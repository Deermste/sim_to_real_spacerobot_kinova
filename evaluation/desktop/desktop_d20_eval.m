function T = desktop_d20_eval(ckptRoot)
%DESKTOP_D20_EVAL  Auswertung der Zwischenstaende aus D20 (Befund A68).
%   T = desktop_d20_eval()          alle Ordner SavedAgents/MotionProfile/D20/*_ckpt
%   T = desktop_d20_eval(ordner)    anderer Wurzelordner (Kurztest)
%
%   Jeder Zwischenstand (Agent<n>.mat, Variable saved_agent) laeuft deterministisch in SK_desktop wie in der
%   D17-Auswertung (40 Hz, 65 kg, J6 0,9774 rad/s, Reward-Modus 4 mit Gewicht 2, Halbkreis 8,5 s).
%   Kennzahlen: RMS-Fehler des Endeffektors, mittlerer Fehler im letzten Viertel, groesster
%   Basis-Orientierungsfehler, frueher Abbruch.
%   Ergebnis: data/simulation/desktop/D20_eval_<Zeit>.csv, eine Zeile je Seed und Zwischenstand

setup_project;
desktop_build_model();
if nargin < 1 || isempty(ckptRoot), ckptRoot = sk_path('SavedAgents', 'MotionProfile', 'D20'); end
dirs = dir(fullfile(ckptRoot, '*_ckpt'));
assert(~isempty(dirs), 'desktop_d20_eval:none', 'Keine Zwischenstaende in %s', ckptRoot);
tmp = fullfile(tempdir, 'd20_agent.mat');
rows = {};
for d = 1:numel(dirs)
    seed = str2double(regexp(dirs(d).name, 'seed(\d+)_', 'tokens', 'once'));
    f = dir(fullfile(dirs(d).folder, dirs(d).name, 'Agent*.mat'));
    ep = cellfun(@(s) str2double(regexp(s, 'Agent(\d+)\.mat', 'tokens', 'once')), {f.name});
    [ep, order] = sort(ep);
    f = f(order);
    for k = 1:numel(f)
        S = load(fullfile(f(k).folder, f(k).name), 'saved_agent');
        agent = S.saved_agent; %#ok<NASGU>
        save(tmp, 'agent');
        c = desktop_config('agentFile', tmp, 'reward_mode', 4, 'base_w', 2, 'j6_lim', 0.9774, 'base_mass', 65, ...
                           'explore', false, 'keepTs', true);
        r = desktop_run_episode(c);
        m = r.metrics;
        epn = vecnorm(r.ts.ep, 2, 2);
        t = r.ts.t_ee;
        q4 = mean(epn(t >= 3 * 8.5 / 4 & t <= 8.5 + 1e-9));
        rows{end + 1} = struct('seed', seed, 'episode', ep(k), 'rms_ee', sqrt(mean(epn .^ 2)), 'ep_q4', q4, ...
            'max_ee', m.max_ee, 'ori_max', m.ori_max, 'early_stop', double(m.early_stop)); %#ok<AGROW>
        fprintf('Seed %d, Episode %4d: RMS %.4f m, letztes Viertel %.4f m, Basis max %.4f rad%s\n', seed, ep(k), ...
                rows{end}.rms_ee, q4, m.ori_max, repmat(' (Abbruch)', 1, m.early_stop));
    end
end
T = struct2table([rows{:}]);
out = sk_path('data', 'simulation', 'desktop', ['D20_eval_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')) '.csv']);
writetable(T, out);
fprintf('Ergebnis: %s\n', out);
end
