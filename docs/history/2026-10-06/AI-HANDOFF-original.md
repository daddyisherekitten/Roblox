# Übergabe: Roblox HTML-Engine

## 6. Oktober 2026 · Memory-Hintergrundmusik

Memory app.js startet beim Seitenstart einen Audio-Knoten für die vom Nutzer
genannte Sound-ID 117006292434032. Loop, Lautstärke 0.35, Pause bei pagehide;
Browser-NotAllowedError wird beim nächsten Pointer-/Tastatureingang erneut
versucht. options.json ordnet die Assetdelivery-URL diesem Roblox-Asset zu;
die generierten Memory-Module sind synchronisiert. Der Browser kann nur spielen,
wenn Roblox ihm die Datei ausliefert und seine Autoplayregeln es zulassen.
MemoryGame/MemoryRendering bestehen; letzterer nutzt den tatsächlichen AudioHost
mit kontrollierten nativen Diensten und prüft Start/ID/Loop/Volume sowie Abbau
bei 320/480/1080 px. Native hörbare Wiedergabe und Assetberechtigung nicht geprüft.
Log: build/memory-music-tests.log.

## 6. Oktober 2026 · Standard-JavaScript-Audio

`JavaScript/AudioElements` verbindet echte Audio-DOM-Knoten mit dem neuen
`Rendering/AudioHost`: `Audio()`/`new Audio(src)`, `play()`-Promises,
`pause/load/fastSeek`, Zustände, MediaError/TimeRanges, Zeit/Rate/Lautstärke,
Mute, Loop, Preload, Quellenwechsel und Standardereignisse. Runtime installiert
die Audio-APIs und berücksichtigt verbundene Ladevorgänge in der Loadbarriere.
Ein unsichtbarer oder entfernter Audio-Knoten kann weiterspielen; Seitenabbau
zerstört Sounds und Verbindungen. Generationen und Play-Intents verhindern
veraltete Erfolge und Pause/Play-Rennen. Native Callbacks führen keinen
Autoren-JavaScript-Code aus, sondern betreten die gemeinsame Aufgabenqueue.

HTMLScripts/MediaRuntime teilen einen Sound zwischen JavaScript, page:PlayMedia
und der Steuerleiste. Wiedergabe/Seek/Lautstärke erzeugen keine DOM-/Layout-
Invalidierung. Audio ohne Controls ist unabhängig von Autoren-CSS unsichtbar.
Das dynamische Controls-Attribut braucht eine interne RenderChildren-Anforderung,
obwohl sich die tatsächlichen DOM-Kinder nicht ändern. RenderTree respektiert
diese Anforderung und behält bestehende Audio-Boxen/Sounds beim Umschalten.
Die tatsächliche DOM-MutationObserver-Oberfläche erhält keine erfundene Mutation.

Der Cursor wird bei Play über Sound.Playing erhalten. Ein nativer End-Cursor-
Reset wird nicht als JavaScript-Zeitposition 0 veröffentlicht. Native Seek-
Ereignisse erhalten die vorherige Position, damit übersprungene Bereiche nicht
als played gelten. Loaded-Assets werden beim erneuten Load nicht doppelt
vorgeladen. Fehler-/IsLoaded-Prüfungen melden keinen bloßen Preload-Rücklauf
als Erfolg. Gemeinsame Audio-Zeitereignisse sind auf etwa vier pro Sekunde
begrenzt; die bestehende begrenzte Media-UI-Aktualisierung bleibt erhalten.

Die Roblox-Pfadzuordnung options.Audio und die Experience-Freigabe bleiben nötig.
Raten 0.5–2, vollständiges Asset statt echter Bufferstatistik; canPlayType gibt
ohne Codecgarantie einen leeren String zurück. Video-JavaScript, Track-API,
vollständiger Source-Fallback/Streaming/Autoplay/CORS sowie Web Audio bleiben
offen. Keine LESS-/jQuery-Erweiterung. Details und Beispiele:
[Audioprofil](JAVASCRIPT-AUDIO-20261006.md), [Medienübersicht](MEDIA.md).
Roadmap/Implementierungsübersicht und Runtime-API-Register sind aktualisiert.

Verifikation: JavaScriptAudio und AudioHost prüfen Zustände/Rennen/Lifecycle
und verbinden die tatsächlichen Runtime-/HTMLScripts-/RenderTree-/MediaRuntime-
Module mit kontrollierten nativen Diensten. Die eingefrorene Browserreferenz
tests/fixtures/audio-browser-reference.{html,json} wurde im echten In-App-
Browser mit stummem PCM geprüft. Hörbarer nativer Studio-Test bleibt offen.
253 registrierte Engine-Suiten einschließlich isolierter Prüfungen,
Projektprüfung mit 400 kalten Rendering-Abhängigkeiten und Rojo-Build bestanden.
Logs: build/audio-full-tests.log, build/audio-final-focused.log,
build/audio-project-audit.log, build/audio-rojo-build.log.
Build: build/audio-engine.rbxlx.

## 6. Oktober 2026 · Dynamische Memory-Fronten und Hangman

Memory-Regression: Der Renderer wird zunächst mit einem leeren Spielfeld
gebaut. Das defer-Skript erzeugt danach Karten mit Opacity-CanvasGroups.
Der lokale Build-Merker `opacity` wurde gesetzt, `tree.HasOpacity` blieb jedoch
beim ursprünglichen Wert. Die nächste Layoutphase ließ deshalb die
Compositorgrößen aus; Bild und Motivname konnten abgeschnitten werden.
Der erfolgreiche strukturelle Refresh übernimmt diesen Merker jetzt vor
der nächsten Layoutphase. Der vorherige HitTest-Passthrough bleibt erhalten.

`MemoryRendering` reproduzierte den fehlenden Merker vor der Korrektur und
prüft das tatsächliche defer-Skript auf einem leeren Renderbaum, native
Compositor- und Clipgrößen, SVG-Uploadflächen, Motivnamen, Fehlpaare,
erneutes Aufdecken, Neustart und Schwierigkeitswechsel bei 320/480/1080 px.
SVG-Pixelberechnung selbst bleibt in den SVG-Suiten; dieser Test verwendet
Upload-Sentinels und behauptet keine native Studio-Bildprüfung.

Hangman ist unter `examples/websites/hangman` und `Websites/Hangman` mit
separaten HTML-, CSS- und JavaScript-Quellen verfügbar und auf Main verlinkt.
Vier Kategorien, 32 deutsche Wörter, sechs Fehler, Umlaute, ein optionaler
Tipp je Wort, Tastatur/Buttons und persönliche Gewinn-/Serienstatistik.
Keine Timer oder fortlaufende Animationsschleife; Buttons und Wortfelder
bleiben erhalten. LocalSVG verpackt sieben Zeichnungszustände.

Beim Kategorienwechsel zeigte sich ein allgemeiner VM-Fehler: Ein vom
`for…of`/`for…in` bereits konsumiertes `continue` der letzten Iteration
blieb als Ergebnis erhalten und übersprang den Code nach der Schleife.
`VM.execute` löscht jetzt normale und konsumierte Iterationsergebnisse;
fremde Labels, return/throw und Iterator-Close bleiben berücksichtigt.
Zwei Sprachfixtures prüfen das Schleifenende, verschachtelte Labels und
Iterator-Close bei break, return und äußerem continue.

Memory wurde nach der Korrektur vom Nutzer in Studio bestätigt.
Hangman wurde mit seinem echten defer-Skript funktional sowie im Browser
geprüft; native Studio-Darstellung von Hangman noch durch den Nutzer.

Verifikation: 251 registrierte Engine-Suiten einschließlich isolierter
Prüfungen erfolgreich. Die beiden neuen Schleifenfixtures stimmen auch
mit nativem JavaScript überein. Projektprüfung (inklusive 398 kalter
Rendering-Abhängigkeiten) und Rojo-Build bestanden. Logs:
`build/games-full-tests.log`, `build/games-final-focused.log`,
`build/games-project-audit.log`, `build/games-rojo-build.log`.
Build: `build/games-memory-hangman.rbxlx`;
Browser-Vorschau: `build/hangman-preview.png`.

## 5. Oktober 2026 · Memory: Fehlpaare erneut anklicken

Nach erneutem Verdecken fingen die anonymen Opacity/OpacityContent-Flächen
den Maus-Treffer ab: Beim Aufsteigen durch die native GUI-Hierarchie fanden
sie den registrierten DOM-Elternknoten mit pointer-events:auto statt der
Kartenebene mit pointer-events:none. Der Spielcode selbst entsperrt Fehlpaare
korrekt. `GroupOpacity.create` markiert seine beiden Hilfsflächen mit
HTMLHitTestPassthrough; der optionale MaskClip erhält dieselbe Markierung.
`HitTest.pick` überspringt eine solche Fläche unabhängig vom gefundenen
DOM-Vorfahren. Die Markierung gilt nur für die Fläche selbst und sperrt
keine interaktiven Nachkommen. Opacity:0 bleibt für echte DOM-Boxen anklickbar.

`MemoryGame` prüft nun drei Fehlpaar-Runden mit echtem JS, Renderer-Updates
und Pointer-Trefferprüfung bei 320/480/1080 px für 8/12 Paare, danach erneut
Aufdecken und Paarfinden mit denselben Buttons. `Cursors` prüft registrierte
Vorfahren, Opacity-Runden, pointer-events:none sowie explizit interaktive
Nachkommen. Die deterministische Uhr pumpt aufgelaufene Tasks bis zur Ruhe,
damit das Taskbudget keinen fälligen Timer im Test zurückhält. Spielregeln,
850-ms-Frist und Websitequellen bleiben unverändert. Native Studio-Prüfung
nach Neustart von Play weiterhin durch den Nutzer.

Verifikation: 249 registrierte Engine-Suiten einschließlich isolierter
Prüfungen erfolgreich; Projektprüfung und Rojo-Build bestanden. Logs:
`build/memory-input-full-tests.log`, `build/memory-input-audit.log`;
Build: `build/memory-input.rbxlx`. Rojo bleibt auf Port 34872 aktiv.

## 5. Oktober 2026 · Memory: Buttonzentrierung, Prozenthöhe und SVG-Symbole

Nutzerbilder zeigten zu hoch stehende Toolbartexte, streifenförmige Buttons
in quadratischen Karten sowie fehlende Unicode-Glyphen. `Controls/Defaults`
setzt für button/submit/reset align-content:center. `Controls/View` verteilt
freien Platz um die Fontbox, begrenzt die Labelhöhe auf TextSize und verwendet
dieselbe Position für die Inline-Grundlinie. Start/end, Flexausrichtung und
asymmetrisches Padding bleiben berücksichtigt; Eingabefeld-Kalibrierungen
sind unverändert. `BlockImage` gibt sizing.HeightBasis an ImageLayout weiter,
damit absolute 100%-Buttons und 50%-Bilder die fertige Elternhöhe nutzen.

Auf ausdrückliche Nutzerwahl bleiben Memory-Rückseitensterne als lokale SVGs
in der Website; keine SVG-Sonderregel für Unicode in der Engine. Back-SVGs
liegen als pointer-events:none-Ebene über dem Button und verschwinden nur
über opacity. Mischpfeil und dekorativer Stern verwenden ebenfalls Bilder;
die Hauptseiten-Kartenvorschau enthält SVG-Motive. Sources/LocalSVG und
generierte Module sind synchronisiert. Allgemeine Schrift-Fallbacks wurden
nicht implementiert. `Forms`, `Positioning`, `CombinationPositioning` und
`MemoryGame` prüfen die neuen Fälle; Memory prüft jetzt auch die volle
Buttonhöhe bei 320/480/1080 px. Native Studio-Darstellung vom Nutzer prüfen.
Prüflogs: `build/memory-controls-full-tests.log`,
`build/memory-controls-audit.log`; Build: `build/memory-controls.rbxlx`.

## 5. Oktober 2026 · Spielraum und Memory mit eigenem JavaScript-Modul

Der öffentliche Katalog enthält nur `Main` (spielraum., Spiele-Hauptseite)
und `Memory`. Alle sechs vorherigen Websites sind aus Browserquellen und
Roblox-Modulen entfernt. Ihre unveränderten Browserdateien und Metadaten
liegen als nicht ausgelieferte Testdaten unter
`tests/fixtures/retired-websites.json`; bestehende Regressionen lesen daraus.
Das Schrift-/SVG-Labor und die Engine-Funktionen bleiben erhalten.

`HTMLPage.client.luau` startet `local WEBSITE = "Main"`;
`StudioDemoConfig` enthält weiterhin nur ActiveDemo. Beide neuen Seiten haben
`HTML.luau`, `CSS.luau`, `JavaScript.luau` und `init.luau`. Die Browserquelle
ist jeweils `index.html`, `styles.css` und `app.js` mit externem defer-Skript.
`sync-website.py` erzeugt bei genau einem LocalScript einen lesbaren
JavaScript-Kindmodulstring und ScriptPath. `Websites.validate` registriert
diesen unter der absoluten URL und kopiert die Optionen einschließlich
JavaScriptServices/ScriptSources. Mehrere lokale Scripts behalten ihre
bisherige Zuordnung. Keine Luau-Übersetzung des Spielcodes.

Memory: 6/8/12 Paare, Fisher-Yates, quadratische Karten mit lokalen SVGs,
Züge/Paare/Uhr, Pause mit eingefrorener Fehlpaar-Restzeit, Neustart ohne
veraltete Timer, Tastatur, Ergebnis und Bestmarken je Paaranzahl. Uhrtexte
ändern sich nur sekündlich; gleicher Schwierigkeits-Neustart erhält die
Karten-DOM-Objekte. Vollständige Runden stoppen alle Timer. Rekorde liegen
unter `spielraum.memory.records.v1`, sind löschbar und nutzen die vorhandene
Storage-Brücke. Die Hauptseite zeigt den 8-Paare-Rekord. Andere Spiele sind
ausdrücklich noch nicht spielbare Ankündigungen. Keine neuen Netzwerkdienste.

`tests/MemoryGame.luau` prüft den echten JS-Code in der Engine einschließlich
externem HTML-defer-Skript, ControlAdapter, Timer-Rennen, Speicherung und Layouts beider Seiten bei
320/480/1080 px. `.tile` verwendet zusätzlich zu aspect-ratio `width:100%`,
damit die native Gridbox ihre quadratischen Maße erhält. Chromium-Prüfung:
volle Gewinnrunde, Pause, gespeicherter Rekord nach Reload, Rekord löschen,
6/12 Paare und 360-px-Ansicht ohne horizontalen Überlauf; keine Konsolenfehler.
Keine nativen FPS-Benchmarks. Dokumentation: [WEBSITES.md](WEBSITES.md).
Verifikation: 249 Engine-Suiten, fünf Synchronisierungsprüfungen,
Projektprüfung und Rojo-Build erfolgreich; Memory nach der erweiterten
defer-Prüfung zusätzlich gezielt erfolgreich. Prüflogs:
`build/minigames-full-tests.log`, `build/minigames-audit.log`;
Rojo-Build `build/minigames.rbxlx`. Browser: `/main/index.html` und
`/memory/index.html`. Native Darstellung weiterhin vom Nutzer prüfen lassen.

## 5. Oktober 2026 · Allgemeiner Seitenaufbau in kleinen Arbeitsabschnitten

Das initiale Laden bevorzugt längere Ladezeit gegenüber großen eigenen
Arbeitsblöcken. `WorkContext` besitzt Coroutine-Scopes und eine gemeinsame
native Heartbeat-Frist mit standardmäßig 2 ms Ziel zwischen Checkpoints.
HTML/CSS/JS-Parsing, Renderbaum/GUI, Bibliotheksinstallation, Skripte,
Layout, SVG-Szenen/Hitboxen/Raster/Cache und CSS-Pixelarbeit pausieren darin.
Der erste Engine-Mount verteilt zusätzlich 398 kalte Modulimporte in
Abhängigkeitsreihenfolge; `export-loading-modules.cjs --check` prüft die Liste.

Initiale Texturen werden in höchstens 64-KiB-Streifen übertragen und erst
vollständig als fertig gemeldet. Die Seite bleibt bis zum stabilen ersten
Layout und sichtbaren SVGs hinter ihrer blanken Ladefläche. Resize und normale
DOM-Änderungen behalten ihre bisherige Verarbeitung. SVG-Vorbereitung darf
nach der Präsentation in Abschnitten fortlaufen; neue sichtbare Uploads bleiben
atomar. Laufende Scopes behalten ihre Frist bis zum Ende, auch nach Lease-Ende.
Async-/Generator-Hostpausen sind keine JS-Suspensionen. Abbruch, Realm-Aufbau,
Cache-Publikation und Ressourcenfreigabe berücksichtigen die zusätzlichen
Pausen. Echte Aufbaufehler werden weiterhin gemeldet.

Native Modulkompilierung, GUI-/Text-/Bild- und GPU-Aufrufe sind nicht beliebig
unterteilbar. Studio-Framezeiten prüft weiterhin der Nutzer; absolute
Ruckelfreiheit wird nicht behauptet. Details und Grenzen stehen in
[LOADING-PERFORMANCE.md](LOADING-PERFORMANCE.md). Funktionale Regressionen:
248 HTML-Suiten, SVG-Runner mit `--functional-only`, Projektprüfung und
Rojo-Build; keine nativen FPS-Benchmarks. Logs:
`build/loading-full-tests.log`, `build/loading-svg-tests.log`,
`build/loading-audit.log`, `build/loading-api-check.log`.

## 5. Oktober 2026 · Bildfehler: Box, Symbol und Requestzustände

`Rendering/ImageFallback` ist die gemeinsame Fehlerentscheidung für ImageBox,
ImageLoad, RenderTree und ImageLayout. Block-/Inlineblockbilder behalten ihre
CSS-/Attributmaße; Inline-Alttexte verwenden den getrennten Text-/Symbolweg
mit min/max und vollständigen Boxkanten. Das vorhandene Nutzer-Fehlerasset
erscheint mit Alttext als 16-Pixel-Symbol; alt="" unterdrückt beides. Fehler
verbergen alte Raster-/Blurflächen. SVG-, Bild- und Hit-Target-Identitäten
bleiben bei Zustandswechseln und Resize erhalten. Interne SVGs, Canvas,
Kontrollen, Medien und Iframes werden nicht als kaputte img behandelt.

ImageResources trennt fehlendes/leeres src, bewahrt currentSrc bei ungültigen
URLs, wiederholt explizite Zuweisungen derselben src und verwirft alte
Ereignisse/Hostantworten. Gültige SVG-Nullmaße sind erfolgreich; SVG/Sizing
und ResourceLoadHost bewahren diese ebenfalls. Verbundene width/height-Getter
flushen vorherige Änderungen und lesen die Inhaltsmaße ohne Boxkanten;
abgetrennte Bilder erzwingen kein Layout. Die Websitequellen bleiben unverändert.

18 echte Chromium-Größenreferenzen und neun native Lifecycle-Fälle stehen
im [Bildprofil](IMAGES.md). ImageErrorSizing montiert die echte Layoutpipeline;
JavaScriptResourceLoading prüft zusätzlich simulierte Hostfehler. Fernwehs
Testaufbau verwendet jetzt dieselbe SVG-Zuordnung wie sein nativer Ladehost.
Vollständiger HTML-Runner: 246 Suiten bestanden, Log
`build/image-errors-full-tests.log`. Projektprüfung: 826 Luau, 80 JS, 35 Python,
114 HTML, 373 Referenzen, sieben Rojo-Projekte, 126 Fonteinträge. Rojo-Build
und API-Export/check bestanden (4.536 Deskriptoren, 555 Owners, 108 Module,
Getterreads 0). Keine FPS-Tests. Studio-Sichtvergleich und allgemeiner
HTTP-/Data-/Blob-Bildtransport bleiben gesonderte Hostgrenzen.

## 5. Oktober 2026 · Browser-Grundlagen und Vergleich 10

Aktueller Abschlussumfang: [Browser-Grundlagen](JAVASCRIPT-FOUNDATIONS-20261005.md),
[CSS/Animationen](JAVASCRIPT-CSS-ANIMATIONS-20261005.md),
[Laden](JAVASCRIPT-LOADING-20261005.md),
[Text/Daten](JAVASCRIPT-TEXT-DATA-20261005.md).
Gesamtbestand und offene Familien stehen in Implementierungsstand, Roadmap und
dem aus dem tatsächlichen Runtime-Realm exportierten API-Register.

Die neue Website `examples/websites/browser-foundations` wird nach
`Websites/BrowserFoundations` generiert. Fünf Karten kombinieren Nesting/CSSOM,
Hover, native Bild-/Fontzustände, Unicode/URL/DST und eine eigene gespeicherte Notiz.
Browser und Engine verwenden dieselben Quellen. Die Startseite bleibt Fernweh;
nur `local WEBSITE` im HTMLPage-LocalScript wählt eine Website. StudioDemoConfig
bleibt bei ActiveDemo. Die ergänzende resource-reference.html ist nur Browserreferenz.

Wichtige Integrationspunkte: Runtime installiert ImageResources/FontLoading vor
Skriptstart, ScriptLoader wartet auf verbundene Bildanforderungen, FontLoading
erhält native Preload-/Layout-Gates. HTMLPage besitzt einen gemeinsamen
ResourceLoadHost für ImageDimensions und JavaScript; Quellenwechsel melden die
alte Registrierung vor Mutation ab und behalten GUI-/Bildidentität. Dynamic
title/meta/base aktualisieren DocumentInfo und spätere Ressourcenbases, ohne GUI.
Native lokale Fontfamilien werden vorgeladen; beliebige externe Fontdateien und
neue Aliasrenderingpfade werden nicht als erfolgreich implementiert dargestellt.

Runtime hält fontLayoutPending zwischen einer layoutbedürftigen ApplyChanges-
Antwort und der tatsächlichen Layoutpublikation. Paint-Flushes löschen dieses
Gate nicht. AfterLayout und FontLayoutCompleted lösen es auf; HTMLPage führt
auch den normalen Scheduler-Skipped-Pfad durch publishLayout. Eine echte lokale
Textmessung gibt so fonts.ready frei, ohne alle Layoutobserver erneut auszulösen.
Font-Environment-Checks sind budgetierte Runtime-Einträge ohne Idle-Pollingtasks.

TextMutation behandelt overflow-wrap:anywhere nicht pauschal als tatsächlich
fragmentierten Text. Nur vorhandene WrapOwner-Fragmente sperren den lokalen
Stable-Geometry-Pfad; echte Umbrüche/Höhenänderungen behalten ihre Propagation.
Animationsnamen sind case-sensitive. Übergangsumkehr verkürzt die Dauer;
unabhängige Stiländerungen dürfen die laufende Uhr nicht neu starten.

Keine FPS-Benchmarks. Automatische Hostmocks ersetzen weder einen nativen
Studio-Sichtvergleich noch tatsächliche Assetrechte oder dauerhafte DataStore-
Wiederherstellung. Keine ganzen Standardfamilien allein wegen existierender
API-Objekte als vollständig markieren. Die Teilprofile nennen ihre Grenzen.

Abschlussnachweise: vollständiger HTML-Runner mit 245 registrierten Suiten und
isolierten Cleanup-/nativen DOM-Prüfungen bestanden; Unicode-Korpus mit 20.034
Zeilen, Text/Daten mit 30 Gruppen/4.729 Referenzen. Projektprüfung (824 Luau,
79 JS, 35 Python, 113 HTML), HTMLPage-Rojo-Build und frischer API-Export/check
(4.536 Deskriptoren, 555 Owners, 108 Module, Getterreads 0) bestanden.
Genaue Befehle, Logs und verbleibende native Prüfgrenzen stehen im Abschlussprofil.

## 5. Oktober 2026 · noscript folgt dem JavaScript-Modus

HTMLPage setzt Parser.ScriptingEnabled aus options.JavaScript (Standard: aktiv).
Bei aktivem Scripting wird HTML-noscript als Rohtext geparst und erhält keinen
Renderbaum, auch ohne Skripte oder bei Skriptfehlern. JavaScript=false erhält den
HTML-Fallback. Die öffentliche, alleinstehende Parser-API bleibt standardmäßig
im deaktivierten Modus, passend zu inertem DOMParser; ScriptingEnabled=true ist
explizit möglich. DOMMarkup übernimmt die Flagge aus dem Kontextdokument für
Fragmentparsing und die unveränderte Rohtext-Serialisierung. Der Elementkatalog
beschreibt diese Semantik statt des überholten Zustands ohne JavaScript-Laufzeit.
Regressionen: NoScript (Parser/Render/Stylesheets/Controls/Fixed/Fragmente/SVG),
PageLoading (echter Mount: deaktiviert/aktiviert/Standard) und Fernweh (kein fester
JavaScript-Hinweis). Browser-Websitequellen bleiben unverändert.

## 5. Oktober 2026 · Transparente Kreisrahmen und output-Darstellung

BorderCorners zeichnet prozentuale/elliptische Rundungen auch ohne Hintergrund.
Formgeometrie und Farbfüllung werden unabhängig ausgewertet; die Mitte eines
transparenten Kreises bleibt auch mit Overflow-Maske durchsichtig. Der Rasterkey
enthält Rahmenbreiten, Farben, Alpha und Stil für Änderungen an erhaltenen Styles.
Native Rundungen und unsichtbare, transparente Flächen benötigen kein neues Raster;
Rahmenmaße werden einmal statt für jedes Subpixel berechnet.
Controls/OutputView verwendet die gemeinsame BorderBox-/BorderCorners-Darstellung
für CSS-Rahmen und Hintergründe von output. Die bisherige pauschale Unterdrückung
des output-Rahmens entfällt. Output mit Flex-Zentrierung zentriert seine Beschriftung;
DOMReconcile gibt dessen Raster bei Entfernung frei. Inputs behalten ihren Painter.
BorderCorners/Forms und die echte Fernweh-Integration prüfen Pfeil und Zähler,
transparente Pixel, Farbwechsel, native/Raster-Wechsel, Resize, Erhalt der Objekte
und Ressourcenfreigabe. Browser-HTML/CSS unverändert; native Sichtprüfung bei Tobias.

## 5. Oktober 2026 · Arbeit bei reinen Farb-/Cursor-Hovern

CSS/Stylesheet prüft Zustandsselektoren auf dem Selektorsubjekt nur an den
geänderten Hover-/Active-/Focus-Knoten und Vorfahren. Verschachtelte relationale
Selektoren, `:has()` und Zustände auf früheren Selektorteilen behalten die
allgemeine Invalidierung. Es werden keine DOM-Indizes dauerhaft zwischengespeichert.
RenderTree überspringt bei reinem Text-Paint die allgemeine Box-/Transformdarstellung;
Kontrollen und currentColor-Abhängigkeiten in Rahmen, Schatten und Rastereffekten
behalten ihren Painter. Unbeteiligte generierte Inhalte werden bei Zustandsänderungen
nicht neu ausgewertet; direkte Pseudoselektoren, betroffene generierte Nachfahren,
Custom Properties und Counter-/Sichtbarkeitsänderungen bleiben berücksichtigt.
HTMLAnimations bekommt bei Paint-Publikationen die tatsächlich recascadierten
Knoten, statt alle Seitenboxen und unbeteiligten aktiven Effekte erneut auszuwerten.
TextDecoration behält Segment-Quellen für reine Farb-/Alphaänderungen, einschließlich
Mustern und Skip-Ink. Abweichende Wort-/Lückenfarben zeichnen nur die Dekoration neu;
Geometrieänderungen und echtes Layout behalten den vollständigen Pfad.
Neue Regression HoverWork: lokale Matching-Arbeit auf langem DOM, Vergleich gegen
vollständiges Matching komplexer Selektoren, 30 Hoverpaare mit unveränderter Geometrie,
SVGs/Animationen/Zählern sowie Pseudoelement-/Control-Abhängigkeiten. Keine native
Studio-FPS-Messung; Tobias prüft das sichtbare Hoververhalten.

## 5. Oktober 2026 · Demo-Konfiguration vereinfacht

Neue HTMLPage-Mounts bleiben hinter einer weißen Fläche verborgen, bis ein
stabiles Layout und die angeforderten SVG-Uploads abgeschlossen sind.
`Presented` ist unabhängig vom geometrischen `Status=ready`; Autofokus wartet
ebenfalls auf die Anzeige. SVG/RenderQueue meldet sichtbare Anfragen unabhängig
vom Hover-Prewarm; späteres Resize und SVG-Arbeit blenden die Seite nicht aus.
Dialog-/Popover-/Fixed-Layer respektieren `PresentationHidden`. `page:SetVisible`
verbirgt bzw. zeigt alle Seitenelemente zusammen, zur atomaren Navigation mit
Wiederherstellung bei Mount-Fehlern. Neue Tests: PageLoading und SVGQueueVisibility;
PageLifecycle und Autofocus decken auch Abbruch/Resize/Fokus der ersten Anzeige ab.

