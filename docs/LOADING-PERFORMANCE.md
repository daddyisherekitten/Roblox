# Schnellerer Seitenaufbau

## Initialisierungsbarriere bei Zwischenlayouts — 19. Oktober 2026

Ein abgeschlossenes Zwischenlayout während der kooperativen
JavaScript-Konstruktion ist noch keine fertige Seite. Die atomare Präsentation
prüft deshalb zusätzlich `ScriptInitializationPending`. Erst nach dem Abschluss
der Skriptinitialisierung darf sie die LoadingWork-Lease beenden. Der explizite
erneute Präsentationsversuch am Mountende ist erforderlich: Bei unveränderter
Fenstergröße plant `requestLayout()` keinen weiteren Durchgang ein.

Eine native Bildpublikation verwendet `Runtime:ImageLayoutCompleted()` mit dem
bestehenden serialisierten VM-Eintritt und Microtask-Checkpoint. Wartet dieser
Eintritt hinter einem Author-Dialog, darf ein zwischenzeitliches Schließen die
Nachricht verwerfen. Der allgemeine strikte Zugriff `Runtime:Access()` wird
dadurch nicht gelockert. Die Quellen-/Load-/Promise-Reihenfolge lebender Bilder
bleibt durch die tatsächlichen ImageResources-Regressionen geprüft.

`AutoImageRendering` prüft den tatsächlichen Runtime-Konstruktionsyield mit
Zwischenlayout, erneute Präsentation ohne Größenänderung, No-Realm mit/ohne
Budget und Abbau vor dem Commit. `JavaScriptSimpleDialogs` prüft lebende und
wartende Bildmeldungen bis zum Abbau. Die
[Abnahme](../build/fallback-layout-lifetime-20261019/final-acceptance.json)
trennt diese CLI-Nachweise vom Nutzerprotokoll und nativen Studio-Zeitmessungen.

## Begrenzte Importgruppen — 18. Oktober 2026

Der öffentliche Engineeintritt bereitet die Rendering-Abhängigkeiten in Gruppen
von höchstens vier nativen Importen vor. Vor jedem Import einschließlich seiner
Modulauflösung läuft der bestehende WorkContext-Checkpoint mit dem gemeinsamen
maximalen 2-ms-Ladebudget. Ein teurer erster Import erzwingt somit vor dem zweiten
eine Pause; vier ist eine zusätzliche Obergrenze, keine Erlaubnis zum Überschreiten
der Deadline. Einzelne native Kompilierungen selbst bleiben ununterbrechbar.

Nur erfolgreich zurückgekehrte eigene Importe werden schwach nach ModuleScript
markiert. Bereits abgeschlossene Arbeit bleibt für einen konkurrierenden Mount
oder nach einem späteren Fehler erhalten. Ein fehlgeschlagener Import wird erneut
versucht; ein abgebrochener Aufbau setzt die globale Bereitschaft nicht vorzeitig.
Das ist kein zusätzlicher Cache der Modulrückgabewerte.

