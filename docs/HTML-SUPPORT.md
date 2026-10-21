# HTML-Grundparser: aktueller Umfang

> Historisch gewachsene Parser-/Darstellungsübersicht. Frühe Aussagen zu JavaScript, DOM und Restlisten sind teilweise überholt. Heutige Zuständigkeiten: [HTML-Abgleich](HTML-COMPLETION.md), [JavaScript-Bestand](JAVASCRIPT-IMPLEMENTATION.md), [Index](README.md). Einzelne Grenzen erst nach Code-/Profilabgleich übernehmen.

Die vollständige Restliste bis zur konformen HTML-Elementabdeckung steht in
[HTML-COMPLETION.md](HTML-COMPLETION.md).

`head`, `title`, `meta`, `link` und `base` werden beim Mount gemeinsam
ausgewertet. Titel, Dokument-/Basis-URL, Standardziel, Meta-Datensätze und
aufgelöste Linkressourcen sind auf der Page verfügbar; Links und lokale
Stylesheets verwenden dieselbe Basisadresse. Umfang und Grenzen:
[Dokumentkopf und Metadaten](DOCUMENT-METADATA.md).

`filter` auf img-Bildpixeln: brightness, contrast, grayscale, invert, sepia,
saturate, hue-rotate, opacity, blur(0–100px) und drop-shadow(), kombinierbar in Reihenfolge. EditableImage mit
Seitencache und Original-Fallback; Demo34. [IMAGE-FILTERS.md](IMAGE-FILTERS.md).

CSS `cursor` mit allen gelieferten Cursor-Assets, automatischem Text-/Linkzeiger
und Resize-Capture. Demo32; [CURSORS.md](CURSORS.md).

`table`/`tr`/`td`/`th` und `thead`/`tbody`/`tfoot`: automatische Spaltenbreiten,
colspan/rowspan, separate Zellrahmen mit border-spacing sowie border-collapse:collapse
mit gemeinsamen Rahmen. Beispiel 31; [TABLES.md](TABLES.md).

`table-layout: fixed` sowie `col`/`colgroup`: Spaltenbreiten über CSS und span,
Spaltenfarben und gemeinsame Spaltenrahmen. Test 31 zeigt 100px/20%/Restplatz.
`caption`/`caption-side`, Hintergrundfarben auf Zeilen und Zeilengruppen sowie
`empty-cells:show/hide` bei separaten Rahmen sind ebenfalls in Test 31 enthalten.

Test 33 ergänzt Tabellen-/Zeilen-/Zellhöhen mit Prozentbezug, `visibility:collapse`
für Zeilen/Spalten und Gruppen, explizite CSS-Tabellenrollen auf anderen Elementen,
implizite Rasterzeilen bei überlangen rowspans sowie `direction:rtl` für Spalten
und logische Textausrichtung. Grenzen, insbesondere Prozentkonflikte und fehlender
vollständiger Bidi-Textsatz: [TABLES.md](TABLES.md).

`details`/`summary`: aufklappbare Bereiche mit `open`, passiven Pfeilen und
Maus/Touch/Tastaturbedienung. Beispiel 30; Teilumfang: [DETAILS.md](DETAILS.md).

`autofocus` auf Formularcontrols: einmal beim ersten fertigen Layout, unter
Beachtung vorhandener Eingabe/Fokuszustände. Details: [FORMS.md](FORMS.md).

`input type="email"`, `input type="url"` und `minlength` ergänzt. Syntax-/Längenprüfung
nutzt das vorhandene invalid-/Fokus-System. Details und URL-/IDN-Grenzen: [FORMS.md](FORMS.md).

`fieldset`/`legend`: Formulargruppen mit unterbrochenem oberen Rahmen und
`disabled`-Vererbung (Ausnahme erste direkte DOM-Legende). Das gemeinsame Beispiel 29
gruppiert die vorhandene Checkbox und die Radios. Details und Grenzen: [FORMS.md](FORMS.md).

Neu: Formulare mit TextBox, Number, Checkbox, Radio, Range, Buttons, Select/Option, Label, Output und lokalem
Ereignis-/Hit-Test-System; Teilumfang und API: [FORMS.md](FORMS.md). Vergleich 29.

`progress` und `meter`: passive Fortschritts-/Messwertbalken mit Wertebegrenzung,
Meter-Farbbereichen und unbestimmtem Fortschritt. Details ebenfalls in FORMS.md.

`em` und `rem` bei unterstützten CSS-Längen, einschließlich Kurzformen.
Root-/Elternbezug, Vererbung und Grenzen: [RELATIVE-LENGTHS.md](RELATIVE-LENGTHS.md).
Katalog: CSSProperties.RelativeUnits; Vergleichsbeispiel 28, Tests: RelativeLengths.
Ältere Abschnitte mit em/rem als Einschränkung werden dadurch ersetzt.

Rahmen-Eckübergänge jetzt diagonal, auch bei ungleichen Breiten; kleine
EditableImage-Eckbilder mit bisheriger Darstellung als Fallback.
[Details](BORDER-CORNERS.md). Bestehende Demo15 und 18–20.

Neu: word-wrap-Alias, border-style outset/groove/ridge, hsl()/hsla(), address,
dl/dt/dd und figure/figcaption. Standards und Grenzen:
[Kleine Ergänzungen](SMALL-ADDITIONS.md). Demoabschnitte 18–20.

Neu: `text-overflow: clip | ellipsis`, mit `overflow-x:hidden` für LTR-Zeilen.
Originaltext und Layout bleiben erhalten; Beispiel 17 zum Resize-Vergleich.
[Details und Grenzen](TEXT-OVERFLOW.md).

Neu: `outline`, `outline-width`, `outline-style`, `outline-color` und `outline-offset`
auf Blöcken, Bildern und Formular-Controls; zusätzliche Kontur ohne Layout-/Scrollplatz.
Stile auto/solid/dashed/dotted/double/none, positive/negative Abstände.
Native Fokusrahmen bleiben auch bei eigenen CSS-Rändern erhalten.
[Verhalten und Grenzen](OUTLINE.md).

## Bereits vorhanden

- Ein eigener Elementbaum aus Document-, Element-, Text- und Comment-Knoten.
- Verschachtelung mit Eltern-/Kind-Beziehungen, Namen und Attributen.
- Tag- und Attributnamen werden kleingeschrieben; Werte und Text bleiben erhalten.
- Attribute mit einfachen/doppelten Anführungszeichen oder ohne Anführungszeichen.
- Boolesche Attribute wie `checked`: vorhanden als leere Zeichenkette. `checked="false"` ist ebenfalls vorhanden.
- Bei mehrfach vorhandenen Attributen gewinnt das erste.
- HTML-Void-Elemente wie `img`, `br`, `input`, `meta`, `link` benötigen kein End-Tag.
- Optionale li-End-Tags vor dem nächsten li beziehungsweise dem Ende der direkten ul/ol-Liste; die nächste Listengrenze begrenzt die Suche.
- Optionale option-End-Tags innerhalb select/optgroup; Optionswerte und Startauswahl siehe FORMS.md.
- Kommentare und einfaches `<!DOCTYPE html>`.
- Häufige benannte Zeichenreferenzen mit Semikolon und dezimale/hexadezimale Unicode-Referenzen.
- Unbekannte benannte Referenzen bleiben unverändert; keine doppelte Decodierung.
- `script` und `style` bleiben Rohtext. Der reine Parser wertet sie nicht aus; der Renderer verarbeitet anschließend style-Regeln.
- `textarea` und `title` behalten Tags als Text, decodieren aber Zeichenreferenzen.
- BOM am Anfang entfernen, CR/CRLF in LF normalisieren, Nullzeichen ersetzen.
- Diagnosemeldungen für einige fehlerhafte Eingaben und einfache Wiederherstellung am passenden End-Tag.
- `findById` und `textContent` ohne rekursive Traversierung.

## Noch keine vollständige Browser-HTML-Verarbeitung

Dies ist ein dokumentierter HTML-Teilumfang. `parseHTML` bleibt Fragmentmodus;
`parseDocument` und `mountHTML` legen fehlende `html/head/body`-Container an.
Ausgelassene End-Tags wie `<p>eins<p>zwei` werden noch nicht nach den HTML5-Regeln korrigiert.
Auch die vollständige Tabellen-Reparatur, spezielle Formatierungsrekonstruktion und MathML fehlen.
Deklarative Shadow Roots über `template[shadowrootmode]` werden angehängt; der
Renderer verteilt benannte und namenlose Slots. Dynamische Shadow-DOM-APIs,
`slotchange`, Event-Retargeting, `:host` und `::slotted()` fehlen noch.
`<div/>` schließt sich im HTML-Teilumfang nicht selbst; der Slash erzeugt eine Diagnose.
Benannte Zeichenreferenzen ohne Semikolon und die vollständige HTML-Zeichentabelle fehlen.
Numerische C1-Steuerzeichen werden noch nicht nach der HTML-Windows-1252-Tabelle umgesetzt.
Andere Tags werden als normale Elemente gespeichert. Das verspricht noch keine Darstellung oder Funktion.

Leerzeichen bleiben im DOM erhalten. Zusammenfassen und Zeilenumbruch übernimmt das getrennte Textlayout.
CSS-Werte in `style` werden nur als Attributtext gespeichert. Bilder werden nicht geladen.
Es werden weder Roblox-GUIs erstellt noch Eingaben verarbeitet oder Scripts ausgeführt.

## Grenzen und Fehler

```lua
local document = Engine.parseHTML(html, {
    MaxBytes = 1024 * 1024, -- maximale Eingabelänge
    MaxNodes = 20000,      -- einschließlich Document
    MaxDepth = 256,       -- Elementtiefe, erstes Element = 1
    MaxDiagnostics = 100,
})
```

