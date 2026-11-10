function T = ext_x2_4_tunable()
%EXT_X2_4_TUNABLE  Welche Modellparameter lassen sich mit Fast Restart je Episode aendern? (Ausbau X2.4)
%   T = ext_x2_4_tunable()
%
%   Das RL-Training (rlSimulinkEnv) simuliert mit Fast Restart. Nicht abstimmbare Parameter bleiben dann auf dem
%   Wert vom Kompilieren oder fuehren zu einem Fehler. Geprueft an einer Kopie SK_drtest (SK_desktop bleibt
%   unberuehrt): je Parameter zwei Episoden mit Fast Restart (Wert A, dann B) gegen eine Episode mit B ohne Fast
%   Restart. Ergebnis je Parameter: 'abstimmbar' (B mit Fast Restart = Referenz), 'ignoriert' (B = A) oder
%   'Fehler'. Agent D16 r4 s2 (1000 Episoden), deterministisch, J6 0,9774.
%   Erster Lauf 10.11.2026 (vor der Umstellung): Basismasse mit compiletime und p_delay_steps als Dialogwert
%   wurden ignoriert. Seitdem baut desktop_build_model die Masse mit runtime und die Verzoegerung ueber einen
%   Eingangsport. Diese Fassung prueft vorher die Bitgleichheit (ext_x0_check_model) und dann alle Parameter,
%   die X2.4 randomisiert.

setup_project;
Simulink.fileGenControl('set', 'CacheFolder', tempname, 'CodeGenFolder', tempname, 'createDir', true);
mdl = 'SK_drtest';
mf = desktop_build_model(true, mdl);
file = sk_path('SavedAgents', 'MotionProfile', 'D16', 'D16_ppo_40hz_r4_seed2.mat');
Q0 = ext_x0_perturbations();
noise = 1e-3 * ones(29, 1);
B = ext_x0_check_model('compare', mdl);
cases = {
    'p_base_mass',     'p_base_mass',     65,          32.5
    'p_inertia_scale', 'p_inertia_scale', 1,           2
    'p_delay_steps',   'p_delay_steps',   0,           2
    'p_cmd_scale',     'p_cmd_scale',     1,           1.1
    'p_obs_noise',     'p_obs_noise',     zeros(29,1), noise
    'p_q0',            'p_q0',            zeros(7,1),  Q0(2, :).'
    };
rows = {};
for c = 1:size(cases, 1)
    [label, name, vA, vB] = cases{c, :};
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    load_system(mf);
    % Workspace wie desktop_run_episode (eine Episode setzt alle Variablen und den Agenten)
    desktop_run_episode(desktop_config('agentFile', file, 'j6_lim', 0.9774, 'reward_mode', 4, 'model', mdl, ...
                                       'keepTs', false));
    inA = Simulink.SimulationInput(mdl); inA = inA.setVariable(name, vA);
    inB = Simulink.SimulationInput(mdl); inB = inB.setVariable(name, vB);
    status = ""; dRef = NaN; dA = NaN;
    try
        ref = sim(inB);
        outs = sim([inA, inB], 'UseFastRestart', 'on', 'ShowProgress', 'off', 'ShowSimulationManager', 'off');
        if ~isempty(outs(2).ErrorMessage)
            status = "Fehler: " + string(outs(2).ErrorMessage);
        else
            oR = obsOf(ref); o1 = obsOf(outs(1)); o2 = obsOf(outs(2));
            n = min([size(oR, 1), size(o1, 1), size(o2, 1)]);
            dRef = max(abs(o2(1:n, :) - oR(1:n, :)), [], 'all');
            dA = max(abs(o2(1:n, :) - o1(1:n, :)), [], 'all');
            if dRef < 1e-5 && dA > 1e-4
                status = "abstimmbar";
            elseif dA < 1e-9
                status = "ignoriert";
            else
                status = "unklar";
            end
        end
    catch err
        status = "Fehler: " + string(err.message);
    end
    if bdIsLoaded(mdl)
        try, set_param(mdl, 'FastRestart', 'off'); catch, end
    end
    rows{end + 1} = struct('parameter', string(label), 'status', status, 'd_to_ref', dRef, 'd_to_A', dA); %#ok<AGROW>
    fprintf('%-26s %s (Abstand zur Referenz %.2e, zu A %.2e)\n', label, status, dRef, dA);
end
T = struct2table([rows{:}]);
T.Properties.UserData = B;
fprintf('Bitgleichheit Modi 0, 2, 4: groesste Abweichung %g\n', max(B.maxAbsDiff));
close_system(mdl, 0);
delete(mf);
end

function o = obsOf(out)
el = out.logsout.getElement('obs');
d = el.Values.Data;
if ndims(d) == 3
    o = reshape(permute(d, [3 1 2]), size(d, 3), []);
else
    o = d;
end
end
