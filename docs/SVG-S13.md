# S13 — Transformationen

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und vom Nutzer visuell bestätigt.
S01–S13 sind bestätigt. Für S13 liegt kein zusätzlicher Clientbericht vor.

## Vergleich

[Browsertafel](../tests/fixtures/svg-regressions.zip). StudioDemoConfig: ActiveDemo=SVGLab,
SVGStage=S13; Stop → Play. 1/2/3: 240/480/960 px, R: 20 Neuaufbauten.
Erwartet: vier Tafeln, acht lebende EditableImages und keine Diagnosen.

1. Asymmetrische F-Formen: translate, scale, rotate, skewX, Spiegelung und matrix.
   Rote Kreuze markieren den Ursprung; Achsen erleichtern den Vergleich.
2. Oben unterschiedliche Reihenfolge von translate und rotate. Unten zwei gleiche
   verschachtelte, gedrehte SVG-Viewports: ihre Ausschnitte folgen den gedrehten
   Kanten. Blau und Orange dürfen diese Grenzen nicht überschreiten.
3. Paarweise gleiche Drehungen: links CSS transform-origin mit fill-box bzw.
   stroke-box, rechts explizites rotate mit demselben Drehpunkt. Die roten Kreuze
   und die Positionen aller Formen müssen übereinstimmen.
4. Links normale Konturen, rechts non-scaling-stroke. Rechts bleiben Dicke und
   unkalibrierte Dashlängen auch bei Größenwechsel konstant. Oben ungleichmäßig
   skalierte Kreise, in der Mitte gestrichelte Linien, unten gescherte Rechtecke.

Quellen werden über scripts/sync-svg-transform.py identisch in TransformSources
und die Browsertafel übernommen. Die HTML-Hauptdemo bleibt unverändert.

## Umsetzung

Matrix stellt affine Multiplikation, Punkte, Rechteckhüllen, Determinante und
maximalen Skalierungsfaktor bereit. SX/SY/TX/TY bleiben mit bisherigen Viewports
kompatibel; KX/KY ergänzen die beiden Kreuzterme. Die größte Singulärzahl steuert
Kurvenverfeinerung auch bei Scherung und Spiegelung. Singuläre Matrizen malen nichts.

Transform parst SVG-Listen mit matrix, translate, scale, rotate (auch Mittelpunkt),
skewX/skewY, Exponenten und Komma-/Leerraumtrennung. CSS-Inlinewerte ergänzen
translateX/Y, scaleX/Y, skew, Längen/Prozente und deg/rad/grad/turn. Inlinewerte
überschreiben Präsentationsattribute; !important wird bei mehrfachen Deklarationen
beachtet. transform-origin unterstützt Achsen-Schlüsselwörter, Längen und Prozente.
view-box nutzt den Benutzerkoordinaten-Ursprung und die Viewportdimensionen;
fill-box/stroke-box nutzen Form- bzw. Konturhüllen, content-box/border-box deren
Entsprechungen für SVG-Elemente ohne CSS-Layoutbox. Gruppenhüllen berücksichtigen
Kindtransformationen. Die Wurzel hat standardmäßig einen mittigen Drehpunkt,
innere SVG-Elemente 0 0. Nichtnull-Z-Ursprünge liefern eine Diagnose.

Der Laboradapter kombiniert Gruppen-, Form- und SVG-Transformationen. Bei einem
SVG-Element liegt dessen Transformation außerhalb seiner viewBox-Abbildung.
Viewport-Clips behalten neben ihrer Rechteckhülle die gedrehten Vierecke. Raster
schneidet jede Abtastzeile gegen alle geerbten Vierecke, auch bei Verschachtelung.
Die bisherigen achsenparallelen Stufen behalten ihren einfachen Clipweg.

Normale Konturen entstehen vor der Transformation. non-scaling-stroke erzeugt
seine Kontur nach der Pfadtransformation mit konstanter Ausgabepixelbreite; auch
Dashes werden in diesem Koordinatenraum gebildet. Füllungen werden normal
transformiert. pathLength-Kalibrierung bleibt für Dashdistanzen verfügbar.

## Grenzen und noch offene Anbindung

S13 integriert Präsentationsattribute und die vier Inline-Eigenschaften transform,
transform-origin, transform-box, vector-effect. Die allgemeine SVG-CSS-Kaskade,
Selektoren/var(), explizites inherit und dynamische Aktualisierung folgen später.
3D-/Perspektivtransformationen sind kein Bestandteil dieses 2D-Schritts. Andere
vector-effect-Werte als none/non-scaling-stroke liefern eine Diagnose.

Referenzhüllen betreffen die bisher implementierten Formen/Gruppen, ohne Text,
Marker oder spätere Ressourcen. Kurvenhüllen werden aus feineren Polylinien
angenähert (Zieltoleranz 0,125/64 Benutzereinheiten, bestehende Punktlimits).
Die Kombination stroke-box mit non-scaling-stroke berücksichtigt die hostabhängige
Konturhülle noch nicht; sie verwendet derzeit die normale lokale Konturhülle.
Das bleibt ein expliziter Restfall für spätere Integrationstests. CSS-Layoutbox-
Sonderfälle an der SVG-Wurzel sind ebenfalls von der allgemeinen CSS-Anbindung
abhängig. Die Beispieltafeln verwenden diese Kombinationen nicht.

Budgets: 16384 Zeichen und 128 Funktionen je Liste, Eingabezahlen bis 1e9,
Matrixskalierung/Translation bis 1e12. Referenzhüllen teilen sich je Anfrage ein
Budget von 16384 Knoten und 262144 Punkten, auch bei verschachtelten Boxanfragen.
Ungültige Listen ergeben eine Diagnose und die Identität; keine teilweise
angewandte Restliste. Bisherige Parser-/Raster-/Kurvenbudgets gelten weiter.

## Prüfung

SVGTransforms prüft Reihenfolge, explizite Drehpunkte, Matrizen, Spiegelung,
beide Scherachsen, CSS-Einheiten/Funktionsnamen, ungültige Listen, Grenzen,
Schlüsselwort-Ursprünge, Inlinepriorität, Gruppenhüllen, negative viewBox-Ursprünge,
font-size-Prozentbezüge, Wurzelrotation und singuläre Matrizen.

Vier tatsächliche Tafeln werden bei 240/480/960 px gerastert. Gleichwertige
Drehpunkt-Paare stimmen bis 1/255 je Kanal überein. Ein Test prüft einen Punkt
innerhalb der Rechteckhülle, aber außerhalb des gedrehten Clips. Die Alpha-Summe
über eine non-scaling-Linie bleibt bei allen drei Größen exakt acht Pixel.
Controller-/Ressourcenmocks prüfen 20 Lebenszyklen und Abbruch/Abbau.

Die lokale Vorschau aus tatsächlichen Luau-Rasterpixeln wurde visuell geprüft;
sie ist kein Browser-/Studio-Screenshot. Abschließende Suite-/Build-Ergebnisse
stehen in PROJECT-REVIEW.md.

- [x] Vier Tafeln in Browser und Studio vergleichen.
- [ ] Clientbericht: acht Bilder, PixelReadback=true, keine Diagnosen.
- [ ] Größenwechsel und R im Client prüfen.

Referenzen: [SVG-Koordinatensysteme](https://www.w3.org/TR/SVG2/coords.html#TransformProperty),
[CSS-Transformationen](https://www.w3.org/TR/css-transforms-1/),
[Non-scaling stroke](https://www.w3.org/TR/SVG2/painting.html#NonScalingStroke).
