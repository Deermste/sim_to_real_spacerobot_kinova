function plan = campaign_plan()
%CAMPAIGN_PLAN  Einzige Quelle fuer die Bedingungen der Messkampagne 2026.
%   plan = CAMPAIGN_PLAN() liefert
%     plan.tracking : Struct-Array der Tracking-Bedingungen (deploy_tracking_v24)
%     plan.timing   : Struct-Array der Timing-Messungen (measure_loop_timing)
%     plan.order    : empfohlene Reihenfolge der Laeufe (Zelle mit {condId, Wiederholung})
%     plan.setpoint : Struct-Array der Set-Point-Bedingungen (deploy_setpoint_v24)
%     plan.orderSetpoint : Reihenfolge der Set-Point-Laeufe {condId, startId, Wiederholung}.
%                     Die Startposen stehen in hardware/campaign/setpoint_starts.mat
%                     (make_setpoint_starts).
%     plan.day2       : Labortag 2 (Ablauf in ANLEITUNG_LABOR_TAG2.md)
%                     .timing   Reihenfolge {condId, Wiederholung} der neuen Timing-Messungen
%                     .tracking Reihenfolge {condId, Wiederholung} der r4/r0-Tracking-Laeufe
%                     .setpoint Reihenfolge {condId, targetId, startId, Wiederholung}
%                     .trackingExt  Erweiterung: zweiter r4-Seed {condId, Wiederholung}
%                     .trackingQuiet  Erweiterung: r4-Agent mit ruhiger Basis {condId, Wiederholung}
%                     .setpointAll  Erweiterung: Plugin-Ziele von allen 15 Starts
%                                   {condId, targetId, startId, Wiederholung}
%                     Die Ziele stehen in hardware/campaign/setpoint_targets.mat
%                     (make_setpoint_targets).
%   Die Auswertung (evaluation/campaign/analyze_campaign.py) gruppiert nach condId.
%   Beschreibung, Begruendung und Ablauf stehen in hardware/campaign/MESSPLAN.md.
%
%   Bedingungen nur ergaenzen, nie umbenennen: condId steht in Dateinamen und Logs.

a10  = 'SavedAgents/MotionProfile/Circle/PPO/ppo_10hz.mat';
aCdr = 'SavedAgents/MotionProfile/CDR/PPO/CDR2-4.mat';
aPpo = 'SavedAgents/MotionProfile/Circle/PPO/SpaceKinova_PPO_agent_motionprofile.mat';
% Labortag 2: Neutraining aus Sec. V (D16), J6-Grenze 0.9774 rad/s. Auswahl vorab nach Regel: je Gruppe
% der Seed mit dem mittleren deterministischen EE-MSE in der Simulation (D16_eval_20260927_102655 und
% _133923). r4 3000 Episoden: Seeds 0-7, Median zwischen s7 und s4, gewaehlt s7, s4 als Erweiterung.
% r4 und r0 1000 Episoden: Seeds 0-2, Median s2 (r4) und s0 (r0).
aR4k3 = 'SavedAgents/MotionProfile/D16/D16_ppo_40hz_r4_seed7_ep3000.mat';
aR4k3b = 'SavedAgents/MotionProfile/D16/D16_ppo_40hz_r4_seed4_ep3000.mat';
% Ruhige Gruppe aus D17 (D17_eval_20260928_144737): von den acht D16-Seeds der mit der kleinsten
% Basisdrehung (s1, 0,023 rad, RMS 21,5 mm). s7 und s4 liegen in der unruhigen Gruppe (0,060 und 0,049 rad).
aR4k3q = 'SavedAgents/MotionProfile/D16/D16_ppo_40hz_r4_seed1_ep3000.mat';
aR4k1 = 'SavedAgents/MotionProfile/D16/D16_ppo_40hz_r4_seed2.mat';
aR0k1 = 'SavedAgents/MotionProfile/D16/D16_ppo_40hz_r0_seed0.mat';

t = struct('condId', {}, 'agentFile', {}, 'agentLabel', {}, 'rateHz', {}, ...
           'pathDuration', {}, 'cmdScale', {}, 'referenceTiming', {}, ...
           'nRepetitions', {}, 'priority', {}, 'purpose', {}, 'j6Lim', {}, 'safetyFactor', {});

% Prioritaet 1 = Pflicht, 2 = wenn Zeit bleibt, 3 = nur als Rueckfalloption
t(end+1) = cond('R0_v23_repro', a10, 'PPO 10 Hz', 10, 17.0, 0.35, 2, 1, ...
    'Reproduktion der V2.3-Laeufe 074-078 mit V2.4. Prueft, dass V2.4 dasselbe Verhalten zeigt.');
