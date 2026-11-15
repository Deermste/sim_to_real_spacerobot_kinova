function ctrl = ext_x7_ctrl(pol, varargin)
%EXT_X7_CTRL  Regler plus gelernte Korrektur als ctrl-Funktion fuer ext_kinsim (X7, 15.11.2026).
%   ctrl = ext_x7_ctrl(agentFile)                    Policy aus der Datei (ext_policy, Mittelwert)
%   ctrl = ext_x7_ctrl(@(obs32) delta3)              eigene Korrektur (Tests)
%   ctrl = ext_x7_ctrl(pol, 'eps_v', 0.02, 'eps_w', 0.01, 'ctrlArgs', {...})
%   res = ext_kinsim([], 'ctrl', ctrl, 'j6_lim', 0.9774, 'reward_mode', 4)
%
%   Gleiche Rechnung wie ext_x7_env: Vorschlag xc ohne Korrektur (api.propose) fuer die Beobachtung
%   [obs; xc / 0,9774], Delta der Policy auf [-1, 1] begrenzt, dann der Regler mit db = eps_v Delta(1:2) und
%   dw = [0; eps_w Delta(3); 0]. Je Episode einen neuen ctrl erzeugen (Zustand der Kette).
%   ctrlArgs wie ext_x7_env (Standard Rbeta 21,5, J6-Seite -, Nominalmodell, Inversion).

p = inputParser;
p.addParameter('eps_v', 0.02);
p.addParameter('eps_w', 0.01);
p.addParameter('ctrlArgs', {});
p.addParameter('K', []);
p.parse(varargin{:});
o = p.Results;
if ischar(pol) || isstring(pol), pol = ext_policy(char(pol)); end
K = o.K;
if isempty(K), K = ext_kin_model(); end
cArgs = o.ctrlArgs;
if isempty(cArgs), cArgs = {'beta', 21.544, 'j6_side', -1}; end
cArgs = [{'j6_lim', 0.9774, 'invert', true, 'K', K}, cArgs];
[c, api] = ext_x2_controller(cArgs{:});
ctrl = @step;

    function u = step(obs, R)
        xc = api.propose(obs, R);
        d = min(max(double(pol([obs; xc / 0.9774])), -1), 1);
        R.db = o.eps_v * d(1:2);
        R.dw = [0; o.eps_w * d(3); 0];
        u = c(obs, R);
    end
end
