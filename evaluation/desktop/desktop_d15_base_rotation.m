function [V, R] = desktop_d15_base_rotation(dt)
%DESKTOP_D15_BASE_ROTATION  Wie weit muss sich die Basis drehen, wenn der Endeffektor dem Halbkreis folgt? (D15, A51)
%   [V, R] = desktop_d15_base_rotation()        Schrittweite 10 ms fuer die Bahnrechnung
%   [V, R] = desktop_d15_base_rotation(0.005)
%
%   Kinematik des frei schwebenden Systems mit Impulserhaltung (Anfangsimpuls null, keine Schwerkraft wie im
%   Modell). Aus der URDF robot/SpaceKinova.urdf (Basis 65 kg, Traegheit 10,833 kg m^2, Arm 0,5 m ueber dem
%   Basis-Schwerpunkt) folgt die verallgemeinerte Jacobi-Matrix (Umetani und Yoshida): Basis-Twist
%   [v0; w0] = G(q) qd und Endeffektor-Geschwindigkeit v_e = Je(q) qd.
%
%   1. Validierung: Die geloggte Gelenkbahn einer Simscape-Episode (fruehes PPO und Optimized, deterministisch,
%      SK_desktop, 65 kg) wird eingespielt. Verglichen werden Basisdrehung und Endeffektor-Bahn.
%   2. Bahnrechnung: Der Endeffektor folgt dem Halbkreis (8,5 s, Referenz nach Zeit, P-Rueckfuehrung 5 1/s).
%      Pro Schritt wird zuerst der Bahnfehler unter den Gelenkgrenzen minimiert, dann unter Beibehaltung dieser
%      Endeffektor-Geschwindigkeit die Basis-Winkelgeschwindigkeit (optional mit Rueckfuehrung der
%      Basisdrehung). Das ist eine schrittweise (gierige) Loesung, also eine obere Schranke fuer die kleinste
%      moegliche Drehung, kein globales Optimum.
%      Die Gelenkwinkel bleiben in den Grenzen des Trainingsmodells (J2 2,41, J4 2,66, J5 2,23, J6 2,01 rad).
%      Faelle: J2/J4/J6 mit den Trainingsgrenzen (0,9774 / 0,9774 / 0,1 rad/s), J2/J4/J6 ohne die J6-Grenze,
%      beide auch mit der Beschleunigungsgrenze des Rate Limiters (0,5 rad/s^2), und alle 7 Gelenke
%      (0,98 rad/s J1-J4, 0,58 rad/s J5-J7, wie beim Set-Point-Task).
%   Ergebnis: data/simulation/desktop/D15_base_rotation_<Zeit>.csv (Bahnrechnung) und _validation.csv

if nargin < 1, dt = 0.01; end
setup_project;
robot = importrobot(sk_path('robot', 'SpaceKinova.urdf'), 'DataFormat', 'column');
m0 = 65;
I0 = 10.833 * eye(3);
ee = 'kinova_end_effector_link';
checkInertiaConvention(robot);

%% 1. Validierung gegen Simscape
desktop_build_model();
cp = sk_path('SavedAgents', 'MotionProfile', 'Circle', 'PPO');
val = {'PPO_base', fullfile(cp, 'SpaceKinova_PPO_agent_motionprofile.mat'); 'Optimized', fullfile(cp, 'Optimized.mat')};
V = table();
for a = 1:size(val, 1)
    r = desktop_run_episode(desktop_config('agentFile', val{a, 2}, 'agentLabel', val{a, 1}));
    t = r.ts.t_q_cmd;
    q = r.ts.q_cmd;
    [ang, pe] = replay(robot, m0, I0, ee, t, q);
    angSim = interp1(r.ts.t_ori, r.ts.ori, t, 'linear', 'extrap');
    cfg = desktop_config();
    pRef = refPos(t, cfg);
    peSim = pRef + interp1(r.ts.t_ee, r.ts.ep, t, 'linear', 'extrap');
    V = [V; table(string(val{a, 1}), max(angSim), max(ang), max(abs(ang - angSim)), ...
        max(vecnorm(pe - peSim, 2, 2)), 'VariableNames', ...
        {'agent', 'ori_max_sim', 'ori_max_model', 'ori_diff_max', 'ee_diff_max_m'})]; %#ok<AGROW>
