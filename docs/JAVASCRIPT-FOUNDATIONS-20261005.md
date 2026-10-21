# Browser-Grundlagen: Ausbau und Bestand

Stand: 5. Oktober 2026. Dieser Durchlauf setzt den zuletzt priorisierten Plan für
die gewöhnlichen Website-Grundlagen um. Er umfasst die Kombination vorhandener
DOM-, CSS-, Eingabe- und Layoutwege, wichtige CSS-/Animationsfälle, Skript-/Bild-/
Fontladen, Unicode/URL/Datumsformatierung und die Speicheranbindung. Die vollständige
Inventur aller bisher aufgebauten P01–P17-Pakete steht im
[Implementierungsstand](JAVASCRIPT-IMPLEMENTATION.md); die öffentlichen Mitglieder
stehen im [maschinenlesbaren API-Register](javascript-api-register.v1.json).

Die Begriffe „implementiert“ und „geprüft“ beziehen sich jeweils auf den unten
genannten Umfang. R00–R20 bleiben als vollständige Ausbauziele in der
[Roadmap](JAVASCRIPT-ROADMAP.md) erhalten. Ein fertiger Durchlauf bedeutet nicht,
dass jede Unterfamilie einer Browser-API vollständig nachgebaut ist.

## Umgesetzter Plan

| Block | Implementiert und integriert | Nachweise und genaue Grenzen |
| --- | --- | --- |
| Bestehende Kombinationen | Dynamisches `title`, `meta` und `base` wirken sofort auf Dokumentdaten und spätere relative Ressourcen. Sie erzeugen keine sichtbaren GUI-Objekte. Text mit `overflow-wrap: anywhere` bleibt bei gleicher Geometrie lokal; tatsächlich fragmentierter Text, Umbruch und Höhenänderungen nutzen weiterhin den Layoutpfad. Native Bild-/Controlobjekte bleiben bei Änderungen erhalten. | DocumentInfo, JavaScriptCSSOMRendering, JavaScriptStableGeometryRendering, BrowserFoundationsWebsite sowie bestehende Formular-/Shadow-/Observer-/Fernweh-Regressionen. DOM- und Eingabegrenzen stehen weiterhin in R02–R04. |
| CSS und Animationen | Gemeinsames Nesting für Stylesheet und CSSOM, verschachtelte Deklarationen und Regeländerungen mit echter Darstellungswirkung. Laufende Übergänge behalten bei unabhängigen Stiländerungen ihre Uhr. Umkehr verkürzt die Restdauer gemäß CSS. Transparente Farben, Custom Properties in Paint-Keyframes, `steps()`-Varianten und `linear()` verwenden den gemeinsamen Animationsweg. | [CSS-/Animationsprofil](JAVASCRIPT-CSS-ANIMATIONS-20261005.md). Unterstützte Paint- und Layoutproperties sind dort getrennt von offenen Eigenschaften, Grammatik- und Timelinefällen aufgeführt. |
| Skripte, Bilder und Fonts | Korrigierter einmaliger Dokument-Lifecycle; dynamische Skripte und `HTMLScriptElement.supports`. `Image`/`img`-Ladezustände, Metadaten, `decode`, Ereignisse, Quellenrennen, Abbruch und gemeinsame native Metadatenanforderungen. `FontFace`, `document.fonts`, Live-Iteration und typisierte Font-Ereignisse, angebunden an echte lokale Roblox-Fontprofile und deren Preload. | [Ladeprofil](JAVASCRIPT-LOADING-20261005.md). Kein Streamingparser/`document.write`, allgemeiner HTTP-Bildtransport oder beliebiger Webfontdecoder. Assetrechte und tatsächliche Studio-Anzeige werden nicht aus Hostmocks abgeleitet. |
| Text, URLs, Date und Intl | Unicode-Normalisierung, IDNA-/IP-Kanonisierung sowie erweiterte URL-Setter; versionierte Zeitzonendaten und gemeinsame Date-/Intl-Anbindung; zusätzliche de/en-Datums- und Zahlenformatierung. Die Website reicht ihre Locale-/Zeitoptionen an die VM weiter; Date und Intl verwenden dieselben Daten. | [Text-/Datenprofil](JAVASCRIPT-TEXT-DATA-20261005.md) nennt Datenversionen, Referenzen, Zeitbereich, unterstützte Zonen/Locales und offene Standardschritte. Vollständige Weltsprachen-/Zeitzonenabdeckung wird nicht behauptet. |
| Speicherung | Bestehender Speicherhost lädt vor Skriptstart, hält Clientbereiche über Dokumentwechsel und überträgt dauerhafte Änderungen asynchron an den Server. Quoten, Origin-/Spielertrennung, Wiederholungen, Fehler, Sessionzustände und synchroner Clientzugriff bleiben erhalten. Die neue Seite speichert nur ihren eigenen Notizschlüssel. | Storage-, StorageRuntime-, StorageClient-, StorageServer- und StorageRendering-Regressionen; echter Browser-Reload mit gespeicherter Notiz. [Speicherprofil](JAVASCRIPT-STORAGE.md). Ein echter Roblox-DataStore-Persistenztest ist weiterhin eine gesonderte Hostprüfung. |

