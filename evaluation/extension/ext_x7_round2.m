function ext_x7_round2(smoke)
%EXT_X7_ROUND2  Zweite Runde X7 (15.11.2026): Bestaetigung Bahn, neuer Set-Point-Ansatz. Regeln in RESULTS X7.3, X7.4.
%   ext_x7_round2()
%   ext_x7_round2(true)    Rauchtest: 16 Episoden, ein Seed, kleine Auswertung, Dateien mit Endung _smoke
%
%   T  Bahn, Bestaetigung (vor dem Lauf festgelegt, RESULTS X7.3): Einstellung des Hauptlaufs C (res, Reward r4,
%      w_res 0,1, letzter Agent) mit neuen Seeds 11 bis 20. Schlussauswertung ext_x7_eval mit dem klassischen
%      Regler C2 (Kp 12, beta 26,1, J6-Seite -1), der nominal am Ort der Residual-Policy liegt.
%   S  Set-Point, zweite Runde (RESULTS X7.4): Reward 'ref' (Abstand zur Referenz), drei Varianten mit Seed 0:
%        S4 resdr ref gate   S5 res ref gate   S6 resdr ref ohne gate     (w_res 0,1, beta 1)
%      Kandidaten und Auswahl wie B in ext_x7_night, zusaetzlich muss J auf dem Entwicklungssatz kleiner sein als
%      bei R. Erfuellt das kein Kandidat, entfaellt der Hauptlauf. Sonst Seeds 1 bis 10, ext_x7sp_eval (Label E).

if nargin < 1, smoke = false; end
setup_project;
dd = sk_path('data', 'simulation', 'extension');
nE = 3000; ckE = 250; seedsT = 11:20; seedsS = 1:10; nDevS = 48; ev = {}; evS = {}; sfx = '';
if smoke
    nE = 16; ckE = 8; seedsT = 11; seedsS = 1; nDevS = 2; sfx = '_smoke';
    ev = {'robust', false}; evS = {'nPairs', 2, 'scenarios', {'nominal', 'mass_0.5'}};
end
tr = {'nEpisodes', nE, 'ckptEvery', ckE};
t0 = tic;
% ---------------- T ----------------
try
    fprintf('=== T Bahn-Bestaetigung ===\n');
    bC2 = logspace(0, 2, 25);
    ctl = {'C2', {'beta', bC2(18), 'j6_side', -1, 'Kp', 12}};
    list = struct('file', {}, 'label', {}, 'group', {}, 'eps_v', {}, 'eps_w', {});
    for s = seedsT
        out = ext_x7_train('res', s, 'name', sprintf('X7_T2_P_r4_seed%d%s', s, sfx), tr{:}, 'reward', 'r4', ...
                           'w_res', 0.1);
        list(end + 1) = struct('file', out.agentFile, 'label', sprintf('P_r4_s%d', s), 'group', 'res_res', ...
                               'eps_v', out.cfg.eps_v, 'eps_w', out.cfg.eps_w); %#ok<AGROW>
        fprintf('  Seed %d fertig (%.1f min)\n', s, toc(t0) / 60);
    end
    save(fullfile(dd, sprintf('X7_T2_list%s_%s.mat', sfx, stampNow())), 'list', 'ctl');
    ext_x7_eval(list, 'label', ['T2' sfx], 'controllers', ctl, ev{:});
catch err
    fprintf(2, 'T Fehler: %s\n', getReport(err));
end
% ---------------- S ----------------
selS = [];
try
    fprintf('=== S Set-Point zweite Runde (%.1f min) ===\n', toc(t0) / 60);
    VS = struct('name', {'S4', 'S5', 'S6'}, 'variant', {'resdr', 'res', 'resdr'}, ...
                'args', {{'reward', 'ref', 'gate', true}, {'reward', 'ref', 'gate', true}, ...
                         {'reward', 'ref', 'gate', false}});
    cand = struct('file', {}, 'label', {}, 'beta', {}, 'eps_v', {}, 'eps_w', {}, 'gate', {}, 'name', {}, ...
                  'stage', {});
    for v = 1:numel(VS)
        out = ext_x7sp_train(VS(v).variant, 0, 'name', sprintf('X7sp_E_%s_seed0%s', VS(v).name, sfx), tr{:}, ...
                             'w_res', 0.1, VS(v).args{:});
        cand = [cand, spCand(out, VS(v).name)]; %#ok<AGROW>
        fprintf('  %s fertig (%.1f min)\n', VS(v).name, toc(t0) / 60);
    end
    T = ext_x7sp_dev(cand, 'n', nDevS);
    writetable(T, fullfile(dd, sprintf('X7sp_E_dev%s_%s.csv', sfx, stampNow())));
    disp(T);
    ok = T.success(2:end) >= T.success(1) - 0.02 & T.J(2:end) < T.J(1);
    Jc = T.J(2:end); Jc(~ok) = Inf;
    [jb, ib] = min(Jc);
    if isfinite(jb) || smoke
        selS = cand(ib);
        fprintf('S gewaehlt: %s (%s), J %.3f gegen R %.3f\n', selS.label, selS.stage, T.J(ib + 1), T.J(1));
    else
        fprintf('S: kein Kandidat besser als R auf dem Entwicklungssatz, Hauptlauf entfaellt\n');
    end
catch err
    fprintf(2, 'S Fehler: %s\n', getReport(err));
end
if ~isempty(selS)
    try
        fprintf('=== S Hauptlauf %s (%.1f min) ===\n', selS.name, toc(t0) / 60);
        v = VS(strcmp({VS.name}, selS.name));
        list = struct('file', {}, 'label', {}, 'group', {}, 'beta', {}, 'eps_v', {}, 'eps_w', {}, 'gate', {});
        for s = seedsS
            out = ext_x7sp_train(v.variant, s, 'name', sprintf('X7sp_E_%s_seed%d%s', v.name, s, sfx), tr{:}, ...
                                 'w_res', 0.1, v.args{:});
            c = spCand(out, v.name);
            c = c(strcmp({c.stage}, selS.stage));
            list(end + 1) = struct('file', c.file, 'label', sprintf('%s_s%d', v.name, s), 'group', ...
                                   ['res_' v.variant], 'beta', c.beta, 'eps_v', c.eps_v, 'eps_w', c.eps_w, ...
                                   'gate', c.gate); %#ok<AGROW>
            fprintf('  Seed %d fertig (%.1f min)\n', s, toc(t0) / 60);
        end
        save(fullfile(dd, sprintf('X7sp_E_list%s_%s.mat', sfx, stampNow())), 'list', 'selS');
        ext_x7sp_eval(list, 'label', ['E' sfx], evS{:});
    catch err
        fprintf(2, 'S Hauptlauf Fehler: %s\n', getReport(err));
    end
end
fprintf('=== X7 zweite Runde fertig nach %.1f h ===\n', toc(t0) / 3600);
end

% =====================================================================
function c = spCand(out, name)
ck = out.ckpt;
sc = ck.t_settle / ck.t_settle(1) + ck.ori_max / ck.ori_max(1) - 10 * ck.succ;
[~, ib] = min(sc);
cf = out.cfg;
c = struct('file', {out.agentFile, char(ck.file(ib))}, 'label', {[name '_final'], sprintf('%s_ep%d', name, ...
           ck.episodes(ib))}, 'beta', cf.beta, 'eps_v', cf.eps_v, 'eps_w', cf.eps_w, 'gate', cf.gate, ...
           'name', name, 'stage', {'final', 'best'});
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
end
