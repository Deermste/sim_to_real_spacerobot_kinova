function ext_x4_1_run(weights, seeds, nEpisodes)
%EXT_X4_1_RUN  Gewichtsreihe des glatten Basis-Terms auf 10 Seeds auffuellen (Ausbau X4.1, Entscheidung E3).
%   ext_x4_1_run()                 alle fehlenden Laeufe (Gewichte 0, 2, 4, 8, 16, Seeds 0-9, 3000 Episoden),
%                                  danach ext_x4_1_eval
%   ext_x4_1_run(4, 3, 16)         Kurztest (tag 'test', Ablage in data/simulation/desktop/_test, keine Auswertung)
%
%   Aufbau genau wie D17 (desktop_d17_run): desktop_d12_train(4, s, 3000, '', 'base_sync', 0.9774, w). Reward-Modus
%   4, Optionen des fruehen PPO mit synchronem Training und Gradient Clipping, J6 0,9774 rad/s, 40 Hz, 65 kg. Damit
%   sind die neuen Agenten mit D16 (Gewicht 2, Seeds 0-7) und D17 (Gewichte 0, 4, 8, 16, Seeds 0-2) zusammen
%   auswertbar. Gewicht 2 landet wie in D16 unter SavedAgents/MotionProfile/D16, die anderen unter .../D17.
%   Vorhandene Agenten werden uebersprungen, ein abgebrochener Lauf kann also einfach neu gestartet werden.
%   Reihenfolge: Seed aussen, Gewicht innen. Bricht der Lauf ab, sind die Gewichte gleich weit aufgefuellt.
%   Protokoll je Lauf in data/simulation/extension/X4_1_runlog.csv.

if nargin < 1 || isempty(weights), weights = [0 2 4 8 16]; end
if nargin < 2 || isempty(seeds), seeds = 0:9; end
if nargin < 3 || isempty(nEpisodes), nEpisodes = 3000; end
tag = '';
if nEpisodes < 1000, tag = 'test'; end

setup_project;
ma = sk_path('SavedAgents', 'MotionProfile');
logFile = sk_path('data', 'simulation', 'extension', 'X4_1_runlog.csv');
if ~isempty(tag), logFile = strrep(logFile, '.csv', '_test.csv'); end
todo = zeros(0, 2);
for s = seeds
    for w = weights
        if isempty(tag) && isfile(agentFile(ma, w, s, nEpisodes)), continue; end
        todo(end + 1, :) = [w s]; %#ok<AGROW>
    end
end
fprintf('X4.1: %d Laeufe offen, %d Episoden je Lauf\n', size(todo, 1), nEpisodes);
t0 = tic;
for k = 1:size(todo, 1)
    w = todo(k, 1); s = todo(k, 2);
    fprintf('\n=== X4.1: Lauf %d/%d, Gewicht %g, Seed %d (%.0f min seit Start) ===\n', k, size(todo, 1), w, s, ...
            toc(t0) / 60);
    t1 = tic; ok = true; msg = '-';
    try
        out = desktop_d12_train(4, s, nEpisodes, tag, 'base_sync', 0.9774, w);
        file = out.agentFile;
    catch err
        ok = false; msg = err.message; file = '';
        fprintf(2, 'X4.1: Gewicht %g, Seed %d fehlgeschlagen: %s\n', w, s, msg);
    end
    row = table(string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), w, s, nEpisodes, ok, ...
                toc(t1) / 60, string(file), string(msg), 'VariableNames', ...
                {'time', 'weight', 'seed', 'episodes', 'ok', 'minutes', 'file', 'error'});
    if isfile(logFile), row = [readtable(logFile, 'TextType', 'string'); row]; end %#ok<AGROW>
    writetable(row, logFile);
end
fprintf('\nX4.1: Training fertig nach %.0f min\n', toc(t0) / 60);
if isempty(tag)
    ext_x4_1_eval();
end
end

% =====================================================================
function f = agentFile(ma, w, s, nEp)
% Dateiname wie in desktop_d12_train (Gewicht 2 ohne _w, Studie D16, sonst D17)
if w == 2
    f = fullfile(ma, 'D16', sprintf('D16_ppo_40hz_r4_seed%d_ep%d.mat', s, nEp));
else
    f = fullfile(ma, 'D17', sprintf('D17_ppo_40hz_r4_w%g_seed%d_ep%d.mat', w, s, nEp));
end
end
