# Rendering- und SVG-Audit – 21.09.2026

Teilprüfung für Schritt 1. Geprüft wurden Ressourcenbesitz und Render-Lebensdauer,
Hintergrund-/Effekt-Caches, HTML-Bewegung, die Canvas-Anbindung und der bestehende
SVG-Szenen-/Raster-/Queue-Pfad. Die Änderungen betreffen Rendering; Webseiten und
SVG-Code wurden in diesem Teilauftrag nicht verändert. Dies ist keine Zusage
vollständiger CSS-Kompatibilität oder einer lückenlosen statischen Verifikation
jeder Quellzeile.

## Behoben

| Fundstelle | Befund | Änderung und Prüfung |
| --- | --- | --- |
| `src/HTMLEngine/Rendering/BackgroundImages.luau` | Weak-Key-Gradientcache konnte den einzigen expliziten Cleanup-Handle eines EditableImage verlieren. Eine Folge unterschiedlicher Größen füllte dauerhaft den Cache; danach fehlte der Hintergrund. | Expliziter, begrenzter Ressourcenbesitz; älteste unbenutzte Varianten werden entfernt. Aktuell geteilte Bilder bleiben geschützt. `tests/Backgrounds.luau`: 101 Größenwechsel, maximal 64 lebende Bilder, geschützter Zweitbesitzer, genau einmalige Freigabe. |
| `src/HTMLEngine/Rendering/BackgroundImages.luau` | Cache berücksichtigte nur Texturauflösung. Unterschiedliche große CSS-Flächen können gleich große Texturen, aber andere Positionen absoluter Gradientstops haben. | Originalbreite/-höhe werden Teil des Schlüssels. Regression mit 300×100 und 600×200, derselben Rasterauflösung und 80px/100px-Farbstops. |
| `src/HTMLEngine/Rendering/HTMLAnimations.luau` | Der Ziel-Snapshot einer Transition wurde von einer gleichnamigen GUI-Variable überschattet; beim Interpolieren fehlten die numerischen Zielwerte. Opacity-Gruppen lasen außerdem die Hintergrundfarbe vom äußeren Gruppenelement. | Unveränderliche Zielwerte bleiben gespeichert, Hintergrund wird am tatsächlich bemalten Knoten gelesen. Es werden nur die animierten Eigenschaften zurückgesetzt; `offset-distance` verwendet den Transform-Pfad. `tests/Animations.luau` prüft Vorwärts-/Rückwärts-Hover, Position, Farbe und Opazität. |
| `src/HTMLEngine/Rendering/HTMLAnimations.luau` | Seiten mit bloßen Transition-Regeln oder bereits beendeten Animationen blieben an jedem Frame verbunden. | Frame-Verbindung entsteht erst bei aktiver Arbeit, endet nach Abschluss und startet bei späteren Zustandsänderungen erneut. Cleanup leert auch ausstehende Snapshots. Regression prüft Disconnect, Neustart und Abbau. |
| `src/HTMLEngine/Rendering/VisualEffectPixels.luau` | Dieselben CSS-Längen wurden in jedem Subpixel erneut aufgelöst. | Clip-Geometrie wird einmal pro Bild berechnet. 30 vorher/nachher erzeugte Bilder sind bytegleich; Messung unten. |
| `src/HTMLEngine/Rendering/VisualEffects.luau`, `src/HTMLEngine/Rendering/BorderCorners.luau` | Schwache Box-Lookups konnten explizit zu zerstörende Ressourcen vor dem Rendererabbau aus der Cleanup-Iteration verlieren. | Separate Listen besitzen die Ressourceneinträge bis zum Rendererabbau, ohne die Render-Boxen festzuhalten. `tests/RenderingLifetimes.luau` lässt zwei Boxen nachweislich vom Luau-GC entfernen und prüft die anschließende genau einmalige Image-Freigabe. |
| `src/HTMLEngine/Rendering/VisualEffects.luau` | `border-image` ignorierte Änderungen allein an Alpha2; gleiche Rastermaße konnten trotz anderer CSS-Maße ein veraltetes Clip-Bild wiederverwenden. | Zweiter Alpha-Wert und ursprüngliche Geometrie invalidieren den Cache. Regression prüft die resultierenden RGBA-Werte bei wiederverwendeter Textur. |
| `src/HTMLEngine/Rendering/GroupOpacity.luau` | Der vollständige neue Stresstest enthielt CSS-Tabellenzellen ohne unterstützten Zeilenwrapper. TableLayout diagnostiziert diesen Fall und lässt die Wörter unangordnet; die seitenweite Opacity-Komposition addierte anschließend fehlende Koordinaten und brach die ganze Seite ab. | Nur tatsächlich angeordnete Wörter tragen zum Paint-Bounds-Rechteck bei. `tests/Visibility.luau` prüft genau diese Struktur mit Opacity und drei Breiten. `StressCatalog` rendert danach den vollständigen Katalog durch. Die Unterstützung anonymer CSS-Tabellenwrapper wird dadurch nicht behauptet. |

