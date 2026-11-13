function C = ext_x6_plant_check()
%EXT_X6_PLANT_CHECK  ext_x6_plant mit chain_step gegen ext_kinsim (chain 'x6'), gleiche Aktionen (X6.1).
%   C = ext_x6_plant_check()
%
%   Drei Startstellungen, je 300 Schritte (15 s, 20 Hz) mit zufaelligen, geglaetteten Aktionen auf allen
%   7 Gelenken, Werkzeugpunkt (tool_offset 0,121 m), Grenzen nach Datenblatt. ext_kinsim spielt dieselben Aktionen
%   offen ein (actionSeq). Vergleich von Werkzeugpunkt, Gelenkwinkeln und Basisdrehung zu den Agentenschritten.
%   Dazu die Rechenzeit je Schritt.

setup_project;
K = ext_kin_model('tool_offset', [0; 0; 0.121]);
P = chain_step('params');
qHw = min(P.q_lim, 2 * pi);
opt = struct('Ts', 0.005, 'Ts_agent', 0.05, 'tau', 0.02, 'qLim', qHw);
rs = RandStream('mt19937ar', 'Seed', 5);
rows = {};
for c = 1:3
    q0 = (2 * rand(rs, 7, 1) - 1) .* [pi; 1.8; pi; 2.0; pi; 1.6; pi];
    N = 300;
    A = zeros(N + 1, 7); a = zeros(7, 1);
    for k = 1:N + 1, a = 0.9 * a + 0.1 * (2 * rand(rs, 7, 1) - 1) * 3; A(k, :) = min(max(a, -1), 1).'; end
    r = ext_kinsim([], 'actionSeq', A, 'chain', 'x6', 'chainP', P, 'Ts_agent', 0.05, 'T', N * 0.05, 'K', K, ...
                   'q0', q0, 'reward_mode', 1, 'noStop', true, 'qLim', qHw, 'refFcn', @(t) zeros(numel(t), 3));
    S = ext_x6_plant('init', K, q0, opt);
    cs = chain_step('init', P);
    pE = zeros(N + 1, 3); qE = zeros(N + 1, 7); oE = zeros(N + 1, 1);
    tic;
    for k = 0:N
        y = ext_x6_plant('meas', S);
        pE(k + 1, :) = y.p.'; qE(k + 1, :) = y.q.'; oE(k + 1) = norm(y.e_ori);
        if k == N, break; end
        [v, cs] = chain_step(cs, A(k + 1, :).', y.q);
        S = ext_x6_plant(S, v);
    end
    tStep = toc / N;
    pk = r.ts.obs(:, 1:3);            % ep = Werkzeugpunkt - 0
    qk = r.ts.obs(:, 13:19);
    ok = vecnorm(r.ts.obs(:, 27:29), 2, 2);
    rows{end + 1} = struct('case', c, 'max_dp', max(vecnorm(pE - pk, 2, 2)), 'max_dq', max(abs(qE - qk), [], 'all'), ...
        'max_dori', max(abs(oE - ok)), 'step_ms', 1000 * tStep, 'brake', r.metrics.x6_brake); %#ok<AGROW>
end
C = struct2table([rows{:}]);
disp(C);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
writetable(C, sk_path('data', 'simulation', 'extension', ['X6_plant_check_' stamp '.csv']));
end
