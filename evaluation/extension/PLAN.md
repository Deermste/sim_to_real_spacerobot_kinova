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
| X1.1 | Lagrange-PPO umsetzen (Kostensignal, duale Aktualisierung, Logging) | 2 Tage | 1 h | – | ✅ 10.11. (SK_desktop enthält Modus 5, X1.2 und X1.3 liefen darauf) |
| X1.2 | Pilot: Kostenform und Schrittweite | ½ Tag | ≈ 4 h | E2 | ✅ 11.11. |
| X1.2b | Zweiter Pilot: schnellere duale Anpassung (Blöcke 50, η 5 gegen PID-Lagrange), Kosten A, 2 Seeds | ½ Tag | ≈ 2 h | X1.2 | ✅ 11.11. |
| X1.3 | Hauptlauf: 5 Budgets × 10 Seeds, dazu r1 × 10 Seeds | 1 Tag | ≈ 25–30 h | E2 | ✅ 13.11. |
| X1.4 | Sicherheitsfilter (CBF auf die Basisdrehung) auf r1-Agenten | 2 Tage | 2 h | X0.2 | ✅ Teil 1 10.11., Teil 2 und 3 (Störungen, Simscape) 13.11. |
| X2.1 | Modellbasierter Regler (GJM, Nullraum), Machbarkeit auf dem Halbkreis | 2 Tage | < 1 h | X0.2 | ✅ 10.11. |
| X2.2 | Modellbasierte Pareto-Front, Vergleich mit RL | 1 Tag | < 1 h | X1.3, X4.1 | ✅ 13.11. |
| X2.3 | Robustheit gegen falsche Trägheitsparameter, RL gegen Regler | 2 Tage | 3 h | X2.1, X1.3 | 🔄 Teil 1 ✅ 10.11., X4.1 und X2.4 ✅ 11.11., X1.3 ✅ 13.11., Filter offen |
| X2.4 | RL mit Domain Randomization (DR-M und DR-voll), je 10 Seeds | 1 Tag | ≈ 10 h | – | ✅ 11.11., X0.1 in SK_desktop 13.11. |
| X3.1 | Kinematische Free-Floating-Emulation im Deploy-Skript, Validierung in Simulation | 3 Tage | 2 h | X0.2 | ✅ 10.11., Vorhersage 13.11. (Trockenläufe nach E5) |
| X3.2 | Labortag: Emulation an gegen aus | 1 Tag Labor + 1 Tag Auswertung | – | Labor, E5 | ⏸ Vorhersage und Vorschlag für E5 in RESULTS X3.2 |
| X4.1 | Gewichtsreihe aus D17 auf 10 Seeds auffüllen | ½ Tag | ≈ 13 h | E3 | ✅ 11.11. |
| X4.2 | Alle Bestandsagenten mit dem Protokoll X0.1 neu auswerten | ½ Tag | 2 h | X0.1 | ✅ 11.11. |
| X4.3 | Ratenpaar D10 auf 10 Seeds (optional) | ½ Tag | ≈ 3 h | E6 | ⏸ |
| X4.4 | Entscheidung, was aus dem Paper fliegt oder in den Anhang geht | ½ Tag | – | Betreuer | ⏸ |
| X4.5 | Sensitivität der eigenen Schwellen („folgt“, Budget-Toleranz, „ruhig“), ohne Training | ½ Tag | < 10 min | X4.1, X2.4 | ✅ Runde 1 11.11., Runde 2 13.11. |
| X4.6 | Ablation: Woher kommt der Abstand von RL zum Regler (Beobachtung, Kette)? 3 Varianten × 5 Seeds | 2 Tage | ≈ 7 h | E17 | ✅ 13.11. (K10, A75, V4 abends: Rate Limiter bremst nur den Regler) |
| X5.1 | 3D-Bahn mit allen 7 Gelenken: Modell, Machbarkeit mit dem Regler aus X2 | 2–3 Tage | 1 h | X2.1 | ✅ Machbarkeit 10.11., SK_desktop 14.11. (p_lim7, bitgleich, 3D gegen ext_kinsim 6e-8 m) |
| X5.2 | Pilot 3D: 2 Varianten × 2 Seeds, Go/No-Go | ½ Tag | ≈ 3 h | X5.1 | ✅ 14.11.: erster Lauf No-Go (Verlernen bei Lernrate 1e-3), X5.2b mit 3e-4 und Zwischenständen Go (3 von 4 folgen, bester 10,4 mm / 18,8 mrad). E4 bestätigen |
| X5.3 | Hauptlauf 3D: 10 Seeds, Vergleich mit Nullraum-Regler | 1 Tag | ≈ 6–8 h | E4 | ✅ 14.11. (8,1 h): r4 9 von 10 folgen (bester Zwischenstand, 11,8 mm / 17,8 mrad), Abstand zur Front Faktor 4,1, x1 (θ 0,03) dreht mehr als r4. RESULTS X5.3, K11, Abbildung `tradeoff3d` |
| X6.0 | Set-Point: Ausgangslage des alten Agenten, Zielwerte und Bezugspunkt festlegen | ½ Tag | – | E11 | ✅ 14.11. (Literatur: e.deorbit 4 mm Annäherung, Fanghülle ±20 mm, ±2–5°) |
| X6.1 | Schritt-Umgebung auf dem kinematischen Simulator (7 Gelenke, frei schwebend), Start- und Zielgenerator | 2 Tage | < 1 h | X0.2 | ✅ 13.11. (Paarsatz, Strecke, Umgebung, Trainingssatz 2000 Paare, Kollision je Schritt mit Kapsel-Vorfilter) |
| X6.2 | Vergleichsregler und Erreichbarkeit der Ziele | ½ Tag | < 1 h | X6.1 | ✅ 13.11. (R0 498/500 mit neuer Kette, 455 mit alter; Nullraum-Mittelzug offen) |
| X6.3 | Pilot: drei Varianten × 1 Seed | 1 Tag | ≈ 4–6 h | X6.1, E12–E14 | ⚠️ 14.11.: erster Lauf am Reward gescheitert. Nach der Korrektur lernt PPO im Plausibilitätstest die Annäherung auf wenige mm, aber kein Halten (0 % bei 5 mm). SAC mit und ohne HER (E14) hält auch nicht, nähert sich schlechter an. Entscheidung offen: X7 oder weiter PPO |
| X6.4 | Hauptlauf 5 Seeds, Auswertung auf 500 Paaren, Gegenprobe in Simscape | 1 Tag | ≈ 8–12 h | X6.3 | ⬜ |
| X6.5 | Deploy-Skript Set-Point v25 mit Emulation der Basis, Trockenläufe, Vorhersage | 2 Tage | 1 h | X3.1, X6.4 | ⬜ |
| X6.6 | Labortag Set-Point (Tracking X3.2 am selben Tag, wenn Zeit bleibt) | 1 Tag Labor + 1 Tag Auswertung | – | Labor | ⏸ |
| X7 | Residual RL: Policy korrigiert den Regler, Vorteil unter Modellfehlern? 4 Varianten × 10 Seeds | 2–3 Tage | ≈ 2–4 h | E19, X4.6 V4 | 🔄 15.11.: Nachtkette fertig. Bahn (X7.3): Kriterium X7.1 nicht erfüllt (Verschiebung entlang der Front), am selben Frontpunkt (C2) besser in 20/26 Szenarien, mit neuen Seeds 11–20 vorab festgelegt bestätigt (21/26, p 0,00015, K12). Set-Point: erste Runde schlechter als Rβ 1 in 26/26 (X7.5), zweite Runde ohne Kandidaten besser als Rβ 1 (X7.4). E19 entscheidet nur über das Paper |
| P | Paper neu aufbauen und Ergebnisse übertragen | 2–3 Wochen | – | alle | ⏸ |

