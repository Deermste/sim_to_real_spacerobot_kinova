function R = ext_x2_2_front(varargin)
%EXT_X2_2_FRONT  Abstand der RL-Agenten zur modellbasierten Front (Ausbau X2.2). Kein neues Rechnen.
%   R = ext_x2_2_front()
%   R = ext_x2_2_front('x13', '20261112_195325', 'x41', '20261110_233147', ...
%                      'sweeps', {'20261110_113752', '20261110_123011'})
%
%   Front: Laeufe aus ext_x2_sweep mit voller Befehlskette und Inversion (variant full_inv), J6-Grenze 0,9774 rad/s,
%   ohne Abbruch und mit ep_q4 < 5 cm (folgt wie X0.1). Pareto-Punkte in (rms_ee, ori_max).
%     F0  nur der Sweep aus X2.1 (ohne Rueckfuehrung der Basislage, Grundlage von K5)
%     F   beide Sweeps zusammen (dazu kOri 0,5 bis 5)
%   Agenten: X1.3 (50 mit Budget, 10 r1) und X4.1 (50, Gewichte 0 bis 16), X0.1 in SK_desktop. Je Agent zwei
%   Lesarten: nominale Episode (nom_rms_ee, nom_ori_max, gleicher Start wie die Front) und Mittel ueber 21 Episoden.
%   Kennzahlen je Agent und Front (wie der Faktor in X2.3):
%     fac     RMS des Agenten / kleinster RMS der Front mit ori_max <= ori_max des Agenten
%     d_rms   RMS des Agenten minus dieser RMS [m]
%     ori_r   ori_max des Agenten / kleinste ori_max der Front mit rms_ee <= RMS des Agenten
%   Ergebnis R:
%     R.front    Pareto-Punkte beider Fronten
%     R.agents   je Agent und Lesart die Kennzahlen gegen F0 und F
%     R.groups   je Gruppe (th20 ... th60, r1, w0 ... w16): n, n_follows, Median und Bereich von fac (nur folgende),
%                Median d_rms und ori_r, Anzahl nicht dominiert (fac < 1)
%     R.tests    Mann-Whitney: fac der folgenden Budget-Agenten gegen die folgenden der Gewichtsreihe und gegen r1
%   CSV: data/simulation/extension/X2_2_<Teil>_<Zeit>.csv

p = inputParser;
p.addParameter('x13', '20261112_195325');
p.addParameter('x41', '20261110_233147');
p.addParameter('sweeps', {'20261110_113752', '20261110_123011'});
p.parse(varargin{:});
o = p.Results;
setup_project;
d = sk_path('data', 'simulation', 'extension');

% --- Fronten ---
P = cell(numel(o.sweeps), 1);
for k = 1:numel(o.sweeps)
    S = readtable(fullfile(d, ['X2_sweep_' o.sweeps{k} '.csv']), 'TextType', 'string');
    if ~ismember('kOri', S.Properties.VariableNames), S.kOri = zeros(height(S), 1); end
    S = S(S.variant == "full_inv" & abs(S.j6_lim - 0.9774) < 1e-6 & S.early_stop == 0 & S.ep_q4 < 0.05, ...
          {'Kp', 'j6_side', 'kOri', 'mode', 'beta', 'rms_ee', 'ep_q4', 'max_ee', 'ori_max', 'jerk_rms'});
    S.sweep = repmat(string(o.sweeps{k}), height(S), 1);
    P{k} = S;
end
F0 = pareto(P{1});
F = pareto(vertcat(P{:}));
F0.front = repmat("F0", height(F0), 1);
F.front = repmat("F", height(F), 1);
R.front = [F0; F];