Der tatsächliche alte und neue Einstieg benötigen für acht simulierte günstige
Importe **neun beziehungsweise drei Schedulerpausen**. Bei den ausdrücklich
simulierten 16-ms-Wartezeiten sind das 144 gegenüber 48 ms Warteanteil.
[Vergleichsbeleg](../build/optimization-audit-20261018/loading-operations.json),
[EngineEntry](../tests/EngineEntry.luau) und [LoadingWork](../tests/LoadingWork.luau)
trennen Operations-/Budgetnachweise von tatsächlichen Studio-Ladezeiten.
Parser-only-Import, Kooperationspunkte, Abbruch, gemeinsame Framebudgets und
blanke Anfangspräsentation bleiben erhalten. Weitere Optimierungen des
[gemeinsamen Reviews](audit-2026-10-06/README.md#optimierungsdurchgang--18-oktober-2026)
senken CSS-, DOM- und GUI-Arbeit, ohne zusätzliche Seitenfunktionen abzuschalten.

## Gehaltene Fenstergröße und verzögerte Signale – 13. Oktober 2026

Die Demo meldet einen gehaltenen Größenänderungsgriff über
`HTMLViewportResizing` am Seitentarget. `HTMLPage` prüft jetzt sowohl diesen
aktuellen Attributwert als auch den zuletzt zugestellten Ereigniszustand.
Roblox kann das Attributereignis erst nach der nächsten Fortsetzung eines
Layoutdurchgangs zustellen. Die Prüfung am Arbeitscheckpoint und nach dem
CSS-State-Flush verhindert dann trotzdem die Veröffentlichung dieses Durchgangs.
Nach dem Loslassen erfolgt gegebenenfalls ein vollständiger Recoverydurchgang
mit der letzten angeforderten Breite/Höhe. Eine begonnene CSS-Rekaskade beendet
weiterhin ihr kohärentes Style-Batch, bevor die Geometriearbeit abbricht.

Auch `FlushScriptLayout` respektiert diesen ausdrücklich gewählten Hostmodus:
Geometrieabfragen erzwingen während des gehaltenen Griffs kein neues Layout und
verwenden die vorhandene Boxgeometrie. Ausstehende DOM-Batches bleiben bis zur
Freigabe im Worker; beginnt das Ziehen erst innerhalb eines laufenden Flushs,
wird bereits angewendete Arbeit für die Recovery bewahrt. Die physische
Viewportgröße bleibt über `GeometryViewport` lesbar. Dies ist die Lade-/
Resizepolitik unseres Roblox-Fensters, keine Behauptung, dass ein Browser beim
nativen Fensterresize dieselbe Wartepolitik verwendet. Außerhalb dieses
Hostgestus bleiben explizite Geometrieabfragen synchron; programmatische und
echte Bildschirmgrößensprünge behalten ihren unmittelbaren Pfad.

`ResizableTestWindow` ignoriert außerdem verspätete Hostmeldungen einer bereits
angepassten Bildschirmgröße. Sie dürfen einen inzwischen gehaltenen Griff nicht
beenden. Nur eine tatsächlich veränderte Hostgröße verwirft dessen alten
Ziehursprung. Maus-/Touch-Freigabe, Fokusverlust und Abbau bleiben wirksam.

[PageResizeGestures](../tests/PageResizeGestures.luau) prüft unmittelbare und
verzögerte Attribut-/Größensignale, Beginn in einer echten Arbeitspause und im
CSS-Publikationsschritt, den tatsächlichen ScriptGeometry-/Geometry-Pfad,
wiederholte synchrone Reads, Start innerhalb von DOM-/CSS-Flushs und genau eine
abschließende Veröffentlichung bei Freigabe. Die Fensterregression ergänzt
unveränderte Hostmeldungen. Die alten Quellen und finalen Testhashes bleiben in
`build/resize-gesture-review/sources.json` erhalten; die unveränderten finalen
Tests mit jeweils nur einer alten Quelldatei sind tatsächlich rot
(`resize-gesture-original-final-full16.log`, `resize-window-original-final-full16.log`).
Die separate JavaScript-Geometrieprüfung besteht mit 14 Browserfällen
(`resize-gesture-geometry-full16.log`). Der gemeinsame Lauf mit 16 betroffenen
Suiten besteht (`resize-gesture-final-sixteen-full16.log`), ebenso die statische
Projektprüfung (`resize-gesture-static-full16.log`) und der Rojo-Build
`build/resize-gesture-ready.rbxlx`. Anschließend ergänzt die echte
`HTMLPageAnimationScheduling`-Regression acht Resize-/Keyframe-Schritte während
eines gehaltenen Griffs; Layout und Geometriebenachrichtigung warten auf Release,
die nativen Objekte bleiben erhalten. Dieser finale Zwei-Suiten-Lauf mit
`PageResizeGestures` besteht ebenfalls (`resize-gesture-real-animation-full16.log`).
Das ist kein Gesamtpass der jetzt 421 registrierten Suiten. Die kontrollierten Schedulerprüfungen
ersetzen keine Messung der Studio-Bildrate oder eine atomare Transaktion aller
nativen GUI-Propertyänderungen.

## Laufende Eingaben und Layoutfortschritt – 13. Oktober 2026

Beim schnellen Ziehen eines Reglers konnte jeder neue `input`-Handler einen
suspendierten Layoutdurchgang abbrechen. Der neue Durchgang begann dann erneut,
bevor die geänderte Balkenbreite veröffentlicht wurde. Der Fehler war dadurch
von der Bewegungsgeschwindigkeit abhängig.

`HTMLPage` lässt einen laufenden Durchgang jetzt fertig werden, wenn das
ausstehende JavaScript-Batch ausschließlich `style`-/`class`-Attribute und
Textänderungen mit einem vorhandenen Renderbesitzer enthält. Diese Änderungen
werden erst durch den nächsten `Flush` in den Renderbaum übernommen; bis dahin
arbeitet der Durchgang mit seinen bisherigen berechneten Styles und Textläufen.
Der bestehende Worker übernimmt danach die zusammengefassten neuesten Werte.
Struktur, andere Attribute, Stylesheets, unbekannte Änderungstypen, Resize und
Disposal behalten ihren Abbruch-/Recoverypfad. Die Änderung entfernt weder die
CPU-Pausen noch fordert sie ein synchrones Layout bei jedem Pointerereignis an.

Die endgültige `PageLoading`-Regression sendet bei **jeder** kooperativen Pause
weitere Stil- oder Klassen-/Textänderungen. Sie verlangt drei Veröffentlichungen
während der laufenden Eingabe, einen begrenzten Passzähler, die korrekte letzte
Prozentbreite und dieselbe GUI. Weitere Fälle prüfen Abbruch und vollständige
Recovery bei Struktur-/Attribut-/Viewportänderungen sowie Disposal. Die
Vergleichsseiten-Regression bewegt außerdem den tatsächlichen `RangeDrag`
rasch hin und her, führt das ausgelieferte JavaScript aus und prüft den neuesten
Wert, die Balkenbreite und erhaltene Slider-/Balkenobjekte.

Der unveränderte finale Test mit dem vorherigen Worker scheitert nach 2048
Pausen ohne Fortschritt (`build/continuous-slider-final-fixture-original-full16.log`).
Der BUILD-Runner ersetzt nur diese eine Workeränderung; Produktionsdateien
bleiben unberührt. Quelle und Testhash stehen unter
`build/continuous-slider-review/sources.json`. Elf gezielte Nachbarsuiten,
statische Projektprüfung und Rojo-Build bestehen mit tatsächlichem Exit 0:
`continuous-slider-final-neighbors-full16.log`, `continuous-slider-static-full16.log`
und `continuous-slider-rojo-full16.log`. Das ist kein Gesamtpass aller Suiten
und keine Messung der Bildrate in Studio.

## 12. Oktober 2026: initiale Poster-Präsentation

[HTMLPage](../src/HTMLEngine/Rendering/HTMLPage.luau) hält die anfängliche
Ladefläche auch ohne Realm, solange ein aktuelles Videoposter aussteht. Erfolg,
Fehler, Entfernung und Ersatz einer Anfrage wecken danach den vorhandenen
Präsentationspfad. Bereits sichtbare Seiten werden bei späteren Posterwechseln
nicht wieder verborgen; zwei gleichzeitige Poster geben jeweils nur ihre eigene
Lade-Lease frei.

Ein lokaler, geschachtelter Publikationszähler schützt die vollständige
Posteränderung. Das letzte Cancel darf die Seite nicht freigeben, während
`RefreshDOMResources` beim tatsächlichen SVG-Klonen noch kooperativ wartet.
Eine äußere leere Posteränderung löscht außerdem nur ihre eigene Lease, nicht
eine im Ressourcen-Callback neu angelegte. Der Zähler wird auch bei Fehlern
ausgeglichen; nil, false und die ursprüngliche Tabellenidentität bleiben erhalten.
Laufende Scheduler- und synchrone Geometrie-Flushes sperren die Präsentation
ebenfalls: `Runtime.Flush` hat seine Pending-Tabelle bereits geleert, bevor die
Ressourcenpublikation abgeschlossen sein muss. Ihre vorhandenen Abschlusswege
wecken die Prüfung erneut, ohne zusätzliche IO oder erzwungenes Layout.

[PosterPresentation](../tests/PosterPresentation.luau) prüft 52 montierte Fälle
über VideoPlayer und VideoFrame, 162 Präsentationskontrollen und 3.901 Assertions.
Der echte `RenderWorkBudgetMS=4`-Pfad wartet in `SVGImages.AddItems` /
`Embedded.document`, bevor der SVG-Updater registriert oder ein Raster angefordert
wird. Abbruch, verschachtelte Änderung, Fehlerausgleich, Sichtbarkeit,
SVG-/Hintergrund-/Composite-Gates und beide tatsächlichen Realm-Flushwege sind
geprüft. Die SVG-Style-/Rasterqueue und nativen Medien-/GUI-Dienste sind kontrolliert.
Dies belegt die atomare initiale Engine-Präsentation, keine vollständige
progressive HTML-Paintregel oder native Studio-/Pixelparität.

Der unabhängige 17-Suiten-Lauf endet mit tatsächlichem Exit 0
(`build/core-poster-independent-seventeen.log`), einschließlich der erforderlichen
kompakten Ressourcen-/Auswahlkernprüfungen und frischen isolierten GC-Tails.
Bei der Promotion blieben die 19 übrigen gehaltenen SOURCE-/Video-/MediaLive-Dateien
bytegenau erhalten. Der anschließende vierzehnte Gesamtlauf besteht mit
tatsächlichem Exit 0: 366 Suiten einschließlich 13 isolierter GC-Prüfpfade;
1.680 Quell-/Test-/Fixturedateien, sieben Projekte und 63 aktuelle Holds sind
danach unverändert bestätigt (`build/html-full14-acceptance.json`). Dies bleibt
eine CLI-Abnahme des geprüften Teilstands. Der [VM-freie Auswahlkern](JAVASCRIPT-AUDIO-20261006.md#vm-freier-auswahlkern-und-audio-reentranz--12-oktober-2026)
hat eigene Zustands- und Besitznachweise. Die danach separat eingebaute
[Audioauswahl ohne Realm](JAVASCRIPT-AUDIO-20261006.md#audioauswahl-ohne-javascript-realm--12-oktober-2026)
verwendet denselben Kern und den vorhandenen WorkContext für Ladefortsetzungen.
Ihre FIFO-Queues entnehmen Tasks mit konstantem Aufwand; Abbau während einer
Pause beendet weitere Auswahl/IO und gibt die Workregistrierung frei. 37 montierte
Kontrollen mit zwei Work4-Abbruchvarianten und der anschließende Produktionslauf
mit 18 betroffenen Suiten bestehen. Die vorhandenen Audiotimer werden nicht um
einen weiteren Idle-Scan ergänzt. Arbeit nach initialer Präsentation, allgemeine
Seiten-/Realm-GC und Videoauswahl bleiben offen. Der folgende AudioHost-Nachtrag
belegt die Freigabe seiner eigenen Besitzerbezüge vor Native-Resume separat.

## 12. Oktober 2026: AudioHost während gehaltenem Preload

Der [AudioHost-Nachtrag](JAVASCRIPT-AUDIO-20261006.md#audiohost-freigabe-und-neue-ladeversuche--12-oktober-2026)
trennt Host-eigene Seiten-/Baum-/Session-/Callbackbezüge beim Abbau, ohne auf
ein ununterbrechbares natives Audio-Preload zu warten. Gelöschte kleine Slots
verhindern auch bei behaltenem Adapter oder noch nicht gestarteter Queue die
Bindung des alten Besitzergraphen. Eine private Versuchsidentität schützt
zusätzlich vor synchroner Resolver-/Stop-Reentranz bei gleicher Generation.
Vorhandene Sounds, Cache, Zeitposition und Timer bleiben erhalten; keine
zusätzliche DOM-Suche oder Idle-Schleife wird eingeführt.

Nach unabhängigem Review bestehen produktiv 23 Kontrollen/220 Assertions mit
echtem MediaBox-Code und separat 27 Kontrollen/282 Assertions im verpflichtenden
kompakten Lifetime-Runner. Das unveränderte GC-Budget und gleich alte unabhängige
Kontrollen verlangen Sammlung vor Native-Resume. Der gemeinsame Produktionslauf
mit 19 betroffenen Suiten endet mit tatsächlichem Exit 0
(`build/audio-host-production-focused-first.log`). Natives Preload selbst kann
seinen Sound bis zur Rückkehr halten; physische Abbruchfähigkeit, gesamte
Page-/Realm-/WorkContext-/GPU-Sammlung und native Studio-Speichermessung sind
dadurch nicht nachgewiesen. Die getrennte montierte Gesamtseiten-Diagnose bleibt
erhalten und ungeprüft; eine dort ebenfalls gehaltene gleich alte Plain-Kontrolle
verhindert eine belastbare Host-Retainer-Zuordnung.

## 12. Oktober 2026: Ressourcenbesitzer während gehaltener nativer Arbeit

`ResourceLoadHost` hielt eine entsorgte Seite über Worker-/Subscriberclosures
fest, bis ein bereits gestartetes natives Preload/Decode zurückkehrte. Reentry
konnte einen temporären Target zweimal zerstören oder nach Dispose noch IO
starten. Guarded Publication allein verhinderte diese Besitzerbindung nicht.

Ein kleiner Lebenszyklusdatensatz besitzt jetzt den Seitenbezug und trennt ihn
beim Abbau. Requests, Cache-Subscriber und der gerade ausgelieferte Batch geben
Callbacks sofort frei. Behaltene Cancelhandles besitzen nur ihren kleinen Slot.
Temporäre Targets werden vor ihrem externen Destructor übernommen; Alivechecks
nach Resolver/Factory/Preload/Decode verhindern weitere Arbeit nach Reentry.
Erfolgs-Cache, Grenze 128, Retryfähigkeit und verzögerte Auslieferung bleiben
erhalten; es entstehen keine Idle-Scans oder versteckte Realms.

Ein werfender Subscriber bleibt fail-fast: der übrige Batch wird zuerst freigegeben,
dann der ursprüngliche Fehler weitergeworfen. Beim Hostabbau werden trotz eines
werfenden Destructors alle Targets versucht, danach der erste ursprüngliche
Fehler weitergegeben. nil, false und Tabellenidentität bleiben erhalten.

[ResourceLoadHostLifetime](../tests/ResourceLoadHostLifetime.luau) prüft neun
unveränderte Rot-/Grünkontrollen, sieben Zusatzfälle und sechs Fehlerwertkontrollen
im [kompakten offiziellen Luau-Runner](../scripts/run-resource-load-host-lifetime-tests.cjs).
Der Haupttestlauf führt diesen Runner beim Gesamtlauf und bei ausdrücklicher
Einzelanforderung der Lifetime-Suite zwingend aus. Die [montierte Prüfung](../tests/ResourceLoadHostLifetimeRendering.luau)
läuft getrennt, um den GC-Zyklus nicht vom Heap anderer Layouts abhängig zu machen.
Sie verwendet eine tatsächliche no-JS HTMLPage mit gehaltenem Videoposter-Preload
und `RenderWorkBudgetMS=0`, also ohne WorkContext:
PageSession/Root/Tree/Item/Host sammeln vor Resume; Plain-Sentinel sammelt ebenfalls.
Nach Resume genau eine native Freigabe und keine Veröffentlichung, 32 Assertions.
Der unabhängige gemeinsame 18-Suiten-Lauf besteht mit tatsächlichem Exit 0;
die vier gehaltenen Lifetime-Dateien sind anschließend unverändert.

Die native Operation selbst bleibt ununterbrechbar. Dieser Nachweis betrifft
Host-eigene Bezüge und einen tatsächlichen no-JS-Poster-Abbau, nicht alle
Seiten-/Realm-/WorkContext-Kontexte, externe Service-Retainer oder Studio-GPU-
Speicher. Frühere rote Belege bleiben erhalten; die engen Attributezuordnungen
stehen im [Attributprofil](HTML-PARSER-ATTRIBUTES-20261006.md#seitenabbau-während-nativer-bildarbeit--12-oktober-2026).

## 8. Oktober 2026: Details und äußeres Shadow-Thema

„Die entscheidenden Regeln“ ändert das native `open`-Attribut; „Äußeres Thema
wechseln“ ändert eine Klasse am Vorfahren eines Shadow-Hosts. Beide Änderungen
lösten bislang die gewöhnliche Kaskade und die Pseudoprüfung für die gesamte
Atelier-Seite aus. Klassenänderungen am Host führten zusätzlich zur erneuten
Shadow-Scope-/Stylesheet-Sammlung, obwohl sich weder Struktur noch Slots änderten.

Die normale DOM-Kaskade kann jetzt Klassen, IDs, `open` an Details und
`data-*`-/`aria-*`-Attribute auf die betroffene Teilstruktur begrenzen. Der erste
alte Attributwert eines Batches bleibt vor reentranten Custom-Element-Reaktionen
erhalten. Bei Klassen werden die tatsächlich hinzugefügten/entfernten Tokens
ausgewertet; ein unverändertes Token in einem fremden `nth-child(... of ...)`
erzwingt dadurch keine globale Prüfung. Direkte Attributselektoren bleiben
konservativ. Relevante `:has`-Vorfahren, Geschwister, Filter, Scope-Grenzen und
Slot-Selektoren behalten die umfassende Kaskade. Der Transform-Schnellpfad
übernimmt diese Attributänderungen nicht.

Shadow-Scope-Sammlung bleibt für Struktur und Slot-Zuordnung aktiv. Reine
Styles, Klassen und Texte lösen sie nicht aus; echte Stylesheetänderungen
behalten ihren eigenen Kompilierungspfad. Die Dirty-Ownership-Tabelle bleibt
bei reinem Paint erhalten. Neue Text-/Strukturressourcen, Geometrie sowie
Opacity-/Position-/ZIndex-Abhängigkeiten aktualisieren sie weiterhin.

| Tatsächlicher Atelier-Klick | Gewöhnliche Styles vorher → jetzt | Pseudoprüfungen vorher → jetzt | Zusätzlicher Nachweis |
| --- | ---: | ---: | --- |
| „Die entscheidenden Regeln“ öffnen | 791 → 29 | 2.138 → 12 | Teil-Layout; 165 Layout-Aufrufe, 266 Cache-Treffer |
| „Äußeres Thema wechseln“ | 791 → 34 | 2.138 → 30 | 0 Stylesheet-Neusammlungen; kein Layout; GUI und Ownership bleiben erhalten |

Das Aufklappen ändert tatsächlich die Höhe und damit abhängige Grid-/Flow-
Geometrie. Die 29 Stilauflösungen sind keine 29 Layout-Aufrufe. Layout und
Counter-/Quote-Reihenfolge werden nicht zur vermeintlichen Beschleunigung
übersprungen. Die zuvor fehlende blaue `[open]`-Darstellung und der native/JS-
Attributpfad sind im [Atelier-Profil](CSS-ATELIER-20261007.md) dokumentiert.

`ScriptTransforms` vergleicht 16 Klassen-Selektorkombinationen nach Hinzufügen,
Entfernen und mehreren Schreibvorgängen mit einem unabhängigen vollständigen
Aufbau; es prüft außerdem reentrante Attributreaktionen. `JavaScriptShadowMutations`
prüft lokale Paint-/Textänderungen ohne Stylesheet-Sammlung sowie weiterhin
funktionierende Slot-/Strukturänderungen. Die tatsächlichen beiden Atelier-
Callbacks prüfen Farben, Rahmen, Rücksetzung, Geometrie-/GUI-Identität und
Arbeitsobergrenzen. Das gezielte Protokoll steht unter
`build/css-atelier-details-theme-focused.log`; die funktionale SVG-Regression
bestand in `build/css-atelier-details-theme-svg.log`. Zusätzlich bestanden alle
261 registrierten HTML-/CSS-/JavaScript-Suiten einschließlich der isolierten
GC-/DOM-Prüfungen, Projekt-/Dokumentprüfung, acht Dokumentationstests und der
Rojo-Build `build/css-atelier-details-theme-review.rbxlx`. Diese Nachweise garantieren
weder sämtliche möglichen Kombinationen noch native Ruckelfreiheit; den
Studio-Vergleich übernimmt Tobias.

## 8. Oktober 2026: verbleibende Arbeit bei Farbänderungen

Nach der Begrenzung gewöhnlicher Stilauflösungen meldete Tobias weiterhin
kurze Ruckler beim Variablen-Haken und „Wert für color“. Zwei zusätzliche
globale Arbeitspfade wurden eingegrenzt:

- `GeneratedContent.update()` behält bei lokaler Invalidierung die berechneten
  Styles unveränderter Pseudoelemente, einschließlich zuvor fehlender Pseudos.
  Betroffene Elemente und tatsächlich neu berechnete Erben werden weiter
  abgeglichen. Der Counter-/Quote-Durchlauf bleibt vollständig in Flat-Tree-
  Reihenfolge: Ein lokaler Counter-Increment kann folgende Nummern ändern,
  ohne deren Pseudostyles erneut zu kaskadieren. Strukturaufbau und ausdrücklich
  frische Durchläufe verwenden weiterhin die vollständige Stilprüfung.
- Der SVG-CSS-Host prüft bei lokaler Stilpublikation nur SVGs mit betroffenem
  Ursprung, Vorfahren oder inneren Elementen. Globale Stylesheet-/Medienpfade
  behalten den vollständigen Abgleich. Unbeteiligte SVGs führen dabei weder
  einen Deklarationsscan noch Raster-/Uploadarbeit aus.

Eine unbenutzte Custom Property ist außerdem von gewöhnlicher Text-/Box-Paint-
Arbeit getrennt. Vererbung, generierte Inhalte, Animationen und aufgelöste
Verbraucher bleiben aktiv; SVG behält zusätzlich seine eigene Rohwerte-Pipeline.

Der kontrollierte CLI-Vergleich in derselben Atelier-Seite ergab:

| Callback | Bisherige globale Pseudoprüfung | Begrenzte Pseudoprüfung |
| --- | ---: | ---: |
| Variablen-Haken | 2.213 | 12 |
| Farbwert mit synchronem `getComputedStyle()` und Erklärungstext | 4.420 | 6 |

Die bisherigen gewöhnlichen Stilauflösungen allein hatten diesen Aufwand
nicht gezeigt: Im neuen Lauf sind es 27 beim Haken und 51 beim Farbwert.
Die Zahlen zählen `Stylesheet.matchPseudo`-/`InlineStyle.resolve`-Aufrufe,
keine FPS. Der Vergleich ließ nur die neue Pseudostil-Wiederverwendung im
Testbundle aus; Farb-/Text-/Geometrieprüfungen blieben erhalten. Quellen und
Ausgaben liegen unter `build/css-atelier-global-pseudo-baseline.*` und
`build/css-atelier-local-paint-final.log`.

Regressionen prüfen den tatsächlichen Callback, aktuelle berechnete Farben,
Counteränderungen nachfolgender Geschwister, generierte Variablentexte und
behaltene GUI-/Eingabeidentität. Der SVG-Test prüft außerdem echte Rasterpixel
bei geänderten Vorfahren, inneren Elementen und globalem Abgleich sowie fehlende
Arbeit bei unbeteiligten Änderungen. 16 gezielte HTML-/Layout-/Animationssuiten
und die funktionale SVG-Suite bestanden. Ob der verbleibende native Ruckler
verschwindet, ist erst nach dem nächsten Studio-Vergleich bestätigt.

## 8. Oktober 2026: lokale CSS-Variable und Text im selben Klick

Der CSSAtelier-Haken „Die Variable auf eine gültige Farbe setzen“ ändert im
selben JavaScript-Callback `--farbe` auf `#var-panel` und den Erklärungstext
seines Kindes. Die bisherige DOM-Stilinvalidierung begrenzte reine Inline-
Stiländerungen, stufte jedoch jede zusätzliche Textänderung als Anlass für
eine Stilprüfung der gesamten Seite ein. Das verursachte auch ohne vollständigen
Layout-Neuaufbau unnötige Arbeit beim Klick.

`ScriptTransforms.Scope()` kann für die normale DOM-Aktualisierung jetzt
Textänderungen im selben Batch berücksichtigen. Vererbte Farben und Variablen
werden weiter in die betroffene Teilstruktur übertragen. Der direkte
Transform-Painter bleibt ausschließlich für reine Stiländerungen verfügbar,
damit er keine Textaktualisierung überspringt. Strukturelle Änderungen, andere
Attribute sowie textabhängige `:empty`-/automatische `:dir`-Selektoren behalten
die umfassende Invalidierung. Die Abhängigkeitssuche erfasst auch verschachtelte
Selektoren, `nth-child(... of ...)`, `@scope`-Grenzen und Shadow-Selektoren.

Der tatsächliche Atelier-Callback benötigte im Luau-Test **28 statt 791
Stilauflösungen**. Das zählt Aufrufe von `InlineStyle.resolve`, keine FPS und
keine native Framezeit. Die weiterhin nötige Prüfung generierter Inhalte ist
enthalten; der Pfad wird nicht als vollständig arbeitsfrei ausgewiesen. Eine
längere Erklärung kann zudem einen lokalen Textumbruch erfordern. Unbeteiligte
GUI-Flächen und Layout-Caches bleiben erhalten.

`CSSAtelierWebsite` prüft den Originalcallback in beiden Richtungen, Farbe,
Erklärungstext, Ressourcenidentität und eine Obergrenze für Stilauflösungen.
`ScriptTransforms` deckt gemischte Transform-/Textänderungen, Textknoten,
vererbte Variablen, Filter- und Scope-Selektoren sowie automatische Textrichtung
ab. `JavaScriptStableGeometryRendering` vergleicht die behaltene Geometrie
zusätzlich mit einem unabhängigen vollständigen Layout. Die Wirkung auf den
gemeldeten kurzen Ruckler ist im nächsten Studio-Vergleich zu bestätigen.

## 8. Oktober 2026: SVG-Aufbauzeit und große Rahmenatlanten

Der nächste CSSAtelier-Start erreichte `Seite bereit` ohne den zuvor gemeldeten
CoreGui-Timeout. Die kalten Imports dauerten 7548 ms einschließlich der
erzwungenen Pausen; die einzelnen `require`-Aufrufe summierten sich auf 715 ms.
Das ist ein erfolgreicher gemeldeter Lauf, kein allgemeiner Nachweis ruckelfreier
nativer Ausführung. Der längste Import benötigte weiterhin 57 ms.

Die gemeldeten 16180 ms SVG-Aufbau waren Gesamtzeit einschließlich kooperativer
Ladepausen und der Arbeiten anderer Jobs während dieser Pausen. Der Demo-Client
druckt jetzt auch die vorhandenen `BuildActiveMS` und `BuildWaitMS`. Die Differenz
ohne Ladepausen ist ebenfalls keine reine CPU-Messung: Wartezeiten in nativen
Aufrufen, die nicht über den WorkContext laufen, können darin enthalten sein.
Budget und Bildqualität werden dafür nicht geändert.

Ein weiterer gemeldeter Fehler war konkret reproduzierbar: Bei großen gerundeten
Flächen mit `overflow:hidden` konnte der vertikale Atlas aus Hintergrund,
Clipmaske und Rand bis zu 512 × 1536 Pixel groß werden. Die
[EditableImage-Grenze](https://create.roblox.com/docs/reference/engine/classes/EditableImage)
beträgt 1024 × 1024 Pixel. Solche Atlanten verteilen die Ebenen nun über Spalten:
schmale Flächen verwenden drei Spalten, breite Flächen ein Raster mit zwei
Spalten und zwei Zeilen. Kleine Flächen behalten den bisherigen vertikalen
Atlas. Die vorhandene Rasterauflösung bleibt erhalten, sofern der bestehende
6-MiB-Radiuscache reicht; eine freie Rasterzelle wird im Pixelbudget mitgezählt.
Bildrechtecke und Pixeloffsets verwenden dieselbe Packung. Ein Größenfehler
darf dadurch den Rahmenrenderer nicht mehr in seinen rechteckigen Ersatzpfad
versetzen.

`BorderCorners` prüft die vollständige native Größenbegrenzung, breite und
schmale hohe Masken, transparente Zentren, Randfarbe, Cachewiederverwendung und
den Wechsel zurück zu kleinen Flächen. Zusammen mit `LoadingTextures`,
`RenderingLifetimes`, `PageLoading`, `PageLifecycle` und `CSSAtelierWebsite`
bestand der gezielte Testlauf in `build/css-atelier-atlas-review.log`.
Die tatsächlichen Warteanteile und die Darstellung in Studio müssen im
nächsten Nutzervergleich bestätigt werden.

## 7. Oktober 2026: kalte Imports und CSS-Arbeitsabschnitte

Nach dem CSSAtelier-Start wurden native CoreGui-Timeouts gemeldet, bevor
`Website geladen` erschien. Dieser Stack belegt keine bestimmte Engine-Schleife;
die genaue native Ursache ist noch nicht bestätigt. Der Startpfad ist jetzt
zusätzlich abgesichert:

- Der Demo-Client gibt vor dem ersten Engine-`require` einen Frame zurück.
- Bei aktivem Ladebudget erhalten kalte Modulimporte jeweils eine erzwungene
  Ladepause; auch sehr schnelle Imports werden nicht im selben Aufruf gehäuft.
  Bereits geladene Abhängigkeiten werden bei späteren Mounts weiterhin übersprungen.
- CSS-Kompilierung, Stilauflösung und lange Deklarationsblöcke nutzen den
  vorhandenen Coroutine-Ladescope. Direkte Aufrufe und spätere Interaktionen
  bleiben ohne Ladescope synchron. Abbruch, Reihenfolge und atomare Veröffentlichung
  bleiben erhalten; es gibt keine neue dauernde Frameloop.
- `page.ColdLoadStats` nennt Importzahl, Gesamtdauer mit Pausen, Summe und
  längsten einzelnen `require`-Aufruf. `page.BuildStats` trennt Parsing,
  Metadaten, CSS/GUI-Aufbau und JS-Start. Der Demo-Client druckt diese Daten
  einmal beim Start. Das sind Laufzeiten einschließlich nativer Wartezeiten,
  keine FPS- oder reinen CPU-Messungen.

Ein einzelner nativer Kompilierungs-/`require`-Aufruf bleibt nicht unterteilbar.
Die nächste Studio-Ausgabe muss daher zeigen, ob die gemeldeten Timeouts damit
wegfallen und welcher Schritt gegebenenfalls weiter auffällt.
[ModuleScript](https://create.roblox.com/docs/reference/engine/classes/ModuleScript)
und [task.wait](https://create.roblox.com/docs/reference/engine/libraries/task/wait)
beschreiben die zugrunde liegenden Host-Aufrufe.

`EngineEntry` prüft die erzwungenen Pausen auch bei Imports unterhalb der
CPU-Frist und das Überspringen auf einem warmen Mount. `LoadingWork` vergleicht
lange CSS-Blöcke mit synchronem Ergebnis. Die tatsächliche Atelier-Seite,
Ladeflächen-/Lifecycle-Prüfungen und funktionale SVG-Regression ergänzen dies.
Die Atelier-Quellen verwenden `@supports` für Fontachsen und Snapshotregeln;
die früheren Warnungen dafür werden nicht durch vorgetäuschte Unterstützung ersetzt.

## 5. Oktober 2026: längeres Laden mit kleineren Arbeitsabschnitten

Der erste Aufbau einer Seite erhält standardmäßig **höchstens 2 ms als Ziel
pro kooperativem Arbeitsabschnitt**. `WorkContext` teilt den nativen
Heartbeat-Rahmen zwischen gleichzeitig ladenden Dokumenten, Layoutjobs und
SVG-Jobs. Ein neuer Job setzt die verbleibende Frist eines anderen Jobs nicht
zurück. Die nächste Fortsetzung wartet auf einen weiteren Frame. Es ist ein
Ziel zwischen Checkpoints, kein harter Grenzwert für einen einzelnen Aufruf.

Die Pausen umfassen HTML-/CSS-Parsing, Dokumentmetadaten, CSS-Matching,
Renderbaum und GUI-Erzeugung, JavaScript-Parsing, Bibliotheksinstallation und
Skriptausführung, initiales Layout sowie SVG-Klonen, Szenenaufbau,
Pfadgeometrie, Hitboxen, Raster und Cache-Kopien. CSS-Verläufe, Masken,
Rahmen, Perspektive und Schatten pausieren ebenfalls beim Pixelaufbau.
Texturen werden im Ladescope mit höchstens 64 KiB je Upload-Streifen
übertragen; der letzte Streifen enthält exakt seine verbleibenden Zeilen.
Die vollständige SVG-Textur wird erst danach als fertig gemeldet. Pixel,
Auflösung, Antialiasing, DOM-Reihenfolge und Layoutregeln bleiben erhalten.

Der erste `Engine.mountHTML()`-Aufruf lädt die statischen Abhängigkeiten von
HTMLPage in Abhängigkeitsreihenfolge mit einem Checkpoint pro Modul. Die Liste
`Rendering/LoadingModules` wird mit `node scripts/export-loading-modules.cjs`
erzeugt und von der Projektprüfung auf Aktualität geprüft. Weitere Mounts
überspringen diese Liste. Moduldefinitionen erzeugen keine Seiten oder
Eingabeverbindungen.

Die neue Seite bleibt bis zum ersten stabilen Layout, den sichtbaren SVGs und
den ausstehenden DOM-Änderungen hinter ihrer weißen Ladefläche. Beim Laden
entsteht diese Fläche bereits vor dem HTML-Parsing. Resize und spätere
DOM-Änderungen schalten die Ladefläche nicht wieder ein. SVG-Vorbereitung von
Hoverzuständen darf nach dem Einblenden weiterlaufen; auch ihr Szenenaufbau
bleibt dabei kooperativ. Bereits gestartete private Arbeiten behalten ihre
Pausen bis zum Ende, selbst wenn die Präsentation ihre Lade-Lease beendet.
Texturänderungen an bereits sichtbaren SVGs werden vollständig in einem
Upload veröffentlicht; Hintergrundvorbereitung zeigt keine halben Bildstände.

Ladescopes gehören zum jeweiligen Coroutine-Aufruf. Direkte Parseraufrufe
bleiben synchron; nach dem Einblenden wird für normale JS-/GUI-Arbeit kein
Ladescope geöffnet. Async-/Generator-Stacks leiten CPU-Pausen über ihren
Host-Aufruf weiter, sodass daraus kein falsches `await` oder `yield` entsteht.
Ein Abbruch während der Realm-Konstruktion lässt die private Konstruktion
weiter in Abschnitten bis zum vollständigen Destruktor laufen und entsorgt
den unveröffentlichten Realm sofort. GUI-/Texturressourcen werden beim Abbruch
freigegeben. Aufbaufehler werden von echten Abbrüchen getrennt und gemeldet.
Die zusätzliche Heartbeat-Verbindung wird entfernt, sobald die letzte
Lade-Lease und ihre bereits laufenden Arbeiten beendet sind.

`RenderWorkBudgetMS` begrenzt wie bisher reguläres Layout. Beim ersten Laden
verwendet die Engine `min(2, RenderWorkBudgetMS)`; `0` deaktiviert diese
kooperativen Ladepausen ebenfalls. Die längere Ladezeit ist hier ausdrücklich
beabsichtigt. Es gibt keine zeitgesteuerte Resize-Neuberechnung als Nebenwirkung.

`page.LoadStats` hält die bisherigen Runs, Pausen, Wartezeit und längsten
gemessenen Abschnitt. Diese Werte schließen nur die expliziten kooperativen
Pausen aus: native Asset-/Textdienst-Wartezeiten können in den übrigen Zeiten
enthalten sein. Sie sind **keine FPS- oder exakten CPU-Messwerte**. SVG-Statistiken
trennen zusätzlich `BuildMS`, `BuildActiveMS` und `BuildWaitMS`; Pixelrasterzeiten
behalten ihre Trennung von Arbeit und explizitem Warten.

Einzelne Roblox-Aufrufe wie Modulkompilierung, `Instance.new`, Textmessung,
`CreateEditableImage`, Bilddownloads und GPU-/GUI-Verarbeitung können in Luau
nicht beliebig unterteilt werden. Die Änderungen beseitigen große eigene
Arbeitsblöcke, garantieren aber keine absolute Ruckelfreiheit der nativen Engine.
Die tatsächlichen Framezeiten beim kalten Laden prüft der Nutzer in Studio.

`LoadingWork`, `LoadingTextures`, `EngineEntry` und `PageLoading` prüfen
deterministisch geteilte Fristen, Scope-/Listener-Lebensdauer, kalte Imports,
unsichtbaren Aufbau, Abbruch, bytegleiche Raster-/Uploaddaten,
Async-/Generator-Reihenfolge und fortlaufende SVG-Vorbereitung. Animationen
und inkrementelles Layout behalten ihre eigenen Regressionen. Es werden
keine nativen FPS-Benchmarks ausgeführt.

## Frühere Optimierungen

Stand: 10. September 2026. Drei Änderungen sind umgesetzt:

1. **Schriften früh anfordern.** `RenderTree` setzt den endgültigen FontFace bereits beim
   Erzeugen der Wort-Labels. `FontPreload` übergibt vor dem ersten Layout je ein bestehendes
   Label pro verwendeter Textschrift/Variante gemeinsam an `ContentProvider:PreloadAsync`.
   Unsichtbare Teilbäume und unbenutzte Katalogschriften werden nicht vorgeladen. Das Layout
   wartet nicht zusätzlich auf den gesamten Preload; seine Textmessungen behandeln Ladefehler
   weiterhin selbst. Vorladen ist best effort. Nach Seitenabbau werden keine neuen Aufträge
   gestartet und keine späten Diagnosen geschrieben. Bereits laufende Roblox-Downloads können
   nicht abgebrochen werden. Nur in Leerraum verwendete Varianten werden weiterhin bei ihrer
   individuellen Messung geladen.
2. **Font-Konfigurationen pro Seite wiederverwenden.** `FontProfiles.newResolver()` hält je
   Familie die verwendeten Kombinationen aus neun Roblox-Gewichten und normal/italic. RenderTree und WordLayout
   verwenden denselben Resolver. Die öffentliche `face()`-Funktion liefert weiterhin frische
   Font-Werte; andere Seiten teilen diesen Cache nicht. Es werden keine Textmaße zwischen
   Wörtern oder Seiten geteilt. Wort- und Leerzeichenmessschlüssel bleiben vollständig erhalten.
3. **CSS-Werte einmal parsen.** `InlineStyle.compile()` bereitet unveränderliche Deklarationen
   vor. `Stylesheet.collect()` ruft dies einmal pro Regeltext auf, auch bei Kommagruppen. Beim
   Selektormatching werden Referenzen auf vorbereitete Werte gesammelt. Normal/important,
   Spezifität, Quellreihenfolge und Inline-Vorrang bleiben erhalten. Veränderliche Werte wie
   Margin/LineHeight werden pro Element kopiert; Prozent-Zeilenhöhen erst nach Anwendung aller
   Deklarationen berechnet. Diagnosen entstehen weiterhin erst bei tatsächlicher Anwendung.

`Syntax.declarations()` liefert intern Text und Important-Markierung; `Stylesheet.match()`
liefert Normal-/Important-Gruppen statt zusammengeklebter CSS-Zeichenketten. Der DOM bleibt unverändert.

## Prüfung

`tests/LoadOptimizations.luau` prüft Parse-Anzahlen, unabhängige berechnete Styles, CSS-Vorrang,
Font-Konstruktoraufrufe, Seitentrennung, frühe Font-Zuweisung, Einzelmessungen und Preload-Abbruch/
Fehlerbehandlung. `tests/PageLifecycle.luau` prüft zusätzlich die Verbindung zum Mount-Ablauf.
Die gesamte CLI-Testsuite und Syntaxprüfung bestehen.

Ein lokaler Vergleich mit Luau-CLI `-O2`, 1.500 Absätzen, drei CSS-Regeln, zwei Warmläufen und
dem Median aus sieben Gruppen mit je vier Aufbauten ergab:

| CSS-/Baumaufbau pro Durchlauf | Vorher | Nachher |
| --- | ---: | ---: |
| Median auf diesem Rechner | 41,272 ms | 9,435 ms |

Der DOM wurde vorher geparst. GUI-Erzeugung war durch Tabellen ersetzt; Font-Downloads und
Roblox-Textmessung waren nicht enthalten. Dies misst vor allem die vermiedene CSS-Wiederholung,
keinen Gesamt-Ladezeitgewinn in Studio. Der Versuchsaufbau liegt unter `build/benchmark-css-tail.luau`;
die gebündelten Vorher-/Nachher-Stände unter `build/benchmark-css-before.luau` und `build/benchmark-css-after.luau`.
Native visuelle Prüfung und Zeitmessung mit kalten/warmen Roblox-Schriftdateien stehen noch aus.

Grundlage: [Roblox TextService](https://create.roblox.com/docs/reference/engine/classes/TextService)
und [ContentProvider](https://create.roblox.com/docs/reference/engine/classes/ContentProvider).
