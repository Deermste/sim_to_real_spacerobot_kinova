function [G, pe, Je, Jg] = ext_kin_eval(K, q)
%EXT_KIN_EVAL  Verallgemeinerte Jacobi-Matrix des frei schwebenden Systems, schnell (X0.2).
%   [G, pe, Je] = ext_kin_eval(K, q)      K aus ext_kin_model, q 7x1 [rad]
%
%   Gleiche Rechnung wie desktop_freefloat (Umetani und Yoshida, Anfangsimpuls null, keine aeusseren Kraefte),
%   aber ohne rigidBodyTree-Aufrufe. Alles im Basis-Koordinatensystem mit Ursprung im Basis-Schwerpunkt.
%   G   6x7  Basis-Twist [v0; w0] = G * qd (v0 Geschwindigkeit des Basis-Schwerpunkts)
%   pe  3x1  Endeffektor-Position
%   Je  3x7  Endeffektor-Geschwindigkeit mit Basisbewegung = Je * qd
%   Jg  6x7  geometrische Jacobi-Matrix des Endeffektors bei fester Basis [v; w] (fuer Regler, X2)

nb = K.nb;
R = zeros(3, 3, nb);
P = zeros(3, nb);
z = zeros(3, 7);                    % Gelenkachsen im Basissystem
pj = zeros(3, 7);                   % Gelenkorte im Basissystem
anc = false(nb, 7);                 % Gelenk j liegt vor Koerper i
for i = K.order
    pa = K.parent(i);
    if pa == 0
        Rp = eye(3); Pp = zeros(3, 1); ancP = false(1, 7);
    else
        Rp = R(:, :, pa); Pp = P(:, pa); ancP = anc(pa, :);
    end
    Tjp = K.Tjp(:, :, i);
    Rj = Rp * Tjp(1:3, 1:3);
    Pj = Pp + Rp * Tjp(1:3, 4);
    j = K.jidx(i);
    if j > 0
        a = K.axis(:, i);
        zj = Rj * a;
        z(:, j) = zj;
        pj(:, j) = Pj;
        Rj = Rj * axang(a, q(j));
        ancP(j) = true;
    end
    Tcj = K.Tcj(:, :, i);
    R(:, :, i) = Rj * Tcj(1:3, 1:3);
    P(:, i) = Pj + Rj * Tcj(1:3, 4);
    anc(i, :) = ancP;
end

M = K.m0; mr = zeros(3, 1); Hw = K.I0; JTw = zeros(3, 7); Hwq = zeros(3, 7);
for i = K.order
    m = K.mass(i);
    if m <= 0, continue; end
    Ri = R(:, :, i);
    r = P(:, i) + Ri * K.com(:, i);
    Iw = Ri * K.Ic(:, :, i) * Ri.';
    Jw = z .* anc(i, :);
    JT = cross(Jw, r - pj, 1) .* anc(i, :);
    M = M + m;
    mr = mr + m * r;
    Sr = skew(r);
    Hw = Hw + Iw - m * (Sr * Sr);
    JTw = JTw + m * JT;
    Hwq = Hwq + Iw * Jw + m * Sr * JT;
end
Smr = skew(mr);
Hb = [M * eye(3), -Smr; Smr, Hw];
G = -Hb \ [JTw; Hwq];
e = K.ee;
pe = P(:, e);
Jv = cross(z, pe - pj, 1) .* anc(e, :);
Je = G(1:3, :) - skew(pe) * G(4:6, :) + Jv;
if nargout > 3
    Jg = [Jv; z .* anc(e, :)];
end
end

function S = skew(v)
S = [0 -v(3) v(2); v(3) 0 -v(1); -v(2) v(1) 0];
end

function Rm = axang(a, th)
% Drehmatrix um die Einheitsachse a (Rodrigues)
c = cos(th); s = sin(th); C = 1 - c;
x = a(1); y = a(2); w = a(3);
Rm = [c + x*x*C,   x*y*C - w*s, x*w*C + y*s;
      y*x*C + w*s, c + y*y*C,   y*w*C - x*s;
      w*x*C - y*s, w*y*C + x*s, c + w*w*C];
end
