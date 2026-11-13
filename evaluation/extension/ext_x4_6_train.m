function out = ext_x4_6_train(variant, seed, varargin)
%EXT_X4_6_TRAIN  Training fuer die Ablation X4.6 (woher kommt der Abstand von RL zum Regler?).
%   out = ext_x4_6_train('V1', 0)
%   out = ext_x4_6_train('V2', 0, 'nEpisodes', 16, 'tag', 'test')   Kurztest unter data/simulation/desktop/_test
%
%   Aufbau genau wie D16 r4 (desktop_d12_train(4, seed, 3000, '', 'base_sync', 0.9774)): Reward-Modus 4 mit
%   Gewicht 2, J6 0,9774 rad/s, 40 Hz, 65 kg, Optionen des fruehen PPO (Horizont 1024, Minibatch 128, Lernraten
%   1e-3 / 5e-4, 10 Epochen, Clip 0,2, gamma 0,99, GAE 0,95, Entropie 1e-3, 2 x 128 ReLU), synchron parallel,
%   Gradient Clipping 1, ein train-Aufruf. Unterschiede je Variante (aufbauend):
%     V1  Beobachtungsgrenzen in der Reihenfolge der Beobachtung (A72, E9): ep 0,5, ev 1, v_base 0,5, w_base 1,
%         q wie die Gelenkgrenzen, dq 1,3963 / 1,2218, e_ori pi. Modell SK_desktop
%     V2  V1 und 9 Kanaele mehr (Kette J2, J4, J6 im vorigen Schritt, Sollpunkt in 0,25 s und 0,5 s relativ zum
%         EE), Grenzen 1. Modell SK_x46 (ext_x4_6_build_model, Filter 0,95)
%     V3  V2 mit Filter 0,85 (Zeitkonstante etwa 0,15 s, E17). Modell SK_x46f
%     V4  V1 mit Rate Limiter 2 statt 0,5 rad/s^2 (Nachtrag 13.11., A75). Modell SK_x46s, 29 Kanaele
%   Ergebnis:
%     SavedAgents/MotionProfile/X4_6/X4_6_ppo_40hz_r4_<V>_seed<Seed>_ep<Episoden>.mat   agent, cfg, info, curve
%     data/simulation/extension/<Name>_train.csv   Lernkurve je Episode

p = inputParser;
p.addParameter('nEpisodes', 3000);
p.addParameter('tag', '');
p.parse(varargin{:});
o = p.Results;
assert(ismember(variant, {'V1', 'V2', 'V3', 'V4'}), 'ext_x4_6_train:variant', 'Variante V1 bis V4');
setup_project;
models = struct('V1', 'SK_desktop', 'V2', 'SK_x46', 'V3', 'SK_x46f', 'V4', 'SK_x46s');
filts = struct('V1', 0.95, 'V2', 0.95, 'V3', 0.85, 'V4', 0.95);
slews = struct('V1', 0.5, 'V2', 0.5, 'V3', 0.5, 'V4', 2);
mdl = models.(variant);
if strcmp(mdl, 'SK_desktop')
    desktop_build_model();
elseif strcmp(variant, 'V4')
    ext_x4_6_build_model(mdl, filts.(variant), false, slews.(variant), false);
else
    ext_x4_6_build_model(mdl, filts.(variant));
end
if ~bdIsLoaded(mdl), load_system(mdl); end
set_param(mdl, 'SimMechanicsOpenEditorOnUpdate', 'off');
rewardMode = 4; j6Lim = 0.9774; baseW = 2;

cfg = struct('variant', variant, 'model', mdl, 'filtA', filts.(variant), 'slew', slews.(variant), ...
    'rewardMode', rewardMode, ...
    'optsSet', 'base_sync', 'j6Lim', j6Lim, 'baseW', baseW, 'rateHz', 40, 'seed', seed, ...
    'nEpisodes', o.nEpisodes, 'Ts_agent', 0.025, 'Ts', 0.005, 'T', 8.5, 'base_mass', 65, 'hidden', 128, ...
    'parMode', 'sync', 'gradThreshold', 1);
cfg.opts = struct('ExperienceHorizon', 1024, 'MiniBatchSize', 128, 'NumEpoch', 10, 'ClipFactor', 0.2, ...
    'DiscountFactor', 0.99, 'GAEFactor', 0.95, 'EntropyLossWeight', 1e-3, 'ActorLR', 1e-3, 'CriticLR', 5e-4);

% --- Workspace wie desktop_d12_train, dazu die Vorschau der Referenz ---
ec = desktop_config('Ts', cfg.Ts, 'Ts_agent', cfg.Ts_agent, 'T', cfg.T, 'base_mass', cfg.base_mass);
[EE_ref, EE_vref] = makeReference(ec);
EE_d25 = timeseries(ext_ref_preview(EE_ref.Time, EE_ref.Data, 0.25), EE_ref.Time);
EE_d50 = timeseries(ext_ref_preview(EE_ref.Time, EE_ref.Data, 0.5), EE_ref.Time);
vars = struct('EE_ref', EE_ref, 'EE_vref', EE_vref, 'EE_d25', EE_d25, 'EE_d50', EE_d50, 'reward_init', 0, ...
    'isdone_init', 0, 'p_Ts', ec.Ts, 'p_Ts_agent', ec.Ts_agent, 'p_T', ec.T, 'p_base_mass', ec.base_mass, ...
    'p_delay_steps', 0, 'p_damp_scale', 1, 'p_slew', ec.slew, 'p_cmd_scale', 1, 'p_obs_mode', 0, ...
    'p_obs_noise', zeros(29, 1), 'p_reward_mode', rewardMode, 'p_j6_lim', j6Lim, 'p_base_w', baseW, ...
    'p_q0', zeros(7, 1), 'p_lambda', 0, 'p_theta', 0.03, 'p_cost_type', 1, 'p_inertia_scale', 1);
