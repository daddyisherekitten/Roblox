# CSSOM: Stylesheets und Regeln

## Typed OM: Ausbau vom 8. Oktober 2026

Zusätzlich zum vorhandenen skalaren Profil besitzen `CSSMathValue`, Sum,
Product, Negate, Invert, Min, Max und Clamp ihre tatsächlichen numerischen
Operationen, Typalgebra und Prototypen. `CSSNumericArray` hält dieselben
Kindobjekte; Änderungen an deren `value` wirken auf spätere Konversionen.
Getter-only-Indizes verwenden den gemeinsamen Plattformobjektpfad;
Expando-Descriptors und Iteration bleiben getrennt von den Mitgliedern.
`add/sub/mul/div/min/max`, `type`, `equals` und `toSum` verwenden Dimensionen
und absolute Einheitenskalen. Prozent-, Font- und Viewportbasen werden nicht
erfunden; nicht auflösbare Konversionen werfen. Gleichheit bleibt strukturell
und numerisch exakt.

`CSSUnparsedValue` und `CSSVariableReferenceValue` erhalten rohe Segmente,
verschachtelte Fallbacks, Iteration, USVString-Konversion und lebende
Indexsetter. Der Index an `length` hängt an, größere Indizes werfen
`RangeError`. Expando-Descriptors, readonly `length`, fehlender Indexdeleter
und nicht verhinderbare Erweiterbarkeit verwenden Plattformobjektregeln.
Variable-Mutationen laufen über denselben bestehenden Deklarations-/Kaskadenpfad.
Math-Werte lassen sich auf `attributeStyleMap` schreiben; ungültige Dimensionen
verändern die vorherige Deklaration nicht.

Kaskade und Typed OM erkennen `var()` als decodierten Funktionstoken:
Groß-/Kleinschreibung und Escapes sind berücksichtigt. Zeichenfolgen,
Kommentare, Hash-/At-Schlüsselwörter, Dimensionen und unquoted URL-Tokens
erzeugen keine Variablenkanten. Ungültige `var()`-Grammatik ersetzt keine
vorherige gültige Deklaration; erst nach Substitution ungültige Werte behalten
den vorhandenen Unset-Pfad.

Nachweise: `JavaScriptTypedMath` vergleicht sechs gespeicherte native Chromium-
Fixtures und zusätzliche Typ-, Index-, Live-Map- und Zyklusfälle;
`JavaScriptTypedOM` prüft weiterhin das skalare Profil. `Stylesheet` prüft die
echten Kaskaden-/Renderpfade für Escapes, Ketten, Zyklen, Literale und ungültige
Referenzen. Der native Unparsed-Append-Probe lief im installierten Chromium
in ein Timeout; dessen Indexfälle sind deshalb ausdrücklich normative
Semantiktests, keine gespeicherten Browser-Rückgaben.

