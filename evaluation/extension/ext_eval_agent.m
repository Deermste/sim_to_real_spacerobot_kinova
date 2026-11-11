function [E, A] = ext_eval_agent(agentFile, varargin)
%EXT_EVAL_AGENT  Wertet einen Agenten mit dem einheitlichen Protokoll aus (X0.1).
%   [E, A] = ext_eval_agent(file)                         Aufbau aus dem cfg des Agenten, 21 Episoden
%   [E, A] = ext_eval_agent(file, 'nPert', 0)             nur die nominale Episode
%   [E, A] = ext_eval_agent(file, 'reward_mode', 4, 'j6_lim', 0.9774, 'base_w', 8)
%
%   Protokoll: je Agent eine nominale Episode (Startstellung null) und nPert Episoden mit gestoerter
%   Startstellung aus ext_x0_perturbations (gleich fuer alle Agenten). Alle deterministisch, Halbkreis 8,5 s,
%   Solver 5 ms, Basismasse 65 kg. Agenten-Takt, J6-Grenze, Reward-Modus und Basis-Gewicht kommen aus dem
%   gespeicherten cfg des Agenten (Trainingsbedingungen). Fehlt es, gelten die Werte des Originalmodells
%   (Modus 0, J6 0,1 rad/s, w 2) und der Takt aus AgentOptions.SampleTime. Name-Wert-Paare ueberschreiben.
%
%   Optionen: nPert (20), pertDeg (2), active ([2 4 6]), base_mass (65), reward_mode, j6_lim, base_w,
%   Ts_agent, label (Dateiname ohne Endung).
%
%   E  eine Zeile je Episode:
%     draw         0 = nominal, 1..nPert gestoert
%     q0_J2/J4/J6  Startstoerung [rad]
%     e0           EE-Fehler zu Beginn [m]
%     rms_ee       RMS des EE-Fehlers ueber die Solver-Schritte [m]
%     ep_q4        mittlerer EE-Fehler im letzten Bahnviertel [m]
%     max_ee       groesster EE-Fehler [m]
%     ori_max      groesste Basisdrehung (Norm des Orientierungsfehlers) [rad]
%     w_max        groesste Basis-Winkelgeschwindigkeit [rad/s]
%     cost_mean    Mittel des Kostensignals der Nebenbedingung (X1) je Agentenschritt, theta und Kostentyp aus
%                  dem cfg des Agenten (Standard 0,03 rad, Indikator). Wie C im Training (ext_x1_train)
%     jerk_rms     RMS des Rucks des Gelenkbefehls (zweite Differenz des Geschwindigkeitsbefehls nach der
%                  Befehlskette, Norm ueber J2, J4, J6) [rad/s^3]
%     early_stop   Episode vorzeitig beendet, stop_reason Grund
%     ret          Return unter dem Reward-Modus der Auswertung
%   A  eine Zeile: Mittel aller Kennzahlen ueber die Episoden (statistische Einheit ist der Agent), dazu
%     nom_*        dieselben Kennzahlen der nominalen Episode
%     ori_max_worst, ep_q4_worst, cost_mean_worst   schlechteste Episode (fuer "haelt das Budget" und "folgt der Bahn")
%     n_stop       Anzahl Abbrueche
%     follows      keine Episode bricht ab und ep_q4 < 0,05 m in jeder Episode

p = inputParser;
p.addParameter('nPert', 20);
p.addParameter('pertDeg', 2);
p.addParameter('active', [2 4 6]);
p.addParameter('base_mass', 65);
p.addParameter('reward_mode', []);
p.addParameter('j6_lim', []);
p.addParameter('base_w', []);
p.addParameter('Ts_agent', []);
p.addParameter('label', '');
p.parse(varargin{:});
o = p.Results;

setup = agentSetup(agentFile);
fn = {'reward_mode', 'j6_lim', 'base_w', 'Ts_agent'};
for k = 1:numel(fn)
    if ~isempty(o.(fn{k})), setup.(fn{k}) = o.(fn{k}); end
end
label = o.label;
if isempty(label), [~, label] = fileparts(agentFile); end

