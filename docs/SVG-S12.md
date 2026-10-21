# S12 — Konturen und Strichmuster

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und vom Nutzer visuell bestätigt.
S01–S12 sind bestätigt. Für S12 liegt kein zusätzlicher Clientbericht vor.

## Vergleich

[Browsertafel](../tests/fixtures/svg-regressions.zip). StudioDemoConfig: ActiveDemo=SVGLab,
SVGStage=S12; Stop → Play. 1/2/3: 240/480/960 px, R: 20 Neuaufbauten.
Erwartet: vier Tafeln, acht lebende EditableImages und keine Diagnosen.

1. Linienenden: butt, round, square. Die roten Marken zeigen die ursprünglichen
   Endpunkte; round/square ragen jeweils um die halbe Strichbreite darüber hinaus.
2. Oben Ecken mit miter, round, bevel; unten spitze Winkel mit Miterlimit 1/4/10.
   Nur die dritte untere Ecke behält ihre lange Spitze.
3. Gerade Strichmuster mit Offset 0, +10 und -10; zwei kalibrierte gestrichelte
   Kreise mit Offset 0 bzw. 0,5. Anfang, Ende und Lücken vergleichen.
4. Oben explizite Nullsegmente: butt unsichtbar, round als Kreis, square als Quadrat.
   Darunter kurze Linien mit doppelten Punkten sowie runde und eckige Nullstriche
   mit sichtbaren Punkten an beiden Enden. Ein reines moveto bleibt unsichtbar.

Die vier SVG-Quellen werden mit scripts/sync-svg-stroke.py identisch in
SVGLab/StrokeSources und die Browsertafel übernommen.

## Umsetzung und Grenzen

Paint erbt stroke-linecap, stroke-linejoin, stroke-miterlimit und stroke-dashoffset
mit inherit/initial/unset. Standardwerte: butt, miter, 4 und 0. Prozent-Offsets
beziehen sich auf die normalisierte Viewportdiagonale; Nicht-Prozent-Offsets
unterliegen der vorhandenen pathLength-Kalibrierung. Negative Offsets laufen
entgegengesetzt, ungerade Dashlisten werden vor der Modulo-Berechnung verdoppelt.

Stroke ist ein eigenes Geometriemodul. Konsistent gewundene Segmentrechtecke,
äußere Eckstücke und Kappen bilden eine nichtnull-Vereinigung; Überlappungen
werden nicht mehrfach mit Alpha gemalt. Innere Miter werden nicht ergänzt,
weil sie bei kurzen Segmenten über die tatsächlichen Enden hinausragen könnten.
Runde Stücke verwenden skalierungsabhängige Polygonannäherungen. Überschrittene
Miterlimits wechseln zu bevel. Geschlossene Konturen erhalten keine Endkappen.
Nullstriche behalten ihre Richtung für gedrehte square-Kappen. Dashes verbindet
weiterhin Null-Lücken und geschlossene Nähte.

Unterstützte linejoin-Werte: miter, round, bevel. Die SVG2-Erweiterungen miter-clip
und arcs bleiben ein ausdrücklich offener Restumfang; sie liefern aktuell eine
unsupported-stroke-style-Diagnose und behalten den geerbten Wert. Sie sind nicht
als in Roblox unmöglich eingestuft. Die allgemeine SVG-CSS-Kaskade und HTML-Paint-
Anbindung folgen später. Kurvenlängen und Konturen bleiben Polygonannäherungen.

Budgets: höchstens 262144 Konturpunkte pro Stroke-Aufruf, höchstens 2048 Punkte
pro Rundung; bisherige 64 Dashwerte/65536 Teilungsschritte und Rasterbudgets gelten.
Nichtendliche kalibrierte Offsets (etwa pathLength=0 mit nichtnull Offset) bzw.
unendliche Muster mit nichtnull Offset liefern einen expliziten numerischen
Budgetfehler. Sie werden nicht unbemerkt als anderes Muster ausgegeben.

## Prüfung

SVGStroke prüft Vererbung und Fehler, exakte Kappenmaße, isolierte movetos,
Nullsegmente, Miterlimit-Bevel-Fallback, kurze scharfe Ecken, beide Offsetrichtungen,
ungerade Muster, Nullstriche an Anfang/Ende, Lücken und gedrehte Quadrate.
Die vier echten Quellen werden bei 240/480/960 px gerastert und mit gezielten
Pixelprüfungen verglichen. Controller-/Ressourcentests verwenden Mocks und prüfen
20 Lebenszyklen, ersetzte Renderjobs und Abbau.

Die lokale Vorschau aus Luau-Rasterpixeln wurde visuell kontrolliert. Sie ist kein
Studio-/Browser-Screenshot. SVG-/HTML-Suiten normal und -O2, Quellensynchronität,
Projektaudit und drei Rojo-Builds bestanden. Der laufende Rojo-Server liefert
S12-Konfiguration, Stroke und StrokeSources. Abschlussprotokoll: PROJECT-REVIEW.md.

- [x] Vier Tafeln visuell in Browser/Studio vergleichen.
- [ ] Clientbericht: acht Bilder, PixelReadback=true, keine Diagnosen.
- [ ] Größenwechsel und R im Client prüfen.

Referenz: [SVG-Konturen](https://www.w3.org/TR/SVG2/painting.html#StrokeProperties).
