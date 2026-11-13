function R = ext_x6_ctrl_eval(varargin)
%EXT_X6_CTRL_EVAL  Vergleichsregler auf dem X6-Paarsatz (X6.2): Erreichbarkeit, Endfehler, Einschwingzeit.
%   R = ext_x6_ctrl_eval()                         neuester X6_pairs_*.mat
%   R = ext_x6_ctrl_eval('pairs', '20261113_...', 'sets', "eval")
%
%   Regler ext_x2_controller (7 Gelenke, x, y, z, Kp 5, mu 1e-4, Nominalmodell = Strecke, Werkzeugpunkt 0,121 m,
%   Grenzen nach Datenblatt, Inversion der Kette). Referenz: Gerade p0 -> pT mit Minimum-Jerk-Profil,
%   Tm = min(max(1,5 s, 9,4 s/m * d0), 10 s), Episode 15 s. Varianten:
%     R0      beta 0
%     R0c     beta 0, gamma 0,01 (J2, J4, J6 zur Mitte, kCenter 1 1/s)
%     Rb1c    beta 1, gamma 0,01 (weniger Basisdrehung)
%     R0c_old wie R0c mit der alten Kette bei 10 Hz (Saettigung 0,9774 / 0,5774, Filter 0,95, Rate Limiter 0,5,
%             wie fixed1)
%   Neue Kette: chain_step('params') (a_max 2 rad/s^2, Platzhalter E18), 20 Hz.
%   Erfolg wie E11: Fehler zum Ziel <= 5 mm und Geschwindigkeit <= 5 mm/s, 1 s lang, innerhalb von 15 s.
%   Ein vom Regler erreichtes Paar gilt als belegt erreichbar (fuer die Laborpaare, reach_known 0).
%   CSV: data/simulation/extension/X6_ctrl_eval_{runs,groups,cells}_<Zeit>.csv

p = inputParser;
p.addParameter('pairs', '');
p.addParameter('sets', ["eval", "lab"]);
p.addParameter('parallel', true);
p.parse(varargin{:});
o = p.Results;
setup_project;
dd = sk_path('data', 'simulation', 'extension');
if isempty(o.pairs)
    d = dir(fullfile(dd, 'X6_pairs_*.mat'));
    f = fullfile(d(end).folder, d(end).name);
else
    f = fullfile(dd, ['X6_pairs_' o.pairs '.mat']);
end
L = load(f, 'P');
Pp = L.P(ismember([L.P.set], o.sets));
fprintf('%d Paare aus %s\n', numel(Pp), f);
K = ext_kin_model('tool_offset', [0; 0; 0.121]);
C = chain_step('params');
qHw = min(C.q_lim, 2 * pi);
sat = [0.9774; 0.9774; 0.9774; 0.9774; 0.5774; 0.5774; 0.5774];
V = struct('name', {'R0', 'R0c', 'Rb1c', 'R0c_old'}, 'beta', {0, 0, 1, 0}, 'gamma', {0, 0.01, 0.01, 0.01}, ...
           'old', {false, false, false, true});
n = numel(Pp);
out = cell(n, 1);
t0 = tic;
if o.parallel
    parfor i = 1:n
        out{i} = runPair(Pp(i), V, K, C, qHw, sat);
    end
else
    for i = 1:n
        out{i} = runPair(Pp(i), V, K, C, qHw, sat);
    end
end
fprintf('%d Laeufe in %.1f min\n', n * numel(V), toc(t0) / 60);
T = struct2table(vertcat(out{:}));
R.runs = T;
rows = {};
for s = unique(T.set).'
    for v = 1:numel(V)
        X = T(T.set == s & T.ctrl == V(v).name, :);
        rows{end + 1} = struct('set', s, 'ctrl', string(V(v).name), 'n', height(X), 'n_success', sum(X.success), ...
            'lag_med', median(X.t_settle(X.success == 1) - X.Tm(X.success == 1)), ...
            'lag_q90', prctile(X.t_settle(X.success == 1) - X.Tm(X.success == 1), 90), ...
            'err_end_med', median(X.err_end), 'err_end_q95', prctile(X.err_end, 95), ...
            'ori_max_med', median(X.ori_max), 'n_stop', sum(X.early_stop), 'brake_med', median(X.brake)); %#ok<AGROW>
    end
