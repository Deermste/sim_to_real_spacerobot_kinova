# Ergebnisse des Ausbaus

Einzige Sammelstelle für Ergebnisse des Ausbaus (Plan: `PLAN.md`). Das Paper wird erst in Phase P daraus
geschrieben. Wer nur den Stand braucht, liest „Kernaussagen“. Wer eine Zahl braucht, sucht nach der ID.

## Regeln

- Jeder Eintrag hat: Datum, Frage, Aufbau mit Aufruf (Skript und Argumente), Zahlen, Deutung, Grenzen,
  Datenquelle (Dateiname in `data/simulation/extension/` oder `SavedAgents/...`).
- Zahlen so eintragen, wie sie später ins Paper sollen: Einheit, Anzahl Seeds und Episoden, Mittel oder Median,
  Streuung. Keine Zahl ohne Datenquelle.
- Korrekturen nicht überschreiben, sondern mit Datum als „Korrektur“ darunter, wie im alten Desktop-Plan.
- Jeder Eintrag endet mit „Paper:“ und dem Ziel (Abschnitt, Tabelle, Abbildung) sowie „offen“ oder „übertragen“.
- Kernaussagen nach jedem Eintrag aktualisieren.

## Kernaussagen (Stand 10.11.2026)

| # | Aussage | Beleg | Sicherheit |
|---|---|---|---|
| K1 | Der Basis-Bonus des alten Rewards (auch neben der Bahn gezahlt) erzeugt den späten Tracking-Verlust | D14, D16, Ausgangslage | 3 Seeds je Variante, Hardware bestätigt |
| K2 | Ein Gewicht des glatten Basis-Terms steuert die Basisdrehung nicht, der Seed entscheidet zwischen ruhiger und genauer Lösung | D17, D20 | 3 bzw. 8 Seeds je Gewicht, wird in X4.1 auf 10 aufgefüllt |
| K3 | Mit den Trainingsgrenzen braucht die Bahn etwa 0,055 rad Basisdrehung, ohne J6-Grenze reichen etwa 0,021 rad | D15 | obere Schranken, kein bewiesenes Minimum |
| K4 | Gelenkbahnen der Hardware ergeben dieselbe Basisdrehung wie die Fixed-Base-Simulation (≤ 2 mrad) | D19 | 8 Agenten, offene Rechnung |

X0.1 (Auswerteprotokoll) steht und reproduziert D17. Mit ±2° Startstörung folgen 19 von 20 D16/D17-Agenten in
allen 21 Episoden der Bahn, der Ausreißer ist ein ruhiger Agent. Noch keine Ergebnisse aus X0.2 bis X5.

## Ausgangslage (aus dem alten Desktop-Plan und dem Paper, Stand 10.11.2026)

Alle Werte frei schwebend, 65 kg, Halbkreis 8,5 s, 40 Hz, sofern nicht anders angegeben. Einzelheiten unter der
D-Nummer in `evaluation/desktop/DESKTOP_PLAN.md`.

**Reward-Varianten (D14, 1000 Episoden, Seeds 0–2, J6 0,1 rad/s, stochastisch über 10 Episoden):**

| Reward | letztes Viertel [m] | größte Basisdrehung [rad] | Return unter r0 |
|---|---|---|---|
| r0 (alter Reward) | 0,131–0,172 | 0,006–0,021 | 1313–1487 |
| r1 (ohne Basis-Terme) | 0,005–0,018 | 0,069–0,080 | 1578–1663 |
| r2 (Basis-Bonus nur auf der Bahn) | 0,005–0,018 | 0,071–0,080 | 1629–1746 |
| frühes PPO | 0,009–0,010 | 0,056–0,057 | 1657 |
| Optimized (Bayes) | 0,111–0,121 | 0,016–0,019 | 1537 |

**J6-Grenze 0,9774 rad/s (D16):** r0 bricht in 3/3 Seeds ein (0,117–0,170 m), r2 folgt in 3/3 (Basis
0,031–0,080 rad). r4 (r2 plus +2·exp(−(ori/0,05)²) auf der Bahn) mit 1000 Episoden: Seed 2 folgt mit
0,017–0,028 rad, Seed 1 mit 0,042–0,054 rad, Seed 0 bricht ein. r4 mit 3000 Episoden, Seeds 0–7: alle folgen
(letztes Viertel det. 0,007–0,040 m), Basis 0,023–0,060 rad, Median 0,051 rad.

**Gewichtsreihe (D17, r4, J6 0,9774, 3000 Episoden, deterministisch):**

