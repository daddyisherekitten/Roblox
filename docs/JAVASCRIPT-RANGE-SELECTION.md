# Range und Selection · Vergleich 03

Stand: 3. Oktober 2026. Das neue Profil erweitert P06/P07 um lebende DOM-Bereiche und die sichtbare Textauswahl. Der vollständige Texteditor-/Shadow-DOM-Umfang bleibt offen.

Die späteren Eingabeerweiterungen und die Korrektur zum Aufheben der Markierung
bei Klicks auf freie Flächen/Textfelder vom 8. Oktober stehen im
[aktuellen R04-Eingabeprofil](JAVASCRIPT-INPUT-R04.md#nachweise).

Die fünf aktuellen Versuche stehen unter [JavaScript Labor](http://localhost:8000/javascript-tests/index.html?range=20261003-ready). Browser und Roblox erhalten dieselbe HTML-/CSS-/JavaScript-Quelle. Vergleich 02 bleibt als nicht ausgelieferte Regression in `tests/fixtures/javascript-review-page.json` erhalten.

## Erreichbare APIs

| Bereich | Implementiert |
| --- | --- |
| Erzeugung | `document.createRange()`, `Range`, `AbstractRange` als nicht konstruierbarer Basistyp, `StaticRange(init)` |
| Grenzen | `startContainer/Offset`, `endContainer/Offset`, `collapsed`, `commonAncestorContainer`, `setStart/End`, die Before-/After-Varianten, `collapse`, `selectNode`, `selectNodeContents` |
| Lesen und Vergleichen | `cloneRange`, `toString`, `compareBoundaryPoints` mit Konstanten, `comparePoint`, `isPointInRange`, `intersectsNode`, `detach` als kompatibler No-op |
| Inhalte | `cloneContents`, `extractContents`, `deleteContents`, `insertNode`, `surroundContents`, `createContextualFragment` |
| Auswahl | `getSelection()`, `window.getSelection()`, `document.getSelection()`, Singleton vom Typ `Selection`; `anchorNode/Offset`, `focusNode/Offset`, `rangeCount`, `isCollapsed`, `type`, `direction` |
| Auswahlmethoden | `getRangeAt`, `addRange`, `removeRange`, `removeAllRanges/empty`, `collapse/setPosition`, `collapseToStart/End`, `extend`, `setBaseAndExtent`, `selectAllChildren`, `deleteFromDocument`, `containsNode`, `toString`, `getComposedRanges` als Light-DOM-Snapshot |
| Sichtbarer Host | Native Mausauswahl ↔ DOM-UTF-16-Grenzen, `::selection`-Paint, `selectstart`, gebündelte asynchrone `selectionchange`, `Range.getClientRects/getBoundingClientRect` |

Baummutation, CharacterData, `splitText` und `normalize` passen Live-Ranges synchron über gemeinsame DOM-Hooks an. Der ausgewählte Range bleibt bei solchen Änderungen dasselbe Objekt. `StaticRange` speichert unveränderliche Grenzpositionen, keine Textkopie. Klonen erzeugt neue Knoten; vollständige extrahierte Knoten behalten ihre Identität und ihren Formularzustand. Abgelehnte Einfügungen lassen Quellknoten und Textteilungen unverändert. Grundlage: [DOM Range](https://dom.spec.whatwg.org/#interface-range), [DOM normalize](https://dom.spec.whatwg.org/#dom-node-normalize).

Eine reine Auswahländerung markiert weder DOM noch Layout als dirty. Sie plant einen Paint-Auftrag und höchstens ein `selectionchange` pro ausstehender Task. Inhaltsänderungen innerhalb der Auswahl mit unveränderten Grenzen aktualisieren nur den Paint. Native Auswahlereignisse laufen durch die vorhandene Realm-Serialisierung und Budgets. `selectstart` kann die neue Benutzeraktion abbrechen. Es entsteht keine neue Frame- oder Polling-Schleife. Grundlage: [Selection API](https://w3c.github.io/selection-api/).

## Grenzen und Referenzunterschiede

- Der öffentliche Auswahlumfang ist Light DOM eines Browsing-Dokuments. Kein `attachShadow`, Host-Rescoping für Shadow-Auswahl, Cross-Realm-Nodeimport, `contenteditable`, IME, blinkender Editing-Caret oder `Selection.modify`. Native TextBox-Auswahl und ihre JavaScript-Methoden sind inzwischen im separaten [Textfeldprofil](JAVASCRIPT-TEXT-CONTROLS.md) implementiert. Die Weitergabe des Textfeld-Auswahltexts an `getSelection().toString()` bleibt offen.
- `containsNode` vergleicht DOM-Grenzen und strukturell gleichwertige Baumkanten. Es löst keine vollständige visuelle Äquivalenz durch White-Space-Collapse, ausgeblendete oder ersetzte Elemente und Bidi-Shaping. Die aktuelle Chromium-Abweichung bei Text-/Elementcontainment ist im Referenzdatensatz getrennt erfasst.
- Auswahl-Paint und Quellzuordnung unterstützen gewöhnlichen horizontalen Text, Unicode-Grapheme, Texttransform, Whitespace, Zeilenumbruch, Scrollen, Resize, UIScale und native 2D-Rotation. Allgemeines Bidi-/Vertikal-Shaping und perspektivische Textflächen bleiben offen.
- Range-Textrechtecke verwenden kalibrierte native Label-Zeilenboxen. Exakte Browser-Font-Ascent-/Descentwerte und vollständige Rechtecke hinter Ellipsis/Line-Clamp fehlen. Kopierter Auswahltext stammt aus den ursprünglichen dargestellten Runs und wird durch Ellipsis oder weichen Zeilenumbruch nicht abgeschnitten. Teilweise gewählte Grapheme und CRLF werden ausdrücklich gegen den Browser geprüft. Die Datenlaufzeit ohne Renderingadapter verwendet als Stringifier-Fallback den rohen Range-Text. Grundlage: [CSSOM View Range](https://drafts.csswg.org/cssom-view/#extensions-to-the-range-interface).
- `createContextualFragment` verwendet den vorhandenen begrenzten HTML-/SVG-Fragmentparser. Vollständige WHATWG-Parserparität, XML-Kontexte, Trusted Types und Custom-Element-Reactions sind kein abgeschlossener Umfang. Die veraltete Select-Kinder-Flattenregel wurde entfernt: aktuelles HTML behält gewöhnliche Fragmentkinder auch im Select-Kontext. Grundlage: [HTML insertion mode](https://html.spec.whatwg.org/multipage/parsing.html#reset-the-insertion-mode-appropriately).
- Der Range-/Selection-Unterbau folgt den dokumentierten aktuellen DOM-/WebIDL-/Selection-Regeln, wo Chromium davon abweicht. Betroffen sind ein leerer Text am Ende von `normalize`, Interface-Vererbung, besondere `newTarget`-Fälle und Auswahlrichtung nach direkter Range-Mutation. Native Werte und eng begrenzte Standarderwartungen bleiben beide gespeichert; diese Fälle sind kein vollständiger Chromium-Paritätsnachweis. Grundlage: [Web IDL Interface objects](https://webidl.spec.whatwg.org/#es-interface-object).

Die vorhandenen VM-/DOM-/Parserbudgets bleiben aktiv. Zusätzlich gelten 4096 gleichzeitig registrierte Live-/Static-Ranges, 256 verschachtelte partielle Inhaltsoperationen und 8192 kopierte Knoten. Die native Zuordnung begrenzt 32768 Knoten, 131072 Quellspannen, 4096 Rechtecke, 16384 Paint-GUIs und 1 MiB kopierten Text. Schwache Range-Registrierung gibt unbenutzte Bereiche frei; wiederholtes Ziehen verbraucht kein kumulatives Range-Kontingent. Range und Selection sind nicht strukturiert klonbar. Abbau entfernt Hooks, Markierungen und gespeicherte Knotengrenzen.

## Prüfung

| Prüfung | Ergebnis |
| --- | --- |
| Range-Kern | Elf native Browsergruppen; jede Beobachtung strikt verglichen, sechs dokumentierte wertbegrenzte Standardabweichungen; zusätzlich Hierarchie-/Budget-/GC-/Destroychecks |
| Range-Inhalte | 37 gemeinsame Fälle, alle im tatsächlichen Luau-DOM und Chromium; zusätzlich private Shadow-Container, Renderer-Preflight, Budget-Recovery und Abbau |
| Selection | 18 gemeinsame API-Profilfälle mit getrennten Browser-/Standarderwartungen; vier zusätzliche native Rendered-Text-Gruppen; Task-Coalescing, vertrauenswürdige Ereignisse, Abbruch, native Clear-Aktionen und kein Layout bei reiner Auswahl |
| Native Zuordnung | Bestehende TextSelection-Suite und neue ScriptSelection-Suite: Quellspannen, Grapheme, Whitespace, Wrap/Ellipsis, Texttransform, CRLF, Geometrie, Paint und Lebenszyklus |
| Seitencode | Aktuelle fünf Karten und historische dreizehn Karten laufen durch DOM, FormModel, Rendering, Dirty-Layout und Runtime; aktuelle Browseraktionen ohne Konsolenfehler geprüft |
| Gemeinsamer Unterbau | DOM-Mutationen, Controls, MutationObserver, lebende Abfragen/Traversierung, Observerbudgets, Host-Serialisierung, native Deskriptoren und ScriptTransforms geprüft; keine FPS-Benchmarks |

Gezielte Einstiegspunkte: `scripts/run-dom-ranges-tests.cjs`, `scripts/test-javascript-range-contents.cjs`, `scripts/test-javascript-selection.cjs`, `scripts/test-script-selection.cjs`, `node scripts/run-html-tests.cjs JavaScriptRangeReviewPage`. Referenzserver sind nur temporäre Testhelfer; sie gehören nicht zum Websitekatalog.
