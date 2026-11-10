# Ausbau-Plan: vom Fehlerbericht zum Beitrag

Stand 10.11.2026. Nachfolger von `evaluation/desktop/DESKTOP_PLAN.md`. Dort sind D0 bis D20 abgeschlossen. Den alten
Plan nur für Einzelheiten lesen (per Suche nach der D-Nummer), nicht komplett.

**Dateien dieses Ausbaus:**
- `PLAN.md` (diese Datei): was gemacht wird, warum, in welcher Reihenfolge, und der Stand jedes Schritts.
- `RESULTS.md`: alle Ergebnisse mit Zahlen, Aufruf und Datenquelle. Einzige Quelle für spätere Paper-Zahlen.
- Skripte: `evaluation/extension/ext_<id>_*.m` (z. B. `ext_x1_train.m`). Daten: `data/simulation/extension/<ID>_*`.
  Agenten: `SavedAgents/MotionProfile/X<n>/`.

## Arbeitsweise

1. Zu Beginn jeder Sitzung: Übersicht unten und den Abschnitt „Kernaussagen“ in `RESULTS.md` lesen. Das Paper
   (`ISPaRo/ISpaRo/root.tex`) und den alten Desktop-Plan nur gezielt durchsuchen, wenn eine Angabe fehlt.
2. Vor einem Lauf: Status in der Übersicht auf 🔄 setzen und die Rechenzeit grob abschätzen.
3. Nach einem Lauf: sofort in `RESULTS.md` eintragen (Frage, Aufbau mit Aufruf, Zahlen, Deutung, Grenzen,
   Datenquelle). Danach Status hier auf ✅ setzen. Ergebnisse stehen nie nur im Chat.
4. Das Paper wird erst in Phase P geändert. Bis dahin sammelt `RESULTS.md` alles.
5. Lange Trainings als eigenständigen Prozess starten (`matlab -batch` außerhalb des Hintergrundauftrags).
   Hintergrundaufträge enden nach etwa 30 min (Erfahrung aus D20).
6. Jeder gespeicherte Agent bekommt in `cfg` den Git-Commit, den Modellnamen und alle Parameter. Zwischenstände
   nur als kleiner `agent` speichern, nicht als Toolbox-Checkpoint (D20: 37 GB).

Status-Legende: ⬜ offen, 🔄 läuft, ✅ erledigt, ⏸ wartet auf Entscheidung oder Labor, ❌ verworfen (mit Grund).

## Kontext in einer Minute

- **Paper:** „From Free-Floating Simulation to Fixed-Base Hardware“ (Ermisch, Oberdörfer, Kaigom). Bei iSpaRo 2026
  abgelehnt. Grund laut AE: zu wenig wissenschaftlicher Beitrag, Hauptbeitrag wirke wie ein Fehlerfund, die feste
  Basis schwäche die Sim-to-Real-Aussage. Die heutigen zwei Beiträge sind beide Diagnosen eigener Fehler
  (Beobachtungsfehler im Deploy-Skript, Basis-Bonus im Reward). Das Access-Paper (planarer 4-DOF-Benchmark,
  10 Seeds, Statistik) ist angenommen und noch nicht erschienen. Dieses Paper baut darauf auf und soll stärker sein.
- **Ziel des Ausbaus:** Eine Forschungsfrage mit übertragbarer Antwort, eine modellbasierte Vergleichsbasis,
  Statistik auf Access-Niveau, und ein geschlossener Free-Floating-Test auf dem festen Arm.
- **Neue Kernfrage:** RL-Policies landen je nach Seed auf verschiedenen Punkten des Zielkonflikts zwischen
  Tracking-Genauigkeit und Basisdrehung, das Reward-Gewicht steuert das nicht (D17). Lässt sich der Punkt mit
  einer Nebenbedingung zuverlässig wählen? Wie weit liegt RL von einem modellbasierten Regler entfernt, und wer
  ist robuster gegen falsche Trägheitsparameter?
- **Simulation:** `SK_desktop` (aus `desktop_build_model.m`), Kinova Gen3 auf 65-kg-Würfel, frei schwebend,
  Gelenke bewegungsgesteuert (Geschwindigkeitsbefehl wird exakt integriert). Halbkreis r = 0,2 m in der x–z-Ebene,
  8,5 s, nur J2, J4, J6 aktiv. Parameter u. a. `p_base_mass` (1e9 = feste Basis), `p_j6_lim`, `p_reward_mode`
  (0 heutiger Reward, 1 ohne Basis-Terme, 2 Basis-Bonus nur auf der Bahn, 4 wie 2 plus glatter Basis-Term),
  `p_base_w` (Gewicht des glatten Terms).
