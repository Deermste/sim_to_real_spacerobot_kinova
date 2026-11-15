function out = media_scenes_sim(scene, varargin)
%MEDIA_SCENES_SIM  Simulationsszenen fuer Bilder und Videos (frei schwebende Basis), ueber media_scene1 gerendert.
%   out = media_scenes_sim('problem')            IK-Bahnregler ohne Basis (R0) gegen den fertigen Agenten (D16 r4 s2)
%   out = media_scenes_sim('budget')             Agent ohne Budget (r1, X1.3) gegen Agent mit Budget (theta 0,03)
%   out = media_scenes_sim('problem', 'video', false)   weitere Optionen gehen an media_scene1
%
%   Alle in der Ebene (Halbkreis wie im Training), J2, J4, J6 mit 0,9774 rad/s, 40 Hz, volle Befehlskette, 65 kg,
%   nominaler Start, ext_kinsim (in X0.2 gegen SK_desktop validiert).
%   problem: Links ein Resolved-Rate-Regler auf der verallgemeinerten Jacobi-Matrix (R0, beta 0): Er kennt die
%     frei schwebende Kinematik und folgt der Bahn, die Basisdrehung kommt in seinem Ziel nicht vor. Das ist die
%     uebliche inverse Kinematik fuer das Tracking. Rechts D16 r4 Seed 2 (Reward mit Bahn und glattem Basis-Term).

setup_project;
ma = sk_path('SavedAgents', 'MotionProfile');
base = struct('kind', '', 'beta', 0, 'file', '', 'rewardMode', 4, 'joints', 'J246', 'path', 'planar', 'tilt', 0, ...
              'title', {{}});
switch scene
    case 'problem'
        P(1) = base; P(1).kind = 'ctrl'; P(1).beta = 0;
        P(1).title = {'Inverse kinematics tracking, base rotation ignored (R0)', ...
                      'Inverse Kinematik fuer die Bahn, Basisdrehung nicht beachtet (R0)'};
        P(2) = base; P(2).kind = 'agent'; P(2).file = fullfile(ma, 'D16', 'D16_ppo_40hz_r4_seed2.mat');
        P(2).title = {'RL agent: tracking and keeping the base steady (PPO, r4)', ...
                      'RL-Agent: Bahn und ruhige Basis (PPO, r4)'};
        main = {'Free-floating base, half-circle path: what happens to the base?', ...
                'Frei schwebende Basis, Halbkreis: Was passiert mit der Basis?'};
    case 'budget'
        x1 = fullfile(ma, 'X1');
        P(1) = base; P(1).kind = 'agent'; P(1).rewardMode = 5;
        P(1).file = fullfile(x1, 'X1_ppo_40hz_r5_c1_th30_eta0_seed0_ep3000_b50.mat');
        P(1).title = {'RL agent without base budget (r1)', 'RL-Agent ohne Budget (r1)'};
        P(2) = base; P(2).kind = 'agent'; P(2).rewardMode = 5;
        P(2).file = fullfile(x1, 'X1_ppo_40hz_r5_c1_th30_eta5_seed6_ep3000_b50_l1.mat');
        P(2).title = {'RL agent with base budget 1.7° (\theta = 0.03 rad)', ...
                      'RL-Agent mit Budget 1,7° (\theta = 0,03 rad)'};
        main = {'Free-floating base, half-circle path: base budget as a constraint', ...
                'Frei schwebende Basis, Halbkreis: Budget fuer die Basisdrehung'};
    case 'residual'
        out = residualScene(varargin{:});
        return
    otherwise
        error('media_scenes_sim:scene', 'Szene problem, budget oder residual');
end
% Mast 1,0 m (z. B. Antenne) und Balken bis 5 Grad, damit die Basisdrehung sichtbar wird (Nutzer 14.11.)
out = media_scene1('panels', P, 'name', ['sim_' scene], 'main', main, 'boom', 1.0, 'barMax', 5, varargin{:});
end

% =====================================================================
function out = residualScene(varargin)
% X7 (15.11.2026): Szenario mass_0.25 aus X2.3 (Basis 16,25 kg, beide kennen nur das Nominalmodell 65 kg).
% Links C2 (Kp 12, beta 26,1, J6-Seite -1), rechts derselbe Grundregler der Policy (Rbeta 21,5) plus gelernte
% Korrektur, Seed 17 aus der Bestaetigung (X7_T2). Seed 17 liegt in diesem Szenario im Mittelfeld der 20 Seeds
% (Rang 11 von 20, J -15,4 % gegen C2), nicht beim besten. Rechnung wie ext_x2_robust, die Kennzahlen werden gegen
% X7_T2_robust_20261115_145114_summary.csv geprueft.
dd = sk_path('data', 'simulation', 'extension');
Knom = ext_kin_model();
Kp = ext_kin_model('base_mass', 65 * 0.25);
bC2 = logspace(0, 2, 25);
c = ext_x2_controller('j6_lim', 0.9774, 'invert', true, 'K', Knom, 'beta', bC2(18), 'j6_side', -1, 'Kp', 12);
runs{1} = ext_kinsim([], 'ctrl', c, 'j6_lim', 0.9774, 'reward_mode', 4, 'K', Kp);
L = load(fullfile(dd, 'X7_T2_list_20261115_144432.mat'), 'list');
k = find(endsWith(string({L.list.file}), 'X7_T2_P_r4_seed17.mat'));
assert(numel(k) == 1, 'media_scenes_sim:seed', 'Seed 17 nicht in der Liste');
rk = L.list(k);
h = ext_x7_ctrl(ext_policy(rk.file), 'eps_v', rk.eps_v, 'eps_w', rk.eps_w, 'K', Knom);
runs{2} = ext_kinsim([], 'ctrl', h, 'j6_lim', 0.9774, 'reward_mode', 4, 'K', Kp);
S = readtable(fullfile(dd, 'X7_T2_robust_20261115_145114_summary.csv'), 'TextType', 'string');
S = S(S.scenario == "mass_0.25", :);
ref = [S(S.subject == "C2", :); S(S.subject == "P_r4_s17", :)];
for i = 1:2
    m = runs{i}.metrics;
    assert(abs(m.rms_ee - ref.rms_ee(i)) < 1e-9 && abs(m.ori_max - ref.ori_max(i)) < 1e-9, ...
           'media_scenes_sim:check', 'Lauf %d weicht von der Auswertung ab', i);
end
titles = {{'Classical controller C2 (nominal model)', 'Klassischer Regler C2 (Nominalmodell)'}, ...
          {'Same kind of controller + learned correction (residual RL)', ...
           'Gleicher Reglertyp + gelernte Korrektur (Residual RL)'}};
main = {'Base 4× lighter than the model assumes (16 kg instead of 65 kg)', ...
        'Basis viermal leichter als im Modell (16 kg statt 65 kg)'};
out = media_scene1('runs', runs, 'titles', titles, 'name', 'sim_residual', 'main', main, 'boom', 1.0, ...
                   'barMax', 3, varargin{:});
end
