# JavaScript Roadmap

> Maßgeblicher JavaScript-Ausbauplan P/R; der Ist-Bestand steht in [IMPLEMENTATION](JAVASCRIPT-IMPLEMENTATION.md), gemeinsame Arbeitsregeln in [PLAN](../PLAN.md). Frühere Labor-/Demoabschnitte bleiben Historie; aktuelle Websites führt [WEBSITES](WEBSITES.md).

Stand: 16. Oktober 2026. Diese Datei ist die zentrale Roadmap für die JavaScript-Sprache, ihre Standardbibliothek und die damit verbundenen DOM- und Browser-APIs unserer Roblox-Engine. Neu ist das begrenzte R14-Profil für einfache JavaScript-Dialoge und hostgesteuerten Dokumentlebenszyklus. Frühere Atelier-/Vergleichsseiten bleiben historische Regressionen; aktuelle Vergleichsseiten führt [WEBSITES](WEBSITES.md). Tobias hat die gezeigten Studio-Fälle von Vergleich 07 nach den Script-/Worker-Hostkorrekturen bestätigt. Solche Bestätigungen beziehen sich auf die gezeigten Fälle und sind keine vollständige ECMAScript-Konformitätsprüfung.

Der Ausbau soll gewöhnlichen Browsercode unverändert nutzbar machen. Bestehende DOM-Identität, Eingaben, Animationen, Resize-Verhalten und lokale Layoutaktualisierungen bleiben Anforderungen jeder Etappe. Tobias hat den eigenständigen Ausbau bis P17 und automatische Tests ausdrücklich beauftragt. Nach jedem größeren Paket wird der gesamte JavaScript-Code samt Layout-/Rendering-/Inputanbindungen erneut geprüft. Die visuelle Vergleichsseite darf mehrere Funktionen verständlich kombinieren. Die frühere Regel ohne eigene Tests ist aufgehoben; den nativen Sichtvergleich kann Tobias ergänzen.

## Umfang und Status

„Alle“ bedeutet für diese Roadmap: die gesamte ECMAScript-Sprache und Standardbibliothek als Ausbauziel, die Browsergrundlage für Websites und ein ausdrücklich erfasstes Reservoir weiterer Web-APIs. Eine Aufzählung einzelner Beispiele begrenzt das Ziel einer Familie nicht: Bei einer fertiggestellten Familie müssen auch ihre übrigen standardisierten Methoden, Eigenschaften, Prototypen, Fehlerfälle und Wechselwirkungen erfasst sein.

Die Webplattform entwickelt sich weiter. Ihr kompletter Methoden- und Eigenschaftskatalog wird durch die jeweils verlinkten Standards bestimmt. Diese Datei gruppiert ihn in umsetzbare Pakete; sie behauptet weder, jeden Browserhersteller-Zusatz aufzulisten, noch, dass jede Geräte-API innerhalb von Roblox vollständig nachgebaut werden kann. HTML-/CSS-Darstellung besitzt zusätzliche eigene Roadmaps. Hier stehen die JavaScript-Zugriffe darauf.

| Status | Bedeutung |
| --- | --- |
| Vorhanden | Im Code erreichbar, innerhalb der daneben genannten Grenzen |
| Teilweise | Ein Teil einer Standardfamilie ist vorhanden; die Familie ist noch offen |
| Offen | Noch nicht in der gemeinsamen HTML-JavaScript-Laufzeit implementiert |
| Plattform klären | Benötigt eine Hostentscheidung oder eine Prüfung der verfügbaren Roblox-Funktionen |
| Nutzer bestätigt | Tobias hat die konkrete Vergleichsetappe akzeptiert; kein Anspruch auf vollständige Standardkonformität |

Die folgenden Ausbaupakete sind geplant. Der eigenständige Auftrag erlaubt Implementierung und automatische Prüfung ohne Zwischenbestätigung. Ein Paket wird erst als abgeschlossen geführt, wenn sein dokumentierter Umfang implementiert und geprüft ist; eine visuelle Nutzerbestätigung wird zusätzlich separat erfasst. Den aktuellen Code- und Prüfstand einschließlich offener Grenzen hält [JAVASCRIPT-IMPLEMENTATION.md](JAVASCRIPT-IMPLEMENTATION.md) fest. Die offenen Checklisten beschreiben den vollständigen Zielumfang der Familien. Es gibt keine belastbare Gesamtprozentzahl und noch keine Terminzusage.

## Aktueller Implementierungsstand

Die aktuelle Inventur, zuständige Dateien, tatsächlichen Prüfungen und offenen Hostgrenzen stehen in [JAVASCRIPT-IMPLEMENTATION.md](JAVASCRIPT-IMPLEMENTATION.md). Die frühere Bestandsaufnahme vom Beginn der Arbeit wurde ersetzt, damit inzwischen implementierte Funktionen nicht weiter als fehlend erscheinen.

