function out = ext_x1_train(theta, seed, varargin)
%EXT_X1_TRAIN  PPO mit Nebenbedingung auf die Basisdrehung, Lagrange-Multiplikator in Bloecken (Ausbau X1.1).
%   out = ext_x1_train(0.03, 0)                          Budget 0,03 rad, Seed 0, 3000 Episoden, Kandidat A
%   out = ext_x1_train(0.03, 0, 'cost_type', 2, 'eta', 0.5)
%   out = ext_x1_train(0.03, 0, 'nEpisodes', 32, 'block', 16, 'tag', 'test')   Kurztest
%
%   Aufbau wie D16/D17 (desktop_d12_train mit 'base_sync', J6 0,9774 rad/s, 40 Hz, 65 kg, Optionen des fruehen
%   PPO, synchrones paralleles Training, Gradient Clipping), aber Reward-Modus 5: nur Tracking (wie Modus 1)
%   minus lambda*c_t. Die Basis wirkt nur ueber die Nebenbedingung.
%     cost_type 1 (Kandidat A): c_t = 1 wenn |ori_t| > theta. Nebenbedingung: mittlere Kosten je Episode <= delta
%     cost_type 2 (Kandidat B): c_t = max(0, |ori_t| - theta)/theta. Nebenbedingung wie A
%   Training in Bloecken zu 'block' Episoden. Agent und Optimiererzustand bleiben zwischen den Bloecken erhalten.
%   Nach jedem Block: C = Mittel der Episodenkosten des Blocks (aus dem geloggten Signal 'cost' in
%   SimulationInfo, also mit der Explorations-Policy), lambda_I <- min(max(lambda_I + eta*(C - delta), 0),
%   lambdaMax) und lambda = min(max(lambda_I + kp*(C - delta), 0), lambdaMax) fuer den naechsten Block
%   (PID-Lagrange nach Stooke et al. 2020 ohne D-Anteil). Mit kp = 0 (Standard) ist lambda = lambda_I wie in X1.2.
%
%   Optionen: nEpisodes 3000, block 100, eta 2, kp 0, delta 0,02, cost_type 1, lambda0 0, lambdaMax 20,
%   model 'SK_desktop', tag '' (nicht leer: Ablage unter data/simulation/desktop/_test).
%   Ergebnis:
%     SavedAgents/MotionProfile/X1/<Name>.mat   agent, cfg, info, curve, dual
%     data/simulation/extension/<Name>_dual.csv  je Block: lambda vorher, C, Return, lambda nachher, Minuten
%     data/simulation/extension/<Name>_train.csv je Episode: Return, Kosten (Mittel und Summe), lambda
%   <Name> = X1_ppo_40hz_r5_c<Typ>_th<theta in mrad>_eta<eta>_seed<Seed>_ep<Episoden>, dazu am Ende _b<block>,
%   wenn block ~= 100, _l<lambda0>, wenn lambda0 ~= 0, und _kp<kp>, wenn kp > 0 (X1.2b)

p = inputParser;
p.addParameter('nEpisodes', 3000);
p.addParameter('block', 100);
p.addParameter('eta', 2);
p.addParameter('kp', 0);
p.addParameter('delta', 0.02);
p.addParameter('cost_type', 1);
p.addParameter('lambda0', 0);
p.addParameter('lambdaMax', 20);
p.addParameter('model', 'SK_desktop');
p.addParameter('tag', '');
% X5 (14.11.2026): 3D-Bahn mit allen sieben Gelenken. Mit den Standardwerten wie bisher.
p.addParameter('rewardMode', 5);      % 4 = r4 (D16, w 2), dann eta 0 und lambda0 0 setzen
p.addParameter('path', 'planar');
p.addParameter('tilt', 30);
p.addParameter('lim7', []);           % 7x1 Saettigung (p_lim7 im Modell-Workspace)
p.addParameter('j6Lim', 0.9774);
p.addParameter('obsBounds', 'old');   % 'old' wie Optimized.mat (A72, E8), 'correct' in der Reihenfolge der Beobachtung (E9)
p.addParameter('prefix', 'X1');       % Namensanfang und Ordner unter SavedAgents/MotionProfile
p.parse(varargin{:});
o = p.Results;
assert(ismember(o.cost_type, [1 2]), 'ext_x1_train:cost', 'cost_type muss 1 oder 2 sein');
assert(mod(o.nEpisodes, o.block) == 0, 'ext_x1_train:block', 'nEpisodes muss ein Vielfaches von block sein');
assert(ismember(o.rewardMode, [4 5]), 'ext_x1_train:mode', 'rewardMode 4 oder 5');
mdl = o.model;
j6Lim = o.j6Lim;
rewardMode = o.rewardMode;

