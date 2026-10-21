# S35/S36 – Beleuchtung und formgenaue Maustests

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Stand 14.09.2026. S33/S34 vom Nutzer mit „gut weiter“ zum Fortfahren freigegeben.
S35/S36 ist im unten beschriebenen Umfang implementiert. Native Browser-/Studio-
Sichtprüfung und Vergleich der angezeigten Treffer bleiben beim Nutzer.

StudioDemoConfig: `SVGStage = "S35_S36"`, Stop → Play.
[Gemeinsame Tafeln](../tests/fixtures/svg-regressions.zip),
[S35](../tests/fixtures/svg-regressions.zip), [S36](../tests/fixtures/svg-regressions.zip).
Tasten 1/2/3: 240/480/960 Pixel. R: 20 Neuaufbauten.

| Tafel | Sichtprüfung |
|---|---|
| S35-diffuse | Dieselbe Alpha-Höhenkarte mit Fern-, Punkt- und Spotlicht. Lichtseiten, unbeleuchtete Seite, Spotgrenze und rote XY-Lichtmarkierungen. |
| S35-specular | Dieselben Lichtquellen, spiegelnde Lichtkarte mit transparentem Hintergrund. |
| S35-surface | Höhen 3/12 und Glanzexponenten 4/32. Glanzbreite und Reliefkante vergleichen. |
| S35-combined | Original gegen diffuse Farbe plus Glanz an Ring und echten Schriftkonturen. |
| S36-fill | Donutloch, sichtbare Füllung, vollständig transparente Füllung und fill=none. |
| S36-stroke | Dicke Linie, Striche/Lücken und gedrehte Form. |
| S36-events | none lässt durch; all trifft trotz visibility=hidden; stroke/fill funktionieren unabhängig von gezeichneter Farbe. |
| S36-clip-mask | Clip beschränkt Treffer; das transparente Maskenloch bleibt treffbar; spätere Form gewinnt bei Überlagerung. |

Bei S36 die Maus auf die nummerierten roten Kreuze bewegen und die
`Treffer:`-Zeile vergleichen. Browser und Roblox verwenden dieselben SVGs.
Die Browserzeile zeigt den echten nativen Event-Target; Roblox fragt den neuen
Geometriekern ab. Hilfsmarkierungen und Beschriftungen haben pointer-events=none.
Die Luau-Quellen enthalten zusätzlich Soll-IDs für alle nummerierten Punkte.

## Beleuchtung

FilterLighting ergänzt feDiffuseLighting und feSpecularLighting sowie die drei
Lichtquellen feDistantLight, fePointLight und feSpotLight. lighting-color läuft
durch die CSS-Kaskade, einschließlich currentColor und Filterfarbraum.
surfaceScale, diffuseConstant, specularConstant, beide specularExponent-Werte,
azimuth/elevation, x/y/z, pointsAtX/Y/Z, limitingConeAngle und kernelUnitLength
werden ausgewertet. Ungültige Werte oder fehlende/mehrere Lichtquellen werden
diagnostiziert.

Die Normale stammt aus Sobel-Ableitungen der Eingangsalpha-Höhenkarte.
Einseitige Ableitungen an Rand und Ecke entsprechen den SVG-Kernelfaktoren.
Punkt-/Spotlicht berücksichtigen die Höhe am Abtastpunkt. Diffuse Beleuchtung
erzeugt Alpha 1; spiegelnde Beleuchtung verwendet den größten Lichtfarbkanal
als Alpha und speichert das Ergebnis konsistent premultipliziert. Die bisherigen
Filterpuffer, Scanline-Abbruchpunkte und Speicherbudgets gelten weiter.

## Trefferprüfung

SVG/HitTest.prepare erzeugt einen unabhängigen Geometrieschnappschuss;
HitTest.query liefert die oberste getroffene Form mit SourceId/SourceNode.
Füllung nutzt winding/evenodd, Konturen den vorhandenen Stroke-/Dash-Kern
einschließlich Kappen, Joins, Transformationen und non-scaling-stroke.
Viewport-Clips und verschachtelte ClipPaths beschränken Treffer geometrisch.
Masken und Filteroutput bestimmen den Trefferbereich nicht. opacity=0 und
fill-opacity=0 unterdrücken einen geometrischen Formtreffer nicht.

Unterstützt: auto, none, visiblePainted, visibleFill, visibleStroke, visible,
painted, fill, stroke, all, bounding-box; CSS-Vererbung und überschreibende
Kinddeklarationen. display=none entfernt den Inhalt schon beim Szenenaufbau.
Geladene Rasterbilder prüfen bei painted/visiblePainted ihre ursprüngliche
Pixeltransparenz; all/fill/stroke schließen die ganze Bildfläche ein.

