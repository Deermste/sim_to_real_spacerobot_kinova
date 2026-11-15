function [C, K, qHw] = ext_x7sp_setup(what)
%EXT_X7SP_SETUP  Gemeinsame Einstellungen fuer X7-SP (Residual RL am Set-Point, 15.11.2026).
%   [C, K, qHw] = ext_x7sp_setup()    Kette chain_step mit a_max 1 / 10 rad/s^2 (Gen3-Handbuch r9.1, Tabelle 44,
%                                     E18), a_brake 0,8 a_max, Nominalmodell mit Werkzeugpunkt 0,121 m,
%                                     Winkelgrenzen der Strecke (Datenblatt, Inf durch 2 pi ersetzt)
%   s = ext_x7sp_setup('noise')       realistische Messfehler je Kanal wie ext_x2_robust (29x1)

if nargin == 1 && strcmp(what, 'noise')
    C = [1e-3 * ones(3, 1); 5e-3 * ones(3, 1); 1e-3 * ones(3, 1); 1e-3 * ones(3, 1); 1e-3 * ones(7, 1); ...
         5e-3 * ones(7, 1); 1e-3 * ones(3, 1)];
    return
end
C = chain_step('params');
C.a_max = [1; 1; 1; 1; 10; 10; 10];
C.a_brake = 0.8 * C.a_max;
K = ext_kin_model('tool_offset', [0; 0; 0.121]);
qHw = min(C.q_lim, 2 * pi);
end
