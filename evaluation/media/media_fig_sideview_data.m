function f = media_fig_sideview_data()
%MEDIA_FIG_SIDEVIEW_DATA  Daten fuer die technische Seitenansicht (Grafik 3): IK-Bahnregler R0 gegen Agent D16 r4 s2.
%   f = media_fig_sideview_data()      schreibt media/figures/sideview_data.mat, gezeichnet von plot_sideview.py
%
%   Laeufe wie media_scenes_sim('problem'): Ebene, Halbkreis, J2/J4/J6 mit 0,9774 rad/s, volle Befehlskette, 65 kg,
%   nominaler Start, ext_kinsim. Je Lauf im Solvertakt (5 ms):
%     t, ee (EE in Welt), ref (Sollbahn), ori (Betrag der Basisdrehung [rad]), pitch (Drehung um y [rad]),
%     joints (n x 3 x 9: Ursprung von base_link, kinova_base_link, sieben Gelenke und EE-Punkt in Welt),
%     corners (n x 3 x 8: Ecken des Basiswuerfels in Welt)
%   Die Bewegung liegt in der x-z-Ebene, die Grafik zeigt die Seitenansicht (x nach rechts, z nach oben).

setup_project;
K = ext_kin_model();
lim = [0; 0.9774; 0; 0.9774; 0; 0.9774; 0];
c = ext_x2_controller('joints', [2 4 6], 'task', [1 3], 'lim', lim, 'j6_side', 0, 'K', K, 'invert', true, 'beta', 0);
runs{1} = ext_kinsim([], 'ctrl', c, 'lim', lim, 'reward_mode', 4, 'chain', 'full', 'K', K);
pol = ext_policy(sk_path('SavedAgents', 'MotionProfile', 'D16', 'D16_ppo_40hz_r4_seed2.mat'));
runs{2} = ext_kinsim(pol, 'reward_mode', 4, 'j6_lim', 0.9774, 'base_w', 2, 'lim', lim, 'K', K);
names = {'ik', 'rl'};
robot = importrobot(sk_path('robot', 'SpaceKinova.urdf'), 'DataFormat', 'column');
bodies = {'kinova_base_link', 'kinova_shoulder_link', 'kinova_half_arm_1_link', 'kinova_half_arm_2_link', ...
          'kinova_forearm_link', 'kinova_spherical_wrist_1_link', 'kinova_spherical_wrist_2_link', ...
          'kinova_bracelet_link', 'kinova_end_effector_link'};
cube = 0.5 * [-1 -1 -1; 1 -1 -1; 1 1 -1; -1 1 -1; -1 -1 1; 1 -1 1; 1 1 1; -1 1 1].';
f = struct();
for r = 1:2
    ts = runs{r}.ts;
    n = numel(ts.t_ee);
    J = zeros(n, 3, numel(bodies) + 1); C = zeros(n, 3, 8); pitch = zeros(n, 1);
    for k = 1:n
        R = q2r(ts.quat(k, :)); pb = ts.pb(k, :).';
        J(k, :, 1) = pb.';
        for b = 1:numel(bodies)
            T = getTransform(robot, ts.q(k, :).', bodies{b});
            J(k, :, b + 1) = (pb + R * T(1:3, 4)).';
        end
        C(k, :, :) = reshape(pb + R * cube, 1, 3, 8);
        pitch(k) = atan2(R(1, 3), R(3, 3));            % Drehung um y (Seitenansicht)
    end
    f.(names{r}) = struct('t', ts.t_ee, 'ee', ts.ref + ts.ep, 'ref', ts.ref, 'ori', ts.ori, 'pitch', pitch, ...
                          'joints', J, 'corners', C, 'rms', runs{r}.metrics.rms_ee, 'ori_max', runs{r}.metrics.ori_max);
    fprintf('%s: RMS %.2f mm, ori_max %.1f mrad, |pitch| max %.1f mrad\n', names{r}, 1000 * runs{r}.metrics.rms_ee, ...
            1000 * runs{r}.metrics.ori_max, 1000 * max(abs(pitch)));
end
out = sk_path('media', 'figures');
if ~isfolder(out), mkdir(out); end
ik = f.ik; rl = f.rl; %#ok<NASGU>
save(fullfile(out, 'sideview_data.mat'), 'ik', 'rl', '-v7');
fprintf('gespeichert: %s\n', fullfile(out, 'sideview_data.mat'));
end

function R = q2r(qt)
w = qt(1); x = qt(2); y = qt(3); z = qt(4);
R = [1 - 2*(y^2 + z^2), 2*(x*y - z*w),     2*(x*z + y*w);
     2*(x*y + z*w),     1 - 2*(x^2 + z^2), 2*(y*z - x*w);
     2*(x*z - y*w),     2*(y*z + x*w),     1 - 2*(x^2 + y^2)];
end
