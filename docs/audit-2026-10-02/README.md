# Gesamtprüfung der HTML-Engine · 2. Oktober 2026

Die Prüfung wurde vom Hauptagenten und drei parallel arbeitenden Fachagents durchgeführt: CSS/Layout, Rendering/Controls und SVG/Laufzeit. Die anschließend umgesetzten Korrekturen sind unten von größeren, noch offenen Umbauten getrennt. **FPS-Tests übernimmt auf ausdrücklichen Wunsch Tobias.** Es wurden keine nativen Roblox-FPS gemessen; nach dieser Anweisung wurden keine weiteren Performance-Messungen gestartet.

## Umfang und Nachweise

- Alle 284 ursprünglichen Engine-Module sind in der Modulmatrix erfasst. Die 267 handgeschriebenen Module wurden vollständig gelesen. Bei 17 generierten Modulen wurden Quelle/Generator, Format, Verbraucher und Ladeverhalten geprüft; rohe Glyphendaten sind kein manuell zeilenweise geprüfter Programmcode.
- Alle handgeschriebenen Luau-Beispielmodule sowie die Hilfsskripte wurden gelesen. SVG-Generatoren wurden mit ihren vorhandenen `--check`-Prüfungen abgeglichen. Der Fontkatalog wird auf 126 identische Einträge zwischen Browser und Luau geprüft; seine historische Erzeugungsprovenienz ist schwächer als die reproduzierbaren SVG-/Website-Generatoren.
- Tests wurden inventarisiert, geänderte und relevante Integrationsfälle im Detail gelesen und die vorhandenen Testsammlungen ausgeführt. **Nicht jeder alte Test und jede historische Dokumentationszeile wurde manuell vollständig geprüft.** Eine grüne Sammlung beweist keine lückenlose Feature- oder Branch-Abdeckung.
- Architekturregeln aus PLAN und AI-HANDOFF wurden mit dem Code abgeglichen. Historische Supportaussagen in README, AI-HANDOFF und Eigenschaftskatalogen sind teilweise überholt, etwa zu Formularen, Flexbox, CSS-weiten Werten und Easing. Sie gelten nicht als heutiger Funktionsnachweis.
- Der gesamte Ausgangsstand liegt als `build/audit-2026-10-02/source-before.zip` vor; Hashes und Zeilenzahlen stehen in `inventory-before.json`. Nutzerdateien wurden nicht zurückgesetzt. Das Repository war bereits vollständig untracked.

Die maschinenlesbare Gesamtmatrix steht in [module-matrix.json](module-matrix.json). Sie enthält Aufgabe, Schnittstellen, statische Abhängigkeiten/Aufrufer, veränderlichen Zustand, Ressourcenbesitz, Tests und getrennte Lese-/Interaktions-/Teststatus. Dynamische Callbacks/Factories werden durch den statischen require-Graphen allein nicht erfasst. [file-inventory.json](file-inventory.json) inventarisiert außerdem Daten und Assets. [code-counts.json](code-counts.json) trennt handgeschriebenen Code, generierte Daten und Tests.

Detailberichte: [CSS/Layout](css-layout.md), [Rendering](rendering.md), [SVG und Infrastruktur](svg.md). Die konkreten Testbefehle und Ergebnisse stehen in [verification.md](verification.md).

## Tatsächlicher Datenfluss

