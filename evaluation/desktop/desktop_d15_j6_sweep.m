function S = desktop_d15_j6_sweep(dt)
%DESKTOP_D15_J6_SWEEP  Kleinste Basisdrehung bei exakter Bahn mit J2/J4/J6 und J6 <= 0,1 rad/s (D15, A51).
%   S = desktop_d15_j6_sweep()        Schrittweite 40 ms
%
%   Mit J2, J4 und J6 und der ebenen Aufgabe (x, z) bleibt bei exakter Bahn genau ein Freiheitsgrad, die
%   Geschwindigkeit u(t) von J6. J2 und J4 folgen dann eindeutig aus der Bahn (mit Basisbewegung, P-Rueckfuehrung
%   5 1/s). Die schrittweise Rechnung in desktop_d15_base_rotation liefert nur eine obere Schranke. Hier werden
%   J6-Profile mit einem Umschaltpunkt durchsucht: u = s1 * 0,1 rad/s bis ts, danach s2 * 0,1 rad/s,
%   s1, s2 in {-1, 0, 1}, ts in 0:1:8 s. J2 und J4 werden mit gedaempften kleinsten Quadraten
%   bestimmt und auf 0,9774 rad/s begrenzt. Zulaessig ist ein Profil, wenn die Gelenke in den Winkelgrenzen des
%   Trainingsmodells bleiben und der Bahnfehler unter 5 mm bleibt (nach der ersten Sekunde, Start singulaer).
%   Ergebnis: data/simulation/desktop/D15_j6_sweep_<Zeit>.csv

if nargin < 1, dt = 0.04; end
setup_project;
robot = importrobot(sk_path('robot', 'SpaceKinova.urdf'), 'DataFormat', 'column');
m0 = 65; I0 = 10.833 * eye(3); ee = 'kinova_end_effector_link';
cfg = desktop_config();
umax = 0.1; vlim = 0.9774;
qLim = [2*pi; 2.41; 2*pi; 2.66; 2.23; 2.01; 2*pi];

rows = {};
for s1 = [-1 0 1]
    for s2 = [-1 0 1]
        for ts = 0:1:cfg.T
            if (ts == 0 && s1 ~= 0) || (ts == cfg.T && s2 ~= 0), continue; end   % doppelte Profile auslassen
            r = simProfile(robot, m0, I0, ee, cfg, dt, @(t) umax * (s1 * (t < ts) + s2 * (t >= ts)), vlim, qLim);
            r.s1 = s1; r.s2 = s2; r.ts = ts;
            rows{end + 1} = r; %#ok<AGROW>
        end
    end
end
S = struct2table([rows{:}]);
S = movevars(S, {'s1', 's2', 'ts'}, 'Before', 1);
S.feasible = S.qlim_ok & S.ee_max_after1s < 0.005;
S = sortrows(S, 'ori_max');
disp(S(1:min(12, height(S)), :));
F = S(S.feasible, :);
if ~isempty(F)
    fprintf('Kleinste Basisdrehung (zulaessig): %.4f rad bei s1 = %d, s2 = %d, ts = %.1f s, EE max %.4f m\n', ...
        F.ori_max(1), F.s1(1), F.s2(1), F.ts(1), F.ee_max(1));
end
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
out = sk_path('data', 'simulation', 'desktop', ['D15_j6_sweep_' stamp '.csv']);
writetable(S, out);
fprintf('Ergebnis: %s\n', out);
end

function r = simProfile(robot, m0, I0, ee, cfg, dt, uFun, vlim, qLim)
t = (0:dt:cfg.T)';
n = numel(t);
q = zeros(7, 1); R0 = eye(3); p0 = zeros(3, 1);
Sel = [1 0 0; 0 0 1];
w = pi / cfg.T_path;
ang = zeros(n, 1); err = zeros(n, 1); v24 = 0; qok = true;
for k = 1:n
    [G, Je, pe] = desktop_freefloat(robot, q, m0, I0, ee);
    pr = [cfg.center(1) + cfg.r * sin(w * t(k)); cfg.center(2); cfg.center(3) + cfg.r * cos(w * t(k))];
    vr = [cfg.r * w * cos(w * t(k)); 0; -cfg.r * w * sin(w * t(k))];
    e = pr - (p0 + R0 * pe);
    err(k) = norm(e);
    a = rotm2axang(R0);
    ang(k) = abs(a(4));
    if k == n, break; end
    u = uFun(t(k));
    A = Sel * R0 * Je(:, [2 4]);
    c = Sel * R0 * Je(:, 6);
    % gedaempfte kleinste Quadrate (Start in der gestreckten, singulaeren Pose), dann auf die Grenze begrenzt
    rhs = Sel * (vr + 5 * e) - c * u;
    x = (A.' * A + 1e-4 * eye(2)) \ (A.' * rhs);
    v24 = max(v24, max(abs(x)));
    x = max(min(x, vlim), -vlim);
    qd = zeros(7, 1); qd([2 4]) = x; qd(6) = u;
    tw = G * qd;
    p0 = p0 + R0 * tw(1:3) * dt;
    R0 = R0 * expm(skew(tw(4:6) * dt));
    q = q + qd * dt;
    qok = qok && all(abs(q) <= qLim);
end
T4 = t >= 3 * cfg.T / 4;
r = struct('ori_max', max(ang), 'ori_end', ang(end), 'ee_max', max(err), 'ee_max_after1s', max(err(t >= 1)), ...
    'ee_q4', mean(err(T4)), ...
    'v24_max', v24, 'qlim_ok', qok, 'q6_end', q(6));
end

function S = skew(v)
S = [0 -v(3) v(2); v(3) 0 -v(1); -v(2) v(1) 0];
end
