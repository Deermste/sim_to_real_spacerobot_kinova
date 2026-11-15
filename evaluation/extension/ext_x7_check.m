function T = ext_x7_check()
%EXT_X7_CHECK  Pruefungen fuer X7 (Residual RL), 15.11.2026.
%   T = ext_x7_check()
%
%   1  Regler: ext_kinsim mit ctrl = Rbeta 21,5 (step) gegen ext_x7_ctrl mit Korrektur null (propose, apply).
%      Erwartung bitgleich (Gelenkbahn, Kennzahlen).
%   2  Umgebung: ext_x7_env Schritt fuer Schritt mit einer festen, von der Beobachtung abhaengigen Korrektur gegen
%      ext_kinsim mit ext_x7_ctrl und derselben Korrektur. Szenarien nominal und kombiniert (Basismasse 32,5 kg,
%      Verzoegerung 1, Verstaerkung 1,1, Messrauschen, Startstellung, Drift). Erwartung bitgleich.
%   3  Laufzeit einer Episode der Umgebung (nominal und DR-voll).

setup_project;
rows = {};
ctrlR = ext_x2_controller('j6_lim', 0.9774, 'invert', true, 'K', ext_kin_model(), 'beta', 21.544, 'j6_side', -1);
r1 = ext_kinsim([], 'ctrl', ctrlR, 'j6_lim', 0.9774, 'reward_mode', 4);
r2 = ext_kinsim([], 'ctrl', ext_x7_ctrl(@(ob) zeros(3, 1)), 'j6_lim', 0.9774, 'reward_mode', 4);
rows{end + 1} = row("1 Regler step gegen propose/apply(0)", r1.ts.q, r2.ts.q, r1.metrics, r2.metrics);

dfun = @(ob) tanh([30 * ob(1); 30 * ob(3); 20 * ob(28)] + 0.5 * ob(30:32));
sig = [1e-3 * ones(3, 1); 5e-3 * ones(3, 1); 1e-3 * ones(3, 1); 1e-3 * ones(3, 1); 1e-3 * ones(7, 1); ...
       5e-3 * ones(7, 1); 1e-3 * ones(3, 1)];
q0 = zeros(7, 1); q0([2 4 6]) = deg2rad([1.5; -1; 0.7]);
scen = {
    'nominal', {}, {}
    'kombiniert', {'plant', {'base_mass', 32.5}, 'delay_steps', 1, 'cmd_scale', 1.1, 'obsNoise', sig, ...
                   'rngSeed', 7, 'q0', q0, 'w0_init', [0; 0.002; 0]}, ...
                  {'K', ext_kin_model('base_mass', 32.5), 'delay_steps', 1, 'cmd_scale', 1.1, 'obsNoise', sig, ...
                   'rngSeed', 7, 'q0', q0, 'w0_init', [0; 0.002; 0]}
    };
for s = 1:size(scen, 1)
    env = ext_x7_env('scenario', scen{s, 2});
    ob = reset(env);
    done = false; n = 0; R = 0;
    while ~done
        [ob, r, done] = step(env, dfun(ob));
        n = n + 1; R = R + r;
    end
    L = env.LoggedSignals;
    mE = ext_x7_plant('metrics', L.S);
    qE = L.S.qS(1:L.S.k * L.S.m + 1, :);
    rk = ext_kinsim([], 'ctrl', ext_x7_ctrl(dfun), 'j6_lim', 0.9774, 'reward_mode', 4, scen{s, 3}{:});
    rows{end + 1} = row("2 Umgebung gegen ext_kinsim, " + scen{s, 1}, rk.ts.q, qE, rk.metrics, mE); %#ok<AGROW>
    fprintf('  %s: %d Schritte, Return %.1f, RMS %.2f mm, ori_max %.2f mrad\n', scen{s, 1}, n, R, ...
            1000 * mE.rms_ee, 1000 * mE.ori_max);
end
T = struct2table([rows{:}]);
disp(T);
for dr = ["none", "full"]
    env = ext_x7_env('dr', char(dr), 'seed', 1);
    t0 = tic; nEp = 4;
    for e = 1:nEp
        ob = reset(env); done = false;
        while ~done, [ob, ~, done] = step(env, zeros(3, 1)); end %#ok<ASGLU>
    end
    fprintf('Laufzeit %s: %.2f s je Episode\n', dr, toc(t0) / nEp);
end
end

function r = row(name, qA, qB, mA, mB)
n = min(size(qA, 1), size(qB, 1));
r = struct('check', name, 'n_A', size(qA, 1), 'n_B', size(qB, 1), 'max_dq', max(abs(qA(1:n, :) - qB(1:n, :)), [], 'all'), ...
           'd_rms', abs(mA.rms_ee - mB.rms_ee), 'd_ori', abs(mA.ori_max - mB.ori_max));
end