Summe Rechenzeit ohne X5.3 etwa 55–65 h. Das sind etwa eine bis eineinhalb Wochen, wenn nachts und am Wochenende
trainiert wird. Die Arbeit liegt bei etwa vier bis sechs Wochen, das Paper danach bei zwei bis drei Wochen.

## Reihenfolge

1. **Woche 1:** X0.1, X0.2, X0.3. Nachts X4.1 (braucht nur die bestehenden Skripte).
2. **Woche 2:** X1.1 und X1.2, X2.1. Ab dem Wochenende X1.3.
3. **Woche 3:** X2.2, X2.3, X1.4, nachts X2.4. Parallel X3.1.
4. **Woche 4:** X5.1 und X5.2, dann Go/No-Go (E4). X4.2.
5. **Zwischenstand mit dem Betreuer:** Geschichte festlegen (E7), X4.4 entscheiden, Labortermin für X3.2.
6. **Danach:** X5.3 (✅ 14.11.), X3.2, dann Phase P.
7. **X4.5 und X4.6:** X4.5 erste Runde sofort (nur Daten), zweite nach X1.3. X4.6 in der Nacht nach X1.3, vorher
   Modus und Bitgleichheit prüfen.
8. **X6 (Set-Point):** X6.0 bis X6.2 in freien Stunden. Pilot und Hauptlauf in Nächten, in denen keine Kette aus
   X1 bis X5 läuft. Der Labortag X6.6 kann mit X3.2 zusammenfallen (E16).
9. **X7 (Residual RL):** erst nach dem Gespräch mit dem Betreuer (E19) und nach V4 aus X4.6. Die Umgebung braucht
   nur Bausteine, die schon stehen (Strecke `ext_x6_plant`, Regler, Störszenarien aus X2.3).

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

Stand 11.11.2026 (`RESULTS.md`, X1.2): Kosten A besser als B (4 von 4 folgen, 2 halten das Budget, B: 2 von 4
folgen, keiner hält es). λ schwingt nicht, ist aber zu langsam und steigt am Ende noch. Der Overhead der Blöcke ist
klein (etwa 0,8 min je 100 Episoden mit allem).

**Vorschlag X1.2b** (vor X1.3, etwa 2 h): Kosten A, θ = 0,03, zwei Seeds, 3000 Episoden, zwei Varianten der dualen
Aktualisierung:
- schneller integrierend: Blöcke zu 50 Episoden (60 Aktualisierungen statt 30), η 5, λ0 = 1.
- PID-Lagrange (Stooke et al. 2020) mit Proportionalanteil: λ = max(0, λ_I + Kp·(C − δ)), λ_I wie bisher mit η 2.
  Der P-Anteil reagiert sofort auf C, der I-Anteil hält das Budget auf Dauer. Kp etwa 20, damit C = δ + 0,05 schon
  λ ≈ 1 ergibt. Neue Option `kp` in `ext_x1_train`.
Auswahl wie in X1.2. Erfüllt keine Variante das Budget in den letzten 10 Blöcken, X1.3 mit 5000 Episoden planen.

Stand 11.11.2026 (`RESULTS.md`, X1.2b): „schnell“ hält das Budget mit beiden Seeds (20,0 und 20,8 mm, 21 und
25 mrad), PID mit einem (Seed 1 verliert die Bahn). Nach der Regel geht „schnell“ in X1.3 (E2).

### X1.3 Hauptlauf

- θ ∈ {0,02; 0,03; 0,04; 0,05; 0,06} rad × Seeds 0–9 × 3000 Episoden: 50 Läufe.
- Referenz: r1 ohne Nebenbedingung × Seeds 0–9 × 3000 Episoden: 10 Läufe. D14 hat r1 nur mit 1000 Episoden und
  drei Seeds.
- Rechenzeit etwa 60 × 25–30 min ≈ 25–30 h.
- Umsetzung 11.11.2026: `ext_x1_3_run()`, Einstellung „schnell“ aus X1.2b (Kosten A, δ 0,02, Blöcke zu 50,
  η 5, λ0 = 1). r1 als `ext_x1_train` mit η 0 und λ0 = 0, ebenfalls in Blöcken zu 50. Modus 5 mit λ = 0 ist der
  Reward von Modus 1, der einzige Unterschied ist also λ. Seeds außen, je Seed fünf Budgets und r1. θ = 0,03 mit
  Seed 0 und 1 sind die X1.2b-Agenten (gleiche Einstellung), θ = 0,03 wird zusätzlich ohne sie angegeben.
  Danach `ext_x1_2_eval` (Studie X1_3) mit D16 r4 als Bezug. Gestartet 11.11. 17:22, Ende etwa 12.11. abends.
- Stand 13.11.2026 (`RESULTS.md`, X1.3, K9): fertig 12.11. 19:54, Auswertung `ext_x1_3_report()`. Das Budget
  steuert die Basisdrehung, aber nur 27 von 50 Agenten folgen der Bahn. Bei θ 0,02 brechen drei Agenten jede
  Episode ab (A74). Mögliche Nachbesserung (nicht geplant): Abbruch mit den Kosten der restlichen Schritte
  belegen oder das Budget als Maximum statt als Anteil formulieren.
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
- Stand 11.11.2026: 20 Agenten trainiert, Robustheit auf den 26 Szenarien ausgewertet (`RESULTS.md`, K8). Offen:
  X0.1 in `SK_desktop` für die 20 DR-Agenten (etwa 5 min) und ein Test auf Ziehungen aus der DR-voll-Verteilung,
  dieselben 40 wie bei der Einstellung der Rt-Regler (kinematisch, wenige Minuten).

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

