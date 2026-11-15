function out = ext_x7_train(variant, seed, varargin)
%EXT_X7_TRAIN  Training der Residual-Policy fuer X7 (15.11.2026).
%   out = ext_x7_train('res', 0)        nominal trainiert (Variante Res)
%   out = ext_x7_train('resdr', 0)      mit DR-voll (Variante Res-DR)
%   out = ext_x7_train('res', 0, 'nEpisodes', 50, 'tag', 'test')   Kurztest
%
%   Umgebung ext_x7_env (Rbeta 21,5 mit Nominalmodell, Korrektur der Sollwerte im Aufgabenraum, kinematischer
%   Simulator, bitgleich zu ext_kinsim). PPO mit dem Aufbau der r4-Agenten (128 Neuronen je Schicht, Horizont
%   1024, Minibatch 128, 10 Epochen, Clip 0,2, gamma 0,99, GAE 0,95, Entropie 1e-3, Gradient Clipping 1), Lernrate des Actors 3e-4
%   (aus X5.2b), des Critics 5e-4. Synchron parallel auf allen Workern des Pools.
%   Die letzte Schicht des Actor-Mittelwerts startet mit Gewichten und Bias null: Am Anfang ist die Korrektur im
%   Mittel null, die Policy startet beim Regler (ueblich bei Residual RL).
%   Training in Bloecken zu ckptEvery Episoden, nach jedem Block ein Zwischenstand und eine nominale Episode in
%   ext_kinsim (RMS, ori_max, mittlere |Delta|).
%   Optionen: nEpisodes 3000, eps_v 0,02, eps_w 0,01, w_res 0,1, actorLR 3e-4, criticLR 5e-4, ckptEvery 250,
%   tag '', name '' (eigener Dateiname), reward 'r4' oder 'J' (ext_x7_env).
%   Ergebnis: SavedAgents/MotionProfile/X7/<Name>.mat (agent, cfg, curve, ckpt), Zwischenstaende in
%   <Name>_ckpt/epNNNNN.mat, data/simulation/extension/<Name>_{train,ckpt}.csv.
%   <Name> = X7_<variant>_seed<seed>_ep<nEpisodes>

p = inputParser;
p.addParameter('nEpisodes', 3000);
p.addParameter('eps_v', 0.02);
p.addParameter('eps_w', 0.01);
p.addParameter('w_res', 0.1);
p.addParameter('actorLR', 3e-4);
p.addParameter('criticLR', 5e-4);
p.addParameter('ckptEvery', 250);
p.addParameter('tag', '');
p.addParameter('name', '');        % eigener Name (ext_x7_sweep)
p.addParameter('reward', 'r4');    % 'r4' oder 'J' (ext_x7_env)
p.parse(varargin{:});
o = p.Results;
assert(ismember(variant, {'res', 'resdr'}), 'ext_x7_train:variant', 'variant ist res oder resdr');
setup_project;
dr = 'none';
if strcmp(variant, 'resdr'), dr = 'full'; end
cfg = struct('variant', variant, 'seed', seed, 'dr', dr, 'nEpisodes', o.nEpisodes, 'eps_v', o.eps_v, ...
    'eps_w', o.eps_w, 'w_res', o.w_res, 'reward', o.reward, 'hidden', 128, 'ckptEvery', o.ckptEvery, 'ctrl', 'Rb21 (beta 21.544, j6_side -1, Kp 5)');
cfg.opts = struct('ExperienceHorizon', 1024, 'MiniBatchSize', 128, 'NumEpoch', 10, 'ClipFactor', 0.2, ...
    'DiscountFactor', 0.99, 'GAEFactor', 0.95, 'EntropyLossWeight', 1e-3, 'ActorLR', o.actorLR, ...
    'CriticLR', o.criticLR);
name = sprintf('X7_%s_seed%d_ep%d', variant, seed, o.nEpisodes);
if ~isempty(o.name), name = o.name; end
if isempty(o.tag)
    agentDir = sk_path('SavedAgents', 'MotionProfile', 'X7');
    csvDir = sk_path('data', 'simulation', 'extension');
else
    name = [name '_' o.tag];
    agentDir = sk_path('data', 'simulation', 'desktop', '_test');
    csvDir = agentDir;
