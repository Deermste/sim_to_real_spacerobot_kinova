function out = media_fig_tradeoff_res(varargin)
%MEDIA_FIG_TRADEOFF_RES  Zielkonflikt-Grafik wie media_fig_tradeoff, dazu die Residual-Agenten aus X7 (15.11.2026).
%   out = media_fig_tradeoff_res()      Paper (eine Spalte), Folie (gross) und Folie mit Ausschnitt um die Front
%
%   Daten (kein neues Rechnen):
%   - Reine RL-Agenten wie media_fig_tradeoff (X2_2_agents, Lesart nominal).
%   - Front: Pareto-Punkte aus F0 (X2.2) und dem dichten Sweep X2_sweep_20261115_104006 (Kp 5 bis 20,
%     beta logspace(0, 2, 25), volle Kette mit Inversion, J6-Seite -1). Gegen diese Front gilt der Faktor 0,91 /
%     0,93 aus X7.3. Damit liegt die Front etwas tiefer als in tradeoff_*.
%   - Residual RL: 20 Agenten (Seeds 1 bis 10 aus X7_C, Seeds 11 bis 20 aus X7_T2), nominale Episode aus X0.1.
%   - C2: klassischer Regler am Ort der Policy (Kp 12, beta 26,1), Vergleichsregler aus X7.3.
%   Ergebnis: media/figures/tradeoff_res_{paper,slide,zoom}.{pdf,png}

p = inputParser;
p.addParameter('outDir', '');
p.parse(varargin{:});
o = p.Results;
setup_project;
if isempty(o.outDir), o.outDir = sk_path('media', 'figures'); end
if ~isfolder(o.outDir), mkdir(o.outDir); end
dd = sk_path('data', 'simulation', 'extension');
A = readtable(fullfile(dd, 'X2_2_agents_20261113_083657.csv'), 'TextType', 'string');
A = A(A.reading == "nom", :);
grp = repmat("", height(A), 1);
grp(startsWith(A.group, "w")) = "weight";
grp(startsWith(A.group, "th")) = "budget";
grp(A.group == "r1") = "r1";
assert(all(grp ~= ""), 'media_fig_tradeoff_res:group', 'unbekannte Gruppe');
A.grp = grp;
F0 = readtable(fullfile(dd, 'X2_2_front_20261113_083657.csv'), 'TextType', 'string');
F0 = F0(F0.front == "F0", :);
Sw = readtable(fullfile(dd, 'X2_sweep_20261115_104006.csv'), 'TextType', 'string');
P = [F0(:, {'Kp', 'beta', 'rms_ee', 'ori_max'}); Sw(:, {'Kp', 'beta', 'rms_ee', 'ori_max'})];
P = sortrows(P, {'ori_max', 'rms_ee'});
keep = false(height(P), 1); best = inf;
for i = 1:height(P)
    if P.rms_ee(i) < best, keep(i) = true; best = P.rms_ee(i); end
end
F = P(keep, :);
R1 = readtable(fullfile(dd, 'X7_C_agents_20261115_060632.csv'), 'TextType', 'string');
R2 = readtable(fullfile(dd, 'X7_T2_agents_20261115_144722.csv'), 'TextType', 'string');
Res = [R1(R1.group == "res_res", :); R2(R2.group == "res_res", :)];
assert(height(Res) == 20 && all(Res.follows == 1), 'media_fig_tradeoff_res:res', 'erwartet 20 folgende Agenten');
bC2 = logspace(0, 2, 25);
c2 = Sw(Sw.Kp == 12 & abs(Sw.beta - bC2(18)) < 1e-9, :);
assert(height(c2) == 1, 'media_fig_tradeoff_res:c2', 'C2 nicht eindeutig');
fprintf('%d RL-Agenten, %d Frontpunkte, 20 Residual (Median %.2f mm / %.1f mrad), C2 %.2f mm / %.1f mrad\n', ...
        height(A), height(F), 1000 * median(Res.nom_rms_ee), 1000 * median(Res.nom_ori_max), ...
        1000 * c2.rms_ee, 1000 * c2.ori_max);

S = struct('name', {'paper', 'slide', 'zoom'}, 'size', {[3.5 3.3], [9 6.4], [9 6.4]}, 'fs', {7.5, 14, 14}, ...
           'ms', {4.5, 9, 11}, 'lw', {1.2, 2.2, 2.2}, 'zoom', {false, false, true});
for s = S
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'inches', 'Position', [0 0 s.size]);
    try, fig.Theme = 'light'; catch, end     % matlab -batch nimmt sonst das dunkle Theme
    ax = axes(fig, 'Color', 'w'); hold(ax, 'on');
    plotIt(ax, A, F, Res, c2, s);
    base = fullfile(o.outDir, ['tradeoff_res_' s.name]);
    exportgraphics(fig, [base '.png'], 'Resolution', 300);
    exportgraphics(fig, [base '.pdf'], 'ContentType', 'vector');
    close(fig);
    fprintf('%s.pdf / .png\n', base);
end
out = struct('dir', o.outDir, 'front', F, 'res', Res, 'c2', c2);
end

% =====================================================================
function plotIt(ax, A, F, Res, c2, s)
ink = [0.04 0.04 0.04]; ink2 = [0.32 0.32 0.31];
C = struct('weight', [0.165 0.471 0.839], 'budget', [0.922 0.408 0.204], 'r1', [0.106 0.686 0.478], ...
           'res', [0.929 0.631 0]);
mk = struct('weight', 'o', 'budget', '^', 'r1', 's');
lbl = struct('weight', 'RL, weighted base term', 'budget', 'RL, base budget', 'r1', 'RL, tracking only');
x = @(r) rad2deg(r);
y = @(m) 1000 * m;
if s.zoom
    xl = [0.6 1.6]; yl = [4 16];
