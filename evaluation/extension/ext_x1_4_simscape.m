function C = ext_x1_4_simscape(varargin)
%EXT_X1_4_SIMSCAPE  Gegenprobe des Sicherheitsfilters in Simscape (Ausbau X1.4, sechs Faelle).
%   C = ext_x1_4_simscape()
%
%   Modell SK_x14 (ext_x1_4_build_model, SK_desktop mit Filterblock nach der Befehlskette). r1-Agenten aus
%   X1.3 mit Filter (alpha 5), nominal, Startstellung null. Standard: drei Faelle, in denen der Agent mit Filter
%   folgt und ohne Filter Simscape und ext_kinsim uebereinstimmen (s3 0,03, s5 0,02, s0 0,04), dazu drei weitere
%   (s0 0,02, s1 0,03, s2 0,05; s1 und s2 weichen schon ohne Filter ab, X1.3). Vergleich mit ext_kinsim und dem Hook
%   ext_x1_shield (wie ext_x1_4_eval): RMS, ori_max, ep_q4, folgt, Anteil der Eingriffe, Befehl nach dem Filter.
%   Vorher und nachher die Pruefsumme von SK_desktop.
%   CSV: data/simulation/extension/X1_4_simscape_<Zeit>.csv

p = inputParser;
p.addParameter('cases', {3, 0.03; 5, 0.02; 0, 0.04; 0, 0.02; 1, 0.03; 2, 0.05});
p.addParameter('alpha', 5);
p.parse(varargin{:});
o = p.Results;
setup_project;
mdlFile = sk_path('evaluation', 'desktop', 'models', 'SK_desktop.slx');
md5a = fileMD5(mdlFile);
ext_x1_4_build_model('SK_x14', true);
rows = {};
for c = 1:size(o.cases, 1)
    seed = o.cases{c, 1}; th = o.cases{c, 2};
    f = sk_path('SavedAgents', 'MotionProfile', 'X1', sprintf('X1_ppo_40hz_r5_c1_th30_eta0_seed%d_ep3000_b50.mat', seed));
    assignin('base', 'p_sh_theta', th);
    assignin('base', 'p_sh_alpha', o.alpha);
    ext_x1_4_sim_shield('reset');
    cfg = desktop_config('agentFile', f, 'reward_mode', 4, 'j6_lim', 0.9774, 'base_w', 2, 'explore', false, ...
                         'keepTs', true, 'T', 8.5, 'model', 'SK_x14');
    r = desktop_run_episode(cfg);
    cnt = ext_x1_4_sim_shield('count');
    hook = ext_x1_shield('theta', th, 'alpha', o.alpha, 'K', ext_kin_model(), 'lim', [0.9774 0.9774 0.9774]);
    k = ext_kinsim(f, 'j6_lim', 0.9774, 'reward_mode', 4, 'cmdHook', hook);
    kc = hook('count');
    epn = vecnorm(r.ts.ep, 2, 2);
    rmsS = sqrt(mean(epn .^ 2));
    q4S = mean(epn(r.ts.t_ee >= 3 * 8.5 / 4 & r.ts.t_ee <= 8.5 + 1e-9));
    rows{end + 1} = struct('seed', seed, 'theta', th, 'rms_sim', rmsS, 'rms_kin', k.metrics.rms_ee, ...
        'd_rms', rmsS - k.metrics.rms_ee, 'ori_sim', r.metrics.ori_max, 'ori_kin', k.metrics.ori_max, ...
        'd_ori', r.metrics.ori_max - k.metrics.ori_max, 'epq4_sim', q4S, 'epq4_kin', k.metrics.ep_q4, ...
        'follows_sim', double(~r.metrics.early_stop && q4S < 0.05), ...
        'follows_kin', double(~k.metrics.early_stop && k.metrics.ep_q4 < 0.05), ...
        'act_sim', cnt(2) / max(cnt(1), 1), 'act_kin', kc(2) / max(kc(1), 1)); %#ok<AGROW>
end
md5b = fileMD5(mdlFile);
C = struct2table([rows{:}]);
C.sk_desktop_unchanged = repmat(double(strcmp(md5a, md5b) && strcmp(md5a, '897024e9e94468f6f074396c4523c6ec')), height(C), 1);
disp(C);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
writetable(C, sk_path('data', 'simulation', 'extension', ['X1_4_simscape_' stamp '.csv']));
end

function h = fileMD5(file)
md = java.security.MessageDigest.getInstance('MD5');
fid = fopen(file, 'r');
data = fread(fid, inf, '*uint8');
fclose(fid);
md.update(data);
h = lower(reshape(dec2hex(typecast(md.digest(), 'uint8'))', 1, []));
end
