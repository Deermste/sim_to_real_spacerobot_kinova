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
| K3 | Mit den Trainingsgrenzen braucht die Bahn etwa 0,055 rad Basisdrehung, ohne J6-Grenze reichen etwa 0,021 rad | D15 | obere Schranken, kein bewiesenes Minimum. Korrektur 10.11. (A73): ohne J6-Grenze 0,020 rad schon bei voller Bahn (1,2 mm, ideale Kette) bzw. 5,7 mm mit der Befehlskette |
| K4 | Gelenkbahnen der Hardware ergeben dieselbe Basisdrehung wie die Fixed-Base-Simulation (≤ 2 mrad) | D19 | 8 Agenten, offene Rechnung |
| K5 | Ein modellbasierter Regler (exaktes Modell, kennt die Befehlskette) dominiert alle RL-Agenten: 0,020 rad bei 5,7 mm, 0,013 rad bei 9 mm | X2.1 | Kinematischer Simulator, in Simscape auf 3e-7 bestätigt. Robustheit offen (X2.3) |
| K6 | Auch mit Nominalmodell bleibt der Regler bei falscher Masse, Trägheit, Verzögerung, Verstärkung, Rauschen, Startstellung und Drift vor den Agenten. Am knappsten bei Kinematikfehlern (Montage) und Drift um x | X2.3 Teil 1 | 26 Szenarien, 20 Agenten ohne Randomisierung, nur kinematisch |

X0.1 (Auswerteprotokoll) steht und reproduziert D17. Mit ±2° Startstörung folgen 19 von 20 D16/D17-Agenten in
allen 21 Episoden der Bahn, der Ausreißer ist ein ruhiger Agent. X0.2 (kinematischer Simulator) trifft
`SK_desktop` im geschlossenen Kreis auf ≤ 0,45 mm und ≤ 0,34 mrad, meist auf 1e-6, und ist etwa zwölfmal schneller.
Neuer Befund A72: Die Beobachtungsgrenzen stehen in der falschen Reihenfolge, q4 wird in etwa der Hälfte der
Schritte auf 1,4 rad begrenzt. X0.3 (Literatur): Einen RL-Vergleich mit einem GJM- oder RNS-Regler, eine
Basisdrehung als Nebenbedingung und eine gelernte Policy auf einem festen Arm mit mitgerechneter Basis haben wir
nicht gefunden. Die Methoden selbst sind bekannt, X3 wird als Prüfmethode beschrieben. Noch keine Ergebnisse aus
X1 bis X5. X2.1: Ein modellbasierter Regler mit exaktem Modell erreicht bei
gleicher Befehlskette 0,020 rad bei 5,7 mm RMS, alle RL-Agenten liegen deutlich hinter dieser Front (K5). D15
unterschätzte den Spielraum ohne J6-Grenze (A73). X2.3 Teil 1: In 26 Szenarien mit Modell-, Aktor-, Sensor- und
Anfangsfehlern fand sich kein Fall, in dem die Agenten robust besser sind als der Regler mit Nominalmodell (K6).

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

### X0.2 Kinematischer Simulator ✅ 10.11.2026

**Frage:** Bildet ein rein kinematischer Simulator (Policy, Befehlskette, verallgemeinerte Jacobi-Matrix) den
geschlossenen Kreis von `SK_desktop` so genau nach, dass X1.4, X2, X3 und X5 damit rechnen können?

**Signalweg von `SK_desktop` (aus dem Modell gelesen und gemessen):**
- Beobachtung [ep; ev; v_base; w_base; q; dq; e_ori]. ep, ev = Ist − Soll im Weltsystem (Transform Sensor, World).
  v_base, w_base aus dem 6-DOF-Gelenk Welt–Basis, im Weltsystem. e_ori = Drehvektor der Basislage aus dem
  Quaternion (`MATLAB Function2`, q0 = [1 0 0 0]). Die Basis liegt zu Beginn im Weltursprung.
- Befehlskette: Delay → Sättigung → Filter y = 0,95 y + 0,05 u → Rate Limiter (0,5 · 0,025 je Schritt, Start 0)
  → Cmd Scale. Die Rate Transition zum Solvertakt verzögert um einen Agentenschritt: Im Intervall [t_k, t_k+1]
  wirkt der Befehl aus Schritt k−1 (gemessen, Abweichung 4e-13).
- Integrator → Positionssättigung → Simulink-PS-Wandler mit Filter 1/(τs+1)², τ = 20 ms. Die Gelenke folgen also
  nicht dem Integrator, sondern dem gefilterten Befehl (gemessen, Abweichung 5e-11 rad. Die Formen
  1/(τ²s²/2+τs+1) und erster Ordnung weichen um 7 mrad ab).
- Reward mit Rohaktion (vor der Sättigung) und vorheriger Rohaktion.
- `getAction` und der RL-Agent-Block begrenzen die Beobachtung auf die Grenzen der ObservationInfo (siehe A72).

**Umsetzung:** `ext_kin_model` (Kinematik und Massen aus der URDF, Optionen Basismasse, Gliedmassen, Lage des Arms),
`ext_kin_eval` (G, pe, Je ohne rigidBodyTree, 0,17 ms je Aufruf), `ext_policy` (Mittelwert des Actors aus den
Gewichten, mit Begrenzung der Beobachtung), `ext_reward` (Reward wie `rewardCode`), `ext_kinsim` (Simulator,
Gelenkfilter exakt diskretisiert, Basislage als Quaternion mit Trapezregel bei 5 ms, Eingriff `cmdHook` für den
Filter in X1.4, offene Einspielung `actionSeq`). Validierung `ext_x0_validate_kinsim`.

