function T = ext_x6_chain_test()
%EXT_X6_CHAIN_TEST  Einheitentests der neuen Befehlskette chain_step (X6, E18) und Bitgleichheit der alten Pfade.
%   T = ext_x6_chain_test()
%
%   1  Rate: Sprung a = 0,5 auf J2 aus der Ruhe bei 10, 20 und 40 Hz, ohne und mit Filter (tau 0,1 s). Vergleich
%      des Befehls zu den gemeinsamen Zeitpunkten (Vielfache von 0,1 s) gegen 40 Hz.
%   2  Grenzen: 20 000 Schritte mit zufaelligen Aktionen und Gelenkwinkeln. |v| <= v_cap, |dv| <= a_max Ts.
%   3  Ruhe: a = 0 ergibt v = 0.
%   4  Bremskurve im kinematischen Simulator: J2, J4, J6 nacheinander mit voller Aktion gegen die Winkelgrenze
%      (20 Hz, 6 s, frei schwebend). Groesster Winkel gegen Grenze und Rand.
%   5  Alte Pfade unveraendert: ext_x2_sweep (full_inv, J6 0,9774) gegen X2_sweep_20261110_113752.csv und D16 r4 s2
%      nominal in ext_kinsim gegen X1_3_diag_agents_20261113_084339.csv.
%   CSV: data/simulation/extension/X6_chain_test_<Zeit>.csv

setup_project;
rows = {};
P0 = chain_step('params');

% --- 1 Rate ---
for tau = [0 0.1]
    ref = [];
    for hz = [40 20 10]
        P = P0; P.Ts = 1 / hz; P.tau = tau;
        S = chain_step('init', P);
        n = round(3 * hz);
        v = zeros(n + 1, 1);
        a = zeros(7, 1); a(2) = 0.5;
        for k = 1:n
            [vk, S] = chain_step(S, a, zeros(7, 1));
            v(k + 1) = vk(2);
        end
        tk = (0:n).' / hz;
        tc = (0:0.1:3).';
        vc = v(round(tc * hz) + 1);
        if hz == 40, ref = vc; end
        rows{end + 1} = row(sprintf('1 Rate %d Hz, tau %.1f: max |v - v(40 Hz)| [rad/s]', hz, tau), ...
                            max(abs(vc - ref)), sprintf('Endwert %.4f, Soll %.4f', v(end), 0.5 * P.v_max(2))); %#ok<AGROW>
        if tau == 0
            k95 = find(v >= 0.95 * 0.5 * P.v_max(2), 1);
            rows{end + 1} = row(sprintf('1 Rate %d Hz: Zeit bis 95 %% [s]', hz), tk(k95), ''); %#ok<AGROW>
        end
    end
end

% --- 2 Grenzen ---
rs = RandStream('mt19937ar', 'Seed', 1);
for tau = [0 0.1]
    P = P0; P.tau = tau;
    S = chain_step('init', P);
    vPrev = zeros(7, 1); worstV = 0; worstA = 0;
    for k = 1:20000
        a = 2 * rand(rs, 7, 1) - 1;
        if rand(rs) < 0.1, a = sign(a); end
        q = (2 * rand(rs, 7, 1) - 1) .* min(P.q_lim, 2 * pi);
        [v, S] = chain_step(S, a, q);
        worstV = max(worstV, max(abs(v) ./ P.v_cap));
        worstA = max(worstA, max(abs(v - vPrev)) / (P.a_max * P.Ts));
        vPrev = v;
    end
    rows{end + 1} = row(sprintf('2 Grenzen tau %.1f: max |v| / v_cap', tau), worstV, ''); %#ok<AGROW>
    rows{end + 1} = row(sprintf('2 Grenzen tau %.1f: max |dv| / (a_max Ts)', tau), worstA, ''); %#ok<AGROW>
end

% --- 3 Ruhe ---
S = chain_step('init', P0);
mx = 0;
for k = 1:100
    [v, S] = chain_step(S, zeros(7, 1), zeros(7, 1));
    mx = max(mx, max(abs(v)));
end
rows{end + 1} = row('3 Ruhe: max |v| bei a = 0', mx, '');

% --- 4 Bremskurve ---
K = ext_kin_model();
qL = [2.41 2.66 2.01];
jj = [2 4 6];
for i = 1:3
    seq = zeros(121, 7); seq(:, jj(i)) = 1;
    r = ext_kinsim([], 'actionSeq', seq, 'chain', 'x6', 'Ts_agent', 0.05, 'T', 6, 'K', K, 'reward_mode', 1, ...
                   'refFcn', @(t) zeros(numel(t), 3), 'noStop', true);
    qmax = max(r.ts.q(:, jj(i)));
    rows{end + 1} = row(sprintf('4 Bremse J%d: Grenze minus groesster Winkel [Grad]', jj(i)), ...
                        rad2deg(qL(i) - qmax), sprintf('Rand %.1f Grad, Bremskurve in %.0f %% der Schritte', ...
                        rad2deg(P0.q_margin), 100 * r.metrics.x6_brake)); %#ok<AGROW>
end

% --- 5 Alte Pfade ---
T0 = ext_x2_sweep('variants', {'full_inv'}, 'j6', 0.9774, 'save', false);
S0 = readtable(sk_path('data', 'simulation', 'extension', 'X2_sweep_20261110_113752.csv'), 'TextType', 'string');
S0 = S0(S0.variant == "full_inv" & abs(S0.j6_lim - 0.9774) < 1e-6, :);
rows{end + 1} = row('5 Sweep full_inv: max |RMS - gespeichert| [m]', max(abs(sort(S0.rms_ee) - sort(T0.rms_ee))), '');
rows{end + 1} = row('5 Sweep full_inv: max |ori - gespeichert| [rad]', max(abs(sort(S0.ori_max) - sort(T0.ori_max))), '');
D = readtable(sk_path('data', 'simulation', 'extension', 'X1_3_diag_agents_20261113_084339.csv'), 'TextType', 'string');
d = D(D.agent == "D16_ppo_40hz_r4_seed2_ep3000", :);
f = sk_path('SavedAgents', 'MotionProfile', 'D16', 'D16_ppo_40hz_r4_seed2_ep3000.mat');
r = ext_kinsim(f, 'j6_lim', 0.9774, 'reward_mode', 5);
rows{end + 1} = row('5 D16 r4 s2 kinematisch: |RMS - gespeichert| [m]', abs(r.metrics.rms_ee - d.rms_ee), '');

T = struct2table([rows{:}]);
disp(T);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
writetable(T, sk_path('data', 'simulation', 'extension', ['X6_chain_test_' stamp '.csv']));
end

function r = row(name, value, note)
r = struct('test', string(name), 'value', value, 'note', string(note));
end
