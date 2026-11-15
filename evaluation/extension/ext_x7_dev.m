function T = ext_x7_dev(list, varargin)
%EXT_X7_DEV  Entwicklungssatz fuer X7 (15.11.2026): Auswahl von Varianten ohne die Testszenarien.
%   T = ext_x7_dev(list)                list: struct mit file, label, eps_v, eps_w (leer: nur der Regler R)
%   T = ext_x7_dev(list, 'n', 40)
%
%   Zieht n Episoden aus der DR-voll-Verteilung von ext_x7_env mit eigenem festen Seed (777777, nie im Training
%   benutzt) und faehrt jeden Teilnehmer auf denselben Ziehungen: R (Korrektur null) und jede Policy
%   (Mittelwert, ext_policy). Die 26 Szenarien aus X2.3 und X0.1 bleiben fuer die Schlussauswertung.
%   Kennzahlen je Teilnehmer: Anteil folgend, Mittel von RMS, ep_q4 und ori_max, Mittel der Differenz zu R auf
%   derselben Ziehung, Anteil der Ziehungen mit kleinerem RMS bzw. kleinerer Drehung als R.
%   Ergebnis: Tabelle T (eine Zeile je Teilnehmer).

p = inputParser;
p.addParameter('n', 40);
p.addParameter('seed', 777777);
p.parse(varargin{:});
o = p.Results;
setup_project;
subj = struct('label', {'R'}, 'pol', {@(ob) zeros(3, 1)}, 'eps_v', {0.02}, 'eps_w', {0.01});
for k = 1:numel(list)
    subj(end + 1) = struct('label', list(k).label, 'pol', ext_policy(list(k).file), 'eps_v', list(k).eps_v, ...
                           'eps_w', list(k).eps_w); %#ok<AGROW>
end
M = nan(numel(subj), o.n, 4);
for j = 1:numel(subj)
    env = ext_x7_env('dr', 'full', 'seed', o.seed, 'eps_v', subj(j).eps_v, 'eps_w', subj(j).eps_w);
    for e = 1:o.n
        ob = reset(env); done = false;
        while ~done
            [ob, ~, done] = step(env, min(max(subj(j).pol(ob), -1), 1));
        end
        L = env.LoggedSignals;
        m = ext_x7_plant('metrics', L.S);
        fol = m.t_end > 8.5 - 0.1 && m.ep_q4 < 0.05;
        M(j, e, :) = [m.rms_ee, m.ep_q4, m.ori_max, fol];
    end
end
rows = {};
for j = 1:numel(subj)
    r = squeeze(M(j, :, :)); r0 = squeeze(M(1, :, :));
    rows{end + 1} = struct('subject', string(subj(j).label), 'follows', mean(r(:, 4)), ...
        'rms_ee', mean(r(:, 1)), 'ep_q4', mean(r(:, 2)), 'ori_max', mean(r(:, 3)), ...
        'd_rms', mean(r(:, 1) - r0(:, 1)), 'd_ori', mean(r(:, 3) - r0(:, 3)), ...
        'better_rms', mean(r(:, 1) < r0(:, 1)), 'better_ori', mean(r(:, 3) < r0(:, 3))); %#ok<AGROW>
end
T = struct2table([rows{:}]);
end
