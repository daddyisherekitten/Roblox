# Tabellen: unterstützter Teilumfang

`caption` mit `caption-side: top | bottom` steht außerhalb des Tabellenrahmens.
Die Eigenschaft wird vererbt; Standard ist oben und zentrierter Text. Die Caption
hat eigene Rahmen, Padding und Margins, benutzt die äußere Tabellenbreite und
bricht bei Resize um. Ihre Mindestbreite begrenzt automatische Tabellenbreiten.
Explizite Tabellenhöhen und Scrollbereiche beschreiben weiterhin nur das Raster;
Beschriftungen vergrößern den gemeinsamen Wrapper. Layout/TableCaptions verwaltet
diesen Bereich ohne die DOM-Struktur oder Eventzuordnung zu verändern. Frei
positionierte Captions und vollständige CSS-Tabellen-Blockifizierung fehlen.

`background-color` an tr/thead/tbody/tfoot wird schichtweise unter den Zellfarben
gezeichnet: Spaltengruppe, Spalte, Zeilengruppe, Zeile, Zelle. Die Fläche gehört
zur Ursprungszeile der Zelle, auch bei rowspan. Border-spacing bleibt frei und
zeigt den Tabellenhintergrund. Die passiven Hintergrundframes bleiben beim
Reflow erhalten; TableColumnPaint verwaltet gemeinsam alle vier unteren Schichten.

`empty-cells: show | hide` wird vererbt, Standard show. Bei separate verbirgt
hide den eigenen Rahmen und Hintergrund leerer Zellen. Entsprechend dem gelieferten
Browservergleich bleiben die darunterliegenden Zeilen-/Spaltenhintergründe sichtbar;
die mittlere Testzelle zeigt daher weiterhin das Hellblau des tbody. Das weicht
von der bisherigen, aus dem CSS-Tabellenmodell abgeleiteten vollständigen
Unterdrückung aller Schichten ab. Hintergrundflächen haben die Rasterhöhe, damit
vollständig ausgeblendete Zeilen keine Farbe in nachfolgende Zeilen zeichnen.
Kollabierte Leerzeichen und display:none-Inhalt zählen nicht als Inhalt; br,
erhaltene Leerzeichen, Bilder/Controls und in-flow Blockboxen dagegen schon.
Reine absolut positionierte Kinder machen die Zelle nicht gefüllt. Sichtbare
Kinder bleiben erhalten. Komplett leere hide-Zeilen haben Höhe null; gemischte
Zeilen behalten die Größenbedingungen ihrer Zellen. Bei collapse bleibt die
Eigenschaft wirkungslos. Border-Geometrie wird für die Spaltenmessung beibehalten.

Unterstützt sind `table`, `tr`, `td`, `th`, `thead`, `tbody` und `tfoot` im
separaten und zusammengefassten Rahmenmodell. `colspan` und `rowspan` verbinden mehrere Spalten/Zeilen,
auch gleichzeitig. `rowspan="0"` reicht bis zum Ende der aktuellen Zeilengruppe.
`th` ist standardmäßig fett und zentriert, `td` übernimmt die Textausrichtung.
Zellen haben 1px Standardpadding und vertikal mittige Inhalte. Autoren-CSS für
Zellrahmen, Padding, Farben, Schrift, text-align und vertical-align funktioniert
mit dem vorhandenen Box-/Textlayout.

`border-spacing` nimmt eine oder zwei nichtnegative Längen (px, em, rem, 0):
horizontal, dann vertikal. Der HTML-Standardabstand beträgt 2px. Abstände liegen
auch zwischen Randzellen und der Paddingkante der Tabelle. `border-collapse:
separate` ist der Standard. Bei `collapse` werden border-spacing und Tabellenpadding
ignoriert. Zellpadding bleibt erhalten; Prozentpadding verwendet in beiden
Layoutpässen dieselbe Tabellenbreite.

`Layout/TableBorders` löst gemeinsame Kanten aus Zellen, Zeilen, Zeilengruppen,
Spalten, Spaltengruppen und Tabelle auf: hidden unterdrückt die Kante, sonst gewinnen größere Breiten,
dann double/solid/dashed/dotted/ridge/outset/groove/inset, dann Zelle vor Zeile
vor Zeilengruppe vor Spalte vor Spaltengruppe vor Tabelle; gleiche Quellen werden von links/oben bevorzugt.
`none` verdrängt keinen sichtbaren Nachbarrahmen. Die Hälfte der gewonnenen
Breite gehört jeweils zur angrenzenden Zelle. Durch verbundene Zellen werden
keine inneren Linien gezogen. Ein `border-collapse` an einer Zelle ändert das
Modell ihrer Tabelle nicht; verschachtelte Tabellen können es überschreiben.

