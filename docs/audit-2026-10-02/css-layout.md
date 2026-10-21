# CSS und Layout – Audit vom 2. Oktober 2026

99 handgeschriebene Module vollständig gelesen, einschließlich aller 21 Fontprofil-Module. Die JSON-Matrix enthält jedes Modul mit Schnittstellen, direkten statischen require-Abhängigkeiten und Aufrufern. Der Graph deckt keine dynamischen Factory-/Callback-Kanten vollständig ab; diese wurden an den zentralen Cascade-, Layout-, Text- und Scrollpfaden zusätzlich verfolgt. Historische Auditberichte gelten hier nicht als Nachweis. Erst nach Abschluss der globalen Inventur und Root-Freigabe wurden die unten belegten kleinen Reparaturen umgesetzt.

Die aktuellen Fontfaktoren, Profile und Rundungsregeln bleiben unverändert. Weder seitenübergreifende Textmess-Caches noch Virtualisierung werden als Optimierung vorgeschlagen. Testergebnisse sind getrennt vom vollständig abgeschlossenen Lesen zu bewerten: Root führt die koordinierte Baseline aus; hier folgen isolierte Repros. Native Roblox-FPS wurden nicht gemessen.

## Befunde und Reparaturplan

### CL-01 · P1 · Quadratische Arbeit bei langen ungebrochenen Textzeilen

**Fundstelle:** `Layout/WordFlow.luau`, `groupEnd`, `setBounds` und Aufruf in `arrange` (ursprünglich Zeilen 20–31, 56–61, 135–141).

**Ursache:** `boundsFor(item, groupEnd(...))` wertet den gesamten restlichen nowrap/pre-Lauf aus, selbst wenn keine Float-Grenzen existieren und `boundsFor` den Wert sofort verwirft. Für N Wörter sind das N(N+1)/2 Breitenabfragen. Zusätzlich verschiebt `setBounds` bei jedem Wort alle bisherigen Wörter um delta=0: N(N−1)/2 unnötige Positionsschreibvorgänge. Beide inneren Schleifen enthalten keinen kooperativen Work-Checkpoint.

**Auswirkung:** Große nowrap/pre-Abschnitte können auch beim Resize mit bereits gemessenen Wörtern erheblich CPU-Zeit blockieren. Dies ist ein konkreter algorithmischer CPU-Befund; die tatsächliche FPS-Auswirkung hängt vom Seiteninhalt und Roblox-Gerät ab.

**Repro:** Isolierte echte WordFlow-Ausführung mit 1000/2000/4000 unveränderten Wortobjekten, `WrapBefore=false`, ohne lineBounds; Metatable zählt Width-Lesezugriffe und X-Schreibzugriffe. Höhe, Breite und Position jedes Wortes werden als Geometrieoracle verglichen. Danach nowrap unter Float-Grenzen, Tabs/pre-wrap, Inline-Fragmente und Abbruch testen.

**Vorschlag/Risiko:** groupEnd nur berechnen, wenn lineBounds den Bedarf tatsächlich braucht (leere Zeile); setBounds verschiebt vorhandene Worte nur bei delta≠0. Keine gemeinsame Messcache-Einführung. Risiko niedrig bis mittel: Float-Zeilen, Tabstopps und feste Umbrüche erfordern Regressionstests.

### CL-02 · P2 · Gültige `@media all and (...)`-Regeln werden verworfen

**Fundstelle:** `CSS/MediaQueries.luau`, `branch`, ursprünglich Zeilen 107–115.

**Ursache:** Die erste Konjunktion wird nur bei `mediaType ~= "all"` konsumiert; die bereits vorhandene Variable `explicitType` wird hierfür nicht verwendet. `screen and (...)` funktioniert, `all and (...)` nicht.

**Auswirkung/Repro:** `all and (min-width:10px)` kompiliert zu nil statt einer gültigen Bedingung. Responsive Regeln können dadurch dauerhaft fehlen. Zusätzlich `only all`, `not all`, nacktes `all`, mehrere Bedingungen und Bedingungen ohne Medientyp prüfen.

**Vorschlag/Risiko:** `explicitType` für die erste Konjunktion verwenden; Parserregression plus Stylesheet-Neuberechnung. Niedriges Risiko. Root hat denselben Parserfehler separat in ResponsiveSources gefunden und besitzt dessen Reparatur.

