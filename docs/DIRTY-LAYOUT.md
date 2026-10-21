# Dirty-Layout: zweite Stufe

Geometrieänderungen an DOM, Text und Controls kennzeichnen deren Layoutbereich und
alle Eltern als geändert. Die Seite berechnet die betroffenen Größen neu und verwendet gespeicherte
Ergebnisse unveränderter, unabhängiger Teilbäume. Dadurch werden Texte oberhalb des
Formulars nicht allein wegen einer neuen Ausgabe erneut angeordnet.

Vor einem gezielten Text-/Control-Layout werden die neuen intrinsischen Textmaße
mit denen des zuletzt angeordneten Felds verglichen. Bleiben Breite, logische Höhe,
TextSize und FontFace gleich, entfällt das Layout ganz: Der Controller hat den Text
bereits aktualisiert. Diese Prüfung verwendet native Messwerte statt Zeichenanzahl.
Eine neue Ausgabe benötigt dabei eine Messung; das spätere Layout verwendet dieses
Ergebnis wieder, falls sich die Größe doch geändert hat.

Die Prüfung gilt auch für sichtbare Button-Captions und Select-Inhalte. Bei Selects
enthält der Messschlüssel die normalisierten Options-/Gruppenbeschriftungen und den
Listenmodus; reine Auswahl- oder Disabled-Änderungen behalten die Messung. Gleiche
intrinsische Maße bleiben lokal. Geänderte intrinsische Breiten ohne sicher feste
Author-Breite, Flex-Shrink-Abhängigkeiten und geometriewirksame CSS-Änderungen
verwenden weiterhin das normale Layout. Textänderungen bleiben für `:empty`/`:has`,
MutationObserver und die Cascade sichtbar, auch bei gleicher sichtbarer Caption.

Bei einer Recascade werden Prozent-/`calc()`-Abstandsvorgaben mit ihren gespeicherten
CSS-Werten verglichen. Enthalten die neuen Werte noch Längenexpressionen, bleiben
die zuletzt aufgelösten Margin-/Padding-Pixel für Paint erhalten, bis ein tatsächliches
Layout die neuen Vorgaben auflöst. Reine Pixelwerte werden sofort übernommen. Ein
Farb-/Fokuswechsel vergleicht dadurch nicht irrtümlich Pixel mit einer neuen
Längenexpression; Paint rechnet auch bei echten Änderungen nicht mit einem AST.
Neue Abstandsvorgaben, Schriftgrößen und verfügbare Breiten werden weiterhin über
den normalen Layoutpfad aufgelöst. Root-Schriftmetadaten reichen geänderte `rem`-
Werte auch durch Vorfahren mit einer festen lokalen Schriftgröße hindurch.
Grid löst Prozentabstände vor der Platzierung gegen die zugewiesene Gridfläche auf;
ein vorheriger intrinsischer Messdurchlauf bestimmt diesen Bezug nicht.

## Ablauf

`Input/Controller` übergibt das geänderte Control-Item an den vorhandenen
Layout-Worker. Mehrere Änderungen werden in einer Menge gesammelt. Der Worker
nimmt vor jeder Berechnung eine eigene Momentaufnahme; während einer Messpause
eintreffende Änderungen verbleiben für den nächsten Durchlauf in der Warteschlange.
Auch die Größenprüfung läuft in diesem Worker. Neu eintreffende Änderungen werden
vor einem veralteten Layout zusammengeführt; Resize hat weiterhin Vorrang. Leere
Ausgabe, andere Maße und fehlende Layoutdaten verwenden den normalen Layoutpfad.
Verglichen wird mit den zuletzt platzierten Maßen, niemals mit einer noch nicht
angewendeten Zwischenmessung. Messfehler fallen auf den bestehenden Layout-/Fehlerpfad zurück.