**Validierung (`X0_validate_kinsim_20261110_092826`):**
- Kinematik gegen `desktop_freefloat` an 20 Stellungen: G, pe, Je auf ≤ 9e-16.
- Policy gegen `getAction` an 50 Beobachtungen je Agent: ≤ 6e-7 (einfache Genauigkeit des Netzes).
- Reward aus den geloggten Signalen gegen den geloggten Reward: ≤ 2e-16.
- Offene Einspielung der Simscape-Aktionen: EE-Bahn ≤ 2,2e-7 m RMS, Basisdrehung ≤ 2,9e-7 rad. Größte
  Abweichung der Beobachtung 5,7e-4 in einem einzelnen Wert von dq6 (D16 r4 s2, t = 8,05 s).
- Geschlossener Kreis, deterministisch:

| Fall | EE-Abstand RMS [m] | Basis-Abstand max [rad] | RMS Simscape / kin [mm] | Return Simscape / kin |
|---|---|---|---|---|
| frühes PPO (Modus 0, J6 0,1) | 4,5e-4 | 3,4e-4 | 10,33 / 10,30 | 1698,92 / 1698,87 |
| Optimized (Modus 0, J6 0,1) | 3,8e-8 | 1,8e-7 | 59,77 / 59,77 | 1593,08 / 1593,08 |
| D16 r4 s2 (Modus 4, J6 0,9774) | 1,1e-6 | 1,8e-6 | 11,93 / 11,93 | 2614,24 / 2614,24 |
| D16 r4 s2, Start gestört (Ziehung 1) | 1,0e-6 | 1,8e-6 | 18,58 / 18,58 | 2385,66 / 2385,66 |
| D16 r4 s2, Basis 32,5 kg | 2,4e-7 | 3,3e-7 | 10,12 / 10,12 | 2539,29 / 2539,29 |

- Beim frühen PPO wachsen Rundungsunterschiede im geschlossenen Kreis an. Bis t = 5,65 s bleibt die Beobachtung
  unter 5e-5, die Policy verstärkt das auf 1e-3 in der Aktion, am Ende 0,45 mm. Das ist Empfindlichkeit des
  Regelkreises, kein Modellfehler.
- Laufzeit 0,3–0,4 s je Episode gegen 4–5 s in Simscape (ohne Kompilieren), also etwa zwölfmal schneller.

**Deutung:** Ziel aus `PLAN.md` erreicht (EE ≤ 2 mm RMS, Basis ≤ 2 mrad, Beobachtung kanalweise). Ohne die Begrenzung
der Beobachtung lief der geschlossene Kreis bis 34 mm auseinander. Der Simulator gilt nur für bewegungsgesteuerte
Gelenke, Anfangsimpuls null und keine äußeren Kräfte, also genau für `SK_desktop`.

**Grenzen:** Nur der Halbkreis (Bahn wie `desktop_run_episode`, `ref_timing` 'wall'). `obs_mode` 1 (V2.1) und die
Dreiecksbahn fehlen. Die Positionssättigung wird nur an den Solverschritten geprüft. Die Lage des Arms
(`mount_offset`) und die Gliedmassen sind eingebaut, aber nicht gegen Simscape geprüft (dort keine Parameter).

**Datenquelle:** `data/simulation/extension/X0_validate_kinsim_20261110_092826.csv` und `.mat` (gültig).
`X0_validate_kinsim_20261110_092204.*` ist der erste Lauf ohne Begrenzung der Beobachtung (Beleg für A72:
geschlossener Kreis 17–34 mm auseinander, Policy bis 1,1 Abweichung).

Paper: Methodenteil (kinematischer Simulator als Werkzeug für X1.4, X2, X3), offen.

### A72 Beobachtungsgrenzen in der falschen Reihenfolge (Befund vom 10.11.2026)

`getAction` begrenzt die Beobachtung elementweise auf `LowerLimit`/`UpperLimit` der ObservationInfo. Die Grenzen
aller Agenten (kopiert aus `Optimized.mat`, auch in `desktop_d12_train`) stehen in der Reihenfolge des
Deploy-Skripts V2.1 [ep; ev; q; dq; v_base; w_base; e_ori], die Beobachtung kommt aber in der Reihenfolge des
Trainings [ep; ev; v_base; w_base; q; dq; e_ori]. Wirksam sind damit: q2–q5 auf ±1,4 rad, q6 und q7 auf ±1,22 rad,
dq1 auf ±1,22 rad/s, dq2–dq4 auf ±0,5 rad/s, dq5–dq7 auf ±1 rad/s. ep, ev und e_ori haben die richtigen Grenzen,
v_base und w_base sehr weite.
- In den Validierungsepisoden greift die Begrenzung bei q4 in 48–52 % der Schritte (alle Agenten), bei q6 in
  28–29 % (D16 r4 s2) und bei dq4 in 1 % (Optimized). Die Policy sieht J4 jenseits von 1,4 rad nicht.
