# Scrollbereiche innerhalb der Seite

Blockcontainer unterstützen `overflow: visible | hidden | clip | auto | scroll`,
`overflow-x` und `overflow-y`. Die Kurzform nimmt einen Wert für beide Achsen
oder zwei Werte in der Reihenfolge x/y. Longhands, Kurzform, Stylesheet und
Inline-Style folgen der bestehenden Cascade einschließlich !important.
Die Eigenschaften werden nicht vererbt. Eine sichtbare Achse wird erst nach
der gesamten Cascade zu auto, wenn die Gegenachse hidden/auto/scroll ist;
clip berechnet sich in dieser Kombination zu hidden.

Auto erzeugt Leisten nur bei Überlauf. Scroll reserviert dauerhaft Leistenplatz;
falls kein Überlauf besteht, zeigt ein inaktiver grauer Track die Leiste ohne
erfundenen Scrollweg. Hidden ist mit der Maus nicht scrollbar. Die erlaubten
Achsen werden über ScrollingDirection begrenzt. Clip erzeugt keine Scrollfläche.
`overflow-clip-margin` und die physischen und logischen Varianten legen die
Kante des Clip-CanvasGroup pro Seite relativ zu padding-, border- oder
content-box fest; ein positiver Wert erweitert den sichtbaren Bereich.

## Darstellung und Layout

Die äußere Box behält Hintergrund, Rahmen und Schatten. Ein ScrollingFrame
innerhalb der Rahmenkante enthält den gesamten Inhalt in einem transparenten
Frame. Dessen versetzter Ursprung erhält die bisherigen Layoutkoordinaten.
Wörter, Bilder, Listenmarker und untergeordnete Boxen scrollen gemeinsam.
Alle GuiObjects bleiben Active=false/Selectable=false; ScrollingEnabled=true.
Es gibt keine eigenen Scroll-Events oder Schleife pro Element. Die Seite
zerstört die Scrollcontainer zusammen mit ihrem vorhandenen GUI-Baum.

Die nativen Leisten werden vom verfügbaren Inhaltsraum abgezogen:
`scrollbar-width:auto` belegt 10px, `thin` 6px und `none` keinen Platz.
`scrollbar-color` setzt die native Daumenfarbe und bei dauerhaft sichtbarem
`overflow:scroll` die inaktive Spurfarbe.
Bei fester Höhe belegen sie Platz innerhalb der Box, bei automatischer Höhe
kann die Box für die horizontale Leiste wachsen. Auto-Leisten werden pro
Größenberechnung zunächst weggelassen und bei Bedarf ergänzt. Eine Änderung
löst einen weiteren Layoutdurchlauf aus; höchstens zwei neue Leisten je Box.
Gegenachsen werden anhand der tatsächlich im jeweiligen Durchlauf verwendeten
Maße geprüft, damit auto-Höhe keine unnötige vertikale Leiste bekommt.

Unveränderte Textmaße und GUI-Objekte werden weiterverwendet. Erst nach stabiler
Geometrie werden CanvasSize und die native Viewport-Größe gesetzt. CanvasPosition
bleibt erhalten und wird nur an einen kleiner gewordenen Scrollweg angepasst.
`scroll-initial-target: nearest` richtet beim ersten Layout das erste passende
Ziel innerhalb der nächsten Scrollfläche am Blockanfang aus. Ein späterer
Layoutdurchlauf setzt eine manuell geänderte Position nicht zurück.
`overflow-anchor:auto` hält ein sichtbares Element bei Neulayout im Viewport;
`none` auf der Scrollfläche oder einem Teilbaum unterbindet dies. Die
`scroll-timeline`-Kurzform setzt Namen und Achsenlisten; die Animationsbindung
nutzt die zum Namen gehörende Achse.
Innere Scrollflächen vergrößern die äußere Seiten-Canvas nicht. Relative und
absolute Nachfahren werden beim eigenen Scrollausmaß berücksichtigt; die
Bezugsbox für positionierte Nachfahren schließt Leistenplatz aus.

## Test und Grenzen

