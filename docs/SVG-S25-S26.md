# S25/S26 — Text und Typografie

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Stand: 14.09.2026. S23/S24 vom Nutzer mit „passt weiter“ visuell bestätigt.
S25/S26-Kern implementiert; nach text-orientation-Korrektur vom Nutzer visuell bestätigt.
Die weiter unten genannten Textfunktionen bleiben ausdrücklich offen und müssen
vor einem Anspruch auf vollständige SVG-Unterstützung erledigt werden.

## Vergleich

`SVGStage="S25_S26"`, `ActiveDemo="SVGLab"`. Stop → Play in Studio.
Browser: `examples/svg-tests/s25-s26.html`, einzeln `s25.html` und `s26.html`.
Acht Tafeln, 16 EditableImages einschließlich Checker-Unterlagen. Erwarteter
Bericht `SVG_S25_S26_REPORT`, leere Diagnostics. 1/2/3: 240/480/960 Pixel;
R: 20 Neuaufbauten. HTML meldet fehlgeschlagene Font-Ladevorgänge.

| Tafel | Prüfkriterium |
|---|---|
| S25-baselines | H x p Äg auf drei roten Baselines, start/middle/end an x=240. |
| S25-spans | Verschiedene tspan-Größen; geerbte Positionslisten; dx/dy; drei separate verankerte Chunks. |
| S25-spacing | Normalisierte/erhaltene Leerzeichen, letter-spacing, word-spacing, alphabetic/middle. |
| S25-fonts | Regular, Bold, Italic, Bold Italic aus vier echten Fontdateien. |
| S26-length | Natürliche Breite und 200 px mit spacing bzw. spacingAndGlyphs. |
| S26-paint | Nur Kontur, zeilenweiter Verlauf, Gruppen-Alpha, Zeichenrotation mit wiederholtem letztem Winkel. |
| S26-shaping | Kerning und ff/fft-Ligaturen, deaktivierte Features, Ä vs. A+Trema, RTL-Anker und explizites bidi-override. |
| S26-vertical | Lateinische Zeichen seitwärts bzw. aufrecht auf drei vertikalen Achsen. |

Die Browserreferenz enthält **native text/tspan-Elemente**. Sie erhält dieselben
TTF-Bytes wie der Outline-Importer, als eingebettete @font-face-Ressourcen.
Kein browserseitiges Ersetzen durch die erzeugten Konturen.

Nach Nutzervergleich korrigiert: `text-orientation` ist keine SVG-
Präsentationseigenschaft als Attribut. Die rechte vertikale Probe verwendet jetzt
`style="text-orientation:upright"`; der Renderer ignoriert das gleichnamige rohe
Attribut wie der Browser. Der ursprüngliche Test zeigte deshalb im Browser drei
gedrehte Läufe, in Roblox rechts jedoch bereits aufrechte Zeichen.

## Implementierung

`SVG/Text.luau` erzeugt aus dem unabhängigen gestylten Document-Baum einen
Gruppen-/Pfadbaum. DOM-Text bleibt erhalten; Original und Definitionen bleiben
unverändert. Auch `use` darf auf `text` zeigen. `Viewports` bindet Text im SVG-Labor
ein; `TransformBounds` kann über `context.TextExpand` Textgrenzen bestimmen.
Die spätere produktive HTML/SVG-Integration ist weiterhin S43.

- x/y/dx/dy-Listen mit Zahlen und Längeneinheiten; untergeordnete Listen ersetzen
  die entsprechenden geerbten Einträge. tspan ohne absolute Position setzt fort.
- text-anchor auf Chunks, font-size und vier Schriftschnitte, Farben, Konturen,
  paint-order, Gruppen-Opacity und Transformationen über die bestehende Pipeline.
- white-space normal/nowrap sowie erhaltene **einzeilige** Leerzeichen mit pre
  bzw. xml:space; letter-spacing und word-spacing.
- alphabetic/middle und aus Fontmetriken abgeleitete weitere Baselines.
  hanging/sub/super sind metrische Näherungen, keine vollständigen BASE-Tabellen.
- textLength mit spacing/spacingAndGlyphs auf zusammenhängenden Chunk-Bereichen,
  einschließlich innerer tspan-Bereiche; Konturbreite bleibt in SVG-Benutzereinheiten.
- rotate pro Zeichen, wiederholter letzter Winkel; explizite Zeichenpositionierung
  bzw. Rotation unterbindet mehrzeichige Ligaturen an diesen Grenzen.
