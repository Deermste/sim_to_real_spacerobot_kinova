function [T, outFile] = ext_x1_4_eval(varargin)
%EXT_X1_4_EVAL  Sicherheitsfilter auf die Basisdrehung an vorhandenen Agenten (Ausbau X1.4, erster Teil).
%   [T, outFile] = ext_x1_4_eval()
%   [T, outFile] = ext_x1_4_eval('agents', list)    eigene Liste (file, label, group, j6)
%   [T, outFile] = ext_x1_4_eval('set', 'x13_r1', 'thetas', [0.02 0.03 0.04 0.05 0.06])   Teil 2: r1 aus X1.3
%
%   Kinematischer Simulator, volle Befehlskette, nominal, deterministisch. Filter ext_x1_shield mit
%   Nominalmodell. Je Agent ohne Filter und mit Filter fuer theta x alpha x Ort (nach der Kette / vor der Kette).
%   Standard-Agenten: r1 aus D14 (nur Tracking, ohne Basis-Terme trainiert, J6 0,1 rad/s, Seeds 0-2) als Ersatz
%   fuer die r1-Agenten aus X1.3, und die 20 r4-Agenten aus D16/D17 (J6 0,9774 rad/s).
%   Kennzahlen: RMS, Fehler im letzten Viertel, groesste Basisdrehung, "folgt" (wie X0.1), "haelt das Budget"
%   (groesste Basisdrehung <= theta + 0,005 rad wie ext_stats), Ruck (wie X0.1), Anteil der Schritte mit Eingriff.
%   Optionen: thetas [0.02 0.03 0.04 0.05], alphas [1 5], where {'after', 'before'}.
%   Ergebnis: data/simulation/extension/X1_4_eval_<Zeit>.csv

p = inputParser;
p.addParameter('agents', []);
p.addParameter('set', 'default');
p.addParameter('thetas', [0.02 0.03 0.04 0.05]);
p.addParameter('alphas', [1 5]);
p.addParameter('where', {'after', 'before'});
p.addParameter('save', true);
p.parse(varargin{:});
o = p.Results;
setup_project;
Knom = ext_kin_model();
list = o.agents;
if isempty(list) && strcmp(o.set, 'x13_r1'), list = x13r1Agents(); end
if isempty(list), list = defaultAgents(); end

rows = {};
tAll = tic;
for k = 1:numel(list)
    pol = ext_policy(list(k).file);
    j6 = list(k).j6;
    rows{end + 1} = one(pol, j6, [], 'none', NaN, NaN, list(k)); %#ok<AGROW>
    for th = o.thetas
        for al = o.alphas
            for w = o.where
                sh = {'theta', th, 'alpha', al, 'K', Knom, 'lim', [0.9774 0.9774 j6]};
                if strcmp(w{1}, 'after')
                    hook = ext_x1_shield(sh{:});
                    rows{end + 1} = one(pol, j6, hook, 'after', th, al, list(k)); %#ok<AGROW>
                else
                    pw = ext_x1_shield(sh{:}, 'policy', pol);
                    rows{end + 1} = one(pw, j6, [], 'before', th, al, list(k), pw); %#ok<AGROW>
                end
            end
        end
    end
    fprintf('%-8s fertig (%.1f min)\n', list(k).label, toc(tAll) / 60);
end
T = struct2table([rows{:}]);
outFile = '';
if o.save
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    outFile = sk_path('data', 'simulation', 'extension', ['X1_4_eval_' stamp '.csv']);
    writetable(T, outFile);
    fprintf('Ergebnis: %s\n', outFile);
end
end

% =====================================================================
function r = one(pol, j6, hook, where, th, al, item, counter)
args = {'j6_lim', j6, 'reward_mode', 4};
if ~isempty(hook), args = [args, {'cmdHook', hook}]; end
res = ext_kinsim(pol, args{:});
m = res.metrics;
jt = res.ts.a_scaled(:, [2 4 6]);
jerk = sqrt(mean(sum((diff(jt, 2) / 0.025^2) .^ 2, 2)));
act = NaN;
if ~isempty(hook), c = hook('count'); act = c(2) / max(c(1), 1); end
if nargin > 7, c = counter('count'); act = c(2) / max(c(1), 1); end
follows = ~m.early_stop && m.ep_q4 < 0.05;
r = struct('agent', string(item.label), 'group', string(item.group), 'j6_lim', j6, 'where', string(where), ...
    'theta', th, 'alpha', al, 'rms_ee', m.rms_ee, 'ep_q4', m.ep_q4, 'max_ee', m.max_ee, 'ori_max', m.ori_max, ...
    'follows', double(follows), 'budget', double(follows && m.ori_max <= th + 0.005), 'jerk_rms', jerk, ...
    'frac_active', act, 'early_stop', double(m.early_stop));
end

function list = x13r1Agents()
% die zehn r1-Agenten aus X1.3 (lambda fest 0, J6 0,9774 rad/s, Seeds 0-9)
list = struct('file', {}, 'label', {}, 'group', {}, 'j6', {});
for s = 0:9
    f = sk_path('SavedAgents', 'MotionProfile', 'X1', sprintf('X1_ppo_40hz_r5_c1_th30_eta0_seed%d_ep3000_b50.mat', s));
    list(end + 1) = struct('file', f, 'label', sprintf('r1x_s%d', s), 'group', 'r1_x13', 'j6', 0.9774); %#ok<AGROW>
end
end

function list = defaultAgents()
ma = sk_path('SavedAgents', 'MotionProfile');
list = struct('file', {}, 'label', {}, 'group', {}, 'j6', {});
for s = 0:2
    list(end + 1) = struct('file', fullfile(ma, 'D14', sprintf('D14_ppo_40hz_r1_seed%d.mat', s)), ...
                           'label', sprintf('r1_s%d', s), 'group', 'r1', 'j6', 0.1); %#ok<AGROW>
end
for s = 0:7
    list(end + 1) = struct('file', fullfile(ma, 'D16', sprintf('D16_ppo_40hz_r4_seed%d_ep3000.mat', s)), ...
                           'label', sprintf('w2_s%d', s), 'group', 'r4', 'j6', 0.9774); %#ok<AGROW>
end
for w = [0 4 8 16]
    for s = 0:2
        f = fullfile(ma, 'D17', sprintf('D17_ppo_40hz_r4_w%d_seed%d_ep3000.mat', w, s));
        list(end + 1) = struct('file', f, 'label', sprintf('w%d_s%d', w, s), 'group', 'r4', 'j6', 0.9774); %#ok<AGROW>
    end
end
end
