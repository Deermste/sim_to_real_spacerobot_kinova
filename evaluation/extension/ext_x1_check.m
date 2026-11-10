function R = ext_x1_check(stage)
%EXT_X1_CHECK  Kurztest fuer Reward-Modus 5 und ext_x1_train (Ausbau X1.1).
%   R = ext_x1_check()        Stufen 1 bis 3
%   R = ext_x1_check([1 2])   nur die Stufen ohne Training
%
%   Laeuft auf der Modellkopie SK_x1test (desktop_build_model(true, 'SK_x1test')), damit SK_desktop waehrend
%   eines laufenden Trainings unberuehrt bleibt. Eigener Simulink-Cache je Prozess und Worker.
%   Stufe 1  Modi 0, 2, 4 bitgleich zur Basislinie (ext_x0_check_model('compare', 'SK_x1test')).
%   Stufe 2  Modus 5 mit lambda 0 gleich Modus 1. Modus 5 mit lambda 3, theta 0,01 (Kosten 1 und 2):
%            Return = Return(Modus 1) - lambda * Summe(cost). Reward und cost aus dem Modell gleich ext_reward
%            mit den geloggten Signalen. Agent D16 r4 s2 (1000 Episoden, Basis bis 0,026 rad), deterministisch.
%            Vorher ein Aufwaermlauf: Die erste Simulation einer Sitzung weicht um etwa 2e-7 ab (10.11.2026).
%   Stufe 3  ext_x1_train mit 2 Bloecken zu 16 Episoden, lambda0 5, 4 Worker. Prueft, dass das Kostensignal
%            in SimulationInfo ankommt und dass lambda bei den Workern wirkt: Episodenreward = Summe der mit
%            ext_reward (Modus 1) nachgerechneten Rewards - lambda * Summe(cost).

if nargin < 1 || isempty(stage), stage = 1:3; end
setup_project;
mdl = 'SK_x1test';
Simulink.fileGenControl('set', 'CacheFolder', tempname, 'CodeGenFolder', tempname, 'createDir', true);
mf = desktop_build_model(true, mdl);
fprintf('Testmodell: %s\n', mf);
R = struct();

if ismember(1, stage)
    T = ext_x0_check_model('compare', mdl);
    R.stage1 = T;
    R.stage1_ok = all(T.maxAbsDiff == 0);
end

if ismember(2, stage)
    file = sk_path('SavedAgents', 'MotionProfile', 'D16', 'D16_ppo_40hz_r4_seed2.mat');
    base = {'agentFile', file, 'j6_lim', 0.9774, 'explore', false, 'keepTs', true, 'model', mdl};
    desktop_run_episode(desktop_config(base{:}, 'reward_mode', 1));           % Aufwaermlauf
    r1 = desktop_run_episode(desktop_config(base{:}, 'reward_mode', 1));
    r50 = desktop_run_episode(desktop_config(base{:}, 'reward_mode', 5, 'lambda', 0));
    rows = {};
    for ct = [1 2]
        lam = 3; th = 0.01;
        r5 = desktop_run_episode(desktop_config(base{:}, 'reward_mode', 5, 'lambda', lam, 'theta', th, ...
                                                'cost_type', ct));
        ts = r5.ts;
        n = min([size(ts.obs, 1), numel(ts.reward), numel(ts.cost)]);
        rr = zeros(n, 1); cc = rr;
        for k = 1:n
            if k == 1, ap = zeros(7, 1); else, ap = ts.a_raw(k - 1, :).'; end
            o = ts.obs(k, :).';
            [rr(k), ~, cc(k)] = ext_reward(o(1:3), o(4:6), ts.a_raw(k, :).', ap, o(10:12), o(27:29), 5, 2, ...
                                           lam, th, ct);
        end
        rows{end + 1} = struct('cost_type', ct, 'ret1', r1.metrics.ret, 'ret5_l0', r50.metrics.ret, ...
            'ret5', r5.metrics.ret, 'sum_cost', sum(ts.cost), ...
            'd_ret', abs(r5.metrics.ret - (r1.metrics.ret - lam * sum(ts.cost(1:n)))), ...
            'd_reward', max(abs(rr - ts.reward(1:n))), 'd_cost', max(abs(cc - ts.cost(1:n))), ...
            'cost_mean', mean(ts.cost)); %#ok<AGROW>
    end
    T = struct2table([rows{:}]);
    disp(T);
    R.stage2 = T;
    R.stage2_ok = r1.metrics.ret == r50.metrics.ret && all(T.d_ret < 1e-9) && all(T.d_reward < 1e-9) && ...
                  all(T.d_cost == 0);
end

if ismember(3, stage)
    pool = gcp('nocreate');
    if isempty(pool), pool = parpool('Processes', 4); end
    root = sk_path();
    f = parfevalOnAll(pool, @workerSetup, 0, root);
    fetchOutputs(f);
    lam0 = 5; th = 0.03;
    out = ext_x1_train(th, 0, 'nEpisodes', 32, 'block', 16, 'tag', 'test', 'model', mdl, 'lambda0', lam0);
    disp(out.dual);
    st = out.lastStats;
    lamLast = out.dual.lambda(end);
    si = st.SimulationInfo;
    nE = si.NumSimulations;
    d = nan(nE, 1);
    for i = 1:nE
        if iscell(si), so = si{i}; else, so = si(i); end
        ls = so.logsout;
        ob = squeezeNx(ls.getElement('obs').Values.Data);
        ar = squeezeNx(ls.getElement('a_raw').Values.Data);
        cs = double(ls.getElement('cost').Values.Data(:));
        n = min([size(ob, 1), size(ar, 1), numel(cs), st.EpisodeSteps(i)]);
        r1 = 0;
        for k = 1:n
            if k == 1, ap = zeros(7, 1); else, ap = ar(k - 1, :).'; end
            o = ob(k, :).';
            r1 = r1 + ext_reward(o(1:3), o(4:6), ar(k, :).', ap, o(10:12), o(27:29), 1, 2);
        end
        d(i) = st.EpisodeReward(i) - (r1 - lamLast * sum(cs(1:n)));
    end
    fprintf('Stufe 3: Episodenreward minus Nachrechnung mit lambda %.3f: max |d| %.2e\n', lamLast, max(abs(d)));
    R.stage3 = out.dual;
    R.stage3_d = d;
    R.stage3_ok = all(out.dual.C_valid == 16) && max(abs(d)) < 1e-6;
end
disp(R);
end

% =====================================================================
function workerSetup(root)
addpath(root);
setup_project;
Simulink.fileGenControl('set', 'CacheFolder', tempname, 'CodeGenFolder', tempname, 'createDir', true);
end

function X = squeezeNx(raw)
% N x Kanaele aus den Daten eines geloggten Signals
if ndims(raw) == 3
    X = reshape(permute(raw, [3 1 2]), size(raw, 3), []);
else
    X = raw;
end
end
