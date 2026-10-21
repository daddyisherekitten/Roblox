# Open Sans Regular: Größenabgleich

Vom Nutzer gemessene sichtbare H-Höhen bei gleichen Ausgangsgrößen (Faktor 1):

| Schriftgröße | Roblox H | HTML H |
| ---: | ---: | ---: |
| 10 px | 6 px | 7 px |
| 20 px | 11 px | 14 px |
| 30 px | 17 px | 21 px |
| 40 px | 21 px | 29 px |
| 50 px | 26 px | 36 px |

Gemeinsamer Faktor für diese Höhen nach kleinsten quadratischen Fehlern ohne konstanten Zusatz:
Summe(Roblox-H × HTML-H) / Summe(Roblox-H²) = 2098 / 1563 ≈ 1,342290.
Vorläufiger Schriftgrößenfaktor: **1,34** (gerundet).

Die Skalierung gemessener Glyphenhöhen ist eine Näherung für die Schriftgrößenanpassung.
Die einzelnen Verhältnisse streuen von 1,17 bis 1,38. Ein gemeinsamer Faktor muss daher bei allen fünf Größen visuell überprüft werden.
Aktueller Test: HTML 10, 20, 30, 40, 50; Roblox TextSize nach ceil: **14, 27, 41, 54, 67**.
Zielhöhen des H: **7, 14, 21, 29, 36 px**. Die angepassten Höhen sind noch nicht bestätigt.
Der Nutzer hat anschließend einen manuellen Linienbericht geliefert. Die Werte sind in `open-sans-guide-fit.json` gespeichert und als eigene Formel übernommen (maximal 1 px Abweichung zu den fünf Messpunkten).
Eine ausdrückliche Bestätigung der angepassten H-Höhen steht weiterhin aus. Linienabstände sind keine unabhängige Zählung der sichtbaren H-Pixel. Die Messung gilt nur für Open Sans Regular.
