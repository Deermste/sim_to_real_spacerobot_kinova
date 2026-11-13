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

## Kernaussagen (Stand 13.11.2026)

| # | Aussage | Beleg | Sicherheit |
|---|---|---|---|
| K1 | Der Basis-Bonus des alten Rewards (auch neben der Bahn gezahlt) erzeugt den späten Tracking-Verlust | D14, D16, Ausgangslage | 3 Seeds je Variante, Hardware bestätigt |
| K2 | Ein Gewicht des glatten Basis-Terms steuert die Basisdrehung nicht (Median 50–54 mrad bei w 0 bis 16). Der Seed entscheidet zwischen ruhiger und genauer Lösung, ruhige Agenten zahlen mit Bahnfehler. Ein größeres Gewicht erhöht vor allem den Befehlsruck | D17, D20, X4.1 | 10 Seeds je Gewicht, 21 Episoden je Agent, alle Holm p ≥ 0,74 |
| K3 | Mit den Trainingsgrenzen braucht die Bahn etwa 0,055 rad Basisdrehung, ohne J6-Grenze reichen etwa 0,021 rad | D15 | obere Schranken, kein bewiesenes Minimum. Korrektur 10.11. (A73): ohne J6-Grenze 0,020 rad schon bei voller Bahn (1,2 mm, ideale Kette) bzw. 5,7 mm mit der Befehlskette |
| K4 | Gelenkbahnen der Hardware ergeben dieselbe Basisdrehung wie die Fixed-Base-Simulation (≤ 2 mrad) | D19 | 8 Agenten, offene Rechnung |
| K5 | Ein modellbasierter Regler (exaktes Modell, kennt die Befehlskette) dominiert alle RL-Agenten: 0,020 rad bei 5,7 mm, 0,013 rad bei 9 mm | X2.1 | Kinematischer Simulator, in Simscape auf 3e-7 bestätigt. Robustheit offen (X2.3) |
| K6 | Auch mit Nominalmodell bleibt der Regler bei falscher Masse, Trägheit, Verzögerung, Verstärkung, Rauschen, Startstellung und Drift vor den Agenten. Am knappsten bei Kinematikfehlern (Montage) und Drift um x | X2.3 Teil 1 | 26 Szenarien, 20 Agenten ohne Randomisierung, nur kinematisch |
| K7 | Auf einer gekippten 3D-Bahn mit allen sieben Gelenken senkt der Nullraum des Reglers die Basisdrehung je nach Kipprichtung stark (−30°: 124 auf 10 mrad bei 2 mm) oder kaum (+30°: 14 auf 11 mrad). In der Ebene bringen die zusätzlichen Gelenke wenig | X5.1 | Nur Regler, kinematisch, nominal. RL in 3D offen (X5.2) |
| K8 | Domain Randomization macht den Bahnfehler der Agenten fast unempfindlich gegen falsche Basismasse (+0,1 bis +0,4 statt +1,7 mm). Die Regler mit Nominalmodell bleiben trotzdem vorn (Faktor 2,0 bis 2,4) | X2.4, X4.5 | 10 Seeds je Variante, 26 Szenarien, nur kinematisch, X0.1 in SK_desktop bestätigt (13.11.). „DR-voll folgt öfter“ hängt an der Schwelle (X4.5), nicht Teil der Aussage |
| K9 | Ein Budget als Nebenbedingung steuert die Basisdrehung (θ gegen ori_max ρ 0,70, bei den folgenden 0,77, Gewicht in K2 −0,18). Der Preis ist die Bahn: nur 27 von 50 Agenten folgen (r1 7 von 10, r4 10 von 10). Für θ ≤ 0,03 muss die Policy den Zweig von J6 finden, den auch der Regler nutzt, ohne ihn folgt keiner (0 von 7). Bei θ 0,03 halten mehr Agenten Bahn und Basis zugleich als in der Gewichtsreihe. Der Abstand zur Front bleibt (Faktor um 2 bis 3 wie ohne Budget), ein Filter auf r1 hält das Budget etwa gleich oft, aber mit mehr Bahnfehler. Unter Störungen scheitern beide verschieden: Der Filter hält das Maximum und verliert eher die Bahn, das Training hält die Bahn und überschreitet das Budget bei Modellfehlern | X1.3, X2.2, X1.4 Teil 2 und 3, X4.5 Runde 2 | 10 Seeds je Budget, 21 Episoden je Agent, nur Simulation. „Folgt seltener als r4“ nur mit Schwelle (X4.5), der Vorteil bei θ 0,02 nicht robust. Budget als Anteil der Schritte, nicht als Maximum. Kollaps bei θ 0,02 (A74) |
| K10 | Weder richtige Beobachtungsgrenzen noch mehr Information (Zustand der Befehlskette, Vorschau der Bahn) noch eine schnellere Kette (Filter 0,85 oder Rate Limiter 2 statt 0,5 rad/s²) machen die Agenten genauer (RMS 12 bis 13 mm in allen Varianten, Faktor gegen die alte Front 2,25 bis 2,69). Die schnellere Kette erhöht nur den Befehlsruck (4- bis 9-fach). Den Regler dagegen bremst die Kette über den Rate Limiter: mit 2 rad/s² 1,4 statt 5,7 mm, der Faktor gegen die eigene Front steigt dann auf 9,5. Die Genauigkeit der Agenten setzt in diesem Aufbau das Lernverfahren, nicht die Schnittstelle. Die Agenten mit dem kleinsten Abstand nutzen den negativen Zweig von J6 | X4.6 (V1 bis V4) | 5 Seeds je Variante, aufbauend, nur Simulation. Nur große Effekte nachweisbar (kleinstes p nach Holm 0,024). V4 nachträglich, gleiche Hyperparameter wie V1 |

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
X5.1: Die gekippte 3D-Bahn ist mit allen sieben Gelenken fahrbar. Bei −30° Kippung macht der Nullraum den
Unterschied (K7). Die Beobachtungsgrenzen aus A72 würden die Policy dort für q7 oft blind machen (E9).
X4.1: Mit 10 Seeds je Gewicht bleibt K2 bestehen, kein Gewicht verschiebt die Basisdrehung, nur der Befehlsruck
steigt mit dem Gewicht. X2.4: Randomisierte Agenten verlieren bei falscher Basismasse kaum noch Bahn, bleiben aber
hinter den Reglern (K8). X1.2: Die Indikator-Kosten sind besser als das Scharnier. Zwei von acht Pilot-Agenten
halten 0,03 rad bei etwa 14 mm, ruhiger und genauer als alle ruhigen r4-Agenten. λ schwingt aber in 3000 Episoden
nicht ein. X1.2b: Mit Blöcken zu 50 Episoden und η 5 halten beide Seeds das Budget (21 und 25 mrad), aber bei
etwa 20 mm. λ bleibt vom Anfang her hoch, die Agenten sind vorsichtiger als nötig. Diese Einstellung geht in X1.3
(E2). X4.2: Alle 95 Bestandsagenten sind nach X0.1 ausgewertet. K1 hält über Takt, J6-Grenze und
Verfahren hinweg. D13 (NaN-Actoren) gehört nicht in die Zahlen des Papers. X1.3: Mit fünf Budgets und 10 Seeds
folgt die Basisdrehung dem Budget (K9). Viele Agenten verlieren dafür die Bahn, bei θ 0,02 brechen drei Agenten
jede Episode ab (A74). Der Abstand zum Regler bleibt. Diagnose: Für ein strenges Budget muss die Policy den
Zweig von J6 finden, den auch der Regler nutzt. X2.2: Kein Agent liegt vor der Front, das Budget ändert den
Abstand nicht. X1.4 Teil 2: Ein Filter auf r1 hält das Budget ähnlich oft, die trainierten Agenten sind genauer,
wenn sie folgen. X4.5 Runde 2: K9a und K1 hängen nicht an den Schwellen, K9b und K9c nur teilweise. X4.6:
Richtige Grenzen, neun Kanäle mehr und ein schnellerer Filter ändern den Abstand zum Regler nicht messbar (K10).
Der Regler verliert durch die Kette nur am Rate Limiter, nicht am Filter (A75). V4: Mit schnellerem Rate
Limiter wird nur der Regler genauer, die Agenten nicht (K10).
Nachträge 13.11.: X0.1 in `SK_desktop` bestätigt K8 für die DR-Agenten. Unter Störungen hält der Filter das
Maximum, die gefilterten Agenten verlieren aber eher die Bahn, die trainierten überschreiten bei Modellfehlern das
Budget (X1.4 Teil 3). In Simscape rechnet der Filter wie kinematisch. Für den Labortag liegt eine Vorhersage je
Kandidat vor (X3.2).

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

### X1.2 Pilot: Kostenform und Schrittweite ✅ 11.11.2026 (E2 nach X1.2b entschieden)

**Frage:** Welche Kostenform (A Indikator, B Scharnier) und welche Schrittweite η der dualen Aktualisierung halten
das Budget θ = 0,03 rad, ohne dass λ schwingt und ohne dass die Bahn verloren geht?

**Aufbau:**
- Training: Schritt 4 der Nachtkette, `ext_x1_2_run()`. θ = 0,03 rad, δ = 0,02, Kosten A und B, η 0,5 und 2,
  Seeds 0 und 1, 30 Blöcke zu 100 Episoden, λ0 = 0. 8 Läufe zu je etwa 23,5 min, alle erfolgreich
  (`X1_2_runlog.csv`).
- Auswertung: `ext_x1_2_eval()`, X0.1 mit 21 Episoden je Agent in `SK_desktop`, dazu D16 r4 Seeds 0–9 als Bezug.
  `ext_eval_agent` gibt dafür neu `cost_mean` aus: das Mittel des Kostensignals je Agentenschritt mit θ und
  Kostentyp aus dem `cfg` des Agenten, also dieselbe Größe wie C im Training, aber mit der deterministischen
  Policy. Für Agenten ohne X1-Felder gilt θ = 0,03 mit Indikator. Die übrigen Kennzahlen bleiben bitgleich
  (D16 wie in X4.1).
- Kennzahlen der dualen Kurven aus `<Name>_dual.csv`: λ am Ende, mittlere Änderung von λ je Block in den letzten
  10 Blöcken, Anzahl Vorzeichenwechsel der λ-Änderung in den letzten 15 Blöcken, C in den letzten 10 Blöcken.

**Ergebnis** (RMS [mm], ori_max Mittel und schlechteste Episode [mrad], Kosten deterministisch, λ und C aus dem
Training):

| Kosten | η | Seed | RMS | ori_max (worst) | Kosten | folgt | Budget | λ Ende | Δλ/Block | C letzte 10 (> δ) |
|---|---|---|---|---|---|---|---|---|---|---|
| A | 0,5 | 0 | 15,3 | 54 (61) | 0,100 | ja | nein | 1,43 | +0,037 | 0,095 (10) |
| A | 0,5 | 1 | 13,6 | 24 (28) | 0 | ja | ja | 0,01 | −0,010 | 0,000 (0) |
| A | 2 | 0 | 12,3 | 62 (71) | 0,114 | ja | nein | 3,72 | +0,129 | 0,085 (10) |
| A | 2 | 1 | 13,7 | 20 (24) | 0 | ja | ja | 3,79 | +0,247 | 0,144 (10) |
| B | 0,5 | 0 | 10,5 | 48 (54) | 0,037 | ja | nein | 0,82 | +0,015 | 0,050 (9) |
| B | 0,5 | 1 | 41,2 | 57 (63) | 0,101 | nein | nein | 0,85 | +0,011 | 0,041 (10) |
| B | 2 | 0 | 226 | 69 (75) | 0,448 | nein | nein | 3,53 | +0,081 | 0,060 (9) |
| B | 2 | 1 | 11,3 | 62 (67) | 0,150 | ja | nein | 1,12 | +0,070 | 0,055 (5) |
| r4 w 2 (D16, 10 Seeds) | – | – | 13,9 (11,6–29,5) | 52 (25–64) | 0–0,26 | 10 von 10 | 2 von 10 | – | – | – |

„Budget“: schlechteste Episode ≤ θ + 5 mrad (wie X4.1). Kosten bei B als Scharnier-Mittel, sonst Anteil der
Schritte über θ.

**Deutung:**
- Kostenform: A ist B in diesem Pilot überlegen. Mit A folgen alle vier Agenten der Bahn und zwei halten das
  Budget. Mit B folgen zwei nicht (41 und 226 mm, B mit η 2 Seed 0 bricht im Training ein, Return am Ende −182)
  und keiner hält das Budget.
- Die zwei Agenten mit Budget (A, Seed 1, beide η) liegen bei 13,6 und 13,7 mm und 24 bzw. 20 mrad. Die sieben
  ruhigen r4-Agenten aus X4.1 brauchen dafür 16,8–29,5 mm. Das spricht dafür, dass eine Nebenbedingung eine ruhige
  Lösung mit weniger Bahnverlust findet. Bei zwei Agenten ist das aber nur ein Hinweis. Beide haben Seed 1, der
  Seed entscheidet also weiter mit.
- Die duale Aktualisierung ist in 3000 Episoden nicht eingeschwungen. In sieben von acht Läufen steigt λ am Ende
  noch (+0,01 bis +0,25 je Block). In sechs Läufen liegt C in mindestens 9 der letzten 10 Blöcke über δ. λ
  schwingt nicht (0 bis 3 Vorzeichenwechsel in 15 Blöcken), es ist zu langsam. Mit η 0,5 bleibt λ unter 1,5, mit
  η 2 erreicht es in drei von vier Läufen 3,5–3,8.
- Muster: Nach dem ersten Block (C 0,45–1,17) fällt C für mehrere Blöcke fast auf null, und λ sinkt wieder.
  Vermutlich ist die Bahn in dieser Phase noch nicht gelernt. Später steigt C, und λ läuft hinterher. A mit
  η 0,5 Seed 1 ist der einzige Lauf, in dem C dauerhaft unter δ bleibt (28 von 30 Blöcken). Dort ist λ am Ende
  praktisch null, die Lösung blieb nach der frühen Phase von selbst ruhig.
- Training gegen Auswertung: C gilt für die Explorations-Policy. Bei A, η 2, Seed 1 liegt C in den letzten
  Blöcken bei 0,14, die deterministische Policy hat 0. Bei den übrigen Läufen passen beide ungefähr zusammen.
- Ruck: Die X1-Agenten liegen bei 8–17 rad/s³, im Bereich von r4 (2,5–16).

**Folgerung für E2 (Vorschlag):** Kosten A. Die Schrittweite allein reicht nicht. Vor X1.3 ein kurzer zweiter
Pilot mit schnellerer dualer Anpassung, damit λ innerhalb des Trainings einschwingt. Siehe PLAN, E2.

**Grenzen:** zwei Seeds je Zelle, nur θ = 0,03, eine Blockgröße. Die Unterschiede zwischen A und B können auch
Seed-Effekte sein.

Datenquelle: `X_eval_X1_2_20261111_150856_*`, `X1_2_summary_*.csv`, `X1_ppo_40hz_r5_*_dual.csv` und `_train.csv`,
`X1_2_runlog.csv`, Log `X2_4_night2_matlab.log` (Schritt 4) und `X1_2_eval_matlab.log`. Agenten
`SavedAgents/MotionProfile/X1/`.

Paper: Methode der Nebenbedingung (Kostenform, Begründung). Offen.

### X1.2b Zweiter Pilot: schnellere duale Anpassung ✅ 11.11.2026 (E2 entschieden)

**Frage:** Hält eine schneller reagierende duale Aktualisierung das Budget θ = 0,03 rad zuverlässiger als X1.2, und
schwingt λ dabei ein?

**Aufbau:**
- Training: `ext_x1_2b_run()`, Kosten A, θ = 0,03 rad, δ = 0,02, Seeds 0 und 1, 3000 Episoden. Zwei Varianten:
  - schnell: Blöcke zu 50 Episoden (60 Aktualisierungen), η 5, λ0 = 1.
  - PID: Blöcke zu 100 Episoden, η 2, Proportionalanteil kp 20 (PID-Lagrange ohne D-Anteil, Stooke et al. 2020).
  Neue Option `kp` in `ext_x1_train`, mit kp = 0 unverändert wie X1.2.
- 4 Läufe, alle erfolgreich. Schnell 26,5 und 28,2 min, PID 23,2 min (`X1_2b_runlog.csv`).
- Auswertung: `ext_x1_2_eval('pattern', 'X1_ppo_40hz_r5_c1_th30_*_ep3000_*.mat', 'study', 'X1_2b', 'ref', false)`,
  X0.1 mit 21 Episoden. Kennzahlen der dualen Kurven wie in X1.2, C und Blöcke über δ aber im letzten Drittel
  des Trainings (schnell: 20 Blöcke zu 50, PID: 10 Blöcke zu 100, also jeweils 1000 Episoden).

**Ergebnis** (RMS [mm], ori_max Mittel und schlechteste Episode [mrad], Kosten der deterministischen Policy, λ und
C aus dem Training, letztes Drittel):

| Variante | Seed | RMS | ep_q4 Median (max) | ori_max (worst) | Kosten | folgt | Budget | λ max | λ Ende | Δλ/Block | C (Blöcke > δ) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| schnell | 0 | 20,0 | 25 (33) | 18 (21) | 0 | ja | ja | 8,05 | 3,59 | −0,098 | 0,001 (0 von 20) |
| schnell | 1 | 20,8 | 30 (34) | 20 (25) | 0 | ja | ja | 5,72 | 3,74 | −0,038 | 0,011 (3 von 20) |
| PID | 0 | 21,1 | 34 (38) | 22 (26) | 0 | ja | ja | 11,72 | 1,09 | −0,035 | 0,007 (0 von 10) |
| PID | 1 | 46,7 | 81 (92) | 25 (31) | 0,0003 | nein | nein | 11,46 | 3,25 | +0,099 | 0,049 (10 von 10) |

Keine Episode bricht ab. „folgt“ und „Budget“ wie in X1.2.

**Deutung:**
- Schnell hält das Budget mit beiden Seeds, PID mit einem. Beim PID-Lauf mit Seed 1 steigt C in der zweiten
  Hälfte über δ (Block 19 bis 30), λ läuft von etwa 2 auf 3,3 hinterher, und der Return fällt von etwa 870 auf
  640. Die Policy verliert dabei die Bahn (ep_q4 81 mm). Die Basis bleibt mit 31 mrad knapp über der Grenze.