| Stufe | Verantwortung und Datenbesitz | Auslöser für weitere Arbeit |
| --- | --- | --- |
| `init`, Parser, DocumentInfo | Öffentliche API; DOM-Knoten und Dokumentmetadaten gehören dem Aufrufer. HTMLPage wird jetzt erst beim Mount geladen. | Mount erzeugt die Page; Parser-Nutzung erzeugt keine Eingabe-/Render-Runtime. |
| Stylesheet, InlineStyle, RenderTree | Regeln, berechnete Styles, StyleRecords, NodeStyles, NodeBoxes und GUI-Zuordnungen gehören der Seite. Regeln bleiben unveränderlich, berechnete Styles werden gezielt aktualisiert. | Media-/Container-/Form-/Pointerzustände lösen Cascade und je nach geändertem Feld Paint oder Layout aus. |
| WordLayout, BlockLayout und Speziallayouts | Individuelle Text-/Glyphenmaße bleiben am Item. Layout schreibt Boxmaße und Positionen. Fontprofile liefern kalibrierte Faktoren/Guides. | Geänderte Geometrie muss abhängige Geschwister/Eltern berücksichtigen; Paint allein darf keinen Voll-Reflow auslösen. |
| DirtyLayout, LayoutJob, WorkBudget | Dirty-Snapshots begrenzen Wiederverwendung; Job/Revision gehören HTMLPage. Checkpoints dürfen pausieren, aber Ergebnisse einer veralteten Revision nicht veröffentlichen. | Resize während Ziehen sammelt Änderungen; Loslassen oder sprunghafte Größe startet die endgültige Anordnung. |
| Retained Rendering, ViewportLayer | Renderbaum besitzt Frames/Labels; Effekthelfer besitzen explizite Images/Caches. Visuelle Transformposition ist von logischer Layoutposition getrennt. | Scroll verschiebt Sticky-/Fixed-Präsentation; Hover animiert bestehende Flächen mit CSS-Zeit/Easing. |
| Input.Controller, FormModel, Events | Controller besitzt Seitenverbindungen, Fokus, Drag, Auswahl und Popups; FormModel ist die Wahrheit für Formwerte. CSS erhält Zustands-Snapshots. | Engine-Hit-Test und Events ändern nur den notwendigen Zustand. Native TextBox/Scroll-Interaktion bleibt erhalten. |
| SVG / Canvas / Medien / Iframes | Je Runtime eigene Aufträge, VM, Buffer, Verbindungen und Ressourcen; asynchrone Rückkehr prüft die Seitenlebenszeit. | SVG priorisiert sichtbare Aufträge vor Vorwärmen; Canvas sammelt Zeichnen vor Upload; Iframes besitzen Kind-Pages. |
| PageSession | `Alive`, umgekehrter Cleanup-Stack, Root-Zerstörung. Späte Ergebnisse dürfen keine neue Arbeit anlegen. | Navigation/Destroy beendet Arbeit und trennt Verbindungen; Scroll-Tweens werden jetzt ausdrücklich beendet. |

Mehrere Darstellungen derselben Information sind teilweise sinnvoll: DOM für Semantik, StyleRecords für Cascade, Renderbaum für Layout und GUI-Mappings für Treffer. Problematisch wird das bei veralteten Ableitungen; die korrigierten Auswahlbreiten und Canvas-Hintergründe waren solche Fälle. Größere Zustands-/Index-Caches benötigen einen eindeutigen Invalidierungsvertrag.

## Umgesetzte Befunde

