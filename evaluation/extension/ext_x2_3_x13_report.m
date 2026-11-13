function R = ext_x2_3_x13_report(stamp)
%EXT_X2_3_X13_REPORT  Robustheit der X1.3-Agenten unter den Stoerungen aus X2.3 (Ausbau X2.3, Teil 2). Kein Rechnen.
%   R = ext_x2_3_x13_report('20261113_090316')
%
%   Liest X2_robust_<stamp>_summary.csv (ext_x2_3_x13, je Szenario und Teilnehmer gemittelt ueber die
%   Wiederholungen, follows_all = folgt in allen Wiederholungen). Gruppen aus dem Label (th20 ... th60, r1, w2).
%   Je Gruppe:
%     n, n_nom_follow       Agenten und davon nominal folgende
%     follow_share         Anteil der Paare (nominal folgender Agent, Stoerszenario), in denen er weiter folgt
%     fac_med, n_nondom    Faktor wie X2.3 (gegen alle Regler im Lauf) nur ueber folgende Paare, nicht dominiert
%     n_nom_budget         Agenten mit nominal Bahn und Budget (ori_max <= theta + 5 mrad), nur Budget-Gruppen
%     budget_share         Anteil ihrer Stoerszenarien, in denen sie weiter folgen und das Budget halten
%   Je theta alle Regler mit nominal Bahn und Budget und ihr budget_share (R.ctrl, best = kleinster RMS).
%   R.nondom: die nicht dominierten folgenden Paare (Agent, Szenario).
%   Stoerszenarien: alle ausser nominal (25). CSV: data/simulation/extension/X2_3_x13_report_<Teil>_<stamp>.csv

setup_project;
d = sk_path('data', 'simulation', 'extension');
S = readtable(fullfile(d, ['X2_robust_' stamp '_summary.csv']), 'TextType', 'string');
rl = S.group == "rl";
S.group(rl) = extractBefore(S.subject(rl), "_");
isC = S.group == "ctrl";
C = S(isC, :);
tol = 0.005;
grp = ["th20", "th30", "th40", "th50", "th60", "r1", "w2"];
rows = cell(numel(grp), 1);
nd = cell(numel(grp), 1);
for k = 1:numel(grp)
    G = S(S.group == grp(k), :);
    th = NaN;
    if startsWith(grp(k), "th"), th = double(extractAfter(grp(k), "th")) / 1000; end
    N = G(G.scenario == "nominal", :);
    nf = N.subject(N.follows_all == 1);
    P = G(G.scenario ~= "nominal" & ismember(G.subject, nf), :);
    fac = nan(height(P), 1);
    P.group = repmat(grp(k), height(P), 1);
    for i = 1:height(P)
        if P.follows_all(i) ~= 1, continue; end
        c = C.rms_ee(C.scenario == P.scenario(i) & C.follows_all == 1 & C.ori_max <= P.ori_max(i));
        if isempty(c), fac(i) = Inf; else, fac(i) = P.rms_ee(i) / min(c); end
    end
    r = struct('group', grp(k), 'theta', th, 'n', height(N), 'n_nom_follow', numel(nf), ...
        'follow_share', mean(P.follows_all), 'fac_med', median(fac(isfinite(fac))), ...
        'n_nondom', sum(fac < 1 | isinf(fac)), 'n_pairs_follow', sum(~isnan(fac)), ...
        'n_nom_budget', NaN, 'budget_share', NaN);
    if ~isnan(th)
        nb = N.subject(N.follows_all == 1 & N.ori_max <= th + tol);
        Q = G(G.scenario ~= "nominal" & ismember(G.subject, nb), :);
        r.n_nom_budget = numel(nb);
        r.budget_share = mean(Q.follows_all == 1 & Q.ori_max <= th + tol);
    end
    rows{k} = r;
    nd{k} = P(fac < 1 | isinf(fac), {'group', 'subject', 'scenario', 'rms_ee', 'ori_max'}); %#ok<AGROW>
end
R.groups = struct2table([rows{:}]);
R.nondom = vertcat(nd{:});

rows = {};
for th = [0.02 0.03 0.04 0.05 0.06]
    Nc = C(C.scenario == "nominal" & C.follows_all == 1 & C.ori_max <= th + tol, :);
    if isempty(Nc), continue; end
    [~, ib] = min(Nc.rms_ee);
    for j = 1:height(Nc)
        Q = C(C.subject == Nc.subject(j) & C.scenario ~= "nominal", :);
        rows{end + 1} = struct('theta', th, 'ctrl', Nc.subject(j), 'best', j == ib, 'rms_nom', Nc.rms_ee(j), ...
            'ori_nom', Nc.ori_max(j), 'budget_share', mean(Q.follows_all == 1 & Q.ori_max <= th + tol), ...
            'follow_share', mean(Q.follows_all)); %#ok<AGROW>
    end
end
R.ctrl = struct2table([rows{:}]);
for nm = ["groups", "ctrl", "nondom"]
    writetable(R.(nm), fullfile(d, sprintf('X2_3_x13_report_%s_%s.csv', nm, stamp)));
end
disp(R.groups); disp(R.ctrl); disp(R.nondom);
end
