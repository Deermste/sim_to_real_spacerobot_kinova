function [E, A, outFile] = ext_eval_batch(list, study, varargin)
%EXT_EVAL_BATCH  Wertet eine Liste von Agenten mit dem Protokoll X0.1 aus und speichert das Ergebnis.
%   [E, A] = ext_eval_batch(list, 'X4')
%   [E, A] = ext_eval_batch(list, 'X0check', 'nPert', 0, 'parallel', false)
%
%   list   Struct-Array mit den Feldern
%            file    Agentendatei (.mat mit agent, wenn vorhanden cfg)
%            label   Kurzname (optional, sonst Dateiname)
%            group   Gruppe fuer die Statistik, z. B. 'w8' oder 'theta0.03' (optional)
%            opts    Cell mit Name-Wert-Paaren fuer ext_eval_agent (optional), z. B. {'base_w', 8}
%          oder ein Cell-Array von Dateinamen.
%   study  Kurzname der Studie fuer den Dateinamen
%   Weitere Name-Wert-Paare gehen an jeden Aufruf von ext_eval_agent (z. B. 'nPert', 0).
%   'parallel' (Standard true) verteilt die Agenten auf einen Prozess-Pool.
%
%   Ergebnis: data/simulation/extension/X_eval_<study>_<Zeit>_episodes.csv, _agents.csv und .mat
%   (.mat enthaelt E, A, list und meta mit Git-Stand, Protokoll und Laufzeit).

if iscell(list)
    list = struct('file', list(:));
end
if ~isfield(list, 'label'), [list.label] = deal(''); end
if ~isfield(list, 'group'), [list.group] = deal(''); end
if ~isfield(list, 'opts'), [list.opts] = deal({}); end

useParallel = true;
k = find(strcmp(varargin(1:2:end), 'parallel'), 1);
if ~isempty(k)
    useParallel = varargin{2 * k};
    varargin(2 * k - 1:2 * k) = [];
end

setup_project;
desktop_build_model();
n = numel(list);
Ec = cell(n, 1);
Ac = cell(n, 1);
tStart = tic;
if useParallel && n > 1
    pool = gcp('nocreate');
    if isempty(pool), pool = parpool('Processes'); end
    root = sk_path();
    f = parfevalOnAll(pool, @workerSetup, 0, root);
    fetchOutputs(f);                    % wartet und meldet Fehler eines Workers
    parfor i = 1:n
        [Ec{i}, Ac{i}] = evalOne(list(i), varargin);
    end
else
    for i = 1:n
        [Ec{i}, Ac{i}] = evalOne(list(i), varargin);
        fprintf('%3d/%d %s: RMS %.4f m, letztes Viertel %.4f m, Basis %.4f rad, folgt %d\n', i, n, ...
                Ac{i}.agent, Ac{i}.rms_ee, Ac{i}.ep_q4, Ac{i}.ori_max, Ac{i}.follows);
    end
end
wallTime = toc(tStart);
E = vertcat(Ec{:});
A = vertcat(Ac{:});

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = sk_path('data', 'simulation', 'extension');
if ~isfolder(outDir), mkdir(outDir); end
outFile = fullfile(outDir, sprintf('X_eval_%s_%s', study, stamp));
writetable(E, [outFile '_episodes.csv']);
writetable(A, [outFile '_agents.csv']);
meta = struct('study', study, 'git', gitInfo(), 'matlab', version, 'wallTime_s', wallTime, ...
              'evalOpts', {varargin}, 'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
              'computer', getenv('COMPUTERNAME'));
save([outFile '.mat'], 'E', 'A', 'list', 'meta');
fprintf('%d Agenten in %.1f min. Ergebnis: %s_*.csv\n', n, wallTime / 60, outFile);
end

% =====================================================================
function [E, A] = evalOne(item, common)
args = [common, item.opts];
if ~isempty(item.label), args = [args, {'label', item.label}]; end
[E, A] = ext_eval_agent(item.file, args{:});
E.group = repmat(string(item.group), height(E), 1);
A.group = string(item.group);
A = movevars(A, 'group', 'After', 'agent');
end

function workerSetup(root)
% Pfad und eigener Simulink-Cache je Worker (sonst schreiben alle Worker in denselben slprj-Ordner)
addpath(root);
setup_project;
d = tempname;                       % eindeutig je Worker und Aufruf
mkdir(d);
Simulink.fileGenControl('set', 'CacheFolder', d, 'CodeGenFolder', d);
desktop_build_model();
load_system('SK_desktop');
end

function g = gitInfo()
g = struct('hash', '', 'dirty', NaN);
[s1, h] = system(sprintf('git -C "%s" rev-parse --short HEAD', sk_path()));
[s2, d] = system(sprintf('git -C "%s" status --porcelain', sk_path()));
if s1 == 0, g.hash = strtrim(h); end
if s2 == 0, g.dirty = ~isempty(strtrim(d)); end
end