- **Training:** `desktop_d12_train(mode, seed, nEp, tag, 'base_sync', 0.9774, w)`: PPO, Optionen des frühen PPO,
  synchron auf 8 Workern, Gradient Clipping. 1000 Episoden ≈ 7 min, 3000 Episoden ≈ 21–26 min. Paralleles
  Training ist nicht bitgenau reproduzierbar, jeder Lauf ist ein unabhängiges Stichprobenelement.
- **Kinematik:** `desktop_freefloat.m` liefert die verallgemeinerte Jacobi-Matrix (Umetani/Yoshida) aus der URDF.
  Weil die Gelenke bewegungsgesteuert sind und der Anfangsimpuls null ist, hängt die Basisbewegung nur von der
  Gelenkbahn ab. Eingespielte Gelenkbahnen treffen Simscape auf 1–1,5 mrad (D15, D19).
- **Hardware:** Kinova Gen3, fest montiert, Deploy-Skript `hardware/campaign/deploy_tracking_v24.m`. Die
  High-Level-API begrenzt die Schleife auf 20 Hz. Die Basis-Kanäle der Beobachtung werden heute nominal gesetzt.
- **Ausgangszahlen** (D14 bis D20) stehen in `RESULTS.md`, Abschnitt „Ausgangslage“.

## Übersicht

| ID | Aufgabe | Arbeit | Rechenzeit | braucht | Status |
|---|---|---|---|---|---|
| X0.1 | Einheitliches Auswerteprotokoll und Statistik-Skript | 1 Tag | 1 h | Entscheidung E1 | ✅ 10.11. |
| X0.2 | Kinematischer Closed-Loop-Simulator (Policy, Befehlskette, GJM), gegen Simscape validiert | 2–3 Tage | 1 h | – | ✅ 10.11. |
| X0.3 | Literaturprüfung für X2 und X3 (Neuheit, Zitate) | ½–1 Tag | – | – | ✅ 10.11. |
| X1.1 | Lagrange-PPO umsetzen (Kostensignal, duale Aktualisierung, Logging) | 2 Tage | 1 h | – | 🔄 Code ✅ 10.11., Neubau SK_desktop offen |
| X1.2 | Pilot: Kostenform und Schrittweite | ½ Tag | ≈ 4 h | E2 | ⬜ |
| X1.3 | Hauptlauf: 5 Budgets × 10 Seeds, dazu r1 × 10 Seeds | 1 Tag | ≈ 25–30 h | E2 | ⬜ |
| X1.4 | Sicherheitsfilter (CBF auf die Basisdrehung) auf r1-Agenten | 2 Tage | 2 h | X0.2 | 🔄 Teil 1 ✅ 10.11. |
| X2.1 | Modellbasierter Regler (GJM, Nullraum), Machbarkeit auf dem Halbkreis | 2 Tage | < 1 h | X0.2 | ✅ 10.11. |
| X2.2 | Modellbasierte Pareto-Front, Vergleich mit RL | 1 Tag | < 1 h | X1.3, X4.1 | ⬜ |
| X2.3 | Robustheit gegen falsche Trägheitsparameter, RL gegen Regler | 2 Tage | 3 h | X2.1, X1.3 | 🔄 Teil 1 ✅ 10.11. |
| X2.4 | RL mit Domain Randomization (DR-M und DR-voll), je 10 Seeds | 1 Tag | ≈ 10 h | – | 🔄 Nacht 10./11.11. |
| X3.1 | Kinematische Free-Floating-Emulation im Deploy-Skript, Validierung in Simulation | 3 Tage | 2 h | X0.2 | ✅ 10.11. (Vorhersage offen) |
| X3.2 | Labortag: Emulation an gegen aus | 1 Tag Labor + 1 Tag Auswertung | – | Labor, E5 | ⏸ |
| X4.1 | Gewichtsreihe aus D17 auf 10 Seeds auffüllen | ½ Tag | ≈ 13 h | E3 | 🔄 läuft seit 10.11. 10:51 |
| X4.2 | Alle Bestandsagenten mit dem Protokoll X0.1 neu auswerten | ½ Tag | 2 h | X0.1 | ⬜ |
| X4.3 | Ratenpaar D10 auf 10 Seeds (optional) | ½ Tag | ≈ 3 h | E6 | ⏸ |
| X4.4 | Entscheidung, was aus dem Paper fliegt oder in den Anhang geht | ½ Tag | – | Betreuer | ⏸ |
| X5.1 | 3D-Bahn mit allen 7 Gelenken: Modell, Machbarkeit mit dem Regler aus X2 | 2–3 Tage | 1 h | X2.1 | 🔄 Machbarkeit ✅ 10.11., SK_desktop offen |
| X5.2 | Pilot 3D: 2 Varianten × 2 Seeds, Go/No-Go | ½ Tag | ≈ 3 h | X5.1 | ⬜ |
| X5.3 | Hauptlauf 3D: 10 Seeds, Vergleich mit Nullraum-Regler | 1 Tag | ≈ 6–8 h | E4 | ⏸ |
| P | Paper neu aufbauen und Ergebnisse übertragen | 2–3 Wochen | – | alle | ⏸ |

