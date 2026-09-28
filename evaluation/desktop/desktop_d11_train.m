function out = desktop_d11_train(algo, seed, nEpisodes, tag)
%DESKTOP_D11_TRAIN  Trainiert einen Agenten fuer den neuen Algorithmenvergleich (Desktop-Plan D11, Befund A64).
%   out = desktop_d11_train('PPO', 0)              1000 Episoden, Seed 0
%   out = desktop_d11_train('SAC', 0, 20, 'test')  Probelauf, speichert nur unter data/.../_test
%
%   algo: 'PPO', 'TRPO', 'PG' (on-policy), 'DDPG', 'TD3', 'SAC' (off-policy).
%   Aufbau fuer alle Verfahren gleich: SK_desktop mit Reward-Modus 0 (Gl. 3 mit den Boni aus Sec. III-C),
%   40 Hz, Solver 5 ms, 65 kg, Halbkreis 8,5 s, J6-Grenze 0,1 rad/s wie im Training, Beobachtung und Aktion wie
%   Optimized.mat. Netz 2 x 128 ReLU fuer Actor und Critic (rlAgentInitializationOptions). Hyperparameter sind die
%   Standardwerte der Toolbox (R2026a), einheitlich Gradient Clipping mit Schwelle 1 fuer alle Optimierer.
%   Keine verfahrensspezifische Abstimmung und keine Lernraten-Reihe (Entscheidung 27.09.2026).
%   Training parallel auf allen Workern: on-policy synchron wie D14 (asynchron wurde in D13 instabil), off-policy
%   asynchron (die Worker sammeln nur Erfahrung, gelernt wird zentral).
%
%   Ergebnis:
%     SavedAgents/MotionProfile/D11/D11_<algo>_seed<seed>.mat   agent, cfg, info, curve
%     data/simulation/desktop/D11_<algo>_seed<seed>_train_<Zeit>.csv   Lernkurve je Episode

if nargin < 2, seed = 0; end
if nargin < 3 || isempty(nEpisodes), nEpisodes = 1000; end
if nargin < 4, tag = ''; end
algo = upper(char(algo));
onPolicy = {'PPO', 'TRPO', 'PG'};
offPolicy = {'DDPG', 'TD3', 'SAC'};
assert(ismember(algo, [onPolicy, offPolicy]), 'desktop_d11_train:algo', 'Unbekanntes Verfahren: %s', algo);

setup_project;
desktop_build_model();
mdl = 'SK_desktop';
if ~bdIsLoaded(mdl), load_system(mdl); end
set_param(mdl, 'SimMechanicsOpenEditorOnUpdate', 'off');

cfg = struct();
cfg.algo = algo;
cfg.seed = seed;
cfg.nEpisodes = nEpisodes;
cfg.Ts_agent = 0.025;
cfg.Ts = 0.005;
cfg.T = 8.5;
cfg.base_mass = 65;
cfg.hidden = 128;
cfg.rewardMode = 0;
cfg.j6Lim = 0.1;
cfg.gradThreshold = 1;
cfg.parMode = 'sync';
if ismember(algo, offPolicy), cfg.parMode = 'async'; end

% --- Workspace wie in desktop_run_episode (Standardwerte, keine Stoerung) ---
ec = desktop_config('Ts', cfg.Ts, 'Ts_agent', cfg.Ts_agent, 'T', cfg.T, 'base_mass', cfg.base_mass);
[EE_ref, EE_vref] = makeReference(ec);
vars = struct('EE_ref', EE_ref, 'EE_vref', EE_vref, 'reward_init', 0, 'isdone_init', 0, ...
    'p_Ts', ec.Ts, 'p_Ts_agent', ec.Ts_agent, 'p_T', ec.T, 'p_base_mass', ec.base_mass, ...
    'p_delay_steps', 0, 'p_damp_scale', 1, 'p_slew', ec.slew, 'p_cmd_scale', 1, 'p_obs_mode', 0, ...
    'p_obs_noise', zeros(29, 1), 'p_reward_mode', cfg.rewardMode, 'p_j6_lim', cfg.j6Lim, 'p_base_w', 2);
fn = fieldnames(vars);
for k = 1:numel(fn)
    assignin('base', fn{k}, vars.(fn{k}));
end

% --- Spezifikationen wie Optimized.mat (gleiche Grenzen und Namen) ---
ref = load(sk_path('SavedAgents', 'MotionProfile', 'Circle', 'PPO', 'Optimized.mat'), 'agent');
obsInfo = getObservationInfo(ref.agent);
actInfo = getActionInfo(ref.agent);