Die Kombinationsprüfungen vom 1. Oktober 2026 prüfen 45 Zustände aus Block-,
Flex- und Gridlayout, horizontaler/vertikaler Schreibrichtung sowie Hover/Fokus.
`scrollbar-gutter:stable both-edges` reserviert in inneren Scrollcontainern
Platz an beiden Inline-Kanten: links/rechts bei horizontalem und oben/unten
bei vertikalem Schreiben. Layoutursprung, Scrollinhalt und Sticky-Kanten
berücksichtigen dabei auch den zusätzlichen vorderen Abstand. Gutter schafft
keinen zusätzlichen Platz an den Block-Kanten.

Bei Zustandsänderungen aktualisieren bestehende Scrollflächen Leistenbreite,
Farbe, Scrollachsen und Overscroll-Verhalten. Scroll-Snap-Ausrichtung,
Scroll-Margin und Scroll-Padding erhalten die neu berechneten CSS-Werte.
Der äußere Seiten-ScrollingFrame reserviert seine rechte Leiste jetzt nativ
mit `VerticalScrollBarInset:Always`; eine Änderung der Leistenbreite löst
Layout mit der entsprechend verfügbaren Inhaltsbreite aus.

Stabile Gutters werden auch bei reinem `overflow:hidden` ohne native
Scrollfläche reserviert. Die Übertragung von html/body-Scrollstilen auf den
Seiten-Viewport bleibt offen.

### Intrinsischer Leistenbeitrag – 10. Oktober 2026

Die gemeinsame intrinsische Breitenmessung berücksichtigt reservierten
Leistenplatz vor den Min-/Max-Limits. Eine ausdrücklich zugewiesene Breite
erhält keinen zusätzlichen äußeren Beitrag. Bei `overflow:auto` prüft ein
eigener verbundener Messgraph mit dem bestehenden Layout-/Scrollpfad, ob
der Inhalt bei der jeweiligen intrinsischen Breite eine Leiste benötigt.
Die aktuelle Höhenbasis wird weitergegeben; Prozenthöhen verwenden keinen
alten, bereits angeordneten Live-Wert. `stable` und `both-edges` reservieren
auch bei `hidden` Platz an den Inline-Kanten. Anonyme Wortläufe und ersetzte
Elemente erhalten keine eigenen Scrollcontainer-Gutters.

Die [native Aufnahme](../tests/fixtures/intrinsic-scrollbars-browser.json)
und [Integration](../tests/IntrinsicScrollbars.luau) prüfen 159 Größenzustände
aus 53 Fällen: min-content/max-content/fit-content, auto/scroll/hidden,
auto/thin/none, stabile und beidseitige Gutters, fünf Schreibmodi mit beiden
Textausrichtungen, feste und automatische Höhen, definierte und undefinierte
Prozenthöhen, Ränder, Padding, Achsenkopplung und Größenlimits. Die rohen
Browsermaße bleiben getrennt gespeichert. Der Vergleich kalibriert klassische
Browserleisten ausdrücklich mit einer Autoren-Pseudoregel auf die tatsächlichen
Roblox-Dicken 10/6/0px; das ist kein Nachweis eines Betriebssystem-Overlayadapters.
Auch die verwendeten Courier-Vorschübe sind unabhängig nativ gemessen und
begründen keine Gleichheit zwischen Roblox- und Browser-Schriftformung.

Sechs zusätzliche Kontrollen prüfen 18 intrinsische Breitenzustände mit
verschachtelten Inline-Block-, Inline-Flex- und Inline-Grid-Boxen, automatischem
und beidseitig stabilem Gutter, Padding/Rahmen sowie definierten Prozenthöhen.
Ein frisch kopierter Gutter-Messgraph durchläuft die gemeinsame
Layoutvorbereitung und bindet seine Inline-Messmethoden an eigene Boxen;
er übernimmt keine Closures des Live-Baums. Warme Proben erhalten die
gezeichneten Boxen und Inline-Pläne ohne neue native Maße oder Oberflächen.
Abbruch innerhalb einer kalten nativen Messung veröffentlicht keine Teilmaße;
die Wiederaufnahme stimmt mit einem unabhängigen frischen Baum überein.

