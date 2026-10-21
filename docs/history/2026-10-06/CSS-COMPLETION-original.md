# CSS-Abschlussliste für das Roblox-Profil

Stand: 21. September 2026

## Bewertungsmaßstab

Diese Liste bewertet CSS nach der tatsächlichen Funktion der Roblox-HTML-Engine
und wird gegen den aktuellen MDN-Eigenschaftskatalog abgeglichen. Jede
Eigenschaft, die den sichtbaren Seiteninhalt oder seine Bedienung verändert,
gehört in die Implementierungswarteschlange. Reine Druck-, Browser-Chrome- und
Plattformfunktionen werden weiterhin gesondert begründet.

- `supported`: Der im Eigenschaftskatalog beschriebene Roblox-Funktionsumfang ist nutzbar.
- `partial`: Eine bereits in das Roblox-Profil aufgenommene Funktion ist noch nicht fertig.
- `planned`: Für normale Roblox-Webseiten vorgesehen, aber noch nicht implementiert.
- `out-of-scope`: Für das Roblox-Ziel nicht erforderlich und deshalb kein Abschlussfehler.

Die erlaubten Werte und Grenzen jeder Eigenschaft stehen verbindlich in
[`CSS/Properties.luau`](../src/HTMLEngine/CSS/Properties.luau). Einschränkungen
außerhalb des beschriebenen Roblox-Profils machen eine Eigenschaft nicht `partial`.

## Aktueller Stand

| Bereich | Stand |
| --- | ---: |
| CSS-Eigenschaften im Katalog (1. Oktober 2026) | 523 `supported` im dokumentierten Roblox-Profil |
| Katalogeigenschaften mit unfertigem Roblox-Verhalten | 0 `partial` |
| Gegen MDN noch zu klassifizierende/implementierende Namen | 162 |

Der Online-Abgleich vom 21. September 2026 umfasst 533 MDN-Einträge: 493
Standard- und 40 experimentelle Eigenschaften. `--*` ist als Custom-Property-
Infrastruktur bereits vorhanden und wird nicht als einzelne Eigenschaft gezählt.
Nach dem aktuellen Ausbau bleiben 129 benannte Standard- und 33 experimentelle
Einträge. Die maschinenlesbaren Rohdaten stehen in
[`build/css-online-comparison.json`](../build/css-online-comparison.json); der
neue Arbeitsumfang steht in [CSS-Erweiterungsplan](CSS-EXPANSION-ROADMAP.md).

SVG besitzt zusätzlich eine eigene CSS-Pipeline für Präsentationsattribute,
Interaktionszustände und Animationen. Diese Liste beschreibt vor allem CSS auf
HTML-Elementen; SVG-spezifische Einzelheiten stehen in den SVG-Dokumenten.

Der Ausbau für Flächen und Effekte ergänzt Kompatibilitätsnamen, Eck-Kurzformen,
Schatten-Komponenten, Verlaufsrahmen, Maskenrahmen und rechteckige Ausschnitte.
Die aktuellen Grenzen und weiterhin offenen Eigenschaften stehen verbindlich in
[CSS-VISUAL-LIMITS.md](CSS-VISUAL-LIMITS.md). Insbesondere `border-shape` und
`box-decoration-break` sind weiterhin offen; der historische MDN-Abgleich oben
wurde durch die neuen Kompatibilitätsnamen nicht neu erhoben.

## Unterstützte Eigenschaften

### Boxen und Größen — 16

`display`, `width`, `height`, `min-width`, `max-width`, `min-height`,
`max-height`, `inline-size`, `block-size`, `min-inline-size`,
`max-inline-size`, `min-block-size`, `max-block-size`, `box-sizing`,
`aspect-ratio`, `resize`

### Abstände und Positionierung — 38

`margin`, `margin-top`, `margin-right`, `margin-bottom`, `margin-left`,
`padding`, `padding-top`, `padding-right`, `padding-bottom`, `padding-left`,
`margin-inline`, `margin-block`, `margin-inline-start`, `margin-inline-end`,
`margin-block-start`, `margin-block-end`, `padding-inline`, `padding-block`,
`padding-inline-start`, `padding-inline-end`, `padding-block-start`,
`padding-block-end`, `position`, `top`, `right`, `bottom`, `left`, `inset`,
`inset-inline`, `inset-block`, `inset-inline-start`, `inset-inline-end`,
`inset-block-start`, `inset-block-end`, `z-index`, `anchor-name`,
`position-anchor`, `position-area`

