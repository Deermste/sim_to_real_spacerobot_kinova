function out = ext_x2_4_train(variant, seed, varargin)
%EXT_X2_4_TRAIN  r4-Training mit Domain Randomization je Episode (Ausbau X2.4).
%   out = ext_x2_4_train('M', 0)          Basismasse und -traegheit randomisiert, Seed 0, 3000 Episoden
%   out = ext_x2_4_train('full', 0)       dazu Verzoegerung, Verstaerkung, Messrauschen, Startstellung
%   out = ext_x2_4_train('M', 0, 'nEpisodes', 16, 'tag', 'test', 'model', 'SK_x2test')   Kurztest
%
%   Aufbau sonst genau wie die r4-Agenten aus D16/D17 (desktop_d12_train(4, s, 3000, '', 'base_sync', 0.9774)):
%   Reward-Modus 4 mit Gewicht 2, Optionen des fruehen PPO, synchrones paralleles Training, Gradient Clipping,
%   J6 0,9774 rad/s, 40 Hz. Damit ist die Randomisierung der einzige Unterschied zu den 20 Bestandsagenten.
%   Randomisierung in der ResetFcn je Episode (alle Parameter sind mit Fast Restart aenderbar, ext_x2_4_tunable):
%     'M'     Basismasse 65 kg x f_m, f_m log-gleichverteilt in [0,25; 2] (Traegheit skaliert mit), dazu
%             Traegheitsfaktor log-gleichverteilt in [0,5; 2]
%     'full'  wie 'M', dazu Verzoegerung 0, 1 oder 2 Agentenschritte, Verstaerkung gleichverteilt in [0,9; 1,1],
%             Messrauschen s x realistische Werte (wie ext_x2_robust) mit s gleichverteilt in [0; 2],
%             Startstellung J2, J4, J6 gleichverteilt +-2 Grad
%   Nicht randomisiert (bleiben Testfaelle ausserhalb des Trainingsbereichs): Gliedmassen, Montage, Servo-Filter,
%   Anfangsdrehimpuls, fester Messfehler.
%   Die gezogenen Werte schreibt jeder Prozess in eine eigene Datei. Am Ende werden sie zu
%   data/simulation/extension/<Name>_dr.csv zusammengefasst (Pruefung, dass jede Episode anders zieht).
%   Ergebnis: SavedAgents/MotionProfile/X2_4/<Name>.mat (agent, cfg, info, curve), Lernkurve <Name>_train.csv.
%   <Name> = X2_4_ppo_40hz_r4_dr<variant>_seed<Seed>_ep<Episoden>

p = inputParser;
p.addParameter('nEpisodes', 3000);
p.addParameter('model', 'SK_desktop');
p.addParameter('tag', '');
p.parse(varargin{:});
o = p.Results;
assert(ismember(variant, {'M', 'full'}), 'ext_x2_4_train:variant', 'variant ist M oder full');
mdl = o.model;
j6Lim = 0.9774;

setup_project;
desktop_build_model(false, mdl);
if ~bdIsLoaded(mdl), load_system(mdl); end
set_param(mdl, 'SimMechanicsOpenEditorOnUpdate', 'off');

dr = struct('variant', variant, 'mass', [0.25 2], 'inertia', [0.5 2], 'delay', [0 0], 'gain', [1 1], ...
            'noise', [0 0], 'pose_deg', 0);
if strcmp(variant, 'full')
    dr.delay = [0 2]; dr.gain = [0.9 1.1]; dr.noise = [0 2]; dr.pose_deg = 2;
end
cfg = struct('rewardMode', 4, 'optsSet', 'base_sync', 'j6Lim', j6Lim, 'baseW', 2, 'dr', dr, 'model', mdl, ...
    'rateHz', 40, 'seed', seed, 'nEpisodes', o.nEpisodes, 'Ts_agent', 0.025, 'Ts', 0.005, 'T', 8.5, ...
    'base_mass', 65, 'hidden', 128, 'parMode', 'sync', 'gradThreshold', 1);
