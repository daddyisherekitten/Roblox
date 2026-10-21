# Roboto Mono Regular: Größenabgleich

Vom Nutzer gemessene sichtbare H-Höhen bei gleichen Ausgangsgrößen (Faktor 1):

| Schriftgröße | Roblox H | HTML H |
| ---: | ---: | ---: |
| 10 px | 7 px | 7 px |
| 20 px | 12 px | 14 px |
| 30 px | 17 px | 21 px |
| 40 px | 22 px | 28 px |
| 50 px | 28 px | 35 px |

Wie bei den bisherigen Familien: gemeinsamer Faktor nach kleinsten quadratischen Fehlern ohne konstanten Zusatz.
Summe(Roblox-H × HTML-H) / Summe(Roblox-H²) = 2170 / 1750 = **1,24**.

Engine und FontLab verwenden ceil(CSS-Größe × 1,24), also TextSize **13, 25, 38, 50, 62** für die fünf Ausgangsgrößen.
Die Browsergrößen bleiben unverändert. Zielhöhen des H: **7, 14, 21, 28, 35 px**.

Der Nutzer hat die angepasste Größe bestätigt: „grösse stimmt“. Die Breitenübereinstimmung ist nicht separat gemessen.
Ein vorheriger FONT_REPORT enthält absolute Linienpositionen bei neutralen Roblox-Textgrößen 10–50. Die eigene Linienformel wird gegen diese tatsächlichen Textgrößen angepasst, ohne sie nachträglich als korrigierte HTML-Größen umzudeuten. Daten: `roboto-mono-guide-fit.json`. Die gerundeten Formeln treffen alle fünf Messpunkte; Zwischenwerte bleiben Näherungen, über TextSize 50 wird extrapoliert. Linienpositionen bei korrigierten Größen sind noch nicht separat visuell bestätigt.
Gemessen wurde Regular mit Google Fonts im Browser; Bold/Italic verwenden vorläufig denselben Familienfaktor.