- Training, Simulation und Hardware nutzen alle `getAction` (Deploy-Skript v24, Zeile 266). Die Begrenzung ist
  also überall gleich und erklärt keinen Sim-to-Real-Unterschied. Sie ist ein versteckter Informationsverlust
  in der Beobachtung.
- Entscheidung E8 (10.11.): Neue Trainings (X1, X2.4, X4.1, X5) behalten die Grenzen, damit alle Agenten
  vergleichbar bleiben. Das Paper nennt die Begrenzung als Eigenschaft des Aufbaus.

Paper: Sec. III (Beobachtung), offen. Eintrag als A72 in `reviewer_comments.md`.

### X0.3 Literatur ✅ 10.11.2026

**Frage:** Was ist die übliche modellbasierte Vergleichsbasis (X2)? Gibt es die kinematische Emulation auf dem
festen Arm schon (X3)? Wurde Basisstörung schon als Nebenbedingung oder mit Sicherheitsfilter behandelt (X1)?

**Vorgehen:** Websuche (Stichworte je Frage, 17 Suchen), alle Angaben unten über Crossref nach DOI, Autoren, Band
und Seiten geprüft. Gelesen wurden nur Abstracts und Kurzfassungen, keine Volltexte. „Nicht gefunden“ heißt also
„in dieser Suche nicht gefunden“. Vor Phase P die Volltexte von [L5], [L9], [L13], [L14] lesen.

**X2 Vergleichsregler:**
- Die übliche Grundlage ist die verallgemeinerte Jacobi-Matrix mit Resolved-Rate-Regelung [L1]. Papadopoulos und
  Dubowsky [L2] zeigen, dass Fixed-Base-Regler auf frei schwebende Systeme übertragbar sind, solange die Basislage
  bekannt ist und dynamische Singularitäten gemieden werden.
- Für Basisminimierung mit Redundanz ist der Reaction Null Space der Standard [L3, L4]. Rβ aus X2.1 ist eine
  gewichtete Form davon. Im Paper so benennen, nicht als eigene Methode.
- In den geprüften RL-Arbeiten zu frei schwebenden Armen [L10–L13] wird gegen andere RL-Verfahren oder eine
  Gelenkvariante verglichen. Einen Vergleich mit einem GJM- oder RNS-Regler auf derselben Bahn haben wir dort nicht
  gefunden. X2 schließt also eine Lücke. Es belegt auch die bisher unbelegte Aussage der Einleitung zu
  ungenauen Trägheitsparametern (X2.3).

**X3 Emulation:**
- Vorläufer auf Modellebene: Virtual Manipulator [L5] und Dynamically Equivalent Manipulator [L6]. Beide bilden
  das frei schwebende System auf einen fest montierten Ersatzarm ab.
- Vorläufer auf Hardware-Ebene: OOS-SIM (im Paper als `artigas2015`), KUKA KUBE [L7], die Anlage von Al Ali u. a.
  [L8] und eine UR10e-Anlage [L9]. Dort rechnet ein Rechner die Dynamik, und ein Industrieroboter fährt die
  berechnete Bewegung nach.
- Unterschied zu X3: Bei uns ist der echte Arm der Manipulator selbst. Nur die Basis ist virtuell und wird
  kinematisch aus den gemessenen Gelenkwinkeln gerechnet. Keine Kräfte, keine Schwerkraftkompensation.
- Eine gelernte Policy, die so auf einem festen Arm mit mitgerechneter Basis läuft, haben wir nicht gefunden. Der
  einzige Treffer war das eigene Repo `sim_to_real_spacerobot_kinova`.
- **Folge:** X3 im Paper als Prüfmethode beschreiben, die auf [L5, L6] und den HIL-Anlagen aufbaut. Kein Anspruch
  auf eine neue Emulationsidee. Höchstens „to our knowledge, not yet used for a learned velocity-level policy“,
  und erst nach Lesen der Volltexte von [L5] und [L9].

**X1 Nebenbedingung und Filter:**
- Grundlagen: CMDP [L15], CPO [L16], PPO-Lagrangian [L17], PID-Lagrangian [L18], CBF [L19].
- Lagrange-PPO bei Space-Manipulatoren gibt es [L14]. Dort ist der Arm aber fest und die Nebenbedingungen sind
  Kontaktkraft und EE-Geschwindigkeit, nicht die Basis.
- RL bei frei schwebenden Armen behandelt die Basis bisher als Reward-Term [L10, L11, L13]. Bei [L12] regelt ein
  zweiter Agent die aktuierte Basislage. Eine Basisdrehung als explizite Nebenbedingung mit Budget haben wir nicht
  gefunden.
- CBF-Filter für frei schwebende Systeme gibt es, auch mit der Basis-Winkelgeschwindigkeit als Grenze [L20], dort
  in Simulation mit Reaktionsrädern und als Filter um beliebige Referenzbefehle. X1.4 unterscheidet sich durch das
  Budget auf den Basiswinkel, die unaktuierte Basis und den Filter um eine gelernte Policy. [L20] muss zitiert
  werden, es ist im selben Konferenzumfeld erschienen (iSpaRo 2025), ebenso [L13].
- **Folge:** X1 ist für diesen Anwendungsfall neu, die Methode selbst nicht. Im Paper als Anwendung bekannter
  Verfahren auf den Zielkonflikt aus D17 beschreiben.

**Für X5:** [L11] findet, dass die zusätzliche Redundanz die Basisstörung vor allem über eine andere Verteilung der
Gelenkbewegungen senkt. Das ist eine Vergleichsstelle für die 3D-Bahn mit Redundanz.

