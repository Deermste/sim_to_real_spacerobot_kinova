function y = ext_x1_4_sim_shield(cmd, obs, theta, alpha)
%EXT_X1_4_SIM_SHIELD  Sicherheitsfilter fuer den Block 'Shield' in SK_x14 (extrinsisch aufgerufen).
%   y = ext_x1_4_sim_shield(cmd, obs, theta, alpha)
%   ext_x1_4_sim_shield('reset')     Filter und Zaehler neu anlegen (vor jeder Episode)
%   c = ext_x1_4_sim_shield('count') [Anzahl Schritte, davon korrigiert]
%
%   Derselbe Filter wie in ext_kinsim (ext_x1_shield nach der Kette, Nominalmodell, Gelenkgrenzen 0,9774 rad/s).
%   q = obs(13:19), e_ori = obs(27:29) aus dem selben Agentenschritt.

persistent hook key
if ischar(cmd)
    switch cmd
        case 'reset', hook = []; key = [];
        case 'count'
            y = [0 0];
            if ~isempty(hook), y = hook('count'); end
    end
    return
end
k = [theta alpha];
if isempty(hook) || ~isequal(key, k)
    hook = ext_x1_shield('theta', theta, 'alpha', alpha, 'K', ext_kin_model(), 'lim', [0.9774 0.9774 0.9774]);
    key = k;
end
obs = double(obs(:));
S = struct('q', obs(13:19), 'ori', obs(27:29));
y = hook(double(cmd(:)), S);
end
