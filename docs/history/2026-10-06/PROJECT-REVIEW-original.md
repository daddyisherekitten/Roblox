# S29/S30: Filtergraph und Farboperationen

Aktuell 14.09.2026: S43/S44 zum Fortfahren bestätigt. S45 auf „gut“ umgesetzt.
StudioDemoConfig: S45. Browser: examples/svg-tests/s45.html.
Vier Kombinationstafeln: Blume/use/Hover, Diagramm/Textpfad, Symbol-/Pattern-/Maskkarte,
interaktive Filter-/Animationsszene mit gemeinsamem JavaScript-Verlauf.
1/2/3 Größen, P Start/Pause, Z/X/C/V/B feste Zeiten, R Reset. Start pausiert.
Generator: scripts/sync-svg-acceptance.py. Quellen: AcceptanceSources.luau.
Tests: SVGAcceptance, kombinierter S45-Zweig in SVGInteractiveHost,
scripts/test-svg-acceptance-browser.cjs (DOM-Mocks). Echte Rastervorschau:
build/svg-s45-preview.png. Nativer visueller S45-Vergleich noch offen.
Details: docs/SVG-S45.md. Maßgebliche Übersicht der offenen Funktionen:
docs/SVG-SUPPORT.md. Der gesamte SVG-Plan ist ausdrücklich noch nicht abgeschlossen.
Native Browser-/Studio-Automation bleibt wegen vorheriger automatischer
Freigabeablehnung aus; Nutzer öffnet die lokale Vergleichsseite manuell.
Nächster Schritt: S45-Nutzervergleich; danach Restarbeiten anhand Supportkatalog.
Ältere Statusabschnitte darunter sind Historie.


Aktuell 14.09.2026: S41/S42 mit „alles gleich“ zum Fortfahren bestätigt.
Auf „ok“ S43/S44 implementiert, nativer visueller Vergleich noch offen.
StudioDemoConfig: S43_S44. Browser: examples/svg-tests/s43-s44.html.
Acht HTML-Tafeln, elf echte SVG-ImageLabels über Shared SceneBuilder/Embedded.
Serielle RenderQueue mit Coalescing, Pixelcache, Textur-Reuse und Speicherlimits.
1/2/3: 240/480/960 px, C: Resize, R: 20 komplette Seiten-Neuaufbauten in Studio.
Tests: SVGIntegration, SVGHTMLIntegration, SVGIntegrationController,
scripts/test-svg-integration-browser.cjs; Generator sync-svg-integration.py.
Umfang/Grenzen/Messwerte: docs/SVG-S43-S44.md. Vorschau: build/svg-s43-s44-preview.png.
SVG-Cascade/IDs in HTML derzeit je SVG gekapselt; kein voller gemeinsamer DOM,
keine automatische eingebettete Skript-/Animationslaufzeit, kein Geometriecache.
Keine nativen Browser-/Studio-Automationen: vorherige automatische Freigabeprüfung
hat Browsernavigation abgelehnt. Nutzer öffnet die Vergleichsseite manuell.
Nach visuellem Nutzervergleich: S45, mit ehrlichem Audit aller Restfunktionen.
Ältere Statusabschnitte darunter sind Historie.


Aktuell 14.09.2026: Auf „gut mach“ S41/S42 umgesetzt, visueller Vergleich offen.
StudioDemoConfig: S41_S42. Browser: examples/svg-tests/s41-s42.html.
S41 echte begrenzte JS-AST-Ausführung via ScriptSyntax/ScriptVM/ScriptDOM, gleiche
JS-Quellen in Browser und Roblox. S42 Conditional/switch/systemLanguage,
view-Fragmente, Metadaten/Ressourcendiagnosen und expliziter Legacy-Audit.
R Reset, 1/2/3 Größe; keine P-Starttaste nötig. Vier Tafeln reagieren auf Klick.
Die letzte Tafel hat absichtlich missing-use-target. Sprache im Lab en.
Generator: scripts/sync-svg-scripting.py. Tests: SVGScript, SVGScriptScenes,
SVGInteractiveHost + scripts/test-svg-scripting-browser.cjs (DOM-Mocks).
Details/Restumfang: docs/SVG-S41-S42.md. Vorschau: build/svg-s41-s42-preview.png.
S39/S40 zum Fortfahren freigegeben, keine zusätzliche Vollabnahme behaupten.
Nächste Etappen nach Nutzervergleich S43/S44; ältere Abschnitte sind Historie.

Aktuell 14.09.2026: S37/S38 inklusive Korrekturen vom Nutzer mit
„perfekt alles passt weiter“ freigegeben. S39/S40 implementiert im dokumentierten
Teilumfang; manueller Browser-/Studio-Vergleich offen.
StudioDemoConfig: S39_S40. Vergleich: examples/svg-tests/s39-s40.html.
P Start/Pause, Z/X/C/V/B feste Zeiten 0/.25/.5/.75/1 s, R Reset, 1/2/3 Größe.
Neue AnimationTiming/AnimationValue/Animation/AnimationCSS-Module, animierte
Document-Overlays, gemeinsame Lab-Uhr und acht neue Vergleichstafeln.
Generator: scripts/sync-svg-animation.py. Umfang, Tests und explizite Grenzen:
docs/SVG-S39-S40.md. Nächstes Paket nach Abnahme: S41/S42.
Ältere Statusabschnitte darunter sind Historie.

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


Abschlussprüfung S31/S32: SVG-Suite normal und -O2 bestanden, einschließlich
Controller-Neuaufbau/Abbruch/Freigabe. Acht finale 480-Pixel-Tafeln aus dem echten
Luau-Rasterrenderer in build/svg-s31-s32-preview.png angesehen. HTML-Regressionen,
beide Filtergenerator-Checks und Projektaudit bestanden: 344 Luau, 6 JS,
55 HTML, 259 lokale Referenzen, 7 Projekte, 126 HTML-Fonts. Workspace/SVGLab/
HTMLPage gebaut. Laufende Rojo-API liefert S31_S32 und die neuen Quellen/Module.
Native Browser-/Studio-Sichtprüfung des Pakets bleibt beim Nutzer.

Aktuell S31/S32: SVGStage=S31_S32, acht Tafeln in examples/svg-tests/s31-s32.html.
S29/S30 nach direkter Filterreferenz korrigiert und zum Fortfahren freigegeben.
Neue FilterOps/FilterBlur/FilterPixels; Filter.build/Style/Raster und Runner
integriert. Räumlicher Graph auf premultiplizierten Float32-Ausschnitten,
Gaußfaltung mit 3-sigma-Radius entlang transformierter Achsen, bilineare Offsets,
Flood/DropShadow/Composite/Merge. Reine Farbgraphen bleiben punktweise.
Quellen SpatialFilterSources/CompositeFilterSources/SpatialCompositeSources,
Generator scripts/sync-svg-spatial-filters.py. Tests SVGSpatialFilters.luau.
Nullfilter-Test vergleicht sichtbares RGB und jedes Alpha; bei Alpha exakt null
werden nur verborgene RGB-Werte ignoriert. Keine Änderung sichtbarer Pixel.
S31/S32-Stand/Grenzen siehe SVG-S31-S32.md; edgeMode duplicate/wrap und
außerhalb der Szenentextur liegende Quellpixel bleiben offen. Nutzerabnahme
steht aus. Browser-Steuerung file:// weiterhin nicht über Umwege versuchen.

## Vorheriger Stand

S29-Nachkorrektur: Nutzer sieht unten in S29-text-order nichts. Filter href
wird im Zielbrowser nicht unterstützt und ist laut CSSWG 22.07.2026 gestrichen.
Gemeinsame Tafel referenziert jetzt direkt #base; identische Quellen für beide
Renderer. Original separat S29-filter-href-known-difference.svg. Engine href
bleibt Legacy-Erweiterung, keine Browserparitätszusage. Siehe SVG-S29-S30.md.


Abschlussprüfung: vollständige SVG-Suite normal und -O2 bestanden; acht finale
480-Pixel-Rastertafeln erzeugt und geprüft. HTML-Suite und Generator-Abgleiche
bestanden. Projektaudit: 337 Luau, 6 JS, 52 HTML, 256 lokale Referenzen,
7 Rojo-Projekte, 126 HTML-Fonts. Workspace/SVGLab/HTMLPage gebaut.
Rojo-API bestätigt S29_S30, FilterSources und den aktuellen Filtercode.

Acht native Vergleichstafeln sowie gemeinsamer punktweiser Filtergraph für
Formen, Gruppen, Textkonturen und Bilder. Grenzen/Abnahme:
[SVG-S29-S30.md](SVG-S29-S30.md). feBlend als in2-Verbraucher vorgezogen;
räumliche Filter und weitere Primitive folgen in S31–S35.

Numerische RGBA-Orakel, Graph-/Referenz-/Regionsprüfungen, Filter-Reihenfolge,
Textfilter und Viewportgrenzen in tests/SVGFilters.luau. Lokale Luau-Rastertafeln
angesehen, Nutzerabnahme des nativen Browser-/Studio-Vergleichs steht noch aus.

## Vorheriger Stand

# S27/S28: Textpfade und Textressourcen

Nach Nutzervergleich: CSS-pre-Probe rechts bricht im Zielbrowser nicht um.
Sie zählt nicht als browsergleich. Gemeinsame Tafel auf relative/absolute
tspan-Zeilen korrigiert, ursprünglichen CSS-Fehlerfall separat beibehalten.
Generator-Abgleich, Audit und Workspace-Build der Korrektur bestanden.

S25/S26 visuell bestätigt. Neuer TextPath-Kern, Textclips/-masken/-muster und
CSS-Zeilenumbrüche mit acht Vergleichstafeln. Stand/Grenzen:
[SVG-S27-S28.md](SVG-S27-S28.md). Automatischer Umbruch, Textfilter und die
HTML-Rasterbrücke für foreignObject bleiben offen, kein vollständiges S28 behauptet.

SVG-Suite normal und -O2 bestanden; numerische Pfadplatzierung, Prozentoffsets,
Anker, Transform, Subpfadlücken, geschlossene/rechte Pfade, Zeilenhöhe,
Referenzfehler und exakter sichtbarer Pixelvergleich Text/Clip/Maske.
Neue Controller-Lebenszyklen, HTML-Regressionen, Generator-Abgleiche, Audit und
drei Builds bestanden. Rojo-API aktuell. Acht tatsächliche Luau-Rastertafeln als
PNG angesehen; native Browser-/Studio-Abnahme durch Nutzer noch offen.

## Vorherige Prüfung S25/S26: Text und Typografie

S23/S24 visuell bestätigt. Neuer Textkern plus acht native Vergleichstafeln
unter examples/svg-tests/s25-s26.html. Vollständiges Unicode-Bidi/komplexes Shaping
bleibt offen; aktueller Teilumfang und Grenzen: [SVG-S25-S26.md](SVG-S25-S26.md).

Prüfung: gesamte SVG-Suite normal/-O2; Textlayout, GPOS-Kerning gegen HarfBuzz,
GSUB-Standardligaturen, Latin-Komposition, echte Textkontur-/Alpha-Pixel,
Diagnosen, Source-DOM bleibt unverändert, Controller mit 20 sauberen Zyklen.
Font-Fallbacklisten und echter BoldItalic-Schnitt zusätzlich geprüft.
HTML-Regressionen, beide Generator-Checks, Audit und drei Rojo-Builds bestanden.
Rojo-API enthält neues Stage/Modul/Quellen/Font-Faces. Lokale Luau-PNG-Montage
mit acht Tafeln geprüft; native Browser-/Studio-Abnahme weiterhin durch Nutzer.

## Vorherige Prüfung S23/S24: Masken und Mischmodi

Mask löst Regionen, Inhaltskoordinaten, Maskenmodus, verschachtelte Ressourcen
und Luminanz-Alpha auf. Blend implementiert 16 CSS-Level-1-Modi. Style/Rendering,
Resources und der Laborbesucher binden die Werte ein. Compositing trennt echte
Isolation von bloßem Clipping und mischt mit dem tatsächlichen SVG-Hintergrund.
Teilalpha wird in der Blend-/Source-over-Formel berücksichtigt. Ein durch die
S22-Regression entdeckter transparenter RGB-Rest wurde kanonisch genullt.