### Transformationen — 6

`transform`, `transform-origin`, `transform-box`, `translate`, `rotate`, `scale`

Der Roblox-Kern umfasst Translation, Rotation und gleichmäßige Skalierung auf
Blockboxen. Details stehen in [CSS-2D-Transformationen](CSS-TRANSFORMS.md).

### Übergänge und Animationen — 16

`transition`, `transition-property`, `transition-duration`,
`transition-timing-function`, `transition-delay`, `animation`,
`animation-name`, `animation-duration`, `animation-timing-function`,
`animation-delay`, `animation-iteration-count`, `animation-direction`,
`animation-fill-mode`, `animation-play-state`, `animation-composition`,
`transition-behavior`

Der Roblox-Kern animiert Transformation, Gruppen-Opacity und einfarbige
Hintergründe über `@keyframes` oder Zustandswechsel. Details stehen in
[CSS-Übergänge und Animationen](CSS-MOTION.md).

### Flexbox — 15

`flex`, `flex-flow`, `flex-direction`, `flex-wrap`, `flex-grow`,
`flex-shrink`, `flex-basis`, `order`, `justify-content`, `align-items`,
`align-self`, `align-content`, `gap`, `row-gap`, `column-gap`

### Grid — 20

`grid`, `grid-template`, `grid-template-columns`, `grid-template-rows`,
`grid-template-areas`, `grid-auto-columns`, `grid-auto-rows`,
`grid-auto-flow`, `grid-column`, `grid-column-start`, `grid-column-end`,
`grid-row`, `grid-row-start`, `grid-row-end`, `grid-area`, `place-items`,
`place-self`, `place-content`, `justify-items`, `justify-self`

Die gemeinsam mit Flexbox verwendeten Eigenschaften `align-*`,
`justify-content` und `gap` werden nur einmal im Katalog gezählt.

