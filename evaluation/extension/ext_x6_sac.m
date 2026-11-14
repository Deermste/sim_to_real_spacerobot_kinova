function out = ext_x6_sac(pools, varargin)
%EXT_X6_SAC  SAC (optional mit Hindsight Experience Replay) in der X6-Umgebung, Rueckfall E14 nach dem Pilot X6.3.
%   out = ext_x6_sac(pools)                         pools: struct mit train und eval (Paare wie ext_x6_sanity)
%   out = ext_x6_sac(pools, 'her', true, 'label', 'sanity_her')
%   out = ext_x6_sac(pools, 'maxEpisodes', 8, 'chunk', 4, 'nEval', 8, 'nCur', 8, 'tag', 'test')   Kurztest
%
%   Umgebung wie ext_x6_pilot Variante a (Kette E18 20 Hz, Reward 'progress', w_v 0,05, w_dq 0,02, w_da 0,01,
%   w_brk 0,02, w_base 0,05, r_fail -100, w_stop 0), eine Stufe mit Toleranz 'tol'.
%   'her' false: SAC mit der Standardumgebung (50 Kanaele), sonst gleich wie PPO in sanity3.
%   'her' true:  Umgebung im HER-Modus (ext_x6_env 'her'): Ziel und Werkzeugpunkt als eigene Kanaele, Reward aus
%                ext_x6_her_reward (ohne w_da, mit Bonus w_in je Schritt innerhalb der Toleranz), im Training kein
%                Ende bei Erfolg (die Episode laeuft 15 s, Halten wird belohnt). Replay rlHindsightReplayMemory,
%                Strategie future, 4 Ziele je Schritt.
%   SAC: 2 x 256 (rlAgentInitializationOptions), gamma 0,99, Minibatch 256, Puffer 1e6, tau 5e-3, Lernraten 3e-4,
%   Entropie automatisch (Zielentropie -7), 1000 Startschritte. Training seriell (ein Prozess) oder parallel
%   ('parallel', Standard false).
%   Auswertung nach jedem Abschnitt wie ext_x6_pilot: Stufenpruefung auf nCur Trainingspaaren mit tol, Auswertung
%   auf nEval Auswertepaaren mit 5 mm, Agent deterministisch.
%   Ergebnis: SavedAgents/MotionProfile/X6/X6_sac[_her]_<label>_seed<S>.mat und CSVs in data/simulation/extension.

p = inputParser;
p.addParameter('her', false);
p.addParameter('seed', 0);
p.addParameter('maxEpisodes', 5000);
p.addParameter('maxHours', 0.75);
p.addParameter('chunk', 100);
p.addParameter('nEval', 100);
p.addParameter('nCur', 48);
p.addParameter('tol', 0.02);
p.addParameter('w_in', 1);
p.addParameter('label', '');
p.addParameter('tag', '');
p.addParameter('parallel', false);
p.parse(varargin{:});
o = p.Results;
setup_project;
dd = sk_path('data', 'simulation', 'extension');
Ptr = pools.train;
Pev = pools.eval(1:min(o.nEval, numel(pools.eval)));
rsC = RandStream('mt19937ar', 'Seed', 500 + o.seed);
Pcur = Ptr(randperm(rsC, numel(Ptr), o.nCur));
C = chain_step('params');
envArgs = {'reward', 'progress', 'w_da', 0.01, 'w_brk', 0.02, 'w_base', 0.05, 'r_fail', -100, 'w_stop', 0, ...
           'w_v', 0.05, 'w_dq', 0.02, 'coll', false};
if o.her
    envArgs = [envArgs, {'her', true, 'w_in', o.w_in}];
end
trainArgs = [envArgs, {'tol', o.tol}];
if o.her, trainArgs = [trainArgs, {'stopSuccess', false}]; end
cfg = struct('her', o.her, 'seed', o.seed, 'chainP', C, 'envArgs', {envArgs}, 'tol', o.tol, 'w_in', o.w_in, ...
    'chunk', o.chunk, 'maxEpisodes', o.maxEpisodes, 'maxHours', o.maxHours, 'nEval', numel(Pev), 'nCur', o.nCur, ...
    'label', o.label, 'hidden', 256, 'parallel', o.parallel);
cfg.opts = struct('DiscountFactor', 0.99, 'MiniBatchSize', 256, 'ExperienceBufferLength', 1e6, ...
    'TargetSmoothFactor', 5e-3, 'LR', 3e-4, 'NumWarmStartSteps', 1000, 'HERStrategy', "future", 'HERGoals', 4);

