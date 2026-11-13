function R = ext_x1_3_diag(varargin)
%EXT_X1_3_DIAG  Wo und warum verlieren die X1.3-Agenten die Bahn? (Ausbau X1.3, Diagnose, kinematischer Simulator)
%   R = ext_x1_3_diag()
%   R = ext_x1_3_diag('x13', '20261112_195325')
%
%   Je Agent (60 aus X1.3 und D16 r4 Seeds 0-9 als Bezug) eine nominale Episode in ext_kinsim (J6 0,9774 rad/s,
%   Reward-Modus 5, Start q0 = 0 wie die nominale Episode von X0.1). Kennzahlen:
%     rms_ee, ep_q4, early_stop, t_end      wie X0.1, dazu nom_rms_sk (nominale Episode in SK_desktop) als Gegenprobe
%     t_lose      Zeit, ab der der EE-Fehler nicht mehr unter 5 cm faellt (NaN, wenn er am Ende darunter liegt)
%     t_first5    erste Zeit ab 1 s mit EE-Fehler ueber 5 cm (NaN, wenn nie), ep_end Fehler im Mittel der letzten 0,25 s
%     q6_at6      J6 bei t = 6 s (Zweig: negativ wie der Regler mit wenig Basisdrehung, A73, oder positiv)
%     sat_J2/J4/J6  Anteil der Agentenschritte mit Rohbefehl an der Geschwindigkeitsgrenze (|a| >= Grenze - 1e-6)
%     plim_J2/J4/J6 Anteil der Solverschritte mit Gelenkwinkel an der Winkelgrenze (|q| >= Grenze - 1e-3)
%     q6_min, q6_max, q4_min, q4_max
%     clip_any, clip_q4, clip_q6   Anteil der Agentenschritte mit begrenzter Beobachtung (A72)
%     act_win     mittleres |a|/Grenze von J2, J4, J6 in der Sekunde nach t_lose (nur bei Verlust)
%     sat_win     Anteil gesaettigter Befehle (J2, J4, J6) in dieser Sekunde
%     branch      Zweig von J6: neg (q6 erreicht <= -1,5 rad, wie der Regler mit wenig Basisdrehung, A73), pos
%                 (q6 erreicht >= 1,5 rad, wie die meisten r4-Agenten), mid (keins von beiden). Beides: Vorzeichen
%                 von q6 bei 6 s
%   R.agents je Agent, R.groups je Gruppe und folgt / folgt nicht, R.tests Mann-Whitney folgende gegen nicht
%   folgende Budget-Agenten, R.branch je Gruppe und Zweig n, n_follows, Median ori_max, R.fisher folgt gegen
%   Zweig neg bei theta 0,02 und 0,03 (Fisher exakt). CSV: data/simulation/extension/X1_3_diag_<Teil>_<Zeit>.csv

p = inputParser;
p.addParameter('x13', '20261112_195325');
p.parse(varargin{:});
o = p.Results;
setup_project;
d = sk_path('data', 'simulation', 'extension');
A = readtable(fullfile(d, ['X_eval_X1_3_' o.x13 '_agents.csv']), 'TextType', 'string');
j6 = 0.9774;
lim = [0.9774 0.9774 j6];
qLim = [2.41 2.66 2.01];
rows = cell(height(A), 1);
t0 = tic;
for i = 1:height(A)
    [pol, W] = ext_policy(char(A.file(i)));
    res = ext_kinsim(pol, 'j6_lim', j6, 'reward_mode', 5);
    m = res.metrics; ts = res.ts;
    epn = vecnorm(ts.ep, 2, 2);
    lastOk = find(epn <= 0.05, 1, 'last');
    tLose = NaN;
    if isempty(lastOk), tLose = 0; elseif lastOk < numel(epn), tLose = ts.t_ee(lastOk + 1); end
    k5 = find(ts.t_ee >= 1 & epn > 0.05, 1);
    tFirst = NaN;
    if ~isempty(k5), tFirst = ts.t_ee(k5); end
    epEnd = mean(epn(ts.t_ee >= ts.t_ee(end) - 0.25));
    [~, k6] = min(abs(ts.t_ee - 6));
    a = ts.a_raw(:, [2 4 6]);
    sat = abs(a) >= lim - 1e-6;
    q = ts.q(:, [2 4 6]);
    plim = abs(q) >= qLim - 1e-3;
    O = ts.obs;
    clip = O < W.lo(:).' | O > W.hi(:).';
    actWin = NaN; satWin = NaN;
    if ~isnan(tLose)
        w = ts.t_agent >= tLose & ts.t_agent < tLose + 1;
        if any(w)
            actWin = mean(abs(a(w, :)) ./ lim, 'all');
            satWin = mean(sat(w, :), 'all');
        end
    end
    g = A.group(i);
    if startsWith(A.agent(i), "X1_")
        g = "th" + extract(A.agent(i), regexpPattern('(?<=_th)\d+'));
        if contains(A.agent(i), "_eta0_"), g = "r1"; end
    end
    rows{i} = struct('agent', A.agent(i), 'group', g, 'follows', A.follows(i), 'rms_ee', m.rms_ee, ...
        'nom_rms_sk', A.nom_rms_ee(i), 'ep_q4', m.ep_q4, 'ori_max', m.ori_max, 'early_stop', double(m.early_stop), ...
        't_end', m.t_end, 't_lose', tLose, 't_first5', tFirst, 'ep_end', epEnd, 'q6_at6', ts.q(k6, 6), ...
        'sat_J2', mean(sat(:, 1)), 'sat_J4', mean(sat(:, 2)), ...
        'sat_J6', mean(sat(:, 3)), 'plim_J2', mean(plim(:, 1)), 'plim_J4', mean(plim(:, 2)), ...
        'plim_J6', mean(plim(:, 3)), 'q4_min', min(ts.q(:, 4)), 'q4_max', max(ts.q(:, 4)), ...
        'q6_min', min(ts.q(:, 6)), 'q6_max', max(ts.q(:, 6)), 'clip_any', mean(any(clip, 2)), ...
        'clip_q4', mean(clip(:, 16)), 'clip_q6', mean(clip(:, 18)), 'act_win', actWin, 'sat_win', satWin);
