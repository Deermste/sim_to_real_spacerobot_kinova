function out = media_fig_tradeoff_3d(varargin)
%MEDIA_FIG_TRADEOFF_3D  Technische 2D-Grafik wie media_fig_tradeoff, fuer die 3D-Bahn (X5.3, 14.11.2026).
%   out = media_fig_tradeoff_3d()               Paper (eine Spalte, PDF und PNG) und Folie (gross, PNG)
%
%   Daten (kein neues Rechnen): X5_3_summary (ext_x5_3_summary, je 10 Seeds r4 und x1, letzter Agent und bester
%   Zwischenstand) und X5_3_front (Regler Rbeta und Prioritaet, alle sieben Gelenke, volle Kette mit Inversion,
%   nur folgende Laeufe, Pareto-Punkte). Bahn tilted -30, alle sieben Gelenke, Grenzen der Agenten.
%   Lesart nominal (Startstellung wie die Front). Achsen logarithmisch: x groesste Basisdrehung [Grad], y RMS-Fehler
%   des Endeffektors [mm]. Gefuellt: bester Zwischenstand folgt (X0.1-Definition), hohl: folgt nicht. Kleiner
%   Punkt: letzter Agent desselben Laufs, mit einer Linie zum besten Zwischenstand.
%   Ergebnis: media/figures/tradeoff3d_{paper,slide}.{pdf,png}

p = inputParser;
p.addParameter('outDir', '');
p.addParameter('summary', 'X5_3_summary_20261114_231420.csv');
p.parse(varargin{:});
o = p.Results;
setup_project;
if isempty(o.outDir), o.outDir = sk_path('media', 'figures'); end
if ~isfolder(o.outDir), mkdir(o.outDir); end
dd = sk_path('data', 'simulation', 'extension');
A = readtable(fullfile(dd, o.summary), 'TextType', 'string');
F = readtable(fullfile(dd, 'X5_3_front_20261114_150547.csv'), 'TextType', 'string');
F = F(F.front & F.chain == "full" & F.follows == 1, :);
F = sortrows(F, 'ori_max');
fprintf('%d Agenten, %d Frontpunkte\n', height(A), height(F));
S = struct('name', {'paper', 'slide'}, 'size', {[3.5 3.1], [9 6.2]}, 'fs', {7.5, 14}, 'ms', {4.5, 9}, ...
           'lw', {1.2, 2.2});
for s = S
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'inches', 'Position', [0 0 s.size]);
    ax = axes(fig); hold(ax, 'on');
    plotIt(ax, A, F, s);
    base = fullfile(o.outDir, ['tradeoff3d_' s.name]);
    exportgraphics(fig, [base '.png'], 'Resolution', 300);
    exportgraphics(fig, [base '.pdf'], 'ContentType', 'vector');
    close(fig);
    fprintf('%s.pdf / .png\n', base);
end
out = struct('dir', o.outDir);
end

