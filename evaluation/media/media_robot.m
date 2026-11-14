function out = media_robot(mode, varargin)
%MEDIA_ROBOT  Zeichnet SpaceKinova (Gen3 auf frei schwebendem Wuerfel) mit den URDF-Meshes, fuer Bilder und Videos.
%   M = media_robot('load')                          Baum, Meshes (aus robot/SpaceKinova.urdf), Linknamen
%   H = media_robot('draw', M, ax, style)            Patches unter hgtransforms anlegen, H = Handles
%   media_robot('update', M, H, q, pb, quat)         Lage setzen: q (7x1), pb (3x1 Basisursprung in Welt),
%                                                    quat (4x1 [w x y z], Basis -> Welt)
%   style: Struct mit Feldern (alle optional)
%     armColor [0.62 0.66 0.72], armAlpha 1, baseColor [0.85 0.87 0.9], baseAlpha 0.35, baseEdge [0.35 0.38 0.42],
%     showBase true, reduce 0.5 (Anteil der Dreiecke, reducepatch)
%   Die Basis ist der Wuerfel aus der URDF (1 m, Ursprung = Schwerpunkt), der Arm sitzt auf der Oberseite.
%   Die Lage kommt aus ext_kinsim (res.ts.pb, res.ts.quat), dieselbe Kinematik wie im Simulator.

switch mode
    case 'load'
        out = loadRobot();
    case 'draw'
        out = drawRobot(varargin{:});
    case 'update'
        updateRobot(varargin{:});
        out = [];
    otherwise
        error('media_robot:mode', 'Modus load, draw oder update');
end
end

% =====================================================================
function M = loadRobot()
root = sk_path();
urdf = fullfile(root, 'robot', 'SpaceKinova.urdf');
robot = importrobot(urdf, 'DataFormat', 'column');
txt = fileread(urdf);
% je Link der erste visual-Block mit Mesh (Ursprung der Visuals ist in dieser URDF ueberall null)
blk = regexp(txt, '<link name="([^"]+)">(.*?)</link>', 'tokens');
M = struct('robot', robot, 'names', {{}}, 'F', {{}}, 'V', {{}});
for i = 1:numel(blk)
    vis = regexp(blk{i}{2}, '<visual>.*?<mesh filename="([^"]+)"', 'tokens', 'once');
    if isempty(vis), continue; end
    org = regexp(blk{i}{2}, '<visual>\s*<origin xyz="([^"]+)" rpy="([^"]+)"', 'tokens', 'once');
    if ~isempty(org)
        assert(all(str2num(org{1}) == 0) && all(str2num(org{2}) == 0), 'media_robot:origin', ... %#ok<ST2NM>
               'Visual-Ursprung ungleich null bei %s', blk{i}{1});
    end
    tr = stlread(fullfile(root, vis{1}));
    M.names{end + 1} = blk{i}{1};
    M.F{end + 1} = tr.ConnectivityList;
    M.V{end + 1} = tr.Points;
end
assert(numel(M.names) == 8, 'media_robot:links', 'erwartet 8 Arm-Links mit Mesh, gefunden %d', numel(M.names));
end

function H = drawRobot(M, ax, style)
if nargin < 3, style = struct(); end
d = struct('armColor', [0.62 0.66 0.72], 'armAlpha', 1, 'baseColor', [0.85 0.87 0.9], 'baseAlpha', 0.35, ...
           'baseEdge', [0.35 0.38 0.42], 'showBase', true, 'reduce', 0.5);
fn = fieldnames(style);
for k = 1:numel(fn), d.(fn{k}) = style.(fn{k}); end
H.world = hgtransform('Parent', ax);
H.links = gobjects(numel(M.names), 1);
for i = 1:numel(M.names)
    H.links(i) = hgtransform('Parent', H.world);
    [f, v] = deal(M.F{i}, M.V{i});
    if d.reduce < 1, [f, v] = reducepatch(f, v, d.reduce); end
    patch('Faces', f, 'Vertices', v, 'Parent', H.links(i), 'FaceColor', d.armColor, 'EdgeColor', 'none', ...
          'FaceAlpha', d.armAlpha, 'FaceLighting', 'gouraud', 'AmbientStrength', 0.45, 'DiffuseStrength', 0.7, ...
          'SpecularStrength', 0.25);
end
if d.showBase
    [cf, cv] = cube(1);
    patch('Faces', cf, 'Vertices', cv, 'Parent', H.world, 'FaceColor', d.baseColor, 'FaceAlpha', d.baseAlpha, ...
          'EdgeColor', d.baseEdge, 'LineWidth', 1.2, 'FaceLighting', 'flat');
end
end

function updateRobot(M, H, q, pb, quat)
Tw = [q2r(quat), pb(:); 0 0 0 1];
H.world.Matrix = Tw;
for i = 1:numel(M.names)
    H.links(i).Matrix = getTransform(M.robot, q(:), M.names{i});
end
end

function [f, v] = cube(s)
v = s / 2 * [-1 -1 -1; 1 -1 -1; 1 1 -1; -1 1 -1; -1 -1 1; 1 -1 1; 1 1 1; -1 1 1];
f = [1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8];
end

function R = q2r(qt)
w = qt(1); x = qt(2); y = qt(3); z = qt(4);
R = [1 - 2*(y^2 + z^2), 2*(x*y - z*w),     2*(x*z + y*w);
     2*(x*y + z*w),     1 - 2*(x^2 + z^2), 2*(y*z - x*w);
     2*(x*z - y*w),     2*(y*z + x*w),     1 - 2*(x^2 + y^2)];
end