end
fprintf('%d Agenten in %.1f min\n', height(A), toc(t0) / 60);
T = struct2table([rows{:}]);
T.branch = repmat("mid", height(T), 1);
isNeg = T.q6_min <= -1.5; isPos = T.q6_max >= 1.5;
T.branch(isNeg) = "neg";
T.branch(isPos) = "pos";
T.branch(isNeg & isPos & T.q6_at6 < 0) = "neg";
R.agents = T;

rows = {};
for g = unique(T.group, 'stable').'
    for b = ["neg", "mid", "pos"]
        X = T(T.group == g & T.branch == b, :);
        rows{end + 1} = struct('group', g, 'branch', b, 'n', height(X), 'n_follows', sum(X.follows), ...
            'ori_med', median(X.ori_max)); %#ok<AGROW>
    end
end
R.branch = struct2table([rows{:}]);
X = T(ismember(T.group, ["th20", "th30"]), :);
tb = [sum(X.follows == 1 & X.branch == "neg"), sum(X.follows == 0 & X.branch == "neg"); ...
      sum(X.follows == 1 & X.branch ~= "neg"), sum(X.follows == 0 & X.branch ~= "neg")];
[~, pf] = fishertest(tb);
R.fisher = table(tb(1, 1), tb(1, 2), tb(2, 1), tb(2, 2), pf, 'VariableNames', ...
    {'neg_follow', 'neg_not', 'other_follow', 'other_not', 'p'});

vars = {'rms_ee', 't_lose', 't_first5', 'ep_end', 'q6_at6', 'sat_J2', 'sat_J4', 'sat_J6', 'plim_J2', 'plim_J4', 'plim_J6', 'q4_min', 'q4_max', ...
        'q6_min', 'q6_max', 'clip_any', 'clip_q4', 'clip_q6', 'act_win', 'sat_win'};
gs = unique(T.group, 'stable');
rows = {};
for g = gs.'
    for f = [1 0]
        X = T(T.group == g & T.follows == f, :);
        if isempty(X), continue; end
        r = struct('group', g, 'follows', f, 'n', height(X));
        for v = vars
            r.(v{1}) = median(X.(v{1}), 'omitnan');
        end
        rows{end + 1} = r; %#ok<AGROW>
    end
end
R.groups = struct2table([rows{:}]);

B = T(startsWith(T.group, "th"), :);
rows = {};
for v = vars
    a = B.(v{1})(B.follows == 1); b = B.(v{1})(B.follows == 0);
    pv = NaN;
    if sum(~isnan(a)) > 0 && sum(~isnan(b)) > 0, pv = ranksum(a, b); end
    rows{end + 1} = struct('var', string(v{1}), 'med_follow', median(a, 'omitnan'), ...
        'med_not', median(b, 'omitnan'), 'p', pv); %#ok<AGROW>
end
R.tests = struct2table([rows{:}]);

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
for nm = ["agents", "groups", "tests", "branch", "fisher"]
    writetable(R.(nm), fullfile(d, sprintf('X1_3_diag_%s_%s.csv', nm, stamp)));
end
disp(R.groups); disp(R.tests); disp(R.branch(R.branch.n > 0, :)); disp(R.fisher);
end