setup_project;
desktop_build_model(false, mdl);
if ~bdIsLoaded(mdl), load_system(mdl); end
set_param(mdl, 'SimMechanicsOpenEditorOnUpdate', 'off');

cfg = struct('rewardMode', rewardMode, 'optsSet', 'base_sync', 'j6Lim', j6Lim, 'baseW', 2, 'theta', theta, ...
    'costType', o.cost_type, 'eta', o.eta, 'kp', o.kp, 'delta', o.delta, 'block', o.block, 'lambda0', o.lambda0, ...
    'lambdaMax', o.lambdaMax, 'model', mdl, 'rateHz', 40, 'seed', seed, 'nEpisodes', o.nEpisodes, ...
    'Ts_agent', 0.025, 'Ts', 0.005, 'T', 8.5, 'base_mass', 65, 'hidden', 128, 'parMode', 'sync', ...
    'gradThreshold', 1, 'path', o.path, 'tilt', o.tilt, 'lim7', o.lim7, 'obsBounds', o.obsBounds);
cfg.opts = struct('ExperienceHorizon', 1024, 'MiniBatchSize', 128, 'NumEpoch', 10, 'ClipFactor', 0.2, ...
    'DiscountFactor', 0.99, 'GAEFactor', 0.95, 'EntropyLossWeight', 1e-3, 'ActorLR', 1e-3, 'CriticLR', 5e-4);

% --- Workspace wie in desktop_d12_train ---
ec = desktop_config('Ts', cfg.Ts, 'Ts_agent', cfg.Ts_agent, 'T', cfg.T, 'base_mass', cfg.base_mass, ...
                    'path', o.path, 'tilt', o.tilt);
[EE_ref, EE_vref] = makeReference(ec);
vars = struct('EE_ref', EE_ref, 'EE_vref', EE_vref, 'reward_init', 0, 'isdone_init', 0, ...
    'p_Ts', ec.Ts, 'p_Ts_agent', ec.Ts_agent, 'p_T', ec.T, 'p_base_mass', ec.base_mass, ...
    'p_delay_steps', 0, 'p_damp_scale', 1, 'p_slew', ec.slew, 'p_cmd_scale', 1, 'p_obs_mode', 0, ...
    'p_obs_noise', zeros(29, 1), 'p_reward_mode', rewardMode, 'p_j6_lim', j6Lim, 'p_base_w', 2, ...
    'p_q0', zeros(7, 1), 'p_lambda', o.lambda0, 'p_theta', theta, 'p_cost_type', o.cost_type, ...
    'p_inertia_scale', 1);
fn = fieldnames(vars);
for k = 1:numel(fn)
    assignin('base', fn{k}, vars.(fn{k}));
end

% --- Agent wie desktop_d12_train ('base_sync') ---
ref = load(sk_path('SavedAgents', 'MotionProfile', 'Circle', 'PPO', 'Optimized.mat'), 'agent');
obsInfo = getObservationInfo(ref.agent);       % Grenzen unveraendert (E8, A72)
actInfo = getActionInfo(ref.agent);
if strcmp(o.obsBounds, 'correct')               % E9 (X5): wie X4.6 V1
    qL = [2*pi; 2.41; 2*pi; 2.66; 2.23; 2.01; 2*pi];
    dqL = [1.3963; 1.3963; 1.3963; 1.3963; 1.2218; 1.2218; 1.2218];
    hi = [0.5 * ones(3, 1); ones(3, 1); 0.5 * ones(3, 1); ones(3, 1); qL; dqL; pi * ones(3, 1)];
    oi0 = obsInfo;
    obsInfo = rlNumericSpec([29 1], 'LowerLimit', -hi, 'UpperLimit', hi);
    obsInfo.Name = oi0.Name;
    obsInfo.Description = oi0.Description;
    cfg.obsHi = hi;