Stand 10.11.2026: `ext_x4_2_list` (93 Agenten, dazu D10, D11, D12, D13, CDR1-4 und basisori, weil das Paper sie
nutzt) und `ext_x4_2_run`. Läuft als Schritt 5 der Nachtkette (`ext_x2_4_night`) nach X1.2 auf 8 Workern, nicht
parallel zu X4.1 (Arbeitsspeicher). D17 kommt aus `ext_x4_1_eval`.

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

### X4.5 Sensitivität der eigenen Schwellen

Ergänzt am 11.11.2026 (Nutzer). **Frage:** Hängen die Kernaussagen an den Schwellen, die wir selbst gesetzt haben?

- Schwellen: „folgt“ (ep_q4 < 3 / 5 / 8 cm in jeder Episode), Budget-Toleranz (0 / 5 / 10 mrad über θ), „ruhig“
  (mittleres ori_max < 30 / 40 / 50 mrad). Dazu „folgt“ als RMS-Schwelle (< 3 / 5 cm) statt ep_q4.
- Nur vorhandene Daten, kein Training. Skript `ext_x4_5_thresholds`, liest die Episoden-Dateien und rechnet die
  Kennzahlen auf dem Gitter neu: `X_eval_X4_1_*` (K2), `X2_robust_20261111_112342_*` (K6, K8),
  `X1_4_eval_*` (Filter), später X4.2 und X1.3.
- Ergebnis: eine Tabelle je Kernaussage. Spalten sind die Schwellen, Einträge die Kennzahl, die die Aussage trägt
  (Anzahl ruhig je Gewicht, Fisher-p; nicht dominiert; Anzahl folgt; Budget-Anteile). Dazu je Aussage „hält“ oder
  „hält nicht“ auf dem ganzen Gitter.
- Erste Runde jetzt mit X4.1 und X2.4, zweite Runde nach X1.3. Das Gitter vor der Rechnung festlegen (wie oben)
  und nicht nachträglich ändern.
- Runde 2, festgelegt am 13.11.2026 vor der Rechnung. Gitter wie Runde 1 („folgt“ fünf Varianten, Toleranz 0 / 5 /
  10 mrad, wo sie eingeht). Daten `X_eval_X1_3_20261112_195325_*`, `X_eval_X4_1_20261110_233147_*`,
  `X_eval_X4_2_20261111_144608_*`. Aussagen und Kriterium „hält“:
  - K9a: Unter den folgenden Budget-Agenten Spearman θ gegen ori_max (Mittel über 21 Episoden) ρ ≥ 0,5 und p < 0,05.
  - K9b: Die Budget-Agenten folgen seltener als r4 w 2 (D16, Seeds 0–9). Fisher exakt p < 0,05.
  - K9c: Bei θ 0,02 und 0,03 halten Bahn und Budget mehr Budget-Agenten als in der Gewichtsreihe X4.1 (alle 50).
    Fisher exakt, Holm über die fünf Budgets, p_holm < 0,05 für beide.
  - K1: In D14 und D16 zusammen folgen die r0-Agenten seltener als die r1- und r2-Agenten. Fisher exakt p < 0,05.

### X4.6 Ablation: Woher kommt der Abstand zum Regler?

Ergänzt am 11.11.2026 (Nutzer). **Frage:** RL liegt beim Tracking etwa beim doppelten Bahnfehler des Reglers bei
gleicher Basisdrehung (K5, Faktor 2,0 bis 2,4). Liegt das an fehlender Information in der Beobachtung, an der
trägen Befehlskette oder am Lernverfahren selbst? Auf der Reglerseite ist das schon getrennt: 1,2 mm mit idealer
Kette, 5,7 mm mit der echten Kette (X2.1, A73). Auf der RL-Seite fehlt das Gegenstück.

**Varianten** (aufbauend, r4 mit Gewicht 2, J6 0,9774, 3000 Episoden, je 5 Seeds, sonst wie D16):
- **V0** Referenz: D16 r4 Seeds 0–9 (vorhanden).
- **V1** Beobachtungsgrenzen in der richtigen Reihenfolge (A72, wie E9). Heute übernimmt `desktop_d12_train` die
  `ObservationInfo` des alten Referenzagenten. Für V1 eigene Grenzen setzen.
- **V2** V1 und mehr Information: Ausgang der Befehlskette für J2, J4, J6 (der Filterzustand, den der Regler
  kennt) und eine Vorschau der Bahn (Sollpunkt relativ zum EE in 0,25 s und 0,5 s). 29 auf 38 Kanäle.
- **V3** V2 mit kürzerer Filterzeitkonstante. Heute 0,95y + 0,05u bei 40 Hz, das sind etwa 0,49 s. Vorschlag
  0,15 s (Koeffizient exp(−0,025 / 0,15) ≈ 0,85, E17).

**Umsetzung:**
- `desktop_build_model`: neuer Modus mit den zusätzlichen Kanälen und dem Filterkoeffizienten als Parameter
  (`p_filt_a`). Vorher prüfen, ob der Koeffizient unter Fast Restart wirkt (Lehre aus X2.4,
  `ext_x2_4_tunable`). Die alten Modi bleiben bitgleich (`ext_x0_check_model('compare')`).
- `ext_kinsim`: dieselben Kanäle und derselbe Koeffizient, damit Front und Faktor mit derselben Kette gerechnet
  werden. Für V3 die Regler-Front aus X2.1 mit dem kürzeren Filter neu rechnen (wenige Minuten). Sonst wäre der
  Vergleich unfair, weil auch der Regler von der schnelleren Kette profitiert.
- Training mit `desktop_d12_train` und einer Option für Modus und Grenzen. 15 Läufe zu etwa 25 min, eine Nacht.

**Auswertung:** X0.1 in `SK_desktop` und Faktor gegen die Front mit derselben Kette (wie X2.3). Statistik
`ext_stats`, jede Variante gegen die vorige (Holm über die drei Vergleiche). Kennzahlen: RMS, ori_max, Faktor,
Anteil folgt, Ruck.

**Erwartung** (vor dem Lauf festgehalten): V1 klein oder null, V2 deutlich (die Vorschau ersetzt die
Vorsteuerung des Reglers), V3 für RL und Regler ähnlich, der Faktor ändert sich also wenig.