% --- Agent mit Standardwerten ---
rng(seed, 'twister');
initOpts = rlAgentInitializationOptions('NumHiddenUnit', cfg.hidden);
switch algo
    case 'PPO',  agent = rlPPOAgent(obsInfo, actInfo, initOpts);
    case 'TRPO', agent = rlTRPOAgent(obsInfo, actInfo, initOpts);
    case 'PG',   agent = rlPGAgent(obsInfo, actInfo, initOpts);
    case 'DDPG', agent = rlDDPGAgent(obsInfo, actInfo, initOpts);
    case 'TD3',  agent = rlTD3Agent(obsInfo, actInfo, initOpts);
    case 'SAC',  agent = rlSACAgent(obsInfo, actInfo, initOpts);
end
o = agent.AgentOptions;
o.SampleTime = cfg.Ts_agent;
o = setGradientThreshold(o, cfg.gradThreshold);
agent.AgentOptions = o;
cfg.agentOptions = o;                       % alle Standardwerte fuer die Dokumentation
assignin('base', 'agent', agent);

% --- Umgebung ---
env = rlSimulinkEnv(mdl, [mdl '/RL_Agent'], obsInfo, actInfo);
env.ResetFcn = @(in) setVariable(setVariable(setVariable(setVariable(setVariable(in, 'reward_init', 0), ...
    'isdone_init', 0), 'p_reward_mode', cfg.rewardMode), 'p_j6_lim', cfg.j6Lim), 'p_base_w', 2);

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
        warning('desktop_d11_train:pool', 'Pool-Start fehlgeschlagen (%s), neuer Versuch in 30 s', err.message);
        pause(30);
        pool = parpool('Processes');
    end
end
fprintf('D11: %s, Seed %d, %d Episoden, %s, %d Worker\n', algo, seed, nEpisodes, cfg.parMode, pool.NumWorkers);

tStart = tic;
stats = train(agent, env, trainOpts);
wallTime = toc(tStart);
fprintf('D11: %s Seed %d fertig nach %.1f min\n', algo, seed, wallTime / 60);

% --- Speichern ---
info = struct('wallTime_s', wallTime, 'numWorkers', pool.NumWorkers, 'matlab', version, ...
    'git', gitInfo(), 'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'computer', getenv('COMPUTERNAME'));
q0 = nan(numel(stats.EpisodeReward), 1);
if isprop(stats, 'EpisodeQ0') || isfield(stats, 'EpisodeQ0'), q0 = stats.EpisodeQ0(:); end
curve = table((1:numel(stats.EpisodeReward)).', stats.EpisodeReward(:), stats.AverageReward(:), q0, ...
    stats.EpisodeSteps(:), 'VariableNames', {'episode', 'reward', 'avg_reward', 'q0', 'steps'});

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
name = sprintf('D11_%s_seed%d', algo, seed);
if nEpisodes ~= 1000
    name = sprintf('%s_ep%d', name, nEpisodes);
end
dataDir = sk_path('data', 'simulation', 'desktop');
if isempty(tag)
    agentDir = sk_path('SavedAgents', 'MotionProfile', 'D11');
else
    agentDir = fullfile(dataDir, '_test');
    name = [name '_' tag];
end
if ~isfolder(agentDir), mkdir(agentDir); end
agentFile = fullfile(agentDir, [name '.mat']);
save(agentFile, 'agent', 'cfg', 'info', 'curve');
csvDir = dataDir;
if ~isempty(tag), csvDir = agentDir; end
csvFile = fullfile(csvDir, sprintf('%s_train_%s.csv', name, stamp));
writetable(curve, csvFile);
fprintf('Gespeichert: %s\n            %s\n', agentFile, csvFile);

out = struct('agentFile', agentFile, 'csvFile', csvFile, 'cfg', cfg, 'info', info, 'curve', curve);
end

% =====================================================================
function o = setGradientThreshold(o, thr)
% Schwelle fuer die Optimierer von Actor und Critic setzen. Die Critic-Optionen koennen bei TD3 und SAC ein
% Array sein. Der Entropie-Optimierer von SAC bleibt unveraendert.
if isprop(o, 'ActorOptimizerOptions')
    for k = 1:numel(o.ActorOptimizerOptions)
        o.ActorOptimizerOptions(k).GradientThreshold = thr;
    end
end
if isprop(o, 'CriticOptimizerOptions')
    for k = 1:numel(o.CriticOptimizerOptions)
        o.CriticOptimizerOptions(k).GradientThreshold = thr;
    end
end
end

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