- λ schwingt in keiner Variante im eigentlichen Sinn ein. Bei „schnell“ treiben die ersten zwei bis vier Blöcke
  (C 0,34 bis 0,53, die Bahn ist noch nicht gelernt) λ auf 5,7 bzw. 8,1. Danach liegt C meist unter δ (Seed 0
  in 55 von 56 Blöcken, Seed 1 in 43 von 56), und λ sinkt um höchstens η·δ = 0,1 je Block. Am Ende ist λ noch
  3,6 bis 3,7. Die Nebenbedingung ist damit am Ende kaum aktiv, die Agenten bleiben mit 21 und 25 mrad unter θ.
  Beim PID-Lauf fällt λ nach dem Anfang durch den P-Anteil sofort auf 1 bis 2 und folgt danach C. Das ist näher
  am Ziel C ≈ δ, war aber mit Seed 1 zu schwach.
- Preis: Die drei Agenten mit Budget liegen bei 20,0 bis 21,1 mm RMS. Die beiden Budget-Agenten aus X1.2 lagen
  bei 13,6 und 13,7 mm, die sieben ruhigen r4-Agenten aus X4.1 bei 16,8 bis 29,5 mm. Der Hinweis aus X1.2, eine
  Nebenbedingung finde eine ruhige Lösung mit weniger Bahnverlust, wird damit schwächer. Vermutlich hält das
  hohe λ vom Anfang die Policy vorsichtiger als nötig. Das ist eine Vermutung, getestet ist sie nicht.
- Ruck: 10 bis 17 rad/s³, wie in X1.2.

**Entscheidung E2:** Nach der vorher festgelegten Regel („die bessere der beiden Varianten geht in X1.3“) geht
„schnell“ in X1.3: zwei von zwei Seeds folgen und halten das Budget, C liegt im letzten Drittel unter δ. Die
Regel wurde nicht nachträglich geändert, obwohl λ nicht einschwingt. Eine Aufwärmphase ohne duale Anpassung
oder ein kleineres λ0 könnten die Vorsicht senken. Das bleibt eine mögliche spätere Variante und ist nicht Teil
von X1.3.

**Grenzen:** zwei Seeds je Variante, nur θ = 0,03. Die Unterschiede zwischen den Varianten können Seed-Effekte
sein. Die Agenten mit θ = 0,03 und Seed 0 und 1 gehen unverändert in X1.3 ein, weil die Einstellung gleich ist.
Weil die Wahl auf genau diesen zwei Agenten beruht, wird X1.3 für θ = 0,03 auch ohne sie (Seeds 2 bis 9)
angegeben.

Datenquelle: `X_eval_X1_2b_20261111_171748_*`, `X1_2b_summary_20261111_171748.csv`,
`X1_ppo_40hz_r5_c1_th30_*_ep3000_{b50_l1,kp20}_dual.csv` und `_train.csv`, `X1_2b_runlog.csv`, Log
`X1_2b_matlab.log`. Agenten `SavedAgents/MotionProfile/X1/`.

Paper: Methode der Nebenbedingung (duale Einstellung, Begründung), Anhang oder Fußnote zum Pilot. Offen.

### X1.3 Hauptlauf: fünf Budgets und r1 ✅ 13.11.2026

**Frage:** Lässt sich die Basisdrehung über ein vorgegebenes Budget θ steuern, anders als über das Gewicht (K2)?
Wie zuverlässig halten die Agenten das Budget, und was kostet es an Bahn?

**Aufbau:**
- Training: `ext_x1_3_run()`, 11.11. 17:22 bis 12.11. 19:54. Einstellung „schnell“ aus X1.2b (Kosten A, δ 0,02,
  Blöcke zu 50 Episoden, η 5, λ0 = 1, 3000 Episoden). θ ∈ {0,02; 0,03; 0,04; 0,05; 0,06} rad × Seeds 0–9.
  θ 0,03 mit Seed 0 und 1 sind die Agenten aus X1.2b.
- Bezug r1: derselbe Aufbau mit λ fest 0 (η 0, λ0 0, Blöcke zu 50), Seeds 0–9. Bezug r4 w 2: D16 Seeds 0–9.
- 58 neue Läufe, alle erfolgreich, 15 bis 34 min, im Mittel etwa 27 min (`X1_3_runlog.csv`).
- Auswertung: X0.1 mit 21 Episoden je Agent in `SK_desktop` (`ext_x1_2_eval`, Studie X1_3, 70 Agenten in
  13,5 min). Zusammenfassung `ext_x1_3_report()`, ohne neues Rechnen.
- Definitionen wie X1.2 und X4.5: „folgt“ = keine Episode bricht ab und ep_q4 < 5 cm in allen 21 Episoden.
  „Budget“ = folgt und schlechteste Episode ori_max ≤ θ + 5 mrad. „Basis im Budget“ = schlechteste Episode
  ≤ θ + 5 mrad, auch ohne folgt.

**Ergebnis** (10 Agenten je Zeile, Median und IQR über die Agenten, RMS [mm], ori_max [mrad]):

| Gruppe | folgt | Budget | Basis im Budget | alle Episoden abgebrochen | RMS | ori_max | schlechteste Episode (Median) | λ Ende (Median) |
|---|---|---|---|---|---|---|---|---|
| θ 0,02 | 3 | 3 | 6 | 3 | 89,8 (36,1–194,4) | 19,0 (13,4–22,1) | 22,1 | 12,4 |
| θ 0,03 | 5 | 5 | 9 | 0 | 24,3 (20,0–66,3) | 23,4 (20,2–24,9) | 29,1 | 3,7 |
| θ 0,03 ohne Seed 0, 1 (8) | 3 | 3 | 7 | 0 | 29,7 (20,8–78,4) | 24,3 (22,0–25,2) | 29,5 | 3,8 |
| θ 0,04 | 4 | 1 | 6 | 0 | 42,0 (16,1–50,4) | 36,2 (24,6–41,8) | 41,9 | 4,9 |
| θ 0,05 | 7 | 5 | 6 | 0 | 21,9 (17,5–28,5) | 45,4 (36,3–50,2) | 51,3 | 2,3 |
| θ 0,06 | 8 | 7 | 8 | 0 | 15,3 (14,3–36,4) | 52,1 (43,0–57,7) | 58,8 | 0,5 |
| r1 (λ = 0) | 7 | – | – | 0 | 19,6 (14,7–28,7) | 59,5 (49,8–73,2) | 67,0 | 0 |
| r4 w 2 (D16) | 10 | – | – | 0 | 13,9 (12,2–16,6) | 52,5 (48,8–61,9) | 58,1 | – |

Budget-Anteil gegen die Bezüge bei demselben θ (Fisher exakt, Holm über die fünf Budgets):

| θ | X1.3 | r1 | X4.1 (alle 50) | p Holm gegen r1 | p Holm gegen X4.1 |
|---|---|---|---|---|---|
| 0,02 | 3/10 | 0/10 | 0/50 | 0,56 | 0,018 |
| 0,03 | 5/10 | 1/10 | 4/50 | 0,56 | 0,018 |
| 0,04 | 1/10 | 1/10 | 6/50 | 1 | 1 |
| 0,05 | 5/10 | 1/10 | 11/50 | 0,56 | 0,34 |
| 0,06 | 7/10 | 2/10 | 38/50 | 0,35 | 1 |

Spearman über die 50 Budget-Agenten:
- θ gegen ori_max: ρ = 0,70 (p 1e-8). Nur die 27 folgenden Agenten: ρ = 0,77 (p 3e-6). Zum Vergleich K2:
  Gewicht gegen ori_max ρ = −0,18.
- θ gegen RMS: ρ = −0,40 (p 0,004). Nur die folgenden: ρ = −0,21 (p 0,30).

λ am Ende ist bei den nicht folgenden Agenten höher (Median 6,0 gegen 2,2, Mann-Whitney p 8e-5), ebenso C im
letzten Drittel (0,020 gegen 0,006, p 2e-4). Die Kosten der deterministischen Policy liegen bei 5, 9, 6, 7 und 8
von 10 Agenten (θ 0,02 bis 0,06) unter δ.

**Deutung:**
- **Das Budget steuert die Basisdrehung.** Die Basisdrehung folgt θ eng (ρ 0,70, bei den folgenden 0,77). Der
  Median von ori_max steigt von 19 auf 52 mrad, die schlechteste Episode liegt im Median knapp unter θ (22,1 bei
  θ 0,02, 29,1 bei θ 0,03). Mit dem Gewicht ging das in X4.1 nicht (ρ −0,18). Das ist der Unterschied, den X1
  zeigen sollte.
- **Der Preis ist die Bahn, nicht die Genauigkeit.** Nur 27 von 50 Agenten folgen der Bahn. Bei r1 sind es 7 von
  10, bei r4 10 von 10. Wer folgt, ist kaum ungenauer als ohne Budget. Der Median des RMS der folgenden Agenten
  liegt je Budget bei 14,8 bis 20,0 mm, bei r1 bei 15,9 und bei r4 bei 13,9 mm. Unter den folgenden hängt der RMS
  kaum von θ ab (ρ −0,21, p 0,30). Die strengen Budgets erhöhen also vor allem den Anteil der Agenten, die die
  Bahn in der zweiten Hälfte verlieren (ep_q4 bis 177 mm), während die Basis ruhig bleibt. Basis im Budget sind
  35 von 50,
  Budget mit Bahn nur 21 von 50.
- **Gegen die Gewichtsreihe:** Bei θ 0,02 und 0,03 halten mit Budget deutlich mehr Agenten Bahn und Basis
  zugleich (3/10 und 5/10 gegen 0/50 und 4/50, Holm p 0,018). Ab 0,04 gibt es keinen Unterschied, dort reicht
  auch die Gewichtsreihe oft. Gegen r1 ist kein Unterschied gesichert, mit 10 Agenten je Seite ist der Test
  schwach (0 bis 2 von 10 bei r1).
- **θ 0,04 fällt aus der Reihe.** Vier Agenten folgen, aber drei davon liegen mit 47 bis 52 mrad über θ + 5 mrad.
  Die Nebenbedingung begrenzt den Anteil der Schritte über θ auf 2 %, nicht das Maximum. Kurze Spitzen über θ
  sind damit erlaubt, die Auswertung misst aber das Maximum. Bei θ 0,05 und 0,06 betrifft das zwei bzw. einen
  der folgenden Agenten, jeweils knapp (55,1 und 55,4 bei Grenze 55, 67,8 bei Grenze 65). Mit 10 Agenten kann
  θ 0,04 auch Zufall sein.
- **Kollaps bei θ 0,02 (A74).** Bei Seed 2, 8 und 9 bricht jede der 21 Episoden ab (EE mehr als 0,5 m von der
  Bahn), im Training auch 100 % der letzten 1000 Episoden. Seed 3 bricht im Training in 29 % ab. λ steigt dort
  auf 11 bis 20. Vermutete Ursache: Der Abbruch kostet einmalig −50, jeder Schritt über θ aber λ. Bei λ ≈ 16
  ist ein früher Abbruch für den Agenten billiger als der Rest der Episode. Geprüft ist das nicht. Die Kostenrate
  C verdeckt das, weil abgebrochene Episoden kurz sind.
- **Hohes λ geht mit Bahnverlust einher** (Median 6,0 gegen 2,2). Die Richtung ist offen. Ein Agent, der das
  Budget schwer erreicht, treibt λ hoch, und ein hohes λ kann die Bahn verdrängen.
- **Abstand zum Regler bleibt.** Die besten Agenten mit Budget liegen bei 14,6 mm und 23,8 mrad (θ 0,02,
  Seed 1) und 13,3 mm und 29,7 mrad (θ 0,03, Seed 6). Der Regler mit exaktem Modell erreicht 5,7 mm bei 20 mrad
  (K5). Die Front aus X2.2 steht noch aus.
- **Streuung der Basisdrehung:** Der IQR von ori_max bei θ 0,03 ist 4,7 mrad (Bootstrap 95 % 0,8–27,9), bei r1
  23,4 (9,4–93,2) und bei r4 13,1 (1,7–37,3). Die Intervalle sind breit, ein Unterschied in der Streuung ist mit
  10 Agenten nicht gesichert.
- **Pilot-Agenten:** Ohne Seed 0 und 1 halten bei θ 0,03 drei von acht das Budget statt fünf von zehn. Die
  Auswahl aus X1.2b hat das Ergebnis bei θ 0,03 also etwas geschönt, die Aussage ändert sich nicht.
- Ruck: Median 14,9 bis 16,3 rad/s³ mit Budget, 13,9 bei r1, 7,2 bei r4 w 2.

**Grenzen:** 10 Seeds je Budget, ein Pfad, nur Simulation. Das Budget ist als Anteil der Schritte formuliert,
nicht als Maximum. Der Kollaps bei θ 0,02 ist nur vermutet erklärt. Die duale Einstellung stammt aus einem Pilot
mit zwei Seeds.

Datenquelle: `X_eval_X1_3_20261112_195325_*`, `X1_3_summary_20261112_195328.csv`,
`X1_3_report_{groups,fisher,spearman,lambda,agents}_20261113_001140.csv`, `X1_ppo_40hz_r5_c1_th*_*_b50*_dual.csv`
und `_train.csv`, `X1_3_runlog.csv`, Log `X1_3_matlab.log`. Agenten `SavedAgents/MotionProfile/X1/`.

Paper: neuer Hauptabschnitt zur Nebenbedingung (Abbildung Bahnfehler gegen Basisdrehung, Tabelle je Budget),
Vergleich mit K2. Offen.

**Nachtrag 13.11.2026: Diagnose des Bahnverlusts.** Frage: Warum verlieren 23 von 50 Budget-Agenten die Bahn?
- Aufbau: `ext_x1_3_diag()`. Je Agent (60 aus X1.3, D16 r4 Seeds 0–9 als Bezug) eine nominale Episode in
  `ext_kinsim` (J6 0,9774 rad/s, Start q0 = 0). Gemessen: Zeitpunkt, ab dem der EE-Fehler 5 cm übersteigt, Anteil
  gesättigter Befehle (J2, J4, J6), Anteil der Zeit an der Winkelgrenze, Verlauf von q6, Begrenzung der
  Beobachtung (A72). „folgt“ kommt aus X0.1 in `SK_desktop` (21 Episoden).
- Gegenprobe Simulator: Der nominale RMS stimmt bei 52 von 70 Agenten auf 1 mm mit `SK_desktop` überein, bei
  sechs Agenten weicht er 3,8 bis 10,1 mm ab. Das ist mehr als bei der Validierung in X0.2 (≤ 0,45 mm).
  Vermutlich verstärken die vielen gesättigten Befehle kleine Unterschiede. Geprüft ist das nicht.
- **Zweig von J6.** Läuft J6 in Richtung −2,01 rad („neg“, q6 erreicht ≤ −1,5 rad), braucht die Bahn wenig
  Basisdrehung. Diesen Zweig nutzt auch der Regler (X2.1, A73). Läuft J6 in Richtung +2,01 rad („pos“), liegt
  die Basis bei etwa 50 mrad. „mid“ heißt, q6 bleibt zwischen −1,5 und +1,5 rad.

| Gruppe | neg (folgt) | mid (folgt) | pos (folgt) |
|---|---|---|---|
| θ 0,02 | 5 (3) | 4 (0) | 1 (0) |
| θ 0,03 | 8 (5) | 1 (0) | 1 (0) |
| θ 0,04 | 4 (2) | 4 (0) | 2 (2) |
| θ 0,05 | 4 (3) | 4 (2) | 2 (2) |
| θ 0,06 | 3 (2) | 3 (2) | 4 (4) |
| r1 | 4 (2) | 3 (2) | 3 (3) |
| r4 w 2 | 1 (1) | 1 (1) | 8 (8) |

- Deutung Zweig: Die r4-Agenten nehmen fast alle den positiven Zweig (8 von 10). Mit Budget nehmen nur 10 von 50
  diesen Zweig, und die folgenden darunter liegen alle bei θ ≥ 0,04 (Basis 40 bis 52 mrad). Bei θ 0,02 und 0,03
  folgt kein Agent ohne den negativen Zweig (0 von 7), mit ihm 8 von 13 (Fisher p 0,015). Für ein strenges
  Budget muss die Policy also den Zweig finden, den der Regler nutzt. Von den 20 Agenten bei θ 0,02 und 0,03
  finden ihn 7 nicht und verlieren alle die Bahn, 5 finden ihn und verlieren sie trotzdem, 8 folgen.
- Sättigung: Die Budget-Agenten und r1 geben je Gruppe im Median in 11 bis 74 % der Schritte Befehle an der
  Geschwindigkeitsgrenze, die r4-Agenten in etwa 1 % (einzelne bis 32 %). Folgende und nicht folgende
  Budget-Agenten unterscheiden sich darin kaum (J6 0,21 gegen 0,36, p 0,04, J2 und J4 p ≥ 0,8). Nach dem Verlust
  der Bahn stehen die Befehle im Mittel bei 88 % der Grenze, die Policy gibt also nicht auf, sie kommt nicht
  hinterher.
- Zeitpunkt: Die nicht folgenden verlassen die 5-cm-Grenze im Median bei 5,9 s (von 8,5 s), die drei
  kollabierten Agenten bei θ 0,02 schon bei 1,0 bis 1,8 s (A74). Auch die folgenden überschreiten 5 cm oft kurz
  vor dem Ende (Median 7,6 s, Fehler am Ende 26 mm gegen 168 mm).
- Beobachtungsgrenzen (A72): Auf dem negativen Zweig liegt q6 jenseits der Grenze ±1,22 rad. Die folgenden
  Budget-Agenten sehen q6 deshalb in 35 % der Schritte begrenzt, die nicht folgenden in 3 % (p 0,008). Die
  Policy ist auf dem günstigen Zweig für q6 also teilweise blind. Ob das den Bahnverlust mit verursacht, prüft
  die Ablation X4.6 (Variante V1 mit korrigierten Grenzen).
- Grenzen: eine nominale Episode je Agent, Zweig aus dem Simulator, „folgt“ aus 21 Episoden in `SK_desktop`.

Datenquelle: `X1_3_diag_{agents,groups,tests,branch,fisher}_20261113_084339.csv`.