`examples/StudioDemoConfig.luau` enthält nur `ActiveDemo = "HTMLPage"`.
Die Startseite wird ausschließlich mit `local WEBSITE` in
`examples/HTMLPage.client.luau` gewählt (aktuell `Fernweh`). Die SVG-Labor-Etappe
wird mit `local stage` in `examples/SVGLab.client.luau` gewählt (aktuell `S45`).
Frühere Angaben zur Website-/SVG-Auswahl in StudioDemoConfig sind historisch.
Hover-Frame-Logging samt Laufzeit-Hook/Metadaten und der temporäre
Hover-Geschwindigkeitsoverride sind vollständig entfernt; CSS-Dauern gelten
unverändert. Beide Studio-Projekte synchronisieren die Demo-Konfiguration.

## 2. Oktober 2026 · Gesamtprüfung und Reparaturen

Aktueller Stand: [Auditbericht](audit-2026-10-02/README.md), [Modulmatrix](audit-2026-10-02/module-matrix.json), [Verifikation](audit-2026-10-02/verification.md).
Root und drei Agents haben alle 284 Engine-Module erfasst und die 267 handgeschriebenen vollständig gelesen; generierte Glyphen/Website-Daten wurden über Format, Generator und Verbraucher geprüft. Tests/Historie sind ausdrücklich keine vollständig manuell gelesene Vollabdeckung.

Repariert: WordFlow-Komplexität, unabhängige Ziffernmaße, CSS all/Clipzentren/Backgroundposition, Scroll-Cleanup/Snap-none, Form-Paint-Invalidierung, responsive Textauswahl, lazy HTMLPage-Import/Match-Reuse, Canvas-Budget/Initialisierungsrollback/Hintergrundreset, Medien-No-op-Paints, SVG-Reentry-Budgets/kooperative Alpha-Crops sowie Steps-Easing vor Delays. Canvas hat jetzt eine explizite Grenze von 65.536 Pfadpunkten. Details und größere offene Architekturthemen stehen im Bericht.

Final: 148 HTML-Suiten, komplette SVG-Suite, statische Prüfung, vier Website-Generatortests, 35 SVG-Infrastrukturchecks und sieben Rojo-Builds bestanden. RenderingLifetimes war in der Baseline intermittierend rot, blieb unverändert und besteht in isolierten sowie beiden vollständigen Nachläufen. Alte gelöschte Websitepfade im SVG-Runner wurden durch nicht veröffentlichte Fixtures ersetzt. Der historische Benchmark mit sechs Zuständen ist nicht mit der aktuellen Acht-Zustands-Fixture vergleichbar; eine separate Snapshot-Baseline und --baseline-file erhalten den alten Stand.

**Letzte Nutzeranweisung: FPS-Tests einfach lassen; Tobias übernimmt diese selbst. Keine weiteren FPS-/Performance-Messläufe automatisch starten.** Keine nativen FPS-Zahlen behaupten. Schriftprofile, Demoauswahl HoverTests, 1× Hover, deaktivierte Frame-Prints, Resize-Freigabeverhalten und vorhandene Webseiten wurden erhalten.

Die nachfolgenden Einträge sind historische Übergaben und teilweise inhaltlich überholt.

S45-Nutzerkorrektur: use-x/y muss userSpaceOnUse-Masken mitverschieben.
Document.UseTranslation + Mask-Mapping korrigiert; Vorlage unverändert,
der gelbe Stern soll wie im Browser angeschnitten sein. Regressionen: vier
Maskeneinheiten-Kombinationen und konkrete S45-Pixel. Erneuter Sichtvergleich offen.

Aktuell 14.09.2026: S43/S44 zum Fortfahren bestätigt. S45 auf „gut“ umgesetzt.
StudioDemoConfig: S45. Browser: examples/svg-tests/s45.html.
Vier Kombinationstafeln: Blume/use/Hover, Diagramm/Textpfad, Symbol-/Pattern-/Maskkarte,
interaktive Filter-/Animationsszene mit gemeinsamem JavaScript-Verlauf.
1/2/3 Größen, P Start/Pause, Z/X/C/V/B feste Zeiten, R Reset. Start pausiert.
Generator: scripts/sync-svg-acceptance.py. Quellen: AcceptanceSources.luau.
Tests: SVGAcceptance, kombinierter S45-Zweig in SVGInteractiveHost,
scripts/test-svg-acceptance-browser.cjs (DOM-Mocks). Echte Rastervorschau:
build/svg-s45-preview.png. Nativer visueller S45-Vergleich noch offen.
Details: docs/SVG-S45.md. Maßgebliche Übersicht der offenen Funktionen:
docs/SVG-SUPPORT.md. Der gesamte SVG-Plan ist ausdrücklich noch nicht abgeschlossen.
Native Browser-/Studio-Automation bleibt wegen vorheriger automatischer
Freigabeablehnung aus; Nutzer öffnet die lokale Vergleichsseite manuell.
Nächster Schritt: S45-Nutzervergleich; danach Restarbeiten anhand Supportkatalog.
Ältere Statusabschnitte darunter sind Historie.


Aktuell 14.09.2026: S41/S42 mit „alles gleich“ zum Fortfahren bestätigt.
Auf „ok“ S43/S44 implementiert, nativer visueller Vergleich noch offen.
StudioDemoConfig: S43_S44. Browser: examples/svg-tests/s43-s44.html.
Acht HTML-Tafeln, elf echte SVG-ImageLabels über Shared SceneBuilder/Embedded.
Serielle RenderQueue mit Coalescing, Pixelcache, Textur-Reuse und Speicherlimits.
1/2/3: 240/480/960 px, C: Resize, R: 20 komplette Seiten-Neuaufbauten in Studio.
Tests: SVGIntegration, SVGHTMLIntegration, SVGIntegrationController,
scripts/test-svg-integration-browser.cjs; Generator sync-svg-integration.py.
Umfang/Grenzen/Messwerte: docs/SVG-S43-S44.md. Vorschau: build/svg-s43-s44-preview.png.
SVG-Cascade/IDs in HTML derzeit je SVG gekapselt; kein voller gemeinsamer DOM,
keine automatische eingebettete Skript-/Animationslaufzeit, kein Geometriecache.
Keine nativen Browser-/Studio-Automationen: vorherige automatische Freigabeprüfung
hat Browsernavigation abgelehnt. Nutzer öffnet die Vergleichsseite manuell.
Nach visuellem Nutzervergleich: S45, mit ehrlichem Audit aller Restfunktionen.
Ältere Statusabschnitte darunter sind Historie.


Aktuell 14.09.2026: Auf „gut mach“ S41/S42 umgesetzt, visueller Vergleich offen.
StudioDemoConfig: S41_S42. Browser: examples/svg-tests/s41-s42.html.
S41 echte begrenzte JS-AST-Ausführung via ScriptSyntax/ScriptVM/ScriptDOM, gleiche
JS-Quellen in Browser und Roblox. S42 Conditional/switch/systemLanguage,
view-Fragmente, Metadaten/Ressourcendiagnosen und expliziter Legacy-Audit.
R Reset, 1/2/3 Größe; keine P-Starttaste nötig. Vier Tafeln reagieren auf Klick.
Die letzte Tafel hat absichtlich missing-use-target. Sprache im Lab en.
Generator: scripts/sync-svg-scripting.py. Tests: SVGScript, SVGScriptScenes,
SVGInteractiveHost + scripts/test-svg-scripting-browser.cjs (DOM-Mocks).
Details/Restumfang: docs/SVG-S41-S42.md. Vorschau: build/svg-s41-s42-preview.png.
S39/S40 zum Fortfahren freigegeben, keine zusätzliche Vollabnahme behaupten.
Nächste Etappen nach Nutzervergleich S43/S44; ältere Abschnitte sind Historie.

Aktuell 14.09.2026: S37/S38 inklusive Korrekturen vom Nutzer mit
„perfekt alles passt weiter“ freigegeben. S39/S40 implementiert im dokumentierten
Teilumfang; manueller Browser-/Studio-Vergleich offen.
StudioDemoConfig: S39_S40. Vergleich: examples/svg-tests/s39-s40.html.
P Start/Pause, Z/X/C/V/B feste Zeiten 0/.25/.5/.75/1 s, R Reset, 1/2/3 Größe.
Neue AnimationTiming/AnimationValue/Animation/AnimationCSS-Module, animierte
Document-Overlays, gemeinsame Lab-Uhr und acht neue Vergleichstafeln.
Generator: scripts/sync-svg-animation.py. Umfang, Tests und explizite Grenzen:
docs/SVG-S39-S40.md. Nächstes Paket nach Abnahme: S41/S42.
Ältere Statusabschnitte darunter sind Historie.

S37/S38 Performance-Fix: InputChanged-Moves werden pro Frame zusammengefasst,
Capture umgeht unnoetige synchrone Hit-Builds, Worker verwirft nicht jede laufende
Ziehzeichnung. Wiederkehrende Bilder in globalem 8-MiB/24-Eintrag-Cache; Capture-
Zwischenstaende werden nicht eingelagert. Raster.paint nutzt Span-Differenzen
fuer vollstaendige Innenpixel bei unveraenderten 16 AA-Samples. Acht Tafeln sind
bytegenau gleich geblieben; CLI Polygon ca. 19→6.6 ms, Verlauf 55→35 ms,
warme Farbwechsel ohne Rasterarbeit. Tests siehe SVG-S37-S38.md. Studio erneut
Stop/Play und Nutzervergleich abwarten; keine Studio-FPS gemessen.


S37/S38 HTML-Interaktionskorrektur: Generator nutzt jetzt eigenstaendige srcdoc-
Frames mit eingebettetem attach-Skript. Kein Elternzugriff auf contentDocument
und keine SVG-Blob-Navigation. Status/Hotkeys per postMessage, mit Token und
Fensterquelle geprueft. Browser-Logiktest: node scripts/test-svg-runtime-browser.cjs
(mit DOM-Mocks, kein automatisierter nativer Browserlauf). User soll HTML neu laden.


S37/S38-Nutzerkorrektur: Hitboxen lagen um den GUI-Inset zu hoch.
Interactive.mousePosition zieht jetzt GuiService:GetGuiInset von GetMouseLocation
ab; Touch InputObject.Position wird nicht doppelt korrigiert. ScreenCTM rechnet
GUI-AbsolutePosition wieder in Bildschirmkoordinaten um. Host-Regression bildet
negative ScreenGui-AbsolutePosition trotz IgnoreGuiInset sowie Scrollen ab.
Nutzer muss die Korrektur nach Stop/Play noch visuell bestätigen.


Aktuell 14.09.2026: S35/S36 nach Spot-Kantenkorrektur mit „gut weiter“ freigegeben.
S37/S38 implementiert; Browser-/Studio-Sicht- und Eingabevergleich noch offen.
StudioDemoConfig: S37_S38. Vergleich: examples/svg-tests/s37-s38.html.
Neue SVG/Events, Session und Queries; eigener interaktiver Lab-Host und acht
Tafeln. Farbwechsel behalten die Treffergeometrie, gleich große Rasterupdates
verwenden dasselbe EditableImage. Generator: sync-svg-runtime.py.
Tests: SVGRuntime und SVGInteractiveHost (inkl. 20 Resets/Abbruch/Freigabe).
Details/Restumfang: docs/SVG-S37-S38.md. Keine JS-/Script-Vollunterstützung;
Callback-Labor, use-Retargeting und HTML-Integration bleiben getrennte Aufgaben.
Nach dem Nutzervergleich folgt S39/S40. Ältere Statusabschnitte sind Historie.


Spot-Kantenkorrektur nach Nutzervergleich: FilterLighting.shade verwendet jetzt
Skias linearen Kegelkantenübergang über 0.016 in Cosinuskoordinaten statt eines
harten Cutoffs. Gilt für diffuse und spiegelnde Beleuchtung; Diffuse-Alpha bleibt
1, Specular-Alpha folgt weiter dem maximalen Lichtfarbkanal. Keine Bildweichzeichnung.
Referenz: https://github.com/google/skia/blob/main/src/sksl/sksl_rt_shader.sksl
($spotlight_scale). Analytische Tests prüfen Außenkante, Viertel-/Halblicht und
volle Intensität inklusive premultiplizierter Specular-Farbe.


Aktuell 14.09.2026: S33/S34 mit „gut weiter“ zum Fortfahren freigegeben.
S35/S36 implementiert; nativer Sicht-/Pointervergleich offen. StudioDemoConfig
S35_S36, Vergleich examples/svg-tests/s35-s36.html. FilterLighting ergänzt
Diffuse/Specular mit Distant/Point/Spot; SVG/HitTest liefert geometrische
Treffer mit pointer-events, Clips, Maskensemantik und Rasterbildalpha.
Lab nutzt UserInputService, passive Tafeln und Trefferzeilen ohne neue Rasterjobs.
Generator sync-svg-lighting-hit.py; Tests SVGLightingHit.luau plus Controller.
Vorschau build/svg-s35-s36-preview.png: acht echte Luau-Rastertafeln geprüft.
Grenzen: Text noch Glyphenkontur statt Zeichen-Trefferzellen, SVG-Bildretargeting
und use/Eventpfad offen. S37/S38 nach Nutzervergleich. Details: SVG-S35-S36.md
(im Projekt unter docs/). Ältere Statusabschnitte sind Historie.


Aktuell 14.09.2026: S31/S32 vom Nutzer mit „perfekt weiter“ freigegeben.
S33/S34 implementiert, nativer Sichtvergleich offen. StudioDemoConfig S33_S34;
Vergleich examples/svg-tests/s33-s34.html. Neue FilterKernel/FilterMorphology/
FilterNoise; Filter/FilterPixels und Runner erweitert. Acht Tafeln, gleicher
RGBA-Resolver plus analytische R/G-Rampe. Generator sync-svg-kernel-filters.py,
Tests SVGKernelFilters.luau. SVG normal/-O2 und HTML-Regressionen bestanden;
480-Pixel-Luau-Vorschau build/svg-s33-s34-preview.png angesehen.
Grenzen ausdrücklich beibehalten: feImage-Vektorverweise noch nicht unterstützt;
SVG-1.1-/Skia-Rauschinitialisierung statt neuerer Entwurfsvariante; diskrete
Morphologie/gedrehte Kanten. S33 nicht als vollständig erledigt markieren.
Details in docs/SVG-S33-S34.md (aus docs: SVG-S33-S34.md).
Nächstes Paket S35/S36 nach Nutzervergleich. Vorherige Statusabschnitte sind Historie.


Abschlussprüfung S31/S32: SVG-Suite normal und -O2 bestanden, einschließlich
Controller-Neuaufbau/Abbruch/Freigabe. Acht finale 480-Pixel-Tafeln aus dem echten
Luau-Rasterrenderer in build/svg-s31-s32-preview.png angesehen. HTML-Regressionen,
beide Filtergenerator-Checks und Projektaudit bestanden: 344 Luau, 6 JS,
55 HTML, 259 lokale Referenzen, 7 Projekte, 126 HTML-Fonts. Workspace/SVGLab/
HTMLPage gebaut. Laufende Rojo-API liefert S31_S32 und die neuen Quellen/Module.
Native Browser-/Studio-Sichtprüfung des Pakets bleibt beim Nutzer.

Aktuell S31/S32: SVGStage=S31_S32, acht Tafeln in examples/svg-tests/s31-s32.html.
S29/S30 nach direkter Filterreferenz korrigiert und zum Fortfahren freigegeben.
Neue FilterOps/FilterBlur/FilterPixels; Filter.build/Style/Raster und Runner
integriert. Räumlicher Graph auf premultiplizierten Float32-Ausschnitten,
Gaußfaltung mit 3-sigma-Radius entlang transformierter Achsen, bilineare Offsets,
Flood/DropShadow/Composite/Merge. Reine Farbgraphen bleiben punktweise.
Quellen SpatialFilterSources/CompositeFilterSources/SpatialCompositeSources,
Generator scripts/sync-svg-spatial-filters.py. Tests SVGSpatialFilters.luau.
Nullfilter-Test vergleicht sichtbares RGB und jedes Alpha; bei Alpha exakt null
werden nur verborgene RGB-Werte ignoriert. Keine Änderung sichtbarer Pixel.
S31/S32-Stand/Grenzen siehe SVG-S31-S32.md; edgeMode duplicate/wrap und
außerhalb der Szenentextur liegende Quellpixel bleiben offen. Nutzerabnahme
steht aus. Browser-Steuerung file:// weiterhin nicht über Umwege versuchen.

## Vorheriger Stand

S29-Nachkorrektur: Nutzer sieht unten in S29-text-order nichts. Filter href
wird im Zielbrowser nicht unterstützt und ist laut CSSWG 22.07.2026 gestrichen.
Gemeinsame Tafel referenziert jetzt direkt #base; identische Quellen für beide
Renderer. Original separat S29-filter-href-known-difference.svg. Engine href
bleibt Legacy-Erweiterung, keine Browserparitätszusage. Siehe SVG-S29-S30.md.


Abschlussprüfung: vollständige SVG-Suite normal und -O2 bestanden; acht finale
480-Pixel-Rastertafeln erzeugt und geprüft. HTML-Suite und Generator-Abgleiche
bestanden. Projektaudit: 337 Luau, 6 JS, 52 HTML, 256 lokale Referenzen,
7 Rojo-Projekte, 126 HTML-Fonts. Workspace/SVGLab/HTMLPage gebaut.
Rojo-API bestätigt S29_S30, FilterSources und den aktuellen Filtercode.

Aktuell S29/S30: siehe SVG-S29-S30.md. SVGStage=S29_S30, acht Tafeln in
examples/svg-tests/s29-s30.html. S27/S28-Kern nach Zeilenkorrektur zum Fortfahren
freigegeben; CSS-Zeilenumbruch und andere alte Reste bleiben offen. FilterColor
und Filter sind neu, Raster/Compositing/Resources/Style/Text/Viewports integriert.
Filter setzt isolierte SourceGraphic vor Clip/Mask/Opacity um. feBlend für in2
aus S32 vorgezogen. Sources FilterGraphSources/FilterColorSources/FilterSources,
Generator scripts/sync-svg-filters.py, Tests tests/SVGFilters.luau.
Browser/Studio S29/S30 noch nicht visuell bestätigt; lokale Luau-Montage geprüft.
Räumliche Filter, Background/FillPaint/StrokePaint, mehrere CSS-Filter und
Subpixel-Regionskanten bleiben explizit offen. Keine Browser-Sperre umgehen.

## Vorheriger Stand S27/S28

S27-Nachkorrektur: Nutzerbild zeigte rechts "Zeile A Zeile B Zeile C" horizontal
statt drei CSS-pre-Zeilen. Die Engine-CSS-Zeilenimplementierung ist damit NICHT
browsergleich bestätigt. Gemeinsame S27-lines-Tafel jetzt links relative dy-
tspan-Zeilen, rechts absolute y-tspan-Zeilen. Ursprüngliche CSS-Probe bleibt als
S27-lines-css-known-difference.svg vom Generator erzeugt. Kein Engine-Fix für
CSS-Zeilen behauptet. Generator-Check, Audit und Workspace-Build bestanden;
native Sichtprüfung der korrigierten Vergleichstafel weiter offen.

Aktuell S27/S28-Kern implementiert; Nutzer bestätigte S25/S26 nach der
Orientierungskorrektur mit „passt weiter“. SVGStage=S27_S28. Vergleich:
examples/svg-tests/s27-s28.html, acht Tafeln/16 EditableImages, Diagnostics leer.
Neues SVG/TextPath: Arc-Length-Segmente, binäre Punkt-/Tangentenabfrage,
href/xlink/path, referenzierter Eigen-Transform, startOffset, Seitenumkehr,
offene/geschlossene Pfade. Text.expand erkennt textPath und pfadgebundene Runs;
context.Document stammt aus Viewports und wird auch für Bounds weitergereicht.
Textkonturen bleiben echte Pfade. ClipPath.silhouette überspringt Textknoten
sicher und lässt text/textPath für den gemeinsamen Besucher stehen. So gehen
Textclips, Textmasken und Text in Mustern. CSS pre + line-height erzeugt
horizontale Zeilen; kein automatischer inline-size-Wortumbruch.
Weitere CSS-only-Textproperties (white-space/line-height/font-kerning/
font-variant-ligatures) werden nicht als Präsentationsattribute akzeptiert;
S25-Quellen und Tests entsprechend auf style umgestellt.
Generator scripts/sync-svg-text-resources.py; Sources PathTextSources,
TextResourceSources, TextPathResourceSources. Native Browser-SVGs mit denselben
TTF-Dateien und denselben S21-PNG-Pixeln, keine gerasterte Ersatzreferenz.
SVG normal/-O2, HTML-Suite, Generator-Checks, Audit (331 Luau,6 JS,49 HTML,
253 lokale Referenzen,7 Projekte,126 HTML-Fonts), drei Builds bestanden.
Lokale echte Luau-Montage build/svg-s27-s28-preview.png mit acht Tafeln angesehen.
Rojo 127.0.0.1:34872 liefert S27_S28/TextPath/TextPathResourceSources.
Browser-file://-Steuerung war vorher gesperrt, kein Umweg oder neuer nativer
Browser-/Studio-Test. Nutzer öffnet den Dateilink und prüft mit Stop → Play.
S27/S28 NICHT vollständig: siehe SVG-S27-S28.md. Insbesondere automatische
Umbrüche, vertical textPath/method=stretch/komplexe Textfälle; Textfilter mit
S29–S31; foreignObject braucht gemeinsame HTML-Pixel-/Paintliste (HTMLPage baut
derzeit GUIs, keine Rasterausgabe). Kein darübergelegtes GUI als Ersatz.
foreignObject meldet foreign-object-raster-bridge-unavailable. Frühere S26-
Shaping/Bidi-Reste und alle bisherigen SVG-Reste bleiben verbindlich offen.
Nach visueller Abnahme als nächstes Filtergraph S29/S30 sinnvoll.
Alle folgenden Abschnitte sind historisch.

S25/S26-Nachkorrektur: Nutzer meldete in der vertikalen Tafel drei gedrehte
Läufe im Browser, aber rechts aufrechte Zeichen in Roblox. Ursache war das
CSS-only-Property text-orientation als SVG-Attribut. Fixture/Generator nutzen
jetzt style="text-orientation:upright"; Style ignoriert das rohe Attribut.
Regression für Attribut vs. CSS und 32px-Upright-Advance hinzugefügt.
Neuer visueller Vergleich bleibt offen; Rojo liefert korrigierte Quellen.

Aktuell S25/S26-Kern implementiert; S23/S24 vom Nutzer mit „passt weiter“ visuell
bestätigt. SVGStage=S25_S26, Browserreferenz examples/svg-tests/s25-s26.html.
Acht Tafeln/16 EditableImages, leere Diagnostics erwartet. Native Studio-Abnahme
noch offen. Allgemeiner Outline-Text in SVG/Text, Fontdaten SVG/TextFont:
Source Sans Pro Regular/Bold/Italic/BoldItalic, alle Glyphen exportiert mit
scripts/export-svg-font.py (fontTools lokal build/python-svg-fonts). Lizenz und
Provenienz examples/fonts/README.md. Browser enthält dieselben TTF-Bytes als
@font-face und native text/tspan, keine ausgetauschten Kontur-Demos.
Document erhält Textknoten; Style kennt Textattribute; Viewports bekommt optional
14. Argument Text. Text.expand erzeugt Gruppen/Pfade in Benutzerkoordinaten;
Bounds erhält context.TextExpand; gemeinsame TextRoot-Inkbox für Verläufe.
Kontur/Alpha, Positionen, tspan, Anker, Baselines, Leerraum/Abstände, textLength,
Rotation, echte Font-Schnitte, GPOS-Pair-Kerning, GSUB-Standardliga und einfache
kanonische Kompositionen implementiert. Source-Sans-Regular hat ff/ft/fft-Ligaturen,
keine fi-Ligatur! HarfBuzz-Oracle AV = 1045/1000 em, als Test hinterlegt.
S26 NICHT vollständig: vollständiges Bidi/komplexe Formung/Mark-Positionierung,
CJK-Vertikalschrift, mehrzeiliger Leerraum, komplexe Baselines und weitere Grenzen
stehen in SVG-S25-S26.md. direction:rtl + lateinischer Lauf sowie bidi-override
sind vorhanden, nicht mit allgemeinem Bidi verwechseln. Weitere Fontfamilien via
ResolveFont möglich, sonst Diagnose/Fallback. HTML-Fontkalibrierung nicht geändert.
SVG normal und -O2 bestanden, lokale Luau-Rastermontage acht Tafeln angesehen:
build/svg-s25-s26-preview.png. HTML-Suite, Audit (326 Luau,6 JS,46 HTML,250 lokale
Referenzen,7 Projekte,126 HTML-Fonts), Generator-Checks und drei Builds bestanden.
Rojo auf 127.0.0.1:34872 liefert S25_S26/Text/TextTypographySources/Font-Faces.
Browser-file://-Steuerung war vorher gesperrt, kein Umweg/keine native Browser-
oder Studio-Prüfung in dieser Runde; der Nutzer öffnet den HTML-Dateilink.
Nach Sichtabgleich S27/S28 planen, S26-Rest bleibt im Gesamtumfang verbindlich.
Alle folgenden Statusabschnitte sind historisch.

Aktuell S23/S24 implementiert; S21/S22 vom Nutzer mit „passt weiter“ visuell
bestätigt, ohne neuen Clientbericht. SVGStage=S23_S24, Browserreferenz
examples/svg-tests/s23-s24.html. Sieben Tafeln/14 EditableImages, keine
Diagnosen erwartet. Neue Module SVG/Mask und Blend; Masken via Resources,
CSS über Style/Rendering. mask-image mit einzelner SVG-mask-URL, mask-Shorthand
URL/none, mask-mode/type; Regionen, Einheiten, verschachtelte Masken und
sRGB/linearRGB-Luminanz. Blend enthält die 16 CSS-Level-1-Modi. Compositing
behandelt Isolation, Teilalpha und Clip→Maske→Opacity→Blend. Clips allein
isolieren nicht mehr: ursprünglichen tatsächlichen Hintergrund kopieren und
beschnittenes Resultat vormultipliziert interpolieren. Volltransparente RGB-
Reste werden dabei genullt (S22-Regression). HTML-Hintergrundpixel fehlen im
bestehenden GUI-Paint-Pfad; keine Ersatzfarbe erfinden, S43-Rest dokumentiert.
Mask-Shorthand-Komplettgrammatik/mehrere Lagen, Text/Filter/Animation und
CSS-Level-2-Blends bleiben explizite spätere Aufgaben (SVG-S23-S24.md).
Generator sync-svg-masks-blending.py übernimmt unveränderte S21-Pixelquelle.
SVG normal und -O2 plus lokale Vorschau bestanden; HTML-Suite, Audit (313 Luau,
6 JS,43 HTML,247 Referenzen,7 Projekte,126 Fonts), Generator --check und drei
Rojo-Builds bestanden. Rojo-API liefert neue Module und S23_S24.
Lokale Vorschau build/svg-s23-s24-preview.png wurde angesehen. Browser-file://-
Steuerung war bereits gesperrt; kein Umweg/keine neue Browserprüfung. Studio
nicht bedient, neuer visueller Nutzervergleich offen. Nächstes Paket nach
Abnahme S25/S26 (SVG-Text), S01-Text-Machbarkeit davor nachlesen.
Alle folgenden Statusabschnitte sind historisch.

Aktuell S21/S22 gemeinsam implementiert; Nutzer hat nach S19-Rot-Korrektur
„weiter“ gesagt. Kein neuer Clientbericht für S19/S20. SVGStage=S21_S22,
Browserreferenz examples/svg-tests/s21-s22.html. Sechs Tafeln/zwölf Bilder,
keine Diagnosen erwartet. Neue Engine-Module Image, ImageAssets und ClipPath.
Resources bindet Bild-/Clip-Szenen über den bisherigen Besucher ein;
Compositing isoliert Clip/Opacity, Raster wendet Clip-Alpha an. Neue
Document.ImageResource-API und options.ResolveImage für dekodierte RGBA-Daten;
SVG-Dateien benutzen den bestehenden Dokumentresolver. Temporäre native
EditableImages werden von ImageAssets auch bei Lesefehlern freigegeben.
Quellbild S21-source.png (64x48 RGBA) ist deterministisch generiert, im Labor
identischer dekodierter Pixelbuffer; kein echtes Asset hochgeladen. Nativer
Asset-API-Clienttest daher separat offen. Sechs Quellen via
sync-svg-images-clips.py, Ressourcen fließen in SourceSHA256 ein.
Referenz-SVG als image erbt kein Eltern-CSS. Automatische Bildmaße fließen in
Gruppen-/Transform-Bounds ein. Details und explizite Restfälle in SVG-S21-S22.md.
Lokale CPU-Vorschau build/svg-s21-s22-preview.png visuell geprüft. Browser-
Steuerung blockiert file:// per URL-Sicherheitsprüfung; KEIN Umweg und kein
Browservergleich behaupten. Nutzer kann HTML selbst öffnen. Studio nicht
bedient, visueller Vergleich offen. Nächstes Paket nach Abnahme S23/S24.
SVG normal/-O2, HTML-Suite, Projektaudit, Generatorprüfung und drei Rojo-Builds
bestanden; laufende Rojo-API liefert die neue Etappe.
Alle folgenden „Aktuell“-Abschnitte sind historische Übergaben.

