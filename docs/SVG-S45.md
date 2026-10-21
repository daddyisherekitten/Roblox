# S45: kombinierter SVG-Gesamtabgleich

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Stand 14.09.2026. S43/S44 vom Nutzer zum Fortfahren bestätigt. Die vier neuen
S45-Tafeln sind implementiert; der native visuelle Vergleich ist noch offen.
Der [Supportkatalog](SVG-SUPPORT.md) führt verbleibende Funktionen gesondert auf.

## Start und Vergleich

StudioDemoConfig `S45`, Stop → Play. [Browser-Vergleich](../tests/fixtures/svg-regressions.zip).
Die Tafeln nutzen den etablierten eigenständigen SVG-Host; sie behaupten keine
vollständige Skript-/Animationsunterstützung in HTML. S43/S44 bleibt separat testbar.

| Tafel | Erwartung |
|---|---|
| Blume | Beige Fläche, acht äußere und acht innere Blätter aus use, gelber radialer Mittelpunkt. Ein angefahrenes Blatt wird rosa, Cursor Fadenkreuz. |
| Diagramm | Weißer Kasten, beschriftete Achsen, gestricheltes Raster, blaue Kurve/Flächenverlauf, vier Punktmarkierungen. Obere Beschriftung folgt einem Pfad. |
| Symbolkarte | Gemusterter Stern, angeschnittener gelber Stern (lokale Maske ab 0,0), violetter Pfeil mit zwei Markern, Kreis-Clip und multiplizierte blaue/rosa Kreise. |
| Interaktive Szene | Kreis mit weichem Schatten über Zeitmarken, Verlaufsbalken, Farbe-Knopf. Bewegung und Script-Farbwechsel können zusammen aktiv sein. |

- 1/2/3: 240/480/960 Pixel.
- P: Animation starten/pausieren. Sie startet bewusst bei angehaltener Zeit 0.
- Z/X/C/V/B: Zeit 0 / 0,25 / 0,5 / 0,75 / 1 Sekunde.
- Farbe anklicken oder per Tab/Enter: Kreis und Balken wechseln gemeinsam
  Blau/Grün, ohne die gewählte Animationszeit zu verändern.
- R: alle Dokumente, Skriptzustände und die gemeinsame Uhr zurücksetzen.

Bei 0/0,25/0,5/0,75/1 s liegt der Kreismittelpunkt bei x=70/155/240/325/410.
Nach 1 s bleibt die Bewegung am Ende stehen (`fill=freeze`). Ein fortlaufender
Loop ist hier nicht vorgesehen; mit Z oder R zurücksetzen.

## Quellen und Prüfungen

`scripts/sync-svg-acceptance.py` erzeugt vier SVG-Quellen, `AcceptanceSources`
und die Browserseite aus denselben SVG-/JavaScript-Quellen. Der Browser führt
die eingebetteten Skripte nativ aus; Roblox verwendet ScriptDOM/ScriptVM.
Die browserseitige Vergleichsuhr steuert native SMIL-Zeitpunkte. Die
Frame-Nachrichten prüfen Quelle und Generation; alte Frames beeinflussen keinen Reset.

`tests/SVGAcceptance.luau` baut alle vier kombinierten Szenen und rastert bei
240/480/960 Pixeln. Es prüft Diagnosefreiheit, sichtbaren use-Hover, alle fünf
Kreispositionen, gemeinsame Ressourcenänderung per Skript/Tastatur und die
exakte Wiederherstellung der ursprünglichen Pixel nach Rückkehr zum Startzustand.
Der S45-Hosttest verbindet echte Session-/Script-/Animationsmodule mit
GUI-/Asset-/Scheduler-Mocks und prüft Eingaben sowie 20 vollständige Resets.
Die gespeicherte Luau-Rastervorschau zeigt vier Ausgangsbilder und zwei
Interaktionszustände: `build/svg-s45-preview.png`.

`scripts/test-svg-acceptance-browser.cjs` führt die erzeugten Parent-/Frame-
Skripte in Node mit ausdrücklich simuliertem DOM aus: Start, Play/Pause,
Seek, Script-Farbwechsel, Tastatur, Resize, Reset und Nachrichtenherkunft.
Diese Prüfungen ersetzen weder Browser-Rasterverifikation noch Studio-FPS-Messungen.

## Lokales Prüfergebnis

SVG-Suite normal und optimiert bestanden; HTML-Regressionen, Browser-DOM-Mocks,
Generatorprüfung und Projektaudit bestanden. Drei Rojo-Builds erstellt; der
laufende Rojo-Server liefert S45 und AcceptanceSources. Native Client-/Browser-
Vergleiche bleiben ausdrücklich dem folgenden Abnahmeblock vorbehalten.

## Abnahme offen

- [ ] Vier Tafeln im Browser und Studio vergleichen.
- [ ] Alle drei Größen und die fünf festen Zeiten vergleichen.
- [ ] Hover, Maus/Tastatur, Pause und Reset im Client prüfen.
- [ ] Bericht `SVG_S45_REPORT`: vier Fälle, keine unerwarteten Diagnosen.

Der erfolgreiche Abschluss dieser Tafeln wäre eine Integrationsabnahme des
vorhandenen Profils. Der vollständige ursprüngliche SVG-Plan ist wegen der
im Supportkatalog genannten Restfunktionen weiterhin nicht abgeschlossen.

## Korrektur: Maske auf verschobenem use

Der Nutzervergleich zeigte einen angeschnittenen Stern im Browser, aber einen
vollständigen halbtransparenten Stern in Roblox. Ursache: use x/y verschob
nur den expandierten Inhalt; der userSpaceOnUse-Maskeninhalt blieb unverschoben.
Document bewahrt jetzt die ergänzende use-Translation, Mask wendet sie auf
userSpaceOnUse-Inhalt und -Region an. ObjectBoundingBox verwendet weiterhin
den bereits verschobenen Geometriekasten, ohne die Translation zu verdoppeln.
Die SVG-Vorlage bleibt unverändert; der korrekte Sollzustand ist das Fragment.
Regressionen vergleichen alle vier Kombinationen von maskUnits/maskContentUnits
mit explizit verschobenen Gruppen unter Skalierung und prüfen Sternpixel.
Dies ist eine Maskenkorrektur; die entsprechende use-Semantik für Clip/Filter
ist damit nicht als vollständig geprüft ausgewiesen.
Referenz: [SVG2 use layout](https://www.w3.org/TR/SVG2/struct.html#UseLayout).
