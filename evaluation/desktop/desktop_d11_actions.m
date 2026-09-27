function T = desktop_d11_actions()
%DESKTOP_D11_ACTIONS  Aktionen der D11-Agenten in der nominalen Episode (Desktop-Plan D11, Befund A64).
%   T = desktop_d11_actions()
%
%   Laeuft fuer jeden Agenten in SavedAgents/MotionProfile/D11 die nominale Episode wie desktop_d11_eval
%   (65 kg, deterministisch, Reward-Modus 0, J6 0,1 rad/s) und wertet die Rohaktion a_raw der aktiven Gelenke
%   J2 und J4 aus:
%     sat_J2, sat_J4   Anteil der Agentenschritte ueber der Saettigungsgrenze 0,9774 rad/s
%     at_bound         Anteil der Schritte, in denen J2 und J4 beide an der Grenze des Actors liegen (|a| >= 0,99)
%     absmean          mittlerer Betrag der Rohaktion von J2 und J4
%     t_end            Episodenende in s, stop_reason wie in der Auswertung
%   Ergebnis: data/simulation/desktop/D11_actions_<Zeit>.csv

setup_project;
desktop_build_model();
d = dir(sk_path('SavedAgents', 'MotionProfile', 'D11', 'D11_*_seed*.mat'));
rows = {};
for k = 1:numel(d)
    tok = regexp(d(k).name, '^D11_([A-Z0-9]+)_seed(\d+)\.mat$', 'tokens', 'once');
    if isempty(tok), continue; end
    f = fullfile(d(k).folder, d(k).name);
    cfg = desktop_config('agentFile', f, 'agentLabel', tok{1}, 'Ts', 0.005, 'Ts_agent', 0.025, 'keepTs', true, ...
        'reward_mode', 0, 'j6_lim', 0.1, 'base_mass', 65);
    r = desktop_run_episode(cfg);
    a = r.ts.a_raw(:, [2 4]);
    rows{end + 1} = struct('algo', string(tok{1}), 'seed', str2double(tok{2}), ...
        'sat_J2', r.metrics.sat_frac_J2, 'sat_J4', r.metrics.sat_frac_J4, ...
        'at_bound', mean(all(abs(a) >= 0.99, 2)), 'absmean', mean(abs(a), 'all'), ...
        't_end', r.metrics.t_end, 'stop_reason', string(r.metrics.stop_reason)); %#ok<AGROW>
    fprintf('%-5s Seed %s: sat J2 %.2f, J4 %.2f, beide an Grenze %.2f, |a| %.3f, Ende %.2f s\n', tok{1}, tok{2}, ...
        rows{end}.sat_J2, rows{end}.sat_J4, rows{end}.at_bound, rows{end}.absmean, rows{end}.t_end);
end
T = struct2table([rows{:}]);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
out = sk_path('data', 'simulation', 'desktop', ['D11_actions_' stamp '.csv']);
writetable(T, out);
fprintf('Ergebnis: %s\n', out);
end
