function [E, S, outFile] = ext_x2_robust(varargin)
%EXT_X2_ROBUST  Robustheit: modellbasierte Regler gegen RL-Agenten bei Modell-, Aktor- und Sensorfehlern (X2.3).
%   [E, S] = ext_x2_robust()
%   [E, S] = ext_x2_robust('agents', list)       eigene Agentenliste (struct mit file, label, group)
%   [E, S] = ext_x2_robust('scenarios', {'nominal', 'mass_0.5'})   nur einzelne Szenarien
%   [E, S] = ext_x2_robust('controllers', {'R0k2', {'beta', 0, 'kOri', 2}})   weitere Regler (Name, Optionen)
%   [E, S] = ext_x2_robust('agents', 'none')     nur Regler
%   Liegt X2_4_ctrl_tuned.mat vor (ext_x2_4_tune_ctrl), kommen die dort eingestellten Regler dazu
%   ('useTuned', false schaltet das ab).
%
%   Alles im kinematischen Simulator (ext_kinsim, volle Befehlskette, J6 0,9774 rad/s, Halbkreis 8,5 s, 40 Hz).
%   Die Regler (ext_x2_controller mit Inversion der Kette) rechnen immer mit dem Nominalmodell (65 kg) und kennen
%   weder Verzoegerung noch Aktorfehler. Die Agenten sehen dieselben Stoerungen. Szenarien:
%     Modell     Basismasse und -traegheit x0,25 / 0,5 / 0,75 / 1,5 / 2, nur Traegheit x0,5 / 2, Gliedmassen
%                x0,8 / 1,2, Montage des Arms +-5 cm in x, +5 cm in z
%     Aktor      zusaetzliche Verzoegerung 1 und 2 Agentenschritte (25 / 50 ms), Verstaerkung x0,9 / 1,1
%                (cmd_scale), Gelenkfilter tau 0,05 s statt 0,02 s (langsamere Servos)
%     Sensor     Rauschen realistisch (ep 1 mm, ev 5 mm/s, v_base 1 mm/s, w_base 1 mrad/s, q 1 mrad,
%                dq 5 mrad/s, e_ori 1 mrad) und dreifach, je 5 Seeds. Fester Lagefehler der Basis 10 mrad um y,
%                fester EE-Positionsfehler 5 mm in x
%     Anfang     Startstellung +-2 Grad (Ziehungen 1-5 aus ext_x0_perturbations), Restdrehrate der Basis
%                +2 / -2 mrad/s um y und 2 mrad/s um x (Drehimpuls ungleich null)
%   Regler: R0 und drei Punkte der Front aus X2.1 (beta 1, 21,5, 46,4 mit J6-Seite -1, Kp 5).
%   Agenten (Standard): r4 mit 3000 Episoden aus D16 (Gewicht 2, Seeds 0-7) und D17 (Gewichte 0, 4, 8, 16,
%   Seeds 0-2), wie in X0.1. Weitere Agenten (X4.1, X1.3) ueber 'agents'.
%   "folgt": kein Abbruch und mittlerer Fehler im letzten Viertel < 5 cm (wie X0.1).
%   Ergebnis: data/simulation/extension/X2_robust_<Zeit>_episodes.csv, _summary.csv, .mat

p = inputParser;
p.addParameter('agents', []);
p.addParameter('scenarios', {});
p.addParameter('controllers', {});
p.addParameter('useTuned', true);
p.addParameter('save', true);
p.parse(varargin{:});
o = p.Results;
setup_project;
Knom = ext_kin_model();

% --- Teilnehmer ---
subj = struct('label', {}, 'group', {}, 'make', {});
ctl = {'R0', {'beta', 0}; 'Rb1', {'beta', 1, 'j6_side', -1}; 'Rb21', {'beta', 21.544, 'j6_side', -1}; ...
       'Rb46', {'beta', 46.416, 'j6_side', -1}};
ctl = [ctl; o.controllers];
% Auf die DR-voll-Verteilung eingestellte Regler (ext_x2_4_tune_ctrl), falls vorhanden
tf = sk_path('data', 'simulation', 'extension', 'X2_4_ctrl_tuned.mat');
if o.useTuned && isfile(tf)
    L = load(tf, 'tuned');
    ctl = [ctl; L.tuned];
