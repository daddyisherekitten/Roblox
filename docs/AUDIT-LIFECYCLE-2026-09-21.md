# Audit: DOM, HTML, Eingabe und Seitenlebenszyklus — 21.09.2026

Statische Sichtung der 41 Module in `DOM/`, `HTML/`, `Input/`, `Controls/`,
`Navigation/` sowie `PageSession.luau` und `Rendering/HTMLPage.luau`.
Schwerpunkte: Ereignisverteilung, Ressourcenfreigabe, Formulare und Tastatur.
Die folgende Liste enthält belegte Befunde; sie ist kein Nachweis vollständiger
HTML-/Browser- oder Screenreader-Kompatibilität.

## Behoben

| Stelle | Befund und Änderung | Regression |
| --- | --- | --- |
| `Input/Events.luau:19` | Jeder Dispatch klonte zuvor alle Seiten-Listener und scannte sie nochmals für jeden Vorfahren. Ziel/Typ-Index reduziert die Arbeit auf Vorfahren und passende Listener. Listener werden pro aufgerufenem Ziel geklont. | `tests/Forms.luau:290`: 1.000 unbeteiligte Listener, Bubbling, Listener hinzufügen/entfernen während Dispatch. |
| `Input/Events.luau:4`, `:69` | Aufbewahrte Disconnect-Handles hielten auch nach Disconnect oder Seitenabbau Callback und DOM-Knoten. Handles werden jetzt von Callback/Bucket getrennt; Destroy invalidiert sämtliche Listener, auch bereits erstellte Dispatch-Snapshots. | `tests/Forms.luau:315`: Destroy im Handler, wiederholtes Disconnect/Destroy und abgelehnte Registrierung danach. Referenzfreigabe zusätzlich durch Codeprüfung, kein behaupteter nativer Heap-Messwert. |
| `Input/Events.luau:38` | Ein Handler konnte durch Ändern von `Parent` den Pfad des bereits laufenden Events umlenken. Der Pfad wird vor dem ersten Callback ermittelt; `CurrentTarget` anschließend gelöscht. | `tests/Forms.luau:290`: alter Elternpfad während erster Auslösung, neuer Pfad erst bei zweiter Auslösung. |
| `Input/Controller.luau:279` | Tab gruppierte alle Form-Controls vor Links und Medien, unabhängig von ihrer Reihenfolge im Dokument. Gemeinsamer einmaliger Dokumentindex; positive `tabindex` behalten Vorrang. Versteckte Links/Medien werden wie Controls ausgeschlossen. | `tests/Forms.luau:320`: gemischte Reihenfolge, positive tabindex-Werte, verborgenes Linkziel, ausgewählte Radiogruppe, Shift+Tab. |
| `Input/Controller.luau:293` | Für jedes Radio wurde beim Tabben die komplette Control-Liste erneut durchsucht. Jetzt zwei lineare Durchläufe mit Gruppen nach Formular und Name, danach die bestehende Sortierung. | Dieselbe Tastaturregression; bisherige Radio-/Formtests bleiben bestehen. |
| `Input/Controller.luau:74`, `:492` | Jedes Wheel-Ereignis erzeugte einen später nutzlosen verzögerten Job. Jetzt wird der vorige Job abgebrochen; Seitenabbau beendet den letzten Job. Generationsprüfung schützt auch bereits angelaufene alte Callbacks. | `tests/Forms.luau:274`: 200 Wheel-Ereignisse halten einen aktiven Job; nach Destroy keinen, verspätete Callbacks bleiben wirkungslos. |
| `Controls/FormModel.luau:22` | Initialisierung, Reset und Required-Prüfung hatten für jedes Radio erneut die komplette Control-Liste durchsucht. Einmaliger Gruppenindex nach Formular/Baum und Namen; Initialisierung und Reset sind linear, Required wird pro Submit einmal je Gruppe ausgewertet. Reset malt jeden betroffenen Control einmal mit seinem endgültigen Zustand. | `tests/Forms.luau`: 1.000 anfangs ausgewählte Radios, unabhängige Formulare und unbenannte Radios, exakt ein Paint je betroffenem Control bei Reset, Required nach Wechsel der Auswahl. |
| `Input/Controller.luau:207` | Dialog-Initialfokus betrachtete ausschließlich Controls und konnte an verborgenen Kandidaten stehenbleiben. Derselbe Kandidatenweg wie Tab berücksichtigt nun sichtbare Links, Medien und Controls in Dokumentreihenfolge, bevorzugt `autofocus`; Medienfokus wird beim Schließen gelöscht. | `tests/Forms.luau:340`: Dialog mit Link vor Button, Media vor Button, verborgene/disabled Kandidaten und Autofocus-Link mit negativem tabindex. |

