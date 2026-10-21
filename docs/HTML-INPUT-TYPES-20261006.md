# Eingabetypen und Auswahlfenster

Stand: 6. Oktober 2026. Diese Etappe ergänzt die sieben Typen der
[seit dem 16. Oktober archivierten Vergleichsseite](../tests/fixtures/retired-window-pages-20261016.json). Sie verwendet im
Browser und in Roblox dieselben HTML-, CSS- und JavaScriptquellen. Das Profil
ist kein Abschluss sämtlicher HTML-Formularregeln oder aller Betriebssystem-Picker.

## Implementierter Umfang

| Typ | Darstellung und Bedienung | Werte und Formularverhalten |
| --- | --- | --- |
| `date` | Getrennte Tag-/Monat-/Jahrsegmente, Kalendersymbol, Monatskalender, Monats-/Jahrauswahl, Heute/Löschen | Kalenderprüfung inklusive Schaltjahren; ISO-Datum; Grenzen, Schritte, Pflichtfeld und Reset |
| `datetime-local` | Datumssegmente; Kalender links, Stunden-/Minuten-/gegebenenfalls Sekundenspalten rechts im selben Auswahlfenster | Lokales Datum mit Uhrzeit ohne Zeitzonen- oder DST-Umrechnung; normalisierte Zeichenfolge; numerische Millisekunden |
| `month` | Benannter Monat, Jahrsegmente und Monatsraster mit Jahreswechsel | Monate seit Januar 1970 als numerischer Wert; Grenzen und Schritte in Monaten |
| `week` | ISO-Woche und Wochenjahr; Kalender mit Wochennummern und Wochenauswahl | ISO-Wochenjahr, 52/53 Wochen und Jahresübergänge; Montag als numerische UTC-Wochengrenze |
| `time` | Uhrsymbol, einzelne Zeitsegmente und scrollbare Zeitspalten | Stunden, Minuten, Sekunden und Millisekunden; Schrittweite in Sekunden; auch über Mitternacht verlaufende min/max-Bereiche |
| `image` | Bestehender Raster-/SVG-Bildpfad einschließlich HTML-Abmessungen, Ladefehlerfläche, Alt-Text und Fokus | Echter Submitter; `name.x`/`name.y` beziehungsweise `x`/`y` für namenlose Bilder; Mauskoordinaten, programmatische Aktivierung mit 0/0 |
| `file` | Auswahlbutton und Text für keine ausgewählte Datei; `multiple` und `disabled` berücksichtigt | **Nur Darstellung in dieser Etappe. Die Dateiauswahl wird ausdrücklich später ergänzt.** |
| `color` | Chromium-ähnliche Farbfläche, Farbtonregler, Vorschau und RGB-/HSL-/HEX-Eingaben; Maus, Touch und Tastatur | Deckendes 8-Bit-sRGB als `#rrggbb`; live `input`, einmal `change` beim Schließen einer geänderten Auswahl; Reset und programmatische Änderungen ohne künstliche Ereignisse |

## Farbauswahl – 13. Oktober 2026

Der Farbwähler gilt für alle `input type="color"`, einschließlich der
[archivierten Formular-Vergleichsseite](../tests/fixtures/retired-window-pages-20261016.json).
`Input/ColorPopup` baut einmal pro Öffnung eine 234 × 251 px große Oberfläche
nach dem [gelieferten Chromium-Screenshot](../tests/fixtures/color-popup-chromium-reference.png) auf. Zwei native `UIGradient`-Flächen
erzeugen Sättigung und Helligkeit; der Farbtonregler verwendet einen Farbverlauf.
Ziehen aktualisiert nur Werte, Zeiger und Paint, ohne Rasterbilder oder Layout.
RGB, HSL und HEX lassen sich über die kleinen Pfeile unten rechts umschalten.
Ungültige oder unvollständige Texte ändern den Farbwert nicht; numerische Werte
werden an die Kanalgrenzen geklemmt und beim Verlassen normalisiert.

Ein Klick, Enter/Leertaste oder aktiviertes `showPicker()` öffnet die Auswahl.
Tab/Shift+Tab führt durch Farbfläche, Regler, Kanalwerte und Formatwechsel.
Pfeiltasten verändern den aktiven Bereich; Enter, Escape oder ein Außenklick
schließt das Fenster und übernimmt die bereits sichtbare Auswahl. Unverändertes
Öffnen/Schließen erzeugt kein `change`. `disabled`, Entfernen des Besitzers und
Seitenabbau geben Fenster, Fokus und Verbindungen frei. `readonly` wirkt bei
`color` entsprechend HTML nicht. Das Fenster wird an den Viewport angepasst;
bei einer Größen- oder Positionsänderung des Ankers schließt es.

