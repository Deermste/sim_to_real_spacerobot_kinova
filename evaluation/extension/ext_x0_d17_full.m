function [E, A, S] = ext_x0_d17_full()
%EXT_X0_D17_FULL  Volles Protokoll X0.1 (21 Episoden) auf den 20 D17-Agenten, parallel (Test von X0.1).
%   Agentenliste wie ext_x0_check_d17. Ergebnis: X_eval_X0full_d17_<Zeit>_*, Statistik gegen w2.
setup_project;
ma = sk_path('SavedAgents', 'MotionProfile');
list = struct('file', {}, 'label', {}, 'group', {}, 'opts', {});
d16 = dir(fullfile(ma, 'D16', 'D16_ppo_40hz_r4_seed*_ep3000.mat'));
for k = 1:numel(d16)
    s = str2double(regexp(d16(k).name, 'seed(\d+)_', 'tokens', 'once'));
    list(end + 1) = struct('file', fullfile(d16(k).folder, d16(k).name), 'label', sprintf('w2_s%d', s), ...
                           'group', 'w2', 'opts', {{'base_w', 2}}); %#ok<AGROW>
end
d17 = dir(fullfile(ma, 'D17', 'D17_ppo_40hz_r4_w*_seed*_ep3000.mat'));
for k = 1:numel(d17)
    tok = regexp(d17(k).name, '_w([\d.]+)_seed(\d+)_', 'tokens', 'once');
    list(end + 1) = struct('file', fullfile(d17(k).folder, d17(k).name), ...
                           'label', sprintf('w%s_s%s', tok{1}, tok{2}), 'group', ['w' tok{1}], ...
                           'opts', {{'base_w', str2double(tok{1})}}); %#ok<AGROW>
end
[E, A] = ext_eval_batch(list, 'X0full_d17');
disp(A(:, {'agent', 'nom_rms_ee', 'rms_ee', 'nom_ori_max', 'ori_max', 'ori_max_worst', 'ep_q4_worst', ...
           'e0', 'w_max', 'jerk_rms', 'n_stop', 'follows'}));
S = ext_stats(A, 'ref', "w2", 'theta', 0.03);
disp(S.metrics(ismember(S.metrics.metric, ["rms_ee", "ori_max"]), :));
disp(S.props);
end
