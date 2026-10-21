# JavaScript: User Timing und PerformanceObserver

Stand: 3. Oktober 2026. Implementierter Teilumfang aus P09, Vergleich 06.

## Erreichbare APIs

| Bereich | Implementiert |
| --- | --- |
| Performance | now(), timeOrigin, toJSON(), EventTarget-Verhalten |
| User Timing | mark(), measure() mit klassischen und Options-Überladungen; clearMarks(), clearMeasures() |
| Einträge | getEntries(), getEntriesByName(), getEntriesByType(); PerformanceEntry/Mark/Measure mit Name, Typ, Start, Dauer und detail |
| Observer | PerformanceObserver, supportedEntryTypes, observe({entryTypes})/observe({type, buffered}), takeRecords(), disconnect() |
| Lieferung | PerformanceObserverEntryList, zeitlich sortierte Abfragen, Callback-Empfänger/Argumente, gebündelte Aufgaben und Callback-Reentranz |

JavaScript/Performance verwendet die monotone Uhr der vorhandenen EventLoop. performance.now und Ereignis-/Framezeiten teilen denselben Ursprung. timeOrigin ist ein einmalig festgelegter Epoch-Wert; JavaScriptServices.PerformanceTimeOrigin kann einen genaueren Hostwert liefern. Ohne Adapter begrenzt os.time dessen absolute Genauigkeit. Die relative Uhr bleibt monoton.

detail wird beim Anlegen eines Eintrags strukturiert geklont. Geteilte Details, Zyklen und Binärdaten verwenden den bestehenden Clone-Unterbau; nicht klonbare Werte werfen DataCloneError. Neue Einträge werden synchron gespeichert, Observer-Lieferungen laufen später als Aufgabe. Eine ruhende Registrierung startet keinen Timer, Framecallback oder Pollinglauf. takeRecords und clearMarks/clearMeasures wirken auf unterschiedliche Puffer.

## Browserprofil und Grenzen

Die unterstützten Eintragstypen sind ausschließlich mark und measure. Navigation, Resource Timing, Paint/Event/Long-Task-Timing und FPS liefern keine erfundenen Daten. navigationId ist im vorhandenen Realm 0. navigationStart lässt sich als Ursprung 0 verwenden; fehlende übrige Legacy-Navigationszeitwerte werfen InvalidAccessError. PerformanceMark lässt sich konstruieren; Performance, PerformanceEntry/Measure und ObserverEntryList sind nicht öffentlich konstruierbar.

Native Referenzen bestimmen Umwandlungen, Überladungen, Sortierung und Observer-Modus. DOMHighResTimeStamp bleibt endlich; NaN/Infinity werfen TypeError. Das geprüfte Browserprofil akzeptiert negative duration und ignoriert nach Umwandlung buffered/durationThreshold im entryTypes-Modus; der aktuelle Performance-Timeline-Entwurf beschreibt bei diesen Kombinationen strengere Konfliktprüfungen. durationThreshold schaltet keine nicht implementierten Event-Timing-Einträge frei. Die vererbte PerformanceEntry.toJSON serialisiert die gemeinsamen Interfacefelder; detail wird separat gelesen.

Sicherheitsgrenzen: höchstens 2048 intern gehaltene Einträge/8 MiB, 64 KiB Clonebudget je detail, 256 registrierte Observer und 4096 wartende Einträge je Observer. Timeline und Observerpuffer teilen die Retention-Quote. Überschreitungen werfen QuotaExceededError vor Veröffentlichung eines unvollständigen Eintrags. Leeren/Abholen/Disconnect geben die entsprechenden internen Referenzen frei. Extern gehaltene Einträge bleiben normale JavaScript-Referenzen.

## Nachweise

23 Luau-Referenzen enthalten 22 identische native Browserfälle und eine zusätzliche Prüfung fehlender Navigation-Zeitwerte. Weitere Assertions erfassen gemeinsame Quoten, fehlgeschlagene Klone, Aufgabenbudget/Recovery, Callback-Batching und Abbau. Die unter tests/fixtures/javascript-top-layer-review-page.json eingefrorene Vergleichsseite 06 prüft feste Start-/Endwerte, geklontes detail, Observer, buffered und takeRecords innerhalb von 25 echten Browser-Bedienzuständen. Es ist kein FPS-Benchmark.

Wiederfinden: JavaScript/Performance.luau, tests/JavaScriptPerformance.luau, tests/fixtures/javascript-performance.json und javascript-performance-browser.json. Die zentrale Regression läuft über scripts/run-html-tests.cjs JavaScriptPerformance.

Normative Grundlagen: [User Timing](https://www.w3.org/TR/user-timing/), [Performance Timeline](https://www.w3.org/TR/performance-timeline/), [High Resolution Time](https://www.w3.org/TR/hr-time/).