**Liste (alle über Crossref geprüft, außer [L15–L18], die keine DOI haben):**

- [L1] Y. Umetani, K. Yoshida, „Resolved motion rate control of space manipulators with generalized Jacobian
  matrix“, IEEE Trans. Robot. Autom. 5(3), 303–314, 1989. doi:10.1109/70.34766
- [L2] E. Papadopoulos, S. Dubowsky, „On the nature of control algorithms for free-floating space manipulators“,
  IEEE Trans. Robot. Autom. 7(6), 750–758, 1991. doi:10.1109/70.105384
- [L3] D. N. Nenchev, K. Yoshida, P. Vichitkulsawat, M. Uchiyama, „Reaction null-space control of flexible
  structure mounted manipulator systems“, IEEE Trans. Robot. Autom. 15(6), 1011–1023, 1999. doi:10.1109/70.817666
- [L4] D. N. Nenchev, K. Yoshida, „Impact analysis and post-impact motion control issues of a free-floating space
  robot subject to a force impulse“, IEEE Trans. Robot. Autom. 15(3), 548–557, 1999. doi:10.1109/70.768186
- [L5] Z. Vafa, S. Dubowsky, „The kinematics and dynamics of space manipulators: The virtual manipulator
  approach“, Int. J. Robot. Res. 9(4), 3–21, 1990. doi:10.1177/027836499000900401
- [L6] B. Liang, Y. Xu, M. Bergerman, „Mapping a space manipulator to a dynamically equivalent manipulator“,
  J. Dyn. Syst. Meas. Control 120(1), 1–7, 1998. doi:10.1115/1.2801316
- [L7] M. Wojtunik, P. Łuczak, T. Rybus, G. Granosik, „Application of the KUKA KUBE test-bed for the
  hardware-in-the-loop validation of the space manipulator control system“, Artificial Satellites 58(s1),
  230–248, 2023. doi:10.2478/arsa-2023-0025
- [L8] A. Al Ali, B. Beigomi, Z. H. Zhu, „Development of 6DOF hardware-in-the-loop ground testbed for autonomous
  robotic space debris removal“, Aerospace 11(11), 877, 2024. doi:10.3390/aerospace11110877
- [L9] H. Jahanshahi, M. Alizadeh, Z. H. Zhu, „Hardware-in-the-loop emulation for 6-DOF free-floating spacecraft
  using active gravity compensation with a collaborative robot“, Acta Astronaut. 247, 782–794, 2026.
  doi:10.1016/j.actaastro.2026.05.058
- [L10] H. Yang, X. Yang, J. Li, M. Hu, „Reinforcement learning control for free-floating space manipulator:
  Truncated quantiles critics“, IFAC-PapersOnLine 59(20), 1255–1260, 2025. doi:10.1016/j.ifacol.2025.11.328
- [L11] J. Zhao, T. Li, Z. Yang, S. Qin, J. Duan, H. Zhang, Y. Wang, „Redundant-motion coordination and base
  disturbance suppression of a 6R1P free-floating space manipulator based on deep reinforcement learning“,
  Machines 14(10), 1120, 2026. doi:10.3390/machines14101120
- [L12] Y. Hu, D. Zhou, K. Ouyang, Z. Yu, J. Lv, X. Shao, „Prior policy guided dual-agent coordinated manipulation
  planning of spacecraft-manipulator system“, Acta Astronaut. 248, 256–270, 2026.
  doi:10.1016/j.actaastro.2026.06.007
- [L13] J. L. Loettgen, M. Ceriotti, G. Aragon-Camarasa, K. Worrall, „Deep reinforcement learning for smooth
  guidance of a free-floating robot in point-to-point tasks“, Proc. iSpaRo 2025, 547–552.
  doi:10.1109/isparo66239.2025.11436749
- [L14] L. Li, D. Xin, M. Li, H. Zhang, S. Xu, D. Zhang, „Compliant transfer method for space manipulators based
  on αPPO-LAG“, Mathematics 14(16), 3004, 2026. doi:10.3390/math14163004
- [L15] E. Altman, „Constrained Markov Decision Processes“, Chapman & Hall/CRC, 1999.
- [L16] J. Achiam, D. Held, A. Tamar, P. Abbeel, „Constrained policy optimization“, Proc. ICML 2017, PMLR 70,
  22–31.
- [L17] A. Ray, J. Achiam, D. Amodei, „Benchmarking safe exploration in deep reinforcement learning“, OpenAI
  Technical Report, 2019.
- [L18] A. Stooke, J. Achiam, P. Abbeel, „Responsive safety in reinforcement learning by PID Lagrangian methods“,
  Proc. ICML 2020, PMLR 119, 9133–9143.
- [L19] A. D. Ames, S. Coogan, M. Egerstedt, G. Notomista, K. Sreenath, P. Tabuada, „Control barrier functions:
  Theory and applications“, Proc. ECC 2019, 3420–3431. doi:10.23919/ECC.2019.8796030
- [L20] J. L. Loettgen, K. Worrall, G. Aragon-Camerasa, M. Ceriotti, R. Lampariello, „Control barrier functions
  for safe real-time control of spacecraft onboard robotic manipulators“, Proc. iSpaRo 2025, 539–546.
  doi:10.1109/isparo66239.2025.11437383

