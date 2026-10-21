# Flächen, Masken, Rahmen und Schatten

Stand: 1. Oktober 2026. Die Engine besitzt 509 katalogisierte CSS-Namen.
`supported` bezeichnet den angegebenen Roblox-Funktionsumfang, keine vollständige
CSS-Konformität oder Pixelgleichheit mit Chromium.

Nachtrag vom 7. Oktober 2026: Der aktuelle Katalog hat 531 Namen; die Zahl oben
gehört zum damaligen Profil. [CSS Atelier](CSS-ATELIER-20261007.md) ergänzt
Farbräume/Mischungen, Bildquellwahl, lokale SVG-Hintergründe, Initial-/Trimprofile
und Highlight-Paint. Die Grenzen unten gelten weiter, soweit das neue Profil sie
nicht ausdrücklich präzisiert. Die dortige Einordnung trennt native Hostgrenzen,
Annäherungen und weiterhin umsetzbare Restarbeit. Alte Stressseiten sind heute
Regressionstestdaten statt veröffentlichter Websites.

## Implementiert

| Bereich | Verhalten |
| --- | --- |
| `border-image` | Lineare, radiale und konische Verlaufsquellen; neun Bildsegmente; Slice-Zahlen und Prozente; `fill`; Breiten als Faktor, Länge, Prozent oder `auto`; Überstand als Faktor/Länge; `stretch`, `repeat`, `round`, `space`, getrennt pro Achse. |
| Masken | Kurzform mit Bild, Position, Größe, Wiederholung und Bezugsbox; Achsenkomponenten; WebKit-Kompatibilitätsnamen; Alpha- und Luminanzmasken; bestehende vier Kompositionsoperatoren. `mask:none` und CSS-weite Resets entfernen die Maske. |
| `mask-border` | Neun-Segment-Verlaufsmaske mit Slice/Fill, Breite, Überstand, Wiederholung und Modus. `-webkit-mask-box-image` und seine Komponenten werden auf dieselbe Implementierung abgebildet. |
| Ecken | Physische/logische Formen pro Ecke, Seiten-Kurzformen für Radius und Form, `round`, `bevel`, `notch`, `squircle`, `scoop`, `square`, `superellipse()`. Ungültige Kurzformen verändern keine einzelnen Komponenten. |
| Schatten | Die fünf `box-shadow-*`-Komponenten mit mehreren Schatten, zyklisch wiederholten Listen, `none`, `initial`, `inherit` und normaler Kaskade. |
| `clip` | Rechteckiger Ausschnitt der gesamten absolut/fest positionierten Box; automatische Kanten folgen der Größe; der Clip-Viewport wird beim Reflow wiederverwendet. |
| Tabellen | Fehlende CSS-Zeilen und Zellen werden als anonyme Layoutboxen erzeugt. Direkte `display:table-cell`-Kinder liegen in einer gemeinsamen Zeile. Der echte DOM-Elternknoten bleibt erhalten. |
| `border-shape` | Einzelner zentrierter Kreis mit Prozent-/Längenradius oder `closest-side`; Bezug ist die Half-Border-Box, der einheitliche solide Rahmen liegt mittig auf der Kontur. Hintergrundfarbe und Rahmen werden gemeinsam gerastert. Wiederverwendung bei Reflow; `none`/`initial` stellen den rechteckigen Hintergrund wieder her. |
| `box-decoration-break` | Horizontale Inline-Zeilen mit Hintergrundfarbe, Padding und geraden Rahmen: `clone` wiederholt seitliche Kanten an jedem Zeilenfragment, `slice` behält sie nur am Anfang/Ende. Dekorationsflächen werden beim Reflow wiederverwendet; der Text bleibt normal umbrechbar. |
| Containerfilter | `brightness(0–100%)` und `opacity()` multiplizieren den gesamten nativen Unterbaum über CanvasGroup. CSS-Deckkraft wird zusätzlich multipliziert. Schriftzeichen werden nicht rasterisiert oder ersetzt; `img` bleibt beim bisherigen Bildfilterpfad ohne doppelte Filterung. |
| Lokale SVG-Bilder | Alle 16 Stressseiten liefern das originale `sample.svg` über `Options.SVGs` mit. Der bestehende SVG-Renderer benötigt dafür keine veröffentlichte Roblox-Bild-ID. Der Generator erhält diese Zuordnung bei erneuter Erstellung. |
| Bildausschnitte | `object-view-box:none/inset()/xywh()/rect()` verändert natürliche Bildgröße und Fit-/Positionsreferenz. Originalpixel außerhalb der Referenz sind wie in Chromium Ink-Overflow und werden an der Contentbox abgeschnitten. Resets und nachträgliche Zustandsänderungen verwenden denselben Clip. Externe SVG-Bilder werden erst im natürlichen Seitenverhältnis gerastert und danach passend skaliert. |
| Bildformen für Textfluss | `shape-outside:url()` aus lokalen SVG-Zuordnungen oder lesbaren Roblox-Assets; `shape-image-threshold` als Zahl/Prozent mit Clamp 0–1; Alpha muss strikt größer sein. Vollständige Zeilenbänder berücksichtigen linken/rechten Float, Contentbox, Padding/Rahmen/Margin und euklidischen `shape-margin`. Asynchroner Seiten-Cache ohne GPU-Textur, maximal 8 MiB Alpha und 32 Quellen, vier Schwellenvarianten pro Quelle. |
| Maskentyp und native Bildwerte | `mask-type:alpha/luminance` für SVG-mask-Ressourcen ist im SVG-Rasterizer pixelwirksam; auf HTML-Boxen wie im Browser ohne Wirkung. `image-orientation:from-image` verwendet die bereits importierte Roblox-Ausrichtung, `image-resolution:1dppx` die normale Zuordnung von Bildpixeln. CSS-weite Resets und Vererbung sind implementiert. |
| HTML-Bilder aus lokalen SVGs | Erfasste Filterkette einschließlich Blur/Drop-Shadow, dann echte Clip-Alphaabdeckung, dann unterstützte Verlaufsmasken/Maskenrahmen; Object-Fit und transparente Filterüberstände. Retained Effektfläche, budgetierte Queue, Cache, schnelle Rücknahme, Resize und Ressourcenabbau. |
| HTML-Mischgruppen | Unterstützte Farben, Verläufe, Text-/Canvas-Rasterflächen und runde/elliptische Kanten werden einschließlich Alpha und Backdrop verrechnet. Computed Style bleibt unverändert. Native Referenzen für normal/multiply/screen/difference und isolierte Untergruppen; Paintpositionen absoluter Kinder, Eingabeziele und retained Oberfläche bleiben erhalten. |
| Gestaltete Buttons / 3D | Buttons mit Elementkindern behalten eigene Layout-/Paintboxen und den Controlzustand. Beide absolut positionierten Flip-Seiten erreichen den bestehenden perspektivischen 3D-/Backfacepfad. Wiederholtes Wenden, Maße, Pixel-Farben und disabled-Click sind geprüft. |

