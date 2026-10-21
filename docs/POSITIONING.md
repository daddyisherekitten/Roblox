# Positionierung

Unterstützt: `position: static | relative | absolute | fixed | sticky`, `top`, `right`, `bottom`,
`left` mit auto/0/signierten px/% und `z-index: auto | Ganzzahl` (±100000).
Nicht vererbt; Stylesheet-/Inline-Cascade und !important bleiben wirksam.

Relative Blockboxen behalten ihren Platz im normalen Fluss. Erst danach wird
die gesamte Box mit ihren Kindern verschoben. left hat bei gleichzeitigem
right Vorrang, top bei gleichzeitigem bottom. Prozentwerte beziehen sich auf
die Inhaltsgröße des Elternblocks; vertikale Prozentwerte brauchen eine
bestimmte Elternhöhe und wirken andernfalls wie auto.

Absolute Boxen nehmen nicht an Blockfluss, Margin-Collapsing, Flexverteilung,
gap, Zeilenumbruch oder intrinsischer Größe der Eltern teil. Ihre Bezugsbox ist
die Paddingbox des nächsten positionierten Vorfahren, einschließlich sticky,
auch über statische Zwischencontainer hinweg. Transform, Perspektive, Filter
und `contain:layout|paint` können ebenfalls eine Bezugsbox erzeugen. Ohne
solchen Vorfahren gilt das Seitenfenster,
nicht die gesamte Scrollfläche. Normale Inline-Textcontainer wie span werden
bei position:absolute zu eigenständigen Boxen. Der übrige Inline-Text bleibt
zusammenhängend. Bilder können in einer positionierten Box stehen.

Fixed-Boxen werden ebenfalls aus dem Fluss genommen, beziehen ihre Kanten aber
auf den sichtbaren Seiten-Viewport. Bei einem Vorfahren mit Transform,
Perspektive, Filter oder Layout-/Paint-Containment beziehen sie sich stattdessen
auf dessen Paddingbox und bleiben in dessen GUI-Teilbaum. Bereits eine
Identitätstransformation wie `translate:0` erzeugt diese Bezugsbox. Beim Scrollen gleicht der
Positionierungsdurchlauf die CanvasPosition aus; die Box bleibt dadurch am
Fenster stehen und vergrößert die Dokument-Scrollfläche nicht. Sticky-Boxen
bleiben im Fluss und werden mit `top` beziehungsweise `bottom` innerhalb des
sichtbaren Viewports begrenzt. Z-Index und HitTest verwenden bei beiden Arten
dieselbe Geschwisterstapelung wie bei absolute/relative.

Eine automatische Breite füllt den Abstand zwischen left/right, wenn beide
angegeben sind. Sonst wird sie aus der Inhaltsbreite innerhalb des verfügbaren
Platzes ermittelt (shrink-to-fit). top+bottom strecken eine automatische Höhe.
Explizite Breiten/Höhen, Padding, Rahmen, Min-/Max-Größen und physische Margins
werden berücksichtigt. Bei beiden gesetzten Kanten können auto-Margins eine
Box mit vorgegebener Größe zentrieren. Fehlende Kanten verwenden im Blockfluss
die gemerkte statische Position; bei direkten Flexkindern die Ausrichtung eines
einzelnen hypothetischen Items. Relative Versätze beeinflussen die Grundlinien-
und Flexberechnung der anderen Items nicht.

`z-index` wirkt auf positionierte Boxen und direkte Flexitems. Die Engine ordnet
Geschwister samt ihrem Inhalt nach Ebene, danach stabil nach Reihenfolge;
Flex-order wird innerhalb derselben Ebene berücksichtigt. Gleiche Ebenen
zeichnen spätere Elemente darüber. Bei Ebene0 folgen positionierte Elemente
den normalen Geschwistern. Statische Nicht-Flexitems ignorieren z-index.

## Grenzen

- Kein writing-mode; logische Kanten unterstützen horizontales LTR/RTL. Relative
  Einheiten, CSS-Mathematik und inset als Kurzform mit 1–4 Werten sind unterstützt.
- Relative Inline-Fragmente und direkt positionierte img werden diagnostiziert;
  dafür einen div-Container verwenden. `display:inline-block` und `inline-flex`
  verwenden atomare Zeilenboxen.
- Die exakte statische Position mitten in einer Textzeile wird noch nicht
  ermittelt; solche Badges sollten explizite Kanten verwenden.