Weitere Treffer ohne Folgen für den Plan: Huang u. a., RL im Nullraum eines redundanten Space-Roboters zur
Hindernisvermeidung (Actuators 12(2), 69, 2023, doi:10.3390/act12020069). Arshad und Bazzocchi, DRL mit
Basisminimierung (22nd IAA Symp. Space Debris, 2024, doi:10.52202/078360-0181).

Paper: Sec. I und II (verwandte Arbeiten), Sec. zu X1, X2, X3. Offen, Übertragung in Phase P.

## X1 Nebenbedingung

### X1.1 Umsetzung ✅ 10.11.2026 (Neubau von SK_desktop offen)

**Umsetzung:**
- Reward-Modus 5 in `desktop_build_model` und `ext_reward`: Reward wie Modus 1 (nur Tracking, kein Abbruch bei
  ori > 1 rad) minus λ·c_t. Parameter `p_lambda`, `p_theta`, `p_cost_type`. Kosten c_t in allen Modi berechnet und
  als Signal `cost` geloggt, in Abbruchschritten 0. Kandidat A: c_t = 1 wenn |ori_t| > θ. Kandidat B:
  c_t = max(0, |ori_t| − θ)/θ.
- `ext_x1_train(theta, seed, ...)`: Aufbau wie D16/D17 (`base_sync`, J6 0,9774 rad/s), Training in Blöcken. Nach
  jedem Block C = Mittel der Episodenkosten aus `SimulationInfo` (Explorations-Policy des Trainings), dann
  λ ← min(max(λ + η(C − δ), 0), 20). Protokoll je Block `<Name>_dual.csv`, je Episode `<Name>_train.csv`.
- `SimulationInfo` ist ein `rl.storage.SimulationStorage`: `numel` ergibt 1, die Anzahl steht in
  `NumSimulations`, `si(i)` liefert die Episode i.
- Standardwerte λ = 0, θ = 0,03, Kosten 1 in `desktop_config`, `desktop_run_episode` und allen Trainingsskripten.
  `desktop_run_episode` akzeptiert jetzt jede Modellkopie mit Namen `SK_*`.
- `ext_kinsim` reicht λ, θ und Kostentyp durch und gibt `cost_mean` und `ts.cost` aus.

**Prüfung** (`ext_x1_check` auf der Kopie `SK_x1test`, weil X4.1 SK_desktop benutzt):

| Stufe | Prüfung | Ergebnis |
|---|---|---|
| 1 | Modi 0, 2, 4 gegen die Basislinie aus X0.1 (5 Fälle) | bitgleich |
| 2 | Modus 5 mit λ = 0 gegen Modus 1, D16 r4 s2 | bitgleich |
| 2 | Modus 5, λ = 3, θ = 0,01: Return = Return(Modus 1) − λ·Σc, Kosten A und B | Abweichung 0 |
| 2 | Reward und Kosten des Modells gegen `ext_reward` mit den geloggten Signalen | Abweichung 0 |
| 3 | `ext_x1_train`, 2 Blöcke × 16 Episoden, λ0 = 5, 4 Worker: Kosten in allen 32 Episoden | ja |
| 3 | Episodenreward gegen Nachrechnung mit dem λ des Blocks (λ wirkt bei den Workern) | ≤ 1,4e-12 |
| – | `ext_kinsim` Modus 4 gegen die X0.2-Validierung | gleich |
| – | `ext_kinsim` Modus 5 gegen Simscape (θ = 0,01): Kosten A, Kosten B | gleich, 5e-6 |

Kurztest: Block 1 mit 16 Episoden dauert 1,1 min (mit Kompilieren), Block 2 0,4 min (4 Worker, neben X4.1).

**Nebenbefund:** Die erste Simulation in einer frischen MATLAB-Sitzung weicht um etwa 2e-7 (Return 4e-7) von allen
folgenden ab, auch im selben Modus. Das betrifft nur Bitvergleiche. Die Basislinie von X0.1 entstand genauso (erster
Fall zuerst), deshalb bleibt sie bitgleich. Für eigene Bitvergleiche einen Aufwärmlauf voranstellen.

Datenquelle: Kurztest unter `data/simulation/desktop/_test/X1_ppo_40hz_r5_c1_th30_eta2_seed0_ep32_test.*`.

Paper: Sec. Methode (Nebenbedingung), offen.

## X2 Modellbasierte Vergleichsbasis

### X2.1 Regler und Machbarkeit ✅ 10.11.2026

**Frage:** Folgt ein modellbasierter Regler auf der verallgemeinerten Jacobi-Matrix dem Halbkreis, und welche
Basisdrehung kostet das bei welcher Gewichtung?

**Aufbau:**
- `ext_x2_controller`: Je Agentenschritt eine Optimierung über die Geschwindigkeiten von J2, J4, J6. Bahnaufgabe in
  der x-z-Ebene b = vref − Kp·ep, Basis-Winkelgeschwindigkeit W·x (beide im Weltsystem, aus dem eigenen Modell und
  der Beobachtung). Gewichtet: min |Ax − b|² + β|Wx|². Vorrang: erst die Bahn, dann die Basis bei gleicher
  EE-Geschwindigkeit (wie `min_rot` in D15). Schranken: Geschwindigkeitsgrenzen, Gelenkwinkel (Vorschau 0,1 s) und
  bei invertierter Kette der Rate Limiter. Exakte Lösung durch Aufzählen der aktiven Schranken.