**Grenzen:** Die Varianten bauen aufeinander auf. Der Anteil einer Änderung hängt deshalb von der Reihenfolge ab.
Ein vollständiger Faktorversuch (8 Zellen × 5 Seeds, etwa 17 h) nur, wenn die Ergebnisse das verlangen. V2 und
V3 verändern die Beobachtung bzw. die Sicherheitskette. Agenten daraus laufen nicht mit `deploy_tracking_v24/v25`
und sind für den Labortag nicht vorgesehen. Die Ablation ist eine Aussage über die Simulation.

**Paper:** Abschnitt Vergleich mit dem Regler (Erklärung von K5), eventuell Ausblick für das Interface-Design.

**Stand 13.11.2026** ✅: Erwartung nur teilweise bestätigt. V1 und V3 wie erwartet ohne messbaren Effekt, V2
ebenfalls ohne (Faktor-Median 2,45 auf 2,25, Holm p 1). Für den Regler kostet der Filter nichts, die Kette
kostet ihn am Rate Limiter (A75). Ein vollständiger Faktorversuch ist damit nicht nötig. Mögliche Fortsetzung:
V4 mit größerem Rate Limiter (für Regler und RL), nur wenn die Erklärung von K5 im Paper das braucht.
Nachtrag 13.11. abends: V4 gerechnet (RESULTS X4.6). Die Agenten bleiben bei etwa 13 mm, der Regler kommt auf
1,4 mm. Der Abstand liegt am Lernverfahren.
Ergebnisse in RESULTS.md X4.6.

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
- Stand 14.11.2026: erledigt mit `p_lim7` (Modell-Workspace) statt `p_active`, ohne `p_path_id` (Bahn über
  `EE_ref`). Bitgleich, 3D gegen `ext_kinsim` auf 6e-8 m (RESULTS X5.1 Nachtrag).

### X5.2 Pilot und Go/No-Go

r4 und die beste X1-Variante, je zwei Seeds, 3000 Episoden, etwa 3 h. Go (E4), wenn mindestens einer von zwei Seeds
je Variante der Bahn folgt. Sonst 5000 Episoden testen oder X5 als Ausblick ins Paper.

### X5.3 Hauptlauf

Beste Variante mit 10 Seeds, Auswertung mit X0.1 (Startstörung auf allen sieben Gelenken), Vergleich mit der
Rβ-Front in 3D. Etwa 6–8 h.

---

## X6 Set-Point neu: frei schwebend, ganzer Arbeitsraum, Millimeter

Ergänzt am 11.11.2026 auf Wunsch des Nutzers. Eigener Strang neben X1 bis X5, für ein späteres Paper oder einen
Abschnitt (E7). Das Tracking bleibt wie geplant. X6 startet, wenn der Rechner frei ist, und blockiert X1 bis X5
nicht.

**Frage:** Kann ein RL-Agent auf dem frei schwebenden Modell jedes erreichbare Ziel von einer beliebigen
Startstellung aus mit einer für reale Aufgaben brauchbaren Genauigkeit anfahren? Hält das auf dem festen Arm,
wenn das Deploy-Skript die Basis emuliert (X3)? Wie weit liegt er von einem modellbasierten Regler entfernt?

### Ausgangslage: der alte Agent `fixed1`

Quellen: Paper Sec. VI-D, Desktop-Plan D4, Laborbücher vom 26.09. und 03.10.2026, `reviewer_comments.md`
(A42, A43, A57, A61), `data/hardware/campaign/results/table_setpoint_targets.csv`.
- Trainiert mit fester Basis und Schwerkraft, die Basis-Kanäle der Beobachtung sind null. Er ist also kein
  Free-Floating-Agent, die Basis-Terme des Rewards wirken nicht.
- Ziele nur in einer Gelenkstreuung von 24° um ein Nominalziel. Hardware: Nominalziel 30 von 30 Läufen unter
  50 mm (4,9–22,7 mm, Median 14,8 mm). Von neun weiteren Zielen erreicht er vier von jedem Start (13–27 mm),
  T04, T06 und die drei Randziele nicht (68–130 mm).
- Erfolgskriterium im Training 2 cm und 3 cm/s. Ein Millimeter-Ziel gab es nie.
- Gelenkgrenzen: im Modell hart geklemmt ohne Anti-Windup, im Training J2 ±138° statt ±128,9° laut Datenblatt.
  J6 bleibt an der Trainingsgrenze hängen (A43), die Bremszone war in 14 von 30 Läufen aktiv (A61).
- Befehlskette mit 10 Hz und Filter 0,95y + 0,05u im Agententakt, also etwa 2 s Zeitkonstante. Der Zustand der
  Kette fehlt in der Beobachtung.
- Training sequenziell mit 16 Neukompilierungen, 3000 Episoden zu 25 s.
- Bezugspunkt: Trainiert auf den URDF-Punkt, die Kortex-Werkzeugpose liegt 0,121 m davor (A42). Seit v24
  regelt das Deploy-Skript auf die FK.

### X6.0 Zielwerte

Vorschlag (E11):
- Erfolg: EE-Fehler ≤ 5 mm und EE-Geschwindigkeit ≤ 5 mm/s, 1 s lang gehalten, innerhalb von 15 s. Ziel in
  Simulation: ≥ 95 % der erreichbaren Paare, Median-Endfehler ≤ 2 mm. Hardware: ≥ 90 % der freigegebenen Paare.
- Bezugspunkt ist die Greiferspitze (Werkzeugpunkt, 0,121 m vor dem URDF-Punkt), weil eine reale Aufgabe dort
  greift. Die Annahme, dass einige Millimeter für eine Annäherung vor dem Greifen reichen, in X6.0 mit Literatur
  zu Greifern und Fangmechanismen belegen, bevor sie ins Paper geht.
- Basisdrehung: im ersten Schritt gemessen und als leichter Term im Reward, kein hartes Budget. Ein Budget mit der
  Lagrange-Variante aus X1, falls E2 positiv ausfällt.
- Orientierung des Werkzeugs (≤ 3°) als Stufe 2, nur wenn Stufe 1 die Zielwerte erreicht.

### X6.1 Umgebung, Starts und Ziele

- **Umgebung** (E12): Training im kinematischen Simulator statt in Simscape. `ext_kinsim` wird als
  Schritt-Umgebung gebaut (`rlFunctionEnv` mit reset und step, 7 Gelenke, frei schwebend, Befehlskette aus
  derselben Datei wie im Deploy-Skript). X0.2 zeigt ≤ 0,45 mm gegen Simscape bei etwa zwölffacher
  Geschwindigkeit, X5.1 rechnet schon mit 7 Gelenken. Kein Neukompilieren, parallel auf 8 Workern. Die
  Schrittzeit wird gemessen, daraus folgt das Episodenbudget.
