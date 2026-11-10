function V = ext_x3_validate()
%EXT_X3_VALIDATE  Validierung der kinematischen Free-Floating-Emulation in Simulation (Ausbau X3.1).
%   V = ext_x3_validate()
%
%   Stufe 1  Einspielen: Gelenkbahnen (q, dq) einer frei schwebenden Episode gehen in virtual_base_step, abgetastet
%            mit 40 Hz, 20 Hz und mit unregelmaessigen Schrittzeiten (Mittel 50 ms, Streuung 8 ms, 5 % Ausreisser
%            bis 120 ms, auf das 5-ms-Raster gerundet). Verglichen werden Basisdrehung (|e_ori|) und EE-Lage in der
%            Welt mit der Episode. Quellen: SK_desktop (Simscape, eine Episode) und ext_kinsim (frei schwebend).
%   Stufe 2  Geschlossener Kreis: derselbe Agent bzw. Regler frei schwebend (ext_kinsim) und auf dem festen Arm
%            mit Emulation (ext_kinsim 'emulate'), bei 40 Hz und bei 20 Hz (Agent mit 40 Hz trainiert). Ziel aus
%            PLAN.md: EE-Bahn <= 2 mm RMS Abstand, Basisdrehung <= 2 mrad Abstand.
%   Stufe 3  Rechenzeit je Aufruf von virtual_base_step.
%   Ergebnis: data/simulation/extension/X3_validate_<Zeit>.mat und _stage1.csv, _stage2.csv

setup_project;
Simulink.fileGenControl('set', 'CacheFolder', tempname, 'CodeGenFolder', tempname, 'createDir', true);
ma = sk_path('SavedAgents', 'MotionProfile');
K = ext_kin_model();
early = fullfile(ma, 'Circle', 'PPO', 'SpaceKinova_PPO_agent_motionprofile.mat');
r4 = fullfile(ma, 'D16', 'D16_ppo_40hz_r4_seed2.mat');
w8 = fullfile(ma, 'D17', 'D17_ppo_40hz_r4_w8_seed0_ep3000.mat');

%% Stufe 1: Einspielen
rs = RandStream('mt19937ar', 'Seed', 3);
rows1 = {};
src = {};
% Simscape (eine Episode, Gelenkbahn hinter der Positionssaettigung, 5 ms)
rS = desktop_run_episode(desktop_config('agentFile', r4, 'j6_lim', 0.9774, 'reward_mode', 4, 'keepTs', true));
cfg = desktop_config();
tq = rS.ts.t_q_cmd;
src(end + 1, :) = {'simscape_r4', tq, rS.ts.q_cmd, interp1(rS.ts.t_ori, rS.ts.ori, tq), ...
                   refPos(tq, cfg) + interp1(rS.ts.t_ee, rS.ts.ep, tq)};
% ext_kinsim frei schwebend (Gelenkbahn nach dem Gelenkfilter, 5 ms)
for a = {{'early', early, 0.1}, {'kin_r4', r4, 0.9774}}
    rk = ext_kinsim(ext_policy(a{1}{2}), 'j6_lim', a{1}{3}, 'reward_mode', 4);
    tt = rk.ts.t_ee;
    src(end + 1, :) = {a{1}{1}, tt, rk.ts.q, rk.ts.ori, refPos(tt, cfg) + rk.ts.ep}; %#ok<AGROW>
