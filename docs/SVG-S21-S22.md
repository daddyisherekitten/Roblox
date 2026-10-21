# S21/S22 — Bilder und Ausschnitte

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Stand 14.09.2026. Implementiert und lokal geprüft; vom Nutzer mit
„passt weiter“ visuell bestätigt. Kein zusätzlicher Clientbericht. S19/S20 wurden nach der Rot-Korrektur
mit „weiter“ zum Fortfahren freigegeben, ohne zusätzlichen Clientbericht.

## Vergleich

- `examples/StudioDemoConfig.luau`: `ActiveDemo="SVGLab"`, `SVGStage="S21_S22"`.
- Studio: Stop → Play; Browser: `examples/svg-tests/s21-s22.html` öffnen.
- 1 / 2 / 3: 240 / 480 / 960 px. R: 20 Neuaufbauten.
- Sechs Tafeln, zwölf ausgegebene EditableImages wie in den vorherigen Paketen.
  Erwartet: `SVG_S21_S22_REPORT`, `Diagnostics: []`. Der Bericht ersetzt keine
  Sichtprüfung; `StudioVisualComparison` bleibt bis zur Nutzerabnahme pending.

| Tafel | Abgleich |
|---|---|
| S21-fit | meet, slice, none sowie Ausrichtung an unterschiedlichen Ecken; transparente Mitte und halbtransparenter Streifen |
| S21-transform | Rotation, Scherung, Gruppen-Alpha, natürliche Größe, automatisch ergänzte Breite, pixelige Vergrößerung |
| S21-vector | unabhängige SVG-Datei als Bild; schwarze Tür trotz roter Elternfarbe, Skalierung, Alpha und Drehung |
| S22-shapes | Kreis, evenodd-Loch, Vereinigung zweier Kreise, Rasterbild im Stern |
| S22-units | relative Bounding-Box-Einheiten, transformierter Clip, zwei use-Instanzen |
| S22-nested | identische Schnittmengen durch Gruppen und clipPath-Referenzen; Gruppen-Opacity und Bildausschnitte |

`scripts/sync-svg-images-clips.py` erzeugt die drei Laborquellen und HTML-Seiten
aus sechs SVG-Dateien. `--check` prüft Synchronität. Der Hash umfasst auch
das gemeinsame PNG und die referenzierte SVG-Datei.

## Bildquelle und Plattformprüfung

`S21-source.png` ist ein deterministisches 64×48-RGBA-Testbild. Der Generator
schreibt dieselben dekodierten Pixel in den Luau-Laborresolver. Die HTML-Seiten
betten exakt dieses PNG und `S21-source.svg` als Daten-URLs ein, damit auch die
isolierten Blob-SVGs ihre Dateien finden. Die Testgeometrie bleibt unverändert.
Es wurde kein Asset hochgeladen und keine fremde Bildberechtigung umgangen.

`Document.prepare(..., {ResolveImage=function(url,base) ... end})` erwartet
`{Width,Height,Pixels}` mit einem RGBA-buffer. Absolute Ressourcen-URLs werden
einmal je Dokument aufgelöst und die Pixel kopiert; Wiederholungen teilen die
kopierten Daten. Rückgabefehler, ungültige Abmessungen und Puffer werden
diagnostiziert. Ein fehlendes Bild bleibt transparent; gültige Nachbarn werden
weiter gezeichnet. Referenzierte `.svg`-Dateien verwenden `options.Resolve`
und einen eigenen CSS-Kontext, einschließlich lokaler defs/Gradienten/use.

Für echte Roblox-Assets kann der Aufrufer als ResolveImage verwenden:

```lua
ImageAssets.resolver(
    { ["picture.png"] = "rbxassetid://94339162936897" },
    game:GetService("AssetService"), Content, Vector2
)
```

Der Aufrufer muss einen yieldfähigen Aufbaukontext bereitstellen: Laden kann
warten. `ImageAssets` liest über `CreateEditableImageAsync`/`ReadPixelsBuffer`
und zerstört das temporäre EditableImage auch bei Lesefehlern. Kein nativer
Asset-Ladetest in dieser Etappe behauptet: Der Adapter ist mit API-Mocks für
Erfolg und Fehler geprüft. Gleiche lokale PNG-Datei + dazu hochgeladenes und
freigegebenes Roblox-Asset bleiben eine separate visuelle Plattformprobe.

