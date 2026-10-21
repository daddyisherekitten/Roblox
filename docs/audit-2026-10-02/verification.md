# Verifikation · 2. Oktober 2026

## Ausgangszustand

| Prüfung vor Produktionsänderungen | Ergebnis |
| --- | --- |
| `node scripts/run-html-tests.cjs` | Fehler in der GC-abhängigen RenderingLifetimes-Assertion. Kein nachgewiesener Engine-Leak. Log: `build/audit-2026-10-02/baseline-html.log`. |
| `node scripts/run-svg-tests.cjs` | Bundlerfehler: gelöschte Stress-Webseiten als Fixture referenziert. |
| `node scripts/check-project.cjs` | Bestanden: 558 Luau, 13 JS, 34 Python, 93 HTML, 346 lokale Referenzen, sieben Projekte. |
| `python scripts/test-sync-website.py` | Vier Tests bestanden. |

Nach Wiederherstellung der bytegleichen SVG-Testgrafik unter `tests/fixtures` und Umleitung auf die bereits vorhandene CSS-Fixture lief die komplette SVG-Ausgangssuite durch. Die alten sichtbaren Webseiten wurden nicht wiederhergestellt.

`RenderingLifetimes.luau` blieb unverändert: drei isolierte Läufe und beide vollständigen HTML-Nachläufe bestehen. Der Test hängt davon ab, wann Luau seine Weak-Table-Keys einsammelt; der anfängliche Fehler bleibt als intermittierender Ausgangsbefund dokumentiert. Keine Assertion wurde entfernt oder gelockert.

## Abschließende funktionale Prüfungen

| Befehl / Bereich | Ergebnis und Log |
| --- | --- |
| `node scripts/run-html-tests.cjs` | **148 Suiten bestanden**, einschließlich neuer EngineEntry, CSSLayoutAudit, RenderingAudit, ScrollLifecycleAudit; `final-html.log`. |
| `node scripts/run-svg-tests.cjs` | **Gesamtsuite bestanden**, einschließlich Reentry, Raster-Abbruch, Queue, Interaktion, Animation und 20 Reset-/Cleanup-Zyklen; `final-svg.log`. |
| `node scripts/check-project.cjs` | **Bestanden:** 562 Luau, 13 JS, 34 Python, 93 HTML, 346 Referenzen, sieben Projekte und 126 übereinstimmende Font-Einträge; `final-static.log`. |
| `python scripts/test-sync-website.py` | **Vier Tests bestanden**; `final-generator.log`. |
| 30 `sync-svg-*.py --check` / fünf `test-svg-*-browser.cjs` | **35/35 bestanden**; `svg/infrastructure-checks.json`. Browser-Skripte sind DOM-Mocks, keine echte Browservisualisierung. |
| `rojo build` für alle sieben `.project.json` | **Alle bestanden**; `final-rojo.log`. Ausgaben nur unter `build/audit-2026-10-02`. |
| Gegenseitiger Code-Review | CSS/Layout-Agent prüfte Root-Korrekturen; SVG-Agent prüfte Canvas/Medien-Paket. Keine zusätzlichen Blocker; dokumentierte Pfadlimit-/Textauswahlgrenzen bleiben. |
| Schutzprüfung gegen Ausgangssnapshot | FontProfiles, generierte Websites, StudioDemoConfig und ResizableTestWindow sind unverändert. Kein neues Frame-Logging. |

Alle genannten Logs liegen unter `build/audit-2026-10-02/`. Neue fachliche Fehlerfälle wurden reproduziert und um Regressionen ergänzt. Der erste neue Animations-Delay-Test hatte eine falsche Test-GUI-Zuordnung (InlineItem/Wrapper); korrigiert wurden das Fixture und die Auswahl der tatsächlichen Paint-Fläche, nicht die erwartete Farbe oder Zeit.

## Pixelvergleich und frühere CPU-Messungen

Vor Tobias' Übernahme der FPS-Prüfung wurde außerdem ausgeführt:

```powershell
node scripts/benchmark-svg.cjs --compare-baseline --baseline-file=build/audit-2026-10-02/benchmark-before/build/svg-benchmark-before.luau
```

**Acht Zustände mit je 1.027.584 RGBA-Bytes sind exakt gleich.** Log: `svg-pixels-current-baseline.log`. Die Baseline enthält die tatsächlichen Quellmodule aus dem ursprünglichen Audit-Snapshot und dieselbe Fixture; die historische `build/svg-benchmark-before.luau` wurde nicht überschrieben. Der alte Standardvergleich erwartete sechs Zustände, während die aktuelle Fixture sieben Hoverziele plus Normalzustand enthält. Inkompatible State-Sequenzen erzeugen weiterhin einen Fehler; die neue Option wählt ausdrücklich eine vergleichbare Baseline.

Weitere bereits vorhandene CPU-/Aufrufnachweise stehen im Hauptbericht und den Teilberichten. Keine davon liefert Studio-FPS, GPU-Speicher oder native Framezeiten. **Weitere FPS-/Performance-Testläufe wurden auf Nutzerwunsch beendet. Tobias übernimmt FPS und visuellen Roblox-/Browservergleich.**

## Aussagegrenzen

Der HTML-Bundler ersetzt einige native Dienste/GUI-Module durch Mocks; spezielle Loader injizieren wieder den echten RenderTree/BlockLayout-/Input-Code. Die neuen Tests prüfen echte Produktionsfunktionen mit kontrollierten Ressourcen, keine unabhängige vollständige Roblox-Implementierung. Enum-/UDim-/Font-/Tween-Mocks haben andere Identitäts- und Timing-Eigenschaften als native Werte. Deshalb sind konkrete Aufruf-, Abbruch-, Geometrie- und Pixelzusagen angegeben, keine allgemeine Browsergleichheit.

Die statische Prüfung kompiliert Luau und prüft Python/JS-Syntax sowie lokale Referenzen; sie ist keine vollständige Luau-Typanalyse. Rojo-Builds belegen Projektzusammenstellung, nicht einen nativen Studio-Start. Allgemeine Script-DOM-Unterstützung wurde durch diesen Audit nicht neu eingeführt.
