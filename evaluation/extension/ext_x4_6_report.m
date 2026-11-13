function R = ext_x4_6_report(varargin)
%EXT_X4_6_REPORT  Auswertung der Ablation X4.6 (V0 bis V3) gegen die Regler-Front mit derselben Kette.
%   R = ext_x4_6_report()
%   R = ext_x4_6_report('x46', '20261113_160116', 'x13', '20261112_195325', ...
%                       'f95', {'20261110_113752', '20261110_123011'}, 'f85', {'20261113_160801', '20261113_160832'})
%
%   Gruppen: V0 D16 r4 Seeds 0-9 (X0.1 aus X1.3), V1 bis V3 je 5 Seeds (X0.1 aus X4.6, alle in SK_desktop bzw.
%   der Modellkopie aus cfg). Fronten wie X2.2 (full_inv, J6 0,9774, folgt, Pareto in rms_ee und ori_max):
%     F95  Filter 0,95 (Sweeps aus X2.1 und dem Nachtrag mit kOri), gilt fuer V0, V1, V2
%     F85  Filter 0,85, dieselben Einstellungen neu gerechnet (ext_x2_sweep mit filt_a 0,85), gilt fuer V3
%     F2   Rate Limiter 2 rad/s^2, dieselben Einstellungen (ext_x2_sweep mit slew 2), gilt fuer V4 (Nachtrag)
%   V4 (Nachtrag 13.11.) wird gegen V1 getestet, einzeln, nicht in der Holm-Korrektur der drei Vergleiche.
%   Faktor fac = RMS des Agenten / kleinster RMS der Front mit ori_max <= ori_max des Agenten (X2.2), je Lesart
%   nom (nominale Episode) und mean (Mittel der 21 Episoden). fac_own gegen die Front der eigenen Kette, fac95
%   immer gegen F95.
%   Diagnose je Agent (nominale Episode in ext_kinsim, Reward-Modus 4, bei V2/V3 obs_ext und filt_a wie cfg):
%   Zweig von J6 wie ext_x1_3_diag (neg: q6 erreicht <= -1,5 rad, pos: >= 1,5 rad, sonst Vorzeichen bei 6 s,
%   mid wenn keins), Anteil begrenzter Beobachtung (q6, alle), Saettigung J2/J4/J6, Anteil der Schritte mit dem
%   Rate Limiter am Anschlag (rl_lim, J2, J4 oder J6), RMS kinematisch gegen
%   nominal in Simscape.
%   Tests (vor dem Lauf festgelegt, PLAN X4.6): jede Variante gegen die vorige, Mann-Whitney, Holm ueber die drei
%   Vergleiche je Kennzahl. Anteil folgt mit Fisher exakt.
%   Ergebnis R.agents, R.groups, R.tests, R.front (Bestwerte der Fronten bei ori_max <= 10/20/30/60 mrad).
%   CSV: data/simulation/extension/X4_6_report_<Teil>_<x46>.csv

p = inputParser;
p.addParameter('x46', '20261113_160116');
p.addParameter('x13', '20261112_195325');
p.addParameter('f95', {'20261110_113752', '20261110_123011'});
p.addParameter('f85', {'20261113_160801', '20261113_160832'});
p.addParameter('f2', {'20261113_192053', '20261113_192136'});
p.parse(varargin{:});
o = p.Results;
setup_project;
d = sk_path('data', 'simulation', 'extension');

F95 = loadFront(d, o.f95);
F85 = loadFront(d, o.f85);
F2 = loadFront(d, o.f2);                     % Rate Limiter 2 rad/s^2 (V4)

% --- Agenten ---
A = readtable(fullfile(d, ['X_eval_X4_6_' o.x46 '_agents.csv']), 'TextType', 'string');
B = readtable(fullfile(d, ['X_eval_X1_3_' o.x13 '_agents.csv']), 'TextType', 'string');
B = B(startsWith(B.agent, "D16_ppo_40hz_r4_seed"), :);
B.group = repmat("V0", height(B), 1);
cols = {'agent', 'group', 'file', 'follows', 'rms_ee', 'ori_max', 'nom_rms_ee', 'nom_ori_max', 'ori_max_worst', ...
        'ep_q4_worst', 'jerk_rms', 'nom_jerk_rms', 'n_stop'};
