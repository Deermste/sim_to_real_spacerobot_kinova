function V = ext_x0_validate_kinsim()
%EXT_X0_VALIDATE_KINSIM  Validierung des kinematischen Simulators gegen SK_desktop (X0.2).
%   V = ext_x0_validate_kinsim()
%
%   Stufe 1  ext_kin_eval gegen desktop_freefloat (rigidBodyTree) an 20 zufaelligen Stellungen: G, pe, Je.
%   Stufe 2  ext_policy gegen getAction (deterministisch) an 50 zufaelligen Beobachtungen je Agent.
%   Stufe 3  ext_reward mit den geloggten Signalen einer Simscape-Episode gegen den geloggten Reward.
%   Stufe 4  offen: die Rohaktionen der Simscape-Episode in ext_kinsim eingespielt (prueft Befehlskette und
%            Strecke ohne Rueckkopplung).
%   Stufe 5  geschlossen: derselbe Agent in SK_desktop und in ext_kinsim. Ziel aus PLAN.md: EE-Bahn <= 2 mm RMS
%            Abstand, Basisdrehung <= 2 mrad Abstand, Beobachtungen kanalweise.
%   Agenten: fruehes PPO und Optimized (Modus 0, J6 0,1), D16 r4 s2 1000 Episoden (Modus 4, J6 0,9774), dazu
%   D16 r4 s2 mit gestoerter Startstellung (ext_x0_perturbations, Ziehung 1) und mit Basismasse 32,5 kg.
%   Ergebnis: data/simulation/extension/X0_validate_kinsim_<Zeit>.csv und .mat

setup_project;
desktop_build_model();
ma = sk_path('SavedAgents', 'MotionProfile');
K = ext_kin_model();

%% Stufe 1: Kinematik
robot = importrobot(sk_path('robot', 'SpaceKinova.urdf'), 'DataFormat', 'column');
rs = RandStream('mt19937ar', 'Seed', 1);
dG = 0; dP = 0; dJ = 0;
for i = 1:20
    q = (2 * rand(rs, 7, 1) - 1) * 1.5;
    [G1, Je1, pe1] = desktop_freefloat(robot, q, 65, 10.833 * eye(3), 'kinova_end_effector_link');
    [G2, pe2, Je2] = ext_kin_eval(K, q);
    dG = max(dG, max(abs(G1(:) - G2(:)))); dP = max(dP, max(abs(pe1 - pe2))); dJ = max(dJ, max(abs(Je1(:) - Je2(:))));
end
fprintf('Stufe 1 Kinematik: max |dG| %.2e, |dpe| %.2e m, |dJe| %.2e\n', dG, dP, dJ);
tic; for i = 1:200, ext_kin_eval(K, q); end; tKin = toc / 200;
fprintf('         ext_kin_eval %.0f us je Aufruf\n', tKin * 1e6);

%% Faelle
cases = {
    'early',      fullfile(ma, 'Circle', 'PPO', 'SpaceKinova_PPO_agent_motionprofile.mat'), 0, 0.1,    2, 0
    'optimized',  fullfile(ma, 'Circle', 'PPO', 'Optimized.mat'),                           0, 0.1,    2, 0
    'd16r4s2',    fullfile(ma, 'D16', 'D16_ppo_40hz_r4_seed2.mat'),                         4, 0.9774, 2, 0
    'd16r4s2_q0', fullfile(ma, 'D16', 'D16_ppo_40hz_r4_seed2.mat'),                         4, 0.9774, 2, 1
    };
