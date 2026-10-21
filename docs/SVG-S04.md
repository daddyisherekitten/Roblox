# S04 — viewBox, preserveAspectRatio und verschachtelte Viewports

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und vom Nutzer am 13.09.2026 visuell
bestätigt ("sieht gut aus weiter"). Bericht: Width=480, UIScale=1, Viewport=1319×619,
Created=Live=Peak=8, Destroyed=0, Cycles=1, Diagnostics=[], PixelReadback=true.
SourceSHA256: 3fa4ace6ae1fafe6e740327697f62dffba92317250c96f26af0e59d0d2663f01.
Weitere Größen und R wurden nicht separat berichtet. S01–S03 bleiben bestätigt.

## Vergleich

Browser: [S04](../tests/fixtures/svg-regressions.zip). StudioDemoConfig: ActiveDemo=SVGLab,
SVGStage=S04; Stop → Play. 1/2/3 wählen 240/480/960 px, R baut 20-mal neu auf.
Die Quellen S04-modes/meet/slice/nested.svg werden unverändert im Browser und im
Roblox-Labor zur Laufzeit geparst. Kein Vorberechnen der Transformationswerte.

Vier Tafeln:

1. Oben Quadrat/meet und breiter Rahmen/meet; unten hoher Rahmen/slice und
   breiter Rahmen/none. Meet lässt blaue Freiflächen, none streckt den Kreis.
2. Alle neun meet-Ausrichtungen: Spalten xMin/xMid/xMax, Zeilen YMin/YMid/YMax.
   Jede Zelle enthält einen breiten und einen hohen Rahmen, damit beide Achsen
   sichtbar geprüft werden. Kreis und vier Eckmarken bleiben vollständig sichtbar.
3. Dasselbe Raster mit slice. Je nach Ausrichtung verschwinden andere Ecken;
   Inhalt darf die schwarzen Rahmen nicht überzeichnen.
4. Oben identische Motive mit Ursprung 0,0 und −50,−50. Unten ein Prozent-Viewport
   in einem gestreckten Eltern-Viewport; rechts bleibt auch ein overflow:visible
   gesetzter Kind-Viewport am weiterhin beschneidenden Elternrahmen abgeschnitten.

Eckfarben: Rot oben links, Grün oben rechts, Blau unten links, Violett unten rechts.
Grauer Kreis auf gelber Motivfläche; blaue Fläche kennzeichnet freien Viewportraum.
Die 100-Pixel-Messlinie liegt außerhalb der SVGs.

## Engine und Abgrenzung

SVG/Viewport.luau liest viewBox und preserveAspectRatio, berechnet Skalierung und
Versatz für meet/slice/none, alle neun Ausrichtungen, negative Ursprünge und
zusammengesetzte verschachtelte Viewports. Clipping wird im gemeinsamen Ausgabe-
koordinatensystem geschnitten. Ein sichtbarer Kind-Überlauf entfernt keinen
Elternclip. x/y/width/height erhält der Kern bereits in Eltern-Benutzereinheiten.
Eine optionale Elterntransformation muss positiv und achsenparallel sein;
allgemeine Transformationslisten, Rotation und Spiegelung gehören zu S13.

Fehlende viewBox bedeutet Translation ohne Skalierung. Fehlerhafte/negative
viewBox-Werte erzeugen eine Diagnose und werden ignoriert, Nullmaße unterdrücken
Inhalt. Ungültiges preserveAspectRatio fällt auf xMidYMid meet zurück. Numerischer
Über-/Unterlauf unterdrückt das Ergebnis mit Diagnose. Das veraltete defer-Präfix
wird nicht unterstützt. S03/Sizing verwendet jetzt denselben viewBox-Parser.

SVGLab/Viewports ist ein Beobachtungsadapter für SVG-Wurzeln/Gruppen sowie wenige
rechteckige und kreisförmige Testmarken. Er verwendet den echten S02-DOM und den
Engine-Viewport-Kern. ViewportPixels zeichnet die transformierten Testformen mit
rechteckigen Clips. Das ist weiterhin kein allgemeiner SVG-Paint-/CSS-Renderer:
Formenkatalog, Konturen, Gruppen-Opacity, Farbvererbung und SVG-Text folgen in den
geplanten Etappen. Die S03-HTML-Box erhält hier noch keine allgemeine Innenzeichnung.
Nur numerische/Prozentmaße der Testviewports sind im Adapter aufgelöst; allgemeine
Längeneinheiten und Prozentbezüge der Formen folgen in S05.

## Prüfung

SVGViewport prüft jede Ausrichtung in breiten/hohen Viewports, Ursprung, none,
verschachtelte Transformationen und Clips, fehlende/ungültige/Nullwerte sowie
Überlauf. Tatsächliche Luau-Raster bei drei Größen prüfen Flächenfarben, Freiraum,
identische Ursprungsvarianten und Elternbeschnitt. Rechteckkanten verwenden exakte
Pixeldeckung. Ellipsenränder verwenden 8×8 Flächensamples nur in der Randzone;
ein 128×128-Referenztest begrenzt die Alpha-Abweichung auf 8/255 bei der Testellipse.
Browser-Kantenglättung wird separat visuell beurteilt; keine Toleranz für falsche
Positionen, Farbfelder oder Beschnitt. Abbruch wird pro Shape-Rasterzeile geprüft.

Der vorhandene Lab-Controller besitzt acht EditableImages im fertigen Zustand:
vier Schachbretter und vier Inhaltstexturen. Bei Abbau müssen null übrig bleiben.
Alte und neue Tafeln können während des Austauschs zeitweise gleichzeitig leben.
SVG_S04_REPORT enthält Quelldigest, Ressourcenstatistik und Pixel-Rückleseergebnis.
Automatische Statistik allein ersetzt keine visuelle Bestätigung.

SVG-/HTML-Suiten normal/-O2, Fixture-Synchronität, Projektprüfung und drei
Rojo-Builds bestanden. Die lokale Vorschau aus realen Luau-Pixeln wurde geprüft;
kein Studio-/Browser-Screenshot. Studio-Messwerte und Nutzerabnahme noch offen.

- [x] Grundmodi: Kreis, Ellipse, Freiraum und Beschnitt stimmen.
- [x] Alle neun Ausrichtungen in beiden Rastertafeln stimmen.
- [x] Negative Ursprünge und verschachtelter Beschnitt stimmen.
- [ ] 1/2/3 und R im Client geprüft; acht Bilder, nach Abbau null.

Referenzen: [SVG-Koordinatensysteme](https://www.w3.org/TR/SVG2/coords.html),
[SVG-Überlauf und Clipping](https://www.w3.org/TR/SVG2/render.html#OverflowAndClipProperties).