Aktuelle S19-Korrektur: Nutzer meldet rechts Rot im Browser, während Roblox
Grün zeigte. Pattern.bind behält jetzt für referenzierte Inhalte den Stil
ihres tatsächlichen Inhalts-Owners (childStyle), auch über href-Ketten.
Die verweisende Definition bestimmt weiterhin Kachelmaße/Transform. Eigene
Ersatzkinder bekommen weiterhin ihren eigenen Elternstil. Keine Änderung an
Gradient- oder use-Vererbung; dort nicht ungeprüft dieselbe Regel übernehmen.
S19-nested bleibt unverändert als Regression: beide Seiten #ef4444, rechts
Alpha 153 (60 %). Caption/Generator/Tests/Etappendoku korrigiert. SVG-Suiten
normal/-O2 und zwei betroffene Builds bestanden. Erneute Sichtabnahme offen.
Die frühere grüne Gesamtvorschau ist historisch; aktuelle korrigierte Tafel:
build/svg-pattern-style-fixed.png.

Aktuell S15/S16 gemeinsam implementiert und vom Nutzer visuell bestätigt („ja passt“).
S01–S16 bestätigt, S14–S16 ohne neuen Clientbericht. Nutzer will künftig größere
Etappenpakete. SVGStage=S15_S16, Browser s15-s16.html. Sechs Tafeln/zwölf Bilder;
zwei erwartete Diagnosen nur in S16-external: missing-use-target und cyclic-use-reference.
Neue Datenmodule CSS/Selectors, Variables, AuthorRules; SVG/Style und Document.
Document.prepare berechnet unabhängige Stil-/use-Bäume, ohne Quell-DOM zu ändern.
Viewports erhält Document als elftes optionales Argument. Externe Referenzen über
options.Resolve, im Labor Sources.Documents. Originalknoten bestimmen Selektor-
Matching, use-Eltern bestimmen Vererbung. Style registriert bisherige SVG-Properties.
StylesUseSources/CSSSources/UseSources über sync-svg-styles-use.py. Browsertafeln
in isolierten Blob-SVG-iframes; externes Beispiel dort lokal eingebettet.
Grenzen, Tests und API in SVG-S15-S16.md. Insbesondere CSS4-/At-Regel-Restumfang,
spätere Text/Gradient/Filter-Properties, Live-Beobachtung und HTML-Paint offen;
kein Anspruch auf vollständiges Browser-CSS. Nächstes vorgesehenes Paket:
S17/S18 (lineare und radiale Verläufe), noch nicht begonnen. Ältere offene S14-Angaben historisch. Prüfergebnisse in PROJECT-REVIEW.md.

Aktuell S14 implementiert, visueller Nutzervergleich offen. S01–S13 bestätigt;
S13 ohne neuen Clientbericht. SVGStage=S14, Browser s14.html. Rendering löst
Opacity/Display/Visibility/Overflow/PaintOrder/Rendering-Hinweise einschließlich
Inline und eigenschaftsabhängiger Vererbung auf. Viewports-Laboradapter erhält
Rendering als optionales zehntes Argument und baut zusätzlich scene.RenderTree.
Compositing.draw isoliert Opacity in CPU-Puffern, Raster ordnet Paint um und
unterstützt drei Abtastqualitäten. Shapes bleibt für bisherige Tests erhalten.
TransformBounds ignoriert display:none, nicht visibility:hidden.
RenderingSources über sync-svg-rendering.py: vier Tafeln, acht Bilder, keine
Diagnosen erwartet. Grenzen in SVG-S14.md: 32 MiB Live-Puffer, 256 Ebenen,
8-Bit-Komposition, endliche Rootfläche, Hinweise für spätere Text/Bilder noch ohne
Rendererwirkung. Marker und allgemeine CSS-/HTML-Paint-Anbindung weiter offen.
Nach Sichtabnahme S15 (vollständige SVG-CSS-Anbindung). Ältere offene S13-Angaben
sind historisch. Prüfung/Build/Rojo in PROJECT-REVIEW.md.

Aktuell S13 implementiert, visueller Nutzervergleich offen. S01–S12 bestätigt;
S12 ohne neuen Clientbericht. SVGStage=S13, Browser s13.html. Matrix erweitert
Viewport/Raster um affine Kreuzterme, Transform parst Listen/Inline-Eigenschaften,
TransformBounds misst Form-/Gruppenreferenzboxen. Viewports-Laboradapter erhält
optional Transform/TransformBounds; frühere Stufen bleiben ohne diese Argumente.
Gedrehte Viewport-Clips werden als Vierecke pro Scanline geschnitten. Non-scaling
stroke entsteht im Ausgaberaum, normale Konturen lokal. TransformSources über
sync-svg-transform.py: vier Tafeln, acht Bilder, keine Diagnosen erwartet.
Details und explizite Restfälle in SVG-S13.md: allgemeine CSS-/HTML-Paint-Anbindung,
inherit/dynamische Styles, hostabhängige stroke-box mit non-scaling-stroke sowie
CSS-Wurzel-Layoutbox-Sonderfälle bleiben offen. S12-miter-clip/arcs weiter offen.
Nach visueller Abnahme folgt S14 (Gruppen/Deckkraft). Ältere offene S12-Statusangaben
sind historisch. Tests/Bauten und Rojo-Verifikation in PROJECT-REVIEW.md.

Aktuell S12 implementiert, visueller Nutzervergleich offen. S01–S11 bestätigt;
S11 ohne zusätzlichen Clientbericht. SVGStage=S12, Browser s12.html. Stroke.build
zeichnet butt/round/square und miter/round/bevel mit Miterlimit. Dashes unterstützt
signierte/prozentuale Offsets, Nullstriche mit Kappen und pathLength-Kalibrierung.
Innere Joins werden durch Segmentrechtecke abgedeckt; keine künstliche Miter-Spitze
an kurzen Segmenten. StrokeSources über sync-svg-stroke.py: vier Tafeln, acht
Bilder, keine Diagnosen erwartet. Details, Budgets und Prüfungen in SVG-S12.md.
SVG2-miter-clip/arcs sind explizit noch offen; HTML-Paint/CSS ebenfalls. Nach
Sichtabnahme folgt S13 (Transformationen). Ältere offene S11-Statusangaben historisch.

Aktuell S11 implementiert, visueller Nutzervergleich offen. S01–S10 bestätigt;
S10 ohne zusätzlichen Clientbericht. SVGStage=S11, Browser s11.html. Paint erbt
fill-rule und stroke-dasharray. Raster wendet evenodd nur auf Füllung an, Stroke
bleibt nichtnull-Vereinigung. PathMetrics parst pathLength für Grundformen/Pfade,
misst die flachen Konturen samt Z und kalibriert Nicht-Prozent-Distanzen. Dashes
teilt Konturen für einfache butt-Muster mit Offset 0; dieser Teil von S12 wurde
für den sichtbaren pathLength-Test vorgezogen. Geschlossene Nähte/Null-Lücken
werden verbunden, Rundungsreste an Segmentgrenzen eingeschnappt. FillSources
über sync-svg-fill.py, drei Tafeln, sechs Bilder, keine Diagnosen erwartet.
Details und Grenzen in SVG-S11.md. Nach Abnahme folgt S12: vollständige Kappen,
Verbindungen/Miterlimit, dashoffset und degenerierte Konturen. HTML-Paint/CSS offen.
Alle älteren offenen S10-Statusangaben sind historisch.

Aktuell S10 implementiert, visueller Nutzervergleich offen. S01–S09 bestätigt;
S09-Bericht in SVG-S09.md. SVGStage=S10, Browser s10.html. Path liest A/a mit
kompakten einzelnen 0/1-Flags; relative Werte betreffen nur den Endpunkt.
Arc.resolve berechnet Mittelpunkt/Winkel und korrigierte Radien. Curves tastet
Bögen nach Skalierung mit 0,125-Pixel-Mittellinientoleranz ab. Drei Quellen in
ArcSources über sync-svg-arcs.py, sechs Bilder und keine Diagnosen erwartet.
Grenzen/Prüfungen in SVG-S10.md. Nach Sichtvergleich folgt S11 (Füllregeln,
Löcher, Pfadrichtung und pathLength). Allgemeines HTML-Paint/CSS weiter offen.
Alle älteren offenen S09-Statusangaben sind historisch.

Aktuell S09 implementiert, visueller Nutzervergleich offen. S01–S08 bestätigt;
S08-Bericht in SVG-S08.md. SVGStage=S09, Browser s09.html. Path speichert nun
C/S/Q/T als Kontrollpunkte in part.Curves[Endpunktindex], neben den bisherigen
Points. Curves.flatten unterteilt beim Rendern nach Ausgabeskalierung; Raster
nutzt die erzeugten Konturen. Kontrollpunktspiegelung wird nach Linien/M/Z und
beim Wechsel der Kurvenfamilie zurückgesetzt. Drei Quellen in CurveSources über
sync-svg-curves.py. Erwartet sechs Bilder, keine Diagnosen. Bekannte Grenzen und
Prüfungen in SVG-S09.md. Nach Sichtvergleich folgt S10 (elliptische A/a-Bögen).
Allgemeine HTML-Paint-/CSS-Anbindung weiterhin offen; ältere S08-Angaben historisch.

Aktuell S08 implementiert, visueller Nutzervergleich offen. S01–S07 bestätigt;
S07-Clientbericht in SVG-S07.md. SVGStage=S08, Browser s08.html. SVG/Path parst
M/L/H/V/Z in beiden Schreibweisen, implizite Wiederholung, kompakte Zahlen und
mehrere Teilpfade mit Fehlerdiagnosen/Budgets. Geometry delegiert path an Path;
Raster malt alle Teilkonturen mit einer gemeinsamen Füll-/Konturoperation.
Drei exakte SVG-Quellen in PathSources über sync-svg-paths.py. Erwartet sechs
Bilder und keine Diagnosen. Quellen geben Stage/Title an den Laboradapter weiter.
Allgemeine HTML-Paint-/CSS-Anbindung weiterhin offen. Nach Sichtvergleich folgt
S09 (kubische/quadratische Kurven). Ältere offene S07-Angaben sind überholt.

Aktuell S07 implementiert, visueller Nutzervergleich offen. S01–S06 bestätigt;
S06-Bericht in SVG-S06.md. SVGStage=S07, Browser s07.html. Paint.luau verwendet
den gemeinsamen CSS/Color-Parser; vererbt fill/stroke/color/Alpha/Strichbreite,
löst currentColor erst bei Verwendung auf und gibt RGBA an Raster weiter.
Viewports-Laboradapter optional um Paint ergänzt; frühere Stufen bleiben nutzbar.
Drei exakte Quellen in PaintSources über sync-svg-paint.py. Erwartet sechs Bilder,
keine Diagnosen. Allgemeine CSS-Kaskade und HTML-Paint weiterhin offen. opacity
auf Elementen/Gruppen folgt in S14; S07 betrifft fill-/stroke-opacity. Nach visueller
Abnahme folgt S08 (M/L/H/V/Z-Pfade). Ältere offene S06-Angaben sind überholt.

Aktuell S06 implementiert, visueller Nutzervergleich offen. S01–S05 bestätigt;
S05-Clientbericht siehe SVG-S05.md. SVGStage=S06; Browser s06.html.
SVG/Geometry erzeugt sechs Grundformen und rx/ry-Rundungen; SVG/Raster zeichnet
Konturen mit nichtnull-Füllung, vorläufigem solid/butt/miter-Stroke und Kantenglättung.
Viewports-Adapter erhält optional Geometry, die S04/S05-Proberaster bleiben erhalten.
Drei Quellen in ShapeSources über sync-svg-shapes.py; sechs Bilder, keine Diagnosen
erwartet. Details/Grenzen und Prüfungen: SVG-S06.md. Allgemeines CSS/HTML-Paint
noch nicht angebunden. Nach visueller S06-Abnahme folgt S07 (Paint/Opacity).
Alle nachfolgenden offenen S05-Statusangaben sind historisch.

Aktuell S05 implementiert, Abnahme offen. SVGStage=S05; Browser s05.html.
SVG/Length: Zahlen/Einheiten, Prozentachsen/Normaldiagonale, explizite Font-/CSS-
Viewport-Kontexte, Fehlerdefaults. Viewports-Adapter optional erweitert, S04-Weg
bleibt erhalten. Drei SVG-Quellen in LengthSources über sync-svg-lengths.py.
Erwartet: sechs Bilder, vier beabsichtigte Längendiagnosen im letzten Test.
S04 ist inzwischen vom Nutzer visuell bestätigt; Bericht siehe SVG-S04.md.
Alle folgenden älteren offenen S04-Statusangaben sind überholt. Nach S05 folgt S06.

Aktueller Stand: S04 implementiert, visueller Vergleich offen. SVGStage=S04;
Browser examples/svg-tests/s04.html, vier Tafeln. Engine SVG/Viewport enthält
viewBox-/preserveAspectRatio-Parsing, positive achsenparallele Transformationen
und verschachtelte Clips. Sizing nutzt denselben viewBox-Parser. Viewports und
ViewportPixels im Labor sind Beobachtungsadapter für Testrechtecke/Kreise, noch
kein allgemeines SVG-Paint in HTML. Quellen mit sync-svg-viewports.py synchron.
Tests und Umfang: SVG-S04.md. Erwartet acht lebende EditableImages; nach Abbau null.
S01–S03 bestätigt; nach S04-Abnahme kommt S05 (Längeneinheiten/Prozentbezüge).
Die folgenden Angaben zum nächsten Schritt S04 sind historisch.

Aktuell: S03 SVG-HTML-Layoutbox visuell vom Nutzer bestätigt (13.09.2026).
Clientbericht: Width=480, neun Boxen, Diagnostics=[], Cycles=1. Details und
GUI-Rundung der relativen Höhe in SVG-S03.md. Weitere Größen/R nicht separat
bestätigt. Nächster Planschritt S04: viewBox und preserveAspectRatio. Config SVGStage=S03.
Browser examples/svg-tests/s03.html; exakte HTML-Quelle S03-embedding.html wird
mit sync-svg-embedding.py nach SVGLab/EmbeddingSource.luau synchronisiert.
HTML-Parser bewahrt SVG-Teilbäume; RenderTree erzeugt ersetzte Inline-/Blockboxen,
SVG/Sizing ermittelt intrinsische Maße; vorhandenes ImageLayout übernimmt Reflow.
Die S03-Flächen sind CSS-Hintergründe der SVG-Boxen, kein allgemeines SVG-Paint.
Details/Grenzen in SVG-S03.md. S02 vom Nutzer bestätigt; dessen Bericht bei 480 px
zeigt sechs lebende Bilder, PixelReadback=true und den erwarteten XML-Fehler.
Die folgenden früheren Statusangaben zu S02 sind dadurch überholt.

SVG S02 implementiert: SVG/XML + SVG/Parser in HTMLEngine, Unicode/XML-Namen,
Namespace-Scope, IDs, Entities/CDATA, strukturierte Diagnosen und harte Limits.
Default-Labor SVGStage=S02. Browser examples/svg-tests/s02.html. StructureSources
enthält unveränderte SVG-Strings; Structure-Adapter traversiert den echten Laufzeit-
DOM für drei Rechtecke, leeren XML-Fehlerfall und gültigen grünen Nachbarn. Kein
allgemeiner SVG-Renderer/CSS-/HTML-Integrationssupport behauptet. Tests und Details
SVG-S02.md; visuelle Nutzerabnahme offen, danach S03. S01 bleibt bestätigt.

Neueste Rückmeldung zu S01: „alles passt“. Gesamtvergleich vom Nutzer visuell
bestätigt; S02 ist als nächste Etappe freigegeben. Einzelne Client-/Zählerwerte
wurden nicht separat übermittelt. Ältere Hinweise „visueller Abgleich offen“ für
S01 sind durch diese Bestätigung überholt; allgemeiner SVG-Parser bleibt S02.

S01-Startproblem behoben: laufender Rojo hatte die geänderte Config, aber die neu
ergänzten Projektbaum-Einträge noch nicht geladen. Server auf Port34872 neu
gestartet; aktuelle /api/rojo-rootInstanceId abgefragt und /api/read geprüft:
SVGLabDemo und alle Labormodulquellen jetzt enthalten. Nach Rojo-Neustart ändern
sich Session-/Root-IDs; alte IDs liefern einen leeren Snapshot. Studio ggf.
Disconnect/Connect und Stop/Play. Logs: build/rojo-svg-serve.log und -error.log.

SVG S01 implementiert: default.project.json startet nun SVGLab (StudioDemoConfig).
Browser examples/svg-tests/index.html, Tasten 1/2/3 für Größen, R für 20 Zyklen.
Zwei SVG-Quellen werden offline in Fixture.luau übersetzt; noch kein allgemeiner
Engine-SVG-Parser. Glyphenpixel des vorhandenen OFL-Fonts demonstrieren echtes
Drehen/Ausschneiden; keine native Glyphenextraktion oder beliebige SVG-Textfunktion.
Pixels/Surface/Lab haben eigene CLI-Tests: scripts/run-svg-tests.cjs; Details,
Grenzen und ausstehende echte Studio-Abnahme stehen in SVG-S01.md. S02 wartet
auf den Vergleich; nächste Etappen nicht als implementiert ansehen.

SVG: Nutzer möchte den gesamten in Roblox machbaren Umfang statt nur der Blume.
Maßgeblich ist SVG-PLAN.md mit S01–S45, je eigenem visuellen Vergleich, Abnahme,
frühen Text-/Raster-Machbarkeitsproben und Abschlussmatrix. SVG.md verweist darauf.

Neu: drop-shadow() für img, optionale Farbe/currentcolor, px-Versatz und sigma.
HasRaster routet auch scharfe Schatten in ImageBlur; Raster erzeugt Alpha-Silhouette
und komponiert Source-over. Drei wiederverwendete Float-Buffer bei Schattenketten.
Currentcolor nach Cascade aufgelöst und im Cache-Key. Demo34 synchron 21.383 Bytes,
zwei Schattenbeispiele, Tests/ImageDropShadow. Details IMAGE-FILTERS.md.

Neu: blur(0–100px) in Filter-Ketten. Filter.HasRaster/Outset leiten positive Blur-
Ketten an ImageBlur statt den reinen Farbfiltercache. ImageBlurPixels rastert fit/
position auf CSS-Anzeigegröße mit transparentem Überstand, filtert premultipliziert
mit drei Boxpässen (Subpixelkernel bei kleinen Radien). ImageBox.BlurGui/UpdateBlur
zeigen Ergebnisse und melden Größenänderungen ohne Polling. Cache verwirft veraltete
Jobs und entfernt unbenutzte Varianten; Cleanup gibt Quellenbuffer/Ergebnisse frei.
ImageLoad respektiert BlurReady; Opacity-Gruppen schließen den Überstand ein.
Demo34 jetzt21090Bytes, zwei Blur-Beispiele; Tests/ImageBlur. Details IMAGE-FILTERS.md.

Neu: CSS/Filter, Rendering/ImageFilterPixels und Rendering/ImageFilters für acht
img-Pixelfilter. HTMLPage startet asynchronen Cache vor ImageLoad (eigene Itemlisten,
weil ImageLoad seine Liste leert). FilterReady schützt erfolgreiche Ausgabe vor
späterem Original-Preload-Fehler. Ein Layout nur bei vorherigem TextFallback.
Gemeinsame Quellen/Filterketten, Cleanup und Budgets; siehe IMAGE-FILTERS.md.
Demo34 synchron, 20877 Bytes; Kompaktgrenze jetzt22000. Tests/ImageFilters und Images.

Nachprüfung: TableContentClipped kennzeichnet Spalten-Clipping für PositionedLayout
und GroupOpacity, damit abgeschnittener Inhalt keine Scroll-/Texturflächen vergrößert.
BlockLayout.naturalWidth hat einen optionalen sechsten Parameter heightBasis für
die aktuelle intrinsische Messung; er darf nicht aus box.HeightBasis des letzten
Layouts stammen. Rekursive Messungen lösen explizite Höhen neu auf. Regressionen
für Prozenthöhe/aspect-ratio, Resize und Teil-/Voll-Layout in TableAdvanced.

Korrektur nach Screenshot zu Demo33: Nur entfernte Zeilen dürfen rowspan-Inhalt
bei overflow:visible nicht am verkleinerten Zellrahmen abschneiden. TableLayout
erzwingt Clipping weiterhin bei entfernten Spalten und explizitem overflow:hidden.
Sichtbarer vertikaler Überlauf zählt zur Scrollfläche, ohne die Tabelle zu strecken.
TableAdvanced prüft beide Rahmenmodelle und visible/hidden.

Neu: Tabellenhöhen/Prozenthöhen, visibility:collapse, CSS-Tabellenrollen,
implizite rowspan-Zeilen und RTL-Spalten. TableHeights verteilt Zusatzhöhe ohne
intrinsische Minima zu unterschreiten. TableTracks projiziert logische Tracks
auf sichtbare Geometrie; TableBorders nutzt diese Projektion. TableGrid erweitert
Gruppen ohne DOM-/GUI-Knoten (max65534 Zeilen,4096 Spalten; collapse max1M Slots).
BlockLayout reicht HeightBasis weiter; DirtyLayout vergleicht sie im Cache.
Partielle Spans behalten ihre Inhaltsbreite und clippen, unter RTL rechtsbündig.
CollapsedByTable verhindert Scroll-/Opacity-Überstände; CollapsedTableCells
sperrt Fokus. HTMLTableStructure lässt HitTests durch generische CSS-Zeilen.
TextAlign-Standard start folgt Direction; kein vollständiger Unicode-Bidi-Satz.
Demo33 synchron, 19834 Bytes; Tests/TableAdvanced plus bestehende Regressionen.
Grenzen und Module: TABLES.md. Native interaktive GUIs bleiben unverändert.

Neu: CursorIcons (alle User-IDs), CSS/Cursor (vererbtes cursor + URL/Fallback),
CursorController und CursorLease. InputController startet Cursor auch ohne
Controls und bindet Textarea-Capture/SelectPopup ein. Native MouseIcon, kein
Frame-Timer. NodeStyles/HitStyles erhalten CSS über HitTest; InlineWords trennt
Cursor-/Linkgrenzen. HitTest liefert optional das getroffene GUI und respektiert
HTMLInputBlocker für passive Fenstergriffe. ResizableTestWindow nutzt Frames
statt TextButtons und CursorLease-Priorität100. Engine.CursorIcons exportiert.
Demo32 alle Cursor; Tests/Cursors, HTMLPageDemo. Native TextBox kann Icon
übersteuern; andere Grenzen/Anwendung in CURSORS.md. User-IDs nicht verändern.

Neu: table-layout:fixed + col/colgroup. TableColumns liest direkte Definitionen
ohne Fluss-GUIs, expandiert span (max1000, max4096 Spalten), nutzt Gruppenbreiten
als Vorgabe und berechnet fixed-Spalten ausschließlich aus col/erster Zeile.
TableLayout benutzt fixed nur mit Style.Width, sonst auto. Intrinsische Messung
verschachtelter fixed-Tabellen verwendet ihre eigene Breite als Prozentbasis.
TableColumnPaint liegt mit ZIndex0 unter Zellen, färbt die ganze Ursprungzelle
auch bei colspan und behält GUIs beim Reflow. TableBorders berücksichtigt Spalten
und Spaltengruppen nach Zeilengruppen, vor Tabelle. Parser schließt colgroup vor
Zeilen/neuen Gruppen. Demo31:100px/20%/Rest, beide Dateien synchron.
Tests/TableFixed; Grenzen und vollständige Beschreibung in TABLES.md.

Neu: border-collapse:collapse. TableBorders löst gemeinsame Kanten nach
Breite/Stil/Quelle auf (inklusive hidden), unterdrückt Innenkanten von Spans und
setzt halbe Layout-Rahmen. RenderTree bewahrt TableBorderSource vor der
Zeilen-/Gruppennormalisierung, wählt das Modell über die nächste Tabelle und
überspringt individuelle BorderBox/UICorner bei collapse. TableBorderPaint nutzt
einen flächenlosen Host über den Zellen und wiederverwendete passive Frames;
Kreuzungen werden ohne doppelte Alphaüberlagerung aufgeteilt. Demo31 jetzt collapse.
Vorheriger Review-Fix: Prozentpadding wurde beim Messen/Arrangieren unterschiedlich
aufgelöst; Sizing.SpacingWidth hält beide Zellpässe konsistent. Tests/TableCollapse
und Tables prüfen beides. Grenzen: TABLES.md. Kein neuer Update-Timer.

Neu: colspan/rowspan in TableGrid + TableLayout. Grid.build reserviert belegte Spalten
je Zeilengruppe (Scope), rowspan=0 bis Gruppenende, Attribute gemäß HTML begrenzt.
Überlange rowspans werden auf vorhandene Gruppenzeilen begrenzt/diagnostiziert.
Grid.ensure verteilt Defizite monoton auf überspannte Spalten/Zeilen, einschließlich
innerem border-spacing. TableLayout misst Gesamtzellbreiten, verteilt Zeilenhöhe und
richtet verbundene Zellen aus. Keine neuen GUI-Instanzen beim Reflow. Demo31 hat einen
zweizeiligen Kopf, je einen colspan/rowspan. Tests/TableSpans; Grenzen in TABLES.md.

Neu: Tabellen-Grundlage, Beispiel 31. Elements.Defaults.TableRole markiert table,
row, group, cell. RenderTree sammelt via TableLayout.prepare die TableRows/Groups.
BlockLayout integriert intrinsische Tabellenbreiten und den TableLayout-Zeilenpass;
Sizing.TableCell erzwingt gemeinsame Breite/Zeilenhöhe, ContentOffset richtet Text aus.
border-spacing (H/V) und border-collapse:separate sind im CSS-Katalog. TableLayout
misst jede Spalte über alle Zellen. DirtyLayout behandelt Tabellen als gemeinsame
Abhängigkeit; unveränderte, unpositionierte Tabellen können mit lokalen Zellmaßen
als Ganzes verschoben werden. Der bestehende Demo-Performance-Test bleibt erfüllt.
Kein collapse/caption/col/fixed/Zeilenhintergrund. Details: TABLES.md.
Tests/Tables und HTMLPageDemo ergänzt; HTML-Sourcen synchron.

Neu: details/summary, Beispiel 30. Rendering/Disclosure verwaltet Open, SummaryNode,
BodyNode/Body, Box und Marker. RenderTree erstellt den anonymen Body ohne DOM-Umbau;
erster direkter Summary wird als Type=summary in Controls registriert. Kein Formwert.
Controller ToggleDetails nutzt Disclosure.toggle + requestLayout(false,details.Box).
View.paint behandelt nur den Fokusrahmen; ListMarker delegiert den eigenen Marker.
AllChildren hält auch geschlossene Inhalte für DirtyLayout.attach und Scroll-Watcher.
Aktuelles Children enthält geschlossen nur den Titel. Disclosure.hidden schützt
Fokus/Tab/Radionavigation/Hit-Test/NativeEditor. Werte und nested Open bleiben erhalten.
Kein name/toggle-Event/Live-[open]-CSS. Umfang/Tests: DETAILS.md, tests/Details.luau.

Neu: optgroup-Überschriften. SelectOptions.read liefert zusätzlich SelectRows mit
Gruppen und Optionsreferenzen; Options/SelectedIndex bleiben reine Optionsindizes.
RenderTree löst die fette Gruppenfont auf, View misst Überschriften plus Einrückung.
SelectPopup zeichnet passive Gruppenlabels und speichert optionTops für Reveal.
disabled-Gruppen bleiben sichtbar, werden bei Auswahl/Suche übersprungen.
Demo-Modus hat Verfügbar/Geplant (disabled), weiterhin drei Optionen. Tests/Optgroups.

Neu: Tastatur-Präfixsuche für Select. Input/SelectTypeAhead hält Präfix/Kontrolle/Zeit
(1s Pause), nutzt Latin-Casefolding aus TextTransform und cached SearchCaption je Option.
Wiederholte Initialen wechseln zyklisch; disabled wird übersprungen. SelectPopup besitzt
Suchzustand: geschlossen direkt choose, offen nur Highlight/Reveal, Enter bestätigt.
Controller mappt druckbare Haupttastatur-KeyCodes via GetStringForKeyCode, ignoriert
Ctrl/Alt/Meta/processed; keine Timer/Layout-Requests. Services.Clock für Tests.
Demo-Moduslabel zeigt K/S-Hinweis, keine zusätzlichen Controls. Tests SelectTypeAhead/Select.

Neu: autofocus auf Formularcontrols. Controller wartet einmal auf Root.Status=ready,
trennt den Listener, wählt ersten geeigneten Kandidaten in tree.Controls/DOM-Reihenfolge.
Disabled/hidden/output/DisplayOnly/unsichtbare GUI-Vorfahren werden übersprungen.
Bereits erfolgte Interaktion, Fokusrevision oder externe fokussierte TextBox verhindern
Fokusübernahme. Kein neuer Fokus bei Resize/Dirty/Reset. Demo-E-Mail hat autofocus;
Tests/Autofocus deckt Timing, Ausnahmen, bestehende Eingabe und Cleanup ab.

