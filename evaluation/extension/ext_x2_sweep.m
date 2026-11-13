function T = ext_x2_sweep(varargin)
%EXT_X2_SWEEP  Modellbasierte Front Bahnfehler gegen Basisdrehung im kinematischen Simulator (Ausbau X2.1, X2.2).
%   T = ext_x2_sweep()
%   T = ext_x2_sweep('betas', [0 1 10], 'Kp', 5, 'j6', 0.9774, 'variants', {'sat'})   kleiner Lauf
%
%   Regler ext_x2_controller, Strecke ext_kinsim (nominal, 65 kg, Halbkreis 8,5 s, 40 Hz).
%   Varianten der Befehlskette:
%     'sat'       nur Saettigung (ext_kinsim chain 'sat'), idealer Regler
%     'full_inv'  volle Befehlskette wie bei den Agenten, der Regler invertiert sie (invert true)
%     'full'      volle Befehlskette ohne Inversion (nur R0, zeigt, was die Kette ohne Modell kostet)
%   Je Variante, J6-Grenze, Kp und Seite von J6 (j6_side 0, -1, +1): R0 (beta 0), die gewichtete Reihe
%   (betas) und der Vorrang-Modus. Die volle Kette ohne Inversion nur mit R0 und j6_side 0.
%   Pareto-Markierung je Variante, J6-Grenze: kein anderer Punkt mit kleinerem RMS und kleinerer Basisdrehung.
%   Optionen: betas [0 logspace(-1, 4, 16)], Kp [5 10], j6 [0.1 0.9774], variants {'sat', 'full_inv', 'full'},
%   sides [0 -1 1], kOri 0 (Rueckfuehrung der Basislage, Liste moeglich), save true, filt_a 0,95 (Befehlsfilter
%   fuer Strecke und Regler, X4.6 V3: 0,85), slew 0,5 (Rate Limiter fuer Strecke und Regler, X4.6 V4: 2).
%   Ergebnis: data/simulation/extension/X2_sweep_<Zeit>.csv

p = inputParser;
p.addParameter('betas', [0 logspace(-1, 4, 16)]);
p.addParameter('Kp', [5 10]);
p.addParameter('j6', [0.1 0.9774]);
p.addParameter('variants', {'sat', 'full_inv', 'full'});
p.addParameter('sides', [0 -1 1]);
p.addParameter('kOri', 0);
p.addParameter('save', true);
p.addParameter('filt_a', 0.95);
p.addParameter('slew', 0.5);
p.parse(varargin{:});
o = p.Results;
setup_project;
K = ext_kin_model();

rows = {};
tAll = tic;
for v = o.variants
    chain = 'full'; inv = strcmp(v{1}, 'full_inv');
    if strcmp(v{1}, 'sat'), chain = 'sat'; end
    for j6 = o.j6
        for kp = o.Kp
            sides = o.sides;
            if strcmp(v{1}, 'full'), sides = 0; end
            for side = sides
                for ko = o.kOri
                    ctl = [num2cell(o.betas(:)), repmat({'weighted'}, numel(o.betas), 1)];
                    ctl(end + 1, :) = {NaN, 'priority'}; %#ok<AGROW>
                    if strcmp(v{1}, 'full'), ctl = {0, 'weighted'}; end
                    for c = 1:size(ctl, 1)
                        beta = ctl{c, 1}; mode = ctl{c, 2};
                        args = {'j6_lim', j6, 'Kp', kp, 'invert', inv, 'mode', mode, 'K', K, 'j6_side', side, ...
                                'kOri', ko, 'filt_a', o.filt_a, 'slew', o.slew};
                        if strcmp(mode, 'weighted'), args = [args, {'beta', beta}]; end %#ok<AGROW>
                        ctrl = ext_x2_controller(args{:});
                        r = ext_kinsim([], 'ctrl', ctrl, 'j6_lim', j6, 'chain', chain, 'K', K, ...
                                       'filt_a', o.filt_a, 'slew', o.slew);
                        m = r.metrics;
                        jt = r.ts.a_scaled(:, [2 4 6]);
                        jerk = sqrt(mean(sum((diff(jt, 2) / 0.025^2) .^ 2, 2)));
                        rows{end + 1} = struct('variant', string(v{1}), 'j6_lim', j6, 'Kp', kp, 'j6_side', side, ...
                            'kOri', ko, ...
                            'mode', string(mode), 'beta', beta, 'rms_ee', m.rms_ee, 'ep_q4', m.ep_q4, ...
                            'max_ee', m.max_ee, 'ori_max', m.ori_max, 'w_max', m.w_max, 'jerk_rms', jerk, ...
                            'q6_min', min(r.ts.q(:, 6)), 'q6_max', max(r.ts.q(:, 6)), ...
                            'early_stop', double(m.early_stop)); %#ok<AGROW>
                    end
                end
            end
        end
    end
end
T = struct2table([rows{:}]);
T.pareto = false(height(T), 1);
[g, ~] = findgroups(T.variant, T.j6_lim);
for k = unique(g).'
    ix = find(g == k & ~T.early_stop);
    for i = ix.'
        dom = T.rms_ee(ix) <= T.rms_ee(i) & T.ori_max(ix) <= T.ori_max(i) & ...
              (T.rms_ee(ix) < T.rms_ee(i) | T.ori_max(ix) < T.ori_max(i));
        T.pareto(i) = ~any(dom);
    end
end
fprintf('%d Laeufe in %.1f min\n', height(T), toc(tAll) / 60);
if o.save
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    out = sk_path('data', 'simulation', 'extension', ['X2_sweep_' stamp '.csv']);
    writetable(T, out);
    fprintf('Ergebnis: %s\n', out);
end
end
