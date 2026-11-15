function T = ext_x7sp_dev(list, varargin)
%EXT_X7SP_DEV  Entwicklungssatz fuer X7-SP (15.11.2026): Auswahl ohne die Testpaare.
%   T = ext_x7sp_dev(list)        list: struct mit file, label, beta, eps_v, eps_w (leer: nur Rbeta 1)
%
%   n = 48 Episoden aus der DR-voll-Verteilung von ext_x7sp_env auf dem Trainingssatz (X6_train), eigener Seed
%   777777. Jeder Teilnehmer faehrt dieselben Ziehungen (Paar und Stoerung): R (Rbeta 1, Korrektur null) und jede
%   Policy (Mittelwert). Erfolg und Einschwingzeit aus der Umgebung (wahre Groessen, 5 mm und 5 mm/s, 1 s).
%   Kennzahlen: Erfolgsquote, Mittel von t (Fehlschlag 15 s) und ori_max, J_sp = ori / ori_R + t / t_R mit den
%   Mitteln von R auf denselben Ziehungen.

p = inputParser;
p.addParameter('n', 48);
p.addParameter('seed', 777777);
p.parse(varargin{:});
o = p.Results;
setup_project;
dd = sk_path('data', 'simulation', 'extension');
dT = dir(fullfile(dd, 'X6_train_*.mat'));
Lt = load(fullfile(dT(end).folder, dT(end).name), 'P');
subj = struct('label', {'R'}, 'pol', {@(ob) zeros(6, 1)}, 'beta', {1}, 'eps_v', {0.02}, 'eps_w', {0.02});
for k = 1:numel(list)
    subj(end + 1) = struct('label', list(k).label, 'pol', ext_policy(list(k).file), 'beta', list(k).beta, ...
                           'eps_v', list(k).eps_v, 'eps_w', list(k).eps_w); %#ok<AGROW>
end
M = nan(numel(subj), o.n, 3);
for j = 1:numel(subj)
    env = ext_x7sp_env(Lt.P, 'dr', 'full', 'seed', o.seed, 'beta', subj(j).beta, 'eps_v', subj(j).eps_v, ...
                       'eps_w', subj(j).eps_w);
    for e = 1:o.n
        ob = reset(env); done = false;
        while ~done
            [ob, ~, done] = step(env, min(max(subj(j).pol(ob), -1), 1));
        end
        L = env.LoggedSignals;
        t = L.tSet; if isnan(t), t = 15; end
        M(j, e, :) = [~isnan(L.tSet), t, max(L.S.oriS(1:L.S.k * L.S.m + 1))];
    end
end
oR = mean(M(1, :, 3)); tR = mean(M(1, :, 2));
rows = {};
for j = 1:numel(subj)
    r = squeeze(M(j, :, :));
    rows{end + 1} = struct('subject', string(subj(j).label), 'success', mean(r(:, 1)), 't_mean', mean(r(:, 2)), ...
        'ori_mean', mean(r(:, 3)), 'J', mean(r(:, 3)) / oR + mean(r(:, 2)) / tR); %#ok<AGROW>
end
T = struct2table([rows{:}]);
end