cfg.opts = struct('ExperienceHorizon', 1024, 'MiniBatchSize', 128, 'NumEpoch', 10, 'ClipFactor', 0.2, ...
    'DiscountFactor', 0.99, 'GAEFactor', 0.95, 'EntropyLossWeight', 1e-3, 'ActorLR', 1e-3, 'CriticLR', 5e-4);

% --- Workspace wie in desktop_d12_train ---
ec = desktop_config('Ts', cfg.Ts, 'Ts_agent', cfg.Ts_agent, 'T', cfg.T, 'base_mass', cfg.base_mass);
[EE_ref, EE_vref] = makeReference(ec);
vars = struct('EE_ref', EE_ref, 'EE_vref', EE_vref, 'reward_init', 0, 'isdone_init', 0, ...
    'p_Ts', ec.Ts, 'p_Ts_agent', ec.Ts_agent, 'p_T', ec.T, 'p_base_mass', ec.base_mass, ...
    'p_delay_steps', 0, 'p_damp_scale', 1, 'p_slew', ec.slew, 'p_cmd_scale', 1, 'p_obs_mode', 0, ...
    'p_obs_noise', zeros(29, 1), 'p_reward_mode', 4, 'p_j6_lim', j6Lim, 'p_base_w', 2, ...
    'p_q0', zeros(7, 1), 'p_lambda', 0, 'p_theta', 0.03, 'p_cost_type', 1, 'p_inertia_scale', 1);
fn = fieldnames(vars);
for k = 1:numel(fn)
    assignin('base', fn{k}, vars.(fn{k}));
end

% --- Agent wie desktop_d12_train ('base_sync') ---
ref = load(sk_path('SavedAgents', 'MotionProfile', 'Circle', 'PPO', 'Optimized.mat'), 'agent');
obsInfo = getObservationInfo(ref.agent);       % Grenzen unveraendert (E8, A72)
actInfo = getActionInfo(ref.agent);
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

name = sprintf('X2_4_ppo_40hz_r4_dr%s_seed%d_ep%d', variant, seed, o.nEpisodes);
if ~isempty(o.tag), name = [name '_' o.tag]; end
if isempty(o.tag)
    agentDir = sk_path('SavedAgents', 'MotionProfile', 'X2_4');
    csvDir = sk_path('data', 'simulation', 'extension');
else
    agentDir = sk_path('data', 'simulation', 'desktop', '_test');
    csvDir = agentDir;
end
if ~isfolder(agentDir), mkdir(agentDir); end
logDir = fullfile(tempdir, ['dr_' name]);
if isfolder(logDir), rmdir(logDir, 's'); end
mkdir(logDir);

env = rlSimulinkEnv(mdl, [mdl '/RL_Agent'], obsInfo, actInfo);
env.ResetFcn = @(in) drReset(in, dr, j6Lim, seed, logDir);
trainOpts = rlTrainingOptions('MaxEpisodes', o.nEpisodes, 'MaxStepsPerEpisode', floor(cfg.T / cfg.Ts_agent), ...
    'ScoreAveragingWindowLength', 25, 'StopTrainingCriteria', 'EpisodeCount', ...
    'StopTrainingValue', o.nEpisodes, 'Plots', 'none', 'Verbose', true, 'StopOnError', 'off', ...
    'UseParallel', true, 'ParallelizationOptions', rl.option.ParallelTraining('Mode', cfg.parMode));
pool = gcp('nocreate');
if isempty(pool), pool = parpool('Processes'); end
fprintf('X2.4: DR %s, Seed %d, %d Episoden, %d Worker\n', variant, seed, o.nEpisodes, pool.NumWorkers);

tStart = tic;
stats = train(agent, env, trainOpts);
wallTime = toc(tStart);
fprintf('X2.4: Training fertig nach %.1f min\n', wallTime / 60);

% --- gezogene Werte zusammenfassen ---
D = table();
fl = dir(fullfile(logDir, '*.csv'));
for k = 1:numel(fl)
    D = [D; readtable(fullfile(fl(k).folder, fl(k).name))]; %#ok<AGROW>
