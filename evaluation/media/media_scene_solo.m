function out = media_scene_solo(agentFile, varargin)
%MEDIA_SCENE_SOLO  Ein Agent allein, Raumfahrt-Stil: dunkler Hintergrund, goldene Basis, Kamerafahrt, Lageanzeige.
%   out = media_scene_solo(agentFile)                          3D-Bahn (tilted -30), alle sieben Gelenke (X5)
%   out = media_scene_solo(agentFile, 'video', false)          nur Standbild
%   out = media_scene_solo(file, 'joints', 'J246', 'path', 'planar', 'rewardMode', 4)   ebener Agent (D16)
%
%   Daten: ext_kinsim mit der Policy des Agenten, nominaler Start, wie in X5.2 (Grenzen 0,9774 / 0,5774 rad/s,
%   J6 0,5774) bzw. wie D16 bei 'J246'. Alles maßstaeblich, keine Ueberhoehung.
%   Bild: Arm (hell), Basis als goldener Wuerfel (Isolierfolie, nur Optik) mit Antennenmast, Startlage der Basis als
%   Drahtwuerfel, Sollbahn hell gestrichelt, Bahn des Endeffektors nach dem Fehler eingefaerbt. Die Kamera faehrt
%   waehrend der Bahn um 'orbit' Grad um die Szene. Oben links Zeit, Fehler und Basisdrehung, unten rechts ein
%   kuenstlicher Horizont der Basislage (Roll und Nick gegen die Startlage, Skala in Grad).
%   Optionen: video (true), fps (30), res ([1920 1080]), orbit (70), boom (1.0), title, joints ('all7'),
%   path ('tilted'), tilt (-30), rewardMode (4), errMax (20 mm), outDir (media/solo), tag ('x5').

p = inputParser;
p.addParameter('video', true);
p.addParameter('fps', 30);
p.addParameter('res', [1920 1080]);
p.addParameter('orbit', 70);
p.addParameter('boom', 1.0);
p.addParameter('title', 'RL agent on a free-floating base: tilted 3D path, all seven joints');
p.addParameter('joints', 'all7');
p.addParameter('path', 'tilted');
p.addParameter('tilt', -30);
p.addParameter('rewardMode', 4);
p.addParameter('errMax', 20);
p.addParameter('outDir', '');
p.addParameter('tag', 'x5');
p.parse(varargin{:});
o = p.Results;
setup_project;
if isempty(o.outDir), o.outDir = sk_path('media', 'solo'); end
if ~isfolder(o.outDir), mkdir(o.outDir); end

% --- Daten ---
K = ext_kin_model();
if strcmp(o.joints, 'J246')
    lim = [0; 0.9774; 0; 0.9774; 0; 0.9774; 0]; j6 = 0.9774;
else
    lim = [0.9774; 0.9774; 0.9774; 0.9774; 0.5774; 0.5774; 0.5774]; j6 = 0.5774;
end
pol = ext_policy(agentFile);
run = ext_kinsim(pol, 'reward_mode', o.rewardMode, 'j6_lim', j6, 'base_w', 2, 'lim', lim, 'path', o.path, ...
                 'tilt', o.tilt, 'K', K);
ts = run.ts;
fprintf('Agent: RMS %.2f mm, ori_max %.1f mrad, Abbruch %d\n', 1000 * run.metrics.rms_ee, ...
        1000 * run.metrics.ori_max, run.metrics.early_stop);
save(fullfile(o.outDir, sprintf('solo_%s_data.mat', o.tag)), 'run', 'o', 'agentFile');
M = media_robot('load');

% --- Standbild ---
fig = makeFig(o.res);
G = setupScene(fig, M, ts, o, true);
setFrame(G, ts, M, size(ts.q, 1), o, 0);
stillFile = fullfile(o.outDir, sprintf('solo_%s_still.png', o.tag));
exportgraphics(fig, stillFile, 'Resolution', 200, 'BackgroundColor', 'current');
close(fig);
fprintf('Standbild: %s\n', stillFile);
out = struct('still', stillFile, 'video', '', 'metrics', run.metrics);

