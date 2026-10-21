# HTML- und CSS-Stresstest

Die [Hauptseite](../examples/websites/html-css-stress/index.html) ist jetzt ein kompakter Einstieg. Sie verlinkt sieben HTML-/Kombinationsproben und acht CSS-Kategorien. Jede Unterseite hat eine eigene URL, `index.html`, `styles.css` und ein aus denselben Dateien erzeugtes Roblox-Website-Modul. Ein Unterseitenlink funktioniert auch direkt in Studio; die Übersicht lädt keine 1.013 CSS-Karten mehr. Die Browserdateien sind bytegleich mit den generierten Roblox-HTML-/CSS-Strings, sodass dieselbe Kategorie direkt verglichen werden kann. Der Zurück-Pfeil führt zur zuletzt besuchten Seite; beim direkten Öffnen verwendet er die Kategorienübersicht als Fallback.

```powershell
python scripts/serve-websites.py
```

Danach ist die [Übersicht](http://localhost:8000/html-css-stress/index.html) erreichbar. Die Hauptübersicht `main` verlinkt sie ebenfalls.

## Kategorien

| Bereich | Inhalt |
| --- | --- |
| HTML & Semantik | Text, Listen, Ruby, Details und HTML-Elementindex |
| Formulare & Tabellen | Eingaben, Validierung, Dialog und Datentabelle |
| Medien & Komponenten | Bild, Audio, Video, Canvas, SVG, Template und Custom Element |
| Layout & Scrollen | 120 verschachtelte Karten, Grid/Flex, Container und Scrollen |
| Effekte & Bewegung | Filter, Masken, Blend, 3D, Animation und Selektoren |
| Typografie | kombinierte Schrift- und Textregeln |
| Last & Messung | 48 Basiskarten, bis zu sieben zusätzliche Kopien und optionale Browser-Messung |
| Acht CSS-Kategorien | Layout, Flächen, Text, Animation, Scrollen, Bedienung, SVG und weitere Eigenschaften |

Der datierte Snapshot umfasst **113 HTML-Elementnamen** und **1.013 CSS-Eigenschaftsnamen**. Alle 1.013 Karten stehen genau einmal auf einer CSS-Unterseite. 526 sind Verhaltensproben, darunter die 370 Einträge des Engine-Katalogs; 487 prüfen Syntax oder Reset. Die Namen stammen aus der [WHATWG-Elementtabelle](https://html.spec.whatwg.org/multipage/indices.html#elements-3), dem [W3C-CSS-Index](https://www.w3.org/Style/CSS/all-properties.en.html), [MDN Data](https://github.com/mdn/data/blob/main/css/properties.json) und dem Engine-Katalog. Details stehen im [Abdeckungsmanifest](../examples/websites/html-css-stress/coverage.json).

Der Katalog beweist weder alle möglichen CSS-Werte noch vollständige Browser- oder Roblox-Unterstützung. Die Syntaxanzeige auf CSS-Seiten verwendet `CSS.supports()` im Browser. Statische HTML-/CSS-Proben benötigen kein JavaScript; lokale Suche und Benchmark benötigen Browser-JavaScript. Audio, Video und Untertitel liegen als lokale Testdateien bei den Seiten. Roblox benötigt für Medien passende Asset-Resolver.

## Erzeugen und prüfen

Der Generator verwendet `scripts/stress/page.html.in`, `complex.html.in`, `base.css.in`, `complex.css.in`, `catalog.py`, `history.js` und `harness.js`. Er zerlegt die ausgeschriebenen Proben in Kategorien und synchronisiert alle Roblox-Module. Browser- und Robloxquellen jeder Seite werden bytegenau verglichen.

```powershell
python scripts/build-stress-page.py
python scripts/check-stress-page.py
node scripts/run-html-tests.cjs StressCatalog
node scripts/check-project.cjs
rojo build default.project.json -o build/roblox-html-engine.rbxlx
```

Der Browser-Test öffnet alle Unterseiten, zählt die CSS-Karten, prüft Suche, native Formulare, Medien und einen echten fünfsekündigen Benchmarklauf:

```powershell
node scripts/test-stress-browser.cjs
```

Für den Browser-Test muss Playwright erreichbar sein; `NODE_PATH` kann auf ein installiertes `node_modules` zeigen. `BROWSER_CHANNEL` wählt bei Bedarf einen anderen Chromium-Kanal. Der Test startet einen eigenen kurzlebigen HTTP-Server und schreibt `build/stress-browser-report.json`.
