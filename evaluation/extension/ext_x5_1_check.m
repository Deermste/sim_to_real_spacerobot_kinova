function R = ext_x5_1_check(phase)
%EXT_X5_1_CHECK  Pruefung des Umbaus von SK_desktop fuer X5 (alle sieben Gelenke, gekippte Bahn), X5.1.
%   R = ext_x5_1_check('before')   vor dem Neubau: Bestandsfaelle im alten Modell rechnen und speichern
%   R = ext_x5_1_check('after')    baut SK_desktop neu und prueft:
%     1  Bitgleichheit: dieselben Bestandsfaelle mit Standardwerten (p_lim7 = -1) liefern dieselbe Beobachtung,
%        dieselben Rohaktionen und denselben Return wie vor dem Neubau (isequal).
%     2  3D gegen ext_kinsim: D16 r4 s2 mit allen sieben Gelenken (0,9774 rad/s J1-J4, 0,5774 rad/s J5-J7) auf
%        der ebenen Bahn und auf der um -30 und +30 Grad gekippten Bahn, in SK_desktop und in ext_kinsim. Offen
%        (Rohaktionen der Simscape-Episode eingespielt) und geschlossen. Ziel wie X0.2: EE-Bahn <= 2 mm RMS
%        Abstand, Basisdrehung <= 2 mrad Abstand.
%     3  Grenzen wirken: geloggte gesaettigte Aktion a_sat je Gelenk hoechstens lim7, J1, J3, J5, J7 nicht null.
%   Bestandsfaelle wie X0.2: Optimized (Modus 0, J6 0,1), D16 r4 s2 (Modus 4, J6 0,9774), D16 r4 s2 mit
%   gestoerter Startstellung (ext_x0_perturbations, Ziehung 1).
%   Ergebnis: data/simulation/extension/X5_1_check_{before,after}_<Zeit>.mat, after zusaetzlich .csv

setup_project;
dd = sk_path('data', 'simulation', 'extension');
ma = sk_path('SavedAgents', 'MotionProfile');
fD16 = fullfile(ma, 'D16', 'D16_ppo_40hz_r4_seed2.mat');
Q0 = ext_x0_perturbations();
base = {
    'optimized',  fullfile(ma, 'Circle', 'PPO', 'Optimized.mat'), 0, 0.1,    zeros(7, 1)
    'd16r4s2',    fD16,                                           4, 0.9774, zeros(7, 1)
    'd16r4s2_q0', fD16,                                           4, 0.9774, Q0(2, :).'
    };
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));

