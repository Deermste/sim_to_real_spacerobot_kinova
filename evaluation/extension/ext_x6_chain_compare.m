function R = ext_x6_chain_compare(varargin)
%EXT_X6_CHAIN_COMPARE  Derselbe Regler mit alter und neuer Befehlskette auf Set-Point-Paaren (X6, E18).
%   R = ext_x6_chain_compare()
%   R = ext_x6_chain_compare('nPairs', 20)        kleiner Lauf
%
%   Paare (vorlaeufig, ohne Kollisionspruefung, X6.1 ersetzt sie spaeter): Start q0 und Zielstellung qT
%   gleichverteilt (Endlosgelenke [-pi, pi], sonst Datenblattgrenze minus 5 Grad), fester Seed 0. Zielpunkt pT = Lage des
%   EE (URDF-Punkt) nach einer offenen Gelenkbahn von q0 nach qT im kinematischen Simulator (frei schwebend,
%   gleichmaessig, hoechstens 0,4 rad/s), also unter frei schwebender Kinematik erreichbar. Behalten werden Paare
%   mit d0 = |pT - p0| zwischen 0,05 und 1,2 m.
%   Regler: ext_x2_controller R0 (beta 0, Kp 5, mu 1e-4), 7 Gelenke, Aufgabe x, y, z, Inversion der jeweiligen
%   Kette, Nominalmodell = Strecke. Referenz: Gerade p0 -> pT mit Minimum-Jerk-Profil, Dauer
%   Tm = min(max(1,5 s, 9,4 s/m * d0), 10 s) (Spitzengeschwindigkeit etwa 0,2 m/s), danach Halten. Episode 15 s.
%   Ketten:
%     O10  alt, 10 Hz (wie fixed1): Saettigung 0,9774 / 0,5774, Filter 0,95 / 0,05 je Schritt, Rate Limiter 0,5
%     O20  alt, 20 Hz
%     A    neu (chain_step), 20 Hz, v_max wie die alte Saettigung, a_max 0,5 rad/s^2: nur der Filter faellt weg
%     B    neu, v_max 0,95 * HW-Cap, a_max 0,5
%     C    neu, v_max 0,95 * HW-Cap, a_max 2 (Platzhalter, E18)
%     D    wie C, dazu Filter tau 0,1 s
%   Strecke und Regler mit den Winkelgrenzen des Datenblatts (chain_step('params').q_lim), auch bei der alten Kette.
%   Erfolg wie E11: EE-Fehler zum Ziel <= 5 mm und EE-Geschwindigkeit <= 5 mm/s, 1 s lang, innerhalb von 15 s.
%   Kennzahlen je Paar und Kette: Erfolg, Einschwingzeit (Beginn des Haltefensters), Endfehler (Mittel der
%   letzten 0,5 s), groesste Basisdrehung, Abbruch, Anteil Bremskurve.
%   CSV: data/simulation/extension/X6_chain_compare_{pairs,runs,groups}_<Zeit>.csv

p = inputParser;
p.addParameter('nPairs', 100);
p.addParameter('seed', 0);
p.parse(varargin{:});
o = p.Results;
setup_project;
K = ext_kin_model();

