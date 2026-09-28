function desktop_d17_run(weights, seeds, nEpisodes)
%DESKTOP_D17_RUN  Kurve Tracking gegen Basisdrehung: Gewicht des glatten Basis-Terms in Reward-Modus 4 variieren.
%   desktop_d17_run()                     Gewichte 0, 4, 8, 16, Seeds 0-2, je 3000 Episoden, danach Auswertung
%   desktop_d17_run([4 8], 0, 16)         Kurztest (tag 'test', keine Auswertung)
%
%   Aufbau wie der lange r4-Lauf aus D16 (desktop_d12_run(4, 0:7, 3000, 'base_sync', 0.9774)): Reward-Modus 4,
%   Optionen des fruehen PPO mit synchronem Training und Gradient Clipping, J6-Grenze 0,9774 rad/s, 40 Hz, 65 kg.
%   Einziger Unterschied ist das Gewicht p_base_w des glatten Basis-Terms +w*exp(-(ori/0,05)^2), der nur auf der
%   Bahn (EE-Fehler < 5 cm) gezahlt wird. Gewicht 2 liegt aus D16 mit acht Seeds vor. Gewicht 0 entspricht
%   Reward-Modus 2 (nur der binaere Basis-Bonus auf der Bahn).
%   Ergebnis: SavedAgents/MotionProfile/D17/D17_ppo_40hz_r4_w<w>_seed<s>_ep3000.mat, Lernkurven und
%   desktop_d17_eval.

if nargin < 1 || isempty(weights), weights = [0 4 8 16]; end
if nargin < 2 || isempty(seeds), seeds = 0:2; end
if nargin < 3 || isempty(nEpisodes), nEpisodes = 3000; end
tag = '';
if nEpisodes < 1000, tag = 'test'; end
t0 = tic;
for s = seeds
    for w = weights
        fprintf('\n=== D17: Gewicht %g, Seed %d, %d Episoden (%.0f min seit Start) ===\n', w, s, nEpisodes, toc(t0) / 60);
        try
            desktop_d12_train(4, s, nEpisodes, tag, 'base_sync', 0.9774, w);
        catch err
            fprintf(2, 'D17: Gewicht %g, Seed %d fehlgeschlagen: %s\n', w, s, err.message);
        end
    end
end
fprintf('\nD17: Training fertig nach %.0f min\n', toc(t0) / 60);
if isempty(tag)
    desktop_d17_eval();
end
end
