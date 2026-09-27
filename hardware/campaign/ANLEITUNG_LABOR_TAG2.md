# Laboranleitung Labortag 2 (ganzer Tag)

Zweiter Labortag nach der Kampagne vom 26.09.2026. Gleicher Roboter und gleicher Greifer wie bei den Set-Point-
Läufen am 26.09. Die Bedingungen stehen in `campaign_plan.m` (`plan.day2`), die allgemeinen Regeln in
`ANLEITUNG_LABOR.md` (Vorbereitung, Verhalten bei Abbrüchen, Log-Dateien). Alle Befehle im MATLAB-Command-Window.

Ziele des Tages:

| Teil | Frage | Paper | Dauer |
|---|---|---|---|
| A | Wartet jeder blockierende API-Aufruf auf einen internen Takt von etwa 25 ms? | A60, Sec. VI-C | 15 min |
| B | Folgt ein Agent mit dem Basis-Bonus nur auf der Bahn (r4, Sec. V) auch auf dem festen Arm der ganzen Bahn? | Sec. V, VII | 45 min |
| C | Erreicht der Set-Point-Agent andere Ziele als das Trainingsziel? | A57, Sec. VI-D, ROS-Plugin | 2–3 h |

## 0. Vorbereitung

- [ ] Alle Punkte aus `ANLEITUNG_LABOR.md`, Abschnitt 0 (Netz, Energiesparplan, `git pull`, `git status` sauber,
  R2026a, `setup_project`, Kinova-Supportpaket, Not-Aus, zweite Person)
- [ ] Trockenlauf ohne Roboter:
  `deploy_setpoint_v24('S20_targets', 'S00', 0, 'targetId', 'T03', 'dryRun', true)`
- [ ] Startposen S00, S06 und S07 sind seit dem 26.09. freigegeben. Hat sich die Zelle verändert, erneut prüfen:
  `check_setpoint_starts('ids', {'S00', 'S06', 'S07'})`

## Teil A: Timing (Roboter steht, nur Null wird gesendet)

```matlab
p = campaign_plan();
for i = 1:size(p.day2.timing, 1)
    measure_loop_timing(p.day2.timing{i, 1}, p.day2.timing{i, 2});
end
```

Das sind neun Messungen: `M_fbonly` (nur `RefreshFeedback`), `M_sendfb` (erst Senden, dann Feedback) und zum
Vergleich `M_fb` (Wiederholungen 4 bis 6), jeweils dreimal.

Erwartung, wenn es einen internen Takt gibt: `M_fbonly` braucht auch allein etwa 25 ms pro Zyklus, `M_sendfb` etwa
so lange wie `M_fb` (≈ 50 ms). Braucht `M_fbonly` nur wenige Millisekunden, ist die Wartezeit an das Senden
gebunden.

## Teil B: Tracking mit den neu trainierten Agenten

**Neu gegenüber dem 26.09.:** Diese Agenten wurden mit einer J6-Grenze von 0,98 rad/s trainiert statt 0,1 rad/s.
Das Handgelenk J6 bewegt sich deshalb bis zu zehnmal schneller als in der Kampagne. Die Hardware-Kappe liegt für
diese Bedingungen bei 0,8 × Gelenkmaximum (J6: 0,977 rad/s, sonst 0,75). Soft-Limit-Bremsung, OOD-Stopp und Watchdog
bleiben unverändert. Beim ersten Lauf besonders auf J6 achten und bei Auffälligkeiten mit dem Not-Aus stoppen.

| Bedingung | Agent | Auswahl (vorab festgelegt) |
|---|---|---|
| `T40_r4_3k` | r4, 3000 Episoden | Seed 7 = mittlerer EE-MSE der acht Seeds in Simulation |
| `T40_r0_j6` | r0 (Trainings-Reward), 1000 Episoden, gleiche J6-Grenze | Seed 0 = Median der drei Seeds |
| `T40_r4_1k` | r4, 1000 Episoden | Seed 2 = Median der drei Seeds |

Reihenfolge: `T40_r4_3k` und `T40_r0_j6` abwechselnd (r = 1 bis 5), danach `T40_r4_1k` (r = 1 bis 5).

```matlab
p = campaign_plan();
for i = 1:size(p.day2.tracking, 1)
    deploy_tracking_v24(p.day2.tracking{i, 1}, p.day2.tracking{i, 2});
end
```