### X1.4 Sicherheitsfilter, Teil 1: vorhandene Agenten ✅ 10.11.2026

**Frage:** Hält ein modellbasierter Filter das Budget auch für eine Policy ohne passendes Training, und was kostet
das an Tracking?

**Aufbau:**
- `ext_x1_shield`: h = θ² − φ² mit φ = Basisdrehung um y (Komponente des Drehvektors), Bedingung ḣ ≥ −α·h. Mit
  der verallgemeinerten Jacobi-Matrix (Nominalmodell) eine lineare Ungleichung in q̇. Bei Verletzung kleinste
  euklidische Korrektur der Geschwindigkeiten von J2, J4, J6, danach Sättigung.
- Zwei Orte: nach der Befehlskette (Hook in `ext_kinsim`, kann die Beschleunigungsgrenze verletzen) und vor der
  Kette (Korrektur der Rohaktion, Kette bleibt eingehalten, wirkt verzögert).
- `ext_x1_4_eval()`: θ ∈ {0,02; 0,03; 0,04; 0,05} rad, α ∈ {1; 5} 1/s. Agenten: 20 r4-Agenten (J6 0,9774) und als
  Ersatz für die r1-Agenten aus X1.3 die drei r1-Agenten aus D14 (nur Tracking, J6 0,1). 391 Episoden, nominal,
  kinematischer Simulator. „Hält das Budget“: folgt der Bahn und größte Basisdrehung ≤ θ + 0,005 rad.

**Ergebnis r4-Agenten** (ohne Filter: RMS Median 12,2 mm, Basis Median 51 mrad, 20/20 folgen, Ruck 9,3):

| Ort | θ [rad] | α | RMS Median (Δ) [mm] | Basis Median / Max [mrad] | folgt | hält Budget | Eingriff |
|---|---|---|---|---|---|---|---|
| nach | 0,02 | 5 | 22,9 (+10,4) | 19,6 / 20,3 | 18/20 | 18/20 | 15 % |
| nach | 0,03 | 5 | 17,2 (+4,0) | 29,6 / 30,2 | 19/20 | 19/20 | 11 % |
| nach | 0,04 | 5 | 13,7 (+0,5) | 39,5 / 40,1 | 20/20 | 20/20 | 7 % |
| nach | 0,03 | 1 | 20,0 (+6,6) | 25,5 / 29,6 | 19/20 | 19/20 | 17 % |
| vor | 0,03 | 1 | 18,2 (+4,9) | 28,7 / 36,0 | 19/20 | 18/20 | 18 % |
| vor | 0,03 | 5 | 15,9 (+1,6) | 33,9 / 39,8 | 19/20 | 10/20 | 13 % |

- Nach der Kette hält der Filter das Budget praktisch exakt (größte Basisdrehung höchstens 0,3 mrad über θ). Die
  Agenten, die dabei die Bahn verlieren, sind dieselben, die schon ohne Filter am Rand lagen. Der Ruck steigt nicht.
- Vor der Kette reicht die Korrektur wegen Filter und Rate Limiter oft nicht. Mit α = 5 hält nur die Hälfte das
  Budget von 0,03 rad, mit α = 1 fast alle.
- Vergleich mit dem Regler (X2.1): Bei 0,020 rad hat der Regler 5,7 mm, die gefilterten Agenten im Median 22,9 mm.
  Der Filter macht die Budgets verlässlich, an der Lücke zur Front ändert er wenig.
- Für X1.3 ist das die Messlatte: Die Nebenbedingung im Training muss das Budget ähnlich zuverlässig halten wie
  der Filter, und das mit weniger Bahnfehler.

**Ergebnis r1-Agenten aus D14 (J6 0,1):** Ohne Filter 10,2 mm bei 79 mrad. Mit Filter wird das Budget gehalten,
aber für θ ≤ 0,04 folgt keiner mehr der Bahn (24–67 mm). Mit J6 0,1 rad/s braucht die Bahn etwa 0,06 rad
(X2.1, D15). Der Filter zeigt hier also die Grenze der Physik, nicht seine eigene. Die r1-Agenten aus X1.3 mit
J6 0,9774 folgen später.

**Noch offen in X1.4:** r1-Agenten aus X1.3, Filter unter den Störungen aus X2.3 (falsches Modell, Verzögerung),
drei Fälle in Simscape.

Datenquelle: `X1_4_eval_20261110_130405.csv`.

Paper: Abschnitt Nebenbedingung (Vergleich Filter gegen Training). Offen.

### X1.4 Sicherheitsfilter, Teil 2: r1-Agenten aus X1.3 ✅ 13.11.2026

**Frage:** Hält der Filter auf den r1-Agenten (gleicher Aufbau wie X1.3, nur λ = 0) das Budget ähnlich oft wie die
Nebenbedingung im Training, und was kostet es an Bahn?

**Aufbau:**
- `ext_x1_4_eval('set', 'x13_r1', 'thetas', [0.02 0.03 0.04 0.05 0.06])`: die zehn r1-Agenten aus X1.3,
  θ wie in X1.3, α ∈ {1; 5} 1/s, Filter nach und vor der Kette. 210 Episoden in 2,3 min, nominal, kinematisch.
- Zusammenfassung `ext_x1_4_report('20261113_084820', 'x13', '20261112_195325', 'diag', '20261113_084339')`.
- Vergleich im selben Protokoll: die Budget-Agenten aus X1.3 in derselben nominalen Episode im Simulator (aus
  `ext_x1_3_diag`). Dazu die X0.1-Zahlen aus `SK_desktop` (21 Episoden mit Startstörung).
- r1 ohne Filter, nominal: 9 von 10 folgen, RMS Median 16,3 mm, Basis 60 mrad. In X0.1 folgen 7 von 10.

**Ergebnis** (Filter nach der Kette, α 5; „Budget“ = folgt und größte Basisdrehung ≤ θ + 5 mrad; RMS der folgenden
als Median [mm]):

| θ | Filter: Budget | Filter: RMS der folgenden | Filter: größte Basis [mrad] | Eingriff | Training: Budget nominal | Training: RMS der folgenden nominal | Training: Budget X0.1 |
|---|---|---|---|---|---|---|---|
| 0,02 | 4/10 | 22,3 | 21,6 | 36 % | 3/10 | 13,4 | 3/10 |
| 0,03 | 5/10 | 21,9 | 31,4 | 24 % | 6/10 | 19,7 | 5/10 |
| 0,04 | 7/10 | 23,5 | 41,3 | 17 % | 4/10 | 12,5 | 1/10 |
| 0,05 | 8/10 | 21,2 | 50,3 | 11 % | 7/10 | 18,2 | 5/10 |
| 0,06 | 8/10 | 14,8 | 60,5 | 3 % | 8/10 | 12,4 | 7/10 |

**Deutung:**
- Filter und Training halten das Budget etwa gleich oft (Filter 32 von 50, Training nominal 28 von 50). Ein
  Test lohnt mit 10 Agenten je Zelle nicht.
- Nach der Kette hält der Filter das Maximum fast exakt (höchstens 1,6 mrad über θ). Die trainierten Agenten
  halten nur einen Anteil der Schritte, nicht das Maximum (siehe X1.3, θ 0,04).
- Wer mit Filter folgt, hat im Median 21 bis 24 mm (θ ≤ 0,05). Die trainierten Agenten, die folgen, liegen bei
  12 bis 20 mm. Das Training findet also eine genauere Lösung, wenn es eine findet. Vermutlich, weil der Filter
  nur den Befehl korrigiert und die Strategie der Policy (etwa den Zweig von J6) nicht ändert. Geprüft ist das
  nicht.
- Vor der Kette hält der Filter das Maximum schlechter (bis 52,6 mrad bei θ 0,04), wie in Teil 1.
- Ruck: 11,6 bis 13,9 rad/s³ mit Filter, r1 in X0.1 13,9.
- Der Filter braucht das Modell zur Laufzeit, die Nebenbedingung nur im Training. Damit gilt für den Filter
  auch die Frage der Robustheit (X2.3, offen).

**Grenzen:** eine nominale Episode je Agent, nur kinematisch, 10 Agenten. Die Startstörungen aus X0.1 fehlen
für den Filter.

Datenquelle: `X1_4_eval_20261113_084820.csv`, `X1_4_report_20261113_084820.csv`,
`X1_3_diag_agents_20261113_084339.csv`.

Paper: Abschnitt Nebenbedingung (Filter gegen Training). Offen.

### X1.4 Sicherheitsfilter, Teil 3: Störungen und Simscape ✅ 13.11.2026

**Frage:** Hält der Filter das Budget auch, wenn Modell, Aktor, Sensor oder Anfangszustand nicht stimmen? Und
rechnet der kinematische Simulator den Filter so wie Simscape?

**Aufbau Störungen:** `ext_x1_4_robust()`. Die zehn r1-Agenten aus X1.3 mit `ext_x1_shield` nach der Kette (α 5,
θ 0,02 bis 0,06, Nominalmodell). Neu: Der Filter nimmt q und e_ori aus der Beobachtung, also mit Rauschen und
Messfehler der Szenarien (Option `measured` in `ext_x1_shield`, Feld `obs` im Hook von `ext_kinsim`, sonst
unverändert). Die 26 Szenarien aus X2.3 (`ext_x2_robust`, neue Option `shield`), 2546 Episoden in 10,9 min,
kinematisch. Vergleich mit den trainierten Budget-Agenten aus X2.3 Teil 2 (`X2_robust_20261113_090316`).
Definitionen wie dort: Budget-Agenten sind die, die nominal folgen und ori_max ≤ θ + 5 mrad halten. Budget gehalten
heißt in einem Störszenario weiter folgen und das Budget halten (25 Störszenarien je Agent). Gegenprobe: Der
Hook mit dem wahren Zustand trifft X1.4 Teil 2 exakt (r1 Seed 0, θ 0,03: 21,918 mm, 30,064 mrad).

| θ | Filter: Agenten | Filter: Budget gehalten | Filter: folgt | Filter: größte Überschreitung [mrad] | Filter: RMS [mm] | Training: Agenten | Training: Budget gehalten | Training: folgt | Training: größte Überschreitung [mrad] | Training: RMS [mm] |
|---|---|---|---|---|---|---|---|---|---|---|
| 0,02 | 4 | 73 % | 77 % | 9,5 | 23,2 | 3 | 88 % | 100 % | 19,2 | 17,6 |
| 0,03 | 5 | 76 % | 76 % | 4,1 | 21,9 | 6 | 90 % | 98 % | 18,5 | 20,5 |
| 0,04 | 7 | 78 % | 78 % | 3,5 | 22,6 | 4 | 74 % | 98 % | 39,8 | 14,8 |
| 0,05 | 8 | 86 % | 86 % | 2,9 | 21,9 | 7 | 84 % | 97 % | 50,5 | 18,8 |
| 0,06 | 8 | 91 % | 91 % | 2,4 | 18,5 | 8 | 85 % | 100 % | 65,5 | 14,6 |

„folgt“ über alle nominal folgenden Agenten der Gruppe, RMS als Median der Paare mit gehaltenem Budget.

- Beide halten das Budget etwa gleich oft (Filter 73 bis 91 %, Training 74 bis 90 %), sie scheitern aber
  verschieden. Der gefilterte Agent hält das Maximum fast immer und verliert dafür die Bahn. Ab θ 0,03 ist
  „Budget gehalten“ gleich „folgt“, wer folgt, hält also auch das Budget. Die größte Überschreitung liegt bei
  2,4 bis 4,1 mrad. Der trainierte Agent folgt fast immer (97 bis 100 %), überschreitet das Budget aber bei
  Modellfehlern deutlich (bis 65 mrad bei θ 0,06).
- Schwächste Szenarien des Filters: Drift um x bei θ 0,02 (0 von 4), fester Lagefehler 10 mrad bei θ 0,02
  (1 von 4, daher die 9,5 mrad, der Filter hält die gemessene Lage ein), leichte Basis (Masse ×0,25,
  Trägheit ×0,5) und 50 ms Verzögerung (θ 0,03: 2 von 5). Schwächste des Trainings: Masse ×0,25 und ×0,5,
  Trägheit ×0,5, Drift y +2 mrad/s (meist 0 bis 33 %). Je Szenariogruppe hält das Training bei Sensor- und
  Aktorfehlern das Budget in 95 bis 100 %, der Filter in 69 bis 100 %. Bei Modellfehlern ist es umgekehrt
  (Training 58 bis 86 %, Filter 71 bis 88 %).
- Wer mit Filter das Budget hält, fährt 18 bis 23 mm, die trainierten Agenten 15 bis 21 mm (wie nominal, X1.4
  Teil 2).

**Aufbau Simscape:** `ext_x1_4_simscape()`. Modellkopie `SK_x14` (`ext_x1_4_build_model`, `SK_desktop` mit
MATLAB-Function-Block `Shield` zwischen Cmd Scale und Rate Transition). Der Block ruft extrinsisch
`ext_x1_4_sim_shield` auf, also denselben Filter. q und e_ori aus dem Ausgang von Obs Transform im selben
Agentenschritt. Sechs Fälle, nominal, α 5. Gegen `ext_kinsim` mit dem Hook. `SK_desktop` vorher und nachher mit
derselben Prüfsumme.

| Fall | Eingriff Simscape / kinematisch | RMS Simscape / kinematisch [mm] | ori_max Simscape / kinematisch [mrad] | folgt |
|---|---|---|---|---|
| r1 s3, θ 0,03 | 13,8 % / 13,8 % | 13,70 / 13,86 | 29,45 / 29,41 | ja / ja |
| r1 s5, θ 0,02 | 28,7 % / 28,4 % | 23,97 / 24,00 | 20,04 / 20,04 | ja / ja |
| r1 s0, θ 0,04 | 24,0 % / 24,0 % | 14,06 / 14,07 | 40,06 / 40,06 | ja / ja |
| r1 s0, θ 0,02 | 39,6 % / 39,6 % | 41,76 / 41,52 | 20,07 / 20,07 | nein / nein |
| r1 s1, θ 0,03 | 19,6 % / 19,4 % | 46,56 / 42,81 | 30,07 / 30,07 | nein / nein |
| r1 s2, θ 0,05 | 0 / 0 | 25,23 / 29,43 | 29,48 / 28,90 | ja / ja |

- In den ersten drei Fällen (Agent folgt, Filter greift oft ein, ohne Filter stimmen beide Simulatoren überein)
  liegen RMS höchstens 0,16 mm und ori_max höchstens 0,04 mrad auseinander. Das Maximum hält der Filter in
  Simscape genauso wie kinematisch.
- s1 und s2 weichen schon ohne Filter um 1,8 und 4,2 mm ab (stark gesättigte Agenten, X1.3), s2 hier ganz ohne
  Eingriff. Die Abweichung kommt also vom Agenten, nicht vom Filter.

**Grenzen:** 3 bis 8 Agenten je Zelle, kinematisch. Der Filter kennt nur das Nominalmodell, sieht aber die
gemessene Lage. Rauschen auf q und e_ori geht ungefiltert in die Barriere ein. In Simscape nur nominal.

Datenquelle: `X2_robust_20261113_175514_*`, `X1_4_robust_{groups,sgroups,scen}_20261113_175514.csv`, Log
`X1_4_robust_matlab.log`, `X1_4_simscape_*.csv`, Modell `evaluation/desktop/models/SK_x14.slx`.

Paper: Abschnitt Nebenbedingung (Filter gegen Training, Robustheit beider). Offen.

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

### X2.2 Abstand der Agenten zur Front ✅ 13.11.2026

**Frage:** Wie weit liegt jeder RL-Agent aus X1.3 und X4.1 hinter der modellbasierten Front, und bringt das Budget
die Agenten näher an die Front?

**Aufbau:**
- `ext_x2_2_front()`, kein neues Rechnen. Front aus den Sweeps von X2.1: volle Kette mit Inversion, J6
  0,9774 rad/s, Läufe, die folgen (wie X0.1). F0 nur der Sweep aus X2.1 (14 Pareto-Punkte, Grundlage von K5),
  F mit der Rückführung der Basislage dazu (20 Punkte).
- Agenten: 50 Budget-Agenten und 10 r1 aus X1.3, 50 Agenten der Gewichtsreihe X4.1. Zwei Lesarten: die nominale
  Episode aus X0.1 (gleicher Start wie die Front) und das Mittel über 21 Episoden.
- Faktor wie in X2.3: RMS des Agenten geteilt durch den kleinsten RMS der Front bei höchstens derselben
  Basisdrehung. Dazu das Verhältnis der Basisdrehung bei höchstens demselben RMS.

**Ergebnis** (nur folgende Agenten, nominale Episode, Front F0; Median und Bereich):

| Gruppe | folgen | Faktor | zusätzlicher RMS [mm] | Basis / Basis der Front bei gleichem RMS |
|---|---|---|---|---|
| θ 0,02 | 3 | 2,1 (2,0–3,8) | 6,6 | 2,1 |
| θ 0,03 | 5 | 3,0 (1,8–4,5) | 11,3 | 3,2 |
| θ 0,04 | 4 | 2,2 (1,9–2,6) | 7,0 | 4,1 |
| θ 0,05 | 7 | 2,8 (2,1–4,1) | 10,0 | 5,8 |
| θ 0,06 | 8 | 2,0 (1,5–6,2) | 5,9 | 4,7 |
| r1 | 7 | 2,6 (1,5–8,4) | 8,9 | 5,8 |
| X4.1 w 0 bis w 16 | 9–10 je Gewicht | 1,9–2,6 (1,4–5,8) | 5,1–7,4 | 4,2–5,9 |

- Kein folgender Agent (83) liegt vor der Front, der kleinste Faktor ist 1,37 (F0) bzw. 1,50 (F). Im Mittel
  über 21 Episoden sind die Faktoren größer (Median je Gruppe 2,5 bis 4,3).
- Budget gegen Gewichtsreihe (Mann-Whitney, folgende Agenten): Faktor 2,39 gegen 2,20, p 0,34 (nominal), 3,02
  gegen 2,63, p 0,16 (Mittel). Gegen r1: p 0,61 bzw. 0,14.
- Die Front F mit Rückführung der Basislage macht die Faktoren um etwa 0,1 bis 0,3 größer, an der Aussage ändert
  sich nichts.