- Varianten der Befehlskette in `ext_kinsim`: `sat` (nur Sättigung, idealer Regler), `full_inv` (volle Kette wie
  bei den Agenten, der Regler kennt Filter und Rate Limiter und invertiert sie) und `full` (volle Kette ohne
  Inversion).
- Option `j6_side`: Der Regler hält J6 auf einer Seite. Ohne Schranken in der Optimierung treibt jede Gewichtung
  J6 an seine Winkelgrenze (2,01 rad) und der Arm verliert die Bahn (erster Versuch, verworfen).
- Sweep `ext_x2_sweep()`: β = 0 und 16 Stufen von 0,1 bis 1e4, Vorrang-Modus, Kp ∈ {5, 10} 1/s, J6-Grenze 0,1 und
  0,9774 rad/s, J6-Seite frei, −, +. 436 Läufe in 3,8 min. Nominales Modell (65 kg) für Regler und Strecke.

**Ergebnis R0 (β = 0, Kp 5):**

| Kette | J6-Grenze | RMS [mm] | Basisdrehung [rad] | D15 track_only [rad] |
|---|---|---|---|---|
| sat | 0,1 | 1,3 | 0,0755 | 0,0747 |
| sat | 0,9774 | 1,2 | 0,0725 | 0,0734 |
| full_inv | 0,1 | 2,7 | 0,0750 | – |
| full_inv | 0,9774 | 2,1 | 0,0691 | – |
| full (ohne Inversion) | 0,1 / 0,9774 | 72 / 117 | 0,077 / 0,111 | – |

Damit ist das Kriterium aus PLAN.md erfüllt (R0 ≤ 5 mm, Basisdrehung passt zu D15). Ohne Kenntnis von Filter und
Rate Limiter verliert der Regler die Bahn. Die Kette verlangt also Vorausschau, die eine Policy lernen muss.

**Front mit voller Kette und Inversion, J6 0,9774 rad/s** (Pareto-Punkte, Auswahl):

| Einstellung | RMS [mm] | größter Fehler [mm] | Basisdrehung [rad] | Ruck [rad/s³] |
|---|---|---|---|---|
| R0, Kp 5 | 2,1 | 10 | 0,069 | 4,8 |
| β 1, Kp 5, J6 − | 5,7 | 20 | 0,020 | 5,2 |
| β 4,6, Kp 5, J6 − | 6,1 | 21 | 0,018 | 4,6 |
| β 22, Kp 5, J6 − | 9,0 | 25 | 0,013 | 4,5 |
| β 46, Kp 5, J6 − | 12,8 | 43 | 0,008 | 4,3 |
| β 215, Kp 5, J6 − | 24 | 55 | 0,006 | 4,9 |
| β 4642, Kp 5 | 39 | 137 | 0,0006 | 6,4 |

- Mit J6 0,1 rad/s bleibt die Basisdrehung bei ≤ 3 mm RMS bei 0,061–0,064 rad. Weniger geht nur mit deutlich mehr
  Bahnfehler (14 mm bei 0,058 rad, 48 mm bei 0,041 rad).
- Der größte Fehler entsteht am Anfang, weil der Rate Limiter das Anfahren bremst. Das gilt für die Agenten genauso.
- Der Ruck (zweite Differenz des Befehls nach der Kette, wie `jerk_rms` in X0.1) liegt mit invertierter Kette bei
  4–7 rad/s³ wie bei den Agenten (2,5–16). Ohne Kette (`sat`) liegt er bei 70–1300, dieser Regler wäre auf der
  Hardware nicht brauchbar.

**Vergleich mit RL (nominal, J6 0,9774, 20 Agenten aus D16/D17, X0.1-Lauf 090946):**
- Genaue Gruppe 8,3–18 mm bei 0,044–0,071 rad, ruhige Gruppe 16–27 mm bei 0,023–0,031 rad.
- Der Regler erreicht 0,020 rad bei 5,7 mm und 0,013 rad bei 9 mm. Je Agent: kleinster RMS der Front bei
  höchstens derselben Basisdrehung. Der Agent hat das 1,5- bis 4,7-fache davon (Median 2,4). Die ruhigen Agenten
  liegen beim 2,8- bis 4,7-fachen, die genauen meist beim 1,5- bis 2,5-fachen. Jeder Agent liegt hinter der Front.
- Grenzen: Der Regler kennt das Modell exakt (X2.3 prüft falsche Parameter), kennt die Befehlskette und bekommt
  den Zweig von J6 vorgegeben. Die Front ist eine schrittweise Lösung, also eine obere Schranke.
- Die genaue Kennzahl (Abstand jedes Agenten zur Front) folgt in X2.2 mit X1.3 und X4.1.

**Kontrolle in Simscape** (`ext_x2_replay_check`): Die Rohbefehle von drei Reglerläufen gingen über
From Workspace statt des Agenten in eine Kopie von SK_desktop (volle Kette). EE-Bahn bis 2,6e-7 m, Basisdrehung bis
2,4e-7 rad gleich. Da der Regler nur von der Beobachtung abhängt, gilt das auch für den geschlossenen Kreis.