`mask` setzt zusätzlich die `mask-border`-Komponenten zurück. Numerische
Schattenkomponenten und logische Rahmen nehmen an `initial`/`inherit`/`unset` teil.
Die bisherigen SVG- und Seitenladeverfahren werden dadurch nicht ersetzt.

## Grenzen der Darstellung

- Rahmen mit externen Roblox-Assets bleiben im bisherigen nativen Slice-/Tile-Profil.
  Ohne Originalpixel und Bildabmessungen sind prozentuale Quell-Slices,
  asymmetrische Breiten und CSS-Kachelverteilung nicht vollständig reproduzierbar.
- Rastermasken erfassen Text, Farben und unterstützte Verlaufsflächen. Externe
  Bilder, Video und native Formular-GUIs sind in diesem Raster nicht vollständig
  vorhanden. URL-/SVG-Masken werden weiterhin diagnostiziert.
- `mask-border-outset` verändert die Quell-/Zielgeometrie; maskierter Inhalt
  außerhalb der rechteckigen Box wird derzeit nicht in die Maskenfläche aufgenommen.
- Die `mask`-Kurzform akzeptiert noch keine Composite-/Mode-Tokens. Diese Werte
  müssen als `mask-composite` und `mask-mode` gesetzt werden. Unterschiedliche
  Kompositionsoperatoren pro Maskenebene fehlen weiterhin.
