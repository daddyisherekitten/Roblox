# S10 — Elliptische Bögen

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und vom Nutzer visuell bestätigt.
S01–S10 sind vom Nutzer bestätigt.

Abnahme: „passt weiter“. Es wurde für S10 kein neuer Clientbericht mitgeliefert;
Bildanzahl/PixelReadback sowie Größenwechsel und R sind daher nicht zusätzlich
als im Client geprüft protokolliert.

## Vergleich

[Browsertafel](../tests/fixtures/svg-regressions.zip). StudioDemoConfig: ActiveDemo=SVGLab,
SVGStage=S10; Stop → Play. 1/2/3: 240/480/960 px, R: 20 Neuaufbauten.
Drei Tafeln, sechs lebende EditableImages und keine Diagnosen erwartet.

1. Vier Kombinationen aus large-arc-flag und sweep-flag. Oben kleine Bögen,
   unten große; links sweep=0, rechts sweep=1. Dunkler Punkt ist der Anfang,
   Orange das Ende. Die graue Sehne bleibt als Orientierung stehen.
2. Gedrehte Ellipsen aus je zwei Halbögen. Links absolute, rechts relative
   Befehle mit kompakten Flags und wiederholten Parametern. Unten rechts sind
   zusätzlich die Radien negativ geschrieben; die Form muss gleich bleiben.
3. Links zu kleine Radien, rechts passende Referenzradien: identische Bögen.
   Darunter rx=0 bzw. ry=0 als gerade Linien. Ein roter Bogen mit gleichem
   Anfang und Ende bleibt unsichtbar.

SVG-Quellen werden unverändert über scripts/sync-svg-arcs.py in ArcSources und
die Browsertafel übernommen.

## Umsetzung und Grenzen

Path verarbeitet A/a und wiederholte Siebener-Parametersätze. Die Flags werden
als einzelne 0/1-Zeichen gelesen, auch ohne Trennzeichen. Relative Befehle
verschieben nur den Endpunkt; Radien und Drehwinkel bleiben unverändert.
Fehlerhafte Flags/unvollständige Sätze liefern Diagnosen mit d-Position, zuvor
vollständige Segmente bleiben erhalten. Ein Bogen setzt die Bézier-Spiegelung zurück.

Arc trennt Endpunkt-/Mittelpunktumrechnung vom Parser und Raster. Negative Radien
werden positiv verwendet; bei Nullradius entsteht eine Linie. Gleiche Endpunkte
lassen das Bogensegment entfallen. Zu kleine Radien werden proportional vergrößert.
Drehung und beide Flags bestimmen Mittelpunkt und vorzeichenbehafteten Winkel.
Bei Radiuskorrektur wird der Mittelpunkt exakt auf den Endpunktmittelwert gesetzt,
damit Rundungsreste keinen künstlichen Mittenversatz erzeugen.

Curves erzeugt skalierungsabhängige Stützpunkte direkt aus der Ellipsenformel.
Die Winkelschrittweite begrenzt den Fehler der Mittellinie auf 0,125 Ausgabepixel;
der letzte Punkt verwendet den exakten geparsten Endpunkt. Das gemeinsame Limit
von 16384 Ausgabepunkten pro Pfad und Checkpoints nach 64 Bogenschritten gelten.
Effektive Radien müssen kleiner als 1e12 bleiben; nicht endliche oder numerisch
unterlaufende Normierungen führen zu einem ausdrücklichen Fehler. Extreme
Radius-/Koordinatenverhältnisse sind damit begrenzt und werden nicht still geraten.

Stroke-Approximation und Kantenglättung behalten die S06/S09-Grenzen. Eine
Mittellinientoleranz verspricht keine bitidentischen Browser-Stroke-Pixel.
CSS-d und allgemeine HTML-Paint-Anbindung bleiben spätere Schritte.

## Prüfung

SVGArcs prüft Flags/kompakte Syntax, relative und wiederholte Bögen, Fehlersätze,
Spiegelungsreset, alle vier Bogenrichtungen, rekonstruierte Endpunkte, negative
und korrigierte Radien, exakten Mittelpunkt bei kleinen gedrehten Radien sowie
Null-/Identitätsfälle. Analytische Ellipsenpunkte werden an 1001 Stellen bei vier
Skalierungen gegen die Polylinie geprüft. Abbruch und Punktbudget sind getestet.

Gedrehte absolute/relative Ellipsen sowie korrigierte/Referenzbögen werden bei
240/480/960 px pixelweise verglichen (maximal 1/255 Kanalabweichung). Alle drei
Tafeln werden mit dem echten Raster gerendert. Controller-/Ressourcenprüfungen
mit Mocks laufen auch für S10. Die lokale Luau-Pixelvorschau wurde kontrolliert;
sie ist kein Browser- oder Studio-Screenshot.

SVG-/HTML-Suiten normal/-O2, Quellensynchronität, Projektaudit und drei Rojo-Builds
bestanden. Laufender Rojo-Server liefert S10-Konfiguration und Module.

- [x] Vier Flag-Kombinationen und Endpunktmarken vergleichen.
- [x] Gedrehte Ellipsen, Radiuskorrektur und Nullfälle vergleichen.
- [ ] Clientbericht: sechs Bilder, PixelReadback=true, keine Diagnosen.
- [ ] Größenwechsel und R im Client prüfen.

Referenz: [SVG 2 — Arc implementation notes](https://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes).
