function desktop_d12_run(modes, seeds, nEpisodes, optsSet)
%DESKTOP_D12_RUN  Trainiert die D12-, D13- oder D14-Varianten nacheinander und wertet sie aus (Befund A51).
%   desktop_d12_run()                   Varianten a, b, c (Modus 1 bis 3), Seed 0, je 1000 Episoden
%   desktop_d12_run([2 3], [1 2])       ausgewaehlte Varianten mit weiteren Seeds
%   desktop_d12_run(0:2, 0:2, [], 'base')   D13: Modus 0 bis 2 mit den Optionen des fruehen PPO
%   desktop_d12_run(0:2, 0:2, [], 'base_sync')   D14: wie D13, synchron und mit Gradient Clipping
%
%   Nach dem Training laufen alle Agenten der Studie (SavedAgents/MotionProfile/D12, D13 oder D14) zusammen mit den
%   Agenten aus A51 durch desktop_a51_reward (1 deterministische + 10 stochastische Episoden, Auswertung mit
%   dem Reward des Trainings seit 09.04.). Die D10-40-Hz-Agenten sind die Kontrolle mit Modus 0 und den Optionen
%   von Optimized.
%   Ergebnis der Auswertung: data/simulation/desktop/<Studie>_eval_<Zeit>_*.csv

if nargin < 1 || isempty(modes), modes = 1:3; end
if nargin < 2 || isempty(seeds), seeds = 0; end
if nargin < 3 || isempty(nEpisodes), nEpisodes = 1000; end
if nargin < 4 || isempty(optsSet), optsSet = 'optimized'; end

for s = seeds
    for m = modes
        try
            desktop_d12_train(m, s, nEpisodes, '', optsSet);
        catch err
            % Ein fehlgeschlagenes Training soll die anderen Varianten nicht aufhalten
            fprintf(2, 'Modus %d, Seed %d, Optionen %s fehlgeschlagen: %s\n', m, s, optsSet, err.message);
        end
    end
end

study = 'D12';
if strcmp(optsSet, 'base'), study = 'D13'; end
if strcmp(optsSet, 'base_sync'), study = 'D14'; end
% Ausgewertet werden die Agenten dieser Studie zusammen mit den 11 Vergleichsagenten aus A51
d = dir(sk_path('SavedAgents', 'MotionProfile', study, [study '_ppo_40hz_r*_seed*.mat']));
extra = struct('label', {}, 'file', {}, 'hz', {});
for k = 1:numel(d)
    tok = regexp(d(k).name, '^(D1\d)_ppo_40hz_r(\d)_seed(\d+)', 'tokens', 'once');
    extra(end + 1) = struct('label', sprintf('%s_r%s_s%s', tok{1}, tok{2}, tok{3}), ...
        'file', fullfile(d(k).folder, d(k).name), 'hz', 40); %#ok<AGROW>
end
prefix = [study '_eval'];
fprintf('Auswertung mit %d neuen Agenten\n', numel(extra));
desktop_a51_reward(10, extra, prefix);
end
