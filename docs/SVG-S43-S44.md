# S43/S44: SVG im HTML und Ressourcenbudgets

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Stand 14.09.2026. S41/S42 wurden mit „alles gleich“ zum Fortfahren bestätigt.
S43/S44 sind im folgenden Teilumfang implementiert und vom Nutzer zum
Fortfahren bestätigt. Ausführliche echte Client-Leistungsmessungen stehen aus.

## Vergleich und Bedienung

StudioDemoConfig: `S43_S44`. Stop → Play in Studio.
[Gemeinsame Vergleichsseite](../tests/fixtures/svg-regressions.zip), alternativ
[S43](../tests/fixtures/svg-regressions.zip) und [S44](../tests/fixtures/svg-regressions.zip).
Acht Tafeln enthalten zusammen elf SVG-Bilder im tatsächlichen HTML-Renderer.

- 1/2/3: HTML-Breite 240/480/960 Pixel, ohne erneutes Mounten der Seite.
- C: kontinuierliche Größenänderung starten/stoppen; Studio höchstens alle 60 ms.
- R: in Studio 20 komplette Seiten-Neuaufbauten; im Browser einmaliger iframe-Reload.
- Scrollen und Hover: blaues Rechteck wird grün, Cursor wird Fadenkreuz;
  orangefarbener Kreis zeigt den Zeiger. Die rosa HTML-Überlagerung zeigt Hilfe.

| Tafel | Sichtbarer Abgleich |
|---|---|
| Inline und Block | SVG zwischen Vorher/Nachher, Textumbruch und Blockbreite. |
| Clips und Überlagerung | Eltern-Clip, HTML vor SVG und verschachtelter Scrollbereich; Hover folgt der sichtbaren Fläche. |
| Deckkraft | HTML-Elternteil 0,5 multipliziert mit gemeinsam zusammengesetzter SVG-Gruppe 0,5. |
| Instanzen | Getrennte Verlaufsdefinitionen: links blau, rechts rot. |
| 10 / 100 / 1000 Formen | Dasselbe farbige Raster, zunehmende Formenzahl. |
| Kurven | 25 quadratische Kurven mit Verlauf in einem runden Clip. |

## Implementierung

`SceneBuilder` ist der gemeinsame Szenenaufbau für das bisherige SVG-Labor
und `SVG.Embedded`. Der HTML-Parser erhält SVG-Schreibweisen wie `viewBox`,
`linearGradient` und `clipPath`. `RenderTree` führt SVG-Flächen gesondert;
`ImageBox` rendert sie als passive ImageLabels mit EditableImage-Inhalt.
Der HTML-Inhaltskasten bestimmt den SVG-Viewport; Prozentgrößen werden nicht
ein zweites Mal angewendet. HTML-Rahmen, Hintergrund, Positionierung und
Inline-Ausrichtung bleiben beim HTML-Kasten. SVG-interne Gruppen behalten
ihre eigene Zeichenreihenfolge und Deckkraft.

`SVGImages` verbindet Layoutänderungen und SVG-Treffergeometrie mit der Seite.
Der bestehende HTML-Picker entscheidet zuerst über Clips/Überlagerungen;
danach erfolgt der SVG-Treffertest anhand tatsächlicher GUI-Position und Größe.
GetMouseLocation wird einmal um den GUI-Inset korrigiert; Input-Positionen
werden nicht ein zweites Mal umgerechnet. SVG-Hover löst Rasterarbeit,
aber kein neues HTML-Layout aus.

`RenderQueue` hat einen seriellen Worker pro Seite, verwirft überholte
Anfragen und hält nur die neueste Anfrage pro SVG-Fläche. Gleiche Abmessungen
verwenden dieselbe EditableImage. Ein LRU-Cache hält bis zu 16 Pixelzustände
mit insgesamt 8 MiB. Lebende Texturen haben ein eigenes 16-MiB-Budget pro Seite.
Rasterauflösung wird proportional auf höchstens 1024 Pixel je Achse begrenzt;
das ist unsere Qualitätsstufe, keine Aussage über sämtliche Roblox-Grenzen.
Rasterarbeit gibt nach ungefähr 4 ms an den Scheduler ab. Fehler werden
angezeigt und nicht in einer endlosen Wiederholung neu versucht.
Destroy bricht Arbeit ab und gibt Texturen und CPU-Cache frei.

