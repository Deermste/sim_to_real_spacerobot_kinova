function out = ext_x6_plant(X, a2, a3, a4)
%EXT_X6_PLANT  Frei schwebende Strecke als Schrittfunktion fuer die X6-Umgebung (X6.1).
%   X = ext_x6_plant('init', K, q0, opt)   Zustand am Start (Arm in Ruhe, Basis in Ruhe und ausgerichtet)
%   X = ext_x6_plant(X, cmd)               ein Agentenschritt mit dem Gelenkbefehl cmd (7x1, rad/s)
%   y = ext_x6_plant('meas', X)            Messgroessen zum aktuellen Zeitpunkt
%
%   Dieselbe Rechnung wie ext_kinsim (gleiche Reihenfolge der Operationen, damit bitgleich):
%     Rate Transition: Im Intervall [t_k, t_k+1] wirkt der Befehl aus Schritt k-1.
%     Integrator (Start q0) -> Klemme auf opt.qLim -> Gelenkfilter 1/(tau s + 1)^2 exakt diskretisiert.
%     Basis-Twist G(q) dq, Lage als Quaternion (Mittel der Drehraten), Ort mit der Trapezregel.
%   Ohne Drift, Messfehler, Verzoegerung und Emulation (die kommen spaeter in X6.3, Randomisierung).
%   opt: Ts (Solvertakt, 0,005), Ts_agent (0,05), tau (0,02), qLim (7x1, Strecke).
%   y: t, q, dq, p (Werkzeugpunkt in der Welt), v (seine Geschwindigkeit), Rb, quat, e_ori (Drehvektor),
%      v_base, w_base (Welt), clamp (7x1 logisch, Gelenk an der Klemme).

if ischar(X)
    switch X
        case 'init'
            out = initState(a2, a3, a4);
        case 'meas'
            out = meas(a2);
    end
    return
end
cmd = a2;
S = X;
h = S.h;
u = S.cmdHeld;
S.cmdHeld = cmd(:);
for i = 1:S.m
    xN = S.x + h * u;
    qcN = min(max(xN, -S.qLim), S.qLim);
    S.Z = S.Ez * S.Z + S.Eu * S.qc.' + S.Es * (qcN - S.qc).';
    S.x = xN; S.qc = qcN;
    q = S.Z(1, :).'; dq = S.Z(2, :).';
    twOld = S.tw; RbOld = S.Rb;
    [G, pe, Je] = ext_kin_eval(S.K, q);
    tw = G * dq;
    wAvg = 0.5 * (twOld(4:6) + tw(4:6));
    S.quat = qmul(S.quat, qexp(wAvg * h));
    S.quat = S.quat / norm(S.quat);
    S.Rb = q2r(S.quat);
    S.pb = S.pb + 0.5 * (RbOld * twOld(1:3) + S.Rb * tw(1:3)) * h;
    S.tw = tw; S.pe = pe; S.Je = Je; S.q = q; S.dq = dq;
end
S.k = S.k + 1;
out = S;
end

% =====================================================================
function S = initState(K, q0, opt)
d = struct('Ts', 0.005, 'Ts_agent', 0.05, 'tau', 0.02, 'qLim', [2*pi; 2.41; 2*pi; 2.66; 2.23; 2.01; 2*pi]);
fn = fieldnames(opt);
for k = 1:numel(fn), d.(fn{k}) = opt.(fn{k}); end
h = d.Ts;
m = round(d.Ts_agent / h);
assert(abs(m * h - d.Ts_agent) < 1e-12, 'ext_x6_plant:rate', 'Ts_agent muss ein Vielfaches von Ts sein');
tau = d.tau;
A = [0 1; -1 / tau^2, -2 / tau];
B = [0; 1 / tau^2];
E = expm([A, B, zeros(2, 1); zeros(1, 3), 1; zeros(1, 4)] * h);
S.Ez = E(1:2, 1:2); S.Eu = E(1:2, 3); S.Es = E(1:2, 4) / h;
S.h = h; S.m = m; S.Ts_agent = d.Ts_agent; S.qLim = d.qLim(:); S.K = K;
S.x = q0(:);
S.qc = min(max(S.x, -S.qLim), S.qLim);
S.Z = [S.qc.'; zeros(1, 7)];
S.quat = [1; 0; 0; 0];
S.pb = zeros(3, 1);
S.q = S.Z(1, :).'; S.dq = S.Z(2, :).';
[G, S.pe, S.Je] = ext_kin_eval(K, S.q);
S.Rb = q2r(S.quat);
S.tw = G * S.dq;
S.cmdHeld = zeros(7, 1);
S.k = 0;
end

function y = meas(S)
y.t = S.k * S.Ts_agent;
y.q = S.q; y.dq = S.dq;
y.p = S.pb + S.Rb * S.pe;
y.v = S.Rb * (S.Je * S.dq + zeros(3, 1));
y.Rb = S.Rb; y.quat = S.quat;
y.e_ori = rotvec(S.quat);
y.v_base = S.Rb * S.tw(1:3); y.w_base = S.Rb * S.tw(4:6);
y.clamp = abs(S.x) >= S.qLim;
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

function qo = qexp(phi)
a = norm(phi);
if a < 1e-15
    qo = [1; 0.5 * phi];
else
    qo = [cos(a / 2); sin(a / 2) * phi / a];
end
end

function qo = qmul(q1, q2)
w1 = q1(1); v1 = q1(2:4); w2 = q2(1); v2 = q2(2:4);
qo = [w1 * w2 - v1.' * v2; w1 * v2 + w2 * v1 + cross(v1, v2)];
end

function R = q2r(qt)
w = qt(1); x = qt(2); y = qt(3); z = qt(4);
R = [1 - 2*(y^2 + z^2), 2*(x*y - z*w),     2*(x*z + y*w);
     2*(x*y + z*w),     1 - 2*(x^2 + z^2), 2*(y*z - x*w);
     2*(x*z - y*w),     2*(y*z + x*w),     1 - 2*(x^2 + y^2)];
end
