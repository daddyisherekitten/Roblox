# SVG-Performance-Review — 20.09.2026

Der komplette SVG-Verarbeitungspfad wurde geprüft, einschließlich HTML-Einbettung und interaktivem SVG-Labor. Die größten nachgewiesenen Engpässe sind behoben. Die erste neue Hover-Variante des aktuellen Stresstests benötigt lokal durchschnittlich 119 ms Rasterarbeit statt 1531 ms. Ein bereits gespeicherter Zustand benötigt weiterhin keinen neuen Szenenaufbau und keine Rasterung.

Das ist keine Zusage von 60 FPS für beliebige SVGs. Der erste vollständige Bildaufbau, komplexe laufende Animationen und Änderungen außerhalb des derzeit abgesicherten Teilbereichspfads bleiben teuer.

## Messung am aktuellen Stresstest

Gleicher Rechner, gleiche Luau-CLI, gleiche SVG-Quelle, 446 × 669 Pixel. Gemessen wurden der Grundzustand und der erste Besuch jedes der fünf Hover-Ziele. Die Zahlen enthalten keine echten Roblox-Scheduler-Wartezeiten, keinen GPU-Upload und keine Studio-Oberfläche. Die alte Implementierung wurde als ausführbares Modul-Bundle vor den Änderungen gesichert.

| Vorgang | Vorher | Nachher | Verbesserung |
|---|---:|---:|---:|
| Szenenaufbau, Mittel der fünf neuen Hover-Zustände | 140,8 ms | 18,3 ms | 7,7× |
| Rasterung, Mittel der fünf neuen Hover-Zustände | 1530,6 ms | 119,2 ms | 12,8× |
| Hitbox-Aufbau, Mittel der fünf Zustände | 7,9 ms | 2,7 ms | 2,9× |
| 500 Trefferabfragen, Mittel | 76,9 ms | 7,2 ms | 10,7× |
| Erste vollständige Rasterung | 1551,8 ms | 1385,8 ms | 1,1× |

Alle sechs Ergebnisbilder wurden **Byte für Byte** mit der vorherigen Implementierung verglichen: jeweils 1.193.496 RGBA-Bytes identisch. Die Messdateien enthalten zusätzlich SHA-256-Prüfsummen. Antialiasing, Auflösung und Filterqualität wurden nicht reduziert.

Der Queue-Test mit dieser vollständigen Szene hält alle sechs Zustände gleichzeitig: 7.160.976 Pixel-Bytes, 521.951 gezählte Metadatenfelder, kein übersprungener Cacheeintrag. Beim erneuten Besuch wird keiner dieser Zustände neu gebaut.

- Messdaten: [vorher](../measurements/svg-performance/before.txt), [nachher](../measurements/svg-performance/after.txt).
- Reproduzierbar mit `node scripts/benchmark-svg.cjs` für die aktuelle HTMLPage-Demo.
- `node scripts/benchmark-svg.cjs --compare-baseline` prüft zusätzlich gegen das lokal gesicherte `build/svg-benchmark-before.luau`.
- `--baseline` erzeugt bewusst eine neue Referenz und sollte für den Vergleich dieses Reviews nicht erneut ausgeführt werden.

## Behobene Ursachen

### Szenenaufbau, Styles und Text

`SceneBuilder`, `Document`, `Style`, `Text`, `Geometry`, `TransformBounds`, `AuthorRules`:

- Laufzeit-Bounding-Boxes werden erst bei einer tatsächlichen Geometrieabfrage berechnet. Zuvor wurden für fast jeden DOM-Knoten erneut ganze Unterbäume vermessen.
- Textausdehnung und Referenzboxen werden innerhalb einer Szene wiederverwendet. Viewport- und Schriftkontexte bleiben dabei getrennt.
- Schriftkonturen werden pro Glyphenquelle einmal geparst. Die transformierten Konturen werden direkt weitergereicht, statt sie für jede Glyphe nochmals aus erzeugtem Pfadtext zu parsen. Die bisherige Koordinatenrundung bleibt erhalten.
- Ressourcen übernehmen bereits berechnete Styles ihrer Vorfahren. Hover an einer Verlaufsreferenz löst dadurch weniger wiederholte CSS-Arbeit aus.
- Zustandsabhängige Selektoren werden einmal pro Regelsammlung bestimmt. Ohne passende `:hover`-/`:active`-/`:focus`-Regeln entfällt der DOM-Durchlauf für diesen Zustand.
- Text, der durch `<use>` eingebunden wird, behält die sichtbare Instanz als Ereignisziel.

