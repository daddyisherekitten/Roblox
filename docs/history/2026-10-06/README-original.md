# Roblox HTML Engine

Aktueller Prüfstand vom 2. Oktober 2026: [Gesamtprüfung, Modulmatrix und Reparaturen](docs/audit-2026-10-02/README.md).
Die dortige Verifikation trennt aktuelle Tests von historischen Supportangaben in den folgenden Abschnitten.
JavaScript-Ausbau vom 5. Oktober: [Browser-Grundlagen, Bestand und genaue Grenzen](docs/JAVASCRIPT-FOUNDATIONS-20261005.md) und [API-Register](docs/JAVASCRIPT-API-REGISTER.md). Aktuelle Seiten: [Spielraum](http://localhost:8000/main/index.html), [Memory](http://localhost:8000/memory/index.html) und [Hangman](http://localhost:8000/hangman/index.html).
FPS und den nativen Sichtvergleich übernimmt Tobias.

Eine wiederverwendbare Engine im Aufbau: HTML-Grundparser, Elementbaum und Darstellung mit einfachen CSS-Regeln und Inline-Styles.
Der weitere Ablauf und unsere festen Regeln stehen in [PLAN.md](PLAN.md). Die HTML-JavaScript-Laufzeit erreicht die dokumentierten P01–P17-Profile; vorhandene Funktionen und offene Unterfamilien stehen im aktuellen Implementierungsstand.

`rojo serve` synchronisiert dauerhaft alle drei Demo-Scripts unter `StarterPlayer > StarterPlayerScripts`:
`HTMLPageDemo`, `FontLabDemo` und `FontComparisonDemo`. Nur die in `examples/StudioDemoConfig.luau` gewählte Demo startet.
`StudioDemoConfig` enthält ausschließlich `ActiveDemo = "HTMLPage"`. Die Website wird nur über `local WEBSITE = "Main"` in `examples/HTMLPage.client.luau` gewählt; `"Memory"` oder `"Hangman"` startet das jeweilige Spiel direkt. Für das Schriftlabor in der Demo-Konfiguration `ActiveDemo = "FontLab"`, für alle Schriften `"FontComparison"` wählen und **Stop → Play** drücken. Die SVG-Etappe wird direkt mit `local stage` in `examples/SVGLab.client.luau` gewählt.
Die aktuell ausgewählte Seite stammt aus browserfertigen Dateien unter `examples/websites`; das Roblox-Modul unter `src/HTMLEngine/Websites` wird daraus generiert.

Der aktive Website-Katalog enthält die Spiele-Hauptseite **spielraum.**, Memory mit 6/8/12 Paaren, Pause, Uhr und persönlichen Rekorden sowie Hangman mit vier Wortkategorien, Tastaturbedienung und einem Tipp pro Wort. Alle besitzen getrennte `HTML`-, `CSS`- und `JavaScript`-ModuleScripts; der Browser lädt denselben JavaScriptcode als `app.js`. Die bisherigen sichtbaren Beispiel- und Testseiten sind entfernt. Engine-Regressionen verwenden ihre nicht ausgelieferten Quellen unter `tests/fixtures/retired-websites.json`. Details: [Website-Module](docs/WEBSITES.md).
Mit `python scripts/serve-websites.py` sind diese Dateien zusätzlich über echte
lokale URLs ab `http://localhost:8000/` erreichbar.
Der SVG-Test besitzt zusätzlich die portable Browserdatei
[supported-svg-stress-3.html](examples/svg-tests/supported-svg-stress-3.html).
Das LocalScript enthält nur den Namen des zu startenden Moduls; HTML, CSS und
Seitenoptionen bleiben im jeweiligen Website-Modul.
Roblox wertet die CSS-Regeln im head aus und verwendet seine registrierten Fontfamilien.
Separates CSS kann über `options.CSS` als String übergeben werden, zusätzlich zu CSS im HTML. Externe Stylesheet-URLs und Fontdateien lädt die Engine noch nicht. Google-Fontversionen können von den lokalen Laborreferenzen abweichen.
Die alte sichtbare Testsammlung wurde auf Nutzerwunsch komplett ersetzt.
Bei allen unterstützten CSS-Längen sind jetzt auch em/rem möglich; ältere Einschränkungen dazu in den folgenden Abschnitten entfallen.

Engine-Dokumentation: [Formulare, Eingabe und Hit-Test](docs/FORMS.md), [relative CSS-Längen em/rem](docs/RELATIVE-LENGTHS.md), [Ergänzungen mit mittlerem Aufwand](docs/MEDIUM-ADDITIONS.md), [Listen und Dekoration](docs/LIST-DECORATION-EXTENSIONS.md), [Positionierung](docs/POSITIONING.md), [Scrollbereiche](docs/SCROLLING.md) und [Rahmenkanten](docs/BORDER-SIDES.md).
Automatische Regressionstests und das separate Schriftlabor bleiben erhalten.
Die Kombinationsprüfungen vom 1. Oktober 2026 verbinden verschachtelte Block-,
Flex- und Gridlayouts mit wiederholtem Resize, Bildern, SVG, Canvas, Video,
Iframes, Hover/Fokus, Übergängen, Transparenz und Scrollbereichen. Ersetzte
Elemente sind jetzt im selben Zustands- und Animationsbaum registriert wie
gewöhnliche Blockboxen. Positionierungswechsel aktualisieren ihre Bezugsboxen,
Viewport-Ebenen und benötigten Scrollverbindungen; gewöhnlicher Link-Hover
ändert keine GUI-Eltern und löst kein Seitenlayout aus.

Die fünf Tests `CombinationStates`, `CombinationPositioning`, `CombinationLayout`,
`CombinationScrolling` und `CombinationPainting` laufen mit
`node scripts/run-html-tests.cjs` zusammen mit den bestehenden Regressionen.
Sie prüfen mehr als 170 Kombinationen beziehungsweise Zustandswechsel mit
echtem Parser, CSS und Layout, aber substituierten Roblox-GUIs/Textmaßen.
Das ist keine Garantie für alle CSS-Kombinationen oder eine native Sichtprüfung.
Grenzen und Verhalten stehen unter [Positionierung](docs/POSITIONING.md),
[Scrollbereiche](docs/SCROLLING.md) und [Sichtbarkeit](docs/VISIBILITY.md).

Formularausgaben nutzen jetzt ein [Dirty-Layout mit Teilbaum-Wiederverwendung](docs/DIRTY-LAYOUT.md).
Auch unveränderte Scroll-/Transparenzbereiche und eigenständige Positionierungscontainer werden wiederverwendet.
Die Debug-Ausgabe unterscheidet partielle Änderungen und vollständiges Resize-Layout.
Unterstützung und Grenzen des Flexlayouts: [Flexbox](docs/FLEXBOX.md).
Die früheren sechs Abschlussblöcke stehen in [CSS-Abschlussblöcke](docs/CSS-FINAL-BLOCKS.md). Der sichtbare Katalog enthält jetzt `main` und `memory`.

Vorübergehende Testhilfe: Das Roblox-Testfenster startet mit 480px Breite. Die vier
blauen Eckgriffe ändern Breite und Höhe durch Ziehen, mindestens 240×180px soweit
der Bildschirm Platz bietet. Die gegenüberliegende Ecke bleibt stehen. Die Hilfe
liegt separat in `examples/ResizableTestWindow.luau`; das HTML hat keine feste
480px-Begrenzung mehr, damit seine Inhalte auf die Fensterbreite reagieren.

## JavaScript: Ausbau und Vergleich (5. Oktober 2026)

Die zentrale [JavaScript-Roadmap](docs/JAVASCRIPT-ROADMAP.md) enthält die genaue
Bestandsaufnahme und 18 Ausbaupakete für Sprache, Standardbibliothek,
DOM und Browser-APIs. Der maßgebliche aktuelle Bestand mit Modulen, Prüfungen
und offenen Grenzen steht in [JAVASCRIPT-IMPLEMENTATION.md](docs/JAVASCRIPT-IMPLEMENTATION.md).
Die Async-/Await-Vergleichsetappe ist vom Nutzer bestätigt.

`Engine.mountHTML` führt klassische Inline-Skripte am Ende des `body` einmal aus.
Die Realm bleibt bei Resize, CSS-Zustandswechseln und Layout erhalten. Mit
`{JavaScript = false}` lässt sich diese HTML-Laufzeit abschalten; Kindseiten
übernehmen die Abschaltung. Iframes ohne `allow-scripts` im vorhandenen
`sandbox`-Attribut führen ebenfalls keine HTML-Skripte aus.

Die früheren JavaScript-/Atelier-Vergleiche liegen jetzt als Regressionstestdaten
unter `tests/fixtures/retired-websites.json`. Vergleich 09 prüft Sprache,
Dokumente/Tabellen, Shadow-Formkomponenten, Editing/Auswahl und native Eingaben.
Vergleich 10 kombiniert Nesting/CSSOM, Hover, Bild-/Fontladen,
Unicode/URL/Sommerzeit und Speicher. Diese Seiten sind nicht mehr veröffentlicht.
Vergleich 08 bleibt eine eingefrorene dynamische Komponenten-/CSS-Regression.
Umfang, Prüfungen und konkrete Grenzen stehen im
[DOM-/CSS-Erweiterungsprofil](docs/JAVASCRIPT-DOM-CSS-EXTENSIONS.md).
Tobias hat die gezeigten Studio-Fälle von Vergleich 07 nach den Script-/Worker-
Hostkorrekturen bestätigt; dies ist keine vollständige Worker-Konformitätsprüfung.
Der Ausbau erreicht P17; offene Unterfamilien stehen weiter in der Roadmap.
Die früheren Vergleiche
bleiben erhalten und werden anhand ihrer eingefrorenen Seiten geprüft.
Die Laufzeit ergänzt außerdem unter anderem synchrone
Iterator-Helfer, gewöhnliche TypedArray-Propertydeskriptoren, NodeFilter/
NodeIterator/TreeWalker, lebende Namens-/Namespace-Abfragen, Raw JSON und
DOMPoint/DOMMatrix/DOMQuad mit StructuredClone. Native Property-Definitionen
bleiben auch bei verändertem Object.prototype unabhängig von Autor-Gettern.
Ältere Regressionen lesen ihren eingefrorenen Stand unter
`tests/fixtures/javascript-labor-classic.html` und `.css`.

Historischer erster Unterbau: Die folgenden Detailpunkte und damaligen Grenzen
beschreiben den anfänglichen Ausbau. Maßgeblich für den aktuellen Funktionsumfang
ist [das Implementierungsregister](docs/JAVASCRIPT-IMPLEMENTATION.md).

Damals implementiert:

- Ein gemeinsamer AST-Interpreter unter `JavaScript/` für HTML, SVG und Canvas;
  die bisherigen SVG-Modulpfade bleiben als Weiterleitungen bestehen.
- Begrenzte Sprache: `var`/`let`/`const`, Funktionen/Closures, Bedingungen,
  Schleifen mit `break`/`continue`, Arrays/Objektliterale, Aufrufe mit `this`, grundlegende eigene
  Konstruktoren/Prototypzugriffe; ausgewählte Array- und Stringmethoden.
  Zeichenpositionen und `length` zählen UTF-16-Einheiten. Groß-/Kleinschreibung
  umfasst zunächst ASCII und Latin-1 inklusive Umlauten/ß.
- `window`, `self`, `globalThis`, `document`, `console`, ausgewählte `Math`-Methoden;
  getrennte Seitengültigkeit und `DOMContentLoaded` nach den unterstützten Skripten.
- Zeitsteuerung im HTML-Realm: `setTimeout`/`setInterval`, `clearTimeout`/
  `clearInterval`, `queueMicrotask`, `requestAnimationFrame`/
  `cancelAnimationFrame` und `performance.now()`. Timer teilen einen ID-Raum,
  unterstützen zusätzliche Callback-Argumente und Quelltext-Handler. Verschachtelte
  Timer verwenden den 4-ms-Mindestabstand nach Nesting-Level 5. Microtasks laufen
  FIFO, auch bei weiteren Microtasks, sobald der JS-Stack leer ist; DOM-Änderungen
  bleiben bis zum Ende dieses Checkpoints gebündelt. Grundlage sind die
  [HTML-Timer/Microtasks](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html)
  und [Animation Frames](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#animation-frames).
  Frame-Callbacks erhalten denselben Zeitstempel je Bild; dort neu angeforderte
  Frames warten auf das nächste Bild. `performance.now()` teilt ihren Zeitursprung.
  `JavaScript/EventLoop` hält die datenbasierten Warteschlangen;
  `Rendering/ScriptClock` verwendet einen einzigen anstehenden Roblox-Timer und
  eine RenderStepped-Verbindung nur bei anstehenden Frame-Callbacks. Layoutjobs
  sperren den Treiber bis zur fertigen Seite. Reine Frame-Darstellungsänderungen
  werden vor dem Bildaufbau angewendet, Größenänderungen nutzen den Dirty-Tree.
  `Rendering/ScriptTransforms` aktualisiert reine native 2D-`transform`-Änderungen
  direkt am bestehenden Element: eine lokale Stilberechnung statt einer Cascade
  der gesamten Seite, ohne Text-/Hintergrundneuzeichnung oder Cache-Neuzuordnung.
  Resize verwendet weiterhin den neu berechneten Layoutanker. Style-Selektoren,
  explizite Transform-Vererbung, CSS-Motion am Element, 3D-Szenen, Fixed/Sticky
  und Änderungen an positionierten Containing Blocks behalten den normalen Weg.
  Beim Seitenabbau werden Timer, Frame-Callbacks und Verbindungen freigegeben.
  Die früheren Abschnitte 07–09 liegen in der nicht ausgelieferten Classic-Fixture.
- Promise-Grundlage im HTML-Realm: `new Promise(executor)`, `Promise.resolve()`/
  `Promise.reject()`, `.then()`, `.catch()` und `.finally()`. Der Executor läuft
  synchron; Reaktionen und das Aufrufen fremder `then`-Methoden werden in derselben
  Microtask-Warteschlange wie `queueMicrotask` ausgeführt. Resolve/Reject lassen
  nur die erste Entscheidung zu, auch beim Warten auf eine andere Promise.
  Ketten übernehmen Rückgabewerte, weitere Promises/Thenables und geworfene Werte;
  fehlende Handler reichen Ergebnis oder Ablehnung weiter. `.finally()` wartet
  auf seine Rückgabe und erhält das ursprüngliche Ergebnis, solange die
  Aufräumfunktion weder wirft noch eine Ablehnung zurückgibt. Grundlage sind die
  [ECMAScript-Promise-Algorithmen](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-promise-objects)
  und die vorhandenen HTML-Microtask-Checkpoints. `throw` erhält den geworfenen
  Wert; einfache `Error`-/`TypeError`-/`RangeError`-/`ReferenceError`-/`SyntaxError`-
  Objekte bieten `name`, `message` und `toString()`. Relevante VM-Laufzeitfehler
  werden als `TypeError` oder `ReferenceError` in Ketten weitergegeben.
  Erst am Ende des Checkpoints weiterhin unbehandelte Ablehnungen werden
  diagnostiziert. Promise-Handler bündeln DOM-Änderungen im vorhandenen Dirty-Tree.
  Die Zustandsregistrierung ist schwach; beim Seitenabbau werden Ergebnis- und
  Handlerreferenzen sowie anstehende Jobs freigegeben. Es gibt keinen zusätzlichen
  Roblox-Timer oder Frame-Loop für Promises. Die früheren Abschnitte 10–11
  bleiben in der nicht ausgelieferten Classic-Fixture erhalten.
- Promise-Kombinationen: `Promise.all`, `allSettled`, `race` und `any` akzeptieren
  Arrays und primitive Strings. Ergebnisse und Ablehnungsgründe behalten die
  Eingabereihenfolge; Thenables und gewöhnliche Werte verwenden `Promise.resolve`.
  `all` wird beim ersten Fehler abgelehnt, `race` übernimmt den ersten Abschluss,
  `any` den ersten Erfolg. Die übrigen Aufgaben laufen weiter.
  `allSettled` sammelt `{status, value}` beziehungsweise
  `{status, reason}`. Leere Eingaben liefern bei `all`/`allSettled` leere Arrays,
  bei `any` eine Ablehnung mit `AggregateError.errors`; `race` bleibt offen.
  Strings werden nach Unicode-Codepoints iteriert. Das aktuelle `Promise.resolve`
  wird einmal gelesen; überschriebene `then`-Methoden und mehrfache Callback-Aufrufe
  werden berücksichtigt. Kein neuer Timer oder Frame-Treiber. Die früheren
  Abschnitte 12–13 und 16 liegen in der nicht ausgelieferten Classic-Fixture.
  Grundlage: [ECMAScript Promise-Konstruktor](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-properties-of-the-promise-constructor).
- `try/catch/finally`: Fehlerobjekte, Laufzeitfehler und beliebige geworfene Werte
  werden im eigenen Catch-Scope abgefangen; `catch {}` braucht keine Variable.
  Verschachtelte Blöcke und erneutes Werfen erhalten den ursprünglichen Wert.
  `finally` läuft vor `return`, `break` und `continue`; ein eigener Rücksprung
  oder Fehler ersetzt das vorige Ergebnis. `var` in den Blöcken wird im
  Funktions-/Programmscope vorab angelegt; Catch-Variablen bleiben lokal.
  Aufruftiefe wird beim Abfangen wiederhergestellt. Ein erschöpftes
  Instruktionsbudget oder eine abgebaute Realm kann durch Skript-Catch/Finally
  nicht wieder aktiviert werden. `AggregateError` ist mit und ohne `new`
  verfügbar und bietet `name`, `message`, `errors` und `toString()`.
  Die früheren Abschnitte 14–15 und 17 liegen in der Classic-Fixture. Grundlage:
  [ECMAScript try-Anweisung](https://tc39.es/ecma262/multipage/ecmascript-language-statements-and-declarations.html#sec-try-statement).
- Async-/Await-Grundlage im HTML-Realm: `async function` als Deklaration oder
  Ausdruck (auch benannt), async-Listener und `await` innerhalb dieser Funktionen.
  Jeder Aufruf liefert eine eigene Promise; der Anfang läuft synchron bis zum
  ersten Await. Werte/Thenables verwenden die intrinsische Promise-Auflösung,
  Fortsetzungen interne Promise-Reaktionen derselben Microtask-Warteschlange.
  Eigene `.then`-/`Promise.resolve`-Overrides steuern Await nicht um. Ablehnungen
  werden am Await-Punkt geworfen, sodass `try/catch/finally` sie verarbeitet.
  Lokale Variablen, `this`, Auswertungszwischenstände und wartende Finally-Blöcke
  bleiben erhalten; Rückgaben übernehmen weitere Promises. Async-Funktionen
  sind keine Konstruktoren und haben keine automatische `prototype`-Eigenschaft.
  Grundlage: [ECMAScript AsyncFunction/Await](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-async-functions-abstract-operations).
  `JavaScript/AsyncFunctions` hält pausierte Interpreter-Coroutines ohne
  Polling, neue Timer oder Frame-Verbindungen. Die VM teilt das aktuelle
  Instruktionsbudget mit synchronen Aufrufern; spätere Microtasks verwenden das
  normale Callback-Budget. Nur vor dem ersten Await zählen aktive Aufrufer zur
  gemeinsamen Stackgrenze. Suspensions erhalten ihre eigenen Tiefen-/Scope-Werte.
  Ein schwacher Index hält unreferenzierte Wartezyklen nicht dauerhaft fest;
  Seitenabbau deaktiviert Fortsetzungen und schließt pausierte Coroutines.
  DOM-Updates nutzen unverändert das bestehende Batching/Dirty-System. Die sechs
  sichtbaren Karten vergleichen Warten, Reihenfolge, Fehler/Finally, parallele
  Aufgaben, Neustart/Abbruch sowie Listener/this/Schleifen und Thenables.
- Stabile DOM-Identität, ID-/CSS-Abfragen, `textContent`, Attribute,
  `classList`, Inline-`style`, `hidden`, Formular-`value`/`checked` und `click()`.
  `querySelectorAll` liefert eine statische Sammlung mit `length`, Indexzugriff,
  `item()` und `forEach()` (noch kein vollständiger NodeList-Prototyp).
- Dynamische DOM-Grundlage: `createElement`, `createTextNode`,
  `createDocumentFragment`, `appendChild`, `insertBefore`, `removeChild` und
  `remove`. Vorhandene Knoten werden verschoben; ihre JS-Identität und Listener
  bleiben erhalten. Fragmente geben ihre Kinder ab. `children`/`childNodes`
  sind live, `querySelectorAll` bleibt statisch. Ungültige Referenzen und Zyklen
  werden vor dem Abhängen geprüft, entsprechend dem [DOM-Standard](https://dom.spec.whatwg.org/).
  Dokumentwurzeländerungen bleiben ausdrücklich außerhalb dieses Teilumfangs.
- Der strukturelle Abgleich unter `Rendering/DOMReconcile` baut betroffene
  Elternflüsse auf und verwendet vorhandene Boxen und native Formularfelder
  weiter. Der Dirty-Tree bekommt den Grund `children`; unveränderte Unterbäume
  behalten ihre Layout-Caches. Neue Felder werden an Input/Fokus/Formularmodell
  angeschlossen, entfernte Felder abgemeldet. Aktuelle Eingabewerte bleiben
  beim Verschieben und erneuten Einfügen erhalten. Entfernte GUI-, Treffer-,
  Text-, Animations- und Effektressourcen werden bereinigt. Der frühere Abschnitt
  06 in der Classic-Fixture vergleicht Einfügen, Fragment-Batches und Umsortieren.
- Listener mit Capture/Target/Bubble, `once`, `passive`, Entfernen,
  `preventDefault` sowie beiden Stop-Methoden. Native Klick-, Formular- und
  vorhandene Fokusereignisse sind angeschlossen. Ein Checkbox-/Radioklick sieht
  die neue Auswahl im Handler; ein abgebrochener Klick stellt sie wieder her.
- Sofortige DOM-Datenänderungen, anschließend eine gebündelte Render-Aktualisierung.
  Unabhängige Boxen/Formularfelder bleiben erhalten. Textänderungen bauen ihren
  Inline-Fluss neu auf. Reine Farbänderungen lösen kein Layout aus. Der CSS-Abgleich
  bleibt bei reinen Inline-Style-Änderungen lokal samt abhängigen Nachfahren,
  solange kein Selektor das `style`-Attribut liest. Andere DOM-Änderungen
  berücksichtigen konservativ auch Nachbarn und `:has`-Vorfahren; betroffene
  Geometrieänderungen markieren ihre Boxen im bestehenden Dirty-Tree. Unveränderte
  Zweige behalten ihre Caches; unabhängige nachfolgende Boxen können verschoben
  werden, ohne ihre Texte erneut anzuordnen. Ein unverändertes Suchergebnis oder
  identischer Klartext fordert kein Renderlayout an. Inline-Farbänderungen bauen
  keine Textläufe neu auf. Flex-/Grid-Abhängigkeiten werden weiterhin berücksichtigt.
  Gewöhnliche Textabsätze werden lokal angeordnet und gezeichnet, wenn ihre Höhe
  und erste Grundlinie gleich bleiben, der Text innerhalb der bisherigen Breite
  liegt und die Box-/Grid-Breite vom Text unabhängig ist. Das gilt für Zähler,
  Statusmeldungen wie „Neuigkeiten: nein/ja“ und mehrzeilige Texte; unveränderte
  Wörter behalten ihre nativen Textmessungen. Einzelne Wörter mit identischen
  Textmaßen bleiben auch bei inhaltsabhängigen Breiten lokal. Textausrichtung,
  Zeichenpositionen, Zeichenreihenfolge und Textlauf-Caches werden aktualisiert.
  Inhaltsabhängige Spalten/Flex-Breiten, Überlauf oder gleichzeitige
  CSS-Geometrieänderungen verwenden den normalen Dirty-Tree; Tabellen-, Scroll-
  und Deckkraftgruppen bleiben bei diesem zusätzlichen Schnellpfad konservativ.
- DOM-Änderungen warten auf das Ende eines unterbrechbaren Layoutjobs und machen
  einen veralteten Job ungültig. Layout liest keine halb erneuerten Textläufe.
  Resize, Fehler und Änderungen während eines laufenden Jobs können zur sicheren
  Wiederherstellung weiterhin ein vollständiges Layout benötigen.
  Listener, Interpreterbindungen, Indizes und veraltete Labels werden aufgeräumt.
- Grenzen für Quelltext, Syntax, Aufrufe, Array-/Stringgrößen, DOM-Abfragen und
  Instruktionen. Fehler eines Skripts verhindern nicht das nächste Skript.
  Roblox-Dienste werden Skripten nicht als Globals zur Verfügung gestellt.

Bewusste Grenzen dieser ersten Ausbaustufe:

- Kein vollständiges ECMAScript oder Browser-DOM. Noch keine Arrow Functions,
  Klassen, Destructuring, Module, Netzwerk-/Storage-APIs,
  `eval`, Labels oder vollständige
  Standardobjekt-Prototypen/Property-Deskriptoren. Semikolons sind weitgehend nötig;
  vollständige ASI, Unicode-Casing und alle Typumwandlungsdetails folgen später.
  Async Arrow Functions, Methodenkurzformen, Generatoren/`for await`, Top-Level-
  Await, Module und dynamische `AsyncFunction`-Konstruktoren bleiben offen.
  `await` außerhalb einer async-Funktion wird diagnostiziert; asynchrone
  Ausführung benötigt bislang den HTML-Realm mit Promise-Ereignisschleife.
- Die Zeitsteuerung ist zunächst eine Ereignisschleife je HTML-Seite, keine
  vollständige Browser-Agent-/Worker-/Cross-Realm-Implementierung. Roblox-Aufgaben
  und Bildrate bestimmen die tatsächliche Timerauflösung; ein Timer kann später
  als seine Frist laufen. Hintergrund-/Visibility-Throttling folgt später.
  Ausführungs- und Warteschlangenbudgets begrenzen Endlosschleifen: maximal
  1024 aktive Timer, 512 Frame-Callbacks und 1024 gleichzeitig wartende Microtasks;
  je Checkpoint höchstens 512 Microtasks und eine Instruktionsschwelle von 30000.
  Instruktionsschwellen werden zwischen Callbacks geprüft; jeder Callback hat
  zusätzlich sein eigenes VM-Budget. Ein überschrittenes
  Microtask-Budget verwirft den verbleibenden Checkpoint mit Diagnose.
  Promise-Reaktionen verwenden dieselben Limits; eine noch offene Promise kann
  höchstens 1024 wartende Reaktionen halten. Kombinationen nehmen höchstens
  1024 Eingabeelemente an und verwenden dieselben Microtask-Budgets. Noch fehlen
  eigene `Symbol.iterator`-Iteratoren, Set/Map und iterable DOM-Sammlungen,
  `Promise.try`/`withResolvers`, Subklassen/Species,
  vollständige native Prototypen/Property-Deskriptoren oder Browserereignisse
  `unhandledrejection`/`rejectionhandled`. Ein später hinzugefügter Handler kann
  eine bereits ausgegebene Diagnose nicht rückwirkend entfernen. Promises sind
  bislang an den HTML-Realm angeschlossen; SVG/Canvas folgen bei der Integration
  ihrer Ereignisschleifen. `throw` und grundlegende Fehlerobjekte liegen bereits
  im gemeinsamen Interpreter.
  Ein Timer-Wake verarbeitet höchstens 32 Aufgaben mit einer Instruktionsschwelle
  von 30000; ein Bild verwendet eine Schwelle von 100000. Frame-Callbacks oberhalb des Budgets
  werden mit Diagnose verworfen. Der CSS-Abgleich bleibt konservativ; paint-only
  bedeutet keine Layout-Neuberechnung, aber nicht vollständig kostenlose Styles.
- Skripte im `head`/mitten im Inhalt, externe Quellen und Module werden ausdrücklich
  diagnostiziert. JSON-Datenblöcke werden nicht ausgeführt. Die Renderer-Ladephase
  ist noch keine vollständige Browser-`load`-/Parser-Blocking-Implementierung.
- Live-Attribute sind zunächst `id`, `class`, `style`, `hidden`, `title`, `data-*`
  und `aria-*`. Andere Live-Attribute werden vor einer Änderung abgewiesen.
  `value`/`checked` verwenden das Formularmodell und erzeugen bei programmatischen
  Zuweisungen keine künstlichen Eingabeereignisse.
- `textContent` unterstützt Text-/Inline-Container sowie Button-/Outputtexte.
  Strukturelle/replaced Unterbäume, `innerHTML`,
  vollständiger Wechsel zwischen Inline-/Blockstrukturen und veränderte
  Pseudoelementinhalte benötigen den nächsten Reconciler-Schritt. Ein anfänglich
  unsichtbarer Block mitten in einer ununterbrochenen Inline-Zeile kann noch nicht
  nachträglich eingeblendet werden; dies wird diagnostiziert.
- Strukturelle Änderungen unterstützen gewöhnliche Text-/Block-/Listenflüsse,
  Flex/Grid und einfache Formularfelder. Dynamische Tabellen, Shadow-/Slot-
  Verteilung, Details/Dialog/Popover, Select-Optionen, neue Medien-/Bild-/SVG-/
  Canvas-/Iframe-Ressourcen und Stylesheet-/Script-Insertion folgen später.
  Solche Elemente werden beim Einfügen/Entfernen im verbundenen DOM vor der
  Mutation abgewiesen; das gilt auch für enthaltene Unterbäume. Änderungen
  an Textflüssen mit bestehenden Inline-Medien werden ebenfalls abgewiesen.
  Änderungen innerhalb bestehender CSS-Counter-Kontexte und `content-visibility:hidden`
  sind ebenfalls begrenzt. Neue Elemente mit weiteren CSS-Counter-/Pseudo-
  Abhängigkeiten, dynamische Inline-/Blockwechsel und spezielle Scroll-/
  Animations-Hostanbindungen sind noch kein vollständiger Browser-Abgleich.
  Ohne Renderbox vorbereitete Formularwerte werden beim Mount übernommen.
  Die neue DOM-Erstellung ist auf 8192 Knoten je Realm begrenzt.
- HTML-Canvas-2D ist inzwischen im gemeinsamen Seiten-Realm erreichbar.
  Der ältere SVG-/Canvas-Demopfad besitzt weiterhin eigene Host-APIs.
  Das unterstützte Profil und seine Grenzen stehen in
  [CANVAS.md](docs/CANVAS.md).

Aktuelle Prüfregel: Tobias hat automatische Funktions-, Differential- und
Regressionstests für den Ausbau bis P17 wieder freigegeben. Native FPS-Messungen
bleiben bei Tobias. Sichtvergleiche ergänzen die automatischen Prüfungen.
Promise-Kombinationen und `try/catch/finally` sind vom Nutzer mit „passt alles“
bestätigt. Die kompakte Async-/Await-Vergleichsetappe ist mit „gut fertig“
ebenfalls bestätigt. Dies gilt für die gezeigten Fälle, nicht für vollständige
ECMAScript-Konformität; die oben genannten Grenzen bleiben bestehen.
Die folgenden historischen Testberichte dokumentieren frühere Etappen.
Den aktuellen Prüfstand der Erweiterungen hält
[JAVASCRIPT-IMPLEMENTATION.md](docs/JAVASCRIPT-IMPLEMENTATION.md) fest.

Bisherige Verifikation: `node scripts/run-html-tests.cjs JavaScript JavaScriptDOM JavaScriptClock JavaScriptPromises ScriptTransforms PageLifecycle`
prüfte die tatsächliche Laufzeit und die damalige Vergleichsseite. Die bestehenden
DOM-/Clock-/Transform-Suiten lesen jetzt die Classic-Fixture statt der neuen Seite.
Textwachstum/-schrumpfung, Deckkraft, versteckte Grid-Elemente und drei Breiten
werden gegen unabhängig neu aufgebaute Layoutbäume verglichen. Die HTML-Suite,
die funktionale SVG-Suite (`node scripts/run-svg-tests.cjs --functional-only`),
`node scripts/check-project.cjs` und Rojo-Builds ergänzen die Prüfung.
Browserinteraktionen wurden mit derselben Seite kontrolliert. Native Roblox-FPS
und der visuelle Studio-Vergleich bleiben bei Tobias; CLI-Mocks ersetzen diese
Prüfung nicht.

Die neue DOM-Suite vergleicht strukturelle Änderungen in Block/Flex/Grid bei
520/260/800 Pixeln mit unabhängig neu aufgebauten Bäumen. Sie prüft außerdem
native Input-Verbindungen, Fokus-/Wert-/Listener-Erhalt, Disconnection,
Fragment-/Sammlungssemantik, Fehler ohne Teilmutation und die ausgelieferte
Vergleichsseite. `JavaScriptLayout` hat weiterhin die zuvor bekannte strenge
Assertion für den künstlich erzwungenen Checkbox-Fallback (`Recomputed < 20`).
Diese frühere, auf Nutzerwunsch belassene Prüfung scheitert weiterhin; die
gewöhnliche Checkbox und die neue DOM-Suite sind davon getrennt.

`JavaScriptClock` prüft ohne Warten/FPS-Messung Timerfristen, Nesting/Argumente,
Abbruch aus Microtasks, Callback-Fehler, Ereignis-/Microtask-Reihenfolge,
Frame-Snapshots/Zeitstempel, Queue-Budgets sowie die echte Laborseite mit
kontrollierten Roblox-Diensten. Der Animationstest fordert kein Layout an;
zehn laufende Frames berechnen nur zehn Elementstile und erneuern weder
Layout-Zuordnung noch Canvas/Hintergrund. `ScriptTransforms` prüft zusätzlich
100 Frames mit unveränderten Caches/GUI-Ressourcen, Resize, gebündelte Writes,
Attributselektoren, Transform-Vererbung, DOM-Einfügen/Entfernen, Containing Blocks,
`!important`, gemischte Geometrieänderungen und gleichzeitige CSS-Transitions.
Ein unterbrechbarer Layoutjob sperrt den Treiber, und der Seitenabbau räumt
auch den Bereitschafts-Listener auf.

`node scripts/test-javascript-promises.cjs` prüft 18 identische JavaScript-
Quellen in einer nativen ECMAScript-Laufzeit; `JavaScriptPromises` vergleicht
dieselben Ergebnis-/Reihenfolgespuren mit der Engine. Zusätzliche Tests prüfen
Getterfehler bei Thenables, genau einen DOM-Batch, unbehandelte Ablehnungen,
fehlende/neue Handler, erhaltene Zustände während weiterer Allokationen,
Instruktionsgrenzen und Seitenabbau. Die echte Laborseite wird mit kontrollierten
Roblox-Diensten einschließlich Neustart, Abbruch, Ablehnung und Handlerfehler geprüft.

Nächste Schritte: weitere DOM-Strukturtypen und CSS-Reconciliation;
Iterator-/Symbol-Grundlage, Arrow Functions/weitere Sprachsemantik und Built-ins;
danach Module und explizite Netzwerk-/Storage-Brücken.

## Eine HTML-Seite starten

Neu: `text-decoration-color` für separate Linienfarben und `text-underline-offset` für auto/signierte px/Prozentwerte. Ebenfalls vorhanden: einzelne `margin-top/right/bottom/left` und `padding-top/right/bottom/left` in px/% (margin auch negativ) sowie h3–h6 mit relativen HTML-Standardgrößen/-abständen. Details und Grenzen: [Kleine Elemente](docs/SMALL-ELEMENTS.md).

1. Die Hauptseite liegt unter `examples/websites/main`, das Spiel unter `examples/websites/memory`. Beide besitzen `index.html`, `styles.css`, `app.js`, lokale Illustrationen und `options.json`. Mit `scripts/sync-website.py` werden daraus die getrennten Roblox-Module erzeugt. Details: [Website-Module](docs/WEBSITES.md).
2. Website-Links verwenden normale relative HTML-Adressen wie `../memory/index.html`; Roblox löst sie über den Website-Katalog auf. Details: [Links](docs/LINKS.md).
3. In `examples/HTMLPage.client.luau` ist `local WEBSITE = "Main"` ausgewählt. Diese Zeile ist die einzige Startseiten-Auswahl.
4. In `examples/StudioDemoConfig.luau` `ActiveDemo = "HTMLPage"` einstellen. Im Projektordner `rojo serve` starten und Studio mit dem Rojo-Plugin auf Port **34872** verbinden (Projekt **HTML Engine - Studio Workspace**).
5. **Stop → Play** ausführen. Die ausgewählte Seite erscheint in einem nativen ScrollingFrame.

Falls Rojo noch fehlt: `aftman install` ausführen. `aftman.toml` legt Version 7.7.0 fest.
Der HTML-Synchronisierer benötigt nur die Python-Standardbibliothek. Das vollständige Demo-HTML bleibt kompakt und enthält keine Fontbinärdaten.
Bei weiteren Demo-Schriften den Google-Fonts-Link, die Roblox-Registrierung und die Tests mitpflegen.
Im Standardprojekt alle drei Demo-Scripts behalten; die nicht gewählten Scripts beenden sich vor dem Laden ihrer Demo.
Beim Wechsel der Demo ist kein anderer Rojo-Server nötig. Die zusätzlichen Projektdateien bleiben für separate, reduzierte Builds verfügbar.
Falls Änderungen fehlen: Play stoppen, die Verbindung im Rojo-Plugin prüfen, nach einer Änderung der Projektstruktur gegebenenfalls neu verbinden und die vorgeschlagenen Sync-Änderungen kontrollieren. Quelltexte hier im Projekt bearbeiten; `Players/.../PlayerScripts` enthält während Play laufende Kopien, die für einen verlässlichen Neustart **Stop → Play** brauchen.

Die Engine kann auch direkt in einem eigenen Fenster verwendet werden:

```lua
local Engine = require(game.ReplicatedStorage.HTMLEngine)
local page = Engine.mountHTML(deinZielFrame, '<div style="padding: 20px;"><h1>Hallo Roblox</h1><p>Meine Seite.</p></div>')
-- Beim Schließen:
page:Destroy()
```

HTML und CSS können auch getrennt übergeben werden:

```lua
local HTML = [[<p class="hinweis">Hallo Roblox</p>]]
local CSS = [[.hinweis { color: blue; font-size: 24px; }]]
local page = Engine.mountHTML(deinZielFrame, HTML, {CSS = CSS})
-- Mit Bildzuordnungen: {CSS = CSS, Images = IMAGES}
```

Audio und Video bleiben im HTML normale Browserpfade. Für Roblox werden diese
Pfade wie Bilder seitenbezogen zu Assets aufgelöst; WebVTT-Dateien werden als
Text hinterlegt:

```lua
local page = Engine.mountHTML(target, HTML, {
    CSS = CSS,
    Images = { ["media/poster.png"] = "94339162936897" },
    Audio = { ["media/tone.mp3"] = "9120386436" },
    Videos = { ["media/clip.mp4"] = "5608384572" },
    Tracks = { ["media/captions.vtt"] = "WEBVTT\n\n00:00.000 --> 00:02.000\nHello" },
})
```

Der Browser lädt die echten Dateien. Roblox verwendet `Sound` sowie die
`VideoPlayer`-/`VideoDisplay`-Pipeline mit `VideoFrame` als Fallback. Controls,
Quellenwahl, Poster, Wiedergabe, ziehbare Zeit- und Lautstärkeregler, Mute,
Geschwindigkeiten von 0.5x bis 2x und einfache WebVTT-Cues sind beschrieben in
[Audio und Video](docs/MEDIA.md).

`canvas` besitzt jetzt eine native 2D-Bitmapfläche mit browsergleichen
Rechteck-, Pfad-, Kurven-, Transformations-, Verlaufs-, Clipping-,
Porter-Duff-, CSS-Misch-, Schatten-, Outline-Text-, `drawImage`-, Pattern-,
`ImageData`-, PNG-Export-, Animations-, WebGL-/WebGPU-, Farb- und Alpha-Aufrufen. Die Testseite verwendet
denselben Canvas-JavaScriptcode im Browser und in Roblox; Befehle werden vor
einem gemeinsamen `EditableImage`-Upload gesammelt. Details und Grenzen:
[Canvas 2D](docs/CANVAS.md).

`CSS` enthält reine CSS-Regeln ohne `<style>`-Tags. Im Testskript gibt es dafür
ein optionales Feld direkt vor `HTML`; leer oder weggelassen bleibt das bisherige
Verhalten erhalten. HTML darf weiterhin eigene `<style>`-Blöcke und Inline-Styles
enthalten. Separates CSS gilt als letztes Autoren-Stylesheet: Bei gleicher
Priorität und Selektor-Spezifität gewinnt die spätere Regel. Inline-Styles und
`!important` behalten ihre bisherige Priorität. Beide Quellen nutzen denselben
Parser und werden einmal pro Seitenaufbau kompiliert; HTML und DOM bleiben unverändert.
Ein anderer Typ als String für `options.CSS` wird vor dem Seitenaufbau abgelehnt.

Für vollständige Seiten erzeugt `mountHTML` fehlende `html`-, `head`- und
`body`-Container. `options.DocumentURL` setzt die Adresse, gegen die ein erstes
`base href`, Hyperlinks und lokale Stylesheet-Links aufgelöst werden. Das erste
`title`, Meta-Datensätze sowie `base target` stehen anschließend auf der Page
und als Root-Attribute bereit. `Engine.parseHTML` bleibt Fragmentmodus;
`Engine.parseDocument` erzeugt die Dokumentcontainer auch ohne Rendering.
Einzelheiten: [Dokumentkopf und Metadaten](docs/DOCUMENT-METADATA.md).

SVG-Hoverbilder werden nach dem ersten sichtbaren Bild im Hintergrund vorbereitet.
Standardmäßig dürfen dabei 16 unterschiedliche Zustände je SVG und insgesamt
24 MiB beziehungsweise 48 Einträge im CPU-Pixelcache liegen. Die sichtbare
Darstellung hat immer Vorrang; eine laufende Vorbereitung wird dafür unterbrochen
und danach fortgesetzt. Die Grenzen lassen sich pro Seite einstellen:

```lua
local page = Engine.mountHTML(target, HTML, {
    SVGPrewarmStates = 16,       -- 0 deaktiviert, maximal 64
    SVGCacheBytes = 24*1024*1024, -- 0 bis 256 MiB
    SVGCacheEntries = 48,        -- 0 bis 256
})
```

Der Cache enthält CPU-Pixel und vorbereitete Szenen. Pro sichtbarem SVG bleibt
weiterhin nur eine `EditableImage` aktiv. Bei Größenänderung oder Entfernen des
SVGs werden die dazugehörigen vorbereiteten Zustände verworfen.

Für einen Browservergleich das separate CSS ebenfalls einbinden, etwa in einem
zusätzlichen `<style>`-Block nach den bisherigen Regeln oder über eine CSS-Datei
mit `<link rel="stylesheet" href="seite.css">` an derselben Stelle. Die Engine
erwartet den Inhalt dieser Datei als `CSS`-String; sie lädt die URL nicht selbst.
Die bisherige kombinierte Browserdemo bleibt vollständig in sich geschlossen.

`font-family` akzeptiert jetzt kommagetrennte Listen, etwa
`font-family: 'Unbekannte Schrift', Inter, sans-serif;`. Die erste registrierte
Familie wird einmal beim Kompilieren der CSS-Regel gewählt. Namen mit Leerzeichen
dürfen in Anführungszeichen stehen; Kommas innerhalb der Anführungszeichen gehören
zum Namen. Generische Familien werden auf vorhandene Profile abgebildet:
`sans-serif`/`system-ui` → Arial, `serif` → Roboto Slab, `monospace` → Roboto Mono.
Generische Namen in Anführungszeichen gelten als echte Familiennamen, nicht als
generische Ersatzschriften. Ohne Treffer verwendet die Engine die Seiten-Standardschrift (PT Serif). Ungültige
Listen (z.B. ein abschließendes Komma) verwerfen die gesamte Deklaration.
Kein zusätzlicher Download, Fallback je fehlendem Zeichen oder bei Ladefehlern;
CSS-Escapes und CSS-weite Schlüsselwörter sind weiterhin nicht unterstützt.
Die Zuordnungen sind Engine-Ersatzschriften und müssen nicht den generischen
Schriften des jeweiligen Browsers entsprechen. Grundlage für Listenreihenfolge
und zitierte Namen: [CSS Fonts](https://www.w3.org/TR/css-fonts-4/#font-family-prop).

**PT Serif ist die Standardschrift**, mit dem bestätigten Faktor 1990/1626 und
eigenen Grundlinien-/Schriftkanten. Sie gilt ohne Schriftvorgabe und als Ersatz,
wenn keine Familie einer gültigen Schriftliste registriert ist. Pro Seite kann
sie über `DefaultFont` geändert werden:

```lua
local page = Engine.mountHTML(target, HTML, {
    CSS = CSS,
    Images = IMAGES,
    DefaultFont = "PT Serif", -- optional; z.B. "Inter" für eine andere Standardschrift
})
```

`DefaultFont` akzeptiert einen CSS-Schriftnamen oder eine Liste mit mindestens
einer unterstützten Familie. Ungültige oder vollständig unbekannte Vorgaben
werden vor der Seitenerstellung abgelehnt. Die Einstellung ist pro Seite;
auch gemeinsam vorkompilierte CSS-Regeln lösen einen fehlenden Font erst bei
der Stilberechnung gegen diese Einstellung auf. Ein Element ohne eigene
Schriftdeklaration erbt weiterhin die Schrift seines Elternteils. Explizite
CSS-Schriften und Elementdefaults wie `code`/`pre` (Roboto Mono) bleiben wirksam.
Die bestehende Demo setzt im body ausdrücklich Roboto, sans-serif.

Alle GuiObjects haben `Active=false`; natives Scrollen bleibt aktiviert. Container enthalten ihre eigenen Unterelemente.
Jedes durch normale Leerzeichen getrennte Wort bekommt ein eigenes TextLabel. Satzzeichen bleiben beim Wort,
geschützte Leerzeichen bei einer untrennbaren Wortgruppe. Roblox misst jedes Wort und seinen nötigen Leerzeichenabstand separat.
Die Engine ordnet Wörter selbst an; natives TextWrapping ist deaktiviert.
`overflow-wrap: break-word` ergänzt Notumbrüche innerhalb überlanger Wörter.
Normale Wörter bleiben ganze Labels; geteilte Wörter verwenden wiederverwendete
Textstücke. `nowrap` und `pre` bleiben ungebrochen. Details und Grenzen:
[overflow-wrap](docs/OVERFLOW-WRAP.md).
Roblox-Schriftgrößen werden nach dem Fontfaktor immer mit `math.ceil` aufgerundet. Wortmessung, Leerzeichenmessung und Darstellung verwenden dieselbe ganze Größe.
Frühere Schrift- und Linienmessungen vor dieser Änderung bleiben dokumentiert, müssen aber mit der neuen Rundung erneut visuell geprüft werden. Die Rundung der Hilfslinien bleibt unverändert.

Bei Breitenänderungen werden bestehende Labels neu angeordnet. Unveränderte Wörter behalten ihre individuellen Maße.
Mehrere Breitenänderungen werden gebündelt; Änderungen nur an der Fensterhöhe und Scrollen starten kein Layout.
Es gibt keine permanente Frame-Schleife. Beim Seitenabbau werden Verbindungen getrennt und späte Messergebnisse ignoriert.
Ein allgemeines DOM-Dirty-System und Pooling sind noch nicht implementiert.

Der Seitenaufbau fordert die tatsächlich verwendeten Textschriften früh an, verwendet Font-Konfigurationen
pro Seite wieder und parst CSS-Regelwerte nur einmal. Einzelne Wort-/Leerzeichenmessungen bleiben erhalten.
Umsetzung, Tests und begrenzter Vorher-/Nachher-Vergleich: [Ladeoptimierungen](docs/LOADING-PERFORMANCE.md).

`WordFlow`, `FontMetrics`, `HTML/Tokenizer`, `CSS/Syntax` und `CSS/Stylesheet` verwenden gezielt
`--!optimize 2`, damit ihre Berechnungs-/Scan-Schleifen auch in Studio auf Stufe 2 laufen.
Laut [Roblox-Kommentardokumentation](https://create.roblox.com/docs/luau/comments) ist dies in Live-Spielen
bereits Standard; daraus folgt kein zusätzlicher Live-Geschwindigkeitsgewinn. Ein Laufzeitvorteil in Studio
ist noch nicht gemessen. `--!native` wird nicht gesetzt: Die Engine wird clientseitig verwendet,
während [Roblox Native Code Generation](https://create.roblox.com/docs/luau/native-code-gen) aktuell
serverseitige Ausführung unterstützt. Roblox-Textmessung und GUI-Aufrufe werden durch diese Direktiven
nicht selbst schneller. Native-Optimierungen erst bei tatsächlicher Servernutzung und mit Profilvergleich prüfen.

## Aktueller Darstellungsumfang

Bilder ohne vollständige Größenangaben verwenden jetzt automatisch ausgelesene Roblox-Assetmaße. Die Abfrage erfolgt einmal pro Asset/Seite; bei fehlendem Zugriff bleiben Attributmaße beziehungsweise 300 × 150 px als Ersatz erhalten, ohne Fehlersymbol. CSS-/HTML-Maße haben Vorrang. Details: [Bildquellen und automatische Maße](docs/IMAGES.md).

Ebenfalls vorhanden: `small`, `code`, `pre` und `blockquote`. small verkleinert die Schrift ohne Höhenversatz; code/pre nutzen Monospace; in Roblox wird dies auf Roboto Mono abgebildet. pre erhält den Leerraum und entfernt beim Parsen den ersten unmittelbaren Zeilenumbruch. blockquote verwendet 40px Seitenränder und 1em vertikale Ränder; Absatzränder am offenen Rand fallen zusammen. Details: [Kleine Elemente](docs/SMALL-ELEMENTS.md).

Neu: `hr`, `mark`, `sup/sub` und `text-align-last`, jeweils mit kurzem Beispiel im gemeinsamen HTML. Hoch-/Tiefstellung verwendet Chromium-orientierte Schriftgrößen und Grundlinienversätze ohne künstliche horizontale Abstände. Zusammenhängende Wortteile können nun eigene Textstile tragen, bleiben beim Umbruch aber eine Gruppe. Details, Quellen und Grenzen: [Kleine Elemente](docs/SMALL-ELEMENTS.md).

`ul`, `ol` und `li` unterstützen verschachtelte Listen mit Außenmarkern. Die Standard-Einrückung beträgt 40px; Listen haben oben/unten 1em Abstand anhand ihrer CSS-Schriftgröße, verschachtelte Listen standardmäßig 0. Einträge selbst haben keinen zusätzlichen Abstand. Folgezeilen beginnen bündig unter dem Text; Nummern wachsen nach links. Unterstützt sind `ol start/reversed`, `li value` und `list-style-type: disc/circle/square/decimal/decimal-leading-zero/lower-alpha/upper-alpha/lower-roman/upper-roman/none`. Einfache ausgelassene li-End-Tags werden erkannt. Abschnitt 11 der Demo zeigt die fünf zusätzlichen Zählerformate.

Absatzränder am Anfang/Ende von Listen und Listeneinträgen fallen bei offenem Rand zusammen; Padding, Rahmen und overflow hidden/auto/scroll trennen sie. Allgemeines Eltern-Kind-Collapsing außerhalb von Listen, Listeneinträgen und blockquote und Durchreichen durch leere Blöcke fehlen weiterhin. Textmarker werden individuell gemessen und beim Resize wiederverwendet; Symbolmarker verwenden eine an Blink angelehnte Geometrie mit angenäherter Font-Ascent. `list-style-image` löst zugeordnete Bilder aus `options.Images` als 1em-Marker auf. Inside-/RTL-Marker bleiben eingeschränkt. Details und Tests: [HTML-Support](docs/HTML-SUPPORT.md), `tests/Lists.luau`.

`white-space` unterstützt `normal`, `nowrap`, `pre`, `pre-wrap`, `pre-line` und `break-spaces`, einschließlich Vererbung auf Inline-Text. normal/nowrap fassen Leerraum zusammen; nowrap verhindert automatische Umbrüche, auch innerhalb einer zusammenhängenden Inline-Wortgruppe. pre/pre-wrap erhalten Leerzeichen, Tabs und Quelltext-Zeilenumbrüche; pre-wrap erlaubt zusätzlich Wortumbrüche. pre-line erhält Quelltext-Zeilenumbrüche, fasst Leerzeichen/Tabs aber zusammen. break-spaces erhält Leerraum auch am Zeilenende und erlaubt einen Umbruch nach jedem Leerzeichen/Tab. Dafür verwendet dieser Modus je Leerzeichen/Tab einen transparenten Frame; Wörter bleiben einzelne Labels. Maße/Frames werden beim Resize wiederverwendet. br erzwingt in allen Modi einen Umbruch. Kein vollständiges Unicode-Layout; das pre-Element hat eigene Standardwerte. Die Demo enthält je ein kurzes Beispiel pro Modus.

`tab-size` wird vererbt und akzeptiert nichtnegative Zahlen (auch Brüche) sowie Pixelwerte. Standard ist 8, `0` entfernt den Vorschub erhaltener Tabs. Zahlen beziehen sich auf die native Leerzeichenbreite des Blockcontainers inklusive word-spacing/letter-spacing; px geben den Abstand der Tabstopps direkt an. Bei weniger als 0.5ch Restabstand wird der folgende Stopp verwendet. Messungen für Tab-Grenze und abweichende Blockschrift werden je Space-Eintrag gespeichert; Resize benötigt keine neuen Messungen. Keine Prozentwerte oder anderen Längeneinheiten. Die gemeinsame HTML-/Studio-Demo zeigt `tab-size: 4`.

Vertikale Außenabstände direkt benachbarter Blockelemente fallen zum größeren Wert zusammen: 16px unten und 16px oben ergeben 16px Abstand, statt 32px. Das gilt auch zwischen Karten mit Rahmen/overflow. Padding und horizontale Margins bleiben unverändert; dazwischenliegender Text unterbricht das Zusammenfallen. Eltern-Kind-Collapsing und das Durchreichen durch leere Blöcke sind noch nicht implementiert.

`min-height` (`auto`, 0, px) und `max-height` (`none`, 0, px) begrenzen die Höhe gemäß `box-sizing`; das Minimum gewinnt bei widersprüchlichen Grenzen. Prozenthöhen fehlen weiterhin. `overflow` unterstützt visible/hidden/auto/scroll mit einem oder zwei Werten sowie getrennte `overflow-x/y`. Auto/scroll nutzen native Scrollcontainer und berücksichtigen Leistenplatz im Layout. Nachfolgende Blöcke richten sich nach der Boxhöhe; nur sichtbarer Überlauf erweitert die äußere Scrollausdehnung. Clipping bleibt rechteckig, auch bei UICorner. Abschnitte 13/14 zeigen vertikales und horizontales Scrollen. Details und Grenzen: [Scrollbereiche](docs/SCROLLING.md).

`box-sizing: content-box` (Standard) bezieht width/height auf den Inhalt; `border-box` schließt Padding und Rahmen in diese Maße ein. Margin bleibt außen. `min-width` und `max-width` begrenzen Breiten in px oder Prozent passend zum gewählten Box-Modell. `min-width: auto` setzt im bisherigen Blocklayout das Minimum auf 0, `max-width: none` hebt das Maximum auf. Mindestbreite gewinnt bei widersprüchlichen Grenzen. Die Inhaltsgröße kann 0 werden; Padding/Rahmen schrumpfen nicht mit. Prozentwerte werden bei Resize anhand der Eltern-Inhaltsbreite neu berechnet, ohne erneute Textmessung. Keine intrinsischen Größen, em/rem oder calc; Höhengrenzen unterstützen nur px. Die Demo zeigt eine flexible Karte mit 180–480 px Gesamtbreite.

Blöcke und Bilder unterstützen `border: 2px solid #245bb3`, `border: none`, border-width/style/color mit 1–4 Werten sowie border-top/right/bottom/left mit ihren width/style/color-Longhands. Linienarten sind solid/inset/outset/groove/ridge/none/dashed/dotted/double. `currentcolor` verwendet die endgültige Textfarbe. Fehlende Kurzschreibwerte sind 3px/none/currentcolor; Cascade und !important gelten pro Seite/Komponente. Jede Kante trägt ihre eigene Breite zum Boxmodell bei. Gleichmäßige solide Rahmen behalten UIStroke und UICorner; individuelle, elliptische und prozentuale Radien verwenden eine vollständige EditableImage-Oberfläche mit optionaler Kindmaske. Der HitTest folgt der exakten Ellipse. Andere Rahmen verwenden rechteckige Kanten und wiederverwendete Mustersegmente, mit diagonalen Eckbildern und API-/Budgetfallback auf rechteckige Übergänge; Musterkanten laufen nicht gerundet um Ecken. Inline-Text-Rahmen bleiben außerhalb des Profils. Siehe [Eckübergänge](docs/BORDER-CORNERS.md) und [Rahmenkanten](docs/BORDER-SIDES.md).

`letter-spacing` unterstützt `normal`, `0` und positive/negative px-Werte mit Vererbung. Bei einem Abstand ungleich null wird ein Wort als Frame mit einzelnen Zeichen-Labels dargestellt. Roblox `utf8.graphemes` hält kombinierte Buchstaben und Emoji-Sequenzen zusammen. Die Engine misst diese Zeichen individuell und verwendet Maße und Labels beim Resize wieder; Umbrüche erfolgen weiterhin zwischen ganzen Wörtern. Abstände sind CSS-Pixel ohne Fontfaktor; normale Leerzeichen berücksichtigen zusätzlich ihre beiden Zeichenübergänge. Unterlinien und skip-ink folgen den Zeichenpositionen. `normal`/0 verwendet beim Seitenaufbau weiterhin ein natives Wort-Label. Getrennte Zeichen können bei Kerning, Ligaturen und verbundenen Schriften vom Browser abweichen; kein RTL, %, em/rem. Mehr Zeichen-Labels bedeuten mehr Instanzen und Messungen beim ersten Aufbau. Im Zeichenmodus wirkt word-spacing auch auf NBSP innerhalb der untrennbaren Wortgruppe.

`word-spacing` unterstützt `normal`, `0` und positive/negative px-Werte mit Vererbung. Der Wert wird zum individuell gemessenen normalen Leerzeichen addiert, nach dem Zusammenfassen von Whitespace. Maßgeblich ist der Stil des Leerzeichens. Umbruch, Ausrichtung, Blocksatz, Einzüge und Unterlinien berücksichtigen den Abstand; bei Änderungen/Resize bleiben native Maße wiederverwendbar. Negative Werte können Wörter überlappen lassen. Noch keine %, em/rem oder zusätzlichen Unicode-Worttrenner; NBSP innerhalb eines nativen Wort-Labels behält seinen Abstand und erzeugt bei nichtnull word-spacing eine Diagnose (Ausnahme: Zeichenmodus bei letter-spacing).

`text-transform` unterstützt `none`, `uppercase`, `lowercase` und `capitalize`: ASCII und Latin-1-Buchstaben einschließlich Umlauten, `ß → SS` bei uppercase und `ẞ → ß` bei lowercase. capitalize ändert nur Wortanfänge und erhält die übrige Schreibweise; Leerraum (auch NBSP) und Bindestriche bilden die einfachen Wortgrenzen. Vollständige Unicode- und sprachabhängige Regeln fehlen. Umgewandelt werden die dargestellten Wörter vor ihrer Messung, der DOM-Text bleibt erhalten. Die bestehende Einschränkung bei unterschiedlichen Stilen innerhalb eines Wortes gilt weiterhin.

`text-indent` unterstützt px und Prozent, auch negative Werte. Es rückt nur die erste formatierte Zeile des Blocks ein; automatische Umbrüche, br und spätere Textabschnitte hinter einem Block beginnen ohne erneuten Einzug. Prozentwerte beziehen sich auf die Inhaltsbreite und werden beim Resize ohne neue Textmessung aktualisiert. left/center/right/justify, Padding und Vererbung werden berücksichtigt. Kein em/rem, hanging, each-line oder RTL; linker Überlauf durch negative Einzüge ist mit dem bisherigen Scrollmodell nicht nachträglich zugänglich.

`text-decoration` unterstützt underline/overline/line-through (auch kombiniert) oder none, optional mit Farbe, Linienart und auto/px/%-Dicke in beliebiger Reihenfolge, z.B. `underline wavy red`. `<u>`, `<ins>`, `<s>` und `<del>`
sind ergänzt. Auf Nutzerwunsch verwenden alle Fonts einfache Näherungen: Unterlinie `max(1, round(font-size / 14))` px unter der
gemeinsamen Grundlinie (1 px bis Größe 20, 2 px ab 21, 3 px ab 35; weitere Übergänge geschätzt), Durchstrich-Oberkante `round(font-size / 4)` px darüber; Dicke
`max(1, floor(font-size * 0.049))`, unabhängig von Schriftfamilie und Gewicht. Diese gemeinsame Näherung trifft die vom Nutzer gemeldeten Übergänge: 2 px ab 41, 3 px ab 62 und 4 px ab 82 px. `text-decoration-thickness` akzeptiert `auto`, px und Prozent; explizite px/% werden gerundet. Das gemeinsame Demo-HTML verwendet automatische Dicke, deren Browserdarstellung abweichen kann. Maßgeblich für Farbe, Dicke und Durchstrichposition ist das Element, das die Linie erzeugt.
Die Linien laufen über normale Wortabstände einschließlich Blocksatz mit und werden bei Umbrüchen getrennt.
Ein untergeordnetes `none` entfernt keine Linie eines Vorfahren. Eigene Standardlinien von u/s/del können
mit CSS entfernt werden. Experimentell spart `text-decoration-skip-ink: auto` (Standard) kleine Bereiche bei p/g/j/q/y aus; `none` zeichnet die Unterlinie durchgehend. Zusätzliche Präfixmessungen bleiben beim jeweiligen Wort und werden beim Umbruch wiederverwendet. Lücken skalieren mit der tatsächlichen Textgröße; sie sind Schätzungen ohne Glyphenkonturen, besonders bei kursiven Schriften. Durchstriche bleiben durchgehend. Keine individuellen Fontdaten oder `from-font`. Overline, Wellenlinien, eigene CSS-Farben und Unterlinienoffset sind unterstützt. Das Browserbild kann abweichen. Der Nutzer hat die Variante mit schmaleren Lücken bestätigt; sie bleibt bestehen.

Der verbindliche **Elementkatalog** steht in [src/HTMLEngine/HTML/Elements.luau](src/HTMLEngine/HTML/Elements.luau).
Er enthält pro Tag die Darstellungsart (`Render`), den Stand (`Support`), eine Beschreibung,
Einschränkungen und gegebenenfalls Standardwerte. Renderer und Inline-Styles verwenden diese Einträge direkt.
`supported` bedeutet: Der dokumentierte Roblox-Funktionsumfang ist einsatzbereit. `partial` ist ausschließlich für noch fehlendes Verhalten innerhalb dieses Roblox-Profils reserviert; Browser-APIs außerhalb des Projektumfangs senken den Status nicht. `parser-only` bedeutet nur im DOM gespeichert.
Unaufgeführte Tags werden bisher als einfache Blockcontainer behandelt, ohne Unterstützung ihrer speziellen Funktion.
Im Code ist der Katalog über `Engine.Elements["h1"]` erreichbar; alle Einträge sind schreibgeschützt.
Bei einem neuen Element oder einer erweiterten Unterstützung wird der zugehörige Eintrag mitgepflegt.

Der entsprechende **CSS-Eigenschaftskatalog** steht in [src/HTMLEngine/CSS/Properties.luau](src/HTMLEngine/CSS/Properties.luau),
im Code `Engine.CSSProperties["line-height"]`. Er beschreibt erlaubte Werte, Einschränkungen und Vererbung.
InlineStyle verwendet ihn direkt für die Zuordnung und Vererbung der Eigenschaften.
Die gezählte Bestandsaufnahme und die verbleibenden Roblox-Ziele stehen in
[docs/CSS-COMPLETION.md](docs/CSS-COMPLETION.md): 355 Katalogeigenschaften sind
`supported` und 0 `partial`. Der Abgleich mit dem aktuellen MDN-Katalog und die
noch offenen sichtbaren Funktionsblöcke stehen im
[CSS-Erweiterungsplan](docs/CSS-EXPANSION-ROADMAP.md).

- Verschachtelte Block-Container, h1/h2/p, formatierte span-Wörter und br. Gemischte Schriftgrößen/-familien teilen sich eine Grundlinie. H1/H2 sind größer und standardmäßig fett; b/strong verwenden Gewicht 700. CSS kann diese Standardwerte überschreiben.
- CSS in style-Blöcken und Inline-Attributen: `color`, `background-color`, mehrschichtige `background`-/`background-image`-URL- und Verlaufshintergründe samt Größe/Position/Wiederholung/Ursprung/Clip, `width` (px/%), `height` (px),
  `margin`/`padding` (0 oder px, 1–4 Werte), `font-size` (1–100 px), `font-family` (Arial / Source Sans Pro / Ubuntu / Roboto / Roboto Condensed / Roboto Mono / Roboto Slab / Inter / Open Sans / Builder Sans), `font-feature-settings` (`zero`, `ss03`, `liga`, `calt`, `kern`, `smcp`, `c2sc`, `sups`, `subs`) und die passenden `font-variant`-Teilmengen, `counter-reset`/`counter-increment`/`counter-set` mit `counter()` und `counters()` in generiertem Inhalt, `line-height` (normal, Zahl, px, %), `text-align` (left/center/right/justify), `text-transform` (none/uppercase/lowercase/capitalize), `text-indent` (0, signierte px/%), `word-spacing` und `letter-spacing` (normal/0/signierte px), `display` (inline/block/none/flex/grid, atomare Inline-Varianten und contents).
- Farben: #RGB, #RRGGBB und wenige Grundnamen.
- Rahmen für Blöcke und Bilder: `border`, `border-width/style/color` (1–4 Werte; solid/inset/outset/groove/ridge/none/dashed/dotted/double), einzelne Kanten und `border-radius` einschließlich vier Einzelkanten, Prozentwerten und elliptischen Radien.
- `outline`, `outline-width/style/color/offset`: zusätzliche Kontur auf Blöcken/Bildern ohne Layoutplatz, auch mit negativem Abstand. Beispiel 16; [Details und Grenzen](docs/OUTLINE.md).
- `text-overflow: clip | ellipsis` bei `overflow-x:hidden`: Text am rechten Zeilenende kürzen, beim Resize wiederherstellen. Beispiel 17; [Details und Grenzen](docs/TEXT-OVERFLOW.md).
- `word-wrap`-Alias, HSL/HSLA-Farben, outset/groove/ridge sowie address, dl/dt/dd und figure/figcaption mit Standardabständen. Beispiele 18–20; [Details](docs/SMALL-ADDITIONS.md).
- Box-Größen: `box-sizing` (content-box/border-box), `min-width` (auto/0/px/%) und `max-width` (none/0/px/%).
- Auf Inline-Text funktionieren `color`, `font-size`, `font-family`, `font-weight`, `font-style`, `line-height`, `text-transform`, `word-spacing`, `letter-spacing`, die beschriebenen Textdekorationen und `display: none`. `text-align`/`text-indent` werden vererbt, verschieben aber keine einzelnen Inline-Wörter; andere Box-Eigenschaften erzeugen eine Diagnose.
- Selektoren: Tag, `.klasse`, `#id`, `*`, Kombinationen wie `p.note`, Nachfahren wie `body .note` und Kommagruppen. Vorrang nach Spezifität, Quellreihenfolge, Inline-Styles und `!important`; Regeln werden vor dem Rendern gesammelt, auch aus späteren style-Blöcken.
- `font-weight: normal/400`, `bold/700` und Zahlen von 1 bis 1000 werden vererbt. Roblox verwendet den nächsten Schnitt in 100er-Stufen von Thin bis Heavy; `600` verwendet SemiBold. Wort- und Leerzeichenmessung sowie Darstellung verwenden denselben Schnitt. Relatives bolder/lighter fehlt; verschachteltes b/strong bleibt 700.
- `font-style: normal/italic` wird vererbt; i/em sind standardmäßig kursiv und per CSS überschreibbar. Mit Gewicht 700 entsteht Fett-Kursiv. Kein oblique oder Neigungswinkel; verfügbare Schnitte hängen von der Roblox-Familie ab. Der Browser-Link enthält alle vier Kombinationen aus 400/700 und normal/italic.
- Bold und Italic verwenden die bestehenden Regular-Größen-/Linienwerte vorerst als Näherung; eigene Bold-/Italic-Kalibrierungen fehlen. Die tatsächlichen Wortbreiten werden mit dem angeforderten Gewicht und Stil gemessen. Die kompakte Demo enthält einen gemeinsamen Absatz für b, strong und CSS-Gewichte sowie Google-Fonts-Links für 400/700.
- Registrierte externe Stylesheets, erweiterte Selektoren, Custom Properties, responsive `@media`-Regeln, `calc()`/`min()`/`max()`/`clamp()`, `vw`/`vh`/`vmin`/`vmax`, Flexbox, Grid und einzelne Rahmenkanten sind vorhanden. Die noch geplanten CSS-Funktionen sind vollständig in [docs/CSS-COMPLETION.md](docs/CSS-COMPLETION.md) aufgeführt.
- Bilder, Buttons und Eingabefelder werden noch nicht dargestellt und erzeugen Diagnosen.
- Überbreite Wörter laufen über. Feste Höhen bestimmen die Boxhöhe; überlaufender Inhalt belegt weiterhin Platz im Seitenfluss.

`page.Root` meldet seinen Zustand im Attribut `Status`: loading, waiting-size, layout, ready oder error.
Bei Layoutfehlern enthält `Error` die Meldung. Parser- und Style-Diagnosen stehen in `page.Document.Diagnostics`.

Der reine Parser funktioniert ohne GUI:

```lua
local document = Engine.parseHTML('<div id="demo"><p>Hallo &amp; Roblox!</p></div>')
local element = Engine.DOM.findById(document, "demo")
print(Engine.DOM.textContent(element)) -- Hallo & Roblox!
```

Details und Eingabegrenzen stehen in [docs/HTML-SUPPORT.md](docs/HTML-SUPPORT.md).
Der rohe Elementbaum ist noch keine Schnittstelle für automatisch sichtbare Inhaltsänderungen.

## Zeilenabstand mit line-height

```html
<p style="font-family: Roboto; font-size: 20px; line-height: 28px">Erste Zeile<br>Zweite Zeile</p>
```

Bei einheitlicher Schrift setzt `28px` den Zeilenschritt auf 28 Pixel. `1.4` ergibt bei 20 px Schriftgröße ebenfalls 28 Pixel;
hier wird die CSS-Schriftgröße verwendet, ohne Roblox-Fontfaktor. Ein geerbter Faktor wird mit der Schriftgröße
des Kindes multipliziert. Prozentwerte werden am definierenden Element in Pixel umgerechnet und als Pixelwert vererbt.
Grundlage: [CSS-Spezifikation zu line-height](https://www.w3.org/TR/CSS2/visudet.html#line-height).

Erlaubt sind `normal` und nichtnegative Dezimalwerte bis 100000, ohne Einheit oder mit `px`/`%`.
Null und kleine Werte erlauben überlappenden Text. Die Wort-Labels behalten ihre benötigte Höhe;
zusätzlicher oder negativer Platz wird gleichmäßig um die angenäherte logische Fontbox verteilt. Bruchteile unterliegen der Roblox-Pixelrasterung.
`normal` verwendet weiterhin die Roblox-Schriftgröße und Textmessung als Näherung. em/rem/calc und CSS-weite Schlüsselwörter fehlen.
Eine reine Änderung der Zeilenhöhe benötigt im Layout keine neuen Wortmessungen; eine öffentliche DOM-Update-API fehlt weiterhin.

## Textausrichtung mit text-align

`text-align: left`, `center`, `right` und `justify` richten jede fertige Textzeile im Inhaltsbereich des Blockcontainers aus.
Standard ist `left`; die Eigenschaft wird vererbt. Padding reduziert den verfügbaren Inhaltsbereich.
Automatische Umbrüche, die letzte Zeile und Zeilen vor einem `br` werden jeweils einzeln ausgerichtet.
Grundlinien und Zeilenhöhen bleiben erhalten, eine reine Ausrichtungsänderung benötigt keine neuen Messungen.
Ein eigener Wert auf einem Span richtet dessen Wörter nicht unabhängig vom Absatz aus.
Der Blockcontainer selbst wird nicht verschoben. Überbreite Wörter können bei center/right nach links überlaufen;
links überlaufender Inhalt ist im bisherigen Scrollmodell nicht nachträglich erreichbar. start/end und RTL-Layout fehlen.

`justify` verteilt den freien Platz gleichmäßig auf die normalen Wortabstände einer automatisch umgebrochenen Zeile.
Die letzte Zeile, Zeilen vor einem `br` und Zeilen ohne dehnbare Wortabstände bleiben linksbündig.
Geschützte Leerzeichen innerhalb einer Wortgruppe bleiben erhalten. Keine Silbentrennung; `text-align-last` kann die letzten Zeilen gesondert ausrichten.

## Gemeinsame Grundlinie

```html
<p style="font-family: Roboto; font-size: 20px; line-height: 1.4">
  Normal <span style="font-size: 40px; color: blue">Groß</span>
  <span style="font-family: Inter; font-size: 30px">Inter</span> Normal
</p>
```

Jedes Wort behält sein eigenes TextLabel, seinen Stil und seine individuelle Wort-/Leerzeichenmessung.
`InlineWords.luau` erhält beim Zusammenfassen von HTML-Leerraum die Wortgrenzen und den Stil des Leerzeichens.
`FontMetrics.luau` übernimmt die Grundlinie des jeweiligen Fontprofils, `WordFlow.luau` richtet die Wörter daran aus.
Pro Zeile zählt der größte Platz oberhalb und unterhalb der Grundlinie. Der Absatzstil liefert eine Mindestbox
(CSS-Strut); große Wörter vergrößern nur die Zeile, auf der sie tatsächlich stehen. Auch bei fester `line-height`
kann eine Mischung unterschiedlicher Schriften oder Größen deshalb eine höhere Zeile ergeben.

Die gespeicherten Linien sind manuell angepasste Näherungen. Ohne kalibrierte Linien liegt die geschätzte Grundlinie
bei `round(TextSize * 0.8)`. Die logische Fontbox verwendet die aufgerundete Roblox-TextSize als angenäherte Höhe;
Roblox liefert hier keine vollständigen Ascent-/Descent-Metriken. H-/x-/p-Kanten sind dafür kein Ersatz.
Wort-Labels behalten unabhängig vom Zeilenschritt ihre gemessene Höhe. Alte Fontprofile behalten ihre bisherige Eingabekonvention.

Unterstützt werden Textstile auch für Wortteile in verschachtelten Spans. Ein Stilwechsel teilt das Wort in separat gemessene Fragmente, die ohne zusätzliche Leerzeichen zusammenbleiben und gemeinsam umbrechen. Kerning und Ligaturen über diese Stilgrenzen fehlen.
Leere Spans und reine Inline-Vorfahren ohne eigenen Text liefern noch keine zusätzlichen Zeilenmetriken.
Inline-Hintergründe sowie `vertical-align: baseline/super/sub` sind unterstützt. Inline-Margin/Padding und weitere vertical-align-Werte fehlen weiterhin.

## Ordner und getrennte Projekte

| Bereich | Inhalt |
| --- | --- |
| `src/HTMLEngine` | Nur Engine-Module und Schriftprofile; keine Tests oder Demos |
| `examples/HTMLPage.client.luau` | Bearbeitbarer HTML-Code und Start der sichtbaren Seite |
| `examples/FontLab` | Separates Schriftlabor mit Hilfslinien, Klickrouter und Print-Bericht |
| `tests` / `scripts` | Automatische Prüfungen und ihre Starter |
| `measurements` | Bisherige Messwerte und ihre Herkunft |

| Befehl | Zweck |
| --- | --- |
| `rojo serve` | Festes Studio-Projekt; aktive Demo in `examples/StudioDemoConfig.luau` auswählen |
| `rojo serve htmlpage.project.json` | Sichtbare HTML-Demo, ohne mitgelieferte Tests |
| `rojo serve fontlab.project.json` | Schriftlabor und dessen Studio-Tests |
| `rojo serve parser.project.json` | Parser-Demo und HTML-Tests in der Studio-Ausgabe |
| `rojo build engine.project.json -o build/HTMLEngine.rbxmx` | Nur die wiederverwendbare Engine als Modell |

## Schriften messen

**Neuer Vergleich mit allen 126 recherchierten Familien bei 50 px:**
Im Standardprojekt `ActiveDemo = "FontComparison"` in `examples/StudioDemoConfig.luau` wählen und in Studio **Stop → Play** drücken.
Die passende Chrome-Datei ist [examples/all-fonts-comparison.html](examples/all-fonts-comparison.html).
Jeweils dieselbe Nummer vergleichen. Beide Seiten verwenden dieselbe Fontdatei und den unkalibrierten Faktor 1,00.
Beide Tests zeigen nur Schriftname und 50-px-Beispieltext untereinander auf weißem Hintergrund.
Anleitung, vollständige Fontliste und Quellen: [docs/FONT-RESEARCH.md](docs/FONT-RESEARCH.md).

Roblox hat Arial durch Arimo ersetzt. Der bisherige Profilname „Arial“ meint unsere Zuordnung HTML-Arial → Roblox-Arimo;
er bezeichnet keine identische Schriftdatei auf beiden Seiten. Der Größenfaktor korrigiert keine Buchstabenformen.

Das Schriftlabor im Standardprojekt (`rojo serve`, `ActiveDemo = "FontLab"`) startet aktuell mit **Open Sans bei HTML 10, 20, 30, 40 und 50 px**, mit dem vorläufigen Faktor **1,34 und Aufrunden**. Die angepassten H-Höhen müssen noch bestätigt werden. Eigene Linienformeln aus fünf manuellen Messpunkten sind übernommen, mit höchstens 1 px Abweichung zu diesen Messwerten; Zwischenwerte bleiben Näherungen. Messwerte: `measurements/open-sans-height-comparison.md` und `measurements/open-sans-guide-fit.json`. Die passende Chrome-Datei ist [examples/open-sans-comparison.html](examples/open-sans-comparison.html). Open Sans Regular verwendet das Roblox-Asset `11598121416` und die vorhandene lokale Vergleichsschrift `font083.ttf`. HTML-Beispiel: `<p style="font-family: 'Open Sans'; font-size: 20px">Hallo Open Sans</p>`.

**Inter:** Im Schriftlabor mit `Font = "Inter"` verfügbar, mit bestätigtem Faktor **1,18 und Aufrunden** bei HTML 10–50 px. Die eigenen Linienformeln treffen die fünf manuellen Messpunkte mit höchstens 1 px Abweichung; Zwischenwerte bleiben Näherungen. Browserdatei: [examples/inter-comparison.html](examples/inter-comparison.html). Messwerte: `measurements/inter-height-comparison.md` und `measurements/inter-guide-fit.json`.

**Roboto:** Mit `Font = "Roboto"` im Schriftlabor verfügbar, in Roblox mit Faktor **1,13 und Aufrunden**. Der Nutzer hat die Größe visuell bestätigt. Roboto hat eigene Linienformeln aus fünf Messpunkten, mit höchstens 1 px Abweichung zu diesen Messwerten. Zwischenwerte bleiben Näherungen. Roboto Mono verwendet den bestätigten Faktor 1,24 und eigene gemessene Linien; Condensed und Slab bleiben ohne bestätigte Kalibrierung bei Faktor 1. Schriftwechsel und passende Browserdateien: [docs/ROBOTO.md](docs/ROBOTO.md).

**Ubuntu:** In `FontTestConfig.luau` mit `Font = Enum.Font.Ubuntu` weiterhin verfügbar, mit Profilfaktor **1,09**.
Der Nutzer hat Faktor 1,09 für diese fünf Größen visuell bestätigt. Der Test zeigt den tatsächlich gespeicherten Roblox-TextSize an.
Der passende Einzelvergleich ist [examples/ubuntu-comparison.html](examples/ubuntu-comparison.html).
Zuerst die sichtbare H-Höhe in Chrome und Roblox vergleichen, daraus den Größenfaktor bestimmen und anschließend die Linien kalibrieren.
Ubuntus eigene Linienformeln sind aus dem manuellen FONT_REPORT berechnet (höchstens 1 px Abweichung zu den fünf Messpunkten). Zwischenwerte und andere Größen bleiben Näherungen. Messwerte: `measurements/ubuntu-guide-fit.json`.
Die vier Linien einstellen und **Werte ausgeben** klicken. Aus Studio **Ausgabe / Output** die vollständige
Zeile beginnend mit `FONT_REPORT` kopieren. Sie enthält Schriftfamilie, Gewicht, HTML-Größe, tatsächliche Roblox-Größe,
Faktor und aktuelle Linienpositionen. Der Knopf liest die Werte erst beim Klick; er verändert kein Fontprofil.

Schrift und Testgrößen stehen in `examples/FontLab/FontTestConfig.luau`, beispielsweise
`Sizes = { 10, 20, 30, 40, 50, 60, 70, 80 }`. Alle Hilfslinien sind 80 % transparent.
Für die x-Linie: Unterkante direkt über die erste sichtbare x-Pixelreihe setzen, ohne Lücke.
Manuelle Änderungen gelten nur bis zum Neustart.

Chrome-Referenzen: [Arial](examples/font-size-comparison.html) und [Source Sans Pro](examples/source-sans-comparison.html).
Beide zeigen 10 bis 80 px und verwenden `font-comparison.css` und `font-comparison.js` im selben Ordner.
In Chrome mit **Strg + 0** auf 100 % Zoom stellen und zuerst die weißen 100-px-Referenzlinien vergleichen.
Source Sans lädt die mitgelieferte Datei aus `examples/fonts`; bei einem Ladefehler bleiben die Muster verborgen.
Die Fontdatei entspricht der Regular-Datei aus der lokalen Roblox-Installation. Textbreiten werden ausschließlich in Roblox bestimmt.
Diese Referenzseiten sind keine Beispiele für den bereits unterstützten HTML-Umfang unserer Engine.

Jede Schrift hat unter `src/HTMLEngine/Layout/FontProfiles` ihr eigenes Profil:
`SizeMultiplier` für die Textgröße und vier getrennte Linienformeln `runden(Slope × RobloxTextSize + Intercept)`.
Neue Profile in `FontProfiles/init.luau` registrieren. Auch weitere Schriftgewichte benötigen eigene Messungen.
Arial verwendet den bestätigten Größenfaktor 1,13 und die akzeptierte Näherung der Linien.
SourceSans ist unkalibriert (`nil`); das Labor verwendet dafür den neutralen Testfaktor 1,00.
Ein einzelner Messpunkt liefert einen Ausgangspunkt, aber noch keine zuverlässige Steigung und Verschiebung für alle Größen.

Die Arial-Koeffizienten stammen aus acht Messungen bei 10, 20, 30, 40, 50, 55, 65 und 75 px.
Die dokumentierte Abweichung beträgt höchstens 2 px für oben, sonst 1 px; die zusätzlichen x-Messungen
bei 60/70/80 px liegen ebenfalls innerhalb 1 px. Daten: `measurements/arial-guide-fit.json`.
Außerhalb dieser Größen ist die Formel nicht visuell geprüft; sie ersetzt keine individuelle Textmessung.
Der Klickrouter gehört zum Labor und unterstützt bisher Mausbedienung ohne überlappende, gedrehte oder skalierte Flächen,
innerhalb eines ScreenGui mit `IgnoreGuiInset=true`. Das vollständige Eingabesystem folgt separat.

Die Codeprüfung und behobenen Randfälle sind in [docs/CODE-REVIEW.md](docs/CODE-REVIEW.md) dokumentiert.

## Prüfen und bauen

```powershell
node scripts/run-html-tests.cjs
node scripts/check-project.cjs
node scripts/check-guide-model.cjs
rojo build htmlpage.project.json -o build/HTMLPage.rbxlx
rojo build fontlab.project.json -o build/FontLab.rbxlx
rojo build parser.project.json -o build/HTMLParser.rbxlx
```

Die CLI-Prüfungen verwenden die offizielle Luau-Laufzeit unter `build/tools/luau/luau.exe`.
Alternativ `LUAU_BIN` auf den eigenen Luau-Pfad setzen. Geprüft werden Parser, Inline-Styles, Wortanordnung,
Seitenabbau und Layoutplanung; Roblox-GUIs werden dabei nicht ausgeführt. Der zusätzliche Node-Check prüft die Linienformeln.
Rojo baut die Modelle, führt aber keinen Luau-Code aus. Darstellung und Eingaben weiterhin in Studio prüfen.
