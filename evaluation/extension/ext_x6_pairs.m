function [P, outFile] = ext_x6_pairs(varargin)
%EXT_X6_PAIRS  Start-Ziel-Paare fuer X6 (X6.1): Auswertesatz mit Kollisionspruefung und die Paare der Labortage.
%   [P, outFile] = ext_x6_pairs()
%   [P, outFile] = ext_x6_pairs('nEval', 50, 'maxTries', 2000)     kleiner Lauf
%
%   Bezugspunkt ist die Greiferspitze (ext_kin_model 'tool_offset' [0; 0; 0,121], wie tool_pose der Kortex-API,
%   kortex_frames). Winkelgrenzen nach Datenblatt (chain_step('params').q_lim).
%   Auswertesatz (set "eval", fester Seed):
%     Start q0 und Zielstellung qT gleichverteilt: Endlosgelenke [-pi, pi], sonst Datenblattgrenze minus 5 Grad.
%     Kollisionspruefung (Robotics System Toolbox, Meshes der URDF, Basiswuerfel, Greifer als Zylinder r 4,5 cm
%     von 2 bis 17 cm vor dem EE-Flansch, Paare Eltern-Kind ausgenommen) fuer q0, qT und 12 Zwischenstellungen
%     der geraden Gelenkbahn. Die Basis dreht sich mit, das aendert die Kollision zwischen Arm und Basis nicht.
%     Zielpunkt pT = Greiferspitze nach dieser Gelenkbahn im frei schwebenden Simulator (hoechstens 0,4 rad/s
%     je Gelenk, Kette 'sat'), im Inertialsystem (Basis am Start). Das Ziel ist damit unter frei schwebender
%     Kinematik auf mindestens einem kollisionsfreien Weg erreichbar.
%     Schichtung: d0 = |pT - p0| in [0,05 0,2), [0,2 0,5), [0,5 0,8), [0,8 1,2] m und Bereich des Ziels
%     ('unten': z < 0,6 m, also hoechstens 10 cm ueber der Montageflaeche z = 0,5 m, 'nah': Abstand zur Schulter
%     [0 0 0,78] unter 0,5 m, sonst 'weit'). Je Zelle bis zu nEval/12 Paare, Rest aus dem Ueberlauf.
%   Labortage (set "lab"): 15 Starts aus setpoint_starts.mat x 9 Ziele aus setpoint_targets.mat (Stellung
%     q_check_deg der Zielpruefung). Zielpunkt = Greiferspitze dieser Stellung bei fester Basis (im Inertialsystem am Start). Ob er frei schwebend
%     erreichbar ist, ist offen (reach_known = 0).
%   Je Paar: q0, qT, p0, pT, d0, Zelle, ori_path (Basisdrehung entlang der offenen Bahn), minz_path (tiefster
%   Punkt der Greiferspitze entlang der Bahn, kinematisch frei schwebend), hw_ok (minz_path > 0,55 m, fuer den
%   Labortag auf dem Tisch; im Simulator gilt keine Hoehengrenze).
%   Trainingssatz: ext_x6_pairs('set', "train", 'seed', 1, 'nEval', 2000, 'lab', false), gleiches Verfahren mit
%     anderem Seed, ohne Laborpaare, Datei X6_train_<Zeit>.
%   Optionen: 'parallel' (Standard true, Kollisionspruefung und offene Bahn im parfor, Ziehungen seriell und damit
%     bitgleich zur seriellen Fassung), 'save' (Standard true).
%   Ergebnis: data/simulation/extension/X6_pairs_<Zeit>.mat (P) und .csv