G = [B(:, cols); A(:, cols)];
rows = cell(height(G), 1);
lim = [0.9774 0.9774 0.9774];
for i = 1:height(G)
    S = load(char(G.file(i)), 'cfg');
    ext = isfield(S.cfg, 'variant') && ismember(S.cfg.variant, {'V2', 'V3'});
    fa = 0.95; sl = 0.5;
    if isfield(S.cfg, 'filtA'), fa = S.cfg.filtA; end
    if isfield(S.cfg, 'slew'), sl = S.cfg.slew; end
    [pol, W] = ext_policy(char(G.file(i)));
    res = ext_kinsim(pol, 'j6_lim', 0.9774, 'reward_mode', 4, 'obs_ext', ext, 'filt_a', fa, 'slew', sl);
    ts = res.ts;
    clip = ts.obs < W.lo(:).' | ts.obs > W.hi(:).';
    sat = abs(ts.a_raw(:, [2 4 6])) >= lim - 1e-6;
    rlLim = mean(any(abs(diff(ts.a_scaled(:, [2 4 6]))) >= sl * 0.025 - 1e-9, 2));   % Rate Limiter am Anschlag
    [~, k6] = min(abs(ts.t_ee - 6));
    isNeg = min(ts.q(:, 6)) <= -1.5; isPos = max(ts.q(:, 6)) >= 1.5;
    br = "mid";
    if isNeg && isPos
        br = "pos"; if ts.q(k6, 6) < 0, br = "neg"; end
    elseif isNeg
        br = "neg";
    elseif isPos
        br = "pos";
    end
    if sl > 1, Fo = F2; elseif fa < 0.9, Fo = F85; else, Fo = F95; end
    [fn, drn] = gap(Fo, G.nom_rms_ee(i), G.nom_ori_max(i));
    [fm, drm] = gap(Fo, G.rms_ee(i), G.ori_max(i));
    f95n = gap(F95, G.nom_rms_ee(i), G.nom_ori_max(i));
    f95m = gap(F95, G.rms_ee(i), G.ori_max(i));
    rows{i} = struct('agent', G.agent(i), 'group', G.group(i), 'filt_a', fa, 'slew', sl, 'follows', G.follows(i), ...
        'rms_nom', G.nom_rms_ee(i), 'ori_nom', G.nom_ori_max(i), 'rms_mean', G.rms_ee(i), ...
        'ori_mean', G.ori_max(i), 'ori_worst', G.ori_max_worst(i), 'ep_q4_worst', G.ep_q4_worst(i), ...
        'jerk_mean', G.jerk_rms(i), 'n_stop', G.n_stop(i), ...
        'fac_own_nom', fn, 'fac_own_mean', fm, 'd_rms_own_nom', drn, 'd_rms_own_mean', drm, ...
        'fac95_nom', f95n, 'fac95_mean', f95m, 'kin_rms', res.metrics.rms_ee, ...
        'kin_minus_sk', res.metrics.rms_ee - G.nom_rms_ee(i), 'q6_min', min(ts.q(:, 6)), ...
        'q6_max', max(ts.q(:, 6)), 'q6_at6', ts.q(k6, 6), 'branch', br, 'clip_q6', mean(clip(:, 18)), ...
        'clip_any', mean(any(clip, 2)), 'sat_J2', mean(sat(:, 1)), 'sat_J4', mean(sat(:, 2)), ...
        'sat_J6', mean(sat(:, 3)), 'rl_lim', rlLim);
end
T = struct2table([rows{:}]);
R.agents = T;

% --- Gruppen ---
gs = ["V0", "V1", "V2", "V3"];
if any(T.group == "V4"), gs = [gs, "V4"]; end
rows = {};
for g = gs
    X = T(T.group == g, :);
    Y = X(X.follows == 1, :);
    rows{end + 1} = struct('group', g, 'n', height(X), 'n_follows', height(Y), ...
        'rms_nom_med', median(Y.rms_nom), 'rms_nom_min', min(Y.rms_nom), 'rms_nom_max', max(Y.rms_nom), ...
        'rms_mean_med', median(Y.rms_mean), 'ori_nom_med', median(Y.ori_nom), 'ori_mean_med', median(Y.ori_mean), ...
        'ori_mean_min', min(Y.ori_mean), 'ori_mean_max', max(Y.ori_mean), 'ori_worst_med', median(Y.ori_worst), ...
        'jerk_med', median(Y.jerk_mean), ...
        'fac_own_nom_med', median(Y.fac_own_nom), 'fac_own_mean_med', median(Y.fac_own_mean), ...
        'fac_own_mean_min', min(Y.fac_own_mean), 'fac_own_mean_max', max(Y.fac_own_mean), ...
        'fac95_mean_med', median(Y.fac95_mean), 'd_rms_own_mean_med', median(Y.d_rms_own_mean), ...
        'n_neg', sum(X.branch == "neg"), 'n_pos', sum(X.branch == "pos"), 'n_mid', sum(X.branch == "mid"), ...
        'clip_q6_med', median(X.clip_q6), 'clip_any_med', median(X.clip_any), ...
        'sat_J2_med', median(X.sat_J2), 'sat_J4_med', median(X.sat_J4), 'sat_J6_med', median(X.sat_J6), ...
        'kin_minus_sk_maxabs', max(abs(X.kin_minus_sk)), 'n_nondom_own', sum(Y.fac_own_mean < 1), ...
        'rl_lim_med', median(X.rl_lim)); %#ok<AGROW>
end
R.groups = struct2table([rows{:}]);