t(end+1) = cond('T10_nom', a10, 'PPO 10 Hz', 10, 8.5, 1.0, 5, 1, ...
    'Frequenzangepasster Agent auf der Trainingsbahn, ungeskalierte Befehle.');
t(end+1) = cond('T40_cdr_nom', aCdr, 'CDR2-4 40 Hz', 40, 8.5, 1.0, 5, 1, ...
    '40-Hz-Agent (Bayes + CDR) auf der Trainingsbahn, ungeskalierte Befehle, Wandzeit-Referenz.');
t(end+1) = cond('T40_ppo_nom', aPpo, 'PPO 40 Hz (Basis)', 40, 8.5, 1.0, 5, 2, ...
    '40-Hz-Basis-PPO (vor Bayes und CDR), Anschluss an die alten Laeufe 008-011.');
t(end+1) = cond('T10_s05', a10, 'PPO 10 Hz', 10, 8.5, 0.5, 5, 3, ...
    'Rueckfall, falls Faktor 1.0 aus Sicherheitsgruenden nicht gefahren wird. Dann fuer beide Agenten.');
t(end+1) = cond('T40_cdr_s05', aCdr, 'CDR2-4 40 Hz', 40, 8.5, 0.5, 5, 3, ...
    'Rueckfall zu T10_s05 mit demselben Faktor.');
% Labortag 2: J6-Grenze 0.9774 rad/s wie im Training. Die Hardware-Kappe safetyFactor * dqLim
% muss darueber liegen (0.8 * 1.2218 = 0.9774), sonst schneidet sie J6 ab.
t(end+1) = cond('T40_r4_3k', aR4k3, 'PPO r4 3000 ep (D16 s7)', 40, 8.5, 1.0, 5, 1, ...
    ['Agent mit Basis-Bonus nur auf der Bahn (Sec. V), 3000 Episoden. Folgt er auf dem festen Arm der ' ...
    'ganzen Bahn?'], 0.9774, 0.8);
t(end+1) = cond('T40_r0_j6', aR0k1, 'PPO r0 J6 0.98 (D16 s0)', 40, 8.5, 1.0, 5, 1, ...
    ['Kontrolle: Trainings-Reward (r0), gleiche J6-Grenze, 1000 Episoden. In der Simulation verliert er ' ...
    'das letzte Viertel.'], 0.9774, 0.8);
t(end+1) = cond('T40_r4_1k', aR4k1, 'PPO r4 1000 ep (D16 s2)', 40, 8.5, 1.0, 5, 2, ...
    'r4 nach 1000 Episoden, gleiche Episodenzahl wie T40_r0_j6.', 0.9774, 0.8);
t(end+1) = cond('T40_r4_3k_s4', aR4k3b, 'PPO r4 3000 ep (D16 s4)', 40, 8.5, 1.0, 5, 2, ...
    ['Erweiterung: zweiter r4-Seed (der andere der beiden mittleren von acht), damit die Hardware-Aussage ' ...
    'nicht an einem Agenten haengt.'], 0.9774, 0.8);
t(end+1) = cond('T40_r4_3k_s1', aR4k3q, 'PPO r4 3000 ep (D16 s1)', 40, 8.5, 1.0, 5, 2, ...
    ['Erweiterung: r4-Agent aus der ruhigen Gruppe von D17 (kleine Basisdrehung, doppelter Tracking-Fehler ' ...
    'in Simulation). Zeigt die andere Seite des Zielkonflikts in Sec. V-C auf der Hardware.'], 0.9774, 0.8);
plan.tracking = t;

m = struct('condId', {}, 'mode', {}, 'nCycles', {}, 'nRepetitions', {}, 'agentFile', {}, 'purpose', {});
m(end+1) = struct('condId', 'M_send', 'mode', 'send_only', 'nCycles', 300, 'nRepetitions', 3, ...
    'agentFile', '', 'purpose', 'Nur SendJointSpeedCommand (Null), Table III Zeile 1.');
m(end+1) = struct('condId', 'M_fb', 'mode', 'send_feedback', 'nCycles', 300, 'nRepetitions', 3, ...
    'agentFile', '', 'purpose', 'Senden + RefreshFeedback.');
m(end+1) = struct('condId', 'M_fk', 'mode', 'send_feedback_fk', 'nCycles', 300, 'nRepetitions', 3, ...
    'agentFile', '', 'purpose', 'Senden + Feedback + FK/Jacobi (entspricht dem Playback), Table III Zeile 2.');
m(end+1) = struct('condId', 'M_full', 'mode', 'closed_loop_zero', 'nCycles', 300, 'nRepetitions', 3, ...
    'agentFile', a10, 'purpose', 'Vollstaendige Schleife mit getAction und Logging, Nullbefehl. Table III Zeile 3.');