- **Starts:** q gleichverteilt in den Grenzen laut Datenblatt minus 5°. Verworfen werden Stellungen mit
  Selbstkollision oder Kollision mit dem Basiswürfel (Meshes der URDF, `checkCollision` der Robotics System
  Toolbox).
- **Ziele:** eine zweite Stellung q_T aus derselben Verteilung. Der Zielpunkt ist die Lage des Werkzeugpunkts nach
  einer Gelenkbahn von q0 nach q_T im kinematischen Simulator, im Inertialsystem. Die Zwischenstellungen werden
  auf Kollision geprüft. Damit ist jedes Ziel unter frei schwebender Kinematik auf mindestens einem
  kollisionsfreien Weg erreichbar.
- **Auswertesatz:** 500 feste Paare (fester Seed), geschichtet nach Abstand d0 (0,05–1,2 m) und Bereich (nah am
  Körper, Rand des Arbeitsraums, über und unter der Basis). Dazu die 15 Starts und neun Ziele der Labortage,
  ins Inertialsystem umgerechnet, für den Vergleich mit `fixed1`.
- **Trainingssatz** (13.11.): gleiches Verfahren mit Seed 1, 2000 Paare, ohne Laborpaare (`X6_train_*`). Der
  Auswertesatz wird im Training nicht benutzt.
- **Kollision im Training** (13.11.): Die Umgebung prüft jeden Agentenschritt und bricht bei Kollision mit
  r_fail ab. Kapseln als Vorfilter, die Mesh-Prüfung nur nahe an einer Kollision (`ext_x6_coll`). An zwei
  frischen Stichproben gleich der reinen Mesh-Prüfung bis auf einen verpassten Fall, der zur breiteren
  Würfelgrenze führte. Danach an einer dritten Stichprobe ohne Abweichung. Die Abbruchregel ist ein Vorschlag
  für den Pilot (Alternative: Strafe ohne Abbruch).

### X6.2 Vergleichsregler

Entschieden (E15): ja. `ext_x2_controller` mit 7 Gelenken und Aufgabe x, y, z (wie X5.1). Referenz: Gerade zum
Ziel mit Minimum-Jerk-Profil, Dauer aus d0 und den Geschwindigkeitsgrenzen. Gleiche Befehlskette mit Inversion,
Nullraum für den Abstand zu den Gelenkgrenzen und die Basisdrehung (β). Keine Kollisionsvermeidung. Paare, bei
denen die Gerade durch den Körper führt, werden markiert. Ergebnis je Paar: erreicht ja oder nein, Endfehler,
Einschwingzeit, Basisdrehung. Ein vom Regler erreichtes Paar gilt zusätzlich als belegt erreichbar.

### X6.3 Aufbau des Agenten und Pilot

Vorschläge, die der Pilot prüft:
1. **Takt 20 Hz** (E13). Die API begrenzt die Schleife ohnehin auf 20 Hz (Labortag 26.09.).
2. **Befehlskette:** neu entworfen, siehe „Neue Befehlskette für X6“ unten (E18). Ersetzt den früheren
   Vorschlag (Aufbau behalten, Filter 0,3 s).
3. **Beobachtung:** ep und ev im Basissystem und ein Feinkanal (ep auf ±5 cm begrenzt und mit 20 skaliert),
   damit Millimeter im Netz sichtbar sind. Endlosgelenke J1, J3, J5, J7 als sin und cos. Dazu dq, Basislage und
   -drehrate und der Abstand zu den Gelenkgrenzen. Grenzen in der richtigen Reihenfolge (A72, E9), Eingänge
   etwa auf ±1 normiert.
4. **Reward:** linearer Abstandsterm wie r_p2p, dazu ein Feinterm exp(−‖ep‖ / 5 mm) und ein Bremsterm nahe am
   Ziel. Strafe auf Befehlsänderungen, eine Barriere 10° vor den Gelenkgrenzen statt harter Klemmung (A43) und
   ein leichter Term auf die Basisdrehrate. Der Erfolgsbonus kommt erst nach 1 s Halten, danach endet die
   Episode.
5. **Gelenkgrenzen:** Datenblatt minus Rand. Dieselbe Bremslogik wie im Deploy-Skript läuft auch im Training
   (A61).
6. **Curriculum:** Der Abstand d0 wächst und die Toleranz schrumpft (5 cm bis 5 mm), sobald ein Block über 80 %
   Erfolg liegt. Ein Teil der Episoden kommt immer aus der vollen Verteilung.
7. **Randomisierung (gering):** Basismasse ×[0,5; 2], Verzögerung 0–1 Schritt, Rauschen realistisch (wie
   X2.4, K8).
8. **Verfahren** (E14): PPO wie bisher, Netz 2 × 256. SAC mit Hindsight Experience Replay
   (`rlHindsightReplayMemory`) nur als Rückfall, wenn PPO die Genauigkeit nicht erreicht.

Pilot: drei Varianten mit je einem Seed, Obergrenze 20 000 Episoden oder 2 h je Lauf. (a) alles wie oben, (b) ohne
Feinkanal und Feinterm, (c) wie (a), aber mit 10 Hz und 2 s Filterzeitkonstante wie `fixed1`. Gemessen auf 100
Paaren des Auswertesatzes. Die Varianten zeigen, welche Bausteine die Genauigkeit tragen. Sie gehören in die
Ablation des Papers.

### Neue Befehlskette für X6 (Entwurf 13.11.2026, E18)

**Warum neu:** Die bisherige Kette (Sättigung, Filter 0,95/0,05, Rate Limiter 0,5 rad/s², Cmd Scale) stammt aus
dem Originalmodell und ist nicht aus der Hardware hergeleitet. Befunde dazu:
- Filter und Rate Limiter glätten doppelt. Der Rate Limiter allein kostet den Regler 1,2 auf 5,7 mm (A75).
- Filter und Rate Limiter rechnen pro Agentenschritt. Die Zeitkonstante hängt damit von der Rate ab: etwa 0,5 s
  bei 40 Hz, 1 s bei 20 Hz, 2 s bei 10 Hz (`fixed1`). Wer die Rate ändert, ändert die Dynamik. Das gilt auch
  im Deploy-Skript (`filt_num`/`filt_den` fest, `pipelineTs` = Takt des Agenten).
- Die Policy gibt [−1, 1] aus, die Sättigung schneidet bei 0,9774 bzw. 0,5774 rad/s ab. Gesättigte Schritte
  geben PPO kein Lernsignal (Budget-Agenten 11 bis 74 %, X1.3). Dort weichen auch Simscape und der kinematische
  Simulator voneinander ab.