end
for s = 1:size(src, 1)
    [name, t, Q, ori, pe] = src{s, :};
    dt = median(diff(t));
    for smp = {'40Hz', '20Hz', 'jitter'}
        switch smp{1}
            case '40Hz', idx = 1:round(0.025 / dt):numel(t);
            case '20Hz', idx = 1:round(0.05 / dt):numel(t);
            otherwise
                idx = 1;
                while true
                    step = 0.05 + 0.008 * randn(rs);
                    if rand(rs) < 0.05, step = 0.08 + 0.04 * rand(rs); end
                    nxt = idx(end) + max(1, round(step / dt));
                    if nxt > numel(t), break; end
                    idx(end + 1) = nxt; %#ok<AGROW>
                end
        end
        dQ = [zeros(1, 7); diff(Q(idx, :)) ./ diff(t(idx))];
        vb = virtual_base_step('init', Q(1, :).', K);
        eo = nan(numel(idx), 1); pw = nan(numel(idx), 3);
        for k = 1:numel(idx)
            [vb, out] = virtual_base_step(vb, Q(idx(k), :).', dQ(k, :).');
            eo(k) = norm(out.e_ori); pw(k, :) = out.pe.';
        end
        rows1{end + 1} = struct('source', string(name), 'sampling', string(smp{1}), 'n', numel(idx), ...
            'ori_max_ref', max(ori(idx)), 'ori_max_emu', max(eo), 'd_ori_max', max(abs(eo - ori(idx))), ...
            'd_ee_rms', sqrt(mean(vecnorm(pw - pe(idx, :), 2, 2) .^ 2)), ...
            'd_ee_max', max(vecnorm(pw - pe(idx, :), 2, 2))); %#ok<AGROW>
    end
end
V1 = struct2table([rows1{:}]);
disp(V1);

%% Stufe 2: geschlossener Kreis
cases = {
    'early',   'pol',  early, 0.1,    0
    'r4_s2',   'pol',  r4,    0.9774, 4
    'w8_s0',   'pol',  w8,    0.9774, 4
    'Rb46',    'ctrl', '',    0.9774, 4
    };
rows2 = {};
for c = 1:size(cases, 1)
    [name, kind, file, j6, mode] = cases{c, :};
    for Ta = [0.025 0.05]
        args = {'j6_lim', j6, 'reward_mode', mode, 'Ts_agent', Ta};
        if strcmp(kind, 'pol')
            pol = ext_policy(file);
            rf = ext_kinsim(pol, args{:});
            re = ext_kinsim(pol, args{:}, 'emulate', true, 'emulK', K);
        else
            mk = @() ext_x2_controller('beta', 46.416, 'j6_side', -1, 'invert', true, 'Ts_agent', Ta, 'K', K);
            rf = ext_kinsim([], 'ctrl', mk(), args{:});
            re = ext_kinsim([], 'ctrl', mk(), args{:}, 'emulate', true, 'emulK', K);
        end
        n = min(size(rf.ts.obs, 1), size(re.ts.obs, 1));
        dEp = vecnorm(rf.ts.obs(1:n, 1:3) - re.ts.obs(1:n, 1:3), 2, 2);
        dOri = abs(vecnorm(rf.ts.obs(1:n, 27:29), 2, 2) - vecnorm(re.ts.obs(1:n, 27:29), 2, 2));
        rows2{end + 1} = struct('case', string(name), 'Ts_agent', Ta, 'ff_rms', rf.metrics.rms_ee, ...
            'emu_rms', re.metrics.emu_rms_ee, 'ff_ori_max', rf.metrics.ori_max, ...
            'emu_ori_max', re.metrics.emu_ori_max, 'fixed_arm_rms', re.metrics.rms_ee, ...
            'd_ep_rms', sqrt(mean(dEp .^ 2)), 'd_ori_max', max(dOri), ...
            'd_obs_max', max(abs(rf.ts.obs(1:n, :) - re.ts.obs(1:n, :)), [], 'all'), ...
            'ff_stop', double(rf.metrics.early_stop), 'emu_stop', double(re.metrics.early_stop)); %#ok<AGROW>
    end
end
V2 = struct2table([rows2{:}]);
disp(V2);

%% Stufe 3: Rechenzeit
vb = virtual_base_step('init', zeros(7, 1), K);
qq = 0.1 * ones(7, 1);
tic;
for i = 1:500
    [vb, ~] = virtual_base_step(vb, qq * (1 + i / 500), 0.01 * ones(7, 1));
end
tStep = toc / 500;
fprintf('virtual_base_step: %.2f ms je Aufruf\n', 1e3 * tStep);

V = struct('stage1', V1, 'stage2', V2, 'tStep', tStep);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
out = sk_path('data', 'simulation', 'extension', ['X3_validate_' stamp]);
writetable(V1, [out '_stage1.csv']);
writetable(V2, [out '_stage2.csv']);
save([out '.mat'], 'V');
fprintf('Ergebnis: %s_*\n', out);
end

% =====================================================================
function p = refPos(t, cfg)
t = t(:);
w = pi / cfg.T_path;
p = [cfg.center(1) + cfg.r * sin(w * t), cfg.center(2) + 0 * t, cfg.center(3) + cfg.r * cos(w * t)];
end
