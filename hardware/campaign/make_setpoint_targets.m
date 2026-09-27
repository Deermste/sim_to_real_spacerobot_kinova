function T = make_setpoint_targets(varargin)
%MAKE_SETPOINT_TARGETS  Feste Zielliste fuer die zweite Set-Point-Reihe (Labortag 2, A57).
%
%   T = MAKE_SETPOINT_TARGETS() berechnet die Liste und speichert sie in
%   hardware/campaign/setpoint_targets.mat und .csv.
%   T = MAKE_SETPOINT_TARGETS('save', false) berechnet nur.
%
%   Die Ziele liegen fest um das nominale Trainingsziel N = [0.479 -0.005 0.636] m
%   (Kortex-Frame, Flanschpunkt kinova_end_effector_link ohne Greifer). Sie sind nach
%   einer Regel gewaehlt, nicht nach dem Ergebnis des Agenten:
%     T01 bis T06  im Zielbereich des ROS-Plugins (0.10 bis 0.30 m um N, mindestens
%                  0.22 m ueber der Montageflaeche): je eine Achsrichtung, 0.15 m
%                  seitlich und nach unten, 0.25 m nach vorn, hinten und oben
%     E01 bis E03  am Rand (0.40 m): links, rechts, schraeg vorn-unten (hinten-unten
%                  hat keine sichere Pruefpose, zu nah am Sockel)
%   Jedes Ziel braucht eine Pruefpose (IK-Loesung nahe am Anker, innerhalb der Grenzen,
%   kollisionsfrei, Hoehe und Singularitaet wie make_setpoint_starts). Die Pruefpose
%   dient nur dem Anfahrtest im Labor (check_setpoint_starts('list', 'targets')). Der
%   Agent waehlt seine Endkonfiguration selbst.
%
%   Hindernisse der Zelle kennt das Skript nicht. Jede Zielpose muss vor der Reihe im
%   Labor angefahren und freigegeben werden.

p = inputParser;
p.addParameter('save', true);
p.addParameter('marginDeg', 10);
p.addParameter('zMin', 0.15);
p.addParameter('sigmaMin', 0.05);
p.addParameter('seed', 2027);
p.parse(varargin{:});
o = p.Results;

rbt = importrobot(sk_path('robot', 'SpaceKinova.urdf'));
rbt.DataFormat = 'row';
ee = 'kinova_end_effector_link';
F = kortex_frames(rbt);
anchor = deg2rad([0 15 180 -130 0 55 90]);
qLimDeploy = [2*pi 2.41 2*pi 2.66 2.23 2.01 2*pi];
qLimHw     = deg2rad([inf 128.9 inf 147.8 inf 120.3 inf]);
qLim = min(qLimDeploy, qLimHw);
cont = logical([1 0 1 0 0 0 1]);
qLo = -qLim + deg2rad(o.marginDeg);  qHi = qLim - deg2rad(o.marginDeg);
qLo(cont) = anchor(cont) - deg2rad(170);  qHi(cont) = anchor(cont) + deg2rad(170);

N = [0.479 -0.005 0.636];                    % Kortex-Frame
def = { ...
    'T01', 'plugin', [0  1  0], 0.15; ...
    'T02', 'plugin', [0 -1  0], 0.15; ...
    'T03', 'plugin', [0  0 -1], 0.15; ...
    'T04', 'plugin', [1  0  0], 0.25; ...
    'T05', 'plugin', [-1 0  0], 0.25; ...
    'T06', 'plugin', [0  0  1], 0.25; ...
    'E01', 'edge',   [0  1  0], 0.40; ...
    'E02', 'edge',   [0 -1  0], 0.40; ...
    'E03', 'edge',   [1 0 -1] / sqrt(2), 0.40};

L0 = load(sk_path('hardware', 'campaign', 'setpoint_starts.mat'));
starts = L0.S.starts;

rng(o.seed, 'twister');
ik = inverseKinematics('RigidBodyTree', rbt);
lim = zeros(7, 2);
for i = 1:7
    lim(i, :) = rbt.Bodies{i + 1}.Joint.PositionLimits;
end
targets = struct('id', {}, 'group', {}, 'dist_m', {}, 'dir', {}, 'ee_real', {}, 'ee_urdf', {}, ...
                 'height_m', {}, 'q_check_deg', {}, 'checkOk', {}, 'maxDevAnchor_deg', {}, ...
                 'minHeight_m', {}, 'sigmaMin', {}, 'd0_from_starts_m', {});
