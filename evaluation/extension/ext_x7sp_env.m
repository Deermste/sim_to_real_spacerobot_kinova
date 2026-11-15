function [env, info] = ext_x7sp_env(pool, varargin)
%EXT_X7SP_ENV  Residual-RL-Umgebung fuer den Set-Point (X7-SP, 15.11.2026): Regler plus Korrektur der Sollwerte.
%   [env, info] = ext_x7sp_env(pool)                      pool: Paare (q0, pT, p0, d0) wie X6_train
%   [env, info] = ext_x7sp_env(pool, 'dr', 'full', 'seed', 2, 'beta', 1)
%
%   Aufgabe wie X6 (E11): Werkzeugpunkt (0,121 m vor dem Flansch) von q0 zum Ziel pT, frei schwebend, alle sieben
%   Gelenke, 20 Hz, neue Kette chain_step mit a_max 1 / 10 rad/s^2 (Handbuch, E18), Episode 15 s. Strecke
%   ext_x7_plant mit chain 'x6' (bitgleich zu ext_kinsim, ext_x7sp_check).
%   Grundregler wie ext_x6_ctrl_eval: ext_x2_controller gewichtet mit beta (Standard 1, X7.2), Kp 5, mu 1e-4,
%   x, y, z, Nominalmodell, Inversion der Kette (chainP). Referenz Minimum-Jerk-Gerade p0 -> pT mit
%   Tm = min(max(1,5 s, 9,4 s/m d0), 10 s).
%   Korrektur: Aktion Delta in [-1, 1]^6, db = eps_v Delta(1:3) auf die Sollgeschwindigkeit des Werkzeugpunkts,
%   dw = eps_w Delta(4:6) auf die Soll-Drehrate der Basis (Welt). Delta = 0 ist genau der Regler.
%   Beobachtung (40 Kanaele, ohne Kappung): die 29 Kanaele von ext_kinsim (ep, ev gegen die Referenz), pT - p
%   (3, Welt, p gemessen = ep + Referenz), Vorschlag des Reglers ohne Korrektur / v_max (7), Phase min(t / Tm, 1) (1).
%   Reward je Schritt: -d / 0,05 m - ori / 0,087 rad + 1 (d <= 5 mm und |v| <= 5 mm/s) - w_res |Delta|^2 / 6,
%   d = |pT - p|, ori = Drehwinkel der Basis, 0,087 rad ist die mittlere Drehung von R0 auf dem Auswertesatz.
%   Abbruch wie ext_reward (Reward -50). Kein Ende beim Erfolg (gehalten wird bis T).
%   DR-voll wie ext_x7_env, Verzoegerung in Schritten zu 50 ms (0 bis 2).
%   Optionen: beta 1 (Rbeta 1, X7.2), eps_v 0,02 m/s, eps_w 0,02 rad/s, w_res 0,1, dr 'none' oder 'full', seed 0,
%   scenario (Tests), sequential false.

p = inputParser;
p.addParameter('beta', 1);
p.addParameter('eps_v', 0.02);
p.addParameter('eps_w', 0.02);
p.addParameter('w_res', 0.1);
p.addParameter('dr', 'none');
p.addParameter('seed', 0);
p.addParameter('scenario', {});
p.addParameter('sequential', false);
p.parse(varargin{:});
o = p.Results;
[C, Knom, qHw] = ext_x7sp_setup();
cArgs = {'mode', 'weighted', 'beta', o.beta, 'gamma', 0, 'Kp', 5, 'mu', 1e-4, 'joints', 1:7, 'task', [1 2 3], ...
         'K', Knom, 'invert', true, 'Ts_agent', C.Ts, 'lim', C.v_max, 'chainP', C};
