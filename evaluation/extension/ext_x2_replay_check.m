function V = ext_x2_replay_check()
%EXT_X2_REPLAY_CHECK  Reglerbefehle aus ext_kinsim in Simscape eingespielt (Ausbau X2.1, Kontrolle).
%   V = ext_x2_replay_check()
%
%   Der kinematische Simulator ist fuer Policies gegen SK_desktop validiert (X0.2). Fuer die Regler aus X2 wird
%   hier geprueft, dass die Strecke auch ihre Befehle gleich verarbeitet: Die Rohbefehle einer ext_kinsim-Episode
%   gehen ueber einen From-Workspace-Block statt des RL-Agenten in eine Kopie von SK_desktop (SK_x2replay, volle
%   Befehlskette). Stimmen EE-Bahn und Basisdrehung, dann stimmt auch der geschlossene Kreis, weil der Regler nur
%   von der Beobachtung abhaengt und diese gleich ist.
%   Faelle (volle Kette mit Inversion, J6 0,9774): R0, Rbeta mit beta 4,64 und J6-Seite -1, Rbeta mit beta 100
%   und Kp 10. Ziel wie X0.2: EE <= 2 mm RMS Abstand, Basis <= 2 mrad Abstand.
%   Ergebnis: data/simulation/extension/X2_replay_check_<Zeit>.csv

setup_project;
Simulink.fileGenControl('set', 'CacheFolder', tempname, 'CodeGenFolder', tempname, 'createDir', true);
mdl = 'SK_x2replay';
mf = desktop_build_model(true, mdl);
load_system(mf);
% RL-Agent durch From Workspace ersetzen (Eingaenge: Obs Transform, Memory, Memory1; Ausgang: Delay)
ph = get_param([mdl '/RL_Agent'], 'PortHandles');
for k = 1:numel(ph.Inport)
    l = get_param(ph.Inport(k), 'Line');
    if l > 0, delete_line(l); end
end
l = get_param(ph.Outport(1), 'Line');
if l > 0, delete_line(l); end
pos = get_param([mdl '/RL_Agent'], 'Position');
delete_block([mdl '/RL_Agent']);
add_block('simulink/Sources/From Workspace', [mdl '/Replay'], 'VariableName', 'a_replay', ...
    'SampleTime', 'p_Ts_agent', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value', ...
    'Position', pos);
add_line(mdl, 'Replay/1', 'Delay/1', 'autorouting', 'on');
srcs = {'Obs Transform', 'Memory', 'Memory1'};
for k = 1:numel(srcs)
    t = sprintf('Term%d', k);
    add_block('simulink/Sinks/Terminator', [mdl '/' t], 'Position', pos + [0 60 * k 0 60 * k]);
    add_line(mdl, [srcs{k} '/1'], [t '/1'], 'autorouting', 'on');
end
rp = get_param([mdl '/Replay'], 'PortHandles');
set_param(rp.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'a_raw');
save_system(mdl, mf);

cases = {
    'R0',         {'beta', 0}
    'b4.6_neg',   {'beta', 4.6416, 'j6_side', -1}
    'b100_kp10',  {'beta', 100, 'Kp', 10}
    };
dummy = sk_path('SavedAgents', 'MotionProfile', 'Circle', 'PPO', 'Optimized.mat');
rows = {};
for c = 1:size(cases, 1)
    ctrl = ext_x2_controller('j6_lim', 0.9774, 'invert', true, cases{c, 2}{:});
    rk = ext_kinsim([], 'ctrl', ctrl, 'j6_lim', 0.9774, 'chain', 'full');
    a = rk.ts.a_raw;
    tA = rk.ts.t_agent;
    assignin('base', 'a_replay', struct('time', tA, 'signals', struct('values', a, 'dimensions', 7)));
    cfg = desktop_config('agentFile', dummy, 'j6_lim', 0.9774, 'model', mdl, 'keepTs', true);
    rs = desktop_run_episode(cfg);
    nS = min(size(rs.ts.ep, 1), size(rk.ts.ep, 1));
    dEE = sqrt(mean(vecnorm(rs.ts.ep(1:nS, :) - rk.ts.ep(1:nS, :), 2, 2) .^ 2));
    dOri = max(abs(rs.ts.ori(1:nS) - rk.ts.ori(1:nS)));
    nA = min(size(rs.ts.a_raw, 1), size(a, 1));
    dA = max(abs(rs.ts.a_raw(1:nA, :) - a(1:nA, :)), [], 'all');
    rows{end + 1} = struct('case', string(cases{c, 1}), 'kin_rms_mm', 1e3 * rk.metrics.rms_ee, ...
        'sim_rms_mm', 1e3 * rs.metrics.rms_ee, 'kin_ori', rk.metrics.ori_max, 'sim_ori', rs.metrics.ori_max, ...
        'd_ee_rms_m', dEE, 'd_ori_rad', dOri, 'd_cmd', dA); %#ok<AGROW>
end
V = struct2table([rows{:}]);
disp(V);
close_system(mdl, 0);
delete(mf);
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
out = sk_path('data', 'simulation', 'extension', ['X2_replay_check_' stamp '.csv']);
writetable(V, out);
fprintf('Ergebnis: %s\n', out);
end
