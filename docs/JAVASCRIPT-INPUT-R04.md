# R04: Auswahl, Eingaben und native Geometrie

Stand: 5. Oktober 2026. Referenzprofil: Chromium 154 auf Windows. Die Engine verwendet den vorhandenen DOM-/Range-Unterbau, die native TextBox-Anbindung und tatsächlich gerenderte Textfragmente. Ein Style-String allein gilt nicht als Darstellungsnachweis.

## Ergänzt und geprüft

- Dokument- und Shadow-Auswahl mit UTF-16-Grenzen, `getComposedRanges`, Rescoping nicht freigegebener Shadow Roots, geschachtelten Roots und den von Chromium angebotenen getrennten `ShadowRoot.getSelection()`-Ansichten. Geliehene Selection-Methoden und Getter akzeptieren authentifizierte Instanzen aus anderen aktiven Realms.
- Ausgewählter Text in nativen Controls, einschließlich `email`/`number` mit rein nativer UI-Auswahl. Password-Auswahl liefert maskierte Grapheme. Kombinierte Zeichen, Supplementary-Codepoints und Emoji-ZWJ-Familien werden im nativen Referenzprofil nicht zerlegt.
- `Selection.modify` für logische Zeichen/Wörter, einfache Satz-/Absatzgrenzen und Dokumentgrenzen; Zeilenbewegung und Zeilenenden verwenden aktuelle native Fragmentkoordinaten. Vertikale Bewegung behält die visuelle Spalte. `dir=auto` findet die erste starke Schreibrichtung.
- Auswahlpaint und Caretgeometrie für homogene RTL-Wörter. Die generierte Unicode-17-Bidi-Class-Tabelle klassifiziert Zeichen; sie ist ausdrücklich kein vollständiger Unicode-Bidi-Layoutalgorithmus.
- Auswahl-Scrolling durch die bestehenden Scrollcontainer, Scroll-Padding/-Margin und Shadow-Host-Anbindung. Resize, Scroll, Entfernen und neue Fragmente werden über dieselben vorhandenen Layout-/Paintpfade verarbeitet.
- `InputEvent.getTargetRanges()` liefert neue Arrays und neue StaticRange-Snapshots. Konstruktor-Konvertierung und fehlerhafte Iterablewerte wurden im tatsächlichen Chromium erfasst; dessen fehlendes IteratorClose bei fehlerhafter Web-IDL-Sequenzkonvertierung wird als Referenzprofil festgehalten.
- Retained native `contenteditable`-Eingabe mit formatiertem DOM, `beforeinput`-Abbruch, echten Zielranges, geschützten Inseln und Rich-/Plaintext-Zeilenumbrüchen: [Editing-Profil](JAVASCRIPT-EDITING-R04.md).
- Capture-Verlust bei Entfernen, erhaltener `moveBefore`, Mehrkontakt-Ereignisse, frische Pointer-Geometrie, native Wheel-Line-Units und Cleanup: [Pointer-/Touch-Profil](JAVASCRIPT-POINTER-TOUCH-INPUT.md).
- UA-Fokusrahmen unabhängig vom CSS-Rand: `:focus-visible` ergänzt eine schwarze automatische Kontur vor der Author-Cascade. Eigene Konturen, `outline:none`, Farbe und Offset bleiben wirksam. Textfelder, Password, Block-/Flex-Controls und Shadow-Eingaben wechseln den Fokus ohne Layoutanfragen. [Outline-Profil](OUTLINE.md) und `tests/fixtures/focus-outline-browser.json` dokumentieren den direkten Browservergleich.
- Natives Ziehen am Textarea-Griff schreibt die tatsächlich veränderten Achsen in den Inline-Style. JavaScript-Stylegetter und MutationObserver sehen die neuen Maße; weitere Author-Deklarationen bleiben erhalten. Ein nachfolgender Fokuswechsel stellt die alte Größe nicht wieder her und fordert kein zusätzliches Layout an.

## Nachweise

Nachtrag 8. Oktober 2026: Primäre Mausklicks auf freie auswählbare Seitenflächen,
Text, native Textfelder, Datum-/Zeitfelder und Summary-Inhalt kollabieren die
Dokumentauswahl. Freiflächen liefern dafür eine DOM-Grenze; Textfelder liefern
die Grenze vor dem Feld. Ein fehlender Texttreffer wird nicht mehr als
`NativeChange(nil, ...)` gemeldet und anschließend als alte Auswahl restauriert.
Eine kollabierte Auswahl behält einen Range, während `removeAllRanges()` ihn
ausdrücklich entfernt. Bereits vorhandene feldinterne Auswahl bleibt getrennt.

Der direkte Chromium-Vergleich bestätigt auch die Ausnahmen: Rechtsklick,
gewöhnliche Buttons, Radio-/Checkbox-/Range-Controls, Links und
`user-select:none` erhalten die Dokumentauswahl. Abgebrochenes `pointerdown`
oder `mousedown` löst ebenfalls keine Auswahländerung aus. Klicks außerhalb
der Seitenoberfläche verändern die Auswahl nicht. Das Profil bildet diese
Unterschiede ab; es setzt kein pauschales `removeAllRanges()` für jeden Klick ein.
Die genaue nächstgelegene Caretposition auf einer leeren Boxfläche bleibt
angenähert: derzeit Boxanfang beziehungsweise Textfeldgrenze, kein vollständiger
Browseralgorithmus für visuell gleichwertige Bidi-/Boxgrenzen.