## Implementierung und Grenzen

- `Image`: Größenberechnung, vorhandenes preserveAspectRatio-Mapping,
  transformierte Abtastung, vormultiplizierte bilineare Farbmischung zur
  Vermeidung dunkler/transparenter Säume; nächste Pixel bei pixelated/optimizeSpeed.
  Intrinsische Maße werden auch für Gruppen- und Transform-Bounds verwendet.
- `ClipPath`: CSS/Präsentationswerte, clip-rule, userSpaceOnUse und
  objectBoundingBox, Transform, use-Formen, Vereinigung von Kindern und
  Schnittmengen verschachtelter Referenzen. Füllfarbe, Kontur und Opacity
  beeinflussen die Clip-Silhouette nicht; display/visibility werden berücksichtigt.
- `Compositing` isoliert Clips und Opacity in CPU-Puffern. Ein Clip wird auf
  die gemeinsame Ausgabe einer Gruppe angewendet. Keine interaktiven GUIs.
- `Resources` verwendet denselben Besucher für Bild-SVGs, Muster, Marker und
  Clips. Referenzzyklen sind begrenzt und diagnostiziert.
- Grenzen: maximal 32 dekodierte Bilder/32 MiB Quellpixel pro Dokument,
  Einzelquelle höchstens 1024×1024. SVG-Bildraster und Pattern-Cache teilen
  32 MiB; Compositing 32 MiB gleichzeitig. Ressourcen- und Clip-Rekursion 12.
  Überschreitungen sind explizite Fehler/Diagnosen, keine stillen Endlosschleifen.
- SVG-Dateien werden vor der Bildplatzierung rasterisiert, mit maximal
  1024×1024. Kleine oder stark gedrehte SVG-Bilder können dadurch von direkt
  gerasterten Browservektoren abweichen. Bilineare Filterung und Clip-Alpha
  arbeiten mit 8 Bit; Rand-Antialiasing ist nicht als pixelidentisch abgenommen.
- Offener S21-Rest: vollständige CSS-object-fit/object-position-Anbindung,
  alle intrinsischen Größen-Sonderfälle von SVGs ohne feste Abmessungen,
  MIME-/Data-URL-/Fragmentauflösung ohne explizite Resolverzuordnung,
  Bildladeereignisse/reaktive Aktualisierung und Animation. Pixelated ist
  direkte Nächster-Pixel-Abtastung, keine vollständige zweistufige CSS-Skalierung.
- Offener S22-Rest: Text als Clip (S25–S28), CSS-Basisformen/Geometriebox-Syntax
  an clip-path sowie spätere Hit-Test-Anbindung (S36). Kein vollständiger
  CSS-Masking-Support behauptet; SVG-Formen und Referenzclips sind der Umfang.
- Allgemeine SVG-Einbettung in den HTML-Paint-Pfad ist weiterhin S43-Arbeit.

## Prüfung

`tests/SVGImagesClips.luau` prüft RGBA-Farben/Alpha, Cache, automatisches
Seitenverhältnis, alle neun meet/slice-Ausrichtungen, Root-viewBox-Clips,
relative Gruppen-Clips, Löcher, verschachtelte Clips, gemeinsame Deckkraft,
Clip-Silhouetten, ungültige Quellen/Zyklen, Freigabe bei Fehlern und Abbruch.
Alle sechs Vergleichsquellen werden bei 240/480/960 gerastert. Bestehende
SVG-Controllerprüfungen laufen auch für S21/S22 (20 Lebenszyklen, überholter
Resize, Abbruch beim Rasterisieren, abgekoppelte Eingaben).

Lokale CPU-Vorschau: `build/svg-s21-s22-preview.png`, visuell geprüft.
Die Browsersteuerung lehnte `file://` durch ihre URL-Sicherheitsprüfung ab;
kein Umweg versucht und kein nativer Browservergleich behauptet. Studio wurde
nicht automatisiert bedient. Die nachfolgende Nutzerabnahme erfolgte mit „passt weiter“.

Referenzen: [SVG 2 — Embedded Content](https://www.w3.org/TR/SVG2/embedded.html)
und [CSS Masking — Clipping](https://www.w3.org/TR/css-masking-1/#clipping-paths).
