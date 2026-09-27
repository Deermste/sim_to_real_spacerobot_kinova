function [G, Je, pe] = desktop_freefloat(robot, q, m0, I0, ee)
%DESKTOP_FREEFLOAT  Verallgemeinerte Jacobi-Matrix des frei schwebenden Systems (D15, Befund A51).
%   [G, Je, pe] = desktop_freefloat(robot, q, m0, I0, ee)
%
%   robot  rigidBodyTree aus robot/SpaceKinova.urdf (importrobot, DataFormat 'column'). Die Basis ist die Wurzel
%          des Baums, ihre Masse m0 und Traegheit I0 (um den Schwerpunkt im Ursprung) werden getrennt uebergeben.
%   Anfangsimpuls null, keine aeusseren Kraefte (Schwerkraft im Modell [0 0 0]). Alles im
%   Basis-Koordinatensystem mit Ursprung im Basis-Schwerpunkt (Umetani und Yoshida).
%   G   6x7, Basis-Twist [v0; w0] = G * qd
%   Je  3x7, Endeffektor-Geschwindigkeit (Basisbewegung eingerechnet) = Je * qd
%   pe  3x1, Endeffektor-Position

M = m0; mr = zeros(3, 1); Hw = I0; JTw = zeros(3, 7); Hwq = zeros(3, 7);
for i = 1:robot.NumBodies
    b = robot.Bodies{i};
    if b.Mass <= 0, continue; end
    Tb = getTransform(robot, q, b.Name);
    Rb = Tb(1:3, 1:3); pb = Tb(1:3, 4);
    c = b.CenterOfMass(:);
    r = pb + Rb * c;
    In = b.Inertia;                                    % [Ixx Iyy Izz Iyz Ixz Ixy] um den Koerper-Ursprung
    Ib = [In(1) In(6) In(5); In(6) In(2) In(4); In(5) In(4) In(3)];
    Ic = Ib - b.Mass * (c.' * c * eye(3) - c * c.');   % auf den Schwerpunkt verschoben
    Iw = Rb * Ic * Rb.';
    J = geometricJacobian(robot, q, b.Name);           % [w; v] des Koerper-Ursprungs
    Jw = J(1:3, :); Jv = J(4:6, :);
    JT = Jv - skew(r - pb) * Jw;
    M = M + b.Mass;
    mr = mr + b.Mass * r;
    Hw = Hw + Iw - b.Mass * skew(r) * skew(r);
    JTw = JTw + b.Mass * JT;
    Hwq = Hwq + Iw * Jw + b.Mass * skew(r) * JT;
end
Hb = [M * eye(3), -skew(mr); skew(mr), Hw];
Hbm = [JTw; Hwq];
G = -Hb \ Hbm;
Te = getTransform(robot, q, ee);
pe = Te(1:3, 4);
J = geometricJacobian(robot, q, ee);
Je = G(1:3, :) - skew(pe) * G(4:6, :) + J(4:6, :);
end

function S = skew(v)
S = [0 -v(3) v(2); v(3) 0 -v(1); -v(2) v(1) 0];
end
