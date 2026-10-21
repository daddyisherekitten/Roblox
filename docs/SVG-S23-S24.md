# S23/S24 — Masken und Mischmodi

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Stand: 14.09.2026. Implementiert, automatisierte Prüfung und lokale Raster-
Sichtprüfung; vom Nutzer mit „passt weiter“ visuell bestätigt, ohne neuen Clientbericht. S21/S22 hat der Nutzer
mit „passt weiter“ visuell bestätigt, ohne zusätzlichen Clientbericht.

## Vergleich und Bedienung

Studio-Konfiguration: `ActiveDemo="SVGLab"`, `SVGStage="S23_S24"`.
Stop → Play lädt das Paket. Browserreferenz:
`examples/svg-tests/s23-s24.html`; Einzeletappen `s23.html` und `s24.html`.
Tasten 1 / 2 / 3 wählen 240 / 480 / 960 Pixel; R prüft 20 Neuaufbauten.
Sieben Tafeln ergeben 14 EditableImages einschließlich Schachbrett-Unterlagen.
Erwartet: `SVG_S23_S24_REPORT`, `Diagnostics: []`. Kein automatischer Bericht
ersetzt die visuelle Nutzerabnahme.

| Tafel | Sichtbares Prüfkriterium |
|---|---|
| S23-alpha | Schwarz-Weiß-Verlauf blendet im Luminanzmodus ein, im Alphamodus bleibt er deckend. Farbige Masken erzeugen unterschiedliche Helligkeitswerte; Alpha ignoriert die Farben. |
| S23-units | Relative Ellipse/Kreis passen sich den Boxen an. Unten beschneiden feste und relative Regionen auch gedrehte Inhalte korrekt. |
| S23-nested | Eine Maske enthält eine weitere Maske; daneben ein Rasterbild als Alphamaske. Grau in linearRGB lässt deutlich weniger durch als dasselbe Grau in sRGB. |
| S24-modes | normal, multiply, screen, overlay / darken, lighten, color-dodge, color-burn. Pro Feld ein Kreispaar und ein reiner Mischfarbbalken. |
| S24-colors | hard-light, soft-light, difference, exclusion / hue, saturation, color, luminosity. Gleiche Farben machen Unterschiede vergleichbar. |
| S24-isolation | Links mischen die Kreise mit Gelb, rechts nur innerhalb ihrer isolierten Gruppe. Clipping links unten isoliert nicht; Gruppen-Opacity rechts unten isoliert. |
| S24-combined | Clip, Luminanzmaske, Gruppen-Opacity und multiply kombiniert; zusätzlich Maskierung und screen mit einem Rasterbild. |

Der Generator `scripts/sync-svg-masks-blending.py` synchronisiert sieben SVGs,
drei Luau-Quellen und drei HTML-Seiten. Er verwendet unverändert das gemeinsame
PNG aus S21; Browser-Datei und dekodierter Luau-Puffer enthalten dieselben Pixel.
Quell-Hash einschließlich referenzierter Ressourcen; `--check` verfügbar.

## Umsetzung

`SVG/Mask.luau` löst SVG-mask-Referenzen auf und lässt den bestehenden Besucher
deren Inhalt zeichnen. Unterstützt sind:

- `mask` mit einzelner URL/none; `mask-image` mit SVG-mask-Referenz;
  `mask-mode: match-source | alpha | luminance` und `mask-type: alpha | luminance`.
- CSS-Kaskade, Präsentationsattribute, Vererbung innerhalb der Maskeninhalte,
  CSS-weite Werte und Variablen über die vorhandene Style-/Document-Schicht.
- `maskUnits`, `maskContentUnits`, x/y/width/height einschließlich Prozenten.
  Standardregion −10 % / −10 % / 120 % / 120 %; positive Maskenregion begrenzt
  alle Inhalte. Leere Regionen ergeben vollständige Transparenz.
- Bereits vorhandene Formen, Gruppen, Bilder, use, Verläufe, Muster, Marker,
  Clips und weitere Masken innerhalb der Ressource. Referenzzyklen und
  fehlende/ungeeignete Referenzen ergeben Diagnose und transparente Maske.
- Alphawerte direkt oder Luminanz × Alpha; auf Wunsch sRGB→linearRGB vor der
  Luminanzberechnung. Die Koeffizienten entsprechen SVG 1.1 luminanceToAlpha.

`SVG/Blend.luau` implementiert die 16 Mischmodi aus CSS Compositing Level 1,
einschließlich der vier nicht separierbaren Farbmodi. `Compositing.over`
berücksichtigt Quell- und Hintergrund-Alpha zusätzlich zur Farbmischung.

