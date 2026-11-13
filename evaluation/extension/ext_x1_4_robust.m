function R = ext_x1_4_robust(varargin)
%EXT_X1_4_ROBUST  Sicherheitsfilter unter den Stoerungen aus X2.3 (Ausbau X1.4, Teil 3).
%   R = ext_x1_4_robust()                         rechnen und auswerten
%   R = ext_x1_4_robust('stamp', '20261113_...')  nur auswerten
%
%   Teilnehmer: die zehn r1-Agenten aus X1.3 (r1_s<Seed>) ohne Filter und mit ext_x1_shield nach der Kette fuer
%   theta 0,02 bis 0,06 (alpha 5, Nominalmodell 65 kg, gemessene Lage und Gelenkwinkel, also mit Rauschen und
%   Messfehler der Szenarien), dazu die Regler wie in X2.3. 26 Szenarien wie ext_x2_robust, kinematisch.
%   Vergleich mit den trainierten Budget-Agenten aus X2.3 Teil 2 (X2_robust_<x23>_summary.csv, th<mrad>_s<Seed>).
%   Kennzahlen je Gruppe (Filter: r1_f<mrad>, Training: th<mrad>), Definitionen wie ext_x2_3_x13_report:
%     n_nom_budget   Agenten, die nominal folgen und das Budget halten (ori_max <= theta + 5 mrad)
%     budget_share   Anteil ihrer 25 Stoerszenarien, in denen sie weiter folgen und das Budget halten
%     follow_share   Anteil der Stoerszenarien, in denen nominal folgende Agenten weiter folgen
%     over_max       groesste Ueberschreitung von theta in diesen Szenarien [rad]
%     rms_med        Median RMS der Paare mit Budget [m]
%   Dazu budget_share je Szenariogruppe (Modell, Aktor, Sensor, Anfang) und je Szenario.
%   CSV: data/simulation/extension/X1_4_robust_{groups,sgroups,scen}_<stamp>.csv

p = inputParser;
p.addParameter('stamp', '');
p.addParameter('x23', '20261113_090316');
p.addParameter('thetas', [0.02 0.03 0.04 0.05 0.06]);
p.addParameter('alpha', 5);
p.parse(varargin{:});
o = p.Results;
setup_project;
d = sk_path('data', 'simulation', 'extension');
stamp = o.stamp;
if isempty(stamp)
    ma = sk_path('SavedAgents', 'MotionProfile');
    list = struct('file', {}, 'label', {}, 'group', {});
    for s = 0:9
        f = fullfile(ma, 'X1', sprintf('X1_ppo_40hz_r5_c1_th30_eta0_seed%d_ep3000_b50.mat', s));
        list(end + 1) = struct('file', f, 'label', sprintf('r1_s%d', s), 'group', 'r1'); %#ok<AGROW>
    end
    [~, ~, outFile] = ext_x2_robust('agents', list, 'shield', struct('thetas', o.thetas, 'alpha', o.alpha));
    [~, stamp] = fileparts(outFile);
    stamp = char(extractAfter(string(stamp), "X2_robust_"));
end

S = readtable(fullfile(d, ['X2_robust_' stamp '_summary.csv']), 'TextType', 'string');
T = readtable(fullfile(d, ['X2_robust_' o.x23 '_summary.csv']), 'TextType', 'string');
T = T(startsWith(T.subject, "th"), :);
T.group = extractBefore(T.subject, "_");
tol = 0.005;
rows = {}; srows = {}; crows = {};
for th = o.thetas
    tag = sprintf('%d', round(th * 1000));
    sets = {"r1_f" + tag, S(S.group == "r1_f" + tag, :), "Filter"; "th" + tag, T(T.group == "th" + tag, :), "Training"};
    for k = 1:2
        G = sets{k, 2};
        N = G(G.scenario == "nominal", :);
        nf = N.subject(N.follows_all == 1);
        nb = N.subject(N.follows_all == 1 & N.ori_max <= th + tol);
        P = G(G.scenario ~= "nominal" & ismember(G.subject, nf), :);
        Q = G(G.scenario ~= "nominal" & ismember(G.subject, nb), :);
        ok = Q.follows_all == 1 & Q.ori_max <= th + tol;
        rows{end + 1} = struct('theta', th, 'kind', sets{k, 3}, 'group', sets{k, 1}, 'n', height(N), ...
            'n_nom_follow', numel(nf), 'n_nom_budget', numel(nb), 'follow_share', mean(P.follows_all), ...
            'budget_share', mean(ok), 'over_max', max([Q.ori_max - th; -Inf]), ...
            'rms_med', median(Q.rms_ee(ok))); %#ok<AGROW>
        for sg = unique(Q.sgroup).'
            m = Q.sgroup == sg;
            srows{end + 1} = struct('theta', th, 'kind', sets{k, 3}, 'sgroup', sg, 'n_pairs', sum(m), ...
                                    'budget_share', mean(ok(m))); %#ok<AGROW>
        end
        for sc = unique(Q.scenario).'
            m = Q.scenario == sc;
            crows{end + 1} = struct('theta', th, 'kind', sets{k, 3}, 'scenario', sc, 'n_pairs', sum(m), ...
                'budget_share', mean(ok(m)), 'ori_max_med', median(Q.ori_max(m))); %#ok<AGROW>
        end
    end
end
R.groups = struct2table([rows{:}]);
R.sgroups = struct2table([srows{:}]);
R.scen = struct2table([crows{:}]);
for nm = ["groups", "sgroups", "scen"]
    writetable(R.(nm), fullfile(d, sprintf('X1_4_robust_%s_%s.csv', nm, stamp)));
end
disp(R.groups); disp(R.sgroups);
end