% =====================================================================
function plotIt(ax, A, F, s)
ink = [0.04 0.04 0.04]; ink2 = [0.32 0.32 0.31];
C = struct('r4', [0.165 0.471 0.839], 'x1', [0.922 0.408 0.204]);
mk = struct('r4', 'o', 'x1', '^');
lbl = struct('r4', 'RL, weighted base term (r4)', 'x1', 'RL, base budget 1°43′ (x1)');
x = @(r) rad2deg(r);
y = @(m) 1000 * m;
fx = x(F.ori_max); fy = y(F.rms_ee);
[sx, sy] = stairs(fx, fy);
fill(ax, [0.05; sx; 20; 20; 0.05], [sy(1); sy; sy(end); 0.5; 0.5], [0.94 0.94 0.93], 'EdgeColor', 'none');
hF = plot(ax, sx, sy, '-', 'Color', ink, 'LineWidth', s.lw * 1.4);
plot(ax, fx, fy, 'o', 'MarkerSize', s.ms * 0.8, 'MarkerFaceColor', ink, 'MarkerEdgeColor', 'w', 'LineWidth', 0.5);
V = ["r4", "x1"];
h = gobjects(1, 2);
for k = 1:2
    v = V(k);
    B = A(A.variant == v & A.stage == "best_ckpt", :);
    L = A(A.variant == v & A.stage == "final", :);
    [~, ib, il] = intersect(B.seed, L.seed);
    for j = 1:numel(ib)
        plot(ax, x([B.nom_ori_max(ib(j)) L.nom_ori_max(il(j))]), y([B.nom_rms_ee(ib(j)) L.nom_rms_ee(il(j))]), ...
             '-', 'Color', 0.4 * C.(v) + 0.6, 'LineWidth', 0.5);
    end
    plot(ax, x(L.nom_ori_max), y(L.nom_rms_ee), '.', 'MarkerSize', s.ms * 1.6, 'Color', C.(v));
    fo = B.follows == 1;
    plot(ax, x(B.nom_ori_max(~fo)), y(B.nom_rms_ee(~fo)), mk.(v), 'MarkerSize', s.ms, 'MarkerEdgeColor', C.(v), ...
         'MarkerFaceColor', 'none', 'LineWidth', 0.8);
    h(k) = plot(ax, x(B.nom_ori_max(fo)), y(B.nom_rms_ee(fo)), mk.(v), 'MarkerSize', s.ms, ...
                'MarkerFaceColor', C.(v), 'MarkerEdgeColor', 'w', 'LineWidth', 0.5);
end
plot(ax, x([0.03 0.03]), [1 400], ':', 'Color', C.x1, 'LineWidth', 0.8);
set(ax, 'XScale', 'log', 'YScale', 'log', 'Box', 'off', 'TickDir', 'out', 'FontSize', s.fs, 'XColor', ink2, ...
    'YColor', ink2, 'LineWidth', 0.6, 'Layer', 'top');
ax.Color = 'w';
xlim(ax, [0.12 8]); ylim(ax, [1 400]);
ax.XTick = [0.15 0.25 0.5 1 2 4 8]; ax.XTickLabel = compose('%g°', ax.XTick);
ax.YTick = [1 2 5 10 20 50 100 200]; ax.YTickLabel = string(ax.YTick);
grid(ax, 'on'); ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1; ax.MinorGridLineStyle = 'none';
ax.XMinorTick = 'off'; ax.YMinorTick = 'off';
xlabel(ax, 'Largest base rotation in the episode', 'Color', ink);
ylabel(ax, 'End-effector error, RMS [mm]', 'Color', ink);
text(ax, 0.13, 55, {'Controller front', '(exact model)'}, 'FontSize', s.fs, 'Color', ink, ...
     'VerticalAlignment', 'bottom');
text(ax, 0.2, 1.3, 'beyond the controller front', 'FontSize', s.fs * 0.9, 'Color', ink2, 'FontAngle', 'italic');
text(ax, x(0.03) * 1.05, 250, 'budget', 'FontSize', s.fs * 0.85, 'Color', ink2);
hH = plot(ax, NaN, NaN, 'o', 'MarkerSize', s.ms, 'MarkerEdgeColor', ink2, 'MarkerFaceColor', 'none', ...
           'LineWidth', 0.8);
hL = plot(ax, NaN, NaN, '.', 'MarkerSize', s.ms * 1.6, 'Color', ink2);
leg = legend(ax, [hF, h, hH, hL], {'Controller front (R\beta)', lbl.r4, lbl.x1, 'hollow: loses the path', ...
             'dot: final agent of the run'}, 'Location', 'northoutside', 'NumColumns', 2, ...
             'FontSize', s.fs * 0.85, 'Box', 'off', 'TextColor', ink);
leg.ItemTokenSize = [12 8] * s.fs / 7.5;
end
