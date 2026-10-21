# Projekt-Audit und Stresstest — 21.09.2026

## Umfang und Vorgehen

Zuerst Bestandsaufnahme und Korrekturen, anschließend Katalog-Stresstest. Gesichtet wurden Engine, Beispiele, Tests, Generierung und Projektkonfiguration. Der Ausgangsbestand umfasst 674 Quell-/Test-/Beispieldateien: 516 Luau, 34 Python, 12 JavaScript, 95 HTML und 17 CSS. Generierte Font-Glyphentabellen und Website-Module sind Daten, keine sinnvollen Kandidaten für manuelles Kürzen. HTML- und SVG-Suite bestanden vor den Änderungen.

Dies ist eine Liste belegter Befunde und ihrer Bearbeitung. Sie verspricht weder Fehlerfreiheit jeder Codezeile noch vollständige Browserkonformität. Die Detailberichte enthalten Grenzen, Regressionen und Fundstellen:

- [CSS und Layout](AUDIT-LAYOUT-2026-09-21.md)
- [DOM, Eingabe und Lebenszyklus](AUDIT-LIFECYCLE-2026-09-21.md)
- [Rendering und Bildressourcen](AUDIT-RENDERING-2026-09-21.md)
- [Abgleich der Funktionskataloge](AUDIT-COVERAGE-2026-09-21.md)

## Implementierte Korrekturen

| Bereich | Vorher | Nachher |
| --- | --- | --- |
| Selektoren | Wiederholte Geschwisterlisten; quadratischer `~`-Scan | Direkte lineare Scans, keine temporären Familienarrays; Detached-/Mutation-Fälle abgesichert |
| Keyframes | `1%` wurde als 100% interpretiert | Prozentwerte korrekt normiert |
| Animation | Falsche Endwerte bei gebrochenen Iterationen; überschriebener Transition-Zielsnapshot | Korrekte Richtung/Endposition und stabile Zielwerte |
| Layout/Paint | Foreground-Sonderrang überschritt Flex/Grid-Reihenfolge; atomare Inlines fehlten in Positionierung | Kontextabhängige Paint-Reihenfolge und korrekte Inline-Anker/Positionierung |
| Layout-Vorbereitung | Unnötige Margin-Kopien und Ankersuche | Kopien nur bei Kollaps; ankerlose Zweige übersprungen |
| Events | Alle Listener pro Vorfahr gescannt; Disconnect hielt Referenzen | Ziel-/Typ-Index, Referenzfreigabe, stabiler Bubble-Pfad |
| Tastatur | Controls vor Links/Medien; wiederholte Radioscans | Gemeinsame DOM-Reihenfolge und lineare Radiogruppierung |
| Formulare/Dialoge | Quadratische Radio-Initialisierung/Reset/Validierung; Dialogfokus nur auf Controls | Gemeinsame Radiogruppen und korrekter Anfangsfokus auch auf Links/Medien |
| Scroll-Snap | Ein verzögerter Job je Wheel-Ereignis | Ein abbrechbarer Job; Destroy beendet ihn |
| Bildressourcen | Schwache Lookup-Tabellen konnten Cleanup-Besitz verlieren; Cache nach vielen Resizes erschöpft | Explizite Ressourcenverantwortung und begrenzte Wiederverwendung/Eviction |
| Clip-Raster | Unveränderte CSS-Radien pro Subpixel neu aufgelöst | Geometrie einmal pro Rasterauftrag vorbereitet |
| Website-Generator | Python-`repr` erzeugte ungültige Luau-Unicode-Escapes; nichtendliche Zahlen möglich | Eigene Luau-Stringkodierung, finite Zahlen und Validierung vor Dateiausgabe |
| Projektprüfer | JSON-/Importmap-Scriptblöcke als JS kompiliert; Module als klassische Scripts | MIME-Typ berücksichtigt; echte Module separat syntaktisch geprüft |
| Opacity unter kombinierter Last | Nicht angeordnete CSS-Tabellenwörter erzeugten einen `nil`-Absturz beim Ermitteln der Paint-Grenzen | Nur Wörter mit angeordneter Geometrie tragen Paint-Grenzen bei; gezielte Regression und vollständiger Stresstest |

