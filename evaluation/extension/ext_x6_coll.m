function [hit, dmin, D, need] = ext_x6_coll(K, q, C, rb)
%EXT_X6_COLL  Kollisionspruefung fuer die X6-Umgebung: Kapseln als Vorfilter, Meshes nur nahe an einer Kollision.
%   C  = ext_x6_coll('params', K)              Radien, Paarliste, Baender (K aus ext_kin_model mit tool_offset)
%   rb = ext_x6_coll('robot')                  rigidBodyTree mit Meshes und Greifer (wie ext_x6_pairs)
%   [hit, dmin, D, need] = ext_x6_coll(K, q, C)        nur Kapseln
%   [hit, dmin, D, need] = ext_x6_coll(K, q, C, rb)    Kapseln, bei need die Mesh-Pruefung (checkCollision)
%
%   Der Arm als Kette von Kapseln zwischen den Gelenkorten (Basissystem, Ursprung im Basis-Schwerpunkt, Basis als
%   Wuerfel mit Kantenlaenge 1 m um den Ursprung):
%     1 Montage [0 0 0,5] -> Gelenk 1    2 Gelenk 1 -> 2    3 2 -> 3    4 3 -> 4    5 4 -> 5    6 5 -> 6
%     7 6 -> 7    8 Gelenk 7 -> EE-Flansch    9 Greifer 2 bis 17 cm vor dem Flansch (wie ext_x6_pairs)
%   Geprueft werden die Kapselpaare in C.pairs (Abstand der Achsen minus beide Radien) und die Kapseln C.box gegen
%   den Basiswuerfel (11 Punkte je Kapsel, Abstand zum Wuerfel minus Radius). D enthaelt alle Abstaende (erst die
%   Paare, dann die Kapseln gegen den Wuerfel), dmin = min(D).
%   Die Kapseln allein trennen nicht scharf genug (ext_x6_coll_check, 4000 Stellungen): Paare mit einem Glied
%   dazwischen haben am gemeinsamen Gelenk einen festen Grundabstand (Kapsel 1 gegen 3 immer 13,5 mm), und die
%   Form von Schulter und Ellbogen weicht von einer Kapsel ab. Deshalb
%     need = any(D < C.band),  C.band = min(2 cm, Grundabstand - 5 mm)  (Grundabstand = Median ueber 200
%     Zufallsstellungen, Seed 7), fuer die Kapseln gegen den Wuerfel 4 cm
%   Ohne need gilt die Stellung als frei. Mit need und rb entscheidet checkCollision (Paare Eltern-Kind
%   ausgenommen), ohne rb gilt hit = need. Ausgelassen sind die Paare 5-7, 6-8, 7-9 (kurze Handgelenkglieder,
%   Kapseln ueberlappen immer).

if ischar(K)
    switch K
        case 'params'
            hit = params(q);
        case 'robot'
            hit = collisionRobot();
    end
    return
end
[pj, pf, Rf] = joints(K, q);
c = [[0; 0; 0.5], pj, pf];
s0 = c(:, 1:8); s1 = c(:, 2:9);
s0(:, 9) = pf + Rf * [0; 0; 0.02];
s1(:, 9) = pf + Rf * [0; 0; 0.17];
np = size(C.pairs, 1);
nb = numel(C.box);
D = zeros(np + nb, 1);
for k = 1:np
    a = C.pairs(k, 1); b = C.pairs(k, 2);
    D(k) = segDist(s0(:, a), s1(:, a), s0(:, b), s1(:, b)) - C.r(a) - C.r(b);
end
w = linspace(0, 1, C.nBox);
for k = 1:nb
    a = C.box(k);
    P = s0(:, a) + (s1(:, a) - s0(:, a)) .* w;
    e = abs(P) - 0.5;
    out = vecnorm(max(e, 0), 2, 1);
    ins = min(max(e, [], 1), 0);
    D(np + k) = min(out + ins) - C.r(a);
end
dmin = min(D);
need = any(D < C.band);
hit = need;
if need && nargin > 3
    hit = any(checkCollision(rb, q, 'SkippedSelfCollisions', 'parent'));
