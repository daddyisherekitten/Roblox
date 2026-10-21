# Dokumentparser und Attributnachweise

Stand: 6. Oktober 2026. Dieses Paket ersetzt die nachträgliche Sortierung des
HTML-Dokuments durch einen Tree-Builder und eröffnet den einzeln belegten
Attributabgleich. Es erklärt HTML nicht pauschal für vollständig.

## Parserpfad

`mountHTML`, `parseDocument` und HTML-`DOMParser` verwenden
[DocumentBuilder](../src/HTMLEngine/HTML/DocumentBuilder.luau). Dieser verarbeitet
Tokens in Einfügemodi: initial/html/head/body, Text, Tabellenabschnitte/Zeilen/
Zellen/Caption/Colgroup, Templates sowie Frameset-/Nach-Dokument-Zustände.
[TreeContext](../src/HTMLEngine/HTML/TreeContext.luau) besitzt Stack,
Formatierungsliste, Formzeiger, Template-Modi und begrenzte Knotenallokation.
Der Parser erzeugt Datenknoten. Der am 9. Oktober ergänzte Live-Pfad meldet
seine Mutationen an das bereits gemountete DOM; GUI-Arbeit bleibt beim Renderer.

- Implizite Dokumentknoten, Kopfmetadaten und doppelte html/body-Attribute werden
  beim Lesen verarbeitet. Kopf und Body werden nicht nachträglich umgeordnet.
- Absatz-, Überschrift-, Listen-, Button-, Form-, Ruby- und Optionsabschlüsse
  berücksichtigen den Stack und die passenden Scope-Grenzen.
- Falsch verschachtelte Formatierung verwendet Rekonstruktion, Noah's-Ark-Regel
  und den begrenzten Adoption-Agency-Algorithmus.
- Tabellen bekommen implizite Gruppen/Zeilen sowie Foster Parenting für
  unzulässige Kinder. Templates besitzen getrennte Content-Fragmente.
- SVG/MathML verwenden Namespaces, Integrationspunkte, Namens-/Attributanpassung
  und kontextabhängige CDATA-/Nullzeichenbehandlung.
- RAWTEXT/RCDATA, Script-Escape-/Double-Escape-Zustände, Plaintext, Kommentare,
  fehlerhafte Tags und Processing Instructions werden getrennt behandelt.
- [Doctype](../src/HTMLEngine/HTML/Doctype.luau) verarbeitet Namen, Public/System-
  Identifikatoren, fehlerhafte Enden und EOF mit Zuständen. Die Modusauswahl nutzt
  die präzisen Identifikatorlisten des aktuellen HTML-Standards. Layout-Quirks
  werden dadurch nicht vollständig implementiert.
- [Entities](../src/HTMLEngine/HTML/Entities.luau) verwendet alle 2.231 benannten
  Schreibweisen aus dem Standard, längstes Matching, Legacy-Semikolonregeln,
  Attributmehrdeutigkeit, numerische Referenzen und C1-Ersetzungen.

[Parser.parseFragment](../src/HTMLEngine/HTML/Parser.luau) verwendet denselben
Tree-Builder mit Elementkontext und Dokumentmodus. `innerHTML`, `outerHTML`,
`insertAdjacentHTML`, Shadow-HTML und die bestehenden Fragmentnutzer gehen über
[DOMMarkup](../src/HTMLEngine/JavaScript/DOMMarkup.luau) dorthin. Die frühere
zusätzliche Tabellenreparatur und die SVG-String-Umhüllung entfallen.
RAW-/RCDATA-Kontexte bleiben literal, fremde Namespaces und Formvorfahren werden
berücksichtigt. `Parser.parse` beziehungsweise öffentliches `parseHTML` behalten
ihren bisherigen allgemeinen Fragmentvertrag für bestehende Enginekunden.
Dieser ältere Vertrag ist nicht mit kontextuellem Browser-`innerHTML` gleichzusetzen.

Ladeabschnitte verwenden `WorkContext.checkpoint`. Byte-, Knoten-, Stack- und
Diagnostikbudgets bleiben begrenzt; rekonstruierte Formatierung und anfängliche
`selectedcontent`-Kopien zählen zum Allokationsbudget. Aufeinanderfolgende
Texttokens werden vor dem Einfügen gesammelt, um quadratische Verkettung bei
vielen ungültigen `<` zu vermeiden.

## Attributregister und reparierte Kombinationen

[html-attributes.v1.json](html-attributes.v1.json) enthält **277 Gruppen** aus dem
HTML-Attributindex, einschließlich **96 Eventhandlernamen** und einem `data-*`-
Mustereintrag. Jede Gruppe führt getrennte Achsen für Parsing, Reflexion,
Verhalten, Darstellung und Kombinationen. Leere Achsen bedeuten **nicht auditiert**.
Ein Nachweis benennt Testquelle, Fälle, untersuchte Elementteilmenge und Umgebung.
Globale Attribute werden im Parsingtest repräsentativ auf `div` geprüft;
`data-*` wird mit `data-audit` geprüft. Dies ist keine beliebige Elementmatrix.

| Achse | Gruppen mit ausdrücklich eingetragenem Nachweis |
| --- | ---: |
| Parsing/Erhalt | 277 |
| DOM-Reflexion | 41 |
| Verhalten | 36 |
| Darstellung/Geometrie | 19 |
| Kombinationen | 46 |

Diese Zahlen zeigen die Reichweite des neuen Audits, keine Anzahl sämtlicher
bereits vorhandener Enginefunktionen. Ältere Suiten können weitere Fälle belegen;
deren Zuordnung wird erst nach Sichtung eingetragen.

Konkrete Änderungen dieses Pakets:

- `input`-/`textarea`-`minLength` und `maxLength`, `input`-/`select`-`size` sowie
  `textarea`-`cols`/`rows` besitzen DOM-Reflexion mit passenden Defaults und
  WebIDL-Grenzen. Ungültige Setter werfen vor der Mutation; große unsigned Werte
  verwenden den vorgeschriebenen Fallback.
- [AttributeValues](../src/HTMLEngine/HTML/AttributeValues.luau) trennt HTML-
  Integerpräfixe von CSS-Zahlen und WebIDL-Konversion. Führende Leerzeichen/`+`,
  angehängter Text, Null, negative und ungültige Werte werden konsistent behandelt.
- Die Größenregeln erreichen tatsächliche ControlView-/BlockLayout-Geometrie.
  Ungültiges `size=0` verwendet den Default; ein `cols`-Attribut an einem input
  ersetzt dessen `size` nicht mehr.
- `maxlength` begrenzt nur passende Texttypen. Nutzereingaben berücksichtigen
  UTF-16 und erhalten Surrogatpaare; Scriptzuweisungen werden nicht abgeschnitten.
- Leere schreibgeschützte/disabled Texteingaben mit `required` bekommen keinen
  falschen `valueMissing`-Zustand.
- `spellcheck`-Reflexion berücksichtigt Vorfahren und gültige/ungültige/fehlende
  Werte. Dies implementiert keinen nativen Rechtschreibdienst.

Die Kombinationstests prüfen außerdem vorhandene Checked-/Selected-Dirty-Flags,
Reset, disabled Fieldset mit erster Legend-Ausnahme, explizite Formzuordnung,
Typfallback, geerbtes `translate` sowie Span-Reflexion. Sie prüfen reale DOM-/
Runtime-/Controlpfade. Geometrie verwendet GUI-Ersatzobjekte, keinen neuen
nativen Roblox-/Browser-Pixelvergleich.

## Referenzen und Prüfungen

[DocumentTree](../tests/DocumentTree.luau) besteht mit **1.508 Dokumentbäumen** und
**59 Kontextfragmenten** aus 46 offiziellen WPT-Dateien. Erwartungsbäume stammen
vom Upstream, nicht von unserer Engine. [Fixture](../tests/fixtures/html-document-tree.json)
nennt den festgehaltenen WPT-Commit und SHA256 jeder Quelldatei; die BSD-Lizenz
liegt neben der Fixture. Zusätzlich werden 21 Doctype-Zustands-/Modusfälle,
Budgets, ungültige Textfolgen und `selectedcontent`-Kopiebudgets geprüft.

[AttributeCatalog](../tests/AttributeCatalog.luau) besteht mit **1.564 reinen
Parsingfällen**. [AttributeCombinations](../tests/AttributeCombinations.luau)
prüft die oben abgegrenzten Wirkungs- und Geometriefälle. Der vollständige Lauf
bestand mit **257 registrierten Suiten** nach der Umstellung der DOM-Fragmentpfade.
Aufgezeichnete Browserfixtures in bestehenden Suiten bleiben historische native
Referenzen. In dieser Etappe wurde kein neuer nativer Browser-/Studiovergleich
durchgeführt. Native Darstellung und FPS bleiben beim Nutzer.

Die anschließende Projektprüfung bestand mit 857 Luau-, 76 JavaScript-, 41
Python- und 106 HTML-Dateien, 352 lokalen Ressourcenverweisen und sieben
Rojo-Konfigurationen. Alle 150 Dokumente sind zugeordnet; die 136 historischen
Originale bleiben bytegetreu erhalten. Referenzgeneratoren, 417 Cold-Loader-
Abhängigkeiten, das isolierte API-Register und der Studio-Rojo-Build bestehen.

```powershell
node scripts/run-html-tests.cjs DocumentTree AttributeCatalog AttributeCombinations
python scripts/import-html-tree-fixtures.py --check
python scripts/export-html-entities.py --check
python scripts/export-html-attributes.py --check
python scripts/check-html-attributes.py
python scripts/test-html-attributes.py
```

Generatoren halten Standardreferenzen und Testprovenienz getrennt von
Verhaltensnachweisen. Der Attributexport erhält manuell zugeordnete Belege nach
stabiler ID. Die Projektprüfung kontrolliert Belegpfade und benannte Assertions.
Die Aufteilung in `reviewedRequirements` bleibt im selben Register. Der Export
erhält alle fünf bisherigen Nachweisachsen und die vollständigen manuellen
Zuordnungen; geänderte oder verschwundene Gruppen werden nicht still ersetzt.
Die gespeicherten URL-/SHA256-Pins beider Katalogquellen müssen mit den tatsächlich
gelesenen Quellen übereinstimmen. Ein neuer Live-Stand wird damit nicht unter dem
Referenzdatum vom 6. Oktober übernommen. Dreizehn separate Werkzeugtests prüfen
Erhalt, fehlende Nachweise, präzise Elementteilmengen, dauerhafte Quellenpins und
den Abbruch vor dem Schreiben bei veränderter Provenienz. Das beweist die
Registerpflege, keine zusätzliche HTML-Funktion.

## Verbleibender Umfang

### Beauftragter Ausbau vom 8. Oktober 2026