Prüfung: SVG-Suite normal (build/svg-masks-blends.log), dieselbe vollständige
Suite -O2 plus Vorschau (build/svg-masks-o2-preview.log), HTML-Suite,
Generator-Synchronität, Projektaudit und default/svg-lab/htmlpage-Builds bestanden.
Audit: 313 Luau, 6 JS,43 HTML,247 Referenzen,7 Rojo-Projekte,126 Fontzuordnungen.
Rojo-API auf 127.0.0.1:34872 liefert S23_S24, Mask, Blend und MaskBlendSources.
Lokale Rastervorschau aller sieben Tafeln bei 480 px visuell geprüft.
Numerische Masken-/Blend-/Alpha-/Isolationstests sowie sieben Quellen bei
240/480/960 px und 20 Controller-Lebenszyklen bestanden. Keine automatische
Browser- oder Studioabnahme behauptet; Nutzervergleich steht aus.

Hintergrundzugang untersucht: HTML RenderTree erzeugt GUI-Hintergründe und
ImageBox separate ImageLabels; kein RGBA-Hintergrund fließt zum SVG-Rasterer.
SVG-Hintergrund-Blending ist implementiert, beliebiges HTML-/3D-Blending bleibt
S43-Integration. Weitere Grenzen und Quellen: SVG-S23-S24.md. Kein vollständiger
CSS-Masking-/Filter-/Text-Support behauptet.

---

# S21/S22: Bilder und clipPath

Neue Module SVG/Image, ImageAssets, ClipPath; erweitert wurden Document,
Resources, Style, TransformBounds, Raster, Compositing und der Laborbesucher.
Bilder verwenden explizite dekodierte Quellen bzw. unabhängige SVG-Dokumente.
Clips wirken auf die gemeinsame Gruppen-Ausgabe und berücksichtigen relative
Bounding-Boxes sowie Root-viewBox-Koordinaten. Bei der Prüfung korrigiert:
automatische Bildmaße in Gruppen-/Transform-Bounds und doppelte viewBox-
Umrechnung bei relativen Root-Clips. Eigene numerische Regressionen ergänzt.

Sechs visuelle Quellen und identisches PNG/Pixelmaterial generiert. Die lokale
CPU-Vorschau wurde angesehen. Native Browsersteuerung durch file://-URL-Policy
blockiert; kein Umweg versucht. Studio-Vergleich durch Nutzer offen.

Projektaudit: 307 Luau, 6 JS, 40 HTML, 244 lokale Referenzen, 7 Projekte,
126 Fontzuordnungen. HTML-Suite bestanden. Generator --check bestanden.
Rojo-Builds default/svg-lab/htmlpage bestanden; laufender Server auf
127.0.0.1:34872 liefert S21_S22 und neue Module. SVG-Normaltest und optimierter Endlauf bestanden
(build/svg-images-clips.log / build/svg-images-clips-o2.log). Lebenszyklus-/Abbruch-
prüfungen gelten auch für das neue Paket. Details/Grenzen in SVG-S21-S22.md;
keine pauschale vollständige S21/S22-Konformität behauptet.

---

# Korrektur: S19-Mustervorlagen bleiben browserkonform rot

Der Nutzervergleich widerlegt die ursprüngliche Erwartung „grüne rechte
Vorlage“. Ursache: Pattern.bind instanziierte fremde Vorlagenkinder mit dem
Stil der referenzierenden Definition. Jetzt bestimmt die tatsächliche
Inhaltsvorlage deren geerbte Stile; eigene Ersatzkinder erben weiterhin ihren
eigenen Elternstil. Kachelgeometrie und Transform kommen weiterhin aus dem
zusammengeführten Referenzsatz. Gezielte Browser-Kompatibilitätsentscheidung,
keine pauschale Änderung am SVG2-Shadow-Modell für use oder Verläufe.

Regressionen prüfen Referenzketten, eigene Ersatzkinder und das unveränderte
S19-nested-SVG bei drei Größen: rechts RGB 239/68/68 und Alpha 153.
SVG-Suiten normal/-O2, Generator-Synchronität, Projektaudit und zwei betroffene
Rojo-Builds bestanden. Keine native Browser-/Studio-Prüfung durch den Agenten
behauptet; erneute Nutzer-Sichtabnahme offen.

# Prüfung: SVG S19/S20 Muster und Marker

Musterauflösung und Markerpositionen sind getrennte Datenmodule. Resources
verwendet die vorhandene CSS-/Dokument- und Geometrieaufbereitung auch für
instanziierte Inhalte. Keine interaktiven GUI-Klassen und keine EditableImages
pro Kachel/Marker ergänzt. Kachelpuffer leben im Cache eines einzelnen
Rasterlaufs; Wiederholung und bilineare Abtastung berücksichtigen Alpha.

Kontrolliert: gemeinsame Phase, Einheitenwechsel, viewBox/Transformation,
Template-Vererbung, verschachtelte Muster/use/Verläufe, externe Definitionen,
zyklische Inhalte und Referenzen, Nullgrößen, Kontextfarben ohne versehentliche
Vererbung der Konturdeckkraft, Referenzpunkte, Startumkehr und paint-order.
Marker nutzen Originalvertices und analytische Tangenten. Nullsegmentläufe
werden linear statt quadratisch durchsucht. Das Kompositionsbudget wird
über verschachtelte Marker/Kacheln geteilt; Markerpositionen und Ressourcen-
Aufbauten besitzen zusätzliche Limits. Kontextpaint ohne Kontext malt nichts.

Lokale Luau-Rastervorschau kontrolliert. Alle sechs Tafeln bei 240/480/960 px
gerastert; gezielte RGBA-/Koordinatenproben, Abbruch und 20 Controllerzyklen
bestanden. SVG-/HTML-Suiten normal und -O2 bestanden. Generatoren S17/S18 und
S19/S20 synchron. Audit: 300 Luau, 6 JS, 37 HTML, 241 lokale Referenzen,
7 Rojo-Projekte, 126 Fonts. Drei Builds bestanden. Rojo-API liefert S19_S20,
Pattern, Marker, MarkerPositions, Resources und die neuen Quellen.

S17/S18 visuell bestätigt; S19/S20 noch ohne Studio-Sichtabnahme. Erwartet
sechs Tafeln, zwölf Bilder, keine Diagnosen. Bekannte Grenzen in SVG-S19-S20.md:
extreme Kachelaspekte, Musterüberhang, endliche Rasterfilterung und expliziter
Restpunkt markerUnits=strokeWidth mit non-scaling-stroke. Dieser Sonderfall
ist diagnostiziert und getestet; nicht als vollständig unterstützt ausgewiesen.

# Prüfung: SVG S17/S18 Farbverläufe

Gradient trennt Definition-/CSS-Aufbereitung von Pixelabtastung. Geprüft:
case-sensitive Paint-URLs und Ersatzfarben, Stopp-Kaskade und Template-
Vererbung, Prozentbezüge, Transform-Reihenfolge, getrennte Farbe/Alpha,
sRGB/linearRGB, harte Offsets, Wiederholung, Fokus-/Innenkreise und äußere
Kegelbereiche. Wiederholte radial kollabierte Ringe benutzen einen gewichteten
Mittelwert; die quadratische Lösung verwendet eine stabilere Wurzelberechnung.
Negative Radien, singuläre Matrizen, fremde Namensräume, fehlende/zyklische
Referenzen sowie Stopp-/Arbeitsgrenzen wurden auf isoliertes Verhalten geprüft.

Lokale tatsächliche Luau-Rastervorschau nach CSS-Ersatzfarbenkorrektur und
Kantenglättung kontrolliert. Sechs Quellen bei drei Rastergrößen mit festen
Farb-/Alphaproben. SVG- und HTML-Suiten normal/-O2, Abbruch- und 20 Controller-
Lebenszyklen bestanden. Generatoren S15/S16 und S17/S18 synchron. Projektaudit:
292 Luau, 6 JS, 34 HTML, 238 lokale Referenzen, 7 Projekte, 126 Fonts.
Drei Rojo-Builds bestanden. Rojo-API liefert S17_S18-Konfiguration, Gradient,
neue Quellen und die zwölfte Viewports-Abhängigkeit.

S15/S16 vom Nutzer bestätigt. S17/S18 noch ohne Studio-Sichtabnahme:
sechs Tafeln, zwölf Bilder, keine Diagnosen erwartet. Grenzen und Quellen
in SVG-S17-S18.md, insbesondere endliche Subpixelabtastung, 8-Bit-Ausgabe,
SVG-HTML-Paint-Anbindung, URL-Basisfälle und bestehender CSS-Teilumfang.

# Prüfung: SVG S15/S16 CSS und Referenzen

Gemeinsames Etappenpaket mit sechs visuellen Tafeln. Geprüft: Selektoren und
Spezifität, Important/Inline/Präsentationsattribute, ungültige Deklarationen,
Custom-Property-Zyklen und Fallbacks, berechnete Vererbung, unabhängige use-
Instanzen, href/xlink, externe Auflösung mit Cache und isolierte Referenzfehler.
Quellbäume bleiben unverändert; erneutes Prepare übernimmt Definitionsänderungen.
Browsertafeln isolieren ihre Stylesheets in separaten SVG-Dokumenten. Externe
Browserreferenzen werden für file:// visuell gleichwertig lokal eingebettet;
die tatsächliche Resolver-Anbindung wird separat in Luau geprüft.

SVG- und HTML-Suiten normal und -O2 bestanden, einschließlich gezielter RGBA-
Proben bei drei Größen sowie 20 Controller-Lebenszyklen und Abbruchfällen.
Lokale Luau-Rastervorschau kontrolliert; keine Studio-Sichtprüfung behauptet.
Generator-Synchronität und Projektaudit bestanden: 287 Luau, 6 JS, 31 HTML,
235 lokale Referenzen, 7 Rojo-Projekte und 126 passende Font-Einträge.
Rojo liefert die Konfiguration S15_S16, Style, Document und neue Quellen.

S14 vom Nutzer visuell bestätigt. S15/S16-Sichtvergleich bleibt offen: sechs
Tafeln, zwölf Bilder, zwei erwartete Diagnosen für fehlende/zyklische Referenzen.
Unterstützte CSS-Teilmenge, Resolver-Budgets und offene Text-/Gradient-/Filter-
Eigenschaften sowie spätere Live-DOM-/HTML-Paint-Anbindung: SVG-S15-S16.md.

# Prüfung: SVG S14 Zeichenreihenfolge und Deckkraft

Rendering trennt vererbte Sichtbarkeit/PaintOrder/Hinweise von nicht vererbter
Opacity/Display/Overflow. Der zusätzliche RenderTree bewahrt Gruppen; Compositing
isoliert Opacity und mischt erst die fertige Ausgabe. Raster respektiert
paint-order und shape-rendering. Display:none wird auch bei Referenzhüllen
entfernt. Geprüft: keine versehentliche Opacity-Multiplikation pro Kind, kein
sichtbares Kind unter display:none, sichtbare Ausnahme unter visibility:hidden,
kein Paint außerhalb der vertikalen Clipgrenze bei crispEdges-Pixelmitten.

Konkrete RGBA-Proben, vier echte Quellen bei drei Größen, Pixelvorschau, binäre
und geglättete Kanten, Inlinepriorität, Hüllen, Speicherlimit und Abbruch zwischen
Zeichnen und Komposition bestanden. SVG-/HTML-Suiten normal/-O2, Controller-
Lebenszyklen/Ressourcenmocks, S13/S14-Synchronität, Projektaudit (278 Luau, 6 JS,
28 HTML, 232 Referenzen, 7 Projekte, 126 Fonts) und drei Rojo-Builds bestanden.
Rojo API liefert S14-Konfiguration, Rendering, Compositing und RenderingSources.

S13 visuell bestätigt ohne neuen Clientbericht. S14-Sichtvergleich offen;
erwartet vier Tafeln, acht Bilder, keine Diagnosen. Grenzen in SVG-S14.md,
insbesondere 32 MiB temporäre Live-Puffer, 8-Bit-Komposition, endliche Rootfläche,
spätere Marker/Text/Bilder sowie allgemeine CSS-/HTML-Paint-Anbindung.

# Prüfung: SVG S13 Transformationen

Matrix/Viewport/Raster unterstützen affine Abbildungen und gedrehte geerbte
Viewport-Clips. Transform trennt SVG-Attributsyntax und CSS-Inlinefunktionen;
TransformBounds ergänzt Form-/Gruppenhüllen für Ursprünge. Non-scaling-stroke
bildet seine Kontur im Ausgaberaum. Geprüft und behoben: negative viewBox-Minima
verschieben nicht den Transformationsursprung; font-size-Prozente werden für
Referenzboxen nicht doppelt angewandt; gemischte fill-/stroke-box-Anfragen nutzen
ihre jeweils eigene Hülle und ein gemeinsames Arbeitsbudget.