- Rasterauflösung und Bildbudgets bleiben begrenzt. Große Flächen werden
  verkleinert gerastert; fehlende EditableImage-Berechtigung oder erschöpfte
  Budgets erzeugen eine Warnung und den vorhandenen Ersatzpfad.
- HTML-Mischgruppen sind auf 64 Boxen und 512 Rasterpixel pro Achse begrenzt;
  nicht lesbare native Bild-/Video-/Controlpixel und transformierte Gruppen
  behalten ihre native Darstellung mit Diagnose. Beliebiges Stacking, aus der
  Gruppe hinausragender Inhalt, alle Filter-/Maskenkombinationen und originale
  Font-/Glyphenpixel sind keine belegte Browsergleichheit. Die CPU-Textdarstellung
  der bestehenden 3D-/Masken-/Canvaspfade bleibt approximiert.
- SVG-Bildeffekte setzen eine lokale SVG-Zuordnung und EditableImage voraus.
  Rohquelle maximal 1024 Pixel pro Achse, Effektfläche maximal 512; Koordinaten
  folgen weiterhin den CSS-Boxen. Clip-Antialiasing und Blur sind angenähert.
  Fremde URL-/SVG-Masken sind damit nicht zusätzlich implementiert.
- Der Rich-Button-Pfad belegt gestaltete Kinder und bereits so gerenderte
  DOM-Inhaltsänderungen. Vollständige UA-Formatierung aller Buttonkombinationen
  und nachträgliche Promotion einfacher Captionbuttons bleiben eigene Restfälle.
- Schatten verwenden den vorhandenen Roblox-Schattenrenderer. Browser-Blur und
  nicht-runde Schattenkonturen sind nicht pixelgleich; Eckraster sind approximiert.
  Rasterecken über Hintergrundbildern bleiben eingeschränkt.
- Rotiertes/3D-transformiertes `clip:rect()` ist nicht zuverlässig pixelgleich.
  Das neue Rechteckprofil deckt normale absolute/fixed Boxen ab.
- Logische Kompatibilitätsnamen folgen dem vorhandenen horizontalen Schreibprofil;
  vertikale Schreibmodi sind keine vollständige CSS-Implementierung.
- `border-shape` ist ein Zeichenprofil: keine Ellipse/Polygon-/Pfadkonturen,
  zwei Konturen, geformten Schatten, Hintergrundbilder oder geformte
  Overflow-/Treffertestregionen. Unvereinbare Kombinationen werden diagnostiziert.
  Kinder bleiben rechteckig angeordnet; der Kreis verändert keine Layoutmaße.
- `box-decoration-break` besitzt keine Seiten-/Spaltenfragmentierung, runden
  Fragmentkanten, Bildhintergründe, fragmentierten Schatten, verschachtelten
  Dekorationsstapel oder eigenen Inline-Deckkraftgruppen. Solche Inline-Kombinationen
  melden eine Einschränkung und behalten die bisherige atomare Darstellung.
- Containerfilter unterstützen keine Aufhellung über 100%, Blur, Contrast,
  Grayscale, Saturate, Farbrotation oder Drop-Shadow des gesamten Unterbaums.
  Dafür fehlen die vollständigen Pixel von nativen Text-, Video- und Formular-GUIs.
  Die vorhandene Filterkette für `img` bleibt unabhängig davon nutzbar.