Neun weitere montierte Zustände ändern Breite, Overflow und Gutter bei einem
aktiven nativen Editor. Editor, DOM-Text, Auswahl, vorhandene Scrollfläche und
Eingabebindings bleiben erhalten. Die rohe Browseraufnahme behält denselben
Editor und seine Auswahl; die kalibrierten dynamischen Maße stammen aus
unabhängigen frischen Vergleichselementen, damit Chromiums verzögerte
Pseudoleisten-Invalidierung keine Referenzmaße verfälscht. Cleanup entfernt
Editor und Eingabeverbindungen. Warme Größenproben benötigen keine neuen
nativen Textmaße oder GUIs. Kalte kooperative und native Messpausen verändern
keine gezeichnete Wort-/Box-/GUI-Geometrie. Abbruch veröffentlicht keine
unvollständigen Maße; Wiederaufnahme entspricht einem frischen Layoutbaum.
22 Scroll-/Text-/Größen-/Form-/Grid-/Table-/Editor-Nachbarsuiten bestehen;
der unabhängige Review wiederholt die gezielte Suite unverändert.

Für die Leistenentscheidung wird auch erlaubter negativer Inline-Überlauf
von RTL-/Sideways-Wortzeilen erfasst. Die tatsächliche Navigation zu negativem
Überlauf bleibt im bestehenden nativen Offsetadapter offen. Nicht vollständig
geprüft sind sämtliche zyklischen Prozent-/Gutterkombinationen, Float-,
Tabellen-, orthogonalen und fragmentierten Scrollcontainer sowie die
Viewport-Übertragung. Grundlage sind die eingefrorenen Abschnitte
[CSS Overflow 3 §4.1](https://www.w3.org/TR/2025/WD-css-overflow-3-20251007/#scrollbar-layout),
[§4.2](https://www.w3.org/TR/2025/WD-css-overflow-3-20251007/#scrollbar-gutter)
und [CSS Sizing 3 §5.2.1](https://www.w3.org/TR/2026/WD-css-sizing-3-20260904/#cyclic-percentage-contribution).

Die gemeinsame Demo zeigt Abschnitt 13 (Text, vertikal auto) und 14
(Kartenreihe, overflow-x:scroll/overflow-y:hidden). Browser-HTML und Skript sind
identisch. Tests/Scrolling prüft Cascade/Achsenkopplung, GUI-Hierarchie,
Scrollflächen, gegenseitige Leistenabhängigkeit, feste/automatische/Nullhöhen,
Padding/Rahmen, verschachtelte/positionierte Boxen, Flex-Schrumpfung und Resize
mit erhaltenen Textmaßen/Objekten/Scrollpositionen. Bestehende Overflow-Tests
bleiben aktiv, einschließlich hr-Clipping über getrennte Defaultachsen.

Roblox-Leisten sind kein pixelgenauer Nachbau der betriebssystemabhängigen
Browserleisten. Das Clip-CanvasGroup nutzt kreisförmige UICorner-Radien;
elliptische CSS-Ecken, rotierte Nachfahren und eine gleichzeitig sichtbare
Gegenachse bleiben durch Roblox-Clipping begrenzt. Reines
hidden verwendet weiterhin den bisherigen Frame-Zuschnitt an der Außenkante.
Html/body werden weiterhin als normale Container behandelt, ihre Overflow-Werte
werden nicht auf den Seiten-Viewport übertragen. Scroll-Anchoring wirkt nur
in nativen inneren Scrollflächen, nicht im äußeren Seiten-Viewport. Keine
öffentliche scrollTop/scrollLeft-API oder Erreichbarkeit negativen Überlaufs.
Die bisherigen Grenzen zu positionierten Nachfahren und
Clipping durch statische Zwischenvorfahren bestehen weiter. Maus-/Touch-Routing
und native Leistengeometrie müssen im Studio visuell bestätigt werden.

Grundlagen: [CSS Overflow](https://www.w3.org/TR/css-overflow/),
[Roblox ScrollingFrame](https://create.roblox.com/docs/reference/engine/classes/ScrollingFrame)
und [Roblox Scrolling Frames](https://create.roblox.com/docs/ui/scrolling-frames).