- Der Zustand der Kette fehlt in der Beobachtung. Die Winkelgrenzen sind im Modell hart geklemmt, im Deploy-Skript
  gibt es eine Bremszone, die im Training nie vorkam (A43, A61).

**Grundsätze:**
1. Eine Stufe Glättung, in Sekunden definiert, aus den Hardwaregrenzen abgeleitet. Ruhe kommt aus dem Reward
   (Strafe auf Befehlsänderungen), nicht aus einem nachgeschalteten Filter.
2. Die Aktion nutzt den ganzen Bereich. Keine harte Sättigung im normalen Betrieb.
3. Der Zustand der Kette ist Teil der Beobachtung (Markov).
4. Sicherheitslogik ist eine eigene Schicht. Sie läuft im Training und auf der Hardware gleich.
5. Eine Datei für Training, Regler und Deploy-Skript. Alles, was von der Rate abhängt, wird aus Ts berechnet.

**Aufbau** (je Agentenschritt, Ts = 0,05 s bei 20 Hz, alle 7 Gelenke):

| Stufe | Rechnung | Parameter |
|---|---|---|
| 1 Skalierung | v* = a ⊙ v_max, a ∈ [−1, 1] (tanh der Policy) | v_max = Trainingsgrenze je Gelenk, unter dem HW-Cap |
| 2 Beschleunigungsgrenze | v = v_prev + clip(v* − v_prev, ±a_max·Ts) | a_max in rad/s² aus der Hardware (siehe unten) |
| 3 Schutzschicht | Bremszone vor den Winkelgrenzen (linear über 10°), HW-Cap | wie Deploy v24, aber auch im Training |
| 4 Senden | v als Gelenkgeschwindigkeit an die API | Verzögerung 0 bis 1 Schritt (gemessen, A60) |

- Optional für den Pilot: ein Filter erster Ordnung zwischen 1 und 2 mit α = exp(−Ts/τ), τ = 0,1 s. Variante, nicht
  Standard.
- Beobachtung zusätzlich: v_prev / v_max (Ausgang der Kette im vorigen Schritt, 7 Kanäle) und ob die Schutzschicht
  eingreift (7 Kanäle 0/1).
- Winkelgrenzen in Simulation ohne harte Klemme: Die Bremszone hält das Gelenk vor der Grenze. Wird sie trotzdem
  erreicht, endet die Episode mit Strafe (wie auf der Hardware ein Fault).
- Reward: Strafe auf ‖a_k − a_{k−1}‖² (Ruck), damit ruhige Befehle gelernt und nicht erzwungen werden.

**Parameter aus der Hardware:**
- v_max: Datenblatt 1,3963 / 1,2218 rad/s, HW-Cap heute 0,75-fach (1,047 / 0,916 rad/s). Vorschlag v_max = HW-Cap
  minus 5 %, dann greift der Cap im Normalbetrieb nie.
- a_max: aus der Kortex-API auslesen (Grenzen für Gelenkbeschleunigung im Geschwindigkeitsmodus), sonst am
  Labortag messen (Sprung auf 0,3 rad/s, Antwort aus den Feedback-Daten). Vorschlag 50 % des Hardwarewerts. Bis
  der Wert feststeht, Platzhalter 2 rad/s² (viermal die heutigen 0,5).
- Servo: Das Modell nimmt heute 2 × 20 ms Gelenkfilter an. Am Labortag mit denselben Sprüngen prüfen und den Wert
  im kinematischen Simulator anpassen. Das schließt die Lücke von 2 bis 3 mm zwischen Vorhersage und Hardware
  (Labortag 2) vielleicht teilweise.

**Umsetzung:**
- `hardware/campaign/chain_step.m`: Zustand (v_prev, optional Filter) und Parameter als Struct, eine Funktion für
  den Schritt. Aufgerufen von der X6-Umgebung (`ext_kinsim`, neue Option `chain` 'x6'), vom Regler mit Inversion
  (X6.2, die Inversion ist bei einer reinen Beschleunigungsgrenze trivial) und von `deploy_setpoint_v25`.
- Die alte Kette bleibt unverändert für alle bisherigen Agenten und Ergebnisse. Die neue gilt nur für X6.

**Prüfung:**
1. Einheitentests: Sprungantwort bei 10, 20 und 40 Hz in Sekunden gleich (bis auf die Abtastung). Ausgang nie über
   v_max und a_max. Mit a ≡ 0 bleibt der Arm stehen.
2. Regler aus X6.2 mit alter und neuer Kette auf den 100 Pilot-Paaren: zeigt, was die Kette allein ausmacht.
3. Gegenprobe Simscape (`SK_point` mit der neuen Kette) gegen den kinematischen Simulator, ≤ 1 mm (wie X6.4).
4. Am Labortag: Sprungtests der Gelenke vor den Set-Point-Läufen (5 min).

**Was das für den Vergleich mit `fixed1` heißt:** Die Pilotvariante (c) (10 Hz, 2 s Filter wie `fixed1`) bleibt.
Damit ist sichtbar, wie viel die neue Kette allein bringt.

### X6.4 Hauptlauf

- Beste Variante mit 5 Seeds, je höchstens 3 h, eine Nacht. 5 Seeds reichen für eine Nebenaufgabe, die
  Statistik läuft mit `ext_stats`.
- Auswertung auf den 500 Paaren: Erfolgsrate, Endfehler (Median und 95-%-Quantil), Einschwingzeit, größte
  Basisdrehung, Anteil der Bremszone, jeweils nach d0 und Bereich. Dasselbe für den Regler aus X6.2.
- Robustheit mit einer Auswahl aus X2.3: Masse, Verzögerung, Rauschen, Startstellung.
- Gegenprobe in Simscape: `SK_point` (frei schwebend) mit der neuen Kette und Beobachtung, 50 Paare. Abweichung
  zum kinematischen Simulator ≤ 1 mm.
- Vorher-Nachher auf den alten 15 Starts und neun Zielen gegen `fixed1`.

### X6.5 Deploy-Skript und Vorhersage

- `deploy_setpoint_v25.m`: v24 und der Schalter `emulateBase` (`virtual_base_step` aus X3.1, ist bereits auf 7
  Gelenke ausgelegt). Neue Beobachtung, Befehlskette aus derselben Datei wie im Training, 20 Hz, neue
  Gelenkgrenzen und Bremslogik, Werkzeugpunkt als Bezug.
