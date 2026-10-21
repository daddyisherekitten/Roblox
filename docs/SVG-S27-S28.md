# S27/S28 — Textpfade und Textressourcen

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Stand: 14.09.2026. S25/S26 nach der text-orientation-Korrektur vom Nutzer
visuell bestätigt. Das neue Paket implementiert den unten beschriebenen Kern;
sein Browser-/Studio-Vergleich ist noch offen. S27/S28 sind wegen der expliziten
Restfunktionen nicht als vollständig abgeschlossen markiert.

## Vergleich

`ActiveDemo="SVGLab"`, `SVGStage="S27_S28"`, Stop → Play in Studio.
Browser: `examples/svg-tests/s27-s28.html`; Einzelseiten `s27.html`, `s28.html`.
Acht Tafeln / 16 EditableImages einschließlich Checker-Unterlagen.
Erwartet: `SVG_S27_S28_REPORT`, keine Diagnostics. 1/2/3: 240/480/960 px;
R: 20 Neuaufbauten. Browser nutzt native SVGs und dieselben vier TTF-Dateien
aus S25/S26 sowie die identischen S21-RGBA-Testpixel.

| Tafel | Sichtbares Prüfkriterium |
|---|---|
| S27-curves | Derselbe Satz auf S-Kurve, Kreisbogen und geschlossenem Kreis. |
| S27-offsets | startOffset 0/25/50 %, Anker an blauen Marken. |
| S27-path-style | Transformierter Pfad, farbige tspan, dy; auf kurzer Linie verschwinden Glyphen mit Mittelpunkt außerhalb des Pfads. |
| S27-lines | Links tspan mit relativem dy, rechts tspan mit absolutem y, gleiche Baselines. |
| S28-text-clip | Rasterbild durch SVG und B O, einschließlich ausgeschnittener Innenräume. |
| S28-text-mask | Text mit Verlauf als Luminanzmaske vs. Alphamaske. |
| S28-text-pattern | Aa als Musterinhalt; das Muster füllt anschließend große Buchstaben. |
| S28-path-clip | TextPath als Bildclip, darunter gedrehte Textmaske. |

`scripts/sync-svg-text-resources.py` synchronisiert acht SVG-Dateien, drei
Luau-Quellen und drei HTML-Seiten; Quell-Hash umfasst SVGs, Fontbytes und PNG.
HTML bettet die Bilder/Fonts ein, behält aber native text/textPath/clipPath/mask/
pattern-Elemente. Kein Ersatz der Browserreferenz durch unsere gerenderten Pfade.

## Implementiert

`SVG/TextPath.luau` bereitet einen Pfad einmal je textPath auf:

- href, historisches xlink:href über ExpandedAttributes, explizites path-Attribut;
  Document-Resolver für lokale und externe Referenzen. Pfade und vorhandene
  SVG-Grundformen. Der eigene Transform des referenzierten Elements wirkt
  ergänzend im Textkoordinatensystem; Vorfahren-Transforms werden nicht kopiert.
- Abgeflachte Kurven mit Längenindex, binärer Suche und Tangenten. Moveto-Lücken
  zählen nicht zur Länge. Geschlossene Einzelpfade erlauben einen Umlauf.
- startOffset als Länge/Prozent, negative und überlange Offsets;
  text-anchor, dx/dy, tspan-Formatierung, Zeichenrotation, gemeinsame Textkontur.
  Offene Pfade unterdrücken Glyphen, deren Mittelpunkt außerhalb liegt.
- side=right kehrt Richtung und Tangente um und ist numerisch getestet;
  pathLength kalibriert die längenbezogenen Abstände. Für diese erweiterten
  Fälle bleibt der native Browser-/Studio-Vergleich offen.
- method=align, spacing=exact; auto benutzt ebenfalls feste typografische
  Abstände. stretch ist nicht implementiert und wird diagnostiziert.

