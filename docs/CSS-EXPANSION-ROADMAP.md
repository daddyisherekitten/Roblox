# CSS-Erweiterungsplan

> Historischer Ausbauplan vom September. Kandidaten und Begründungen bleiben erhalten; die aktuelle Zuordnung steht im [CSS-Abgleich](CSS-COMPLETION.md) und in [R05/R06](JAVASCRIPT-ROADMAP.md). Dies ist keine zusätzliche aktive Arbeitsreihenfolge.

Stand: 21. September 2026

## Ziel

Jede CSS-Eigenschaft, die sichtbare Pixel, Layout, Text, Medien oder die
Bedienung einer Webseite verändert, soll in Roblox eine dokumentierte
Darstellung erhalten. Der Eigenschaftskatalog enthält weiterhin nur Verhalten,
das tatsächlich funktioniert; fehlende Eigenschaften bleiben hier als offene
Arbeit sichtbar.

Grundlage ist der aktuelle MDN-Datenbestand in
[`build/mdn-css-properties.json`](../build/mdn-css-properties.json). Der erste
Abgleich fand 191 lokale Eigenschaften und 342 fehlende MDN-Einträge. Fünfunddreißig
direkte Zuordnungen und vier visuelle Gruppen sind inzwischen
umgesetzt, sodass 370 Katalogeigenschaften unterstützt werden und 162 benannte
Einträge zur Prüfung oder Umsetzung verbleiben (129 Standard, 33 experimentell).
`--*` ist bereits
über die Custom-Property-Infrastruktur funktionsfähig.

## Reihenfolge

1. **Direkte Zuordnungen:** logische Größen, Überlauf, Rahmen-Longhands,
   Ecken, `background-position-x/y` sowie getrennte `translate`, `rotate` und
   `scale` sind erledigt.
2. **Textdarstellung:** `text-wrap*`, Silbentrennung, Hervorhebungszeichen,
   Quotes, Ruby-Ausrichtung und das begrenzte Roblox-Schreibmodusprofil sind
   erledigt. Das Roblox-Profil für `font-feature-settings`, Kerning,
   Größenanpassung, Kapitälchen, Ligaturen und die geschlitzte Null ist erledigt.
   CSS-Zähler mit Reset, Erhöhung, Setzen, verschachtelter
   Ausgabe und eigenen Markern sind ebenfalls erledigt. Weitere typografische
   Feinsteuerungen bleiben offen. `line-break:anywhere`, Satzzeichen-Hängen und
   CJK-/Latein-Autospacing sind als begrenztes sichtbares Profil ergänzt.
3. **Scrollen und Eingabe:** Scroll-Snap, Scrollabstände, Overscroll,
   Scrollleistenfarben/-breite/-platz, weiche Fragmentnavigation,
   `accent-color`, `caret-*`, `appearance` und automatisch erzeugte
   Scroll-Marker für Snap-Kinder sind erledigt.
4. **Weitere Layoutmodelle:** Float/Clear, Mehrspaltenlayout,
   Zeilenbegrenzung, circle-/ellipse-Formumfluss, Größencontainer und sichtbares
   Containment sind erledigt. Offen bleiben Polygon-/Bildformen und
   intrinsische Layoutmodelle.
5. **Paint und Effekte:** Das begrenzte Roblox-Profil für Border-Images,
   Clip-Paths, positionierte/wiederholte Verlaufsmasken, Blend-Modi und
   Backdrop-Filter, Masken-Origin/Clip/Composite, Mask-Border-Verläufe,
   `corner-shape` und `border-image-outset` sind erledigt. Offen
   bleiben komplexe Pfade, Mehrfachmasken und echtes Backdrop-Sampling.
6. **Bewegung und Komposition:** Individuelle Transformfunktionen, gerade
   Bewegungspfade samt Anchor/Position, `transform-box`, Kompositionsmodi,
   begrenzte Perspektive/3D, Scroll-Timelines und Scroll-Animation-Trigger sind erledigt.
   Benannte Anchor-Boxen mit den fünf position-area-Grundseiten sind ebenfalls
   umgesetzt. Offen bleiben Kurvenpfade, echte Tiefenprojektion und View-Transitions.

SVG-Präsentationseigenschaften wie `fill`, `stroke`, Marker und Geometrie sind
bereits Teil der getrennten SVG-Pipeline. Sie werden gegen deren eigenen
Katalog geprüft, statt als HTML-Boxeigenschaften doppelt implementiert zu
werden.

## Nicht blind übertragbare Bereiche

Ein fehlender Name wird nur dann aus der sichtbaren Warteschlange entfernt,
wenn er keine darstellbare Roblox-Entsprechung besitzt. Dazu zählen reine
Druckseitensteuerung, Browserfenster-Chrome, Betriebssystem-Farbschemata und
Metadaten ohne sichtbare oder interaktive Wirkung. Experimentelle Einträge
bleiben sichtbar, werden aber nach stabilen Standards umgesetzt.

## Nachweis pro Block

Jeder Block braucht Katalogeinträge mit Wertgrenzen, Parser- und
Cascade-Tests, mindestens eine gemeinsame HTML-Testseite sowie einen visuellen
Vergleich zwischen Browser und Roblox. Erst danach wechselt er von der
Warteschlange in `supported`.
