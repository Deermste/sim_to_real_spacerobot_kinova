function R = ext_x2_4_eval_report(varargin)
%EXT_X2_4_EVAL_REPORT  Auswertung von X0.1 in SK_desktop fuer die DR-Agenten (X2.4) gegen w 2 aus D16.
%   R = ext_x2_4_eval_report()
%   R = ext_x2_4_eval_report('x24', '20261113_174009', 'x13', '20261112_195325', 'robust', '20261111_112342')
%
%   Gruppen: w2 (D16 r4 Seeds 0-9, X0.1 aus X1.3), drM, drfull (je 10 Seeds, X0.1 aus ext_x2_4_eval).
%   Kennzahlen je Gruppe wie X4.6: folgt (21 Episoden), RMS und ori_max (Mittel und nominal), schlechteste
%   Basisdrehung, Ruck, Faktor gegen die Front F aus X2.2 (Filter 0,95, Mittel und nominal).
%   Tests: DR-M und DR-voll je gegen w2, Mann-Whitney, Holm ueber die zwei Vergleiche je Kennzahl, folgt mit
%   Fisher exakt.
%   Gegenprobe: nominale Episode in SK_desktop gegen den kinematischen Simulator (Szenario nominal aus
%   X2_robust_<robust>_episodes.csv), je Agent Differenz von RMS und ori_max und Gleichheit von folgt.
%   CSV: data/simulation/extension/X2_4_eval_report_{agents,groups,tests}_<x24>.csv

p = inputParser;
p.addParameter('x24', '20261113_174009');
p.addParameter('x13', '20261112_195325');
p.addParameter('robust', '20261111_112342');
p.addParameter('f95', {'20261110_113752', '20261110_123011'});
p.parse(varargin{:});
o = p.Results;
setup_project;
d = sk_path('data', 'simulation', 'extension');
F = loadFront(d, o.f95);

A = readtable(fullfile(d, ['X_eval_X2_4_' o.x24 '_agents.csv']), 'TextType', 'string');
B = readtable(fullfile(d, ['X_eval_X1_3_' o.x13 '_agents.csv']), 'TextType', 'string');
B = B(startsWith(B.agent, "D16_ppo_40hz_r4_seed"), :);
B.group = repmat("w2", height(B), 1);
cols = {'agent', 'group', 'follows', 'rms_ee', 'ori_max', 'nom_rms_ee', 'nom_ori_max', 'ori_max_worst', ...
        'ep_q4_worst', 'jerk_rms', 'n_stop', 'nom_ep_q4'};
G = [B(:, cols); A(:, cols)];
G.seed = double(extract(G.agent, regexpPattern('(?<=seed)\d+')));

K = readtable(fullfile(d, ['X2_robust_' o.robust '_episodes.csv']), 'TextType', 'string');
K = K(K.scenario == "nominal", :);
kmap = struct('w2', "w2_s", 'drM', "drM_s", 'drfull', "drfull_s");

n = height(G);
G.fac_mean = NaN(n, 1); G.fac_nom = NaN(n, 1);
G.kin_rms = NaN(n, 1); G.kin_ori = NaN(n, 1); G.kin_follows = NaN(n, 1);
for i = 1:n
    G.fac_mean(i) = gap(F, G.rms_ee(i), G.ori_max(i));
    G.fac_nom(i) = gap(F, G.nom_rms_ee(i), G.nom_ori_max(i));
    if G.group(i) == "w2", continue; end      % w2 im Robustheitslauf sind die X4.1-Agenten, nicht D16
    s = kmap.(char(G.group(i))) + string(G.seed(i));
    k = find(K.subject == s, 1);
    if isempty(k), continue; end
    G.kin_rms(i) = K.rms_ee(k); G.kin_ori(i) = K.ori_max(k); G.kin_follows(i) = K.follows(k);
end
G.nom_follows = double(G.nom_ep_q4 < 0.05);
R.agents = G;

