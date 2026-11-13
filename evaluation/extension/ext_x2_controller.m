function ctrl = ext_x2_controller(varargin)
%EXT_X2_CONTROLLER  Modellbasierter Bahnregler mit Basisminimierung fuer ext_kinsim (Ausbau X2.1).
%   ctrl = ext_x2_controller()                      R0: Resolved-Rate auf der verallgemeinerten Jacobi-Matrix
%   ctrl = ext_x2_controller('beta', 10)            Rbeta, gewichtete Form (erweiterte Aufgabe)
%   ctrl = ext_x2_controller('mode', 'priority')    Bahn zuerst, dann Basis bei gleicher EE-Geschwindigkeit
%   res = ext_kinsim([], 'ctrl', ctrl, 'j6_lim', 0.9774, 'chain', 'sat')
%
%   Der Regler sieht dasselbe wie die Policy: die Beobachtung (q, Basislage als Drehvektor, EE-Fehler ep im
%   Weltsystem) und dazu die Referenzgeschwindigkeit. Die Jacobi-Matrizen rechnet er mit seinem eigenen Modell
%   'K' (Standard nominal, 65 kg). Damit laesst sich in X2.3 ein falsches Modell einsetzen, waehrend die
%   Strecke in ext_kinsim ein anderes K hat. Je Agentenschritt (x = Geschwindigkeiten der aktiven Gelenke):
%     A = P Rb Je(:, a)       EE-Geschwindigkeit in der Ebene (P waehlt x und z), a = aktive Gelenke
%     W = Rb G(4:6, a)        Basis-Winkelgeschwindigkeit im Weltsystem
%     b = P (vref - Kp ep)    gewuenschte EE-Geschwindigkeit
%     w* = -kOri e_ori        gewuenschte Basis-Winkelgeschwindigkeit (Standard kOri = 0, also w* = 0)
%   Schranken l <= x <= u: Geschwindigkeitsgrenzen 'lim' (J2, J4 0,9774, J6 j6_lim rad/s), Gelenkwinkel
%   (qLim wie im Modell, x so begrenzt, dass q + horizon * x in den Grenzen bleibt) und mit 'invert' der
%   Rate Limiter (Ausgang der Kette hoechstens slew * Ts_agent vom jetzigen Stand entfernt).
%   mode 'weighted' (Standard): x = argmin |A x - b|^2 + beta |W x - w*|^2 + mu |x|^2 unter den Schranken.
%     beta = 0 ist R0 (gedaempfte Pseudoinverse mit Schranken). Grosses beta naehert die reaktionsfreie Bewegung
%     (Reaction Null Space, Nenchev u. a. 1999), soweit die Schranken es zulassen.
%   mode 'priority': (1) x1 = argmin |A x - b|^2 + mu |x|^2, (2) x = argmin |W x - w*|^2 + mu |x|^2 mit
%     A x = A x1, beide unter den Schranken. Das ist min_rot aus D15 (desktop_d15_base_rotation).
%   invert (Standard false): Der Regler kennt die Befehlskette (Filter y = 0,95 y + 0,05 u, Rate Limiter) und
%     waehlt u so, dass ihr Ausgang x erreicht, soweit Saettigung und Rate Limiter es zulassen. Dafuer fuehrt er
%     die Kette intern mit (Zustand je Episode, Reset bei R.t = 0). Fuer chain 'full' in ext_kinsim.
%   j6_side 0 (frei), -1 oder +1: Der Regler haelt J6 auf einer Seite (q6 <= 0 oder >= 0). Die Loesung haengt
%     stark davon ab, in welche Richtung J6 laeuft (zwei Zweige, 10.11.2026), das legt diese Option fest.
%   Optionen: beta 0, mode 'weighted', Kp 5 1/s (wie D15), kOri 0 1/s, joints [2 4 6], task [1 3], mu 1e-8,
%   j6_lim 0,9774, horizon 0,1 s, invert false, slew 0,5, Ts_agent 0,025, j6_side 0, K (ext_kin_model),
%   lim 7x1 Geschwindigkeitsgrenzen (Standard [], dann wie oben aus j6_lim). Fuer X5 mit joints 1:7 und
%   task [1 2 3] dieselben Grenzen wie in ext_kinsim 'lim' angeben.
%   chainP (Standard []): Parameter der neuen Kette chain_step (X6, E18), nur mit invert. Der Regler haelt
%     dann die Beschleunigungsgrenze und die Bremskurve ein und gibt die Aktion x ./ v_max aus. lim auf
%     chainP.v_max setzen.
%   filt_a (Standard 0,95): Koeffizient des Befehlsfilters, den der Regler mit invert kennt (X4.6 V3: 0,85, dann
%   in ext_kinsim dasselbe filt_a angeben).

