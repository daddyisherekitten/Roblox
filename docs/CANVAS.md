# Canvas 2D

Stand: 4. Oktober 2026.

Der gemeinsame HTML-Realm enthält jetzt ein Path2D-Profil über `DOMCanvasPaths`:
leere Pfade, unabhängige Kopien, SVG-Pathstrings, `addPath` mit Matrix-Dictionary,
moveTo/lineTo/rect/arc/arcTo/ellipse und quadratische/kubische Kurven.
`fill(path, rule)`, `stroke(path)`, `clip(path, rule)` und `isPointInPath` verwenden
den Pfad, ohne den aktuellen Kontextpfad zu ersetzen. Die Zeichentransformation
gilt bei Verwendung des Path2D. Clipping speichert einen eigenen Geometriestand;
spätere Pfadänderungen ändern die Maske nicht. Nach closePath setzen weitere
Segmente am Anfang des geschlossenen Teilpfads fort.

18 identische Browser-/Luau-Abläufe prüfen Innenpixel, Kopien, Selbstaddition,
Matrixaliases, Transformationen, SVG-Kurven/Arcs, Füllregeln und Randpunkte,
Masken, Kontextpfaderhaltung, Receiver-/Klonfehler und Canvas-Reset.
Der sichtbare Vergleich zeigt drei Häuser aus derselben Geometrie.
Grundlage: [HTML Path2D](https://html.spec.whatwg.org/multipage/canvas.html#path2d-objects).

Grenzen des neuen Profils: Kein roundRect oder isPointInStroke; keine übertragbare
Path2D-Serialisierung. Der CPU-Renderer verwendet begrenzte polygonale
Kurvenapproximationen und besitzt weiterhin keine vollständige Browser-
Kantenglättung/Strichgeometrie. SVG-Daten werden beim Erzeugen mit 0,125 Einheiten
Zieltoleranz unter Segmentgrenzen abgeflacht; starkes späteres Vergrößern kann die
Approximation sichtbar machen. SVG-Quellen sind auf 256 KiB/4096 Ausgangspunkte,
abgeflachte SVG-Kurven auf 16.384 Punkte, erzeugte Pfade auf 65.536 Punkte begrenzt.

`<canvas>` ist als ersetztes Inline-Element registriert. `width` und `height`
bestimmen die interne transparente Bitmap und verwenden wie im Browser die
Standardgröße 300 × 150. CSS-Breite und CSS-Höhe skalieren nur die Darstellung.
Die Roblox-Umsetzung begrenzt eine Bitmap auf 2048 Pixel pro Achse und insgesamt
4.194.304 Pixel.

Eine Browser-Untertestseite kann exakt denselben HTML-, CSS- und JavaScriptcode
im Browser und in Roblox verwenden. Ein Script mit dem wirkungslosen
Datenattribut `data-canvas-script` wird zusätzlich von der begrenzten
Roblox-JavaScript-Laufzeit ausgeführt:

```html
<canvas id="drawing" width="720" height="280"></canvas>
<script data-canvas-script>
const canvas = document.getElementById("drawing");
const ctx = canvas.getContext("2d");
ctx.fillStyle = "#e63946";
ctx.fillRect(20, 20, 100, 60);
</script>
```

## Unterstützte 2D-Funktionen

- `fillStyle`, `strokeStyle`, `lineWidth`, `globalAlpha`
- `shadowColor`, `shadowBlur` bis 128 Pixel, `shadowOffsetX` und
  `shadowOffsetY`; drei lineare Boxfilter approximieren die weiche Gaußmaske
- `globalCompositeOperation` mit `source-over`, `source-in`, `source-out`,
  `source-atop`, `destination-over`, `destination-in`, `destination-out`,
  `destination-atop`, `lighter`, `copy` und `xor`
- die separablen CSS-Mischmodi `multiply`, `screen`, `overlay`, `darken`,
  `lighten`, `color-dodge`, `color-burn`, `hard-light`, `soft-light`,
  `difference` und `exclusion`
- die nicht separablen CSS-Mischmodi `hue`, `saturation`, `color` und
  `luminosity`
- `fillRect()`, `strokeRect()`, `clearRect()`
- `font` mit Source Sans Pro Regular, Bold, Italic und Bold Italic sowie
  `textAlign`, `textBaseline` und `direction`
- `fillText()`, `strokeText()` und `measureText()` einschließlich Kerning,
  gängiger Ligaturen, `maxWidth` und TextMetrics für Breite und Begrenzungen;
  dieselben Outline-Glyphen funktionieren mit Verläufen, Schatten, Clipping,
  Transformationen und Compositing
- `drawImage()` mit den drei Browser-Signaturen für vollständige Bilder,
  Skalierung und Quell-Crops; HTML-`img` und andere Canvas-Flächen können als
  Quelle dienen
- `createPattern()` mit Canvas- oder Bildquelle, `repeat`, `repeat-x`,
  `repeat-y`, `no-repeat` und `CanvasPattern.setTransform()`; Muster sind als
  Füll- und Konturfarbe auch auf Pfaden und Text einsetzbar
- `createImageData()`, `getImageData()` und `putImageData()` mit einem
  beschreibbaren, wie `Uint8ClampedArray` auf 0–255 geklemmten `data`-Puffer;
  Readback außerhalb der Zeichenfläche liefert transparentes Schwarz und
  `putImageData()` folgt dem Browser, indem es Transformation, Alpha, Schatten,
  Compositing und Clipping ignoriert
- `canvas.toDataURL()` und `canvas.toBlob()` erzeugen eine echte RGBA-PNG-Datei
  mit gültigen PNG-Chunks, CRC-32, Zlib/Adler-32 und Base64; nicht unterstützte
  angefragte MIME-Typen fallen wie im Browser auf `image/png` zurück
- `requestAnimationFrame()`, `cancelAnimationFrame()` und `performance.now()`;
  Callbacks laufen in Anforderungsreihenfolge mit einem gemeinsamen Zeitstempel,
  können den Folgeframe planen und lösen höchstens einen gebündelten
  `EditableImage`-Upload pro sichtbarem Frame aus
- `getContext("webgl")`, `experimental-webgl` und `webgl2` mit Shader- und
  Program-Lebenszyklus, Float-/Index-Buffern, Attributen, Viewport, Clear,
  `drawArrays()` und `drawElements()` für Dreiecke sowie den üblichen Kern-
  Konstanten und Statusabfragen; Positionen und Farben werden aus echten
  interleavten Vertexdaten gelesen und baryzentrisch interpoliert
- `getContext("webgpu")` mit `navigator.gpu`, Adapter-/Device-Promises,
  `GPUBufferUsage`, `GPUQueue.writeBuffer()`, Shader-Modulen, Renderpipelines,
  Canvas-Konfiguration, Command Encodern, Renderpässen und Queue-Submission;
  die Pipeline liest `float32x2`-Positionen und `float32x3/4`-Farben aus dem
  beschriebenen Vertexlayout
- `imageSmoothingEnabled` sowie `imageSmoothingQuality`; Roblox lädt jede
  explizit über `Options.Images` zugeordnete Quellbitmap einmal pro Seite und
  gibt das temporäre `EditableImage` nach dem Pixel-Readback sofort frei
- `beginPath()`, `moveTo()`, `lineTo()`, `closePath()`, `rect()`, `arc()`
- `quadraticCurveTo()`, `bezierCurveTo()`, `ellipse()`, `arcTo()`
- `fill()`, `stroke()`
- `clip()` sowie `fill("nonzero")` und `fill("evenodd")`
- `createLinearGradient()`, `createRadialGradient()` und
  `CanvasGradient.addColorStop()`; Verläufe halten die beim Erstellen aktive
  Transformationsmatrix fest
- `save()`, `restore()` für den Zeichenstil
- `translate()`, `rotate()`, `scale()`, `transform()`, `setTransform()`,
  `resetTransform()`; die Matrix wird von `save()`/`restore()` mitgesichert
- CSS-Farben aus dem gemeinsamen Farbparser
- transparentes Source-over-Compositing

Alle Befehle eines Scripts ändern zuerst einen CPU-Puffer. Erst nach dem Script
wird dieser Puffer einmal in eine `EditableImage` hochgeladen. Dadurch erzeugt
eine Zeichnung mit vielen Befehlen keinen Upload pro Befehl.

## Grenzen

WebGL und WebGPU bilden in Roblox eine begrenzte CPU-Kompatibilitätsschicht.
Shader werden auf Vorhandensein eines Einstiegspunktes geprüft; allgemeiner
GLSL-/WGSL-Code, Uniformberechnung, Texturen, Depth/Stencil, MSAA, Compute-
Passes und die vollständigen Spezifikationsoberflächen werden nicht emuliert.
Der gemeinsame HTML-JavaScript-Realm führt gewöhnliche Scripts ohne zusätzliches
Canvas-Datenattribut aus. Dort ist derzeit das dokumentierte 2D-Profil zugänglich.
Die frühere separate SVG-/Canvas-Laufzeit bleibt für ihre vorhandenen
WebGL-/WebGPU-Teilpfade bestehen; ihr `data-canvas-script`-Modus beschreibt nicht
die inzwischen ausgebaute allgemeine HTML-Laufzeit.

Ein Canvas-Pfad ist auf 65.536 erzeugte Punkte begrenzt, einschließlich der
Unterteilung von Kurven und temporärer Textkonturen. Größere Geometrie wird mit
einer Diagnose abgewiesen; die Auflösung regulärer Kurven wird nicht reduziert.
`beginPath()` setzt dieses Budget zurück. Die Punkterzeugung prüft regelmäßig
das kooperative Arbeitsbudget und den Lebenszyklus der Seite. Große endliche
Winkel werden ohne wiederholte Normalisierungsschleifen verarbeitet.

Die Luau-Seite kann eine benannte Zeichenfläche mit
`page:GetCanvasContext(id)` abrufen. Die Oberfläche und ihre `EditableImage`
werden zusammen mit der PageSession freigegeben. Dabei werden auch ausstehende
Animationsframes verworfen und die gemeinsame Render-Verbindung getrennt.
Die Ressourcen gehören bereits während der Initialisierung zur PageSession;
ein Uploadfehler oder eine während des Ladens geschlossene Seite gibt auch
teilweise angelegte Ressourcen wieder frei.
