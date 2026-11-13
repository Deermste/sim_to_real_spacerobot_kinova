function K = ext_kin_model(varargin)
%EXT_KIN_MODEL  Kinematik- und Massenmodell des frei schwebenden Systems fuer ext_kin_eval (X0.2).
%   K = ext_kin_model()                                  Nominalwerte (URDF, Basis 65 kg)
%   K = ext_kin_model('base_mass', 32.5, 'link_mass_scale', 1.2, 'mount_offset', [0.05 0 0])
%
%   Quelle ist robot/SpaceKinova.urdf wie in desktop_freefloat (D15). Die Wurzel base_link ist die Basis
%   (Wuerfel 1 m, Schwerpunkt im Ursprung). Ihre Masse und Traegheit werden getrennt gesetzt:
%   I0 = 10,833 kg m^2 * base_mass / 65 wie in SK_desktop (desktop_build_model). Je Koerper werden die festen
%   Transformationen, die Gelenkachse, Masse, Schwerpunkt und Traegheit um den Schwerpunkt abgelegt, damit
%   ext_kin_eval ohne rigidBodyTree-Aufrufe auskommt.
%   Optionen:
%     base_mass        Basismasse [kg], Standard 65
%     base_inertia     Traegheit der Basis [kg m^2] (Skalar fuer alle Achsen), Standard 10,833*base_mass/65
%     link_mass_scale  Faktor auf Masse und Traegheit aller Armglieder, Standard 1
%     mount_offset     3x1 Verschiebung des Arms auf der Basis [m] (im Basissystem), Standard null
%     ee               Name des Endeffektor-Frames, Standard kinova_end_effector_link
%     tool_offset      3x1 Werkzeugpunkt im EE-Frame [m], Standard null. X6: [0; 0; 0,121] (Greiferspitze wie
%                      tool_pose der Kortex-API, kortex_frames)

p = inputParser;
p.addParameter('base_mass', 65);
p.addParameter('base_inertia', []);
p.addParameter('link_mass_scale', 1);
p.addParameter('mount_offset', [0 0 0]);
p.addParameter('ee', 'kinova_end_effector_link');
p.addParameter('tool_offset', [0; 0; 0]);
p.parse(varargin{:});
o = p.Results;
if isempty(o.base_inertia), o.base_inertia = 10.833 * o.base_mass / 65; end

robot = importrobot(sk_path('robot', 'SpaceKinova.urdf'), 'DataFormat', 'column');
nb = robot.NumBodies;
names = cellfun(@(b) b.Name, robot.Bodies, 'UniformOutput', false);
K = struct();
K.nb = nb;
K.names = names;
K.parent = zeros(nb, 1);
K.jidx = zeros(nb, 1);              % Index im Gelenkvektor, 0 = fest
K.Tjp = zeros(4, 4, nb);            % JointToParentTransform
K.Tcj = zeros(4, 4, nb);            % ChildToJointTransform
K.axis = zeros(3, nb);
K.mass = zeros(nb, 1);
K.com = zeros(3, nb);               % Schwerpunkt im Koerpersystem
K.Ic = zeros(3, 3, nb);             % Traegheit um den Schwerpunkt im Koerpersystem
nj = 0;
for i = 1:nb
    b = robot.Bodies{i};
    pn = b.Parent.Name;
    ip = find(strcmp(names, pn), 1);
    if isempty(ip) || strcmp(pn, robot.BaseName), ip = 0; end
    K.parent(i) = ip;
    if ~strcmp(b.Joint.Type, 'fixed')
        assert(strcmp(b.Joint.Type, 'revolute'), 'ext_kin_model:joint', 'Nur Drehgelenke erwartet');
        nj = nj + 1;
        K.jidx(i) = nj;
        K.axis(:, i) = b.Joint.JointAxis(:);
    end
    K.Tjp(:, :, i) = b.Joint.JointToParentTransform;
    K.Tcj(:, :, i) = b.Joint.ChildToJointTransform;
    m = b.Mass * o.link_mass_scale;
    c = b.CenterOfMass(:);
    In = b.Inertia * o.link_mass_scale;             % [Ixx Iyy Izz Iyz Ixz Ixy] um den Koerper-Ursprung
    Ib = [In(1) In(6) In(5); In(6) In(2) In(4); In(5) In(4) In(3)];
    K.mass(i) = m;
    K.com(:, i) = c;
    K.Ic(:, :, i) = Ib - m * (c.' * c * eye(3) - c * c.');
end
assert(nj == 7, 'ext_kin_model:nj', 'Erwartet 7 Gelenke, gefunden %d', nj);
% Arm auf der Basis verschieben: alle Kinder der Wurzel
for i = find(K.parent == 0).'
    K.Tjp(1:3, 4, i) = K.Tjp(1:3, 4, i) + o.mount_offset(:);
end
K.ee = find(strcmp(names, o.ee), 1);
K.tool = o.tool_offset(:);
K.m0 = o.base_mass;
K.I0 = o.base_inertia * eye(3);
K.opts = o;
% Nur Koerper mit Masse oder auf dem Weg zum Endeffektor werden gebraucht
need = K.mass > 0;
i = K.ee;
while i > 0, need(i) = true; i = K.parent(i); end
K.order = find(need).';             % Reihenfolge der URDF ist topologisch (Eltern vor Kindern)
end
