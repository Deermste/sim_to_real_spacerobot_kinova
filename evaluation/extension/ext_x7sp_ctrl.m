function ctrl = ext_x7sp_ctrl(pol, pT, Tm, varargin)
%EXT_X7SP_CTRL  Set-Point-Regler plus gelernte Korrektur als ctrl-Funktion fuer ext_kinsim (X7-SP, 15.11.2026).
%   ctrl = ext_x7sp_ctrl(agentFile, pT, Tm)            Policy aus der Datei (Mittelwert)
%   ctrl = ext_x7sp_ctrl(@(obs40) delta6, pT, Tm, 'beta', 0, 'eps_v', 0.02, 'eps_w', 0.02, 'K', K)
%
%   Gleiche Rechnung wie ext_x7sp_env. Der Werkzeugpunkt ist p = ep + pref (Beobachtung plus Referenz).
%   Je Episode einen neuen ctrl erzeugen (Zustand der Kette).
%   Option 'gate' (Standard false): Korrektur mal ext_x7sp_gate(t, Tm) wie in ext_x7sp_env (X7.4).

p = inputParser;
p.addParameter('beta', 1);
p.addParameter('eps_v', 0.02);
p.addParameter('eps_w', 0.02);
p.addParameter('K', []);
p.addParameter('gate', false);
p.parse(varargin{:});
o = p.Results;
if ischar(pol) || isstring(pol), pol = ext_policy(char(pol)); end
[C, Knom] = ext_x7sp_setup();
if ~isempty(o.K), Knom = o.K; end
[c, api] = ext_x2_controller('mode', 'weighted', 'beta', o.beta, 'gamma', 0, 'Kp', 5, 'mu', 1e-4, ...
    'joints', 1:7, 'task', [1 2 3], 'K', Knom, 'invert', true, 'Ts_agent', C.Ts, 'lim', C.v_max, 'chainP', C);
pT = pT(:);
ctrl = @step;

    function u = step(obs, R)
        xc = api.propose(obs, R);
        p = obs(1:3) + R.pref;
        d = min(max(double(pol([obs; pT - p; xc(:) ./ C.v_max; min(R.t / Tm, 1)])), -1), 1);
        if o.gate, d = ext_x7sp_gate(R.t, Tm) * d; end
        R.db = o.eps_v * d(1:3);
        R.dw = o.eps_w * d(4:6);
        u = c(obs, R);
    end
end
