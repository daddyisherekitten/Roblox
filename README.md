# Roblox HTML Engine

Eine wiederverwendbare HTML-, CSS- und JavaScript-Engine in Luau für Roblox.
Ziel sind Verhalten und Darstellung möglichst nah am normalen Webbrowser.
Der erreichte Umfang und seine Grenzen stehen in den jeweiligen Fachprofilen;
ein registrierter Name bedeutet keine vollständige Browserkompatibilität.

## Einstieg

| Gesucht | Zuständige Datei |
| --- | --- |
| Dokumentation und Funktionsübersichten | [Dokumentationsindex](docs/README.md) |
| Gemeinsame Arbeitsregeln und nächster Arbeitsablauf | [Plan](PLAN.md) |
| Module, Datenfluss und Verantwortlichkeiten | [Architektur](docs/ARCHITECTURE.md) |
| Letzte Änderungen und Einstieg zum Weiterarbeiten | [Übergabe](docs/AI-HANDOFF.md) |
| Historische Reviews und Testnachweise | [Prüfprotokolle](docs/PROJECT-REVIEW.md) |

Aktueller Abgleich: [HTML-Parser und Attribute](docs/HTML-PARSER-ATTRIBUTES-20261006.md),
[CSS-Bestand und offene Fälle](docs/CSS-GAPS-20261006.md),
[Codepfade und sichere Optimierungen](docs/audit-2026-10-06/README.md).

## Starten

Im Projektverzeichnis:

```powershell
rojo serve default.project.json --port 34872
python scripts/serve-websites.py --port 8000
```

In Roblox Studio das Rojo-Plugin mit `localhost:34872` verbinden.
Ein bereits laufender passender Server wird weiterverwendet.
Nach einem Demo-Wechsel **Stop → Play**; laufende PlayerScripts sind Kopien.
Nach Änderungen am Rojo-Projektbaum den Server neu starten und das Plugin
erneut verbinden; ein alter Server kann noch entfernte Module erwarten.
Rojo ist durch [aftman.toml](aftman.toml) auf Version 7.7.0 festgelegt.

