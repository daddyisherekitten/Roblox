# Outline

Unterstützt auf Blockboxen, Bildern und Formular-Controls:

- `outline: 2px solid red` – Breite, Stil und Farbe in beliebiger Reihenfolge.
- `outline-width`: nichtnegative px, `0`, `thin`, `medium`, `thick` (1/3/5 px).
- `outline-style`: `auto`, `solid`, `dashed`, `dotted`, `double`, `none`.
- `outline-color`: die unterstützten CSS-Farben mit Alpha und `currentcolor`.
- `outline-offset`: positive oder negative px, Standard 0.

Alle Eigenschaften sind nicht vererbt. Die Kurzform setzt ausgelassene Komponenten auf 3px/none/currentcolor zurück und lässt den Offset bestehen. Reihenfolge und `!important` gelten komponentenweise. Ungültige Angaben ersetzen keine zuvor gültige Deklaration. Farben werden nach der Cascade aufgelöst.

Die Linie beginnt außerhalb der Borderbox, zusätzlich um den Offset versetzt. Negative Offsets verkleinern die Kontur nach innen; ihre Außenmaße bleiben je Achse mindestens zweimal so groß wie die Linienbreite. Outline verändert weder Layoutmaße, Textumbruch, Nachbarpositionen noch Scrollausdehnung.

Die UA-Regel `:focus-visible` ergänzt vor der Author-Cascade eine schwarze `auto`-Kontur. Textfelder zeigen sie auch bei Mausfokus; Buttons bei Tastaturfokus. Ein eigener `border` ersetzt diese Kontur nicht. Author-Regeln wie `outline:none`, `outline:0 solid`, Farbe oder Offset bleiben wirksam. `auto` verwendet das überprüfte Chromium/Windows-Profil: gerundete 2px-Linie, jeweils 1px innerhalb und außerhalb der Borderkante. Die berechnete `outline-width` bleibt erhalten, wird beim Zeichnen einer `auto`-Kontur gemäß CSS UI ignoriert. Daher blendet `outline-width:0` allein eine `auto`-Kontur nicht aus.

`Rendering/OutlineBox` verwendet `BorderBox` zum Zeichnen. Solide Konturen nutzen UIStroke und bei border-radius eine angepasste Rundung. Muster nutzen die bestehenden Segmentpools (höchstens 128 je Kante); unveränderte Geometrie wird nicht erneut aufgebaut. Alle Objekte gehören zum GUI-Unterbaum der Box und werden mit der Seite entfernt. Keine zusätzlichen Events oder Messungen.

Bei einer eigenen Outline bleibt der äußere Block ungeclippt. Scrollcontainer schneiden weiterhin über ihr ScrollingFrame ab. Für sonstiges `overflow: hidden` liegt der Inhalt in einem separaten Clip-Frame. Dadurch bleibt die eigene Outline sichtbar; Clipping eines Vorfahren wirkt weiterhin auf sie. Die Kontur bewegt sich mit der Box, auch bei Positionierung oder Scrollen.

Grenzen: keine Inline-Text-Konturen, `invert`, 3D-Stile oder Prozent-Offsets. Kontur folgt der eigenen rechteckigen Box, nicht überstehenden Nachfahren oder mehreren Textfragmenten. Muster haben dieselben Näherungen wie Rahmen: keine gerundeten oder kontinuierlichen Eckmuster; double unter 3px wie solid. Bei stark negativen Offsets und runden Ecken ist die Rundung angenähert. Andere Browser-/Betriebssystem-Profile für `auto` sind nicht separat nachgebildet.

`tests/Outline.luau` prüft Cascade, Zurücksetzen, Alpha, Offsets, Invarianz von Layout/Scrollfläche, Inhalts-Clipping, Bilder und Wiederverwendung beim Resize. `tests/FocusOutline.luau` prüft native Fokuswechsel, eigene Ränder und Konturen, Maus/Tastatur, Block-/Flex-Controls und Shadow-DOM-Felder ohne Layoutanfragen. Native Sichtprüfung in Roblox erfolgt durch den Nutzer.

Grundlage: [CSS UI: Outline](https://www.w3.org/TR/css-ui-4/#outline) und [Outline-Offset](https://www.w3.org/TR/css-ui-4/#outline-offset).