Affine Punkt-/Reihenfolgetests, vier reale Tafeln bei drei Rastergrößen, äquivalente
Drehpunkt-Paare, gedrehter Ausschnitt, konstante Pixelkonturdicke und lokale
Luau-Pixelvorschau bestanden. SVG-/HTML-Suiten normal/-O2, Controller-/Ressourcen-
mocks, S12/S13-Synchronität, Projektaudit (274 Luau, 6 JS, 27 HTML, 231 Referenzen,
7 Projekte, 126 Fonts) und drei Rojo-Builds bestanden. Rojo API liefert S13,
Matrix, Transform, TransformBounds und TransformSources.

S12 visuell bestätigt, ohne neuen Clientbericht. S13-Sichtvergleich offen;
erwartet acht Bilder und keine Diagnosen. Restfälle und numerische Grenzen in
SVG-S13.md, insbesondere allgemeine CSS-Anbindung und hostabhängige stroke-box
bei non-scaling-stroke. Keine Behauptung eines bereits geprüften Studio-Screenshots.

# Prüfung: SVG S12 Konturen und Strichmuster

Stroke kapselt butt/round/square und miter/round/bevel mit Miterlimit. Geprüft und
behoben: innere Miter dürfen bei kurzen, scharfen Ecken nicht über Enden ragen;
Dashoffset-Modulo darf bei unendlicher pathLength-Kalibrierung nicht NaN erzeugen;
explizite Nullsegmente und Nullstriche an Endpunkten müssen ihre Kappen erhalten.
Gezielte Geometrie-/Pixeltests decken diese Fälle ab.

Vier Vergleichsquellen, drei Rastergrößen und lokale Luau-Pixelvorschau geprüft.
SVG-/HTML-Suiten normal/-O2, Controller-/Ressourcenmocks, S11/S12-Synchronität,
Projektaudit (269 Luau, 6 JS, 26 HTML, 230 Referenzen, 7 Projekte, 126 Fonts) und
alle drei Rojo-Builds bestanden. Laufender Rojo-Server liefert S12-Konfiguration,
Stroke und StrokeSources. S11 visuell bestätigt, ohne neuen Clientbericht.
S12-Sichtvergleich offen; erwartet acht Bilder und keine Diagnosen.

SVG2-miter-clip/arcs bleiben ausdrücklich offen. Weitere Grenzen: numerische
Budgets, angenäherte Rundungen/Kurvenlängen und noch fehlende allgemeine
HTML-Paint-/SVG-CSS-Anbindung. Details: SVG-S12.md.

# Prüfung: SVG S11 Füllregeln und Pfadlänge

Raster-Parität ist auf Füllungen begrenzt; Stroke bleibt eine Vereinigung.
PathMetrics verarbeitet author length und kalibriert die vorgezogenen einfachen
Dashmuster. Dashes erhält geometrische Ecken, verbindet Null-Lücken/Schlussnähte
und begrenzt Arbeit. Ein im Pixelvergleich gefundener Rundungsrest an einer
Strich-/Kurvenpunktgrenze wurde durch enges Einschnappen behoben; identische
kalibrierte Kreise stimmen danach überein.

Loch-/Insel-/Konturprüfungen, Metrik-/Dashsonderfälle, drei Rastergrößen und lokale
Luau-Pixelvorschau bestanden. SVG-/HTML-Suiten normal/-O2, Controller-/Ressourcen-
mocks, S10/S11-Synchronität, Projektaudit (266 Luau, 6 JS, 25 HTML, 229 Referenzen,
7 Projekte) und drei Rojo-Builds bestanden. Rojo liefert S11 und neue Module.
S10 visuell bestätigt, ohne neuen Clientbericht; S11-Sichtvergleich offen.
Grenzen: approximierte Kurvenlängen, Offset 0 und bisherige butt/miter-Konturen;
vollständige S12-Konturstile sowie HTML-Paint/CSS folgen. Details: SVG-S11.md.

# Prüfung: SVG S10 Elliptische Bögen

Path liest A/a einschließlich kompakter Flags und Wiederholung; Arc trennt die
Mittelpunktumrechnung von der skalierungsabhängigen Polylinienausgabe in Curves.
Geprüft: relative Endpunkte, Flagfehler, Richtungen, Drehung, Radiuskorrektur,
Nullradien, identische Endpunkte, Kontrollpunktreset und Budget-/Abbruchverhalten.
Korrigierte Halbögen erhalten den exakten Mittelpunkt statt Rundungsversatz.

Analytischer Vergleich bei vier Skalierungen, Pixelreferenzen bei drei Größen,
lokale Luau-Rastervorschau, SVG-/HTML-Suiten normal/-O2 und Ressourcenmocks bestanden.
S09/S10-Synchronität, Projektaudit (262 Luau, 6 JS, 24 HTML, 228 Referenzen,
7 Projekte) sowie drei Rojo-Builds bestanden. Server liefert S10-Konfiguration
und Module. S09 vom Nutzer bestätigt; S10-Sichtvergleich offen. Extreme numerische
Verhältnisse bleiben durch explizite Budgets begrenzt. Details: SVG-S10.md.

# Prüfung: SVG S09 Bézierkurven

Path bewahrt Kontrollpunkte für C/S/Q/T; Spiegelung und Resets sind unabhängig
von der Rasterunterteilung geprüft. Curves teilt zur Ausgabegröße passend per
de Casteljau, mit Distanz zur endlichen Sehne auch bei Schleifen/Umkehrungen.
Parserpräfixe bleiben bei Fehlern erhalten; Unterteilungs-/Punktebudgets führen
zu expliziten Fehlern und Checkpoints ermöglichen Abbruch. Keine Mutation der
geparsten Konturen. Mittellinientoleranz ist von Stroke-/AA-Abweichung getrennt.

Analytischer Vergleich an 1001 Stellen bei vier Skalierungen, Pixelvergleich der
expliziten/kurzen Kurven bei drei Rastergrößen, lokale Luau-Rastervorschau sowie
SVG-/HTML-Suiten normal/-O2 bestanden. Controller-/Ressourcenmocks auch für S09.
S08/S09-Synchronität, Projektaudit (259 Luau, 6 JS, 23 HTML, 227 Referenzen,
7 Projekte) und drei Rojo-Builds bestanden. Rojo liefert S09 und neue Module.
S08 vom Nutzer bestätigt; S09-Sichtvergleich offen. Grenzen/Bedienung: SVG-S09.md.

# Prüfung: SVG S08 Gerade Pfade

Path trennt Syntax und Punktkonturen von Geometry/Raster. Geprüft wurden absolute,
relative und implizite Befehle, vollständige Zahlenpaare, Anfangs-/Schlusspunkte,
Fehlerpräfixe und Größenbudgets. Raster verarbeitet Teilkonturen als eine Füll-/
Konturoperation; keine künstlichen Verbindungslinien oder doppelte Deckkraft.
Drei Hausvarianten pixelweise bei 240/480/960 verglichen, weitere Prüfstellen für
Enden und Teilpfade. Tatsächliche Luau-Rastervorschau kontrolliert.

SVG-/HTML-Suiten normal/-O2, S06/S07/S08-Quellensynchronität, Projektaudit
(256 Luau, 6 JS, 22 HTML, 226 Referenzen, 7 Projekte) und drei Rojo-Builds bestanden.
Controller-/Ressourcenmocks laufen auch für S08. Rojo liefert S08 und neue Module.
S07 vom Nutzer bestätigt; S08-Clientvergleich offen. Kurven, vollständige Konturen,
CSS-d und HTML-Paint-Anbindung folgen in späteren Etappen. Details: SVG-S08.md.

# Prüfung: SVG S07 Füllung und Kontur

Paint verwendet den gemeinsamen CSS-Farbparser und ergänzt vererbte
Präsentationswerte für Farbe, Füllung, Kontur, deren Alpha und Breite. currentColor
bleibt bis zum jeweiligen Element symbolisch; Alpha wird erst beim Paint mit
Flächendeckung kombiniert. RGB an transparenten Rändern bleibt unverfälscht.
Keine Änderung an HTML-Farbparser oder Fontkalibrierung; S06-RGB bleibt deckend.

Drei Laufzeit-SVG-Tafeln, Pixelprüfungen in drei Größen, lokale Luau-Rastervorschau,
SVG-/HTML-Suiten normal/-O2 und Controller-/Ressourcenmocks bestanden. Synchronität,
Projektaudit (253 Luau, 6 JS, 21 HTML, 225 Referenzen, 7 Rojo-Projekte) sowie drei
Rojo-Builds bestanden. Laufender Server liefert S07-Konfiguration und Module.
S06 vom Nutzer bestätigt; S07-Clientvergleich offen. Vollständige CSS-Kaskade,
Gruppen-opacity, Paint-Server und HTML-Paint sind spätere Etappen: SVG-S07.md.

# Prüfung: SVG S06 Grundformen

Geometry und Raster trennen Konturerzeugung und Pixelmalen. Geprüft wurden
Radiusübernahme/-begrenzung, leere Formen, Kurventoleranz, Punktebudgets,
Stroke-Verbindungen, implizite Füllabschlüsse und tatsächliche Fixture-Pixel.
Die lokale Luau-Rastervorschau zeigt die erwarteten drei Tafeln. Bestehende
S04/S05-Proberaster bleiben unverändert. Grenzen: solid/butt/miter als vorläufige
Konturzeichnung, RGB-Attribute im Labor; allgemeines Paint/CSS und HTML-Anbindung
folgen. Keine behauptete vollständige SVG-Paint-Unterstützung.

SVG- und HTML-Suiten normal/-O2, drei Quellensynchronitätsprüfungen, Projektaudit
(250 Luau, 6 JS, 20 HTML, 224 lokale Referenzen, 7 Projekte) und drei Rojo-Builds
bestanden. Ressourcen-/Abbruchtests laufen mit Mocks auch für S06. Rojo liefert
S06-Konfiguration und neue Module. S05 vom Nutzer bestätigt; S06-Clientvergleich
bleibt offen. Bedienung, Grenzen und visuelle Checkliste: SVG-S06.md.

# Prüfung: SVG S05 Längen

Ein eigener Engine-Längenresolver verarbeitet vollständige Zahlen-/Dimensionstoken,
CSS-Festmaße, Font-/Viewport-Kontexte und SVG-Prozentachsen einschließlich Radius-
Normaldiagonale. Negative Koordinaten bleiben gültig, ungültige Größen benutzen
explizite Defaults und Diagnosen. Keine Änderung der bestehenden Fontkalibrierung.
Metrik-/Viewport-Kontexte werden nicht durch einen falschen inneren SVG-Bezug ersetzt.

Drei unveränderte SVG-Fixtures, Rastervorschau aus tatsächlichen Luau-Pixeln geprüft.
Gleich lange Balken, Prozentkreise, Null-/Fehlermaße und gültige Nachbarn numerisch
bei drei Größen getestet. S04-Regressionsweg erhalten. SVG-/HTML-Suiten normal/-O2,
Synchronität, Projektaudit (246 Luau/223 Referenzen) und drei Rojo-Builds bestanden.
S04 ist vom Nutzer bestätigt; S05-Clientabnahme offen. Details: SVG-S05.md.

# Prüfung: SVG S04 Viewports

Engine-Viewport-Kern getrennt vom Laborraster: alle neun Ausrichtungen,
meet/slice/none, negative Ursprünge, verschachtelte Skalierung/Translation und
Elternclips. Gemeinsamer viewBox-Parser mit S03-Sizing. Zahlen-/Syntaxfehler,
Nullmaße und Überlauf behandelt. Allgemeine SVG-Geometrie/CSS bleiben später.

Vier unveränderte SVG-Laufzeitquellen; lokale Rastervorschau geprüft. Testmarken
mit exakter Rechteckdeckung und 8×8 Ellipsenkanten, Alpha-Referenzvergleich 8/255.
S01–S04-Controllerprüfungen mit Ressourcen-/Scheduling-Mocks, Abbruch und 20
Lebenszyklen bestanden. SVG-/HTML-Suiten normal/-O2, Fixture-Synchronität,
Projektaudit (243 Luau/222 Referenzen) und default/svg-lab/htmlpage Builds bestanden.
Echter Studio-/Browservergleich und S04-Clientstatistik bleiben offen: SVG-S04.md.

S03-Nachtrag (13.09.2026): Nutzer bestätigt den visuellen Vergleich. Clientbericht
mit neun Boxen, ohne Diagnosen, bei 480 px; Details in SVG-S03.md. Frühere
Angaben zum offenen S03-Vergleich unten sind damit überholt.

# Prüfung: SVG S03 HTML-Einbettung