- GPOS-Kerning (PairPos 1/2), Standardliga aus der Fontdatei; kanonische
  Zwei-Codepoint-Kompositionen für vorhandene Zeichen, z. B. A + Trema.
- direction:rtl verankert lateinische LTR-Läufe korrekt; bidi-override kehrt den
  Lauf explizit um. Das ist **kein vollständiger Unicode-Bidi-Algorithmus**.
- Vertikale lateinische Schrift seitwärts/aufrecht; vertical-rl/lr als Inline-Achse.

Textkonturen werden vor dem Zeichnen in SVG-Benutzereinheiten umgerechnet. Damit
werden Füllung und Rahmen nicht von Fontunits oder einem TextLabel abhängig.
Verläufe verwenden die gemeinsame Text-Inkbox. Vollständige SVG-Glyphen-Zellboxen
und mehrere unterschiedlich transformierte tspan-Paintboxen sind noch nachzuprüfen.

## Fontdaten und Grenzen

`scripts/export-svg-font.py` exportiert **alle Glyphen** der jeweiligen Datei,
keine Auswahl der Demozeichen. Source Sans Pro Regular: 1896 Konturen und 1298
Unicode-Mappings; Bold/Italic/BoldItalic: je 826 Konturen und 654 Mappings.
Lizenz: `examples/fonts/SourceSansPro-LICENSE.txt`. Herkunft und Hashes siehe
`examples/fonts/README.md`. Die bestehenden HTML-Fontkalibrierungen bleiben unberührt.

`Text.expand(node, context, report?, resolveFont?)` erlaubt zusätzliche importierte
Fonts. Der Resolver bekommt Familie, Gewicht und Stil und liefert dasselbe
Fontdatenformat (Units/Ascent/Descent/XHeight/Glyphs/Cmap/Compose/Ligatures/Kern).
Nicht verfügbare Familien fallen mit Diagnose auf Source Sans Pro zurück.
400/700 sind echte Schnitte, andere numerische Gewichte werden darauf zugeordnet.
Oblique verwendet den vorhandenen Italic-Schnitt.

Grenzen: 4096 ausgegebene Zeichen, 16384 Rohzeichen, 64 Textebenen,
Positionswerte bis 1e6, 32 unterschiedliche Diagnosen pro Textlayout; danach
gelten die vorhandenen Geometrie-/Rasterbudgets. Es wird kein Font pro Bild oder
pro Buchstabe als EditableImage angelegt. Fontdaten laden einmal je ModuleScript.

**Offen:** vollständiges Bidi einschließlich Einbettungen/Isolates und gemischten
Scripts, arabische/indische Formung, allgemeine GSUB/GPOS-Markpositionierung,
mehrfache kombinierende Zeichen, Sprachvarianten, vertikale CJK-Metriken/Features,
Textausrichtung komplexer Cluster, UTF-16-Adressierung für Nicht-BMP-Zeichen,
mehrzeilige white-space-Modi, vollständige verschachtelte Baseline-Modelle,
textLength über mehrere Chunks und freie Font-Fallbackketten. Einige dieser Fälle
geben gezielte Diagnosen; eine Diagnose ist keine Implementierung. Hinzu kommen
die geplanten Etappen textPath, Textclips/Masken und weitere Textfunktionen.

## Verifikation

- Gesamte SVG-Suite normal und -O2; Controller inklusive 20 Mount/Release-Zyklen,
  abgebrochener Rasterung und Größenwechsel. Texttests prüfen echte Module,
  Alpha-Pixel, Datenintegrität, Listen, Chunks, Fontfeatures und Diagnosepfade.
- Unabhängiger HarfBuzz-Abgleich für die Regular-Metrik AV: 530 + 515 Fontunits
  bei 1000 Units/em; echte ff/fft-Ligaturen stammen aus GSUB, nicht aus Annahmen.
- Acht Tafeln aus dem tatsächlichen Luau-Raster als lokale PNG-Montage angesehen:
  `build/svg-s25-s26-preview.png`. Keine native Studio-/Browser-Abnahme behauptet.
- HTML-Regressionssuite, Projektprüfung, Generator-Abgleiche und Rojo-Builds.

Spezifikationsgrundlage: [SVG 2, Text](https://www.w3.org/TR/SVG2/text.html).
Die Spezifikation trennt Zeichen, Glyphen und typografische Cluster; die offenen
Formungsfunktionen werden deshalb nicht durch simples Umdrehen von UTF-8-Bytes ersetzt.
