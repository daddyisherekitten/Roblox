# S29/S30 – SVG-Filtergraph und Farboperationen

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Abschlussprüfung: vollständige SVG-Suite normal und -O2 bestanden; acht finale
480-Pixel-Rastertafeln erzeugt und geprüft. HTML-Suite und Generator-Abgleiche
bestanden. Projektaudit: 337 Luau, 6 JS, 52 HTML, 256 lokale Referenzen,
7 Rojo-Projekte, 126 HTML-Fonts. Workspace/SVGLab/HTMLPage gebaut.
Rojo-API bestätigt S29_S30, FilterSources und den aktuellen Filtercode.

Stand 14.09.2026. S27/S28-Kern nach korrigiertem Zeilenvergleich zum Fortfahren
freigegeben. Dessen bekannte Text-/foreignObject-Reste bleiben offen.

## Visueller Vergleich

`examples/StudioDemoConfig.luau`: SVGStage = "S29_S30". Studio Stop → Play.
Browser: [acht Vergleichstafeln](../tests/fixtures/svg-regressions.zip).
Einzelstufen: [S29](../tests/fixtures/svg-regressions.zip), [S30](../tests/fixtures/svg-regressions.zip).
Tasten 1/2/3 wählen 240/480/960 px, R prüft 20 Neuaufbauten.
Browser rendert native SVGs, mit denselben Source-Sans-Pro-Dateien und S21-PNG-Pixeln.
Roblox rastert die identischen SVG-Quellen in die vorhandenen EditableImages.

| Tafel | Erwartung |
|---|---|
| S29-graph | Original, roter SourceAlpha-Zweig, dann screen-Kombination über benannte in/in2-Eingänge. |
| S29-regions | Orange Kontur: normal, eng beschnitten, erweiterte Region, halbe primitiveUnits-Region. |
| S29-color-space | Die untere linearRGB-Reihe ist heller als die mittlere sRGB-Reihe. Halbes Weiß ergibt rund 188 bzw. 128. |
| S29-text-order | Invertierte Textkonturen; darunter transformierte Gruppe mit direkt gemeinsam verwendetem Filter, danach Clip und Gruppen-Opacity. |
| S30-matrices | identity, saturate(0), hueRotate(90), Kanalvertauschung B/R/G. |
| S30-transfer | identity, table, discrete, linear, gamma auf derselben Graurampe. |
| S30-alpha | luminanceToAlpha, Alpha-Stufen und Alpha-Offset, der auch transparente Umgebung sichtbar macht. |
| S30-image | Originalbild neben Invertierung und Gammafilter, einschließlich transparentem Loch. |

## Umsetzung

- `Filter`: URL-Ressourcen, href/xlink:href-Vorlagen als Legacy-Erweiterung (nicht Browserparität), Zyklusbegrenzung,
  filterUnits/primitiveUnits, Filter-/Primitivregionen, vorherige Ergebnisse und
  zuletzt benannter result-Wert, SourceGraphic/SourceAlpha.
- `FilterColor`: feColorMatrix (matrix, saturate, hueRotate, luminanceToAlpha),
  feComponentTransfer und feFuncR/G/B/A mit identity/table/discrete/linear/gamma.
- `feBlend` ist als erster echter in2-Verbraucher aus S32 vorgezogen.
  feComposite und feMerge folgen weiterhin in S32.
- CSS filter und vererbtes color-interpolation-filters; linearRGB als Default.
  Umrechnung je Primitiv, Alpha bleibt linear. Nicht-premultiplizierte Float-Kanäle
  innerhalb des punktweisen Graphen; nur die Ausgabe wird auf RGBA8 gerundet.
- Isolierte SourceGraphic-Gruppe, dann Filter → Clip → Mask → Opacity/Blend.
  Text wird genau einmal als Glyphengruppe gefiltert. Bilder, Gruppen und Formen
  nutzen denselben Ablauf. Übergeordnete Viewport-Grenzen bleiben wirksam.
- Keine neuen interaktiven GUIs und keine zusätzlichen EditableImages pro
  Filterprimitiv. Bestehendes Kompositionsbudget, maximal 64 Primitive und
  32 Referenzschritte; Abbruch pro Scanline. Keine laufende Frame-Schleife.

## Prüfungen und Grenzen

`tests/SVGFilters.luau` prüft numerische Matrix-/Transferwerte, Farbraum-Rundreise,
RGBA-Referenzpixel (128/188), Alpha-Erzeugung, benannte Zweige, Referenzzyklen,
Regionen/Prozente, Default-Subregionen, einmalige Textfilter, Clip/Opacity-Reihenfolge,
Viewport-Grenzen, Abbruch und alle acht Tafeln. Die vollständige SVG-Suite prüft
zusätzlich Controller-Lebenszyklen und Ressourcenfreigabe.

Aktueller Graph ist punktweise; räumliche Nachbarschaftsoperationen kommen ab S31.
GaussianBlur/DropShadow/Offset/Flood, weitere Primitive S32–S35 und Textschatten
sind noch nicht Bestandteil dieses Pakets. BackgroundImage/BackgroundAlpha sowie
FillPaint/StrokePaint werden ausdrücklich diagnostiziert, noch nicht ausgewertet.
Mehrere CSS-Filterfunktionen bzw. URL-Listen sind noch kein SVG-Labor-Support.
Nicht unterstützte Primitive oder ungültige Parameter lassen den gesamten Filter
mit Diagnose aus, statt einen falschen Teilgraphen vorzutäuschen. Ein gültiger
Filter ohne Primitive erzeugt dagegen transparenten Inhalt. Nicht existierende
result-Namen fallen gemäß Referenz auf den vorherigen Eingang zurück.

Filter-/Primitivregionen werden am Pixelzentrum beschnitten; Subpixel-Antialiasing
an gedrehten Filterregionsgrenzen ist noch nicht abschließend browsergleich.
Die vorhandene 1024-Pixel-Ausgabegrenze und das Kompositionsbudget gelten weiter.
Leistung bei großen Graphen wird in S44 gemessen, nicht aus diesen Tafeln abgeleitet.

Lokale Luau-Rastermontage: `build/svg-s29-s30-preview.png`.
Native Browser-/Studio-Abnahme dieses Pakets durch den Nutzer steht noch aus.

Referenz: [W3C Filter Effects](https://www.w3.org/TR/filter-effects-1/), insbesondere
[Filtergraph und Regionen](https://www.w3.org/TR/filter-effects-1/#FilterPrimitiveTree),
[Farbmatrix](https://www.w3.org/TR/filter-effects-1/#feColorMatrixElement) und
[Komponententransfer](https://www.w3.org/TR/filter-effects-1/#feComponentTransferElement).

## Korrektur nach Browservergleich

Der Nutzervergleich zeigte auf S29-text-order nur die obere Schrift. Ursache:
Der untere Filter war ein leeres `<filter href="#base">`. Filter-Vererbung über
href ist eine alte, im Zielbrowser nicht unterstützte Funktion; der
[CSSWG-Beschluss vom 22.07.2026](https://www.w3.org/2026/07/22-css-minutes.html)
entfernt href am filter-Element. Die gemeinsame Tafel verwendet jetzt direkt
`filter="url(#base)"` für beide Gruppen. Originalfall separat erhalten:
`examples/svg-tests/S29-filter-href-known-difference.svg`. Engine-Vererbung bleibt
als Legacy-Erweiterung getestet, zählt nicht zur aktuellen Browserparität.
Generator-Check, Projektaudit und Workspace-Build der Korrektur bestanden;
native Sichtprüfung der korrigierten Tafel steht noch aus.