Neu: englische ValidationPopup-Sprechblase. FormModel liefert invalid.Data={Reason,Message}
über Controls/ValidationMessage; PreventDefault unterdrückt Default-Fokus/Blase.
Controller.ShowValidation öffnet nach Fokusprüfung, Bearbeitung/Fokus/Klick/Escape
und Fensterverlust schließen. Input/ValidationPopup beobachtet Anker/Viewport/Scroll,
zeichnet passive Frames/TextLabels als Overlay unter/über dem Feld, misst synchron
Arial14 über GetTextSize (Tests: Services.MeasureValidationText). Kein Layout/Heartbeat.
Tests/ValidationPopup prüft Meldung, Abbruch, Positionierung und Listener-Cleanup.
Keine Änderung am gemeinsamen HTML nötig; falsche E-Mail + Testen zeigt die Blase.

Neu: email/url/minlength. Controls/TextValue kapselt Texttypen, Sanitizing, ASCII-
E-Mail-Syntax (auch multiple), UTF-16-Länge und minlength-Attribut. URLValue prüft
absolute URLs lokal (Host/Port/IPv4/IPv6, andere Schemas), keine vollständige
WHATWG-/IDNA-Normalisierung. State speichert MinLength/Multiple/UserEdited;
FormModel verfolgt UserEdited inklusive gleicher programmgesteuerter Werte und Reset.
Submit ergänzt type mismatch/too short im bestehenden invalid-Pfad. View verwendet
bisherige Maße/Fonts; gemeinsame Demo ersetzt Name/Passwort durch email/url und
setzt minlength=5 am Textarea. TextValidation + bestehende Regressionen prüfen die Änderung.

Textarea-Griff: Controller hebt beim Begin den Fokus auf; TextareaResize.IsActive
sperrt API-/native-/Tab-Fokussierung und native Texteingaben während der Geste.
Kein automatisches Refocus nach Ende; bestehende Blur/Change-Semantik bleibt aktiv.
Tests/TextareaResize prüft Fokusverlust, 1px-Rahmen, Sperre und erneute Aktivierung.

Neu: fieldset/legend. Layout/FieldsetLayout misst die erste gerenderte direkte Legende;
BlockLayout reserviert deren Höhe im oberen Rahmenbereich und entfernt sie aus FlowChildren.
FlexLayout nutzt ContentTop. BorderBox zeichnet über drei transparente Clip-Regionen
eine echte Lücke (vorhandene Border-Pools bleiben wiederverwendbar). Controls/State.disabled
prüft jeden disabled-fieldset-Vorfahren separat, Ausnahme erste direkte DOM-Legende.
InlineStyle löst Standardpadding nach endgültiger Schriftgröße, unter Beachtung der
Autor-Longhands. Gemeinsames Formular gruppiert bestehende Toggles, keine Zusatzfelder.
Tests/Fieldsets prüft Layout, disabled-Ausnahmen, Formularwerte und Teil-/Voll-Layout.
Visueller Studio-Abgleich dieser Ergänzung steht noch aus; Grenzen siehe FORMS.md.

Neu: Textarea-Ziehgriff 12×12 EditableImage, RGB102, Referenzdiagonalen 7+3 Pixel.
Rendering/ResizeGrip cachet eine Textur pro Seite; Fallback Pixel-Frames. Durch
HTMLPage/RenderTree an ControlView weitergereicht. TextareaView positioniert/hittet
den Griff innerhalb der Rahmenkante; Input/TextareaResize erfasst Maus/Touch.
Control.LayoutStyle bewahrt Originalstil für Block-/Flex-Resizes; CSS resize
none/both/horizontal/vertical. requestLayout(false,item) erlaubt Item-Änderungen
bei konstantem Viewport, verwendet bestehenden 1/60s-Timer und DirtyLayout.
Kein Cursorwechsel, keine input/change-Events. Bestehender Textarea-Test erweitert,
Tests/TextareaResize und PageLifecycle für Bild, Drag, Constraints und Throttle.

Neu: progress/meter, GaugeValue normalisiert Grenzen/Werte/Qualitätsbereiche;
GaugeView zeichnet passive Frame-Balken. Controller bindet optionalen TweenService-
Laufbalken für progress ohne value, beendet bei bestimmtem Wert/Hidden/Dispose.
PaintOwner beachtet für Scroll-/Layout-Snapshots, damit diese die Animation nicht
zurücksetzen. DisplayOnly verhindert Eingabe, Fokus, Tab, Submit-Werte und Reset.
page:SetValue ändert nur Paint; nil setzt progress unbestimmt, GetValue liefert "0".
Demo29 jetzt 15 Controls, je ein progress/meter. Tests/Gauges prüft Grenzen,
Farbbereiche, Form-Exklusion, Paint-only-Updates und Tween-Lebensdauer. FORMS.md.

Neu: input type=number mit eigener Frame-Pfeildarstellung und nativer Texteingabe.
NumericValue teilt den Zahlenparser mit Range; NumberValue prüft min/max/step und
berechnet Schritte. Rohtext EditText bleibt beim Tippen erhalten; Value ist für
ungültige Eingaben leer, BadInput verhindert Submit. SetValue/Reset synchronisieren
Editor/Draft, keine Layoutanforderung. Pfeilklick/Touch/Up/Down: input+change;
CommitNumber aktualisiert die Fokus-Vergleichsbasis vor Callbacks gegen doppelte
Change-Ereignisse. NumberView übernimmt Layout, Hover und geometrischen Hit-Test.
Demo29 jetzt 13 Controls, ein Number 1–10. Limits in FORMS.md, Tests/Number.luau.

Neu: input type=range horizontal, min/max/step/any/value, passive Frame-Spur/Griff.
Controls/RangeValue normalisiert Werte; RangeView zeichnet; Input/RangeDrag hält
Maus/Touch bis Release fest. Input bei Wertänderungen, Change bei Release/Fokusverlust;
Pfeile/Home/End, disabled, Submit/Reset. Keine neue Layoutanforderung beim Ziehen.
Demo29 enthält einen 0–100-Regler (jetzt 12 Controls). Tests/Range prüft Modell,
Darstellung, Capture außerhalb, Touch, Tastatur, Ereignisse und Cleanup.
Browser-/Studio-HTML identisch. Native Studio-/Touch-Sichtprüfung noch offen.

Text-/Passwort- und Select-Höhe entkoppelt: Controls/View verwendet als IntrinsicHeight
ungekürzte FontMetrics.resolve(style).TextSize + 1 (Default17), native TextSize bleibt14.
Mit Padding 19px innen /21px mit Rahmen. textTop verschiebt korrigierte Glyphenbox
innerhalb der logischen Zeile; Standardgrundlinie 5px oberhalb innerer Unterkante.
Größere explizite CSS-Höhen zentrieren die logische Zeile. View.align verwendet dieselbe
Textposition, Passwortmaske/Editor identisch. Textarea/Buttons unverändert.
Forms-Regressionen für 21px, native14, Grundlinie/Maskenposition und CSS-Höhen.

Neu: select/option als eigener Dropdown-Teilumfang. Controls/SelectOptions liest
Optionstext/label/value/selected/disabled, FormModel integriert SelectedIndex,
SetValue (erster Treffer, unbekannt → keine Auswahl), Daten, required und Reset.
View misst längste Option + Pfeil einmal je Font; Auswahl bleibt paint-only.
Input/SelectPopup zeichnet Frame/TextLabels mit nativem ScrollingFrame außerhalb
des Seiten-Scrollinhalts. Zentraler Controller behandelt Maus/Touch, Pfeile,
Enter/Space/Escape, Außenklick und Fokusverlust. Ankerbewegung/Resize schließen das
Popup; Listener und Popup-GUIs werden entfernt. Keine TextButtons/ImageButtons.
Parser kann ausgelassene option-End-Tags. optgroup disabled wird weitergegeben,
Gruppentitel sind implementiert; Options-CSS/multiple/size>1 fehlen (letztere Diagnose).
Demo29 synchron um genau ein Select mit drei Optionen ergänzt. Tests/Select prüft
Werte, disabled, Daten/Reset/required, doppelte Werte, Maße/Messcache, Maus/Touch/
Tastatur, Popup oberhalb, Schließen und Cleanup. Native Studio-Optik noch abgleichen.

Radio-Punkt jetzt EditableImage: Rendering/RadioDot erstellt lazily eine 9×9 weiße
Alphamaske aus den gemessenen Pixeln der Nutzer-HTML-Referenz: gespiegelter 5×5-COVERAGE-Quadrant,
Alpha 40/70/102/202 am Rand, 255 innen. Ersetzt den zuvor konstanten 50%-Rand.
HTMLPage besitzt Cache/Cleanup,
RenderTree reicht ihn an beide ControlView.create-Pfade weiter. DotImage steuert
ImageColor3 statt BackgroundColor3; Farben/Checked/Disabled unverändert. Kein
Pixel-Neuzeichnen bei Zustandswechseln. Fehlerpfad einmalige Diagnose + bisheriger
runder Frame. Tests RadioDot/PageLifecycle prüfen Geometrie, Zustände, Sharing und
Cleanup. Haken zuletzt 2px nach unten; ControlBox-Standardradius 3px (Radio rund).

Erneute Prüfung: Input/Controller schützt Fokusübergänge mit focusRevision gegen
Umleitung/Destroy aus change-/blur-/nativen Fokus-Handlern. Stylesheet.matches prüft
ganze direkte Kindketten und versucht bei Fehlschlag weiter entfernte Vorfahren;
gemischte Selektoren mit wiederholten Klassen funktionieren jetzt. Reproduktionen
und Regressionen in Forms/Stylesheet; Gesamtsuite normal/-O2, Audit und beide Builds
bestanden. Details im neuesten Abschnitt von PROJECT-REVIEW.md.

Aktuelle Toggle-Optik in Controls/View: Haken aus zwei 1px-Frames, kurzer Strich
3px/45°, langer 7px/-55°. Radio blau normal (0,117,255), Hover (0,95,204),
Pressed (57,147,255); Ring und Punkt synchron, kein schwarzer Fokusring am Radio.
Nicht gewählter Radio-Rahmen wird gedrückt grau (163,163,163). Disabled hat Vorrang.

Output-Änderungen gleicher Größe: View.canKeepLayout misst im serialisierten
HTMLPage-Worker und vergleicht mit PlacedControlMetrics vom letzten tatsächlichen
View.arrange (PaintOwner bei Ellipsis-Snapshots). Gleiche intrinsische Breite/Höhe,
TextSize und FontFace → kein Dirty.begin/BlockLayout/Canvas-/Statusupdate. Vorprüfung
aktualisiert nur den Messcache, nie die Referenz des angeordneten Layouts. Bei
Änderungen während Mess-Yields werden verbleibende Items wieder zusammengeführt;
Resize/Fehler/Erstlayout nutzen weiterhin den normalen Weg. Pending-Scrollpaint bleibt
erhalten. Output/Button-Messung benötigt nur Caption-Messung statt zusätzlichem "0".
Tests DirtyLayout/PageLifecycle erweitert; HTML-Demo unverändert.

Demo-Doppelmeldung korrigiert: verzögerte Status-Rückrufe für layout→ready können
beide bereits ready lesen. Der Reporter merkt die konkrete LastLayoutStats-Tabelle
und meldet denselben Abschluss nur einmal; spätere echte Layouts haben neue Tabellen.
Keine Eingabe-/Layout-Drosselung geändert. tests/DemoStatus verwendet den aus dem
LocalScript extrahierten Reporter und reproduziert den Fehler vor dem Fix.

Aktuell: Dirty-Layout Stufe 2. Unveränderte Scroll-/Opacity-Bereiche und eigenständige
relative Positionierungscontainer dürfen ihren ganzen Teilbaum wiederverwenden.
DirtyLayout.ReusedRoots kennzeichnet Flow-Treffer; touch/invalidate löschen die
Kennzeichnung bei späteren Geometrieänderungen. ScrollLayout.prepare setzt Balken
erst bei tatsächlichem Layout zurück, Settle/Commit lassen unberührte Bereiche aus.
Neue Gutter invalidieren Vorfahren. PositionedResult prüft globale Koordinaten und
Containing-Block-Größe/-Position; OpacityBounds überspringt unveränderte Unterbäume.
Geänderte Sonderbereiche und externe Positionierungsabhängigkeiten konservativ.
CLI-Demo: 5 Layout-Aufrufe, 78 Cache-Treffer (vorher 100/144); native Bestätigung offen.
Regressionen für Scrollpositionen, bewegte Container, kombinierte Sonderbereiche
und vollständige Geometrievergleiche ergänzt. Details: [DIRTY-LAYOUT.md](DIRTY-LAYOUT.md).
Der folgende Absatz beschreibt die vorherige erste Stufe.

Neu: erste Dirty-Layout-Stufe für output-Änderungen. DirtyLayout.begin/finish im
serialisierten HTMLPage-Worker, Item→Owner/Parent-Index, generationsgebundene
Teilbaum-Caches im vorbereiteten BlockLayout-Pfad. Geänderte Vorfahren werden
berechnet, unabhängige unveränderte Teilbäume übersprungen. Flex-Nachfahren und
Scroll-/Positionierungs-/Opacity-Zweige konservativ; Vor-/Nachbereitung bleibt.
Resize/Bilder/Fehlererholung vollständig. Pending-Mengen werden pro Durchlauf
abgetrennt, Änderungen während Yields bleiben erhalten. Debug unterscheidet
Teil-Layout mit Cache-Treffern und Voll-Layout; page.LastLayoutStats verfügbar.
Tests DirtyLayout/Forms/PageLifecycle; Details und Grenzen: [DIRTY-LAYOUT.md](DIRTY-LAYOUT.md).
Browser-HTML unverändert, Beispiel 29 zum Prüfen. Native Studio-Prüfung noch offen.

Formularhöhen korrigiert: ImageLayout.size verwendet für Controls kein natürliches
Bild-Seitenverhältnis. width:100% skaliert daher die Höhe nicht mehr proportional;
sie folgt Text/rows oder CSS-height. Explizites CSS-aspect-ratio bleibt möglich.
Forms-Regression prüft Inline-/Block-/Flexfelder über drei Breiten, explizite Höhe
und stabile TextSize. Nach Arial-Korrektur: Input 18px, Textarea rows=3 48px Rahmenhöhe.

Arial in Formular-Controls (außer output) lokal um 2 TextSize reduziert: Standard
16 → 14, über View.metrics für Eingabe, Buttons, Messung und Layout. Roboto Mono
bleibt bei 14; globale Arial-Kalibrierung und CSS-Vorgaben unverändert.

Textarea/Roboto Mono: native Schriftgröße lokal um 3 reduziert (Standard 17 → 14),
keine Positionsverschiebung. Controls/View.metrics berechnet die Korrektur samt
Guides über optionalen FontMetrics.resolve-Offset. WordLayout und BlockImage nutzen
dieselben Metriken; die frühere reine View-Korrektur wurde im WordLayout überschrieben.
Forms prüft nun die endgültige Editor.TextSize nach Inline-/Block-/Flexlayout und
Resize sowie eine abweichende CSS-Schriftgröße. Globale Fontkalibrierung unverändert.

Studio-Startfehler der Formulare behoben: Controls/Defaults muss Enum.Font.Arial
statt des Strings "Arial" setzen. Der CSS-Parser liefert bereits den Enum-Wert.
Forms-Regression verwendet jetzt getrennte Enum-Objekte und echte FontProfiles.face-
Logik; die bisherigen String-Enum-Mocks hatten den Unterschied verdeckt.

Neu: Formularvorschau jetzt auch in Roblox implementiert. Gemeinsames Beispiel 29,
Browser weiterhin native Controls. Controls/{Defaults,State,View,FormModel} und
Input/{Events,HitTest,Controller}; native TextBox, zentraler Ereigniscontroller,
Radio/Checkbox/Button, Submit/Reset, Label-/Tab-Fokus. API/Grenzen: [FORMS.md](FORMS.md).
Keine neue Frame-Schleife; lokale Eingabe/Toggle/Fokus ohne Seiten-Reflow, nur
Output-Änderungen fordern Layout an. TextBox-Instanzen bleiben bei Resize erhalten.
Hit-Test nutzt native Reihenfolge plus Clipprüfung, schwache GUI-Schlüssel.
CSS unterstützt jetzt auch direkte Kindselektoren (>). Vollständiges HTML in
Browserdatei und LocalScript identisch; Luau-Submit-Handler setzt preview-result.
Passwortmaske über transparenter TextBox: Cursor/Selektion/Scrollen langer Werte
noch eingeschränkt. Native Studio-Eingabe und Optik noch nicht geprüft. Browser-
Reload wurde durch URL-Policy abgelehnt; nicht umgehen. Nutzer manuell neu laden lassen.
Ältere Aussagen unten über fehlende Formulare sind historisch.

Neu: `em` und `rem` bei unterstützten CSS-Längen, einschließlich Kurzformen.
Root-/Elternbezug, Vererbung und Grenzen: [RELATIVE-LENGTHS.md](RELATIVE-LENGTHS.md).
Katalog: CSSProperties.RelativeUnits; Vergleichsbeispiel 28, Tests: RelativeLengths.
Ältere Abschnitte mit em/rem als Einschränkung werden dadurch ersetzt.

Erneute Pruefung: BlockImage.ImageStyle bleibt fuer BorderCorners-Caches stabil;
sechs Groessen-/Limitfelder werden je Messung zurueckgesetzt. OverflowWrap entfernt
ersetzte Glyphenfragmente via GroupOpacity.untrack. Ellipsis-PaintState kopiert
Elementgeometrie und haelt PaintOwner fuer originale Prefix-Caches/Fragmentpools.
Regressionen: MediumAdditions; Bericht: PROJECT-REVIEW.md.

Fix Demo27: horizontales Ellipsis-Scrollen ruft WordLayout.repaint auf gespeicherten
Zeilen auf, keinen Seiten-Reflow. Ein gemeinsamer Worker serialisiert Paint/Resize
und erhält Ereignisse während Mess-Yields. Keine Canvas-/Statusänderung beim Scrollen;
Demo meldet das erste ready und danach jede tatsächliche Layout-Neuberechnung.
Resize ist auf 1/60 Sekunde (ca. 16,7ms) zwischen Layoutstarts begrenzt; ein Timer übernimmt die letzte
Größe. Scrollpaint bleibt im gemeinsamen Worker während der Wartezeit möglich.
Erstladen/Bildabschluss bleiben unmittelbar. Timer wird beim Destroy abgebrochen.
Lifecycle-/Projektions- und virtuelle Zeitregressionen ergänzt.

Neu: mittlere Erweiterungen (Punkte 7–16) integriert, Demo21–27.
CompositeValues: font/list-style und inherit/initial/unset; BoxSpacing: signierte
Margin/Prozentabstände mit getrennten CSS-Werten; wbr, break-all, anywhere inklusive
min-content; Innenmarker in erster Wortzeile; BlockImage für echte Block-/Flexbilder;
GroupOpacity für Block-/Inline-/Bild-CanvasGroups mit berechneter Ansichtsfläche.
TextOverflow berücksichtigt horizontale Scrollposition; HTMLPage räumt Listener auf.
Regressionen: tests/MediumAdditions; Details/Grenzen: MEDIUM-ADDITIONS.md.
Browser/Studio-HTML identisch, Bildermapping landschaft.png → 15773523297.
Native Sichtprüfung der neuen Funktionen offen.

Neu: diagonale Rahmen-Ecken. BorderPaint zentralisiert unveränderte Farbwahl;
BorderCornerPixels rastert vier Eckkacheln mit 16 Proben/Pixel in einen Atlas.
BorderCorners verwaltet 64 Boxen/262144 Pixel je Seite, Resize-Reuse und Fallback.
HTMLPage reicht den Renderer als letzten optionalen RenderTree.build-Parameter
an BorderBox/ImageBox/OutlineBox. Bei Erfolg gerade Kanten ohne Ecken, Muster
mit voller Kantenlänge plus Clip; sonst alter vollständiger Rahmen. Native solide
UIStroke-Rundung bleibt. Bestehende Demo15/18–20, tests/BorderCorners;
Grenzen in BORDER-CORNERS.md. Native Sichtprüfung offen.

Neu: word-wrap als Alias von overflow-wrap; border outset/groove/ridge über
BorderBox/BorderGeometry (outset Farbstreifen, groove/ridge zwei Bänder,
Alpha/Resize erhalten, legacy inset unverändert). Outline-Whitelist separat.
Color.parse unterstützt HSL mit Kommas/Leerzeichen/Slash und Hue-Einheiten.
Neue Blöcke address, dl/dt/dd, figure/figcaption; figure-Margins per
MarginBlockEm/MarginInlinePx, dl-Nesting wie Listenabstände. Parser unterstützt
optionale dt/dd-Endtags. Demo18–20, tests/SimpleAdditions, SMALL-ADDITIONS.md.
Native Sichtprüfung offen.

Neu: text-overflow clip/ellipsis (nicht vererbt). Layout/TextOverflow projiziert
WordFlow-Zeilen bei OverflowX hidden auf Präfixe + eigene Ellipse in Blockschrift.
Originaltexte/Layoutmaße bleiben erhalten; OverflowWrap.commit nutzt Teilwortpools,
TextOverflow.visibility blendet Originale ein/aus. EllipsisPool am Run, Positioning
berücksichtigt Marker-ZIndex. Keine Scroll-Events; auto/scroll noch ohne Ellipsis.
Beispiel17, tests/TextOverflow, Details TEXT-OVERFLOW.md. Native Sichtprüfung offen.

Neu: outline/outline-width/style/color/offset auf Blöcken und Bildern. OutlineBox
nutzt BorderBox als unabhängige Zeichenebene innerhalb der Box, ohne Layout- oder
Scrollausdehnung. Bei eigener Outline und hidden-Inhalt zusätzlicher ClipContent;
Scrollcontainer verwenden weiter ScrollGui. Kein neuer Event/Dirty-Pfad.
Kurzform setzt Offset nicht zurück. Negative Offsets je Achse begrenzt.
Beispiel16 in beiden HTML-Quellen; Tests/Outline, Details/Grenzen in OUTLINE.md.

Neu: border-style dashed/dotted/double, in border und Seitenkurzformen sowie
1–4 Stylewerten. BorderGeometry.pattern liefert begrenzte Segmente pro Kante,
BorderBox.arrange zeichnet dieselben Muster für Blöcke/Bilder. Dotted UICorner,
double Gesamtbreite erhalten (unter3px solid). Max128 Segmente/Kante, danach
größere Lücken; Pools bei Resize wiederverwenden, gleiche Maße überspringen.
Beispiel15 jetzt oben dashed/rechts dotted/unten double/links solid. Grenzen
(rechteckige Kanten, keine durchgehende Eckphase) in BORDER-SIDES.md dokumentiert.

Aktuell: border-width/style/color akzeptieren 1–4 Werte nach CSS-Seitenregeln.
Properties.BorderComponents aktiviert die Erweiterung, auf Seiten-Longhands
explizit false. Syntax.scan bewahrt rgb/rgba mit inneren Leerzeichen. Vollständige
Validierung vor Anwendung; keine Mehrwert-Grammatik auf border-radius oder
Seiten-Longhands. Tests/BorderSides erweitert, Beispiel15 auf Kurzformen umgestellt.

Neu: border-top/right/bottom/left samt -width/-style/-color (16 Eigenschaften).
BorderSides/BorderSizes sind nichtvererbte Seitendaten, nur bei Rahmen-CSS
angelegt; skalare Alt-Felder bleiben für uniforme Rahmen verfügbar.
BorderGeometry kapselt vier Breiten und Streifenmaße, BorderBox gemeinsame
Block-/Bilddarstellung. Sämtliche Layout-/Scroll-/Positions-/Inset-Schatten-
Berechnungen auf vier Kanten umgestellt. Gleichmäßige solide Rundungen bleiben
UIStroke; ungleiche Kanten sind rechteckige Streifen, Eckfarbgehrung/Rundung
hier noch Näherung. BORDER-SIDES.md enthält Grenzen. Demo jetzt 15 Abschnitte,
Beispiel15 mit 2/4/6/8px und vier Farben. Scrollbar bleibt 10px, RGB139/139/139.

Aktuell: overflow auto/scroll und overflow-x/y implementiert. Kurzform ein/zwei
Werte; sichtbare Gegenachse wird nach Cascade zu auto. Style.Overflow bleibt
intern der kombinierte visible/hidden-Clipindikator; OverflowX/Y sind die Modi.
RenderTree hält Boxdekoration fest, Inhalt in nativem ScrollingFrame+Frame.
Layout/ScrollLayout reserviert 10px Gutters, löst Achsenabhängigkeit über begrenzte
Layoutdurchläufe und erhält CanvasPosition bei Resize. Keine Scroll-Events.
PositionedLayout ergänzt die eigene Scrollfläche und schließt Leisten aus der
Bezugsbox aus. hr-Defaults auf OverflowX/Y hidden umgestellt. Tests/Scrolling
ergänzt; Demo jetzt vierzehn Abschnitte, zwölf Flexcontainer, HTML synchron.
Details/Grenzen und native Sichtprüfung: SCROLLING.md.

Neuestes Paket: decimal-leading-zero, lower/upper-alpha und lower/upper-roman
sowie text-decoration mit Linien, Style, Farbe und optional auto/px/%-Dicke.
Details und Grenzen: LIST-DECORATION-EXTENSIONS.md. Bestehende Zähler, Marker-
Messcaches und Linienrenderer weiterverwendet. Demo jetzt zwölf Abschnitte,
elf Flexcontainer; Abschnitte11/12 testen die neuen Funktionen kompakt.
Tests für Grenzen, reversed, Resize-Wiederverwendung, Kurzform/Cascade/Alpha.
Frühere Aussagen unten zu fehlenden Listenformaten/Farb-Style-Kurzform überholt.

Aktuelle Nutzeränderung: Demo nur über font-family, keine Google-Fonts-Links.
body Roboto, sans-serif; kbd/samp Roboto Mono, monospace. Browser-/Skript-HTML synchron.
Font-Mapping und Kalibrierungen der Engine unverändert. Ohne lokal installierte Fonts
nutzt der Browser seine Ersatzschriften. Frühere Googlefont-Demovorgaben
unten sind überholt.

Neuestes Paket: alle einfachen Vorschläge ergänzt: row-gap/column-gap (px/normal),
inset1–4 mit auto/signiertenpx/%, font-size:larger (×1.2,max100), text-align:start/end
(LTR), border-width thin/medium/thick auch im border-Shorthand, alle148 CSS-Farbnamen
als statische NamedColors-Tabelle, ins/kbd/samp/var/cite/dfn über vorhandene Inline-
Defaults. Listenformate und text-decoration-Kurzform wurden anschließend ergänzt
(siehe oben). Codeprüfung: doppelte Inset-Vorzeichen wie
-+2px abgewiesen, auto-Seiten/reset/important getestet, Rahmenkeywords auf echte
Rahmenbreiten begrenzt. Color3-Namenwerte einmal pro Modulladen initialisiert.
Katalogtexte zu div/Flex, Textausrichtung, Alpha und Keywords korrigiert.
Beispiel10 drei kompakte Karten; Beispiel9-Badge jetzt inset. Vollständiges HTML
synchron; GooglefontsRoboto Regular/Bold+Italic und RobotoMonoRegular/Bold, damit
neue Inline-Tags auch im Browser die passenden Fonts haben. SimpleFeatures und
Demoassertions ergänzt; gesamte Serie regulär/-O2, Audit125Luau und beide Rojo-
Builds erfolgreich. Details/Review SIMPLE-FEATURES.md. Native Sichtprüfung offen.

Neuestes Paket: position static/relative/absolute, vier Kanten auto/signiertepx/%
und z-index auto/Integer±100000. BlockLayout speichert numerische lokale Geometrie
und FlowChildren ohne absolute Kinder; DOM/Children bleiben erhalten.
PositionedLayout als abschließender Pass: relative Versätze ohne Flussänderung,
absolute Bezugsbox nächste positionierte Paddingbox oder Viewport, shrink-to-fit,
beidseitige Kanten, Min-/Max, Auto-Margins, Flex-static-position und Scrollausdehnung.
Absolute span-Container werden vor Inline-Restriktionen blockifiziert, ohne den
umgebenden Text zu zerlegen. ZIndex sortiert Geschwister-Teilbäume (auch Flexitems),
kein vollständiger CSS-Stacking-Context. Relative Inline-Fragmente/direkte img,
fixed/sticky und genaue statische Position mitten im Text bleiben Grenzen.
Clipping bleibt an GUI-Vorfahren; Details POSITIONING.md. Keine neuen Abhängigkeiten
außer reinem Luau-Modul. Seiten mit Positionierung reflowen auch bei Höhenänderung,
weiterhin ein koaleszierender Worker und Abbruch nach Dispose. Unbetroffene
Teilbäume überspringen den Zusatzpass, Textmaße/Labels bleiben wiederverwendet.
Tests Positioning neu, PageLifecycle ergänzt, alte CSS-Ablehnung korrigiert.
Demo Beispiel9 kompakte Karte (Badge oben rechts, Fläche unten rechts, relatives
Label, Ebenen2/1), HTML synchron5.968Bytes. Reguläre/-O2-Tests, Audit123Luau und
beide Rojo-Builds erfolgreich. Nutzer bestätigte Baseline-Beispiel8; Beispiel9
noch nativ vergleichen.