## Messung und Prüfstatus

Isolierte Messung des echten geänderten Event-Moduls mit offizieller Luau-CLI:
2.000 Auslösungen über 13 Vorfahren, Median aus 7 Läufen. 0 / 1.000 / 10.000
unbeteiligte Listener: **1,689 / 1,823 / 2,271 ms**. Messskript:
`build/audit-events-bench.luau`. Das belegt die geringe Abhängigkeit von
unbeteiligten Listenern; es ist kein Roblox-FPS- oder Vorher/Nachher-Benchmark.

Die erweiterten funktionalen Regressionen liegen in der bestehenden
`tests/Forms.luau`. Der koordinierte Gesamtlauf
`node scripts/run-html-tests.cjs` ist einschließlich dieser Regressionen
bestanden. Nach den ergänzten Radio-/Dialogkorrekturen nochmals vollständig
ausgeführt: Exitcode 0.

## Weitere belegte Stellen, offen

| Stelle | Befund / nächste klar begrenzte Arbeit |
| --- | --- |
| `DOM/Node.luau:100`, `Controls/FormModel.luau:48`, `:195` | ID-Auflösung und implizite Label-Zuordnung laufen linear durch DOM/Controls. Ein dokumenteigener Index braucht definierte Invalidierung für künftige Änderungen, doppelte IDs und Shadow-Grenzen; kein globaler Cache eingeführt. |
| `Input/Controller.luau:233` | **Featuregrenze:** Wiederherstellung des vorherigen Fokus nach Dialogschluss ist noch nicht umgesetzt. Initialfokus für Links/Medien/Controls und Autofocus ist dagegen korrigiert und geprüft. |
| `Input/Controller.luau:112`, `CSS/InlineStyle.luau:913` | **Featuregrenze:** Tastaturbedienung und `aria-label`-Speicherung sind vorhanden, aber keine vollständige ARIA-/Accessibility-Tree-Brücke. HTML `inert` wird beim Fokus nicht allgemein ausgewertet. Eine zugängliche Test-Webseite bedeutet daher noch keine äquivalente Roblox-Screenreader-Unterstützung. |
| `Input/Controller.luau:23` | Rund 600 Zeilen verbinden Fokus, Controls, Pointer, Tastatur, Dialoge und Seiten-API. Nach Absicherung kann die gemeinsame Fokusnavigation als eigene Verantwortung ausgelagert werden. Für einen Stress-Test ist ein großflächiger mechanischer Umbau ohne zusätzliche Tests kein belegter Performancegewinn. |
| `Input/Events.luau:38` | **Featuregrenze:** Weiterhin bewusst begrenzter Eventbus und DOM: keine Capture-Phase oder vollständige browserartige Event-/Shadow-Retargeting-Semantik. Der Fokusindex setzt den aktuell beim Mount aufgebauten DOM voraus; spätere DOM-Mutationen müssen ihn invalidieren. |

## Bereits vorhandene Schutzmechanismen

`HTML/Parser.luau:55` begrenzt Bytes, Knoten, Tiefe und Diagnosen;
`DOM/Node.luau:100` traversiert iterativ. `PageSession.luau:5` beendet Ressourcen
idempotent und isoliert einzelne Cleanup-Fehler. `Rendering/HTMLPage.luau:216`
bündelt Layoutarbeit; `tests/PageLifecycle.luau` deckt Resize, Dirty-Updates,
späte Ergebnisse, Fehlererholung und Destroy ab. `Input/MediaRuntime.luau:464`
trennt Signale und entlädt Medien; die bestehenden MediaRuntime-Tests prüfen
deren Lebenszyklus. Diese Bereiche wurden nicht aus kosmetischen Gründen
umgeschrieben.

Normative Referenzen zur Einordnung der korrigierten Semantik:
[DOM-Ereignisdispatch](https://dom.spec.whatwg.org/#dispatching-events),
[HTML-Fokusnavigation](https://html.spec.whatwg.org/multipage/interaction.html#sequential-focus-navigation).