**Deutung:**
- Das Budget verschiebt die Agenten entlang der Front, nicht auf sie zu. Sie werden ruhiger, ihr Abstand zur
  Front bleibt etwa gleich (Faktor um 2 bis 3). Bei gleichem Bahnfehler dreht der Regler die Basis zwei- bis
  sechsmal weniger.
- Der Abstand zum Regler ist damit keine Frage der Gewichtung oder der Nebenbedingung. X4.6 prüft, ob er an der
  Beobachtung (A72) oder an der Befehlskette liegt.

**Grenzen:** Die Front ist eine schrittweise Lösung mit exaktem Modell und vorgegebenem Zweig von J6, also
eine obere Schranke für den Regler. Die Agenten laufen in `SK_desktop`, die Front im kinematischen Simulator
(X0.2, ≤ 0,45 mm).

Datenquelle: `X2_2_{front,agents,groups,tests}_20261113_083657.csv`, Sweeps `X2_sweep_20261110_113752.csv` und
`X2_sweep_20261110_123011.csv`.

Paper: Abbildung Bahnfehler gegen Basisdrehung (Front, Budgets, Gewichtsreihe), Ergebnisabschnitt. Offen.

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

**Nachtrag 10.11.2026: Regler mit Rückführung der Basislage.** Gewünschte Basis-Winkelgeschwindigkeit
w* = −kOri·e_ori statt 0 (`ext_x2_controller`, Option `kOri`).
- Nominal (`ext_x2_sweep` mit kOri 0 / 0,5 / 1 / 2 / 5, volle Kette mit Inversion, J6 0,9774, Kp 5, 90 Läufe,
  `X2_sweep_20261110_123011.csv`): Die Front verschiebt sich wenig. kOri 0,5 findet ohne Vorgabe der J6-Seite den
  günstigen Zweig (5,3 mm / 21 mrad statt 7,0 mm / 59 mrad). kOri 5 mit großem β verbessert den ruhigen Rand
  (22,6 mm / 4,6 mrad, 25,9 mm / 2,5 mrad gegen 24 mm / 6,0 mrad ohne Rückführung).
- Robustheit (`ext_x2_robust` mit drei zusätzlichen Reglern, 1026 Episoden, `X2_robust_20261110_123757_*`):

| Szenario | Rβ 1 | Rβ 1, kOri 0,5 | Rβ 46 | Rβ 46, kOri 0,5 | Rβ 46, kOri 5 |
|---|---|---|---|---|---|
| nominal | 5,7 / 20 | 5,4 / 20 | 12,8 / 8 | 11,9 / 9 | 22,6 / 5 |
| Drift y −2 mrad/s | 5,3 / 27 | 3,1 / 17 | 11,0 / 23 | 10,9 / 10 | 36,2 / 5 ✗ |
| Drift y +2 mrad/s | 6,2 / 44 | 7,4 / 43 | 14,9 / 31 | 20,8 / 25 | 56,6 / 10 ✗ |
| Drift x 2 mrad/s | 13,1 / 26 | 13,1 / 26 | 17,4 / 19 | 16,8 / 19 | 18,7 / 18 |
| Verzögerung +50 ms | 7,6 / 21 | 7,4 / 19 | 13,4 / 8 | 14,7 / 10 | 40,9 / 7 ✗ |
| Servo τ 50 ms | 7,9 / 21 | 7,6 / 18 | 13,6 / 8 | 16,2 / 10 | 40,4 / 7 ✗ |
| Rauschen ×1 | 5,7 / 20 | 6,6 / 18 | 12,4 / 9 | 12,1 / 10 | 41,3 / 7 ✗ |

  RMS [mm] / größte Basisdrehung [mrad], ✗ = in mindestens einer Wiederholung nicht gefolgt.
- Mit kOri 0,5 sind bei der Gegendrift alle 20 Agenten dominiert (vorher 5 nicht dominiert). Nur bei Montage
  z +5 cm bleibt ein Agent nicht dominiert.
- Mit kOri 5 folgt der Regler in 15 von 26 Szenarien nicht in jeder Wiederholung. Betroffen sind Verzögerung 50 ms,
  Servo τ 50 ms, beide Rauschstufen, beide Messfehler, Startstellung, Drift um y in beide Richtungen, Basismasse
  ×1,5 und ×2, Trägheit ×2 und die drei Montagefehler. Ein scharf eingestellter Regler erreicht nominal die ruhigste
  Basis, ist aber brüchig. Die Robustheit des modellbasierten Reglers hängt also an einer zurückhaltenden
  Einstellung. Das ist der Punkt, an dem ein randomisiert trainierter Agent einen Vorteil haben könnte (X2.4).
- Die Drift um x kann keiner der Regler ausgleichen, weil die drei Gelenke nur in der Ebene wirken.

**Nachtrag 11.11.2026: alle 50 r4-Agenten aus X4.1 und die 20 DR-Agenten** (`X2_robust_20261111_112342_*`,
Auswertung `ext_x2_robust_report`, Einzelheiten unter X2.4). Ohne Randomisierung sind von 1300
Agent-Szenario-Paaren 10 nicht dominiert (gegen die vier Regler aus X2.1), wieder bei Gegendrift und
Montagefehlern. Mit 50 statt 20 Agenten ändert sich das Bild aus Teil 1 nicht.

**Noch offen in X2.3:** Agenten aus X1.3 und der Sicherheitsfilter aus X1.4.

Datenquelle: `X2_robust_20261110_115447_episodes.csv`, `_summary.csv`, `.mat`.

Paper: neue Vergleichsbasis (Robustheit), Einleitung (Aussage zu Trägheitsparametern). Offen.

### X2.3 Robustheit, Teil 2: Agenten aus X1.3 ✅ 13.11.2026

**Frage:** Halten die Budget-Agenten Bahn und Budget auch unter Modell-, Aktor-, Sensor- und Anfangsfehlern, und
wie oft gelingt das den Reglern mit Nominalmodell?

**Aufbau:**
- `ext_x2_3_x13()`: `ext_x2_robust` mit allen Reglern wie in X2.4 (R0, Rβ 1 / 21,5 / 46,4, dazu Rt_acc, Rt_mid,
  Rt_calm), den 50 Budget-Agenten und 10 r1 aus X1.3 und D16 r4 Seeds 0–9 (w 2). 26 Szenarien wie Teil 1, 2926
  Episoden in 12,8 min, kinematisch.
- Auswertung `ext_x2_3_x13_report('20261113_090316')`. Nur Agenten, die nominal folgen. „Budget“ = folgt in allen
  Wiederholungen und mittlere größte Basisdrehung ≤ θ + 5 mrad. Faktor wie Teil 1, gegen alle sieben Regler, nur
  über folgende Paare. Dazu `ext_x2_robust_report` (jetzt mit CSV-Ausgabe).

**Ergebnis Agenten** (25 Störszenarien je Agent):

| Gruppe | folgen nominal | folgen weiter (Anteil der Paare) | Faktor Median | nicht dominiert | Bahn und Budget nominal | davon gehalten (Anteil der Paare) |
|---|---|---|---|---|---|---|
| θ 0,02 | 3 | 100 % | 2,06 | 4 von 75 | 3 | 88 % |
| θ 0,03 | 6 | 98 % | 2,39 | 6 von 147 | 6 | 90 % |
| θ 0,04 | 4 | 98 % | 2,27 | 0 von 98 | 4 | 74 % |
| θ 0,05 | 8 | 97 % | 2,90 | 1 von 193 | 7 | 84 % |
| θ 0,06 | 8 | 100 % | 2,10 | 1 von 200 | 8 | 85 % |
| r1 | 9 | 93 % | 3,13 | 0 von 210 | – | – |
| r4 w 2 | 10 | 97 % | 2,00 | 2 von 243 | – | – |

**Ergebnis Regler** (Regler mit nominal Bahn und Budget, Anteil der Störszenarien mit Bahn und Budget):

| Regler (nominal RMS / Basis) | θ 0,02 | θ 0,03 | θ ≥ 0,04 |
|---|---|---|---|
| Rβ 1 (5,7 mm / 19,8 mrad) | 60 % | 88 % | 100 % |
| Rt_acc (6,1 mm / 18,0 mrad) | 76 % | 92 % | 100 % |
| Rβ 21,5 (9,0 mm / 13,0 mrad) | 88 % | 96 % | 100 % |
| Rβ 46,4, Rt_mid (12,8 mm / 8,1 mrad) | 96 % | 100 % | 100 % |
| Rt_calm (16,7 mm / 6,2 mrad) | 96 % | 100 % | 100 % |

Alle Regler folgen in allen Szenarien.

**Deutung:**
- Wer nominal folgt, folgt auch unter den Störungen fast immer (93 bis 100 %), mit Budget nicht seltener als
  ohne. Die Nebenbedingung macht die Agenten also nicht empfindlicher.
- Das Budget halten die Agenten unter Störungen in 74 bis 90 % der Fälle. Die Regler mit etwas Abstand zur Grenze
  halten es in 88 bis 100 %, und das bei kleinerem Bahnfehler (Rβ 21,5 mit 9 mm bei θ 0,02 gegen 12,5 bis 36 mm
  bei den drei Agenten). Nur der Regler direkt an der Grenze (Rβ 1, 19,8 mrad bei θ 0,02) hält seltener (60 %).
- Der Faktor bleibt bei etwa 2 bis 3, wie in Teil 1 und X2.2. Nicht dominiert sind 14 von 1166 folgenden Paaren
  (1,2 %), fast alle unter Drift der Basis (y ±2 mrad/s, x 2 mrad/s) oder falscher Montage (x ±5 cm), wie in
  Teil 1.
- Damit gilt K6 auch für die Agenten mit Budget: In keinem der 26 Szenarien ist eine Gruppe robust besser als
  die Regler mit Nominalmodell.

**Grenzen:** nur kinematisch, Agenten mit nominal Budget sind wenige (3 bis 8 je θ). Der Filter aus X1.4 ist unter
den Störungen noch nicht geprüft.

Datenquelle: `X2_robust_20261113_090316_{episodes,summary}.csv` und `.mat`,
`X2_3_x13_report_{groups,ctrl,nondom}_20261113_090316.csv`, `X2_robust_20261113_090316_report_{T,D}.csv`, Log
`X2_3_x13_matlab.log`.

Paper: Robustheitsabschnitt, Ergänzung zu K6. Offen.

### X2.4 Domain Randomization ✅ 11.11.2026 (X0.1 in SK_desktop 13.11.)

**Abstimmbarkeit** (`ext_x2_4_tunable`): Unter Fast Restart (wie im RL-Training) wurden Basismasse (Simscape,
compiletime) und Verzögerung (Dialogwert des Delay-Blocks) stillschweigend ignoriert. Verstärkung, Startstellung
und Rauschen wirkten. Umgestellt in `desktop_build_model`: Masse und Trägheit mit `Mass_conf` und
`MomentsOfInertia_conf` = runtime, neuer Trägheitsfaktor `p_inertia_scale`, Verzögerung über den Eingangsport des
Delay-Blocks. Danach alle sechs Parameter abstimmbar, Modi 0, 2, 4 bitgleich zur Basislinie. Die CDR-Studie im
Paper ist nicht betroffen (`SpaceKinova_CDR_FRO.m` kompiliert je Teilphase neu).

**Training** (`ext_x2_4_train`): r4 mit Gewicht 2, sonst wie D16/D17. DR-M (Masse ×[0,25; 2], Trägheit ×[0,5; 2],
log-gleichverteilt) und DR-voll (dazu Verzögerung 0–2 Schritte, Verstärkung [0,9; 1,1], Rauschen 0–2-fach,
Startstellung ±2°), je Episode in der ResetFcn. Kurztraining 16 Episoden, 4 Worker: Die ResetFcn läuft auf den
Workern, jede Episode zieht andere Werte. Nachgespielt im Simulator passt jede Episode zu genau einer Ziehung
(Abweichung ≤ 1e-6, nächstbeste ≥ 0,017). Läuft in der Nacht 10./11.11. (`ext_x2_4_night`).

**Einstellung des Reglers auf dieselbe Verteilung** (`ext_x2_4_tune_ctrl`, fairer Vergleich): 98 Regler (β, kOri,
Kp, J6-Seite) auf 40 Ziehungen aus der DR-voll-Verteilung, Nominalmodell, Inversion der Kette. 10 min.
- Nur 32 von 98 Reglern folgen in allen 40 Ziehungen. Kp 10 verliert in 17–23 % der Ziehungen die Bahn, starke
  Rückführung der Basislage ebenso. Robust sind nur zurückhaltende Einstellungen (Kp 5).
- Front im 90-%-Quantil: 12,6 mm / 51 mrad (β 4,6) bis 27,4 mm / 18,5 mrad (β 100), alle mit Kp 5, J6-Seite −.
  R0 folgt überall, liegt aber mit 14,2 mm / 162 mrad hinter der Front.
- Drei Vertreter für den Vergleich mit den DR-Agenten (`X2_4_ctrl_tuned.mat`, gehen automatisch in
  `ext_x2_robust` ein): Rt_acc β 4,6 (12,6 mm / 51 mrad), Rt_mid β 46 (18,8 / 28), Rt_calm β 100 (27,4 / 18,5).

Datenquelle: `X2_4_tune_ctrl_20261110_125630.csv`, `X2_4_ctrl_tuned.mat`.

**Training** (Nachtkette `ext_x2_4_night`, `X2_4_runlog.csv`): 20 Läufe (DR-M und DR-voll, Seeds 0–9), alle
erfolgreich, je 21–26 min. Ein Neustart durch Windows Update um 03:52 brach DR-M Seed 5 ab. Die Kette lief ab
07:32 weiter und übersprang die fertigen Agenten. Letzter gleitender Return: DR-M 2101–2419, DR-voll 1628–2283
(andere Bedingungen, nicht direkt vergleichbar). Je Episode gezogene Werte in `X2_4_*_dr.csv`.

**Robustheit** (Schritt 3 der Nachtkette, `ext_x2_robust('agents', ...)`, 26 Szenarien wie X2.3, kinematischer
Simulator): 70 Agenten (50 r4 aus X4.1, 10 DR-M, 10 DR-voll) und 7 Regler (vier aus X2.1, die drei auf die
DR-voll-Verteilung eingestellten Rt). 2926 Episoden in 11 min. Auswertung
`ext_x2_robust_report('20261111_112342')`. Referenz ist w 2 aus D16: gleicher Reward, Seeds 0–9, ohne
Randomisierung. Rt_mid ist mit Rβ 46 identisch (gleiche Einstellung).

RMS [mm] / größte Basisdrehung [mrad], Agenten als Median über 10 Seeds, in Klammern Anzahl „folgt“:

| Szenario | w 2 | DR-M | DR-voll | Rβ 46 | Rt_acc | Rt_calm |
|---|---|---|---|---|---|---|
| nominal | 10,9 / 52 (10) | 12,4 / 54 (9) | 15,6 / 39 (10) | 12,8 / 8 | 6,1 / 18 | 16,7 / 6 |
| Masse ×0,25 | 18,3 / 101 (9) | 12,7 / 138 (9) | 15,5 / 70 (10) | 15,6 / 17 | 9,3 / 41 | 20,3 / 12 |
| Masse ×0,5 | 13,8 / 75 (10) | 11,8 / 90 (9) | 14,5 / 57 (10) | 14,1 / 12 | 7,4 / 28 | 18,5 / 9 |
| Masse ×2 | 12,0 / 32 (10) | 12,0 / 31 (9) | 16,6 / 20 (10) | 11,6 / 5 | 4,8 / 10 | 15,0 / 3 |
| Trägheit ×0,5 | 13,5 / 78 (10) | 12,6 / 90 (9) | 14,8 / 50 (10) | 13,7 / 12 | 7,3 / 28 | 18,5 / 10 |
| Verzögerung +50 ms | 13,7 / 52 (10) | 12,6 / 56 (9) | 14,3 / 36 (10) | 13,4 / 8 | 7,4 / 18 | 18,3 / 6 |
| Startstellung ±2° | 12,9 / 54 (10) | 13,6 / 56 (9) | 15,7 / 36 (10) | 13,5 / 11 | 6,6 / 20 | 17,7 / 7 |
| Montage x +5 cm | 26,9 / 64 (9) | 32,8 / 67 (9) | 22,0 / 53 (10) | 20,6 / 19 | 11,0 / 30 | 26,3 / 11 |
| Montage x −5 cm | 38,3 / 39 (9) | 42,4 / 40 (10) | 31,6 / 19 (10) | 21,0 / 20 | 14,6 / 26 | 34,9 / 17 |
| Montage z +5 cm | 36,1 / 60 (8) | 33,0 / 60 (8) | 36,1 / 43 (9) | 27,7 / 14 | 28,1 / 23 | 30,6 / 9 |
| Drift y −2 mrad/s | 15,0 / 30 (10) | 15,2 / 30 (10) | 19,3 / 21 (10) | 11,0 / 23 | 5,3 / 24 | 14,9 / 18 |

Je Gruppe über alle 26 Szenarien. „Δ Masse“: je Agent das Mittel des Zuwachses gegen nominal über die sieben
Szenarien mit Basismasse und Trägheit (der Bereich der Randomisierung), dann Median über die Seeds. p:
Mann-Whitney-U gegen w 2, zweiseitig, unkorrigiert. Faktor und „nicht dominiert“ gegen alle 7 Regler (in
Klammern gegen die 4 aus X2.1):

| Gruppe | nominal p RMS / ori | Δ Masse RMS [mm] (p) | Δ Masse ori [mrad] (p) | alle folgen | Faktor | nicht dominiert |
|---|---|---|---|---|---|---|
| w 2 | Referenz | +1,7 | +7,9 | 20 von 26 | 2,0 | 2 (2) |
| DR-M | 0,85 / 0,57 | +0,4 (0,011) | +14,7 (0,021) | 2 von 26 | 2,0 | 4 (4) |
| DR-voll | 0,10 / 0,43 | +0,1 (0,0028) | +5,1 (0,31) | 25 von 26 | 2,4 | 9 (11) |

Die übrigen Gewichte ohne Randomisierung (w 0, 4, 8, 16) liegen bei Δ Masse RMS +1,1 bis +1,8 mm (p ≥ 0,16)
und nicht dominiert 0 bis 4.

