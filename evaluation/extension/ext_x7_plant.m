function [out, out2] = ext_x7_plant(S, a2)
%EXT_X7_PLANT  Strecke von ext_kinsim als Schrittfunktion fuer die Residual-Umgebung (X7, 15.11.2026).
%   S = ext_x7_plant(struct(opts))     Zustand bei t = 0, Optionen wie ext_kinsim (Teilmenge, siehe unten)
%   [obs, S] = ext_x7_plant('obs', S)  Beobachtung (29 Kanaele) zum aktuellen Agentenschritt, zieht das Rauschen
%   S = ext_x7_plant(S, a)             ein Agentenschritt mit dem Rohbefehl a (7x1): Verzoegerung, Saettigung,
%                                      Filter, Rate Limiter, Cmd Scale, dann Integration ueber [t_k, t_k+1] mit
%                                      dem Befehl aus Schritt k-1 (Rate Transition)
%   m = ext_x7_plant('metrics', S)     Kennzahlen wie ext_kinsim (rms_ee, ep_q4, max_ee, ori_max, w_max)
%   y = ext_x7_plant('tool', S)        EE- bzw. Werkzeugpunkt p und seine Geschwindigkeit v (Welt) zum Schritt
%
%   Dieselbe Rechnung in derselben Reihenfolge wie ext_kinsim mit chain 'full', damit die Gelenkbahn bitgleich
%   ist (Pruefung ext_x7_check). ext_kinsim bleibt unveraendert und ist die Referenz fuer alle Auswertungen.
%   Optionen (Standard wie ext_kinsim): Ts 0,005, Ts_agent 0,025, T 8,5, r 0,2, center, path 'planar', tilt 30,
%   j6_lim 0,9774, lim [], slew 0,5, cmd_scale 1, delay_steps 0, q0 zeros(7,1), tau 0,02, K (ext_kin_model),
%   obsNoise 29x1, obsBias 29x1, rngSeed 0, w0_init 3x1, filt_a 0,95.
%   Set-Point (X7-SP, 15.11.): chain 'x6' mit chainP (chain_step statt Saettigung, Filter, Rate Limiter, wie
%   ext_kinsim), refFcn @(t) -> numel(t) x 3 (eigene Referenz), qLim 7x1.
%   Die Beobachtung ist [ep; ev; v_base; w_base; q; dq; e_ori] wie ext_kinsim. Das Rauschen kommt aus einem eigenen
%   Strom mit rngSeed, je Agentenschritt ein randn(29, 1) wie in ext_kinsim.

if ischar(S)
    switch S
        case 'obs'
            [out, out2] = observe(a2);
        case 'metrics'
            out = metrics(a2);
        case 'tool'
            out = struct('p', a2.pb + a2.Rb * a2.pe, 'v', a2.Rb * (a2.Je * a2.dq + a2.Dd));
    end
    return
end
if nargin == 1
    out = initState(S);
    return
end
out = stepState(S, a2);
end

% =====================================================================
function S = initState(opt)
d = struct('Ts', 0.005, 'Ts_agent', 0.025, 'T', 8.5, 'r', 0.2, 'center', [0.0, -0.025, 1.687 - 0.2], ...
           'path', 'planar', 'tilt', 30, 'j6_lim', 0.9774, 'lim', [], 'slew', 0.5, 'cmd_scale', 1, ...
           'delay_steps', 0, 'q0', zeros(7, 1), 'tau', 0.02, 'K', [], 'obsNoise', zeros(29, 1), ...
           'obsBias', zeros(29, 1), 'rngSeed', 0, 'w0_init', zeros(3, 1), 'filt_a', 0.95, ...
           'qLim', [2*pi; 2.41; 2*pi; 2.66; 2.23; 2.01; 2*pi], 'chain', 'full', 'chainP', [], 'refFcn', []);
fn = fieldnames(opt);
for k = 1:numel(fn), d.(fn{k}) = opt.(fn{k}); end
S.o = d;
if isempty(d.K), d.K = ext_kin_model(); end
S.K = d.K;
h = d.Ts;
S.h = h;
S.m = round(d.Ts_agent / h);
S.N = floor(d.T / d.Ts_agent + 1e-9);
nS = S.N * S.m;
S.lim = [0.0; 0.9774; 0.0; 0.9774; 0.0; d.j6_lim; 0.0];
if ~isempty(d.lim), S.lim = d.lim(:); end
S.qLim = d.qLim(:);
S.dSlew = d.slew * d.Ts_agent;
t = (0:nS).' * h;
if isempty(d.refFcn)
    S.traj = ext_ref_path(t, d);
else
    S.traj = d.refFcn(t);
end
S.x6 = strcmp(d.chain, 'x6');
if S.x6
    assert(abs(d.chainP.Ts - d.Ts_agent) < 1e-12, 'ext_x7_plant:x6', 'chainP.Ts muss Ts_agent sein');
    S.cs = chain_step('init', d.chainP);
