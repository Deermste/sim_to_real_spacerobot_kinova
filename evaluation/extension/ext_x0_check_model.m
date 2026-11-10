function T = ext_x0_check_model(mode, mdl)
%EXT_X0_CHECK_MODEL  Prueft, dass eine Aenderung an SK_desktop alte Ergebnisse bitgleich laesst (X0.1).
%   T = ext_x0_check_model('baseline')  rechnet fuenf Referenzfaelle und speichert sie
%   T = ext_x0_check_model('compare')   rechnet dieselben Faelle und vergleicht mit der gespeicherten Basislinie
%   T = ext_x0_check_model('compare', 'SK_x1test')   dasselbe mit einer Modellkopie aus desktop_build_model
%
%   Faelle: fruehes PPO und Optimized (Modus 0, J6 0,1), D16 r2 s1 (Modus 2, J6 0,9774), D16 r4 s7 ep3000
%   (Modus 4, J6 0,9774, w 2), D17 w8 s0 (Modus 4, w 8). Alle deterministisch, 65 kg, 40 Hz.
%   Verglichen werden Return, RMS, groesster EE-Fehler und groesste Basisdrehung auf volle Genauigkeit.
%   Datei: data/simulation/extension/X0_check_model_baseline.mat

if nargin < 2 || isempty(mdl), mdl = 'SK_desktop'; end
setup_project;
desktop_build_model(false, mdl);
ma = sk_path('SavedAgents', 'MotionProfile');
cases = {
    'early',  fullfile(ma, 'Circle', 'PPO', 'SpaceKinova_PPO_agent_motionprofile.mat'), 0, 0.1,    2
    'optim',  fullfile(ma, 'Circle', 'PPO', 'Optimized.mat'),                           0, 0.1,    2
    'd16r2',  fullfile(ma, 'D16', 'D16_ppo_40hz_r2_seed1.mat'),                         2, 0.9774, 2
    'd16r4',  fullfile(ma, 'D16', 'D16_ppo_40hz_r4_seed7_ep3000.mat'),                  4, 0.9774, 2
    'd17w8',  fullfile(ma, 'D17', 'D17_ppo_40hz_r4_w8_seed0_ep3000.mat'),               4, 0.9774, 8
    };
n = size(cases, 1);
name = cases(:, 1);
ret = zeros(n, 1); rms_ee = ret; max_ee = ret; ori_max = ret;
for k = 1:n
    c = desktop_config('agentFile', cases{k, 2}, 'reward_mode', cases{k, 3}, 'j6_lim', cases{k, 4}, ...
                       'base_w', cases{k, 5}, 'base_mass', 65, 'explore', false, 'keepTs', false, 'model', mdl);
    m = desktop_run_episode(c).metrics;
    ret(k) = m.ret; rms_ee(k) = m.rms_ee; max_ee(k) = m.max_ee; ori_max(k) = m.ori_max;
end
T = table(name, ret, rms_ee, max_ee, ori_max);

outDir = sk_path('data', 'simulation', 'extension');
if ~isfolder(outDir), mkdir(outDir); end
file = fullfile(outDir, 'X0_check_model_baseline.mat');
switch mode
    case 'baseline'
        B = T; %#ok<NASGU>
        save(file, 'B');
        fprintf('Basislinie gespeichert: %s\n', file);
        disp(T);
    case 'compare'
        S = load(file, 'B');
        d = abs(T{:, 2:end} - S.B{:, 2:end});
        T.maxAbsDiff = max(d, [], 2);
        disp(T);
        fprintf('Groesste Abweichung: %g\n', max(d(:)));
        if all(d(:) == 0)
            fprintf('Bitgleich.\n');
        else
            fprintf('NICHT bitgleich.\n');
        end
    otherwise
        error('ext_x0_check_model:mode', 'mode ist ''baseline'' oder ''compare''');
end
end