Neuestes Paket: align-items/align-self:baseline für row/row-reverse ergänzt.
FlexLayout sammelt pro Zeile die größten Abstände vor/nach der ersten Grundlinie;
leere Items verwenden die untere Borderboxkante. Padding/Margins, Wrap/Reverse und
Auto-Margin-Vorrang berücksichtigt. Erste teilnehmende Gruppe der ersten Flexzeile
wird als Container-FirstBaseline für verschachtelte Layouts exportiert. Keine
zusätzlichen nativen Messungen; column baseline vorerst flex-start, keine
first/last-baseline- oder writing-mode-Erweiterung (Katalog/FLEXBOX.md).
tests/FlexBaseline ergänzt; alte Ablehnungstests auf last baseline umgestellt.
Demo nun acht Beispiele, neues Beispiel drei Schriftgrößen18/28/40 mit verschiedenem
Padding. Vollständiges HTML synchron5.094Bytes. Testserie regulär/-O2, Projektaudit
(121Luau) und default/htmlpage-Rojo-Builds erfolgreich. Nutzer bestätigte Beispiel7;
Beispiel8 noch nativ in Studio/Browser vergleichen.

Aktuell (12.09.2026): margin:auto inklusive physischer Longhands und flex-flow
implementiert. Margin/LayoutMargin bleiben numerisch; MarginAuto hält unabhängige
Flags je Stil. Flex verteilt positiven Restplatz nach Grow/Shrink pro Zeile;
Querachsen-auto unterdrückt Stretch/align-self, physische Seiten bleiben bei
Reverse erhalten. Normale Blöcke unterstützen horizontales auto. flex-flow setzt
ausgelassene Komponenten row/nowrap zurück, normale Cascade/important.
hr nutzt jetzt dieselben automatischen Standardränder statt CenterBlock/EndBlock.
Review korrigiert zudem horizontale Scrollausdehnung verschobener Blöcke.
tests/AutoMargins neu, InlineStyle-/Demotests angepasst; sieben kompakte Beispiele,
HTML synchron 4.445 Bytes. Vollständige Tests regulär/-O2, Projektaudit und beide
Rojo-Builds erfolgreich. Umfang/Ergebnisse: PROJECT-REVIEW.md. Erste sechs
Flexbeispiele samt Resize vom Nutzer bestätigt; neues siebtes Beispiel noch
nativ vergleichen. CSS-Katalog und FLEXBOX.md aktualisiert. Historische
Featuregrenzen und offene Sichtprüfungen in älteren Einträgen können überholt sein.

Flexitem-Steuerung ergänzt: align-self auto/stretch/flex-start/flex-end/center, order als signed Integer ±100000, flex-direction row-reverse/column-reverse. Nicht vererbt, Defaults auto/0/row. FlexLayout verwendet effektive Itemausrichtung schon bei intrinsischer Column-Breite; stabile Sortierung einer temporären Itemliste nach Order/SourceIndex vor Line-Collection, DOM/Children unverändert. Hauptachsenposition gespiegelt, unabhängig von wrap-reverse-Querachse; Margins bleiben physisch. Bei ausschließlich Box-Items ZIndex nach sortiertem Rang (Sibling-Modus), anonyme Textitems order0/Containeralign; gemischte Paint-Stapelung und negativer Reverse-Scrollursprung bleiben Grenzen (docs/FLEXBOX.md). BlockLayout.naturalWidth erkennt column-reverse als Spalte. tests/FlexItemControls neu, Testbundler registriert und bisherige Ablehnung von row-reverse angepasst. Sichtdemo sechstes gemeinsames Beispiel: A order1 unten, B order-1 mittig, C order0 oben mit C2 über C1 durch column-reverse; Elternrow-reverse. HTML vollständig synchron. Resizehilfe und laufender Rojo unverändert; letztes Rojo-Re-Serve Port34872 PID6592 (Aftman-Wrapper30136). Demo lädt Resizehilfe nun asynchron mit 4s Timeout; ältere Rojo-Bäume blockieren Seitenstart nicht mehr. Native Sichtprüfung des neuen Pakets ausstehend.

Temporäre Demo-Fensterhilfe auf Nutzerwunsch: examples/ResizableTestWindow.luau als ReplicatedStorage.ResizableTestWindow in default/htmlpage.project.json. Vier blaue Eckgriffe (16px, Overlay ZIndex200/201), Maus/Touch, Gegenkante bleibt stehen; Mindestgröße240×180 soweit Viewport erlaubt, Bildschirmgrenzen, Focusverlust beendet Drag, globale Verbindungen werden bei target.Destroying bzw. page-Cleanup entfernt. Startbreite480, vorherige UISizeConstraint entfernt. HTML body max-width480 entfernt und vollständiges HTML synchronisiert, damit verbreitertes Fenster auch Inhalt verbreitert; stage max-width560 als Autoren-CSS bleibt. Keine Änderung an Engine-Interaktion oder HTML-Features. Native Drag-Sichtprüfung noch durch Nutzer in Studio.

Flex-Wrap ergänzt: flex-wrap nowrap/wrap/wrap-reverse, align-content stretch/start/end/center/space-between/space-around/space-evenly (CSS-Werte flex-start/flex-end). Nicht vererbt, Standard nowrap/stretch. FlexLayout sammelt Zeilen anhand hypothetischer äußerer Hauptachsengrößen vor Grow/Shrink, löst flexible Größen pro Zeile, berechnet Quergrößen und verteilt Zeilen samt Cross-Gap. Wrap-reverse spiegelt Querpositionen einschließlich Itemausrichtung; nowrap ignoriert align-content. Column-Wrap verwendet begrenzte Höhe und intrinsische/provisorische Itembreiten, abschließend Stretch je Spalte. BlockLayout.naturalWidth verwendet für minimale umbrochene Reihen das Maximum statt Summe der Kinder. Gemeinsame distribution-Funktion für Main-/Cross-Abstände, bei negativem Restplatz sichere Fallbacks der Cross-Space-Modi. tests/FlexWrap neu und Testbundler registriert; bestehende Tests erhalten. Sichtdemo um genau ein fünftes Beispiel ergänzt: vier flexible Karten ab160px, gap8/12, feste Höhe180, align-content:center; vollständiges Browser-HTML synchron. Nutzer bestätigte vorheriges Größenpaket visuell, neue Wrap-Demo noch nativ vergleichen. Grenzen weiter docs/FLEXBOX.md, insbesondere komplexe intrinsische/zyklische Layouts und direkte img-Flexitems. flex-flow, row/column-reverse, order, align-self, Auto-Margins noch nicht implementiert.

Flexgrößen ergänzt: flex-grow/shrink/basis und flex-Kurzform, Standard 0 1 auto; Kurzform mit ausgelassener Basis 0% wie Browser. CSS-Katalog, nichtvererbte Felder und normale Cascade/important. FlexLayout löst Basis getrennt von Min/Max, verteilt mit iterativem Einfrieren, gewichteter Schrumpfung und partiellen Faktorsummen. Content-/Border-Box, Margins/gap, row/column, Prozentbasis nur bei bestimmter Hauptachse; automatische Mindestgröße aus untrennbarem Inhalt, min-width/min-height:0 oder overflow:hidden zum Aufheben. BlockLayout MainAxis/MainSize-Hinweise überschreiben die verwendete Hauptachsengröße, ohne Styles zu mutieren; Column-Inhaltsprobe ignoriert eigene Hauptachsengrenzen. NaturalWidth kann minimale/ungeklemmte Inhaltsbreiten bestimmen; WordLayout MeasureOnly liefert Maße ohne GUI-Paint/Fragment-Commit/SkipInk-Messung. Row benötigt keinen vorgeschalteten rekursiven Probe-Layoutdurchlauf. Tests/FlexLayout erweitert für Cascade, Grow/Shrink, Grenzverteilung, partielle Faktoren, Basis/Prozenthöhe, Umbrüche, verschachtelte flexible Items, Reflow und reine Messproben. Sichtdemo hat jetzt vier Beispiele, neue Reihe Fix72 + Basis120/Grow1 + Basis120/Grow2, HTML vollständig synchron. Grenzen weiter docs/FLEXBOX.md: kein wrap/reverse/order/align-self/auto-margins, direkte img bleiben Inline-Modell; komplexe zyklische/intrinsische Flexgrößen und Ratio/Cross-Min-Max noch unvollständig. Erstes Ausrichtungspaket visuell vom Nutzer bestätigt, neue Größenreihe noch nativ vergleichen. Als Nächstes war flex-wrap vorgesehen.

Erstes Flex-Paket implementiert und sichtbaren Alt-Test auf ausdrücklichen Nutzerwunsch vollständig ersetzt. Neue HTML-Seite2.192Bytes mit drei Layoutbeispielen, nurRoboto400/700GoogleFonts; eingebetteterHTMLBlock synchron, ungenutzte IMAGES-Demomap entfernt. tests/HTMLPageDemo auf neuen Inhalt umgestellt, alle übrigen automatischen Regressionstests erhalten. CSS Display stattHidden alsEigenschaftsfeld, Hidden weiterhin abgeleitet; flex-direction row/column, gap1/2px-Werte, justify6Modi, align-items4Modi. Directinline flexchildren blockifiziert, anonymeTextitems. FlexLayout+BlockLayout.naturalWidth/Größenhinweise fürintrinsische/festeItems, Stretch/MinMax/Abstände/Padding/Border, keinMargincollapse anFlexgrenzen, verschachtelterReflow. Blockpositionierung ohne erneutenrekursivenFinaldurchlauf. tests/FlexLayout neu. Grenzen docs/FLEXBOX.md: keinshrink/grow/basis/wrap/reverse/autoMargins/baseline; direktimg nochInlineModell, zyklischeProzente/intrinsicMinContent nichtvollständig. NativeSichtprüfungoffen. Nächste Ausbaustufe flexibleGrößen+wrap.

overflow-wrap:normal/break-word implementiert. Vererbtes Stylefeld/Stilgrenzen; RenderTree-Worterzeugung als CreateWord-Closure wiederverwendet. Neues Layout/OverflowWrap misst bedarfsweise ganze Graphem-Teilstrings (binäre Präfixsuche, bei negativem Tracking linear), begrenzter Cache256/Originalwort, Fragment-GUI-Pool. WordFlow optionaler Splitcallback und DisplayItems als 4.Return; WordLayout misst weiterhin Originale, zeichnet angeordnete DisplayItems mit vorhandenen Linien/Schatten/Backgrounds. Resize zeigt bei Platz Originalwort wieder; letter-spacing nutzt Glyphmaße, ersetzt Gruppen bei geändertem Fragmenttext. nowrap/pre/Images nicht geteilt. Tests/OverflowWrap inkl.Cancellation, Unicode, Stilgrenzen, Reflow, normaleWörter, Baseline/Folgeblöcke, Effekte. Demo eine URL-Zeile, synchron7.251Bytes. Grenzen/Quelle docs/OVERFLOW-WRAP.md: keine zusätzlichen normalen URL-Satzzeichen-Trennstellen oder vollständige Unicode-Regeln, kein anywhere/hyphens/mincontent. Nativer Sichtvergleich offen.

PT Serif jetzt auf Nutzerwunsch Standard und Fallback. CSS/FontFamily.Default="PT Serif"; gültige Liste ohne Treffer liefert false-Marker, InlineStyle löst ihn erst gegen geerbtes style.DefaultFont auf. RenderTree setzt Root Font+DefaultFont, HTMLPage validiert options.DefaultFont vor GUI-Allokation via FontFamily.default (String/Familienliste mit bekanntem Treffer) und reicht kanonischen Font durch. Default pro Seite, keine globale Mutation/kein Auslesen externer Fonts. CSS-Vererbung, explizite Fonts, generische Familien und code/pre-Defaults bleiben. Tests InlineStyle/Stylesheet/PageLifecycle prüfen Standard, getrennte Seiten, wiederverwendete kompilierte Regeln, Optionenweitergabe/Validierung und Priorität. StudioDemoConfig zurück auf HTMLPage; bestehende Demo hat ausdrücklich Roboto im body. Browser-Messseite/README/Katalog aktualisiert. Ursprünglicher Wunsch nach einstellbarem Standard-/Fallbackfont damit umgesetzt.

PT Serif Größe vom Nutzer ausdrücklich visuell bestätigt; anschließend Linienintegration beauftragt und erledigt. Eigenes Layout/FontProfiles/PTSerif.luau mit bestätigtem Faktor1990/1626, Asset12187606624, ceil und vier LS-Geraden gegen native13/25/37/49/62. Gerundet Top/XHeight/Baseline exakt, Bottom bei25=25 statt24 (max1px), andere Punkte exakt. Rohwerte+Methode measurements/pt-serif-guide-fit.json, Check-Guide-Model um PTSerif ergänzt. FontProfiles.get und CSS-Familienregister kennen PT Serif; FontLab verwendet registriertes Profil (TestProfile=nil, TestSizeMultiplier=nil), bleibt aktiv. Browserseite aktualisiert. Noch keine konfigurierbare Standardschrift/Fallbackoption umgesetzt; ursprünglicher Nutzerwunsch bleibt für Anschluss offen. Keine Times-New-Roman-Aliaszuordnung oder Generic-Änderung. Bold/Italic vorläufig Regular-Metriken.

PT-Serif-FONT_REPORT nach Faktor1.223862 empfangen: native Größen13/25/37/49/62, Top2/5/8/11/14, XHeight4/9/14/19/24, Baseline11/20/30/39/49, Bottom14/24/36/47/59. Vollständige Zahlen inkl.TextBounds in measurements/pt-serif-height-comparison.md. Baseline−Top=9/15/22/28/35 gegenüber Browserziel7/13/20/27/33: Größenbestätigung widersprüchlich/noch offen. Manuelle Linien, nicht automatische Glyphenmessung. Vor Integration/Guidefit klären, ob H-Kanten korrekt gesetzt und Größe tatsächlich passend; Testfaktor unverändert.

PT-Serif-Höhen gemessen (12.09.): bei10/20/30/40/50 Roblox6/11/16/22/27, BrowserTimesNewRoman7/13/20/27/33. Least-squares-Faktor1990/1626≈1.223862, FontLab.TestSizeMultiplier gesetzt; ceil ergibt13/25/37/49/62. Vergleichsseite aktualisiert, Rohdaten measurements/pt-serif-height-comparison.md. Neue H-Höhen vom Nutzer zu bestätigen, dann Guides messen; keine Engine-Registrierung oder Default/Fallback-Konfiguration erfolgt.

Aktuell Schriftmessung vor Standardfont-Integration: Nutzer wünscht konfigurierbaren Default/Fallback und nennt Times New Roman / Roblox PT Serif, unterbricht Integration zugunsten Sichttests. FontLab aktiv, Config.Font="PT Serif", TestProfile nur im Labor mit Katalog-ID12187606624, Guides leer, TestSizeMultiplier=1, Größen10/20/30/40/50. FontLab akzeptiert optionalen Config.TestProfile ohne Engine-Registrierung; für registrierte Fonts entfernen. examples/pt-serif-comparison.html verwendet lokale Times New Roman via @font-face-Alias Comparison Times und vorhandene interaktive Messhilfen. Windows times.ttf vorhanden. Zwei verschiedene Familien, keine Gleichheit/Kalibrierung behauptet. Erst H-Höhen, dann Größenkorrektur und x/p-Guides; Default/Fallback-Konfiguration noch NICHT implementiert, Engine weiterhin Arial ohne Treffer. Standardschrift-Arbeit nach Messung fortsetzen.

Schriftlisten implementiert in CSS/FontFamily.luau, Namensregister aus InlineStyle dorthin verschoben. Quote-aware Komma-Scanner, vollständige Syntaxprüfung vor Wahl, unbekannte Familien übersprungen; erste registrierte Familie einmal beim CSS-Kompilieren. Generics sans-serif/system-ui=Arial, serif=Roboto Slab, monospace=Roboto Mono; zitiert keine Generic-Auflösung. Ohne Treffer Arial statt geerbter Font. Ungültige Listen erhalten vorherige Deklaration, CSS-Escapes/-weite Keywords unsupported. Kein per-Glyph-/Ladefehler-Fallback oder Fontdownload. Fontprofile unverändert. Tests InlineStyle/Stylesheet prüfen Listen, Cascade, Vererbung, Quotes, ungültige Folgeteile und separates CSS; Demo verwendet Listen bei bestehenden vier Familien, 7.096 Bytes synchron. README/Katalog aktualisiert.

Separate CSS-Eingabe: Engine.mountHTML(target, HTML, {CSS = CSS, Images = IMAGES}) unterstützt optionalen reinen CSS-String. HTMLPage validiert CSS vor GUI-Allokation und reicht ihn als letztes Argument an RenderTree/Stylesheet.collect weiter. Nach allen eingebetteten Stylesheets mit demselben Parser kompiliert, vor gemeinsamer Spezifitäts-/Quellreihenfolge-Sortierung; wichtig/inline unverändert. Keine HTML-Verkettung oder DOM-Änderung, keine URL-/Dateiabfrage, keine neue Mutation-API. Testskript hat leeres optionales CSS-Feld vor HTML, kombinierte Browserdemo unverändert. README mit getrenntem Beispiel, Kombinationsreihenfolge und Browser-Einbindung. Stylesheet-Tests prüfen Quellenvergleich, Cascade/important, leere Quellen, Seitentrennung und HTML-Endtag in CSS-String; PageLifecycle prüft Weitergabe und ungültige Typen. 

visibility:hidden/visible ergänzt, vererbt, Standard visible; collapse bewusst unsupported. Hidden weiterhin ausschließlich display:none-Pruning. Block-Frames transparent statt Visible=false, damit explizit sichtbare Nachfahren funktionieren; eigene Rahmen/Schatten/Marker unterdrückt. Text/Glyphs TextTransparency=1, Bild-BoxGui.Visible=false, Wrapper für vorherige sichtbare Leerzeichen-/Dekorationsursprünge erhalten. ImageBox.updateFallback berücksichtigt Visibility bei späteren Ladeupdates. InlineWords bewahrt Sichtbarkeitsgrenzen; InlineStyle unterdrückt neue unsichtbare Hintergrund-/Dekorationsursprünge, erhält sichtbare Vorfahrenfarbe/-linien. SkipInk schneidet nicht für unsichtbare Glyphen. Tests/Visibility plus Demoassertions ergänzt; gemeinsame HTML-Demo 7.049 Bytes mit einer Visibility-Zeile. Details VISIBILITY.md. Keine allgemeine Style-Mutations-API; native Sichtprüfung offen.

RGB/RGBA für allgemeine Farben: gemeinsames CSS/Color aus bisherigem Shadow-Parser extrahiert; kommagetrennte RGB/RGBA, Alpha-Hex, transparent/currentcolor. Color3-Felder bleiben, Alpha separat in InlineStyle; Border-Shorthand jetzt Syntax.scan für Funktionsfarben. Alpha an Text/Glyphs/Alt, Hintergründe/Abstände, Rahmen/Listen/Lines und alle currentcolor-Schatten weitergegeben. InlineWords berücksichtigt Alpha-Stilgrenzen; verschachtelte Inline-Hintergründe einmal bei Stilauflösung zusammengesetzt. Inset-Cache berücksichtigt ColorAlpha. Sichtdemo verwendet bestehende Karte für Hintergrund-/Rahmenalpha und word-spacing-Zeile für Textalpha; Body-RGB unveränderte Farbe. Keine neuen Beispielblöcke. Tests/Colors ergänzt, veraltete erwartete Ablehnung von rgb/transparent bei Dekorationstests aktualisiert. Details COLORS.md. Native Sichtprüfung offen.

aspect-ratio für img und Blockcontainer implementiert: auto, Ratio, auto+Ratio; mindestens eine automatische Achse, box-sizing, min/max und Inhaltshöhe berücksichtigt. Layout/AspectRatio kapselt Umrechnung; ImageLayout trennt Autorenratio von natürlichen Inhaltsmaßen; ImageFit spart Metadata-Abfragen bei vollständig bestimmbarer Box. ImageDimensions-Tests prüfen auto-Ratio-Wechsel nach Größenabfrage und unveränderte reine Autorenratio. BlockLayout verhindert Bottom-Margin-Collapsing bei ratio-bestimmter Höhe. Keine allgemeine Min-Content-Breitenberechnung; siehe ASPECT-RATIO.md. Demo 6.820 Bytes synchron, bestehendes cover-Bild jetzt 90px breit mit 16:9 und automatischer Höhe, weiterhin acht Bilder. Neue AspectRatio-Regressionen. Native Studio-Sichtprüfung offen.

Erneute Bild-Codeprüfung: ObjectPosition akzeptiert jetzt CSS-konform 1, 2 oder 4 Komponenten; frühere 3er-Syntax war ein Parserfehler. Viererparser auf zwei Kanten-/Abstandspaare gekürzt. ImageFit vermeidet für fill + wirkungslose Prozentpositionen einen zusätzlichen Clip/CanvasGroup; Pixelversatz bleibt geclippt. Offset-Helfer außerhalb der Layoutfunktion. Regression erst fehlgeschlagen, dann grün; Details PROJECT-REVIEW.md. Demo unverändert. Browserprüfung der lokalen Datei durch URL-Richtlinie blockiert.

Bildanpassung erweitert: object-fit none/scale-down sowie object-position (1/2/4 Komponenten, physische Schlüsselwörter, signierte px/%, Kantenabstände). CSS/ObjectPosition parst unveränderliche Achsenwerte; Layout/ImageFit berechnet Inhalt unabhängig von der Inline-Box. ImageBox verwendet für eigene Geometrie einen Clip-Frame, bei BorderRadius CanvasGroup+UICorner; Standard fill/contain/cover zentriert bleibt nativ. CanvasGroup braucht ScreenGui.ZIndexBehavior.Sibling und Rendertextur-Budget. ImageDimensions fragt auch für explizite Boxgrößen benötigte natürliche Maße ab, weiterhin je Asset/Seite nur einmal und temporäre Instanz sofort zerstört. Ohne Zugriff gelten Attribute/300x150 als angenäherte Inhaltsmaße. Demo synchron 6.803 Bytes, weiterhin acht Bilder: cover rechts oben, none/scale-down mit vorhandenen Alignment-Beispielen kombiniert. ImageFit-Regressionen und Metadata/GuiFactory/Demo-Tests ergänzt; Details docs/IMAGES.md. Native Studio-Sichtprüfung offen.

Automatische Bildmaße implementiert und anschließende Projektcode-Durchsicht durchgeführt: ImageDimensions.start gruppiert nur Bilder mit automatischen Achsen je Asset/Seite, liest CreateEditableImageAsync(Content.fromUri)/Size sequenziell und zerstört jede temporäre Instanz sofort. Kein Polling; Aufruffehler/nil/ungültige Größe nur Diagnose, nie Bildfehler. ImageLayout bevorzugt CSS/HTML; auto nutzt IntrinsicWidth/Height und Ratio, danach bisherige Attribute/300x150. HTMLPage verbindet Abfrage vor ImageLoad mit gemeinsamem erzwungenem Reflow/Cleanup; unabhängige Gruppenkopie überlebt table.clear(ImageItems). Erstes Demo-Bild jetzt ohne Attribute, max-width90; HTML synchron 6.710 Bytes, weiterhin acht geladene Bilder plus Fehlerfall. Tests ImageDimensions/PageLifecycle ergänzt. Review: InlineWords bewahrt WordSpacing-Wechsel im Zeichenmodus (NBSP), Regression vor Fix fehlgeschlagen. Abfrage-Cleanup gibt Gruppen sofort frei, späte Ergebnisse werden zerstört/ignoriert; kein Reflow für bereits aktiven Textfallback. Details docs/IMAGES.md und PROJECT-REVIEW.md. Fontkalibrierungen unverändert, native Studio-Prüfung offen.

Aktueller Fehlericon-Fix: Screenshot zeigt Symbol über geladenen Bildern. Vorher ImageLoad-Fallback bei not IsLoaded (auch pending), ImageBox.arrange setzte ErrorGui.Visible unabhängig vom Ladestatus wieder auf true. Jetzt gemeinsamer ImageBox.updateFallback: fehlende Quelle oder bestätigtes LoadFailed bei weiterhin nicht geladenem Bild; Frame/Alt/Icon gemeinsam aktualisieren, TextFallback weiterhin ohne Icon. Pending und allgemeiner Preload-Aufruffehler zeigen keinen Fehler. Layout ändert keine Fallback-Sichtbarkeit mehr. Tests prüfen direktes Icon-Ausblenden, Pending, Reflow, bestätigten Fehler ohne alt, Textfallback und späte Recovery. Native Sichtprüfung nach Stop/Play offen.

Aktuelle Demo-Kürzung auf Nutzerwunsch: Jedes Feature nur einmal visuell demonstrieren. examples/ubuntu-roboto-page.html und eingebettetes HTML synchron, 6.697 statt 12.637 Bytes (rund 47% weniger). Eine feature-card kombiniert Rahmen/Rundung, Außen-/Innenschatten, Box-sizing, Größenbegrenzung und Seitenabstände. Textstile/Fonts/Grundlinie zusammengelegt, Linienarten einmal pro Variante; pre+tab-size, justify+text-align-last kombiniert. Acht Bilder verbinden object-fit und vertical-align; zusätzlich ein defektes Bild ohne Autorenrahmen. Separate wiederholte Bildbox-, Rahmen-, Größen-, Reset- und Textbeispiele entfernt. Tests/HTMLPageDemo an das kompakte Dokument angepasst, übrige Regressionstests und Engine unverändert. Ältere Demoanzahlen/IDs unten sind Historie.

Aktueller Bildfallback-Fix: Nutzer-Screenshot zeigt „Fehlendes Bild: Landschaft“ mit textengem Rahmen, ohne Icon. RenderTree.TextFallback bei fehlender Zuordnung und nichtleerem alt; ImageLoad setzt ihn nach spezifischem AssetFetch-Fehler und entfernt ihn bei späterem IsLoaded. HTMLPage erlaubt dafür erzwungenes, zusammengefasstes Reflow auch bei gleicher Breite. WordLayout misst Alt einmal je Text/Font/Größe/Gewicht/Stil; ImageLayout ignoriert für diesen Fall Bildmaße, nutzt Textgrundlinie und horizontale Boxkanten, vertikale Padding/Margin ändern die Zeilenhöhe nicht. ImageBox versteckt Icon nur im Textfallback und legt Rahmen um Text. Pending/kein alt behalten Symbol, alt="" kein Symbol; allgemeiner Preload-Aufruffehler ist kein endgültiger Bildfehler. Tests für Textgeometrie/Cache, Ladefehler/Recovery und erzwungenes Reflow ergänzt. HTML unverändert. Alt bleibt atomar und hat noch keine eigenen Spacing/Transform/Shadow/Decoration-Effekte; Details docs/IMAGES.md. Native Studio-Sichtprüfung offen. Ältere Aussagen zu stets reservierten Fehlerboxen unten sind überholt.

Fehlersymbol für Bilder ergänzt: Nutzer liefert rbxassetid://112299903593689 mit festen12x14px und Offset5links/4oben ab innerer Rahmenkante. ImageBox verwendet ein transparentes, rechteckig clippendes FallbackGui an border/border und ein ErrorGui darin bei5/4; Padding/Margin ändern den Symboloffset nicht. AltGui nun im Fallback neben Symbol (mindestens4px Abstand). EmptyAlt am ImageItem unterscheidet fehlendes alt von alt="": fehlend zeigt Icon, leer unterdrückt Fallback. ImageLoad schaltet FallbackGui zusammen mit Alt bei IsLoaded um, auch verspätetes Laden; keine zusätzlichen Layout-/Textmessungen. Bekannte ungültige Quelle zeigt sofort Fallback, wie bisher auch während ausstehendem Laden. Hauptdemo um absichtlich ungültige data:image/png,broken ergänzt (1 erwartete Renderdiagnose, Browserdekodierung ebenfalls defekt); HTML synchron12637Bytes. Tests Images/ImageAlignment/HTMLPageDemo prüfen Maße/Offset mit Rahmen+Padding, Reflowreuse, leeres/fehlendes alt und spätes Ausblenden. Die neue Icon-Asset-Verfügbarkeit/native Optik muss in Studio noch verglichen werden.

