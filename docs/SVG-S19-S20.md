# S19 + S20 — Muster und Pfadmarkierungen

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert; Browser-Abweichung bei Template-Farben korrigiert,\nerneuter visueller Nutzervergleich offen.
S01–S18 vom Nutzer bestätigt. S17/S18 mit „gut weiter“, ohne neuen Clientbericht.

## Vergleich

[Gemeinsame Browsertafel](../tests/fixtures/svg-regressions.zip), alternativ
[S19](../tests/fixtures/svg-regressions.zip) / [S20](../tests/fixtures/svg-regressions.zip).
StudioDemoConfig: SVGStage=S19_S20, ActiveDemo=SVGLab; Stop → Play.
Tasten 1/2/3: 240/480/960 px; R: 20 Neuaufbauten. Erwartet sechs Tafeln,
zwölf lebende EditableImages, PixelReadback=true und keine Diagnosen.

- S19-tiles: Schachbrett mit gleicher Phase in getrennten Boxen, transparente
  Punkte und gedrehte Streifen in einer abgerundeten Form.
- S19-units: relative Kachel-/Inhaltseinheiten mit gleicher Anzahl Kacheln,
  viewBox mit Versatz, preserveAspectRatio=none und patternTransform.
- S19-nested: Muster in einem Muster, use-Sterne mit Verlauf, href/xlink,
  CSS-Vererbung der ursprünglichen Vorlage und Fülltransparenz.
- S20-arrows: strokeWidth gegenüber userSpaceOnUse, Konturstärken 2/4/7 px,
  auto-start-reverse und context-stroke.
- S20-directions: Mittelmarker an Winkelhalbierenden, Bézier-/Bogentangenten
  und rote Endpunktmarkierungen. Keine Marker an Raster-Unterteilungspunkten.
- S20-context: Verlauf bis in die Pfeilspitze, geschlossene Teilpfade,
  feste 45°-Orientierung, CSS-Markerregel, Transform und gemeinsame Deckkraft.

scripts/sync-svg-patterns-markers.py generiert die drei Luau-Quellen und drei
Browserseiten aus sechs SVG-Dateien. Browsertafeln verwenden isolierte native
SVG-Dokumente. build/svg-s19-s20-preview.png ist eine kontrollierte Ausgabe des
tatsächlichen Luau-Rasterkerns, kein Studio-/Browser-Screenshot.\nDiese erste Gesamtvorschau enthält noch den inzwischen korrigierten grünen\nVorlagenfall. Aktuelle korrigierte dritte Tafel: build/svg-pattern-style-fixed.png.

## Implementierung

SVG/Resources verteilt Paint-URLs zwischen Gradient und Pattern und verwaltet
die begrenzte rekursive Ressourcen-Aufbereitung. Document.Content erzeugt
unabhängige Inhaltsinstanzen mit eigener CSS-Vererbung und Quell-Selektoren.
Der Viewports-Beobachter verwendet denselben Geometrie-/Stilpfad für sichtbare
Elemente, Kachelinhalte und Marker; Resources ist sein 13. optionales Argument.

Pattern: patternUnits, patternContentUnits, x/y/width/height, viewBox,
preserveAspectRatio und patternTransform/CSS transform. href/xlink übernehmen
fehlende Attribute und gegebenenfalls Inhalt aus Vorlagen, auch über den
bestehenden externen Resolver. Inhalte können Gruppen, Formen, Pfade, SVG,
use, Verläufe und weitere Muster enthalten. CSS-Stile werden am Ursprung der
Definition ausgewertet. Browser-Abgleich vom Nutzer: referenzierter Musterinhalt\nbehält den Stil seiner ursprünglichen Inhaltsvorlage, auch über href-Ketten.\nVariablen am referenzierenden Muster färben diesen Inhalt nicht um; eigene\nErsatzkinder erben dagegen dessen Stil. Dies ist eine gezielte Browser-Kompatibilität\ngegenüber dem zuvor verwendeten SVG2-Shadow-Vererbungsmodell.

Kacheln werden erst beim Rastern in temporäre CPU-Puffer gezeichnet, abhängig
von Ausgabedichte und Transformation. Ein Cache gilt nur für den jeweiligen
Rasterlauf. Es entstehen keine zusätzlichen EditableImages pro Kachel.
Wiederholung verwendet modulo auch bei negativen Positionen; periodische
bilineare Abtastung kombiniert Farbe/Alpha ohne dunkle transparente Ränder.

