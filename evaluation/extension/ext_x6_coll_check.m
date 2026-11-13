function R = ext_x6_coll_check(varargin)
%EXT_X6_COLL_CHECK  Kapselpruefung ext_x6_coll gegen die Mesh-Pruefung (checkCollision, wie ext_x6_pairs).
%   R = ext_x6_coll_check()                 4000 Zufallsstellungen (Seed 7, Verteilung wie ext_x6_pairs)
%   R = ext_x6_coll_check('seed', 8)        Pruefung an frischen Stellungen (Baender aus Seed 7)
%   R = ext_x6_coll_check('n', 500)
%   Erster Lauf (13.11., Seed 7) mit allen Paaren und ohne Baender, daraus die Baender in ext_x6_coll.
%   Ab dem zweiten Lauf zusaetzlich: Ergebnis mit Vorfilter und Mesh (verpasst, Fehlalarme, Anteil mit Mesh) und
%   Rechenzeit der Pruefung wie in der Umgebung.
%
%   Je Stellung: Mesh-Ergebnis (Exhaustive, Paare Eltern-Kind ausgenommen, kleinster Abstand der Meshes) und
%   alle Kapselabstaende D. Ausgewertet werden
%     - je Kapselpruefung der Anteil der Mesh-freien Stellungen mit D < 0 (Pruefungen, die nur Fehlalarme
%       liefern, fliegen aus der Paarliste)
%     - fuer delta 0 bis 5 cm: verpasste Kollisionen (Mesh trifft, Kapsel nicht) und Fehlalarme
%     - Rechenzeit je Aufruf
%   CSV: data/simulation/extension/X6_coll_check_{checks,delta}_<Zeit>.csv, MAT mit allen Werten

p = inputParser;
p.addParameter('n', 4000);
p.addParameter('seed', 7);
p.parse(varargin{:});
o = p.Results;
setup_project;
K = ext_kin_model('tool_offset', [0; 0; 0.121]);
Cp = chain_step('params');
fin = isfinite(Cp.q_lim);
qS = pi * ones(7, 1);
qS(fin) = Cp.q_lim(fin) - deg2rad(5);
rs = RandStream('mt19937ar', 'Seed', o.seed);
Q = (2 * rand(rs, 7, o.n) - 1) .* qS;
C = ext_x6_coll('params', K);
rbC = parallel.pool.Constant(@() ext_x6_coll('robot'));
hitM = false(o.n, 1); dM = zeros(o.n, 1);
t0 = tic;
parfor i = 1:o.n
    [ic, sd] = checkCollision(rbC.Value, Q(:, i), 'SkippedSelfCollisions', 'parent', 'Exhaustive', 'on');
    hitM(i) = any(ic);
    v = sd(isfinite(sd));
    if isempty(v), dM(i) = 0; else, dM(i) = min(v); end
    if hitM(i), dM(i) = 0; end
end
tMesh = toc(t0);
nD = size(C.pairs, 1) + numel(C.box);
D = zeros(nD, o.n);
t0 = tic;
for i = 1:o.n
    [~, ~, D(:, i)] = ext_x6_coll(K, Q(:, i), C);
end
tCap = toc(t0) / o.n;
fprintf('Mesh %.1f s (parallel), Kapsel %.3f ms je Aufruf, %d von %d Stellungen mit Mesh-Kollision\n', ...
        tMesh, 1e3 * tCap, sum(hitM), o.n);

names = [compose("seg%d-seg%d", C.pairs(:, 1), C.pairs(:, 2)); compose("seg%d-box", C.box)];
free = ~hitM;
Tc = table(names, 'VariableNames', {'check'});
Tc.false_alarm = mean(D(:, free) < 0, 2);
Tc.hit_share = mean(D(:, hitM) < 0, 2);
Tc.only_hit = arrayfun(@(k) sum(D(k, hitM) < 0 & all(D([1:k-1, k+1:end], hitM) >= 0, 1)), (1:nD).');
Tc.d_min_free = min(D(:, free), [], 2);
R.checks = Tc;
disp(Tc);

dmin = min(D, [], 1).';
dl = (0:0.005:0.05).';
Td = table(dl, 'VariableNames', {'delta'});
Td.missed = arrayfun(@(x) sum(hitM & dmin >= x), dl);
Td.false_alarm = arrayfun(@(x) sum(free & dmin < x), dl);
Td.false_alarm_share = Td.false_alarm / sum(free);
Td.hit_share = arrayfun(@(x) mean(dmin(hitM) < x), dl);
R.delta = Td;
disp(Td);
% Vorfilter und Mesh wie in der Umgebung
rb = ext_x6_coll('robot');
need = false(o.n, 1); hitH = false(o.n, 1);
t0 = tic;
for i = 1:o.n
    [hitH(i), ~, ~, need(i)] = ext_x6_coll(K, Q(:, i), C, rb);
end
tHyb = toc(t0) / o.n;
fprintf('Vorfilter + Mesh: verpasst %d von %d, Fehlalarme %d, Mesh noetig in %.1f %% (%.1f %% der freien), %.2f ms je Aufruf\n', ...
        sum(hitM & ~hitH), sum(hitM), sum(~hitM & hitH), 100 * mean(need), 100 * mean(need(~hitM)), 1e3 * tHyb);
R.hybrid = struct('missed', sum(hitM & ~hitH), 'false_alarm', sum(~hitM & hitH), 'need', mean(need), ...
                  'need_free', mean(need(~hitM)), 't_ms', 1e3 * tHyb);
R.need = need; R.hitH = hitH;
R.Q = Q; R.hitM = hitM; R.dM = dM; R.D = D; R.C = C; R.tMesh = tMesh; R.tCap = tCap;
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
dd = sk_path('data', 'simulation', 'extension');
writetable(Tc, fullfile(dd, sprintf('X6_coll_check_checks_%s.csv', stamp)));
writetable(Td, fullfile(dd, sprintf('X6_coll_check_delta_%s.csv', stamp)));
save(fullfile(dd, sprintf('X6_coll_check_%s.mat', stamp)), 'R');
writetable(struct2table(R.hybrid), fullfile(dd, sprintf('X6_coll_check_hybrid_%s.csv', stamp)));
end