`Layout/DirtyLayout` ordnet Items ihren Layoutbereichen zu und speichert Elternlinks.
Vor der Berechnung werden der geänderte Bereich und seine Vorfahren markiert.
`BlockLayout` verwendet einen gespeicherten Rückgabewert nur dann, wenn Bereich,
Breite, Position und Layoutgeneration unverändert sind und keine speziellen
Größenvorgaben des übergeordneten Layouts vorliegen.

Ein geänderter Elternbereich durchläuft weiterhin seine Kinder, überspringt dabei
aber geeignete unveränderte Teilbäume. Wächst die Ausgabe, werden folgende
Geschwister an ihrer neuen Position angeordnet und die Eltern-/Scrollhöhen angepasst.
Reset verkleinert sie wieder. TextBox-Instanzen und Formularzustände bleiben erhalten.

## Sichtbare Positionen während Größenmessungen (8. Oktober 2026)

Ein Cache-Treffer allein verhindert keine sichtbare Bewegung durch einen Elternframe.
Bei Bytebudes „Abstimmen“ wurde die geänderte rechte Spalte zur Grid-Größenmessung
zwischenzeitlich an `(0, 0)` gezeichnet. Layoutpausen ließen diese Position sichtbar
werden; die rechte Spalte überdeckte dabei den unveränderten Wegweiser/Webmeister.
Im instrumentierten 1120-px-Luau-Test lag ihre lokale Position zeitweise bei `(0, 0)`
statt `(795, 15)`. Die unveränderten linken Instanzen wurden nicht neu erstellt.

[LayoutProbe](../src/HTMLEngine/Layout/LayoutProbe.luau) hält die native Position
eines gemessenen Block-/Bildcontainers bis zur wirklichen Platzierung fest. Grid,
Flex, das vorhandene Masonry-Profil, absolute Positionierung und atomare Inlineboxen
verwenden diesen gemeinsamen Pfad. Berechnete Maße, innere lokale Geometrie,
Cache-Einträge, Arbeitspausen und endgültige Platzierung bleiben aktiv. Anonyme
Textruns messen an ihrem behaltenen Paint-Ursprung, weil sie direkt in den
Elternframe zeichnen. Abbruch und verschachtelte Messungen stellen den vorherigen
Messzustand wieder her. Die Seite wird während partieller Layouts nicht ausgeblendet.

Nachweis: [LayoutProbeRendering](../tests/LayoutProbeRendering.luau) prüft Bytebude
bei 1120/800/360 px an jedem künstlich erzwungenen Budgethalt und an simulierten
nativen Textmesspausen. Stationäre linke/Hauptinhalte behalten GUI-Geometrie,
Sichtbarkeit und Paint-Reihenfolge; rechts bleibt der Spaltenursprung erhalten.
Bei 360 px darf die nachfolgende Navigation mit der höheren Umfrage nach unten
wandern, während ihre lokale Darstellung gleich bleibt. Die Endgeometrie entspricht
jeweils einem unabhängigen vollständigen Layout. Weitere Fälle prüfen Grid/Flex,
Masonry, absolute Positionierung, ersetzte Elemente, Inlineboxen und Abbruch.
Das ist ein Nachweis der behaltenen GUI-Eigenschaften im CLI-Host, keine native
Studio-Pixel-/FPS-Messung und keine Zusicherung atomaren Paints aller Layoutarten.

## Weitere Wiederverwendung

Unveränderte Scroll- und Transparenzbereiche sowie eigenständige relative
Positionierungscontainer können jetzt ebenfalls vollständig wiederverwendet werden.
Treffer kennzeichnen den ganzen Teilbaum für die nachfolgenden Durchläufe.
Berechnet ein späterer Durchlauf darin doch Geometrie neu, wird diese Kennzeichnung
bis zu den Eltern zurückgenommen.

Scrollbereiche setzen ihre automatischen Balken bei einem partiellen Update erst
zurück, wenn ihr Layout tatsächlich aufgerufen wird. Übersprungene Bereiche behalten
Gutter, Canvas und CanvasPosition; sie nehmen nicht an Settle/Commit teil. Ein neu
hinzukommender Balken invalidiert seinen Bereich und die Eltern für den nächsten
Konvergenzdurchlauf. So können Balken bei Wachstum erscheinen und bei Reset verschwinden.