| Gewicht w | Seeds | größte Basisdrehung, Median (Bereich) [rad] | RMS [mm] | ruhige Lösung |
|---|---|---|---|---|
| 0 | 3 | 0,053 (0,025–0,058) | 9–24 | 1 |
| 2 | 8 | 0,051 (0,023–0,060) | 8–27 | 2 |
| 4 | 3 | 0,044 (0,031–0,071) | 9–26 | 1 |
| 8 | 3 | 0,052 (0,050–0,066) | 12–14 | 0 |
| 16 | 3 | 0,045 (0,025–0,060) | 13–16 | 1 |

Zwei Gruppen über alle 20 Agenten: ruhig 0,023–0,031 rad bei 16–27 mm RMS (5 Agenten), genau 0,044–0,071 rad bei
8–18 mm (15 Agenten). Datenquelle `D17_eval_20260928_144737_*`.

**Trainingsverlauf (D20, 8 Seeds, Zwischenstände alle 250 Episoden):** Ruhige Phasen mit Bahnfolge nur in 2/8
Läufen (0,026–0,031 rad, RMS 19–28 mm), danach Wechsel zur genauen Lösung. Kein Stand zugleich < 0,035 rad und
< 15 mm RMS. Endagenten 0,049–0,062 rad, 7–14 mm.

**Kinematik (D15):** GJM-Einspielung trifft Simscape auf ≤ 1 mrad. Mit Trainingsgrenzen (J6 0,1 rad/s) braucht die
exakte Bahn 0,055–0,076 rad. Ohne J6-Grenze mit Beschleunigungsgrenze 0,5 rad/s² 0,021 rad bei ≤ 22 mm Bahnfehler.
Mit allen 7 Gelenken (Set-Point-Grenzen) 0,046–0,048 rad (schrittweise, obere Schranke).

**Hardware (Labortage 26.09. und 03.10., Schleife 20 Hz, Faktor 1,0, je 5 Läufe):** r4 1000 ep s2 RMS 0,0141 m,
r4 3000 ep s7 0,0188 m, s4 0,0169 m, s1 0,0302 m, r0 0,0915 m, frühes PPO 0,0241 m. Basisdrehung aus den
gemessenen Gelenkbahnen (D19): s2 0,022, s7 0,048, s4 0,040, s1 0,024, r0 0,023 rad, frühes PPO 0,050 rad.

---

## X0 Grundlage

### X0.1 Auswerteprotokoll ✅ 10.11.2026

**Frage:** Ein Protokoll und ein Statistik-Skript für alle späteren Vergleiche (X1, X2, X4, X5).

**Aufbau:**
- Protokoll wie in `PLAN.md`, X0.1 vorgeschlagen, mit E1 (10.11.) auf ±2° statt ±1°. Je Agent 21
  deterministische Episoden: nominal und 20 Startstellungen mit gleichverteilter Störung ±2° auf J2, J4, J6.
  Die Störungen kommen aus `ext_x0_perturbations` (eigener Zufallsstrom, Seed 20261110) und sind für alle
  Agenten gleich. Basismasse 65 kg, Solver 5 ms. Agenten-Takt, J6-Grenze, Reward-Modus und Basis-Gewicht aus dem
  `cfg` des Agenten (Trainingsbedingungen). Ohne `cfg` gelten die Werte des Originalmodells (Modus 0, J6 0,1).
- Modelländerung: neuer Parameter `p_q0` (Anfangswert des Gelenkwinkel-Integrators, Standard null) in
  `desktop_build_model`, `desktop_config` (Feld `q0`), `desktop_run_episode` und den Trainingsskripten D10,
  D11, D12. Dazu die Kennzahl `w_max` in `desktop_run_episode`.
- Skripte: `ext_eval_agent` (ein Agent), `ext_eval_batch` (Liste, parallel, CSV und .mat), `ext_stats`
  (Mittel mit 95-%-Perzentil-Bootstrap aus 2000 Ziehungen, Median, IQR mit Bootstrap, Mann-Whitney-U
  zweiseitig, Fisher exakt, Holm über die Vergleiche zur selben Referenz). Prüfungen `ext_x0_check_model`,
  `ext_x0_check_d17`, `ext_x0_d17_full`.
- Kennzahlen je Episode: `rms_ee`, `ep_q4` (letztes Viertel), `max_ee`, `ori_max`, `w_max`, `jerk_rms`
  (zweite Differenz des Geschwindigkeitsbefehls nach der Kette, Norm über J2, J4, J6), `e0`, Abbruch, Return.
  Je Agent der Mittelwert über die 21 Episoden, dazu die nominalen Werte (`nom_*`) und die schlechteste
  Episode (`ori_max_worst`, `ep_q4_worst`). „Folgt der Bahn“: kein Abbruch und `ep_q4` < 50 mm in jeder
  Episode. „Hält das Budget θ“: `ori_max_worst` ≤ θ + 0,005 rad.

