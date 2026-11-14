function S = ext_x5_3_summary(varargin)
%EXT_X5_3_SUMMARY  Zusammenfassung X5.3: r4 und x1 auf der 3D-Bahn (tilted -30, alle sieben Gelenke), je 10 Seeds.
%   S = ext_x5_3_summary()
%
%   Daten (kein neues Rechnen): r4 Seeds 0, 1 aus X5.2b, Seeds 2 bis 9 aus X5.3 Schritt 3. x1 Seeds 0, 1 aus dem
%   X1-Piloten (X5.2c), Seeds 2 bis 9 aus X5.3 Schritt 4. Front des Reglers aus X5.3 Schritt 1 (nominal, volle
%   Kette mit Inversion, nur folgende Laeufe).
%   Je Variante und Stufe (letzter Agent, bester Zwischenstand): Anzahl folgend, Median und Spanne von RMS (Mittel
%   ueber die 21 Episoden), ep_q4 und ori_max (schlechteste der 21 Episoden), dazu die nominale Lesart.
%   Je folgendem Agenten nominal: kleinster RMS der Front bei hoechstens derselben Basisdrehung (Abstand zur
%   Front als Faktor) und kleinste Basisdrehung der Front bei hoechstens demselben RMS.
%   Ergebnis: data/simulation/extension/X5_3_summary_<Zeit>.csv (eine Zeile je Agent)

p = inputParser;
p.addParameter('save', true);
p.parse(varargin{:});
setup_project;
dd = sk_path('data', 'simulation', 'extension');
src = {
    'r4', 'X5_2b_agents_20261114_143532.csv'
    'r4', 'X5_23_r4_agents_20261114_194452.csv'
    'x1', 'X5_2c_agents_20261114_155811.csv'
    'x1', 'X5_23_x1_agents_20261114_231248.csv'
    };
A = table();
for i = 1:size(src, 1)
    T = readtable(fullfile(dd, src{i, 2}), 'TextType', 'string');
    T.variant = repmat(string(src{i, 1}), height(T), 1);
    T.source = repmat(string(src{i, 2}), height(T), 1);
    A = [A; T(:, {'agent', 'file', 'variant', 'seed', 'source', 'follows', 'rms_ee', 'ep_q4_worst', ...
                  'ori_max', 'ori_max_worst', 'jerk_rms', 'nom_rms_ee', 'nom_ori_max', 'n_stop'})]; %#ok<AGROW>
end
A.stage = repmat("final", height(A), 1);
A.stage(startsWith(A.agent, "ep")) = "best_ckpt";
A.ckpt_ep = NaN(height(A), 1);
isC = A.stage == "best_ckpt";
A.ckpt_ep(isC) = double(extractAfter(A.agent(isC), "ep"));
F = readtable(fullfile(dd, 'X5_3_front_20261114_150547.csv'), 'TextType', 'string');
F = F(F.front & F.chain == "full" & F.follows == 1, :);
F = sortrows(F, 'ori_max');
% Abstand zur Front, nominal
A.front_rms_at_ori = NaN(height(A), 1);
A.front_ori_at_rms = NaN(height(A), 1);
for i = 1:height(A)
    k = F.ori_max <= A.nom_ori_max(i);
    if any(k), A.front_rms_at_ori(i) = min(F.rms_ee(k)); end
    k = F.rms_ee <= A.nom_rms_ee(i);
    if any(k), A.front_ori_at_rms(i) = min(F.ori_max(k)); end
end
A = sortrows(A, {'variant', 'stage', 'seed'});
fprintf('Front: %d Punkte, %.1f mm / %.1f mrad bis %.1f mm / %.1f mrad\n', height(F), 1000 * F.rms_ee(end), ...
        1000 * F.ori_max(end), 1000 * F.rms_ee(1), 1000 * F.ori_max(1));
for v = ["r4", "x1"]
    for st = ["final", "best_ckpt"]
        B = A(A.variant == v & A.stage == st, :);
        fo = B.follows == 1;
        fprintf('\n%s %s: %d von %d folgen (Seeds ohne: %s)\n', v, st, sum(fo), height(B), ...
                strjoin(string(B.seed(~fo)).', ', '));
        fprintf('  alle:    RMS Median %.1f mm (%.1f bis %.1f), ep_q4 schl. Median %.1f mm, ori schl. Median %.1f mrad (%.1f bis %.1f)\n', ...
                1000 * median(B.rms_ee), 1000 * min(B.rms_ee), 1000 * max(B.rms_ee), 1000 * median(B.ep_q4_worst), ...
                1000 * median(B.ori_max_worst), 1000 * min(B.ori_max_worst), 1000 * max(B.ori_max_worst));
        if any(fo)
            C = B(fo, :);
            fprintf('  folgend: RMS Median %.1f mm (%.1f bis %.1f), ori Mittel Median %.1f mrad, ori schl. Median %.1f mrad (%.1f bis %.1f), Ruck Median %.1f\n', ...
                    1000 * median(C.rms_ee), 1000 * min(C.rms_ee), 1000 * max(C.rms_ee), 1000 * median(C.ori_max), ...
                    1000 * median(C.ori_max_worst), 1000 * min(C.ori_max_worst), 1000 * max(C.ori_max_worst), ...
                    median(C.jerk_rms));
            fprintf('  nominal folgend: RMS Median %.1f mm, ori Median %.1f mrad, Front bei gleicher Drehung Median %.1f mm (Faktor %.1f), Front bei gleichem RMS Median %.1f mrad\n', ...
                    1000 * median(C.nom_rms_ee), 1000 * median(C.nom_ori_max), 1000 * median(C.front_rms_at_ori), ...
                    median(C.nom_rms_ee ./ C.front_rms_at_ori), 1000 * median(C.front_ori_at_rms, 'omitnan'));
        end
        if st == "best_ckpt"
            fprintf('  Episoden der besten Zwischenstaende: %s\n', strjoin(string(B.ckpt_ep).', ', '));
        end
    end
end
% Paarweise je Seed (bester Zwischenstand), r4 gegen x1
R = A(A.variant == "r4" & A.stage == "best_ckpt", :);
X = A(A.variant == "x1" & A.stage == "best_ckpt", :);
[~, ir, ix] = intersect(R.seed, X.seed);
both = R.follows(ir) == 1 & X.follows(ix) == 1;
d = X.ori_max_worst(ix(both)) - R.ori_max_worst(ir(both));
fprintf('\nBester Zwischenstand, Seeds mit beiden folgend: %d. x1 minus r4 ori schl.: Median %+.1f mrad, x1 kleiner in %d\n', ...
        sum(both), 1000 * median(d), sum(d < 0));
dr = X.rms_ee(ix(both)) - R.rms_ee(ir(both));
fprintf('  x1 minus r4 RMS: Median %+.1f mm, x1 kleiner in %d\n', 1000 * median(dr), sum(dr < 0));
S = struct('A', A, 'F', F);
if p.Results.save
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    out = fullfile(dd, ['X5_3_summary_' stamp '.csv']);
    writetable(A, out);
    fprintf('Ergebnis: %s\n', out);
end
end
