function T = desktop_d18_progress_stop()
%DESKTOP_D18_PROGRESS_STOP  Stopp nach dem Minimum und Neustart beim Set-Point-Agenten (D18).
%   T = desktop_d18_progress_stop()
%
%   Frage (Labortag 2, 03.10.): In den nicht konvergierten Laeufen von S20_targets erreicht der Arm
%   ein Minimum und entfernt sich danach wieder vom Ziel. Hilft es, nach dem Minimum zu stoppen,
%   oder dort anzuhalten, Agent und Befehlskette neu zu laden und weiterzufahren?
%
%   Kinematischer Trockenlauf von deploy_setpoint_v24 (er trifft die Hardware in C2 auf +-2 mm).
%   Zuerst Kontrolle: progressRule 'none' muss day2_dryrun_prediction.csv reproduzieren. Dann die
%   19 Kombinationen von S20_targets, die dort nicht konvergieren, mit vier Varianten:
%   none, stop, restart (1 Neustart), restart (bis 5 Neustarts). Regel: ||ep|| liegt 3 Schritte in
%   Folge mehr als 5 mm ueber dem bisherigen Minimum.
%   Ergebnis: data/simulation/desktop/D18_progress_stop_<Zeit>.csv

setup_project;
tmp = tempname; mkdir(tmp);
cleanup = onCleanup(@() rmdir(tmp, 's'));
dry = {'dryRun', true, 'showPlots', false, 'saveRoot', tmp};

% Kontrolle: Standard unveraendert
P = readtable(sk_path('hardware', 'campaign', 'day2_dryrun_prediction.csv'), 'CommentStyle', '#', ...
              'TextType', 'string');
dmax = 0;
for i = 1:height(P)
    m = run_one(char(P.target(i)), char(P.start(i)), dry, {});
    assert(strcmp(m.stopReason, P.stopReason(i)), 'Kontrolle: %s %s Stoppgrund %s statt %s.', ...
           P.target(i), P.start(i), m.stopReason, P.stopReason(i));
    dmax = max(dmax, abs(m.finalErr_m - P.finalErr_m(i)));
end
fprintf('Kontrolle: %d Laeufe wie day2_dryrun_prediction.csv, Endfehler max. %.2g m Abweichung\n', ...
        height(P), dmax);
assert(dmax < 1e-6, 'Kontrolle: Endfehler weicht ab.');

idx = find(P.stopReason ~= "converged");
modes = {'none', {}; 'stop', {'progressRule', 'stop'}; ...
         'restart1', {'progressRule', 'restart', 'maxRestarts', 1}; ...
         'restart5', {'progressRule', 'restart', 'maxRestarts', 5}};
rows = {};
for i = idx(:).'
    for j = 1:size(modes, 1)
        m = run_one(char(P.target(i)), char(P.start(i)), dry, modes{j, 2});
        rows{end + 1} = struct('target', P.target(i), 'start', P.start(i), 'mode', string(modes{j, 1}), ...
            'stopReason', string(m.stopReason), 'nRestarts', m.nRestarts, 'finalErr_m', m.finalErr_m, ...
            'minErr_m', m.minErr_m, 'tEnd_s', m.tEnd); %#ok<AGROW>
        fprintf('%s %s %-9s %-14s Endfehler %6.1f mm, Minimum %6.1f mm, %4.1f s, Neustarts %d\n', ...
                P.target(i), P.start(i), modes{j, 1}, m.stopReason, 1e3 * m.finalErr_m, ...
                1e3 * m.minErr_m, m.tEnd, m.nRestarts);
    end
end
T = struct2table([rows{:}]);
out = sk_path('data', 'simulation', 'desktop', ['D18_progress_stop_' ...
    char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')) '.csv']);
writetable(T, out);
fprintf('Ergebnis: %s\n', out);
end

function m = run_one(targetId, startId, dry, extra)
evalc('r = deploy_setpoint_v24(''S20_targets'', startId, 0, ''targetId'', targetId, dry{:}, extra{:});');
L = load(r.file);
m = L.run.meta;
end