Q0 = ext_x0_perturbations(o.nPert, o.pertDeg, o.active);
T = 8.5;
rows = cell(size(Q0, 1), 1);
for k = 1:size(Q0, 1)
    c = desktop_config('agentFile', agentFile, 'reward_mode', setup.reward_mode, 'j6_lim', setup.j6_lim, ...
                       'base_w', setup.base_w, 'Ts_agent', setup.Ts_agent, 'base_mass', o.base_mass, ...
                       'theta', setup.theta, 'cost_type', setup.cost_type, ...
                       'q0', Q0(k, :).', 'explore', false, 'keepTs', true, 'T', T);
    r = desktop_run_episode(c);
    m = r.metrics;
    epn = vecnorm(r.ts.ep, 2, 2);
    t = r.ts.t_ee;
    q4 = mean(epn(t >= 3 * T / 4 & t <= T + 1e-9));
    rows{k} = struct('agent', string(label), 'draw', k - 1, 'q0_J2', Q0(k, 2), 'q0_J4', Q0(k, 4), ...
        'q0_J6', Q0(k, 6), 'e0', epn(1), 'rms_ee', sqrt(mean(epn .^ 2)), 'ep_q4', q4, 'max_ee', m.max_ee, ...
        'ori_max', m.ori_max, 'w_max', m.w_max, 'jerk_rms', cmdJerk(r.ts, setup.Ts_agent), ...
        'cost_mean', costMean(r.ts), 'early_stop', double(m.early_stop), 'stop_reason', string(m.stop_reason), ...
        'ret', m.ret);
end
E = struct2table([rows{:}], 'AsArray', true);

met = {'e0', 'rms_ee', 'ep_q4', 'max_ee', 'ori_max', 'w_max', 'jerk_rms', 'cost_mean', 'ret'};
A = table(string(label), string(agentFile), setup.reward_mode, setup.j6_lim, setup.base_w, setup.Ts_agent, ...
          height(E), 'VariableNames', {'agent', 'file', 'reward_mode', 'j6_lim', 'base_w', 'Ts_agent', 'n_ep'});
for k = 1:numel(met)
    A.(met{k}) = mean(E.(met{k}));
end
for k = 1:numel(met)
    A.(['nom_' met{k}]) = E.(met{k})(E.draw == 0);
end
A.ori_max_worst = max(E.ori_max);
A.ep_q4_worst = max(E.ep_q4);
A.cost_mean_worst = max(E.cost_mean);
A.n_stop = sum(E.early_stop);
A.follows = double(A.n_stop == 0 && all(E.ep_q4 < 0.05));
end

% =====================================================================
function s = agentSetup(file)
% Trainingsbedingungen aus dem gespeicherten cfg (desktop_d12_train und Nachfolger)
s = struct('reward_mode', 0, 'j6_lim', 0.1, 'base_w', 2, 'Ts_agent', [], 'theta', 0.03, 'cost_type', 1);
vars = {whos('-file', file).name};
if ismember('cfg', vars)
    S = load(file, 'cfg');
    c = S.cfg;
    if isfield(c, 'rewardMode'), s.reward_mode = c.rewardMode; end
    if isfield(c, 'j6Lim'), s.j6_lim = c.j6Lim; end
    if isfield(c, 'baseW'), s.base_w = c.baseW; end
    if isfield(c, 'Ts_agent'), s.Ts_agent = c.Ts_agent; end
    if isfield(c, 'theta'), s.theta = c.theta; end
    if isfield(c, 'costType'), s.cost_type = c.costType; end
end
if isempty(s.Ts_agent)
    S = load(file, 'agent');
    s.Ts_agent = S.agent.AgentOptions.SampleTime;
end
end

function c = costMean(ts)
% Mittel des Kostensignals der Nebenbedingung je Agentenschritt (wie C im Training, ext_x1_train)
c = NaN;
if isfield(ts, 'cost'), c = mean(double(ts.cost(:))); end
end

function j = cmdJerk(ts, Ts_agent)
% Ruck des Gelenkwinkel-Befehls: zweite Differenz des Geschwindigkeitsbefehls hinter der Kette
j = NaN;
if ~isfield(ts, 'a_scaled'), return; end
a = ts.a_scaled(:, [2 4 6]);
if size(a, 1) < 3, return; end
d2 = diff(a, 2, 1) / Ts_agent ^ 2;
j = sqrt(mean(sum(d2 .^ 2, 2)));
end
