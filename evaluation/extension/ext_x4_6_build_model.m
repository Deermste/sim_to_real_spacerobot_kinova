function mdlFile = ext_x4_6_build_model(dst, filtA, force)
%EXT_X4_6_BUILD_MODEL  Modellkopie mit erweiterter Beobachtung fuer die Ablation X4.6 (Varianten V2 und V3).
%   ext_x4_6_build_model('SK_x46', 0.95)    V2: 38 Kanaele, Filter wie im Training (0,95 y + 0,05 u)
%   ext_x4_6_build_model('SK_x46f', 0.85)   V3: 38 Kanaele, Filter mit Zeitkonstante etwa 0,15 s (E17)
%   ext_x4_6_build_model(dst, filtA, true)  neu bauen
%
%   Grundlage ist desktop_build_model(true, dst), also dasselbe Modell wie SK_desktop. SK_desktop selbst bleibt
%   unveraendert. Zusaetzlich:
%     Beobachtung  [obs (29, wie bisher hinter Obs Transform); a_rl(k-1) von J2, J4, J6 (Ausgang des Rate Limiters
%                  im vorigen Agentenschritt, Unit Delay); EE_d25 - ep; EE_d50 - ep] = 38 Kanaele. EE_d25 und
%                  EE_d50 sind die Vorschau der Referenz (ext_ref_preview) als From Workspace im Agententakt,
%                  daraus der Sollpunkt in 0,25 s und 0,5 s relativ zum EE.
%     Filter       Discrete Filter mit Zaehler 1 - filtA und Nenner [1 -filtA] als feste Zahl (nicht als
%                  Parameter, damit es unter Fast Restart sicher wirkt)
%     Logging      erweiterte Beobachtung als obs_ext
%   Die Workspace-Variablen EE_d25 und EE_d50 setzen desktop_run_episode und ext_x4_6_train.

if nargin < 3, force = false; end
assert(startsWith(dst, 'SK_x46'), 'ext_x4_6_build_model:name', 'Name muss mit SK_x46 beginnen');
mdlFile = fullfile(sk_path('evaluation', 'desktop', 'models'), [dst '.slx']);
if isfile(mdlFile) && ~force, return; end
if bdIsLoaded(dst), close_system(dst, 0); end
desktop_build_model(true, dst);
load_system(mdlFile);

% --- Filter ---
set_param([dst '/Discrete Filter'], 'Numerator', sprintf('[%.17g]', 1 - filtA), ...
    'Denominator', sprintf('[1 %.17g]', -filtA));

% --- Zustand der Kette im vorigen Schritt ---
add_block('simulink/Discrete/Unit Delay', [dst '/RL Prev'], 'InitialCondition', 'zeros(7, 1)', ...
    'SampleTime', '-1', 'Position', pos([dst '/Rate Limiter'], [0 120]));
add_line(dst, 'Rate Limiter/1', 'RL Prev/1', 'autorouting', 'on');

% --- Vorschau der Referenz ---
add_block('simulink/Sources/From Workspace', [dst '/Ref D25'], 'VariableName', 'EE_d25', ...
    'SampleTime', 'p_Ts_agent', 'OutputAfterFinalValue', 'Holding final value', ...
    'Position', pos([dst '/Obs Transform'], [0 140]));
add_block('simulink/Sources/From Workspace', [dst '/Ref D50'], 'VariableName', 'EE_d50', ...
    'SampleTime', 'p_Ts_agent', 'OutputAfterFinalValue', 'Holding final value', ...
    'Position', pos([dst '/Obs Transform'], [0 200]));

% --- Erweiterte Beobachtung ---
blk = [dst '/Obs Extend'];
add_block('simulink/User-Defined Functions/MATLAB Function', blk, 'Position', pos([dst '/Obs Transform'], [80 0]));
chart = sfroot().find('-isa', 'Stateflow.EMChart', 'Path', blk);
chart.Script = strjoin({
    'function y = obs_extend(u, aPrev, d25, d50)'
    '% Ausbau X4.6: [obs; Kette J2, J4, J6 im vorigen Schritt; Sollpunkt in 0,25 s und 0,5 s relativ zum EE]'
    'ep = u(1:3);'
    'y = [u; aPrev(2); aPrev(4); aPrev(6); d25(:) - ep; d50(:) - ep];'
    }, newline);
delete_line(dst, 'Obs Transform/1', 'RL_Agent/1');
add_line(dst, 'Obs Transform/1', 'Obs Extend/1', 'autorouting', 'on');
add_line(dst, 'RL Prev/1', 'Obs Extend/2', 'autorouting', 'on');
add_line(dst, 'Ref D25/1', 'Obs Extend/3', 'autorouting', 'on');
add_line(dst, 'Ref D50/1', 'Obs Extend/4', 'autorouting', 'on');
add_line(dst, 'Obs Extend/1', 'RL_Agent/1', 'autorouting', 'on');
ph = get_param(blk, 'PortHandles');
set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'obs_ext');

save_system(dst, mdlFile);
close_system(dst, 0);
fprintf('X4.6-Modell erzeugt: %s (Filter %.4g)\n', mdlFile, filtA);
end

function p = pos(ref, offset)
r = get_param(ref, 'Position');
p = [r(1) + offset(1), r(2) + offset(2) + 40, r(1) + offset(1) + 50, r(2) + offset(2) + 70];
end