switch phase
    case 'before'
        desktop_build_model();                  % vorhandenes (altes) Modell, kein Neubau
        clear desktop_run_episode               % Agenten-Cache leeren (siehe after)
        B = runBase(base);
        R = B;
        save(fullfile(dd, ['X5_1_check_before_' stamp '.mat']), 'B');
        fprintf('Bestandsfaelle gespeichert (%d)\n', numel(B));
    case 'after'
        d = dir(fullfile(dd, 'X5_1_check_before_*.mat'));
        assert(~isempty(d), 'ext_x5_1_check:before', 'erst ext_x5_1_check(''before'')');
        L = load(fullfile(d(end).folder, d(end).name), 'B');
        md5Old = L.B(1).modelMD5;
        if bdIsLoaded('SK_desktop'), close_system('SK_desktop', 0); end
        desktop_build_model(true);
        rows = {};
        % --- 1 Bitgleichheit ---
        % Agenten-Cache in desktop_run_episode leeren: Die erste Episode eines Agenten in einer Sitzung weicht von
        % den folgenden um 1e-8 bis 2e-7 ab (Netz beim ersten Aufruf anders ausgewertet, 14.11. gemessen). Vorher
        % und nachher muss also jeweils die erste Episode je Agent verglichen werden.
        clear desktop_run_episode
        A = runBase(base);
        for i = 1:numel(A)
            b = L.B(i); a = A(i);
            same = isequal(a.obs, b.obs) && isequal(a.a_raw, b.a_raw) && isequal(a.ret, b.ret);
            dObs = maxAbs(a.obs, b.obs);
            rows{end + 1} = struct('check', "1 bitgleich", 'case', string(a.name), 'pass', same, ...
                'value', dObs, 'limit', 0, 'note', sprintf('Return %.6f / %.6f', a.ret, b.ret)); %#ok<AGROW>
            fprintf('1 %-11s bitgleich %d (max |dobs| %.1e, Return %.6f gegen %.6f)\n', a.name, same, dObs, ...
                    a.ret, b.ret);
        end
        % --- 2 und 3: 3D gegen ext_kinsim ---
        lim7 = [0.9774; 0.9774; 0.9774; 0.9774; 0.5774; 0.5774; 0.5774];
        K = ext_kin_model();
        pol = ext_policy(fD16);
        paths = {'planar', 30; 'tilted', -30; 'tilted', 30};
        for c = 1:size(paths, 1)
            nm = sprintf('%s%+d', paths{c, 1}, paths{c, 2} * strcmp(paths{c, 1}, 'tilted'));
            cfg = desktop_config('agentFile', fD16, 'reward_mode', 4, 'j6_lim', 0.5774, 'base_w', 2, ...
                                 'lim7', lim7, 'path', paths{c, 1}, 'tilt', paths{c, 2}, 'explore', false, ...
                                 'keepTs', true);
            rS = desktop_run_episode(cfg);
            ts = rS.ts;
            opt = {'reward_mode', 4, 'j6_lim', 0.5774, 'base_w', 2, 'K', K, 'lim', lim7, 'path', paths{c, 1}, ...
                   'tilt', paths{c, 2}};
            rO = ext_kinsim([], opt{:}, 'actionSeq', ts.a_raw);
            [oO, eO, wO] = compare(ts, rO.ts);
            rC = ext_kinsim(pol, opt{:});
            [oC, eC, wC] = compare(ts, rC.ts);
            pass2 = eO <= 2e-3 && wO <= 2e-3 && eC <= 2e-3 && wC <= 2e-3;
            rows{end + 1} = struct('check', "2 offen", 'case', string(nm), 'pass', eO <= 2e-3 && wO <= 2e-3, ...
                'value', eO, 'limit', 2e-3, 'note', sprintf('EE %.2e m, Basis %.2e rad, obs %.1e', eO, wO, oO)); %#ok<AGROW>
            rows{end + 1} = struct('check', "2 geschlossen", 'case', string(nm), 'pass', eC <= 2e-3 && wC <= 2e-3, ...
                'value', eC, 'limit', 2e-3, 'note', sprintf('EE %.2e m, Basis %.2e rad, obs %.1e | SK RMS %.1f mm, ori_max %.1f mrad, Return %.1f | kin RMS %.1f mm, ori_max %.1f mrad, Return %.1f', ...
                eC, wC, oC, 1000 * rS.metrics.rms_ee, 1000 * rS.metrics.ori_max, rS.metrics.ret, ...
                1000 * rC.metrics.rms_ee, 1000 * rC.metrics.ori_max, rC.metrics.ret)); %#ok<AGROW>
            % 3 Grenzen
            as = abs(ts.a_sat);
            mx = max(as, [], 1).';
            pass3 = all(mx <= lim7 + 1e-9) && all(mx([1 3 5 7]) > 0);
            rows{end + 1} = struct('check', "3 Grenzen", 'case', string(nm), 'pass', pass3, ...
                'value', max(mx - lim7), 'limit', 0, 'note', ['max |a_sat| ' mat2str(mx.', 3)]); %#ok<AGROW>
            fprintf(['%-10s offen: EE %.2e m, Basis %.2e rad | geschlossen: EE %.2e m, Basis %.2e rad | ' ...
                     'SK %.1f mm / %.1f mrad, kin %.1f mm / %.1f mrad | Grenzen %d %s\n'], nm, eO, wO, eC, wC, ...
                    1000 * rS.metrics.rms_ee, 1000 * rS.metrics.ori_max, 1000 * rC.metrics.rms_ee, ...
                    1000 * rC.metrics.ori_max, pass3, mat2str(mx.', 3));
            if ~pass2, fprintf('   -> Abweichung ueber 2 mm / 2 mrad\n'); end
        end
        R = struct2table([rows{:}]);
        disp(R);
        info = struct('md5_before', md5Old, 'md5_after', A(1).modelMD5, 'before_file', d(end).name);
        save(fullfile(dd, ['X5_1_check_after_' stamp '.mat']), 'R', 'A', 'info');
        writetable(R, fullfile(dd, ['X5_1_check_after_' stamp '.csv']));
        fprintf('Alle bestanden: %d\n', all(R.pass));
    otherwise
        error('ext_x5_1_check:phase', 'phase ist before oder after');
end
end

% =====================================================================
function B = runBase(base)
B = struct('name', {}, 'obs', {}, 'a_raw', {}, 'ret', {}, 'rms', {}, 'ori_max', {}, 'modelMD5', {});
for i = 1:size(base, 1)
    [name, file, mode, j6, q0] = base{i, :};
    cfg = desktop_config('agentFile', file, 'reward_mode', mode, 'j6_lim', j6, 'base_w', 2, 'q0', q0, ...
                         'explore', false, 'keepTs', true);
    r = desktop_run_episode(cfg);
    B(i) = struct('name', name, 'obs', r.ts.obs, 'a_raw', r.ts.a_raw, 'ret', r.metrics.ret, ...
                  'rms', r.metrics.rms_ee, 'ori_max', r.metrics.ori_max, 'modelMD5', r.info.modelMD5);
    fprintf('%-11s Return %.4f, RMS %.2f mm, ori_max %.2f mrad\n', name, r.metrics.ret, 1000 * r.metrics.rms_ee, ...
            1000 * r.metrics.ori_max);
end
end

function m = maxAbs(a, b)
if ~isequal(size(a), size(b)), m = Inf; return; end
m = max(abs(a(:) - b(:)));
end

function [dObs, eeRms, oriMax] = compare(a, b)
% wie ext_x0_validate_kinsim: a = Simscape, b = ext_kinsim
nA = min(size(a.obs, 1), size(b.obs, 1));
d = abs(a.obs(1:nA, :) - b.obs(1:nA, :));
dObs = max(d(:));
nS = min(size(a.ep, 1), size(b.ep, 1));
eeRms = sqrt(mean(vecnorm(a.ep(1:nS, :) - b.ep(1:nS, :), 2, 2) .^ 2));
oriMax = max(abs(a.ori(1:nS) - b.ori(1:nS)));
end
