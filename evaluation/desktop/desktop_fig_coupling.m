function T = desktop_fig_coupling(logFile, tag)
%DESKTOP_FIG_COUPLING  Arm und Basis am Anfang und Ende eines eingespielten Hardware-Laufs (Abbildung fig:coupling).
%   T = desktop_fig_coupling(logFile, tag)
%
%   Die gemessene Gelenkbahn log.q eines Kampagnenlaufs wird wie in D15/D19 in die Kinematik des frei schwebenden
%   Systems eingespielt (Impulserhalt, Anfangsimpuls null, Basis 65 kg). Mitgerechnet wird jetzt auch die Lage
%   der Basis (Position und Drehung). Ausgegeben werden fuer Anfang und Ende die Ursprünge aller Arm-Koerper,
%   die acht Ecken des Basiswuerfels (1 m) und die Endeffektor-Bahn, alles im Inertialsystem.
%   Ergebnis: data/simulation/desktop/FIG_coupling_<tag>.csv (Punkte) und _path.csv (Endeffektor-Bahn)

setup_project;
robot = importrobot(sk_path('robot', 'SpaceKinova.urdf'), 'DataFormat', 'column');
m0 = 65;
I0 = 10.833 * eye(3);
ee = 'kinova_end_effector_link';
S = load(logFile, 'run');
L = S.run.log;
n = S.run.meta.nSteps;
t = L.t_wall(1:n);
q = L.q(1:n, :);

R0 = eye(3); p0 = zeros(3, 1);
P = zeros(n, 3); ang = zeros(n, 1);
pose = cell(n, 1);
for k = 1:n
    [G, ~, peB] = desktop_freefloat(robot, q(k, :).', m0, I0, ee);
    P(k, :) = (p0 + R0 * peB).';
    ang(k) = norm(rotvecOf(R0));
    pose{k} = {R0, p0};
    if k == n, break; end
    h = t(k + 1) - t(k);
    tw = G * ((q(k + 1, :) - q(k, :)).' / h);
    p0 = p0 + R0 * tw(1:3) * h;
    R0 = R0 * expm(skew(tw(4:6) * h));
end

bodies = ['base_link', cellfun(@(b) b.Name, robot.Bodies, 'UniformOutput', false)];
keep = startsWith(bodies, 'kinova_') & ~contains(bodies, 'camera');
bodies = [{'base_link'}, bodies(keep)];
[cx, cy, cz] = ndgrid([-0.5 0.5], [-0.5 0.5], [-0.5 0.5]);
corners = [cx(:) cy(:) cz(:)].';
rows = {};
for ph = {'start', 'end'}
    k = 1; if strcmp(ph{1}, 'end'), k = n; end
    Rb = pose{k}{1}; pb = pose{k}{2};
    for i = 2:numel(bodies)
        Tb = getTransform(robot, q(k, :).', bodies{i});
        p = pb + Rb * Tb(1:3, 4);
        rows{end + 1} = {ph{1}, bodies{i}, p(1), p(2), p(3)}; %#ok<AGROW>
    end
    c = pb + Rb * corners;
    for j = 1:8
        rows{end + 1} = {ph{1}, sprintf('corner%d', j), c(1, j), c(2, j), c(3, j)}; %#ok<AGROW>
    end
end
T = cell2table(vertcat(rows{:}), 'VariableNames', {'phase', 'point', 'x', 'y', 'z'});
out = sk_path('data', 'simulation', 'desktop', ['FIG_coupling_' tag]);
writetable(T, [out '.csv']);
writetable(table(t - t(1), P(:, 1), P(:, 2), P(:, 3), ang, 'VariableNames', {'t', 'x', 'y', 'z', 'ori'}), ...
    [out '_path.csv']);
fprintf('%s: %d Schritte, Basisdrehung max %.4f rad, Ende %.4f rad, Basisverschiebung %.4f m\n', tag, n, ...
    max(ang), ang(end), norm(pose{n}{2}));
end

function v = rotvecOf(R)
a = rotm2axang(R);
v = a(1:3).' * a(4);
end

function S = skew(v)
S = [0 -v(3) v(2); v(3) 0 -v(1); -v(2) v(1) 0];
end
