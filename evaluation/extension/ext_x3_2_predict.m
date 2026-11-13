function T = ext_x3_2_predict(varargin)
%EXT_X3_2_PREDICT  Vorhersage fuer den Labortag X3.2 (Emulation aus und an) im kinematischen Simulator.
%   T = ext_x3_2_predict()
%   T = ext_x3_2_predict('x13', '20261112_195325', 'rates', [20 40])
%
%   Kandidaten (PLAN X3.2, E5): D16 r0 Seed 0 (Einbruch), D16 r4 Seed 2 nach 1000 Episoden (ruhig, Labortag 2),
%   D16 r4 Seeds 7, 4 (genau, Labortag 2) und 1 (ruhig, Labortag 2), alle Budget-Agenten aus X1.3 mit theta 0,03
%   und 0,05, die in X0.1 folgen und das Budget halten (ori_max_worst <= theta + 5 mrad), dazu DR-voll Seed 6
%   (ruhig, X2.4). Je Agent und Rate, nominal, Startstellung null, Halbkreis 8,5 s, J6 0,9774 rad/s:
%     ff_*     frei schwebend (wie das Training): rms, ep_q4, ori_max, folgt
%     off_*    Emulation aus (V2.4): fester Arm, Basis-Kanaele null (Basis 1e9 kg): rms, ep_q4, folgt
%     on_*     Emulation an (V2.5): fester Arm, Beobachtung aus virtual_base_step. Was der Agent sieht (emu_rms,
%              emu_ep_q4, emu_ori_max) und was der Arm physisch faehrt (phys_rms, phys_max)
%   Ohne die Schutzschicht des Deploy-Skripts (Soft-Limits, HW-Cap, OOD-Stopp) und mit idealem Servo
%   (Gelenkfilter 20 ms wie im Modell). Die Trockenlaeufe mit deploy_tracking_v25 folgen, wenn E5 steht.
%   Spalte median_budget markiert je theta den Budget-Agenten mit dem mittleren RMS (X0.1).
%   CSV: data/simulation/extension/X3_prediction_<Zeit>.csv

p = inputParser;
p.addParameter('x13', '20261112_195325');
p.addParameter('rates', [20 40]);
p.parse(varargin{:});
o = p.Results;
setup_project;
ma = sk_path('SavedAgents', 'MotionProfile');
d16 = fullfile(ma, 'D16');
c = {'r0_s0', fullfile(d16, 'D16_ppo_40hz_r0_seed0.mat'), "Einbruch (K1)", false;
     'r4_s2_1k', fullfile(d16, 'D16_ppo_40hz_r4_seed2.mat'), "r4 ruhig nach 1000 Episoden", false;
     'r4_s7', fullfile(d16, 'D16_ppo_40hz_r4_seed7_ep3000.mat'), "r4 genau", false;
     'r4_s4', fullfile(d16, 'D16_ppo_40hz_r4_seed4_ep3000.mat'), "r4 genau", false;
     'r4_s1', fullfile(d16, 'D16_ppo_40hz_r4_seed1_ep3000.mat'), "r4 ruhig", false};
A = readtable(sk_path('data', 'simulation', 'extension', ['X_eval_X1_3_' o.x13 '_agents.csv']), 'TextType', 'string');
for th = [30 50]
    B = A(contains(A.agent, sprintf('_th%d_eta5_', th)) & A.follows == 1 & A.ori_max_worst <= th / 1000 + 0.005, :);
    B = sortrows(B, 'rms_ee');
    im = ceil(height(B) / 2);
    for k = 1:height(B)
        s = extract(B.agent(k), regexpPattern('(?<=seed)\d+'));
        c(end + 1, :) = {sprintf('th%d_s%s', th, s), char(B.file(k)), sprintf("Budget %.2f", th / 1000), k == im}; %#ok<AGROW>
    end
end
c(end + 1, :) = {'drfull_s6', fullfile(ma, 'X2_4', 'X2_4_ppo_40hz_r4_drfull_seed6_ep3000.mat'), "DR-voll ruhig", false};

Kfix = ext_kin_model('base_mass', 1e9);
rows = {};
for i = 1:size(c, 1)
    assert(isfile(c{i, 2}), 'ext_x3_2_predict:file', 'Agent fehlt: %s', c{i, 2});
    pol = ext_policy(c{i, 2});
    for hz = o.rates
        args = {'j6_lim', 0.9774, 'reward_mode', 4, 'Ts_agent', 1 / hz};
        ff = ext_kinsim(pol, args{:}).metrics;
        off = ext_kinsim(pol, args{:}, 'K', Kfix).metrics;
        on = ext_kinsim(pol, args{:}, 'emulate', true).metrics;
        rows{end + 1} = struct('cand', string(c{i, 1}), 'role', c{i, 3}, 'median_budget', c{i, 4}, ...
            'rate_Hz', hz, 'ff_rms', ff.rms_ee, 'ff_ep_q4', ff.ep_q4, 'ff_ori_max', ff.ori_max, ...
            'ff_follows', double(~ff.early_stop && ff.ep_q4 < 0.05), ...
            'off_rms', off.rms_ee, 'off_ep_q4', off.ep_q4, 'off_follows', double(~off.early_stop && off.ep_q4 < 0.05), ...
            'on_emu_rms', on.emu_rms_ee, 'on_emu_ep_q4', on.emu_ep_q4, 'on_emu_ori_max', on.emu_ori_max, ...
            'on_emu_follows', double(~on.early_stop && on.emu_ep_q4 < 0.05), 'on_phys_rms', on.rms_ee, ...
            'on_phys_max', on.max_ee, 'on_early_stop', double(on.early_stop), 'file', string(c{i, 2})); %#ok<AGROW>
    end
end
T = struct2table([rows{:}]);
disp(T(:, 1:end - 1));
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
writetable(T, sk_path('data', 'simulation', 'extension', ['X3_prediction_' stamp '.csv']));
end
