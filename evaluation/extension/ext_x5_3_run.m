function ext_x5_3_run(varargin)
%EXT_X5_3_RUN  Nachtkette X5.3 (14.11.2026): 3D-Front, X1-Pilot in 3D, Hauptlauf r4 und gegebenenfalls X1.
%   ext_x5_3_run()
%
%   1  Front des Reglers auf der Bahn tilted -30 mit allen sieben Gelenken und den Grenzen der Agenten
%      (0,9774 / 0,5774 rad/s): ext_x5_1_feasibility mit beta 0 und logspace(-1, 4, 21), J6-Seiten 0, -1, +1,
%      Prioritaetsform. Ergebnis X5_3_front_<Zeit>.csv.
%   2  X1-Pilot in 3D: Variante x1 (theta 0,03, Kosten A, eta 5, lambda0 1) mit Lernrate 3e-4, Seeds 0 und 1,
%      Zwischenstaende alle 250 Episoden (ext_x5_2_run, Label 'c'). Go-Regel wie X5.2: mindestens ein Seed folgt.
%   3  Hauptlauf r4: Seeds 2 bis 9 mit denselben Einstellungen wie X5.2b (Seeds 0 und 1 von dort uebernommen),
%      Label '3_r4'.
%   4  Nur bei Go in 2: Hauptlauf x1, Seeds 2 bis 9, Label '3_x1'.
%   Auswertung je Lauf wie X5.2b: letzter Agent und bester Zwischenstand (nominal ausgewaehlt) mit X0.1
%   (21 Episoden, Stoerung auf allen sieben Gelenken). Die Zusammenfassung ueber alle 10 Seeds folgt danach.

setup_project;
lim7 = [0.9774; 0.9774; 0.9774; 0.9774; 0.5774; 0.5774; 0.5774];
t0 = tic;
fprintf('=== X5.3 Schritt 1: Front 3D ===\n');
ext_x5_1_feasibility('betas', [0 logspace(-1, 4, 21)], 'paths', {{'tilted', -30}}, 'sets', {'all7'}, ...
                     'lim7', lim7, 'label', '3_front');
fprintf('=== X5.3 Schritt 2: X1-Pilot 3D (%.1f min) ===\n', toc(t0) / 60);
S = ext_x5_2_run('variants', {'x1'}, 'actorLR', 3e-4, 'ckptEvery', 250, 'label', 'c');
goX1 = any(S.agents.follows == 1);
fprintf('X1-Pilot: %d von %d Agenten folgen -> %s\n', sum(S.agents.follows), height(S.agents), ...
        string(goX1) + "");
fprintf('=== X5.3 Schritt 3: r4 Seeds 2 bis 9 (%.1f min) ===\n', toc(t0) / 60);
ext_x5_2_run('variants', {'r4'}, 'seeds', 2:9, 'actorLR', 3e-4, 'ckptEvery', 250, 'label', '3_r4');
if goX1
    fprintf('=== X5.3 Schritt 4: x1 Seeds 2 bis 9 (%.1f min) ===\n', toc(t0) / 60);
    ext_x5_2_run('variants', {'x1'}, 'seeds', 2:9, 'actorLR', 3e-4, 'ckptEvery', 250, 'label', '3_x1');
else
    fprintf('=== X5.3 Schritt 4 entfaellt (X1-Pilot ohne folgenden Agenten) ===\n');
end
fprintf('=== X5.3 fertig nach %.1f h ===\n', toc(t0) / 3600);
end
