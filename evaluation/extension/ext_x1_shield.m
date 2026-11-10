function hook = ext_x1_shield(varargin)
%EXT_X1_SHIELD  Sicherheitsfilter auf die Basisdrehung (CBF), fuer ext_kinsim (Ausbau X1.4).
%   hook = ext_x1_shield('theta', 0.03, 'alpha', 1)
%   res = ext_kinsim(pol, 'cmdHook', hook, ...)                         Filter nach der Befehlskette
%   pw = ext_x1_shield('policy', pol, ...); res = ext_kinsim(pw, ...)   Filter vor der Kette (siehe unten)
%
%   Barrierefunktion h = theta^2 - phi^2 mit phi = Drehwinkel der Basis um die Achse der ebenen Aufgabe (y im
%   Weltsystem, Komponente des Drehvektors). Bedingung dh/dt >= -alpha h. Mit der verallgemeinerten Jacobi-Matrix
%   ist phi_dot = c' qd (c = y-Zeile von Rb G(4:6, :)), also eine lineare Ungleichung a' qd <= b mit a = 2 phi c,
%   b = alpha h. Ist sie verletzt, wird qd minimal (euklidisch, nur die aktiven Gelenke) auf die Grenze
%   projiziert. Ohne QP-Bibliothek, eine Ungleichung in geschlossener Form.
%   Der Filter rechnet mit seinem eigenen Modell 'K' (Standard nominal, 65 kg) aus der gemessenen Lage und den
%   Gelenkwinkeln, wie der Regler in X2. Er greift nach der Befehlskette ein ('after', Hook in ext_kinsim). Dann
%   kann er die Beschleunigungsgrenze des Rate Limiters verletzen. Mit 'policy' (Variante vor der Kette) wird
%   stattdessen die Rohaktion der Policy korrigiert, aus q und e_ori der Beobachtung. Die Kette bleibt dann
%   eingehalten, der Filter wirkt aber nur ueber Filter und Rate Limiter, also verzoegert.
%   Optionen: theta 0,03 rad, alpha 1 1/s, joints [2 4 6], axis 2 (y), K (ext_kin_model), lim (Saettigung der
%   aktiven Gelenke nach der Korrektur, Standard [0,9774 0,9774 0,9774]).
%   Der Hook zaehlt die Eingriffe: hook('count') liefert [Anzahl Schritte, davon korrigiert].

p = inputParser;
p.addParameter('theta', 0.03);
p.addParameter('alpha', 1);
p.addParameter('joints', [2 4 6]);
p.addParameter('axis', 2);
p.addParameter('K', []);
p.addParameter('lim', [0.9774 0.9774 0.9774]);
p.addParameter('policy', []);
p.parse(varargin{:});
o = p.Results;
if isempty(o.K), o.K = ext_kin_model(); end
nStep = 0; nAct = 0;
hook = @apply;
if ~isempty(o.policy), hook = @wrapped; end

    function a = wrapped(obs)
        if ischar(obs) && strcmp(obs, 'count')
            a = [nStep, nAct];
            return
        end
        nStep = nStep + 1;
        a0 = o.policy(obs);
        eo = obs(27:29);
        a = shieldStep(a0, obs(13:19), rotvecToRotm(eo), eo, o);
        if any(a ~= a0), nAct = nAct + 1; end
    end

    function out = apply(cmd, S)
        if ischar(cmd) && strcmp(cmd, 'count')
            out = [nStep, nAct];
            return
        end
        nStep = nStep + 1;
        out = shieldStep(cmd, S.q, rotvecToRotm(S.ori), S.ori, o);
        if any(out ~= cmd), nAct = nAct + 1; end
    end
end

% =====================================================================
function qd = shieldStep(qd, q, Rb, eo, o)
G = ext_kin_eval(o.K, q);
W = Rb * G(4:6, :);
a = o.joints;
c = W(o.axis, a).';
phi = eo(o.axis);
h = o.theta^2 - phi^2;
av = 2 * phi * c;
b = o.alpha * h;
x = qd(a);
v = av.' * x - b;
if v > 0 && av.' * av > 0
    x = x - v / (av.' * av) * av;
    x = min(max(x, -o.lim(:)), o.lim(:));
    qd(a) = x;
end
end

function Rm = rotvecToRotm(v)
th = norm(v);
if th < 1e-12
    Rm = eye(3) + [0 -v(3) v(2); v(3) 0 -v(1); -v(2) v(1) 0];
    return
end
k = v / th;
Kx = [0 -k(3) k(2); k(3) 0 -k(1); -k(2) k(1) 0];
Rm = eye(3) + sin(th) * Kx + (1 - cos(th)) * (Kx * Kx);
end
