function desktop_fig_playback()
%DESKTOP_FIG_PLAYBACK  Endeffektor-Bahnen der Playback-Laeufe 004-006 fuer die Abbildung fig:playback (Sec. V-B).
%   Wie evaluation/paper/legacy_fk_numbers.m: FK der Gen3-URDF (end_effector_link) fuer
%     measured    gemessene Gelenkwinkel
%     integrated  dq_cmd ueber die tatsaechliche Schleifenzeit integriert (Servo-Folge)
%     plan        dq_cmd ueber die geplante Zeit t_ref integriert (geplanter Takt)
%   Laeufe 004 (nominal), 005 (halbe Geschwindigkeit), 006 (1,33-fach) auf der nicht singulaeren Bahn.
%   Ergebnis: data/simulation/desktop/FIG_playback.csv (run, t, t_ref, je drei Positionen)

setup_project;
gen3 = importrobot(sk_path('robot', 'GEN3-7DOF-VISION_ARM_URDF_V12.urdf'));
gen3.DataFormat = 'row';
fk = @(q) tform2trvec(getTransform(gen3, deg2rad(q), 'end_effector_link'));
f = [dir(sk_path('data', 'hardware', 'playback_runs', 'run_004_*.mat'))
     dir(sk_path('data', 'hardware', 'playback_runs', 'run_005_*.mat'))
     dir(sk_path('data', 'hardware', 'playback_runs', 'run_006_*.mat'))];
T = table();
for k = 1:numel(f)
    L = load(fullfile(f(k).folder, f(k).name));
    d = L.data;
    t = d.t(:); tr = d.t_ref(:); q = d.q_measured; dq = d.dq_cmd; n = numel(t);
    qa = zeros(n, 7); qa(1, :) = q(1, :); qp = qa;
    for i = 2:n
        qa(i, :) = qa(i - 1, :) + dq(i - 1, :) * (t(i) - t(i - 1));
        qp(i, :) = qp(i - 1, :) + dq(i - 1, :) * (tr(i) - tr(i - 1));
    end
    pm = zeros(n, 3); pa = pm; pp = pm;
    for i = 1:n
        pm(i, :) = fk(q(i, :)); pa(i, :) = fk(qa(i, :)); pp(i, :) = fk(qp(i, :));
    end
    run = repmat(string(f(k).name(1:7)), n, 1);
    scale = repmat(L.meta.timeScale, n, 1);
    T = [T; table(run, scale, t - t(1), tr - tr(1), pm, pa, pp, 'VariableNames', ...
        {'run', 'timeScale', 't', 't_ref', 'measured', 'integrated', 'plan'})]; %#ok<AGROW>
    fprintf('%s Faktor %.2f: %d Schritte, %.1f s, Abstand zum Plan RMS %.1f mm\n', f(k).name(1:7), ...
        L.meta.timeScale, n, t(end) - t(1), 1e3 * sqrt(mean(vecnorm(pm - pp, 2, 2) .^ 2)));
end
writetable(T, sk_path('data', 'simulation', 'desktop', 'FIG_playback.csv'));
end
