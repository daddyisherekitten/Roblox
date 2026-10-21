# S33/S34 – Bildfilter, Konturen und Rauschen

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Nutzerabnahme 14.09.2026: „gut weiter“. Fortsetzung S35/S36; frühere Hinweise zur ausstehenden Abnahme sind historisch.

Stand 14.09.2026. S31/S32 vom Nutzer mit „perfekt weiter“ zum Fortfahren
freigegeben. S33/S34 im unten beschriebenen Umfang implementiert; der native
Browser-/Studio-Vergleich steht noch aus.

StudioDemoConfig: `SVGStage = "S33_S34"`, Studio Stop → Play.
[Acht gemeinsame Tafeln](../tests/fixtures/svg-regressions.zip),
[S33](../tests/fixtures/svg-regressions.zip), [S34](../tests/fixtures/svg-regressions.zip).
Tasten 1/2/3: 240/480/960 Pixel. R: 20 Neuaufbauten.

| Tafel | Vergleich |
|---|---|
| S33-image | Dasselbe RGBA-Bild durch feImage mit meet, slice, none und kleiner Primitivregion. Rote Zielrahmen, transparentes Innenloch. |
| S33-tile | Einzelbild, Wiederholung und Wiederholung einer größeren Eingangsregion mit transparentem Rand. |
| S33-morphology | Original, dilate 3, erode 2, dilate 6/1 an einem Ring und echten Schriftkonturen. |
| S33-convolve | Original, Schärfung, Kantenerkennung und Prägung mit 3×3-Matrizen und preserveAlpha. |
| S34-displacement | Nummeriertes Raster, konstante neutrale/rote/grüne/gelbe Karte. Positive Abtastverschiebung bewegt sichtbaren Inhalt in Gegenrichtung. |
| S34-channels | Analytische R/G-Verlaufskarte, R/G gegen G/R und B/Alpha. B=128, Alpha=255. |
| S34-noise | turbulence/fractalNoise, eine/vier Oktaven, feste Seeds 7/19. Wiederaufbau muss reproduzierbar sein. |
| S34-stitch | 80×60-Rauschkacheln mit/ohne stitchTiles, wiederholt durch feTile; rote Grenzmarkierungen. |

## Umsetzung

FilterKernel parst die sechs neuen Primitive. FilterPixels führt sie in den
vorhandenen premultiplizierten Float32-Puffern aus; keine zusätzlichen
EditableImages pro Primitiv und keine interaktiven GUI-Objekte.

- feImage: derselbe validierte, zwischengespeicherte RGBA-Resolver wie bei image;
  href/xlink:href, Zielregion und preserveAspectRatio. Bilddaten bleiben sRGB,
  nachfolgende Primitive wandeln bei Bedarf in ihren Farbraum um.
- feTile: Wiederholung der gesamten Eingangsregion einschließlich transparenter
  Pixel. Bilineare Taps werden am Rand einzeln umgebrochen.
- feMorphology: zwei getrennte Min-/Max-Pässe auf premultiplizierten Kanälen;
  getrennte Radien, primitiveUnits und transformierte Achsen. Ein Radius <=0
  deaktiviert die gesamte Operation. Radius wird auf Ausgabepixel gerundet.
- feConvolveMatrix: rechteckige Matrizen, um 180° gedrehter Kernel, targetX/Y,
  divisor (Standard Summe oder 1), bias, preserveAlpha und Randmodi
  duplicate/wrap/none. Optionales kernelUnitLength skaliert mit SVG-Achsen.
  Falsche Anzahl Matrixeinträge erzeugt eine Diagnose und reicht die Eingabe
  durch. Ohne kernelUnitLength beträgt der Abstand einen Ausgabepixel.
- feDisplacementMap: unabhängige R/G/B/A-Auswahl, nicht premultiplizierte
  Kartenwerte, Farbraum der Karte getrennt von dem der verschobenen Eingabe;
  bilineare Abtastung der premultiplizierten Eingabe.
- feTurbulence: eigener Park-Miller-Generator, vier Gradiententabellen,
  deterministische Seeds, cubic interpolation, zwei Rauschtypen, Oktaven und
  Frequenzanpassung/periodische Gitter bei stitchTiles. Keine globale Zufallsquelle.