Summe Rechenzeit ohne X5.3 etwa 55–65 h. Das sind etwa eine bis eineinhalb Wochen, wenn nachts und am Wochenende
trainiert wird. Die Arbeit liegt bei etwa vier bis sechs Wochen, das Paper danach bei zwei bis drei Wochen.

## Reihenfolge

1. **Woche 1:** X0.1, X0.2, X0.3. Nachts X4.1 (braucht nur die bestehenden Skripte).
2. **Woche 2:** X1.1 und X1.2, X2.1. Ab dem Wochenende X1.3.
3. **Woche 3:** X2.2, X2.3, X1.4, nachts X2.4. Parallel X3.1.
4. **Woche 4:** X5.1 und X5.2, dann Go/No-Go (E4). X4.2.
5. **Zwischenstand mit dem Betreuer:** Geschichte festlegen (E7), X4.4 entscheiden, Labortermin für X3.2.
6. **Danach:** X5.3, X3.2, dann Phase P.

X1 und X2 entscheiden, ob die neue Geschichte trägt. Fallen beide Ergebnisse unerwartet aus (Nebenbedingung hilft
nicht, Regler ist überall besser), ist das trotzdem ein Befund. Die Gewichtung im Paper ändert sich dann.

---

## X0 Grundlage

### X0.1 Auswerteprotokoll und Statistik

**Warum:** Heute nutzt jede Studie ein anderes Protokoll (eine deterministische plus zehn stochastische Episoden,
20 Basismassen-Ziehungen, ...). Für Vergleiche über X1, X2, X4 und X5 braucht es eines.

**Vorschlag (Entscheidung E1):**
- Je Agent 21 deterministische Episoden: die nominale Startstellung und 20 Startstellungen mit gleichverteilter
  Störung von ±2° (E1, ursprünglich ±1°) auf den aktiven Gelenken. Die Störungen kommen aus einem festen Zufallsstrom und sind für alle
  Agenten gleich (gepaart, wie im Access-Paper). Basismasse 65 kg, J6 0,9774 rad/s, Solver 5 ms, 40 Hz.
- Kennzahlen je Episode: RMS-Fehler, mittlerer Fehler im letzten Viertel, größter Fehler, größte Basisdrehung,
  größte Basis-Winkelgeschwindigkeit, Jerk des Befehls, Abbruch. Je Agent der Mittelwert über die 21 Episoden.
  Statistische Einheit ist der Trainingslauf (Seed), nicht die Episode.
- „Folgt der Bahn“: keine Episode bricht ab und das letzte Viertel liegt in jeder Episode unter 50 mm.
- „Hält das Budget θ“: größte Basisdrehung in jeder Episode ≤ θ + 0,005 rad.
- Tests wie im Access-Paper: Anteile mit Fisher, Kennzahlen mit zweiseitigem Mann-Whitney-U, Holm-Korrektur über
  die Vergleiche zur selben Referenz, 95-%-Bootstrap-Intervall des Mittelwerts (2000 Ziehungen). Streuung über die
  Seeds als Interquartilsabstand.

**Umsetzung:** `ext_eval_agent.m` (baut auf `desktop_run_episode.m` auf, ergänzt die Startstörung, falls sie
fehlt), `ext_eval_batch.m` (Liste von Agenten, parallel), `ext_stats.py` oder MATLAB, je nachdem ob die
Statistics Toolbox vorhanden ist (prüfen). Ergebnis je Agent eine Zeile in `X_eval_<Studie>_<Zeit>.csv`.

**Fertig, wenn:** Die Auswertung eines D17-Agenten mit nur der nominalen Episode die D17-Zahl reproduziert.

### X0.2 Kinematischer Closed-Loop-Simulator

**Warum:** Gelenke bewegungsgesteuert plus Impuls null heißt, dass das frei schwebende System rein kinematisch ist.
Ein Simulator aus Policy, Befehlskette (Sättigung, IIR-Filter, Rate Limiter) und verallgemeinerter Jacobi-Matrix
ist exakt bis auf den Integrationsfehler und deutlich schneller als Simscape. X1.4, X2, X3 und X5 brauchen ihn.

**Umsetzung:** `ext_kinsim.m`. Eingaben: Policy oder Regler (Funktions-Handle), Bahn, Grenzen, Parameter der
Basis (Masse, Trägheit, Schwerpunktlage), Agenten- und Integrationsschritt. Baut die 29 Beobachtungen in derselben
Reihenfolge und mit denselben Vorzeichen wie `SK_desktop` (A22-Lehre: Beobachtung immer gegen das Modell prüfen).
Integriert Gelenke und Basislage (Quaternion) mit festem Schritt.