`Rendering/TableBorderPaint` zeichnet diese Kanten einmal über den Zellflächen.
Schnittflächen schwächerer Kanten werden ausgespart, damit halbtransparente
Kreuzungen nicht mehrfach zusammengesetzt werden. Ein Host ohne Fläche lässt
Hit-Tests der Controls durch. Die Rahmenobjekte werden beim Reflow wiederverwendet;
Muster können bei größerer Länge zusätzliche Poolobjekte benötigen. Inset/outset
werden hier als ridge/groove gezeichnet; Tabellen-/Zellrundungen entfallen.

Automatische Tabellenbreiten liegen zwischen dem kleinsten umbrechbaren Inhalt
und der Breite ohne Umbrüche, begrenzt durch den verfügbaren Platz. Untrennbare
Inhalte können eine Tabelle breiter als ihren Container machen. Explizite Breiten,
Prozentbreiten und min-/max-width werden für die Tabelle berücksichtigt; ihre
intrinsische Mindestbreite bleibt erhalten. HTML-Tabellen verwenden standardmäßig
border-box. Zellbreiten dienen der gemeinsamen Spaltenmessung, nicht als isolierte
Breite einer einzelnen Zeile. Zusätzlicher Platz wird zunächst gemäß den gemessenen
Spaltenbreiten, oberhalb der bevorzugten Breite gleichmäßig verteilt. Das ist ein
deterministischer Teilumfang des automatischen CSS-Tabellenalgorithmus.

`table-layout: fixed` mit einer angegebenen Tabellenbreite überspringt die
intrinsische Inhaltsmessung für die Spalten. CSS-width an `col`/`colgroup` hat
Vorrang vor der CSS-width von Zellen in der ersten visuellen Zeile. Eine Breite
an einer verbundenen Kopfzelle wird nach Abzug innerer Abstände gleichmäßig auf
ihre Spalten aufgeteilt; bereits durch col festgelegte Spalten behalten ihre Vorgabe.
Spalten ohne Breite teilen den Restplatz. Sind alle Breiten angegeben, verteilt
der Renderer zusätzlichen Platz gleichmäßig. Größere Spaltenvorgaben können die
Tabelle über ihre angegebene Breite hinaus vergrößern. Ohne Tabellen-width bleibt
auch mit fixed das automatische Layout aktiv. Pixel-/Prozentbreiten werden bei
Resize neu aufgelöst; lange Inhalte späterer Zeilen ändern die Spalten nicht.
Text bricht gemäß white-space/overflow-wrap um oder läuft gemäß overflow über.

`col` und `colgroup` sind reine Spaltendefinitionen, keine Flussboxen. CSS-width
auf einer Gruppe dient als Vorgabe pro Spalte; eigene col-Breiten überschreiben sie.
`span` wiederholt eine Spaltendefinition (1–1000). Bei colgroup mit col-Kindern
bestimmen diese Kinder den Umfang, nicht das span der Gruppe. Direkte col und
ausgelassene colgroup-End-Tags vor der nächsten Gruppe/Zeile sind möglich.
Definitionen können zusätzliche leere Spalten erzeugen; die Grenze bleibt 4096.
display:none entfernt eine Definition. Verschachtelte Tabellen lesen ausschließlich
ihre eigenen Definitionen. Veraltete HTML-width-/align-Attribute fehlen.

Spaltenvorgaben werden auch im automatischen Layout als Mindestbreiten verwendet.
Hintergrundfarben der Gruppe und Spalte liegen unter den Zellflächen; bei colspan
bestimmt die Startspalte den Hintergrund der gesamten Zelle. Schrift, Farbe des
Textes und text-align an col werden nicht an Zellen vererbt. Spaltenrahmen wirken
nur bei collapse. Column-Backgrounds behalten passive GUIs beim Reflow, ohne
weitere Layoutboxen oder neue Eingabesysteme. Beliebige Effekte/Opacity auf
Spaltendefinitionen gehören nicht zum Teilumfang.