- Roblox-Sibling-Stapelung ist keine vollständige CSS-Stacking-Context-Engine:
  Kinder können die Ebene ihres GUI-Elternteilbaums nicht verlassen. Negative
  Ebenen liegen unter Geschwistern, aber weiterhin über dem eigenen Elternhintergrund.
- Clipping folgt der GUI-Hierarchie, auch an statischen Zwischenvorfahren. Die
  CSS-Ausnahmen für absolute Nachfahren außerhalb solcher Clipping-Vorfahren
  sind nicht umgesetzt. Negativer Überlauf bleibt mit Ursprung links oben nur
  eingeschränkt erreichbar. Bestehende rechteckige Clip-Näherung gilt weiter.
- Komplexe intrinsische Flex-/Aspect-Ratio-Kombinationen behalten ihre bisherigen
  Grenzen. Keine DOM-/Style-Mutationsschnittstelle.

## Umsetzung und Prüfung

Die Kombinationsregressionen vom 1. Oktober 2026 prüfen acht Varianten der
Bezugsbox einschließlich Identitätstransformation, zehn wiederholte Wechsel
zwischen static/fixed/sticky und drei Hover-Wechsel der Transform-Bezugsbox.
Fixed-Flächen ziehen zusammen mit ihrer äußeren Transparenzgruppe in eine
wiederverwendete Viewport-Ebene. Beim Zurückwechseln oder Verstecken eines
Vorfahren kommen sie an ihren ursprünglichen GUI-Elternplatz zurück.
Nachträglich aktivierte Sticky-Boxen starten die gemeinsame Scrollabtastung;
die letzte entfernte Sticky-Box beendet sie wieder. Gewöhnlicher Link-Hover
auf solchen Seiten fordert weder Layout noch erneutes Umhängen an.

Eine durch eine laufende Keyframe-Animation neu erzeugte Transform-Bezugsbox
wird noch nicht in jedem Animationsframe neu bemessen. `will-change` als
Bezugsboxauslöser und vollständige CSS-Stapelkontexte bleiben außerhalb
dieser Ergänzung. Die Tests verwenden substituierte Roblox-Objekte; native
Sichtprüfung in Studio ist weiterhin nötig.

Grundlagen für die neuen Bezugsboxen:
[CSS Transforms](https://www.w3.org/TR/css-transforms-1/#transform-rendering) und
[CSS Containment](https://www.w3.org/TR/css-contain-2/#containment-layout).

BlockLayout berechnet zuerst den Fluss und speichert lokale Boxkoordinaten.
FlowChildren lässt absolute Kinder aus, während Children/DOM vollständig bleiben.
PositionedLayout bemisst absolute Boxen danach und berechnet relative Versätze,
Bezugsboxen, Stapelung und sichtbare Scrollausdehnung. Layoutwerte werden nicht
in CSS-Werte zurückgeschrieben; ein Resize beginnt mit denselben Autorenwerten.
Unbetroffene Teilbäume überspringen den zusätzlichen Durchlauf. Vorhandene
individuelle Textmaße und Labels werden wiederverwendet.

Seiten mit Positionierung reagieren zusätzlich auf Änderungen der Fensterhöhe.
Mehrere Resize-/Bildmeldungen teilen weiterhin einen Layoutworker; Seitenabbau
bricht wartende Arbeit ab. Seiten ohne Positionierung behalten die bisherige
Optimierung für reine Höhenänderungen.

tests/Positioning prüft CSS-Validierung/Cascade, Boxmodell, Prozentwerte,
verschachtelte Bezugsboxen, relative Flussreservierung, absolute Größen und
Auto-Margins, Inline-Text, Flex-Ausschluss, Scrollen/Clipping, Stapelung, Resize
und Wiederverwendung. PageLifecycle prüft zusätzlich zusammengefasste
Höhenänderungen und Abbruch. Beispiel9 im gemeinsamen Browser-/Studio-HTML
kombiniert ein Badge rechts oben, eine Fläche rechts unten und relativen Versatz.
Native Sichtprüfung in Studio steht aus.

Grundlagen: [CSS Positioned Layout](https://www.w3.org/TR/css-position-3/) und
[CSS2, absolute Größen](https://www.w3.org/TR/CSS2/visudet.html#abs-non-replaced-width).
