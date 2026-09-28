function [E, A] = desktop_d17_eval(nStoch)
%DESKTOP_D17_EVAL  Auswertung der Studie D17 (Gewicht des glatten Basis-Terms in Reward-Modus 4).
%   [E, A] = desktop_d17_eval()      deterministisch und 10 stochastische Episoden je Agent
%   [E, A] = desktop_d17_eval(2)     Kurztest
%
%   Agenten: D17_ppo_40hz_r4_w<w>_seed<s>_ep3000 (Gewichte 0, 4, 8, 16) und die D16-Agenten mit Gewicht 2
%   (D16_ppo_40hz_r4_seed<s>_ep3000, Seeds 0-7). Alle laufen in SK_desktop wie im Training (40 Hz, 65 kg,
%   J6 0,9774 rad/s, Halbkreis 8,5 s). Kennzahlen je Episode: EE-MSE, RMS- und groesster EE-Fehler, mittlerer
%   Fehler je Bahnviertel, Endfehler, groesster Basis-Orientierungsfehler, mittlere Basis-Drehrate, frueher Abbruch.
%   E  eine Zeile je Episode, A  Mittel je Agent und Satz (det, stoch)
%   Ergebnis: data/simulation/desktop/D17_eval_<Zeit>_episodes.csv, _agents.csv und .mat

if nargin < 1, nStoch = 10; end
setup_project;
desktop_build_model();

ag = struct('file', {}, 'weight', {}, 'seed', {});
d16 = dir(sk_path('SavedAgents', 'MotionProfile', 'D16', 'D16_ppo_40hz_r4_seed*_ep3000.mat'));
for k = 1:numel(d16)
    s = str2double(regexp(d16(k).name, 'seed(\d+)_', 'tokens', 'once'));
    ag(end + 1) = struct('file', fullfile(d16(k).folder, d16(k).name), 'weight', 2, 'seed', s); %#ok<AGROW>
end
d17 = dir(sk_path('SavedAgents', 'MotionProfile', 'D17', 'D17_ppo_40hz_r4_w*_seed*_ep3000.mat'));
for k = 1:numel(d17)
    tok = regexp(d17(k).name, '_w([\d.]+)_seed(\d+)_', 'tokens', 'once');
    ag(end + 1) = struct('file', fullfile(d17(k).folder, d17(k).name), 'weight', str2double(tok{1}), ...
                         'seed', str2double(tok{2})); %#ok<AGROW>
end
assert(~isempty(ag), 'desktop_d17_eval:none', 'Keine Agenten gefunden');

rows = {};
for a = 1:numel(ag)
    for k = 0:nStoch
        c = desktop_config('agentFile', ag(a).file, 'reward_mode', 4, 'base_w', ag(a).weight, 'j6_lim', 0.9774, ...
                           'base_mass', 65, 'explore', k > 0, 'seed', max(k, 1), 'keepTs', true);
        r = desktop_run_episode(c);
        m = r.metrics;
        epn = vecnorm(r.ts.ep, 2, 2);
        t = r.ts.t_ee;
        q = arrayfun(@(i) mean(epn(t >= (i - 1) * 8.5 / 4 & (t < i * 8.5 / 4 | (i == 4 & t <= 8.5 + 1e-9)))), 1:4);
        rows{end + 1} = struct('weight', ag(a).weight, 'seed', ag(a).seed, 'stoch', k > 0, 'draw', k, ...
            'mse_ee', m.mse_ee, 'rms_ee', sqrt(mean(epn .^ 2)), 'max_ee', m.max_ee, 'ep_q1', q(1), ...
            'ep_q2', q(2), 'ep_q3', q(3), 'ep_q4', q(4), 'ep_final', epn(end), 'ori_max', m.ori_max, ...
            'w_mean', m.w_mean, 'early_stop', double(m.early_stop), 'ret_mode4', m.ret); %#ok<AGROW>
        if k == 0
            fprintf('w %4g seed %d det: RMS %.4f m, letztes Viertel %.4f m, Basis max %.4f rad\n', ag(a).weight, ...
                    ag(a).seed, rows{end}.rms_ee, q(4), m.ori_max);
        end
    end
end
E = struct2table([rows{:}]);
A = groupsummary(E, {'weight', 'seed', 'stoch'}, 'mean', ...
    {'mse_ee', 'rms_ee', 'max_ee', 'ep_q4', 'ep_final', 'ori_max', 'w_mean', 'early_stop'});
A.Properties.VariableNames = regexprep(A.Properties.VariableNames, '^mean_', '');

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
out = sk_path('data', 'simulation', 'desktop', ['D17_eval_' stamp]);
writetable(E, [out '_episodes.csv']);
writetable(A, [out '_agents.csv']);
save([out '.mat'], 'E', 'A');
disp(groupsummary(A(~A.stoch, :), 'weight', {'mean', 'min', 'max'}, {'rms_ee', 'ep_q4', 'ori_max'}));
fprintf('Ergebnis: %s_*.csv\n', out);
end