**Deutung:**
- Randomisierung macht den Bahnfehler unempfindlich gegen falsche Basismasse und Trägheit. Über die sieben
  Szenarien im Trainingsbereich wächst der RMS je Agent um +0,4 mm (DR-M) und +0,1 mm (DR-voll) statt +1,7 mm.
  Nach Holm über die zwei DR-Gruppen bleiben beide unter 0,05 (0,0057 und 0,011). Am deutlichsten ist es bei Masse
  ×0,25 (DR-voll 15,5 mm, nominal 15,6 mm, w 2 von 10,9 auf 18,3 mm).
- DR-M hält die Bahn bei leichter Basis, indem es mehr Basisdrehung zulässt (138 statt 101 mrad bei ×0,25,
  Δ Masse ori +14,7 statt +7,9 mrad). DR-voll bleibt in beiden Größen ruhiger (70 mrad bei ×0,25).
- DR-voll ist nominal ungenauer (15,6 statt 10,9 mm, p 0,10) und dreht im Median weniger (39 statt 52 mrad,
  p 0,43). Die Verteilung ist zweigeteilt: 5 von 10 Seeds liegen bei 23–28 mrad mit 14,0–22,3 mm, die anderen bei
  50–67 mrad. Ohne Randomisierung sind es 2 von 10. Der Unterschied ist bei 10 Seeds nicht belastbar.
- DR-voll folgt in 25 von 26 Szenarien mit allen Seeds (w 2: 20). Auch außerhalb des Trainingsbereichs verliert es
  weniger: Montage x +5 cm +6,1 statt +16,9 mm, x −5 cm +16,7 statt +25,3 mm (p 0,004 und 0,002, unkorrigiert).
  Korrektur 11.11.2026 (X4.5): Der Vergleich 25 gegen 20 Szenarien gilt nur mit der Schwelle 5 cm aus X0.1. Mit
  8 cm oder RMS < 5 cm folgen beide Gruppen gleich oft.
- DR-M Seed 1 folgt in 24 von 26 Szenarien nicht, auch nominal nicht (31,9 mm / 29 mrad, ep_q4 55 mm). Er hat den
  niedrigsten Trainingsreturn der Reihe. Wie w0_s1 in X4.1 ist er ruhig, gibt aber die Bahn auf. Ohne ihn fällt
  DR-M nur in einem weiteren Agent-Szenario-Paar aus (w 2: 7 von 260).
- Die Regler mit Nominalmodell bleiben vorn. Der Faktor liegt im Median bei 2,0 (DR-M) und 2,4 (DR-voll). DR-voll
  ist in 9 von 260 Agent-Szenario-Paaren nicht dominiert, alle bei Gegendrift y −2 mrad/s (4) und Montage x −5 cm
  (5). Dort drehen die ruhigen DR-voll-Agenten weniger als jeder folgende Regler. Diese Regler haben keine
  Rückführung der Basislage. Mit kOri 0,5 war bei der Gegendrift in X2.3 kein Agent mehr frei.
- Auch die Regler verlieren bei Masse ×0,25 nur wenig Bahn (Rβ 46 +2,8 mm, Rt_acc +3,2 mm). Die Randomisierung
  schließt also den Abstand in der Empfindlichkeit, nicht im Niveau. Ein Fall, in dem RL robust besser ist als
  ein zurückhaltend eingestellter Regler, wurde auch mit Randomisierung nicht gefunden.
- Grenzen: Training in Simscape, Test im kinematischen Simulator (X0.2: ≤ 0,45 mm). Das Protokoll X0.1 in
  `SK_desktop` für die 20 DR-Agenten fehlt noch. Ein Test auf Ziehungen aus der Trainingsverteilung selbst (wie
  bei der Einstellung der Rt-Regler) fehlt ebenfalls. Der Regler kennt die Befehlskette und den Zweig von J6.

Datenquelle: `X2_robust_20261111_112342_summary.csv`, `_episodes.csv`, `.mat`, `X2_4_runlog.csv`,
`X2_4_*_train.csv`, `X2_4_*_dr.csv`. Agenten `SavedAgents/MotionProfile/X2_4/`.

Paper: Robustheitsvergleich (Methode, Fairness), ersetzt die CDR-Studie für die Basismasse. Offen.

**Nachtrag 13.11.2026: X0.1 in `SK_desktop`** (`ext_x2_4_eval()`, 20 Agenten in 5,2 min, Auswertung
`ext_x2_4_eval_report()`). Aufbau aus dem cfg (r4, w 2, J6 0,9774, 40 Hz), nominales Modell ohne Randomisierung,
21 Episoden je Agent. Bezug w 2 = D16 r4 Seeds 0–9 (X0.1 aus X1.3). Mann-Whitney gegen w 2, Holm über die zwei
DR-Gruppen. Faktor gegen die Front F aus X2.2 (nur folgende Agenten, Mittel der 21 Episoden).

| Gruppe | folgt | RMS Median Mittel (nominal) [mm] | ori_max Median [mrad] | schlechteste ori [mrad] | Ruck | ruhig (≤ 30 mrad, folgt) | Faktor |
|---|---|---|---|---|---|---|---|
| w 2 (D16) | 10/10 | 13,9 (10,9) | 52,5 | 58,1 | 7,2 | 1 | 2,69 |
| DR-M | 9/10 | 14,6 (12,4) | 54,6 | 61,0 | 10,2 | 0 | 2,80 |
| DR-voll | 10/10 | 16,5 (15,7) | 36,6 | 47,8 | 13,1 | 5 | 3,19 |

- Keine Gruppe unterscheidet sich von w 2 in RMS, ori_max, folgt oder Faktor (Holm p ≥ 0,20). Einzige
  Ausnahme ist der Ruck von DR-voll (13,1 gegen 7,2, p 0,014, Holm 0,028).
- Die kinematischen Zahlen bestätigen sich. DR-M Seed 1 folgt auch hier nicht (34,3 mm, 29 mrad). DR-voll ist
  wieder zweigeteilt: 5 Seeds bei 23–29 mrad mit 14,5–21,8 mm (Mittel), die anderen bei 44–67 mrad.
- Gegenprobe nominale Episode `SK_desktop` gegen den kinematischen Simulator (Szenario nominal aus
  `X2_robust_20261111_112342`): Das Urteil „folgt“ stimmt bei allen 20 überein. RMS höchstens 1,8 mm auseinander
  (DR-voll Seed 5, 27,7 gegen 29,5 mm), sonst ≤ 0,3 mm. ori_max ≤ 1,1 mrad. Die 1,8 mm liegen über den 0,45 mm aus
  X0.2. Der Agent hat den größten RMS der Reihe, die Aussagen von K8 ändern sich dadurch nicht.
- Damit ist die Grenze „X0.1 in SK_desktop offen“ von K8 erledigt.

Datenquelle: `X_eval_X2_4_20261113_174009_*`, `X2_4_eval_report_{agents,groups,tests}_20261113_174009.csv`.

## X3 Kinematische Emulation

### X3.1 Umsetzung und Validierung in Simulation ✅ 10.11.2026

**Umsetzung:**
- `hardware/campaign/virtual_base_step.m`: eine Datei für Simulator und Deploy-Skript. Je Schritt
  dx = G(q_mid)·(q − q_prev) mit der verallgemeinerten Jacobi-Matrix am Mittelpunkt, Lage als Quaternion, Ort mit
  der halben Drehung. Daraus EE-Lage und -Geschwindigkeit in der Welt, v_base, w_base und e_ori wie im Training.
  Die Zeit geht nicht ein, nur der Weg im Gelenkraum.
- `ext_kinsim` mit `emulate`: Strecke ist der fest montierte Arm, die Beobachtung kommt aus `virtual_base_step`
  zu jedem Agentenschritt.
- `hardware/campaign/deploy_tracking_v25.m` = v24 plus Schalter `emulateBase` (Standard aus, dann wie v24). Mit
  Emulation: Prüfung beim Start, dass Emulationsmodell und URDF dieselbe EE-Lage liefern. Beobachtung aus der
  virtuellen Basis. OOD-Stopp auf den virtuellen und zusätzlich auf den physischen EE-Fehler (`oodThresholdPhys`
  0,4 m). Neue Log-Felder (virtuelle EE-Lage, Basis-Twist, e_ori, physischer Fehler, Rechenzeit). Dazu
  `dryRunKinematic`: Im Trockenlauf folgt der Arm ideal dem gesendeten Befehl.

**Validierung** (`ext_x3_validate()`):

| Stufe | Prüfung | Ergebnis |
|---|---|---|
| 1 | Gelenkbahn aus `ext_kinsim` (frei schwebend) eingespielt, 40 Hz / 20 Hz / unregelmäßig (50 ± 8 ms, 5 % bis 120 ms) | Basisdrehung ≤ 6e-7 rad, EE ≤ 8e-7 m |
| 1 | Gelenkbahn aus Simscape (`q_cmd`, vor dem Gelenkfilter) eingespielt | Basisdrehung ≤ 1,0 mrad, EE 3 mm RMS |
| 2 | Geschlossener Kreis fest + Emulation gegen frei schwebend, 3 Agenten und Rβ 46, 40 und 20 Hz | EE ≤ 0,41 mm RMS (frühes PPO, 40 Hz), sonst ≤ 1e-5 m, Basis ≤ 0,2 mrad |
| 3 | Rechenzeit `virtual_base_step` | 0,42 ms (Simulator), 0,6 ms im Deploy-Skript |

- Ziel aus PLAN.md (≤ 2 mm, ≤ 2 mrad) erfüllt. Die 1 mrad und 3 mm beim Simscape-Einspielen kommen daher, dass
  Simscape die Gelenkbahn vor dem Gelenkfilter loggt (τ = 20 ms, zweifach). D15 fand dieselbe Größe.
- Unregelmäßige Schrittzeiten ändern das Ergebnis nicht messbar. Die Emulation hängt nur vom Weg ab.
- Physisch weicht der feste Arm dabei von der Referenz ab (14–33 mm RMS), weil er die Bahn relativ zur virtuellen
  Basis fährt. Das ist gewollt und muss im Labor so erklärt werden. Die zusätzliche OOD-Grenze sichert es ab.

**Trockenlauf v25** (`dryRunKinematic`, D16 r4 s2, J6 0,9774, Kappe 0,85; nur Funktionstest, der ideale Arm hat
weder Servoverzögerung noch Rate Transition, und die Schleife lief neben X4.1 mit 32 statt 40 Hz):

| Rate | Emulation | Agent sieht RMS | Basis max | physisch RMS | frei schwebend (Simulator) |
|---|---|---|---|---|---|
| 40 Hz | aus (wie v24) | 24,2 mm | – | 24,2 mm | 11,9 mm / 26,3 mrad |
| 40 Hz | an | 12,9 mm | 25,5 mrad | 19,9 mm | 11,9 mm / 26,3 mrad |
| 20 Hz | aus | 14,3 mm | – | 14,3 mm | 8,8 mm / 25,0 mrad |
| 20 Hz | an | 14,8 mm | 24,4 mrad | 16,1 mm | 8,8 mm / 25,0 mrad |

Alle Läufe vollständig, `getAction` 2 ms, Emulation 0,6 ms.

**Noch offen:** Vorhersage je Bedingung für X3.2 (`X3_prediction.csv`), sobald die Agenten feststehen (E5).
Nachtrag 13.11.2026: Vorhersage für alle Kandidaten gerechnet (X3.2 Vorhersage unten). Trockenläufe mit
`deploy_tracking_v25` folgen, wenn E5 steht.

Datenquelle: `X3_validate_20261110_131114_*`.

Paper: neuer Abschnitt Emulation (Methode, Validierung, Grenzen). Offen.

### X3.2 Vorhersage für den Labortag ✅ 13.11.2026 (Labortag ⏸)

**Frage:** Was sollte die Hardware je Kandidat mit und ohne Emulation zeigen? Und bei welchen Agenten ist der
Unterschied groß genug, um ihn auf der Hardware zu sehen?

**Aufbau:** `ext_x3_2_predict()`, kinematischer Simulator, nominal, Startstellung null, J6 0,9774 rad/s, 20 Hz
(Rate der API) und 40 Hz. Kandidaten aus PLAN X3.2: D16 r0 s0, D16 r4 s2 nach 1000 Episoden, D16 r4 s7, s4 und
s1 (alle schon am Labortag 2 gefahren), alle Budget-Agenten aus X1.3 mit θ 0,03 und 0,05, die in X0.1 folgen und
das Budget halten (je 5), und DR-voll s6. Je Agent drei Läufe:
- frei schwebend wie im Training (ff),
- Emulation aus wie V2.4 (fester Arm, Basis-Kanäle null),
- Emulation an wie V2.5. Dabei zählen, was der Agent sieht (virtuell) und was der Arm physisch fährt.

Ohne die Schutzschicht des Deploy-Skripts und mit idealem Servo.

20 Hz (RMS [mm] / ori_max [mrad], „Median“ = Budget-Agent mit mittlerem RMS in X0.1):

| Kandidat | frei schwebend | Emulation aus | Emulation an, virtuell | Emulation an, physisch RMS / max [mm] | an minus aus [mm] |
|---|---|---|---|---|---|
| r0 s0 (Einbruch) | 73,7 / 19,9, folgt nicht | 87,4, folgt nicht | 74,3 / 19,9, folgt nicht | 83,4 / 217 | −13,1 |
| r4 s2 1000 Ep. | 8,8 / 25,0 | 13,5 | 8,8 / 25,0 | 18,1 / 56 | −4,7 |
| r4 s7 | 9,9 / 61,1 | 16,5 | 9,9 / 61,1 | 32,6 / 110 | −6,6 |
| r4 s4 | 12,4 / 47,5 | 13,5 | 12,4 / 47,5 | 19,0 / 52 | −1,1 |
| r4 s1 | 23,3 / 25,5 | 28,8 | 23,5 / 26,0 | 34,3 / 74 | −5,3 |
| θ 0,03 s6 | 9,2 / 25,9 | 14,0 | 9,3 / 25,8 | 19,4 / 61 | −4,7 |
| θ 0,03 s9 | 15,7 / 21,8 | 11,7 | 15,7 / 21,8 | 29,0 / 46 | +4,0 |
| θ 0,03 s0 (Median) | 18,4 / 15,1 | 18,9 | 15,9 / 15,1 | 21,6 / 68 | −3,0 |
| θ 0,03 s1 | 16,5 / 20,4 | 27,1 | 16,6 / 20,4 | 34,7 / 69 | −10,5 |
| θ 0,03 s2 | 18,4 / 24,8 | 23,2 | 18,6 / 25,6 | 27,9 / 69 | −4,6 |
| θ 0,05 s4 | 13,5 / 47,1 | 17,3 | 13,6 / 47,0 | 29,8 / 55 | −3,7 |
| θ 0,05 s2 | 16,1 / 20,8 | 17,2 | 16,2 / 20,8 | 33,9 / 57 | −1,0 |
| θ 0,05 s3 (Median) | 19,8 / 37,2 | 19,5 | 19,6 / 36,2 | 33,8 / 102 | +0,1 |
| θ 0,05 s9 | 22,8 / 21,3 | 21,5 | 23,9 / 21,3 | 28,2 / 56 | +2,4 |
| θ 0,05 s5 | 23,2 / 42,8 | 20,5 | 23,6 / 42,8 | 27,9 / 47 | +3,1 |
| DR-voll s6 | 12,9 / 23,8 | 14,9 | 12,9 / 23,8 | 19,6 / 51 | −2,0 |

„an minus aus“ ist der RMS, den der Agent mit Emulation sieht, minus den RMS ohne Emulation. Werte für 40 Hz in
der CSV, sie liegen ähnlich.

- Mit Emulation sieht der Agent fast dasselbe wie frei schwebend: höchstens 0,4 mm Unterschied, außer bei drei
  Budget-Agenten (θ 0,03 s0 2,5 mm bei 20 Hz und 1,4 mm bei 40 Hz, θ 0,03 s2 1,1 mm bei 40 Hz, θ 0,05 s9 1,1 mm
  bei 20 Hz). In X3.1 waren es höchstens 0,41 mm. Ungeprüfte Vermutung: Die Emulation rechnet je Agentenschritt,
  bei Agenten mit vielen gesättigten Schritten wirkt das stärker. Alle, die frei schwebend folgen, folgen auch
  mit Emulation.
- Physisch fährt der Arm bei den folgenden Agenten 18 bis 35 mm RMS neben der Referenz, im größten Fall 110 mm
  (r4 s7). Die zusätzliche OOD-Grenze von 0,4 m wird in keinem Fall erreicht (r0 s0 höchstens 217 mm).
- Der Unterschied zwischen Emulation an und aus beträgt −10,5 bis +4,0 mm. Am Labortag 2 lag die Hardware 2 bis
  3 mm über der Vorhersage mit fester Basis (r4 s7, s4, s1: Vorhersage 16 / 14 / 28 mm, Hardware 18 / 17 / 30 mm,
  `hardware/campaign/ANLEITUNG_LABOR_TAG2.md`). Gut unterscheidbar sind also
  Agenten mit mehr als etwa 4 mm Unterschied: θ 0,03 s1 (−10,5), r4 s7 (−6,6), r4 s1 (−5,3), r4 s2 1000 Ep. und
  θ 0,03 s6 (je −4,7). Bei den beiden Median-Agenten (−3,0 und +0,1) ist der Unterschied kaum messbar.
- Vorschlag für E5 (mit dem Betreuer): r4 s7 (Labortag 2, großer Unterschied, positiver Zweig) und θ 0,03 s6
  (bester Budget-Agent in X0.1 mit 13,3 mm und höchstens 29,7 mrad, negativer Zweig, wenig Sättigung J6 9 %).
  Dazu r0 s0 als Gegenprobe (Einbruch in beiden Modi). θ 0,03 s1 zeigt den größten Unterschied, sättigt J6 aber
  in 34 % der Schritte.

**Grenzen:** kinematisch, ideales Servo, ohne Schutzschicht und Timing der Hardware. Eine nominale Episode je
Bedingung. Die Trockenläufe mit `deploy_tracking_v25` stehen aus.

Datenquelle: `X3_prediction_20261113_180218.csv`, `X_eval_X1_3_20261112_195325_agents.csv`,
`X1_3_diag_agents_20261113_084339.csv`.

Paper: Abschnitt Emulation (Vorhersage gegen Hardware). Offen.

## X4 Belastbarkeit