- Bildformen benötigen lesbare Pixel oder ein zugeordnetes lokales SVG. Fehlende
  Zuordnung/Berechtigung oder Budgetüberschreitung wird gemeldet und behält die
  rechteckige Floatfläche. SVGs werden bis maximal 1024 Pixel pro Achse gerastert;
  Antialiasing kann kleine Abweichungen an Alpha-Grenzen erzeugen. CSS-Verläufe,
  externe Downloads und Polygonformen in shape-outside fehlen weiterhin.
- Bildausschnitte mit runden Ecken in der inset()/rect()/xywh()-Funktion fehlen.
  Rohes EXIF, `image-orientation:none`, manuelle Orientierung/Spiegelung und andere
  Bildauflösungen als 1dppx sind nicht verfügbar. HTML-URL-Masken sind weiterhin
  nicht implementiert; SVG-mask-Ressourcen bleiben beim vorhandenen SVG-System.

## Nicht als Unterstützung ausgegeben

`border-shape` und `box-decoration-break` besitzen die oben beschriebenen
Teilprofile. Das ist keine vollständige Umsetzung aller Konturen und
Fragmentierungsregeln; weitere Werte bleiben ausdrücklich offen.

Der Browser meldet bei vielen übrigen Warnungen selbst „Property unbekannt“:
`-moz-border-*-colors`, `-moz-outline-radius*`, `-ms-filter`,
`-webkit-mask-attachment`, `background-image-transform`, `background-tbd`,
`border-image-transform`, `border-boundary`, `border-limit`, die `border-clip`-
Familie und die historischen unpräfixierten `mask-box*`-Namen.
Diese Namen bleiben ausdrücklich als nicht unterstützt diagnostiziert.
Der aktuelle Borders-Entwurf kennzeichnet partielle Rahmen sogar als noch nicht
implementierungsreif; ein Browservergleich kann dafür keine fertige Referenz liefern.

## Nachweise

`tests/VisualCompleteness.luau` prüft Kaskade, atomare Kurzformen, Alpha/Luminanz,
Neun-Segment-Raster, DOM-erhaltende Tabellenreparatur und Clip-Reflow/Reset.
Die vorhandenen Masken-, Rahmen-, Schatten-, Tabellen- und Lebensdauertests
ergänzen dies. `StressCatalog` führt alle 16 echten Kategoriequellen bei
1280, 800, 390 und erneut 1280 Pixel Breite aus.
`FeasibleVisuals` prüft Container-/Bildfiltertrennung, Kreispixel,
Wiederverwendung/Reset und Inline-Kanten bei `clone`/`slice` und Größenänderungen.
Die Horizontalmaße der echten HTML-`clone`-Probe stehen in
`tests/fixtures/inline-fragments-browser.json`; mit diesen Browser-Schriftmaßen
prüft der Test identische Wortpositionen, Zeilenzuordnung und Fragmentbreiten.
Luau-Mocks und ein Rojo-Build ersetzen keine visuelle Studio-Prüfung.
`RemainingVisuals` und `SVGShapeImages` prüfen echte SVG-Alpha-/Maskenpixel,
Schwellenwerte, Source-Reuse, Abbau, dynamische Metadaten, Crop/Fit und Resets.
`tests/fixtures/remaining-visuals-browser.json` enthält die Chromium-Maße und
sechs Float-Zeilenpositionen aus der eigenständigen HTML-Referenz.

Referenzen:

- [CSS Borders and Box Decorations Level 4](https://drafts.csswg.org/css-borders-4/)
- [CSS Tables: anonyme Boxen](https://drafts.csswg.org/css-tables-3/#fixup)
- [CSS Masking Level 1](https://www.w3.org/TR/css-masking-1/)
- [CSS Shapes: Bilder und Alpha-Schwellenwerte](https://www.w3.org/TR/css-shapes/#shapes-from-image)
- [CSS Images 5: object-view-box](https://drafts.csswg.org/css-images-5/#the-object-view-box)
- [Entfernte Firefox-60-Rahmenfarben](https://developer.mozilla.org/en-US/Firefox/Releases/60)