SVG wird als einzelne ersetzte Inline-/Blockbox angeordnet; Kinder bleiben im DOM.
SVG/Sizing liefert intrinsische Maße, ImageLayout/WordLayout/BlockImage übernehmen
vorhandene Box- und Reflowregeln. Keine ImageLoad-Anfragen für Inline-SVG und keine
Alt-Platzhalter. SVG-Flächen zeigen CSS-Hintergründe; allgemeines Zeichnen folgt.
HTML-Fremdinhalte sind ein dokumentierter Teilumfang, kein vollständiger Browser-
HTML-Algorithmus. Der strikte S02-XML-Parser bleibt getrennt und unverändert.

Review: CSS überschreibt Größenattribute; Prozenthöhen mit bestimmtem Elternmaß,
viewBox-Verhältnis, Nullgrößen, Maximalbreiten und Inline-Ausrichtung geprüft.
Die tatsächliche achtteilige HTML-Tafel erzeugt neun SVG-Boxen und beim Resize
keine neuen GUIs. Laborcontroller mit PageSession-Mocks: 20 Neuaufbauten, nur eine
lebende Seite, deduplizierte Statusmeldungen und Abbruch bei wartendem Neuaufbau.

HTML- und SVG-Suiten normal/-O2, drei Fixture-Synchronitätsprüfungen, Projektaudit
(238 Luau-Dateien/221 Referenzen) und default/svg-lab/htmlpage Rojo-Builds bestanden.
Visueller Studio-/Browservergleich von S03 bleibt offen. S02 ist durch Nutzer und
Clientbericht vom 13.09.2026 bestätigt; siehe SVG-S02.md. S03-Anleitung: SVG-S03.md.

# Prüfung: SVG S02 Dokumentstruktur

S01 wurde inzwischen vom Nutzer visuell bestätigt. S02 ergänzt einen eigenen
UTF-8-XML-Scanner und SVG-Dokumentparser mit Namensräumen, unveränderter
Groß-/Kleinschreibung, ID-Index und begrenzten Diagnosen. Fehlerhafte Dokumente
liefern keinen Teilbaum. DTDs bleiben ausdrücklich ausgeschlossen.

Review: Namespace-Suche ist iterativ, damit Tiefe 128 nicht am Luau-Metatable-
Limit scheitert. Fataldiagnosen bleiben auch bei vollem Diagnosebudget sichtbar.
Der Testadapter liest echte SVG-Quellen zur Laufzeit; er ist noch kein allgemeiner
SVG-Renderer. Definitionen und Metadaten bleiben im Baum, aber unsichtbar.

SVG- und HTML-Suiten normal/-O2, Synchronitätsprüfung, Projektprüfung mit 233
Luau-Dateien/219 lokalen Referenzen und drei Rojo-Builds bestanden. Exportierte
Luau-Raster visuell geprüft: drei Rechtecke, leere Fehlertafel, grüner Nachbar.
Der laufende Rojo-Server liefert die neuen Module und SVGStage=S02 aus.
Der visuelle Browser/Studio-Abgleich für S02 bleibt offen; Anleitung: SVG-S02.md.

# Historische Prüfung: SVG S01 Plattformlabor

Eigenständiges S01-Labor mit denselben SVG-Quelldateien für Browser und offline
kompilierte Roblox-Probes. Pixelbuffer für RGB, Halbtransparenz und Diagonale;
OFL-Glyphenpixel für normalen, gedrehten und kreisförmig ausgeschnittenen Text.
Noch kein Engine-SVG-Parser. Native TextLabel-Probe bleibt unkalibriert.

Review: getrennte Ressourcenbesitzer, transactional Upload, Cleanup auch bei
Zuweisungsfehler/Abbruch, superseded Resize-Jobs, abschließender Bericht erst
nach Ende aller Jobs. Passive GUIs; nur natives Scrollen. Exakte Rechteckdeckung
und begrenzte Kantensamples sparen unnötige Rasterarbeit. Vorschau aus tatsächlich
exportierten Luau-Pixeln geprüft; kein Studio-Screenshot.

Fixture-Synchronität, SVG- und HTML-Suiten normal/-O2, Projektprüfung mit 228 Luau-
Dateien/217 lokalen Referenzen und drei Rojo-Builds bestanden. StudioDemoConfig
steht auf SVGLab. Echte Pixel-Rückleseprüfung, visueller Abgleich und Live-Zähler
im Roblox-Client noch offen; Protokoll/Bedienung in SVG-S01.md. S01 daher nicht
visuell abgenommen und S02 noch nicht gestartet.

# Prüfung: Drop-shadow für Bilder

drop-shadow() ergänzt: zwei signed px-Versätze, optionale Standardabweichung und
Farbe/currentcolor. Alpha-Silhouette des aktuellen Kettenergebnisses wird getönt,
versetzt, weichgezeichnet und hinter den Vordergrund komponiert. Drei Float-Buffer
werden innerhalb der Kette wiederverwendet; Ausgabe verwendet den bestehenden
größenabhängigen Cache, Abbruch, Original-Fallback und Cleanup.

Review: HasRaster erfasst auch Schatten ohne Blur. Currentcolor wird nach der
Cascade aufgelöst und einschließlich Alpha im Cache-Schlüssel berücksichtigt.
Schattenüberstand wird in Opacity-Gruppen erhalten, Layoutmaße bleiben unverändert.
Tests/ImageDropShadow prüft Pixeltransparenz, Versatz, Alpha-Komposition,
Reihenfolge, weiche Kanten, getrennte Farbvarianten und einmalige Speicherfreigabe.

Gesamtsuite normal/-O2, Projektprüfung mit 221 Luau-Dateien/210 lokalen Referenzen
und beide Rojo-Builds bestanden. Demo34 synchron, 21.383 Bytes. Visueller Vergleich
und tatsächlicher EditableImage-Zugriff in Studio bleiben manuell zu prüfen.

# Prüfung: Blur für Bilder

blur(0–100px) ergänzt, auch innerhalb von Farbfilterketten. Rasterisierung erfolgt
in CSS-Anzeigegröße mit transparentem Überstand und premultipliziertem Float-Alpha;
Gauß-Näherung durch drei lineare Boxpässe, Subpixelkernel für kleine Radien.
object-fit/position sowie innere Rundung werden vor dem Filter berücksichtigt.

Eigenes passives BlurGui; native Bildanzeige bleibt Fallback. Größenabhängiger Cache
meldet Änderungen über ImageBox.arrange statt Polling, verwirft überholte Ergebnisse,
entfernt ungenutzte Varianten und gibt Speicher bei Seitenende frei. ImageLoad kann
ein fertiges Blur-Bild nicht mit dem Original überdecken. Opacity-Gruppen enthalten
den Filterüberstand, ohne die Layoutbox zu vergrößern.

Tests/ImageBlur prüft Symmetrie, Alpha-/Farbsaumfreiheit, Subpixelwerte, Reihenfolge,
Anzeigegröße/Fitting, Wiederverwendung/Eviction, Abbruch und API-Fallback.
Gesamtsuite normal/-O2, Prüfung von 220 Luau-Dateien/208 lokalen Referenzen und
beide Rojo-Builds bestanden. Demo34 synchron, 21.090 Bytes. Visueller Studio-Abgleich
steht aus; Auflösungs-/Budget- und Genauigkeitsgrenzen stehen in IMAGE-FILTERS.md.

# Prüfung: Bildfilter

Acht CSS-Farb-/Alphafilter für img-Pixel mit geordneten Ketten, unveränderlichen
Cache-Schlüsseln, einer Quellenlesung pro Asset und geteilten Ausgabe-EditableImages.
Keine Neuberechnung beim Reflow. Speicher-/Anzahlgrenzen, kooperative Abbrüche und
Cleanup ergänzt. Original bleibt bei fehlendem Zugriff/Budget erhalten.

Beim Gegenlesen abgesichert: Zwischenwerte jeder Filterstufe begrenzen, Alpha
erhalten, CSS-Cascade berücksichtigen, bei Zuweisungsfehlern bereits ersetzte
Bilder zurücksetzen, fertige Filter vor späteren Original-Preload-Fehlern schützen.
Keine Filterwirkung auf Rahmen, Hintergründe, Alt-Texte oder Container zugesichert.

Tests/ImageFilters und Images sowie Gesamtsuite normal/-O2 bestanden. Projektprüfung:
217 Luau-Dateien, 206 lokale Referenzen. Beide Rojo-Builds erfolgreich. Demo34 in
Browser und Studio synchron (20.877 Bytes). Tests verwenden API-/GUI-Mocks;
Assetberechtigungen, Clientbudget und visuelle Übereinstimmung in Studio bleiben
zu prüfen. Umfang und weitere Grenzen: IMAGE-FILTERS.md.

# Nachprüfung: Tabellen-Clipping und unabhängige Breitenmessung

Zwei Fehler mit reproduzierenden Regressionen gefunden und behoben:

- Positionierte Nachfahren teilweise durch Spalten-Collapse abgeschnittener Zellen
  vergrößerten weiterhin die Scrollfläche und Opacity-Textur. TableContentClipped
  begrenzt nun auch PositionedLayout und GroupOpacity; Zeilen-Collapse mit sichtbarem
  Überlauf bleibt erhalten. Teil-/Voll-Layout stimmen überein.
- Intrinsische Breitenmessung verwendete gespeicherte HeightBasis aus dem letzten
  Layout. Bei Prozenthöhe plus aspect-ratio änderte sich dadurch die Tabellenbreite
  ohne Inhaltsänderung (Regression: 10 auf 200). naturalWidth reicht nun einen
  eigenen Höhenbezug durch die Messung; explizite Elternhöhen bleiben wirksam,
  ungeklärte Prozenthöhen bleiben auto. Text-/Bildproben übernehmen diesen Bezug.

Regressionen in TableAdvanced prüfen wiederholtes Layout, Resize, bestimmte
Elternhöhen und geclippte positionierte Inhalte mit opacity.
Gesamtsuite normal und mit -O2 bestanden. Projektprüfung: 213 Luau-Dateien und
196 lokale Referenzen; beide Rojo-Builds erfolgreich. Keine neue visuelle
Studio-Prüfung; die Geometrie-/GUI-Tests verwenden Mocks.

# Prüfung: Tabellenhöhen, collapse, CSS-Rollen, rowspan und RTL

Nachträglicher Screenshot-Abgleich von Demo33: Der Browser zeigt die umgebrochene
„3“ unterhalb des durch eine entfernte Zeile verkleinerten Zellrahmens. Das zuvor
pauschale Clipping aller partiellen Spans wurde auf Spalten-Collapse und explizites
overflow:hidden begrenzt. Tests prüfen sichtbaren Überlauf samt Scrollgrenzen und
unveränderter Tabellenhöhe in beiden Rahmenmodellen.

TableHeights verteilt Zusatzhöhe und Prozentvorgaben unter Erhalt der Inhaltsminima.
TableTracks trennt logische Messung und sichtbare Zeilen/Spalten. Gemeinsame Rahmen
verwenden das projizierte Raster; partielle Spans behalten ihre Inhaltsbreite und
clippen unter RTL an der rechten Seite. Implizite rowspan-Zeilen brauchen keine
DOM-/GUI-Knoten. Raster- und Rahmenmodell haben explizite Größenlimits.

Beim Gegenlesen abgesichert: bestimmte Elternhöhe im DirtyLayout-Cache,
keine Scroll-/Opacity-Überstände vollständig entfernter Zellen, kein Fokus auf
deren Controls und keine blockierenden Hit-Flächen generischer CSS-Zeilen.
CSS-Rollen brauchen eine explizite Hierarchie; komplexe Prozentkonflikte werden
angenähert. Vollständiger Bidi-Textsatz bleibt offen. Details: TABLES.md.

Gesamtsuite normal und mit -O2 bestanden, einschließlich TableAdvanced und der
synchronen Demo33. Projektprüfung erfolgreich: 213 Luau-Dateien, 196 lokale
Referenzen. Beide Rojo-Builds erfolgreich. Test-HTML 19.834 Bytes.
Die Tests verwenden Geometrie-/GUI-Mocks; visueller Studio-Abgleich steht aus.

# Prüfung: Caption, Tabellenhintergründe und empty-cells

TableCaptions trennt Tabellenfläche und Beschriftung; Rahmen, feste Rasterhöhe,
Scrollbereich, Hit-Zuordnung und Caption-Opacity bleiben getrennt. Automatische
Spaltenmessung berücksichtigt die Caption-Mindestbreite ohne die Verteilung der
Spalten zu verfälschen. Positionierte Nachfahren berücksichtigen den zusätzlichen
Versatz der Tabellenfläche.