### X4.1 Gewichtsreihe auf 10 Seeds ✅ 11.11.2026

**Frage:** Steuert das Gewicht w des glatten Basis-Terms (r4) die Basisdrehung, wenn je Gewicht 10 Seeds vorliegen?

**Aufbau:**
- `ext_x4_1_run()` vom 10.11. 10:51 bis 23:20 als eigener MATLAB-Prozess (Log `X4_1_matlab.log`). 30 Läufe mit
  Gewicht 0, 4, 8, 16 (neue Seeds 3–9) und Gewicht 2 (Seeds 8, 9), je 3000 Episoden. Alle erfolgreich
  (`X4_1_runlog.csv`).
- Danach `ext_x4_1_eval()`: 50 Agenten (w 2 aus D16, die übrigen aus D17), je 21 Episoden nach X0.1 in
  `SK_desktop`, zusammen 1050 Episoden. Statistik `ext_stats` gegen w 2: Mann-Whitney-U, Holm über die vier
  Gewichte, Fisher für die Anteile.
- Zusatz ohne neues Rechnen: `ext_x4_1_report('20261110_233147')` (Spannweiten, Ruck, Spearman).

**Ergebnis** (Mittel je Agent über 21 Episoden, dann Median und Spannweite über die 10 Seeds):

| w | ori_max [mrad] | RMS [mm] | Ruck [rad/s³] | p Holm ori / RMS / Ruck | folgt | Budget 0,03 / 0,05 | ruhig |
|---|---|---|---|---|---|---|---|
| 0 | 53,9 (25,4–81,4) | 13,7 (11,3–26,9) | 5,1 | 1 / 1 / 0,49 | 9 | 1 / 1 | 1 |
| 2 | 52,5 (24,6–64,2) | 13,9 (11,6–29,5) | 7,2 | Referenz | 10 | 2 / 3 | 2 |
| 4 | 52,9 (30,8–72,1) | 16,0 (10,4–27,9) | 10,5 | 1 / 1 / 0,49 | 10 | 0 / 2 | 1 |
| 8 | 52,8 (20,3–78,8) | 14,5 (11,4–18,4) | 10,6 | 1 / 1 / 0,49 | 10 | 1 / 2 | 1 |
| 16 | 49,7 (26,8–58,7) | 15,5 (14,0–21,3) | 15,3 | 1 / 0,74 / 0,085 | 10 | 1 / 4 | 2 |

„Budget θ“: schlechteste der 21 Episoden mit ori_max ≤ θ + 5 mrad (wie X1.3, unabhängig von „folgt“). „Ruhig“:
mittleres ori_max < 40 mrad. Fisher gegen w 2 für „folgt“ und beide Budgets überall p ≥ 0,47, nach Holm 1.

**Deutung:**
- Kein Gewicht unterscheidet sich von w 2, weder im Median der Basisdrehung (49,7–53,9 mrad) noch im Bahnfehler
  noch in den Anteilen. Spearman über alle 50 Agenten: w gegen ori_max −0,18 (p 0,21). K2 hält mit 10 Seeds.
- Die Streuung innerhalb eines Gewichts ist größer als der Unterschied zwischen den Gewichten (20–81 mrad). Jedes
  Gewicht hat ein bis zwei ruhige Agenten, zusammen 7 von 50 (w0_s1, w2_s0, w2_s1, w4_s2, w8_s9, w16_s0,
  w16_s8). Welcher Seed ruhig wird, sagt w nicht voraus.
- Ruhige Agenten zahlen mit Bahnfehler: ori_max gegen RMS −0,47 (Spearman, p 6e-4). Die sieben ruhigen Agenten
  liegen bei 16,8–29,5 mm, die Gruppenmediane bei 13,7–16,0 mm. Am günstigsten sind w8_s9 (18,4 mm / 20 mrad)
  und w16_s0 (17,5 mm / 27 mrad). w0_s1 folgt nicht (ep_q4 bis 55 mm), ein ruhiger Agent, der die Bahn aufgibt.
- Was w verändert, ist der Befehlsruck: Median 5,1 bei w 0 bis 15,3 rad/s³ bei w 16, Spearman 0,58 (p 8e-6).
  Die Einzeltests gegen w 2 sind nach Holm nicht signifikant (w 16: p 0,085). In diesen Läufen macht ein größeres
  Gewicht also eher den Befehl unruhiger als die Basis ruhiger.
- Budget: 0,03 rad halten 5 von 50 Agenten, 0,05 rad 12 von 50, ohne Zusammenhang mit w. Das ist die
  Vergleichsgröße für H1a und H1b (X1.3).
- Grenzen: nur r4, 3000 Episoden, ebene Bahn, nominale Masse. Die Ruck-Kennzahl ist der Ruck des Befehls hinter
  der Kette, nicht der gemessene Ruck der Gelenke.

Datenquelle: `X_eval_X4_1_20261110_233147_agents.csv`, `_episodes.csv`, `.mat`, `X4_1_stats_20261110_233147.mat`,
`X4_1_runlog.csv`. Agenten `SavedAgents/MotionProfile/D17/` (neu Seeds 3–9) und `D16/` (neu Seeds 8, 9).

Paper: Abschnitt Zielkonflikt (bisher D17 mit drei Seeds), Abbildung RMS gegen Basisdrehung mit X1.3 und der
Front aus X2.2. Offen.

### X4.2 Bestandsagenten nach Protokoll X0.1 ✅ 11.11.2026

**Aufbau:** `ext_x4_2_run()` mit der Liste aus `ext_x4_2_list()`. 93 Agenten: frühes PPO und basisori,
Optimized, ppo_10hz, CDR1-4 und CDR2-4, D10 (7, Ratenpaar), D11 (30, sechs Algorithmen × 5 Seeds), D12 (7),
D13 (9), D14 (9), D16 (17, r0, r2, r4 kurz und lang), D20 (8 Endagenten). D17 wertet `ext_x4_1_eval` aus.
Trainingsbedingungen aus dem `cfg` (Inventar `X4_2_inventory.csv`): Takt 0,1 s bei ppo_10hz und D10 10 Hz,
sonst 0,025 s. J6 0,9774 nur bei D16 und D20, sonst 0,1. Reward-Modus 0 bis 4 wie im Training. Alle Dateien
enthalten `agent`.

**Rauchtest** (3 Agenten, nur nominal, seriell): frühes PPO 1698,9196 und Optimized 1593,0836, gleich der
Basislinie aus X0.1. Testdateien gelöscht.

**Ablauf:** Schritt 5 der Nachtkette nach X1.2, 8 Worker. Nicht parallel zu X4.1 gestartet, weil X4.1 etwa
14 GB belegt und nur 6,5 GB frei waren. Gelaufen am 11.11. ab 14:32: 95 Agenten (D16 inzwischen mit den Seeds 8
und 9 aus X4.1), 1995 Episoden in 14,5 min. Zusammenfassung nach Untergruppen mit
`ext_x4_2_report('20261111_144608')`.

**Ergebnis** (Median über die Agenten einer Untergruppe, RMS [mm], ori_max [mrad], ep_q4 [mm] nur aus Episoden
ohne Abbruch, „folgt“ wie X0.1, „Abbruch“ = Agenten, bei denen alle 21 Episoden abbrechen):

| Untergruppe | Modus | J6 | n | folgt | Abbruch | RMS | ori_max | ep_q4 |
|---|---|---|---|---|---|---|---|---|
| frühes PPO | 0* | 0,1 | 1 | 1 | 0 | 13,5 | 56 | 9,6 |
| frühes PPO basisori | 0 | 0,1 | 1 | 0 | 0 | 65,1 | 10 | 118 |
| Optimized | 0 | 0,1 | 1 | 0 | 0 | 61,0 | 18 | 113 |
| ppo_10hz | 0 | 0,1 | 1 | 0 | 0 | 67,3 | 15 | 124 |
| CDR1-4, CDR2-4 | 0 | 0,1 | 2 | 0 | 0 | 81,3 | 13 | 149 |
| D10 10 Hz | 0 | 0,1 | 4 | 0 | 0 | 67,3 | 18 | 118 |
| D10 40 Hz | 0 | 0,1 | 3 | 0 | 0 | 62,2 | 24 | 117 |
| D11 PPO | 0 | 0,1 | 5 | 0 | 1 | 70,5 | 24 | 117 |
| D11 TRPO | 0 | 0,1 | 5 | 0 | 0 | 73,5 | 14 | 135 |
| D11 SAC | 0 | 0,1 | 5 | 0 | 0 | 309 | 30 | 409 |
| D11 DDPG, TD3, PG | 0 | 0,1 | 15 | 0 | 15 | 220–264 | 129–135 | – |
| D12 r1 / r2 / r3 | 1 / 2 / 3 | 0,1 | 1 / 3 / 3 | 0 / 1 / 0 | 1 / 0 / 3 | 141 / 28,1 / 153 | 179 / 57 / 31 | – / 46 / – |
| D13 (alle Modi) | 0–2 | 0,1 | 9 | 0 | 8 | – | – | – |
| D14 r0 | 0 | 0,1 | 3 | 0 | 0 | 72,5 | 22 | 130 |
| D14 r1 | 1 | 0,1 | 3 | 3 | 0 | 12,1 | 80 | 11,0 |
| D14 r2 | 2 | 0,1 | 3 | 3 | 0 | 16,9 | 79 | 16,9 |
| D16 r0 | 0 | 0,9774 | 3 | 0 | 0 | 76,7 | 17 | 141 |
| D16 r2 | 2 | 0,9774 | 3 | 3 | 0 | 12,9 | 67 | 10,7 |
| D16 r4, 1000 Episoden | 4 | 0,9774 | 3 | 2 | 0 | 14,6 | 27 | 15,1 |
| D16 r4, 3000 Episoden | 4 | 0,9774 | 10 | 10 | 0 | 13,9 | 52 | 14,7 |
| D20 (Endagenten) | 4 | 0,9774 | 8 | 8 | 0 | 13,5 | 53 | 10,3 |

\* Das frühe PPO wurde ohne Basis-Terme trainiert (A62), ausgewertet unter Modus 0.

**Deutung:**
- K1 hält unter dem einheitlichen Protokoll. Alle 27 Agenten mit dem alten Basis-Bonus, die durchlaufen und in
  der Nähe der Bahn bleiben (basisori, Optimized, ppo_10hz, CDR, D10, D11 PPO und TRPO, D14 r0, D16 r0), verlieren
  die Bahn im letzten Viertel (Mediane der Untergruppen 113–149 mm) und drehen die Basis wenig (Mediane
  10–24 mrad). Der Einbruch hängt nicht vom Takt (D10), von der J6-Grenze (D14 gegen D16) oder vom Verfahren (D11)
  ab.
- Ohne den Bonus neben der Bahn folgen alle 20 Agenten aus frühem PPO, D14 r1/r2, D16 r2 und D16 r4 mit 3000
  Episoden, dazu alle 8 D20-Agenten. Mediane der Basisdrehung: 79–80 mrad mit J6 0,1 (D14), 52–67 mrad mit
  J6 0,9774 (D16, D20). Das frühe PPO liegt trotz J6 0,1 bei 56 mrad. Keine Untergruppe liegt unter den etwa
  55 mrad, die K3 für J6 0,1 nennt.
- D11: Nur PPO und TRPO bleiben in der Nähe der Bahn (9 von 10 ohne Abbruch, PPO Seed 0 bricht ab), wie im Paper
  (Table II). SAC bricht nicht ab, bleibt aber 0,3–0,4 m neben der Bahn. DDPG, TD3 und PG brechen in allen
  Episoden ab (EE-Fehler > 0,5 m).
- D13: Sechs Actoren bestehen nur aus NaN (bekannt aus D13). Diese Episoden enden im ersten Schritt, ihre
  Kennzahlen (16,3 mm, 0 mrad) sind bedeutungslos. Zwei weitere brechen nach wenigen Sekunden ab, einer läuft
  durch und verliert die Bahn (ep_q4 0,27 m). D13 gehört nicht in die Zahlen des Papers.
- D12 (asynchron, ohne Gradient Clipping): r1 Seed 0 und alle r3 brechen ab, von r2 folgt einer (D12_r2 Seed 1,
  24,2 mm / 83 mrad).
- D16 r4 kurz (1000 Episoden): Seed 0 folgt nicht (64 mm / 21 mrad), Seed 2 ist der ruhige Agent des
  Labortags (12,9 mm / 27 mrad).

**Grenzen:** ep_q4 fehlt für abgebrochene Episoden. „Folgt“ ist dort 0, der Median steht dann als –. Die Zahlen
ersetzen die Simulationswerte im Paper erst in Phase P. Der Abgleich Zahl für Zahl mit `paper_numbers.md` gehört
dorthin.

Datenquelle: `X_eval_X4_2_20261111_144608_agents.csv`, `_episodes.csv`, `.mat`, `X4_2_groups_20261111_144609.csv`,
`X4_2_report_20261111_144608.csv`, `X4_2_inventory.csv`.

Paper: alle Simulationszahlen der Bestandsagenten (Tabellen und Text zu D10 bis D16). Offen.

### X4.5 Sensitivität der eigenen Schwellen, Runde 1 ✅ 11.11.2026

**Frage:** Hängen die Kernaussagen an den Schwellen, die wir gesetzt haben („folgt“, Budget-Toleranz, „ruhig“)?

**Aufbau:** `ext_x4_5_thresholds()`, nur vorhandene Episoden-Dateien, kein Training. Gitter und Kriterium „hält“
standen vorher fest (PLAN X4.5, Kopf des Skripts):
- folgt: ep_q4 < 3 / 5 / 8 cm in jeder Episode ohne Abbruch, oder RMS < 3 / 5 cm in jeder Episode
- Budget: schlechteste Episode ≤ θ + 0 / 5 / 10 mrad
- ruhig: mittleres ori_max < 30 / 40 / 50 mrad
- K2 hält, wenn kein Gewicht in einem Anteil (folgt, Budget 0,03, Budget 0,05, ruhig) von w 2 abweicht (Fisher,
  Holm, alle p ≥ 0,05). K6 hält, wenn gegen die vier Regler aus X2.1 der Median des Faktors in jeder Gruppe ohne
  Randomisierung ≥ 1,5 ist und höchstens 5 % der Paare nicht dominiert sind. K8 hält, wenn DR-voll in mehr
  Szenarien mit allen Seeds folgt als w 2 und der Faktor gegen alle sieben Regler im Median ≥ 1,5 ist. Filter
  (X1.4, nach der Kette, α 5) hält, wenn jeder folgende Agent das Budget hält. X1.2 hält, wenn mit Kosten A
  mindestens so viele Agenten das Budget halten wie mit B.
- Selbstprüfung: Mit „ep_q4 < 5 cm“ kommen dieselben Zahlen heraus wie in `ext_x2_robust_report` (w 2: 2 nicht
  dominiert gegen vier Regler, DR-voll: 9 gegen sieben).

**Ergebnis:**

| Aussage | Gitterpunkte | hält | Bemerkung |
|---|---|---|---|
| K2 (Gewicht steuert die Basis nicht) | 45 | 45 | kleinstes p nach Holm 0,84. Ruhige Agenten je Gewicht (w 0/2/4/8/16): 1/1/0/1/1 bei 30 mrad, 2/3/2/2/5 bei 50 mrad |
| K6 (Regler vorn, ohne Randomisierung) | 5 | 5 | Faktor-Median mindestens 1,98, nicht dominiert 10 von 1300 Paaren (0,8 %) auf allen Punkten |
| K8 (DR-voll, Regler trotzdem vorn) | 5 | 2 | Faktor 2,37–2,38 überall. „Folgt in mehr Szenarien als w 2“ nur bei ep_q4 < 5 cm (25 gegen 20) und RMS < 3 cm (22 gegen 16). Bei 8 cm und RMS < 5 cm beide gleich (26/26, 24/24), bei 3 cm folgt in keinem Szenario jede Gruppe vollständig |
| Filter X1.4 (nach der Kette) | 9 | 6 | hält mit 5 und 10 mrad Toleranz. Ohne Toleranz liegen 14 der 77 folgenden Läufe knapp über θ, höchstens 0,27 mrad |
| X1.2 (Kosten A ≥ B) | 15 | 15 | A: 2 von 4 mit Budget, B: 0 auf allen Punkten |

**Deutung:**
- K2, K6 und die Wahl der Kostenform hängen nicht an den Schwellen.
- Bei K8 trägt nur ein Teil. Robust sind: Die Regler bleiben vorn (Faktor ≥ 2,37), und die Randomisierung macht den
  Bahnfehler unempfindlich gegen die Masse (Δ RMS, ohne Schwelle). Nicht robust ist die Aussage, DR-voll folge in
  mehr Szenarien als w 2. Sie gilt nur für die Schwelle von 5 cm aus X0.1 (und RMS < 3 cm). Im Paper nur mit
  Schwelle nennen oder weglassen.
- Filter: „hält das Budget praktisch exakt“ heißt genauer höchstens 0,27 mrad über θ. Das ist die Formulierung
  für das Paper.
- Runde 2 nach X1.3 (Budget-Reihe, H1a/H1b) mit demselben Gitter.

Datenquelle: `X4_5_K2_20261111_154036.csv`, `_K6_`, `_K8_`, `_F_`, `_X12_` (gleicher Zeitstempel), Eingänge
`X_eval_X4_1_20261110_233147_*`, `X2_robust_20261111_112342_episodes.csv`, `X1_4_eval_20261110_130405.csv`,
`X_eval_X1_2_20261111_150856_*`.

Paper: Anhang oder Fußnote zur Wahl der Schwellen, Formulierung von K8 und Filter. Offen.

### X4.5 Sensitivität der eigenen Schwellen, Runde 2 ✅ 13.11.2026

**Aufbau:** `ext_x4_5_thresholds()` mit den neuen Optionen `x13` und `x42`. Kriterien vor der Rechnung in PLAN
X4.5 festgelegt (13.11.2026). Gitter wie Runde 1. Die Aussagen aus Runde 1 kommen unverändert heraus (K2 45/45,
K6 5/5, K8 2/5, Filter 6/9, X1.2 15/15).

**Ergebnis:**