| Priorität | Befund und Korrektur | Nachweis / Grenze |
| --- | --- | --- |
| P1 | WordFlow scannte bei jedem Wort den verbleibenden ungebrochenen Lauf und verschob alle bisherigen Wörter um 0. Beide unnötigen Schleifen entfernt. | Positionsgleichheit, Float-Grenzen und Abbruch geprüft; Arbeit im nowrap-Repro wird linear. |
| P1 | Synchron verschachtelte Host→JS-Aufrufe setzten VM-Schritt-/Tiefenbudget zurück. Reentry teilt jetzt das äußere Budget und stellt Tiefe auch nach Fehlern wieder her. | Tatsächlicher DOM-Fokuszyklus, verschachtelte Call/Run-Aufrufe, Disposal und unabhängige Folgeevents getestet. |
| P1 | Canvas-Pfaderzeugung konnte die VM-Zeitgrenze mit riesigen Winkeln/Radien umgehen. Konstante Winkelnormalisierung, Checkpoints und explizite Punktgrenze ergänzt. | Normale Kurvenauflösung unverändert. Maximal 65.536 Punkte pro Pfad, einschließlich Textkonturen; Überschreitung ist ein Fehler. Nicht jeder Pfadbefehl ist bei Fehler atomar. |
| P1 | Canvas-Aufbau besaß seine Ressourcen erst nach potenziell fehlschlagender/yieldender Initialisierung. Cleanup wird früh registriert; Rollback und Alive-Prüfungen ergänzt. | Uploadfehler, späte Bildrückkehr, Abbruch und idempotente Freigabe getestet. HTMLPage setzt den Aufbau nach zerstörter Page nicht fort. |
| P2 | SVG-Alpha-Grenzsuche lief ununterbrechbar über jedes Pixel. Zeilenweise Suche des ersten/letzten belegten Pixels und kooperative Abbruchpunkte. | Bytegleiche Crops, leere/dichte/sparse Flächen, Release während Checkpoint; acht vollständige Benchmark-Zustände pixelgleich zur aktuellen Ausgangsversion. |
| P2 | Formular-/Popoverzustände lösten trotz reinem Paint einen Voll-Reflow aus. Controller berücksichtigt `layoutNeeded`; ControlBackgroundSpecified gilt als Paint. | Farbänderung: kein Layout; tatsächliche Breitenänderung: Layout. Form-, Hover- und Lifecycle-Regressionen erhalten. |
| P2 | Identischer Medien-Hover und viele unveränderte GUI-Werte wurden immer neu geschrieben. Zustands-/Property-Vergleiche vermeiden diese Arbeit. | 100 Bewegungen innerhalb derselben Aktion ohne erneuten Paint; geänderte Zustände werden weiterhin dargestellt. |
| P2 | Gemeinsamer Ziffern-Messcache verletzte die Vorgabe unabhängiger Textmessungen. Messwerte gehören wieder dem jeweiligen Messdurchlauf/Item. | Zwei unabhängige Items übernehmen keine fremden Maße; Resize erhält weiterhin eigene fertige Maße. |
| P2 | `@media all and (...)` und entsprechendes picture-Matching waren fehlerhaft. Expliziten Medientyp korrekt berücksichtigen. | Positive/negative Breitenfälle, CSS-Konjuktionen und responsive Quellen geprüft. |
| P2 | Zentrierte Prozent-Clipformen enthielten ein falsches Prozentliteral; zweiteilige background-position wurde als Kantenoffset interpretiert. | `50% 50%` entspricht center; `right 10px` bedeutet X=100%, Y=10px. Drei-/vierteilige Syntax bleibt erhalten. |
| P2 | Scroll-Tweens konnten nach Seitenabbau weiterleben; `scroll-snap-align:none` wurde pro Achse ignoriert. | Disconnect vor Cancel, synchrone Completed-Signale, verborgene Teilbäume und unveränderte none-Achse geprüft. |
| P2 | Textauswahl behielt Prefixbreiten einer alten Schriftgröße; user-select:none wurde bei Pick ignoriert. | Itemlokale Maße werden bei Font/Größe/Breite ungültig; Wort-/Glyphen-Overlays übernehmen neue Schriftwerte. OpenType-/vertikale Auswahl bleibt ein separates Profilthema. |
| P2 | Transparent gewordener html/body-Hintergrund ließ die alte Farbe stehen. | Ursprüngliche Root-Farbe und Transparenz werden wiederhergestellt, auch nach color-scheme. |
| P2 | `step-start` war am Start nicht gleich `steps(1,start)`; Steps sprangen teilweise schon vor einem positiven Delay. | Before-Phase für Transition/Animation ergänzt, einschließlich rückwärts gerichtetem und pausiertem Fill. Normale Bézier-Kurven und 1×-Zeit bleiben erhalten. |
| P3 | Reine Parser-Nutzung lud HTMLPage und dessen großen Render-/Inputgraphen; Inline-Auflösung matchte identische Regeln doppelt. | Lazy HTMLPage-require, unveränderte Mount-/IFrame-API; eine lokale Matchliste pro Auflösung ohne neuen globalen Cache. |
| Infrastruktur | SVG-Tests referenzierten gelöschte Webseiten; Benchmark erwartete unveränderlich sechs Zustände. | Originalgrafik als nicht veröffentlichte Fixture restauriert; CSS aus bestehender Fixture. Benchmark prüft explizit identische State-Sequenzen und je ein Readback, unterstützt ausgewählte Baseline-Datei. Alte Baseline bleibt erhalten. |

Native Bild-/Textrasterung kann aus CLI-Tests nicht abgeleitet werden.

## Bereits erhobene CPU-Nachweise

Diese Messungen wurden vor Tobias' Übernahme der FPS-Tests erhoben. Sie sind **keine FPS-Messungen** und kein Versprechen einer allgemeinen Beschleunigung jeder Website.

- 4.000 nowrap-Wörter: Width-Zugriffe 8.010.000 → 8.000; X-Schreibvorgänge 8.006.000 → 8.000. Instrumentierte Einzelzeit 864,8 → 6,4 ms; der Zähler, nicht der Zeitfaktor, ist der belastbare Komplexitätsnachweis.
- SVG-Cacheaufnahme einer deckenden 1024²-Ebene: 15 abwechselnde tatsächliche Modul-Läufe, Mittel 30,71 → 1,50 ms, Median 30,20 → 1,52 ms. Zentrale Quadratbelegung 16,33 → 8,97 ms; leer 11,50 → 11,00 ms. RGBA jeweils bytegleich. Leere Flächen profitieren vor allem von Unterbrechbarkeit.
- 600 Inline-Elemente / 24 Regeln: Match-Aufrufe 2.406 → 1.806. 15 abwechselnde Läufe nach Warmup, Median 94,45 → 89,30 ms, beobachtete Spanne 92,82–100,95 → 85,91–92,96 ms. Nur der lokale Match-Reuse wurde zwischen beiden Varianten geändert.

