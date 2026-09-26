function [E, S, H] = desktop_a51_reward(nStoch, extra, prefix)
%DESKTOP_A51_REWARD  Zerlegt den Return der Tracking-Agenten in die Reward-Terme (Befund A51).
%   [E, S, H] = desktop_a51_reward()     10 stochastische Episoden je Agent
%   [E, S, H] = desktop_a51_reward(2)    Kurztest
%   [E, S, H] = desktop_a51_reward(10, extra, 'D12_eval')   zusaetzliche Agenten (struct-Array mit label, file, hz),
%                                   z. B. die D12-Agenten. Ausgewertet wird immer mit dem Reward des Trainings
%                                   seit 09.04. (reward_mode 0), damit die Returns vergleichbar bleiben
%
%   Frage: Belohnt der Reward den Einbruch der abgestimmten Agenten im letzten Drittel des Halbkreises, oder
%   haben sie ein schlechteres Optimum desselben Rewards gefunden? Dazu laeuft jeder Agent in SK_desktop
%   (65 kg, Halbkreis 8,5 s, Wandzeit-Referenz, Trainingsrate) einmal deterministisch und nStoch-mal
%   stochastisch. Der Reward wird aus den geloggten Signalen mit den Gewichten aus rewardFcn (Modell-Chart,
%   in allen Modellstaenden seit 09.04. gleich) nachgerechnet und je Term und Bahndrittel summiert. Der
%   Vergleich mit dem geloggten Reward zeigt, ob die Nachrechnung stimmt.
%
%   Agenten (40 Hz): PPO_base (26.03., trainiert mit dem Reward OHNE Basis-Terme, Modell im Commit 50ad2ce),
%   PPO_basisori (30.03., Optionen aehnlich PPO_base, vermutlich erster Agent mit Basis-Termen),
%   Optimized (Bayes), CDR2-4 (Bayes + CDR), D10_40hz Seeds 0-2 (neu trainiert mit den Optionen von Optimized). 10 Hz: ppo_10hz und D10_10hz
%   (4000 Episoden) Seeds 0-2. Returns nur innerhalb einer Rate vergleichen (10 Hz hat ein Viertel der Schritte).
%
%   Ergebnis: data/simulation/desktop/A51_reward_<Zeit>_episodes.csv, _summary.csv, _hyper.csv und .mat

if nargin < 1, nStoch = 10; end
if nargin < 2, extra = []; end
if nargin < 3, prefix = 'A51_reward'; end
setup_project;
desktop_build_model();

cp = sk_path('SavedAgents', 'MotionProfile', 'Circle', 'PPO');
d10 = sk_path('SavedAgents', 'MotionProfile', 'D10');
ag = struct( ...
    'label', {'PPO_base', 'PPO_basisori', 'Optimized', 'CDR2-4', 'D10_40hz_s0', 'D10_40hz_s1', 'D10_40hz_s2', ...
              'ppo_10hz', 'D10_10hz_s0', 'D10_10hz_s1', 'D10_10hz_s2'}, ...
    'file', {fullfile(cp, 'SpaceKinova_PPO_agent_motionprofile.mat'), ...
             fullfile(cp, 'SpaceKinova_PPO_agent_motionprofile_basisori.mat'), fullfile(cp, 'Optimized.mat'), ...
             sk_path('SavedAgents', 'MotionProfile', 'CDR', 'PPO', 'CDR2-4.mat'), ...
             fullfile(d10, 'D10_ppo_40hz_seed0.mat'), fullfile(d10, 'D10_ppo_40hz_seed1.mat'), ...
             fullfile(d10, 'D10_ppo_40hz_seed2.mat'), fullfile(cp, 'ppo_10hz.mat'), ...
             fullfile(d10, 'D10_ppo_10hz_seed0_ep4000.mat'), fullfile(d10, 'D10_ppo_10hz_seed1_ep4000.mat'), ...
             fullfile(d10, 'D10_ppo_10hz_seed2_ep4000.mat')}, ...
    'hz', {40, 40, 40, 40, 40, 40, 40, 10, 10, 10, 10});
