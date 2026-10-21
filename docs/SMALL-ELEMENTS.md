# Trennlinie, Hervorhebung, Hoch-/Tiefstellung und letzte Zeile

Die gemeinsame Demo verwendet unverändertes Standard-HTML. Die Darstellung ist anhand der HTML-Vorgaben und des Chromium-Codes implementiert; ein nativer visueller Browser-/Studio-Vergleich steht noch aus.

## sup und sub

Die Tags verwenden `font-size: smaller`, `line-height: normal` und `vertical-align: super/sub`. Grundlage: [HTML-Phrasing-Defaults](https://html.spec.whatwg.org/multipage/rendering.html#phrasing-content-3).

Für kleinere Schrift wird die CSS-Schriftgröße des Elternteils durch 1.2 geteilt ([Chromium FontDescription](https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/platform/fonts/font_description.cc)). Anschließend gilt die bestehende Roblox-Fontkorrektur samt Aufrundung; intern mindestens 1 CSS-Pixel. CSS kann Größe, line-height und Ausrichtung überschreiben.

Der Grundlinienversatz orientiert sich an [Chromium InlineBoxState](https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/core/layout/inline/inline_box_state.cc): super nach oben um Elternschrift/3 + 1px, sub nach unten um Elternschrift/5 + 1px, auf 1/64px quantisiert. Bei 20px Elternschrift ergibt das 16.6667px CSS-Schriftgröße sowie 7.65625px nach oben bzw. 5px nach unten. Verschachtelte Verschiebungen addieren sich. Kein künstlicher horizontaler Abstand.

InlineWords erzeugt bei Stilwechseln zusammenhängende Wortfragmente. Dadurch bleiben `m<sup>2</sup>` und `H<sub>2</sub>O` beim Umbruch ungetrennt. Gleich formatierte Teile bleiben ein Wortlabel. WordLayout misst Fragmente einzeln und berücksichtigt ihre Verschiebung bei Ascent/Descent; WordFlow vergrößert die Zeile bei Bedarf. Reflow verwendet dieselben Instanzen und Maße. Auch b/i/u und farbige Teilwörter profitieren davon.

Grenzen: Roblox-Fontboxen und Baselines bleiben kalibriert/angenähert. Kein Kerning oder Ligaturen über Fragmentgrenzen; keine zusätzlichen Metriken für leere Inline-Vorfahren. Vollständiges verschachteltes Inline-Box-Layout fehlt. `vertical-align` unterstützt nur baseline, super und sub, keine Längen oder top/middle/bottom. Der rohe DOM ist weiterhin kein Dirty-System.

## mark

Standard ist schwarzer Text auf gelbem Hintergrund, ohne zusätzliches Padding ([HTML-Defaults](https://html.spec.whatwg.org/multipage/rendering.html#phrasing-content-3)). `background`, `background-color` und `color` können das ändern; Hintergrundfarben akzeptieren auch transparent. Inline-Hintergrundflächen folgen den Wort-/Space-Frames. Zugehörige kollabierte Wortabstände erhalten wiederverwendbare Hintergrundframes; am Umbruch verschwinden diese Abstandsflächen. Erhaltene Leerzeichen werden über die vorhandenen Space-Frames gefärbt.

Grenzen: Hintergrundhöhe folgt der angenäherten nativen Fontbox. Verschachtelte Inline-Hintergründe verwenden die innerste sichtbare Farbe, keine vollständigen übereinanderliegenden CSS-Paint-Flächen. Inline-Rahmen/Margin/Padding fehlen.

## hr

Standard ist ein 1px-Inset-Rahmen, also 2px Gesamthöhe ohne Inhalt, graue Farbe, oben/unten 0.5em Margin und horizontale Zentrierung. `hr` bleibt ein Void-Element. Grundlage: [HTML-hr-Defaults](https://html.spec.whatwg.org/multipage/rendering.html#the-hr-element-2).

Die Engine zeichnet inset vereinfacht mit vier rechteckigen Kanten (oben/links Rahmenfarbe, unten/rechts weiß). solid verwendet weiterhin UIStroke. CSS-Breite, Rahmen, Padding und Margin überschreiben die Standards; explizites margin ersetzt auch die automatische Zentrierung. Keine vollständige browserabhängige 3D-Farbberechnung oder abgerundeten Inset-Kanten. Historische size/noshade/color/width-Attribute fehlen.

## text-align-last

Unterstützt auto, left, center, right, justify und start/end für LTR; wird vererbt. Es gilt am Blockende und vor festen Umbrüchen (br und erhaltene Quelltext-Zeilenumbrüche). Automatisch umgebrochene Zwischenzeilen folgen weiter text-align. auto übernimmt dessen Ausrichtung, bei justify links. justify dehnt vorhandene Wortabstände. Grundlage: [CSS Text](https://www.w3.org/TR/css-text-3/#text-align-last-property).

Kein RTL, match-parent oder vollständiger text-align-Shorthand-Reset. Zeilen ohne dehnbare Abstände bleiben bei justify links. Die dokumentierten pre-wrap-Endleerraum- und Tab/Blocksatz-Näherungen bleiben bestehen.

## small, code/pre und blockquote

`small` verwendet die vorhandene smaller-Regel (Elternschrift/1.2, mindestens 1px), bleibt auf der normalen Grundlinie und erbt line-height. Verschachtelung verkleinert erneut; Autor-CSS kann die Größe überschreiben.

`code` ist inline und verwendet Monospace; `pre` ist ein Block mit Monospace, white-space:pre und vertikalen 1em-Rändern. Die Engine bildet die generische CSS-Familie monospace auf die registrierte Roboto Mono ab. Browser können für monospace andere Schriften und Standardschriftgrößen wählen. Deshalb setzt die gemeinsame Demo code/pre ausdrücklich auf Roboto Mono und lädt diese Familie im kurzen Google-Fonts-Link mit allen vier verwendbaren Schnitten. Roboto Mono verwendet den bestätigten Größenfaktor 1,24 und eigene Linienformeln aus Messungen bei nativer TextSize 10–50. Zwischenwerte sind Näherungen; größere native Textgrößen werden extrapoliert.

Der Parser entfernt genau einen unmittelbar auf das pre-Starttag folgenden LF, auch nach CRLF-Normalisierung oder als numerische Zeichenreferenz. Ein Kommentar, Leerzeichen oder Kindtag davor verhindert diese Entfernung. Weitere Zeilenumbrüche und Leerzeichen bleiben erhalten. HTML innerhalb von code/pre wird weiterhin geparst: Tags für sichtbaren Code als &lt; und &gt; schreiben. Keine Syntaxhervorhebung, Codeausführung oder Auswertung des historischen pre-wrap-Attributs.

`blockquote` hat standardmäßig 40px Außenabstand links/rechts und 1em oben/unten. Offene obere/untere Ränder können mit Absatzrändern zusammenfallen, ebenso bei verschachtelten Zitaten. Rahmen, Padding und overflow:hidden verhindern den jeweiligen Zusammenfall. Autor-Margin überschreibt die Standards. cite wird nur im DOM gespeichert, nicht als sichtbare Quellenangabe ergänzt.

Grundlagen: [HTML-Darstellungsstandards](https://html.spec.whatwg.org/multipage/rendering.html#flow-content-3), [pre-Parserregel](https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inbody). Tests/SmallElements prüft zusätzlich kleinere Schrift, Monospace-Zuordnung, pre-Leerraum/Umbruch/CSS-Overrides, ersten LF, Zitatabstände einschließlich Padding/Verschachtelung und Resize ohne neue Messung.

## Einzelne Abstände und h3–h6

`margin-top/right/bottom/left` und `padding-top/right/bottom/left` akzeptieren je einen nichtnegativen px-Wert oder 0 auf Blöcken. Kurzformen setzen weiterhin alle vier Seiten; einzelne Seiten ändern nur ihre Seite. Reihenfolge, Spezifität, Inline-Vorrang und !important gelten gemeinsam für beide Schreibweisen. Ungültige Deklarationen verändern keine Seite. Die Arrays bleiben elementbezogen; andere Elemente und kompilierte Regeln werden nicht verändert.

Relative Standardränder von pre, blockquote, Listen, hr und den neuen Überschriften werden nach der finalen Schriftgröße berechnet und nur auf nicht überschriebenen Seiten ergänzt. Bei hr bleibt eine nicht überschriebene horizontale Auto-Seite wirksam. Explizites auto, negative Werte, Prozent-/em-Abstände, logische Seiten und Inline-Box-Abstände bleiben außerhalb des Teilumfangs.

Die neuen Überschriften sind standardmäßig fett. Größenfaktoren beziehen sich auf die Elternschrift, vertikale Ränder auf die eigene endgültige Schriftgröße:

| Element | Größenfaktor | Oberer/unterer Rand |
| --- | ---: | ---: |
| h3 | 1,17 | 1em |
| h4 | 1 | 1,33em |
| h5 | 0,83 | 1,67em |
| h6 | 0,67 | 2,33em |

Quelle: [HTML-Standard für Überschriften](https://html.spec.whatwg.org/multipage/rendering.html#sections-and-headings). CSS kann Größe, Gewicht und einzelne Ränder überschreiben. Mindestschriftgröße 1px wie bei smaller; die vorhandenen h1/h2-Defaults bleiben bestehen. Native Fontmetriken und Pixelraster können abweichen. Die Demo enthält je eine h3–h6 und eine Box mit allen acht Seitenangaben.

Tests prüfen beide Deklarationsreihenfolgen, !important, Spezifität, unveränderte Standardseiten, ungültige Werte, unabhängige Stile, relative Überschriften bei mehreren Elternschriftgrößen und CSS-Overrides. Layouttests prüfen geometrische Abstände, hr-Ausrichtung und Umbruch bei Resize ohne neue Wortmessungen. Native Sichtprüfung steht aus.

## Linienfarbe und Unterlinienabstand

`text-decoration-color` akzeptiert die vorhandenen benannten/Hex-Farben sowie `currentcolor` (Standard). Die Textfarbe bleibt erhalten. Die Eigenschaft selbst wird nicht vererbt; eine bereits vom Vorfahren erzeugte Linie behält ihre Ursprungsfarbe. Quelle: [CSS Text Decoration Color](https://www.w3.org/TR/css-text-decor-3/#text-decoration-color-property).

`text-underline-offset` akzeptiert `auto`, 0 sowie signierte px- und Prozentwerte. Es wird vererbt: px bleiben fest, Prozentwerte beziehen sich auf die Schriftgröße des Elements, das eine neue Linie erzeugt. Der berechnete Abstand einer bereits erzeugten Vorfahrenlinie bleibt erhalten. Bei horizontalem Text misst der explizite Wert ab der Grundlinie; positiv nach unten, negativ nach oben. Die Engine rundet auf ganze Pixel und verändert den Durchstrich nicht. `auto` verwendet weiterhin max(1, round(CSS-Größe / 14)). Quelle: [CSS Text Underline Offset](https://www.w3.org/TR/css-text-decor-4/#text-underline-offset-property).

Die unterstützte Kurzform `text-decoration` setzt ihre ausgelassenen Komponenten Farbe und Dicke auf currentcolor/auto zurück. Deshalb eigene Farbe/Dicke nach der Kurzform schreiben; !important und Spezifität gelten wie üblich. Der Offset gehört nicht zur Kurzform und bleibt erhalten. Farbe oder Offset allein erzeugen keine Linie.

Alpha-Farben einschließlich transparent sind inzwischen über CSS/Color unterstützt, auch innerhalb der text-decoration-Kurzform. `text-underline-position:under` legt die Linie unter die geschätzte Fontbox; `auto` und `from-font` verwenden die vorhandene Näherung. Skip-ink prüft zusätzlich die vertikale Überschneidung mit dem geschätzten Buchstabenbereich: von der x-Oberkante bis zur unteren p-Linie des aktuellen Wortfonts. Liegt die Unterlinie vollständig außerhalb, bleibt sie durchgehend. Die Linienstärke zählt zur Überschneidung; bloßes Berühren der Kante erzeugt keine Lücke. Bei unkalibrierten Fonts dient 0.3 × TextSize bis TextSize als Näherung. p/g/j/q/y teilen sich diese vertikale Näherung, Bold/Italic verwenden Regular-Guides; echte Glyphenkonturen fehlen. Dekorationen ändern weder Zeilenhöhe noch Wortmaße; ihr Überstand erweitert den Scrollbereich nicht automatisch. Native Sichtprüfung offen.

Die vorhandenen Linien-Frames werden wiederverwendet. Tests prüfen Defaults, currentcolor, Kurzform-Reihenfolge, !important, Vererbung, Prozentwerte bei anderer Schriftgröße, Ursprungsschutz, verschachtelte Linien, negative/ungültige Werte, Darstellung von Wortabständen, Umbruch und Wiederverwendung. Das gemeinsame HTML enthält eine farbige Unter-/Durchstreichung und einen Unterstrich mit 6px Abstand.

Die Höhenprüfung gilt pro Unterlinie und Wort, auch bei mehreren Linienursprüngen oder letter-spacing. Liegen alle Unterlinien außerhalb des Buchstabenbereichs, sind keine zusätzlichen Präfixmessungen nötig. Bereits berechnete horizontale Lücken bleiben gespeichert und werden beim Zurückverschieben wiederverwendet; überschüssige Frames werden ausgeblendet. Tests/SkipInk prüft die p-Unterkante, Linienstärke, Schriftgrößen/Fallback, verschachtelte Linien und Hin-/Zurückverschieben ohne erneute Messungen nach Aufbau des Caches. Das Offset-Beispiel enthält pgjqy zur Sichtprüfung.

## Linienarten (Prototyp zum Vergleich)

`text-decoration-style` unterstützt solid, double, dotted, dashed und wavy. Der Wert gehört zum Linienursprung und färbt/formt keine Vorfahrenlinie um. Die text-decoration-Kurzform akzeptiert Style und Farbe direkt, z.B. `underline wavy red`; ausgelassener Style wird auf solid zurückgesetzt. Details: [Erweiterte Kurzform](LIST-DECORATION-EXTENSIONS.md).

Solid und double verwenden Frames. Dotted, dashed und wavy werden einmal als weiße Alpha-Kacheln erzeugt, pro Seite/Style/Dicke geteilt und in ImageLabels eingefärbt und wiederholt. Die Phase bleibt über Wortabstände und Skip-ink-Lücken zusammenhängend. Beim Resize werden Positionen aktualisiert, keine Bildpixel neu gezeichnet. Beim Entfernen der Seite werden die EditableImages zerstört. Grundlage: [Roblox EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage) und [ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel).

Die Geometrie ist eine Näherung zur anschließenden Sichtprüfung: bei Dicke t hat dotted Periode 2t, dashed Periode 6t/Strichlänge 3t, wavy Periode 8t/Höhe 3t. Double hat zwei t-Striche mit t Abstand. Die Welle verwendet 4×4 Abdeckung pro Pixel für geglättete Ränder. Skip-ink prüft deren gesamte Höhe; bei double jeden Strich separat. Horizontale Lücken bleiben Buchstabenheuristik, keine echten Glyphenmasken. Muster beginnen am Blockkoordinatensystem, statt an jedem Dekorationsursprung neu zu starten. Zeilenhöhe und Scrollüberstand verhalten sich wie bisher.

Bildmuster unterstützen 1–32px Dicke, maximal 16 Kacheln und 65536 Bildpixel pro Seite. Bei fehlendem EditableImage-Zugriff, Allocation-/Schreibfehlern oder überschrittenen Grenzen erscheint eine Diagnose; die betroffene Darstellung nutzt solid. Roblox veröffentlicht Änderungen mehrerer angezeigter EditableImages über mehrere Frames, weshalb neue Muster kurz nacheinander sichtbar werden können. Keine laufenden Bildänderungen. Die gemeinsame Demo enthält eine Zeile pro Style bei 24px Text und 2px Strichstärke; native Sichtprüfung steht aus.

Tests/DecorationStyles prüft CSS-Reihenfolge/important/Ursprungsschutz, Alpha-Raster, geteilte Bilder, Grenzen, Fehlerbereinigung, Musterphase über Abstände/Lücken, Wiederverwendung beim Resize, double/Skip-ink und solid-Fallback. PageLifecycle prüft die Anbindung und einmalige Freigabe des Caches.

## Linienauswahl und Überstrich

`text-decoration-line` akzeptiert none oder eine Kombination aus underline, overline und line-through. Sie ändert nur die Linienauswahl. Farbe, Dicke und Muster bleiben erhalten, auch wenn zuerst none und danach eine andere Auswahl gesetzt wird. `text-decoration` akzeptiert dieselben Linien mit optionaler Farbe/Dicke/Style und setzt ausgelassene Komponenten zurück. Cascade und !important gelten gemeinsam für beide Schreibweisen. Ungültige oder doppelte Einträge werden vollständig ignoriert. Quelle: [CSS text-decoration-line](https://www.w3.org/TR/css-text-decor-3/#text-decoration-line-property).

Eine Linie behält Schriftmetriken und Darstellung ihres Ursprungs; none bei einem Nachfahren löscht keine Vorfahrenlinie. Overline verwendet die geschätzte obere Fontboxkante: relativ zur Grundlinie minus FontMetrics.Baseline des Ursprungs. Das ist eine Näherung der Font-Ascent-Position, keine gemessene Browser-Overline. Double und Wavy wachsen von dort nach oben; die vorhandenen Muster werden unverändert wiederverwendet. Overlines erhalten derzeit keine Glyphenlücken; Skip-ink gilt weiterhin für Unterlinien. Maße, Zeilenhöhe und Scrollbereich bleiben unverändert.

Der Nutzer hat die bisherigen fünf Muster im Sichtvergleich bestätigt. Die neue Overline-Höhe steht noch zum Vergleich aus. Das gemeinsame HTML enthält einen einfachen Überstrich und eine farbige Wellenkombination über und unter dem Text; Letztere setzt Farbe/Style/Dicke absichtlich vor der Longhand, um deren Erhalt sichtbar zu prüfen. Tests ergänzen CSS-Reihenfolge/important, Kombinationen/none/Invalid, Ursprungsmetriken, alle fünf Overline-Muster und Resize ohne neue Frames oder Wortmessungen.

## Prüfung

`tests/SmallElements.luau` prüft Größen und Versätze, zusammenhängende Formeln, Verschachtelung, CSS-Overrides, Hintergrundflächen inklusive Leerzeichen/Umbruch, letzte Zeilen und br, hr-Ränder/Zentrierung sowie Mess- und Instanzwiederverwendung. Die bisherigen Tests für Wortstile prüfen jetzt die Fragmentdarstellung statt der früheren Erststil-Diagnose. Die vollständige Demo bleibt zwischen HTML und Luau synchronisiert.
