# S41/S42: JavaScript, DOM und SVG-Dokumentfunktionen

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Stand 14.09.2026. Nutzerauftrag: S41/S42 umsetzen. S39/S40 zum Fortfahren
freigegeben; keine darüber hinausgehende vollständige Animationsabnahme ableiten.
S41/S42 sind im folgenden Teilumfang implementiert und mit „alles gleich“
vom Nutzer zum Fortfahren bestätigt. Die dokumentierten Restfunktionen bleiben offen.

## Vergleich

StudioDemoConfig: `S41_S42`. Stop → Play in Studio, danach
[acht Tafeln](../tests/fixtures/svg-regressions.zip) öffnen. Alternativ:
[S41](../tests/fixtures/svg-regressions.zip), [S42](../tests/fixtures/svg-regressions.zip).
Hier ist keine Starttaste nötig: Skripte laufen beim Laden; Knöpfe/Kreise anklicken.
R setzt alle Dokumente und Skriptzustände zurück. 1/2/3: 240/480/960 px.

| Tafel | Abgleich |
|---|---|
| Erzeugen | Blauer Kreis und Zähler 0 entstehen/initialisieren per Skript; Klick → größer, grün, Zähler 1. |
| Closures | Vier Kreise; jeder besitzt seine eigene Nummer und seinen eigenen Klickzähler. |
| Entfernen | Klick entfernt den Kreis aus dem DOM; nächster Klick hängt denselben Knoten wieder an. Tab/Enter/Leertaste funktioniert am Knopf. |
| Ressource | Ein per Skript geänderter Farb-Stopp färbt beide Verlaufsverbraucher um. |
| Sprache | Fantasiesprache und unbekannte Erweiterung werden übersprungen. Erster passender Sprachzweig grün, sonst violetter Fallback. Roblox-Lab hier en, Browser echte Sprache. |
| Ansicht A | Native SVG-Datei #left, blaues Rechteck. |
| Ansicht B | Native SVG-Datei #right, gelber Kreis. |
| Fehlende Ressource | Links use-Dreieck, rechts absichtlich leere Fläche; Tab/Klick zeigt Titel/Beschreibung im Status. |

Die fehlende use-Referenz erzeugt genau die erwartete Diagnose `missing-use-target`.
Das ist Teil des Tests. Andere Script-/Dokumentfehler sind nicht erwartet.

## Echte Skriptausführung, begrenzter Sprachumfang

`ScriptSyntax` tokenisiert und parst JavaScript in einen AST. `ScriptVM` wertet
diesen aus; keine Übersetzung nach Luau und keine vorprogrammierten Fallaktionen.
`ScriptDOM` verbindet die SVG-Session mit DOM-Operationen und Ereignissen.
Alle vier S41-Tafeln benutzen denselben eingebetteten JavaScript-Quelltext im
Luau-Interpreter und im nativen JavaScript des Browser-Vergleichs.

Implementiert: Zahlen/Strings/Booleans/null/undefined, let/const/var,
Funktionsdeklarationen und anonyme function-Ausdrücke, Closures, return,
if/else, while/for/break, Array-Literale/Index-Lesen, Memberzugriff/Aufrufe,
Zuweisung/compound assignment/postfix ++/--, arithmetische/logische/Vergleichs-
Operatoren und ternärer Ausdruck. Number/String und ausgewählte Math-Funktionen.
for(let)-Closures erhalten eigene Iterationsbindungen. Lvalue wird vor RHS
und nur einmal ausgewertet. Nicht unterstützte Syntax führt zu einem Fehler.

DOM: createElementNS (SVG), getElementById, querySelector für ID oder Tag,
get/set/removeAttribute, appendChild/removeChild/remove, id/textContent,
parentNode/firstChild/children/ownerDocument/documentElement, focus,
add/removeEventListener mit boolescher Capture-Option. Event: target,
currentTarget, type, eventPhase, key/pointerId/buttons/shiftKey/pointerType sowie
preventDefault/stopPropagation/stopImmediatePropagation.

Der Script-Host ist ausdrücklich aktiviert (`Scripted=true` im Labor).
Normale HTML-Seiten führen dadurch nicht plötzlich Skripte aus. Externe Skripte
benötigen einen ausdrücklich übergebenen ResolveScript-Callback; kein automatischer
Netzwerkzugriff. Reset/Destroy beendet Realm und Listener.

Grenzen: 64 KiB Quelltext pro Skript, 16.000 Tokens, 96 Parse-/Ausdrucksebenen,
20.000 Schritte pro Ausführung/Callback, 64 Funktionsaufrufebenen,
32 Skripte/Dokument, 1.024 erzeugte DOM-Elemente und 256 Listener/Realm.
Unendliche Schleifen werden abgebrochen und im Status gemeldet.

## S42

`Conditional` prüft systemLanguage mit Teilsprachen-Matching sowie explizite
requiredFeatures/requiredExtensions-Supportmengen. switch übernimmt nur den
ersten zulässigen Elementzweig; dessen display:none führt nicht zur Auswahl
des nächsten Zweigs. Dieselben Bedingungen gelten außerhalb von switch.