**Zwei Zweige von J6 (Befund A73):** Die Lösung hängt stark davon ab, in welche Richtung J6 läuft. Läuft J6 nach
+2,01 rad, bleibt die Basis bei etwa 0,05 rad. Läuft J6 nach −2,01 rad, reichen 0,020 rad bei voller Bahn
(Vorrang-Modus, `sat`: 1,2 mm RMS). D15 fand mit `min_rot` nur den ersten Zweig (0,0526 rad). Grund ist die
Regularisierung 1e-3·|x| in D15: Mit derselben Regularisierung liefert `ext_x2_controller` genau 0,0526 rad, ohne
sie 0,0204 rad. Die obere Schranke aus D15 für J6 ohne Grenze (0,053 rad bei voller Bahn, 0,021 rad nur mit 22 mm
Fehler) war also zu hoch.

Datenquelle: `X2_sweep_20261110_113752.csv`, `X2_replay_check_20261110_113958.csv`.

Paper: neue Vergleichsbasis (Methode und Ergebnis), Sec. V-A (Aussage zum kinematischen Check, A73). Offen.

### X2.3 Robustheit, Teil 1: Bestandsagenten ✅ 10.11.2026

**Frage:** Wer verliert mehr, wenn Modell, Aktorik, Sensorik oder Anfangszustand von der Annahme abweichen: der
modellbasierte Regler mit Nominalmodell oder die RL-Agenten? Gibt es Fälle, in denen RL im Vorteil ist?

**Aufbau** (`ext_x2_robust()`, kinematischer Simulator, volle Befehlskette, J6 0,9774 rad/s):
- Teilnehmer: vier Regler aus X2.1 mit Inversion der Kette und Nominalmodell (R0, Rβ mit β 1, 21,5, 46,4 und
  J6-Seite −) und die 20 r4-Agenten aus D16/D17 (3000 Episoden, wie X0.1). Die Regler kennen weder Verzögerung
  noch Aktorfehler noch Anfangsdrehimpuls.
- 26 Szenarien in vier Gruppen. Modell: Basismasse und -trägheit ×0,25 bis ×2, nur Trägheit ×0,5 / ×2,
  Gliedmassen ±20 %, Montage ±5 cm. Aktor: Verzögerung +25 / +50 ms, Verstärkung ×0,9 / ×1,1, Servo τ 50 ms.
  Sensor: Rauschen realistisch und dreifach (je 5 Seeds), Lagefehler 10 mrad, EE-Fehler 5 mm. Anfang: Startstellung
  ±2° (5 Ziehungen), Restdrehrate der Basis ±2 mrad/s um y und 2 mrad/s um x.
- Neu in `ext_kinsim`: `obsBias` und `w0_init` (Drehimpuls ungleich null, P = 0, Twist G·dq + Hb⁻¹[0; Rbᵀ L]).
  Geprüft: ohne Drehimpuls bitgleich zur X0.2-Validierung, mit ruhendem Arm dreht die Basis exakt mit w0.
- Kennzahl „Faktor“: RMS des Agenten geteilt durch den kleinsten RMS eines Reglers, der der Bahn folgt und
  höchstens dieselbe Basisdrehung hat. „Nicht dominiert“: kein solcher Regler oder Faktor < 1. Nur vier Regler,
  der Faktor ist also eher zu klein.

**Ergebnis** (RMS [mm] / größte Basisdrehung [mrad], RL als Median über 20 Agenten, 912 Episoden in 6 min):

| Szenario | R0 | Rβ 1 | Rβ 46 | RL Median (Δ nominal) | RL ori | RL folgen | Faktor Median (Bereich) | nicht dominiert |
|---|---|---|---|---|---|---|---|---|
| nominal | 2,1 / 69 | 5,7 / 20 | 12,8 / 8 | 12,2 | 51 | 20 | 2,4 (1,5–4,7) | 0 |
| Masse ×0,25 | 4,2 / 164 | 9,2 / 45 | 15,6 / 17 | 18,6 (+6,7) | 99 | 19 | 2,0 (1,3–3,9) | 0 |
| Masse ×0,5 | 2,8 / 112 | 7,3 / 32 | 14,1 / 12 | 15,2 (+2,9) | 75 | 20 | 2,1 (1,3–4,3) | 0 |
| Masse ×2 | 2,2 / 39 | 5,2 / 11 | 11,6 / 5 | 11,9 (−0,4) | 31 | 20 | 2,5 (1,3–5,1) | 0 |
| Trägheit ×0,5 | 2,9 / 114 | 6,9 / 32 | 13,7 / 12 | 15,0 (+2,5) | 76 | 20 | 2,2 (1,3–4,4) | 0 |
| Glieder ×1,2 | 2,2 / 79 | 6,0 / 23 | 13,1 / 9 | 13,0 (+0,5) | 57 | 20 | 2,3 (1,5–4,6) | 0 |
| Montage x +5 cm | 14,6 / 112 | 12,0 / 31 | 20,6 / 19 | 29,7 (+17,7) | 61 | 18 | 2,5 (1,4–4,3) | 0 |
| Montage x −5 cm | 12,9 / 56 | 14,6 / 29 | 21,0 / 20 | 39,6 (+25,7) | 38 | 19 | 2,5 (2,0–3,2) | 1 |
| Montage z +5 cm | 39,0 / 64 | 30,0 / 37 | 27,7 / 14 | 33,5 (+19,8) | 57 | 18 | 1,3 (1,0–1,8) | 1 |
| Verzögerung +50 ms | 3,4 / 64 | 7,6 / 21 | 13,4 / 8 | 14,5 (+3,0) | 50 | 19 | 2,1 (1,2–4,9) | 0 |
| Verstärkung ×1,1 | 2,4 / 69 | 4,9 / 20 | 11,9 / 9 | 14,2 (+1,5) | 52 | 19 | 3,0 (1,9–7,2) | 0 |
| Servo τ 50 ms | 3,3 / 65 | 7,9 / 21 | 13,6 / 8 | 13,9 (+0,4) | 50 | 20 | 1,9 (1,0–3,6) | 0 |
| Rauschen ×3 | 6,7 / 58 | 7,4 / 25 | 12,4 / 10 | 12,2 (+0,2) | 51 | 20 | 1,6 (1,1–4,4) | 0 |
| Lagefehler 10 mrad | 2,1 / 69 | 5,8 / 20 | 12,8 / 8 | 11,8 (0,0) | 51 | 20 | 2,2 (1,5–4,6) | 0 |
| Startstellung ±2° | 3,3 / 86 | 6,6 / 22 | 13,5 / 11 | 13,6 (+1,9) | 53 | 19 | 2,0 (1,4–4,5) | 0 |
| Drift y +2 mrad/s | 2,2 / 93 | 6,2 / 44 | 14,9 / 31 | 12,4 (+0,6) | 73 | 18 | 2,2 (1,4–5,2) | 0 |
| Drift y −2 mrad/s | 2,2 / 45 | 5,3 / 27 | 11,0 / 23 | 15,7 (+3,3) | 30 | 20 | 2,8 (1,4–5,0) | 5 |
| Drift x 2 mrad/s | 12,1 / 71 | 13,1 / 26 | 17,4 / 19 | 17,7 (+5,2) | 53 | 20 | 1,3 (1,1–2,2) | 0 |

