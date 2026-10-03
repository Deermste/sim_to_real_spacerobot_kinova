function desktop_d20_run(seeds, nEpisodes, ckptEvery)
%DESKTOP_D20_RUN  Zwischenstaende des r4-Trainings (Befund A68): Tritt die ruhige und genaue Loesung im Training auf?
%   desktop_d20_run()              Seeds 0-7, je 3000 Episoden, Zwischenstand alle 250 Episoden, danach Auswertung
%   desktop_d20_run(0, 8, 4)       Kurztest (tag 'test', keine Auswertung)
%
%   Aufbau genau wie der lange r4-Lauf aus D16 (desktop_d12_train(4, s, 3000, '', 'base_sync', 0.9774)): Reward-Modus
%   4 mit Gewicht 2, Optionen des fruehen PPO mit synchronem Training und Gradient Clipping, J6 0,9774 rad/s, 40 Hz,
%   65 kg. Neu ist nur das Speichern der Zwischenstaende. Das parallele Training ist nicht deterministisch, die Laeufe
%   wiederholen D16 also nicht, sie sind neue Laeufe mit denselben Einstellungen.
%   Hintergrund: Der r4-Agent aus einem Lauf mit 1000 Episoden (D16 Seed 2) drehte die Basis um etwa 0,02 rad und
%   war auf der Hardware der genaueste (D19). Von den acht Laeufen mit 3000 Episoden fanden nur zwei die ruhige
%   Loesung (D17). Ob sie in den anderen zwischendurch auftrat und wieder verloren ging, war unbekannt.
%   Ergebnis: SavedAgents/MotionProfile/D20/D20_ppo_40hz_r4_seed<s>_ep3000.mat und _ckpt/Agent<n>.mat,
%   Lernkurven in data/simulation/desktop/, Auswertung desktop_d20_eval.

if nargin < 1 || isempty(seeds), seeds = 0:7; end
if nargin < 2 || isempty(nEpisodes), nEpisodes = 3000; end
if nargin < 3 || isempty(ckptEvery), ckptEvery = 250; end
tag = '';
if nEpisodes < 1000, tag = 'test'; end
t0 = tic;
for s = seeds
    fprintf('\n=== D20: Seed %d, %d Episoden, Zwischenstand alle %d (%.0f min seit Start) ===\n', s, nEpisodes, ...
            ckptEvery, toc(t0) / 60);
    try
        desktop_d12_train(4, s, nEpisodes, tag, 'base_sync', 0.9774, 2, ckptEvery);
    catch err
        fprintf(2, 'D20: Seed %d fehlgeschlagen: %s\n', s, err.message);
    end
end
fprintf('\nD20: Training fertig nach %.0f min\n', toc(t0) / 60);
if isempty(tag)
    desktop_d20_eval();
end
end