`isolation:auto` lässt normale Gruppen in den vorhandenen SVG-Hintergrund
zeichnen. `isolation:isolate`, Masken, Gruppen-Opacity unter 1 und ein anderer
Mischmodus als normal erzeugen eine transparente Zwischenfläche. Ein Clip
allein isoliert nicht: dafür wird die tatsächliche Hintergrundfläche kopiert
und das beschnittene Ergebnis mit dem ursprünglichen Hintergrund in
vormultipliziertem Farbraum interpoliert. Das korrigiert die S22-Isolation,
die erst mit neu hinzugekommenen blendenden Kindern einen Unterschied macht.

Die Reihenfolge ist Clip → Maske → Opacity → Mischung/Komposition mit der
Elternfläche. Filter werden erst in S29–S35 vorgeschaltet. Alle Zwischenbilder
bleiben CPU-Puffer; keine zusätzlichen interaktiven Roblox-GUIs.

## Hintergrundzugang und ehrliche Grenzen

Der Mischhintergrund besteht aus bereits gezeichneten Pixeln derselben SVG-
Szene bzw. Gruppe. Das Labor-Schachbrett bleibt eine separate Anzeigeunterlage
und wird nicht heimlich als Mischhintergrund eingesetzt.

Der vorhandene HTML-Renderer wurde dafür geprüft: `Rendering/RenderTree.luau`
erzeugt Hintergründe als Frames/ImageLabels; `ImageBox.luau` erzeugt Bild-GUIs.
Diese Komponenten liefern dem SVG-Rasterer keinen gemeinsamen RGBA-Hintergrund.
Eine beliebige HTML-Seite, TextLabels oder die 3D-Welt werden deshalb in dieser
Etappe nicht als Hintergrund abgetastet. Das ist eine offene Integration in
S43, keine Behauptung einer grundsätzlichen Roblox-Unmöglichkeit. Die Tests
verwenden ausdrücklich echte SVG-Hintergrundformen; eine erfundene Ersatzfarbe
wird nicht als bestandene HTML-Hintergrundprüfung ausgegeben.

Weitere Grenzen:

- Maskenregionen und unterstützte SVG-Inhalte sind umgesetzt; mehrere CSS-
  Maskenlagen, mask-composite, mask-border und die vollständige mask-Shorthand-
  Grammatik bleiben eigener Restumfang. Direkte Raster-URLs an mask-image
  sind nicht als positionierte CSS-Masken implementiert; Rasterbilder innerhalb
  eines SVG-mask-Elements funktionieren.
- Text als Maskeninhalt folgt mit S25–S28. Filter, Animation und Hit-Tests
  behalten ihre späteren Etappen. S24 bedeutet keine Unterstützung von
  Hintergrundfilterung oder neueren Level-2-Werten wie plus-lighter.
- RGB-Blending verwendet sRGB. `color-interpolation:linearRGB` auf mask
  steuert die Luminanzumrechnung; es stellt nicht alle Gruppenoperationen auf
  lineare Komposition um. Diese Unterscheidung ist separat getestet.
- 8-Bit-Zwischenbilder, vorhandenes Antialiasing und bilineare Bildabtastung
  können an weichen Grenzen von Browsern abweichen. Keine pauschale
  pixelidentische Browser-Konformität behauptet.
- Bestehende Limits bleiben: 32 MiB gleichzeitig für Compositing, 12 Ebenen
  bei rekursiven Ressourcen/Masken/Clips, begrenzte Referenzexpansion und
  maximal 1024×1024 pro gerasterter Ausgabe. Komplexe Masken brauchen mehr
  Rasterarbeit. Arbeitsabbruch erfolgt an vorhandenen Checkpoints.

## Prüfung und Referenzen

`tests/SVGMasksBlending.luau`: numerische Maskenwerte, lineare Umrechnung,
analytische Sollwerte für separierbare Mischmodi, nicht separierbare
Wertebereiche/Luminanz, Teilalpha, Maskenregionen, relative Einheiten,
verschachtelte Masken, Isolation, Clip-Hintergrund, Reihenfolge, Fehlerfälle,
Abbruch und sieben Tafeln bei drei Auflösungen. Bestehende S01–S22-Regressionen
bleiben Teil derselben Suite; der Laborcontroller wird mit 20 Lebenszyklen,
überholtem Resize, Abbruch und bereinigten Eingaben geprüft.

Lokale Rastervorschau: `build/svg-s23-s24-preview.png`. Native Browsersteuerung
war bereits in S21/S22 durch die file://-URL-Policy gesperrt; kein erneuter
Umgehungsversuch. Studio wird vom Nutzer visuell verglichen.

Referenzen: [CSS Masking — Maskenverarbeitung](https://www.w3.org/TR/css-masking-1/#MaskValues),
[SVG-mask-Element](https://www.w3.org/TR/css-masking-1/#MaskElement) und
[CSS Compositing and Blending Level 1](https://www.w3.org/TR/compositing-1/).