end
disp(V);

%% 2. Bahnrechnung mit minimaler Basisdrehung
lim7 = [0.98 0.98 0.98 0.98 0.58 0.58 0.58];
cases = {
    'J246_train',        [2 4 6],  [0.9774 0.9774 0.1],   Inf
    'J246_train_acc',    [2 4 6],  [0.9774 0.9774 0.1],   0.5
    'J246_noJ6cap',      [2 4 6],  [0.9774 0.9774 0.9774], Inf
    'J246_noJ6cap_acc',  [2 4 6],  [0.9774 0.9774 0.9774], 0.5
    'all7',              1:7,      lim7,                   Inf
    };
methods = {'track_only', 0, false; 'min_rot', 0, true; 'min_rot_reg', 2, true};
rows = {};
for c = 1:size(cases, 1)
    for mth = 1:size(methods, 1)
        s = simulateTracking(robot, m0, I0, ee, dt, cases{c, 2}, cases{c, 3}, cases{c, 4}, ...
            methods{mth, 3}, methods{mth, 2});
        s.case = string(cases{c, 1});
        s.method = string(methods{mth, 1});
        rows{end + 1} = s; %#ok<AGROW>
        fprintf('%-18s %-12s  Basis max %.4f rad (Ende %.4f)  EE max %.4f m, letztes Viertel %.4f m  |qd|max %s\n', ...
            cases{c, 1}, methods{mth, 1}, s.ori_max, s.ori_end, s.ee_max, s.ee_q4, mat2str(round(s.qd_absmax, 3)));
    end
end
R = struct2table([rows{:}]);
R = movevars(R, {'case', 'method'}, 'Before', 1);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
out = sk_path('data', 'simulation', 'desktop', ['D15_base_rotation_' stamp]);
writetable(R, [out '.csv']);
writetable(V, [out '_validation.csv']);
fprintf('Ergebnis: %s.csv\n', out);
end

% =====================================================================
function s = simulateTracking(robot, m0, I0, ee, dt, idx, lim, amax, minRot, kOri)
% Endeffektor folgt dem Halbkreis. Pro Schritt: (1) Bahnfehler minimieren unter Gelenkgrenzen,
% (2) bei gleicher Endeffektor-Geschwindigkeit die Basis-Winkelgeschwindigkeit minimieren (minRot).
Q_LIM = [2*pi; 2.41; 2*pi; 2.66; 2.23; 2.01; 2*pi];   % wie qLim in desktop_run_episode (Training)
cfg = desktop_config();
T = cfg.T;
t = (0:dt:T)';
n = numel(t);
q = zeros(7, 1);
qdPrev = zeros(7, 1);
R0 = eye(3);
p0 = zeros(3, 1);
if numel(idx) == 3
    S = [1 0 0; 0 0 1];                % ebene Aufgabe (x, z), die Gelenke J2/J4/J6 bewegen den Arm in der x-z-Ebene
else
    S = eye(3);