## Verifikation

- Luau-SVG-Suite in normaler und optimierter Ausführung; echte Rasterdaten.
- Alle elf SVGs der kompletten HTML-Quelle bauen ohne SVG-Diagnosen.
- Echte HTML-Layoutpipeline mit GUI-Mocks: elf lokale SVG-Flächen,
  keine Remote-Bilder, 240/480/960/480 ohne zusätzliche GUI-Allokationen.
- Queue-Tests: 100 schnelle Anfragen → letztes Ergebnis, Cache-Treffer,
  Wiederverwendung, Abbruch während Resize/Destroy und 20 saubere Lebenszyklen.
- Host-Tests: Layout und SVGReady gemeinsam abwarten, C und R,
  deduplizierte Meldungen, Verbindungen und Seiten beim Beenden freigeben.
- Browser-Harness in Node mit ausdrücklich simuliertem DOM geprüft.
  Das ersetzt keinen nativen Browser-/Studio-Sichtvergleich.
- Vorschau aus tatsächlichen Luau-Rasterbytes: `build/svg-s43-s44-preview.png`.

Referenzmessung der optimierten Luau-CLI bei 480 × 200 Pixeln:
10 Formen 18,6 ms, 100 Formen 36,0 ms, 1000 Formen 80,6 ms,
25 Kurven mit Clip/Verlauf 145,7 ms. Alle Ausgaben jeweils 384000 RGBA-Bytes.
Diese Einzelmessungen sind keine Studio-FPS-Angaben. Die Lab-Statistik
`LastRasterMS`/`RasterMS` enthält verstrichene Zeit einschließlich Scheduler-Wartezeit.

## Offene Grenzen

- HTML- und SVG-Cascade sind noch getrennt. SVG-interne style-Elemente gelten
  nur im eigenen SVG; globale HTML-Regeln werden nicht vollständig in die
  SVG-Nachkommen übernommen. IDs/Verweise sind je SVG gekapselt; allgemeine
  Verweise zwischen SVG-Instanzen fehlen. Die Browser-Vergleichsquelle nutzt
  deshalb unterschiedliche IDs, keine vom Browser abweichende Doppel-ID-Probe.
- HTML-Farbe und Schriftgröße werden als Vorgaben übernommen; die vollständige
  Schrift-/CSS-Vererbung und externe Asset-/Font-Resolver fehlen in Embedded.
- Die Skript- und Animationslaufzeit aus S39–S42 startet in HTML noch nicht
  automatisch. Hier sind Hover und Cursor eingebunden, nicht die volle DOM-API.
- Die Szene wird bei Änderungen neu aufgebaut. Ein allgemeiner Geometriecache,
  Kachelung, parallele Worker und aus echten Geräten abgeleitete Budgets fehlen.
  Kontinuierliches Resize kann vorübergehend die letzte fertige Textur strecken.
  Extrem schmale Seitenverhältnisse können an der Raster-Mindesthöhe scheitern.
- Keine vollständige Prüfung allgemeiner Root-Filter/Transformationen,
  SVG-Overflow über den HTML-Kasten hinaus oder sehr großer Texturen.
- Lab-R misst den aktuellen Seitenbestand; erst echte Studio-Messreihen können
  zusätzlich engineinterne/allgemeine Speicherentwicklung bestätigen.

S45-Kombinationsbilder sind inzwischen umgesetzt (siehe SVG-S45.md); frühere
ausdrücklich dokumentierte Restfunktionen bleiben offen.
S43/S44 sind damit keine Behauptung vollständiger Browserkompatibilität.
