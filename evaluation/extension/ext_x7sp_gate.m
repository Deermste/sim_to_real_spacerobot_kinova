function g = ext_x7sp_gate(t, Tm)
%EXT_X7SP_GATE  Ausblendung der Set-Point-Korrektur (X7.4, 15.11.2026): 1 bis Tm, linear auf 0 bis Tm + 1 s.
%   g = ext_x7sp_gate(t, Tm)
g = min(max(Tm + 1 - t, 0), 1);
end