- Trockenlauf für jedes geplante Paar mit Emulation. Mit Emulation fährt der echte Arm eine andere Bahn als der
  virtuelle, deshalb jedes Paar zusätzlich physisch prüfen: Höhenwächter, Tisch und freier Raum. Vorhersage
  `X6_prediction.csv`.

### X6.6 Labortag

Reihenfolge nach Wunsch des Nutzers (E16): Set-Point zuerst. Bei wenig Zeit nur Set-Point.
- Bester Seed aus X6.4. Etwa 20 freigegebene Paare × 2 Durchgänge mit Emulation, 5 Paare ohne Emulation als
  Gegenprobe (der Agent sieht eine ruhende Basis), dazu die alten neun Ziele von drei Starts für den Vergleich
  mit `fixed1`. Etwa 70 Läufe zu höchstens 20 s.
- Danach Tracking wie X3.2, wenn Zeit bleibt.
- Grenze bleibt: Der Arm ist fest montiert, die Basis ist emuliert und nicht gemessen (AE.2, R3.1).
- Anleitung `hardware/campaign/ANLEITUNG_LABOR_TAG3.md` erst schreiben, wenn der Termin steht.

**Aufwand:** Arbeit etwa acht bis neun Tage plus Labortag, Rechenzeit etwa ein bis zwei Nächte.

---

## X7 Residual RL: Wo hilft RL dem Regler?

Ergänzt am 13.11.2026 (Vorschlag, vom Nutzer in den Plan aufgenommen, E19 offen).

**Warum:** Der modellbasierte Regler liegt in allen bisherigen Vergleichen vorn (K5, K6, K8, K10). Ohne
konstruktiven Teil bleibt das Paper ein Negativbefund („warum dann RL?“). Residual RL ist die naheliegende
Antwort: Der Regler liefert den Grundbefehl, die Policy lernt nur eine begrenzte Korrektur. Wo das Modell stimmt,
sollte die Korrektur klein bleiben. Wo es nicht stimmt (Basismasse, Trägheit, Montage, Drift), kann sie
ausgleichen, was der Regler mit dem Nominalmodell falsch macht. Das Verfahren ist bekannt (Residual Policy
Learning). Neu wäre der Einsatz für die Basisdrehung frei schwebender Manipulatoren mit fairem Vergleich. Vor dem
Paper die Literatur prüfen wie in X0.3.

**Frage:** Ist Regler plus gelernte Korrektur unter Modellfehlern besser als der Regler allein, ohne nominal
schlechter zu werden? Und ist er besser als reines RL?

**Aufbau:**
- Aufgabe wie bisher: Halbkreis 8,5 s, J2, J4, J6, 40 Hz, J6 0,9774 rad/s, alte Befehlskette (damit der Vergleich
  zu X2 und X4.6 gilt). Rate Limiter je nach Ergebnis von V4 (X4.6) 0,5 oder 2 rad/s².
- Grundregler: ein Punkt der Front aus X2.1 mit Nominalmodell, Inversion der Kette, Vorschlag Rβ 21,5 (J6-Seite −,
  Kp 5). Er gibt die Gelenkgeschwindigkeit x_c.
- Policy: Aktion Δ ∈ [−1, 1]³, Befehl x = x_c + ε·Δ mit ε = 0,2 rad/s (Variante 0,05). Danach dieselbe Kette.
  Geändert am 15.11.2026 (RESULTS X7.0): Die Korrektur auf die Gelenkgeschwindigkeit lässt den redundanten Arm im
  Nullraum driften (0,02 rad/s auf J2 ergibt 306 mm). Stattdessen korrigiert Δ die Sollwerte des Reglers:
  Sollgeschwindigkeit des EE ± 0,02 m/s (x, z) und Soll-Drehrate der Basis ± 0,01 rad/s. Reward r4 ohne
  Befehlsterme, dazu −0,1 |Δ|². Rate Limiter 0,5 rad/s² (Hardware).
  Beobachtung wie X4.6 V1 (29 Kanäle, richtige Grenzen) und dazu x_c (3 Kanäle).
- Reward r4 mit Gewicht 2 (wie D16) und eine Strafe auf |Δ|², damit die Korrektur ohne Grund null bleibt.
- Training im kinematischen Simulator (rlFunctionEnv auf `ext_x6_plant` mit der alten Kette, gegen `ext_kinsim`
  bitgleich zu prüfen wie in X6.1). Kein Simscape nötig, X0.2 zeigt ≤ 0,45 mm. Gegenprobe einzelner Agenten in
  Simscape über einen Reglerblock wie `SK_x14`.

**Varianten** (je 10 Seeds, 3000 Episoden):

| Variante | Inhalt | Zweck |
|---|---|---|
| R | Regler allein, Nominalmodell | Bezug (kein Training) |
| RL | reines RL wie X4.6 V1 (oder V4) | Bezug aus X4.6, schon vorhanden |
| Res | Residual, nominal trainiert | lernt die Korrektur den Regler nominal zu verbessern? |
| Res-DR | Residual, trainiert mit der DR-voll-Verteilung aus X2.4 | gleicht die Korrektur Modellfehler aus? |

**Auswertung:**
- X0.1 nominal und die 26 Szenarien aus X2.3 (`ext_x2_robust` mit Residual-Teilnehmern).
- Kennzahlen: RMS und Basisdrehung je Szenario, Faktor gegen die Front, Anteil folgt.
- Gepaarter Vergleich je Szenario gegen R (gleicher Grundregler): Zuwachs von RMS und Basisdrehung gegen nominal,
  wie Δ Masse in X2.4.
- Mann-Whitney über die Seeds, Holm über die Vergleiche Res gegen R, Res-DR gegen R, Res-DR gegen RL.

**Erwartung (vor dem Lauf festhalten):**
- Res nominal höchstens 10 % schlechter als R, eher gleich.
- Res-DR in den Modellszenarien (Masse, Trägheit, Montage) mit kleinerem Zuwachs als R.
- Res und Res-DR in allen Szenarien besser als RL.
- Fällt Res-DR unter Modellfehlern nicht besser aus als R, ist das ebenfalls ein Ergebnis: Dann hilft RL hier
  auch als Korrektur nicht.

**Aufwand:** Umgebung und Prüfung etwa ein Tag. Training im kinematischen Simulator etwa 5 bis 15 min je Lauf auf
8 Workern, 20 Läufe also 2 bis 4 h. Auswertung mit vorhandenen Skripten etwa ein halber Tag.

**Grenzen:**
- Die Korrektur braucht den Regler und damit das Modell zur Laufzeit, wie der Sicherheitsfilter in X1.4.
- ε begrenzt, was die Policy ändern kann. Zu klein heißt kein Effekt, zu groß heißt wieder reines RL.
- Auf der Hardware nur mit Emulation sinnvoll (X3), sonst sieht der Grundregler eine ruhende Basis.

