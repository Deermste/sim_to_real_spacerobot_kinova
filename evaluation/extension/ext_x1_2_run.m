function ext_x1_2_run()
%EXT_X1_2_RUN  Pilot fuer die Nebenbedingung (Ausbau X1.2): Kostenform und Schrittweite.
%   ext_x1_2_run()
%
%   theta 0,03 rad, Kandidat A (cost_type 1) und B (2), eta 0,5 und 2, Seeds 0 und 1, je 3000 Episoden in Bloecken
%   zu 100 (ext_x1_train). 8 Laeufe. Vorhandene Agenten werden uebersprungen. Protokoll X1_2_runlog.csv.
%   Auswahl danach (Entscheidung E2): lambda konvergiert ohne Dauerschwingung, Budget gehalten, Bahn gefolgt.

setup_project;
theta = 0.03;
logFile = sk_path('data', 'simulation', 'extension', 'X1_2_runlog.csv');
t0 = tic;
for seed = [0 1]
    for ct = [1 2]
        for eta = [0.5 2]
            name = sprintf('X1_ppo_40hz_r5_c%d_th%g_eta%g_seed%d_ep%d', ct, round(1000 * theta), eta, seed, 3000);
            file = sk_path('SavedAgents', 'MotionProfile', 'X1', [name '.mat']);
            if isfile(file), continue; end
            fprintf('\n=== X1.2: Kosten %d, eta %g, Seed %d (%.0f min seit Start) ===\n', ct, eta, seed, toc(t0) / 60);
            t1 = tic; ok = true; msg = "-";
            try
                ext_x1_train(theta, seed, 'cost_type', ct, 'eta', eta);
            catch err
                ok = false; msg = string(err.message);
                fprintf(2, 'X1.2: %s fehlgeschlagen: %s\n', name, msg);
            end
            row = table(string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), string(name), ok, ...
                        toc(t1) / 60, msg, 'VariableNames', {'time', 'name', 'ok', 'minutes', 'error'});
            if isfile(logFile), row = [readtable(logFile, 'TextType', 'string'); row]; end %#ok<AGROW>
            writetable(row, logFile);
        end
    end
end
fprintf('\nX1.2: fertig nach %.0f min\n', toc(t0) / 60);
end