Die folgenden Pakete bilden den weiteren Arbeitsumfang. „Offen“ bezeichnet
fehlende Umsetzung oder fehlenden Wirkungsnachweis; es ist keine Aussage,
dass die gesamte Familie bisher fehlt. Die CSS-Pakete stehen ausschließlich
im [CSS-Atelier-Profil](CSS-ATELIER-20261007.md#beauftragter-ausbau-vom-8-oktober-2026).

| Paket | Umsetzung und Abnahme | Status |
| --- | --- | --- |
| H01 Details | Exklusive nichtleere Namen pro DOM-Baum; Parser, Attributwechsel, Einfügen und native Aktivierung; verzögerte koaleszierte ToggleEvents; Mutation, CSS, GUI-Erhaltung und Abbau | Umgesetzt; Nachweise im [Details-Profil](DETAILS.md) |
| H02 Rich Select | Dynamisches `selectedcontent`, Kopieren der gewählten Option bei Wert-/Baumänderungen, Auswahl-/Resetpfade; Rich-Inhalte in der eigenen Selectdarstellung | In Arbeit: Behaltene Base-Dropdown-/Listboxpfade, anonymer Fallback, Rich-Inhalte, dynamische Picker-CSSOM-/Zustands-/Resetpfade und gemeinsame Anchor-/Fallback-Größen nachgewiesen. Genaue aktuelle Nachweise und Restfälle stehen im [Formularprofil](FORMS.md#rich-select-und-selectedcontent--8-oktober-2026). Weitere logische/transformierte/fragmentierte Optionen-/Anchorachsen, Effekt-/Ressourcenkombinationen und Studio-Abnahme bleiben offen. |
| H03 Parser und Schreiben | Inkrementelle Token-/Baumkonstruktion, Parser-Scripts am Einfügepunkt, `document.write`/`writeln`/`open`/`close`, Reihenfolge und Reentranz | In Arbeit: Unicode-Quellen, stückweise Dekodierung gewisser Bytequellen, dokumenteigene Schreibstreams, verknüpfte/importierte CSS-Ladebarrieren und CSSOM-Importänderungen samt retained Renderer; Srcdoc und eingefrorene Basisadressen ergänzt. Native Nachweise und genaue Restfälle stehen ausschließlich im [H03-Fachabschnitt](#h03-live-parser-und-dynamisches-schreiben--9-oktober-2026). Netzwerkzufuhr, tentative Kodierungswechsel nach Veröffentlichung und übrige Parsingkontexte bleiben offen. |
| H04 Zeichensätze | Bytequellen, BOM/Transport-/Meta-Sniffing, unterstützte Decoder, Dokumentzeichenkodierung und kontrollierter Neustart | Umgesetzt für ausdrücklich übergebene vollständige Bytequellen; inkrementelle Netzwerk-/Parserverknüpfung bleibt H03. [Umfang und Referenzunterschiede](JAVASCRIPT-TEXT-DATA-20261005.md#byte-decoder-und-html-zeichencodierung--9-oktober-2026) |
| H05 Fehlerkorrektur und Attribute | Zusätzliche normative Parserfälle und elementbezogene Attribute mit Reflexion, Verhalten, Darstellung, Kombinationen und Negativfällen im bestehenden Register | In Arbeit: gemeinsame Validierung, Dimensionshinweise, Formzuordnung, Eingabehinweise, Namespace-/Attr-Identität, Dokumentlisten/-zugriffe und inaktive Template-Dokumente mit Import/Adoption/Klonen ergänzt. Die genauen Nachweise und Restfälle stehen in den Fachabschnitten unten, der [Validierung](FORMS.md#gemeinsame-validierung-und-geöffnete-picker--9-oktober-2026) und dem [Dokumentprofil](JAVASCRIPT-DOCUMENTS-R02.md). Weitere Attribut-/Parserachsen und native Darstellung bleiben offen. |
| H06 Quirks | Dokumentmodus in die betroffenen Größen-, Prozent-, Tabellen- und Inlinepfade übernehmen; Standards/Almost Standards/Quirks getrennt vergleichen | In Arbeit: ID-/Klassenvergleiche, Hover-/Active-Sonderregeln, alte Längen/Farben, horizontale Prozent-/Dokumentgrößen, Inline-Struts, Whitespace, Inline-CSSOM-Geometrie und Tabellenprofil mit Dimensions-/Zeilengruppenänderungen ergänzt. 399 native Layoutszenen und 57 Inline-Geometrieszenen; weitere Tabellen-/Attributkombinationen und vertikale Layoutquirks bleiben offen |

Native Betriebssystemdienste, echte Dateiauswahl und Browser-GPU-Zugriff
bleiben die bereits dokumentierten Hostgrenzen. Ein bestandener Pakettest
ersetzt keine pauschale Browserkonformität. Nach jedem Paket werden dessen
Aufrufpfade geprüft und die betroffenen Regressionen ausgeführt.

Der H06-Selektorpfad ermittelt den aktuellen Eigentümer und Modus auch bei
abgetrennten oder adoptierten Teilbäumen. Nur ASCII-Großbuchstaben werden
gefaltet; Nicht-ASCII-Zeichen, Attributselektoren, `classList` und
`getElementById()` bleiben entsprechend ihrem eigenen Algorithmus exakt.
Klassen zerfallen ausschließlich an HTML-ASCII-Leerraum. Standards und Almost
Standards verwenden exakte ID-/Klassenvergleiche. `QuirksSelectors` vergleicht
vier echte Chromium-Dokumentsequenzen; `ScriptTransforms` prüft montierte
Farbänderungen, `:has()`, Nachbarschaften und gefilterte `nth-child()`-Regeln
mit behaltenen Flächen und ohne zusätzliche Layouts. Zusätzlich vergleicht
`QuirksSelectors` 18 Sequenzen mit echten Mausereignissen in Chromium:
Bare-/Universalzustände, Links, qualifizierte und funktionale Selektoren,
gefilterte Geschwister und Pseudoelemente. Die Quirksbeschränkung wird je
Compound beim Kompilieren erfasst; Argumente und das Compound eines
Pseudoelements sind ausgenommen. `HoverWork` prüft den montierten Wechsel
ohne zusätzliche Layouts oder neue Flächen. Die Referenz hält Chromiums
abweichendes Ergebnis für bloßes `:has(> :hover)` im Quirksmodus unverändert
fest; ein begründetes separates Standardergebnis folgt WHATWG Abschnitt 4.1.
Quelle: [Selectors 4](https://www.w3.org/TR/selectors-4/#id-selectors)
und [lebende Klassenlisten](https://dom.spec.whatwg.org/#concept-getelementsbyclassname),
[Hover-/Active-Quirk](https://quirks.spec.whatwg.org/#the-active-and-hover-quirk).

### Prozenthöhen und Dokumentgrößen – 9. Oktober 2026

`Layout/QuirksLayout` hält die historische Höhenbasis getrennt von der
gewöhnlichen bestimmten Elternhöhe. Automatische Blockcontainer reichen sie
weiter; Flex-/Gridcontainer und absolute automatische Container unterbrechen
sie. Bestimmte Größen und gestreckte absolute Container verwenden ihren
normalen Höhenpfad. Tatsächliche HTML-Wurzel und erster Body werden über
DOM-Position und Namespace identifiziert; bloß gleichnamige Elemente erhalten
keine Sonderbehandlung. Horizontale Root-/Bodygrößen füllen den verfügbaren
Bereich, berücksichtigen eigene Ränder/Kanten und wachsen mit dem Inhalt.

Das konkrete Browserprofil folgt Chromium auch bei prozentualen `min-height`
und `max-height` sowie deren Begrenzung impliziter Root-/Bodyfüllgrößen.
Insbesondere `html{max-height:200px}` und `body{max-height:200px}` können die
Füllgröße auf 200px begrenzen. Das unterscheidet sich von einer wörtlichen
Anwendung der WHATWG-Füllalgorithmen, die das größere Ergebnis aus normaler
Größe und Füllgröße verlangen. Diese gemessene Profilentscheidung ist keine
Behauptung browserübergreifender oder vollständiger Quirkskonformität.

`min-height` und `max-height` akzeptieren Prozentwerte im gemeinsamen Parser.
Bei unbestimmter normaler Höhenbasis entfallen Prozentminimum/-maximum;
ersetzte Elemente verwenden für vertikale Grenzen ihre Höhenbasis und nicht
die verfügbare Breite. Intrinsische Bild-/Blockproben führen den aktuellen
Quirkskontext mit, ohne alte platzierte Höhen wiederzuverwenden. Finale und
intrinsische Layoutcaches prüfen Modus und relevante Höheninputs bei Resize.

Der Abgleich hat zusätzlich zwei gemeinsame Fehler korrigiert: Rootränder
kollabieren nicht mit Nachfahren; leere Randketten behalten ihre größten
positiven und kleinsten negativen Anteile. Floats in verschachtelten normalen
Containern tragen zur automatischen Höhe ihres einschließenden Formatierungs-
kontexts bei. Seiten ohne Floats erhalten weiterhin den gewöhnlichen Cachepfad.
Vollständige Clearance-/Randkettenkombinationen sind damit nicht abgeschlossen.

`QuirksLayoutRendering` vergleicht inzwischen 399 echte Chromium-Szenen in Standards,
Almost Standards und Quirks. Größenwechsel und montierte Änderungen ergeben 7.659
Vergleiche kompletter Boxen (x/y/Breite/Höhe), einschließlich Root-/Bodykanten,
Grenzen, Prozentketten, Floats, Flex, Grid, Positionierung und ersetzter Bilder.
GUI-Identität und ausbleibende Layoutallokationen bleiben geprüft; unveränderte
Folgepasses nutzen den Cache bei dafür geeigneten Szenen. Gemeinsame mutable
Floatkontexte und externe Positionierungsabhängigkeiten bleiben konservativ.
Native Vorlagen: `tests/fixtures/quirks-layout-browser.json`; Reproduktion:
`scripts/capture-quirks-layout-reference.cjs`. Die verfügbaren Layoutbreiten
stammen aus den Browser-Layoutmetriken; reservierte Scrollbalken werden nicht
mit Elementbreiten oder dem CSS-Viewport verwechselt. Robloxobjekte werden
hier durch Ersatzobjekte geprüft; ein visueller Studioabgleich bleibt nötig.

Quellen: [Prozenthöhen](https://quirks.spec.whatwg.org/#the-percentage-height-calculation-quirk),
[Rootfüllung](https://quirks.spec.whatwg.org/#the-html-element-fills-the-viewport-quirk)
und [Bodyfüllung](https://quirks.spec.whatwg.org/#the-body-element-fills-the-html-element-quirk).
Vertikale Achsen bleiben offen; der ergänzte Tabellenumfang ist unten getrennt erfasst.

### Historische Inline-Struts und leere Inlineelemente – 9. Oktober 2026

Standards verwenden weiterhin den Strut des Blockcontainers. Almost Standards
und Quirks unterdrücken ihn; negative Halb-Leading-Werte der wirklichen
Textstücke bleiben erhalten, statt gegen einen künstlichen Null-Strut zu
klemmen. Bilder mit baseline/middle/top/bottom behalten damit im historischen
Modus keine bloß vom Elterntext kommende Zusatzhöhe. Ein echter Umbruch
bewahrt die Zeilenhöhe einer ansonsten leeren Zeile; zwischen zwei Bildern
erzeugt er keine zusätzliche Text-Strut-Höhe.

Direkt leere Inlineelemente und solche mit ausschließlich kollabierenden
Textleerzeichen haben jetzt einen eigenen leeren Layoutteil. Er
introduziert keinen Text, keine Glyphenmessung, kein Text-Emphasiszeichen und
keine Textschatten. Leerzeichen vor/nach ihm kollabieren weiter über die
Elementgrenze, behalten ihren ursprünglichen Platz und werden einmal verbraucht.
Seitenkanten bestimmen die historische Zeilenhöhenbeteiligung. Einfache
statische horizontale Padding-/Border-/Hintergrundfragmente benötigen dafür
kein ausdrückliches `box-decoration-break`. Horizontalen Rändern, komplexen
oder verschachtelten Dekorationen und positionierten Inlineelementen bleibt
vorerst ihr dokumentierter konservativer Darstellungsweg.

Die Erweiterung fügt 60 native Szenen hinzu: drei Modi, vier Bildausrichtungen,
Umbrüche, leere/paddierte Inlineelemente, Textpräsenz bei Nullschrift,
zusammenfallende Zwischenräume und erste Padding-/Hintergrund-Textfragmente.
Sie verwendet Nullschrift und explizite Zeilenhöhen, um die Modusregeln von
Roblox-Fontkalibrierung zu trennen. Die bestehende Font-/Zeilenregression prüft
zusätzlich signiertes Leading. Initiale Fragmentflächen dürfen beim ersten
Paint entstehen; nachfolgendes Resize erhält Boxen und Inline-/Blockbilder.
Nullschrift behält ihre Text-/Selektionsstruktur, malt aber auch bei Farbwechseln
keine nativen Glyphen, Schatten oder Emphasiszeichen. `pre`-Leerraum und
`pre-line`-Umbrüche werden nicht zu leeren Teilen umgedeutet.
Wortstücke und Fragmente mit echter Glyphenformung, tief verschachtelte
Whitespace-Inlinebäume und vertikale Paint-
Profile sind damit nicht vollständig nachgewiesen.

Quellen: [Inline-Zeilenhöhe](https://quirks.spec.whatwg.org/#the-line-height-calculation-quirk)
und [unterdrückter Block-Strut](https://quirks.spec.whatwg.org/#the-blocks-ignore-line-height-quirk).

Einfache Inline-Hintergründe liegen als behaltene Fragmentflächen unter Text
und Schatten. Verschachtelte einfache Hintergründe behalten ihre eigene
Transparenz über dieser Fläche. Innere und nachfolgende Quellleerzeichen
erweitern die Fläche nur auf derselben Zeile. Ellipsen kürzen die Textdarstellung,
erhalten aber die ursprüngliche Hintergrundbox hinter dem Overflow-Clip.
`Colors`, `Visibility`, `TextShadows`, `SmallElements`, `OverflowWrap` und
`TextOverflow` prüfen diese gemeinsamen Pfade; ihre früheren wortweisen
Hintergrundassertionen wurden durch Fragment-/Ebenenassertionen ersetzt.

### Inline-Geometrie – 9. Oktober 2026

`InlineGeometry` liest die behaltenen Zeilen, Fragmentflächen und Textquellen
für `getClientRects`, `getBoundingClientRect` und die Offsetmaße. Neutral
zusammengeführte Wörter verlieren dadurch ihre Span-Grenzen nicht. Kollabierter
Leerraum zählt zur ersten Quellposition; weitere Leerzeichen in leeren Spans
erzeugen keine zusätzliche Fläche. Prefixmaße werden pro Wort begrenzt gehalten.
Versteckte Inlineboxen behalten ihre Geometrie, `display:none` liefert keine.
Vorfahren-Transformationen und Scrollpositionen werden im vorhandenen gemeinsamen
Geometriepfad angewendet. Offsetmaße ignorieren Transformationen und umfassen
auch mehrere Zeilen ohne eigene Texthöhe; der erste Fragmentursprung bleibt
für offsetLeft/Top maßgeblich. Inline-clientLeft/Top sind trotz Rahmen null.

`InlineGeometryRendering` vergleicht 57 Chromium-Szenen in drei Dokumentmodi:
leere/Whitespace-Spans, Padding/Rahmen, Bilder, Textquellen, Umbruch,
visibility/display, transformierte Vorfahren und statische/positionierte Bodys.
462 wiederholte CSSOM-Abfragen erzeugen keine GUI-Objekte und fordern kein
Layout an. Nullschrift trennt die Geometrieprüfung ausdrücklich von nativen
Fontmetriken. Der separate Geometrieabgleich mit 14 Browserfällen besteht weiter.
Native Roblox-Pixel, reale Glyphenformung, tiefe Inline-/Blockverschachtelung,
Spaltenfragmente, Shadow-Verteilung und vertikale Geometrie sind hier nicht
vollständig nachgewiesen und bleiben eigene Ausbauachsen.

Die Rohreferenz bleibt unverändert erhalten: Chromium liefert bei mehreren
Nullhöhenzeilen die letzte Boundingbox; die Engine verwendet hier ausdrücklich
die erste, wie CSSOM View verlangt. Diese Fälle besitzen getrennte benannte
Standarderwartungen. Der historische statische Body-Offsetursprung folgt dagegen
dem gemessenen Chromium-Profil (Initial Containing Block); positionierte Bodys
verwenden dessen Borderursprung. Das ist keine pauschale CSSOM-Konformitätsaussage.
Quelle: [CSSOM View](https://drafts.csswg.org/cssom-view/#extensions-to-the-htmlelement-interface).

### Historische Tabellen – 9. Oktober 2026

Quirks-Zellhöhen verwenden jetzt die Borderbox, ohne dabei Zellbreiten auf
Borderbox umzuschalten. Prozenthöhen von Zellen/Zeilen/Gruppen verwenden keine
historische Viewport-Suche. Zell-min/max-height bleiben im gemessenen Chromium-
Profil ohne Größenwirkung. Automatische Spalten trennen Inhaltsminimum und
bevorzugte Zellbreite; eine deklarierte Zellbreite verhindert nicht länger
jede Verkleinerung. Für HTML-td/th mit `nowrap` und einer nichtnulligen CSS-
Längenbreite gilt im Quirks-Modus dagegen das historische Breitenminimum.
Direkt aneinanderliegende Inline-HTML-Bilder in automatisch breiten Zellen
besitzen beim historischen Min-Content-Probe keine zusätzlichen Umbruchstellen.
Quellleerzeichen, Blockbilder und ausdrücklich breite Zellen bleiben getrennt.

Tatsächliche HTML-Tabellen setzen im Quirks-Modus die normativen UA-Schrift-,
Zeilenhöhen-, Whitespace- und Ausrichtungswerte zurück, bevor Autorenregeln
wirken. Auszeichnungen von Vorfahren enden an der Tabelle; eigene bleiben.
Die UA-Tabellenfarbe kommt vom tatsächlichen HTML-body. CSS-`initial` bleibt
die gewöhnliche Initialfarbe; `inherit` und eigene
Farben erhalten ihre normale Kaskadenwirkung. Bodyfarbänderungen aktualisieren
auch Tabellen über ihre behaltenen Styles; die Prüfung fordert Paint ohne
Layout oder GUI-Allokation. Tabellenmesscaches berücksichtigen den Modus.

Die Referenz enthält 204 zusätzliche Tabellenszenen und sechs berechnete Stylewerte
pro vorhandenem Zielelement. Zwölf Abläufe ändern anschließend die Bodyfarbe.
Die bestehenden sieben Table-Suiten prüfen zusätzlich Spans, Grenzkonflikte,
Kollaps, RTL, feste Spalten und Teil-/Voll-Layout. `TableSpans` benennt jetzt
ausdrücklich Standards als Ausgangsmodus; sein historisches Höhengegenstück
wird separat gegen echte Browserdaten in allen drei Modi geprüft.

**Gemessene Profilabweichungen:** Chromium ignoriert bei leeren Tabellen ohne
Zeilen und ohne Rowgroup die bevorzugte Höhe, behält jedoch Padding und Border.
Leere Captions/Spalten verhindern dies dort nicht. Das unterscheidet sich von
WHATWG 3.10 (Height 0, Border none und andere Ausnahmen). Diese Engine folgt
hier dem gespeicherten Chromium-Profil; dies ist keine Behauptung vollständiger
normativer Quirks-Konformität. Prozenthöhen innerhalb von Tabellen bleiben
auch in der Quirks-Spezifikation teilweise UA-definiert.

HTML-Dimensionen an Bildern, Image-Inputs, Tabellen, Zellen, Zeilen/Gruppen,
Spalten/Colgroups und hr werden vor Autor-CSS aufgelöst. Der gemeinsame
HTML-Dimensionsparser nimmt einen dezimalen Präfix und ein unmittelbar folgendes
Prozentzeichen an; Zeichenfolgen wie `12e2` sind 12 px, nicht CSS-Exponenten.
Vorzeichen, führender Dezimalpunkt und Nicht-ASCII-Leerraum werden nicht akzeptiert.
Nullwerte werden bei Tabellenbreite und Zellenhöhen/-breiten ignoriert. Die
vorhandene Hostgrenze von 100.000 bleibt ausdrücklich bestehen. `revert`
verwirft diese Autor-Hints, `revert-layer` an Inline-CSS erhält sie. Elf
Präfix-/Negativfälle und fünf Rücksetzungen sind im tatsächlichen Stylepfad
geprüft; die Attributregisterachse benennt nur die dort untersuchte img-Teilmenge.

Das gemessene `nowrap`-Profil bleibt ausdrücklich Chromium: `nowrap` wird
als Autor-Hint behandelt; `revert` entfernt es. Ein nichtnulliges width-Attribut
ändert dort den berechneten nowrap-Wert nicht, obwohl HTML Rendering dafür im
Quirks-Modus einen normal-Hint und die UA-Regel nowrap beschreibt. Die Engine
folgt hier dem gespeicherten Browserprofil, ohne normative Vollständigkeit zu
behaupten. Native Breitenproben berücksichtigen die historische Zellminimum-Regel.

Rowgroups besitzen ein Mindestmaß über ihre Zeilen einschließlich innerer
Abstände. Automatische Zeilen nehmen zusätzlichen Gruppenraum vor festen
Zeilen auf; Prozentgruppen verwenden den tatsächlich verfügbaren Zeilenraum.
Leere Gruppen reservieren eigene Höhe ohne erfundene DOM-/GUI-Zeilen. Bei einem
Span über ausschließlich leere Zeilen liegt das notwendige Maß in der letzten
Zeile. Row-/Gruppenboxen liegen innerhalb der äußeren border-spacing-Abstände;
Zell-/Hintergrundpositionen bleiben relativ zu diesen korrigierten Boxen.
Die früheren relativen Tabellenassertionen wurden deshalb an die native Box-
Hierarchie angepasst; die unabhängigen Browsererwartungen blieben unverändert.

15 width-Wechsel und 24 Gruppenhöhenwechsel gehen durch behaltene Styles und
lokales Layout. Weitere 18 Farb-/Alphawechsel benötigen kein Layout oder neue
Hintergrund-GUIs. Der allgemeine Paintpfad aktualisiert auch native Zustands-
änderungen von Row-/Gruppen-/Spaltenquellen. Hintergründe behalten ihre GUI bei
gleicher Quelle; Struktur-/Quellwechsel entfernen nur entfallene Layer. Rowgroups
malen keinen zusätzlichen vollen Hintergrund über Abstände oder leere Fläche.
Eine isolierte Chromium-Pixelprobe bestätigt diese leere Gruppenfläche.

Beliebige verschachtelte Tabellen-/Prozentzyklen, weitere Span-Verteilungsfälle,
leere Gruppen mit komplexen Collapsed-Border-Interaktionen und vertikale Achsen
bleiben offene Umsetzung/Nachweise. Die CLI-Ersatz-GUIs belegen Geometrie und Identität,
keine native Roblox-Pixeldarstellung.

Quellen: [Tabellenquirks 3.8–3.13](https://quirks.spec.whatwg.org/#the-table-cell-width-calculation-quirk)
und [HTML-UA-Tabellenregeln](https://html.spec.whatwg.org/multipage/rendering.html#tables-2).

### Alte CSS-Werte – 9. Oktober 2026

`CSS/QuirkyValues` ergänzt die ausdrücklich festgelegten Eigenschaften um
einheitenlose Pixelwerte und Farben ohne Hash. Standards und Almost Standards
bleiben streng. Shorthands wie `background`, moderne logische Eigenschaften
und Funktionen wie `calc()` erhalten diese Erweiterung nicht; `clip: rect()`
ist die festgelegte Ausnahme. Zahl-, Dimension- und Identifierfarben werden
getrennt behandelt; Dezimal-/Exponentflags und ungültige Rechteckargumente
bleiben erhalten. Allgemeine Längen-/Farbparser werden nicht gelockert.

Der gemeinsame Pfad gilt für Stylesheets, Inlineattribute, Keyframes,
Variablenersetzung und schreibbare CSSOM-Deklarationen. `@supports` und
Import-Supports verwenden den Stylesheetmodus; `CSS.supports()` bleibt streng.
Ein bereits erstelltes Inline-CSSOM-Objekt behält seinen Parsemodus bei Adoption.
`QuirksValues` prüft 690 native Deklarations-/Supports-Proben über alle drei
Dokumentmodi sowie Variablen, Keyframes und Adoption. Die Rohreferenz in
`tests/fixtures/quirks-values-browser.json` dokumentiert sechs Unterschiede
von Chromiums direktem `setProperty`-Farbfastpfad; separate erwartete
Standardwerte verwenden die festgelegte Tokenregel. Reproduktion über
`scripts/capture-quirks-values-reference.cjs`; beide neuen Capture-Scripts
öffnen und schließen einen isolierten Headless-Browser.

Nullschrift und positive Bruchteile bis 100px werden akzeptiert. Nullglyphen
haben keine Ausdehnung und brauchen keinen nativen Messaufruf. Größere und
prozentuale Schriftgrößen sowie weitere Größenkeywords bleiben im Schriftprofil
offen; positive Roblox-Glyphen werden weiterhin auf native Größen gerundet.
Die 690 Proben belegen diesen konkreten Parser-/CSSOM-Umfang, nicht alle
CSS-Eigenschaften oder sämtliche Layoutquirks.

Quellen: [Quirky Lengths](https://drafts.csswg.org/css-values-4/#deprecated-quirky-length),
[Quirky Hex Colors](https://drafts.csswg.org/css-color-4/#quirky-colors).

1. Die **leeren Attributachsen** gezielt schließen: weitere Defaults, Reflexion,
   Aktivierung, Eingabe, Ressourcen, Darstellung und Kombinationen je Element.
   Legacy-Attribute, ARIA-Verhalten und SVG-/MathML-Attribute sind separate Umfänge.
2. Der unten belegte H03-Live-Pfad ergänzt parserbegleitende Scripts und
   `document.write`-Reentranz. Srcdoc-Sondermodus, Byte-/Netzwerkstreams,
   sowie das vollständige Zusammenspiel aller Ressourcen bleiben offen.
   Der neue vollständige Bytequellenpfad ergänzt Sniffing und einen begrenzten
   Neustart vor der Veröffentlichung; bestehende UTF-8-Strings bleiben unverändert.
3. Die importierten Dokument-/Fragmentfälle decken nicht sämtliche WPT-
   Tokenizer-, Streaming-, Encoding- und Scriptfälle ab. Vollständige
   Fehlercodes/-positionen sind ebenfalls nicht einzeln belegt.
4. Rich-`selectedcontent` verwendet jetzt dynamische tiefe Momentaufnahmen und
   erhaltene Inhaltsflächen unter `appearance:base-select`. Die verbleibenden
   Picker-, Größen- und Darstellungswechsel stehen im H02-Profil; die gesamte
   Customizable-Select-Familie ist noch nicht abgeschlossen.
5. Pixelgleichheit nativer Controls, alle historischen Layout-Quirks sowie
   XML-DTD-/Entity-Parsing und weitere XML-Konformitätsfälle sind gesonderte Arbeit.
   Der gemeinsame Namespace-Fixup und XMLSerializer sind mit ihren genauen
   Standard-/API-Grenzen im [Dokumentprofil](JAVASCRIPT-DOCUMENTS-R02.md#xml-namespace-fixup-und-serialisierung--10-oktober-2026) geprüft.

Normative Quellen: [HTML-Tree-Construction](https://html.spec.whatwg.org/multipage/parsing.html#tree-construction),
[HTML-Fragmentalgorithmus](https://html.spec.whatwg.org/multipage/parsing.html#html-fragment-parsing-algorithm),
[Attributindex](https://html.spec.whatwg.org/multipage/indices.html#attributes-3),
[Reflexionsregeln](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#reflecting-content-attributes-in-idl-attributes)
und [offizielle Web Platform Tests](https://github.com/web-platform-tests/wpt/tree/9710d2af7737513c93d823fddf364c36b2574c4c/html/syntax/parsing/resources).

## H03: Live-Parser und dynamisches Schreiben — 9. Oktober 2026

[DocumentBuilder.new](../src/HTMLEngine/HTML/DocumentBuilder.luau) behält
Tokenizer, Einfügemodi und offene Elemente zwischen Eingabeabschnitten.
Unvollständige Tags, Attribute, Entities und RAWTEXT-Enden werden bis zur
Fortsetzung oder zum tatsächlichen EOF aufgeschoben. Tabellenzeichen bleiben
bis zum folgenden Nichtzeichen-Token zusammen, damit Foster Parenting nicht
von der Stückelung abhängt. Der bestehende vollständige und kontextuelle Parser
verwendet weiterhin denselben Tree-Builder.

`mountHTML` mit aktiviertem JavaScript und einer decodierten Stringquelle pausiert
am ersten vollständig geparsten Script. [ScriptLoader](../src/HTMLEngine/JavaScript/ScriptLoader.luau)
setzt das Parsen nach klassischen Scripts fort; externe blockierende Quellen
pausieren den Parser. Async-/Defer-/Modulquellen gehen durch die bestehenden
Aufgaben- und Modulpfade. Frühe Scripts sehen spätere Elemente noch nicht.
Unvollständig geschlossene Scripts bei EOF werden nicht ausgeführt.

SVG-Scripts verwenden denselben Einfügepunkt und Ausführungsweg. `href` vor
`xlink:href`, selbstschließende externe Scripts und Async-/Modultiming sind
angebunden; die in SVG unbekannten Attribute `src`, `defer` und `nomodule`
ändern die Ausführung nicht. Das vollständige SVG-Script-Objektinterface ist
damit noch nicht nachgewiesen. Scripts eines inaktiven Schreibdokuments bleiben
auch nach späterer Adoption inert.

[DocumentStreams](../src/HTMLEngine/JavaScript/DocumentStreams.luau) implementiert
`write`, `writeln`, `open` und `close` für das aktive und für erzeugte HTML-
Dokumente. Einfügemarken überstehen verschachtelte Schreibvorgänge und Scripts;
CR/LF über Schreibaufrufe und die ursprüngliche Quelle wird normalisiert;
[InputStream](../src/HTMLEngine/HTML/InputStream.luau) erhält die Herkunft
normalisierter CR, damit zwei eigenständige CR nicht als CR/LF verschmelzen. Argument-
konversion findet vor dem Fehler-/Noop-Pfad statt. XML-Dokumente und synchrone
Parser-Custom-Element-Konstruktoren weisen dynamisches Schreiben zurück.
`open()` innerhalb eines Parser-Scripts bleibt ein Noop. Die Unterdrückung
destruktiver Schreibvorgänge externer/Modul-Scripts gilt auch nach Top-Level-Await;
ausdrückliches `open()` eines Async-Scripts kann einen neuen Schreibstream erzeugen.

Dokumentersetzung behält Document, Window-Realm und Seitencontainer. Verbundene
Listener werden gelöscht; Listener bereits abgetrennter Knoten bleiben erhalten.
Alte Skriptaufgaben und Resource-Abbrüche gehören zu einer Generation und können
die neue Dokumentgeneration nicht nachträglich fertigmelden. Parsermutationen
gehen über die vorhandenen Mutation-, Custom-Element-, Control-, Ressourcen- und
Reconcile-Pfade. Später geparste Styles ändern die vorhandene Darstellung.
Unbeteiligte Controls behalten Objektidentität und aktuellen Eingabewert.

Deklarative Shadow Roots werden am Template-Start erzeugt. Berechtigte Hosts,
vorhandene Roots und `disabledFeatures` werden berücksichtigt; der Templateknoten
bleibt dabei im Parserstack statt im Lichtbaum. Scripts im verbundenen Shadow-
Baum laufen mit `currentScript === null`, gewöhnliche Template-Inhalte bleiben
inert. Custom-Element-Konstruktoren sehen noch keine Parserattribute oder Eltern;
Attributreaktionen laufen vor der Einfügung und Verbindungsreaktionen vor späteren
Kindern. Namensprüfung und Hostberechtigung sind gemeinsam in
[ElementNames](../src/HTMLEngine/DOM/ElementNames.luau) definiert.

Nachweise: [50 Chromium-Referenzen](../tests/fixtures/document-streams-browser.json),
[DocumentStreams](../tests/DocumentStreams.luau) mit zusätzlich 22 bisherigen
Skriptfolgen, [DocumentStreamsRendering](../tests/DocumentStreamsRendering.luau)
mit echtem Parser/Runtime/Reconciler und deterministischen GUI-Hosts sowie
[DocumentTree](../tests/DocumentTree.luau) mit allen 1.508 vorhandenen Bäumen bei
je drei Stückelungen (1/7/31 Bytes: 4.524 Vergleiche). Der angebundene Test prüft
auch späteres Shadow-CSS, Objektretention und Entsorgung bei Dokumentersetzung.
Diese Nachweise sind kein Studio-Pixel-/FPS-Test.

Die SVG-Scriptquelle wird nach erweitertem Attributnamen gelesen: `href` ohne
Namespace hat Vorrang vor einem `href` im XLink-Namespace, unabhängig von dessen
Präfix. Nachträgliche Quellen an verbundenen, noch nicht gestarteten Scripts
lösen die Vorbereitung aus. Unverbundene und schon gestartete Scripts behalten
ihren bisherigen Lifecycle. Gleichnamige Attribute in einem fremden Namespace
oder ein nur wörtlich gesetztes `xlink:href` ohne Namespace bleiben inert.
Namespaceinformationen werden nach Validierung vor den Attributänderungsschritten
veröffentlicht; Ressourcenhooks sehen damit denselben Attributzustand wie das DOM.

### Srcdoc und eingefrorene Basisadressen — 10. Oktober 2026

Der reale IFrame-Mount übergibt `about:srcdoc`, die beim Mount erfasste About-
Basisadresse und `IsSrcdoc` an denselben Dokumentparser. Doctype-Varianten ändern
seinen No-Quirks-Modus nicht; Meta-Charset kann eine Unicode-Srcdoc-Quelle nicht
nachträglich umkodieren. `document.open`/`write`/`close` erhalten diesen Modus.
HTML-Dokumentmetadaten und JavaScript-`URL` verwenden denselben Recordparser und
dieselben Scalar-/Percent-Codecs; URL-Host-/IDNA-/Portfehler dürfen keine gültige
Basis vortäuschen. Der originfreie lokale Website-Katalog behält seinen
ausdrücklich getrennten Pfadvertrag.

Die erste teilnehmende `base[href]` friert ihre Adresse gegen die Fallbackbasis
ein. History-/URL-Änderungen und gewöhnliche Metadaten-/Textänderungen tauen sie
nicht auf. Wechsel des ersten Elements, `href`-Änderung einschließlich identischer
Zuweisung, Entfernung/Reinsertion und Adoption verwenden die üblichen DOM-Hooks.
Die `base.href`-Reflexion löst dagegen bei jedem Lesen gegen die aktuelle
Fallbackbasis auf, auch beim abgetrennten Element oder fehlendem Attribut.
Namespacierte `href`-Attribute wirken nicht als HTML-Basis; MutationRecords
enthalten ihren erweiterten lokalen Namen und Namespace. Der dokumenteigene
Cache hält keinen globalen Realm-/GUI-Besitzer und wird beim First-Base-Wechsel
ersetzt. Gewöhnliche Änderungen scannen nur tatsächlich editierte Subtrees auf
betroffene Basisnodes; ruhende Seiten benötigen keine Prüfzyklen.

Nachweise: [20 Srcdoc-Referenzen](../tests/fixtures/srcdoc-browser.json),
[Srcdoc](../tests/Srcdoc.luau), [sechs native Basis-Mutationsfolgen](../tests/fixtures/base-url-browser.json),
[BaseURLs](../tests/BaseURLs.luau), [isolierter Capture](../scripts/capture-base-urls.cjs),
[tatsächlicher Mountcontroller](../tests/IFrames.luau). Chromium verwendet bei
drei ungültigen Basisadressen `about:blank`; das aktuelle
[HTML-Frozen-Base-Verfahren](https://html.spec.whatwg.org/multipage/semantics.html#frozen-base-url)
verlangt die Fallbackbasis. Rohwerte und Standarderwartungen sind getrennt in
der Fixture gespeichert. Vollständige Browsing-Kontext-/Sandbox-/CSP-/Encoding-
URL-Regeln und Studio-Pixelabnahme sind damit nicht nachgewiesen.

### Festgelegte Bytekodierungen am Script-Einfügepunkt — 10. Oktober 2026

`Parser.newDocumentBytes` übernimmt die vorhandene Kodierungs-/Budgetprüfung.
Bei einer durch BOM, Transport oder ausdrücklichen Override bereits gewissen
Kodierung speist der gemeinsame Decoder die vorhandene Bytequelle stückweise
in eine echte Dokumentparser-Session. `HTMLPage` hält deren ersten Script-Einfügepunkt
vor GUI-Veröffentlichung an; ScriptLoader, Schreibmarker, Kopf-/Body-Sichtbarkeit
und spätere Ressourcen verwenden anschließend denselben Live-Pfad wie String-
Quellen. Kodierungsmetadaten stehen vor dem ersten Script bereit; spätere
widersprüchliche Meta-Charset-Deklarationen ändern diese gewisse Kodierung nicht.
Decoderzustand und kumulatives Ausgabebudget bleiben über Stückgrenzen erhalten.
Die Transport-Endmarke wird unabhängig von `document.write`-Einfügemarken geführt;
der echte EOF kommt erst nach dem letzten Dekoderstück. Quellen und Zustände
werden am Ende oder beim Seiten-/Realmabbau beziehungsweise Abbruch freigegeben.

[15 native HTTP-Bytefälle](../tests/fixtures/live-byte-documents-browser.json)
prüfen UTF-8, zwei UTF-16-BOM-Varianten, BOM-vor-Transport, Windows-1252,
sieben Mehrbyte-/Zustandsdecoder, ungültiges UTF-8, innere BOM, CR/LF-Stückgrenzen
und dynamisches Schreiben bei 1/7/4.096 Byte großen Decoderstücken;
[LiveByteDocuments](../tests/LiveByteDocuments.luau) vergleicht tatsächliche
Parser-/Runtime-Ausgaben. [PageLoading](../tests/PageLoading.luau) prüft den
wirklichen Mountzweig mit bestehendem Scriptadapter-Ersatz separat.
[DocumentStreamsRendering](../tests/DocumentStreamsRendering.luau) prüft den
echten Script-/Reconcile-/Controlpfad zusätzlich mit sieben Byte großen Stücken,
spätem CSS, Dokumentersetzung, GUI-Erhaltung und Abbau. Zukunftsbytes werden vor
dem ersten Script nicht vollständig dekodiert; spätere Ausgabeüberschreitungen
und kooperative Abbrüche schließen die Quelle ohne veraltete Fortsetzung. Die
30 bisherigen statischen Kodierungsfälle und sieben vollständigen Bytepaar-
Decodervergleiche bleiben unverändert bestehen.

**H03 bleibt offen:** Tentative Bytequellen verwenden weiterhin den vollständigen
begrenzten Reparse vor Scriptstart. Netzwerkzufuhr während des Mounts und ein
Encoding-Neustart nach Veröffentlichung sind nicht angeschlossen. Weitere SVG-Script-Interfaces,
Srcdoc-/Navigations-/Unload-Sonderfälle, Trusted Types und vollständige CSP-/Fetch-
Regeln sind weitere Anforderungen. Neuere Template-Patching-Regeln und sämtliche
WPT-Tokenizer-/Reentranzkombinationen sind noch nicht nachgewiesen. Diese Lücken
sind Arbeitsumfang, keine behaupteten Roblox-Unmöglichkeiten.

### Ereignisattribute und benannte DOM-Zugriffe — 10. Oktober 2026

[EventHandlerAttributes](../src/HTMLEngine/JavaScript/EventHandlerAttributes.luau)
bindet echte HTML-Quellen wie `onclick="…"` an denselben geordneten Handlerplatz
wie die IDL-Eigenschaft. Lesen oder Auslösen kompiliert die Quelle; identische
Attributzuweisung, IDL-Ersatz und Entfernung behalten die vorgeschriebene
Listenerreihenfolge. Syntaxfehler werden einmal gemeldet, löschen die unkompilierte
Quelle vor Fehler-Callbacks und erhalten den Listenerplatz. Eine Ersatzfunktion
aus einem Fehler-Callback wird erhalten. Attribute mit nichtleerem Namespace
werden nicht als Ereignishandler ausgeführt.

Der Interpreter verwendet lebende Objektumgebungen für Dokument, den bei
Kompilation ermittelten Formularbesitzer und Element, einschließlich
`Symbol.unscopables`, Methodenempfängern und lokalen Variablen. Body-/Frameset-
Weiterleitung, Window-`error` mit fünf Argumenten, normaler Rückgabewert `false`,
`beforeunload`-Stringkonversion, inert gewordene Quellen, Klonen, `document.open`
und Adoption zwischen zwei JavaScript-Reichen sind gezielt geprüft. Bereits
kompilierte Funktionen behalten ihr JavaScript-Reich; unveränderte rohe Quellen werden
nach Adoption im Zielreich kompiliert.

[DOMNamedProperties](../src/HTMLEngine/JavaScript/DOMNamedProperties.luau)
stellt die zugelassenen benannten Dokumentelemente und geerbte Window-Namen
bereit. ID-/Namenswechsel, Einfügen, Entfernen und Adoption invalidieren den
gemeinsamen Index; Text- und Farbänderungen tun dies nicht. Betroffene Namens-
Buckets werden sofort geleert, damit entfernte Elemente auch ohne weiteren
Namenszugriff freigegeben werden können. Das Dokument hält seinen datenreinen
Snapshot; der Runtime-Index hält Dokumente und lebende Duplikatlisten schwach.
Die Listen behalten ihre Identität über Speicherbereinigungen. Freigabe einer
Runtime entfernt ihren Snapshot, ohne Indizes anderer Reiche zu verändern.
Formulare haben
Indexzugriff, lebende `RadioNodeList`-Werte, Namenshistorie und Bild-Fallbacks;
Image-Buttons bleiben im Resetpfad, gehören aber nicht zu `elements` und den
benannten/indexierten Formzugriffen. Reflexion von `img.name` und `embed.name`
erreicht denselben Mutationspfad.

[40 native Sequenzen](../tests/fixtures/event-handler-attributes-browser.json)
und [EventHandlerAttributes](../tests/EventHandlerAttributes.luau) prüfen Werte,
Deskriptoren, Reihenfolge, Scope, Mutationen und Ressourcenabbau. 25 stimmen mit
der Browserreferenz überein; 15 konkrete Chromium-154-Abweichungen sind mit
unveränderter Browserreferenz und separater
Standarderwartung gespeichert: Lesen inaktiver Handler verwirft dort deren
Quelle; Formnamen überdecken dort vorhandene Expandos; Dokumentnamen besitzen
dort schreibbare Deskriptoren und überschreibbare/löschbare Plätze; XHTML- und
inaktive HTML-Dokumente lassen die geprüften Namen dort weg. Elf zusätzliche
Importfolgen erhalten dort die URL des Attributdokuments statt der vorgeschriebenen
null-Skriptzuordnung. Die Fixture hält dafür echte vertrauenswürdige Mausklicks
und die jeweilige Dokumentbasis fest. Grundlage sind
[HTML-Ereignishandler](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers),
[Dokumentnamen](https://html.spec.whatwg.org/multipage/dom.html#dom-document-nameditem),
[Window-Namen](https://html.spec.whatwg.org/multipage/nav-history-apis.html#named-access-on-the-window-object)
und [WebIDL-Namenssichtbarkeit](https://webidl.spec.whatwg.org/#dfn-named-property-visibility).

HTML-Handler behalten getrennt von der Fehlerquelladresse eine null-
`[[ScriptOrModule]]`-Zuordnung. Importieren ohne laufendes Aufruferskript verwendet
die aktuelle API-Basis ihres JavaScript-Reichs; ein vorhandenes Aufruferskript
bestimmt die Basis nach
[GetActiveScriptOrModule](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#sec-getactivescriptormodule).
Die normale HTML-Seitenintegration liefert diese Basis über ihren bestehenden
Metadatenpfad. Externe IDL-Funktionen behalten ihre eigene Skriptbasis. Geprüft sind
dynamische Basiswechsel, echte Hosteingaben, direkte Aufrufe und `eval`, zwei
Reiche nach Adoption, unterschiedliche Importmaps, getrennte Funktions-/Promise-
Reiche, `await`, Generator-Fortsetzung und Fehler vor Ressourcen-Disposal.
Skriptkontexte werden pro Funktion wiederverwendet und schwach pro Coroutine
verfolgt, damit suspendierte Stacks keine neuen Realm-Wurzelzyklen bilden.
Die VM stellt den Kontext an vorhandenen Ausnahmegrenzen wieder her;
sie fügt keinen zusätzlichen geschützten Aufruf für jede Funktion hinzu.

Dies schließt H05 nicht insgesamt. Vollständige CSP-/Trusted-Types-Regeln,
Quellpositionsdiagnostik, echte Browsing-Context-
Kindfenster/WindowProxy-Namensregeln, Sandbox-/Navigation-/Unload-Abläufe sowie
weitere Parser-/Attributkombinationen bleiben Arbeit. Ein gespeicherter
Handlername allein belegt nicht den nativen Erzeugungsmechanismus dieses Events.

### Globale Eingabehinweise und gemeinsame Formzuordnung — 10. Oktober 2026

[DOMReflection](../src/HTMLEngine/JavaScript/DOMReflection.luau) ergänzt
`autocapitalize`, `autocorrect` und `writingSuggestions` mit ihren tatsächlichen
IDL-Typen, Schlüsselwörtern, fehlenden/ungültigen/leeren Werten und Settern.
Autocapitalize und Autocorrect erben ausschließlich für die sechs im Standard
genannten Formelemente über deren Formbesitzer. URL-, Email- und Password-Inputs
geben für Autocorrect immer `false` zurück; ein Typwechsel wird unmittelbar
berücksichtigt. WritingSuggestions erbt beim fehlenden Attribut über
`parentElement`; ein eigenes leeres oder ungültiges Attribut aktiviert den Wert.

[FormOwner](../src/HTMLEngine/DOM/FormOwner.luau) ersetzt die mehrfach vorhandene
Formsuche in DOMControls, Control-State/FormModel und ElementInternals. Explizite
IDs werden im verbundenen eigenen Baum gesucht, auch innerhalb eines verbundenen
Shadow Root. Der erste gleichnamige Nicht-Form-Knoten blockiert eine später
folgende Form; explizite Zuordnung in einem abgetrennten Baum ergibt keinen
Besitzer. Die gewöhnliche Vorfahrenzuordnung in einer abgetrennten Form bleibt
erhalten. Der Parser erhält außerdem seine besondere Zuordnung zu einer
Nicht-Vorfahren-Form, beispielsweise bei Tabellen-Foster-Parenting. Sie gilt
für die sieben Standardelemente, wird nicht aus Fragmenten oder Klonen
übernommen und wird beim Trennen von Besitzer und Element, Adoption und
Formattributänderungen zurückgesetzt. Gemeinsames Verschieben des Teilbaums
und zustandserhaltende Verschiebungen im selben Baum erhalten die Zuordnung;
ein Wechsel des Shadow-Baums setzt sie unmittelbar zurück. Das registrierte
Besitzerindex besitzt ausschließlich schwache Elementschlüssel.

[FormOwners](../tests/FormOwners.luau) prüft **18 native Mutationsfolgen** samt
Formular-Daten und Reset über den gemeinsamen Control-Pfad. Zwei Rohabweichungen
bleiben separat erhalten: Chromiums DOMParser lässt eine Parserzuordnung aus;
moveBefore setzt sie auch beim Verbleib im selben Baum zurück. Die gesonderten
Erwartungen folgen dem aktuellen
[HTML-Konstruktionsalgorithmus](https://html.spec.whatwg.org/multipage/parsing.html#create-an-element-for-the-token)
und [Moving-Steps](https://html.spec.whatwg.org/multipage/infrastructure.html#html-element-moving-steps)
sowie dem
[Web-Platform-Test](https://github.com/web-platform-tests/wpt/blob/master/html/syntax/parsing-html-fragments/fragment-parse-form-owner-001.html).
Weitere Parser-/Namespace-/Attributkombinationen bleiben H05.

[GlobalAttributes](../tests/GlobalAttributes.luau) vergleicht **67 Szenen** mit
der [Chromium-Referenz](../tests/fixtures/global-attributes-browser.json):
Konversion einschließlich Symbolfehlern, echte HTMLElement-Deskriptoren und
Empfängerprüfung, Form-/Typ-/Elternwechsel, Duplikate, Shadow-/Detached-Bäume,
Adoption, formassoziierte Custom Elements, synchrone Reaktionen und
MutationObserver-Reihenfolge. Zwei Rohabweichungen bleiben separat erhalten:
Chromium vererbt WritingSuggestions über den Shadow Host und verzögert
Autocapitalize-Reaktionen. Die Engine folgt hier den aktuellen
[ParentElement-Regeln](https://html.spec.whatwg.org/multipage/interaction.html#attr-writingsuggestions)
und der [CEReactions-IDL](https://html.spec.whatwg.org/multipage/dom.html#htmlelement).
Das Attributregister ordnet nur Reflexion und die genannten Kombinationen zu.
Der tatsächliche HTMLScripts-/Rendererpfad lässt diese drei Attributänderungen
ebenfalls zu und erhält dabei den editierten Wert und das native Eingabeobjekt.
Autokorrektur, mobile Tastaturumschaltung und native Vorschlagsdienste werden
damit nicht als implementiert oder technisch unmöglich ausgegeben.

### Attributnamen, Namensräume und Objektidentität — 10. Oktober 2026

[AttributeStore](../src/HTMLEngine/DOM/AttributeStore.luau) trennt private
Speicherschlüssel von qualifizierten und erweiterten Namen. Gewöhnliche
HTML-Attribute behalten den direkten Lookup; verschiedene Namespace-/LocalName-
Paare können unabhängig denselben qualifizierten Namen verwenden.
DOMAttributes, öffentliche Attributgetter/-setter, Attr-Knoten, NamedNodeMap,
Dataset, Serialisierung, Custom-Element-Reaktionen und CSS-Attributselektoren
lesen diese Identität gemeinsam. Fremde Attribute ohne Präfix erhalten dadurch
keine HTML-Steuerwirkung für beispielsweise `disabled`, `type`, `style`,
`form` oder Ereignishandler.

`setAttributeNS` erhält den Präfix eines vorhandenen Attributes beim Wertwechsel.
Die beiden Attr-Setter ersetzen dagegen das Objekt mit gleichem erweitertem
Namen an seiner bestehenden Position. Neue Owner-/Objektidentität wird erst nach
Hostvalidierung und vor synchronen Reaktionen veröffentlicht. Reentrantes
Entfernen während einer Reaktion bleibt erhalten. `isEqualNode` vergleicht
Attribute nach Namespace, LocalName und Wert, unabhängig von Attributpräfix,
Reihenfolge oder privaten Speicherschlüsseln; Elementpräfixe bleiben relevant.
NamedNodeMap liefert zunächst alle Indexschlüssel und anschließend sichtbare
qualifizierte Namen. Großbuchstaben in diesen Namen werden bei HTML-Elementen
in HTML-Dokumenten aus dem benannten Eigenschaftszugriff ausgeschlossen.

[AttributeNamespaces](../tests/AttributeNamespaces.luau) prüft **34
Browsersequenzen**: 28 direkte Chromium-Erwartungen und sechs gesonderte
Standarderwartungen. Die
[Rohdaten](../tests/fixtures/attribute-namespaces-browser.json) bleiben erhalten.
Chromium behält bei zwei Attr-Ersetzungen einen veralteten Präfixlookup,
bevorzugt in einer Folge einen späteren gleichnamigen Nullnamespace-Attr und
ändert beim Dataset-Setter ein fremdes Namespace-Attribut. Die getrennten
Engine-Erwartungen folgen den
[DOM-Attributalgorithmen](https://dom.spec.whatwg.org/#concept-element-attributes-set),
dem [Nullnamespace beim Wertsetzen](https://dom.spec.whatwg.org/#concept-element-attributes-set-value)
und den [Dataset-Schritten](https://html.spec.whatwg.org/multipage/dom.html#dom-dataset).
Zwei weitere Rohabweichungen betreffen explizite HTML-/SVG-Präfixe und Rawtext
beim Serialisieren. Die Engine verwendet die vorgeschriebenen LocalNames und
Rawtextregeln; HTML-Voids samt Legacy-Voids überspringen Kinder auch beim
innerHTML-Getter. Importiertes CDATA und Processing Instructions folgen ebenfalls
dem [HTML-Serialisierungsalgorithmus](https://html.spec.whatwg.org/multipage/parsing.html#serialising-html-fragments).
XML-Dokumente und `XMLSerializer` verwenden den gemeinsamen iterativen
Namespace-Fixup. 63 native Datensätze, 126 Namespace-Roundtrips, Brand-/Realm-/
Fehlerprüfungen sowie erhaltene DOM-/Renderobjekte sind mit den getrennten
Standardabweichungen im [Dokumentprofil](JAVASCRIPT-DOCUMENTS-R02.md#xml-namespace-fixup-und-serialisierung--10-oktober-2026) dokumentiert.
Gleichheit und NamedNodeMap folgen dem
[DOM-Gleichheitsbegriff](https://dom.spec.whatwg.org/#concept-node-equals)
und den [unterstützten NamedNodeMap-Namen](https://dom.spec.whatwg.org/#dom-namednodemap).

Zusätzliche Runtimeprüfungen belegen unveränderte Attr-Owner bei zurückgewiesenen
Hoständerungen, gehaltene Map-/Attr-Identität und die Freigabe ungenutzter Elemente
und abgetrennter Dokumente ohne erneuten Zugriff.
[DocumentStreamsRendering](../tests/DocumentStreamsRendering.luau) prüft dieselben
Mutationen im tatsächlichen Renderer sowohl mit Unicodequelle als auch mit
stückweiser Bytedekodierung: editierte Controls bleiben erhalten; namespacierte
Farbselektoren ändern nur Paint und verursachen keinen Layoutaufruf. Gültige
eigene Attributnamen werden nicht mehr von einer Renderer-Positivliste blockiert;
auch ihr Hinzufügen und Entfernen erreicht denselben Selektorpfad.
Unveränderte Namespacewerte erhalten den lebenden Querysnapshot. Eine
tatsächliche Änderung invalidiert ihn und belastet die übliche VM-Schrittgrenze;
fremdes href invalidiert keine HTML-Link-Mitgliedschaft.
Dies schließt die genannten Identitäts- und Integrationsfälle, keinen
vollständigen H05- oder XML-/SVG-Attributabgleich.

### Dokumentzugriffe und gemeinsame Metadaten — 10. Oktober 2026

[DocumentAccessors](../src/HTMLEngine/DOM/DocumentAccessors.luau) verbindet die
namensraumabhängigen Regeln für `head`, `body` und `title` mit
[DOMDocuments](../src/HTMLEngine/JavaScript/DOMDocuments.luau) und
[DocumentInfo](../src/HTMLEngine/HTML/DocumentInfo.luau). Präfixe ändern die
HTML-/SVG-Elementidentität nicht. Head und Body benötigen ein HTML-html-
Dokumentelement und passende direkte Kinder; Frameset ist ein zulässiger Body.
Der Bodysetter prüft zuerst HTMLElement-Konversion und Hierarchie, erhält den
identischen Body ohne Mutation und adoptiert einen Ersatz über denselben
DOM-Mutationspfad. Ein HTML-Body kann unter einem fremden Dokumentelement
eingefügt werden, obwohl der Bodygetter dort weiterhin null liefert.

Der Titelgetter verwendet direkte Text-/CDATA-Kinder und kollabiert nur ASCII-
Whitespace. Beim SVG-svg-Dokumentelement gilt der erste direkte SVG-Titel;
sonst der erste HTML-Titel im Dokumentbaum, auch außerhalb des Kopfbereichs.
Der Setter aktualisiert das vorhandene Ziel oder erstellt es an der vorgesehenen
Position; unpassende Wurzeln bleiben nach DOMString-Konversion unverändert.
Seitenmetadaten wenden dieselben Titelregeln innerhalb ihres bereits vorhandenen
Baumdurchlaufs an. Präfixierte Base-/Meta-/Linkelemente verwenden die bisherigen
Adress-/Metadatenpfade, gewöhnliche Änderungen behalten den Metadatencache.

[DocumentAccessors-Test](../tests/DocumentAccessors.luau) belegt **34 native Folgen**
mit [erhaltenen Browserdaten](../tests/fixtures/document-accessors-browser.json),
zusätzlich Metadaten-/DOM-Gleichheit, ASCII-/NBSP-Grenzen und präfixierte
Adressquellen, Deskriptoren, Empfänger-/Konversionsfehler und synchrone
Custom-Element-Reaktionen bei Body-/Titelersatz. **27 Folgen stimmen direkt mit
Chromium überein; sieben**
erhalten dessen abweichende Head-Getter bzw. SVG-Descendant-Text-Ergebnisse
separat. Hier folgt die Engine den
[HTML-Dokumentzugriffen](https://html.spec.whatwg.org/multipage/dom.html#dom-tree-accessors)
und [Child-Text-Regeln](https://dom.spec.whatwg.org/#concept-child-text-content).
Der Paketreview fand außerdem einen echten Speicherfehler: der starke
DOMImplementation-Cachewert hielt über seinen Dokumentabschluss den schwachen
Schlüssel in Luau am Leben. Schwache Schlüssel und Werte erlauben jetzt die
Freigabe unbenutzter Factory-/Dokumentzyklen; gehaltene Implementierungen erhalten
weiterhin Eigentümer und Identität. Der neue GC-Test scheitert vor dieser
Korrektur und besteht danach, zusätzlich zum regulären Abbau.
Dieser Nachweis schließt die genannten Zugriffe; vollständige präfixierte
Elementsemantik im Renderer und weitere H05-Kombinationen bleiben offen.
XML-Serialisierungs-Fixup, XMLSerializer und ihre ausdrücklichen Standardgrenzen
sind im [Dokumentprofil](JAVASCRIPT-DOCUMENTS-R02.md#xml-namespace-fixup-und-serialisierung--10-oktober-2026) geprüft. Template-Eigentümer, Import/Adoption/Klonen,
Custom-Element-Aktivierung und Wechsel zwischen Runtime-Bridges sind mit 40
nativen Datensätzen und tatsächlichen Ressourcen-/Identitäts-/GC-Prüfungen im
[Dokumentprofil](JAVASCRIPT-DOCUMENTS-R02.md) nachgewiesen; neue Template-Patching-
Regeln und weitere CSP-/Trusted-Types-Kombinationen bleiben dort getrennt offen.

### Montierte Bild-, Canvas- und Mediennamen — 10. Oktober 2026

[HTMLExpandedResources](../tests/HTMLExpandedResources.luau) verbindet echte
`createElementNS`-Änderungen mit HTMLScripts, FormModel, Layout, CanvasRuntime
und ResizeObserver. Die [Chromium-154-Aufnahme](../tests/fixtures/html-expanded-resource-browser.json)
enthält sechs anfängliche Rechtecke, acht Observergrößen, zwei tatsächliche
Canvas-Pixelwerte nach Bildquellenwechsel, natürliche Bildmaße, Control-Captions,
fremde Attributkontrollen und Audio-Bedienelemente aus/an. Für Bild, Canvas,
Audio und Video folgen je drei Zustände mit Padding/Rand/Margin, Skalierung
und `border-box`: zwölf CSSOM-Rechtecke und zwölf unabhängige Contentgrößen.
Die Quelle und alle rohen Browserwerte bleiben gespeichert.

HTML-Namensraum und LocalName bestimmen Bild-/Canvasquellen und Medienart;
präfixierte HTML-Source-/Track-Kinder werden angenommen, gleichnamige fremde
und explizit namenlose Kinder nicht. Normale Inlineelemente erhalten dadurch
keine Replaced-Observergröße. Inline-Replaced-Items veröffentlichen ihre fertige
Border-/Contentgeometrie im Paintpfad; reine Größenproben verändern diese
veröffentlichten Koordinaten nicht. Farbänderungen am behaltenen nativen Control
verursachen kein Layout; Image-GUI und Caption-GUI bleiben bei Quellen- bzw.
Textänderungen erhalten, auch bei direkter `firstChild.data`-Änderung.

Audio ohne Bedienelemente entfernt seine alte Fläche und GUI. Der separate
Playbackbesitzer läuft weiter. [AudioHost](../tests/AudioHost.luau) prüft dies
für gewöhnliches und tatsächlich per DOM erzeugtes präfixiertes HTML-Audio:
Aus-/Einblenden, Entfernen/Wiedereinfügen und Pause erhalten denselben Sound
ohne erneutes Laden; Seitenabbau zerstört ihn genau einmal. Temporäre
Canvas-Bilddecodes und eigene Canvasflächen werden ebenfalls freigegeben.
Die neue Suite und **15 Nachbarsuiten** bestehen.

Dieser Nachweis verwendet Ersatzobjekte für Roblox-Assets/GUIs; er belegt keine
native Studio-Pixel-/FPS-Abnahme oder Webdownload-/Codecunterstützung. Die
Transformzustände prüfen CSSOM-/Observergeometrie. Der unabhängige Review fand
daneben einen separaten Paintpfadfehler. Dieser ist inzwischen im begrenzten
[Inline-2D-Profil](CSS-TRANSFORMS.md#eigene-2d-transformation-ersetzter-inlineflächen--10-oktober-2026)
behoben und mit tatsächlichen behaltenen Paintflächen geprüft. Weitergehende
3D-/Raster-/Fragment-/Trefferkombinationen bleiben dort offen.
Zum Stand dieser Aufnahme am 10. Oktober verwendeten gemeinsame
Video-HTMLMediaElement-IDLs noch den Audio-only-Empfängerpfad; Video-Controls/Src
wurden über echte Inhaltsattribute gesetzt. Der Nachtrag vom 11. Oktober
belegt inzwischen die sieben gemeinsamen IDLs. Adoptierte CDATA-Kinder und dynamische Kindlisten
nativer Button-/Output-Captions sind mit dem direkten Textnachweis ebenfalls
nicht geschlossen. Weitere Metadaten-/Namespace-/Scroll-/Shadow-/
Ressourcenkombinationen bleiben H05 offen.

### Lebende Dokumentlisten — 10. Oktober 2026

`document.images`, `embeds`, `plugins`, `links`, `forms` und `scripts` verwenden
die vorhandene HTMLCollection-Implementierung. Embeds und Plugins teilen
dieselbe Liste; Getter, Branding, Schreibschutz, Reihenfolge, ID-/Namenszugriff
und lebende Änderungen sind in
[DocumentCollections](../tests/DocumentCollections.luau) mit **12 nativen Folgen**
belegt. Nur passende HTML-Namensräume und LocalNames werden aufgenommen;
Template-Inhalte und Shadow-Bäume bleiben außerhalb der Dokumentlisten.

Dokumenteigene Mitgliedschaftssnapshots werden bei Elementstrukturänderungen
freigegeben. Href-Änderungen betreffen nur Links; reine Farben und Textinhalte
lassen die Snapshots erhalten. Ein schwacher Dokumentindex und schwache
Viewwerte vermeiden eine dauerhafte Bindung verworfener Dokumente. Prüfungen
im tatsächlichen Runtimepfad belegen erhaltene Listenidentität, entfernte
Elemente und abgetrennte Dokumente ohne weiteren Lookup, Garbage Collection
sowie vollständig freigegebene Snapshots beim Abbau. Diese Nachweise ersetzen
keinen vollständigen Abschluss aller Document- oder Attributinterfaces.

### Überschriftenoffset und Reset — 10. Oktober 2026

`headingOffset` reflektiert den nichtnegativen HTML-Zifferpräfix mit geklemmtem
Getterbereich 0–8. Der Unsigned-Long-Setter speichert seinen konvertierten Wert;
Getter-Clamping verändert den Inhaltswert nicht. `headingReset` reflektiert
boolesche Präsenz über denselben Attribut-/Reaktionspfad. HTML-Expanded-Names
besitzen die IDLs; fremde Elemente bestehen die Markenprüfung nicht.

Die berechnete Überschriftenebene summiert Offsets einschließlich des aktuellen
Elements und des ersten HTML-Reset-Ancestors, mit abschließendem Limit 9.
Ungültige negative Werte, Namespaced-Attribute und fremde Ancestors wirken nicht
als HTML-Offsets/Reset. Shadow-Roots führen zum Host; ein zugewiesener Slot
ersetzt die DOM-Ancestry nicht. ARIA-Ebenen bleiben vom HTML-Algorithmus getrennt.
Die Tagtypografie ändert sich durch einen semantischen Offset allein nicht.

[HeadingSelectors](../tests/HeadingSelectors.luau) prüft 35 experimentell native
IDL-Kontrollen, 26 rohe Accessibility-Kontrollen samt getrennten normativen
Erwartungen und Live-/Fehler-/Namespace-/Shadow-Kombinationen.
[Montierter Paint](../tests/JavaScriptCSSOMRendering.luau) erhält Labels,
Hintergrundflächen, Editor und Auswahl in neun Farbzuständen ohne Neulayout.
Gewöhnliches Chromium 154 hat diese IDLs und den Selectors-5-Selektor noch nicht;
die Aufnahme aktiviert ausdrücklich `HeadingOffset`. Drei Getter- und vier
Accessibility-Abweichungen bleiben im Originalfixture sichtbar.

Die eingefrorenen Indexlinks für beide Attribute zeigten irrtümlich auf
`tabindex`. Das vorhandene Attributregister bewahrt diese Originalreferenzen
als Korrekturprovenienz und verweist auf die
[tatsächliche Definition](https://html.spec.whatwg.org/multipage/sections.html#heading-levels-&-offsets).
Diese begrenzten Nachweise schließen H05/C01 insgesamt nicht ab.

### Lebende Bildkarten und Flächen — 11. Oktober 2026

Der Zielbestand verwendet die eingefrorene
[WHATWG-HTML-Quelle vom 6. Oktober](https://raw.githubusercontent.com/whatwg/html/ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c/source),
Commit `ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c` vom 6. Oktober 2026,
09:12:18 UTC; SHA256
`49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f`.
Die festgehaltenen Chromium-Ergebnisse bleiben von normativen Erwartungen getrennt.

Der DOM-Teil ist unabhängig geprüft:
[ImageMapsDOM](../tests/ImageMapsDOM.luau) vergleicht zehn fest benannte Fälle
exakt mit der [nativen Referenz](../tests/fixtures/image-maps-dom-browser.json).
[Die Aufnahme](../scripts/capture-image-maps-dom-reference.cjs) prüft den
Quellhash und verwendet einen getrennten Chromium-Prozess.

- `HTMLMapElement.areas` ist eine schreibgeschützte, lebende SameObject-
  HTMLCollection aus HTML-`area`-Nachfahren im Light-Tree. Präfixe beeinflussen
  den Expanded-Name nicht; fremde Namespaces, Template-Inhalte und Shadow-
  Nachfahren gehören nicht zur Liste. Normale andere Elemente behalten ihr
  gewöhnliches `areas`-Expandoverhalten.
- Reihenfolge, Einfügen/Entfernen, ID-/Namenszugriff und reservierte Listennamen
  verwenden die bestehende Collection-Implementierung. Import erzeugt eine
  eigene Liste; Adoption zwischen zwei lebenden Runtime-Bridges erhält die
  ursprüngliche Liste und deren Realm-Prototyp. Beide ausgeliehenen Getter
  liefern sie auch nach Hin- und Rückadoption; aktuelle Kindänderungen im
  Zieldokument bleiben sichtbar.
- `area.shape` reflektiert einen rohen DOMString, einschließlich leerer,
  ungültiger und großgeschriebener Autorenwerte. Die geometrische Bedeutung
  wird davon getrennt verarbeitet. Objektkonversion, Symbolfehler vor Mutation,
  Deskriptoren und gültige/ungültige Empfänger sind nativ abgeglichen.
- 38 `tabIndex`-Kontrollen belegen für HTML-`area` den Default
  `0`, unabhängig von `href`, Abtrennung oder Bildzuordnung. Das ist keine
  Zusicherung, dass eine unzugeordnete Fläche fokussierbar ist.
- Behaltene Listen und gecachte Methoden lehnen Reads nach Runtime-Abbau ab.
  Ein entfernter Nachfahr wird bereits vor dem nächsten Listenread freigegeben;
  auch ein unbenutzter abgetrennter Map-/Listenzirkel bleibt sammelbar. Beide
  Lebenszykluskontrollen besitzen eine unabhängige Plain-Object-GC-Kontrolle
  und laufen im vorhandenen isolierten Prüfpfad.

Die Änderung verwendet den vorhandenen Wrappercache und Collectionpfad. Es gibt
keinen zweiten Listen- oder Knotensnapshotcache. Der Review behob einen echten
Retainer: ein langfristig gehaltener Querycallback bewahrte sein letztes
Nachfahrenergebnis. Die Liste erzeugt deshalb nur für einen tatsächlichen Read
den aktuellen, budgetierten Queryscan. Acht betroffene Suiten und die
anschließende unabhängige Prüfung bestehen. Die zwei Attributgruppen `shape`
und `tabindex` erhalten im vorhandenen Register ausschließlich die belegten
Reflexions-/Kombinationsnachweise.

Der tatsächliche Renderer-/Eingabepfad ist mit
[ImageMapsRendering](../tests/ImageMapsRendering.luau) und einer getrennten
[nativen Aufnahme](../tests/fixtures/image-maps-browser.json) geprüft:
48 fest benannte Primärfälle enthalten 82 Zustände und 139 echte Pointerproben.
Die unveränderten Aktionen laufen im tatsächlichen JavaScript-/DOM-/RenderTree-/
Controllerpfad; Klickziel, Truststatus und verhinderte Navigation werden geprüft.
Die GUI-Ersatzobjekte erhalten native Koordinatenursprünge. Dies belegt Routing,
nicht native Studio-Pixel- oder Schriftgeometrie. 20 ergänzende geladene/defekte
Bildproben prüfen die CSS-Boxmaße und den Rahmenursprung gesondert.

- Lebende Zuordnung verwendet den ersten passenden HTML-Map-Namen oder die ID
  im Light-Tree-Root des Bildes. Umbenennen, Löschen, Reihenfolge, `useMap`,
  Namespaces und getrennte Shadow-Roots ändern aktuelle Treffer. Die geometrische
  Verarbeitung bleibt von der rohen `shape`-Reflexion getrennt: Rect/Circle/Poly,
  alte Schlüsselwörter, Grenzen und die erholende Koordinatenliste besitzen eigene
  Kontrollen. Fehlendes `href` macht die zuerst passende tote Fläche nicht zu
  einem Durchlass für eine spätere Fläche.
- Acht ausdrücklich benannte Zustände unterscheiden normativ erforderliche
  Default-Reihenfolge vom Chromium-Ergebnis. Die Rohdaten bleiben unverändert;
  15 zusätzliche native Vollrechteckproben bilden unabhängige Gegenkontrollen.
  Dieser Unterschied wird nicht auf andere Reihenfolge- oder Fokusfälle übertragen.
- 13 native Tastaturzustände und zwei AREA-Platzierungsfolgen prüfen begrenzte
  Tab-/Enter-Ziele; zwei zusätzliche IMG-`tabindex`-Folgen erhalten den allgemeinen
  Bildfokus. Vier Drücken-/Mutieren-/Loslassen-Folgen vergleichen die tatsächlichen
  Pointer-/Klickereignisse. Vier Fragmentnavigationen und sieben synthetische
  Klickfälle prüfen Aktivierung, Verhinderung, leeres/fehlendes `href`, prefixed
  HTML-A/AREA und exakt einen Klick mit `isTrusted=false`.
- Gewöhnliche Map-Kinder nehmen am normalen Text-/Blockfluss teil; AREA erzeugt
  keine Layoutbox. Sechs native Sichtbarkeitszustände und tatsächliches Hinzufügen
  von Text prüfen gemischte Inhalte und erneutes Anzeigen. Reine verschachtelte
  AREA-Änderungen behalten die sichtbaren Kinder und Bilder. Weitere montierte
  Einfüge-/Verschiebe-/Entfernungskontrollen für verschachtelte Maps/Bilder betreffen
  Light- und Shadow-Tree.
- Map-/Shape-Datenmutationen erhalten Editor, Fokus, Wert, UTF16-/Byte-Auswahl und
  Bildflächen. Spies belegen dabei keine Bildauflösung/-Aktualisierung, kein Layout
  und keine neue GUI. Gewöhnliche Counter-Textwechsel außerhalb Maps lösen keinen
  Zuordnungsscan aus. Nur geänderte Teilbäume werden auf maximal 256 eingereihte
  Knoten klassifiziert; breite Änderungen und unbekannte Children-Metadaten fallen
  konservativ zurück. Es gibt keinen Idle-Frame-Scan.
- Der virtuelle Shape-Cursor verwendet eigene AREA-Selektoren und IMG-Vererbung;
  die normale DOM-CSS-Berechnung bleibt erhalten. Vererbte/ausdrückliche Werte,
  Variablen, CSSOM und Hover sind gegen den eingefrorenen Shape-Vertrag geprüft.
  Acht unveränderte Bewegungen wiederholen weder Zuordnungsscan noch Cursor-Kaskade.
  Zwei native Inert-Fallthrough-Kontrollen prüfen die passende Cursorlease.
  Native DOM-Computed-Styles sind kein OS-Shape-Cursor- oder Screenshotnachweis.
- Entfernte AREA-/MAP-/IMG-Referenzen werden unmittelbar aus dem Index gelöst;
  dessen letzter Cursor und Bindings verschwinden beim Abbau. Montierter Runtime-/
  Controllerabbau prüft wartende Timer/Frames und Cursorlease. Die GC-Kontrolle
  hält einen Unit-Index und einen unabhängigen Plain-Object-Sentinel in einer
  beendeten Erzeugungs-Coroutine; sie ist kein retained HTMLPageSession-Test.
  Der tatsächliche HTMLPage-Cleanupanschluss ist zusätzlich im Quellpfad geprüft.

Neun gezielte Suiten bestehen. Beide Bildkarten-GC-Prüfungen laufen im vorhandenen
isolierten Prüfpfad mit unveränderten Sentinels und Allokationsbudgets: der frühere
Nachbarlauf sammelte auch den unabhängigen Plain-Object-Sentinel nicht. Dies ist
als Harness-Heapeinfluss erhalten, nicht als behobener Engine-Retainer ausgegeben.
Zwölf Suiten bestehen zusätzlich in der unabhängigen Endprüfung bei unveränderten
Prüfsummen der 13 gehaltenen Renderer-/Test-/Fixture-/Aufnahmedateien. Die sechs
betroffenen Attributgruppen und der vorhandene AREA-/IMG-`tabindex`-Eintrag erhalten
ausschließlich die belegten Wirkungs-/Darstellungs-/Kombinationsachsen; der globale ID-Nachweis ist dabei ausdrücklich
auf Maps begrenzt. Der elfte Gesamtlauf bestätigt diesen Umfang mit tatsächlichem
Exit 0: 352 registrierte Suiten einschließlich der zwölf isolierten GC-Prüfungen.
Die anschließende Snapshotkontrolle bestätigt unveränderte 1.648 Quell-/Test-/
Fixturedateien und sieben Rojo-Projekte. Projekt-/Registerprüfung, API-/CSS-
Exportchecks und drei Rojo-Builds bestehen. Das Rohprotokoll
`build/html-full-20261011-eleventh.log` und das Hauptbundle
`build/html-tests-5856.luau` bleiben erhalten.

Offen bleiben Überleben nach Zerstörung des ursprünglichen Realms, vollständige
Fokus-/Browserchrome-/Mehrbildreihenfolge, stationäre Hover-/Boundary-Ereignis-
Zeitpunkte, beliebige Transform-/Fragment-/Object-Fit-/Shadowkombinationen,
vollständige Floating-Point-/degenerierte Polygongrenzen und native Studio-Pixel/
FPS. Sieben stationäre Chromium-Rohzustände bleiben separat erhalten; die aktive
Engine-Geometrieaktualisierung wird nicht als deren exakte Zwei-Frame-Parität
ausgegeben. Die begrenzten Nachweise schließen H05 nicht insgesamt.

### Verknüpfte Stylesheets und Skriptbarrieren — 9. Oktober 2026

[StylesheetResources](../src/HTMLEngine/JavaScript/StylesheetResources.luau)
nimmt decodierte Hostquellen über `JavaScriptServices.LoadStylesheet(url,
complete, context)` an. Die Completion enthält eine CSS-Zeichenfolge oder
`{Source, MIME?, OriginClean?, URL?}`; Rückgabe einer Abbruchfunktion ist möglich.
`options.Stylesheets` bleibt der sofort verfügbare Paketquellenpfad. Kein
automatischer HTTP-Zugriff wird dadurch zugesichert.

Ein Requestgraph gehört zum Link-/Styleknoten. URL-/Rel-/Type-/Disabled-Änderungen,
Entfernung und Dokumentersetzung lösen seine bisherigen Jobs ab. Späte
Completions können weder dessen neue Quelle noch eine neue Dokumentgeneration
ändern. Parsererstellte, bei Erstellung aktivierte und passende Blätter halten
klassische Parser-Scripts und Defer-/Modulscripts zurück. Async-Scripts und
dynamisch eingefügte Blätter verwenden ihre eigenen Abläufe; ausstehende
verbundene CSS-Requests verzögern `load`. Nach erfolgreicher Completion teilen
CSSOM und Renderer dieselbe Quelle; Editoren und vorhandene Flächen bleiben erhalten.

Die Hostmetadaten steuern den Origin-clean-Regelschutz. Ein nicht freigegebenes
Blatt bleibt darstellbar; `cssRules`, `rules`, `insertRule` und `deleteRule`
werfen `SecurityError`. Die Berechnung tatsächlicher CORS-/Fetch-Rechte gehört
weiterhin zum Transporthost. MIME-/Quellenbudgets werden geprüft.

[33 native HTTP-Szenen](../tests/fixtures/stylesheet-loading-browser.json) und
[StylesheetLoading](../tests/StylesheetLoading.luau) prüfen Skriptentscheidungen,
Bereitschaft, Fehler, URL-Wechsel, CORS-Regelzugriff und Shadow-Ressourcen.
Die Tests vergleichen semantische Werte und erforderliche Abhängigkeiten;
eine vollständige Reihenfolge unabhängiger Netzwerk-/Render-Tasks wird nicht
aus einem einzelnen Browserlauf abgeleitet. Sechs konkrete Unterschiede bleiben
mit Originalreferenz und gesonderter Standarderwartung erhalten: Chromiums
leeres Fehlerblatt, Annahme der getesteten Same-origin-`text/plain`-Antwort,
frühe Freigabe nach URL-Wechsel, zusätzliche Shadow-CSS-Parserblockade,
ein leeres Importblatt trotz falscher Supports-Bedingung und getrennte MediaList-
Objekte für Importregel und importiertes Blatt.
Grundlage ist der aktuelle HTML-Algorithmus für
[Stylesheet-Links](https://html.spec.whatwg.org/multipage/links.html#link-type-stylesheet)
und [Scriptblocking](https://html.spec.whatwg.org/multipage/semantics.html#interactions-of-styling-and-scripting).

Der angebundene [Renderertest](../tests/DocumentStreamsRendering.luau) prüft
geladenes CSS, anschließendes `sheet.insertRule`, Input-/GUI-Retention, entfernte
alte Styles beim URL-Wechsel sowie Abbruch und verspätete Ergebnisse bei
Dokumentersetzung. [StylesheetGraph](../src/HTMLEngine/JavaScript/StylesheetGraph.luau)
lädt kritische Imports rekursiv für verknüpfte und inline Blätter. Relative URLs
verwenden die Response-Basis, während `sheet.href` die erste Request-URL behält.
Falsche Supports-Bedingungen laden nicht; Medienbedingungen begrenzen die
Darstellung. Zyklen tragen kein zweites Blatt bei. Importfehler lösen die Barriere
und melden den Besitzerfehler; gültige Elternregeln bleiben erhalten. Tiefe,
Requests und decodierte Gesamtbytes sind begrenzt. Abgelöste Graphen können
auch nach einer kooperativen Pause keine neuen Jobs oder alte Quellen publizieren.
Importblätter besitzen eigene Identität, `parentStyleSheet`, `ownerRule` und
Origin-clean-Prüfung. Änderungen ihrer Regeln, ihres Disabled-Zustands und der
Import-Medienliste erreichen den behaltenen Renderer; verschachtelte Änderungen
erhalten GUI und Eingabewerte. Die Regeln folgen
[CSS Cascade Imports](https://drafts.csswg.org/css-cascade-5/#at-import) und
[CSSOM Importregeln](https://drafts.csswg.org/cssom/#css-import-rule).

`insertRule` startet Importrequests asynchron; `deleteRule` gibt ausstehende
Untergraphen frei. Die 33 Szenen enthalten zwei erhaltene Chromium-Timeouts
nach dem Löschen noch ladender Imports. Das Abbruchprofil der Engine lässt
den Parser fortschreiten; diese Erwartung wird ausdrücklich vom beobachteten
Browserlauf getrennt. Späte Hostcallbacks bleiben wirkungslos. Ein bereits
fertiges, nur noch in der Ereignisqueue wartendes Besitzerereignis kann auch
nach Entfernen des Knotens ausgeliefert werden. Gehaltene entfernte Importblätter
behalten ihre Identität und OwnerRule, verlieren aber die ParentStyleSheet-Verbindung.
Der tatsächliche Renderertest prüft Einfügen, Löschen, vorherige Kaskade,
Abbruch und verspätete Completion mit unveränderten Box-/Editorobjekten.

Die Runtime unterscheidet die eigene script-blocking Stylesheet-Menge von der
Barriere des unmittelbaren Containerdokuments. Eingebettete Parser-/Defer-/Modul-
Scripts warten auf diese Menge; Async-Scripts bleiben unabhängig. Eine Barriere
des Großelterndokuments wird nicht versehentlich rekursiv weitergereicht.
HTMLPage schützt auch die anfängliche Phase vor dem Start der Parent-Runtime.
Abonnements wecken wartende Kinder nur bei Änderungen und werden beim Abbau
freigegeben. Die aufrufende Seite wartet für ihren `load` auf ausstehende Mounts
und noch nicht abgeschlossene Kinddokumente. Das Frame-`load` folgt den eigenen
Load-Handlern und Microtasks des Kindes; Dokumentersetzung veröffentlicht nur
die gültige Generation. Ressourcenhosts werden geerbt, eigene Websiteoptionen
behalten Vorrang. Ein Dokument ohne Script-Tags bekommt ebenfalls die Runtime-
Ressourcenanbindung, wenn ein `LoadStylesheet`-Host konfiguriert ist.

[Zehn weitere native HTTP-Szenen](../tests/fixtures/stylesheet-embedded-browser.json)
und [StylesheetEmbedded](../tests/StylesheetEmbedded.luau) prüfen zwei echte
Parser/Realms. Chromium lässt die getesteten `srcdoc`-Scripts bereits vor dem
Parent-Stylesheet laufen; diese Originalreihenfolge bleibt separat von der
aktuellen HTML-Containerbarriere erhalten. Die Tests vergleichen erforderliche
Abhängigkeiten statt einer vollständigen zufälligen Task-Reihenfolge.
[IFrames](../tests/IFrames.luau) prüft zusätzlich den tatsächlichen Mountcontroller,
Load-Zähler, Optionsweitergabe, Entfernung und ausbleibende veraltete Ereignisse.
Dieser Nachweis ersetzt keine vollständigen `contentWindow`-/`parent`-Interfaces,
Navigations-, Sandbox- oder Studio-Abnahme.

HTML- und SVG-`style` verwenden denselben Besitzerpfad nach Namespace und lokalem
Namen, einschließlich `h:style` und `s:style`; fremde und ausdrücklich
namespacelose Elemente bleiben inaktiv. SVG-Besitzer reflektieren `type`, `media`
und `title` und besitzen `sheet` und `disabled`. Die CSS-Quelle enthält nur
direkte Text- und CDATA-Kinder. Direkte Kindlisten-/CharacterData-Änderungen
ersetzen das zugeordnete Blatt auch bei identischer Zeichenfolge; Änderungen
an Enkeltext ersetzen es nicht. Ein echter Blockupdate setzt über die vorhandene
Ressourcengeneration auch CSSOM-veränderte Importgraphen zurück und bricht alte
Requests ab. Die gemeinsamen Helfer führen keinen zusätzlichen globalen
Besitzerindex ein. Grundlage sind
[SVG2-Styleelemente](https://www.w3.org/TR/SVG2/styling.html#StyleElement),
[HTML-Styleblockupdates](https://html.spec.whatwg.org/multipage/semantics.html#update-a-style-block)
und [direkter DOM-Kindtext](https://dom.spec.whatwg.org/#concept-child-text-content).

[SVGStyleOwners](../tests/SVGStyleOwners.luau) vergleicht 233 gespeicherte native
DOM-/CSSOM-/Namespace-/CDATA-Zustände anhand ausdrücklich ausgewählter
Eigenschaften. SVG innerhalb und außerhalb von SVG, Shadow-Roots, eigenständige
SVG-XML-Dokumente und HTML-Kontrollen sind enthalten. 18 weitere native
Farbzustände werden im echten montierten Renderer mit denselben Labels, Boxen,
Editoren, Eingabewerten und Auswahlen ohne Neulayout geprüft. Echte ausstehende
Importrequests werden bei identischem Blockupdate und beim Abbau abgebrochen;
späte Completions bleiben wirkungslos. Ein begrenzter Luau-Weak-GC-Nachweis mit
separater Plain-Control sammelt verworfene Besitzer, Ressourcenrecords, Runtime
und VM. Die [isolierte Chromium-Aufnahme](../scripts/capture-svg-style-owner.cjs)
bewahrt sämtliche [Rohwerte](../tests/fixtures/svg-style-owner-browser.json).

Die rohe `display`-Abweichung bleibt sichtbar: Chromium 154 meldet in den
erfassten SVG-Stylekontexten `inline` und lässt eigenes `display:block` wirken.
Die Engine verwendet das gespeicherte SVG2-Profil `display:none` mit Vorrang vor
Autorregeln. Vorhandene SVG-`fill`-Regelserialisierung und Auswahl betitelter
alternativer Blätter sind durch diesen Besitzernachweis nicht geschlossen;
ihre nativen Regeln und Farbwerte bleiben unverändert im Fixture erhalten.
Die bereinigte Typaufnahme prüft `Attr.namespaceURI` und `getAttributeNS`:
Ein unpräfixiertes fremdes `type` konnte in der Vorgängeraufnahme durch
`setAttribute` weiter verändert werden und war kein Null-Namespace-Typupdate.
Echte Null-Namespace-Typwechsel ersetzen das Blatt im gespeicherten Chromiumlauf
auch ohne Textmutation. Die Engine behält dieses vorhandene Verhalten; der
aktuelle HTML-Algorithmus nennt `type` allein nicht als Update-Auslöser. Diese
native/normative Grenze wird getrennt erhalten.

Stylesheet-Sets/Alternativen, CSS-Hostladung bei ausdrücklich deaktiviertem JavaScript,
vollständige CSP/SRI-/Encoding-Regeln und alle
Attribut-/Viewport-Kombinationen bleiben weitere Arbeit.

Normative Grundlagen: [dynamische Markup-Einfügung](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html),
[Parserknoten und Scriptunterbrechung](https://html.spec.whatwg.org/multipage/parsing.html#creating-and-inserting-nodes)
und [Scriptausführung](https://html.spec.whatwg.org/multipage/scripting.html#execute-the-script-element).

### Gemeinsame Medienattribute und montierte Videos — 11. Oktober 2026

`HTMLMediaElement` besitzt für HTML-Audio und HTML-Video die sieben gemeinsam
geprüften Reflexionen `src`, `preload`, `crossOrigin`, `autoplay`, `loop`,
`controls` und `defaultMuted`. Normale und präfixierte HTML-Namen sind getrennt
von fremden Namespaces geprüft. `src` verwendet USVString und die aktuelle
Besitzerbasis; `Audio(src)` behält dagegen den optionalen DOMString. Der native
Getter und neue Audio-Ladevorgänge nutzen den
[gemeinsamen Node-Basisadresspfad](JAVASCRIPT-DOCUMENTS-R02.md#basisadresse-jedes-dom-knotens--11-oktober-2026),
ohne dass ein Getter eine Quelle neu lädt. Fehlendes/ungültiges `preload` hat in
diesem ausdrücklich festgelegten Engine-UA-Profil den Wert `metadata`, leeres
`preload` den Wert `auto`; Keywords ignorieren ASCII-Großschreibung, nicht
umgebenden Leerraum. `crossOrigin`-Reflexion beweist keine CORS-Anfrage.

[MediaReflection](../tests/MediaReflection.luau) enthält 17 fest benannte Folgen
mit 488 erhaltenen Browserzeilen. Die ursprünglichen zwölf Folgen/422 Zeilen
bleiben unverändert. 19 zusätzliche normative Zeilendifferenzen sind separat
gespeichert: zehn fehlende Setterargumente, sechs Unicode-Getterfälle und drei
Audio-Factory-Getterfälle. Originalwerte werden nicht durch Standarderwartungen
ersetzt. [Fixture](../tests/fixtures/media-reflection-browser.json) und
[Capture](../scripts/capture-media-reflection-reference.cjs) halten die HTML-,
WebIDL- und URL-Quellen zum 6. Oktober mit Commit und SHA256 fest. Setterbranding
vor Umwandlung, atomare Fehler, `false`/`undefined`, Eigentümerwechsel und
ursprüngliche Getter werden an der tatsächlichen VM geprüft. Der unabhängige
elf-Suiten-Lauf besteht (`build/media-reflection-independent-final.log`).

Bereits montierte Videos reagieren auf `controls`, `src`, `loop`, `preload` und
`autoplay` über den vorhandenen HTMLScripts-/RenderTree-/MediaRuntime-Pfad.
Controls werden einmal erstellt und danach verborgen/angezeigt. Unveränderte
Video-, GUI-, Editor-, Fokus- und UTF16-Auswahlbesitzer bleiben erhalten.
Controls-Umschaltung im Vollbild verwendet die erhaltene Overlaygröße und stellt
beim Verlassen die CSS-Größe wieder her. Entfernte/entsorgte Tastaturziele sind
wirkungslos. `defaultMuted` überschreibt keine bereits gewählte aktuelle
Mute-/Lautstärkepräferenz. `src` setzen, auch leer oder identisch, aktiviert eine
neue Generation; bloßes Entfernen behält die ausgewählte Quelle. Gebündelte
Setzen-/Entfernenfolgen und reentrante Ereignisse werden gesondert geprüft.

[MediaLiveRendering](../tests/MediaLiveRendering.luau) vergleicht 36 erhaltene
native Zustände und drei getrennte gebündelte Quellenfolgen aus
[Fixture](../tests/fixtures/media-live-browser.json) und
[Capture](../scripts/capture-media-live-reference.cjs). 72 montierte
Sequenzzustände, 32 Lade-/Ereignisrennen und zehn Vollbild-/inaktive
Tastaturkontrollen ergeben 2.648 Assertions. Der unabhängige finale Lauf mit
sieben gezielten Suiten besteht bei unveränderten sieben Quellenprüfsummen
(`build/media-live-independent-review-final.log`). Die zuvor gefundenen
Pause-, Tastatur- und Vollbildfehler bleiben mit ihren Rotprotokollen erhalten.

Die Registerachsen sind eng auf Audio-/Video-Reflexion, sechs montierte
Video-Wirkungsachsen und strukturelle Controls-Darstellung begrenzt. Native
Browserereignisse und deterministische Roblox-Asset-/GUI-Ersatzdienste werden
getrennt geführt. Alte Jobfortsetzungen und alte Callbackclosures sind
generationengeprüft; ein tatsächlich verspätetes Roblox-Signal an einen neuen
Handler enthält jedoch keine alte Quellenkennung. Dessen Zuordnung ist keine
gelöste Garantie. Vollständiges Video-JavaScript, Quellkinder-/Poster-/Track-
Änderungen, ungerenderte Videozustände, Studio-Videopixel und PageSession-GC
bleiben weitere Anforderungen. Dies ist kein pauschaler H05-/Medienabschluss.

Der anschließende [Audio-Quellenlebenszyklus](JAVASCRIPT-AUDIO-20261006.md#quellenwahl-startposition-und-entfernung--11-oktober-2026)
belegt 34 Fälle/106 Übergänge/237 erhaltene Rohsnapshots. Direktes `src` setzen,
Attributentfernung, SOURCE-Kindänderungen, `preload`-Hint-Resume und Controls
teilen eine gehaltene Ressource. Auswahl und ausdrücklicher Load-Reset sind
getrennt; leere/ungültige URLs verändern `currentSrc` nicht vor erfolgreicher
Auswahl. Frühpositionen, wartende Play-Promises und stabile Dokumententfernung
besitzen eigene Regressionen. Neun unabhängige Suiten bestehen bei unveränderten
Ownerdateien. Die zusätzlichen `src`-/`preload`-Registerbelege gelten nur für
Audio und die ausdrücklich genannten Kombinationen; vollständige
SOURCE-Fallbacks, Medien-Tasks, Realm-Wiedergabe und Studio bleiben offen.

Der zwölfte Gesamtlauf bestätigt diese begrenzten Medien- und Node-Nachträge
mit tatsächlichem Exit 0: 356 registrierte Suiten einschließlich zwölf
isolierter GC-Prüfungen und der getrennten DOM-/Renderer-/Bidi-Prüfungen.
Die anschließende Snapshotkontrolle bestätigt unveränderte 1.660
Quell-/Test-/Fixturedateien und sieben Rojo-Projekte. Projekt-/Registerprüfung,
Registererhaltungstests, API-/CSS-Exportchecks und drei Rojo-Builds bestehen.
Erhaltene Belege: `build/html-full-20261011-twelfth.log`,
`build/html-full12-snapshot-check.log`, `build/html-tests-17912.luau`.
Video-Poster/-Größen und Audio-SOURCE-Fallbacks beginnen erst nach dieser
Abnahme; ihre begrenzten folgenden Nachweise gehören nicht rückwirkend zum
zwölften Lauf.

### Video-Poster und intrinsische Größen — 12. Oktober 2026

Video-`poster` verwendet USVString, den aktuellen Besitzer und den gemeinsamen
URL-Getter. `playsInline` reflektiert das boolesche Inhaltsattribut; Inline-
Wiedergabe entspricht der vorhandenen Roblox-Seitendarstellung. `width` und
`height` verwenden unsigned-long-Konversion und getrennte HTML-
Dimensionshinweise, einschließlich ungültiger Rohwerte und CSS-Vorrang.
`videoWidth`/`videoHeight` sind readonly, vor Metadaten Null und danach die
positive, endliche natürliche Auflösung. Quellen-Setzen sperrt alte Maße noch
im gleichen Skript vor dem Rendercheckpoint; Attributentfernung verwirft die
vorherige Ressource nicht. Aktuelle Auflösungsänderungen aktualisieren Maße
und planen `resize`; alte, entfernte und entsorgte Besitzer veröffentlichen nichts.

[VideoPresentationDOM](../tests/VideoPresentationDOM.luau) enthält 130 Fälle und
sechs separat ausgewiesene USV-Projektionen. Die ursprünglichen Reflexions-,
Branding-, Konversions-, Besitzerbasis-, Intrinsik- und Dimensionsdatensätze
bleiben erhalten. HTML-, WebIDL- und URL-Grundlagen sind mit Revision und
SHA256 in [Capture](../scripts/capture-video-presentation-reference.cjs) und
[Rohfixture](../tests/fixtures/video-presentation-browser.json) festgehalten;
die HTML-Revision ist `ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c` vom 6. Oktober,
SHA256 `49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f`.

Posteranfragen besitzen eine eigene Generation und einen ausstehenden Zähler,
auch ohne JavaScript-Realm. Der Dokument-Loadverschluss ist mit Realm geprüft;
ohne Realm ist der initiale Lade-/Decode-/Renderpfad geprüft, kein allgemeiner
Dokument- oder Sichtbarkeitsverschluss. Die neue Anfrage zählt vor dem Abbruch der alten; dadurch
gibt es keinen falschen Zwischenstand ohne ausstehende Ressource. Ein bisheriges
Poster bleibt während eines Ersatzloads erhalten. Fehlende, leere oder
fehlerhafte Ersatzquellen entfernen es; alte Antworten, Entfernung und Abbau
sind gesperrt. Sechs native HTTP-Zustände belegen den Dokument-Loadpfad.
Zwei vorübergehend größenlose Chromium-Rohzustände bleiben neben der
eingefrorenen Standarderwartung für fehlende natürliche Videogröße erhalten.

Vorbereitete Poster-/SVG-Daten sind von aktiven, erfolgreich geladenen
Renderflächen getrennt. Anfangs- und dynamische SVG-Poster betreten vor dem
Decode nicht die SVG-Renderqueue; während Wiedergabe ausgeblendete SVG-Poster erzeugen kein Raster.
Quellkindänderungen sind Medien-Datenänderungen statt vermeintlicher
struktureller Renderkinder. Die konservative Kaskade erhält dabei tatsächliche
`:has(source[...])`-/`:empty`-Abhängigkeiten. Dies implementiert noch keine
vollständige geordnete Videoquellenauswahl.

Normale und Vollbildflächen teilen `object-fit`/`object-position`. Der
VideoDisplay-Pfad dehnt `fill`; `contain` und `cover` folgen denselben
berechneten Flächen wie der Fallback. Neue Auflösungshinweise sind auf Hosts
ohne entsprechendes natives Signal optional. GUI, Backend, Controls, Fokus,
Editor und UTF16-Auswahl bleiben erhalten.
[VideoPresentationRendering](../tests/VideoPresentationRendering.luau)
vergleicht 152 aufgenommene Browsergeometrien und getrennt 28 kontrollierte
Lebenszyklusgeometrien sowie 40 benannte Controls mit 5.490 Assertions.
Unveränderte frühere MediaLive-Rohdaten prüfen zusätzlich 72 montierte
Zustände, 32 Race- und zehn Controls-Fälle; Auflösungsbenachrichtigungen erhöhen
deren aktuelle Assertions auf 2.680.

Der unabhängige Zehn-Suiten-Lauf (`build/video-presentation-root-independent.log`)
und der gemeinsame 14-Suiten-Medienlauf mit tatsächlichem Exit 0 einschließlich
isolierter GC-Tails bestehen. Die gehaltenen 13 Video- und sieben Audiodateien,
beide Manifeste und frühere Rohdaten bleiben unverändert. Die
[geordnete Audio-SOURCE-Auswahl](JAVASCRIPT-AUDIO-20261006.md#geordnete-source-kandidaten--12-oktober-2026)
hat einen eigenen begrenzten Nachweis.

Das bestehende [Attributregister](html-attributes.v1.json) hält acht teilweise
zugeordnete Mediengruppen mit 44 Einzelanforderungen: 20 erfüllt, elf offen und
13 ungeprüft. Dies ist weder die Gesamtzahl aller HTML-Anforderungen noch ein
globaler Abschlussstand. SOURCE-eigene IDLs, der Seitenabbau bei einer gehaltenen
nativen Ressourcenanfrage, der No-Realm-Loadverschluss, Decoder-/Signalphasen, anamorphes Video, Tracks,
ungerenderte Videozustände, vollständiges Video-JavaScript und Studio-Pixel
bleiben getrennte Anforderungen.

Der dreizehnte vollständige CLI-Lauf bestätigt diesen begrenzten Poster-/Größen-
und Audio-SOURCE-Stand mit tatsächlichem Exit 0: 360 registrierte Suiten,
einschließlich zwölf isolierter GC-Prüfungen und der erforderlichen DOM-,
Renderer-Lifetime- und Bidi-Prüfpfade. Danach waren 1.669 Quell-/Test-/Fixturedateien
und sieben Rojo-Projekte unverändert; 33 unabhängig gehaltene Medienhashes und
drei Provenienzwerkzeuge blieben erhalten. Projekt-/Registerprüfung,
API-/CSS-Exportchecks und drei Rojo-Builds bestehen. Die unveränderte rohe
UTF16-Videofixture ist nur in den drei EngineTests-Projekten von Rojo ausgenommen,
die CLI verwendet weiterhin die Originaldaten. Abnahme:
`build/html-full13-acceptance.json`, Protokoll `build/html-full-20261012-thirteenth.log`,
Hauptbundle `build/html-tests-10196.luau` (48.250.653 Bytes). Nachfolgende SOURCE-IDL-
und Ressourcen-Lifetime-Korrekturen gehören nicht rückwirkend zu diesem Stand.

### SOURCE-Reflexion und geliehene URL-Getter — 12. Oktober 2026

`HTMLSourceElement` verwendet jetzt die passenden gemeinsamen Reflexionsregeln:
`src` ist eine USVString-URL, `srcset` ein USVString, `type`/`sizes`/`media` sind
DOMStrings und `width`/`height` unsigned long. Rohe Attributschreibweisen bleiben
erhalten; skalare Ersatzzeichen entstehen im jeweiligen IDL-Pfad. URL-Getters
verwenden den aktuellen Dokumentbesitzer. Bei einem geliehenen Getter nach
Adoption wird die Basis beim Besitzer gelesen; der Ursprung-Realm behält seine
Wrapper-/Brandingregeln. Das gemeinsame URL-Kontextverfahren korrigiert auch
die geprüften Video-, Bild-, Link-, Base- und Zitatgetter. Base-Hrefs verwenden
weiter die Dokumentadresse statt ihre eigene bereits aufgelöste Basis.

[SourceReflection](../tests/SourceReflection.luau) vergleicht 49 benannte Fälle
und 24 zusätzliche Besitzerzustände für sechs Getter über zwei gleichzeitig
lebende tatsächliche Realms, mit 639 Assertions. Getterzugriff nach dem Abbau
des Ursprung-Realms ist damit nicht geprüft. Geprüft sind Deskriptoren, Defaults, Rohwerte,
Konversion und Mutation bei Fehlern, Receiver vor Konversion, fehlende und
explizit undefinierte Argumente, Namespaces, CE-Reaktionen und Observer.
Die [Rohfixture](../tests/fixtures/source-reflection-browser.json) behält alle
ursprünglichen vollständigen Browserzustände. Fünf getrennte eingefrorene
Gegenstücke betreffen zehn Zeilen: skalare Rohgetter, fehlende Setterargumente
bei `sizes`/`media` und URL-Fallbacks mit opaker Basis. Der
[Capture](../scripts/capture-source-reflection-reference.cjs) prüft die drei
unveränderlichen HTML-/WebIDL-/URL-Quellenpins; frische Original- und
Besitzeraufnahmen wurden ohne Umschreiben ihrer URLs exakt verglichen.

Dies erfüllt die sieben benannten SOURCE-IDL-Verträge. Bild-/Picture-Auswahl,
SOURCE-Dimensionshinweise, historische Ressourcenbasis, Video-/No-Realm-
Quellenwahl und Wiedergabe nach Realm-Adoption sind eigenständige Algorithmen.
Die Reflexion erfüllt deren Anforderungen nicht nebenbei.

Der anschließende unabhängige gemeinsame Lauf besteht mit tatsächlichem Exit 0:
18 Suiten einschließlich SOURCE, Medien-/URL-/Dokumentnachbarn, Ressourcenhost
und isolierter GC-Prüfpfade (`build/source-lifetime-independent-eighteen.log`).
Danach sind die neun gehaltenen Quell-/Test-/Fixture-/Capturedaten und beide
Manifeste unverändert. Gegen den dreizehnten Stand ändern sich nur die vier
freigegebenen alten Source-/Runnerpfade; 1.665 alte Dateien, sieben Rojo-Projekte
und drei Provenienzwerkzeuge bleiben erhalten. Dies ist ein gezielter Nachtrag,
kein vierzehnter Gesamtlauf oder eine Studioabnahme.

### Seitenabbau während nativer Bildarbeit — 12. Oktober 2026

Der [Ressourcenhost](../src/HTMLEngine/Rendering/ResourceLoadHost.luau) trennt
Seitenbesitzer und Subscriber von laufenden nativen Arbeitsframes. Cancel und
Destroy entfernen Callbackbezüge auch aus Cache- und laufenden Completionfällen.
Native Targets werden vor dem externen `Destroy` aus dem Besitz genommen;
Reentranz kann sie damit nicht zweimal freigeben. Bereits laufendes natives
Preload/Decode bleibt ununterbrechbar und darf nach dem Seitenabbau nichts mehr
veröffentlichen. Details zu Cache-, Fehler- und Reentryverhalten stehen im
[Ladeprofil](LOADING-PERFORMANCE.md#12-oktober-2026-ressourcenbesitzer-während-gehaltener-nativer-arbeit).

[ResourceLoadHostLifetime](../tests/ResourceLoadHostLifetime.luau) erhält neun
ursprünglich rote Kontrollen und sieben Nachbarkontrollen; sechs zusätzliche
Kontrollen erhalten nil-/false-/Tabellen-Fehlerwerte unverändert.
[ResourceLoadHostLifetimeRendering](../tests/ResourceLoadHostLifetimeRendering.luau)
prüft eine tatsächlich gemountete no-JS-Videoposterseite mit 32 Assertions.
`RenderWorkBudgetMS=0` schaltet dabei WorkContext aus.
PageSession, Root, Renderbaum, Medienobjekt und Host sammeln bereits vor der
Fortsetzung des absichtlich gehaltenen Preloads, ebenso die unabhängige
Plain-Object-Kontrolle. Nach Fortsetzung: genau eine native Freigabe, keine
Veröffentlichung. Das ist der Abschluss dieses Besitzfehlers, kein Nachweis
aller Page-/Realm-/WorkContext-Kontexte oder nativer GPU-Freigabe.

Das bestehende Register enthält nach diesen Nachträgen zehn teilweise
zugeordnete Gruppen mit 50 Einzelanforderungen: 28 erfüllt, sieben offen und
15 ungeprüft. Vier zuvor offene SOURCE-/Besitzverträge sind erfüllt, vier weitere
SOURCE-IDLs sind jetzt einzeln zugeordnet. Für `srcset`/`sizes` werden die bisher
fehlenden Zuordnungen der übrigen responsiven Auswahl-/Sizingalgorithmen
ausdrücklich als Erfassungslücken geführt. Die früheren 277 Kataloggruppen,
Quellenpins und Nachweise bleiben erhalten. Die Zahlen zählen diesen Teilbestand,
keine vollständige HTML-Matrix oder gesamte verbleibende Arbeit.

### Initiale Poster-Präsentation und gemeinsamer Auswahlkern — 12. Oktober 2026

[HTMLPage](../src/HTMLEngine/Rendering/HTMLPage.luau) wartet beim erstmaligen
Einblenden auf aktuelle Poster-Leases und vollständige Posterpublikation.
Das gilt auch ohne Realm. Cancel/Entfernung, zwei parallele Anfragen, Ersatz,
verschachtelte Publikation und nil-/false-/Tabellenfehler sind getrennt geprüft.
Eine kooperative Pause im tatsächlichen `SVGImages.AddItems` /
`Embedded.document` mit `RenderWorkBudgetMS=4` darf weder den Root zeigen noch
LoadingWork beenden. Auch beide tatsächlichen Realm-Flushpfade bleiben gesperrt,
wenn `Runtime.Pending` bereits leer, die Ressourcenpublikation aber noch nicht
abgeschlossen ist. [PosterPresentation](../tests/PosterPresentation.luau)
belegt 52 montierte Fälle über beide Videobackends, 162 Präsentationskontrollen
und 3.901 Assertions; Umfang und kontrollierte Hostgrenzen stehen im
[Ladeprofil](LOADING-PERFORMANCE.md#12-oktober-2026-initiale-poster-präsentation).
Das ist die atomare initiale Engine-Präsentation, keine normative progressive
HTML-Paint- oder Studio-Pixelabnahme.

Der gemeinsame [MediaSelection-Kern](../src/HTMLEngine/HTML/MediaSelection.luau)
ist VM-frei und wird von der bestehenden verwalteten Audioauswahl benutzt.
[MediaSelection](../tests/MediaSelection.luau) prüft 18 Reentranzkontrollen mit
49 Assertions; [MediaSelectionAudioOpen](../tests/MediaSelectionAudioOpen.luau)
ergänzt drei echte Runtime-/DOM-Kontrollen für veraltete/nil/späte Open-Ergebnisse.
Die [Audioabgrenzung](JAVASCRIPT-AUDIO-20261006.md#vm-freier-auswahlkern-und-audio-reentranz--12-oktober-2026)
trennt begrenzten Queuebesitz von nativen Playbackbesitzern.

Der unabhängige gezielte 17-Suiten-Lauf besteht mit tatsächlichem Exit 0,
kompakten Ressourcen-/Kernprüfungen und frischen isolierten GC-Tails
(`build/core-poster-independent-seventeen.log`). Bei der Posterpromotion bleiben
die 19 übrigen gehaltenen SOURCE-/Video-/MediaLive-Dateien bytegleich; frühere
Rohreferenzen und datierte Gesamtlaufzahlen werden nicht ersetzt. Der folgende
vierzehnte Gesamtlauf bestätigt den gemeinsamen Teilstand mit tatsächlichem
Exit 0, 366 registrierten Suiten und 13 isolierten GC-Prüfpfaden. Quellen-/Projekt-
und Holdprüfungen danach bestätigen denselben Stand (`build/html-full14-acceptance.json`).

### Native Audioauswahl ohne Realm — 12. Oktober 2026

Die [produktive Audioanbindung](JAVASCRIPT-AUDIO-20261006.md#audioauswahl-ohne-javascript-realm--12-oktober-2026)
verwendet denselben Auswahlkern bei No-Script und deaktiviertem JavaScript.
37 montierte Kontrollen/4.481 Assertions und 16 Resolverfälle prüfen geordnete
Kandidaten, None, Fehlerfortsetzung, verborgene/controlfreie Ressourcen, spätere
Controls, tatsächliche Eingabe, Work4-Abbau und begrenzten Audio-Fail-stop bei
Hostfehlern. Unabhängige Codeprüfung und der anschließende Produktionslauf mit
18 betroffenen Suiten einschließlich kompakter/isolierter Tails bestehen,
tatsächlicher Exit 0 (`build/native-audio-production-focused-second.log`).
Die bestehende No-Realm-Audioanforderung erhält diesen Teilnachweis; dieselben
50 erfassten Anforderungen haben nun 29 erfüllte, sechs offene und 15 ungeprüfte
Stände. Ihre Zuordnung bleibt teilweise und zählt nicht den gesamten HTML-Restumfang.
Video-Adapter, der verbleibende historische Quellenumfang, vollständige Lade-/Task-/
Codec-Algorithmen und Studio-Abnahme bleiben getrennt offen. Die separat belegte
[AudioHost-Freigabe](JAVASCRIPT-AUDIO-20261006.md#audiohost-freigabe-und-neue-ladeversuche--12-oktober-2026)
und der folgende Dokumentnachtrag schließen jeweils nur ihren benannten Umfang.

### Historisches Quellendokument — 12. Oktober 2026

Bei Audio und seinen SOURCE-Kindern unterscheidet die Ressourcenwahl jetzt das
Dokument beim letzten erfolgreichen semantischen `src`-Write vom aktuellen
Besitzerdokument des reflektierten Getters. [MediaSourceDocument](../src/HTMLEngine/DOM/MediaSourceDocument.luau)
speichert dazu einen dokumenteigenen Datenkontext mit schwachem Dokumentbezug
und skalaren URL-/Basisbeobachtungen. Er hält keine Realm, Seite, Bridge, Callback
oder nativen Objekte. [AudioElements](../src/HTMLEngine/JavaScript/AudioElements.luau)
und [NativeMediaResources](../src/HTMLEngine/Rendering/NativeMediaResources.luau)
verwenden denselben Kontext bei der Ressourcenwahl; allgemeine URLgetter behalten
ihren bestehenden aktuellen Besitzerpfad.

Ein erfolgreicher Write wird nach Konversion und Validierung, vor beobachtbaren
Callbacks aufgezeichnet, auch bei gleichem Attributwert. Namespaced Writes ändern
den semantischen Null-Namespace-Kontext nicht. Adoption/Move erhalten die Historie;
Entfernung gibt sie frei. Parser, neue Fragmentknoten, Clone/Import und inerte
Templatebesitzer sind jeweils ausdrücklich zugeordnet. Im nativen Daten-DOM gilt
weiter die vorhandene explizite Commit-/Vorher-/Mutationsbenachrichtigung; beliebige
Lua-Tabellenwrites ohne diese Meldung werden nicht nachträglich rekonstruiert.

Die eingefrorene HTML-Quelle vom 6. Oktober verlangt im Algorithmustext das
historische Knotendokument. Die URL wird mit dessen aktueller kanonischer Basis
aufgelöst. Ein danebenstehender Kommentar legt eine frühere Basiszeichenfolge
nahe; dieser Nachtrag gibt das nicht als zusätzlich implementierten Eager-Freeze
aus. Die bestehende USV-/strikte URLparser- und lokale Katalogpolitik bleibt erhalten.
Auch zwei tatsächlich montierte native Seiten ohne `Document.URL` benutzen die
beobachtete Dokumentadresse korrekt; ein relativer neuer BASE im lebenden alten
Dokument wirkt bei erneuter Auswahl, ein gleichwertiger `src`-Write setzt Historie B.

[HistoricalSources](../tests/HistoricalSources.luau) prüft 20 Fälle/67 Kontrollen,
einschließlich aller 14 archivierten Zustände der fünf URLfälle. Die zwei
ausdrücklich benannten [MediaReflection-Gegenstücke](../tests/MediaReflection.luau)
ändern nur die Ressourcenadresse zu Dokument A und prüfen Getter B getrennt
streng. Alle 17 Fälle/488 Rohzeilen bleiben erhalten; die vollständige frühere
Testdatei und beide getrennten roten Alt-Erwartungsproben liegen unverändert in
`build/media-historical-source-implementation-prep`. Es gibt keinen OR-/Skip-
oder Kompatibilitätszweig im produktiven Medienverhalten.

[NativeHistoricalSources](../tests/NativeHistoricalSources.luau) erhält alle
37 bisherigen Montagefälle und ergänzt neun historische Fälle, 5.145 Assertions
insgesamt. [SourceDocumentLifetime](../tests/SourceDocumentLifetime.luau) prüft neun
Datenbesitzkontrollen im verpflichtenden [kompakten Runner](../scripts/run-source-document-lifetime-tests.cjs),
mit unverändertem Budget 128 × 2.048 und unabhängigen zyklischen Kontrollen.
Der unabhängige Review enthält eigene frische Native-/Daten-Lifetime-Läufe;
anschließend besteht der produktive gemeinsame Lauf mit 24 betroffenen Suiten,
tatsächlicher Exit 0 einschließlich aller verpflichtenden kompakten und drei
isolierten Prüfpfade (`build/historical-production-focused-first.log`).

Nach Sammlung des schwachen Ursprungsdokuments oder Ende seiner Bridge bleibt
nur die zuletzt beobachtete skalare Basis. Das ist ein begrenztes Fallbackprofil,
kein vollständiger Standardnachweis für zerstörte Ursprungsdienste. Exakter früher
Basisstring, Nicht-UTF8-Encoding-Parsing, gemeinsame Wiedergabe nach Realm-Adoption
und Videoauswahl bleiben getrennt offen. Die vorhandene Anforderung
`audio-source-historical-document` bleibt daher **offen mit Teilnachweisen**;
die 50 erfassten Anforderungen und ihre 29/6/15 Statuszahlen bleiben unverändert.
Dieser Nachtrag behauptet weder Gesamt-GC noch native Studio-/Codec-/Pixelparität.

### Geordnete Videoquellen auf erhaltenen Backends — 12. Oktober 2026

Montierte VIDEO-Elemente verwenden jetzt denselben VM-freien Auswahlkern wie Audio. SOURCE-Kinder werden in DOM-Reihenfolge geprüft, auch wenn die erste Quelle keine Assetzuordnung besitzt. Direktes, leeres und ungültiges `src`, Medienbedingungen, ausdrücklich abgelehnte gültige Typen und unbekannte ungültige Typangaben haben getrennte Pfade. `preload="none"` verschiebt native Vorbereitung bis Play. Ein Fehler vor Metadaten löst einen nichtblubbernden SOURCE-Fehler aus und setzt die Auswahl getrennt fort; nach Metadaten bleibt er ein Medienfehler ohne Kindfallback.

Die Auswahlposition reagiert auf Einfügen und Entfernen während einer wartenden Auswahl. Direkte Quellenwechsel setzen Maße sofort zurück und sperren alte Callbacks und Ladefortsetzungen. Ein explizites `page:LoadVideo(id)` lädt die aktuelle Quellstruktur erneut. Die bestehende VideoPlayer-/VideoFrame-Instanz, Controls, GUI, Editor und UTF16-Auswahl bleiben erhalten. Native Ladejobs laufen seriell; eine Quelle wird erst nach aktueller bestätigter Bereitschaft als geladen behandelt. Leere oder ungültige Ersatzquellen stoppen die alte Wiedergabe und leeren die Bindung. Auch Destruction oder ein neuer Quellenwechsel innerhalb eines Resolvers oder einer nativen Propertybindung darf nichts Veraltetes veröffentlichen.

[VideoSourceInitialSelection](../tests/VideoSourceInitialSelection.luau) prüft sieben Anfangssituationen auf beiden Backends jeweils mit und ohne Realm: 28 Fälle. [VideoSourceSelection](../tests/VideoSourceSelection.luau) ergänzt 41 benannte Kontrollen mit 7.203 Assertions, darunter tatsächliche HTMLPage-/HTMLScripts-/Controllerpfade, historische Quellendokumente, ein zusammengefasster VM-Write, Work4-Abbau und 1.050 Fehlerquellen mit exakt erhaltener Ereignisreihenfolge. Die privaten No-Realm-Queues sind O(1) und begrenzen nicht willkürlich die Zahl zulässiger Quellen. Mit Realm geht ein stabiler Auswahlcheckpoint den SOURCE-Aufgaben voraus; es gibt keinen Idle-Scan.

Der unabhängige Review enthält eigene frische Anfangs-, Live-, Core- und neun Nachbarsuitenläufe. Der anschließende produktive Lauf mit 15 betroffenen Suiten besteht mit tatsächlichem Exit 0 (`build/video-source-selection-prep/production-focused-first.log`). Acht Quellmodule und zwei additive Testregistrierungen sind exakt übernommen; ursprüngliche Referenzen, 21er-Rotprobe und alle 19 gehaltenen BUILD-Dateien bleiben bytegleich.

Das ist kontrollierte CLI-Integration mit nachgebildeten nativen Diensten, keine Studio-/Decoder-/Pixelabnahme. VIDEO ohne Rendererobjekt (etwa detached oder display:none), die Dokument-load-/readyState-Barriere, Lazy Loading, vollständiges Video-JavaScript, Trackausbau und die gesamte Mediaquery-/Codec-Fähigkeitsgrammatik bleiben getrennt offen. Die frühere Preflightgrenze für fremde SOURCE- und gewöhnliche Fallback-Unterbäume ist im getrennten [Fallback-Nachweis](#versteckte-medien-fallbackinhalte--12-oktober-2026) korrigiert. Das ist kein Abschluss der gesamten Videoquellenauswahl. Manuell erzeugte MediaRuntime-Tests ohne ResolveVideo behalten ihr altes statisches Profil; jede tatsächliche HTMLPage stellt den neuen Resolver bereit. Die drei betroffenen Registeranforderungen bleiben offen mit diesen benannten Teilnachweisen.

### Versteckte Medien-Fallbackinhalte — 12. Oktober 2026

Die fünf Quellmodule und fünf additiven Tests sind nach unabhängigem Kandidatenreview exakt produktiv übernommen. Der anschließende Rootlauf mit 14 betroffenen Suiten hat tatsächlichen Exit 0. Der unabhängige statische Kopierreview b1d5ef2b ist abgeschlossen, ohne Blocker und ohne weiteren Engine-Lauf. Er bestätigt Source5/Test5, die strikten Full41-/Runner-/Loader-Inversen sowie 661 unveränderte Pins. Kein Gesamt- oder Studioabschluss.

Der produktive gemeinsame Pfad erlaubt normale DOM-Einfügung, Entfernung, Ersetzung und
Textmutation unter HTML AUDIO/VIDEO, einschließlich DIV, INPUT sowie fremden und
verschachtelten SOURCE-Elementen. Die authorseitige transparente Inhaltsregel ist
keine DOM-Pre-insert-Gültigkeitsprüfung. Die eingefrorenen HTML-Schritte
37087–37136 und 37595–37605 verlangen im unterstützenden UA keine gewöhnliche
Fallbackdarstellung; DOM 2726–2753 bewahrt Hierarchie-, Referenz- und Knotentypfehler.
Nur direkte SOURCE-Kinder im HTML-Namensraum qualifizieren weiterhin als
Ressourcen; die Auswahlposition zählt sämtliche direkten Kinder.

Ein gemeinsamer datenfreier Klassifikator benutzt Namespace/LocalName,
FlatParent/AssignedSlot und den inklusiven DOM-/Shadowhostpfad. Versteckte
Children/Text/RenderChildren werden vom Renderer getrennt, ihre ursprünglichen
Text-/Strukturinformationen bleiben für die vorhandene CSS-Scopeprüfung erhalten.
Input-type und verschachtelte Audio-controls erzeugen dort keine gewöhnliche
Präsentation. Ein zuvor sichtbarer Editor wird trotz fortbestehender DOM-Verbindung
aus GUI-, Control-, Hit-, Style- und Fokusindizes abgebaut; Wert und UTF16-Auswahl
bleiben beim Zurückverschieben erhalten, ohne automatische Refokussierung.

Runtime-Mutation/PostInsert, MutationObserver, Scriptloader, Stylesheetquellen und
Bildressourcen werden nicht deaktiviert. Die kontrollierte Bildprobe belegt load,
decode, complete und 200×100 ohne Renderitem sowie genau einen neuen IMG101-Preload;
der initiale UI-Asset964655… wird getrennt gezählt. Das ist ein kontrolliertes
Hostprofil, kein Abgleich mit der unabhängigen nativen SVGgröße 21×13 oder
Decoder-/Pixel-/Request-Cancel-Parität. Connected Script läuft, innerHTML-Script
bleibt inert, und verstecktes STYLE beeinflusst die sichtbare Außenkaskade.

Der unabhängige Kandidatenreview 949fa34b ist positiv. Der anschließende
produktive Rootlauf build/media-fallback-production-full16.log besteht mit
tatsächlichem Exit 0:
22 Grundfälle/1.784 Assertions, zwei Shadow-/Slotfälle/257, vier Ressourcen- und
Hierarchiefälle/329 und zwei Lokalitätsfälle/321, insgesamt 30 montierte Kontrollen.
Der bestehende produktive VideoSourceSelection-Test führt genau den geprüften
vollständigen 41-Fall-Gegenpart aus, hier 7.241 Assertions;
die Quelle b00115c4… bleibt archiviert. Ausschließlich der alte Ausdruck
**rejects == [true,true], children == 2, gap == 0** wird durch
**rejects == [false,false], children == 4, gap == 0** ersetzt, ohne OR oder Skip.
Die qualifizierte direkte HTML-SOURCE und der eine kontrollierte Medienload werden
weiter streng geprüft. Unterschiedliche historische Drain-Assertionzahlen werden
nicht als geänderte Testkörper dargestellt. Zusammen mit einer isolierten genauen
Gegenprobe und acht unveränderten Nachbarsuiten besteht das 14-Suiten-Paket.

Zwei gesonderte probe-only Kontrollen/215 Assertions beobachten tatsächliche
recascade-Aufrufe: ein unbenutztes Medien-data-Attribut besucht einen Record,
abhängigkeitsfreier versteckter Text und unreferenzierte Klasse keinen. Die frühere
Vollscan-Gegenprobe bleibt rot erhalten. :has/:empty mit CharacterData 0↔nichtleer
und dir=auto/RTL↔LTR behalten abhängige Außenkaskaden; Sibling-GUI, Blocklayoutzahl
und gemessene Font-/Layoutcaches bleiben in den Farb-/No-op-Fällen erhalten.
Das Instrumentationsmodul ist kein produktiver Kandidat und der Nachweis schließt
keine allgemeine CSS-/Medien-Mikrolag- oder Cascadekostenmatrix.

Die getrennte isolierte Chromiumreferenz bewahrt 16 DOM-/Observer-/Geometriezustände
und zwei echte lokale WAV-Auswahlen; fremde, leere Namespace- und verschachtelte
SOURCE werden ignoriert. Die genaue alte Topologie-Gegenprobe bleibt gesondert.
14 TopLayerzustände zeigen showModal/:modal und showPopover/:popover-open bei
rectCount 0, ohne Throw; acht Open-Shadow-/Slotzustände belegen versteckten Fokus
und sichtbaren Move-out. Daraus folgt keine vollständige TopLayer-Inertness-/
Bewegungs-, Shadow-Medien-, Codec-/Decoder- oder Studio-Pixelparität.
Die vorhandene AREA-Ausnahme über ein zugeordnetes sichtbares Bild bleibt erhalten;
MAP im Medien-Fallback mit IMG außerhalb ist als neue native Achse ungeprüft.
Dokumentladeordnung, ganze Page-/Realm-GC und die gesamte Medienfamilie bleiben
offen. Produktionshold und genaue Grenzen:
build/media-fallback-implementation-prep/production-source-hold.json (30948919):
29 aktuelle Produktionspins, 317 historische/HOLD-Pins und 1.673 gegenüber Full15
unveränderte Dateien. LoadingModules enthält 518 Abhängigkeiten, SHA134ed165.
Die gesamte frühere Testdatei liegt bytegleich unter
build/media-fallback-implementation-prep/production-before/tests/VideoSourceSelection.luau.

### Dokumentladebarriere für Videos — 12. Oktober 2026

Für verbundene VIDEO-Elemente, die der Renderer bereits bei MediaRuntime
angemeldet hat, sperren die anfängliche Auswahlreservierung und der getrennte
Delay-load-Zustand den Dokumentabschluss mit JavaScript-Realm.
DOMContentLoaded bleibt davon getrennt. None-Suspend, Wiederaufnahme, fehlende
Quellen, erschöpfte SOURCE-Kinder, Fehler, Quellenersatz und Abbau ändern den
gezählten Zustand; der Getter braucht keinen Dokumentscan. Die bestehende
Loaded-/IsLoaded-Benachrichtigung ist ein kontrollierter Host-Datenproxy.
Eine queued Datenaufgabe geht der Freigabe für window.load voraus; das ist
kein Nachweis des ersten decodierten Frames. Die bisherige synchrone
loadedmetadata-/canplay-Reihenfolge bleibt ein gesondertes Profil.

ResourcesChanged darf synchron den Besitzer stoppen oder eine neuere Auswahl
starten. Vier lokale Schutzstellen prüfen danach Registrierung, Generation
und Auswahl-Epoche, bevor Initialisierung, sofortiger src-Mutationsreset,
erste SOURCE-Fortsetzung oder erneutes Laden weiterlaufen. Add prüft vor
jedem weiteren Batch-Element die lebenden Besitzer. Die Gegenproben bewahren
einen neueren Ladevorgang und dessen späteren Rate-Befehl, vermeiden alte
Präsentationsaufrufe und neue native Objekte nach Stop sowie doppelte Begin-
Aufgaben. Geworfene nil-/false-/table-Werte bleiben exakt erhalten.

[VideoDocumentLoadRendering](../tests/VideoDocumentLoadRendering.luau) ruft
die ursprünglichen 38 Kontrollen/4.595 Assertions, den unveränderten unabhängigen
Vier-Fall-Rotkörper mit jetzt null Fehlern und 17 zusätzliche fest benannte
Kontrollen/1.707 Assertions auf: insgesamt 59 Fälle. Die Umgebung benutzt
tatsächliche HTMLPage, Controller, Runtime und EventLoop mit kontrollierten
VideoPlayer-/VideoFrame-Diensten. Der eigene unabhängige Acht-Suiten-Lauf und
die physisch geladene Coreprüfung mit unveränderten 18 Kontrollen/49 Assertions
bestehen; die übrigen neun Nachbarn sind als separate finale Ownerprüfung
ausgewiesen. Drei Quellmodule und der Testkörper sind exakt aus v2 übernommen.
Der anschließende produktive 17-Suiten-Lauf hat tatsächlichen Exit 0:
build/video-barrier-production-full16.log. Abnahme:
build/video-load-barrier-v2-prep/production-source-hold.json. Die unveränderte
41er-Quellenfixture zählt in dieser späteren Komposition 7.248 Assertions,
weil zusätzliche Dokumentaufgaben vorhandene Drainprüfungen ausführen; die
historischen 7.203 Assertions des früheren Quellenstands bleiben erhalten.

Der v1-Review bleibt wegen fünf Beobachtungen in vier Acquire-Reentry-Fällen
als BLOCKED erhalten (build/video-load-barrier-prep/independent-final-review.json,
c724872a34ee9c9ba71b0b86b86625b92269f3374db026e55e90013b8a5bd83d).
V2-Abnahme und genaue Pins stehen im separaten unabhängigen Bericht
build/video-load-barrier-v2-prep/independent-final-review.json. Das schließt
weder das gesamte Medienpaket noch die offene Videoquellenanforderung.

Der folgende Nachtrag schließt die geprüfte Rendererregistrierungsgrenze
neu verbundener VIDEO-Elemente. Die ursprünglichen Work4-Rotbelege beider
Backends und neun native Referenzfälle/21 Zustände bleiben unverändert.
Detached/display:none, Lazy Loading, Dokument-/Iframe-Abschluss ohne Realm,
vollständiges Video-JavaScript, Decoder-/Streaming-/Studio-Pixel und
allgemeines Page-/Realm-GC bleiben getrennt offen. Der
initiale blanke Darstellungsverschluss und die vollständige normative
Dokumentladeordnung sind von diesem begrenzten Nachweis zu unterscheiden.

### Dokumentladebarriere vor der Video-Rendererregistrierung — 12. Oktober 2026

Mit Realm wird bei neu verbundenen HTML-VIDEO-Elementen vor dem tatsächlichen
kooperativen HTMLScripts-/Rendererflush eine aktuelle Knotenreservierung
angelegt. Damit kann eine schon wartende window.load-Aufgabe nicht zwischen
DOM-Verbindung und Media:Add feuern. Der Getter liest ausschließlich O(1)-
Zähler; nur tatsächlich geänderte Unterbäume werden kooperativ besucht. Eine
eigene Scanreservierung besteht bereits vor deren Work4-Yield. Die Übernahme
in den registrierten Auswahlbesitzer hält den Beitrag atomar bei 1→1.

Ein Publikationstoken löscht nur die abgeschlossene ältere Arbeit und bewahrt
neuere reentrante Quellencommits. Entsorgte oder abgelehnte Rendererbesitzer
geben ihren Beitrag frei. Mehrere Closing-Slots werden vor der externen
Benachrichtigung gemeinsam entfernt; ein Notifyfehler strandet keinen zweiten
Beitrag. Ursprüngliche Renderer-/Scanfehler bleiben gegenüber sekundären
Closingfehlern exakt erhalten, auch als nil, false oder table.

Die vollständige Medien-API und ihr gemeinsamer Besitzer werden vor der
ersten Transferbenachrichtigung veröffentlicht. Destroy über die zuvor
gespeicherte Eingabefassade oder den neuen Besitzer beendet denselben
lebenden Besitzer. Der Stopzustand gilt vor Remove; nach einer externen
Benachrichtigung prüft Remove nochmals die konkrete Registrierung. So
pausiert die äußere Fortsetzung ein bereits entferntes Backend nicht erneut.
Während dieses bestehenden Teardowns werden ausschließlich ResourcesChanged-
Fehler bis nach Registrierung-/Backend-/Queue-/Verbindungsabbau gehalten;
der erste Fehlerwert wird unverändert weitergegeben. Alte native Antworten
können den Besitzer danach nicht wiederbeleben.

[VideoPrerenderDocumentLoad](../tests/VideoPrerenderDocumentLoad.luau) prüft
24 Einfügungs-/Quellen-/None-/Abbaukontrollen mit 2.697 Assertions.
[VideoPrerenderBoundaries](../tests/VideoPrerenderBoundaries.luau) prüft
21 Publikations-/Acquire-/Scan-/Fehlerkontrollen mit 1.136 Assertions.
Diese ursprünglichen 45 Testfälle bleiben bytegleich.
[VideoPrerenderOwnerReceivers](../tests/VideoPrerenderOwnerReceivers.luau)
ergänzt 28 Receiver-/Remove-/Teardownkontrollen mit 2.673 Assertions: beide
Backends, beide Stopreceiver, beide verschachtelten Stoprichtungen sowie
nil-/false-/table-Fehler. Einzelne native Pause-/Destroy-/Disconnectzähler,
gehaltene native Fortsetzungen, reale Controller-/Editor-/UTF16- und
Nachbaridentität sind getrennt geprüft. Zusammen sind es 73 fest benannte
Fälle/6.506 Assertions in tatsächlichen HTMLPage-/Runtime-/EventLooppfaden
mit kontrollierten nativen Diensten.

Der unabhängige v2-Lauf und der anschließende Produktionslauf mit jeweils
19 betroffenen Suiten haben tatsächlichen Exit 0, einschließlich des
unveränderten verpflichtenden kompakten Core18/49. Der bestehende
VideoDocumentLoadRendering-Körper mit 59 Fällen bleibt unverändert.
Produktionslog: build/video-prerender-owner-v2-production-full16.log.
Abnahme: build/video-prerender-load-owner-v2-prep/production-source-hold.json,
dfa46efe; 32 aktuelle Produktionspins, 450 gehaltene/historische Artefakte,
1.673 gegenüber Full15 unveränderte Dateien und sieben Projekte.
Source2 und drei neue Testdateien sind exakt übernommen; der Runner enthält
nur den benötigten Captureloader und die drei neuen Registrierungen.
LoadingModules bleibt bei 518 Abhängigkeiten/SHA134ed165. Dies ist ein
gezielter Abschluss, kein nachträglich behaupteter vollständiger CLI-Lauf.

Der Pre-render-v1 bleibt im unabhängigen Bericht bc32cdc2 BLOCKED: Die zuvor
gehaltene Zero-Facade stoppte den neuen Owner nicht. Die unveränderte
Receiver-Gegenprobe 1fa12195 ist unter v2 frisch grün. Zusätzliche tatsächlich
rote V1-Einzelzähler zeigen beim reentranten Remove einen Player-Pauseaufruf
und zwei Aufrufe an derselben behaltenen VideoFrame-Fläche statt jeweils
einem. Die anfängliche neue Harness-Gesamterwartung von nur einem Pauseaufruf
war dagegen falsch: Ein moderner Besitzer besitzt beide unterschiedlichen
Objekte. Diese Harnessdiagnose ist archiviert und kein Enginefehlerbeleg.
Der frühere Acquire-Barriere-v1 c724 bleibt ein eigener historischer
BLOCKED-Nachweis; beide Fehlerfamilien werden nicht vermischt.

Die neun ursprünglichen nativen Fälle/21 Zustände und ursprünglichen Player-/
Frame-Work4-Rotproben sind unverändert. Der Browser hält ein entferntes
ladendes Video weiterhin bis zur Antwort als Ladebeitrag; die Enginepolicy
beendet den nicht mehr zuständigen Rendererbesitzer früher. Diese Abweichung
belegt keine normative detached-Medienvollständigkeit. Auch declined/hidden,
Lazy, Dokument-/Iframe-Load ohne Realm, vollständige Video-JavaScript-API,
geladenes erstes Decoderbild, Studio-/Pixelrendering und allgemeines
Page-/Realm-GC bleiben offen. Die separate ForcedGeometry-Diagnostik
bleibt unbehoben; der grüne normale Workerpfad schließt sie nicht.
Die vorhandene Videoquellenanforderung bleibt mit diesem Teilnachweis offen.

### Gemeinsame Video-JavaScript-Bindungen — 12. Oktober 2026

Source7 und sieben neue Testkörper sind nach unabhängigem V2-Review fe7fa301 exakt produktiv übernommen. Der Rootlauf [video-v2-production-full16.log](../build/video-v2-production-full16.log) hat tatsächlichen Exit0 für 22 Registrierungen: 19 Verhaltens-/Nachbarsuiten und drei verpflichtende kompakte Registrierungen mit insgesamt zwölf Kontrollen. Der [Produktionshold fe425c21](../build/video-javascript-api-implementation-prep/production-v2-source-hold.json) hält die aktuellen Bytes, Main4fc5b436 und Loader521/6d893f4b. Das ist kein weiterer vollständiger Projekt-/Medienabschluss.

Die elf readonly Zustands-/Error-/Range-Getter, fünf mutable Werte und fünf Methoden des schon installierten HTMLMediaElement akzeptieren VIDEO. [VideoJavaScriptBindings](../tests/VideoJavaScriptBindings.luau) prüft 21 Member/31 Assertions an tatsächlicher VM/DOM: Defaults, borrowed Receiver, Namespace/Brand vor Konversion, Fehlkonversion ohne Mutation und invalides play() als Promise-Rejection. Die sieben gemeinsamen Reflexionen und sechs eigenen Video-Präsentations-IDLs bleiben separate bestehende Nachweise. Video betritt keine AudioState-/AudioController-/Sound-Welt.

HTML/VideoState hält reine Node-Daten; JavaScript/VideoElements materialisiert VM-Werte, Error-/Range-Objekte und Play-Capabilities. Input/VideoServices adaptiert die vorhandene MediaRuntime-Registrierung; Auswahl, native Factory und Backendbesitz bleiben dort. Gültige scalar Setter/State-Identität bestehen vor Mount und nach Abmeldung. Detached play() ist hier mit NotSupportedError abgelehnt; detached load() ist nur ein begrenztes Datenprofil. currentSrc ist die ausgewählte URL, nicht SourceRaw. volume ersetzt muted nicht; DefaultRate/absolute Zeit sind von UI-Speedintervall und Slider-Ratio getrennt. Der geprüfte VideoFrame-Rate4-Fall wirft NotSupportedError; URI-Mapping beweist keinen Codec.

[VideoJavaScriptMounted](../tests/VideoJavaScriptMounted.luau) erhält 16 benannte Player-/Frame-Kontrollen und ergänzt zwei Positionsfälle, insgesamt18/1374. Er prüft source-less wartende Plays mit Source-Insertion, None/native Fertigstellung, Key-Pause desselben Script-Promises bei tatsächlichen Controls, aktuelle URL/Erroridentität, frische Range-Objekte und Node-State bei Remove/Add. Dies ist der echte MediaRuntime-Key-Service mit installiertem Controller, keine physische Tastatur-/Tab-Probe. Die vorbereiteten falschen URL-/Error-Zeitannahmen vor stabilem Checkpoint und die controls-lose Key-Probe bleiben als rote Körper erhalten; die Gegenstücke behalten strikte Werte bei korrektem Timing/Setup. Getter erzeugen weder native Anfrage noch Layoutpass; geänderte montierte Volume-/Rate-/Seeking-Events sind Media-Tasks statt Setterstack-Dispatch.

Vier rohe Chromium-Kontrollen für VIDEO mit lokalem WAV-Audiotrack liegen unverändert in [position-reference/native.json](../build/video-javascript-api-implementation-prep/position-reference/native.json). Negative/zero/positive DefaultStart-Werte, Endpunkt und Reset sind getrennt erfasst: Metadaten löschen DefaultStart stets, nur positive Werte lösen den geprüften Seek aus; Ended erscheint im Endpunktfall nach Abschluss. Der native20s-WAV und die kontrollierten12s-Hosts sind getrennte Continuous-Timeline-Profile. Das belegt keine Videoframes/Codec- oder disjunkte Seekable-Parität.

V1 bleibt historisch [BLOCKED](../build/video-javascript-api-implementation-prep/independent-final-review.json): der echte12-Fall-Rotkörper zeigt Pause0/Metadatenverbindung1 und PlayerDestroy0 bzw. gebundene Frame-Quelle auch nach späterem Destroy. V2 nimmt alte Registrierungs-/Selektions-/Native-/Connection-Slots vor Rückmeldungen heraus, baut gefangene alte Ressourcen ab und bewahrt die durch einen Subscriber auf demselben Item neue Auswahl. notify versucht alle noch aktuellen Subscriber; der erste nil-/false-/table-Fehler wird nach Cleanup unverändert weitergegeben. Der vorhandene best-effort native Release-Pfad bleibt erhalten. QueueTask-Fehler lassen Tokens wie bisher fallen; für den fehlgeschlagenen Hostscheduler wird kein Play-Promise-Outcome behauptet.

[VideoRemoveSchedulerReview](../tests/VideoRemoveSchedulerReview.luau) ist bytegleich zum unabhängigen roten12-Körper und jetzt ohne Fehler. [VideoRemoveReentryReview](../tests/VideoRemoveReentryReview.luau) prüft beide Backends mit2/153: old disposed/new alive, aktuelle neue Lease, None-IO-Anzahl, Abort des alten Play und keine Publikation aus alter gehaltener Antwort. Der tatsächliche ursprüngliche Reentry-Rotbeleg bleibt. Die frische kompakte Prüfung erhält [VideoFacadeLifetime](../tests/VideoFacadeLifetime.luau) mit sechs ursprünglichen Kontrollen plus [VideoFacadeDestroyFaults](../tests/VideoFacadeDestroyFaults.luau)3/45 und [VideoStateNotificationReview](../tests/VideoStateNotificationReview.luau)3/19. Sie belegt nur cache-eigene Fassadengraphen innerhalb unveränderter begrenzter Pressure, keine ganze Page-/VM-/native-I/O-GC.

Der unabhängige V2-Review belegt19+compact12 Exit0 und1616 unveränderte Pins, physisch sieben Source-IDs/753 Inputs. Nur VideoState/MediaRuntime unterscheiden sich von V1. MediaReflection ersetzt exakt das historische VIDEO-TypeError-Kriterium durch strikte genuine Receiver; vollständiges Original bffe30f0 und17/488 Rohdaten bleiben in BUILD erhalten. Keine ORs, Skips oder sonstige Erwartungslockerung.

Offen bleiben loading, preservesPitch, getStartDate, srcObject, audioTracks, videoTracks, textTracks und addTextTrack, Video-Cross-Realm/Origin-Task-/Promise-Besitz, zerstörte VM-Operationen, detached Transport, native Decoder/Streaming und payloadfreie verspätete Signale an neue Bindungen. Loaded/IsLoaded ist der dokumentierte HAVE_CURRENT_DATA2-Proxy; leere buffered/seekable ohne Capability sind kein Bufferbeweis. Detached Setter-Events und vollständige Play-/Pause-/Timeupdate-/Metadaten-Taskordnung, Studioframes und ganze Page-/Realm-GC sind nicht geschlossen. Bestehende offene Registeranforderungen und globale Abschlusszahlen bleiben unverändert.

### IFrame-Remove-/Destroy-Batches — 12. Oktober 2026

Nach [unabhängiger begrenzter Abnahme6cb2b079](../build/iframe-lifecycle-independent-review-prep/independent-final-review.json) sind Source1/Test3 exakt produktiv. [Root15](../build/iframe-lifecycle-production-full16.log) hat tatsächlichen Exit0; [Produktionshold2c0adf40](../build/iframe-lifecycle-frame2-rebase-prep/production-source-hold.json) hält58 aktuelle/1.035 historische Pins und sieben Projekte, mit1.668 unveränderten Full15-Altdateien. Main9a93931c besitzt nur drei neue Registrierungen mit Inverse zub0038e38; Loader522/a48fed28 bleibt unverändert. Der frühere [BUILD-HOLD0efff290](../build/iframe-lifecycle-frame2-rebase-prep/final-build-hold.json) auf Frame2/Source55 bleibt erhalten. Nur IFrameRuntime Remove/Destroy ändert sich: der vollständige alte Batch wird vor externen Rückmeldungen abgemeldet, seine Kindseiten werden vorher aus den Slots genommen und anschließend alle gefangenen alten Kinder geschlossen. Neu registrierte Items/neue Owner werden nicht nachträglich abgeräumt. Auch nested Remove/Destroy erhält den ersten nil-/false-/table-Originalfehler bis nach allem alten Cleanup.

Die bytegleichen [IFrameLifecycle](../tests/IFrameLifecycle.luau), [IFrameLifecycleNested](../tests/IFrameLifecycleNested.luau) und [IFrameLifecycleMounted](../tests/IFrameLifecycleMounted.luau) erhalten10/215 plus6/136 und tatsächliche HTMLPage/PageSession/VM6/487: insgesamt22/838. Drei echte Produktions-Rotbelege bleiben im [Autorbericht](../build/iframe-lifecycle-frame2-rebase-prep/author-final-evidence.json) erhalten; jeder brach an seiner ersten echten Assertion ab, sodass nicht sämtliche Inventarzeilen als rot gemessen gelten. Autor15, unabhängiger15er und Root15 haben tatsächlichen Exit0 mit unveränderten Frame40, NoRealm-, NativeIMG-, Owner73-, Video59-, PageLoading- und WebStorage-Nachbarn.

Das ist ein enger Engine-Batch-/Exceptionvertrag mit kontrollierten Diensten. PageSession behält seine eigene warn-and-continue-Cleanuppolicy; ein erster Fehler wird hier nur bei tatsächlicher Propagation aus ChildPage.Destroy oder Owner-Wake behauptet. Einzelkind-Ersetzung/unavailable außerhalb Remove/Destroy, beliebige native Property-/Callbackfehler, physische Taskannullierung, volle Browser-/Window-/Sandbox-Semantik und allgemeine Page-/Realm-/native-I/O-GC bleiben offen. Keine neue parallele Anforderungsliste oder Statusschließung.

### Lebende IFrame-Attribute und aktuelle Kindnavigation — 12. Oktober 2026

Nach [unabhängigem Review10fd662a](../build/iframe-attribute-navigation-native-img-rebase-prep/independent-final-review.json) sind Source2/Test40 und die bytegleiche18-Fall-Rohfixture exakt produktiv. [Root13](../build/iframe-navigation-production-full16.log) hat tatsächlichen Exit0; [Produktionshold67a7d577](../build/iframe-attribute-navigation-native-img-rebase-prep/production-source-hold.json) hält55 aktuelle/998 historische Pins, sieben Projekte und1.668 unveränderte Full15-Altdateien. Mainb0038e38 besitzt genau eine Registrierung und die Inverse zu44c149e1; Loader522/a48fed28 bleibt unverändert. Der frühere [BUILD-HOLD206fdd68](../build/iframe-attribute-navigation-native-img-rebase-prep/final-build-hold.json) und die NativeIMG-Basis bleiben historische Eingaben. HTMLScripts leitet erfolgreiche null-namespace src/srcdoc-Schreibvorgänge an IFrameRuntime; die vorhandene Kindseiten-/Quellen-/Ressourcenordnung bleibt erhalten. HTML-expanded-name und Namespace-Gates schließen fremde/unverbundene Nodes aus. Setter erfassen Quelle, srcdoc, Basis und Sandbox vor späterer Mutation. Gleiche src/srcdoc-Werte navigieren erneut; srcdoc bleibt prioritär, Entfernen nimmt das aktuelle src, sandbox wirkt erst bei der nächsten Navigation und base allein startet keine Navigation.

[IFrameAttributeNavigation](../tests/IFrameAttributeNavigation.luau) ist der bytegleiche0769477a-Körper mit40 Fällen/4060 Assertions, ursprünglichen36 plus vier Owner-/Interleavingkontrollen. Fragmentnavigation behält die committed Kindseite und deren Completion-Lease. Ein Kind nach C kann die queued oder gehaltene Elternnavigation B ersetzen; Requestgeneration und committed Dokumentidentität sind getrennt. Resolver-/Constructor-Reentry, Stop im Add-Batch und alte Mount-/Loadantworten werden geprüft. Tatsächliche GUI-/Editor-/UTF16-Identität bleibt erhalten. Authored Ziel, finale zwölf Nachbarsuiten, unabhängiger13er und Root13 haben tatsächlichen Exit0.

Die ursprünglichen [Chromium18/44-Rohwerte](../tests/fixtures/iframe-attribute-navigation-browser.json) und separaten [Childnavigation2/8](../build/iframe-attribute-navigation-owner-prep/native-child-navigation.json) bleiben unverändert. Frozen invalid-src→about:blank ist getrennt von Chrome about:blank#blocked. Die eingefrorene Vorfahrenprüfung behält den committed Child/Editor, während Chrome den rekursiven Elternversuch anders beobachtet. Bei echten HTTP-Interleavings können B und anschließend C tatsächlich angefragt werden; die Engine darf eine frühe noch nicht gestartete B-Anforderung annullieren. Zwei gemappte Kontrollen belegen last-navigation-wins, keinen Replay jeder HTTP-Row oder vollständige Netzwerk-/Taskparität.

[PageLoading-Review1fbc4654](../build/iframe-attribute-navigation-native-img-rebase-prep/page-loading-test-only-review.json) erhält das ganze ursprüngliche Mocktestarchiv und dessen exakte Inverse: nur ShouldStart=true wird zum ohnehin Runtime-startenden HTMLScripts-Mock ergänzt. Kein Enginefallback und keine geänderte Assertion; Source2-freier Rotbeleg, eigener grüner Gegenpart, finale zwölf Nachbarn und Root13 einschließlich PageLoading sind getrennt erhalten. Alte NoRealm-Körper bleiben bytegleich: current10/1330 und33/3122 sind zusätzliche Drains, nicht Ersatz der datierten3112/3071.

Öffentliche Window/Document-Fassaden, detached/lazy, vollständige Sandboxgrammatik und Vorfahren-/History-/Adoptionssemantik, native Studio-/Pixelabnahme und allgemeines Page-/Realm-GC bleiben offen. Der oben benannte Remove-/Destroy-Batch ist getrennt ergänzt; darüber hinausgehendes Ressourcenhost-/Lifecycle-Hardening bleibt offen. Der bestehende src-Unterpunkt erhält ausschließlich diesen IFrame-Teilnachweis; Status und Abschlusszahlen bleiben unverändert.

### Eager-Bildanforderungen ohne Engine-VM — 12. Oktober 2026

Nach [unabhängiger begrenzter Abnahme d162f16f](../build/no-realm-image-load-independent-prep/independent-final-review.json) sind Source3 und zwei bytegleiche Testkörper exakt produktiv. [Root12](../build/native-image-production-full16.log) hat tatsächlichen Exit0; der [Produktionshold3f22968c](../build/no-realm-image-load-author-v1-prep/production-source-hold.json) hält52 aktuelle/916 historische Pins und sieben Projekte, mit1.669 unveränderten Full15-Altdateien. Main44c149e1 und Loader522/a48fed28 besitzen genaue Inversen zu vorherigem Main/Loader521; ein NativeImage-ID und die nötige ResponsiveSources-Reihenfolge sind getrennt vom bereits autorisierten R16-Metadata-Toolinglift erfasst. Dies ist kein neuer vollständiger Projekt-/HTML-Ladeabschluss.

Rendering/NativeImageResources besitzt verbundene HTML-IMG-Anforderungen ohne Engine-Runtime am DOM statt am Renderitem. HTMLPage bindet den vorhandenen Dokument-Wake daran; ImageLoad unterdrückt einen zweiten visuellen Preload. Der Beitrag bleibt durch aktuelle terminale Rückmeldung/Ereignisdispatch reserviert. Initiale und spätere Work4-Discovery sperren vorzeitigen Abschluss; neue Ressourcen vor der Fertigmeldung blockieren diese, danach wird sie nicht rückwirkend geöffnet. Keine versteckte VM, Idle-Schleife oder globale Requestzählung als Ersatz für Node-Besitz.

[NativeImageDocumentLoadRendering](../tests/NativeImageDocumentLoadRendering.luau) prüft22/986: gehaltene gemappte Antworten, display:none, beide Medien-Fallbacks, eigene DOM-Beiträge bei geteiltem Asset, Fehler/null source, Generation/PageDestroy, queued neue Bilder, verschachtelte Frames, Work4 und responsive Same-Candidate-No-op. [NativeImageOwnerGuards](../tests/NativeImageOwnerGuards.luau) prüft24/218 mit Load/Notify/Changed/Emit/Viewport/Scheduler-Reentry und ersten Originalfehlern nil/false/table nach Cleanup. Die ursprünglichen NoRealm-Körper bleiben bytegleich: aktuelle zusätzliche Drains10/1330 und33/3112 werden getrennt von den datierten1319/3071 geführt. Owner73/6506, Video-Barriere59 und Video-JS18/1374 bestehen unverändert in den acht Nachbarsuiten.

Nur die ursprüngliche display:none-Harnessannahme eines fehlenden ImageItem wurde [streng berichtigt](../build/no-realm-image-load-author-v1-prep/test-counterpart.json): das aktuelle Item bleibt unter unsichtbarer GUI und geprüfter physischer Elternkette. Audio-/Video-Fallback verlangt weiterhin kein ImageItem. Die Whole-Body-Inverse erhält das Original; Anfrage-/Ereignis-/Ladebarrieren sind ungeschwächt.

Die separate [Chromium-HTTP-Referenz](../build/no-realm-image-native-reference-prep/independent-review.json) umfasst7 Fälle/15 Snapshots/117 Kontrollen: eager/hidden/beide Medien-Fallback-IMG, gültiges SVG0×0, HTTP404 und ein zweites Bild vor dem ersten Abschluss. Child/Parent bleiben interactive bis zum aktuellen Terminalereignis und melden load jeweils einmal. Sandbox verhindert Kindskripte, Chrome besitzt aber Window-/Platform-Realms; das ist kein absent-Engine-VM-Beweis. PNG2×3/Null-SVG und kontrollierte gemappte Enginehosts belegen keine Decoder-/Studio-Pixelparität.

Missing src ohne srcset/picture erzeugt hier keine Anfrage/kein Terminalereignis; ein null ausgewählter src/srcset/picture-Pfad plant den engen error-Fall ohne IO. Bei deaktiviertem Scripting verzögert loading=lazy den eager Abschluss nicht. Enabled-JavaScript-/Lazy-Resumption, automatische bare-DOM-Notification und Removed-Node-/Adoptionssemantik, vollständige responsive/MIME-/Pixel-Density-Grammatik, weitere Dokumentressourcen und ganze Page-/Realm-GC bleiben offen. Der passende bestehende src-Registerpunkt erhält ausschließlich IMG-Teilnachweise; Status und Abschlusszahlen ändern sich nicht.

### Dokumentladebarriere ohne Engine-VM — 12. Oktober 2026

Die tatsächliche Originalbaseline hatte 21 Fehlerbeobachtungen in zehn
Fällen: Bei sieben gehaltenen Audio-/Video-/Poster-/verschachtelten bzw.
noscript-Kindern war Child-/LeafRuntime tatsächlich nil und ein nativer
Beitrag noch offen, während Iframe und Parent bereits load meldeten. None,
leere Quelle, aktives Scripting mit inaktivem noscript sowie der finale
einmalige Abschluss/Abbau aller zehn Fälle bestanden schon vorher.
Die ganze gepumpte Kontrollquelle fffcc660 bleibt unverändert; ihre beiden
Parent-Flush-/Drainpunkte sind eine getrennte Ableitung der ursprünglichen
ff14-Quelle. Browserrohwerte wurden nicht durch Engineerwartungen ersetzt.

Vier unabhängig geprüfte, exakt produktiv übernommene Quellen ergänzen den
seitenweiten Hostvertrag:
HTMLPage.IsDocumentComplete delegiert mit Realm an den bestehenden
ScriptLoader und hält sonst den eigenen Abschluss einmal fest. Eine
wartende Freigabe prüft aktuelle Seitenlebensdauer, Startup und bekannte
Ressourcen nochmals. DocumentResourcesChanged ist ein reiner Ressourcen-
Wake, ohne Layoutanforderung, Idle-Schleife oder Dokumentscan. Native-AUDIO,
registriertes VIDEO, Poster und aktuelle Kindframes verwenden diesen
Wake. Der Iframepfad prüft die echte Kindseite sowie Registrierung,
Navigationsgeneration und Identität nach externem Ereignis; ältere
Mount-Stubs behalten ihren vorhandenen Kompatibilitätspfad.

Die Callbackwerte sind interactive und complete, keine Booleans. Neue
Quellen oder Frames vor einer wartenden Freigabe blockieren diese; nach
erreichtem Abschluss lösen spätere Ressourcen keine zweite Fertigmeldung
aus. Der existierende Native-AUDIO-Pfad setzt Loading und Pending bereits
vor Begin. Die tatsächliche Work4-Visit-Kontrolle prüft Startup und diese
vorhandene Reservierung; sie führt keine spekulative Bootstraplease ein.
SourceSelection, VM, HTMLScripts und Renderer-/Layoutalgorithmen sind
unverändert. Der vorhandene Owner-v2-FirstError-/Receiververtrag besteht
unter dem neuen Page-Wake weiterhin unverändert.

[NoRealmDocumentLoadOriginal](../tests/NoRealmDocumentLoadOriginal.luau)
ergeben jetzt null Fehlerbeobachtungen/1.319 Checks; die historischen
1.301 Checks bleiben im roten Originalprotokoll erhalten. Zusätzliche
echte Abschlussaufgaben führen 18 weitere bestehende Drainchecks aus.
[NoRealmDocumentLoad](../tests/NoRealmDocumentLoad.luau) prüft 33 benannte
Kontrollen mit 3.071 Assertions für queued Quelle/Frame, Callbacknavigation und
ChildDestroy, Posterabschluss mit PageDestroy, mehrere unabhängige Beiträge,
Fehler/OwnerStop, spätere Ressourcen, verschachtelte Pages ohne VM,
Scripting=false, sandbox allow-same-origin ohne allow-scripts, tatsächliche
Work4-Visit-/Bind-Reentry und nil-/false-/table-Callbackfehler. Navigation
verwendet ausdrücklich den tatsächlichen ChildPage.Navigate-/IFrameRuntime-
Hostpfad; die damalige VM-iframe.src-Attributlücke ist im separaten [lebenden IFrame-Nachweis](#lebende-iframe-attribute-und-aktuelle-kindnavigation--12-oktober-2026) im benannten Teilumfang korrigiert.

Der eigene tatsächliche 14-Suiten-Lauf besteht: ursprüngliche zehn und neue
33 Fälle, alte 73 Owner-v2-Kontrollen/6.506 Assertions, Video-Barriere59 und
verpflichtender unveränderter Core18/49. Protokoll:
build/no-realm-document-load-implementation-prep/final-fourteen.log.
HOLD662e27d0 enthält Source4, die Testkörper und den privaten Treiber,
509 geprüfte Pins und tatsächliche sieben Quellenreads im eigenen Lauf.
Der unabhängige Final14-Review9f16fe36 ist ohne Blocker abgenommen,
547 Pins bleiben unverändert. Danach sind Source4 und zwei Testkörper exakt
übernommen; Main erhält nur zwei Registrierungen. Der produktive14er
hat tatsächlichen Exit0 (build/no-realm-production-full16.log); die alten
Owner73/6506, Video59 und verpflichtender Core18/49 bleiben ungeschwächt.
Produktionshold f542af4e:36 aktuelle/505 historische Pins, sieben Projekte,
1.671 unveränderte Full15-Altdateien und18 ausdrücklich freigegebene alte
Pfade. Loader518/134ed165 unverändert, Main05206704. Kein neuer vollständiger
CLI-/HTML-Ladeabschluss.

Die [native Kernreferenz](../build/no-realm-iframe-load-prep/native-independent-review.json)
bleibt bei fünf Fällen/elf Rohsnapshots/48 Kontrollen. Sandbox verhindert
authorseitige Kindskripte, schafft im Browser aber keinen VM-freien
Dokumenttyp. Die Engineprüfung zeigt getrennt die tatsächliche Abwesenheit
einer Runtime. Native Readiness ist weiter der kontrollierte Loaded-/
IsLoaded-Proxy, kein erster Decoderframe-/Freeze-/Studio-Pixelnachweis.
Weitere Font-/Style-/Ressourcenalgorithmen außerhalb des begrenzten IMG-Nachweises,
contentDocument/contentWindow-/NoRealm-readyState-Fassaden, weitere Iframe-
Navigation, detached/display:none/Lazy, vollständige Medien-/Iframe-/Adoptions-
semantik, ForcedGeometry und allgemeines Page-/Realm-GC bleiben offen.
Die initiale atomare blanke Präsentation bleibt vom normativen
Dokumentabschluss getrennt. Keine neue Kategorie oder Anforderung wird
geschlossen; der passende Videoquellenpunkt erhält höchstens diesen
unterstützenden Teilnachweis.


### Responsive Bildauswahl und Dichtekorrektur — 16. Oktober 2026

Der [Bildquellen-Nachtrag](IMAGES.md#responsive-bildauswahl--16-oktober-2026)
ordnet den beiden bisherigen ungeprüften SOURCE-`sizes`-/`srcset`-Anforderungen
jetzt Grammatik, Qualifikation, ausgewählte Anfrage, Media-/DPR-Neubewertung,
Basis-/Quellenreihenfolge, Fehler, Owner und erhaltenes Layout einzeln zu.
Die unveränderten ursprünglichen Abnahmekriterien bleiben erhalten; beide
Anforderungen sind **offen**, nicht pauschal erfüllt.

Die [Rohreferenz](../tests/fixtures/responsive-source-browser.json) enthält
55 IMG- und zehn Picture-Fälle aus isoliertem HTTP-Chromium 155. 64 Vergleiche
prüfen Auswahl und natürliche Dichtemaße. Der eager-`auto`-Fall bleibt als
abweichende native Beobachtung separat; Lazy-/konkrete Auto-Größen sind offen.
Die eingefrorene HTML-Revision ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c
und ihr unveränderter SHA256 sind im Capture festgehalten.

Tatsächliche Runtime- und montierte no-Realm-Pfade ergänzen Dichtekorrektur,
Quelle/Basis, Höhe/Auflösung, gleiche und noch wartende Quellen, späte Antworten,
SOURCE-Maßhinweise und erhaltene native GUI-/CSS-Boxen. Der Metadatencache
trennt gemeinsam decodierte Pixel von der Dichte jedes Verbrauchers. Ein
bestehender Nullquellen-Test verwendete irrtümlich das zulässige `0x`; seine
unveränderten Fehlerbehauptungen verwenden jetzt das tatsächlich unzulässige
`0w`. Gültiges `-0x` besitzt eine gesonderte Erfolgs-/Maßkontrolle.

Die 17 Bild-/Quellen-/Ressourcen-/Dokumentnachbarn bestehen zusammen. Dies
belegt keine vollständige CSS-Mathematik-/Einheitengrammatik, jede Adoption,
Entfernung oder Reihenfolge, dynamische Decoderfähigkeiten oder Studio-Pixel.


### VIDEO-/Poster-Lazy und doppelte native Fehler — 16. Oktober 2026

Der [Mediennachtrag](MEDIA.md#verzögertes-video-posterladen--16-oktober-2026)
ordnet dem bestehenden offenen Lazy-Kriterium jetzt die Loading-Zustände,
getrennte Medien-/Posterfortsetzungen, eager-/Geometrie-/Play-/Load-Auslöser und
Dokumentladebarrieren zu. Erfasst sind tatsächliche montierte Seiten mit Realm,
mit eingeschaltetem Scripting ohne Realm und mit ausgeschaltetem Scripting.
Die vorhandenen beiden Videobackends behalten ihre Besitzer und GUI-Flächen;
es gibt keine neue Auslassung von Elementen außerhalb des Viewports.

80 montierte Kontrollen/3.874 Assertions und 18 gezielte Besitzerprüfungen
umfassen Root-/Ancestor-Scrolling, Resize, fixed-/absolute-Containing-Blocks,
inline GeometryBox, Transform-/WAAPI-Publikation, Quellen-/Posterwechsel,
Basisaufnahme, erhaltene Eingaben und Suspend-/Entfernungs-/Fehlerabbau.
Der separate geordnete Retry-Nachweis ergänzt acht Fälle/635 Assertions für
mehrfache Meldung desselben nativen Fehlers, ohne die bestehenden Quellenwahl-
Kriterien oder ihre Statuswerte zu ersetzen.

Die Rohreferenz enthält 13 tatsächliche HTTP-Chrome-155-Fälle und dieselbe
geprüfte eingefrorene HTML-Revision. Beobachtete native Play-/Load-, currentSrc-
und Scripting-disabled-Posterabweichungen bleiben neben dem Zielverhalten
sichtbar. Decoder-/Studioframes, vollständige nichtrechteckige beziehungsweise
transformierte Clip-/Top-Layer-Geometrie, detached Transport und die übrigen
ursprünglichen Medienkriterien bleiben offen. Dies ist kein Abschluss der
Attributgruppe und keine Einstufung dieser machbaren Geometriearbeit als
technische Unmöglichkeit.

### Automatische IMG-/SOURCE-Größen und Lazy-Fortsetzung — 18. Oktober 2026

Der [neue Bildquellen-Nachtrag](IMAGES.md#automatische-bildgrößen-mit-lazy-loading--18-oktober-2026)
ergänzt einen begrenzten Teil der am 16. Oktober noch offenen Auto-Größen:
IMG-`loading=lazy` und eigenes exaktes `sizes=auto`/`auto,`-Präfix, ausgelassenes
SOURCE-`sizes`, explizite bedingte SOURCE-Größen, veröffentlichte Inhaltsbreite
und die letzte Auto-Breite während ungerenderter Phasen. Eine Kopie übernimmt
diese gemerkte Breite nicht. Die Quellenwahl liest abgeschlossene Geometrie
und erzwingt kein Layout innerhalb der Auswahl.

UA-`contain:size!important` ersetzt andere Containment-Mengen vollständig.
Die normalen 300×150-Ersatzmaße stehen vor Autorenregeln, einschließlich
geprüftem `initial`/`unset`/`inherit`/`revert`; explizite Maße und null bleiben
wirksam. Dichtekorrigierte Metadaten speisen keine wiederholte Auto-Verkleinerung.
`object-view-box` behält seinen gemalten Ausschnitt, ohne diese Ersatzbox
nochmals zu verkleinern.

Tatsächliche HTMLPage-, Runtime- und VM-freie Pfade behalten denselben
DOM-Anfragebesitzer für Quelle, Dichte und Metadaten. Lazy-Fortsetzungen
reagieren auf vorhandene Layout-/Scroll-/Loading-Benachrichtigungen; deaktiviertes
Scripting nimmt den Lazy-Aufschub aus. Geplante Realm-Initialisierung schützt
auch vor dem Aufbau der VM vor einem zweiten expliziten Preload-/Metadatenpfad.
Gehaltene alte Antworten und Auswahlrückrufe nach Ersetzung/Abbau dürfen nicht
wieder publizieren. Auswahl nach veröffentlichtem Layout betritt mit Runtime
deren vorhandenen budgetierten Einstieg.

Der [korrigierte elf-Quellmodule-Nachweis](../build/engine-expansion-20261018/auto-image-corrected-receipt.json)
ordnet [59 Kernkontrollen](../tests/AutoImageSources.luau) sowie
[25 Montagekontrollen/1.136 Assertions](../tests/AutoImageRendering.luau) zu.
Der gezielte Zwei-Suiten-Lauf, 13 Bild-/Layout-/Ressourcennachbarn und zwei
Kaskadensuiten bestehen. Der unabhängige
[Review](../build/engine-expansion-20261018/autoimage-independent-review.md)
hat die drei UA-/View-Box-/CSS-weiten Kombinationen vor der Korrektur belegt
und danach elf strikte Chromium-155-/Renderer-Gegenproben bestanden. Die
16 zusätzlichen nativen Auswahlbeobachtungen bleiben getrennt von diesen
strikten Kontrollen und vom normativen Parserprofil erhalten.

Die zwei bestehenden offenen SOURCE-`sizes`-/`srcset`-Anforderungen erhalten
nur diesen weiteren Teilnachweis. Ihre ursprüngliche Standardrevision,
Abnahmekriterien und offenen Grammatik-/Kombinationsachsen bleiben bestehen;
der Zwischenbeleg mit zehn Quellmodulen und 1.067 Montage-Assertions ist nicht
der finale Stand. Es gibt keinen Gesamtabschluss dieser Attribute, aller
Adoptions-/Parser-/Shadow-/Einheiten-/Zahlenkombinationen, automatischer
Plattformanforderungen, Studio-Pixel oder ganzer Page-/Realm-Freigabe.

### Lebende Inline-Textregeln — 18. Oktober 2026

Der [bestehende Textnachweis](OVERFLOW-WRAP.md) ergänzt das CSS-Kompatibilitäts-
Schlüsselwort `word-break:break-word`: Der berechnete Wert bleibt erhalten,
die Umbruchwirkung entspricht `word-break:normal` mit `overflow-wrap:anywhere`
einschließlich Min-Content, unabhängig vom tatsächlich berechneten
`overflow-wrap`. 135 unabhängige Chromium-Fälle prüfen Zeilen, intrinsische
Breiten und berechnete Werte.

Die acht bestehenden Felder `word-break`, `overflow-wrap`, `hyphens`,
`hyphenate-character`, `hyphenate-limit-chars`, `line-break`, `text-autospace`
und `hanging-punctuation` invalidieren nun ihren betroffenen Textpfad korrekt.
Gleichförmige Regeln behalten nach Möglichkeit das ursprüngliche Wortlabel;
veränderte Inline-Quellgrenzen verwenden den vorhandenen begrenzten Tokenizer.
[InlineTextMutation](../tests/InlineTextMutation.luau) vergleicht 72 tatsächliche
Token-/Positions-/Größenzustände nach Stil-, Klassen- und Hoverwechseln mit
frischem Aufbau. Erweiterte [Hyphenation](../tests/Hyphenation.luau)-Kontrollen
prüfen Trennregelwechsel und Rückkehr; unabhängige Controls und Boxen bleiben
erhalten. Sieben Text-/DirtyLayout-Nachbarsuiten bestehen.

Dies erweitert das sichtbare CSS-/Rendererverhalten vorhandener HTML-Inhalte,
keine HTML-Parsergrammatik und keinen vollständigen CJK-/Unicode-/Sprach-/
Font-/Studiovertrag. Der [enge Gesamtbeleg](../build/engine-expansion-20261018/text-expansion-report.md)
trennt native Vergleiche von Live-/Frischaufbau-Parität; allgemeine Text- und
Grammatikkriterien bleiben offen.
