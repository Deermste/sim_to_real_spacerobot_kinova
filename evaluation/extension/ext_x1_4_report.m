function G = ext_x1_4_report(stamp, varargin)
%EXT_X1_4_REPORT  Zusammenfassung einer Auswertung des Sicherheitsfilters (Ausbau X1.4). Kein neues Rechnen.
%   G = ext_x1_4_report('20261113_084820')
%   G = ext_x1_4_report('20261113_084820', 'x13', '20261112_195325')   dazu die Budget-Agenten aus X1.3
%   G = ext_x1_4_report('20261113_084820', 'x13', '20261112_195325', 'diag', '20261113_084339')
%
%   Liest X1_4_eval_<stamp>.csv (ext_x1_4_eval). Je Gruppe, Ort, theta und alpha: n, RMS Median und Differenz
%   zum Median ohne Filter, Basisdrehung Median und Maximum, Anzahl folgt und haelt das Budget (wie ext_x1_4_eval),
%   Ruck Median, Eingriff Median. Mit 'x13' je theta die Budget-Agenten aus X1.3 (X0.1 in SK_desktop, folgt und
%   schlechteste Episode <= theta + 5 mrad) als Vergleich: x13_budget, x13_rms_follow (Median der folgenden).
%   Mit 'diag' dieselben Agenten in der nominalen Episode im kinematischen Simulator (ext_x1_3_diag), also im
%   selben Protokoll wie der Filter: x13nom_budget (folgt und ori_max <= theta + 5 mrad), x13nom_rms_follow.
%   Ergebnis: data/simulation/extension/X1_4_report_<stamp>.csv

p = inputParser;
p.addParameter('x13', '');
p.addParameter('diag', '');
p.parse(varargin{:});
o = p.Results;
setup_project;
d = sk_path('data', 'simulation', 'extension');
T = readtable(fullfile(d, ['X1_4_eval_' stamp '.csv']), 'TextType', 'string');
if ~isempty(o.x13)
    A = readtable(fullfile(d, ['X_eval_X1_3_' o.x13 '_agents.csv']), 'TextType', 'string');
    A = A(startsWith(A.agent, "X1_") & ~contains(A.agent, "_eta0_"), :);
    A.theta = double(extract(A.agent, regexpPattern('(?<=_th)\d+'))) / 1000;
end
if ~isempty(o.diag)
    D = readtable(fullfile(d, ['X1_3_diag_agents_' o.diag '.csv']), 'TextType', 'string');
    D = D(startsWith(D.group, "th"), :);
    D.theta = double(extractAfter(D.group, "th")) / 1000;
    D.fol = D.early_stop == 0 & D.ep_q4 < 0.05;
end
[g, grp, wh, th, al] = findgroups(T.group, T.where, T.theta, T.alpha);
rows = cell(max(g), 1);
for k = 1:max(g)
    X = T(g == k, :);
    N = T(T.group == grp(k) & T.where == "none", :);
    r = struct('group', grp(k), 'where', wh(k), 'theta', th(k), 'alpha', al(k), 'n', height(X), ...
        'rms_med', median(X.rms_ee), 'd_rms_med', median(X.rms_ee) - median(N.rms_ee), ...
        'ori_med', median(X.ori_max), 'ori_max', max(X.ori_max), 'n_follows', sum(X.follows), ...
        'n_budget', sum(X.budget), 'jerk_med', median(X.jerk_rms), 'active_med', median(X.frac_active), ...
        'x13_n', NaN, 'x13_budget', NaN, 'x13_rms_follow', NaN, 'x13nom_budget', NaN, 'x13nom_rms_follow', NaN);
    if ~isempty(o.x13) && ~isnan(th(k))
        B = A(abs(A.theta - th(k)) < 1e-9, :);
        r.x13_n = height(B);
        r.x13_budget = sum(B.follows == 1 & B.ori_max_worst <= th(k) + 0.005);
        r.x13_rms_follow = median(B.rms_ee(B.follows == 1));
    end
    if ~isempty(o.diag) && ~isnan(th(k))
        B = D(abs(D.theta - th(k)) < 1e-9, :);
        r.x13nom_budget = sum(B.fol & B.ori_max <= th(k) + 0.005);
        r.x13nom_rms_follow = median(B.rms_ee(B.fol));
    end
    rows{k} = r;
end
G = struct2table([rows{:}]);
G = sortrows(G, {'group', 'where', 'alpha', 'theta'});
disp(G);
writetable(G, fullfile(d, ['X1_4_report_' stamp '.csv']));
end