**Prüfungen:**
- Bitgleichheit nach der Modelländerung (`ext_x0_check_model`): frühes PPO 1698,9196, Optimized 1593,0836,
  D16 r2 s1, D16 r4 s7 und D17 w8 s0 liefern Return, RMS, größten EE-Fehler und größte Basisdrehung mit
  Abweichung 0.
- Training mit dem neuen Modell: `desktop_d12_train(4, 0, 16, 'x0test', 'base_sync', 0.9774)` läuft auf
  8 Workern ohne Fehler (1,1 min).
- Fertig-Kriterium (`ext_x0_check_d17`): Mit nur der nominalen Episode trifft das Protokoll RMS, letztes
  Viertel und größte Basisdrehung aller 20 D16/D17-Agenten aus `D17_eval_20260928_144737_agents.csv` auf
  ≤ 5e-17 (Rundung der CSV).

**Vorlauf mit ±1° (20 D16/D17-Agenten, `X_eval_X0full_d17_20261110_085731_*`):** Anfangsfehler im Mittel
8,2 mm. Alle 20 folgen in allen 21 Episoden. RMS-Mittel je Agent −0,2 bis +1,9 mm gegenüber nominal, größte
Basisdrehung der schlechtesten Episode 1,4–4,7 mrad über nominal. Die Störung trennte die Agenten kaum, deshalb
E1 mit ±2°.

**Gültiger Lauf mit ±2° (20 D16/D17-Agenten, 420 Episoden, 5,7 min auf 8 Workern):**
- Anfangsfehler durch die Störung im Mittel 16,3 mm (für alle Agenten gleich, gepaart).
- Kein Abbruch. 19 von 20 folgen der Bahn in allen 21 Episoden. w0 s1 (ruhige Lösung) liegt in einer Episode im
  letzten Viertel bei 54,9 mm und verfehlt damit das Kriterium von 50 mm.
- RMS-Mittel je Agent 0,5–5,6 mm über dem nominalen Wert. Die größte Basisdrehung der schlechtesten Episode
  liegt 3,1–8,1 mrad über der nominalen.
- Gruppen wie in D17, kein Unterschied zum Gewicht 2 (Mann-Whitney, Holm: alle p = 1). Median der größten
  Basisdrehung (Mittel über 21 Episoden) w2 0,052 rad (IQR 0,040–0,053, n = 8), w0 0,054, w4 0,044, w8 0,052,
  w16 0,045 (je n = 3). Median RMS w2 13,7 mm.
- Budget 0,03 rad (Toleranz 0,005 rad) halten 4 von 20 (w2 s0, w2 s1, w0 s1, w16 s0). w4 s2 (nominal
  0,031 rad) fällt mit 0,037 rad in der schlechtesten Episode heraus.

**Deutung:** Das Protokoll ist einsatzbereit und reproduziert D17. Mit ±2° wird der Unterschied zwischen den
Lösungen sichtbar. Die ruhigen Agenten verlieren mit gestörtem Start eher die Bahn im letzten Viertel (w0 s1,
w2 s0 und w4 s2 bei 49 mm), die genauen kaum. Die Budget-Toleranz bleibt nach E1 bei 0,005 rad.

**Grenzen:** Die Störung prüft nur die Startstellung, keine Modellfehler. Bootstrap-Intervalle bei n = 3 sind
kaum aussagekräftig (ab X4.1 n = 10). Laufzeit etwa 0,8 s je Episode auf 8 Workern, X4.2 mit etwa 40 Agenten
also etwa 15 min.

**Datenquelle:** `data/simulation/extension/X0_check_model_baseline.mat`,
`X_eval_X0check_d17_20261110_085109_*`, `X_eval_X0full_d17_20261110_090946_*` (±2°, gültig),
`X_eval_X0full_d17_20261110_085731_*` (±1°, Vorlauf).

Paper: Methodenteil (Auswerteprotokoll und Statistik), offen. Die D17-Zahlen mit vollem Protokoll ersetzen in
X4.2 die alten.

### X0.2 Kinematischer Simulator

Noch offen.

### X0.3 Literatur

Noch offen.

## X1 Nebenbedingung

Noch offen.

## X2 Modellbasierte Vergleichsbasis

Noch offen.

## X3 Kinematische Emulation

Noch offen.

## X4 Belastbarkeit

Noch offen.

## X5 3D

Noch offen.

## Gliederung (für Phase P)

Wird nach X1 und X2 vorgeschlagen.
