function desktop_d11_run(algos, seeds, nEpisodes)
%DESKTOP_D11_RUN  Algorithmenvergleich neu: alle Trainings nacheinander, danach die Auswertung (D11, A64).
%   desktop_d11_run()                                 6 Verfahren x Seeds 0 bis 4, je 1000 Episoden
%   desktop_d11_run({'PPO', 'SAC'}, 0, 20)            Probelauf (speichert unter _test, keine Auswertung)
%
%   Reihenfolge: erst die on-policy Verfahren (schnell), dann die off-policy Verfahren, innerhalb eines Verfahrens
%   die Seeds aufsteigend. Ein fehlgeschlagenes Training haelt die anderen nicht auf. Danach desktop_d11_eval.

if nargin < 1 || isempty(algos), algos = {'PPO', 'TRPO', 'PG', 'DDPG', 'TD3', 'SAC'}; end
if nargin < 2 || isempty(seeds), seeds = 0:4; end
if nargin < 3 || isempty(nEpisodes), nEpisodes = 1000; end
probe = nEpisodes < 1000;
tag = '';
if probe, tag = 'test'; end

for a = 1:numel(algos)
    for s = seeds
        try
            desktop_d11_train(algos{a}, s, nEpisodes, tag);
        catch err
            fprintf(2, 'D11: %s Seed %d fehlgeschlagen: %s\n', algos{a}, s, err.message);
        end
    end
end
if ~probe
    desktop_d11_eval();
end
end