if ~isempty(extra)
    ag = [ag, extra(:).'];
end

% Hyperparameter der Agenten
H = table();
for a = 1:numel(ag)
    agent = loadAgentFile(ag(a).file);
    o = agent.AgentOptions;
    H = [H; table(string(ag(a).label), o.SampleTime, getOpt(o, 'ExperienceHorizon'), ...
        getOpt(o, 'MiniBatchSize'), getOpt(o, 'NumEpoch'), getOpt(o, 'DiscountFactor'), ...
        getOpt(o, 'GAEFactor'), getOpt(o, 'ClipFactor'), getOpt(o, 'EntropyLossWeight'), ...
        o.ActorOptimizerOptions.LearnRate, o.CriticOptimizerOptions.LearnRate, ...
        'VariableNames', {'agent', 'Ts', 'horizon', 'minibatch', 'epochs', 'gamma', 'gae', 'clip', ...
        'entropy', 'lr_actor', 'lr_critic'})]; %#ok<AGROW>
end
disp(H);

rows = {};
for a = 1:numel(ag)
    for k = 0:nStoch
        cfg = desktop_config('agentFile', ag(a).file, 'agentLabel', ag(a).label, 'Ts', 0.005, ...
            'Ts_agent', 1 / ag(a).hz, 'base_mass', 65, 'keepTs', true, 'explore', k > 0, 'seed', max(k, 1));
        r = desktop_run_episode(cfg);
        row = episodeRow(r, cfg);
        row.agent = string(ag(a).label);
        row.hz = ag(a).hz;
        row.stoch = k > 0;
        row.seed = k;
        rows{end + 1} = row; %#ok<AGROW>
        fprintf('%-12s %s seed %2d  ret %8.1f (nachgerechnet %8.1f)  q4 %.3f m  ori_max %.3f rad\n', ...
            ag(a).label, ternary(k > 0, 'stoch', 'det  '), k, row.ret, row.ret_rec, row.ep_q4, row.ori_max);
    end
end
E = struct2table([rows{:}]);
E = movevars(E, {'agent', 'hz', 'stoch', 'seed'}, 'Before', 1);

% Zusammenfassung je Agent und Modus (Mittel ueber die Episoden)
num = E.Properties.VariableNames(varfun(@isnumeric, E, 'OutputFormat', 'uniform'));
num = setdiff(num, {'hz', 'seed'}, 'stable');
S = groupsummary(E, {'agent', 'hz', 'stoch'}, 'mean', num);
S.Properties.VariableNames = regexprep(S.Properties.VariableNames, '^mean_', '');
[~, ord] = ismember(S.agent, string({ag.label}));
S = sortrows(addvars(S, ord, 'Before', 1), {'ord', 'stoch'});
S.ord = [];

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
out = sk_path('data', 'simulation', 'desktop', [prefix '_' stamp]);
writetable(E, [out '_episodes.csv']);
writetable(S, [out '_summary.csv']);
writetable(H, [out '_hyper.csv']);
save([out '.mat'], 'E', 'S', 'H');
disp(S(:, {'agent', 'stoch', 'ret', 'ret_rec', 'ep_q1', 'ep_q2', 'ep_q3', 'ep_q4', 'ori_max', ...
    'bonus_base_frac_t3', 'R_track_t3', 'R_base_t3', 'R_bonus_ee_t3', 'R_bonus_base_t3'}));
fprintf('Ergebnis: %s_*.csv\n', out);
end

function row = episodeRow(r, cfg)
m = r.metrics;
ts = r.ts;
T = cfg.T_path;
row = struct();
row.ret = m.ret;
row.mse_ee = m.mse_ee;
row.max_ee = m.max_ee;
row.ori_max = m.ori_max;
row.w_mean = m.w_mean;
row.early_stop = m.early_stop;

% Fehler je Viertel (Solver-Schritte, wie Hardware-Auswertung nach Zeit)
epn = vecnorm(ts.ep, 2, 2);
for q = 1:4
    k = ts.t_ee >= (q - 1) * T / 4 & (ts.t_ee < q * T / 4 | (q == 4 & ts.t_ee <= T + 1e-9));
    row.(sprintf('ep_q%d', q)) = mean(epn(k));
end
row.ep_final = epn(end);

% Reward-Terme zu den Agentenschritten. Beobachtung: [ep; ev; v_base; w_base; q; dq; e_ori] (29x1),
% ungeclippt ('obs'). dq_cmd ist der Befehl nach der Signalkette (a_rl).
tA = ts.t_agent;
obs = sampleAt(ts.t_obs, ts.obs, tA);
u = sampleAt(ts.t_a_rl, ts.a_rl, tA);
uPrev = [zeros(1, size(u, 2)); u(1:end - 1, :)];
ep = obs(:, 1:3); ev = obs(:, 4:6); wb = obs(:, 10:12); eo = obs(:, 27:29);
dist = vecnorm(ep, 2, 2);
wn = vecnorm(wb, 2, 2);
ori = vecnorm(eo, 2, 2);
du = u - uPrev;
terms.pos = -20.0 * min(sum(ep.^2, 2), 0.25);
terms.vel = -2.0 * min(sum(ev.^2, 2), 4.0);
terms.u = -0.02 * min(sum(u.^2, 2), 10.0);
terms.du = -0.05 * min(sum(du.^2, 2), 10.0);
terms.ori = -8.0 * min(sum(eo.^2, 2), 0.5);
terms.w = -4.0 * min(sum(wb.^2, 2), 1.0);
terms.b5 = 1.0 * (dist < 0.05);
terms.b2 = 3.0 * (dist < 0.02);
terms.bb = 2.0 * (ori < 0.02 & wn < 0.01);
rec = terms.pos + terms.vel + terms.u + terms.du + terms.ori + terms.w + terms.b5 + terms.b2 + terms.bb;
row.ret_rec = sum(rec);
row.rec_err_max = max(abs(rec - ts.reward(:)));

% Summen je Drittel: Tracking (pos + vel), Aktion (u + du), Basis (ori + w), Boni
edges = [0, T / 3, 2 * T / 3, inf];
for w = 1:3
    k = tA >= edges(w) & tA < edges(w + 1);
    row.(sprintf('R_track_t%d', w)) = sum(terms.pos(k) + terms.vel(k));
    row.(sprintf('R_action_t%d', w)) = sum(terms.u(k) + terms.du(k));
    row.(sprintf('R_base_t%d', w)) = sum(terms.ori(k) + terms.w(k));
    row.(sprintf('R_bonus_ee_t%d', w)) = sum(terms.b5(k) + terms.b2(k));
    row.(sprintf('R_bonus_base_t%d', w)) = sum(terms.bb(k));
    row.(sprintf('bonus_base_frac_t%d', w)) = mean(terms.bb(k) > 0);
    row.(sprintf('ori_max_t%d', w)) = max(ori(k));
end
end

function X = sampleAt(t, Y, tq)
% Wert zum Zeitpunkt tq (letzter Wert bis einschliesslich tq)
[t, iu] = unique(t(:), 'last');
Y = Y(iu, :);
X = interp1(t, Y, tq(:) + 1e-9, 'previous', 'extrap');
end

function v = getOpt(o, name)
if isprop(o, name), v = double(o.(name)); else, v = NaN; end
end

function agent = loadAgentFile(f)
s = load(f, 'agent');
agent = s.agent;
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end
