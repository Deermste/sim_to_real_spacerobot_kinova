# Zwischenstand Ausbau des Papers (13.11.2026, ergänzt am Abend)

Unterlage für das Gespräch mit dem Betreuer. Paper „From Free-Floating Simulation to Fixed-Base Hardware“,
nach der Ablehnung bei iSpaRo 2026. Alle Zahlen mit Datenquelle stehen in `RESULTS.md`, der Plan in `PLAN.md`.
Alles hier ist Simulation, wenn nicht anders gesagt. Das Paper selbst ist noch nicht geändert (Phase P).

## 1 Ausgangslage

Die Reviews bemängelten vor allem drei Dinge. Der Beitrag wirke wie ein Fehlerfund. Es fehle eine Vergleichsbasis.
Die feste Basis auf der Hardware schwäche die Sim-to-Real-Aussage. Der Ausbau seit 10.11. setzt dort an:
- Kernfrage: RL landet je nach Seed auf verschiedenen Punkten des Zielkonflikts zwischen Bahngenauigkeit und
  Basisdrehung. Lässt sich der Punkt wählen? Wie weit liegt RL von einem modellbasierten Regler entfernt?
- Vergleichsbasis: Regler mit verallgemeinerter Jacobi-Matrix, der dieselbe Befehlskette fährt wie die Agenten.
- Statistik wie im Access-Paper: 10 Seeds je Variante, 21 Episoden je Agent (nominal und 20 Startstörungen),
  Holm-Korrektur, Sensitivität der eigenen Schwellen.
- Prüfmethode für die Hardware: Emulation der frei schwebenden Basis im Deploy-Skript des festen Arms.

## 2 Ergebnisse in Kürze

**Gewicht steuert die Basis nicht (K2).** Ein Reward-Gewicht von 0 bis 16 auf dem Basis-Term ändert die
Basisdrehung nicht (Median 50 bis 54 mrad, 10 Seeds je Gewicht, alle Holm p ≥ 0,74). Der Seed entscheidet. Ein
größeres Gewicht erhöht nur den Befehlsruck.

**Ein Budget steuert die Basis, kostet aber Bahn (K9).** Lagrange-PPO mit Budget θ von 0,02 bis 0,06 rad, je 10
Seeds. Die Basisdrehung folgt dem Budget (Spearman 0,70, bei den folgenden Agenten 0,77). Nur 27 von 50 Agenten
folgen der Bahn. Ohne Budget sind es 10 von 10 (bisheriger Reward r4) bzw. 7 von 10 (Reward ohne Basis-Terme).
Bei θ = 0,02 brechen 3 von 10 Agenten jede Episode ab (A74). Für ein strenges Budget (θ ≤ 0,03) muss die Policy
einen bestimmten Zweig von J6 finden, den auch der Regler nutzt. Ohne ihn folgt kein Agent (0 von 7), mit ihm 8
von 13.

**Der Regler liegt vorn (K5, K6, K8).** Bei gleicher Befehlskette erreicht der Regler 0,020 rad bei 5,7 mm. Die
Agenten brauchen bei gleicher Basisdrehung etwa den 2- bis 2,7-fachen Bahnfehler. Kein Budget und kein Gewicht
ändert diesen Faktor. Auch mit Nominalmodell bleibt der Regler in 26 Störszenarien vorn (Masse, Trägheit,
Verzögerung, Rauschen, Startstellung, Drift). Domain Randomization macht die Agenten robuster gegen falsche
Basismasse, aber nicht besser als den Regler. Das bestätigt sich auch in Simscape nach dem vollen Protokoll.

**Filter statt Training (X1.4).** Ein modellbasierter Sicherheitsfilter auf Agenten ohne Budget-Training hält
das Budget etwa so oft wie das Training (nominal 32 gegen 28 von 50, unter Störungen 73 bis 91 % gegen 74 bis
90 %). Die beiden
scheitern aber verschieden. Der Filter hält das Maximum fast immer (höchstens 4 mrad darüber, 9,5 mrad bei einem
Lagefehler der Messung), der Agent verliert dafür die Bahn. Das Training hält die Bahn und überschreitet das
Budget bei Modellfehlern deutlich (bis 65 mrad). Trainierte Agenten sind genauer, wenn sie folgen (15 bis 21 mm
gegen 18 bis 23 mm). In Simscape rechnet der Filter wie im kinematischen Simulator (≤ 0,2 mm).

**Woher der Abstand kommt (K10, A75, neu vom 13.11.).** Ablation mit 3 Varianten zu je 5 Seeds. Richtige
Beobachtungsgrenzen, neun Kanäle mehr (Zustand der Befehlskette, Vorschau der Bahn) und ein schnellerer Filter
ändern den Faktor nicht messbar (Median 2,25 bis 2,69). Der schnellere Filter erhöht nur den Ruck etwa neunfach.
Beim Regler kostet der Filter nichts, er invertiert ihn. Die Kette kostet ihn nur am Rate Limiter (1,2 mm ideal,
5,7 mm mit Kette). Der Abstand liegt damit eher im Lernverfahren und in der Wahl des J6-Zweigs.

**Emulation auf dem festen Arm (X3.1).** Das Deploy-Skript v25 rechnet die Basis aus den gemessenen
Gelenkwinkeln mit und gibt der Policy die Beobachtung wie im frei schwebenden Training. In Simulation trifft das
die frei schwebende Rechnung auf ≤ 0,41 mm und ≤ 0,2 mrad, Rechenzeit 0,6 ms je Schritt. Der Arm fährt dabei
physisch nicht die Referenzbahn, sondern die Bahn relativ zur virtuellen Basis (14 bis 33 mm Abweichung). Das ist
gewollt und durch eine zweite Abbruchgrenze abgesichert. Hardware-Test steht aus. Eine Vorhersage je Kandidat
liegt vor. Mit Emulation sieht der Agent fast dasselbe wie frei schwebend. Ohne Emulation weicht er je nach Agent
um −10,5 bis +4 mm ab. Messbar ist der Unterschied nur bei Agenten mit mehr als etwa 4 mm, weil die Hardware am
Labortag 2 schon 2 bis 3 mm über der Vorhersage lag.

