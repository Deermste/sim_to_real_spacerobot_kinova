function D = ext_ref_preview(t, traj, tau)
%EXT_REF_PREVIEW  Vorschau der Referenzbahn fuer die erweiterte Beobachtung (Ausbau X4.6, Varianten V2 und V3).
%   D = ext_ref_preview(t, traj, 0.25)
%
%   D(i, :) = traj(t_i + tau) - traj(t_i), linear interpoliert, nach dem Ende der Bahn bleibt der Endpunkt stehen.
%   Die Beobachtung bekommt daraus D - ep = Sollpunkt in tau Sekunden relativ zum EE (ep = Ist - Soll).
%   Gleiche Rechnung in desktop_run_episode und ext_x4_6_train (Simscape, From Workspace) und in ext_kinsim.

t = t(:);
tq = min(t + tau, t(end));
D = interp1(t, traj, tq, 'linear') - traj;
end
