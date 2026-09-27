function out = desktop_d12_train(rewardMode, seed, nEpisodes, tag, optsSet, j6Lim)
%DESKTOP_D12_TRAIN  Trainiert einen 40-Hz-PPO-Agenten mit geaendertem Reward (Desktop-Plan D12 und D13, Befund A51).
%   out = desktop_d12_train(2, 0)              Variante b, Seed 0, 1000 Episoden
%   out = desktop_d12_train(3, 0, 16, 'test')  Kurztest, speichert nur unter data/.../_test
%   out = desktop_d12_train(2, 0, [], '', 'base')   D13: Optionen des fruehen PPO statt Optimized
%
%   Aufbau wie D10 bei 40 Hz (desktop_d10_train): SK_desktop, Halbkreis 8,5 s, Referenz nach Zeit, 65 kg, keine
%   Verzoegerung, kein CDR, Optionen wie Optimized.mat (Horizont 600, Minibatch 200, 10 Epochen, Clip 0,2,
%   gamma 0,99, GAE 0,95, Entropie 1e-3, Lernraten 5,7e-5 / 1e-3, 2 x 128 ReLU), 1000 Episoden.
%   optsSet 'base' (D13) nimmt stattdessen die Optionen des fruehen PPO (SpaceKinova_PPO_agent_motionprofile.mat):
%   Horizont 1024, Minibatch 128, Lernraten 1e-3 / 5e-4, sonst gleich (Netz ebenfalls 2 x 128 ReLU).
%   optsSet 'base_sync' (D14) wie 'base', aber synchrones paralleles Training und Gradient Clipping (Schwelle 1,
%   L2-Norm) fuer Actor und Critic. Grund: In D13 wurden 6 von 9 Actors mit asynchronem Training NaN.
%   j6Lim (Standard 0,1 rad/s) setzt die Saettigung von J6. Ein anderer Wert ergibt die Studie D16
%   (Physik-Check D15: mit 0,1 rad/s verlangt die Bahn etwa 0,055 rad Basisdrehung).
%   Einziger Unterschied ist der Reward (p_reward_mode, siehe desktop_build_model):
%     0  wie im Training seit 09.04. Das ist D10 (SavedAgents/MotionProfile/D10/D10_ppo_40hz_seed*.mat)
%     1  (a) ohne Basis-Terme, wie beim fruehen PPO. Kontrolle, trennt Reward und Hyperparameter
%     2  (b) Basis-Bonus nur bei EE-Fehler < 5 cm
%     3  (c) dicht und gekoppelt
%     4  wie 2, dazu auf der Bahn ein glatter Basis-Term +2*exp(-(ori/0,05)^2) (nach D16)
%
%   Ergebnis:
%     SavedAgents/MotionProfile/D12/D12_ppo_40hz_r<Modus>_seed<Seed>.mat   agent, cfg, info, curve
%     data/simulation/desktop/D12_40hz_r<Modus>_seed<Seed>_train_<Zeit>.csv   Lernkurve je Episode

if nargin < 2, seed = 0; end
if nargin < 3 || isempty(nEpisodes), nEpisodes = 1000; end
if nargin < 4, tag = ''; end
if nargin < 5 || isempty(optsSet), optsSet = 'optimized'; end
assert(ismember(optsSet, {'optimized', 'base', 'base_sync'}), 'desktop_d12_train:opts', ...
    'optsSet muss optimized, base oder base_sync sein');
study = 'D12';
if strcmp(optsSet, 'base'), study = 'D13'; end
if strcmp(optsSet, 'base_sync'), study = 'D14'; end
if nargin < 6 || isempty(j6Lim), j6Lim = 0.1; end
if j6Lim ~= 0.1, study = 'D16'; end             % D16: hoehere J6-Grenze (Physik-Check D15)
assert(ismember(rewardMode, 0:4), 'desktop_d12_train:mode', 'rewardMode muss 0 bis 4 sein');