end
rng(seed, 'twister');
agent = rlPPOAgent(obsInfo, actInfo, rlAgentInitializationOptions('NumHiddenUnit', cfg.hidden));
ao = agent.AgentOptions;
ao.SampleTime = cfg.Ts_agent;
ao.ExperienceHorizon = cfg.opts.ExperienceHorizon;
ao.MiniBatchSize = cfg.opts.MiniBatchSize;
ao.NumEpoch = cfg.opts.NumEpoch;
ao.ClipFactor = cfg.opts.ClipFactor;
ao.DiscountFactor = cfg.opts.DiscountFactor;
ao.GAEFactor = cfg.opts.GAEFactor;
ao.EntropyLossWeight = cfg.opts.EntropyLossWeight;
ao.ActorOptimizerOptions.LearnRate = cfg.opts.ActorLR;
ao.CriticOptimizerOptions.LearnRate = cfg.opts.CriticLR;
ao.ActorOptimizerOptions.GradientThreshold = cfg.gradThreshold;
ao.CriticOptimizerOptions.GradientThreshold = cfg.gradThreshold;
agent.AgentOptions = ao;
assignin('base', 'agent', agent);

env = rlSimulinkEnv(mdl, [mdl '/RL_Agent'], obsInfo, actInfo);
trainOpts = rlTrainingOptions('MaxEpisodes', o.block, 'MaxStepsPerEpisode', floor(cfg.T / cfg.Ts_agent), ...
    'ScoreAveragingWindowLength', 25, 'StopTrainingCriteria', 'EpisodeCount', 'StopTrainingValue', o.block, ...
    'Plots', 'none', 'Verbose', false, 'StopOnError', 'off', 'UseParallel', true, ...
    'ParallelizationOptions', rl.option.ParallelTraining('Mode', cfg.parMode));

pool = gcp('nocreate');
if isempty(pool), pool = parpool('Processes'); end

if rewardMode == 5
    name = sprintf('%s_ppo_40hz_r5_c%d_th%g_eta%g_seed%d_ep%d', o.prefix, o.cost_type, round(1000 * theta), ...
                   o.eta, seed, o.nEpisodes);
else
    name = sprintf('%s_ppo_40hz_r%d_seed%d_ep%d', o.prefix, rewardMode, seed, o.nEpisodes);
end
if o.block ~= 100, name = sprintf('%s_b%d', name, o.block); end
if o.lambda0 ~= 0, name = sprintf('%s_l%g', name, o.lambda0); end
if o.kp > 0, name = sprintf('%s_kp%g', name, o.kp); end
if ~isempty(o.tag), name = [name '_' o.tag]; end
if isempty(o.tag)
    agentDir = sk_path('SavedAgents', 'MotionProfile', o.prefix);
    csvDir = sk_path('data', 'simulation', 'extension');
else
    agentDir = sk_path('data', 'simulation', 'desktop', '_test');
    csvDir = agentDir;
end
if ~isfolder(agentDir), mkdir(agentDir); end
fprintf('X1: theta %.3f rad, Kosten %d, eta %g, kp %g, delta %g, Seed %d, %d x %d Episoden, %d Worker\n', ...
        theta, o.cost_type, o.eta, o.kp, o.delta, seed, o.nEpisodes / o.block, o.block, pool.NumWorkers);

% --- Bloecke ---
nB = o.nEpisodes / o.block;
lambda = o.lambda0;
lambdaI = o.lambda0;
dual = table('Size', [nB 8], 'VariableTypes', repmat({'double'}, 1, 8), 'VariableNames', ...
    {'block', 'lambda', 'C', 'C_valid', 'ret_mean', 'lambda_next', 'minutes', 'lambda_I'});
curve = table();
tStart = tic;
for b = 1:nB
    tB = tic;
    lam = lambda;
    env.ResetFcn = @(in) resetFcn(in, j6Lim, lam, theta, o.cost_type, rewardMode, o.lim7, mdl);
    assignin('base', 'p_lambda', lam);
    stats = train(agent, env, trainOpts);
    [cMean, cSum] = episodeCost(stats);
    C = mean(cMean, 'omitnan');
    nValid = sum(~isnan(cMean));
    assert(nValid > 0, 'ext_x1_train:cost', 'Block %d: kein Kostensignal in SimulationInfo', b);
    lambdaI = min(max(lambdaI + o.eta * (C - o.delta), 0), o.lambdaMax);
    lambdaNext = min(max(lambdaI + o.kp * (C - o.delta), 0), o.lambdaMax);
    ep0 = (b - 1) * o.block;
    nE = numel(stats.EpisodeReward);
    curve = [curve; table(ep0 + (1:nE).', stats.EpisodeReward(:), stats.EpisodeSteps(:), ...
        cMean(1:nE), cSum(1:nE), repmat(lam, nE, 1), 'VariableNames', ...
        {'episode', 'reward', 'steps', 'cost_mean', 'cost_sum', 'lambda'})]; %#ok<AGROW>
    dual(b, :) = {b, lam, C, nValid, mean(stats.EpisodeReward), lambdaNext, toc(tB) / 60, lambdaI};
    fprintf('X1 Block %2d/%d: lambda %.3f, C %.4f (%d Ep.), Return %.1f -> lambda %.3f (%.1f min)\n', b, nB, ...
            lam, C, nValid, mean(stats.EpisodeReward), lambdaNext, toc(tB) / 60);
    lambda = lambdaNext;
    writetable(dual(1:b, :), fullfile(csvDir, [name '_dual.csv']));
