function Q0 = ext_x0_perturbations(nPert, pertDeg, active)
%EXT_X0_PERTURBATIONS  Fester Satz von Startstellungen fuer das Auswerteprotokoll (X0.1).
%   Q0 = ext_x0_perturbations()            21 x 7: Zeile 1 nominal (null), Zeilen 2-21 gestoert
%   Q0 = ext_x0_perturbations(20, 2, [2 4 6])
%
%   Die Stoerung ist gleichverteilt in [-pertDeg, +pertDeg] Grad auf den aktiven Gelenken, die anderen bleiben
%   null. Die Zahlen kommen aus einem eigenen Zufallsstrom mit festem Seed. Damit ist der Satz fuer alle Agenten
%   gleich (gepaarter Vergleich) und unabhaengig vom globalen rng. Einheit von Q0: rad.
%   Ziehung k (k = 1..nPert) haengt nur von k ab, nicht von nPert. Ein kleinerer Satz ist also ein Anfang des
%   groesseren.

if nargin < 1 || isempty(nPert), nPert = 20; end
if nargin < 2 || isempty(pertDeg), pertDeg = 2; end
if nargin < 3 || isempty(active), active = [2 4 6]; end

SEED = 20261110;                        % fest, nicht aendern (sonst sind alte Auswertungen nicht mehr gepaart)
s = RandStream('mt19937ar', 'Seed', SEED);
U = rand(s, 7, max(nPert, 0)).';        % je Ziehung eine Zeile mit 7 Zahlen, auch fuer inaktive Gelenke
Q0 = zeros(nPert + 1, 7);
D = deg2rad(pertDeg) * (2 * U - 1);
Q0(2:end, active) = D(:, active);
end