end
opts = optimoptions('lsqlin', 'Display', 'off', 'Algorithm', 'interior-point');
na = numel(idx);
lo = -lim(:); hi = lim(:);
ang = zeros(n, 1); err = zeros(n, 1); Q = zeros(n, 7); QD = zeros(n, 7);
for k = 1:n
    [G, Je, pe] = desktop_freefloat(robot, q, m0, I0, ee);
    peW = p0 + R0 * pe;
    [pr, vr] = refPos(t(k), cfg);
    e = pr(:) - peW;
    err(k) = norm(e);
    rv = rotvecOf(R0);
    ang(k) = norm(rv);
    Q(k, :) = q.';
    if k == n, break; end
    b = S * (vr(:) + 5 * e);
    A = S * R0 * Je(:, idx);
    W = R0 * G(4:6, idx);
    l = lo; u = hi;
    if isfinite(amax)
        l = max(lo, qdPrev(idx) - amax * dt);
        u = min(hi, qdPrev(idx) + amax * dt);
    end
    % Gelenkwinkel-Grenzen des Trainingsmodells (Saturation hinter dem Integrator) nicht ueberschreiten
    l = max(l, (-Q_LIM(idx) - q(idx)) / dt);
    u = min(u, (Q_LIM(idx) - q(idx)) / dt);
    u = max(u, l);
    % (1) Bahnfehler minimieren, kleine Regularisierung fuer eine eindeutige Loesung
    x1 = lsqlin([A; 1e-3 * eye(na)], [b; zeros(na, 1)], [], [], [], [], l, u, [], opts);
    x = x1;
    if minRot
        % (2) gleiche Endeffektor-Geschwindigkeit, Basis-Winkelgeschwindigkeit minimieren (bzw. Drehung zurueckfuehren)
        wDes = -kOri * rv;
        try
            x2 = lsqlin([W; 1e-3 * eye(na)], [wDes; zeros(na, 1)], [], [], A, A * x1, l, u, [], opts);
            if all(isfinite(x2)), x = x2; end
        catch
        end
    end
    qd = zeros(7, 1);
    qd(idx) = x;
    QD(k, :) = qd.';
    tw = G * qd;                        % Basis-Twist im Basis-Koordinatensystem [v0; w0]
    p0 = p0 + R0 * tw(1:3) * dt;
    R0 = R0 * expm(skew(tw(4:6) * dt));
    q = q + qd * dt;
    qdPrev = qd;
end
T4 = t >= 3 * T / 4;
qdd = diff(QD(1:end - 1, :)) / dt;
s = struct('ori_max', max(ang), 'ori_end', ang(end), 'ee_max', max(err), 'ee_q4', mean(err(T4)), ...
    'qd_absmax', max(abs(QD(:, idx))), 'qdd_absmax', max(abs(qdd(:, idx)), [], 'all'), ...
    'q_min', min(Q(:, idx)), 'q_max', max(Q(:, idx)), ...
    'frac_at_vlim', mean(any(abs(QD(1:end - 1, idx)) >= lim(:).' - 1e-6, 2)));
end

function [ang, pe] = replay(robot, m0, I0, ee, t, q)
% Geloggte Gelenkbahn einspielen, Basis aus dem Impulserhalt integrieren
n = numel(t);
R0 = eye(3); p0 = zeros(3, 1);
ang = zeros(n, 1); pe = zeros(n, 3);
for k = 1:n
    [G, ~, peB] = desktop_freefloat(robot, q(k, :).', m0, I0, ee);
    pe(k, :) = (p0 + R0 * peB).';
    ang(k) = norm(rotvecOf(R0));
    if k == n, break; end
    h = t(k + 1) - t(k);
    qd = (q(k + 1, :) - q(k, :)).' / h;
    tw = G * qd;
    p0 = p0 + R0 * tw(1:3) * h;
    R0 = R0 * expm(skew(tw(4:6) * h));
end
end

function checkInertiaConvention(robot)
% importrobot legt die Traegheit um den Koerper-Ursprung ab. Pruefung an kinova_base_link (URDF: Traegheit um
% den Schwerpunkt ixx = 0,004622, Schwerpunkt [-0,000648 -0,000166 0,084487], Masse 1,697)
b = getBody(robot, 'kinova_base_link');
c = [-0.000648 -0.000166 0.084487];
ixxOrigin = 0.004622 + 1.697 * (c(2)^2 + c(3)^2);
assert(abs(b.Inertia(1) - ixxOrigin) < 1e-5, 'desktop_d15:inertia', ...
    'Traegheits-Konvention unerwartet: %.6f statt %.6f', b.Inertia(1), ixxOrigin);
end

function [p, v] = refPos(t, cfg)
% Halbkreis nach Zeit wie desktop_run_episode (Start oben, Richtung +x, Ende unten)
t = t(:);
w = pi / cfg.T_path;
p = [cfg.center(1) + cfg.r * sin(w * t), cfg.center(2) + 0 * t, cfg.center(3) + cfg.r * cos(w * t)];
v = [cfg.r * w * cos(w * t), 0 * t, -cfg.r * w * sin(w * t)];
end

function v = rotvecOf(R)
a = rotm2axang(R);
v = a(1:3).' * a(4);
end

function S = skew(v)
S = [0 -v(3) v(2); v(3) 0 -v(1); -v(2) v(1) 0];
end
