function [T, F] = ext_x2_4_tune_ctrl(varargin)
%EXT_X2_4_TUNE_CTRL  Regler auf die Trainingsverteilung von DR-voll einstellen (Ausbau X2.4, fairer Vergleich).
%   [T, F] = ext_x2_4_tune_ctrl()
%   [T, F] = ext_x2_4_tune_ctrl('nDraws', 10, 'workers', 0)     kleiner Lauf ohne Pool
%
%   Die randomisierten Agenten (ext_x2_4_train 'full') sehen im Training Basismasse x[0,25; 2], Traegheit
%   x[0,5; 2], Verzoegerung 0-2 Schritte, Verstaerkung [0,9; 1,1], Messrauschen 0-2-fach und Startstellung +-2 Grad.
%   Damit der Vergleich fair ist, darf der Regler auf dieselbe Verteilung eingestellt werden: Gitter ueber beta,
%   kOri, Kp und J6-Seite, jeder Regler auf nDraws Ziehungen aus dieser Verteilung (feste Ziehungen fuer alle
%   Regler, ext_kinsim mit voller Kette, Regler mit Nominalmodell und Inversion der Kette). Kennzahlen je Regler:
%   Anteil gefolgt, Median, 90-%-Quantil und groesster Wert von RMS und Basisdrehung.
%   F: Regler, die in allen Ziehungen folgen und im 90-%-Quantil (RMS, Basisdrehung) nicht dominiert sind.
%   Daraus drei Vertreter (Anfang, Mitte, Ende der Front) fuer ext_x2_robust:
%   data/simulation/extension/X2_4_ctrl_tuned.mat.
%   Ergebnis: X2_4_tune_ctrl_<Zeit>.csv

p = inputParser;
p.addParameter('nDraws', 40);
p.addParameter('betas', [0 1 4.6416 21.544 46.416 100 215.44]);
p.addParameter('kOri', [0 0.5 1 2]);
p.addParameter('Kp', [5 10]);
p.addParameter('sides', [0 -1]);
p.addParameter('workers', 4);
p.addParameter('save', true);
p.parse(varargin{:});
o = p.Results;
setup_project;

% --- feste Ziehungen wie drReset in ext_x2_4_train ('full') ---
rs = RandStream('mt19937ar', 'Seed', 20261110);
lu = @(r) exp(log(r(1)) + rand(rs) * (log(r(2)) - log(r(1))));
D = struct('mass', {}, 'inertia', {}, 'delay', {}, 'gain', {}, 'noise', {}, 'q0', {});
for k = 1:o.nDraws
    q0 = zeros(7, 1);
    m = lu([0.25 2]); fi = lu([0.5 2]);
    dl = floor(rand(rs) * 3); g = 0.9 + 0.2 * rand(rs); ns = 2 * rand(rs);
    q0([2 4 6]) = deg2rad(2) * (2 * rand(rs, 3, 1) - 1);
    D(k) = struct('mass', 65 * m, 'inertia', fi, 'delay', dl, 'gain', g, 'noise', ns, 'q0', q0);
end

% --- Regler-Gitter ---
G = {};
for b = o.betas
    for ko = o.kOri
        for kp = o.Kp
            for sd = o.sides
                if b == 0 && (ko > 0 || sd ~= 0), continue; end    % R0 haengt nicht von kOri und Seite ab
                G(end + 1, :) = {b, ko, kp, sd}; %#ok<AGROW>
            end
        end
    end
end
nC = size(G, 1);
fprintf('%d Regler x %d Ziehungen\n', nC, o.nDraws);

Knom = ext_kin_model();
Ks = cell(1, o.nDraws);
for k = 1:o.nDraws
    Ks{k} = ext_kin_model('base_mass', D(k).mass, 'base_inertia', 10.833 * D(k).mass / 65 * D(k).inertia);
end
tAll = tic;
rms = nan(nC, o.nDraws); ori = rms; fol = rms;
if o.workers > 0
    pool = gcp('nocreate');
    if isempty(pool), pool = parpool('Processes', o.workers); end
    root = sk_path();
    f = parfevalOnAll(pool, @workerSetup, 0, root);
    fetchOutputs(f);
    parfor c = 1:nC
        [rms(c, :), ori(c, :), fol(c, :)] = runCtrl(G(c, :), D, Ks, Knom);
    end
