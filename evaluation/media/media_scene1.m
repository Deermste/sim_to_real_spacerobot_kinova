function out = media_scene1(varargin)
%MEDIA_SCENE1  Szene 1: gekippte 3D-Bahn, Regler ohne gegen mit Nullraum, Basisdrehung und Bahn im Bild (K7).
%   out = media_scene1()                        Standbild (PNG) und Video (MP4) unter media/scene1/
%   out = media_scene1('video', false)          nur Standbild
%   out = media_scene1('lang', 'de')            deutsche Beschriftung (Standard Englisch)
%
%   Daten: ext_kinsim, nominal, Bahn tilted -30 Grad (E10), alle sieben Gelenke (0,98 / 0,58 rad/s), volle
%   Befehlskette mit Inversion, J6-Seite 0. Links R0 (beta 0), rechts Rbeta (beta 4,6416), wie in
%   ext_x5_1_feasibility (X5.1: 4,2 mm / 124 mrad gegen 2,1 mm / 9,7 mrad).
%   Darstellung je Feld (gleiche Kamera):
%     Arm und Basiswuerfel in der wahren Lage (keine Ueberhoehung im Bild der Basis), Startlage der Basis als
%     gestrichelter Wuerfel, Basisachsen (1,1 m) mit Spur der Achsspitzen, Sollbahn gestrichelt, Bahn des
%     Endeffektors eingefaerbt nach dem Fehler, Anzeige der Basisdrehung als Balken (0 bis 9 Grad).
%     Winkel in Grad und Bogenminuten (7°08'), nicht in mrad.
%   Optionen: video (true), fps (30), slow (1, Faktor der Zeitlupe), lang ('en'), res ([1920 1080]),
%   strobe ([0 2.125 4.25 6.375 8.5] s, Posen im Standbild), outDir (media/scene1).

p = inputParser;
p.addParameter('video', true);
p.addParameter('fps', 30);
p.addParameter('slow', 1);
p.addParameter('lang', 'en');     % seit 14.11. Englisch als Standard (Nutzer), 'de' fuer deutsche Beschriftung
p.addParameter('res', [1920 1080]);
p.addParameter('strobe', [0 2.125 4.25 6.375 8.5]);
p.addParameter('outDir', '');
p.addParameter('agentFile', '');        % drittes Feld: RL-Agent (X5), leer = nur die beiden Regler
p.addParameter('agentTitle', {'RL agent (PPO)', 'RL-Agent (PPO)'});   % {en, de}
p.addParameter('agentRewardMode', 4);
p.addParameter('tag', '');              % Zusatz im Dateinamen, z. B. 'rl'
% Freie Zusammenstellung (14.11.): Struct-Array mit kind ('ctrl' oder 'agent'), beta (ctrl), file und rewardMode
% (agent), joints ('J246' wie die Bestandsagenten oder 'all7'), path ('planar'/'tilted'), tilt, title {en, de}.
% Ersetzt die beiden Regler von Szene 1. Dazu name (Dateiname statt 'scene1') und main {en, de} (Gesamttitel).
p.addParameter('panels', []);
p.addParameter('name', 'scene1');
p.addParameter('main', {});
p.parse(varargin{:});
o = p.Results;
setup_project;
if isempty(o.outDir), o.outDir = sk_path('media', o.name); end
if ~isfolder(o.outDir), mkdir(o.outDir); end

% --- Daten ---
K = ext_kin_model();
lim = [0.98; 0.98; 0.98; 0.98; 0.58; 0.58; 0.58];
betas = [0 4.6416];
runs = cell(1, 2);
if ~isempty(o.panels)
    [runs, titles] = buildRuns(o.panels, K);
    betas = []; % nur Szene 1
end
for i = 1:2 * isempty(o.panels)
    c = ext_x2_controller('joints', 1:7, 'task', [1 2 3], 'lim', lim, 'j6_side', 0, 'K', K, 'invert', true, ...
                          'beta', betas(i));
    runs{i} = ext_kinsim([], 'ctrl', c, 'lim', lim, 'reward_mode', 4, 'path', 'tilted', 'tilt', -30, ...
                         'chain', 'full');
    fprintf('beta %.4g: RMS %.2f mm, ori_max %.1f mrad\n', betas(i), 1000 * runs{i}.metrics.rms_ee, ...
            1000 * runs{i}.metrics.ori_max);
end
if isempty(o.panels)
    titles = {{'Controller without null space (R0)', 'Regler ohne Nullraum (R0)'}, ...
              {'Controller with reaction-reducing null space (R\beta, \beta = 4.6)', ...
               'Regler mit reaktionsarmer Nullraumbewegung (R\beta, \beta = 4,6)'}};
end
if ~isempty(o.agentFile)
    % RL-Agent wie im Training X5.2: Grenzen 0,9774 / 0,5774 rad/s, J6 0,5774, Beobachtungsgrenzen aus dem Agenten
    lim7 = [0.9774; 0.9774; 0.9774; 0.9774; 0.5774; 0.5774; 0.5774];
    pol = ext_policy(o.agentFile);
    runs{3} = ext_kinsim(pol, 'reward_mode', o.agentRewardMode, 'j6_lim', 0.5774, 'base_w', 2, 'lim', lim7, ...
                         'path', 'tilted', 'tilt', -30, 'K', K);
    titles{3} = o.agentTitle;
    fprintf('Agent: RMS %.2f mm, ori_max %.1f mrad, Abbruch %d\n', 1000 * runs{3}.metrics.rms_ee, ...
            1000 * runs{3}.metrics.ori_max, runs{3}.metrics.early_stop);
end
nP = numel(runs);
sfx = o.lang;
if ~isempty(o.tag), sfx = [o.tag '_' o.lang]; end
dataName = [o.name '_data.mat'];
if ~isempty(o.tag), dataName = sprintf('%s_data_%s.mat', o.name, o.tag); end
save(fullfile(o.outDir, dataName), 'runs', 'betas', 'lim', 'o');

L = labels(o.lang, runs, titles);
if ~isempty(o.main), L.main = o.main{1 + strcmp(o.lang, 'de')}; end
M = media_robot('load');

% --- Standbild (Stroboskop) ---
fig = makeFigure(o.res);
[A, S] = setupPanels(fig, M, runs, L, true, o.strobe);
for i = 1:nP, setFrame(A{i}, S{i}, runs{i}, M, size(runs{i}.ts.q, 1), L, i); end
stillFile = fullfile(o.outDir, sprintf('%s_still_%s.png', o.name, sfx));
exportgraphics(fig, stillFile, 'Resolution', 200, 'BackgroundColor', 'white');
close(fig);
fprintf('Standbild: %s\n', stillFile);
out = struct('still', stillFile, 'video', '');

% --- Video ---
if o.video
    fig = makeFigure(o.res);
    [A, S] = setupPanels(fig, M, runs, L, false, []);
    vidFile = fullfile(o.outDir, sprintf('%s_%s.mp4', o.name, sfx));
    vw = VideoWriter(vidFile, 'MPEG-4');
    vw.FrameRate = o.fps; vw.Quality = 95;
    open(vw);
    t = runs{1}.ts.t_ee;
    tF = 0:(1 / (o.fps * o.slow)):t(end);
    tF = [tF, repmat(t(end), 1, round(1.5 * o.fps))];     % 1,5 s Standbild am Ende
    sz = [];
    for k = 1:numel(tF)
        n = find(t <= tF(k) + 1e-9, 1, 'last');
        for i = 1:nP
            setFrame(A{i}, S{i}, runs{i}, M, min(n, size(runs{i}.ts.q, 1)), L, i);   % Abbruch: letzte Lage halten
        end
        drawnow;
        fr = getframe(fig);
        if isempty(sz), sz = size(fr.cdata); end
        if ~isequal(size(fr.cdata), sz), fr.cdata = imresize(fr.cdata, sz(1:2)); end
        writeVideo(vw, fr);
    end
    close(vw);
    close(fig);
    fprintf('Video: %s (%d Bilder, %.1f s)\n', vidFile, numel(tF), numel(tF) / o.fps);
    out.video = vidFile;
end
end

% =====================================================================
function [runs, titles] = buildRuns(P, K)
% Laeufe aus der freien Zusammenstellung (Option panels), Aufbau wie die jeweiligen Studien
runs = cell(1, numel(P)); titles = cell(1, numel(P));
for i = 1:numel(P)
    pr = P(i);
    if strcmp(pr.joints, 'J246')
        lim = [0; 0.9774; 0; 0.9774; 0; 0.9774; 0];        % wie D16 (J6 0,9774)
        jnt = [2 4 6]; j6 = 0.9774;
    else
        lim = [0.9774; 0.9774; 0.9774; 0.9774; 0.5774; 0.5774; 0.5774];   % wie X5.2
        jnt = 1:7; j6 = 0.5774;
    end
    task = [1 2 3];
    if strcmp(pr.path, 'planar') && strcmp(pr.joints, 'J246'), task = [1 3]; end
    if strcmp(pr.kind, 'ctrl')
        c = ext_x2_controller('joints', jnt, 'task', task, 'lim', lim, 'j6_side', 0, 'K', K, 'invert', true, ...
                              'beta', pr.beta);
        runs{i} = ext_kinsim([], 'ctrl', c, 'lim', lim, 'reward_mode', 4, 'path', pr.path, 'tilt', pr.tilt, ...
                             'chain', 'full', 'K', K);
    else
        pol = ext_policy(pr.file);
        runs{i} = ext_kinsim(pol, 'reward_mode', pr.rewardMode, 'j6_lim', j6, 'base_w', 2, 'lim', lim, ...
                             'path', pr.path, 'tilt', pr.tilt, 'K', K);
    end
    titles{i} = pr.title;
    fprintf('%s: RMS %.2f mm, ori_max %.1f mrad, Abbruch %d\n', pr.title{1}, 1000 * runs{i}.metrics.rms_ee, ...
            1000 * runs{i}.metrics.ori_max, runs{i}.metrics.early_stop);
end
end

function L = labels(lang, runs, titles)
il = 1 + strcmp(lang, 'de');
L.title = cellfun(@(c) c{il}, titles, 'UniformOutput', false);
if strcmp(lang, 'en')
    L.sub = cellfun(@(r) sprintf('EE error %.1f mm RMS, base rotation up to %s', 1000 * r.metrics.rms_ee, ...
                                 fmtDeg(r.metrics.ori_max)), runs, 'UniformOutput', false);
    L.time = 't = %.2f s';
    L.err = 'EE error %.1f mm';
    L.ori = 'Base rotation %s';
    L.legend = {'Reference path', 'End-effector path', 'Base at start', 'Base axes'};
    L.bar = 'Base rotation';
    L.cbar = 'EE error [mm]';
    L.main = 'Free-floating base, tilted 3D path (-30°), all seven joints';
else
    L.sub = cellfun(@(r) sprintf('EE-Fehler %.1f mm RMS, Basisdrehung bis %s', 1000 * r.metrics.rms_ee, ...
                                 fmtDeg(r.metrics.ori_max)), runs, 'UniformOutput', false);
    L.sub = strrep(L.sub, '.', ',');
    L.time = 't = %.2f s';
    L.err = 'EE-Fehler %.1f mm';
    L.ori = 'Basisdrehung %s';
    L.legend = {'Sollbahn', 'Bahn des Endeffektors', 'Basis beim Start', 'Basisachsen'};
    L.bar = 'Basisdrehung';
    L.cbar = 'EE-Fehler [mm]';
    L.main = 'Frei schwebende Basis, gekippte 3D-Bahn (-30°), alle sieben Gelenke';
end
L.lang = lang;
end

function fig = makeFigure(res)
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', 'Position', [0 0 res]);
end

function [A, S] = setupPanels(fig, M, runs, L, strobe, tStrobe)
nP = numel(runs);
A = cell(1, nP); S = cell(1, nP);
pw = 0.95 / nP;                                  % Breite je Feld
fs = 15 - 2 * (nP > 2);                          % Schrift kleiner bei drei Feldern
annotation(fig, 'textbox', [0 0.925 1 0.06], 'String', L.main, 'EdgeColor', 'none', ...
           'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 20, 'FontWeight', 'bold', ...
           'FitBoxToText', 'off');
cmap = turbo(256);
for i = 1:nP
    ax = axes(fig, 'Position', [0.005 + pw * (i - 1), 0.12, pw, 0.72]); %#ok<LAXES>
    hold(ax, 'on'); axis(ax, 'equal'); axis(ax, 'off');
    % Ausschnitt: Wuerfel unten abgeschnitten (Clipping an den Achsgrenzen), damit Arm und Bahn groesser werden
    xlim(ax, [-0.62 0.62]); ylim(ax, [-0.62 0.62]); zlim(ax, [-0.12 1.78]);
    ax.Clipping = 'on';
    view(ax, -35, 22);
    camproj(ax, 'perspective');
    camtarget(ax, [0 0 0.82]);
    camzoom(ax, 1.45);
    ts = runs{i}.ts;
    % Sollbahn
    plot3(ax, ts.ref(:, 1), ts.ref(:, 2), ts.ref(:, 3), '--', 'Color', [0.15 0.15 0.15], 'LineWidth', 1.6);
    % Startlage der Basis (gestrichelter Wuerfel)
    drawGhostCube(ax);
    % Stroboskop: halbtransparente Posen
    if strobe
        t = ts.t_ee;
        for j = 1:numel(tStrobe) - 1
            n = find(t <= tStrobe(j) + 1e-9, 1, 'last');
            a = 0.12 + 0.18 * (j - 1) / max(numel(tStrobe) - 2, 1);
            Hg = media_robot('draw', M, ax, struct('armAlpha', a, 'showBase', false, 'reduce', 0.3));
            media_robot('update', M, Hg, ts.q(n, :).', ts.pb(n, :).', ts.quat(n, :).');
        end
    end
    % Arm in der aktuellen Lage
    H = media_robot('draw', M, ax, struct());
    % Basisachsen und Spur der Spitzen
    S{i}.axes = gobjects(3, 1); S{i}.trail = gobjects(3, 1);
    col = [0.85 0.2 0.2; 0.2 0.6 0.25; 0.2 0.35 0.85];
    Rall = quatToR(ts.quat);
    for k = 1:3
        S{i}.tips{k} = ts.pb + squeeze(Rall(:, k, :)).' * 1.1;     % Spitzen der Basisachsen (1,1 m)
    end
    for k = 1:3
        S{i}.axes(k) = plot3(ax, [0 0], [0 0], [0 0], '-', 'Color', col(k, :), 'LineWidth', 2.2);
        S{i}.trail(k) = plot3(ax, NaN, NaN, NaN, '-', 'Color', [col(k, :) 0.6], 'LineWidth', 1.2);
    end
    % Bahn des Endeffektors, eingefaerbt nach dem Fehler (0 bis 20 mm)
    S{i}.ee = patch(ax, 'XData', NaN, 'YData', NaN, 'ZData', NaN, 'CData', NaN, 'EdgeColor', 'interp', ...
                    'FaceColor', 'none', 'LineWidth', 3.2);
    S{i}.eeDot = plot3(ax, NaN, NaN, NaN, 'o', 'MarkerSize', 7, 'MarkerFaceColor', [0.95 0.45 0.1], ...
                       'MarkerEdgeColor', 'k');
    colormap(ax, cmap); clim(ax, [0 20]);
    light(ax, 'Position', [1 -1 2], 'Style', 'infinite');
    light(ax, 'Position', [-1 1 1], 'Style', 'infinite', 'Color', [0.5 0.5 0.5]);
    S{i}.H = H;
    annotation(fig, 'textbox', [0.005 + pw * (i - 1), 0.84, pw, 0.08], 'String', {L.title{i}, L.sub{i}}, ...
               'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
               'FontSize', fs, 'Interpreter', 'tex', 'FitBoxToText', 'off');
    S{i}.ax = ax;
    % Text und Balken unter dem Feld (Text links, Balken rechts, je etwa 40 % der Feldbreite)
    x0 = 0.005 + pw * (i - 1) + 0.05 * pw;
    bw = 0.42 * pw;
    S{i}.txt = annotation(fig, 'textbox', [x0 0.01 0.45 * pw 0.11], 'String', '', 'EdgeColor', 'none', ...
                          'FontSize', fs - 1, 'FontName', 'Consolas', 'Interpreter', 'none', 'FitBoxToText', 'off', ...
                          'VerticalAlignment', 'middle');
    xb = x0 + 0.47 * pw;
    S{i}.barBg = annotation(fig, 'rectangle', [xb, 0.07, bw, 0.025], 'FaceColor', [0.93 0.93 0.93], ...
                            'Color', [0.5 0.5 0.5]);
    S{i}.bar = annotation(fig, 'rectangle', [xb, 0.07, 0.001, 0.025], 'FaceColor', [0.85 0.3 0.2], ...
                          'Color', 'none');
    S{i}.barTxt = annotation(fig, 'textbox', [xb, 0.025, bw, 0.04], 'String', L.bar + " (0° bis 9°)", ...
                             'EdgeColor', 'none', 'FontSize', 11, 'HorizontalAlignment', 'center', ...
                             'FitBoxToText', 'off');
    if strcmp(L.lang, 'en'), S{i}.barTxt.String = L.bar + " (0° to 9°)"; end
    S{i}.barW = bw;
    A{i} = ax;
end
% weisser Streifen unter Text und Balken (der abgeschnittene Wuerfel ragt sonst hinein), Text und Balken nach vorn
annotation(fig, 'rectangle', [0 0 1 0.125], 'FaceColor', 'w', 'Color', 'w');
for i = 1:nP
    for h = [S{i}.txt, S{i}.barBg, S{i}.bar, S{i}.barTxt]
        uistack(h, 'top');
    end
end
% gemeinsame Farbskala
cb = colorbar(A{end}, 'Position', [0.96 0.3 0.01 0.4]);
cb.Label.String = L.cbar; cb.FontSize = 11;
linkprop([A{:}], {'CameraPosition', 'CameraTarget', 'CameraUpVector', 'CameraViewAngle'});
end

function setFrame(ax, S, run, M, n, L, ~) %#ok<INUSL>
ts = run.ts;
q = ts.q(n, :).'; pb = ts.pb(n, :).'; qt = ts.quat(n, :).';
media_robot('update', M, S.H, q, pb, qt);
for k = 1:3
    TT = S.tips{k}(1:n, :);
    tip = TT(end, :);
    S.axes(k).XData = [pb(1) tip(1)]; S.axes(k).YData = [pb(2) tip(2)]; S.axes(k).ZData = [pb(3) tip(3)];
    S.trail(k).XData = TT(:, 1); S.trail(k).YData = TT(:, 2); S.trail(k).ZData = TT(:, 3);
end
ee = ts.ref(1:n, :) + ts.ep(1:n, :);
e = 1000 * vecnorm(ts.ep(1:n, :), 2, 2);
S.ee.XData = [ee(:, 1); NaN]; S.ee.YData = [ee(:, 2); NaN]; S.ee.ZData = [ee(:, 3); NaN];
S.ee.CData = [e; NaN];
S.eeDot.XData = ee(end, 1); S.eeDot.YData = ee(end, 2); S.eeDot.ZData = ee(end, 3);
s1 = sprintf(L.time, ts.t_ee(n));
s2 = sprintf(L.err, e(end));
s3 = sprintf(L.ori, fmtDeg(ts.ori(n)));
if strcmp(L.lang, 'de'), s2 = strrep(s2, '.', ','); s1 = strrep(s1, '.', ','); end
S.txt.String = {s1, s2, s3};
w = S.barW * min(rad2deg(ts.ori(n)) / 9, 1);    % Balken 0 bis 9 Grad
S.bar.Position(3) = max(w, 0.001);
end

function s = fmtDeg(rad)
% Winkel in Grad und Bogenminuten, z. B. 7°08' (lesbarer als mrad, Wunsch des Nutzers 14.11.)
m = round(rad2deg(rad) * 60);
s = sprintf('%d°%02d''', floor(m / 60), mod(m, 60));
end

function drawGhostCube(ax)
v = 0.5 * [-1 -1 -1; 1 -1 -1; 1 1 -1; -1 1 -1; -1 -1 1; 1 -1 1; 1 1 1; -1 1 1];
e = [1 2; 2 3; 3 4; 4 1; 5 6; 6 7; 7 8; 8 5; 1 5; 2 6; 3 7; 4 8];
for k = 1:size(e, 1)
    plot3(ax, v(e(k, :), 1), v(e(k, :), 2), v(e(k, :), 3), ':', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.3);
end
end

function R = quatToR(Q)
% Q n x 4 [w x y z] -> 3 x 3 x n
n = size(Q, 1);
R = zeros(3, 3, n);
for j = 1:n, R(:, :, j) = q2r(Q(j, :)); end
end

function R = q2r(qt)
w = qt(1); x = qt(2); y = qt(3); z = qt(4);
R = [1 - 2*(y^2 + z^2), 2*(x*y - z*w),     2*(x*z + y*w);
     2*(x*y + z*w),     1 - 2*(x^2 + z^2), 2*(y*z - x*w);
     2*(x*z - y*w),     2*(y*z + x*w),     1 - 2*(x^2 + y^2)];
end