Die Werte sind positive ganze Zahlen. Überschrittene Grenzen brechen mit einem Luau-Fehler ab;
bei fremden Eingaben kann der Aufrufer `pcall` verwenden. Der Aufruf ist synchron und sollte bei einer Änderung
des gesamten HTML-Quelltexts erfolgen, nicht in jeder Frame-Schleife.
Diagnosen stehen in `document.Diagnostics` und enthalten Code, Message und Position.
Position ist ein Byte-Offset in der normalisierten Eingabe. Nach dem Meldungslimit wird
`DiagnosticsTruncated` gesetzt. Ein vollständiges Browser-Diagnosesystem ist das noch nicht.

Die Engine protokolliert den Inhalt nicht automatisch und enthält keine Testskripte.
Die CLI-/Studio-Tests liegen in `tests/HTML.luau`; die Demo liegt in `examples/HTMLParser.client.luau`.

## Erste Darstellung ergänzt

Neu unterstützt: hr, mark, sup/sub, background auf Inline-Text, vertical-align baseline/super/sub, font-size smaller und text-align-last. Standardwerte, Quellen, Fragmentlayout und Grenzen stehen in [Kleine Elemente](SMALL-ELEMENTS.md).

`Engine.mountHTML(targetFrame, html)` stellt inzwischen einen einfachen Block-Teilumfang mit CSS-Regeln und Inline-Styles dar.

Blockboxen unterstützen außerdem mehrschichtige `background-image`-Ebenen mit
zugeordneten Roblox-Assets sowie linearen, radialen und wiederholenden
Verläufen. Größe, Position, Wiederholung, Origin und Clip verwenden denselben
CSS-Quelltext wie der Browser. Details und Budgets:
[CSS-Hintergrundbilder](CSS-BACKGROUNDS.md).
Der Parser selbst bleibt unabhängig von dieser Darstellung. Das bearbeitbare Beispiel liegt in
`examples/HTMLPage.client.luau`; unterstützte Style-Eigenschaften stehen in der README.
Der HTML-Block enthält das vollständige Dokument einschließlich Google-Fonts-Link und CSS.
Er lässt sich unverändert als eigenständige HTML-Datei speichern. Der Browser lädt die Schriften online;
Roblox wertet die style-Regeln aus und verwendet für bekannte Familien seine registrierten Fonts.
Registrierte externe Stylesheets werden geladen. Es gibt keinen freien Netzwerkdownload von Stylesheets oder Fontdateien; `@font-face` wird als gültige Browser-Metadaten akzeptiert, die Fontwahl bleibt auf registrierte Roblox-Familien beschränkt.

`CSS/Stylesheet.luau` sammelt alle style-Blöcke vor der Darstellung und unterstützt Tag-, Klassen-, ID-,
Universal-, kombinierte, Nachfahren- und direkte Kindselektoren (`>`) sowie Kommagruppen. Regeln gelten nach Spezifität und
Quellreihenfolge; Inline-Styles haben Vorrang, `!important` steht über normalen Deklarationen.
`CSS/Syntax.luau` berücksichtigt Kommentare, Zeichenketten und geklammerte Werte beim Trennen.
Ungültige Werte ersetzen keine gültigen vorherigen Werte. Nicht unterstützte Selektoren verwerfen die
gesamte Selektorgruppe mit Diagnose. At-Regeln werden einschließlich verschachtelter Blöcke übersprungen.
Style-Medien sind auf leer/all/screen beschränkt; andere Angaben werden mit Diagnose übersprungen.
HTML verwendet Tag-, Klassen-, ID-, Universal-, Attribut-, Nachfahren-, Kind- und Geschwisterselektoren sowie strukturelle und interaktive Pseudoklassen. CSS-Escapes fehlen noch. Die vollständige CSS-Restliste steht in [CSS-COMPLETION.md](CSS-COMPLETION.md).
`font-weight` akzeptiert normal/400, bold/700 und Zahlen von 1 bis 1000 mit Vererbung. Der nächste Roblox-Schnitt in 100er-Stufen von Thin bis Heavy wird für Messung und Darstellung verwendet; 600 entspricht SemiBold. Die `font`-Kurzform unterstützt diese Gewichte einschließlich Größe und Zeilenhöhe. h1/h2/b/strong verwenden standardmäßig 700; CSS kann dies überschreiben. bolder/lighter fehlen.

Welche Elemente ausdrücklich behandelt werden und welche Einschränkungen sie haben, steht zentral in
[`src/HTMLEngine/HTML/Elements.luau`](../src/HTMLEngine/HTML/Elements.luau), auch abrufbar als `Engine.Elements`.
Renderer und Standardformatierung lesen diesen Katalog. `partial` bezeichnet den dokumentierten Darstellungs-Teilumfang,
`parser-only` ausschließlich die Speicherung im DOM. Andere Tags kann der Parser ebenfalls speichern;
ihre bisherige Darstellung als generischer Block verspricht keine Unterstützung der jeweiligen HTML-Funktion.
Der Katalog beschreibt Elementtypen. Konkrete Seitenelemente liegen weiterhin in `page.Document`.

CSS-Eigenschaften sind in [`CSS/Properties.luau`](../src/HTMLEngine/CSS/Properties.luau) dokumentiert (`Engine.CSSProperties`).

Textschatten: `text-shadow` unterstützt zunächst bis zu 16 scharfe Schatten mit px-Offset, Farbe/Alpha und Vererbung; none deaktiviert sie. Kein Blur. Details und Grenzen: [TEXT-SHADOW.md](TEXT-SHADOW.md).

Bilder: `img` unterstützt die seitenbezogene src→Asset-Zuordnung, alt, width/height, CSS-Größengrenzen und alle fünf object-fit-Werte. `picture`/`source` sowie `srcset`/`sizes` wählen beim Mount eine responsive Quelle; `map`/`area` liefern rechteckige, runde, polygonale und Default-Linkflächen. vertical-align unterstützt zusätzlich middle, text-top/text-bottom, top/bottom und px/%. Rahmen, runde Ecken, Margin/Padding und box-sizing sind direkt auf img möglich. Fehlende automatische Achsen können die Roblox-Assetmaße einmal pro Seite lesen. Details, Einschränkungen und Browser-Testdatei: [IMAGES.md](IMAGES.md).

Medien: `audio`, `video`, deren `source`-Kinder sowie einfache WebVTT-`track`-
Untertitel verwenden im Browser normale Dateien und in Roblox getrennte
`Audio`-/`Videos`-/`Tracks`-Zuordnungen. Eigene Controls unterstützen Play,
Pause, Seek, Mute und CC; Video-Poster bleiben normale `Images`-Zuordnungen.
Details und Grenzen: [MEDIA.md](MEDIA.md).

Eingebettete Dokumente: `iframe`, `object[type=text/html]` und
`embed[type=text/html]` mounten registrierte interne Websites in einer eigenen
PageSession. `object` zeigt bei fehlender Quelle oder nicht unterstütztem Typ
seinen HTML-Fallback. Größen, Rahmen, Scrollen und Lifecycle laufen über das
gewöhnliche Layout. Details und Grenzen: [IFRAMES.md](IFRAMES.md).

