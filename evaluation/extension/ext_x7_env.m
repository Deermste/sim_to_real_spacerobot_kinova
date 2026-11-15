function [env, info] = ext_x7_env(varargin)
%EXT_X7_ENV  Residual-RL-Umgebung fuer X7 (15.11.2026): Regler Rbeta plus begrenzte Korrektur der Policy.
%   [env, info] = ext_x7_env()                       nominal (Variante Res)
%   [env, info] = ext_x7_env('dr', 'full', 'seed', 3)  DR-voll wie X2.4 (Variante Res-DR)
%
%   Aufgabe wie die r4-Agenten: Halbkreis 8,5 s in der Ebene, J2, J4, J6, 40 Hz, J6 0,9774 rad/s, alte
%   Befehlskette (Filter 0,95, Rate Limiter 0,5 rad/s^2). Strecke ext_x7_plant (bitgleich zu ext_kinsim,
%   ext_x7_check).
%   Grundregler: ext_x2_controller mit Nominalmodell und Inversion der Kette, Standard Rbeta 21,5 (J6-Seite -,
%   Kp 5) wie 'Rb21' in ext_x2_robust.
%   Korrektur im Aufgabenraum (15.11., statt auf die Gelenkgeschwindigkeit wie im Plan, Grund in RESULTS X7):
%   Aktion Delta in [-1, 1]^3. Der Regler bekommt db = eps_v Delta(1:2) zur Sollgeschwindigkeit des EE (x, z,
%   Welt) und dw = [0; eps_w Delta(3); 0] zur Soll-Drehrate der Basis um y. Delta = 0 ist genau der Regler.
%   Beobachtung (32 Kanaele, ohne Kappung): die 29 Kanaele von ext_kinsim (mit Rauschen und Messfehler) und
%   xc ./ 0,9774, der Vorschlag des Reglers ohne Korrektur (api.propose, aendert den Zustand nicht).
%   Reward: ext_reward Modus 4, Gewicht 2 (wie D16) auf der Beobachtung nach dem Schritt, ohne die
%   Befehlsterme (Befehl null, die Glaettung ist Sache des Reglers), dazu -w_res |Delta|^2.
%   Ende bei isDone aus ext_reward (Reward -50) oder nach T.
%   Optionen: eps_v 0,02 m/s, eps_w 0,01 rad/s, w_res 0,1, dr 'none' oder 'full', seed 0, ctrlArgs (Zellarray
%   fuer ext_x2_controller, ersetzt Rbeta 21,5), scenario (Zellarray mit festen Optionen fuer ext_x7_plant und
%   'plant' fuer ext_kin_model, nur Tests).
%   DR-voll je Episode wie ext_x2_4_train: Basismasse 65 kg x f_m (log-gleich in [0,25; 2]), Traegheit
%   10,833 x f_m x f_i (f_i log-gleich in [0,5; 2]), Verzoegerung 0 bis 2 Schritte, Verstaerkung [0,9; 1,1],
%   Messrauschen s x Sigma von ext_x2_robust (s in [0; 2]), Startstellung J2, J4, J6 +-2 Grad. Der Regler
%   behaelt immer das Nominalmodell.
%   Zufallsstrom: auf einem Worker Seed 100 * seed + Worker-ID wie ext_x6_env.

