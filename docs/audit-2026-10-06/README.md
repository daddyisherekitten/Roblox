# Gesamtprüfung: HTML, CSS, JavaScript und verbundene Enginepfade

Aktueller Nachtrag: [Optimierungsdurchgang vom 18. Oktober 2026](#optimierungsdurchgang--18-oktober-2026).
Die ursprünglichen Zahlen und Belege vom 6. Oktober bleiben als datierter Bestand erhalten.

Stand: 6. Oktober 2026. Das [Parser-/Attributpaket](../HTML-PARSER-ATTRIBUTES-20261006.md)
ist der vorausgehende Funktionsausbau. Dieses anschließende Review kürzt und
optimiert vorhandene Pfade, ohne die bisherigen Besitz-, Layout- und
Darstellungsverträge zu ändern. FPS-Messungen übernimmt Tobias.

## Umfang und Nachschlagen

Der statische Durchgang erfasst **alle 455 Luau-Dateien unter `src/HTMLEngine`**,
einschließlich generierter Website-/Referenzdaten. Der dauerhafte
[Modul- und Funktionsplan](engine-map.json) enthält Quellprüfsummen, Zeilenzahlen,
**4.983 benannte Funktionsdeklarationen**, **1.221 statische Require-Verbindungen**,
aufrufende Module und Hinweise auf Jobs, Verbindungen und Arbeitspausen.
Kein statischer Require-Pfad ist unauflösbar; der erfasste Graph enthält keine
Require-Zyklen. Anonyme Funktionen und dynamische Aufrufe sind kein vollständiger
Callgraph dieses Registers.

Alle Module wurden strukturell untersucht. Die unten genannten kritischen
Ausführungspfade wurden zusätzlich semantisch auf Aufwand, Reihenfolge,
Wiederverwendung und Abbau geprüft. Das ist kein Versprechen eines manuellen
Zeile-für-Zeile-Konformitätsaudits jedes generierten Datenblocks oder jedes
denkbaren Browserfalls. Die Projektprüfung kompiliert außerdem die First-Party-
Luau-, JavaScript- und Pythondateien sowie Browsermarkup außerhalb der Engine.

Für einen bestimmten Einstieg:

- **HTML-Tag:** [Elements](../../src/HTMLEngine/HTML/Elements.luau) nennt die
  Renderrolle. Parserkontext und Attribute stehen im
  [HTML-Paket](../HTML-PARSER-ATTRIBUTES-20261006.md) und
  [Attributregister](../html-attributes.v1.json). Die Renderrolle führt über
  RenderTree zu Layout, Controls oder einem Ressourcenhost.
- **CSS-Name/Wert:** Das [CSS-Register](../css-features.v1.json) verbindet die
  Standarddefinition mit der tatsächlichen Registrierung, dem internen `Field`,
  Kataloggrenzen, konkreten Parserproben und gegebenenfalls SVG-Pfaden.
  Ein `Field` ist kein Beweis für vollständige Layout-/Paintwirkung.
- **JavaScript-API:** Das [API-Register](../javascript-api-register.v1.json)
  nennt tatsächliche Deskriptoren, Prototypbesitzer, Deklarationsmodule,
  Fachprofile und direkte Regressionen. Dynamische Instanzen/Getterrückgaben
  sind ausdrücklich ein gesonderter Nachweis.
- **Luau-Funktion:** Im Modulplan nach Name oder Datei suchen. Abhängigkeiten
  erklären den Modulweg; `functions[].line` führt zur Deklaration. Bei zukünftig
  verändertem Quellhash die datierte Zeile erneut auflösen.

## Durchgegangene Ausführungspfade

| Einstieg | Verbindung und Zweck | Geprüfter Vertrag / Entscheidung |
| --- | --- | --- |
| Seite laden | `init.mountHTML` → WorkContext/LoadingModules → HTMLPage → Parser/DocumentBuilder → Stylesheet/InlineStyle → RenderTree → LayoutJob | Budgetiertes Laden, blanke Anfangsdarstellung, begrenzte Daten/Arbeit; Abbruch gehört dem Mountbesitzer. Keine doppelte Websiteauswahl. |
| Fehlerhaftes Markup / DOM-Fragment | Tokenizer/Entities/ScriptData → TreeContext/Head/Body/Table/Formatting/ForeignContent → Node; DOMMarkup nutzt denselben Kontextparser | Dokument und Fragment behalten getrennte öffentliche Verträge. Keine zusätzliche Reparatur nach dem Tree-Builder. Klone dürfen Attributreihenfolge nicht teilen. |
| Texteingabe / Checkbox / Select | Input.Controller/Events → Controls.State/TextValue/SelectOptions/FormModel → JavaScript.DOMControls → gebündelte Mutationen | Dirty-Zustand, Defaults, Reset, explizite Formzuordnung und reentrante Ereignisse erhalten. Die Alive-Prüfung nach einem Reset-Event ist notwendig. |
| Hover / Klick / Fokus | Controller → HitTest/PointerCapture → Events/CSS-State → Selektoren und Änderungszuordnung | Rundes Clipping und Reihenfolge der Treffer bleiben gleich. Unveränderte Maße dürfen über Paint laufen; keine elementweise Dauerpollschleife ergänzen. |
| Farbe / Transform ändern | Stylesheet/Selectors/InlineStyle → RenderTree-Stilvergleich → HTMLAnimations/BoxTransform/Transform2D → Paint | Statische Nachschlagetabellen einmal anlegen. 2D-Backface-Prüfung braucht keine 4×4-Inversion; echte 3D-Fälle behalten den bisherigen Pfad. |
| DOM-Kinder hinzufügen/entfernen | Runtime/DOM → HTMLScripts → DOMReconcile → RenderTree-Mapping / Ressourcenlisten | Nur notwendige Teilbäume ersetzen; vorhandene DOM-/GUI-/Controlzustände erhalten. Tiefen nur je Reconcile-Batch ermitteln. |
| Text / Größe / Tabelle ändern | Mutationstyp → DirtyLayout → LayoutJob → Block/Word/Flex/Grid/Table/Positioned Layout → Paint | Elementlokale Messwerte und Layoutcachegrenzen erhalten. Nachfolgende Verschiebung ist keine Neuerstellung. Intrinsische Abhängigkeiten dürfen notwendige Arbeit propagieren. |
| SVG verschieben / skalieren | Layout → SVGBox/Geometry/Session → Szene/Raster/HitTest | Identität und Geometriewiederverwendung unterscheiden; Änderung von Größe/Inhalt kann Rasterarbeit erfordern. Ressourcen und Pointerbesitz beim Abbau freigeben. |
| Timer / Promise / rAF | Runtime → VM/ObjectModel → EventLoop → ScriptClock → gebündelte DOM-/Paintänderungen | Reihenfolge von Tasks/Microtasks und vorhandene Budgets erhalten; Frameanbindung nur bei Arbeit. Keine globale Prototyp- oder Gettercache-Abkürzung. |
| Clone / Transfer / Worker | Node-Klon bzw. StructuredClone/WorkerRealm/Messaging | Vor Transfer erst vollständig validieren; Allokationsbudgets, Besitzer und Abbau erhalten. GUI-Mount und Datentransfer nicht vermischen. |
| Bilder / Fonts / Storage spät fertig | Ressourcenruntime bzw. Storage.Client → Besitzer-/Generationsprüfung → begrenzte Aktualisierung | Späte Ergebnisse dürfen zerstörte oder neue Seiten nicht verändern. Preload ist kein garantierter Assetzugriff; Lifecycle bleibt getrennt vom sichtbaren Layout. |
| Seite schließen | HTMLPage/Page-Cleanups → Runtime/EventLoop/ScriptClock/Input/Ressourcenhosts → Destroy | Verbindungen, wartende Jobs, Bilder, SVG- und native Ressourcen behalten ihren bisherigen expliziten Abbau. |

Vertiefte Kernmodule waren insbesondere HTMLPage, RenderTree, DOMReconcile,
WorkContext, LayoutJob, DirtyLayout, Controller, Events, HitTest, Runtime, VM,
EventLoop, ScriptClock, ObjectModel, StructuredClone, Node, Stylesheet, Selectors,
InlineStyle, Matrix4, Transform2D, LengthExpression, MediaQueries,
ContainerQueries, ImageLoad, Storage.Client sowie SVG.Session/Style/Raster.
Ihre Abhängigkeiten und Register wurden im vollständigen Modulgraph erfasst.

## Umgesetzte Kürzungen und Optimierungen

| Änderung | Warum sie den bestehenden Vertrag erhält | Sicherung |
| --- | --- | --- |
| Node-Klone kopieren `AttributeOrder` unabhängig | Direkte Daten-DOM-Klone erhalten Reihenfolge und teilen kein veränderliches Attributarray | Neue direkte Klon-/Mutationsregression in DocumentTree; DOM-Kombinationen |
| DOMReconcile verwendet feste Feldmengen und berechnet Knotentiefe einmal pro Batch | Gleiche kopierte Felder und Sortierung, weniger temporäre Arrays / wiederholte Vorfahrenläufe; kein Cache über spätere DOM-Mutationen | DOM-/Layout-/Control-Regressionen und Gesamtlauf |
| Matrix4 überspringt Inversion für exakt reine 2D-Matrizen | Die Prüfung verlangt unveränderte Z-/Projektionskomponenten; 3D geht weiter über die Originalinversion | Inversen-Oracle für 2D inklusive Spiegelung/singulärer Matrix; Zähltest 0 Inversionen für 2D und 1 für rotateY |
| Transform2D und HitTest vermeiden temporäre Iterationstabellen | Reihenfolge von Translate/Rotate/Scale und alle vier elliptischen Clip-Ecken bleiben erhalten | ThreeDTransforms und Cursors; zusätzliche Ecktests |
| Selectors verwendet feste Pseudo-/Inputtypmengen | Unveränderliche Mengen werden nicht bei jedem Zustandsvergleich neu allokiert | Selektor-/Form-/CSS-State-Regressionen |
| RegExp.Create normalisiert Flags in einem einzigen Erstellungspfad | Dieselbe kanonische Reihenfolge, ohne zusätzlichen Wrapperaufruf | JS-/Regexregressionen im Gesamtlauf |
| Unbenutzte reine Imports / tote Hilfsfunktionen entfernt | Keine Ressourceninitialisierung oder Exportfunktion entfernt; Cold-Loader neu erzeugt | Gesamtlauf, API-Register und Loaderprüfung |
| Doppelte identische Intl-/Renderbaumwerte entfernt; URL-Slashpattern vereinfacht | Bisher tatsächlich wirksamer Wert bleibt gleich; Slash braucht im Luaupattern kein Escape | Intl-/Navigation-/Renderregressionen |
| Bestehende `--!native`-/`--!optimize 2`-Direktiven vor die Imports gesetzt | Die zuvor verspäteten Direktiven werden als Direktiven erkannt; Rechenalgorithmen unverändert | Luaukompilierung und CPU-Pixel-/SVG-/3D-Regressionen; native JIT-/FPS-Wirkung noch nicht gemessen |
| CSS-Inventargenerator indexiert APIbesitzer und memoisiert Quellenfundstellen | Identische Nachweise, weniger wiederholte Suche beim Werkzeuglauf; kein Laufzeitcache der Engine | Deterministischer Registervergleich |

Unbenutzte Imports betrafen RenderTree/GridValues, DOMCanvas/Surface,
FileData/Strings, Runtime/Node und BlockImage/BorderGeometry. Tote Hilfsfunktionen
betrafen HTMLAnimations.segment, CanvasWebGL.get und StreamPiping.reject.
Die vorhandenen Fontkalibrierungen, Textelementaufteilung, Scroll- und
Resizeverträge wurden nicht verändert.

## Bewusst erhaltene oder weitere Untersuchungen erfordernde Fälle

- **Reentranz:** scheinbar doppelte Alive-Prüfungen können ein Script-/Event-
  Callback absichern. Insbesondere FormModel.Reset prüft vor und nach dem Event.
- **Layoutcache:** kein gemeinsamer Cache für Textmaße verschiedener Elemente,
  keine globale Prototyp-/Gettercache-Abkürzung, keine Umstellung auf Satzlabels.
- **Scheduler:** Timerheap, veränderte Task-/Microtaskreihenfolge oder aggressiver
  Parallelaufbau sind keine nachgewiesenen Verbesserungen dieses Reviews.
- **Ressourcen:** komplette native Ladehänger, Hostspeicher, JIT und Raster-
  Uploadzeit benötigen Studio-/Gerätebeobachtung. Die Prüfung erfindet keine FPS.
- **Lint:** Der erste Gesamtpass hatte 128, der abschließende Pass **102 Nicht-
  Typdiagnosen**. Die verbliebenen Meldungen sind überwiegend Tabelleninferenz,
  lokale Namensüberdeckung, ungenutzte Destrukturierung und Formatierungswarnungen.
  Sie sind keine 102 bestätigten Laufzeitfehler und auch kein fehlerfreier
  Roblox-Typcheck. Der Standalone-Analyzer kennt die Roblox-Umgebung nicht.
  Der [Warnungsbestand](lint.txt) bleibt zum gezielten Nachschlagen erhalten.
  Warnungen wurden nicht durch globale Lint-Deaktivierung verborgen.

## Nachweise und Grenzen

Nach den Codeänderungen bestand der vollständige Lauf mit **257 Engine-Suiten**,
einschließlich isolierter Realm-/CSSOM-Lifecycletests. Die letzte zusätzliche
HitTest-Regressionsänderung bestand anschließend sechs gezielte Suiten:
Cursors, Forms, TableSpans, TableCollapse, MemoryGame und ThreeDTransforms.
Die entsprechenden lokalen Logs sind `build/engine-review-full.txt` und
`build/engine-review-input.txt`; das Testregister ist
[run-html-tests.cjs](../../scripts/run-html-tests.cjs).

Die CSS-Proben verwenden tatsächliche Engineparser und Ersatzobjekte für
Color3/Enum; sie führen keine native GUI, Fontdecodierung oder Browserpaint aus.
Der APIexport ermittelt Deskriptoren ohne Getter auszuführen und ohne Seiten-
Scripts zu starten. Gespeicherte native Browserfixtures bleiben datierte
Referenzen; dieses Review hat keinen neuen nativen Browser-/Studiovergleich
oder FPS-Benchmark durchgeführt.

Die abschließende Projektprüfung umfasst Compiler, Ressourcenverweise,
Dokumentzuordnung, Originalarchivprüfsummen, HTML-/CSS-Belegregister und
Cold-Loader. CSS-/HTML-Referenzgeneratoren, APIexport und Rojo-Build sind
zusätzliche Nachweise. Der [CSS-Abgleich](../CSS-GAPS-20261006.md) benennt
offene Teilfälle und Host-/Bedarfskategorien, statt registrierte Namen als
vollständig umgesetzt zu zählen.

Abschließende Ergebnisse: **857 Luau-, 77 JavaScript-, 44 Python- und 106
HTML-Dateien** bestehen die Projektprüfung; 352 lokale Ressourcenverweise,
sieben Rojo-Projekte und 126 Fontkatalogeinträge sind konsistent. **154 Dokumente**
sind zugeordnet, 1.420 lokale Markdownverweise auflösbar und alle **136
historischen Originale** bytegetreu erhalten; die zwei bekannten historischen
fehlenden Ziele bleiben ausdrücklich markiert. 417 Cold-Loader-Abhängigkeiten,
der aktuelle Modulplan sowie alle HTML-/CSS-Referenz-/Coveragegeneratoren bestehen
ihre Vergleiche. Das API-Register bleibt bei 4.625 Deskriptoren / 562 Besitzern /
110 Modulen, ohne Getterausführung. Rojo 7.7.0 baut das Standardprojekt erfolgreich
als `build/engine-review-20261006.rbxlx`.

```powershell
node scripts/review-engine.cjs --check
python scripts/check-css-coverage.py
python scripts/export-css-coverage.py --check
node scripts/check-project.cjs
node scripts/export-javascript-api.cjs --check
```

Der Modulplan ist ein datierter Beleg. Neue Codeänderungen machen seine
Prüfsummen absichtlich ungleich; erst nach einem neuen Review eine neue
Momentaufnahme erzeugen. Für Funktionsstatus bleiben die Bereichsprofile
maßgeblich, für CSS die [einzige aktive Inventarliste](../CSS-GAPS-20261006.md).

## Optimierungsdurchgang — 18. Oktober 2026

Der neue [Quellplan](../../build/optimization-audit-20261018/engine-map.json)
erfasst alle **676 Luau-Dateien** unter `src`. Der erste eingefrorene Stand hat
7.497 lexikalisch erkannte benannte Funktionsdeklarationen, 315.954 Quellzeilen
und 1.919 statische Require-Kanten; der aktuelle Plan hält die finalen Werte fest.
Es gibt keine unauflösbaren statischen Pfade oder Require-Zyklen. Große generierte
Trennmuster-/Font-/Referenzdaten werden von handgeschriebenen Algorithmen getrennt.
Anonyme Funktionen und dynamische Aufrufe sind Grenzen des lexikalischen Registers;
es ist kein manueller Konformitätsbeweis jeder Funktion.

Vertieft wurden Start/WorkContext/Loading, Parser → DOM/VM → Mutation/EventLoop,
CSS → RenderTree → Block/Wort/Flex/Grid/Tabelle → Paint/Ressourcen, SVG/Text/Raster
sowie Browser/Eingabe/Fenster/Tabhost/Formulare/Medien/Kamera/Abbau. Die genaue
Datei- und Leserangeabdeckung steht in
[Layoutreview](../../build/optimization-audit-20261018/layout-review.json),
[Browser-/Eingabereview](../../build/optimization-audit-20261018/browser-review.json)
und [JS-/DOM-/SVG-Review](../../build/optimization-audit-20261018/js-dom-svg-review.json)
sowie im [Einstiegs-/Hostreview](../../build/optimization-audit-20261018/root-review.json).
Die [vollständige Lesematrix](../../build/optimization-audit-20261018/coverage-complete.json)
weist **581 vollständig gelesene Quellen beziehungsweise handgeschriebene
Runtimeanteile** und **95 Daten-/Payloadreviews** aus. Bei generierten Font-,
Unicode-, Encoding- und Referenztabellen sowie Seitenstrings wurden Erzeuger,
Verbraucher und Fixtures geprüft; nicht jede Datenzelle oder jedes Payloadtoken
wurde einzeln gelesen. Keine handgeschriebene Runtimequelle bleibt bei einer
rein strukturellen Erfassung. Der finale Quellplan enthält 315.998 Zeilen,
7.498 lexikalische benannte Deklarationen und 1.920 statische Require-Kanten.

### Umgesetzt und in kontrollierten Fällen verglichen

| Pfad | Änderung und Nachweis |
| --- | --- |
| Kaltimport-Vorbereitung | Höchstens vier Importe pro Abschnitt und weiterhin Deadlineprüfung vor jedem Import. Erfolgreiche eigene Importe werden bei überlappenden/fehlgeschlagenen Mounts wiedererkannt. [Alter/neuer Einstieg](../../build/optimization-audit-20261018/loading-operations.json): acht günstige Importe brauchen **9 → 3 Pausen**, im simulierten 16-ms-Scheduler **144 → 48 ms Warteanteil**. Teure Einzelimporte, Abbruch, Fehler und gemeinsame Framebudgets separat geprüft. |
| CSS-Regeln | Besitzergebundener Kandidatenindex für normale/Pseudo-/Part-/Shadow-Ziele; Zustände, Queries, Scope, Layer und Cascade bleiben live. 323 Regeln und 360 warme Pseudoabfragen: **116.280 → 360 Klassifikationszugriffe**. In-place-Invalidierung und Scope-Lebensdauer sind geprüft; schwache Schlüssel und Werte verhindern einen neuen Besitzzyklus. |
| DOM-Batches | Positionsmap und einmaliges Kompaktieren ersetzen wiederholte Suche/Verschiebung. 4.096 verschiedene Knoten: **8.386.560 → 0 lineare Suchvergleiche**. Die neue Map-/Kompaktierungsarbeit bleibt linear; 1.000 deterministische Reihenfolge-/Fragmentproben stimmen überein. |
| HTML-Streaming | Höchstens neun Prefixbytes statt Kopie des gesamten Reststreams; begrenzte Delimitersuche mit Überlappung. 2.048 Tags: **29.364.224 → 18.427 kopierte Guard-Bytes**. 56 Streamingkombinationen liefern gleiche Tokens und Warnungen. |
| SVG-Text | Ersten Textrecord einmal pro Expansion nach Knoten indizieren. 256 Glyphen: **33.280 Recordvergleiche → 512 Mapzugriffe**, gleiche Glyphenpfade/-maße und 307.200 gleiche Rasterbytes. |
| Grid/Tabellen | Gleiche Positionen/Größen/Z-Werte vor nativen Writes erkennen. Zweite identische Layouts: **4 Grid- und 6 Tabellenwrites → 0 + 0**; Größen-, Positions- und Orderwechsel sowie GUI-Identität bleiben geprüft. |
| Browser/Fenster | Erreichte Tweenziele ohne laufenden Übergang und bereits fokussierte oberste Fenster benötigen keine erneute Animation/Familiensortierung. **48 → 0 Tweenallokationen**, **24 → 0 gleiche Familiensortierungen**. Echte Wechsel, laufende Übergänge, ungültige Ziele und Modal-/Ownerpfade bleiben geprüft. |
| Favoriten | Textmaß am einzelnen vorhandenen Eintrag wiederverwenden, solange Titel/Font gleich sind; keine Messung für verborgene Leisten. Acht Updates mit zwei Favoriten: **16 → 0 Messungen**; acht verborgene Updates: **8 → 0**. Kein geteilter Textmaßcache. |
| DOM-Beobachter | Ohne Registrierungen kein Vorfahrenaufbau; gefilterte Änderungen planen keine leere Microtask. 100 unregistrierte Mutationen: **0 Vorfahrenreads und 0 Microtasks**; transiente Registrierungen und Zustellreihenfolge bleiben erhalten. |
| Ressourcenhilfen | Storage-Retry nach ACK/Destroy wirklich abbrechen: **1 → 0 wartende Jobs**; Hosts ohne task.cancel behalten Generationsschutz. Kamera-Propertyproben verwenden stabile pcall-Funktionen, temporale Typchecks keine temporäre Suchliste. Medien-/Kamera-/Formular-/Lifetime-Nachbarn prüfen unverändertes Verhalten. |
| Effekt-Snapshots | Eine Kopiermap pro vollständiger Aufnahme statt neuer Maps pro Style/Wort. Tatsächliche DOM-Fälle mit 20/60/120 Wörtern: **6.040/31.520/105.740 → 2.531/7.251/14.331 kopierte Tabellen**. Alle Felder, Metatables und Zyklen bleiben erhalten; je Fall 27.648 identische Rasterbytes, eingefrorene Stylegraphen, native Ressourcenidentität und getrennte ausstehende Frames sind geprüft. Kein geteilter Cache zwischen Frames. |
| Andockvorschau | Bereits versteckte oder gerade ausgeblendete Vorschauen starten keine weiteren Fades. Je 24 wiederholte Aufrufe: **48 → 0 Tweens**. Erneutes Einblenden/Umkehren, alte eingeplante Completion, getrennte Manager und Abbau haben eigene Kontrollen. |

Die Originale der zunächst 15 geänderten Quellen und der anschließend geprüften
Folgefixes, Vorher-/Nachher-Proben und Logs liegen unter
`build/optimization-audit-20261018`. Die Vergleiche messen kontrollierte
Arbeit, keine tatsächliche Studio-Bildrate oder zugesicherte reale Ladezeit.
Wortlabels, Schriftkalibrierungen, passive GUI-Eingabe, sichtbarer Elementbestand,
hierarchischer Besitz und Modulunabhängigkeit bleiben erhalten.

Zusätzlich bestätigte Fehler sind mit Regressionen korrigiert: übernommene
lebende DOM-Abfragen lesen die Revision ihres aktuellen Besitzers; ihre
Tagname-Filter bleiben dagegen an das Erzeugungsdokument gebunden. Gepufferte
`target`-/`open`-Zustände gehen nach einem Layout nicht
verloren. Scroll-Snap erzeugt am erreichten Ziel keine neue Animation, beendet
aber einen alten konkurrierenden Tween und respektiert reentrante neue Besitzer.
Vier kleine Rastercaches verwerfen Images nach einem Abbruch während Allokation,
Upload oder Content-Erstellung. Der Hintergrundhost bekommt die konfigurierte
Anfangsauflösung. Der unbenutzte `Interactive.paint`-Helper akzeptiert nun den
expliziten Router seines Besitzers als vierten Parameter.

Die nativen DOM-Gegenproben bestätigen den gehaltenen HTML-/XML-Tagfilter und
den aktuellen Dokumentmodus bei Klassenvergleichen. Eine zunächst aus einem
Kommentar abgeleitete Shadow-Query-Erwartung wurde durch Chrome widerlegt und
verworfen: Dokument-/Elementabfragen bleiben im eigenen Baum; nur die
Ersetzungsberechtigung einer Animation berücksichtigt den verbundenen
Shadowhost. Originale, verworfene Erwartungen und korrigierte Rot-/Grünbelege
sind getrennt erhalten. Primärverträge:
[DOM-Collections](https://dom.spec.whatwg.org/#concept-getelementsbytagname),
[Animationsabfragen](https://www.w3.org/TR/web-animations-1/#dom-documentorshadowroot-getanimations).

### Abschließende Nachweise

Der [geprüfte Abschlussbeleg](../../build/optimization-audit-20261018/final-acceptance.json)
bestätigt den korrigierten Stand: **453 registrierte Suiten**, genau einmal auf
vier disjunkte Gruppen verteilt, tatsächlicher Exit 0 aller Gruppen einschließlich
der erforderlichen kompakten und isolierten Zusatzprüfungen. Alle **1.726
festgehaltenen Quell-, Test-, Beispiel- und Scriptdateien** sind während dieses
Schlusslaufs unverändert geblieben. Frühere Teilstände und die eigens protokollierte
Testassertionsänderung des ersten Laufs werden damit nicht überschrieben.

Der eigenständige Browser, der vollständige SVG-Lauf, die Projektprüfung,
API-/Cold-Loaderchecks und die drei Rojo-Projekte `default`, `htmlpage` und
`browser` bestehen. Das API-Register enthält weiterhin 5.225 Deskriptoren,
669 Owner und 136 Module bei null Getterausführungen; der Kaltloader umfasst
536 geprüfte Abhängigkeiten. Live-Rojo stimmt für 674 Quellen im gemeinsamen
Projekt und 611 Quellen im HTML-only-Projekt sowie das jeweilige Start-LocalScript
mit dem aktuellen Code überein. Das bestätigt ausgelieferte Quellen; ein laufendes
Studio-Spiel und native Bildrate/Ladezeit wurden dadurch nicht beobachtet.

### Bewusst getrennte Grenzen

Ein einzelner nativer require-/Compile-Aufruf bleibt ununterbrechbar. Das maximal
2-ms-Ladebudget begrenzt die Arbeit zwischen diesen Aufrufen. Es garantiert
nicht, dass jede native Kompilierung unter 2 ms dauert. Die Importstatistik kann
transitiv bereits von Roblox geladene Module enthalten und ist keine vollständige
native Cold-Cache-Messung.

Weitere konkrete Kosten stehen in den Reviews: SVG-/Canvas-Fontnutzdaten im
Importgraph, Medien-Heartbeat bei pausierten Medien, Kameraproperty-Sampling und
Nachfahrenanimationen beim Fensterschließen. Sie benötigen eigene Bedarfs-/
Ereignis-/Hostnachweise, bevor Arbeit sicher entfernt wird. Getter-, Prototyp-,
Layout- und Ressourcenbesitz werden dafür nicht pauschal gecacht. Eine separate
stateChanges-GC-Beobachtung ist kein bestätigter neuer Leckbefund; der neue
CSS-Kandidatenindex hat seinen eigenen bestandenen Lebensdauernachweis.
Der unabhängige Diffreview hat einen neuen Reentryfehler dieses Indexes
tatsächlich reproduziert: Nach In-place-Regelersatz lag die Invalidierung hinter
einem kooperativ wartenden Shadow-Refresh. Die Invalidierung erfolgt jetzt vor
diesem Wartepunkt. Die tatsächliche RenderTree-Regression ist auf dem neuen
Index mit altem Aufrufzeitpunkt rot, auf ursprünglichem Vollscan sowie korrigiertem
Zeitpunkt grün. Der erste Abschlussversuch wurde dafür mit zwei fertigen und
zwei unterbrochenen Gruppen erhalten; der vollständige Schlusslauf verwendet
den korrigierten Quellstand. Diese Teilstände sind kein vollständiger Schlussbeleg.
Auch die Website-URL-Aufzählung lädt derzeit Seitenpayloads; ein Metadatenpfad
braucht einen eigenen Kompatibilitätsnachweis. Veraltete Beschreibungstexte im
Elementkatalog sind von tatsächlichen Laufzeitlücken getrennt protokolliert.
Native Ladezeit, FPS, Assetzugriff und sichtbare Studio-Abnahme bleiben eigene
Nachweise. Dieser Durchgang ist kein neuer HTML-/CSS-/JS-Gesamtabschluss.
