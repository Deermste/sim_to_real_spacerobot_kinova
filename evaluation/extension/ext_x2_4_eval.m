function [E, A, outFile] = ext_x2_4_eval()
%EXT_X2_4_EVAL  Protokoll X0.1 in SK_desktop fuer die 20 DR-Agenten aus X2.4 (DR-M und DR-voll, Seeds 0-9).
%   [E, A, outFile] = ext_x2_4_eval()
%
%   Aufbau aus dem cfg der Agenten (r4, J6 0,9774, w 2, 40 Hz), nominales Modell (65 kg, keine Randomisierung),
%   21 Episoden je Agent. Gruppen drM und drfull. Auswertung mit ext_x2_4_eval_report.
%   Ergebnis: data/simulation/extension/X_eval_X2_4_<Zeit>_*

setup_project;
d = dir(sk_path('SavedAgents', 'MotionProfile', 'X2_4', 'X2_4_ppo_40hz_r4_dr*_seed*_ep3000.mat'));
assert(numel(d) == 20, 'ext_x2_4_eval:n', '%d statt 20 Agenten', numel(d));
list = struct('file', {}, 'label', {}, 'group', {}, 'opts', {});
for k = 1:numel(d)
    [~, n] = fileparts(d(k).name);
    list(end + 1) = struct('file', fullfile(d(k).folder, d(k).name), 'label', n, ...
                           'group', char(extractBetween(string(n), "r4_", "_seed")), 'opts', {{}}); %#ok<AGROW>
end
[E, A, outFile] = ext_eval_batch(list, 'X2_4');
end
