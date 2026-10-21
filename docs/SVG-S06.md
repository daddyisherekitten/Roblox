# S06 — Grundformen

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und vom Nutzer visuell bestätigt.
S01–S06 sind vom Nutzer bestätigt.

Abnahme am 13.09.2026: „weiter, alles gut“. Clientbericht bei Width=480,
UIScale=1, Viewport=1319×619: Created=6, Live=6, Destroyed=0, Peak=6,
Cycles=1, Kind=ready, PixelReadback=true, Diagnostics=[].
SourceSHA256: 45e91403d6accd0ebcc852f8770ac0a20065a86384277446901da88400301d61.
Das automatisch weiterhin offene StudioVisualComparison-Feld wird durch diese
manuelle Bestätigung ergänzt. Größenwechsel und R nicht separat bestätigt.

## Vergleich

[Browsertafel](../tests/fixtures/svg-regressions.zip). StudioDemoConfig: ActiveDemo=SVGLab,
SVGStage=S06; Stop → Play. 1/2/3 wechseln zwischen 240/480/960 px, R baut 20-mal
neu auf. Drei Tafeln, sechs lebende EditableImages, keine Diagnosen erwartet.
Nach Abbau müssen alle Bilder freigegeben sein.

1. Oben Rechteck, Kreis und Ellipse; unten Linie, offener Linienzug und Polygon.
   Graue Rahmen und weiße Mittelpunkte erleichtern den Positionsvergleich.
2. Rechteck mit nur rx; ungleiche rx/ry; übergroße Radien; explizites ry=0.
   Das dritte Rechteck wird elliptisch, das vierte bleibt scharfkantig.
3. Offener Linienzug und geschlossenes Dreieck. Darunter schließt sich die
   Füllfläche eines offenen Linienzugs, seine untere Konturlinie bleibt offen.
   Doppelte Punkte stören den rechten Linienzug nicht; eine rote Nulllinie ist
   mit dem derzeitigen butt-Ende unsichtbar.

Die SVG-Dateien werden unverändert in den Browser und als Laufzeitstrings in
ShapeSources übernommen. Synchronisierung: scripts/sync-svg-shapes.py.

## Umsetzung und Grenzen

SVG/Geometry trennt Formattribute von der Rasterausgabe. Unterstützt werden rect,
circle, ellipse, line, polyline und polygon. Längen verwenden den S05-Resolver.
Fehlende Rechteckradien übernehmen den jeweils anderen Radius und werden auf
die halbe Seitenlänge begrenzt. Prozentuale Rechteckradien beziehen sich gemäß
SVG 2 auf die verwendete Rechteckbreite bzw. -höhe. Ein expliziter Nullradius
auf einer Achse ergibt scharfe Ecken. Nullgrößen bleiben leer.

Kurven werden adaptiv in Konturen zerlegt: maximal 0,125 Ausgabepixel Sehnenfehler
bei den getesteten Größen, mit einer Grenze von 2048 Segmenten pro Vollkurve.
Sehr große Kurven können an dieser Grenze gröber werden. Punkte sind auf 4096
Paare und Koordinaten auf ±1e9 Benutzereinheiten begrenzt. Ungültige Punktwerte
liefern Diagnosen; zuvor vollständig gelesene Paare bleiben erhalten. Die
Fehlerwiederherstellung bei fehlerhaften Trennzeichen ist noch konservativ.

SVG/Raster zeichnet nichtnull-gefüllte Konturen; offene Füllflächen werden implizit
geschlossen. Vorläufige Striche verwenden butt-Enden, miter-Verbindungen und
Miterlimit 4. Andere Strichstile folgen in ihrer eigenen Etappe. Überschneidende
Strichteile werden als Vereinigung gefüllt, ohne mehrfaches Alpha an Verbindungen.
Kanten nutzen 16 vertikale Flächenproben und exakte horizontale Pixelüberdeckung.
RGB bleibt bei teiltransparenten Randpixeln unpremultipliziert; Quellüberlagerung
berücksichtigt vorhandenes Alpha. Diese Glättung muss visuell mit dem Browser
verglichen werden und ist keine Zusage bitidentischer Browserpixel.

Ausgaben sind auf 1024×1024 Pixel begrenzt; transformierte Koordinaten haben ein
gesondertes Budget. Checkpoints erlauben Abbruch und kooperative Arbeit zwischen
Rasterzeilen. Es gibt keinen dauernden Rasterloop im Leerlauf.

Der Laboradapter liest in dieser Etappe explizite RGB-Präsentationsattribute,
none und stroke-width. Allgemeine Farb-/Opacity-Vererbung, currentColor und CSS
folgen in S07/S15. Der neue Rasterkern liegt in der Engine, ist aber noch nicht
an die allgemeine HTML-SVG-Paintausgabe angeschlossen. S04/S05 behalten ihren
bestätigten Proberaster. Keine neuen interaktiven Roblox-GUIs.

## Prüfung

SVGGeometry prüft sechs Formen, Kopieren/Begrenzen von Radien, Prozentbezüge,
Kurvenfehler, Punktdiagnosen/-limits, doppelte Punkte und Nulllinien. Die drei
echten Fixture-Raster werden bei 240/480/960 px an Farben und Abschlusskanten
geprüft. Separate Tests decken Bruchpixel, Clipping und Abbruch ab.
Die vorhandenen Controller-/Ressourcenprüfungen laufen auch für S06 mit Mocks.
Die Vorschau aus tatsächlichen Luau-Pixeln wurde visuell kontrolliert; sie ist
kein Browser- oder Studio-Screenshot.
SVG-/HTML-Suiten normal und -O2, Synchronitätsprüfungen, Projektaudit und drei
Rojo-Builds bestanden; laufender Rojo-Server liefert Konfiguration und Module.

- [x] Drei Tafeln im Browser und Studio bei gleicher Breite vergleichen.
- [x] Rundungen, offene Enden und Polygonabschluss stimmen.
- [x] Clientbericht: sechs Bilder, PixelReadback=true, keine Diagnosen.
- [ ] Größenwechsel und R im Client prüfen.

Referenz: [SVG 2 — Basic Shapes](https://www.w3.org/TR/SVG2/shapes.html).