Grenzen: Die Pipette ist als graues, inaktives Symbol vorhanden. Roblox stellt
keinen Zugriff auf beliebige Bildschirm-Pixel bereit. Alpha-/Display-P3-Picker,
Farblisten aus `datalist` und das plattformabhängige Aussehen anderer Browser
sind mit dieser Ergänzung nicht implementiert. Das bestehende Werteprofil
bleibt auf sechsstellige Hexwerte begrenzt; aktuelle HTML-Farbgrammatik,
`alpha` und `colorspace` sind damit nicht als vollständig abgedeckt markiert.
Die Ereignisse benutzen den bestehenden synchronen Hostpfad; dies belegt keine
vollständige Browser-Taskordnung. Die HTML-Regeln für Werte, Aktivierung und
Ereignisse stehen im [HTML-Standard](https://html.spec.whatwg.org/multipage/input.html#color-state-(type=color)).

`tests/ColorPopup.luau` prüft Farbwerte, Grenzkoordinaten und Pointer-Identität,
RGB/HSL/HEX-Bearbeitung, Fokus, Ereignisse, Aktivierung, echte JS-Listener,
unveränderte GUI-Identität, ausbleibende Layoutanfragen und vollständigen Abbau.
Der Screenshot dient als Darstellungsreferenz; die endgültige Roblox-Optik
bleibt vom Nutzer in Studio zu beurteilen.

Datum-/Zeitfelder bieten `value`, `defaultValue`, `valueAsNumber`,
`valueAsDate` (außer `datetime-local`), `stepUp`, `stepDown`, Prüfung und Reset.
`valueAsDate` verwendet UTC für Datum/Woche/Monat und den 1. Januar 1970 für
Uhrzeiten. Unpassende Date-Zuweisungen und `step="any"` bei Schrittmethoden
werden abgewiesen. Die numerischen Methoden sind auch an `number` und `range`
angebunden. Programmatische Wertänderungen erzeugen keine künstlichen
`input`-/`change`-Ereignisse.

Die Felder lassen sich mit Ziffern, Links/Rechts, Auf/Ab und Löschen bearbeiten;
ein unvollständiger Wert bleibt als Segmentzustand sichtbar und meldet
`badInput`. Leertaste/Enter öffnet den Picker. Dort dienen Pfeiltasten und
PageUp/PageDown der Auswahl, Tab/Shift+Tab den Aktionen und Escape dem Schließen.
Die Auswahlflächen unterstützen Maus und Touch. Eine bestätigte Auswahl
meldet `input` und `change`. `readonly` und `disabled` öffnen keine Picker.
Millisekunden lassen sich im Feldsegment bearbeiten; die Popup-Spalten zeigen
Stunden, Minuten und gegebenenfalls Sekunden. Dateifelder behalten unvollständige
Segmentwerte auch beim Entfernen und Wiedereinfügen derselben DOM-Node.
Der kombinierte Datum-/Zeitpicker behält die Uhrzeitspalten neben dem Kalender
auch bei der Monats-/Jahrauswahl. Bei zu schmalem Hostfenster wird der Picker
horizontal scrollbar; er stapelt die Bereiche nicht. Eine Wertauswahl erhält
die Scrollposition, und Tab blendet das fokussierte Ziel durch Scrollen ein.
Aktive Kalenderzellen, Zeitwerte und Aktionen zeigen eine lokale Hover-Fläche;
deaktivierte Werte erhalten keine Hervorhebung. Native Bewegungen und Mausrad
über dem Picker gehen nicht an den DOM-/CSS-Hover der darunterliegenden Seite.

`showPicker()` ist an den vorhandenen Host angebunden und benötigt bei einer
gemounteten Seite eine aktuelle Benutzeraktivierung. Der Host verwendet dafür
ein zeitlich begrenztes Aktivierungsfenster; das ist noch kein vollständiges
Browsermodell für alle Aktivierungsquellen und Cross-Origin-Regeln.

## Dateifeld: bewusst verschobener Teil

Das Dateifeld öffnet in Roblox derzeit **keinen Dialog** und wählt **keine Datei**.
Ein Klick kann ein normales DOM-`click` auslösen, simuliert jedoch weder eine
Auswahl noch ein `change`. Die spätere Dateiauswahl benötigt einen gesonderten
Hostweg. Diese Etappe bewertet sie nicht als prinzipiell unmöglich und gibt ihr
keinen abgeschlossenen Status.

Die Standard-Browserseite behält den echten Dateidialog einschließlich lokalem
Namens-/Größen-/Typbericht und Bildvorschau. In Roblox ist `files` zunächst eine
leere Liste; eine leere Wertzuweisung oder Reset leert den Zustand, eine
nichtleere `value`-Zuweisung wirft `InvalidStateError`. Das bestehende FormData-
Profil erzeugt für nicht ausgewählte Dateien den normalen leeren File-Eintrag.
Vollständige FileList-Zuweisung und Auswahlereignisse gehören zum späteren Hostweg.

## Architektur und Arbeit pro Änderung

- [TemporalValue](../src/HTMLEngine/Controls/TemporalValue.luau) enthält gemeinsame
  Kalender-, ISO-Wochen-, Parsing-, Grenz- und Schrittfunktionen ohne lokale Zeitzone.
- [TemporalEdit](../src/HTMLEngine/Controls/TemporalEdit.luau) verwaltet die
  Segmentbearbeitung; [TemporalView](../src/HTMLEngine/Controls/TemporalView.luau)
  zeichnet die Felder und hält Messungen lokal am jeweiligen Segment.
- [TemporalPopup](../src/HTMLEngine/Input/TemporalPopup.luau) besitzt ausschließlich
  die vorübergehenden Auswahlflächen. Es schließt beim Verschieben des Ankers,
  beim Resize, bei Außenklick, Entfernen und beim Dispose der Seite.
- [InputValues](../src/HTMLEngine/JavaScript/InputValues.luau) verbindet numerische
  und Date-APIs mit denselben Control-Werten; FormModel und DOMControls verwenden
  dieselbe Sanitization und Validitätsberechnung.
- [FileView](../src/HTMLEngine/Controls/FileView.luau) zeichnet den Dateibutton.
  Bildbuttons verwenden ImageBox, den vorhandenen Ressourcenpfad und SVG-Renderer.

Eine Wertauswahl braucht kein neues Seitenlayout. Nur die betroffenen Controls,
CSS-Zustände und tatsächlichen Änderungen der Live-Ausgabe werden aktualisiert.
Das normale Dirty-Layout bleibt für geometrisch wirksame Änderungen zuständig.
Es gibt keinen neuen Frame-Loop pro Feld oder Popup und keinen Zugriff auf
Roblox-GUI-Instanzen aus dem JavaScript der Website.

## Vergleich und Nachweise

Die frühere Referenz `InputTypes` ist seit dem 16. Oktober mit Browserquellen
und generierten Roblox-Modulen im
[Regressionarchiv](../tests/fixtures/retired-window-pages-20261016.json) erhalten.
Sie ist keine aktive Web-/Katalogseite mehr; der aktuelle Start ist `WindowCheck`.
Die Standard-Webquelle bleibt unverändert portierbar.

[TemporalInputs](../tests/TemporalInputs.luau) prüft die Kalenderregeln,
Wochengrenzen, Picker-Aktionen, unveränderte Feldidentität, fehlende Layoutanfragen,
Teilwerte/Reset, Bildkoordinaten und die tatsächliche Seiten-JavaScript-Datei mit
Schrittbuttons und DOM-APIs. Die nachfolgende Layout-/Hover-Regression ergänzt
die horizontale Datum-/Zeitansicht, erhaltenes Datum/Scrollen und native
Mausbewegungen durch Controller bei geschlossenem Select-Popup.
Die vollständige Engine-Regression dieser Etappe
bestand 254 Suiten; spätere Reviewänderungen erhalten gezielte Wiederholungen.
Die abschließende Wiederholung bestand zehn Suiten einschließlich Formularen,
Bildladezuständen, Ladefehlergrößen und Memory. Projektprüfung (843 Luau-Dateien),
Website-Generatorprüfungen (fünf Tests), aktueller API-Export und Rojo-Build waren
erfolgreich. Der Browservergleich meldete keine Konsolenfehler.
Native Studio-Darstellung und FPS bleiben Tobias' Vergleich. Ein pixelgleicher
Abgleich aller Roblox-Picker ist noch nicht durch eine Studio-Aufnahme belegt.

Die nachgebildete Darstellung orientiert sich an einem deutschen Desktop-Picker.
Browser/Betriebssystem können andere Kalender, Monatsnamen, Farbthemen oder
Fehlermeldungen zeigen. Mobile Betriebssystemdialoge, alternative Kalender,
native Screenreader-Anbindung, automatische locale-Auswahl, Datums-Datalist-
Vorschläge und beliebig erweiterte Jahresbereiche werden hier nicht als fertig
bezeichnet. Das bisherige Color-Control wird durch diese sieben Typen nicht
automatisch zu einem vollständigen nativen Farbdialog.

Normative Referenz:
[HTML-Eingabetypen und gemeinsame APIs](https://html.spec.whatwg.org/multipage/input.html),
[Datum-/Zeitzeichenfolgen](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#dates-and-times)
und [Formulareinträge](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#constructing-the-entry-list).