else
    xl = [0.12 8]; yl = [1 400];
end
fx = x(F.ori_max); fy = y(F.rms_ee);
[sx, sy] = stairs(fx, fy);
fill(ax, [0.05; sx; 20; 20; 0.05], [sy(1); sy; sy(end); 0.5; 0.5], [0.94 0.94 0.93], 'EdgeColor', 'none');
hF = plot(ax, sx, sy, '-', 'Color', ink, 'LineWidth', s.lw * 1.4);
% Die dichte Front hat 65 Punkte, deshalb nur die Linie (ohne Punktmarken)
G = ["weight", "budget", "r1"];
h = gobjects(1, 3);
nG = 3;
if s.zoom, nG = 0; end                       % Ausschnitt: nur Front, Residual und C2
for k = 1:nG
    g = G(k);
    Ag = A(A.grp == g, :);
    fo = Ag.follows == 1;
    plot(ax, x(Ag.ori_max(~fo)), y(Ag.rms_ee(~fo)), mk.(g), 'MarkerSize', s.ms, 'MarkerEdgeColor', C.(g), ...
         'MarkerFaceColor', 'none', 'LineWidth', 0.8);
    h(k) = plot(ax, x(Ag.ori_max(fo)), y(Ag.rms_ee(fo)), mk.(g), 'MarkerSize', s.ms, 'MarkerFaceColor', C.(g), ...
                'MarkerEdgeColor', 'w', 'LineWidth', 0.5);
end
% Residual: Raute, dunkler Rand (Gelb hat wenig Kontrast zum Hintergrund)
hR = plot(ax, x(Res.nom_ori_max), y(Res.nom_rms_ee), 'd', 'MarkerSize', s.ms * 1.05, 'MarkerFaceColor', C.res, ...
          'MarkerEdgeColor', ink, 'LineWidth', 0.6);
% C2: klassischer Regler am selben Ort
hC = plot(ax, x(c2.ori_max), y(c2.rms_ee), 'p', 'MarkerSize', s.ms * 1.9, 'MarkerFaceColor', 'w', ...
          'MarkerEdgeColor', ink, 'LineWidth', s.lw * 0.8);
set(ax, 'XScale', 'log', 'YScale', 'log', 'Box', 'off', 'TickDir', 'out', 'FontSize', s.fs, 'XColor', ink2, ...
    'YColor', ink2, 'LineWidth', 0.6, 'Layer', 'top');
xlim(ax, xl); ylim(ax, yl);
if s.zoom
    ax.XTick = [0.6 0.8 1 1.2 1.4 1.6]; ax.YTick = [4 5 6 7 8 10 12 16];
else
    ax.XTick = [0.15 0.25 0.5 1 2 4 8]; ax.YTick = [1 2 5 10 20 50 100 200];
end
ax.XTickLabel = compose('%g°', ax.XTick); ax.YTickLabel = string(ax.YTick);
grid(ax, 'on'); ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1; ax.MinorGridLineStyle = 'none';
ax.XMinorTick = 'off'; ax.YMinorTick = 'off';
xlabel(ax, 'Largest base rotation in the episode', 'Color', ink);
ylabel(ax, 'End-effector error, RMS [mm]', 'Color', ink);
if s.zoom
    text(ax, 0.62, 4.3, 'beyond the controller front', 'FontSize', s.fs * 0.9, 'Color', ink2, ...
         'FontAngle', 'italic');
    tx = 1.08; ty = 10.5;
    plot(ax, [x(c2.ori_max) * 1.01, tx * 0.99], [y(c2.rms_ee) * 1.04, ty * 0.97], '-', 'Color', ink2, ...
         'LineWidth', 0.8);
    text(ax, tx, ty, {'C2: classical controller', 'at the same point'}, 'FontSize', s.fs * 0.85, 'Color', ink, ...
         'VerticalAlignment', 'bottom');
    leg = legend(ax, [hF, hR, hC], {'Controller front (R\beta, exact model)', ...
                 'Residual RL: controller + learned correction (20 seeds)', 'C2 (same point on the front)'}, ...
                 'Location', 'northoutside', 'NumColumns', 1, 'FontSize', s.fs * 0.85, 'Box', 'off', ...
                 'TextColor', ink);
else
    text(ax, 0.13, 1.45, {'Controller front', '(exact model)'}, 'FontSize', s.fs, 'Color', ink, ...
         'VerticalAlignment', 'bottom');
    text(ax, 0.6, 1.3, 'beyond the controller front', 'FontSize', s.fs * 0.9, 'Color', ink2, 'FontAngle', 'italic');
    text(ax, 0.62, 3.1, {'Residual RL', 'on the front'}, 'FontSize', s.fs * 0.9, 'Color', ink, ...
         'HorizontalAlignment', 'left');
    hH = plot(ax, NaN, NaN, 'o', 'MarkerSize', s.ms, 'MarkerEdgeColor', ink2, 'MarkerFaceColor', 'none', ...
               'LineWidth', 0.8);
    leg = legend(ax, [hF, h, hR, hC, hH], {'Controller front (R\beta)', lbl.weight, lbl.budget, lbl.r1, ...
                 'Residual RL (controller + correction)', 'C2: controller at the same point', ...
                 'hollow: loses the path'}, 'Location', 'northoutside', 'NumColumns', 2, ...
                 'FontSize', s.fs * 0.85, 'Box', 'off', 'TextColor', ink);
end
leg.ItemTokenSize = [12 8] * s.fs / 7.5;
end
