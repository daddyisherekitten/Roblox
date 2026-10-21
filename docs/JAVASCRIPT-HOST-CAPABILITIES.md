# Roblox-Hostprofil

Stand: 18. Oktober 2026. Das API-Register unterscheidet Implementierung, dokumentierte
Hostfähigkeit und einen tatsächlich beobachteten Studio-/Live-Test. Eine vorhandene
Methode beweist weder Berechtigung noch erfolgreiche Übertragung oder Persistenz.

`src/HTMLEngine/Diagnostics/HostCapabilities.luau` liefert auf ausdrücklichen Aufruf
einen versionierten, lesenden Snapshot. Er führt keine HTTP-Anfrage aus, schreibt
keinen DataStore und erzeugt keinen Frame-Loop. Native Messungen dieser Etappe sind
noch nicht aus Studio bzw. einem veröffentlichten Server geliefert worden.

| Fähigkeit | Studio | Veröffentlichtes Spiel | Adapter und verbleibender Nachweis |
| --- | --- | --- | --- |
| HTTP | Host-/Konfiguration prüfen | Servertransport mit aktivierten HTTP-Anfragen | `HttpService.RequestAsync`; Browser-Origin-/CORS-/Cookie-Regeln zusätzlich in R09. Transport nicht vorhanden. |
| Streaming/WebSocket | Methoden und Ausführungskontext prüfen | Berechtigungen und konkrete Protokolle separat prüfen | `CreateWebStreamClient`/`WebStreamClient` als Kandidat für R09/R10; API-Vorhandensein ist kein funktionierender Fetch-Stream. |
| Binärdaten | Luau buffer verfügbar, Engine-Binärtests bestehen | Derselbe Pufferadapter | Kopieren/Transfer bleiben Engine-Semantik; gemeinsam zugänglicher Speicher wird daraus nicht abgeleitet. |
| Dauerhafte Speicherung | API-Zugriff und veröffentlichte Experience erforderlich | DataStore-Serveradapter vorhanden | Engine-Tests prüfen Quota/Revision/Fehler; Laden nach neuer echter Sitzung ist weiterhin nicht bestätigt (R00/R11). |
| Fonts | Assetzugriff/Preload abhängig vom Host | Assetzugriff/Preload abhängig vom Host | FontFace/document.fonts und Ladeereignisse sind im [lokalen Ladeprofil](JAVASCRIPT-LOADING-20261005.md) implementiert. Native Zuordnung nutzt bestehende Font-Profile und tatsächlichen Preload; beliebige Webfontdecoder/Aliases bleiben offen. |
| Texteingabe | TextBox liefert Text, Cursor und Auswahl | Derselbe native Eingabepfad | R04 verarbeitet veröffentlichte Unicode-Änderungen; keine erfundenen IME-Zwischenstände. |
| OS-Dateiauswahl | Kein Adapter installiert | Kein Adapter installiert | `input type=file` zeigt den Auswahlbutton, öffnet aber bewusst noch keinen Dialog; [Umfang und späterer Hostweg](HTML-INPUT-TYPES-20261006.md). Vom Host gelieferte `File`-Werte bleiben getrennt davon. |
| Bild-/Pixelgrafik | EditableImage-Verfügbarkeit/Budget prüfen | Berechtigungen/Budget prüfen | Image/decode/Metadaten sind an explizite Raster-/SVG-Quellen angebunden. Rastermaße benötigen CreateEditableImageAsync-Rechte; Hostmocks beweisen deren Logik, nicht tatsächliche Assetrechte. Vorhandene CPU-Pixelpfade begründen keine beliebigen GPU-Shader (R15/R18). |
| Medien | Assetrechte und native Wiedergabe prüfen | Assetrechte und native Wiedergabe prüfen | [Audio-Soundhost](JAVASCRIPT-AUDIO-20261006.md) mit Lade-/Fehler-/Zeitadapter vorhanden; echte hörbare Wiedergabe bleibt separat nachzuweisen. Vollständige Video-/Track-/Codec-/Autoplay-/Streamingparität bleibt offen (R16). |
| Virtueller Bildschirm | Fensterhost liefert Arbeitsfläche | Derselbe Hostvertrag | `window.screen` besitzt lebende, nur lesbare width/height/availWidth/availHeight sowie availLeft/availTop=0 und colorDepth/pixelDepth=24. Browser- und HTML-Fallbackhost liefern ihre tatsächliche Fensterfläche; ohne Host gilt der Dokumentviewport. Dies beschreibt einen virtuellen Bildschirm innerhalb der Roblox-GUI, keine physischen Monitore oder Window-Placement-API. |
| Shared Memory | Nicht nachgewiesen | Nicht nachgewiesen | Actor-Nachrichten und kopierte Puffer ersetzen kein SharedArrayBuffer-/Atomics-Modell (R19). |
| Web Locks | Explizit geteilter In-process-Store zwischen tatsächlichen Runtime-/WorkerRealm-VMs geprüft | Derselbe Hostvertrag, native Actorgrenze separat | `Engine.createWebLockStore()` und `WebLockStore`/`WebLockPartitionKey` trennen Partition/Herkunft. Das Beispiel teilt einen Store zwischen Tabs, Popups und HTML-Fallback. Ohne Hostsharing bleibt ein realm-eigener Store. Roblox-Actor-IPC und vollständige browsergleiche Storage-/SecureContext-Policy fehlen; [begrenztes Profil](JAVASCRIPT-IMPLEMENTATION.md#web-locks-im-hostspeicher--18-oktober-2026). |
| Priorisierte Aufgaben | Eigener EventLoop/TaskController in VM-/WorkerRealm-Tests geprüft | Derselbe begrenzte Tasktreiber | `scheduler.postTask/yield` verwendet bestehende Tasks/Microtasks. Prioritäten ordnen eigene wartende Aufgaben; native Roblox-Threads, Eingaben, Compositor oder parallele Dokumente erhalten dadurch keine OS-Prioritäten. [Umfang und Grenzen](JAVASCRIPT-IMPLEMENTATION.md#priorisierte-aufgaben--18-oktober-2026). |
| GC | Weak-Registry-Lebensdauer getestet | Native Laufzeit noch separat prüfen | WeakRef-/FinalizationRegistry-Jobgarantien fehlen; nicht als Konformität geführt (R19). |

Die Zuordnung stützt sich auf die öffentlichen Primärreferenzen
[HttpService](https://create.roblox.com/docs/reference/engine/classes/HttpService),
[WebStreamClient](https://create.roblox.com/docs/reference/engine/classes/WebStreamClient),
[DataStoreService](https://create.roblox.com/docs/reference/engine/classes/DataStoreService),
[buffer](https://create.roblox.com/docs/reference/engine/libraries/buffer),
[TextBox](https://create.roblox.com/docs/reference/engine/classes/TextBox),
[TextLabel](https://create.roblox.com/docs/reference/engine/classes/TextLabel) und die
[Luau-Bibliothek](https://luau.org/library/). Aussagen über fehlende Adapter
beschreiben den aktuellen Engine-Code; sie behaupten keine prinzipielle
Unmöglichkeit eines späteren Hostwegs.
