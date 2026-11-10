function [E, A, G] = ext_x4_2_run(varargin)
%EXT_X4_2_RUN  Alle Bestandsagenten mit dem Protokoll X0.1 neu auswerten (Ausbau X4.2).
%   [E, A, G] = ext_x4_2_run()
%   [E, A, G] = ext_x4_2_run('nAgents', 2, 'parallel', false, 'nPert', 0, 'study', 'X4_2test')   Rauchtest
%
%   Liste aus ext_x4_2_list (93 Agenten: fruehes PPO, Optimized, ppo_10hz, CDR, D10-D14, D16, D20). Je Agent
%   21 Episoden wie X0.1 (nominal und 20 Startstoerungen +-2 Grad), Trainingsbedingungen aus dem cfg des
%   Agenten. Auswertung mit ext_eval_batch in SK_desktop.
%   Ergebnis: X_eval_<study>_<Zeit>_* (ext_eval_batch), dazu <study>_inventory.csv (Bestandsaufnahme) und
%   <study>_groups_<Zeit>.csv (je Gruppe: Anzahl, Anzahl folgt, Median und IQR von rms_ee, ep_q4, ori_max).
%   Optionen: nAgents (alle), parallel (true), study ('X4_2'), weitere Name-Wert-Paare an ext_eval_agent.

p = inputParser;
p.KeepUnmatched = true;
p.addParameter('nAgents', Inf);
p.addParameter('parallel', true);
p.addParameter('study', 'X4_2');
p.parse(varargin{:});
o = p.Results;
rest = namedargs2cell(p.Unmatched);
setup_project;
[list, inv] = ext_x4_2_list();
outDir = sk_path('data', 'simulation', 'extension');
writetable(inv, fullfile(outDir, [o.study '_inventory.csv']));
assert(all(inv.ok), 'ext_x4_2_run:inventory', 'Agentendatei ohne Variable agent, siehe Inventar');
list = list(1:min(numel(list), o.nAgents));
fprintf('X4.2: %d Agenten\n', numel(list));
[E, A] = ext_eval_batch(list, o.study, 'parallel', o.parallel, rest{:});

grp = string({list.group}).';
A.group = grp(1:height(A));
rows = {};
for g = unique(A.group, 'stable').'
    S = A(A.group == g, :);
    rows{end + 1} = struct('group', g, 'n', height(S), 'n_follows', sum(S.follows), ...
        'rms_med', median(S.rms_ee), 'rms_q1', prctile(S.rms_ee, 25), 'rms_q3', prctile(S.rms_ee, 75), ...
        'ep_q4_med', median(S.ep_q4), 'ori_med', median(S.ori_max), 'ori_q1', prctile(S.ori_max, 25), ...
        'ori_q3', prctile(S.ori_max, 75), 'ori_worst_max', max(S.ori_max_worst), 'n_stop', sum(S.n_stop)); %#ok<AGROW>
end
G = struct2table([rows{:}]);
disp(G);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
writetable(G, fullfile(outDir, [o.study '_groups_' stamp '.csv']));
end
