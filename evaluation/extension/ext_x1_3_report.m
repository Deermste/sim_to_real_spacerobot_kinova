function R = ext_x1_3_report(varargin)
%EXT_X1_3_REPORT  Auswertung des Hauptlaufs X1.3 (Nebenbedingung, fuenf Budgets, r1 als Bezug). Kein neues Rechnen.
%   R = ext_x1_3_report()
%   R = ext_x1_3_report('stamp', '20261112_195325', 'x41', '20261110_233147')
%
%   Liest X_eval_X1_3_<stamp>_agents.csv (ext_x1_3_run, X0.1 mit 21 Episoden), X1_3_summary_*.csv (duale Kurven),
%   die <Agent>_train.csv der X1.3-Laeufe und X_eval_X4_1_<x41>_agents.csv (Gewichtsreihe, 50 Agenten).
%   Definitionen wie X1.2 und X4.5:
%     folgt     keine der 21 Episoden bricht ab und ep_q4 < 5 cm in jeder Episode (Spalte follows)
%     Budget    folgt und schlechteste Episode ori_max <= theta + 5 mrad
%     ori_ok    schlechteste Episode ori_max <= theta + 5 mrad, auch ohne folgt
%     Kollaps   im Training brechen mehr als die Haelfte der letzten 1000 Episoden vorzeitig ab (< 340 Schritte)
%   Ergebnis R:
%     R.groups    je Gruppe (th20 ... th60, th30 ohne Seeds 0 und 1, r1, r4_w2): n, n_follows, n_budget, n_ori_ok,
%                 n_stop_any, n_collapse, Median und IQR von rms_ee (dazu Median nur der folgenden), ori_max,
%                 ori_max_worst, ep_q4, jerk_rms, IQR von ori_max mit Bootstrap-Intervall (2000 Ziehungen, rng 0), Median lambda_end, C_last10
%     R.fisher    je theta: Budget-Anteil der Gruppe gegen r1 und gegen die 50 Agenten aus X4.1 (bei demselben
%                 theta), Fisher exakt zweiseitig, Holm ueber die fuenf Budgets je Vergleich
%     R.spearman  theta gegen rms_ee, ori_max und ori_max_worst (alle 50 Budget-Agenten und nur die folgenden)
%     R.lambda    lambda_end und C_last10: folgende gegen nicht folgende Budget-Agenten, Mann-Whitney-U
%     R.agents    je Agent alle Kennzahlen mit seed, theta, budget, collapse, stop_frac_last1000
%   CSV: data/simulation/extension/X1_3_report_<Teil>_<Zeit>.csv

p = inputParser;
p.addParameter('stamp', '20261112_195325');
p.addParameter('x41', '20261110_233147');
p.parse(varargin{:});
o = p.Results;
setup_project;
d = sk_path('data', 'simulation', 'extension');
tol = 0.005;
thetas = [0.02 0.03 0.04 0.05 0.06];

A = readtable(fullfile(d, ['X_eval_X1_3_' o.stamp '_agents.csv']), 'TextType', 'string');
sf = dir(fullfile(d, 'X1_3_summary_*.csv'));
S = readtable(fullfile(d, sf(end).name), 'TextType', 'string');
[~, is] = ismember(A.agent, S.agent);
A.lambda_end = S.lambda_end(is);
A.C_last10 = S.C_last10(is);
A.seed = double(extract(A.agent, regexpPattern('(?<=seed)\d+')));
A.theta = nan(height(A), 1);
A.kind = repmat("ref", height(A), 1);
isX1 = startsWith(A.agent, "X1_");
isR1 = isX1 & contains(A.agent, "_eta0_");
A.kind(isX1 & ~isR1) = "budget";
A.kind(isR1) = "r1";
A.theta(A.kind == "budget") = double(extract(A.agent(A.kind == "budget"), regexpPattern('(?<=_th)\d+'))) / 1000;
A.budget = A.follows == 1 & A.ori_max_worst <= A.theta + tol;
A.ori_ok = A.ori_max_worst <= A.theta + tol;
A.stop_frac_last1000 = nan(height(A), 1);
for i = find(isX1).'
    T = readtable(fullfile(d, A.agent(i) + "_train.csv"));
    A.stop_frac_last1000(i) = mean(T.steps(end - 999:end) < 340);
end
A.collapse = A.stop_frac_last1000 > 0.5;

% --- Gruppen ---
grp = {};
for th = thetas
    grp(end + 1, :) = {sprintf('th%d', round(1000 * th)), A.kind == "budget" & abs(A.theta - th) < 1e-9, th}; %#ok<AGROW>