p = inputParser;
p.addParameter('eps_v', 0.02);
p.addParameter('eps_w', 0.01);
p.addParameter('w_res', 0.1);
p.addParameter('dr', 'none');
p.addParameter('seed', 0);
p.addParameter('ctrlArgs', {});
p.addParameter('scenario', {});
p.parse(varargin{:});
o = p.Results;
assert(ismember(o.dr, {'none', 'full'}), 'ext_x7_env:dr', 'dr ist none oder full');
Knom = ext_kin_model();
cArgs = o.ctrlArgs;
if isempty(cArgs), cArgs = {'beta', 21.544, 'j6_side', -1}; end
cArgs = [{'j6_lim', 0.9774, 'invert', true, 'K', Knom}, cArgs];
o.ctrlArgs = cArgs;
a = [2 4 6];
lima = 0.9774 * ones(3, 1);
nObs = 32;
obsInfo = rlNumericSpec([nObs 1], 'LowerLimit', -inf(nObs, 1), 'UpperLimit', inf(nObs, 1));
obsInfo.Name = 'x7_obs';
actInfo = rlNumericSpec([3 1], 'LowerLimit', -ones(3, 1), 'UpperLimit', ones(3, 1));
actInfo.Name = 'x7_delta';
rs = RandStream('mt19937ar', 'Seed', o.seed);
seededFor = -1;
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
        po = struct('j6_lim', 0.9774);
        K = Knom;
        L.draw = struct('base_mass', 65, 'inertia_scale', 1, 'delay', 0, 'gain', 1, 'noise_scale', 0, ...
                        'q0', zeros(3, 1));
        if strcmp(o.dr, 'full')
            lu = @(r) exp(log(r(1)) + rand(rs) * (log(r(2)) - log(r(1))));
            fm = lu([0.25 2]);
            fi = lu([0.5 2]);
            dl = floor(rand(rs) * 3);
            gn = 0.9 + rand(rs) * 0.2;
            ns = rand(rs) * 2;
            q0 = zeros(7, 1);
            q0(a) = deg2rad(2) * (2 * rand(rs, 3, 1) - 1);
            K = ext_kin_model('base_mass', 65 * fm, 'base_inertia', 10.833 * fm * fi);
            po.delay_steps = dl; po.cmd_scale = gn; po.q0 = q0;
            if ns > 0, po.obsNoise = ns * noiseSigma(); po.rngSeed = randi(rs, 2^31 - 1); end
            L.draw = struct('base_mass', 65 * fm, 'inertia_scale', fi, 'delay', dl, 'gain', gn, ...
                            'noise_scale', ns, 'q0', q0(a));
        end
        if ~isempty(o.scenario)
            sc = o.scenario;
            for i = 1:2:numel(sc)
                if strcmp(sc{i}, 'plant'), K = ext_kin_model(sc{i + 1}{:}); else, po.(sc{i}) = sc{i + 1}; end
            end
        end
        po.K = K;
        L.S = ext_x7_plant(po);
        [L.ctrl, L.api] = ext_x2_controller(cArgs{:});
        [ob, L.S] = ext_x7_plant('obs', L.S);
        L.ob = ob;
        L.n = 0;
        [obs, L] = propose(L);
    end

    function [obs, r, done, L] = stepFcn(act, L)
        dl = min(max(double(act(:)), -1), 1);
        R = L.R;
        R.db = o.eps_v * dl(1:2);
        R.dw = [0; o.eps_w * dl(3); 0];
        u = L.ctrl(L.ob, R);
        L.S = ext_x7_plant(L.S, u);
        L.n = L.n + 1;
        [ob, L.S] = ext_x7_plant('obs', L.S);
        L.ob = ob;
        [r, isd] = ext_reward(ob(1:3), ob(4:6), zeros(7, 1), zeros(7, 1), ob(10:12), ob(27:29), 4, 2);
        r = r - o.w_res * sum(dl .^ 2);
        done = isd || L.S.k >= L.S.N;
        if done
            obs = [ob; zeros(3, 1)];
            return
        end
        [obs, L] = propose(L);
    end

    function [obs, L] = propose(L)
        R = struct('t', L.S.k * L.S.o.Ts_agent, 'pref', L.S.traj(L.S.k * L.S.m + 1, :).', ...
                   'vref', L.S.vref(L.S.k * L.S.m + 1, :).');
        L.R = R;
        xc = L.api.propose(L.ob, R);
        obs = [L.ob; xc ./ lima];
    end
end

function s = noiseSigma()
% wie ext_x2_robust und ext_x2_4_train
s = [1e-3 * ones(3, 1); 5e-3 * ones(3, 1); 1e-3 * ones(3, 1); 1e-3 * ones(3, 1); 1e-3 * ones(7, 1); ...
     5e-3 * ones(7, 1); 1e-3 * ones(3, 1)];
end