Browser und Luau erhalten identische SVG-Texte, Fontdateien und Bildpixel.
S34-ramp.png wird ohne externe Bildbibliothek aus derselben 64×64-R/G-Formel
erzeugt, die der Luau-Resolver nutzt. Der SourceSHA256 umfasst auch diese Datei.
Der Browsergenerator ersetzt sowohl image- als auch feImage-Referenzen durch
eingebettete PNG-Daten, bevor er die nativen SVG-Dokumente als Blob lädt.

## Prüfung und Grenzen

SVGKernelFilters prüft Impuls-Dilatation/Erosion, asymmetrische Kernelrichtung,
normierte Faltung, alle drei Randmodi, preserveAlpha, transparente Kachelabstände,
ganzzahlige und halbe Pixelverschiebung, den publizierten 10000. Park-Miller-Wert,
negative Seeds, Nulloktaven, periodische Nähte, Parameterdiagnosen,
Objektbox-Einheiten und Abbruch mit wiederhergestellter Speicherbilanz.

SVG-Suite normal und -O2 bestanden, inklusive Controller-Lebenszyklen. Acht
finale 480-Pixel-Rastertafeln in build/svg-s33-s34-preview.png angesehen.
HTML-Regressionen bestanden. Diese Vorschau stammt aus dem tatsächlichen
Luau-CPU-Renderer, nicht aus einer automatisierten Browser-/Studio-Sichtprüfung.

Offen / begrenzt:

- feImage unterstützt in diesem Paket Rasterquellen. Lokale Fragmentverweise
  und externe SVG-Dokumente benötigen eine eigene, zyklengeschützte Szenen-
  Rasterintegration. Sie erzeugen `unsupported-filter-image-reference` und
  ein transparentes Primitivergebnis. **S33 ist daher nicht vollständig erledigt.**
- Rauschen verwendet die SVG-1.1-/Skia-Initialisierung ohne erneutes Ziehen von
  Gradienten außerhalb des Einheitskreises. Der neuere Filter-Effects-Entwurf
  beschreibt hier einen anderen Zufallsverbrauch. Skias zusätzliche 16-Bit-
  Gradientenquantisierung wird nicht nachgebildet; geringe Pixelabweichungen
  sowie plattformabhängige Rasterursprünge bleiben visuell zu prüfen.
- Morphologie maximal 128 Ausgabepixel Radius pro Achse, Faltung maximal 225
  Kernelwerte, Rauschen maximal 9 Oktaven (mit Diagnose bei Begrenzung).
  Weiterhin 64 Primitive und 64 MiB gemeinsame Filter-/Kompositionspuffer.
- Fractionale/gedrehte Regionskanten und Morphologie-Rasterradien sind eine
  diskrete Näherung. Das ältere Problem außerhalb der Szenentextur liegender
  Quellpixel bleibt S43/S44-Rest. Keine Vollparität für solche Fälle behaupten.
- feGaussianBlur edgeMode duplicate/wrap ist weiterhin offen; die neuen
  Randmodi gelten hier ausschließlich für feConvolveMatrix.
- Lighting-Primitive folgen in S35. Frühere Text-/HTML-/Filterreste bleiben offen.

Referenzen:
[W3C Filter Effects](https://www.w3.org/TR/filter-effects-1/),
[SVG 1.1 Turbulence](https://www.w3.org/TR/SVG11/filters.html#feTurbulenceElement),
[Skia Perlin-Initialisierung](https://github.com/google/skia/blob/main/src/shaders/SkPerlinNoiseShaderImpl.h).

Abschluss: Projektaudit bestanden (351 Luau, 6 JS, 58 HTML, 262 lokale Referenzen, 7 Rojo-Projekte, 126 Fonts). Beide Filtergenerator-Checks und Workspace/SVGLab/HTMLPage-Builds bestanden. Laufende Rojo-API bestätigt S33_S34, KernelNoiseSources und neue Filtermodule. Beide PNG-Ressourcen der nativen Vergleichsseite sind eingebettet.