end
grp(end + 1, :) = {'th30_ohne_s01', A.kind == "budget" & abs(A.theta - 0.03) < 1e-9 & A.seed >= 2, 0.03};
grp(end + 1, :) = {'r1', A.kind == "r1", NaN};
grp(end + 1, :) = {'r4_w2', A.kind == "ref", NaN};
rs = RandStream('twister', 'Seed', 0);
rows = cell(size(grp, 1), 1);
for k = 1:size(grp, 1)
    G = A(grp{k, 2}, :);
    iq = @(x) prctile(x, 75) - prctile(x, 25);
    bs = zeros(2000, 1);
    for b = 1:2000
        bs(b) = iq(G.ori_max(randi(rs, height(G), height(G), 1)));
    end
    r = struct('group', string(grp{k, 1}), 'theta', grp{k, 3}, 'n', height(G), 'n_follows', sum(G.follows), ...
        'n_budget', NaN, 'n_ori_ok', NaN, 'n_stop_any', sum(G.n_stop > 0), 'n_collapse', sum(G.collapse), ...
        'rms_med', median(G.rms_ee), 'rms_q1', prctile(G.rms_ee, 25), 'rms_q3', prctile(G.rms_ee, 75), ...
        'rms_med_follow', median(G.rms_ee(G.follows == 1)), ...
        'ori_med', median(G.ori_max), 'ori_q1', prctile(G.ori_max, 25), 'ori_q3', prctile(G.ori_max, 75), ...
        'ori_iqr', iq(G.ori_max), 'ori_iqr_lo', prctile(bs, 2.5), 'ori_iqr_hi', prctile(bs, 97.5), ...
        'worst_med', median(G.ori_max_worst), 'worst_max', max(G.ori_max_worst), ...
        'epq4_med', median(G.ep_q4), 'jerk_med', median(G.jerk_rms), ...
        'lambda_end_med', median(G.lambda_end), 'C_last_med', median(G.C_last10));
    if ~isnan(grp{k, 3})
        r.n_budget = sum(G.budget);
        r.n_ori_ok = sum(G.ori_ok);
    end
    rows{k} = r;
end
R.groups = struct2table([rows{:}]);

% --- Fisher je theta: Gruppe gegen r1 und gegen X4.1 ---
W = readtable(fullfile(d, ['X_eval_X4_1_' o.x41 '_agents.csv']), 'TextType', 'string');
r1 = A(A.kind == "r1", :);
rows = cell(numel(thetas), 1);
for k = 1:numel(thetas)
    th = thetas(k);
    G = A(A.kind == "budget" & abs(A.theta - th) < 1e-9, :);
    nb = sum(G.budget);
    nr = sum(r1.follows == 1 & r1.ori_max_worst <= th + tol);
    nw = sum(W.follows == 1 & W.ori_max_worst <= th + tol);
    [~, pr] = fishertest([nb, height(G) - nb; nr, height(r1) - nr]);
    [~, pw] = fishertest([nb, height(G) - nb; nw, height(W) - nw]);
    rows{k} = struct('theta', th, 'n_budget', nb, 'n', height(G), 'r1_budget', nr, 'r1_n', height(r1), ...
        'x41_budget', nw, 'x41_n', height(W), 'p_r1', pr, 'p_x41', pw);
end
F = struct2table([rows{:}]);
F.p_r1_holm = holm(F.p_r1);
F.p_x41_holm = holm(F.p_x41);
R.fisher = F;

% --- Spearman theta gegen Bahnfehler und Basisdrehung ---
B = A(A.kind == "budget", :);
rows = {};
for sub = ["alle", "folgen"]
    X = B;
    if sub == "folgen", X = B(B.follows == 1, :); end
    for v = ["rms_ee", "ori_max", "ori_max_worst"]
        [rho, pv] = corr(X.theta, X.(v), 'Type', 'Spearman');
        rows{end + 1} = struct('subset', sub, 'var', v, 'n', height(X), 'rho', rho, 'p', pv); %#ok<AGROW>
    end
end
R.spearman = struct2table([rows{:}]);

% --- lambda am Ende und C bei folgenden gegen nicht folgende Budget-Agenten (Mann-Whitney-U) ---
rows = {};
for v = ["lambda_end", "C_last10"]
    a = B.(v)(B.follows == 1); b = B.(v)(B.follows == 0);
    rows{end + 1} = struct('var', v, 'n_follow', numel(a), 'med_follow', median(a), 'n_not', numel(b), ...
        'med_not', median(b), 'p', ranksum(a, b)); %#ok<AGROW>
end
R.lambda = struct2table([rows{:}]);
R.agents = A;

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
for nm = ["groups", "fisher", "spearman", "lambda", "agents"]
    writetable(R.(nm), fullfile(d, sprintf('X1_3_report_%s_%s.csv', nm, stamp)));
end
disp(R.groups); disp(R.fisher); disp(R.spearman); disp(R.lambda);
end

function q = holm(p)
[ps, ix] = sort(p(:));
m = numel(ps);
adj = min(1, cummax((m - (0:m - 1)).' .* ps));
q = zeros(size(p));
q(ix) = adj;
end