Rohlogs und reproduzierbare Skripte liegen unter `build/audit-2026-10-02/`. Keine Darstellung wurde für diese Verbesserungen verkleinert, virtualisiert oder durch gemeinsame Textmaße ersetzt.

## Größere offene Aufgaben und Migrationsentscheidungen

1. **Style-Invalidierung und Regelindizes:** Stylesheet/Selectors/RenderTree durchlaufen bei Zustandswechseln noch breite Bäume. Zuerst State-Kandidaten und Regelmatches sichtbar zählen; anschließend einen unveränderlichen RuleIndex mit id/class/tag-Buckets plus Fallback einführen. Snapshot-Invalidierung muss DOM, Attribute, Media, Container und Shadow-Grenzen enthalten. Nutzen: weniger Matching; Kosten/Risiko: neue Cacheverträge und Kaskadenfehler. Alternative: lokales Wiederverwenden wie in dieser Serie. Migration: Index nur für Kandidatenauswahl, alte Matcher als Oracle, danach State-Index.
2. **Mount und SVG-Szenenvorbereitung:** HTMLPage/RenderTree und Teile von Embedded/RenderQueue bauen synchron; Rasterbudget umfasst nicht jede Vorbereitung. Ein expliziter `BuildContext` mit Revision, Checkpoint, Diagnose und Cleanup-Besitz wäre die Schnittstelle. Nutzen: kürzere Blockierungen; Risiko: halb publizierte Bäume. Migration: Vorbereitung in private Ergebnisse, Alive-Prüfung vor Veröffentlichung, dann kooperatives Aufteilen. Keine mechanische Zerlegung nach Dateigröße.
3. **HTMLAnimations und SVG-Vorwärmen:** Änderungen an AnimationName nach dem ersten Layout werden nicht allgemein mit der Runtime-Liste synchronisiert. SVGImages enumeriert Vorwärmkandidaten noch vor manchen Kapazitätsprüfungen; Snapshot-/Metadatenvergleiche können groß sein. Laufzeitlisten an eine Style-Revision binden und Vorwärmen erst nach Kapazitätsprüfung planen. Risiken: veränderte Startzeiten/Animationsidentität; separat gegen aktuelle Hover-/Resize-Geometrie testen.
4. **Canvas-Quellbilder und Perspektivflächen:** Canvas decodiert noch manche unbenutzten Bilder mit IDs; Perspektiv-/Filterarbeit kann ganze Flächen betreffen. Bedarfsgerechte Quellauflösung und revisionsbasierte Rasterinvalidierung getrennt migrieren. Kein stilles Weglassen sichtbarer Effekte; Memory-Budgets pro Seite/Iframe zusammen betrachten.
5. **Engine-/Website-Kopplung:** Parser lädt HTMLPage jetzt nicht mehr. Die öffentliche Facade exportiert weiterhin Font-/CSS-/GUI-Bausteine, und der Standard-IFrameResolver hängt am Website-Katalog. Route-Lookup kann mehrere vollständige Webseiten laden. Ein kleiner Metadatenindex mit `resolveURL` → Seitenschlüssel wäre ein nächster, API-erhaltender Schritt; CustomResolver unverändert lassen. Kein ungefragtes Entfernen öffentlicher Exporte.
6. **Top-Layer und harte Vorgaben:** SelectPopup/ValidationPopup verwenden im vorhandenen Code teilweise den Parent der Page als Host. Das ist eine bestehende Abweichung vom strikten Nachfahren-Prinzip. Eine gemeinsame Page-eigene Overlay-Wurzel muss Clipping, Scrollkoordinaten, Cursor und Escape/Fokus lösen, bevor Hosts verschoben werden. Nicht durch `Active=true` oder globale klickbare Ersatzflächen kaschieren.
7. **Dokumentation/Supportkatalog:** Veraltete Einschränkungen anhand tatsächlicher Registrierungen und Tests abgleichen. Kein pauschales browserweites „supported“ aus einem Property-Namen ableiten. `scroll-snap proximity`, vertikale Auswahl, allgemeine Animation-Mutationen und native Raster-/Fontgrenzen bleiben ausdrücklich eingeschränkt.

Bestätigte Fontfaktoren und Guide-Daten, Wort-Labels, Active=false, natives Scrollen, bestehende Inhalte außerhalb des Viewports und Resize erst nach Freigabe bleiben erhalten. Keine permanente Diagnoseschleife und keine Frame-Prints wurden hinzugefügt. Tobias übernimmt die Beurteilung von FPS und nativer Darstellung; weitere automatische FPS-Tests sind nicht vorgesehen.