end
S.vref = [zeros(1, 3); diff(S.traj) / h];
tau = d.tau;
A = [0 1; -1 / tau^2, -2 / tau];
B = [0; 1 / tau^2];
E = expm([A, B, zeros(2, 1); zeros(1, 3), 1; zeros(1, 4)] * h);
S.Ez = E(1:2, 1:2); S.Eu = E(1:2, 3); S.Es = E(1:2, 4) / h;
S.x = d.q0(:);
S.qc = min(max(S.x, -S.qLim), S.qLim);
S.Z = [S.qc.'; zeros(1, 7)];
S.quat = [1; 0; 0; 0];
S.pb = zeros(3, 1);
S.yf = zeros(7, 1); S.yr = zeros(7, 1); S.cmdHeld = zeros(7, 1);
S.dBuf = zeros(7, d.delay_steps);
S.noisy = any(d.obsNoise > 0);
if S.noisy, S.ns = RandStream('mt19937ar', 'Seed', d.rngSeed); end
S.q = S.Z(1, :).'; S.dq = S.Z(2, :).';
[G, S.pe, S.Je, ~, S.Hb] = ext_kin_eval(S.K, S.q);
S.Rb = q2r(S.quat);
S.hasDrift = any(d.w0_init ~= 0);
S.Lw = zeros(3, 1);
if S.hasDrift
    w0 = S.Rb.' * d.w0_init(:);
    v0 = -S.Hb(1:3, 4:6) * w0 / S.Hb(1, 1);
    S.Lw = S.Rb * (S.Hb(4:6, :) * [v0; w0]);
end
[S.tw, S.Dd] = twistOf(S, G, S.dq, S.Hb, S.pe, S.Rb);
S.k = 0;
% Solvertakt-Speicher fuer die Kennzahlen
S.epS = nan(nS + 1, 3); S.oriS = nan(nS + 1, 1); S.wS = nan(nS + 1, 1); S.qS = nan(nS + 1, 7);
S = logSolver(S, 1);
end

function [obs, S] = observe(S)
n = S.k * S.m;
ep = S.pb + S.Rb * S.pe - S.traj(n + 1, :).';
ev = S.Rb * (S.Je * S.dq + S.Dd) - S.vref(n + 1, :).';
vb = S.Rb * S.tw(1:3); wb = S.Rb * S.tw(4:6);
eo = rotvec(S.quat);
obs = [ep; ev; vb; wb; S.q; S.dq; eo];
obs = obs + S.o.obsBias(:);
if S.noisy, obs = obs + S.o.obsNoise(:) .* randn(S.ns, 29, 1); end
end

function S = stepState(S, a)
a = a(:);
if S.o.delay_steps > 0
    S.dBuf = [S.dBuf, a];
    a = S.dBuf(:, 1);
    S.dBuf(:, 1) = [];
end
if S.x6
    [cmd, S.cs] = chain_step(S.cs, a, S.q);
    cmd = cmd * S.o.cmd_scale;
else
    sat = min(max(a, -S.lim), S.lim);
    if S.o.filt_a == 0.95
        S.yf = 0.95 * S.yf + 0.05 * sat;
    else
        S.yf = S.o.filt_a * S.yf + (1 - S.o.filt_a) * sat;
    end
    S.yr = S.yr + min(max(S.yf - S.yr, -S.dSlew), S.dSlew);
    cmd = S.yr * S.o.cmd_scale;
end
n = S.k * S.m;
u = S.cmdHeld;
S.cmdHeld = cmd;
h = S.h;
for i = 1:S.m
    xN = S.x + h * u;
    qcN = min(max(xN, -S.qLim), S.qLim);
    S.Z = S.Ez * S.Z + S.Eu * S.qc.' + S.Es * (qcN - S.qc).';
    S.x = xN; S.qc = qcN;
    S.q = S.Z(1, :).'; S.dq = S.Z(2, :).';
    twOld = S.tw; RbOld = S.Rb;
    [G, S.pe, S.Je, ~, S.Hb] = ext_kin_eval(S.K, S.q);
    [S.tw, S.Dd] = twistOf(S, G, S.dq, S.Hb, S.pe, RbOld);
    wAvg = 0.5 * (twOld(4:6) + S.tw(4:6));
    S.quat = qmul(S.quat, qexp(wAvg * h));
    S.quat = S.quat / norm(S.quat);
    S.Rb = q2r(S.quat);
    S.pb = S.pb + 0.5 * (RbOld * twOld(1:3) + S.Rb * S.tw(1:3)) * h;
    S = logSolver(S, n + i + 1);
end
S.k = S.k + 1;
end

function m = metrics(S)
nEnd = S.k * S.m;
idx = 1:nEnd + 1;
t = (idx(:) - 1) * S.h;
epn = vecnorm(S.epS(idx, :), 2, 2);
T = S.o.T;
m = struct('rms_ee', sqrt(mean(epn .^ 2)), 'max_ee', max(epn), ...
           'ep_q4', mean(epn(t >= 3 * T / 4 & t <= T + 1e-9)), 'ori_max', max(S.oriS(idx)), ...
           'w_max', max(S.wS(idx)), 't_end', S.k * S.o.Ts_agent);
end

function [t2, D] = twistOf(S, Gm, dqv, Hm, pev, Rm)
t2 = Gm * dqv;
D = zeros(3, 1);
if S.hasDrift
    dd = Hm \ [zeros(3, 1); Rm.' * S.Lw];
    t2 = t2 + dd;
    D = dd(1:3) - [0 -pev(3) pev(2); pev(3) 0 -pev(1); -pev(2) pev(1) 0] * dd(4:6);
end
end

function S = logSolver(S, j)
S.epS(j, :) = (S.pb + S.Rb * S.pe - S.traj(j, :).').';
S.oriS(j) = norm(rotvec(S.quat));
S.wS(j) = norm(S.tw(4:6));
S.qS(j, :) = S.q.';
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
