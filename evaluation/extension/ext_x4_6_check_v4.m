function C = ext_x4_6_check_v4()
%EXT_X4_6_CHECK_V4  Pruefungen vor dem Training von X4.6 V4 (Rate Limiter 2 rad/s^2, Modell SK_x46s).
%   C = ext_x4_6_check_v4()
%
%   1  SK_desktop MD5 vor und nach dem Bau von SK_x46s unveraendert.
%   2  Kurztraining V4 (16 Episoden, Ablage _test): laeuft, 29 Kanaele, cfg.slew = 2.
%   3  Agent aus dem Kurztraining nominal: Simscape (SK_x46s) gegen ext_kinsim mit slew 2. Dazu der Ausgang des
%      Rate Limiters: groesste Aenderung je Schritt gegen 2 * 0,025.
%   4  ext_x2_sweep mit slew 0,5 (neue Option) bitgleich zur gespeicherten Front X2_sweep_20261110_113752.
%   CSV: data/simulation/extension/X4_6_check_v4_<Zeit>.csv

setup_project;
rows = {};
mdlFile = sk_path('evaluation', 'desktop', 'models', 'SK_desktop.slx');
md5 = fileMD5(mdlFile);
rows{end + 1} = row('SK_desktop MD5 wie vor X4.6', double(strcmp(md5, '897024e9e94468f6f074396c4523c6ec')), md5);
ext_x4_6_build_model('SK_x46s', 0.95, true, 2, false);
rows{end + 1} = row('SK_desktop MD5 nach dem Bau von SK_x46s', double(strcmp(fileMD5(mdlFile), md5)), '');

out = ext_x4_6_train('V4', 0, 'nEpisodes', 16, 'tag', 'test');
A = load(out.agentFile, 'agent');
oi = getObservationInfo(A.agent);
rows{end + 1} = row('V4 Kurztraining Kanaele', prod(oi.Dimension), out.cfg.model);
rows{end + 1} = row('V4 cfg.slew', out.cfg.slew, '');

c = desktop_config('agentFile', out.agentFile, 'reward_mode', 4, 'j6_lim', 0.9774, 'base_w', 2, ...
                   'explore', false, 'keepTs', true, 'T', 8.5, 'model', 'SK_x46s');
r = desktop_run_episode(c);
k = ext_kinsim(out.agentFile, 'j6_lim', 0.9774, 'reward_mode', 4, 'slew', 2);
k5 = ext_kinsim(out.agentFile, 'j6_lim', 0.9774, 'reward_mode', 4, 'slew', 0.5);
epn = vecnorm(r.ts.ep, 2, 2);
rmsS = sqrt(mean(epn .^ 2));
rows{end + 1} = row('V4 RMS Simscape gegen kinematisch (slew 2)', abs(rmsS - k.metrics.rms_ee), ...
                    sprintf('%.6g m, mit slew 0,5 waeren es %.6g m', k.metrics.rms_ee, k5.metrics.rms_ee));
rows{end + 1} = row('V4 ori_max Simscape gegen kinematisch (slew 2)', abs(r.metrics.ori_max - k.metrics.ori_max), '');
rl = k.ts.a_scaled(:, [2 4 6]);
rows{end + 1} = row('V4 kinematisch: max |Aenderung Rate Limiter| / (2 * 0,025)', max(abs(diff(rl)), [], 'all') / 0.05, '');

T0 = ext_x2_sweep('variants', {'full_inv'}, 'j6', 0.9774, 'save', false, 'slew', 0.5);
S0 = readtable(sk_path('data', 'simulation', 'extension', 'X2_sweep_20261110_113752.csv'), 'TextType', 'string');
S0 = S0(S0.variant == "full_inv" & abs(S0.j6_lim - 0.9774) < 1e-6, :);
rows{end + 1} = row('Sweep slew 0,5 gegen gespeichert: max |RMS| [m]', max(abs(sort(S0.rms_ee) - sort(T0.rms_ee))), '');

C = struct2table([rows{:}]);
disp(C);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
writetable(C, sk_path('data', 'simulation', 'extension', ['X4_6_check_v4_' stamp '.csv']));
end

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