setup_project;
desktop_build_model();
mdl = 'SK_desktop';
if ~bdIsLoaded(mdl), load_system(mdl); end
set_param(mdl, 'SimMechanicsOpenEditorOnUpdate', 'off');

cfg = struct();
cfg.rewardMode = rewardMode;
cfg.optsSet = optsSet;
cfg.j6Lim = j6Lim;
cfg.rateHz = 40;
cfg.seed = seed;
cfg.nEpisodes = nEpisodes;
cfg.Ts_agent = 0.025;
cfg.Ts = 0.005;
cfg.T = 8.5;
cfg.base_mass = 65;
cfg.hidden = 128;
cfg.opts = struct('ExperienceHorizon', 600, 'MiniBatchSize', 200, 'NumEpoch', 10, 'ClipFactor', 0.2, ...
    'DiscountFactor', 0.99, 'GAEFactor', 0.95, 'EntropyLossWeight', 1e-3, 'ActorLR', 5.7e-5, 'CriticLR', 1e-3);
cfg.parMode = 'async';
cfg.gradThreshold = Inf;
if ismember(optsSet, {'base', 'base_sync'})
    cfg.opts.ExperienceHorizon = 1024;
    cfg.opts.MiniBatchSize = 128;
    cfg.opts.ActorLR = 1e-3;
    cfg.opts.CriticLR = 5e-4;
end
if strcmp(optsSet, 'base_sync')
    cfg.parMode = 'sync';
    cfg.gradThreshold = 1;
end

% --- Workspace wie in desktop_run_episode (Standardwerte, keine Stoerung) ---
ec = desktop_config('Ts', cfg.Ts, 'Ts_agent', cfg.Ts_agent, 'T', cfg.T, 'base_mass', cfg.base_mass);
[EE_ref, EE_vref] = makeReference(ec);
vars = struct('EE_ref', EE_ref, 'EE_vref', EE_vref, 'reward_init', 0, 'isdone_init', 0, ...
    'p_Ts', ec.Ts, 'p_Ts_agent', ec.Ts_agent, 'p_T', ec.T, 'p_base_mass', ec.base_mass, ...
    'p_delay_steps', 0, 'p_damp_scale', 1, 'p_slew', ec.slew, 'p_cmd_scale', 1, 'p_obs_mode', 0, ...
    'p_obs_noise', zeros(29, 1), 'p_reward_mode', rewardMode, 'p_j6_lim', j6Lim);
fn = fieldnames(vars);
for k = 1:numel(fn)
    assignin('base', fn{k}, vars.(fn{k}));
end

% --- Spezifikationen wie Optimized.mat (gleiche Grenzen und Namen) ---
ref = load(sk_path('SavedAgents', 'MotionProfile', 'Circle', 'PPO', 'Optimized.mat'), 'agent');
obsInfo = getObservationInfo(ref.agent);
actInfo = getActionInfo(ref.agent);

% --- Agent ---
rng(seed, 'twister');
initOpts = rlAgentInitializationOptions('NumHiddenUnit', cfg.hidden);
agent = rlPPOAgent(obsInfo, actInfo, initOpts);
o = agent.AgentOptions;
o.SampleTime = cfg.Ts_agent;
o.ExperienceHorizon = cfg.opts.ExperienceHorizon;
o.MiniBatchSize = cfg.opts.MiniBatchSize;
o.NumEpoch = cfg.opts.NumEpoch;
o.ClipFactor = cfg.opts.ClipFactor;
o.DiscountFactor = cfg.opts.DiscountFactor;
o.GAEFactor = cfg.opts.GAEFactor;
o.EntropyLossWeight = cfg.opts.EntropyLossWeight;
o.ActorOptimizerOptions.LearnRate = cfg.opts.ActorLR;
o.CriticOptimizerOptions.LearnRate = cfg.opts.CriticLR;
o.ActorOptimizerOptions.GradientThreshold = cfg.gradThreshold;
o.CriticOptimizerOptions.GradientThreshold = cfg.gradThreshold;
agent.AgentOptions = o;
assignin('base', 'agent', agent);

