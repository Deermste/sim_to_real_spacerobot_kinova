function [v, S, info] = chain_step(S, a, q)
%CHAIN_STEP  Befehlskette fuer X6 (Entwurf E18): eine Datei fuer Training, Regler und Deploy-Skript.
%   P = chain_step('params')                       Standardparameter (siehe unten)
%   S = chain_step('init', P)                      Zustand am Episodenstart (Befehl null)
%   [v, S, info] = chain_step(S, a, q)             ein Schritt: Aktion a (7x1, [-1, 1]), Gelenkwinkel q (7x1)
%
%   Stufen je Schritt (Ts = P.Ts, alle Groessen in Sekunden, unabhaengig von der Rate):
%     1 Skalierung      v* = clip(a, -1, 1) .* v_max. Mit P.tau > 0 zusaetzlich ein Filter erster Ordnung
%                       y = alpha y + (1 - alpha) v*, alpha = exp(-Ts / tau) (Pilotvariante, Standard tau = 0).
%     2 Bremskurve      Geschwindigkeit in Richtung einer Winkelgrenze hoechstens sqrt(2 a_brake d), d = Abstand
%                       bis zur Grenze minus q_margin. So kann das Gelenk mit a_brake < a_max vor der Grenze
%                       anhalten. Gilt fuer die Gelenke mit endlicher Grenze (q_lim < Inf).
%     3 Beschleunigung  v = v_prev + clip(v* - v_prev, -a_max Ts, a_max Ts)
%     4 HW-Cap          v = clip(v, -v_cap, v_cap). Mit v_max < v_cap greift er im Normalbetrieb nie.
%   v_prev ist der zuletzt gesendete Befehl (Ausgang von Stufe 4). Ausgang v in rad/s.
%   info: brake (7x1 logisch, Stufe 2 hat eingegriffen), accel (Stufe 3), cap (Stufe 4), v_star (nach Stufe 1).
%
%   Parameter (chain_step('params')):
%     Ts        0,05 s (20 Hz)
%     v_max     0,95 * v_cap
%     v_cap     0,75 * Datenblatt [1,3963 x4; 1,2218 x3] rad/s (wie safetyFactor in deploy_setpoint_v24)
%     a_max     2 rad/s^2 (Platzhalter bis zum Hardwarewert, E18)
%     a_brake   0,8 * a_max
%     q_lim     Winkelgrenzen laut Gen3-Datenblatt: J2 128,9, J4 147,8, J6 120,3 Grad, J1, J3, J5, J7 endlos (Inf).
%               Nicht die Modellwerte von SK_desktop (2,41 / 2,66 / 2,23 / 2,01 rad), die J2 und J4 zu weit fassen
%     q_margin  5 Grad (Abstand, bei dem das Gelenk spaetestens steht)
%     tau       0 (kein Filter)
%     active    true(7, 1) (inaktive Gelenke bekommen den Befehl null)

if ischar(S)
    switch S
        case 'params'
            dqData = [1.3963; 1.3963; 1.3963; 1.3963; 1.2218; 1.2218; 1.2218];
            P = struct('Ts', 0.05, 'v_cap', 0.75 * dqData, 'a_max', 2, 'q_margin', deg2rad(5), ...
                       'q_lim', deg2rad([Inf; 128.9; Inf; 147.8; Inf; 120.3; Inf]), 'tau', 0, 'active', true(7, 1));
            P.v_max = 0.95 * P.v_cap;
            P.a_brake = 0.8 * P.a_max;
            v = P;
        case 'init'
            P = a;
            assert(all(P.v_max <= P.v_cap + 1e-12), 'chain_step:vmax', 'v_max muss unter v_cap liegen');
            v = struct('P', P, 'v_prev', zeros(7, 1), 'y', zeros(7, 1), ...
                       'alpha', exp(-P.Ts / max(P.tau, eps)) * (P.tau > 0));
        otherwise
            error('chain_step:mode', 'Unbekannter Modus %s', S);
    end
    return
end

P = S.P;
a = min(max(a(:), -1), 1);
a(~P.active) = 0;
vs = a .* P.v_max;
if P.tau > 0
    S.y = S.alpha * S.y + (1 - S.alpha) * vs;
    vs = S.y;
end
vStar = vs;

% Stufe 2: Bremskurve vor den Winkelgrenzen
dUp = P.q_lim - P.q_margin - q(:);
dLo = q(:) + P.q_lim - P.q_margin;
vUp = sqrt(2 * P.a_brake * max(dUp, 0));
vLo = sqrt(2 * P.a_brake * max(dLo, 0));
fin = isfinite(P.q_lim);
brake = false(7, 1);
up = fin & vs > vUp;
lo = fin & vs < -vLo;
vs(up) = vUp(up); vs(lo) = -vLo(lo);
brake(up | lo) = true;

% Stufe 3: Beschleunigungsgrenze
dMax = P.a_max * P.Ts;
dv = vs - S.v_prev;
accel = abs(dv) > dMax + 1e-12;
v = S.v_prev + min(max(dv, -dMax), dMax);

% Stufe 4: HW-Cap
cap = abs(v) > P.v_cap + 1e-12;
v = min(max(v, -P.v_cap), P.v_cap);
v(~P.active) = 0;

S.v_prev = v;
info = struct('brake', brake, 'accel', accel, 'cap', cap, 'v_star', vStar);
end
