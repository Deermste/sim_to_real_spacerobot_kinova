function mdlFile = desktop_build_model(force)
%DESKTOP_BUILD_MODEL  Erzeugt das parametrisierte Auswertemodell SK_desktop (Desktop-Plan D0).
%   mdlFile = desktop_build_model()       baut das Modell nur, wenn es fehlt
%   mdlFile = desktop_build_model(true)   baut es neu
%
%   Quelle ist models/SpaceKinova_MotionProfile_CDR.slx. Es entspricht dem 40-Hz-Modell mit einem
%   zusaetzlichen Delay-Block hinter dem Agenten (Befund A23). Die Quelle bleibt unveraendert.
%   Im neuen Modell sind diese Groessen Variablen (Werte setzt desktop_run_episode):
%     p_Ts           Solver-Schritt [s] (Rate Transition vor dem Integrator)
%     p_Ts_agent     Agenten-Takt [s] (Beobachtung, Reward)
%     p_T            Episodendauer [s]
%     p_base_mass    Basismasse [kg], Traegheit skaliert mit (Wuerfel 1 m). 1e9 kg haelt die Basis fest
%     p_delay_steps  Aktionsverzoegerung in Agentenschritten (0 = keine)
%     p_damp_scale   Faktor auf die Gelenkdaempfung (ohne Wirkung auf die Bewegung, Gelenke sind
%                    bewegungsgesteuert, A23)
%     p_slew         Anstieg des Rate Limiters [1/s] (Training 0,5)
%     p_cmd_scale    Faktor auf den Befehl nach der Kette (speedScale der Deploy-Skripte, A18)
%     p_obs_mode     0 = Beobachtung wie im Training, 1 = wie Deploy-Skript V2.1 (A22)
%     p_obs_noise    29x1 Standardabweichungen fuer Beobachtungsrauschen vor dem Agenten (D7), Standard 0
%     p_reward_mode  Reward-Variante (D12, A51), 0 = wie im Training. Siehe rewardCode unten
%     p_j6_lim       Saettigung von J6 [rad/s] (D16), Training 0,1
%     p_base_w       Gewicht des glatten Basis-Terms in Reward-Modus 4 (D17), Standard 2 wie in D16
%   Zusaetzlich geloggt: Rohaktion, gesaettigte, gefilterte, ratenbegrenzte und skalierte Aktion,
%   Gelenkwinkel-Befehl hinter der Positionssaettigung, Beobachtung (obs) und Agenten-Eingang (obs_agent),
%   isDone.

if nargin < 1, force = false; end

src = 'SpaceKinova_MotionProfile_CDR';
dst = 'SK_desktop';
outDir = sk_path('evaluation', 'desktop', 'models');
mdlFile = fullfile(outDir, [dst '.slx']);
if ~isfolder(outDir), mkdir(outDir); end
addpath(outDir);
if isfile(mdlFile) && ~force
    return
end
if bdIsLoaded(dst), close_system(dst, 0); end

load_system(src);
srcFile = get_param(src, 'FileName');
copyfile(srcFile, mdlFile, 'f');
fileattrib(mdlFile, '+w');
close_system(src, 0);
load_system(mdlFile);

% --- Solver und Dauer ---
set_param(dst, 'FixedStep', 'p_Ts', 'StopTime', 'p_T');

% --- Raten ---
set_param([dst '/Rate Transition'], 'OutPortSampleTime', 'p_Ts');
set_param([dst '/Rate Transition1'], 'OutPortSampleTime', 'p_Ts_agent');
for k = 1:4
    set_param(sprintf('%s/Reward/Rate Transition%d', dst, k), 'OutPortSampleTime', 'p_Ts_agent');
end
% Der MATLAB-Function-Block des Rewards hat im Original eine feste Abtastzeit von 0,025 s
set_param([dst '/Reward/MATLAB Function'], 'SystemSampleTime', 'p_Ts_agent');

% --- J6-Grenze der Saettigung als Parameter (D16). Original 0,1 rad/s, J2 und J4 bleiben bei 0,9774 rad/s ---
set_param([dst '/Saturation'], 'UpperLimit', '[0.0; 0.9774; 0.0; 0.9774; 0.0; p_j6_lim; 0.0]', ...
    'LowerLimit', '-1 * [0.0; 0.9774; 0.0; 0.9774; 0.0; p_j6_lim; 0.0]');

% --- Reward-Variante als Parameter (D12, Befund A51). Modus 0 rechnet wie rewardFcn im Original ---
rwBlk = [dst '/Reward/MATLAB Function'];
rw = sfroot().find('-isa', 'Stateflow.EMChart', 'Path', rwBlk);
rw.Script = rewardCode();
pm = rw.find('-isa', 'Stateflow.Data', 'Name', 'p_reward_mode');
pm.Scope = 'Parameter';
pw = rw.find('-isa', 'Stateflow.Data', 'Name', 'p_base_w');
pw.Scope = 'Parameter';

