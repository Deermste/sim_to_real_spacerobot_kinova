function out = media_scene_hw(varargin)
%MEDIA_SCENE_HW  Hardware-Szene: gemessene Gelenkbewegung der Laborlaeufe, gerendert mit virtueller frei schwebender Basis.
%   out = media_scene_hw()                       Tracking K1: alter Reward (r0) gegen neuer Reward (r4), Labortag 2
%   out = media_scene_hw('video', false)         nur Standbild
%   out = media_scene_hw('runs', {...}, 'titles', {...}, 'tag', 'xyz')   eigene Laeufe (Pfade relativ zu
%                                                data/hardware/campaign)
%
%   Gezeigt wird, was im Labor passiert ist: der fest montierte Arm (grauer Block = Montage), die gemessene
%   Gelenkbahn (run.log.q, pchip auf die Bildrate), die Bahn des Endeffektors aus der FK der gemessenen Winkel
%   (run.log.ee_pos, eingefaerbt nach dem Fehler zur Sollbahn) und die Sollbahn (run.log.ee_ref, gestrichelt).
%   Dazu orange die Lage, die eine frei schwebende Basis (65 kg) bei genau dieser Gelenkbewegung haette
%   (media_hw_base, wie D19), um 'exaggerate' vergroessert gezeichnet. Zahlen und Balken zeigen die wahre Drehung
%   in Grad und Bogenminuten.
%   Optionen: video (true), fps (30), lang ('en'), res ([1920 1080]), exaggerate (5), errMax (100 mm, Farbskala),
%   barMax (3 Grad), outDir (media/hw_tracking), tag ('k1').

p = inputParser;
p.addParameter('video', true);
p.addParameter('fps', 30);
p.addParameter('lang', 'en');
p.addParameter('res', [1920 1080]);
p.addParameter('exaggerate', 5);
p.addParameter('errMax', 100);
p.addParameter('barMax', 3);
p.addParameter('runs', {'T40_r0_j6/T40_r0_j6_r03_20261003_134523.mat', 'T40_r4_1k/T40_r4_1k_r03_20261003_134742.mat'});
p.addParameter('titles', {'Old reward with base bonus (r0)', 'Revised reward (r4)'});
p.addParameter('main', 'Lab hardware, measured joint motion (Kinova Gen3, half-circle path)');
p.addParameter('outDir', '');
p.addParameter('tag', 'k1');
p.addParameter('mode', 'tracking');      % 'setpoint': Ziel aus meta.target statt Sollbahn (Laeufe S10_nom usw.)
p.addParameter('tol', 0.02);             % Set-Point: Toleranzkugel [m] (Trainingskriterium von fixed1)
p.parse(varargin{:});
o = p.Results;
setup_project;
sp = strcmp(o.mode, 'setpoint');
if isempty(o.outDir), o.outDir = sk_path('media', ['hw_' o.mode]); end
if ~isfolder(o.outDir), mkdir(o.outDir); end

