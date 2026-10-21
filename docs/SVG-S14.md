# S14 — Zeichenreihenfolge und Deckkraft

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und vom Nutzer visuell bestätigt.
S01–S14 sind bestätigt. Für S14 liegt kein zusätzlicher Clientbericht vor.

## Vergleich

[Browsertafel](../tests/fixtures/svg-regressions.zip). StudioDemoConfig: ActiveDemo=SVGLab,
SVGStage=S14; Stop → Play. 1/2/3: 240/480/960 px, R: 20 Neuaufbauten.
Erwartet: vier Tafeln, acht lebende EditableImages, keine Diagnosen.

1. Oben links zwei einzeln halbtransparente Formen: violette Überlappung. Rechts
   eine halbtransparente Gruppe: Überlappung blau. Unten links zweimal 50 % als
   verschachtelte Gruppen (25 %), rechts Füllung und Kontur gemeinsam mit 50 %.
2. Oben normal gegenüber stroke zuerst: rechts bleibt mehr Gelb sichtbar. Unten
   geerbtes stroke fill gegenüber einem Kind mit paint-order:normal.
3. Oben display:none gegenüber visibility:hidden: nur im rechten Rahmen erscheint
   das explizit sichtbare grüne Kind. Unten overflow:hidden gegenüber visible,
   die roten Rahmen markieren die inneren SVG-Viewports.
4. auto / crispEdges / geometricPrecision / optimizeSpeed. Harte Pixelkanten bei
   crispEdges; die anderen Modi bleiben geglättet. Hinweise sind Prioritäten:
   Browser dürfen hierfür unterschiedliche Rasterverfahren wählen.

Die vier SVG-Dateien werden über scripts/sync-svg-rendering.py identisch in
SVGLab/RenderingSources und s14.html übernommen.

## Umsetzung

Rendering löst Präsentationsattribute und Inline-Deklarationen dieser Etappe auf:
opacity, display, visibility, overflow, paint-order sowie shape-/color-/text-/
image-rendering. Vererbung und inherit/initial/unset werden je Eigenschaft getrennt
behandelt, ebenso Inlinepriorität und !important. Ungültige Werte liefern eine
Diagnose und lassen einen vorherigen gültigen Wert bestehen.

Der Laboradapter behält neben der flachen Shapes-Liste einen RenderTree mit
Gruppen. Compositing zeichnet in Dokumentreihenfolge. Opacity kleiner eins
verwendet einen isolierten temporären RGBA-Puffer und mischt erst die fertige
Gruppe in ihr Ziel. Auch einzelne Formen erhalten ihre opacity nach Füllung und
Kontur; fill-opacity/stroke-opacity bleiben separate Paint-Werte. Opacity wird
nicht automatisch vererbt. Null-Deckkraft überspringt die Ausgabe.

paint-order ergänzt fehlende Schritte in Normalreihenfolge und ordnet Füllung/
Kontur um. markers wird syntaktisch berücksichtigt; die eigentliche Markerausgabe
folgt in ihrer späteren Etappe. display:none entfernt den ganzen Teilbaum aus der
Ausgabe und aus Referenzhüllen. visibility:hidden/collapse unterdrückt nur die
betreffenden Formen; sichtbare Nachfahren bleiben möglich, die Geometrie zählt
weiterhin für Hüllen. Vorhandene DOM-Knoten werden nicht gelöscht.

Innere Viewports sind per SVG-Standardstil begrenzt. overflow:visible hebt nur
ihren eigenen Ausschnitt auf; geerbte Ausschnitte und die endliche Laborfläche
bleiben bestehen. hidden/clip/scroll/auto begrenzen die statische SVG-Ausgabe;
scroll/auto erzeugen hier keine zusätzlichen interaktiven Scrollleisten.

shape-rendering:auto/geometricPrecision verwendet die bisherige 16-fache
vertikale Abtastung, optimizeSpeed vier Proben und crispEdges binäre Abdeckung
an Pixelmitten. Der Rest der Geometrie bleibt unverändert. Color-/Text-/Image-
Hinweise werden aufgelöst und vererbt; mit der aktuellen Ausgabe aus einfarbigen
Formen bewirken sie keinen zusätzlichen Filter oder Text-/Bildrenderer.

## Grenzen und Prüfung

Compositing verwendet CPU-Puffer, keine zusätzlichen EditableImages. Das Budget
beträgt 32 MiB für gleichzeitig referenzierte Rasterpuffer inklusive Ausgabe und
höchstens 256 RenderTree-Ebenen. Budgetüberschreitungen sind explizite Fehler.
Abbruch wird vor Knoten, in der Rasterung und zeilenweise beim Zusammenmischen
geprüft; eine abgebrochene Ausgabe wird nicht veröffentlicht. Alpha/RGB werden
je Ebene in 8 Bit gespeichert, daher sind Rundungsabweichungen möglich.

Allgemeine Stylesheets/Selektoren/var() folgen in S15; vollständige HTML-Paint-
Anbindung, Marker, Bilder und Text behalten ihren bisherigen offenen Status.
Die endliche Rasterfläche begrenzt auch bei root overflow:visible die Ausgabe.
Keine Behauptung, sämtliche späteren Filter/Blend-/Maskeneffekte bereits abzudecken.

SVGRendering prüft konkrete RGBA-Werte für Einzel-/Gruppen-/verschachtelte Opacity,
Füllung/Kontur, paint-order, Vererbung, ungültige Werte, Sichtbarkeitsausnahmen,
Display-Teilbäume und Hüllen, Overflow sowie binäre/geglättete Kanten. Die echten
vier Tafeln werden in drei Größen gerastert. Speichergrenze, Abbruch vor Ausgabe
und zwischen Zeichnen und Komposition sowie 20 Controller-Lebenszyklen sind
mit automatisierten Tests bzw. Ressourcenmocks abgedeckt.

Eine lokale Vorschau aus tatsächlichen Luau-Pixeln wurde visuell kontrolliert.
Sie ist kein Studio-/Browser-Screenshot. Abschließende Suiten und Builds stehen
in PROJECT-REVIEW.md.

- [x] Vier Tafeln in Browser und Studio vergleichen.
- [ ] Clientbericht: acht Bilder, PixelReadback=true, keine Diagnosen.
- [ ] Größenwechsel und R im Client prüfen.

Referenzen: [SVG-Renderingmodell](https://www.w3.org/TR/SVG2/render.html),
[Paint order und Rendering-Hinweise](https://www.w3.org/TR/SVG2/painting.html#PaintOrderProperty).