### Rasterung, Ebenen und Filter

`Raster`, `Compositing`, `FilterBlur`, `FilterPixels`, `FilterNoise`:

- Bereits fertiggestellte isolierte Ebenen werden anhand ihres vollständigen Renderinhalts wiederverwendet. Unveränderte Rauschfilter, Unschärfen und Masken müssen beim nächsten Hover nicht erneut berechnet werden.
- Gespeicherte Ebenen enthalten nur ihre sichtbare Pixelfläche. Auch die Kombination mit dem Hintergrund beschränkt sich auf diese Fläche.
- Bei Änderungen innerhalb gefilterter Zweige wird die Vereinigung der alten und neuen Filterausgabebereiche neu gezeichnet. Der Rest des fertigen Bilds bleibt erhalten. Das deckt den aktuellen Stresstest ab.
- Filterquellen werden weiterhin einschließlich ihres benötigten Randbereichs gerendert. Unsichere Änderungen, andere Größen oder komplexere Abhängigkeiten verwenden automatisch die vollständige Rasterung.
- Gruppen mit ausschließlich einem Clip bleiben mit ihrem tatsächlichen Hintergrund verbunden. Eine falsche Isolation würde beispielsweise überlappende Blend-Modi verändern.
- Normale horizontale/vertikale Gauß-Filter verwenden direkte Pixelzugriffe. Schatten verwischen nur den benötigten Alphakanal. Gewichtung und Summationsreihenfolge bleiben erhalten.
- Deckende einfarbige Pixel haben einen direkten Schreibpfad; außerhalb des betroffenen Bereichs entfällt unnötige Vorbereitung von Pattern-Paints.
- Die innere Rauschberechnung erzeugt weniger temporäre Tabellen.

### Warteschlange und Lebensdauer

`RenderQueue`, `Rendering/SVGImages`, `SVGLab/Interactive`:

- Nach dem ersten sichtbaren Bild werden die unterschiedlichen statischen
  `:hover`-Darstellungen gesammelt und im Hintergrund als CPU-Pixel vorbereitet.
  Der erste spätere Hover verwendet damit bereits Szene und Raster aus dem Cache.
- Sichtbare Anforderungen haben Vorrang vor der Vorbereitung. Ein unterbrochener
  Vorbereitungsjob behält seine aufgebaute Szene und wird danach fortgesetzt; sein
  Ergebnis wird niemals von selbst angezeigt.
- Größenänderung, Entfernen und Seitenabbau verwerfen alle dazugehörigen Jobs,
  Szenen und Pixel. `SVGPrewarmStates`, `SVGCacheBytes` und `SVGCacheEntries`
  machen die Grenzen pro Seite einstellbar.
- Ein schon begonnener unveränderlicher Zustand darf fertig werden und den Cache füllen. Ein veraltetes Ergebnis überschreibt niemals den neueren gewünschten Hover-Zustand.
- Bereits gespeicherte Bilder können an einer noch laufenden Berechnung vorbeiziehen. Zurück auf den Hintergrund zu gehen wartet somit nicht auf ein anderes kaltes Bild.
- Wiederholte Änderungen eines SVGs blockieren andere wartende SVGs nicht dauerhaft.
- Nach einem fehlgeschlagenen Aufbau kann derselbe Zustand erneut angefordert werden.
- Entfernte SVGs geben Textur, CPU-Bilder und wiederverwendbare Renderdaten frei. Auch während einer Berechnung entfernte Besitzer können ihren Cache nicht wiederbeleben.
- Der Labor-Host verwendet dieselben wiederverwendbaren Renderdaten. Seine vollständige DOM-Serialisierung wird erst nach einer Mutation erneuert; Fragmentnavigation ist Bestandteil des Cache-Schlüssels.