% Labortag 2 (A60): Wartet jeder blockierende Aufruf auf einen internen Takt von etwa 25 ms?
m(end+1) = struct('condId', 'M_fbonly', 'mode', 'feedback_only', 'nCycles', 300, 'nRepetitions', 3, ...
    'agentFile', '', 'purpose', 'Nur RefreshFeedback, kein Senden. Ein API-Aufruf pro Zyklus (A60).');
m(end+1) = struct('condId', 'M_sendfb', 'mode', 'send_then_feedback', 'nCycles', 300, 'nRepetitions', 3, ...
    'agentFile', '', 'purpose', 'Senden, direkt danach RefreshFeedback (umgekehrte Reihenfolge zu M_fb, A60).');
plan.timing = m;

% Empfohlene Reihenfolge: Timing zuerst (Roboter steht), dann Reproduktion, dann
% die beiden Pflichtbedingungen abwechselnd, damit Drift beide gleich trifft.
o = {};
for i = 1:3
    o(end+1, :) = {'M_send', i}; %#ok<AGROW>
    o(end+1, :) = {'M_fb', i};   %#ok<AGROW>
    o(end+1, :) = {'M_fk', i};   %#ok<AGROW>
    o(end+1, :) = {'M_full', i}; %#ok<AGROW>
end
o(end+1, :) = {'R0_v23_repro', 1};
o(end+1, :) = {'R0_v23_repro', 2};
for i = 1:5
    o(end+1, :) = {'T10_nom', i};     %#ok<AGROW>
    o(end+1, :) = {'T40_cdr_nom', i}; %#ok<AGROW>
end
for i = 1:5
    o(end+1, :) = {'T40_ppo_nom', i}; %#ok<AGROW>
end
plan.order = o;

% Set-Point-Reihe (R1.9): ein Ziel (nominales Trainingsziel), feste Startposen ueber
% dem Startabstand d0, je zwei Wiederholungen.
aP2p = 'SavedAgents/MotionProfile/point/test_agent_fixed1.mat';
sp = struct('condId', {}, 'agentFile', {}, 'agentLabel', {}, 'rateHz', {}, 'cmdScale', {}, ...
            'maxDuration', {}, 'eeSource', {}, 'targetMode', {}, 'targetKortex', {}, ...
            'startIds', {}, 'nRepetitions', {}, 'priority', {}, 'purpose', {});
sp(end+1) = spcond('S0_repro073', aP2p, 0.5, 60, 'kortex', 'kortex_fixed', [0.479 -0.105 0.336], ...
    {'S00'}, 1, 1, ['Reproduktion von Lauf 073 mit V2.4 (Kortex-tool_pose, Faktor 0.5, 60 s, Ziel ' ...
    'wie 073). Prueft, dass V2.4 dasselbe Verhalten zeigt wie V3.0.']);
sp(end+1) = spcond('S10_nom', aP2p, 1.0, 25, 'fk', 'nominal', [], 'all', 2, 1, ...
    ['Set-Point-Agent (Fixed-Base-Training) vom Anker und von 14 festen Starts zum nominalen ' ...
    'Trainingsziel, FK-Endeffektor wie im Training, ungeskalierte Befehle, 25 s wie die Episode.']);
sp(end+1) = spcond('S10_s05', aP2p, 0.5, 25, 'fk', 'nominal', [], 'all', 2, 3, ...
    'Rueckfall zu S10_nom mit Faktor 0.5, falls 1.0 aus Sicherheitsgruenden nicht gefahren wird.');
% Labortag 2 (A57): neun feste Ziele aus setpoint_targets.mat (make_setpoint_targets), je drei Starts.
sp(end+1) = spcond('S20_targets', aP2p, 1.0, 25, 'fk', 'list', [], {'S00', 'S06', 'S07'}, 2, 1, ...
    ['Set-Point-Agent zu neun festen Zielen: sechs im Zielbereich des ROS-Plugins (0.15 und 0.25 m um ' ...
    'das Nominalziel), drei am Rand (0.40 m). Starts S00, S06, S07, sonst wie S10_nom. Wiederholung 2 ' ...
    'nur wenn Zeit bleibt.']);
sp(end+1) = spcond('S21_targets_all', aP2p, 1.0, 25, 'fk', 'list', [], 'all', 1, 2, ...
    ['Erweiterung: die sechs Plugin-Ziele T01-T06 von allen 15 freigegebenen Starts, je einmal. Karte, aus ' ...
    'welchen Richtungen und Abstaenden der Agent die Ziele im Plugin-Bereich erreicht.']);
plan.setpoint = sp;

