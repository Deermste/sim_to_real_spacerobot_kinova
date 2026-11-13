function out = ext_x6_pilot(variant, seed, varargin)
%EXT_X6_PILOT  Pilot X6.3: PPO in der Schritt-Umgebung ext_x6_env (frei schwebend, 7 Gelenke), drei Varianten.
%   out = ext_x6_pilot('a', 0)
%   out = ext_x6_pilot('a', 0, 'chunk', 16, 'maxEpisodes', 32, 'nEval', 8, 'nCur', 8, 'tag', 'test')   Kurztest
%
%   Varianten (PLAN X6.3):
%     a  Kette E18 bei 20 Hz (chain_step('params'), a_max 2 rad/s^2 Platzhalter), Feinkanal und Feinterm
%     b  wie a, ohne Feinkanal und Feinterm (47 Kanaele, w_fine 0)
%     c  wie a, aber 10 Hz und Filter tau 2 s in der Kette (wie fixed1: 0,95 je Schritt bei 10 Hz, tau 1,95 s)
%   Ohne Randomisierung (Strecke wie ext_x6_plant, Nominalmodell). Kollision je Schritt beendet die Episode.
%
%   Training in Abschnitten zu 'chunk' Episoden (je Abschnitt ein train-Aufruf, Agent wird weitergegeben).
%   Trainingspaare aus dem neuesten X6_train_*.mat, Auswertepaare aus dem neuesten X6_pairs_*.mat (set "eval").
%   Curriculum (vom Treiber gesteuert, gilt fuer alle Worker):
%     Stufe        1      2      3      4
%     tol [m]      0,05   0,02   0,01   0,005     Erfolg: Abstand <= tol und Geschwindigkeit <= tol, 1 s lang
%     dcap [m]     0,2    0,4    0,8    Inf       Ziel auf der Geraden auf hoechstens dcap verkuerzt
%     pFull 0,2 (Anteil der Episoden mit voller Weglaenge, Toleranz der Stufe)
%   Nach jedem Abschnitt, Agent deterministisch:
%     - Stufenpruefung auf nCur festen Trainingspaaren mit tol und dcap der Stufe. Ab 80 % Erfolg naechste Stufe.
%     - Auswertung auf den ersten nEval Paaren des Auswertesatzes mit 5 mm (E11), volle Weglaenge.
%   Ende nach maxEpisodes oder maxHours (geprueft nach jedem Abschnitt).
%   PPO: 2 x 256 (rlAgentInitializationOptions), Horizont 1024, Minibatch 256, 10 Epochen, Clip 0,2,
%   gamma 0,99, GAE 0,95, Entropie 1e-3, Lernraten Actor 3e-4 / Critic 1e-3, Gradient Clipping 1, synchron
%   parallel.
%   Ergebnis:
%     SavedAgents/MotionProfile/X6/X6_pilot_<V>_seed<S>.mat     agent (letzter), best (bester Auswertewert),
%                                                               cfg, log, evalBest, info
%     data/simulation/extension/X6_pilot_<V>_seed<S>_{log,curve,eval}_<Zeit>.csv

p = inputParser;
p.addParameter('maxEpisodes', 20000);
p.addParameter('maxHours', 2);
p.addParameter('chunk', 500);
p.addParameter('nEval', 100);
p.addParameter('nCur', 48);
p.addParameter('tag', '');
p.parse(varargin{:});
o = p.Results;
assert(ismember(variant, {'a', 'b', 'c'}), 'ext_x6_pilot:variant', 'Variante a, b oder c');
setup_project;
dd = sk_path('data', 'simulation', 'extension');
dT = dir(fullfile(dd, 'X6_train_*.mat'));
dE = dir(fullfile(dd, 'X6_pairs_*.mat'));
Lt = load(fullfile(dT(end).folder, dT(end).name), 'P');
Le = load(fullfile(dE(end).folder, dE(end).name), 'P');
Ptr = Lt.P;
Pev = Le.P([Le.P.set] == "eval");
Pev = Pev(1:min(o.nEval, numel(Pev)));
rsC = RandStream('mt19937ar', 'Seed', 500 + seed);
Pcur = Ptr(randperm(rsC, numel(Ptr), o.nCur));

