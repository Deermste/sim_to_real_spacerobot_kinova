function [E, S, outFile] = ext_x2_3_x13()
%EXT_X2_3_X13  Robustheit der X1.3-Agenten gegen die Regler (Ausbau X2.3, Teil 2). Ruft ext_x2_robust auf.
%   [E, S, outFile] = ext_x2_3_x13()
%
%   Teilnehmer: alle Regler wie in X2.4 (vier aus X2.1, dazu die eingestellten aus X2_4_ctrl_tuned.mat), die 50
%   Budget-Agenten aus X1.3 (Label th<theta in mrad>_s<Seed>), die zehn r1-Agenten aus X1.3 (r1_s<Seed>) und als
%   Bezug D16 r4 Seeds 0-9 (w2_s<Seed>, wie der Bezug in X1.3). Szenarien wie ext_x2_robust (26).
%   Auswertung danach mit ext_x2_robust_report(<Zeit>, 'ref', 'w2').

setup_project;
ma = sk_path('SavedAgents', 'MotionProfile');
list = struct('file', {}, 'label', {}, 'group', {});
for th = [20 30 40 50 60]
    for s = 0:9
        f = fullfile(ma, 'X1', sprintf('X1_ppo_40hz_r5_c1_th%d_eta5_seed%d_ep3000_b50_l1.mat', th, s));
        list(end + 1) = struct('file', f, 'label', sprintf('th%d_s%d', th, s), 'group', 'rl'); %#ok<AGROW>
    end
end
for s = 0:9
    f = fullfile(ma, 'X1', sprintf('X1_ppo_40hz_r5_c1_th30_eta0_seed%d_ep3000_b50.mat', s));
    list(end + 1) = struct('file', f, 'label', sprintf('r1_s%d', s), 'group', 'rl'); %#ok<AGROW>
end
for s = 0:9
    f = fullfile(ma, 'D16', sprintf('D16_ppo_40hz_r4_seed%d_ep3000.mat', s));
    list(end + 1) = struct('file', f, 'label', sprintf('w2_s%d', s), 'group', 'rl'); %#ok<AGROW>
end
assert(all(arrayfun(@(x) isfile(x.file), list)), 'ext_x2_3_x13:file', 'Agent fehlt');
[E, S, outFile] = ext_x2_robust('agents', list);
end