### CL-03 · P2 · Zentrierte Clipform in Prozent wird nicht akzeptiert

**Fundstelle:** `CSS/AdvancedVisual.luau`, `clipPath`, ursprünglich Zeilen 81 und 86.

**Ursache:** Direkter Stringvergleich nutzt das Pattern-Escape `"50%% 50%%"`; bei einem gewöhnlichen Stringvergleich ist das ein anderes Literal als CSS `50% 50%`.

**Repro/Auswirkung:** `circle(40% at 50% 50%)` und `ellipse(40% 30% at 50% 50%)` werden abgelehnt, obwohl die gleichbedeutende center-Variante unterstützt ist. Browser-Kompatibilität innerhalb des erklärten zentrierten Profils verletzt.

**Vorschlag/Risiko:** Literal korrigieren und äquivalente Parsedaten testen; außerzentrierte Formen weiterhin nach bestehendem Profil ablehnen. Niedriges Risiko.

### CL-04 · P2 · Tabular-Nums teilt native Messwerte zwischen Elementen und Seiten

**Fundstelle:** `Layout/LetterSpacing.luau`, moduleglobale `digitMetrics`/`digitMetricOrder`, ursprünglich Zeilen 4–23.

**Ursache:** Ein Cache aus `tostring(font)..":"..size` bewahrt zehn native Ziffernmessungen pro Schlüssel über alle Aufrufer. Er ist auf 64 Einträge begrenzt, widerspricht aber ausdrücklich PLAN.md: keine gemeinsamen Textmaß-Caches zwischen Elementen/Seiten. Zusätzlich ist der Schlüssel nicht an Messbackend oder OpenType-Kontext gebunden.

**Auswirkung/Repro:** Zwei unabhängige Elemente mit gleichem Font/Size und bewusst verschiedenen Test-Messfunktionen erhalten dieselben ersten Ziffernmaße. Zweite Funktion wird gar nicht aufgerufen. Dies ist kein belegtes unbeschränktes Speicherleck; der Cache ist begrenzt.

**Vorschlag/Risiko:** Die vorhandene itemeigene Messvalidität in WordLayout nutzen; tabulare Maße nur für den einzelnen vollständig abgeschlossenen Messdurchlauf erzeugen. Bei einer lokalen Wiederverwendung müssten Font, Größe und Messkontext vollständig geprüft werden. Auf Abbruch keine Teilwerte veröffentlichen. Niedriges Layout-, mögliches First-Load-CPU-Risiko bei vielen getrennten Ziffernläufen; bewusst keine verbotene gemeinsame Beschleunigung.

### CL-05 · P2 · Zweiteilige Hintergrundposition wird als Kantenoffset missverstanden

**Fundstelle:** `CSS/Background.luau`, `parsePosition`, ursprünglich Zeile 104ff.

**Ursache:** Eine Zahl nach jedem Positionskeyword wird derselben Achse als Offset zugeordnet. CSS-Zweiteilsyntax `right 10px` bedeutet hingegen x=100%, y=10px; Kantenoffsets gehören zur Drei-/Vierteilsyntax oder explizitem background-position-x/-y.

**Repro/Auswirkung:** `right 10px`, `center 10px` und entsprechende mask-/Gradient-Positionen weichen ab. Bestehende Tests decken `right 10px bottom 20%` ab, nicht diesen Fall.

**Vorschlag/Risiko:** Zweiwerte- und Kantenoffsetsyntax trennen, existierende ObjectPosition-Regeln vergleichen, Browser/Spezifikation als Oracle heranziehen. Mittleres Risiko durch gemeinsam genutzte Gradienten- und Maskenpositionen.

### CL-06 · P2 · Scroll-Tweens haben keinen expliziten Destroy-Eigentümer

**Fundstelle:** `Layout/ScrollLayout.luau`, `scrollToMarker`, `markers`, `snap`; Aufrufer `Rendering/HTMLPage` und `PageSession` vom Root überprüft.

**Ursache:** Boxen speichern Tween und Completed-Verbindung sowie Marker-/CanvasPosition-Verbindungen. Kein ScrollLayout.destroy/cleanup wird beim Seitenabbau aufgerufen. Gui-Zerstörung trennt Gui-Signale, ist aber kein ausdrückliches Cancel eines noch laufenden Tween-Objekts. Completed kann den Boxbaum bis Abschluss halten und `refreshMarkers` nach Seitenabbau anstoßen.

