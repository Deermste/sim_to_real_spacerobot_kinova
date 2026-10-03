# Laborbuch Labortag 2, 03.10.2026

Ablauf nach `hardware/campaign/ANLEITUNG_LABOR_TAG2.md`, Bedingungen in `campaign_plan.m` (`plan.day2`).

## Umgebung

- Laptop mit Pop!_OS 24.04, MATLAB R2026a Update 4, Kortex über `matlab_simplified_api_2.2.1`
  (`kortexApiMexInterface.mexa64`), Roboter 192.168.0.10. Wie Teil B am 26.09.
- Laut Anleitung derselbe Roboter und Greifer wie bei den Set-Point-Läufen am 26.09. (Roboter 2). Die
  `tool_pose`-Abweichung zur FK in C1 (2,4–6,8 mm) passt dazu.
- Code-Stand: Teil A, B und B+ auf `96f4f4b`, ab B++ auf `123b595` (neue Bedingung `T40_r4_3k_s1`). In allen
  Logs `gitDirty = 0`.
- Auf dem Laptop fehlt das Aerospace Blockset. `SK_desktop` läuft hier nicht (Block `Quaternion Normalize`), die
  Vorhersage auf fester Basis für B++ wird deshalb auf dem Desktop-Rechner nachgerechnet.

## Ablauf

- **0. Vorbereitung:** Trockenlauf `S20_targets T03 S00` wie vorhergesagt (converged, 12,2 mm, 2,3 s). Startposen
  nicht erneut geprüft.
- **A. Timing** (13:35–13:39), 9 Messungen, je 300 Zyklen: `M_fbonly` 25,0 ms (40 Hz), `M_sendfb` 50,0 ms
  (Senden 23,8 ms, Feedback 26,2 ms), `M_fb` r4–r6 50,0 ms. Jeder blockierende Aufruf wartet auf einen Takt von
  etwa 25 ms, auch `RefreshFeedback` allein (A60).
- **B. Tracking** (13:42–13:48), 15 Läufe, alle completed, Loop 50 ms (20 Hz). RMS-Median `T40_r4_3k` 0,0179 m,
  `T40_r0_j6` 0,0917 m, `T40_r4_1k` 0,0141 m. Vorhersage 0,0164 / 0,0875 / 0,0135 m. `T40_r4_3k` r01 lag mit
  0,023 m über den anderen vier (Abweichung am Anfang der Bahn). J6 unauffällig.
  Die Reachability-Warnung im Preflight erscheint zufällig (IK mit zufälligen Neustarts) und betrifft nur die
  Referenzbahn, nicht den Lauf.
- **B+. `T40_r4_3k_s4`** (13:50–13:52), 5 Läufe, RMS-Median 0,0169 m (Vorhersage 0,0135 m).
- **B++. `T40_r4_3k_s1`** (13:59–14:01), neu am 03.10., ruhiger r4-Agent aus D17. 5 Läufe, RMS-Median 0,0295 m,
  etwa 1,7-mal so viel wie s7 und s4. Erwartung vor dem Lauf: deutlich über 0,017–0,018 m.
- **C1. Zielposen** (14:02–14:04): alle 9 Ziele freigegeben, `tool_pose`-Abweichung zur FK 2,4–6,8 mm. Bei E02
  wurde die erste Eingabe leer abgeschickt, die zweite war `j`.
- **C2 / C3. `S20_targets`** (14:05–14:26 und 14:39–14:53), je 27 Läufe. Je 12/27 unter 50 mm: T01, T02, T03, T05
  von allen drei Starts, T04, T06 und E01–E03 von keinem. Alle Läufe wie im kinematischen Trockenlauf (Endfehler
  ±2 mm). Einziger Unterschied zwischen C2 und C3: T01 S06 (r01 timeout 31 mm, r02 converged 19,6 mm, Grenzfall
  an der 20-mm-Schwelle).
- **C+. `S21_targets_all`** (15:14–16:08), 90 Läufe. T01, T02, T03, T05 je 15/15 unter 50 mm, T04 und T06 je
  0/15, wie vorhergesagt. Unterbrochen nach Lauf 55 (siehe unten).

## Störungen

### MATLAB-Absturz im Kortex-MEX, C+ nach Lauf 55 (15:39)

- MATLAB hat sich um 15:39:53 ohne Fehlermeldung im Command Window beendet.
- Crash-Dump `~/matlab_crash_dump.5822-1`: `abort()` aus der C-Bibliothek im Kortex-MEX
  `kortexApiMexInterface.mexa64` (`mexFunction`). Das spricht für einen Speicherfehler im Treiber, nicht für einen
  Fehler im Skript.
- Zeitpunkt: 1 s nach dem Speichern von Lauf 55 (`S21_targets_all_T05_S04_r01_20261003_153952.mat`, converged),
  also beim Schließen der Session oder beim Verbinden für Lauf 56. Der Arm stand, das Skript hatte vorher Null
  gesendet.
- Lauf 55 ist vollständig (Log und Index-Zeile). Kein Lauf ging verloren, kein Lauf wurde doppelt gefahren.
- Weiter nach MATLAB-Neustart und `setup_project` mit `for i = 56:size(o, 1)`, erster Lauf 15:44:56 (T05 S03).
  Danach kein weiterer Absturz.
- Der Absturz vom 26.09. (`matlab_crash_dump.4090-1`, 17:07) war ein Segmentation Fault ohne Kortex-MEX im Stack,
  also eine andere Ursache.

### Watchdog-Stopp bei `S21_targets_all T06 S13` (15:58)

- Der Lauf endete nach 240 Schritten (24,03 s) mit `watchdog` statt nach 25 s mit `timeout`.
- Im letzten Schritt dauerte das Warten auf den Takt (`waitfor` von `rateControl`) 196 ms statt der üblichen
  69 ms. Damit lagen 197 ms seit dem letzten Senden, die Grenze ist 150 ms. Senden (12–25 ms), Feedback
  (6–11 ms) und Agent (4–5 ms) waren normal. Die Verzögerung kam also nicht von der Kortex-API. Vermutlich hat
  der Laptop oder MATLAB kurz gehangen, das ist nicht geprüft.
- Kein Einfluss auf das Ergebnis: Endfehler 107,7 mm (Vorhersage 107,1 mm), T06 wird von keinem Start erreicht.
  Der Lauf zählt als gültig.

## Weitere Befunde

- **T01 S11 (C+):** Der Arm kam wie vorhergesagt bis auf 11 mm an das Ziel heran, erfüllte das
  Konvergenzkriterium (unter 3 cm/s für 0,5 s) aber nicht durchgehend und lief auf 27 mm zurück (timeout). In
  der Vorhersage konvergierte er. Zwei weitere Kippfälle an der 20-mm-Schwelle: T01 S02 (HW converged, Vorhersage
  timeout) und T03 S06 (umgekehrt).
- **Stopp nach dem Minimum (Beobachtung im Labor):** In den nicht konvergierten Läufen erreicht der Arm ein
  Minimum und entfernt sich danach wieder. Im Trockenlauf untersucht (D18, `DESKTOP_PLAN.md`): Ein Neustart nach
  dem Minimum führt zum selben Endpunkt, ein Stopp senkt den Endfehler bei T04, T06 und den Randzielen, macht
  aus keinem Fehlschlag einen Erfolg.
