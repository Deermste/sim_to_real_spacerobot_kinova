function ext_x7_night(smoke)
%EXT_X7_NIGHT  Nachtkette X7 (15./16.11.2026): Auswahl auf dem Entwicklungssatz, Hauptlauf, Schlussauswertung.
%   ext_x7_night()
%   ext_x7_night(true)    Rauchtest: 16 Episoden, ein Seed, kleine Auswertung, Dateien mit Endung _smoke
%
%   Ablauf und Auswahlregeln (vor dem Lauf festgelegt, RESULTS X7.1 und X7.2):
%   A  Bahn: drei Varianten mit Seed 0 (3000 Episoden), Reward J (ext_x7_env):
%        TJ1 resdr w_res 0,1   TJ2 resdr w_res 0,5   TJ3 res w_res 0,1
%      Kandidaten je Lauf: letzter Agent und bester Zwischenstand (kleinstes J der nominalen Trainingsepisode).
%      Dazu der Pilot-Agent X7_res_seed0_ep3000 (Reward r4) als Bezug. Auswahl auf ext_x7_dev: kleinstes J unter
%      den Kandidaten, die mindestens so oft folgen wie R minus 5 Prozentpunkte.
%   B  Set-Point: drei Varianten mit Seed 0, Grundregler Rbeta 1:
%        S1 resdr w_res 0,1    S2 resdr w_res 0,5    S3 res w_res 0,1
%      Kandidaten: letzter Agent und bester Zwischenstand (hoechster Erfolg auf den 16 Pruefpaaren, dann kleinste
%      Summe aus t / t0 und ori / ori0 der Pruefpaare, t0 und ori0 aus dem ersten Block). Auswahl auf
%      ext_x7sp_dev: kleinstes J unter den Kandidaten mit Erfolg mindestens wie R minus 2 Prozentpunkte.
%   C  Bahn, Hauptlauf: gewaehlte Variante mit Seeds 1 bis 10, Stufe wie gewaehlt (letzter Agent oder bester
%      Zwischenstand nach derselben Regel wie in A). Schlussauswertung ext_x7_eval (X0.1, 26 Szenarien).
%   D  Set-Point, Hauptlauf: gewaehlte Variante mit Seeds 1 bis 10, Stufe wie gewaehlt. Schlussauswertung
%      ext_x7sp_eval (100 Testpaare, 26 Szenarien, R0, Rbeta 1, 4,6, 21,5).
%   Jede Stufe in try/catch, ein Fehler stoppt nur die abhaengigen Stufen.

if nargin < 1, smoke = false; end
setup_project;
dd = sk_path('data', 'simulation', 'extension');
nE = 3000; ckE = 250; seeds = 1:10; nDev = 40; nDevS = 48; ev = {}; evS = {}; sfx = '';
if smoke
    nE = 16; ckE = 8; seeds = 1; nDev = 2; nDevS = 2; sfx = '_smoke';
    ev = {'robust', false}; evS = {'nPairs', 2, 'scenarios', {'nominal', 'mass_0.5'}};
end
tr = {'nEpisodes', nE, 'ckptEvery', ckE};
t0 = tic;
selT = []; selS = [];
% ---------------- A ----------------
try
    fprintf('=== A Bahn-Auswahl ===\n');
    VT = struct('name', {'TJ1', 'TJ2', 'TJ3'}, 'variant', {'resdr', 'resdr', 'res'}, ...
                'args', {{'reward', 'J', 'w_res', 0.1}, {'reward', 'J', 'w_res', 0.5}, {'reward', 'J', 'w_res', 0.1}});
    cand = struct('file', {}, 'label', {}, 'eps_v', {}, 'eps_w', {}, 'name', {}, 'stage', {});
    for v = 1:numel(VT)
        out = ext_x7_train(VT(v).variant, 0, 'name', sprintf('X7_A_%s_seed0%s', VT(v).name, sfx), tr{:}, ...
                           VT(v).args{:});
        cand = [cand, trajCand(out, VT(v).name)]; %#ok<AGROW>
        fprintf('  %s fertig (%.1f min)\n', VT(v).name, toc(t0) / 60);
    end
    pf = sk_path('SavedAgents', 'MotionProfile', 'X7', 'X7_res_seed0_ep3000.mat');
    if isfile(pf)
        cand(end + 1) = struct('file', pf, 'label', 'P_r4_final', 'eps_v', 0.02, 'eps_w', 0.01, 'name', 'P_r4', ...
                               'stage', 'final');
    end
    T = ext_x7_dev(cand, 'n', nDev);
    T.J = T.rms_ee / 0.00899 + T.ori_max / 0.01298;
    writetable(T, fullfile(dd, sprintf('X7_A_dev%s_%s.csv', sfx, stampNow())));
    disp(T);
    ok = T.follows(2:end) >= T.follows(1) - 0.05;
    Jc = T.J(2:end); Jc(~ok) = Inf;
    [~, ib] = min(Jc);
    selT = cand(ib);
    fprintf('A gewaehlt: %s (%s), J %.3f gegen R %.3f\n', selT.label, selT.stage, T.J(ib + 1), T.J(1));
catch err
    fprintf(2, 'A Fehler: %s\n', getReport(err));