else
    for c = 1:nC
        [rms(c, :), ori(c, :), fol(c, :)] = runCtrl(G(c, :), D, Ks, Knom);
    end
end
fprintf('fertig nach %.1f min\n', toc(tAll) / 60);

T = table(cell2mat(G(:, 1)), cell2mat(G(:, 2)), cell2mat(G(:, 3)), cell2mat(G(:, 4)), mean(fol, 2), ...
    median(rms, 2), prctile(rms, 90, 2), max(rms, [], 2), median(ori, 2), prctile(ori, 90, 2), max(ori, [], 2), ...
    'VariableNames', {'beta', 'kOri', 'Kp', 'j6_side', 'frac_follows', 'rms_med', 'rms_p90', 'rms_max', ...
    'ori_med', 'ori_p90', 'ori_max'});
T.front = false(nC, 1);
ok = find(T.frac_follows == 1);
for i = ok.'
    dom = T.rms_p90(ok) <= T.rms_p90(i) & T.ori_p90(ok) <= T.ori_p90(i) & ...
          (T.rms_p90(ok) < T.rms_p90(i) | T.ori_p90(ok) < T.ori_p90(i));
    T.front(i) = ~any(dom);
end
F = sortrows(T(T.front, :), 'ori_p90', 'descend');
disp(F);

% --- drei Vertreter: Anfang und Ende der Front, dazu der Punkt mit der Basisdrehung am naechsten am
%     geometrischen Mittel der beiden ---
tuned = cell(0, 2);
if ~isempty(F)
    names = {'Rt_acc', 'Rt_mid', 'Rt_calm'};
    iAcc = 1;
    iCalm = height(F);
    [~, iMid] = min(abs(F.ori_p90 - (F.ori_p90(iAcc) * F.ori_p90(iCalm)) ^ 0.5));
    pick = unique([iAcc, iMid, iCalm], 'stable');
    for k = 1:numel(pick)
        r = F(pick(k), :);
        tuned(end + 1, :) = {names{min(k, 3)}, {'beta', r.beta, 'kOri', r.kOri, 'Kp', r.Kp, ...
                             'j6_side', r.j6_side}}; %#ok<AGROW>
    end
end
if o.save
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    writetable(T, sk_path('data', 'simulation', 'extension', ['X2_4_tune_ctrl_' stamp '.csv']));
    save(sk_path('data', 'simulation', 'extension', 'X2_4_ctrl_tuned.mat'), 'tuned', 'F', 'D', 'stamp');
    fprintf('Vertreter: %s\n', strjoin(tuned(:, 1).', ', '));
end
end

% =====================================================================
function [r, w, f] = runCtrl(g, D, Ks, Knom)
nD = numel(D);
r = nan(1, nD); w = r; f = r;
for k = 1:nD
    K = Ks{k};
    ctrl = ext_x2_controller('j6_lim', 0.9774, 'invert', true, 'K', Knom, 'beta', g{1}, 'kOri', g{2}, ...
                             'Kp', g{3}, 'j6_side', g{4});
    res = ext_kinsim([], 'ctrl', ctrl, 'j6_lim', 0.9774, 'K', K, 'delay_steps', D(k).delay, ...
                     'cmd_scale', D(k).gain, 'obsNoise', D(k).noise * noiseSigma(), 'rngSeed', k, ...
                     'q0', D(k).q0, 'keepTs', false);
    m = res.metrics;
    r(k) = m.rms_ee; w(k) = m.ori_max; f(k) = double(~m.early_stop && m.ep_q4 < 0.05);
end
end

function s = noiseSigma()
s = [1e-3 * ones(3, 1); 5e-3 * ones(3, 1); 1e-3 * ones(3, 1); 1e-3 * ones(3, 1); 1e-3 * ones(7, 1); ...
     5e-3 * ones(7, 1); 1e-3 * ones(3, 1)];
end

function workerSetup(root)
addpath(root);
setup_project;
end