[~, info0] = ext_x6_env(Ptr, 'chainP', C, trainArgs{:});
rng(o.seed, 'twister');
agent = rlSACAgent(info0.obsInfo, info0.actInfo, rlAgentInitializationOptions('NumHiddenUnit', cfg.hidden));
ao = agent.AgentOptions;
ao.SampleTime = C.Ts;
ao.DiscountFactor = cfg.opts.DiscountFactor;
ao.MiniBatchSize = cfg.opts.MiniBatchSize;
ao.ExperienceBufferLength = cfg.opts.ExperienceBufferLength;
ao.TargetSmoothFactor = cfg.opts.TargetSmoothFactor;
ao.NumWarmStartSteps = cfg.opts.NumWarmStartSteps;
ao.ActorOptimizerOptions.LearnRate = cfg.opts.LR;
for k = 1:numel(ao.CriticOptimizerOptions)
    ao.CriticOptimizerOptions(k).LearnRate = cfg.opts.LR;
    ao.CriticOptimizerOptions(k).GradientThreshold = 1;
end
ao.ActorOptimizerOptions.GradientThreshold = 1;
agent.AgentOptions = ao;
if o.her
    H = info0.her;
    rf = @(o1, a1, o2) ext_x6_her_reward(o1, a1, o2, H);
    df = @(o1, a1, o2) double(o2{1}(51) > 0.5);
    buf = rlHindsightReplayMemory(info0.obsInfo, info0.actInfo, rf, df, {{1, 4:6, 1, 1:3}}, ...
                                  cfg.opts.ExperienceBufferLength);
    buf.Strategy = cfg.opts.HERStrategy;
    buf.NumGoalSamples = cfg.opts.HERGoals;
    agent.ExperienceBuffer = buf;
end

if o.parallel
    pool = gcp('nocreate');
    if isempty(pool), pool = parpool('Processes'); end
    nW = pool.NumWorkers;
else
    nW = 0;
    pool = gcp('nocreate');
    if isempty(pool), pool = parpool('Processes'); end   % nur fuer die Auswertung
end
nMax = round(15 / C.Ts);
fprintf('X6 SAC%s, Seed %d: %d Kanaele, %d Trainings- und %d Auswertepaare, tol %.3f m, parallel %d\n', ...
        repmat(' mit HER', 1, o.her), o.seed, info0.obsInfo.Dimension(1), numel(Ptr), numel(Pev), o.tol, nW);

nEp = 0; c = 0; tStart = tic;
logRows = {}; curve = table(); bestSucc = -1; best = agent; evalBest = table();
while nEp < o.maxEpisodes && toc(tStart) < 3600 * o.maxHours
    c = c + 1;
    nC = min(o.chunk, o.maxEpisodes - nEp);
    env = ext_x6_env(Ptr, 'chainP', C, trainArgs{:}, 'seed', 1000 * o.seed + c);
    topt = {'MaxEpisodes', nC, 'MaxStepsPerEpisode', nMax, 'ScoreAveragingWindowLength', 50, ...
            'StopTrainingCriteria', 'EpisodeCount', 'StopTrainingValue', nC, 'Plots', 'none', 'Verbose', false, ...
            'StopOnError', 'off'};
    if o.parallel
        topt = [topt, {'UseParallel', true}]; %#ok<AGROW>
    end
    t0 = tic;
    stats = train(agent, env, rlTrainingOptions(topt{:}));
    tTrain = toc(t0);
    n = numel(stats.EpisodeReward);
    curve = [curve; table(nEp + (1:n).', c * ones(n, 1), stats.EpisodeReward(:), stats.EpisodeSteps(:), ...
        'VariableNames', {'episode', 'chunk', 'reward', 'steps'})]; %#ok<AGROW>
    nEp = nEp + n;
    t0 = tic;
    Tc = evalAgent(agent, Pcur, C, [envArgs, {'tol', o.tol}]);
    Te = evalAgent(agent, Pev, C, envArgs);
    tEval = toc(t0);
    sc = mean(Tc.outcome == "success");
    se = mean(Te.outcome == "success");
    row = struct('chunk', c, 'episodes', nEp, 'minutes', toc(tStart) / 60, 'tol', o.tol, 'cur_success', sc, ...
        'eval_success', se, 'cur_d_med_mm', 1000 * median(Tc.d), 'eval_d_med_mm', 1000 * median(Te.d), ...
        'eval_d_q90_mm', 1000 * prctile(Te.d, 90), 'eval_vend_med_mms', 1000 * median(Te.v_end), ...
        'eval_clamp', sum(Te.outcome == "clamp"), 'eval_ood', sum(Te.outcome == "ood"), ...
        'eval_timeout', sum(Te.outcome == "timeout"), 'train_reward_mean', mean(stats.EpisodeReward), ...
        'train_steps_mean', mean(stats.EpisodeSteps), 'train_min', tTrain / 60, 'eval_min', tEval / 60);
    logRows{end + 1} = row; %#ok<AGROW>
    fprintf(['Abschnitt %2d: %5d Episoden, %5.1f min, Pruefung %3.0f %% (Median %.1f mm), Auswertung %3.0f %% ', ...
             '(Median %.1f mm, %.1f mm/s, Zeitende %d), Training %.1f min, Auswertung %.1f min\n'], ...
            c, nEp, row.minutes, 100 * sc, row.cur_d_med_mm, 100 * se, row.eval_d_med_mm, row.eval_vend_med_mms, ...
            row.eval_timeout, row.train_min, row.eval_min);
    if se > bestSucc || (se == bestSucc && median(Te.d) < median(evalBest.d))
        bestSucc = se; best = copyAgent(agent); evalBest = Te;
    end
