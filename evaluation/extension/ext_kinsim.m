function res = ext_kinsim(policy, varargin)
%EXT_KINSIM  Kinematischer Closed-Loop-Simulator des frei schwebenden Systems (X0.2).
%   res = ext_kinsim(agentFile)                              wie desktop_run_episode, Standardwerte wie desktop_config
%   res = ext_kinsim(agentFile, 'j6_lim', 0.9774, 'reward_mode', 4)
%   res = ext_kinsim(@(obs) ..., 'K', ext_kin_model('base_mass', 32.5))   Regler oder Policy als Funktion
%   res = ext_kinsim([], 'ctrl', ext_x2_controller('beta', 1), 'chain', 'sat')   Regler mit Referenz (X2)
%
%   Grundlage: Die Gelenke von SK_desktop sind bewegungsgesteuert (InputMotion) und der Anfangsimpuls ist null.
%   Dann haengt die Basisbewegung nur von der Gelenkbahn ab (Impulserhalt, verallgemeinerte Jacobi-Matrix), und
%   das ganze System ist kinematisch. Nachgebildet ist der Signalweg von SK_desktop (geprueft 10.11.2026):
%     Beobachtung [ep; ev; v_base; w_base; q; dq; e_ori] zu den Agentenschritten. ep, ev = Ist - Soll im
%       Weltsystem, v_base, w_base im Weltsystem, e_ori = Drehvektor der Basislage (Quaternion, wie
%       MATLAB Function2 im Modell). Referenz wie desktop_run_episode (Geschwindigkeit als Rueckwaertsdifferenz).
%     Aktion -> Delay (p_delay_steps) -> Saettigung (J2, J4 0,9774, J6 j6_lim, sonst 0) -> Filter
%       y = 0,95 y + 0,05 u -> Rate Limiter (slew * Ts_agent je Schritt, Start 0) -> Cmd Scale.
%     Rate Transition zum Solvertakt verzoegert um einen Agentenschritt: Im Intervall [t_k, t_k+1] wirkt der
%       Befehl aus Schritt k-1 (gemessen: Abweichung 4e-13).
%     Integrator (Start q0) -> Positionssaettigung -> Simulink-PS-Wandler mit Filter 1/(tau s + 1)^2,
%       tau = 0,02 s. Ausgang ist die Gelenkbahn q, dq (gemessen: Abweichung 5e-11 rad bei linearer
%       Interpolation des Befehls zwischen den Solverschritten). Hier exakt diskretisiert.
%     Basis: Twist [v0; w0] = G(q) dq im Basissystem, Lage als Quaternion, Trapezregel je Solverschritt.
%     Reward wie rewardCode (ext_reward) mit Rohaktion und vorheriger Rohaktion, Abbruch bei isDone.
%
%   Optionen (Standard wie desktop_config): Ts 0,005, Ts_agent 0,025, T 8,5, r 0,2, center, j6_lim 0,1,
%   slew 0,5, cmd_scale 1, delay_steps 0, reward_mode 0, base_w 2, lambda 0, theta 0,03, cost_type 1 (X1),
%   q0 zeros(7,1), tau 0,02,
%   K (ext_kin_model, Standard nominal mit base_mass), base_mass 65 (nur wenn K fehlt),
%   cmdHook @(cmd, S) -> cmd: Eingriff nach der Befehlskette, vor der Verzoegerung (fuer den Filter in X1.4).
%     S hat die Felder t, q, dq, G, Je, quat, ori (Drehvektor), obs (Beobachtung mit Rauschen und Messfehler).
%   obsNoise 29x1 Standardabweichungen (Standard 0), rngSeed fuer das Rauschen,
%   obsBias 29x1 fester Messfehler auf der Beobachtung (Standard 0, X2.3),
%   w0_init 3x1 Anfangs-Drehrate der Basis im Weltsystem [rad/s] bei ruhendem Arm (Standard 0, X2.3). Daraus
%     folgt ein Drehimpuls L ungleich null (Gesamtimpuls P = 0), der erhalten bleibt. Der Basis-Twist ist dann
%     G dq + Hb \ [0; Rb' L], die EE-Geschwindigkeit erhaelt den passenden Anteil.
%   keepTs (Standard true).
%   actionSeq (N+1)x7 Rohaktionen statt der Policy (offene Einspielung zur Validierung), policy darf dann [] sein.
%   ctrl @(obs, R) -> 7x1 Rohbefehl statt der Policy (X2). R hat die Felder t, pref, vref (Referenz zum
%     Agentenschritt, vref wie in der Beobachtung als Rueckwaertsdifferenz). Sonst nur die Beobachtung.
%   emulate (Standard false, X3.1): Die Strecke ist der fest montierte Arm (Basis ruht), die Beobachtung kommt
%     aus virtual_base_step mit q, dq zu jedem Agentenschritt, wie im Deploy-Skript v25. emulK ist das Modell
%     der Emulation (Standard ext_kin_model nominal). Zusaetzliche Kennzahlen emu_rms_ee, emu_ep_q4,
%     emu_ori_max aus der emulierten Beobachtung (Agententakt). rms_ee usw. sind dann die des festen Arms.
%   chain 'full' (Standard, Befehlskette wie oben) oder 'sat' (nur Saettigung und Cmd Scale, ohne Filter und
%     Rate Limiter, fuer einen idealen Regler in X2). Verzoegerung, Rate Transition und Gelenkfilter bleiben.
%   lim 7x1 Geschwindigkeitsgrenzen der Saettigung [rad/s] (Standard [], dann J2, J4 0,9774, J6 j6_lim, sonst 0).
%     Fuer alle sieben Gelenke (X5) etwa [0.98 0.98 0.98 0.98 0.58 0.58 0.58].
%   path 'planar' (Standard) oder 'tilted', tilt [Grad, Standard 30]: Referenzbahn aus ext_ref_path (X5.1).
%   chain 'x6' (X6, E18): Befehlskette chain_step (Skalierung, Bremskurve, Beschleunigungsgrenze, HW-Cap) statt
%     Saettigung, Filter und Rate Limiter. Parameter chainP (Standard chain_step('params') mit Ts = Ts_agent).
%     Kennzahlen x6_brake, x6_accel, x6_cap: Anteil der Schritte, in denen die Stufe eingreift.
%   refFcn @(t) -> numel(t) x 3: eigene Referenzbahn statt ext_ref_path (X6). Geschwindigkeit wie sonst als
%     Rueckwaertsdifferenz.
%   qLim 7x1 Winkelgrenzen der Strecke (Klemme nach dem Integrator, Standard wie SK_desktop [2pi 2,41 2pi 2,66
%     2,23 2,01 2pi]). X6: chain_step('params').q_lim mit Inf durch 2pi ersetzt.
%   noStop (Standard false): Abbruchbedingung aus ext_reward ignorieren (Tests und offene Gelenkbahnen in X6).
%   obs_ext (Standard false, X4.6 V2/V3): Beobachtung mit 38 Kanaelen wie die Modelle SK_x46*:
%     [obs; Ausgang des Rate Limiters im vorigen Schritt fuer J2, J4, J6; Sollpunkt in 0,25 s und 0,5 s relativ
%     zum EE (ext_ref_preview minus ep, nach Rauschen und Messfehler)]
%   filt_a (Standard 0,95): Koeffizient des Befehlsfilters y = filt_a y + (1 - filt_a) u (X4.6 V3: 0,85).
%
%   res.metrics  wie desktop_run_episode: mse_ee, rms_ee, max_ee, ep_q4, ori_mean, ori_max, w_mean, w_max, ret,
%                early_stop, t_end, n_steps, stop_reason
%   res.ts       t_ee, ep, ori, w (Solvertakt), t_agent, obs, a_raw, a_scaled, reward (Agententakt), q, dq,
%                q_cmd (Solvertakt)
%   res.info     Laufzeit

p = inputParser;
p.addParameter('Ts', 0.005);
p.addParameter('Ts_agent', 0.025);
p.addParameter('T', 8.5);
p.addParameter('r', 0.2);
p.addParameter('center', [0.0, -0.025, 1.687 - 0.2]);
p.addParameter('j6_lim', 0.1);
p.addParameter('slew', 0.5);
p.addParameter('cmd_scale', 1);
p.addParameter('delay_steps', 0);
p.addParameter('reward_mode', 0);
p.addParameter('base_w', 2);
p.addParameter('lambda', 0);
p.addParameter('theta', 0.03);
p.addParameter('cost_type', 1);
p.addParameter('q0', zeros(7, 1));
p.addParameter('tau', 0.02);
p.addParameter('K', []);
p.addParameter('base_mass', 65);
p.addParameter('cmdHook', []);
p.addParameter('obsNoise', zeros(29, 1));
p.addParameter('obsBias', zeros(29, 1));
p.addParameter('w0_init', zeros(3, 1));
p.addParameter('rngSeed', 0);
p.addParameter('keepTs', true);
p.addParameter('actionSeq', []);
p.addParameter('ctrl', []);
p.addParameter('chain', 'full');
p.addParameter('emulate', false);
p.addParameter('emulK', []);
p.addParameter('lim', []);
p.addParameter('path', 'planar');
p.addParameter('tilt', 30);
p.addParameter('obs_ext', false);
p.addParameter('filt_a', 0.95);
p.addParameter('chainP', []);
p.addParameter('refFcn', []);
p.addParameter('noStop', false);
p.addParameter('qLim', []);
p.parse(varargin{:});
o = p.Results;

tWall = tic;
if ischar(policy) || isstring(policy)
    pol = ext_policy(char(policy));
else
    pol = policy;
end
assert(~isempty(pol) || ~isempty(o.actionSeq) || ~isempty(o.ctrl), 'ext_kinsim:policy', ...
       'Policy, ctrl oder actionSeq angeben');
assert(ismember(o.chain, {'full', 'sat', 'x6'}), 'ext_kinsim:chain', 'chain ist ''full'', ''sat'' oder ''x6''');
fullChain = strcmp(o.chain, 'full');
x6Chain = strcmp(o.chain, 'x6');
if x6Chain
    cP = o.chainP;
    if isempty(cP), cP = chain_step('params'); cP.Ts = o.Ts_agent; end
    assert(abs(cP.Ts - o.Ts_agent) < 1e-12, 'ext_kinsim:x6', 'chainP.Ts muss Ts_agent sein');
    cs = chain_step('init', cP);
    x6Cnt = zeros(1, 4);                     % Schritte, Bremskurve, Beschleunigungsgrenze, HW-Cap (je ein Gelenk)
end
K = o.K;
if isempty(K), K = ext_kin_model('base_mass', o.base_mass); end

h = o.Ts;
m = round(o.Ts_agent / h);
assert(abs(m * h - o.Ts_agent) < 1e-12, 'ext_kinsim:rate', 'Ts_agent muss ein Vielfaches von Ts sein');
N = floor(o.T / o.Ts_agent + 1e-9);         % letzter Agentenschritt (t = T)
nS = N * m;                                  % letzter Solverschritt
lim = [0.0; 0.9774; 0.0; 0.9774; 0.0; o.j6_lim; 0.0];
if ~isempty(o.lim), lim = o.lim(:); end
qLim = [2*pi; 2.41; 2*pi; 2.66; 2.23; 2.01; 2*pi];
if ~isempty(o.qLim), qLim = o.qLim(:); end   % X6: Datenblatt statt Modellwerte
dSlew = o.slew * o.Ts_agent;

% --- Referenz wie desktop_run_episode (ref_timing 'wall', Halbkreis, X5.1 auch gekippt) ---
t = (0:nS).' * h;
if isempty(o.refFcn)
    traj = ext_ref_path(t, o);
else
    traj = o.refFcn(t);                      % eigene Referenz (X6: Gerade zum Ziel)
end
vref = [zeros(1, 3); diff(traj) / h];
nObs = 29;
if o.obs_ext
    nObs = 38;
    d25 = ext_ref_preview(t, traj, 0.25);
    d50 = ext_ref_preview(t, traj, 0.5);
end

% --- Gelenkfilter 1/(tau s + 1)^2, exakt bei linear interpoliertem Eingang ---
tau = o.tau;
A = [0 1; -1 / tau^2, -2 / tau];
B = [0; 1 / tau^2];
E = expm([A, B, zeros(2, 1); zeros(1, 3), 1; zeros(1, 4)] * h);
Ez = E(1:2, 1:2); Eu = E(1:2, 3); Es = E(1:2, 4) / h;

% --- Zustand ---
x = o.q0(:);                                 % Integrator
qc = min(max(x, -qLim), qLim);
Z = [qc.'; zeros(1, 7)];                     % Filterzustand je Gelenk [q; dq]
quat = [1; 0; 0; 0];                         % Basislage (Basis -> Welt)
pb = zeros(3, 1);                            % Basis-Schwerpunkt in der Welt
yf = zeros(7, 1); yr = zeros(7, 1); aPrev = zeros(7, 1); cmdHeld = zeros(7, 1);
dBuf = zeros(7, o.delay_steps);
if any(o.obsNoise > 0), ns = RandStream('mt19937ar', 'Seed', o.rngSeed); end

% --- Speicher ---
epS = nan(nS + 1, 3); oriS = nan(nS + 1, 1); wS = nan(nS + 1, 1);
keep = o.keepTs;
if keep
    qS = nan(nS + 1, 7); dqS = nan(nS + 1, 7); qcS = nan(nS + 1, 7);
end
obsA = nan(N + 1, nObs); aRaw = nan(N + 1, 7); aScl = nan(N + 1, 7); rew = nan(N + 1, 1); cst = nan(N + 1, 1);

q = Z(1, :).'; dq = Z(2, :).';
[G, pe, Je, ~, Hb] = ext_kin_eval(K, q);
Rb = q2r(quat);
% Anfangsdrehimpuls aus w0_init (Arm in Ruhe, P = 0): M v0 + Hb(1:3,4:6) w0 = 0, L = Hb(4:6,:) [v0; w0]
hasDrift = any(o.w0_init ~= 0);
emu = o.emulate;
if emu
    assert(~hasDrift, 'ext_kinsim:emulate', 'emulate und w0_init zusammen sind nicht vorgesehen');
    eK = o.emulK;
    if isempty(eK), eK = ext_kin_model(); end
    vbs = virtual_base_step('init', q, eK);
    emuEp = nan(N + 1, 1); emuOri = nan(N + 1, 1);
end
Lw = zeros(3, 1);
if hasDrift
    w0 = Rb.' * o.w0_init(:);
    v0 = -Hb(1:3, 4:6) * w0 / Hb(1, 1);
    Lw = Rb * (Hb(4:6, :) * [v0; w0]);
end
[tw, Dd] = twistOf(G, dq, Hb, pe, Rb);
logSolver(1);

done = false; stopReason = 'none'; kEnd = N; nEnd = nS;
for k = 0:N
    n = k * m;
    % --- Beobachtung zum Zeitpunkt t_k ---
    ep = pb + Rb * pe - traj(n + 1, :).';
    ev = Rb * (Je * dq + Dd) - vref(n + 1, :).';
    vb = Rb * tw(1:3); wb = Rb * tw(4:6);
    eo = rotvec(quat);
    if emu
        [vbs, eo_] = virtual_base_step(vbs, q, dq);
        ep = eo_.pe - traj(n + 1, :).';
        ev = eo_.ve - vref(n + 1, :).';
        vb = eo_.v_base; wb = eo_.w_base; eo = eo_.e_ori;
        emuEp(k + 1) = norm(ep); emuOri(k + 1) = norm(eo);
    end
    obs = [ep; ev; vb; wb; q; dq; eo];
    obs = obs + o.obsBias(:);
    if any(o.obsNoise > 0), obs = obs + o.obsNoise(:) .* randn(ns, 29, 1); end
    if o.obs_ext
        obs = [obs; yr([2 4 6]); d25(n + 1, :).' - obs(1:3); d50(n + 1, :).' - obs(1:3)]; %#ok<AGROW>
    end
    if isempty(o.actionSeq)
        if isempty(o.ctrl)
            a = pol(obs);
        else
            a = o.ctrl(obs, struct('t', k * o.Ts_agent, 'pref', traj(n + 1, :).', 'vref', vref(n + 1, :).'));
        end
    else
        a = o.actionSeq(min(k + 1, size(o.actionSeq, 1)), :);
    end
    a = a(:);
    if o.delay_steps > 0
        dBuf = [dBuf, a]; %#ok<AGROW>
        a = dBuf(:, 1);
        dBuf(:, 1) = [];
    end
    [r, isd, c] = ext_reward(obs(1:3), obs(4:6), a, aPrev, obs(10:12), obs(27:29), o.reward_mode, o.base_w, ...
                             o.lambda, o.theta, o.cost_type);
    aPrev = a;
    % --- Befehlskette (Agententakt) ---
    sat = min(max(a, -lim), lim);
    if fullChain
        if o.filt_a == 0.95
            yf = 0.95 * yf + 0.05 * sat;          % wie bisher, bitgleich
        else
            yf = o.filt_a * yf + (1 - o.filt_a) * sat;
        end
        yr = yr + min(max(yf - yr, -dSlew), dSlew);
        cmd = yr * o.cmd_scale;
    elseif x6Chain
        [cmd, cs, ci] = chain_step(cs, a, q);
        x6Cnt = x6Cnt + [1, any(ci.brake), any(ci.accel), any(ci.cap)];
        cmd = cmd * o.cmd_scale;
    else
        cmd = sat * o.cmd_scale;
    end
    if ~isempty(o.cmdHook)
        S = struct('t', k * o.Ts_agent, 'q', q, 'dq', dq, 'G', G, 'Je', Je, 'quat', quat, 'ori', eo, 'obs', obs);
        cmd = o.cmdHook(cmd, S);
    end
    obsA(k + 1, :) = obs.'; aRaw(k + 1, :) = a.'; aScl(k + 1, :) = cmd.'; rew(k + 1) = r; cst(k + 1) = c;
    if isd && ~o.noStop
        done = true; kEnd = k; nEnd = n;
        stopReason = stopOf(obs);
        break
    end
    if k == N, break; end
    % --- Integration ueber [t_k, t_k+1] mit dem Befehl aus Schritt k-1 ---
    u = cmdHeld;
    cmdHeld = cmd;
    for i = 1:m
        xN = x + h * u;
        qcN = min(max(xN, -qLim), qLim);
        Z = Ez * Z + Eu * qc.' + Es * (qcN - qc).';
        x = xN; qc = qcN;
        q = Z(1, :).'; dq = Z(2, :).';
        twOld = tw; RbOld = Rb;
        [G, pe, Je, ~, Hb] = ext_kin_eval(K, q);
        [tw, Dd] = twistOf(G, dq, Hb, pe, RbOld);
        wAvg = 0.5 * (twOld(4:6) + tw(4:6));
        quat = qmul(quat, qexp(wAvg * h));
        quat = quat / norm(quat);
        Rb = q2r(quat);
        pb = pb + 0.5 * (RbOld * twOld(1:3) + Rb * tw(1:3)) * h;
        logSolver(n + i + 1);
    end
end

% --- Kennzahlen wie desktop_run_episode ---
idx = 1:nEnd + 1;
epn = vecnorm(epS(idx, :), 2, 2);
tt = t(idx);
mtr = struct();
mtr.mse_ee = mean(epn .^ 2);
mtr.rms_ee = sqrt(mtr.mse_ee);
mtr.max_ee = max(epn);
mtr.ep_q4 = mean(epn(tt >= 3 * o.T / 4 & tt <= o.T + 1e-9));
mtr.ori_mean = mean(oriS(idx));
mtr.ori_max = max(oriS(idx));
mtr.w_mean = mean(wS(idx));
mtr.w_max = max(wS(idx));
mtr.ret = sum(rew(1:kEnd + 1));
if emu
    ka = 1:kEnd + 1;
    ta = (ka - 1) * o.Ts_agent;
    mtr.emu_rms_ee = sqrt(mean(emuEp(ka) .^ 2));
    mtr.emu_ep_q4 = mean(emuEp(ka(ta >= 3 * o.T / 4 - 1e-9)));
    mtr.emu_ori_max = max(emuOri(ka));
end
mtr.cost_mean = mean(cst(1:kEnd + 1));
mtr.n_steps = kEnd + 1;
mtr.t_end = kEnd * o.Ts_agent;
mtr.early_stop = done || mtr.t_end < o.T - 0.1;
mtr.stop_reason = stopReason;
if x6Chain
    mtr.x6_brake = x6Cnt(2) / x6Cnt(1); mtr.x6_accel = x6Cnt(3) / x6Cnt(1); mtr.x6_cap = x6Cnt(4) / x6Cnt(1);
end

res = struct('metrics', mtr, 'opts', o);
res.ts = struct();
if keep
    ka = 1:kEnd + 1;
    res.ts = struct('t_ee', tt, 'ep', epS(idx, :), 'ori', oriS(idx), 'w', wS(idx), 'q', qS(idx, :), ...
        'dq', dqS(idx, :), 'q_cmd', qcS(idx, :), 't_agent', (ka(:) - 1) * o.Ts_agent, 'obs', obsA(ka, :), ...
        'a_raw', aRaw(ka, :), 'a_scaled', aScl(ka, :), 'reward', rew(ka), 'cost', cst(ka));
end
res.info = struct('wallTime', toc(tWall));

    function [t2, D] = twistOf(Gm, dqv, Hm, pev, Rm)
        % Basis-Twist [v0; w0] im Basissystem und Drift-Anteil der EE-Geschwindigkeit (null ohne Drehimpuls)
        t2 = Gm * dqv;
        D = zeros(3, 1);
        if emu, t2 = zeros(6, 1); return; end   % fester Arm: Basis ruht
        if hasDrift
            dd = Hm \ [zeros(3, 1); Rm.' * Lw];
            t2 = t2 + dd;
            D = dd(1:3) - [0 -pev(3) pev(2); pev(3) 0 -pev(1); -pev(2) pev(1) 0] * dd(4:6);
        end
    end

    function logSolver(j)
        epS(j, :) = (pb + Rb * pe - traj(j, :).').';
        oriS(j) = norm(rotvec(quat));
        wS(j) = norm(tw(4:6));
        if keep
            qS(j, :) = q.'; dqS(j, :) = dq.'; qcS(j, :) = qc.';
        end
    end
end

% =====================================================================
function s = stopOf(obs)
if any(~isfinite(obs)), s = 'nonfinite';
elseif norm(obs(1:3)) > 0.5, s = 'ep>0.5m';
elseif norm(obs(4:6)) > 2.0, s = 'ev>2m/s';
elseif norm(obs(27:29)) > 1.0, s = 'ori>1rad';
else, s = 'unknown';
end
end

function v = rotvec(qt)
% Drehvektor wie MATLAB Function2 in SK_desktop (q0 = [1 0 0 0])
if qt(1) < 0, qt = -qt; end
nv = norm(qt(2:4));
if nv < 1e-12
    v = zeros(3, 1);
else
    v = 2 * atan2(nv, max(1e-12, qt(1))) * qt(2:4) / nv;
end
end

function qo = qexp(phi)
% Quaternion der Drehung um den Drehvektor phi
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