Alle Zeilen benutzen dieselben Spaltenbreiten. Die größte Zellhöhe bestimmt die
Zeilenhöhe; kürzere Inhalte werden innerhalb der gestreckten Zellbox ausgerichtet.
`top`, `middle`, `bottom` und `baseline` sind umgesetzt. `thead` steht vor den
Körperzeilen, `tfoot` danach, ohne die DOM-Reihenfolge umzuschreiben. Direkte `tr`
ohne explizites `tbody` sind möglich. Verschachtelte Tabellen bleiben unabhängig.
Optionale End-Tags für Zellen, Zeilen und Zeilengruppen werden im üblichen
Tabellenkontext geschlossen. Es gibt keine vollständige HTML-Foster-Parenting-
Reparatur oder automatische Einfügung eines `tbody` in die DOM-Struktur.

`Layout/TableGrid` ordnet Zellen freien Spalten zu und reserviert die Slots ihrer
Zeilenverbindungen. Das Raster speichert je Spalte das Ende ihrer Belegung statt
einer vollständigen Zeilen×Spalten-Matrix. `colspan` wird wie HTML auf 1000,
`rowspan` auf 65534 begrenzt; fehlende/ungültige Werte und colspan=0 gelten als 1.
Überlange rowspans ergänzen implizite Rasterzeilen innerhalb ihrer Zeilengruppe,
ohne neue DOM-/GUI-Knoten. rowspan=0 berücksichtigt diese zusätzlichen Zeilen.
Zeilengruppen bleiben unabhängig. Pro Tabelle sind höchstens 4096 Spalten und
65534 Rasterzeilen zulässig; das gemeinsame Rahmenmodell ist zusätzlich auf
eine Million Rasterplätze begrenzt.

Verbundenen Zellen gehören auch die inneren Border-Spacing-Abstände. Zuerst werden
Einzelzellen gemessen, danach zusätzliche Min-/Max-Breiten und Höhen verbundener
Zellen auf deren Spalten/Zeilen verteilt. Die Verteilung ist monoton und erfolgt
deterministisch nach Spannweite und DOM-Reihenfolge. Grundlinie und vertikale
Ausrichtung beziehen sich auf die gesamte verbundene Zellfläche; die Grundlinie
bleibt der ersten belegten Zeile zugeordnet. Zellen behalten ihre ursprüngliche
GUI-/DOM-Zuordnung für Controls und Hit-Testing.

`Layout/TableLayout` sammelt die Zeilen, misst Min-/Max-Content pro Spalte und
berechnet Zeilen und Zellpositionen. `BlockLayout` rendert weiterhin Zellinhalte,
Rahmen, Größen und Überlauf. Tabellen bilden für DirtyLayout eine gemeinsame
Abhängigkeit: Änderungen in einer Zelle können alle Spalten betreffen. Eine
unveränderte Tabelle ohne Positionierungsabhängigkeiten kann beim Verschieben
als Ganzes wiederverwendet werden. Es gibt keine neue Frame-Schleife und keine
interaktiven Tabellen-GUIs.

`height` ist für Tabellen und Zellen eine Mindesthöhe. TableHeights verteilt
Zusatzhöhe auf die Zeilen, berücksichtigt prozentuale Zeilen-/Zellvorgaben und
gibt Restplatz bevorzugt an automatisch bemessene Zeilen. Intrinsische Minima
bleiben erhalten. Prozenthöhen nutzen eine bestimmte Elternhöhe; fehlt diese,
gilt auto. Zellnachfahren erhalten die endgültige Zellinhaltshöhe als Bezug.
Captions liegen weiterhin außerhalb dieser Rasterhöhe. Widersprüchliche
Prozentvorgaben werden innerhalb des verfügbaren Platzes angenähert; height an
Zeilengruppen wird ignoriert.

`visibility:collapse` entfernt Zeilen, Spalten und deren Gruppen samt zugehörigen
Abständen aus der sichtbaren Geometrie. TableTracks erhält zuvor ihre logischen
Inhaltsmessungen und projiziert das Raster auf die übrigen Tracks. Bei entfernten
Spalten werden verbundene Zellen auf den verbleibenden Bereich zugeschnitten.
Entfernte Zeilen verkleinern die Zellbox; overflow:visible lässt ihren Text weiter
unterhalb des Rahmens erscheinen, entsprechend dem gelieferten Browservergleich.
Explizites overflow:hidden schneidet ihn weiterhin ab. Gemeinsame Rahmen
werden an den neuen Nachbarschaften berechnet. Vollständig entfernte Zellen
tragen weder zur Scrollfläche bei noch nehmen ihre Controls Fokus an.
Außerhalb von Tabellen-Tracks verhält sich collapse wie hidden. Komplexe
Spans über ausgeblendete Ursprungszeilen bleiben ein begrenzter Teilumfang.