p = inputParser;
p.addParameter('nEval', 500);
p.addParameter('maxTries', 20000);
p.addParameter('seed', 0);
p.addParameter('set', "eval");
p.addParameter('lab', true);
p.addParameter('parallel', true);
p.addParameter('save', true);
p.addParameter('batch', 400);
p.parse(varargin{:});
o = p.Results;
setup_project;
K = ext_kin_model('tool_offset', [0; 0; 0.121]);
C = chain_step('params');
qHw = min(C.q_lim, 2 * pi);
fin = isfinite(C.q_lim);
qS = pi * ones(7, 1);
qS(fin) = C.q_lim(fin) - deg2rad(5);
rb = collisionRobot();
bins = [0.05 0.2 0.5 0.8 1.2];
regs = ["unten", "nah", "weit"];
quota = ceil(o.nEval / 12);
cells = cell(4, 3); over = {};
rs = RandStream('mt19937ar', 'Seed', o.seed);
t0 = tic; tries = 0; nColl = 0;
if o.parallel
    rbC = parallel.pool.Constant(@collisionRobot);
end
full = @() sum(cellfun(@numel, cells), 'all') >= 12 * quota;
while tries < o.maxTries && ~full()
    % Ziehungen seriell (gleiche Folge wie frueher), Pruefung im Block
    nb = min(o.batch, o.maxTries - tries);
    Q0 = zeros(7, nb); QT = zeros(7, nb);
    for j = 1:nb
        Q0(:, j) = (2 * rand(rs, 7, 1) - 1) .* qS;
        QT(:, j) = (2 * rand(rs, 7, 1) - 1) .* qS;
    end
    res = cell(nb, 1);
    if o.parallel
        parfor j = 1:nb
            if pathFree(rbC.Value, Q0(:, j), QT(:, j)), res{j} = openPath(Q0(:, j), QT(:, j), K, qHw); end
        end
    else
        for j = 1:nb
            if pathFree(rb, Q0(:, j), QT(:, j)), res{j} = openPath(Q0(:, j), QT(:, j), K, qHw); end
        end
    end
    for j = 1:nb
        if full(), break; end
        tries = tries + 1;
        pr = res{j};
        if isempty(pr), nColl = nColl + 1; continue; end
        if pr.d0 < bins(1) || pr.d0 > bins(end), continue; end
        b = find(pr.d0 >= bins(1:end - 1), 1, 'last');
        g = find(regs == region(pr.pT));
        pr.d0bin = b; pr.region = regs(g); pr.set = string(o.set);
        if numel(cells{b, g}) < quota, cells{b, g}{end + 1} = pr; else, over{end + 1} = pr; end %#ok<AGROW>
    end
    fprintf('%5d Ziehungen, %4d in Zellen, %4d Ueberlauf, %.1f min\n', tries, ...
            sum(cellfun(@numel, cells), 'all'), numel(over), toc(t0) / 60);
end
% Zustand des Zufallsstroms wie nach genau 'tries' seriellen Ziehungen (fuer randperm unten)
rs = RandStream('mt19937ar', 'Seed', o.seed);
rand(rs, 14 * tries, 1);
E = [cells{:}];
nMiss = o.nEval - numel(E);
if nMiss > 0 && ~isempty(over)
    idx = randperm(rs, numel(over), min(nMiss, numel(over)));
    E = [E, over(idx)];
end
E = E(1:min(o.nEval, numel(E)));
fprintf('Satz %s: %d Paare aus %d Ziehungen (%d mit Kollision), %.1f min\n', o.set, numel(E), tries, nColl, ...
        toc(t0) / 60);

% --- Labortage ---
L = {};
if o.lab
S = load(sk_path('hardware', 'campaign', 'setpoint_starts.mat'));
Tg = load(sk_path('hardware', 'campaign', 'setpoint_targets.mat'));
st = S.S.starts; tg = Tg.T.targets;
for i = 1:numel(st)
    for j = 1:numel(tg)
        q0 = deg2rad(st(i).q_deg(:)); qT = deg2rad(tg(j).q_check_deg(:));
        [~, p0] = ext_kin_eval(K, q0);
        [~, pT] = ext_kin_eval(K, qT);
        pr = struct('q0', q0, 'qT', qT, 'p0', p0, 'pT', pT, 'd0', norm(pT - p0), 'ori_path', NaN, ...
                    'minz_path', NaN, 'hw_ok', 1, 'reach_known', 0, 'd0bin', NaN, 'region', region(pT), ...
                    'set', "lab", 'lab_start', string(st(i).id), 'lab_target', string(tg(j).id));
        L{end + 1} = pr; %#ok<AGROW>
    end
