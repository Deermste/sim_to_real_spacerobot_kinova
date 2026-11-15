function T = ext_x7_sweep(variants, seeds, varargin)
%EXT_X7_SWEEP  Varianten von X7 auf dem Entwicklungssatz vergleichen (15.11.2026).
%   T = ext_x7_sweep(variants, seeds)
%   variants: struct-Array mit name, variant ('res' oder 'resdr') und args (Zellarray fuer ext_x7_train)
%   Je Variante und Seed ein Training (3000 Episoden), dann ext_x7_dev mit dem letzten Agenten und dem besten
%   Zwischenstand (kleinstes J in der nominalen Episode des Trainings). Die Testszenarien bleiben unberuehrt.
%   Ergebnis: data/simulation/extension/X7_sweep_<label>_<Zeit>.csv (eine Zeile je Agent, dazu R)

p = inputParser;
p.addParameter('label', 'a');
p.addParameter('nEpisodes', 3000);
p.parse(varargin{:});
o = p.Results;
setup_project;
list = struct('file', {}, 'label', {}, 'eps_v', {}, 'eps_w', {});
meta = {};
for v = 1:numel(variants)
    for s = seeds
        a = variants(v).args;
        out = ext_x7_train(variants(v).variant, s, 'nEpisodes', o.nEpisodes, 'name', ...
                           sprintf('X7_%s_%s_seed%d', o.label, variants(v).name, s), a{:});
        ev = out.cfg.eps_v; ew = out.cfg.eps_w;
        list(end + 1) = struct('file', out.agentFile, 'label', sprintf('%s_s%d_final', variants(v).name, s), ...
                               'eps_v', ev, 'eps_w', ew); %#ok<AGROW>
        meta(end + 1, :) = {variants(v).name, s, "final", 3000}; %#ok<AGROW>
        ck = out.ckpt;
        J = ck.nom_rms_ee / 0.00899 + ck.nom_ori_max / 0.01298 + 100 * ck.nom_stop;
        [~, ib] = min(J);
        list(end + 1) = struct('file', char(ck.file(ib)), 'label', sprintf('%s_s%d_best', variants(v).name, s), ...
                               'eps_v', ev, 'eps_w', ew); %#ok<AGROW>
        meta(end + 1, :) = {variants(v).name, s, "best", ck.episodes(ib)}; %#ok<AGROW>
    end
end
T = ext_x7_dev(list);
T.J = T.rms_ee / 0.00899 + T.ori_max / 0.01298;
T.J_R = repmat(T.J(1), height(T), 1);
T.variant = ["R"; string(meta(:, 1))];
T.seed = [NaN; cell2mat(meta(:, 2))];
T.stage = ["-"; string(meta(:, 3))];
T.ckpt_ep = [NaN; cell2mat(meta(:, 4))];
T.file = [""; string({list.file}.')];
disp(T(:, {'subject', 'follows', 'rms_ee', 'ori_max', 'J', 'better_rms', 'better_ori'}));
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
f = sk_path('data', 'simulation', 'extension', sprintf('X7_sweep_%s_%s.csv', o.label, stamp));
writetable(T, f);
fprintf('Ergebnis: %s\n', f);
end
