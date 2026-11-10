function T = ext_x5_1_obsclip()
%EXT_X5_1_OBSCLIP  Wie oft wuerden die 3D-Reglerbahnen an die Beobachtungsgrenzen der Agenten stossen? (X5.1, A72)
%   T = ext_x5_1_obsclip()
%
%   Grenzen aus der ObservationInfo von D16 r4 s2 (gleich fuer alle Bestandsagenten, A72). Reglerbahnen mit allen
%   sieben Gelenken (0,98 rad/s J1-J4, 0,58 rad/s J5-J7), volle Kette mit Inversion, nominal. Anteil der
%   Agentenschritte, in denen q bzw. dq ausserhalb der Grenzen liegt, je Gelenk.

setup_project;
K = ext_kin_model();
S = load(sk_path('SavedAgents', 'MotionProfile', 'D16', 'D16_ppo_40hz_r4_seed2_ep3000.mat'));
fn = fieldnames(S);
ag = [];
for i = 1:numel(fn)
    if isobject(S.(fn{i})), ag = S.(fn{i}); break; end
end
oi = getObservationInfo(ag);
lo = oi.LowerLimit(:); hi = oi.UpperLimit(:);
fprintf('q-Grenzen (obs 13:19):  %s\n', mat2str(hi(13:19).', 3));
fprintf('dq-Grenzen (obs 20:26): %s\n', mat2str(hi(20:26).', 3));
lim7 = [0.98 0.98 0.98 0.98 0.58 0.58 0.58].';
cases = {'planar', 0, 0; 'tilted', 30, 0; 'tilted', 30, 4.6416; 'tilted', -30, 0; 'tilted', -30, 4.6416; ...
         'tilted', -30, 46.416};
rows = {};
for c = 1:size(cases, 1)
    ctrl = ext_x2_controller('beta', cases{c, 3}, 'joints', 1:7, 'task', [1 2 3], 'lim', lim7, ...
                             'invert', true, 'K', K);
    r = ext_kinsim([], 'ctrl', ctrl, 'lim', lim7, 'reward_mode', 4, 'path', cases{c, 1}, 'tilt', cases{c, 2});
    O = r.ts.obs;
    clip = O < lo.' | O > hi.';
    rows{end + 1} = struct('path', string(cases{c, 1}), 'tilt', cases{c, 2}, 'beta', cases{c, 3}, ...
        'frac_q', mean(clip(:, 13:19)), 'frac_dq', mean(clip(:, 20:26)), 'frac_any', mean(any(clip, 2))); %#ok<AGROW>
end
T = struct2table([rows{:}]);
disp(T);
end