### Treffer, Ereignisse, Abfragen und Animation

`HitTest`, `Events`, `Queries`, `Session`, `Animation*`, `ScriptDOM`:

- Bounding-Boxes verwerfen weit entfernte Formen und Gruppen vor der aufwendigen Konturprüfung.
- Nicht benötigte, unbemalte Konturen werden für normale Trefferabfragen nicht mehr tesselliert.
- Ereignislistener sind nach Ereignis und Ziel indiziert. Der Dispatch kopiert nur Listener auf dem Ereignispfad. Mehrfaches `Disconnect` beschädigt die Listenerzählung nicht mehr.
- Pfadlängen und segmentierte Konturen werden wiederverwendet; `getPointAtLength` sucht das Segment binär. Zurückgegebene Pfaddaten können den Cache nicht verändern.
- Cancel und Touch-Ende räumen logische Zustände auch ohne CSS-Effekt korrekt auf und lösen dann keinen unnötigen Neuaufbau aus.
- Ersetzte DOM-Knoten mit identischer Geometrie erhalten trotzdem das richtige Ereignisziel.
- Identische Animationsabfragen werden wiederverwendet; statische Keyframepositionen werden einmal sortiert.
- Die Animationshistorie speichert nur tatsächlich benötigte Ereignistypen. Unbeteiligte Mausbewegungen verdrängen so keine relevanten Animationsstarts. Änderungen an `begin`/`end` aktualisieren diese Auswahl.
- Änderungen an Stylesheetinhalt und Struktur invalidieren die Zustandsregeln.

## Speichergrenzen

- Ganze Queue-Bilder: standardmäßig 24 MiB RGBA und 48 Einträge. Pro Seite sind
  über `SVGCacheBytes` bis 256 MiB und über `SVGCacheEntries` bis 256 Einträge
  möglich. Die Hintergrundvorbereitung ist standardmäßig auf 16 Zustände je SVG
  begrenzt und über `SVGPrewarmStates` zwischen 0 und 64 einstellbar.
- Queue-Szenenmetadaten: maximal 1.000.000 erreichbare Tabellenfelder zusammen und 262.144 pro Eintrag. Zyklische und geteilte Referenzen werden berücksichtigt. Zu große Einträge werden gerendert, aber nicht gespeichert.
- Wiederverwendbare Ebenen: 8 MiB RGBA pro Besitzer, 24 MiB gemeinsam; maximal 24 Einträge pro Besitzer.
- Ebenenmetadaten: 262.144 Tabellenfelder pro Besitzer, 1.048.576 gemeinsam.

Diese Grenzen begrenzen Pixelpuffer und gespeicherte Datenstrukturen getrennt. Sie messen nicht den gesamten Luau-Heap: beispielsweise Strings, Funktionsabschlüsse und geladene Schriften sind darin nicht als exakte Bytes enthalten. Bildressourcen bleiben entsprechend dem vorhandenen Vertrag unveränderlich; bearbeitete Pixel benötigen einen neuen Buffer oder die Freigabe der Renderdaten.

## Verbleibende Prioritäten