Zeilen-/Gruppenfarben werden zusammen mit Spaltenfarben pro Ursprungszelle
gezeichnet, einschließlich rowspan. empty-cells verbirgt den eigenen Zellhintergrund
und Zellrahmen nur bei separate. Der nachträgliche Browservergleich zeigte:
Zeilen-/Spaltenhintergründe müssen sichtbar bleiben; entsprechende Regression
und Hintergrundhöhe null bei ausgeblendeten Zeilen ergänzt. Bei der Prüfung ergänzt: volle Größenwirkung
leerer Zellen in gemischten Zeilen, keine unsichtbaren Rahmenüberstände unter
komplett ausgeblendeten Zeilen, eigene Rundung am ausblendbaren Rahmenhost.

Tests/TableExtras und aktualisierte Demo31 bestehen normal und mit -O2.
Projektprüfung: 210 Luau-Dateien; beide Rojo-Projekte erfolgreich gebaut.
Test-HTML synchron, 19.618 Bytes. Geometrie-/GUI-Mocks; visueller Studio-Abgleich
steht noch aus. Verbleibende Grenzen sind in TABLES.md dokumentiert.

# Prüfung: Cursor-System

Alle gelieferten Cursor-IDs übernommen, CSS-cursor (inklusive URL-Fallback),
automatische Zeiger und Textarea-/Fenster-Resize-Capture ergänzt. CursorLease
verwaltet native MouseIcon/MouseIconEnabled über mehrere Seiten und Griffe;
Cleanup/Fokusverlust/Touch stellt den vorherigen Zustand wieder her, ohne spätere
Cursoränderungen fremder Scripts beim Freigeben zu überschreiben.

Beim Prüfen gefunden und korrigiert: InlineWords durfte benachbarte Texte mit
unterschiedlichen Cursorn oder Linkkontext nicht zusammenfassen. HitStyles
bewahrt Cursorwerte innerhalb von Labels, während deren Eventziel gleich bleibt.
Cursor startet auch ohne Controls und aktualisiert bei Scrollen/Layout/Verbergen
ohne neue Frame-Schleife. Fenstergriffe sind passive Frames mit HTMLInputBlocker.

Tests/Cursors und Demo32 prüfen alle Namen, CSS/URL/Vererbung, Text-/Linkgrenzen,
Labels, Auto-Auswahl, none, Touch/Fokus, stationäre Aktualisierung, Resize-Capture,
Besitzerpriorität und Cleanup. Gesamtsuite normal/-O2, Projektprüfung und beide
Rojo-Builds bestanden:206 Luau-Dateien. Native TextBox kann den eigenen Textcursor
erzwingen; Zugriff/Aussehen der gelieferten Assets erst in Studio prüfen.
Weitere Grenzen: CURSORS.md.

# Prüfung: fixed-Layout und Spaltendefinitionen

table-layout:auto/fixed sowie col/colgroup ergänzt. TableColumns trennt
Spaltendefinitionen vom Flusslayout; fixed verwendet col-/Gruppenbreiten und
die erste Zeile, spätere Zellinhalte ändern die Spalten nicht. Pixel-/Prozent-
und Restbreiten, span, colgroup-End-Tag-Auslassung und Display-Filter geprüft.
Bei verschachtelten fixed-Tabellen werden Prozentvorgaben schon während der
intrinsischen Messung gegen die eigene Tabellenbreite aufgelöst.

TableColumnPaint zeichnet Gruppen-/Spaltenfarben unter den Ursprungszellen,
auch bei Zellverbindungen, mit wiederverwendeten passiven Frames. TableBorders
bezieht Spalten/Spaltengruppen in die vorhandene Konfliktauflösung ein.
Keine neuen Eingabe-GUIs oder Timer. Demo31 synchron:100px/20%/Restplatz.

Tests: Priorität col/erste Zeile, colspan, Breitenüberlauf, Umbruch/Resize,
width:auto-Fallback, verschachtelte Tabellen, Farben/Rahmen, ungültige span-
Werte/4096-Limit, inerte Scripts, GUI-Erhaltung und Teil-/Voll-Layout.
Gesamtsuite normal/-O2, Projektprüfung und beide Rojo-Builds bestanden:
201 Luau-Dateien. Visuelle Prüfung in Studio bleibt manuell; Umfang in TABLES.md.

# Prüfung und Erweiterung: gemeinsame Tabellenrahmen

Vor der Erweiterung TableLayout/TableGrid, BlockLayout, Rahmen-Rendering und
Hit-Test-/Teil-Layout-Anbindung geprüft. Konkreten Fehler korrigiert: prozentuales
Zellpadding wurde bei Messung und Platzierung gegen unterschiedliche Breiten
aufgelöst. SpacingWidth hält beide Pässe konsistent; Regression mit 200/100/200px.
Die bestehende Suite bestand anschließend bereits vor der Erweiterung.

border-collapse:collapse ergänzt, mit getrennten Modulen für Kantenauflösung
und Zeichnung. Tabellen-, Gruppen-, Zeilen- und Zellrahmen konkurrieren nach
Breite/Stil/Quelle; hidden unterdrückt Nachbarkanten. Halbbreiten im Layout,
keine Linien durch Spans, kein doppelter Alphaauftrag an Kreuzungen. Flächenloser
Border-Host verhindert das Abfangen von Eingaben; passive Rahmen-Pools bleiben
beim Resize erhalten. Demo31 in beiden Dateien synchron auf collapse umgestellt.

Gesamtsuite normal/-O2, Projektprüfung und beide Rojo-Builds bestanden:
198 Luau-Dateien. Neue Prüfungen für Maße, Priorität/hidden, verbundene Zellen,
verschachtelte Modelle, Pixelabdeckung, GUI-Erhaltung und Teil-/Voll-Layout.
Tests verwenden GUI-/Textmessungs-Mocks; Studio-Abgleich weiterhin manuell.
Grenzen (u.a. col/colgroup, leere Raster und Musterübergänge): TABLES.md.

# Prüfung Zellverbindungen

TableGrid ergänzt: freie Spaltenpositionen, rowspan-Belegung und Gruppengrenzen.
TableLayout verteilt Größenanforderungen verbundener Zellen über die betroffenen
Spalten/Zeilen und schließt die inneren Zellabstände ein. Vertikale Ausrichtung und
Grundlinien erhalten die ursprüngliche GUI-/DOM-Anordnung. HitTest überspringt
strukturelle Zeilen-/Gruppenrahmen, damit später liegende transparente Zeilen keine
Controls in einer rowspan-Zelle abfangen. Demo31 verwendet je einen colspan/rowspan.

Geprüft: beide Achsen kombiniert, belegte Slots, rowspan=0, unabhängige Gruppen,
Attributnormalisierung/Limits, breite/hohe Zellen, Umbruch, Grundlinie, fehlende
Einzelzellen, Teil-/Voll-Layout, GUI-Erhaltung und Klickdurchlässigkeit. Gesamtsuite
normal/-O2, Projektprüfung und beide Rojo-Builds bestanden: 195 Luau-Dateien.
Überlange rowspans werden auf vorhandene Gruppenzeilen begrenzt und diagnostiziert;
keine impliziten Zusatzzeilen. Visueller Studio-Abgleich offen; Tests nutzen Mocks.

# Prüfung Tabellen-Grundlage

TableLayout ergänzt: gemeinsame Min-/Max-Content-Spalten, Zeilenhöhen und vertikale
Zellausrichtung. BlockLayout behält Inhalt, Rahmen und Boxmodell. HTML-Katalog,
border-spacing/separate, optionale Tabellen-End-Tags und Beispiel 31 ergänzt.
DirtyLayout registriert die Tabellenabhängigkeit und verschiebt unveränderte
Tabellen ohne erneute Zellenberechnung, sofern keine Positionierungsabhängigkeit
besteht. Bestehende Demo-Performance-Regression unverändert bestanden.

Geprüft: automatische/feste/Prozentbreiten und min-width, Zellpadding/Rahmen,
Spacing, Umbruch bei Resize, baseline/middle/bottom, Gruppenreihenfolge,
Verschachtelung, leere Tabellen/Zellen, Diagnose nicht unterstützter Werte,
Editor-GUI-Erhaltung und Übereinstimmung von Teil-/Voll-Layout. Gesamtsuite normal
und mit -O2, Projektprüfung und beide Rojo-Builds bestanden: 193 Luau-Dateien.
Browser-/Studio-Demo-HTML ist identisch. GUI-/Messungs-Mocks ersetzen keinen
visuellen Studio-Abgleich. Grenzen und nächste Ausbaustufen: TABLES.md.

# Prüfung Details/Summary

Aufklappbereiche mit aktivem erstem Summary, renderinternem Ersatztitel, Pfeil und
`open` ergänzt. Anonymous-Body und AllChildren erhalten die DOM-Struktur und
vorhandene GUI-/Editorinstanzen. Der aktive Layoutbaum schließt versteckte Inhalte
aus; DirtyLayout kennt trotzdem sämtliche Eigentümer. Input läuft über denselben
Controller wie Formulare. Geschlossene Nachfahren werden bei Fokus/Tab, Radio-
Navigation, nativer Eingabe und Trefferauflösung ausgeschlossen. Formulardaten und
Reset bleiben unabhängig vom Aufklappzustand. Beispiel 30 synchron ergänzt.

Geprüft: Maus/Touch, Enter/Leertaste, Klickabbruch, Tab/Shift+Tab, initiales open,
Fallback und weitere Summarys, Verschachtelung, DOM-/Editor-/Werterhaltung,
Formular-Reset, Teil-/Voll-Layout und Listener-Cleanup. Bestehende Gesamtsuite
normal und mit -O2, Projektprüfung und beide Rojo-Builds bestanden: 191 Luau-Dateien.
GUI-/Messungs-Mocks prüfen Logik und Geometrie; visueller Studio-Abgleich offen.
Bekannte Grenzen (name, Events, dynamisches CSS, Marker): DETAILS.md.

# Prüfung Optionsgruppen

optgroup-Überschriften und eingerückte Optionen ergänzt. Optionsindizes bleiben von
den sichtbaren Gruppenzeilen getrennt, damit Auswahl, Formulardaten und Reset ihre
bisherige Bedeutung behalten. Reveal berücksichtigt die tatsächliche Zeilenposition.
Gruppenüberschriften werden fett gemessen; Inline- und Block-Select berücksichtigen
Überschriften und Einrückung bei der intrinsischen Breite. Passive GUIs, keine neuen
Layout-Anforderungen bei Auswahl. Bestehendes Test-Dropdown in beiden HTML-Quellen
synchron um Verfügbar/Geplant (disabled) gruppiert.

Geprüft: option/optgroup-End-Tag-Auslassung, leere Gruppen, disabled, Header-Klick,
Pfeile/Suche, Scrollposition, voller Auswahlhintergrund, Messcache, Daten, Reset,
required mit leerem Gruppenoptionswert und Popup-Cleanup. Normal/-O2-Gesamtsuite,
Audit und beide Rojo-Builds bestanden: 189 Luau-Dateien, 196 lokale Referenzen.
GUI-/Textmessungs-Mocks prüfen Logik und Geometrie; visueller Studio-Abgleich offen.

# Prüfung Validierungs-Sprechblase

Englische Meldungen mit orangefarbenem Warnsymbol, weißer Fläche, grauem Rahmen,
kleinem Pfeil und optionalem Schatten ergänzt. Passive Overlay-GUIs, keine neuen
interaktiven Buttons oder Layout-Anforderungen. `invalid` enthält Reason/Message;
PreventDefault unterdrückt den Standard-Fokus und die Blase, nicht die Validierung.

Geprüft: fehlendes @, Mindestlänge ohne Passwortausgabe, begrenzte Textauszüge,
Fokus/Submit, Event-Abbruch, mehrfache Öffnung, Bearbeiten, Escape, Reset, Scrollen,
Ankeränderung, Platzierung am rechten/unteren Rand und Listener-Cleanup.
Normal/-O2-Gesamtsuite, Audit und beide Rojo-Builds bestanden: 185 Luau-, 5 JS-,
12 HTML-Dateien, 196 Referenzen, 6 Rojo-Projekte, 126 passende Fonteinträge.
GUI-/Textmessungs-Mocks prüfen Logik und Geometrie; visueller Studio-Abgleich offen.

# Prüfung E-Mail, URL und Mindestlänge

TextValue/URLValue ergänzt und in State, FormModel sowie View eingebunden.
Bestehende Feldmaße und Fonts bleiben erhalten. Gemeinsames HTML testet E-Mail,
Webadresse und minlength=5 am vorhandenen Textarea; Zahl der Controls unverändert.

