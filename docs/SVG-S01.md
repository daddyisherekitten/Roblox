# S01 — Pixel- und Textlabor

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: **implementiert, lokal getestet und vom Nutzer visuell bestätigt**
(Rückmeldung: „alles passt“). S02 kann beginnen. Noch kein allgemeiner SVG-Parser/Renderer
in der HTML-Engine: S01 ist bewusst ein eigenständiger Plattformversuch.

## Öffnen und vergleichen

- Browser: [Vergleichslabor](../tests/fixtures/svg-regressions.zip), Zoom 100 %.
- Studio: `default.project.json` mit Rojo synchronisieren, Stop → Play.
  `examples/StudioDemoConfig.luau` steht jetzt auf `ActiveDemo = "SVGLab"`.
  Das HTML-Labor lässt sich dort mit `"HTMLPage"` wieder einschalten.
- Optional separates Rojo-Projekt: `svg-lab.project.json`.
- Wenn nach einer Projektbaum-Erweiterung nichts erscheint: Rojo-Server neu
  starten, im Studio-Plugin neu verbinden und Stop → Play. Beim ersten S01-Start
  hatte der Server die neue Config synchronisiert, die neuen Laboreinträge aber
  noch nicht geladen; der Server wurde daraufhin neu gestartet und sein aktueller
  API-Snapshot auf Starter-Script und Labormodule geprüft.
- Tasten **1 / 2 / 3** wählen 240 / 480 / 960 Pixel Breite, im Browser wie in Roblox.
  In Studio muss der Spielbereich den Tastaturfokus haben.
- **R** baut die Testtafeln 20-mal ab und neu auf. Der Browser macht dies direkt;
  Roblox arbeitet kooperativ und zeigt den Fortschritt. Währenddessen sind weitere
  Größenwechsel möglich und müssen alte Aufträge abbrechen.
- Auf kleinen Ansichten nativ scrollen. Die 100-Pixel-Messlinie bleibt immer
  100 Pixel breit, unabhängig von der gewählten SVG-Größe.

## Was sichtbar stimmen soll

1. Vier gleich große Felder: Rot `#e53935`, Grün `#43a047`, Blau `#1e88e5`,
   danach dasselbe Blau mit 50 % Deckkraft. Das Schachbrett scheint nur beim
   vierten Feld durch. In der Quelle bleibt außerhalb der Formen Alpha 0.
2. Die violette Diagonale ist ebenfalls halbtransparent. Kanten geglättet,
   gerade abgeschnittene Enden; keine schwarze oder weiße Randfarbe.
3. Texttafel: „H x p“ normal, um −15° um den Startpunkt gedreht und durch einen
   Kreis ausgeschnitten. Bei der dritten Probe verschwindet ein Teil des H.
   Der ausgeschnittene Bereich enthält echte transparente Glyphenpixel.
4. Beim Größenwechsel bleiben Proportionen und Positionen erhalten. Das
   Schachbrett verwendet in beiden Programmen feste 16-Pixel-Kacheln.
5. Eine zusätzliche native TextLabel-Probe zeigt dieselbe Schrift. Sie ist
   **unkalibriert** und gehört nicht zur Pixel-/Masken-Gleichheitsprüfung.

Für diese Etappe: Farbflächen im RGBA-Buffer exakt wie oben, 50-%-Alpha gerundet
auf 128. Achsenkanten bei allen drei Größen auf denselben Pixelgrenzen.
Die Linienkante darf durch unterschiedliche Abtastung im unmittelbar angrenzenden
Randpixel abweichen, nicht in Lage, Dicke oder Endpunkt. Rastertext benutzt einen
vorbereiteten 32px-Glyphenbuffer und wird skaliert; native Browser-Schrift wird bei
jeder Größe neu gerastert. Deren Glättung ist daher ausdrücklich kein Pixelgleich-
Versprechen. Glyphenlage, Drehrichtung und Kreis-Ausschnitt müssen trotzdem stimmen.
Am Kreisrand verwendet die Probe eine pixelzentrierte Ausschneidung; geglättete
allgemeine SVG-Clips sind erst Gegenstand von S22.

## Gemeinsame Quelle und Text-Machbarkeit

`S01-pixels.svg` und `S01-text.svg` sind die Browser-Quellen. Der kleine
Entwicklungs-Compiler `scripts/sync-svg-lab.py` liest genau diese Dateien und
erzeugt die feste Szenenbeschreibung `examples/SVGLab/Fixture.luau` sowie das
Browserlabor. Er akzeptiert nur die benötigte S01-Syntax; er ist **kein**
SVG-Parser für beliebige Benutzereingaben. Ab S02 folgt der eigentliche Engine-Pfad.

