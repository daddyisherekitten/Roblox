# CSS Atelier: Roblox-Vergleich und Ausbauprofil

## Positionierte Transparenzebenen und Animationen – 13. Oktober 2026

Die [seit dem 16. Oktober archivierte Bewegungsseite](../tests/fixtures/retired-window-pages-20261016.json)
zeigt bei `replace` und 50 % dieselbe Transformation für Basis und Ergebnis.
Das [gemeldete Roblox-Bild](../tests/fixtures/motion-initial-position-reference.png)
zeigte das Ergebnis jedoch um 22 px nach links und 50 px nach oben versetzt.
Die Animationsrechnung war in diesem Fall korrekt; der zusätzliche
Transparenz-Compositor lag am falschen Ursprung.

`PositionedLayout` hält Mess-/Flowkoordinaten und endgültige Zeichenkoordinaten
getrennt. Für ein absolut positioniertes Element kann `LayoutX/Y` weiterhin
`0,0` sein, während `PaintX/Y` bereits die verwendeten Insets enthält.
`GroupOpacity.arrange` verwendet jetzt beim Platzieren des Compositors die
Zeichenkoordinaten; explizite Top-Layer-Koordinaten behalten Vorrang. Auch die
Vereinigung ungeclippter Kindflächen verwendet deren Zeichenposition, damit
positionierter Überlauf innerhalb einer Transparenzebene berücksichtigt wird.
Die innere GUI bleibt bei `0,0`; vorhandene Transformations-, Drehpunkt- und
Viewportpfade arbeiten danach auf dem korrekt platzierten äußeren Compositor.
Dies ist eine allgemeine Korrektur, ohne Werte aus der Beispielseite im Renderer.

Der Pfad wurde von Parser/Cascade über PositionedLayout, Compositor-Fit,
BoxTransform und CSS-/JS-Animationspublikation verfolgt. Die ursprüngliche
Vergleichsregression hatte vor dem Skript bereits gelayoutet und prüfte keine
native Lage des Ergebnisses. Sie erstellt den Effekt jetzt vor dem ersten Layout,
startet den tatsächlichen CSS-Motion-Runtime und prüft die GUI-Position.
`AnimationPositionedOpacity` vergleicht zusätzlich vier tatsächlich gezeichnete
GUI-Ecken gegen Chromium: 48 Fälle, jeweils fünf Zeiten vor und nach Resize.
Abgedeckt sind negative und prozentuale Insets, `calc`, right/bottom, relative
und normale Flowpositionen, verschachtelte Transparenz, Überlauf, Schatten,
andere Transformationszahlen, Drehpunkte, Rotation, replace/add/accumulate und
ein erstmals durch den Effekt erzeugter Compositor. GUI-Identität, pausierter
Framebedarf, Cancel und Ressourcenabbau werden ebenfalls geprüft.