cases(:, 7) = {65};
cases(end + 1, :) = {'d16r4s2_m32', fullfile(ma, 'D16', 'D16_ppo_40hz_r4_seed2.mat'), 4, 0.9774, 2, 0, 32.5};
Q0 = ext_x0_perturbations();
rows = {};
store = struct();
for c = 1:size(cases, 1)
    [name, file, mode, j6, bw, draw, mb] = cases{c, :};
    q0 = Q0(draw + 1, :).';
    Kc = K;
    if mb ~= 65, Kc = ext_kin_model('base_mass', mb); end

    %% Stufe 2: Policy
    [pol, W] = ext_policy(file);
    S = load(file, 'agent');
    ag = S.agent; ag.UseExplorationPolicy = false;
    dA = 0;
    for i = 1:50
        o = randn(rs, 29, 1) * 0.3;
        a1 = getAction(ag, {o}); a1 = double(a1{1});
        dA = max(dA, max(abs(a1 - pol(o))));
    end

    %% Simscape
    cfg = desktop_config('agentFile', file, 'reward_mode', mode, 'j6_lim', j6, 'base_w', bw, 'q0', q0, ...
                         'base_mass', mb, 'explore', false, 'keepTs', true);
    tS = tic; rS = desktop_run_episode(cfg); tSim = toc(tS);
    tsS = rS.ts;

    %% Stufe 3: Reward aus den geloggten Signalen
    ob = tsS.obs; ar = tsS.a_raw;
    nA = min(size(ob, 1), numel(tsS.reward));
    rr = zeros(nA, 1);
    for k = 1:nA
        if k == 1, ap = zeros(7, 1); else, ap = ar(k - 1, :).'; end
        rr(k) = ext_reward(ob(k, 1:3).', ob(k, 4:6).', ar(k, :).', ap, ob(k, 10:12).', ob(k, 27:29).', mode, bw);
    end
    dR = max(abs(rr - tsS.reward(1:nA)));
    % Wie oft greift die Begrenzung der Beobachtung (A72)? Anteil der Agentenschritte je Kanal
    clipFrac = mean(ob < W.lo.' | ob > W.hi.', 1);
    chNames = [compose('ep%d', 1:3), compose('ev%d', 1:3), compose('vb%d', 1:3), compose('wb%d', 1:3), ...
               compose('q%d', 1:7), compose('dq%d', 1:7), compose('eo%d', 1:3)];
    act = find(clipFrac > 0);
    fprintf('%-11s Begrenzung aktiv: %s\n', name, strjoin(compose('%s %.0f %%', string(chNames(act)).', ...
            100 * clipFrac(act).'), ', '));

    %% Stufe 4: offene Einspielung
    opt = {'reward_mode', mode, 'j6_lim', j6, 'base_w', bw, 'q0', q0, 'K', Kc};
    rO = ext_kinsim([], opt{:}, 'actionSeq', ar);
    [oO, eO, wO] = compare(tsS, rO.ts);

    %% Stufe 5: geschlossener Kreis
    tK = tic; rC = ext_kinsim(pol, opt{:}); tKs = toc(tK);
    [oC, eC, wC, chC] = compare(tsS, rC.ts);

    mS = rS.metrics; mC = rC.metrics;
    rows{end + 1} = struct('case', string(name), 'base_mass', mb, 'd_policy', dA, 'd_reward', dR, ... %#ok<AGROW>
        'clip_any', mean(any(ob < W.lo.' | ob > W.hi.', 2)), 'clip_dq', max(clipFrac(20:26)), ...
        'open_obs_max', oO, 'open_ee_rms', eO, 'open_ori_max', wO, ...
        'closed_obs_max', oC, 'closed_ee_rms', eC, 'closed_ori_max', wC, ...
        'sim_rms', mS.rms_ee, 'kin_rms', mC.rms_ee, 'sim_ori_max', mS.ori_max, 'kin_ori_max', mC.ori_max, ...
        'sim_ret', mS.ret, 'kin_ret', mC.ret, 'sim_stop', double(mS.early_stop), 'kin_stop', double(mC.early_stop), ...
        't_simscape', tSim, 't_kinsim', tKs);
    store.(name) = struct('chClosed', chC, 'sim', tsS, 'kin', rC.ts, 'open', rO.ts);
    fprintf(['%-11s Policy %.1e, Reward %.1e | offen: obs %.1e, EE %.2e m, Basis %.2e rad | ' ...
             'geschlossen: obs %.1e, EE %.2e m, Basis %.2e rad | %.1f s gegen %.2f s\n'], name, dA, dR, ...
            oO, eO, wO, oC, eC, wC, tSim, tKs);
end
V = struct2table([rows{:}], 'AsArray', true);
disp(V);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
out = sk_path('data', 'simulation', 'extension', ['X0_validate_kinsim_' stamp]);
writetable(V, [out '.csv']);
kin = struct('dG', dG, 'dP', dP, 'dJ', dJ, 'tKin', tKin);
save([out '.mat'], 'V', 'kin');
fprintf('Ergebnis: %s.csv\n', out);
end

% =====================================================================
function [dObs, eeRms, oriMax, ch] = compare(a, b)
% a = Simscape (desktop_run_episode), b = ext_kinsim. Beobachtung zu den Agentenschritten, EE und Basis im
% Solvertakt, jeweils ueber die gemeinsame Laenge.
nA = min(size(a.obs, 1), size(b.obs, 1));
d = abs(a.obs(1:nA, :) - b.obs(1:nA, :));
dObs = max(d(:));
grp = {1:3, 4:6, 7:9, 10:12, 13:19, 20:26, 27:29};
gn = {'ep', 'ev', 'v_base', 'w_base', 'q', 'dq', 'e_ori'};
ch = struct();
for g = 1:numel(grp), ch.(gn{g}) = max(max(d(:, grp{g}))); end
nS = min(size(a.ep, 1), size(b.ep, 1));
eeRms = sqrt(mean(vecnorm(a.ep(1:nS, :) - b.ep(1:nS, :), 2, 2) .^ 2));
oriMax = max(abs(a.ori(1:nS) - b.ori(1:nS)));
end
