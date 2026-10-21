# Aktuelle Übergabe

Current engine update: 19 October 2026. Zum Weiterarbeiten zuerst [Index](README.md),
[Arbeitsplan](../PLAN.md) und [Architektur](ARCHITECTURE.md) verwenden.
Die frühere vollständige Übergabe mit Messwerten, Entscheidungen und
Änderungsprotokollen liegt [unverändert im Archiv](history/2026-10-06/AI-HANDOFF-original.md).

## Vollständiger Originalspiel-Port — 19. Oktober 2026

Aktiv sind nun alle 175 Archiv-HTML-Adressen des Spiels: 60 Site-Einträge und drei
Wikis, mit 30 originalen Fake-Adressen. 160 HTML-Dokumente bleiben Originale;
15 ausdrücklich gekennzeichnete Inhaltsplatzhalter ersetzen unzulässige beziehungsweise
altersunklare sexuelle Inhalte. Deren 24 Bilder sind ausgeschlossen; 456 geprüfte
Originalbilder sind ausgeliefert. Eingangsarchiv-SHA und vollständige Referenzen
stehen in `scripts/data/wttg2-full-selection.json`; der aktive Katalog mit Hashes
ist `scripts/data/wttg2-full-catalog.json`. Keine alten eigenen Seiten werden serviert.

Start in beiden HTML-Projekten `DeepWiki`, Serverwurzel `/wiki1/index.html`.
`DeepWiki2` und `DeepWiki3` sind über echte Wiki-Einträge erreichbar. Die vollständige
Auswahl verteilt 20 Sites und zehn Fake-Einträge je Wiki; mit den beiden anderen
Wikis sind das 32 Einträge. Dies ersetzt die zufällige unvollständige Spielrunde,
nicht deren tatsächliche Kandidatenpools. Alle 60 Sites kommen genau einmal vor.

Die Bilder nutzen 476 Kachelreferenzen auf 469 eindeutige Module. RGBA-Rekonstruktion,
98 unabhängige PNG-Vergleiche, pfadbezogene Ressourcen und lazy Decoding sind geprüft.
Geteilte ScriptSources stehen einmal in `Assets/HostScripts`; jede Seite erhält
nur ihren eigenen Abhängigkeitsumfang. Precomputed Host-Lookups halten auch die
Wikis unter dem normalen 30k-Schrittbudget (Wiki I 26.011), ohne Limits zu erhöhen.
Host-Cursorhooks bleiben ohne Root-Stylemutation. 23 GIFs sind nativ weiterhin nur
als erstes Bild vorhanden; keine native Studio-Pixelgleichheit wird behauptet.

Das originale TheThree-Rätsel erhält nur eine fehlende Selektorklammer; seine
komplette falsche/richtige Auswahl und Weiterleitung zu Wiki III sind geprüft.
Historische Beichtdienste bleiben lokal. Fake-Links verwenden das originale
`/NotFound/index.html`. Die 175 tatsächlichen Module und 390 Onclick-Navigationen
laufen ohne VM-Diagnosen. `FullGameWikiNavigation` prüft 96 Hoverbewegungen und den
nativen Eingabepfad I→II→III→I im gemounteten Browser-/HTML-Stack.

Die entfernten eigenen Seiten sind in `tests/fixtures/retired-authored-darknet-20261019.json`
mit ihren Hashes gesichert und vom Rojo-Modell ausgeschlossen. `NightwebRuntime`,
`NightwebNavigation` und `NightwebIllustrations` verwenden ausschließlich diese
festen Regressionseingaben. Neue Importläufe erzeugen Staging, überschreiben nicht
automatisch den aktiven Katalog. Nachweise: `build/wttg2-full-20261019`.

## Eigene Darknet-Seiten — 19. Oktober 2026

Der damalige aktive Inhalt war durch 15 neu geschriebene fiktionale Darknet-Websites ersetzt:
geschlossene Foren, anonyme Briefkästen, Leaks und versteckte Archiv-/Relaydienste.
Mit Nachtverzeichnis und neun Unterseiten sind es 25 Routen. Einstieg ist
`/verzeichnis/index.html`, Startattribut in beiden HTML-Projekten `Nachtverzeichnis`.
Es gibt keine alten Spielseiten, Unity-Hooks, jQuery oder originalen Pixelpacks im
aktiven Baum. Browser/WindowManager/HTML-Fallback bleiben unverändert unabhängig.

`scripts/publish-nightweb.cjs` verpackt `examples/websites` anhand von
`scripts/data/nightweb-sites.json`. Der erzeugte `nightweb-catalog.json` enthält
Hashes aller Browser- und Moduldateien. Lokale SVG-Bilder werden direkt eingebettet;
jedes Modul enthält nur seine eigenen Ressourcen. Native hrefs übernehmen Navigation,
kleine DOM-Skripte die tatsächlichen Seitenaktionen. Kein Hover schreibt Rootstyles.

Die vorige Veröffentlichung ist vor dem Entfernen in
`build/retired-original-sites-20261019/previous-sites.zip` gesichert worden.
`WikiHoverNavigation` verwendet seine bytegesicherte Eingabe aus
`tests/fixtures/retired-wiki-hover-20261019.json`; sie wird nicht an Roblox ausgeliefert.
`NightwebRuntime` mountet alle 25 tatsächlichen HTML-/CSS-/JS-Seiten mit 20
Proben über den echten Formularhost und verlangt null Dokumentdiagnosen;
native GUI-/EditableImage-Zuweisungen und Textmessung sind CLI-Testgrenzen.
`NightwebIllustrations` baut alle zehn echten SVG-Quellen zu 233 Formen ohne
Parser-/Szenendiagnosen. Diese Prüfungen behaupten keine nativen Studio-Pixel.
`NightwebNavigation` prüft den gemounteten Browser-/HTML-Pfad mit nativer Eingabe.
`test-nightweb-browser.cjs` prüft sämtliche Seiten, lokale Bilder, Querverbindungen
und 404-Antworten für alte Adressen. Browsernachweise liegen in `build/nightweb-20261019`.

## Wiki-Linkhover ohne dokumentweite Stylearbeit — 19. Oktober 2026

Nach dem unten beschriebenen Flackerfix blieb beim Wechsel zwischen Link und
Text eine teure Cursoranbindung im Portadapter: Sie schrieb den Root-Cursor und
löste pro Wechsel 89 Styleauflösungen und 1.134 Selektorprüfungen aus. Diese Zahlen
stammen aus instrumentierten Luau-Tests, nicht aus einer nativen Roblox-FPS-Messung.

Der Publisher injiziert jetzt `[onmouseover*="LinkHover"] { cursor: pointer; }`.
Die kompatiblen `LinkHover`-/`LinkOut`-Funktionen bleiben vorhanden und schreiben
keine Dokumentstyles. Das gilt auch für dynamische, von basic.js mit den Hooks
ausgestattete Ziele. Die ursprünglichen Spielskripte bleiben unverändert.
Alle 35 Seitenmodule und Browserquellen sind neu publiziert, ihre Kataloghashes
aktualisiert. Die Engine-Kaskade bleibt für echte Styleänderungen unverändert.

`WikiHoverNavigation` misst nun alle 25 Linkeintritte/-austritte, direkte
Linkwechsel und Bewegungen innerhalb eines Links. Der Arbeitszähler verlangt
jeweils null Styleauflösungen, Selektorprüfungen, Generated-Content-Auswertungen,
BorderBox-Updates/-Repaints und Transform-Paint-Aufrufe. Zusätzlich bleiben
Rootstyle/Cursor, GUI-Identität, Layout und Präsentation stabil; der Link hat
effektiv `cursor:pointer`, und ein nativer Klick navigiert einmal zu Fortune
Cookie. Die Regression scheitert mit den alten publizierten Quellen an 1.134
Selektorprüfungen und besteht mit den neuen. Nachweise unter
`build/wiki-hover-perf-20261019`.

## Wiki-Linkhover ohne Neuaufbau — 19. Oktober 2026

Der gemeldete Hoverfehler ist mit den tatsächlichen veröffentlichten Wiki-Skripten
und nativen Eingabeereignissen im gemounteten Browser/HTML-Pfad reproduziert:
Die damalige Hostadapter-Version von `LinkHover` schrieb
`document.documentElement.style.cursor`. Die vererbte
Cursoränderung wurde bei generierten Listenmarkern als Inhaltsänderung behandelt
und ersetzte Link-GUIs; anschließende Hover-Neubestimmung konnte `LinkOut` und
weitere Änderungen auslösen. Zusätzlich verglich der Canvas-Hintergrund alle
Root-Style-Felder und zeichnete selbst bei reinen Eingabeänderungen erneut.

GeneratedContent und RenderTree behalten Marker/Pseudotext samt Hit-Stilen bei
Cursor-, Pointer- und Auswahländerungen. Die effektiven Eingabewerte und
Viewport-Metadaten werden weiterhin aktualisiert. Der Hintergrund invalidiert nur
seine wirklichen Zeichenparameter; echte Hintergrund-, Größen-, Besitzer- und
Compositor-Änderungen bleiben berücksichtigt. Die Original-Seitenskripte bleiben
unverändert. Neue Regressionen prüfen alle 25 Wiki-Links ohne Layout-/GUI-Wechsel,
einen echten Klick auf Fortune Cookie, unveränderte Hintergrundtexturen ohne neue
SVG-Aufträge sowie positive Kontrollen für tatsächliche Inhalts-/Hintergrundänderungen.
Fehler-/Abnahmenachweise liegen unter `build/wiki-hover-20261019`.

## Browser ohne Tabs — 19. Oktober 2026

Auf ausdrücklichen Nutzerwunsch sind Tableiste, Plus, Tabsuche, Tabmenüs,
Drag/Reorder und öffentliche Tab-Erstellung entfernt. `Browser:Open(address,intent)`
navigiert ein einziges Dokument je Mount. View verwendet `AddPage`/`RemovePage`;
der komplette HTML-Inhaltscontainer `PageContent_` bleibt vom Chrome-Inputblocker
ausgenommen. Navigation, Adressleiste, Favoriten, Home und Einstellungen bleiben.

`TabStrip`, `TabShape` und `TabSearch` sind gelöscht. Die HTML-Adapter verwenden
intern noch die alten Context-Getter/Signale, jedoch mit höchstens einem Dokument.
Weitere `window.open`-Kontexte bekommen eigene WindowManager-Fenster, einschließlich
benannter Wiederverwendung. HTML allein braucht weiterhin keines der optionalen Module.

Session/Schema V2 speichern nur `Page`. Alte V1-/V0-Daten migrieren die zuletzt
aktive Seite, erhalten gemeinsame Favoriten/Verlauf/Einstellungen und lokale
History/Scrollzustände; geschlossene oder inaktive Tabs werden nicht reaktiviert.
Der bestehende DataStore-Name bleibt erhalten. Der ursprüngliche Mehrtab-Teststand
ist bytegenau in `tests/fixtures/browser-multitab-before-removal-20261019.json`
gesichert. Die aktiven Tests prüfen die neue Ein-Dokument-Schnittstelle und
behalten die unabhängigen Navigations-/Fenster-/Dialog-/Inputkontrollen bei.

## Wiki-I-Port mit 15 Zielen — 19. Oktober 2026