end
end
for k = 1:numel(E)
    E{k}.reach_known = 1; E{k}.lab_start = ""; E{k}.lab_target = "";
end
all = [E, L];
for k = 1:numel(all), all{k}.id = k; all{k} = orderfields(all{k}); end
P = [all{:}];

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
pre = 'X6_pairs_';
if o.set ~= "eval", pre = sprintf('X6_%s_', o.set); end
outFile = sk_path('data', 'simulation', 'extension', [pre stamp]);
meta = struct('seed', o.seed, 'set', string(o.set), 'nEval', o.nEval, 'tries', tries, 'nColl', nColl, 'quota', quota, ...
              'tool_offset', K.tool, 'q_lim', C.q_lim, 'date', stamp);
T = struct2table(arrayfun(@flat, P));
if o.save
    save([outFile '.mat'], 'P', 'meta');
    writetable(T, [outFile '.csv']);
    fprintf('Ergebnis: %s.mat / .csv\n', outFile);
else
    outFile = '';
end
G = groupsummary(T(T.set == string(o.set), :), {'d0bin', 'region'});
disp(G);
end

% =====================================================================
function rb = collisionRobot()
rb = importrobot(sk_path('robot', 'SpaceKinova.urdf'), 'DataFormat', 'column', 'MeshPath', {sk_path()});
g = rigidBody('gripper');
c = collisionCylinder(0.045, 0.15);
c.Pose = trvec2tform([0 0 0.095]);
addCollision(g, c);
addBody(rb, g, 'kinova_end_effector_link');
end

function ok = pathFree(rb, q0, qT)
ok = false;
for s = [0 1 (1:12) / 13]
    q = q0 + s * (qT - q0);
    if any(checkCollision(rb, q, 'SkippedSelfCollisions', 'parent')), return; end
end
ok = true;
end

function pr = openPath(q0, qT, K, qHw)
Tm = max(abs(qT - q0)) / 0.4;
n = max(ceil(Tm / 0.05), 1);
seq = repmat(((qT - q0) / (n * 0.05)).', n + 1, 1);
seq(end, :) = 0;
r = ext_kinsim([], 'actionSeq', seq, 'chain', 'sat', 'lim', 0.5 * ones(7, 1), 'Ts_agent', 0.05, ...
               'T', (n + 10) * 0.05, 'K', K, 'q0', q0, 'reward_mode', 1, 'noStop', true, 'qLim', qHw, ...
               'refFcn', @(t) zeros(numel(t), 3));
p0 = r.ts.ep(1, :).'; pT = r.ts.ep(end, :).';
pr = struct('q0', q0, 'qT', qT, 'p0', p0, 'pT', pT, 'd0', norm(pT - p0), 'ori_path', r.metrics.ori_max, ...
            'minz_path', min(r.ts.ep(:, 3)), 'hw_ok', double(min(r.ts.ep(:, 3)) > 0.55));
end

function g = region(pT)
if pT(3) < 0.6
    g = "unten";
elseif norm(pT(:) - [0; 0; 0.78]) < 0.5
    g = "nah";
else
    g = "weit";
end
end

function f = flat(pr)
f = struct('id', pr.id, 'set', pr.set, 'd0', pr.d0, 'd0bin', pr.d0bin, 'region', pr.region, ...
    'ori_path', pr.ori_path, 'minz_path', pr.minz_path, 'hw_ok', pr.hw_ok, 'reach_known', pr.reach_known, ...
    'lab_start', pr.lab_start, 'lab_target', pr.lab_target);
for k = 1:7, f.(sprintf('q0_%d', k)) = pr.q0(k); end
for k = 1:7, f.(sprintf('qT_%d', k)) = pr.qT(k); end
for k = 1:3, f.(sprintf('p0_%d', k)) = pr.p0(k); f.(sprintf('pT_%d', k)) = pr.pT(k); end
end
