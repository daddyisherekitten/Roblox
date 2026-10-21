# Erste manuelle Roblox-Werte

Vom Nutzer übermittelter Screenshot, Reihenfolge laut Nutzer: 16, 24, 36 px.
Kontext der damaligen Testansicht: Arial normal. Rohwerte ohne automatische Validierung.

| TextSize | H oben | x oben | Basis | p unten |
| --- | --- | --- | --- | --- |
| 16 | 0 | 4 | 13 | 20 |
| 24 | 0 | 7 | 20 | 28 |
| 36 | 0 | 10 | 29 | 40 |

Dies sind Positionen der 1-px-Hilfslinien ab Textbox-Oberkante, keine freigegebenen Fontmetriken.
Die vorherige Anleitung setzte die Unterkante der oberen Hilfslinie direkt über den Buchstaben.
Dadurch kann bei Differenzbildung ein 1-px-Versatz entstehen. Die Kantenkonvention muss vor einer
automatischen Verwendung vereinheitlicht werden. Keine Umrechnung oder Engine-Kalibrierung aus diesen Werten.

Nächster Vergleich: 10, 20, 30, 40, 50 px in Roblox und der separaten Chrome-HTML-Datei.
