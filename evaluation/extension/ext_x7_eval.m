function [A, E, robFile] = ext_x7_eval(list, varargin)
%EXT_X7_EVAL  Auswertung der Residual-Agenten gegen den Regler allein (X7, 15.11.2026).
%   [A, E] = ext_x7_eval(list)              list: struct mit file, label, group ('res' oder 'resdr'), eps_v, eps_w
%   [A, E] = ext_x7_eval(list, 'robust', false, 'label', 'pilot')
%
%   1  X0.1 im kinematischen Simulator: 21 Startstellungen (ext_x0_perturbations, +-2 Grad auf J2, J4, J6),
%      nominales Modell. Teilnehmer: Regler Rbeta 21,5 allein (R) und jeder Residual-Agent. Kennzahlen je Episode
%      und je Teilnehmer (Mittel und schlechteste Episode, folgt wie X0.1).
%   2  Robustheit (Standard an): ext_x2_robust mit den 26 Szenarien, nur Regler und Residual-Agenten
%      (keine RL-Agenten, deren Werte liegen aus X2.3 und X2.4 vor).
%   Option 'controllers' (Standard leer): weitere Regler fuer Teil 2 wie in ext_x2_robust (Name, Optionen).
%   Ergebnis: data/simulation/extension/X7_<label>_{agents,episodes}_<Zeit>.csv und X7_<label>_robust_<Zeit>_*.

p = inputParser;
p.addParameter('robust', true);
p.addParameter('label', 'eval');
p.addParameter('controllers', {});
p.parse(varargin{:});
o = p.Results;
setup_project;
Knom = ext_kin_model();
Q0 = ext_x0_perturbations();
subj = struct('label', {'R'}, 'group', {'ctrl'}, 'make', {@() ext_x2_controller('j6_lim', 0.9774, ...
              'invert', true, 'K', Knom, 'beta', 21.544, 'j6_side', -1)});
for k = 1:numel(list)
    pol = ext_policy(list(k).file);
    ev = list(k).eps_v; ew = list(k).eps_w;
    subj(end + 1) = struct('label', list(k).label, 'group', list(k).group, ...
                           'make', @() ext_x7_ctrl(pol, 'eps_v', ev, 'eps_w', ew, 'K', Knom)); %#ok<AGROW>
end
rows = {};
for j = 1:numel(subj)
    for r = 1:size(Q0, 1)
        res = ext_kinsim([], 'ctrl', subj(j).make(), 'j6_lim', 0.9774, 'reward_mode', 4, 'q0', Q0(r, :).', ...
                         'keepTs', false);
        m = res.metrics;
        rows{end + 1} = struct('subject', string(subj(j).label), 'group', string(subj(j).group), 'draw', r - 1, ...
            'rms_ee', m.rms_ee, 'ep_q4', m.ep_q4, 'max_ee', m.max_ee, 'ori_max', m.ori_max, 'w_max', m.w_max, ...
            'early_stop', double(m.early_stop), 'follows', double(~m.early_stop && m.ep_q4 < 0.05)); %#ok<AGROW>
    end
end
E = struct2table([rows{:}]);
[g, s, gr] = findgroups(E.subject, E.group);
A = table(s, gr, splitapply(@min, E.follows, g), splitapply(@mean, E.rms_ee, g), splitapply(@max, E.ep_q4, g), ...
    splitapply(@mean, E.ori_max, g), splitapply(@max, E.ori_max, g), ...
    splitapply(@(v, d) v(d == 0), E.rms_ee, E.draw, g), splitapply(@(v, d) v(d == 0), E.ori_max, E.draw, g), ...
    'VariableNames', {'subject', 'group', 'follows', 'rms_ee', 'ep_q4_worst', 'ori_max', 'ori_max_worst', ...
                      'nom_rms_ee', 'nom_ori_max'});
disp(A);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
dd = sk_path('data', 'simulation', 'extension');
writetable(A, fullfile(dd, sprintf('X7_%s_agents_%s.csv', o.label, stamp)));
writetable(E, fullfile(dd, sprintf('X7_%s_episodes_%s.csv', o.label, stamp)));
robFile = '';
if o.robust
    [~, ~, robFile] = ext_x2_robust('agents', 'none', 'useTuned', false, 'controllers', o.controllers, ...
                                    'residuals', list, 'prefix', sprintf('X7_%s_robust_', o.label));
end
end