**Validierung:** Drei Agenten (frühes PPO, D16 r4 s2, Optimized) deterministisch in `SK_desktop` und in
`ext_kinsim`. Ziel: Beobachtungen kanalweise, EE-Bahn auf ≤ 2 mm RMS, Basisdrehung auf ≤ 2 mrad. Ohne diese
Übereinstimmung keine Aussage aus dem Simulator ins Paper, nur Simscape-Zahlen.

### X0.3 Literaturprüfung ✅ 10.11.2026

Ergebnis in `RESULTS.md`, X0.3. X3 wird als Prüfmethode beschrieben, nicht als neue Emulationsidee.


- Für X2: Umetani und Yoshida (GJM), Nenchev u. a. (Reaction Null Space), Papadopoulos und Dubowsky, Kaigom 2011
  (schon zitiert). Was ist der übliche modellbasierte Vergleichsregler für Basisstörung?
- Für X3: Vafa und Dubowsky (Virtual Manipulator), Liang, Xu und Bergerman (Dynamically Equivalent Manipulator),
  DLR OOS-SIM, Emulation frei schwebender Systeme mit Industrierobotern. Gibt es die rein kinematische Emulation mit
  einem einzelnen festen Arm für geschwindigkeitsgeregelte Policies schon? Davon hängt ab, ob X3 als Beitrag oder
  als Methode beschrieben wird.
- Für X1: Constrained RL (Achiam 2017 CPO, Ray u. a. 2019 PPO-Lagrangian, Stooke u. a. 2020 PID-Lagrangian),
  CBF-Sicherheitsfilter (Ames 2019). Wurde das für Basisstörung bei Space-Manipulatoren schon gemacht?
- Ergebnis: Liste mit Fundstelle und einem Satz zur Abgrenzung in `RESULTS.md`, Abschnitt X0.3.

---

## X1 Zielkonflikt mit Nebenbedingung steuern

**Frage:** Wählt eine explizite Nebenbedingung auf die Basisdrehung den Punkt auf dem Zielkonflikt zuverlässig, wo
das Reward-Gewicht es nicht tut (D17)?

**Hypothesen:**
- H1a: Für jedes erreichbare Budget θ hält die Mehrheit der Seeds das Budget ein (≥ 8 von 10).
- H1b: Die Streuung der Basisdrehung über die Seeds ist kleiner als in der Gewichtsreihe (X4.1).
- H1c: Der Tracking-Fehler steigt monoton, wenn θ sinkt. Zusammen ergibt das eine Pareto-Front.
- Für θ = 0,02 rad wird kein sicheres Einhalten erwartet. D15 fand als kleinste Basisdrehung etwa 0,021 rad bei
  ≤ 22 mm Bahnfehler (obere Schranke).

### X1.1 Umsetzung

Stand 10.11.: Code und Kurztest fertig (`ext_x1_train`, `ext_x1_check`, Ergebnis in `RESULTS.md`). Offen: nach dem
Ende von X4.1 `desktop_build_model(true)`, dann `ext_x0_check_model('compare')` und `SK_x1test.slx` löschen.
SK_desktop darf während eines Trainings nicht neu gebaut werden, jeder Lauf lädt es von der Platte.

- **Reward:** neuer Modus 5 in `desktop_build_model.m`: r1 (nur Tracking, keine Basis-Terme) minus λ·c_t. Die Basis
  wirkt dann nur über die Nebenbedingung. Neue Modellparameter `p_lambda`, `p_theta`, `p_cost_type`.
- **Kosten:** Kandidat A (Indikator): c_t = 1 wenn |ori_t| > θ, Nebenbedingung: Anteil solcher Schritte je
  Episode ≤ δ = 0,02. Kandidat B (Scharnier): c_t = max(0, |ori_t| − θ)/θ, Nebenbedingung: Mittel ≤ δ. Auswahl in
  X1.2.
- **Duale Aktualisierung:** Training in Blöcken (Vorschlag 100 Episoden). Nach jedem Block
  λ ← max(0, λ + η·(Ĉ − δ)), λ begrenzt auf 20. Ĉ ist die mittlere Episodenkosten des Blocks. Agent und
  Optimiererzustand bleiben zwischen den Blöcken erhalten (wie bei CDR im Paper, Sec. IV-C). Optional später
  PID-Lagrange gegen Schwingen von λ.
- **Ĉ messen:** Kosten im Reward-Block berechnen und als Signal loggen, dann aus `SimulationInfo` des
  Trainingsergebnisses lesen. Ersatz, falls das parallel nicht geht: nach jedem Block acht kurze Episoden.
- **Logging:** λ, Ĉ und Return je Block in `X1_<Name>_dual.csv`.
- **Kurztest:** 2 Blöcke à 16 Episoden. Prüfen, dass λ bei den Workern ankommt (wie `p_base_w` in D17) und dass
  Modus 0, 2 und 4 unverändert bitgleiche Returns liefern.
