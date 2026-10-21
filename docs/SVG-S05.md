# S05 — Längeneinheiten und Prozentbezüge

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und vom Nutzer visuell bestätigt.
S01–S05 sind vom Nutzer bestätigt.

Abnahme am 13.09.2026: „passt, weiter“. Clientbericht bei Width=480,
UIScale=1, Viewport=1319×619: Created=6, Live=6, Destroyed=0, Peak=6,
Cycles=1, Kind=ready, PixelReadback=true. Genau die vier erwarteten Diagnosen
negative-width/negative-radius/invalid-height/unknown-unit.
SourceSHA256: e2cbba342a170cba87e2b085f7ab4708c52b9086f425170636fd0e6f0aae0935.
Das automatische Feld StudioVisualComparison=pending wird durch diese manuelle
Bestätigung ergänzt. Größenwechsel und R wurden nicht separat bestätigt.

## Vergleich starten

Browser: [S05](../tests/fixtures/svg-regressions.zip). StudioDemoConfig: ActiveDemo=SVGLab,
SVGStage=S05; Stop → Play. 1/2/3: 240/480/960 px. R: 20 Neuaufbauten.
Die drei SVG-Dateien laufen unverändert durch Browser und Luau-DOM/Viewport-Kern.

1. Drei Lineale: Jeder Balken ist 96 Benutzereinheiten lang. Links Zahl/px/Exponent,
   Mitte in/cm/mm/Q/pt/pc, rechts em/rem und geerbte prozentuale Schriftgröße.
   Bei 480 px Tafelbreite sind es 96 Ausgabepixel, bei 240/960 px entsprechend 48/192.
2. Zwei Viewports mit 400×100 und 200×100 Einheiten. Beide Kreise haben r=15%:
   Radien ungefähr 43,73 bzw. 23,72. Schwarze Marken zeigen die berechneten Ränder.
   Die grünen Rechtecke verwenden auf jeder Achse x/y=25% und Breite/Höhe=50%.
3. Oben links wird eine blaue Form mit negativer Position korrekt abgeschnitten.
   Die übrigen drei Felder zeigen gültige grüne Nachbarn. Nullbreite, Nullradius,
   Nullviewport und ungültige rote Formen bleiben unsichtbar.

**Vier Diagnosen auf der dritten Tafel sind beabsichtigt:** negative-width und
negative-radius liefern negative-length, invalid-height liefert invalid-length,
unknown-unit liefert unsupported-length-unit. Der Gesamtbericht muss ready sein.
Im fertigen Zustand leben sechs EditableImages; nach Abbau null.

## Engine-Modul und API

SVG/Length.luau trennt parse, resolve und attribute. Numerische Werte werden mit
Vorzeichen, Dezimalpunkt und Exponent vollständig gelesen; Einheiten sind nicht
mit Leerzeichen von der Zahl getrennt. NaN/Infinity, Überlauf, Zusatzzeichen und
unbekannte Einheiten liefern Diagnosen statt unkontrollierter Rasterwerte.

- Zahlen/px und in/cm/mm/Q/pt/pc: feste CSS-Umrechnung mit 96 px pro in.
- Prozentwerte: x/Breite relativ zur Viewportbreite, y/Höhe relativ zur Höhe,
  andere Längen wie r relativ zu sqrt((Breite²+Höhe²)/2). Der nächste gültige
  viewBox bestimmt diese Maße in Benutzereinheiten. Der Ursprung wird nicht
  zur Prozentkoordinate addiert. Die CTM wird erst anschließend angewendet.
- em/rem beziehen sich auf übergebene FontSize/RootFontSize. Prozentuale
  Schriftgröße verwendet die übergebene Elternschriftgröße.
- ex/ch verwenden XHeight/ZeroAdvance, bei fehlenden Metriken den CSS-Ersatz
  0,5em mit expliziter font-metric-fallback-Diagnose. Kein erratenes Arial-Maß.
- lh/rlh/cap/ic verlangen LineHeight/RootLineHeight/CapHeight/IdeographicAdvance.
- vw/vh/vmin/vmax verlangen den äußeren CSSViewportWidth/Height-Kontext; sie
  werden nicht irrtümlich am inneren SVG-Viewport gemessen.

Für metrische und CSS-Viewport-Einheiten sind die übergebenen Kontexte numerisch
getestet. Das Labor demonstriert em/rem, jedoch keine behauptete Browsergleichheit
für ex/ch ohne echte Fontmetriken. Es ermittelt diese Metriken noch nicht selbst.
Moderne sv*/lv*/dv*-Viewportvarianten, Schreibmodus-Einheiten, CSS-Mathematikfunktionen
und Custom-Properties sind nicht Teil dieses einzelnen Längenparsers. Sie müssen
später durch CSS-/Dokumentkontext aufgelöst werden und werden hier nicht geraten.

attribute wählt bei ungültigen Werten den vom Aufrufer gelieferten Standardwert.
Negative Positionen sind erlaubt; nichtnegative Geometriemaße werden gesondert
geprüft. Im Probe-Adapter sind ungültige rect-Größen und Kreisradien daher null.
Die Browser-/CSS-Kaskade für gültige alternative Deklarationen folgt in S15.

## Integration und Prüfung

Der bestehende Viewports-Laboradapter erhält optional das Length-Modul. S04 nutzt
weiter seinen bisherigen Weg. S05 löst auch Formkoordinaten, Kreisradius sowie
geerbte font-size-Präsentationsattribute über den Engine-Kern auf. Gruppen setzen
keinen neuen Prozentviewport; ein verschachteltes svg mit viewBox tut dies.
Der Adapter ist weiterhin kein vollständiger Geometrie-/Paint-/CSS-Renderer.

SVGLength prüft alle implementierten Umrechnungen, fehlende Kontexte, Zahlen-
syntax, negative/ungültige Maße, Normaldiagonale ohne unnötigen Quadratüberlauf,
Font-Kontext, tatsächliche SVG-Fixtures bei drei Größen, verschachtelte viewBox-
Bezüge sowie die Abwesenheit roter Fehlerformen und sichtbare grüne Nachbarn.
Controller-/Ressourcentests mit Mocks laufen auch für S05. SVG-/HTML-Suiten normal
und -O2, Synchronitätsprüfung, Projektaudit und drei Rojo-Builds bestanden.
Die Vorschau aus tatsächlichen Luau-Pixeln wurde geprüft; kein Studio-Screenshot.

- [x] Alle Balken enden am rechten Linealstrich.
- [x] Prozentkreise und Rechtecke stimmen in beiden Rahmen.
- [x] Gültige Nachbarn sichtbar; keine rote Fehlerform; vier erwartete Diagnosen.
- [ ] Drei Größen und R-Test im Client geprüft.

Referenzen: [SVG-Einheiten](https://www.w3.org/TR/SVG2/coords.html#Units),
[SVG-Geometrie](https://www.w3.org/TR/SVG2/geometry.html),
[CSS-Längeneinheiten](https://www.w3.org/TR/css-values-4/#lengths).
