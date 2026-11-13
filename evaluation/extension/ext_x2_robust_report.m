function [T, D] = ext_x2_robust_report(stamp, varargin)
%EXT_X2_ROBUST_REPORT  Auswertung einer Robustheitsstudie (ext_x2_robust): Agentengruppen gegen die Regler.
%   [T, D] = ext_x2_robust_report('20261111_112342')
%   [T, D] = ext_x2_robust_report(stamp, 'ctrl', {'R0', 'Rb1', 'Rb21', 'Rb46'}, 'ref', 'w2')
%
%   Liest X2_robust_<stamp>_summary.csv (eine Zeile je Szenario und Teilnehmer). Gruppen der Agenten: Spalte
%   group, die Gruppe rl wird nach dem Gewicht im Label aufgeteilt (w0, w2, w4, w8, w16).
%   Faktor wie in X2.3: RMS des Agenten geteilt durch den kleinsten RMS eines Reglers aus 'ctrl', der in allen
%   Wiederholungen folgt und hoechstens dieselbe Basisdrehung hat. "Nicht dominiert": kein solcher Regler oder
%   Faktor < 1.
%
%   T  je Szenario und Gruppe: n, Anzahl folgt, Median RMS, Median ori_max, Median Delta-RMS zu nominal,
%      Median Faktor, Anzahl nicht dominiert, p (Mann-Whitney-U zweiseitig) fuer Delta-RMS gegen 'ref'
%      (unkorrigiert, die Familie ist je Frage zu waehlen)
%   D  je Gruppe ueber alle Szenarien: Anzahl Szenarien, in denen alle Agenten folgen, Median der Faktoren,
%      Summe nicht dominiert. Dazu nominal Median RMS und ori_max mit p gegen 'ref', und je Agent der mittlere
%      Delta-RMS und Delta-ori ueber die Szenarien in 'family' (ein Wert je Seed), Median und p gegen 'ref'
%      (Mann-Whitney-U zweiseitig, unkorrigiert)
%   CSV: data/simulation/extension/X2_robust_<stamp>_report_T.csv und _D.csv
%   Optionen: ctrl (alle Regler im Lauf), ref ('w2'), groups (alle ausser ctrl), family (Masse und Traegheit,
%   also der Bereich der Randomisierung DR-M)

p = inputParser;
p.addParameter('ctrl', {});
p.addParameter('ref', 'w2');
p.addParameter('groups', {});
p.addParameter('family', {'mass_0.25', 'mass_0.5', 'mass_0.75', 'mass_1.5', 'mass_2', 'inertia_0.5', 'inertia_2'});
p.parse(varargin{:});
o = p.Results;
setup_project;
f = sk_path('data', 'simulation', 'extension', ['X2_robust_' stamp '_summary.csv']);
S = readtable(f, 'TextType', 'string');
rl = S.group == "rl";
S.group(rl) = extractBefore(S.subject(rl), "_");
isC = S.group == "ctrl";
ctrl = string(o.ctrl);
if isempty(ctrl), ctrl = unique(S.subject(isC), 'stable'); end
groups = string(o.groups);
if isempty(groups), groups = unique(S.group(~isC), 'stable'); end
scen = unique(S.scenario, 'stable');

rows = {};
F = cell(numel(groups), 1);
for s = scen.'
    C = S(S.scenario == s & isC & ismember(S.subject, ctrl), :);
    C = C(C.follows_all == 1, :);
    refD = S.d_rms(S.scenario == s & S.group == o.ref);
    for g = 1:numel(groups)
        A = S(S.scenario == s & S.group == groups(g), :);
        fac = inf(height(A), 1);
        for k = 1:height(A)
            r = C.rms_ee(C.ori_max <= A.ori_max(k));
            if ~isempty(r), fac(k) = A.rms_ee(k) / min(r); end
        end
        F{g} = [F{g}; fac];
        pd = NaN;
        if groups(g) ~= o.ref && s ~= "nominal", pd = ranksum(A.d_rms, refD); end
        rows{end + 1} = struct('scenario', s, 'group', groups(g), 'n', height(A), ...
            'n_follows', sum(A.follows_all == 1), 'rms_med', median(A.rms_ee), 'ori_med', median(A.ori_max), ...
            'd_rms_med', median(A.d_rms), 'fac_med', median(fac), 'n_nondom', sum(isinf(fac) | fac < 1), ...
            'p_d_rms', pd); %#ok<AGROW>
    end
end
T = struct2table([rows{:}]);
% Je Agent: mittlerer Delta-RMS und Delta-ori ueber die Szenarien in 'family' (ein Wert je Seed)
fam = string(o.family);
P = S(ismember(S.scenario, fam) & ~isC, :);
[sub, ~, ix] = unique(P.subject, 'stable');
grpOf = accumarray(ix, (1:height(P)).', [], @(i) {P.group(i(1))});
perAgent = table(sub, string(grpOf), accumarray(ix, P.d_rms, [], @mean), accumarray(ix, P.d_ori, [], @mean), ...
                 'VariableNames', {'subject', 'group', 'd_rms_fam', 'd_ori_fam'});
nomS = S(S.scenario == "nominal" & ~isC, :);
D = table(groups(:), 'VariableNames', {'group'});
refA = perAgent(perAgent.group == o.ref, :);
refN = nomS(nomS.group == o.ref, :);
for g = 1:numel(groups)
    G = T(T.group == groups(g), :);
    D.n_scen(g) = height(G);
    D.scen_all_follow(g) = sum(G.n_follows == G.n);
    D.fac_med(g) = median(F{g}(~isinf(F{g})));
    D.n_nondom(g) = sum(G.n_nondom);
    N = nomS(nomS.group == groups(g), :);
    Ga = perAgent(perAgent.group == groups(g), :);
    D.nom_rms_med(g) = median(N.rms_ee);
    D.nom_ori_med(g) = median(N.ori_max);
    D.d_rms_fam_med(g) = median(Ga.d_rms_fam);
    D.d_ori_fam_med(g) = median(Ga.d_ori_fam);
    D.p_nom_rms(g) = NaN; D.p_nom_ori(g) = NaN; D.p_d_rms_fam(g) = NaN; D.p_d_ori_fam(g) = NaN;
    if groups(g) ~= o.ref
        D.p_nom_rms(g) = ranksum(N.rms_ee, refN.rms_ee);
        D.p_nom_ori(g) = ranksum(N.ori_max, refN.ori_max);
        D.p_d_rms_fam(g) = ranksum(Ga.d_rms_fam, refA.d_rms_fam);
        D.p_d_ori_fam(g) = ranksum(Ga.d_ori_fam, refA.d_ori_fam);
    end
end
fprintf('Regler: %s\n', strjoin(ctrl, ', '));
fprintf('Familie fuer d_*_fam: %s\n', strjoin(fam, ', '));
disp(T);
disp(D);
out = sk_path('data', 'simulation', 'extension', ['X2_robust_' stamp '_report']);
writetable(T, [out '_T.csv']);
writetable(D, [out '_D.csv']);
end