Der Laborcontroller nutzt UserInputService und passive Frames/ImageLabels.
Die Mauskoordinate wird über AbsolutePosition/AbsoluteSize der Tafel umgerechnet.
CanvasPosition-Änderungen aktualisieren den Treffer auch bei ruhender Maus.
Pointerabfragen starten keine Raster- oder Layoutaufträge. Verbindungen werden
bei Dispose getrennt; jeder Neuaufbau erhält eigene Geometrieschnappschüsse.

## Prüfungen und verbleibender Umfang

SVGLightingHit prüft flache/lineare Normalen an Innenpunkten, Rändern und Ecken,
Lambert-/Glanz-/Punktlicht-Sollwerte, Spotgrenzen, Farbkanäle/Alpha, CSS-Lichtfarbe,
Parameterdiagnosen und Abbruch/Speicherbilanz. Alle nummerierten Trefferpunkte
werden bei drei Auflösungen geprüft, zusätzlich Vererbung, unsichtbare Elemente,
Boundingbox, Kappen, verschachtelte Viewports und Rasterbildtransparenz.
Controller-Tests decken Maus/Scrollen ohne neue Rasterjobs, 20 Lebenszyklen,
überholte Resize-Aufträge und Trennen der Pointerlistener ab.

Acht 480-Pixel-Tafeln aus dem tatsächlichen Luau-Renderer wurden als
build/svg-s35-s36-preview.png geprüft. Dies ist keine automatische native
Browser-/Studio-Abnahme.

Offen und nicht als vollständige SVG-Parität zählen:

- SVG-Text wird bisher als Glyphenkontur getroffen. SVG verlangt hierfür
  zeichenweise Trefferzellen; komplexe Textlayouts bleiben Teil des Textrests.
- Externe SVG-Bilder verwenden zunächst ihre Bildfläche; die genaue
  Unterdokument-/Eventzuordnung ist noch offen. Rasterbildalpha ist umgesetzt.
- use-Schattenbaum-Retargeting, Eventpfade, Cursor, Hover/Active/Fokus,
  Tastatur/Touch folgen in S37. HTML-Seitenintegration bleibt S43.
- Der Schnappschuss muss nach Geometrie-/Stiländerungen neu erstellt werden;
  automatische Invalidierung folgt mit S38. Kurvenabflachung nutzt dieselbe
  diskrete Toleranz wie der Rasterrenderer, keine analytische Bézier-Gleichheit.
- Lichtnormalen und kernelUnitLength bleiben rasterabhängig. Starke Scherung,
  nichtuniforme Objektboxkoordinaten und Subpixelränder benötigen weitere
  native Vergleiche; keine Pixelgleichheit in diesen Spezialfällen zugesagt.
- Vorherige Restfunktionen (unter anderem feImage-Vektorverweise, Filterpuffer
  außerhalb der Szenentextur, Textlayout) bleiben im Gesamtplan offen.

Referenzen: [Filter Effects – Lighting](https://www.w3.org/TR/filter-effects-1/#feDiffuseLightingElement),
[SVG 2 – Pointer Events](https://www.w3.org/TR/SVG2/interact.html#PointerEventsProperty).

Abschlussprüfung: Finale SVG-Suite normal und -O2 bestanden, einschließlich Rasterbildalpha und Pointer-/Scroll-/Dispose-Controllerprüfungen. HTML-Regressionen und Generatorchecks bestanden. Projektaudit: 357 Luau, 6 JS, 61 HTML, 265 lokale Referenzen, 7 Rojo-Projekte, 126 Fonts. Workspace/SVGLab/HTMLPage gebaut; laufende Rojo-API bestätigt S35_S36, LightingHitSources, FilterLighting, HitTest und Trefferanzeige.


Spot-Kantenkorrektur nach Nutzervergleich: FilterLighting.shade verwendet jetzt
Skias linearen Kegelkantenübergang über 0.016 in Cosinuskoordinaten statt eines
harten Cutoffs. Gilt für diffuse und spiegelnde Beleuchtung; Diffuse-Alpha bleibt
1, Specular-Alpha folgt weiter dem maximalen Lichtfarbkanal. Keine Bildweichzeichnung.
Referenz: https://github.com/google/skia/blob/main/src/sksl/sksl_rt_shader.sksl
($spotlight_scale). Analytische Tests prüfen Außenkante, Viertel-/Halblicht und
volle Intensität inklusive premultiplizierter Specular-Farbe.
