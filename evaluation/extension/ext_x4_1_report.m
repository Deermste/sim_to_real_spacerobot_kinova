function R = ext_x4_1_report(stamp)
%EXT_X4_1_REPORT  Zusatzauswertung der Gewichtsreihe X4.1 aus den gespeicherten Dateien (kein neues Rechnen).
%   R = ext_x4_1_report('20261110_233147')
%
%   Liest X_eval_X4_1_<stamp>_agents.csv und X4_1_stats_<stamp>.mat (ext_x4_1_eval). Gibt aus:
%   - je Gewicht Median, Minimum und Maximum von ori_max und rms_ee, Median jerk_rms mit p nach Holm gegen w2
%     (aus ext_stats), Agenten mit ori_max < 0,04 rad
%   - Rangkorrelation (Spearman) ueber alle 50 Agenten: Gewicht gegen ori_max, Gewicht gegen jerk_rms,
%     ori_max gegen rms_ee
%   R  Struktur mit den Tabellen und Korrelationen

setup_project;
d = sk_path('data', 'simulation', 'extension');
A = readtable(fullfile(d, ['X_eval_X4_1_' stamp '_agents.csv']), 'TextType', 'string');
L = load(fullfile(d, ['X4_1_stats_' stamp '.mat']), 'S');
M = L.S.th030.metrics;
groups = ["w0", "w2", "w4", "w8", "w16"];
rows = {};
for g = groups
    G = A(A.group == g, :);
    j = M(M.group == g & M.metric == "jerk_rms", :);
    rows{end + 1} = struct('group', g, 'n', height(G), 'ori_med', median(G.ori_max), 'ori_min', min(G.ori_max), ...
        'ori_max', max(G.ori_max), 'rms_med', median(G.rms_ee), 'rms_min', min(G.rms_ee), ...
        'rms_max', max(G.rms_ee), 'jerk_med', j.median, 'jerk_q1', j.q1, 'jerk_q3', j.q3, ...
        'jerk_p_holm', j.p_holm, 'calm', strjoin(G.agent(G.ori_max < 0.04), ' ')); %#ok<AGROW>
end
R.groups = struct2table([rows{:}]);
[R.rho_w_ori, R.p_w_ori] = corr(A.base_w, A.ori_max, 'Type', 'Spearman');
[R.rho_w_jerk, R.p_w_jerk] = corr(A.base_w, A.jerk_rms, 'Type', 'Spearman');
[R.rho_ori_rms, R.p_ori_rms] = corr(A.ori_max, A.rms_ee, 'Type', 'Spearman');
disp(R.groups);
fprintf('Spearman Gewicht-ori %.3f (p %.3g), Gewicht-Ruck %.3f (p %.3g), ori-RMS %.3f (p %.3g)\n', ...
        R.rho_w_ori, R.p_w_ori, R.rho_w_jerk, R.p_w_jerk, R.rho_ori_rms, R.p_ori_rms);
end