% --- Tests: jede Variante gegen die vorige, Holm ueber die drei Vergleiche je Kennzahl ---
mets = ["fac_own_mean", "fac_own_nom", "rms_mean", "rms_nom", "ori_mean", "ori_worst", "jerk_mean"];
rows = {};
for m = mets
    pv = zeros(3, 1); rr = cell(3, 1);
    for k = 1:3
        a = T.(m)(T.group == gs(k + 1) & T.follows == 1);
        b = T.(m)(T.group == gs(k) & T.follows == 1);
        pv(k) = ranksum(a, b);
        rr{k} = struct('metric', m, 'a', gs(k + 1), 'b', gs(k), 'n_a', numel(a), 'med_a', median(a), ...
                       'n_b', numel(b), 'med_b', median(b), 'p', pv(k));
    end
    ph = holmAdj(pv);
    for k = 1:3
        rr{k}.p_holm = ph(k);
        rows{end + 1} = rr{k}; %#ok<AGROW>
    end
end
pv = zeros(3, 1); rr = cell(3, 1);
for k = 1:3
    a = T.follows(T.group == gs(k + 1)); b = T.follows(T.group == gs(k));
    [~, pv(k)] = fishertest([sum(a) numel(a) - sum(a); sum(b) numel(b) - sum(b)]);
    rr{k} = struct('metric', "follows", 'a', gs(k + 1), 'b', gs(k), 'n_a', numel(a), 'med_a', mean(a), ...
                   'n_b', numel(b), 'med_b', mean(b), 'p', pv(k));
end
ph = holmAdj(pv);
for k = 1:3, rr{k}.p_holm = ph(k); rows{end + 1} = rr{k}; end %#ok<AGROW>
% Nachtrag V4 gegen V1 (nicht vor dem Lauf festgelegt, einzeln, p_holm = p)
if ismember("V4", gs)
    for m = [mets, "follows"]
        a = T.(m)(T.group == "V4" & (T.follows == 1 | m == "follows"));
        b = T.(m)(T.group == "V1" & (T.follows == 1 | m == "follows"));
        if m == "follows"
            [~, pp] = fishertest([sum(a) numel(a) - sum(a); sum(b) numel(b) - sum(b)]);
            ma = mean(a); mb = mean(b);
        else
            pp = ranksum(a, b); ma = median(a); mb = median(b);
        end
        rows{end + 1} = struct('metric', m, 'a', "V4", 'b', "V1", 'n_a', numel(a), 'med_a', ma, ...
                               'n_b', numel(b), 'med_b', mb, 'p', pp, 'p_holm', pp); %#ok<AGROW>
    end
end
R.tests = struct2table([rows{:}]);

% --- Fronten im Vergleich ---
rows = {};
for q = [0.010 0.020 0.030 0.060]
    rows{end + 1} = struct('ori_le', q, 'rms_F95', minRms(F95, q), 'rms_F85', minRms(F85, q), ...
                           'rms_F2', minRms(F2, q)); %#ok<AGROW>
end
R.front = struct2table([rows{:}]);
F95.front = repmat("F95", height(F95), 1);
F85.front = repmat("F85", height(F85), 1);
F2.front = repmat("F2", height(F2), 1);
R.frontPts = [F95; F85; F2];

for nm = ["agents", "groups", "tests", "front", "frontPts"]
    writetable(R.(nm), fullfile(d, sprintf('X4_6_report_%s_%s.csv', nm, o.x46)));
end
disp(R.groups); disp(R.tests); disp(R.front);
end

% =====================================================================
function F = loadFront(d, sweeps)
P = cell(numel(sweeps), 1);
for k = 1:numel(sweeps)
    S = readtable(fullfile(d, ['X2_sweep_' sweeps{k} '.csv']), 'TextType', 'string');
    if ~ismember('kOri', S.Properties.VariableNames), S.kOri = zeros(height(S), 1); end
    S = S(S.variant == "full_inv" & abs(S.j6_lim - 0.9774) < 1e-6 & S.early_stop == 0 & S.ep_q4 < 0.05, ...
          {'Kp', 'j6_side', 'kOri', 'mode', 'beta', 'rms_ee', 'ep_q4', 'ori_max', 'jerk_rms'});
    S.sweep = repmat(string(sweeps{k}), height(S), 1);
    P{k} = S;
end
F = pareto(vertcat(P{:}));
end

function F = pareto(S)
% wie ext_x2_2_front
keep = true(height(S), 1);
for i = 1:height(S)
    dom = S.rms_ee <= S.rms_ee(i) & S.ori_max <= S.ori_max(i) & ...
          (S.rms_ee < S.rms_ee(i) | S.ori_max < S.ori_max(i));
    keep(i) = ~any(dom);
end
F = S(keep, :);
[~, ia] = unique(round([F.rms_ee F.ori_max] * 1e5), 'rows', 'stable');
F = sortrows(F(ia, :), 'ori_max');
end

function [fac, dr] = gap(F, r, q)
c = F.rms_ee(F.ori_max <= q);
if isempty(c), fac = NaN; dr = NaN; else, fac = r / min(c); dr = r - min(c); end
end

function r = minRms(F, q)
c = F.rms_ee(F.ori_max <= q);
if isempty(c), r = NaN; else, r = min(c); end
end

function ph = holmAdj(p)
[ps, ix] = sort(p(:));
m = numel(ps);
adj = min(1, cummax((m - (1:m).' + 1) .* ps));
ph = zeros(m, 1);
ph(ix) = adj;
end
