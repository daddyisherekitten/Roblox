# JavaScript: Implementierung und Prüfstand

> Maßgebliche JavaScript-Bestandsübersicht. Engere und neuere Fachprofile präzisieren einzelne Familien; Erreichbarkeit ist keine Vollständigkeit. [Index und Statusbedeutung](README.md), [Ausbauplan](JAVASCRIPT-ROADMAP.md).

Stand: 18. Oktober 2026. Neu sind die unten beschriebenen priorisierten Aufgaben, asynchrones XMLHttpRequest und Web Locks im ausdrücklich geteilten Hostspeicher. Einfache JavaScript-Dialoge und der vom Browserhost gesteuerte Dokumentlebenszyklus bestehen seit dem 15. Oktober. Das [JavaScript-Audioprofil](JAVASCRIPT-AUDIO-20261006.md) ergänzt Audio-Konstruktor, Play-Promises, Zustände und native Soundanbindung. Der [Browser-Grundlagen-Durchlauf](JAVASCRIPT-FOUNDATIONS-20261005.md) ergänzt Nesting/CSSOM, Übergangssemantik, Bild-/Fontladen, Unicode/URL und de/en-Date-/Intl-Profile. Seine frühere Atelier-Seite und Vergleich 09 mit R01–R04 bleiben historische Regressionen; den aktuellen sichtbaren Katalog führt [WEBSITES](WEBSITES.md). Das [Eingabetypen-Profil](HTML-INPUT-TYPES-20261006.md) ergänzt Datum-/Zeitwerte, Picker, Bildsubmitter und den bewusst auf Darstellung begrenzten Datei-Input. Der Gesamtbestand P01–P17 und seine offenen Unterfamilien sind unten erfasst; dies ist keine vollständige Browser-Konformität. Dauerhafte Roblox-DataStore-Speicherung benötigt weiterhin einen tatsächlichen Studio-/Live-Persistenztest.

