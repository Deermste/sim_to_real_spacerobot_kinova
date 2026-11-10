function [reward, isDone] = ext_reward(ep, ev, dq_cmd, dq_cmd_prev, w_base, e_ori, mode, base_w)
%EXT_REWARD  Reward von SK_desktop als MATLAB-Funktion fuer den kinematischen Simulator (X0.2).
%   [r, done] = ext_reward(ep, ev, a, a_prev, w_base, e_ori, mode, base_w)
%
%   Zeile fuer Zeile wie rewardCode in desktop_build_model (Modi 0 bis 4). dq_cmd ist die Rohaktion des Agenten
%   (vor der Saettigung), dq_cmd_prev die des vorigen Schritts. ext_x0_validate_kinsim prueft die Gleichheit
%   mit dem geloggten Reward von SK_desktop. Aenderungen am Reward immer in beiden Dateien.

if any(~isfinite([ep; ev; dq_cmd; dq_cmd_prev; w_base; e_ori]))
    reward = -50; isDone = true; return;
end
dist = norm(ep); vel = norm(ev); w_norm = norm(w_base); ori = norm(e_ori);
if dist > 0.5 || vel > 2.0 || (mode ~= 1 && ori > 1.0)
    reward = -50; isDone = true; return;
end
c_pos = min(ep.' * ep, 0.25);
c_vel = min(ev.' * ev, 4.0);
c_u   = min(dq_cmd.' * dq_cmd, 10.0);
du    = dq_cmd - dq_cmd_prev;
c_du  = min(du.' * du, 10.0);
c_ori = min(e_ori.' * e_ori, 0.5);
c_w   = min(w_base.' * w_base, 1.0);
if mode == 1
    reward = - 20.0 * c_pos - 2.0 * c_vel - 0.02 * c_u - 0.05 * c_du;
else
    reward = - 20.0 * c_pos - 2.0 * c_vel - 0.02 * c_u - 0.05 * c_du - 8.0 * c_ori - 4.0 * c_w;
end
if mode == 3
    g = exp(-(dist / 0.05)^2);
    reward = reward - 5.0 * min(dist, 0.2) + 1.0 * g + 3.0 * exp(-(dist / 0.02)^2) ...
        + 2.0 * g * exp(-(ori / 0.02)^2) * exp(-(w_norm / 0.01)^2);
else
    if dist < 0.05, reward = reward + 1; end
    if dist < 0.02, reward = reward + 3; end
    if mode == 0 && ori < 0.02 && w_norm < 0.01, reward = reward + 2; end
    if mode == 2 && ori < 0.02 && w_norm < 0.01 && dist < 0.05, reward = reward + 2; end
    if mode == 4 && dist < 0.05
        reward = reward + base_w * exp(-(ori / 0.05)^2);
        if ori < 0.02 && w_norm < 0.01, reward = reward + 2; end
    end
end
isDone = false;
end