end
ckDir = fullfile(agentDir, [name '_ckpt']);
if ~isfolder(ckDir), mkdir(ckDir); end

[env0, info0] = ext_x7_env('eps_v', o.eps_v, 'eps_w', o.eps_w, 'w_res', o.w_res, 'dr', dr, 'seed', seed, ...
                           'reward', o.reward);
rng(seed, 'twister');
agent = rlPPOAgent(info0.obsInfo, info0.actInfo, rlAgentInitializationOptions('NumHiddenUnit', cfg.hidden));
ao = agent.AgentOptions;
ao.SampleTime = 0.025;
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
% Mittelwert der Korrektur am Anfang null
actor = getActor(agent);
net = getModel(actor);
L = net.Learnables;
im = strcmp(L.Layer, 'fc_mean');
assert(nnz(im) == 2, 'ext_x7_train:actor', 'Schicht fc_mean nicht gefunden: %s', strjoin(unique(L.Layer), ', '));
L.Value(im) = cellfun(@(v) 0 * v, L.Value(im), 'UniformOutput', false);
net.Learnables = L;
actor = setModel(actor, net);
agent = setActor(agent, actor);
clear env0

pool = gcp('nocreate');
if isempty(pool), pool = parpool('Processes'); end
nMax = 341;
fprintf('X7 %s, Seed %d: eps_v %.3f m/s, eps_w %.3f rad/s, w_res %.2f, DR %s, %d Episoden, %d Worker\n', ...
        variant, seed, o.eps_v, o.eps_w, o.w_res, dr, o.nEpisodes, pool.NumWorkers);
curve = table(); ck = {}; nEp = 0; b = 0; tStart = tic;
while nEp < o.nEpisodes
    b = b + 1;
    nB = min(o.ckptEvery, o.nEpisodes - nEp);
    env = ext_x7_env('eps_v', o.eps_v, 'eps_w', o.eps_w, 'w_res', o.w_res, 'dr', dr, 'seed', 1000 * seed + b, ...
                     'reward', o.reward);
    trainOpts = rlTrainingOptions('MaxEpisodes', nB, 'MaxStepsPerEpisode', nMax, ...
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
    [m, dmean] = nominalEval(f, o.eps_v, o.eps_w);
    ck{end + 1} = struct('episodes', nEp, 'nom_rms_ee', m.rms_ee, 'nom_ep_q4', m.ep_q4, ...
        'nom_ori_max', m.ori_max, 'nom_stop', double(m.early_stop), 'delta_mean', dmean, ...
        'reward_mean', mean(stats.EpisodeReward), 'file', string(f)); %#ok<AGROW>
    fprintf('  Block %2d: %4d Episoden, Return %.1f, nominal RMS %.2f mm, ori_max %.2f mrad, |Delta| %.3f (%.1f min)\n', ...
            b, nEp, mean(stats.EpisodeReward), 1000 * m.rms_ee, 1000 * m.ori_max, dmean, toc(tStart) / 60);
end
ckpt = struct2table([ck{:}]);
info = struct('wallTime_s', toc(tStart), 'numWorkers', pool.NumWorkers, 'matlab', version, ...
    'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), 'computer', getenv('COMPUTERNAME'));
agentFile = fullfile(agentDir, [name '.mat']);
save(agentFile, 'agent', 'cfg', 'curve', 'ckpt', 'info');
writetable(curve, fullfile(csvDir, [name '_train.csv']));
writetable(ckpt, fullfile(csvDir, [name '_ckpt.csv']));
fprintf('X7 %s Seed %d fertig nach %.1f min: %s\n', variant, seed, info.wallTime_s / 60, agentFile);
out = struct('agentFile', agentFile, 'ckpt', ckpt, 'curve', curve, 'cfg', cfg);
end

% =====================================================================
function [m, dmean] = nominalEval(f, eps_v, eps_w)
pol = ext_policy(f);
D = [];
    function d = polLog(ob)
        d = min(max(pol(ob), -1), 1);
        D(end + 1) = norm(d); %#ok<AGROW>
    end
res = ext_kinsim([], 'ctrl', ext_x7_ctrl(@polLog, 'eps_v', eps_v, 'eps_w', eps_w), 'j6_lim', 0.9774, ...
               'reward_mode', 4, 'keepTs', false);
m = res.metrics;
dmean = mean(D);
end
