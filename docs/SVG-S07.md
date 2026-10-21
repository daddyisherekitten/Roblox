# S07 — Füllung und Kontur

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und mit „weiter“ vom Nutzer bestätigt.
S01–S07 sind vom Nutzer bestätigt.

Abnahme am 13.09.2026 nach Clientbericht: Width=480, UIScale=1,
Viewport=1319×619, Created=6, Live=6, Destroyed=0, Peak=6, Cycles=1,
Kind=ready, PixelReadback=true, Diagnostics=[].
SourceSHA256: 6c21ffaf14708b17b624e85fbf61a6179cbd694a17ecfa0b3f481a96ba7859a1.
Das automatische StudioVisualComparison=pending wird durch die manuelle Freigabe
zum Weiterarbeiten ergänzt. Größenwechsel und R nicht separat bestätigt.

## Vergleich

[Browsertafel](../tests/fixtures/svg-regressions.zip). StudioDemoConfig: ActiveDemo=SVGLab,
SVGStage=S07; Stop → Play. 1/2/3: 240/480/960 px, R: 20 Neuaufbauten.
Drei Tafeln, sechs lebende EditableImages und keine Diagnosen erwartet.

1. Standardfüllung schwarz, explizites Blau, nur grüne Kontur; darunter Füllung
   plus Kontur, vollständig unsichtbares none und transparente Füllung mit Kontur.
2. Geerbtes currentColor: blau vom Elternteil, eigene grüne Farbe am Kind,
   violette Farbe aus einer Untergruppe. Darunter initial-Schwarz, geerbtes none
   und eine schwarze Standardfüllung trotz color=red ohne fill=currentColor.
3. Blau 50 % einmal über fill-opacity und einmal über rgba. Rechts Füllung und
   Kontur jeweils 50 %; sie überlagern sich innen an der Kontur. Darunter rote
   und blaue Flächen mit je 50 % sowie Violett mit 50 % Farb-Alpha × 50 %
   fill-opacity = 25 %. Ein zusätzlicher Null-Alpha-Nachbar bleibt unsichtbar.

Alle Tafeln zeigen das Schachbrett durch transparente Flächen. Keine schwarze
Färbung an weichen Kanten; gleiche Farbwerte bei unterschiedlicher Deckung.
Unveränderte SVG-Quellen werden über scripts/sync-svg-paint.py sowohl im Browser
als auch in SVGLab/PaintSources verwendet.

## Umsetzung

SVG/Paint verarbeitet die Präsentationsattribute color, fill, stroke,
fill-opacity, stroke-opacity und stroke-width. Initialwerte sind Schwarz,
Schwarz, none, 1, 1 und 1. Alle sechs Eigenschaften werden vererbt. Unterstützt
sind dabei auch inherit, initial und unset; die vollständige CSS-Kaskade folgt
in S15. Ungültige Attribute liefern Diagnosen und erhalten den geerbten Wert.

currentColor bleibt beim Vererben von fill/stroke symbolisch. Erst Paint.used
setzt die jeweilige Elementfarbe samt Farb-Alpha ein. color=currentColor erbt
die Elternfarbe. Der gemeinsame CSS/Color-Parser liefert sRGB-Farben: Namen,
kurze/lange Hexwerte mit optionalem Alpha, Komma-rgb/rgba, hsl/hsla und transparent.
Seine vorhandenen Syntaxgrenzen gelten weiterhin, beispielsweise kein modernes
leerzeichengetrenntes rgb oder lab/oklch. Keine duplizierte Farbtabelle.

Opacity-Zahlen und Prozentwerte werden auf 0 bis 1 begrenzt. Geerbte Opacity
wird bei einer neuen Deklaration ersetzt, nicht mit der Eltern-Opacity multipliziert.
Das Farb-Alpha wird anschließend mit der jeweiligen fill-/stroke-opacity multipliziert.
Absolute und fontrelative Strichbreiten werden am deklarierenden Element berechnet;
Prozentbreiten bleiben bis zur Verwendung an den jeweiligen Viewport gebunden.

Raster verwendet RGBA mit nicht vormultiplizierten Farbkanälen. Pixeldeckung und
Paint-Alpha bestimmen die Deckkraft; jedes neue Paint wird über das vorhandene
Pixel gelegt. Füllung wird vor der Kontur gemalt. Vollständig transparente Paints
werden früh übersprungen. Die bisherigen S06-RGB-Werte bleiben voll deckend.

Dies ist noch keine Unterstützung der Eigenschaft opacity auf Elementen oder
Gruppen: deren gemeinsame Komposition folgt in S14. Paint-Server, Verläufe,
Kontextfarben für marker/use und vollständiges SVG-CSS haben spätere Etappen.
Die allgemeine HTML-SVG-Paint-Anbindung bleibt offen; S07 läuft im Vergleichslabor.
Geometrie-, Raster- und Strichstilgrenzen aus S06 bleiben bestehen.

## Prüfungen

SVGPaint prüft Standardwerte, Vererbung, unabhängige Geschwister, currentColor,
Farbsyntax, ungültige Attribute, Opacity-Clamping/-Ersetzung und Strichbreiten.
Die echten drei Tafeln werden in drei Größen gerastert. Prüfstellen kontrollieren
RGBA inklusive überlagerter Füllung/Kontur und zweier transparenter Rechtecke.
Alle teilgedeckten Randpixel des isolierten blauen Kreises behalten sein RGB.
Controller-/Lebenszyklusprüfungen mit Mocks laufen auch für S07.

SVG- und HTML-Suiten normal/-O2, Quellensynchronität, Projektaudit und drei
Rojo-Builds bestanden. Laufender Rojo-Server liefert S07-Konfiguration und Module.
Die Vorschau aus tatsächlichen Luau-Pixeln wurde visuell kontrolliert. Sie ersetzt
keinen Studio-/Browservergleich.

- [x] Farben, leere Felder und Vererbung visuell vergleichen.
- [x] Transparenz und Überlappungen einschließlich weicher Kanten vergleichen.
- [x] Clientbericht: sechs Bilder, PixelReadback=true und keine Diagnosen.
- [ ] Größenwechsel und R im Client prüfen.

Referenz: [SVG 2 — Painting](https://www.w3.org/TR/SVG2/painting.html).
