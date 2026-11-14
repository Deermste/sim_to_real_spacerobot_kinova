function [env, info] = ext_x6_env(pool, varargin)
%EXT_X6_ENV  Set-Point-Umgebung fuer X6 (X6.1, Entwurf fuer den Pilot X6.3): frei schwebend, 7 Gelenke, 20 Hz.
%   [env, info] = ext_x6_env(pool)                     pool: Struct-Array mit q0 (7x1) und pT (3x1), z. B. aus
%                                                      ext_x6_pairs (set "eval" nur fuer die Auswertung nutzen)
%   [env, info] = ext_x6_env(pool, 'chainP', P, 'seed', 1)
%
%   Strecke ext_x6_plant (bitgleich zu ext_kinsim), Kette chain_step (E18), Werkzeugpunkt 0,121 m vor dem
%   EE-Flansch, Grenzen nach Datenblatt. Jede Episode zieht ein Paar aus pool.
%   Beobachtung (50 Kanaele, etwa auf +-1 normiert, Grenzen der Spezifikation +-Inf, damit nichts gekappt wird
%   wie in A72), Basissystem = aktuelle Lage der Basis:
%     1-3   e = Rb' (pT - p) [m]               Fehler zum Ziel (d0 bis 1,2 m)
%     4-6   Feinkanal clip(Rb' (pT - p), +-0,05) * 20
%     7-9   Rb' v / 0,5                        Geschwindigkeit des Werkzeugpunkts
%     10-17 sin und cos von q1, q3, q5, q7    (Endlosgelenke)
%     18-20 q2, q4, q6 / Grenze
%     21-27 dq / v_cap
%     28-30 e_ori / 0,5 (Drehvektor der Basis, Welt)
%     31-33 w_base / 0,5 (Welt)
%     34-36 Abstand von q2, q4, q6 zur Grenze / Grenze
%     37-43 v_prev / v_max (Ausgang der Kette im vorigen Schritt)
%     44-50 Bremskurve hat im vorigen Schritt eingegriffen (0 / 1)
%   Reward je Schritt (Entwurf, Gewichte als Optionen):
%     -w_lin d + w_fine exp(-d / 5 mm) - w_da |a - a_prev|^2 - w_brk any(brake) - w_base |w_base|
%     - w_stop |v| / 0,05 nahe am Ziel (d < 2 cm)
%     Option 'reward' 'progress' (seit 14.11., nach dem ersten Pilot): Abstand und Feinterm als Potenzial
%       Phi(d) = -w_lin d / 1 cm + 20 w_fine exp(-d / 5 mm),  r = Phi(d) - Phi(d_prev) - (Strafen wie oben)
%     Ueber eine Episode summiert sich Phi zu Phi(d_Ende) - Phi(d0). Ein fruehes Ende spart damit nichts. Mit
%     'step' (Standard, erster Pilot) kostet jeder Schritt -w_lin d, und ein Abbruch mit r_fail war billiger als
%     15 s in der Naehe des Ziels (der Agent lernte, die Episode zu beenden).
%     d = |pT - p|. Erfolg: d <= 5 mm und |v| <= 5 mm/s 20 Schritte lang (1 s), +r_succ, Ende.
%     Abbruch: d > d0 + 0,4 m (wie oodMargin im Deploy-Skript), ein Gelenk an der Klemme der Strecke oder
%     Kollision (Option 'coll', Standard true: ext_x6_coll mit Kapseln als Vorfilter und Mesh-Pruefung, Arm gegen
%     sich selbst, Greifer und Basiswuerfel, je Agentenschritt), r_fail, Ende. Sonst Ende nach T = 15 s.
%     Die Kollisionspruefung haengt nur von q ab, nicht von der Lage der Basis.
%   Optionen fuer den Pilot (X6.3):
%     'fine'       true: Feinkanal 4-6 und Feinterm. false: beide fehlen (47 Kanaele, w_fine 0), Variante (b)
%     'tol'        Erfolgstoleranz [m] fuer Abstand und Geschwindigkeit [m/s] (Standard 0,005 wie E11)
%     'dcap'       Ziel hoechstens dcap vom Start: weiter entfernte Ziele werden auf der Geraden p0 -> pT
%                  auf dcap verkuerzt (Curriculum, Standard Inf)
%     'pFull'      Anteil der Episoden ohne Verkuerzung (Standard 0)
%     'sequential' true: Paare der Reihe nach statt zufaellig (Auswertung)
%   Zufallsstrom: auf einem Worker Seed 100 * seed + Worker-ID (sonst zoegen alle Worker dieselbe Folge).
%   info: obsInfo, actInfo, opts. Logged Signals der Umgebung: Zustand, Paar, Zaehler, coll (Kollision im letzten
%   Schritt), nMesh (Mesh-Pruefungen in der Episode), outcome (success, ood, clamp, coll, timeout), d (Abstand am
%   Ende), fuer Tests lesbar.

p = inputParser;
p.addParameter('chainP', []);
p.addParameter('seed', 0);
p.addParameter('T', 15);
p.addParameter('w_lin', 1);
p.addParameter('w_fine', 0.5);
p.addParameter('w_da', 0.05);
p.addParameter('w_brk', 0.1);
p.addParameter('w_base', 0.1);
p.addParameter('w_stop', 0.2);
p.addParameter('r_succ', 50);
p.addParameter('r_fail', -50);
p.addParameter('coll', true);
p.addParameter('fine', true);
p.addParameter('tol', 0.005);
p.addParameter('dcap', Inf);
p.addParameter('pFull', 0);
p.addParameter('sequential', false);
p.addParameter('reward', 'step');
p.parse(varargin{:});
o = p.Results;
P = o.chainP;
if isempty(P), P = chain_step('params'); end
o.chainP = P;
K = ext_kin_model('tool_offset', [0; 0; 0.121]);
qHw = min(P.q_lim, 2 * pi);
plantOpt = struct('Ts', 0.005, 'Ts_agent', P.Ts, 'tau', 0.02, 'qLim', qHw);
fin = [2 4 6];
qL = P.q_lim(fin);
if o.coll
    CC = ext_x6_coll('params', K);
    rb = ext_x6_coll('robot');
else
    CC = []; rb = [];
end
nObs = 50 - 3 * ~o.fine;
if ~o.fine, o.w_fine = 0; end
obsInfo = rlNumericSpec([nObs 1], 'LowerLimit', -inf(nObs, 1), 'UpperLimit', inf(nObs, 1));   % keine Kappung (A72)
obsInfo.Name = 'x6_obs';
actInfo = rlNumericSpec([7 1], 'LowerLimit', -ones(7, 1), 'UpperLimit', ones(7, 1));
actInfo.Name = 'x6_action';
rs = RandStream('mt19937ar', 'Seed', o.seed);
seededFor = -1; seqK = 0;   % Prozess, fuer den der Strom gilt (0 Client, sonst Worker-ID)
nMax = round(o.T / P.Ts);
nHold = round(1 / P.Ts);
env = rlFunctionEnv(obsInfo, actInfo, @stepFcn, @resetFcn);
info = struct('obsInfo', obsInfo, 'actInfo', actInfo, 'opts', o, 'K', K, 'plantOpt', plantOpt, 'coll', CC);

    function [obs, L] = resetFcn()
        tk = getCurrentTask();
        wid = 0;
        if ~isempty(tk), wid = tk.ID; end
        if wid ~= seededFor
            % rlFunctionEnv ruft reset schon beim Erzeugen auf, die Kopie auf dem Worker braucht einen eigenen Strom
            if wid > 0, rs = RandStream('mt19937ar', 'Seed', 100 * o.seed + wid); end
            seededFor = wid;
        end
        if o.sequential
            seqK = mod(seqK, numel(pool)) + 1;
            pr = pool(seqK);
        else
            pr = pool(randi(rs, numel(pool)));
        end
        L.S = ext_x6_plant('init', K, pr.q0, plantOpt);
        L.cs = chain_step('init', P);
        y = ext_x6_plant('meas', L.S);
        pT = pr.pT(:);
        dc = norm(pT - y.p);
        if isfinite(o.dcap) && dc > o.dcap && ~(o.pFull > 0 && rand(rs) < o.pFull)
            pT = y.p + (pT - y.p) * o.dcap / dc;
        end
        L.pT = pT;
        L.id = 0;
        if isfield(pr, 'id'), L.id = pr.id; end
        L.outcome = "running";
        L.d0 = norm(L.pT - y.p); L.d = L.d0; L.dPrev = L.d0;
        L.aPrev = zeros(7, 1);
        L.brake = false(7, 1);
        L.hold = 0; L.n = 0; L.coll = false; L.nMesh = 0;
        obs = observe(y, L);
    end

    function [obs, r, done, L] = stepFcn(a, L)
        a = min(max(double(a(:)), -1), 1);
        y0 = ext_x6_plant('meas', L.S);
        [v, L.cs, ci] = chain_step(L.cs, a, y0.q);
        L.S = ext_x6_plant(L.S, v);
        L.n = L.n + 1;
        y = ext_x6_plant('meas', L.S);
        L.brake = ci.brake;
        if o.coll
            [L.coll, ~, ~, nd] = ext_x6_coll(K, y.q, CC, rb);
            L.nMesh = L.nMesh + nd;
        end
        e = L.pT - y.p;
        d = norm(e);
        sp = norm(y.v);
        pen = o.w_da * sum((a - L.aPrev) .^ 2) + o.w_brk * any(ci.brake) + o.w_base * norm(y.w_base) ...
              + o.w_stop * (d < 0.02) * sp / 0.05;
        if strcmp(o.reward, 'progress')
            r = phi(d) - phi(L.dPrev) - pen;
        else
            r = -o.w_lin * d + o.w_fine * exp(-d / 0.005) - pen;
        end
        L.dPrev = d;
        L.aPrev = a;
        if d <= o.tol && sp <= o.tol, L.hold = L.hold + 1; else, L.hold = 0; end
        done = false;
        L.d = d;
        if L.hold >= nHold
            r = r + o.r_succ; done = true; L.outcome = "success";
        elseif d > L.d0 + 0.4 || any(y.clamp) || L.coll
            r = r + o.r_fail; done = true;
            if L.coll, L.outcome = "coll"; elseif any(y.clamp), L.outcome = "clamp"; else, L.outcome = "ood"; end
        elseif L.n >= nMax
            done = true; L.outcome = "timeout";
        end
        obs = observe(y, L);
    end

    function f = phi(d)
        f = -o.w_lin * d / 0.01 + 20 * o.w_fine * exp(-d / 0.005);
    end

    function obs = observe(y, L)
        eb = y.Rb.' * (L.pT - y.p);
        q = y.q;
        if o.fine, fc = min(max(eb, -0.05), 0.05) * 20; else, fc = zeros(0, 1); end
        obs = [eb; fc; y.Rb.' * y.v / 0.5; ...
               sin(q([1 3 5 7])); cos(q([1 3 5 7])); q(fin) ./ qL; y.dq ./ P.v_cap; y.e_ori / 0.5; ...
               y.w_base / 0.5; (qL - abs(q(fin))) ./ qL; L.cs.v_prev ./ P.v_max; double(L.brake)];
    end
end