Der Nutzer hat den Umfang ausdrücklich von allen Wiki-I-Kandidaten auf 15
Originalseiten reduziert. Der aktive Katalog enthält jetzt `DeepWiki` und
34 Original-HTML-Dokumente dieser Auswahl, darunter 19 Unterseiten. Der
Einstieg ist `/wiki1/index.html`; beide HTML-Projekte setzen `Website=DeepWiki`.
Die vorherigen eigenen Seiten bleiben entfernt. Umfang, Generatoren und
bekannte Grenzen stehen in [WEBSITES](WEBSITES.md#wiki-i-originalseiten--19-oktober-2026).

Mitgliedschaft und Originalquellen sind aus dem schreibgeschützt gelesenen
Unity-Spiel belegt: `build/wiki1-port-20261019/research/selected-wiki1.json`.
`scripts/data/wttg2-catalog.json` ist der persistente aktive Katalog samt Hashes.
Die neuen Publisher-/Bildpacker-Skripte sind reproduzierbar. Der Browser behält
originales jQuery; nur der Roblox-ScriptSource-Eintrag verwendet einen eng
begrenzten Adapter. Die Enginebudgets bleiben unverändert.
Die Coreänderungen in ImageSources und SVG/Embedded transportieren einen
vertrauenswürdigen RGBA-Resolver für originale Bilder und CSS-Hintergründe.
Der SVG-Image-Zweig übernimmt zudem `shape-rendering`, damit getrennt gekachelte
Bildgeometrie keine transparenten Nähte bei Skalierung erzeugt.
51 Originalbilder sind ohne Roblox-Upload verlustfrei gepackt. Native GIFs
verwenden vorläufig Frame 0; Originalschriften und separate Spielmusik haben
weiterhin die im Websiteprofil ausgewiesenen Grenzen.

## Vorheriger leerer Seitenkatalog — 19. Oktober 2026

Auf erneuten Nutzerwunsch sind alle Webseiten einschließlich der neun gerade
erstellten Nightweb-Seiten entfernt. `examples/websites` enthält keine Seiten;
unter `HTMLEngine.Websites` bleibt nur der wiederverwendbare Katalogeintritt.
Die Kernmodule Browser, HTMLEngine und WindowManager bleiben erhalten.
Der Demo-Start darf keine gelöschte Startadresse voraussetzen. Frühere
Seitenbeschreibungen und Testprotokolle weiter unten sind historisch;
alte Regressionseingaben werden nicht als Webseiten veröffentlicht.

## Initiale Präsentation und Runtime-Lebensdauer — 19. Oktober 2026

Der folgende Nutzerlauf bestätigt den Start ohne Browser: Die AnnoyingSite
erreicht nach 4,4 Sekunden den fertigen Aufbau. Danach gemeldetes
`Document has been disposed` hat zwei reproduzierte Lebenszyklusursachen:
Ein Zwischenlayout konnte während des kooperativen Runtime-Konstruktors die
Präsentation freigeben und dessen LoadingWork beenden; außerdem verwendete eine
wartende native Bildpublikation den absichtlich strikten Runtime-Zugriff.

HTMLPage wartet bei der Freigabe jetzt auf `ScriptInitializationPending=false`
und versucht die Präsentation nach der Initialisierung ausdrücklich erneut,
auch wenn die bestehende Geometrie keinen weiteren Layoutdurchgang braucht.
`Runtime:ImageLayoutCompleted()` erhält VM-Eintritt und Microtask-Checkpoint,
verwirft aber beim Schließen wartende Hintergrundmeldungen. Strikter
Live-Dokumentzugriff bleibt unverändert. Die additiven Regressionen verwenden
die tatsächlichen HTMLPage-/HTMLScripts-/Runtime-Pfade und kontrollierte
kooperative Wartezeiten; sie ersetzen keinen nativen Studio-Lauf.

Die Demo spielt nun im Hauptfenster und ersten Kind insgesamt zwei Videos;
weitere Kinder zeigen das vorhandene Katzenbild. Ein ungültiges Grab-Cursorasset
verwendet vorerst das vorhandene Handcursorasset. Die CorePackages-Warnung und
Asset-ID `203785492` sind nicht durch Fehlermeldungsfilter unterdrückt; für
letztere ist im Projekt kein direkter Verweis nachgewiesen.

Belege und die aktuelle gezielte Abnahme stehen unter
[Fallback-/Layout-Lebensdauer](../build/fallback-layout-lifetime-20261019/final-acceptance.json).
Der Architekturvertrag bleibt bei drei getrennten Rootmodulen.

## Modularer Start — 19. Oktober 2026

Nutzerbefund: Ohne Browser wartet der Serverstarter unbegrenzt auf
`ReplicatedStorage.Browser`; das HTML-LocalScript bleibt zusätzlich bis zu zehn
Sekunden beim optionalen Browser und gegebenenfalls beim WindowManager hängen.
Die unabhängigen Kernmodule waren getrennt, ihre Demo-/Serverstarter hatten
jedoch noch diese unzulässigen Kopplungen.

Korrigiert sind die drei Einstiegsdateien `HTMLPage.client.luau`,
`BrowserPersistence.server.luau` und `HTMLStorage.server.luau`.
Nach einmaligem initialem `game.Loaded` werden optionale Pakete direkt geprüft;
alle vier Browser-/WindowManager-Kombinationen bei vorhandener HTMLEngine
wählen sofort den passenden Host. Ein fehlender Besitzer überspringt seinen
Serverstarter. Defekte vorhandene Pakete bleiben sichtbar fehlerhaft.
Zusätzliche Parentprüfungen verhindern neue Ressourcenhosts nach Abbruch während
Pflichtmodulwartezeit, erstem Frame oder kooperativem Modul-/Websiteimport.

Die neue `BrowserPersistenceStartup`-Suite hat 24 echte Source-Wrapperkontrollen;
die erweiterte `HTMLPageStartup` prüft initiale Replikation, alle optionalen
Kombinationen und Abbruchgrenzen. Neun gezielte Bootstrap-/Storage-/Standalone-/
Browser-/Fenstersuiten bestehen mit tatsächlichem Exit 0. Die eigenständigen
Browserprüfungen und drei Rojo-Builds bestehen ebenfalls. Die
[Architektur](ARCHITECTURE.md#start-ohne-optionale-module--19-oktober-2026)
führt den genauen Startvertrag; der
[unabhängige Review](../build/module-startup-20261019/root-startup-independent-review.json)
belegt den gefundenen und behobenen Ressourcenabbruchfehler.
Der [gemeinsame Prüfbeleg](../build/module-startup-20261019/final-acceptance.json)
hält die sechs Quell-/Test-/Runnerdateien, unveränderte 680 Kernquellen und die
exakt abgeglichenen Client-/Serverstarter beider laufenden Rojo-Projekte fest.
Dieser eng begrenzte Startfix verändert keine Quelle unter `src/` und
beansprucht keinen neuen vollständigen 463-Suiten-Lauf oder Studio-Ladezeitnachweis.
Der vollständige 462-Suiten-Stand vom Vortag bleibt im folgenden Abschnitt erhalten.

## Engineausbau — 18. Oktober 2026

Aktueller Auftrag: die grundsätzlich umsetzbaren fehlenden Enginefunktionen
weiter ergänzen. Die drei eigenen Rootmodule bleiben HTMLEngine, Browser und
WindowManager; der Browserhost verbindet die Dienste über das LocalScript.
Die vorherige vollständige Optimierungsprüfung bleibt im folgenden Abschnitt
mit ihren unveränderten Belegen erhalten.

Dieser Durchlauf ergänzt vier neue JavaScriptmodule: Scheduler, TaskSignals,
XMLHttpRequest und WebLocks. [Priorisierte Aufgaben](JAVASCRIPT-IMPLEMENTATION.md#priorisierte-aufgaben--18-oktober-2026)
verwenden die vorhandene Ereignisschleife samt Promise-/Await-/Microtaskkontext;
[XHR](JAVASCRIPT-IMPLEMENTATION.md#asynchrones-xmlhttprequest--18-oktober-2026)
nutzt gepufferte asynchrone Fetchantworten. [Web Locks](JAVASCRIPT-IMPLEMENTATION.md#web-locks-im-hostspeicher--18-oktober-2026)
koordinieren explizit geteilte Hostspeicher nach Partition und Herkunft.
Das Beispiel teilt denselben Store zwischen Tabs, Popups und HTML-Fallback.
Getrennte Roblox-Actors benötigen weiterhin einen IPC-Broker.

[Lazy-IMG mit `sizes=auto`](IMAGES.md#automatische-bildgrößen-mit-lazy-loading--18-oktober-2026)
verwendet die bereits angeordnete konkrete Bildgröße und korrekte
UA-Containment-/Intrinsikdefaults. Eager/lazy- und Realm/NoRealm-Pfade behalten
ihre jeweiligen Ressourcenbesitzer. [Textumbruch](OVERFLOW-WRAP.md)
ergänzt `word-break:break-word` und acht dynamische Textstilinvalidierungen.
Native Vergleiche, tatsächliche Rendereränderungen und Hostnachweise sind
getrennt dokumentiert. Die ursprünglichen HTML-/CSS-Anforderungen bleiben
erhalten; vier eng begrenzte zusätzliche CSS-Zuordnungen ergeben jetzt 20.

Der gezielte und unabhängige Reviewstand ist grün. Ein während des ersten
Gesamtlaufs bestätigter Web-Locks-Fehler beim überschriebenen `signal.reason`
ist mit internem Abortgrund und drei additiven kanonischen Regressionspfaden
korrigiert. Der Scheduler-Setter veröffentlicht seine Backingtabelle erst nach
erfolgreicher Propertydefinition. Der korrigierte gemeinsame Schlusslauf über
462 Suiten besteht mit tatsächlichem Exit 0 in allen vier disjunkten Gruppen.
Alle 1.745 gehaltenen Quell-/Test-/Skriptdateien sind unverändert; sämtliche
ursprünglichen kompakten und isolierten Prüfpfade sind erhalten. Der
[Abschlussbeleg](../build/engine-expansion-20261018/final-acceptance.json)
verifiziert Testzuordnung, Fachbelege und aktuelle Quellprüfsummen.

Insgesamt 26 Modulquellen unter `src/` sind geändert, davon vier neue Module;
das LocalScript ist für den ausdrücklich geteilten Web-Locks-Speicher ergänzt.
API-/Loader-/CSS-/Projektprüfung, eigenständiger Browser, vollständiger SVG-Lauf
und die drei Rojo-Builds bestehen. Das API-Register enthält 5.320 öffentliche
Deskriptoren / 689 Owner / 140 Module bei null Getter- und Scriptaufrufen;
der Kaltloader hat 540 Abhängigkeiten. Beide laufenden Rojo-Server liefern
678 beziehungsweise 615 exakt geprüfte ReplicatedStorage-Quellen und das
aktuelle LocalScript. Die HTML-only-Variante enthält weiterhin nur HTMLEngine.
Der Webseitenserver liefert HTTP 200. Geladene Studio-Module benötigen
Stop → Play; native Pixel, FPS und Ladezeiten wurden hier nicht abgenommen.

Die beiden ausdrücklich getrennten nativen Abweichungen stehen im
[JavaScriptprofil](JAVASCRIPT-IMPLEMENTATION.md): XHR-Loadend-Zähler nach Reopen
und der gespeicherte Scheduler-Setter auf einer nicht konfigurierbaren
Eigenschaft. In beiden Fällen folgt die Engine dem benannten normativen
Algorithmus; Rohreferenzen bleiben unverändert. Weitere beobachtete Web-Locks-
Taskreihenfolgen und der native Queued-Signal-Override-Quirk bleiben im
[Scopebeleg](../build/javascript-web-locks/scope-review.md) separat erhalten.

Der Gesamtauftrag ist weiterhin offen. Maßgeblich bleiben PLAN, HTML-/CSS-Register
und R00–R20. Insbesondere sind übrige Transport-/Streaming-/Encodingfälle,
Persistenz/Cache/IndexedDB, Actor-Koordination, Cross-Realm-/Agentverträge,
vollständige CSS-/Text-/Bildgrammatik und native Studioabnahmen keine pauschal
unmöglichen Ausnahmen und nicht durch diesen Teilumfang erledigt.

## Optimierungsprüfung — 18. Oktober 2026

Aktueller Auftrag: den gesamten handgeschriebenen Engine-/Browser-/Fenstercode
lesen, Wege und Lebenszyklen verfolgen sowie sichere Vereinfachungen und
Ladeoptimierungen umsetzen. Alle 676 Luau-Dateien sind erfasst; die drei
Teilreviews und das Einstiegs-/Hostreview weisen 581 vollständig gelesene
Quellen beziehungsweise Runtimeanteile und 95 Daten-/Payloadreviews aus.
Sie unterscheiden vollständige Funktionslektüre von generierten Daten und
Seitenpayloads. Keine handgeschriebene
Runtimequelle bleibt lediglich strukturell inventarisiert. Die Rootmodule
HTMLEngine, Browser und WindowManager bleiben unabhängig.

28 Quellen sind geändert: begrenzte Importgruppen mit weiter bestehender
2-ms-Deadline, CSS-Kandidatenindex, lineare DOM-Batchnormalisierung, begrenzte
Tokenizerkopien, SVG-Textrecordindex, vermiedene identische GUI-Writes, lokale
Favoritenmaße, weniger Tweens und sofortiges Beenden veralteter Storage-Retries.
Effektaufnahmen verwenden eine eigene Kopiermap pro Aufnahme und behalten
Pixel-/Ressourcen-/Frameisolation. Bestätigte Owner-, Abbruch-, Scroll- und
CSS-Queuefehler sind mit Regressionen korrigiert. Native Gegenproben verhindern
zwei zunächst falsch hergeleitete Änderungen am HTML-/XML-Tagfilter und an
Dokument-/Shadow-Animationsabfragen; nur die tatsächlich fehlerhafte
Shadow-Replacement-Eignung ist geändert.

Der vollständige Schlusslauf aller 453 Suiten besteht mit tatsächlichem Exit 0
aller vier disjunkten Gruppen, einschließlich der vorgeschriebenen kompakten
und isolierten Prüfpfade. Alle 1.726 festgehaltenen Dateien sind unverändert;
der [Abschlussbeleg](../build/optimization-audit-20261018/final-acceptance.json)
prüft Quellhashes, vollständige Testzuordnung und Hostnachweise. Alle gezielten
Nachbarn, drei getrennte Rojo-Builds, eigenständiger Browser, vollständiger
SVG-Lauf, Projektprüfung und API-/Loaderchecks bestehen. API unverändert 5.225
Deskriptoren / 669 Owner / 136 JS-Module, null Getterzugriffe; Kaltloader 536.
Rojo läuft wieder auf 34872 und 34873, der Webseitenserver auf 8000. Live-Rojo
stimmt nach Zeilenendennormalisierung für 674 bzw. 611 ReplicatedStorage-Quellen
und das jeweilige LocalScript mit dem aktuellen Code überein.

Details, kontrollierte Vorher-/Nachher-Zahlen und abschließende Nachweise gehören
in den [bestehenden Auditnachtrag](audit-2026-10-06/README.md#optimierungsdurchgang--18-oktober-2026).
Die Originalquellen und Lesematrix liegen unter
`build/optimization-audit-20261018`. Reale Studio-Ladezeit/FPS wurden nicht
gemessen; geladene Module im laufenden Studio-Spiel brauchen Stop → Play.
Keine neue Zusage vollständiger HTML-/CSS-/JS-Konformität.

## Aktueller Planfortschritt — 16. Oktober 2026

Aktueller Nutzerauftrag: eine vollständige angepasste Annoying-Site-Seite mit den
vorhandenen Fenster-, Dialog-, Vollbild-, Verlaufs- und Kamerafunktionen bauen.
[AnnoyingSite](../tests/fixtures/retired-nightweb-pages-20261019.json) ist jetzt die explizite
Startseite beider HTML-Projekte unter `http://localhost:8000/annoying-site/index.html`.
Die Browserquellen werden mit `scripts/sync-website.py annoying-site AnnoyingSite`
in die nativen Module übertragen. Start öffnet zwei Popups und startet Ton/Video;
maximal vier eigene Popups springen alle 100 ms an zufällige Positionen und
holen sich mit `focus()` wieder in den Vordergrund. `window.screen` liest nun die
Arbeitsfläche des Hosts, nicht den eventuell kurzen Seitenviewport. Der Start
fragt automatisch nach der Kamera und fokussiert dafür die Hauptseite; während
der offenen Anfrage bewegen sich die Popups ohne Fokusübernahme. Kamera und
Vollbild haben eigene Schalter. Stop, Navigation und Seitenabbau beenden Timer, Medien und eigene
Zusatzfenster. Die Kamera benutzt weiterhin die LocalScript-Konfiguration und
fragt vor der Aufnahme nach. Sound `93424997719572` und Video `5608384572` werden
über Options auf Roblox-Assets abgebildet; die Browservorschau verwendet eigene
generierte kurze Medien. Es wurde keine Web-Audio- oder Mikrofonimplementierung
ergänzt. [Umfang und Bedienung](WEBSITES.md#the-annoying-site--16-oktober-2026).
Nachweise: tatsächliche Browserseite mit Start/Stop und sichtbarem Video geprüft;
`AnnoyingSitePage` führt die aktuellen Quellen durch Engine/HTMLPage/VM sowohl
ohne optionale Rootmodule als auch mit Browser und WindowManager aus. Ein
620 × 460 px Hauptfenster in einer 1280 × 900 px Arbeitsfläche prüft zwei
Startpopups, weite Bewegung auf beiden Achsen, den offenen Kameradialog ohne
Fokusverlust, Assetzuordnung, Popupgrenze, Meldung, Vollbild, Verlauf, Kamera
Blockieren/Zulassen und vollständigen Abbau.
Die ursprünglichen sieben Suiten und drei Builds bestehen; der Nachtrag mit
Arbeitsfläche/automatischer Kamera ist zusätzlich mit zehn Nachbarsuiten, dem
aktuellen Zwei-Host-Seitentest samt echtem InputBegan/InputEnded-Startklick,
zwei neuen HTML-Projektbuilds, Projektprüfung und API-Exportcheck geprüft.
Beide Hosts öffnen dabei zwei verschiedene sichtbare Popupdokumente; der
gemeldete Ein-Popup-Fall ist im aktuellen Code nicht reproduziert. Laufende
Studio-PlayerScripts und bereits geladene Modulwerte brauchen Stop → Play.
Keine neue
Studio-Sichtabnahme oder Bestätigung der Assetberechtigungen im Zielspiel.
Die laufenden Rojo-Server wurden nach der Projektattributänderung neu gestartet:
34872 liefert Browser/HTMLEngine/WindowManager mit `Website=AnnoyingSite`,
34873 nur HTMLEngine mit derselben Startseite. Liveprüfung vergleicht dreizehn bzw.
elf aktuelle Quellen einschließlich aller generierten Seitenmodule.

Vorheriger Kameraauftrag: virtuelle Kamera nach den Berechtigungsdialogen ergänzt.
**Neue Nutzerentscheidung: Kameraquelle im LocalScript konfigurieren, keine
rekursive Namenssuche.** `CAMERA_PATH` in HTMLPageDemo ist eine Folge direkter
Workspace-Kindnamen; `CAMERA_SCENE_PATH` begrenzt optional die Szene. Die
Standardfolge `{"Camera"}` kann die gewöhnliche Workspace-Camera verwenden.
BasePart, Camera und Attachment werden als Quellen unterstützt.
`Engine.createMediaCaptureHost` erstellt den eigenständigen VirtualCameraHost;
LocalScript verbindet ihn sowohl mit Browserintegration als auch HTML-Fallback.
Nach Zulassen liefert getUserMedia einen MediaStream mit MediaStreamTrack;
video.srcObject zeigt eine ViewportFrame-/WorldModel-Ansicht. Start, Pause, Stopp,
deaktivierte Tracks, Quellenwechsel und Realm-Abbau besitzen getrennte Pfade.
Ein Fenster schließt keine fremden Trackklone. Mikrofonton ist weiterhin offen;
audio/combined liefern mit diesem Host NotFoundError. Iframe-Sperre bleibt bestehen.
[Vertrag, Konfiguration und Darstellungsgrenzen](MEDIA.md#virtuelle-kamera-aus-dem-roblox-workspace--16-oktober-2026).
WindowCheck Abschnitt 7 zeigt nun das Livebild und besitzt Start/Stopp. Die
tatsächliche Seite hinter beiden Fensterhosts ist mit einer kontrollierten
Capturequelle geprüft; native Host-/Stream-/Videoregressionen sind getrennt.
Neue gezielte Nachweise ersetzen keinen früheren vollständigen Prüflauf.
Finale Prüfung dieses Pakets: 15 gezielte Eltern-Suiten bestehen; die tatsächliche
WindowCheck-Seite prüft Start/Pause/Stop/Track-Disable/Reload/Popup und Abbau hinter
beiden Fensterhosts. Drei aktuelle Rojo-Builds, Projektprüfung und Exportcheck
bestehen. API-Register: 5.224 Deskriptoren / 669 Owner / 136 JS-Module bei null
Getterzugriffen; Kaltloader: 536. Beide laufenden Rojo-Server liefern die aktuellen
Quellen (kombiniert 34872, HTML allein 34873).
Die native Studio-Sichtabnahme bleibt Tobias vorbehalten.

Die sichtbaren Testseiten sind bereinigt: aktiver Katalog `Main`, `Memory`,
`Hangman`, `Bytebude`, `WindowCheck` und `AnnoyingSite`. Beide HTML-Projekte öffnen
`AnnoyingSite` direkt; neue Browsertabs zeigen Home mit diesem Katalog. Die
[einzelne Fensterprüfseite](../tests/fixtures/retired-nightweb-pages-20261019.json) liegt unter
`http://localhost:8000/window-check/index.html`. Tabs und Popups verwenden dieselbe
HTML-Datei mit `?view=tab` bzw. `?view=popup`. Sie prüft normalen/maximierten Rahmen,
Minimieren/Wiederherstellen, Tabanimation/-Reihenfolge, benanntes Popup mit
Geometrie/Close, Dialogrückgaben, Leave-Warnung, Sichtbarkeit und Elementvollbild.
Der PC-Abstand von 200 px für Titel und Tabs gilt nur maximiert; Pfeile und
Adressleiste behalten ihre Position. Ohne WindowManager startet der vorhandene
HTML-Fallback. Die 15 entfernten Testseiten samt generierten Modulen liegen
bytegleich in [retired-window-pages-20261016.json](../tests/fixtures/retired-window-pages-20261016.json);
die native `wayline://windows`-Demo bleibt im
[separaten Regressionarchiv](../tests/fixtures/retired-native-window-demo-20261016.json).
Bestehende Unit-/Integrationstests verwenden die archivierten Eingaben weiter.
Die nachfolgenden datierten Prüfläufe behalten ihren historischen Bestand;
sie behaupten keine neue Gesamtabnahme dieser Seitenbereinigung.

Nachtrag zum Startskript: `HTMLPageDemo` benutzt bei fehlendem Browser oder
WindowManager automatisch den internen HTML-Fensterhost mit derselben Website.
`BrowserEnabled=false` bleibt die direkte Auswahl ohne optionale Modulwartezeit.
Vorhandene fehlerhafte Integrationen bleiben sichtbare Startfehler; verspätete
Module erhalten weiterhin bis zu zehn Sekunden Replikationszeit. Die frühere
Startkorrektur vom 14. Oktober weiter unten ist in diesem Punkt ersetzt.
Die lokale Regression steht in [HTMLPageStartup](../tests/HTMLPageStartup.luau).
Der unten verlinkte Gesamtprüfcheckpoint liegt zeitlich vor dieser Startkorrektur.

Die Änderungen entstanden mit getrennten Implementierungs- und Review-Agents.
Der neue interne [HTML-Fensterhost](ARCHITECTURE.md#eigenständige-html-fenster--16-oktober-2026)
bleibt unter HTMLEngine und importiert weder Browser noch WindowManager.
Das HTML-only-Projekt startet jetzt über `HTMLPageDemo.Website=AnnoyingSite` dieselbe
Annoying-Seite mit einfachem Rahmen, Dialogen und Popup-Lebensdauer.
`FallbackWindow=false` erhält die rahmenlose Einbettung; ein ausdrücklich
konfigurierter WindowHost hat Vorrang. Die [Bedienung und Grenzen](WEBSITES.md#html-ohne-browser-und-windowmanager--16-oktober-2026)
stehen in den bestehenden Dokumenten. Raw-Iframe-Popups, allgemeiner
Internettransport und die übrigen offenen R14-Achsen sind damit nicht geschlossen.
Neu hinzugekommen sind responsive Bildauswahl mit Dichtekorrektur, begrenztes
verzögertes VIDEO-/Poster-Laden sowie Korrekturen an Dokument-Canvas und
Inlinehintergründen. Die Profile [IMAGES](IMAGES.md), [MEDIA](MEDIA.md) und
[CSS-BACKGROUNDS](CSS-BACKGROUNDS.md) halten Rohreferenzen, normative Abweichungen,
Codepfade und verbleibende Grenzen fest. Beim Canvas bleiben GUI-/Editoridentität,
einmalige Alpha-Komposition und Ressourcenbesitzer auch bei Rootersetzung erhalten.
Die damalige kleine [Canvas-Vergleichsunterseite](../tests/fixtures/retired-window-pages-20261016.json)
ist seit der Seitenbereinigung nur als Regressionseingabe erhalten, einschließlich
der aus denselben HTML-/CSS-/JS-Quellen erzeugten Roblox-Module. Sie prüft Besitzerwechsel,
Transparenz, einen erhaltenen Editor und Canvaswachstum. Ihre native Browserprobe
ist keine Studio-Sichtabnahme.

Die gemeinsamen Prüfläufe fanden zunächst eine Regression bei der Fokusumrandung
eines direkt geparsten Eingabefeldes, eine Startup-Kompatibilitätslücke und
Canvasbesitzer nach leerem Start bzw. `document.open()`. Die Ursachen sind
korrigiert und mit ursprünglichen Rotbelegen sowie gezielten Nachbarprüfungen
erhalten. Zwei weitere veraltete Testannahmen sind mit unveränderten Farbwerten
am tatsächlichen Inline-Paintbesitzer bzw. positiver `video.loading`-Prüfung
ersetzt; die übrigen fehlenden Medienmitglieder bleiben negative Kontrollen.

Die [aktuelle CLI-Gesamtprüfung](../build/plan-final-acceptance-20261016.json)
besteht: **444 registrierte Suiten in vier disjunkten Gruppen**, einschließlich
aller vom ursprünglichen Runner verlangten kompakten und isolierten Prüfungen;
zusätzlich SVG, eigenständiger Browser, Projekt-/API-/CSS-Abgleich und drei
Rojo-Builds. Alle acht Prüfphasen verwenden denselben gehaltenen Bestand von
1.846 Quell-/Test-/Fixture-/Script-/Projektdateien und bestätigen danach dessen
unveränderte Prüfsummen. API: 5.178 Deskriptoren/660 Owner/134 Module, null
Getterzugriffe; CSS: alle 5.045 Definitionseinträge und 16 geprüften Zuordnungen
erhalten. Der native Studio-Sichtvergleich bleibt separat offen.
Rojo auf 34872 liefert die drei getrennten Kernmodule; der zusätzliche
[HTML-only-Testserver](../build/live-html-fallback-20261016.json) auf **34873**
lieferte zum damaligen Prüfcheckpoint nur HTMLEngine und WindowDemo mit dem
internen Fallback. Der aktuelle Projektstart ist WindowCheck.
Im Studio-Plugin verbinden, synchronisieren und Stop → Play ausführen.
Dieser Prüfcheckpoint schließt den weiterhin offenen Gesamtplan nicht ab.

Neu implementiert sind der optionale synchrone JavaScript-Dialoghost und der
begrenzte Dokumentlebenszyklus ohne BFCache. Browser/HTMLBinding und WindowHost
verbinden Antworten, abgebrochene Navigation, Tab-/Caption-Close, logische
Dokumentsichtbarkeit und sicheren Abbau wartender Skripte. HTML bleibt ohne die
beiden anderen Module nutzbar. Die damalige `window-demo` ist archiviert;
`WindowCheck` enthält die aktuellen manuellen Fensterproben; [WEBSITES](WEBSITES.md#dialoge-und-seitenlebenszyklus--15-oktober-2026)
und das [JavaScript-Profil](JAVASCRIPT-IMPLEMENTATION.md#dialoge-und-dokumentlebenszyklus--15-oktober-2026)
besitzen den Vertrag und seine Grenzen. Iframe-Runtimes erben keinen
Eltern-`RuntimeCreated`-Callback; `allow-modals`, Sichtbarkeit und aggregierter
Leave-Guard sind gesondert geprüft. Konstruktionfehler eines Browserdialogs
hinterlassen keine Eingabesperre; native Editorfokusse und Auswahl werden erhalten.

`requestIdleCallback`/`cancelIdleCallback` und `IdleDeadline` sind am bestehenden
Treiber ergänzt. Standardmäßig wird ein kooperativer Budgethinweis von höchstens
1 ms verwendet; echte native Compositor-Idlezeit ist nicht bekannt. Die bestehende
archivierte Vergleichsunterseite `comparison-script` enthält weiterhin die
Start-/Timeout-/Abbruchproben für Regressionen und bleibt unter 250 DOM-Knoten.
Tatsächliche Websitequellen werden durch Runtime und
Ereignisse getestet. Das aktuelle API-Register zählt 5.178 Deskriptoren,
660 Owner und 134 Module bei null Getterzugriffen; der Kaltloader hat 532 Einträge.
Alle 21 R-Familien bleiben offen.

Die Integration korrigiert außerdem unbekannte externe Fensteradressen, die
fälschlich als interne Startseiten galten, und die Fortsetzung eines bereits
geschlossenen Mounts. `BrowserWindowAPIs`, `BrowserWindowsMounted` und
`BrowserLifecycleDialogs` bestehen mit tatsächlicher HTMLPage-/VM-Ausführung
und kontrollierten nativen Diensten. Der App-Browser hat `confirm(false)` auf
der Testseite bestätigt; `prompt()` wird von diesem Host explizit nicht
unterstützt und jetzt verständlich auf der Seite gemeldet. Eine spätere positive
Bestätigungsprobe war wegen Timeouts der Browserautomatisierung nicht auswertbar;
kein vollständiger nativer Browser-/Studio-Pass wird daraus behauptet.

Die CSS-Hintergrundanforderung `canvas-currentcolor` erfüllt ihre bisherigen
Kriterien einschließlich berechnetem `background-image`. Auch
`canvas-image-resources` erfüllt jetzt seine ursprünglichen beiden Kriterien:
begrenzte gemeinsame Renderer-Caches sowie sichere aktuelle Besitzer bei
Quelle/Größe/Ownerwechsel, Fehlern und verspäteten Ergebnissen. Reproduzierte
Allocation-/Upload-/Resolver-Leaks und überholte Canvas-Publikation wurden
behoben; 20 montierte Ressourcenfälle ergänzen die bestehenden Kontrollen. Details im
[Hintergrundprofil](CSS-BACKGROUNDS.md). Nach den zusätzlichen Canvas-Korrekturen
vom 16. Oktober ist der erfasste CSS-Stand: 80 Anforderungen, 44 erfüllt und
36 ungeprüft. HTML: 50 erfasst, 29 erfüllt, acht offen und 13 ungeprüft.
Diese Zahlen gelten nur für den bereits aufgeteilten Bestand;
der vollständige Zielbestand ist weiter nicht zugeordnet. Der Gesamtplan und
die R-Familien bleiben offen; fehlende Adapter gelten nicht als Unmöglichkeit.

## Current Wayline browser state — 15 October 2026

Window-system import: the complete `WindowSystem` area of `haha.rbxmx` and its
required UI/framework helpers are now children of WindowManager. Original source
SHA-256: `e68787a31d07dd0d9a7cdb651fe0e10502ecc8d2559a6cef3e6d1c1db039aab4`.
The scoped pre-import backup, untouched extracted sources and import map are in
`build/window-import-20261015`. Root module count remains three. No Desktop,
Taskbar, Apps, Lifecycle or external Windows10 dependency was imported.
The public host facade preserves existing browser/HTML window APIs; input is still
passive, with mouse/touch ownership and resize deferral. Imported controls use the
existing router through a local adapter. Shadows use native UIShadow. The original
caption rasterizer has a Frame fallback and bounded cache; previews, tweens, flash
jobs and dialog sounds now have manager/window ownership. Modality includes nested
global/owner boundaries and keyboard results; owned windows remain above owners.
Snap restore and immediate destruction during closing animation were corrected
during integration. At that checkpoint HTMLPageDemo registered the optional native
`wayline://windows` comparison page through `Browser.Integration.WindowDemo`;
that demo is now retained only in the regression archive linked above. MessageBox/ShowError are
native host methods. The separate optional JavaScript dialog bridge is described above.
The existing WindowManager and HTMLPageStartup suites pass with controlled native
services. This is not a claim of a fresh Studio rendering/asset-access observation.

Wayline retains its independent implementation and now uses a simpler
Chrome-inspired appearance: compact tabs, a plain navigation toolbar, one rounded
address field, a narrow bookmarks bar and centered Home search with circular
shortcuts. Neutral surfaces and restrained hover/press states replace the initial
card-like Wayline shell. Preserve the existing functionality during visual edits.
The current browser reference is [WAYLINE](WAYLINE.md); it owns installation, Explorer mapping, native page
registration, host input/coordinate contracts and DataStore configuration. Do not
reintroduce the old shell's hotkeys or second window frame.
All new browser code and visible text are English. All browser GuiObjects remain
Active=false, with a custom shared pointer/scroll router. Icons use the Figma image
atlas configured as `rbxassetid://72168208218331`, with image-only browser icons.
Browser/Input now owns arrow, hand and text cursors using the same asset IDs as
HTML, copied into Browser/CursorIcons without importing HTML. It releases cursor
ownership over HTML content, unrelated UI, touch, hiding and focus loss.

The browser mounts in an existing content Frame. HTMLEngine and WindowManager
remain independent; HTMLPageDemo and its adapters connect the combined application.
Browser-only and HTML-only project graphs remain separate. ReplicatedStorage now
has only three root modules: HTMLEngine, Browser and WindowManager. The adapters
live in `Browser.Integration.HTMLBinding` and `Browser.Integration.WindowHost`.
Demo helpers and existing checks live under `HTMLEngine.Examples` and `HTMLEngine.Tests`;
core imports do not run them. WaylinePage and its Pocket Journal example are deleted.
The pre-cleanup backup is `build/module-cleanup-20261015/before-module-cleanup.zip`.
All six affected Rojo projects build successfully; the startup suite covers the
combined and explicit HTML-only modes. The changed Luau files compile, the loader
manifest and documentation links pass, and the restarted live Rojo server exposes
exactly the three root modules with current browser, adapter and demo sources.
This verifies sync contents, not a new Roblox Studio runtime session.
The standalone BrowserDemo now supplies its own content Frame, not a window engine.

The application shares SharedData and PersistenceClient across windows. Settings,
Home, quick links, stable bookmark folders and the latest 500 visits are shared;
only the primary window saves the server tab session. Model separates full live
navigation from plain snapshots, caps open tabs at20 and closed snapshots at10,
and defers successful-visit recording until native rendering succeeds. Host
snapshot validation happens before destructive UI changes. Closed tabs retain
serializable navigation/page state without native resources.

BrowserServer and BrowserPersistenceServer are mapped into ServerScriptService in
the default and browser-only projects. Server writes are validated, debounced,
rate-limited, versioned and guarded by a renewable lease/revision; failed initial
loads never overwrite stored data with defaults. Client transport GUIDs allow
storage-service recreation without reusing stale sequence streams. Pre-load local
visits and bookmark edits merge with saved data; impossible merges retain memory
changes and preserve the stored copy. No save is required before window close.
Explicit host snapshot precedes the server session, then Home. Server sessions
restore only current ordered addresses and selection with fresh navigation stacks.

The backup before replacement remains outside the workspace:
`C:/Users/Tobias/Documents/ChatGPT/Roblox-Backups/Roblox-before-Wayline-2026-10-14-55231749.zip`
and its adjacent manifest. The existing large build directory was excluded as
already documented at backup creation. Previous dated browser records below are
historical evidence, not a description of the current Wayline design or shortcuts.
No new Studio pixel or permanent DataStore observation is claimed here.

## Previous dated implementation notes

Navigationsschalter: Browser:SetNavigationVisible(bool) blendet Back/Forward/Reload
über eine stabile passive NavigationControls-Gruppe ein/aus und passt Omnibox an.
ShowNavigation=false setzt den Anfangszustand. Tabs, History und Inhalte bleiben;
beim Verbergen werden gehaltene/hovernde Navigationsbuttons abgebrochen. Der
BrowserWindowHost ruft die Funktion auch für Popups auf (standardmäßig false;
ShowPopupNavigation=true für sichtbare Popupknöpfe). HTMLPageDemo setzt den
Schalter ausdrücklich auf false. Nur die drei Buttons und ihre gemeinsame
Gruppe ändern Visible; Adressleiste, ihre Höhe und laufende Eingabe bleiben.
Die zwischenzeitliche Änderung zum Verbergen der gesamten Toolbar wurde auf
Nutzeranweisung zurückgenommen. BrowserShell prüft
Eingabe/Verbindungen, Anfangszustand und Vollbildkombination; BrowserWindowsMounted
prüft die tatsächlichen Popup-Toolbaraktionen und erhaltenes HTML beim Toggle.
Keine zusätzliche Abhängigkeit der drei Kernmodule.
Nachweis: drei unabhängige Suiten in `browser-navigation-switch-final-20261014-full16`
und vier Mount-/Start-/Fenstersuiten in `browser-popup-controls-final-20261014-full16`
bestehen (Exit 0), inklusive echter Back/Forward/Reload-Klicks im Popup.
Beide betroffenen Builds, Quellkompilierung, Dokumentprüfung und Live-Rojo-
Abgleich bestehen. Die Tableiste bleibt unabhängig vom Navigationsschalter.
Korrekturläufe: `browser-address-preserved-20261014-full16` (drei unabhängige
Browsersuiten) und `browser-popup-address-preserved-20261014-full16` (vier
Fenster-/Mount-/Start-Suiten) prüfen versteckte Buttons bei sichtbarer Toolbar,
erhaltenes Adressediting, den tatsächlichen Popupstart und erneutes Einschalten.

Eigenständiger WindowManager vom 14. Oktober: `src/WindowManager` importiert nur
seine eigenen Module. Reine Kaskaden-/Resize-/Snap-Rechnung stammt aus der
gelieferten `C:/Users/Tobias/Documents/haha.rbxmx`; Original-Module sind in
`build/window-manager-20261014/*-original.luau` gesichert. Kein Windows10-OS,
Desktop, Framework, Taskleiste oder Apps in Rojo eingebunden. Native Frames
Active/Selectable false; eigener Router hält Drag, acht Resizegriffe, Fokus/Z,
Minimize/Restore, Maximieren/Doppelklick und Snap. Minimierte Fenster haben eine
kleine horizontale Wiederherstellungsleiste. Default ReplicatedStorage enthält
`WindowManager` sowie den Beispielhost `BrowserWindowHost`.

Nur HTMLPageDemo lädt Browser, HTMLEngine, Manager und die Anbindungen und
übergibt sie als Argumente. `Browser.ExternalWindow=true` entfernt Browser-
Fenstergriffe/Fit, lässt Tabdrag bestehen. Host setzt Resize-/Sichtbarkeits-/
Eingabezuteilung und beendet beim Close auch Binding, Browser, Realm und Mounts.
InputScope hält InputBegan registriert, prüft aber weiter Active vor Delivery,
damit der erste Klick nach einem früheren nativen Fokuscallback nicht verloren
geht. Sichtbare unfokussierte Fenster bleiben gemalt; Minimieren pausiert Frames.

`JavaScript/BrowsingWindows` ist ausschließlich ein optionaler Hostvertrag,
kein Import des Managers. open() ohne Popup erzeugt einen Tab; Popup Features
erzeugen ein Fenster. Benannte Ziele werden wiederverwendet. Stabile Referenzen
haben closed/name/close/focus, noopener/noreferrer liefern null. close() nur
für Script-Kontexte, queued nach dem laufenden Callback. Ohne Host open=null.
Grenzen (16 Fenster, 32 Tabs, kein vollständiger WindowProxy, iframe-Zielbaum,
Berechtigungs- oder HTTP-Host) sind in WEBSITES dokumentiert.
`WindowDemo`/`WindowPopup` sind Browserquellen und getrennte generierte Module;
Comparison bleibt Hauptseite und verlinkt die Demo im Header.

Neue Prüfungen: WindowManager, BrowsingWindows, BrowserWindowsMounted. Letztere
verwendet tatsächlichen HTMLPage/RenderTree/Layout/Controller/JS mit kontrollierten
nativen Services. Der frühe 11-Suiten-Nachbarlauf steht in
`build/window-manager-integration-final-20261014-full16.log` mit Exit 0;
die drei gezielten neuen Suiten in `build/window-manager-host-contract-final-20261014-full16.log`.
Abschluss: `build/window-manager-final-checks-20261014-full16.log` besteht mit
18 Suiten, einschließlich echter Demoquellen, gehaltenem verspäteten Mount,
Window-/Tabgrenzen, Eingabe, Forms/Cursor/Layout und API-Inventory (Exit 0).
`build/window-manager-project-20261014-full16.log` besteht; default/browser/
htmlpage Builds liegen in build/window-manager-20261014. API- und Loader-
Register sind aktualisiert und geprüft (525 Cold-Loader-Module).
Der ursprüngliche Managerstand registrierte 430 Suiten; kein neuer Gesamtlauf
und kein Studio-Pixelnachweis.

Fenster-Web-API-Erweiterung: BrowsingWindows nutzt optionale native Handles für
move/resize, Maße, location assign/replace/reload, opener und postMessage.
BrowserWindowHost erzeugt synchron ein initiales gleichherkünftiges about:blank;
Referenzen bleiben über Navigation stabil. Neues JavaScript/RealmAccess hält
lebende, herkunftsgeprüfte DOM-/Callback-Zugriffe über runtime.Access. Weak Caches,
Export-Invalidierung beim Destroy und Herkunftsprüfung pro Zugriff; keine
ungeprüfte fremde VM oder eval-Brücke. Messaging.ReceiveWindow nutzt vorhandenen
Clone-/Task-/Abbaupfad, prüft Zielherkunft bei Delivery und hält event.source stabil.

JavaScript/Fullscreen besitzt Promise/Zustand/Ereignisse; Rendering/FullscreenHost
besitzt die native Elementpräsentation und Wiederherstellung. CSS :fullscreen
und UA-Geometrie sowie Escape/BeforeRemove sind angebunden. WindowManager/Browser
blenden Rahmen/Chrome über Host aus. **HTML-only benötigt keine dieser Module**:
FullscreenHost vergrößert sein Target innerhalb ScreenGui selbst. htmlpage.project
enthält weiter weder Browser noch Manager; LocalScript BrowserEnabled=false.
Die neuen Module importieren ausschließlich Engine-Module.

BrowserWindowAPIs verwendet tatsächlichen Renderer/Layout/JS mit nativen Test-
Services: initial blank DOM, move/resize, guarded DOM/Callback, cloned messages,
origin checks, reload/stale handles, rejected requests, Escape/focus/remove/reload/
close und HTML-only fullscreen einschließlich Destroy-Restoration. Die echte
WindowDemo/WindowPopup-Seite prüft BrowserWindowsMounted über alle neuen Buttons.
`build/window-extension-demo-buttons-20261014-full16.log` besteht mit zwei Suiten;
`build/window-extension-lifecycle-final-20261014-full16.log` mit drei (Exit 0).
18 Nachbarn bestehen in `build/window-extension-neighbors-full-20261014-full16.log`.
API-Register: 5138 Deskriptoren, 649 Owner, 131 Module, keine Getterauswertung;
Cold Loader: 528 Module. 431 Suiten registriert, kein Gesamtpass behauptet.
Die verbleibenden WindowProxy-/Reflection-/iframe-/Permissions-/Fullscreen-Stack-
Grenzen stehen im Abschnitt Eigenständige Fenster in WEBSITES.
Abschluss der Erweiterung: `window-extension-final-neighbors-20261014-full16`
besteht mit 23 Suiten einschließlich Messaging-/Worker-/Clone-Nachbarn und
frischen isolierten Handler-/Dokumentprüfungen. Drei unabhängige Browser-Suiten
in `window-extension-standalone-browser-20261014-full16`, Projektprüfung in
`window-extension-project-20261014-full16`: Exit 0. Der Vollbild-Inputnachtrag
prüft tatsächliches natives Begin/End nach Reparenting; der opake Herkunfts-
Nachtrag prüft unterschiedliche Null-Serialisierungen, Standardzielherkunft,
Wildcard und eigene Nachricht. Beide bestehen. Separate Chromeprüfung
`window-extension-chrome-20261014-full16` besteht mit echten Demoquellen und
1000/390-px-Screenshots. Die drei aktualisierten Builds liegen unter
`build/window-manager-20261014/window-extension-{default,browser,html-only}.rbxlx`.
Keine vollständige Enginekonformität oder Studio-Pixel/FPS-Abnahme behauptet.
Wichtig für die Auslieferung: WindowDemo/WindowPopup besitzen jetzt options.json
mit LocalScripts=[app.js] und generierte JavaScript-Kindmodule. BrowserWindowsMounted
liest tatsächliche generierte HTML/CSS/JS/init-Module, prüft Browserquellen-Parität
und nutzt den produktiven Website-Katalog für ScriptSources. Der gezielte Lauf
`window-extension-generated-catalog-final-20261014-full16` besteht mit drei Suiten.
Die anfänglich fehlende Scriptverpackung wurde durch den Live-Rojo-Abgleich gefunden
und behoben. Finale Builds verwenden den Namen `window-extension-delivery-*`.
`window-extension-delivery-tests-20261014-full16` besteht mit den drei betroffenen
Suiten; `window-extension-delivery-project-20261014-full16` prüft 1149 Luau-Dateien
und alle sieben Rojo-Projekte (Exit 0). Live Rojo stimmt nach seiner normalen
CRLF/LF-Normalisierung exakt mit Kernmodulen, Anbindungen und beiden ausgelieferten
Testseiten überein. Die tatsächlichen Browser-only-/HTML-only-Buildbäume wurden
zusätzlich auf gegenseitige Modulabwesenheit geprüft. Standard-RBXLX enthält
bereits Testfixture-NUL-Zeichen und lässt sich deshalb nicht mit Python XML 1.0
parsen; dieser Parser ist kein Roblox-Nachweis. Zusätzlich wurde das Standardprojekt
als `window-extension-delivery-default.rbxl` gebaut. Für Studio wird der geprüfte
Live-Rojo-Weg verwendet. Windows10 bleibt abwesend.

Tab-Suche vom 14. Oktober nach Screenshot: nativer Pfeil links neben Tabs,
dunkles Popup mit Suchfeld/Shortcut, offenen Tabs (kleines X), einklappbaren
kürzlich geschlossenen Tabs und Favicon/URL/relativem Zeitpunkt. Suche filtert
Titel/URL, Pfeiltasten/Enter wählen, Strg+Umschalt+A toggelt, Escape/Klick außen
schließen. Closed-Row/Strg+Umschalt+T öffnen URL neu; höchstens 20 reine Metadaten-
Snapshots, keine Page-/DOM-/Realm-/Historyreferenzen. TabSearch bleibt selbständig
im Browser, Active false, manuelle Hover-/Pressfarben und stabile Zeilen-GUIs.
Tableiste um 38 px nach rechts versetzt; Plus folgt weiterhin dem letzten Tab.
Die alte Quellenkopie liegt in build/browser-tab-search-20261014. Zehn Suiten
in `build/browser-tab-search-final-20261014-full16.log` und drei eigenständige
Shellsuiten in `build/browser-tab-search-standalone-final-20261014-full16.log`
bestehen einschließlich echtem HTML-Suchfokus und Close/Reopen-Abbau. 427 Suiten
registriert; kein neuer Engine-Gesamtpass oder Studio-Pixelnachweis.

Buttonfarben vom 14. Oktober: Browser.Input meldet optionales Press-Feedback
separat vom gehaltenen Klick-/Drag-Besitz. Die Farbe folgt dem aktuellen
gehaltenen Treffer, erlischt beim Wegziehen und kommt bei Reenter zurück.
Release/Cancel/Fokusverlust setzen sie zurück. View.BindButton zeichnet Hover
und Press getrennt für X, Plus, Toolbar, Menü, Favoriten/Recent-Links; PaintTab
erhält beide Zustände bei Titel-/Modelupdates. Kein Active true oder Cursor-
Override. Touch besitzt Pressfeedback und exakte Freigabe ohne klebenden Hover.
Alte Quellen in `build/browser-pressed-colors-20261014`, Rotbeleg in
`build/browser-pressed-colors-before-20261014-full16.log` (Tab-X ohne Pressfarbe).
Sieben betroffene Suiten bestehen in
`build/browser-pressed-colors-final-20261014-full16.log`, beide unabhängigen
Shellsuiten in `build/browser-pressed-colors-shell-final-20261014-full16.log`.

Hoverkorrektur vom 14. Oktober: Browser.Input hatte die Hover-Trefferprüfung
während Pressed vollständig übersprungen. Sie folgt jetzt auch beim gehaltenen
Mausklick der aktuellen Position; nach Finish/Action wird erneut geprüft, damit
versteckte/entfernte Menüreihen keinen Hover behalten. Klick-/Drag-Besitz und
exakte Touchfreigabe bleiben erhalten. BrowserShell prüft Wegziehen, Reenter,
Loslassen außen/über anderem Button, Release ohne letzten Move sowie Menüabbau.
Originalquelle/Rotbeleg: `build/browser-held-hover-20261014/Input-before.luau`
und `build/browser-held-hover-before-20261014-full16.log`. Sieben betroffene
Suiten und beide unabhängigen Shellsuiten bestehen in den held-hover-final-
Logs. Kein HTML-Import und weiterhin alle Browser-GuiObjects Active false.

Browser-Eingaben vom 14. Oktober: Nach Nutzerkorrektur ausschließlich Active
false setzen und vorhandene manuelle Klicks verwenden. Die drei expliziten
Active-true-Scrollflächen sind korrigiert; Gui erzwingt Active/Selectable false
für alle nativen und injiziert erzeugten Browser-GuiObjects. Kein Cursor-
Override und kein zusätzlicher GUI-/Input-Umbau. Der vorhandene Router behandelt
Klick/Hover, Tabdrag, Resize, Links und ausdrückliches CaptureFocus der URL.
Nachweise: `build/browser-active-false-final-20261014-full16.log` (sieben
betroffene Suiten), beide unabhängigen Shellsuiten und default/browser-Builds
jeweils tatsächlicher Exit 0. Der live gelesene Rojo-Baum enthält dieselben
Browser-/Binding-Quellen wie auf Disk. Die Browserquellen importieren
ausschließlich eigene Module; browser.project enthält keine HTML-Engine.

Neue Tab-Seite/Favoriten vom 14. Oktober: Browser enthält native StartPage
(`about:newtab`), mittig bis zu zehn letzte Seiten, begrenzten Recent-Bestand
und 28 px Favoritenleiste ausschließlich auf about:newtab. Auf Websites,
Lade-/Fehlerflächen ist sie verborgen; ihr Platz geht an den Inhalt. Tabs/
Zurück und versteckte Linkeingaben sind geprüft. Daten sind weiterhin pro Browserlebensdauer.
Die anschließende Sichtbarkeitskorrektur besteht mit acht betroffenen Suiten
in `build/browser-favorites-start-only-20261014-full16.log` und beiden
eigenständigen Shellsuiten. Favoriten-GUIs bleiben beim Verbergen erhalten.
OpenTab ohne URL/Plus/Menü/Strg+T starten sie; HTMLPageDemo übergibt für den
ersten Tab weiterhin ausdrücklich Comparison. Plus steht neben dem letzten
Tab, bei Überlauf im sichtbaren Ende. X/Abbruch sind 1 px GUI-Linien, Plus 2 px.
OnStartPage gibt in BrowserHTMLBinding Current/Pending-Sessions frei; Native
StartPage mountet kein HTML, Rückkehr erhält den Scrollverlauf. Relative
Adresseingaben ./ und ../ werden nicht länger als HTTPS-Host behandelt.
HTML-Favicon + Options.Images mit Roblox-ID ist für Tab, letzte Seiten und
Favoriten im realen Mountpfad geprüft. Unveränderte Listen behalten ihre GUIs.
13 betroffene Suiten bestehen in
`build/browser-new-tabs-final-verification-20261014-full16.log`; unabhängiger
Shelllauf, Projektprüfung, API-/Lademodulabgleich und default/browser-Builds
ebenfalls Exit 0. Der spätere Wunsch verkleinert das Plus auf 12 px bei gleich
bleibender 28 px Klickfläche; beide Shellsuiten bestehen anschließend in
`build/browser-new-tabs-smaller-plus-20261014-full16.log`. 426 Suiten registriert;
kein neuer Engine-Gesamtpass oder Studio-Pixelnachweis.

Startkorrektur vom 14. Oktober: Der tatsächlich laufende Rojo-Server hatte
noch den alten Baum mit gelöschtem SVGLab; er wurde mit default.project neu
gestartet. Der Live-Protokollbaum ist geprüft (Browser/Binding vorhanden,
HTMLPageDemo-Quelle aktuell, BrowserEnabled true). Standardstart wartet nun
auf die beiden Module und zeigt bei Fehlen einen Fehler. Nur htmlpage.project
setzt BrowserEnabled ausdrücklich false für den direkten HTML-Mount; ohne
Attribut gilt Browserstart. Keine zusätzliche StudioDemoConfig-Auswahl.
Bei Anbindungsfehlern wird auch die bereits registrierte Destroying-Verbindung
getrennt. Studio-Plugin erneut mit localhost:34872 verbinden, dann Stop → Play.
Der erfolgreiche Start meldet `HTMLPageDemo: Browser + HTML gestartet`.
Nachweis: `build/browser-startup-routing-final-20261014-full16.log` (sieben
Suiten einschließlich tatsächlichem LocalScript-Start), Projektprüfung,
API-/Lademodulabgleich und default/htmlpage-Builds jeweils tatsächlicher Exit 0.
425 Suiten sind jetzt registriert; kein neuer Gesamtpass oder Studio-UI-Nachweis.

Aktueller Aufräumwunsch: SVGLabDemo, SVGLab-Modul, SVG-Laborseiten/Blumenbeispiel,
Generatoren und svg-lab.project sind entfernt. 342 Dateien bleiben bytegleich
als nicht synchronisiertes ZIP-Regressionsarchiv erhalten; vorhandene SVG-/HTML-
Tests lesen ihre Originaleingaben daraus. Die SVG-Engine ist unverändert.
FontLabDemo/FontComparisonDemo sind in `StarterPlayerScripts/Fonts` eingeordnet;
HTMLPageDemo bleibt direkt daneben und verbindet weiterhin Browser mit HTML.
Die Standalone-HTML-/Browserprojekte bleiben vorhanden. Einzelheiten im
[Websiteprofil](WEBSITES.md#entferntes-svg-labor--14-oktober-2026).
Der SVG-Funktionslauf, acht betroffene HTML-/Browser-Suiten, fünf archivierte
Browserlogikprüfungen, API-Abgleich, Projektprüfung und drei betroffene Rojo-
Builds bestehen. Die Sourcemap bestätigt die neue Hierarchie und den Ausschluss
des ZIP-Archivs. Im alten SVG-CLI-Runner fehlten inzwischen DOM-/Selektorimporte;
der Runner löst jetzt auch spätere Abhängigkeiten aus dem tatsächlichen Graphen
auf. Alle ursprünglichen Assertions bleiben bestehen; Fehlerlogs sind erhalten.
Keine Änderung am Enginecode und kein neuer Gesamtpass.

Aktueller Architekturwunsch ist umgesetzt: `src/Browser` bleibt unabhängig von
HTMLEngine, `src/Browser/Integration/HTMLBinding` erhält beide Objekte vom LocalScript.
Default zeigt Comparison im Browser; htmlpage.project behält den direkten HTML-
Mount ohne Browser; browser.project zeigt die native neue Tab-Seite ohne Engine.
StudioDemoConfig und die zentrale WEBSITE-Auswahl sind erhalten. Tabs/History,
Lesezeichen/Menü, Entwurferhalt, gehaltene Resizegriffe, scoped Eingaben/Frames,
Staging, stale Mounts, Fehler/Abbruch und Abbau sind geprüft. Drei neue Suiten
(424 registriert) und acht betroffene Nachbarn bestehen gemeinsam in
`build/browser-module-integration-final-full16.log`; die spätere Chrome-Eingabe-
Abgrenzung besteht zusammen mit Forms in
`build/browser-module-chrome-input-final-full16.log`. Kein neuer Gesamtlauf und
keine Studio-Pixelabnahme. Der eigenständige Shelllauf und alle drei getrennten
Rojo-Builds bestehen. Der spätere gemeinsame Abschlussnachweis für zwölf Suiten
mit bereits queued nativen Callbacks ist
`build/browser-module-final-verification-full16.log`, tatsächlicher Exit 0,
einschließlich Host-Beobachterfehlern und Hintergrund-/Backdrop-Cursorbesitz.
Der finale Cursorfall ist mit dem vorherigen Scope-Gate tatsächlich rot;
Vorher-/Nachherbundle und Rohlogs bleiben erhalten.
Umfang steht im
[Websiteprofil](WEBSITES.md#unabhängiges-browsermodul--14-oktober-2026).
Reservierte Fenster-/Geräte-APIs und vollständige gemeinsame JS-/Toolbar-History
bleiben getrennte Verträge; der frühere H01–H06/C01–C09-Restauftrag ist nicht
durch diese Browseroberfläche abgeschlossen.

Aktueller Browserwunsch: `browser-requests/index.html` zeigt echte, einzeln
ausgelöste Kamera-/Mikrofon-, Fenster-, Vollbild-, Pointer-Lock- und weitere
Browserabfragen. Die Seite ist lokal in der App geöffnet; Quelle und Grenzen
stehen im [Websiteprofil](WEBSITES.md#echte-browserabfragen--14-oktober-2026).
Sie gehört ausschließlich zur Browserreferenz. Keine neuen Roblox-Hosts,
keine geänderte Studio-Startseite und kein Abschluss der reservierten P18-APIs.

Aktueller Resize-Nachtrag: Gehaltene Demo-Griffe sperren jetzt auch synchrone
Geometrieflushes. Laufende Passes und die Publikationsprüfung lesen zusätzlich
das aktuelle Attribut, bevor verzögerte Roblox-Ereignisse eintreffen. Doppelte
Hostgrößenmeldungen beenden keinen Griff mehr. Boxreads behalten während dieses
ausdrücklichen Hostmodus ihre gemessene Geometrie; physische Viewportgröße bleibt
lesbar. Finaler Altquellen-Rotbeleg und 14 separate Geometriefälle sind erhalten.
16 betroffene Suiten, statische Prüfung und Rojo-Build bestehen. Der danach
ergänzte echte Keyframe-/Resizefall besteht zusammen mit PageResizeGestures
ebenfalls; der aktuelle Bestand hat 421 registrierte Suiten, keinen neuen
Gesamtcheckpoint. Rojo34872 und Webserver8000 sind weiter erreichbar.
[Resizeprofil](LOADING-PERFORMANCE.md#gehaltene-fenstergröße-und-verzögerte-signale--13-oktober-2026)
beschreibt den Umfang und die Grenzen; es entsteht kein neuer Vollständigkeitsplan.

Aktueller Animationsnachtrag: Das Ergebnis der Composition-Demo war beim
ersten Laden um die Insets versetzt, weil GroupOpacity den Messursprung statt
PaintX/Y verwendete. Position und ungeclippte Kindvereinigung sind allgemein
korrigiert. Die echte Demo startet nun in der Regression vor dem ersten Layout.
48 native Fälle/480 Zustände prüfen Platzierung, Zahlenvarianten, Zeitpunkte,
Komposition, Resize und Abbau. Die einzige normative Prozent-/Matrix-Ausnahme
ist separat belegt und erklärt; Rohwerte und alte Quelle bleiben erhalten.
[Aktuelles Compositor-Profil](CSS-ATELIER-20261007.md#positionierte-transparenzebenen-und-animationen--13-oktober-2026)
enthält Umfang und Logs. Der abschließende gemeinsame Lauf mit 13 Suiten,
statischer Prüfung und Rojo-Build ist ebenfalls grün. Das ist kein Gesamtpass
aller 420 registrierten Suiten; die Studio-Abnahme bleibt beim Nutzer.

Aktueller Eingabenachtrag: Schnelles Ziehen konnte den Layoutworker dauerhaft
neu starten. Aufgeschobene Style-/Class-/Text-Batches mit erhaltenem Renderbesitzer
dürfen nun den laufenden Pass fertig werden lassen. Die echte ComparisonForms-Logik
und drei fortlaufende Veröffentlichungen sowie weiterhin wirksame Struktur-/Attribut-/
Viewport-/Disposal-Abbrüche sind geprüft. Elf gezielte Suiten, statische Prüfung
und Rojo-Build bestehen; der finale bytegleiche Test bleibt mit dem alten Worker
tatsächlich rot. Belege und Grenzen:
[Layoutfortschritt](LOADING-PERFORMANCE.md#laufende-eingaben-und-layoutfortschritt--13-oktober-2026).

Aktuelle Nutzerarbeit: `Comparison` ist die Studio-Startseite und hat neun eigenständige Unterseiten mit je drei Beispielen. Rojo34872 und Webserver8000 laufen. Beide gemeldeten nativen Memberfehler sind korrigiert; der Messgraph liest LayoutParent nur von Geometrie, Textauswahl liest LayerCollector.Enabled statt ScreenGui.Visible. Neu gebaute Wörter und geöffnete Details werden lokal bis zur vollständigen Geometrie zurückgehalten. Verspätete native Fokusmeldungen lösen keine Capture/Release-Schleife mehr aus. Die echten Seitenskripte und gezielte Kontroll-/Auswahl-/Layout-/Abbauprüfungen bestehen; Einzelheiten und Original-Rotbelege stehen im [aktuellen Review](PROJECT-REVIEW.md#vergleichsseiten-und-gemeldete-native-fehler--13-oktober-2026) und [Websiteprofil](WEBSITES.md#vergleich-mit-getrennten-unterseiten--13-oktober-2026). Der erste neue Gesamtlauf ist tatsächlich rot wegen einer historischen künstlichen textContent-Sperre; die originale Datei bleibt gesichert, ihre Negativassertion erhält eine nativ tatsächlich verbotene Document-Einfügung. Die ursprüngliche gültige Ersetzung ist separat nativ und mit Editorfreigabe geprüft. Der zweite Gesamtlauf `build/comparison-and-native-fixes-retry-full16.log` endete tatsächlich rot: ein Mockrenderer hatte EnablePendingPresentation nicht. Der Host prüft die optionale Methode nun; fünf unveränderte Seiten-/Iframe-Suiten bestehen in comparison-page-owners-reviewed-full16.log. Ein neuer Gesamtpass für die aktuellen Quellen ist noch nicht belegt. API5101/641/128 ist bytegleich zurückgesetzt und geprüft; der generische Daten-DOM bleibt ebenfalls bytegleich. Der allgemeine Farbwähler ist jetzt angebunden; Loader524. Umfang und Grenzen stehen im Eingabetypen-Profil unter Farbauswahl. Elf gezielte Picker-/Formular-/Fokus-/Seiten-/JS-Suiten bestehen im abschließenden color-popup-final-targeted-full16.log; die statische Prüfung color-popup-static-full16.log besteht ebenfalls. Das ist kein Gesamtpass aller 419 Suiten.

Nächste Grammatikarbeit: [BUILD-only Source5](../build/scope-family-raw-comments-prep/manifest.json) führt das rohe Scope-Prelude durch beide CSSOM-Parser und erhält unbekannte vergebende Zweige mit echtem Referenztoken. Alle 18+16+24 exakten nativen Serialisierungskontrollen, Namespace-/Nested-/Retainedpfade und zwölf Nachbarsuiten haben tatsächlichen Exit0 (`build/scope-family-raw-comments-focused-full16.log`). Alte gehaltene Kandidaten, Fehlerlogs und Referenzen bleiben unberührt. Der neue Kandidat ist noch nicht in Produktion, Loader oder Register übernommen. Zwölf zusätzliche rohe/native Kontexte haben vier weitere echte Abweichungen aufgedeckt (scope-comments-extra-contexts-full16.log, tatsächlich rot); Assertions und Rohbelege bleiben unverändert. Der vollständige Kandidatenreview fehlt. Der frühere 417-Gesamtcheckpoint betrifft ausschließlich den damaligen Source4-Stand und nicht diese neue Quelle oder die aktuellen UI-Korrekturen.

Geprüfter Projektstand vom 13. Oktober: Der [aktuelle Scope-Gesamtcheckpoint](../build/scope-core-canonical-prep/full-current-acceptance.json) besteht mit tatsächlichem Exit 0: 417 registrierte Suiten einschließlich erforderlicher kompakter Prüfungen und 13 isolierter GC-Prüfpfade. Nach dem Lauf sind 1.749 Quell-/Test-/Fixture-/Scriptdateien, sieben Projekte und Loader523 geprüft. Projektprüfung, drei Rojo-Builds, API-Abgleich und Dokumentprüfung bestehen ebenfalls. Scope-Subjects/relative Namespaceanker, CSSOM-Kontexte und die zwölf erfassten verschachtelten Kontexte sind als begrenzter Source4-Pfad übernommen. Eine alte CSSOM-Renderingprüfung erwartete unzulässig direkten Root-Paint: Alle Originalquellen/Assertions bleiben erhalten, drei strikte Native-Negative und drei explizite selectorText-Korrekturen ergänzen sie. Der erste Scope-Gesamtlauf bleibt als tatsächlicher Rotbeleg erhalten. Das CSS-Register enthält 16 ausdrücklich partielle Zuordnungen mit 80 Anforderungen: 39 erfüllt, fünf offen, 36 ungeprüft; die bisherigen 72 sind unverändert. Dies ist kein vollständiger Restzähler. Nächster BUILD-Stand ist der zusätzliche Scope-Prelude-/Formatterpfad mit gemeinsamem Referenztoken-Scanner; seine Quelle ist nicht übernommen. Agenten meldeten ein Nutzungslimit; Root arbeitet weiter. Der gesamte H01–H06/C01–C09-Auftrag und die abschließende Browser-/Roblox-Abnahme bleiben offen.

Begrenzte aktuelle Video-Korrektur vom 13. Oktober: [Öffentliche Zeitsprünge und Posterwechsel](MEDIA.md#öffentliche-video-zeitsprünge-und-posterwechsel--13-oktober-2026) stellen bei verfügbarem Video die neue natürliche Größe vor synchronen VideoState-Subscribern bereit; DOM seeking/seeked behalten getrennte Taskpfade. Vor Metadaten wird nur die Startposition gespeichert. Unveränderte Darstellungsreferenz 152/28/40/5636 und 14 ursprüngliche Video-/Mediennachbarn sowie neue 102 Kontrollen/2240 Assertions haben tatsächlichen Exit 0. Der aktuelle gemischte Produktionslauf nach Quellenübernahme hat 18 Suiten mit tatsächlichem Exit 0. Aktuelle Quellen-/Besitzerprüfung nach nativen und Present-Rückmeldungen, erhaltene GUI/Editor/UTF16 und wiederholte Auto-/Fixed-Seeks ohne weitere Layout-/Ladearbeit sind begrenzt belegt. Ranges, gleichquellige verschachtelte Sprünge, vollständige Ereignisordnung/Frameverfügbarkeit, übrige Callback-/Propertyfehler und Studio bleiben offen; der erste Fixed-Wechsel kann weiter lokal layouten. Der kombinierte vierte Full16-Lauf war tatsächlich rot; diese Korrektur und die früheren drei Rotbelege begründen keinen breiten Gesamtpass oder neuen Registerstatus.

Aktueller begrenzter Nachtrag: [IFrame-Einzelkind-Cleanup](IFRAMES.md#iframe-einzelkind-cleanup-und-getrennte-coroutine-kontexte--12-oktober-2026) hält 60/1758 Kontrollen mit Coroutine-getrennten ersten Fehlern und 17 Autor-Suiten mit tatsächlichem Exit 0. [Live-Owner im Messgraphen](CSS-ATELIER-20261007.md#live-ressourcen-außerhalb-des-messgraphen--12-oktober-2026) korrigiert den tatsächlich reproduzierten AudioSession→HostPage→VM-Pfad: 21 Grenzassertions und unveränderter 140 Inline-Geometrien/8980 Messprüfpunkte, neun Autor-Suiten mit tatsächlichem Exit 0. Quellen/HOLDs und alte Tests/Referenzen bleiben getrennt erhalten. Andere asynchrone Callback-/Propertyfehler, allgemeines GC und Studio-Pixel/FPS bleiben offen. Die drei damaligen Full16-Versuche bleiben als rote Nachweise erhalten; der aktuelle gemeinsame Prüfstand ist oben gesondert dokumentiert.

Der Gesamtauftrag bleibt aktiv. Der verbindliche Endpunkt steht in
[PLAN](../PLAN.md#verbindlicher-gesamtabschluss); H01–H06 und C01–C09 sind weiterhin
die vorhandenen Arbeitspakete. Eine vollständige Zuordnung aller Anforderungen,
alle notwendigen Umsetzungsschritte und die abschließende visuell abgenommene
Browser-/Roblox-Vergleichsseite sind noch nicht erreicht. Die aktuellen
Paketstände stehen ausschließlich im
[HTML-Profil](HTML-PARSER-ATTRIBUTES-20261006.md#beauftragter-ausbau-vom-8-oktober-2026)
und [CSS-Profil](CSS-ATELIER-20261007.md#beauftragter-ausbau-vom-8-oktober-2026).

Die folgenden Fachprofile enthalten die jüngsten Nachweise und genaue Restfälle:

- [C01 Selektornamen und Werte](CSS-ATELIER-20261007.md#selektornamen-namensräume-und-attributwerte--10-oktober-2026):
  Typ-/Attributnamen benutzen Namespace und lokalen Namen mit dokumentabhängiger
  HTML-Faltung. `of-type` ignoriert Präfixe; Adoption benötigt keine Neukompilation.
  HTML-Attributwertregeln und explizite `i`/`s`-Flags sowie Namespacekarten in
  Scope-Grenzen sind mit 163 DOM- und 86 tatsächlichen Paintdatensätzen abgeglichen.
  CSS-Whitespace, Strings, Escapes, Kommentargrenzen und An+B-Koeffizienten
  werden gemeinsam tokenisiert; reale CSSOM-Regelzahlen und Serialisierungen
  verhindern das unbeabsichtigte Reparieren ungültiger Selektoren.
  Expanded-Name-Pseudozustände und gemeinsame FormOwner-Auflösung bestehen
  mit acht nativen Pseudo-Datensätzen und 15 betroffenen Suiten.
  `:state()` verarbeitet nun denselben CSS-Identtoken für Unicode/Escapes und
  Fehlergrenzen; CSSOM serialisiert den dekodierten Namen. Shadow-Hostfarben
  erreichen die ursprünglichen Rahmenmodifier ohne Layout oder Editorverlust.
  Richtungsargumente lesen CSS-Identtokens; SVG-Linkzustände beachten echte
  XLink-Namespaces. `:root` trifft nur das tatsächliche Dokumentelement,
  keine losgelösten Elemente oder Fragment-/Shadow-Kinder.
  DOM/CSS/native Eingabe teilen nun EditingHost-Zustände; 76 exakte native
  Ergebnisse und 15 getrennte normative Abweichungen sowie 14 echte Paintzustände
  belegen Vererbung, DesignMode und Eingabetypzustände ohne GUI-Neuaufbau/Layout.
  Einzelheiten stehen im vorhandenen [Editingprofil](JAVASCRIPT-EDITING-R04.md).
  Überschriftenoffset/Reset und das vorhandene Selectors-5-Headingprofil sind mit
  35 experimentellen IDL- und 26 rohen AX-Kontrollen ergänzt; normative Grenzen
  und gewöhnlich fehlende Chromium-Unterstützung bleiben getrennt erhalten.
  Neun montierte Farbzustände erhalten Labels/Editor/Auswahl ohne Neulayout.
  Relationale `:has()`-Grammatik bewahrt Grenzen nicht vergebender Listen und
  verbietet verschachtelte `:has()` auch in weiteren funktionalen Selektoren.
  41 Grammatik-, 21 DOM-/CSSOM- und acht Spezifitäts-/Kaskadenfälle sowie neun
  montierte Farbzustände und elf Nachbarsuiten bestehen. Forgiving Listen
  verwerfen nur die ungültigen Zweige; Rohunterschiede bei Bad Strings,
  EOF-Fehlerkorrektur und CSSOM-Serialisierung bleiben getrennt erhalten.
  Rohe Browser-/Standardunterschiede bleiben erhalten; weitere C01-Achsen sind offen.
- [H03 Parser und Laden](HTML-PARSER-ATTRIBUTES-20261006.md#h03-live-parser-und-dynamisches-schreiben--9-oktober-2026):
  echte Script-Einfügepunkte, Schreiben/Ersetzen, CSS-Import- und Parent-/Frame-
  Barrieren, Srcdoc-Modus, eingefrorene Basisadressen und gemeinsamer URLparser.
  Gewisse Bytequellen werden inzwischen stückweise bis zum nächsten Script
  dekodiert; Ausgabe-/Abbruchbudgets und der retained Renderer sind geprüft.
  Netzwerkzufuhr und tentative Encodingneustarts nach Veröffentlichung bleiben offen.
- [H02/H05 Formulare](FORMS.md): Rich-Select-Inhalte verwenden den gemeinsamen
  DOM-/CSS-/Renderbaum; anonyme Base-Dropdowns, UA-Zustände, Moduswechsel und
  gemeinsam positionierte Picker sind ergänzt. HTML-Ereignisattribute und benannte
  Form-/Dokumentproperties mit Originalrealm, Namensinvalidierung und Abbau sind
  dokumentiert. Vollständige Kombinationen bleiben im Fachprofil offen.
- [Benannte Dokumentproperties](JAVASCRIPT-DOCUMENTS-R02.md#namensindex-und-begrenzte-mutationsinvalidierung--10-oktober-2026):
  Relevante Kandidatenänderungen invalidieren den dokumenteigenen Namensindex;
  irrelevante Mutationen erhalten ihn. Die gemeinsame begrenzte Klassifizierung
  ist gegen reentrante Reads, große Listen, Adoption und Freigabe geprüft.
  Memory mit 24 Karten benötigt dadurch 25.638 statt 35.524 Schritte bei
  unverändertem 30.000-Budget. 13 gezielte Suiten einschließlich isolierter
  GC-Prüfungen bestehen. Die echte Memory-Rendererfixture verwendet jetzt
  denselben Frame-Treiber für CSS- und JavaScript-Uhren; ihre strikten
  Sichtbarkeits-/Replay-Erwartungen bleiben erhalten. Legacy-Property-Setter,
  Frame-WindowProxy-Zuordnung und rohe Detached-Document-Unterschiede bleiben
  ausdrücklich im Dokumentprofil offen.
- [H05 Attributidentität](HTML-PARSER-ATTRIBUTES-20261006.md#attributnamen-namensräume-und-objektidentität--10-oktober-2026):
  Namespace-/QName-Zugriff, Attr-Replacement samt synchronen Reaktionen,
  Serialisierung und Gleichheit sind abgeglichen. Der tatsächliche Renderer
  akzeptiert eigene gültige Attribute und hält GUI-/Controlidentität bei reinen
  Farbänderungen ohne Layout; unveränderte Namespacewerte behalten Querycaches.
  XML-Namespace-Fixup und die getrennten strikten Markup-/XMLSerializer-Pfade
  bestehen mit 63 nativen Datensätzen und 126 Roundtrips im
  [R02-Profil](JAVASCRIPT-DOCUMENTS-R02.md). Template-Inhalte behalten inert
  OwnerDocument-, Clone-/Import-/Adopt- und Aktivierungsgrenzen.
  HTML-Expanded-Names sind für DOM/Form mit 55 exakten nativen Ergebnissen
  und drei getrennten normativen FormData-Erwartungen ergänzt. UA-/Renderer-,
  Shadow-/Slot- und Directionality-Pfade sind mit 27 weiteren nativen Ergebnissen,
  zwei normativen Grenzen und sieben tatsächlichen montierten Rechtecken ergänzt.
  DOM-Ressourcen-/Script-/Stylesheet-Hostadapter bestehen mit 33 synchronen
  und sechs asynchronen nativen Ergebnissen. Sieben srcset-Lexingproben
  bewahren vier exakte und drei getrennte UA-Auswahl-/Profilergebnisse;
  alte Bildrequests, Owner-Erhaltung und Dispose sind geprüft.
  Montierte Bild-/Canvas-/Medienpfade verwenden nun Expanded-Names; sechs
  Rechtecke, acht Observergrößen, zwei echte Canvas-Pixelwerte sowie zwölf
  Kanten-/Transform-/Box-Sizing-Zustände stimmen nativ überein. Text-/Quellen-
  Änderungen erhalten Controls und Bild-GUIs. Audio ohne Controls verliert
  seine alte Fläche; gewöhnliches und per DOM erzeugtes präfixiertes Audio
  erhalten im AudioHost denselben laufenden Sound ohne erneutes Laden.
  Die neue Suite und 15 Nachbarn bestehen. Gemeinsame Video-IDLs und weitere
  Metadaten-/Observerkombinationen bleiben offen.
  [Eigene Inline-2D-Transformationen](CSS-TRANSFORMS.md#eigene-2d-transformation-ersetzter-inlineflächen--10-oktober-2026)
  erreichen inzwischen die behaltene Borderfläche: 140 native Paint-/CSSOM-
  Geometrien und 9.258 reine Messprüfpunkte, Opacity-/Ellipsen-Repaint,
  Resize/Abbruch, Editoridentität und Cleanup bestehen. 23 Nachbarsuiten und
  unabhängiger Review sind grün. 3D-/Raster-, ungleichmäßige/negative Skalierung,
  Skew und vollständige Fragment-/Treffer-/Animationskombinationen bleiben offen;
  dies ersetzt keinen Studio-Pixel- oder FPS-Nachweis.
  HTML-/SVG-Stylebesitzer teilen nun direkte Text-/CDATA-Quellen und gültige
  Namespace-/LocalName-Zuordnung. 233 ausgewählte native Zustände und 18 montierte
  Farb-/Editorzustände, identische Blockupdates, Importcancel, späte Completion,
  Dispose und isolierter Weak-GC bestehen; 17 Nachbarsuiten und unabhängiger
  Codepfadreview sind grün. SVG2-Display-/Chromium- und Typtriggerunterschiede
  bleiben ausdrücklich getrennt; SVG-fill-Serialisierung, alternative Blätter
  und weitere Host-/Attributkombinationen bleiben im Stylesheetprofil offen.
  [Dokumentzugriffe](HTML-PARSER-ATTRIBUTES-20261006.md#dokumentzugriffe-und-gemeinsame-metadaten--10-oktober-2026)
  verwenden für DOM und Hostmetadaten gemeinsame Head-/Body-/Titelregeln.
- [C05/C06 Text](HTML-SUPPORT.md) und [Trennung](OVERFLOW-WRAP.md): UAX-9-Umordnung
  ist mit echten Zeilen-/Paint-/Source-/Selection- und Live-Inputpfaden verbunden.
  Sprachmuster, Whitespace, Einzug und Unicode-Textumwandlung sind ergänzt.
  Vertikale Orientierung, logische Achsen, Dekoration, Selection, Schatten und
  Emphasis sind mit erhaltenen Quellspannen verbunden; Schrift-/Layoutkombinationen
  werden weiter geprüft.
- [C02 Anker und Queries](CSS-ATELIER-20261007.md#ankerpositionierung--9-oktober-2026):
  `match-parent`, Position-Reset, Pickeranker und gezielte externe Layoutabhängigkeiten
  sind ergänzt; rohe Chromium-Entwurfsunterschiede bleiben separat erhalten.
  Position-Area-/Fallbackregionen sind ergänzt; weitere transformierte,
  fragmentierte und Scroll-/Shadowkombinationen bleiben im Fachprofil offen.
- [C03 Größen](CSS-ATELIER-20261007.md): logische bevorzugte Größen und Limits
  folgen endgültigen Schreibachsen/Kaskaden, mit 92 nativen Fällen/208 Zuständen.
  Intrinsische bevorzugte Größen und Min-/Max-Limits sind mit 91 nativen
  Fällen/994 Zuständen ergänzt, einschließlich Textzeilen, Bild-/Input-Image-
  Gegenachsenwerten, Aspect-Ratio, Prozentkindbasis, Margin-Beiträgen und
  abgegrenzten Flex-/Grid-Aufrufern. Reine intrinsische und atomare Messungen
  verwenden jetzt einen vollständig verbundenen eigenen Geometriegraphen mit
  der vorhandenen Arrange-Folge: 54 native Editorzustände, 170 native
  Boxgrößenvergleiche, 750 Budgetpausen und 34 native Textmesspausen erhalten
  CSSOM, GUI, Treffer, Editorwert/Fokus/Markierung und Bindungen. Abbruch,
  Recovery, warme Caches und 43 Nachbarsuiten bestehen. Automatische Column-
  Flex-Querbreiten verwenden jetzt die gemeinsame Fit-Content-Intrinsik samt
  aktuellen Prozentkanten. 118 native Resize-/CSSOM-/Font-/Editorzustände mit
  350 Boxvergleichen, unabhängiger Vollparität, warmen Caches und 15 Nachbarsuiten
  bestehen; ursprünglicher Editor, Fokus, Markierung und Bindungen bleiben erhalten.
  Der unabhängige Review korrigierte einen Capture-Ersatz: anonymer Text wird
  jetzt tatsächlich als direktes Words-Item geprüft. Die Wrap-Kontrolle bleibt
  ausdrücklich einspaltig; echte Mehrspalten-/Prozentkombinationen sind offen.
  Das abgegrenzte Fontprofil verwendet ausdrücklich `font-kerning:none`;
  rohe Arial-Formung bleibt im Fachprofil offen. Die vier unveränderten
  `self-start`-Kontrollen sind inzwischen im begrenzten Alignmentnachweis vom
  11. Oktober akzeptiert; FlexAutoCross umfasst nun 122 Zustände/362 Vergleiche.
  Intrinsische Scrollbalkenbeiträge besitzen nun 159
  Größenvergleiche aus 53 nativen Fällen und neun montierte Editor-/Resizezustände;
  22 Nachbarn und unabhängiger Review bestehen. Klassische Hostkalibrierung
  10/6/0 und rohe Plattformwerte bleiben getrennt. Negative Inlineausdehnungen
  bestimmen die Leistenentscheidung; vollständige negative Navigation und
  weitere Gutterkombinationen bleiben im [Scrollingprofil](SCROLLING.md) offen.
  Die letzte Letter-Spacing-Kante bei `min-content` bleibt ebenfalls offen.
  Weitere generische Live-Flex-/Grid-/Positionierungsproben und ein allgemeiner
  pausenfreier GUI-/GPU-Paintcommit bleiben separate Architekturarbeit.
- [C08 Animationen](JAVASCRIPT-ANIMATION-LAYOUT.md): intrinsische Größen,
  individuelle Transforms, Ganzzahlen, Border/Outline/Radien und geerbte
  Schrift-/Farbwerte durchlaufen denselben Paint-/Layoutpfad. CSS-DOM-Objekte,
  Ereignisse, Cancel-/Replay-Identität und Animation-Shorthands sind ergänzt.
  Ersetzung/Entfernung fertiger Effekte und der letzte Pending-Finish-Frame
  sind geprüft. Schattenlisten malen über behaltene UIShadow-/Insetflächen
  mit Generation-/Abbaugrenzen ohne Layout. Transform-Origin ergänzt 29 native
  Wertefälle und tatsächliche 2D-/3D-Paint-/Hit-/Fixed-/Editorpfade; der stabile
  Wertcheckpoint umfasst nach Text-Shadow-/Emphasis-Farberweiterung und acht
  Outline-/Font-Transition-Kurzformfolgen 337 native
  Fälle, vier Level-2-Erweiterungen, fünf Browser-only-Referenzen und 13 normative
  Proben mit erhaltenen Rohdifferenzen. Animierte/geerbte Schatten benutzen eigene
  Autoren-/Samplegrenzen, ursprüngliche Schattenlabels und Opacity-Bounds ohne
  uniformes Neulayout; Scope-Erstpaint, Editor, Commit/Cancel und Cleanup sind geprüft.
  Betonungsfarben verwenden denselben Color-/Mark-Painter samt statisch symbolischer
  bzw. abgetastet aufgelöster currentColor-Vererbung und behaltenen Marken-/Editor-
  Objekten. Zwölf Animations-/Text- und 15 Farb-/Painter-/Lifetime-Nachbarn bestehen.
  Outline-/Font-Transition-Listen beachten letzte Longhandpriorität; Outline-
  Offset bleibt außerhalb der Kurzform. Ein beim letzten Controller-Release
  wartender Restore-Besitzer wird beim Seitenabbau ebenfalls aufgeräumt.
  Zwölf betroffene Nachbarn und ein unabhängiger LIFO-Cleanup-Review bestehen.
  Weitere animierbare
  Eigenschaften und Timingkombinationen bleiben offen.

Die gezielten neuen Regressionen bestehen. Der fünfte Aggregatelauf fand
zwei konkrete Folgefehler der genaueren UA-Elementrollen: doppelte Summary-
Layouttargets beim Aufklappen und übersprungene Shadow-Inhalte in gewöhnlichen
Inline-Elementen. Die engen Korrekturen erhalten die ursprünglichen strikten
Details- und Comparison09-Erwartungen; beide Fehler sind gezielt reproduziert
und behoben. Der sechste Aggregatelauf vom 10. Oktober enthält anschließend
auch die reinen Messgraphen, Betonungsfarben und Memory-Budgetkorrekturen.
Diese Suiten bestehen darin; der Gesamtprozess endet jedoch mit Exit 1 wegen
eines URL-Konstruktorfehlers für einen nicht speziellen opaque host
(`foo://UPPER.example/a`). Die gemeinsame URLpfad-Korrektur ist inzwischen
gezielt geprüft: 502 native Sequenzen, davon 501 direkt exakt und ein separat
ausgewiesenes normatives Frozen-Base-Delta; 13 Nachbarsuiten einschließlich
frischer isolierter GC-Prüfungen sowie drei eigenständige Bibliotheksprüfungen
bestehen. Der unabhängige Review ergänzte außerdem eine bereits vorhandene
IPv6-Portgrenze: 72 zusätzliche Konstruktor-/Host-/Hostname-Suffixfolgen prüfen
den obligatorischen Doppelpunkt und atomare Fehler. Der Fix erhält das VM-Budget
und die gemeinsame Parserdelegation;
weitere URL-Zustands-/Setter-/Hostadapterkombinationen bleiben im
[Text-/URL-Profil](JAVASCRIPT-TEXT-DATA-20261005.md#gemeinsame-opaque-hosts--nachprüfung-vom-10-oktober-2026)
offen. Der siebte Aggregatelauf scheitert anschließend an einer bestehenden
strikten CSSAtelier-Gridbreitenerwartung. Eine unbesuchte reine Größenprobe
überschrieb bereits aktuelle Fontbounds mit alten sichtbaren Glyphenmaßen.
Der gemeinsame Messcache bewahrt jetzt passende vollständige Bounds; der
Gridalgorithmus und seine ursprünglichen Erwartungen wurden nicht gelockert.
CSSAtelier mit neun neuen nativen Resize-Kontrollen, Atomic und zehn Nachbarn
bestehen gezielt. Relative dynamische LetterSpacing-Werte waren zu diesem
Zeitpunkt noch offen; der folgende Nachweis vom 11. Oktober ergänzt sie.
Der achte Aggregatelauf auf dem eingefrorenen
Quellstand endet ebenfalls mit Exit 1: CSSAtelier erreicht eine Inline-Grid-
Größenprobe ohne `MeasureGrid`-Callback. Der bisherige Gridbreitenfehler ist
darin nicht erneut gemeldet. Der neue Messpfadbefund ist inzwischen reproduziert
und eng korrigiert: Die intrinsische Scrollbarprobe übergab ihre Größenoptionen
versehentlich als `prepared`-Argument und übersprang dadurch die Vorbereitung
des eigenen Messgraphen. Der vorhandene Arrange-Pfad erhält jetzt die Optionen
im richtigen Argument; Livecallbacks werden nicht in Messkopien übernommen.
Die ursprünglichen CSSAtelier-Erwartungen, 18 Nachbarsuiten und ein unabhängiger
frischer Review bestehen. Sechs neue verschachtelte Inline-Block-/Flex-/Gridfälle
mit 18 nativen Größenvergleichen ergänzen die unveränderten 159 Scrollbarwerte;
warme Messwerte, echte Abbruch-/Recoverygrenzen und GUI-Identitäten sind geprüft.
Die nachgelagerten isolierten Prüfungen liefen wegen des
Mainfehlers noch nicht. Projekt-/Registerprüfung und die drei Rojo-Projekte mit
EngineTests bestehen; nur die absichtlichen UTF-16-Surrogate der rohen URL-
JSONreferenz sind vom Studio-Sync ausgenommen, unverändert im CLI-Test erhalten.
Ein bestandener Gesamtcheckpoint wird erst nach dem erneuten vollständigen
Lauf einschließlich isolierter Prüfungen gemeldet. Der anschließende
[Canvas-Slice vom 11. Oktober](CSS-BACKGROUNDS.md#dokument-canvas-und-tatsächliche-paintbesitzer--11-oktober-2026)
besteht gezielt mit 41 nativen Initialfällen, sieben dynamischen Zuständen und
736 behaltenen GUI-/Bufferpixelproben. Root-/Bodywahl, einmaliges Alpha,
Rootkomposition, tatsächliche PageSession-/SVG-Request-/Disposepfade und acht
warme normale Blockbox-Radiuswechsel gegen frische Endzustände sind geprüft.
17 Nachbarsuiten, neun betroffene Cornernachbarn und der unabhängige Review
bestehen. Vollständige Besitzer-/Zustands-/Ressourcenkombinationen,
`getComputedStyle().backgroundImage`, Roottransform/Attachments, ersetzte
Bild-/Control-Rahmenkombinationen und native Studioabnahme bleiben im Profil
offen. Der anschließende [dynamische Buchstabenabstand](CSS-ATELIER-20261007.md#dynamischer-buchstabenabstand--11-oktober-2026)
besteht mit 24 nativen Wertzuständen und 156 Vergleichen, sieben Klassen-/
Variablenzuständen mit sechs Mutationen, tatsächlichem B/C-Selection-Paint
und kopiertem Text, reinem warmem/abbrechbarem Messcache sowie behaltenem Editor.
Der gemeinsame Tokenizer teilt oder vereinigt nur betroffene Quellgruppen;
unveränderte Glyphen bleiben erhalten. Der Tabular-Boolwert gehört nun auch
zum Messschlüssel und wird bei Rückwechseln als `false` veröffentlicht.
18 Nachbarsuiten und der unabhängige Source-/Hook-/Cache-/Painter-/Selection-
Review mit frischem Target nach Hold bestehen. Native Editor-Trackingdarstellung,
allgemeine Glyphenformung, Vollgrammatik und Studiooptik bleiben getrennt offen.
Im einzigen CSS-Register sind nach den Ergänzungen vom 11. Oktober 25 eng
abgegrenzte Anforderungen erfüllt. Die neun Zuordnungen mit insgesamt 52
Teilanforderungen bleiben unvollständig: fünf offen, 22 ungeprüft. Der übrige
Standardbestand ist noch nicht vollständig aufgeteilt; dies ist ausdrücklich
kein Gesamtzähler verbleibender CSS-Arbeiten.
Der neunte vollständige Aggregatelauf vom 11. Oktober endet mit Exit 0:
347 registrierte Suiten einschließlich DOM-Traversal/-Queries/-Ranges,
Renderer-Lifetime, Unicode-Bidi und aller zehn isolierten GC-Prüfungen bestehen.
Der eingefrorene Stand mit 1.631 Quell-/Test-/Fixturedateien und sieben
Rojo-Projektdefinitionen ist anschließend unverändert verifiziert.
Projekt-/Registerprüfung, drei Registererhaltungstests und die drei Rojo-Builds
bestehen ebenfalls. Damit sind die oben genannten Fontcache-/Scrollbarfixes,
Canvas- und Textabstandsänderungen im gemeinsamen CLI-Stand bestätigt;
dies ersetzt weder vollständige Anforderungszuordnung noch Studio-Pixel/FPS-Abnahme.
Die anschließenden begrenzten Restfälle bestehen nun gezielt und unabhängig:
leere Hintergrund-URLs erzeugen keine Ressourcenarbeit, bleiben aber vorhandene
Bildebenen für die Canvasbesitzerwahl. Der Canvasnachweis umfasst 59 Initial-
und 73 dynamische Zustände mit 1.490 Pixelproben; 63 native Fälle/136 Rohzustände
sind erhalten. Horizontale Flex-/Grid-Seitenausrichtung besitzt 580 Zustände
mit 2.840 Boxvergleichen sowie 122/362 Column-Flex-Kontrollen. Vertikale Container,
vollständige Grammatik/Scrollsicherheit und Fontformung bleiben ausdrücklich offen.
[Ausgeblendete Inhalte](CSS-ATELIER-20261007.md#ausgeblendete-inhalte-und-erhaltene-objekte--11-oktober-2026)
behalten GUI-/Editor-/Bildidentitäten, verborgene DOM-Änderungen, Auswahl,
Linkfokus und getestete Tabellen-/Fieldsetmodelle; 82 native Rohzustände sind
als 79 direkte Vergleiche, zwei normative Zellkontrollen und eine separate
Chrome-Tabgrenze ausgewiesen. 22 zusätzliche Top-Layer-Zustände erhalten
logische Modal-/Popovermitgliedschaft und Modal-Sperre trotz ausgeblendeter
Darstellung; Fokus, Escape und Light-Dismissal funktionieren auch bei alten
Fensterkoordinaten. Allgemeine Containment-/Auto-/Observer-/Layoutkombinationen
und native Studioabnahme bleiben offen. Die gehaltenen Quellen sind unabhängig
reviewt. Der zehnte vollständige Aggregatelauf endet anschließend mit
tatsächlichem Exit 0: 350 registrierte Suiten einschließlich aller erforderlichen
isolierten Prüfungen. Die anschließende Prüfsummenkontrolle bestätigt unveränderte
1.641 Quell-/Test-/Fixturedateien und sieben Rojo-Projektdefinitionen. Projekt-/
Registerprüfung, API-/CSS-Exportchecks und drei Rojo-Builds bestehen ebenfalls.
Die Ausrichtungs-, Canvasbesitzer- und ausgeblendeten Inhaltspfade sind damit im
gemeinsamen CLI-Stand bestätigt; Studio-Pixel/FPS und übrige Standardanforderungen
bleiben getrennt offen. Der konkrete H05-Slice
[Bildkarten](HTML-PARSER-ATTRIBUTES-20261006.md#lebende-bildkarten-und-flächen--11-oktober-2026)
ist im begrenzten Teilumfang unabhängig geprüft. Der DOM-Teil besteht mit zehn nativen Fällen,
38 area-TabIndex-Kontrollen, beiden lebenden Realm-Adoptionsrichtungen,
ursprünglichem Collection-Prototyp und isolierter Freigabe entfernter Bereiche
sowie unbenutzter Map-/Listenzirkel. Shape-Reflexion bewahrt rohe Autorenwerte;
die beiden Attributgruppen sind eng im bestehenden Register belegt. Der tatsächliche
Renderer-/Controllerpfad ergänzt 48 native Primärfälle mit 82 Zuständen/139
Pointerproben, acht getrennte normative Default-Reihenfolgen und 15 unabhängige
Vollrechteckkontrollen. Synthetische AREA-/A-Klicks aktivieren Links genau einmal
mit `isTrusted=false`; Fokus, Editor/UTF16, Bildressourcen, gewöhnlicher Map-Inhalt
und Cleanup bleiben in den genannten Kontrollen erhalten. Countertext außerhalb
Maps und unveränderte Cursorbewegung verursachen keine neuen Zuordnungsscans;
Strukturklassifizierung begrenzt auch die Frontier auf 256 Knoten mit konservativem
Fallback. Neun gezielte und zwölf unabhängig geprüfte Suiten bestehen bei
unveränderten 13 Renderer-/Test-/Fixture-/Capturedateien. Beide Bildkarten-GC-Suiten
laufen wegen belegten Aggregate-Heapeinflusses einschließlich nicht gesammelter
Plain-Object-Kontrolle im bestehenden isolierten Pfad mit unveränderten Budgets.
Sechs betroffene Attributgruppen und der vorhandene `tabindex`-Eintrag besitzen
nur eng belegte Wirkungs-/Darstellungs-/Kombinationsachsen. Es gibt keinen pauschalen H05-/Studio-/OS-Cursor-/stationären
Hover-/Transformabschluss.
Der API-Export enthält 5.093 installierte Deskriptoren bei null Getterreads;
das ist weiterhin nur Verfügbarkeit. Der elfte Gesamtlauf endet mit tatsächlichem
Exit 0: 352 registrierte Suiten einschließlich DOM-Traversal/-Queries/-Ranges,
Renderer-Lifetime, Unicode-Bidi und zwölf isolierten GC-Prüfungen. Die anschließende
Snapshotkontrolle bestätigt unveränderte 1.648 Quell-/Test-/Fixturedateien und sieben
Rojo-Projekte. Projekt-/Registerprüfung, API-/CSS-Exportchecks und drei Rojo-Builds
bestehen. Rohprotokoll: `build/html-full-20261011-eleventh.log`; unverändertes
Hauptbundle: `build/html-tests-5856.luau`. Dies bestätigt den begrenzten
Bildkartenumfang im gemeinsamen CLI-Stand, keinen vollständigen H05-Abschluss.
Der folgende begrenzte Medienabgleich ist gezielt und unabhängig abgenommen:
sieben gemeinsame Audio-/Video-IDLs mit 17 Folgen/488 erhaltenen Rohzeilen
(19 normative Differenzen separat), dynamische bereits montierte Videos mit
72 Zuständen/32 Race-/zehn Vollbild- und inaktiven Tastaturkontrollen/2.648
Assertions sowie der gemeinsame Node-Basisadresspfad mit sieben nativen
Folgen/32 Zuständen. Die finalen unabhängigen Läufe umfassen elf Suiten für
Reflexion/Node und sieben für montierte Videos. Der
[Audio-Quellenlebenszyklus](JAVASCRIPT-AUDIO-20261006.md#quellenwahl-startposition-und-entfernung--11-oktober-2026)
ergänzt 34 Fälle/106 Übergänge/237 Rohsnapshots und einen finalen unabhängigen
neun-Suiten-Lauf einschließlich isolierter Realm-Lifetime-Prüfung. Originale
Browserdaten und finale Ownerhashes bleiben erhalten. Registerachsen sind eng
belegt; die unten ergänzten Video-Poster-/Größen-/SOURCE-Nachweise bleiben von
vollständigen Medien-Tasks, gemeinsamer Realm-Wiedergabe und Studio-Pixeln/
Decodern getrennt. Diese
neuen Quellen sind nun im zwölften vollständigen CLI-Prüfstand bestätigt:
tatsächlicher Exit 0, 356 registrierte Suiten einschließlich der zwölf
isolierten GC-Prüfungen, DOM-Traversal/-Queries/-Ranges, Renderer-Lifetime und
Unicode-Bidi. Nach Laufende waren alle 1.660 Quell-/Test-/Fixturedateien und
sieben Rojo-Projekte unverändert. Projekt-/Registerprüfung,
Registererhaltungstests, aktuelle API-/CSS-Exportchecks und drei Rojo-Builds
bestehen. Protokoll des am 11. Oktober begonnenen, am 12. Oktober Ortszeit
abgeschlossenen Laufs: `build/html-full-20261011-twelfth.log`, Hauptbundle
`build/html-tests-17912.luau` (47.103.536 Bytes). Erst danach ist der Hold für
den nächsten Video-Poster-/Größen- und Audio-SOURCE-Fallbackblock aufgehoben.

Beide folgenden begrenzten Blöcke sind inzwischen gezielt und unabhängig
abgenommen: [Video-Poster und natürliche Größen](HTML-PARSER-ATTRIBUTES-20261006.md#video-poster-und-intrinsische-größen--12-oktober-2026)
mit 130 DOM-Fällen/sechs USV-Projektionen und 152 aufgenommenen/28 kontrollierten
Geometrien, 40 Controls/5.490 Assertions; [geordnete Audio-SOURCE-Auswahl](JAVASCRIPT-AUDIO-20261006.md#geordnete-source-kandidaten--12-oktober-2026)
mit 36 SOURCE-/fünf URL-/acht Reihenfolgefällen und acht montierten Eingabemodi/
252 Assertions. Der unabhängige Video-Zehn-Suiten-Lauf und der gemeinsame
14-Suiten-Medienlauf einschließlich isolierter GC-Tails sind Exit 0. Alle
33 geschützten Quellen-/Referenzhashes, beide Medienmanifeste und frühere
Rohdaten bleiben erhalten. Anschließend besteht auch der dreizehnte vollständige
CLI-Prüfstand: tatsächlicher Exit 0, 360 registrierte Suiten samt zwölf isolierten
GC-Prüfungen und den erforderlichen DOM-/Renderer-/Bidi-Prüfpfaden. Nach Laufende
waren 1.669 Quell-/Test-/Fixturedateien und sieben Rojo-Projekte unverändert.
Projekt-/Registerprüfung, aktuelle API-/CSS-Exportchecks und drei Rojo-Builds
bestehen. `build/html-full13-acceptance.json` versiegelt diesen Stand; Protokoll
`build/html-full-20261012-thirteenth.log`, Hauptbundle `build/html-tests-10196.luau`
(48.250.653 Bytes). Die rohe UTF16-Videofixture bleibt unverändert für die CLI;
nur die drei EngineTests-Projekte nehmen sie von Rojo aus.

Nach der dreizehnten Abnahme sind die sieben SOURCE-IDLs und der belegte
ResourceLoadHost-Besitzfehler abgenommen: 49 native SOURCE-Fälle, fünf getrennte
vollständige Frozen-Projektionen/zehn geänderte Zeilen, 24 Besitzerzustände für
sechs geliehene URL-Getter über zwei gleichzeitig lebende Realms und 639 Assertions;
Getter nach Ursprung-Realm-Abbau sind ungeprüft. Namespace-/Brand-/CE-/SameObject-
Pfade bleiben erhalten. Lifetime: neun ursprüngliche/sieben Zusatzkontrollen,
sechs Fehlerwertkontrollen und tatsächlicher no-JS-Poster-Seitenabbau mit 32
Assertions bei `RenderWorkBudgetMS=0` ohne WorkContext; fünf Wrapper sammeln vor gehaltenem Native-Resume, Freigabe genau
einmal und keine Veröffentlichung. Dies ist kein allgemeiner WholePage-/Realm-/
WorkContext-/GPU-GC-Nachweis. Eigenständiger read-only Review und unabhängiger
gemeinsamer 18-Suiten-Lauf samt kompaktem und isoliertem GC-Tail bestehen.
Neun gehaltene Dateien und zwei Manifeste sind unverändert; gegenüber Full13
ändern sich nur vier freigegebene alte Source-/Runnerpfade, 1.665 alte Dateien,
sieben Projekte und drei Provenienztools bleiben erhalten. Log:
`build/source-lifetime-independent-eighteen.log`; kein vierzehnter Gesamtlauf.

Das bestehende Register hält nun zehn teilweise zugeordnete Gruppen mit
50 Einzelanforderungen: 28 erfüllt, sieben offen und 15 ungeprüft. Diese Zahlen
sind kein globaler HTML-Abschlussstand. Nicht zugeordnete übrige responsive
`srcset`-/`sizes`-Algorithmen sind als Erfassungslücken aufgenommen. Alle alten
Kataloggruppen/Belege bleiben erhalten; neue Anforderungen nutzen denselben
datierten HTML-Pin, dessen URL/Revision/Bytes auch der SOURCE-Capture geprüft hat.
Die [initiale Poster-Präsentation](LOADING-PERFORMANCE.md#12-oktober-2026-initiale-poster-präsentation)
ist nun produktiv und gezielt unabhängig geprüft: 52 montierte Fälle über
VideoPlayer/VideoFrame, 162 Präsentationskontrollen und 3.901 Assertions.
Aktuelle Poster-Leases, echte Work4-Pausen in Embedded-SVG-Publikation,
verschachtelte Änderung/Cancel, nil-/false-/Tabellenfehler und beide echten
Runtime-Worker-/Geometrie-Flushpfade dürfen den Root nicht vorzeitig zeigen.
Bei der Promotion blieben die 19 übrigen gehaltenen SOURCE-/Video-/MediaLive-
Dateien bytegleich. Keine normative progressive HTML-Paint- oder Studio-Pixelabnahme.

Der [VM-freie Medienauswahlkern](JAVASCRIPT-AUDIO-20261006.md#vm-freier-auswahlkern-und-audio-reentranz--12-oktober-2026)
liegt ebenfalls produktiv vor: 18 injizierte Reentranzkontrollen/49 Assertions
mit begrenztem Queuebesitz; drei tatsächliche Runtime-/DOM-Open-Kontrollen
erhalten die neueste Auswahl bei veraltetem/nil/spätem Handle. Der unabhängige
17-Suiten-Lauf ist tatsächlicher Exit 0 einschließlich der verpflichtenden
kompakten Ressourcen-/Kernprüfungen und frischen isolierten GC-Tails:
`build/core-poster-independent-seventeen.log`. Der anschließende vierzehnte
Gesamtlauf endet ebenfalls mit tatsächlichem Exit 0: 366 registrierte Suiten,
13 isolierte GC-Prüfpfade sowie die verpflichtenden kompakten DOM-/Ressourcen-/
Kernprüfungen. Danach sind 1.680 Quell-/Test-/Fixturedateien, sieben Projekte
und 63 aktuell gehaltene Dateien unverändert bestätigt. Projekt-/Register-,
API-/CSS-Export- und Dokumentprüfungen sowie drei Rojo-Builds bestehen.
Protokoll: `build/html-full-20261012-fourteenth.log`; Abnahmeartefakt:
`build/html-full14-acceptance.json`. Dies bestätigt den gemeinsam geprüften
Teilstand, keinen globalen HTML-/CSS-/Medienabschluss oder Studio-Pixel/FPS.

Der folgende fünfzehnte vollständige CLI-Lauf bestätigt die gemeinsam
produktive [native Audioauswahl](JAVASCRIPT-AUDIO-20261006.md#audioauswahl-ohne-javascript-realm--12-oktober-2026),
[AudioHost-Freigabe](JAVASCRIPT-AUDIO-20261006.md#audiohost-freigabe-und-neue-ladeversuche--12-oktober-2026)
und [historische Dokumentwahl](HTML-PARSER-ATTRIBUTES-20261006.md#historisches-quellendokument--12-oktober-2026):
tatsächlicher Exit 0, 371 Suiten einschließlich sieben verpflichtender kompakter
und 13 isolierter Prüfpfade. Native37 plus neun historische Montagefälle/
5.145 Assertions, Host23/220 plus kompakt27/282, JS20/67 mit allen 14 archivierten
URLzuständen und Daten-Lifetime9 sind eingeschlossen. Der Loader hat 516
Abhängigkeiten. Quellenprüfung nach dem Lauf bestätigt 1.689 Dateien, sieben
Projekte und 164 gehaltene Artefakte; 1.667 Full14-Altdateien sind unverändert,
13 alte Pfade ausdrücklich freigegeben. Projekt-/Registerabgleiche, enger
unabhängiger Doku-/Registerreview und drei Rojo-Builds bestehen. Nachweise:
`build/html-full15-acceptance.json`, `build/html-full-20261012-fifteenth.log`.
Die historischen Promotions-/Diagnosezahlen stehen vollständig im
[Prüfprotokoll](PROJECT-REVIEW.md); ihre Originale und Rohfixtures sind erhalten.
Die historische Anforderung bleibt offen mit Teilnachweisen; 50 Anforderungen
mit 29/6/15 sind weiterhin nur eine teilweise Zuordnung. Video-SOURCE-Auswahl
und Realm-Besitz werden getrennt als BUILD-Kandidaten vorbereitet. Ganze
Page-/Realm-/WorkContext-/GPU-Sammlung, Codec-/Task-/Video-API und Studioabnahme
sind damit nicht abgeschlossen; GC-Budgets/Erwartungen bleiben unverändert.

Danach ist das begrenzte [Picture-Typangabenprofil](IMAGES.md#typangaben-in-picture-quellen--12-oktober-2026)
produktiv ergänzt: unbekannte `image/`-Angaben werden übersprungen, 27 native
Referenzfälle und 378 tatsächliche Runtime-/RenderTree-Assertions sowie fünf
unveränderte Nachbarsuiten bestehen im unabhängig geprüften Sechssuitenlauf.
Genau ein Quellblock, ein neuer Test/eine Rohfixture und eine additive
Mainrunnerregistrierung ändern den Full15-Stand. Formatdecoder, vollständige
MIME-/responsive Grammatik und Registerstatus bleiben unverändert/offen.

Die Collection-GC-Prüfung läuft
nun im vorhandenen isolierten GC-Prüfpfad mit unverändertem Sentinel/Budget,
zusätzlicher unabhängiger Plain-Object-Kontrolle und beendetem Erzeugungsframe.
Die konkrete Aggregate-Heap-Schwelle verhinderte selbst dessen unabhängige
Sammlung; ein Engine-Map-Retainer wurde nicht nachgewiesen. Dieser unveränderte
isolierte Prüfpfad besteht inzwischen auch im neunten Gesamtlauf; native
Studio-Pixel-/FPS-Abnahme bleibt weiterhin offen. In `QuirksSelectors`
wurde eine veraltete Daten-Append-Annahme korrigiert: OwnerDocument ändert sich
durch tatsächliche DOM-Adoption, nicht durch bloßes Umhängen einer Datentabelle.
Die nativen DOM-Adoptionsfälle bleiben bestehen. Der kalte Loader schließt
sprachabhängige Trennmuster, Case-, Vertical-Orientation- und Emphasis-Daten vom
unbedingten Preload aus.

Die [geordnete Videoauswahl](HTML-PARSER-ATTRIBUTES-20261006.md#geordnete-videoquellen-auf-erhaltenen-backends--12-oktober-2026) ist jetzt produktiv: exact8 Module, 28 Anfangsfälle und 41 Livekontrollen/7.203 Assertions über VideoPlayer/VideoFrame mit/ohne Realm. Unabhängige frische Prüfungen und produktiver 15-Suiten-Lauf Exit 0; `build/video-source-selection-prep/production-promotion.json`. Quellen-/Reset-/Reentranz-/Abbaupfade sind belegt. Dokumentladebarriere vor Rendererregistrierung, Lazy/hidden/detached, vollständiges Video-JavaScript und Studio bleiben offen. Drei bestehende Registeranforderungen erhalten ausschließlich Teilnachweise; 50/29/6/15 bleibt erhalten.


Die [Audioownership zwischen lebenden Realms](JAVASCRIPT-AUDIO-20261006.md#audio-besitz-zwischen-zwei-lebenden-realms--12-oktober-2026)
ist produktiv übernommen: genau fünf geprüfte Quellen, acht Aliase eines
unveränderten Testkörpers und genau zwei präzise kanonische Testkorrekturen.
40 ursprüngliche Kontrollen/192 Assertions plus vier Schedulerfälle/28 Assertions
ergeben 44/220 in acht Modi. Unabhängiger v2-Review ohne Blocker und produktiver
22-Suiten-Lauf bestehen mit tatsächlichem Exit 0. V1 bleibt wegen des Drop(nil)-
Repro historisch BLOCKED; v2 verändert allein den already-settled Guard, und
der unveränderte unabhängige Vier-Fall-Rotkörper ist gegen v2 frisch grün.
Separate physische CandidateHost27/282 und CandidateCore18/49 bestehen unabhängig
auf bytegleichen Modulen; der anschließende Produktionslauf liest die aktuellen
Host/Corebytes im Hauptpfad23/220 und den verpflichtenden kompakten Tails.
Genau eine zusätzlich benötigte AudioState-Testbundlerregistrierung ist separat
geprüft; die vorherige Bundler-Rotprobe bleibt erhalten. Originale ganze
Testdateien/RAW/HOLDs und Dokumententwürfe bleiben archiviert; keine OR-/Skip-Erwartung. Ein kanonischer Zustand und Backendbesitzer B
sind von OriginTasks-/Promise-/ReturnFactories A und Binding A/B getrennt.
EventB und Adoptionsreload sind benannte Chrome-UA-Profile bei getrennten
Frozen-EventA-/Flag-/Triggergrenzen. Explizites Runtime.Destroy modelliert
keine Iframe-Inaktivität. Abnahme: `build/media-cross-realm-audio-candidate-v2-prep/production-source-hold.json`;
Protokoll: `build/audio-production-focused-second-full16.log`. Zehn produktive Dateien,
162 gehaltene Artefakte und 1.674 Full15-Altdateien sind unverändert versiegelt.
Dies ist ein gezielter Produktionsnachweis, kein neuer Gesamtlauf.
VIDEO-/noRealm-Übergänge, zerstörter Ursprung und ganze Realm-/Page-GC bleiben
offen; der bestehende offene Registerpunkt und 50/29/6/15 ändern sich nicht.

## Frühere datierte Nachweise

Die folgenden Etappenergebnisse sind zur Nachvollziehbarkeit erhalten. Ihre
damaligen Reststände und Bestandszahlen sind historische Momentaufnahmen;
für den heutigen Umfang gelten die Fachprofile oben.

- Auftrag vom 8. Oktober: alle zuvor als grundsätzlich umsetzbar eingestuften
  Restpunkte ergänzen. Aktive Pakete und Status stehen im
  [HTML-Parser-/Attributprofil](HTML-PARSER-ATTRIBUTES-20261006.md#beauftragter-ausbau-vom-8-oktober-2026)
  und [CSS-Atelier-Profil](CSS-ATELIER-20261007.md#beauftragter-ausbau-vom-8-oktober-2026).
  H01 Details-Gruppen und verzögerte ToggleEvents sind umgesetzt; alter
  Details-Teilumfang korrigiert. C01 ergänzt Sprachfilter/Dokumentsprachen,
  Variable-Tokenisierung und Bereichs-/Defaultselektoren mit aktuellen
  Formular-/Auswahlzuständen; montierte Änderungen bleiben bei reinen Farben
  Paint ohne Layout. H06 umfasst Modusabhängigkeit der ID-/Klassenabfragen,
  lebende Listen, Adoption, gezielte CSS-Invalidierung, bare Hover-/Active-Regeln
  und alte eigenschaftsgebundene Längen/Farben. 18 native Mausabläufe und 690
  Deklarations-/Supports-Proben bestehen, einschließlich Variablen, CSSOM und
  Keyframes; dokumentierte Chromium-Abweichungen bleiben in den Rohdaten.
  Horizontale Prozent-/Root-/Bodygrößen und zugehörige intrinsische Bildproben
  sind ergänzt: 399 native Szenen, Resize-/Mutationsfolgen und 7.659 Boxvergleiche mit
  behaltenen GUIs. Gemeinsame Korrekturen betreffen Prozentminimum/-maximum,
  leere Randketten und eingeschlossene verschachtelte Floats. Dokumentierte
  Chromium-Grenzen bleiben erhalten. Historische Struts und direkt leere/aus
  kollabierenden Textleerzeichen bestehende Inlineelemente, echte Nullschrift-
  Paintunterdrückung, Fragmenthintergründe samt Ellipsis/Leerzeichen, Zellhöhen,
  automatische Zellbreiten, nowrap-/Bildminima und UA-Tabellenstyles sind ergänzt.
  Tabellenfarben wechseln mit der Bodyfarbe ohne Layout/GUI-Ersatz. Das leere
  Tabellenprofil folgt ausdrücklich Chromium, nicht pauschal WHATWG 3.10.
  Dimensionshints samt CSS-Rollback, Gruppenhöhen/-boxen und leere Gruppen
  sind ergänzt; das nowrap-Hintprofil folgt ausdrücklich Chromium. 15 Breiten-
  und 24 Höhenwechsel behalten GUIs; 18 Hintergrundfarb-/Alphawechsel malen
  ohne Layout/Allokation. Tabellenhintergrundquellen behalten ihre Flächen.
  Inline-CSSOM-Geometrie liest behaltene Fragmente/Quellspannen; 57 native
  Szenen und 462 wiederholte Abfragen bestehen ohne Layout/GUI-Allokation.
  Body-Offset- und Nullhöhen-Bounding-Unterschiede sind explizit dokumentiert;
  nichtzero native Fontboxen und Shadow-/Spalten-/vertikale Kombinationen
  sind dadurch nicht pauschal nachgewiesen.
  Weitere Attribut-/Tabellenkombinationen, tiefe/Whitespace-Inlinebäume und
  vertikale Quirks bleiben offen; [Layoutnachweis](HTML-PARSER-ATTRIBUTES-20261006.md#prozenthöhen-und-dokumentgrößen--9-oktober-2026),
  [Tabellenprofil](HTML-PARSER-ATTRIBUTES-20261006.md#historische-tabellen--9-oktober-2026),
  [Grammatiknachweis](HTML-PARSER-ATTRIBUTES-20261006.md#alte-css-werte--9-oktober-2026).
  C02 ergänzt Medienabfragen: Komponenten-Tokenisierung, Listenfehlerkorrektur,
  dreiwertige Logik, zusätzliche Merkmale und gemeinsame CSS-/CSSOM-/JS-Pfade.
  864 native Ergebnisse/800 Serialisierungen bestehen; 28 normative Zusatzwerte
  und nicht unterstützte Chromium-Features sind explizit gekennzeichnet.
  Der echte Seiten-Worker verwendet die vorhandene Paint-/Layoutklassifikation:
  Medien-Farbwechsel ohne BlockLayout, Größenwechsel mit Layout, Queryereignisse
  auch nach übersprungenem Layout und abgetrennte Hostsignale. Das Scripting-
  Merkmal berücksichtigt JavaScript=false. Keine zusätzlichen Frame-Treiber.
  Weitere Container-/Anchorachsen und Custom Media bleiben offen;
  [Medienprofil](CSS-ATELIER-20261007.md#medienabfragen--9-oktober-2026).
  Containerqueries ergänzen logische Achsen, Schrift-/Viewport-/Variablenmaße,
  Style-Abfragen eigener/registrierter Variablen und stabile Scrollzustände.
  588 Größen-, 360 Style- und 3.060 Scrollresultate sind erhalten; 44/6/170
  Standardabweichungen separat benannt. Montierte Änderungen und der echte
  Scroll-Worker behalten GUIs und vermeiden Layout bei reinen Farben.
  Snapshotindizes, relative vs. absolute Scrollpfade, Lade-/Abbaugrenzen und
  keine zusätzlichen Frame-Treiber sind geprüft. Normale Eigenschaften in
  Stylequeries, weitere Einheiten-/Snap-/Eingabekombinationen, Custom Media und
  weitere Anchorachsen bleiben offen; [Containerprofil](CSS-ATELIER-20261007.md#containerabfragen--9-oktober-2026).
  Anschließend ergänzt C02 Ankergröße/-Mathe/-Fallback, akzeptable Namenswahl,
  Scope einschließlich display:contents und benannte/gespiegelte Position-Try-
  Alternativen samt CSSOM. Order-/Shorthand-/Insets-Overflowauswahl sowie
  absolute RTL-/vertikale Insets/Margins sind anschließend ergänzt.
  288 native Szenen, 3.660 Geometriewerte, 30 behaltene Änderungen,
  60 Supports- und 45 CSSOM-Werte bestehen. 15 Geometrie-/ein
  Syntaxunterschied zu Chromium sind einzeln begründet; Rohdaten erhalten.
  Montierte Regel-/Größenwechsel behalten GUIs/Stilobjekte; reine Farben lösen
  kein Layout aus. Area-/Origin-/Scroll-/Transform-/Inline-/Shadow-/Recording-
  Kombinationen bleiben offen; [Ankerprofil](CSS-ATELIER-20261007.md#ankerpositionierung--9-oktober-2026).
  Gesamtstand mit 288 Engine-Suiten, letzten spezifischen Nachprüfungen,
  14 JS-Geometriefällen, Register-/Projekt-/Loaderprüfung, strukturellem
  Review und Rojo-Build bestätigt. Katalog: 535 Eigenschaften/114 Elemente;
  Runtime-Register: 5.016 Deskriptoren. C02 insgesamt weiter in Arbeit.
  `DocumentLanguage`, `QuirksSelectors`, `FormSelectors`, `ScriptTransforms`
  und `JavaScriptCSSOMRendering` belegen diese Pfade. Übriger C01-Umfang
  noch offen. C09 führt projizierte Szenentreffer zu den ursprünglichen
  Nachfahren; Grenzen eigener 3D-Eingabe bleiben dokumentiert. Aktuelle
  Nachweise: `Details`, `DetailsGroups`, `Selectors`, `CSSAtelierCore`,
  `ProjectiveHit`, `ThreeDTransforms`. C07-Math-/Unparsed-/Variablenobjekte
  sind ergänzt; auch Transformwerte, numerisches Parsing und SameObject-Maps.
  `JavaScriptTypedMath`, `JavaScriptTypedTransforms` und `JavaScriptTypedOM`
  belegen den Umfang; weitere Math-/Color-/Reifizierungsfälle bleiben offen.
  H02 umfasst dynamische tiefe Select-Momentaufnahmen und montierte Rich-
  Inhalte einschließlich nativem Controller ohne JavaScript; `SelectTree`
  vereinheitlicht die normativen DOM-Grenzen. Formatierte Pickeroptionen verwenden
  jetzt eigene behaltene Renderfragmente mit Abbruch-/Reentranzschutz.
  Formatierte Legends, ursprüngliche Optgroup-Vererbung, gemessene Popuphöhe
  beim Refresh und asynchrone native Bild-/Fontanbindung sind ergänzt und
  gegen Schließen, Quellwechsel und späte Rückmeldungen geprüft.
  Standardbreite, feste/inhaltsabhängige Selectmaße, gewöhnliche Dropdown-/
  Listenwechsel und Inline-Controlgeometrie sind inzwischen ergänzt. Customizable-
  Pseudoelemente im Rich-Dropdown/eigenen Picker sind inzwischen ergänzt;
  drei Chromium-Sequenzen sowie echte Popup-Paint-/Ressourcenprüfungen bestehen.
  Unterdrückte Optionsbilder werden auch bei verbundenem DOM abgemeldet.
  Base-Dropdowns ohne ersten Button und Rich-Darstellungswechsel bleiben offen,
  siehe [FORMS](FORMS.md#rich-select-und-selectedcontent--8-oktober-2026).
  H04 ergänzt alle WHATWG-Decoder sowie einen ausdrücklich aktivierten HTML-
  Bytequellenpfad mit BOM/Transport/Meta-Erkennung, maximal einem Neustart und
  tatsächlichen Encoding-Properties. Umfang, native Referenzabweichungen und
  noch fehlende H03-Streaminganbindung stehen im
  [Text-/Datenprofil](JAVASCRIPT-TEXT-DATA-20261005.md#byte-decoder-und-html-zeichencodierung--9-oktober-2026).
  Beim Paketreview wurde eine doppelte Stilregistrierung für normale Controls
  entfernt; Größenveränderungen einer Textarea brauchen beim Fokus erneut
  kein Layout. Die montierten Atelier-/Rich-Select-/Textarea-Regressionen bestehen.
  Weitere Pakete weiter abarbeiten.

- Gemeinsame Formularvalidierung und Pickerzustände vom 9. Oktober:
  [FORMS](FORMS.md#gemeinsame-validierung-und-geöffnete-picker--9-oktober-2026)
  hält Kandidaten/rohe Flags, UnicodeSets-Patterns ohne Seitenskripte, atomare
  Radiogruppen, `:open`, behaltene Pickerupdates und native Runtime-Budgets fest.
  54 neue Chromium-Sequenzen und gemountete Paint-/Identitätstests bestehen;
  dies schließt nicht alle H05-/C01-Kombinationen oder native Studiooptik ab.

- Bytebude-Nachtmodus: Radio-Innenfläche war fest weiß. Sie wird jetzt retained
  aus `color-scheme` gezeichnet; automatischer dunkler Akzent, Hover/Pressed,
  deaktivierte Controls und `appearance:none` sind berücksichtigt. Reine
  Themen-/Scrollbar-Farbänderungen brauchen kein Layout. [FORMS](FORMS.md#hell-dunkelmodus-nativer-controls--8-oktober-2026).
  Textmarkierung kollabiert beim Klick auf freie Seitenflächen, Text und native
  Text-/Datumseingaben; Browserausnahmen und `preventDefault()` bleiben erhalten.
  [R04](JAVASCRIPT-INPUT-R04.md#nachweise) hält Umfang und angenäherte freie
  Caretposition fest. Montierte Controller-/Painttests und Chromium-Referenz
  in `tests/fixtures/native-control-theme-selection.json`; Studiooptik bei Tobias.

- Bytebude-Reiter: einfache Controls respektieren jetzt `border-bottom:0`
  mit dem gemeinsamen BorderBox; die Leiste liefert die einzelne Abschlusslinie.
  CSS-Buttons bekommen keine pauschale 3-px-Rundung mehr; explizite Radien,
  einzelne Ecken und Origin-/Layer-Rollback bleiben berücksichtigt.
  Uniformer UIStroke und Control-/TextBoxidentität bleiben erhalten, getrennte
  Rahmenflächen werden bei Stilwechsel/Entfernung aufgeräumt.
  Umfang und Grenzen: [FORMS](FORMS.md#css-rahmen-und-button-ecken--8-oktober-2026).
  19 verschiedene Engine-Suiten bestanden; Chromium-Seam-/Radiusvergleich,
  Projektprüfung und Rojo-Build ebenfalls bestanden. Studiooptik bei Tobias.

- Bytebude-Umfrage: Größenproben schrieben bisher `(0, 0)` auf die sichtbare
  rechte Gridspalte und überdeckten während Layoutpausen die linken Karten.
  Gemeinsamer `LayoutProbe` hält Block-/Bildoberflächen bis zur tatsächlichen
  Platzierung am behaltenen Ursprung; Grid/Flex/Masonry, absolute und atomare
  Inline-Messungen verwenden ihn. Budgetierung bleibt aktiv. Bytebude bei drei
  Breiten einschließlich nativer Messpausen und unabhängiger Voll-Layoutparität,
  weitere Layoutbesitzer und Abbruch in `LayoutProbeRendering` geprüft.
  Nachweis/Prüfgrenzen: [DIRTY-LAYOUT](DIRTY-LAYOUT.md). Studiooptik bei Tobias.

- Bytebude ersetzt die sichtbare CSS-Testseite auf Wunsch vom 8. Oktober 2026.
  Browser: `http://localhost:8000/bytebude/index.html`; Studio startet `Bytebude`.
  Eigenes Retroportal mit Standard-HTML/CSS/JavaScript, lokaler Pixelillustration,
  wirklichen Spielelinks, Reitern, Tag-/Nachtmodus, Umfrage und lokalem Gästebuch
  mit höchstens 12 eigenen Grüßen. Quellen und Speicherverhalten: [WEBSITES](WEBSITES.md).
  Alle 14 CSS-Atelier-Dateien samt Font/Lizenz unverändert in
  `tests/fixtures/css-atelier` erhalten und per Prüfsumme abgeglichen;
  die vier generierten Website-Module wurden entfernt. Keine Enginefunktion
  zurückgenommen; bestehende CSS-/SVG-Regressionen lesen das Archiv.
  Sechs betroffene Engine-Suiten sowie anschließende Prüfung der erhaltenen
  Gästebuchidentität bestanden. Chromium: je 17 Bedien-/Speicher-/Layoutchecks
  bei Desktop- und 390-px-Ansicht; Screenshots geprüft. SVG-Funktionssuite,
  Generator und Projektprüfung bestanden; Studiooptik/FPS weiter bei Tobias.

- [Lokale Farbänderungen und Ladepfade](LOADING-PERFORMANCE.md): CSSAtelier-
  Variablen-/Text-Batches begrenzen die Kaskade; Pseudostyles werden außerhalb
  betroffener Elemente wiederverwendet und unbeteiligte SVG-CSS-Scans entfallen.
  Vollständige Counter-/Quote-Reihenfolge bleibt erhalten. Die beiden realen
  Farbcallbacks benötigen im CLI-Test 12/6 statt 2.213/4.420 Pseudoprüfungen;
  native Ruckelfreiheit ist noch nicht bestätigt. Gezielte Regressionen und
  funktionale SVG-Prüfung sind im verlinkten Profil dokumentiert.

- [CSS Atelier](CSS-ATELIER-20261007.md) bleibt als archivierter Browser-/Roblox-Vergleich erhalten:
  `tests/fixtures/css-atelier`, 35 Beispiele für die neun
  CSS-Abgleichsbereiche. Standard-HTML/CSS/JavaScript, lokale Ressourcen, variable
  Roboto-Schrift mit Original-Lizenz, echte API-/Syntaxanzeigen. Ergänzte
  Kaskaden-/Selektor-/Query-/Einheiten-/Text-/Farb-/Bild-/Timeline-/Anchor-/APIpfade
  im verlinkten Fachprofil; 531 CSS-Namen. Die damalige Demo `CSSAtelier` lief
  ohne die bisherige 480-Pixel-Grenze. Gesamtes CSS bleibt nicht abgeschlossen;
  native Fonts/Snapshots/Worklet-Host und umsetzbare Restfälle getrennt dokumentiert.
  Korrektur vom 8. Oktober: native/JS-Änderungen an `details.open` aktualisieren
  Inhalt und `[open]`/`:open`-CSS einschließlich verwandter Selektoren. Blaue
  Details-Karte, Rücksetzung, Observer, retained Eingaben und Layout-Queue in
  gezielten Mockprüfungen belegt; Details-Namensgruppen/Toggle-Tasks weiter offen.
  Details-Aufklappen und äußerer Shadow-Themenwechsel begrenzen die Kaskade
  konservativ: 29/34 gewöhnliche Styles statt je 791; Theme ohne Layout oder
  Stylesheet-Neusammlung. Klassen-Batchwerte, relationale Fallbacks, unabhängige
  Vollkaskadenvergleiche, Slot-Neuverteilung und behaltene Ownership geprüft;
  Messwerte und Prüfgrenzen im Ladeprofil. Keine Garantie aller Kombinationen.
  Query-Kartenbild: zyklische Bildbreiten begrenzen jetzt den intrinsischen
  Grid-Beitrag; gesetzte Längen-/Prozentachsen werden nicht durch Stretch überschrieben.
  Native Browserreferenz bei 423 px: zwei 181,5-px-Spalten. Elf Grid-Bildfälle
  und neun echte Reglerwechsel mit behaltenen Flächen geprüft; Fachprofil oben.
  Produktkarten: Zeilen-Subgrid misst neue Inhaltsbeiträge statt alter gestreckter
  Höhen; Rahmen/Innenabstände und unterschiedliche Gutters werden eingepasst.
  Chromium-Geometrien, verschachtelte Zeilen, Resize/Rücknahme und tatsächliche
  Karten-/Stapelgeometrie geprüft. Vollständiges Subgrid bleibt ein Teilprofil.
  Weitere Korrekturen: HTML-SVG-Bildpixel durchlaufen Filter → Clip → Maske mit
  retained Effektfläche und unveränderten Layoutmaßen. Mischmodi verändern keine
  computed Farben; budgetierte Gruppen verrechnen überlappende Flächen an ihren
  Paintpositionen. Beide Kreise, vier Modi/Alpha, Isolation, Rücknahme, schnelle
  Wechsel und Resize gegen Chromium geprüft. Raster-/Native-Pixelgrenzen sind im
  Fachprofil und in [Darstellungsgrenzen](CSS-VISUAL-LIMITS.md) ausdrücklich offen.
  Die leere Flip-Karte war ein zusammengefasster Buttoncaption: Elementkinder
  behalten jetzt eigene Boxen samt 3D-Seiten; Control/disabled-Verhalten bleiben
  erhalten. Einfache Captionbuttons bleiben beim bisherigen Pfad; ihre spätere
  Promotion und vollständige UA-Formatierung sind keine abgeschlossenen Fälle.
  CSS/WAAPI-`accumulate` ergänzt Identitäten und verrechnet Funktionen/Matrixreste
  statt ungleiche Listen wie `add` anzuhängen. 30 Chromium-Referenzsätze plus beide
  Laufzeitpfade und wiederholtes Kartenwenden geprüft; native Studioansicht offen.

- [Parser-/Attributpaket vom 6. Oktober](HTML-PARSER-ATTRIBUTES-20261006.md):
  Tree-Builder und gemeinsame DOM-Kontextfragmente; 1.508 Dokument-/59 Fragmentfälle
  und 257 Suiten bestanden. [Attributregister](html-attributes.v1.json): 277 Gruppen,
  separate Nachweisachsen und ausdrücklich offene Wirkungs-/Darstellungsfälle.
- [Gesamtcode-/Pfadreview vom 6. Oktober](audit-2026-10-06/README.md): alle 455
  Engine-Module strukturell, kritische Ausführungspfade zusätzlich semantisch
  geprüft. Sichere Kürzungen/Allokationsoptimierungen sowie direkter Node-Klonfix;
  257 Suiten und anschließend sechs gezielte HitTest-/Form-/Layout-/Spiel-Suiten
  bestanden. Projekt-/Dokument-/Generator-/APIprüfungen und Rojo-Build bestanden;
  native JIT-/FPS-/Pixeldarstellung nicht neu geprüft.
- [Vollständiger datierter CSS-Referenzbestand](CSS-GAPS-20261006.md) und
  [einziges aktives CSS-Register](css-features.v1.json): 5.008 Standarddefinitionen/
  Kontexte plus 37 zusätzliche Engine-Registrierungen. Registrierung, konkrete
  Compilerproben, SVG-Pfade und APIpräsenz unterscheiden; ungeprüfte Semantik bleibt
  offen. Bedarf-/Hostgrenzen sind eigene Kategorien. Generator und Belegcheck
  erhalten diese Trennung; native FPS übernimmt Tobias.
- Aktuelle Websites: Main/Spielraum, Memory und Hangman mit getrennten Browser-
  und generierten HTML-/CSS-/JavaScript-Modulen. Frühere Testseiten sind
  Regressionstestdaten in `tests/fixtures/retired-websites.json`.
- Der angeforderte Formularvergleich ist zusätzlich als `InputTypes` vorhanden und
  über den Website-Katalog erreichbar. [Eingabetypenprofil](HTML-INPUT-TYPES-20261006.md):
  fünf Datum-/Zeittypen mit Pickern, Bild-Submitter, Dateifeld nur Darstellung;
  Dateiauswahl bewusst später. 254 Engine-Suiten bestanden vor den abschließenden
  Reviewänderungen. Danach zehn gezielte Suiten, Projektprüfung, fünf Generator-
  Tests, API-Registerprüfung und Rojo-Build bestanden; native Darstellung/FPS
  bleiben offen. Browserreferenz: `http://localhost:8000/input-types/index.html`.
- `StudioDemoConfig` enthält nur die Demoauswahl. `local WEBSITE` im
  HTMLPage-LocalScript ist die einzige Startwebsite-Auswahl; Anleitung in
  [README](../README.md) und [WEBSITES](WEBSITES.md).
- JavaScript P01–P17 bezeichnet erreichte, dokumentierte Teilprofile.
  Bestand/Grenzen: [IMPLEMENTATION](JAVASCRIPT-IMPLEMENTATION.md).
  Weitere R-Familien: [ROADMAP](JAVASCRIPT-ROADMAP.md). Keine Browservollständigkeit behaupten.
- Das [Audioprofil vom 6. Oktober](JAVASCRIPT-AUDIO-20261006.md) verbindet
  Standard-HTML-/JavaScript-Audio mit dem nativen Soundhost. Memory lädt die
  angeforderte Musik `117006292434032` per Audioquelle/Optionszuordnung,
  mit Loop und Lautstärke 0,35. Native hörbare Wiedergabe/Assetrechte bleiben offen.
- Bildfehler, Ladebudgets, retained Layout/DOM und Lifecycle besitzen eigene
  Fachprofile und Regressionen. Native FPS und Sichtvergleiche übernimmt Tobias.

## Bekannte Dokumentationsgrenzen

Die alten HTML-/CSS-Abschlusslisten wurden für frühere Roblox-Profile geschrieben.
Registrierung, akzeptierte Attribute und erreichbare Methoden dürfen nicht als
vollständige Browsersemantik bewertet werden. Für HTML-Attribute fehlt noch ein
vollständiger, einzeln belegter Abgleich. `script` als alter `parser-only`-Status
und frühe fehlende DOM-/Shadow-/Custom-Element-Angaben sind nicht der heutige
JavaScript-Bestand. [HTML-COMPLETION](HTML-COMPLETION.md) und
[CSS-COMPLETION](CSS-COMPLETION.md) ordnen den Folgeabgleich ein.

Die [Dokumentladebarriere für bereits registrierte Videos](HTML-PARSER-ATTRIBUTES-20261006.md#dokumentladebarriere-für-videos--12-oktober-2026) ist nun
eng produktiv abgenommen: drei Quellen, ursprüngliche 38/4595 plus unabhängige vier
ohne Fehler und additive 17/1707, insgesamt 59. Unabhängige acht Suiten,
physischer Core18/49 und der produktive 17-Suiten-Lauf haben tatsächlichen
Exit 0; build/video-load-barrier-v2-prep/production-source-hold.json.
V1 bleibt BLOCKED/c724 und seine Rotprobe bleibt unverändert; V2 bewahrt neuere
Auswahl und Besitzerstop an vier synchronen Benachrichtigungsgrenzen und
stoppt weitere Add-Batch-Initialisierung. Loaded/IsLoaded ist nur der
kontrollierte Datenproxy; synchrone Metadaten/erste Decoderframes bleiben
getrennt. Die folgende Pre-render-v2-Abnahme ergänzt die geprüfte Work4-Grenze vor
Rendererregistrierung. Lazy/hidden/detached, noRealm-Dokument/Iframe, volle
VIDEO-JS-API und allgemeines Page-/Realm-GC bleiben getrennte Grenzen.
Die bestehende Medienanforderung bleibt offen; 277/10/50/29-6-15 unverändert. Dieser gezielte Nachtrag enthält
keinen weiteren Gesamt- oder Studioabschluss.

Die [produktive Medien-Fallbackkorrektur](HTML-PARSER-ATTRIBUTES-20261006.md#versteckte-medien-fallbackinhalte--12-oktober-2026)
hat einen positiven unabhängigen Kandidatenreview949fa34b und tatsächlichen
Root14 Exit0. Exakt Source5 und bestehender strikt korrigierter Full41 sind
übernommen;30 montierte Fälle bleiben unverändert. Produktionshold30948919
versiegelt29 aktuelle/317 historische Pins sowie1673 unveränderte Full15-Dateien;
Loader518/134ed165. Der statische Kopierreview b1d5ef2b bestätigt Source5/Test5, Full41-/Runner-/Loader-Inversen und 661 weitere unveränderte Pins, ohne Blocker oder zusätzlichen Engine-Lauf. Ursprünglicher b001-
Testkörper und native Referenzen bleiben erhalten; nur dessen dokumentierter
Reject/Childcount-Ausdruck ist normativ korrigiert. AREA/TopLayer-/Shadow-Gesamt-
semantik, universelle Cascadekosten, Decoder/Studio und Page-/Realm-GC bleiben
separat offen. Registerstatus und Zählstände unverändert lassen.

Die [Video-Ladebarriere vor Rendererregistrierung](HTML-PARSER-ATTRIBUTES-20261006.md#dokumentladebarriere-vor-der-video-rendererregistrierung--12-oktober-2026) ist mit
Owner-v2 produktiv übernommen: Source2, drei neue Tests und ein eng
additiver Captureloader/Runner. Die ursprünglichen 24/2.697 und 21/1.136
bleiben bytegleich, 28/2.673 additive Receiver-/Teardownkontrollen ergeben
73/6.506. Unabhängiger Reviewa91dc1a8 und produktiver 19-Suiten-Lauf jeweils
tatsächlicher Exit 0, mit unverändertem verpflichtendem Core18/49.
Produktionshold dfa46efe versiegelt32 aktuelle/450 historische Pins,
1.673 unveränderte Full15-Dateien und sieben Projekte; Main2aacd7b7,
Loader518/134ed165. Der vorherige Pre-render-v1 bleibt im Bericht bc32cdc2
BLOCKED; die unveränderte zusätzliche Receiverrotprobe1fa121 ist unter v2
grün. Korrekte Einzelzähler belegen V1 Player1/Frame2 statt je1; die
anfängliche neue Gesamtpauseerwartung1 bleibt nur eine Harnessdiagnose.

Knotenreservierung vor realem Work4, atomarer1→1-Transfer und gemeinsamer
Owner für retained Facade/current API verhindern vorzeitiges load und
spätes Wiederbeleben. Verschachtelter Abbau erfolgt einmal und erhält
ursprüngliche nil-/false-/table-Fehler. Die nativen neun Fälle/21 Zustände
bleiben unverändert; früherer Enginecancel nach Ownerentfernung ist eine
engere Besitzpolicy als der Browser. Renderer-decline/detached/hidden,
Lazy, nativer erster Frame/Studio, vollständige Video-API, ForcedGeometry
und allgemeines Page-/Realm-GC bleiben getrennt offen. Keine neue
Gesamtprüfung oder Registerstatusschließung daraus ableiten.

Der begrenzte [NoRealm-Medien-/Iframe-Nachweis](HTML-PARSER-ATTRIBUTES-20261006.md#dokumentladebarriere-ohne-engine-vm--12-oktober-2026) ist nach Source4/Test2-
Promotion produktiv. Eigener, unabhängiger9f16fe36 und anschließender
produktiver14er haben tatsächlichenExit0; Produktionshold f542af4e
schützt36 aktuelle/505 historischePins und siebenProjekte,1671 alte
Full15-Dateien unverändert bei18 explizitenaltenLifts. Main05206704,
Loader518134ed165. Original10fffcc660 bleibt ganz
erhalten: tatsächliche Baseline21Faults/1301Checks, jetzt0Faults/1319Checks;
33 additive Fälle/3071Assertions. Source4-HOLD662e27d0 schützt die neuen
Bytes; alte Owner-v2-73/6506 und Video59/Core18/49 bleiben ungeschwächt.
Page.IsDocumentComplete ist gelatcht/queued/rechecked und mit Realm weiterhin
delegiert. Native AUDIO, rendererbasierte VIDEO, Poster und aktuelle Frames
wachen echte Pages ohne VM auf; ScriptInitialization/Strings/Once bleiben
getrennt von atomarer Präsentation. Kein versteckter Realm oder globaler
ResourceLoadHost-Requestzähler. Fünf Browserfälle/elf Rohsnapshots/48 Kontrollen
zeigen gesperrte Kindskripte, keine browserseitige Abwesenheit von Window/VM.
Die tatsächliche Work4-Visit-Kontrolle nutzt bestehendes NativeLoading/Pending,
keine neue spekulative Bootstraplease. EagerIMG, contentDocument/contentWindow-
Fassaden und der konkret fehlende VM-iframe.src-Reload bleiben getrennt
umsetzbar offen, ebenso ForcedGeometry. Keine allgemeine NoRealm-/HTML-Load-,
Decoder-, Lazy-, Studio- oder Page-/Realm-GC-Schließung behaupten.

Die erste Video-JavaScript-Version V1 lag ausschließlich als BUILD-Kandidat vor. Ihr [unabhängiger Review](../build/video-javascript-api-implementation-prep/independent-final-review.json) bleibt historisch BLOCKED: trotz grünem17/kompakter Fassadenprüfung waren alle zwölf Player-/Frame-/Remove-/Destroy-Fälle mit nil-/false-/table-Rückmeldungen rot. V1-HOLD da4d9b58 und sämtliche Rotbelege bleiben erhalten; V1 wurde nicht produktiv übernommen.

Die getrennte V2 ist nach [unabhängiger begrenzter Abnahme fe7fa301](../build/video-javascript-api-implementation-prep/independent-v2-final-review.json) exakt produktiv: Source7/Test7, Root22 einschließlich verpflichtender compact12 tatsächlicherExit0. Bindings21/31, Mounted18/1374, exakter Remove12-Körper ohne Fehler, Reentry2/153 und kompakt6+3/45+3/19. Nur VideoState/MediaRuntime unterscheiden sich von V1; independent19/compact12 und1616 unveränderte Pins/siebenSourceIDs/753Inputs. [Produktionshold fe425c21](../build/video-javascript-api-implementation-prep/production-v2-source-hold.json), Main4fc5b436, Loader521/6d893f4b. Alte Slots/native Ressourcen werden vor Subscriber-Reentry abgebaut, alle Rückmeldungen laufen vor dem ersten Originalfehler weiter.

Details stehen im [Video-JavaScript-Nachweis](HTML-PARSER-ATTRIBUTES-20261006.md#gemeinsame-video-javascript-bindungen--12-oktober-2026). Acht fehlende IDLs, detached Transport, Video-Realm-Besitz, Decoder/Studio, vollständige Taskordnung und wholeGC bleiben offen. Der separate NativeIMG-Teilnachweis ist unten produktiv ergänzt. Der [IFrame-Attribut-Teilnachweis](HTML-PARSER-ATTRIBUTES-20261006.md#lebende-iframe-attribute-und-aktuelle-kindnavigation--12-oktober-2026) ist nach unabhängigem Review10fd662a exakt produktiv: Source2/Test40/Rohfixture18, Root13 actualExit0 einschließlich zwölf Nachbarn. Der bytegleiche0769477a-Körper40/4060 belegt captured setterbase, same-value reload, srcdoc priority, next-nav sandbox, retained fragmentlease und ChildC vor queued/held ParentB. [Produktionshold67a7d577](../build/iframe-attribute-navigation-native-img-rebase-prep/production-source-hold.json) hält55 aktuelle/998 historische Pins, sieben Projekte und1668 Full15-Altdateien; Mainb0038e38 mit einer Registrierung/inverse44c149, Loader522a48fed unverändert. Native18/44+separate2/8, Frozen invalid/ancestor-Abweichungen und HTTPB/C versus frühem Enginecancel bleiben getrennt. PageLoading besitzt exakt einen Mocksetup-Hook bei unveränderten Assertions/Whole-Original-Inverse8688 und ist auch in Root13 grün. PublicWindow/Document, detached/lazy, volle Sandbox/History, nativepixels/GC und weitere Lifecycle-/Bulk-Close-Semantik bleiben offen. Der separate produktive [Remove-/Destroy-Teilnachweis](HTML-PARSER-ATTRIBUTES-20261006.md#iframe-remove-destroy-batches--12-oktober-2026) Source1a0ad/Test3 hat Original10/215+nested6/136+actualHTMLPage/VM6/487=22/838. Nach unabhängigem Review6cb2b079 und exakter Promotion besteht Root15 mit tatsächlichem Exit0; [Hold2c0adf40](../build/iframe-lifecycle-frame2-rebase-prep/production-source-hold.json) hält58 aktuelle/1035 historische Pins, sieben Projekte und1668 Full15-Altdateien. Main9a93931c besitzt drei Registrierungen/inverseb0038e38, Loader522a48fed bleibt erhalten; alter BUILD-HOLD0efff290 und Autor15 bleiben historisch. Er nimmt alle alten Batchslots vor Rückmeldungen heraus, schließt gefangene alte Kinder und bewahrt neue Items/Owner; der erste Originalfehler folgt nach allem Cleanup. Drei Produktions-Rotbelege bleiben erhalten. Unveränderte Nachbarn sind im Root15 belegt; Einzelkind-Ersetzung/unavailable sind im aktuellen [Nachtrag](IFRAMES.md#iframe-einzelkind-cleanup-und-getrennte-coroutine-kontexte--12-oktober-2026) begrenzt belegt; andere Callbacksemantik und allgemeines GC bleiben getrennt offen. Kein neuer breiter Projektabschluss. Kein neuer globaler Abschluss.

Gewöhnliche eager-Bilder ohne Runtime hatten im bisherigen produktiven NoRealm-Stand noch keinen passenden nativen Dokumentladeflag. Dieser Ausgangsbefund bleibt historisch erhalten; der getrennte [NativeIMG-Nachweis](HTML-PARSER-ATTRIBUTES-20261006.md#eager-bildanforderungen-ohne-engine-vm--12-oktober-2026) ist jetzt nach Reviewd162f16f exakt produktiv: Source3/Test2, Root12 actualExit0, Mounted22/986+Owner24/218 und alte NoRealm current10/1330+33/3112 mit acht ungeschwächten Nachbarsuiten. [Hold3f22968c](../build/no-realm-image-load-author-v1-prep/production-source-hold.json) hält52 aktuelle/916 historische Pins und sieben Projekte; Main44c149/Loader522a48fed sowie1669 Full15-Altdateien sind belegt. Native HTTP7/15/117 und die strenge display:none-Harnessinverse bleiben getrennt. Enabled-JavaScript/lazy, automatische bare-DOM-Notification/Removal-/Adoptionssemantik, native Pixel/Decoder und ganze Page-/Realm-GC bleiben offen. Kein neuer globaler Abschluss; spätere Ressourcen öffnen die gelatchte Dokumentfertigstellung nicht erneut.

## Letzte datierte Nachweise

Die Audio-Etappe meldet 253 bestandene Engine-Suiten, Projektprüfung,
API-Registerprüfung und Rojo-Build; die anschließende Memory-Musikänderung zwei
bestandene Memory-Suiten sowie Projektprüfung/Build. Diese Angaben sind
Ergebnisse der jeweiligen Etappen, kein bei jedem Lesen erneut ausgeführter Test.
Einzelheiten, Befunde und Logpfade stehen in der archivierten Übergabe und im
[Audioprofil](JAVASCRIPT-AUDIO-20261006.md). Generierte Logs unter `build/`
sind lokale Belege und können fehlen; dauerhafte Umfangsangaben gehören in die Fachprofile.

## Neuordnung der Dokumentation

README enthält Bedienung, PLAN Arbeitsregeln, ARCHITECTURE Modulverantwortung,
der Index sämtliche Fachbereiche und das Dokumentregister Dateizuständigkeiten.
Historische Sammeltexte und Checklisten bleiben über den
[Sicherungsnachweis](history/2026-10-06/README.md) erreichbar.
Der Enginecode wird bei dieser Neuordnung nicht geändert.
Sicherung und unveränderter Quellbestand sind per Prüfsumme bestätigt;
Dokumentations-, Projekt- und API-Registerprüfungen bestehen. Die genaue
Abgrenzung und die historischen fehlenden Verweise stehen beim Sicherungsnachweis.

## Übergabe pflegen

Hier nur aktiven Einstieg, letzte wesentliche Änderung und konkrete Blocker
aktualisieren. Funktionsdetails am zuständigen Fachprofil pflegen und verlinken.
Vor dem Ersetzen wesentlicher Übergabeinformationen einen datierten Nachweis
bewahren. Alte Abschnitte nicht erneut als aktuelle Aufgaben oder Freigaben anfügen.
