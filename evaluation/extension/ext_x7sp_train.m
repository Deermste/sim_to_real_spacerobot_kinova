function out = ext_x7sp_train(variant, seed, varargin)
%EXT_X7SP_TRAIN  Training der Residual-Policy am Set-Point (X7-SP, 15.11.2026).
%   out = ext_x7sp_train('res', 0)        nominal trainiert
%   out = ext_x7sp_train('resdr', 0)      mit DR-voll
%   out = ext_x7sp_train('res', 0, 'nEpisodes', 32, 'ckptEvery', 16, 'tag', 'test')
%
%   Umgebung ext_x7sp_env (Regler gewichtet mit beta, Korrektur der Sollwerte, Trainingssatz X6_train). PPO wie
%   ext_x7_train (128 Neuronen, Horizont 1024, Minibatch 128, 10 Epochen, Lernraten 3e-4 / 5e-4), letzte Schicht
%   des Mittelwerts startet mit null. Nach jedem Block ein Zwischenstand und 16 feste Trainingspaare nominal in
%   ext_kinsim (Erfolg, mittlere Einschwingzeit, mittlere Basisdrehung).
%   Optionen: nEpisodes 3000, beta 1, eps_v 0,02, eps_w 0,02, w_res 0,1, actorLR 3e-4, criticLR 5e-4,
%   ckptEvery 250, tag '', name '', reward 'goal' oder 'ref', gate false (ext_x7sp_env, X7.4).
%   Ergebnis: SavedAgents/MotionProfile/X7/<Name>.mat, <Name>_ckpt/, data/simulation/extension/<Name>_*.csv.

p = inputParser;
p.addParameter('nEpisodes', 3000);
p.addParameter('beta', 1);
p.addParameter('eps_v', 0.02);
p.addParameter('eps_w', 0.02);
p.addParameter('w_res', 0.1);
p.addParameter('actorLR', 3e-4);
p.addParameter('criticLR', 5e-4);
p.addParameter('ckptEvery', 250);
p.addParameter('tag', '');
p.addParameter('name', '');
p.addParameter('reward', 'goal');
p.addParameter('gate', false);
p.parse(varargin{:});
o = p.Results;
assert(ismember(variant, {'res', 'resdr'}), 'ext_x7sp_train:variant', 'variant ist res oder resdr');
setup_project;
dr = 'none';
if strcmp(variant, 'resdr'), dr = 'full'; end
dd = sk_path('data', 'simulation', 'extension');
dT = dir(fullfile(dd, 'X6_train_*.mat'));
Lt = load(fullfile(dT(end).folder, dT(end).name), 'P');
pool = Lt.P;
rsC = RandStream('mt19937ar', 'Seed', 4242);
chk = pool(randperm(rsC, numel(pool), 16));
cfg = struct('variant', variant, 'seed', seed, 'dr', dr, 'nEpisodes', o.nEpisodes, 'beta', o.beta, ...
    'eps_v', o.eps_v, 'eps_w', o.eps_w, 'w_res', o.w_res, 'hidden', 128, 'ckptEvery', o.ckptEvery, ...
    'trainFile', dT(end).name, 'reward', o.reward, 'gate', o.gate);
cfg.opts = struct('ExperienceHorizon', 1024, 'MiniBatchSize', 128, 'NumEpoch', 10, 'ClipFactor', 0.2, ...
    'DiscountFactor', 0.99, 'GAEFactor', 0.95, 'EntropyLossWeight', 1e-3, 'ActorLR', o.actorLR, ...
    'CriticLR', o.criticLR);
name = sprintf('X7sp_%s_b%g_seed%d_ep%d', variant, o.beta, seed, o.nEpisodes);
if ~isempty(o.name), name = o.name; end
if isempty(o.tag)
    agentDir = sk_path('SavedAgents', 'MotionProfile', 'X7');
    csvDir = dd;
else
    name = [name '_' o.tag];
    agentDir = sk_path('data', 'simulation', 'desktop', '_test');
    csvDir = agentDir;
end
ckDir = fullfile(agentDir, [name '_ckpt']);
if ~isfolder(ckDir), mkdir(ckDir); end
eArgs = {'beta', o.beta, 'eps_v', o.eps_v, 'eps_w', o.eps_w, 'w_res', o.w_res, 'dr', dr, 'reward', o.reward, ...
         'gate', o.gate};
