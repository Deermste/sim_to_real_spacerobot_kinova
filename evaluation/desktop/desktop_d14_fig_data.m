function desktop_d14_fig_data()
%DESKTOP_D14_FIG_DATA  Daten fuer die Abbildung zum Reward-Befund (Paper Sec. V, fig:reward_diag, Befund A51).
%   desktop_d14_fig_data()
%
%   Je eine deterministische Episode (SK_desktop, 40 Hz, 65 kg, Halbkreis 8,5 s, Auswertung mit reward_mode 0)
%   fuer das fruehe PPO und die D14-Agenten mit r0 und r2 (Seeds 0 bis 2). Gespeichert werden die
%   Endeffektor-Position (Referenz + Fehler) und der Betrag des Basis-Orientierungsfehlers auf einem
%   gemeinsamen Zeitraster von 25 ms.
%   Ergebnis: data/simulation/desktop/D14_fig_paths.mat (-v7, lesbar mit scipy) fuer
%   fig/src/plot_reward_diag.py im Paper-Repo

setup_project;
desktop_build_model();

d14 = sk_path('SavedAgents', 'MotionProfile', 'D14');
ag = struct('key', {'PPO_base', 'r0_s0', 'r0_s1', 'r0_s2', 'r2_s0', 'r2_s1', 'r2_s2'}, ...
    'file', {sk_path('SavedAgents', 'MotionProfile', 'Circle', 'PPO', 'SpaceKinova_PPO_agent_motionprofile.mat'), ...
             fullfile(d14, 'D14_ppo_40hz_r0_seed0.mat'), fullfile(d14, 'D14_ppo_40hz_r0_seed1.mat'), ...
             fullfile(d14, 'D14_ppo_40hz_r0_seed2.mat'), fullfile(d14, 'D14_ppo_40hz_r2_seed0.mat'), ...
             fullfile(d14, 'D14_ppo_40hz_r2_seed1.mat'), fullfile(d14, 'D14_ppo_40hz_r2_seed2.mat')});
tg = (0:0.025:8.5)';
ref = [0 + 0.2 * sin(pi / 8.5 * tg), -0.025 + 0 * tg, 1.487 + 0.2 * cos(pi / 8.5 * tg)];
out = struct('t', tg, 'ref', ref, 'keys', {{ag.key}});
for a = 1:numel(ag)
    r = desktop_run_episode(desktop_config('agentFile', ag(a).file, 'agentLabel', ag(a).key));
    e = interp1(r.ts.t_ee, r.ts.ep, tg, 'linear', NaN);
    ori = interp1(r.ts.t_ori, r.ts.ori, tg, 'linear', NaN);
    out.(ag(a).key) = struct('pos', ref + e, 'err', vecnorm(e, 2, 2), 'ori', ori, ...
        'ret', r.metrics.ret, 'max_ee', r.metrics.max_ee, 'ori_max', r.metrics.ori_max);
    fprintf('%-9s ret %7.1f  max_ee %.3f m  ori_max %.4f rad\n', ag(a).key, r.metrics.ret, r.metrics.max_ee, ...
        r.metrics.ori_max);
end
f = sk_path('data', 'simulation', 'desktop', 'D14_fig_paths.mat');
save(f, '-struct', 'out', '-v7');
fprintf('Gespeichert: %s\n', f);
end