1. **Erster vollständiger Aufbau:** Rausch-, Licht-, Morphologie- und andere umfangreiche Filter bleiben CPU-Arbeit. Die Hover-Vorbereitung verschiebt diese Arbeit vor die Interaktion, beseitigt aber nicht ihre Gesamtkosten. Ein Hover vor Abschluss der Vorbereitung erhält Vorrang und kann bei einem noch kalten Zustand weiterhin warten.
2. **Allgemeine Teilbereiche:** Der neue Pfad benutzt nachweisbare Filterausgabegrenzen. Reine Änderungen unfiltrierter Blütenblätter oder beliebiger Pfadgeometrie benötigen noch eine konservative Begrenzung einschließlich Stroke, Miter, Marker und Abhängigkeiten. Bis dahin verwenden sie den vollständigen Renderer mit wiederverwendbaren Ebenen.
3. **Inkrementeller Szenengraph:** Vorbereitete Hover-Zustände verwenden ihre gespeicherte Szene. Nicht vorhersehbare oder dynamisch erzeugte Zustände bauen weiterhin eine neue Szene auf. Die gemessenen rund 18 ms können bei großen Dokumenten noch einen Frame überschreiten. Dauerhaft gespeicherte Style-/Geometrieknoten mit gezielter Invalidierung wären der nächste größere Umbau.
4. **Animation und Upload:** Laufende Animationen benötigen neue Ergebnisse. Der Labor-Host taktet sie auf maximal 30 Aktualisierungen pro Sekunde; diese Rate wird bei teuren Szenen nicht garantiert. Die Queue lädt weiterhin das vollständige fertige Pixelbild hoch, auch wenn nur ein Teil neu gerastert wurde.
5. **Sehr viele Trefferziele:** Bounding-Boxes werden weiterhin linear geprüft. Ein räumlicher Index lohnt sich erst bei deutlich größeren Szenen oder vielen überlappenden Konturen.
6. **Dynamisch eingefügte Animationsknoten:** Eine bestehende Animation-Instanz entdeckt neue `<animate>`-Knoten bisher nicht automatisch. Das ist eine verbleibende Funktionsgrenze, unabhängig von der Hover-Optimierung.

Die Bereiche XML/HTML-Einbettung, Längen/Viewports/Transformationen, Pfad- und Strichgeometrie, Ressourcenauflösung, Verläufe/Patterns/Bilder, Text, Filter, Interaktion sowie Script-Ausführung wurden in diese Prüfung einbezogen. Für Parser, Größenberechnung und Script-Syntax/VM ergab sich in diesem Stresstest kein vergleichbar großer nachgewiesener Engpass; ihre vorhandenen Budgets und Fehlerbehandlung bleiben bestehen.

Die unveränderte Benchmarkquelle enthält außerdem den bisherigen Diagnosefall `invalid-points` (`points="0,-68 61,42-61,42"`). Er bleibt für einen identischen Vorher-/Nachher-Vergleich erhalten und ist keine neue Folge der Optimierung.

## Prüfung und Studio-Abgleich

- Vollständige SVG-Suite S01–S45 einschließlich vorhandener Bild-, Interaktions- und Lebensdauertests, jeweils im normalen und im optimierten Luau-Lauf bestanden.
- Neue Regressionen für Szenenaufwand, Teilbereiche, Pixelgleichheit, Cachegrenzen, veraltete Bilder, schnelle Zustandswechsel und Fehlerwiederholung.
- Vollständige HTML-Suite einschließlich der SVG-Einbettung und Debug-Ausgabe.
- Rojo-Build des vollständigen Studio-Projekts.
- Bytegenauer Vergleich der sechs ursprünglichen Stresstestbilder.

Die Debug-Ausgabe zeigt jetzt zusätzlich `Hover vorbereitet` mit fertigen,
wartenden, unterbrochenen und abgebrochenen Jobs sowie der belegten Cachegröße.
Sie zeigt außerdem `Teilbereich neu gerastert`, wiederverwendete/erstellte Ebenen,
neu gezeichnete Fläche sowie Rasterarbeit und Scheduler-Wartezeit getrennt.
`Szenen` zählt weiterhin tatsächliche Szenenaufbauten; Teilrasterung bedeutet
nicht, dass auch der Szenengraph schon inkrementell aufgebaut wird. Die neue
Fläche bezeichnet die endgültig neu gezeichnete Ausgabefläche, nicht alle
zusätzlich benötigten Filter-Zwischenpixel.

Die verbleibende Studio-Verifikation ist ein neuer Play-Lauf mit den aktualisierten Modulen: erster Hover über jedes der fünf Felder, schnelles Verlassen während der Berechnung, danach wiederholte Wechsel. Lokale CLI-Messungen ersetzen diese Beobachtung nicht.