end
for c = 1:size(ctl, 1)
    args = [{'j6_lim', 0.9774, 'invert', true, 'K', Knom}, ctl{c, 2}];
    subj(end + 1) = struct('label', ctl{c, 1}, 'group', 'ctrl', 'make', @() ctrlRunner(args)); %#ok<AGROW>
end
list = o.agents;
if isempty(list), list = defaultAgents(); end
if ischar(list) && strcmp(list, 'none'), list = struct('file', {}, 'label', {}, 'group', {}); end
for k = 1:numel(list)
    pol = ext_policy(list(k).file);
    subj(end + 1) = struct('label', list(k).label, 'group', list(k).group, 'make', @() pol); %#ok<AGROW>
end

% --- Szenarien ---
sc = scenarios();
if ~isempty(o.scenarios), sc = sc(ismember({sc.name}, o.scenarios)); end
Q0 = ext_x0_perturbations();

rows = {};
tAll = tic;
for s = 1:numel(sc)
    K = Knom;
    if ~isempty(sc(s).plant), K = ext_kin_model(sc(s).plant{:}); end
    for r = 1:sc(s).nRep
        extra = sc(s).sim;
        if sc(s).noise > 0
            extra = [extra, {'obsNoise', sc(s).noise * noiseSigma(), 'rngSeed', r}]; %#ok<AGROW>
        end
        if sc(s).pose
            extra = [extra, {'q0', Q0(r + 1, :).'}]; %#ok<AGROW>
        end
        for j = 1:numel(subj)
            h = subj(j).make();
            if strcmp(subj(j).group, 'ctrl')
                res = ext_kinsim([], 'ctrl', h, 'j6_lim', 0.9774, 'reward_mode', 4, 'K', K, extra{:});
            else
                res = ext_kinsim(h, 'j6_lim', 0.9774, 'reward_mode', 4, 'K', K, extra{:});
            end
            m = res.metrics;
            rows{end + 1} = struct('scenario', string(sc(s).name), 'sgroup', string(sc(s).group), 'rep', r, ...
                'subject', string(subj(j).label), 'group', string(subj(j).group), 'rms_ee', m.rms_ee, ...
                'ep_q4', m.ep_q4, 'max_ee', m.max_ee, 'ori_max', m.ori_max, 'w_max', m.w_max, ...
                'early_stop', double(m.early_stop), ...
                'follows', double(~m.early_stop && m.ep_q4 < 0.05)); %#ok<AGROW>
        end
    end
    fprintf('%-14s fertig (%.1f min)\n', sc(s).name, toc(tAll) / 60);
end
E = struct2table([rows{:}]);

% --- Zusammenfassung je Teilnehmer und Szenario (Mittel ueber Wiederholungen), Verlust gegen nominal ---
[g, sName, sGrp, subjName, grp] = findgroups(E.scenario, E.sgroup, E.subject, E.group);
S = table(sName, sGrp, subjName, grp, splitapply(@mean, E.rms_ee, g), splitapply(@mean, E.ori_max, g), ...
    splitapply(@mean, E.ep_q4, g), splitapply(@min, E.follows, g), 'VariableNames', ...
    {'scenario', 'sgroup', 'subject', 'group', 'rms_ee', 'ori_max', 'ep_q4', 'follows_all'});
nom = S(S.scenario == "nominal", {'subject', 'rms_ee', 'ori_max'});
nom.Properties.VariableNames = {'subject', 'rms_nom', 'ori_nom'};
S = outerjoin(S, nom, 'Keys', 'subject', 'MergeKeys', true, 'Type', 'left');
S.d_rms = S.rms_ee - S.rms_nom;
S.d_ori = S.ori_max - S.ori_nom;
S = sortrows(S, {'sgroup', 'scenario', 'group', 'subject'});
fprintf('%d Episoden in %.1f min\n', height(E), toc(tAll) / 60);

outFile = '';
if o.save
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    outFile = sk_path('data', 'simulation', 'extension', ['X2_robust_' stamp]);
    writetable(E, [outFile '_episodes.csv']);
    writetable(S, [outFile '_summary.csv']);
    agents = list; %#ok<NASGU>
    save([outFile '.mat'], 'E', 'S', 'sc', 'agents');
    fprintf('Ergebnis: %s_*.csv\n', outFile);
end
end

% =====================================================================
function h = ctrlRunner(args)
% Neuer Regler je Episode (Zustand der Ketten-Inversion)
h = ext_x2_controller(args{:});
end

function s = noiseSigma()
% realistische Messfehler je Kanal [ep; ev; v_base; w_base; q; dq; e_ori]
s = [1e-3 * ones(3, 1); 5e-3 * ones(3, 1); 1e-3 * ones(3, 1); 1e-3 * ones(3, 1); 1e-3 * ones(7, 1); ...
     5e-3 * ones(7, 1); 1e-3 * ones(3, 1)];
end

function sc = scenarios()
sc = struct('name', {}, 'group', {}, 'plant', {}, 'sim', {}, 'noise', {}, 'pose', {}, 'nRep', {});
add('nominal', 'nominal', {}, {});
for f = [0.25 0.5 0.75 1.5 2]
    add(sprintf('mass_%g', f), 'model', {'base_mass', 65 * f}, {});
end
for f = [0.5 2]
    add(sprintf('inertia_%g', f), 'model', {'base_inertia', 10.833 * f}, {});
end
for f = [0.8 1.2]
    add(sprintf('links_%g', f), 'model', {'link_mass_scale', f}, {});
end
add('mount_x+5cm', 'model', {'mount_offset', [0.05 0 0]}, {});
add('mount_x-5cm', 'model', {'mount_offset', [-0.05 0 0]}, {});
add('mount_z+5cm', 'model', {'mount_offset', [0 0 0.05]}, {});
add('delay_25ms', 'actuator', {}, {'delay_steps', 1});
add('delay_50ms', 'actuator', {}, {'delay_steps', 2});
add('gain_0.9', 'actuator', {}, {'cmd_scale', 0.9});
add('gain_1.1', 'actuator', {}, {'cmd_scale', 1.1});
add('servo_tau50ms', 'actuator', {}, {'tau', 0.05});
add('noise_1x', 'sensor', {}, {}, 1, false, 5);
add('noise_3x', 'sensor', {}, {}, 3, false, 5);
b = zeros(29, 1); b(28) = 0.01;
add('bias_ori_10mrad', 'sensor', {}, {'obsBias', b});
b = zeros(29, 1); b(1) = 0.005;
add('bias_ee_5mm', 'sensor', {}, {'obsBias', b});
add('pose_2deg', 'initial', {}, {}, 0, true, 5);
add('drift_y+2mrad', 'initial', {}, {'w0_init', [0; 0.002; 0]});
add('drift_y-2mrad', 'initial', {}, {'w0_init', [0; -0.002; 0]});
add('drift_x2mrad', 'initial', {}, {'w0_init', [0.002; 0; 0]});

    function add(name, group, plant, sim, noise, pose, nRep)
        if nargin < 5, noise = 0; end
        if nargin < 6, pose = false; end
        if nargin < 7, nRep = 1; end
        sc(end + 1) = struct('name', name, 'group', group, 'plant', {plant}, 'sim', {sim}, 'noise', noise, ...
                             'pose', pose, 'nRep', nRep);
    end
end

function list = defaultAgents()
ma = sk_path('SavedAgents', 'MotionProfile');
list = struct('file', {}, 'label', {}, 'group', {});
for s = 0:7
    list(end + 1) = struct('file', fullfile(ma, 'D16', sprintf('D16_ppo_40hz_r4_seed%d_ep3000.mat', s)), ...
                           'label', sprintf('w2_s%d', s), 'group', 'rl'); %#ok<AGROW>
end
for w = [0 4 8 16]
    for s = 0:2
        list(end + 1) = struct('file', fullfile(ma, 'D17', sprintf('D17_ppo_40hz_r4_w%d_seed%d_ep3000.mat', w, s)), ...
                               'label', sprintf('w%d_s%d', w, s), 'group', 'rl'); %#ok<AGROW>
    end
end
end