Bildausrichtungen/Boxmodell ergänzt: Nutzer möchte Bilder abrunden und Ausrichtung an Textlinien. img vertical-align jetzt baseline/super/sub + middle,text-top,text-bottom,top,bottom,signiertepx/%; neue Werte bewusst img-only, Inline-Text bleibt bei bisherigen drei. ParentStyle am ImageItem für Eltern-Fontmetriken/Shift. ImageLayout.align berechnet Marginbox-Grundlinie, middle über Baseline-XHeight/2, text-top/bottom über logische Fontbox, % über eigene line-height. WordFlow ignoriert top/bottom zunächst bei A/D, erweitert fertige Zeile minimal und positioniert am Zeilenrand; Reset pro Umbruch. ImageLayout.size berücksichtigt Border-box/minmax sowie Padding/Rand/Margin. Rendering/ImageBox ersetzt Bildbau in RenderTree: Margin-Frame, Box-Frame mit Rand/Hintergrund und Bild-/Alt-Inhalt. UICorner außen und am tatsächlichen ImageLabel, innerer Kreisradius reduziert um Border/maxPadding (ungleiche Paddingradien angenähert); UIStroke Round nur mit UICorner, sonst Miter; inset-Rahmen Vierkanten. Keine Bildschatten/Blockdarstellung neu. Tests/ImageAlignment neu, bestehende Images/Demo angepasst. Demo synchron12462Bytes, nun13Images:3fit+5alignment+4shift+1box. IDs15773523297 und Browser-PNG unverändert. docs/IMAGES und Element-/CSS-Katalog aktuell. Native Sichtprüfung für neue Bildausrichtungen/Rundung offen.

Text-shadow-Prototyp implementiert: Nutzer will zuerst scharfe Labelkopien mit Offset/Farbe/Alpha und mehreren Schatten ausprobieren; Font-Fallbacklisten ausdrücklich später. CSS/BoxShadow.parse teilt Farb-/Längengrammatik über optionalen Textmodus (2–3 Längen, Blur nur0, kein inset/Spread, max16); Properties.TextShadows vererbt, none erlaubt, Cascade/important wie bisher. InlineWords.sameStyle vergleicht auch Schattenrecords, damit Stilwechsel ohne erfundene Wortabstände bleiben. Rendering/TextShadows erstellt zusätzliche Labels pro Wort/Graphem mit ZIndex16..1, Vordergrund17, Dekoration18. Normale Schattenwörter bekommen Frame+TextGui; Hintergrund bleibt am Frame. WordLayout übernimmt Maße/Font/Position aus bestehender Messung, keine zusätzlichen Textmessungen; Labelreuse bei Reflow. Aktuelle Einschränkungen: keine Schatten der Textdekorationen/Listenmarker/alt, keine Unschärfe; je Wort gestapelt, großer Offset kann Nachbartext überdecken, Zeichenalpha überlappt unabhängig. Layout/Scrollgrößen unverändert. Tests/TextShadows und Demo-Assertions neu. Gemeinsames HTML synchron11174Bytes: ein Absatz nach Schriftstil mit einfachem Schatten, zwei Schatten+letter-spacing und none. docs/TEXT-SHADOW.md und Katalog aktualisiert. Native Sichtprüfung noch offen.

Bildladefehler behoben (Code/Zuordnung): Studio-Log meldete für alte Beispiel-ID 6319951718 AssetDelivery403IncorrectAssetType / Asset type does not match requested type. Nutzer liefert rbxassetid://15773523297; IMAGES im Seitenskript und Demo-Test aktualisiert. Browser-PNG unverändert. ImageLoad preloaded jetzt ein ImageLabel je Asset-ID statt roher URI, wertet PreloadAsync-Statuscallback aus und meldet URI/Fehlerstatus dedupliziert. HTMLPage leitet asynchrone Bilddiagnosen auch an warn weiter (bisher nur im DOM, nach dem einmaligen Demo-Diagnoseauslesen). Bild-Labels bleiben sichtbar; IsLoaded-Signal entfernt Alt-Text auch bei verspätetem Laden. Initialer Alt-Text statt leerer Box. Keine Wiederholungs-/Polling-Schleife. ImageLoad liefert idempotente Listener-Cleanup-Funktion an PageSession. Tests für verspätetes Laden, nichtwerfende Ladefehler, Seitenlöschung und Cleanup ergänzt. Neuer nativer Sichtvergleich nach erneutem Play noch offen. Frühere ID-Angaben unten sind historisch.

Aktuelle Nutzerkorrektur: Bildzuordnung direkt oben im Seitenskript, z.B. landschaft.png=6319951718. Umgesetzt als local IMAGES im Kopf von examples/HTMLPage.client.luau und Engine.mountHTML(target,HTML,{Images=IMAGES}). Kein zentraler Engine-Bildkatalog; kurz angelegte ImageAssets.luau wieder entfernt. Rendering/ImageSources.newResolver validiert numerische/Dezimalstring/rbxassetid IDs und löst exakte src-Schlüssel auf (führendes ./ und äußerer Leerraum normalisiert; unbekannt→nil). HTMLPage erzeugt vor GUI-Allokation einen privaten Snapshot, als page.ResolveImage(src) verfügbar. Engine.ImageSources exportiert. Tests/ImageSources und PageLifecycle prüfen Lookup/Validierung und Seitentrennung. docs/IMAGES.md erklärt die Grenze: img weiterhin parser-only, eigentliche Bilddarstellung noch nicht angebunden. HTML unverändert; Beispiel-Asset-ID vom Nutzer, Bildinhalt/Verfügbarkeit und passende Browserdatei noch nicht geprüft. Nächster Schritt img-Renderer an Resolver anbinden.

Neuester Stand: Nutzer hat Außenschatten bestätigt und inset beauftragt. CSS/BoxShadow akzeptiert Inset-Flag vor/nach kompletter Längengruppe, auch gemischt mit außen. Native UIShadow nur für außen. Inset-Blockcontainer ist ImageLabel (eigene Bildebene hinter Kindern/Text, über Background); InsetShadows als seitenbezogener Renderer in HTMLPage erzeugt/aufgeräumt, RenderTree reicht ihn an betroffene Boxen, BlockLayout ruft Draw nach endgültiger Größe auf. InsetShadowPixels (optimize2/native) rendert gerundete Paddingbox-/Lochmasken, Gaussian-Näherung durch drei lineare Boxfilter (sigma=Blur/2; kleiner Blur Dreipunktfilter), invertiert und komponiert CSS-Reihenfolge und Alpha. Bild bleibt innerhalb Paddingbox, Border frei. Kein Layout-/Textmaß-Einfluss, keine Textschatten. Cache je GUI+Maße+Radius/Rand+Styleliste+Farbe; gleiche Rastergröße aktualisiert bestehende EditableImage, sonst alte vor Ersatz zerstört. Zero-Size und PageDestroy geben frei. Grenzen32Karten/1M Bildpixel pro Seite, Raster adaptiv für max1024 Bildseiten und begrenzte Arbeitspuffer; API-/Budgetfehler mit einmaliger Diagnose, Inset dann unsichtbar. Tests/InsetShadows neu und PageLifecycle ergänzt. Gemeinsames HTML synchron10.489Bytes; Innenschattenkarte nach Außenschattenkarte. Reine Raster-PNG900×70 in build/inset-preview.png visuell geprüft, kein Studiovergleich. Details/Grenzen docs/BOX-SHADOW.md; nativer Inset-Sichtvergleich offen. Vorherige bestätigte Außen-/Textlinien unverändert.

Aktuell: Nutzer bestätigt auch overline/text-decoration-line visuell. Textschatten auf Nutzerwunsch vorerst ausgelassen; stattdessen box-shadow für Karten eingebaut. CSS/BoxShadow.luau separater Parser für none oder max16 Außenschatten, signierte 0/px-Offsets/Spread, Blur0–1000px, bestehende Farben/currentcolor sowie transparent/Alpha-Hex/kommagetrennte rgb(a). Einmalige CSS-Kompilierung, nicht vererbt, immutable Records, vollständige Deklaration bei Invalid verworfen. RenderTree erzeugt UIShadow direkt am Block-Frame, ZIndex=-index (erster CSS-Schatten vorn), Alpha→Transparency, Blur/Offset/Spread direkt in px; vorhandene UICorner und Frame-Resize nativ. Kein neuer Layout-/Messcode. API-Fehler einmal diagnostiziert, Restseite bleibt benutzbar. Native Blur/Spread/Clipping-Gleichheit noch offen; text-shadow/inset/Inline-Box-Schatten nicht implementiert. Details/Quellen docs/BOX-SHADOW.md. Gemeinsames HTML synchron 10.263 Bytes, eine Schattenkarte direkt nach h1. Tests/BoxShadow neu, GuiFactory-Test und Bundler ergänzt. Vorher bestätigte Schriften/Textlinien unverändert.

Aktuell: Nutzer bestätigt die fünf Linienmuster visuell als „genau 1 zu 1 gleich“. Anschließend overline und text-decoration-line autorisiert und ergänzt. Beide CSS-Schreibweisen akzeptieren none oder eindeutige Kombinationen aus underline/overline/line-through. Properties.ResetDecoration nur auf Kurzform; Compiler reicht Flag weiter, apply setzt nur dort Farbe/Dicke/Style zurück. Longhand bewahrt diese Komponenten, auch nach none. Immutable Origin-Record ergänzt Overline und OverlineOffset=-FontMetrics.resolve(originStyle).Baseline; obere Fontboxkante ist Näherung, nicht H-Kante, keine neuen Fontkalibrierungen. Ursprung bleibt bei Nachfahren mit anderer FontSize erhalten. Renderer verwendet vorhandene Frames/Images und Muster; double/wavy wachsen oberhalb der normalen Overline, Skip-ink bleibt nur bei Unterlinien. Maße/Zeilenhöhe/Scrollfläche unverändert. Tests/TextDecoration und DecorationStyles prüfen Kombinationen/Invalid/Cascade/important, Reset-Unterschied, Ursprünge, alle fünf Muster, Abstand/Reflow/Wiederverwendung. HTML synchron 10.076 Bytes mit einem Überstrich- und einem Longhand-Kombinationsbeispiel. Neue Overline-Höhe noch vom Nutzer visuell abzugleichen; bestätigte Mustergeometrie unverändert.

Neuester Stand: text-decoration-style als Prototyp zum Nutzervergleich eingebaut. solid/double verwenden wiederverwendete Frames; dotted/dashed/wavy verwenden weiße RGBA-Kacheln aus Rendering/DecorationPixels (4×4 Alpha-Abdeckung), via DecorationPatterns einmalig in EditableImages geschrieben und pro Seite nach Style+Dicke geteilt. ImageLabels mit TileSize/Clipping und Phase (item.X+segment.Left)%Period, per ImageColor3 eingefärbt. Wavy-Höhe 3t/Periode8t, dotted 2t, dashed6t mit 3t Strich; double zwei t-Striche mit t Abstand. Strike mehrzeiliger Muster um bestehende Mittellage zentriert. Native Browsergeometrie nur angenähert; Sichtvergleich offen. SkipInk berücksichtigt Musterhöhe bzw. jede double-Linie einzeln und schließt Lücken unterhalb der Guides weiterhin. Kein Einfluss auf Textmaße/Zeilenhöhe; dekorativer Überstand erweitert Scrollfläche weiterhin nicht.

HTMLPage besitzt den lazy Pattern-Cache, reicht ihn an alle Runs weiter und zerstört EditableImages beim PageSession-Cleanup. Grenzen: 1–32px Dicke, max16 Muster/max65536 Pixel pro Seite; keine Downloads/Frame-Loops. CreateEditableImage nil/Fehler führt zu solid und einmaliger Diagnose plus Output-Warnung; vorhandene Bilder bleiben verwendbar. Roblox muss EditableImage erlauben; Einstellungen unverändert. Properties unterstützt nichtvererbtes DecorationStyle; Herkunftsrecord bewahrt Style. text-decoration-Kurzform setzt Style auf solid zurück, volle Style/Farb-Kurzform weiterhin unsupported. Gemeinsames HTML mit fünf kompakten Zeilen bei24px/2px Dicke, synchron 9.789 Bytes. Neue Tests/DecorationStyles plus GUI- und PageLifecycle-Erweiterungen prüfen Raster/Cache/Limits/Cleanup/Cascade/Phase/Reflow/SkipInk/Fallback. Tests normal/O2, Projektaudit und Rojo-Builds geprüft; keine native Sichtprüfung behaupten. Der folgende Stand ist Historie.

Aktuelle Gesamtprüfung auf Nutzerwunsch vor text-decoration-style: zwei reproduzierte Fehler behoben. RenderTree.resolve prüft jetzt Hidden auch bei br, somit kein Umbruch/keine Worttrennung für display:none einschließlich Cascade/important. TextDecoration überbrückt Joined-Tracking-Lücken nur für gemeinsame Dekorationsursprünge beider Wortfragmente, nicht für getrennte u-Origins. Regressionen Elements/TextDecoration erst fehlgeschlagen, nach Fix bestanden. Optimierungen: keine Segmenttabellen für Wörter ohne Linien/Gappedekoration/vorhandeneFrames; WordLayout.metricsFor speichert reine FontMetrics je Stil nur innerhalb eines Layoutdurchlaufs, keine gemeinsamen Textmaße. FontWeight-Test prüft 1 statt 6 Profilberechnungen bei A B C, fünf weiterhin individuelle native Messungen, Resize und neue FontSize im Folgedurchlauf. Details docs/PROJECT-REVIEW.md. HTML unverändert 9.192 Bytes, Schriftfaktoren unverändert. Geplante Linienarten weiterhin nicht implementiert. Native Sichtprüfung offen.

Aktueller Fix: Nutzer meldet offene Unterstrich-Lücken trotz weit nach unten versetzter Linie und schlägt Guide-Nutzung vor. FontMetrics.resolve liefert jetzt XHeight/Bottom aus dem bestehenden Fontprofil (Fallback round(TextSize*.3)/TextSize). WordLayout speichert diese als SkipInkTop/Bottom pro Item vor SkipInk.measure. SkipInk.intersects prüft halboffene Rechtecküberschneidung von Baseline+UnderlineOffset bis +Thickness mit XHeight..Bottom. measure überspringt Präfixmessungen, wenn keine aktive Unterlinie überlappt, ohne leeres Cuts-Resultat zu cachen; bestehende Cuts bleiben nutzbar. TextDecoration verwendet dieselbe Prüfung je Ursprungsdekoration, schließt somit Lücken unterhalb p-Unterkante und blendet überzählige Frames aus. Tests decken Mono20 mit Baseline21/Bottom25 (offset4 geschlossen, offset3 offen), Cache/Frame-Wiederverwendung beim Hin-/Zurückverschieben, Dicke, mehrere Größen/Fonts/Fallback, geschichtete Linien und letter-spacing ab. Demo pgjqy im 6px-Offset-Beispiel, HTML synchron 9.192 Bytes. Näherung für alle fünf Descender gleich, keine echten Glyphenkonturen; Bold/Italic weiterhin Regular-Guides. Native Sichtprüfung offen.

Neuester Ausbau: Nutzer bestätigt text-decoration-color und text-underline-offset. Properties: DecorationColor nicht vererbt/Inline, vorhandene Farben+currentcolor; UnderlineOffset vererbt als nil(auto) oder {Value,Percent}, signierte px/%/0. Parsing verwendet gemeinsamen signed-Length-Zweig; auto setzt geerbten Wert zurück. Bei neuer Dekoration aktuelle Farbe am Ursprung auflösen, Offset aus Ursprungsschrift/Prozent oder px runden, auto weiterhin max1round(size/14); Vorfahrenrecords unverändert, StrikeOffset unverändert. Gültige text-decoration-Kurzform setzt DecorationColor/DecorationThickness zurück, Offset nicht. TextDecoration-Renderer unverändert, bestehende Frames übernehmen Farbe/Offset. Tests/TextDecoration + Demoassertions ergänzen Cascade/Prozentvererbung/Reset/Ancestor/Nesting/Negative/Invalid/Render/Reuse. Zwei kompakte Varianten im Absatz decoration-options, gesamtes HTML synchron 9.185 Bytes. Native Sichtprüfung offen. SkipInk bleibt horizontaler Buchstabenheuristik ohne Prüfung der Y-Überschneidung; bei starkem Offset mögliche überflüssige Lücken, explizit dokumentiert. Keine Alpha-Farben/em/rem/full shorthand. Tests und Grenzen in docs/SMALL-ELEMENTS.md.

Neuester Ausbau: Nutzer bestätigt Margin-/Padding-Longhands und h3–h6. Properties erzeugt acht schreibgeschützte Einträge mit Field Margin/Padding, Side 1–4, Kind spacing-side (nichtnegative px/0). Compile erhält Side; apply aktualisiert einzelne Arrayeinträge in bestehender Cascade. Pro-Seite-Margin-Maske verhindert Überschreiben gültiger Autorenwerte durch spätere dynamische Defaults von pre/blockquote/hr/Listen/Headings. HR bleibt bei nur vertikaler Longhand zentriert; nur margin-right erhält automatische linke Seite über EndBlock im BlockLayout. Neue Katalogmetadaten FontSizeScale/MarginBlockEm: h3 1.17/1, h4 1/1.33, h5 .83/1.67, h6 .67/2.33, FontWeight700. Größe vor Autorregeln aus parent, Ränder danach aus finaler Größe. h1/h2 unverändert. Tests InlineStyle/Elements/HTMLPageDemo/MarginCollapse erweitert inkl. Cascade/Defaults/Geometrie/Reflow. Ein Beispiel pro Heading und eine Box für acht Seiten, vollständiges HTML synchron 8.967 Bytes. Standardquelle/Grenzen in docs/SMALL-ELEMENTS.md. Native Sichtprüfung offen.

Roboto Mono abgeschlossen: Nutzer bestätigt „grösse stimmt“ für Faktor 1.24/ceil. Vorheriger FONT_REPORT wurde ausdrücklich bei nativen TextSize 10/20/30/40/50 und Faktor1 aufgenommen. Eigene Guides jetzt gegen diese nativen Größen gefittet (nicht gegen nachträglich skalierte HTML-Größen): Top=.28*s-1.6, XHeight=.4*s-1, Baseline=.8*s+1, Bottom=.95*s+1.3, jeweils max0/round und s=ceil(native request). Alle fünf Messpunkte gerundet exakt; Zwischenwerte geschätzt, >50 extrapoliert. Daten measurements/roboto-mono-guide-fit.json mit scale=1 als Messfaktor, confirmedProfileScale=1.24 getrennt. Profil GuideSizeRounding=ceil. FontProfiles-Tests und check-guide-model um RobotoMono erweitert. StudioDemoConfig wieder HTMLPage; FontLab-Konfiguration bleibt Mono für spätere Messungen. Linien bei korrigierten Größen nicht separat visuell bestätigt.

Roboto-Mono-Größenabgleich: Nutzer liefert H-Höhen bei 10/20/30/40/50px: Roblox 7/12/17/22/28, HTML 7/14/21/28/35. Faktor wie bisher über Least-Squares durch Ursprung: 2170/1750=1.24. RobotoMono.SizeMultiplier jetzt 1.24; ceil-TextSize 13/25/38/50/62. Vergleichs-HTML und ROBOTO-Doku aktualisiert, Rohdaten in measurements/roboto-mono-height-comparison.md. FontLab bleibt aktiv, nutzt automatisch Profilfaktor. Neue sichtbare H-Höhen noch vom Nutzer zu bestätigen; Guides bleiben nil, bis absolute Linienpositionen nach Größenbestätigung gemessen sind. Nach Abschluss wieder HTMLPage aktivieren.

Aktuell: Nutzer meldet abweichende Code-Schrift und möchte Roboto Mono wie die anderen Fonts aufnehmen/angleichen. Familie war bereits registriert, Faktor/Guides aber ungemessen. FontTestConfig jetzt Roboto Mono, TestSizeMultiplier=nil (noch Faktor 1); StudioDemoConfig vorübergehend FontLab. Bestehender Rojo-Port 34872 geprüft. roboto-mono-comparison.html lädt jetzt wie die HTML-Demo Google Fonts statt lokaler Katalogdatei; Font-Ladeprüfung quotiert Familiennamen mit Leerzeichen. Nutzer muss H-Höhen bei 10/20/30/40/50px aus beiden Ansichten liefern; dann Faktor bestimmen, überprüfen, anschließend Guides messen. Keine erfundenen Profilwerte setzen. Nach abgeschlossener Kalibrierung wieder HTMLPage aktivieren. Größenanpassung noch offen.

Neuester Ausbau: Nutzer „gu“ bestätigt small, code/pre und blockquote. Neue Elementkatalogeinträge: small FontSize=smaller ohne eigenes line-height/Shift; code Font=Roboto Mono; pre zusätzlich WhiteSpace=pre und dynamische 1em-Margins; blockquote dynamisch 1em/40px. InlineStyle akzeptiert monospace als registrierte Roboto-Mono-Zuordnung. Browsergenerik nicht fontidentisch garantiert; gemeinsame Demo setzt code/pre ausdrücklich auf Roboto Mono und ergänzt Google-Fonts-Familie inklusive aller vier Schnitte. Fontprofil unverändert/unkalibriert. Parser überspringt genau einen LF im unmittelbar nächsten Texttoken nach pre, Kommentar/Whitespace/Kindtag davor verhindert das; DOM ab dann normal erhalten. BlockLayout.prepareMargins schließt blockquote ein, damit Absatz-/verschachtelte Zitatabstände nicht doppelt werden. Tests/SmallElements + Demoassertions ergänzt, Headerfont-Test jetzt vier Familien. Gemeinsames vollständiges HTML synchron, 8.498 Bytes. Native Sichtprüfung weiterhin offen. Docs/SMALL-ELEMENTS beschreibt Standards, Quellen und Grenzen.

Neuester Ausbau: Nutzer bestätigt alle vier kleinen Funktionen hr, mark, sup/sub und text-align-last; ausdrücklich Browsergrößen/-abstände für sup/sub prüfen. Implementiert und gegen Primärquellen recherchiert: smaller=Elternschrift/1.2 (min1), sup-Shift=-(Elternschrift/3+1), sub=Elternschrift/5+1 auf 1/64px; Standard line-height normal. CSS vertical-align baseline/super/sub, smaller, text-align-last und Inline-Background/transparent ergänzt. InlineWords bildet bei Stilwechseln jetzt zusammenhängende Fragmente statt Erststil-Diagnose; WordFlow hält sie zusammen, WordLayout berücksichtigt Shift und Tracking-Übergänge. Bestehende Teilworttests entsprechend auf neue Darstellung umgestellt. TextDecoration zeichnet zusätzlich native Wort-/Space-Hintergründe sowie wiederverwendete GapBackground-Frames. HR hat 1px inset/gray/hidden, 0.5em Margin und automatische Zentrierung; inset als vier einfache zweifarbige rechteckige Kanten, solid bleibt UIStroke. TAL auto/left/center/right/justify/start/end, auch vor br/Quelltext-Breaks; keine vollständige text-align-Shorthand-Semantik. Tests/SmallElements ergänzt. Gemeinsame Demo synchron, 8.068 Bytes. Einzelheiten/Quellen/Grenzen in docs/SMALL-ELEMENTS.md. Native visuelle Studio-Prüfung offen. Ältere Hinweise auf fehlende Teilwortstile oder Erststilregel unten sind überholt.

Neuester Ausbau 11. September 2026: Nutzer bestätigt Listen und betont visuelle HTML-Abstände. ul/ol/li im Elementkatalog; list-style-type disc/circle/square/decimal/none im CSS-Katalog. InlineStyle berechnet Listen-Defaults nach CSS-FontSize (1em vertikale Margin, nested 0), 40px linkes Padding aus Katalog, ul-Marker nach Tiefe; Autor-Margin gewinnt. RenderTree erzeugt Außenmarker (Frames für Symbole, Label für Dezimalzahlen, im Font-Preload) und zählt gerenderte direkte li unabhängig pro Liste, inklusive start/reversed/value. Display:block entfernt li-Marker. Neues Layout/ListMarker misst Dezimalmarker inklusive Punkt/Space per Item, cached Schrift/Text/Größe, Alive-Prüfung vor Schreiben. Symbolgeometrie an Blink angelehnt mit FontMetrics.Baseline als angenäherter Ascent. WordFlow liefert dritte Rückgabe FirstBaseline, WordLayout/BlockLayout reichen sie durch; Marker ändern Inhaltsbreite nicht, leere li mit Marker erhalten Zeilenhöhe. BlockLayout.prepareMargins berechnet einmal pro Layout effektive Margin für ul/ol/li, damit Absatzränder oben/unten zusammenfallen; allgemeines Eltern-Kind-/Leerblock-Collapsing weiterhin unvollständig. OwnBottom erhält sichtbaren Overflow bei kollabiertem Endrand. Parser unterstützt einfache ausgelassene li-End-Tags innerhalb der nächsten Listengrenze. Tests/Lists + Demo-Assertions ergänzen bisherigen Testsatz. Demo UL mit Unterliste und OL start=9 (9/10) synchronisiert, 7.555 Bytes. Native Sichtprüfung offen; keine Behauptung pixelidentischer Darstellung. Begrenzungen und Quellen in HTML-SUPPORT.

Neuester Ausbau: Nutzer bestätigte tab-size, pre-line und break-spaces. CSS-Katalog/Parser unterstützen alle sechs white-space-Werte sowie vererbtes TabSize {Kind=number/px,Value}, Default 8, nichtnegative Werte inklusive Brüche/0. InlineWords kollabiert in pre-line Leerzeichen/Tabs, erhält aber normalisierte Breaks; break-spaces erzeugt einzelne Space-Einträge je U+0020/Tab. WordFlow kann dadurch nach jedem erhaltenen Zeichen umbrechen, auch bei reinen Leerzeichenzeilen; der erste Space bleibt am vorigen Wort. Endleerzeichen in break-spaces zählen zur Breite/Alignment/Dekoration. WordLayout benutzt für numerische Tabs die nächste Blockschrift und deren Spacing, für px direkte Stopps; abweichende Blockschrift-Messungen sind je Item gecacht und Alive-geprüft. Zusätzliche Tests für alle Modi, Entity-Tabs, Zahlen/px/Null, Cascade/Vererbung, Block- vs. Inline-Schrift/Spacing, Fontänderung, Resize, Leerraumüberlauf und Dekoration. Drei kurze Beispiele im gemeinsamen HTML (7.074 Bytes) synchronisiert. Native Sichtprüfung offen. Bekannte ältere pre-wrap-Einschränkung (Endleerraum hängt auch vor festen Breaks/am Blockende vollständig) jetzt ausdrücklich in HTML-SUPPORT dokumentiert; nicht in dieser Erweiterung geändert. Historische Angaben zu nur vier Modi/festen Tabs unten sind überholt.