- Skripte: `ext_x1_train.m` (äußere Schleife um `train`), `ext_x1_run.m` (Liste von Budgets und Seeds).

### X1.2 Pilot

θ = 0,03 rad, Kandidat A und B, η ∈ {0,5; 2}, zwei Seeds, 3000 Episoden: 8 Läufe, etwa 4 h.
Auswahl nach: λ konvergiert ohne Dauerschwingung, Budget gehalten, Bahn gefolgt. Entscheidung E2 mit diesen
Kurven. Fällt der Overhead der wiederholten `train`-Aufrufe zu groß aus, Blöcke auf 200 Episoden.

### X1.3 Hauptlauf

- θ ∈ {0,02; 0,03; 0,04; 0,05; 0,06} rad × Seeds 0–9 × 3000 Episoden: 50 Läufe.
- Referenz: r1 ohne Nebenbedingung × Seeds 0–9 × 3000 Episoden: 10 Läufe. D14 hat r1 nur mit 1000 Episoden und
  drei Seeds.
- Rechenzeit etwa 60 × 25–30 min ≈ 25–30 h.
- Auswertung mit X0.1. Abbildung: Tracking-Fehler gegen Basisdrehung, je Budget eine Farbe, Gewichtsreihe aus
  X4.1 grau dahinter, modellbasierte Front aus X2.2 als Linie. Tabelle: je Budget Anteil „folgt der Bahn“, Anteil
  „hält das Budget“, Median und IQR beider Größen.
- Tests: Anteil „hält das Budget“ mit Fisher gegen die Gewichtsreihe. Streuung der Basisdrehung: IQR mit
  Bootstrap-Intervall. Front: Spearman zwischen θ und RMS.

### X1.4 Sicherheitsfilter

**Frage:** Hält ein modellbasierter Filter das Budget auch für eine Policy ohne Basis-Training, und was kostet das
an Tracking?

- Filter nach der Befehlskette, vor der Integration: h = θ² − φ², Bedingung ḣ ≥ −α·h. Mit der GJM ist φ̇ linear in
  q̇, also eine lineare Ungleichung. Kleinste Korrektur von q̇ in geschlossener Form (eine Ungleichung, keine
  QP-Bibliothek nötig). Planar ist φ der Drehwinkel um y. In 3D (X5) die Norm des Drehvektors.
- Zielkonflikt im Aufbau: Der Filter kann die Beschleunigungsgrenze des Rate Limiters verletzen. Beide Varianten
  rechnen (Filter vor und nach dem Rate Limiter) und den Unterschied angeben.
- Agenten: die zehn r1-Agenten aus X1.3, ohne Neutraining, θ wie in X1.3, α ∈ {1; 5} 1/s. Im kinematischen
  Simulator (X0.2), drei Fälle zur Kontrolle in Simscape mit einem Filterblock.
- Der Filter braucht das Modell. Deshalb gehört er auch in die Robustheitsprüfung X2.3.
- Skript `ext_x1_shield.m`.

---

## X2 Modellbasierte Vergleichsbasis

**Frage:** Wie weit liegen die RL-Policies von einem modellbasierten Regler mit Basisminimierung entfernt, und wer
verliert mehr, wenn die Trägheitsparameter falsch sind? Die Einleitung des Papers behauptet heute ohne Beleg, dass
modellbasierte Regelung an ungenauen Trägheitsparametern leidet.

### X2.1 Regler und Machbarkeit

- **Regler R0:** Resolved-Rate auf der verallgemeinerten Jacobi-Matrix J*, q̇ = J*⁺ (v_ref + K·e_p). Basis frei.
- **Regler Rβ:** wie R0, dazu im Nullraum die Minimierung der Basis-Winkelgeschwindigkeit mit Gewicht β
  (gewichtete Pseudoinverse oder erweiterte Aufgabe [EE; ω_b = 0] mit Gewichtung). Planar: 2 Aufgaben, 3 Gelenke,
  also ein redundanter Freiheitsgrad.
- Gleiche Gelenkgrenzen und Sättigung wie die Agenten. Zwei Varianten: nur Sättigung, und mit voller Befehlskette.
  Beide berichten, damit der Vergleich fair ist.
- In `ext_kinsim` (X0.2). Drei Fälle zur Kontrolle in Simscape über einen Reglerblock in einer Kopie von
  `SK_desktop`.
- Skripte `ext_x2_controller.m`, `ext_x2_sweep.m`. Startpunkt ist `desktop_freefloat.m` und die schrittweise
  Rechnung aus D15.
- **Fertig, wenn:** R0 dem Halbkreis auf ≤ 5 mm RMS folgt und die Basisdrehung von R0 und der Rβ-Reihe zu D15
  passt (0,021–0,076 rad je nach Grenzen).

### X2.2 Pareto-Front