## Neue Vergleichsseite

[Atelier öffnen](http://localhost:8000/browser-foundations/index.html).
Die Browserquellen liegen unter `examples/websites/browser-foundations`;
`scripts/sync-website.py` erzeugt daraus `Websites/BrowserFoundations`.
HTML, CSS, JavaScript und die beiden SVGs werden unverändert für beide Hosts
verwendet. Es gibt keine Roblox-Zweige im Websitecode.

Fünf Karten kombinieren die neuen Funktionen:

1. Verschachtelte CSS-Regeln, Farbvariante, Hover und eingefügte/entfernte
   CSSOM-Pseudoelementregel auf demselben Vorschauobjekt.
2. Wechselnde Landschaft mit `decode`, natürlichen Bildmaßen und sichtbarem
   Fehlerzustand; das vorhandene Bildobjekt wird weiterverwendet.
3. Tatsächlicher lokaler Fontload mit `FontFace`, `document.fonts.ready` und
   einer Vorschau. Ladefehler bleiben sichtbar.
4. NFC/NFKC, internationaler Domainname sowie der konkrete Berliner
   Sommerzeitwechsel in deutscher und englischer Darstellung.
5. Notiz speichern, lesen und ausschließlich den eigenen Schlüssel löschen;
   die Erläuterung trennt den synchronen Speicherzugriff vom Roblox-Backendcommit.

In Roblox wird die Seite ausschließlich durch
`local WEBSITE = "BrowserFoundations"` in `examples/HTMLPage.client.luau`
ausgewählt. `StudioDemoConfig` bleibt bei `ActiveDemo = "HTMLPage"`.
Die bestehende Startseite `Fernweh` wurde nicht umgestellt.

`resource-reference.html` ist eine zusätzliche native Browserreferenz für
Bild-/Fontzustände, keine weitere ausgelieferte Roblox-Demoseite.

## Prüfungen und Review

Die gezielten Prüfungen montieren die echten Websitequellen und kontrollieren
Ausgaben, CSSOM-Darstellung, Objektidentität, Ressourcenfreigabe, Fehler und
responsive Geometrie. Eine kleine Breite stapelt die Karten und skaliert das Bild.
Gleiche Textgeometrie verursacht keinen zusätzlichen Layoutpass; ein echtes
Wortfragment vergrößert die Karte und verschiebt den Inhalt darunter.

Native Chromium-Prüfungen vergleichen die bedienbaren Karten, SVG-Maße,
Ladefehler und Speicherwiederherstellung. Die versionierten Unicode- und
Node-Referenzen sind in den Teilprofilen beschrieben. Regressionen prüfen
zusätzlich die bereits vorhandenen Seiten und Laufzeitwege.

Der Review erfasst die neuen Module und ihre Runtime-, Layout-, Rendering-,
Cleanup- und Generatoranbindungen. Das ist keine erneute manuelle Volllektüre
jeder historischen Engine- und Testdatei. Statische Projektprüfung, generierte
Websitequellen, API-Register und Rojo-Build gehören zur Abschlussprüfung.
Es wurden keine FPS-Benchmarks durchgeführt.

Abschlussprüfung vom 5. Oktober 2026:

| Prüfung | Ergebnis |
| --- | --- |
| `node scripts/run-html-tests.cjs` | Alle 245 registrierten Suiten bestanden, einschließlich isolierter GC-/Cleanupprüfungen und zusätzlicher nativer DOM-Query-/Traversal-/Range-Vergleiche. Log: `build/browser-foundations-full-tests.log`. |
| Unicode-Normalisierung | Alle 20.034 offiziellen Unicode-17-Korpuszeilen mit 400.680 Invarianten bestanden. |
| Text-/Datenreferenz | Alle 30 nativen Gruppen mit 4.729 Referenzdatensätzen bestanden. |
| Atelier-Integration | Gemeinsame Seitenskripte, CSSOM/Pseudoelemente, Bild-/Fontzustände, Speicher, 420-px-Geometrie, Objektretention und lokale Textänderungen bestanden. Die fünf Karten wurden zusätzlich im echten Browser bedient. |
| Projektprüfung | 824 Luau-, 79 JavaScript-, 35 Python- und 113 HTML-Dateien; 373 lokale Referenzen, sieben Rojo-Projekte und 126 passende Fonteinträge geprüft. Log: `build/browser-foundations-project-check.log`. |
| Rojo | `htmlpage.project.json` erfolgreich nach `build/browser-foundations.rbxlx` gebaut. |
| API-Register | Neu erzeugt und mit `--check` bestätigt: 4.536 Deskriptoren, 555 erreichbare Objekte/Prototypen, 108 Module. Keine Propertygetter wurden beim Export ausgeführt. Logs: `build/browser-foundations-api-export.log` und `build/browser-foundations-api-check.log`. |

Die Deskriptorzahl zählt erreichbare Eigenschaften und Methoden, nicht 4.536
vollständig browserkonforme Funktionen. Native Abweichungen und Profilgrenzen
bleiben in den zuständigen Teilprofilen dokumentiert.

Bildfehler-Nachprüfung vom selben Tag: 18 echte Chromium-Größenfälle und
neun native Request-/Ereignisfälle wurden im [Bildprofil](IMAGES.md)
abgeglichen. Block-/Inlineblock-Fehlerbilder behalten ihre CSS-Fläche;
Alttext und vorhandenes Fehlersymbol erscheinen darin. Inlinebilder,
leeres/fehlendes src, Wiederholungen, Quellenrennen, SVG-Nullmaße,
veraltete Filterflächen und sofortige Inhaltsmaß-Getter sind durch
zusätzliche Regressionen gesichert. Die Websitequellen bleiben unverändert.
Der anschließend vollständige Runner besteht mit 246 Suiten
(`build/image-errors-full-tests.log`); Projektprüfung besteht mit 826 Luau-,
80 JS-, 35 Python- und 114 HTML-Dateien. Rojo und frischer API-Export/check
bestehen ebenfalls. Hierfür wurden keine FPS-Tests ausgeführt.

## Weiterhin getrennte Ausbauziele

Der abgeschlossene Umfang oben ersetzt nicht die übrigen Ziele von R00–R20:
vollständige Sprach-/DOM-/Editing-Konformität, zusätzliche CSS-/Animationseffekte,
alle CLDR-Locale-/Zeitzonenfamilien, echter HTTP-Transport und Browsernetzwerkregeln,
IndexedDB/Cache API, Streamingparser und zyklisches Top-Level-Await, zusätzliche
Canvas-/Medien-/GPU-Verfahren sowie Shared-/Service-Worker und Shared Memory.
Die zuständige Etappe, vorhandene Grundlage und verbleibende Grenze sind in
Roadmap, API-Register und Teilprofilen separat auffindbar.

Ein fehlender nativer Decoder oder verweigerter Hostzugriff wird als Fehler
gemeldet. Es gibt keine Erfolgsanzeige, die lediglich eine noch nicht implementierte
Browserfunktion simuliert. Die visuelle Studio-Prüfung und echte DataStore-
Wiederherstellung bleiben von den automatischen Adapterprüfungen getrennt.