Die Beispielseiten wurden nicht verändert, um Darstellungsfehler zu kaschieren. Browser und Roblox erhalten dieselben HTML-/CSS-Dateien.

## Messbare Effekte

- Clip-Raster, echte Luau-CLI, Ellipse 256×144, Median aus neun Läufen: **101,0 → 38,4 ms**. Längenauflösungen: **1.179.648 → 2**. 30 Fälle mit Kreis/Ellipse/Rundrechteck liefern bytegleiche Pixel gegenüber dem vorherigen Modul. Dies ist ein CPU-Mikrobenchmark, keine Roblox-FPS-Messung.
- Fehlgeschlagener General-Sibling-Match über 2.048 Geschwister: höchstens **3n** Kind-Zugriffe im Regressionstest statt quadratischer Arbeit.
- 200 schnelle Wheel-Ereignisse: **ein** aktiver Snap-Timer, nach Destroy keiner.
- Wiederholte Hintergrund-Resizes: über 100 Varianten getestet, maximal 64 Cachebilder; gemeinsam verwendete Bilder bleiben erhalten.
- Eventdispatch: 2.000 Emits über 13 Vorfahren benötigen im lokalen CLI-Median bei 0 / 1.000 / 10.000 fremden Listenern 1,689 / 1,823 / 2,271 ms. Keine ungeprüfte Vorher-/Nachher-Prozentangabe.

## Größere verbleibende Arbeiten

Diese Architektur- und Funktionsgrenzen werden durch einen lokalen Refactor nicht vollständig gelöst:

1. Stylesheet-Matching prüft weiterhin Regeln pro Element. Ein Selektorindex braucht eigene Cascade-/Pseudo-/Invalidierungsregressionen.
2. Partielle Layouts führen noch vorbereitende Baumgänge aus. Überspringen erfordert verlässliche Style-/DOM-Generationen.
3. Paint-Phasen, Float-Shapes pro Textzeile und komplexes Float/Clearance-Margin-Collapse sind begrenzt; keine vollständige CSS-Layoutkonformität.
4. `CSS/InlineStyle.luau` und `Rendering/RenderTree.luau` überschreiten die angestrebte Modulgröße deutlich. Eine Aufteilung braucht abgesicherte Schnittstellen; bloßes Kürzen wäre kein Performancebeleg.
5. DOM-ID-/Label-Suche ist linear. Vollständige dynamische DOM-/ARIA-/Screenreader-Semantik fehlt; native Eingabefelder und Tastaturbedienung allein ersetzen sie nicht.
6. Native Roblox-Textmessung, GPU-/EditableImage-Kosten, Gerätebudgets und Studio-Interaktion müssen auf Zielgeräten gemessen werden. CLI-Mocks belegen Logik, keine visuelle Gleichheit oder native Speichernutzung.

## Wiederholbare Prüfungen

```powershell
python scripts/test-sync-website.py
node scripts/run-html-tests.cjs
node scripts/run-svg-tests.cjs
node scripts/check-project.cjs
node scripts/export-engine-catalog.cjs
rojo build default.project.json -o build/roblox-html-engine.rbxlx
```

Die abschließenden Prüfresultate und die Katalogabdeckung stehen im [Stresstest-Bericht](STRESS-TEST-2026-09-21.md). HTML-/SVG-Gesamtsuiten, Generatorregression, statische Prüfung einschließlich Python, Offline-Abdeckung, strenger Browserlauf und Rojo-Build sind bestanden. Der Projektprüfer decodiert außerdem HTML-Entities in lokalen CSS-URLs korrekt.
