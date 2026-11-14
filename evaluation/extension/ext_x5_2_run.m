function S = ext_x5_2_run(varargin)
%EXT_X5_2_RUN  Pilot X5.2: RL auf der um -30 Grad gekippten 3D-Bahn mit allen sieben Gelenken, Go/No-Go (E4).
%   S = ext_x5_2_run()                              4 Laeufe (r4 und X1 theta 0,03, je Seeds 0 und 1), danach X0.1
%   S = ext_x5_2_run('test', true)                  Kurztest: 16 Episoden je Variante, Pruefung der Grenzen bei den
%                                                   Workern, Auswertung mit 1 Episode, Ablage unter _test
%
%   Aufbau wie X1.3 (ext_x1_train, 40 Hz, 65 kg, PPO wie D16, Bloecke zu 50 Episoden, 3000 Episoden), aber:
%     Bahn 'tilted' mit tilt -30 (E10), Saettigung p_lim7 = [0,9774 x4; 0,5774 x3] rad/s fuer alle Gelenke
%     (wie X5.1), J6-Grenze 0,5774, Beobachtungsgrenzen in der Reihenfolge der Beobachtung (E9).
%   Varianten:
%     r4  Reward-Modus 4 mit w 2 (wie D16), lambda fest 0 (eta 0, lambda0 0)
%     x1  Reward-Modus 5, theta 0,03, Kosten A, delta 0,02, eta 5, lambda0 1 (Einstellung "schnell", X1.3)
%   Auswertung: ext_eval_agent mit 21 Episoden, Startstoerung +-2 Grad auf allen sieben Gelenken.
%   Go (PLAN X5.2): je Variante folgt mindestens einer von zwei Seeds der Bahn.
%   Ergebnis: Agenten unter SavedAgents/MotionProfile/X5, data/simulation/extension/X5_2_{agents,episodes}_<Zeit>.csv

p = inputParser;
p.addParameter('test', false);
p.addParameter('seeds', [0 1]);
p.addParameter('nEpisodes', 3000);
p.parse(varargin{:});
o = p.Results;
setup_project;
dd = sk_path('data', 'simulation', 'extension');
lim7 = [0.9774; 0.9774; 0.9774; 0.9774; 0.5774; 0.5774; 0.5774];
common = {'path', 'tilted', 'tilt', -30, 'lim7', lim7, 'j6Lim', 0.5774, 'obsBounds', 'correct', 'prefix', 'X5', ...
          'block', 50};
nEp = o.nEpisodes; tag = ''; nPert = 20;
if o.test
    nEp = 16; tag = 'test'; nPert = 0;
    common{end} = 16;                       % Bloecke zu 16
end
V = struct('name', {'r4', 'x1'}, 'theta', {0.03, 0.03}, ...
           'args', {{'rewardMode', 4, 'eta', 0, 'lambda0', 0}, {'rewardMode', 5, 'eta', 5, 'lambda0', 1, 'cost_type', 1, ...
                     'delta', 0.02}});
runs = {};
tAll = tic;
for v = 1:numel(V)
    for s = o.seeds
        t0 = tic;
        out = ext_x1_train(V(v).theta, s, V(v).args{:}, common{:}, 'nEpisodes', nEp, 'tag', tag);
        fprintf('X5.2 %s Seed %d: %.1f min\n', V(v).name, s, toc(t0) / 60);
        runs{end + 1} = struct('variant', string(V(v).name), 'seed', s, 'file', string(out.agentFile)); %#ok<AGROW>
        if o.test
            checkWorkers(out.lastStats, lim7);
        end
    end
end
fprintf('X5.2 Training fertig nach %.1f min\n', toc(tAll) / 60);
R = struct2table([runs{:}]);
Arows = {}; Erows = {};
for i = 1:height(R)
    [E, A] = ext_eval_agent(char(R.file(i)), 'nPert', nPert, 'active', 1:7);
    A.variant = R.variant(i); A.seed = R.seed(i);
    E.variant = repmat(R.variant(i), height(E), 1); E.seed = repmat(R.seed(i), height(E), 1);
    Arows{end + 1} = A; Erows{end + 1} = E; %#ok<AGROW>
    fprintf('%s Seed %d: folgt %d, RMS %.1f mm, ep_q4 schlechteste %.1f mm, ori_max schlechteste %.1f mrad, Abbrueche %d\n', ...
            R.variant(i), R.seed(i), A.follows, 1000 * A.rms_ee, 1000 * A.ep_q4_worst, 1000 * A.ori_max_worst, ...
            A.n_stop);
end
S.agents = vertcat(Arows{:});
S.episodes = vertcat(Erows{:});
for v = 1:numel(V)
    k = S.agents.variant == V(v).name;
    verdict = 'No-Go';
    if any(S.agents.follows(k)), verdict = 'Go'; end
    fprintf('Go/No-Go %s: %d von %d Seeds folgen -> %s\n', V(v).name, sum(S.agents.follows(k)), sum(k), verdict);
end
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
pre = 'X5_2_';
if o.test, pre = 'X5_2_test_'; dd = sk_path('data', 'simulation', 'desktop', '_test'); end
writetable(S.agents, fullfile(dd, sprintf('%sagents_%s.csv', pre, stamp)));
writetable(S.episodes, fullfile(dd, sprintf('%sepisodes_%s.csv', pre, stamp)));
end

% =====================================================================
function checkWorkers(stats, lim7)
% Kommen p_lim7 und die gekippte Bahn bei den Workern an? Geloggte gesaettigte Aktion der Trainingsepisoden.
si = stats.SimulationInfo;
if isprop(si, 'NumSimulations'), n = si.NumSimulations; else, n = numel(si); end
mx = zeros(7, 1); nOk = 0;
for i = 1:n
    if iscell(si), so = si{i}; else, so = si(i); end
    try
        el = so.logsout.getElement('a_sat');
        d = squeeze(el.Values.Data);
        if size(d, 1) == 7 && size(d, 2) ~= 7, d = d.'; end
        mx = max(mx, max(abs(d), [], 1).');
        nOk = nOk + 1;
    catch
    end
end
fprintf('Pruefung Worker (%d Episoden mit a_sat): max |a_sat| %s, Grenzen %s\n', nOk, mat2str(mx.', 3), ...
        mat2str(lim7.', 4));
assert(nOk > 0, 'ext_x5_2_run:log', 'kein a_sat in SimulationInfo');
assert(all(mx <= lim7 + 1e-9) && all(mx([1 3 5 7]) > 0), 'ext_x5_2_run:lim', ...
       'Grenzen kommen bei den Workern nicht an');
end