Die Positionierungsprüfung vergleicht zusätzlich globale Position und Bezugsrahmen
(Position/Breite/Höhe), bevor sie die gespeicherten Ausmaße zurückgibt. Transparenz-
Durchläufe verwenden die gespeicherten Grenzen nur für vollständig wiederverwendete
Teilbäume. Die lokale Nullposition des Inhalts einer CanvasGroup bleibt erhalten.

Tabellen speichern zusätzlich die intrinsischen Zellbreiten, die natürliche Höhe
mit Baseline und die abschließende gestreckte Platzierung getrennt. Unveränderte
gewöhnliche Zellen können diese Ergebnisse auch innerhalb eines Scrollcontainers
wiederverwenden. Die Schlüssel enthalten verfügbare Breite, aufgelöste Rahmen und
Padding sowie die konkreten Vorgaben der jeweiligen Layoutphase. Änderungen an
Zellinhalt oder geometriewirksamen Styles bleiben dirty; eine neue Layoutgeneration
verwirft alte Treffer. Positionierte, scrollende, transparente und von Prozenthöhen
abhängige Zellunterbäume bleiben auf dem gewöhnlichen Berechnungspfad.

Zeilenreihenfolge, Spannweiten, Tracks, Ausrichtung und gemeinsame Rahmen werden
weiterhin bestimmt. Ein strukturelles Tabellenziel behält den Grund `children`,
statt unveränderte Zellen rekursiv dirty zu markieren. Tatsächliche Styleänderungen
an der Tabelle oder einzelnen Zeilen/Zellen behalten ihre stärkeren Ziele. Eine
gleichbleibende äußere Tabellenbreite oder -höhe allein reicht nicht für einen Treffer.

Tabellenmodelle werden bei CSS-Updates nur für tatsächlich geänderte Tabellenstile
erneuert, einschließlich geerbter Änderungen außerhalb des anfänglichen Selektor-
Scopes. Ein breiter Selektor-Scope allein invalidiert keine unveränderte Tabelle.
Die Normalisierung der Zeilen-/Gruppenränder bleibt bei der Recascade identisch;
`nil` statt einer Nullkante löst kein scheinbares Geometrieupdate aus. Farbänderungen
bei gleichen gemeinsamen Rahmenbreiten erneuern Modell und Paint ohne Layout;
gleichzeitige Größenänderungen in einer anderen Karte erweitern dieses Paintziel nicht.

## Bewusste Grenzen

- Resize, Erstlayout, Bildlade-/Metadatenänderungen und nicht zuordenbare Änderungen
  führen weiterhin zum vollständigen Layout. Ein ausstehendes vollständiges Layout
  hat Vorrang vor partiellen Anforderungen.
- Flexbox kann einen ganzen unabhängigen, unveränderten Teilbaum wiederverwenden.
  Muss dieser berechnet werden, laufen seine intrinsischen Messungen und Kinder
  vollständig durch den bestehenden Flex-Pfad.
- Geänderte Sonderbereiche berechnen ihre abhängigen Nachfahren weiterhin über den
  bestehenden Pfad. Scroll-/Transparenzzweige mit Positionierungsabhängigkeiten außerhalb
  ihres Teilbaums bleiben konservativ; relative Container stellen einen eigenen
  Bezugsrahmen für ihre absoluten Nachfahren bereit.
- Abstands-/Margin-Vorbereitung und Scroll-Registrierung bleiben erhalten. Die
  nachfolgenden Durchläufe überspringen nun geeignete Teilbäume; es bleibt jedoch
  weiterhin vorbereitende Arbeit am gesamten Baum.
- Dynamische DOM-/CSS-Änderungen und Formularzustände verwenden denselben gezielten
  Invalidierungspfad. Native Fokuskonturen und Auswahl sind Darstellungsänderungen.
  Geometriewirksame Author-Styles für Hover/Fokus lösen weiterhin Layout aus.