Die übrigen Szenarien (Masse ×0,75 / ×1,5, Trägheit ×2, Glieder ×0,8, Verzögerung +25 ms, Verstärkung ×0,9,
Rauschen ×1, EE-Fehler 5 mm) liegen dazwischen. Alle in `X2_robust_20261110_115447_summary.csv`.

**Deutung:**
- Die Regler folgen in allen 26 Szenarien der Bahn. Von den Agenten fallen in 8 Szenarien ein oder zwei aus.
- Falsche Basismasse oder -trägheit kostet den Regler kaum Bahn (R0 höchstens 4,2 mm, Rβ 46 höchstens 15,6 mm).
  Die Basisdrehung folgt bei allen der wahren Masse. Die Agenten verlieren bei leichter Basis mehr (Median +6,7 mm
  bei ×0,25). In der hier gerechneten kinematischen Form ist die Annahme der Einleitung, dass modellbasierte
  Regelung an ungenauen Trägheitsparametern leidet, nicht gestützt.
- Am stärksten trifft den Regler ein Fehler in der Kinematik (Montage z +5 cm: R0 39 mm) und eine Drehrate um x,
  die die ebene Aufgabe nicht ausgleichen kann. Dort liegen die Agenten etwa gleichauf (Faktor 1,0–1,8). Die
  Montagefehler treffen die Agenten aber ebenso (+18 bis +26 mm).
- Bei einer Restdrehrate gegen die Drehrichtung (y −2 mrad/s) sind 5 Agenten nicht dominiert, weil die Drift ihre
  Basisdrehung verkleinert und die vier Regler die Drift nicht ausgleichen (kOri = 0).
- Ein Fall, in dem RL robust besser ist, wurde nicht gefunden. Die Agenten sind ohne Randomisierung trainiert.
  X2.4 prüft, ob Randomisierung der Basismasse daran etwas ändert.
- Grenzen: nur kinematisch (Gelenke bewegungsgesteuert). Momentengrenzen, Elastizität, Kontakt und Schwerkraft
  auf der Hardware sind nicht abgebildet. Genau dort könnte ein modellfreies Verfahren Vorteile haben, das lässt
  sich in diesem Aufbau nicht prüfen. Der Regler kennt die Befehlskette, den Zweig von J6 und die
  Abtastrate.

**Noch offen in X2.3:** Agenten aus X4.1, X1.3 und X2.4 sowie der Sicherheitsfilter aus X1.4. Regler mit
Rückführung der Basislage (kOri > 0) gegen die Drift.

Datenquelle: `X2_robust_20261110_115447_episodes.csv`, `_summary.csv`, `.mat`.

Paper: neue Vergleichsbasis (Robustheit), Einleitung (Aussage zu Trägheitsparametern). Offen.

## X3 Kinematische Emulation

Noch offen.

## X4 Belastbarkeit

### X4.1 Gewichtsreihe auf 10 Seeds (läuft)

Gestartet am 10.11.2026 um 10:51 mit `ext_x4_1_run()` als eigener MATLAB-Prozess (Log `X4_1_matlab.log`). 30 Läufe,
Gewichte 0, 2, 4, 8, 16, neue Seeds 3–9 (Gewicht 2: 8–9), je 3000 Episoden. Danach automatisch `ext_x4_1_eval`.
Kurztest vorher bestanden (2 × 16 Episoden, Auswertung der 20 vorhandenen Agenten in 4,7 min).

## X5 3D

Noch offen.

## Gliederung (für Phase P)

Wird nach X1 und X2 vorgeschlagen.