% --- Video ---
if o.video
    fig = makeFig(o.res);
    G = setupScene(fig, M, ts, o, false);
    vidFile = fullfile(o.outDir, sprintf('solo_%s.mp4', o.tag));
    vw = VideoWriter(vidFile, 'MPEG-4'); vw.FrameRate = o.fps; vw.Quality = 95;
    open(vw);
    t = ts.t_ee;
    tF = [0:1 / o.fps:t(end), repmat(t(end), 1, round(2 * o.fps))];
    sz = [];
    for k = 1:numel(tF)
        n = find(t <= tF(k) + 1e-9, 1, 'last');
        az = o.orbit * min(tF(k) / t(end), 1);                 % Kamerafahrt waehrend der Bahn
        setFrame(G, ts, M, n, o, az);
        drawnow;
        fr = getframe(fig);
        if isempty(sz), sz = size(fr.cdata); end
        if ~isequal(size(fr.cdata), sz), fr.cdata = imresize(fr.cdata, sz(1:2)); end
        writeVideo(vw, fr);
    end
    close(vw); close(fig);
    fprintf('Video: %s (%d Bilder)\n', vidFile, numel(tF));
    out.video = vidFile;
end
end

% =====================================================================
function fig = makeFig(res)
fig = figure('Visible', 'off', 'Color', [0.03 0.04 0.08], 'Units', 'pixels', 'Position', [0 0 res]);
end

function G = setupScene(fig, M, ts, o, still)
bg = [0.03 0.04 0.08];
ax = axes(fig, 'Position', [0 0 1 0.93], 'Color', bg);
hold(ax, 'on'); axis(ax, 'equal'); axis(ax, 'off');
% Ausschnitt: Basis unten abgeschnitten, damit Arm und Bahn gross werden (wie Szene 1)
xlim(ax, [-0.7 0.7]); ylim(ax, [-0.7 0.7]); zlim(ax, [-0.1 1.8]);
ax.Clipping = 'on';
view(ax, -35, 20); camproj(ax, 'perspective');
camtarget(ax, [0.08 0 0.95]); camzoom(ax, 1.6);
G.az0 = -35; G.el = 20; G.ax = ax;
% Sterne: zufaellige Punkte auf einer Kugel um die Szene (fester Seed), ohne Clipping
rs = RandStream('mt19937ar', 'Seed', 3);
nS = 2500;
u = randn(rs, 3, nS); u = u ./ vecnorm(u) * 5;
scatter3(ax, u(1, :), u(2, :), u(3, :) + 0.9, 3 + 14 * rand(rs, 1, nS) .^ 3, [0.85 0.88 1], 'filled', ...
         'MarkerFaceAlpha', 0.85, 'Clipping', 'off');
% Startlage der Basis als Drahtwuerfel
v = 0.5 * [-1 -1 -1; 1 -1 -1; 1 1 -1; -1 1 -1; -1 -1 1; 1 -1 1; 1 1 1; -1 1 1];
e = [1 2; 2 3; 3 4; 4 1; 5 6; 6 7; 7 8; 8 5; 1 5; 2 6; 3 7; 4 8];
for k = 1:size(e, 1)
    plot3(ax, v(e(k, :), 1), v(e(k, :), 2), v(e(k, :), 3), '-', 'Color', [0.45 0.75 1 0.55], 'LineWidth', 1.2);
