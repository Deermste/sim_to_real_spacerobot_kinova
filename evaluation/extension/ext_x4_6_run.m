function ext_x4_6_run(varargin)
%EXT_X4_6_RUN  Nachtlauf der Ablation X4.6: V1, V2, V3 je fuenf Seeds, danach X0.1.
%   ext_x4_6_run()
%   ext_x4_6_run('seeds', 0:1, 'variants', {'V1'}, 'eval', false)
%
%   Training mit ext_x4_6_train (3000 Episoden). Reihenfolge: Seeds aussen, damit ein Abbruch vollstaendige
%   Seeds hinterlaesst. Vorhandene Agenten werden uebersprungen. Protokoll X4_6_runlog.csv. Danach X0.1
%   (ext_eval_batch, Studie X4_6) fuer alle X4.6-Agenten. ext_eval_agent nimmt das Modell aus dem cfg des Agenten.
%   Bezug V0 ist D16 r4 Seeds 0-9 (schon ausgewertet, X1.3 und X4.1).

p = inputParser;
p.addParameter('seeds', 0:4);
p.addParameter('variants', {'V1', 'V2', 'V3'});
p.addParameter('eval', true);
p.parse(varargin{:});
o = p.Results;
setup_project;
logFile = sk_path('data', 'simulation', 'extension', 'X4_6_runlog.csv');
agentDir = sk_path('SavedAgents', 'MotionProfile', 'X4_6');
t0 = tic;
for seed = o.seeds
    for v = o.variants
        name = sprintf('X4_6_ppo_40hz_r4_%s_seed%d_ep3000', v{1}, seed);
        if isfile(fullfile(agentDir, [name '.mat'])), continue; end
        fprintf('\n=== X4.6: %s (%.0f min seit Start) ===\n', name, toc(t0) / 60);
        t1 = tic; ok = true; msg = "-";
        try
            out = ext_x4_6_train(v{1}, seed);
            [~, got] = fileparts(out.agentFile);
            assert(strcmp(got, name), 'ext_x4_6_run:name', 'Name %s statt %s', got, name);
        catch err
            ok = false; msg = string(err.message);
            fprintf(2, 'X4.6: %s fehlgeschlagen: %s\n', name, msg);
        end
        row = table(string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), string(name), ok, ...
                    toc(t1) / 60, msg, 'VariableNames', {'time', 'name', 'ok', 'minutes', 'error'});
        if isfile(logFile), row = [readtable(logFile, 'TextType', 'string'); row]; end %#ok<AGROW>
        writetable(row, logFile);
    end
end
fprintf('\nX4.6: Training fertig nach %.0f min\n', toc(t0) / 60);
if o.eval
    d = dir(fullfile(agentDir, 'X4_6_ppo_40hz_r4_V*_seed*_ep3000.mat'));
    list = struct('file', {}, 'label', {}, 'group', {}, 'opts', {});
    for k = 1:numel(d)
        [~, n] = fileparts(d(k).name);
        list(end + 1) = struct('file', fullfile(d(k).folder, d(k).name), 'label', n, ...
                               'group', char(extractBetween(string(n), "r4_", "_seed")), 'opts', {{}}); %#ok<AGROW>
    end
    ext_eval_batch(list, 'X4_6');
end
fprintf('\nX4.6: fertig nach %.0f min\n', toc(t0) / 60);
end