Die Fontdatei `examples/fonts/SourceSansPro-Regular.ttf` liegt bereits samt
OFL-Lizenz im Projekt. Pillow erzeugt beim Synchronisieren die Alpha-Pixel nur
für den Satz „H x p“ bei 32px. Diese werden in der Fixture als Hexdaten eingebunden.
Browser und Compiler verwenden dieselbe Fontdatei; SHA-256-Werte für Font und
SVG-Quellen stehen im Laufzeitbericht. Das ist ein zulässiger Importversuch,
kein Zugriff auf die Pixel einer Roblox-Schrift zur Laufzeit.

**Ergebnis der technischen Untersuchung:** EditableImage stellt Pixel-Lese- und
Schreibfunktionen bereit, TextService Schriftmessung und Familieninformationen.
Die geprüften öffentlichen APIs bieten keinen allgemeinen Export von TextLabel-
Glyphen als Pixel oder Kurven. Der Import von vorbereiteten Glyphenpixeln ist hier
als ausführbarer Versuch implementiert. Ein skalierbarer Glyphenatlas, Font-Outlines,
beliebige Zeichen, Ligaturen und Schriftformung bleiben eigene Umsetzungsschritte.
Diese Untersuchung belegt also eine mögliche Text-Rasterroute, keine allgemeine
SVG-Textunterstützung und kein Verbot anderer Implementierungswege.

Quellen: [EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage),
[TextService](https://create.roblox.com/docs/reference/engine/classes/TextService/FilterStringAsync).

## Laufzeitbericht und Lebenszyklus

Studio schreibt `SVG_S01_REPORT` bei fertiger Tafel, nach dem R-Test, bei Fehlern
und beim vollständigen Aufräumen. Enthalten: Größe, erzeugte/freigegebene/lebende
EditableImages, Höchststand, Aufbauzähler, Pixel-Rückleseprüfung, Viewport und Hashes.

- Fertige Tafeln: vier lebende EditableImages (zwei Schachbretter, zwei Inhalte).
- Größenwechsel: kurzzeitig zusätzliche Bilder, danach wieder vier.
- Nach Seitenabbau und dem Ende abgebrochener Jobs: `Live = 0` und
  `Created = Destroyed`. Der Bericht wartet auf diese Jobs.
- Nach R: 20 zusätzliche Aufbauten und wieder vier lebende Bilder. Zähler sind
  Allokationsbelege; sie ersetzen keine spätere Messung des GPU-/Clientspeichers.
- PixelReadback prüft direkt nach dem Upload einen Pixel pro Ebene. Die echte
  Roblox-Anzeige ist erst mit der Sichtprüfung bestätigt.
- Bei nicht möglicher Allokation oder Upload erscheint eine konkrete Fehlermeldung.
  Kein unsichtbarer Ersatz gilt als bestandene EditableImage-Prüfung.

## Lokale Prüfung

```text
python scripts/sync-svg-lab.py --check
node scripts/run-svg-tests.cjs
node scripts/run-svg-tests.cjs --optimized
node scripts/run-html-tests.cjs
node scripts/check-project.cjs
rojo build default.project.json -o build/StudioWorkspace.rbxlx
rojo build svg-lab.project.json -o build/SVGLab.rbxlx
rojo build htmlpage.project.json -o build/HTMLPage.rbxlx
```

Tests verwenden den tatsächlichen Raster- und Eigentümercode sowie einen
kontrollierten Scheduler für den tatsächlichen Lab-Controller. Geprüft werden
RGBA, Größen, Kanten, Glyphenrotation/-ausschnitt, Abbruch, fehlgeschlagene
Allokation/Upload/Zuweisung, 20 Lebenszyklen, konkurrierende Größenwechsel,
Aufräumen während eines Jobs und abgetrennte Tastaturverbindungen.
Asset-/GUI-Tests lokal sind Mocks. `build/svg-s01-preview.png` zeigt exportierte
Pixel des Luau-Rasters, keinen Studio- oder Browser-Screenshot.

## Noch vom visuellen Vergleich zu protokollieren

Der Nutzer hat den Gesamtvergleich mit „alles passt“ bestätigt. Einzelne
Geräteangaben und Laufzeit-Zähler wurden nicht separat übermittelt; die folgenden
Detailfelder bleiben deshalb offen und werden nicht aus der Bestätigung abgeleitet.

| Prüfung | Ergebnis |
|---|---|
| Client-/Studio-Version und Betriebssystemskalierung | offen |
| Browser und Font geladen | offen |
| 100-Pixel-Messlinie stimmt | offen |
| Farbfelder/Diagonale bei 240/480/960 px | offen |
| Normaler/gedrehter/ausgeschnittener Text | offen |
| PixelReadback in Roblox | offen |
| R-Test: vier lebende Bilder, kein stetiges Wachstum | offen |
| Abbau: Live 0, Created = Destroyed | offen |
