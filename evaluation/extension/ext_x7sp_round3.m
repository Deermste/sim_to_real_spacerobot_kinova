function ext_x7sp_round3(smoke)
%EXT_X7SP_ROUND3  Dritte Set-Point-Runde X7 (15.11.2026), Regeln in RESULTS X7.6 (vor dem Lauf festgelegt).
%   ext_x7sp_round3()
%   ext_x7sp_round3(true)    Rauchtest: 16 Episoden, ein Seed, kleine Auswertung, Dateien mit Endung _smoke
%
%   Reward 'sp' (ext_x7sp_env), alle mit gate, beta 1, w_res 0,1, je Seed 0 und 3000 Episoden:
%     S7 resdr w_ori 1    S8 resdr w_ori 3    S9 res w_ori 1
%   Kandidaten (letzter Agent, bester Zwischenstand) und Auswahl wie ext_x7_round2 Teil S: Erfolg mindestens wie
%   R minus 2 Prozentpunkte und J kleiner als bei R auf ext_x7sp_dev. Sonst entfaellt der Hauptlauf.
%   Hauptlauf: Seeds 1 bis 10, Schlussauswertung ext_x7sp_eval (Label F) mit dem Kriterium aus X7.2.

if nargin < 1, smoke = false; end
setup_project;
dd = sk_path('data', 'simulation', 'extension');
nE = 3000; ckE = 250; seeds = 1:10; nDev = 48; evS = {}; sfx = '';
if smoke
    nE = 16; ckE = 8; seeds = 1; nDev = 2; sfx = '_smoke';
    evS = {'nPairs', 2, 'scenarios', {'nominal', 'mass_0.5'}};
end
tr = {'nEpisodes', nE, 'ckptEvery', ckE, 'w_res', 0.1, 'reward', 'sp', 'gate', true};
t0 = tic;
VS = struct('name', {'S7', 'S8', 'S9'}, 'variant', {'resdr', 'resdr', 'res'}, ...
            'args', {{'w_ori', 1}, {'w_ori', 3}, {'w_ori', 1}});
sel = [];
try
    fprintf('=== Set-Point dritte Runde ===\n');
    cand = struct('file', {}, 'label', {}, 'beta', {}, 'eps_v', {}, 'eps_w', {}, 'gate', {}, 'name', {}, ...
                  'stage', {});
    for v = 1:numel(VS)
        out = ext_x7sp_train(VS(v).variant, 0, 'name', sprintf('X7sp_F_%s_seed0%s', VS(v).name, sfx), tr{:}, ...
                             VS(v).args{:});
        cand = [cand, spCand(out, VS(v).name)]; %#ok<AGROW>
        fprintf('  %s fertig (%.1f min)\n', VS(v).name, toc(t0) / 60);
    end
    T = ext_x7sp_dev(cand, 'n', nDev);
    writetable(T, fullfile(dd, sprintf('X7sp_F_dev%s_%s.csv', sfx, stampNow())));
    disp(T);
    ok = T.success(2:end) >= T.success(1) - 0.02 & T.J(2:end) < T.J(1);
    Jc = T.J(2:end); Jc(~ok) = Inf;
    [jb, ib] = min(Jc);
    if isfinite(jb) || smoke
        sel = cand(ib);
        fprintf('Gewaehlt: %s (%s), J %.3f gegen R %.3f\n', sel.label, sel.stage, T.J(ib + 1), T.J(1));
    else
        fprintf('Kein Kandidat besser als R auf dem Entwicklungssatz, Hauptlauf entfaellt\n');
    end
catch err
    fprintf(2, 'Auswahl Fehler: %s\n', getReport(err));
end
if ~isempty(sel)
    try
        fprintf('=== Hauptlauf %s (%.1f min) ===\n', sel.name, toc(t0) / 60);
        v = VS(strcmp({VS.name}, sel.name));
        list = struct('file', {}, 'label', {}, 'group', {}, 'beta', {}, 'eps_v', {}, 'eps_w', {}, 'gate', {});
        for s = seeds
            out = ext_x7sp_train(v.variant, s, 'name', sprintf('X7sp_F_%s_seed%d%s', v.name, s, sfx), tr{:}, ...
                                 v.args{:});
            c = spCand(out, v.name);
            c = c(strcmp({c.stage}, sel.stage));
            list(end + 1) = struct('file', c.file, 'label', sprintf('%s_s%d', v.name, s), 'group', ...
                                   ['res_' v.variant], 'beta', c.beta, 'eps_v', c.eps_v, 'eps_w', c.eps_w, ...
                                   'gate', c.gate); %#ok<AGROW>
            fprintf('  Seed %d fertig (%.1f min)\n', s, toc(t0) / 60);
        end
        save(fullfile(dd, sprintf('X7sp_F_list%s_%s.mat', sfx, stampNow())), 'list', 'sel');
        ext_x7sp_eval(list, 'label', ['F' sfx], evS{:});
    catch err
        fprintf(2, 'Hauptlauf Fehler: %s\n', getReport(err));
    end
end
fprintf('=== Set-Point dritte Runde fertig nach %.1f h ===\n', toc(t0) / 3600);
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
