# Inter Regular: Größenabgleich

Vom Nutzer gemessene sichtbare H-Höhen bei gleichen Ausgangsgrößen (Faktor 1):

| Schriftgröße | Roblox H | HTML H |
| ---: | ---: | ---: |
| 10 px | 7 px | 7 px |
| 20 px | 13 px | 14 px |
| 30 px | 18 px | 22 px |
| 40 px | 25 px | 29 px |
| 50 px | 30 px | 36 px |

Gemeinsamer Faktor für diese Höhen nach kleinsten quadratischen Fehlern ohne konstanten Zusatz:
Summe(Roblox-H × HTML-H) / Summe(Roblox-H²) = 2432 / 2067 ≈ 1,176584.
Schriftgrößenfaktor: **1,18** (gerundet), anschließend mit Aufrunden vom Nutzer visuell bestätigt.

Die Skalierung gemessener Glyphenhöhen ist eine Näherung für die Schriftgrößenanpassung.
Pixelraster und Aufrunden können die tatsächlichen Ergebnisse verändern, besonders bei kleinen Größen.
Aktueller Test: HTML 10, 20, 30, 40, 50; Roblox TextSize nach ceil: **12, 24, 36, 48, 59**.
Zielhöhen des H: **7, 14, 22, 29, 36 px**. Der Nutzer bestätigt: „ja grösse passt“.
Die vier manuellen Linien sind in `inter-guide-fit.json` gespeichert und als eigene Inter-Formel übernommen (maximal 1 px Abweichung zu den Messpunkten).
Andere Größen bleiben Näherungen. Die Messung gilt nur für Inter Regular.
