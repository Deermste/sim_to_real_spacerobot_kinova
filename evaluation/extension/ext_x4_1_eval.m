function [E, A, S] = ext_x4_1_eval()
%EXT_X4_1_EVAL  Volles Protokoll X0.1 auf der Gewichtsreihe (Ausbau X4.1).
%   [E, A, S] = ext_x4_1_eval()
%
%   Alle r4-Agenten mit 3000 Episoden aus D16 (Gewicht 2) und D17 (Gewichte 0, 4, 8, 16), die vorhanden sind. Je
%   Agent 21 Episoden (nominal und 20 Startstoerungen +-2 Grad, ext_eval_agent). Statistik je Gewicht gegen
%   Gewicht 2 (ext_stats), Budgets 0,03 und 0,05 rad wie in X1.3.
%   Ergebnis: data/simulation/extension/X_eval_X4_1_<Zeit>_* und X4_1_stats_<Zeit>.mat

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
fprintf('X4.1: %d Agenten\n', numel(list));
[E, A, outFile] = ext_eval_batch(list, 'X4_1');
S = struct();
for th = [0.03 0.05]
    S.(sprintf('th%03d', round(1000 * th))) = ext_stats(A, 'ref', "w2", 'theta', th);
end
disp(A(:, {'agent', 'group', 'nom_rms_ee', 'rms_ee', 'nom_ori_max', 'ori_max', 'ori_max_worst', 'n_stop', ...
           'follows'}));
disp(S.th030.metrics(ismember(S.th030.metrics.metric, ["rms_ee", "ori_max"]), :));
disp(S.th030.props);
disp(S.th050.props);
[p, n] = fileparts(outFile);
save(fullfile(p, strrep(n, 'X_eval_X4_1', 'X4_1_stats')), 'S');
end
