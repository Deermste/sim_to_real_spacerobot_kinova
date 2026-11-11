function ext_x1_2b_run()
%EXT_X1_2B_RUN  Zweiter Pilot der Nebenbedingung (Ausbau X1.2b): schnellere duale Anpassung.
%   ext_x1_2b_run()
%
%   Nach X1.2 (E2: Kosten A) schwang lambda in 3000 Episoden mit keiner Einstellung ein. Zwei Varianten, Kosten A,
%   theta 0,03 rad, delta 0,02, Seeds 0 und 1, je 3000 Episoden (ext_x1_train):
%     fast  Bloecke zu 50 Episoden, eta 5, lambda0 1
%     pid   Bloecke zu 100 Episoden, eta 2, kp 20 (PID-Lagrange ohne D-Anteil, Stooke et al. 2020)
%   Vorhandene Agenten werden uebersprungen. Protokoll X1_2b_runlog.csv. Danach ext_x1_2_eval fuer die vier
%   Agenten (Studie X1_2b). Auswahl wie in X1.2: lambda schwingt ein, Budget gehalten, Bahn gefolgt.

setup_project;
theta = 0.03;
variants = {'fast', {'block', 50, 'eta', 5, 'lambda0', 1}, 'eta5_seed%d_ep3000_b50_l1';
            'pid',  {'block', 100, 'eta', 2, 'kp', 20},     'eta2_seed%d_ep3000_kp20'};
logFile = sk_path('data', 'simulation', 'extension', 'X1_2b_runlog.csv');
t0 = tic;
for seed = [0 1]
    for v = 1:size(variants, 1)
        name = ['X1_ppo_40hz_r5_c1_th30_' sprintf(variants{v, 3}, seed)];
        file = sk_path('SavedAgents', 'MotionProfile', 'X1', [name '.mat']);
        if isfile(file), continue; end
        fprintf('\n=== X1.2b: %s, Seed %d (%.0f min seit Start) ===\n', variants{v, 1}, seed, toc(t0) / 60);
        t1 = tic; ok = true; msg = "-";
        try
            out = ext_x1_train(theta, seed, 'cost_type', 1, variants{v, 2}{:});
            [~, got] = fileparts(out.agentFile);
            assert(strcmp(got, name), 'ext_x1_2b_run:name', 'Name %s statt %s', got, name);
        catch err
            ok = false; msg = string(err.message);
            fprintf(2, 'X1.2b: %s fehlgeschlagen: %s\n', name, msg);
        end
        row = table(string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), string(name), ok, ...
                    toc(t1) / 60, msg, 'VariableNames', {'time', 'name', 'ok', 'minutes', 'error'});
        if isfile(logFile), row = [readtable(logFile, 'TextType', 'string'); row]; end %#ok<AGROW>
        writetable(row, logFile);
    end
end
fprintf('\nX1.2b: Training fertig nach %.0f min\n', toc(t0) / 60);
ext_x1_2_eval('pattern', 'X1_ppo_40hz_r5_c1_th30_*_ep3000_*.mat', 'study', 'X1_2b', 'ref', false);
fprintf('\nX1.2b: fertig nach %.0f min\n', toc(t0) / 60);
end
