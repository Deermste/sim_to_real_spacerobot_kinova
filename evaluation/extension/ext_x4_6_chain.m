function C = ext_x4_6_chain(varargin)
%EXT_X4_6_CHAIN  Welcher Teil der Befehlskette kostet den Regler Bahnfehler? (Ausbau X4.6, Nachtrag)
%   C = ext_x4_6_chain()
%   C = ext_x4_6_chain('filts', [0.95 0.85 0.5 0], 'ori', [0.01 0.02 0.03 0.06])
%
%   ext_x2_sweep mit den Einstellungen aus X2.1 (Kp 5 und 10, J6-Seite 0/-1/+1, beta 0 bis 1e4 und Vorrang,
%   kOri 0, J6 0,9774), nicht gespeichert:
%     full_inv mit Filterkoeffizient filt_a (0 heisst ohne Filter, Rate Limiter bleibt)
%     sat      ohne Filter und ohne Rate Limiter (ideale Kette aus X2.1)
%   Je Kette der kleinste RMS unter den folgenden Laeufen (kein Abbruch, ep_q4 < 5 cm) mit ori_max <= Schwelle.
%   CSV: data/simulation/extension/X4_6_chain_<Zeit>.csv

p = inputParser;
p.addParameter('filts', [0.95 0.85 0.5 0]);
p.addParameter('ori', [0.01 0.02 0.03 0.06]);
p.parse(varargin{:});
o = p.Results;
setup_project;
rows = {};
for fa = [o.filts NaN]
    if isnan(fa)
        T = ext_x2_sweep('variants', {'sat'}, 'j6', 0.9774, 'save', false);
        chain = "sat";
    else
        T = ext_x2_sweep('filt_a', fa, 'variants', {'full_inv'}, 'j6', 0.9774, 'save', false);
        chain = "full_inv";
    end
    ok = T.early_stop == 0 & T.ep_q4 < 0.05;
    for q = o.ori
        c = T.rms_ee(ok & T.ori_max <= q);
        r = NaN;
        if ~isempty(c), r = min(c); end
        rows{end + 1} = struct('chain', chain, 'filt_a', fa, 'ori_le', q, 'rms_min', r, 'n_runs', height(T), ...
                               'n_ok', sum(ok)); %#ok<AGROW>
    end
end
C = struct2table([rows{:}]);
disp(C);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
writetable(C, sk_path('data', 'simulation', 'extension', ['X4_6_chain_' stamp '.csv']));
end
