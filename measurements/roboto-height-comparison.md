# Roboto Regular: Größenabgleich

Vom Nutzer gemessene sichtbare H-Höhen bei gleichen Ausgangsgrößen (Faktor 1):

| Schriftgröße | Roblox H | HTML H |
| ---: | ---: | ---: |
| 10 px | 7 px | 7 px |
| 20 px | 13 px | 14 px |
| 30 px | 19 px | 22 px |
| 40 px | 25 px | 29 px |
| 50 px | 32 px | 36 px |

Gemeinsamer Faktor für diese Höhen nach kleinsten quadratischen Fehlern ohne konstanten Zusatz:
Summe(Roblox-H × HTML-H) / Summe(Roblox-H²) = 2526 / 2228 ≈ 1,133752.
Schriftgrößenfaktor: **1,13** (gerundet), anschließend vom Nutzer mit Aufrunden visuell bestätigt.

Diese Näherung muss am gerenderten Text überprüft werden: Pixelraster und gespeicherte TextSize beeinflussen die sichtbare Höhe.
Aktueller Test: HTML 10, 20, 30, 40, 50; berechnete Größen 11,3, 22,6, 33,9, 45,2, 56,5.
Auf Nutzerwunsch wird TextSize jetzt immer aufgerundet: **12, 23, 34, 46, 57**. Wortmessung und Darstellung verwenden dieselben ganzen Werte.
Der Test zeigt die tatsächlich gespeicherte TextSize. Zielhöhen des H: **7, 14, 22, 29, 36 px**.

Der Nutzer hat die angepasste Größe ausdrücklich bestätigt: „ja grösse passt“. Außerdem liegt ein Linienbericht für die aufgerundeten Größen vor.
Diese Linien sind in `roboto-guide-fit.json` gespeichert und als eigene Formel übernommen (maximal 1 px Abweichung). Die Formel bestätigt keine Übereinstimmung der H-Höhen mit Chrome.
Die Messung gilt ausschließlich für Roboto Regular, nicht für Condensed, Mono oder Slab.
