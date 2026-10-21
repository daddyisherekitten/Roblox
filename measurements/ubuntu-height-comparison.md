# Ubuntu Regular: Größenabgleich

Vom Nutzer gemessene sichtbare H-Höhen bei gleichen Ausgangsgrößen (Testfaktor 1):

| Schriftgröße | Roblox H | HTML H | Verhältnis HTML / Roblox |
| ---: | ---: | ---: | ---: |
| 10 px | 7 px | 7 px | 1,0000 |
| 20 px | 13 px | 14 px | 1,0769 |
| 30 px | 19 px | 21 px | 1,1053 |
| 40 px | 26 px | 28 px | 1,0769 |
| 50 px | 32 px | 35 px | 1,0938 |

Ein gemeinsamer Faktor für diese Höhen, nach kleinsten quadratischen Fehlern ohne konstanten Zusatz:
Summe(Roblox-H × HTML-H) / Summe(Roblox-H²) = 2478 / 2279 ≈ 1,087319.
Als vorläufiger Schriftgrößenfaktor verwenden wir gerundet **1,09**.
Das ersetzt die erste Schätzung 35/32 allein aus dem 50-px-Messpunkt.

Ein Faktor für gemessene Glyphenhöhen garantiert nicht dieselbe Skalierung der gerenderten Schrift.
Pixelraster und die tatsächlich gespeicherte TextSize können das Ergebnis beeinflussen.
Der Nutzer hat den Größenvergleich bei 10–50 px mit Faktor 1,09 visuell bestätigt ("passt").

Aktueller Test: HTML 10, 20, 30, 40, 50; angeforderte Roblox-TextSize 10,9, 21,8, 32,7, 43,6, 54,5.
Der Roblox-Test zeigt und misst die tatsächlich gespeicherte TextSize. Zielhöhen: **7, 14, 21, 28, 35 px**.

Die anschließend gemeldeten Linien sind in `ubuntu-guide-fit.json` gespeichert und als eigene Ubuntu-Formel übernommen (maximal 1 px Abweichung zu diesen Messpunkten).
Die Linienabstände sind keine erneute unabhängige Pixelzählung der H-Höhe. Keine Bestätigung anderer Größen oder Schriftgewichte.