end
R.groups = struct2table([rows{:}]);
E = T(T.set == "eval", :);
R.cells = groupsummary(E, {'ctrl', 'd0bin', 'region'}, {'mean', 'median'}, {'success', 'err_end', 'ori_max'});
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
for nm = ["runs", "groups", "cells"]
    writetable(R.(nm), fullfile(dd, sprintf('X6_ctrl_eval_%s_%s.csv', nm, stamp)));
end
disp(R.groups);
end

% =====================================================================
function rows = runPair(pr, V, K, C, qHw, sat)
Tm = min(max(1.5, 9.4 * pr.d0), 10);
ref = @(t) minJerk(t, pr.p0, pr.pT, Tm);
rows = [];
for v = 1:numel(V)
    cargs = {'beta', V(v).beta, 'gamma', V(v).gamma, 'Kp', 5, 'mu', 1e-4, 'joints', 1:7, 'task', [1 2 3], ...
             'K', K, 'invert', true};
    if V(v).old
        Ts = 0.1;
        ctrl = ext_x2_controller(cargs{:}, 'Ts_agent', Ts, 'lim', sat, 'slew', 0.5, 'filt_a', 0.95, 'qLim', qHw);
        sargs = {'chain', 'full', 'lim', sat, 'slew', 0.5, 'filt_a', 0.95};
    else
        Ts = C.Ts;
        ctrl = ext_x2_controller(cargs{:}, 'Ts_agent', Ts, 'lim', C.v_max, 'chainP', C);
        sargs = {'chain', 'x6', 'chainP', C};
    end
    r = ext_kinsim([], 'ctrl', ctrl, sargs{:}, 'Ts_agent', Ts, 'T', 15, 'K', K, 'q0', pr.q0, ...
                   'reward_mode', 1, 'refFcn', ref, 'qLim', qHw);
    ts = r.ts;
    ta = ts.t_agent;
    [pa, va] = minJerk(ta, pr.p0, pr.pT, Tm);
    eT = vecnorm(ts.obs(:, 1:3) + pa - pr.pT(:).', 2, 2);
    vE = vecnorm(ts.obs(:, 4:6) + va, 2, 2);
    ok = eT <= 0.005 & vE <= 0.005;
    nHold = round(1 / Ts);
    tSet = NaN; run = 0;
    for k = 1:numel(ok)
        if ok(k), run = run + 1; else, run = 0; end
        if run >= nHold, tSet = ta(k - nHold + 1); break; end
    end
    br = NaN;
    if isfield(r.metrics, 'x6_brake'), br = r.metrics.x6_brake; end
    rows = [rows; struct('id', pr.id, 'set', pr.set, 'd0', pr.d0, 'd0bin', pr.d0bin, 'region', pr.region, ...
        'hw_ok', pr.hw_ok, 'Tm', Tm, 'ctrl', string(V(v).name), 'success', double(~isnan(tSet)), ...
        't_settle', tSet, 'err_end', mean(eT(ta >= ta(end) - 0.5)), 'err_min', min(eT), ...
        'ori_max', r.metrics.ori_max, 'early_stop', double(r.metrics.early_stop), ...
        'stop_reason', string(r.metrics.stop_reason), 'brake', br)]; %#ok<AGROW>
end
end

function [pp, vv] = minJerk(t, p0, pT, Tm)
s = min(max(t(:) / Tm, 0), 1);
f = 10 * s .^ 3 - 15 * s .^ 4 + 6 * s .^ 5;
df = (30 * s .^ 2 - 60 * s .^ 3 + 30 * s .^ 4) / Tm .* (t(:) < Tm);
pp = p0(:).' + f * (pT(:) - p0(:)).';
vv = df * (pT(:) - p0(:)).';
end