Geprüft: E-Mail-Syntax und multiple, absolute URLs/Host/Port/IPv4/IPv6, Sanitizing,
UTF-16-Länge, User-Edit-Herkunft, gleiche programmatische Werte, Reset, optionale
Leerwerte, required, disabled/readonly, Validierungs-Bypass, invalid/Fokus und
identische TextBox-Maße. URL-/IDNA-Teilumfang ist in FORMS.md dokumentiert.

Gesamtsuite normal/-O2, Audit und beide Rojo-Builds bestanden: 182 Luau-, 5 JS-,
12 HTML-Dateien, 196 Referenzen, 6 Rojo-Projekte und 126 passende Fonteinträge.
Prüfung über CLI-/GUI-Mocks; manuelle Eingabe in Studio steht noch aus.

# Prüfung Fieldset und Legend

Formulargruppen mit 2px-Groove-Rahmen, relativen Standardabständen und ausgesparter
oberer Rahmenkante ergänzt. Die erste gerenderte Legende bleibt außerhalb des
Block-/Flex-Inhaltsflusses; mehrzeilige Legenden reservieren ihre Höhe. Border-Pools
werden beim Resize wiederverwendet. Keine neuen interaktiven Roblox-Buttons.

Kontrolliert: disabled-Vorfahren, erste DOM-Legende (auch unsichtbar), verschachtelte
Ausnahmen, eigenes disabled, Formulardaten, Autor-Padding, feste Höhen, Flexlayout,
schmale Breiten, weitere/ausgeblendete/absolute Legenden, Objektwiederverwendung und
Übereinstimmung zwischen Teil- und Voll-Layout. Gemeinsame HTML-Dateien sind identisch;
vorhandene Toggles gruppiert, Zahl der Formularfelder bleibt gleich.

Gesamtsuite normal/-O2, Audit und beide Rojo-Builds bestanden: 179 Luau-, 5 JS-,
12 HTML-Dateien, 196 Referenzen, 6 Rojo-Projekte und 126 passende Fonteinträge.
Tests verwenden CLI-/GUI-Mocks; visueller Studio-Abgleich steht noch aus.
Grenzen bei besonderen CSS-Kombinationen sind in FORMS.md dokumentiert.

# Prüfung Textarea-Ziehgriff

12×12 EditableImage-Maske aus Nutzerreferenz (7+3 Pixel, RGB102), Seiten-Cache,
transparenter Hintergrund und Pixel-Frame-Fallback ergänzt. Ziehen über zentralen
InputController; Text/Fokus/Fonts unverändert. Original-Control-Stil bewahrt für
Block-/Flex-Pfade, vorhandene Größenlimits weiter aktiv. CSS resize steuert Achsen.

Getestet: exakte Bildpixel/Farbe, Cache/Fallback/Cleanup, Rahmenabstand, Maus/Touch,
fremder Touch, Bewegung über die Feldgrenze hinaus, No-op-Klick, Größenlimits,
Originalstil bei Block-Controls, unveränderter Text und keine input/change-Events.
PageLifecycle prüft Item-Resize bei gleicher Viewportgröße mit 1/60s-Bündelung.
Gemeinsames Textarea-Beispiel erhält den Griff, kein zusätzliches Testfeld.

Gesamtsuite normal/-O2, Audit und beide Rojo-Builds bestanden: 177 Luau-, 5 JS-,
12 HTML-Dateien, 196 Referenzen, 6 Rojo-Projekte und 126 passende Fonteinträge.
Native Studio-Sichtprüfung noch offen; Mauszeigerwechsel absichtlich später.

# Prüfung Progress-/Meter-Integration

Gemeinsame GaugeValue-/GaugeView-Module ergänzt. Geprüft: Standard-/Fehlerwerte,
Clamping, gleiche/umgekehrte Grenzen, low/high/optimum-Grenzfälle, Grün/Gelb/Rot,
extreme endliche Zahlen, passive Fokus-/Tab-/Formbehandlung und Wertänderung ohne
Layout oder neue GUI-Objekte. Ohne progress-value läuft ein nativer Tween; Wechsel
zum bestimmten Wert, Hidden und Cleanup stoppen und zerstören ihn. Resize sowie
vor der Bindung erstellte Paint-Snapshots erhalten den Tween über PaintOwner.

Gesamtsuite normal und -O2, Projektaudit sowie beide Rojo-Builds bestanden.
Audit: 173 Luau-, 5 JS-, 12 HTML-Dateien, 196 Referenzen, 6 Rojo-Projekte,
126 passende Fonteinträge. Demo29 enthält je einen Fortschritts- und Messwertbalken
im identischen Browser-/Studio-HTML (15 Controls). Outputänderung weiterhin
5 Layout-Aufrufe, nun 83 Cache-Treffer. GUI-/Input-/Tween-Mocks prüfen Verhalten;
native Farben, Maße und Animation in Studio noch visuell abzugleichen.

# Prüfung Number-Integration

Zahlenfeld mit TextBox, passiven Frame-Pfeilen, zentralem Maus-/Touch-Hit-Test und
Pfeiltasten ergänzt. NumericValue ist der gemeinsame Parser für Number und Range.
Geprüft: leere/ungültige Werte, Exponenten, EditText/BadInput, min/max/step,
Schrittbasis, gerichtetes Einrasten, Submit-Validierung, readonly/disabled,
Click-PreventDefault, Daten/Reset, Cleanup und einmaliges Change auch bei Fokuswechsel
innerhalb eines Input-Callbacks. Der Texteditor behält die bestehende Schrift-/
Höhenkorrektur; nur der Pfeilbereich verkürzt seine verfügbare Breite.

Gesamtsuite normal und -O2, Projektaudit und beide Rojo-Builds bestanden.
Audit: 170 Luau-, 5 JS-, 12 HTML-Dateien, 196 Referenzen, 6 Rojo-Projekte,
126 passende Fonteinträge. Demo29: identisches Browser-/Studio-HTML mit einem
Number-Feld 1–10; Outputänderung 5 Layout-Aufrufe/81 Cache-Treffer. Prüfungen nutzen
GUI-/Input-Mocks; native Optik in Studio noch abzugleichen. Kein Auto-Repeat beim
Halten der Pfeile; weitere Grenzen und API in FORMS.md.

# Prüfung Range-Integration

Horizontaler Range-Regler mit begrenzten Schrittwerten, passiven Frames und
Maus-/Touch-Capture ergänzt. Geprüft: fehlende/ungültige Werte, Schrittbasis,
Dezimalschritte, Rundung, umgekehrte Grenzen, extreme Zahlen, Griff ohne Sprung,
Ziehen außerhalb, fremder Touch, einmaliges Change, Tastatur, disabled,
Formulardaten, Reset, Fokusverlust und synchrones Unmount im Input-Listener.
Änderungen lösen nur Paint aus; Range benötigt keine Textmessung. Die vorhandenen
Schriftkorrekturen und Input-/Select-Maße wurden beibehalten.

Gesamtsuite normal und mit -O2 bestanden; Projektaudit: 166 Luau-, 5 JS-, 12
HTML-Dateien, 196 lokale Referenzen, 6 Rojo-Projekte, 126 passende Fonteinträge.
Beide Rojo-Builds bestanden. Identische Browser-/Studio-Demo mit einem Regler;
Outputänderung weiterhin 5 Layout-Aufrufe, nun 80 Cache-Treffer. Validierung nutzt
GUI-/Eingabe-Mocks, keine native Studio-Sichtprüfung. Browseroptik und Touch in
nativen Scrollcontainern bleiben praktisch zu vergleichen. Grenzen: FORMS.md.

# Prüfung Select-/Option-Integration

Einfaches Select mit eigener Popup-Darstellung und zentralem Hit-Test integriert.
Startauswahl, deaktivierte Optionen/Gruppen, Text-/Werttrennung, doppelte und
unbekannte Werte, required, Submit-Daten und Reset geprüft. Natürliche Breite folgt
der längsten Option; Auswahl wechselt nur die Darstellung und erhält den Messcache.
Parser unterstützt option-End-Tag-Auslassung innerhalb select/optgroup.

Tests verwenden echte State-/Model-/Render-/Controller-Logik mit GUI- und
Eingabesignal-Mocks. Geprüft: Maus, Touch-Tap und Drag-Abbruch, Pfeile/Enter/Escape,
Popup oberhalb bei Platzmangel, Außenklick, Ankerbewegung, Reset, deaktiviertes Feld,
Fokusverlust und Cleanup. Ein Popup verwendet Frames/TextLabels und natives
Scrolling, ohne neue interaktive Buttons oder Frame-Schleifen. Neue Modulgrenzen:
Controls/SelectOptions und Input/SelectPopup. Grenzen in FORMS.md dokumentiert.

Gemeinsames Browser-/Studio-HTML um genau ein Dropdown mit drei Optionen in
Beispiel 29 ergänzt; Gleichheit und Inhalt automatisch geprüft. Gesamtsuite normal
und -O2 bestanden. Projektaudit: 162 Luau-, 5 JS-, 12 HTML-Dateien, 196 lokale
Referenzen, 6 Rojo-Projekte, 126 passende Fonteinträge. Beide Rojo-Builds bestanden.
Demo-Outputänderung weiterhin 5 Layout-Aufrufe, jetzt 79 Cache-Treffer. Native
Studio-Sichtprüfung des Dropdowns noch offen; keine Pixelgleichheit behauptet.

# Erneute Projektprüfung – Formulare und CSS-Selektoren

Manuell geprüft: Eingabe-/Ereigniswege, Formularzustand und Darstellung,
HTML-Parser und Stylesheet-Zuordnung, Renderbaum, Dirty-/Block-/Scroll-Layout,
Opacity-/Ellipsis-Caches, Bildladen und EditableImage-Lebenszyklen. Zusätzlich
projekweiter Syntax-/Referenzaudit und vollständige Regressionen ausgeführt.

Zwei reproduzierte Fehler korrigiert:

- Ein Fokuswechsel aus einem change-/blur-Handler konnte durch den noch laufenden
  äußeren Fokuswechsel überschrieben werden. Eine Revisionsnummer verwirft diesen
  überholten Übergang; auch Destroy während des Handlers beendet ihn zuverlässig.
- Gemischte Kind-/Nachfahrenselektoren konnten am nächstgelegenen passenden
  Klassennamen scheitern, obwohl ein weiter entfernter Vorfahr passte. Das Matching
  prüft nun komplette direkte Kindketten, bevor es einen Nachfahrenkandidaten
  akzeptiert. Es benötigt weder rekursives Backtracking noch einen zusätzlichen Cache.

Neue Tests schlugen vor den jeweiligen Fixes fehl. Regressionen für Umleitung aus
change und blur, Destroy sowie positive/negative verschachtelte CSS-Ketten ergänzt.
Die bestätigten Checkbox-/Radiofarben und Schriftkalibrierungen bleiben erhalten.
Mehrzeilige Output-Layouts bleiben die in FORMS.md dokumentierte Einschränkung.

Gesamtsuite normal und -O2 bestanden. Statischer Audit: 157 Luau-Dateien,
5 JS-Dateien, 12 HTML-Dateien, 196 lokale Referenzen, 6 Rojo-Projekte und 126 passende
Fonteinträge. Beide Rojo-Builds erfolgreich. Aktuelle CLI-Demo weiterhin 5 Layout-
Aufrufe / 78 Cache-Treffer bei der geprüften Ausgabeänderung. Kein neuer Timer,
keine Änderung am gemeinsamen HTML-Test. Native Studio-Sichtprüfung nicht ausgeführt.

# Prüfung gleich großer Output-Änderungen

Output-Werte werden im bestehenden Worker mit den zuletzt tatsächlich angeordneten
Maßen verglichen. Gleiche intrinsische Breite, Höhe und Schriftmetriken überspringen
das Layout vollständig. Die Textdarstellung aktualisiert sich über den bestehenden
Paint-Pfad. Unterschiedliche Maße und Messfehler gehen an das bisherige Dirty-Layout.
Messungen verändern den Vergleichsstand erst nach einer echten Anordnung.

Regressionen prüfen gleiche Maße bei verändertem Text, unterschiedlich breite
Zeichen, leere Ausgabe, Änderungen während der Messung, gemischte Updates,
Resize-Vorrang, Zerstörung und ausstehendes Scroll-Paint. Status und Layoutstatistik
bleiben bei reinem Paint unverändert. Doppelte verzögerte Statusmeldungen der Demo
werden anhand der Statistikinstanz unterdrückt.

