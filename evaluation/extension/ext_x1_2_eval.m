function [T, E, A] = ext_x1_2_eval(varargin)
%EXT_X1_2_EVAL  Auswertung des Pilots X1.2 (Kostenform und Schrittweite der Lagrange-Variante).
%   [T, E, A] = ext_x1_2_eval()                    Agenten mit X0.1 auswerten und mit den dualen Kurven verbinden
%   T = ext_x1_2_eval('stamp', '20261111_150000')  vorhandene Auswertung X_eval_X1_2_<stamp> nur zusammenfassen
%
%   Agenten: die acht X1.2-Laeufe (SavedAgents/MotionProfile/X1, theta 0,03, Kosten 1 und 2, eta 0,5 und 2,
%   Seeds 0 und 1) und als Bezug D16 r4 Seeds 0-9 (Gewicht 2, ohne Nebenbedingung). X0.1 mit 21 Episoden,
%   cost_mean mit theta und Kostentyp des Agenten (fuer D16: 0,03 und Indikator).
%   Aus X1_<Name>_dual.csv je Lauf:
%     lambda_end, lambda_max     lambda nach dem letzten Block, groesstes lambda
%     lambda_slope10             mittlere Aenderung von lambda je Block ueber die letzten 10 Bloecke
%     lambda_rev15               Vorzeichenwechsel der lambda-Aenderung in den letzten 15 Bloecken (Schwingen)
%     C_last10, n_over_last10    Mittel von C und Anzahl Bloecke mit C > delta in den letzten 10 Bloecken
%     ret_last10                 mittlerer Trainings-Return der letzten 10 Bloecke
%   Ergebnis: data/simulation/extension/X1_2_summary_<Zeit>.csv

p = inputParser;
p.addParameter('stamp', '');
p.parse(varargin{:});
o = p.Results;
setup_project;
outDir = sk_path('data', 'simulation', 'extension');
ma = sk_path('SavedAgents', 'MotionProfile');

if isempty(o.stamp)
    list = struct('file', {}, 'label', {}, 'group', {}, 'opts', {});
    d = dir(fullfile(ma, 'X1', 'X1_ppo_40hz_r5_c*_th30_eta*_seed*_ep3000.mat'));
    for k = 1:numel(d)
        [~, n] = fileparts(d(k).name);
        t = regexp(n, '_c(\d)_th30_eta([\d.]+)_seed(\d+)_', 'tokens', 'once');
        list(end + 1) = struct('file', fullfile(d(k).folder, d(k).name), 'label', n, ...
                               'group', ['c' t{1} '_eta' t{2}], 'opts', {{}}); %#ok<AGROW>
    end
    d = dir(fullfile(ma, 'D16', 'D16_ppo_40hz_r4_seed*_ep3000.mat'));
    for k = 1:numel(d)
        [~, n] = fileparts(d(k).name);
        list(end + 1) = struct('file', fullfile(d(k).folder, d(k).name), 'label', n, 'group', 'r4_w2', ...
                               'opts', {{'base_w', 2}}); %#ok<AGROW>
    end
    fprintf('X1.2: %d Agenten\n', numel(list));
    [E, A] = ext_eval_batch(list, 'X1_2');
    grp = string({list.group}).';
    A.group = grp(1:height(A));
else
    L = load(fullfile(outDir, ['X_eval_X1_2_' o.stamp '.mat']));
    E = L.E; A = L.A;
    A.group = string({L.list.group}).';
end

rows = cell(height(A), 1);
for i = 1:height(A)
    r = struct('agent', A.agent(i), 'group', A.group(i), 'rms_ee', A.rms_ee(i), 'ori_max', A.ori_max(i), ...
        'ori_max_worst', A.ori_max_worst(i), 'cost_mean', A.cost_mean(i), 'cost_mean_worst', A.cost_mean_worst(i), ...
        'follows', A.follows(i), 'jerk_rms', A.jerk_rms(i), 'lambda_end', NaN, 'lambda_max', NaN, ...
        'lambda_slope10', NaN, 'lambda_rev15', NaN, 'C_last10', NaN, 'n_over_last10', NaN, 'ret_last10', NaN);
    f = fullfile(outDir, A.agent(i) + "_dual.csv");
    if isfile(f)
        D = readtable(f);
        lam = D.lambda_next;
        dl = diff([D.lambda(1); lam]);
        last15 = dl(max(1, end - 14):end);
        last15 = last15(abs(last15) > 1e-9);
        r.lambda_end = lam(end);
        r.lambda_max = max(lam);
        r.lambda_slope10 = mean(dl(max(1, end - 9):end));
        r.lambda_rev15 = sum(diff(sign(last15)) ~= 0);
        r.C_last10 = mean(D.C(max(1, end - 9):end));
        r.n_over_last10 = sum(D.C(max(1, end - 9):end) > 0.02);
        r.ret_last10 = mean(D.ret_mean(max(1, end - 9):end));
    end
    rows{i} = r;
end
T = struct2table([rows{:}]);
disp(T);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
writetable(T, fullfile(outDir, ['X1_2_summary_' stamp '.csv']));
end