% --- Agenten ---
A = readtable(fullfile(d, ['X_eval_X1_3_' o.x13 '_agents.csv']), 'TextType', 'string');
A = A(startsWith(A.agent, "X1_"), :);
A.group = "th" + extract(A.agent, regexpPattern('(?<=_th)\d+'));
A.group(contains(A.agent, "_eta0_")) = "r1";
W = readtable(fullfile(d, ['X_eval_X4_1_' o.x41 '_agents.csv']), 'TextType', 'string');
cols = {'agent', 'group', 'follows', 'rms_ee', 'ori_max', 'nom_rms_ee', 'nom_ori_max'};
G = [A(:, cols); W(:, cols)];
G.series = repmat("X4.1", height(G), 1);
G.series(startsWith(G.group, "th")) = "X1.3";
G.series(G.group == "r1") = "X1.3 r1";
rows = {};
for i = 1:height(G)
    for rd = ["nom", "mean"]
        if rd == "nom", r = G.nom_rms_ee(i); q = G.nom_ori_max(i); else, r = G.rms_ee(i); q = G.ori_max(i); end
        [f0, dr0, or0] = gap(F0, r, q);
        [f1, dr1, or1] = gap(F, r, q);
        rows{end + 1} = struct('agent', G.agent(i), 'group', G.group(i), 'series', G.series(i), ...
            'follows', G.follows(i), 'reading', rd, 'rms_ee', r, 'ori_max', q, 'fac_F0', f0, 'd_rms_F0', dr0, ...
            'ori_r_F0', or0, 'fac_F', f1, 'd_rms_F', dr1, 'ori_r_F', or1); %#ok<AGROW>
    end
end
T = struct2table([rows{:}]);
R.agents = T;

% --- Gruppen ---
gs = ["th20", "th30", "th40", "th50", "th60", "r1", "w0", "w2", "w4", "w8", "w16"];
rows = {};
for rd = ["nom", "mean"]
    for g = gs
        X = T(T.group == g & T.reading == rd, :);
        Y = X(X.follows == 1, :);
        rows{end + 1} = struct('reading', rd, 'group', g, 'n', height(X), 'n_follows', height(Y), ...
            'fac_F0_med', median(Y.fac_F0), 'fac_F0_min', min(Y.fac_F0), 'fac_F0_max', max(Y.fac_F0), ...
            'fac_F_med', median(Y.fac_F), 'fac_F_min', min(Y.fac_F), 'fac_F_max', max(Y.fac_F), ...
            'd_rms_F0_med', median(Y.d_rms_F0), 'ori_r_F0_med', median(Y.ori_r_F0), ...
            'n_nondom_F0', sum(Y.fac_F0 < 1), 'n_nondom_F', sum(Y.fac_F < 1)); %#ok<AGROW>
    end
end
R.groups = struct2table([rows{:}]);

% --- Tests (folgende Agenten, nominale Episode und Mittel) ---
rows = {};
for rd = ["nom", "mean"]
    X = T(T.reading == rd & T.follows == 1, :);
    b = X.fac_F0(X.series == "X1.3");
    for ref = ["X4.1", "X1.3 r1"]
        c = X.fac_F0(X.series == ref);
        rows{end + 1} = struct('reading', rd, 'a', "X1.3", 'b', ref, 'n_a', numel(b), 'med_a', median(b), ...
            'n_b', numel(c), 'med_b', median(c), 'p', ranksum(b, c)); %#ok<AGROW>
    end
end
R.tests = struct2table([rows{:}]);

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
for nm = ["front", "agents", "groups", "tests"]
    writetable(R.(nm), fullfile(d, sprintf('X2_2_%s_%s.csv', nm, stamp)));
end
disp(R.front(:, {'front', 'Kp', 'j6_side', 'kOri', 'mode', 'beta', 'rms_ee', 'ori_max'}));
disp(R.groups); disp(R.tests);
end

% =====================================================================
function F = pareto(S)
% Punkte, zu denen kein anderer mit kleinerem oder gleichem RMS und kleinerer oder gleicher Basisdrehung existiert
keep = true(height(S), 1);
for i = 1:height(S)
    dom = S.rms_ee <= S.rms_ee(i) & S.ori_max <= S.ori_max(i) & ...
          (S.rms_ee < S.rms_ee(i) | S.ori_max < S.ori_max(i));
    keep(i) = ~any(dom);
end
F = S(keep, :);
[~, ia] = unique(round([F.rms_ee F.ori_max] * 1e5), 'rows', 'stable');   % gleiche Punkte aus mehreren Einstellungen
F = sortrows(F(ia, :), 'ori_max');
end

function [fac, dr, orr] = gap(F, r, q)
% Faktor und RMS-Abstand bei hoechstens gleicher Basisdrehung, Verhaeltnis der Basisdrehung bei hoechstens gleichem RMS
c = F.rms_ee(F.ori_max <= q);
if isempty(c), fac = NaN; dr = NaN; else, fac = r / min(c); dr = r - min(c); end
c = F.ori_max(F.rms_ee <= r);
if isempty(c), orr = NaN; else, orr = q / min(c); end
end