% --- Basis ---
inertia = [dst '/Robot/base_link/Inertia'];
set_param(inertia, 'Mass', 'p_base_mass', ...
    'MomentsOfInertia', '[10.833, 10.833, 10.833] * p_base_mass / 65');

% --- Verzoegerung ---
set_param([dst '/Delay'], 'DelayLength', 'p_delay_steps', 'DelayLengthUpperLimit', '100');

% --- Daempfung (Nennwerte wie im 40-Hz-Modell: J1-J4 0,5, J5-J7 0,3) ---
for j = 1:7
    blk = sprintf('%s/Robot/kinova_kinova_joint_%d', dst, j);
    if j <= 4, d0 = '0.5'; else, d0 = '0.3'; end
    set_param(blk, 'DampingCoefficient', [d0 ' * p_damp_scale']);
end

% --- Logging der Befehlskette ---
logPort([dst '/RL_Agent'], 1, 'a_raw');
logPort([dst '/Saturation'], 1, 'a_sat');
logPort([dst '/Discrete Filter'], 1, 'a_filt');
logPort([dst '/Rate Limiter'], 1, 'a_rl');
logPort([dst '/Saturation1'], 1, 'q_cmd');
logPort([dst '/Rate Transition1'], 1, 'obs');
logPort([dst '/Reward'], 2, 'is_done');

% --- Rate Limiter: Anstieg als Variable [1/s] ---
set_param([dst '/Rate Limiter'], 'RisingSlewLimit', 'p_slew', 'FallingSlewLimit', '-p_slew');

% --- Befehlsskalierung nach der Kette (wie speedScale der Deploy-Skripte, A18) ---
delete_line(dst, 'Rate Limiter/1', 'Rate Transition/1');
add_block('simulink/Math Operations/Gain', [dst '/Cmd Scale'], 'Gain', 'p_cmd_scale', ...
    'Position', blockPos([dst '/Rate Limiter'], [60 0]));
add_line(dst, 'Rate Limiter/1', 'Cmd Scale/1', 'autorouting', 'on');
add_line(dst, 'Cmd Scale/1', 'Rate Transition/1', 'autorouting', 'on');

% --- Beobachtung vor dem Agenten: korrekt (0) oder wie Deploy-Skript V2.1 (1, Befund A22) ---
delete_line(dst, 'Rate Transition1/1', 'RL_Agent/1');
obsBlk = [dst '/Obs Transform'];
add_block('simulink/User-Defined Functions/MATLAB Function', obsBlk, ...
    'Position', blockPos([dst '/Rate Transition1'], [80 0]));
chart = sfroot().find('-isa', 'Stateflow.EMChart', 'Path', obsBlk);
chart.Script = obsTransformCode();
add_block('simulink/Sources/Constant', [dst '/Obs Mode'], 'Value', 'p_obs_mode', ...
    'Position', blockPos([dst '/Rate Transition1'], [0 60]));
add_block('simulink/Sources/Constant', [dst '/Obs Noise'], 'Value', 'p_obs_noise', ...
    'Position', blockPos([dst '/Rate Transition1'], [0 120]));
add_line(dst, 'Rate Transition1/1', 'Obs Transform/1', 'autorouting', 'on');
add_line(dst, 'Obs Mode/1', 'Obs Transform/2', 'autorouting', 'on');
add_line(dst, 'Obs Noise/1', 'Obs Transform/3', 'autorouting', 'on');
add_line(dst, 'Obs Transform/1', 'RL_Agent/1', 'autorouting', 'on');
logPort(obsBlk, 1, 'obs_agent');
logPort([dst '/Cmd Scale'], 1, 'a_scaled');

set_param(dst, 'SignalLogging', 'on', 'SignalLoggingName', 'logsout');
save_system(dst, mdlFile);
close_system(dst, 0);
fprintf('Modell erzeugt: %s\n', mdlFile);
end

function p = blockPos(ref, offset)
% Position relativ zu einem vorhandenen Block (nur fuer die Darstellung)
r = get_param(ref, 'Position');
p = [r(1) + offset(1), r(2) + offset(2) + 40, r(1) + offset(1) + 50, r(2) + offset(2) + 70];
end

function code = obsTransformCode()
code = strjoin({
'function y = obs_transform(u, mode, sigma)'
'% mode 0: Beobachtung wie im Training [ep; ev; v_base; w_base; q; dq; e_ori]'
'% mode 1: wie Deploy-Skript V2.1 (Befund A22): Reihenfolge [ep; ev; q; dq; v_base; w_base; e_ori],'
'%         Vorzeichen Soll - Ist, Basisgroessen null, e_ori = Endeffektor-Orientierung, Clipping wie V2.1'
'% sigma: 29x1 Standardabweichungen fuer gaussches Beobachtungsrauschen (D7), 0 = kein Rauschen.'
'%        Das Rauschen kommt aus MATLAB (desktop_obs_randn), damit rng-Seeds wirken.'
'coder.extrinsic(''desktop_v21_eori'', ''desktop_obs_randn'');'
'y = u;'
'if any(sigma > 0)'
'    nz = zeros(29, 1);'
'    nz = desktop_obs_randn();'
'    y = y + sigma .* nz;'
'end'
'if mode == 1'
'    q = y(13:19);'
'    dq = y(20:26);'
'    e = zeros(3, 1);'
'    e = desktop_v21_eori(q);'
'    y = [-y(1:3); -y(4:6); q; dq; zeros(3, 1); zeros(3, 1); e];'
'    qlo = [-2*pi; -2.41; -2*pi; -2.66; -2.23; -2.01; -2*pi];'
'    dqlim = [1.3963; 1.3963; 1.3963; 1.3963; 1.2218; 1.2218; 1.2218];'
'    hi = [0.5*ones(3,1); 1.0*ones(3,1); -qlo; dqlim; 0.5*ones(3,1); 1.0*ones(3,1); pi*ones(3,1)];'
'    y = min(max(y, -hi), hi);'
'end'
}, newline);
end