end
wallTime = toc(tStart);
fprintf('X1: Training fertig nach %.1f min\n', wallTime / 60);

info = struct('wallTime_s', wallTime, 'numWorkers', pool.NumWorkers, 'matlab', version, 'git', gitInfo(), ...
    'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), 'computer', getenv('COMPUTERNAME'));
agentFile = fullfile(agentDir, [name '.mat']);
save(agentFile, 'agent', 'cfg', 'info', 'curve', 'dual');
writetable(curve, fullfile(csvDir, [name '_train.csv']));
fprintf('Gespeichert: %s\n', agentFile);
out = struct('agentFile', agentFile, 'cfg', cfg, 'info', info, 'curve', curve, 'dual', dual, ...
             'lastStats', stats);                % fuer ext_x1_check (lambda bei den Workern)
end

% =====================================================================
function in = resetFcn(in, j6Lim, lambda, theta, costType, rewardMode, lim7, mdl)
% Alle Reward-Parameter je Episode setzen, damit sie sicher bei den Workern ankommen (wie D17)
in = setVariable(in, 'reward_init', 0);
in = setVariable(in, 'isdone_init', 0);
in = setVariable(in, 'p_reward_mode', rewardMode);
if ~isempty(lim7)
    in = setVariable(in, 'p_lim7', lim7(:), 'Workspace', mdl);   % X5, Modell-Workspace
end
in = setVariable(in, 'p_j6_lim', j6Lim);
in = setVariable(in, 'p_base_w', 2);
in = setVariable(in, 'p_lambda', lambda);
in = setVariable(in, 'p_theta', theta);
in = setVariable(in, 'p_cost_type', costType);
end

function [cMean, cSum] = episodeCost(stats)
% Mittel und Summe des geloggten Kostensignals je Episode (NaN, wenn es fehlt)
si = stats.SimulationInfo;
if isprop(si, 'NumSimulations')
    n = si.NumSimulations;                  % rl.storage.SimulationStorage (numel ist dort 1)
else
    n = numel(si);
end
cMean = nan(n, 1); cSum = nan(n, 1);
for i = 1:n
    if iscell(si), so = si{i}; else, so = si(i); end
    try
        el = so.logsout.getElement('cost');
        d = double(el.Values.Data(:));
        cMean(i) = mean(d);
        cSum(i) = sum(d);
    catch
    end
end
end

function [EE_ref, EE_vref] = makeReference(cfg)
% Halbkreis nach Zeit wie desktop_d12_train, mit path 'tilted' gekippt (X5, ext_ref_path wie desktop_run_episode)
t = 0:cfg.Ts:cfg.T;
omega = pi / cfg.T_path;
x = cfg.center(1) + cfg.r * sin(omega * t);
y = cfg.center(2) + 0 * t;
z = cfg.center(3) + cfg.r * cos(omega * t);
traj = [x(:), y(:), z(:)];
if strcmp(cfg.path, 'tilted')
    traj = ext_ref_path(t(:), struct('T', cfg.T_path, 'r', cfg.r, 'center', cfg.center, 'path', 'tilted', ...
                                     'tilt', cfg.tilt));
end
vref = [zeros(1, 3); diff(traj) / mean(diff(t))];
EE_ref = timeseries(traj, t);
EE_vref = timeseries(vref, t);
end

function g = gitInfo()
g = struct('hash', '', 'dirty', NaN);
[s1, h] = system(sprintf('git -C "%s" rev-parse --short HEAD', sk_path()));
[s2, d] = system(sprintf('git -C "%s" status --porcelain', sk_path()));
if s1 == 0, g.hash = strtrim(h); end
if s2 == 0, g.dirty = ~isempty(strtrim(d)); end
end