**Repro:** Fake-Tween mit manuell ausgelöstem Completed, smooth scrollToMarker starten, Seite zerstören, Completed auslösen; Cancel/Disconnect zählen und Post-Destroy-Writes verbieten. Echte Roblox-Verifikation bleibt zusätzlich nötig; dauerhafter Leak bislang nicht belegt.

**Vorschlag/Risiko:** Idempotentes `ScrollLayout.destroyTree` trennt Connections, löscht Handles vor Cancel, beendet Tweens und markiert Boxen für spätere Callback-Guards. Root muss es vor Gui-Zerstörung beim Session-Cleanup einhängen. Marker-Stilabschaltung separat prüfen. Mittleres Lifecycle-Risiko; Cancel kann synchron Completed feuern.

### CL-07 · P2 · Scroll-Snap ignoriert einzelne `none`-Achsen

**Fundstelle:** `Layout/ScrollLayout.luau`, `snap`, ursprünglich Zeilen 370–397.

**Ursache:** Ein Kind wird nur übersprungen, wenn beide Alignment-Achsen none sind. Bei `both` verarbeitet `target(..., "none", ...)` die entsprechende Achse wie start.

**Repro/Auswirkung:** `scroll-snap-type:both mandatory` plus `scroll-snap-align:none start` verändert auch Y, obwohl nur die Inline-Achse snappt. Mit asymmetrischer Scrollposition testen.

**Vorschlag/Risiko:** Pro Achse `align.Inline/Block ~= "none"` prüfen. Niedriges Risiko. Weiterer offener Profilunterschied: proximity und mandatory werden gleich behandelt; keinen willkürlichen Pixelthreshold ohne Produktentscheidung einführen. Logische Achsen verwenden das erklärte horizontale Scrollprofil.

### CL-08 · P2/Performance-Kandidat · Style-Matching durchläuft Regeln und DOM breit

**Fundstellen:** `CSS/Stylesheet.luau` `match`, `matchPseudo`, `stateChanges`; `CSS/Selectors.luau` Geschwisterpositionen, `:has` und komplexe Kombinationen.

**Ursache/Auswirkung:** Jedes Element prüft alle Regeln und Pseudoregeln. Zustandsänderungen laufen über den ganzen DOM/Shadowbaum und testen passende State-Selektoren vor/nach Änderung, auch ohne Media-Eignungsfilter. `nth-*`/first/last zählen Geschwister bei jedem Kandidaten erneut; `:has` traversiert Teilbäume. Bei großen Seiten entsteht multiplizierte Arbeit. Konkrete native FPS-Zahl noch unbekannt.

**Vorschlag/Risiko:** Erst Zähler für Element×Regel-Matches, State-Kandidaten und besuchte Geschwister erfassen. Danach unveränderliche Rule-Buckets nach rechtestem id/class/tag plus Fallback und per-Cascade strukturelle Geschwisterindizes. Wichtig: keine selektorfremden gemeinsamen Textmaße; korrekte Invalidierung bei Attribut-, DOM-, Media-, Container- und Shadowänderungen. Hohes Risiko für eine vorschnelle allgemeine Optimierung, daher nicht Teil der kleinen ersten Fixserie.

### CL-09 · Performance-Kandidat · Wiederholte Inline-Compilation und Default-Allokation

**Fundstelle:** `CSS/InlineStyle.luau`, `resolve`, ursprünglich Zeilen 933–1079ff.

Jeder Cascade-Durchlauf baut den großen kompletten Defaultstil sowie eine initial-Kopie auf und kompiliert `node.Attributes.style` neu, auch bei unveränderter Attributquelle. Immutable, nodeeigene Compilation-Wiederverwendung ist möglich; computed Werte, relative Größen und Custom Properties müssen weiterhin pro Cascade berechnet werden. Erst Compile-/Allocationzähler messen. Kein belegter FPSgewinn. Das 1660-Zeilenmodul überschreitet die PLAN-Reviewgröße deutlich; parser/compile/defaults/cascade könnten getrennt werden, aber keine pauschale Dateiteilung mitten in einer Fehlerreparatur.

### CL-10 · P3 · `step-start` und `steps(1,start)` unterscheiden sich bei t=0

**Fundstelle:** `CSS/Motion.luau`, `ease`, ursprünglich Zeile 174.

