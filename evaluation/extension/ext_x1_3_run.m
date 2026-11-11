function ext_x1_3_run(varargin)
%EXT_X1_3_RUN  Hauptlauf der Nebenbedingung (Ausbau X1.3): fuenf Budgets und r1 als Bezug, je zehn Seeds.
%   ext_x1_3_run()
%   ext_x1_3_run('seeds', 0:4, 'thetas', [0.02 0.03], 'r1', false, 'eval', false)
%
%   Duale Einstellung nach X1.2b (E2): Kosten A, delta 0,02, Bloecke zu 50 Episoden, eta 5, lambda0 1, 3000
%   Episoden (ext_x1_train). Budgets theta 0,02 bis 0,06 rad.
%   Bezug r1: derselbe Aufbau mit lambda fest 0 (eta 0, lambda0 0, Bloecke zu 50). Reward-Modus 5 mit lambda 0 ist
%   der Reward von Modus 1 (nur Tracking), der einzige Unterschied zu den Budget-Laeufen ist also lambda.
%   theta 0,03 ist dort nur die Schwelle des geloggten Kostensignals.
%   Reihenfolge: Seeds aussen, damit ein Abbruch vollstaendige Seeds hinterlaesst. Vorhandene Agenten werden
%   uebersprungen (theta 0,03 mit Seed 0 und 1 sind die Agenten aus X1.2b mit derselben Einstellung).
%   Protokoll X1_3_runlog.csv. Danach ext_x1_2_eval mit allen X1.3-Agenten und D16 r4 als Bezug (Studie X1_3).

p = inputParser;
p.addParameter('seeds', 0:9);
p.addParameter('thetas', [0.02 0.03 0.04 0.05 0.06]);
p.addParameter('r1', true);
p.addParameter('eval', true);
p.parse(varargin{:});
o = p.Results;
setup_project;
fast = {'block', 50, 'eta', 5, 'lambda0', 1};
r1 = {'block', 50, 'eta', 0, 'lambda0', 0};
logFile = sk_path('data', 'simulation', 'extension', 'X1_3_runlog.csv');
t0 = tic;
for seed = o.seeds
    jobs = arrayfun(@(th) {th, fast, sprintf('X1_ppo_40hz_r5_c1_th%d_eta5_seed%d_ep3000_b50_l1', ...
                                             round(1000 * th), seed)}, o.thetas, 'UniformOutput', false);
    if o.r1
        jobs{end + 1} = {0.03, r1, sprintf('X1_ppo_40hz_r5_c1_th30_eta0_seed%d_ep3000_b50', seed)}; %#ok<AGROW>
    end
    for j = 1:numel(jobs)
        [theta, opts, name] = jobs{j}{:};
        file = sk_path('SavedAgents', 'MotionProfile', 'X1', [name '.mat']);
        if isfile(file), continue; end
        fprintf('\n=== X1.3: %s (%.0f min seit Start) ===\n', name, toc(t0) / 60);
        t1 = tic; ok = true; msg = "-";
        try
            out = ext_x1_train(theta, seed, 'cost_type', 1, opts{:});
            [~, got] = fileparts(out.agentFile);
            assert(strcmp(got, name), 'ext_x1_3_run:name', 'Name %s statt %s', got, name);
        catch err
            ok = false; msg = string(err.message);
            fprintf(2, 'X1.3: %s fehlgeschlagen: %s\n', name, msg);
        end
        row = table(string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), string(name), ok, ...
                    toc(t1) / 60, msg, 'VariableNames', {'time', 'name', 'ok', 'minutes', 'error'});
        if isfile(logFile), row = [readtable(logFile, 'TextType', 'string'); row]; end %#ok<AGROW>
        writetable(row, logFile);
    end
end
fprintf('\nX1.3: Training fertig nach %.0f min\n', toc(t0) / 60);
if o.eval
    ext_x1_2_eval('pattern', 'X1_ppo_40hz_r5_c1_th*_seed*_ep3000_b50*.mat', 'study', 'X1_3', 'ref', true);
end
fprintf('\nX1.3: fertig nach %.0f min\n', toc(t0) / 60);
end
