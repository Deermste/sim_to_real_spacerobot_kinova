function R = ext_x4_5_thresholds(varargin)
%EXT_X4_5_THRESHOLDS  Sensitivitaet der Kernaussagen gegen die eigenen Schwellen (Ausbau X4.5, kein Training).
%   R = ext_x4_5_thresholds()
%   R = ext_x4_5_thresholds('x41', '20261110_233147', 'robust', '20261111_112342', 'x14', '20261110_130405', ...
%                           'x12', '20261111_150856')
%
%   Gitter (vor der Rechnung festgelegt, PLAN X4.5):
%     folgt    ep_q4 < 3 / 5 / 8 cm in jeder Episode ohne Abbruch, oder RMS < 3 / 5 cm in jeder Episode
%     Budget   schlechteste Episode ori_max <= theta + 0 / 5 / 10 mrad
%     ruhig    mittleres ori_max < 30 / 40 / 50 mrad
%   Aussagen und Kriterium "haelt" (ebenfalls vorher festgelegt):
%     K2   X4.1: kein Gewicht unterscheidet sich von w 2 in den Anteilen folgt, Budget 0,03, Budget 0,05, ruhig
%          (Fisher exakt, Holm ueber die vier Gewichte, alle p_holm >= 0,05)
%     K6   Robustheit: gegen die vier Regler aus X2.1 ist der Median des Faktors in jeder Gruppe ohne
%          Randomisierung >= 1,5 und hoechstens 5 % der Agent-Szenario-Paare sind nicht dominiert
%     K8   Robustheit: DR-voll folgt in mehr Szenarien mit allen Seeds als w 2, und der Median des Faktors gegen
%          die sieben Regler ist >= 1,5
%     F    X1.4: hinter der Kette (Ort "nach", alpha 5) haelt jeder Agent, der folgt, das Budget
%     X12  X1.2: mit Kosten A halten mindestens so viele Agenten das Budget wie mit Kosten B
%   Runde 2 (13.11.2026, nach X1.3, Optionen 'x13', 'x42'):
%     K9a  unter den folgenden Budget-Agenten Spearman theta gegen ori_max rho >= 0,5 und p < 0,05
%     K9b  Budget-Agenten folgen seltener als r4 w 2 (D16 Seeds 0-9), Fisher p < 0,05
%     K9c  theta 0,02 und 0,03: mehr Budget-Agenten mit Bahn und Budget als in X4.1, Fisher, Holm p < 0,05
%     K1   D14 und D16: r0 folgt seltener als r1 und r2, Fisher p < 0,05
%   R.(Aussage) Tabelle je Gitterpunkt mit den tragenden Kennzahlen und der Spalte holds. Dazu CSV-Dateien
%   data/simulation/extension/X4_5_<Aussage>_<Zeit>.csv und eine Uebersicht R.summary.

p = inputParser;
p.addParameter('x41', '20261110_233147');
p.addParameter('robust', '20261111_112342');
p.addParameter('x14', '20261110_130405');
p.addParameter('x12', '20261111_150856');
p.addParameter('x13', '20261112_195325');
p.addParameter('x42', '20261111_144608');
p.parse(varargin{:});
o = p.Results;
setup_project;
d = sk_path('data', 'simulation', 'extension');
fol = {'epq4', 0.03; 'epq4', 0.05; 'epq4', 0.08; 'rms', 0.03; 'rms', 0.05};
tols = [0 0.005 0.01];
calms = [0.03 0.04 0.05];
folName = @(k) sprintf('%s<%g', fol{k, 1}, fol{k, 2});

% --- K2 (X4.1) ---
E = readtable(fullfile(d, ['X_eval_X4_1_' o.x41 '_episodes.csv']), 'TextType', 'string');
A = readtable(fullfile(d, ['X_eval_X4_1_' o.x41 '_agents.csv']), 'TextType', 'string');
ws = ["w0", "w4", "w8", "w16"];
rows = {};
for kf = 1:size(fol, 1)
    fo = agentFollows(E, A.agent, fol{kf, :});
    for tol = tols
        for c = calms
            b30 = A.ori_max_worst <= 0.03 + tol;
            b50 = A.ori_max_worst <= 0.05 + tol;
            calm = A.ori_max < c;
            P = [pHolm(A.group, fo, ws), pHolm(A.group, b30, ws), pHolm(A.group, b50, ws), pHolm(A.group, calm, ws)];
            r = struct('follow', string(folName(kf)), 'tol', tol, 'calm', c, ...
                'n_follows', sum(fo), 'n_b30', sum(b30), 'n_b50', sum(b50), 'n_calm', sum(calm), ...
                'calm_per_w', strjoin(string(arrayfun(@(g) sum(calm(A.group == g)), ["w0" "w2" ws(2:end)])), '/'), ...
                'min_p_holm', min(P(:)), 'holds', min(P(:)) >= 0.05);
            rows{end + 1} = r; %#ok<AGROW>
        end
    end