**Paper:** konstruktiver Teil nach dem Vergleich mit dem Regler („wo RL hilft und wo nicht“). Nur wenn E19 das so
entscheidet.

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
- **E2** ✅ Kostenform, Schrittweite und Blockgröße der Lagrange-Variante. 11.11.2026 (Nutzer übernimmt den
  Vorschlag): Kosten A (Indikator). Schrittweite und Blockgröße nach dem Pilot X1.2b (schneller integrierend
  gegen PID-Lagrange), weil λ in X1.2 mit keiner Einstellung einschwang. Die bessere der beiden Varianten geht in
  X1.3. Hält keine das Budget, X1.3 mit 5000 Episoden. 11.11.2026 nach X1.2b: „schnell“ (Blöcke zu 50, η 5,
  λ0 = 1, 3000 Episoden), zwei von zwei Seeds mit Budget, PID einer von zwei. λ bleibt vom Anfang her hoch, die
  Agenten sind vorsichtiger als nötig (RESULTS, X1.2b).
- **E3** ✅ 10.11.2026: Gewichte 0, 2, 4, 8, 16 (mit 4). 30 Läufe.
- **E4** ✅ 14.11.2026 (Nutzer bestätigt): X5 Go nach X5.2b (3 von 4 folgen), Hauptlauf X5.3 erledigt.
- **E5** Agenten für den Labortag X3.2.
- **E6** Ratenpaar auf 10 Seeds ja oder nein.
- **E8** ✅ 10.11.2026 (Befund A72): Beobachtungsgrenzen für neue Trainings (X1, X2.4, X4.1) belassen, damit
  alle Agenten vergleichbar bleiben. Im Paper als Eigenschaft des Aufbaus nennen. Für X5 durch E9 ersetzt.
- **E9** ✅ 10.11.2026: Für X5 die Beobachtungsgrenzen in der richtigen Reihenfolge setzen. Begründung (A72):
  Die reaktionsarmen 3D-Lösungen des Reglers liegen bei q7 in 43–63 % der Schritte außerhalb von ±1,22 rad,
  dazu q4, q5 (±1,4) und q6 (±1,22) zeitweise. Mit E8 wäre die Policy dort blind. X5 ist eine neue Aufgabe,
  der Vergleich läuft gegen den Regler, nicht gegen die ebenen Agenten.
- **E10** ✅ 10.11.2026: Kipprichtung der 3D-Bahn −30°. Dort senkt der Nullraum die Basisdrehung des Reglers
  von 124 auf 10 mrad bei 2 mm, bei +30° nur von 14 auf 11 mrad. Bei −30° hat die Frage aus X5 Gewicht.
- **E7** Mit dem Betreuer: neue Geschichte, Zielkonferenz, was nach X4.4 aus dem Paper fliegt, ob die
  Schnittstellendiagnose ein Abschnitt bleibt oder ein eigenes kurzes Paper wird. Neu: ob X6 (Set-Point) in
  dieses Paper kommt oder in ein eigenes.
- **E11** ✅ 11.11.2026 (Vorschlag übernommen): Zielwerte für X6 5 mm und 5 mm/s, 1 s gehalten, innerhalb von
  15 s, ≥ 95 % in Simulation, ≥ 90 % auf der Hardware, Bezug Greiferspitze. Orientierung erst in Stufe 2.
- **E12** ✅ 11.11.2026 (Vorschlag übernommen): X6 im kinematischen Simulator trainieren, Gegenprobe in Simscape.
- **E13** ✅ 11.11.2026 (Vorschlag übernommen): Takt für X6 20 Hz, passend zur API.
- **E14** ✅ 11.11.2026 (Vorschlag übernommen): Verfahren für X6 PPO. SAC mit Hindsight Experience Replay nur als
  Rückfall.
- **E15** ✅ 11.11.2026 (vom Nutzer freigegeben): X6 bekommt einen Vergleichsregler. Gründe: Die Reviews
  vermissten eine Vergleichsbasis, beim Tracking ist der Abstand groß (K5), ohne Regler wäre die Set-Point-Aussage
  so angreifbar wie bisher. Der Regler belegt zugleich, welche Ziele erreichbar sind. Der Aufwand ist klein, weil
  `ext_x2_controller` schon 7 Gelenke und 3D kann (X5.1).
- **E16** ✅ 11.11.2026 (Nutzer): Auf dem nächsten Labortag Set-Point vor Tracking. Bei wenig Zeit nur Set-Point.
- **E17** ✅ 11.11.2026 (Vorschlag übernommen): Filterzeitkonstante für X4.6 V3 0,15 s (Koeffizient 0,85 bei
  40 Hz) statt 0,49 s.
- **E18** 13.11.2026 (Nutzer: Kette für X6 neu entwerfen): Entwurf in „Neue Befehlskette für X6“. Offen sind
  a_max (Hardwarewert oder Messung) und ob der optionale Filter (τ 0,1 s) in den Pilot kommt. Vorschlag: nur
  Beschleunigungsgrenze, Filter als Pilotvariante.
  Stand 13.11.2026: `chain_step.m` gebaut und getestet, Reglervergleich alt gegen neu auf 100 Paaren (RESULTS X6,
  E18). Für den Regler entscheidet a_max (99 gegen 90 bis 95 Erfolge bei 20 Hz), der Filter kaum. Damit ist der
  Wert von a_max die wichtigste offene Zahl. Winkelgrenzen in X6 nach Datenblatt statt Modellwerten. Bremskurve
  statt linearer Bremszone (Abweichung vom Entwurf, begründet in RESULTS).
  Stand 14.11.2026: Laut Gen3-Handbuch r9.1 (Tabelle 44) gilt für API-Geschwindigkeitsbefehle standardmäßig
  1,0 rad/s² für J1–J4 und 10,0 für J5–J7, änderbar bis zur harten Grenze 5,2 / 10. Der Regler erreicht damit
  497 von 500 Paaren (Platzhalter 498). Offen: Wert auf dem Laborarm auslesen, Kette für X6.4 auf 1 / 10 setzen.
- **E19** (mit dem Betreuer): X7 Residual RL in dieses Paper? Vorschlag: ja, als konstruktiver Teil nach dem
  Vergleich mit dem Regler. Es verschiebt die Geschichte von „Bewertung“ zu „Bewertung mit Ausweg“. Offen
  außerdem: Grundregler (Vorschlag Rβ 21,5), ε (0,2 rad/s) und der Rate Limiter (nach V4).