MarkerPositions verwendet ursprüngliche Pfadpunkte mit analytischen Tangenten
für Linien, quadratische/kubische Bézierkurven und elliptische Bögen. Nullsegmente
übernehmen benachbarte Richtungen in linearer Laufzeit. Geschlossene und mehrere
Teilpfade behalten separate Anfangs-/Schlussvertices; start/end beziehen sich
auf den gesamten Pfad. Grundformen nutzen ihre äquivalenten Pfadvertices.

Marker: marker-start/mid/end, CSS marker-Kurzform, refX/refY einschließlich
Prozent-/Positionswerten, markerWidth/Height, markerUnits, viewBox und
preserveAspectRatio. orient unterstützt auto, auto-start-reverse und feste Winkel.
Standardmäßig wird auf den Marker-Viewport beschnitten; overflow:visible
erlaubt Überhang. Formtransformation und vorhandener Viewport-Ausschnitt werden
beachtet. Marker werden während der markers-Phase von paint-order gezeichnet
und teilen die Gesamtdeckkraft der markierten Form.

context-fill/context-stroke verwenden die bereits im Koordinatensystem des
referenzierenden Elements gebundene Farbe, einschließlich Verlauf/Muster.
fill-/stroke-opacity des referenzierenden Elements wird dabei nicht geerbt;
eigene Deckkraft am Markerinhalt gilt zusätzlich. Außerhalb eines unterstützten
Kontextes ergibt context-paint keine Füllung. Allgemeines Kontext-Paint für
use-Instanzen bleibt eine spätere Erweiterung. Marker sind rein visuell.

## Prüfungen und bekannte Grenzen

Tests: Phasenlage bei x/y-Versatz, negative Wiederholung durch modulo,
beide Einheitenarten, viewBox, externe Muster, Template-/Inhaltszyklen,
Nullgröße, wiederholtes Rastern bei anderer Dichte, analytische Tangenten,
Nullsegmente, Kreise, mehrere geschlossene Teilpfade, moveto-only, Referenzpunkt,
Startumkehr, Kontur-/Markertransparenz, paint-order und fehlende Marker.
Alle sechs Tafeln werden bei drei Größen gerastert; Abbruch sowie 20
Controller-Lebenszyklen mit Ressourcenmocks werden geprüft.
Bestehende SVG- und HTML-Suiten laufen normal sowie -O2.

Grenzen: maximal 12 verschachtelte Ressourcen-Aufbereitungen, 4096
Inhaltsaufbauten, 8192 Markerpositionen pro vorbereitetem Dokument und 100
Ressourcendiagnosen. Pattern-Templateketten sind auf 64 Schritte begrenzt.
Bestehende DOM-/CSS-/Gradientenbudgets bleiben aktiv. Pro Rasterlauf maximal
32 MiB Pattern-Cache; die 32-MiB-Kompositionsgrenze wird nun auch über
verschachtelte Marker- und Kachel-Zeichnungen geteilt. Beide Budgets sind separat.

Ein Kachelpuffer ist auf 1024×1024 Pixel begrenzt. Größere Kacheln werden mit
reduzierter Dichte dargestellt; extreme Seitenverhältnisse, die bei dieser
Grenze keine Pixelzeile/-spalte mehr ergeben, bleiben transparent. Bilineare
Rasterkacheln können bei starker Verkleinerung anders filtern als Browser.
pattern overflow:visible wird diagnostiziert und auf die Kachel beschnitten;
dessen Überlappungsverhalten ist in SVG2 nicht vollständig definiert.

Offener S20-Rest: markerUnits=strokeWidth zusammen mit non-scaling-stroke.
Die Marker folgen derzeit weiterhin der Formtransformation; eine Diagnose
non-scaling-marker-units-approximation macht das sichtbar. Normale mitskalierende
Konturen und userSpaceOnUse-Marker sind umgesetzt. Die weiteren bekannten
CSS-/URL-Basis-/Live-DOM-/HTML-Paint-Grenzen aus S15–S18 bleiben bestehen.
Bilder, Text, Filter und Clipping über ihre bisherigen Fähigkeiten hinaus
werden auch in Ressourcen erst in den entsprechenden Folgeetappen ergänzt.

- [ ] Sechs Tafeln im Browser und Studio visuell vergleichen.
- [ ] Clientbericht: zwölf Bilder, PixelReadback=true, keine Diagnosen.
- [ ] Größenwechsel und R im Client bestätigen.

Grundlagen: [SVG2 Muster](https://www.w3.org/TR/SVG2/pservers.html#Patterns),
[SVG2 Marker und Kontextfarben](https://www.w3.org/TR/SVG2/painting.html#Markers).
