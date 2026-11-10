function ext_x2_4_night()
%EXT_X2_4_NIGHT  Kette fuer die Nacht nach X4.1 (10./11.11.2026): Modell neu bauen, X2.4, Robustheit, X1.2.
%   ext_x2_4_night()
%
%   1. SK_desktop mit dem aktuellen desktop_build_model neu bauen (Modus 5, Kostensignal, Masse und Verzoegerung
%      mit Fast Restart aenderbar) und gegen die Basislinie aus X0.1 pruefen. Bei Abweichung Abbruch.
%      Danach die Testkopien SK_x1test und SK_x2test loeschen.
%   2. X2.4: ext_x2_4_train fuer 'M' und 'full', Seeds 0-9, je 3000 Episoden (vorhandene uebersprungen).
%      Protokoll X2_4_runlog.csv.
%   3. ext_x2_robust mit allen r4-Agenten (D16, D17 inklusive X4.1) und den X2.4-Agenten.
%   4. Pilot X1.2 (ext_x1_2_run).
%   5. X4.2: alle Bestandsagenten mit dem Protokoll X0.1 (ext_x4_2_run, ergaenzt 10.11. abends, etwa 30 min).
%   Gestartet von einem PowerShell-Prozess, der auf das Ende von X4.1 wartet.

setup_project;
t0 = tic;
fprintf('=== Nacht: SK_desktop neu bauen ===\n');
desktop_build_model(true);
T = ext_x0_check_model('compare');
assert(all(T.maxAbsDiff == 0), 'ext_x2_4_night:bit', 'SK_desktop nicht bitgleich zur Basislinie, Abbruch');
for m = {'SK_x1test', 'SK_x2test'}
    f = sk_path('evaluation', 'desktop', 'models', [m{1} '.slx']);
    if isfile(f), delete(f); end
end

fprintf('\n=== Nacht: X2.4 (%.0f min) ===\n', toc(t0) / 60);
logFile = sk_path('data', 'simulation', 'extension', 'X2_4_runlog.csv');
for seed = 0:9
    for v = {'M', 'full'}
        name = sprintf('X2_4_ppo_40hz_r4_dr%s_seed%d_ep3000', v{1}, seed);
        if isfile(sk_path('SavedAgents', 'MotionProfile', 'X2_4', [name '.mat'])), continue; end
        t1 = tic; ok = true; msg = "-";
        try
            ext_x2_4_train(v{1}, seed);
        catch err
            ok = false; msg = string(err.message);
            fprintf(2, 'X2.4: %s fehlgeschlagen: %s\n', name, msg);
        end
        row = table(string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), string(name), ok, ...
                    toc(t1) / 60, msg, 'VariableNames', {'time', 'name', 'ok', 'minutes', 'error'});
        if isfile(logFile), row = [readtable(logFile, 'TextType', 'string'); row]; end %#ok<AGROW>
        writetable(row, logFile);
    end
end

fprintf('\n=== Nacht: Robustheit mit allen Agenten (%.0f min) ===\n', toc(t0) / 60);
try
    ext_x2_robust('agents', allAgents());
catch err
    fprintf(2, 'Robustheit fehlgeschlagen: %s\n', err.message);
end

fprintf('\n=== Nacht: Pilot X1.2 (%.0f min) ===\n', toc(t0) / 60);
try
    ext_x1_2_run();
catch err
    fprintf(2, 'X1.2 fehlgeschlagen: %s\n', err.message);
end

fprintf('\n=== Nacht: X4.2 Bestandsagenten (%.0f min) ===\n', toc(t0) / 60);
try
    ext_x4_2_run();
catch err
    fprintf(2, 'X4.2 fehlgeschlagen: %s\n', err.message);
end
fprintf('\n=== Nacht fertig nach %.0f min ===\n', toc(t0) / 60);
end

% =====================================================================
function list = allAgents()
% r4-Agenten mit 3000 Episoden (D16 Gewicht 2, D17 alle Gewichte, inklusive X4.1) und alle X2.4-Agenten
ma = sk_path('SavedAgents', 'MotionProfile');
list = struct('file', {}, 'label', {}, 'group', {});
d = dir(fullfile(ma, 'D16', 'D16_ppo_40hz_r4_seed*_ep3000.mat'));
for k = 1:numel(d)
    s = regexp(d(k).name, 'seed(\d+)_', 'tokens', 'once');
    list(end + 1) = struct('file', fullfile(d(k).folder, d(k).name), 'label', ['w2_s' s{1}], 'group', 'rl'); %#ok<AGROW>
end
d = dir(fullfile(ma, 'D17', 'D17_ppo_40hz_r4_w*_seed*_ep3000.mat'));
for k = 1:numel(d)
    t = regexp(d(k).name, '_w([\d.]+)_seed(\d+)_', 'tokens', 'once');
    list(end + 1) = struct('file', fullfile(d(k).folder, d(k).name), 'label', ['w' t{1} '_s' t{2}], ...
                           'group', 'rl'); %#ok<AGROW>
end
d = dir(fullfile(ma, 'X2_4', 'X2_4_ppo_40hz_r4_dr*_seed*_ep3000.mat'));
for k = 1:numel(d)
    t = regexp(d(k).name, '_dr(\w+?)_seed(\d+)_', 'tokens', 'once');
    list(end + 1) = struct('file', fullfile(d(k).folder, d(k).name), 'label', ['dr' t{1} '_s' t{2}], ...
                           'group', ['dr_' t{1}]); %#ok<AGROW>
end
end