[StudioDemoConfig](examples/StudioDemoConfig.luau) wählt ausschließlich die Demo,
standardmäßig `ActiveDemo = "HTMLPage"`. Beide HTML-Projekte starten jetzt
`DeepWiki`: der vollständige Webseitenbestand aus Welcome to the Game II mit
60 Site-Einträgen, allen drei Wikis und 175 HTML-Adressen. 160 Dokumente sind
Originale; 15 Adressen haben gekennzeichnete Inhaltsplatzhalter. Der Einstieg ist
[Wiki I](http://localhost:8000/wiki1/index.html), daneben
[Wiki II](http://localhost:8000/wiki2/index.html) und
[Wiki III](http://localhost:8000/wiki3/index.html).
Die native Home-Seite bleibt über das Browsermenü erreichbar. Jedes Browserfenster
zeigt genau eine Seite; Tableiste und Tab-Erstellung sind entfernt.
Im Standardprojekt erscheint sie in einem Fenster des unabhängigen `WindowManager`
mit der separaten Browseroberfläche. Die Verbindung steht im LocalScript;
die drei Kernmodule importieren einander nicht.
Fehlt `WindowManager` oder `Browser`, startet dasselbe `HTMLPageDemo` automatisch
dieselbe konfigurierte Seite im internen HTML-Fenster. Dafür ist kein Attributwechsel nötig;
optionale Module werden nach der initialen Replikation direkt geprüft.
Direkt unter `ReplicatedStorage` liegen nur `HTMLEngine`, `Browser` und
`WindowManager`. Die optionalen Verbindungen liegen unter `Browser.Integration`,
Demo-Helfer unter `HTMLEngine.Examples` und bestehende Tests unter `HTMLEngine.Tests`.
`WaylinePage` und die zusätzliche Pocket-Journal-Seite sind entfernt.
Frühere sichtbare Seiten sind ausschließlich als Regressionseingaben archiviert.
Das Standardprojekt enthält außerdem die Schrift-Labore sowie den
Speicher-Serveradapter; separate Projektdateien bleiben für gezielte Builds erhalten.
Die Font-LocalScripts liegen unter `StarterPlayerScripts/Fonts`.
`HTMLPageDemo` bleibt direkt unter `StarterPlayerScripts` und verbindet Browser
und HTML. Das frühere SVG-Labor samt Vergleichsseiten ist entfernt; die SVG-
Engine und ihre Regressionen bleiben erhalten.
Der WindowManager enthält jetzt das Fenstersystem aus `haha.rbxmx`, einschließlich
Schatten, Animationen, Snap-Vorschau und modalen Meldungen. Seine Host-API steht im
[Fensterprofil](docs/WEBSITES.md#eigenständige-fenster--14-oktober-2026).

Die Browserquellen in [examples/websites](examples/websites) sind maßgeblich.
[wttg2-site-publisher.cjs](scripts/wttg2-site-publisher.cjs) erzeugt die Module unter
[Websites](src/HTMLEngine/Websites). Die geprüfte vollständige Auswahl steht in
[wttg2-full-selection.json](scripts/data/wttg2-full-selection.json), Routen und Hashes
in [wttg2-full-catalog.json](scripts/data/wttg2-full-catalog.json). 456 Originalbilder
liegen zusätzlich als verlustfreie, bei Bedarf entpackte Pixelpakete vor. Die
eigenen Darknet-Seiten sind aus dem aktiven Katalog und Webserver entfernt.
Umfang und Pflege stehen in
[WEBSITES](docs/WEBSITES.md#vollständiger-originalspiel-port--19-oktober-2026). Weitere Ressourcenoptionen stehen in
[WEBSITES.md](docs/WEBSITES.md). Frühere sichtbare Testseiten liegen ausschließlich
als Regressionstestdaten in [retired-websites.json](tests/fixtures/retired-websites.json).
Die am 16. Oktober entfernten 15 Seiten einschließlich ihrer generierten Module
liegen in [retired-window-pages-20261016.json](tests/fixtures/retired-window-pages-20261016.json);
die native Fensterdemo in [retired-native-window-demo-20261016.json](tests/fixtures/retired-native-window-demo-20261016.json).
Das frühere CSS Atelier bleibt in [tests/fixtures/css-atelier](tests/fixtures/css-atelier).
Auf dem PC erhält der Fenstertitel nur
bei maximiertem Fenster 200 px linken Abstand; die Navigationspfeile bleiben stehen.

## Verwenden

```lua
local Engine = require(game.ReplicatedStorage.HTMLEngine)
local page = Engine.mountHTML(targetFrame, html, options)
-- Beim Verlassen der Seite:
page:Destroy()
```

Die öffentliche Schnittstelle steht in [init.luau](src/HTMLEngine/init.luau).
HTML/CSS/JavaScript bleiben Standard-Webcode; Ressourcen wie Bilder, Fonts und
Audio werden über die dokumentierten Hostoptionen zugeordnet.

### Wayline browser

[Wayline](src/Browser/init.luau) is an independent in-game browser with a simple,
Chrome-inspired shell: a plain toolbar, one rounded address field
and a narrow bookmarks bar. Home uses centered search and circular shortcuts.
It fills a supplied content Frame and creates no window frame or ScreenGui.
Native Home, local Search, Bookmarks, History,
Settings and Guide pages work without HTMLEngine or WindowManager. Icons use a
tinted image atlas exclusively. Browser objects remain `Active = false`; one custom
mouse/touch router owns controls, scrolling, explicit text focus and drag capture.
No browser keyboard shortcuts are installed.

```lua
local Browser = require(game.ReplicatedStorage.Browser)
local browser = Browser.mount(contentFrame)
browser:Navigate("wayline://home")
browser:SetFocused(true)
browser:SetVisible(true)
-- Retain before closing when the host should restore the live session.
local snapshot = browser:ExportSession()
browser:Destroy()
```

The host owns geometry, focus, visibility, stacking and close. The optional
`CanReceivePointer(position)` callback handles host overlays and other windows.
`SetNavigationVisible(false)` hides only Back, Forward and Reload, retaining
the address field. The supported minimum content area is 480 by 360 pixels.
Light/Dark themes, three accent colors, editable Home, twelve quick links,
bookmark folders and global history share the same native controls and cleanup
rules. Each mount owns one document. `browser:Open(address)` navigates that
document; there is no tab strip, tab search or tab-creation API.

| Project | Modules and startup |
| --- | --- |
| [default.project.json](default.project.json) | Wayline + HTML + separate WindowManager through `HTMLPageDemo` and application adapters |
| [browser.project.json](browser.project.json) | Native Wayline with session-only data; no HTML engine or window module |
| [htmlpage.project.json](htmlpage.project.json) | HTML alone with `BrowserEnabled = false`; DeepWiki and built-in fallback windows, no browser or window module dependency |

All supplied projects keep browser settings, Home, bookmarks, history and page
storage in memory for the current play session. No DataStore service is mapped,
no saved browser profile is loaded, and a new play session starts fresh. Windows
in the same application still share their current browser data and origin storage.
The optional persistence source APIs are inactive unless explicitly installed by
another host; the demo disables them. Disabled no-op scripts at the two previous
bootstrap names retire older Studio installations without touching other game scripts.

The exact Explorer mapping, host contract, pointer coordinate convention,
native page registration and session-only storage setup are maintained in
[WAYLINE](docs/WAYLINE.md). The optional [HTML binding](src/Browser/Integration/HTMLBinding/init.luau)
continues to mount the registered local website catalog. HTML window handles,
messages, document access and fullscreen remain separate adapter capabilities;
HTML still works alone and arbitrary external websites are not implied to work.
The [website profile](docs/WEBSITES.md#wayline-browser--15-october-2026) describes
that boundary. The project backup before replacement remains outside this
workspace in `Roblox-Backups`.

Die Rojo-Projekte mit `HTMLEngine.Tests` schließen die beiden nativen
Referenzdateien `tests/fixtures/url-record-browser.json` und
`tests/fixtures/video-presentation-browser.json` vom Studio-Sync aus. Ihre
absichtlichen einzelnen UTF-16-Surrogate kann Rojo nicht als JSON-Modul lesen.
Die Rohdateien bleiben unverändert erhalten und werden von den CLI-Tests
`URLRecords`, `VideoPresentationDOM` und `VideoPresentationRendering` vollständig
verwendet; die Luau-Tests bleiben synchronisiert.

Das entfernte SVG-Labor liegt ausschließlich als komprimierte Regressionseingabe
in [svg-regressions.zip](tests/fixtures/svg-regressions.zip). Dieses Archiv ist
ebenfalls vom Studio-Sync ausgeschlossen. Es enthält keine aktive Demo und
wird vom [SVG-Testadapter](scripts/svg-fixtures.cjs) nur in CLI-Prüfungen gelesen.

## Prüfen

```powershell
python scripts/check-documentation.py
node scripts/check-project.cjs
node scripts/run-html-tests.cjs
node scripts/run-browser-tests.cjs
node scripts/export-javascript-api.cjs --check
rojo build default.project.json -o build/engine.rbxlx
```

Bei Codeänderungen die betroffenen Regressionen und nötigen gemeinsamen Checks
ausführen. Der Dokumentationsprüfer kontrolliert Zuständigkeiten, lokale Verweise
und die unveränderte Sicherung der früheren Dokumente. FPS sowie den nativen
visuellen und hörbaren Studiovergleich übernimmt Tobias. Tests mit Ersatzobjekten
beweisen keine Pixelgleichheit oder tatsächlichen Assetrechte.

## Frühere Dokumentation

Die bisherige große README und alle anderen Dokumente vor der Neuordnung vom
6. Oktober 2026 sind vollständig [gesichert](docs/history/2026-10-06/README.md).
Der aktuelle Einstieg enthält keine zweite, konkurrierende Funktionsliste.