p = inputParser;
p.addParameter('beta', 0);
p.addParameter('mode', 'weighted');
p.addParameter('Kp', 5);
p.addParameter('kOri', 0);
p.addParameter('joints', [2 4 6]);
p.addParameter('task', [1 3]);
p.addParameter('mu', 1e-8);
p.addParameter('j6_lim', 0.9774);
p.addParameter('horizon', 0.1);
p.addParameter('invert', false);
p.addParameter('slew', 0.5);
p.addParameter('Ts_agent', 0.025);
p.addParameter('j6_side', 0);
p.addParameter('K', []);
p.addParameter('lim', []);
p.addParameter('filt_a', 0.95);
p.addParameter('chainP', []);
p.parse(varargin{:});
o = p.Results;
assert(ismember(o.mode, {'weighted', 'priority'}), 'ext_x2_controller:mode', 'mode ist weighted oder priority');
if isempty(o.K), o.K = ext_kin_model(); end
lim7 = [0; 0.9774; 0; 0.9774; 0; o.j6_lim; 0];
if ~isempty(o.lim), lim7 = o.lim(:); end
qLim = [2*pi; 2.41; 2*pi; 2.66; 2.23; 2.01; 2*pi];
qLo = -qLim; qHi = qLim;
if o.j6_side < 0, qHi(6) = 0; end
if o.j6_side > 0, qLo(6) = 0; end
a = o.joints;
P = eye(3);
o.P = P(o.task, :);
o.qp = optimoptions('lsqlin', 'Display', 'off', 'Algorithm', 'interior-point');
d = o.slew * o.Ts_agent;
x6 = ~isempty(o.chainP);                     % neue Kette chain_step (X6, E18): nur Beschleunigungsgrenze invertieren
if x6
    assert(o.invert, 'ext_x2_controller:x6', 'chainP nur mit invert');
    d = o.chainP.a_max * o.chainP.Ts;
