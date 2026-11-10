function traj = ext_ref_path(t, o)
%EXT_REF_PATH  Referenzbahn des Endeffektors im Weltsystem (Halbkreis, eben oder gekippt, Ausbau X5.1).
%   traj = ext_ref_path(t, o)      t Spaltenvektor [s], traj numel(t) x 3 [m]
%   o hat die Felder T, r, center und optional path ('planar' Standard, 'tilted') und tilt [Grad, Standard 30].
%
%   planar: wie desktop_run_episode, x = cx + r sin(w t), y = cy, z = cz + r cos(w t), w = pi / T. Start oben
%     (gestreckte Stellung bei q0 = 0), Ende unten.
%   tilted: dieselbe Bahn, die Ebene um 'tilt' um die x-Achse durch den Startpunkt gekippt. Startpunkt und
%     Anfangsrichtung (entlang x) bleiben gleich, die Bahn laeuft nach +y (tilt > 0) bzw. -y (tilt < 0) aus.
%     Mit tilt = 30 Grad endet sie 0,2 m neben und 0,346 m unter dem Start. Eine Drehung um die senkrechte Achse
%     waere keine echte 3D-Aufgabe, J1 allein koennte sie ausgleichen.

if ~isfield(o, 'path') || isempty(o.path), o.path = 'planar'; end
if ~isfield(o, 'tilt') || isempty(o.tilt), o.tilt = 30; end
t = t(:);
w = pi / o.T;
c = o.center(:).';
switch o.path
    case 'planar'
        traj = [c(1) + o.r * sin(w * t), c(2) + 0 * t, c(3) + o.r * cos(w * t)];
    case 'tilted'
        a = deg2rad(o.tilt);
        d1 = o.r * sin(w * t);
        d3 = o.r * (cos(w * t) - 1);            % relativ zum Startpunkt, <= 0
        traj = [c(1) + d1, c(2) - sin(a) * d3, c(3) + o.r + cos(a) * d3];
    otherwise
        error('ext_ref_path:path', 'path ist ''planar'' oder ''tilted''');
end
end