Browsergrenze, ausdrücklich getrennt: Chromium 155 verliert bei
`accumulate` die prozentuale Translation, wenn die Transformationslisten
verschiedene primitive Reihenfolgen haben. Die unveränderten Rohwerte bleiben
in der [nativen Referenz](../tests/fixtures/animation-positioned-opacity-browser.json).
Für genau diesen Fall verwendet die Engine die Vorschrift aus
[CSS Transforms 2](https://drafts.csswg.org/css-transforms-2/#combining-transform-lists)
und erhält die Translation. Ein unabhängig aufgenommener Pixelvergleich
belegt die Äquivalenz: bei der unveränderten 150-px-Breite sind 12 % = 18 px,
−10 % = −15 px und 40 % = 60 px. Der Prüfer zählt daher **470 direkte native
Zustände und 10 getrennte normative Pixeläquivalente**. Diese Ausnahme ist
benannt; die ursprünglichen 33-/42-Fall-Aufnahmen wurden bytegleich gesichert
und ihre CSS-, Script- und Ergebniswerte nicht überschrieben.

Der alte Compositor scheitert mit dem unveränderten neuen Test bereits am
ersten 50-%-Zustand: x=21,6 statt x=43,6
(`build/motion-positioned-opacity-original-full16.log`). Der korrigierte Stand
besteht alle 480 Zustände (`motion-positioned-opacity-final-cases-full16.log`)
und den ursprünglichen Elf-Suiten-Nachbarschaftslauf
(`motion-positioned-opacity-neighbors-full16.log`). Beide grünen Nachweise haben
tatsächlichen Exit 0. Der abschließende gemeinsame Lauf besteht ebenfalls:
13 Suiten in `build/motion-positioned-opacity-final-review-full16.log` mit
tatsächlichem Exit 0, einschließlich CSS-/JS-Layoutanimationen, Commit,
Transform-/3D-/Inlinepfaden, Top Layer, Compositing und Seitenaufbau.
Statische Prüfung und Rojo-Build sind grün
(`motion-positioned-opacity-static-full16.log`,
`motion-positioned-opacity-rojo-full16.log`): 1183 Luau-, 215 JS-, 52 Python-
und 122 HTML-Dateien, 454 lokale Referenzen, sieben Rojo-Projekte und 126
Fontzuordnungen. Dies belegt keinen vollständigen CSS-/Browserabschluss,
Gesamtpass aller 420 Suiten oder Studio-Pixel-/FPS-Nachweis.

Stand des Ausbauprofils: 7./8. Oktober 2026. Die 35 Standard-HTML/CSS/JavaScript-
Beispiele aus neun Bereichen sind seit dem 8. Oktober aus dem Website-Katalog
entfernt und unter `tests/fixtures/css-atelier` unverändert archiviert.
Enginefunktionen und Regressionen bleiben bestehen. Studio startet jetzt
`Bytebude`; Bedienung und Quellen: [WEBSITES](WEBSITES.md).

Dieses Profil hält die Erweiterungen und ihre konkreten Grenzen fest. Es erklärt
weder die gesamte CSS-Spezifikation noch alle technisch umsetzbaren Restfälle für
abgeschlossen. Das einzige vollständige, datierte Namensregister bleibt
[css-features.v1.json](css-features.v1.json); die übergreifende Navigation bleibt
[CSS-COMPLETION](CSS-COMPLETION.md). Native Optik und FPS beurteilt Tobias.

## Was in diesem Durchgang ergänzt wurde

### Korrektur am 8. Oktober: geöffnete Details

Die Regel `.open-demo[open] { background:#e5ecff }` der unveränderten
Vergleichsseite wurde bei nativer Summary-Aktivierung nicht neu ausgewertet.
Der bisherige Controller schaltete nur Inhalt, Pfeil und Layout um. Jetzt
laufen native Aktivierung und JavaScript-Schreibvorgänge an `details.open`
durch die Attribut-/Kaskadenaktualisierung. `[open]`, `:open`, abhängige
Nachfahren, Geschwister und `:has`-Vorfahren erhalten ihre Styles; tatsächliche
Geometrieänderungen liefern lokale Dirty-Ziele. Vorhandene Karte und Editoren
bleiben erhalten. Während laufender Layoutjobs wird die Veröffentlichung
aufgeschoben; ohne JavaScript bleibt der native Bedienpfad verfügbar.

`tests/Details.luau` prüft Maus, Tastatur, Touch, Reflexion/Boolean-Präsenz,
MutationObserver-Records, Stilrücksetzung, verwandte Geometrieziele,
Teil-/Voll-Layoutgleichheit und sichere Warteschlangen bei Layoutabbruch.
`tests/CSSAtelierWebsite.luau` prüft zusätzlich den blauen Hintergrund und
seine Rücksetzung auf der tatsächlich gelieferten Seite mit Mock-GUIs.
Native Studio-Pixelgleichheit bleibt vom Benutzer zu bestätigen.
Dies ist ein begrenzter Nachweis für `open`, kein Abschluss sämtlicher
Details-Regeln: Namensgruppen-Exklusivität und zusammengefasste `toggle`-Tasks
sind in diesem Fix nicht ergänzt worden. Normative Grundlage:
[HTML Details](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-details-element).

### Korrektur am 8. Oktober: Aufklappen und äußeres Thema

Die beiden gemeldeten starken Ruckler hatten zusätzliche globale CSS-Arbeit:
Das Aufklappen und die äußere Themenklasse lösten je 791 gewöhnliche Stil-
und 2.138 Pseudoprüfungen aus. Klassen-/Attributänderungen werden nun anhand
ihrer Selektorabhängigkeiten konservativ begrenzt. Relationale, Filter-, Scope-
und fremde Slot-Abhängigkeiten behalten die umfassende Prüfung; relevante
Shadow-Parts und vererbte Variablen werden weiter aktualisiert.

Auf der gelieferten Seite benötigt das Öffnen 29/12 Stil-/Pseudoprüfungen und
ein Teil-Layout mit 165 Aufrufen sowie 266 Cache-Treffern. Der äußere Theme-
Klick benötigt 34/30 Prüfungen, keine Stylesheet-Neusammlung und kein Layout;
Flächen und Dirty-Ownership bleiben erhalten. Farben und Rahmen werden in
beiden Richtungen geprüft. Unabhängige Vollaufbauvergleiche sichern zusätzliche
Klassenkombinationen ab. [Ursache, Pfade und Nachweisgrenzen](LOADING-PERFORMANCE.md).
Native Ruckelfreiheit ist noch vom Benutzer zu bestätigen.

### Korrektur am 8. Oktober: Bild und Text im Query-Grid

Bei 423 px angeforderter Kartenbreite waren die zwei Spalten bereits aktiv,
aber das Bild drückte den Text rechts aus dem Rahmen. Der gemeinsame Grid-
Pfad verwendete die durch `min-height:230px` und das natürliche Bildverhältnis
erhöhte intrinsische Mindestbreite ohne die Begrenzung für prozentuale
bevorzugte/Maximalbreiten. Compressible Replaced Elements begrenzen diesen
Grid-Beitrag jetzt mit der zyklisch gegen null aufgelösten Breite; ausdrücklich
gesetzte Mindestbreiten, Boxkanten und Margins bleiben berücksichtigt.
Andere Controls behalten ihre eigenen Mindestmaße. Der normale intrinsische
Bildpfad mit übertragenen Mindesthöhen bleibt erhalten.

Grid-Stretch-Hinweise überschreiben bei ersetzten Elementen außerdem keine
ausdrücklich gesetzte Längen-/Prozentachse mehr. Prozent-/`calc()`-Maße lösen sich gegen die
aktuelle Grid-Zelle auf. Das beseitigt auch den unabhängig gemessenen Fall
`width:calc(100% + 20px)`, der vorher auf die Spaltenbreite gekürzt wurde.
Intrinsische Größenkeywords behalten den vorhandenen Pfad und seine Grenzen.

Ein unabhängiger Chromium-Aufbau derselben gelieferten Seite misst bei 423 px
Gesamtbreite einen 421-px-Inhaltscontainer, 36 px Innenabstand und 22 px Gap:
Bild und Text belegen je **181,5 px**. Bei 560/600 px sind es 250/270 px je
Spalte. Die Regel `(width > 420px)` bleibt bei 422 px Gesamtbreite inaktiv,
weil die zwei Rahmenpixel nicht zum abgefragten Inhaltsmaß gehören.

`CSSAtelierWebsite` prüft neun aufeinanderfolgende Regleränderungen über diese
Grenze, Spalten-/Bild-/Textmaße, Positionen innerhalb der Karte, Stapelung,
Mindesthöhe und behaltene GUI-Identität. `CyclicImageSizing` prüft elf native
Grid-Referenzen mit fr/min-content/minmax, Prozent-/Maximal-/calc-Breiten,
explizitem Minimum, Overflow und Auto-/Prozent-/Pixelhöhe, jeweils mit
wiederholtem Resize; die früheren allgemeinen Intrinsic-Proben bleiben aktiv.
Browsermessung: `build/grid-image-native-results.json`, reproduzierbarer lokaler
Probe-Runner: `build/grid-image-reference.cjs`. Vollständige Regression:
261 Suiten in `build/css-atelier-grid-image-full-review.log`; nach der finalen
Begrenzung der Stretch-Korrektur auf Längen-/Prozentachsen bestanden erneut
Grid, CyclicImageSizing, CSSAtelierWebsite, TemporalInputs, Forms und
MemoryRendering in `build/css-atelier-grid-image-final-review.log`.
Projektprüfung und Rojo-Build `build/css-atelier-grid-image-review.rbxlx`
bestanden; das CSS-Register erhielt nur aktualisierte Codepositionen.
Native Studio-Darstellung bleibt
vom Benutzer zu bestätigen. Normative Grundlage:
[CSS Grid 2, automatische Mindestgröße](https://drafts.csswg.org/css-grid-2/#min-size-auto).

### Korrektur am 8. Oktober: gemeinsame Kartenzeilen

Die drei Produktkarten verwenden `grid-row:span 3` mit Zeilen-Subgrid. Der
intrinsische Höhenprobe-Pfad übernahm bisher die bereits gestreckten Zeilen
des vorherigen Layouts und addierte erneut die Kartenkanten. Zudem wurde die
gesamte Kartenhöhe auf die drei Elternzeilen verteilt. Damit wuchsen Karten
und Abstände, statt die einzelnen Überschriften/Beschreibungen/Links zu messen.

`GridLayout` übergibt für die Probe nun nur Zeilenanzahl und Namen, keine alten
Pixelhöhen. Die einzelnen Inhaltsbeiträge werden auch durch verschachtelte
Zeilen-Subgrids an die entsprechenden Elternzeilen weitergegeben. `GridTracks`
berücksichtigt Rahmen, Padding/Margins und die halbe Differenz der Gutters;
`normal` erbt den Abstand der jeweiligen Achse, explizites `row-gap:0` bleibt null.
Die endgültige gemeinsame Zeile wird anschließend in die Inhaltsbox eingepasst.

Unabhängige Chromium-Referenz: die feste Drei-Karten-Probe hat 160 px Höhe,
Elternzeilen von 62/28/34 px und Inhaltspositionen 23/79/125 px. Normale,
null und 30-px-Zeilenabstände ergeben 164/128/188 px. Weitere Referenzen
decken verschachtelte Subgrids, Spans, leere Randzeilen, leere Subgrids und
Spalten mit Padding/abweichenden Gutters ab. `Grid` prüft diese Geometrien,
wiederholtes Resize, Höhenänderung/Rücknahme im Teil-Layout und GUI-Identität.
`CSSAtelierWebsite` prüft die echte Drei-Karten-Gruppe und die schmale Stapelung
mit stabiler Höhe bei Rückkehr zur ursprünglichen Breite. Messung/Runner:
`build/subgrid-native-results.json`, `build/subgrid-reference.cjs`.
Gezieltes Protokoll: `build/css-atelier-subgrid-focused.log`.
Alle 261 registrierten HTML-Suiten bestanden anschließend in
`build/css-atelier-subgrid-full-review.log`.

Dies schließt die gemeldete Zeileninflation, nicht alle Subgrid-Kombinationen.
Insbesondere vollständige Baseline-Introspektion, beliebige intrinsische
Spalten-Subgrids und orthogonale Schreibmodi benötigen weitere Referenzfälle.
Native Studio-Pixelgleichheit bleibt vom Benutzer zu bestätigen. Grundlage:
[CSS Grid 2, Subgrids](https://drafts.csswg.org/css-grid-2/#subgrids).

### Korrektur am 8. Oktober: Bildeffekte und Mischflächen

HTML-`img` aus lokalen SVG-Quellen verwendet nun dieselbe erfasste Pixelkette
für Filter, echten Alpha-Ausschnitt und Maske: Filter zuerst, dann `clip-path`,
dann `mask`/`mask-border`. Blur erhält transparente Überstände, ohne die
Layoutmaße zu verändern. Die Effektfläche bleibt bei Reglerwechseln erhalten;
geänderte Jobs werden zusammengefasst, veraltete Ergebnisse nicht veröffentlicht.
`none`, Resize, Cache und Ressourcenabbau sind geprüft. Die drei tatsächlichen
Atelier-Controls behalten die Bildgeometrie; eine geänderte Beschriftung darf
weiterhin ihren eigenen Textlayoutpfad benötigen.

`mix-blend-mode` verändert keine berechneten CSS-Farben mehr. Ein begrenzter
Compositor verrechnet die tatsächlichen überlappenden Paintflächen einschließlich
Hintergrund und Alpha innerhalb der unterstützten Gruppe. Absolute Kinder werden
an ihren Paintpositionen aufgenommen; ihre Flussposition darf nicht beide Kreise
auf denselben Ursprung legen. Die Ersatzfläche bleibt erhalten, native GUI-Flächen
werden transparent und behalten Eingabe/Fokus. Die Gruppe wird budgetiert und
auf höchstens 512 Pixel pro Achse gerastert; der sichtbare Erstaufbau wartet auf
die fertige Fläche, späterer Resize blendet die Seite nicht erneut aus.

`HTMLMixBlending` vergleicht acht Chromium-Pixelreferenzen für `normal`,
`multiply`, `screen` und `difference`, jeweils mit voller/halber Deckkraft;
geprüft sind Überlappung, beide einzelnen Kreise, Hintergrund, Isolation,
Rücksetzung, schnelle Änderungen, Resize und Abbau.
Auch während einer bestehenden Komposition neu transparent gewordene
Hintergründe bleiben nach Rückkehr zu `normal` transparent. Gesicherte native
Paintwerte werden vor dem Author-Paint wiederhergestellt, damit die Rücksetzung
keine alte Farbe/Deckkraft veröffentlicht. Prüfung:
`build/css-atelier-blend-restoration-review.log`.
`SVGHTMLEffects` prüft echte Bildpixel, die 40%-Maskenposition, Blur-Überstand,
Kombinationsreihenfolge und das ausgelieferte Atelier-SVG.

Dies bleibt ein CPU-Paintprofil. Gruppen mit nicht lesbaren nativen Bild-/Video-/
Controlpixeln, Transformationen oder mehr als 64 Boxen behalten diagnostiziert
die native Darstellung. Beliebige Stacking-/Overflow-/Masken-/Filterkombinationen
und Originalschriften in Rasterflächen sind weiterhin nicht vollständig.
Grundlagen: [Compositing](https://www.w3.org/TR/compositing-1/),
[Masking-Reihenfolge](https://www.w3.org/TR/css-masking-1/#Module-Interactions).

### Korrektur am 8. Oktober: Button-Inhalt und Transformakkumulation

Ein `<button>` mit Elementkindern erzeugt nun deren eigene DOM-/Layout-/Paintboxen
statt einer zusammengefassten Controlbeschriftung. Dadurch erreichen beide
absoluten Flip-Flächen einschließlich Flexinhalt, Schriftgrößen, Farben und
`backface-visibility` den vorhandenen 3D-Szenenpfad. Controlzustand, disabled-
Aktivierung, Formularzugehörigkeit und native Eingabefläche bleiben erhalten.
Bestehende einfache Textbuttons verwenden weiter ihren bisherigen Controlpfad.
Dynamische Änderungen eines bereits so gerenderten Buttons benutzen den normalen
DOM-Abgleich. Das ist kein Vollständigkeitsnachweis aller UA-Buttonformatierungen
oder der nachträglichen Umwandlung eines einfachen Captionbuttons.
Horizontale Margins gestalteter Inlinekinder erhalten wie Padding/Rahmen eine
gemessene atomare Box; so verschwindet Fernwehs innerer 7px-Abstand nicht mehr.
Mehrzeilige Fragmentierung aller solcher Inlinekombinationen bleibt offen.

`add` hängt Transformationslisten aneinander; `accumulate` gleicht entsprechende
Funktionen ab, ergänzt Identitäten für die kürzere Liste und zerlegt nur einen
nicht passenden Rest in Matrizen. Die gemeinsame Implementierung dient CSS-
Animationen, Web Animations und Iterationsakkumulation. Skalierung wird um eins
akkumuliert, Matrixrotationen über Quaternionen, Perspektive über ihre inverse
Distanz. Eine fehlgeschlagene Matrixzerlegung verwendet den Effektwert.
Das Atelier-Beispiel bewegt `add` in der gedrehten Achse; `accumulate` bleibt
horizontal. Eine unabhängige Chromium-Referenz mit 30 Matrixwert-Sätzen deckt
auch Prozentwerte, ungleiche Listen, Achsen, Skew, Perspektive und singuläre
Matrizen ab: `tests/fixtures/transform-composition-native.json`.

`ThreeDTransforms` prüft diese Referenz sowie die sichtbaren Farben beider
210px-Buttonseiten bei wiederholtem Wenden und behaltenen GUIs/Controlzuständen.
`CSSAtelierWebsite` führt den tatsächlichen Buttoncallback und disabled-Click
aus. CSS- und WAAPI-Richtung sind zusätzlich über beide Laufzeitpfade geprüft.
Native Schrift-/Rasterdarstellung in Studio muss Tobias weiterhin vergleichen.
Normative Grundlage: [Transformationslisten](https://www.w3.org/TR/css-transforms-2/#combining-transform-lists).
Gezielte Prüfung: `build/css-atelier-flip-accumulate-final.log`;
Spiel-/Controlregression: `build/css-atelier-flip-composition-checks.log`.
Fernweh und Inline-Abstände: `build/css-atelier-rich-button-spacing-review.log`
und `build/css-atelier-inline-spacing-check.log`.

| Bereich / sichtbarer Vergleich | Gemeinsamer Ausführungspfad und Umfang | Weiter offen oder angenähert |
| --- | --- | --- |
| Kaskade, Variablen, Imports, Namespaces | Escape-/Unicode-Bezeichner für Selektoren, Deklarationen und Variablen; lokale Imports mit eigenen Namespaces, URL-Bezug, Bedingungen, Layern und Zyklus-/Arbeitsbudgets; `revert` zum vorhandenen UA-Profil und `revert-layer` mit Prioritäts-/Inline-Kontext; ungültige Variablenergebnisse fallen auf `unset` zurück. HTML-Selektoren erreichen auch SVG-Paint. | Vollständige CSS-Tokenisierung/Fehlerkorrektur, eigene User-Stylesheet-Ursprünge, alle Shorthand-/logischen Rollback-Kombinationen und Shadow-/SVG-Kaskadenfälle. Rollback nutzt begrenzte, zwischengespeicherte niedrigere Stilauflösungen; fontrelative Komponenten mit gleichzeitig wechselnder Basis brauchen weitere Referenzfälle. |
| Selektoren | `nth-child`/`nth-last-child(... of ...)` mit gefilterten Geschwistern, Spezifität und Mutation; Sprache/Richtung; Link-, Ziel-, Offen-, Defined-, Required-/Optional- und User-Valid-Zustände. Bestehende Shadow-/Part-/Slot-Pfade bleiben erhalten. | Erweiterte Sprach-Wildcards, vollständige Pseudo-/Namespace-Grammatik und alle kombinatorischen Invalidierungsfälle. `:visited` erhält keine erfundene Browserhistorie und matcht im aktuellen Profil nicht. |
| Maße und responsive Regeln | 96-dpi-Absolutlängen; zusätzliche Font-, Rootfont-, `sv*`/`lv*`/`dv*`- und `cq*`-Einheiten im gemeinsamen Längenparser; boolesche, Bereichs- und verkettete Mediaqueries; nächster geeigneter benannter Größencontainer und Inhaltsbreite als Einheitbasis. | Nicht bereitgestellte Fontmetriken werden geschätzt; alle dynamischen Viewportvarianten fallen ohne Hostwerte auf den verfügbaren Viewport zurück. Weitere Medienmerkmale, Style-/Scroll-State-Containerqueries, vollständige logische Abhängigkeiten und Zyklen. |
| Text und Schriften | Tabellarische/proportionale Ziffern; `::first-letter` mit horizontalem Initial-Letter-Float, Sink und kalibriertem Größenbezug; originale UTF-16-Quellen bleiben für Auswahl/Highlights erhalten. `text-box-trim`/`text-box-edge` für horizontale Wortruns; zusätzliche Inline-Ausrichtung ohne doppelte Behandlung ersetzter Bilder. | Initial-/Trimmetriken sind kalibriert oder geschätzt. Absatz-/Fragmentregeln, mehrteilige Anfangszeichen über DOM-Grenzen, komplexe Inlineboxen, vollständige Bidi-/Vertikalschreibung, Glyphenformung und alle OpenType-Familien sind nicht browsergleich. Arbiträre lokale variable TTF-Dateien werden nicht als native Roblox-Fonts ausgegeben. |
| Layout | Vorhandene Grid-/Subgrid-, Flex-, Float-/Shape- und Table-/Span-Pfade auf der echten Seite zusammengeführt; zusätzliche intrinsische Blockbreiten; prozentuales `max-height`. Containeränderungen und Seiten-Resize erhalten geprüfte GUI-Identitäten. | Min-/Max-/Fit-Content in allen Formatierungskontexten, Prozentzyklen, Fragmentierung und alle Baseline-/Subgrid-Kombinationen. Dies sind weiter umsetzbare Layoutarbeiten, keine Hostverbote. |
| Bilder, Farben, Effekte | `oklab()`/`oklch()` und `color-mix()` in sRGB, linearem sRGB, OKLab/OKLCH mit Alpha/Hue-Pfaden; `image-set()`-Quellwahl nach Dichte/Typ; lokale SVG-Hintergründe über die budgetierte Rasterwarteschlange, Cache und sichtbaren Ladezustand. Gemeinsame HTML-Stylesheet-Regeln für Inline-SVG mit zustandsabhängigen Cachekeys; bestehende Hover-Vorbereitung bleibt erhalten. HTML-SVG-Bilder erhalten die Pixel-Filterkette einschließlich Blur, Clip und Masken. Unterstützte HTML-Paintgruppen verrechnen echte Überlappungen für Mischmodi. Gestaltete Buttonkinder erreichen den vorhandenen 3D-Pfad. | Ausgabe begrenzt auf sRGB/Color3; einfaches Gamut-Clipping. Die gesamte Bildgrammatik und alle image-set-Verbraucher fehlen. Vollständige Masken/Filter/Blend/3D-Kombinationen bleiben gemäß [Darstellungsgrenzen](CSS-VISUAL-LIMITS.md) begrenzt; CPU-Rasterung ersetzt keinen beliebigen nativen GUI-Snapshot. |
| Eingabe und Scrolling | Vorhandene Controls, Fokus, Sticky und Snap; anonyme `scroll()`/`view()`-Timelines mit Bereichen; Scrollsignale gemeinsam abonnieren und entsorgen, keine zusätzliche dauernde Frameloop. Anchor-Inset/-Size mit Mathe/Fallback, Scope und benannten/gespiegelten Fallbackregeln im [Ankerprofil](#ankerpositionierung--9-oktober-2026). | Benannte View-Timelines, komplexe Range-/Timingfälle, dynamische Scroll-Owner-Wechsel, übrige Anker-/Position-Area-/Scrollkombinationen, komplette Forced-Colors-/Zoom-/native Pickerdarstellung. |
| Animationen | Numerische Höhe ↔ gemessene natürliche Höhe bei `interpolate-size:allow-keywords`, Umkehr und Rückgabe des intrinsischen Endwerts; vorhandene Easing-/Kompositionspfade und Web Animations. Gemeinsame Transformaddition/-akkumulation mit Identitätsergänzung und Matrixrest; CSS und WAAPI gegen Browserreferenzen geprüft. Standard-Prototypezugänge erreichen denselben Backendpfad. | Intrinsische Größen in beliebigen WAAPI/Keyframe-Effekten, Interpolation jeder Eigenschaft, vollständige Akkumulation/Iteration aller Eigenschaftstypen und alle wechselnden Basiswerte. |
| CSSOM / Typed OM / Highlights | CSSOM-Regeln werden bei Bedarf materialisiert. `CSS.supports`/`CSS.escape`; skalare `CSSUnitValue`/`CSSKeywordValue`, kompatible Einheitenkonversion, lebende `attributeStyleMap`, read-only `computedStyleMap`, atomare Schreibvorgänge und Iteration. `Highlight`/`HighlightRegistry` mit Range-Sets, Priorität, lebender Registry und reiner Paintdarstellung; getrennte/überlappende Fragmente erhalten Text-/GUI-/Auswahlidentität und werden entfernt. | Vollständige Typed-OM-Math-/Transform-/Unparsed-/Variablenklassen, alle CSSOM-Regeltypen und Highlight-Vererbungs-/Fehlermarkierungsfälle. View-Transition-Snapshots und Worklets besitzen aktuell keinen Host. |

Die unterstützten Profile greifen auf Parser, Stilauflösung, Layout, Paint und
Lifecycle zu. Es gibt keine Spezialimplementierung einer Atelier-Karte in der
Engine. `CSS.supports` und die APIanzeigen belegen konkrete Verfügbarkeit;
sie versprechen weder alle Werte einer Eigenschaft noch Pixelgleichheit.

## Native Grenzen, Annäherungen und umsetzbare Restarbeit

| Einordnung | Fälle | Konsequenz |
| --- | --- | --- |
| Nicht direkt mit dem vorhandenen Roblox-Host verfügbar | Browserartige Originalpixel/Snapshots eines beliebigen nativen GUI-Unterbaums; browserinterne GPU-Compositor-/Paint-Worklet-Threads; beliebige lokale Webfontdateien mit frei einstellbaren Variationsachsen und sämtlichen Shapingmetriken; native Wide-Gamut-/HDR-Ausgabe; OS-Picker/-Forced-Colors/-Browsertoolbar-Metriken. | Keine APIpräsenz oder exakte Darstellung vortäuschen. Die Variable-Font-Karte meldet fehlende Schrift; Worklet-Karte bleibt neutral; View-Transition-Karte führt ihren gewöhnlichen DOM-/Bildwechsel aus. |
| Annäherung möglich, bereits vorhanden oder weiterer Host erforderlich | CPU-Rastereffekte, Schatten/Masken/3D, Schriftmetriken/Bidi/vertikale Runpositionen, nachgebaute Controls, kontrollierte Snapshot-Raster und kooperative Worklet-Ausführung. | Begrenzte Profile dokumentieren; Aufwand, Rasterbudgets und Abweichungen benennen. Ein eingeschränkter Worklet-/Snapshot-Host wäre zusätzliche Implementierung und ist nicht grundsätzlich unmöglich. |
| Weiter umsetzbar, noch offen | Die Restspalte oben: Parser-/Kaskadenrandfälle, zusätzliche Query-/Layout-/Animations-/CSSOM-/Typed-OM-Semantik und Kombinationen. | Im bestehenden Register und Fachprofil als offen erhalten. Weder Zeitaufwand noch eine fehlende Implementierung sind Gründe für die Kategorie „unmöglich“. |
| Separater Bedarf | Print/Seitenfragmentierung, Speech, Legacy-/herstellerspezifische Regeln und unfertige Layoutentwürfe. | Im datierten Register auffindbar; für diese Bildschirmvergleichsseite kein behaupteter Abschluss. |

## Seite und Ressourcen

Die archivierten Originalquellen sind [HTML](../tests/fixtures/css-atelier/index.html),
[CSS](../tests/fixtures/css-atelier/styles.css) und
[JavaScript](../tests/fixtures/css-atelier/app.js). Der Generator verpackt
`tokens.css`, `namespaces.css` und vier lokale SVG-Dateien sowie das getrennte
JavaScript-Modul. Der CSS-Importkontext bleibt erhalten. `paint.js` und die lokale
variable Roboto-Datei bleiben Browserressourcen und werden ohne passenden
Roblox-Host nicht als native Umsetzung angekündigt.

```powershell
# Historischer Generatoraufruf vor der Archivierung:
# python scripts/sync-website.py css-atelier CSSAtelier "CSS Atelier"
```

Kein Framework und kein Präprozessor. Die Kapitelinitialisierung verteilt sich
über reguläre Tasks, statt das JavaScript-Instruktionsbudget zu erhöhen.
Die vorhandene blanke Ladefläche und die Rasterwarteschlangen bleiben aktiv;
späterer Resize blendet die Seite nicht erneut aus.

## Nachweise und Bewertungsgrenze

Nach dem nativen Studio-Timeout beim Start wurde der Ladepfad am selben Tag
nachgebessert: einzelne kalte Imports pausieren zwingend; große CSS-Blöcke
nutzen den Ladescope; Startphasen und der längste Modulaufruf werden gemessen.
[Details und verbleibende native Unsicherheit](LOADING-PERFORMANCE.md).
Für diesen Folgestand bestanden zwölf gezielte HTML-Suites, die funktionale
SVG-Regression, die Auswahlprüfung, die Projektprüfung und der Rojo-Build.
Das vollständige 261-Suite-Protokoll unten gehört zum vorherigen Ausbau;
die gezielte Folgeprüfung steht in `build/css-atelier-startup-review.log`.

- `CSSAtelierCore`: Escapes/Unicode und tatsächliche deklarierte Längenfelder,
  gefilterte Selektoren/Spezifität/Mutation, Sprachen, Richtung, Namespaces,
  Bereichs-/Booleanqueries und physische/logische Einheitachsen.
- `CSSAtelierWebsite`: echtes ausgeliefertes HTML/CSS/JavaScript über DOM,
  Formmodell, CSSOM und Renderer; Initialisierung und VM-Budget, Layer-Rücknahme,
  ungültige Variablen, Inhaltscontainer, Initial-Quellgrenzen, SVG-Namespace,
  CSSOM/Typed-OM-Schreibvorgänge, Highlights, Fallback, Resize und GUI-Identität.
- `JavaScriptTypedOM`, `CSSScrollViews`, `CSSLayoutAnimations` und `Positioning`:
  APIbrands/Fehler/Iteration, Viewprogress und Signalabbau, intrinsische
  Höhenumkehr und Anchor-Fallback.
- `scripts/test-script-selection.cjs`: echte Auswahl-/Highlight-Paintpfade,
  disjunkte Fragmente, Rangwechsel, originale GUI-Identität und Abbau.
- Gesamte HTML-Regression: **261 registrierte Suites bestanden**, einschließlich
  der isolierten GC-/Lifecycle-Prüfungen; Protokoll
  `build/css-atelier-html-review.log`.
- Gesamte SVG-Regression einschließlich Cache-/Queue-/Rasterprüfungen bestanden;
  Protokoll `build/css-atelier-svg-review.log`. Die getrennte funktionale Prüfung
  steht zusätzlich unter `build/css-atelier-svg-final.log`.
- Generator: fünf Prüfungen bestanden, einschließlich unveränderter lokaler
  Importquellen und Abbruch vor partiellen Schreibvorgängen. Projektprüfung,
  API-/CSS-Registerabgleich und Rojo-Build erfolgreich; Build unter
  `build/css-atelier-review.rbxlx`. Rojo und Webserver antworten auf ihren
  vorgesehenen Ports. Diese automatischen Prüfungen verwenden für native
  GUI-/Fontdienste Ersatzobjekte und beweisen keine Studio-Pixelgleichheit.

Die automatische Browser-Sichtprüfung war wegen eines lokalen CUA-Toolfehlers
nicht verfügbar. Native Sicht- und FPSbestätigung bleibt ausstehend. Die Seite
ist die Vorlage für Tobias' anschließenden Vergleich; Abweichungen gehören mit
Kapitel, Bedienaktion und Fenstergröße zurück in diesen konkreten Pfad.

## Dokument-Canvas – 11. Oktober 2026

Der gemeinsame [Hintergrundpfad](CSS-BACKGROUNDS.md#dokument-canvas-und-tatsächliche-paintbesitzer--11-oktober-2026)
überträgt den tatsächlichen Root-/Body-Hintergrund auf eine behaltene passive
Canvasfläche. Aktives und implizites Containment, Namespace-/Direktkindgrenzen,
Display/Visibility, Alpha und helle/dunkle UA-Flächen werden unterschieden.
Bildgrößen, Position und Wiederholungsperiode benutzen die Rootbox; DOMstile
bleiben erhalten. Root-Opacity und die erste WAAPI-Promotion komponieren Canvas
und Original-GUI einmal; Body-Opacity verändert einen übertragenen Hintergrund
nicht. Gewöhnliche Dokumente erhalten keine zusätzliche CanvasGroup. Hintergrund-
Longhands aktualisieren Paint ohne Layout unveränderter Boxen.

63 native Fälle/136 Rohzustände sind dauerhaft gespeichert; die ursprünglichen
45 Fälle bleiben unverändert. Die zusätzlichen Owner-/EmptyURL-/State-
Rückwechsel erweitern denselben Capture und Test. Leere URLs bleiben bei der
Canvasauswahl Bildebenen, verursachen aber keine Auflösung, SVG-Draw, Upload-
oder Warnarbeit. 59 Initialzustände
und 73 dynamische Zustände bestehen mit 1490 tatsächlichen GUI-/Buffer-
Pixelproben; die zusätzlichen CSSOM-Rückwechsel stimmen auch mit frisch
aufgebauten Endzuständen überein. Der tatsächliche retained
`content-visibility`-Pfad ist darin enthalten. Retained Editor/Fokus/Auswahl, CurrentColor-Cachewechsel,
Layout-/Resizeveröffentlichung und PageSession-Abbau sind gesondert geprüft.
Die SVG-Ressourcen-Lifecycleprobe verwendet die tatsächlichen Request-/Upload-
und Disposepfade mit einem ausdrücklich synthetischen kleinen Rasterbackend.
Die tatsächliche SVG-Rasterimplementierung bleibt in den eigenen SVG-Suiten.
Eine benachbarte gewöhnliche Blockboxprobe hält acht warme Native-/Raster-
Radiuswechsel gegen frische Endzustände. Hintergrundbildänderungen erhalten
GUI-/Corneridentität und Texturen ohne Layout; die neun betroffenen Corner-/
Border-/Animationsnachbarn bestehen. Vollständige ersetzte Bild-/Control-
Cornerkombinationen werden damit nicht als abgeschlossen geführt. Sämtliche
Hover-/Media-/Container-Recascade-, Dokumentwachstums- und Seitenersetzungs-
Kombinationen sind mit diesem begrenzten Zustandsnachweis noch nicht abgenommen.

Dieses Paket schließt weder die gesamten Bildgrammatiken noch das vollständige
CSSOM-Hintergrundbildformat ab. Vier native Root-Transform-Initialzustände sind
noch ungeprüft: Die inverse Ausdehnung des unendlichen Canvas und weitere
Scroll-/Attachment-/Masken-/Filter-/Mischkombinationen bleiben umsetzbare
Restarbeit. Rohe Browser-/Standardabweichungen und die ausstehende Studio-
Pixel-/Leistungsabnahme stehen ausschließlich im vorhandenen Hintergrundprofil.
Lokale Framesetgröße/-Paint und tatsächliche nicht-HTML-/ersetzte SVG-Root-
Mounts bleiben dort ebenfalls ausdrücklich als umsetzbare Restfälle erhalten.

## Beauftragter Ausbau vom 8. Oktober 2026

Diese Pakete konkretisieren Tobias' Auftrag, die grundsätzlich umsetzbaren
Restpunkte zu ergänzen. HTML-Pakete werden im
[Parser-/Attributprofil](HTML-PARSER-ATTRIBUTES-20261006.md#beauftragter-ausbau-vom-8-oktober-2026)
geführt. Vorhandene Implementierungen bleiben Ausgangspunkt; ein offener
Kombinationsnachweis bedeutet nicht, dass ein ganzes Feature fehlt.

| Paket | Umsetzung und Abnahme | Status |
| --- | --- | --- |
| C01 Syntax und Kaskade | Escapes/Tokenfehler, ungültige Variablenwerte, CSS-weite Werte und Rollbacks, Import-/Namespacekombinationen und zusätzliche Selektorfälle mit Invalidierung | In Arbeit: Sprachfilter/Dokumentsprachen, gemeinsame Variable-Tokenisierung/Grammatik, Bereichs-/Defaultselektoren, aktuelle Formularzustände, Quirks-Hover/-Active und eigenschaftsgebundene alte Werte ergänzt. Gemeinsame At-Keyword-/Import-/Namespacegrammatik mit 19 nativen Regelbäumen, 23 CSSOM-Mutationsfolgen und tatsächlicher Import-/Layerkaskade nachgewiesen; drei Standardabweichungen bleiben separat erhalten. Weitere Kaskaden-/Selektorfälle offen |
| C02 Queries und Anchor | Weitere Medienmerkmale, boolesche/Bereichsqueries, Style-/Scrollzustandscontainer, Anchorgröße/-Scope und benannte Fallbacks; Abhängigkeiten und Resize | In Arbeit: gemeinsamer Medienparser; logische Größen-/Variablenqueries, eigene/registrierte Style-Variablen, Scroll-Snapshots und Ankergröße/-Scope/benannte Fallbacks ergänzt. Reine Farbwechsel erhalten GUIs ohne Layout. Übrige Query-/Anchorachsen bleiben offen; [Mediennachweise](#medienabfragen--9-oktober-2026), [Containerprofil](#containerabfragen--9-oktober-2026), [Ankerprofil](#ankerpositionierung--9-oktober-2026) |
| C03 Größen und Layout | Intrinsische/min/max/auto-Größen, Prozentzyklen, Baselines, Subgrid und Tabellenkombinationen; Teil-/Voll-Layout und GUI-Identität | In Arbeit: Prozentgrenzen, horizontale Quirks-/Dokumentfüllgrößen, intrinsische Proben, leere Randgruppen, verschachtelte Floatgrößen und abgegrenzte automatische/historische Zellgrößen ergänzt. Logische Größen/min/max in fünf Schreibmodi: 208 native Zustandsaufnahmen mit zehn expliziten normativen Vererbungsabweichungen, 30 native Achsen-/Reihenfolgeproben und tatsächlichen retained CSSOM-/Eingabepfaden. Intrinsische bevorzugte Größen und Min-/Max-Limits: 994 native Text-/Block-/Bild-/Image-Input-/Aspect-Ratio-/Prozent-/Dokumentzustände mit tatsächlichen Wortzeilen, abgegrenzten horizontalen Flex-/Grid-Itemfällen, Resize, Randbeiträgen und Quirks-Rootfüllung. Eigener verbundener Messgraph für intrinsische und atomare Inlineproben: 54 native/editor Zustände mit 170 Boxmaßvergleichen; CSSOM, Hit-/Wort-/Control-/Scrollgeometrie, GUI-/Editor-/Auswahlidentität und Ressourcen bleiben während jeder Messunterbrechung erhalten. Montierte CSSOM-Änderungen behalten Editor und Auswahl. Automatische Column-Flex-Querbreiten nutzen die gemeinsame Fit-Content-Intrinsik: 122 native Resize-/CSSOM-/Font-/Editorzustände mit 362 Boxvergleichen einschließlich der vier unveränderten self-start-Kontrollen, unabhängiger Vollparität und warmen Caches; Kerning-/Trackingkontrollen bleiben offen. Horizontale Flex-/Grid-Seitenausrichtung besitzt zusätzlich 580 Zustände/2.840 Boxvergleiche; vertikale Container und vollständige Alignmentgrammatik bleiben offen. Intrinsischer Scrollleistenbeitrag mit reinem Messgraph: 159 Größenzustände aus 53 Fällen plus neun retained Editor-/Resizezustände; rohe Plattformmaße und klassische Hostkalibrierung auf 10/6/0px bleiben getrennt. Weitere Gutter-/Float-/Fragment- und intrinsische/orthogonale Block-/Flex-/Grid-/Fragmentkombinationen und allgemeine Paintatomarität bleiben offen; [logische Größen](#logische-größen--10-oktober-2026), [intrinsische Größen und Limits](#intrinsische-bevorzugte-höhen--10-oktober-2026), [reine Messgraphen](#reine-intrinsische-und-atomare-messgraphen--10-oktober-2026), [Column-Flex-Querbreiten](#automatische-querbreiten-von-column-flex-items--10-oktober-2026), [Scrollprofil](SCROLLING.md#intrinsischer-leistenbeitrag--10-oktober-2026), [Größennachweise](HTML-PARSER-ATTRIBUTES-20261006.md#prozenthöhen-und-dokumentgrößen--9-oktober-2026), [Tabellenprofil](HTML-PARSER-ATTRIBUTES-20261006.md#historische-tabellen--9-oktober-2026) |
| C04 Inline und Fragmentierung | Mehrzeilige Inlineflächen, Box-Dekoration, Spalten-/Zeilenfragmente, Paint/Hit/Selection und Wiederverwendung | In Arbeit: historische Struts, direkt leere Inlineelemente, einfache statische Padding-/Border-/Hintergrundfragmente und abgegrenzte Inline-CSSOM-Geometrie ergänzt. Dynamischer Buchstabenabstand: 24 native Wertzustände, 156 Wertvergleiche, Klassen-/Variablenänderungen, Glyphmodus- und Quellgruppenwechsel mit aktuellem Selection-Paint, behaltenen GUIs und reinen warmen/abbrechbaren Messungen. Verschachtelte Dekorationen, horizontale Ränder, Fragmentierungs- und Paint-/Hit-/Selectionkombinationen sowie native Editor-Trackingdarstellung/Glyphenformung bleiben offen; [Buchstabenabstand](#dynamischer-buchstabenabstand--11-oktober-2026), [Paintnachweise](HTML-PARSER-ATTRIBUTES-20261006.md#historische-inline-struts-und-leere-inlineelemente--9-oktober-2026), [Geometrie](HTML-PARSER-ATTRIBUTES-20261006.md#inline-geometrie--9-oktober-2026) |
| C05 Schreibrichtung | Bidi-Umordnung und vertikale Schreibrichtungen samt Inline-/Blockachsen, Caret, Selection und Eingabe; verfügbare native Glyphen verwenden | In Arbeit: Unicode-17-Bidi mit 861.948 offiziellen Fällen und tatsächlicher HTML-/CSS-/Zeilen-/Paint-/Source-/Selection-/Live-Eingabeanbindung; 414 native Layoutvergleiche, 18 begrenzte Trackingprojektionen, 45 Shadow-/Slotzustände, 30 Ellipsen-Paintfälle. Unicode-17-Mixed-Orientierung mit vollständigem Property-Datensuchnachweis; vertical-/sideways-Modi mit 164 nativen Inline-Achslayouts, 192 Kopierfällen und 24 gedrehten Range-/Pointerfällen. Logische Seiten/Ecken und Scrollachsen: 30 native Zuordnungen, 90 native Scrollausrichtungen sowie 100 getrennt gekennzeichnete normative Vererbungsprojektionen. Gerade Inlinefragmente: 240 native Größen-/Inlinepositionen, 60 tatsächliche Leerraum-Ranges und retained Projektion. Textlinien: 1620 native Paint-Achs-/Ausdehnungs-/Seitenvergleiche, 23 Grammatikfälle; Font-Crosspositionen bleiben geschätzt. Scharfe Schatten: 240 normative physische Projektionen mit 96 nativen Matches und 144 expliziten Chrome-Rotationsabweichungen, dynamischen Listen/SourceScopes und Retention. Betonungszeichen: Unicode-17-Grammatiken/-Berechtigung, 247 tatsächliche native Mark-Paints/Quell-Ranges/Kopien, dynamische Farben/Stile/Achsen, Umbruch/Ellipsis, Hits/Selection, Compositinggrenzen und Abbau; rohe Form-/Seiten-/upright-Abweichungen bleiben getrennt. Vollständige vertikale Block-/Ruby-/Tabellenachsen, verschachtelte/orthogonale Fragmentkombinationen, präzise Marken-/Ruby-/Fontkollisionen sowie native Glyphcluster-/Caret-/Fontalternates bleiben offen. Maßgeblich: [Textprofil](HTML-SUPPORT.md#weitere-schritte) |
| C06 Silbentrennung | Sprachabhängige Wörterbuch-/Mustertrennung, Grenzen und CSS-Steuerung; gemessene Wortstücke und Auswahlindices erhalten | In Arbeit: lizenzierte Muster für 14 Sprachen, dynamische Trennung, manuelle Trennzeichen und Quellkopie; Whitespace, Einzug und Textumwandlung ergänzt. 60 native manuelle/None-Fälle, 264 Whitespace-Geometrien, 312 Quellkopien, 2.160 Einzugspositionen, 3.540 Unicode-Mappings, 520 normative Fallausgaben und 321 irische Firefox-Ausgaben. Browser-/Standardunterschiede sind getrennt dokumentiert; weitere Text-/Sprachkombinationen bleiben offen. [Trennprofil](OVERFLOW-WRAP.md), [Textprofil](HTML-SUPPORT.md) |
| C07 CSSOM und Typed OM | Weitere tatsächlich nutzbare Regel-/Werttypen, Math-/Transform-/Unparsed-/Variablenobjekte, Konversion/Fehler/Iteration und Live-Map-Commit | In Arbeit: Math-/Transform-/Unparsed-/Variablenobjekte, numerisches Parsing, SameObject-Maps und Live-Map-Commit ergänzt. Eigene native 2D-Transformationen ersetzter Inlineflächen erreichen dieselbe retained Paint-/CSSOM-Geometrie: 140 native Vergleiche, getrennte ResizeObserver-/Serialisierungskanäle und 9.258 reine Messprüfpunkte; Opacitybesitzer, fokussierter Editor und Abbau sind geprüft. Weitere Math-/Color-/Reifizierungstypen, Inline-3D-/Raster-/Treffer- und vollständige Animationskombinationen bleiben offen; [Typed OM](JAVASCRIPT-CSSOM.md#typed-om-ausbau-vom-8-oktober-2026), [Inline-Transformprofil](CSS-TRANSFORMS.md#eigene-2d-transformation-ersetzter-inlineflächen--10-oktober-2026) |
| C08 Animationen | Renderbare Werttypen, intrinsische Maße, Add/Accumulate/Iteration und Basiswechsel; CSS-/JS-Timing, Umkehr, Abbruch und Cleanup | In Arbeit: intrinsische Höhen, individuelle Transformwerte und Transform-Ursprung, Ganzzahlen, Border-/Outline-/Radius-Werte, vererbte Schrift-/Farbproben, dynamische Autorenbasen sowie CSSAnimation-/CSSTransition-Controller und geprüfte Ereignis-/Pending-rate-Folgen ergänzt. Der aktuelle native Referenz-, Ressourcen-/Abbruch- und Kombinationsnachweis samt verbleibendem Umfang steht ausschließlich im [Fachprofil](JAVASCRIPT-ANIMATION-LAYOUT.md). Weitere Werttypen, Controller-/Realm-/Timingkombinationen und vollständige Ereignissortierung bleiben offen. |
| C09 3D-Treffer | Perspektivische Rückprojektion interaktiver Nachfahren, Sichtbarkeit/Backface/Clipping und gemeinsame Paint-/Trefferreihenfolge | Umgesetzt im vorhandenen Ebenenprofil; Nachweise und Grenzen in [CSS-TRANSFORMS](CSS-TRANSFORMS.md#rasterprofil-und-grenzen) |

Jedes Paket benötigt Wirkungsnachweise im tatsächlichen Enginepfad,
Code-Review und passende Regressionen. Fehlende native Pixelquellen,
Betriebssystemdienste und GPU-Funktionen werden nicht durch API-Stubs als
erledigt dargestellt. Die bestehenden Hostgrenzen dieses Profils gelten weiter.

## Medienabfragen – 9. Oktober 2026

[MediaSyntax](../src/HTMLEngine/CSS/MediaSyntax.luau) liest CSS-Komponenten,
Escapes, Kommentare, Zahlen/Exponenten, Funktionen und verschachtelte Blöcke.
Kommas in Funktionen teilen keine Medienliste. Ungültige Einträge werden
einzeln zu `not all`; spätere gültige Einträge bleiben erhalten. Eine leere
Liste trifft zu. Unbekannte Features und allgemeine eingeschlossene Inhalte
haben den Wahrheitswert **unbekannt**, der auch nach `not` unbekannt bleibt.
`false and unknown` und `true or unknown` behalten ihre eindeutigen Ergebnisse.
Eine ungültige Grammatik wird damit nicht als fehlendes Enginefeature gemeldet.

[MediaQueries](../src/HTMLEngine/CSS/MediaQueries.luau) wertet boolesche,
gewöhnliche, min/max- und zulässige ein-/zweiseitige Bereichsformen aus.
Richtungswechsel in einem zweiseitigen Vergleich, min/max-Präfixe auf diskreten
Merkmalen und ungültige Werte bleiben unbekannt. Negative Längen/Auflösungen
werden als bekannte Werte behandelt; Integermerkmale unterscheiden
Integertokens von Dezimal-/Exponenttokens. Verhältniswerte können degenerieren;
endliche Werte werden nicht versehentlich gleich einer unendlichen Auflösung.
Unterstützte `calc`/`min`/`max`/`clamp`-Ausdrücke verwenden den bestehenden
begrenzten Matheparser. Addition/Subtraktion benötigt echte Whitespace-Tokens;
Kommentare erzeugen weder einen Operator noch eigenständig Whitespace.
Relative Font- und Viewporteinheiten werden gegen die Query-Umgebung ausgewertet,
nicht gegen Autorenstyles. Fontrelative Mathe bleibt beim Serialisieren relativ.
Statische Mathe wird einmal kompiliert. Berechnete Zahlen/Verhältnisse verwenden
das ausdrücklich geprüfte Chromium-Single-Precision-Profil.

Die Merkmale umfassen Größen, Geräte-/Seitenverhältnisse, Orientierung,
Auflösung, Farbtiefe/-index/Monochrom, Viewportsegmentanzahl, Hover/Pointer,
Farbschema, reduzierte Bewegung/Transparenz/Daten, Kontrast, Forced/Inverted
Colors, Update, Overflow, Scripting, Scan, Display Mode, Gamut/Dynamic Range
einschließlich Videoebene, Environment Blending und Navigationskontrollen.
Das sind Abfragen von Fähigkeiten, kein Ersatz für die native Implementierung
aller damit beschriebenen Funktionen. Ein Printprofil erzeugt z. B. keinen
Betriebssystem-Druckdialog, eine Segmentanzahl keine zusätzliche Bildschirmfläche.
`options.MediaFeatures` liefert ein ausdrücklich konfiguriertes Hostprofil.
Roblox erkennt Mouse/Touch und Reduced Motion über vorhandene Signale;
`scripting` spiegelt `options.JavaScript`. Weitere Betriebssystempräferenzen
werden nicht erfunden. Ohne konfigurierte Werte gelten die dokumentierten
Defaultwerte im Modul, z. B. sRGB/Standard Dynamic Range, ein Viewportsegment,
keine Farbinvertierung und progressives Rasterrendering.

Stylesheets, CSSOM-`MediaList` und JS-`matchMedia` teilen Parser und Serializer.
Der tatsächliche Seiten-Worker übernimmt Umgebungsänderungen durch
`RefreshDOMStyles`: Nur geänderte Geometrie fordert Layout an; Farbänderungen
malen vorhandene GUIs. Der übersprungene Layoutpfad publiziert trotzdem
`MediaQueryList`-Änderungen. Größen-/Generated-Content-/Ownershipänderungen
behalten ihre vorhandenen Invalidierungs- und Ressourcenpfade. Signale und
Queryobjekte werden beim Seiten-/Realmabbau freigegeben; kein zusätzlicher
Frame-Treiber oder Polling-Loop wurde eingeführt.

Nachweis: [864 native Resultate](../tests/fixtures/media-query-browser.json)
in vier Umgebungen, erzeugt durch den isolierten
[Chromium-Capture](../scripts/capture-media-query-reference.cjs), mit
[MediaQueryReference](../tests/MediaQueryReference.luau). Geprüft werden 864
Matchresultate und 800 serialisierte Abfragetexte, tatsächliche CSS-/CSSOM-/JS-
Pfade, Änderungen samt Eventdaten, behaltene GUIs und Ressourcenlimits.
[HTMLPageAnimationScheduling](../tests/HTMLPageAnimationScheduling.luau)
prüft über den echten Seiten-Worker ausdrücklich null BlockLayout-Aufrufe
bei einer Hover-Farbänderung, echtes Layout bei geänderter Präferenzhöhe,
unveränderte Folgewerte, Querypublikation und abgetrennte Signale.

Die Rohdaten bleiben unverändert erhalten. 28 Resultate tragen ausdrückliche
normative Zusatzwerte: Chromium 154 behandelt negative/unendliche Auflösung
teilweise als unbekannt und liefert für die boolesche Standard-Dynamic-Range-
Abfrage `false`. Der aktuelle MQ5-Text akzeptiert diese Auflösungswerte und
definiert boolesche Tests anhand unterstützter Nichtnull-/Nicht-none-Werte.
Features, die Chromium nicht implementiert, werden im Vergleich als solche
kalibriert; 64 zugehörige Serialisierungen behaupten keine native Gleichheit.
Roblox-spezifische zusätzliche Fähigkeiten werden separat über explizite
Hostwerte geprüft. Native OS-Fontmetriken, die gesamte neue CSS-Mathegrammatik,
Custom-Media-Definitionen, sämtliche Serialisierungskombinationen und die
übrigen Container-/Anchorachsen bleiben dadurch offen; ergänzte Containerfälle
sind im folgenden Abschnitt getrennt nachgewiesen.
Ressourcenlimits: 65.536 Quellbytes, 8.192 Komponenten, 32 Ebenen, 256 Zweige;
`matchMedia` behält seine kleineren Realmgrenzen. Dies ist ein geprüfter Ausbau,
keine Behauptung vollständiger MQ5- oder Browserkonformität.

Quelle: [Media Queries 5](https://drafts.csswg.org/mediaqueries-5/), insbesondere
Grammatik, Fehlerbehandlung, dreiwertige Auswertung, initiale Einheiten und
Merkmalsdefinitionen; die Version und Rohresultate sind in der Fixture benannt.

## Containerabfragen – 9. Oktober 2026

[ContainerQueries](../src/HTMLEngine/CSS/ContainerQueries.luau) wählt für eine
einzelne Bedingung genau einen Vorfahren, der alle benötigten Achsen/Featuretypen
unterstützt. Breite vom nahen und Höhe vom entfernten Container werden nicht
vermischt. Namen sind case-sensitive, unterstützen Escapes/Unicode und können
durch Kommentare von einer Bedingung getrennt sein. Die Vorfahrensuche folgt
bei verteilten Knoten ihrem Slot und beim ShadowRoot dessen Host.

Größenbedingungen unterstützen `width`, `height`, `inline-size`, `block-size`,
Orientierung, Verhältnis, boolesche/min/max-/Bereichsformen und verschachtelte
Logik. Logische Achsen beziehen sich auf den Schreibmodus des Containers.
`inline-size`-Container erfüllen nur diese Größenachse, `size` beide.
`display:none`/`contents` liefern keine Größenbox. Relative `em`/`rem`-Werte
beziehen sich auf Container-/Rootschrift; Viewporteinheiten behalten den
Seitenviewport. `var()`-Werte werden gegen die eigenen berechneten Variablen
des ausgewählten Containers ersetzt. Fehlende/ungültige Ersetzung bleibt
unbekannt, auch unter `not`. Geänderte Queryschrift, Rootschrift, Viewport und
benutzte Variablen werden invalidiert, auch wenn die Containerbreite gleich bleibt.

[ContainerStyleQueries](../src/HTMLEngine/CSS/ContainerStyleQueries.luau)
unterstützt `style(...)` für eigene Variablen. Jeder gewöhnliche Vorfahr kann
dafür Container sein, auch mit `container-type:normal`. Boolesche Formen prüfen
gegen den Initialwert; Deklarationsformen vergleichen berechnete Werte.
Registrierte Variablen verwenden denselben Typ-/Initial-/Vererbungsrechner wie
die normale Kaskade. Unregistrierte Werte behalten Case, Tokenform und
Whitespace; `1.0` ist in diesem Profil kein identischer Tokeninhalt wie `1`.
Kommentare werden nicht zu echten Whitespace-Tokens gemacht. CSS-weite Werte,
Fallbacks, `var()` und ungültige Rollbacks haben eigene Regeln.
Ein-/zweiseitige Bereiche berechnen Zahlen, Prozent, Längen, Winkel, Zeiten,
Frequenzen und Auflösungen; inkompatible Typen treffen nicht zu. Gemeinsame
Matheparser und ihre Ressourcen-/Grammatikgrenzen bleiben ausdrücklich bestehen.

`container-type` unterstützt außerdem `scroll-state` und die zulässigen
Kombinationen mit `size`/`inline-size`. Die Grammatik wird auch im `container`-
Shorthand und bei CSSOM-Serialisierung verwendet.
[ContainerScrollQueries](../src/HTMLEngine/CSS/ContainerScrollQueries.luau)
wertet `stuck`, `snapped`, `scrollable` und `scrolled` mit physischer/logischer
Richtung und booleschen Kombinationen aus.
[ContainerStates](../src/HTMLEngine/Rendering/ContainerStates.luau) hält einen
Snapshot während der folgenden Kaskade stabil. Sticky-Offsets kommen aus dem
bestehenden Viewportpfad, Snapziele aus derselben Auswahl wie das tatsächliche
Scroll-Snapping. Absolute JS-Scrollschreibvorgänge verändern `scrolled` nicht;
`scrollBy()` und beobachtete native Wheelbewegung erfassen relative Richtung.
Nichtscrollbare/nichtsticky Boxen werden entsprechend dem aktuellen Entwurf
von den jeweiligen Featurewerten ausgeschlossen.

Der tatsächliche Seiten-Worker fasst Post-Layout-/Scrollsignale in einem
verzögerten Snapshot zusammen. Reine Farbe braucht keinen BlockLayout-Aufruf,
kein neues GUI und keinen zusätzlichen Frame-Treiber. Geometrieänderungen
fordern weiterhin gezieltes Layout an; Animationen erhalten ihre vorhandene
Veröffentlichung. Die Snapshotindizes enthalten nur beteiligte Scrollcontainer
und Snapbesitzer; relevante Stil-/DOMänderungen erneuern sie. Ladepausen und
Seitenabbau behalten ihre vorhandenen WorkContext-/Alive-Grenzen.

Nachweise:

- [588 Größenresultate](../tests/fixtures/container-query-browser.json) in zwölf
  Größen-/Schreibmodus-/Schriftumgebungen, erfasst durch
  [Capture](../scripts/capture-container-query-reference.cjs), geprüft mit
  [ContainerQueryReference](../tests/ContainerQueryReference.luau).
- [360 Style-Resultate](../tests/fixtures/container-style-browser.json) in sechs
  Umgebungen, [Capture](../scripts/capture-container-style-reference.cjs),
  [ContainerStyleReference](../tests/ContainerStyleReference.luau).
- [3.060 Scrollresultate](../tests/fixtures/container-scroll-browser.json) in
  40 aufeinanderfolgenden Snapshots von Overflow, absolutem/relativem Scrollen,
  Sticky und Snapzielen, jeweils LTR/RTL;
  [Capture](../scripts/capture-container-scroll-reference.cjs),
  [ContainerScrollReference](../tests/ContainerScrollReference.luau).
- Gemountete Schrift-/Variablenwechsel, direkte Paint-/GUI-Erhaltung,
  unveränderte Snapshots und der echte Root-Scroll-Worker in
  [HTMLPageAnimationScheduling](../tests/HTMLPageAnimationScheduling.luau).
  Wiederholte Rootsignale werden zusammengefasst; der Abbau mit ausstehendem
  Snapshot bleibt sicher und hat keine zurückgelassenen Frame-/Servicesignale.

Die Browserrohwerte bleiben erhalten. 44 Größenresultate haben zusätzliche
Standarderwartungen, weil Chromium im Snapshot `var()` in Größenqueries nicht
auswertet. Sechs Frequenzproben vergleichen `1kHz`/`1000Hz` gemäß dem Entwurf,
obwohl Chromium sie nicht trifft. 170 Scrollresultate benennen ausdrücklich
die abweichenden `none`-/Negationswerte auf nichtscrollbaren/nichtsticky Boxen.
Es werden keine ganzen unbekannten Familien als bestanden ausgeklammert.

Offen bleiben normale CSS-Eigenschaften/Shorthands in `style(...)`, die
gesamte erweiterte Mathe-/Substitutionsgrammatik, Containerabfragelisten und
Custom Media, vollständige Fontmetriken und alle vertikalen Layout-/Unit-
Kombinationen. Die Scrollreferenzen liefern den physischen Offset nativer
negativer RTL-Ursprünge ausdrücklich an Ersatzframes; sie beweisen nicht den
gesamten nativen Roblox-RTL-Scrollorigin. Touch-/Tastaturscrollrichtungen,
Snapereignisse, verschachtelte/verschachtelt transformierte Snapziele,
Proximity-/Oversize-/Root-Snapping und zyklische Größen-/Scrollabhängigkeiten
benötigen weiteren Ausbau/Abgleich. Anchorgröße, Anchor-Scope und benannte
Fallbacks sind anschließend im folgenden Teilprofil ergänzt. Native Roblox-Optik,
Eingabe- und Frametimingbestätigung sind von diesen Prüfungen getrennt.

Grundlage: [CSS Conditional Rules 5](https://drafts.csswg.org/css-conditional-5/),
insbesondere Containerauswahl, Größen-/Style-/Scrollfeatures und stabile
Post-Layout-Snapshots. Das ist ein datierter, abgegrenzter Implementierungsnachweis,
keine Vollständigkeitserklärung für CSS Conditional 5 oder C02.

## Logische Größen – 10. Oktober 2026

`inline-size`, `block-size` und ihre `min-`-/`max-`-Varianten verwenden die
physischen Breiten-/Höhenfelder des berechneten `writing-mode`: horizontal,
vertical-rl/lr und sideways-rl/lr. Physische und logische Deklarationen teilen
Reihenfolge und Important-Kaskade, Prozent-/Mathematikwerte, Variablen samt
ungültigem berechnetem Wert, Content-/Border-Box und Minimum-vor-Maximum.
Physische und logische Layer-Rollbacks behalten die endgültige Achsenabbildung,
auch wenn die zurückliegende Schicht einen anderen Schreibmodus deklariert.
Der gemeinsame Achsen-Prepass bleibt während der Anwendung erhalten; frühe
Schreibmodus-/Richtungswerte verändern spätere Seiten/Ecken nicht vorübergehend.

Nachweis: [92 native Fälle mit 208 Zustandsaufnahmen](../tests/fixtures/logical-sizing-browser.json),
erzeugt durch [isoliertes Chromium](../scripts/capture-logical-sizing-reference.cjs),
und [LogicalSizing](../tests/LogicalSizing.luau). Größen, berechnete physische/logische
Werte, Resize und behaltene GUIs/Styleobjekte werden gemeinsam geprüft.
30 zusätzliche native Proben vergleichen Seiten/Ecken in unterschiedlichen
Deklarationsreihenfolgen. [JavaScriptCSSOMRendering](../tests/JavaScriptCSSOMRendering.luau)
prüft echte CSSOM-Mutationen in allen fünf Modi, erhaltene native Eingabefelder,
editierte Werte und rückwärtige Textauswahl. Reine Farbänderungen lösen dabei
kein Layout aus. Die benachbarten Größen-, Tabellen-, Grid-, Formular-, Bild-,
Query-/Picker-/Anker- und Schreibachsenpfade bestehen in 18 gezielten Suiten.

Die [Vererbungsregel in CSS Logical §4](https://drafts.csswg.org/css-logical-1/#logical-box-properties)
liest die gleichnamige logische Eigenschaft des Elternteils. Zehn orthogonale
Fälle behalten deshalb die rohen Chromium-Ergebnisse und getrennte normative
Erwartungen: Chromium verwendet dort die physische Entsprechung der Kindachse.
Das wird nicht als Browsergleichheit ausgewiesen. Intrinsische Größen in
vertikalen/orthogonalen Block-, Flex-, Grid- und Fragmentkombinationen sowie
vollständige automatische Mindestgrößen und Prozentzyklen bleiben offen.
Die Größenregistrierung ist kein Nachweis dieser noch offenen Layoutfamilien.

## Intrinsische bevorzugte Höhen – 10. Oktober 2026

`height:min-content|max-content|fit-content` und entsprechend abgebildete
logische Größen bleiben als intrinsische Werte erhalten; sie werden nicht als
bestimmte Nulllänge gespeichert. Im horizontalen Blockfluss verwendet die
bevorzugte intrinsische Höhe den vorhandenen Inhalts-/Umbruchpfad, inklusive
Blockkindern, kollabierenden Rändern, Min-/Max-Grenzen und Aspect-Ratio-Übertrag.
Für vertikalen/seitlichen direkten Text liefern dieselben nichtmalenden
Wortproben die minimale/maximale Inlineausdehnung. `fit-content` begrenzt diese
mit der verfügbaren Höhe; automatische Inlinegrößen unterscheiden parallele
Stretch- von orthogonalen Fit-Fällen. Die Layoutabhängigkeit berücksichtigt
veränderte Elternhöhen. Bei geladenen Blockbildern behalten intrinsische
bevorzugte Achsen natürliche Maße, Größenverhältnis und Grenzwertübertrag.
Der horizontale HTML-Root behält im Quirks-Modus seine Viewportfüllung auch
bei diesen intrinsischen Keywords. Die besondere Bodyfüllung gilt nativ
weiterhin nur für `height:auto`; Keywords messen dort den Inhalt.

Dieselben Keywords gelten jetzt für physische und logisch abgebildete
`min-width`, `max-width`, `min-height` und `max-height`. Horizontale Höhenlimits
verwenden den bereits laufenden Inhaltsdurchlauf. Eine bestimmte bevorzugte
Längenhöhe und ihre Längenlimits bestimmen dabei weiterhin die Prozentkindbasis;
das intrinsische Limit löst diese Basis nicht nachträglich erneut auf.
Hypothetisch außen liegende letzte Margins vergrößern den intrinsischen
Blockbeitrag nicht. Breitenlimits messen mit geklontem Eigenstil ohne eigene
Breitenlimits, während Nachfahren ihre gewöhnlichen Grenzen behalten.
Geladene Bilder und Image-Inputs übertragen intrinsische Limits über die
gegenüberliegende Größe und das Größenverhältnis. Abgegrenzte horizontale
Flex-/Grid-Breitenlimits sowie horizontale Flex-Row-/Column-Höhenlimits
verwenden diese vorhandenen Breiten- bzw. Höhenbeiträge.

Nachweis: [91 native Fälle mit 994 Zustandsaufnahmen](../tests/fixtures/intrinsic-height-browser.json),
[isolierte Chromium-Aufnahme](../scripts/capture-intrinsic-height-reference.cjs)
und [IntrinsicHeight](../tests/IntrinsicHeight.luau). Alle fünf Schreibmodi,
physische/logische Größen, `br`/`nowrap`, Content-/Borderbox, Minimum-vor-Maximum,
echte Elternhöhenänderungen, Schrift-/Breitenänderungen und dekodierte Bilder
werden mit roher Browsergeometrie und berechneten Werten verglichen. Direkte
Textfälle vergleichen zusätzlich die tatsächlichen Browser-Zeilengruppen:
eine passende Außenhöhe allein beweist keinen korrekten Umbruch. Prozentkinder
behalten bei intrinsischer bevorzugter Blockhöhe eine unbestimmte Basis.
Bestehende GUI-/Styleobjekte bleiben erhalten; reine Wortproben verändern
weder die vorherigen Wortpositionen noch native Oberflächenmaße. Unveränderte
Durchläufe benötigen keine weiteren nativen Schriftmessungen. Eine erzwungene
Textmaßunterbrechung mitten in einer intrinsischen Limitprobe publiziert keine
temporäre GUI-Geometrie; der folgende vollständige Durchlauf entspricht einem
frischen Baum. Montierte
[CSSOM-/Controller-Regressionsfälle](../tests/JavaScriptCSSOMRendering.luau)
für Input-Min-/Max-Limits behalten Editor, bearbeiteten Wert und Auswahl;
Farbänderungen an diesen Controls bleiben ohne Layout. Diese Widgetprüfung
verwendet die vorhandenen Hostmaße und behauptet keine vollständige
Browsergleichheit ihrer Fontmetriken. Die Textproben verwenden die im Browser
gemessenen Courier-Vorschübe am CSS-Schriftgrad; die getrennte Roblox-
Schriftkalibrierung wird damit ausdrücklich nicht als Browsergleichheit geprüft.
28 gezielte Größen-/CSSOM-/Bild-/Schreibachsen-/Formular-/Tabellen-/Grid-/
Query-/Anker-/Picker-/Dirty-Layout-/Probe-/Animationssuiten bestehen mit diesem Stand.
Die zusätzliche reale Dokumentprüfung und die drei Quirks-Regressionssuiten
bestehen: 399 bestehende Szenen mit 7659 montierten Positions-/Größenvergleichen,
690 Deklarations-/CSSOM-Werten und den vorhandenen Modus-/Hover-/Adoptionsfällen.

Grundlage: [CSS Sizing 3, Größenwerte und Intrinsic-Größen](https://drafts.csswg.org/css-sizing-3/#sizing-values).
Dieses Teilprofil umfasst noch keine `fit-content()`-/Stretch-/Calc-Size-Grammatik,
vollständigen orthogonalen Blockinhalt, atomare Inline-/Marker-Kombinationen,
Flex-/Grid-Automindestgrößen, alle Fehlerbild-/Medien-/Font-/gegenläufigen
Ratio-Limit-Kombinationen, weiteren Dokument-/Quirks-Kombinationen oder
Fragmentierungs-/Prozentzyklen. Der atomare `MeasureGrid`-Pfad und die
intrinsischen Wortproben verwenden nun den unten beschriebenen eigenen
Messgraphen. Das schließt die allgemeinen Layout-/Paintgrenzen nicht mit ein.
Die automatische Roblox-/GUI-Ersatzobjektprüfung bleibt von einer tatsächlichen
Studioabnahme getrennt. Diese Grenzen
bleiben C03-Anforderungen; sie werden nicht aus einer Größenregistrierung
abgeleitet oder als unmöglich eingestuft.

## Reine intrinsische und atomare Messgraphen – 10. Oktober 2026

[LayoutMeasurement](../src/HTMLEngine/Layout/LayoutMeasurement.luau) erstellt
für Größenproben einen verbundenen eigenen Graphen. Die vorhandenen
Block-/Inline-/Flex-/Grid-/Table-/Float-/Columns-Algorithmen bleiben der einzige
Arrangepfad. `Items`, `InlineBox`, Inlinefragmente, Controls und ihre
Style-/Geometriedaten teilen innerhalb der Probe die richtigen eigenen
Referenzen. DOM-Knoten und immutable Fontwerte behalten ihre Identität;
native GUI wird durch reine Geometrierecords ersetzt. Hit-/Text-/Node-Register,
Live-Layoutcache, Ressourcen-/Paint-/Neuberechnungs-Callbacks und native
Renderer gehören nicht zum Messgraphen. Image/Media/IFrame-/Controlpaint,
Masken, Transformationen und Scrollcommit werden in der Probe nicht aufgerufen.

`MeasureGrid` misst den eigenen atomaren Teilbaum. Die tatsächliche Inlinebox
wird erst an der endgültigen Zeilenposition und Breite arrangiert. Deklarierte
Prozentbreiten verwenden dabei die enthaltende Zeile als Basis. Fertige
Font-/Glyphen-/Marker-/Emphasis-Maße können getrennt übernommen werden;
unbesuchte oder abgebrochene Glyphenproben ersetzen keinen vollständigen
Cache durch ungemessene Werte. Schriftfamilie, Gewicht, Variante, Bidi und
Tabular-Zustand bleiben Teil der Wiederverwendungsprüfung. Kopieren,
Verknüpfen und große Cachevorbereitungen prüfen das Arbeitsbudget. Die reine
Shape-Image-Abfrage liest ausschließlich bereits geladene Threshold-Daten;
sie startet keine Requests, Task/Asset-/SVG-Arbeit, Diagnosen oder Sourcebudgets.

Auch vorhandene painted Glyphenbreiten können noch zur vorherigen Schriftgröße
gehören, während eine reine Probe bereits neue vollständige Fontbounds hält.
Unbesuchte Folgeproben behalten deshalb den passenden vollständigen Cache;
neu abgeschlossene Messungen mit anderem Schlüssel ersetzen ihn weiterhin.
Der gezielte Cachevertrag prüft beide Richtungen ohne Mutation der behaltenen
Glyphengeometrie. Die [native Atelier-Kontrollaufnahme](../tests/fixtures/container-font-measurement-browser.json)
bewahrt neun Container-/Font-/Grid-Zustände aus der tatsächlichen Story und CSS.
[CSSAtelierWebsite](../tests/CSSAtelierWebsite.luau) prüft unabhängig dieselben
Spalten- und Fontgrößen, aktuelle gemessene Glyphenbreiten, GUI-Identität und
warme Intrinsikabfragen ohne weitere Messung oder Allokation. Dies belegt
Layout mit den bestehenden kontrollierten Textmaßen, keine Gleichheit der
Roblox-/Browser-Glyphenformung. Die rohe native Aufnahme bewahrt auch die
relative Trackingänderung. Ihre dynamische Weitergabe und der Wechsel zwischen
Glyphen- und gewöhnlichem Labelmodus sind im begrenzten C04-Nachweis
[Dynamischer Buchstabenabstand](#dynamischer-buchstabenabstand--11-oktober-2026)
ergänzt; native Glyphenformung und Editor-Trackingdarstellung bleiben getrennt
ungeprüft.

Die [Browseraufnahme](../tests/fixtures/layout-atomic-browser.json) enthält
54 Zustände aus neun Inline-block/-flex/-grid-, verschachtelten,
Prozent-/logischen-/Rand-/Min-/Max-/Fit-/Scroll-/Tracked-Glyphen-Szenen.
Der [tatsächliche Renderer-/Controller-/Runtime-Test](../tests/LayoutAtomicMeasurements.luau)
prüft 170 native Boxmaße mit den gespeicherten Courier-Vorschüben. Er hält
jede Budgetpause und kalte native Textmaßunterbrechung gegen behaltene
GUI-/Box-/Wort-/Glyphen-/Hit-/Control-/Scrollgeometrie, computed CSSOM,
`getBoundingClientRect`/Client-/Scrollzugriffe, einen fokussierten und
bearbeiteten Editor mit backward Selection und die vorhandenen Bindings.
Warme Proben erzeugen keine neuen nativen Textmaße oder GUI/Assets.
Abbruch mitten im dritten nativen Maß hinterlässt keine vorläufige Geometrie;
Wiederaufnahme und alle finalen Zustände entsprechen einem frischen Baum.
Der echte TextBox-Change funktioniert anschließend weiter; Cleanup löst
sämtliche ursprünglichen Eingabebindings. Die vorhandenen Probe-,
Border-/Marker-/Emphasis-/Shape-/Text-/Form-/Table-/Grid-/Flex-/CSSOM-/
Lifetime-Nachbarn bestehen ebenfalls.

Die ursprüngliche rohe Aufnahme bewahrt zwei Größenabweichungen: den damals
fehlenden intrinsischen Leistenbeitrag einer Auto-Scrollfläche und die letzte
Trackingkante unabhängig gezeichneter Glyphen bei `min-content` (2px in dieser
Aufnahme). Ihre vier ausgeschlossenen Boxmaße bleiben unverändert roh erhalten
und werden weiter gegen Frischaufbauparität geprüft. Der Leistenbeitrag ist
inzwischen über den gemeinsamen reinen Messpfad ergänzt und mit einem eigenen
[Scrollprofil](SCROLLING.md#intrinsischer-leistenbeitrag--10-oktober-2026) von
159 Größenzuständen aus 53 Fällen sowie neun montierten Editorzuständen
nachgewiesen. Dort stehen die rohen Plattformmaße ausdrücklich getrennt vom
Vergleich mit kalibrierten Roblox-Leistendicken 10/6/0px. Die native
Fontkalibrierung wird weiterhin getrennt von Roblox-Fontgleichheit gehalten.

Die Garantie betrifft reine Größenmessung und den atomaren Inline-Messpfad.
Allgemeine Live-Arrange-Proben in anderen Flex-/Grid-/Positionierungsphasen,
ein vollständig yieldfreier GUI-/GPU-/Raster-Paintcommit und sämtliche
orthogonalen/Fragmentierungs-/Prozentzyklusfälle sind dadurch nicht abgeschlossen.
Die Studioabnahme bleibt vom ausführbaren GUI-Ersatzobjekt getrennt.
Grundlagen: [CSS Sizing 3, Intrinsic-Größen](https://drafts.csswg.org/css-sizing-3/#intrinsic)
und [CSS Inline 3, atomare Inlineboxen](https://drafts.csswg.org/css-inline-3/#atomic-inline).

### Live-Ressourcen außerhalb des Messgraphen — 12. Oktober 2026

Eine im breiten Prüflauf gefundene Regression führte über AudioSession → CurrentHostLease.Page → JavaScriptRuntime → VM zu einem Autorenarray. Dessen String-Items wurden fälschlich als geometrische Messobjekte registriert. Der Nachtrag setzt die Grenze vor der Traversierung: Audio-/Videoleases, iframe-Kindseiten und IMG-Ressourcenzustände bleiben opake Referenzen; die geprüften Runtime-/Ressourcenhostfelder gehören nicht zur Geometriekopie. Items werden nur aus Words, ImageItem nur aus BlockImage als Messbesitzer registriert. Marker werden für tatsächliche Block-/BlockImage-/Inline-Markerbesitzer übernommen, einschließlich ersetzter/list-item-Bildboxen. Fremde Items-/ImageItem-/Markerfelder begründen keinen Messcache.

[MeasurementOwnerBoundaries](../tests/MeasurementOwnerBoundaries.luau) prüft 21 Assertions, drei tatsächliche Messobjekte, null fremde Messobjekte und null Zugriffe auf Live-Owner. Der unveränderte [InlineReplacedTransforms](../tests/InlineReplacedTransforms.luau) besteht mit 140 gespeicherten Browser-/GUI-Geometrievergleichen und 8980 reinen Messprüfpunkten. Der Autorstand besteht mit tatsächlichem Exit 0 in neun Suiten einschließlich LayoutAtomicMeasurements, FlexAutoCross, PositionAlignment, VideoJavaScriptMounted sowie Lists, Details und GeneratedContentRendering. Original-/Diagnose-/Marker-Rotbelege und [BUILD-HOLD](../build/layout-measurement-owner-prep/final-build-hold-v2.json) bleiben getrennt erhalten.

Dies ergänzt die konkret geprüften Ownergrenzen; neue Ressourcenfelder benötigen weiterhin eine ausdrückliche Zuordnung. Der Nachweis schließt weder alle Layoutfälle noch allgemeinen GC-, GPU-/Frametiming- oder Studioverhalten ab. Drei rote Gesamtprüfungen des bisherigen Full16-Versuchs bleiben erhalten; eine neue erfolgreiche Gesamtprüfung wird erst nach dem gemeinsamen aktuellen Prüfstand dokumentiert.

## Automatische Querbreiten von Column-Flex-Items – 10. Oktober 2026

Der bestehende [Flex-Arrangepfad](../src/HTMLEngine/Layout/FlexLayout.luau)
bestimmt eine endgültig automatische physische Querbreite in einer Flexspalte
über die gemeinsame intrinsische Messung:
`max(min-content, min(max-content, verfügbar))`. Das gilt für nicht gestreckte
Items und automatische Querränder. Der Fall mit deklarierter Umbruchart
bleibt bei jeder aufgenommenen Breite tatsächlich einspaltig; er heißt
ausdrücklich `column wrap declaration without line break`.
Anonyme Textitems verwenden denselben vorhandenen natürlichen Wortmesspfad.
Fixe oder ausdrücklich intrinsische `width`-Werte behalten ihren normalen
Arrangepfad; Min-/Max-Limits werden weiterhin bei der tatsächlichen Anordnung
angewendet, einschließlich `min-width`-Vorrang. Prozent-Padding und -Margins
verwenden die aktuelle Containerbreite. Die reine intrinsische Hilfe löst
diese Beiträge in eigenen Style-Daten; sie schreibt weder vorläufige Breiten
noch eine neue `width`-Deklaration in den Live-Baum.

Die [native Aufnahme](../tests/fixtures/flex-auto-cross-browser.json) und
der [montierte Test](../tests/FlexAutoCross.luau) prüfen 118 Zustände mit
350 Boxvergleichen: 24 Fälle wechseln jeweils zwischen 40, 120, 400 und
80 px, weitere 22 Zustände ändern echte CSSOM-Deklarationen, Variablen,
Min-/Max-Limits, Ränder, Schriftfamilie und Schriftgröße. Jeder Zustand wird
gegen einen unabhängig aufgebauten vollständigen Layoutbaum verglichen.
Verwendete CSSOM-Größen und ursprüngliche fixe/automatische/intrinsische
Deklarationen bleiben getrennt. GUIs, tatsächlicher nativer Editor,
bearbeiteter Wert, Fokus, Cursor/Selection und vorhandene Bindings bleiben
erhalten. Warme Intrinsikabfragen und erneute Anordnung benötigen keine
neuen nativen Textmaße oder Oberflächen; echte TextBox-Änderungen funktionieren
anschließend weiter, und Cleanup löst Editor-/Eingabebindings vollständig.
Der frühere Column-Flex-Ausnahmefall der atomaren Aufnahme gehört damit
wieder zu deren zwölf zusätzlichen nativen Boxmaßvergleichen.

Das Schrift-Abnahmeprofil verwendet ausdrücklich `font-kerning:none` und
unabhängig erfasste native Einzelvorschübe. Auch montierte Styles und die
gezeichneten Wort-GUIs behalten `kern 0`. Dies prüft Layout mit kalibrierten
Vorschüben; eine Roblox-/Browser-Glyphen- oder Formungsgleichheit wird nicht
behauptet. Die Aufnahme bewahrt zwei zusätzliche Kontrollfamilien:
Die vier `align-items:self-start`-Rohkontrollen wurden am 11. Oktober im
[Alignmentnachweis](#position-alignment-in-horizontalen-flex--und-gridcontainern--11-oktober-2026)
mit unveränderten Erwartungen akzeptiert; der aktuelle Test umfasst deshalb
122 Zustände/362 Vergleiche. Arial mit normalem Kerning formt Wort-/Space-Übergänge gemeinsam
(286,328 px für den ganzen DOM-Text gegenüber 289,906 px aus unabhängig
gemessenen Wörtern/Spaces). Allgemeine Alignmentkombinationen und
Übergangsformung bleiben C03 beziehungsweise C04 offen.

Der intrinsische Scrollleistengutter ist inzwischen im gemeinsamen Größenpfad
für die begrenzten Fälle des [Scrollprofils](SCROLLING.md#intrinsischer-leistenbeitrag--10-oktober-2026)
ergänzt; weitere Gutter-/Float-/Fragmentkombinationen bleiben offen.
Bei Tracking werden die rohe Chromium-Kante und die
normative CSS-Text-3-Behandlung der Zeilenränder getrennt gehalten; für
Browsergleichheit wird kein pauschaler zusätzlicher Abstand angehängt.
Die Prozentbasis bei echtem mehrspaltigem Column-Flex-Umbruch bleibt offen.
Vollständige orthogonale Flexachsen, Fragmentierung, sämtliche Umbruch-/
Baseline-/Prozentzyklen und allgemeine Paintatomarität sind durch diesen
begrenzten Quergrößennachweis nicht abgeschlossen. Die native Studioabnahme
bleibt getrennt. Grundlage:
[Flexbox 1, Cross Size Determination](https://drafts.csswg.org/css-flexbox-1/#cross-sizing),
[CSS Sizing 3, Fit-Content-Größe](https://drafts.csswg.org/css-sizing-3/#fit-content-size)
und [CSS Text 3, Letter Spacing](https://drafts.csswg.org/css-text-3/#letter-spacing-property).

## Ankerpositionierung – 9. Oktober 2026

`anchor()` und `anchor-size()` werden im gemeinsamen Komponentenparser
innerhalb zulässiger Insets, Größen und Margins aufgelöst. Das Profil umfasst
physische/logische Größenachsen, explizite/default Namen, Escapes/Unicode,
`calc()`/`min()`/`max()`/`clamp()`, verschachtelte und prozentuale Fallbacks,
ungültige oder fehlende Anker und Fallbacks auf nichtpositionierten Boxen.
Andere Eigenschaften erhalten dadurch keine unzulässigen Ankerfunktionen.
Die Größenbasis ist die Borderbox des ausgewählten Ankers. Die veränderte
Größe durchläuft den vorhandenen Layout-/Intrinsic-/Min-/Max-Pfad.

`anchor-name` und `anchor-scope` verwenden kommagetrennte, case-sensitive
Namen; `none` und für Scope `all` sind enthalten. Der neue per-Layout
`AnchorRegistry` berücksichtigt akzeptable Containing-Block-/Baumreihenfolge,
den nächstliegenden akzeptablen Vorfahren, relative Versetzung, bereits
positionierte Anker und verschachtelte Owner. Scopegrenzen funktionieren auch
auf `display:contents`; ausgeblendete, boxlose und übersprungene Inhalte
werden nicht als sichtbarer Anker für außen verwendet. Selbst-/Nachfahrenzyklen
sind ausgeschlossen. Shadow-Baumgrenzen haben ein grundlegendes Profil;
dies ist kein Nachweis jeder Part-/Slot-/Pseudoelementkombination.

`@position-try` liefert gefilterte Größen-/Inset-/Margin-/Self-Alignment-
Deklarationen, Variablen, Quellen-/Layer-/Medienauswahl und die vorhandene
Stilauflösung. `!important` in ursprünglichen Regeldeklarationen wird ignoriert;
wichtige Autorwerte behalten Vorrang. Bis zu acht benannte Alternativen mit
`flip-block`, `flip-inline`, `flip-start`, `flip-x` und `flip-y` verwenden den
gemeinsamen Positionierungs-/Layoutpfad. `AnchorFallback` behält eine passende
gewählte Alternative, invalidiert sie bei relevanten Basis-/Regel-/Ownerwechseln
und stellt nach erfolglosen Größenproben die gewählte Größe wieder her.

`position-try-order` sortiert Basis und Alternativen stabil nach dem verfügbaren
inset-modifizierten Containing Block: `normal`, `most-width`, `most-height`,
`most-inline-size` und `most-block-size`. Die logischen Achsen richten sich nach
dem Containing Block; Auto-Insets zählen als null. Die Sortierung löst keine
zusätzlichen Layoutproben aus. Der Fit-Test verwendet die Marginbox und lehnt
negative verfügbare Größen auch bei einer Nullbox ab. Passende frühere Optionen
bleiben erhalten, solange kein relevanter Eingabewechsel sie zurücksetzt.
`position-try` setzt beide Longhands, einschließlich ausgelassenem Order,
Variablen, ungültiger Substitution, Vererbung/Initial/Unset und Layerrollback.
Die allgemeine absolute Insetsauflösung berücksichtigt nun auch RTL und
vertikale Gegenrichtung sowie die Verteilung automatischer Margins.

`CSSPositionTryRule` und `CSSPositionTryDescriptors` ergänzen tatsächliche
CSSOM-Regel-/Styleobjekte, schreibgeschützte Namen, erlaubte Member,
Serialisierung und die beobachteten unterschiedlichen `!important`-Regeln
von `cssText` und `setProperty`. Änderungen eines montierten Stylesheets
erreichen den behaltenen RenderTree. Computed Styles überlagern nur die
gewählte Geometrie, damit spätere reine Farbwechsel aktuell bleiben und kein
Layout auslösen. Es entstehen keine zusätzlichen Frame-Treiber oder GUIs.
Order-/Fallback-Shorthand und die Longhands sind auch in CSSOM und Computed
Styles enthalten. Gemischte CSS-weite/Variablenkomponenten werden nicht als
unzulässiger Shorthand serialisiert; vollständige Pending-Shorthands bleiben
als ursprüngliche Quelle erhalten. Die Identifier-Serialisierung teilt ihren
Code mit `CSS.escape` und hält dessen vorhandene Zeichenregeln bei.

Nachweise:

- [288 native Layouts](../tests/fixtures/anchor-browser.json), 3.660
  Geometrievergleiche, 30 montierte Änderungen und 60 Syntaxresultate;
  [Capture](../scripts/capture-anchor-reference.cjs),
  [AnchorReference](../tests/AnchorReference.luau). Größen-/Scope-/Regelwechsel
  behalten GUI- und Stilidentität. Skipped-Nachfahren werden ausdrücklich nicht
  mit durch Messung erzwungenen Browserboxen gleichgesetzt; ihre Ablehnung als
  Anker von außen ist geprüft.
- [45 native CSSOM-Resultate](../tests/fixtures/anchor-cssom-browser.json),
  [JavaScriptAnchorCSSOM](../tests/JavaScriptAnchorCSSOM.luau) und tatsächliche
  Stylesheet-/Größen-/Paintwechsel mit InputController in
  [JavaScriptCSSOMRendering](../tests/JavaScriptCSSOMRendering.luau).
- Die Rohdaten bleiben unverändert: zwei Geometriewerte bei Vorfahrenauswahl
  und ein Größen-/ein Syntaxwert für `anchor-size(,45px)` tragen ausdrücklich
  Erwartungen aus dem September-2026-Entwurf. Acht weitere Geometriewerte
  benennen Chromiums stale Scopeinvalidierung bei `display:contents`; beide
  Rohsnapshots und der unabhängige Reload des identischen Dokuments sind erhalten.
  Vier zusätzliche Koordinatenwerte belegen Chromiums behaltene Auswahl nach
  `position-try-order`-Wechsel: Der Standard verlangt die Rücksetzung dieser
  fallback-sensitiven Änderung, und der Reload identischer Quellen bestätigt
  die neue Auswahl. Insgesamt sind 15 Geometrie-/ein Syntaxwert einzeln erklärt.

Beim Gesamtcode-/Regressionreview wurde außerdem eine fehlerhafte
Bool/Nil-Verknüpfung im generischen Längenparser korrigiert: ungültige Werte
außerhalb der erlaubten Ankergrößenfelder bleiben verworfen und überschreiben
keine frühere gültige Deklaration. Bestehende Textdekorationsnachweise bleiben
erhalten; es wurde keine pauschale neue Grammatik für andere Längen eingeführt.

Verifikation des Gesamtstands: 288 Engine-Suiten einschließlich isolierter
Ressourcen-/GC-/Abbauprüfungen bestanden. Die letzten spezifischen
Shorthand-/CSSOM-Korrekturen und die Entfernung einer doppelten verworfenen
Basisprobe bestehen zusätzlich in `AnchorReference`,
`JavaScriptAnchorCSSOM` und `JavaScriptCSSOMRendering`. 14 unabhängige
JavaScript-Geometriefälle, Projekt-/Dokument-/Registerprüfung, kalter Loader
mit 469 Abhängigkeiten und Rojo-Build bestanden. Struktureller Code-Review:
511 Engine-Dateien, 5.455 benannte Funktionen, 1.422 statische Abhängigkeiten,
keine Zyklen oder unaufgelösten Pfade. Das belegt die genannten Pfade mit
Ersatz-GUIs und Browserreferenzen, nicht alle nativen Studio-/FPS-Kombinationen.

Offen bleiben vollständiges `position-area` samt Fallback-Flächen,
sämtliche Fallback-Origin-/Rollbackregeln, Self-Alignment-/Area-Spiegelungen,
Area-spezifische Insets/Alignment/Overflow und exaktes Recording zum
ResizeObserver-Zeitpunkt. Implizite Defaultanker, neue `position-anchor`-Werte,
transformierte/sticky/animierte/gescrollte Ankergeometrie, Scrollkompensation,
vollständige Inline-/Fragment-/Pseudo-/Top-Layer-/Shadow-Namensauswahl,
verschachtelte Container-/Scope-Bedingungen von Definitionen und alle
Computed-Style-Member benötigen weiteren Ausbau. Die browsergleiche
CSSOM-Serialisierung eines durch Einzelwertmutation aufgebrochenen variablen
Pending-Shorthands ist nachgewiesen; sämtliche internen Pending-Kaskaden-
Kombinationen nach erneutem HTML-Attributparsen sind damit nicht bewiesen.
Native Roblox-Pixeloptik und
Frametiming sind getrennt zu bestätigen. Das Teilprofil schließt C02 nicht ab.

Grundlage: [CSS Anchor Positioning, Entwurf vom September 2026](https://drafts.csswg.org/css-anchor-position/).

### Selektor- und Dokumentzustände — 9. Oktober 2026

`DocumentLanguage` verarbeitet `Content-Language` aus ausdrücklich übergebenen
Hostoptionen und eingefügte HTML-Meta-Pragmas. Ein verarbeitetes Pragma bleibt
nach Attributänderung oder Entfernung wirksam; erneutes Einfügen verarbeitet
den neuen Inhalt. Templates, Shadow Trees, XML und fremde Namensräume ändern
die Dokumentvorgabe nicht. `:lang()` berücksichtigt diese Vorgabe auch bei
abgetrennten Elementen. Tatsächliche Metamutationen erreichen den montierten
CSS-/Paintpfad ohne Austausch von Controls oder Layout bei reinen Farbänderungen.

`:default`, `:in-range` und `:out-of-range` unterscheiden Defaultattribute von
aktuellen Werten, Formzuordnung und Baumreihenfolge. Zahlen-, Range- und
Zeittypen berücksichtigen gültige Grenzen, deaktivierte/readonly Felder,
Datalist und über Mitternacht laufende Zeitbereiche. Schrittfehler allein
sind kein Bereichsfehler. DOM-Abfragen lesen nun die aktuellen Controlrecords;
`option:checked` und relationale CSS-Regeln erhalten unabhängig gespeicherte
Auswahlzustände. Eine Wertänderung schreibt kein Defaultattribut um.

Nachweise: `DocumentLanguage` mit sieben aufgezeichneten Chromium-Sequenzen,
`FormSelectors` mit 57 Sequenzen und `JavaScriptCSSOMRendering` mit tatsächlichem
InputController, verwandten Elementen, Paint, GUI-Identität und Layoutzählung.
Browserbeobachtungen bleiben unverändert in den jeweiligen Fixtures. Vier
Sprachfälle sowie zwölf leere Felder ohne definierte Grenzen und ein Range-
Fall mit widersprüchlichen Grenzen haben ausdrücklich benannte normative
Erwartungen, weil das installierte Chromium vom aktuellen Standard abweicht.
Dies sind keine pauschal freigestellten Testfamilien und kein Studio-Pixelnachweis.

Grundlagen: [HTML-Dokumentsprache](https://html.spec.whatwg.org/multipage/semantics.html#pragma-set-default-language),
[HTML-Formularselektoren](https://html.spec.whatwg.org/multipage/semantics-other.html#pseudo-classes)
und [Bereichsgrenzen](https://html.spec.whatwg.org/multipage/input.html#have-range-limitations).
Gemeinsame rohe Validitätsflags, Kandidatenregeln, UnicodeSets-Patterns,
atomare Radiogruppen und geöffnete native Picker sind anschließend ergänzt;
54 zusätzliche native Sequenzen und gemountete Paint-/Identitätsfälle stehen im
[Formularprofil](FORMS.md#gemeinsame-validierung-und-geöffnete-picker--9-oktober-2026).
Übrige Validierungs-, Formularzustands- und Attributkombinationen bleiben Teil
von H05/C01; diese Ergänzung schließt nicht die gesamte Selektorfamilie ab.

### Selektornamen, Namensräume und Attributwerte — 10. Oktober 2026

[Selectors](../src/HTMLEngine/CSS/Selectors.luau) vergleicht Typen anhand von
Namespace und lokalem Namen. Präfixe ändern weder Typselektoren noch die Gruppen
von `nth-of-type`/`first-of-type`/`last-of-type`. Das ältere Datenprofil ohne
Namespacefeld entspricht weiterhin HTML; explizit leere Namespaces bleiben leer.
HTML-Namen werden am Selektor nach den Regeln des aktuellen Eigentümerdokuments
gefaltet. XML und fremde Namespaces behalten ihre Schreibweise. Derselbe bereits
kompilierte Selektor folgt damit Adoption zwischen HTML- und XML-Dokumenten.
[Stylesheet](../src/HTMLEngine/CSS/Stylesheet.luau) verändert diese Namen nicht
mehr pauschal beim Sammeln; funktionale und geschwistergefilterte Regeln benutzen
denselben Vergleich wie DOM-Abfragen und SVG-Kaskaden.

Die 46 im HTML-Standard benannten Attributwerte haben ihre automatische
von ASCII-Groß-/Kleinschreibung unabhängige Vergleichsregel ausschließlich auf HTML-Elementen in
HTML-Dokumenten und ohne Attributnamespace. Andere Werte bleiben exakt.
`i` erzwingt ASCII-Faltung, `s` erzwingt den exakten Vergleich; Nicht-ASCII-
Zeichen werden dabei nicht umgeschrieben. Namespace-Wildcards prüfen weiterhin
jedes passende Attribut, auch bei mehreren gleichnamigen Attributnamespaces.

[SelectorNames](../tests/SelectorNames.luau) prüft 163 eingefrorene native
DOM-Sequenzen und 86 tatsächliche Stylesheet-/Renderer-Paintfälle aus
[dem Capture](../scripts/capture-selector-names.cjs) und
[den Rohdaten](../tests/fixtures/selector-names-browser.json). 30 DOM- und vier
Paintdatensätze haben ausdrücklich getrennte Standarderwartungen: Chromium
faltet einige fremde Typ-/Attributnamen im HTML-Dokument und implementiert
den `s`-Wertflag noch nicht; zusätzliche Unterschiede betreffen zitierte
Sprachbereiche, einzelne Surrogates in Strings und das großgeschriebene
`OF`-Schlüsselwort. Die Rohbeobachtungen bleiben unverändert erhalten.
Zehn dieser Paintfälle prüfen explizite, leere und Defaultnamespaces in
`@scope`-Start-/Endgrenzen, funktionale Grenzen und ungültige Präfixe.
[ScopeRules](../src/HTMLEngine/CSS/ScopeRules.luau) erhält dazu die Namespacekarte
des aktuellen Stylesheets; Imports behalten ihre jeweils eigene Karte.
Zusätzliche Regressionen halten einen kompilierten Selektor über Adoption hinweg
und erhalten den linearen Geschwisterscan. Selektoren, Stylesheets, Formular-
selektoren und die Atelier-Grammatik bestanden ihren gemeinsamen Lauf. Der
Scope-Nachtrag besteht zusätzlich mit CSS-Regelfamilien, CSSOM-Regeln und dem
tatsächlich montierten CSSOM-Pfad.

Die gemeinsamen Scanner behandeln CSS-Whitespace ausdrücklich: vertikale
Tabulatoren und geschützte Leerzeichen werden nicht als normales Leerzeichen
repariert. Vor der Tokenisierung werden NUL, einzelne Surrogates und die
CSS-Zeilenenden verarbeitet, ohne gespeicherte DOM-Namen oder Werte zu ändern.
Stringtokens, Escape-Terminierung und Kommentargrenzen sind gegen einfache,
hexadezimale und ergänzende Unicode-Zeichen sowie ungültige Newlines geprüft.
Die `An+B`-Grammatik wird einmal beim Kompilieren gelesen; getrennte Zahlen/
Dimensionen, Dezimal-/Exponentenformen und ungültige Vorzeichenkombinationen
werden verworfen. Gefilterte Geschwister benutzen dieselben kompilierten
Koeffizienten. Kommentare erzeugen keine zusätzlichen Nachfahrenselektoren.
Echte CSSOM-Regelzahlen, kanonische Selektorstrings und Scope-Grenzen gehören
zu den Paintdatensätzen; ungültige Selektoren werden beim Einlesen nicht
durch pauschales Trim oder Formatieren gültig gemacht. Sieben betroffene
Selektor-/Stylesheet-/CSSOM-Suiten bestehen; der isolierte native Capture
wurde ohne Aktualisieren erneut gegen alle gespeicherten Ergebnisse geprüft.

`:has()` verwirft auch leerraumgefüllte relative Listen und leere Kommaeinträge,
bevor der interne Scopeanker hinzugefügt wird. Sein Kompilierkontext verbietet
inneres `:has()` durch `:is()`/`:where()`/`:not()` und `nth-child`-/`nth-last-child`-
Filter hindurch. Forgiving Listen behalten gültige Geschwisterzweige; verworfene
Zweige tragen keine Spezifität bei. Die strikten Listen von `:not()`, `:has()`
und den Geschwisterfiltern bleiben strikt.
[RelationalSelectors](../tests/RelationalSelectors.luau) prüft 41 Grammatikfälle,
21 tatsächliche DOM-/CSSOM-Fälle, acht Spezifitäts-/Renderergewinner einschließlich
Nesting und neun montierte Paintzustände aus
[dem isolierten Capture](../scripts/capture-relational-selectors.cjs) und
[seinen Rohdaten](../tests/fixtures/relational-selectors-browser.json).
Die Paintfolge erhält das ursprüngliche Textlabel, Boxen, GUIs, Inputwert und
rückwärts gerichtete Selektion. Ungültiges `selectorText` lässt die bestehende
Regel bestehen; ungültiges `insertRule` wirft ohne Einfügen. Eine reine
Farbänderung an der gültigen relationalen Regel aktualisiert Paint ohne Layout.
Der gezielte gemeinsame Lauf der elf betroffenen Selektor-, Stylesheet-,
Namespace-, Quirks-, CSSOM- und Componentsuiten besteht; `AttributeNamespaces`
behält seinen vorgeschriebenen isolierten Nachlauf.

Die Rohstrings nativer forgiving CSSOM-Serialisierung bleiben erhalten;
[CSSWG #3676](https://github.com/w3c/csswg-drafts/issues/3676) ist offen und wird
hier nicht durch pauschales Entfernen aller ungültigen Textzweige entschieden.
Ein Bad-string-Token bleibt gemäß
[CSS Syntax `<any-value>`](https://www.w3.org/TR/css-syntax-3/#any-value)
ein Fehler vor der forgiving Listenauswertung, auch wenn Chromium im erfassten
DOM-Fall einen gültigen Restzweig akzeptiert. Chromiums EOF-Funktionsschluss und
die entsprechende bestehende DOM-Parserlücke werden getrennt ausgewiesen.
Die benannten Defaultnamespace-Ausnahmen und der künstliche :has()-Anker
sind im Nachweis vom 13. Oktober ergänzt; implizite @scope-Kontexte bleiben offen. Diese Ergänzung erfüllt die
benannten relationalen Fehler- und Spezifitätsfälle nach
[Selectors 4 `:has()`](https://www.w3.org/TR/2026/WD-selectors-4-20260122/#relational)
und [forgiving Listen](https://www.w3.org/TR/2026/WD-selectors-4-20260122/#forgiving-selector);
weitere Selektor-/Namespacekombinationen innerhalb C01 bleiben offen.

Maßgeblich: [HTML-Vergleichsregeln](https://html.spec.whatwg.org/multipage/semantics-other.html#case-sensitivity-of-selectors),
[Typselektoren](https://drafts.csswg.org/selectors-4/#type-selectors) und
[typisierte Geschwister](https://drafts.csswg.org/selectors-4/#the-nth-of-type-pseudo).
Tokenregeln: [CSS-Preprocessing](https://drafts.csswg.org/css-syntax-3/#input-preprocessing),
[Stringtokens](https://drafts.csswg.org/css-syntax-3/#consume-string-token) und
[An+B](https://drafts.csswg.org/css-syntax-3/#anb-microsyntax).
Die Überschriftenselektoren `:heading` und `:heading(<integer>#)` verwenden
HTMLs berechnete Ebene statt des qualifizierten Tagnamens. Die gemeinsame
Integer-Token-Grammatik verwirft Dezimal-, Exponenten-, Dimensions-, String-
und getrennte Vorzeichenformen; Spezifität und CSSOM-Serialisierung folgen
dem vorhandenen Selectors-5-Entwurfsprofil. Live Offsets/Reset, Namespacegrenzen,
DOM-Reparenting und Shadow-Hosts sind in
[HeadingSelectors](../tests/HeadingSelectors.luau) geprüft. Neun montierte
Farbszenen mit relationalem `:has()` aktualisieren die ursprünglichen Labels,
Hintergründe und Editorflächen ohne Layout, neue GUI oder Auswahlverlust.

Die [native Referenz](../tests/fixtures/heading-browser.json) hält 35 IDL-
Kontrollen und 26 rohe Accessibility-Ebenen getrennt von Standarderwartungen.
Diese Aufnahme aktiviert ausdrücklich Chromiums experimentelles `HeadingOffset`;
gewöhnliches Chromium 154 besitzt die IDLs noch nicht und verwirft die Selektoren.
Vier Accessibility-Abweichungen und drei Getter-Grenzabweichungen bleiben
unverändert erhalten. Das ist keine Behauptung nativer Selektorunterstützung.
Grundlagen: [HTML-Ebenen](https://html.spec.whatwg.org/multipage/sections.html#heading-levels-&-offsets)
und [Selectors-5-Entwurf](https://drafts.csswg.org/selectors-5/#heading-pseudo).

Weitere Pseudozustände, vollständige Namespace-/Shadow-Grammatik und sämtliche
kombinatorischen Invalidierungen bleiben innerhalb C01 offen.

`:dir()` liest genau einen CSS-Identtoken mit Escapes und Kommentargrenzen.
Unbekannte Bezeichner sind gültig und treffen kein Element; Strings und mehrere
Tokens sind ungültig. CSSOM bewahrt die Schreibweise des dekodierten Arguments.
25 native Grammatikproben und acht Regel-/Paintfälle prüfen diese Grenzen.
Grundlage: [Selectors-4-Richtung](https://drafts.csswg.org/selectors-4/#the-dir-pseudo).

Die acht Expanded-Name-Linksequenzen unterscheiden HTML-Anker/Areas und
SVG-Anker. SVG erkennt das gewöhnliche `href` und das echte XLink-Attribut
unabhängig vom Präfix; ein bloßer Attributname `xlink:href` ohne Namespace
erzeugt keinen Linkzustand. Die Nachweise betreffen DOM-Selektoren; sie erklären
nicht sämtliche SVG-Navigations-/Paintpfade für abgeschlossen.
Grundlage: [SVG-Anker](https://www.w3.org/TR/SVG2/linking.html#AElement).

`:root` benutzt den gemeinsamen Dokumentelementzugriff und den tatsächlichen
Dokument-Elternknoten. Losgelöste Elemente, Fragment- und Shadow-Kinder treffen
den Selektor nicht. Zwei native Sequenzen prüfen Einfügen, Entfernen und
Dokumentwechsel einschließlich XML; `:scope` bleibt bei `matches()` auf das
jeweils abgefragte Element bezogen. Ohne expliziten Abfragescope trifft
`:scope` die Dokumentwurzel; drei normale Stylesheet-Paintfälle prüfen den
Wurzelstil, davon abhängige Kindselektoren und die nicht getroffenen Nachfahren.
Grundlage: [Dokumentwurzel](https://drafts.csswg.org/selectors-4/#root-pseudo).

`:state()` verwendet denselben CSS-Identtoken: Unicode, einfache/hexadezimale
Escapes, escaped führende Ziffern und Satzzeichen, exakte Groß-/Kleinschreibung
und Kommentargrenzen werden unterstützt. Strings, einzelne Bindestriche,
unescaped Zahlen und zusätzliche Tokens werden verworfen. CSSOM serialisiert
den dekodierten Namen wieder als CSS-Bezeichner. Die 13 zusätzlichen nativen
Zustandssequenzen und acht tatsächlichen Paint-/Regelbaumfälle bleiben in der
obigen Referenz gespeichert. `JavaScriptComponentsRendering` belegt zudem
escaped Shadow-Host-Zustände am tatsächlich behaltenen Rahmenmodifier samt
Löschung, layoutfreier Aktualisierung, Editoridentität und backward Selection.

Der folgende DOM-/Formularabgleich verwendet den vorhandenen gemeinsamen
[ElementNames](../src/HTMLEngine/DOM/ElementNames.luau)-Pfad auch für
HTML-Pseudozustände. `disabled`/`enabled`, Validierung, Auswahl, Offen-Zustände,
Links und `defined` prüfen den HTML-Namespace und den lokalen Namen;
fremde oder ausdrücklich namespacefreie Namensvettern werden nicht zu
HTML-Controls. Die tatsächlichen Custom-Element-Zustände berücksichtigen
auch noch nicht definierte angepasste Builtins. Öffentlich sichtbare QNames
werden dabei nicht verändert. Formularbesitzer und Radiogruppen verwenden
[FormOwner](../src/HTMLEngine/DOM/FormOwner.luau), einschließlich
Tree-Scope- und Parser-Assoziationen, statt eigener ID-/Ancestor-Suchen.
[HTMLExpandedNames](../tests/HTMLExpandedNames.luau) prüft acht native
Pseudo-Datensätze neben den 58 DOM-/Formular-Datensätzen (55 exact native,
drei getrennte normative FormData-Abweichungen). Der gemeinsame Lauf aus
15 Selektor-, Formular-, CSS-/CSSOM-, Quirks- und Sprachsuiten besteht.
Maßgeblich sind die [HTML-Pseudozustände](https://html.spec.whatwg.org/multipage/semantics-other.html#pseudo-classes).
DOM/CSS/native Eingabe verwenden nun denselben reinen
[EditingHost](../src/HTMLEngine/DOM/EditingHost.luau)-Pfad für geerbte,
case-insensitive und Plaintext-Zustände, geschützte Inseln und unabhängige
Shadow-Hosts. `designMode` löst nur bei einer echten Änderung die gemeinsame
Selektorinvalidierung aus. Eingabetypselektoren benutzen den normalisierten
Controltyp; Placeholder-Zustände gelten nur für Typen, die diese Darstellung
besitzen. [EditingSelectors](../tests/EditingSelectors.luau) besteht mit
76 exakten Browserergebnissen und 15 getrennten normativen Abweichungen;
die rohe Referenz bleibt gespeichert. 14 zusätzliche native Paintzustände
belegen tatsächliche Text-/Control-/Ancestorfarben ohne Layout, GUI-Neuaufbau
oder Verlust der Editor-Auswahl. Einzelheiten und Restfälle stehen im
[Editingprofil](JAVASCRIPT-EDITING-R04.md).
Weitere Editing-, Host-/Renderadapter und Zustand-/Namespacekombinationen
bleiben ausdrücklich offen; die Namenskorrektur ersetzt keinen vollständigen
Nachweis jeder Pseudofamilie.

## Dynamischer Buchstabenabstand – 11. Oktober 2026

`letter-spacing` wird nach DOM-/CSSOM-, Klassen-, Variablen-, Schrift- und
Containeränderungen auf die aktuellen Wortstile übertragen. Relative Werte
verwenden die endgültige CSS-Schriftbasis; geerbte berechnete Abstände bleiben
absolute Werte, auch wenn ein Kind eine eigene Schriftgröße besitzt. `em`,
`rem` und der von Container-Einheiten abhängige Schriftwechsel sind durch
unabhängig aufgenommene Browserwerte belegt.

`normal`/`0` und positive/negative Abstände wählen den tatsächlich benötigten
Wortlabel- oder Graphemlabelmodus. Bei einem Moduswechsel werden nur die
betroffenen gerenderten Textbesitzer erneuert; DOM-Textknoten bleiben erhalten.
Nichtnull-Änderungen mit gleicher Quellgruppierung behalten vorhandene Glyphen,
GUIs und passende native Messwerte. Erhaltener Leerraum behält seinen leeren
Frame und erhält neue Breiten statt unnötiger Glyphen-Neuerzeugung.

Quellgruppen werden erst nach der vollständigen Neukaskadierung geprüft.
Verschiedene ursprüngliche Quellstile verwenden dieselbe unveränderte
`InlineWords.sameStyle`-Regel wie die erste Tokenisierung. Neue Abstands-,
Schriftfamilien-, Größen-, Gewichts- und Variantenunterschiede teilen einen
früher gemeinsam gezeichneten Wortbestand; wieder gleiche Stile können ihn
auch vor dem ersten Layout zusammenführen. Explizite `wbr`- und automatische
Leerraumgrenzen werden dabei nicht entfernt. Der vorhandene begrenzte
Refresh-/Reconcile-Pfad bleibt für den tatsächlichen Neuaufbau zuständig.
Die Gruppierung verwendet den vorhandenen Tokenizer; die Prüfung erfolgt
ausschließlich bei relevanten Änderungen.

Tabellarische Ziffern berücksichtigen ihren Zustand auch im Schlüssel der
behaltenen Glyphenmessungen. Der Boolwert `false` wird bei einer reinen Probe
ausdrücklich übernommen, damit die Rückkehr von tabellarischen zu
proportionalen Ziffern keinen alten Schlüssel behält. Glyphenlabels wechseln
ihre Ziffernausrichtung ohne Ersetzen der GUI. Unvollständige oder abgebrochene
Proben veröffentlichen keine neuen Cachewerte; Wiederaufnahme und warme
Folgemessungen sind in beiden Richtungen geprüft.

Dauerhafter Nachweis:
[LetterSpacingDynamic](../tests/LetterSpacingDynamic.luau),
[native Referenz](../tests/fixtures/letter-spacing-dynamic-browser.json) und
[Browseraufnahme](../scripts/capture-letter-spacing-dynamic-reference.cjs).
Die 24 rohen Browserzustände liefern 156 Vergleiche aktueller Schrift-/Abstands-
werte. Sie bewahren zusätzlich rohe Range-/Graphemmaße, ohne diese als
Roblox-Pixelgleichheit auszugeben. Sieben Klassen-/Variablenzustände mit
sechs tatsächlichen Mutationen prüfen daneben CSSOM und feste
Kindüberschreibungen. Split/Merge
prüft originale Quellknoten, UTF-16-Auswahlgrenzen, kopierten Text `BC` und
neu angeordnete B/C-Selection-Overlays einschließlich aktueller GUI-/Treffer-
besitzer und Abbau der früheren Overlays. Die Paintgeometrie verwendet dabei
kontrollierte Host-Textmaße, keine Behauptung browsergleicher Schriftformung.
Der aktive native Editor behält Wert, Fokus und Auswahl; seine tatsächliche
Glyphen-Abstandsdarstellung ist damit ausdrücklich **nicht** nachgewiesen.

Im Register gehören diese eng geprüften Teile zu `live-resolved-values`,
`live-glyph-mode`, `live-source-groups` und `measurement-cache`. Die tatsächliche
Min-/Max-Content-Abfrage sieht neue Abstände, ohne vorläufige Glyphenpositionen
auf dem Bildschirm zu veröffentlichen. Warme Messungen, Moduswechsel mit
kaltem Abbruch und Tabular-Rückwechsel mit Abbruch/frischer Wiederaufnahme
bleiben geprüft. Kerning, Ligaturen, verbundene Schriften, allgemeine Bidi-/
Vertikal-/Fragmentkombinationen, die vollständige Eigenschaftsgrammatik und
native Studio-Optik/FPS bleiben eigene offene oder ungeprüfte Anforderungen;
dies schließt C04 und die gesamte Eigenschaft nicht ab. Chromiums rohe äußere
Trackingkante bleibt von der bestehenden normativen Zeilenrandregel getrennt.
Maßgeblich: [CSS Text 3, Buchstabenabstand](https://www.w3.org/TR/2026/CRD-css-text-3-20260814/#letter-spacing-property).

Referenzen: [CSS Cascade 5](https://www.w3.org/TR/css-cascade-5/),
[Selectors 4](https://www.w3.org/TR/selectors-4/),
[Media Queries 4](https://www.w3.org/TR/mediaqueries-4/),
[CSS Values 4](https://www.w3.org/TR/css-values-4/),
[CSS Color 4](https://www.w3.org/TR/css-color-4/),
[CSS Color 5](https://www.w3.org/TR/css-color-5/),
[Scroll Animations](https://www.w3.org/TR/scroll-animations-1/),
[Anchor Positioning](https://www.w3.org/TR/css-anchor-position-1/),
[Typed OM](https://www.w3.org/TR/css-typed-om-1/),
[Custom Highlights](https://www.w3.org/TR/css-highlight-api-1/).

## Position-Alignment in horizontalen Flex- und Gridcontainern – 11. Oktober 2026

Dieser C03-Nachweis betrifft Positionen fester physischer Itemboxen in
horizontalen Containern. `start/end` verwenden die Containerkante,
`self-start/self-end` die entsprechende Kante des Items und
`flex-start/flex-end` die gegebenenfalls umgekehrte Flexachse. Die vorhandene
`WritingMode.side`-Auflösung berücksichtigt dabei auch feste Items mit
`vertical-rl`, `vertical-lr`, `sideways-rl` und `sideways-lr` sowie deren
LTR-/RTL-Richtung. Der neue gemeinsame Kantenresolver ersetzt keinen
Größen- oder Achsenalgorithmus. Vertikale Container behalten ihren bisherigen
Layoutpfad.

Die geprüften Eigenschaftsachsen sind `align-items/align-self` auf der
Flexquerachse (Y bei Row, X bei Column) und auf Grid-Y,
`justify-items/justify-self` auf Grid-X sowie `justify-content` auf den
Flexhauptachsen X/Y und auf Grid-X. Row-/Column-Reversal, Wrap-Reverse und
Container-/Itemrichtung werden getrennt aufgelöst. `left/right` wirken bei
Justify physisch; auf der Column-Flex-Hauptachse entsprechen beide `start`.
Auf `align-items/align-self` werden diese beiden ungültigen Werte weiterhin
abgewiesen. `align-content` erhält durch diesen Abschnitt keinen neuen
Vollständigkeitsnachweis.

Grid projiziert zuerst die Area in physische Koordinaten und richtet dann
das Item darin aus. Eine bereits aufgelöste Self- oder physische Kante wird
bei RTL nicht nochmals gespiegelt. Bestehende Box- und Trackgrößen bleiben
Teil des Vergleichs. Positive automatische Margins nehmen den freien Platz
vor der Ausrichtung auf; physische, asymmetrische Margins bleiben dabei
physisch. Bei Übergröße unterscheiden sich die Modelle ausdrücklich:
Flex löst Querachsen-Automargins an der Block-/Inline-Startseite des
Containers auf und unterdrückt danach Self-Alignment; Grid setzt
überlaufende Automargins auf null und verwendet anschließend Box-Alignment.

`scripts/capture-position-alignment-reference.cjs` erfasst unabhängig
177 Fälle mit 532 rohen Chromium-Zuständen sowie drei retained Folgen mit
insgesamt 48 Zuständen. Der gepaddete Stage hält diese festen Boxen von
unzugänglichen Rootscroll-Kanten fern. Die Aufnahme liegt unverändert in
`tests/fixtures/position-alignment-browser.json`; Boxgrößen und verwendete
Gridtrackgrößen gehören zum Beleg. Zwölf rohe Gridzustände mit
überlaufenden Automargins zeigen eine ausdrücklich gespeicherte
Chromium-Abweichung von Grid 2 §11.2. Zusätzlich aufgenommene entsprechende
Null-Margin-Kontrollen liefern unabhängig die normgeforderte Geometrie.
Der Test benennt diese zwölf Normdeltas getrennt und ersetzt keine rohe
Browsererwartung. Diese Gegenprobe ist keine allgemeine Abnahme impliziter
Scrollsicherheit.

`tests/PositionAlignment.luau` prüft sämtliche 580 Zustände über den
tatsächlichen Controller-/JavaScript-/Dirty-Layout-Pfad. Drei montierte
Folgen ändern Klassen, Variablen, CSSOM, Richtung, Kontext und freie Größe
für Item-, eigene Self- und Content-Alignmentwerte. DOM-Knoten und GUIs, Editorbindungen,
bearbeiteter Wert und Fokus bleiben erhalten. Die UTF-16-Auswahl über ein
Emoji (1–3, rückwärts) behält zugleich die nativen TextBox-Bytepositionen
2 und 6. Tatsächliche native Eingabeereignisse funktionieren anschließend
weiter; Cleanup trennt die montierten Controller-/Editorbindings. Ein
tatsächlich ausstehender Timer und Animation-Frame werden zusätzlich vor
Cleanup angelegt: Event-Loop-Zähler, Frame-/Statusbindungen und ScriptClock
enden, jede native Timerplanung wird genau einmal abgebrochen. Die frischen
Paritätsbäume besitzen keinen eigenen Controller oder Runtime. Jeder
Zustand wird außerdem mit unabhängigem vollständigem Layout verglichen.
Warme Folgeanordnung benötigt keine erneuten Textmaße oder Oberflächen.
Die vorhandenen vier unveränderten `self-start`-Rohkontrollen des
Column-Flex-Quergrößentests werden zusätzlich ausgeführt; dieser umfasst
damit 122 Zustände und 362 Boxmaßvergleiche.

Die Grundlage bleibt der eingefrorene Zielbestand vom 6. Oktober 2026:
[CSS Align 3, datierter Entwurf vom 30. Januar 2026](https://www.w3.org/TR/2026/WD-css-align-3-20260130/),
[Flexbox 1, datierter Entwurf vom 14. Oktober 2025](https://www.w3.org/TR/2025/CRD-css-flexbox-1-20251014/#cross-alignment)
und [Grid 2, datierter Entwurf vom 26. März 2025](https://www.w3.org/TR/2025/CRD-css-grid-2-20250326/#auto-margins).
Die neue Grid-2-Positionsaufnahme ist von der älteren Grid-1-Aufnahme
getrennt. Die eingefrorene Webref-Grammatik verwendet Commit
`c6e1630adecd5acac338fd9166232ff3324b6781` und SHA-256
`4860d2a9ad90814a61888e8b2d879651fd523c0d3926eecfe4548b4dd60a20eb`.
Spätere Änderungen des Align-Entwurfs vom 8. Oktober werden hier nicht
stillschweigend in das Ziel übernommen.

Offen bleiben vollständige vertikale Containerachsen und intrinsische
orthogonale Größen, Baseline-/Fragmentkombinationen, weitere Modifier-/Layoutkombinationen,
implizite Scrollsicherheit in allen Hosts, vollständige Longhand- und
Shorthandgrammatik samt CSS-weiten/Variablenkombinationen sowie native
Font-/Glyphenformung und die Studioabnahme. Dieser begrenzte Positionsbeleg
schließt weder ganz C03 noch die vollständigen fünf Alignmentdefinitionen.

## Ausgeblendete Inhalte und erhaltene Objekte – 11. Oktober 2026

`content-visibility:hidden` trennt im geprüften Blockprofil die eigene Box
von ihren Nachfahren. Rahmen und eigener Hintergrund bleiben bestehen;
Nachfahren nehmen nicht an der aktiven Anordnung, Darstellung, Trefferprüfung,
Fokusreihenfolge oder gerenderten Textauswahl teil. Bereits erstellte GUI-,
Bild- und Editorobjekte bleiben erhalten. Ein passiver Inhaltsframe verdeckt
die normalen Nachfahren gemeinsam; Fixed- und Top-Layer-Flächen werden über
denselben übersprungenen DOM-Vorfahren geprüft.

Erstmals verborgene gewöhnliche Inhalte werden erst beim Einblenden aufgebaut,
aus dem dann aktuellen DOM. Textänderungen, Hinzufügen und Entfernen unter
der verborgenen Box benötigen vorher weder neue GUIs noch Bildauflösung.
Die erste Veröffentlichung erfolgt nach gültiger Geometrie. Eine kleine Menge
wartender Inhaltsbesitzer ersetzt einen Vollscan bei jedem Layoutcommit;
gewöhnliche Boxen erhalten keinen eigenen Tabellen-Preparation-Closure.
Warm und erstmals eingeblendete Tabellen benutzen denselben Helper.

Die tatsächlichen Controller-/JavaScript-/Dirty-Layout-Pfade prüfen Editorwert,
Fokusverlust, abgewiesene verborgene Fokusversuche und erhaltene UTF-16-Auswahl
über ein Emoji. Dokumentauswahl entfernt echte Overlays und gerenderten
Kopiertext aus verborgenen Nachfahren. Verschachtelte Bereiche, aufgeklappte
`details`, Fieldset-Legenden, neue Tastaturlinks und Block-/Tabellenwechsel
werden über denselben Pfad geprüft. Neue Links aktualisieren den vorhandenen
Fokusindex einmal beim Aufbau. Tabellenmodelle bleiben bei einem Wechsel zu
`display:block` gespeichert, wirken dort aber nicht auf Größen oder Anordnung;
anonyme Tabellenboxen bleiben innerhalb des gemeinsamen Inhaltsframes.

[Native Aufnahme](../tests/fixtures/content-visibility-browser.json),
[Capture](../scripts/capture-content-visibility-reference.cjs) und
[montierter Test](../tests/ContentVisibilityRendering.luau) bewahren 82
Rohzustände: 79 direkte native Vergleiche, zwei ausdrücklich normative
Tabellenzellen-Kontrollen und eine getrennte Browser-Hostgrenze. Im einzigen
Link-/Input-Fall verlässt Tab nativ die Seite zum Chrome-Fenster; der aktuelle
Roblox-Seitenzyklus bleibt im Editor. Diese Abweichung wird gespeichert und
nicht als Parität ausgegeben. Eine zusätzliche Folge mit weiterem Seitencontrol
belegt unabhängig, dass Tab verborgene Links überspringt.

Die eingefrorene Zielquelle ist der letzte CSSWG-Contain-2-Stand vor dem
6. Oktober: Commit `9b290faedc95e9f93648fb5f5c675c75508c2d14` vom 23. Juni 2026,
SHA-256 `5a8dbbd4c6a8bccd661c5bb7b66275da9cfb5a93b206f2124cc6f60cfd6ccc4d`.
Der Capture prüft diese unveränderliche Quelle. Sie bindet die Anwendbarkeit
an Size Containment; innere Tabellen und interne Tabellenboxen sind davon
ausgenommen. Die bereits seit Oktober 2022 bestehende Regel ist von der
älteren veröffentlichten Septemberfassung getrennt. Chromium überspringt
in zwei gespeicherten Zuständen trotzdem Tabellenzellen. Die Engine folgt
hier der eingefrorenen Norm; beide Rohabweichungen bleiben ausdrücklich erhalten.
Quellen: [festgehaltener Contain-2-Text](https://raw.githubusercontent.com/w3c/csswg-drafts/9b290faedc95e9f93648fb5f5c675c75508c2d14/css-contain-2/Overview.bs)
und [historische Applicability-Änderung](https://github.com/w3c/csswg-drafts/commit/5cf431ca4d20bab1496da8bb55e9d05446d31015).

Ein eigener [Top-Layer-Test](../tests/ContentVisibilityTopLayerRendering.luau)
mit [22 nativen Rohzuständen](../tests/fixtures/content-visibility-top-layer-browser.json)
und [Capture](../scripts/capture-content-visibility-top-layer-reference.cjs)
prüft bereits montierte Dialoge und Popovers. Ein verborgener Vorfahr entfernt
Fenster, Backdrop und gemeinsame Layerfläche aus der Darstellung. Logischer
Open-/Modal-/Popoverzustand und die Modal-Sperre bleiben bestehen; auch die
Hintergrundcontrols erhalten deshalb keinen Fokus. Erneutes Einblenden verwendet
die ursprünglichen Oberflächen. Escape und Pointer-Light-Dismissal funktionieren
auch verborgen; alte Fensterrechtecke zählen dabei nicht als sichtbare Treffer.
Ist nur der Top-Layer-Besitzer selbst `content-visibility:hidden`, bleibt dessen
eigene Box samt Backdrop sichtbar und nur der Inhalt wird übersprungen.

Die CLI-Prüfung verwendet tatsächliche Enginepfade mit kontrollierten GUI-/
Fontadaptern. Sie prüft Sichtbarkeit, Mitgliedschaft, Fokus, Treffergrenzen und
Abbau; die nativen Backdrop-Pixel sind zusätzliche Referenz, kein vollständiger
Engine-Pixel-/XYWH-Abnahmenachweis. Die unabhängige Nachprüfung umfasst auch
Canvas, Details, Tabelleninvalidierung, Fieldsets und JavaScript-Tabellen.
Linkindex-, Legend- und Tabellenwechselbefunde wurden im gehaltenen Stand behoben.

Drei begrenzte Anforderungen sind damit im einzigen CSS-Register erfüllt.
Offen oder ungeprüft bleiben übrige Display-/Replaced-/Ruby-/Inline-Anwendbarkeit,
Containment-/intrinsische Größen, vollständige Clipping-/Fragment-/Observer-
Kombinationen, erstmals unaufgebaute Top-Layer-Knoten, allgemeine Modal-/Shadow-
Stacks, deferred Hover-/Media-/Container-/Ressourcenwechsel, `auto` samt
Viewportrelevanz und Timing sowie die native Studio-Optik und Framekosten.
Diese Nachweise schließen weder `content-visibility` insgesamt noch C03/C07 ab.

## Explizite Overflow-Ausrichtung – 12. Oktober 2026

`safe` und `unsafe` werden gemeinsam als geordnete Positionsmodifikatoren
geparst. Berechnete CSSOM-Werte bleiben kanonische Keywordstrings. Passende
Boxen behalten die verlangte Ausrichtung; bei übergroßen Marginboxen fällt
explizites `safe` gemäß der eingefrorenen Align-3-Fassung auf `flex-start`
zurück. Reversal und RTL bleiben Teil dieser Kantenauflösung. Positive Auto-
Margins haben weiterhin Vorrang; Flexquerachsen und Grid benutzen ihre
unterschiedlichen Overflow-Marginregeln. Stretch, Baselines und verteilte
Werte erhalten keinen unzulässigen Sicherheitsmodifikator.

Die gültige eingefrorene Self-Grammatik enthält auch qualifiziertes `normal`.
Es behält den vorhandenen Normal-/Auto-/Min-/Max-Größenpfad vor der
Positionsauflösung. Vorhandene Flex-Static- und Anchor-Area-Pfade verwenden
denselben Resolver. Explizite Sicherheitswerte bleiben von der bisherigen
automatischen Abspos-Union-Regel getrennt; deren native Äquivalentkontrollen
verwenden bei Bedarf `unsafe flex-start`, damit diese Regel nicht erneut
aktiviert wird. Normale Positionswerte behalten den bisherigen Pfad.

[OverflowAlignment](../tests/OverflowAlignment.luau) prüft 962 montierte Zustände/
3.896 Boxvergleiche mit erhaltenen DOM-/GUI-/Editorobjekten, Fokus, Werten,
rückwärtiger Emoji-Auswahl, echten Eingabeereignissen danach und Timer-/Frame-
Cleanup. Warme Layouts benötigen keine erneuten Textmaße oder Oberflächen.
Jeder Zustand wird zusätzlich mit einem frischen vollständigen Layout
verglichen; positionierte Boxen prüfen tatsächliche Paint-/GUI-Koordinaten.
Die [rohen Nativecaptures](../tests/fixtures/overflow-alignment-browser.json)
und [gefrorenen Gegenparts](../tests/fixtures/overflow-alignment-frozen.json)
sind getrennte Testargumente. 914 Zustände sind rohe Eingangszustände mit 861 unveränderten Nativevergleichen und 53 getrennten Normprojektionen, 48
qualifizierte-normal-Zustände sind benannte Äquivalente. Dieselben 53
Native-/Norm-Geometriedeltas und sieben Qualified-Normal-Grammatikdeltas bleiben
explizit gespeichert. 108 Longhand- und 42 Positions-Shorthand-Proben gehören
zum Nachweis; 15 rohe Baseline-Grenzproben schließen keine neue Baselinefamilie.

Unveränderte PositionAlignment 580/2.840 und 15 weitere Nachbarsuiten bestehen
im tatsächlichen 17-Suiten-Lauf; der kanonisch getrennt verpackte Test besteht
anschließend gemeinsam mit PositionAlignment. Die historische FlexWrap-
Negativprobe für nun gültiges `safe center` ist als vollständiges Original
erhalten: dieselbe Negativprüfung verwendet `safe stretch`, daneben steht
eine zusätzliche strikte Akzeptanzkontrolle. Kein Skip und keine Engine-
Sonderbehandlung. Quelle: [Align 3 vom 30. Januar 2026](https://www.w3.org/TR/2026/WD-css-align-3-20260130/);
Originaldatei-SHA 7361249cbb73d90e811e6eb7f8cd5bc4de5bbb81c2a7add6d1cbcb9dfd800d37.

Die sechs neuen Registeranforderungen begrenzen die jeweiligen Rollen einzeln: Items-Defaults auf den erfassten In-flow-Kindern, justify-items auf Grid, align-content auf Flexzeilen/Gridreihen, justify-content auf Flexhauptachse/Gridspalten und den erfassten Flex-Static-Fällen sowie Self-Ausrichtung auf den erfassten In-flow-/Area-Fällen. Die gemeinsamen 962 Zustände belegen keine vollständige Kreuzkombination jeder Eigenschaft mit allen Größen und Aufrufern. Qualifiziertes normal gilt für Self-Eigenschaften einschließlich der place-self-Expansion.

Vertikale Container, vollständige Baseline-/Fragment-/intrinsische/replaced
Kombinationen, allgemeine Abspos-Pfade ohne Area, automatische Scrollsicherheit
und native Studiooptik/Framekosten bleiben offen. Sechs eng abgegrenzte
Anforderungen werden im einzigen CSS-Register ergänzt; bestehende offene
Anforderungen ändern dadurch ihren Stand nicht. Kein C03-/Eigenschafts-
oder Gesamtabschluss.

## Defaultnamespace-Ausnahmen funktionaler Selektoren – 13. Oktober 2026

Der gemeinsame Selektorkompiler nimmt nur implizite rechte Subjects innerhalb
von `:is()`, `:where()` und `:not()` vom Defaultnamespace aus. Ein expliziter
Typ oder Universal, äußere Compounds, nichtrechte Vorfahren und direkte
Nth-Filter behalten ihre Namespacebindung. Für `:has()` wird ausschließlich
der künstliche erste Scopeanker ausgenommen; die relativen Autorencompounds
bleiben gebunden. Spezifität, Quirks-Ausnahmen und Nested-has-Verbote bleiben
erhalten. Ohne Defaultnamespace entstehen keine neuen Compiler-Hilfstabellen.

[DefaultNamespaces](../tests/DefaultNamespaces.luau) vergleicht 265 rohe
Attributkontext-Fälle mit 6.360 Subjects: 6.261 unveränderte Nativevergleiche
und 99 ausdrücklich getrennte gefrorene Projektionen. 20 unabhängig
erfasste explizite Gegenproben liefern weitere 480 Subjects. Dazu kommen zwei
tatsächliche DOM-Sequenzen, sechs Spezifitätsgewinner und eine unabhängige
explizite Gegenprobe mit 18 getrennten Spezifitätsprojektionen sowie acht
Autoren-Scopes mit ausdrücklich gesetztem Any-Namespace-Scopeanker. Diese
Scopes sind eigene Kontrollen, keine umbenannten impliziten Rohfälle.

Chromium 154 weicht im Capture bei `:where(valid, unknown|*)` (72 Subjects),
impliziten Geschwistertargets in `:has(+)` (12) und `:has(~)` (6) sowie
mehreren inneren ID-Attributsubjects in `:is()` (9) von den benannten
[frozen Selectors-4-Regeln vom 22. Januar](https://www.w3.org/TR/2026/WD-selectors-4-20260122/#matches)
ab. Die 18 zusätzlichen Spezifitätsprojektionen betreffen den Defaultnamespace
in `:is([data-hit], #no)`. Die [Rohdaten](../tests/fixtures/default-namespace-browser.json),
[expliziten Gegenproben](../tests/fixtures/default-namespace-frozen.json) und
[weiteren Kontextdaten](../tests/fixtures/default-namespace-context-browser.json)
bleiben getrennte Testargumente. Ein erster Klassen-Capture zeigt außerdem
abweichende native Stylesheetfarben bei generischen Namespaces trotz positiver
DOM-`matches`, korrektem `getAttribute` und `classList`. Das ist keine pauschale
Behauptung einer Engine-Klassenlücke oder einheitlicher Browsersemantik.

Zwölf tatsächliche CSSOM-/Klassen-/Stylesheetkontext-/Farbmutationen erhalten
DOMs, Boxen, Labels, Editorbindungen, Werte, native Eingabefunktion, Fokus und
rückwärts gerichtete UTF16-Emoji-Auswahl. Farb-/Selektormutationen benötigen
kein Layout; unabhängige vollständige Paint-/Geometrieaufbauten und warme
Layouts stimmen überein. Echte Timer, Frames und Bindings werden entsorgt.
Die unveränderten Nachbarsuiten bestehen im gemeinsamen Elf-Suiten-Lauf
einschließlich der vorgeschriebenen isolierten GC-Prüfungen.

Die gespeicherten impliziten `@scope`-Rohfälle bleiben ein offener C01-Pfad:
`ScopeRules.selector` unterscheidet den standardmäßig implizierten
Descendant-Scopedstyle vom ausdrücklichen Ziel am Scoperoot noch nicht
vollständig; der synthetische Anker relativer Limits besitzt weiterhin einen
Defaultnamespace-Test. Diese bestehenden Fälle sind kein neuer optionaler
Standard und werden durch die Autoren-Gegenproben nicht abgeschlossen.
Weitere Shadow-/Featureless-/Namespacekombinationen, vollständige Grammatik
und native Studioabnahme bleiben offen. Kein C01- oder Gesamtabschluss.

## Begrenzte Scope-Kontexte und CSSOM-Rundläufe – 13. Oktober 2026

Der übernommene Source4-Pfad trennt gewöhnliche Scope-Subjects, echte
`:scope`-/`&`-Referenzen und synthetische relative Anker. Referenzen zählen auch
in verworfenen Zweigen; Strings, Kommentare, Identifier/Escapes und URL-Tokens
bleiben Daten. Nur künstliche relative Anker erhalten die Namespaceausnahme.
Der Scanner gibt bei langer Arbeit kooperativ ab und erzeugt Rewrite-Chunks
nur für tatsächliche Ampersands. Bestehende Shadow-/Host-/Part-/Slotted-
Projektionspfade erhalten keinen pauschalen neuen Abschluss.

[ScopeNamespaces](../tests/ScopeNamespaces.luau) prüft 270 unveränderte rohe
Fälle/6480 Subjects: 6460 native Matches und 20 getrennte gefrorene Namespace-
Projektionen. Acht unabhängig erfasste explizite Gegenproben/192 Subjects
ergeben zusammen 278 Fälle/6672 Vergleiche. Rohdaten und Gegenproben bleiben
[getrennt](../tests/fixtures/scope-namespace-browser.json) erhalten. Die
20 Projektionen übernehmen ausdrücklich den bereits geprüften
Selectors4-Jan22-Vertrag; sie werden nicht als rohe Browsergleichheit gezählt.

[ScopeRetained](../tests/ScopeRetained.luau) hält in zwölf tatsächlichen
HTMLScripts-/Controller-/RenderTree-Zuständen DOMs, Boxen, Labels, Editor,
Fokus, Werte und rückwärtige UTF16-Auswahl. Farb-/Selektorwechsel benötigen
kein Arrangement; serialisierte Regeln stimmen im frischen vollständigen
Paint-/Geometrieaufbau überein. Warme Layouts messen keine Texte neu und
erzeugen keine Oberflächen; Eingabe, Timer, Frames und Bindings werden abgebaut.

[ScopeNestedContexts](../tests/ScopeNestedContexts.luau) vergleicht zwölf
verschachtelte Scope-/Stilkontexte mit exakten Regelbäumen, Start/End und
216 Farben vor/nach Serialisierung. Der Start behält den äußeren Kontext;
Scope-Body und explizite Limits verwenden den eigenen Root. 36 weitere CSSOM-
Kontexte und sechs Setter-/Insert-Paare unterscheiden scoped-relative
`> p` von gewöhnlichem Stil-Nesting `& > p`.
[ScopeTopReferences](../tests/ScopeTopReferences.luau) ergänzt acht gewöhnliche
HTML-Referenzkontexte/88 Subjects für nichtverschachteltes Ampersand.

Der Scope-Vertrag verwendet den [erhaltenen CSSWG-Editorentwurf](../build/scope-namespace-prep/css-cascade-6-20260428.html)
mit Headerdatum 28. April 2026 und den [Scopeabschnitten](https://drafts.csswg.org/css-cascade-6/#scoped-style-rules).
Dies ist ein Work-in-progress-Snapshot, kein erfundener datierter veröffentlichter
TR. Sein SHA ist im [kanonischen Übernahmebeleg](../build/scope-core-canonical-prep/canonical-receipt.json)
festgehalten. [Nesting](https://drafts.csswg.org/css-nesting-1/#nesting-scope)
begründet die Trennung zwischen Stilparent und neuem Scope-Body.

Die neuen Zuordnungen sind ausdrücklich teilweise: drei eng abgegrenzte
Scope-Anforderungen und ein nichtverschachtelter Ampersand-Vertrag sind erfüllt;
vier neue Restanforderungen sind ungeprüft. Insgesamt 16 partielle Zuordnungen/
80 Anforderungen: 39 erfüllt, fünf offen, 36 ungeprüft. Die bisherigen 72
Anforderungen bleiben unverändert. Diese Zahlen zählen keinen vollständigen
Restumfang und schließen weder C01 noch die Scope-/Nestingdefinitionen.

Weitere [24 rohe Grenzfälle](../build/scope-namespace-prep/nested-extra-browser-root.json),
[18 Formatterkontrollen](../build/scope-namespace-prep/format-browser-root.json)
und [24 Stilparentkombinationen](../build/scope-namespace-prep/style-scope-context-browser-root.json)
bleiben außerhalb dieser Übernahme. Die zusätzlichen Formatter-/Grenzkandidaten und
ihre strikten roten Läufe bleiben BUILD. Bekannte Grammatik für zitiertes `::`,
verwerfende Pseudoelement-Serialisierung, komplexe implizite Limits,
eigene-Root-Limit-/Stilparentabweichungen zwischen Chrome und Editorentwurf,
weitere Shadow-/Namespace-/Proximitykombinationen und native Studioabnahme
sind nicht als abgeschlossen markiert. Nächste Arbeit setzt dort fort.

Der [gemeinsame aktuelle CLI-Checkpoint](../build/scope-core-canonical-prep/full-current-acceptance.json) besteht mit 417 registrierten Suiten. Der erste Scope-Gesamtlauf war rot: Eine ältere CSSOM-Renderingregel verwendete den impliziten Subjectselektor an der eigenen Root. Das [vollständige Original](../build/scope-core-production-prep/cssom-rendering-before.luau) und die [sechs unabhängigen Nativeproben](../build/scope-core-production-prep/cssom-root-fixtures-browser.json) bleiben erhalten. Drei strikte Negativprüfungen für die ursprünglichen Regeln stehen nun vor drei tatsächlichen selectorText-Mutationen auf explizite Rootreferenzen; sämtliche ursprünglichen Paint-/Alpha-/Pooling-/Layout-/Editor-/Cleanup-Assertions bleiben unverändert. Die aktuelle Prüfung besteht gemeinsam mit den vier neuen Scope-Suiten. Diese Fixturekorrektur verändert keinen Enginepfad.