| Aussage | Gitterpunkte | hält | Bemerkung |
|---|---|---|---|
| K9a (Budget steuert die Basis) | 5 | 5 | ρ 0,77 bis 0,79 bei 17 bis 33 folgenden Agenten, p ≤ 1,5e-4 |
| K9b (Budget-Agenten folgen seltener als r4) | 5 | 3 | hält bei ep_q4 < 5 und 8 cm und RMS < 5 cm. Bei den strengen Schwellen (ep_q4 < 3 cm, RMS < 3 cm) fallen auch r4-Agenten heraus (7 und 8 von 10), dann p 0,07 und 0,08 bei gleicher Richtung (34 und 46 % gegen 70 und 80 %) |
| K9c (θ 0,02 und 0,03 besser als die Gewichtsreihe) | 15 | 5 | Der Teil θ 0,03 hält auf 12 von 15 Punkten, der Teil θ 0,02 nur auf 5. Ohne Toleranz liegt bei θ 0,02 kaum ein Agent unter θ, weil das Budget als Anteil der Schritte formuliert ist |
| K1 (Basis-Bonus erzeugt den Bahnverlust) | 5 | 5 | D14 und D16: r0 folgt in keinem Fall (0 von 6), r1 und r2 in 8 oder 9 von 9, p ≤ 0,0014 |

**Deutung:**
- K9a und K1 hängen nicht an den Schwellen.
- K9b nur mit Schwelle nennen. Die Richtung ist überall gleich, die Signifikanz nicht.
- K9c auf θ 0,03 einschränken. Für θ 0,02 ist der Vorteil gegen die Gewichtsreihe nicht robust.

Datenquelle: `X4_5_{K9a,K9b,K9c,K1}_20261113_084521.csv` (dazu Runde 1 neu mit demselben Zeitstempel), Eingänge
`X_eval_X1_3_20261112_195325_*`, `X_eval_X4_1_20261110_233147_*`, `X_eval_X4_2_20261111_144608_*`.

Paper: Formulierung von K9 und K1. Offen.

### X4.6 Ablation: Woher kommt der Abstand zum Regler? ✅ 13.11.2026 (V4 abends)

**Umsetzung** (13.11.2026):
- `SK_desktop` bleibt unverändert. V1 trainiert auf `SK_desktop`, nur mit eigenen Beobachtungsgrenzen in der
  Reihenfolge der Beobachtung (A72). V2 und V3 bekommen eigene Modellkopien (`ext_x4_6_build_model`):
  `SK_x46` (Filter 0,95) und `SK_x46f` (Filter 0,85, als feste Zahl, damit er unter Fast Restart sicher wirkt).
- Erweiterte Beobachtung (38 Kanäle): die 29 bisherigen, der Ausgang des Rate Limiters im vorigen Schritt für
  J2, J4, J6 (Unit Delay) und der Sollpunkt in 0,25 s und 0,5 s relativ zum EE (`ext_ref_preview`, From
  Workspace im Agententakt). Grenzen der neuen Kanäle ±1.
- `ext_x4_6_train(variant, seed)`: genau der D16-Aufbau (`desktop_d12_train(4, seed, 3000, '', 'base_sync',
  0.9774)`), Unterschiede nur Grenzen, Modell und Kanalzahl. `ext_x4_6_run()`: V1, V2, V3 × Seeds 0–4, danach
  X0.1 (Studie X4_6).
- Mitgezogen: `ext_kinsim` (Optionen `obs_ext`, `filt_a`), `ext_x2_controller` und `ext_x2_sweep` (Option
  `filt_a`, für die Front mit dem schnelleren Filter), `desktop_run_episode` (Variablen EE_d25, EE_d50, Ausgabe
  `obs_ext`), `ext_eval_agent` (Modell aus dem cfg, nur für `SK_x46*`). Mit den Standardwerten laufen alle
  bisherigen Pfade wie vorher.

**Prüfung** (`ext_x4_6_check()`):
- `SK_desktop` vor und nach dem Bau der Kopien mit derselben Prüfsumme.
- Kurztraining je Variante (16 Episoden): läuft, 29 / 38 / 38 Kanäle, richtiges Modell.
- V2 und V3, Agent aus dem Kurztraining, nominal: Simscape gegen `ext_kinsim` RMS ≤ 3e-9 m, ori_max ≤ 7e-9 rad,
  Beobachtung ≤ 2,4e-8 (auch die neuen Kanäle).
- Bitgleichheit alter Agenten: D16 r4 s2 nominal über `ext_eval_batch` (parallel, wie alle X0.1-Zahlen) exakt
  gleich zu X1.3 (Abweichung 0). Ein serieller Lauf in der Hauptsitzung weicht um 2,4e-5 m und 1,8e-4 rad ab,
  auch mehrfach hintereinander. Das betrifft nur Läufe außerhalb des Pools und liegt nicht an X4.6. Für Zahlen
  gilt weiter der parallele Weg.

Datenquelle: `X4_6_check_*.csv`, Log `X4_6_check_matlab.log`, `X_eval_X46bitcheck_20261113_095516_*`.

**Lauf** (`ext_x4_6_run()`, 13.11.2026 09:55 bis 16:01): 15 Trainings ohne Fehler, je 21 bis 26 min, danach X0.1
für alle 15 Agenten (2,9 min). Front für V3 neu gerechnet mit denselben Einstellungen wie die bisherige Front F
aus X2.2, nur mit Filter 0,85: `ext_x2_sweep('filt_a', 0.85, 'variants', {'full_inv'}, 'j6', 0.9774)` (108
Läufe) und der Sweep mit Rückführung der Basislage (Kp 5, J6-Seite 0 und −1, kOri 0 bis 5, 8 β und Vorrang, 90
Läufe). Gegenprobe: Derselbe Sweep mit 0,95 trifft die gespeicherte Datei auf 5e-17.

**Auswertung** (`ext_x4_6_report()`): V0 sind die 10 D16-r4-Agenten (X0.1 aus X1.3), V1 bis V3 je 5 Seeds.
Faktor wie X2.2 gegen die Front mit derselben Kette (V0 bis V2 gegen F mit 0,95, V3 gegen F mit 0,85). Mittel
über 21 Episoden, in Klammern die nominale Episode. Tests vor dem Lauf festgelegt: jede Variante gegen die vorige,
Mann-Whitney, Holm über die drei Vergleiche je Kennzahl.

| Variante | folgt | RMS Median [mm] | ori_max Median [mrad] | Faktor Median (Bereich) | Ruck Median | Zweig J6 neg / pos / mid | q6 begrenzt |
|---|---|---|---|---|---|---|---|
| V0 D16 r4 | 10/10 | 13,9 (10,9) | 52,5 | 2,69 (2,24–5,70), nominal 2,10 | 7,2 | 1 / 8 / 1 | 57 % |
| V1 Grenzen | 5/5 | 12,9 (9,5) | 52,0 | 2,45 (1,95–3,58), nominal 1,80 | 5,9 | 1 / 4 / 0 | 0 |
| V2 + 9 Kanäle | 5/5 | 11,7 (9,6) | 51,8 | 2,25 (1,20–3,61), nominal 1,85 | 4,0 | 2 / 2 / 1 | 0 |
| V3 + Filter 0,85 | 5/5 | 12,9 (10,1) | 53,5 | 2,49 (1,85–2,73), nominal 1,96 | 34,8 | 0 / 5 / 0 | 0 |

- Faktor: Keine Variante unterscheidet sich von der vorigen (Mittel p 0,37 / 0,69 / 0,69, nominal 0,31 / 1 /
  0,55, nach Holm alle ≥ 0,93). Ebenso RMS, ori_max (Mittel und schlechteste Episode) und Anteil folgt (alle 1).
- Ruck: V3 gegen V2 34,8 gegen 4,0 (p 0,008, Holm 0,024). Der schnellere Filter gibt die Unruhe der Rohaktion an
  die Gelenke weiter. Das ist die einzige signifikante Änderung.
- Front: Mit Filter 0,85 ist die Front praktisch dieselbe. Kleinster RMS bei ori_max ≤ 10 / 20 / 30 / 60 mrad:
  11,92 / 5,42 / 5,17 / 5,17 mm mit 0,95, 11,92 / 5,42 / 5,17 / 5,17 mm mit 0,85.
- Beobachtungsgrenzen: In V1 bis V3 ist keine Beobachtung mehr begrenzt (V0: q6 im Median in 57 % der
  Schritte). Die Wahl des Zweigs ändert sich dadurch nicht. Wie in V0 nehmen die meisten Agenten den positiven
  Zweig mit etwa 50 mrad.
- Einzelfall V2 Seed 2: negativer Zweig, 10,2 mm bei 15,7 mrad (schlechteste Episode 20,4 mrad), Faktor 1,20,
  nominal 0,90. Das ist der erste Agent, der in der nominalen Episode vor der Front liegt (in X2.2 kleinster
  Faktor 1,50 nominal, 1,93 im Mittel). Ein Seed, kein Gruppeneffekt. V1 Seed 4 nimmt ebenfalls den negativen
  Zweig (12,9 mm, 17,8 mrad, Faktor 1,95).
- Gegenprobe kinematisch gegen Simscape (nominale Episode): höchstens 0,42 mm (V2 Seed 1, J6 in 39 % der
  Schritte gesättigt), 16 von 25 Agenten unter 0,01 mm.

**Nachtrag: Welcher Teil der Kette kostet den Regler?** (`ext_x4_6_chain()`, Einstellungen wie X2.1, kOri 0).
Kleinster RMS bei ori_max ≤ 20 mrad:

| Kette | Filter | RMS [mm] |
|---|---|---|
| volle Kette mit Inversion | 0,95 / 0,85 / 0,5 / ohne | 5,66 / 5,66 / 5,66 / 5,66 |
| nur Sättigung (ideal, X2.1) | ohne, ohne Rate Limiter | 1,21 |

Der Regler invertiert den Filter vollständig, der Filter kostet ihn also nichts. Der ganze Abstand zwischen idealer
und echter Kette (1,2 auf 5,7 mm, A73) entsteht am Rate Limiter (0,5 rad/s², also 0,0125 rad/s je Agentenschritt).
Bei ≤ 10 mrad liegen alle Ketten bei 11 bis 12 mm, dort begrenzt die Basisdrehung selbst.

**Deutung:**
- Die vor dem Lauf festgehaltene Erwartung trifft nur teilweise zu. V1 klein oder null: ja. V2 deutlich: nein,
  der Median sinkt von 2,45 auf 2,25, im Rahmen der Streuung der Seeds. V3 ähnlich für RL und Regler: ja, aber aus
  einem anderen Grund als erwartet. Der Filter ist für den Regler kein Engpass, für RL ebenfalls nicht.
- In den getesteten Varianten kommt der Abstand zum Regler damit weder von fehlender Information über die Kette
  und die kommende Bahn noch von der Filterzeitkonstante. Er sitzt eher im Lernverfahren und in der Wahl des
  Zweigs von J6. Die meisten Agenten bleiben auf dem positiven Zweig (etwa 50 mrad). Die wenigen auf dem
  negativen Zweig liegen der Front am nächsten (V2 Seed 2, V1 Seed 4). Das passt zur Diagnose von X1.3.
- Für das Interface heißt das: Eine schnellere Filterung bringt in Simulation keine Genauigkeit, aber etwa
  neunfachen Befehlsruck. Die Kette kostet den Regler über den Rate Limiter, nicht über den Filter (A75).

**Grenzen:** 5 Seeds je Variante. Bei 5 gegen 5 ist das kleinste mögliche p 0,008 (nach Holm 0,024). Nachweisbar
sind also nur Effekte, bei denen sich die Gruppen kaum überlappen. Ein Effekt von etwa 10 % auf den Faktor bleibt
unentdeckt. Die Varianten bauen aufeinander auf (Reihenfolge). V2 und V3 ändern die Beobachtung bzw. die
Sicherheitskette und laufen nicht mit den Deploy-Skripten. Nur Simulation. Der Rate Limiter wurde nicht variiert.
Das wäre die nächste Variante, wenn die Kette weiter zerlegt werden soll.

Datenquelle: `SavedAgents/MotionProfile/X4_6/X4_6_ppo_40hz_r4_V*_seed*_ep3000.mat`, `X4_6_runlog.csv`,
`X4_6_matlab.log`, `X_eval_X4_6_20261113_160116_*`,
`X4_6_report_{agents,groups,tests,front,frontPts}_20261113_160116.csv`, `X2_sweep_20261113_160801.csv`,
`X2_sweep_20261113_160832.csv`, `X4_6_chain_20261113_161818.csv`.

Paper: Abschnitt Vergleich mit dem Regler (Erklärung von K5), Ausblick Interface (Filter und Rate Limiter). Offen.

**Nachtrag 13.11.2026 abends: V4 (Rate Limiter 2 statt 0,5 rad/s²).** Nicht vor dem Lauf festgelegt, A75 hat die
Frage gestellt.
- Aufbau: V1 (29 Kanäle, richtige Grenzen) mit Rate Limiter 2 rad/s² als feste Zahl in der Modellkopie `SK_x46s`
  (`ext_x4_6_build_model('SK_x46s', 0.95, false, 2, false)`). Training wie V1, 5 Seeds, je 20 bis 23 min
  (`ext_x4_6_run('variants', {'V4'})`). Front F2 mit denselben Einstellungen wie F, Strecke und Regler mit 2 rad/s²
  (`ext_x2_sweep(..., 'slew', 2)`).
- Prüfung vorher (`ext_x4_6_check_v4()`): `SK_desktop` mit unveränderter Prüfsumme, 29 Kanäle, cfg.slew = 2.
  Sweep mit slew 0,5 bitgleich zur gespeicherten Front. Der Testagent erreichte den Rate Limiter nicht. Deshalb
  zusätzlich D16 r4 s2 in `SK_x46s`: 10,897 mm wie der Simulator mit 2 rad/s², mit 0,5 wären es 9,497 mm. Der Wert
  wirkt also.
- Neue X0.1-Auswertung aller 20 Agenten (`X_eval_X4_6_20261113_210932_*`). V1 bis V3 sind bitgleich zum
  Nachmittag.

| | V1 (0,5 rad/s²) | V4 (2 rad/s²) | p (Mann-Whitney) |
|---|---|---|---|
| folgt | 5/5 | 5/5 | 1 |
| RMS Median Mittel / nominal [mm] | 12,9 / 9,5 | 12,8 / 11,1 | 0,69 / 0,42 |
| ori_max Median [mrad] | 52,0 | 52,0 | 0,55 |
| Ruck Median | 5,9 | 23,2 | 0,008 |
| Rate Limiter am Anschlag (Anteil Schritte, nominal) | 31 % | 5 % | |
| Faktor gegen die eigene Front (Bereich) | 2,45 (1,95–3,58) | 9,46 (9,13–12,42) | 0,008 |
| Faktor gegen F mit 0,5 rad/s² | 2,45 | 2,49 | |

Front des Reglers, kleinster RMS bei ori_max ≤ 10 / 20 / 30 / 60 mrad: mit 0,5 rad/s² 11,9 / 5,4 / 5,2 / 5,2 mm,
mit 2 rad/s² 11,0 / 1,36 / 1,36 / 1,19 mm. Die ideale Kette (nur Sättigung) liegt bei 11,2 / 1,21 / 1,21 / 0,92 mm.

**Deutung V4:**
- Der Rate Limiter bremst den Regler, nicht die Agenten. Mit der vierfach schnelleren Kette wird der Regler etwa
  viermal genauer (5,2 auf 1,4 mm bei gleicher Basisdrehung) und liegt fast bei der idealen Kette. Die Agenten
  bleiben bei etwa 13 mm. Sie stoßen seltener an den Rate Limiter (31 auf 5 %), werden dadurch aber nicht
  genauer, nur unruhiger (Ruck etwa viermal höher).
- Damit ist die letzte geprüfte Ursache aus X4.6 ausgeschlossen. In diesem Aufbau setzt nicht die Schnittstelle
  die Genauigkeit der Agenten, sondern das Lernverfahren (PPO, 3000 Episoden, Reward r4). Bei der alten Kette
  verdeckt die Kette einen Teil dieses Abstands, weil sie den Regler auf 5,7 mm begrenzt. Mit der schnelleren
  Kette wächst der Faktor von 2,4 auf 9,5.
- Für X6: Die neue Kette hilft dem Regler (E18). Ob sie einem Agenten Millimeter erlaubt, ist offen. Die Hebel
  liegen eher bei Beobachtung, Reward und Training (Feinkanal, Feinterm, Curriculum, X6.3) als bei der Kette.
- Für X7: Ein Grundregler mit schneller Kette startet bei 1,4 mm. Residual RL hätte dort mehr zu verlieren als zu
  gewinnen, wenn die Korrektur so ungenau ist wie reines RL. Die Strafe auf |Δ| und ein kleines ε werden wichtig.

**Grenzen V4:** 5 Seeds, Nachtrag ohne Vorab-Erwartung, ein einzelner Test ohne Holm-Korrektur. Gleiches
Trainingsbudget und gleiche Hyperparameter wie V1. Mit einer schnelleren Kette könnten andere Einstellungen oder
mehr Episoden nötig sein. Der Reward ist für die alte Kette entstanden.

Datenquelle V4: `SavedAgents/MotionProfile/X4_6/X4_6_ppo_40hz_r4_V4_seed*_ep3000.mat`, `X4_6_runlog.csv`,
`X4_6_v4_matlab.log`, `X4_6_check_v4_*.csv`, `X_eval_X4_6_20261113_210932_*`,
`X4_6_report_{agents,groups,tests,front,frontPts}_20261113_210932.csv`, `X2_sweep_20261113_192053.csv`,
`X2_sweep_20261113_192136.csv`. Modell `evaluation/desktop/models/SK_x46s.slx`.

## X5 3D

### X5.1 Machbarkeit im kinematischen Simulator ✅ 10.11.2026 (SK_desktop offen)

**Frage:** Lässt sich eine echte 3D-Bahn mit allen sieben Gelenken fahren, und wie viel Basisdrehung spart der
Nullraum des Reglers?

**Aufbau:**
- Bahn `ext_ref_path` 'tilted': der Halbkreis (r = 0,2 m, 8,5 s), die Ebene um ±30° um die x-Achse durch den
  Startpunkt gekippt. Start (gestreckte Stellung, q0 = 0) und Anfangsrichtung bleiben gleich. Bei +30° läuft die
  Bahn nach +y aus (Ende 0,2 m neben und 0,346 m unter dem Start), bei −30° nach −y. Eine Drehung der Ebene um die
  senkrechte Achse wurde verworfen, J1 allein könnte sie ausgleichen.
