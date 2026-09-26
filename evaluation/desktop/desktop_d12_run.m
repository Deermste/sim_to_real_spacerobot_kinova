function desktop_d12_run(modes, seeds, nEpisodes)
%DESKTOP_D12_RUN  Trainiert die D12-Varianten nacheinander und wertet sie danach aus (Befund A51).
%   desktop_d12_run()                   Varianten a, b, c (Modus 1 bis 3), Seed 0, je 1000 Episoden
%   desktop_d12_run([2 3], [1 2])       ausgewaehlte Varianten mit weiteren Seeds
%
%   Nach dem Training laufen alle D12-Agenten, die in SavedAgents/MotionProfile/D12 liegen, zusammen mit den
%   Agenten aus A51 durch desktop_a51_reward (1 deterministische + 10 stochastische Episoden, Auswertung mit
%   dem Reward des Trainings seit 09.04.). Die D10-40-Hz-Agenten sind die Kontrolle mit Modus 0.
%   Ergebnis der Auswertung: data/simulation/desktop/D12_eval_<Zeit>_*.csv

if nargin < 1 || isempty(modes), modes = 1:3; end
if nargin < 2 || isempty(seeds), seeds = 0; end
if nargin < 3 || isempty(nEpisodes), nEpisodes = 1000; end

for s = seeds
    for m = modes
        try
            desktop_d12_train(m, s, nEpisodes);
        catch err
            % Ein fehlgeschlagenes Training soll die anderen Varianten nicht aufhalten
            fprintf(2, 'D12: Modus %d, Seed %d fehlgeschlagen: %s\n', m, s, err.message);
        end
    end
end

d = dir(sk_path('SavedAgents', 'MotionProfile', 'D12', 'D12_ppo_40hz_r*_seed*.mat'));
extra = struct('label', {}, 'file', {}, 'hz', {});
for k = 1:numel(d)
    tok = regexp(d(k).name, 'r(\d)_seed(\d+)', 'tokens', 'once');
    extra(end + 1) = struct('label', sprintf('D12_r%s_s%s', tok{1}, tok{2}), ...
        'file', fullfile(d(k).folder, d(k).name), 'hz', 40); %#ok<AGROW>
end
fprintf('D12: Auswertung mit %d neuen Agenten\n', numel(extra));
desktop_a51_reward(10, extra, 'D12_eval');
end