o.ctrlArgs = cArgs;
nObs = 40;
obsInfo = rlNumericSpec([nObs 1], 'LowerLimit', -inf(nObs, 1), 'UpperLimit', inf(nObs, 1));
obsInfo.Name = 'x7sp_obs';
actInfo = rlNumericSpec([6 1], 'LowerLimit', -ones(6, 1), 'UpperLimit', ones(6, 1));
actInfo.Name = 'x7sp_delta';
rs = RandStream('mt19937ar', 'Seed', o.seed);
seededFor = -1; seqK = 0;
env = rlFunctionEnv(obsInfo, actInfo, @stepFcn, @resetFcn);
info = struct('obsInfo', obsInfo, 'actInfo', actInfo, 'opts', o);

    function [obs, L] = resetFcn()
        tk = getCurrentTask();
        wid = 0;
        if ~isempty(tk), wid = tk.ID; end
        if wid ~= seededFor
            if wid > 0, rs = RandStream('mt19937ar', 'Seed', 100 * o.seed + wid); end
            seededFor = wid;
        end
        if o.sequential
            seqK = mod(seqK, numel(pool)) + 1;
            pr = pool(seqK);
        else
            pr = pool(randi(rs, numel(pool)));
        end
        Tm = min(max(1.5, 9.4 * pr.d0), 10);
        po = struct('chain', 'x6', 'chainP', C, 'Ts_agent', C.Ts, 'T', 15, 'qLim', qHw, 'q0', pr.q0(:), ...
                    'refFcn', @(t) minJerk(t, pr.p0, pr.pT, Tm));
        K = Knom;
        if strcmp(o.dr, 'full')
            lu = @(r) exp(log(r(1)) + rand(rs) * (log(r(2)) - log(r(1))));
            fm = lu([0.25 2]);
            fi = lu([0.5 2]);
            po.delay_steps = floor(rand(rs) * 3);
            po.cmd_scale = 0.9 + rand(rs) * 0.2;
            ns = rand(rs) * 2;
            K = ext_kin_model('tool_offset', [0; 0; 0.121], 'base_mass', 65 * fm, 'base_inertia', 10.833 * fm * fi);
            if ns > 0, po.obsNoise = ns * ext_x7sp_setup('noise'); po.rngSeed = randi(rs, 2^31 - 1); end
        end
        if ~isempty(o.scenario)
            sc = o.scenario;
            for i = 1:2:numel(sc)
                if strcmp(sc{i}, 'plant')
                    K = ext_kin_model('tool_offset', [0; 0; 0.121], sc{i + 1}{:});
                else
                    po.(sc{i}) = sc{i + 1};
                end
            end
        end
        po.K = K;
        L.S = ext_x7_plant(po);
        [L.ctrl, L.api] = ext_x2_controller(cArgs{:});
        L.pT = pr.pT(:); L.Tm = Tm; L.id = pr.id;
        [L.ob, L.S] = ext_x7_plant('obs', L.S);
        L.hold = 0; L.tSet = NaN;
        [obs, L] = propose(L);
    end

    function [obs, r, done, L] = stepFcn(act, L)
        dl = min(max(double(act(:)), -1), 1);
        R = L.R;
        R.db = o.eps_v * dl(1:3);
        R.dw = o.eps_w * dl(4:6);
        u = L.ctrl(L.ob, R);
        L.S = ext_x7_plant(L.S, u);
        [L.ob, L.S] = ext_x7_plant('obs', L.S);
        ob = L.ob;
        y = ext_x7_plant('tool', L.S);
        d = norm(L.pT - y.p);
        ok = d <= 0.005 && norm(y.v) <= 0.005;
        if ok, L.hold = L.hold + 1; else, L.hold = 0; end
        if L.hold >= 20 && isnan(L.tSet), L.tSet = (L.S.k - 20) * C.Ts; end
        [~, isd] = ext_reward(ob(1:3), ob(4:6), zeros(7, 1), zeros(7, 1), ob(10:12), ob(27:29), 1, 0);
        r = -d / 0.05 - norm(ob(27:29)) / 0.087 + double(ok) - o.w_res * sum(dl .^ 2) / 6;
        if isd, r = -50; end
        done = isd || L.S.k >= L.S.N;
        if done
            obs = [ob; zeros(3, 1); zeros(7, 1); 1];
            return
        end
        [obs, L] = propose(L);
    end

    function [obs, L] = propose(L)
        n = L.S.k * L.S.m + 1;
        t = L.S.k * C.Ts;
        R = struct('t', t, 'pref', L.S.traj(n, :).', 'vref', L.S.vref(n, :).');
        L.R = R;
        xc = L.api.propose(L.ob, R);
        pm = L.ob(1:3) + R.pref;                 % gemessener Werkzeugpunkt (mit Rauschen und Messfehler)
        obs = [L.ob; L.pT - pm; xc(:) ./ C.v_max; min(t / L.Tm, 1)];
    end
end

function pp = minJerk(t, p0, pT, Tm)
s = min(max(t(:) / Tm, 0), 1);
f = 10 * s .^ 3 - 15 * s .^ 4 + 6 * s .^ 5;
pp = p0(:).' + f * (pT(:) - p0(:)).';
end