end
rmdir(logDir, 's');
if ~isempty(D)
    writetable(D, fullfile(csvDir, [name '_dr.csv']));
    fprintf('X2.4: %d gezogene Episoden aus %d Prozessen, Basismasse %.1f-%.1f kg, Verzoegerung %s\n', ...
            height(D), numel(fl), min(D.base_mass), max(D.base_mass), mat2str(unique(D.delay).'));
end

info = struct('wallTime_s', wallTime, 'numWorkers', pool.NumWorkers, 'matlab', version, 'git', gitInfo(), ...
    'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), 'computer', getenv('COMPUTERNAME'), ...
    'nDrawn', height(D));
curve = table((1:numel(stats.EpisodeReward)).', stats.EpisodeReward(:), stats.AverageReward(:), ...
    stats.EpisodeSteps(:), 'VariableNames', {'episode', 'reward', 'avg_reward', 'steps'});
agentFile = fullfile(agentDir, [name '.mat']);
save(agentFile, 'agent', 'cfg', 'info', 'curve');
writetable(curve, fullfile(csvDir, [name '_train.csv']));
fprintf('Gespeichert: %s\n', agentFile);
out = struct('agentFile', agentFile, 'cfg', cfg, 'info', info, 'curve', curve, 'draws', D, 'stats', stats);
end

% =====================================================================
function in = drReset(in, dr, j6Lim, seed, logDir)
% Zieht die Parameter einer Episode. Eigener Zufallsstrom je Prozess (Seed und Task-ID), Protokoll je Prozess.
persistent rs pid cnt key
if isempty(rs) || ~strcmp(key, logDir)          % neu je Training (logDir enthaelt Variante und Seed)
    key = logDir;
    t = getCurrentTask();
    pid = 0;
    if ~isempty(t), pid = t.ID; end
    rs = RandStream('mt19937ar', 'Seed', 1000 * seed + pid);
    cnt = 0;
end
cnt = cnt + 1;
lu = @(r) exp(log(r(1)) + rand(rs) * (log(r(2)) - log(r(1))));
fm = lu(dr.mass);
fi = lu(dr.inertia);
delay = dr.delay(1) + floor(rand(rs) * (dr.delay(2) - dr.delay(1) + 1));
gain = dr.gain(1) + rand(rs) * (dr.gain(2) - dr.gain(1));
ns = dr.noise(1) + rand(rs) * (dr.noise(2) - dr.noise(1));
q0 = zeros(7, 1);
q0([2 4 6]) = deg2rad(dr.pose_deg) * (2 * rand(rs, 3, 1) - 1);
in = setVariable(in, 'reward_init', 0);
in = setVariable(in, 'isdone_init', 0);
in = setVariable(in, 'p_reward_mode', 4);
in = setVariable(in, 'p_j6_lim', j6Lim);
in = setVariable(in, 'p_base_w', 2);
in = setVariable(in, 'p_base_mass', 65 * fm);
in = setVariable(in, 'p_inertia_scale', fi);
in = setVariable(in, 'p_delay_steps', delay);
in = setVariable(in, 'p_cmd_scale', gain);
in = setVariable(in, 'p_obs_noise', ns * noiseSigma());
in = setVariable(in, 'p_q0', q0);
f = fullfile(logDir, sprintf('task%d.csv', pid));
isNew = ~isfile(f);
fid = fopen(f, 'a');
if isNew, fprintf(fid, 'pid,n,base_mass,inertia_scale,delay,gain,noise_scale,q2,q4,q6\n'); end
fprintf(fid, '%d,%d,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%.6f,%.6f\n', pid, cnt, 65 * fm, fi, delay, gain, ns, q0([2 4 6]));
fclose(fid);
end

function s = noiseSigma()
% realistische Messfehler je Kanal wie ext_x2_robust [ep; ev; v_base; w_base; q; dq; e_ori]
s = [1e-3 * ones(3, 1); 5e-3 * ones(3, 1); 1e-3 * ones(3, 1); 1e-3 * ones(3, 1); 1e-3 * ones(7, 1); ...
     5e-3 * ones(7, 1); 1e-3 * ones(3, 1)];
end

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
