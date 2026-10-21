# Formulare und Eingabe – erster Teilumfang

Das ursprüngliche Formularprofil steht unten. Den aktuellen Zusatz für Datum-,
Zeit-, Datei- und Bild-Eingabetypen dokumentiert
[HTML-INPUT-TYPES-20261006](HTML-INPUT-TYPES-20261006.md). Dateiauswahl bleibt dort
bewusst verschoben; für weitere Eingaben gilt zusätzlich [R04](JAVASCRIPT-INPUT-R04.md).

Der am 13. Oktober ergänzte allgemeine RGB-/HSL-/HEX-Farbwähler ist im
[Eingabetypen-Profil](HTML-INPUT-TYPES-20261006.md#farbauswahl--13-oktober-2026)
dokumentiert. Die ältere offene Liste unten beschreibt den damaligen Stand;
dieser Picker ist inzwischen vorhanden, mit ausdrücklich begrenztem Farbprofil.

## CSS-Rahmen und Button-Ecken – 8. Oktober 2026

Einfache Controls zeichnen einzelne beziehungsweise gemusterte Rahmenkanten
jetzt mit dem gemeinsamen `Rendering/BorderBox`. Ein vollständiger solider
Rahmen behält den vorhandenen `UIStroke`; abgeschaltete Kanten bekommen keinen
zusätzlichen Ring. CSS-Wechsel zwischen diesen Darstellungen erhalten das
Control, TextBox und Beschriftung und räumen nur die alten Rahmenflächen auf.
Entfernte Controls geben auch die zugehörigen Eck-/Musterressourcen frei.

Bei `button` und `input` der Typen `button`, `submit`, `reset` beginnt der
CSS-Eckenradius bei null. Gewinnende Autorenangaben für Rahmen, Hintergrund
oder Eckradien verhindern die bisher pauschale 3-px-Themenrundung. Explizite
Radien bleiben erhalten; einzelne Eckangaben lassen die übrigen Ecken bei null.
`revert` und `revert-layer` berücksichtigen den Ursprung je CSS-Komponente.
Ein ungestalteter Button behält die bisherige native Themenannäherung.
Diese Ursprungsauswertung ist auf Buttons begrenzt; die Default-Rundung anderer
Eingabetypen wird damit nicht als vollständig browserkonform eingestuft.

Die Bytebude-Reiter zeigen den konkreten Fall: `border-bottom:0` entfernt
den unteren Buttonrahmen. Die Leiste selbst zeichnet die verbleibende
1-px-Linie. Hier findet kein `border-collapse` statt. Chromium bestätigt
bei allen drei Reitern null Radius, null untere Rahmenbreite und genau 1 px
zwischen Buttonunterkante und Leistenunterkante.

`tests/ControlBorders.luau` prüft diese tatsächliche Seite, alle drei Buttontypen,
Deklarationsreihenfolge, `!important`, Vererbung, Variablen/ungültige Werte,
Rollback, separate Feldkanten, transparente Muster, Hover ohne Layout oder
Neuaufbau, spätere Rahmen-/Radiusänderungen und Ressourcenfreigabe.
Form-/Fokus-, Rahmen-, Layout-, Animations- und Spielregressionen bleiben
zusätzliche Nachweise. Die endgültige sichtbare Roblox-Darstellung bewertet
Tobias in Studio. Raster-/Eckmuster behalten die Grenzen der
[Rahmendarstellung](BORDER-SIDES.md).

Grundlage: [CSS UI – Properties Disabling Native Appearance](https://www.w3.org/TR/css-ui-4/#appearance-disabling-properties).

## Hell-/Dunkelmodus nativer Controls – 8. Oktober 2026

Radio-Buttons behalten ihre innere Ringfläche und aktualisieren sie bei jedem
Paint aus dem aufgelösten `color-scheme`. Die zuvor fest weiße Fläche verdeckte
die korrekte dunkle Hintergrundfarbe. Gewählte, ungewählte und deaktivierte
Radios verwenden jetzt dieselbe dunkle Feldfläche. `appearance:none` entfernt
Ring und Punkt; `visibility:hidden` blendet beide aus. Ein CSS-Hintergrund
auf einem Control ohne native Darstellung bleibt auch bei `checked` erhalten.

Der automatische Akzent für dunkle Radio-/Checkbox-Controls und der Radio-
Hover-/Pressed-Akzent entsprechen der direkt erfassten Chromium-154-Referenz.
Autorenangaben für `accent-color` bleiben erhalten. Checkbox-Markierungen
verwenden im dunklen Standardprofil die Feldfarbe für ihren Kontrast.
Die native Darstellung bleibt ein kalibriertes Windows-/Chromium-Profil,
keine pixelgenaue Zusage für alle Browser und Betriebssysteme.

`color-scheme`, seine aufgelösten Themenmetadaten und `scrollbar-color` sind
Paintänderungen. Der gemeinsame Scrollbar-Painter aktualisiert Thumb und
vorhandene Trackflächen ohne Canvasgrößen oder Scrollposition anzufassen.
Andere gleichzeitig veränderte CSS-Maße lösen weiterhin Layout aus.
`ControlBorders` prüft wiederholte Hell-/Dunkelwechsel an den tatsächlichen
Bytebude-Radios sowie reine Themenwechsel ohne Layout oder GUI-Allokation,
beide Punktdarstellungen, eigene Akzente, deaktivierte/ausgeblendete Controls
und unveränderte Scrollgeometrie. Die Browserbeobachtungen liegen in
[native-control-theme-selection.json](../tests/fixtures/native-control-theme-selection.json).

## Ursprüngliches Formularprofil

Beispiel 29 enthält dieselben HTML-Elemente im Browser und in Roblox. Der Browser
verwendet weiterhin seine nativen Steuerelemente. Roblox zeichnet deren Rahmen,
Farben und Rundungen näherungsweise; ein visueller Studio-Abgleich steht noch aus.

## Unterstützt

- `form`, `label` mit `for` oder verschachteltem Feld, `output`.
- `fieldset` und `legend`, einschließlich `fieldset disabled`.
- `input` mit `text`, `email`, `url`, `password`, `number`, `checkbox`, `radio`, `range`, `button`, `submit`, `reset`.
- `textarea` und `button` mit reinem Textinhalt.
- `select` als Einfachauswahl und `option` mit `value`, `label`, `selected`, `disabled`.
- `datalist` über `input[list]` für editierbare Text-, E-Mail-, URL- und
  Zahlenfelder, einschließlich Filterung und Auswahl mit Maus oder Tastatur.
- `progress` und `meter` als passive Anzeigen; Werte per `page:SetValue`.
- `id`, `name`, `value`, `checked`, `disabled`, `readonly`, `placeholder`,
  `maxlength`, `minlength`, `required`, `size`, `rows`, `cols`, `tabindex`, `autofocus`, `form`,
  `novalidate` und `formnovalidate` im beschriebenen Teilumfang.
- Maus und Touch, Label-Klick, Fokus, Tab/Shift+Tab innerhalb der Seite,
  Radio-Auswahl mit Pfeiltasten, Button-Aktivierung mit Leertaste/Enter.
- Lokales Submit/Reset, Pflichtfeldprüfung auf leere Texte und nicht ausgewählte
  Checkbox-/Radiogruppen. `invalid`, Fokus und englische Validierungs-Sprechblase.
- CSS-Kindselektor `>` zusätzlich zu den bisherigen Nachfahren-Selektoren.

Text, Passwort und Textarea verwenden eine native Roblox `TextBox` für die
Texteingabe. Radios bestehen aus Außenkreis, weißem Innenring und blauem Punkt;
Checkboxen aus einer Box und zwei gedrehten Strichen. Fokussierte Textfelder
bekommen einen 2px-Rahmen, ohne ihre Layoutgröße zu ändern.

Einzeilige Text-/Passwortfelder und Select trennen die logische Zeilenhöhe von der lokalen
Schriftkorrektur: ungekürzte FontMetrics.TextSize + 1px. Standard-Arial ergibt 17px
Textbereich plus je 1px Padding = 19px innen (21px mit Rahmen). Die angezeigte
TextSize bleibt 14; ihre Grundlinie liegt 5px über der inneren unteren Rahmenkante.
Explizite CSS-Höhen bleiben maßgebend; zusätzlicher vertikaler Platz zentriert die
logische Textzeile. Passwortmaske und Editor erhalten dieselbe Position. Textarea,
Buttons und globale Fontprofile behalten ihre bisherigen Größen.

Buttons (`button` sowie `input` mit button/submit/reset) zentrieren ihre
Beschriftungszeile jetzt innerhalb der verfügbaren Inhaltsfläche. Eine feste
Höhe oder `min-height` verteilt den zusätzlichen Platz um die Zeile; die
Grundlinie hängt nicht von den sichtbaren Buchstaben des aktuellen Texts ab.
Die Standardausrichtung ist `align-content:center`, wie im
[HTML-Renderingprofil](https://html.spec.whatwg.org/multipage/rendering.html#form-controls).
Autoren können start/end oder bei Flexbuttons die entsprechende Flexausrichtung
setzen. Asymmetrisches Padding verschiebt die Inhaltsfläche entsprechend.
Bestehende Eingabefeld-Grundlinien und Fontkalibrierungen bleiben erhalten.

Absolut positionierte Steuerelemente und Bilder rechnen Prozenthöhen gegen
die bereits bestimmte Höhe ihrer Bezugsbox. Das gilt auch, wenn diese Höhe
über `aspect-ratio` entsteht. Rahmen, GUI-Identität und Hitbox bleiben bei
Größenänderungen erhalten. Die Positionierungsregression prüft volle und
halbe Höhen in einem quadratischen Container.

## Formulargruppen

`fieldset` zeichnet standardmäßig einen 2px-Groove-Rahmen, mit 2px Außenabstand
links/rechts und Padding `.35em .75em .625em`. Die erste sichtbare, nicht absolut
positionierte direkte `legend` sitzt auf der oberen Rahmenkante und erhält 2px
Padding links/rechts. Ihre Breite richtet sich nach dem Inhalt; längere Beschriftungen
brechen um. Der Rahmen wird in der Lücke tatsächlich ausgespart, ohne Hintergrundfarbe
über den Text zu legen. Weitere Legenden stehen im normalen Inhaltsfluss.

Auch bei `display:flex` bleibt die erste Legende außerhalb der Flexelemente.
`min-width:0` erlaubt einer Gruppe, unter ihre standardmäßige minimale Inhaltsbreite
zu schrumpfen. Unveränderte Teilbäume bleiben über DirtyLayout wiederverwendbar.

`fieldset disabled` deaktiviert die enthaltenen Formularfelder für Bedienung, Fokus,
Tab, Validierung und Formulardaten. Ausgenommen sind Nachfahren seiner ersten direkten
DOM-Legende, unabhängig von deren Sichtbarkeit. Jede verschachtelte deaktivierte Gruppe
wird separat geprüft; ein eigenes `disabled` am Feld bleibt wirksam.

Teilumfang: horizontales LTR-Layout; keine dynamischen Attributänderungen oder native
`fieldset.elements`-API. Spezielle Kombinationen mit Overflow, Schatten und vertikalen
Schreibrichtungen sind noch nicht vollständig browsergleich. Referenz:
[HTML-Standard](https://html.spec.whatwg.org/multipage/rendering.html#the-fieldset-and-legend-elements).

## Luau-API

Die Methoden werden beim Mounten einer Seite mit Formularfeldern eingerichtet:

```lua
page:On("form-preview", "submit", function(event)
    event:PreventDefault()
    page:SetValue("preview-result", "Button geklickt.")
    -- event.Data.Entries: {{Name = "...", Value = "..."}, ...}
    -- event.Data.Submitter: DOM-Knoten des auslösenden Buttons, falls vorhanden.
end)

local listener = page:On("input", function(event)
    -- event.Target: DOM-Knoten; event.Data.Value oder event.Data.Checked.
end)
listener:Disconnect()

page:SetValue("preview-name", "Tobias")
local name = page:GetValue("preview-name")
page:SetChecked("checkbox-id", true)
local checked = page:GetChecked("checkbox-id")
page:Focus("preview-name")
local entries = page:GetFormData("form-preview")
page:Reset("form-preview")
```

`On(id, eventName, callback)` kann auch einen DOM-Knoten als erstes Argument
erhalten. `On(eventName, callback)` hört auf Seitenebene. Ereignisse laufen
vom Ziel über seine Eltern bis zur Seite. `StopPropagation()` beendet diesen
Weg; `PreventDefault()` unterbindet die Standardaktion bei `click` und `reset`.
Submit besitzt noch keine externe Standardaktion. Weitere Ereignisse:
`change`, `focus`, `blur`, `pointerdown`, `pointerup`, `pointerenter`, `pointerleave`,
`invalid`. Das ist eine einfache Luau-Ereignis-API, kein vollständiges DOM-Eventmodell.

Formulardaten behalten DOM-Reihenfolge und doppelte Namen als einzelne Einträge.
Unbenannte/deaktivierte Felder, nicht gewählte Checkboxen/Radios und `output`
werden ausgelassen. Beim Submit zählt nur der auslösende Submit-Button mit;
`GetFormData` fügt keinen Button hinzu. Gleichnamige Radios teilen eine Gruppe
je Formular. Bei mehreren `checked`-Vorgaben gewinnt das letzte Feld auch nach Reset.
Programmgesteuerte Änderungen lösen keine `input`-/`change`-Ereignisse aus.

## Struktur und Aufwand

### Autofocus

`autofocus` setzt einmal nach dem ersten fertigen Seitenlayout den Fokus auf das
erste geeignete Formularfeld in DOM-Reihenfolge. Deaktivierte Felder (auch durch
fieldset), ausgeblendete Felder, Output und passive Anzeigen werden übersprungen.
`readonly` und `tabindex="-1"` verhindern programmgesteuerten Fokus nicht.
Das Attribut ist boolesch: seine Anwesenheit zählt, auch bei `autofocus="false"`.

Vorhandener Fokus, bereits erfolgte Benutzerinteraktion oder Fenster-Fokusverlust
während des Ladens verhindern eine spätere Übernahme. Auch eine fokussierte TextBox
außerhalb der Seite bleibt erhalten. Resize, Teil-Layout und Reset wiederholen den
Autofokus nicht. Der Status-Listener wird nach dem ersten Versuch getrennt und beim
Dispose aufgeräumt; ohne Attribut wird kein zusätzlicher Listener angelegt.

Teilumfang: vorhandene fokussierbare Formularcontrols; keine generischen
contenteditable-Elemente, Dialog-/Popover-Fokusbereiche oder zusätzliche Scrolllogik.
Gemeinsamer Test: E-Mail-Feld. Regressionen: Tests/Autofocus.
Referenz: [HTML autofocus](https://html.spec.whatwg.org/multipage/interaction.html#the-autofocus-attribute).

### Datalist-Vorschläge

Ein `input[list]` findet die `datalist` mit der passenden ID beim Aufbau der
Seite. Aktivierte `option`-Werte werden ohne Beeinflussung der freien Eingabe
angeboten. Fokus oder ein erneuter Klick öffnet die Liste. Eingabe filtert ohne
Neulayout ohne Beachtung der Groß-/Kleinschreibung über Wert und Beschriftung.
Pfeil hoch/runter verändert die Hervorhebung, Enter übernimmt den Wert und Escape
schließt die Liste. Maus und Touch verwenden denselben passiven Popup-Hit-Test wie
Select; Auswahl erzeugt `input`, während `change` wie bei einem Textfeld beim
Abschluss der Bearbeitung folgt.

Der aktuelle Teilumfang gilt für die bereits editierbaren Text-, E-Mail-, URL-
und Zahlenfelder. Browserabhängige Picker für Datum und Farbe, Tickmarken an
Range-Feldern, dynamische Änderungen am Listen-DOM sowie die vollständigen
Ereignis- und Accessibility-Details fehlen noch. Die Abdeckung liegt in
`tests/Forms.luau`; die frühere sichtbare Datalist-Seite wurde entfernt.

### E-Mail, URL und Mindestlänge

`input type="email"` und `input type="url"` verwenden dieselbe native TextBox,
Schriftkorrektur, Innenhöhe und Grundlinie wie Textfelder. Ihre Werte entfernen
Zeilenumbrüche und äußeren ASCII-Leerraum. E-Mail unterstützt auch `multiple`
als kommaseparierte Liste; leere Einträge innerhalb einer Liste sind ungültig.

Beim Absenden prüft der Controller die E-Mail-Syntax beziehungsweise eine absolute
URL (mit Schema, z.B. `https://example.com`). Geprüft werden auch Host, Portgrenze,
IPv4-/IPv6-Schreibweise; andere absolute Formen wie `mailto:` sind zulässig.
Die Prüfung betrifft Syntax, nicht Erreichbarkeit. URLValue ist ein lokaler Teilumfang
des URL-Standards: keine vollständige IDNA-/Punycode-Umwandlung, URL-Normalisierung
oder sämtliche Sonderregeln für file-URLs. E-Mail-Domains unterstützen ASCII und
bereits vorliegendes Punycode; Unicode-Domains werden nicht automatisch umgewandelt.

`minlength` gilt für Text, Passwort, E-Mail, URL und Textarea. Gezählt werden UTF-16-
Codeeinheiten; Textarea-Zeilenenden werden zuvor auf LF vereinheitlicht. Wie in HTML
greift die Mindestlänge nur bei nichtleerem, zuletzt vom Benutzer verändertem Text.
Initialwerte, Reset und `page:SetValue` lösen allein keinen too-short-Fehler aus.
Ein leeres Feld wird erst mit `required` ungültig. Ungültige/negative Mindestlängen
werden ignoriert; `minlength` an anderen unterstützten Kontrolltypen hat keine Wirkung.

Das erste ungültige Feld löst `invalid` aus und verhindert Submit. Ohne
`event:PreventDefault()` erhält es Fokus und eine englische Validierungs-Sprechblase.
`disabled`, `readonly`, `novalidate` und `formnovalidate` bleiben berücksichtigt.
Die Validierung benötigt kein neues Layout. Referenzen:
[HTML-Eingabetypen](https://html.spec.whatwg.org/multipage/input.html),
[Mindestlänge](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#attr-fe-minlength).
Tests: TextValidation; bestehende Formularbeispiele durch E-Mail, URL und
Textarea mit Mindestlänge ersetzt, keine zusätzlichen Felder.

### Englische Validierungsmeldungen

`Controls/ValidationMessage` erzeugt passende Texte für fehlende Werte, E-Mail,
URL, Mindestlänge und Zahlenbedingungen. `event.Data` enthält `Reason` und `Message`.
`invalid:PreventDefault()` unterdrückt Fokus und Standard-Sprechblase; Submit bleibt
blockiert. Eingabewerte werden nur bei E-Mail-Hinweisen zitiert, auf 60 UTF-16-Einheiten
begrenzt und ohne RichText dargestellt. Passwortwerte werden nicht ausgegeben.

`Input/ValidationPopup` zeichnet passive Frames/TextLabels: weißen Hintergrund,
grauen 1px-Rahmen, kleine Rundung, Dreieckspfeil, orangefarbenes Ausrufezeichen
und optionalen UIShadow. Arial 14, umbrochener Text; maximale Breite 300px.
Die Blase sitzt unter dem Feld beziehungsweise bei Platzmangel darüber und wird
horizontal ins Seitenfenster begrenzt. Keine interaktiven Buttons, keine Frame-Schleife
oder Layout-Anforderung. Textmaße über synchrones TextService:GetTextSize.

Bearbeitung, Fokuswechsel, Klick/Touch, Escape, Reset, Scrollen, Verschieben/Resize
des Ankers sowie Fenster-Fokusverlust entfernen die Blase. Dispose trennt ihre
Listener und entfernt den Teilbaum. Das vorhandene Formular reicht zum Vergleich:
ungültige E-Mail eingeben und Testen drücken. Browsermeldungen bleiben nativ und
folgen der Browsersprache; die Roblox-Meldungen sind Englisch.

Referenz für die fehlende-@-Meldung:
[Chromium-Validierungstests](https://chromium.googlesource.com/chromium/blink/+/HEAD/LayoutTests/fast/forms/validationMessage-expected.txt).
Optik ist angenähert und muss in Studio mit der Nutzerreferenz verglichen werden.

### Textarea-Ziehgriff

Das vorhandene Textarea-Beispiel besitzt einen 12×12px-Ziehgriff direkt innerhalb
der unteren/rechten Rahmenkante. EditableImage zeichnet die Nutzerreferenz mit
7 und 3 diagonalen Pixeln in RGB 102 auf transparentem Hintergrund. Eine Textur
pro Seite, beim ersten Feld angelegt und beim Dispose freigegeben. Bei fehlender
EditableImage-Freigabe ersetzen zehn passive Pixelframes dieselbe Darstellung.

Maus/Touch ziehen das Feld in beide Richtungen; der Mauszeiger wird nicht geändert.
`resize: none | both | horizontal | vertical` steuert den Griff (Textarea-Standard:
both; andere Elemente unterstützen das Ziehen noch nicht). Der Griff erhält
weder TextButton/ImageButton noch eigene GUI-Input-Listener. Ein reiner Klick
ohne Größenänderung fordert kein Layout an. Beim Greifen wird der Eingabefokus
aufgehoben: kein Schreiben und kein 2px-Fokusrahmen während der Geste. Nach dem
Loslassen bleibt das Feld unfokussiert, bis es wieder aktiviert wird. Textwert und
Schriftgröße bleiben erhalten. Die Größenänderung erzeugt keine input/change-
Ereignisse; das normale Blur kann zuvor bearbeiteten Text mit change abschließen.
Reset setzt den Text zurück und behält die gezogene Größe.

Änderungen schreiben Pixelmaße nach CSS-box-sizing in den ursprünglichen
Control-Stil, auch für Block-/Flex-Controls mit temporärem Layout-Stil. Vorhandene
min/max-Beschränkungen gelten weiter. Mindestinhalt beim Ziehen: 12px pro Achse.
Das Teil-Layout erhält das betroffene Item; der Scheduler bündelt lokale
Control-Änderungen weiterhin in 1/60s. Ein gleichzeitig laufender Fenster-Resize
wartet bei `HTMLViewportResizing=true` am Mount-Ziel bis zum echten Loslassen
und übernimmt dann sofort alle ausstehenden Änderungen. Größenwechsel ohne
aktive Geste starten sofort. Keine zusätzliche Frame-Schleife. Release außerhalb und
Fenster-Fokusverlust beenden die Geste, Dispose räumt auf.

Module: Rendering/ResizeGrip, Controls/TextareaView, Input/TextareaResize.
Tests: TextareaResize, PageLifecycle und vorhandenes gemeinsames Textarea-Beispiel.

### Fortschritt und Messwert

`progress` verwendet `value` und `max` (Standard 1, muss positiv sein). Werte
werden auf 0–max begrenzt. Ohne `value` ist der Fortschritt unbestimmt und ein
30%-Segment läuft vor/zurück. Ein vorhandenes, aber ungültiges `value` bedeutet 0.

`meter` verwendet `min` (Standard 0), `max` (Standard 1), `value` (Standard 0),
`low`, `high` und `optimum`. Werte und Grenzwerte werden in den gültigen Bereich
begrenzt. Ohne Angaben liegen low/high an den Grenzen, optimum in der Mitte.
Die Füllfarbe folgt dem Verhältnis zum Optimum: grün im optimalen Bereich, gelb
im benachbarten Bereich und rot im gegenüberliegenden Bereich. Liegt optimum
zwischen low/high, sind beide äußeren Bereiche gelb. Gleiche min/max ergeben
einen leeren Balken; max kleiner als min wird auf min angehoben.

```lua
page:SetValue("preview-progress", 75)
page:SetValue("preview-progress", nil) -- unbestimmter Fortschritt
page:SetValue("preview-meter", 90)
```

`GetValue` liefert wie bei anderen Controls einen Zahlenstring; unbestimmter
Fortschritt liefert "0". Änderungen ersetzen keine GUIs und fordern kein Layout
an. Beide Elemente sind keine Formularfelder: kein Submit-Wert, kein Reset,
keine Validierung, kein Fokus/Tab und keine Eingabeereignisse. Der HTML-Inhalt
bleibt im DOM als Fallbacktext erhalten, wird aber nicht zusätzlich gezeichnet.

Darstellung aus Frames/UICorner/UIStroke: 8px Spur mittig in einer 1em hohen Box;
natürliche Breite 10em bei progress, 5em bei meter. CSS-Größen, Padding, Rahmen
und vertical-align laufen durch das vorhandene Box-/Inline-Layout. Schriftprofile
bleiben unverändert. Farben sind zunächst angenähert, native Studio-Optik noch
abzugleichen; keine vertikale Darstellung oder bar-spezifischen CSS-Pseudoelemente.

`Controls/GaugeValue` normalisiert Werte/Bereiche. `GaugeView` zeichnet und verwaltet
die optionale TweenService-Animation. Ein laufender Tween bleibt bei Resize und
gecachten Paint-Snapshots erhalten; value setzen, visibility:hidden oder Dispose
beendet ihn. Keine zusätzliche Luau-Frame-Schleife. Grenzen werden beim Mounten
gelesen; zur Laufzeit ist zunächst nur value über die Seiten-API veränderbar.
Tests: `tests/Gauges.luau`, gemeinsame Demo: je ein Element in Beispiel 29.
Grundlage: [HTML progress und meter](https://html.spec.whatwg.org/multipage/form-elements.html#the-progress-element).

### Zahlenfeld

`input type="number"` verwendet eine TextBox und zwei selbst gezeichnete Pfeile
aus Frames. Pfeile erscheinen bei Hover/Fokus, bei `disabled`/`readonly` bleiben
sie verborgen. Klick/Touch oben erhöht, unten verringert; Pfeil hoch/runter auf
der Tastatur funktioniert auch bei aktivem Editor. Pro Pfeilklick ein Schritt;
noch keine Haltewiederholung oder Mausrad-Steuerung.

`min`/`max` sind optional, `step` ist standardmäßig 1. Schrittbasis: `min`, sonst
ursprüngliches `value`, sonst 0. Bei `step="any"` wird keine Schrittgenauigkeit
validiert; die UI-Pfeile verwenden vorerst Einerschritte. Zahlen ohne vorgegebenen
Wert bleiben leer. Gültige Eingaben außerhalb der Grenzen werden nicht automatisch
geändert, sondern bei Submit als ungültig erkannt. `required`, ungültige Eingabe,
Unter-/Überlauf und Schrittfehler führen zu `invalid` und Fokus. `novalidate` und
`formnovalidate` umgehen diese Prüfung wie bei den übrigen Feldern.

Während des Tippens bleibt Rohtext (`EditText`) erhalten, etwa `-` oder `1e`.
`GetValue` und Formulardaten liefern für ungültige Eingaben eine leere Zeichenkette;
`BadInput` unterscheidet diese vom leeren gültigen Feld. Dezimalpunkt und Exponenten
werden unterstützt; lokalisierte Komma-Eingabe und native Zeichenfilter noch nicht.
`SetValue` übernimmt gültige Zahlenstrings, ungültige werden geleert. `maxlength`
und `size` beeinflussen Zahlenfelder nicht. Reset stellt den Startwert wieder her.

Tippen erzeugt `input`, Verlassen nach Wertänderung `change`. Pfeilschritte erzeugen
je ein `input` und `change`; beim späteren Fokuswechsel gibt es kein zweites Change.
Keine Layoutanforderung bei Wertänderungen. Höhe/Schriftkorrektur entsprechen den
Textfeldern (standardmäßig 21px außen, TextSize 14). Der Editor lässt 18px für die
Pfeile frei. Nach Nutzerreferenz: 7×4px-Dreiecke in RGB 139, 4px Abstand dazwischen;
15×14px Hintergrund RGB 252 mit 3px Abstand zum inneren rechten Rand.
Gemeinsamer Test: ein Zahlenfeld 1–10 in Beispiel 29.

Module: `NumericValue` (gemeinsamer Parser mit Range), `NumberValue` (Werte/Schritte/
Prüfung), `NumberView` (Pfeile und Trefferflächen). Tests: `tests/Number.luau`.
Semantische Grundlage: [HTML Number State](https://html.spec.whatwg.org/multipage/input.html#number-state-(type=number)).

### Schieberegler

`input type="range"` verwendet `min`, `max`, `step` (auch `any`) und `value`.
Ohne Grenzen gilt 0–100, ohne Schrittweite 1, ohne gültigen Wert die Mitte.
Werte werden begrenzt und auf erlaubte Schritte gerundet; bei gleichem Abstand
gewinnt der größere Wert. Schrittbasis ist `min`, sonst das ursprüngliche
`value`-Attribut, sonst 0. Bei `max < min` bleibt der Wert auf `min`.
Grundlage: [HTML-Standard](https://html.spec.whatwg.org/multipage/input.html#range-state-(type=range)).

`Controls/RangeValue` normalisiert Startwerte und `page:SetValue`.
`Controls/RangeView` zeichnet graue Spur, blauen Füllstand und runden Griff aus
passiven Frames. Standardgröße: 129×16px plus 2px Margin, Griff 16px, Spur 8px
einschließlich 1px Innenrahmen (RGB 178); innen RGB 239 wie im Browser-Referenzbild.
Hover über dem Regler färbt den blauen Füllstand; der Griff ändert seine Farbe
erst beim direkten Überfahren seiner Kreisfläche. Über dem Griff reagieren beide.
Der graue Schienenhintergrund verwendet RGB 239 normal, 229 bei Hover und 245
beim Drücken oder bei deaktiviertem Regler; Disabled hat Vorrang vor Hover.
CSS-Breite/Höhe verändern die Geometrie; Wertänderungen benötigen keine Textmessung
und kein neues Layout. `Input/RangeDrag` erfasst die Geste bis zum Loslassen,
auch außerhalb des Reglers. Ein Griff-Klick erhält den Abstand zum Mittelpunkt.
Maus und Touch lösen `input` bei Wertänderungen aus, beim Loslassen einmal `change`
bei verändertem Endwert. Fenster-Fokusverlust beendet die Geste ebenfalls.
Pfeiltasten ändern um einen Schritt, Home/End springen an die Grenzen.
Bei `step="any"` verwenden Pfeile 1% des Bereichs.

`disabled`, Fokus/Tab, Formulardaten und Reset sind angebunden; `readonly`,
`required` und `maxlength` gelten für Range nicht. Programmatische Wertänderungen
und Reset erzeugen keine `input`-/`change`-Ereignisse. Beispiel 29 enthält einen
Regler 0–100. Tests: `tests/Range.luau` mit Eingabe-/GUI-Mocks.
Vorerst horizontal von links nach rechts; keine Tickmarks/`datalist`, vertikale
Ausrichtung oder CSS-Pseudoelemente für Spur/Griff. Native Touch-Scrollkonflikte
und die genaue Browser-/Studio-Optik müssen noch visuell geprüft werden.

### Dropdown

`Controls/SelectOptions` liest Optionstexte/-werte und die Startauswahl. Die letzte
`selected`-Vorgabe gewinnt; ohne Vorgabe wird die erste aktivierte Option gewählt.
`page:SetValue` wählt den ersten passenden Wert, auch bei doppelten Werten. Ein
unbekannter Wert hebt die Auswahl auf. `GetValue` liefert dann eine leere Zeichenkette;
das Feld wird wie eine ausgewählte deaktivierte Option beim Submit ausgelassen.
Reset stellt die ursprüngliche Auswahl wieder her. `required` berücksichtigt eine
fehlende Auswahl und eine leere erste Platzhalteroption. `disabled` am Select und
an Optionen wird beim Auswählen beachtet; ein `optgroup disabled` deaktiviert seine
Optionen ebenfalls. Gruppenüberschriften werden separat und nicht auswählbar gezeichnet.

`Input/SelectPopup` zeichnet die Liste aus Frames/TextLabels und einem nativen
ScrollingFrame. Sie liegt außerhalb des Seiten-Scrollinhalts und öffnet je nach
Platz darunter oder darüber. Maus/Touch laufen durch den zentralen Controller;
Ziehen wählt keine Option aus. Pfeile ändern die Auswahl oder die vorläufige
Markierung einer offenen Liste; Enter/Leertaste bestätigt, Escape verwirft sie.
Klick außerhalb, Fokuswechsel, Reset, Resize und Bewegung des Ankers schließen sie.
Der Popup-Teilbaum und seine Listener werden anschließend entfernt.

`Input/SelectTypeAhead` sucht bei fokussiertem Select anhand des angezeigten
Optionstexts (einschließlich `label`). Schnell getippte Zeichen bilden ein Präfix;
nach einer Sekunde Pause beginnt eine neue Suche. Wiederholte gleiche Buchstaben
wechseln zyklisch zwischen passenden Optionen, deaktivierte Optionen werden
übersprungen. Groß-/Kleinschreibung folgt dem vorhandenen Latin-Mapping inklusive
Umlauten. Leerzeichen können ein aktives Suchpräfix erweitern.

Bei geschlossener Liste wird direkt ausgewählt; bei geöffneter Liste nur markiert
und gegebenenfalls zur Zeile gescrollt. Enter bestätigt, Escape verwirft die Markierung.
Kein Treffer ändert den Wert nicht. Auswahl desselben Eintrags erzeugt keine doppelten
Events. Fokuswechsel, Öffnen/Schließen, Pfeilnavigation, programmatisches SetValue und
Reset leeren die Suche. Keine Timer oder neuen GUI-Objekte für die Suche.

Der Controller verwendet GetStringForKeyCode für druckbare Haupttastatur-Tasten.
Ctrl/Alt/Meta-Kombinationen und bereits verarbeitete Eingaben werden ignoriert.
Teilumfang: keine IME-Komposition, Bildschirmtastatur, vollständige Unicode-Faltung
oder modifierabhängige Sonderzeichen-/Ziffernblock-Übersetzung. Tests:
SelectTypeAhead sowie die Controller-/Popup-Regressionen in Select.

`optgroup label="…"` erzeugt eine nicht auswählbare fette Überschrift im Dropdown.
Zugehörige Optionen sind um 12px eingerückt; ihre Auswahlfläche umfasst weiterhin
die gesamte Zeile. `disabled` an einer Gruppe deaktiviert alle ihre Optionen.
Überschriften sind weder Formularwerte noch Such- oder Pfeiltastenziele. Die
ausgewählte Option behält im geschlossenen Feld ihre normale Darstellung.
Leere Gruppen bleiben als Überschrift sichtbar. Individuelles Gruppen-CSS,
`legend`-Inhalte und verschachtelte Gruppen sind nicht unterstützt.

`Controls/SelectOptions` liefert neben der reinen Optionsliste die sichtbaren
`SelectRows` mit Gruppenzeilen. Optionsindizes bleiben stabil; das Popup speichert
deren tatsächliche Zeilenpositionen für `Reveal`. Die Feldbreite berücksichtigt
auch fette Gruppenüberschriften und die Einrückung. Tests: `tests/Optgroups.luau`.
Semantik: [HTML optgroup](https://html.spec.whatwg.org/multipage/form-elements.html#the-optgroup-element).

Die Feldbreite berücksichtigt die längste Option plus Pfeilbereich. Messwerte
werden je Schriftgröße/-familie gespeichert. Eine Auswahl ändert nur die Anzeige
und löst bei Benutzereingabe einmal `input` und `change` aus; kein Seitenlayout.
Das historische Beispiel 29 enthält ein Dropdown mit drei Optionen in den
Gruppen „Verfügbar“ und „Geplant“ (deaktiviert). `multiple` und `size > 1`
verwenden die bestehende Listenansicht mit Mehrfachauswahl, Tastatur,
Formularwerten und Reset. Individuelles Options-CSS und native Browser-
Popup-Optik sind nicht vollständig nachgebildet. Tests: `tests/Select.luau`.

### Rich Select und selectedcontent — 8. Oktober 2026

`HTML/SelectTree` führt die gemeinsame iterative Options-/Spiegeltraversierung.
Parser und Controls beachten HTML-Namensräume, normale Wrapper und die Grenzen
von verschachtelten Selects, Optionsgruppen, Optionsinhalten, `hr` und Datalist.
Der erste direkte Select-Button ist unter `appearance:base-select` inert und
verwendet `display:contents`; das Select übernimmt Schrift und Farbe der Seite.
`selectedcontent` zeichnet formatierte Texte und Bilder über die üblichen
retained Box-/Wort-/Bildpfade. Das Select und unabhängige Nachbarn behalten
ihre GUI-Identität bei Auswahlwechseln.

Die Kopie ist eine tiefe Momentaufnahme. Wert-/Indexsetter, Optionen-
Selectedness, Reset, neue Spiegel und Rückkehr von `multiple` zur Einfachauswahl
aktualisieren sie. Eine reine Änderung am Quelltext der Option aktualisiert
die Momentaufnahme nicht; erneut denselben Wert zu setzen dagegen schon.
Normale Clone-/MutationObserver-Pfade bleiben wirksam. Nicht ausgewählte,
entfernte Optionen werden durch das Snapshot-Merkmal nicht festgehalten.
Während `multiple` gesetzt ist bleiben vorhandene Kopien erhalten.

Der native Controller kopiert auch ohne JavaScript. Läuft gerade Layout,
wartet die GUI-Aktualisierung auf dessen Abschluss; aktuelle Flächen bleiben
sichtbar. Option-Metadaten ohne geänderten Rich-Inhalt verlangen kein neues
Rich-Layout. Gemeinsame Arbeitspausen bleiben im Kopier-/Traversierungspfad aktiv.

Nachweise: `JavaScriptSelectedContent` mit gespeicherter Chromium-Sequenz,
normalen MutationRecords, tiefen Identitäten und Reset-/Modusfällen;
`RichSelectRendering` mit tatsächlichem JavaScript-/DOM-/Renderer- und nativem
Controllerpfad, formatierter Farbe, Bildgeometrie, erhaltenen Nachbarn und
aufgeschobenen Aktualisierungen. `Select` und `Optgroups` prüfen die bisherige
Auswahl-/Popup-/Listensteuerung weiter.

Seit dem 9. Oktober zeichnet auch der eigene Picker formatierte Optionstexte,
Bilder und lokale SVGs durch separate RenderTree-/BlockLayout-Fragmente.
Autorenregeln werden gegen die ursprüngliche DOM-Anordnung ausgewertet;
Optionen werden weder geklont noch umgehängt. Zeilen übernehmen ihre echte
Inhaltshöhe. Ein geöffnetes Fenster aktualisiert veränderte Inhalte auf
behaltenen Flächen. Arbeit läuft mit Ladepausen; Close, Abbruch, ein während
des Aufbaus neu geöffnetes Fenster derselben Auswahl und reentrante Refresh-
Aufrufe geben nur die jeweils eigenen Ressourcen frei. `RichSelectRendering`
prüft diese tatsächlichen Pfade mit GUI-Ersatzobjekten.

Gruppen verwenden jetzt ihre erste Element-Legend als Beschriftung, auch wenn
deren Inhalt leer ist. Nur eine HTML-Legend zählt; andernfalls gilt `label`.
Formatierte Legends bekommen eigene behaltene Zeilen. Entfernen/Ersetzen der
Legend gibt deren altes Fragment frei und stellt gegebenenfalls das Attribut
wieder dar. Option-/Legend-Inhalte erben Farbe und Schrift über ihre ursprüngliche
Optgroup-Anordnung. Die Popuphöhe folgt der gemessenen Zeilenhöhe auch nach
Refresh; Position oberhalb/unterhalb und Scroll-Reveal berücksichtigen die
neuen Grenzen. Gruppen bleiben nicht auswählbar.

Auf gemounteten Seiten nutzen Pickerfragmente denselben erlaubten Raster-
Metadatenhost wie die Seite. Native Bild-/Font-Preloads laufen verzögert;
Bildankunft und Quellwechsel aktualisieren behaltene Inhalte und Popupgrenzen.
Schließen entfernt Listener/Metadatenabonnements; späte Ergebnisse öffnen kein
Fenster erneut und starten kein Preload für zerstörte Flächen. `ImageDimensions`
prüft zusätzlich das Entfernen einer Registrierung nach Quelländerung.
Nachweise: `Select`, `Optgroups`, `RichSelectRendering`, `ImageDimensions` und
`LoadOptimizations`. Kein neuer nativer Studio-Sichtvergleich wurde behauptet.
Quelle: [HTML-Optgroup-Beschriftung](https://html.spec.whatwg.org/multipage/form-elements.html#the-optgroup-element).

Normale Dropdowns messen die breiteste Option beziehungsweise Gruppenbeschriftung.
`field-sizing:content` misst beim Dropdown die aktuelle Beschriftung und bei
Listen die tatsächlichen Zeilen; `fixed` verwendet die angeforderte Zeilenzahl.
`base-select` erzwingt die UA-Inhaltsgröße. Gewöhnliche Dropdown-/Listenwechsel
erhalten Control, äußere Flächen, Fokus und Auswahl. Inline-Controls liefern ihre
tatsächlichen platzierten Boxen an DOM-Geometrieabfragen. Zwei native Chromium-
Größensequenzen werden in `JavaScriptCSSOMRendering` abgeglichen; die beobachtete
Chromium-Abweichung der wichtigen Base-Select-Vorgabe bleibt separat erhalten.
Dies implementiert `field-sizing` für Selects, nicht pauschal für jeden Eingabetyp.

`::picker-icon` auf dem Rich-Dropdown und `option::checkmark` im eigenen Picker
benutzen jetzt die gewöhnliche Kaskade, generierte Inhalte und das Box-/Textlayout.
UA-Vorgaben, `content:none`, Farben/Vererbung, feste Maße, Variablen, Layer-Rollback
und lebende Auswahlzustände sind ergänzt. Die Auswahlmarkierung bleibt vor
`::before`, das Pickersymbol nach `::after`; der UA-Abstand benutzt die automatische
Inline-Margin. Geänderte Symbole erhalten Selectrecord und äußere GUI. Verdeckte
Datenoptionen erzeugen keine zusätzlichen Pseudoboxen im Hauptdokument.

Ein nichtleeres Optionslabel unterdrückt die Kinder innerhalb derselben behaltenen
Pickeransicht. Unterdrückte Bilder/SVG-/Medienobjekte werden nach Renderzugehörigkeit
abgemeldet, auch wenn ihre DOM-Knoten weiter verbunden sind. Rücknahme baut nur die
wieder sichtbaren Ressourcen auf; späte Metadatenantworten reaktivieren sie nicht.
`RichSelectRendering` prüft wirkliche Paintwerte, Inhalts-/Auswahlwechsel, Label-
Rücknahme, Abbruch, Wiederanmeldung und Ressourcenfreigabe. Drei aufgezeichnete
Chromium-Sequenzen in `select-pseudos-browser.json` werden zusätzlich über den
montierten CSSOM-/Rendererpfad abgeglichen. Standardglyphen verwenden vorhandene
native Fonts; dies ist keine Garantie aller Fontquellen oder Studio-Pixelgleichheit.

Seit dem 9. Oktober verwenden Base-Dropdowns auch ohne ersten Button den normalen
Wort-/Pseudoboxpfad: Die ausgewählte Optionsbeschriftung ist ein anonymer Klartext,
gefolgt vom kaskadierten `::picker-icon`. Formatierte Optionskinder bleiben Daten
für den Picker; es werden keine Ersatzknoten in den Benutzer-DOM geschrieben.
Ein später eingefügter beziehungsweise entfernter erster Button übernimmt
beziehungsweise beendet seine sichtbare Teilnahme auf derselben Selectfläche.

Montierte Wechsel zwischen Base-Dropdown und gewöhnlichem Dropdown/Listbox
erhalten Formularrecord, Item, Haupt-GUI, aufgelösten Stil und Fokus. Die anonymen
Inhaltsflächen wechseln mit der Darstellung. Alte native Beschriftungen/Pfeile,
Rich-Wörter/Pseudoboxen, Layoutwrapper einschließlich Opazitätsflächen sowie
Rahmen-/Outline-Ressourcen werden freigegeben. Schriftfamilie und Gruppenfont
folgen dem aktuellen Modus; unveränderte Paints lösen den Fontresolver nicht erneut
aus. Ein offener Picker behält seinen Host und bindet seine Positions-/Größenlistener
an die aktuelle Ankerfläche um. Signale einer ausgemusterten Fläche schließen ihn
nicht nachträglich.

Eine veränderte UA-Beschriftung aktualisiert nur ihre behaltene Selectbox und
fordert das notwendige Layout an. Auswahlwechsel zwischen identischen Beschriftungen
lassen Wörter und Maße unangetastet. Während eines laufenden Layouts bleibt die
bisherige Beschriftung sichtbar; die neue wird an der bestehenden Flush-Grenze
publiziert. Optionslabel, Auswahl, Reset und eine ausdrücklich leere Auswahl
werden im tatsächlichen Controller-/Rendererpfad geprüft. Reine Stiländerungen
dürfen eine leere Auswahl nicht auf die erste Option zurücksetzen.

Nachweise: erweiterte `RichSelectRendering`- und `JavaScriptCSSOMRendering`-Tests
mit behaltenen Identitäten, tatsächlichen Wort-/Pseudofarben, Größenvergleichen,
Offen-/Fokuszuständen, kooperativen Aktualisierungen und Ressourcenabbau. Die
Chromium-Größenreferenz enthält acht Sequenzen, darunter UA-Fallback, First-Button-
Moduswechsel, Rich-Listboxen, fontrelative UA-Maße und berechnete Prozent-/Math-
Constraints. Eine ausdrücklich leere Auswahl bleibt bei Label-/Wert-/Text-,
Disabled- und Nichtoptionsänderungen bestehen; wirkliche Optionslistenänderungen
verwenden weiterhin die nativen Auswahl-/Resetregeln. Die beobachtete Chromium-154-Ausgabe `field-sizing:fixed` trotz
inhaltlicher Größenanpassung bleibt gespeichert; die HTML-Vorgabe
`field-sizing:content !important` wird ausdrücklich separat abgeglichen.

Base-Listboxen verwenden seit dem 9. Oktober ebenfalls den normalen behaltenen
Renderer für formatierte Options-/Gruppeninhalte, Bilder, erste Legends,
anonyme Gruppenlabels und `::checkmark`. Auswahl per Maus und Tastatur, Reveal,
Disabled-Gruppen und Reset erhalten Optionsboxen und Scrollflächen; Auswahlpaint
fordert kein Seitenlayout an. Label unterdrückt die Optionskinder samt Ressourcen,
seine Rücknahme stellt sie wieder her. Native List-/Dropdown-/Base-Wechsel
erhalten Formularrecord, Haupt-GUI, Fokus und DOM-Knoten. Die aktuelle HTML-UA-
Vorgabe `border-box` bleibt gegenüber Chromiums beobachtetem `content-box` bei
Base-Listboxen ausdrücklich getrennt, statt die Standardvorgabe still zu ersetzen.

`RichSelectStates` gleicht 31 aufgezeichnete Chromium-Zustände für echte Hover-
Eingabe, Active, Disabled-Vererbung, erste Fieldset-Legend-Ausnahme, fontrelative
Dropdownmaße und Autoren-/UA-Kaskade ab. Revert behält die Abhängigkeit vom
finalen `currentColor` und von der gewählten Base-Darstellung. RGB/Alpha werden
als Paintwerte verglichen; Chromiums `oklab(...)`-Serialisierung der UA-Farbmischung
ist weiterhin keine identische CSSOM-Serialisierung unserer Engine.

Der reguläre Custom-Dropdown montiert eine gemeinsame anonyme
`::picker(select)`-Renderbox. Die ursprünglichen Optionen/Gruppen bleiben im
Benutzer-DOM mit denselben Eltern und Selektorpfaden; es entstehen keine author-
sichtbaren Ersatzknoten. Rahmen, Padding, Intrinsic-/Min-/Max-Maße, Scrollport,
Optionsdisplay und gemeinsame Grid-Tracks durchlaufen den normalen CSS-/Layout-
Pfad. Die Standardankerkante bildet auch die Bezugsbreite für Prozentwerte.
`RichSelectPicker` vergleicht 20 native Größen-/Anordnungszustände in sechs
Sequenzen sowie dynamische Optionen, Label-/Legend-Wechsel, Checkmarks,
Moduswechsel, behaltene Flächen und den vollständigen Abbau. Hoverfarbe wird
ohne erneutes Pickerlayout gemalt. Der CSSOM-Mounttest prüft die tatsächlich
sichtbare Pickerbox bei Offen-/Farb-/Darstellungswechseln. Die ältere interne
Optionsfragment-Schnittstelle wurde entfernt; ihre Abbruch-/Bild-/Font-/
Ressourcenregressionen prüfen jetzt denselben gemeinsamen Pickerbaum wie die
Produktion. Es bleibt keine zweite eigene Optionslayout-Implementierung.

H02 bleibt offen: vollständige Autoren-`position-area`-/Inset-/Try-Fallback-
Kombinationen über den unten geprüften gemeinsamen Bereichs-/UA-Pfad hinaus,
transformierte/fragmentierte Anker sowie vollständige Offen-/Geschlossen-
Serialisierung des Pickerpseudos sowie weitere Effekt-/Ressourcen-/Zustands-
Kombinationen sind noch nicht vollständig nativ abgeglichen. Die genannten
Nachweise gelten für Ersatzobjekttests und isoliertes Chromium; native Studiooptik
und Interaktion bleiben zur visuellen Abnahme beim Nutzer.
Grundlage: [Select-Algorithmen](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element)
und [selectedcontent](https://html.spec.whatwg.org/multipage/form-elements.html#the-selectedcontent-element).

### Autorenpositionierung des Select-Pickers – 10. Oktober 2026

`::picker(select)` besitzt nun seine feste UA-Position vor der Autorenkaskade.
Explizite physische Insets, `anchor()`-/`anchor-size()`-Ausdrücke, `position-anchor`
mit `normal`, `none`, `auto` oder einem Ankernamen und benannte `@position-try`-
Regeln verwenden denselben Solver wie andere positionierte Boxen. Die behaltene
Seiten-Ankerregistry liefert Namensauswahl und `anchor-scope`; der Select stellt
den impliziten Ursprung bereit. Autorenpositionierung hängt auch bei einem
großen oder außerhalb liegenden Select nicht vom Platz direkt darunter ab.
Die normale Top-Layer-Verwaltung verhindert zusätzliche Viewport-Wrapper beim
Restyle. Optionen behalten ihre ursprünglichen DOM-Eltern und GUI-Flächen.

Ein offener Picker folgt Ankerbewegung und Viewportänderungen. Nur tatsächlich
referenzierte fremde Ankerflächen erhalten Größen-/Positionslistener; Schließen,
Referenzwechsel und Seitenabbau entfernen diese wieder. Nach dem Seitenlayout
wird der Picker mit den aktuellen benannten Ankermaßen publiziert, auch wenn
das Select selbst seine Lage behält. Keine dauernde Abfrage ruhender Seiten.

`RichSelectAnchors` vergleicht 26 aufgezeichnete Chromium-154-Zustände in zehn
Sequenzen: implizite/benannte/fehlende Anker, getrennte Koordinaten- und
Größenausdrücke, dynamische Scopes, explizite Fallbackregeln, Prozent-Insetwerte,
Auto-Margins, Größenwechsel und die genannten Öffnungsgrenzen. 25 Ergebnisse
stimmen direkt mit Chromium überein. Eine Namensauswahl bleibt ausdrücklich
getrennt: Die aktuelle CSS-Vorgabe bevorzugt den nächsten zulässigen Vorfahren;
Chromium wählt nach Entfernen des Select-Scopes den späteren äußeren Anker.
Das rohe Browserergebnis und die begründete Standarderwartung sind gemeinsam
gespeichert. Zusätzlich prüft der echte HTMLPage-Worker die Veröffentlichung
nach einem fremden Ankerlayout und den vollständigen Abbau; die Ersatz-GUI-
Vergleiche enthalten auch verschobene Viewport-/Elternursprünge.

Dieser Nachweis deckt physische Insets mit `position-area:none` ab. Logische
Bereiche und UA-Fallbacks wurden inzwischen im folgenden Teilumfang ergänzt;
transformierte und fragmentierte Anker bleiben offene Anforderungen. Grundlage:
[CSS-Ankerpositionierung](https://drafts.csswg.org/css-anchor-position/)
und [UA-Regeln für Select](https://html.spec.whatwg.org/multipage/rendering.html#the-select-element-2).

`position-anchor:match-parent` übernimmt das tatsächlich ausgewählte Element
des unmittelbar übergeordneten Elements, beim Picker seines ursprünglichen
Selects. Die Auswahl wird nicht unter einem gleichnamigen Anker im Scope des
Kindes erneut aufgelöst. Nicht positionierte Eltern, fehlende Defaults und für
das Kind unzulässige Anker liefern keinen Default. Namenwechsel erreichen den
offenen, behaltenen Picker. `position` setzt nun den Reset-Unterwert
`position-anchor` gemäß aktuellem Entwurf zurück; Wichtigkeit, CSS-weite Werte,
Variablen und spätere explizite Ankerdeklarationen bleiben Teil der Kaskade.
Die CSSOM benutzt dieselbe Reihenfolge und verliert spätere Settersignale nicht
beim erneuten Parsen des tatsächlichen Style-Attributs.

`AnchorParent` prüft zwölf Parent-/Ketten-/Scope-/Zulässigkeitszustände,
vier echte Pickerzustände, acht Resetfälle sowie Syntax, Inline-/Regel-CSSOM,
berechnete Werte im RenderTree und behaltene Flächen. Dieser Nachweis ist
ausdrücklich normativ: Chromium 154 unterstützt `match-parent` und den
Reset-Unterwert von `position` noch nicht. Die rohen Ablehnungen und alten
Resetwerte bleiben in der Referenz gespeichert. Für die Geometrie wird die
normativ ausgewählte Fläche im isolierten Browser explizit benannt; das ist
eine native Ersatzgeometrie, kein erfolgreicher nativer `match-parent`-Test.
Die Standardgrundlage steht in
[Default Anchors](https://drafts.csswg.org/css-anchor-position/#position-anchor)
und den [WPT-Parentfällen](https://github.com/web-platform-tests/wpt/blob/master/css/css-anchor-position/position-anchor-match-parent-rendering.html).

### Gemeinsame Position-Area-Geometrie und UA-Fallbacks – 10. Oktober 2026

Der anonyme Select-Picker und normale absolut/fest positionierte Boxen benutzen
denselben `PositionedLayout.place`-Pfad. `CSS/PositionArea` liefert die gemeinsame
Grammatik, Autoren-/Computed-Serialisierung und physische Bereichszuordnung.
Physische, `x/y`-, `block/inline`- und `self`-Schlüsselwörter sowie zulässige
`span-*`-/Zweierkombinationen berücksichtigen `horizontal-tb`, `vertical-rl`,
`vertical-lr`, `sideways-rl`, `sideways-lr` und LTR/RTL. Ungültige Mischungen
werden verworfen. Prozentgrößen, Padding, Margin und Insets beziehen sich auf
den gewählten Bereich; bestehende Alignmentwerte und Überlaufkorrekturen laufen
durch denselben Pfad. Area-Rezepte und Flip-Taktiken in `position-try` arbeiten
zusammen mit benannten Regeln und stabiler Auswahl bei Bewegung und Resize.

`PositionAreas` vergleicht 523 native Geometriezustände, 39 Area-Syntax- und
9 Fallback-Syntax-/Serialisierungsfälle mit
[position-area-browser.json](../tests/fixtures/position-area-browser.json).
Der Nachweis schließt veränderte Anker, Rückkehr zum Ausgangszustand, Größen-
und Prozentfälle, zu große/außerhalb liegende Boxen sowie erhaltene GUI-/Stil-
Identitäten ein. Er ersetzt keinen vollständigen vertikalen Block-/Flex-/Grid-
Fluss; ein eigener, vertikaler Schreibmodus am positionierten Element wird
hier für seine Bereiche und feste Außenmaße geprüft.

Der Picker verwendet die UA-Bereiche `self-block-end span-self-inline-end`,
die drei im HTML-Standard genannten Alternativen und `most-block-size`.
Seine UA-Minimalgröße folgt der Select-Inlinegröße; die maximale Blockgröße
folgt dem gewählten Bereich. Normale Autorendeklarationen überschreiben diese
UA-Regeln, ohne eine private Zeilen-/Positionsroutine zu erzwingen. Das zuvor
pauschal bevorzugte Platzieren unter dem Select entfällt: Bei einer größeren
verfügbaren Block-Start-Fläche kann der Picker darüber erscheinen. Legenden-
Wachstum/-Schrumpfung bewegt denselben Host am beibehaltenen Selectrand.

`RichSelectUA` prüft 150 echte native anonyme Picker-Außenboxzustände in allen
fünf Schreibmodi, zwei Richtungen, mit Select-Bewegung, Viewportänderung,
Autorengrößen und entfernten Größen-/Fallbackbeschränkungen. Der Capture liest
die tatsächliche UA-Pseudo-Box per CDP und rekonstruiert sie nicht aus einer
Option. Die 150 unveränderten Chromium-154-Aufnahmen bleiben getrennt von
150 nativen Kontrollaufnahmen erhalten: Chromium ergänzt `min-block-size:1lh`,
das in der hier eingefrorenen HTML-UA-Regel fehlt. Der Kontrolllauf entfernt
ausschließlich diese zusätzliche Mindestgröße vor dem Öffnen; die Engine
folgt der normativen UA-Regel. Bei sehr kleinen Bereichen betrifft diese
Differenz auch die ausgewählte Alternative. Drei weitere native Aufnahmen
belegen Legend-Wachstum/-Schrumpfung; `RichSelectRendering` prüft dazu den
behaltenen tatsächlichen DOM-/Bild-/Pickerpfad und Ressourcenabbau.
Nachweis: [select-ua-browser.json](../tests/fixtures/select-ua-browser.json).

`RichSelectCSSOM` ergänzt 80 native Zustände für geschlossene, geöffnete,
veränderte und erneut geschlossene Picker. Der Nachweis umfasst alle fünf
Schreibmodi, LTR/RTL, feste und prozentuale Größen und behaltene Live-
Deklarationen. `getComputedStyle(select, '::picker(select)')` verwendet während
des Öffnens die tatsächlich angeordnete Pseudobox; geschlossen bleibt die
UA-Regel `display:none` über die normale Autorenkaskade auflösbar. Prozentwerte
ohne Layoutbox bleiben berechnete Prozentwerte; die UA-Grenze `stretch` wird
nicht durch einen temporären Layout-Pixelwert ersetzt.
Nachweis: [select-cssom-browser.json](../tests/fixtures/select-cssom-browser.json).

Offen bleiben insbesondere vollständiger vertikaler Options-/Gruppenfluss,
transformierte/fragmentierte Anker, sichere/unsichere Alignment-Kombinationen
und alle Scroll-/Scope-Provenienzfälle. Diese implementierbaren Anforderungen sind
keine technische Unmöglichkeit und werden durch die bestandenen Teilnachweise
nicht als erfüllt ausgegeben. Grundlage:
[CSS Position Areas](https://drafts.csswg.org/css-anchor-position/#position-area)
und [HTML Select Rendering](https://html.spec.whatwg.org/multipage/rendering.html#the-select-element).

### Select.showPicker und versteckte Elemente – 10. Oktober 2026

`HTMLSelectElement.prototype.showPicker()` benutzt den tatsächlichen
Controller-/Pickerpfad. Mutabilität, unveränderliche Dokumentursprünge,
transiente Benutzeraktivierung und vorhandene Layoutboxen entscheiden über
die standardisierten DOMExceptions. Srcdoc und initiale About-Blank-Dokumente
erben den Ursprung des Elternkontexts; sandboxed Dokumente ohne
`allow-same-origin` erhalten einen eigenen opaken Ursprung. Fehlgeschlagene
Vorbedingungen verbrauchen keine Aktivierung. Ein erfolgreiches Öffnen eines
Mehrfach-/Listen-Selects verbraucht sie, erzeugt jedoch keinen Dropdownpicker.
Wiederholtes Öffnen erhält denselben Host und Fokus. Tastaturauswahl, Abbruch
und `input`/`change` vor der Fokus-Rückkehr werden am echten GUI-/DOM-Pfad
geprüft. Methode, Prototypidentität und Receiverprüfung sind Teil desselben
Nachweises.

`SelectShowPicker` vergleicht 62 echte native Zustände: 36 Vorbedingungen,
12 Frame-/Ursprungsfälle und 14 durch native Mausklicks/Tastatureingaben
ausgelöste Öffnungs-/Auswahl-/Wiederholungszustände. Vier Chromium-154-Fälle
weichen in der Reihenfolge ab: Chromium prüft fremde Ursprünge vor der
Mutabilität. Die Engine folgt der Standardreihenfolge und meldet bei einem
deaktivierten fremden Select `InvalidStateError`. Rohes natives Ergebnis und
normative Erwartung bleiben getrennt in
[select-showpicker-browser.json](../tests/fixtures/select-showpicker-browser.json).
Grundlage: [HTML showPicker-Schritte](https://html.spec.whatwg.org/multipage/form-elements.html#dom-select-showpicker).

Der generische `hidden`-Pfad liefert UA-Stile vor normalen Autorendeklarationen:
normales Hidden verbirgt die Box, `until-found` benutzt `content-visibility`,
`embed[hidden]` erhält Nullgrößen, Tabellen-Spalten/-Gruppen/-Zeilen benutzen
die vorgesehenen Collapse-Regeln, und `input[type=hidden]` bleibt durch seine
UA-Important-Regel verborgen. Namespaced Attribute und SVG-Elemente erhalten
diese HTML-Regeln nicht. Verbundene Elemente unter `display:none` behalten
berechnete CSSOM-Werte auch ohne Layoutbox; nicht verbundene oder nicht im
Flat Tree enthaltene Elemente liefern eine leere Deklaration. Der Resolver
erstellt dafür keine GUI und benutzt die bestehende geerbte Stilauflösung.

`HiddenUA` prüft 108 native Setzen-/Übersteuern-/Revert-/Entfernen-Zustände und
Live-CSSOM am behaltenen Dokumenthost. Chromium implementiert `hidden` als
Präsentationshinweis auf Autorenebene; deshalb unterscheiden sich dort
`revert` und versteckte Tabellenstrukturen von den HTML-UA-Regeln. Die
Referenz [hidden-browser.json](../tests/fixtures/hidden-browser.json) bewahrt
diese Unterschiede ausdrücklich als normative Zusatz-Erwartungen.
Grundlage: [HTML Hidden-Rendering](https://html.spec.whatwg.org/multipage/rendering.html#hidden-elements)
und [CSSOM getComputedStyle](https://drafts.csswg.org/cssom/#dom-window-getcomputedstyle).
Dieser Teilnachweis behauptet keine vollständige Find-in-Page-/
`beforematch`-Enthüllung von `until-found` und keine vollständige browserweite
Ursprungs-/Navigation-Sicherheitsimplementierung.

## Gemeinsame Validierung und geöffnete Picker – 9. Oktober 2026

DOM, CSS-Zustände und native Formularübermittlung benutzen denselben Solver für
rohe Validitätsflags. Kandidatenregeln bleiben davon getrennt: deaktivierte,
readonly und Datalist-Felder können rohe Fehlerflags behalten, ohne an der
Formvalidierung oder `:invalid` teilzunehmen. Radiogruppen werden atomar umgeschaltet;
ihre CSS-Momentaufnahmen enthalten unabhängige Flags für vorher/nachher.
Pflicht-Selects unterscheiden die erste direkte leere Platzhalteroption von
Listen, Mehrfachauswahl und Optgroups.

`pattern` kompiliert zunächst die eigenständige UnicodeSets-Grammatik (`v`) und
prüft danach den gesamten Wert. Ungültige Syntax deaktiviert die Einschränkung;
mehrfache E-Mail-Werte werden einzeln geprüft. Der intrinsische Matcher funktioniert
auch ohne Seitenskripte und bleibt von Änderungen an `window.RegExp` unabhängig.
Quellen/Input/Matcherarbeit und der 64-Einträge-Cache sind begrenzt. Native
Validitätsabfragen und `reportValidity()` teilen die serialisierte Runtime-Grenze:
neue Hostaktionen erhalten ein neues Budget, verschachtelte Skriptarbeit behält
das laufende Budget. Fehler werden nicht als erfolgreiche Prüfung verschluckt.

Geöffnete Dropdown- und Eingabepicker erreichen `:open` und relationale Regeln
ohne ein erfundenes `open`-Attribut. Listen-Selects matchen diesen Zustand nicht.
Ein geöffnetes Selectpopup übernimmt veränderte `::picker(select)`-Styles und
Opt-in-Wechsel ohne Austausch des Hosts oder kurzes Schließen. Rich-Optionen
beachten das nichtleere `label`-Attribut. Kalender-/Datalistdarstellung bleibt
das vorhandene Hostprofil; vollständige Pickergeometrie/-effekte sind noch offen.

Nachweise: `ConstraintValidation` mit 54 aufgezeichneten Chromium-Sequenzen,
zusätzlichen Native-/Nested-Budgetfällen sowie `TextValidation`, `Forms`,
`TemporalInputs`, `JavaScriptDOMControls`, `JavaScriptCSSOMRendering` und
`RichSelectRendering`. Gemountete Farb-/Zustandswechsel erhalten GUIs ohne
zusätzliches Layout. Die automatischen GUI-Prüfungen ersetzen keine Studiooptik.
Quellen: [HTML-Validierung](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#the-constraint-validation-api),
[Patterns](https://html.spec.whatwg.org/multipage/input.html#the-pattern-attribute)
und [Offen-Zustände](https://html.spec.whatwg.org/multipage/semantics-other.html#selector-open).

Live-Änderungen von `input.type` wechseln jetzt auch die tatsächlich gemountete
anonyme Eingabeoberfläche. Der DOM-Knoten, sein Formularzustand und die äußere
Treffer-GUI bleiben erhalten; alte TextBox-Signale werden vor der Zerstörung
getrennt und neue Editor-Signale neu gebunden. Fokus und UTF-16-Auswahl überleben
geeignete Typwechsel. `hidden` verlässt den Layoutfluss, und ein zunächst
unsichtbares Feld übernimmt bei seiner ersten sichtbaren Oberfläche zuvor
gesetzte Werte, checkedness und `indeterminate`. Ein Wechsel vom Bild-Input
beendet vor dem GUI-Abbau seine Metadatenarbeit; verspätete Ergebnisse dürfen
die neue Oberfläche nicht verändern. Wiederholte Schreibweisen desselben
normalisierten Typs ersetzen keine Widgets. Formular-Reset erhält die bestehende
Auswahl und begrenzt deren Positionen auf die Länge des zurückgesetzten Werts.

Nachweis: `InputTypeState` vergleicht 968 Chromium-Sequenzen für 22×22 Typwechsel
mit sauberen und geänderten Werten, checkedness, Validierung, Radiogruppen,
Auswahl und Reset. `InputTypeRendering` vergleicht zusätzlich 16 native
Fokussequenzen, 22 mit echter Browser-Texteingabe erzeugte ungültige Zahlen und
prüft 66 wiederholte Widgetwechsel, neue native
Editor-Anbindung, unveränderte GUI-Identität, initial verborgenes Feld,
asynchronen Bildwechsel und Disposal. Die Rohreferenzen erhalten 14
Chromium-Abweichungen vom vorgeschriebenen Kopieren des aktuellen range/color-
Werts beim Wechsel zum default/default-on-Wertmodus; diese Fälle prüfen
gesonderte Standarderwartungen. 105 native Reset-Sequenzen bewegen bei
verbundenen Feldern die Auswahl an das Ende; der Standard verlangt weiterhin
die Begrenzung der vorhandenen Auswahl, wie sie die native Referenz bei
unverbundenen Feldern bereits zeigt. Ebenso bleibt Chromiums fehlendes `blur` beim
Wechsel zu `hidden` als Abweichung vom Rendering-Fokus-Fixup sichtbar. Der
Auswahlrichtungs-Standard erlaubt ein Plattformprofil: Die Engine benutzt
`none`, der Windows-Browser teilweise `forward`. Visuelle native Picker- und
Mobil-Tastaturgleichheit wird durch diese Tests nicht behauptet.
Quellen: [Input-Typwechsel](https://html.spec.whatwg.org/multipage/input.html#attr-input-type),
[Rendering-Fokus-Fixup](https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering)
und [Auswahlrichtung](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#concept-textarea/input-selection-direction).

Der Radio-Punkt verwendet eine weiße EditableImage-Alphamaske, die pro Seite beim
ersten Radio erzeugt und gemeinsam benutzt wird. Die 9×9-Maske übernimmt die
gemessenen Alphawerte des Punkts aus der vergrößerten HTML-Referenz des Nutzers.
Ein 5×5-Quadrant (`COVERAGE` in `Rendering/RadioDot.luau`) wird gespiegelt; am Rand
stehen abgestufte Werte 40/70/102/202 statt eines konstanten Transparenzrings.
Abweichende Controlgrößen skalieren das Bild
mit dem bisherigen inneren Bereich. Hover/Pressed/Disabled verändern nur
ImageColor3, niemals die Pixel. Beim Schließen wird das Bild freigegeben. Wenn
EditableImage nicht verfügbar ist, erscheint der bisherige runde Frame als Ersatz.

- `Controls/Defaults`: Standardstile, vor dem Autoren-CSS angewendet.
- `Controls/State`, `Controls/FormModel`: Werte, Radiogruppen, Daten, Submit/Reset.
- `Controls/View`: GUI-Erzeugung, Maße und Zustandsdarstellung.
- `Input/HitTest`: native GUI-Reihenfolge, Vorfahren-Clipping und DOM-Zuordnung.
  Anonyme Compositor- und Top-Layer-Flächen lassen ihren eigenen Treffer
  durch, auch bei einem registrierten DOM-Vorfahren. Ihre echten Nachkommen
  bleiben separat anklickbar; `pointer-events:none` wird weiter am
  getroffenen DOM-Element ausgewertet, nicht an der Compositor-Hülle.
- `Input/Events`, `Input/Controller`: Ereignisse, Maus/Touch/Tastatur, Fokus, API.

Ein Controller je Seite hört auf Eingabeereignisse. Es gibt keine neue
Frame-Schleife. Texteingabe, Fokus und Auswahl ändern nur die betroffenen GUIs;
`output`-Text markiert seinen Bereich für ein [partielles Layout](DIRTY-LAYOUT.md).
Geeignete unveränderte Teilbäume werden dabei wiederverwendet.
Bei unveränderten nativen Textmaßen entfällt das Layout vollständig; die Größenprüfung
läuft im gleichen Worker. Ein Wechsel zwischen leerer und gefüllter Ausgabe ändert
die Höhe und benötigt weiterhin ein partielles Layout.
Fenster-Resize verwendet dieselben TextBox-Instanzen und erhält Werte/Fokus;
Ziehen am Textarea-Griff hebt den Eingabefokus hingegen bewusst auf. Listener
werden mit der Seite aufgeräumt; ersetzte Textfragmente bleiben nicht durch
die Hit-Test-Zuordnung im Speicher. Native Scrollbereiche bleiben eingeschaltet.

## Grenzen und Prüfung

Passwörter werden mit Punkten über einer unsichtbar geschriebenen TextBox
dargestellt. Cursor-/Auswahlpositionen und horizontales Scrollen langer Passwörter
sind noch nicht an diese Maske angepasst. Mobile Tastatur und native Eingabe
müssen ebenfalls in Studio beziehungsweise auf dem Gerät geprüft werden.
Die Grundlage ist [Roblox TextBox](https://create.roblox.com/docs/reference/engine/classes/TextBox).
Die Trefferreihenfolge kommt von
[GetGuiObjectsAtPosition](https://create.roblox.com/docs/reference/engine/classes/BasePlayerGui#GetGuiObjectsAtPosition).

Dieser Abschnitt beschreibt das ursprüngliche Formularprofil. Dessen damalige
Lückenliste gilt nicht als aktueller Funktionsstand: Ereignishandler, dynamische
Pseudoklassen, Feldset-Regeln, Mehrfachauswahl und weitere Eingabetypen wurden
seitdem erweitert. Die aktuellen Nachweise und verbleibenden Grenzen stehen in
den obigen Ergänzungen, [R04](JAVASCRIPT-INPUT-R04.md),
[Eingabetypen](HTML-INPUT-TYPES-20261006.md) und dem
[HTML-Attributregister](HTML-PARSER-ATTRIBUTES-20261006.md). Ein nativer
Dateiauswahldialog bleibt ausdrücklich verschoben. Nicht unterstützte
Input-Typen fallen nach den HTML-Typregeln auf Text zurück.

`tests/Forms.luau` prüft Render-/Layout-Wiederverwendung, native Signal-Anbindung
mit GUI-Mocks, Label-/Tab-Fokus, UTF-16-Maxlength, Passwortmaskierung, Radiogruppen,
Submit/Reset und Pflichtfelder, Ereignisabbruch, Trefferreihenfolge, Clipping,
Touch-Abbruch und Cleanup. Die Tests ersetzen keinen visuellen Studio-Vergleich.
