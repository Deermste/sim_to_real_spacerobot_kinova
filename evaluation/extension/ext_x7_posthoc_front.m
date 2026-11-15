function ext_x7_posthoc_front()
%EXT_X7_POSTHOC_FRONT  Nachtrag X7.3 (15.11.2026, nicht vorab festgelegt): dichte klassische Front und Regler am
%   Ort der Residual-Policy (Median der Seeds 1 bis 10 aus C: 6,67 mm, 16,06 mrad), 26 Szenarien wie X2.3.
%   Auswahl der Regler nur nach dem nominalen Punkt:
%   C1 kleinster RMS bei ori_max <= 16,06 mrad, C2 kleinste Drehung bei RMS <= 6,67 mm, dazu Kp 10, beta 21,5.
%   Ergebnis: data/simulation/extension/X2_sweep_<Zeit>.csv, X7_C_posthoc_robust_<Zeit>_*.

setup_project;
T = ext_x2_sweep('betas', logspace(0, 2, 25), 'Kp', [5 6 7 8 10 12 15 20], 'j6', 0.9774, ...
                 'variants', {'full_inv'}, 'sides', -1);
disp(T(:, {'Kp', 'beta', 'rms_ee', 'ori_max'}));
ok = T.rms_ee < 0.05;
T = T(ok, :);
i1 = find(T.ori_max <= 0.01606); [~, k] = min(T.rms_ee(i1)); i1 = i1(k);
i2 = find(T.rms_ee <= 0.00667); [~, k] = min(T.ori_max(i2)); i2 = i2(k);
fprintf('C1 Kp %g beta %.3f: %.2f mm %.2f mrad\n', T.Kp(i1), T.beta(i1), 1e3 * T.rms_ee(i1), 1e3 * T.ori_max(i1));
fprintf('C2 Kp %g beta %.3f: %.2f mm %.2f mrad\n', T.Kp(i2), T.beta(i2), 1e3 * T.rms_ee(i2), 1e3 * T.ori_max(i2));
ctl = {'Rk10b21', {'beta', 21.544, 'j6_side', -1, 'Kp', 10}; ...
       'C1', {'beta', T.beta(i1), 'j6_side', -1, 'Kp', T.Kp(i1)}; ...
       'C2', {'beta', T.beta(i2), 'j6_side', -1, 'Kp', T.Kp(i2)}};
ext_x2_robust('agents', 'none', 'useTuned', true, 'controllers', ctl, 'prefix', 'X7_C_posthoc_robust_');
end