fn = fieldnames(vars);
for k = 1:numel(fn)
    assignin('base', fn{k}, vars.(fn{k}));
end

% --- Spezifikationen: Aktion wie Optimized.mat, Beobachtung mit eigenen Grenzen ---
ref = load(sk_path('SavedAgents', 'MotionProfile', 'Circle', 'PPO', 'Optimized.mat'), 'agent');
oi0 = getObservationInfo(ref.agent);
actInfo = getActionInfo(ref.agent);
qLim = [2*pi; 2.41; 2*pi; 2.66; 2.23; 2.01; 2*pi];
dqLim = [1.3963; 1.3963; 1.3963; 1.3963; 1.2218; 1.2218; 1.2218];
hi = [0.5 * ones(3, 1); ones(3, 1); 0.5 * ones(3, 1); ones(3, 1); qLim; dqLim; pi * ones(3, 1)];
if ismember(variant, {'V2', 'V3'}), hi = [hi; ones(9, 1)]; end
obsInfo = rlNumericSpec([numel(hi) 1], 'LowerLimit', -hi, 'UpperLimit', hi);
obsInfo.Name = oi0.Name;
obsInfo.Description = oi0.Description;
cfg.obsHi = hi;

% --- Agent wie desktop_d12_train ('base_sync') ---
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
env.ResetFcn = @(in) setVariable(setVariable(setVariable(setVariable(setVariable(in, 'reward_init', 0), ...
    'isdone_init', 0), 'p_reward_mode', rewardMode), 'p_j6_lim', j6Lim), 'p_base_w', baseW);
trainOpts = rlTrainingOptions('MaxEpisodes', o.nEpisodes, 'MaxStepsPerEpisode', floor(cfg.T / cfg.Ts_agent), ...
    'ScoreAveragingWindowLength', 25, 'StopTrainingCriteria', 'EpisodeCount', 'StopTrainingValue', o.nEpisodes, ...
    'Plots', 'none', 'Verbose', false, 'StopOnError', 'off', 'UseParallel', true, ...
    'ParallelizationOptions', rl.option.ParallelTraining('Mode', cfg.parMode));

pool = gcp('nocreate');
if isempty(pool), pool = parpool('Processes'); end
fprintf('X4.6 %s: Modell %s, %d Kanaele, Filter %.2f, Seed %d, %d Episoden, %d Worker\n', variant, mdl, ...
        numel(hi), cfg.filtA, seed, o.nEpisodes, pool.NumWorkers);
tStart = tic;
stats = train(agent, env, trainOpts);
wallTime = toc(tStart);
fprintf('X4.6 %s: Training fertig nach %.1f min\n', variant, wallTime / 60);

info = struct('wallTime_s', wallTime, 'numWorkers', pool.NumWorkers, 'matlab', version, 'git', gitInfo(), ...
    'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), 'computer', getenv('COMPUTERNAME'));
curve = table((1:numel(stats.EpisodeReward)).', stats.EpisodeReward(:), stats.AverageReward(:), ...
    stats.EpisodeQ0(:), stats.EpisodeSteps(:), 'VariableNames', {'episode', 'reward', 'avg_reward', 'q0', 'steps'});
name = sprintf('X4_6_ppo_40hz_r4_%s_seed%d_ep%d', variant, seed, o.nEpisodes);
if isempty(o.tag)
    agentDir = sk_path('SavedAgents', 'MotionProfile', 'X4_6');
    csvDir = sk_path('data', 'simulation', 'extension');
else
    name = [name '_' o.tag];
    agentDir = sk_path('data', 'simulation', 'desktop', '_test');
    csvDir = agentDir;
end
if ~isfolder(agentDir), mkdir(agentDir); end
agentFile = fullfile(agentDir, [name '.mat']);
save(agentFile, 'agent', 'cfg', 'info', 'curve');
writetable(curve, fullfile(csvDir, [name '_train.csv']));
fprintf('Gespeichert: %s\n', agentFile);
out = struct('agentFile', agentFile, 'cfg', cfg, 'info', info, 'curve', curve);
end

% =====================================================================
function [EE_ref, EE_vref] = makeReference(cfg)
% Halbkreis nach Zeit wie desktop_d12_train
t = 0:cfg.Ts:cfg.T;
omega = pi / cfg.T_path;
x = cfg.center(1) + cfg.r * sin(omega * t);
y = cfg.center(2) + 0 * t;
z = cfg.center(3) + cfg.r * cos(omega * t);
traj = [x(:), y(:), z(:)];
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