Jeder Aufruf fragt vor der Bewegung nach ENTER. Nach jedem Lauf Stoppgrund, RMS und Loop-Zeit ins Laborbuch
schreiben.

Vorhersage auf fester Basis (`desktop_day2_tracking_pred.m`, deterministisch, 20 Hz wie die API):

| Bedingung | RMS [m] | mittlerer Fehler letztes Viertel [m] |
|---|---|---|
| `T40_r4_3k` | 0,016 | 0,025 |
| `T40_r0_j6` | 0,088 | 0,159 |
| `T40_r4_1k` | 0,014 | 0,020 |
| zum Vergleich `T40_cdr_nom` (26.09. auf der Hardware 0,024–0,055) | 0,051 | 0,092 |

Die Basisdrehung, um die es beim Zielkonflikt geht, ist auf dem festen Arm nicht messbar. Sie wird hinterher in der
Simulation aus den gemessenen Gelenkbahnen nachgerechnet.

## Teil C: Set-Point zu neun festen Zielen

Die Ziele stehen in `setpoint_targets.mat` (`make_setpoint_targets.m`). Sie sind nach einer festen Regel gewählt,
nicht nach dem Ergebnis des Agenten. Alle Koordinaten im Kortex-Frame, Flanschpunkt ohne Greifer.

| Ziel | Gruppe | Lage relativ zum Trainingsziel [0,479 −0,005 0,636] m | Vorhersage (kinematisch) |
|---|---|---|---|
| T01 | Plugin | 0,15 m nach links (+y) | 3/3 unter 50 mm (21–31 mm, Timeout) |
| T02 | Plugin | 0,15 m nach rechts (−y) | 3/3 unter 50 mm |
| T03 | Plugin | 0,15 m tiefer | 3/3 unter 50 mm |
| T04 | Plugin | 0,25 m weiter vorn (+x) | 0/3 (≈ 130 mm) |
| T05 | Plugin | 0,25 m näher am Sockel (−x) | 3/3 unter 50 mm |
| T06 | Plugin | 0,25 m höher | 0/3 (≈ 109 mm) |
| E01 | Rand | 0,40 m nach links | 0/3 (≈ 68 mm) |
| E02 | Rand | 0,40 m nach rechts | 0/3 (≈ 108 mm) |
| E03 | Rand | 0,40 m schräg vorn-unten | 0/3 (≈ 103 mm) |

Die Vorhersage stammt aus dem kinematischen Trockenlauf aller 27 Kombinationen (`day2_dryrun_prediction.csv`).
Ziele, die dort verfehlt werden, bleiben trotzdem in der Reihe. Sie zeigen, wo der Agent aufhört zu funktionieren.

**C1. Zielposen freigeben (einmal):**

```matlab
check_setpoint_starts('list', 'targets')
```

Das fährt für jedes Ziel eine Prüfpose an, in der der Flansch am Ziel steht. Pose frei → `j`, sonst `n` mit Grund.
Gesperrte Ziele entfallen und werden nicht ersetzt. Der Agent wählt seine Endkonfiguration selbst. Die Prüfpose
zeigt nur, dass der Bereich um das Ziel frei ist. Deshalb bei den Läufen weiter den Not-Aus in der Hand halten.

**C2. Wiederholung 1 (Pflicht):** 9 Ziele × 3 Starts (S00, S06, S07) = 27 Läufe, je höchstens 25 s.

```matlab
p = campaign_plan();
o = p.day2.setpoint;
for i = find([o{:, 4}] == 1)
    deploy_setpoint_v24(o{i, 1}, o{i, 3}, o{i, 4}, 'targetId', o{i, 2});
end
```

**C3. Wiederholung 2 (wenn Zeit bleibt):** gleiche Schleife mit `[o{:, 4}] == 2`. Die Startreihenfolge je Ziel ist
umgekehrt.

Ein Einzellauf geht auch direkt, zum Beispiel `deploy_setpoint_v24('S20_targets', 'S06', 1, 'targetId', 'T04')`.
Ein Timeout ist ein gültiges Ergebnis. Der Endfehler steht trotzdem im Log.

## Nach der Messung

- [ ] `python evaluation/campaign/analyze_campaign.py`. Neu ist `table_setpoint_targets.csv` mit dem Erfolg je Ziel
- [ ] Laborbuch-Notizen sichern
- [ ] Logs, `campaign_index.csv`, `setpoint_start_check.csv`, `setpoint_target_check.csv` und die Ergebnisse
  committen und pushen
