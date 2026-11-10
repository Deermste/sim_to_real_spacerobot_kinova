function [T, outFile] = ext_x5_1_feasibility(varargin)
%EXT_X5_1_FEASIBILITY  Machbarkeit der 3D-Bahn mit allen sieben Gelenken ueber den Regler aus X2 (Ausbau X5.1).
%   [T, outFile] = ext_x5_1_feasibility()
%
%   Kinematischer Simulator (ext_kinsim), nominal, volle Befehlskette. Der Regler (ext_x2_controller) kennt die
%   Kette (invert). Zusaetzlich die Prioritaetsform mit idealer Kette ('sat') als untere Schranke.
%   Bahnen: planar (wie bisher), tilted +30 und -30 Grad (ext_ref_path, Ebene um die x-Achse durch den Start
%   gekippt). Gelenksaetze:
%     J246  J2, J4, J6 mit 0,9774 rad/s wie die r4-Agenten (Aufgabe x, z bzw. x, y, z), Referenz
%     all7  alle sieben Gelenke, 0,98 rad/s J1-J4, 0,58 rad/s J5-J7 wie beim Set-Point (Aufgabe x, y, z)
%   Regler: R0 (beta 0, ohne Nullraum), Rbeta mit beta 1 bis 1e4, Prioritaet (Bahn zuerst, dann Basis im
%   Nullraum). J6-Seite 0, -1, +1.
%   Kennzahlen je Lauf: rms_ee, ep_q4, max_ee, ori_max, folgt (wie X0.1), Abstand zur Gelenkwinkelgrenze
%   (kleinster Wert und Gelenk, nur J2, J4, J5, J6 haben endliche Grenzen), Anteil der Schritte an einer
%   Geschwindigkeitsgrenze, Ruck, kleinster Singulaerwert der EE-Jacobi-Matrix (Aufgabe, aktive Gelenke) in der
%   Startstellung (sv_start) und entlang der Bahn ab 0,25 s (sv_min), front (Pareto in rms_ee und ori_max je Bahn und Gelenksatz unter den folgenden Laeufen).
%   Ergebnis: data/simulation/extension/X5_1_feasibility_<Zeit>.csv

p = inputParser;
p.addParameter('betas', [0 1 4.6416 21.544 46.416 100 1000 1e4]);
p.addParameter('sides', [0 -1 1]);
p.addParameter('paths', {{'planar', 0}, {'tilted', 30}, {'tilted', -30}});
p.addParameter('save', true);
p.parse(varargin{:});
o = p.Results;
setup_project;
K = ext_kin_model();
qLim = [2*pi; 2.41; 2*pi; 2.66; 2.23; 2.01; 2*pi];
sets = {
    'J246', [2 4 6], [0; 0.9774; 0; 0.9774; 0; 0.9774; 0]
    'all7', 1:7,     [0.98; 0.98; 0.98; 0.98; 0.58; 0.58; 0.58]
    };
rows = {};
tAll = tic;
for ip = 1:numel(o.paths)
    pth = o.paths{ip}{1}; tilt = o.paths{ip}{2};
    for is = 1:size(sets, 1)
        [sName, jnt, lim] = sets{is, :};
        % J246 in der Ebene: Aufgabe x, z (wie X2). Sonst x, y, z.
        task = [1 2 3];
        if strcmp(pth, 'planar') && strcmp(sName, 'J246'), task = [1 3]; end
        variants = [num2cell(o.betas), {'priority'}];
        for iv = 1:numel(variants)
            for side = o.sides
                chains = {'full'};
                if ischar(variants{iv}), chains = {'full', 'sat'}; end
                for ch = chains
                    cargs = {'joints', jnt, 'task', task, 'lim', lim, 'j6_side', side, 'K', K, ...
                             'invert', strcmp(ch{1}, 'full')};
                    if ischar(variants{iv})
                        cargs = [cargs, {'mode', 'priority'}]; %#ok<AGROW>
                        beta = NaN; vname = "priority";
                    else
                        beta = variants{iv}; cargs = [cargs, {'beta', beta}]; %#ok<AGROW>
                        vname = "R" + string(beta);
                    end
                    c = ext_x2_controller(cargs{:});
                    res = ext_kinsim([], 'ctrl', c, 'lim', lim, 'reward_mode', 4, 'path', pth, 'tilt', tilt, ...
                                     'chain', ch{1});
                    rows{end + 1} = metricsOf(res, K, qLim, lim, jnt, task, pth, tilt, sName, vname, beta, ...
                                              side, ch{1}); %#ok<AGROW>
                end
            end
        end
        fprintf('%s %+d %s fertig (%.1f min)\n', pth, tilt, sName, toc(tAll) / 60);
    end
end
T = struct2table([rows{:}]);
T.front = false(height(T), 1);
grp = findgroups(T.path, T.tilt, T.set);
for g = unique(grp).'
    idx = find(grp == g & T.follows == 1 & T.chain == "full");
    for i = idx.'
        dom = T.rms_ee(idx) <= T.rms_ee(i) & T.ori_max(idx) <= T.ori_max(i) & ...
              (T.rms_ee(idx) < T.rms_ee(i) | T.ori_max(idx) < T.ori_max(i));
        T.front(i) = ~any(dom);
    end
end
outFile = '';
if o.save
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    outFile = sk_path('data', 'simulation', 'extension', ['X5_1_feasibility_' stamp '.csv']);
    writetable(T, outFile);
    fprintf('Ergebnis: %s\n', outFile);
end
end

% =====================================================================
function r = metricsOf(res, K, qLim, lim, jnt, task, pth, tilt, sName, vname, beta, side, chain)
m = res.metrics;
q = res.ts.q;
dq = res.ts.dq;
fin = [2 4 5 6];
marg = qLim(fin).' - max(abs(q(:, fin)), [], 1);
[mMin, iMin] = min(marg);
act = lim > 0;
atLim = any(abs(dq(:, act)) >= 0.99 * lim(act).', 2);
jt = res.ts.a_scaled(:, jnt);
jerk = sqrt(mean(sum((diff(jt, 2) / 0.025^2) .^ 2, 2)));
% Startstellung (gestreckt, singulaer) getrennt, Bahnverlauf ab 0,25 s
sv = inf;
[~, ~, Je] = ext_kin_eval(K, q(1, :).');
sv0 = min(svd(Je(task, jnt)));
for i = find(res.ts.t_ee >= 0.25, 1):5:size(q, 1)
    [~, ~, Je] = ext_kin_eval(K, q(i, :).');
    sv = min(sv, min(svd(Je(task, jnt))));
end
follows = ~m.early_stop && m.ep_q4 < 0.05;
r = struct('path', string(pth), 'tilt', tilt, 'set', string(sName), 'variant', vname, 'beta', beta, ...
    'j6_side', side, 'chain', string(chain), 'rms_ee', m.rms_ee, 'ep_q4', m.ep_q4, 'max_ee', m.max_ee, ...
    'ori_max', m.ori_max, 'follows', double(follows), 'early_stop', double(m.early_stop), ...
    'q_margin_min', mMin, 'q_margin_joint', fin(iMin), 'frac_at_vlim', mean(atLim), 'jerk_rms', jerk, ...
    'sv_min', sv, 'sv_start', sv0, 'q1_range', range(q(:, 1)), 'q7_range', range(q(:, 7)));
end