C = chain_step('params');
envArgs = {};
if variant == "b", envArgs = {'fine', false}; end
if variant == "c", C.Ts = 0.1; C.tau = 2; end
lv = struct('tol', {0.05, 0.02, 0.01, 0.005}, 'dcap', {0.2, 0.4, 0.8, Inf});
pFull = 0.2;
cfg = struct('variant', variant, 'seed', seed, 'chainP', C, 'envArgs', {envArgs}, 'levels', lv, 'pFull', pFull, ...
    'chunk', o.chunk, 'maxEpisodes', o.maxEpisodes, 'maxHours', o.maxHours, 'nEval', numel(Pev), ...
    'nCur', o.nCur, 'trainFile', dT(end).name, 'evalFile', dE(end).name, 'hidden', 256);
cfg.opts = struct('ExperienceHorizon', 1024, 'MiniBatchSize', 256, 'NumEpoch', 10, 'ClipFactor', 0.2, ...
    'DiscountFactor', 0.99, 'GAEFactor', 0.95, 'EntropyLossWeight', 1e-3, 'ActorLR', 3e-4, 'CriticLR', 1e-3);

[env0, info0] = ext_x6_env(Ptr, 'chainP', C, envArgs{:});
rng(seed, 'twister');
agent = rlPPOAgent(info0.obsInfo, info0.actInfo, rlAgentInitializationOptions('NumHiddenUnit', cfg.hidden));
ao = agent.AgentOptions;
ao.SampleTime = C.Ts;
ao.ExperienceHorizon = cfg.opts.ExperienceHorizon;
ao.MiniBatchSize = cfg.opts.MiniBatchSize;
ao.NumEpoch = cfg.opts.NumEpoch;
ao.ClipFactor = cfg.opts.ClipFactor;
ao.DiscountFactor = cfg.opts.DiscountFactor;
ao.GAEFactor = cfg.opts.GAEFactor;
ao.EntropyLossWeight = cfg.opts.EntropyLossWeight;
ao.ActorOptimizerOptions.LearnRate = cfg.opts.ActorLR;
ao.CriticOptimizerOptions.LearnRate = cfg.opts.CriticLR;
ao.ActorOptimizerOptions.GradientThreshold = 1;
ao.CriticOptimizerOptions.GradientThreshold = 1;
agent.AgentOptions = ao;
clear env0

pool = gcp('nocreate');
if isempty(pool), pool = parpool('Processes'); end
nMax = round(15 / C.Ts);
fprintf('X6 Pilot %s, Seed %d: %d Kanaele, %.0f Hz, %d Trainings- und %d Auswertepaare, %d Worker\n', variant, ...
        seed, info0.obsInfo.Dimension(1), 1 / C.Ts, numel(Ptr), numel(Pev), pool.NumWorkers);