## Messung

Lokale Luau-CLI, Ellipse mit 256×144 Pixeln und unveränderten 16 Deckungssamples:
Median aus neun Läufen **101,0 ms → 38,4 ms**. Pro Raster sinkt die Zahl der
Längenauflösungen von **1.179.648 auf 2**. Dies misst ausschließlich lokale
CPU-Rasterzeit, weder Studio-Framerate noch GPU-Upload.

Die bytegleichen Vergleichsfälle umfassen Kreis, Ellipse und Rundrechteck mit
Pixel-/Prozentlängen bei fünf Größen, einschließlich Downsampling.
Rohwerte und lokale Reproduktionsartefakte stehen in
[`measurements/rendering-audit/clip-raster.txt`](../measurements/rendering-audit/clip-raster.txt).

## Offene Architektur- und Funktionsgrenzen

- `VisualEffects`/`BorderCorners`: Masken übermalen Außenbereiche mit einer
  ermittelten Hintergrundfarbe. Das ist kein allgemeines Compositing auf
  beliebigen Bildern, transparenten Hintergründen oder verschachtelten Blend-
  Flächen. Echte Masken-/Backdrop-Komposition erfordert einen größeren Umbau.
- `PerspectivePixels`: unterstützt einfache Text-/Hintergrundboxen; normale
  HTML-Unterbäume und sämtliche Font-/Glyphenmerkmale sind nicht vollständig
  auf die Softwarefläche abgebildet. Eine allgemeine 3D-DOM-Projektion bleibt offen.
- `HTMLAnimations`: ein bereits laufender Runtimezustand entdeckt neue oder
  durch CSS nachträglich ersetzte Animationsdefinitionen nicht vollständig;
  der Paint-Teilumfang bleibt auf die vorhandenen Eigenschaften begrenzt.
- Große Rastereffekte bleiben CPU-Arbeit. Die Clip-Vorberechnung beseitigt
  redundante Geometrieauflösung, aber keine Pixel-/Antialiasing-Arbeit.
- Explizite Effektressourcen werden spätestens beim Rendererabbau freigegeben.
  Eine allgemeine inkrementelle Freigabe einzelner aus dem DOM entfernter Boxen
  ist eine separate Lebenszyklusfunktion; der Gradientcache kann unbenutzte
  Einträge bereits innerhalb einer Seite verdrängen.
- `SVG/RenderQueue`, `SVG/Raster`, `SVG/Resources`, `SVG/Session` und
  `Rendering/SVGImages` besitzen bereits Abbruch-, Größen-/Speicherbudgets,
  Ressourcenbegrenzung, Caches und Cleanup. In dieser Prüfung ergab sich dort
  kein weiterer ähnlich eng isolierbarer, neu belegter Hotspot. Die zuvor
  dokumentierten teuren Kaltstarts, Szenenneuaufbauten, vollständigen Uploads
  und Grenzen dynamischer Animationen gelten weiter:
  [`SVG-PERFORMANCE-REVIEW.md`](SVG-PERFORMANCE-REVIEW.md).
- `RenderTree` und `CanvasSurface` bündeln viele Aufgaben. Eine Aufteilung kann
  Wartbarkeit verbessern; ohne isolierten Verhaltensvertrag wurde kein rein
  kosmetischer Großumbau im selben Performance-Patch vorgenommen.

## Verifikation

- `node scripts/run-html-tests.cjs`: vollständig erfolgreich, einschließlich
  der neuen Backgrounds-, Animations- und RenderingLifetimes-Regressionen.
- `build/tools/luau/luau.exe -O2 build/html-tests.luau`: dieselbe vollständige
  Testsuite auch mit optimierter Luau-Ausführung erfolgreich.
- Die Pixeloptimierung wurde zusätzlich direkt mit dem unveränderten vorherigen
  Rastermodul verglichen: 30/30 RGBA-Puffer identisch.
- Ein nativer Browser-/Studio-Sichtvergleich wurde nicht durchgeführt und wird
  durch CLI-Tests ausdrücklich nicht als erledigt behauptet.

Nach Aufbau der neuen Stresstestseite wurde zusätzlich `node scripts/run-html-tests.cjs StressCatalog`
ausgeführt: 14.225 DOM-Knoten, 1.013 Eigenschaftsproben, 30.738 Mock-GUIs,
vier Layoutbreiten einschließlich Rückkehr zur Ausgangsbreite und ein
wiederholter unveränderter Lauf ohne neue GUIs/Textmessungen. 706 unterschiedliche
Diagnosen kennzeichnen den bewusst über das Engine-Profil hinausgehenden Katalog.
Dieser Test misst keine native GPU-Auslastung.