Gesamtsuite normal und -O2, statischer Projektaudit (157 Luau-Dateien, 5 JS-Dateien,
12 HTML-Dateien, 196 lokale Referenzen, 6 Rojo-Projekte, 126 passende Font-Einträge)
und beide Rojo-Builds bestanden. Browser-HTML und Fontkalibrierungen unverändert.
Native Studio-Prüfung dieser Optimierung und reale Laufzeitmessung bleiben offen.

# Prüfung des Dirty-Layouts – Stufe 2

Wiederverwendung geschlossener Sonderbereiche ergänzt. Scroll-Reset erfolgt bei
partiellen Updates erst beim tatsächlichen Layout; unberührte Bereiche behalten
CanvasPosition/Gutter und überspringen Settle/Commit. Neue Gutter invalidieren
Vorfahren. Positionierungs-Caches prüfen den vollständigen eingehenden Bezugsrahmen;
Opacity-Bounds werden nur bei unveränderter Geometrie wiederverwendet. Spätere
Geometrieänderungen löschen übergeordnete Wiederverwendungsmarkierungen.

Regressionen für unveränderte Sonderzweige ohne Text-Layout, native Scrollpositionen,
CanvasGroup-Positionen, verschobene Container und verschachtelte Sonderbereiche
ergänzt. Dirty-/Voll-Layout-Geometrie stimmt auch für die aktuelle Demo überein.
CLI-Demo-Ausgabeänderung: 5 Layout-Aufrufe / 78 Cache-Treffer statt zuvor 100 / 144.
Native Studio-Bestätigung und echte Laufzeitmessung bleiben offen.

Gesamtsuite normal und -O2, statischer Projektaudit (156 Luau-Dateien) und beide
Rojo-Builds bestanden. Keine neue Frame-Schleife, Browser-HTML unverändert.

# Prüfung des Dirty-Layouts – Stufe 1

Erste partielle Invalidierung für output-Werte ergänzt. Cache-Schlüssel enthalten
Generation, verfügbare Breite und Position; Bereiche mit abhängigen Sonderpässen
bleiben auf dem bestehenden Layoutpfad. Vorfahren-/Item-Zuordnung und ausstehende
Änderungsmengen geprüft; eine neue Menge je Worker-Durchlauf verhindert verlorene
Änderungen bei Mess-Yields. Vollständige Anforderungen haben Vorrang, Fehler
verwerfen die Cachegeneration. Kein neuer Timer oder Frame-Listener.

Regressionen vergleichen partielle und vollständige Geometrie einschließlich der
aktuellen Demo, wachsender/schrumpfender Ausgabe, Folgeelementen, Flex, Scroll,
Positionierung, Opacity, Margins und Prozentgrößen. Unveränderte frühere Textläufe
werden nachweislich nicht nochmals angeordnet. Umfang/Grenzen: [DIRTY-LAYOUT.md](DIRTY-LAYOUT.md).

Gesamtsuite normal und -O2 bestanden. Projektaudit: 156 Luau-, 5 JS-, 12 HTML-Dateien,
196 lokale Referenzen, 6 Rojo-Projekte, 126 passende Font-Einträge. Beide Rojo-Builds
erfolgreich. Native Studio-Sichtprüfung und reale Zeitmessung noch offen.

# Prüfung der Formularintegration (12.09.2026)

Native TextBox-Eingabe, Control-Layout, zentraler Hit-Test, Fokus und lokale
Formularaktionen ergänzt. Renderer verwendet bestehende Inline-/Block-/Flexwege
und bewahrt Control-Instanzen bei Resize. Einfache Zustandsänderungen führen
keinen Seiten-Reflow aus; Output-Maßänderungen nutzen den vorhandenen Worker.

Bei der Prüfung korrigiert: letzte checked-Radiovorgabe auch nach Reset,
deaktivierte Checkbox-/Radiofarben, unsichtbare Treffer und Radio-Tastaturziele,
Vorfahren-Clipping/Scrollgutter, abgebrochene Touch-Gesten und Listener-Cleanup
auch bei fehlgeschlagenem Controller-Start. Die Hit-Zuordnung verwendet schwache
GUI-Schlüssel, damit ausgetauschte Wrap-Fragmente freigegeben werden können.

Gesamte Testsuite normal und -O2 bestanden; Projektaudit: 154 Luau-Dateien,
5 JS-Dateien, 12 HTML-Dateien, 196 lokale Referenzen, 6 Rojo-Projekte und
126 übereinstimmende Fonteinträge. Beide Rojo-Builds erfolgreich. Gemeinsames
HTML mit Beispiel 29 durch Demo-Regression auf Gleichheit geprüft.

Native Studio-Eingabe und visueller Vergleich noch offen. Passwortmaske benötigt
weiteren Abgleich für Cursor/Selektion und lange Werte. Browser-Reload wurde
durch die URL-Policy abgelehnt; kein visueller Browser-Test behauptet.
API und weitere Grenzen: [FORMS.md](FORMS.md).

# Prüfung relativer CSS-Längen (12.09.2026)

em/rem werden vor dem Layout berechnet. Geprüft: endgültige Schriftgröße unabhängig
von Deklarationsreihenfolge, Root-Sonderfall, geerbte Pixelwerte, Kurzformen,
!important, Seitentrennung, ungültige Tokens und berechnete Größenlimits.
Eine abgelehnte font-Kurzform darf keine falsche Root-Größe hinterlassen.
Bestehende Negativtests behalten ihre ungültigen Fälle mit ex statt em/rem.

Alle Tests regulär und mit -O2 bestanden; Projektaudit: 146 Luau, 5 JS, 12 HTML,
196 lokale Referenzen, 6 Rojo-Projekte, 126 übereinstimmende Font-Einträge.
Beide Rojo-Builds erfolgreich. Beispiel 28 im Browser und Studio identisch;
nativer visueller Abgleich offen. Details: [RELATIVE-LENGTHS.md](RELATIVE-LENGTHS.md).

---

# Erneute Projektpruefung (12.09.2026)

Parser/CSS, Layout und Paint, Bild-/Font-Ladevorgaenge, Cache-Lebensdauer,
Resize-Scheduler und Cleanup erneut geprueft. Drei konkrete Befunde behoben:

- BlockImage behaelt seinen abgeleiteten Stil zwischen Layouts. Dadurch werden
  unveraenderte Rahmenecken nicht allein wegen einer neuen Stiltabelle rasterisiert.
  Flex-Groessenvorgaben werden vor jeder Messung auf die CSS-Werte zurueckgesetzt.
- Ersetzte Glyphenfragmente werden aus der Opacity-Gruppe entfernt, bevor ihre
  GUI zerstoert wird. Wiederholter Umbruch sammelt keine toten Mitglieder mehr.
- Ellipsis speichert eigene Elementgeometrie. Intrinsische Breitenmessungen koennen
  die beim Scrollen verwendeten Zeilenpositionen nicht mehr ueberschreiben;
  Prefix-Caches und Fragmentpools bleiben am Originalwort.

Blockbilder und Opacity-Gruppen vermeiden zusaetzlich identische GUI-Schreibzugriffe;
Alt-Text verwendet die bereits aufgeloeste Schriftgroesse. Regressionen in
`tests/MediumAdditions.luau` reproduzierten die drei Befunde vor den Korrekturen.
Testsuite regulaer und mit -O2, statischer Projektaudit sowie beide Demo-Rojo-Builds
bestanden. Native Studio-Sichtpruefung und Performance-Messung nicht durchgefuehrt.
Schriftkalibrierungen, sichtbare Beispiele, Debug-Ausgaben und 1/60-s-Resize unveraendert.

---

# Prüfung mittlerer Erweiterungen (12.09.2026)

CSS-Kurzformen, Ausgangswerte statt Tagdefaults, Farb-Alpha-Vererbung,
Prozentabstände ohne kumulierte Resize-Offsets, Margin-Verrechnung, Wort-/Marker-
Grenzen, Bildfluss und wiederverwendete Transparenzgruppen überprüft.
Neue Regressionen prüfen alle Katalogeinträge mit inherit/initial/unset sowie
klein–groß–klein-Reflow. Marker werden nicht nochmals als Text dekoriert.
Bestehende Tests behalten ihre Funktion; neue gültige Werte ersetzen alte Negativfälle.
Sichtbare Vergleichsbeispiele 21–27. Native Studio-Sichtprüfung offen.
Grenzen und Module: [MEDIUM-ADDITIONS.md](MEDIUM-ADDITIONS.md).

---

# Prüfung diagonaler Rahmenecken (12.09.2026)

Gemeinsame Farbwahl für Frames/Eckpixel, diagonale Flächenzuordnung und Alpha ohne
Überdeckung geprüft. Gerade Kanten sparen Eckflächen aus; Musterphase folgt derselben
Geometrie. Resize-Reuse, Schreibfehler, fehlende API, Budget und Cleanup abgesichert.
Block-/Bild-/Outline-Integration in tests/BorderCorners; alle vorherigen Funktionen
behalten ihre Layoutmaße. Native Sichtprüfung offen; [Grenzen](BORDER-CORNERS.md).

---

# Prüfung kleiner Ergänzungen (12.09.2026)

Alias-Cascade/Vererbung, HSL-Syntax/Umrechnung/Alpha in allen Farbpfaden,
Rahmenstil-Whitelist getrennt von Outline, Rahmenmaße/Pool-Reuse beim Resize,
HTML-Defaults und optionale dt/dd-Endtags geprüft. Bestehende inset/hr- und
Fontkalibrierungen erhalten. Neue Fälle in tests/SimpleAdditions.luau;
Grenzen und offener Sichtabgleich: [SMALL-ADDITIONS.md](SMALL-ADDITIONS.md).

---

# Prüfung Text-overflow (12.09.2026)

Nicht vererbte Cascade, Trennung von Originaltext/Layout und sichtbarer Darstellung,
Präfixmessungen und Abbruch, Teilwortpools, Grapheme, Grundlinien und gemischte
Dekorationen/Schatten geprüft. Resize-Rückkehr stellt Originale wieder her.
Tests decken auch übergroße erste Zeichen/Bilder und leere Zeilen ab.
Grenzen und ausstehender Sichtabgleich: [TEXT-OVERFLOW.md](TEXT-OVERFLOW.md).

---

# Prüfung Outline (12.09.2026)

Cascade und Kurzform-Reset, currentcolor/Alpha, nicht vererbte Defaults,
positive/negative Offsets und ungültige Werte geprüft. Darstellung verwendet
BorderBox erneut. Kein Eingriff in Boxgrößen oder Scrollausdehnung; eigenes
Inhalts-Clipping erhält die Außenkontur. Resize verwendet Musterobjekte und
Textmaße wieder. Block- und Bildpfad durch tests/Outline.luau abgedeckt.
Native Sichtprüfung offen; Grenzen in [OUTLINE.md](OUTLINE.md).

---

# Prüfung einzelner Rahmenkanten (12.09.2026)

CSS-Seitenauflösung/Cascade, gemeinsame Block-/Bilddarstellung und alle bisherigen
BorderSize-Verwendungen kontrolliert. Größenberechnungen, Positionsbezugsboxen,
Scrollviewport und Schattenmasken rechnen getrennt mit jeder Kante. Seitendaten
werden nur bei Bedarf angelegt. Einheitliche Rahmen und hr durch bestehende
Tests abgesichert; Tests/BorderSides ergänzt die neuen Kombinationen.
Details und visuelle Grenzen: [BORDER-SIDES.md](BORDER-SIDES.md).

---

# Prüfung der Scrollcontainer (12.09.2026)

Achsen-Cascade, hr-Defaults, Renderbaum/GUI-Hierarchie, Block-/Flexgrößen,
positionierte Bezugsboxen, innere/äußere Überläufe und Größenwiederverwendung
kontrolliert. Auto-Höhe darf für eine horizontale Leiste wachsen, ohne sofort
eine falsche vertikale Leiste auszulösen; beide Achsen verwenden die Maße
desselben Durchlaufs. Null-/Maximalhöhen bleiben auch mit Leisten begrenzt.
Regressionsprüfung in Tests/Scrolling; Details in [SCROLLING.md](SCROLLING.md).
Native Maus-/Touchbedienung und Sichtvergleich stehen aus.

---

# Prüfung der Listenformate und Dekorationskurzform (12.09.2026)