`Text.expand` behält textPath-Inhalte und deren Ressourcenkontext, positioniert
die vorhandenen echten Fontkonturen entlang des Pfads und gibt sie an denselben
Pfadrenderer. Font-Schriftgröße und Strichbreite bleiben in Benutzereinheiten.
Die Engine hat außerdem eine experimentelle Behandlung erhaltener Zeilenumbrüche
mit CSS line-height. Der Nutzervergleich zeigte aber, dass der Zielbrowser die
rechte CSS-Probe in einer Zeile zeichnet. Dieser Weg ist daher **nicht browsergleich
abgenommen**. Die gemeinsame Tafel verwendet jetzt beidseitig explizite tspan-
Zeilen (links relative, rechts absolute Positionen). Der ursprüngliche Fehlerfall
bleibt in `examples/svg-tests/S27-lines-css-known-difference.svg` erhalten.
Die internen CSS-Zeilentests belegen nur unser Verhalten, keine Browsergleichheit.
Automatischer SVG-Wortumbruch ist ebenfalls noch nicht enthalten.

`ClipPath` behandelt Text als Glyphensilhouette. Fill-Farbe, Stroke und Opacity
des Cliptextes beeinflussen die Silhouette nicht; clip-rule und Innenräume
bleiben erhalten. Textknoten werden beim Silhouettenbesuch sicher übersprungen.
Masken und Muster verwenden den gemeinsamen Besucher und zeichnen jetzt auch
textPath-Inhalte. Keine darübergelegten Roblox-TextLabels.

Die S25-Vergleichsquelle setzt font-kerning/font-variant-ligatures jetzt als CSS
statt als nicht standardisierte Präsentationsattribute. Ebenso sind white-space
und line-height CSS-only. Das setzt die vorherige text-orientation-Korrektur fort.

## Noch offen / Abhängigkeiten

- Automatischer SVG-Textumbruch (inline-size, shape-inside), volle CSS-Zeilen- und
  Tabulatorregeln, vertikaler Text auf Pfaden, method=stretch und komplexe
  Cluster-/Bidi-Formung. S26-Rest bleibt unverändert verbindlich.
- Glyphen, die einen Subpfadwechsel überbrücken, sowie spezielle geschlossene
  RTL-/textLength-Kombinationen benötigen weitere native Vergleichsproben.
  Die Kurventangente wird aus einer fein abgeflachten Kurve abgeleitet.
- Text als **Filterinhalt** folgt mit dem Filtergraphen S29–S31. Der jetzige
  Pfadbaum ist dafür geeignet; Textschatten wurden nicht als Ersatzfilter gemalt.
- **foreignObject mit HTML** bleibt offen. Das bestehende HTMLPage baut über
  RenderTree/GuiFactory Roblox-GUIs und führt BlockLayout daran aus. Es liefert
  noch keine vollständige Pixel-/Paintliste für SVG-Masken, Transformationen und
  Filter. Dafür braucht es eine gemeinsame HTML-Rasterausgabe; ein darübergelegtes
  GUI würde den S28-Test nicht bestehen. Dies ist zusätzliche Implementierungsarbeit,
  kein nachgewiesenes Roblox-Verbot. Eine foreignObject-Eingabe meldet derzeit
  `foreign-object-raster-bridge-unavailable` statt als unterstützt zu gelten.

## Prüfung

- Ganze SVG-Suite normal und -O2, inklusive voriger Etappen.
- Neue Tests: Position/Tangente auf geraden und transformierten Pfaden, Prozent-
  offsets, Anker, Subpfadlücken, geschlossene/rechte Pfade, ungültige Referenz,
  mehrzeilige Baselines sowie sichtbarer Pixelvergleich direkter Glyphen mit
  Glyphenclip und weißer Glyphenmaske. RGB unter Alpha=0 wird dabei ignoriert;
  alle sichtbaren RGB- und Alpha-Werte müssen exakt übereinstimmen.
- Acht Tafeln tatsächlich mit Luau gerastert; lokale Montage
  `build/svg-s27-s28-preview.png` angesehen. Native Browser-/Studio-Sichtprüfung
  bleibt dem Nutzervergleich vorbehalten.
- HTML-Regressionssuite, Generator-Checks, Projekt-Audit und Rojo-Builds.
  Controller prüft 20 Mount/Release-Zyklen, Größenwechsel und Abbruchbereinigung.

Grundlagen: [SVG 2 Text auf Pfaden](https://www.w3.org/TR/SVG2/text.html#TextPathElement),
[SVG 2 foreignObject](https://www.w3.org/TR/SVG2/embedded.html#ForeignObjectElement).
