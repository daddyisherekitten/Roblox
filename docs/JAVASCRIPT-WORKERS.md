# Dedicated Worker

Stand: 4. Oktober 2026. Zuständig: `JavaScript/WorkerAdapter`, `WorkerRealm`,
`EventLoop`, `StructuredClone`, `Modules` sowie `Rendering/WorkerHost` und
`WorkerRunner.client`. Grundlagen:
[HTML Worker](https://html.spec.whatwg.org/multipage/workers.html),
[Roblox Parallel Luau](https://create.roblox.com/docs/scripting/multithreading).

Der HTML-Host erstellt pro Dedicated Worker einen Actor mit eigener JavaScript-VM,
Standardbibliothek, Modulregistrierung und Ereignisschleife. Die Seiten-VM führt
den Workerquelltext nicht aus. Der Runner wird als inaktive Vorlage unter
ReplicatedStorage ausgeliefert und erst unter dem Actor in der PlayerGui-Abstammung
der Seite gestartet. Module werden vor Eintritt in parallele Ausführung geladen.
Nur die Nachrichtenbrücke wechselt für Roblox-Instancezugriffe in serielle Ausführung.
Dabei auftretende native Task-Unterbrechungen werden aus Async-/Generatorstacks
an den zuständigen Host-Task weitergereicht. Sie sind keine JavaScript-await- oder
yield-Operation und dürfen die jeweilige Promise-/Generatorfortsetzung nicht beenden.

Vorhanden sind klassische Worker und Modul-Worker, `name`, schreibgeschützte
`location`, `self/globalThis`, Ereignisse, Promises, Timer und Microtasks.
`document` und `window` fehlen. Klassische Worker besitzen synchrones
`importScripts` für zugeordnete Quellen; Modul-Worker verwenden den gemeinsamen
Modulgraphen und lehnen `importScripts` mit TypeError ab.

Die implizite Nachrichtenwarteschlange öffnet nach Beginn der Modulevaluation.
Top-Level-Await hält Nachrichten nicht bis zur Installation eines späteren Handlers
zurück. Die Vergleichsseite sendet deshalb erst nach einem ausdrücklichen
Bereitschaftssignal. Ein vor await installierter Handler verarbeitet bereits
eintreffende Nachrichten.

`postMessage` klont Daten. ArrayBuffers können in beide Richtungen übertragen
werden; der Absender verliert seinen Zugriff. Ein Worker und seine Seite teilen
keine gewöhnlichen JavaScript-Objekte. Fehlerlistener erhalten ErrorEvents;
das globale `onerror` verwendet die fünf besonderen Argumente und unterdrückt
die Weitergabe bei `return true`. Ein gewöhnlicher Laufzeitfehler beendet nicht
automatisch einen bereits installierten Nachrichtenhandler.

`close` beendet nach der laufenden Aufgabe und deren Microtasks. Weitere Aufgaben
werden verworfen. `terminate` und Seitenabbau räumen Actor, Verbindung, VMs,
Timer, Module und Nachrichten auf. Der Host besitzt keine eigene Heartbeat-
oder Frame-Pollingschleife: Neue Arbeit und der nächste fällige Timer wecken den
Runner. Untätige Worker erzeugen keine fortlaufenden Updates.

Prüfung: Acht echte Chromium-/Luau-Abläufe prüfen Startreihenfolge, await,
Fehlerweitergabe und beide onerror-Formen, close und Transfers. Zusätzlich prüfen
`JavaScriptWorkerRealm` und `JavaScriptWorkerHost` Budgets, Bootstrap-Reihenfolge,
Allokationsfehler, spätes Zustellen, untätige Timer und genau einmaliges Aufräumen.
Vier zusätzliche Fälle simulieren die suspendierende Actor-Nachrichtenbrücke für
Async-Funktionen, synchrone/asynchrone Generatoren und Module mit Top-Level-Await.
`JavaScriptProfilesReviewPage` führt denselben ausgelieferten HTML-/Workerquelltext
aus. Rojo-Build und Luau-Kompilierung sind geprüft. Tobias hat nach der Korrektur
der suspendierenden Actor-Brücke die gezeigten Studio-Fälle von Vergleich 07
mit „gut alles funktioniert jetzt“ bestätigt. Diese
funktionalen Prüfungen sind kein FPS- oder Parallelitätsbenchmark.

## Grenzen

- Der Standardhost bezieht Script-/Importquellen aus
  `Options.JavaScriptServices.ScriptSources` und `ModuleSources`. Ein expliziter
  `LoadScript`-/`SpawnWorker`-Adapter bleibt möglich. Synchronous importScripts
  erhält nur die paketierten Quellen; es gibt keinen synchronen Roblox-HTTP-Fetch.
- HTTP(S)-Worker-URLs müssen denselben Origin wie das Dokument haben.
  Blob-/Data-Worker, vollständige MIME-/CORS-/Credentials-Regeln und Netzwerkfetch
  innerhalb des Actor-Hosts sind noch offen.
- Kein Worker-MessagePort-Transfer, verschachtelter Standardhost-Worker,
  SharedWorker, Service Worker, SharedArrayBuffer/Atomics oder Worker-Canvas.
- Default: höchstens 32 Worker je Realm, 30.000 Interpreter-Schritte je Callback,
  1 MiB Startquelltext/serialisierter Einzelnachricht, 4 MiB paketierte Ressourcen und pro Nachrichtenwarteschlange
  höchstens 1024 Nachrichten beziehungsweise 4 MiB.

P17 ist damit um ein ausführbares Dedicated-Worker-Profil erweitert. Die vollständige
Worker-/Agent-/Service-Worker-Familie ist weiterhin ein offenes Ausbauziel.