Mehrspalten-Trennlinien unterstützen außerdem `column-rule-inset`, die
Kurzformen `-start`, `-end`, `-cap`, `-junction` sowie die vier Langformen
`-cap-start`, `-cap-end`, `-junction-start`, `-junction-end`.
Positive Längen kürzen die Linie, negative verlängern sie. Prozentwerte beziehen
sich nach [CSS Gaps](https://drafts.csswg.org/css-gaps-1/#inset) auf den kreuzenden
Zeilenabstand; am Rand des Inhalts ist diese Basis null. `overlap-join` verbindet
fortgesetzte Trennlinien über diesen Abstand. Grid-/Flex-Trennlinien und
kreuzende `row-rule`-Linien gehören derzeit nicht zum Roblox-Profil.

Ergänzung vom 30. September: `column-rule-break` und
`column-rule-visibility-items` steuern durchgehende/geteilte Linien und Linien
neben leeren Spalten. Die alten `column-rule-edge-inset*`,
`column-rule-interior-inset*` und `column-rule-outset` bleiben als dokumentierte
Kompatibilitätswerte verfügbar; sie unterscheiden Rand- und innere Endpunkte.
`margin-trim` entfernt Block-Randabstände einschließlich kollabierter Nachfahren;
`margin-break` steuert die Abstände an erzwungenen und automatischen Spaltenumbrüchen.
`min-size`/`max-size` setzen beide Größenachsen, `min-intrinsic-sizing` komprimiert
min-content-Beiträge leer gedachter Scroll-/extrinsisch begrenzter Boxen.

`-ms-grid-columns`/`-ms-grid-rows` speichern getrennte historische Tracks,
die nur bei `display:-ms-grid`/`-ms-inline-grid` verwendet werden. Sie dürfen
modernes `display:grid`/`inline-grid` nicht verändern. Dieses Profil ist keine
vollständige IE-Grid-Emulation. Die gemeinsamen Browserproben verwenden modernes
Grid und zeigen deshalb auch in Roblox den normalen Grid-Fallback;
`inset-area` bildet auf `position-area` ab. Das frühere `grid-auto-position`
setzt bei `grid-auto-flow:none` den gemeinsamen Vorgabeplatz der automatisch
platzierten Kinder (Spalte / Zeile). `align-tracks`/`justify-tracks` gehören
zum historischen Masonry-Profil mit `grid-template-rows/columns:masonry`.
Der Renderer unterstützt kürzeste Bahn, explizite Bahn/Spanne, feste Tracks,
Listen von Bahnausrichtungen, Verteilung, Stretch und RTL. Subgrid innerhalb
von Masonry und Baseline-Ausrichtung sind noch nicht unterstützt;
Baseline-Werte werden mit einer Diagnose abgelehnt. Das ist kein Anspruch
auf vollständige Umsetzung des heutigen Grid-Lanes-Entwurfs.

`color-scheme` wählt helle/dunkle Standardfarben von Canvas, Controls und
Scrollleisten, ohne Autorenfarben zu ersetzen. Die Media-Umgebung unterstützt
`prefers-color-scheme` und `prefers-reduced-motion`; letzteres folgt der nativen
Roblox-Einstellung `GuiService.ReducedMotionEnabled`. Überschreibungen sind
über `MediaFeatures.PreferredColorScheme` und `MediaFeatures.ReducedMotion` möglich.

### Überlauf und Sichtbarkeit — 9

`overflow`, `overflow-x`, `overflow-y`, `overflow-inline`, `overflow-block`,
`text-overflow`, `visibility`, `scrollbar-color`, `scrollbar-width`

### Text und Schrift — 32

`font`, `font-family`, `font-size`, `font-style`, `font-weight`,
`font-feature-settings`, `font-variant`, `font-variant-ligatures`,
`font-variant-numeric`, `font-variant-caps`, `font-variant-position`,
`font-kerning`, `font-size-adjust`,
`line-height`, `direction`, `text-align`, `text-align-last`,
`text-transform`, `text-indent`, `white-space`, `tab-size`, `word-break`,
`overflow-wrap`, `word-wrap`, `letter-spacing`, `word-spacing`,
`vertical-align`, `white-space-collapse`, `text-wrap`, `text-wrap-mode`,
`text-wrap-style`, `text-justify`

### Textdekoration und Textfarbe — 10

`color`, `text-shadow`, `text-decoration`, `text-decoration-line`,
`text-decoration-color`, `text-decoration-style`,
`text-decoration-thickness`, `text-decoration-skip-ink`,
`text-underline-offset`, `text-underline-position`

### Erweiterter Text — 13

`hyphens`, `hyphenate-character`, `hyphenate-limit-chars`, `text-emphasis`,
`text-emphasis-style`, `text-emphasis-color`, `text-emphasis-position`,
`quotes`, `writing-mode`, `text-orientation`, `line-break`,
`hanging-punctuation`, `text-autospace`

Automatische Trennung arbeitet im Roblox-Profil ohne Sprachwörterbuch an
Graphemgrenzen. Vertikale Schreibmodi drehen die Textläufe innerhalb ihrer
normalen Box; die genauen Grenzen stehen im Eigenschaftskatalog.

### Ruby — 2

`ruby-align`, `ruby-position`

Ruby-Annotationen lassen sich innerhalb ihrer gemeinsamen Spalte am Anfang
oder mittig ausrichten und ober- oder unterhalb des Basistexts platzieren.

### Hintergründe und Effekte — 14

`background`, `background-color`, `background-image`, `background-size`,
`background-position`, `background-position-x`, `background-position-y`,
`background-repeat`, `background-origin`, `background-attachment`,
`background-clip`, `opacity`, `filter`, `box-shadow`

`background` setzt Farbe und Ebenen-Longhands gemeinsam zurück. `filter`
verarbeitet die Bildpixel von `img`, einschließlich lokal gerenderter SVGs für
Farbfilterketten. Bei diesen SVGs sind äußere CSS-Ketten mit `blur()` oder
`drop-shadow()` noch nicht unterstützt; der Renderer meldet die Einschränkung
und behält das Original. Die weiteren Grenzen stehen jeweils im Katalog und
in [CSS-Hintergrundbilder](CSS-BACKGROUNDS.md).

### Rahmen und Konturen — 60

`border`, `border-width`, `border-style`, `border-color`, `border-radius`,
`border-top`, `border-top-width`, `border-top-style`, `border-top-color`,
`border-right`, `border-right-width`, `border-right-style`,
`border-right-color`, `border-bottom`, `border-bottom-width`,
`border-bottom-style`, `border-bottom-color`, `border-left`,
`border-left-width`, `border-left-style`, `border-left-color`,
`border-inline`, `border-block`, `border-inline-start`, `border-inline-end`,
`border-block-start`, `border-block-end`, `border-top-left-radius`,
`border-inline-width`, `border-inline-style`, `border-inline-color`,
`border-block-width`, `border-block-style`, `border-block-color`,
`border-inline-start-width`, `border-inline-start-style`,
`border-inline-start-color`, `border-inline-end-width`,
`border-inline-end-style`, `border-inline-end-color`,
`border-block-start-width`, `border-block-start-style`,
`border-block-start-color`, `border-block-end-width`,
`border-block-end-style`, `border-block-end-color`,
`border-top-right-radius`, `border-bottom-right-radius`,
`border-bottom-left-radius`, `border-start-start-radius`,
`border-start-end-radius`, `border-end-end-radius`, `border-end-start-radius`, `outline`,
`outline-width`, `outline-style`, `outline-color`, `outline-offset`,
`corner-shape`, `border-image-outset`

### Listen — 4

`list-style`, `list-style-type`, `list-style-position`, `list-style-image`

### Bilder — 3

`object-fit`, `object-position`, `image-rendering`

### Tabellen — 5

`table-layout`, `border-spacing`, `border-collapse`, `caption-side`,
`empty-cells`

### Generierter Inhalt und Zähler — 4

`content` auf `::before`, `::after` und `::marker`, `counter-reset`,
`counter-increment`, `counter-set`

`content` unterstützt Text, `attr()`, `counter()` und `counters()`. Das
Roblox-Profil formatiert Dezimalzahlen, führende Nullen, Buchstaben und
römische Zahlen. Zähler folgen verschachtelten Elementbereichen; `reversed()`
und frei definierte `@counter-style`-Regeln sind noch nicht enthalten.

### Eingabe — 5

`cursor`, `pointer-events`, `user-select`, `touch-action`, `accent-color`

### Scrollverhalten und Steuerelemente — 38

`overscroll-behavior`, `overscroll-behavior-x`, `overscroll-behavior-y`,
`overscroll-behavior-inline`, `overscroll-behavior-block`, `scroll-snap-type`,
`scroll-snap-align`, `scroll-snap-stop`, `scroll-padding` samt physischen und
logischen Langformen, `scroll-margin` samt physischen und logischen Langformen,
`scroll-behavior`, `scrollbar-gutter`, `appearance`, `caret-color`,
`caret-shape`, `caret-animation`, `caret`, `scroll-marker-group`

### Spalten und Fluss — 22

`float`, `clear`, `column-count`, `column-width`, `columns`, `column-fill`,
`column-span`, `column-rule`, `column-rule-width`, `column-rule-style`,
`column-rule-color`, `line-clamp`, `max-lines`, `shape-outside`, `shape-margin`,
`orphans`, `widows`, `break-inside`, `break-before`, `break-after`,
`column-height`, `column-wrap`

Mehrspaltenlayout verwendet eigene Zeilenfragmente und keine Grid-Tracks.
`column-width` und die verfügbare Breite bestimmen die Spaltenzahl;
`column-span:all` trennt die ausgeglichenen Bereiche mit einer vollen Zeile.
Feste Höhe und max-height begrenzen die Fragmente; Overflow läuft in weiteren
Spalten weiter. `column-height` setzt die Höhe einer Spaltenreihe;
`column-wrap:wrap` (bzw. auto bei column-height) setzt Overflow mit row-gap
in neuen Reihen fort. `break-before/after:column` erzwingen Umbrüche zwischen
Blockelementen, auch in normalen verschachtelten Textblöcken.
Text kann an Zeilengrenzen die Spalte wechseln; eigenständige Layouts bleiben
ungeteilt. Rahmen und Hintergründe fragmentierter Textblöcke werden noch nicht
pro Spalte zerlegt. circle/ellipse-Floats grenzen die ganze Höhe jeder Textzeile
ein, einschließlich `shape-margin`; normale verschachtelte Blöcke teilen diese
Umfließung, neue Formatierungskontexte bleiben unabhängig.

### Container und sichtbares Containment — 10

`contain`, `container-type`, `container-name`, `container`,
`content-visibility`, `contain-intrinsic-width`, `contain-intrinsic-height`,
`contain-intrinsic-inline-size`, `contain-intrinsic-block-size`,
`contain-intrinsic-size`

Größenabfragen über `@container` verwenden feste oder zuletzt angeordnete
Containermaße. Paint-Containment clippt an der Borderbox; versteckter Inhalt
kann mit den intrinsischen Ersatzgrößen Platz im Layout behalten.

### Erweiterte Effekte — 21

`clip-path`, `mask-image`, `mask`, `mask-mode`, `mask-position`, `mask-size`,
`mask-repeat`, `mask-origin`, `mask-clip`, `mask-composite`, `mask-border`,
`mask-border-source`, `border-image-source`,
`border-image`, `border-image-slice`, `border-image-width`,
`border-image-repeat`, `mix-blend-mode`, `background-blend-mode`, `isolation`,
`backdrop-filter`

Das Profil umfasst zentrierte Grundformen, zweistufige Alpha-Masken,
URL-/Verlaufsrahmen und begrenzte Farbkomposition. Roblox kann den bereits
gerenderten Hintergrund nicht lokal abtasten; `backdrop-filter` erzeugt daher
eine dokumentierte transluzente Frostglasfläche.

### Erweiterte Bewegung und Tiefe — 15

`offset`, `offset-path`, `offset-distance`, `offset-rotate`, `offset-anchor`,
`offset-position`, `perspective`,
`perspective-origin`, `transform-style`, `backface-visibility`,
`animation-timeline`, `animation-trigger`, `scroll-timeline`, `scroll-timeline-name`,
`scroll-timeline-axis`

Gerade Pfade und Strahlen können statisch oder über Keyframes bewegt werden.
Benannte und anonyme Scroll-Timelines beziehen ihren Fortschritt vom nächsten
passenden Scrollcontainer. 3D-Transformationen verwenden vollständige 4x4-Matrizen,
verschachtelte Perspektive und einen begrenzten Renderer mit Tiefensortierung
pro Pixel; Umfang und Grenzen stehen in `CSS-TRANSFORMS.md`.

`scroll-initial-target`, `overflow-anchor` und die zehn Varianten von
`overflow-clip-margin` sind zusätzlich im Scroll-Profil umgesetzt. Die
Verhaltenstests prüfen den ersten Ziel-Sprung, die Anker-Korrektur bei Reflow
und die Clip-Kante. Plattformgrenzen stehen in `SCROLLING.md`.

## Bereits unterstützte CSS-Infrastruktur

- `<style>`, `style="…"`, separate Autor-CSS-Quellen und registrierte
  `<link rel="stylesheet">`-Dateien
- Cascade nach Spezifität, Quellreihenfolge und `!important`
- Vererbung sowie `inherit`, `initial` und `unset`, unabhängig von der Großschreibung.
- `all: initial/inherit/unset` setzt alle unterstützten Eigenschaften über die
  normale Cascade zurück; `direction`, `unicode-bidi` und Custom Properties sind
  ausgenommen. Die Expansion wird pro Schlüsselwort einmal kompiliert und
  wiederverwendet. `!important`, spätere Longhands und `var()` bleiben wirksam.
- CSS-weite Font-/Variant-Resets setzen auch die unterstützten Variant- und
  Feature-Anteile zurück. Ein einzelner Corner-Radius-Reset erhält die übrigen
  Ecken. Fehlende Eigenschaften bleiben als fehlend diagnostiziert; `initial`
  allein implementiert deren sonstiges Verhalten nicht.
- Tag-, Klassen-, ID-, Universal-, kombinierte, Nachfahren-, Kind- und
  Geschwisterselektoren sowie Kommagruppen auf HTML
- Attributselektoren einschließlich Operatoren und `i`-Flag
- `:root`, `:empty`, Kind-/Typ-Positionen, `:is()`, `:where()`, `:not()`,
  `:hover`, `:active`, `:focus` und `:focus-within`
- Kommentare, Zeichenketten und geklammerte Werte im CSS-Parser
- HTML Custom Properties mit case-sensitiven `--name`-Werten, Vererbung,
  `!important`, verschachtelten `var()`-Fallbacks und Zyklenerkennung
- verschachtelte und kommaseparierte `@media`-Regeln für Breite, Höhe,
  Seitenverhältnis, Orientierung sowie `hover`-/`pointer`-Fähigkeiten;
  Breakpoints werden bei Viewport- und Eingabeänderungen neu ausgewertet
- `px`, `%`, `em`, `rem`, `vw`, `vh`, `vmin` und `vmax` an den jeweils
  dokumentierten Stellen; `calc()`, `min()`, `max()` und `clamp()` teilen
  dieselbe Längenauflösung und reagieren auf Viewport-Änderungen
- 148 benannte Farben, Hex, RGB/RGBA, HSL/HSLA, Alpha und `currentcolor`
- separate Shadow-DOM-Styles ohne Durchsickern in das Hauptdokument
- `@keyframes` mit Prozentstopps, Wiederholungen, Richtung, Füllmodus und
  begrenzter Paint-Runtime
- benannte `@container`-Größenabfragen und benannte Scroll-Timelines
- mehrschichtige CSS-Hintergründe mit URL-Bildern, linearen/radialen und
  wiederholenden Verläufen, Größe, Position, Wiederholung, Ursprung und Clip;
  Details und Rasterbudgets stehen in [CSS-Hintergrundbilder](CSS-BACKGROUNDS.md)

Interaktive Selektoren und umschaltende Media Queries aktualisieren bestehende
Farb-, Schrift-, Größen-, Abstands-, Flex-, Grid-, Sichtbarkeits- und Cursorwerte
ohne Szenen-Neuaufbau. Strukturelle Zustandswechsel, die neue GUI-Objekte
benötigen würden, etwa `display:none` oder das erstmalige Hinzufügen eines
Schattens oder Rahmens, bleiben bis zu den jeweiligen Layout-/Effektblöcken
unverändert.

## Bisher abgeschlossene Roblox-Funktionsblöcke

Die bisherigen Abschlussblöcke sind umgesetzt:
`fixed`/`sticky`, `inline-block`/`inline-flex`/`contents`, generierter Text,
logische Seiten für horizontales LTR/RTL, einzelne/elliptische Radien und
Zeiger-/Auswahl-/Touchsteuerung. Die genauen Roblox-Grenzen stehen im
Eigenschaftskatalog. Die frühere Sammelseite `css-completion` wurde entfernt.
Neue sichtbare Erweiterungsblöcke erhalten jeweils eine eigene Untertestseite.
Die Seiten `css-containment`, `css-effects` und `css-advanced-motion`
vergleichen die drei jüngsten Funktionsgruppen direkt zwischen Browser und Roblox.

## Bewusst außerhalb des Roblox-Profils

Diese Bereiche werden im Online-Abgleich getrennt klassifiziert:

- Druck- und Seitenmedien wie `@page`, Seitenumbrüche und Druckränder
- Sprach- und Vorlese-CSS
- Betriebssystem- oder Browser-Chrome-Styling
- beliebiger Webfont-Download; Roblox verwendet registrierte Font-Assets
- vollständige 3D-Perspektive und GPU-Compositing-Parität eines Browsers
- herstellerspezifische Präfixe und historisches Browser-Quirk-Verhalten

## Abschlusskriterium

CSS gilt für dieses Projekt erst als abgeschlossen, wenn jeder benannte Eintrag
des aktuellen Online-Abgleichs entweder implementiert oder mit einer konkreten
Roblox-Begründung klassifiziert ist, keine Katalogeigenschaft `partial` ist und
Tests Katalogzählung, Cascade, Layout, Eingabe, Resize und Lifecycle abdecken.