gs = ["w2", "drM", "drfull"];
rows = {};
for g = gs
    X = G(G.group == g, :);
    Y = X(X.follows == 1, :);
    rows{end + 1} = struct('group', g, 'n', height(X), 'n_follows', height(Y), 'n_stop_agents', sum(X.n_stop > 0), ...
        'rms_mean_med', median(X.rms_ee), 'rms_nom_med', median(X.nom_rms_ee), ...
        'ori_mean_med', median(X.ori_max), 'ori_nom_med', median(X.nom_ori_max), ...
        'ori_worst_med', median(X.ori_max_worst), 'jerk_med', median(X.jerk_rms), ...
        'n_calm30', sum(X.ori_max <= 0.030 & X.follows == 1), ...
        'fac_mean_med_follow', median(Y.fac_mean), 'fac_nom_med_follow', median(Y.fac_nom), ...
        'kin_d_rms_maxabs', max(abs(X.nom_rms_ee - X.kin_rms)), ...
        'kin_d_ori_maxabs', max(abs(X.nom_ori_max - X.kin_ori)), ...
        'kin_follow_mismatch', sum(X.kin_follows ~= X.nom_follows & ~isnan(X.kin_follows))); %#ok<AGROW>
end
R.groups = struct2table([rows{:}]);

mets = ["rms_ee", "nom_rms_ee", "ori_max", "nom_ori_max", "ori_max_worst", "jerk_rms", "fac_mean"];
rows = {};
for m = mets
    pv = zeros(2, 1); rr = cell(2, 1);
    for k = 1:2
        a = G.(m)(G.group == gs(k + 1)); b = G.(m)(G.group == "w2");
        if m == "fac_mean"
            a = G.(m)(G.group == gs(k + 1) & G.follows == 1); b = G.(m)(G.group == "w2" & G.follows == 1);
        end
        pv(k) = ranksum(a, b);
        rr{k} = struct('metric', m, 'a', gs(k + 1), 'b', "w2", 'n_a', numel(a), 'med_a', median(a), ...
                       'n_b', numel(b), 'med_b', median(b), 'p', pv(k));
    end
    ph = holmAdj(pv);
    for k = 1:2, rr{k}.p_holm = ph(k); rows{end + 1} = rr{k}; end %#ok<AGROW>
end
pv = zeros(2, 1); rr = cell(2, 1);
for k = 1:2
    a = G.follows(G.group == gs(k + 1)); b = G.follows(G.group == "w2");
    [~, pv(k)] = fishertest([sum(a) numel(a) - sum(a); sum(b) numel(b) - sum(b)]);
    rr{k} = struct('metric', "follows", 'a', gs(k + 1), 'b', "w2", 'n_a', numel(a), 'med_a', mean(a), ...
                   'n_b', numel(b), 'med_b', mean(b), 'p', pv(k));
end
ph = holmAdj(pv);
for k = 1:2, rr{k}.p_holm = ph(k); rows{end + 1} = rr{k}; end %#ok<AGROW>
R.tests = struct2table([rows{:}]);

for nm = ["agents", "groups", "tests"]
    writetable(R.(nm), fullfile(d, sprintf('X2_4_eval_report_%s_%s.csv', nm, o.x24)));
end
disp(R.groups); disp(R.tests);
end

% =====================================================================
function F = loadFront(d, sweeps)
P = cell(numel(sweeps), 1);
for k = 1:numel(sweeps)
    S = readtable(fullfile(d, ['X2_sweep_' sweeps{k} '.csv']), 'TextType', 'string');
    if ~ismember('kOri', S.Properties.VariableNames), S.kOri = zeros(height(S), 1); end
    S = S(S.variant == "full_inv" & abs(S.j6_lim - 0.9774) < 1e-6 & S.early_stop == 0 & S.ep_q4 < 0.05, ...
          {'rms_ee', 'ori_max'});
    P{k} = S;
end
S = vertcat(P{:});
keep = true(height(S), 1);
for i = 1:height(S)
    keep(i) = ~any(S.rms_ee <= S.rms_ee(i) & S.ori_max <= S.ori_max(i) & ...
                   (S.rms_ee < S.rms_ee(i) | S.ori_max < S.ori_max(i)));
end
F = S(keep, :);
end

function fac = gap(F, r, q)
c = F.rms_ee(F.ori_max <= q);
if isempty(c), fac = NaN; else, fac = r / min(c); end
end

function ph = holmAdj(p)
[ps, ix] = sort(p(:));
m = numel(ps);
adj = min(1, cummax((m - (1:m).' + 1) .* ps));
ph = zeros(m, 1);
ph(ix) = adj;
end