Der am 5. Oktober beauftragte priorisierte Durchlauf ist in
[Browser-Grundlagen](JAVASCRIPT-FOUNDATIONS-20261005.md) dokumentiert:
vorhandene DOM-/Layoutkombinationen, Nesting/CSSOM und wichtige Animationsfälle,
Skript-/Bild-/Fontladen, Unicode/URL/Date/Intl sowie Prüfung der Speicheranbindung.
Die [Atelier-Seite](http://localhost:8000/browser-foundations/index.html)
verwendet diese Erweiterungen gemeinsam. Der Durchlauf ergänzt dokumentierte
Teile von R05/R06, R07/R08 und R13/R16; er ersetzt nicht den vollständigen
R00–R20-Restplan. Tatsächliche neue Roblox-Assetrechte und dauerhafte
DataStore-Wiederherstellung bleiben getrennte Hostnachweise.

Nach dem bestätigten Vergleich 05 wurde die in Vergleich 06 eingeführte gemeinsame Dialog-/Popoverintegration korrigiert. Der weitere Ausbau erreicht den Dedicated-Worker-Unterbau von P17. Die kompakte [Vergleichsseite 07](http://localhost:8000/javascript-tests/index.html?review=20261003-workers#scripts) zeigt dynamische Skripte (P13), ListFormat (P15), Path2D (P16), klassische/Modul-Worker (P17) und die Dialogkorrekturen. Frühere Vergleichsetappen bleiben eingefrorene Regressionen. 45 relevante Testgruppen und die zusätzlichen nativen Referenzen bestehen; nach den Script-/Worker-Hostkorrekturen bestehen 13 relevante Gruppen erneut. Tobias hat die gezeigten Studio-Fälle bestätigt. Die folgenden offenen Checklisten beschreiben den vollen Zielumfang; die implementierten Profile schließen nicht sämtliche Unterfamilien von P01–P17 ab.

## Folgeplan R00–R20: offene Teile von P01–P17 abschließen

Planstand: 4. Oktober 2026. Diese Etappen ergänzen die ursprünglichen Pakete und
beginnen beim tatsächlich vorhandenen [Implementierungsstand](JAVASCRIPT-IMPLEMENTATION.md).
Bereits vorhandene Tabellen, Komponenten, Pointer-Capture, CSSOM, Animationen,
Web Storage und Dedicated Worker werden vervollständigt, nicht erneut gebaut.
Der autorisierte Durchlauf R00–R04 wurde implementiert und überprüft. Der
API-Bestand und die nachgewiesenen Grenzen stehen im [Register](JAVASCRIPT-API-REGISTER.md).
P18 bleibt eine getrennte Erweiterungsreserve.

Das Ziel ist unveränderter Browserquelltext mit möglichst gleicher Semantik und
Darstellung. Eine Familie bleibt teilweise implementiert, solange standardisierte
Teile fehlen. Eine nachgewiesene Plattformgrenze ist ein eigener Status und keine
fertige Implementierung. Eine unbegrenzte Gleichheit mit sämtlichen Browsern wird
aus einer einzelnen Vergleichsseite nicht abgeleitet.

### Reihenfolge, Umfang und Abschlussnachweise

R00–R04 besitzen einen implementierten und geprüften Erweiterungsstand.
Der neue Durchlauf ergänzt die unten verlinkten Profile von R05/R06, R07/R08
und R13/R16. Offene Konformitätsfälle und übrige Familien bleiben geplant.
Die Voraussetzungen beziehen sich auf die
neuen Lücken; der vorhandene Unterbau bleibt nutzbar. Größere Etappen werden in
kleine, prüfbare Änderungen geteilt. Noch offene Randfälle werden im Register
weitergeführt und beim zuständigen Paket bearbeitet.

| Durchlauf | Nachweis und verbleibende Grenze |
| --- | --- |
| R00 | [API-Register](JAVASCRIPT-API-REGISTER.md) und [Hostmatrix](JAVASCRIPT-HOST-CAPABILITIES.md); tatsächliche Studio-/Live-Permissions und Persistenz müssen noch bestätigt werden. |
| R01 | [Gemeinsames Objektmodell](JAVASCRIPT-R01-CORE.md), native Core-/Radixreferenzen und Realm-Tests; weitere Test262-/Annex-B-/Bibliotheksfamilien bleiben offen. |
| R02 | [Dokumente und DOM-Interfaces](JAVASCRIPT-DOCUMENTS-R02.md), Adoption, Collections und montierte Tabellen; kein vollständiger HTML-Tree-Builder/XML-Prozessor. |
| R03 | [Formkomponenten und Registries](JAVASCRIPT-COMPONENTS.md), native Cross-Realm-/Lifecycle-/Formreferenzen und echte Paintwirkung; die dort dokumentierten Grenzen bleiben offen. |
| R04 | [Auswahl und Eingaben](JAVASCRIPT-INPUT-R04.md), 25 native Auswahlreferenzen und montierte Editor-/Pointerfälle; vollständiges gemischtes Bidi, Editing und OS-IME bleiben offen. |
| R05/R06 · 5. Oktober | [Nesting und Animationssemantik](JAVASCRIPT-CSS-ANIMATIONS-20261005.md), echte CSSOM-/Paintwirkung, Umkehr, Easing und Layoutprofile; übrige Grammatik-/Property-/Timelinefälle bleiben offen. |
| R07/R08 · 5. Oktober | [Unicode, URLs, Date und Intl](JAVASCRIPT-TEXT-DATA-20261005.md), versionierte normative Daten und native Referenzen; übrige URL-/Locale-/Kalender-/Zeitzonenfamilien bleiben offen. |
| R13/R16 · 5. Oktober | [Skript-, Bild- und Fontladen](JAVASCRIPT-LOADING-20261005.md), Lifecycle, Metadaten, Promises und native Hostanbindung; Streamingparser, allgemeiner Transport, Webfontdecoder und übrige Medienfamilien bleiben offen. |
| R16 · 6. Oktober | [JavaScript-Audio](JAVASCRIPT-AUDIO-20261006.md): Audio-Konstruktor, Play-Promises, Zeit/Rate/Lautstärke, Lade-/Fehlerereignisse, gemeinsame Sound-Instanz mit Controls und Lebensdauer. Die übrige Video-/Track-/Streaming- und Web-Audio-Oberfläche bleibt offen. |
| R16 · 16. Oktober | [VIDEO-/Poster-Lazy](MEDIA.md#verzögertes-video-posterladen--16-oktober-2026): Loading-Reflexion, getrennte Fortsetzungen, native Besitzer und Loadbarrieren mit/ohne Realm. Vollständige Medien-, Clip-/Intersection- und Studioabnahme bleiben offen. |
| R14 · 15. Oktober | [Einfache Dialoge und Dokumentlebenszyklus](JAVASCRIPT-IMPLEMENTATION.md#dialoge-und-dokumentlebenszyklus--15-oktober-2026): synchrone `alert/confirm/prompt`, optionaler UI-Host, Abbruch/Abbau, schreibgeschützte Document-Sichtbarkeit, `pageshow/pagehide/visibilitychange/unload` und aktivierungsabhängiges `beforeunload` mit optionaler Bestätigung. BFCache, vollständige Sandbox-/Frame-/Navigation-/Receiverfälle, Scheduling/Idle und weitere R14-Ziele bleiben offen; native Sichtabnahme steht getrennt aus. |
| R14 · Idleprofil, 15. Oktober | [Kooperative Idle-Callbacks](JAVASCRIPT-IMPLEMENTATION.md#kooperative-idle-callbacks--15-oktober-2026): `requestIdleCallback/cancelIdleCallback`, `IdleDeadline`, positives Timeoutrennen, Abbruch/Abbau und vorhandener Tasktreiber. Standardbudget höchstens 1 ms, optionaler Hostbudgethinweis, höchstens 50 ms; dies beweist keine native Compositor-/Frame-Idle-Garantie. Vollständige Host-/Cross-Realm-Kriterien bleiben offen. |
| R14 · 18. Oktober | [Priorisierte Aufgaben](JAVASCRIPT-IMPLEMENTATION.md#priorisierte-aufgaben--18-oktober-2026): `scheduler.postTask/yield`, dynamische TaskController-/TaskSignal-Prioritäten, Abbruch, Delay und Promise-/Await-Kontext im bestehenden EventLoop und WorkerRealm. Native Frame-/Agentprioritäten und vollständige Cross-Realm-Konformität bleiben offen. |
| R10 · 18. Oktober | [Asynchrones XMLHttpRequest](JAVASCRIPT-IMPLEMENTATION.md#asynchrones-xmlhttprequest--18-oktober-2026): gepufferte Antworten, Zustände, Header, Antworttypen, Timeout/Abbruch und Upload-/Downloadereignisse mit echten Runtime-/Workerpfaden. Synchrones XHR, Live-Netzwerkprogress und weitere Transport-/Encoding-/IDL-Fälle bleiben offen. Eine normative Zählererwartung weicht ausdrücklich von der rohen Chrome-155-Referenz ab. |
| R12 · 18. Oktober | [Web Locks im Hostspeicher](JAVASCRIPT-IMPLEMENTATION.md#web-locks-im-hostspeicher--18-oktober-2026): explizit geteilter Store mit Partition-/Origintrennung, FIFO shared/exclusive, ifAvailable/steal/Abort, Snapshots und ownerbezogenem Abbau zwischen tatsächlichen Realms und montierten Tabs. Getrennte Actor-Worker brauchen weiterhin IPC; vollständige Storage-/SecureContext-Policy, übrige Koordination und Persistenz bleiben offen. |

Die neue [Vergleichsseite 10](http://localhost:8000/browser-foundations/index.html)
enthält fünf kombinierte Werkstücke. [Vergleich 09](http://localhost:8000/javascript-tests/index.html?r04=20261004-ready)
und die früheren Etappen bleiben Regressionen. Ein implementierter Durchlauf ist keine pauschale Konformitätszusage
für jede Standardunterfamilie seiner Etappen.

| Etappe | Zu ergänzen | Voraussetzung | Konkreter Abschlussnachweis |
| --- | --- | --- | --- |
| R00 Bestand und Hostfähigkeiten | Versioniertes API-/Statusregister mit Methoden, Properties, Konstruktoren, Prototypen, Events, Modul, Referenzstandard, Grenzen und Tests. Standardfassung und Browserversion festhalten. Roblox-Fähigkeiten für HTTP/Streaming, binäre Daten, Persistenz, Fonts, Medien, IME, GPU, Shared Memory und GC früh prüfen. Den tatsächlichen DataStore-Persistenzfall noch bestätigen. | Aktueller Bestand | Jeder bekannte Restpunkt ist einer Etappe zugeordnet; Hostbeschränkungen haben einen belegten Grund und einen möglichen Adapterweg. Verfügbarkeit in Studio und im veröffentlichten Spiel wird getrennt erfasst. |
| R01 Sprache und gemeinsames Objektmodell | Frühe Syntaxfehler, ASI/Strict/Annex-B-Abgrenzung, globale var-/lexikalische Bindungen, gewöhnliches/striktes this und Primitive-Boxing; Konvertierungs-/Deskriptor-/Prototyp-/Cross-Realm-Randfälle von Klassen, Proxy, Reflect, Generatoren, Promises, Iteratoren, Binärdaten und Bibliothek. Nichtdezimale Zahlenausgabe und weitere bekannte Bibliothekslücken. Gemeinsame Web-IDL-Receiver-, Konvertierungs- und Brandregeln. | R00 | Gewählte Test262-Fälle und DOM-Konvertierungsfälle stimmen mit der Referenz überein; Hostobjekte funktionieren auch bei geänderten globalen Konstruktoren und Prototypen. Weitere im Register gefundene Methoden bleiben explizit zugeordnet. |
| R02 DOM, Dokumente und Tabellen | HTML-Interfaceprototypen und Attributreflexion vervollständigen; Adoption zwischen Dokumenten, Collection-Namensenumeration, Dokumentmutation, XML-/Quirks-Unterschiede. Dynamische Tabellenkombinationen mit colgroup, Abschnitten, Spans, Parserkorrekturen und erhaltenen Eingaben überprüfen und offene Fälle ergänzen. | R01 | Einfügen, Verschieben, Löschen, Clone und Adoption behalten die richtige Identität, Sammlungen, Fokus und Formularzustände; Tabellen reagieren korrekt auf schmale Breiten. |
| R03 Shadow DOM und Custom Elements | Verbleibende Upgrade-/Adoption-/Lifecycle-Fälle, ElementInternals und formularassoziierte Komponenten, Formwert/Validierung/Reset/State-Restore; scoped Registries nach festgehaltenem Standard-/Browserprofil. Geschachtelte Slots, Stylesheets und Auswahlgrenzen an den bestehenden Shadow-Unterbau anschließen. | R02 | Eine echte Formkomponente mit verschachteltem Shadow DOM kann eingefügt, verschoben, deaktiviert, validiert, zurückgesetzt und zwischen Dokumenten übernommen werden. Reaktionen und Event-Retargeting stimmen. |
| R04 Eingaben, Auswahl und Editing | Shadow-/Control-Auswahl, getComposedRanges bzw. tatsächlich unterstützte Auswahl-APIs, Auswahl-Scrolling, Selection.modify/Editing/Bidi; Pointer-Capture-Verlust bei Abbau, Multi-Touch und Scroll-/Defaultaktionen vervollständigen. Native IME-Zwischenstände und OS-Dateiauswahl nur über nachweislich verfügbare Hostsignale anbinden. | R02/R03; Hostprüfung R00 | Auswahl und Drag funktionieren nach Resize, Scroll und DOM-Mutation sowie außerhalb des ursprünglichen Ziels; native Paintposition wird geprüft, nicht nur ein geänderter Style-String. Für nicht verfügbare IME-Signale bleibt die Grenze sichtbar. |
| R05 CSSOM, CSS-Grammatik und erzeugter Inhalt | Restliche Regel-/Descriptor-/Wertegrammatik, CSS-Nesting, Registrierung und Invalidierung; @import an R09 anschließen. Dynamische ::before/::after/::marker, Counterbereiche und Attribut-/Klassen-/Stylesheetkombinationen einschließlich Shadow DOM vervollständigen. Print-/Font-Palette-Wirkung getrennt vom vorhandenen CSSOM-Regelobjekt bewerten. | R02/R03; Importladen nach R09 | Regeländerungen zeigen echte Style-/Layout-/Paintwirkung; verschachtelte Regeln, ungültige Werte und entfernte Blätter haben browsergerechte Ergebnisse. Keine Regel wird wegen eines vorhandenen API-Objekts als vollständig gerendert geführt. |
| R06 Animationen und Layout | Verbleibende animierbare Properties und Werttypen, diskrete Übergänge, auto/intrinsische Größen nach gewähltem Standardprofil, Inlinefragmente und Pseudoelement-Ziele; add/accumulate/commitStyles und Effektordnung vervollständigen. Transition-/Animationereignisse, Timing, Unterbrechung/Umkehr sowie Scroll-/View-Timelines und View Transitions einzeln erfassen. | R04/R05 | Gleichzeitige Größen-, Text-, Transform- und Shadow-Änderungen bleiben nach Resize, Pause, Commit, Cancel und Entfernen korrekt. Ereignisreihenfolge und tatsächliche Boxen stimmen; Paint-Effekte verursachen kein Layout. |
| R07 Unicode, URLs und Dateien | String.normalize mit NFC/NFD/NFKC/NFKD, Unicode-/RegExp-Randfälle, vollständige URL-/IDNA-/IPv4-/IPv6-Kanonisierung und Originbildung; fehlende standardisierte Decoder und Fehler-/Streamzustände. Blob/File/Object-URL-Lebensdauer und Ressourcenintegration vervollständigen. | R01 | Unicode- und URL-Testdaten stimmen; ungültige Eingaben, Surrogate, Chunkgrenzen, widerrufene URLs und Transfers besitzen definierte Ergebnisse. Dateiwerte bleiben von OS-Dateiauswahl getrennt. |
| R08 Date und Intl | Zeitzonen-/Sommerzeitdaten und Date-Randfälle; übrige NumberFormat-/Locale-Optionen. Collator, DateTimeFormat, PluralRules, RelativeTimeFormat, DisplayNames, Segmenter und DurationFormat samt supportedLocalesOf, Parts/Range-Funktionen soweit spezifiziert. Sprach-/Kalender-/Zahlen-/Zeitzonendaten versionieren und schrittweise erweitern. Temporal nur nach separater Aufnahmeentscheidung für den festgelegten Standardstand. | R07 | Mehrere Locales, DST-Wechsel, mehrdeutige Zeiten, Emoji-/Wortsegmentierung und Fehlerfälle stimmen mit dokumentierter Datenversion überein. Ein en/de-Profil gilt weiterhin nicht als vollständige Intl-Familie. |
| R09 Gemeinsamer Ressourcenloader und HTTP-Fetch | Ein Loader für fetch, HTML, CSS/@import, Skripte/Module, Worker, Bilder, Fonts und Medien. URLbase/Origin, Servertransport, Request/Response, Status, Redirects, Abbruch, Binärdaten, Streaming, MIME, Lade-/Fehlerereignisse, CORS/Preflight, Credentials/Cookies und HTTP-Cache zusammen festlegen. Roblox-Transport und Browserregeln bleiben getrennte Schichten. | R00/R01/R07 | Derselbe lokale Referenzserver liefert in Browser und Engine gleiche erlaubte Antworten und sichtbare Fehler. Verbotene Origins, Redirects, Abbruch, Seitenwechsel und geschlossene Realms bleiben korrekt; rein gepufferte Antwortkörper werden nicht als echtes Streaming geführt. |
| R10 Weitere Transporte und Stream-Codecs | XMLHttpRequest mit Zuständen, Response-Typen, Upload/Download-Progress, Timeout und Abort; EventSource mit Parser, Last-Event-ID und Wiederverbindung; WebSocket mit Text/Binärnachrichten, Zuständen, bufferedAmount und Close-/Fehlersemantik. CompressionStream/DecompressionStream, sendBeacon und verbliebene Streamrandfälle. | R09; verfügbare Hostadapter aus R00 | Echte Transportfälle prüfen Nachrichtengrenzen, Fehler, Abbruch und Aufräumen. Synchrones XHR und direkt beobachtbares Streaming werden nur geführt, wenn der Ausführungs-/Transportweg ihre Semantik tatsächlich ermöglicht. |
| R11 IndexedDB und dauerhafter Zustand | Bestehenden Web-Storage-Host um Reload-/Navigation-/Mehrdokument-/Quota-/Fehlerfälle vervollständigen. IndexedDB mit versionierten Datenbanken, Object Stores, Schlüsseln/KeyRanges, Indizes, Cursor, StructuredClone, Requests, Transaktionen, Rollback, Auto-Commit, Upgrade/blocked/versionchange und dauerhaftem Host. | R01/R07; Storage-Host | Abbruch oder Speicherfehler hinterlassen keine halben Transaktionen. Gleichzeitige Verbindungen, Upgrade und Wiederherstellung nach neuer Sitzung stimmen; eine Map mit asynchronen Methoden genügt nicht als IndexedDB. |
| R12 Cache API und Koordination | CacheStorage/Cache mit Request-/Response-Kopien, add/addAll/put/match/matchAll/keys/delete, Matchingoptionen, Vary, Bodyzuständen, atomaren Fehlern, Quoten und Persistenz. Web Locks und weitere im P12-Register erfasste Origin-Koordination. HTTP-Cache, Cache API und Web Storage besitzen getrennte Zuständigkeiten. | R09/R11 | Antworten sind nach erneutem Öffnen abrufbar; konsumierte Bodies, Vary, Abbruch und gleichzeitige Realms verhalten sich korrekt. Offline-Wiederherstellung funktioniert ohne versteckte Verbindung zum Original-Response. |
| R13 HTML-Parser, Skripte und Module | Schrittweises Parsen/Tokenisieren, parserblockierende Skripte, Stylesheetabhängigkeiten, async/defer und Microtask-/DOMContentLoaded-/load-Reihenfolge; document.open/write/writeln/close einschließlich reentrantem Parser. Zyklisches Top-Level-Await mit Fehler-/Ablehnungspropagation; übrige MIME/CORS/Importmap/Attribute/CSP/SRI-Regeln über den Loader. | R02/R05/R09 | Ein Skript mitten im Dokument sieht nur den zu diesem Zeitpunkt geparsten Bestand. Nachladen, Fehler, Parser-Reentry und async Modulgraphen stimmen mit der Referenz; Resize und DOM-Abgleich führen gestartete Skripte weiterhin nicht erneut aus. |
| R14 Navigation, Lifecycle und Scheduling | Location/History-Randfälle, URL-/Hash-/Scrollzustände, load/pageshow/pagehide/visibilitychange und nachvollziehbare navigator-/screen-Daten. Hintergrund-/Cross-Realm-Scheduling, requestIdleCallback und Scheduler-APIs nach Referenzprofil; zusätzliche echte Performance-Einträge und Diagnose statt erfundener Messwerte. | R09/R13; vorhandener EventLoop | Navigation während Timer, Fetch, Observer und Animation räumt den alten Realm auf. Microtasks, Tasks und rAF behalten die richtige Reihenfolge; Sichtbarkeit und Idle geben reale Hostzustände wieder. |
| R15 Canvas und SVG | Restliche Canvas-2D-Methoden einschließlich roundRect/isPointInStroke, Text-/Bild-/Pixeloperationen, Compositing, Farbräume und Reset-/Detach-Zustände; SVG-DOM, animierte Werte, Live-Listen, Geometrie/CTM und Ereignisgrenzen vervollständigen. Rasterqualität, projektive Clips und Fragmentierung mit dem Renderer abgleichen. | R04/R06/R07 | Gemeinsame Browserquellen erzeugen geometrisch und visuell passende Ergebnisse bei Resize, Transformation, Ressourcenwechsel und Mutation. Rastertoleranzen und Unterschiede bleiben benannt. |
| R16 Bild-, Font- und Medienladen | Image/naturalWidth/naturalHeight/complete/decode, Quellen-/srcset-Wechsel, ImageBitmap und Blob-Quellen; FontFace/document.fonts samt Ladezuständen und Layoutinvalidierung. HTMLMediaElement play/pause/load, Zeit/Rate/Lautstärke, Tracks, Ready-/Networkstates und Ereignisse; verfügbare Codec-/Autoplay-/Fullscreen-Pfade konkret zuordnen. | R09/R15; Hostfähigkeiten | Laden, Fehler, Abbruch, Quellenwechsel und Entfernen geben richtige Promises/Events. Ein geladener Font aktualisiert nur echte Metrikabhängigkeiten; Medienzustände entsprechen dem tatsächlich abgespielten Medium. |
| R17 Worker und MessagePorts | MessagePort-Transfer über Actor-/Workergrenzen mit Ownership und Queuezuständen; verschachtelte Worker, SharedWorker nach Origin/URL/Name, gemeinsame Verbindungen und Lebensdauer. Worker-fetch und externe/Blob-/Data-Quellen samt MIME/CORS/Credentials; importScripts ohne Blockieren der Seiten-VM. | R01/R07/R09/R13 | Ports behalten wartende Nachrichten nach Transfer, verlieren den Senderzugriff und räumen korrekt auf. Verschachtelte Worker und mehrere Clients eines SharedWorkers teilen nur die vorgesehenen Ressourcen. |
| R18 OffscreenCanvas und GPU-/Audiobrücken | transferControlToOffscreen, OffscreenCanvas, Workerbesitz/Transfer, Bitmappräsentation und Lebensdauer; vorhandene WebGL-/WebGPU-Teilpfade an den gemeinsamen HTML-Realm anschließen und ihre fehlenden Methoden, Shader-/Ressourcen-/Lost-Zustände erfassen. Web Audio als eigenes Hostprofil. | R15/R16/R17; GPU-/Audioentscheidung R00 | Echte Worker-Canvas-Fälle, Transferfehler und Ressourcenabbau funktionieren. CPU-Rasterisierung wird nicht als native GPU-Ausführung bezeichnet; nicht verfügbare Shader-, Codec- oder Audiogarantien bleiben als Grenze geführt. |
| R19 Service Worker, Shared Memory und GC | Service-Worker-Registrierung/Scope/Update/install/activate/controller, Clients, Fetchinterception, respondWith/waitUntil und Neustart über den originbezogenen Host. SharedArrayBuffer/Atomics/Wait/Notify/WaitAsync sowie WeakRef/FinalizationRegistry und Weak-Collection-Ephemeronsemantik als getrennte Unteretappen mit Hostnachweis. | R09/R11/R12/R13/R17; Plattformentscheidung R00 | Offline-Fetch, Workerwechsel und Suspend/Resume funktionieren im dokumentierten Browserhost. Shared Memory benötigt ein tatsächliches Agent-/Speichermodell; Finalizer benötigen echte GC-/Jobgarantien. Ohne diese Nachweise bleibt der jeweilige Punkt offen bzw. hostbegrenzt. |
| R20 Gesamtabschluss und Vergleich | Register gegen implementierte Exporte und Referenzkataloge abgleichen, übrige Randfälle den Familien zuordnen und beheben; alle neuen Kombinationen zusammen prüfen, Dokumentation aktualisieren und kompakte Abschlussseite erstellen. | Alle umgesetzten Etappen | Kein unbegründeter Eintrag „fertig“, keine verschwundenen offenen Punkte. Funktionale Ergebnisse, echte Darstellung, native Studio-Befunde und Plattformgrenzen sind getrennt belegt. |

Die bevorzugte Arbeitsfolge ist R00–R20. R18 benötigt den in R17
vervollständigten Worker-Transfer. R05 und R06 werden
nach der Ressourcenintegration gezielt auf Import-/Font-/Medienkombinationen
erneut geprüft. Datenarbeit in R07/R08 und Hostproben aus R00 können unabhängig
von DOM-Erweiterungen stattfinden; dafür ist keine zusätzliche Agentnutzung
vorausgesetzt.

### Gemeinsame Architekturentscheidungen

- Bestehende VM, Ereignisschleife, DOM-Identität, Renderer und Dirty-Tree bleiben
  der gemeinsame Unterbau. APIs bekommen keinen eigenen dauerhaften Frame-Loop.
- Ressourcen laden über R09; Origins, Credentials und Storagepartitionen werden
  konsistent behandelt. Antworten des Roblox-Servers verleihen dem Websitecode
  keine Roblox-Dienstrechte.
- IndexedDB braucht echte Transaktionszustände und einen passenden persistenten
  Host. DataStore-Namen oder mehrere unabhängig gespeicherte Schlüssel allein
  garantieren keine atomare Datenbanktransaktion.
- Neue Codefamilien erhalten eigene Module und reale Budgets. Fortsetzungen,
  Ports, Bilder, Fonts, Medien und Datenbanken besitzen einen klaren Besitzer und
  werden beim Abbau freigegeben.
- GPU, IME, synchrone Netzwerkwege, Shared Memory und Finalizer werden bereits
  in R00 untersucht. Spätere Etappen liefern die belegte Umsetzung oder die
  konkrete verbleibende Grenze; wirkungslose API-Stubs sind kein Abschluss.

HTTP-RequestAsync und WebStreamClient sind dokumentierte Roblox-Ansatzpunkte;
ihre Nutzbarkeit, Rechte und Transportgarantien werden im konkreten Zielhost
geprüft. Daraus folgt noch keine fertige Fetch-/WebSocket-Implementierung.
Quellen: [Roblox HttpService](https://create.roblox.com/docs/reference/engine/classes/HttpService),
[WebStreamClient](https://create.roblox.com/docs/reference/engine/classes/WebStreamClient),
[Fetch](https://fetch.spec.whatwg.org/), [XMLHttpRequest](https://xhr.spec.whatwg.org/)
und [WebSockets](https://websockets.spec.whatwg.org/).

### Prüfung und Review nach jeder größeren Etappe

1. Methoden-/Propertyumfang, Fehler, Deskriptoren, Konvertierungsreihenfolge und
   Ereignis-/Jobreihenfolge anhand des versionierten Standards erfassen. Geeignete
   Test262-/Web-Platform-Testfälle und vorhandene gemeinsame Fixtures verwenden.
2. Dieselben HTML-/CSS-/JavaScriptquellen im Browser und in der gemeinsamen
   Engine ausführen. Tatsächliche GUI-/Paint-/Layoutwerte prüfen; eine richtige
   JavaScript-Rückgabe allein belegt keine richtige Darstellung.
3. Kombinationen aus Resize, Scroll, Animation, Textumbruch, Formularzustand,
   Shadow DOM, Einfügen/Entfernen, Navigation, Abbruch und Worker-Transfer prüfen.
   Fokus, Eingabewerte, DOM- und GUI-Identität müssen erhalten bleiben.
4. Nach jedem größeren Paket den gesamten JavaScript-Code und die zugehörigen
   DOM-/Layout-/Rendering-/Input-/Hostanbindungen reviewen. Neue Befunde beheben,
   danach die betroffenen und gemeinsamen Regressionen ausführen; unveränderte
   erfolgreiche Tests werden ohne Anlass nicht ständig wiederholt.
5. Leistung über strukturelle Assertions schützen: identische Werte erzeugen
   keinen Job, Paintänderungen kein Layout, DOM-Writes werden gebündelt, echte
   Geometrieabhängigkeiten lokal invalidiert und alte Realms vollständig gelöst.
   FPS-Benchmarks übernimmt weiterhin Tobias.
6. APIregister, Profilgrenzen und Nachweise aktualisieren. Ein Paketabschluss
   und Tobias' native visuelle Bestätigung werden getrennt gespeichert.

Normative Grundlagen für die jeweilige Etappe:
[ECMAScript](https://tc39.es/ecma262/), [Web IDL](https://webidl.spec.whatwg.org/),
[DOM](https://dom.spec.whatwg.org/), [HTML](https://html.spec.whatwg.org/multipage/),
[URL](https://url.spec.whatwg.org/), [ECMA-402](https://tc39.es/ecma402/),
[IndexedDB](https://www.w3.org/TR/IndexedDB-3/),
[Web Animations](https://drafts.csswg.org/web-animations-1/) und
[Service Worker/Cache](https://w3c.github.io/ServiceWorker/).

### Kompakte visuelle Abschlussseite

Das aktive Labor zeigt jeweils die neu abgeschlossene Vergleichsetappe; ältere
Fälle bleiben eingefrorene Regressionen außerhalb der aktiven Karten. Am Ende
entsteht eine kurze Übersicht mit getrennt anwählbaren Bereichen. Damit müssen
nicht alle Funktionen auf einer langen Seite gesucht werden.

- Komponenten und Eingaben: Shadow-Formular in dynamischer Tabelle, Auswahl,
  Drag und Multi-Touch; native IME-Grenzen sichtbar kennzeichnen.
- CSS und Animation: dynamische Regeln, Counter, Pseudoelemente, Layoutanimation,
  Resize sowie Pause/Commit/Cancel in einem Objekt.
- Laden und Module: Fetch, Abbruch, Status und Fehler zusammen mit Modulladen
  und parserabhängiger Reihenfolge.
- Speicherung und Offline: vorhandene Notiz plus IndexedDB-Transaktion,
  Reload-/Upgradefall und Cache-Wiederherstellung.
- Sprache und Intl: Suche/Sortierung, Unicode, Datums-/Zeitzonenwechsel und
  Format-/Parts-Ergebnisse mit erwarteter Ausgabe.
- Grafik und Medien: Canvas/SVG, tatsächliche Bild-/Fontladezustände und
  Mediensteuerung; Offscreen-/GPU-Fälle nur soweit implementiert.
- Worker: Porttransfer, getrennte Arbeit, gemeinsame Clients und kontrolliertes
  Beenden; Service-Worker-/Shared-Memory-Fälle nur mit belegtem Host.

Jeder Fall hat eine sichtbare erwartete Wirkung, aktuellen Ergebniszustand,
Fehleranzeige und Reset. Quellen bleiben zwischen Browser und Roblox identisch.
Die Seite startet keine endlosen Lastgeneratoren. Verbleibende Plattformgrenzen
stehen beim betroffenen Fall und im Register.

## Ausbaupakete in empfohlener Reihenfolge

Die Reihenfolge ist unser Umsetzungsvorschlag. Sprachfunktionen hängen von ihrem Objekt-/Iteratorunterbau ab; neue Browser-APIs müssen an die vorhandene Ereignisschleife und den Dirty-Tree angeschlossen werden. Große Pakete werden in kleine Vergleichsetappen geteilt.

| Paket | Ziel | Voraussetzung | Geplanter Nutzen |
| --- | --- | --- | --- |
| P01 | Moderne Alltagssyntax und vollständiger gewöhnlicher Kontrollfluss | Bestehende VM | Häufigen Websitecode direkt schreiben |
| P02 | Objektmodell, Funktionen und Typsemantik | P01 teilweise parallel | Gemeinsamer korrekter Unterbau für weitere APIs |
| P03 | Alltägliche Standardbibliothek | P02 schrittweise | Daten suchen, sortieren, umformen und serialisieren |
| P04 | Symbols, Iteratoren und Sammlungen | P02/P03 | `for/of`, Spread, Destructuring, Set/Map |
| P05 | Promise- und Async-Ergänzungen | P01/P02/P04 je Teilfunktion | Vorhandene Asynchronität vervollständigen |
| P06 | DOM-Komfort und vollständiger struktureller Abgleich | P02; vorhandener Reconciler | Gewöhnlichen dynamischen Websitecode ausführen |
| P07 | Ereignisse, Eingaben und Formulare | P02/P06 | Eigene Events, Tastatur, Pointer, vollständige Formularsteuerung |
| P08 | Geometrie, berechnete Styles und Scrollen | P06; lokaler Layoutabgleich | Dropdowns, Slider und responsive JS-Widgets |
| P09 | Observer und programmatische Animation | P07/P08 | Auf Änderungen reagieren und Animationen steuern |
| P10 | URLs, Textkodierung und Dateidaten | P03; Binärunterbau bei Bedarf aus P15 | Gemeinsame Datenbasis für Netzwerk und Storage |
| P11 | Netzwerk und Streams | P05/P07/P10; Hostadapter | Daten und Ressourcen asynchron laden |
| P12 | Storage, Navigation und Seitenzustand | P03/P07/P10; Hostadapter | Zustand speichern und lokale Apps navigieren |
| P13 | Scriptladen und Module | P05/P11; eigener Ressourcenresolver | Mehrdateienprojekte und Modulabhängigkeiten |
| P14 | Klassen, Generatoren und fortgeschrittene Sprache | P02/P04/P05 | Größere Bibliotheken und strukturierte Programme |
| P15 | Übrige ECMAScript- und Intl-Familien | Jeweilige Sprachgrundlage | Standardbibliothek vollständig ausbauen |
| P16 | Gemeinsame HTML-, SVG-, Canvas- und Medien-APIs | P06–P11; vorhandene Grafikhosts | Grafikelemente direkt aus gewöhnlichen HTML-Skripten steuern |
| P17 | Worker, Kommunikation und getrennte Ausführung | P11/P13/P15; Hostentscheidung | Arbeit aus dem Seitenablauf auslagern |
| P18 | Weitere Geräte-, Browser- und Plattform-APIs | Machbarkeit je Familie klären | Bewusst erfasste Erweiterungsreserve |

### P01 Moderne Alltagssyntax

- [ ] Arrow Functions einschließlich async-Arrows, lexikalischem `this`, Block- und Ausdrucksrückgabe.
- [ ] Template Literals mit `${...}`; Tagged Templates und `String.raw` als eigene Folgefunktion.
- [ ] Default- und Restparameter; Objektkurzformen, Methodenkurzformen und berechnete Propertynamen.
- [ ] Optional Chaining `?.`, Nullish Coalescing `??`, logische Zuweisungen `&&=`, `||=`, `??=`.
- [ ] Potenzierung `**`, `%=` und weitere zusammengesetzte Zuweisungen; Prefix-`++/--`.
- [ ] Bitoperatoren `& | ^ ~ << >> >>>` und ihre Zuweisungen; korrekte 32-Bit-Umwandlung.
- [ ] `in`, `instanceof`, `delete`, `void` und Kommaoperator über das Objektmodell von P02.
- [ ] `do/while`, `switch`, Labels und gezieltes `break`/`continue`.
- [ ] ASI, Zeilenumbrüche, erlaubte abschließende Kommas, Arraylücken, reservierte Wörter, frühe Syntaxfehler und vollständige Literal-/Escape-/Unicode-Identifierformen.

Spread, Destructuring und `for/of` gehören wegen ihrer Iteratorabhängigkeit zu P04. Die Syntax muss an die gemeinsame VM angeschlossen werden, damit HTML-, SVG- und Canvascode dieselben Sprachregeln bekommen. Grundlagen: [Ausdrücke](https://tc39.es/ecma262/multipage/ecmascript-language-expressions.html), [Anweisungen](https://tc39.es/ecma262/multipage/ecmascript-language-statements-and-declarations.html), [Funktionen](https://tc39.es/ecma262/multipage/ecmascript-language-functions-and-classes.html).

### P02 Objektmodell und Typsemantik

- [ ] Einheitliche Standardprototypen, Propertyschlüssel, Besitz-/Vererbungssuche und festgelegte Enumeration.
- [ ] Propertydeskriptoren: writable/enumerable/configurable, Getter/Setter, eigene/inherited Properties, nicht erweiterbare und eingefrorene Objekte.
- [ ] Vollständige `ToPrimitive`-/Zahl-/String-/Boolean-Konvertierungen, Gleichheit, UTF-16-Vergleiche, `NaN`, `-0` und Infinity-Randfälle.
- [ ] Ordinary/strict `this`, Primitive-Boxing, Konstruktoren, `new.target`, Funktionsname/-länge und Funktionsprototypen.
- [ ] `Function.prototype.apply/bind/call/toString`, korrektes `arguments`, Konstruktion gebundener Funktionen.
- [ ] Vollständige Scope-/Hoisting-/TDZ-/Strict-Regeln und frühe Fehler; globale `var`-/lexikalische Bindungen korrekt unterscheiden.
- [ ] Fehlerfamilien vervollständigen: `EvalError`, `URIError`, `SuppressedError`, `cause`, Vererbung und native Konstruktorsemantik. Stackdiagnosen separat als Hostfunktion behandeln.
- [ ] Web-IDL-Typumwandlung, optionale Argumente, read-only Eigenschaften, Methodenempfänger und `DOMException` für DOM-/Hostobjekte.

Eigene Knoten-/Event-/Promiseobjekte brauchen weiterhin stabile Identität. Der Unterbau soll Unterschiede zwischen APIs lösen, bevor jede API einen eigenen Ersatz baut. Grundlagen: [ECMAScript Fundamental Objects](https://tc39.es/ecma262/multipage/fundamental-objects.html), [Web IDL](https://webidl.spec.whatwg.org/).

### P03 Alltägliche Standardbibliothek

Die aufgeführten Namen sind die zuerst sichtbaren Lücken; das Abschlussziel umfasst die gesamte jeweilige Standardfamilie.

| Familie | Noch einzubauen oder zu vervollständigen |
| --- | --- |
| `Object` | Konstruktor/Prototyp, `keys`, `values`, `entries`, `fromEntries`, `assign`, `create`, `hasOwn`, `is`, `groupBy`; Descriptor-/Prototype-/Freeze-/Seal-/Extensibility-Methoden |
| `Array` | Konstruktor, `isArray`, `from`, `of`; `at`, `concat`, `copyWithin`, `every`, `some`, `fill`, `find`, `findIndex`, `findLast`, `findLastIndex`, `flat`, `flatMap`, `lastIndexOf`, `reduce`, `reduceRight`, `reverse`, `shift`, `slice`, `sort`, `splice`, `unshift`, `toReversed`, `toSorted`, `toSpliced`, `with`, Iteration und Stringkonvertierung |
| `String` | Konstruktor/Prototyp, `at`, `codePointAt`, `concat`, `lastIndexOf`, `padStart`, `padEnd`, `repeat`, `replace`, `replaceAll`, `split`, `trimStart`, `trimEnd`, `normalize`, `isWellFormed`, `toWellFormed`, `fromCharCode`, `fromCodePoint`, `raw`; Match-/Locale-/Iteratorfunktionen mit ihrem Unterbau |
| `Number` und `Boolean` | Konstruktor-/Wrapper-/Prototypsemantik, Number-Konstanten, `isFinite`, `isNaN`, `isInteger`, `isSafeInteger`, `parseInt`, `parseFloat`, `toFixed`, `toExponential`, `toPrecision`, `toString`, `valueOf`; Localeformatierung mit Intl |
| Globale Hilfen | `parseInt`, `parseFloat`, `isFinite`, `isNaN`, `encodeURI`, `decodeURI`, `encodeURIComponent`, `decodeURIComponent`; dynamische Evaluation separat in P14 |
| `Math` | Übrige Konstanten; `random`, `sign`, `trunc`, `cbrt`, `hypot`, `clz32`, `imul`, `fround`, `f16round`, Log-/Exponential-/Trigonometrie-/Hyperbelfunktionen, vollständige Randfälle vorhandener Methoden |
| `JSON` | `parse`, `stringify`, Reviver/Replacer/Einrückung, Zyklen und Randwerte; aktuelle Raw-JSON-Erweiterungen als eigener Teilumfang |
| `Date` | Konstruktor, `now`, `parse`, `UTC`, Zeitwerte; alle lokalen/UTC Getter/Setter, ISO-/JSON-/Stringausgabe, ungültige Datumswerte, Zeitzonen-/Sommerzeitregeln |

- [x] Raw-JSON-Teilumfang: JSON.rawJSON/isRawJSON, unveränderte primitive Parse-Quelle im Reviver-Kontext, replacer/toJSON-Reihenfolge, eingefrorene Wrapper, UTF-16-Grenzen, Realm-/Budget-/Proxy-Regeln.

Array-/Stringmethoden müssen Lücken, Callback-Reihenfolge, Empfänger und Seiteneffekte berücksichtigen. JSON darf kein Lua-Tabellenformat nach außen geben. Quellen: [Fundamental Objects](https://tc39.es/ecma262/multipage/fundamental-objects.html), [Indexed Collections](https://tc39.es/ecma262/multipage/indexed-collections.html), [Text Processing](https://tc39.es/ecma262/multipage/text-processing.html), [Numbers and Dates](https://tc39.es/ecma262/multipage/numbers-and-dates.html), [Structured Data](https://tc39.es/ecma262/multipage/structured-data.html).

### P04 Symbols und Iteratoren

- [ ] `Symbol`, `Symbol.for`, `keyFor`, `description`, sämtliche standardisierten Well-known Symbols und Symbol-Properties.
- [ ] Allgemeines Iteratorprotokoll mit `next`, `done`, `value`, `return`/IteratorClose, Fehlerweitergabe und Unicode-Codepoints bei Stringiteration.
- [ ] `for/of`, `for/in`, Array-/Argument-Spread, Objekt-Spread, Array-/Objektdestructuring einschließlich Default-/Restmustern.
- [ ] `Map`: Konstruktor, `get/set/has/delete/clear`, `size`, `keys/values/entries`, `forEach`, Iteratoren und `groupBy`.
- [ ] `Set`: Konstruktor, `add/has/delete/clear`, `size`, Iteration; `union`, `intersection`, `difference`, `symmetricDifference`, `isSubsetOf`, `isSupersetOf`, `isDisjointFrom`.
- [ ] `WeakMap`/`WeakSet` mit korrekten zulässigen Schlüsseln und tatsächlicher schwacher Referenzhaltung.
- [ ] Iterable DOM-Sammlungen und allgemeine Iterable-Eingaben für Promise-Kombinationen.
- [x] Synchroner `Iterator`-Konstruktor, `from`, standardisiertes `concat`, `map/filter/flatMap`, `take/drop`, `reduce`, `toArray`, `some/every/find`, `forEach`, Close-/Dispose-Regeln und gemeinsame native Iterator-Prototypen. Neue Draft-Ergänzungen und AsyncIterator-Helfer bleiben getrennte Folgepakete.

Grundlagen: [Keyed Collections](https://tc39.es/ecma262/multipage/keyed-collections.html), [Iteration](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-iteration).

### P05 Asynchronität vervollständigen

- [ ] `Promise.withResolvers`, `Promise.try`, vollständige native Promise-Properties/-Prototypen und beliebige Iterable-Eingaben.
- [ ] Promise-Subklassen und `Symbol.species`, sobald P14 Klassen unterstützt.
- [ ] Async-Arrows und async-Methoden aus P01; dynamische AsyncFunction-Konstruktion nur mit dem Evaluationsunterbau aus P14.
- [ ] `unhandledrejection`, `rejectionhandled`, `PromiseRejectionEvent` und korrekte Hostdiagnosen.
- [ ] `AbortController`/`AbortSignal` mit `abort`, `reason`, `throwIfAborted`, statischem `abort/timeout/any`; gemeinsame Anbindung an Events/Fetch/Streams.
- [ ] Aufgabenquellen und Microtask-Checkpoints bei Eventdispatch, Laden, Frames und Unterdokumenten vervollständigen; Visibility-/Hintergrundverhalten gesondert.
- [ ] Idle-/Schedulingfamilie vervollständigen. Das [kooperative Idleprofil](JAVASCRIPT-IMPLEMENTATION.md#kooperative-idle-callbacks--15-oktober-2026) liefert `requestIdleCallback`/Abbruch, Deadlineobjekte und Timeouttasks am vorhandenen Treiber. [Priorisierte Aufgaben](JAVASCRIPT-IMPLEMENTATION.md#priorisierte-aufgaben--18-oktober-2026) ergänzen `postTask/yield` und TaskController/TaskSignal. Exakte native Idle-/Agentkriterien und vollständige Cross-Realm-Receiverfälle bleiben offen.

Promise-Reaktionen und Await dürfen keine zweite Render- oder Polling-Schleife einführen. Ein AbortSignal storniert die angeschlossene Operation; eine Promise bekommt dadurch keine erfundene allgemeine `cancel()`-Methode. Grundlagen: [Control Abstraction](https://tc39.es/ecma262/multipage/control-abstraction-objects.html), [HTML-Ereignisschleifen](https://html.spec.whatwg.org/multipage/webappapis.html), [DOM Abort](https://dom.spec.whatwg.org/#aborting-ongoing-activities).

### P06 DOM und strukturelle Änderungen

- [ ] `matches`, `closest`, `getElementsByClassName`, `getElementsByTagName`, vollständige Selektor-/Scope-Semantik.
- [ ] `append`, `prepend`, `before`, `after`, `replaceWith`, `replaceChild`, `replaceChildren`, `cloneNode`, `contains`, `compareDocumentPosition`, `normalize`, `isEqualNode`, `getRootNode`.
- [ ] `nextElementSibling`, `previousElementSibling`, `nodeName`, Text-/CharacterData-Oberfläche, `dataset`, vollständige `classList` und Attribute-/Namespace-APIs.
- [ ] `innerHTML`, `outerHTML`, `insertAdjacentHTML/Text/Element`, Fragmentparser, `DOMParser`, `XMLSerializer`, Template-Klonen, `importNode`/`adoptNode` und Dokumenterstellung.
- [ ] Volle NodeList-/HTMLCollection-/NamedNodeMap-Prototypen, Live-Semantik, benannte Einträge und Iteration.
- [ ] Verbundene Mutationen für Tabellen, Select-Optionen, Bilder/Medien, SVG/Canvas/Iframes, Details/Dialog/Popover, Stylesheets und Skripte.
- [ ] Inline-/Blockwechsel, gemischte Medien-/Textflüsse, Counter/Pseudoelemente und besondere Scroll-/Animationalbindungen im Reconciler.
- [x] NodeFilter, TreeWalker und NodeIterator: Navigation, Filterkonvertierung/-Reentranz, Live-Positionen bei Entfernung/Verschiebung, stabile Identität und Abbau.
- [x] Lebende getElementsByName-/getElementsByTagNameNS-Abfragen für den vorhandenen HTML-/SVG-DOM; Tag-/Klassenabfragen teilen Konvertierung, Namenregeln und einen mutationsabhängigen Cache. Vollständige Collection-Prototypen und XML-/Quirks-Dokumente bleiben offen.
- [x] Range/StaticRange-Kern, lebende DOM-Grenzen, Inhaltsoperationen und native Light-DOM-Auswahl mit Selection, Ereignissen und Textrechtecken. Profil und Referenzgrenzen: [Range/Selection](JAVASCRIPT-RANGE-SELECTION.md).
- [ ] Vollständige Textbearbeitung, Shadow-Auswahl/Rescoping, Selection.modify, IME und genaue Bidi-/Vertikal-/Fontgeometrie.
- [x] Komponentenprofil: Custom Elements, `customElements`, Konstruktion/Upgrade/Lifecycle, Shadow DOM, `attachShadow`, Slots, Event-Retargeting, eigene/adoptierte Styles, Host/Slotted/Part-CSS. [Umfang und Grenzen](JAVASCRIPT-COMPONENTS.md).
- [x] Dynamische Tabellenstrukturen mit lebenden Sammlungen, Tabelleninterfaces, Span-/Abschnittsänderungen und retained Controls; [Profil](JAVASCRIPT-TABLES.md).
- [x] Dynamische Counter-/Pseudo-Inhalte und Marker im gemeinsamen Reconciler; [Erweiterungsprofil](JAVASCRIPT-DOM-CSS-EXTENSIONS.md).

Das Ziel ist Mutation mit denselben Seiteneffekten wie im Browser. Bereits existierende Knoten behalten Eingaben, Listener und Identität; neu eingefügte Spezialelemente erhalten ihre Ressourcen-/Inputanbindung. Normative Interfacekataloge: [DOM](https://dom.spec.whatwg.org/), [HTML](https://html.spec.whatwg.org/multipage/).

### P07 Ereignisse und Formulare

- [ ] `EventTarget`, `Event`, `CustomEvent`, `dispatchEvent`, `detail`, `timeStamp`, `isTrusted`, `composed`, `composedPath`; Listenerobjekte mit `handleEvent` und `signal`.
- [ ] Maus-/Pointer-/Touch-/Wheel-/Tastatur-/Fokus-/Input-/Composition-Events mit Positions-, Tasten- und Modifierdaten; Enter/Leave, Pointer-Capture und Standardaktionen.
- [ ] `onclick` und andere Eventhandlerproperties; Attributhandler nur mit dokumentierter Standardscope-Semantik.
- [ ] `focus`, `blur`, `activeElement`, `tabIndex`, Fokusoptionen, Textauswahl und Caretsteuerung.
- [ ] Formular-/Input-/TextArea-/Select-/Option-Properties: `name`, `type`, `disabled`, `readOnly`, `required`, Defaultwerte, Indeterminate, Auswahl, Numerik/Datum und Validity.
- [ ] `form.elements`, `requestSubmit`, `submit`, `reset`, `checkValidity`, `reportValidity`, `setCustomValidity`, `FormData`, `formdata` und `SubmitEvent.submitter`.
- [x] Textfeldprofil: `selectionStart/End/Direction`, `select`, `setSelectionRange`, `setRangeText`, UTF-16/native Bytepositionen und asynchrone Auswahlereignisse; [Umfang und Grenzen](JAVASCRIPT-TEXT-CONTROLS.md).
- [ ] Vollständige IME-/Bidi-/Touch-Bearbeitung, Auswahl-Scrolling und gemeinsame TextControl-/Document-Selection.
- [x] Pointer-Capture, native Touchkontakte/TouchLists und Unicode-beforeinput/input. Native IME-Zwischenstände sind mangels Roblox-API nicht verfügbar; [Profil](JAVASCRIPT-POINTER-TOUCH-INPUT.md).
- [x] Dialog-/Popoverprofil: show/showModal/close/requestClose, open/returnValue/closedBy, Popovermethoden/Attribute, ToggleEvent/cancel/close, native Befehle/Fokus/Escape und dynamische Ressourcen; [Grenzen](JAVASCRIPT-TOP-LAYER.md).
- [ ] Vollständige Details-/Elementprototypen, CloseWatcher, Cross-Realm-/Shadow-/Iframe-Inertheit und übrige spezielle Elementfamilien.

Elementart und Textänderung dürfen keine pauschale Seitenneuberechnung verursachen. Neue Eventpayloads müssen aus dem echten Inputmodell kommen. Eventdispatch-Grundlage: [DOM Events](https://dom.spec.whatwg.org/#events). HTML-Elementoberflächen werden nach ihren jeweiligen HTML-Interfaces ausgebaut.

### P08 Geometrie und Scrollen

- [x] DOMPoint/ReadOnly, DOMMatrix/ReadOnly und DOMQuad einschließlich Matrixrechnung, absoluter CSS-Transformstrings, JSON-/TypedArray-Konvertierung und typbewahrendem StructuredClone.
- [ ] Vollständige `getBoundingClientRect`-/`getClientRects`-Fragmentierung und projektive Clips; vorhandene DOMRect-/ReadOnly-/List-Grundlage und Geometrieanbindung vervollständigen.
- [ ] `offsetWidth/Height/Top/Left/Parent`, `clientWidth/Height/Top/Left`, `scrollWidth/Height/Top/Left` und Viewport-/Fenstermaße.
- [ ] Vollständiger `getComputedStyle`-Werte-/Propertyzugriff; das vorhandene lebende Profil einschließlich gemeinsamer `CSSStyleDeclaration` ist umgesetzt.
- [x] Stylesheet-CSSOM-Profil: lebende Blatt-/Regellisten, Style-/Media-/Supports-Regeln, Deklarationen und Prioritäten, `insertRule`/`deleteRule`, konstruierte `CSSStyleSheet`, `replace`/`replaceSync` und `document.adoptedStyleSheets`; gezielter Renderingabgleich. Umfang und Fehlerfälle: [CSSOM-Profil](JAVASCRIPT-CSSOM.md).
- [x] Erweitertes CSSOM-Profil: Keyframes/FontFace/Page/Margin/Import/Namespace/Layer/Container/Scope/StartingStyle/Property/CounterStyle/FontPalette-Regeln, ShadowRoot-Adoption und dynamische Counter-/Pseudoelemente. [Umfang](JAVASCRIPT-DOM-CSS-EXTENSIONS.md).
- [ ] Vollständige Regel-/Descriptor-/Nestinggrammatik und Wertserialisierung, Ressourcen-/Originmodell sowie Fontdatei-/Print-/Font-Palette-Rendering.
- [ ] `scroll`, `scrollTo`, `scrollBy`, `scrollIntoView`, Smooth-Scroll, Scrollereignisse und passende Abschlussereignisse.
- [ ] `matchMedia`/MediaQueryList einschließlich Änderungen; `CSS.supports` und `CSS.escape`.
- [ ] Sichtbare und Layoutkoordinaten bei Transforms, Scroll, Iframes, Resize, Skalierung und Scrollbarbreite korrekt unterscheiden.

Wichtige Implementierungsregel: Ein Geometrie-Read liefert einen aktuellen Stand. Falls davor Änderungen liegen, wird die notwendige lokale Style-/Layoutarbeit vorgezogen; unbeeinflusste Bereiche behalten ihre Caches. Wiederholte Reads ohne neue Writes sollen den Stand wiederverwenden. Grundlage: [CSSOM View](https://drafts.csswg.org/cssom-view/).

### P09 Observer und Animationen

- [ ] `MutationObserver` mit Records, Optionen, `takeRecords`, `disconnect` und Microtask-Auslieferung.
- [ ] `ResizeObserver` für tatsächlich veränderte Größen und dessen Lieferung im Layout-/Frameablauf.
- [ ] `IntersectionObserver` mit Root, Margins, Thresholds, Scroll-/Transformkontexten.
- [ ] `Element.animate`, `Animation`, `KeyframeEffect`, Timeline, `finished`/`ready`, `play/pause/cancel/finish/reverse`, Playbackrate und `getAnimations`.
- [x] `Animation.commitStyles()` für das vorhandene replace-Paintprofil mit Teilstapel, einer CSSOM-Mutation, aktuellen Kontextwerten und retained Rendering; [Umfang und Grenzen](JAVASCRIPT-ANIMATION-COMMIT.md).
- [x] Numerische Layoutanimationen, add/accumulate, einzelne Keyframe-Composites, gemeinsame CSS-/WAAPI-Samples, aktuelle Geometrie und erweitertes commitStyles; @starting-style. [Profil und Grenzen](JAVASCRIPT-ANIMATION-LAYOUT.md).
- [ ] CSS-Transition-/Animationereignisse; gemeinsame Zeitleiste mit dem vorhandenen Motion-System.
- [x] User Timing und PerformanceObserver für mark/measure über die gemeinsame Uhr und Aufgabenwarteschlange; [Profil und Grenzen](JAVASCRIPT-PERFORMANCE.md).
- [ ] Weitere Performance-Eintragstypen, Scroll-/View-Timelines und View Transitions als gesonderte Ausbauten.

Observer sammeln Änderungen aus den bestehenden Aktualisierungspfaden. Sie sollen keine permanente DOM-/Layoutvollsuche pro Frame verwenden. Diese Anforderungen und Prioritäten sind unser Architekturvorschlag; Details richten sich vor Implementierung nach den jeweiligen Observer-/Animationsstandards.

### P10 URLs und Datentypen

- [ ] `URL`, `URLSearchParams`, URLauflösung gegen Dokumentbase und vollständige Kodierungsregeln.
- [ ] `TextEncoder`, `TextDecoder`, ihre Streamvarianten und `atob`/`btoa`.
- [ ] `Blob`, `File`, `FileList`, `FileReader`, Object URLs, Binär-/Text-/Streamzugriff und `structuredClone`.
- [ ] `CompressionStream`/`DecompressionStream` als Folgeausbau; Übertragung und Ownership von Binärpuffern sauber festlegen.

Browserkompatible Dateien/Object URLs können zunächst über virtuelle Hostressourcen abgebildet werden. Tatsächliche lokale Dateiauswahl ist eine getrennte Plattformfrage.

### P11 Netzwerk und Streams

- [ ] `fetch`, `Request`, `Response`, `Headers`; Methoden, Status, Bodytypen, Fehler, Redirects und Abbruch.
- [ ] `text/json/blob/arrayBuffer/formData`, Body-Consumption, Clone/Locked-Zustände und Streams.
- [ ] `ReadableStream`, `WritableStream`, `TransformStream`, Reader/Writer, Backpressure, Pipe, Tee und Abbruch.
- [ ] Externe HTML-/CSS-/Script-/Bild-/Fontressourcen über einen gemeinsamen Loader/Resolver mit URLbase, Cache und Ladeereignissen.
- [ ] Folgeausbau: asynchrones gepuffertes [XMLHttpRequest](JAVASCRIPT-IMPLEMENTATION.md#asynchrones-xmlhttprequest--18-oktober-2026) ist vorhanden; synchrones XHR, Live-Progress, `WebSocket`, `EventSource`, `sendBeacon` und weitere Transporte bleiben offen.
- [ ] Originmodell, erlaubte Netzwerkzugriffe, Credentials/Cookies, CORS, Cache und Cross-Realm-Kommunikation zusammen mit dem Hostadapter entscheiden.

Eine HTTP-Anfrage im Roblox-Host ist noch keine vollständige Browser-Fetch-Implementierung. Client-/Servertransport, sichtbare Fehler und Ressourcenpolitik müssen zuerst feststehen. Danach bleibt die JS-Oberfläche standardkonform und die konkrete Hostgrenze wird dokumentiert. Grundlage: [Fetch](https://fetch.spec.whatwg.org/).

### P12 Storage und Navigation

- [x] Web-Storage-Oberfläche: `localStorage`, `sessionStorage`, `length`, `key`, `getItem/setItem/removeItem/clear`, Quoten, benannte Properties und queued `storage`-Events zwischen verbundenen Realms.
- [x] Roblox-Speicherhost: dauerhaftes `localStorage` pro Spieler und HTTP(S)-Origin über DataStore sowie gemeinsames `sessionStorage` über Dokumentwechsel innerhalb desselben Engine-Browsers. Laden vor Scriptstart, gebündelte asynchrone Änderungen, idempotente Wiederholungen und explizite Fehler; [Umfang und Einrichtung](JAVASCRIPT-STORAGE.md).
- [ ] `location`, URL-/Hashänderungen, `history.pushState/replaceState/back/forward/go`, `popstate`, `hashchange`, Titel und Dokument-URL.
- [ ] Dokument-/Fensterlifecycle mit `load`, `pageshow/pagehide`, `visibilitychange`, `error`, passenden Zustandsproperties und tatsächlich unterstützter Navigation.
- [ ] `navigator`-/Screen-/Visibilityoberfläche anhand des vorhandenen Hosts; keine erfundenen Browser-/Gerätedaten.
- [ ] Weitere Persistenz-/Koordinationsdienste: IndexedDB, Cache API, vollständiger BroadcastChannel-Host und Web-Locks-Hostpolitik bleiben offen. [Web Locks](JAVASCRIPT-IMPLEMENTATION.md#web-locks-im-hostspeicher--18-oktober-2026) koordinieren bereits Realms über einen ausdrücklich geteilten In-process-Store; getrennte Actor-Worker benötigen IPC.
- [ ] Cookies und weitere Cookie-/Origin-/Permissionoberflächen nur mit einem definierten Hostmodell.

Der Speicherhost trennt Spieler und Origins; unterschiedliche Pfade derselben Origin teilen ihre Daten. Eine Play-Sitzung besitzt einen Browserhost und dessen Sitzungsspeicher. Ohne expliziten Hostadapter behält die Runtime ihren begrenzten Dokument-Memory-Speicher; sie behauptet dann keine Persistenz. Nicht zugelassene und opaque Origins erhalten weiterhin `SecurityError`. Die neue erste Vergleichskarte zeigt Notiz-Wiederherstellung, gezieltes Löschen und Sitzungszählung beim erneuten Laden. Grundlage für Web Storage: [HTML Storage](https://html.spec.whatwg.org/multipage/webstorage.html).

### P13 Skripte und Module

Zusätzliches geprüftes Profil: dynamische Inline-/src-Insertion, geordnete
async=false-Skripte, currentScript/Microtask-Reihenfolge, started-Klonzustand,
inerte HTML-Insertion und aktive Range-Fragmente. [Umfang](JAVASCRIPT-SCRIPTS.md).

- [ ] Klassische Skripte im Head/mitten im Dokument, externe `src`, `async`, `defer`, `currentScript`, Lade-/Fehlerereignisse und korrekte Startreihenfolge.
- [ ] `type="module"`, `import`, `export`, Reexports, Live-Bindings, einmalige Modulevaluation, Zyklen und Fehlerpropagation.
- [ ] `import()`, `import.meta`, Import Maps und Import Attributes; JSON-Module als eigener unterstützter Typ.
- [ ] Top-Level-Await und Modulgraphen mit asynchronen Abhängigkeiten.
- [ ] Dynamische Script-/Stylesheetinsertion und Iframe-Realmgrenzen; Parser-Blocking/`document.write` erst mit entsprechendem Parserablauf.

Modulsuche und Ressourcensuche sollen denselben URL-/Loaderunterbau benutzen. Resize oder ein DOM-Update darf Module nicht erneut ausführen. Sprachgrundlage: [Scripts and Modules](https://tc39.es/ecma262/multipage/ecmascript-language-scripts-and-modules.html).

### P14 Klassen und fortgeschrittene Sprache

- [ ] `class`, Konstruktoren, `extends`, `super`, Methoden, Getter/Setter, statische/Instanzfelder, private Namen und statische Blöcke.
- [ ] Generatorfunktionen, `yield`, `yield*`, `next/return/throw`, IteratorClose und `finally` bei Abbruch.
- [ ] Async-Generatoren, Async-Iteratorprotokoll und `for await/of`.
- [ ] `Reflect` vollständig und `Proxy` mit Traps/Invarianten, Revocation und korrekter Konstruktion/Propertysemantik.
- [ ] Direkte/indirekte `eval`, `Function` sowie dynamische Generator-/Async-Konstruktoren innerhalb derselben begrenzten VM.
- [ ] Legacy-/Annex-B-Semantik separat: `with`, alte String-HTML-Hilfen, `escape/unescape`, Legacy-RegExp-/Date-/Function-Eigenschaften und browserabhängige Kompatibilität.
- [ ] `debugger` und verständliche Quellpositionen/Stacks; Debuggerintegration als eigenes Hostwerkzeug.

Der AST-Interpreter bleibt die Ausführungsgrenze. Dynamische Evaluation darf keinen Quelltext als Luau ausführen oder Roblox-Dienste freigeben. Grundlagen: [Funktionen und Klassen](https://tc39.es/ecma262/multipage/ecmascript-language-functions-and-classes.html), [Reflection](https://tc39.es/ecma262/multipage/reflection.html).

### P15 Übrige Standardbibliothek

ListFormat ist mit englischen/deutschen Daten für alle neun Typ-/Stilkombinationen
je Sprache und Format/Parts/Locale-/Brand-/Iteratorregeln vorhanden.
Die übrigen Intl-Familien bleiben offen. [Umfang](JAVASCRIPT-INTL.md).

| Familie | Ausbauziel und Abhängigkeit |
| --- | --- |
| RegExp | Literale/Konstruktor, `exec/test`, Flags, Capturegruppen/Named Groups, Unicode, Lookaround, Backreferences, Indizes, `lastIndex`, `escape`; String-`match/matchAll/search/replace/split` und Symbolhooks. Eigene Regex-Engine oder geeigneter kompatibler Unterbau erforderlich. |
| BigInt | Literale, Konvertierung, arithmetische/bitweise Operationen, `asIntN/asUintN`, Prototyp-/Stringsemantik und korrekte Trennung von Number |
| Binärdaten | `ArrayBuffer`, Resizing/Transfer/Detachment, `DataView`, alle TypedArray-Familien: Int8/Uint8/Uint8Clamped/Int16/Uint16/Int32/Uint32/Float16/Float32/Float64/BigInt64/BigUint64; komplette Methoden, Endianness und Grenzen |
| Shared Memory | `SharedArrayBuffer`, Grow-Funktionen und `Atomics` einschließlich Wait/Notify/WaitAsync. Korrektes Agent-/Speichermodell erforderlich; Machbarkeit mit P17 klären. |
| Schwache Referenzen | `WeakRef`, `FinalizationRegistry` und korrekte GC-/Jobsemantik. Luau-GC darf keine deterministischen Browser-Finalizer vortäuschen. |
| Ressourcenfreigabe | `using`, `await using`, `Symbol.dispose/asyncDispose`, `DisposableStack`, `AsyncDisposableStack`, `SuppressedError` und Scopeabwicklung |
| Intl | `Intl.getCanonicalLocales`, `Locale`, `Collator`, `DateTimeFormat`, `NumberFormat`, `PluralRules`, `RelativeTimeFormat`, `ListFormat`, `DisplayNames`, `Segmenter`, `DurationFormat`, unterstützte Localeabfragen und Format-/Parts-/Rangefunktionen |
| Neue Standardergänzungen | Änderungen am gewählten Standardstand einzeln erfassen. Temporal gehört als separates Ausbaugebiet dazu; seine Aufnahme in Sprachstandard und Browserverfügbarkeit vor Umsetzung erneut festlegen. |

Sprachmethoden sind grundsätzlich Interpreterarbeit; vollständige Locale-/Zeitzonen-/Unicodeunterstützung benötigt zusätzlich Daten und klare Speicherbudgets. Normative Kataloge: [Text Processing](https://tc39.es/ecma262/multipage/text-processing.html), [Structured Data](https://tc39.es/ecma262/multipage/structured-data.html), [Control Abstraction](https://tc39.es/ecma262/multipage/control-abstraction-objects.html), [Intl](https://tc39.es/ecma402/), [Temporal](https://tc39.es/proposal-temporal/).

### P16 Grafik und Medien integrieren

Path2D ergänzt die gemeinsame Canvas-Laufzeit: SVG-Quellen, Kopien, addPath,
Kontext-Fill/Stroke/Clip und PointInPath sind in 18 Browserfällen geprüft.
Die übrigen Grafik-/Medienfamilien bleiben offen. [Grenzen](CANVAS.md).

- [ ] Normales HTML-JavaScript erhält die vorhandenen Canvas-/SVG-Hostfunktionen über echte DOM-Elemente; gemeinsame Identität, Promises, Timer und Frameabläufe.
- [ ] `canvas.getContext`, die bereits vorhandene Canvas-2D-Oberfläche und Bilddatenobjekte in den HTML-Realm integrieren; fehlende Standardmethoden anhand [CANVAS.md](CANVAS.md) erfassen.
- [ ] SVG-DOM, Namespaces, animierte Werte, Geometrie/CTM, Pointer-/Ereignisscope und Live-Ressourcen anhand [SVG-SUPPORT.md](SVG-SUPPORT.md) vervollständigen.
- [ ] `Image`, Lade-/Decodezustände, Bildquellenänderungen und Font Loading (`document.fonts`, `FontFace`) mit Ressourcenloader verbinden.
- [x] Audio-Hostprofil: `Audio()`/`new Audio()`, echte Audio-DOM-Identität, `play/pause/load`, Zeit/Rate/Lautstärke, Zustände/Fehler/TimeRanges und Ereignisse; gemeinsamer nativer Sound für JavaScript und Controls. Umfang und Grenzen: [Audioprofil](JAVASCRIPT-AUDIO-20261006.md).
- [ ] Übrige `HTMLMediaElement`-Familie: Video-JavaScript, Tracks, vollständige Source-/Streaming-/Codec-/Autoplay-Unterfälle und Fullscreen/Picture-in-Picture.
- [ ] Vorhandene WebGL-/WebGPU-Teilpfade integrieren; übrige Grafikoberfläche, Web Audio, ImageBitmap und OffscreenCanvas als separate große Ausbaugebiete.

Bestehende Teilimplementierungen werden nicht als vollständige Browser-GPU-/Media-APIs geführt. Für volle Shaderausführung, Codecunterstützung oder Audioknoten brauchen wir eine eigenständige Machbarkeitsentscheidung.

### P17 Worker und Kommunikation

Ein konkreter Standardhost über Roblox-Actors ist implementiert: eigene VM,
klassische/Modul-Worker, Ereignisschleife, gepufferter Start, ArrayBuffer-Transfer,
Fehlerregeln und Aufräumen. Acht Abläufe stimmen mit Browser-Workern überein;
Actor-Bootstrap und Lebensdauer sind separat funktional geprüft. Die tatsächliche
Actor-Ausführung der gezeigten Fälle wurde nach der Brückenkorrektur von Tobias
bestätigt. Die folgenden Punkte bleiben als
volle Familienziele offen. [Hostprofil](JAVASCRIPT-WORKERS.md).

- [ ] `Worker`, `SharedWorker`, `postMessage`, `MessageChannel`/`MessagePort`, MessageEvents und strukturierte Klone/Transferlisten.
- [ ] Getrennte Realms, Scheduler, Budgets und Lifecycle; Hostarbeit darf die HTML-Seite nicht blockieren.
- [ ] Cross-Realm-/Iframe-Kommunikation und Originprüfung.
- [ ] Service Worker, Fetchinterception, Cache/Persistenz, Worklets und Shared Memory als eigene Machbarkeitsstufen.

Ein zusätzliches Coroutineobjekt allein erzeugt keinen Browser-Worker mit paralleler CPU-Ausführung. Erst das konkrete Roblox-Ausführungsmodell entscheidet, welche Garantien realistisch angeboten werden können.

### P18 Weitere Webplattform erfassen

Diese Familien gehören zur Vollständigkeitsreserve. Sie sind noch keine zugesagte nächste Implementierung. Vor jedem Ausbau wird der normative Interfaceumfang erfasst und der Hostweg entschieden.

| Familie | Erfasste Erweiterungen | Erste Planentscheidung |
| --- | --- | --- |
| Sicherheit und Identität | Web Crypto, Permissions, Credential Management, WebAuthn, Trusted Types, Sanitizer | Externe Identitäts-/Permission-/Kryptografiegarantien klären |
| Dateien und Betriebssystem | Clipboard, Drag/Drop, File System Access/OPFS, Downloads, Share, File Handling | Virtuelle Ressourcen von echten OS-Zugriffen unterscheiden |
| Hardware und Sensoren | Geolocation, Generic Sensor, Device Orientation/Motion, Gamepad, HID, USB, Serial, Bluetooth, NFC, MIDI, Battery | Pro Familie verfügbare Roblox-/Geräteschnittstelle prüfen |
| Medien und Echtzeit | MediaDevices/getUserMedia, MediaStream, MediaRecorder, WebRTC, WebCodecs, Speech, Media Session, Audio/Video-Worklets | Kamera/Mikrofon/Codecs/Transport und native Fähigkeiten klären |
| Fenster und Anzeige | Fullscreen, Pointer Lock, Screen Orientation, Screen Capture, Window Management, Wake Lock, WebXR | Ein UI-Fenster besitzt nicht automatisch OS-/Browserfensterrechte |
| Hintergrund und Integration | Notifications/Push, Background Sync/Fetch, Payment Request, Badging, installierbare Web-App-Funktionen | Benötigte Browser-/Serverinfrastruktur separat planen |
| Ressourcen und Diagnose | Resource/Navigation/Event Timing, Long Tasks, Reporting, Beacon, Device/Network-Information | Nur tatsächlich messbare/sichtbare Hostdaten ausgeben |
| Weitere CSS-/Layout-APIs | Typed OM, Properties and Values API, Paint/Layout/Animation-Worklets, neue Timeline-/Transition-APIs | Mit der CSS-/Rendering-Roadmap und ihren Grenzen verbinden |

Nachtrag vom 16. Oktober: Für Kamera/Mikrofon sind zunächst getUserMedia-
Berechtigungsanfragen, die zwei Permissions.query-Namen und PermissionStatus
mit nativer Oberfläche angebunden. [Umfang und Nachweise](MEDIA.md#kamera--und-mikrofonberechtigungen--16-oktober-2026).
Der optionale virtuelle Kamerahost ergänzt nun `MediaStream`/`MediaStreamTrack`
und `video.srcObject`. Kamera-/Szenenpfade stehen im LocalScript; Mikrofonton,
Recorder, WebRTC und vollständige Constraint-/Gerätefunktionen bleiben offen.
Dies schließt weder Permissions noch MediaDevices als Familie ab.

Herstellerspezifische, veraltete und experimentelle Zusätze werden separat markiert. Neue Webstandards erweitern diese Reserve statt still als bereits unterstützt zu gelten.

## Regeln für Leistung und Kombinationen

Diese Arbeit läuft in jeder Etappe mit; sie wird nicht bis ans Ende verschoben.

- Sprach-/Bibliotheksaufrufe ohne DOM-Änderung lösen kein Rendering aus.
- Identische DOM-Werte erzeugen keinen neuen Darstellungsjob.
- Farbe/Deckkraft/geeignete Transforms verwenden Darstellungswege ohne Layout; lokale Textänderungen bleiben lokal, wenn ihre geometrischen Abhängigkeiten gleich bleiben.
- Tatsächliche Größenänderungen markieren betroffene Layoutabhängigkeiten. Nachfolgende unabhängige Boxen werden bei Bedarf verschoben, ihre Texte nicht pauschal erneut angeordnet.
- Flex-, Grid-, Tabellen-, Inline-, Prozent-, Sticky- und Containerabhängigkeiten bleiben korrekt; „nur nach unten verschieben“ ist nicht für jeden Layouttyp ausreichend.
- DOM-Änderungen je synchronem Ablauf/Microtask-Checkpoint bündeln; rAF nutzt den bestehenden Bildtreiber. Keine neue Frameverbindung je Promise, Observer oder Element.
- Lesezugriffe auf Geometrie und Writes dürfen keine unnötige abwechselnde Vollberechnung erzeugen. Caches werden nach ihren tatsächlichen Abhängigkeiten ungültig.
- Seitenabbau, Iframes, dynamische Medien und wartende Jobs räumen Listener, native Ressourcen und Fortsetzungen auf.
- Neue APIs erhalten dokumentierte Quelltext-/Instruktions-/Queue-/Knoten-/Speicherbudgets und verständliche Fehler.
- Kombinationen gehören zum Nutzervergleich: Async plus DOM, Resize plus Animation, Einfügen plus Fokus, Observer plus Layout, Modul plus Fetch und Abbruch plus Seitenwechsel.

## Fortschritt und Wiederfinden

Diese Roadmap wird zusammen mit dem JavaScript-Abschnitt in [README.md](../README.md), dem aktuellen Einstieg in [PLAN.md](../PLAN.md) und [WEBSITES.md](WEBSITES.md) gepflegt. Das aktive Labor zeigt jeweils nur die neue Etappe. Historische Vergleichsdaten können außerhalb der Serverwurzel erhalten bleiben.

Jede neu implementierte Teilfunktion bekommt den Paketbezug, ihre erreichbaren Namen, das zuständige Modul und ihre Grenzen im Supportstand. Nach Tobias' Rückmeldung wird die konkrete Vergleichsetappe als bestätigt markiert. Allgemeine Familien behalten den Status „Teilweise“, bis ihr kompletter vereinbarter Umfang erreicht ist.

| Codebereich | Aufgabe |
| --- | --- |
| `src/HTMLEngine/JavaScript/Syntax.luau` | Tokens, Grammatik, AST und Syntaxfehler |
| `src/HTMLEngine/JavaScript/VM.luau` | Werte, Scopes, Operatoren, Funktionen, Ausführung und derzeitige Standardmethoden |
| `src/HTMLEngine/JavaScript/Strings.luau` | UTF-16-/Unicodegrundlage |
| `src/HTMLEngine/JavaScript/Runtime.luau` | HTML-Realm, Globals, Scriptstart und DOM-Batching |
| `src/HTMLEngine/JavaScript/EventLoop.luau` | Timer, Microtasks und Framecallbacks |
| `src/HTMLEngine/JavaScript/Promises.luau` | Promisezustände, Reaktionen, Thenables und Kombinationen |
| `src/HTMLEngine/JavaScript/AsyncFunctions.luau` | Async-Ausführung und Await-Fortsetzungen |
| `src/HTMLEngine/JavaScript/DOM.luau`, `DOMQueries.luau`, `DOMTraversal.luau` und `Style.luau` | DOM-/Event-/Live-Abfrage-/Traversierungs-/Inline-CSS-Brücke |
| `src/HTMLEngine/JavaScript/DOMRanges.luau`, `RangeContents.luau` und `Selection.luau` | Lebende und statische Bereiche, Inhaltsoperationen und Auswahl im Light DOM |
| `src/HTMLEngine/JavaScript/CSSOM.luau` und `CSSDeclarations.luau` | Stylesheets, Regeln, Adoption und gemeinsame Inline-/Regel-/Computed-Deklarationen |
| `src/HTMLEngine/Layout/TextSource.luau` und `src/HTMLEngine/Rendering/ScriptSelection.luau` | Zuordnung zwischen DOM-Text, gerenderten Fragmenten und nativer Mausauswahl |
| `src/HTMLEngine/JavaScript/LibraryJSON.luau` | Parse/Stringify, Reviver-Quellen und Raw-JSON-Wrapper |
| `src/HTMLEngine/JavaScript/IteratorHelpers.luau` und `BinaryData.luau` | Iterator-Pipelines und Integer-indexed/gewöhnliche TypedArray-Eigenschaften |
| `src/HTMLEngine/JavaScript/GeometryMath.luau` und `GeometryTransformParser.luau` | Punkte, Matrizen, Vierecke und absolute CSS-Transformausdrücke |
| `src/HTMLEngine/Rendering/HTMLScripts.luau`, `DOMReconcile.luau`, `ScriptTransforms.luau`, `ScriptClock.luau` | Anbindung an Input, Ressourcen, Rendering, Layout und Bildablauf |
| `examples/websites/javascript-tests` | Unveränderte Browserquelle der aktuellen Vergleichsetappe |

Größere Standardfamilien sollen eigene Module bekommen, statt die VM dauerhaft zu vergrößern. Das [maschinenlesbare API-/Statusregister](JAVASCRIPT-API-REGISTER.md) exportiert die tatsächlich installierten Deskriptoren einschließlich ihrer Herkunft. Es ist ein Verfügbarkeitsnachweis und noch keine vollständige Standardanforderungs- oder Konformitätsmatrix.

Der Ausbau erreicht nun einen Actor-Host für Dedicated Worker. Observerbudget,
Iterator-Helfer, TypedArrays, Traversierung, Geometrie, lebende DOM-Abfragen,
Raw JSON, Range/Selection, CSSOM und Textfelder besitzen geprüfte Profile.
Dynamische Scripts, ListFormat und Path2D sind ergänzt. Vergleich 08 ergänzt
Tabellen, Shadow DOM/Custom Elements, Pointer/Touch/Text, zusätzliche CSSOM-
Regeln/Kaskade, dynamische Counter/Pseudoelemente und additive Layoutanimationen.
Der Roblox-Speicherhost ergänzt dauerhaftes Local Storage und Sitzungsspeicher
über Dokumentwechsel; die erste Karte zeigt Wiederherstellung und Reload.
Vollständige Shadow-Textbearbeitung, ElementInternals, übrige CSSOM-/Intl-Familien,
Medien, Worker-Netzwerk/Porttransfer,
SharedWorker/ServiceWorker und Shared Memory bleiben offen. Der aktuelle Stand
und die native Studio-Actor-Prüfgrenze stehen im
[Implementierungsregister](JAVASCRIPT-IMPLEMENTATION.md).
