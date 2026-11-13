function C = ext_x6_env_check()
%EXT_X6_ENV_CHECK  Funktionspruefung der X6-Umgebung (X6.1): validateEnvironment, Ruhe, Erfolg, Abbruch, Zeit.
%   C = ext_x6_env_check()
%
%   1  validateEnvironment
%   2  Ziel = Startpunkt, Aktion null: Erfolg nach 20 Schritten (1 s), Reward am Ende enthaelt +50
%   3  Paar aus dem Auswertesatz, Aktion null: kein Abbruch, Ende nach 300 Schritten, Fehler bleibt d0
%   4  Paar aus dem Auswertesatz, Aktion konstant +1 auf allen Gelenken: Abbruch (OOD oder Klemme) oder Zeitende,
%      keine Grenzverletzung der Kette
%   5  Zeit je Schritt ueber env.step (200 Schritte zufaellig)
%   6  Beobachtung endlich, groesster Betrag
%   7  Kollision: Arm gestreckt nach oben (q = 0), nur J2 mit +1: Ende mit Kollision, bevor J2 die Grenze erreicht
%   8  Zeit je env.step ohne Kollisionspruefung (Option 'coll' false)

setup_project;
d = dir(sk_path('data', 'simulation', 'extension', 'X6_pairs_*.mat'));
assert(~isempty(d), 'ext_x6_env_check:pairs', 'Zuerst ext_x6_pairs laufen lassen');
L = load(fullfile(d(end).folder, d(end).name), 'P');
E = L.P([L.P.set] == "eval");
rows = {};
[env, info] = ext_x6_env(E(1));
validateEnvironment(env);
rows{end + 1} = row('1 validateEnvironment', 1, '');

K = info.K;
[~, p0] = ext_kin_eval(K, E(1).q0);
pr = struct('q0', E(1).q0, 'pT', p0);
env2 = ext_x6_env(pr);
reset(env2);
n = 0; done = false; rSum = 0;
while ~done && n < 400
    [~, r, done] = step(env2, zeros(7, 1)); n = n + 1; rSum = rSum + r;
end
rows{end + 1} = row('2 Ziel am Start: Schritte bis Ende', n, sprintf('letzter Reward %.2f', r));

reset(env);
n = 0; done = false; o = [];
while ~done && n < 400
    [o, r, done] = step(env, zeros(7, 1)); n = n + 1;
end
rows{end + 1} = row('3 Aktion null: Schritte bis Ende', n, sprintf('|e| am Ende %.4f m, d0 %.4f m', norm(o(1:3)), E(1).d0));

reset(env);
n = 0; done = false; vmax = 0;
while ~done && n < 400
    [o, r, done] = step(env, ones(7, 1)); n = n + 1;
    vmax = max(vmax, max(abs(o(37:43))));
end
rows{end + 1} = row('4 Aktion +1: Schritte bis Ende', n, sprintf('letzter Reward %.1f, max |v_prev/v_max| %.3f', r, vmax));

rs = RandStream('mt19937ar', 'Seed', 2);
reset(env);
mo = 0; tic; k = 0;
while k < 200
    [o, ~, done] = step(env, 2 * rand(rs, 7, 1) - 1); k = k + 1;
    mo = max(mo, max(abs(o)));
    assert(all(isfinite(o)), 'ext_x6_env_check:nan', 'Beobachtung nicht endlich');
    if done, reset(env); end
end
rows{end + 1} = row('5 Zeit je env.step [ms]', 1000 * toc / k, '');
rows{end + 1} = row('6 groesster Betrag der Beobachtung', mo, '');

prc = struct('q0', zeros(7, 1), 'pT', [0.5; 0; 1]);
env3 = ext_x6_env(prc);
reset(env3);
n = 0; done = false; a2 = [0; 1; 0; 0; 0; 0; 0];
while ~done && n < 400
    [o, r, done] = step(env3, a2); n = n + 1;
end
Ls = env3.LoggedSignals;
q2 = rad2deg(Ls.S.q(2));
rows{end + 1} = row('7 Kollision bei J2 +1: Kollision erkannt', double(Ls.coll), ...
                    sprintf('nach %d Schritten, J2 %.1f Grad (Grenze 128,9), letzter Reward %.1f', n, q2, r));

env4 = ext_x6_env(E(1), 'coll', false);
reset(env4); reset(env);
rs = RandStream('mt19937ar', 'Seed', 2);
A = 2 * rand(rs, 7, 200) - 1;
tt = zeros(1, 2);
for e = 1:2
    ev = env; if e == 2, ev = env4; end
    reset(ev); tic;
    for k = 1:200
        [~, ~, done] = step(ev, A(:, k));
        if done, reset(ev); end
    end
    tt(e) = 1000 * toc / 200;
end
rows{end + 1} = row('8 Zeit je env.step mit / ohne Kollision [ms]', tt(1), sprintf('ohne %.2f ms', tt(2)));
C = struct2table([rows{:}]);
disp(C);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
writetable(C, sk_path('data', 'simulation', 'extension', ['X6_env_check_' stamp '.csv']));
end

function r = row(name, value, note)
r = struct('check', string(name), 'value', value, 'note', string(note));
end
