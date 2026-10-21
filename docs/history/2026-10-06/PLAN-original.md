# Unser Bauplan

Folgeplanung 04.10.2026: [R00–R20](docs/JAVASCRIPT-ROADMAP.md#folgeplan-r00r20-offene-teile-von-p01p17-abschließen)
ordnen die verbleibenden Lücken von P01–P17. Der Plan beginnt mit einem
versionierten APIregister und frühen Hostprüfungen; danach folgen Sprache,
DOM/Eingaben, CSS/Animationen, Daten/Intl, Ressourcen/Netzwerk, Speicherung,
Parser/Module/Lifecycle, Grafik/Medien und Worker. Jede größere Etappe erhält
Browservergleich, Integration und vollständigen Code-Review. FPS-Benchmarks
bleiben bei Tobias. Diese Anfrage erstellt den Plan, ohne neue Enginefunktionen
zu implementieren; P18 bleibt eine gesonderte Reserve.

Neue Arbeitsregel 02.10.2026: Tobias beauftragt den eigenständigen Ausbau P01 bis
P17. Automatische Funktions-, Differential- und Regressionstests sind wieder
erlaubt. Browsersemantik und visuelle Browser-/Roblox-Parität haben Vorrang.
Nach jedem größeren Paket folgt ein vollständiger Review des JavaScript-Codes
und seiner Rendering-/Layout-/Inputanbindungen; Befunde werden vor dem nächsten
Paket behoben. Zeit ist nachrangig. Das vorhandene Kontingent muss reichen:
Startmessung 6 % Wochenverbrauch / 94 % verbleibend. Kontingent an Paketgrenzen
erneut lesen und Reserve für Integration, Abschlussreview und Vergleichsseite
einplanen. Die kompakte neue Vergleichsseite entsteht am Ende des Ausbaus;
Kombinationen dürfen mehrere Funktionen anschaulich in einem Objekt zeigen.
Diese neue Anweisung ersetzt die ältere Regel ohne eigene Tests unten.

Aktuell 04.10.2026, Vergleich 08: Dynamische Tabellen, Shadow DOM/Custom Elements,
Pointer-Capture/Touch/native Unicode-Edits, erweiterte CSSOM-Regeln und Kaskade,
dynamische Counter/Pseudoelemente sowie additive Layoutanimationen sind integriert.
Die kompakte Seite zeigt sechs kombinierte Karten; frühere Vergleiche bleiben
eingefrorene Regressionen. Native IME-Zwischenstände sind mangels Roblox-API
nicht verfügbar. Umfang und übrige Grenzen: docs/JAVASCRIPT-DOM-CSS-EXTENSIONS.md.
Funktions-/Browserprüfungen sind erlaubt; keine FPS-Benchmarks.

Vorheriger Stand 04.10.2026: Die Dialog-/Popoverpositionierung ist über gemeinsame
CSS-/Top-Layer-Regeln korrigiert. Dynamische Scripts, Intl.ListFormat und Path2D
sind ergänzt. Dedicated Worker besitzen nun einen Roblox-Actor-Host mit eigener
VM/Ereignisschleife, klassischen und Modulquellen, ArrayBuffer-Transfer und
Aufräumen. Vergleich 07 zeigt diese Erweiterungen kompakt. 45 relevante
Regressionstestgruppen bestehen; ergänzende Chromium-Referenzen prüfen 22 Script-,
58 Bibliotheks-, 18 Path2D- und acht Workerabläufe. Nach den Script-/Worker-
Hostkorrekturen bestehen 13 relevante Regressionstestgruppen erneut. Tobias hat
die gezeigten Studio-Fälle von Vergleich 07 bestätigt. Dies ist kein FPS-/
Parallelitätsbenchmark. Offene Unterfamilien von P01–P17 bleiben ausdrücklich in
docs/JAVASCRIPT-IMPLEMENTATION.md und JAVASCRIPT-ROADMAP.md verzeichnet.

Stand 03.10.2026: Die Laufzeit besitzt Grundlagen in allen Paketen P01–P17.
Nach dem Observer-Budgetfix sind Iterator-Helfer, TypedArray-Eigenschaften,
DOM-Traversierung, lebende Abfragen, Raw JSON und Geometrieobjekte ergänzt.
Interne Deskriptoren sind gegen Änderungen an Object.prototype abgesichert.
Range/StaticRange und Selection ergänzen lebende Grenzpunkte,
Inhaltsoperationen und native Light-DOM-Textauswahl. Der folgende CSSOM-Block
verbindet lebende Stylesheets, Regeln, Deklarationen, Media/Supports und
konstruierte übernommene Blätter mit dem vorhandenen Renderer. Tobias hat
Vergleich 04 und 05 bestätigt. Vergleich 06 zeigt die nächsten drei Teilpunkte:
P07-Dialogsteuerung, P07-Popoversteuerung und P09 User Timing/PerformanceObserver.
Frühere Vergleichsseiten bleiben nicht ausgelieferte Regressionen. Profilgrenzen
und Nachweise stehen in docs/JAVASCRIPT-TOP-LAYER.md und
docs/JAVASCRIPT-PERFORMANCE.md sowie den Textfeld-/Animation-/CSSOM-/Range-Dokumenten.
Die neuen Karten brauchen noch den nativen Roblox-Sichtvergleich. Die
Gesamtpakete P07 und P09 bleiben mit ihren übrigen Familien offen.
Die vollständige JavaScript-Roadmap mit Bestandsaufnahme, offenen Standardfamilien,
Browser-APIs und 18 Ausbaupaketen steht in [docs/JAVASCRIPT-ROADMAP.md](docs/JAVASCRIPT-ROADMAP.md).
Die noch offenen Teilfamilien werden eigenständig erweitert und an Paketgrenzen
gemeinsam geprüft. Der aktuelle Supportumfang und die ausgewiesenen Grenzen
stehen in docs/JAVASCRIPT-IMPLEMENTATION.md; ältere Etappen unten beschreiben
ihren damaligen Stand. Automatische Tests sind wieder erlaubt; FPS-Messungen
übernimmt weiterhin Tobias. Code, Vergleichsseite und Supportdokumentation
werden zusammen gepflegt.

S45-Nutzerkorrektur: use-x/y muss userSpaceOnUse-Masken mitverschieben.
Document.UseTranslation + Mask-Mapping korrigiert; Vorlage unverändert,
der gelbe Stern soll wie im Browser angeschnitten sein. Regressionen: vier
Maskeneinheiten-Kombinationen und konkrete S45-Pixel. Erneuter Sichtvergleich offen.

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


SVG-Ausbau: [eigener Gesamtplan mit 45 visuellen Vergleichsetappen](docs/SVG-PLAN.md).
Ziel ist der in Roblox realisierbare Gesamtumfang, mit belegten Grenzen und
einzeln prüfbaren Browser-/Studio-Tests. Status: S01–S30 im dokumentierten Teilumfang zum Fortfahren freigegeben; S31/S32-räumliche Filter und Komposition implementiert, visueller Vergleich offen. Bidi/Shaping, automatischer Textumbruch, Filter-Randfälle und foreignObject bleiben dokumentierter Rest.
Aktuelles Prüfprotokoll: [S31/S32](docs/SVG-S31-S32.md).
Prüfprotokolle: [S14](docs/SVG-S14.md), [S15/S16](docs/SVG-S15-S16.md).
Nutzerpräferenz: ab S15 größere Etappenpakete umsetzen, mit gemeinsamem Sichtvergleich.

## Feste Regeln

- Unter-/Durchstreichungen bewusst einfach schätzen: Unterlinie max(1, round(CSS-font-size / 14)) px unter der Grundlinie (gemeldet: 1 px bis Größe 20, 2 px ab 21, 3 px ab 35; weitere Übergänge geschätzt), Durchstrich etwa bei halber Kleinbuchstabenhöhe. Automatische Dicke max(1, floor(CSS-font-size * 0.049)) für alle Schriften und Gewichte. Näherung passend zu den Nutzerbeobachtungen: ab 41 px → 2 px, ab 62 → 3, ab 82 → 4. Demo verwendet automatische Dicke; Browser-auto kann abweichen. Keine Fontdateien einzeln dafür prüfen oder pro Schrift kalibrieren.

- Kopierbare HTML-Beispiele als kurzes, vollständiges Standard-HTML schreiben: Derselbe Code wird unverändert im Browser und in Roblox verwendet. Aktuelle Demo auf Nutzerwunsch nur mit font-family, ohne Google-Fonts-Links oder eingebettete Fontbinärdaten. Im Browser stehen diese Familien nur bei vorhandener Schrift zur Verfügung; reguläre Font-Links bleiben für andere HTML-Eingaben unterstützt. CSS-Regeln im style-Block auswerten; Roblox verwendet für bekannte font-family-Namen seine registrierten Schriftfamilien. Grenzen des unterstützten HTML/CSS-Teilumfangs ausdrücklich dokumentieren.
- Die Engine ist unabhängig von Tabs, Adressleiste und Browserfenstern.
- Jede Seite hat einen ScrollingFrame. Alle sichtbaren Seitenelemente sind seine Nachfahren.
- Alle GuiObjects: Active=false. Natives Scrollen: ScrollingEnabled=true.
- Eigene Klicks, Hover, Fokus und Trefferprüfung; Roblox übernimmt das Scrollen.
- Individuelle Textmessung ohne zwischen Elementen geteilte Mess-Caches.
- Standardmäßig ein TextLabel pro Wort. Auf Nutzerwunsch bei letter-spacing ungleich null ein Wort-Frame mit einem TextLabel je Graphem (zusammengesetzte Zeichen zusammenhalten). Eigene Wortanordnung und Zeilenumbrüche bleiben auf Wortebene; keine Satz-Labels.
- Unveränderte Elemente behalten ihre Maße. Änderungen lösen gezielte neue Messungen aus.
- Kein Entfernen oder Nicht-Erstellen von Elementen wegen ihrer Entfernung zum sichtbaren Bereich.
- Nur Roblox-Bilder. Kleine Fontabweichungen zu Chrome sind akzeptabel.
- Später begrenztes Pooling mit vollständigem Zurücksetzen und sauberem Seitenabbau.
- Keine Schleife pro Element. Nur bei tatsächlicher Arbeit berechnen.
- Module nach Aufgabe trennen; ab etwa 400–600 Zeilen Verantwortung überprüfen.

## Schritte

1. **Schriftlabor:** Textgrößen und manuelle Grundlinien untersuchen. Jetzt vorbereitet; visuelle Studio-Prüfung offen.
2. **HTML-Grundparser:** Erster Teilumfang umgesetzt und mit Luau geprüft; Grenzen in `docs/HTML-SUPPORT.md`.
3. **DOM:** Elementbaum, Elternbeziehungen, ID-Suche und Textauslesen umgesetzt. Reaktive Änderungen folgen später.
4. **CSS-Grundlagen:** Selektoren, Vorrang, Vererbung, Farben, Größen, Abstände, Rahmen.
5. **Layout:** Zuerst Block-Anordnung, danach Textzeilen und Grundlinien, anschließend Flexbox.
6. **Rendering:** DOM/Layout in verschachtelte Roblox-GUIs übersetzen. Nur geänderte Properties schreiben.
7. **Dirty-System:** Style, Layout, Darstellung und Trefferbereiche getrennt markieren. Abhängigkeiten berücksichtigen.
8. **Scheduler:** Änderungen bündeln und nur bei Bedarf abarbeiten. Kein permanentes Scannen.
9. **Input:** Vollständige Trefferprüfung, Überlagerungen, Hover, Fokus, Dragging und DOM-Events ergänzen.
10. **Controls:** Checkboxen und zuverlässig machbare Texteingabe umsetzen. Natives Scrollen integrieren.
11. **Pooling:** Alte Seite deaktivieren, Arbeiten beenden, Objekte sauber zurücksetzen und begrenzt wiederverwenden.
12. **JavaScript:** Eigener Parser/Interpreter, Variablen, Funktionen und DOM-Zugriff. Ausführungsbudgets einbauen.
13. **Ausbau:** Weitere CSS-/HTML-Funktionen in einer Supportliste ausdrücklich als geplant oder unterstützt markieren.

Dirty-Markierung und Lebenszyklus werden schon beim Aufbau ihrer Schnittstellen vorgesehen,
nicht erst nachträglich an einen großen fertigen Renderer angehängt.

## Erster HTML-Meilenstein

Eine kleine Seite mit Überschrift, Text, Roblox-Bild, Abständen, Rahmen und Checkbox.
Eigenes Klicken und Hover, natives Scrollen, überall Active=false.
Abhaken aktualisiert nur den nötigen Zustand und die Darstellung.
Textänderungen dürfen notwendige Nachbarelemente verschieben, ohne die Seite zurückzusetzen.

## Wer prüft was?

Wir liefern Roblox-Code und verständliche HTML-Testseiten, sobald der Parser existiert.
Du vergleichst diese selbst in Chrome. Performance und Funktion prüfen wir auf Roblox-Seite.
Es gibt kein Versprechen vollständiger Chrome-Kompatibilität; der geprüfte Funktionsumfang wächst schrittweise.
