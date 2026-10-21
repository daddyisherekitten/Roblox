# Dynamische Skripte

Stand: 4. Oktober 2026. Zuständig sind `JavaScript/ScriptLoader`, `DOMTree`,
`DOM`, `DOM/Node` und `Runtime`. Grundlage ist der
[HTML-Scriptablauf](https://html.spec.whatwg.org/multipage/scripting.html).

Verbinden eines Script-Elements führt dessen Vorbereitung nach dem abgeschlossenen
DOM-Einfügen aus. Inline-Code läuft synchron, externe Quellen über den gemeinsamen
Loader. Neue externe Skripte sind zunächst async; `script.async = false` erhält
ihre Einfügereihenfolge. Änderungen an `src` oder dem direkten Text eines bislang
leeren, verbundenen Scripts können die Vorbereitung starten.

Ein erfolgreich vorbereitetes Element startet nur einmal. Entfernen, Verschieben,
Resize und Klonen eines bereits gestarteten Elements starten keinen weiteren Lauf.
Ein noch ungestarteter Klon ist unabhängig. `currentScript` wird bei verschachtelten
Inline-Skripten wiederhergestellt; Microtasks warten auf das Ende der äußeren
JavaScript-Ausführung. Frühere Scripts können später eingefügte Scripts entfernen,
bevor deren Verbindungsschritt erreicht wird.

`innerHTML`, `outerHTML` und `insertAdjacentHTML` erzeugen inerte Scripts.
Ein über `Range.createContextualFragment` erzeugtes Script startet dagegen beim
Verbinden. Scripttext besteht aus direkten Textkindern; Text in anderen
Kind-Elementen wird nicht als Scriptquelltext verwendet. Die Attribute/Eigenschaften
`src`, `text`, `type`, `async`, `defer` und `noModule` sind zugänglich.

Head- und Body-Insertionen durchlaufen außerdem den gemeinsamen Renderer.
Scriptknoten und ihre Textänderungen werden ohne eigene GUI-/Layoutobjekte
abgeglichen; mögliche CSS-Selektorwirkungen bleiben erhalten.

Prüfung: 22 identische HTML-Abläufe in Chromium und Luau unter
`tests/fixtures/javascript-script-loader.json`, zusätzlich die ausgelieferten
Dateien auf Vergleichsseite 07. `JavaScriptCSSOMRendering` prüft zusätzlich den
tatsächlichen Renderer-Preflight für Inline-/externe Skripte, Head-/Body-Wechsel,
verbundene Textänderungen und Entfernen, einschließlich unveränderter GUI-/
Controlidentitäten und ausbleibender Layoutaufrufe. Frühere Modul-, Range-, DOM- und Seitentests bleiben
Regressionen.

Grenzen: Das Dokument ist vor dem anfänglichen Scriptstart vollständig geparst.
Streamingparser, Parser-Blocking während des Einlesens und `document.write` fehlen.
Module behalten ihre dokumentierten Grenzen, insbesondere zyklisches Top-Level-Await.
CSP, SRI und vollständige Fetch-/CORS-Regeln sind nicht durch eine lokale
Quelltextzuordnung abgedeckt. Normale HTML-Scriptquellen bleiben auf 64 KiB und
256 Jobs pro Loader begrenzt.