Aktueller Tab-Fix: Nutzer meldet zu kleinen Abstand nach „Eingerückt“ im pre-Beispiel (HTML enthält Eingerückt&#9;nach). WordFlow verwendete eine halbe Leerzeichenbreite als Mindestvorschub, CSS fordert 0.5ch. WordLayout misst nun nur bei Tab-Space-Einträgen zusätzlich die Ziffer 0 und speichert TabMinimum zusammen mit der nativen Leerzeichenmessung; Alive-Prüfung nach Messung, Cache-Schlüssel erst nach Erfolg. WordFlow überspringt zu nahe Stopps anhand dieser Grenze. Tests prüfen beide erhaltenden Modi, unter/genau an der Grenze, Start auf einem Tabstopp, numerische Tab-Entity und Resize ohne Messungen. Gemeinsames HTML unverändert; tatsächlicher Screenshot-Abstand in Studio noch nicht visuell bestätigt. Vorherige Demo-Korrektur: pre-wrap-Beispiel hat rechts 6px Padding, synchron im HTMLPage-Skript.

Neuester Ausbau: white-space normal/nowrap/pre/pre-wrap, vererbt. InlineWords erhält beim pre/pre-wrap-Pfad Space-Einträge (Text/SpaceCount/Style) und Breaks mit Stil; DOM unverändert. RenderTree baut transparente Frames für Space, nur Wörter werden TextLabels bzw. Graphem-Frames. WordLayout misst je Space-Eintrag ein individuelles natives Leerzeichen, berechnet SpaceUnit/8-Space-TabWidth und Tracking-Übergänge; keine FontFace/TextSize-Schreibzugriffe auf Space-Frames. WrapBefore wird anhand des Leerraumstils gesetzt. WordFlow prüft zusammenhängende nowrap/pre-Gruppen vor Umbruch, positioniert Tabs, behandelt pre-wrap-Endleerraum hängend und erhält Einrückungen/Leerzeilen. TextDecoration kann die Space-Frames direkt verwenden. Tests/WhiteSpace prüfen vier Modi, Vererbung/Cascade, inline-nowrap, führende/mehrfache/abschließende Leerzeichen, Tabs, Leerzeilen/br, Ausrichtung/justify/indent, Spacing/Dekorationen, Clipping, DOM-Erhalt und Messwiederverwendung. Demo: bestehender Absatz explizit normal; je ein zusätzliches kompaktes Beispiel für nowrap/pre/pre-wrap. Kein pre-Tag-Default, pre-line/break-spaces/tab-size, volles Unicode-Layout oder dynamischer Strukturwechsel. Tabstopps mit justify und komplexe gemischte Whitespace-Grenzen bleiben Näherungen. Sichtprüfung offen.

Neuester Fix: Nutzer meldete doppelt große VERTIKALE Lücken zwischen Karten/Absätzen, nicht Wortabstände. BlockLayout lässt benachbarte Block-Margins nun mit max(unten, oben) zusammenfallen; tatsächliche Textläufe unterbrechen, Leerraum/display:none nicht. Kein Eltern-Kind-/Leerblock-Collapsing ergänzt. Die vertikale Scrollausdehnung addiert außerdem unteren Box-Margin nicht mehr auf überlaufende Kindinhalte. tests/MarginCollapse sichert ungleiche/Standardabstände, Rahmen/Padding/overflow, Texttrennung, versteckte Blöcke und Resize-Messwiederverwendung. Schriftgrößen, Wortabstände, letter-spacing und Test-HTML wurden dafür nicht geändert.

Aktueller Stand 10. September 2026: Nutzer hat Größenregeln akzeptiert, Rojo läuft mit default.project.json auf localhost:34872. Neu auf seine Freigabe: min-height auto/0/px, max-height none/0/px und overflow hidden/visible (keine neuen ScrollingFrames). Nicht vererbt, keine Prozenthöhen. RenderTree setzt ClipsDescendants nur für hidden. Einfacher rechteckiger Zuschnitt am Außenframe, kein abgerundetes Padding-Clipping. BlockLayout trennt Flusshöhe von vertikaler Überlaufausdehnung (dritter Rückgabewert); beim Dokument liefert der erste Wert weiterhin die Canvas-Höhe. Feste/maximale Höhen verdrängen nachfolgende Geschwister nicht mehr durch überlaufende Kinder. Sichtbarer Überlauf bleibt scrollbar, hidden begrenzt beide Ausdehnungen. Tests/Overflow deckt Box-Sizing, Grenzenkonflikte, Nullhöhen, verschachteltes Clipping, Geschwister, CSS-Cascade und Resize ohne neue Messungen ab. Gemeinsames HTML um zwei kompakte Boxen ergänzt und synchronisiert.

Anschließender Projektcheck auf Nutzerwunsch: Größenkonvertierung in einen gemeinsamen Helfer verschoben; min/max-Parser für Breite/Höhe zusammengeführt (Kind min-size/max-size, AllowPercent nur bei Breiten). InlineStyle bestimmt vererbbare Felder einmal aus dem unveränderlichen Katalog. Stylesheet.match erzeugt Listen erst bei einem Treffer, sonst gemeinsame eingefrorene Leerdaten. Elementkatalog und veraltete Größen-/Clipping-Angaben berichtigt. Bestehende Fontfaktoren, Linienformeln, Wort-/Graphemstruktur und individuelle Messungen erhalten. Details/Prüfgrenzen: [CODE-REVIEW.md](CODE-REVIEW.md). Die folgenden Abschnitte enthalten auch die Historie; der aktuelle Stand hier und die Supportkataloge haben Vorrang.

Aktuell nach Nutzerfreigabe „weiter gehts“ ergänzt: box-sizing content-box/border-box und min-width (auto/0/px/%), max-width (none/0/px/%), ohne Vererbung. BlockLayout rechnet mit horizontalen/vertikalen Padding-/Rahmenkanten, konvertiert explizite Maße und Grenzen in Inhaltsmaße, klemmt zuerst max dann min (Minimum gewinnt). Bei border-box enthalten Breite/Höhe die Kanten, Margin bleibt außen. Auto-Größen bleiben füllend. Inhalt darf 0 sein: alte künstliche Mindestbreite von 1px in BlockLayout/WordLayout entfernt; ganze Wörter laufen bei 0 Breite über, ohne leere erste Zeile. Prozent relativ zur aktuellen Eltern-Inhaltsbreite; keine intrinsischen Maße, em/rem, calc oder min/max-height. box-sizing auf Inline-Stilen akzeptiert ohne eigene Layoutwirkung, damit Universalregeln funktionieren. Tests/BoxSizing prüfen CSS-Werte/Cascade, Nichtvererbung, px/%/Auto, Konflikte, Padding-Untergrenze, Nullgrößen, Umbruch/Resize und Geschwisterfluss. Demo enthält kompakte Karte id=box-sizing (100%, min180/max480px einschließlich Padding/Rahmen). Nutzer hatte Rahmen zuletzt akzeptiert: LineJoinMode MUSS Round sein, wenn ein UICorner erzeugt wird (BorderRadius > 0), sonst Miter. Tests/Border prüfen beide Fälle. Neue Größenregeln noch nicht visuell in Studio bestätigt.

Aktuell: Nutzer hat letter-spacing optisch akzeptiert; anschließend border und border-radius beauftragt. Implementiert: gleichmäßiger Rahmen für Blockcontainer via border-Kurzschreibweise (px, solid/none, Farbe/currentcolor) und border-width/style/color, plus einzelner px-Radius für alle Ecken. Nicht vererbt; shorthand setzt fehlende Bestandteile auf 3px/none/currentcolor zurück, eigene apply-Behandlung verteilt Border-Werte auf Langschreibfelder. BorderSize wird nach Cascade berechnet (none => 0), currentcolor nach finalem Color aufgelöst. BlockLayout addiert beide Rahmenkanten bei content-box-Größen, reduziert Auto-Inhaltsbreite und verschiebt Kindpositionen. RenderTree fügt UICorner und innen liegenden UIStroke hinzu; GuiFactory.modifier erlaubt ausschließlich diese beiden Nicht-GuiObject-Klassen mit Fehlerbereinigung und Parent zuletzt. Keine Active/Selectable-Properties auf Modifikatoren schreiben. Testharness hat UDim/Stroke-Enum-Stubs und modifier-Fallback. Tests/Border prüfen Cascade, Initialwerte, currentcolor, Vererbung, ungültige/Inline-Werte, Geometrie, Umbruch/Resize/Prozentbreiten; GuiFactory-Test prüft Modifier-Fehlerpfade. Kompakte HTML-Box id=border mit 2px Rahmen/12px Radius/12px Padding. Grenzen: keine Einzelkanten, dashed/dotted, elliptischen/Mehrfach-/Prozentradien, Kind-Clipping oder nachträgliches DOM-Dirty-System. Visuelle Studio-Bestätigung für Rahmen/Rundung noch offen.

Aktuell implementiert auf ausdrücklichen Nutzerwunsch: `letter-spacing` normal/0/signierte px mit Vererbung. Regel in PLAN aktualisiert: nur bei nichtnull letter-spacing wird beim Mount ein Wort-Frame mit TextLabel pro Graphem erzeugt; sonst nativer Wort-Label-Pfad. `Layout/LetterSpacing.luau` verwendet Roblox utf8.graphemes, misst jeden Cluster individuell, positioniert ihn mit CSS-Pixel-Abständen, speichert VisualWidth für extrem negative Abstände und invalidiert SkipInkCuts bei Spacing-Änderung. RenderTree legt alle Zeichen-Labels mit FontFace an und wählt ein echtes Zeichen-Label fürs Preloading. WordLayout schreibt keine TextLabel-Properties auf den Frame und berechnet zwischen Wörtern zusätzlich spaceLetterSpacing+(previousLetterSpacing+currentLetterSpacing)/2. SkipInk verwendet im Zeichenmodus direkt Glyph.X/Width ohne Präfixmessungen. NBSP bleibt gruppiert und bekommt im Zeichenmodus auch word-spacing, im nativen Wortpfad bleibt die bisherige Einschränkung. Kein nachträglicher Wechsel der Label-Struktur ohne neues Mount/Dirty-System. Kerning/Ligaturen/verbundene Schriften nur angenähert, mehr Instanzen/Messungen bei nichtnull Abstand. Test-HTML mit 2px/-1px/normal und unterstrichenem Äpfel synchronisiert. Tests/LetterSpacing deckt Grapheme, Stil/Vererbung, Preload, Maße, negative Abstände, Umbruch/justify/indent, NBSP und skip-ink, Wiederverwendung und Abbruch ab. Luau-CLI hat kein Roblox utf8.graphemes; Harness liefert ASCII-Grenzen und Unicode-Fixtures via Intl.Segmenter. Keine echte visuelle Studio-Prüfung behaupten.

Neu: `word-spacing` normal/0/signierte px mit Vererbung. InlineStyle teilt die signierte Längenprüfung mit text-indent, speichert WordSpacing als Zahl (Standard 0). WordLayout addiert den Stil des Leerzeichens zu dessen gecachtem nativen Maß, ohne zusätzliche Messungen oder Fontfaktor. WordFlow berechnet farRight aus allen Wortenden, damit große negative Abstände keine früheren breiteren Wörter aus dem Canvas-Ausmaß verlieren. InlineWords meldet nichtnull word-spacing bei NBSP-Wortgruppen als noch nicht unterstützt; innere NBSP bleiben nativ und untrennbar. Keine %, em/rem oder zusätzlichen Unicode-Worttrenner. Tests/WordSpacing deckt Vererbung/Cascade, Whitespace-Stil, Umbruch/br, Ausrichtung/justify/indent, Unterlinien, negative Überlappung und Resize ohne Messungen ab. HTML und Studio-Demo synchron, ein neuer Absatz word-spacing:6px. Nutzer hat text-transform/text-indent akzeptiert. Sein anschließender Auftrag für letter-spacing ist inzwischen umgesetzt; siehe aktuellen Abschnitt oben.

Neu ergänzt: `text-transform` none/uppercase/lowercase/capitalize und `text-indent` als signierte px/% mit Vererbung. `Layout/TextTransform.luau` bietet eine begrenzte ASCII-/Latin-1-Abbildung inklusive Ä/Ö/Ü/ß/ẞ; InlineWords transformiert erst das vollständig zusammengesetzte Wort vor Messung/Label-Erzeugung. DOM-Text bleibt original; capitalize erhält übrige Schreibweise, erkennt Leerraum/NBSP und Bindestriche. Andere Sprach-/Unicode-Regeln fehlen; gemischte Wortstile bleiben Erststil plus Diagnose. WordFlow hat optionalen fünften Parameter für den ersten Zeileneinzug; WordLayout löst Prozentwerte aus der Inhaltsbreite. RenderTree markiert `IndentFirstLine`, damit anonyme Textläufe hinter Blockkindern keinen zweiten Einzug bekommen. br verbraucht den ersten Einzug, auch als führender Break. Negative Werte möglich, linker Überlauf bleibt unzugänglich wie bei überbreiter Ausrichtung. Tests TextTransform/TextIndent inklusive DOM-Erhalt, ß-Erweiterung, SkipInk, Ausrichtung, Vererbung, verschachtelter Blöcke und Resize. Gemeinsames HTML enthält je einen kompakten Absatz; keine visuellen Studio-/Browser-Ergebnisse behaupten.

Textlinien: Nutzer hat die begonnene Font-Metadaten-Auswertung ausdrücklich durch einfache Näherungen
ersetzt. Die dafür neu erzeugten Extraktionsdateien und Profilblöcke sind entfernt. Keine weitere
Einzelprüfung von Fonts für Unter-/Durchstreichungen. Implementiert sind text-decoration none/underline/
line-through/Kombination und u/s/del. Unterlinie: Baseline+max(1, round(CSS-Größe/14)) px. Trifft die gemeldeten Abstände: 1 px bis Größe 20, 2 px ab 21, 3 px ab 35; weitere Übergänge sind Näherungen. Alle Fonts/Gewichte gleich, Ursprungsabstand bleibt bei Nachfahren erhalten. Durchstrich: Baseline-round(CSS-Größe/4);
Aktuelle Nutzerentscheidung: ein gemeinsamer Größenfaktor für alle Schriften, keine Einzelkalibrierung. Automatische Dicke max(1, floor(CSS-font-size * 0.049)), unabhängig vom Gewicht: ab 41 px → 2 px, ab 62 → 3, ab 82 → 4. Alle drei Übergänge vom Nutzer gemeldet; weitere Größen bleiben Näherungen. text-decoration-thickness unterstützt auto, px und Prozent; explizite px/% werden gerundet. Die frühere 3.7%-Vorgabe wurde aus dem gemeinsamen Browser-/Studio-Demo-HTML entfernt, damit automatische Dicke greift; Browser-auto kann abweichen. Vorfahrenlinien behalten Ursprungsfarbe und -dicke auch bei child none oder anderer Schriftgröße.
Layout/TextDecoration zeichnet wiederverwendete Frame-Segmente unter den Wort-Labels einschließlich
dekorierter Wortabstände und justify. WordFlow liefert LineIndex auch bei line-height:0. Keine Änderung
an Wortbreite/Zeilenhöhe; undekorierte Runs überspringen die Zusatzzeichnung. Tests: TextDecoration.luau.

Sichttest abgeschlossen: Nutzer hat die einfache skip-ink-Version nach Verkleinerung der Lücken ausdrücklich bestätigt ("gut lassen wir so"). Sie bleibt bestehen. Zusatzrand jetzt max(0.5, TextSize * 0.025), zuvor max(1, round(TextSize * 0.04)). `Layout/SkipInk.luau` misst bei unterstrichenen Wörtern nur Präfixe vor/bis p/g/j/q/y, schätzt Lücken per Buchstabenanteil plus größenabhängigem Rand und speichert `item.SkipInkCuts`. `WordLayout` invalidiert diese bei neuer Wortmessung, ruft SkipInk nach FontFace/TextSize auf und prüft Abbruch nach asynchronen Messungen. `TextDecoration` teilt ausschließlich Unterlinien an diesen Lücken, behält Frame-Reuse, Abstände und Durchstriche. CSS `text-decoration-skip-ink` auto/none ist vererbt; Dekorationsursprung speichert SkipInk. HTML-Kurztest enthält Hxpgjqy bei 20/35 px sowie none-Vergleich. Automatische Tests in tests/SkipInk.luau; aktuelle Optik vom Nutzer akzeptiert.
Gezielter Rückbau bei Nutzerablehnung: neues SkipInk-Modul und Test entfernen, dessen require/Cache-Reset/measure-Aufruf aus WordLayout und Einträge aus run-html-tests.cjs entfernen; in TextDecoration die Schnittschleife entfernen (drawLine-Helfer kann bleiben). CSS-Property, Parserzweig, Standardfeld und Dekorationsfeld SkipInk entfernen; Demo-Zusatz und diese Dokumentation zurücknehmen, HTML erneut synchronisieren. Bestehende Formeln für Dicke (0.049/floor) und Unterlinienabstand (/14/round) erhalten. Keine git-reset/clean-Aktion: Projektdateien sind untracked.

Ladeoptimierungen: FontFace schon bei Label-Erzeugung setzen; Rendering/FontPreload lädt pro
sichtbar verwendeter Variante ein repräsentatives Label asynchron vor. FontProfiles.newResolver()
hält private Font-Konfigurationen pro Seite (kein Textmaß-Cache). CSS-Regeln werden mit
InlineStyle.compile() einmal in unveränderliche Normal-/Important-Deklarationen übersetzt.
Stylesheet.match() gibt nun diese Gruppen statt CSS-Text zurück. Prozentberechnung und Tabellenkopien
bleiben pro Element. Tests und Messgrenzen: docs/LOADING-PERFORMANCE.md; keine gesamte Studio-Ladezeit behaupten.

Compilerstand: WordFlow, FontMetrics, HTML/Tokenizer, CSS/Syntax und CSS/Stylesheet tragen
`--!optimize 2`, um diese Module auch im Studio-Test wie auf Live-Stufe 2 zu kompilieren.
Kein gemessener Laufzeitgewinn behauptet. `--!native` bewusst nicht gesetzt: Die Engine läuft
clientseitig; native Codegenerierung ist laut aktueller Roblox-Dokumentation serverseitig.
Quelle und Grenzen stehen im Performance-Absatz der README. Kein pauschales Verteilen von Direktiven.

Stand: 9. September 2026. Projekt: `C:\Users\Tobias\Documents\ChatGPT\Roblox`.
Diese Übergabe fasst den ursprünglichen Plan, spätere Nutzerentscheidungen und den überprüften Dateistand zusammen. Sie ist keine Aufforderung, alle geplanten Funktionen sofort einzubauen.

## 1. Ziel und Zusammenarbeit

Tobias entwickelt eine wiederverwendbare Browser-Darstellungsengine in Luau für Roblox. Sie soll langfristig HTML, CSS und JavaScript unterstützen und Webseiten möglichst wie Chrome anzeigen. Sie wird in einen beliebigen Ziel-Frame eingebaut. Tabs, Adressleiste, Navigation und eine Chrome-Oberfläche gehören später in ein eigenes System außerhalb der Engine.

Tobias ist Anfänger: auf Deutsch, einfach und konkret erklären. Bestehende Dateien weiterentwickeln und neue Funktionen nach Verantwortung aufteilen. Keine immer weiter wachsende Datei mit tausenden Zeilen. Erst einen kleinen HTML-Kern bauen, dann HTML und CSS gemeinsam erweitern; JavaScript folgt später.

Tobias übernimmt den visuellen Vergleich in Chrome und liefert Messwerte. Die KI liefert Roblox-Code und passende lokale HTML-Dateien. Kleine Unterschiede durch Fonts und insbesondere deren Textbreite sind akzeptiert; Abstände und Layout sollen möglichst genau stimmen. Keine vollständige Chrome-Kompatibilität behaupten.

## 2. Verbindliche Entscheidungen des Nutzers

Diese Entscheidungen ersetzen abweichende Vorschläge aus dem frühen Gespräch:

- **Alle GuiObjects haben `Active = false`, ohne Ausnahme.** Auch Controls, Hilfslinien und wiederverwendete Objekte. `Selectable = false` ist ebenfalls im bestehenden Code vorgesehen.
- Jede Webseite liegt in **einem ScrollingFrame**, alle Seitenelemente sind dessen Nachfahren. Container enthalten ihre Kinder in eigenen Frames, für einen übersichtlichen Explorer.
- **Natives Scrollen bleibt aktiviert**, mit `ScrollingEnabled = true`. Tobias hat Scrollen mit `Active = false` selbst geprüft. Nicht wieder auf `Active = true` umstellen.
- Klicks, Hover, Trefferprüfung und später Fokus/Dragging werden selbst implementiert. Keine nativen Button-Klicks als Ersatz.
- **Standardmäßig ein TextLabel pro Wort**; bei letter-spacing ungleich null auf Nutzerwunsch ein Wort-Frame mit Labels je Graphem. Keine ganzen Sätze in einem Label. Wortanordnung und Umbrüche erfolgen durch die Engine. Geschützte Leerzeichen halten eine Wortgruppe zusammen; Satzzeichen bleiben am Wort.
- Jedes Element bzw. Wort wird **individuell gemessen**. Keine zwischen verschiedenen Elementen geteilten Textmess-Caches und keine Übernahme fremder Textmaße.
- Ein unverändertes Element darf seine eigenen Messwerte behalten. Eine neue Containerbreite benötigt bei den bestehenden ungetrennten Wörtern nur eine neue Anordnung, keine neue Messung jedes Wortes.
- **Keine Virtualisierung oder Entfernung von Inhalten außerhalb des Viewports.** Die Seite bleibt aufgebaut, der Scrollbereich schneidet optisch ab.
- Nur Roblox-Bildassets verwenden. Keine beliebigen Web-Bilder als zugesichert unterstützt darstellen.
- Bedarfsgesteuerte Arbeit: keine Schleife pro Element, keine dauernden Baumdurchläufe im Ruhezustand. Mehrere Änderungen bündeln.
- Eine Checkbox soll später nur ihren Zustand und die notwendige Darstellung ändern, nicht die Seite zurücksetzen. Scrollposition und Eingaben erhalten.
- Abhängigkeiten berücksichtigen: Wird ein Element höher, müssen nachfolgende Elemente gegebenenfalls mitwandern. „Dirty“ bedeutet nicht, notwendige Folgeänderungen zu überspringen.
- Beim Seitenwechsel alte Events und Arbeiten vollständig beenden. **Pooling ist gewünscht, aber noch nicht umgesetzt.** Wiederverwendung braucht vollständiges Zurücksetzen und begrenzte Pools.
- **Schriftgrößen immer aufrunden:** `math.ceil(htmlSize * fontFactor)`. Messung und dargestellte TextSize müssen denselben Wert verwenden. Die Hilfslinien werden weiterhin auf den nächsten ganzen Pixel gerundet.
- Tests und Demos bleiben außerhalb von `src/HTMLEngine`.
- Kleine Module mit klaren Aufgaben; ab etwa 400–600 Zeilen Verantwortung prüfen, keine starre Zeilengrenze und keine künstlichen Mini-Dateien oder riesige Utils-Sammlung.

## 3. Was tatsächlich implementiert ist

| Bereich | Aktueller Stand |
| --- | --- |
| HTML | Tokenizer, Grundparser, Attribute, Text, Verschachtelung, Kommentare, Entities, Diagnosen und Eingabegrenzen. Kein vollständiger HTML5-Parser. |
| DOM | Reine Luau-Daten, Eltern/Kinder, `append`, ID-Suche und Textauslesen. Keine automatisch sichtbaren reaktiven Mutationen. |
| CSS | Style-Blöcke und Inline-Styles: einfache/zusammengesetzte Selektoren, Nachfahren, Gruppen, Spezifität, Reihenfolge, !important und Vererbung. Kein vollständiges CSS; keine externen Stylesheets. |
| Layout | Block-Anordnung, individuelle Wörter/Leerzeichen, Umbrüche und `br`; gemischte Schriftgrößen/-familien auf gemeinsamer Grundlinie. Kein vollständiges Inline-Box-Modell oder Flexbox. |
| Rendering | Verschachtelte Frames, regulär ein Label je Wort, bei letter-spacing Labels je Graphem im Wort-Frame; gemeinsame GuiFactory, nur geänderte Properties schreiben. |
| Updates | Breitenänderungen werden gebündelt; bestehende Labels werden neu angeordnet. Keine Neubildung der Seite beim Resize. |
| Lebenszyklus | `PageSession`: Aufräumen, `Alive`, idempotentes Entfernen, Abbruch später asynchroner Ergebnisse. |
| Schriften | Eigene Profile mit Größenfaktor, Fontfamilie und teilweise gemessenen Linienformeln. Details unten. |
| Eingaben | Ein einfacher eigener Klickrouter existiert **nur im Schriftlabor**. Kein vollständiges Engine-Eingabesystem. |

Unterstützte Inline-Styles: `color`, `background-color`/`background` als Farbe, `width` in px/%, `height` in px, `margin`/`padding` mit 1–4 Werten in px bzw. 0, `font-size` von 1–100 px, registrierte `font-family`, `line-height` als normal/Zahl/px/%, `text-align: left/center/right/justify` mit Vererbung, `display: block/none`. Textausrichtung gilt für die Zeilen des Blockcontainers; ein Span-Wert verschiebt keine einzelnen Wörter. justify dehnt nur Wortabstände bei automatischem Umbruch; letzte Zeile/br bleiben links. Kein start/end, RTL, Silbentrennung oder text-align-last.

Farben: wenige benannte Farben, `#RGB`, `#RRGGBB`. Familien werden als einzelne Namen unterstützt; beliebige CSS-Fallbacklisten sind nicht implementiert.

Darstellung: verschachtelte Block-Container, h1/h2/p, Text, formatierte span-Wörter und br. Inline-Text unterstützt eigene Schriftgröße, Schriftfamilie, Gewicht 400/700, Stil normal/italic, Farbe und line-height mit Vererbung sowie display:none. Überschriften sind größer und standardmäßig fett (700); b/strong ebenfalls. CSS kann die Standardwerte überschreiben. em/i sind kursiv und mit Fett kombinierbar. Links erhalten weiterhin Diagnosen wegen fehlender tag-spezifischer Formatierung/Funktion. Teilwortstile und ein vollständiges Inline-Box-Modell fehlen: Bei Stilwechsel mitten im Wort bleiben alle Zeichen in einem Label mit dem ersten Stil, mit Diagnose. Leere Spans und reine Inline-Vorfahren ohne eigenen Text liefern keine zusätzlichen Zeilenmetriken. Bilder, Buttons und Eingabefelder werden noch nicht dargestellt. Unbekannte Features nicht stillschweigend als unterstützt dokumentieren.

## 4. Wichtige Grenzen des vorhandenen Codes

1. **Noch kein allgemeines Dirty-System.** `HTMLPage.luau` bündelt Änderungen der Viewport-Breite und ruft dann das vorhandene Layout für die Seite auf. Das ist kein inkrementeller DOM-Dirty-Tree.
2. Höhe allein und Scrollen lösen aktuell kein neues Seitenlayout aus. Unveränderte Wortmessungen werden behalten; GUI-Properties nur bei Änderungen geschrieben.
3. Der öffentliche DOM-Baum ist noch keine Mutations-API. Attribute oder Text direkt in `page.Document` zu ändern aktualisiert die Darstellung nicht automatisch.
4. **Grundlinienausrichtung ist ergänzt, Fontmetriken bleiben Näherungen.** `FontMetrics.luau` übernimmt die Grundlinie aus den Fontprofilen (deren historische Rundungskonventionen bleiben erhalten). Ohne Linien gilt ausdrücklich die Schätzung round(TextSize * 0.8). Die logische Fontbox ist angenähert durch die aufgerundete Roblox-TextSize; zusätzliche/negative Zeilenhöhe wird darum verteilt. Gemessene Höhen bestimmen weiterhin die individuellen Labelhöhen und normal. Die sichtbaren H-/x-/p-Kanten sind keine vollständigen Ascent-/Descent-Metriken. `WordFlow.luau` berechnet je Zeile das Maximum oberhalb und unterhalb der gemeinsamen Grundlinie, einschließlich Mindestbox des Absatzstils (Strut). Gemischte Schriften können deshalb selbst bei identischer fester line-height eine höhere Zeile ergeben. Faktoren verwenden CSS-Schriftgrößen, Prozentwerte werden vor Vererbung in Pixel aufgelöst. Keine visuellen Studio-Ergebnisse für diese neue Ausrichtung behaupten.
5. Baseline-Ausrichtung von Controls, Margin-Collapsing, prozentuale Höhengrenzen, Flexbox und Grid fehlen. Rahmen, box-sizing, min/max-width und min/max-height in px sind inzwischen vorhanden.
6. JavaScript-Laufzeit, DOM-Events, Formularzustände, Bildrenderer, Pooling und ein Performance-Dashboard fehlen.
7. Ein Rojo-Build führt keinen Roblox-Code aus. CLI-Tests mit Ersatzobjekten beweisen keine Darstellung oder vollständige Studio-Kompatibilität.

## 5. Orientierung in den Dateien

Alle folgenden Pfade sind relativ zum Projektordner:

| Datei/Bereich | Aufgabe |
| --- | --- |
| `src/HTMLEngine/init.luau` | Öffentliche Einstiege `mountHTML`, `parseHTML`, DOM und weitere Bausteine |
| `src/HTMLEngine/HTML/` | Tokenizer, Parser, Entities |
| `src/HTMLEngine/HTML/Elements.luau` | Verbindlicher Elementkatalog: Darstellung, Unterstützungsstand, Einschränkungen und Standardwerte; öffentlich als `Engine.Elements`, direkt von Renderer und InlineStyle verwendet |
| `src/HTMLEngine/DOM/Node.luau` | Elementbaum und Hilfsfunktionen |
| `src/HTMLEngine/CSS/Stylesheet.luau` / `Syntax.luau` | CSS-Regeln sammeln, Selektoren kompilieren und zuordnen; Kommentare, Strings und Deklarationen lesen |
| `src/HTMLEngine/CSS/Properties.luau` | Zentraler CSS-Katalog mit erlaubten Werten, Einschränkungen und Vererbung; öffentlich als `Engine.CSSProperties` |
| `src/HTMLEngine/CSS/InlineStyle.luau` | CSS-Werte lesen, Standardformatierung und Vererbung auflösen; Prozent-Zeilenhöhe nach font-size berechnen |
| `src/HTMLEngine/Layout/BlockLayout.luau` | Block-Anordnung |
| `src/HTMLEngine/Layout/TextWords.luau` | Text in Wörter und Umbrüche zerlegen |
| `src/HTMLEngine/Layout/InlineWords.luau` | Gestylte Textknoten zusammenführen; Wortgrenzen, HTML-Leerraum und Leerzeichenstil erhalten |
| `src/HTMLEngine/Layout/FontMetrics.luau` | Aufgerundete Schriftgröße, Profilgrundlinie/Fallback und angenäherte Zeilenmetriken |
| `src/HTMLEngine/Layout/WordFlow.luau` | Umbruch, gemeinsame Grundlinie, individuelle Höhen und text-align je Zeile |
| `src/HTMLEngine/Layout/WordLayout.luau` | Individuelle Wort-/Leerzeichenmessung je eigenem Stil und Labelpositionen; nur eigene Maße bei Reflow wiederverwenden |
| `src/HTMLEngine/Layout/TextMeasure.luau` | Roblox-TextService-Abfrage |
| `src/HTMLEngine/Layout/FontProfiles/` | Ein Profil pro Schrift; Registry, FontFace-Erzeugung und Linienberechnung in `init.luau` |
| `src/HTMLEngine/Rendering/GuiFactory.luau` | GUI-Erstellung und feste GUI-Regeln |
| `src/HTMLEngine/Rendering/RenderTree.luau` | DOM/Styles in Frames und Wort-Labels übersetzen |
| `src/HTMLEngine/Rendering/HTMLPage.luau` | Seite starten, Breitenänderungen bündeln, CanvasSize aktualisieren |
| `src/HTMLEngine/PageSession.luau` | Lebenszyklus und Aufräumen |
| `examples/HTMLPage.client.luau` | LocalScript mit bearbeitbarem `local HTML = [==[ ... ]==]` |
| `examples/ubuntu-roboto-page.html` | Kurzes Standard-HTML mit Google-Fonts-Link und CSS; identisch zum HTML-Block im LocalScript |
| `examples/FontLab/` | Schriftlabor, Reihen, manuelle Linien, eigener Klickrouter und Print-Bericht |
| `tests/`, `scripts/` | Studio-Tests, CLI-Teststarter und Formelprüfung |
| `measurements/` | Messwerte, Herleitung und Bestätigungsstatus der Fonts |
| `docs/HTML-SUPPORT.md` | Parser-Teilumfang und Grenzen |
| `docs/FONT-RESEARCH.md` | Bereits erfolgte Fontrecherche und Quellen |
| `PLAN.md`, `README.md` | Plan und Bedienung; manche frühen Planformulierungen sind historisch, diese Übergabe unterscheidet Ist und Soll |

Beispiel für die Engine-Nutzung:

```lua
local Engine = require(game.ReplicatedStorage.HTMLEngine)
local page = Engine.mountHTML(zielFrame,
    '<p style="font-family: Inter; font-size: 20px">Hallo Roblox</p>')
-- Beim Schließen:
page:Destroy()
```

Die Seite hat `Root`, `Document` und den PageSession-Lebenszyklus. `Root` meldet Status über `Status` und Fehler über `Error`. Diagnosen stehen in `page.Document.Diagnostics`.

Bei Fragen wie „Welche HTML-Elemente unterstützen wir?“ zuerst `HTML/Elements.luau` lesen.
`partial` bezeichnet den dokumentierten Darstellungs-Teilumfang, `parser-only` nur die Speicherung im DOM.
Nicht eingetragene Tags behalten den generischen Block-Fallback; das bedeutet keine Unterstützung ihrer speziellen HTML-Funktion.
Katalogeinträge sind schreibgeschützt; aufgelöste Styles erhalten eigene Kopien der Standardabstände.

## 6. Rojo: fester Arbeitsablauf, nicht wieder zwischen Servern springen

Es gab mehrfach fehlende oder veraltete LocalScripts, weil zwei Server unterschiedliche Projekte lieferten und die Standarddatei zwischen Demos umgestellt wurde. Das wurde behoben:

- Standard bleibt `default.project.json`, Projektname **HTML Engine - Studio Workspace**.
- Mit `rojo serve` starten, Standardport **34872**. Nicht parallel einen alten Demo-Server auf 34873 betreiben. Laufende Prozesse bei Bedarf prüfen; frühere Prozess-IDs sind keine dauerhaften Angaben.
- Das Standardprojekt enthält dauerhaft **HTMLPageDemo**, **FontLabDemo** und **FontComparisonDemo** unter `StarterPlayer/StarterPlayerScripts`.
- `ReplicatedStorage` enthält Engine, StudioDemoConfig, FontLab, FontComparison und EngineTests.
- **Nur** die in `examples/StudioDemoConfig.luau` gewählte Demo startet. Andere Demo-Scripts beenden sich, bevor sie ihre Oberfläche laden.
- Werte für `ActiveDemo`: `"FontLab"`, `"HTMLPage"`, `"FontComparison"`.
- Aktuell: `ActiveDemo = "HTMLPage"`, kompakte Testseite mit je einem Beispiel für die bisherigen Elemente/Funktionen und je einem Absatz für text-align left/center/right/justify. Die langen Schriftgrößen- und line-height-Reihen wurden auf Nutzerwunsch entfernt. Das gesamte HTML-Dokument einschließlich head ist identisch. Inter, Roboto und Ubuntu werden im Browser über den enthaltenen Google-Fonts-Link geladen. Keine Fontbinärdaten einbetten. Roblox wertet style-Blöcke aus und nutzt registrierte Familien; externe CSS-/Fontdownloads fehlen. Browserdatei bearbeiten, dann python scripts/sync-html-demo.py ausführen (nur Standardbibliothek). Die Lab-Konfiguration enthält weiterhin `Font = "Open Sans"`, Größen `{10,20,30,40,50}`, `TestSizeMultiplier = nil`.
- Beim Wechsel **Stop → Play**. Laufende `Players/.../PlayerScripts` sind Kopien; Module können in Play bereits geladen sein. Dateien im Projekt bearbeiten.
- Bei fehlenden Änderungen Play stoppen, Rojo-Verbindung zu localhost:34872 prüfen, ggf. Disconnect/Connect und Sync-Änderungen prüfen. Nicht einfach weitere Server starten.

Rojo ist über `aftman.toml` auf 7.7.0 festgelegt. `aftman install` dient der Installation. Separate Projektdateien für Schriftlabor, HTML-Seite, Fontvergleich, Parser und reines Engine-Modell bleiben vorhanden; im normalen gemeinsamen Studio-Projekt werden sie nicht zum Demo-Wechsel gebraucht.

## 7. Fontstatus

Kalibrierung bezieht sich auf **Regular/Normal**, nicht automatisch auf Bold, Italic oder alle Schriftgrößen.

| Schrift | Faktor | Status |
| --- | ---: | --- |
| Ubuntu | 1,09 | Größe bei HTML 10–50 px bestätigt, eigene Linienformeln vorhanden. Bestätigung erfolgte **vor** der späteren Umstellung auf Aufrunden. Mit ceil nochmals prüfen. |
| Roboto normal | 1,13 | Größe bei 10–50 px **mit Aufrunden bestätigt**. Vier Linienformeln, maximal 1 px Abweichung zu den Messpunkten. |
| Inter | 1,18 | Größe bei 10–50 px **mit Aufrunden bestätigt**. Vier Linienformeln, maximal 1 px Abweichung zu den Messpunkten. |
| Open Sans | 1,34 | Vier Linienformeln übernommen, maximal 1 px Abweichung zu den Messpunkten. **Größenvergleich mit Chrome noch nicht ausdrücklich bestätigt.** |
| Roboto Condensed / Mono / Slab | unbekannt | Profile und Browsertests vorhanden, `SizeMultiplier = nil`, Linien unbekannt; neutraler Testfaktor 1. Vorerst zurückgestellt. |
| Source Sans Pro | unbekannt | Vorbereitet, nicht kalibriert. |
| Historisches Arial-Profil | 1,13 | Frühe Messung, Roblox-Arimo ist nicht echtes Arial. Tobias war mit der Übereinstimmung unzufrieden; nicht als identische Schrift darstellen. Ältere Linienformeln erhalten. |

Faktoren sind **fontspezifisch**, kein allgemeiner Roblox-Multiplikator. Neue Faktoren wurden zunächst als Näherung aus fünf H-Höhenpaaren berechnet:

`Summe(Roblox-H × HTML-H) / Summe(Roblox-H²)`, dann auf zwei Nachkommastellen gerundet.

Erst ein erneuter visueller Vergleich bestätigt, ob der Faktor mit gerasterten und aufgerundeten Größen wirklich passt.

Roboto, Inter und Open Sans verwenden `GuideSizeRounding = "ceil"`. Die Linien werden mit `round(Slope * ceil(htmlSize * factor) + Intercept)` geschätzt. `FontProfiles.guides` erhält die bereits skalierte Größe, nicht einfach die CSS-Größe. Alte Arial-/Ubuntu-Modelle behalten ihre ursprüngliche Eingabekonvention ohne zusätzliches ceil in der Formel. Ihre historischen Beobachtungen nicht rückwirkend umdeuten.

Die gemeldete Abweichung von höchstens 1 px ist der Fehler gegenüber den **zum Fit verwendeten** Messpunkten. Das garantiert keine Genauigkeit an ungemessenen Zwischenwerten. Grundlinie, H-Oberkante, x-Oberkante und p-Unterkante sind hier manuell gesetzte Pixelpositionen ab der TextLabel-Oberkante. Ihr Abstand ist nicht automatisch eine unabhängig gezählte Glyphenhöhe; TextBounds ist ebenfalls nicht die sichtbare H-Höhe.

### Letzter Open-Sans-Bericht

Faktor 1,34, Aufrunden, Roblox-Familie `rbxassetid://11598121416`, Text `H x p`, LineHeight 1:

| HTML-Größe | Roblox TextSize | Oben | x-Oberkante | Basis | Unten |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 10 | 14 | 3 | 5 | 12 | 15 |
| 20 | 27 | 6 | 9 | 22 | 27 |
| 30 | 41 | 10 | 15 | 33 | 40 |
| 40 | 54 | 13 | 21 | 43 | 53 |
| 50 | 67 | 16 | 25 | 53 | 65 |

Vorherige H-Messungen ohne Faktor: Roblox `{6,11,17,21,26}`, HTML `{7,14,21,29,36}`. Die letzte offene Frage war, ob die **angepassten** H-Höhen zu Chrome passen. Tobias hat danach die Übergabe angefordert, keine ausdrückliche Größenbestätigung gegeben.

Dateien: `measurements/open-sans-height-comparison.md`, `measurements/open-sans-guide-fit.json`, Profil `OpenSans.luau`. Entsprechende Dateien für Inter, Roboto, Ubuntu und Arial ebenfalls vorhanden.

## 8. Schriftlabor und vorhandener Fontkatalog

Ein Font nach dem anderen. HTML und Roblox zeigen zunächst 10/20/30/40/50 px mit neutralem Faktor 1. Tobias meldet die H-Höhen. Danach Faktor berechnen, mit Aufrunden einsetzen, erneut prüfen, dann Linien einstellen und per **Werte ausgeben** den `FONT_REPORT` kopieren.

Die Linien haben `BackgroundTransparency = 0.8`. Koordinaten steigen nach unten. Für die x-Linie wurde vereinbart: Unterkante der Hilfslinie direkt über der ersten sichtbaren x-Pixelreihe, ohne Lücke. Manuelle Änderungen gehen beim Neustart verloren, sofern sie nicht aus dem Bericht in die Profile übernommen werden.

`FONT_REPORT` enthält echte gespeicherte TextSize, Fontfamilie, Gewicht/Stil, TextBounds und Linien. **`sizeMultiplierKnown = true` bedeutet im aktuellen Code nur, dass ein Profilfaktor gesetzt ist. Es ersetzt keine Bestätigung durch Tobias.**

Vorhandene Font-Referenzen: `examples/ubuntu-comparison.html`, `roboto-comparison.html`, `inter-comparison.html`, `open-sans-comparison.html` sowie Dateien für die weiteren Roboto-Familien. Chrome-Zoom 100 %; Browserdateien nutzen lokale Fontdateien und gemeinsame `font-comparison.css/js`. Diese Laborseiten sind nicht der unterstützte HTML/CSS-Teilumfang der Roblox-Engine: ihr Browser-JavaScript gehört nur zur Messoberfläche.

Der recherchierte Katalog umfasst 126 Familien:

- Roblox-Liste: `examples/FontComparison/Catalog.luau` → im Studio `ReplicatedStorage/FontComparison/Catalog`.
- Anzeige: `ActiveDemo = "FontComparison"`; schlicht Namen und Muster bei 50 px untereinander, scrollbar.
- Chrome: `examples/all-fonts-comparison.html`, Daten in `font-comparison-catalog.js`.
- Lokale Fontdateien: `examples/fonts/comparison/`, Herkunft/Lizenzen dort und in `docs/FONT-RESEARCH.md` bzw. `measurements/roblox-font-catalog-2026-09-08.json`.
- Nummern: Inter 047, Lato 057, Montserrat 069, Open Sans 083, Poppins 090, Roboto 098, Condensed 099, Mono 100, Slab 101, Ubuntu 122.

Katalogeintrag bedeutet nicht, dass eine Schrift bereits in der Engine registriert und kalibriert ist. Neue Fonts brauchen Profil, Registry-/CSS-Zuordnung, passenden Test und Aktualisierung betroffener Tests. Vorhandene Kalibrierungen nicht kopieren.

## 9. Weiterer Plan in kleinen Schritten

1. **Aktuellen Fontschritt abschließen:** Open-Sans-Größe bestätigen lassen; Ubuntu bei Gelegenheit mit ceil erneut prüfen. Keine weiteren Fonts ohne Nutzerwunsch hinzufügen.
2. **Statische HTML-Darstellung verbessern:** line-height und Grundlinienausrichtung sind ergänzt; die neuen Beispiele oben auf der Testseite mit Chrome visuell vergleichen, danach das nächste Feature mit dem Nutzer wählen. Grenzen des Inline-Box-Modells und der geschätzten Fontmetriken beachten. Individuelle Wortmessung und eigene Labelstruktur erhalten.
3. **HTML/CSS gemeinsam erweitern:** Box-Modell, Rahmen, genauer Textfluss, dann weitere Selektoren, Cascade-Funktionen und Einheiten. Aufgaben getrennt halten; Flexbox nach belastbaren Grundlagen, Grid später.
4. **Reaktive DOM-Mutationen und Dirty-Tree:** getrennt Style/Layout/Paint/Transform/HitTest markieren. API-Änderungen müssen abhängige Boxen erfassen. Eine Farbänderung braucht keine erneute Textmessung; eine Höhenänderung kann Folgeelemente verschieben.
5. **Scheduler ausbauen:** Änderungen bündeln, betroffene Teilbäume berechnen, laufende asynchrone Arbeit bei Seitenabbau sicher stoppen. Die vorhandene Resize-Logik ist ein Anfang.
6. **Eigenes Inputsystem:** zentrale Eingaben, Z-Reihenfolge, Clipping, verdeckende Flächen, Hover, Fokus, Pointer-Capture, Touch/Tastatur und später Event-Bubbling. Hover auch nach Layoutänderung unter stillstehender Maus aktualisieren. Trefferprüfung räumlich begrenzen statt ständig alles zu durchsuchen.
7. **Erste interaktive Referenzseite:** Überschrift, Text, Roblox-Bild, Abstände, Rahmen, Checkbox. Häkchen lokal ändern; Textänderung verschiebt notwendige Nachbarn; Scrollposition und Zustand erhalten.
8. **Texteingabe als Machbarkeitstest:** Cursor, Auswahl, Tastatur und mobile Eingabe nur soweit zuverlässig mit den Vorgaben möglich.
9. **Pooling und Ressourcen:** begrenzte Pools, Eigenschaften/Events/Zustand vollständig zurücksetzen; nur Roblox-Bilder. Keine Offscreen-Virtualisierung hinzufügen.
10. **JavaScript als separates Teilprojekt:** definierter Parser/Interpreter-Teilumfang, DOM-Zugriff, Events, Ausführungs-/Speicherbudgets. Timer/Promises benötigen später eine festgelegte Event-Reihenfolge. Nicht als bereits vorhanden behandeln.
11. **Kompatibilität und Performance ausbauen:** Supportliste pflegen; tatsächliche Layout-, Mess- und Schreibarbeit nachvollziehbar prüfen. Browseroberfläche erst separat darauf aufsetzen.

Die Zielarchitektur sieht später Erweiterungen für CSS-Cascade/Selektoren und zusätzliche Module für Inline-/Flex-Layout, DOM-Mutationen, DirtyTracker/Scheduler, HitTest/Hover/Focus/Events, Controls und Pooling vor. Diese Dateien nicht als leere Gerüste auf Vorrat anlegen.

## 10. Verifikation und unmittelbarer Einstieg

```powershell
node scripts/run-html-tests.cjs
node scripts/check-guide-model.cjs Arial
node scripts/check-guide-model.cjs Ubuntu
node scripts/check-guide-model.cjs Roboto
node scripts/check-guide-model.cjs Inter
node scripts/check-guide-model.cjs OpenSans
rojo build default.project.json -o build/StudioWorkspace.rbxlx
rojo build engine.project.json -o build/HTMLEngine.rbxmx
```

Luau-CLI liegt unter `build/tools/luau/luau.exe`, Syntaxcompiler unter `build/tools/luau/luau-compile.exe`. Der Teststarter kann alternativ `LUAU_BIN` verwenden. Zur Grundlinienausrichtung prüfen `tests/Baseline.luau` und die erweiterten Wortfluss-/line-height-Tests gemischte Schriften, Strut, Umbruch, Überlappung, Inline-Vererbung, Leerraum, nachfolgende Blöcke und individuelle Messwiederverwendung. Der Demo-Test prüft die identischen vollständigen HTML-Dokumente mit kompaktem Body und Google-Fonts-Link. tests/Stylesheet.luau prüft das vollständige Inter-Beispiel, Vererbung, Selektoren, Cascade, !important und isoliertes Überspringen nicht unterstützter Regeln. tests/TextAlign.luau prüft Vererbung, ungültige Werte, jede Zeile nach dem Umbruch, gemischte Grundlinien, Padding, überbreite Wörter und Messwiederverwendung. Zusätzlich sind GUI-/Messobjekt-Aufräumen und Fehlererholung abgesichert; siehe docs/CODE-REVIEW.md. scripts/check-project.cjs prüft die Syntax sämtlicher Projektquellen und lokale Referenzen. Eine neue visuelle Studio-Prüfung steht noch aus.

CLI-Tests prüfen Parser, Styles, Fontprofile, Wortfluss und Lebenszyklus mit Ersatzobjekten. Studio-Smoke prüft im Labor unter anderem `Active = false`, native Scrollfreigabe und Berichte. Fehlgeschlagene Assertions wegen inzwischen kalibrierter Fonts sinnvoll aktualisieren, nicht Tests pauschal abschalten.

Zum Einstieg diese Übergabe, README und die betroffenen Module lesen. Dann am vereinbarten nächsten Schritt weiterarbeiten. Keine Server-/Projektumschaltung, keine neue Fontrecherche und kein Neuaufbau der Engine allein wegen der Übergabe erforderlich.

## Ergänzung: Fettschrift

font-weight akzeptiert normal/400 und bold/700, vererbt über CSS und Inline-Elemente.
h1/h2/b/strong haben den Standard 700. Andere Gewichte und bolder/lighter fehlen; verschachtelte
b/strong bleiben 700. FontProfiles.face(font, weight?) erzeugt Regular/Bold derselben Familie;
ohne Gewicht bleibt die bisherige Enum-Konvertierung erhalten. WordLayout misst Wörter und ihren
jeweiligen Leerraum mit dem korrekten Gewicht, das auch Bestandteil ihrer individuellen Messschlüssel ist.
InlineWords meldet auch Gewichtswechsel innerhalb ungetrennter Wörter als nicht unterstützt.
Bold verwendet Regular-Größenfaktoren und Grundlinien als explizite Näherung; FontMetrics.Calibrated
ist für Bold false. Keine neuen Kalibrierungen oder visuellen Studio-Ergebnisse behaupten.
tests/FontWeight.luau prüft CSS, Vererbung, Standardwerte, FontFace-Erzeugung, Messung, Umbruch und
selektive Messwiederverwendung. Demo: ein gemeinsamer Gewichtsabsatz und Google-Fonts-Links mit 400/700.

## Ergänzung: Kursiv

font-style akzeptiert normal/italic; i/em haben FontStyle=italic als CSS-überschreibbaren Standard.
FontProfiles.face(font, weight?, style?) wählt Gewicht und Stil unabhängig. Nicht angegebene Argumente
erhalten beim Enum-Einstieg die bisherigen Enum-Werte. WordLayout übergibt beide Eigenschaften an die
Wort-/Leerzeichenmessung und speichert getrennte MeasuredStyle/MeasuredSpaceStyle-Schlüssel.
InlineWords diagnostiziert auch Kursivwechsel im ungetrennten Wort. Kalibrierung bleibt Regular;
Italic und Fett-Kursiv melden Calibrated=false, bei unveränderten Regular-Linien als Näherung.
tests/FontStyle.luau prüft Vererbung, CSS-Overrides, Kombination mit Fett, Font-Erzeugung, Umbruch,
Messwiederverwendung und Teilwortgrenzen. Demo enthält einen kompakten Kursivabsatz. Google-Fonts-Link
fordert ital,wght@0,400;0,700;1,400;1,700 an. Native visuelle Studio-Abnahme bleibt offen.
# Tabellen-Ergänzungen

Caption/top/bottom, tr/thead/tbody/tfoot-Hintergrundfarben und empty-cells sind
umgesetzt. Demo31 enthält alle neuen Fälle. Layout/TableCaptions ergänzt bei
Tabellen mit Beschriftungen einen passiven GUI-Wrapper; TableSurface bleibt die
eigentliche dekorierte/scrollende Rasterfläche. CaptionTop/TableGridHeight trennen
beide Geometrien. TableColumnPaint verwaltet auch Zeilen-/Gruppenfarben und
EmptyCellHidden. Tests/TableExtras, Gesamtprüfung und beide Rojo-Builds bestanden.
Siehe docs/TABLES.md und docs/PROJECT-REVIEW.md für Umfang und Grenzen.
# Visuelle CSS-Erweiterungen vom 1. Oktober 2026

Aktueller Katalog: 509 Eigenschaften; die Stresstest-Union enthält 1017 Namen
einschließlich vier zusätzlicher Masken-Achsenkomponenten. `VisualValues` ergänzt
Alias-/Kurzformkaskade und Schattenkomponenten; `BorderImagePixels` zeichnet
Neun-Segment-Verläufe; `ClipRect` clippt absolute/fixed Boxen; `TableLayout`
erzeugt fehlende anonyme Zeilen/Zellen. Siehe `CSS-VISUAL-LIMITS.md` für die
expliziten Grenzen der `border-shape`/`box-decoration-break`-Teilprofile.
Nicht alle alten Warnungsnamen wurden implementiert oder unterdrückt.
Roblox Studio wird ausschließlich vom Benutzer bedient.

Gemeinsame Navigation (1. Oktober): `currentcolor`-Änderungen an unsichtbaren
Spaltentrennlinien dürfen keinen vollständigen Reflow auslösen. Farb-Hover
bewahrt den nativen Radiuspfad des Headers. `Rendering/PaintLayer` markiert
reine Rahmen-/Effektbilder mit `HTMLPaintOnlyOverlay`, damit transparente
Vollflächen weder Links noch Textcursor verdecken. Das betrifft Rasterradien,
Border-Image, Border-Overlay und kollabierte Tabellenrahmen. `StressCatalog`
prüft Hover/Fokus/Active der Navigation auf allen 16 Seiten; `Cursors` prüft
Linkaktivierung und Textcursor unter solchen Bildern. Native Studio-Abnahme
bleibt beim Benutzer.

Der gemeinsame Farbparser akzeptiert modernes `rgb()`/`rgba()` mit drei
Leerzeichen-getrennten Kanälen und optionalem Slash-Alpha, einschließlich
gemischter Zahlen/Prozente und `none` (als Nullkomponente). Alte Kommasyntax
bleibt erhalten; ungültige Mischsyntax verwirft die Deklaration. `Colors` und
`Dialog` prüfen insbesondere `background:rgb(10 40 32 / .65)` im Backdrop.

Machbare visuelle Teilprofile (1. Oktober): `BorderShapePixels` zeichnet einen
zentrierten Kreis auf der Half-Border-Box mit solid-Rahmen und Hintergrundfarbe.
`InlineFragments` und `WordFlow` reservieren/zeichnen clone- bzw. slice-Kanten
über mehrere Inline-Zeilen; Fragment-GUIs werden wiederverwendet.
`Filter.native`/`GroupOpacity.paint` setzen Container-brightness bis 100% und
opacity auf den vollständigen nativen Unterbaum; Animationen lesen/schreiben
CSS-opacity getrennt vom Filterfaktor. Bilder werden nicht doppelt gefiltert.
Alle Stressseiten paketieren das echte sample.svg über LocalSVG; der Generator
erhält die Zuordnung. `FeasibleVisuals` prüft diese Profile; Grenzen bleiben
in CSS-VISUAL-LIMITS.md und Properties dokumentiert. Keine JavaScript-Suchlogik
wurde ergänzt und keine Layout-Yielding-Änderung wieder eingeführt.


## 1. Oktober 2026: weitere machbare Bild-/Maskeneigenschaften

509 CSS-Namen, 619 konkrete Verhaltensproben. `object-view-box` besitzt ein
rechteckiges inset/xywh/rect-Profil mit natürlicher Crop-Größe, object-fit/position,
Contentbox-Clipping und Reset. Pixel außerhalb des View-Referenzrechtecks sind
Ink-Overflow wie in Chromium, kein zusätzliches inneres Crop-Clipping.
Externe SVG-Bilder behalten natürliche Rasterproportionen und Root-Deckkraft;
die HTML-Bildbox kann danach unabhängig strecken. ImageDimensions lädt bei
späteren Hover-/Media-Crops bei Bedarf asynchron und teilt die Maße je Quelle.

ShapeImages lädt lokale SVGs oder zugeordnete, lesbare Roblox-Bilder für echte
floating URL-Formen. ShapeImage wertet strikt alpha > threshold aus, berücksichtigt
vollständige Zeilenbänder und euklidische shape-margin. Pro Seite maximal 8 MiB
Alpha/32 Quellen, vier fertige und vier offene Schwellenvarianten pro Quelle;
keine eigene GPU-Textur. Fehlende Quellen bleiben diagnostizierte normale Floats.
Keine erneute Wiedereinführung von inkrementellem Seitenlayout oder JS-Suche.

`mask-type` ist für SVG-mask-Ressourcen pixelwirksam (auf HTML wie im Browser ohne
Wirkung). `image-orientation` unterstützt ausschließlich die importierte
from-image-Ausrichtung, `image-resolution` ausschließlich native 1dppx. Rohes
EXIF/none, andere Auflösungen, runde Viewboxen, externe Shape-Downloads und
historische unbekannte Namen bleiben offen. Containerfilter weiterhin nur
brightness <= 100% und opacity; Voll-Unterbaum-Grayscale/Saturate/Contrast usw.
benötigen nicht verfügbare native GUI-Pixel. Siehe docs/CSS-VISUAL-LIMITS.md.

Nachweise: gesamte HTML- und SVG-Suite, RemainingVisuals/SVGShapeImages,
Projekt-/Stresstestprüfung und Rojo-Build. Browserreferenz mit zwei Bildformaten
und sechs gemessenen Alpha-Float-Zeilenpositionen in tests/fixtures/remaining-visuals*.
Studio nicht bedient; visuelle Roblox-Prüfung weiterhin durch den Benutzer.


## 1. Oktober 2026: HTML text-orientation: upright

Layout/VerticalText zeichnet aufrechte Unicode-Grapheme in wiederverwendeten
GUI-Pools. WordLayout verwendet bei vertikalen Läufen die Contenthöhe als
Umbruchachse (HeightBasis), gibt physische Flowmaße zurück und hält native
horizontale Messungen separat für Moduswechsel. OverflowWrap zerlegt zu lange
aufrechte Wörter an Graphemgrenzen, ohne Hyphens einzufügen. Spalten laufen
bei vertical-rl nach links und bei vertical-lr nach rechts; sideways rotiert
in beiden Fällen im Uhrzeigersinn. upright verwendet für start/end die
benutzte LTR-Richtung. Preserved Spaces und Letter-/Word-Spacing bleiben aktiv.

Inline-Stilgrenzen bewahren TextOrientation/WritingMode; TextOrientation ist
auf Inline-Elementen akzeptiert und beide Felder nehmen an dynamischen
CSS-Änderungen teil. Farb-Hover aktualisiert die aufrechten Zeichen, ohne das
verdeckte horizontale Wortlabel wieder einzublenden. Scharfe Textschatten
werden pro aufrechtem Graphem gezeichnet. GroupOpacity nutzt die physischen
PaintRect-Grenzen für aufrechte Wörter, einschließlich linker Ink-Überläufe.

Teilprofil: keine orthogonale Neuanordnung kompletter Block-/Tabellen-/Ruby-
Strukturen, keine vollständige mixed-CJK-Orientierungsanalyse, keine fertige
vertikale Betonungs-/Dekorations-/Auswahlgeometrie. Zellmaße verwenden native
Roblox-Schriftbounds und bestehende kalibrierte Fontprofile; Font-Fallback und
Browser-Subpixelrundung können abweichen. Keine universelle 1:1-Garantie.

Nachweis: tests/VerticalText.luau und die tatsächlich aus Chromium gemessene
Katalogprobe tests/fixtures/vertical-upright-browser.json. Höhe 88px mit
7px Padding und 2px Rand ergibt 70px Inlineplatz: AVAT / AR / 0123 / — /
alph / a / beta usw. Tests decken Größenwechsel, wiederverwendete Zeichen,
Hover/Fokus, Reset, beide Spaltenrichtungen, Kombinationszeichen, Emoji und
Tracking ab. HTML-Gesamtsuite und Projekt-/Rojo-Prüfung ausgeführt; Studio
wurde nicht bedient. Visuelle Roblox-Abnahme bleibt beim Benutzer.