% Reihenfolge: Reproduktion, dann Wiederholung 1 nach aufsteigendem d0 und
% Wiederholung 2 nach absteigendem d0, damit Drift nicht mit d0 zusammenfaellt.
os = {'S0_repro073', 'S00', 1};
startsFile = fullfile(fileparts(mfilename('fullpath')), 'setpoint_starts.mat');
if isfile(startsFile)
    L = load(startsFile);
    [~, ix] = sort([L.S.starts.d0_m]);
    ids = {L.S.starts(ix).id};
    for i = 1:numel(ids), os(end+1, :) = {'S10_nom', ids{i}, 1}; end        %#ok<AGROW>
    for i = numel(ids):-1:1, os(end+1, :) = {'S10_nom', ids{i}, 2}; end     %#ok<AGROW>
end
plan.orderSetpoint = os;

% Labortag 2: Timing zuerst (Roboter steht), dann Tracking abwechselnd, dann Set-Point.
d2 = struct();
d2.timing = {};
for i = 1:3
    d2.timing(end+1, :) = {'M_fbonly', i};
    d2.timing(end+1, :) = {'M_sendfb', i};
    d2.timing(end+1, :) = {'M_fb', 3 + i};      % Vergleich im selben Aufbau, Nummern 4-6
end
d2.tracking = {};
for i = 1:5
    d2.tracking(end+1, :) = {'T40_r4_3k', i};
    d2.tracking(end+1, :) = {'T40_r0_j6', i};
end
for i = 1:5
    d2.tracking(end+1, :) = {'T40_r4_1k', i};
end
% Set-Point: Wiederholung 1 zielweise, Plugin-Ziele vor den Randzielen. Innerhalb eines Ziels
% wechselt die Startreihenfolge, damit keine Startpose immer zuerst kommt.
tgt = {'T01', 'T02', 'T03', 'T04', 'T05', 'T06', 'E01', 'E02', 'E03'};
st3 = {'S00', 'S06', 'S07'};
d2.setpoint = {};
for r = 1:2
    for i = 1:numel(tgt)
        o3 = circshift(st3, -(i - 1));
        if r == 2, o3 = fliplr(o3); end
        for j = 1:3
            d2.setpoint(end+1, :) = {'S20_targets', tgt{i}, o3{j}, r};
        end
    end
end
% Erweiterung 1: zweiter r4-Seed.
d2.trackingExt = {};
for i = 1:5
    d2.trackingExt(end+1, :) = {'T40_r4_3k_s4', i};
end
% Erweiterung 3 (03.10.): r4-Agent mit ruhiger Basis (D17).
d2.trackingQuiet = {};
for i = 1:5
    d2.trackingQuiet(end+1, :) = {'T40_r4_3k_s1', i};
end
% Erweiterung 2: Plugin-Ziele von allen Starts. Je Ziel nach d0 zu diesem Ziel sortiert, abwechselnd
% aufsteigend und absteigend, damit Drift nicht mit d0 zusammenfaellt.
d2.setpointAll = {};
tf = fullfile(fileparts(mfilename('fullpath')), 'setpoint_targets.mat');
if isfile(tf) && isfile(startsFile)
    LT = load(tf);
    ids = {L.S.starts.id};
    tgtAll = {'T01', 'T02', 'T03', 'T05', 'T04', 'T06'};   % T04 und T06 zuletzt (im Trockenlauf 0/15)
    for i = 1:6
        tt = LT.T.targets(strcmp({LT.T.targets.id}, tgtAll{i}));
        [~, ix] = sort(tt.d0_from_starts_m);
        if mod(i, 2) == 0, ix = fliplr(ix); end
        for j = ix
            d2.setpointAll(end+1, :) = {'S21_targets_all', tgtAll{i}, ids{j}, 1};
        end
    end
end
plan.day2 = d2;
end

function c = spcond(id, agentFile, cmdScale, maxDuration, eeSource, targetMode, targetKortex, ...
                    startIds, nRep, prio, purpose)
c = struct('condId', id, 'agentFile', agentFile, 'agentLabel', 'PPO set-point 10 Hz (fixed base)', ...
           'rateHz', 10, 'cmdScale', cmdScale, 'maxDuration', maxDuration, 'eeSource', eeSource, ...
           'targetMode', targetMode, 'targetKortex', targetKortex, 'startIds', {startIds}, ...
           'nRepetitions', nRep, 'priority', prio, 'purpose', purpose);
end

function c = cond(id, agentFile, label, rateHz, pathDuration, cmdScale, nRep, prio, purpose, j6Lim, safetyFactor)
if nargin < 10, j6Lim = 0.1; end
if nargin < 11, safetyFactor = 0.75; end
c = struct('condId', id, 'agentFile', agentFile, 'agentLabel', label, 'rateHz', rateHz, ...
           'pathDuration', pathDuration, 'cmdScale', cmdScale, 'referenceTiming', 'wall', ...
           'nRepetitions', nRep, 'priority', prio, 'purpose', purpose, 'j6Lim', j6Lim, ...
           'safetyFactor', safetyFactor);
end
