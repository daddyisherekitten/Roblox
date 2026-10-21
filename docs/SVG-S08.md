# S08 — Gerade Pfade

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und vom Nutzer visuell bestätigt.
S01–S08 sind vom Nutzer bestätigt.

Abnahme am 13.09.2026: „passt weiter“. Clientbericht bei Width=480,
UIScale=1, Viewport=1319×619, Created=6, Live=6, Destroyed=0, Peak=6,
Cycles=1, Kind=ready, PixelReadback=true, Diagnostics=[].
SourceSHA256: 33f6b80d335a71825c509e6f25e8f22c1b5700f8e4ef265cb9c3d7efb9e9a225.
Das automatische StudioVisualComparison=pending wird durch diese manuelle
Bestätigung ergänzt. Größenwechsel und R nicht separat bestätigt.

## Vergleich

[Browsertafel](../tests/fixtures/svg-regressions.zip). StudioDemoConfig: ActiveDemo=SVGLab,
SVGStage=S08; Stop → Play. 1/2/3: 240/480/960 px, R: 20 Neuaufbauten.
Erwartet werden drei Tafeln, sechs lebende EditableImages und keine Diagnosen.

1. Dasselbe Haus dreimal: Polygon-Grundform, absoluter Pfad und relativer Pfad.
   Silhouetten müssen gleich sein. Fenster und Tür bleiben gemeinsame Referenz-
   Rechtecke; der neue Pfad ersetzt die Hauskontur.
2. Offener und geschlossener Dreieckspfad. Darunter implizit geschlossene Füllung
   eines offenen Pfads sowie ein Rechteck mit wiederholten H/V-Parametern.
3. Zwei getrennte blaue Teilflächen, dazwischen keine Linie. Die transparente
   Konturkreuzung bleibt auch im Zentrum bei 50 %. Darunter ein geschlossener
   Pfad mit anschließender relativer Linie ab dem ursprünglichen Startpunkt
   sowie mehrere moveto-Befehle vor einem offenen Linienzug.

Die drei SVG-Quelldateien werden über scripts/sync-svg-paths.py unverändert in
die Browsertafel und SVGLab/PathSources übernommen.

## Umsetzung

SVG/Path liest M/L/H/V/Z sowie m/l/h/v/z, implizite Wiederholungen, zusätzliche
moveto-Paare als lineto, Vorzeichen ohne Leerzeichen, Dezimalwerte und Exponenten.
Der erste Befehl muss moveto sein. Weitere relative moveto-Befehle beziehen sich
auf den aktuellen Punkt. Z schließt die Kontur und setzt diesen auf ihren Anfang.
Eine anschließende Linie beginnt dort einen neuen offenen Teilpfad. Leeres d,
none und reine moveto-Pfade zeichnen mit den aktuellen butt-Kappen nichts.

Der Parser liefert getrennte Punktkonturen samt Closed-Flag. Geometry übernimmt
diese; Raster füllt alle Teilkonturen gemeinsam und zeichnet alle Strichteile
in einer gemeinsamen Paintoperation. So entstehen weder Verbindungen zwischen
Teilpfaden noch doppelte Deckkraft an ihren Konturkreuzungen. Die bisherige
nichtnull-Füllregel bleibt aktiv; evenodd und umfassende Lochtests folgen in S11.

Bei Syntaxfehlern bleiben zuvor vollständig gelesene Segmente erhalten. Ein
unvollständiges Koordinatenpaar wird nicht teilweise übernommen. Diagnosen nennen
Code, d-Attribut und Byteposition. Noch nicht unterstützte Kurvenbefehle liefern
unsupported-path-command. Grenzen: 262144 Quellbytes, insgesamt 4096 gespeicherte
Punkte und Koordinaten innerhalb ±1e9, auch nach relativer Addition. Bei einer
Punkt-/Koordinatengrenze bleibt der bereits gelesene Präfix erhalten; eine zu große
Gesamtquelle wird vor dem Parsen abgewiesen.

Kurven folgen in S09/S10. Vollständige Konturstile, pathLength, CSS-d und allgemeine
HTML-Paint-Anbindung sind noch nicht implementiert. S06/S07-Raster- und Paint-
Grenzen gelten weiter. Alle bisherigen Vergleichsstufen bleiben nutzbar.

## Prüfung

SVGPath prüft Befehle, Wiederholung, relative Startpunkte, kompakte Zahlen,
Fortsetzung nach Z, Fehlerpräfixe und Budgets. Die Hausraster werden bei drei
Größen über alle Pixel gegeneinander geprüft (maximal 1/255 Kanalabweichung).
Weitere Prüfstellen kontrollieren offene Schlusskanten, getrennte Teilpfade,
Moveto ohne Segment, Füllüberlappungen und Konturkreuzungen ohne doppeltes Alpha.
Ressourcen-/Controllerprüfungen laufen für S08 mit Mocks. Die Vorschau aus echten
Luau-Pixeln wurde kontrolliert; sie ist kein Browser- oder Studio-Screenshot.

SVG-/HTML-Suiten normal/-O2, Quellensynchronität, Projektaudit und drei Rojo-Builds
bestanden. Laufender Rojo-Server liefert S08-Konfiguration und Module.

- [x] Häuser, Enden und Teilpfade im Browser/Studio vergleichen.
- [x] Kreuzungs-Alpha und unsichtbare Verbindungslinien prüfen.
- [x] Clientbericht mit sechs Bildern, PixelReadback=true, ohne Diagnosen.
- [ ] Größenwechsel und R im Client prüfen.

Referenz: [SVG 2 — Paths](https://www.w3.org/TR/SVG2/paths.html).
