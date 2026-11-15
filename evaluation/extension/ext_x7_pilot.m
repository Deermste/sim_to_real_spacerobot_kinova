function ext_x7_pilot()
%EXT_X7_PILOT  Pilot X7 (15.11.2026): Res und Res-DR je Seed 0, 3000 Episoden, dann Auswertung.
%   ext_x7_pilot()
%
%   Training ext_x7_train (Korrektur der Sollwerte von Rbeta 21,5, eps_v 0,02 m/s, eps_w 0,01 rad/s, w_res 0,1).
%   Auswertung ext_x7_eval mit dem letzten Agenten je Lauf: X0.1 (21 Startstellungen) und 26 Szenarien gegen R.
%   Go-Regel fuer den Hauptlauf (vor dem Lauf festgelegt): beide Agenten folgen in allen 21 Episoden, und der
%   nominale RMS liegt hoechstens 10 % ueber R.

setup_project;
t0 = tic;
list = struct('file', {}, 'label', {}, 'group', {}, 'eps_v', {}, 'eps_w', {});
for v = {'res', 'resdr'}
    out = ext_x7_train(v{1}, 0);
    list(end + 1) = struct('file', out.agentFile, 'label', [v{1} '_s0'], 'group', v{1}, 'eps_v', 0.02, ...
                           'eps_w', 0.01); %#ok<AGROW>
    fprintf('=== %s fertig (%.1f min) ===\n', v{1}, toc(t0) / 60);
end
A = ext_x7_eval(list, 'label', 'pilot');
R = A(A.subject == "R", :);
for k = 1:numel(list)
    a = A(A.subject == string(list(k).label), :);
    go = a.follows == 1 && a.nom_rms_ee <= 1.1 * R.nom_rms_ee;
    fprintf('%s: folgt %d, nominal RMS %.2f mm (R %.2f), ori %.2f mrad (R %.2f) -> %s\n', list(k).label, ...
            a.follows, 1000 * a.nom_rms_ee, 1000 * R.nom_rms_ee, 1000 * a.nom_ori_max, 1000 * R.nom_ori_max, ...
            string(go));
end
fprintf('=== X7-Pilot fertig nach %.1f h ===\n', toc(t0) / 3600);
end