Direkter `step-start`-Zweig lieferte bei t=0 null, allgemeiner steps-Zweig eins. Die Keywords werden jetzt über denselben Steps-Zweig ausgewertet. [CSS Easing §2.3](https://www.w3.org/TR/css-easing-1/#step-easing-functions) definiert diese Aliase sowie den Before-Flag an Sprunggrenzen. Die Caller-Prüfung fand zusätzlich einen verwandten Fehler: HTMLAnimations klemmte die Zeit vor einem positiven Delay auf null und ließ deshalb `steps(1,start)` schon während des Delays springen. Der optionale Before-Flag wirkt ausschließlich auf Steps; normale cubic-bezier-Kurven und Animationsgeschwindigkeit bleiben unverändert.

Motion.progress gibt den Flag als dritten Rückgabewert zurück, HTMLAnimations berücksichtigt ihn für Transition-Delay, die initiale/pausierte Layoutdarstellung und laufende Animationen. Die Richtung wird gemäß [Web Animations §4.10.1](https://www.w3.org/TR/web-animations-1/#calculating-the-transformed-progress) beachtet: vorwärts vor dem aktiven Intervall, rückwärts nach der letzten Iteration. Die erweiterten vorhandenen Suites Motion/Animations prüfen die Aliase bei 0/.5/1, positive Delays, backwards fill, normal/reverse/alternate-reverse, den Endpunkt und pausierten Anfang. Motion, Animations und HoverTransitionGeometry sind im isolierten funktionalen Lauf mit aktuellem offiziellem Loader grün; die abschließende zentrale Ausführung dokumentiert Root. Kein FPS-Benchmark war hierfür nötig.

### CL-11 · Performance-Kandidat · Vorbereitung besucht trotz Dirty-Reuse den Baum

**Fundstelle:** `Layout/BlockLayout.luau`, Spacing-/Margin-/Inline-Vorbereitung sowie Grid-/Table-Intrinsikpfade.

DirtyLayout kann arrangierte Unterbäume wiederverwenden, aber vorherige vorbereitende Baumgänge und wiederholte intrinsische Messung werden nicht generell vermieden. Das ist zunächst notwendige Arbeit für Abhängigkeiten, kein pauschaler Bug. Messen: Knotenbesuche vor DirtyReuse, Min-/Maxcontent-Aufrufe, verschachtelte Grid/Table-Tiefe, CSS-Mediaänderungen. Wenn belastbar: vorbereitete Werte nur pro Box mit vollständigen Eingabe-Schlüsseln behalten, Dirty-Grenzen an echten Formatierungskontexten. Hohes Korrektheitsrisiko bei relativen Längen/Containern/Floats; nicht blind skippen.

### CL-12 · P3 · Öffentliche Supporttexte sind teilweise überholt

**Fundstelle:** `CSS/Properties.luau` und spätere VisualValues.register-Overrides.

Einige Limits beschreiben einen früheren Stand: z.B. transform-origin behauptet keine Z-/negativen Werte trotz erweitertem Parser, Named-ease sei nur Näherung trotz cubic-bezier-Auswertung, min/max/width-Texte sagen kein calc während RelativeUnits später hinzugefügt wird. Andere Grenzen sind bewusst und verhindern falsche Befunde: Prozent-min/max-height wird öffentlich abgelehnt; deshalb ist dessen interner ImageLayout-Basisverdacht kein aktuell erreichbarer CSS-Bug. Supporttexte sollten nach verifizierten Tests vereinheitlicht werden, ohne browserweite Parität vorzutäuschen.

## Prüfgrenzen

Fontkalibrierungen wurden nur gelesen. Pure-Luau- und Mocktests können Geometrie, Aufrufanzahlen, Cascade und Disconnect-Ownership prüfen, aber nicht tatsächliche Roblox-FPS, GPU-Komposition, echte TextBounds, native Tween-Scheduling oder GUI-Rasterqualität. Diese Punkte bleiben im Gesamtbericht ausdrücklich als Studio-/Profilingprüfung offen.

## Umgesetzt und isoliert überprüft

CL-01, CL-02, CL-03, CL-04, CL-05, CL-06, CL-10 sowie die konkrete none-Achse aus CL-07 sind repariert und isoliert funktional geprüft. CL-08, CL-09, CL-11 und CL-12 bleiben als abgegrenzte Folgebefunde offen. Die Scroll-proximity-Auswahl wurde nicht durch einen erfundenen Abstand ersetzt.

Produktionsänderungen: `Layout/WordFlow`, `Layout/LetterSpacing`, `Layout/ScrollLayout`, `CSS/MediaQueries`, `CSS/AdvancedVisual`, `CSS/Background`, `CSS/Motion`, `Rendering/HTMLAnimations`. Der Root ergänzt den PageSession-Cleanup-Aufruf in HTMLPage. Neue Tests: `tests/CSSLayoutAudit.luau`, `tests/ScrollLifecycleAudit.luau`; erweitert: `tests/Motion.luau`, `tests/Animations.luau`. Der Root registriert und führt die breite HTML-Suite zentral aus. Die isolierten Tests liefen direkt mit `build/tools/luau/luau.exe` und dem vorhandenen offiziellen Testloader, ohne die zentrale Bundle-Datei zu verändern.

Instrumentierte echte WordFlow-Ausführung, unveränderte Geometrie:

| nowrap-Wörter | Width-Lesezugriffe vorher → nachher | X-Schreibzugriffe vorher → nachher | lokale CPU-Laufzeit vorher → nachher |
|---:|---:|---:|---:|
| 1000 | 502500 → 2000 | 501500 → 2000 | 53,9 ms → 1,7 ms |
| 2000 | 2005000 → 4000 | 2003000 → 4000 | 215,9 ms → 3,8 ms |
| 4000 | 8010000 → 8000 | 8006000 → 8000 | 864,8 ms → 6,4 ms |

Die Zähler belegen die Reduktion von quadratischer auf lineare Arbeit für diesen Fall. Die Zeiten enthalten Metatable-Instrumentierung, sind Einzelmessungen im CLI und ausdrücklich keine Roblox-FPS- oder allgemeine Website-Beschleunigungsmessung. Die Regression prüft zusätzlich alle Wortpositionen, Float-Grenzen mit wirklichem Delta, Abbruch und 128/512/1024 Wörter mit/ohne Float-Bounds.

Weitere reproduzierte Vorher/Nachher-Ergebnisse:

- `all and (...)`, `only all`, `not all` werden korrekt geparst; nacktes all und Bedingungen ohne Typ bleiben gültig.
- Prozentzentrierte Circle-/Ellipse-Clips ergeben dieselbe Geometrie wie center.
- `right 10px` ergibt jetzt X=100%, Y=10px; vierteilige Kantenabstände und `background-position-x:right 10px` bleiben erhalten. Zweiteilsyntax ist anhand [CSS Backgrounds §2.6](https://www.w3.org/TR/css-backgrounds-3/#the-background-position) geprüft; Masken- und Radialgradient-Positionen sind mitgetestet.
- Zwei unabhängige Tabular-Nums-Items rufen jeweils zehn Messungen auf und erhalten ihre eigenen Breiten (12 beziehungsweise 21 im Test); vorher übernahm das zweite Item fälschlich 12 bei null eigenen Messungen. Vorhandenes WordLayout hält erfolgreiche itemeigene Glyphenmaße bei Resize weiterhin fest.
- Smooth-Marker-Tween: nach Destroy vorher ein nachträglicher refresh und kein Cancel; nachher null nachträgliche refreshes, Cancel/Disconnect ausgeführt. Der Test umfasst synchrones Completed bei Cancel, verborgenes AllChildren und wiederholten Destroy.
- Snap `none start` verändert bei both nur X; Y bleibt 70 statt fälschlich 150. Die umgekehrte Achse ist ebenfalls geprüft.
- `step-start` und `steps(1,start)` liefern am aktiven Anfang beide 1; während positivem Delay/backwards fill bleiben sie bei 0. Reverse/alternate-reverse beginnen bei 1 und füllen nach dem letzten Sprung mit 0. Der Before-Flag verändert keine kontinuierliche Bezierkurve.

Rohdaten und reproduzierbare Vorbereitung: `build/audit-2026-10-02/css-layout/repro-before.txt`, `repro-after.txt`, `scroll-before.txt`, `scroll-after.txt`, `prepare-repro.py` sowie die isolierten Repro-/Regressionsbundles. Reparaturtests sind in der regulären Testsammlung gespeichert, nicht nur in Build-Artefakten.