`JavaScriptTextControlSelectionRendering` prüft diese Aktionen mit montiertem
Controller, echten Runtime-Ranges und Selection-Paint: Overlays verschwinden,
das `selectionchange` wird einmal ausgeliefert, Quell-GUIs bleiben erhalten,
und Auswahl allein fordert kein Layout an. Die neue Referenz ist
[native-control-theme-selection.json](../tests/fixtures/native-control-theme-selection.json).

`tests/fixtures/javascript-r04-selection-browser.json` enthält 25 tatsächlich erfasste Chromium-Fälle. 20 werden im Daten-Realm, die übrigen fünf über montierte Renderer-/Controller-/TextBox-Adapter geprüft. Drei zusätzliche montierte Fälle prüfen kombinierte Zeichen, native Rückwärtsauswahl und komplexe Text-/Password-Grapheme.

`javascript-r04-input-browser.json` hält Konstruktorreihenfolge, homogene Hebrew-Navigation, Maskierung und StaticRange-Identität fest. `javascript-r04-editing-browser.json` enthält einen echten Enter-Tastendruck samt DOM-, Caret- und `beforeinput`-/`input`-Ergebnissen. `tests/ScriptSelection.luau` prüft tatsächliche Fragmentprojektion, Overlay-Wiederverwendung, RTL-Caretkoordinaten, Resize, Scroll und entfernte Quellen.

Die ausgelieferte [Vergleichsseite 09](http://localhost:8000/javascript-tests/index.html?r04=20261004-ready) zeigt vier kombinierte Beispiele. `JavaScriptR04ReviewPage` führt deren unveränderten Quelltext mit montierten Adaptern aus und prüft Tabellen, Komponenten, native Eingaben, Auswahl, Capture, Resize und Cleanup. Automatisierte GUI-Adapterprüfungen ersetzen keine abschließende visuelle Prüfung in einer echten Studio-Sitzung. FPS-Benchmarks wurden nicht ausgeführt.

Die gemeinsame Gesamtsuite mit 232 registrierten Testgruppen besteht, einschließlich der unabhängigen Query-/Range- und GC-Prüfprozesse. `scripts/check-project.cjs` prüft zusätzlich 792 Luau-Dateien, die Browserquellen und alle Rojo-Projekte. Der Build von `htmlpage.project.json` sowie der Aktualitätscheck des API-Registers bestehen. Der Registerexport enthält 4.457 Deskriptoren und liest keine Getter. Diese Zahlen belegen den jeweiligen Prüfbestand, keine vollständige Standardkonformität.

Die Abschlussreviews korrigierten außerdem unnötige Marker-Invalidierung bei Hover/Resize, die reihenfolgeabhängige Auswertung gleichzeitiger Eltern-/Kindmutationen, Formular-Popup-Reset sowie interne TypedArray- und Realm-Lifetime-Fehler. Bestehende Assertions bleiben erhalten; Option-Klonzustände werden anhand von `javascript-option-clone-browser.json` im tatsächlichen Browserprofil geprüft.

## Offen und hostbegrenzt

Seit 19. Oktober 2026 bereitet `Input/NativeSelectionCopy` eine mit der Maus
markierte Dokumentauswahl für natives Strg+C beziehungsweise Cmd+C vor. Eine
transparente, schreibgeschützte und passive Roblox-TextBox hält ausschließlich
den über `ScriptSelection:CopyText` ermittelten Klartext. Unicode, ursprüngliche
Schreibung und gerenderte Zeilenumbrüche bleiben erhalten. Die Anbindung läuft
auch ohne JavaScript-Realm, Browser oder WindowManager. Native Eingabefelder und
contenteditable behalten ihre eigene Auswahl; Browserdialoge und eingebettete
Dokumente beachten die bestehenden Eingabegrenzen.

Es gibt keinen programmierten Zugriff auf die Betriebssystem-Zwischenablage.
Roblox übernimmt den tatsächlichen Kopiervorgang über seine native TextBox.
`NativeSelectionCopy` und `SelectionCopyMounted` prüfen Textaufbereitung,
Fokusübergänge, Tastaturereignisse, Änderungen bei bestehender Auswahl und
vollständiges Aufräumen mit kontrollierten nativen Diensten. Der tatsächliche
Zwischenablageninhalt und die erste Tastenkombination im Studio/Player müssen
zusätzlich dort geprüft werden. `navigator.clipboard`, Rich-Clipboard,
Kontextmenü und mobiles Kopieren werden dadurch nicht implementiert.

R04 ist keine vollständige Editing- oder Auswahlkonformität. Gemischte Bidi-Runs, visuelle Caret-Affinität, vollständige ICU-Satz-/Wortsegmentierung, komponierte Slotnavigation und vertikale Schreibrichtungen bleiben offen. HTML-Editing einschließlich Undo/Redo, Rich-Clipboard, sämtlicher Absatz-/Listen-/Tabellenoperationen und aller Focus-/Web-IDL-Randfälle braucht weitere Arbeit.

Roblox veröffentlicht keine nachgewiesenen OS-IME-Zwischenstände für diesen Adapter. Übernommen werden native veröffentlichte Textänderungen; `compositionstart/update/end` werden nicht aus Textänderungen erfunden. Ein OS-Dateiauswahldialog ist nicht vorhanden. Pan-Achsen-Schnittmengen, Native-Pan-Takeover und die genaue Reihenfolge einer OS-Wheel-Cancellation bleiben als Host-/Konformitätsgrenzen im Pointerprofil ausgewiesen.

Referenzen: [Selection API](https://w3c.github.io/selection-api/), [CSSOM View](https://drafts.csswg.org/cssom-view/), [HTML Editing](https://html.spec.whatwg.org/multipage/interaction.html#editing), [Roblox TextBox](https://create.roblox.com/docs/reference/engine/classes/TextBox).
