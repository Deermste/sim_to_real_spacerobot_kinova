function [T, H] = desktop_day2_base_from_hw()
%DESKTOP_DAY2_BASE_FROM_HW  Basisdrehung aus den gemessenen Gelenkbahnen der Tracking-Laeufe (Labortag 2, D19).
%   [T, H] = desktop_day2_base_from_hw()
%
%   Auf dem festen Arm ist die Basisdrehung nicht messbar. Die gemessene Gelenkbahn jedes Hardware-Laufs wird
%   deshalb wie in D15 in die Kinematik des frei schwebenden Systems eingespielt (Impulserhaltung, Anfangsimpuls
%   null, Basis 65 kg, verallgemeinerte Jacobi-Matrix, desktop_freefloat). Ergebnis ist die Basisdrehung, die
%   genau diese Gelenkbewegung auf der frei schwebenden Basis ausloesen wuerde. Die Rechnung ist offen: Die
%   Policy reagiert nicht auf die Basis. Bei Anfangsimpuls null haengt die Drehung nur vom Weg im Gelenkraum
%   ab, nicht vom Timing. Die 20-Hz-Schleife der Hardware stoert den Vergleich deshalb nicht.
%
%   Je Agent drei Vergleichswerte:
%     ff_sim     Simscape frei schwebend, 65 kg, Trainingsrate (wie D16/D17), deterministisch
%     ff_replay  dieselbe Gelenkbahn eingespielt (Validierung der Einspielung gegen ff_sim)
%     fb_replay  Gelenkbahn der Fixed-Base-Simulation bei der Hardware-Rate (wie desktop_day2_tracking_pred)
%     hw_replay  Gelenkbahn jedes Hardware-Laufs (Kampagne 26.09. und Labortag 2)
%   Ergebnis: data/simulation/desktop/D19_base_from_hw_<Zeit>_agents.csv und _runs.csv

setup_project;
desktop_build_model();
robot = importrobot(sk_path('robot', 'SpaceKinova.urdf'), 'DataFormat', 'column');
m0 = 65;
I0 = 10.833 * eye(3);
ee = 'kinova_end_effector_link';

d16 = sk_path('SavedAgents', 'MotionProfile', 'D16');
cp = sk_path('SavedAgents', 'MotionProfile', 'Circle', 'PPO');
ag = struct( ...
    'cond', {'T40_r4_3k', 'T40_r4_3k_s4', 'T40_r4_3k_s1', 'T40_r4_1k', 'T40_r0_j6', 'T40_cdr_nom', ...
             'T40_ppo_nom', 'T10_nom'}, ...
    'file', {fullfile(d16, 'D16_ppo_40hz_r4_seed7_ep3000.mat'), fullfile(d16, 'D16_ppo_40hz_r4_seed4_ep3000.mat'), ...
             fullfile(d16, 'D16_ppo_40hz_r4_seed1_ep3000.mat'), fullfile(d16, 'D16_ppo_40hz_r4_seed2.mat'), ...
             fullfile(d16, 'D16_ppo_40hz_r0_seed0.mat'), ...
             sk_path('SavedAgents', 'MotionProfile', 'CDR', 'PPO', 'CDR2-4.mat'), ...
             fullfile(cp, 'SpaceKinova_PPO_agent_motionprofile.mat'), fullfile(cp, 'ppo_10hz.mat')}, ...
    'j6', {0.9774, 0.9774, 0.9774, 0.9774, 0.9774, 0.1, 0.1, 0.1}, ...
    'Ts', {0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.1}, ...
    'TsHw', {0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.1});

rows = {};
hrows = {};
for a = 1:numel(ag)
    % Simscape frei schwebend bei Trainingsrate
    r = desktop_run_episode(desktop_config('agentFile', ag(a).file, 'agentLabel', ag(a).cond, ...
        'Ts_agent', ag(a).Ts, 'j6_lim', ag(a).j6));
    oriSim = max(r.ts.ori);
    angFf = replay(robot, m0, I0, ee, r.ts.t_q_cmd, r.ts.q_cmd);
    % Fixed-Base-Simulation bei der Hardware-Rate
    rf = desktop_run_episode(desktop_config('agentFile', ag(a).file, 'agentLabel', ag(a).cond, ...
        'Ts_agent', ag(a).TsHw, 'base_mass', 1e9, 'j6_lim', ag(a).j6));
    angFb = replay(robot, m0, I0, ee, rf.ts.t_q_cmd, rf.ts.q_cmd);
    % Hardware-Laeufe
    files = dir(sk_path('data', 'hardware', 'campaign', ag(a).cond, '*.mat'));
    hw = nan(numel(files), 2);
    for f = 1:numel(files)
        S = load(fullfile(files(f).folder, files(f).name), 'run');
        L = S.run.log;
        n = S.run.meta.nSteps;
        ang = replay(robot, m0, I0, ee, L.t_wall(1:n), L.q(1:n, :));
        hw(f, :) = [max(ang), ang(end)];
        hrows{end + 1} = struct('cond', string(ag(a).cond), 'file', string(files(f).name), ...
            'stopReason', string(S.run.meta.stopReason), 'nSteps', n, 'ori_max', hw(f, 1), ...
            'ori_end', hw(f, 2)); %#ok<AGROW>
    end
    rows{end + 1} = struct('cond', string(ag(a).cond), 'ff_sim_ori_max', oriSim, ...
        'ff_replay_ori_max', max(angFf), 'fb_replay_ori_max', max(angFb), 'hw_runs', size(hw, 1), ...
        'hw_ori_max_mean', mean(hw(:, 1)), 'hw_ori_max_min', min(hw(:, 1)), 'hw_ori_max_max', max(hw(:, 1)), ...
        'hw_ori_end_mean', mean(hw(:, 2))); %#ok<AGROW>
    fprintf(['%-13s Simscape %.4f, Einspielung %.4f, Fixed-Base %.4f, Hardware %.4f (%.4f-%.4f, %d Laeufe)' ...
        ' rad\n'], ag(a).cond, oriSim, max(angFf), max(angFb), mean(hw(:, 1)), min(hw(:, 1)), ...
        max(hw(:, 1)), size(hw, 1));
end
T = struct2table([rows{:}]);
H = struct2table([hrows{:}]);
out = sk_path('data', 'simulation', 'desktop', ['D19_base_from_hw_' ...
    char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))]);
writetable(T, [out '_agents.csv']);
writetable(H, [out '_runs.csv']);
fprintf('Ergebnis: %s_agents.csv\n', out);
end

function ang = replay(robot, m0, I0, ee, t, q)
% Gelenkbahn einspielen, Basis aus dem Impulserhalt integrieren (wie desktop_d15_base_rotation)
n = numel(t);
R0 = eye(3);
ang = zeros(n, 1);
for k = 1:n - 1
    G = desktop_freefloat(robot, q(k, :).', m0, I0, ee);
    h = t(k + 1) - t(k);
    qd = (q(k + 1, :) - q(k, :)).' / h;
    tw = G * qd;
    R0 = R0 * expm(skew(tw(4:6) * h));
    ang(k + 1) = norm(rotvecOf(R0));
end
end

function v = rotvecOf(R)
a = rotm2axang(R);
v = a(1:3).' * a(4);
end

function S = skew(v)
S = [0 -v(3) v(2); v(3) 0 -v(1); -v(2) v(1) 0];
end
