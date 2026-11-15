function [S, E, outFile] = ext_x7sp_eval(list, varargin)
%EXT_X7SP_EVAL  Schlussauswertung X7-SP (15.11.2026): Regler allein gegen Regler plus Korrektur, 26 Szenarien.
%   [S, E] = ext_x7sp_eval(list)          list: struct mit file, label, group, beta, eps_v, eps_w
%   [S, E] = ext_x7sp_eval(list, 'nPairs', 100, 'betas', [0 1], 'scenarios', {'nominal'})
%
%   Paare: die ersten nPairs des Auswertesatzes (X6_pairs, set "eval", fest, vor der Auswertung gewaehlt).
%   Teilnehmer: Regler allein mit jedem beta aus 'betas' (R<beta>) und jeder Residual-Agent.
%   Szenarien wie ext_x2_robust (X2.3), auf den Set-Point uebertragen: Modell (Basismasse und -traegheit x0,25 /
%   0,5 / 0,75 / 1,5 / 2, nur Traegheit x0,5 / 2, Gliedmassen x0,8 / 1,2, Montage +-5 cm in x, +5 cm in z),
%   Aktor (Verzoegerung 1 und 2 Schritte = 50 / 100 ms, Verstaerkung x0,9 / 1,1, Servo tau 0,05 s), Sensor
%   (Rauschen 1- und 3-fach, Seed je Paar, fester Lagefehler 10 mrad um y, fester Positionsfehler 5 mm in x),
%   Anfang (Startstellung +-2 Grad auf allen sieben Gelenken, Ziehung je Paar, Drift 2 mrad/s um +y, -y, x).
%   Kennzahlen je Lauf wie ext_x6_ctrl_eval: success, t_settle, err_end, ori_max. Zusammenfassung je Szenario und
%   Teilnehmer: Erfolgsquote, Median t_settle (Fehlschlag 15 s), Median ori_max, J_sp.
%   J_sp je Lauf = ori_max / ori_R + t / t_R (t = t_settle, Fehlschlag 15 s), Bezug R mit beta 0 nominal
%   (Median ueber die Paare).
%   Ergebnis: data/simulation/extension/X7sp_<label>_{episodes,summary}_<Zeit>.csv

p = inputParser;
p.addParameter('nPairs', 100);
p.addParameter('betas', [0 1 4.6416 21.544]);
p.addParameter('scenarios', {});
p.addParameter('label', 'eval');
p.parse(varargin{:});
o = p.Results;
setup_project;
[~, Knom] = ext_x7sp_setup();
dd = sk_path('data', 'simulation', 'extension');
dE = dir(fullfile(dd, 'X6_pairs_*.mat'));
Le = load(fullfile(dE(end).folder, dE(end).name), 'P');
Pev = Le.P([Le.P.set] == "eval");
Pev = Pev(1:min(o.nPairs, numel(Pev)));
subj = struct('label', {}, 'group', {}, 'pol', {}, 'beta', {}, 'eps_v', {}, 'eps_w', {});
for b = o.betas
    subj(end + 1) = struct('label', sprintf('R%g', b), 'group', 'ctrl', 'pol', [], 'beta', b, 'eps_v', 0, ...
                           'eps_w', 0); %#ok<AGROW>
end
for k = 1:numel(list)
    subj(end + 1) = struct('label', list(k).label, 'group', list(k).group, 'pol', ext_policy(list(k).file), ...
                           'beta', list(k).beta, 'eps_v', list(k).eps_v, 'eps_w', list(k).eps_w); %#ok<AGROW>
end
sc = scenarios();
if ~isempty(o.scenarios), sc = sc(ismember({sc.name}, o.scenarios)); end
Q0p = ext_x0_perturbations(numel(Pev), 2, 1:7);
sig = ext_x7sp_setup('noise');
rows = {};
t0 = tic;
for s = 1:numel(sc)
    out = cell(numel(Pev), 1);
    scs = sc(s);
    parfor i = 1:numel(Pev)
        pr = Pev(i);
        K = Knom;
        if ~isempty(scs.plant), K = ext_kin_model('tool_offset', [0; 0; 0.121], scs.plant{:}); end
        extra = [{'K', K}, scs.sim];
        if scs.noise > 0, extra = [extra, {'obsNoise', scs.noise * sig, 'rngSeed', pr.id}]; end
        if scs.pose, pr.q0 = pr.q0(:) + Q0p(i + 1, :).'; end
        rr = [];
        for j = 1:numel(subj)
            Tm = min(max(1.5, 9.4 * pr.d0), 10);
            pol = subj(j).pol;
            if isempty(pol), pol = @(ob) zeros(6, 1); end
            c = ext_x7sp_ctrl(pol, pr.pT, Tm, 'beta', subj(j).beta, 'eps_v', subj(j).eps_v, 'eps_w', subj(j).eps_w);
            r = ext_x7sp_run(c, pr, extra{:});
            r.subject = string(subj(j).label); r.group = string(subj(j).group);
            r.scenario = string(scs.name); r.sgroup = string(scs.group);
            rr = [rr; r]; %#ok<AGROW>
        end
        out{i} = rr;
    end
    rows = [rows; out]; %#ok<AGROW>
    fprintf('%-16s fertig (%.1f min)\n', sc(s).name, toc(t0) / 60);