Fragmentoption: `#viewId` übernimmt viewBox/preserveAspectRatio eines view-
Elements. `svgView(viewBox(...);preserveAspectRatio(...))` wird ebenfalls gelesen.
Die Quellattribute bleiben erhalten. Browser-Ansichten verwenden echte SVG-
Dateien mit Fragment im iframe-URL. Resize betrifft den SVG-Viewport; der
Browser übernimmt die Fragmentsemantik selbst. Fonts/Hotkey-Brücke werden nur
in die generierten nativen Vergleichsdateien eingebettet.

Ressourcenauflösung, Titel/desc/ARIA-Metadaten und Fokus bauen auf Document und
Session auf. Fehlende Ressourcen bleiben lokale Diagnosen und verhindern nicht
die Darstellung benachbarter Inhalte.

## Offener Umfang und Legacy-Audit

| Bereich | Status / weiterer Weg |
|---|---|
| Vollständiges JavaScript | Offen: Arrow Functions, Klassen/Prototypen/this/new, Objektliterale, Destructuring, Exceptions, Module, Regex, Async/Promises, Timer und Standardbibliothek. |
| Exakte ECMAScript-Semantik | Offen: vollständiges Hoisting/TDZ/ASI, UTF-16-Stringindizes, Objektkonversion/Equality aller Typen, alle Array-Operationen und frühzeitige Syntaxfehlerprüfung. Explizite Semikolons verwenden. |
| Vollständiges DOM | Offen: dynamische stylesheets, CSSStyleDeclaration/classList, beliebige Selektoren, MutationObserver, NamedNodeMap/Live-Collections, Namespace-Attribut-APIs, Inline-on*-Handler, Event-Konstruktoren/Optionen, dynamisch nachgeladene Scripts. |
| Ressourcenkontext | Vorhandener lokaler/Callback-Resolver; vollständiges xml:base, MIME/CORS-/Netzwerkmodell und Skriptlade-Reihenfolge bleiben offen. |
| Ansichten | viewBox/preserveAspectRatio implementiert; viewTarget-Highlight, svgView-transform/zoomAndPan, allgemeine Elementfragmente und History/Navigation bleiben offen. |
| SVG-Fonts: font/glyph/missing-glyph/hkern/vkern | Nicht implementiert; explizite Diagnose. Denkbar: Glyphenkonturen/Advance/Kerning in bestehenden Textpfad übernehmen. TTF/OTF-Pfad bleibt bestehender Weg. |
| altGlyph/altGlyphDef/altGlyphItem/glyphRef/tref | Nicht implementiert, Diagnose; spätere Glyphen-/Textreferenzauflösung möglich. |
| color-profile | Nicht implementiert, Diagnose; ICC-Auswertung wäre eigene Farbmanagement-Abhängigkeit. |
| cursor-Element | Nicht implementiert, Diagnose. Bestehende CSS-Cursor-Assetzuordnung bleibt nutzbar. |
| flowRoot/flowRegion/flowPara | Entwurfs-/Legacy-Layout nicht implementiert, Diagnose; zusätzliche Textfluss-Geometrie nötig. |
| meshgradient/meshrow/meshpatch | Nicht implementiert, Diagnose; Tessellation und Farbinterpolation wären eigene Rasterfunktion. |
| hatch/hatchpath | Nicht implementiert, Diagnose; könnte auf Pattern-Raster aufbauen. |
| discard/handler/listener/prefetch/multiImage/subImage | SVG-Tiny-Erweiterungen nicht implementiert, Diagnose; getrennte Lebenszyklus-/Ereignis-/Ressourcenarbeiten. |
| foreignObject, feImage-SVG-Verweise und frühere Reste | Bleiben gemäß vorherigen Etappen offen. |

## Prüfung

- Gesamte SVG-Suite normal und -O2: Interpreter, Dom-Operationen, Ereignisse,
  Scope/Closures, Fehlerbudgets, Literal-false, Lvalue-Reihenfolge, Sprach-
  Matching, benannte und svgView-Fragmente, unverändertes Quelldokument,
  erwartete Ressourcendiagnose und Legacy-Diagnosen.
- Host: tatsächliche Pointer-zu-JavaScript-Ausführung, 20 Resets mit Freigabe
  von Realms/Listenern/EditableImages. Vorherige S37–S40-Tests bleiben aktiv.
- `node scripts/test-svg-scripting-browser.cjs`: echte Fixture-JavaScript-
  Ausführung in Node mit expliziten DOM-Mocks, gleiche Ergebnisassertionen wie
  Luau; generierte Frame-Skripte starten, Resize/Reset/Message-Isolation.
  Kein automatisierter nativer Browsertest.
- Tatsächliche Luau-Rastermontage nach den Testaktionen geprüft:
  `build/svg-s41-s42-preview.png` (Runner --script-preview).
- HTML-Regression, Generator-Abgleich, Projektprüfung und drei Rojo-Builds.

Referenzen: [SVG-Dokumentstruktur](https://www.w3.org/TR/SVG11/struct.html#ConditionalProcessing),
[SVG-Fragmente](https://www.w3.org/TR/SVG11/linking.html#SVGFragmentIdentifiers),
[ECMAScript Statements](https://tc39.es/ecma262/multipage/ecmascript-language-statements-and-declarations.html).

Nach Nutzervergleich: S43/S44. Diese Etappe bedeutet keine vollständige JS-/DOM-
oder SVG-Unterstützung; Restpunkte bleiben bis zur Supportmatrix offen.
