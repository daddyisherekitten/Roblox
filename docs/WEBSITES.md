# Website-Seiten

## Vollständiger Originalspiel-Port — 19. Oktober 2026

Der aktive Katalog deckt sämtliche **175 HTML-Dateien** des installierten Spiels ab:
60 echte Site-Einträge, drei Wikis und 30 originale tote Links. Die zusätzlichen
15 Archivdokumente ohne Unity-Seitenreferenz sind ebenfalls registriert. 160
HTML-Dokumente werden aus den Originalen übernommen. 15 Adressen mit sexualisierten
Minderjährigen beziehungsweise altersunklarem Sexualinhalt verwenden ausdrücklich
gekennzeichnete neutrale Platzhalter; 24 zugehörige Bilder werden nicht übernommen.
Die eigenen Darknet-Seiten sind entfernt und ausschließlich als nicht ausgelieferte
Regressionseingaben in
[retired-authored-darknet-20261019.json](../tests/fixtures/retired-authored-darknet-20261019.json)
gesichert.

Einstiege: [Wiki I](http://localhost:8000/wiki1/index.html),
[Wiki II](http://localhost:8000/wiki2/index.html),
[Wiki III](http://localhost:8000/wiki3/index.html). Beide HTML-Projekte starten
`DeepWiki`; die optionalen Browser-/Fenstermodule bleiben unabhängig.

Das Original wählt je Spielrunde zufällig 15 echte und zehn tote Ziele pro Wiki.
Der vollständige Port verteilt stattdessen deterministisch **20 eindeutige echte
Einträge je Wiki**, zehn tote Einträge und zwei Verweise auf die anderen Wikis.
Damit sind alle 60 Sites erreichbar. Die tatsächlichen Kandidatenpools 59/60/59
bleiben in den Metadaten separat dokumentiert; dies ist keine beobachtete Spielrunde.

[wttg2-full-selection.json](../scripts/data/wttg2-full-selection.json) hält Archivhash,
Originalreferenzen, alle Dokumente und die Ressourcenfreigabe fest.
[wttg2-full-catalog.json](../scripts/data/wttg2-full-catalog.json) beschreibt die
ausgelieferten Dateien samt Hashes, Einschränkungen und bekannten Originalverweisen.
Geteilte Skriptquellen liegen einmalig unter `Websites/Assets/HostScripts`; jedes
Seitenmodul bindet nur seine tatsächlichen Skript-, CSS- und Bildabhängigkeiten ein.
Die Cursorhooks schreiben keine Rootstyles. Alle drei Wikis bleiben unter dem
normalen JavaScript-Budget, ohne dessen Erhöhung.

**Bilder und Grenzen:** 456 freigegebene Originalbilder werden verlustfrei als
469 eindeutige Pixelmodule mit 476 Kachelverweisen verpackt. Alle Pixel wurden
rekonstruiert, 98 PNGs zusätzlich unabhängig mit Pillow verglichen. Der Native-Host
dekomprimiert bei Bedarf über `EncodingService`; separate Bild-Asset-IDs sind nicht
erforderlich. Im Browser bleiben GIFs animiert, in Roblox sind 23 animierte GIFs
derzeit auf Bild 0 begrenzt. Native Texturgrenzen und Schrift-Fallbacks bleiben
bestehen. Bereits im Originalarchiv fehlende Ressourcen sowie externe Dienste
werden im Katalog ausgewiesen und nicht erfunden.

Die historische Beichtseite erhält lokal deterministische GET-/POST-Antworten;
es werden keine Inhalte an fremde Empfänger übertragen. Das originale
TheThree-Skript enthält einen unvollständigen Attributselektor. Nur dessen fehlende
Schlussklammer wird dokumentiert repariert; die ursprünglichen Hashes bleiben
erhalten. Falsche Auswahl, Reset, alle 18 richtigen Schritte und der Übergang zu
Wiki III sind geprüft. Tote Links zeigen die originale `/NotFound/index.html`.

Neuer Import aus dem unveränderten installierten Spiel erzeugt zunächst Staging:

```powershell
node scripts/import-wttg2-wiki.cjs "<Spielverzeichnis>" --output build/wttg2-full-rebuild
node scripts/test-wttg2-runtime.cjs
node scripts/test-wttg2-browser.cjs
node scripts/run-html-tests.cjs FullGameWikiNavigation HTMLPageStartup WikiHoverNavigation
```

Die kanonischen Regressionen prüfen auch die früheren eigenen Seiten ausschließlich
aus ihren gesicherten Eingaben. Nachweise für den vollständigen Port liegen unter
`build/wttg2-full-20261019`. Die folgenden Abschnitte beschreiben ältere Stände.

## Das Nachtverzeichnis — 19. Oktober 2026

Früherer Einstieg: [Das Nachtverzeichnis](http://localhost:8000/verzeichnis/index.html),
Modul `Nachtverzeichnis`. Beide HTML-Projekte wählen denselben Inhalt, einschließlich
des unabhängigen HTML-Fensterhosts ohne Browser oder WindowManager.

Die 15 eigenen Websites bilden ein fiktionales verborgenes Netz: anonyme Postfächer,
geschlossene Boards, interne Leaks, zurückgezogene Bild-/Tonarchive, Relay-Verzeichnisse
und fragwürdige Dokumentendienste. Sie haben unterschiedliche alte Weblayouts,
Betreiberstimmen und Querverweise. Mit dem Verzeichnis und neun Unterseiten gibt
es 25 Dokumentrouten. Wiederkehrende Kennungen verbinden die Einträge.

Browserquellen unter `examples/websites` sind maßgeblich. Zum Aktualisieren:

```powershell
node scripts/publish-nightweb.cjs
node scripts/run-html-tests.cjs NightwebRuntime NightwebNavigation NightwebIllustrations HTMLPageStartup
node scripts/test-nightweb-browser.cjs
```

[nightweb-sites.json](../scripts/data/nightweb-sites.json) enthält Titel, Routen und
Interaktionsproben; [nightweb-catalog.json](../scripts/data/nightweb-catalog.json)
hält die erzeugten Dateien und Hashes fest. Module laden nur eigene CSS-/JS-Quellen
und lokale SVGs, ohne jQuery oder Unity-Hosthooks. Normale HTML-Links und lokale
Formular-/Archivaktionen funktionieren in Browser und Engine. Es werden keine
externen Dienste, Nachrichtenempfänger oder Kameraendpunkte angesprochen.

Die früheren 35 Originalspiel-Dokumente, deren Bilder und privaten Pixelmodule
sind nicht mehr registriert oder erreichbar. Eine Wiederherstellungskopie liegt
unter `build/retired-original-sites-20261019/previous-sites.zip`. Nur die
[gesicherte Wiki-Hover-Eingabe](../tests/fixtures/retired-wiki-hover-20261019.json)
bleibt außerhalb der Auslieferung für die bestehende Engine-Regression erhalten.
Die folgenden Originalspiel-Abschnitte beschreiben den früheren Stand.

## Wiki I: Originalseiten — 19. Oktober 2026

Der frühere Katalog enthielt die originale erste Deep-Wiki-Seite aus dem lokal
installierten Welcome to the Game II und eine feste Auswahl von **15** tatsächlichen
Wiki-I-Kandidaten. Im Spiel werden pro Runde 15 echte Ziele und zehn tote Links
zusammengestellt; die Auswahl hier ist fest und keine beobachtete Spielrunde.
Die 15 Ziele haben zusammen 34 HTML-Dokumente. Mit dem Wiki-Einstieg sind
35 Routen registriert. Frühere eigene Webseiten bleiben entfernt.

Einstieg: [Wiki I](http://localhost:8000/wiki1/index.html), Roblox-Modul `DeepWiki`.
`default.project.json` und `htmlpage.project.json` wählen beide diese Seite.
Ohne Browser oder WindowManager startet das LocalScript denselben Inhalt im
internen HTML-Fenster. Die 19 Unterseiten sind navigierbar, erscheinen aber nicht
zusätzlich als Home-Kacheln des Browsers.

Die Auswahl umfasst Fortune Cookie, Thanks For Visiting, The Black Waves,
St Louis Arch, Red Triangle, Fifty Seven, Number Station, IAMHERE, YOU THERE?,
Eye, THANATOS, The Grey, The Hall, We Rock und Your Data. Zehn originale tote
Einträge führen bewusst zu einer fehlenden lokalen Adresse.

Die Browserquellen, Stylesheets, Bilddateien und eine Schrift stammen aus
`WTTG2_Data/Resources/browser_assets`. Die Spieldatei wird ausschließlich lesend
geöffnet. Der Publisher injiziert eine Cursorregel, Konfiguration und einen
Hostadapter vor die ursprünglichen Skripte. `LinkClick` und `SiteClick` ersetzen die Unity-Hooks,
kanonisieren bekannte Unterseiten auch bei abweichender Großschreibung und
speichern Besuchsmarkierungen. `.ann`-Aliase sind stabile Port-Konfiguration;
das Original erzeugt Adressen je Spielstand. Schlüssel/Hashes, Hotspots und die
eigentliche Spiellogik werden nicht erfunden. Hook-Ereignisse stehen für eine
spätere Spielanbindung bereit.

Die originalen Hover-Handler rufen Unity-Cursorhooks auf. Der Hostadapter lässt
`LinkHover` und `LinkOut` als kompatible Funktionen bestehen; die statische Regel
`[onmouseover*="LinkHover"] { cursor: pointer; }` setzt den Cursor direkt am
jeweiligen Ziel, auch bei dynamisch aktivierten Hotspots. Es gibt keine
Style-Schreibzugriffe am Dokument pro Hover. `WikiHoverNavigation` prüft alle
25 Links mit tatsächlichen Eingabeereignissen: keine Styleauflösung,
Selektorprüfung, Generated-Content-Auswertung, Box-Neuzeichnung oder Layoutarbeit
bei Eintritt/Austritt sowie funktionierende Klicknavigation im gemounteten
Browser-/HTML-Pfad. Legitime geerbte Cursoränderungen durch andere Seitenskripte
bleiben separat getestet und erhalten Link-GUIs und Hintergrundtexturen.

Der normale Browser verwendet originales jQuery 3.2.1. Die Engine verwendet
einen kleinen Adapter ausschließlich für die hier tatsächlich gebrauchten
jQuery-Methoden. Ihre normalen Script-/Lexerbudgets bleiben unverändert.
Die 51 Bilder sind zusätzlich als verlustfrei komprimierte RGBA-Kacheln unter
`Websites/Assets` verpackt. Die Engine lädt sie bei Bedarf über `EncodingService`
und die bestehende SVG-Rasterpipeline; einzelne Roblox-Bilduploads entfallen.
`SVGs[source]` akzeptiert dafür neben SVG-Text einen vertrauenswürdigen
Hostdeskriptor `{SVG=markup, ResolveImage=function}`. Der Callback bleibt
außerhalb von HTML-Attributen und Seitenskripten; er liefert validierte
`{Width, Height, Pixels=buffer}`-Ressourcen.

**Grenzen der Originaltreue:** Im lokalen Browser bleiben die sechs GIFs
animiert. Der Roblox-Pixelpack enthält derzeit deren erstes Bild. Nicht
verfügbare Originalschriften verwenden native Ersatzschriften; das Wiki nutzt
Arial als Sans-Fallback. Die Rendertexturen haben die bestehende Grenze von
1024 Pixeln pro Achse. Im Spiel separat hinterlegte Hintergrundmusik ist nicht
Teil des HTML-Archivs und hier nicht angebunden. Ein pixelidentischer nativer
Studio-Lauf wird damit ausdrücklich nicht behauptet.

Reproduktion aus derselben lokalen Spielinstallation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/decode-wttg2-images.ps1 -ArchivePath "<Spiel>/WTTG2_Data/Resources/browser_assets" -RegistryPath build/wttg2-research-20261019/original-browser-assets.json -SelectedPath build/wiki1-port-20261019/research/selected-wiki1.json -OutputDirectory build/wiki1-port-20261019/decoded
node scripts/pack-wttg2-images.cjs
node scripts/wttg2-site-publisher.cjs --workspace . --registry build/wttg2-research-20261019/assets/browser_assets-registry.json --archive "<Spiel>/WTTG2_Data/Resources/browser_assets" --selected scripts/data/wttg2-selection.json
```

Der vollständige Import kann auch direkt mit
`node scripts/import-wttg2-wiki.cjs "<Spielverzeichnis>"` ausgeführt werden.
Er prüft Archivstruktur und SHA-256 gegen den untersuchten Spielstand und
verwendet die persistente Auswahl unter `scripts/data/wttg2-selection.json`.

Der [persistente Katalog](../scripts/data/wttg2-catalog.json) hält Routen und
Hashes fest. Prüfungen: `test-wttg2-image-pack.cjs` rekonstruiert sämtliche
Originalpixel, `test-wttg2-browser.cjs` prüft alle 35 Dokumente im isolierten
Chromium. Die kanonischen ImageSources-/SVG-Regressionen prüfen auch Alpha,
CSS-Hintergründe und Abbau. Native Roblox-Ausführung bleibt eine eigene Abnahme.

## Frühere Seiten

Browser, HTML-Engine und WindowManager bleiben eigenständige Module. Die
folgenden Seitenbeschreibungen dokumentieren frühere Regressionseingaben und
gehören nicht zum aktiven Katalog.

Die vor dem Nightweb-Auftrag bestehenden Seiten sind bytegenau in
[retired-nightweb-pages-20261019.json](../tests/fixtures/retired-nightweb-pages-20261019.json)
für bestehende Engineprüfungen erhalten. Die 15 am
16. Oktober 2026 entfernten Seiten und ihre generierten Roblox-Module bleiben bytegleich in
[retired-window-pages-20261016.json](../tests/fixtures/retired-window-pages-20261016.json),
die frühere native Fensterdemo in
[retired-native-window-demo-20261016.json](../tests/fixtures/retired-native-window-demo-20261016.json).
Unit- und Integrationstests verwenden diese Regressionseingaben weiter.
Die bereits früher entfernten Seiten bleiben unverändert in
[retired-websites.json](../tests/fixtures/retired-websites.json); das CSS Atelier mit
Font und Lizenz bleibt unter `tests/fixtures/css-atelier`.

| Frühere Browserdateien | Früheres Roblox-Modul | Historischer Inhalt |
| --- | --- | --- |
| `examples/websites/annoying-site` | `AnnoyingSite` | Gewünschter Nachbau mit bewegten Popups, Meldungen, Vollbild, Verlauf/URL, virtueller Kamera, Video und Ton |
| `examples/websites/window-check` | `WindowCheck` | Eine aktuelle Prüfseite für Fenster, Tabs, Dialoge, Lebenszyklus und den internen HTML-Fallback |
| `examples/websites/main` | `Main` | Spiele-Hauptseite mit Memory, Hangman, Einführung und Spielelinks |
| `examples/websites/memory` | `Memory` | Spielbares Memory mit 6/8/12 Paaren, Mischen, Zug-/Paarzähler, Uhr, Pause, Tastaturbedienung, Ergebnis und persönlichem Rekord |
| `examples/websites/hangman` | `Hangman` | Wortspiel mit vier Kategorien, 32 deutschen Wörtern, sechs Fehlversuchen, Tastatur/Alphabetbuttons, einem Tipp pro Wort und persönlicher Statistik |
| `examples/websites/bytebude` | `Bytebude` | Retroportal mit Spielhalle, Reitern, lokalem Gästebuch, Umfrage, Besuchszähler und Tag-/Nachtmodus |

## The Annoying Site — 16. Oktober 2026

Die [Seite](http://localhost:8000/annoying-site/index.html) ist ein eigener Nachbau,
inspiriert von [Feross' Original](https://github.com/feross/TheAnnoyingSite.com).
Sie verwendet den bereits implementierten HTML-/Fensterumfang. Ein normaler Start
öffnet zwei Zusatzfenster, die alle 100 ms zufällig springen und mit `focus()`
wieder in den Vordergrund geholt werden; weitere sind über die Leiste möglich. Meldungen,
Elementvollbild, Verlauf/wechselnde URL-Fragmente und eine ausdrücklich angefragte
virtuelle Kamera verwenden die vorhandenen Engine-APIs. `window.screen` liefert
die tatsächliche Arbeitsfläche des jeweiligen Fensterhosts, unabhängig von der
Größe des Hauptfensters; die Bewegung nutzt daher beide Achsen. Die kompakte Popupansicht
ist dieselbe Datei mit `?child=1`; es werden keine neuen Testunterseiten angelegt.

„Stopp“ beendet Timer, Ton/Video, Kameratracks und die zugehörigen Popups.
Der Schließen-Hinweis gilt nur für die laufende Hauptseite. Fehlende oder
abgelehnte Medien-/Fenster-/Vollbildfunktionen erscheinen als Status auf der Seite.
Beim Start erscheint automatisch die Kameraabfrage. Bis zur Entscheidung bleibt
die Hauptseite mit dem Dialog im Vordergrund; die Popups bewegen sich weiter.
Erst Zulassen startet das Bild. Der Kameraknopf stoppt es oder fragt erneut an;
gespeicherte Entscheidungen werden vom Host wiederverwendet.

Roblox verwendet Audio **93424997719572** („Zinc“) und Video **5608384572**
(„Particle Disco Light Experience“) aus [options.json](../tests/fixtures/retired-nightweb-pages-20261019.json).
Die normale Browseransicht verwendet kleine lokal erzeugte Vorschau-Medien;
[Herkunft und Zuordnung](../tests/fixtures/retired-nightweb-pages-20261019.json) sind ausdrücklich getrennt.
Der Sound wird über die vorhandene Audioelement-Anbindung gesteuert. Dies ist
keine neue `AudioContext`-/Web-Audio-Implementierung. Sprachausgabe, Pointer Lock,
Bild-in-Bild, zusätzliche Geräteauswahl, Druck-/Download-/Zwischenablageaktionen,
Abmeldungen bei echten Webseiten und Browser-Themewechsel gehören nicht zu
diesem ausdrücklich auf vorhandene Funktionen begrenzten Seitenauftrag.

## Aktuelle Fensterprüfung — 16. Oktober 2026

[WindowCheck](http://localhost:8000/window-check/index.html) und seine
[Browserquelle](../tests/fixtures/retired-nightweb-pages-20261019.json) verwenden Standard-
HTML/CSS/JavaScript. Hauptansicht, neuer Tab (`?view=tab`) und benanntes Popup
(`?view=popup`) verwenden dieselbe HTML-Datei; es gibt keine zusätzliche Testunterseite.
Sieben kleine Abschnitte führen durch die zuletzt geänderten Funktionen:

- Normal/Maximiert, Minimieren/Wiederherstellen und auf dem PC 200 px Abstand
  links von Titel und Tabs ausschließlich bei maximiertem Fenster. Pfeile und
  Adressleiste behalten ihre Position.
- Neue Tabs, Öffnungs-/Schließanimation, Drag-Reihenfolge, kleine Tabs, rechter
  sichtbarer Tab und Schließen des Fensters beim letzten Tab.
- Benanntes Popup öffnen/wiederverwenden, fokussieren, um 25/15 px verschieben,
  auf 520 × 420 px ändern, seinen Zustand abfragen und schließen.
- `alert`, `confirm` und `prompt` mit sichtbaren Rückgaben.
- Erhaltene Notiz, optionale `beforeunload`-Warnung, Reload und Sichtbarkeit.
- Elementvollbild mit beobachtbarer Wiederherstellung.
- Kamera-/Mikrofonberechtigung einzeln oder gemeinsam, Zulassen/Blockieren/Abbruch
  und `PermissionStatus`; konfigurierte virtuelle Kamera mit Start/Stopp und
  Livebild ohne Videobedienelemente. Mikrofonton bleibt offen; siehe
  [Medienprofil](MEDIA.md#kamera--und-mikrofonberechtigungen--16-oktober-2026).

Ohne WindowManager startet dasselbe LocalScript nach Stop → Play den internen
HTML-Fensterhost. Dieser besitzt einen einfachen Rahmen; die vollständige
Browser-Taboberfläche gehört weiterhin zum optionalen Browsermodul. Auch das
HTML-only-Projekt kann dieselbe Seite über `Website=WindowCheck` starten;
seine aktuelle Startseite ist `AnnoyingSite`. Die Bedienprobe ersetzt weder die
Fachprofile noch die native Studio-Abnahme.

## Entferntes SVG-Labor — 14. Oktober 2026

Die früheren Seiten unter `examples/svg-tests` und das Blumenbeispiel sind
entfernt. `SVGLabDemo`, `examples/SVGLab`, die zugehörigen Generatoren und
`svg-lab.project.json` gehören nicht mehr zum aktiven Projekt. Die unveränderten
Quellen bleiben ausschließlich als [Regressionseingaben](../tests/fixtures/svg-regressions.zip)
für die bestehenden CLI-Prüfungen erhalten; das Archiv wird nicht nach Studio
synchronisiert. Die SVG-Engine und SVGs der aktuellen Websites bleiben bestehen.

Die Font-Demos liegen in den Standard-/Fontprojekten unter
`StarterPlayerScripts/Fonts`. Der direkte LocalScript `HTMLPageDemo` startet
im Standardprojekt weiterhin Browser und HTML gemeinsam.

Nachweis: `build/remove-svglab-html-regression-full16.log` besteht mit acht
betroffenen Suiten. Der vollständige SVG-Funktionslauf besteht in
`build/remove-svglab-engine-graph-literal-full16.log`; der bisherige CLI-Runner
erhält dafür seine fehlenden DOM-/Selektorabhängigkeiten aus dem kanonischen
Modulgraphen. Fünf ursprüngliche Browserlogikprüfungen verwenden dieselben
archivierten Quellbytes und bestehen ebenfalls. Die Projektprüfung bestätigt
1121 Luau-Dateien, 219 JS-Dateien, 22 Python-Dateien, 56 HTML-Dateien und sieben
Rojo-Projekte. Drei betroffene Builds und der API-Abgleich bestehen. Das Archiv
ist sowohl in Python als auch im Node-Testadapter byte-/hashgeprüft; alle
ursprünglichen Assertions und alte Fehlerbelege bleiben erhalten.

## Wayline browser — 15 October 2026

Aktualisierung vom 19. Oktober: Der Browser zeigt pro Fenster genau ein Dokument.
Tableiste, Plus, Tabsuche, Tabmenüs und die öffentliche Tab-Erstellung sind
entfernt. `browser:Open(address)` navigiert das vorhandene Dokument. Zusätzliche
HTML-Kontexte öffnen über den optionalen Fensterhost ein eigenes Fenster;
benannte Fenster bleiben wiederverwendbar. Alte Sitzungen migrieren ausschließlich
die zuvor aktive Seite. Favoriten, Verlauf und Einstellungen bleiben erhalten.

[Wayline](../src/Browser/init.luau) replaces the former Chrome-inspired shell with
an independent native Roblox browser. Home, local Search, Bookmarks, History,
Settings and Guide are native pages using `wayline://` addresses. They work without
HTML or a window engine. Native pages are Luau, not generated HTML
website modules and not additions to `engine.Websites`.

The single detailed installation/API reference is [WAYLINE](WAYLINE.md). It defines
the Explorer tree, supplied content Frame, host focus/visibility/pointer contract,
GUI-inset coordinate convention, resource ownership, native page registration and
server persistence. The three project modes remain separate: the default project
connects Wayline, HTML and WindowManager; the browser project has neither engine;
the HTML-only project mounts Engine without either optional module.

Wayline has one document with a full navigation stack, twelve customizable quick
links, stable bookmark/folder organization and five hundred global visits.
Reloading, restoring and failing
navigation do not create visits. Back/Forward retain serializable native page state;
Reload resets that page's transient state and scroll. The optional bookmarks bar
shows root bookmarks and folders with overflow on Home and follows its shared setting.
No browser keyboard shortcuts are installed. Figma-exported image icons share one
atlas, without legacy glyph fallbacks, and every browser-owned GuiObject remains
`Active = false`.

`browser:SetNavigationVisible(false)` hides only Back, Forward and Reload; the
address/search field stays visible and usable. `ShowNavigation = false` sets this
initially, and the example window host retains its popup switch. All outer window
controls and geometry remain owned by WindowManager.

As of 19 October 2026, all supplied projects use session memory for personal data
and page storage. No browser profile or page data is loaded or saved through a
DataStore. Auxiliary windows share current in-memory data, while a new play session
starts fresh. Explicit in-memory host snapshots remain available through the API.

The optional [HTML binding](../src/Browser/Integration/HTMLBinding/init.luau) still loads
the local catalog's normal HTML/CSS/JavaScript. It uses the same navigation tickets
and host-independent mount APIs. The native Browser adds no arbitrary internet
transport or download dialog. Camera and microphone permission prompts are
connected through the optional HTML host. HTMLPageDemo supplies the engine's
virtual Workspace camera backend; section 7 now attaches its MediaStream to a
live video preview with Start/Stop. Configure CAMERA_PATH and CAMERA_SCENE_PATH
in that LocalScript. Real microphone capture remains unavailable in this host.
The initial HTML website uses HTMLPageDemo's `Website` attribute when supplied,
otherwise the `local WEBSITE` fallback in the LocalScript;
StudioDemoConfig continues to choose only the active demonstration, now mapped to
`HTMLEngine.Examples.Config`. ReplicatedStorage has three root modules: HTMLEngine,
Browser and WindowManager. Integration adapters are Browser children; the optional
WaylinePage journal example has been removed.

## Unabhängiges Browsermodul — 14. Oktober 2026

This anchor is retained for links to the previous browser profile. The old shell's
Chrome-like design, shortcut behavior, favicon presentation, twenty metadata-only
closed records and per-instance-only profile data are superseded by Wayline above.
Earlier dated implementation records remain in [AI-HANDOFF](AI-HANDOFF.md) and
[PROJECT-REVIEW](PROJECT-REVIEW.md); they do not describe the current native UI.

## Eigenständige Fenster — 14. Oktober 2026

[WindowManager](../src/WindowManager/init.luau) ist ein eigenes ModuleScript in
ReplicatedStorage. Es funktioniert ohne Windows10, Browser und HTMLEngine.
`WindowManager.new(parent, options)` erzeugt einen Manager; `manager:Open`
liefert ein Fenster mit `Root`, `Content`, `Titlebar`, `State` und `OnClose`.
Fenster bieten `SetTitle`, `SetPosition`, `SetSize`, `Focus`, `Close`, `Minimize`,
`Maximize`, `Restore` und `Snap`. Acht passive Resizegriffe, exakter Maus-/Touch-
Besitz, Fokus/Z-Reihenfolge, Bereichsbegrenzung, Titelleistendoppelklick und
Halb-/Viertel-Snap werden vom Manager gehalten. Minimierte Fenster haben unten
einen Wiederherstellungsknopf in einer schmalen horizontalen Scrollfläche.
Das ist kein Windows10-Desktop oder Taskleistenmodul. Der komplette
`WindowSystem`-Bereich aus `haha.rbxmx` ist jetzt mit seinen benötigten UI- und
Framework-Helfern unter WindowManager übernommen. Die öffentliche API bleibt
über einen Hostadapter kompatibel; es gibt keine Abhängigkeit zu einem
`ReplicatedStorage.Windows10`. Desktop, Taskleiste, Apps, Anmeldung und Bootlogik
sind nicht Bestandteil dieses Fensterimports.

Hinzugekommen sind aktive/inaktive native Schatten, Titelleistenglyphen,
Öffnungs-/Schließanimationen, die animierte Snap-Vorschau, Fensterbesitzer und
die ursprüngliche MessageBox mit Info-/Warn-/Fehler-/Fragesymbolen. Ihre sechs
Schaltflächensätze, Tastaturauswahl, einmalige Ergebnisrückgabe, Klänge und
verschachtelte modale Sperren sind angebunden. Besitzer bleiben hinter ihren
Kindfenstern und schließen diese mit. Die Vorschau gehört jeweils einem Manager;
Animationen, Blinkjobs, Bildressourcen und Dialogklänge werden beim Abbau freigegeben.
Alle GuiObjects bleiben `Active = false` und `Selectable = false`; Maus und Touch
verwenden den vorhandenen Router. HTML-Eingaben erhalten nur freigegebene Fenster.

Schatten verwenden Roblox-[UIShadow](https://create.roblox.com/docs/reference/engine/classes/UIShadow).
Titelleistenglyphen nutzen den ursprünglichen kleinen Rasterrenderer und bei
fehlender EditableImage-Unterstützung passive Frame-Geometrie. Dialogsymbole und
Klänge behalten die Asset-IDs der gelieferten Datei; ihre Berechtigung im jeweiligen
Experience muss zur Laufzeit bestehen. Der Import ist strukturell und mit
kontrollierten nativen Ersatzobjekten geprüft; ein neuer Studio-Pixelvergleich ist
damit nicht behauptet.

```lua
local windows = WindowManager.new(screen)
local window = windows:Open({Title = "Application"})
windows:ShowError("The operation could not finish.", {Owner = window})
windows:MessageBox({
    Title = "Save changes?", Message = "Save before closing?",
    Icon = "question", Buttons = "YesNoCancel", Owner = window,
    OnResult = function(name) print(name) end,
})
```

`Owner = false` erzeugt eine anwendungsweit modale Meldung; ein normaler Besitzer
sperrt nur sein Fenster. `Modal = false` deaktiviert die Sperre, `Sound = false`
unterdrückt auch den Hinweis beim Klick auf ein gesperrtes Fenster.
`manager:Beep(kind)` spielt nur den zugehörigen Klang ab.
`GetOwnedWindows`, `GetMinimizedWindows`, `FindByAppID`, `FindAllByAppID`, `ClearFocus`
und `CloseAll` ergänzen die Fensterabfragen. Fenster bieten `GetOwner`, `SetEnabled`,
`MessageBox` und `Flash`. Die Dialoge sind native Hostfunktionen; dadurch werden
keine neuen JavaScript-APIs wie `alert()` oder Browser-Berechtigungsabfragen registriert.

Die frühere native Vergleichsseite `wayline://windows` mit vier Dialogtypen,
anwendungsweiter Sperre und Beispielfenster ist seit dem 16. Oktober als
[Regressionseingabe archiviert](../tests/fixtures/retired-native-window-demo-20261016.json).
Die WindowManager-API und ihre Tests bleiben erhalten. Die sichtbare Bedienprobe
verwendet jetzt die gemeinsame HTML-Seite `WindowCheck`.

Nur [HTMLPageDemo](../examples/HTMLPage.client.luau) lädt alle Module und übergibt
sie an [Browser.Integration.WindowHost](../src/Browser/Integration/WindowHost.luau). Die
Startwebsite ist `AnnoyingSite`; der Browser bietet `WindowCheck` zusätzlich auf Home an. Die
[Fensterseite](http://localhost:8000/window-check/index.html) verwendet für
Kinddokumente dieselbe Adresse mit `?view=popup` oder `?view=tab`.
Die getrennten HTML-/CSS-/JavaScript-Quellen bleiben normale Browserquellen.

`window.open(url, target, features)` nutzt `JavaScriptServices.WindowHost`.
Mit `popup` oder entsprechenden älteren Featureangaben entsteht ein separates
Browserfenster; ohne Popup ein Tab im aktuellen Browser. `width`/`innerWidth`,
`height`/`innerHeight`, `left`/`screenX` und `top`/`screenY` werden ausgewertet
und an den sichtbaren Bereich angepasst. Breite/Höhe beziehen sich auf den
Dokumentbereich; native Titel-/Adressleiste werden dazugezählt. Zielnamen
werden wiederverwendet, `_self`/`_parent`/`_top` beziehen sich in dieser
Top-Level-Anbindung auf den aktuellen Tab. Links mit benannten Targets können
dieselben Kontexte verwenden. `noopener` und `noreferrer` erzeugen keine
zurückgegebene Referenz und verwenden fremde Zielnamen nicht wieder.

Zurückgegebene Referenzen unterstützen `closed`, `name`, `close()` und `focus()`.
`window.close()` schließt nur vom Script geöffnete Kontexte. Schließen wird
queued, damit der laufende Handler zu Ende läuft. Jeder zusätzliche Kontext
belegt ein eigenes Fenster. Im rohen Runtime-/HTMLPage-Weg
ohne Host liefert `open()` `null`; der öffentliche eigenständige `mountHTML`-
Einstieg verwendet seit dem 16. Oktober den unten beschriebenen internen Host.
The example host supports up to 16 windows, with one document per browser.
The window limit is configurable at the application host. Fremde Internetseiten bleiben ohne HTTP-Host
abgelehnt; Kameras, Mikrofone und Berechtigungsdialoge werden nicht ergänzt.

Die Erweiterung ergänzt `moveTo`, `moveBy`, `resizeTo`, `resizeBy` und
`screenX`/`screenY`, `outerWidth`/`outerHeight`. Geometriebefehle gelten für
scriptgeöffnete einzelne Fenster; bei Hauptfenstern und Vollbild
bleiben sie ohne Wirkung. Zahlen werden nach WebIDL in ganze 32-Bit-Werte
umgewandelt und die native Fläche begrenzt Position/Größe.

`child.location.href`, `assign`, `replace` und `reload` navigieren den aktuellen
Kontext. Die Referenz bleibt erhalten; alte Dokumentobjekte sind nach dem
Realm-Abbau unbenutzbar (`InvalidStateError`). `child.document` erlaubt bei
gleicher Herkunft lebende DOM-Zugriffe, Style-/Textänderungen, neue Knoten und
Ereignisrückrufe. Jeder Zugriff prüft die feste Dokumentherkunft erneut;
fremde Dokumente und Location-Lesezugriffe werfen `SecurityError`. Ein neu
geöffnetes `about:blank` ist synchron verfügbar und erbt die Herkunft des
Öffners. `opener` bezeichnet diesen Kontext, außer bei `noopener`/`noreferrer`.

`postMessage` verwendet Structured Clone, Queuegrenzen und asynchrone Zustellung.
`targetOrigin` muss zur aktuellen Zielherkunft passen; `event.origin` hält die
Senderherkunft und `event.source` dieselbe stabile Fensterreferenz. Antworten
funktionieren auch zwischen verschiedenen Herkünften. Die vorhandene Clone-
Implementierung bestimmt unterstützte Payloads und Transferobjekte.
Unterschiedliche opake Herkünfte bleiben verschieden, obwohl beide als `null`
ausgegeben werden; die Standardzielherkunft vergleicht ihre Identität.

`element.requestFullscreen()`, `document.exitFullscreen()`,
`fullscreenElement`/`fullscreenEnabled`, `:fullscreen` und die beiden Vollbild-
Ereignisse sind verbunden. Vollbild vergrößert das Element innerhalb der Roblox-
Oberfläche; keine Betriebssystem- oder Monitorsteuerung. Nutzeraktivierung ist
erforderlich. Escape, Elemententfernung, Navigation, Fensterwechsel und Close
räumen den Zustand auf. **HTML allein unterstützt diesen Vollbildpfad ebenfalls**:
ohne WindowHost wird nur das eigene Mountziel erweitert und wiederhergestellt.
Kein Import von Browser oder WindowManager ist dafür nötig.

Dies bleibt ein begrenzter Hostvertrag: kein vollständiger WindowProxy mit
allen fremden Window-Globals, Property-Reflection oder iframe-Zielbaum;
vollständige Sandbox-/COOP- und Browser-Popupblocker-Verträge sind offen. Der
begrenzte Unload-Vertrag ist unten beschrieben. Vollbild
hält ein aktives Element pro Dokument; ein vollständiger verschachtelter
Fullscreen-/iframe-Stack samt Permissions Policy und Optionsauswertung fehlt.
`blur()` ist eine wirkungslose Kompatibilitätsmethode.
Fensteranimationen, Schatten und native MessageBox-Dialoge sind inzwischen im
eigenständigen WindowManager enthalten. Desktop, OS und Taskleiste bleiben getrennt.
Als Semantikreferenz dienen [Window.open](https://developer.mozilla.org/en-US/docs/Web/API/Window/open)
und [Window.close](https://developer.mozilla.org/en-US/docs/Web/API/Window/close),
[Herkunftsprüfungen](https://html.spec.whatwg.org/multipage/nav-history-apis.html#cross-origin-objects),
[Nachrichten](https://html.spec.whatwg.org/multipage/web-messaging.html#posting-messages)
und der [Fullscreen-Standard](https://fullscreen.spec.whatwg.org/);
die genannten Profilgrenzen ersetzen keine vollständige Browserkonformität.

Nachweis: `WindowManager`, `BrowsingWindows` und `BrowserWindowsMounted` prüfen
unabhängige native Fenster, echtes HTML/JS, benannte Referenzen, ersten Klick
auf Hintergrundinhalt, Eingabeabgrenzung, gehaltenes Layout, Close/Restore und
vollständigen Verbindungsabbau. Der Abschlusslauf
`build/window-manager-final-checks-20261014-full16.log` besteht mit 18 Suiten,
einschließlich tatsächlicher Demoquellen, verspätetem Mount und Hostgrenzen.
`BrowserWindowAPIs` ergänzt echte gemountete Dokumente für Geometrie, lebenden
DOM-Zugriff, Rückrufe, Klonen, Herkunft, Navigation, alte Referenzen, Vollbild-
Lebenszyklus und **HTML ohne Host**. `BrowserWindowsMounted` bedient alle neuen
Knöpfe mit den tatsächlichen Demoquellen. Der gezielte Lebenszykluslauf
`build/window-extension-lifecycle-final-20261014-full16.log` besteht mit drei
Suiten und Exit 0; der vorherige Nachbarlauf
`build/window-extension-neighbors-full-20261014-full16.log` mit 18 Suiten.
Der Erweiterungsabschluss besteht mit 23 betroffenen Engine-Suiten
(`build/window-extension-final-neighbors-20261014-full16.log`), drei unabhängigen
Browser-Suiten und Projektprüfung (Exit 0). Der Nachtrag für tatsächliche
Vollbildklicks und opake Herkunft besteht separat mit den betroffenen Fenstersuiten
(`build/window-extension-fullscreen-input-20261014-full16.log` und
`build/window-extension-opaque-origins-20261014-full16.log`). Chrome prüft dieselben
Seitenquellen einschließlich DOM, Nachricht/Antwort, Herkunft, Navigation/Reload,
Vollbild und 1000/390-px-Geometrie; Screenshots wurden angesehen.
API-/Loader-Register und default/browser/htmlpage-Builds sind aktualisiert.
Die damals geprüften beiden Fenstertestseiten sind seit dem 16. Oktober
[archiviert](../tests/fixtures/retired-window-pages-20261016.json). Sie deklarieren
`LocalScripts: ["app.js"]` in ihren `options.json`. Die generierten JavaScript-Kindmodule und `ScriptPath` werden
durch den tatsächlichen Website-Katalog geladen und im Mounttest verwendet
(`build/window-extension-generated-catalog-final-20261014-full16.log`, Exit 0).
Studio-Pixel und tatsächliche Framezeiten sind
damit noch nicht visuell abgenommen.

## HTML ohne Browser und WindowManager — 16. Oktober 2026

`rojo serve htmlpage.project.json --port 34873` startet dieselbe `AnnoyingSite`
direkt mit der HTML-Engine. Das Projekt enthält weder Browser noch WindowManager.
Im Studio-Plugin `localhost:34873` verbinden und nach dem Sync **Stop → Play**
ausführen. Der Standardaufbau mit
`default.project.json` bleibt Browser plus WindowManager mit der Annoying-Seite.

Auch das Standard-`HTMLPageDemo` startet automatisch mit internen HTML-Fenstern,
wenn `WindowManager` oder `Browser` aus ReplicatedStorage entfernt wurde.
Das `Website`-Attribut und die Speicheranbindung bleiben erhalten. Für verspätete
Replikation wartet der Start pro optionalem Modul höchstens zehn Sekunden;
`BrowserEnabled=false` überspringt diese Suche. Fehler einer vorhandenen
Integration werden weiterhin angezeigt.

Ohne gelieferten `JavaScriptServices.WindowHost` erstellt `Engine.mountHTML`
standardmäßig einen kleinen internen Fensterrahmen. Er bietet Schließen,
Minimieren mit Wiederherstellen, Maximieren, Ziehen, Größenänderung und Vollbild.
`window.open()` öffnet eigene einfache Fenster; benannte Referenzen,
synchron beschreibbares `about:blank`, Herkunft, Nachrichten, Navigation und
Schließen verwenden die vorhandene HTML-/JavaScript-Laufzeit.
`alert`, `confirm`, `prompt` und ein erforderliches `beforeunload` besitzen
ebenfalls eine interne Oberfläche. Explizit gelieferte Fenster-/Dialoghosts
behalten Vorrang.

Für die Einbettung in eigene GUIs bleibt derselbe Aufruf möglich:

```lua
local page = Engine.mountHTML(contentFrame, html, {
    FallbackWindow = false,
    DocumentURL = "http://localhost:8000/example/index.html",
})
```

Damit erhält das Hauptdokument keine zusätzliche Titelleiste. HTML-Popups und
Dialoge können weiter den internen Host benutzen. Für den normalen Fensterweg
kann `FallbackWindow` eine Tabelle mit `Title`, `Size`, `Position`, `MinSize`
und `Visible` sein. Alle Fenster bleiben standardmäßig innerhalb des gelieferten
Targets und seiner Clipping-Grenzen. Nur ein ausdrücklich gesetztes
`WindowParent` erlaubt einen anderen GUI-Elternbereich.
Es wird kein ScreenGui außerhalb dieses Vertrags angelegt.

`page.FallbackHost:GetPage()` liefert das aktuelle Hauptdokument,
`page.FallbackWindow` den initialen Rahmen. `page:Destroy()` auf dem ursprünglichen
Mount-Ergebnis beendet auch nach dessen Navigation die gesamte Familie.
Minimieren zerstört weder DOM noch VM; Verbergen/Minimieren beantwortet einen
noch lebenden Dialog ablehnend. Erzwungenes Schließen verwirft dagegen zuerst
die betroffenen Realms und ihre wartenden Autorenfortsetzungen.

Zielquellen bleiben Katalog-/Resolverdaten. Ein eigener
`WindowResolver(base, reference)` kann `{URL, Website={HTML, Options}}`
bereitstellen; beliebige Internetseiten, Downloads und Kamera-/Mikrofonrechte
werden dadurch nicht verfügbar. Same-Document-Fragmente und deren JS-History
behalten das Dokument; eine vollständige dokumentübergreifende Browserhistory
oder BFCache wird nicht behauptet. Raw-Iframes bekommen keinen eigenen
Fensterhost und unterstützen noch keine `allow-popups`-Weitergabe; erlaubte
Dialoge können den Elternhost verwenden. Siehe [Iframeprofil](IFRAMES.md) und
[Architektur](ARCHITECTURE.md#eigenständige-html-fenster--16-oktober-2026).

Die gemounteten Prüfungen stehen in
[StandaloneHTMLWindows](../tests/StandaloneHTMLWindows.luau),
[StandaloneHostLifetime](../tests/StandaloneHostLifetime.luau),
[FallbackWindows](../tests/FallbackWindows.luau) und
[WindowOpenCooperative](../tests/WindowOpenCooperative.luau).
Die native Studio-Darstellung und tatsächliche Framezeiten bewertet Tobias.

## Dialoge und Seitenlebenszyklus — 15. Oktober 2026

Der optionale HTML-Browseradapter verbindet jetzt `alert()`, `confirm()` und
`prompt()` mit einem Browserdialog. Das Skript wartet synchron auf die Antwort;
`confirm` liefert einen booleschen Wert, `prompt` einen String oder `null`.
Die Browseroberfläche besitzt Modalität, Textfeld, Tastaturbedienung und Cleanup.
Abbruch, Verbergen und Abbau lösen die Antwort höchstens einmal auf. Die HTML-
Engine importiert dafür weder Browser noch WindowManager. Im rohen Runtime-Weg
ohne Dialoghost gelten die dokumentierten Standardrückgaben; der öffentliche
eigenständige Mount kann die interne Oberfläche oben bereitstellen.

`beforeunload` wird bei vollständiger Navigation, Reload, Tab- und Fensterclose
abgefragt. Erst nach echter Nutzeraktivierung und einer abgebrochenen
`beforeunload`-Verarbeitung erscheint die feste Warnung `Leave this page?`.
`Stay` erhält das bestehende Dokument. Fragmentwechsel fragen nicht nach.
Der native Caption-Close läuft über `Window:RequestClose()` und den optionalen
Close-Guard; `Window:Close()` bleibt der bedingungslose Hostabbau.

`pageshow`, `pagehide`, `visibilitychange`, `unload`, `document.hidden` und
`document.visibilityState` sind für den dokumentierten Ablauf ohne BFCache
verbunden. GUI-Staging beim Seitenaufbau ist keine Dokumentverbergung.
Eingebettete Dokumente erhalten eigene Runtime-Besitzer, Sichtbarkeitsänderungen
und `allow-modals`-Prüfung; ein gemeinsamer Seitenwechsel zeigt höchstens eine
Leave-Warnung. Kinddokumente werden vor ihrem Elternteil entladen. Ein nie
veröffentlichtes, wartendes Dokument wird beim Abbruch zerstört, ohne den
wartenden Autorcode fortzusetzen.

Die aktuelle [Fenstertestseite](http://localhost:8000/window-check/index.html)
enthält manuelle Proben für Dialogrückgaben, Leave-Warnung und Sichtbarkeit.
Die Runtime-/Hostverträge, Tests und offenen Grenzen stehen im
[JavaScript-Profil](JAVASCRIPT-IMPLEMENTATION.md#dialoge-und-dokumentlebenszyklus--15-oktober-2026).
BFCache, vollständige Navigable-/WindowProxy-Semantik und ein gemeinsamer
browserweiter EventLoop für alle eingebetteten Realms bleiben offen. Native
Studio-Pixel und Dialogasset-Berechtigungen sind damit nicht abgenommen.

## Echte Browserabfragen — 14. Oktober 2026

Die frühere reine Browserreferenz `browser-requests` ist seit dem 16. Oktober
[archiviert](../tests/fixtures/retired-window-pages-20261016.json) und gehört weder
zum aktiven Websitekatalog noch zum Webserver. Die folgenden Beschreibungen
halten ihren ursprünglichen Referenzumfang fest.
Einzelne Knöpfe rufen Kamera/Mikrofon, genau ein verwaltetes Zusatzfenster,
Vollbild, Pointer Lock, Bluetooth-/USB-/Serial-/HID-Auswahl, Standort,
Benachrichtigungsberechtigung und klassische Hinweis-/Bestätigungs-/Eingabedialoge
auf. Die Seite verwendet Standard-HTML/CSS/JavaScript. Die native Oberfläche
und die tatsächlich erlaubten Fähigkeiten bleiben beim Browser/App-Host;
vorhandene Methoden garantieren keinen sichtbaren oder zugelassenen Dialog.
Gespeicherte Berechtigungen können Abfragen überspringen. Fehlende Methoden,
Ablehnung, Abbruch und Hostfehler werden auf der Seite ausgegeben.

Es starten keine Anfragen beim Laden. Freigegebene Medien werden lokal
angezeigt, ohne Aufnahme oder Upload, und über den Stopknopf, beim Verbergen
der Seite oder beim Verlassen freigegeben. Spät aufgelöste Medienanfragen geben
ihre Tracks frei. Die Geräteauswahl öffnet keine Geräteverbindung, Standortdaten
werden nicht gespeichert und es werden keine Benachrichtigungen verschickt.
Das frühere Zusatzfenster `popup.html` ist im selben Archiv erhalten.

Diese frühere Referenz hatte kein generiertes Roblox-Modul und war keine neue
Engine-/P18-Abschlussmeldung. Ihre Archivierung ergänzt keine Gerätefähigkeiten
der Engine. Die aktuelle Studio-Startwebsite ist `AnnoyingSite`.

## Vergleich mit getrennten Unterseiten — 13. Oktober 2026

Die frühere Übersicht und alle zehn Unterseiten sind seit dem 16. Oktober
[archiviert](../tests/fixtures/retired-window-pages-20261016.json), einschließlich
ihrer Browserquellen und generierten Module. Sie werden nur für die bestehenden
Regressionen verwendet; die folgenden Belege beschreiben diesen historischen
Vergleich. Jede Unterseite enthält
drei Beispiele mit Bedienung und erwarteter Wirkung; die neun ursprünglichen
Unterseiten besitzen zusätzlich aufklappbare Regeln.
Navigation lädt ein eigenes Dokument; keine versteckten Kapitel, eingebetteten
Frames oder vorausgeladenen Vorschauen. Die Übersicht benötigt kein JavaScript.
Die zehn Skripte sind jeweils eigene `JavaScript.luau`-Module. Browser und Roblox
verwenden dieselben Quellen; bestehende Spiele und archivierte Prüfseiten bleiben erhalten.

| Browserpfad unter `http://localhost:8000/` | Roblox-Modul | Vergleich |
| --- | --- | --- |
| `comparison-markup/index.html` | `ComparisonMarkup` | Dynamische Tabelle, offener Details-Zustand, Template/Elementverschiebung |
| `comparison-forms/index.html` | `ComparisonForms` | Validierung/FormData, Kalender/Select, Regler/Farbe/Rahmen |
| `comparison-selectors/index.html` | `ComparisonSelectors` | `:has()`, `nth-child(... of ...)`, Scope-Wurzel/Grenze, Ziel/Sprache/Richtung |
| `comparison-cascade/index.html` | `ComparisonCascade` | Layers/revert-layer, ungültige Variablenwerte, vergebende Listen/quoted Daten |
| `comparison-layout/index.html` | `ComparisonLayout` | Containerbreite/Queries/cqi, Subgrid, Flex/intrinsische Größen |
| `comparison-text/index.html` | `ComparisonText` | Gerade Inline-Rahmen/slice/clone, dynamische Counter, Richtung/Umbruch |
| `comparison-effects/index.html` | `ComparisonEffects` | Eine kleine lokale SVG, Clip/Mask/Filter, Mischflächen, 3D-Vorder-/Rückseite |
| `comparison-motion/index.html` | `ComparisonMotion` | Endliche Größenanimation, angehaltene add/accumulate-Probe, Transition |
| `comparison-script/index.html` | `ComparisonScript` | Promise/Timer-Reihenfolge, Idle-Callback mit Deadline-/Timeoutanzeige und direktem Abbruchtest, modaler/nichtmodaler Dialog/Popover, gespeicherte Notiz |
| `comparison-canvas/index.html` | `ComparisonCanvas` | Root-/Body-Canvasbesitzer, transparente Farbe über heller/dunkler UA-Fläche, Root-Opacity, Hover, behaltener Editor und Dokumentwachstum; separat geladene drei kleine Beispiele |

Animationen starten nur durch Bedienung; die Kompositionsprobe bleibt angehalten.
Effekte sind als begrenzter Rastervergleich gekennzeichnet. Allgemeiner
Hintergrund-Blur, nicht abgedeckte Schriftglyphen, abgerundete/verschachtelte/
halbtransparente Inline-Fragmente und echte Dateiauswahl werden dadurch nicht
als vollständig unterstützt dargestellt. Die Seite ersetzt weder Register noch
Fachprofile und ist keine vollständige Abnahme des Gesamtplans. Für Studio nach
dem Sync **Stop → Play**; laufende PlayerScripts behalten sonst ihre alte Startseite.

Browsernachweis: zehn Routen, neun tatsächliche Skripte und 27 Beispiele bei
1000/390 px; jede Route bleibt unter 250 DOM-Elementen und ohne Frames/seitlichen
Überstand (`build/comparison-browser-final-full16.log`). Die aktuellen Quellen
werden in `ComparisonWebsite` mit realem Renderer, Controller, CSS und Skripten
bedient. Zeilen-/Notizänderungen, FormData, Scope-Wurzeln, Variablen/Layer,
Container, Counter, SVG-Effekte, Komposition, Dialoge und wiederholte
Promise-/Timer-Durchläufe sowie zwei Enginebreiten bestehen. Die Prüfung
belegt außerdem verborgenen neuen Zeilentext während Budget-/nativer Messpausen,
erhaltene sichtbare Fremd-Editoren und Editorfreigabe bei strukturellem textContent.
Native Studio-Pixel und FPS bewertet Tobias weiterhin selbst.

Die ebenfalls [archivierte Eingabetypenreferenz](../tests/fixtures/retired-window-pages-20261016.json)
zeigt native `date`,
`datetime-local`, `month`, `week`, `time`, `file` und `image` mit Wertebereichen,
Pflichtfeldmeldungen, Schritten, Reset und tatsächlich übergebenen Formulardaten.
HTML, CSS und JavaScript liegen getrennt im Ordner `input-types`; sie benötigt
keine Bibliotheken und sendet keine Formulare ins Netz. Dieselben Quellen sind
als `InputTypes` für Roblox erzeugt und sind im Archiv erhalten; [Umfang und verschobene Dateiauswahl](HTML-INPUT-TYPES-20261006.md).

## Bytebude: die Homepage von 2004

[Browserquellen](../tests/fixtures/retired-nightweb-pages-20261019.json):
`http://localhost:8000/bytebude/index.html`. Dreispaltige Portalansicht, scharfe
Fensterkanten, klassische Links, Webbuttons und eine lokale Pixelillustration.
Schmalere Fenster ordnen die Randspalten unter den Inhalt. Die Spielhalle
öffnet die vorhandenen Memory-/Hangman-Seiten über gewöhnliche HTML-Links.

HTML, CSS und JavaScript liegen getrennt vor; keine Bibliotheken oder externen
Ressourcen. Die Reiter des schwarzen Bretts unterstützen Pfeiltasten und Home/End.
Nachtmodus, Umfrage und Besuchszähler verwenden `bytebude.v1.*` in Web Storage.
Das Gästebuch bewahrt höchstens 12 eigene Einträge; Nutzereingaben werden als
Text eingefügt; vorhandene Einträge behalten beim Ergänzen ihre DOM-Identität.
Zwei als Archiv markierte Grüße und die Nachrichten von 2004
gehören zur erfundenen Homepage. Neue Grüße werden nicht an andere Besucher
gesendet. Fehlende Speicherung lässt die Bedienelemente weiter funktionieren.
Kein ständig laufender Timer oder Animationsloop ist erforderlich.

Nachweis vom 8. Oktober: `BytebudeWebsite` führt das tatsächliche defer-Skript
in der Engine aus und prüft Reiter/Tastatur, Theme, Umfrage, Fundstücke, Formreset,
sichere Texte, Speicherbegrenzung und erhaltene Eintragsidentität sowie Layouts
bei 360/800/1120 px. Gemeinsam mit Memory, Hangman, dem archivierten CSS Atelier,
3D-Transforms und Mischflächen bestanden sechs betroffene Engine-Suiten
(`build/bytebude-engine-final.log`). Die anschließende Gästebuchverbesserung
bestand separat (`build/bytebude-retained-guest-review.log`).
Chromium bestand 17 Bedien-/Speicher-/Geometrieprüfungen jeweils bei 1384 und
390 px; Screenshots beider Ansichten wurden angesehen. Nach der finalen
Mobilkorrektur besteht kein horizontaler Überstand
(`build/bytebude-browser-review.log`). Funktionale SVG-Regressionen mit den
archivierten Quellen bestanden (`build/bytebude-svg-archive-review.log`);
Generatorprüfung: fünf Tests. Native Studioansicht und FPS bewertet Tobias.

## CSS Atelier: die neun CSS-Bereiche ansehen

Der frühere Vergleich ist seit dem 8. Oktober 2026 kein ausgelieferter Website-
Katalogeintrag mehr. [Archivierte HTML-Quelle](../tests/fixtures/css-atelier/index.html),
CSS, JavaScript, vier SVGs, Imports, Worklet und Font inklusive Lizenz bleiben
als Regressionstestdaten erhalten. `CSSAtelierWebsite` und `SVGHTMLEffects`
verwenden diese Originalquellen weiter. Die Dateiarchivierung wurde anhand
sämtlicher SHA-256-Prüfsummen kontrolliert.
[Erreichte Enginepfade und konkrete Grenzen](CSS-ATELIER-20261007.md) bleiben
unverändert gültig; eine entfernte Demo entfernt keine Enginefunktion.

## Im Browser

```powershell
python scripts/serve-websites.py
```

`http://localhost:8000/` leitet zur Hauptseite weiter. Direkte Adressen:

- `http://localhost:8000/main/index.html`
- `http://localhost:8000/memory/index.html`
- `http://localhost:8000/hangman/index.html`
- `http://localhost:8000/window-check/index.html`
- `http://localhost:8000/bytebude/index.html`

Alle Seiten verwenden normale HTML-Dokumente, CSS, lokale SVGs und eine
externe JavaScriptdatei mit `<script src="app.js" defer></script>`. Sie benötigen
keine Bibliotheken oder externen Schrift-/Bilddienste. Links sind gewöhnliche
relative HTML-Adressen; die Seiten funktionieren auch im normalen Browser.

## Eigene HTML-, CSS- und JavaScript-Module

Jede ausgelieferte Roblox-Seite besitzt folgende generierte Module unter
`src/HTMLEngine/Websites`, einschließlich Bytebude:

| ModuleScript | Inhalt |
| --- | --- |
| `HTML` | Unveränderter Quelltext aus `index.html` |
| `CSS` | Unveränderter Quelltext aus `styles.css` |
| `JavaScript` | Unveränderter JavaScript-Quelltext aus `app.js`, als String |
| Seitenmodul (`init.luau`) | Name, URL, ScriptPath und Ressourcenoptionen |

Das `JavaScript`-ModuleScript ist kein Roblox-LocalScript und enthält keine
Übersetzung des Spiels nach Luau. Der Website-Katalog registriert seinen String
unter der absoluten `app.js`-Adresse. Der bestehende HTML-Skriptloader führt
denselben JavaScriptcode in der Engine-Laufzeit aus. Die Optionen werden dabei
kopiert; vorhandene ScriptSources bleiben erhalten.

Bearbeitet werden die Browserdateien. Anschließend synchronisieren:

```powershell
python scripts/sync-website.py main Main "Spielraum"
python scripts/sync-website.py memory Memory "Memory — Spielraum"
python scripts/sync-website.py hangman Hangman "Hangman — Spielraum"
```

`LocalScripts: ["app.js"]` in `options.json` erzeugt das separate JavaScript-
Kindmodul und `ScriptPath = "app.js"`. Bei mehreren lokalen Skripten bleibt
deren bisherige Zuordnung über `JavaScriptServices.ScriptSources` erhalten.
`LocalSVG` verpackt die lokalen Illustrationen für den Roblox-Ressourcenhost.

## In Roblox

`examples/StudioDemoConfig.luau` enthält ausschließlich `ActiveDemo = "HTMLPage"`.
Die Startseite verwendet das Attribut `Website` auf `HTMLPageDemo`; fehlt es,
gilt der `local WEBSITE`-Fallback in `examples/HTMLPage.client.luau`.
Für einen direkten Spielstart das Attribut auf `"Memory"` oder `"Hangman"`
setzen. Nach Änderungen **Stop → Play** ausführen.
Hauptseite und Spiele navigieren über den bestehenden Website-Katalog.

Das erste Laden bleibt bis zum stabilen Layout und den sichtbaren SVG-Uploads
hinter der blanken Ladefläche. Späterer Resize blendet die Seite nicht erneut
aus. Details: [Laden und Arbeitsabschnitte](LOADING-PERFORMANCE.md).

## Memory: Verhalten und Speicherung

Die erste aufgedeckte Karte startet die Uhr. Erst die zweite Karte zählt als
Zug. Gefundene Paare bleiben offen. Bei einem Fehlpaar werden beide Karten
nach 850 ms verdeckt; währenddessen ist keine dritte Karte aufdeckbar.
Pause stoppt Uhr und Fehlpaar-Timer und verdeckt das Spielfeld. Fortsetzen
verwendet die verbleibende Wartezeit. Neustart verwirft alte Timer und erhält
bei gleicher Schwierigkeit die Kartenobjekte. Eine andere Schwierigkeit
erzeugt die benötigte Kartenanzahl. Im großen Spiel sind es ab 600 px sechs,
darunter vier Spalten. Alle Karten bleiben quadratisch.
Der volle Kartenbutton erhält seine Prozenthöhe aus der fertigen Bezugsbox.
Die Sterne der Rückseiten, der Mischpfeil und die Motive sind lokale SVG-Bilder;
sie benötigen keine Unicode-Abdeckung der Roblox-Schrift. Der Stern ist eine
Website-Ressource, keine besondere Zeichenbehandlung in der Engine. Beim
Aufdecken ändern sich Transparenz und Farben; das Rückseitensymbol löst keinen
zusätzlichen display-Wechsel aus und blockiert durch pointer-events:none
keine Kartenklicks.

Bestleistungen liegen unter `spielraum.memory.records.v1`, getrennt nach
Paaranzahl. Weniger Züge zählen zuerst, bei Gleichstand die kürzere Zeit.
Die Hauptseite zeigt den Rekord für acht Paare. Der Spielbereich kann den
Rekord der gewählten Schwierigkeit löschen. Ungültige oder nicht verfügbare
Speicherdaten verhindern das Spielen nicht. Im Browser ist dies normaler
Web Storage; Roblox verwendet die vorhandene Speicherbrücke, deren dauerhafte
Speicherung einen synchronisierten HTMLStorage-Server benötigt.

Tab/Enter/Leertaste bedienen die nativen Buttons; Escape pausiert bzw. setzt
fort. Hover- und Aufdeckübergänge verwenden CSS. `prefers-reduced-motion`
schaltet diese Übergänge ab. Symbole und Namen erklären die Motive gemeinsam.

## Prüfen

`node scripts/run-html-tests.cjs MemoryGame` führt den echten Spielcode in der
Engine aus: Schwierigkeiten, Fehlpaare, Pause/Fortsetzen, Neustart-Rennen,
Gewinn, Speicherung, Timerfreigabe, native Layouts und getrennte Scriptmodule.
`MemoryRendering` beginnt mit dem leeren Spielfeld, bevor das tatsächliche
defer-Skript die Karten erzeugt. Es prüft transparente Ebenen, Bildregistrierung,
Motivnamen, Cliprechtecke, Aufdecken, Fehlpaare und erneutes Aufdecken. Der
Renderer muss neue Transparenzebenen vor dem ersten Layout berücksichtigen;
sonst behalten sie ihre native Standardgröße und schneiden Karteninhalte ab.
`HangmanGame` prüft Gewinn/Verlust, wiederholte Eingaben, Umlaute, Kategorien,
Tipp, Statistik und responsive Spielfeldgrößen mit dem tatsächlichen Spielcode.
Der vollständige Runner erhält die bisherigen Engine-Regressionen über die
nicht veröffentlichten Fixtures. `python scripts/test-sync-website.py` prüft
die Quellübernahme; `node scripts/check-project.cjs` und Rojo prüfen das Projekt.
Automatische Browserprüfungen ergänzen das funktionale Engineprofil. Die native
Studio-Darstellung und FPS prüft Tobias; eine vollständige Browserkonformität
wird dadurch nicht behauptet.

## Hangman: Verhalten und Speicherung

Vier Kategorien enthalten insgesamt 32 deutsche Wörter. Bereits geratene
Buchstaben zählen nicht erneut; ein Treffer deckt alle passenden Stellen auf.
Ä, Ö und Ü besitzen eigene Alphabetbuttons. Nach sechs verschiedenen falschen
Buchstaben endet die Runde und das vollständige Wort erscheint. Pro Wort ist
ein Tipp erlaubt, der einen noch fehlenden Buchstaben ohne Fehlversuch aufdeckt.
Ein Kategorienwechsel und „Neues Wort“ setzen die laufende Runde zurück. Das
nächste Wort unterscheidet sich vom vorherigen.

Das Spiel verwendet keine Uhr und keine Animationsschleife. Alphabetbuttons
und Wortfelder werden wiederverwendet. Die Zeichnung besitzt sieben lokale
SVG-Ladezustände; ein Fehlversuch wechselt nur deren Quelle. Gesamtgewinne und
beste Serie werden unter `spielraum.hangman.records.v1` gespeichert. Ohne
verfügbaren Speicher bleibt das Spiel nutzbar. Die laufende Serie beginnt pro
Seitenbesuch neu.
