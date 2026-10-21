# Animation.commitStyles

Stand: 3. Oktober 2026. Ergänzung zu P09 auf Grundlage von [Web Animations](https://drafts.csswg.org/web-animations-1/#dom-animation-commitstyles). Unterstützt ist der vorhandene replace-Paintumfang: transform, offset-distance, opacity und background-color.

## Verhalten und Anbindung

`commitStyles()` übernimmt die abgetasteten Werte in die normale Inline-Deklaration des Zielelements. Die Animation läuft danach unverändert weiter; zum Freigeben dient weiterhin `cancel()`. Berücksichtigt wird der Effektstapel bis einschließlich der aufgerufenen Animation. Später darüberliegende Animationen werden nicht mitgespeichert. Pausierte, laufende und abgeschlossene Effekte, fehlende Fill-Wirkung an Intervallgrenzen und neutrale Keyframes verwenden denselben Timing-/Samplingweg wie die Darstellung.

Vor dem Abtasten werden ausstehende DOM-/Style-/Layoutänderungen über den vorhandenen synchronen Geometrieweg aufgelöst. Native Zahlen, Farben, Längen und Transformlisten werden serialisiert; Prozenttranslationen bleiben relativ, aufgelöste em-/var-Werte werden eingefroren. Transform, individuelle translate/rotate/scale und Motion-Path bleiben getrennte Kanäle, damit Commit plus Cancel keine Bewegung verdoppelt. Alpha-Interpolation verwendet vormultiplizierte Farben.

CSS-`!important` wird beim Abtasten berücksichtigt. Die gespeicherte Zielproperty erhält normale Priorität; andere Properties behalten ihre Werte und Prioritäten. Der gemeinsame `CSSDeclarations`-Pfad schreibt den gesamten Commit atomar als einen Style-Attributvorgang. Unveränderte kanonische Werte schreiben nichts und erzeugen keinen zusätzlichen MutationObserver-Record.

Eine fehlende styled-element-Zuordnung wirft im geprüften Chromium-Profil `NoModificationAllowedError`. Nicht dargestellte oder getrennte HTML-Ziele werfen `InvalidStateError`. Ungültige CSS-Keyframewerte werden nicht als animierte Zielproperty gespeichert. Leere Keyframes schreiben nichts. Fehler sind gebrandete DOMExceptions; die Methode prüft ihren Receiver.

Abtasten durchsucht den begrenzten gehaltenen Effektstapel, keine historische Animationsliste. Schwache Kontextcaches prüfen Stylegeneration, Schriftgröße und Viewport; auch Prioritätsänderungen ohne Wertänderung invalidieren sie. Dynamisch erzeugte Opacity-Gruppen nehmen an späteren Layouts teil. Reine Paintänderungen behalten vorhandene Objekte und Layoutcaches; offset-distance fordert keine Text-/Flowberechnung an. Cancel und Realm-Dispose lösen angeforderte Framecallbacks.

## Profilgrenzen und Nachweise

Additive/akkumulierende Effekte, Layoutproperties, Inlinefragmentanimationen, Pseudoelemente, SVG-Animationen und vollständige CSS-Motion-Topologie sind weiterhin offene Familien. Bereits laufende CSS-Transitions mit höherer Kaskadenpriorität sind noch kein vollständiger Commit-Abgleich. Nicht darstellbare Commitkombinationen melden den vorhandenen Unsupported-/NotSupported-Pfad. Dieses Paket vervollständigt P09 nicht.

Ein nativer Referenzfall unterscheidet sich ausdrücklich: Eine untere halbtransparente CSS-Farbanimation mit einem neutralen Skriptkeyframe liefert in Chromium `rgba(128, 0, 255, 0.5)`, im aktuellen Unterlying-/vormultiplizierten Farbmodell dagegen `rgba(85, 0, 170, 0.75)`. Die Engine behält den aktuellen Algorithmus. Die genaue Browserrückgabe steht nur für diesen Fall als `browserExpected` im Fixture; die Diagnose prüfte getrennt CSS-Grundwert, sichtbaren Effekt, Commit und Cancel. Grundlage der Entscheidung: [Alpha-Interpolation](https://drafts.csswg.org/css-color-4/#interpolation-alpha) und die geänderte Behandlung [impliziter Keyframes](https://drafts.csswg.org/web-animations-1/#changes-since-last-publication).

| Datei | Aufgabe |
| --- | --- |
| `JavaScript/WebAnimations.luau` | Zeitpunkt, begrenzter Teilstapel, Methode und Fehler |
| `Rendering/HTMLAnimations.luau` | Gemeinsame Effektwerte, untere CSS-Effekte, Serialisierung, native Paintwege |
| `JavaScript/CSSDeclarations.luau`, `Runtime.luau` | Eine Inline-Mutation, gemeinsame Konvertierung und synchroner Flush |
| `Rendering/RenderTree.luau` | Kaskadengeneration, Media-Kontext und Paint-/Layoutunterscheidung |
| `tests/JavaScriptAnimationCommit.luau` | Native Referenzfälle, retained Paint, wichtige Kombinationen und Cleanup |
| `tests/JavaScriptSelectionCommitReviewPage.luau` | Vergleich 05 mit 20 Browserzuständen und einem tatsächlich laufenden Frameverlauf |

17 Referenzfälle stehen in `tests/fixtures/javascript-animation-commit.json`, die native Referenz in `javascript-animation-commit-browser.json`. Ein SVG-Namespacefall läuft wegen der noch fehlenden createElementNS-Hostoberfläche als Browserfall plus direkter Namespaceprüfung im Luau-Host; die übrigen 16 Quellen laufen unverändert im Interpreter. `node scripts/test-javascript-animation-commit.cjs` prüft das Luau-Profil; `--serve` liefert denselben JavaScriptcode an den nativen Browser. Gemeinsame Regressionen prüfen außerdem CSSOM, ScriptTransforms, WebAnimations, ScriptClock und geschlossene Realm-Lebensdauer. Native GUI-Mocks sind kein Studio-Screenshot; der Roblox-Sichtvergleich bleibt bei Tobias. Es gibt keinen FPS-Benchmark.
