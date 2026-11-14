function out = media_fig_tradeoff(varargin)
%MEDIA_FIG_TRADEOFF  Technische 2D-Grafik: Bahnfehler gegen Basisdrehung, alle Agenten gegen die Front des Reglers.
%   out = media_fig_tradeoff()                  Paper (eine Spalte, PDF und PNG) und Folie (gross, PNG)
%
%   Daten (kein neues Rechnen): X2_2_agents und X2_2_front (X2.2, 13.11.2026). Agenten: Gewichtsreihe X4.1
%   (50, D16/D17 und Gewichte 0 bis 16), Budget-Reihe X1.3 (50, theta 0,02 bis 0,06), r1 ohne Basis-Term (10).
%   Lesart nominal (Startstellung wie die Front). Front F0: Pareto-Punkte des Reglers aus X2.1 (exaktes Modell,
%   volle Befehlskette mit Inversion, nur folgende Laeufe).
%   Achsen logarithmisch: x groesste Basisdrehung [Grad], y RMS-Fehler des Endeffektors [mm].
%   Gefuellt: Agent folgt der Bahn (X0.1-Definition), hohl: folgt nicht. Farbe und Form je Gruppe (Farben 1 bis 3
%   der Referenzpalette, fuer Streudiagramme mit allen Paaren geprueft, Form als zweite Kodierung).
%   Ergebnis: media/figures/tradeoff_{paper,slide}.{pdf,png}

p = inputParser;
p.addParameter('outDir', '');
p.parse(varargin{:});
o = p.Results;
setup_project;
if isempty(o.outDir), o.outDir = sk_path('media', 'figures'); end
if ~isfolder(o.outDir), mkdir(o.outDir); end
dd = sk_path('data', 'simulation', 'extension');
A = readtable(fullfile(dd, 'X2_2_agents_20261113_083657.csv'), 'TextType', 'string');
F = readtable(fullfile(dd, 'X2_2_front_20261113_083657.csv'), 'TextType', 'string');
A = A(A.reading == "nom", :);
F = F(F.front == "F0", :);
F = sortrows(F, 'ori_max');
grp = repmat("", height(A), 1);
grp(startsWith(A.group, "w")) = "weight";
grp(startsWith(A.group, "th")) = "budget";
grp(A.group == "r1") = "r1";
assert(all(grp ~= ""), 'media_fig_tradeoff:group', 'unbekannte Gruppe');
A.grp = grp;
fprintf('%d Agenten (%d folgen), %d Frontpunkte\n', height(A), sum(A.follows), height(F));

S = struct('name', {'paper', 'slide'}, 'size', {[3.5 3.1], [9 6.2]}, 'fs', {7.5, 14}, 'ms', {4.5, 9}, ...
           'lw', {1.2, 2.2});
for s = S
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'inches', 'Position', [0 0 s.size]);
    ax = axes(fig); hold(ax, 'on');
    plotIt(ax, A, F, s);
    base = fullfile(o.outDir, ['tradeoff_' s.name]);
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
C = struct('weight', [0.165 0.471 0.839], 'budget', [0.922 0.408 0.204], 'r1', [0.106 0.686 0.478]);
mk = struct('weight', 'o', 'budget', '^', 'r1', 's');
lbl = struct('weight', 'RL, weighted base term', 'budget', 'RL, base budget', 'r1', 'RL, tracking only');
x = @(r) rad2deg(r);
y = @(m) 1000 * m;
% Treppenkurve der Front: bei hoechstens x Grad Basisdrehung erreicht der Regler hoechstens y mm (Pareto).
% Darunter (hellgrau) liegt der Bereich jenseits der Front, den auch der Regler nicht erreicht.
fx = x(F.ori_max); fy = y(F.rms_ee);
[sx, sy] = stairs(fx, fy);
hb = fill(ax, [0.05; sx; 20; 20; 0.05], [sy(1); sy; sy(end); 0.5; 0.5], [0.94 0.94 0.93], ...
          'EdgeColor', 'none'); %#ok<NASGU>
hF = plot(ax, sx, sy, '-', 'Color', ink, 'LineWidth', s.lw * 1.4);
plot(ax, fx, fy, 'o', 'MarkerSize', s.ms * 0.8, 'MarkerFaceColor', ink, 'MarkerEdgeColor', 'w', 'LineWidth', 0.5);
G = ["weight", "budget", "r1"];
h = gobjects(1, 3);
for k = 1:3
    g = G(k);
    Ag = A(A.grp == g, :);
    fo = Ag.follows == 1;
    % nicht folgend: hohl, ohne Legende
    plot(ax, x(Ag.ori_max(~fo)), y(Ag.rms_ee(~fo)), mk.(g), 'MarkerSize', s.ms, 'MarkerEdgeColor', C.(g), ...
         'MarkerFaceColor', 'none', 'LineWidth', 0.8);
    h(k) = plot(ax, x(Ag.ori_max(fo)), y(Ag.rms_ee(fo)), mk.(g), 'MarkerSize', s.ms, 'MarkerFaceColor', C.(g), ...
                'MarkerEdgeColor', 'w', 'LineWidth', 0.5);
end
set(ax, 'XScale', 'log', 'YScale', 'log', 'Box', 'off', 'TickDir', 'out', 'FontSize', s.fs, 'XColor', ink2, ...
    'YColor', ink2, 'LineWidth', 0.6, 'Layer', 'top');
xlim(ax, [0.12 8]); ylim(ax, [1 400]);
ax.XTick = [0.15 0.25 0.5 1 2 4 8]; ax.XTickLabel = compose('%g°', ax.XTick);
ax.YTick = [1 2 5 10 20 50 100 200]; ax.YTickLabel = string(ax.YTick);
grid(ax, 'on'); ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1; ax.MinorGridLineStyle = 'none';
ax.XMinorTick = 'off'; ax.YMinorTick = 'off';
xlabel(ax, 'Largest base rotation in the episode', 'Color', ink);
ylabel(ax, 'End-effector error, RMS [mm]', 'Color', ink);
% Beschriftungen direkt im Bild
text(ax, 0.13, 1.45, {'Controller front', '(exact model)'}, 'FontSize', s.fs, 'Color', ink, ...
     'VerticalAlignment', 'bottom');
text(ax, 0.6, 1.3, 'beyond the controller front', 'FontSize', s.fs * 0.9, 'Color', ink2, 'FontAngle', 'italic');
hH = plot(ax, NaN, NaN, 'o', 'MarkerSize', s.ms, 'MarkerEdgeColor', ink2, 'MarkerFaceColor', 'none', ...
           'LineWidth', 0.8);
leg = legend(ax, [hF, h, hH], {'Controller front (R\beta)', lbl.weight, lbl.budget, lbl.r1, ...
             'hollow: loses the path'}, 'Location', 'northoutside', 'NumColumns', 2, ...
             'FontSize', s.fs * 0.85, 'Box', 'off', 'TextColor', ink);
leg.ItemTokenSize = [12 8] * s.fs / 7.5;
end