% --- Umgebung. Der Reward-Modus wird zusaetzlich pro Episode gesetzt, damit er sicher bei den Workern ankommt ---
env = rlSimulinkEnv(mdl, [mdl '/RL_Agent'], obsInfo, actInfo);
env.ResetFcn = @(in) setVariable(setVariable(setVariable(setVariable(in, 'reward_init', 0), 'isdone_init', 0), ...
    'p_reward_mode', rewardMode), 'p_j6_lim', j6Lim);

% --- Training ---
par = rl.option.ParallelTraining('Mode', cfg.parMode);
trainOpts = rlTrainingOptions( ...
    'MaxEpisodes', nEpisodes, ...
    'MaxStepsPerEpisode', floor(cfg.T / cfg.Ts_agent), ...
    'ScoreAveragingWindowLength', 25, ...
    'StopTrainingCriteria', 'EpisodeCount', ...
    'StopTrainingValue', nEpisodes, ...
    'Plots', 'none', ...
    'Verbose', true, ...
    'StopOnError', 'off', ...
    'UseParallel', true, ...
    'ParallelizationOptions', par);

pool = gcp('nocreate');
if isempty(pool)
    try
        pool = parpool('Processes');
    catch err
        warning('desktop_d12_train:pool', 'Pool-Start fehlgeschlagen (%s), neuer Versuch in 30 s', err.message);
        pause(30);
        pool = parpool('Processes');
    end
end
fprintf('%s: Reward-Modus %d, Optionen %s, J6 %.4g rad/s, Seed %d, %d Episoden, %d Worker\n', study, rewardMode, ...
    optsSet, j6Lim, seed, nEpisodes, pool.NumWorkers);

tStart = tic;
stats = train(agent, env, trainOpts);
wallTime = toc(tStart);
fprintf('%s: Training fertig nach %.1f min\n', study, wallTime / 60);

% --- Speichern ---
info = struct('wallTime_s', wallTime, 'numWorkers', pool.NumWorkers, 'matlab', version, ...
    'git', gitInfo(), 'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'computer', getenv('COMPUTERNAME'));
curve = table((1:numel(stats.EpisodeReward)).', stats.EpisodeReward(:), stats.AverageReward(:), ...
    stats.EpisodeQ0(:), stats.EpisodeSteps(:), 'VariableNames', ...
    {'episode', 'reward', 'avg_reward', 'q0', 'steps'});

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
name = sprintf('%s_ppo_40hz_r%d_seed%d', study, rewardMode, seed);
if nEpisodes ~= 1000
    name = sprintf('%s_ep%d', name, nEpisodes);
end
dataDir = sk_path('data', 'simulation', 'desktop');
if isempty(tag)
    agentDir = sk_path('SavedAgents', 'MotionProfile', study);
else
    agentDir = fullfile(dataDir, '_test');
    name = [name '_' tag];
end
if ~isfolder(agentDir), mkdir(agentDir); end
agentFile = fullfile(agentDir, [name '.mat']);
save(agentFile, 'agent', 'cfg', 'info', 'curve');
csvDir = dataDir;
if ~isempty(tag), csvDir = agentDir; end
csvFile = fullfile(csvDir, sprintf('%s_train_%s.csv', strrep(name, [study '_ppo'], study), stamp));
writetable(curve, csvFile);
fprintf('Gespeichert: %s\n            %s\n', agentFile, csvFile);

out = struct('agentFile', agentFile, 'csvFile', csvFile, 'cfg', cfg, 'info', info, 'curve', curve);
end

% =====================================================================
function [EE_ref, EE_vref] = makeReference(cfg)
% Halbkreis nach Zeit wie desktop_run_episode (ref_timing 'wall')
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