end
% Sollbahn
plot3(ax, ts.ref(:, 1), ts.ref(:, 2), ts.ref(:, 3), '--', 'Color', [0.55 0.9 1], 'LineWidth', 1.8);
if still
    tS = linspace(0, ts.t_ee(end), 6);
    for j = 1:numel(tS) - 1
        n = find(ts.t_ee <= tS(j) + 1e-9, 1, 'last');
        Hg = media_robot('draw', M, ax, struct('armAlpha', 0.12 + 0.06 * j, 'showBase', false, 'reduce', 0.3, ...
                                              'armColor', [0.75 0.8 0.88]));
        media_robot('update', M, Hg, ts.q(n, :).', ts.pb(n, :).', ts.quat(n, :).');
    end
end
% Arm und goldene Basis
G.H = media_robot('draw', M, ax, struct('armColor', [0.86 0.88 0.92], 'baseColor', [0.83 0.66 0.25], ...
                                       'baseAlpha', 0.75, 'baseEdge', [1 0.85 0.4]));
% Antennenmast mit Schuessel (an der Basis, mitgedreht)
G.mast = hgtransform('Parent', G.H.world);
f = [-0.45; -0.45; 0.5];
plot3([f(1) f(1)], [f(2) f(2)], [f(3) f(3) + o.boom], '-', 'Color', [0.8 0.8 0.85], 'LineWidth', 3, ...
      'Parent', G.mast, 'Clipping', 'off');
[xs, ys, zs] = sphere(20);
surf(f(1) + 0.07 * xs, f(2) + 0.07 * ys, f(3) + o.boom + 0.035 * zs, 'FaceColor', [0.9 0.9 0.95], ...
     'EdgeColor', 'none', 'Parent', G.mast, 'Clipping', 'off');
plot3(ax, [f(1) f(1)], [f(2) f(2)], [f(3) f(3) + o.boom], ':', 'Color', [0.45 0.75 1], 'LineWidth', 1.4, ...
      'Clipping', 'off');
G.mastTrail = plot3(ax, NaN, NaN, NaN, '-', 'Color', [1 0.55 0.2], 'LineWidth', 1.6, 'Clipping', 'off');
R = quatToR(ts.quat);
tip = f + [0; 0; o.boom];
G.tipPath = ts.pb + squeeze(pagemtimes(R, repmat(tip, 1, 1, size(R, 3)))).';
% Bahn des Endeffektors
G.ee = patch(ax, 'XData', NaN, 'YData', NaN, 'ZData', NaN, 'CData', NaN, 'EdgeColor', 'interp', ...
             'FaceColor', 'none', 'LineWidth', 3.4);
G.dot = plot3(ax, NaN, NaN, NaN, 'o', 'MarkerSize', 8, 'MarkerFaceColor', [1 0.6 0.15], 'MarkerEdgeColor', 'w');
colormap(ax, turbo(256)); clim(ax, [0 o.errMax]);
light(ax, 'Position', [2 -1 3], 'Style', 'infinite', 'Color', [1 0.97 0.9]);
light(ax, 'Position', [-1 2 -1], 'Style', 'infinite', 'Color', [0.25 0.3 0.45]);
% Titel und Anzeigen
annotation(fig, 'textbox', [0 0.93 1 0.06], 'String', o.title, 'EdgeColor', 'none', 'Color', [0.92 0.94 1], ...
           'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 20, 'FontWeight', 'bold', ...
           'FitBoxToText', 'off');
G.hud = annotation(fig, 'textbox', [0.02 0.72 0.2 0.15], 'String', '', 'EdgeColor', [0.4 0.6 0.9], ...
                   'BackgroundColor', [0.06 0.08 0.15], 'Color', [0.9 0.95 1], 'FontName', 'Consolas', ...
                   'FontSize', 16, 'FitBoxToText', 'off', 'VerticalAlignment', 'middle', 'Margin', 10);
cb = colorbar(ax, 'Position', [0.955 0.25 0.01 0.4], 'Color', [0.85 0.9 1]);
cb.Label.String = 'EE error [mm]'; cb.FontSize = 12;
% kuenstlicher Horizont
G.ah = axes(fig, 'Position', [0.79 0.06 0.17 0.3], 'Color', 'none');
hold(G.ah, 'on'); axis(G.ah, 'equal'); axis(G.ah, 'off'); xlim(G.ah, [-1.25 1.25]); ylim(G.ah, [-1.35 1.25]);
th = linspace(0, 2 * pi, 200);
G.sky = patch(G.ah, NaN, NaN, [0.2 0.45 0.8], 'EdgeColor', 'none');
G.gnd = patch(G.ah, NaN, NaN, [0.55 0.38 0.2], 'EdgeColor', 'none');
G.hor = plot(G.ah, NaN, NaN, 'w-', 'LineWidth', 2);
G.ticks = gobjects(0);
plot(G.ah, cos(th), sin(th), '-', 'Color', [0.8 0.85 0.95], 'LineWidth', 2);
plot(G.ah, [-0.5 -0.15 0 0.15 0.5], [0 0 -0.12 0 0], '-', 'Color', [1 0.75 0.1], 'LineWidth', 3);
text(G.ah, 0, -1.22, 'Base attitude (pitch lines every 2°)', 'Color', [0.85 0.9 1], 'FontSize', 12, ...
     'HorizontalAlignment', 'center');
G.scaleDeg = 10;                                 % Kreisradius = 10 Grad
G.pitchLines = gobjects(8, 1); G.pitchTxt = gobjects(8, 1);
for k = 1:8
    G.pitchLines(k) = plot(G.ah, NaN, NaN, '-', 'Color', [1 1 1 0.75], 'LineWidth', 1);
    G.pitchTxt(k) = text(G.ah, NaN, NaN, '', 'Color', [1 1 1], 'FontSize', 9, 'HorizontalAlignment', 'left');
end
end

function setFrame(G, ts, M, n, o, az)
q = ts.q(n, :).'; pb = ts.pb(n, :).'; qt = ts.quat(n, :).';
media_robot('update', M, G.H, q, pb, qt);
view(G.ax, G.az0 + az, G.el);
T = G.tipPath(1:n, :);
G.mastTrail.XData = T(:, 1); G.mastTrail.YData = T(:, 2); G.mastTrail.ZData = T(:, 3);
ee = ts.ref(1:n, :) + ts.ep(1:n, :);
e = 1000 * vecnorm(ts.ep(1:n, :), 2, 2);
G.ee.XData = [ee(:, 1); NaN]; G.ee.YData = [ee(:, 2); NaN]; G.ee.ZData = [ee(:, 3); NaN]; G.ee.CData = [e; NaN];
G.dot.XData = ee(end, 1); G.dot.YData = ee(end, 2); G.dot.ZData = ee(end, 3);
eMax = max(1000 * ts.ori(1:n));
G.hud.String = {sprintf('t           %5.2f s', ts.t_ee(n)), sprintf('EE error    %5.1f mm', e(end)), ...
                sprintf('Base now    %s', fmtDeg(ts.ori(n))), sprintf('Base max    %s', fmtDeg(eMax / 1000))};
% Roll und Nick der Basis gegen die Startlage (Basis -> Welt), kleine Winkel: Drehvektor-Komponenten
R = quatToR(qt.');
roll = atan2(R(3, 2), R(3, 3)); pitch = -asin(max(min(R(3, 1), 1), -1));
s = 1 / deg2rad(G.scaleDeg);                     % Ring = scaleDeg
off = -pitch * s;                                % Horizont verschiebt sich mit dem Nickwinkel
c = cos(roll); si = sin(roll);
P = [c -si; si c] * [[-1 1]; [off off]];
G.hor.XData = P(1, :); G.hor.YData = P(2, :);
% Himmel = ganzer Kreis, Boden = Kreis geschnitten mit der Halbebene unter der gedrehten Horizontlinie
th = linspace(0, 2 * pi, 200);
circ = polyshape(cos(th(1:end - 1)), sin(th(1:end - 1)));
B = [c -si; si c] * [[-3 3 3 -3]; [off off off - 6 off - 6]];
gnd = intersect(circ, polyshape(B(1, :), B(2, :)));
G.sky.XData = cos(th); G.sky.YData = sin(th);
if gnd.NumRegions > 0
    G.gnd.XData = gnd.Vertices(:, 1); G.gnd.YData = gnd.Vertices(:, 2);
else
    G.gnd.XData = NaN; G.gnd.YData = NaN;
end
degs = [-8 -6 -4 -2 2 4 6 8];                    % Nicklinien alle 2 Grad, laengere bei 4 und 8
for k = 1:8
    d = degs(k) / G.scaleDeg;
    hw = 0.15 + 0.12 * (mod(degs(k), 4) == 0);
    P = [c -si; si c] * [[-hw hw]; [off + d off + d]];
    G.pitchLines(k).XData = P(1, :); G.pitchLines(k).YData = P(2, :);
    if mod(degs(k), 4) == 0
        Pt = [c -si; si c] * [hw + 0.04; off + d];
        G.pitchTxt(k).Position = [Pt(1) Pt(2) 0]; G.pitchTxt(k).String = sprintf('%d°', abs(degs(k)));
    end
end
end

function R = quatToR(Q)
n = size(Q, 1);
R = zeros(3, 3, n);
for j = 1:n
    w = Q(j, 1); x = Q(j, 2); y = Q(j, 3); z = Q(j, 4);
    R(:, :, j) = [1 - 2*(y^2 + z^2), 2*(x*y - z*w), 2*(x*z + y*w);
                  2*(x*y + z*w), 1 - 2*(x^2 + z^2), 2*(y*z - x*w);
                  2*(x*z - y*w), 2*(y*z + x*w), 1 - 2*(x^2 + y^2)];
end
end

function s = fmtDeg(rad)
m = round(rad2deg(rad) * 60);
s = sprintf('%d°%02d''', floor(m / 60), mod(m, 60));
end