`display:table`, `table-row`, `table-cell`, `table-row-group`, `table-header-group`,
`table-footer-group` und `table-caption` funktionieren auch auf div/span.
Die Hierarchie muss ausdrücklich passende Tabellen-, Zeilen- und Zellrollen
enthalten. Es gibt keine vollständigen anonymen CSS-Tabellenboxen, kein
inline-table und keine generischen CSS-Spaltendefinitionen.

`direction:rtl` spiegelt die Spaltenanordnung und gemeinsamen Rahmen.
Bei gleichrangigen Rahmenquellen gewinnt horizontal die rechte statt linke
Quelle. start/end bei Textausrichtung folgen direction; logische Spaltenbreiten
und DOM-Reihenfolge bleiben erhalten. Vollständiger Unicode-Bidi-Textsatz,
writing-mode und RTL-Flexlayout sind nicht enthalten.

Margins an Zellen und Padding an Zeilen/Gruppen werden ignoriert.
Zeilen-/Gruppenrahmen gelten nur bei collapse. Vollständige Blockifizierung sowie
frei positionierte Tabelleninnenteile sind nicht umgesetzt. Dynamische CSS-
Änderungen benötigen einen Neuaufbau. Prozentpadding, komplexe Breitenkonflikte und spezielle
Overflow-/Flexkombinationen sind nicht browsergenau zugesichert. Bei collapse
reserviert der Tabellenaußenrand die maximale halbe Rahmenbreite über alle
Randzellen; unterschiedlich dicke äußere Seiten laufen dadurch nicht in die
Margins über. Tabellen ohne Rasterzellen zeichnen keine kollabierten Rahmen.
Gemischte Farben treffen rechteckig zusammen; Musterraster an Kreuzungen und
die Rundung angeschnittener Punkte sind angenähert.

Beispiel 31 in den synchronen Browser-/Studio-Demos enthält drei Spalten, einen
zweizeiligen Kopf mit jeweils einem colspan und rowspan,
gemeinsame 1px-Rahmen und umbrechenden Text. Die feste Spaltenaufteilung verwendet
100px, 20% und den Restplatz, mit Spaltengruppen- und Spaltenfarbe.
Beschriftung oben, Kopfgruppenfarbe und eine gefärbte Zeile ergänzen das Raster.
Eine kleine separate Tabelle darunter zeigt Beschriftung unten, tbody-/tfoot-Farbe
und eine leere hide-Zelle neben einer leeren show-Zelle.
Tests/TableExtras prüft Caption-Rahmen/-Breiten/-Umbruch, Vererbung, Nesting,
Hintergrundschichten mit rowspan, Leerzellen, Scrollen, positionierte Nachfahren,
Opacity sowie Übereinstimmung von Teil-/Voll-Layout und GUI-Wiederverwendung.
Tests/Tables prüft Maße, Ausrichtung,
Verschachtelung, Gruppenfolge, Parserfälle, Inhaltsänderungen und Layout-Wiederverwendung.
Tests/TableCollapse prüft gemeinsame Maße, Konflikte, hidden, Zellverbindungen,
verschachtelte Rahmenmodelle, eindeutige Pixelabdeckung, Hit-Tests und Pool-Erhaltung.
Tests/TableFixed prüft Breitenvorrang, erste Zeile/colspan, feste/prozentuale Breiten,
Überlauf, Resize, Verschachtelung, Farben/Rahmen, Parserfälle und Teil-/Voll-Layout.
Spätere zusätzliche Spalten werden gleichberechtigt verteilt; das ist im festen
CSS2-Algorithmus nicht definiert. Komplexe Prozentkonflikte bleiben angenähert.
Beispiel 33 zeigt Prozenthöhen, eine CSS-Tabelle in RTL, ausgeblendete Tracks
und überlange rowspans. Tests/TableAdvanced prüft diese Funktionen in beiden
Rahmenmodellen, Clipping, Inhaltsminima, Prozentkonflikte, Fokus und Scrollflächen.
DirtyLayout berücksichtigt Änderungen der bestimmten Elternhöhe im Cache.
Die Gesamtsuite vergleicht auch das Teil-/Voll-Layout der kompletten Demo.
Die Tests verwenden GUI-/Textmessungs-Mocks; der visuelle Studio-Abgleich bleibt nötig.

Referenzen: [CSS-Tabellenmodell](https://www.w3.org/TR/CSS2/tables.html),
[HTML-Zellverbindungen](https://html.spec.whatwg.org/multipage/tables.html#attributes-common-to-td-and-th-elements).
