function S = ext_stats(A, varargin)
%EXT_STATS  Statistik des Auswerteprotokolls X0.1 ueber Gruppen von Agenten (statistische Einheit: Seed).
%   S = ext_stats(A)                          nur beschreibend, je Gruppe
%   S = ext_stats(A, 'ref', "w2")             dazu Tests jeder Gruppe gegen die Gruppe w2
%   S = ext_stats(A, 'ref', "r1", 'theta', 0.03)
%
%   A ist die Agenten-Tabelle aus ext_eval_batch (eine Zeile je Agent). Optionen:
%     group     Name der Gruppenspalte (Standard 'group')
%     ref       Referenzgruppe fuer die Tests, leer = keine Tests
%     metrics   Kennzahlen (Standard rms_ee, ep_q4, ori_max, w_max, jerk_rms; Mittel je Agent ueber die Episoden)
%     theta     Budget der Basisdrehung [rad] fuer "haelt das Budget". Skalar oder leer. Hat A eine Spalte
%               theta, gilt sie je Agent (fuer die Budget-Reihe X1)
%     thetaTol  Toleranz (Standard 0,005 rad). Haelt das Budget: ori_max_worst <= theta + thetaTol
%     nBoot     Bootstrap-Ziehungen (Standard 2000), bootSeed fester Seed (Standard 1)
%
%   S.metrics  je Gruppe und Kennzahl: n, Mittel mit 95-%-Bootstrap-Intervall (Perzentil), Median, Quartile,
%              IQR mit Bootstrap-Intervall, p-Wert Mann-Whitney-U zweiseitig gegen ref, p nach Holm
%              (Familie: alle Gruppen gegen ref bei derselben Kennzahl)
%   S.props    je Gruppe: n, Anzahl "folgt der Bahn" und "haelt das Budget", Fisher exakt zweiseitig gegen ref,
%              p nach Holm (Familie: alle Gruppen gegen ref beim selben Anteil)
%   S.opts     die benutzten Optionen

p = inputParser;
p.addParameter('group', 'group');
p.addParameter('ref', "");
p.addParameter('metrics', {'rms_ee', 'ep_q4', 'ori_max', 'w_max', 'jerk_rms'});
p.addParameter('theta', []);
p.addParameter('thetaTol', 0.005);
p.addParameter('nBoot', 2000);
p.addParameter('bootSeed', 1);
p.parse(varargin{:});
o = p.Results;
ref = string(o.ref);

g = string(A.(o.group));
groups = unique(g, 'stable');
hasRef = strlength(ref) > 0;
if hasRef
    assert(any(groups == ref), 'ext_stats:ref', 'Referenzgruppe %s fehlt', ref);
end

% --- Budget je Agent ---
inBudget = nan(height(A), 1);
if ismember('theta', A.Properties.VariableNames)
    inBudget = double(A.ori_max_worst <= A.theta + o.thetaTol);
elseif ~isempty(o.theta)
    inBudget = double(A.ori_max_worst <= o.theta + o.thetaTol);
end

% --- Kennzahlen ---
rows = {};
for m = 1:numel(o.metrics)
    name = o.metrics{m};
    for k = 1:numel(groups)
        x = A.(name)(g == groups(k));
        x = x(isfinite(x));
        r = struct('group', groups(k), 'metric', string(name), 'n', numel(x), 'mean', mean(x), ...
                   'ci_lo', NaN, 'ci_hi', NaN, 'median', median(x), 'q1', NaN, 'q3', NaN, 'iqr', NaN, ...
                   'iqr_ci_lo', NaN, 'iqr_ci_hi', NaN, 'p_mwu', NaN, 'p_holm', NaN);
        if numel(x) >= 2
            q = quantile(x, [0.25 0.75]);
            r.q1 = q(1); r.q3 = q(2); r.iqr = q(2) - q(1);
            ci = boot(x, @mean, o);
            r.ci_lo = ci(1); r.ci_hi = ci(2);
            ci = boot(x, @iqr, o);
            r.iqr_ci_lo = ci(1); r.iqr_ci_hi = ci(2);
        end
        if hasRef && groups(k) ~= ref
            y = A.(name)(g == ref);
            y = y(isfinite(y));
            if numel(x) >= 1 && numel(y) >= 1
                r.p_mwu = ranksum(x, y);
            end
        end
        rows{end + 1} = r; %#ok<AGROW>
    end
end
M = struct2table([rows{:}], 'AsArray', true);
if hasRef
    for m = 1:numel(o.metrics)
        idx = M.metric == o.metrics{m} & M.group ~= ref;
        M.p_holm(idx) = holm(M.p_mwu(idx));
    end
end

% --- Anteile ---
rows = {};
for k = 1:numel(groups)
    sel = g == groups(k);
    r = struct('group', groups(k), 'n', sum(sel), 'n_follows', sum(A.follows(sel)), ...
               'n_budget', sum(inBudget(sel)), 'p_follows', NaN, 'p_follows_holm', NaN, ...
               'p_budget', NaN, 'p_budget_holm', NaN);
    if hasRef && groups(k) ~= ref
        sr = g == ref;
        r.p_follows = fisher(r.n_follows, r.n, sum(A.follows(sr)), sum(sr));
        if all(isfinite(inBudget(sel | sr)))
            r.p_budget = fisher(r.n_budget, r.n, sum(inBudget(sr)), sum(sr));
        end
    end
    rows{end + 1} = r; %#ok<AGROW>
end
P = struct2table([rows{:}], 'AsArray', true);
if hasRef
    idx = P.group ~= ref;
    P.p_follows_holm(idx) = holm(P.p_follows(idx));
    P.p_budget_holm(idx) = holm(P.p_budget(idx));
end

S = struct('metrics', M, 'props', P, 'opts', o);
end

% =====================================================================
function ci = boot(x, fun, o)
% 95-%-Perzentil-Intervall mit eigenem Zufallsstrom (reproduzierbar, unabhaengig vom globalen rng)
s = RandStream('mt19937ar', 'Seed', o.bootSeed);
ci = bootci(o.nBoot, {fun, x}, 'Type', 'per', 'Options', statset('Streams', s));
end

function p = fisher(a, na, b, nb)
% Fisher exakt zweiseitig fuer zwei Anteile a/na und b/nb
[~, p] = fishertest([a, na - a; b, nb - b]);
end

function q = holm(p)
% Holm-Bonferroni, NaN bleiben NaN
q = nan(size(p));
ok = find(isfinite(p));
if isempty(ok), return; end
[ps, order] = sort(p(ok));
m = numel(ps);
adj = min(1, cummax((m - (1:m)' + 1) .* ps(:)));
q(ok(order)) = adj;
end
