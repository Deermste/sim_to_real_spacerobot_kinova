function C = ext_x4_6_check()
%EXT_X4_6_CHECK  Pruefungen vor dem Training der Ablation X4.6.
%   C = ext_x4_6_check()
%
%   1  SK_desktop unveraendert (MD5 wie vor X4.6) und D16 r4 s2 nominal bitgleich zu X1.3 (X_eval_X1_3_*.mat),
%      nach einem Aufwaermlauf (Nebenbefund X1.1). ext_kinsim mit Standardwerten bitgleich zu ohne neue Optionen
%      ist trivial (gleicher Code-Pfad) und wird nicht eigens geprueft.
%   2  Modelle SK_x46 (Filter 0,95) und SK_x46f (Filter 0,85) bauen.
%   3  Kurztraining je Variante (16 Episoden, Ablage _test): laeuft, Kanalzahl stimmt, Grenzen gespeichert.
%   4  Gegenprobe V2 und V3: Agent aus dem Kurztraining nominal in Simscape (desktop_run_episode mit dem Modell
%      aus cfg) gegen ext_kinsim mit obs_ext und filt_a. Abweichung von RMS, ori_max und der erweiterten
%      Beobachtung (obs_ext gegen ts.obs).
%   Ergebnis C als Tabelle, dazu data/simulation/extension/X4_6_check_<Zeit>.csv

setup_project;
rows = {};
mdlFile = sk_path('evaluation', 'desktop', 'models', 'SK_desktop.slx');
md5 = fileMD5(mdlFile);
rows{end + 1} = row('SK_desktop MD5', double(strcmp(md5, '897024e9e94468f6f074396c4523c6ec')), md5);

L = load(sk_path('data', 'simulation', 'extension', 'X_eval_X1_3_20261112_195325.mat'), 'E');
e = L.E(L.E.agent == "D16_ppo_40hz_r4_seed2_ep3000" & L.E.draw == 0, :);
f = sk_path('SavedAgents', 'MotionProfile', 'D16', 'D16_ppo_40hz_r4_seed2_ep3000.mat');
c = desktop_config('agentFile', f, 'reward_mode', 4, 'j6_lim', 0.9774, 'base_w', 2, 'explore', false, ...
                   'keepTs', true, 'T', 8.5);
desktop_run_episode(c);                                   % Aufwaermlauf
r = desktop_run_episode(c);
epn = vecnorm(r.ts.ep, 2, 2);
rows{end + 1} = row('D16 r4 s2 nominal RMS gegen X1.3', abs(sqrt(mean(epn .^ 2)) - e.rms_ee), '');
rows{end + 1} = row('D16 r4 s2 nominal ori_max gegen X1.3', abs(r.metrics.ori_max - e.ori_max), '');
rows{end + 1} = row('SK_desktop MD5 nach dem Lauf', double(strcmp(fileMD5(mdlFile), md5)), '');

ext_x4_6_build_model('SK_x46', 0.95, true);
ext_x4_6_build_model('SK_x46f', 0.85, true);
rows{end + 1} = row('SK_desktop MD5 nach dem Bau der Kopien', double(strcmp(fileMD5(mdlFile), md5)), '');

for v = {'V1', 'V2', 'V3'}
    out = ext_x4_6_train(v{1}, 0, 'nEpisodes', 16, 'tag', 'test');
    A = load(out.agentFile, 'agent');
    oi = getObservationInfo(A.agent);
    rows{end + 1} = row([v{1} ' Kurztraining Kanaele'], prod(oi.Dimension), out.cfg.model); %#ok<AGROW>
    rows{end + 1} = row([v{1} ' Episoden'], height(out.curve), ''); %#ok<AGROW>
    if strcmp(v{1}, 'V1'), continue; end
    c = desktop_config('agentFile', out.agentFile, 'reward_mode', 4, 'j6_lim', 0.9774, 'base_w', 2, ...
                       'explore', false, 'keepTs', true, 'T', 8.5, 'model', out.cfg.model);
    r = desktop_run_episode(c);
    k = ext_kinsim(out.agentFile, 'j6_lim', 0.9774, 'reward_mode', 4, 'obs_ext', true, 'filt_a', out.cfg.filtA);
    epn = vecnorm(r.ts.ep, 2, 2);
    rows{end + 1} = row([v{1} ' RMS Simscape gegen kinematisch'], abs(sqrt(mean(epn .^ 2)) - k.metrics.rms_ee), ...
                        sprintf('%.6g m', k.metrics.rms_ee)); %#ok<AGROW>
    rows{end + 1} = row([v{1} ' ori_max Simscape gegen kinematisch'], abs(r.metrics.ori_max - k.metrics.ori_max), ...
                        ''); %#ok<AGROW>
    oe = r.ts.obs_ext;
    n = min(size(oe, 1), size(k.ts.obs, 1));
    dlt = abs(oe(1:n, :) - k.ts.obs(1:n, :));
    rows{end + 1} = row([v{1} ' obs 1-29 Simscape gegen kinematisch'], max(dlt(:, 1:29), [], 'all'), ''); %#ok<AGROW>
    rows{end + 1} = row([v{1} ' obs 30-32 (Kette) Simscape gegen kinematisch'], max(dlt(:, 30:32), [], 'all'), ...
                        ''); %#ok<AGROW>
    rows{end + 1} = row([v{1} ' obs 33-38 (Vorschau) Simscape gegen kinematisch'], max(dlt(:, 33:38), [], 'all'), ...
                        sprintf('max |Vorschau| %.3g m', max(abs(k.ts.obs(:, 33:38)), [], 'all'))); %#ok<AGROW>
end
C = struct2table([rows{:}]);
disp(C);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
writetable(C, sk_path('data', 'simulation', 'extension', ['X4_6_check_' stamp '.csv']));
end

% =====================================================================
function r = row(name, value, note)
r = struct('check', string(name), 'value', value, 'note', string(note));
end

function h = fileMD5(file)
md = java.security.MessageDigest.getInstance('MD5');
fid = fopen(file, 'r');
data = fread(fid, inf, '*uint8');
fclose(fid);
md.update(data);
h = lower(reshape(dec2hex(typecast(md.digest(), 'uint8'))', 1, []));
end
