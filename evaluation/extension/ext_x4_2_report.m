function G = ext_x4_2_report(stamp)
%EXT_X4_2_REPORT  Zusammenfassung von X4.2 nach Untergruppen (kein neues Rechnen).
%   G = ext_x4_2_report('20261111_144608')
%
%   Liest X_eval_X4_2_<stamp>_agents.csv und _episodes.csv sowie X4_2_inventory.csv (ext_x4_2_run).
%   Untergruppe: Gruppe aus ext_x4_2_list, dazu Reward-Modus (D12 bis D16), Takt (D10), Verfahren (D11),
%   Trainingslaenge bei D16 r4 (kurz 1000 / lang 3000 Episoden). Je Untergruppe:
%     n, n_follows (alle 21 Episoden ohne Abbruch und ep_q4 < 5 cm), n_allstop (alle 21 Episoden abgebrochen),
%     rms_med, ori_med, ep_q4_med (nur Episoden ohne Abbruch), j6_lim, reward_mode, stop_reasons
%   G als Tabelle, dazu data/simulation/extension/X4_2_report_<stamp>.csv

setup_project;
d = sk_path('data', 'simulation', 'extension');
A = readtable(fullfile(d, ['X_eval_X4_2_' stamp '_agents.csv']), 'TextType', 'string');
E = readtable(fullfile(d, ['X_eval_X4_2_' stamp '_episodes.csv']), 'TextType', 'string');
I = readtable(fullfile(d, 'X4_2_inventory.csv'), 'TextType', 'string');
[~, ia] = ismember(A.agent, I.label);
A.group = I.group(ia);
A.sub = A.group;
for i = 1:height(A)
    a = A.agent(i); g = A.group(i);
    if ismember(g, ["D12", "D13", "D14", "D16"])
        A.sub(i) = g + "_r" + A.reward_mode(i);
        if g == "D16" && A.reward_mode(i) == 4
            if endsWith(a, "_ep3000"), A.sub(i) = A.sub(i) + "_3000"; else, A.sub(i) = A.sub(i) + "_1000"; end
        end
    elseif g == "D10"
        A.sub(i) = g + "_" + round(1 / A.Ts_agent(i)) + "Hz";
    elseif g == "D11"
        A.sub(i) = g + "_" + extractBetween(a, "D11_", "_seed");
    elseif g == "early"
        A.sub(i) = a;
    end
end
subs = unique(A.sub, 'stable');
rows = cell(numel(subs), 1);
for k = 1:numel(subs)
    S = A(A.sub == subs(k), :);
    Ek = E(ismember(E.agent, S.agent), :);
    ok = Ek.early_stop == 0;
    reasons = unique(Ek.stop_reason(~ok));
    rows{k} = struct('sub', subs(k), 'n', height(S), 'n_follows', sum(S.follows), ...
        'n_allstop', sum(S.n_stop == S.n_ep), 'rms_med', median(S.rms_ee), 'ori_med', median(S.ori_max), ...
        'ep_q4_med', median(Ek.ep_q4(ok), 'omitnan'), 'reward_mode', S.reward_mode(1), 'j6_lim', S.j6_lim(1), ...
        'Ts_agent', S.Ts_agent(1), 'stop_reasons', strjoin(reasons, ' '));
end
G = struct2table([rows{:}]);
disp(G);
writetable(G, fullfile(d, ['X4_2_report_' stamp '.csv']));
end