**Weitere Befunde.** Der alte Basis-Bonus im Reward erzeugt den späten Bahnverlust (K1, auch auf der Hardware
gesehen). Gelenkbahnen der Hardware ergeben dieselbe Basisdrehung wie die Simulation mit fester Basis (≤ 2 mrad,
K4). Auf einer gekippten 3D-Bahn mit allen sieben Gelenken senkt der Nullraum des Reglers die Basisdrehung je nach
Kipprichtung stark (124 auf 10 mrad bei 2 mm, K7). RL in 3D ist noch nicht trainiert.

## 3 Was daraus folgt

Die ehrliche Bilanz: In keinem getesteten Aufbau ist RL besser als der modellbasierte Regler, weder nominal noch
unter Störungen. Das Paper wird damit eher eine Bewertung als eine Methode. Vorschlag für die Geschichte:
1. Beim Zielkonflikt Bahn gegen Basisdrehung wählt der Seed den Punkt, nicht das Reward-Gewicht.
2. Eine Nebenbedingung macht den Punkt wählbar, mit einem Preis bei der Bahn.
3. Ein Regler mit Modell und Kenntnis der Befehlskette bleibt etwa um den Faktor 2 vorn. Der Abstand liegt nicht
   an fehlender Information in der Beobachtung.
4. Die Emulation der Basis erlaubt einen geschlossenen Free-Floating-Test der Policy auf dem festen Arm. Sie
   prüft Regelung, Timing und Sicherheitslogik, nicht die echte Dynamik einer schwebenden Basis.
5. Die Schnittstellendiagnose (Beobachtungsfehler, Abtastrate) aus der ersten Fassung wird kürzer.
6. Optional (E19): Residual RL als Ausweg. Der Regler gibt den Grundbefehl, die Policy lernt eine begrenzte
   Korrektur. Hilft sie unter Modellfehlern, ist das die positive Aussage, die der Geschichte bisher fehlt.

## 4 Entscheidungen

| # | Frage | Vorschlag |
|---|---|---|
| E7a | Trägt die Geschichte aus Abschnitt 3? | Ja, als Bewertungspaper mit Regler als Bezug |
| E7b | Zielkonferenz oder Journal, Seitenlimit | offen, bestimmt den Umfang von Phase P |
| E7c | Schnittstellendiagnose als Abschnitt behalten oder auslagern | kürzen, als Abschnitt behalten |
| E7d | Set-Point neu (X6, frei schwebend, Millimeter-Ziel) in dieses Paper oder in ein eigenes | eigenes Paper, sonst wird dieses zu breit |
| X4.4 | Was fliegt aus dem Paper oder geht in den Anhang | nach E7a, z. B. Ratenpaar D10 und Teile des Algorithmenvergleichs |
| E4 | 3D-Bahn mit RL (X5) machen | ja, kleiner Pilot (2 × 2 Seeds, etwa 3 h), dann Go/No-Go |
| E5 | Agenten für den Labortag mit Emulation (X3.2) | D16 r4 s7 (Labortag 2, 6,6 mm Unterschied an gegen aus), Budget-Agent θ = 0,03 s6 (bester Budget-Agent, negativer Zweig, 4,7 mm Unterschied), r0 s0 als Gegenprobe |
| Labor | Termin für X3.2 | früh anfragen. Set-Point vor Tracking (E16) geht nur, wenn X6 bis dahin fertig ist |
| E6 | Ratenpaar D10 auf 10 Seeds | nein, wenn die Diagnose ohnehin gekürzt wird |
| E19 | Residual RL (X7) in dieses Paper: Policy korrigiert den Regler, Vorteil unter Modellfehlern? | ja, als konstruktiver Teil („wo RL hilft und wo nicht“), etwa 2 bis 3 Tage, Rechenzeit 2 bis 4 h |

## 5 Grenzen, die im Paper stehen müssen

- Alle Vergleiche mit dem Regler laufen im kinematischen Simulator, gegengeprüft in Simscape (≤ 0,45 mm).
- Der Regler kennt das exakte Modell bzw. das Nominalmodell. Die Störszenarien decken nicht alles ab.
- Filter und Training unter Störungen nur mit 3 bis 8 Agenten je Budget verglichen.
- Das Budget ist als Anteil der Schritte über θ formuliert, nicht als Maximum.
- Die Ablation hat 5 Seeds je Variante und findet nur große Effekte. Der Rate Limiter wurde nicht variiert.
- Hardware bleibt der fest montierte Arm. Auch mit Emulation ist die Basisdynamik gerechnet, nicht gemessen.

## 6 Weiter geplant

| Schritt | Inhalt | Rechenzeit (geschätzt) |
|---|---|---|
| X5.1 Rest, X5.2 | 3D-Modell in Simscape, Pilot | etwa 4 h |
| X5.3 | Hauptlauf 3D mit 10 Seeds (nur bei Go) | 6 bis 8 h |
| X3.2 | Trockenläufe der gewählten Agenten, dann Labortag mit Emulation an und aus | Labor |
| X6 | Set-Point neu (nur wenn E7d dafür) | 15 bis 20 h |
| P | Paper neu aufbauen | 2 bis 3 Wochen |
