function T = desktop_day2_tracking_pred()
%DESKTOP_DAY2_TRACKING_PRED  Vorhersage der Tracking-Laeufe von Labortag 2 auf fester Basis.
%   T = desktop_day2_tracking_pred()
%
%   Wie desktop_d3_base Teil A: Basis fest (1e9 kg), deterministisch, Halbkreis 8,5 s, Referenz nach Wandzeit.
%   Agenten der Bedingungen T40_r4_3k, T40_r0_j6, T40_r4_1k, T40_r4_3k_s4,
%   T40_r4_3k_s1 (J6-Grenze 0,9774 rad/s) und zum Vergleich der
%   CDR-Agent der Kampagne (J6 0,1 rad/s). Jeweils mit 40 Hz (Trainingsrate) und 20 Hz (Rate, die die
%   High-Level-API in der Kampagne erlaubte). Kennzahlen: RMS-Fehler, mittlerer Fehler je Bahnviertel.
%   Ergebnis: data/simulation/desktop/DAY2_tracking_pred_<Zeit>.csv

setup_project;
desktop_build_model();
d16 = sk_path('SavedAgents', 'MotionProfile', 'D16');
ag = struct('cond', {'T40_r4_3k', 'T40_r0_j6', 'T40_r4_1k', 'T40_r4_3k_s4', 'T40_r4_3k_s1', ...
                 'T40_cdr_nom'}, ...
    'file', {fullfile(d16, 'D16_ppo_40hz_r4_seed7_ep3000.mat'), fullfile(d16, 'D16_ppo_40hz_r0_seed0.mat'), ...
             fullfile(d16, 'D16_ppo_40hz_r4_seed2.mat'), fullfile(d16, 'D16_ppo_40hz_r4_seed4_ep3000.mat'), ...
             fullfile(d16, 'D16_ppo_40hz_r4_seed1_ep3000.mat'), ...
             sk_path('SavedAgents', 'MotionProfile', 'CDR', 'PPO', 'CDR2-4.mat')}, ...
    'j6', {0.9774, 0.9774, 0.9774, 0.9774, 0.9774, 0.1});
rows = {};
for a = 1:numel(ag)
    for Tsr = [0.025 0.05]
        c = desktop_config('agentFile', ag(a).file, 'agentLabel', ag(a).cond, 'Ts_agent', Tsr, ...
                           'base_mass', 1e9, 'j6_lim', ag(a).j6);
        r = desktop_run_episode(c);
        epn = vecnorm(r.ts.ep, 2, 2);
        t = r.ts.t_ee;
        q = arrayfun(@(i) mean(epn(t >= (i - 1) * 8.5 / 4 & t < i * 8.5 / 4)), 1:4);
        rows{end + 1} = struct('cond', string(ag(a).cond), 'rate_Hz', round(1 / Tsr), ...
            'rms_m', sqrt(mean(epn .^ 2)), 'max_m', max(epn), 'q1_m', q(1), 'q2_m', q(2), 'q3_m', q(3), ...
            'q4_m', q(4), 'early_stop', double(r.metrics.early_stop)); %#ok<AGROW>
        fprintf('%-12s %2d Hz: RMS %.4f m, Viertel %s m\n', ag(a).cond, round(1 / Tsr), rows{end}.rms_m, ...
                mat2str(round(q, 3)));
    end
end
T = struct2table([rows{:}]);
out = sk_path('data', 'simulation', 'desktop', ['DAY2_tracking_pred_' ...
    char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')) '.csv']);
writetable(T, out);
fprintf('Ergebnis: %s\n', out);
end