- `ext_kinsim` und `ext_x2_controller` mit Option `lim` (sieben Geschwindigkeitsgrenzen). Alle sieben Gelenke
  mit 0,98 rad/s J1–J4 und 0,58 rad/s J5–J7 wie beim Set-Point. Aufgabe x, y, z. Standardwerte unverändert
  (Rβ 46 eben, J2/J4/J6: wieder 12,8 mm / 8,1 mrad wie X2.1).
- `ext_x5_1_feasibility()`: Bahnen eben, +30°, −30°. Gelenksätze J2/J4/J6 (0,9774 rad/s) und alle sieben. Regler
  R0, Rβ mit β 1 bis 1e4, Prioritätsform (Bahn zuerst, dann Basis im Nullraum), J6-Seite 0, −1, +1. Volle
  Befehlskette mit Inversion, die Prioritätsform zusätzlich mit idealer Kette. 180 Läufe, 3 min. Nominal,
  deterministisch.

**Zahlen** (RMS EE-Fehler / größte Basisdrehung, volle Kette):

| Bahn | Gelenke | R0 (ohne Nullraum) | Front, genau | Front, ruhig |
|---|---|---|---|---|
| eben | J2/J4/J6 | 2,1 mm / 69 mrad | 5,7 mm / 19,8 mrad (β 1) | 16,7 mm / 6,2 mrad (β 100) |
| eben | alle 7 | 2,1 mm / 68 mrad | 4,9 mm / 20,6 mrad (β 1) | 15,7 mm / 8,0 mrad (β 100), 31 mm / 2,8 mrad (β 1000) |
| +30° | J2/J4/J6 | 122 mm, folgt nicht | – | – |
| +30° | alle 7 | 1,8 mm / 13,8 mrad | 2,1 mm / 11,3 mrad (β 4,6) | 6,1 mm / 9,3 mrad (β 46), 15,7 mm / 5,6 mrad (β 1000) |
| −30° | J2/J4/J6 | 125 mm, folgt nicht | – | – |
| −30° | alle 7 | 4,2 mm / 124 mrad | 2,1 mm / 9,7 mrad (β 4,6) | 5,4 mm / 8,7 mrad (β 46), 15,8 mm / 4,9 mrad (β 1000) |

- Die gekippte Bahn ist mit allen sieben Gelenken in allen Reglerformen fahrbar. 27 von 30 (+30°) und 28 von 30
  (−30°) Läufen folgen. Kein Lauf verletzt eine Gelenkwinkelgrenze, die Läufe mit großem β liegen zeitweise an der
  Winkelgrenze von J5 oder J6 und bis zu 70 % der Schritte an einer Geschwindigkeitsgrenze.
- J2/J4/J6 allein folgen der gekippten Bahn nicht (122–128 mm). Die Aufgabe ist also echt dreidimensional.
- Die gestreckte Startstellung ist singulär (kleinster Singulärwert der EE-Jacobi-Matrix 1,7e-6, nach 0,25 s
  etwa 1e-3). Weil die Bahn entlang x beginnt, macht das keinem Regler Probleme. Ein anderer Start ist nicht nötig.
- In der Ebene bringen die zusätzlichen Gelenke kaum etwas: Die Front mit allen sieben liegt fast auf der von
  J2/J4/J6 und reicht nur bei sehr großem β weiter (2,8 mrad bei 31 mm).
- Die Kipprichtung entscheidet, wie viel der Nullraum bringt. Bei +30° dreht R0 die Basis schon nur um 13,8 mrad,
  der Nullraum senkt das bei gleicher Genauigkeit auf etwa 11 mrad. Bei −30° dreht R0 die Basis um 92–124 mrad
  (je nach J6-Seite), Rβ 4,6 bei gleicher Genauigkeit (2,1 mm) nur um 9,7 mrad. Das ist der Fall, in dem eine
  reaktionsarme Bewegung den Unterschied macht.
- Die gierigen Formen hängen stark vom Zweig ab (wie A73). Die Prioritätsform erreicht bei −30° mit idealer Kette
  1,0 mm / 11 mrad, mit voller Kette 3,3–4,4 mm / 83–106 mrad. Für den Vergleich mit RL in X5.3 zählt deshalb die
  Front über alle Formen und Seiten, nicht ein einzelner Regler.

**Beobachtungsgrenzen (A72) in 3D** (Grenzen aus D16 r4 s2, Reglerbahnen alle sieben Gelenke): Bei den
reaktionsarmen Lösungen liegt q7 in 43–63 % der Schritte außerhalb von ±1,22 rad (Rβ 4,6 und 46, beide
Kipprichtungen), q4 in bis zu 41 % und q5 in bis zu 21 % außerhalb von ±1,4 rad, q6 in bis zu 24 % außerhalb
von ±1,22 rad. Bei R0
sind es 21–40 % (q6 oder q7). dq bleibt fast immer innerhalb. Mit E8 wäre die Policy also gerade für die
Gelenkstellungen blind, die der Nullraum nutzt. Entscheidung E9 (10.11.): Für X5 werden die Grenzen in der
richtigen Reihenfolge gesetzt. E10 (10.11.): Die 3D-Bahn wird um −30° gekippt.

**Grenzen:** nur kinematisch und nominal, Regler mit exaktem Modell. Die Modellparameter `p_active` und
`p_path_id` in `SK_desktop` und die Bitgleichheitsprüfung folgen nach der Nachtkette (sie baut `SK_desktop` neu).

Datenquelle: `X5_1_feasibility_20261110_175620.csv`. Begrenzung: `ext_x5_1_obsclip()` (Ausgabe in der
Konsole, Zahlen oben).

Paper: neuer Abschnitt 3D (Aufgabe, Regler-Front). Offen, hängt an X5.2 und E4.

## X6 Set-Point

### E18 Neue Befehlskette: Tests und Reglervergleich ✅ 13.11.2026

**Frage:** Funktioniert die neue Kette (PLAN „Neue Befehlskette für X6“)? Und was macht die Kette allein aus,
bevor ein Agent trainiert wird? Gemessen mit demselben Regler auf alter und neuer Kette.

**Umsetzung:**
- `hardware/campaign/chain_step.m`, eine Datei für Simulator, Regler und später das Deploy-Skript:
  1. Skalierung der Aktion auf v_max, optional mit Filter erster Ordnung (α = exp(−Ts/τ)).
  2. Bremskurve vor den Winkelgrenzen: Geschwindigkeit zur Grenze höchstens √(2·a_brake·d), d = Abstand bis
     Grenze minus 5°, a_brake = 0,8·a_max.
  3. Beschleunigungsgrenze a_max·Ts.
  4. HW-Cap.

  Abweichung vom Entwurf: Die lineare Bremszone über 10° aus dem Deploy-Skript bremst bei voller Fahrt härter als
  die Beschleunigungsgrenze. Deshalb die Bremskurve aus dem Bremsweg.
- Winkelgrenzen nach dem Gen3-Datenblatt (J2 ±128,9°, J4 ±147,8°, J6 ±120,3°, J1, J3, J5, J7 endlos), nicht die
  Modellwerte von `SK_desktop` (J2 ±138°, J4 ±152°, J6 ±115°, J5 ±128°). Die Modellwerte fassen J2 und J4 weiter
  als der echte Arm. Gilt für Kette, Strecke (`ext_kinsim` Option `qLim`) und Regler (Option `qLim`) in X6. Die
  bisherigen Pfade behalten die Modellwerte.
- `ext_kinsim`: Option `chain` 'x6' mit `chainP`, Kennzahlen `x6_brake`, `x6_accel`, `x6_cap`. Dazu `refFcn`
  (eigene Referenz) und `noStop` (Abbruch aus `ext_reward` ignorieren). `ext_x2_controller`: Option `chainP`.
  Der Regler hält dann Beschleunigungsgrenze und Bremskurve als Schranken ein und gibt x ./ v_max aus.

**Tests** (`ext_x6_chain_test()`):
- Rate: Der Sprung auf J2 ergibt bei 10, 20 und 40 Hz zu gleichen Zeiten denselben Befehl (Abweichung ≤ 1e-16),
  ohne und mit Filter. 95 % nach 0,25 s (10 Hz 0,3 s wegen der Abtastung).
- Grenzen: 20 000 Zufallsschritte, |v| höchstens 0,95·v_cap, |Δv| höchstens a_max·Ts. Mit a = 0 bleibt v = 0.
- Bremskurve im Simulator (volle Aktion gegen die Datenblattgrenze, 20 Hz): J2, J4, J6 stehen 1,3 bis 1,5° vor
  der Grenze. Von den 5° Rand verbrauchen Verzögerung und Gelenkfilter also etwa 3,5°.
- Alte Pfade bitgleich: Sweep full_inv gegen die gespeicherte Datei 5e-17, D16 r4 s2 kinematisch 3e-18.

**Reglervergleich** (`ext_x6_chain_compare()`, 600 Läufe in 1,1 min):
- 100 Paare, vorläufig ohne Kollisionsprüfung. Start und Zielstellung gleichverteilt. Ziel ist der EE-Punkt nach
  einer offenen Gelenkbahn im frei schwebenden Simulator, d0 von 0,05 bis 1,2 m.
- Regler R0 (Kp 5, 7 Gelenke, x, y, z, Inversion der jeweiligen Kette). Referenz ist eine Gerade mit
  Minimum-Jerk-Profil (Dauer Tm 1,5 bis 10 s aus d0), Episode 15 s.
- Erfolg wie E11: ≤ 5 mm und ≤ 5 mm/s, 1 s lang. Nachlauf = Beginn des Haltefensters minus Tm. Negativ heißt,
  der Regler ist schon vor dem Ende der Referenz im 5-mm-Fenster.

| Kette | Aufbau | Erfolg | Nachlauf Median / 90 % / max [s] | Endfehler 95 % [mm] | Basisdrehung Median [mrad] |
|---|---|---|---|---|---|
| O10 | alt, 10 Hz (wie `fixed1`) | 86 | 1,35 / 6,2 / 8,0 | 23,8 | 120 |
| O20 | alt, 20 Hz | 95 | 0,10 / 4,4 / 6,8 | 12,4 | 120 |
| A | neu ohne Filter, v_max und a_max wie alt (0,5 rad/s²) | 94 | −0,21 / 5,0 / 9,6 | 4,2 | 122 |
| B | neu, v_max 0,95·HW-Cap, a_max 0,5 | 90 | −0,25 / 4,7 / 10,7 | 25,4 | 122 |
| C | neu, v_max 0,95·HW-Cap, a_max 2 | 99 | −0,29 / 0,24 / 1,5 | < 0,001 | 111 |
| D | wie C, Filter τ 0,1 s | 99 | 0,17 / 0,75 / 3,7 | < 0,001 | 110 |

- Gepaart: O20 gegen O10 erreicht 9 Paare mehr und keines weniger, Einschwingen im Median 0,55 s früher. C gegen
  O10: 13 mehr, keines weniger, Median 1,25 s früher. C gegen O20: 4 mehr, keines weniger. A gegen O20: 1 mehr,
  2 weniger. B gegen A: 1 mehr, 5 weniger. C gegen B: 9 mehr, keines weniger.
- Der Hebel ist die Beschleunigungsgrenze. Mit 2 statt 0,5 rad/s² bleibt der Nachlauf in 90 % der Paare unter
  0,25 s statt 4 bis 5 s. Filter weg (A) ändert für den Regler fast nichts, er invertiert den Filter wie beim
  Tracking (A75). Eine höhere v_max ohne höheres a_max (B) hilft nicht, eher im Gegenteil (90 statt 94).
- Der Wechsel von 10 auf 20 Hz bringt mit der alten Kette schon viel (86 auf 95). Bei der alten Kette ändert der
  Takt die Zeitkonstante von Filter und Rate Limiter mit.
- Ein Filter τ 0,1 s (D) kostet etwa 0,5 s Nachlauf (90 %), aber keinen Erfolg.
- Paar 94 (d0 1,16 m) scheitert mit jeder Kette (46 bis 63 mm). Das ist eher eine Grenze von R0 (ohne Nullraum
  für die Gelenkgrenzen) als der Kette. Mit a_max 0,5 rad/s² (O20, A, B, auch O10) scheitern einzelne Paare mit
  großem Endfehler (Paar 25 und 34: 96 bis 188 mm). Die Ursache ist nicht geprüft. Bei a_max 2 kommt das nicht
  vor. Korrektur 13.11.: Die erste Fassung vermutete die Bremskurve als Ursache. Das trifft nicht zu, weil die
  alte Kette keine Bremskurve hat und dieselben Paare verliert.
- Die Basisdrehung ist bei allen gleich (R0 minimiert sie nicht).

**Deutung:** Für den Regler entscheidet die Beschleunigungsgrenze, nicht der Filter. Für RL kann der Filter
trotzdem wichtig sein, weil die Policy ihn nicht invertiert. Das prüft der Pilot (X6.3, Varianten C und D und
die alte Kette als (c)). Der Wert a_max = 2 ist ein Platzhalter. Hält die Hardware ihn nicht, verschiebt sich das
Ergebnis Richtung A und B.

**Grenzen:** Paare ohne Kollisionsprüfung, URDF-Punkt statt Greiferspitze, Regler mit exaktem Modell, nur
kinematisch, ein Regler (R0). Die alte Kette hat im Simulator keine Bremszone, das Deploy-Skript schon.

Datenquelle: `X6_chain_test_20261113_190954.csv`, `X6_chain_compare_{pairs,runs,groups}_20261113_191125.csv`,
Log `X6_chain_compare_matlab.log`.

Paper: X6 (eigenes Paper oder Abschnitt, E7d), Interface-Design. Offen.

### X6.1 Paarsatz, Strecke und Umgebung ✅ 13.11.2026 (Pilot offen)

**Werkzeugpunkt:** `ext_kin_model` Option `tool_offset` (Standard null, alle bisherigen Pfade unverändert). X6 nutzt
[0; 0; 0,121] m im EE-Frame wie `kortex_frames` (tool_pose der Kortex-API). Gegen `getTransform` der Robotics
System Toolbox an 20 Zufallsstellungen: 3,5e-16 m.

**Paarsatz** (`ext_x6_pairs()`, 23,7 min):
- Kollisionsprüfung mit den Meshes der URDF und dem Basiswürfel. Der Greifer fehlt in der URDF und ist als
  Zylinder ergänzt (r 4,5 cm, 2 bis 17 cm vor dem Flansch). Eltern-Kind-Paare sind ausgenommen, 14 ms je Prüfung.
- Erste Fassung mit Greifer ab 0 cm: jede Stellung in Kollision (Greifer gegen Bracelet). Mit 2 cm Abstand ist
  die Grundstellung frei, 27 von 200 Zufallsstellungen kollidieren.
- Geprüft werden Start, Ziel und 12 Zwischenstellungen der Gelenkbahn. Das Ziel ist die Greiferspitze nach dieser
  Bahn im frei schwebenden Simulator.
- 500 Paare aus 4000 Ziehungen, 1217 davon mit Kollision verworfen. 464 Paare bleiben auf der ganzen Bahn
  mindestens 5 cm über der Montagefläche (`hw_ok`). Basisdrehung entlang der offenen Bahn im Median 149 mrad,
  höchstens 477 mrad.
- Die Schichtung ist nur teilweise gelungen, weil zufällige Stellungen selten tief oder kurz enden. Je d0-Bereich
  (0,05–0,2 / 0,2–0,5 / 0,5–0,8 / 0,8–1,2 m) und Bereich (unten / nah / weit):

| d0 | unten | nah | weit |
|---|---|---|---|
| 0,05–0,2 | 1 | 8 | 38 |
| 0,2–0,5 | 6 | 50 | 79 |
| 0,5–0,8 | 11 | 58 | 92 |
| 0,8–1,2 | 18 | 50 | 89 |

  Für eine echte Schichtung müssten Ziele gezielt erzeugt werden (Ziel zuerst, dann Inverse Kinematik). Das ist
  offen und erst nötig, wenn die Auswertung je Zelle ins Paper soll.
- Dazu 135 Laborpaare (15 Starts × 9 Ziele der Labortage, Zielstellung q_check_deg, Ziel bei fester Basis,
  d0 0,07 bis 1,64 m). Ob sie frei schwebend erreichbar sind, zeigt erst der Regler (X6.2).

**Strecke** (`ext_x6_plant`): der Kern von `ext_kinsim` als Schrittfunktion. Gegen `ext_kinsim` mit denselben
Aktionen (`ext_x6_plant_check()`, 3 × 300 Schritte, alle 7 Gelenke, Bremskurve aktiv): Werkzeugpunkt,
Gelenkwinkel und Basisdrehung bitgleich (Abweichung 0). 2 ms je Agentenschritt.

**Umgebung** (`ext_x6_env`, `rlFunctionEnv`, Entwurf für den Pilot):
- 50 Beobachtungskanäle, Grenzen ±Inf, damit nichts gekappt wird (A72).
- Reward und Abbruch wie X6.3 Punkt 4, Gewichte als Optionen.
- Prüfung (`ext_x6_env_check()`):
  - `validateEnvironment` besteht.
  - Ziel am Start und Aktion null ergibt Erfolg nach 20 Schritten (1 s, +50).
  - Aktion null bei einem Paar: kein Abbruch, Ende nach 15 s, Fehler bleibt d0.
  - Volle Aktion ergibt Abbruch nach 1 s (−50). Die Kette bleibt in ihren Grenzen.
  - 2,0 ms je `step`, größter Betrag der Beobachtung 1,2.

**Offen:** Trainings-Paarsatz getrennt vom Auswertesatz (anderer Seed). Kollision im Training (heute nur in den
Paaren geprüft, die Policy kann durch sich selbst fahren). Gewichte des Rewards und Curriculum im Pilot.

Datenquelle: `X6_pairs_20261113_195451.mat` / `.csv`, Log `X6_pairs_matlab.log`,
`X6_plant_check_20261113_193228.csv`, `X6_env_check_20261113_195519.csv`.

Paper: X6 (Methode, Auswertesatz). Offen.

## Gliederung (für Phase P)

Wird nach X1 und X2 vorgeschlagen.