- β in etwa 10 Stufen von 0 bis groß, dazu K in zwei Stufen. Ergebnis: Kurve RMS gegen größte Basisdrehung.
- Vergleich mit X1.3 und X4.1 in derselben Abbildung. Kennzahl: Abstand jedes RL-Agenten zur Front
  (z. B. zusätzlicher RMS-Fehler bei gleicher Basisdrehung).

### X2.3 Robustheit gegen falsche Trägheitsparameter

- Regler und Filter (X1.4) rechnen mit den Nominalwerten. Die Strecke bekommt andere Werte:
  Basismasse und -trägheit × {0,25; 0,5; 0,75; 1,5; 2} (Bereich wie CDR-2), Masse der Glieder × {0,8; 1,2},
  Lage des Arms auf der Basis ± 0,05 m.
- Dieselben Strecken für die RL-Agenten: die Medianagenten je Budget aus X1.3, die r4-Agenten, und X2.4.
  Basismasse in Simscape über `p_base_mass`. Glieder und Lage nur im kinematischen Simulator, wenn X0.2 validiert
  ist.
- Kennzahlen: Verlust gegenüber nominal in RMS und Basisdrehung, Anteil „hält das Budget“.
- Erwartung offen. Beides ist ein Befund: Der Regler dominiert auch mit Fehlern, oder RL mit Randomisierung
  verliert weniger.

### X2.4 RL mit Domain Randomization

Geändert am 10.11.2026 (Nutzer): beide Varianten, Reward r4 mit Gewicht 2 wie die 20 Bestandsagenten, damit die
Randomisierung der einzige Unterschied ist. Nicht mehr auf X1.3 warten. Eine Variante mit Nebenbedingung kann folgen.
- DR-M: Basismasse ×[0,25; 2] und Trägheitsfaktor ×[0,5; 2], beide log-gleichverteilt, je Episode.
- DR-voll: dazu Verzögerung 0–2 Agentenschritte, Verstärkung [0,9; 1,1], Messrauschen 0–2-fach realistisch,
  Startstellung J2/J4/J6 ±2°.
- Seeds 0–9, 3000 Episoden, `ext_x2_4_train`, gestartet von `ext_x2_4_night` nach X4.1.
- Vorher geprüft (`ext_x2_4_tunable`): Mit Fast Restart wurden Basismasse (compiletime) und Verzögerung
  (Dialogwert) stillschweigend ignoriert. Jetzt Masse mit runtime, Verzögerung über einen Eingangsport. Modi 0, 2, 4
  bleiben bitgleich. Kurztraining mit 16 Episoden: jede Episode passt zu genau einer gezogenen Kombination
  (Abweichung ≤ 1e-6, nächste ≥ 0,017).
- Fairness: Der Regler darf auf denselben Bereich eingestellt werden (β, Kp, kOri nach dem schlechtesten Fall über
  die Trainingsverteilung). Test auf den 26 Szenarien aus X2.3, ein Teil liegt bewusst außerhalb des
  Trainingsbereichs (Gliedmassen, Montage, Servo, Drift, feste Messfehler).
- Ersetzt im Paper die nicht reproduzierbare CDR-Studie (ein Seed je Merkmal, Modell nicht archiviert), soweit
  die Basismasse betroffen ist.

---

## X3 Kinematische Free-Floating-Emulation auf dem festen Arm

**Frage:** Lässt sich der geschlossene Free-Floating-Regelkreis auf kinematischer Ebene mit dem fest montierten Arm
testen, wenn das Deploy-Skript die Basisbewegung aus den gemessenen Gelenkwinkeln mitrechnet?

**Begründung:** Gelenke bewegungsgesteuert, Impuls null, keine äußeren Kräfte. Dann ist die Basislage eine Funktion
des Wegs im Gelenkraum (D19: Hardware-Gelenkbahnen treffen die Fixed-Base-Simulation auf 2 mrad). Das Skript kann
die neun Basis-Kanäle damit füllen und den EE-Fehler im Inertialsystem bilden. Die Policy reagiert dann auf die
(virtuelle) Basis wie in der Simulation.

**Grenzen (gehören ins Paper):** nur Geschwindigkeitsebene, keine Gelenkmomente und keine Kontakte, Schwerkraft
wirkt auf den echten Arm (nur über das Servoverhalten sichtbar), Anfangsimpuls null, Trägheitsparameter aus dem
Modell. Am 25.09.2026 war „virtuelle Basis im Loop“ als Teil von Option B verworfen worden (Aufwand). Der Aufwand
ist kleiner als damals gedacht, weil die Rechnung schon existiert.

### X3.1 Umsetzung und Validierung in Simulation

- Funktion `virtual_base_step.m` (eine Datei für Simulator und Deploy-Skript, wie bei der Befehlskette): aus q_k und
  q_{k−1} das Inkrement der Basislage über die GJM am Mittelpunkt, Integration der Lage, Basisgeschwindigkeit aus
  dem Inkrement und der gemessenen Schrittzeit, EE-Lage im Inertialsystem, Beobachtungsvektor wie im Training.
