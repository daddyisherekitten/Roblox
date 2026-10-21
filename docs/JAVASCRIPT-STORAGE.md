# Web Storage und Roblox-Persistenz

Stand: 5. Oktober 2026. Der [Browser-Grundlagen-Durchlauf](JAVASCRIPT-FOUNDATIONS-20261005.md)
hat die bestehenden Storage-/Runtime-/Client-/Server-/Rendering-Prüfungen erneut
einbezogen. Die neue [Atelier-Seite](http://localhost:8000/browser-foundations/index.html#speicher)
verwendet ausschließlich `atelier.browser-foundations.note.v1`. Im echten Browser
wurde Speichern → Reload → Abrufen geprüft und die eigene Testnotiz danach über
den vorgesehenen Löschen-Button entfernt. Die montierte Engineprüfung kontrolliert
dieselben Werte und unveränderte Textgeometrie ohne zusätzliches Layout.
Dies ist kein Nachweis eines echten Roblox-DataStore-Commits: dessen persistente
Wiederherstellung unter den unten beschriebenen Hostrechten bleibt separat offen.

Der gewöhnliche HTML-Code verwendet `localStorage` und `sessionStorage`. Die JavaScript-Oberfläche in `src/HTMLEngine/JavaScript/Storage.luau` ist dieselbe für den Browservergleich und den Roblox-Host: Stringschlüssel/-werte, `getItem`, `setItem`, `removeItem`, `clear`, `key`, `length`, benannte Properties, Quoten und `StorageEvent`.

## Lebensdauer und Zuordnung

| Bereich | Roblox-Speicherhost | Browservergleich |
| --- | --- | --- |
| `localStorage` | DataStore-Daten pro Spieler und HTTP(S)-Origin; im Client unmittelbar zugänglicher Speicher mit asynchroner Speicherung | Nativer dauerhafter Speicher der Origin im Browserprofil |
| `sessionStorage` | Client-Speicher pro Origin und Engine-Browserhost; überlebt Dokumentwechsel und erneutes Laden, endet mit diesem Host | Speicher pro Origin und Browsing Context; überlebt Reloads, endet beim Schließen des Tabs |
| Ohne Speicherhost | Begrenzter dokumenteigener Memory-Speicher; keine behauptete Dauerhaftigkeit | Keine Veränderung des nativen Browserhosts |

Origin bedeutet Schema, Host und Port, nicht den Seitenpfad. Zum Beispiel teilen `http://localhost:8000/main/index.html` und `http://localhost:8000/javascript-tests/index.html` ihre Bereiche. Ein anderer Port oder HTTPS erhält eigene Bereiche. Die serverseitige Origin-Zulassung verhindert, dass beliebiger Scriptcode unbegrenzt weitere Profile anlegt. Der Server entnimmt die Spieleridentität dem Roblox-Remoteaufruf; sie kommt nicht aus einem clientseitig ausgewählten UserId-Feld.

Same-origin-Unterdokumente verwenden denselben lokalen Bereich und den Sitzungsspeicher ihres Browserhosts. Opaque Origins und Sandbox-Dokumente ohne `allow-same-origin` bekommen keinen solchen Zugriff. Storage-Daten sind nicht automatisch gemeinsame Spielerdaten: Ein anderer Spieler besitzt ein anderes lokales Profil.

## Hostanbindung

`Storage/Client.luau` stellt den langlebigen Clienthost bereit. Der Roblox-Demo-Client erstellt ihn einmal und übergibt denselben Host als `StorageHost` an jeden Seitenmount. `Client.new` erlaubt einen injizierten Transport; die Roblox-Anbindung verwendet `Client.fromReplicatedStorage`. Der Server wird über das HTMLPage-Rojo-Projekt eingebunden.

`StorageHost:Prepare(DocumentURL)` lädt den lokalen Bereich vor dem Start der Dokument-Scripte. Dadurch sehen bereits die ersten `getItem`-Aufrufe den geladenen Zustand. Die Runtime erhält anschließend einen `GetStorageArea`-Adapter. Das Zerstören eines Dokument-Realms entfernt dessen Subscriber, löscht jedoch keine externen Hostbereiche. Ein explizit verweigerter Adapter wird nicht durch leeren Memory-Speicher ersetzt.

JavaScript liest und schreibt synchron im Clientbereich. Der Commit-Hook nimmt Änderungen vor der Mutation in die begrenzte Transportwarteschlange auf. Kann er eine Änderung nicht aufnehmen, bleibt der Bereich unverändert und die API meldet `QuotaExceededError`. Die VM wartet dabei nicht auf einen Roblox-Remoteaufruf und blockiert keinen Frame für ein DataStore-Update.

Änderungen werden asynchron gebündelt übertragen. Der Server prüft Origin, Nachrichtengröße, Operationsformen, Quoten und Reihenfolge und speichert Deltas mit `DataStore:UpdateAsync`. Er ersetzt nicht das gesamte Profil durch einen möglicherweise alten Client-Snapshot. Wiederholte Übertragungen verwenden eine Sitzungs-/Batchkennung und werden idempotent bestätigt. Zwischenzeitlich hinzugekommene Änderungen bleiben in der Warteschlange, bis auch ihr Batch bestätigt ist. Fehlgeschlagene Speicherungen werden erneut versucht; ein Fehler beim ersten Laden wird nicht als erfolgreicher leerer Speicher behandelt.

Der serverseitige Abschluss ist von der synchronen JavaScript-Mutation getrennt. Ein zurückgekehrtes `setItem` bedeutet, dass die Änderung im Client übernommen und zum Speichern angenommen wurde. Bei einem fortdauernden Netzwerk-/DataStore-Ausfall kann der Host keine erfolgreiche dauerhafte Speicherung garantieren. Seiten sollten keine erfundene synchrone Erfolgsgarantie für den Roblox-Backendzustand anzeigen. `StorageHost:Flush(timeout)` erlaubt dem Host ein geordnetes Schließen mit Warten auf die dauerhaften Bestätigungen; die Demo nutzt dafür zehn Sekunden. Ein abrupt beendeter Client kann noch nicht übertragene Änderungen verlieren. Bereits akzeptierte Batches werden bei `PlayerRemoving` und Serverabschluss erneut gespeichert.

Die gemountete Seite veröffentlicht `StorageStatus` (`unavailable`, `pending`, `saved`) und `StorageError` als Roblox-GUI-Attribute. Ein Speicherfehler bestätigt keinen Batch. Das Dokument erhält weiter die standardisierte Web-Storage-Oberfläche; es gibt kein zusätzlich erfundenes JavaScript-Erfolgsereignis.

## Quoten und Ereignisse

Pro Bereich gelten standardmäßig 1 MiB, gemessen als zwei Bytes je UTF-16-Codeeinheit von Schlüsseln und Werten, und höchstens 4096 Einträge. Der Transport begrenzt jeden Batch auf 128 Änderungen und seine kodierte Größe auf 2,3 MB; die ausstehenden kodierten Änderungen besitzen zusätzlich eine 8-MB-Grenze. Die Grenzwerte sind eigene Hostbudgets, keine Behauptung über eine universelle Browserquote oder Roblox-Aufrufrate. Ein Speichercodec erhält auch nicht gepaarte UTF-16-Surrogates, ohne ungültige DataStore-Strings zu erzeugen.

`storage` wird als Task an andere verbundene Dokument-Realms desselben Bereichs zugestellt. Das schreibende Dokument bekommt sein eigenes Ereignis nicht. Ein unverändertes `setItem`, das Entfernen eines nicht vorhandenen Schlüssels und das Leeren eines bereits leeren Bereichs sind No-ops. `sessionStorage` wird nicht über unabhängige Browserhosts geteilt. Eine hostübergreifende Live-Synchronisation mit weiteren gleichzeitig geöffneten Roblox-Clients ist kein Bestandteil dieses Profils.

## Roblox Studio einrichten

Nach dem Ergänzen des Serverscripts muss der laufende Rojo-Server den aktuellen Projektbaum laden. Bei einer bereits laufenden alten Rojo-Sitzung reicht die Aktualisierung der Module nicht aus: Rojo mit `htmlpage.project.json` oder `default.project.json` neu starten, in Studio erneut verbinden/synchronisieren und dann Stop → Play ausführen. Im Explorer muss `ServerScriptService.HTMLStorageServer` vorhanden sein. Das Script erstellt beim Spielstart `ReplicatedStorage.HTMLStorage` mit `Load` und `Changes`.

Für echte Persistenz muss die Experience veröffentlicht sein und unter **Experience Settings → Security → Enable Studio Access to API Services** der Studio-Zugriff aktiviert sein. Die Einstellung wird vom Projekt nicht automatisch verändert. Der Roblox-DataStore läuft serverseitig; ein LocalScript erhält keinen direkten DataStorezugriff. Die [offizielle Roblox-Anleitung](https://create.roblox.com/docs/cloud-services/data-stores) beschreibt diese Einrichtung und die Trennung zwischen Client und Server.

Ohne erreichbaren Server oder zulässigen DataStorezugriff meldet der Speicherhost den Fehler. Er bestätigt nicht einen nur für diesen Dokumentmount vorhandenen leeren Ersatz als dauerhaft gespeichert. Session-Speicher benötigt keine dauerhafte DataStoreverbindung.

## Vergleich und Prüfgrenze

Die erste Karte der [Vergleichsseite](http://localhost:8000/javascript-tests/index.html#storage) kombiniert eine gespeicherte Projektnotiz mit einer Sitzungszahl. `Notiz speichern` schreibt nur `html-labor:project-note` in `localStorage`. `Notiz löschen` entfernt ausschließlich diesen Schlüssel. `Labor neu laden` ruft die standardisierte `location.reload()` auf; beim erneuten Scriptstart erscheint dieselbe Notiz und die Zahl unter `sessionStorage` steigt. Die Zahl verwendet ausschließlich `html-labor:session-visits` und wird bei einer neuen Sitzung zurückgesetzt. Speicherfehler werden unabhängig für beide Bereiche angezeigt und verhindern nicht den Start der übrigen Vergleichskarten.

Im Browser verwendet die Seite unveränderte native APIs. Eine neue Roblox-Play-Sitzung prüft die dauerhafte Wiederherstellung; ein neuer unabhängiger Browsertab prüft eine neue Browsersitzung. Ein vom bisherigen Tab mit Opener geöffneter Tab kann zunächst dessen Session-Speicher kopieren. Ein Zurück-Navigieren aus dem Browser-Back/Forward-Cache startet das Script nicht erneut und erhöht deshalb auch die Zahl nicht; ein Reload tut es. Zum Gegenprüfen können gespeicherte Daten im Browser auch über die Storage-Ansicht der Entwicklerwerkzeuge gelesen werden.

Automatische Prüfungen verwenden injizierte Transporte und DataStores für Quoten, Zuordnung, Reload-/Realm-Lebensdauer, Reihenfolge, Fehler und Wiederholungen. Solche Prüfungen bestätigen die Hostlogik, nicht die Verfügbarkeit des tatsächlichen Roblox-DataStores oder eine visuelle Studio-Prüfung. Die endgültige echte Speicherung wird im veröffentlichten Studio-Testplatz mit aktivierten API Services geprüft. Es werden keine FPS-Messungen durchgeführt.

IndexedDB, Cache API, Web Locks, Cookie-Persistenz, Browserprofilimport und Offline-Netzwerkcaches sind hiervon getrennte offene Erweiterungen. Normative Web-Storage-Regeln stehen im [HTML Standard](https://html.spec.whatwg.org/multipage/webstorage.html); Roblox empfiehlt für konkurrierende Profiländerungen [UpdateAsync und Fehlerbehandlung](https://create.roblox.com/docs/cloud-services/data-stores/best-practices).