Listen: ul/ol/li erzeugen Blockcontainer und separate Außenmarker. Standardmäßig 40px linkes Padding auf ul/ol, vertikale Außenabstände von 1em nach der endgültigen CSS-Schriftgröße, bei verschachtelten Listen 0. li hat kein zusätzliches Margin/Padding. ul verwendet disc, ab zweiter Listenebene circle und ab dritter square; ol decimal. Autor-CSS überschreibt diese Standards. Grundlage: [HTML-Standard: Listen](https://html.spec.whatwg.org/multipage/rendering.html#lists).

`list-style-type: disc/circle/square/decimal/decimal-leading-zero/lower-alpha/upper-alpha/lower-roman/upper-roman/none` wird vererbt. Nummerierung berücksichtigt gerenderte direkte li-Kinder, ol start/reversed und li value (vorzeichenbehaftete Ganzzahlen bis 32 Bit). Verborgene Einträge und mit display:block umgestellte li werden nicht gezählt; list-style-type:none blendet nur den Marker aus. Unterlisten zählen unabhängig. Ein isoliertes li bekommt einen Punkt. Alphabetisch ab 1, römisch 1–3999, außerhalb decimal. `list-style-image:url(...)` verwendet ein über `options.Images` zugeordnetes quadratisches 1em-Bild und fällt ohne Zuordnung auf den Markertyp zurück. Keine generischen CSS-Counter, type=a/A/i/I oder RTL-Marker. Details: [Listenformate](LIST-DECORATION-EXTENSIONS.md).

Marker stehen außerhalb der li-Inhaltsbreite und verkleinern diese nicht. WordFlow liefert die erste Zeilengrundlinie, BlockLayout reicht diese über Unterblöcke weiter. So bleiben Marker bei mehrzeiligem Text sowie gemischten Schriftgrößen an der ersten Zeile; leere Einträge mit Marker erhalten eine Zeilenhöhe. Dezimalmarker einschließlich Punkt/Leerzeichen werden individuell gemessen und rechts an der Inhaltskante ausgerichtet. Font-Preload schließt diese Labels ein, Messungen bleiben beim Resize erhalten und werden bei Abbruch nicht geschrieben. Symbolmarker nutzen Frames/UICorner/UIStroke, orientiert an [Blink-Listengeometrie](https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/core/layout/list/list_marker.cc); echte Font-Ascent ist in Roblox nicht verfügbar, daher verwenden sie die bestehende Baseline-Näherung. Pixelidentische Marker sind nicht garantiert.

BlockLayout berechnet für ul/ol/li/blockquote zusätzlich effektive obere/untere Ränder vor der Anordnung: Kindränder am offenen oberen/unteren Rand fallen mit dem Elternrand zusammen. Border/Padding, overflow hidden und unten feste/minimale Höhe verhindern dies. Text unterbricht den Zusammenfall. Das verhindert doppelte Absatzabstände in Listeneinträgen, ohne Style.Margin beim Resize zu verändern. Kein vollständiges allgemeines Eltern-Kind- oder Leerblock-Collapsing; linke negative Markerüberläufe erweitern die Canvas nicht. Tests in tests/Lists.luau decken Abstände, Verschachtelung, Umbrüche, Markergrundlinien, Nummernwechsel, leere/verborgene Einträge, CSS-Overrides und Messwiederverwendung ab. Native Sichtprüfung noch offen.

`line-height` unterstützt normal, nichtnegative Dezimalzahlen, px und Prozentwerte einschließlich Vererbung.
Faktoren beziehen sich auf die CSS-Schriftgröße; Prozentwerte werden vor der Vererbung in Pixel aufgelöst.
Der Zeilenschritt wird getrennt von der Höhe der Wort-Labels berechnet. Wörter mit verschiedenen Schriftgrößen
und Schriftfamilien teilen sich pro Zeile die Grundlinie aus ihren Fontprofilen. Der größte Platz über und unter
der Grundlinie bestimmt die Zeilenhöhe, mindestens mit der Fontbox des Absatzstils. Gemischte Schriften können
deshalb auch bei gleicher fester `line-height` eine höhere Zeile ergeben. `normal` und die logischen Fontmetriken
bleiben Näherungen; unkalibrierte Fonts verwenden `round(TextSize * 0.8)` als geschätzte Grundlinie.

Inline-Text unterstützt `font-size`, `font-family`, `font-weight`, `font-style`, `color` und `line-height` mit Vererbung sowie `display: none`.
Verschachtelte Spans werden berücksichtigt. Leerraum wird über Taggrenzen hinweg zusammengefasst; jedes Wort und
sein nötiges Leerzeichen werden weiterhin separat gemessen. Ändert sich der Stil innerhalb eines ungetrennten Wortes,
bleibt dessen erster Stil erhalten und eine Diagnose erklärt die Einschränkung. Ein vollständiges Inline-Box-Modell,
Inline-Margin/Padding/Hintergrund und andere `vertical-align`-Werte fehlen. Leere Spans und reine
Inline-Vorfahren ohne eigenen Text liefern noch keine zusätzlichen Zeilenmetriken.
Details und ein Beispiel: [historische README zur gemeinsamen Grundlinie](history/2026-10-06/README-original.md#gemeinsame-grundlinie).

`text-align` unterstützt start (Standard), end, left, center, right und justify mit Vererbung. Maßgeblich ist der Stil des Blockcontainers;
ein eigener Span-Wert verschiebt keine einzelnen Wörter. Jede Zeile wird nach dem Umbruch innerhalb der Inhaltsbreite
ausgerichtet, einschließlich letzter Zeile und br. Padding, Grundlinien und individuelle Wortmessungen bleiben erhalten.
start/end folgen direction; vollständiger Unicode-Bidi-Textsatz fehlt. Überbreite Wörter können nach links überlaufen; das bisherige Scrollmodell kann
diesen linken Überlauf nicht nachträglich zugänglich machen. Die sichtbare Demo enthält nur noch kompakte Beispiele.

`justify` dehnt nur normale Wortabstände bei automatischem Umbruch. Letzte Zeilen, Zeilen vor br und
Zeilen ohne dehnbare Abstände bleiben linksbündig. Geschützte Leerzeichen werden nicht zerlegt.
`text-align-last` überschreibt die Ausrichtung letzter Zeilen und Zeilen vor festen Umbrüchen; keine automatische Silbentrennung.

## Weitere Schritte

### Leerraum und Umbruch

Stand 9. Oktober 2026, Zielquelle: [CSS Text 4, Working Draft vom 14. August 2026](https://www.w3.org/TR/2026/WD-css-text-4-20260814/#white-space-property). `white-space-collapse` und `text-wrap-mode` bleiben unabhängige, vererbte Achsen. Alle zwölf Kombinationen der sechs Kollapswerte mit `wrap/nowrap` werden verarbeitet; der Kurzname `white-space` akzeptiert die Legacy-Werte und ein oder zwei Achswörter in beliebiger Reihenfolge. `white-space-trim` gehört weiterhin zum offenen Umfang. Ungültige/doppelte Wörter werden verworfen; Variablen, CSS-weite Werte und wichtige Deklarationen laufen durch dieselbe Kaskade.

`collapse` kollabiert ASCII-Leerraum; `preserve` erhält Spaces/Tabs/LF; `preserve-breaks` kollabiert Spaces/Tabs und erhält LF auch mit nowrap. `preserve-spaces` ersetzt Tabs/LF durch erhaltene Spaces. `break-spaces` erhält Endleerraum und erlaubt Zwischenumbrüche, einschließlich Stilgrenzen zwischen erhaltenen Folgen. `discard` entfernt ASCII-Leerraum ohne neue Umbruchgelegenheiten. Der eingefrorene Entwurf lässt die Umbruchwirkung von discard ausdrücklich offen; diese Profilentscheidung beweist keine endgültige Standardgleichheit. nowrap verhindert weiche Umbrüche einschließlich Silbentrennung/Notumbrüchen; br und erhaltene LF wirken weiter. Der ursprüngliche DOM und sichtbare UTF-16-Quelloffsets bleiben erhalten.

InlineWords erzeugt Space-Frames und Break-Einträge; WordLayout behält native Messungen je Element. Keine gepoolte Satzmessung. WordFlow unterscheidet bei preserve+wrap zwischen vollständig hängendem Endleerraum vor weichen Umbrüchen und nur teilweise hängendem, überlaufendem Endleerraum vor festen Umbrüchen/am Blockende. Passender Endleerraum zählt dort zur Ausrichtung. Ein Inline-Endrahmen/-padding verhindert das Hängen. Überbreite Zeilen werden am Anfang ausgerichtet, auch bei center/right: [CSS Text 3 §6.1](https://www.w3.org/TR/css-text-3/#text-align-property) verlangt diese Startausrichtung. Die Browserfixture enthält dafür eigene zwölfbuchstabige, untrennbare Wörter; die zwei früheren negativen-X-Erwartungen in TextAlign wurden anhand dieser Evidenz korrigiert. Transparente Leerraumframes behalten ihre Auswahl-/Dekorationsgeometrie; unveränderte Messungen und Frames werden beim Resize wiederverwendet. Dynamische Achswechsel regenerieren betroffene Wortstrukturen; eigene White-space-Grenzen, fremde Controls und folgende Boxen bleiben erhalten.

`tab-size` ist vererbt, Standard 8; akzeptiert nichtnegative Zahlen oder berechnete Längen, inklusive null und Bruchzahlen. Zahlen verwenden die native Leerzeichenbreite der nächsten Blockschrift inklusive word-spacing/letter-spacing. Ein abweichender Inline-Stil ändert dieses Raster nicht. Der Mindestvorschub beträgt 0.5ch, gemessen an der Ziffer 0; ein zu naher Stopp wird übersprungen. Die Messungen werden je Space-Eintrag behalten und nach Schriftänderung erneuert. [Tabpositionierung](https://www.w3.org/TR/2026/WD-css-text-4-20260814/#white-space-phase-2).

Nachweis: `tests/WhiteSpace.luau` prüft Achsgrammatik/Kaskade, Tabs, feste/weiche Umbrüche, Endleerraum, Inline-Gruppen/-kanten, Ausrichtung, Quellen, Resize und dynamische Normal→Preserve/Discard→Normal-Wechsel mit GUI-Erhaltung. `scripts/capture-whitespace-reference.cjs` erfasst 468 Layoutfälle eines isolierten Chrome; `tests/fixtures/whitespace-browser.json` bewahrt Rohdaten und Browserkennung. 264 tatsächlich unterstützte ASCII-Layouts vergleichen Zeilenhöhen und ursprüngliche Positionen von Wörtern, Spaces und Tabs. Die Capture-Umgebung unterstützt discard/preserve-spaces nicht; deren Tests folgen der Zielquelle, nicht einem behaupteten nativen Browsernachweis. Encodiertes CR wird normativ als Space behandelt, während der erfasste Chrome CR versteckt. FF ist kein CSS-Leerraum und bleibt Kontrollglyph im Wort; Chrome zeigt ihn je Kollapsmodus unterschiedlich. Diese font-/UA-abhängigen Fälle sind getrennt vom gleichmäßigen Messrastervergleich. Zusätzlich vergleichen `tests/ScriptSelection.luau` und der isolierte Runner 312 unterstützte native Selection.toString-Fälle, einschließlich CR/FF. Erhaltener CR wird wie im Browser im Kopiertext bewahrt, obwohl sein normativer Vorschub ein Space ist; kollabierter CR wird ein gewöhnliches Leerzeichen. LF wird nur in Modi mit erhaltenen Umbrüchen separat kopiert und ein nicht mehr dargestellter Schluss-LF entfällt. FF wird über seine normale Wortquelle einmal kopiert. preserve-spaces/discard-Kopierregeln sind gesonderte Profiltests. Sichtprüfung im echten Roblox bleibt offen.

Offen: vollständige Unicode-/Sprach-/Bidi-Regeln, zusätzliche Unicode-Space-Separatoren für break-spaces, white-space-trim und Kontrollglyph-Synthese bei unsichtbarer nativer Glyphe. Tabstopps mit Blocksatz bleiben angenähert, da die Dehnung nach der Tabpositionierung erfolgt. Komplexe kombinierte Inline-/Bidi-/Fragmentierungsfälle und vollständige intrinsische Größen brauchen weitere Nachweise. preserve-spaces-Endhängen ist im Zielentwurf ungeklärt; das Profil erhält diese Endspaces vollständig. Die beschriebenen Teilanforderungen schließen C06 nicht insgesamt ab.

### Vertikale Außenabstände

Benachbarte Blockgeschwister verwenden für unteren/oberen Margin den größeren der beiden nichtnegativen Werte. Reiner HTML-Leerraum und display:none trennen sie nicht; ein tatsächlicher Textlauf schon. Die Berechnung erfolgt bei jedem Layout neu ohne Änderungen an den CSS-Werten. Padding, Rahmen und overflow der Geschwister ändern diese äußere Regel nicht. Margin nach einer festen Box wird nicht noch einmal an das Ende ihrer überlaufenden Kinder angehängt. Grenzen: noch kein Eltern-Kind-Collapsing, Zusammenfallen durch leere Blöcke oder negative Margins. Die bestehende kompakte Demo zeigt den Effekt bereits zwischen ihren p-Absätzen und Karten. Test: tests/MarginCollapse.luau. Grundlage: [CSS collapsing margins](https://www.w3.org/TR/CSS2/box.html#collapsing-margins).

### Höhenbegrenzung und Überlauf

`min-height: auto/0/px`, `max-height: none/0/px` und `overflow: hidden/visible/auto/scroll` sind für Blockcontainer implementiert und nicht vererbt. overflow nimmt einen oder zwei Werte (x/y); overflow-x und overflow-y setzen die einzelnen Achsen. Höhengrenzen sind nichtnegativ und berücksichtigen box-sizing. auto entspricht keiner zusätzlichen Mindesthöhe, none entfernt die Maximalhöhe. Erst Maximum, dann Minimum anwenden; Padding und Rahmen können bei border-box nicht unterschritten werden. Prozenthöhen, intrinsische Werte und andere Einheiten fehlen.

Alle Kinder werden vollständig angeordnet. Die belegte Höhe im Blockfluss ist die begrenzte Boxhöhe plus Margin; sichtbarer Überlauf wird separat bis zur Seiten-Scrollfläche weitergereicht. Ein hidden/auto/scroll-Vorfahre begrenzt diese äußere Ausdehnung auf seine Box. Auto/scroll bewegen einen eigenen Inhaltsbaum im nativen ScrollingFrame innerhalb der Rahmenkante; Leistenplatz und lokale Scrollfläche werden im Layout berücksichtigt. Reines hidden nutzt weiterhin den Frame-Zuschnitt an der Außenkante. Clipping bleibt rechteckig, auch bei UICorner. Ein Kind mit visible kann das Clipping seiner Vorfahren nicht aufheben. Keine öffentliche programmatische Scroll-API oder Übertragung von html/body-overflow auf den Viewport. Details: [Scrollbereiche](SCROLLING.md). Tests: `tests/Overflow.luau` und `tests/Scrolling.luau`; Demo-IDs scroll-text und scroll-cards. Studio-Sichtprüfung offen.

### Weitere bereits implementierte Eigenschaften

`box-sizing` unterstützt content-box (Standard) und border-box, ohne Vererbung. Bei border-box werden width/height/min-width/max-width einschließlich Padding und Rahmen verstanden, ohne Margin. Inhaltsmaße können auf 0 fallen; die Box bleibt mindestens so groß wie ihre Padding-/Rahmenkanten. `min-width` akzeptiert auto/0/px/%, `max-width` none/0/px/%; alle Längen nichtnegativ. Im vorhandenen Blocklayout entspricht min-width:auto keiner zusätzlichen Mindestbreite. Grenzen werden nach width/Auto-Breite angewendet, zuerst Maximum, dann Minimum; dadurch gewinnt min-width im Konflikt. Prozent beziehen sich auf die Eltern-Inhaltsbreite, auch bei verschachtelten Border-Boxen. Inline-Text speichert box-sizing ohne eigene Größenwirkung (Universalregel möglich); min/max-width auf Inline-Text bleiben nicht unterstützt. Keine intrinsischen Größen, em/rem oder calc; Höhengrenzen unterstützen nur px. Resize verändert Boxen/Umbruch, ohne unveränderte Wortmaße neu zu messen. Feste Höhen belegen nur ihre Boxhöhe im Seitenfluss; sichtbarer Überlauf wird separat für die Scrollfläche erfasst. Grundlage: [CSS Box Sizing Level 3](https://www.w3.org/TR/css-sizing-3/). Tests: tests/BoxSizing.luau; Beispiel id=box-sizing mit 180–480px Gesamtbreite. Visuelle Studio-Bestätigung offen.

Blöcke und Bilder unterstützen `border` mit px oder thin/medium/thick, solid/inset/outset/groove/ridge/none/dashed/dotted/double und einer Farbe oder currentcolor in beliebiger Reihenfolge. Fehlende Werte werden auf 3px/none/currentcolor zurückgesetzt. `border-width`, `border-style` und `border-color` akzeptieren 1–4 Werte; `border-top/right/bottom/left` und ihre Longhands setzen einzelne Kanten. CSS-Reihenfolge und !important gelten pro Komponente und Seite. Die Eigenschaften werden nicht vererbt. currentcolor wird nach der Cascade anhand der finalen Textfarbe aufgelöst. `border-radius` akzeptiert ein bis vier Werte und elliptische Werte nach `/`; die vier Eck-Longhands unterstützen Längen und Prozente. Auch bei border:none bleibt die Rundung bestehen. Einfarbige Boxen verwenden eine vollständige gerundete EditableImage-Oberfläche. Bei `overflow:hidden` enthält dasselbe Bild eine Vordergrundmaske gegen den nächsten deckenden Hintergrund und der HitTest folgt der exakten Ellipse. Transparente Umgebungen und Bildhintergründe verwenden die größte gemeinsame sichere UICorner-Rundung. Musterkanten sind rechteckig, ohne durchgehenden Musterverlauf um Ecken. Details und Mustergrenzen: [Rahmenkanten](BORDER-SIDES.md).

BlockLayout behandelt Rahmen als zusätzliche Kanten im content-box-Modell: Auto-Breite zieht Rahmen/Padding/Margin vom Platz ab, explizite px/%-Breite und px-Höhe bleiben Inhaltsmaße. Kindpositionen, Umbruch, Geschwisterfluss und Scrollausdehnung berücksichtigen den Rahmen. UIStroke zeichnet mit BorderStrokePosition.Inner, UICorner rundet Hintergrund/Rahmen und begrenzt den Radius nativ auf die halbe kürzere Boxkante. Modifikatoren werden einmal beim Aufbau über GuiFactory.modifier erstellt, beim Resize wiederverwendet und mit ihren Eltern entfernt. Grundlagen: [Roblox UI appearance modifiers](https://create.roblox.com/docs/ui/appearance-modifiers). Tests: tests/Border.luau und tests/GuiFactory.luau; echte Studio-Optik noch nicht geprüft.

`letter-spacing: normal/0/px` (auch negative px) wird vererbt. Nichtnull Werte erzeugen ein Wort-Frame mit einem Label je Graphem; [Roblox utf8.graphemes](https://create.roblox.com/docs/reference/engine/libraries/utf8/graphemes) hält zusammengesetzte Zeichen zusammen. Jeder Cluster wird einzeln gemessen, kein geteilter Messcache. Wortweite ist die Summe der Zeichenbreiten plus Abstände zwischen ihnen; kein Zusatz am Zeilenanfang/-ende. Normale Wortlücken berücksichtigen die zusätzlichen Zeichenübergänge, kombiniert mit word-spacing und justify. Auch NBSP-Gruppen bleiben untrennbar, ihre innere Wortweite berücksichtigt im Zeichenmodus word-spacing. Baselines, text-indent und skip-ink funktionieren weiter; SkipInk nutzt die Zeichenpositionen statt Präfixmessungen. normal/0 bleibt beim Seitenaufbau der bisherige Wort-Label-Pfad. Grenzen: voneinander unabhängige Zeichendarstellung ohne wortübergreifendes Shaping/Kerning/Ligaturen, keine %, em/rem oder RTL. Negative Abstände können überlappen; rechter sichtbarer Überlauf wird mitgerechnet. Kein neues DOM-Dirty-System oder dynamischer Wechsel der Label-Struktur. Tests: `tests/LetterSpacing.luau`; CLI-Graphemgrenzen der Unicode-Testdaten kommen aus JS Intl.Segmenter, echter Roblox-Sichttest noch offen.

`word-spacing: normal/0/px` (px auch negativ) wird vererbt und zum normalen gemessenen Leerzeichen addiert. Kollabierter Whitespace erhält den Stil des ersten überlebenden Leerzeichens. Der Wert ist in CSS-Pixeln, ohne Font-Größenkorrektur. Umbrüche, Ausrichtung, Blocksatz, Einzug und Unterlinien verwenden den Zusatzabstand; native Messwerte bleiben unverändert und wiederverwendbar. Große negative Werte dürfen überlappen; horizontale Ausdehnung berücksichtigt auch frühere, weiter rechts endende Wörter. Noch keine %, em/rem oder weiteren Unicode-Worttrenner. NBSP innerhalb eines nativen Wort-Labels bleibt nativ/untrennbar und erzeugt bei nichtnull Abstand eine Diagnose; der Zeichenmodus bei letter-spacing unterstützt dagegen diesen Zusatzabstand. Tests: `tests/WordSpacing.luau`, ein kompakter Demo-Absatz mit 6 px Zusatzabstand. Semantik: [CSS word-spacing](https://www.w3.org/TR/css-text-3/#word-spacing-property).

`text-transform` akzeptiert none, math-auto oder eine beliebige Reihenfolge aus höchstens einem Case-Wert (uppercase/lowercase/capitalize), full-width und full-size-kana. Doppelte/exklusive Werte sind ungültig; die Ausgabe wird in Case/Width/Kana-Reihenfolge kanonisiert. Unicode-17-Vollabbildungen ersetzen das frühere Latin-1-Profil: Erweiterungen (ß → SS, Ligaturen), Titlecase-Digraphen, zusätzliche Schriften und astrale Buchstaben. Alle 16 bedingten SpecialCasing-Regeln sind eingebunden: finales griechisches Sigma, türkische/aserbaidschanische Punktregeln und litauische Akzente/Punkte. Dazu kommen niederländisches IJ am Wortanfang und griechisches Uppercase mit Akzententfernung, Dialytika, Iota-Subscript und dem alleinstehenden disjunktiven ή. Sprachregeln beachten gültige Sprachkennzeichen und ausdrücklich deklarierte Schriftsysteme; unbekannte/ungültige Kennzeichen verwenden Standard-Unicode-Casing.

Angrenzende Textfragmente teilen einen linearen, rein linguistischen Originalkontext. Stil-, leere Inline- und wbr-Grenzen erfinden keinen neuen Großschreibungsanfang; Finale-Sigma-/Punktregeln verlieren weder vorherige noch folgende Buchstaben. capitalize verändert das erste vollständige Graphem, erhält die übrige Schreibweise und verwendet ein festgelegtes UA-Wortgrenzenprofil (Unicode-Leerraum/Dashes und ausgewählte Satzzeichen, Apostroph/Unterstrich innerhalb des Wortes). Width verwendet die wide/narrow-Abbildungen, Kana die zugehörigen großen Zeichen einschließlich kleiner Halbbreiten-Kana. Die Reihenfolge ist Case → Width → Kana. full-width macht nur erhaltene U0020-Spaces zu U3000; kollabierte Zwischenräume bleiben normale Spaces. Zusammengesetzte Halbbreiten-Kana/Voice Marks werden als kanonisch äquivalente Fullwidth-/Combining-Folge dargestellt, ohne DOM-Normalisierung. math-auto gilt nur für ursprüngliche Textknoten mit genau einem Unicode-Zeichen; mehrere Wörter oder benachbarte Einzeichen-Textknoten werden dabei korrekt unterschieden.

Transformation passiert vor Label-Erzeugung und individueller Wortmessung. Weder Messwerte noch Wörter werden global gepoolt; Unicode-Daten werden erst bei einer aktiven Transformation geladen und bleiben aus der allgemeinen Kaltmodul-Ladeliste ausgeschlossen. Resize verwendet die gemessenen Wörter erneut. Originale UTF-16-Spans bleiben auch bei Expansion und entfernten Punkten/Bindestrichen erhalten; ausgeblendete Quellen besitzen Nullbreiten-Caretgrenzen. Dynamische Sprach-/Mode-/benachbarte Textänderungen erneuern den linguistischen Kontext und erhalten eigene Sprachgrenzen sowie fremde Controls/Boxen; Dokumentdefault, namespaced xml:lang einschließlich leerem Vorrang und Shadow-Host-Sprache sind separat geprüft. Fullwidth-Spaces behalten individuelle Messwerte, während numerische Tabs weiterhin gewöhnliche Font-Space-Tabstopps verwenden. JavaScript Selection.toString folgt dem Chromium-Darstellungsprofil einschließlich erhaltener Fullwidth-Spaces. Die getrennte Lua-Methode ScriptSelection.CopyText bereitet dagegen ursprünglichen Text inklusive entfernter Zeichen für Plain-Text-Copy vor. Firefox 157 liefert bei Selection.toString die Quellschreibung; diese Browserabweichung ist mit vollständigen und partiellen Auswahl-Rohwerten erfasst. Keine der beiden Lua-Methoden behauptet einen Betriebssystem-Clipboard-Transport.

Provenienz: `scripts/generate-text-case.py`, eingefrorene Unicode-17-Dateien unter `scripts/data/unicode-case-17.0.0`, gemeinsam genutztes UnicodeData unter `scripts/data/unicode-17.0.0`, URL/SHA256-Manifest und eingebettete Unicode-License-V3 in `Layout/TextCaseData.luau`. Offline-Regeneration ist reproduzierbar. `tests/TextTransform.luau` prüft sämtliche 3540 Upper/Lower/Wide/Kana/Math-Laufzeitabbildungen, zusätzliche bedingte Regeln, Grammatik/Kombinationen, Originalkontext über Stilgrenzen, dynamische Vererbung/Sprach-/Mode-/Textänderungen und individuelle Messwert-Wiederverwendung. `tests/ScriptSelection.luau` prüft expandierte SS, entfernte Punkte, Teilbereichsstring/Kopie und Caret-Geometrie.

Native Evidenz: `scripts/capture-text-transform-reference.cjs` erfasst 1620 rohe Chrome-154-Outputs mit Browserkennung, unterstützt-Meldung, computed-Wert, Originaltext, innerText und Selection.toString. 520 vergleichbare Case-Ausgaben werden automatisch abgeglichen. Nicht als Gleichheitsnachweis verwendet werden dort nicht unterstützte Width-/Kana-Grammatiken, math-auto (innerText zeigt keine Glyphentransformation), mehrere von Chromium abweichende vollständige Titlecase-/Sprach-/Stilkontexte und Georgian-/astrale Capitalize-Fälle. Diese Rohwerte bleiben sichtbar; eingefrorene Unicode-/CSS-Regeln und explizite Tests bestimmen das Engine-Verhalten. Der Textnachweis belegt keine Roblox-Pixel-/Font-/Shaping-Gleichheit und keine native Clipboard-Schreiboperation.

Irisches ga/ga-Latn ergänzt ein lineares Präfixprofil: bhf/bp/dt/gc/mb/nd/ng und t+s mit Vokal/l/n/r erhalten kleine Präfixbuchstaben, ebenso h/n/t vor ursprünglich großen Vokalen. n-/t- vor kleinem Vokal verlieren beim Uppercase ihren Bindestrich (U002D/U2010/U2011). Lowercase fügt ihn nur bei ursprünglichem kleinem n/t unmittelbar vor großem Vokal ein; originale Großpräfixe und vorhandene Bindestriche werden nicht geraten. Ein eingefügter Bindestrich gehört geometrisch zum Originalspan des Vokals, ein entfernter bleibt als Nullbreitenquelle kopierbar. Stilfragment-, Sprach-/Mode-/Nachbartextänderungen und individuelle Resize-Messung sind geprüft. Bewusst konservativ wie die Primärregeln: h vor kleinem Vokal kann ein gewöhnliches Wort oder ein Präfix sein; ein Wörterbuch zur Auflösung dieser Mehrdeutigkeit ist nicht eingebunden.

Irische Provenienz/Evidenz: `scripts/capture-irish-casing-reference.cjs` und der isolierte Firefox-BiDi-Helper erfassen 327 gepaarte Firefox-157.0.1/Chrome-154-Ausgaben in derselben TextTransform-Fixture. 321 Firefox-innerText-Ausgaben werden direkt verglichen, darunter sämtliche 316 eingefrorenen Gecko-Reftest-Beispiele. Die sechs ausgenommenen Stilkontext-/Schriftsystemfälle behalten Rohwerte und explizite Engine-Erwartungen nach den CSS-Kontextregeln; Firefox verliert dort Kontext oder ignoriert ga-Cyrl. Primärdateien/SHA256/Commit `5836a062726f715fda621338a17b51aff30d0a8c` und MPL-2.0 liegen unter `scripts/data/irish-casing`; der Adapter drückt die beschriebenen Sprachregeln selbstständig aus und übernimmt keinen FSM-Code. Die Tests zeigen keine Wörterbuch- oder native Roblox-Glyphen-Vollständigkeit.

capitalize ist bewusst ein dokumentiertes UA-Wortgrenzenprofil, keine Behauptung sämtlicher linguistischer Wort-/Phrase-Wörterbücher oder weiterer frei konfigurierbarer Sprachtailorings. Native Glyphenverfügbarkeit, Font-Fallback, Formung/Kerning über Stilgrenzen und schwierige vertikale/Bidi-/Fragmentierungs-Kombinationen bleiben in ihren eigenen Profilen begrenzt. Primärgrundlagen: [CSS Text 4 vom 14. August 2026, Mapping/Verarbeitungsreihenfolge](https://www.w3.org/TR/2026/WD-css-text-4-20260814/#text-transform-property), [Unicode 17 SpecialCasing](https://www.unicode.org/Public/17.0.0/ucd/SpecialCasing.txt), [MathML Core math-auto](https://www.w3.org/TR/mathml-core/#the-math-auto-transform), [ICU 77 Greek Upper](https://github.com/unicode-org/icu/blob/release-77-1/icu4c/source/common/ucasemap.cpp), [irische Uppercase-Regeln](https://bugzilla.mozilla.org/show_bug.cgi?id=1014639) und [irische Lowercase-Regeln](https://bugzilla.mozilla.org/show_bug.cgi?id=1018805).

`text-indent` verarbeitet signierte Längen/Prozent und berechnete Ausdrücke, optional `hanging` und/oder `each-line` in beliebiger Reihenfolge. Die Länge ist erforderlich; doppelte Flags oder zusätzliche Längen sind ungültig. each-line wiederholt den Einzug nach br/erhaltenem LF, nicht nach weichen Umbrüchen; hanging kehrt die betroffenen Zeilen um. Die erste formatierte Zeile eines Blocks und spätere anonyme Textläufe bleiben unterschieden. Prozent beziehen sich auf die aktuelle Block-Inhaltsbreite; intrinsische Probes setzen nur den Prozentanteil auf null und erhalten absolute Beiträge. RTL zieht den logischen rechten Rand ein, LTR den linken Anfang. Inline-Angaben werden an Blocknachfahren vererbt und verschieben keine einzelnen Wörter. Resize und dynamische signierte/Prozent-/Flag-/Richtungswechsel erhalten WordItems, eigene Einzugsgrenzen, fremde Controls und folgende Boxen.

Nachweis: `scripts/capture-text-indent-reference.cjs` erfasst 2160 tatsächlich unterstützte Chrome-Layouts; `tests/fixtures/text-indent-browser.json` enthält Rohpositionen, Zeilenhöhen und Browserkennung. `tests/TextIndent.luau` vergleicht LTR/RTL, start/center/end, signed px/%/calc, vier Flagkombinationen, feste/weiche/führende Umbrüche, LF und anonyme Blöcke bei drei Breiten. Dazu kommen Grammatik, Vererbung, intrinsische Breiten, Resize und dynamische GUI-Erhaltung. Die Glyphenmessung im Automatentest ist gleichmäßig; der RTL-Nachweis verwendet lateinischen Inhalt, belegt also logische Einzüge, keine vollständige Bidi-Neuordnung. Kombinierte echte Roblox-Glyphen-/Bidi-/vertikale-/Float-/Fragmentierungsfälle und native Sichtabnahme bleiben offen; negativer linker Scrollüberlauf ist eine bekannte Grenze des bisherigen Scrollmodells.

C05-Bidi-Algorithmus und Inline-Integration (Stand 10. Oktober 2026): `Layout/Bidi.luau` besitzt Unicode-17-P1/P2/P3, explizite Embeddings/Overrides/Isolates bis zur normativen Grenze 125, isolierende Run-Sequenzen, W-/N-/I-Regeln einschließlich N0-Paarungen/canonical-equivalent Brackets und zeilenbezogene L1/L2-Umordnung. Absatz-/Zeilenobjekte liefern ursprüngliche Codepointindices, inverse Visualindices und Richtungsläufe; Originaltext sowie globale UTF-8-/UTF-16-Spans bleiben erhalten. Entfernte X9-Steuercodes behalten die Quelle, erscheinen aber nicht in der Visualreihenfolge. Eine Zeilenprojektion kopiert nur ihre Strecke, keine wiederholte ganze Absatzkopie. Mirroring ist ein separater Codepoint-Hinweis und verändert keine DOM-Quelle.

Der isolierte Runner `scripts/test-bidi.cjs` prüft alle 770.241 Class-/Base-Fälle aus BidiTest und 91.707 Codepoint-Absätze aus BidiCharacterTest, zusätzlich Absatzwechsel/astrale Quellindices/Zeilenenden, Inputkopie und Fehlerfälle. Diese Originalkorpora prüfen durch L2; sie beweisen keine native Glyphencluster/-formung L3/L4, Caretpositionen oder GUI-Darstellung. Die nachfolgend beschriebenen Integrationstests sind eigenständige Nachweise. P1 wird zusätzlich durch eigene Mehrabsatzfälle geprüft. `scripts/generate-bidi.py` regeneriert offline 128 Bracket- und 428 Mirror-Einträge; Quellen, Unicode-17-Version, SHA256 und Unicode-Lizenz liegen unter `scripts/data/unicode-bidi-17.0.0` bzw. eingebettet im Datenmodul. Normative Referenz: [UAX9 Revision 51 (Unicode 17)](https://www.unicode.org/reports/tr9/tr9-51.html), [BidiTest 17](https://www.unicode.org/Public/17.0.0/ucd/BidiTest.txt), [BidiCharacterTest 17](https://www.unicode.org/Public/17.0.0/ucd/BidiCharacterTest.txt). Dieser Stand schließt C05 nicht ab.

Die Inline-Integration löst alle sechs `unicode-bidi`-Werte mit nichtvererbten CSS-Scopes, HTML `dir`/`dir=auto`, `bdi`/`bdo` und tatsächlichen UAX9-Absätzen auf. Pro umbrochener Zeile projizieren L1/L2 die ursprünglichen Wortstücke in physische Reihenfolge. Die logischen Besitzer und UTF-16-Quellintervalle bleiben unverändert; X9-Steuerzeichen bleiben als verborgene Quellspannen erhalten. Native Labels erhalten die aufgelöste Richtung; nur notwendige Overrides verwenden unsichtbare Richtungscodes. Normale LTR-Wörter bleiben unverändert und behalten ihre eigenen Messungen. ZWJ/ZWNJ bleiben für die native Formung erhalten. Rahmen-/Paddingkanten richten sich nach der Inline-Boxrichtung, nicht nach der zufälligen Parität eines ersten Zahlenteils. Dekorationen, Schatten und markierte Teilintervalle verwenden die physische Projektion.

`CSS/Directionality` verwendet die HTML-Regeln unabhängig von author-CSS `direction`. Lebende Input-/Textarea-Werte wirken auf ihre eigene automatische Richtung und `:dir`-Selektoren, ohne das `value`-Attribut oder den Defaulttext zu verändern. Die bestehende Formzustandsänderung invalidiert nur bei semantischer Richtungsänderung; auch JS-Setter lösen diesen Pfad aus. DOM-Text-/`dir`-Änderungen berücksichtigen automatische Vorfahren, explizite Richtungsgrenzen, Shadowhosts und zugewiesene Slots. Es gibt keine periodische Seitensuche. Reine ASCII-Richtungsänderungen erhalten Wortlauf, Itemarray, GUI und individuelle Messungen, wenn die Zerlegung gleich bleibt; tatsächlich geänderte Richtungsstücke werden lokal regeneriert. Native Controlassoziationen überleben das Ende einer JS-Laufzeit und werden durch ihren Seitenbesitzer abgebaut.

Nachweise: `scripts/capture-bidi-reference.cjs` und `tests/fixtures/bidi-browser.json` enthalten 414 echte Chrome-Zeilen-/Wortgeometrien: RTL/LTR, normal/plaintext/override, Hebräisch, Arabisch, Zahlen, Brackets, Isolates, verschachtelte Scopes, Steuerzeichen, feste/weiche Umbrüche, kombinierende Grapheme, Joining-Codes und asymmetrische Inline-Kanten bei drei Breiten. Weitere 18 Rohlayouts prüfen unabhängig gezeichnete RTL-/LTR-Grapheme mit Tracking. Hier enthält Chromes Range eine zusätzliche abschließende Trackingbreite; die Engine behält die normative n−1-Verteilung und die rohen Browserwerte dokumentieren diese Abweichung. Diese 18 Fälle sind keine Behauptung übereinstimmender äußerer Ausrichtungs-/Rangebreiten. Grundlage: [CSS Text 3 §7.2](https://www.w3.org/TR/css-text-3/#letter-spacing-property). 13 HTML-UA-Fälle und neun native Shadow-/Slotänderungsschritte mit 45 Style-/`:dir`-Snapshots werden separat verglichen. Die erfasste Chrome-UA-Isolate-Regel für automatische Textinputs weicht von der HTML-Prosa `plaintext` ab; die Fixture kennzeichnet genau diese normative Erwartung.

`text-overflow:ellipsis` kürzt am visuellen Ende gemäß Blockrichtung. Richtungsstücke behalten dafür die passende logische Vorsilbe oder Nachsilbe und ihre ursprünglichen Spannen; Layout und vollständiger Quelltext bleiben erhalten. Die Markierung verweist auf verborgene Quellintervalle. `scripts/capture-bidi-ellipsis-reference.cjs` erfasst 30 tatsächliche Browserbilder mit eindeutig gefärbten Quellzeichen; `tests/BidiRendering.luau` vergleicht die sichtbar gemalten Zeichen, RTL-/LTR-Seite, Quellkopie, Mess-/GUI-Wiederverwendung und den Abbau alter Ellipsen. Browser-Rangegeometrie allein wäre dafür kein Paintnachweis. [CSS Overflow 3 §5.1](https://www.w3.org/TR/css-overflow-3/#text-overflow).

Die Ersatzobjekttests belegen keine pixelgleiche Roblox-Fontformung. Kontextformung und Kerning über getrennte Richtungs-/Stilgrenzen, native L3/L4-Glyphcluster/-mirroring, Cluster-Caretpräzision, sämtliche gemischten vertikalen Orientierungs-/Fontfälle, vollständige Block-/Ruby-/Tabellenachsen und sämtliche Kombinationen mit Floats, Fragmentierung, Tabs oder Einzügen bleiben offene Anforderungen. `Selection.toString` liefert die logische dargestellte Browserquelle; `CopyText` ist die separate Quellkopie-API und kein zugesicherter OS-Clipboardtransport. Die Unicode-/CSS-Scope-/Ellipsis-Teilanforderungen sind umgesetzt und geprüft; C05 ist insgesamt weiter offen.

Vertikaler Mischtext: `Layout/VerticalOrientation` verwendet die eingefrorene Unicode-17-Quelle mit 189 zusammengeführten Nicht-R-Intervallen, Default R und 13 Me-Enclosing-Marks. Die Orientierung wird für vollständige Grapheme bestimmt; ein enthaltenes Me macht das ganze Graphem aufrecht. `mixed` zerlegt Wortstücke in aufrechte U/Tu/Tr- und seitwärts gedrehte R-Gruppen, mit unveränderten logischen UTF-16-Quellen. Es werden keine Leerzeichen an Orientierungsgrenzen erfunden. Tu/Tr behalten ihren Bedarf an vertikalen Alternates ausdrücklich; deren native Glyphsubstitution ist noch nicht umgesetzt. Generator, Originaldaten, SHA256 und Unicode-Lizenznachweis: `scripts/generate-vertical-orientation.py`, `scripts/data/unicode-vertical-17.0.0/manifest.json`. Das Datenmodul wird erst bei Bedarf geladen. `scripts/test-vertical-orientation.cjs` prüft die tatsächliche Luau-Suche gegen alle 1.114.112 Codepoint-Klassifikationen der unveränderten offiziellen Datei und alle 13 Enclosing-Mark-Adapter; das ist ein Datensuchnachweis, kein Nachweis nativer Fontsubstitution. Grundlagen: [UAX50 Revision 33 (Unicode 17)](https://www.unicode.org/reports/tr50/tr50-33.html), [CSS Writing Modes 4 §5.1.2](https://www.w3.org/TR/css-writing-modes-4/#mixed-orient).

Aufrechte vertikale Schrift verwendet pro Graphem eine vertikale Em- oder horizontale Fontzelle. Unterschiedliche Zellvorschübe im selben Wort werden getrennt gespeichert; unveränderte Projektionen behalten diese individuellen Werte und Glyphenpools. `upright` verarbeitet den Inhalt mit LTR-Bidi-Verhalten, ohne den vererbten computed direction zu ändern. Einzug und Zeilenausrichtung folgen weiterhin der berechneten Richtung des Line-Box-Containers, wie [CSS Text 3 §8.3](https://www.w3.org/TR/css-text-3/#bidi-linebox) verlangt. Die bisherige pauschale LTR-Ausrichtung bei upright war falsch und ist einschließlich Regression korrigiert. Auswahl, DOM-Range-Rechtecke und Pointer-Offsets verwenden bei aufrechten Stücken die vertikale Achse; Highlight-Glyphen gehören weiter ihrem ursprünglichen Wort und werden vollständig aus den Registern entfernt. Dynamische Achs-/Orientierungswechsel erhalten Wörter, Itemarrays, GUI und aufrechte Pools, wenn die logische Zerlegung unverändert bleibt. Eine tatsächlich andere Mixed-Zerlegung regeneriert den betroffenen Wortfluss und erhält benachbarte Controls.

`sideways-rl` und `sideways-lr` sind eigene Schreibmodi: Sie formen vollständige horizontale Wortläufe und drehen sie um 90° bzw. −90°. `sideways-lr` kehrt dabei die physische Inlineachse um; `text-orientation` beeinflusst diese beiden Modi nicht. Der gemessene Inlineumfang gehört zum gespeicherten Paintzustand und wird bei reiner Verschiebung oder Repaint wiederverwendet. `scripts/capture-vertical-mixed-reference.cjs` bewahrt 192 rohe Chrome-Layouts mit vier vertikalen/seitlichen Modi, drei Orientierungen und beiden Richtungen. `tests/VerticalMixed.luau` vergleicht 164 tatsächlich passende Inline-Achsgeometrien, alle 192 logischen Selection-Kopien und 24 tatsächliche native gedrehte Range-/Pointerfälle sowie Retention, dynamische Änderungen und Highlightabbau. Der Geometrievergleich injiziert individuell gemessene Browserwort-/Präfixbreiten und Fontzellen; Roblox-Schriftkalibrierung und horizontale Baselinepositionen werden damit nicht pixelgleich nachgewiesen. 28 Fälle sind ausdrücklich von der Geometriegleichheit ausgeschlossen: Ersatzfont-Vertikalmetriken für Hangul/Emoji, Chromes abweichende Behandlung enclosing-mark-Graphemen und upright-RTL-Font-/Reihenfolgefälle. Ihre Rohdaten und konkrete Abweichung bleiben in der Fixture erhalten. Diese Ausschlüsse sind offene Adapter-/Nachweisanforderungen, keine behaupteten technischen Unmöglichkeiten.

`CSS/WritingMode` vereinheitlicht die physischen Seiten/Ecken und Scrollachsen aller fünf Schreibmodi. Logische Margin-/Padding-/Border-/Inset-/Scrollkanten und Border-Radius-Ecken werden vor der Deklarationsanwendung mit berechnetem writing-mode/direction zugeordnet. Ein logischer Scroll-Longhand bleibt ein Einzelwert; er wird nicht mehr fälschlich als Liste verworfen. Scroll-Snap-/Markerprojektion berücksichtigt block/inline, Richtung, `sideways-lr` und asymmetrische Scroll-Padding-/Marginwerte auch beim Zentrieren; Quelllayout und aktuelle Scrollposition bleiben bei der Zielberechnung unangetastet. Der horizontale Textmutations-Schnellpfad schließt alle vertikalen/seitlichen Modi aus. `scripts/capture-writing-axes-reference.cjs` und `tests/WritingAxes.luau` prüfen 30 tatsächliche native Seiten-/Eckzuordnungen und 90 tatsächliche native Scrollausrichtungen, einschließlich aller Orientierungen. Browsernegative RTL-Scrollwerte bleiben in der Fixture; der Geometrienachweis verwendet aus den tatsächlichen Zielrechtecken abgeleitete physische Canvasoffsets. Das beweist die Zielprojektion, keinen vollständigen nativen RTL-Scroll-API-Transport.

Logisches `inherit` liest die gleichnamige logische Elternkante/-ecke und ordnet sie anschließend den Kinderachsen zu. Für 100 Eltern-/Kindkombinationen bewahrt die Fixture sowohl Chromes rohe Vererbung als auch eine echte Browserprojektion der einzeln ausgelesenen logischen Elternwerte. 82 dieser Rohfälle weichen ab: installiertes Chrome übernimmt physische Gegenstücke; [CSS Logical Properties 1 §4](https://www.w3.org/TR/css-logical-1/#box) verlangt die gleichnamige logische Eigenschaft des Elternteils. Die Engine folgt hier der dokumentierten Spezifikation. Diese 100 Projektionen werden deshalb ausdrücklich nicht als 100 übereinstimmende rohe Chrome-Vererbungsfälle gezählt. Vollständige Revert-/Prozentbasis-/orthogonale Layoutkombinationen sind dadurch nicht nachgewiesen.

Vertikale Inlinefragmente: `InlineFragments.prepare/draw` nutzt dieselbe `WritingMode`-Projektion für physische Padding-/Borderseiten und gerade Hintergrundflächen. CSS-Rahmen drehen nicht mit den Glyphen. Bidi-Paint reserviert die Kanten am tatsächlichen visuellen Fragmentrand statt an unverändert logischen Wortendpunkten; Quellen bleiben erhalten. `scripts/capture-vertical-fragments-reference.cjs` und `tests/VerticalFragments.luau` vergleichen 240 tatsächliche native Fragmentanzahlen, physische Größen und Inlinepositionen in allen fünf Modi, drei Orientierungen, zwei Richtungen und slice/clone. Native Fontboxhöhen bleiben von vertikalen Em-Zellvorschüben getrennt. Der Test vergleicht die Cross-Baselineposition bewusst nicht pixelgleich, solange native Fontmetriken fehlen. Runde/verschachtelte Fragmentflächen, Inline-Bildhintergründe, Fragmentopacity und vollständige orthogonale Margin-/Fragmentierungsfälle bleiben offen.

Auswahllücken zwischen vertikalen/gemischten/sideways Wortstücken werden aus der gespeicherten Bidi-Zeilenstrecke projiziert. Aufrechte Ranges verwenden ihren Em-Vorschub und die individuell gemessene native Fontbox quer zur Linie; gedrehte Ranges und Leerraum-Highlights folgen der bestehenden Wortrotation. Die Fixture bewahrt 60 tatsächliche native kollabierte Leerzeichen-Ranges, geprüft auf Inlineposition und physische Größe. Wiederholte Auswahl und reine Flowverschiebung behalten Gapframes und Wortmessungen; Abbau entfernt ihre Quellregistrierung. Das beweist rechteckige 0°/±90°-Textachsen, keine exakten Auswahlvierecke bei beliebigen CSS-Transformwinkeln. `scripts/test-script-selection.cjs` erhält zusätzlich alle 312 nativen Whitespace-Kopierfälle unverändert.

Vertikale Textlinien: `TextDecoration.draw` projiziert Unter-, Über- und Durchstriche auch an aufrechten und gemischt gedrehten Wortstücken. `text-underline-position` akzeptiert die vollständigen unterstützten Level-4-Kombinationen von under/from-font mit left/right; die berechnete Reihenfolge ist kanonisch. In vertikaler Typografie bestimmen left/right die physische Unterstrichseite und tauschen bei Bedarf die Überstrichseite. Horizontale und sideways Typografie ignoriert diese Seitenangabe. Positive/negative explizite Offsets beginnen bei under an der Inhaltkante; der Linienursprung trägt Fontgröße, Position, Verschiebung und Farbe weiter. Rastermuster bleiben im bestehenden Seitencache; aufrechte Musterlabels drehen innerhalb der physischen Linie. `scripts/capture-vertical-decoration-reference.cjs` bewahrt 1620 echte native Paintfälle mit per-Element-Farbmaske und unveränderten Fontpositionen. `tests/VerticalDecoration.luau` vergleicht Linie/Achse, Inlineausdehnung und physische Seite, 23 native Grammatikfälle, computed Werte, Modus-/Farbwechsel, Poolerhaltung und Abbau. UA-/Fontpositionen quer zur Linie sind bewusst kein Pixelgleichheitsnachweis; from-font verwendet weiter die geschätzten Fontdaten. Aufrechtes Glyphen-Skip-ink wird nicht als Konturadapter behauptet. Grundlagen: [CSS Text Decoration 3 §2.5](https://www.w3.org/TR/css-text-decor-3/#text-underline-position-property), [CSS Text Decoration 4 §2.7–2.8](https://www.w3.org/TR/css-text-decor-4/#text-underline-position-property).

Scharfe Textschatten: `Rendering/TextShadows` bewahrt die Originalglyphen, Bidi-Richtung und individuellen Wortmessungen. Offsets bleiben auch bei 0°/±90°-Wortrotation physische Rechts-/Untenwerte; die lokale Gegenprojektion verhindert eine zweite Rotation. `scripts/capture-vertical-shadow-reference.cjs` bewahrt 240 getrennte echte Vordergrund-/Schatten-Pixelmasken. `tests/VerticalShadows.luau` prüft 240 normative Projektionen: 96 rohe Chromium-Paintfälle passen, 144 drehen die Offsets mit der seitlichen Glyphenfläche. Diese Abweichung bleibt erhalten, weil [CSS Writing Modes 4 §7.6](https://www.w3.org/TR/css-writing-modes-4/#physical-only) ausdrücklich physische Schattenwerte verlangt. Dynamische Listen, transparente/entfernte/zurückkehrende Schatten, gemischte Inlinequellen und Abbau sind geprüft. Einheitliche Änderungen erhalten Original-GUI, Vordergrund und Kopien ohne neue Textmessung. Grenzen und Stapelung: [TEXT-SHADOW.md](TEXT-SHADOW.md).

Textbetonungszeichen: `Layout/TextEmphasis` erzeugt erhaltene Marken pro berechtigtem Graphem. Unicode-17-Kategorien und NFKD-Ausnahmen bestimmen Ausschlüsse; ein Separator mit Combining-Mark bleibt eine gemeinsame berechtigte Einheit. Leere CSS-Zeichenketten sind gültig, andere verwenden ihr erstes Graphem. Ausgelassene Form wird zum berechneten circle/sesame-Paar und vererbt als solches. Marken übernehmen 50% der nativen Textgröße, behalten in vertikaler Schrift ihre aufrechte Orientierung und verwenden die vorhandenen Fontfeatures. Horizontale/sideways Typografie projiziert over/under, vertikale Typografie left/right. Die Orientierung von Marken in sideways-Typografie ist in Level3 undefiniert; die Engine verwendet ausdrücklich aufrechte Marken. Quelle: [CSS Text Decoration 3 §3](https://www.w3.org/TR/css-text-decor-3/#text-emphasis-style-property), [CSS Writing Modes 4](https://www.w3.org/TR/css-writing-modes-4/#typographic-mode).

`scripts/generate-text-emphasis.py` nutzt ausschließlich das eingefrorene Unicode-17-UCD: 841 Ausschluss-, 8 Separator- und 327 Markintervalle, SHA256 und vollständige Unicode-Lizenz im bei Bedarf geladenen `Layout/TextEmphasisData`. `scripts/capture-vertical-emphasis-reference.cjs` und `tests/VerticalEmphasis.luau` bewahren 247 tatsächliche Mark-Pixelkomponenten, ursprüngliche Graphem-Ranges, Selection-Kopien und Fontboxen mit/ohne Mark. Quellzentren werden getrennt von rasterisierten Ink-Zentren geprüft. 144 native sideways-Seitenwerte, 32 upright-RTL-Quellzentren, 10 automatische Form-/Vererbungswerte und ein ausgelassenes Separator+Combining-Zeichen bleiben ausdrücklich abweichende Rohdaten, keine Gleichheitsnachweise. Der [normative upright-LTR-Override samt Implementierungshinweis](https://www.w3.org/TR/css-writing-modes-4/#text-orientation) bleibt Grundlage der Originalzeichenreihenfolge.

Marken gehören weder DOM-Text noch Selection-Quellen an; echte Hit-Traversierung erreicht den ursprünglichen UTF16-Wortbesitzer. Farbe, Stil, Position, Schreibmodus, Umbruchstücke, Ellipsen, scharfe Markenschatten und Abbau sind geprüft. Einheitliche Änderungen erhalten Wort, GUI und wortlokale Messcaches; nur tatsächlich verschiedene ursprüngliche Inline-Effektscopes werden neu zerlegt. Aufrechte Zellen/Tracking verwenden vorhandene Glyphenvorschübe statt zusätzlicher Präfixmessung. Mark-/Schattengrenzen erweitern den tatsächlichen CanvasGroup-Paintbereich, damit keine Mark außerhalb der Fontbox abgeschnitten wird. Es gibt keine globale Textmessungsablage.

Offen bleiben vertikale Alternates, vollständige native Ersatzfontmetriken, Emoji-Joining, weiche UAX14-Kombinationen und vollständige Block-/Flex-/Grid-/Table-/Ruby-Layoutachsen. Marken reservieren Zeilenumfang mit dem vorhandenen geschätzten Fontprofil; exakte Ruby-/Dekorationskollisionen, Ruby-Fontfeature-/Ersatzglyphadapter und alle kombinierten Glyphen-/Fragmentierungsfälle bleiben offen. Die 247 Browserfälle beweisen keine Roblox-Pixel-/Fontgleichheit und kein vollständiges natives Ruby-Verhalten. Das sind weitere Implementierungs- oder Nachweisanforderungen; Hostgrenzen nativer Glyphformung bleiben davon getrennt.

Semantikgrundlage: [CSS Text Level 3](https://www.w3.org/TR/css-text-3/), Abschnitte text-transform und text-indent. Tests: `tests/TextTransform.luau`, `tests/TextIndent.luau`; je ein kompakter Beispielabsatz im gemeinsamen HTML-Dokument.

Unter-/Durchstreichungen sind mit `text-decoration: none/underline/line-through` und der Kombination
beider Linien sowie u/s/del ergänzt. Die Engine schätzt bewusst: Unterlinie Baseline+max(1, round(CSS-font-size/14)) px (1 px bis Größe 20, 2 px ab 21, 3 px ab 35; weitere Übergänge geschätzt), Durchstrich
Baseline-round(CSS-font-size/4), automatische Dicke max(1, floor(CSS-font-size * 0.049)) für alle Schriften und Gewichte. Gemeinsame Näherung passend zu den drei gemeldeten Übergängen: 2 px ab 41, 3 px ab 62, 4 px ab 82. text-decoration-thickness akzeptiert auto, px und Prozent (explizite px/% gerundet, mindestens 1 px). Das gemeinsame Demo-HTML verwendet automatische Dicke; Browser-auto kann abweichen. Keine individuellen Fontmetriken.
Dekorationen werden von Vorfahren weitergetragen, obwohl die CSS-Eigenschaft selbst nicht vererbt wird;
ein child none entfernt deshalb keine bestehende Vorfahrenlinie. Ursprungsfarbe/-dicke bleiben erhalten.
Normale Wortabstände, Umbrüche und Blocksatz werden berücksichtigt. Experimentelles `text-decoration-skip-ink: auto/none`: auto ist Standard, schätzt Lücken bei p/g/j/q/y über wortlokale Präfixmessungen und mit der Textgröße skalierende Randabstände. Keine echten Glyphenkonturen, keine Garantie für alle Schriftvarianten oder andere Alphabete. none unterdrückt diese Zusatzmessungen und Lücken; Durchstriche bleiben durchgehend. Beim Umbruch bleiben Lücken und Frame-Segmente wiederverwendbar. Unter-/Über-/Durchstriche, getrennte Farb-/Stil-/Offseteigenschaften und vertikale Projektionen sind inzwischen ergänzt; die aktuelle Nachweisgrenze steht im C05-Abschnitt darüber. Kein Kerning über Fragmentgrenzen oder Zugriff auf native Unterstrich-Fontmetriken.
Browser und Roblox verwenden dasselbe Demo-HTML; die vereinfachte Geometrie muss nicht pixelgleich sein.

Den vorhandenen Inline-Style- und Block-Teilumfang um weitere CSS-Funktionen, genaueren Textfluss und
weitere Layoutverfahren erweitern. DOM-Änderungen und gezielte Aktualisierungen erhalten
eigene Schnittstellen; der rohe Baum ist bisher noch kein reaktives Dirty-System.

Wort- und Leerzeichenmessungen berücksichtigen das Schriftgewicht getrennt. Unveränderte individuelle Maße bleiben beim Umbruch erhalten; Änderungen nur am Gewicht lösen die betroffene Messung neu aus. Bold verwendet vorerst die Regular-Größen-/Linienwerte als Näherung und wird nicht als separat kalibriert gemeldet.

`font-style` unterstützt normal/italic mit Vererbung und CSS-Overrides. i/em sind standardmäßig kursiv;
verschachtelte starke Betonung kombiniert italic mit Gewicht 700. oblique/Neigungswinkel fehlen.
FontProfiles.face nimmt optional Gewicht und Stil entgegen; Wort- und Leerzeichenmessschlüssel enthalten beides.
Italic/Fett-Kursiv verwenden Regular-Größen- und Linienwerte als Näherung, nicht als eigene Kalibrierung.
Welche Schnitte tatsächlich existieren, hängt von der Roblox-Familie ab; fehlende Schnitte löst Roblox auf.
Der kurze Google-Fonts-Link der identischen Browser-/Studio-Demo fordert alle vier Varianten an.