for k = 1:size(def, 1)
    pReal = N + def{k, 4} * def{k, 3};
    pUrdf = to_urdf(F, pReal);
    best = inf; qBest = [];
    for i = 1:300
        seed = min(max(anchor + deg2rad(30) * randn(1, 7), lim(:, 1).'), lim(:, 2).');
        [qs, info] = ik(ee, [eye(3) pUrdf.'; 0 0 0 1], [0 0 0 1 1 1], seed);
        Tq = getTransform(rbt, qs, ee);
        if norm(Tq(1:3, 4).' - pUrdf) > 1e-3 || ~strcmp(info.Status, 'success'), continue; end
        qs = unwrap_to(qs, anchor);
        if any(qs < qLo | qs > qHi), continue; end
        if ~pose_ok(rbt, qs, F, o) || ~path_ok(rbt, anchor, qs, F, o), continue; end
        dev = max(abs(rad2deg(qs - anchor)));
        if dev < best, best = dev; qBest = qs; end
    end
    d0 = arrayfun(@(s) norm(s.ee_urdf - pUrdf), starts);
    t = struct('id', def{k, 1}, 'group', def{k, 2}, 'dist_m', def{k, 4}, 'dir', def{k, 3}, ...
               'ee_real', pReal, 'ee_urdf', pUrdf, 'height_m', pReal(3), 'q_check_deg', nan(1, 7), ...
               'checkOk', false, 'maxDevAnchor_deg', NaN, 'minHeight_m', NaN, 'sigmaMin', NaN, ...
               'd0_from_starts_m', d0(:).');
    if ~isempty(qBest)
        J = geometricJacobian(rbt, qBest, ee);
        [~, zmin] = heights_ok(rbt, qBest, F, -inf);
        t.q_check_deg = rad2deg(qBest); t.checkOk = true; t.maxDevAnchor_deg = best;
        t.minHeight_m = zmin; t.sigmaMin = min(svd(J(4:6, :)));
    else
        warning('make_setpoint_targets:ik', 'Ziel %s: keine gueltige Pruefpose gefunden.', def{k, 1});
    end
    targets(end + 1) = t; %#ok<AGROW>
end

T = struct();
T.schema = 'sk_setpoint_targets_v1';
env = campaign_env_meta();
T.meta = struct('generator', 'make_setpoint_targets.m', ...
                'datetime', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), 'params', o, ...
                'nominal_real', N, 'startIds', {{starts.id}}, 'gitHash', env.gitHash, 'gitDirty', env.gitDirty);
T.targets = targets;

fprintf('\n%-4s %-6s %5s  %-24s %6s %5s %6s %6s   d0 von S00/S06/S07 [m]\n', 'ID', 'Gruppe', 'Abst', ...
        'Kortex [m]', 'Hoehe', 'Pose', 'maxDev', 'sMin');
iS = cellfun(@(id) find(strcmp({starts.id}, id)), {'S00', 'S06', 'S07'});
for k = 1:numel(targets)
    t = targets(k);
    fprintf('%-4s %-6s %5.2f  %-24s %6.3f %5d %6.1f %6.3f   %s\n', t.id, t.group, t.dist_m, ...
            mat2str(round(t.ee_real, 3)), t.height_m, t.checkOk, t.maxDevAnchor_deg, t.sigmaMin, ...
            mat2str(round(t.d0_from_starts_m(iS), 2)));
end

if o.save
    here = fileparts(mfilename('fullpath'));
    save(fullfile(here, 'setpoint_targets.mat'), 'T', '-v7');
    write_csv(fullfile(here, 'setpoint_targets.csv'), T);
    fprintf('Gespeichert: %s\n', fullfile(here, 'setpoint_targets.mat'));
end
end

%% ========================================================================
function q = unwrap_to(q, ref)
q = q + 2*pi * round((ref - q) / (2*pi));
end

function p = to_urdf(F, pReal)
v = F.T_urdf_from_real * [pReal(:); 1];
p = v(1:3).';
end

function [ok, zmin] = heights_ok(rbt, q, F, zMin)
zBase = F.T_urdf_from_real(3, 4);
Tw = getTransform(rbt, q, 'kinova_spherical_wrist_2_link');
Tf = getTransform(rbt, q, 'kinova_forearm_link');
Te = getTransform(rbt, q, 'kinova_end_effector_link');
pts = Te(1:3, 1:3) * F.gripperPoints + Te(1:3, 4);
z = [Tw(3, 4), Tf(3, 4), pts(3, :)] - zBase;
zmin = min(z);
ok = zmin >= zMin;
end

function ok = pose_ok(rbt, q, F, o)
ok = false;
if ~heights_ok(rbt, q, F, o.zMin), return; end
J = geometricJacobian(rbt, q, 'kinova_end_effector_link');
if min(svd(J(4:6, :))) < o.sigmaMin, return; end
if checkCollision(rbt, q, 'SkippedSelfCollisions', 'parent'), return; end
ok = true;
end

function ok = path_ok(rbt, qA, qB, F, o)
ok = false;
for s = linspace(0, 1, 11)
    q = qA + s * (qB - qA);
    if ~heights_ok(rbt, q, F, o.zMin), return; end
    if mod(round(s * 10), 2) == 0 && checkCollision(rbt, q, 'SkippedSelfCollisions', 'parent'), return; end
end
ok = true;
end

function write_csv(path, T)
fid = fopen(path, 'w');
c = onCleanup(@() fclose(fid));
fprintf(fid, '# Erzeugt von make_setpoint_targets.m am %s (Git %s). Nicht von Hand aendern.\n', ...
        T.meta.datetime, T.meta.gitHash);
fprintf(fid, '# Nominalziel Kortex-Frame [m]: %s. d0 in der Reihenfolge %s\n', mat2str(T.meta.nominal_real, 4), ...
        strjoin(T.meta.startIds, ' '));
fprintf(fid, 'id,group,dist_m,ee_real_x,ee_real_y,ee_real_z,ee_urdf_x,ee_urdf_y,ee_urdf_z,checkOk,');
fprintf(fid, 'q1_deg,q2_deg,q3_deg,q4_deg,q5_deg,q6_deg,q7_deg,maxDevAnchor_deg,minHeight_m,sigmaMin\n');
for k = 1:numel(T.targets)
    t = T.targets(k);
    fprintf(fid, '%s,%s,%.2f,%s,%s,%d,%s,%.1f,%.3f,%.3f\n', t.id, t.group, t.dist_m, ...
            strjoin(compose('%.4f', t.ee_real), ','), strjoin(compose('%.4f', t.ee_urdf), ','), t.checkOk, ...
            strjoin(compose('%.2f', t.q_check_deg), ','), t.maxDevAnchor_deg, t.minHeight_m, t.sigmaMin);
end
end
