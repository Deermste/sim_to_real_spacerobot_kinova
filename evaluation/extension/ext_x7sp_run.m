function r = ext_x7sp_run(ctrl, pr, varargin)
%EXT_X7SP_RUN  Eine Set-Point-Episode in ext_kinsim mit Kennzahlen wie ext_x6_ctrl_eval (X7-SP, 15.11.2026).
%   r = ext_x7sp_run(ctrl, pr)                  ctrl: ctrl-Funktion, pr: Paar (q0, p0, pT, d0, id)
%   r = ext_x7sp_run(ctrl, pr, 'K', K, ...)     weitere Optionen fuer ext_kinsim (Szenario)
%   r: success (5 mm und 5 mm/s 1 s lang innerhalb von 15 s), t_settle, err_end (Mittel der letzten 0,5 s),
%   ori_max, early_stop, Tm.

[C, Knom, qHw] = ext_x7sp_setup();
Tm = min(max(1.5, 9.4 * pr.d0), 10);
ref = @(t) mj(t, pr.p0, pr.pT, Tm);
args = [{'K', Knom}, varargin];
res = ext_kinsim([], 'ctrl', ctrl, 'chain', 'x6', 'chainP', C, 'Ts_agent', C.Ts, 'T', 15, 'q0', pr.q0(:), ...
                 'reward_mode', 1, 'refFcn', ref, 'qLim', qHw, args{:});
ts = res.ts;
ta = ts.t_agent;
[pa, va] = mj(ta, pr.p0, pr.pT, Tm);
eT = vecnorm(ts.obs(:, 1:3) + pa - pr.pT(:).', 2, 2);
vE = vecnorm(ts.obs(:, 4:6) + va, 2, 2);
ok = eT <= 0.005 & vE <= 0.005;
nHold = round(1 / C.Ts);
tSet = NaN; run = 0;
for k = 1:numel(ok)
    if ok(k), run = run + 1; else, run = 0; end
    if run >= nHold, tSet = ta(k - nHold + 1); break; end
end
r = struct('id', pr.id, 'd0', pr.d0, 'Tm', Tm, 'success', double(~isnan(tSet)), 't_settle', tSet, ...
           'err_end', mean(eT(ta >= ta(end) - 0.5)), 'ori_max', res.metrics.ori_max, ...
           'early_stop', double(res.metrics.early_stop));
end

function [pp, vv] = mj(t, p0, pT, Tm)
s = min(max(t(:) / Tm, 0), 1);
f = 10 * s .^ 3 - 15 * s .^ 4 + 6 * s .^ 5;
df = (30 * s .^ 2 - 60 * s .^ 3 + 30 * s .^ 4) / Tm .* (t(:) < Tm);
pp = p0(:).' + f * (pT(:) - p0(:)).';
vv = df * (pT(:) - p0(:)).';
end
