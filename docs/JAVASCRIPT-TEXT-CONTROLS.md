# Textauswahl in Eingabefeldern

Stand: 3. Oktober 2026. Ergänzung zu P07, Grundlage: [HTML-Textauswahl](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#textFieldSelection). Dies ist die Auswahl im Editor; die dokumentweite Range-/Selection-API bleibt separat.

## Implementierter Umfang

`selectionStart`, `selectionEnd`, `selectionDirection`, `select()`, `setSelectionRange()` und beide Überladungen von `setRangeText()` stehen auf HTML-Input und Textarea bereit. Die Bereichs-APIs gelten für textarea sowie input text/search/url/tel/password. Unbekannte Inputtypen folgen dem HTML-Textfallback. Bei anderen bekannten Typen lesen die Auswahlproperties `null`; Schreiboperationen und Range-Methoden werfen `InvalidStateError`. `select()` kann zusätzlich den vorhandenen nativen UI-Text von email/number auswählen, auch einen ungültigen Number-Zwischenwert. Textarea besitzt das schreibgeschützte `textLength`.

Die Algorithmen verwenden UTF-16-Positionen, geklemmte Grenzen, Web-IDL-Konvertierungsreihenfolge, nullable Setter, gebrandete Methoden mit name/length und echte DOMException-Objekte. Ersetzen unterstützt select/start/end/preserve, normalisierte Textarea-Zeilenumbrüche und einzelne Surrogat-Einheiten. Ein gleicher sanitierter Wert erhält die Auswahl; tatsächliche IDL-Wertänderungen setzen sie ans Ende. Defaultwerte, Reset, Clone und relevante Wertänderungen laufen über die bestehenden Controlzustände.

`select` wird bei API-Auswahländerungen asynchron geliefert. Element-`selectionchange` wird pro ausstehender Task zusammengefasst. Beide blubbern und sind nicht abbrechbar. `setRangeText` erzeugt kein künstliches input/change und keinen DOM-Text-Mutationsbericht. Native Benutzereingaben behalten ihre bestehenden Input-/Change-Wege.

## Native Darstellung und Grenzen

Roblox TextBox zählt Cursorpositionen in UTF-8-Bytes, JavaScript in UTF-16-Einheiten. `Controls/TextSelection` übersetzt beide Richtungen. Property-Signale werden gebündelt, API-Schreibvorgänge unterdrücken Zwischenzustände. Es gibt keine permanente Frame-Abfrage und keine Layoutanforderung für reine Auswahländerungen. Fokusverlust, Resize und Entfernen/Wiedereinfügen bewahren den DOM-Zustand; entfernte Editorobjekte lösen ihre Verbindungen.

Die native Anzeige kann keine Grenze innerhalb eines Surrogatpaars zeichnen. Die DOM-Position bleibt exakt, die sichtbare Auswahl liegt an der nächsten vollständigen Unicode-Grenze. Einzelne Surrogate bleiben im JavaScript-Wert und werden für Roblox als Ersatzzeichen dargestellt. Passwortfelder projizieren den Custom-Caret auf den maskierten Text.

Die Engine unterstützt die Standardrichtung `none`. Der geprüfte Chromium verwendet dafür `forward`; HTML lässt diese Plattformunterscheidung zu. `preserve` übernimmt bei beiden Überladungen das bestehende Browserverhalten; der aktuelle HTML-Entwurf begrenzt die Delta-Anpassung auf die Einargument-Variante. Die Referenzfixtures trennen ferner die konkret gemessenen Chromium-Unterschiede bei Defaultwert-/Reset-Cursorpositionen und dem Dirty-Flag eines ungültigen Ersetzungsbereichs. Diese Ausnahmen betreffen konkrete Rückgaben, keine pauschal übersprungenen Gruppen.

Weiter offen sind IME/Composition, vollständige Bidi-/Touch-Editorsteuerung, Auswahl-Scrolling und die Integration der Control-Auswahl in `document.getSelection().toString()`. Dynamische Wechsel zwischen unterschiedlichen nativen Input-Editorarten bleiben durch das bestehende Renderingprofil begrenzt. Die bisherigen VM-/Control-Wertbudgets gelten weiterhin.

## Wiederfinden und Nachweise

| Datei | Aufgabe |
| --- | --- |
| `JavaScript/TextControlSelection.luau`, `DOMControls.luau` | HTML-Algorithmen, Konvertierung, DOMException, Ereignistasks |
| `Controls/TextSelection.luau`, `State.luau`, `View.luau`, `FormModel.luau` | Native Bytepositionen, Werte, Fokus, Caret und Wiederherstellung |
| `Input/Controller.luau`, `Rendering/HTMLScripts.luau` | Native Signale und Realm-Anbindung |
| `tests/JavaScriptTextControlSelection.luau` | 16 Semantikfälle, native Positionsabbildung, Cleanup |
| `tests/JavaScriptTextControlSelectionRendering.luau` | Tatsächliche Controller-, Editor-, Layout- und Lebensdauerwege |
| `tests/JavaScriptSelectionCommitReviewPage.luau` | Unveränderter Seitenquelltext, 20 Browserzustände, sichtbare Texte/Werte/Animationen |

Browserreferenzen liegen in `tests/fixtures/javascript-text-control-selection-browser.json` und `javascript-selection-commit-page-browser.json`; autorisierte JavaScriptquellen samt enger Abweichungsangaben in `javascript-text-control-selection.json`. Einstieg zum isolierten Abgleich: `node scripts/test-javascript-text-control-selection.cjs`; `--serve` stellt dieselben Quellen für den nativen Browser bereit. Die Renderingtests verwenden die echten Module mit ersetzten Roblox-GUIs und Textmaßen. Sie ersetzen Tobias' Sichtvergleich in Studio nicht und messen keine FPS.
