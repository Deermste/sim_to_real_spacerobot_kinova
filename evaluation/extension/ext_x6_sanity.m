function out = ext_x6_sanity(varargin)
%EXT_X6_SANITY  Plausibilitaetstest fuer die X6-Trainingskette (nach dem Pilot X6.3): lernt PPO die leichte Aufgabe?
%   out = ext_x6_sanity()                       Standard: 5000 Episoden oder 45 min
%   out = ext_x6_sanity('maxEpisodes', 32, 'chunk', 16, 'tag', 'test')
%
%   Ein fester Start (erster Laborstart, q aus setpoint_starts.mat), Ziele 5 bis 15 cm vom Start in zufaelliger
%   Richtung (Seed 11, 500 Trainings- und 100 Auswerteziele), ohne Kollisionspruefung, eine Stufe mit tol 2 cm.
%   Sonst alles wie ext_x6_pilot Variante a (Reward 'progress', PPO, Kette E18 20 Hz).
%   Erster Lauf (14.11., Label sanity) mit w_stop 0,2: Endfehler fast ueberall 25 mm (Bremsterm innerhalb 2 cm).
%   Zweiter Lauf (Label sanity2) mit w_stop 0: Endabstand 1 bis 3 mm, aber Pendeln mit 25 bis 50 mm/s, 0 %.
%   Dritter Lauf (Label sanity3) mit w_v 0,05 und w_dq 0,02 (Standard in ext_x6_pilot).
%   Vierter Lauf (sanity4): ext_x6_sanity('label', 'sanity4', 'w_v', 0,2, 'w_dq', 0,05, 'w_da', 0,1).
%   SAC (14.11.): ext_x6_sanity('algo', 'sac', 'label', 'sanity_sac', 'chunk', 100)
%                 ext_x6_sanity('algo', 'sac_her', 'label', 'sanity_her', 'chunk', 100)
%   Lernt der Agent das nicht, liegt der Fehler im Aufbau (Umgebung, Agent, Optionen) und nicht in der
%   Schwierigkeit der Aufgabe.

p = inputParser;
p.addParameter('maxEpisodes', 5000);
p.addParameter('maxHours', 0.75);
p.addParameter('chunk', 500);
p.addParameter('tag', '');
p.addParameter('label', 'sanity3');
p.addParameter('w_stop', 0);
p.addParameter('w_v', 0.05);
p.addParameter('w_dq', 0.02);
p.addParameter('w_da', 0.01);
p.addParameter('algo', 'ppo');      % 'ppo' (ext_x6_pilot), 'sac' oder 'sac_her' (ext_x6_sac, seit 14.11.)
p.addParameter('w_in', 1);          % nur sac_her
p.parse(varargin{:});
o = p.Results;
setup_project;
S = load(sk_path('hardware', 'campaign', 'setpoint_starts.mat'));
q0 = deg2rad(S.S.starts(1).q_deg(:));
K = ext_kin_model('tool_offset', [0; 0; 0.121]);
[~, p0] = ext_kin_eval(K, q0);
rs = RandStream('mt19937ar', 'Seed', 11);
n = 600;
u = randn(rs, 3, n); u = u ./ vecnorm(u);
r = 0.05 + 0.10 * rand(rs, 1, n);
P = struct('q0', repmat({q0}, 1, n), 'pT', num2cell(p0 + u .* r, 1), 'id', num2cell(1:n));
pools = struct('train', P(1:500), 'eval', P(501:600));
fprintf('Start %s Grad, Werkzeugpunkt %s m\n', mat2str(round(rad2deg(q0.'))), mat2str(round(p0.', 3)));
if ~strcmp(o.algo, 'ppo')
    % SAC (E14-Rueckfall): Gewichte fest wie sanity3 (w_v 0,05, w_dq 0,02, w_da 0,01), tol 2 cm
    out = ext_x6_sac(pools, 'her', strcmp(o.algo, 'sac_her'), 'maxEpisodes', o.maxEpisodes, ...
                     'maxHours', o.maxHours, 'chunk', o.chunk, 'nEval', 100, 'nCur', 48, 'tol', 0.02, ...
                     'w_in', o.w_in, 'label', o.label, 'tag', o.tag);
    return
end
out = ext_x6_pilot('a', 0, 'pools', pools, 'levels', struct('tol', 0.02, 'dcap', Inf), 'pFull', 0, ...
                   'envExtra', {'coll', false}, 'maxEpisodes', o.maxEpisodes, 'maxHours', o.maxHours, ...
                   'chunk', o.chunk, 'nEval', 100, 'nCur', 48, 'label', o.label, 'tag', o.tag, 'w_stop', o.w_stop, ...
                   'w_v', o.w_v, 'w_dq', o.w_dq, 'w_da', o.w_da);
end
