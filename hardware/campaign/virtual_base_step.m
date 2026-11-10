function [vb, out] = virtual_base_step(vb, q, dq)
%VIRTUAL_BASE_STEP  Kinematische Free-Floating-Emulation: virtuelle Basis aus gemessenen Gelenkwinkeln (X3.1).
%   vb = virtual_base_step('init', q0)            Zustand anlegen (Basis in Ruhe, Lage = Einheit, Ursprung)
%   vb = virtual_base_step('init', q0, K)         mit eigenem Modell (ext_kin_model, Standard nominal 65 kg)
%   [vb, out] = virtual_base_step(vb, q, dq)      ein Schritt mit den gemessenen q, dq (7x1, rad, rad/s)
%
%   Eine Datei fuer den Simulator (ext_kinsim, Option 'emulate') und das Deploy-Skript (deploy_tracking_v25).
%   Grundlage: Gelenke bewegungsgesteuert, Impuls null, keine aeusseren Kraefte. Dann haengt die Basislage nur
%   vom Weg im Gelenkraum ab (verallgemeinerte Jacobi-Matrix, Umetani und Yoshida). Je Schritt:
%     dx = G(q_mid) (q - q_prev), q_mid = (q + q_prev) / 2, dx = [dp0; dth] im Basissystem
%     Lage: quat <- quat * exp(dth), Ort: p0 <- p0 + R_mid dp0 (R_mid = Lage nach dem halben Drehschritt)
%   Die Zeit geht nicht ein, nur der Weg. Unregelmaessige Schrittzeiten veraendern das Ergebnis also nur ueber die
%   Aufloesung des Wegs. Geschwindigkeiten fuer die Beobachtung aus den gemessenen dq.
%   out (alles im Weltsystem der Emulation, gleich der Welt des Trainingsmodells bei ruhender Basis):
%     pe       EE-Position, p0 + R pe(q)
%     ve       EE-Geschwindigkeit, R Je(q) dq (Je mit Basisreaktion)
%     v_base   R G(1:3, :) dq,  w_base  R G(4:6, :) dq
%     e_ori    Drehvektor der Basislage wie im Modell (2 atan2(|v|, w) v / |v|)
%     R, p0, quat
%   Die Beobachtung des Trainings ist dann [pe - ref; ve - vref; v_base; w_base; q; dq; e_ori].

if ischar(vb) && strcmp(vb, 'init')
    K = [];
    if nargin > 2, K = dq; end
    if isempty(K), K = ext_kin_model(); end
    vb = struct('K', K, 'q', q(:), 'quat', [1; 0; 0; 0], 'p0', zeros(3, 1), 'n', 0);
    out = [];
    return
end
q = q(:); dq = dq(:);
dqPath = q - vb.q;
G = ext_kin_eval(vb.K, 0.5 * (q + vb.q));
dx = G * dqPath;
qHalf = qmul(vb.quat, qexp(0.5 * dx(4:6)));
vb.p0 = vb.p0 + q2r(qHalf) * dx(1:3);
vb.quat = qmul(vb.quat, qexp(dx(4:6)));
vb.quat = vb.quat / norm(vb.quat);
vb.q = q;
vb.n = vb.n + 1;
if nargout > 1
    [Gq, pe, Je] = ext_kin_eval(vb.K, q);
    R = q2r(vb.quat);
    out = struct('pe', vb.p0 + R * pe, 've', R * (Je * dq), 'v_base', R * (Gq(1:3, :) * dq), ...
                 'w_base', R * (Gq(4:6, :) * dq), 'e_ori', rotvec(vb.quat), 'R', R, 'p0', vb.p0, ...
                 'quat', vb.quat);
end
end

% =====================================================================
function r = qmul(a, b)
r = [a(1) * b(1) - a(2:4).' * b(2:4); a(1) * b(2:4) + b(1) * a(2:4) + cross(a(2:4), b(2:4))];
end

function e = qexp(v)
th = norm(v);
if th < 1e-15
    e = [1; 0.5 * v];
    e = e / norm(e);
else
    e = [cos(th / 2); sin(th / 2) * v / th];
end
end

function R = q2r(qq)
w = qq(1); x = qq(2); y = qq(3); z = qq(4);
R = [1 - 2 * (y^2 + z^2), 2 * (x * y - w * z), 2 * (x * z + w * y);
     2 * (x * y + w * z), 1 - 2 * (x^2 + z^2), 2 * (y * z - w * x);
     2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x^2 + y^2)];
end

function v = rotvec(qq)
% wie MATLAB Function2 in SK_desktop und rotvec in ext_kinsim
if qq(1) < 0, qq = -qq; end
s = norm(qq(2:4));
if s < 1e-12
    v = zeros(3, 1);
else
    v = 2 * atan2(s, max(1e-12, qq(1))) * qq(2:4) / s;
end
end