[env0, info0] = ext_x7sp_env(pool, eArgs{:}, 'seed', seed);
rng(seed, 'twister');
agent = rlPPOAgent(info0.obsInfo, info0.actInfo, rlAgentInitializationOptions('NumHiddenUnit', cfg.hidden));
ao = agent.AgentOptions;
ao.SampleTime = 0.05;
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
actor = getActor(agent);
net = getModel(actor);
L = net.Learnables;
im = strcmp(L.Layer, 'fc_mean');
assert(nnz(im) == 2, 'ext_x7sp_train:actor', 'Schicht fc_mean nicht gefunden');
L.Value(im) = cellfun(@(v) 0 * v, L.Value(im), 'UniformOutput', false);
net.Learnables = L;
actor = setModel(actor, net);
agent = setActor(agent, actor);
clear env0

pp = gcp('nocreate');
if isempty(pp), pp = parpool('Processes'); end
fprintf('X7-SP %s, Seed %d: beta %g, eps_v %.3f m/s, eps_w %.3f rad/s, w_res %.2f, DR %s, %d Episoden, %d Worker\n', ...
        variant, seed, o.beta, o.eps_v, o.eps_w, o.w_res, dr, o.nEpisodes, pp.NumWorkers);
curve = table(); ck = {}; nEp = 0; b = 0; tStart = tic;
while nEp < o.nEpisodes
    b = b + 1;
    nB = min(o.ckptEvery, o.nEpisodes - nEp);
    env = ext_x7sp_env(pool, eArgs{:}, 'seed', 1000 * seed + b);
    trainOpts = rlTrainingOptions('MaxEpisodes', nB, 'MaxStepsPerEpisode', 301, ...
        'ScoreAveragingWindowLength', 50, 'StopTrainingCriteria', 'EpisodeCount', 'StopTrainingValue', nB, ...
        'Plots', 'none', 'Verbose', false, 'StopOnError', 'off', 'UseParallel', true, ...
        'ParallelizationOptions', rl.option.ParallelTraining('Mode', 'sync'));
    stats = train(agent, env, trainOpts);
    n = numel(stats.EpisodeReward);
    curve = [curve; table(nEp + (1:n).', stats.EpisodeReward(:), stats.EpisodeSteps(:), ...
        'VariableNames', {'episode', 'reward', 'steps'})]; %#ok<AGROW>
    nEp = nEp + n;
    S = struct('agent', agent, 'cfg', cfg); S.cfg.episodes = nEp; %#ok<NASGU>
    f = fullfile(ckDir, sprintf('ep%05d.mat', nEp));
    save(f, '-struct', 'S');
    m = checkEval(f, chk, o);
    ck{end + 1} = struct('episodes', nEp, 'succ', m.succ, 't_settle', m.tset, 'ori_max', m.ori, ...
        'reward_mean', mean(stats.EpisodeReward), 'file', string(f)); %#ok<AGROW>
    fprintf('  Block %2d: %4d Episoden, Return %.1f, Pruefpaare Erfolg %d/16, t_settle %.2f s, ori %.1f mrad (%.1f min)\n', ...
            b, nEp, mean(stats.EpisodeReward), round(16 * m.succ), m.tset, 1000 * m.ori, toc(tStart) / 60);
end
ckpt = struct2table([ck{:}]);
info = struct('wallTime_s', toc(tStart), 'numWorkers', pp.NumWorkers, 'matlab', version, ...
    'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
agentFile = fullfile(agentDir, [name '.mat']);
save(agentFile, 'agent', 'cfg', 'curve', 'ckpt', 'info');
writetable(curve, fullfile(csvDir, [name '_train.csv']));
writetable(ckpt, fullfile(csvDir, [name '_ckpt.csv']));
fprintf('X7-SP %s Seed %d fertig nach %.1f min: %s\n', variant, seed, info.wallTime_s / 60, agentFile);
out = struct('agentFile', agentFile, 'ckpt', ckpt, 'curve', curve, 'cfg', cfg);
end

% =====================================================================
function m = checkEval(f, chk, o)
pol = ext_policy(f);
R = cell(numel(chk), 1);
parfor i = 1:numel(chk)
    pr = chk(i);
    Tm = min(max(1.5, 9.4 * pr.d0), 10);
    c = ext_x7sp_ctrl(pol, pr.pT, Tm, 'beta', o.beta, 'eps_v', o.eps_v, 'eps_w', o.eps_w, 'gate', o.gate);
    R{i} = ext_x7sp_run(c, pr);
end
T = struct2table([R{:}]);
ts = T.t_settle; ts(isnan(ts)) = 15;
m = struct('succ', mean(T.success), 'tset', mean(ts), 'ori', mean(T.ori_max));
end