end
% ---------------- B ----------------
try
    fprintf('=== B Set-Point-Auswahl (%.1f min) ===\n', toc(t0) / 60);
    VS = struct('name', {'S1', 'S2', 'S3'}, 'variant', {'resdr', 'resdr', 'res'}, ...
                'args', {{'w_res', 0.1}, {'w_res', 0.5}, {'w_res', 0.1}});
    cand = struct('file', {}, 'label', {}, 'beta', {}, 'eps_v', {}, 'eps_w', {}, 'name', {}, 'stage', {});
    for v = 1:numel(VS)
        out = ext_x7sp_train(VS(v).variant, 0, 'name', sprintf('X7sp_B_%s_seed0%s', VS(v).name, sfx), tr{:}, ...
                             VS(v).args{:});
        cand = [cand, spCand(out, VS(v).name)]; %#ok<AGROW>
        fprintf('  %s fertig (%.1f min)\n', VS(v).name, toc(t0) / 60);
    end
    T = ext_x7sp_dev(cand, 'n', nDevS);
    writetable(T, fullfile(dd, sprintf('X7sp_B_dev%s_%s.csv', sfx, stampNow())));
    disp(T);
    ok = T.success(2:end) >= T.success(1) - 0.02;
    Jc = T.J(2:end); Jc(~ok) = Inf;
    [~, ib] = min(Jc);
    selS = cand(ib);
    fprintf('B gewaehlt: %s (%s), J %.3f gegen R %.3f\n', selS.label, selS.stage, T.J(ib + 1), T.J(1));
catch err
    fprintf(2, 'B Fehler: %s\n', getReport(err));
end
% ---------------- C ----------------
if ~isempty(selT)
    try
        fprintf('=== C Bahn-Hauptlauf %s (%.1f min) ===\n', selT.name, toc(t0) / 60);
        v = VT(strcmp({VT.name}, selT.name));
        if isempty(v), v = struct('name', 'P_r4', 'variant', 'res', 'args', {{'reward', 'r4', 'w_res', 0.1}}); end
        list = struct('file', {}, 'label', {}, 'group', {}, 'eps_v', {}, 'eps_w', {});
        for s = seeds
            out = ext_x7_train(v.variant, s, 'name', sprintf('X7_C_%s_seed%d%s', v.name, s, sfx), tr{:}, v.args{:});
            c = trajCand(out, v.name);
            c = c(strcmp({c.stage}, selT.stage));
            list(end + 1) = struct('file', c.file, 'label', sprintf('%s_s%d', v.name, s), 'group', ...
                                   ['res_' v.variant], 'eps_v', c.eps_v, 'eps_w', c.eps_w); %#ok<AGROW>
            fprintf('  Seed %d fertig (%.1f min)\n', s, toc(t0) / 60);
        end
        save(fullfile(dd, sprintf('X7_C_list_%s.mat', stampNow())), 'list', 'selT');
        ext_x7_eval(list, 'label', ['C' sfx], ev{:});
    catch err
        fprintf(2, 'C Fehler: %s\n', getReport(err));
    end
end
% ---------------- D ----------------
if ~isempty(selS)
    try
        fprintf('=== D Set-Point-Hauptlauf %s (%.1f min) ===\n', selS.name, toc(t0) / 60);
        v = VS(strcmp({VS.name}, selS.name));
        list = struct('file', {}, 'label', {}, 'group', {}, 'beta', {}, 'eps_v', {}, 'eps_w', {});
        for s = seeds
            out = ext_x7sp_train(v.variant, s, 'name', sprintf('X7sp_D_%s_seed%d%s', v.name, s, sfx), tr{:}, ...
                                 v.args{:});
            c = spCand(out, v.name);
            c = c(strcmp({c.stage}, selS.stage));
            list(end + 1) = struct('file', c.file, 'label', sprintf('%s_s%d', v.name, s), 'group', ...
                                   ['res_' v.variant], 'beta', c.beta, 'eps_v', c.eps_v, 'eps_w', c.eps_w); %#ok<AGROW>
            fprintf('  Seed %d fertig (%.1f min)\n', s, toc(t0) / 60);
        end
        save(fullfile(dd, sprintf('X7sp_D_list_%s.mat', stampNow())), 'list', 'selS');
        ext_x7sp_eval(list, 'label', ['D' sfx], evS{:});
    catch err
        fprintf(2, 'D Fehler: %s\n', getReport(err));
    end
end
fprintf('=== X7-Nachtkette fertig nach %.1f h ===\n', toc(t0) / 3600);
end

% =====================================================================
function c = trajCand(out, name)
ck = out.ckpt;
J = ck.nom_rms_ee / 0.00899 + ck.nom_ori_max / 0.01298 + 100 * ck.nom_stop;
[~, ib] = min(J);
ev = out.cfg.eps_v; ew = out.cfg.eps_w;
c = struct('file', {out.agentFile, char(ck.file(ib))}, 'label', {[name '_final'], sprintf('%s_ep%d', name, ...
           ck.episodes(ib))}, 'eps_v', ev, 'eps_w', ew, 'name', name, 'stage', {'final', 'best'});
end

function c = spCand(out, name)
ck = out.ckpt;
sc = ck.t_settle / ck.t_settle(1) + ck.ori_max / ck.ori_max(1) - 10 * ck.succ;
[~, ib] = min(sc);
cf = out.cfg;
c = struct('file', {out.agentFile, char(ck.file(ib))}, 'label', {[name '_final'], sprintf('%s_ep%d', name, ...
           ck.episodes(ib))}, 'beta', cf.beta, 'eps_v', cf.eps_v, 'eps_w', cf.eps_w, 'name', name, ...
           'stage', {'final', 'best'});
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
end