function code = rewardCode()
% Modus 0 ist Zeile fuer Zeile der Reward des Originalmodells (rewardFcn, gleich seit 09.04.2026).
code = strjoin({
'function [reward, isDone] = rewardFcn(ep, ev, dq_cmd, dq_cmd_prev, w_base, e_ori, p_reward_mode, p_base_w)'
'% Reward des Tracking-Trainings mit Varianten fuer D12 (Befund A51)'
'%   p_reward_mode 0: wie im Training seit 09.04. (Basis-Strafen und Basis-Bonus)'
'%                 1: ohne Basis-Terme, wie beim fruehen PPO (Modell im Commit 50ad2ce, ohne Abbruch bei ori > 1)'
'%                 2: wie 0, der Basis-Bonus gilt nur bei EE-Fehler < 5 cm'
'%                 3: dicht und gekoppelt: glatte EE-Boni, Basis-Bonus mit der Tracking-Guete gewichtet,'
'%                    linearer Positionsterm -5*min(|ep|, 0,2) (hoechstens -1 pro Schritt, damit ein Abbruch'
'%                    nicht billiger wird als Weiterfahren). Basis-Strafen wie 0'
'%                 4: wie 2, dazu auf der Bahn (EE-Fehler < 5 cm) ein glatter Basis-Term'
'%                    +p_base_w*exp(-(ori/0,05)^2), p_base_w = 2 in D16, variiert in D17'
'mode = p_reward_mode;'
''
'if any(~isfinite([ep; ev; dq_cmd; dq_cmd_prev; w_base; e_ori]))'
'    reward = -50;'
'    isDone = true;'
'    return;'
'end'
''
'dist   = norm(ep);'
'vel    = norm(ev);'
'w_norm = norm(w_base);'
'ori    = norm(e_ori);'
''
'if dist > 0.5 || vel > 2.0 || (mode ~= 1 && ori > 1.0)'
'    reward = -50;'
'    isDone = true;'
'    return;'
'end'
''
'c_pos = min(ep.'' * ep, 0.25);'
'c_vel = min(ev.'' * ev, 4.0);'
'c_u   = min(dq_cmd.'' * dq_cmd, 10.0);'
'du    = dq_cmd - dq_cmd_prev;'
'c_du  = min(du.'' * du, 10.0);'
'c_ori = min(e_ori.'' * e_ori, 0.5);'
'c_w   = min(w_base.'' * w_base, 1.0);'
''
'if mode == 1'
'    reward = - 20.0 * c_pos - 2.0 * c_vel - 0.02 * c_u - 0.05 * c_du;'
'else'
'    reward = ...'
'        - 20.0  * c_pos ...'
'        -  2.0  * c_vel ...'
'        -  0.02 * c_u   ...'
'        -  0.05 * c_du  ...'
'        -  8.0  * c_ori ...'
'        -  4.0  * c_w;'
'end'
''
'if mode == 3'
'    g = exp(-(dist / 0.05)^2);'
'    reward = reward - 5.0 * min(dist, 0.2) + 1.0 * g + 3.0 * exp(-(dist / 0.02)^2) ...'
'        + 2.0 * g * exp(-(ori / 0.02)^2) * exp(-(w_norm / 0.01)^2);'
'else'
'    if dist < 0.05'
'        reward = reward + 1;'
'    end'
'    if dist < 0.02'
'        reward = reward + 3;'
'    end'
'    if mode == 0 && ori < 0.02 && w_norm < 0.01'
'        reward = reward + 2;'
'    end'
'    if mode == 2 && ori < 0.02 && w_norm < 0.01 && dist < 0.05'
'        reward = reward + 2;'
'    end'
'    if mode == 4 && dist < 0.05'
'        reward = reward + p_base_w * exp(-(ori / 0.05)^2);'
'        if ori < 0.02 && w_norm < 0.01'
'            reward = reward + 2;'
'        end'
'    end'
'end'
''
'isDone = false;'
'end'
}, newline);
end

function logPort(blk, portNum, name)
ph = get_param(blk, 'PortHandles');
p = ph.Outport(portNum);
set_param(p, 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', name);
end