end
E = struct2table(vertcat(rows{:}));
E.t_eff = E.t_settle; E.t_eff(isnan(E.t_eff)) = 15;
N = E(E.scenario == "nominal" & E.subject == "R0", :);
if isempty(N), N = E(E.scenario == "nominal" & E.group == "ctrl", :); end
oriR = median(N.ori_max); tR = median(N.t_eff);
E.J = E.ori_max / oriR + E.t_eff / tR;
[g, sN, sG, sub, grp] = findgroups(E.scenario, E.sgroup, E.subject, E.group);
S = table(sN, sG, sub, grp, splitapply(@mean, E.success, g), splitapply(@median, E.t_eff, g), ...
    splitapply(@median, E.ori_max, g), splitapply(@median, E.J, g), splitapply(@mean, E.J, g), ...
    'VariableNames', {'scenario', 'sgroup', 'subject', 'group', 'success', 't_settle_med', 'ori_max_med', ...
                      'J_med', 'J_mean'});
S.oriR = repmat(oriR, height(S), 1); S.tR = repmat(tR, height(S), 1);
fprintf('%d Laeufe in %.1f min, Bezug ori_R %.1f mrad, t_R %.2f s\n', height(E), toc(t0) / 60, 1000 * oriR, tR);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outFile = fullfile(dd, sprintf('X7sp_%s_%s', o.label, stamp));
writetable(E, [outFile '_episodes.csv']);
writetable(S, [outFile '_summary.csv']);
fprintf('Ergebnis: %s_*.csv\n', outFile);
end

% =====================================================================
function sc = scenarios()
sc = struct('name', {}, 'group', {}, 'plant', {}, 'sim', {}, 'noise', {}, 'pose', {});
add('nominal', 'nominal', {}, {});
for f = [0.25 0.5 0.75 1.5 2]
    add(sprintf('mass_%g', f), 'model', {'base_mass', 65 * f}, {});
end
for f = [0.5 2]
    add(sprintf('inertia_%g', f), 'model', {'base_inertia', 10.833 * f}, {});
end
for f = [0.8 1.2]
    add(sprintf('links_%g', f), 'model', {'link_mass_scale', f}, {});
end
add('mount_x+5cm', 'model', {'mount_offset', [0.05 0 0]}, {});
add('mount_x-5cm', 'model', {'mount_offset', [-0.05 0 0]}, {});
add('mount_z+5cm', 'model', {'mount_offset', [0 0 0.05]}, {});
add('delay_50ms', 'actuator', {}, {'delay_steps', 1});
add('delay_100ms', 'actuator', {}, {'delay_steps', 2});
add('gain_0.9', 'actuator', {}, {'cmd_scale', 0.9});
add('gain_1.1', 'actuator', {}, {'cmd_scale', 1.1});
add('servo_tau50ms', 'actuator', {}, {'tau', 0.05});
add('noise_1x', 'sensor', {}, {}, 1, false);
add('noise_3x', 'sensor', {}, {}, 3, false);
b = zeros(29, 1); b(28) = 0.01;
add('bias_ori_10mrad', 'sensor', {}, {'obsBias', b});
b = zeros(29, 1); b(1) = 0.005;
add('bias_ee_5mm', 'sensor', {}, {'obsBias', b});
add('pose_2deg', 'initial', {}, {}, 0, true);
add('drift_y+2mrad', 'initial', {}, {'w0_init', [0; 0.002; 0]});
add('drift_y-2mrad', 'initial', {}, {'w0_init', [0; -0.002; 0]});
add('drift_x2mrad', 'initial', {}, {'w0_init', [0.002; 0; 0]});

    function add(name, group, plant, sim, noise, pose)
        if nargin < 5, noise = 0; end
        if nargin < 6, pose = false; end
        sc(end + 1) = struct('name', name, 'group', group, 'plant', {plant}, 'sim', {sim}, 'noise', noise, ...
                             'pose', pose);
    end
end
