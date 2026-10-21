# Listenformate und Textdekoration

`list-style-type` unterstützt zusätzlich `decimal-leading-zero`, `lower-alpha`,
`upper-alpha`, `lower-roman` und `upper-roman`. Beispiele: 09/10, z/aa, Z/AA,
ix/x und IX/X. `start`, `reversed`, `li value`, Vererbung und individuelle
CSS-Überschreibungen verwenden weiterhin denselben Listenzähler.

Alphabetische Marker gelten ab 1, römische von 1 bis 3999. Außerhalb des Bereichs
wird decimal verwendet. decimal-leading-zero ergänzt 0 bis 9 auf zwei Zeichen;
bei negativen Zahlen zählt das Minuszeichen zur Mindestbreite (also -1).
Alle Marker bleiben außerhalb des Textes, an dessen erster Grundlinie.
Breitere Nummern wachsen nach links. Textmaße und Labels bleiben pro Marker
gespeichert und werden bei Resize wiederverwendet.

`list-style-image:url(...)` verwendet ein über `options.Images` aufgelöstes
Bild als quadratischen 1em-Marker. `image-rendering:pixelated` beziehungsweise
`crisp-edges` gilt auch für diesen Marker. Fehlt die Bildzuordnung, bleibt der
jeweilige `list-style-type` sichtbar; bei `list-style-type:none` entsteht kein
Marker.

`text-decoration: underline wavy red` kombiniert Linienauswahl, Muster und Farbe
in beliebiger Reihenfolge. Mehrere unterschiedliche Linien sind erlaubt, ebenso
alle unterstützten Farben inklusive rgba/transparent/currentcolor. Optional
kann die vorhandene Dicke als auto, px oder % angegeben werden, z.B.
`text-decoration: underline line-through dashed rgba(255, 0, 0, .5) 2px`.

Die Kurzform setzt ausgelassene Komponenten auf none/currentcolor/solid/auto.
Farbe oder Muster allein erzeugen keine Linie. `none` darf mit Farbe/Muster,
aber nicht mit underline/overline/line-through kombiniert werden. Doppelte oder
unbekannte Komponenten verwerfen die gesamte Deklaration. Reihenfolge,
Selektoren und !important gelten gemeinsam mit den Longhands. Der Unterlinien-
Offset gehört nicht zur Kurzform; Vorfahrenlinien bleiben erhalten.
`text-decoration-line` akzeptiert weiterhin ausschließlich die Linienauswahl.
em/rem, from-font und weitere Counter-Systeme bleiben außerhalb des Umfangs.

Die Demo enthält neu Abschnitt 11 mit je einer Liste pro Format und Abschnitt 12
mit einer roten Wellenlinie. Browser-HTML und eingebettetes HTML sind identisch,
weiterhin Roboto/Roboto Mono über font-family ohne Google-Links.

## Prüfung

Durchgesehen: CSS-Parsing und Cascade, Zählerzuordnung im Renderbaum,
Markerformatierung/-messung sowie bestehende Linienrenderer. Keine zusätzlichen
Renderingobjekte pro Wort, keine Änderung an Fontprofilen oder Liniengeometrie.
Tests prüfen Zahlengrenzen, Null/negative Werte, römische Subtraktionen,
alphabetische Überträge, reversed, Resize ohne neue Messungen/Objekte,
Kurzform-Reihenfolge, Resets, !important, Alpha, Prozentwerte, ungültige Werte
und den Weg von der Kurzform bis zur gezeichneten Wellenlinie.
Native Sichtprüfung der neuen Beispiele durch den Nutzer steht aus.

Grundlagen: [CSS Counter Styles](https://www.w3.org/TR/css-counter-styles-3/)
und [CSS Text Decoration](https://www.w3.org/TR/css-text-decor-4/).
