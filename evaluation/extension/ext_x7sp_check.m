function T = ext_x7sp_check()
%EXT_X7SP_CHECK  Pruefung fuer X7-SP (15.11.2026): Umgebung gegen ext_kinsim, Regler mit Korrektur null.
%   T = ext_x7sp_check()
%
%   1  ext_x7sp_ctrl mit Korrektur null gegen den Regler allein in ext_kinsim (bitgleich erwartet).
%   2  ext_x7sp_env mit fester, beobachtungsabhaengiger Korrektur gegen ext_kinsim mit ext_x7sp_ctrl und derselben
%      Korrektur, zwei Paare, nominal und kombiniert (Masse, Verzoegerung, Verstaerkung, Rauschen). Bitgleich.
%   3  Laufzeit einer Episode.

setup_project;
[C, Knom, qHw] = ext_x7sp_setup();
dd = sk_path('data', 'simulation', 'extension');
dT = dir(fullfile(dd, 'X6_train_*.mat'));
Lt = load(fullfile(dT(end).folder, dT(end).name), 'P');
prs = Lt.P([3 17]);
rows = {};
dfun = @(ob) tanh([20 * ob(30:32); 0.3 * ob(10:12)] + 0.5 * [ob(33:35); ob(36:38)]);
sig = ext_x7sp_setup('noise');
scen = {
    'nominal', {}, {}
    'kombiniert', {'plant', {'base_mass', 32.5}, 'delay_steps', 1, 'cmd_scale', 1.1, 'obsNoise', sig, 'rngSeed', 5}, ...
                  {'K', ext_kin_model('tool_offset', [0; 0; 0.121], 'base_mass', 32.5), 'delay_steps', 1, ...
                   'cmd_scale', 1.1, 'obsNoise', sig, 'rngSeed', 5}
    };
for ip = 1:numel(prs)
    pr = prs(ip);
    Tm = min(max(1.5, 9.4 * pr.d0), 10);
    ref = @(t) mj(t, pr.p0, pr.pT, Tm);
    kargs = {'chain', 'x6', 'chainP', C, 'Ts_agent', C.Ts, 'T', 15, 'q0', pr.q0(:), 'reward_mode', 1, ...
             'refFcn', ref, 'qLim', qHw};
    c0 = ext_x2_controller('mode', 'weighted', 'beta', 1, 'gamma', 0, 'Kp', 5, 'mu', 1e-4, 'joints', 1:7, ...
        'task', [1 2 3], 'K', Knom, 'invert', true, 'Ts_agent', C.Ts, 'lim', C.v_max, 'chainP', C);
    r1 = ext_kinsim([], 'ctrl', c0, kargs{:}, 'K', Knom);
    r2 = ext_kinsim([], 'ctrl', ext_x7sp_ctrl(@(ob) zeros(6, 1), pr.pT, Tm), kargs{:}, 'K', Knom);
    rows{end + 1} = row(sprintf("1 Paar %d Regler gegen Korrektur null", pr.id), r1.ts.q, r2.ts.q); %#ok<AGROW>
    for s = 1:size(scen, 1)
        env = ext_x7sp_env(pr, 'scenario', scen{s, 2}, 'sequential', true);
        ob = reset(env); done = false; t0 = tic;
        while ~done, [ob, ~, done] = step(env, dfun(ob)); end
        tEp = toc(t0);
        L = env.LoggedSignals;
        qE = L.S.qS(1:L.S.k * L.S.m + 1, :);
        sa = scen{s, 3};
        if isempty(sa), sa = {'K', Knom}; end
        rk = ext_kinsim([], 'ctrl', ext_x7sp_ctrl(dfun, pr.pT, Tm), kargs{:}, sa{:});
        rows{end + 1} = row(sprintf("2 Paar %d Umgebung gegen ext_kinsim, %s", pr.id, scen{s, 1}), rk.ts.q, qE); %#ok<AGROW>
        fprintf('  Paar %d %s: %d Schritte, %.2f s, ori_max %.1f mrad\n', pr.id, scen{s, 1}, L.S.k, tEp, ...
                1000 * max(L.S.oriS(1:L.S.k * L.S.m + 1)));
    end
end
T = struct2table([rows{:}]);
disp(T);
end

function r = row(name, qA, qB)
n = min(size(qA, 1), size(qB, 1));
r = struct('check', name, 'n_A', size(qA, 1), 'n_B', size(qB, 1), ...
           'max_dq', max(abs(qA(1:n, :) - qB(1:n, :)), [], 'all'));
end

function pp = mj(t, p0, pT, Tm)
s = min(max(t(:) / Tm, 0), 1);
f = 10 * s .^ 3 - 15 * s .^ 4 + 6 * s .^ 5;
pp = p0(:).' + f * (pT(:) - p0(:)).';
end
