function [E, A, S] = desktop_d11_eval(nStoch, nMass)
%DESKTOP_D11_EVAL  Auswertung des neuen Algorithmenvergleichs (Desktop-Plan D11, Befund A64).
%   [E, A, S] = desktop_d11_eval()        10 stochastische Episoden, 20 Massenziehungen je Agent
%   [E, A, S] = desktop_d11_eval(2, 2)    Kurztest
%
%   Liest alle Agenten aus SavedAgents/MotionProfile/D11 (D11_<algo>_seed<n>.mat). Jeder Agent laeuft im Modell des
%   Trainings (SK_desktop, Reward-Modus 0, 40 Hz, J6 0,1 rad/s, Halbkreis 8,5 s):
%     nominal   65 kg, deterministische Policy (wie auf der Hardware)
%     stoch     65 kg, stochastische Policy, Seeds 1..nStoch
%     mass      deterministisch, Basismasse 65 kg * max(0,5; 1 + 0,65 randn), dieselben Ziehungen wie D1
%   Kennzahlen je Episode: K1 EE-MSE, K2 groesster EE-Fehler, K3 groesster Basis-Orientierungsfehler, K4 Return
%   unter Gl. 3, K5 frueher Abbruch, dazu der mittlere EE-Fehler im letzten Viertel.
%   E  eine Zeile je Episode
%   A  eine Zeile je Agent und Satz (Mittel ueber die Episoden des Satzes)
%   S  eine Zeile je Verfahren und Satz: Mittel, Standardabweichung und Median ueber die Seeds, dazu die Zahl der
%      Seeds ohne fruehen Abbruch (Grundlage fuer die neue Table II)
%   Ergebnis: data/simulation/desktop/D11_eval_<Zeit>_episodes.csv, _agents.csv, _summary.csv und .mat

if nargin < 1, nStoch = 10; end
if nargin < 2, nMass = 20; end
setup_project;
desktop_build_model();

d = dir(sk_path('SavedAgents', 'MotionProfile', 'D11', 'D11_*_seed*.mat'));
assert(~isempty(d), 'desktop_d11_eval:none', 'Keine D11-Agenten gefunden');
rng(20260924, 'twister');                          % Massenziehungen wie in D1
massFactor = max(0.5, 1 + 0.65 * randn(nMass, 1));

rows = {};
for k = 1:numel(d)
    tok = regexp(d(k).name, '^D11_([A-Z0-9]+)_seed(\d+)(_ep\d+)?\.mat$', 'tokens', 'once');
    if isempty(tok), continue; end
    algo = tok{1}; seed = str2double(tok{2});
    f = fullfile(d(k).folder, d(k).name);
    base = {'agentFile', f, 'agentLabel', algo, 'Ts', 0.005, 'Ts_agent', 0.025, 'keepTs', true, ...
        'reward_mode', 0, 'j6_lim', 0.1};
    jobs = {'nominal', 0, desktop_config(base{:}, 'base_mass', 65)};
    for s = 1:nStoch
        jobs(end + 1, :) = {'stoch', s, desktop_config(base{:}, 'base_mass', 65, 'explore', true, 'seed', s)}; %#ok<AGROW>
    end
    for m = 1:nMass
        jobs(end + 1, :) = {'mass', m, desktop_config(base{:}, 'base_mass', 65 * massFactor(m))}; %#ok<AGROW>
    end
    for j = 1:size(jobs, 1)
        r = desktop_run_episode(jobs{j, 3});
        mt = r.metrics;
        epn = vecnorm(r.ts.ep, 2, 2);
        q4 = mean(epn(r.ts.t_ee >= 3 * 8.5 / 4));
        rows{end + 1} = struct('algo', string(algo), 'seed', seed, 'set', string(jobs{j, 1}), ...
            'draw', jobs{j, 2}, 'K1', mt.mse_ee, 'K2', mt.max_ee, 'K3', mt.ori_max, 'K4', mt.ret, ...
            'K5', double(mt.early_stop), 'ep_q4', q4, 't_end', mt.t_end, 'stop_reason', string(mt.stop_reason)); %#ok<AGROW>
    end
    fprintf('%-5s Seed %d: nominal K1 %.5f, K3 %.4f, K4 %.1f, Abbruch %d\n', algo, seed, rows{end - nStoch - nMass}.K1, ...
        rows{end - nStoch - nMass}.K3, rows{end - nStoch - nMass}.K4, rows{end - nStoch - nMass}.K5);
end
E = struct2table([rows{:}]);

% Mittel je Agent und Satz
A = groupsummary(E, {'algo', 'seed', 'set'}, 'mean', {'K1', 'K2', 'K3', 'K4', 'K5', 'ep_q4'});
A.Properties.VariableNames = regexprep(A.Properties.VariableNames, '^mean_', '');

% Je Verfahren und Satz ueber die Seeds
S = groupsummary(A, {'algo', 'set'}, {'mean', 'std', 'median'}, {'K1', 'K2', 'K3', 'K4', 'K5', 'ep_q4'});
noStop = groupsummary(A, {'algo', 'set'}, @(x) sum(x == 0), 'K5');
S.seeds_without_stop = noStop{:, end};
order = ["PPO"; "TRPO"; "PG"; "DDPG"; "TD3"; "SAC"];
[~, o] = ismember(S.algo, order);
S = sortrows(addvars(S, o, 'Before', 1, 'NewVariableNames', 'ord'), {'set', 'ord'});
S.ord = [];
disp(S(S.set == "nominal", {'algo', 'GroupCount', 'mean_K1', 'std_K1', 'mean_K3', 'mean_K4', 'mean_K5', ...
    'seeds_without_stop'}));

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
out = sk_path('data', 'simulation', 'desktop', ['D11_eval_' stamp]);
writetable(E, [out '_episodes.csv']);
writetable(A, [out '_agents.csv']);
writetable(S, [out '_summary.csv']);
save([out '.mat'], 'E', 'A', 'S', 'massFactor');
fprintf('Ergebnis: %s_*.csv\n', out);
end