CSS-Parsing/Cascade, Renderbaum-Zähler, Markerformatierung und Dekorationsweg
geprüft. Vorzeichen bei decimal-leading-zero anhand der aktuellen CSS-Pad-Regel
berücksichtigt; alphabetisch/römisch außerhalb des Bereichs decimal. Ungültige
Kurzformen wirken nicht teilweise, der Linien-Longhand bleibt getrennt.
Bestehende Messungen/Labels und EditableImage-Muster werden weiterverwendet.
Tests/Lists, TextDecoration, DecorationStyles und HTMLPageDemo erweitert.
Details: [Listen und Dekoration](LIST-DECORATION-EXTENSIONS.md#prüfung).

---

# Prüfung der einfachen HTML-/CSS-Erweiterungen (12.09.2026)

Umfang und Befunde stehen in [SIMPLE-FEATURES.md](SIMPLE-FEATURES.md#codepr%C3%BCfung).
Parser/Cascade, Darstellungseinbindung und Katalogbeschreibungen geprüft.
Fehlerhafte doppelte Vorzeichen an Positionierungskanten werden nun abgewiesen;
auto in inset-Kurzformen bleibt pro Seite erhalten. Rahmenkeywords beeinflussen
keine anderen Längenparser. Farbnamen als separate Datentabelle, Farbwerte einmal
initialisiert. Native Fontkalibrierung und individuelle Textmaß-Caches unverändert.

---

# Projektprüfung nach Auto-Margins und flex-flow (12.09.2026)

Manuell durchgesehen: Parser/Tokenizer und DOM, CSS-Syntax/Cascade und
Stilauflösung, Renderbaum, Block-/Flexlayout, Wortlayout/Umbruch, Textmessung,
Dekorationen/Textschatten, Bildgeometrie/-laden/-maße, EditableImage-Verwaltung,
Font-Preload, Seitenlebensdauer und temporäre Resizehilfe. Ergänzend prüft der
Projektaudit alle Luau-Dateien, JS-/HTML-Syntax, Projektzuordnungen und lokale
Ressourcenverweise. Keine vollständige native Roblox-Typ- oder Sichtprüfung.

- Scrollausdehnung korrigiert: Ein verschobener Block muss seinen horizontalen
  Versatz auch in der zurückgegebenen Inhaltsausdehnung berücksichtigen.
  Regression: 100px breite, in 300px zentrierte Box mit 400px breitem Kind
  reicht bis x=500, nicht nur 400. Clipping bleibt vorher wirksam.
- hr-Sonderlogik entfernt: Bisherige CenterBlock/EndBlock-Flags konnten
  `margin-right:auto` fälschlich rechts ausrichten. Die beiden horizontalen
  Standardränder verwenden jetzt die gemeinsame MarginAuto-Repräsentation,
  solange keine gültige Autorenangabe die jeweilige Seite ersetzt. Das erhält
  die bestehende Zentrierung und funktioniert auch als Flexitem. Neuer Test
  zeigte vor der Korrektur x=198 statt 99; nachher bestehen beide hr-Fälle.
  Grundlage: [HTML-Standard, hr](https://html.spec.whatwg.org/multipage/rendering.html#the-hr-element-2).
- Reflow geprüft: Aufgelöste automatische Abstände werden nicht in Style.Margin
  oder LayoutMargin zurückgeschrieben. Bestehende Labels und individuelle
  Textmaße werden beim Resize wiederverwendet; kein neuer Messcache zwischen
  Elementen. Kein gemessener Ladezeit-/FPS-Gewinn behauptet.
- Asynchroner Seitenabbau, Bildabfrage-/Preload-Abbruch und Freigabe temporärer
  Bilder durchgesehen und mit vorhandenen Regressionen geprüft.

Validierung erfolgreich: gesamte HTML-Testserie (47 Ergebniszeilen, darunter
34 Parserchecks) regulär und mit Luau -O2; Projektaudit mit 120 Luau-Dateien,
5 JS-Dateien, 12 HTML-Dateien, 193 lokalen Verweisen, 6 Rojo-Projekten und 126
übereinstimmenden Fonteinträgen; Rojo-Builds default und htmlpage.
Browser-HTML und Script-HTML sind synchron (4.445 UTF-8-Bytes). Siebtes kompaktes
Beispiel für auto-Margins/flex-flow ergänzt. Native Sichtprüfung dieses Beispiels
steht aus. Dokumentierte Teilunterstützung für direkte img-Flexitems, komplexe
intrinsische Größen und den Scrollursprung bei Reverse bleibt bestehen.

---

# Codeprüfung nach object-position und object-fit

Durchgesehen: ObjectPosition, InlineStyle/Properties, ImageFit, ImageLayout, ImageBox/GuiFactory, ImageDimensions/ImageLoad, HTMLPage und die betroffenen Regressionstests. Der Projektaudit prüft zusätzlich alle Quellmodule und Ressourcenverweise. Dies ist eine gezielte Prüfung der neu geschriebenen Bildfunktionen und ihrer Einbindung.

- Parserfehler reproduziert und korrigiert: Dreiteilige Werte wie `left 10px center` wurden fälschlich akzeptiert. Die allgemeine CSS-Positionssyntax erlaubt ein, zwei oder vier Komponenten; die Dreierform gehört zu background-position. Ungültige Angaben behalten jetzt die vorherige gültige Position bei. Viererform vereinfacht: zwei Kanten-/Abstandspaare, keine Sonderlogik für center. Der neue Test schlug vor dem Fix fehl. Quelle: [CSS Values 4, Position](https://www.w3.org/TR/css-values-4/#position).
- Unnötige Instanzen vermieden: fill + reine Prozentposition hat keinen Versatz, da Bild und Inhaltsfläche gleich groß sind. Diese Kombination bleibt jetzt auf dem nativen ImageLabel-Weg und erzeugt auch bei Rundung keine zusätzliche CanvasGroup. Pixelverschiebungen erhalten weiterhin ihren Clip-Container. Tests prüfen beide Wege einschließlich der richtigen Corner-Zuordnung.
- Gemeinsame Offsetrechnung aus dem Layoutaufruf herausgezogen; keine neue Funktion je Bild/Anordnung. Keine gemessene FPS-/Ladezeitverbesserung behauptet.
- Größenabfrage, Ressourcenfreigabe, späte Ergebnisse nach Seitenabbau, Textfallback, Clipping/Boxmodell und Wiederverwendung durchgesehen. Die Regressionen prüfen insbesondere, dass natural-size-Inhalt nicht den Textfluss vergrößert und Metadata-Fehler kein Fehlersymbol aktivieren.

Validierung: vollständige HTML-Testserie regulär und mit Luau -O2, Projektaudit und die zwei betroffenen Rojo-Builds (StudioWorkspace/HTMLPage). Sichtbarer Demo-HTML-Code unverändert. Der direkte Zugriff auf die lokale Browserseite wurde durch die Browser-URL-Richtlinie blockiert; keine Umgehung, kein automatischer Browser-/Studio-Sichttest behauptet. Bekannte Assetmaß-Ersatzwerte und CanvasGroup-Voraussetzungen bleiben in IMAGES.md dokumentiert.

---

# Projektprüfung nach automatischen Bildmaßen

Durchgesehen: sämtliche Engine-Module für Parser/DOM, CSS, Layout, Fontprofile, Bild-/Text-/Schattenrendering und Seitenlebensdauer, außerdem Schriftlabor, Vergleichslogik und Build-/Synchronisationsskripte. Fontkataloge und Dateiverweise werden zusätzlich maschinell geprüft. Die eigenständigen Regressionstests bleiben bestehen; die sichtbare Demo bleibt kompakt.

- Automatische Bildmaße: Abfragen nur für automatische Achsen, nach Asset gruppiert, sequenziell mit höchstens einem temporären EditableImage pro Seitenabfrage. Das Bild wird nach dem Auslesen sofort freigegeben. Resize liest keine neuen Maße. Fehlende Metadaten beeinflussen den normalen Bild-Ladezustand nicht.
- Abbruch optimiert: Wartende Bildreferenzen werden bei Seitenlöschung sofort freigegeben; auch ein spät zurückgegebenes EditableImage wird zerstört. Tests prüfen Abbruch sowohl vor als auch während der Abfrage.
- Reproduzierter Textfehler behoben: Bei letter-spacing konnte `X<span style="word-spacing:6px">A&nbsp;B</span>` zu einem Eintrag mit dem ersten Stil verschmelzen. Dadurch verlor NBSP den zusätzlichen Abstand. InlineWords erhält im Zeichenmodus nun diese Stilgrenze; die Fragmente bleiben ohne erfundenes Leerzeichen untrennbar. Der neue Regressionstest schlug vor dem Fix an seiner Stilgrenzenprüfung fehl und besteht danach.
- Keine Änderung vorhandener Schriftfaktoren oder akzeptierter Liniengeometrien. Keine neue DOM-Mutationsschnittstelle, keine Hintergrundschleife und kein unbelegter Geschwindigkeitsgewinn.

Validierung: vollständige HTML-Testserie, Luau -O2, statischer Projektaudit, sechs Guide-Fits und sechs Rojo-Builds. Das prüft Logik, Kompilierung und Ressourcenverweise; der Sichtvergleich sowie die tatsächlichen Assetrechte in Roblox bleiben separat zu prüfen. Bestehende dokumentierte Näherungen bei Fontmetriken, Unicode, Textfallback und Browser-Layout bleiben erhalten.

---

# Projektprüfung nach Linienfarbe und Unterlinienabstand

Geprüft wurden Parser/DOM, CSS-Katalog und Cascade, Renderbaum, Block-/Wortlayout, Fontprofile, Dekorationen/skip-ink, Seitenlebensdauer, Font-Preload, Schriftlabor, Vergleichsdemos und Build-/Synchronisationsskripte. Katalogdaten werden zusätzlich auf Übereinstimmung und lokale Referenzen geprüft. Dies ist eine Code- und CLI-Prüfung; keine native Sichtprüfung in Roblox oder im Browser und kein vollständiger Roblox-Typcheck.

## Korrigierte Fehler

- `br` wurde vor der CSS-Auflösung verarbeitet. Deshalb erzeugte auch `display:none` einen Umbruch. Der Renderbaum prüft nun den aufgelösten Hidden-Zustand. Regressionstest enthält Klassenregel mit !important, Inline-Angaben und anschließendes sichtbares br; Text um unsichtbare br bleibt zusammenhängend.
- Bei letter-spacing und einem Stilwechsel innerhalb eines Wortes blieb die gemeinsame Unterlinie im Abstand zwischen Fragmenten unterbrochen. Dekorationssegmente verlängern sich jetzt über diese Lücke, sofern beide Fragmente denselben Linienursprung besitzen. Getrennte u-Elemente verbinden ihre unabhängigen Linien nicht.

Beide Fehler wurden mit zunächst fehlschlagenden Regressionstests reproduziert und danach behoben.

## Gezielte Vereinfachungen und Optimierungen

- TextDecoration überspringt den Aufbau temporärer Segment-/Zuordnungstabellen bei Wörtern ohne eigene oder vorgelagerte Dekoration. Hintergrundverarbeitung bleibt erhalten; vorhandene Linien-Frames werden weiterhin ausgeblendet, wenn nötig.
- WordLayout verwendet reine Fontprofil-Ergebnisse je Stil innerhalb eines einzelnen Durchlaufs wieder. Das spart mehrfaches Berechnen und Anlegen der Guide-/Metriktabellen. Der Cache endet mit dem Durchlauf; individuelle native Wort-/Leerzeichenmaße werden weiterhin getrennt erfasst. Test mit drei gleich formatierten Wörtern: eine statt sechs Profilberechnungen bei unverändert drei Wort- und zwei Leerzeichenmessungen. Resize braucht keine erneuten nativen Messungen; Änderung der Schriftgröße im nächsten Durchlauf schon.

Kein gemessener Gesamtgewinn für Ladezeit/FPS behauptet. Kein Hintergrund-Polling, keine Virtualisierung und keine Änderung der Schriftfaktoren oder der vom Nutzer akzeptierten Linienabmessungen.

## Validierung

Die gesamte HTML-Testserie inklusive Regressionen wird regulär und mit Luau -O2 ausgeführt. Der statische Audit kompiliert alle 83 Luau-Dateien und prüft 5 JS-Dateien, 11 HTML-Dateien, lokale Referenzen, 6 Rojo-Projekte sowie 126 übereinstimmende Fontkatalogeinträge. Zusätzlich werden alle sechs vorhandenen Guide-Fits gegen ihre gespeicherten Messdaten und sämtliche Rojo-Projekte per Build geprüft. Die gemeinsame Demo bleibt unverändert und wird im Test auf exakte HTML-/Luau-Synchronität kontrolliert.

Bekannte Teilumfangsgrenzen bleiben dokumentiert: Fontmetriken/skip-ink sind Näherungen; vollständiges HTML-Fehlerhandling und CSS-Tokenisierung fehlen; pre-wrap behandelt bestimmte abschließende Leerzeichen noch vereinfacht; kein allgemeines DOM-Dirty-System. Neue Linienarten sind noch nicht implementiert.