- Rechenzeit pro Schritt messen. Ziel deutlich unter den freien 20 ms der 50-ms-Schleife (`getAction` 4,6 ms).
- `deploy_tracking_v25.m`: v24 plus Schalter `emulateBase`, sonst unverändert. Trockenlauf (kinematisch) mit dem
  Schalter.
- Validierung in drei Stufen: (1) Gelenkbahnen aus Simscape eingespielt, Basislage gegen Simscape (wie D15/D19).
  (2) Trockenlauf mit Emulation gegen `SK_desktop` frei schwebend, gleicher Agent, bei 40 Hz und bei 20 Hz:
  EE-Bahn ≤ 2 mm RMS, Basisdrehung ≤ 2 mrad. (3) Wie (2) mit einer simulierten Schrittzeit-Streuung wie auf der
  Hardware.
- Vorhersage für X3.2: jede geplante Hardware-Bedingung einmal im Trockenlauf, Tabelle `X3_prediction.csv`.

### X3.2 Labortag (wartet auf Laborzugang)

- Agenten (Entscheidung E5): r0 (Einbruch), r4 ruhig (D16 s2, 1000 Episoden), r4 genau (D16 s7 oder s4), der
  Medianagent für θ = 0,03 und 0,05 aus X1.3, eventuell ein X2.4-Agent.
- Je Agent Emulation aus und an, je fünf Läufe, Halbkreis 8,5 s, Faktor 1,0. Etwa 60 Läufe.
- Vorher der übliche Anfahr- und Trockenlauf-Check, OOD-Grenzen wie am zweiten Labortag. Die Emulation ändert die
  Bahn der Gelenke, deshalb jede Bedingung erst im Trockenlauf.
- Auswertung: Übereinstimmung Hardware gegen Vorhersage (RMS, Basisdrehung virtuell), Vergleich mit Emulation aus.
- Anleitung `hardware/campaign/ANLEITUNG_LABOR_TAG3.md` erst schreiben, wenn der Termin steht.

---

## X4 Belastbarkeit und Aufräumen

### X4.1 Gewichtsreihe auf 10 Seeds

D17 hat Gewicht 0, 4, 8, 16 mit drei Seeds und Gewicht 2 mit acht. Für den Vergleich mit X1 auf 10 Seeds auffüllen.
Entscheidung E3 (10.11.): Gewichte 0, 2, 4, 8, 16, also 7 + 2 + 7 + 7 + 7 = 30 Läufe, etwa 13 h. Skripte
`ext_x4_1_run` (überspringt vorhandene Agenten, Protokoll `X4_1_runlog.csv`) und `ext_x4_1_eval`. Aufruf über
`desktop_d12_train(4, s, 3000, '', 'base_sync', 0.9774, w)` mit neuen Seeds. Gleicher Aufbau wie D17, deshalb mit
den D17-Agenten zusammen auswertbar.

### X4.2 Bestandsagenten neu auswerten

Alle Agenten, die im neuen Paper vorkommen könnten, mit X0.1: D14 (r0, r1, r2), D16 (r0, r2, r4 kurz und lang), D17,
D20 (Endagenten), frühes PPO, Optimized, CDR2-4, ppo_10hz. Danach stammen alle Simulationszahlen im Paper aus einem
Protokoll.

### X4.3 Ratenpaar auf 10 Seeds (optional, E6)

Nur falls der Ratenvergleich im neuen Paper eine quantitative Aussage behält. D10 hat drei Seeds je Rate.

### X4.4 Was im Paper bleibt

Vorschlag zur Entscheidung mit dem Betreuer (E7):
- Algorithmenvergleich (D11): auf einen Absatz mit Verweis auf das Access-Paper kürzen.
- Bayes-Suche: streichen (nicht reproduzierbar, kein Gewinn gegenüber den Standardwerten, Sec. IV-B).
- CDR: streichen oder in den Anhang, ersetzt durch X2.4.
- Versionsgeschichte V2.1 bis V2.3 und die sechs alten Set-Point-Läufe: auf einen Absatz kürzen oder Anhang.
- Schnittstellendiagnose: als kompakter Abschnitt „Lessons for deployment“ mit dem Check (Fig. 13b) behalten.
- Set-Point-Teil: behalten, aber kürzer. Er stützt den Pipeline-Teil, nicht die Kernfrage.

---

## X5 3D-Bahn mit Redundanz

**Frage:** Findet RL bei redundanter Kinematik reaktionsarme Bewegungen, die der Nullraum-Regler explizit nutzt?
Mit allen 7 Gelenken bleibt bei 3D-Position und Basisdrehung um drei Achsen ein redundanter Freiheitsgrad.

### X5.1 Modell und Machbarkeit