level = 1; nEp = 0; c = 0; tStart = tic;
logRows = {}; curve = table(); bestSucc = -1; best = agent; evalBest = table();
while nEp < o.maxEpisodes && toc(tStart) < 3600 * o.maxHours
    c = c + 1;
    nC = min(o.chunk, o.maxEpisodes - nEp);
    env = ext_x6_env(Ptr, 'chainP', C, envArgs{:}, 'tol', lv(level).tol, 'dcap', lv(level).dcap, ...
                     'pFull', pFull, 'seed', 1000 * seed + c);
    trainOpts = rlTrainingOptions('MaxEpisodes', nC, 'MaxStepsPerEpisode', nMax, ...
        'ScoreAveragingWindowLength', 50, 'StopTrainingCriteria', 'EpisodeCount', 'StopTrainingValue', nC, ...
        'Plots', 'none', 'Verbose', false, 'StopOnError', 'off', 'UseParallel', true, ...
        'ParallelizationOptions', rl.option.ParallelTraining('Mode', 'sync'));
    t0 = tic;
    stats = train(agent, env, trainOpts);
    tTrain = toc(t0);
    n = numel(stats.EpisodeReward);
    curve = [curve; table(nEp + (1:n).', c * ones(n, 1), level * ones(n, 1), stats.EpisodeReward(:), ...
        stats.EpisodeSteps(:), 'VariableNames', {'episode', 'chunk', 'level', 'reward', 'steps'})]; %#ok<AGROW>
    nEp = nEp + n;
    t0 = tic;
    Tc = evalAgent(agent, Pcur, C, [envArgs, {'tol', lv(level).tol, 'dcap', lv(level).dcap}]);
    Te = evalAgent(agent, Pev, C, envArgs);
    tEval = toc(t0);
    sc = mean(Tc.outcome == "success");
    se = mean(Te.outcome == "success");
    row = struct('chunk', c, 'episodes', nEp, 'minutes', toc(tStart) / 60, 'level', level, ...
        'tol', lv(level).tol, 'dcap', lv(level).dcap, 'cur_success', sc, 'eval_success', se, ...
        'eval_d_med_mm', 1000 * median(Te.d), 'eval_d_q90_mm', 1000 * prctile(Te.d, 90), ...
        'eval_coll', sum(Te.outcome == "coll"), 'eval_ood', sum(Te.outcome == "ood"), ...
        'eval_clamp', sum(Te.outcome == "clamp"), 'eval_timeout', sum(Te.outcome == "timeout"), ...
        'train_reward_mean', mean(stats.EpisodeReward), 'train_steps_mean', mean(stats.EpisodeSteps), ...
        'train_min', tTrain / 60, 'eval_min', tEval / 60);
    logRows{end + 1} = row; %#ok<AGROW>
    fprintf(['Abschnitt %2d: %5d Episoden, %5.1f min, Stufe %d, Stufenpruefung %3.0f %%, Auswertung %3.0f %% ', ...
             '(Median %.1f mm, Kollision %d, OOD %d, Zeitende %d), Training %.1f min, Auswertung %.1f min\n'], ...
            c, nEp, row.minutes, level, 100 * sc, 100 * se, row.eval_d_med_mm, row.eval_coll, row.eval_ood, ...
            row.eval_timeout, row.train_min, row.eval_min);
    if se > bestSucc || (se == bestSucc && median(Te.d) < median(evalBest.d))
        bestSucc = se; best = copyAgent(agent); evalBest = Te;
    end
    if sc >= 0.8 && level < numel(lv)
        level = level + 1;
        fprintf('  -> Stufe %d (tol %.3f m, dcap %.1f m)\n', level, lv(level).tol, lv(level).dcap);
    end
end
log = struct2table([logRows{:}]);
info = struct('wallTime_s', toc(tStart), 'numWorkers', pool.NumWorkers, 'matlab', version, ...
    'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), 'computer', getenv('COMPUTERNAME'));
name = sprintf('X6_pilot_%s_seed%d', variant, seed);
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
save(agentFile, 'agent', 'best', 'cfg', 'log', 'evalBest', 'info', 'curve');
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
writetable(log, fullfile(csvDir, sprintf('%s_log_%s.csv', name, stamp)));
writetable(curve, fullfile(csvDir, sprintf('%s_curve_%s.csv', name, stamp)));
writetable(evalBest, fullfile(csvDir, sprintf('%s_eval_%s.csv', name, stamp)));
fprintf('X6 Pilot %s fertig nach %.1f min, bester Auswertewert %.0f %%. Gespeichert: %s\n', variant, ...
        info.wallTime_s / 60, 100 * bestSucc, agentFile);
out = struct('agentFile', agentFile, 'log', log, 'evalBest', evalBest, 'cfg', cfg);
end

% =====================================================================
function T = evalAgent(agent, pp, C, args)
% Agent deterministisch auf den Paaren pp, parallel in Bloecken (je Block eine Umgebung, Paare der Reihe nach)
agent.UseExplorationPolicy = false;
nb = min(numel(pp), 32);
blk = cell(nb, 1);
for b = 1:nb, blk{b} = b:nb:numel(pp); end
res = cell(nb, 1);
parfor b = 1:nb
    env = ext_x6_env(pp(blk{b}), 'chainP', C, 'sequential', true, args{:});
    rows = [];
    for k = 1:numel(blk{b})
        obs = reset(env); done = false;
        while ~done
            a = getAction(agent, {obs});
            [obs, ~, done] = step(env, a{1});
        end
        Ls = env.LoggedSignals;
        rows = [rows; struct('id', Ls.id, 'outcome', Ls.outcome, 'd', Ls.d, 'steps', Ls.n, ...
                             'd0', Ls.d0, 'nMesh', Ls.nMesh)]; %#ok<AGROW>
    end
    res{b} = rows;
end
T = struct2table(vertcat(res{:}));
agent.UseExplorationPolicy = true;
end

function b = copyAgent(agent)
% unabhaengige Kopie (Agenten sind Handle-Objekte)
tmp = [tempname '.mat'];
save(tmp, 'agent');
L = load(tmp, 'agent');
delete(tmp);
b = L.agent;
end
