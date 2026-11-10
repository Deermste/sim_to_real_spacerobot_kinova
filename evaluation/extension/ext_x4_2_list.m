function [list, inv] = ext_x4_2_list()
%EXT_X4_2_LIST  Agentenliste fuer X4.2: alle Bestandsagenten, die im Paper vorkommen koennen.
%   [list, inv] = ext_x4_2_list()
%
%   list  fuer ext_eval_batch (file, label, group, opts)
%   inv   Bestandsaufnahme je Datei: Variablen, cfg-Felder, Takt, Trainingsbedingungen wie ext_eval_agent
%
%   Gruppen: early (fruehes PPO, basisori), optimized, ppo10 (Circle/PPO/ppo_10hz), cdr (CDR1-4, CDR2-4),
%   D10 (Ratenpaar 10/40 Hz), D11 (Algorithmen), D12, D13, D14 (r0, r1, r2), D16 (r0, r2, r4 kurz, r4 lang),
%   D20 (Endagenten der Checkpoint-Studie). D17 und D16 r4 lang mit 3000 Episoden wertet auch X4.1 aus
%   (ext_x4_1_eval); D16 r4 lang ist hier trotzdem dabei, damit X4.2 fuer sich steht. D17 nicht.

setup_project;
ma = sk_path('SavedAgents', 'MotionProfile');
spec = {
    'early',     fullfile(ma, 'Circle', 'PPO', 'SpaceKinova_PPO_agent_motionprofile.mat')
    'early',     fullfile(ma, 'Circle', 'PPO', 'SpaceKinova_PPO_agent_motionprofile_basisori.mat')
    'optimized', fullfile(ma, 'Circle', 'PPO', 'Optimized.mat')
    'ppo10',     fullfile(ma, 'Circle', 'PPO', 'ppo_10hz.mat')
    'cdr',       fullfile(ma, 'CDR', 'PPO', 'CDR1-4.mat')
    'cdr',       fullfile(ma, 'CDR', 'PPO', 'CDR2-4.mat')
    };
groups = {'D10', 'D10_*.mat'; 'D11', 'D11_*.mat'; 'D12', 'D12_*.mat'; 'D13', 'D13_*.mat'; 'D14', 'D14_*.mat'; ...
          'D16', 'D16_*.mat'; 'D20', 'D20_*_ep3000.mat'};
for g = 1:size(groups, 1)
    d = dir(fullfile(ma, groups{g, 1}, groups{g, 2}));
    for k = 1:numel(d)
        spec(end + 1, :) = {groups{g, 1}, fullfile(d(k).folder, d(k).name)}; %#ok<AGROW>
    end
end

n = size(spec, 1);
list = struct('file', {}, 'label', {}, 'group', {}, 'opts', {});
rows = cell(n, 1);
for i = 1:n
    f = spec{i, 2};
    [~, lab] = fileparts(f);
    vars = {whos('-file', f).name};
    r = struct('group', string(spec{i, 1}), 'label', string(lab), 'vars', string(strjoin(vars, ' ')), ...
               'cfg_fields', "", 'reward_mode', 0, 'j6_lim', 0.1, 'base_w', 2, 'Ts_agent', NaN, ...
               'agent_class', "", 'ok', true, 'note', "");
    if ismember('cfg', vars)
        S = load(f, 'cfg');
        c = S.cfg;
        r.cfg_fields = string(strjoin(fieldnames(c).', ' '));
        if isfield(c, 'rewardMode'), r.reward_mode = c.rewardMode; end
        if isfield(c, 'j6Lim'), r.j6_lim = c.j6Lim; end
        if isfield(c, 'baseW'), r.base_w = c.baseW; end
        if isfield(c, 'Ts_agent'), r.Ts_agent = c.Ts_agent; end
    end
    if ismember('agent', vars)
        S = load(f, 'agent');
        r.agent_class = string(class(S.agent));
        if isnan(r.Ts_agent), r.Ts_agent = S.agent.AgentOptions.SampleTime; end
    else
        r.ok = false;
        r.note = "keine Variable agent";
    end
    rows{i} = r;
    if r.ok
        list(end + 1) = struct('file', f, 'label', lab, 'group', spec{i, 1}, 'opts', {{}}); %#ok<AGROW>
    end
end
inv = struct2table([rows{:}]);
end