- Neue Modellparameter: `p_active` (Maske der aktiven Gelenke, Sättigung heute 0 für J1, J3, J5, J7), `p_path_id`
  (Bahnwahl). Grenzen für alle sieben Gelenke wie beim Set-Point (0,98 rad/s J1–J4, 0,58 rad/s J5–J7).
- Bahn: Halbkreis r = 0,2 m, 8,5 s, Ebene um 30° aus der x–z-Ebene gekippt. Start nicht in der gestreckten,
  singulären Stellung, falls das Probleme macht.
- Machbarkeit mit R0 und Rβ aus X2 im kinematischen Simulator: Bahn erreichbar, Gelenkgrenzen eingehalten,
  Basisdrehung mit und ohne Nullraum. Danach erst trainieren.
- Mit Standardwerten der neuen Parameter liefert `SK_desktop` dieselben Returns wie vorher (Prüfung wie D16).
- Stand 10.11.2026: Machbarkeit im kinematischen Simulator erledigt (`ext_x5_1_feasibility`, RESULTS.md X5.1).
  Bahn `ext_ref_path` 'tilted', Gelenkgrenzen als Option `lim` in `ext_kinsim` und `ext_x2_controller`. Offen:
  `p_active`/`p_path_id` in `desktop_build_model` mit Bitgleichheitsprüfung. Erst nach der Nachtkette vom
  10./11.11., weil diese `SK_desktop` neu baut und prüft. E9 und E10 entschieden (−30°, Grenzen korrigiert).

### X5.2 Pilot und Go/No-Go

r4 und die beste X1-Variante, je zwei Seeds, 3000 Episoden, etwa 3 h. Go (E4), wenn mindestens einer von zwei Seeds
je Variante der Bahn folgt. Sonst 5000 Episoden testen oder X5 als Ausblick ins Paper.

### X5.3 Hauptlauf

Beste Variante mit 10 Seeds, Auswertung mit X0.1 (Startstörung auf allen sieben Gelenken), Vergleich mit der
Rβ-Front in 3D. Etwa 6–8 h.

---

## Phase P: Paper

Erst wenn X1, X2 und X4.1 fertig sind und E7 entschieden ist.
1. Gliederung neu (Vorschlag nach den Ergebnissen in `RESULTS.md`, Abschnitt „Gliederung“).
2. Zahlen aus `RESULTS.md` übertragen, jede in `Reviews/Submission_1/paper_numbers.md` (oder Submission 2) mit
   Quelle eintragen.
3. Skill `paper-style` laden, Prüfskript über die geänderten Zeilen und die ganze Datei.
4. `reviewer_comments.md`: AE.1, AE.2, R2.1, R2.5 neu bewerten.

## Offene Entscheidungen

- **E1** ✅ 10.11.2026: Protokoll wie in X0.1 vorgeschlagen, aber Startstörung ±2° statt ±1° (±1° trennte die
  Agenten kaum). Budget-Toleranz bleibt 0,005 rad. Umgesetzt in `ext_eval_agent` und `ext_stats`.
- **E2** Kostenform, Schrittweite und Blockgröße der Lagrange-Variante (nach dem Pilot X1.2).
- **E3** ✅ 10.11.2026: Gewichte 0, 2, 4, 8, 16 (mit 4). 30 Läufe.
- **E4** X5 Go/No-Go nach dem Pilot.
- **E5** Agenten für den Labortag X3.2.
- **E6** Ratenpaar auf 10 Seeds ja oder nein.
- **E8** ✅ 10.11.2026 (Befund A72): Beobachtungsgrenzen für neue Trainings (X1, X2.4, X4.1, X5) belassen (für X5 durch E9 ersetzt), damit
  alle Agenten vergleichbar bleiben. Im Paper als Eigenschaft des Aufbaus nennen.
- **E9** ✅ 10.11.2026: Für X5 die Beobachtungsgrenzen in der richtigen Reihenfolge setzen. Begründung (A72): Die reaktionsarmen 3D-Lösungen des Reglers liegen bei q7 in 43–63 %
  der Schritte außerhalb von ±1,22 rad, dazu q4, q5 (±1,4) und q6 (±1,22) zeitweise. Mit E8 wäre die Policy dort
  blind. X5 ist eine neue Aufgabe, der Vergleich läuft gegen den Regler, nicht gegen die ebenen Agenten. E8 gilt
  damit für X1, X2.4 und X4.1, nicht für X5.
- **E10** ✅ 10.11.2026: Kipprichtung der 3D-Bahn −30° (Nullraum senkt die Basisdrehung des Reglers von 124 auf 10 mrad bei
  2 mm), nicht +30° (nur von 14 auf 11 mrad). Dort hat die Frage aus X5 Gewicht.
- **E7** Mit dem Betreuer: neue Geschichte, Zielkonferenz, was nach X4.4 aus dem Paper fliegt, ob die
  Schnittstellendiagnose ein Abschnitt bleibt oder ein eigenes kurzes Paper wird.
