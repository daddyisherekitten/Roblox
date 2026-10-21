# SVG: geplanter Einstieg

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Seit dem 14. Oktober ist das eigenständige SVG-Labor entfernt.
Die früheren Etappen sind als CLI-Regressionsdaten erhalten; SVG in HTML
wird weiterhin durch die Engine dargestellt.

Aktuell 14.09.2026: S35/S36 nach Spot-Kantenkorrektur mit „gut weiter“ freigegeben.
S37/S38 implementiert; Browser-/Studio-Sicht- und Eingabevergleich noch offen.
StudioDemoConfig: S37_S38. Vergleich: examples/svg-tests/s37-s38.html.
Neue SVG/Events, Session und Queries; eigener interaktiver Lab-Host und acht
Tafeln. Farbwechsel behalten die Treffergeometrie, gleich große Rasterupdates
verwenden dasselbe EditableImage. Generator: sync-svg-runtime.py.
Tests: SVGRuntime und SVGInteractiveHost (inkl. 20 Resets/Abbruch/Freigabe).
Details/Restumfang: docs/SVG-S37-S38.md. Keine JS-/Script-Vollunterstützung;
Callback-Labor, use-Retargeting und HTML-Integration bleiben getrennte Aufgaben.
Nach dem Nutzervergleich folgt S39/S40. Ältere Statusabschnitte sind Historie.


Aktuell 14.09.2026: S33/S34 mit „gut weiter“ zum Fortfahren freigegeben.
S35/S36 implementiert; nativer Sicht-/Pointervergleich offen. StudioDemoConfig
S35_S36, Vergleich examples/svg-tests/s35-s36.html. FilterLighting ergänzt
Diffuse/Specular mit Distant/Point/Spot; SVG/HitTest liefert geometrische
Treffer mit pointer-events, Clips, Maskensemantik und Rasterbildalpha.
Lab nutzt UserInputService, passive Tafeln und Trefferzeilen ohne neue Rasterjobs.
Generator sync-svg-lighting-hit.py; Tests SVGLightingHit.luau plus Controller.
Vorschau build/svg-s35-s36-preview.png: acht echte Luau-Rastertafeln geprüft.
Grenzen: Text noch Glyphenkontur statt Zeichen-Trefferzellen, SVG-Bildretargeting
und use/Eventpfad offen. S37/S38 nach Nutzervergleich. Details: SVG-S35-S36.md
(im Projekt unter docs/). Ältere Statusabschnitte sind Historie.


Aktuell 14.09.2026: S31/S32 vom Nutzer mit „perfekt weiter“ freigegeben.
S33/S34 implementiert, nativer Sichtvergleich offen. StudioDemoConfig S33_S34;
Vergleich examples/svg-tests/s33-s34.html. Neue FilterKernel/FilterMorphology/
FilterNoise; Filter/FilterPixels und Runner erweitert. Acht Tafeln, gleicher
RGBA-Resolver plus analytische R/G-Rampe. Generator sync-svg-kernel-filters.py,
Tests SVGKernelFilters.luau. SVG normal/-O2 und HTML-Regressionen bestanden;
480-Pixel-Luau-Vorschau build/svg-s33-s34-preview.png angesehen.
Grenzen ausdrücklich beibehalten: feImage-Vektorverweise noch nicht unterstützt;
SVG-1.1-/Skia-Rauschinitialisierung statt neuerer Entwurfsvariante; diskrete
Morphologie/gedrehte Kanten. S33 nicht als vollständig erledigt markieren.
Details in docs/SVG-S33-S34.md (aus docs: SVG-S33-S34.md).
Nächstes Paket S35/S36 nach Nutzervergleich. Vorherige Statusabschnitte sind Historie.


**Verbindliche weitere Planung:** [SVG-Gesamtplan mit 45 visuellen Etappen](SVG-PLAN.md).
Er ersetzt die folgende frühere, nur auf die Blume zugeschnittene Reihenfolge.
Die Angaben zum Blumenbeispiel bleiben als Referenz erhalten.