end
R.K2 = struct2table([rows{:}]);

% --- K6, K8 (Robustheit) ---
Er = readtable(fullfile(d, ['X2_robust_' o.robust '_episodes.csv']), 'TextType', 'string');
rl = Er.group == "rl";
Er.group(rl) = extractBefore(Er.subject(rl), "_");
c4 = ["R0", "Rb1", "Rb21", "Rb46"];
rows6 = {}; rows8 = {};
for kf = 1:size(fol, 1)
    S = robustSummary(Er, fol{kf, :});
    [F4, N4] = dominance(S, c4);
    [F7, N7, AF7] = dominance(S, unique(S.subject(S.group == "ctrl")).');
    g0 = ["w0", "w2", "w4", "w8", "w16"];
    fm = arrayfun(@(g) median(F4{g}(~isinf(F4{g}))), g0);
    nd = arrayfun(@(g) N4.(g), g0);
    np = arrayfun(@(g) numel(F4{g}), g0);
    rows6{end + 1} = struct('follow', string(folName(kf)), 'fac_med_min', min(fm), ...
        'nondom_share', sum(nd) / sum(np), 'nondom', sum(nd), 'pairs', sum(np), ...
        'holds', min(fm) >= 1.5 && sum(nd) / sum(np) <= 0.05); %#ok<AGROW>
    fFull = median(F7{"dr_full"}(~isinf(F7{"dr_full"})));
    rows8{end + 1} = struct('follow', string(folName(kf)), 'scen_all_dr_full', AF7.dr_full, ...
        'scen_all_w2', AF7.w2, 'scen_all_dr_M', AF7.dr_M, 'fac_med_dr_full', fFull, ...
        'fac_med_dr_M', median(F7{"dr_M"}(~isinf(F7{"dr_M"}))), 'nondom_dr_full', N7.dr_full, ...
        'holds', AF7.dr_full > AF7.w2 && fFull >= 1.5); %#ok<AGROW>
    if kf == 2   % Selbstpruefung gegen ext_x2_robust_report (folgt wie X0.1)
        fprintf('Selbstpruefung ep_q4 < 5 cm: nicht dominiert w2 %d (4 Regler), dr_full %d (7 Regler)\n', ...
                N4.w2, N7.dr_full);
    end
    clear F4 N4 AF4 F7 N7 AF7
end
R.K6 = struct2table([rows6{:}]);
R.K8 = struct2table([rows8{:}]);

% --- F (X1.4) ---
X = readtable(fullfile(d, ['X1_4_eval_' o.x14 '.csv']), 'TextType', 'string');
X = X(X.where == "after" & X.alpha == 5 & X.group == "r4", :);
rows = {};
for kf = 1:3
    for tol = tols
        fo = X.early_stop == 0 & X.ep_q4 < fol{kf, 2};
        hb = fo & X.ori_max <= X.theta + tol;
        rows{end + 1} = struct('follow', string(folName(kf)), 'tol', tol, 'n', height(X), 'n_follows', sum(fo), ...
            'n_budget', sum(hb), 'max_over_theta', max(X.ori_max(fo) - X.theta(fo)), 'holds', all(hb(fo))); %#ok<AGROW>
    end
end
R.F = struct2table([rows{:}]);

% --- X12 (X1.2) ---
E2 = readtable(fullfile(d, ['X_eval_X1_2_' o.x12 '_episodes.csv']), 'TextType', 'string');
A2 = readtable(fullfile(d, ['X_eval_X1_2_' o.x12 '_agents.csv']), 'TextType', 'string');
isA = contains(A2.agent, "_c1_"); isB = contains(A2.agent, "_c2_");
rows = {};
for kf = 1:size(fol, 1)
    fo = agentFollows(E2, A2.agent, fol{kf, :});
    for tol = tols
        hb = fo & A2.ori_max_worst <= 0.03 + tol;
        rows{end + 1} = struct('follow', string(folName(kf)), 'tol', tol, 'A_follows', sum(fo & isA), ...
            'A_budget', sum(hb & isA), 'B_follows', sum(fo & isB), 'B_budget', sum(hb & isB), ...
            'holds', sum(hb & isA) >= sum(hb & isB)); %#ok<AGROW>
    end
end
R.X12 = struct2table([rows{:}]);

% --- Runde 2: K9 (X1.3) und K1 (X4.2), Kriterien in PLAN X4.5 vor der Rechnung festgelegt ---
E3 = readtable(fullfile(d, ['X_eval_X1_3_' o.x13 '_episodes.csv']), 'TextType', 'string');
A3 = readtable(fullfile(d, ['X_eval_X1_3_' o.x13 '_agents.csv']), 'TextType', 'string');
isB = startsWith(A3.agent, "X1_") & ~contains(A3.agent, "_eta0_");
isR4 = startsWith(A3.agent, "D16_");
th = nan(height(A3), 1);
th(isB) = double(extract(A3.agent(isB), regexpPattern('(?<=_th)\d+'))) / 1000;
thetas = [0.02 0.03 0.04 0.05 0.06];
rowsA = {}; rowsB = {}; rowsC = {};
for kf = 1:size(fol, 1)
    fo3 = agentFollows(E3, A3.agent, fol{kf, :});
    foW = agentFollows(E, A.agent, fol{kf, :});
    X = isB & fo3;
    [rho, pv] = corr(th(X), A3.ori_max(X), 'Type', 'Spearman');
    rowsA{end + 1} = struct('follow', string(folName(kf)), 'n', sum(X), 'rho', rho, 'p', pv, ...
        'holds', rho >= 0.5 && pv < 0.05); %#ok<AGROW>
    t = [sum(fo3 & isB), sum(~fo3 & isB); sum(fo3 & isR4), sum(~fo3 & isR4)];
    [~, pb] = fishertest(t);
    rowsB{end + 1} = struct('follow', string(folName(kf)), 'budget_follows', t(1, 1), 'budget_n', sum(isB), ...
        'r4_follows', t(2, 1), 'r4_n', sum(isR4), 'p', pb, ...
        'holds', pb < 0.05 && t(1, 1) / sum(isB) < t(2, 1) / sum(isR4)); %#ok<AGROW>
    for tol = tols
        nb = zeros(1, 5); nw = zeros(1, 5); pc = ones(1, 5);
        for k = 1:5
            s = isB & abs(th - thetas(k)) < 1e-9;
            hb = s & fo3 & A3.ori_max_worst <= thetas(k) + tol;
            hw = foW & A.ori_max_worst <= thetas(k) + tol;
            nb(k) = sum(hb); nw(k) = sum(hw);
            [~, pc(k)] = fishertest([nb(k), sum(s) - nb(k); nw(k), height(A) - nw(k)]);
        end
        ph = holmAdj(pc);
        rowsC{end + 1} = struct('follow', string(folName(kf)), 'tol', tol, 'n_budget', strjoin(string(nb), '/'), ...
            'n_x41', strjoin(string(nw), '/'), 'p_holm_th20', ph(1), 'p_holm_th30', ph(2), ...
            'holds', all(ph(1:2) < 0.05) && all(nb(1:2) / 10 > nw(1:2) / height(A))); %#ok<AGROW>
    end
end
R.K9a = struct2table([rowsA{:}]);
R.K9b = struct2table([rowsB{:}]);
R.K9c = struct2table([rowsC{:}]);

E4 = readtable(fullfile(d, ['X_eval_X4_2_' o.x42 '_episodes.csv']), 'TextType', 'string');
A4 = readtable(fullfile(d, ['X_eval_X4_2_' o.x42 '_agents.csv']), 'TextType', 'string');
I = readtable(fullfile(d, 'X4_2_inventory.csv'), 'TextType', 'string');
[~, ia] = ismember(A4.agent, I.label);
A4 = A4(ismember(I.group(ia), ["D14", "D16"]) & ismember(A4.reward_mode, [0 1 2]), :);
r0 = A4.reward_mode == 0;
rows = {};
for kf = 1:size(fol, 1)
    fo = agentFollows(E4, A4.agent, fol{kf, :});
    t = [sum(fo & r0), sum(~fo & r0); sum(fo & ~r0), sum(~fo & ~r0)];
    [~, p1] = fishertest(t);
    rows{end + 1} = struct('follow', string(folName(kf)), 'r0_follows', t(1, 1), 'r0_n', sum(r0), ...
        'r12_follows', t(2, 1), 'r12_n', sum(~r0), 'p', p1, ...
        'holds', p1 < 0.05 && t(1, 1) / sum(r0) < t(2, 1) / sum(~r0)); %#ok<AGROW>
end
R.K1 = struct2table([rows{:}]);

names = fieldnames(R);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
sm = table(string(names), cellfun(@(n) height(R.(n)), names), cellfun(@(n) sum(R.(n).holds), names), ...
           'VariableNames', {'statement', 'grid_points', 'holds'});
for k = 1:numel(names)
    writetable(R.(names{k}), fullfile(d, ['X4_5_' names{k} '_' stamp '.csv']));
    fprintf('\n=== %s ===\n', names{k});
    disp(R.(names{k}));
end
R.summary = sm;
disp(sm);
end

% =====================================================================
function fo = agentFollows(E, agents, kind, thr)
% folgt: keine Episode bricht ab und jede Episode unter der Schwelle (ep_q4 oder rms_ee)
fo = false(numel(agents), 1);
for i = 1:numel(agents)
    e = E(E.agent == agents(i), :);
    if kind == "epq4", v = e.ep_q4; else, v = e.rms_ee; end
    fo(i) = all(e.early_stop == 0) && all(v < thr);
end
end

function p = pHolm(group, x, ws)
% Fisher exakt jeder Gruppe gegen w2, Holm ueber die Gruppen
ref = group == "w2";
p = ones(1, numel(ws));
for k = 1:numel(ws)
    s = group == ws(k);
    t = [sum(x(s)), sum(~x(s)); sum(x(ref)), sum(~x(ref))];
    [~, p(k)] = fishertest(t);
end
[ps, ix] = sort(p);
m = numel(p);
adj = min(1, cummax((m - (0:m - 1)) .* ps));
p(ix) = adj;
end

function q = holmAdj(p)
[ps, ix] = sort(p);
m = numel(p);
q = p;
q(ix) = min(1, cummax((m - (0:m - 1)) .* ps));
end

function S = robustSummary(E, kind, thr)
% je Szenario und Teilnehmer: Mittel von RMS und ori_max ueber die Wiederholungen, folgt in allen
[g, sc, su, gr] = findgroups(E.scenario, E.subject, E.group);
if kind == "epq4", v = E.ep_q4; else, v = E.rms_ee; end
ok = E.early_stop == 0 & v < thr;
S = table(sc, su, gr, splitapply(@mean, E.rms_ee, g), splitapply(@mean, E.ori_max, g), ...
          splitapply(@all, ok, g), 'VariableNames', {'scenario', 'subject', 'group', 'rms_ee', 'ori_max', 'follows_all'});
end

function [F, N, AF] = dominance(S, ctrl)
% Faktor wie X2.3 je Gruppe, Anzahl nicht dominiert, Anzahl Szenarien, in denen alle Agenten folgen
groups = unique(S.group(S.group ~= "ctrl")).';
F = dictionary(); N = struct(); AF = struct();
for g = groups
    F(g) = {[]}; N.(g) = 0; AF.(g) = 0;
end
for s = unique(S.scenario).'
    C = S(S.scenario == s & ismember(S.subject, ctrl) & S.follows_all, :);
    for g = groups
        G = S(S.scenario == s & S.group == g, :);
        f = inf(height(G), 1);
        for k = 1:height(G)
            r = C.rms_ee(C.ori_max <= G.ori_max(k));
            if ~isempty(r), f(k) = G.rms_ee(k) / min(r); end
        end
        F(g) = {[F{g}; f]};
        N.(g) = N.(g) + sum(isinf(f) | f < 1);
        AF.(g) = AF.(g) + all(G.follows_all);
    end
end
end
