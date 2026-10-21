# PT Serif Regular gegenüber Times New Roman: Größenabgleich

Aktueller Stand: Der Nutzer bestätigt die Größe visuell („aber die grösse stimmt so“).
Faktor 1990/1626 bleibt unverändert. Auf ausdrücklichen Wunsch sind die Guidewerte
des späteren FONT_REPORT jetzt in einem eigenen PT-Serif-Profil modelliert.
Details und Rohwerte: `pt-serif-guide-fit.json`. Nachfolgende offene Fragen
dokumentieren den früheren Ablauf; die Größenfreigabe ist damit erfolgt.
Top, XHeight und Baseline werden an allen fünf Punkten gerundet exakt getroffen;
Bottom hat bei TextSize 25 einen Fehler von +1 px, sonst 0 px. Außerhalb 13–62
wird extrapoliert. PT Serif ist als Familie registriert, noch nicht als Default.

Nutzermessung vom 12.09.2026, sichtbare H-Höhen bei Testfaktor 1:

| Ausgangsgröße | Roblox PT Serif H | Browser Times New Roman H |
| ---: | ---: | ---: |
| 10 px | 6 px | 7 px |
| 20 px | 11 px | 13 px |
| 30 px | 16 px | 20 px |
| 40 px | 22 px | 27 px |
| 50 px | 27 px | 33 px |

Wie bei den bisherigen Größenabgleichen: kleinste quadratische Fehler ohne
konstanten Zusatz. Faktor = Summe(Roblox-H × HTML-H) / Summe(Roblox-H²)
= 1990 / 1626 = **1,2238622386223863**.

FontLab verwendet zunächst ceil(Ausgangsgröße × Faktor), also native TextSize
**13, 25, 37, 49 und 62**. Browsergrößen bleiben unverändert. Zielhöhen:
**7, 13, 20, 27 und 33 px**. Der Faktor ist eine Näherung; Rasterung und
Aufrunden erfordern eine erneute Sichtmessung. Breiten sind nicht abgeglichen.

Nur der Labor-Testfaktor ist eingestellt. PT Serif ist noch nicht in der Engine
registriert und noch kein Standard-/Fallbackfont. Guides bleiben ungemessen.
Erst H-Höhen bestätigen, danach x-/p-/Grundlinien messen. Die beiden Familien
sind verschieden; ein Größenfaktor garantiert keine identischen Glyphen.

## Manueller FONT_REPORT nach Größenkorrektur

Nutzerbericht vom 12.09., 00:22:24, Faktor 1,2238622386223864,
Regular/Normal, alle Messstatus ready, Guides ab TextLabel-Oberkante:

| HTML-Größe | TextSize | TextBounds B × H | Top | XHeight | Baseline | Bottom | Baseline − Top | Ziel-H |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 10 | 13 | 25 × 13 | 2 | 4 | 11 | 14 | 9 | 7 |
| 20 | 25 | 45 × 25 | 5 | 9 | 20 | 24 | 15 | 13 |
| 30 | 37 | 66 × 37 | 8 | 14 | 30 | 36 | 22 | 20 |
| 40 | 49 | 86 × 49 | 11 | 19 | 39 | 47 | 28 | 27 |
| 50 | 62 | 111 × 62 | 14 | 24 | 49 | 59 | 35 | 33 |

Das sind manuelle Guidepositionen, keine automatisch erkannten Glyphenränder.
Falls Rosa/Gelb tatsächlich die H-Kanten markieren, sind die H-Höhen um
2/2/2/1/2 px größer als die Browserziele. Größenbestätigung fehlt daher noch;
keine neue Faktorenkorrektur, keine Guide-Anpassung und keine Integration auf
Basis dieses Berichts vorgenommen. Nutzer muss bestätigen, ob die Linien
exakt an den H-Kanten liegen oder die Schrift visuell bereits passt.