Status: [S01](SVG-S01.md) und [S02](SVG-S02.md) visuell bestätigt.
[S03 HTML-Layoutbox](SVG-S03.md) ebenfalls visuell bestätigt.
[S04-Viewport-Kern und Vergleichslabor](SVG-S04.md) visuell bestätigt.
[S05-Längeneinheiten](SVG-S05.md) visuell bestätigt.
[S06-Grundformen](SVG-S06.md) visuell bestätigt.
[S07-Füllung und Kontur](SVG-S07.md) visuell bestätigt.
[S08-Gerade Pfade](SVG-S08.md) visuell bestätigt.
[S09-Bézierkurven](SVG-S09.md) visuell bestätigt.
[S10-Elliptische Bögen](SVG-S10.md) visuell bestätigt.
[S11-Füllregeln und Pfadlänge](SVG-S11.md) visuell bestätigt.
[S12-Konturen und Strichmuster](SVG-S12.md) visuell bestätigt.
[S13-Transformationen](SVG-S13.md) visuell bestätigt.
[S14-Zeichenreihenfolge und Deckkraft](SVG-S14.md) visuell bestätigt.
[S15/S16 CSS und Instanzen](SVG-S15-S16.md) gemeinsam visuell bestätigt.
[S17/S18 Farbverläufe](SVG-S17-S18.md) visuell bestätigt.
[S19/S20 Muster und Marker](SVG-S19-S20.md) nach Rot-Korrektur zum Fortfahren freigegeben.
[S21/S22 Bilder und Ausschnitte](SVG-S21-S22.md) visuell bestätigt.
[S23/S24 Masken und Mischmodi](SVG-S23-S24.md) visuell bestätigt.
[S25/S26 Text und Typografie](SVG-S25-S26.md): Kern visuell bestätigt, dokumentierte Restfunktionen offen.
[S27/S28 Textpfade und Textressourcen](SVG-S27-S28.md): Kern zum Fortfahren freigegeben; Umbruch-/foreignObject-Rest offen.
[S29/S30 SVG-Filter und Farben](SVG-S29-S30.md): Graph, Farbmatrizen, Kanalfilter und Textfarbfilter implementiert; visueller Vergleich offen.
Der Geometrie-/Rasterkern zeichnet jetzt sechs Grundformen im SVG-Labor.
Präsentationsfarben, Vererbung, currentColor und getrennte Paint-Alpha sind im Labor
angebunden. Vollständige CSS-Auflösung und HTML-Paint-Anbindung folgen.
examples/svg-flower.html enthält das vom Nutzer gelieferte
Blumenbeispiel, examples/svg-flower.css die zugehörigen Regeln. Die SVG-Datei
verweist auf diese CSS-Datei statt auf style8.css. Hauptdemo unverändert.

## Umsetzung in prüfbaren Schritten

1. SVG-Wurzel als eigene Layoutbox: width/height, viewBox mit negativem Ursprung,
   preserveAspectRatio. Grundformen rect/circle/ellipse/line/polygon/polyline,
   fill/stroke/stroke-width und geglättete Ausgabe in einem passiven ImageLabel.
   Geometrie, Rasterisierung und Roblox-Ressourcenverwaltung getrennt halten.
2. Gruppen und Transformationsmatrizen: translate/rotate/scale/matrix,
   Vererbung der Darstellungsattribute, CSS-Vorrang, echte Gruppen-Opacity.
   Gruppentransparenz nach dem Zusammenzeichnen anwenden, nicht pro Teilform.
3. Path-Parser mit absoluten/relativen M/L/H/V/C/S/Q/T/A/Z, Kurven unter
   Transformation adaptiv unterteilen. Die Blume braucht M, v, a und z;
   Kreisbögen und korrekte Stroke-Kanten sind für sie erforderlich.
4. defs, linearGradient/radialGradient, stop/stop-color/stop-opacity,
   url(#id), gradientUnits (im Beispiel userSpaceOnUse).
5. SVG-Text: x/y, Baseline, Schriftgröße/-gewicht und transformierter Text.
   Bestehende Fontprofile nutzen; Textdarstellung nicht als Teil des normalen
   HTML-Zeilenumbruchs behandeln.
6. Formgenauer Hit-Test einschließlich Stroke und Transformation, Hover entlang
   der DOM-Vorfahren, cursor. Änderungen nur innerhalb der betroffenen SVG-Ausgabe
   neu zeichnen; kein Seitenlayout für reine Farbwechsel. Keine nativen Buttons.
7. CSS-Custom-Properties/var samt Vererbung und Ersatzwerten für SVG anbinden bzw.
   ergänzen. Für externe CSS-Dateien den vorhandenen CSS-Eingabepfad/Resolver
   explizit verwenden; ein Dateiname lädt in Roblox nicht automatisch CSS.

Das Beispiel enthält kein use-Element, obwohl seine CSS-Kommentare use erwähnen.
defs wird dort ausschließlich für den radialen Verlauf verwendet. use/symbol,
clipPath/mask, SVG-Filter und Animationen sind spätere, separate Erweiterungen;
sie sind für diese Blume nicht erforderlich.

## Referenzprüfung und Grenzen

Das Beispiel enthält 80 Paths, 1 Circle, 2 Text-Elemente und einen radialen Verlauf.
Die zusätzlichen Legacy-Selektoren sind mitgespeichert; ihre höhere Spezifität
übersteuert hier teilweise die Regeln mit var(). Die Custom-Properties deshalb
zusätzlich isoliert testen, damit die Legacy-Regeln Fehler nicht verdecken.

Tests pro Schritt: negative viewBox-Ursprünge und Skalierung, Pixel-/Alphawerte,
Transformationsreihenfolge, Pfadschließung/Kurven, Gruppenüberlagerung, Farbverlauf,
Baseline, Hover nur auf tatsächlichen Formen, Cache/Resize/Abbruch/Cleanup.
Erst danach Blume gegen Browser und Roblox vergleichen und als unterstützten
Engine-Test aufnehmen. Pixelgenaue Text- und Kantengleichheit ist zu prüfen.

EditableImage ist die geplante Pixel-Ausgabe. SVG muss zuvor von unserer Engine
interpretiert und rasterisiert werden. Geometrie bei Hover wiederverwenden,
Auflösung und Rasterarbeit begrenzen, Bilder bei Seitenende freigeben.

Referenzen: https://www.w3.org/TR/SVG2/struct.html und
https://www.w3.org/TR/SVG2/paths.html.

[S31/S32 Räumliche Filter und Komposition](SVG-S31-S32.md): Blur, Schatten, Offset, Flood, Composite und Merge integriert; acht Tafeln zur visuellen Abnahme.
