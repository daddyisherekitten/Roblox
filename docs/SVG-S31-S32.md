# S31/S32 – Räumliche Filter und Komposition

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Nutzerabnahme 14.09.2026: „perfekt weiter“. Weiter mit S33/S34; ältere Hinweise auf ausstehende Abnahme sind historisch.

Abschlussprüfung S31/S32: SVG-Suite normal und -O2 bestanden, einschließlich
Controller-Neuaufbau/Abbruch/Freigabe. Acht finale 480-Pixel-Tafeln aus dem echten
Luau-Rasterrenderer in build/svg-s31-s32-preview.png angesehen. HTML-Regressionen,
beide Filtergenerator-Checks und Projektaudit bestanden: 344 Luau, 6 JS,
55 HTML, 259 lokale Referenzen, 7 Projekte, 126 HTML-Fonts. Workspace/SVGLab/
HTMLPage gebaut. Laufende Rojo-API liefert S31_S32 und die neuen Quellen/Module.
Native Browser-/Studio-Sichtprüfung des Pakets bleibt beim Nutzer.

Stand 14.09.2026. S29/S30 nach Korrektur der veralteten href-Filterprobe zum
Fortfahren freigegeben. S31/S32 wartet auf den nativen Browser-/Studio-Vergleich.

## Vergleich

StudioDemoConfig: `SVGStage = "S31_S32"`, Studio Stop → Play.
[Gemeinsame acht Tafeln](../tests/fixtures/svg-regressions.zip),
[S31](../tests/fixtures/svg-regressions.zip), [S32](../tests/fixtures/svg-regressions.zip).
Tasten 1/2/3: 240/480/960 px. R: 20 Neuaufbauten.
Native SVGs und Roblox verwenden dieselben SVG-Quellen, Fontdateien und Bildpixel.

| Tafel | Sichtprüfung |
|---|---|
| S31-blur | Original gegen Blur in beiden Achsen, nur X bzw. nur Y. Innenloch bleibt erkennbar, keine dunklen Farbsäume. |
| S31-offset | Positiver/negativer Versatz, objectBoundingBox-Einheiten und gedrehte Achse; rote Ausgangsrahmen. |
| S31-shadow | feDropShadow gegen die ausgeschriebene Folge: GaussianBlur, Offset, Flood, Composite, Merge. Ring und echte Textkonturen. |
| S31-regions | Weite/enge Blurregion, Schatten nach links oben, halbtransparente Flood-Fläche. |
| S32-composite | over, in, out, atop, xor, lighter mit identischen roten/blauen Scheiben. |
| S32-blend | normal, multiply, screen, darken, lighten, difference. Weitere Mischmodi bleiben durch den bestehenden Blend-Kern verfügbar. |
| S32-arithmetic | Vier k1/k2/k3/k4-Rechnungen einschließlich konstanter Alpha-Erzeugung. |
| S32-merge | Umgekehrte Merge-Reihenfolge und zwei hintereinander geschaltete Schatten an einem Bild mit transparentem Loch. |

## Umsetzung

Filter.build liest feGaussianBlur, feOffset, feFlood, feDropShadow, feComposite
und feMerge/feMergeNode. flood-color/flood-opacity laufen durch die CSS-Kaskade.
Offsets und Abweichungen beziehen sich auf primitiveUnits und die transformierten
SVG-Achsen. Objektbox-Bezüge skalieren getrennt nach Breite/Höhe.

FilterOps vereinheitlicht die punktweisen Farb-/Blend-/Composite-/Merge-Operationen.
Porter-Duff und arithmetic rechnen auf premultiplizierten Kanälen; arithmetic
begrenzt Farbkanäle zusätzlich auf das resultierende Alpha. Merge zeichnet in
Kindreihenfolge, die letzte MergeNode liegt oben. SourceGraphic/SourceAlpha und
benannte Zweige bleiben verfügbar. Reine Farbgraphen behalten den bisherigen
Weg ohne Zwischenbilder.

FilterPixels nutzt für räumliche Graphen premultiplizierte Float32-Bilder im
Ausschnitt der Filterregion. Erst die Ausgabe wird auf RGBA8 gerundet.
Zwischenergebnisse werden nach ihrer letzten Verwendung freigegeben.
FilterBlur faltet mit zwei normierten Gaußkernen, jeweils entlang einer
transformierten SVG-Achse. Fractionale Offsets verwenden bilineare Abtastung
auf premultiplizierten Werten. DropShadow extrahiert Eingangsalpha, verwischt,
verschiebt, färbt und zeichnet die ursprüngliche Eingabe darüber.

Keine zusätzlichen EditableImages pro Primitiv, keine interaktiven GUI-Objekte.
Räumliche Filter laufen im vorhandenen Rasterauftrag mit Abbruch pro Scanline.
FilterLive/FilterPeak erfassen temporäre Floatbuffer; FilterLive wird auch bei
Abbruch und Fehler wiederhergestellt. Filter- plus Kompositionsbuffer sind auf
64 MiB begrenzt (zusätzlich gilt das bisherige Kompositionsbudget).

## Verifikation und verbleibende Grenzen

Tests in SVGSpatialFilters.luau: unabhängige numerische Porter-Duff- und
arithmetic-Ergebnisse, Merge-Reihenfolge, normierter Gauß-Impuls, Teilpixeloffset,
keine dunklen Farbsäume, Null-Blur/Null-Offset in drei Größen, Schatten gegen die
manuelle Filterfolge (maximal ein Byte Unterschied), CSS-Flood/Alpha, Einheiten,
Fehlerdiagnosen, Budget-/Abbruchfreigabe und acht gerasterte Tafeln.
RGBA-Identität ignoriert ausschließlich verborgene RGB-Werte bei Alpha exakt null;
alle Alpha-Werte und sichtbaren RGB-Werte müssen exakt übereinstimmen.

- Der Gaußkern endet bei drei Standardabweichungen und wird normiert. Browser
  können andere zulässige Gauß-Approximationen nutzen. Subpixel-/gedrehte
  Regionskanten und bilineare Richtungsabtastung sind nicht pixelgenau zugesagt.
- edgeMode=none ist implementiert. duplicate/wrap werden ausdrücklich
  diagnostiziert und bleiben S31-Restumfang, nicht still als none behandelt.
- Maximal 256 Pixel Kernelradius je Achse, 64 Primitive, 64 Merge-Eingänge sowie
  die bestehenden Raster-/Speicherbudgets. Überlast wirft eine klare Diagnose
  des Rasterauftrags; Geräteperformance großer Graphen ist Aufgabe von S44.
- Filterpuffer bleiben innerhalb der vorhandenen Szenentextur. Rückwirkung von
  außerhalb dieser Textur oder zuvor abgeschnittenen Eltern-Viewports liegenden
  Quellpixeln sowie HTML-Hintergründe benötigen den Ausbau in S43/S44.
- BackgroundImage/BackgroundAlpha/FillPaint/StrokePaint, CSS-Filterlisten,
  foreignObject, frühere Textreste und Primitive S33–S35 bleiben offen.
- Filter-href-Vererbung bleibt eine separate Legacy-Erweiterung. Keine neue
  Vergleichstafel ist davon abhängig.

Referenz: [W3C Filter Effects](https://www.w3.org/TR/filter-effects-1/), insbesondere
[GaussianBlur](https://www.w3.org/TR/filter-effects-1/#feGaussianBlurElement),
[DropShadow](https://www.w3.org/TR/filter-effects-1/#feDropShadowElement) und
[Composite](https://www.w3.org/TR/filter-effects-1/#feCompositeElement).