end
yf = zeros(7, 1); yr = zeros(7, 1);           % interne Kopie der Befehlskette (invert)
ctrl = @step;

    function u = step(obs, R)
        if R.t == 0, yf(:) = 0; yr(:) = 0; end
        q = obs(13:19);
        lo = max(-lim7(a), (qLo(a) - q(a)) / o.horizon);
        hi = min(lim7(a), (qHi(a) - q(a)) / o.horizon);
        if o.invert
            lo = max(lo, yr(a) - d);
            hi = min(hi, yr(a) + d);
        end
        if x6                                   % Bremskurve der Kette als Schranke (wie chain_step Stufe 2)
            cp = o.chainP;
            fin = isfinite(cp.q_lim(a));
            vUp = sqrt(2 * cp.a_brake * max(cp.q_lim(a) - cp.q_margin - q(a), 0));
            vLo = sqrt(2 * cp.a_brake * max(q(a) + cp.q_lim(a) - cp.q_margin, 0));
            hi(fin) = min(hi(fin), vUp(fin));
            lo(fin) = max(lo(fin), -vLo(fin));
        end
        hi = max(hi, lo);
        x = law(obs, R, o, lo, hi);
        u = zeros(7, 1);
        u(a) = x;
        if ~o.invert, return; end
        if x6
            yr(a) = x;                          % Ausgang der Kette, wenn die Bremskurve nicht eingreift
            u = zeros(7, 1);
            u(a) = x ./ o.chainP.v_max(a);      % Aktion in [-1, 1], chain_step skaliert mit v_max
            return
        end
        target = yr + min(max(u - yr, -d), d);  % was der Rate Limiter im naechsten Schritt erlaubt
        if o.filt_a == 0.95
            u = (target - 0.95 * yf) / 0.05;    % Filter invertieren (wie bisher, bitgleich)
            u = min(max(u, -lim7), lim7);
            yf = 0.95 * yf + 0.05 * u;          % Kette mitfuehren wie in ext_kinsim
        else
            u = (target - o.filt_a * yf) / (1 - o.filt_a);
            u = min(max(u, -lim7), lim7);
            yf = o.filt_a * yf + (1 - o.filt_a) * u;
        end
        yr = yr + min(max(yf - yr, -d), d);
    end
end

% =====================================================================
function x = law(obs, R, o, lo, hi)
q = obs(13:19);
ep = obs(1:3);
eo = obs(27:29);
Rb = rotvecToRotm(eo);
[G, ~, Je] = ext_kin_eval(o.K, q);
a = o.joints;
n = numel(a);
A = o.P * Rb * Je(:, a);
W = Rb * G(4:6, a);
b = o.P * (R.vref - o.Kp * ep);
wDes = -o.kOri * eo;
rm = sqrt(o.mu) * eye(n);
if strcmp(o.mode, 'weighted')
    rb = sqrt(o.beta);
    x = boxLsq([A; rb * W; rm], [b; rb * wDes; zeros(n, 1)], lo, hi);
else
    x1 = boxLsq([A; rm], [b; zeros(n, 1)], lo, hi);
    x = x1;
    try
        x2 = lsqlin([W; rm], [wDes; zeros(n, 1)], [], [], A, A * x1, lo, hi, [], o.qp);
        if all(isfinite(x2)), x = x2; end
    catch
    end
end
end

function x = boxLsq(C, dv, lo, hi)
% min |C x - dv|^2 unter lo <= x <= hi, exakt durch Aufzaehlen der aktiven Mengen (n <= 4), sonst lsqlin
n = size(C, 2);
x = C \ dv;
if all(x >= lo - 1e-12 & x <= hi + 1e-12), return; end
if n > 4
    x = lsqlin(C, dv, [], [], [], [], lo, hi, [], optimoptions('lsqlin', 'Display', 'off'));
    return
end
best = Inf;
for code = 0:3^n - 1
    s = mod(floor(code ./ 3 .^ (0:n - 1)), 3).';    % 0 frei, 1 unten, 2 oben
    y = zeros(n, 1);
    y(s == 1) = lo(s == 1);
    y(s == 2) = hi(s == 2);
    f = s == 0;
    if any(f)
        y(f) = C(:, f) \ (dv - C(:, ~f) * y(~f));
        if any(y(f) < lo(f) - 1e-12 | y(f) > hi(f) + 1e-12), continue; end
    end
    v = norm(C * y - dv)^2;
    if v < best, best = v; x = y; end
end
end

function Rm = rotvecToRotm(v)
% Drehvektor -> Drehmatrix (Rodrigues), wie die Basislage in ext_kinsim
th = norm(v);
if th < 1e-12
    Rm = eye(3) + skew(v);
    return
end
k = v / th;
Kx = skew(k);
Rm = eye(3) + sin(th) * Kx + (1 - cos(th)) * (Kx * Kx);
end

function S = skew(v)
S = [0 -v(3) v(2); v(3) 0 -v(1); -v(2) v(1) 0];
end
