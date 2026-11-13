function mdlFile = ext_x1_4_build_model(dst, force)
%EXT_X1_4_BUILD_MODEL  Modellkopie mit Sicherheitsfilter nach der Befehlskette (Ausbau X1.4, Gegenprobe in Simscape).
%   ext_x1_4_build_model()               SK_x14, nur bauen, wenn die Datei fehlt
%   ext_x1_4_build_model('SK_x14', true) neu bauen
%
%   Grundlage ist desktop_build_model(true, dst), also dasselbe Modell wie SK_desktop. SK_desktop bleibt
%   unveraendert. Zusaetzlich ein MATLAB-Function-Block 'Shield' zwischen Cmd Scale und Rate Transition. Er ruft
%   extrinsisch ext_x1_4_sim_shield(cmd, obs, theta, alpha) auf, also denselben Filter (ext_x1_shield,
%   Nominalmodell) wie der Hook in ext_kinsim. q und e_ori kommen aus der Beobachtung (Ausgang Obs Transform) im
%   selben Agentenschritt. theta und alpha aus den Workspace-Variablen p_sh_theta und p_sh_alpha. Der Ausgang des
%   Filters wird als cmd_shield geloggt.

if nargin < 1 || isempty(dst), dst = 'SK_x14'; end
if nargin < 2, force = false; end
assert(startsWith(dst, 'SK_x14'), 'ext_x1_4_build_model:name', 'Name muss mit SK_x14 beginnen');
mdlFile = fullfile(sk_path('evaluation', 'desktop', 'models'), [dst '.slx']);
if isfile(mdlFile) && ~force, return; end
if bdIsLoaded(dst), close_system(dst, 0); end
desktop_build_model(true, dst);
load_system(mdlFile);

blk = [dst '/Shield'];
add_block('simulink/User-Defined Functions/MATLAB Function', blk, 'Position', pos([dst '/Cmd Scale'], [80 0]));
chart = sfroot().find('-isa', 'Stateflow.EMChart', 'Path', blk);
chart.Script = strjoin({
    'function y = shield(cmd, obs, theta, alpha)'
    '% Ausbau X1.4: Sicherheitsfilter auf die Basisdrehung nach der Befehlskette (ext_x1_shield, extrinsisch)'
    'coder.extrinsic(''ext_x1_4_sim_shield'');'
    'y = zeros(7, 1);'
    'y = ext_x1_4_sim_shield(cmd, obs, theta, alpha);'
    }, newline);
add_block('simulink/Sources/Constant', [dst '/Shield Theta'], 'Value', 'p_sh_theta', ...
    'Position', pos([dst '/Cmd Scale'], [0 100]));
add_block('simulink/Sources/Constant', [dst '/Shield Alpha'], 'Value', 'p_sh_alpha', ...
    'Position', pos([dst '/Cmd Scale'], [0 160]));
delete_line(dst, 'Cmd Scale/1', 'Rate Transition/1');
add_line(dst, 'Cmd Scale/1', 'Shield/1', 'autorouting', 'on');
add_line(dst, 'Obs Transform/1', 'Shield/2', 'autorouting', 'on');
add_line(dst, 'Shield Theta/1', 'Shield/3', 'autorouting', 'on');
add_line(dst, 'Shield Alpha/1', 'Shield/4', 'autorouting', 'on');
add_line(dst, 'Shield/1', 'Rate Transition/1', 'autorouting', 'on');
ph = get_param(blk, 'PortHandles');
set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'cmd_shield');

save_system(dst, mdlFile);
close_system(dst, 0);
fprintf('X1.4-Modell erzeugt: %s\n', mdlFile);
end

function p = pos(ref, offset)
r = get_param(ref, 'Position');
p = [r(1) + offset(1), r(2) + offset(2) + 40, r(1) + offset(1) + 50, r(2) + offset(2) + 70];
end
