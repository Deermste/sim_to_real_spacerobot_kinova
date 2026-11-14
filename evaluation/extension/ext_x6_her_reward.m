function r = ext_x6_her_reward(o1, a, o2, H) %#ok<INUSL>
%EXT_X6_HER_REWARD  Reward der X6-Umgebung im HER-Modus, nur aus Beobachtungen (fuer Hindsight Experience Replay).
%   r = ext_x6_her_reward(o1, a, o2, H)     o1, o2 Beobachtung vor und nach dem Schritt (51x1 oder Zelle),
%                                           H = info.her aus ext_x6_env(..., 'her', true)
%
%   Aufbau der Beobachtung im HER-Modus (ext_x6_env):
%     1-3 Ziel (pT - c) / 0,5,  4-6 Werkzeugpunkt (p - c) / 0,5  (Welt, c = H.c),  7-9 v / 0,5 (Welt),
%     10-50 wie im Standardmodus,  51 Abbruch (Kollision oder Klemme, haengt nicht vom Ziel ab)
%   HER ersetzt 1-3 durch 4-6 eines spaeteren Schritts. Alle anderen Kanaele haengen nicht vom Ziel ab, der Reward
%   laesst sich damit fuer jedes Ziel neu berechnen.
%   r = Phi(d2) - Phi(d1) - w_v |v| / 0,05 - w_dq |dq| - w_brk any(brake) - w_base |w_base|
%       + w_in (d2 <= tol und |v| <= tol) + r_fail Abbruch
%   Phi wie im Modus 'progress'. Ohne w_da (die vorige Aktion steht nicht in der Beobachtung).

if iscell(o1), o1 = o1{1}; end
if iscell(o2), o2 = o2{1}; end
d1 = 0.5 * norm(o1(1:3) - o1(4:6));
d2 = 0.5 * norm(o2(1:3) - o2(4:6));
sp = 0.5 * norm(o2(7:9));
dq = o2(21:27) .* H.v_cap(:);
wb = 0.5 * norm(o2(31:33));
brk = any(o2(44:50) > 0.5);
fail = o2(51) > 0.5;
phi = @(d) -H.w_lin * d / 0.01 + 20 * H.w_fine * exp(-d / 0.005);
r = phi(d2) - phi(d1) - H.w_v * sp / 0.05 - H.w_dq * norm(dq) - H.w_brk * brk - H.w_base * wb ...
    + H.w_in * (d2 <= H.tol && sp <= H.tol) + H.r_fail * fail;
end