% --- Daten ---
K = ext_kin_model();
nP = numel(o.runs);
D = cell(1, nP);
for i = 1:nP
    S = load(sk_path('data', 'hardware', 'campaign', o.runs{i}), 'run');
    L = S.run.log; n = S.run.meta.nSteps;
    t = L.t_wall(1:n) - L.t_wall(1);
    B = media_hw_base(t, L.q(1:n, :), 'K', K);
    if sp
        ref = repmat(S.run.meta.target(:).', n, 1);
    else
        ref = L.ee_ref(1:n, :);
    end
    err = vecnorm(L.ee_pos(1:n, :) - ref, 2, 2);
    D{i} = struct('t', t, 'q', L.q(1:n, :), 'ee', L.ee_pos(1:n, :), 'ref', ref, 'err', err, ...
                  'B', B, 'rms', sqrt(mean(err .^ 2)), 'oriMax', max(B.ori), 'meta', S.run.meta);
    fprintf('%s: RMS %.1f mm, Ende %.1f mm, virtuelle Basis bis %.1f mrad\n', o.runs{i}, 1000 * D{i}.rms, ...
            1000 * err(end), 1000 * D{i}.oriMax);
end
M = media_robot('load');
L = labels(o, D);

% --- Standbild: Endlage, ganze Bahn ---
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', 'Position', [0 0 o.res]);
[A, Sx] = setupPanels(fig, M, D, L, o, true);
for i = 1:nP, setFrame(Sx{i}, D{i}, M, D{i}.t(end), L, o); end
stillFile = fullfile(o.outDir, sprintf('hw_%s_still_%s.png', o.tag, o.lang));
exportgraphics(fig, stillFile, 'Resolution', 200, 'BackgroundColor', 'white');
close(fig);
fprintf('Standbild: %s\n', stillFile);
out = struct('still', stillFile, 'video', '');

% --- Video ---
if o.video
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', 'Position', [0 0 o.res]);
    [~, Sx] = setupPanels(fig, M, D, L, o, false);
    vidFile = fullfile(o.outDir, sprintf('hw_%s_%s.mp4', o.tag, o.lang));
    vw = VideoWriter(vidFile, 'MPEG-4');
    vw.FrameRate = o.fps; vw.Quality = 95;
    open(vw);
    tEnd = max(cellfun(@(d) d.t(end), D));
    tF = [0:1 / o.fps:tEnd, repmat(tEnd, 1, round(1.5 * o.fps))];
    sz = [];
    for k = 1:numel(tF)
        for i = 1:nP, setFrame(Sx{i}, D{i}, M, min(tF(k), D{i}.t(end)), L, o); end
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
function L = labels(o, D)
L.title = o.titles;
L.sp = strcmp(o.mode, 'setpoint');
L.tol = o.tol;
if L.sp
    L.sub = cellfun(@(d) sprintf('Start %.0f mm away, final error %.1f mm, virtual base up to %s', ...
                                 1000 * d.err(1), 1000 * d.err(end), fmtDeg(d.oriMax)), D, 'UniformOutput', false);
    L.err = 'Distance to target %.1f mm';
    L.cbar = 'Distance to target [mm]';
else
    L.sub = cellfun(@(d) sprintf('EE error %.1f mm RMS, virtual base rotation up to %s', 1000 * d.rms, ...
                                 fmtDeg(d.oriMax)), D, 'UniformOutput', false);
    L.err = 'EE error %.1f mm';
    L.cbar = 'EE error [mm]';
end
L.time = 't = %.2f s';
L.ori = 'Virtual base %s';
L.bar = sprintf('Virtual base rotation (0° to %d°)', o.barMax);
L.main = o.main;
if o.exaggerate == 1
    scl = 'drawn to scale';
else
    scl = sprintf('drawn %g\\times enlarged', o.exaggerate);
end
L.note = sprintf(['Arm fixed to the lab table (grey block). Orange: attitude a free-floating 65-kg base would ' ...
                  'take for the same joint motion (computed, %s). Numbers show the true angle.'], scl);
end

function [A, S] = setupPanels(fig, M, D, L, o, still)
nP = numel(D);
A = cell(1, nP); S = cell(1, nP);
pw = 0.95 / nP;
fs = 15 - 2 * (nP > 2);
annotation(fig, 'textbox', [0 0.925 1 0.06], 'String', L.main, 'EdgeColor', 'none', ...
           'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 20, 'FontWeight', 'bold', ...
           'FitBoxToText', 'off');
for i = 1:nP
    d = D{i};
    ax = axes(fig, 'Position', [0.005 + pw * (i - 1), 0.15, pw, 0.69]); %#ok<LAXES>
    hold(ax, 'on'); axis(ax, 'equal'); axis(ax, 'off');
    if L.sp
        % Set-Point: Starts im ganzen Arbeitsraum, groesserer Ausschnitt
        xlim(ax, [-0.95 0.95]); ylim(ax, [-0.95 0.95]); zlim(ax, [-0.12 1.65]);
        ax.Clipping = 'on';
        view(ax, -35, 22); camproj(ax, 'perspective');
        camtarget(ax, [0.15 0 0.8]); camzoom(ax, 1.75);
    else
        xlim(ax, [-0.62 0.62]); ylim(ax, [-0.62 0.62]); zlim(ax, [-0.12 1.78]);
        ax.Clipping = 'on';
        view(ax, -35, 22); camproj(ax, 'perspective');
        camtarget(ax, [0 0 0.82]); camzoom(ax, 1.45);
    end
    if L.sp
        % Ziel: Punkt und durchscheinende Toleranzkugel
        [xs, ys, zs] = sphere(32);
        c = d.ref(1, :);
        surf(ax, c(1) + L.tol * xs, c(2) + L.tol * ys, c(3) + L.tol * zs, 'FaceColor', [0.2 0.75 0.3], ...
             'FaceAlpha', 0.25, 'EdgeColor', 'none', 'FaceLighting', 'gouraud');
        plot3(ax, c(1), c(2), c(3), 'p', 'MarkerSize', 16, 'MarkerFaceColor', [0.1 0.55 0.2], ...
              'MarkerEdgeColor', 'k');
    else
        plot3(ax, d.ref(:, 1), d.ref(:, 2), d.ref(:, 3), '--', 'Color', [0.15 0.15 0.15], 'LineWidth', 1.6);
    end
    % Standbild: Startpose als Geisterbild
    if still
        Hg = media_robot('draw', M, ax, struct('armAlpha', 0.2, 'showBase', false, 'reduce', 0.3));
        media_robot('update', M, Hg, d.q(1, :).', zeros(3, 1), [1 0 0 0]);
    end
    % Arm auf der festen Montage (grauer Block, ruht)
    H = media_robot('draw', M, ax, struct('baseAlpha', 0.55, 'baseColor', [0.78 0.79 0.81]));
    % virtuelle Basis: oranger Drahtwuerfel und Achsen, vergroessert gedreht
    S{i}.vb = hgtransform('Parent', ax);
    v = 0.5 * [-1 -1 -1; 1 -1 -1; 1 1 -1; -1 1 -1; -1 -1 1; 1 -1 1; 1 1 1; -1 1 1];
    e = [1 2; 2 3; 3 4; 4 1; 5 6; 6 7; 7 8; 8 5; 1 5; 2 6; 3 7; 4 8];
    for k = 1:size(e, 1)
        plot3(v(e(k, :), 1), v(e(k, :), 2), v(e(k, :), 3), '-', 'Color', [0.95 0.5 0.05], 'LineWidth', 2.4, ...
              'Parent', S{i}.vb);
    end
    col = [0.85 0.2 0.2; 0.2 0.6 0.25; 0.2 0.35 0.85];
    for k = 1:3
        u = zeros(3, 1); u(k) = 1.1;
        plot3([0 u(1)], [0 u(2)], [0 u(3)], '-', 'Color', col(k, :), 'LineWidth', 2.2, 'Parent', S{i}.vb);
    end
    S{i}.ee = patch(ax, 'XData', NaN, 'YData', NaN, 'ZData', NaN, 'CData', NaN, 'EdgeColor', 'interp', ...
                    'FaceColor', 'none', 'LineWidth', 3.2);
    S{i}.eeDot = plot3(ax, NaN, NaN, NaN, 'o', 'MarkerSize', 7, 'MarkerFaceColor', [0.95 0.45 0.1], ...
                       'MarkerEdgeColor', 'k');
    colormap(ax, turbo(256)); clim(ax, [0 o.errMax]);
    light(ax, 'Position', [1 -1 2], 'Style', 'infinite');
    light(ax, 'Position', [-1 1 1], 'Style', 'infinite', 'Color', [0.5 0.5 0.5]);
    S{i}.H = H;
    media_robot('update', M, H, d.q(1, :).', zeros(3, 1), [1 0 0 0]);
    annotation(fig, 'textbox', [0.005 + pw * (i - 1), 0.84, pw, 0.08], 'String', {L.title{i}, L.sub{i}}, ...
               'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
               'FontSize', fs, 'Interpreter', 'tex', 'FitBoxToText', 'off');
    x0 = 0.005 + pw * (i - 1) + 0.05 * pw;
    bw = 0.42 * pw;
    S{i}.txt = annotation(fig, 'textbox', [x0 0.055 0.45 * pw 0.1], 'String', '', 'EdgeColor', 'none', ...
                          'FontSize', fs - 1, 'FontName', 'Consolas', 'Interpreter', 'none', 'FitBoxToText', 'off', ...
                          'VerticalAlignment', 'middle');
    xb = x0 + 0.47 * pw;
    S{i}.barBg = annotation(fig, 'rectangle', [xb, 0.1, bw, 0.025], 'FaceColor', [0.93 0.93 0.93], ...
                            'Color', [0.5 0.5 0.5]);
    S{i}.bar = annotation(fig, 'rectangle', [xb, 0.1, 0.001, 0.025], 'FaceColor', [0.95 0.5 0.05], 'Color', 'none');
    S{i}.barTxt = annotation(fig, 'textbox', [xb, 0.06, bw, 0.04], 'String', L.bar, 'EdgeColor', 'none', ...
                             'FontSize', 11, 'HorizontalAlignment', 'center', 'FitBoxToText', 'off');
    S{i}.barW = bw;
    A{i} = ax;
end
annotation(fig, 'rectangle', [0 0 1 0.15], 'FaceColor', 'w', 'Color', 'w');
annotation(fig, 'textbox', [0.03 0.0 0.94 0.05], 'String', L.note, 'EdgeColor', 'none', 'FontSize', 11, ...
           'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Interpreter', 'tex', ...
           'FitBoxToText', 'off', 'Color', [0.3 0.3 0.3]);
for i = 1:nP
    for h = [S{i}.txt, S{i}.barBg, S{i}.bar, S{i}.barTxt], uistack(h, 'top'); end
end
cb = colorbar(A{end}, 'Position', [0.96 0.3 0.01 0.4]);
cb.Label.String = L.cbar; cb.FontSize = 11;
linkprop([A{:}], {'CameraPosition', 'CameraTarget', 'CameraUpVector', 'CameraViewAngle'});
end

function setFrame(S, d, M, tk, L, o)
q = interp1(d.t, d.q, tk, 'pchip');
media_robot('update', M, S.H, q(:), zeros(3, 1), [1 0 0 0]);
[~, j] = min(abs(d.B.t - tk));
v = rotvecOf(d.B.quat(j, :));
S.vb.Matrix = makehgtform('translate', d.B.pb(j, :)) * axrot(o.exaggerate * v);
n = find(d.t <= tk + 1e-9, 1, 'last');
ee = d.ee(1:n, :); e = 1000 * d.err(1:n);
S.ee.XData = [ee(:, 1); NaN]; S.ee.YData = [ee(:, 2); NaN]; S.ee.ZData = [ee(:, 3); NaN];
S.ee.CData = [e; NaN];
S.eeDot.XData = ee(end, 1); S.eeDot.YData = ee(end, 2); S.eeDot.ZData = ee(end, 3);
S.txt.String = {sprintf(L.time, tk), sprintf(L.err, e(end)), sprintf(L.ori, fmtDeg(d.B.ori(j)))};
S.bar.Position(3) = max(S.barW * min(rad2deg(d.B.ori(j)) / o.barMax, 1), 0.001);
end

function T = axrot(v)
a = norm(v);
T = eye(4);
if a > 1e-12, T = makehgtform('axisrotate', v / a, a); end
end

function v = rotvecOf(qt)
if qt(1) < 0, qt = -qt; end
nv = norm(qt(2:4));
if nv < 1e-12, v = zeros(3, 1); else, v = 2 * atan2(nv, qt(1)) * qt(2:4).' / nv; end
end

function s = fmtDeg(rad)
m = round(rad2deg(rad) * 60);
s = sprintf('%d°%02d''', floor(m / 60), mod(m, 60));
end