Das gemeinsame `HTMLMediaElement.loading` reflektiert seit dem 16. Oktober
`eager`/`lazy` nach den bekannten Werten. Der
[VIDEO-/Poster-Lazy-Nachtrag](MEDIA.md#verzögertes-video-posterladen--16-oktober-2026)
belegt die montierten Fortsetzungen und ihre Load-/Lebensdauergrenzen.
AUDIO-Lazy und vollständige Medien-/Intersection-Geometrie bleiben offen.

Der begrenzte Kamera-/Mikrofon-Berechtigungsweg ist jetzt vorhanden:
`navigator.mediaDevices.getUserMedia`, `navigator.permissions.query` für beide
Namen und `PermissionStatus` mit Zuständen/Änderungen. Beide nativen Fensterhosts
stellen den Dialog, Entscheidungen bleiben sitzungsweit pro Herkunft erhalten.
Der konfigurierte virtuelle Kamerahost liefert jetzt `MediaStream`/`MediaStreamTrack`
und `video.srcObject` mit lebender ViewportFrame-Ansicht. Kamera und Szene werden
im LocalScript angegeben. Ohne Capturehost bleibt `NotSupportedError`; Mikrofon
hat noch keine Tonquelle. Vollständige Geräte-/Stream-/Permissions-Policy-Semantik
ist damit nicht umgesetzt; Iframe-Anfragen bleiben gesperrt. Vertrag und Nachweise stehen im
[Medienprofil](MEDIA.md#kamera--und-mikrofonberechtigungen--16-oktober-2026).

## Dialoge und Dokumentlebenszyklus · 15. Oktober 2026

`alert()`, `confirm()` und `prompt()` sind im gemeinsamen HTML-Realm vorhanden.
Sie liefern synchron `undefined`, einen Boolean beziehungsweise einen String
oder `null`; sie geben kein Promise als Ersatz zurück. Der optionale
`SimpleDialogHost.Show(request, complete)`-Adapter stellt die Oberfläche und
liefert eine Abbruchfunktion zurück. Die Engine wartet in der besitzenden
Luau-Aufgabe, während Roblox und andere unabhängige Realms bedienbar bleiben.
Die Aufgaben, Microtasks und Autorenereignisse desselben Realms laufen erst nach
der Antwort weiter. Async-/Generator-Körper reichen die Hostwartezeit an ihre
äußere Ausführungsaufgabe weiter. Browser, HTML und WindowManager bleiben eigene
Module; ohne Adapter werden Dialoge unterdrückt: `confirm()` liefert `false`,
`prompt()` liefert `null`, `alert()` liefert `undefined`.

Das Profil umfasst DOMString-Konvertierung einschließlich Symbolfehlern,
Nachrichtenumbruch-Normalisierung, `alert()` gegenüber `alert(undefined)`,
optionale Vorgaben, akzeptierte leere Eingaben, Abbruch und einmalige Zustellung.
Ein bereits offener Dialog unterdrückt native Host-Reentry-Dialoge; Dialoge aus
der vorherigen Argumentkonvertierung bleiben dagegen nacheinander möglich.
`Cancel()` schließt einen noch lebenden Dialog mit seinem Abbruchwert. Beim
Dokumentabbau wird zuerst die VM unbrauchbar, dann der wartende Host fortgesetzt;
späte Antworten können kein `catch`/`finally` in einem toten Dokument ausführen.
Eine erzwungene native Fensterzerstörung prüft auch gerade ausführende oder
in Dialogen wartende Kind-Realms, einschließlich noch nicht zurückgekehrter
IFrame-Mounts. Sie beendet diese Realms vor der Dialogfreigabe und überspringt
in diesem Fall die Unload-Ereignisse; der gewöhnliche bestätigte Leave-Pfad
behält seine Ereignisfolge. Unload ist damit kein garantierter Speicherpunkt.
Dialoganfragen enthalten einen String-Ursprung; ein privater opaker Ursprung
wird für die Oberfläche als `"null"` serialisiert.
Ein fehlerhafter UI-Adapter wird diagnostiziert und unterdrückt den Dialog.
Der Adapter muss `Show` ohne eigene Wartephase zurückgeben und später genau
einmal antworten oder über seine Abbruchfunktion schließen.

Die neuen Window-Operationen `alert`, `confirm`, `prompt`, `requestIdleCallback`
und `cancelIdleCallback` prüfen zuerst ihren Receiver. Das eigene `window`,
`self` und `globalThis` sind zulässig; `null`/`undefined` verwenden das globale
Window ihres definierenden Realms, auch bei strikten freien Aufrufen.
Fremde Objekte, bloße Prototypnachkommen und primitive Receiver werfen vor
Argumentkonvertierung oder Hostaufruf einen `TypeError`. Vollständiges Borrowing
über fremde WindowProxy-Realms bleibt offen. Maßgeblich ist die
[Web-IDL-Operationsbindung](https://webidl.spec.whatwg.org/#es-operations).

`DocumentLifecycle` stellt `document.hidden` und `document.visibilityState`
als schreibgeschützte Zustände bereit und empfängt Sichtbarkeit vom Host.
Nach `load` folgt `pageshow`; tatsächlicher Dokumentwechsel löst einmal
`pagehide`, bei sichtbarer Seite `visibilitychange` und anschließend `unload`
aus. Seitenwechselereignisse verwenden `persisted=false`: ein Back-Forward-Cache
wird dadurch nicht behauptet. `PageTransitionEvent` ist konstruierbar;
`BeforeUnloadEvent` besitzt das native Eventinterface und ist nicht öffentlich
konstruierbar. `beforeunload` berücksichtigt Handler-Rückgabe, `returnValue`,
`preventDefault()` und bleibende vertrauenswürdige Nutzeraktivierung. Der
optionale `ConfirmLeave`-Host entscheidet über Abbruch/Weitergehen mit fester
Browsernachricht; Autorentext wird nicht als Browserwarnung übernommen.
Ohne solchen Host oder ohne Aktivierung wird die Warnung unterdrückt und der
Wechsel erlaubt. Dialoge und neue Fenster werden während des Unloadpfads
unterdrückt; das ist keine Gerätezusage für Kamera/Mikrofon oder sonstige APIs.

Eine native Leave-Abfrage pausiert auch den Aufgaben- und Animationstreiber des
anfragenden Realms bis zur Antwort. Tatsächliche Seitensichtbarkeit wird von
vorübergehender GUI-Staging-Sichtbarkeit getrennt; verschachtelte Dokumente
erben die echte Tab-/Fenstersichtbarkeit. `page:RequestLeave` aggregiert die
eigene Realm und ihre Nachkommen mit höchstens einer sichtbaren Warnung;
`page:CommitLeave` entlädt Nachkommen vor dem Elternteil. IFrame-Ersetzungen und
Reloads verwenden dieselbe Abfrage. Eine reine IFrame-Entfernung zerstört das
Dokument ohne Unload-Ereignisse. Das Sandbox-Token `allow-modals` und geerbte
Hostsperren begrenzen die neuen Dialoge. Die präzisen Fälle, übrigen
Browsing-Kontext-/Agent-Grenzen und Nachweise stehen im
[IFrame-Profil](IFRAMES.md#sichtbarkeit-und-navigation-mit-leave-abfrage--15-oktober-2026).

Nachweise sind `JavaScriptSimpleDialogs`, `DocumentLifecycle`, `WindowManager`,
`BrowsingWindows`, `JavaScriptHostIntegration`, `JavaScriptLoadingLifecycle`,
`EventHandlerAttributes` und `JavaScriptRealmLifetime` im bestehenden Luau-Runner.
Ergänzend prüfen `WindowCloseGuard`, `IFrameLifecycle`, `IFrameLifecycleNested`,
`IFrameLifecycleMounted` und `IFrameAttributeNavigation` die Fensterinterzeption,
Abbruch-/Reentranzgrenzen, Dienstisolierung und den tatsächlichen Kind-Realm-Pfad.
`BrowserLifecycleDialogs` verbindet echte HTMLPage-, Browser- und WindowManager-
Instanzen mit kontrollierten nativen Diensten und prüft auch erzwungenen Abbau
wartender Haupt-, erhaltener Kind- und noch mountender Kind-Dokumente.
Sie prüfen echte VM-Ausführung und kontrollierte native GUI-Ersatzobjekte;
die sichtbare Roblox-Abnahme bleibt davon getrennt. Grundlage sind
[HTML Simple dialogs](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#simple-dialogs)
und [HTML Navigation/Lifecycle](https://html.spec.whatwg.org/multipage/nav-history-apis.html),
abgeglichen am 15. Oktober 2026. Offen bleiben vollständige Web-IDL-/Cross-Realm-
Receiverkombinationen, alle Sandbox-/Frame- und Navigation-Sonderfälle,
BFCache, Hintergrund-/Cross-Realm-Scheduling, vollständige Frame-Idle-Kriterien
und Scheduler, weitere echte
Performanceeinträge und die übrigen R14-Familien. Dieses Profil schließt R14
und die allgemeine Browserkonformität ausdrücklich nicht ab.

`WindowHost.close` und die `close`-Methoden zurückgegebener Fensterreferenzen
sind nicht wartende Schließaufträge. Die bereitgestellte Browseranbindung
plant den tatsächlichen Guard/Abbau als spätere native Aufgabe; `window.close()`
und `child.close()` liefern unmittelbar `undefined`. Laufender Autorenquelltext
und seine Microtasks können deshalb zuerst fertig werden. Ein asynchroner
Schließauftrag wird nicht wie ein synchroner JavaScript-Dialog suspendiert.
Eigene WindowHost-Adapter müssen denselben Vertrag einhalten und dürfen die
laufende Autoren-VM nicht im `close`-Aufruf zerstören oder dort auf eine
Guardantwort warten. `BrowsingWindows` prüft eigene und fremde Zielkontexte aus
Script-, Event-, Timer-, Promise-, Async-, Generator- und Idlepfaden: Erst die
separate native Aufgabe wartet auf `beforeunload`, Abbruch erhält das Dokument,
Bestätigung baut es ab und löst keine verbliebenen Autoren-Generatorfinalizer
aus. Maßgeblich sind die [HTML-close-Schritte](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-window-close).
Die vollständigen `is closing`-/Script-closable-/Sandbox-/Navigationskombinationen
sind damit nicht als abgeschlossen nachgewiesen.

Seit dem 16. Oktober zeigt `closed` bei einem erlaubten JavaScript-Schließauftrag
bereits vor seiner nativen Aufgabe `true`. Mehrere Aufträge an denselben
Zielkontext teilen einen wartenden Guard. Das logische Closing verwirft das
Dokument nicht: eigener Code, Microtasks und gleichursprüngliche Zugriffe auf
`document`, `name`, `location` und Geometrie bleiben bis zum tatsächlichen Abbau
möglich. Der optionale Hostmember `IsDiscarded()` unterscheidet diese physische
Lebensdauer von `IsClosed()`; ältere Adapter ohne ihn behalten ihr bisheriges
Verhalten über den IsClosed-Fallback. Benannte physisch vorhandene Kontexte
bleiben bei `open('', name)` dieselben. Abgelehnte Primärfensteranfragen setzen
keinen Closing-Zustand.

Die Browseranbindung verwendet ein ausdrücklich begrenztes Hostprofil:
Tatsächliches Stay, ein fehlgeschlagener Guard oder abgelehnte Aufgabenplanung
setzt den aktuellen lebenden Schließauftrag zurück, sodass ein späterer Versuch
möglich bleibt. Rückmeldungen und erzwungener nativer Abbau dürfen keinen alten
Kontext reaktivieren. Scheduler-/Guardfehler erhalten ihren ersten ursprünglichen
Fehlerwert, auch `nil`, `false` oder eine Tabelle. Dies ist kein stiller Zusatz
zum eingefrorenen Standardalgorithmus: Dessen `definitely close`-Abbruchpfad
enthält keinen ausdrücklichen Closing-Reset.

Die [unabhängige Chrome-155-Aufnahme](../tests/fixtures/window-close-browser.json)
enthält fünf tatsächliche HTTP-Popupfälle. Dort ist `closed` nach erfolgreichem
`close()` synchron wahr, Dokumentzugriff besteht im selben Stack/Microtask fort,
Stay ergibt dagegen `closed=false` und erlaubt einen neuen Versuch. Die Aufnahme
zeigt außerdem native Abweichungen zum hier verwendeten eingefrorenen Pfad:
`beforeunload` läuft bereits vor der Rückkehr des Aufrufs, ein wiederholter
ungehinderter Aufruf löst zweimal `beforeunload` aus, und der native Dokumentzugriff
bleibt dort sogar nach physischem Targetabbau möglich. Die Engine behält ihre
bisherige `InvalidStateError`-Policy nach tatsächlicher Dokumentverwerfung.
CDP-`Target.closeTarget` dient ausschließlich als erzwungener Harnessabbau;
es wird nicht mit der nativen Caption-Schließfunktion gleichgesetzt.
23 additive tatsächlich montierte Kontrollen/119 Assertions in
`BrowserLifecycleDialogs` sowie die ursprünglichen unveränderten Stay-/Retry-
und WindowProxy-Prüfungen belegen diesen Umfang. Die echte `window-demo`
zeigt den unmittelbaren Getterwert; ihren Quelltext prüft `BrowserWindowsMounted`.
History-size-1-/Familiarity-/Sandbox-/vollständige Navigations- und Cross-Realm-
Kombinationen, native WindowProxy-Lebensdauer und die vollständige R14-Familie
bleiben offen.


Ein neuer durch `open()` erzeugter leerer Kontext besitzt synchron sein initiales
`about:blank`-Dokument; spätere Hostaufgaben ersetzen keine unmittelbar daran
geschriebenen DOM-Inhalte. Eine leere oder ausgelassene URL navigiert einen
bestehenden benannten Kontext nicht. Eine ausdrücklich angegebene
`about:blank`-URL navigiert dagegen einen bereits bestehenden Zielkontext.
Diese Unterscheidung folgt den [HTML-window-open-Schritten](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-open-steps)
und wird mit tatsächlichen HTMLPage-/Browser-/WindowManager-Instanzen in
`BrowserWindowAPIs` geprüft.

Der synchrone `WindowHost.Open`-Aufruf darf beim Aufbau dieses leeren Dokuments
kooperativ an den nativen Tasktreiber abgeben. `BrowsingWindows` führt zuvor
die Argumentkonvertierungen aus und überträgt anschließend ausschließlich
diesen Hostaufruf über den vorhandenen Generator-/Async-Trampolinpfad. Auch ein
Asyncaufruf innerhalb eines Generators prüft beim tatsächlichen Hosteintritt
die noch umgebenden Generatorstacks. Die native Pause wird weder zu einem
Autoren-`yield` noch zu einem unbeabsichtigten `await`. `WindowOpenCooperative`
prüft sieben tatsächliche HTMLPage-/Fallbackhost-Mounts mit einem gezielt
angehaltenen nativen Aufbau: gewöhnlicher Aufruf, Generator, Asyncfunktion,
Asyncgenerator und drei verschachtelte Kombinationen. Ein Symbolfehler bei
der Argumentkonvertierung erreicht den Host nicht; fertig aufgebaute Kinder
und sämtliche nativen Verbindungen werden anschließend freigegeben. Andere
beliebige Hostmember werden dadurch nicht allgemein suspendierbar.

## Kooperative Idle-Callbacks · 15. Oktober 2026

`requestIdleCallback(callback, options)` und `cancelIdleCallback(handle)`
ergänzen den vorhandenen Tasktreiber. `IdleDeadline` besitzt das
schreibgeschützte `didTimeout`, die gebrandete Methode `timeRemaining()` und
keinen öffentlichen Konstruktor. Callback- und Dictionary-Prüfung,
`unsigned long`-Konvertierung der Handles/Timeouts, Getterreihenfolge,
Cancellation und einmalige Zustellung sind umgesetzt. Positive Timeouts
konkurrieren als verzögerte gewöhnliche Tasks mit der Idle-Zustellung;
bei ihrem Ablauf gilt `didTimeout=true` und `timeRemaining()=0`. `timeout: 0`
legt gemäß dem festgehaltenen Entwurfsalgorithmus keinen Ablauf-Task an.

Das Roblox-Profil liefert einen **kooperativen Budgethinweis**, keine Messung
der freien Zeit seines nativen Compositors. Nach ausführbaren gewöhnlichen
Tasks ist standardmäßig ein Budget von höchstens 1 ms vorgesehen. Bekannte
frühere Tasks verkürzen es; bei wartenden rAF-Callbacks wird standardmäßig
keine gewöhnliche Idlephase begonnen. `Runtime` kann über
`IdleBudget = function() return milliseconds end` einen anderen Hosthinweis
erhalten. Auch dieser wird auf höchstens 50 ms und die nächste bekannte Task
begrenzt. Ein Hinweis von null parkt gewöhnliche Idle-Anfragen ohne Polling;
der Host kann nach einer Budgetänderung `runtime.IdleCallbacks:Wake()` rufen.
Timeouts bleiben unabhängig davon normale geplante Tasks.

Eine kooperative Phase führt höchstens einen Callback aus. Weitere und rekursiv
registrierte Anfragen behalten ihre Reihenfolge und warten bis zu einer
folgenden Phase. Verbleibende Zeit sinkt mit der gemeinsamen monotonen Uhr und
endet spätestens bei neu geplanter dringlicher Taskarbeit. Versteckte Dokumente
parken gewöhnliche Idlephasen; positive Timeouts bleiben erlaubt.
Die bestehende VM-Instruktionsgrenze gilt weiterhin: Ein Autor kann einen
Budgethinweis ignorieren, wodurch er nicht zu einer harten CPU-Zeitschranke wird.
Je Realm sind höchstens 1.024 wartende Idle-Anfragen vorgesehen; Abbau entfernt
Callbacks, Timeouttasks und sämtliche nativen Weckaufgaben.

`JavaScriptIdleCallbacks` prüft diese Semantik einschließlich Reentry,
Timeoutrennen, Hintergrundzustand und Abbau. `JavaScriptClock` prüft mit
echtem `HTMLScripts`/`ScriptClock` und kontrollierter nativer Uhr: ein gemeinsamer
Wecker, keine zusätzliche permanente Frameverbindung, Layoutpausen und
Abbruchfreigabe. `JavaScriptSimpleDialogs` umfasst zusätzlich einen innerhalb
eines Idlecallbacks wartenden Dialog und dessen Abbau. Grundlage ist der
[W3C-Entwurf vom 21. Mai 2025](https://www.w3.org/TR/2025/WD-requestidlecallback-20250521/),
abgeglichen mit dem aktuellen Editorentwurf am 15. Oktober 2026. Exakte native
Frame-/Input-Idle-Garantien und vollständige Cross-Realm-Receiverfälle bleiben
offen. Das folgende Schedulerprofil ergänzt priorisierte Aufgaben. Aus den
beiden begrenzten Profilen folgt kein Abschluss
der gesamten Scheduling-Familie.

## Priorisierte Aufgaben · 18. Oktober 2026

`scheduler.postTask(callback, options)` plant Arbeit mit `user-blocking`,
`user-visible` oder `background`. Das zurückgegebene Promise übernimmt Ergebnis,
Fehler und Thenables. `delay` verschiebt die früheste Ausführung; `signal`
bricht wartende und noch synchron laufende Aufgaben mit dem tatsächlichen
Abortgrund ab. Nach dem Callback entfernte Abortalgorithmen ändern ein bereits
übernommenes Ergebnis nicht mehr. Fehler der Promise-Operationen werden als
Ablehnungen zugestellt; Konstruktor-/Controllerfehler werfen synchron.

`TaskController` und `TaskSignal` erweitern echte AbortController-/AbortSignal-
Instanzen. `setPriority`, `prioritychange`, `TaskPriorityChangeEvent` und
`TaskSignal.any` ergänzen veränderliche und abhängige Prioritäten. Explizite
`postTask`-Prioritäten bleiben fest. Quellen verwenden schwache Abhängigkeiten;
beobachtete abhängige Signale bleiben für registrierte Prioritätsbeobachter
und wartende Aufgaben erhalten. Gleiche Priorität startet kein neues Ereignis;
eine reentrante Änderung während der Zustellung wirft `NotAllowedError`.

`scheduler.yield()` setzt in einer neuen Aufgabe fort, mit Vorrang vor gewöhnlichen
Aufgaben derselben Priorität. Priorität und Abbruch werden über Promise-Reaktionen,
`await`, Thenables und `queueMicrotask` weitergereicht. Gewöhnliche Timer und
Framecallbacks übernehmen diesen Kontext nicht. Idlecallbacks beginnen mit
Hintergrundpriorität. Derselbe Unterbau läuft im DOM-freien Dedicated Worker.
Ein einzelner vorhandener EventLoop-Dispatch bedient höchstens 1.024 wartende
Scheduleraufgaben; es gibt keinen neuen dauerhaften Frame-/Timerpoller.
Die globale `scheduler`-Eigenschaft besitzt einen ersetzbaren Accessor mit
Receiverprüfung. Eine Zuweisung erzeugt eine gewöhnliche eigene Dateneigenschaft;
die interne Aufgabenplanung hängt nicht von einem Autorenersatz ab.
Bei einer nachträglich nicht konfigurierbaren Accessoreigenschaft wirft der
gespeicherte Setter gemäß Web IDL `CreateDataPropertyOrThrow` einen `TypeError`.
Chrome 155 kehrt in der unabhängigen Zusatzprobe dagegen still zurück. Diese
Abweichung bleibt neben den zehn übereinstimmenden Zusatzprogrammen erhalten.

Referenz ist der [Prioritized-Task-Scheduling-Entwurf vom 30. Mai 2025](https://wicg.github.io/scheduling-apis/).
Eine eingefrorene Kopie mit SHA256 und Chromium-155-Metadaten liegt bei den
[nativen Referenzprogrammen](../tests/fixtures/javascript-scheduler-native.json).
`JavaScriptScheduler` führt dieselben Programme durch die tatsächliche Runtime
aus und ergänzt Delay-, Abbruch-, Worker-, Intrinsic- und Abbaukontrollen.
Zurückgegebene Thenables behalten den Callbackkontext nach der eingefrorenen
Chromium-Beobachtung; die Clear-Schritte des Entwurfs sind davon ausdrücklich
getrennt, kein vollständiger normativer Promise-/Host-Job-Abschluss.
Vollständige Cross-Realm-/Agentverträge, gemeinsame Prioritäten verschiedener
Dokumente und native Input-/Compositor-/Hintergrundgarantien bleiben offen.
`yield()` garantiert einen Taskwechsel, keinen nativen Bildwechsel oder eine
Unterbrechung eines laufenden JavaScript-Callbacks.

## Asynchrones XMLHttpRequest · 18. Oktober 2026

`XMLHttpRequest` verwendet den bestehenden Fetch-/Body-/Headertransport.
`open`, `send`, Header, MIME-Override, Zustände, `responseType`, `responseText`,
`responseXML`, Uploadtarget, Progress-/Load-/Abort-/Error-/Timeout-Ereignisse
und Request-Neustart sind im gepufferten asynchronen Profil vorhanden.
Text, JSON, Blob, ArrayBuffer und Dokumentantworten behalten ihre eigenen
Ergebnisidentitäten. Verbotene Requestheader und nicht exponierte Antwortheader
werden über die vorhandenen Header-/Fetch-Guards gefiltert.
Timeoutänderung, Abort, Reopen und Realm-Abbau sperren alte Antworten und
entfernen wartende Aufgaben. Im Worker fehlt `responseXML`; der Dokumenttyp
wird dort wie in der nativen Referenz ignoriert.

Die HTTP-/Worker-Rohreferenz und der echte VM-/DOM-/Fetch-Abgleich stehen in
`scripts/test-javascript-xml-http-request.cjs`; `JavaScriptXMLHttpRequest` und
`JavaScriptXHRRuntime` prüfen zusätzlich die kanonischen und tatsächlichen
HTML-Runtimepfade. Der [Scopebeleg](../build/network-xhr-20261018/scope-review.md)
benennt Standard, Hashes und verbleibende Grenzen.
Eine native Abweichung bleibt ausdrücklich getrennt: Bei `open()` innerhalb
von `load` liefert Chrome 155 für das folgende `loadend` die Zähler `0/0`.
Die Engine behält die vorher festgehaltenen Bytes `5/5` gemäß den
[XHR-End-of-body-Schritten 3/4 und 10/11](https://xhr.spec.whatwg.org/#handle-response-end-of-body).
Rohreferenz und normative Erwartung sind im Scopebeleg getrennt erhalten.
Der Adapter liefert einen vollständigen Bytebatch; dessen Progressereignisse
beweisen kein Live-Netzwerkstreaming. Synchrones XHR und URLauthentifizierung
benötigen weitere Ausführung-/Transportpfade und bleiben offen. Allgemeine
CORS-/Cookie-/Redirect-/Transportregeln bleiben Hostaufgaben; Dokumentencoding,
XML- und sämtliche Web-IDL-Randfälle sind damit nicht vollständig abgenommen.

## Web Locks im Hostspeicher · 18. Oktober 2026

`navigator.locks.request()` und `query()` koordinieren benannte Ressourcen
exklusiv oder mit mehreren Lesern. Wartende exklusive Anfragen werden nicht
von späteren Lesern überholt. `ifAvailable`, `steal`, AbortSignal, Ergebnis- und
Thenableübernahme, getrennte Statuskopien und Freigabe beim Realm-Abbau sind
vorhanden. Bereits zugestellte alte Grantcallbacks können nach `steal` noch
laufen, besitzen die Sperre dann jedoch nicht mehr. Die genaue relative
Reihenfolge zwischen verschiedenen nativen Aufgabenquellen wird nicht versprochen.

Der Host erstellt mit `Engine.createWebLockStore()` einen privaten Speicher
und reicht ihn über `WebLockStore` und optional `WebLockPartitionKey` weiter.
Browser-Tabs, Popups und HTML-Fallback des Beispielskripts teilen denselben
Speicher. Partition, tatsächliche Tuple-Herkunft und Ressourcenname trennen die
Sperren. Ohne ausdrücklich geteilten Speicher erhält jede Realm einen lokalen
Fallback; unabhängige Realms werden dadurch nicht koordiniert.
Sichere Kontexte beziehungsweise vertrauenswürdige lokale Herkunft sind nötig;
opake Herkünfte werden abgelehnt. Der Host kann mit `SecureContext=false` sperren.

Der Broker arbeitet in einer Luau-Ausführungsumgebung. Tatsächliche Runtime-
und direkte WorkerRealm-Instanzen teilen den Speicher im Integrationstest.
Getrennte Roblox-Actors benötigen weiterhin einen echten IPC-Broker;
automatische Top-Level-Site-Partitionierung, Storage Buckets, vollständige
SecureContext-/Cross-Realm-/Discardverträge und R12 insgesamt bleiben offen.
Die endlichen Ressourcenlimits und verbleibenden Hostgrenzen beschreibt der
[Scopebeleg](../build/javascript-web-locks/scope-review.md).
`JavaScriptWebLocks`, `JavaScriptLocksRuntime` und `BrowserHTMLMounted`
prüfen API, echte Runtime-/Workerübergaben und zwei montierte Browsertabs.
Grundlage ist der [Web-Locks-Entwurf vom 24. September 2025](https://www.w3.org/TR/2025/WD-web-locks-20250924/).

## Wiederfinden

Der [Folgeplan R00–R20](JAVASCRIPT-ROADMAP.md#folgeplan-r00r20-offene-teile-von-p01p17-abschließen)
ordnet die noch offenen Teile nach Abhängigkeiten und enthält Abschlusskriterien,
Hostprüfungen, Reviews und Vergleichsseiten. R00–R04 besitzen geprüfte Erweiterungsprofile. Neu hinzugekommen sind die dokumentierten Teile von R05/R06, R07/R08 und R13/R16; die übrigen Unterfamilien und R09–R20 bleiben als Ausbauziele sichtbar.
Offene Standardunterfamilien werden ausdrücklich im Register weitergeführt.

Die gemeinsame Sprache liegt in src/HTMLEngine/JavaScript. Runtime verbindet sie mit DOM, Ereignissen und Jobs; Rendering/HTMLScripts, HTMLPage, ScriptClock und ScriptGeometry verbinden native Eingaben, Layout, Scrollen und Frames. Den weiteren Umfang beschreibt die [Roadmap](JAVASCRIPT-ROADMAP.md).

Die früheren Quellen von browser-foundations und javascript-tests sind ausschließlich unter tests/fixtures/retired-websites.json als Regressionstestdaten erhalten. Aktive Browserquellen und generierte Module beschreibt [WEBSITES](WEBSITES.md). Die Startwebsite steht nur im LocalScript; StudioDemoConfig wählt nur die Demo.

## Erreichbarer Bestand

| Paket | Implementierte Grundlage | Dateien | Offene Grenze |
| --- | --- | --- | --- |
| P01 | Arrows/async, Templates/Tags, Methoden/berechnete Namen, Default/Rest/Spread/Destructuring, optional/nullish/logische/Bitoperatoren, do/switch/Labels/for-in/of, Unicode-Identifier, RegExp-Literale | Lexer, Identifier, Syntax, SyntaxValidation, VM | Weitere frühe Syntaxfehler und vollständige Annex-B-Regeln |
| P02 | Deskriptoren/Accessoren, Prototypen, Enumeration, Freeze/Seal, new.target, call/apply/bind, Arguments, Fehlerfamilien, Builtin-Subklassen | ObjectModel, VM, Classes, Reflection | Volles globales Environment, Primitive-this-Boxing, Cross-Realm und alle Hostdeskriptoren |
| P03 | Breite Object/Array/String/Number/Boolean/Math/JSON/Date-Oberfläche; Array-Species, groupBy, Kopier-/Sortiermethoden, URI-Codecs; JSON.rawJSON/isRawJSON und Reviver-Kontext; Unicode-Normalisierung NFC/NFD/NFKC/NFKD und gemeinsamer Date-/Zeitzonenadapter | StandardLibrary, Strings, LibraryNumbers/JSON/Date, UnicodeNormalization, LibraryStringNormalization | Weitere Locale-/Legacy-Date-/Annex-B-Fälle und vollständige weltweite Zeitzonendaten; [Text-/Datenprofil](JAVASCRIPT-TEXT-DATA-20261005.md) |
| P04 | Symbol-Registry/Well-known Symbols, Iterator/Close, Iterator-Konstruktor/from/concat und synchrone Helfer, gemeinsame native Iterator-Prototypen, Map/Set/WeakMap/WeakSet, Live-Iteration, Map.groupBy, Set-Algebra | IteratorHelpers, Collections, StandardLibrary, Generators, VM | Keine AsyncIterator-Helfer oder unstandardisierten zip/join-Proposals; Luau-Weak-Keys sind keine vollständige Ephemeron-GC |
| P05 | Promise-Reaktionen/Kombinatoren/withResolvers/try/Species, Async/Await, Abort, Rejection-Events, Tasks/Microtasks/Timer/rAF, kooperative Idle-Callbacks und priorisierte Aufgaben mit TaskController/TaskSignal | Promises, AsyncFunctions, EventLoop, IdleCallbacks, Scheduler, TaskSignals, ScriptClock, HostEvents | Vollständiges Cross-Realm-/Hintergrund-Scheduling, exakte native Frame-Idle-Garantien und übrige Schedulingfälle |
| P06 | Live-Sammlungen/Abfragen, CharacterData/Baummutation, DOM-/HTML-Interfaces, Attr/Namespaces, HTML-/XML-Dokumente, Quirks/Doctype, Adoption/Clonezustände, Traversierung und Ranges, dynamische Tabellen, Shadow Roots/Slots sowie Custom Elements, scoped Registries und ElementInternals/FACE; XML-Namespace-Fixup und XMLSerializer mit dokumentierten API-/Standardgrenzen | DOM/Documents/Interfaces/Reflection/Tree/Queries/Traversal/Ranges/Controls/Tables, XMLSerialization, ShadowDOM, CustomElements, ElementInternals, DOMReconcile | Weitere Streaming-/Script-/Encodingfälle im bestehenden HTML-Tree-Builder, XML-DTD-/Entity-Parsing und Legacy-/Web-IDL-Konformitätsfälle; Details in R02/R03-Profilen |
| P07 | EventTarget/Handler, native Maus/Pointer/Touch/Tastatur/Wheel/Fokus/Input, Capture und frische Geometrie; Formulare/Validierung/FormData; Shadow-/Control-/Document-Selection, UTF-16/Grapheme, getComposedRanges, Selection.modify, Auswahl-Scrolling und retained rich/plaintext contenteditable | HostEvents, PointerCapture, NativeContentEditable, Editing, Selection/SelectionNavigation, ScriptSelection, TextControlSelection, DOMControls, FormDataDOM, Controls | Native IME-Preedit/OS-Dateiauswahl; vollständiges gemischtes Bidi, Editing/Undo/Rich-Clipboard, komponierte Navigation und Native-Pan-/Wheel-Garantien; Details im R04-Profil |
| P08 | Geometrie/StructuredClone, Client-/Bounding-Rects, client/offset/scroll, aktuelle animierte/pseudo-Computed-Styles, Media/Scroll; CSSOM-Regelfamilien, Deklarationen, Konstruktion/Adoption auch im ShadowRoot; Layer/Scope/Property/Counter-Style, dynamische Pseudoboxen und gemeinsames CSS-/CSSOM-Nesting | Geometry, ComputedStyle, CSSOM/Rules/Descriptors/Declarations, CSS/Nesting/Stylesheet/ShadowSelectors/CascadeLayers/ScopeRules/RegisteredProperties/CounterStyles, Rendering/GeneratedContent/RenderTree | Vollständige Regel-/Wertegrammatik und übrige Nestingfälle, Import-Transport/CORS, Fontdatei-/Print-/Font-Palette-Rendering, Legacy-SVGPoint/SVGMatrix und projektive Clips/Fragmentierung; [neues Profil](JAVASCRIPT-CSS-ANIMATIONS-20261005.md) |
| P09 | Observer; Web Animations mit Timing/Promises/Events, numerischen Layoutwerten, add/accumulate, einzelnen Keyframe-Composites, aktuellem Paint/Geometrie und commitStyles; gemeinsamer CSS-/WAAPI-Effektstapel, @starting-style; laufende Transition-Uhren, verkürzte Umkehr, Custom-Property-Paint-Keyframes und gemeinsames steps()/linear()-Easing; User Timing/PerformanceObserver | Performance, MutationObserver, LayoutObservers, WebAnimations, HTMLAnimations, AnimationValues, CSSDeclarations, CSS/Motion | Animationen aller Layout-/Paintproperties, auto/intrinsische Größen, Inlinefragmente/Pseudoelement-Ziele, komplette Motion-/Timeline-Kombinationen; iterationComposite als explizite Level-2-Erweiterung; [neues Profil](JAVASCRIPT-CSS-ANIMATIONS-20261005.md) |
| P10 | URL/URLSearchParams mit erweitertem IDNA-/IPv4-/IPv6- und Setterprofil, TextEncoder/Decoder/Streams, Binärdaten mit Integer-indexed TypedArray- und gewöhnlichen Propertydeskriptoren, Blob/File/FileList/FileReader/ProgressEvent, Objekt-URLs | LibraryURL, LibraryURLHost, LibraryURLIDNAData, BinaryData, NetworkData, FileData, ObjectURLs, EncodingStreams, Encoding/Decoder | URL-/Daten- und WHATWG-Decoderumfang siehe [Text-/Datenprofil](JAVASCRIPT-TEXT-DATA-20261005.md); keine OS-Dateiauswahl/implizite Blob-Bild-/Medienanbindung |
| P11 | Headers/Request/Response/fetch/Bodyzustände, Multipart/FormData; Readable/Writable/TransformStream, Reader/Writer/Pipe/Tee/Iteration, Abbruch/Backpressure; lokales fetch(blob:) mit Range; asynchrones gepuffertes XMLHttpRequest | NetworkData, XMLHttpRequest, FormData, Readable/Writable/TransformStreams | HTTP braucht echten Fetch-Transport mit Host-CORS/Credentials; synchrones XHR und echte Chunk-/Uploadfortschritte, WebSocket/EventSource/CompressionStreams bleiben offen |
| P12 | local/session Storage/Quota/Events, Location/History, geklonter Zustand, Hash/Popstate/Scrollzustände; Roblox-Host lädt vor Scriptstart und speichert pro Spieler/Origin; sessionStorage überlebt Dokumentwechsel; Web Locks koordinieren explizit geteilte partitionierte Hostspeicher | Storage/Client, Storage/Server, Storage/Protocol, JavaScript/Storage, WebLocks, Navigation, Runtime, HTMLScripts | DataStore-Zugriff muss verfügbar sein; Studio benötigt API Services. Ohne Host bleibt der dokumenteigene Memory-Speicher. IndexedDB/Cache API, Web-Locks-Actor-IPC und vollständige Storagepolitik bleiben offen; opaque Origin oder verweigerter Adapter bleiben SecurityError |
| P13 | Klassische/externe/async/defer Skripte, dynamische Inline-/src-Insertion und geordnete async=false-Quellen, inert HTML/aktive Range-Fragmente, currentScript, Module/Namespaces/lebende Imports/Reexports/Zyklen, dynamic import/import.meta, acyclic TLA, Importmaps/JSON-Module; HTMLScriptElement.supports, Ressourcenbarriere und einmaliger DOMContentLoaded/load-Lifecycle; Live-Parsing decodierter Stringquellen, document.write/writeln/open/close sowie verknüpfte/importierte CSS-Ladebarrieren, CSSOM-Importänderungen und unmittelbare Container-/Frame-Ladeabhängigkeiten | Modules, ScriptLoader, StylesheetResources, StylesheetGraph, DocumentStreams, HTML/DocumentBuilder, DOMTree/DOM/Node, Syntax, VM, Runtime, IFrameRuntime | Byte-/Netzwerkstreams, weitere Parser-/Navigationskontexte, zyklisches TLA und volle CSP/SRI/Fetch-Regeln offen; [H03-Nachweise](HTML-PARSER-ATTRIBUTES-20261006.md#h03-live-parser-und-dynamisches-schreiben--9-oktober-2026), [Ladeprofil](JAVASCRIPT-LOADING-20261005.md) |
| P14 | Public/private Klassenfelder/-Methoden/Accessoren, Vererbung/super/static Blöcke, sync/async Generatoren/yield*/for-await/finally, eval/dynamische Funktionskonstruktoren, alle Reflect-Methoden/Proxy-Traps | Classes, Generators, DynamicCode, Reflection, VM, Syntax | Alle frühen Syntaxfehler/exotischen und Cross-Realm-Wechselwirkungen |
| P15 | RegExp/Unicode-Profil, BigInt-Arithmetik/Bitoperationen, Binärdaten/Detach/Transfer, DisposableStack/AsyncDisposableStack/SuppressedError, using/await using, Intl Locale/NumberFormat/ListFormat/DateTimeFormat mit erweiterten de/en- und Zeitzonenprofilen | RegExp, BigInt, BinaryData, ResourceStacks, Intl, IntlLists/ListData/DateData | Verfügbare Locales, Zahlen-/Kalender-/Zeitzonenbereiche und Referenzversionen siehe [Text-/Datenprofil](JAVASCRIPT-TEXT-DATA-20261005.md); übrige CLDR-Familien, WeakRef/FinalizationRegistry, SharedArrayBuffer/Atomics offen |
| P16 | HTML-Canvas-2D im gemeinsamen Realm: CPU-Bitmap/Pixel/Gradient/Pattern/Transform/PNG, Upload/Detach/Reset; Path2D-Kopien/SVG-Quellen/addPath, fill/stroke/clip/PointInPath; dynamische SVG/Image/Media/IFrame-Ressourcen; Image/decode/Metadaten/Ereignisse und FontFace/document.fonts; Audio()/new Audio(), play()-Promise, pause/load, Zeit/Rate/Lautstärke, Zustände/TimeRanges/Fehler/Ereignisse und geteilte native Controls | DOMCanvas/DOMCanvasPaths, CanvasRuntime/Surface, StructuralResources, ImageResources, FontLoading, ResourceLoadHost, AudioElements, AudioHost, MediaRuntime, HTMLPage | Transparentes sRGB/RGBA8, 2048²-Pixelgrenze, polygonale Kurven/CPU-Kantenglättung; roundRect/isPointInStroke, WebGL/WebGPU/OffscreenCanvas und übrige Bild-/Font-/CORS-/SVG-/Medienfamilien; [Ladeprofil](JAVASCRIPT-LOADING-20261005.md), [Audioprofil und konkrete Hostgrenzen](JAVASCRIPT-AUDIO-20261006.md) |
| P17 | StructuredClone/Transfer, MessageChannel/Port, BroadcastChannel, Window-postMessage; klassische und Modul-Worker in eigener VM/Ereignisschleife über Roblox-Actors, importScripts, Timer/Promise/Fehler/close/terminate | StructuredClone, Messaging, WorkerAdapter, WorkerRealm, Rendering/WorkerHost/WorkerRunner | Paketierte Quellen; gezeigte Studio-Fälle von Tobias bestätigt, kein Parallelitätsbenchmark. Worker-Porttransfer, verschachtelter Host, SharedWorker/ServiceWorker/Shared Memory und volle Worker-Netzwerkregeln offen |

Date nutzt standardmäßig UTC; DefaultTimeZone oder ein expliziter Zeitzonenadapter ermöglichen das dokumentierte lokale Profil. Intl verwendet dieselben versionierten Zonen. URL/Intl behaupten keine Unterstützung ihrer offenen Unterfamilien. Interne Disposer, Codecs und JSON-Module bleiben von geänderten globalen Konstruktoren unabhängig.

## Historische Vergleichsseite 08

Sieben Karten zeigen Web Storage, dynamische Tabellen, erhaltene Shadow-Komponenteneingaben,
Pointer-Capture/Touch/Unicode-Edits, Counter/Attribute/Klassen/Pseudoelemente,
CSSOM-Layer/Scope/Property/Keyframes und CSS-/WAAPI-Layoutanimationen mit
Pause/Commit/Cancel. Neue Elemente zeigen außerdem Eintrittsübergänge.
[Profil, Nachweise und Grenzen](JAVASCRIPT-DOM-CSS-EXTENSIONS.md).
Der native Roblox-Sichtvergleich steht noch aus; es gibt keine FPS-Messung.

## Historischer Vergleich 07

Fünf Karten zeigen geordnete dynamische Skripte und genau einmaligen Inline-Code,
ListFormat-Ausgaben/Parts mit Sprach- und Typwechsel, wiederverwendbare Canvas-Häuser
mit Kopien/Füllregel/Clipping, klassische/Modul-Worker mit Bereitschaftssignal und
hin-/zurückübertragenem Puffer sowie modal/nichtmodal/Popover. Ausgelieferter HTML-
und Ressourcenquelltext wird gemeinsam geprüft; Browser-Worker verwenden echte
Worker, die Luau-Funktionsprüfung eigenständige WorkerRealms. Studio-Actors werden
dabei nicht automatisch nativ geprüft. Tobias hat die gezeigten Studio-Fälle
nach den Renderer-/Actor-Brückenkorrekturen bestätigt.

Die gemeinsame Dialogkorrektur verlegt Browserdefaults vor die Autorenkaskade,
unterscheidet ordinary containing blocks und Top-Layer-Platzierung, berücksichtigt
Scrollbar-/CSS-Viewportbreiten, Schrift-/Padding-/Maxgrößen und reale Scrolllage.
104 geometrische Browserreferenzen bei zwei Größen und zwei Scrollständen sowie
24 native Mausaktionen auf Vergleich 06 bleiben Regressionen.

Neue Referenzen: 22 ScriptLoader-, 58 erweiterte Bibliotheks-, 18 Path2D- und acht
Worker-Abläufe. Der Abschlusslauf umfasst 45 relevante Testgruppen, einschließlich
aller historischen Vergleichsseiten, Input, lokalen Layouts, Canvas, Animation,
Lifecycles und GC. Der Rojo-Build und Worker-Runner-Kompilierung bestehen. Kein
FPS-Benchmark. [Scripts](JAVASCRIPT-SCRIPTS.md), [Intl](JAVASCRIPT-INTL.md),
[Canvas](CANVAS.md), [Worker](JAVASCRIPT-WORKERS.md),
[Dialoge](JAVASCRIPT-TOP-LAYER.md). Nach den Script-/Worker-Hostkorrekturen bestehen
13 relevante Regressionstestgruppen erneut. Tobias hat die gezeigten Funktionen
in Studio bestätigt; ein FPS-/Parallelitätsbenchmark wurde nicht durchgeführt.

## Historischer Vergleich 06

Quelltext: tests/fixtures/javascript-top-layer-review-page.json.

Fünf Karten zeigen modale Formulardialoge, cancel/requestClose und nichtmodales Öffnen, Auto-Popover und ToggleEvent.source, abbrechbare/manuelle/bündelbare Popover sowie Zeitmarken, Messungen, buffered Observer und takeRecords. Die Zeitachse verwendet feste Beispielzeiten und misst keine FPS. Der Browservergleich enthält 25 echte Bedienzustände; derselbe Quelltext wird durch native Controls, Fokus, Formulare, Styles und Paint geprüft. Zusätzliche Prüfungen erfassen dynamisches Einfügen/Entfernen, Attributkonvertierung, Resize, Opacity, gemeinsame Ebenenreihenfolge, Aufgabenbudgets und Abbau.

Referenzen: 21 Dialog-/Popoverfälle und 22 Zeitmessungsfälle stimmen mit dem nativen Browser überein. Die Luau-Zeitmessung prüft zusätzlich fehlendes Navigation-Timing. 37 relevante Regressionstestgruppen bestanden, einschließlich früherer Vergleichsseiten, Realm-/Ressourcenlebensdauer, Eingaben, Layout und Animationen. [Dialog-/Popoverprofil](JAVASCRIPT-TOP-LAYER.md), [Zeitmessungsprofil](JAVASCRIPT-PERFORMANCE.md). Der Sichtvergleich dieser neuen Karten in Studio ist noch offen.

## Historischer Vergleich 05

Tobias hat den sichtbaren Stand bestätigt. Der Quelltext bleibt unter tests/fixtures/javascript-selection-commit-review-page.json erhalten.

Fünf Karten zeigen Textauswahl und Richtung, Ersetzen und Caretposition, UTF-16/Eingabetypfehler, das Speichern einer Animation sowie den begrenzten Stapel zweier Effekte. 20 echte Browserzustände werden gegen den unveränderten HTML-/CSS-/JavaScriptquelltext mit nativen Editor-, Paint- und Layoutwegen geprüft. Ein tatsächlich laufender Frameverlauf prüft Commit/Cancel und Callbackfreigabe. Die erlaubte none/forward-Plattformrichtung wird im Vergleich eng unterschieden. [Textfeldprofil](JAVASCRIPT-TEXT-CONTROLS.md), [Commitprofil](JAVASCRIPT-ANIMATION-COMMIT.md).

Abschluss: 33 relevante Regressionstestgruppen bestanden, einschließlich 16 Textfeld- und 17 Animationsreferenzen. GC-/Kapazitätsprüfungen laufen wie die vorhandenen Rendering-Lebensdauertests in frischen Luau-Prozessen, damit frühere Raster-/VM-Heaps nicht den inkrementellen Collector-Zeitpunkt bestimmen; sämtliche Assertions und Produktionsbudgets bleiben erhalten. Browser-/Roblox-Quellen sind unverändert identisch synchronisiert. Kein FPS-Benchmark; Tobias hat Vergleich 05 visuell bestätigt.

## Historischer Vergleich 04

Fünf CSSOM-Karten zeigen Regel-/Selektorwechsel, Prioritäten und Innenabstand, Media-/Supports-Gruppen, konstruierte/adoptierte Blätter mit Promise-Ersetzung sowie Style-Textänderung und Lebensdauer. 19 Browserzustände bleiben gegen den eingefrorenen Seitenquelltext in tests/fixtures/javascript-cssom-review-page.json und native Roblox-Paintwege geprüft. Tobias hat den sichtbaren Stand bestätigt. [Profil und Grenzen](JAVASCRIPT-CSSOM.md).

## Historischer Vergleich 03

Die fünf Range-Karten bleiben in tests/fixtures/javascript-range-review-page.json geprüft. Sie zeigen Auswahlrichtung, lebende Grenzen, Inhaltsoperationen, StaticRange und native Auswahlrechtecke. [Profil und Nachweise](JAVASCRIPT-RANGE-SELECTION.md).

## Historischer Vergleich 02

Die folgenden dreizehn Karten sind jetzt nur noch in tests/fixtures/javascript-review-page.json und der zugehörigen Integrationssuite enthalten.

Dreizehn Karten zeigen echte API-Ergebnisse, erwartetes Verhalten und Fehleranzeigen. Die drei neuen Karten stehen zuerst:

- Iterator-Pipeline: lazy filter/map/take, einzelne Treffer, Abbruch und Generator-finally.
- DOM-Traversierung: unterschiedliche FILTER_SKIP-/FILTER_REJECT-Wirkung in TreeWalker und NodeIterator; Knoten entfernen.
- Geometrie: DOMPoint über Matrix transformieren, mit Inverse zurückführen, Matrixkopie ändern und DOMQuad-Grenzen anzeigen.

Die zehn bisherigen Kombinationen bleiben darunter erreichbar:

1. Array/Map/Set-Suche, RegExp, JSON, BigInt und deutsche Währungsformatierung; eine Zahl außerhalb des sicheren Number-Bereichs über Reviver-Kontext und Raw JSON exakt erhalten.
2. Eventdispatch/FormData; Notizen einfügen, verschieben und entfernen, Eingabezustand behalten; lebende Namens-/Namespace-Abfragen nach Mutation und Umbenennen ablesen.
3. Timer-/Microtask-/Promise-Reihenfolge, Async/Await und Abort.
4. Vererbung/private Felder/Generator, Proxy/Reflect, dynamische Function und using-Aufräumen.
5. TextEncoder/TypedArray/DataView/File/FileReader/URLSearchParams und sofortiger Abbruch.
6. Objekt-URL/fetch/Response und Readable → Transform → Writable.
7. Geometrie/getComputedStyle sowie Mutation-/ResizeObserver.
8. Web Animations/Canvas: Verlauf/Kreis/Pixel, gleicher-Wert-Bitmapreset.
9. Dokument-Memory-Storage und History ohne Dokumentwechsel.
10. ES-Modul, StructuredClone/Buffertransfer und MessageChannel mit Map-Kopie.

Die Seite startet keine endlose Animation oder FPS-Benchmark. Tobias ergänzt den nativen Roblox-Sichtvergleich.

## Review und Nachweise

Geteilte Fixtures laufen in nativem Node/Chromium und Luau. Bekannte Referenzabweichungen sind mit getrennten Erwartungen dokumentiert. Die Engine folgt dem ausgewiesenen Browser-/Standardprofil.

| Prüfung | Nachweis beim Paketabschluss |
| --- | --- |
| Alltagssprache / Klassen | 47 / 16 gemeinsame Fälle |
| Klassen/Builtin-/Species-Integration | 34 gemeinsame Fälle und tatsächlicher Chromium-Vergleich |
| Dynamische Evaluation | 10 gemeinsame Fälle; dynamische Async-/Generator-Konstruktoren zusätzlich im Generatortest |
| Generatoren / using und await using | 36 / 32 gemeinsame Fälle und Chromium-Vergleich |
| Standardbibliothek / Reflect-Proxy | 62 / 37 gemeinsame Fälle |
| Raw JSON | 33 gemeinsame Fälle in Luau und Chromium plus Realm-Wechsel/Abbau, UTF-16-Grenzfälle, Reviver-Seiteneffekte und Budgets |
| Iterator-Helfer / TypedArray-Eigenschaften | 65 / 30 Fälle in Luau und Chromium; explizite Referenzabweichungen separat |
| DOM-Traversierung | Zehn gemeinsame Browsergruppen plus GC, Abbau, abgelehnte Mutation und Budget-Recovery |
| Range und Inhalte | Elf native Kerngruppen mit sechs engen Standardabweichungen; 37 Browser-/Luau-Inhaltsfälle; Hierarchie/Preflight/GC/Budget/Destroy |
| Selection und native Zuordnung | 18 API-Profilfälle und vier zusätzliche native Rendered-Text-Gruppen; Tasks/Events/Geometrie/Clone/Abbau sowie zwei native Mapping-Suites |
| CSSOM | Semantik-/Receiver-/Konvertierungs-/Lebenszyklusfälle mit nativer Referenz; gemeinsame Deklarationsschnittstelle, gezielte Paint-/Layoutintegration und 19 tatsächliche Browserzustände der neuen Seite |
| Realm-Lebensdauer | Geschlossene VMs/Seiten werden vom tatsächlichen Luau-GC freigegeben; extern gehaltene Nullprototype-Objekte behalten ihre private Konvertierungslaufzeit bis zur letzten Referenz |
| Lebende DOM-Abfragen | Neun Gruppen strikt Chromium-gleich plus Konvertierungs-/Mutationsreihenfolge, 256 Elemente im Defaultbudget, Cache-Invalidierung und Abbau |
| BigInt / Zahlenparser / erweitertes Bibliotheksprofil | 214 / 71 / 58 Fälle; ListFormat zusätzlich in Chromium geprüft |
| Async/Events | 44 Chromium/Luau-Abläufe plus Hostyield/Coroutine |
| Netzwerk/Dateien/Streams | 71 Chromium/Luau-Fälle plus Transport/Abbruch/Registry/Queue/Lebenszyklus |
| FormData-DOM / RegExp / Messaging | 9 / 34 / 24 gemeinsame Fälle |
| Geometrie | 14 gemeinsame Fälle plus verschmutzte Layouts/Abbau |
| Geometrieobjekte / Klonen | 36 gemeinsame Fälle plus Ziel-Realm-Typen, Graphidentität, Bytebudget und atomare Transferfehler |
| Matrix-Arithmetik / CSS-Transformparser | 13 Gruppen mit 123 Beobachtungen / 122 Fälle plus Limits; numerische Referenzabweichungen und ein Chromium-Crash-Skip ausgewiesen |
| Module / zusätzliche Modulreviews | 21 / 7 gemeinsame Prüfungen |
| ScriptLoader | 22 tatsächliche Chromium/Luau-HTML-Vergleiche |
| Path2D | 18 Chromium/Luau-Pixel-/Geometrie-/Objektsemantikfälle |
| Dedicated Worker | Acht Chromium/Luau-Workerabläufe, unabhängige Realm-/Actorhost-Budget-/Cleanup-Prüfungen, vier suspendierende Hostbrückenfälle; gezeigte Studio-Fälle von Tobias bestätigt, kein Parallelitätsbenchmark |
| Storage/Navigation | 19 gemeinsame Fälle plus Quota/Multi-Realm/Abbau |
| DOM/Controls/Observer/WAAPI/Canvas | 16 zentrale Fälle gemeinsam grün, einschließlich tatsächlichem Seitencode, Canvas-Hostyield, Memory-Storage und Observerbudget |
| Inkrementelles Layout | Checkbox-Fallback: 12 Aufrufe bei 1000/560/320 px; 36 Karten: 6–10 lokale gegenüber 188–368 vollständigen Aufrufen |

Nach jedem größeren Paket wurden auch VM, Ereignisschleife, DOM, Layout, Rendering und Eingaben geprüft. Korrigiert wurden unter anderem native Inputwerte neuer Knoten, Observer-Wiederplanung, IteratorClose/Completed-Result-Getter, Generator-/Promise-Aufräumen, Script-/Importmap-Reihenfolge, CSS/WAAPI-Paint-Präzedenz und Canvas-Hostyield-/EditableImage-Races. Die tatsächliche Seitencodeprüfung steht in tests/JavaScriptReviewPage.luau.

Interne Property-Descriptor-Records besitzen jetzt einen Null-Prototyp oder gehen direkt durch DefineOwn. Änderungen an Object.prototype.get/set beeinflussen dadurch weder AST-Funktionen noch native APIs, Klonen oder Bibliotheksoperationen. Öffentliche Object/Reflect.defineProperty lesen weiterhin geerbte Descriptor-Felder in der vorgeschriebenen Reihenfolge; sichtbare getOwnPropertyDescriptor-Ergebnisse behalten Object.prototype. tests/JavaScriptNativeDescriptors.luau prüft diese Kombination über Runtime, Klassen, Streams, Geometrie, Traversierung und Ereignisse.

DOMQueries hält Ergebnisse pro lebender Abfrage und DOM-Revision. Öffentliche Struktur-/Attributmutationen invalidieren die Revision; unveränderte Attribute und reine Formwertänderungen tun das nicht. Eine zweite Iteration derselben unveränderten Sammlung scannt den DOM-Baum nicht erneut. Die neue Abfragefamilie erhält weder einen Frame-Treiber noch eine Polling-Schleife. Für externe direkte Luau-Schreibzugriffe auf Knoten/Attribute muss der Host weiterhin Mutation melden.

Raw JSON verwendet eine unveränderliche interne Marke, ohne Proxy-Traps oder nachschlagbare globale Konstruktoren. Die Quelle im Reviver-Kontext folgt dem tatsächlichen Parse-Pfad und wird nach Austausch von Werten nicht weitergereicht. Zusammengefügte UTF-16-Surrogatpaare werden an String-Erzeugungsgrenzen vereinheitlicht; einzelne Surrogate bleiben erhalten. JSON-Raw-Wrapper und lebende Iterator-/Traverserobjekte werden beim StructuredClone ausdrücklich abgelehnt. Map/Set-Kopien verwenden gespeicherte Intrinsics; Error.message wird nur aus einer eigenen Dateneigenschaft kopiert. Die Queuebudgets berücksichtigen auch primitive Nutzlasten, Einträge und wiederholte Referenzen.

Der neue Iterator-Unterbau erfasst außerdem `Symbol.hasInstance`, gewöhnliches `instanceof` und die observable Prototyp-/length-/name-Abfragefolge von `bind`. TypedArray-Expandos teilen das ObjectModel für Deskriptoren, Symbole, Receiver und Extensibilität; Integer-indexed Regeln gelten weiterhin für kanonische Indexschlüssel. Die Traversierung besitzt aktive Filter-Reentranzprüfungen und einen Vor-Entfernungshook, der ohne Autor-Callback die NodeIterator-Position anpasst.

Bekannte Chromium-Abweichungen sind eng im Vergleichsdatensatz markiert: concat-Pullfehler, TypedArray `-0.0` und `isSealed`, ein letzter entfernter NodeIterator-Teilbaum, gemeinsame DOMQuad-Punktreferenzen beim StructuredClone sowie Error.message nach einem seiteneffektbehafteten name-Getter. Die Engine folgt hier dem jeweiligen Standard statt den Browserfehler nachzubauen. Belege: [ECMAScript-Iteratoren](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-iterator.concat), [DOM-Vorentfernung](https://dom.spec.whatwg.org/#concept-nodeiterator-pre-remove), [WPT-Interopkorrektur](https://github.com/web-platform-tests/wpt/pull/60997), [Geometrieserialisierung](https://drafts.csswg.org/geometry/#serialization), [HTML-StructuredClone](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializeinternal).

DOMMatrix rechnet mit Double-Präzision und erhält negative Nullwerte, echte No-ops und belegte NaN-Zustandsübergänge. Zwei extrem große/kleine Rotationsachsen werden robuster normalisiert als in Chromium. Beim Transformparser entsprechen 113 von 122 Fällen der erfassten Chromium-Ausgabe; acht neuere CSS-/Numerikfälle haben getrennte Standard- und Browsererwartungen. `perspective(none)` wird im Engine-Test geprüft, im nativen Vergleich wegen eines tatsächlich beobachteten Chromium-Absturzes ausgelassen. Relative Längen, var/env und nicht unterstützte CSS-Typfamilien werden ausdrücklich abgelehnt.

Der gemeldete LayoutObservers-Fehler durch kumulierte VM-Schritte ist behoben: unabhängige Host-Publikationen besitzen ein frisches Budget; verschachtelte Callbacks teilen es. Auch Script-URL- und native Eventvorbereitung nach einem Budgetabbruch sind eingeschlossen. VM-Budgetbesitz ist vom tatsächlichen Autor-Scriptstack getrennt, und verschachtelte Entries melden Schrittdifferenzen. Geprüft sind 10.000 unveränderte Publikationen auf der echten Seite sowie zusätzlich 10.000 unveränderte und 1.000 veränderte Observer-Runden, Event-/Script-Recovery und native Measurement-Yields mit gesperrter paralleler Eingabe. Zwei Observer liefern A → Microtask A → B → Microtask B; diese Reihenfolge ist auch im nativen Chromium gemessen. Grundlage: [ResizeObserver-Callbackauslieferung](https://drafts.csswg.org/resize-observer/#broadcast-active-resize-observations) und [HTML-Microtask-Checkpoint nach Scriptcleanup](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-script).

## Budgets und Hostgrenzen

Standardprofile: Arrays/Sammlungen 16.384 Einträge, Strings 65.536 Bytes, BigInt 4.096 Bits; Datei/Body 1 MiB, FileList 1.024 Dateien; 256 Objekt-URLs/8 MiB Registry; Canvas maximal 2048 × 2048 mit Pixelgrenze. Es gelten zusätzlich Schritte-, Tiefen- und Queuebudgets. Diese Limits sind Ressourcenentscheidungen und keine erfundenen Webstandards.

Traverser sind auf 4.096 Erstellungen je Realm-Lebensdauer begrenzt. Geometrie-Transformstrings verwenden höchstens 16.384 Tokens, 64 Ebenen für CSS-Mathematik, 256 mathematische Argumente und 4.096 Transformfunktionen. Geometrie-Klone werden im bestehenden Byte-/Objektbudget vollständig mitgerechnet.

Hostpausen auf native Dienste bleiben von JavaScript-await und Generator-yield getrennt. Resize startet Skripte nicht erneut. Cleanup stoppt Timer, Jobs, Fortsetzungen, Listener und Ressourcen ohne erfundene Benutzer-finally-/Dispose-Aufrufe.
