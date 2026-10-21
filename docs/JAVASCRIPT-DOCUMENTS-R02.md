# R02: Dokumente, DOM-Interfaces und dynamische Tabellen

Die API verwendet dieselben Datenknoten, Wrapper, Mutationspfade und Renderer-Reconciliation wie die vorhandene Engine. Übernahme in ein anderes Dokument erhält die Identität des author-seitig vorhandenen Wrappers, eigene Eigenschaften, Listener und den aktuellen Zustand von Eingabefeldern. Es wird kein zweites DOM für diese APIs aufgebaut.

## Implementiert

- `DOMImplementation`, `DocumentType`, `XMLDocument`, `Attr`, `CDATASection`, `ProcessingInstruction`, `NamedNodeMap` und die üblichen `NodeList`-/`HTMLCollection`-Prototypen.
- `createHTMLDocument`, `createDocument`, `createDocumentType`, `createElementNS`, `createAttribute[NS]`, `createCDATASection`, `createProcessingInstruction`, `importNode` und `adoptNode`.
- HTML-Templates besitzen ein eigenes Content-Fragment im gemeinsamen inaktiven Eigentümerdokument. Auch präfixierte HTML-Namespace-Templates, verschachtelte Inhalte, HTML-/XML-Parsing, Fragmentkontexte, Klonen, Importieren, Adoption und anschließendes Einfügen erhalten diese Grenzen; Einzelheiten und Nachweise stehen unten.
- Dokument- und Elementmetadaten, `documentElement`, tatsächliche `head`-/`body`-Knoten, `title`, `doctype`, `compatMode`, tatsächlicher Zeichensatz und Content-Type. Bereits decodierte Strings verwenden UTF-8; ausdrücklich übergebene Rohbytes nutzen das [Encodingprofil](JAVASCRIPT-TEXT-DATA-20261005.md#byte-decoder-und-html-zeichencodierung--9-oktober-2026). Detached-Dokumente haben kein Window und keine aktive Navigation.
- Gemeinsame HTML-Attributreflexion einschließlich URLs, `lang`, `dir`, `translate`, `contentEditable`, `inputMode`, `enterKeyHint`, booleschen und enumerierten Attributen. Gemeinsame Interfaces wie `HTMLQuoteElement` erlauben alle zugehörigen Tags.
- Lebende, stabile Attr-Knoten und namespacebezogene Attributoperationen. HTML-Namen sind ASCII case-insensitive; XML-Namen und Namespace-Metadaten bleiben erhalten.
- `DOMParser` für HTML und XML-MIME-Typen. Die geparsten Dokumente übernehmen die URL des relevanten Dokuments und haben keinen Browsing Context; HTML-Skripte bleiben inert. XML verwendet den vorhandenen strikten UTF-8-/XML-Scanner, Namespace-Scope, QName-Prüfung, CDATA, PI, Kommentare und `parsererror` bei Fehlern.
- `XMLSerializer` verwendet denselben gemeinsamen Serialisierungspfad wie XML-`innerHTML`/`outerHTML`: Element-/Attribut-Namespace-Fixup, Präfixkonflikte, Default-Resets und XML-Escapes. Der eigene HTML-Serializer bleibt erhalten; der genaue Fehler- und Nachweisumfang steht unten.
- HTML-Doctype-Knoten und die gebräuchlichen Quirks-/Limited-Quirks-Klassifizierungen, einschließlich HTML 4.01 mit/ohne System-ID.
- Lebende Collections mit numerischen enumerierbaren und benannten nicht enumerierbaren Properties in Dokumentreihenfolge.
- Dynamische Tabellen/Abschnitte/Zeilen/Zellen, Span-Reflexion und aktuelle Eingabewerte während Einfügen/Entfernen. Tabellen verwenden weiterhin die zentrale Parser-Normalisierung und den Tabellen-Renderer.
- `moveBefore` über den gemeinsamen Mutationspfad; erhaltene Moves beeinflussen Listener, native Eingaben und Custom-Element-Lebenszyklen über explizite Move-Metadaten.
- `document.write`/`writeln`/`open`/`close`, Live-Parsing decodierter Stringquellen,
  Parser-Scriptunterbrechung und Dokumentersetzung im vorhandenen Renderer;
  Umfang und verbleibende Kontexte im [H03-Profil](HTML-PARSER-ATTRIBUTES-20261006.md#h03-live-parser-und-dynamisches-schreiben--9-oktober-2026).

## Nachweise

`node scripts/run-html-tests.cjs JavaScriptDocuments JavaScriptDOMExpansion JavaScriptDOMQueries JavaScriptRuntimeStorage JavaScriptRealmLifetime`

Die Dokumentgruppe prüft echte Runtime-Bridges, Fremd-Dokumentübernahme mit erhaltenem Wrapper/Eingabewert, XML-/HTML-Parser, Attr-Identität, Descriptor-Receiver, gemeinsame HTML-Interfaces, Collections, Tabellenkombinationen und Moves. Die bestehende Query-Gruppe vergleicht ihre Ergebnisse mit einem aufgezeichneten nativen Chromium-Durchlauf. Realm-Lifetime prüft, dass entsorgte Seiten nicht durch globale Wrapper-Registry-Zyklen festgehalten werden.

Bei `option` erhält `adoptNode` den aktuellen ausgewählten Zustand und dessen Dirty-Flag. `cloneNode` initialisiert den Zustand dagegen aus den kopierten `selected`-Attributen; bei einem einfachen `select` gewinnt das letzte ausgewählte Option-Element. Dieser Unterschied ist in `tests/fixtures/javascript-option-clone-browser.json` unmittelbar nach dem Klonen mit Chromium 154 aufgezeichnet und wird zusätzlich von der vorhandenen DOM-Control-Gruppe geprüft.

### Template-Eigentümer und Präfixe — 10. Oktober 2026

`DOM/TemplateDocument` verbindet jedes Dokument mit genau einem inaktiven
Template-Dokument. Verschachtelte Templates darin verwenden denselben Besitzer;
es entsteht keine weitere Dokumentkette und kein globaler starker Cache.
Der inaktive Besitzer hat `about:blank`, keine Kinder und keinen Browsing Context.
Ein XML-Template-Besitzer implementiert `Document`, nicht `XMLDocument`; dieser
Interface-Unterschied bleibt beim Dokumentklonen erhalten. Templates werden nach
HTML-Namespace und lokalem Namen erkannt, unabhängig von einem Präfix.

Der Parser ordnet Knoten bereits vor der Runtime-Anbindung ihrem tatsächlichen
Besitzer zu. `innerHTML` ersetzt Template-Inhalte, gewöhnliche `append`-Kinder
bleiben Light DOM. HTML-Fragmente verwenden den lokalen Template-Kontext auch bei
Präfixen. XML-Fragmente verwenden den strikten Scanner und den Namespace-Scope
des Kontextes; fehlerhafte Eingaben werfen `SyntaxError`, bevor bestehende Inhalte
verändert werden. Die gemeinsame XML-Serialisierung ergänzt Element- und Attribut-
Namespace-Deklarationen und löst Präfixkonflikte wie im folgenden Abschnitt beschrieben.

Adoption erhält Fragment-/Knoten-/Wrapper-Identität und verlegt Template-Inhalte
in den inaktiven Besitzer des Zieldokuments; normale Kinder und Shadow Roots
verwenden das Zieldokument selbst. Tiefe Kopien verwenden den Besitzer ihres
jeweiligen Ziel-Fragments. Custom Elements in inaktiven Vorlagen werden nicht
vorzeitig konstruiert. Ein Import in ein aktives Dokument oder das anschließende
Einfügen über den vorhandenen DOM-Mutationspfad aktiviert die entsprechenden
Elemente; verschachtelte Template-Inhalte bleiben inaktiv.

`node scripts/capture-template-document-reference.cjs` zeichnet 40 native
Chromium-Datensätze in `tests/fixtures/template-document-browser.json` auf.
Die identische JavaScript-Quelle läuft in `tests/TemplateDocuments.luau`:
HTML/XML mit/ohne Präfix, gemeinsame Besitzer/Metadaten/Interfaces, Negativfälle,
tiefe/flache/Fragment-/Dokumentkopien, Import/Adoption/Extraktion, HTML-Tabellen-
Fragmentkontext, XML-Fehleratomizität, echte Custom-Element-Konstruktor-/Connection-
Zähler und `content`-Descriptor/Receiver/readonly-Prüfungen. Zusätzliche Daten-DOM-
Prüfungen sichern Parser-Eigentümer vor Runtime-Anbindung, tatsächliche Übernahme
zwischen zwei unabhängigen Runtime-Bridges mit gehaltenen Wrappern, Eingabewerten,
Listenern und korrekten Quell-/Ziel-Host-Migrationsaufrufen sowie die Speicherfreigabe
verwaister Dokumentpaare. Der reguläre Parser-/Shadow-/Ressourcen-Lauf bleibt
Bestandteil der Regression; `TemplateDocuments` führt seine GC-Prüfung separat
aus, ohne sie zu entfernen.

Maßgeblich sind die [Template-Erstellungs-/Adoptions-/Klonregeln](https://html.spec.whatwg.org/multipage/scripting.html#the-template-element)
und die [HTML/XML-Fragmentsetzung](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-innerhtml).
Neue `template[for]`-Patching-Regeln sowie CSP-/Trusted-Types-Kombinationen sind
durch diese 40 Nachweise nicht abgeschlossen. XML-Serialisierung hat einen eigenen
Nachweisumfang im selben Profil.

### HTML-Elementsemantik mit Präfixen — 10. Oktober 2026

`DOM/ElementNames` teilt die vorhandene Expanded-Name-Regel mit
`DocumentAccessors`: Namespace und lokaler Name bestimmen die Elementsemantik.
`h:input` im HTML-Namespace besitzt damit dieselben bereits implementierten
Formular-/IDL-Verhaltensweisen wie `input`. `Name`, `nodeName`, `tagName`, Präfix
und Namespace-Metadaten bleiben erhalten. Ein Doppelpunkt im lokalen Namen,
ein fremder oder ausdrücklich leerer Namespace und ein großgeschriebener
XML-Lokalname erhalten dadurch keine HTML-Kontrollsemantik.

Dieser DOM-Checkpoint umfasst die vorhandene Attributreflexion, live/default
Werte und Textauswahl, Validierung, Formulareigentümer und erste-Legend-Ausnahme,
Reset/Submit, Radio- und Select-Collections, Tabellen-/Listen-Interfaces,
Details-Gruppen, FormData und benannten Document-/Window-Zugriff. Custom-Element-
Lookup und Interface-Marken verwenden denselben lokalen Namen; vorhandene
Konstruktor-, Connection-, Attributreaktionen und form-associated Internals
funktionieren auch mit Präfix. Der gemeinsame Mutationspfad bleibt bestehen.

`capture-html-expanded-names-reference.cjs` friert 58 DOM-Datensätze und acht
zusätzliche Selektorzustände in `tests/fixtures/html-expanded-names-browser.json`
ein. `HTMLExpandedNames` prüft 55 identische Chromium-DOM-Ergebnisse und drei
ausdrücklich normative FormData-Gegenfälle. Chromium übernimmt darin Felder
unter `datalist` unabhängig vom Präfix in FormData; die Engine überspringt sie
nach [HTML §4.10.22.4 Schritt 5.1](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#constructing-the-entry-list).
Unveränderte Rohwerte und getrennte normative Erwartungen bleiben gespeichert.
MO-Attributnamen, Ziele und alte Werte sowie beobachtete Custom-Element-Attribute
werden tatsächlich ausgeführt; es werden keine Quellenamen zur Anpassung an
den Renderer verändert. Maßgeblich ist die
[HTML/XML-Elementdefinition](https://html.spec.whatwg.org/multipage/infrastructure.html#xml-compatibility).

Acht zusätzliche native Pseudodatensätze prüfen die tatsächliche
HTML-/Foreign-Abgrenzung von `matches()` und Formularzuständen. DOM-Getter
allein gelten weiterhin nicht als Nachweis für Styling oder Darstellung.

`HTMLExpandedRendering` ergänzt **27 exakte native UA-/Shadow-/Richtungsfälle**
und **sieben tatsächlich montierte Rechtecke** mit `getBoundingClientRect()`.
Der gemeinsame `HTML/ElementProfile` wählt Renderer und UA-Einträge über Namespace
und lokalen Namen, ohne den öffentlichen Katalog oder Quellenamen umzuschreiben.
Unbekannte HTML- und Foreign-Elemente behalten die anfängliche Inline-Darstellung;
HTML-lokale `svg`/`math` sind keine SVG-/MathML-Elemente. Controls, Tabellen,
`bdi`/`bdo`, der erste direkte HTML-`summary`, benannte/manuelle Slots, Fallback,
Slot-Klonen und aktuelle `dir=auto`-Inputwerte verwenden dieselbe Abgrenzung.
Der berechnete Summary-Marker folgt `open`, auch ohne eine eigene Author-Regel.

Der montierte Prüflauf verändert Slotnamen und aktuelle Inputwerte und prüft dabei
originale Light-DOM-Eltern, Quellen-QNames, bereits vorhandene native Input-GUIs,
unbeteiligte Boxen und Freigabe nach Entfernen. **Zwei zusätzliche normative
Namespace-Kontrollen** bleiben ausdrücklich von den Rohdaten getrennt:
Der aufgezeichnete Chromium-Browser akzeptiert `Element.prototype.attachShadow`
bei Nicht-HTML-`div`; [DOMs Attach-Shadow-Algorithmus, Schritt 1](https://dom.spec.whatwg.org/#dom-element-attachshadow)
verlangt dort `NotSupportedError`, dem die Engine folgt. Maßgeblich für die
UA-Summary-Kontexte sind die [HTML-Rendering-Regeln](https://html.spec.whatwg.org/multipage/rendering.html#the-details-and-summary-elements).

`HTMLExpandedHosts` ergänzt **33 exakte native Host-Ergebnisse** und **sechs
exakte asynchrone Ergebnisse** aus derselben gespeicherten JavaScript-Quelle in
`tests/fixtures/html-expanded-host-browser.json`. Der vorhandene Bild-, Canvas-,
Audio-, Dialog-/Popover-, Script-/Style-/Link- und Metadatenpfad verwendet nun
HTML-Namespace und lokalen Namen; SVG-Scripts bleiben im passenden Namespace
aktiv. HTML-Scripts in MathML-/SVG-Containern werden nicht pauschal verworfen,
HTML-Template-Inhalte bleiben dagegen inert. GlobalEventHandlers gelten für
HTML-, SVG- und MathML-Elemente, nicht für beliebige Foreign-Elemente. Body-
Window-Weiterleitung und Formular-Handler-Scope verwenden dieselbe Abgrenzung.
Fremde Attribute gleichen lokalen Namens ersetzen keine HTML-Ressourcenattribute
und invalidieren keine unveränderten Stylesheet-/Bildbesitzer.

Der Ressourcenlauf prüft abgewiesene `decode()`-Receiver als tatsächlich
abgewiesene Promises, PNG-Metadaten, Picture-Quellen und externe Script-/CSS-
Ladeereignisse. Weitere Prüfungen erhalten den Bildbesitzer beim Quellwechsel,
beenden nur den überholten Request, unterdrücken dessen verspäteten Abschluss
und räumen noch laufende Requests beim Entsorgen auf. Sieben zusätzliche
`srcset`-Proben sichern Kommas in URLs, Trenner und ungültige Klammerdeskriptoren:
vier Ein-Quellen-Ergebnisse stimmen exakt mit Chromium überein; bei drei
verschiedenen Dichten bleiben native Auswahl und feste 1x-Profil-Erwartung
getrennt gespeichert. [HTMLs Bildauswahlalgorithmus](https://html.spec.whatwg.org/multipage/images.html#selecting-an-image-source)
erlaubt ausdrücklich eine browserabhängige Auswahl aus diesen Kandidaten.
Das bestehende deterministische Profil ist kein Nachweis für vollständige
`sizes`-/Media-/Deskriptorgrammatik oder sämtliche Ressourcen-/CSP-Kombinationen.

Der DOM-/Runtime-Hostnachweis beweist noch keine vollständige montierte Bild-/
Canvas-/Medien-Darstellung mit Präfixen: verbleibende semantische Gates im
Renderer werden getrennt geprüft. Vollständige WebIDL-/UA-Pixelkonformität wird
weiterhin nicht behauptet. Die Details-Regressionsgruppe prüft zusätzlich, dass
ein Öffnen/Schließen keine redundante Layout-Anforderung für bereits durch die
übergeordnete Disclosure-Box abgedeckte Marker-/Inhaltsboxen auslöst; externe
Stilziele und bestehende Retention-/Open-/Toggle-Prüfungen bleiben erhalten.

### Namensindex und begrenzte Mutationsinvalidierung — 10. Oktober 2026

`DOMNamedProperties` verwendet eine eigene schwache Revision je Dokument. Kleine
Änderungen ohne relevante gewöhnliche `id`- oder HTML-`name`-Kandidaten behalten
bereits aufgebaute Document-/Window-Indizes und ihre lebenden Collections. Shadow-
Bäume und Template-Inhalte gehören nicht zum Document-Light-Tree. Kandidaten-
Einfügung, Entfernung, Umbenennung, Vorfahrenverschiebung und Adoption invalidieren
vor Custom-Element-Reaktionen; entfernte Kandidaten werden sofort aus den Daten-
Snapshots gelöscht. Namenszugriff, Built-in-Überschreibung und VM-Schrittgrenze
werden durch diese Optimierung nicht verändert.

Die atomare Klassifizierung verwendet Cursor auf Eingabe-/Kinderlisten und prüft
höchstens **256 Knoten insgesamt je Mutation**, ohne breite Listen vorher zu
kopieren. Größere, noch nicht vollständig klassifizierte Unterbäume invalidieren
konservativ. Alle tatsächlich besuchten Knoten werden anschließend dem bestehenden
VM-Budget belastet. Ein verschachtelter Lookup am ersten kooperativen Checkpoint
sieht deshalb bereits die neue Revision. Ein Budgetabbruch nach der committed
Mutation lässt entfernte Knoten nicht im alten Index hängen; ein späterer Entry
kann normal neu aufbauen. Das ist keine Zusage ruckelfreier beliebig großer
Mutationen oder unbegrenzter DOM-Arbeit.

`NamedPropertyMutations` prüft **zehn exakte native Mutationssequenzen** aus
`tests/fixtures/named-property-mutations-browser.json`: Duplikatreihenfolge,
Collection-Identität, Namespace-Attribute, Detached-Vorfahren und Wiedereinfügen,
Adoption, Präfix-/Foreign-Namen, Shadow-/Template-Grenzen und tatsächlich
aufgerufene Disconnect-Reaktionen. Direkte Schritt-Hooks prüfen Einfügen,
Umbenennen und Entfernen während laufender Snapshots, verschachtelte Lookups
während der Invalidierung sowie Abbruch/Recovery. Breite Eingaben mit 3.000
Elementen/Textknoten und tiefe Unterbäume belegen die Klassifizierungsgrenze.
Die unveränderten isolierten Handler-GC-Prüfungen bleiben verbindlich.

Im real montierten `MemoryRendering` mit gemeinsamer RenderStepped-/Heartbeat-
Uhr verbraucht der Wechsel von 16 auf 24 Karten nun **25.638 statt 35.524 VM-
Schritte**; Initialaufbau 16 Karten **19.742 statt 25.528**, erhaltener Neustart
**9.192 statt 10.926**. Die Ergebnisse stimmen an 320, 480 und 1.080 Pixeln
überein. Die Grenze bleibt 30.000; Karte/Motiv, SVG-Upload, Clips, Zwischenstände,
Fehlpaar, Wiederaufdecken, Neustart, 24-Karten-Aufbau und Entsorgen werden im
bestehenden Test tatsächlich ausgeführt. Dies ist ein deterministischer
Schrittvergleich, keine Zeit-/Framerate-Messung in Roblox Studio.

**Drei zusätzliche native Datensätze bleiben ausdrücklich Audit-Lücken:**
Document-Assignment auf bereits unterstützte Legacy-Namen, benannte Iframe-
WindowProxies und das Browserverhalten bei Named-Gettern in Detached-Dokumenten.
Die zusätzliche Zwölf-Fälle-Matrix trennt `createHTMLDocument`/DOMParser,
gewöhnliche/präfixierte HTML-Images und gewöhnliche/Foreign-`name`-Attribute.
Chromium zeigt gewöhnliche Namen im Hauptdokument, aber nicht in diesen Detached-
Dokumenten; Namespace, lokaler Name, HTMLDocument-Marke, Content-Type und echtes
Document-Root sind dabei gleich. Diese Beobachtung wird nicht ohne Nachweis als
`fully active`-Regel oder Hostgrenze erklärt. Der derzeit optionale `FrameWindow`-
Callback ist nicht an den Renderer gebunden; Window-Child-Navigable-Namen sind
noch nicht implementiert. Maßgeblich für die weitere Konformitätsprüfung sind
[HTMLs Document-Namenszugriff](https://html.spec.whatwg.org/multipage/dom.html#dom-document-nameditem)
und [Window-Namenszugriff](https://html.spec.whatwg.org/multipage/nav-history-apis.html#named-access-on-the-window-object).

### XML-Namespace-Fixup und Serialisierung — 10. Oktober 2026

`JavaScript/XMLSerialization` serialisiert iterativ mit je Aufruf eigenem
Namespace-Scope, Präfixzähler und einem Ausgabelimit von 1 MiB. Elemente und
Attribute behalten ihre erweiterten Namen aus Namespace-URI und lokalem Namen.
Vorhandene Deklarationen, spätere Deklarationen im Attributsatz, geerbte und lokal
neu gebundene Präfixe, mehrere Kandidaten, Default-Namespace-Wechsel/-Resets und
fehlende Attributpräfixe werden berücksichtigt. Erzeugte `nsN`-Präfixe kollidieren
nicht mit vorhandenen Bindungen. Ein Attribut kann den Präfix des eigenen Elements
oder eines bereits ausgegebenen Attributs nicht auf einen anderen Namespace umbiegen.

Präfixkorrekturen finden ausschließlich in der Ausgabe statt. Attr-Knoten,
Attributreihenfolge, ursprüngliche Präfixe, Kinder, Wrapper und OwnerDocument bleiben
erhalten. Der HTML-Pfad ergänzt keine XML-Deklarationen und behält seine bisherigen
Raw-Text-/Void-/Template-/Entity-Regeln. XML dagegen escaped auch HTML-`script`-Text;
NBSP bleibt ein Unicode-Zeichen. Attribut-Tabs, LF und CR werden als numerische
Referenzen ausgegeben, damit ihre Werte das erneute XML-Parsing überstehen.

XML-Getter verwenden `require well-formed = true`: ungültige lokale XML-1.0-Namen,
Zeichen, doppelte erweiterte Attribute, unqualifiziertes `xmlns`, reservierte
Namespace-Deklarationen, Prefix-Undeclarations, ungültige Kommentare und
Processing Instructions werfen ein echtes `DOMException` mit
`name = "InvalidStateError"` und `code = 11`. PUBLIC-/SYSTEM-IDs werden geprüft
und System-IDs bei Bedarf mit Apostrophen eingefasst. Diese Prüfungen verändern
weder das DOM noch Renderobjekte. `createDocument` berücksichtigt bei
`qualifiedName = null` die vorgeschriebene leere Zeichenkette.

`new XMLSerializer()` sowie Methoden-/Konstruktor-/Descriptor-/Brand-Prüfungen
sind in der Runtime angebunden. `serializeToString` verwendet ausdrücklich
`require well-formed = false`, wie es der HTML Standard verlangt; ungültige
author-seitig erzeugte Inhalte werden dabei nicht pauschal abgewiesen. Attr als
Wurzel liefert die leere Zeichenkette. Dokument-, Fragment-, Text-, Kommentar-,
CDATA-, PI- und Doctype-Knoten sowie HTML-/Foreign-Elemente verwenden denselben
Helper. Leere Foreign-Elemente erhalten `/>`; leere HTML-Void-Elemente ` />`,
andere leere HTML-Elemente ein End-Tag. Vorhandene Kinder eines Void-Elements
bleiben bei XML-Serialisierung erhalten.

`node scripts/capture-xml-serialization-reference.cjs` hält 63 unveränderte native
Chromium-Datensätze samt identischer JavaScript-Quelle in
`tests/fixtures/xml-serialization-browser.json` fest. `XMLSerialization` besteht
43 exakt gleiche Datensätze und 20 ausdrücklich dokumentierte Normativabweichungen
von Chromium. Die Rohdaten werden dafür nicht überschrieben. Betroffen sind
strenge Fehlerprüfungen, Attr-Wurzeln, redundante/reservierte Deklarationen und
Doctype-Quoting. Die ergänzende echte Browser-Referenz und zwei unabhängige Runtime-
Bridges prüfen fremde Node-Wrapper, gegenseitig ausgeliehene Methoden,
Konstruktor-Brands und die Realm-Identität von TypeErrors. Weitere 126 Kombinationen
werden serialisiert und erneut durch den strikten XML-Parser gelesen; Namespace-
und Attributwerte sowie originale Attr-/Präfix-Identität müssen erhalten bleiben.
Raw-Daten-DOM-Prüfungen sichern XML-Zeichen-/NCName-Grenzen, doppelte Attribute,
Doctype-IDs und einen 4.096 Ebenen tiefen Baum ohne rekursiven Stack.

`XMLSerializationRendering` sichert Boxen, SVG-Quellknoten, Textobjekte und native
Input-Werte/-Auswahl: Serialisierung löst keine Author-Mutation oder GUI-Erstellung
aus. Eine isolierte GC-Prüfung belegt, dass Serializer-Brands verworfene Instanzen,
Knoten und Runtimes nicht halten.

Maßgeblich sind [DOM Parsing §5.2.1](https://w3c.github.io/DOM-Parsing/#xml-serialization),
die [HTML-Getter und XMLSerializer-Regeln](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#xmlserializers)
und [Namespaces in XML §3](https://www.w3.org/TR/REC-xml-names/#ns-decl).
Die bekannten offenen Draft-Probleme 44/45/52 werden beim Namespace-Fixup so
behandelt, dass keine kollidierenden Bindungen erzeugt oder neu gebundene Präfixe
für ihren alten Namespace verwendet werden; eine passende lokale Default-
Deklaration hat wie im aufgezeichneten Browser Vorrang. Numerische Dezimal-
Referenzen sind mit den aufgezeichneten Browser-Escapes kompatibel.

Der aktuelle DOM-Parsing-Algorithmus verlangt für CDATA selbst bei `require
well-formed = true` keine Inhaltsprüfung. Eine nachträglich mit `]]>` oder
ungültigen Zeichen beschriebene CDATA kann deshalb weiterhin nicht wohlgeformte
Ausgabe erzeugen; dieser überprüfte API-/Standardfall wird nicht als vollständige
XML-Validierung bezeichnet. `serializeToString` garantiert aufgrund seines
False-Flags ebenfalls keine wohlgeformte Ausgabe beliebiger ungültiger Daten.
DTD-Parsing/-Validierung, Entity-Deklarationen und externe Entitäten sind weiterhin
getrennte, nicht implementierte Parser-Funktionen. Dieser Nachweis ersetzt keine
vollständige XML-1.1-/DTD-/WebIDL-Konformität.

## Basisadresse jedes DOM-Knotens · 11. Oktober 2026

`Node.baseURI` liest die Basisadresse des aktuellen Knotendokuments. Das gilt
auch für Text, Kommentare, Attribute, Processing Instructions, CDATA, Doctypes,
Fragmente und Shadow Roots sowie für entfernte Knoten. Nach `adoptNode` bleiben
ursprüngliche Wrapper und Getter erhalten und lesen die Basis des neuen Besitzers.
Inaktive Template-Inhalte behalten ihr eigenes Knotendokument. Der Getter ist
nativ gebrandet und schreibgeschützt; eine eigene, ausdrücklich definierte
Property bleibt von einem geborgten nativen Getter getrennt.

[NodeBaseURI](../tests/NodeBaseURI.luau) prüft sieben fest benannte native Folgen
mit 32 unveränderten Zuständen aus dem
[Browserfixture](../tests/fixtures/node-base-uri-browser.json), darunter
Basisänderungen, History, Detached-Dokumente, beide Adoptionsrichtungen,
Descriptoren und falsche Empfänger. Eine zusätzliche Kontrolle verwendet zwei
gleichzeitig lebende Runtime-Realms und prüft auch entsorgte Getter. Die
[Aufnahme](../scripts/capture-node-base-uri-reference.cjs) hält den DOM-Zielstand
vom 6. Oktober über Commit
`b76da7af5fe35a2a368127cc9ec22449ac8fd559` und SHA256
`a7e26185022e0f29650bcd30be7df091419096f6d9bd96bb493662efa34d1e7f`
fest. Die unabhängige Prüfung mit elf gezielten Suiten sowie die abschließende
Prüfung der Inventar-/Run-Guards und gepinnten Aufnahme bestehen mit tatsächlichem
Exit 0 (`build/media-reflection-independent-final.log`,
`build/node-base-uri-final-guards.log`,
`build/node-base-uri-capture-pinned-check.log`).

Dies ergänzt den vorhandenen Basisadresspfad ohne neuen Cache oder
Ressourcenreload beim Lesen. Der zunächst untersuchte XML-DTD-Fall bleibt als
fehlgeschlagene Probe unter `build/node-base-uri-reference/initial-with-xml-dtd.*`
erhalten. Der aktuelle XML-Fall verwendet keine DTD; ein weiterer Fall erzeugt
einen Doctype ausdrücklich über DOMImplementation. Das beweist weder XML-DTD-
Parsing noch das Weiterleben eines fremden Wrappers nach Entsorgung seines
ursprünglichen Realms. `xml:base` verändert den hier geprüften DOM-Getter nicht.

## Bewusste Grenzen

Der HTML-Pfad wurde am 6. Oktober durch einen Tree-Builder mit Einfügemodi,
Formatierungs-/Tabellenfehlerkorrektur, Foreign Content, kontextuellen Fragmenten
und Doctype-Zuständen ersetzt. Umfang, 1.508 Dokument-/59 Fragmentnachweise und
verbleibende Streaming-/Script-/Encodingfälle stehen im
[Parser-/Attributprofil](HTML-PARSER-ATTRIBUTES-20261006.md). Dies ist weiterhin
keine pauschale vollständige WHATWG-Konformität. Quirks-Metadaten allein
implementieren nicht sämtliche historische Browser-Layout-Quirks.

XML-DTD-/Entity-Deklarationen und externe DTDs/Entitäten sind beim Parsing nicht
implementiert. Solche XML-Eingaben liefern `parsererror`; vorhandene DOM-Doctype-
IDs können vom XML-Serializer ausgegeben werden. Namespace-Fixup und seine
bewussten API-/Standardgrenzen sind im obigen Abschnitt geprüft.

HTML-Interfaces reflektieren die tatsächlich implementierten DOM-/Host-Operationen. Netz-, Medien- oder Font-Ladezustände werden dadurch nicht künstlich als verfügbar ausgewiesen. Die Detailalgorithmen aller Legacy-HTML-Interfaces und vollständige WebIDL-Eigenschaftsüberschreibung sind weitere Konformitätsarbeit. Eine vollständige Iframe-Navigation mit Realm-Wechsel benötigt zusätzlich die Ereignis-/Ressourcenmigration des Runtime-Hosts.

Die auf Navigation basierende URL-Reflexion ist kein vollständiger Ersatz für alle Browser-URL-Algorithmen. Insbesondere die vollständigen Frozen-Base-URL-Regeln in Detached-Dokumenten sowie XML-Base-/exotische URL-Fälle benötigen weitere Konformitätsarbeit.

Referenzen: [DOM Standard](https://dom.spec.whatwg.org/), [HTML DOM-Interfaces](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html), [HTML Initial Insertion Mode](https://html.spec.whatwg.org/multipage/parsing.html#the-initial-insertion-mode).
