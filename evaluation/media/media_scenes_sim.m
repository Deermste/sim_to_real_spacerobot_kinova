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
    otherwise
        error('media_scenes_sim:scene', 'Szene problem oder budget');
end
out = media_scene1('panels', P, 'name', ['sim_' scene], 'main', main, varargin{:});
end