end
log = struct2table([logRows{:}]);
info = struct('wallTime_s', toc(tStart), 'numWorkers', nW, 'matlab', version, ...
    'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), 'computer', getenv('COMPUTERNAME'));
name = 'X6_sac';
if o.her, name = [name '_her']; end
if ~isempty(o.label), name = [name '_' o.label]; end
name = sprintf('%s_seed%d', name, o.seed);
if isempty(o.tag)
    agentDir = sk_path('SavedAgents', 'MotionProfile', 'X6');
    csvDir = dd;
else
    name = [name '_' o.tag];
    agentDir = sk_path('data', 'simulation', 'desktop', '_test');
    csvDir = agentDir;
end
if ~isfolder(agentDir), mkdir(agentDir); end
agentFile = fullfile(agentDir, [name '.mat']);
agent.ExperienceBuffer = rlReplayMemory(info0.obsInfo, info0.actInfo, 1);   % Puffer nicht mitspeichern
best.ExperienceBuffer = rlReplayMemory(info0.obsInfo, info0.actInfo, 1);
save(agentFile, 'agent', 'best', 'cfg', 'log', 'evalBest', 'info', 'curve');
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
writetable(log, fullfile(csvDir, sprintf('%s_log_%s.csv', name, stamp)));
writetable(curve, fullfile(csvDir, sprintf('%s_curve_%s.csv', name, stamp)));
writetable(evalBest, fullfile(csvDir, sprintf('%s_eval_%s.csv', name, stamp)));
fprintf('X6 SAC fertig nach %.1f min, bester Auswertewert %.0f %%. Gespeichert: %s\n', info.wallTime_s / 60, ...
        100 * bestSucc, agentFile);
out = struct('agentFile', agentFile, 'log', log, 'evalBest', evalBest, 'cfg', cfg);
end

% =====================================================================
function T = evalAgent(agent, pp, C, args)
% Agent deterministisch auf den Paaren pp, parallel in Bloecken (Paare der Reihe nach), Ende bei Erfolg
agent.UseExplorationPolicy = false;
pol = getGreedyPolicy(agent);
nb = min(numel(pp), 32);
blk = cell(nb, 1);
for b = 1:nb, blk{b} = b:nb:numel(pp); end
res = cell(nb, 1);
parfor b = 1:nb
    env = ext_x6_env(pp(blk{b}), 'chainP', C, 'sequential', true, args{:});
    rows = [];
    for k = 1:numel(blk{b})
        obs = reset(env); done = false; vEnd = NaN;
        while ~done
            a = getAction(pol, {obs});
            [obs, ~, done] = step(env, a{1});
        end
        Ls = env.LoggedSignals;
        y = ext_x6_plant('meas', Ls.S);
        vEnd = norm(y.v);
        rows = [rows; struct('id', Ls.id, 'outcome', Ls.outcome, 'd', Ls.d, 'v_end', vEnd, 'steps', Ls.n, ...
                             'd0', Ls.d0)]; %#ok<AGROW>
    end
    res{b} = rows;
end
T = struct2table(vertcat(res{:}));
agent.UseExplorationPolicy = true;
end

function b = copyAgent(agent)
% unabhaengige Kopie ohne Erfahrungsspeicher (Agenten sind Handle-Objekte)
buf = agent.ExperienceBuffer;
agent.ExperienceBuffer = rlReplayMemory(agent.ObservationInfo, agent.ActionInfo, 1);
tmp = [tempname '.mat'];
save(tmp, 'agent');
L = load(tmp, 'agent');
delete(tmp);
agent.ExperienceBuffer = buf;
b = L.agent;
end