Fehlgeschlagene Berechnungen verwerfen die wiederverwendbare Generation. Der nächste
Durchlauf beginnt vollständig. Es gibt keine zusätzliche Frame-Schleife; Resize
und Scrollpaint verwenden weiterhin die vorhandenen Worker.

## Debug und Tests

`page.LastLayoutStats` enthält `Mode` (`full`/`partial`), `Recomputed` und `Reused`.
An der Seitenwurzel stehen dieselben Werte als `LayoutMode`, `LayoutRecomputed`
und `LayoutReused`. Die Zähler erfassen Layout-Aufrufe bzw. Cache-Treffer;
mehrere Scrollbar-Konvergenzdurchläufe können denselben Bereich mehrfach zählen.
Zusätzlich zählt `LastLayoutStats.PositionReused` übersprungene Positionierungs-
Durchläufe und `OpacityReused` übersprungene Berechnungen der Transparenz-Ausmaße.
`MeasurementReused` zählt wiederverwendete intrinsische Messungen und natürliche
Tabellenzellgrößen; ein Treffer darin ist kein zusätzlicher Layout-Aufruf.

Die Demo unterscheidet `Seitenlayout vollständig neu berechnet` von
`Teil-Layout (... Layout-Aufrufe, ... Cache-Treffer)`. Das HTML bleibt unverändert;
Beispiel 29 mit Testen/Reset zeigt den Unterschied. Resize zeigt weiterhin Voll-Layout.
Gleich große Output-Änderungen erzeugen keine neue Layoutmeldung und verändern
`LastLayoutStats` nicht. Testen/Reset wechselt weiterhin zwischen leerer und gefüllter
Ausgabe und benötigt deshalb ein partielles Layout.

`tests/DirtyLayout.luau` vergleicht partielle Ergebnisse mit vollständigem Layout:
Eltern-/Folgegeometrie, Wachstum/Reset, Inline-/Block-/Flexausgabe, Scrollgutter,
Positionierung, Transparenz, Margin-Collapse, Prozentgrößen und die vollständige Demo.
Es prüft außerdem, dass frühere Textläufe nicht erneut angeordnet werden.
Stufe 2 prüft unveränderte Scrollpositionen ohne Commit, tatsächlich übersprungene
Sonderdurchläufe, CanvasGroup-Inhaltspositionen, verschobene übergeordnete Container
und verschachtelte Scroll-/Positionierungs-/Transparenzbereiche. Im CLI-Demotest
sinkt die untere Ausgabeänderung von zuvor 100 auf 5 Layout-Aufrufe bei 78 Cache-Treffern.
Das ist ein Arbeitszähler unter Test-Mocks, keine gemessene Studio-Laufzeit.
Im montierten R04-Vergleich sinkt das Verschieben einer Zeile von 67 auf 35
Layout-Aufrufe; Kopieren von 89 auf 53 und Adoption von 103 auf 59. Fokus,
natives Editieren und Blur in den Tabellenfeldern benötigen dabei keinen Layoutpass.
`TableIncremental` vergleicht Partial-/Vollgeometrie einschließlich Rahmenpaint,
Spans, CSS-Strukturselektoren, Captions, Inhalts-/Breitenänderungen und Sonderfällen.
`JavaScriptStableGeometryRendering` vergleicht lokale Caption-/Select-/Control-
Änderungen in Block, Flex und Grid mit unabhängig neu aufgebautem End-DOM.
`PageLifecycle` prüft zusammengefasste Änderungen, Änderungen während laufender
Berechnungen, Resize-Vorrang und Fehlererholung; `Forms` prüft die Item-Zuordnung.
Native Studio-Sichtprüfung und Laufzeitmessung stehen noch aus.
Zusätzliche Regressionen prüfen gleich große Texte, unterschiedlich breite Zeichen
bei gleicher Zeichenanzahl, Zwischenmessungen, gemischte Update-Mengen, neue Änderungen
und Resize während der Messung sowie gleichzeitig anstehenden Scrollpaint.
