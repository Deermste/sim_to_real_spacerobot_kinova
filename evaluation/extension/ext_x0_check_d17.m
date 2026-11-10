function T = ext_x0_check_d17(parallel)
%EXT_X0_CHECK_D17  Fertig-Kriterium von X0.1: Das Protokoll reproduziert mit nur der nominalen Episode D17.
%   T = ext_x0_check_d17()        parallel
%   T = ext_x0_check_d17(false)   seriell
%
%   Wertet die 20 Agenten aus D17 (Gewichte 0, 4, 8, 16, Seeds 0-2) und D16 (Gewicht 2, Seeds 0-7) mit
%   ext_eval_batch und nPert = 0 aus und vergleicht RMS, letztes Viertel und groesste Basisdrehung der
%   nominalen Episode mit den deterministischen Zeilen von D17_eval_20260928_144737_agents.csv.
%   Danach ein Kurztest von ext_stats (Gruppen nach Gewicht, Referenz w2).

if nargin < 1, parallel = true; end
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
assert(numel(list) == 20, 'ext_x0_check_d17:n', 'Erwartet 20 Agenten, gefunden %d', numel(list));

[~, A] = ext_eval_batch(list, 'X0check_d17', 'nPert', 0, 'parallel', parallel);

R = readtable(sk_path('data', 'simulation', 'desktop', 'D17_eval_20260928_144737_agents.csv'));
R = R(R.stoch == 0, :);
R.agent = string(compose('w%g_s%d', R.weight, R.seed));
T = innerjoin(A(:, {'agent', 'nom_rms_ee', 'nom_ep_q4', 'nom_ori_max', 'reward_mode', 'j6_lim', 'base_w'}), ...
              R(:, {'agent', 'rms_ee', 'ep_q4', 'ori_max'}), 'Keys', 'agent');
assert(height(T) == 20, 'ext_x0_check_d17:join', 'Nur %d von 20 Agenten zugeordnet', height(T));
T.d_rms = abs(T.nom_rms_ee - T.rms_ee);
T.d_q4 = abs(T.nom_ep_q4 - T.ep_q4);
T.d_ori = abs(T.nom_ori_max - T.ori_max);
disp(T);
dmax = max([T.d_rms; T.d_q4; T.d_ori]);
fprintf('Groesste Abweichung zu D17: %g\n', dmax);
if dmax < 1e-12
    fprintf('D17 reproduziert.\n');
else
    fprintf('D17 NICHT reproduziert.\n');
end

S = ext_stats(A, 'ref', "w2", 'theta', 0.03, 'nBoot', 500);
disp(S.metrics(S.metrics.metric == "ori_max", :));
disp(S.props);
end