% --- Paare ---
P0 = chain_step('params');
qHw = min(P0.q_lim, 2 * pi);                 % Datenblatt, Endlosgelenke 2 pi (Strecke und Regler)
fin = isfinite(P0.q_lim);
qLim = pi * ones(7, 1);
qLim(fin) = P0.q_lim(fin) - deg2rad(5);      % Starts und Ziele: Datenblatt minus 5 Grad, Endlosgelenke [-pi, pi]
rs = RandStream('mt19937ar', 'Seed', o.seed);
pr = {};
tries = 0;
while numel(pr) < o.nPairs
    tries = tries + 1;
    q0 = (2 * rand(rs, 7, 1) - 1) .* qLim;
    qT = (2 * rand(rs, 7, 1) - 1) .* qLim;
    Tm = max(abs(qT - q0)) / 0.4;
    n = ceil(Tm / 0.05);
    seq = repmat(((qT - q0) / (n * 0.05)).', n + 1, 1);
    seq(end, :) = 0;
    r = ext_kinsim([], 'actionSeq', seq, 'chain', 'sat', 'lim', 0.5 * ones(7, 1), 'Ts_agent', 0.05, ...
                   'T', (n + 10) * 0.05, 'K', K, 'q0', q0, 'reward_mode', 1, 'noStop', true, 'qLim', qHw, ...
                   'refFcn', @(t) zeros(numel(t), 3));
    p0 = r.ts.ep(1, :).'; pT = r.ts.ep(end, :).';
    d0 = norm(pT - p0);
    if d0 < 0.05 || d0 > 1.2, continue; end
    pr{end + 1} = struct('pair', numel(pr) + 1, 'q0', q0, 'qT', qT, 'p0', p0, 'pT', pT, 'd0', d0, ...
                         'ori_path', r.metrics.ori_max); %#ok<AGROW>
end
fprintf('%d Paare aus %d Ziehungen\n', numel(pr), tries);

% --- Ketten ---
sat = [0.9774; 0.9774; 0.9774; 0.9774; 0.5774; 0.5774; 0.5774];
P = chain_step('params');
PA = P; PA.v_max = sat; PA.a_max = 0.5; PA.a_brake = 0.4;
PB = P; PB.a_max = 0.5; PB.a_brake = 0.4;
PC = P;
PD = P; PD.tau = 0.1;
ch = struct('name', {'O10', 'O20', 'A', 'B', 'C', 'D'}, 'Ts', {0.1, 0.05, 0.05, 0.05, 0.05, 0.05}, ...
            'P', {[], [], PA, PB, PC, PD});

% --- Laeufe ---
nP = numel(pr); nC = numel(ch);
out = cell(nP, 1);
t0 = tic;
parfor i = 1:nP
    out{i} = runPair(pr{i}, ch, K, sat, qHw);
end
fprintf('%d Laeufe in %.1f min\n', nP * nC, toc(t0) / 60);
Rr = struct2table(vertcat(out{:}));
tmp = cellfun(@(x) rmfield(x, {'q0', 'qT', 'p0', 'pT'}), pr, 'UniformOutput', false);
Pp = struct2table([tmp{:}]);
R.pairs = Pp; R.runs = Rr;

rows = {};
for c = 1:nC
    X = Rr(Rr.chain == ch(c).name, :);
    rows{end + 1} = struct('chain', string(ch(c).name), 'n', height(X), 'n_success', sum(X.success), ...
        'n_stop', sum(X.early_stop), 't_settle_med', median(X.t_settle(X.success == 1)), ...
        'err_end_med', median(X.err_end), 'err_end_q95', prctile(X.err_end, 95), ...
        'ori_max_med', median(X.ori_max), 'brake_med', median(X.brake)); %#ok<AGROW>
end
R.groups = struct2table([rows{:}]);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
for nm = ["pairs", "runs", "groups"]
    writetable(R.(nm), sk_path('data', 'simulation', 'extension', sprintf('X6_chain_compare_%s_%s.csv', nm, stamp)));
end
disp(R.groups);
end

% =====================================================================
function rows = runPair(pr, ch, K, sat, qHw)
d0 = pr.d0;
Tm = min(max(1.5, 9.4 * d0), 10);
ref = @(t) minJerk(t, pr.p0, pr.pT, Tm);
rows = [];
for c = 1:numel(ch)
    Ts = ch(c).Ts;
    cargs = {'beta', 0, 'Kp', 5, 'mu', 1e-4, 'joints', 1:7, 'task', [1 2 3], 'K', K, 'invert', true, ...
             'Ts_agent', Ts};
    if isempty(ch(c).P)
        ctrl = ext_x2_controller(cargs{:}, 'lim', sat, 'slew', 0.5, 'filt_a', 0.95, 'qLim', qHw);
        sargs = {'chain', 'full', 'lim', sat, 'slew', 0.5, 'filt_a', 0.95};
    else
        Pc = ch(c).P; Pc.Ts = Ts;
        ctrl = ext_x2_controller(cargs{:}, 'lim', Pc.v_max, 'chainP', Pc);
        sargs = {'chain', 'x6', 'chainP', Pc};
    end
    r = ext_kinsim([], 'ctrl', ctrl, sargs{:}, 'Ts_agent', Ts, 'T', 15, 'K', K, 'q0', pr.q0, ...
                   'reward_mode', 1, 'refFcn', ref, 'qLim', qHw);
    ts = r.ts;
    ta = ts.t_agent;
    [pa, va] = minJerk(ta, pr.p0, pr.pT, Tm);
    eT = vecnorm(ts.obs(:, 1:3) + pa - pr.pT.', 2, 2);   % Fehler zum Ziel
    vE = vecnorm(ts.obs(:, 4:6) + va, 2, 2);             % EE-Geschwindigkeit
    ok = eT <= 0.005 & vE <= 0.005;
    nHold = round(1 / Ts);
    tSet = NaN;
    run = 0;
    for k = 1:numel(ok)
        if ok(k), run = run + 1; else, run = 0; end
        if run >= nHold, tSet = ta(k - nHold + 1); break; end
    end
    br = NaN;
    if isfield(r.metrics, 'x6_brake'), br = r.metrics.x6_brake; end
    rows = [rows; struct('pair', pr.pair, 'd0', d0, 'Tm', Tm, 'chain', string(ch(c).name), ...
        'success', double(~isnan(tSet)), 't_settle', tSet, 'err_end', mean(eT(ta >= ta(end) - 0.5)), ...
        'err_min', min(eT), 'ori_max', r.metrics.ori_max, 'early_stop', double(r.metrics.early_stop), ...
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