end
end

% =====================================================================
function C = params(K)
C.r = [0.06; 0.06; 0.055; 0.05; 0.05; 0.045; 0.045; 0.045; 0.045];
[i, j] = find(triu(ones(9), 2));
pr = [i, j];
pr = pr(~ismember(pr, [5 7; 6 8; 7 9], 'rows'), :);
C.pairs = pr;
C.box = (3:9).';
C.nBox = 11;
C.band = -inf(size(pr, 1) + numel(C.box), 1);
Cp = chain_step('params');
fin = isfinite(Cp.q_lim);
qS = pi * ones(7, 1);
qS(fin) = Cp.q_lim(fin) - deg2rad(5);
rs = RandStream('mt19937ar', 'Seed', 7);
Q = (2 * rand(rs, 7, 200) - 1) .* qS;
Dn = zeros(numel(C.band), 200);
for k = 1:200
    [~, ~, Dn(:, k)] = ext_x6_coll(K, Q(:, k), C);
end
C.nominal = median(Dn, 2);
C.band = min(0.02, C.nominal - 0.005);
C.band(size(pr, 1) + 1:end) = 0.04;   % gegen den Wuerfel breiter (Bracelet mit Kamera dicker als 4,5 cm, Seed 8)
end

function rb = collisionRobot()
% wie ext_x6_pairs: Meshes der URDF, Basiswuerfel, Greifer als Zylinder r 4,5 cm von 2 bis 17 cm vor dem Flansch
rb = importrobot(sk_path('robot', 'SpaceKinova.urdf'), 'DataFormat', 'column', 'MeshPath', {sk_path()});
g = rigidBody('gripper');
c = collisionCylinder(0.045, 0.15);
c.Pose = trvec2tform([0 0 0.095]);
addCollision(g, c);
addBody(rb, g, 'kinova_end_effector_link');
end

% =====================================================================
function [pj, pf, Rf] = joints(K, q)
% Gelenkorte und EE-Flansch im Basissystem, gleiche Rechnung wie ext_kin_eval
nb = K.nb;
R = zeros(3, 3, nb); P = zeros(3, nb);
pj = zeros(3, 7);
for i = K.order
    pa = K.parent(i);
    if pa == 0
        Rp = eye(3); Pp = zeros(3, 1);
    else
        Rp = R(:, :, pa); Pp = P(:, pa);
    end
    Tjp = K.Tjp(:, :, i);
    Rj = Rp * Tjp(1:3, 1:3);
    Pj = Pp + Rp * Tjp(1:3, 4);
    j = K.jidx(i);
    if j > 0
        pj(:, j) = Pj;
        Rj = Rj * axang(K.axis(:, i), q(j));
    end
    Tcj = K.Tcj(:, :, i);
    R(:, :, i) = Rj * Tcj(1:3, 1:3);
    P(:, i) = Pj + Rj * Tcj(1:3, 4);
end
pf = P(:, K.ee); Rf = R(:, :, K.ee);
end

function d = segDist(p1, q1, p2, q2)
% kleinster Abstand zweier Strecken (Ericson, Real-Time Collision Detection, 5.1.9)
d1 = q1 - p1; d2 = q2 - p2; r = p1 - p2;
a = d1.' * d1; e = d2.' * d2; f = d2.' * r;
c = d1.' * r; b = d1.' * d2; den = a * e - b * b;
if den > 1e-12, s = min(max((b * f - c * e) / den, 0), 1); else, s = 0; end
t = (b * s + f) / e;
if t < 0
    t = 0; s = min(max(-c / a, 0), 1);
elseif t > 1
    t = 1; s = min(max((b - c) / a, 0), 1);
end
d = norm(p1 + d1 * s - p2 - d2 * t);
end

function Rm = axang(a, th)
c = cos(th); s = sin(th); C = 1 - c;
x = a(1); y = a(2); w = a(3);
Rm = [c + x*x*C,   x*y*C - w*s, x*w*C + y*s;
      y*x*C + w*s, c + y*y*C,   y*w*C - x*s;
      w*x*C - y*s, w*y*C + x*s, c + w*w*C];
end