Budgets: 256 Math-Mitglieder und
algebraische Terme, 64 Rechentiefe, 4096 Unparsed-Segmente, 32 Parse-/64
Serialisierungsebenen und 64 KiB serialisierter Wert; vorhandene VM-Budgets
bleiben wirksam. Diese Grenzen sind Hostprofile. Grundlage:
[CSS Typed OM](https://drafts.css-houdini.org/css-typed-om-1/).

`CSSNumericValue.parse` reifiziert Zahlen, Dimensionen, Prozentwerte sowie
`calc`, `min`, `max` und `clamp`. Dieselben CSS-Zahl-/Escape-/Kommentartokens
werden schon von Geometry Interfaces verwendet. Konstante passende Terme
werden vereinfacht; relative Einheiten und unauflösbare Produkte bleiben
strukturierte Werte. Ungültige Grammatik/Typen erzeugen `SyntaxError`, ohne
VM-Budget-/Lifecyclefehler zu verschlucken.

`CSSTransformValue` und Translate, Scale, Rotate, Skew/SkewX/SkewY,
Perspective und MatrixComponent besitzen numerische Member, Indexsetter,
lebende Iteration, Stringifizierung und `toMatrix`. Relative Längen und
Prozente dürfen in deklarierte Transformationen geschrieben werden;
Matrixkonversion ohne erforderlichen Größenkontext wirft. MatrixComponent
kopiert die Konstruktorquelle, erhält den Matrixsetter und berücksichtigt
seinen expliziten 2D-/3D-Schalter. Schreiben/Lesen von `attributeStyleMap`
läuft über die vorhandene Deklaration und Reifizierung, ohne neue Renderloop.

`JavaScriptTypedTransforms` belegt sieben gespeicherte native Chromium-
Sequenzen für Komponenten, Mutationen, Matrixwerte, Fehler, Transformation-
und numerisches Parsing sowie Prozent-Hints. Die Komponentenfixture lässt
den abweichenden Chromium-`toMatrix().is2D`-Rückgabewert aus: Chromium 154
kennzeichnet etwa Perspective und Translate3d mit Z=0 als 2D; die Engine
verwendet die explizite Dimension nach Typed OM. Chromium lässt außerdem
einzelne Define-/Set-Aufrufe auf getter-only NumericArray-Indizes zu,
während die normativen Web-IDL-Tests diese ablehnen. Diese Unterschiede
sind keine behauptete Browserparität.

Weitere C07-Arbeit: übrige Math-Funktionen und jede propertiespezifische
Reifizierung, Typed-Colorfamilien und Vollabgleich aller Plattform-
Descriptors/Methoden. Transformlisten sind auf 256 Komponenten begrenzt;
die numerische Parse-Tiefe bleibt 64 und der Token-/Ausdruckspfad begrenzt.
Inline-/Computed-Maps erfüllen `SameObject`; die DOM-Besitzer halten die
zugehörigen realmbezogenen Maps. Die Runtime hält entfernte Bäume dabei nur
schwach und entfernt ihre privaten Slots beim Abbau. Der gemeinsame
`computedStyleMap`-Methodenwert berücksichtigt den tatsächlichen Receiver.

Review vom 9. Oktober: Matrixkonversion und Transformparser verwenden
festgehaltene intrinsische Konstruktoren/Getter. Änderungen an globalen
`DOMMatrix`-/Transformkonstruktoren oder an öffentlichen Matrixgettern
verfälschen diese internen Schritte nicht. `JavaScriptTypedTransforms` prüft
Overrides und ihre Rücknahme. Die DOM-Wrapperzuordnung ist schwach; erreichbare
Knoten besitzen ihren Wrapper und die SameObject-Maps. `JavaScriptRealmLifetime`
belegt die Freigabe eines entfernten Knotens samt Maps auch bei weiter aktiver
Runtime sowie den Erhalt ausdrücklich gehaltener Knoten. Dies ist kein Nachweis
für die Freigabe sämtlicher anderer DOM-Caches und Ressourcenfamilien.

Stand: 5. Oktober 2026. Dies ist das implementierte CSSOM-Profil für den vorhandenen HTML-/CSS-Renderer. Vergleich 08 ergänzt weitere Regelfamilien, Shadow-Adoption und dynamische Kaskade/Inhalte. Der [Ausbau vom 5. Oktober](JAVASCRIPT-CSS-ANIMATIONS-20261005.md) ergänzt verschachtelte Stilregeln, `CSSNestedDeclarations` und montierte Cascade-/Inhaltsregressionen. Die vollständige CSSOM-Familie bleibt ein Ausbauziel. Grundlage sind [CSSOM](https://drafts.csswg.org/cssom/) und die [Web-IDL-Regeln für Plattformobjekte](https://webidl.spec.whatwg.org/).

## Erreichbare Oberfläche

| Bereich | Implementiert |
| --- | --- |
| Dokument und Eigentümer | Lebendes `document.styleSheets`, `style.sheet`, geladene lokale `link.sheet`; DOM-Reihenfolge, Entfernen/Wiedereinfügen und neue Blätter nach Style-Textänderungen |
| StyleSheet / CSSStyleSheet | `type`, `href`, `ownerNode`, `parentStyleSheet`, `title`, `disabled`, `media`, `ownerRule`, `cssRules`; `insertRule`, `deleteRule`, `replaceSync`, Promise-basiertes `replace` |
| Konstruktion | `new CSSStyleSheet(options)` mit Dictionary-Konvertierung, `media`, `disabled` und `baseURL`; nur konstruierte Blätter können ersetzt oder übernommen werden |
| Adoption | Lebendes ObservableArray `document.adoptedStyleSheets`: Zuweisung und Arrayoperationen, Typ-/Realmprüfung, definierte Index-/Längen-/Descriptorregeln; übernommene Blätter folgen den regulären Blättern |
| Regeln | `CSSRule`, `CSSStyleRule`, `CSSNestedDeclarations`, `CSSGroupingRule`, `CSSConditionRule`, `CSSMediaRule`, `CSSSupportsRule`; `type`, `cssText`, Elternbeziehungen, `selectorText`, `style`, lebende innere `cssRules`, Einfügen/Löschen und Bedingungen |
| Sammlungen | `CSSRuleList`, `StyleSheetList`, `MediaList`: stabile Identität, lebende Indizes, `length`, `item`, Iteration; MediaList zusätzlich `mediaText`, `appendMedium`, `deleteMedium` |
| Deklarationen | Ein gemeinsamer `CSSStyleDeclaration`-Typ für Inline-, Regel- und berechnete Styles; `cssText`, `length`, `item`, `parentRule`, Propertyzugriff, `getPropertyValue/Priority`, `setProperty`, `removeProperty` |

Inline- und Regelblöcke bewahren Deklarationsreihenfolge und Prioritäten. Die vorhandenen CSS-Eigenschaften werden mit dem Engineparser validiert. Die zunächst vollständig expandierten Kurzformen sind margin, padding, border-width/color/style, gap und overflow; dies ist noch keine vollständige Browser-Kurzformfamilie. Berechnete Styles bleiben lebend und schreibgeschützt. Methodenausleihe und `instanceof CSSStyleDeclaration` verwenden für alle drei Arten dieselbe Schnittstelle.

HTMLStyleElement/HTMLLinkElement spiegeln media, type und title; Linkelemente zusätzlich rel, href und das boolesche disabled-Attribut. Link-URLs werden gegen die Dokumentbasis aufgelöst. `style.disabled` und `sheet.disabled` steuern den Zustand des zugehörigen Blatts. Änderungen an `sheet.media` schreiben kein HTML-Attribut um.

## Darstellung, Mutationen und Lebensdauer

CSSOM besitzt eigene Regelobjekte. Eine Regeländerung verändert weder `style.textContent` noch die DOM-Mutationsberichte. Ändert JavaScript stattdessen den DOM-Text eines Style-Elements, entsteht ein neues zugeordnetes Stylesheet; gehaltene alte Blätter und Regeln bleiben lesbar. Gelöschte Regeln behalten ihren Inhalt und verlieren die entsprechende Blattzuordnung.

Der Renderer kompiliert geänderte Blattquellen und gleicht berechnete Styles in Elternreihenfolge ab. Nur tatsächliche geometrische Änderungen markieren Layoutabhängigkeiten. Farben und ungenutzte Custom Properties brauchen kein Layout. Vorhandene GUI-Objekte, Listener und Eingabewerte bleiben erhalten. Mediaaktivierung, Viewporteinheiten, Selector-Caches und die Reihenfolge übernommener Blätter sind angebunden.

Nachträglich eingeführte Rahmen erzeugen ihre benötigten Zeichenflächen auch auf bereits vorhandenen Boxen. Der Abgleich wechselt zwischen nativen Strokes und gemusterten Randstreifen und entfernt ersetzte Rahmen-/Corner-Ressourcen. Die Box und ihre Eingaben bleiben erhalten; reine Rahmenfarbänderungen verwenden dieselben Flächen ohne Layout. Die ausgelieferte Scope-Karte prüft den tatsächlichen 2-Pixel-Stroke, die CSSOM-Renderingregression zusätzlich Hinzufügen, Entfernen, Musterwechsel, Alpha und kombinierte Opacity.

Es gibt keine neue permanente Frameverbindung oder Abfrage pro Element. Quellensuche wird durch relevante DOM-Mutationen ungültig. Private Objektzustände und schwache Registries berücksichtigen, dass Luau keine Ephemeron-Tabellen besitzt. Auch der gemeinsame VM-Owner-Lookup hält weder Objekte noch Realms fest: Ein gehaltenes Objekt besitzt seine Konvertierungslaufzeit privat, eine freigegebene Seite wird gesammelt. Der Seitenabbau trennt den Provider, löscht Zustände und verhindert die spätere Veröffentlichung wartender Ersetzungen.

## Grenzen

- Regeln und Deklarationen verwenden den unterstützten CSS-/Selektor-/Media-Teilumfang. `CSSStyleRule.cssRules` enthält verschachtelte Stil-/Gruppenregeln und spätere Deklarationsläufe als `CSSNestedDeclarations`. Verschachtelte Regeln lassen sich einfügen, löschen und ändern; Selektorkontext, Spezifität, Quellreihenfolge und Elternbeziehungen bleiben erhalten. Vollständige Escape-/Namespace-/Wertegrammatik, sämtliche Regelhierarchieprüfungen, nackte Deklarationen über `insertRule()` und Shadow-Spezialselektoren innerhalb des durch Nesting erzeugten `:is()` bleiben offen.
- Spezialisierte Regeln für Keyframes, FontFace, Page/Margin, Import/Namespace, Layer, Container, Scope, StartingStyle, Property, CounterStyle und FontPaletteValues besitzen native Prototypen und ihr dokumentiertes editierbares Profil. Nicht jede neue Regelfamilie und Descriptorgrammatik ist vollständig umgesetzt. Fontdatei-Laden, Print-/Page-Layout und Font-Palette-Rasterisierung sind keine Folge der CSSOM-Schnittstelle.
- `@import` lädt über den CSS-Hostgraphen auch verschachtelte Ressourcen und stellt eigene Importblätter mit Eltern-/OwnerRule-Identität bereit. Deren Regel-/Disabled-/Medienänderungen erreichen den Renderer. `insertRule` lädt Imports asynchron; `deleteRule` entfernt ihre Wirkung und bricht ausstehende Untergraphen ab. Gehaltene bereits geladene Importblätter bleiben lesbar. Konstruierte Blätter lehnen Importregeln ab, `replace`/`replaceSync` entfernen sie. Verknüpfte Blätter sind bei einer erfolgreichen Hostquelle zugeordnet. Hostmetadaten setzen den Origin-clean-Schutz für Regelzugriff/-mutation; der Transport ermittelt die tatsächlichen CORS-/Fetch-Rechte. [CSS-Ladeprofil, Abbruchprofil und erhaltene Referenzunterschiede](HTML-PARSER-ATTRIBUTES-20261006.md#verknüpfte-stylesheets-und-skriptbarrieren--9-oktober-2026).
- `replace()` wird als vorhandene Ereignisschleifenaufgabe ausgeführt, mit Änderungssperre und anschließender Promise-Reaktion. Die genaue Dauer gegenüber Chromium hängt vom Host ab.
- Adoption unterstützt Dokument und Shadow Roots einschließlich eines gemeinsam genutzten konstruierten Blatts. Übernahme aus fremden Dokumenten bleibt abgewiesen.
- Dynamische Counter/Pseudoelemente, Keyframeänderungen mit erhaltener Uhr, Layer-/Scope-Kaskade, registrierte Custom Properties und Eintrittsübergänge sind angebunden. Vollständige Fragment-/Inline-Topologie und alle Motionkombinationen sind weiter offen. Eingebettete SVG-Kaskaden bleiben separat.
- `baseURL` wird konvertiert und gespeichert; die vollständige Auflösung relativer URLs in neu konstruierten Regeln bleibt offen. Konstruierte `href` folgt dem geprüften Chromium-Profil (`null`).

Budgets: 1 MiB CSS-Quelle pro Operation, 4096 Regeln pro Parse/List, 4096 Properties pro Deklarationsblock, 32 Verschachtelungsebenen, 256 Mediazweige, 4096 übernommene Blätter und 16384 gehaltene CSSOM-Kernobjekte. Hinzu kommen die vorhandenen VM-, DOM- und Attributbudgets. Das sind Hostgrenzen, keine Browserstandards.

## Prüfung und Wiederfinden

Vergleich 04 zeigt fünf kombinierte Karten: Regeln/Selektoren, Deklarationen/Prioritäten, Media/Supports, Konstruktion/Adoption/Promise und Eigentümer/Lebensdauer. Tobias hat diesen Sichtvergleich bestätigt. Sein unveränderter Quelltext bleibt unter `tests/fixtures/javascript-cssom-review-page.json` geprüft. Vergleich 08 ist ebenfalls eine historische Regression; dessen [Erweiterungsprofil](JAVASCRIPT-DOM-CSS-EXTENSIONS.md) ordnet seine Module und Grenzen zu. Der neue Vergleich 10 verwendet Nesting/CSSOM auf der [Atelier-Seite](http://localhost:8000/browser-foundations/index.html). Die vorherige Range-Seite liegt in `tests/fixtures/javascript-range-review-page.json`.

| Datei | Aufgabe |
| --- | --- |
| `src/HTMLEngine/JavaScript/CSSOM.luau` | Interfaces, Parserprofil, Zuordnung, ObservableArray und Lebensdauer |
| `src/HTMLEngine/JavaScript/CSSOMRules.luau`, `CSSOMDescriptors.luau` | Zusätzliche Regelprototypen und Descriptorparser |
| `src/HTMLEngine/JavaScript/CSSDeclarations.luau` | Gemeinsame Deklarationsblöcke, Priorität und Serialisierung |
| `Runtime.luau`, `DOM.luau`, `Geometry.luau` im selben Verzeichnis | Realm-, DOM-/Inline- und berechnete Style-Anbindung |
| `src/HTMLEngine/CSS/Stylesheet.luau` | Gemeinsame Quellensuche und Kompilierung der Overlays |
| `src/HTMLEngine/CSS/Nesting.luau`, `ScopeRules.luau`, `Selectors.luau` | Verschachtelte Deklarationsläufe, relative Selektoren, Spezifität, Scope-Grenzen und forgiving Selektorlisten |
| `src/HTMLEngine/Rendering/HTMLScripts.luau`, `RenderTree.luau`, `DOMReconcile.luau` | Provider, gezielter Styleabgleich und Metadatamutationen |
| `tests/JavaScriptCSSOM.luau` und `scripts/test-javascript-cssom.cjs` | Semantik, native Referenzfälle, Fehler und Aufräumen |
| `tests/JavaScriptRealmLifetime.luau` | Tatsächliche Luau-GC-Freigabe geschlossener Seiten und Konvertierungslaufzeit extern gehaltener Objekte |
| `tests/JavaScriptCSSOMRendering.luau` | Tatsächliche Paint-/Layoutwege, Kontrolleingaben, Media, URLs und Objektidentität |
| `tests/JavaScriptCSSOMReviewPage.luau` | 19 native Browserzustände gegen den identischen Seitenquelltext im Roblox-Renderingtest |

Die Renderingregressionen verwenden den tatsächlichen Parser, die VM und die Layout-/Paintlogik mit ersetzten Roblox-GUIs und Textmaßen. Die Referenzzustände stammen aus dem nativen Chromium. Ein Sichtvergleich direkt in Roblox Studio bleibt zusätzlich bei Tobias; diese Tests sind keine Studio-Screenshots und keine FPS-Messungen.

Die native Referenz enthält sechs ausdrücklich getrennte Standardabweichungen des installierten Chromium: Es liest das neue `baseURL`-Dictionaryfeld nicht; eine leere Deklaration mit ungültiger Priorität bleibt dort stehen; `removeProperty` liefert für die getestete Kurzform eine leere Rückgabe. Außerdem verkürzt es Deklarationen über eine dazwischenliegende logische Property hinweg, besitzt noch nicht die aktuelle `CSSStyleRule`-/`CSSGroupingRule`-Vererbung und wirft bei einem leeren Indexdescriptor des ObservableArray einen Konvertierungsfehler. Die Engine folgt hier den aktuellen CSSOM-/Web-IDL-Algorithmen. Unterschiede sind auf die konkreten Rückgaben begrenzt und keine pauschal freigestellten Testgruppen. Weitere Host-/Parsergrenzen stehen oben.

## ShadowRoot-Quellen und Adoption

`Document` und jeder offene oder geschlossene `ShadowRoot` besitzen getrennte, lebende `styleSheets`-Listen und identische `adoptedStyleSheets`-ObservableArrays pro Root. Dokument-Stylesheets umfassen keine Schatteninhalte. Ein konstruiertes Blatt desselben Dokuments kann gleichzeitig in mehreren Roots verwendet werden; eine Regeländerung wirkt auf alle Adoptionen. Die Entfernung aus einer Root-Liste verändert die anderen Listen nicht.

Die Quellenprojektion und synthetische Rendererquellen sind pro Root getrennt. Verschobene Style-Elemente verlieren die bisherige Zuordnung und erhalten im neuen Root ein neues Blatt. Abgetrennte Style-Teilbäume geben die Zuordnung frei; die gehaltenen Root-Adoptionslisten bleiben erhalten. Fremde Konstruktor-Dokumente werden mit `NotAllowedError` zurückgewiesen. Beim Realm-Cleanup werden die privaten Arrayhandler sämtlicher Roots, Adoptionszählungen und Quellenbindungen entfernt.

`tests/JavaScriptShadowCSSOM.luau` prüft getrennte Quellenlisten, mehrfach adoptierte Blätter, Arrayänderungen, Verschieben, Abtrennen/Wiedereinfügen, Dokumentprüfung und Lebensdauer. Die vorhandenen CSSOM-Semantik- und Rendererregressionen bleiben aktiv.

`tests/JavaScriptCSSOMRules.luau` prüft 53 tatsächliche Browserreferenzen der neuen Interfaces. Der separate CSSOM-Runner besitzt jetzt 20 Semantikfixtures, darunter fünf neue Chromium-Nestingfälle. `CSSRuleFamilies`, `GeneratedContentRendering`, `JavaScriptComponentsRendering`, `JavaScriptPseudoContent` und die ausgelieferte `JavaScriptComponentsReviewPage` prüfen zusätzlich den sichtbaren Kaskaden-/Inhaltsabgleich. Unterstützte Shadow-Selektoren bleiben auch in konstruierten Blättern erhalten, bevor diese einem Root zugeordnet werden. Die bekannten Grenzen für verschachtelte Shadow-Spezialselektoren stehen oben.

Nachträglich hinzugefügte Rahmen erhalten ihre native Fläche über `Rendering/BorderBox.update`, auch wenn die Box ursprünglich keinen Rahmen hatte. Ein Wechsel zwischen keinem Rahmen, UIStroke, Hintergrund-Overlay und gemusterten Kanten ersetzt nur die Rahmenflächen. `JavaScriptCSSOMRendering` prüft diese Übergänge einschließlich Alpha, Gruppentransparenz, Farbe und Unadoption mit erhaltenem Eingabewert/Boxen; Vergleich 08 prüft den tatsächlichen Stroke der konstruierten `@scope`-Regel.
