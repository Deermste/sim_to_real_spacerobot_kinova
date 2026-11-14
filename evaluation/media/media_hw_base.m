function B = media_hw_base(t, Q, varargin)
%MEDIA_HW_BASE  Virtuelle Basislage zu einer gemessenen Gelenkbahn (fester Arm im Labor, Basis frei schwebend gedacht).
%   B = media_hw_base(t, Q)                  t (n x 1) [s], Q (n x 7) [rad], z. B. run.log.t_wall, run.log.q
%   B = media_hw_base(t, Q, 'h', 0.005, 'K', ext_kin_model())
%
%   Wie D19 (desktop_day2_base_from_hw): Die gemessene Gelenkbahn wird in die Kinematik des frei schwebenden
%   Systems eingespielt (Impulserhaltung, Anfangsimpuls null, Basis 65 kg). Ergebnis ist die Lage, die eine frei
%   schwebende Basis bei genau dieser Gelenkbewegung haette. Offen gerechnet, die Policy reagiert nicht darauf.
%   Integration wie ext_kinsim: Basis-Twist tw = G(q) dq im Basissystem, Quaternion rechts multipliziert mit dem
%   Mittel der Winkelgeschwindigkeit, Position mit der Trapezregel. q wird mit pchip auf das Raster h gelegt, dq ist
%   die Ableitung dieser Interpolation. Bei Anfangsimpuls null haengt die Drehung nur vom Weg ab, nicht vom Timing.
%   B: t (Raster), q, pb (n x 3), quat (n x 4 [w x y z]), ori (Norm des Drehvektors [rad]), pe (EE im Basissystem)

p = inputParser;
p.addParameter('h', 0.005);
p.addParameter('K', []);
p.parse(varargin{:});
o = p.Results;
K = o.K;
if isempty(K), K = ext_kin_model(); end
t = t(:) - t(1);
tg = (0:o.h:t(end)).';
pp = pchip(t, Q.');
qg = ppval(pp, tg).';
dpp = fnder_pchip(pp);
dqg = ppval(dpp, tg).';
n = numel(tg);
pb = zeros(n, 3); quat = zeros(n, 4); ori = zeros(n, 1); pe = zeros(n, 3);
qt = [1; 0; 0; 0]; pbc = zeros(3, 1);
[G, pe1] = ext_kin_eval(K, qg(1, :).');
tw = G * dqg(1, :).';
Rb = eye(3);
pb(1, :) = pbc.'; quat(1, :) = qt.'; pe(1, :) = pe1.';
for i = 2:n
    twOld = tw; RbOld = Rb;
    [G, pei] = ext_kin_eval(K, qg(i, :).');
    tw = G * dqg(i, :).';
    wAvg = 0.5 * (twOld(4:6) + tw(4:6));
    qt = qmul(qt, qexp(wAvg * o.h));
    qt = qt / norm(qt);
    Rb = q2r(qt);
    pbc = pbc + 0.5 * (RbOld * twOld(1:3) + Rb * tw(1:3)) * o.h;
    pb(i, :) = pbc.'; quat(i, :) = qt.'; ori(i) = norm(rotvec(qt)); pe(i, :) = pei.';
end
B = struct('t', tg, 'q', qg, 'pb', pb, 'quat', quat, 'ori', ori, 'pe', pe);
end

% =====================================================================
function d = fnder_pchip(pp)
% Ableitung eines pp-Polynoms (pchip) ohne Curve Fitting Toolbox
[br, c, l, k, dd] = unmkpp(pp);
dc = c(:, 1:k - 1) .* repmat(k - 1:-1:1, size(c, 1), 1);
d = mkpp(br, dc, dd);
assert(l == numel(br) - 1, 'media_hw_base:pp', 'unerwartete Stueckzahl');
end

function qo = qmul(q1, q2)
w1 = q1(1); v1 = q1(2:4); w2 = q2(1); v2 = q2(2:4);
qo = [w1 * w2 - v1.' * v2; w1 * v2 + w2 * v1 + cross(v1, v2)];
end

function qo = qexp(phi)
a = norm(phi);
if a < 1e-15
    qo = [1; 0.5 * phi];
else
    qo = [cos(a / 2); sin(a / 2) * phi / a];
end
end

function v = rotvec(qt)
if qt(1) < 0, qt = -qt; end
nv = norm(qt(2:4));
if nv < 1e-12
    v = zeros(3, 1);
else
    v = 2 * atan2(nv, max(1e-12, qt(1))) * qt(2:4) / nv;
end
end

function R = q2r(qt)
w = qt(1); x = qt(2); y = qt(3); z = qt(4);
R = [1 - 2*(y^2 + z^2), 2*(x*y - z*w),     2*(x*z + y*w);
     2*(x*y + z*w),     1 - 2*(x^2 + z^2), 2*(y*z - x*w);
     2*(x*z - y*w),     2*(y*z + x*w),     1 - 2*(x^2 + y^2)];
end
