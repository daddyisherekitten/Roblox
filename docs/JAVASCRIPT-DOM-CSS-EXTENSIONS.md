# DOM, Eingaben und CSS: Vergleich 08

Stand: 4. Oktober 2026. Dieses Dokument beschreibt den Erweiterungsstand der historischen Vergleichsseite 08, jetzt in `tests/fixtures/javascript-components-review-page.json` eingefroren. Die aktive [Vergleichsseite 09](http://localhost:8000/javascript-tests/index.html?r04=20261004-ready) zeigt die neuen R00–R04-Funktionen; deren Nachweise und Grenzen stehen in der [Roadmap](JAVASCRIPT-ROADMAP.md).

## Implementierte Bereiche

| Bereich | Verhalten | Zuständige Module |
| --- | --- | --- |
| Tabellen | Lebende Tabellen-/Abschnitt-/Zeilen-/Zellensammlungen, Einfügen und Entfernen, Caption/Head/Foot, Span-Änderungen, Tabellenlayout und erhaltene Formularzustände | JavaScript/DOMTables, Rendering/DOMReconcile, Layout/TableLayout |
| Komponenten | Custom-Element-Konstruktion und Upgrade, Lifecycle-/Attributreaktionen, offene/geschlossene Shadow Roots, benannte/manuelle Slots, Event-Retargeting, deklarative Wurzeln und erhaltene native Eingaben | JavaScript/CustomElements, DOM/ShadowTree, JavaScript/ShadowDOM, Rendering/RenderTree |
| Shadow-CSS | Eigene Stylesheets und adoptierte Blätter, `:host`, `:host-context`, `::slotted`, `::part` und `exportparts`, normale/wichtige Prioritäten zwischen verschachtelten Bereichen, scoped Keyframes | CSS/ShadowSelectors, CSS/Stylesheet, JavaScript/CSSOM |
| Eingaben | Pending/active Pointer-Capture mit got/lost-Ereignissen, Touchkontakte und TouchLists, implizites Touch-Capture, Fokus-/Abbaukorrekturen, Unicode-Textänderungen und abbrechbares `beforeinput` | Input/PointerCapture, Input/NativeTextEdit, JavaScript/PointerCapture, JavaScript/HostEvents |
| CSSOM | Zusätzliche native Regelprototypen für Keyframes, Font-Face, Page/Margin, Import/Namespace, Layer, Container, Scope, Starting-Style, Property, Counter-Style und Font-Palette; lebende Listen und Regeln/Deklarationen | JavaScript/CSSOMRules, JavaScript/CSSOMDescriptors, JavaScript/CSSDeclarations |
| CSS-Kaskade | Layer-Reihenfolge einschließlich `!important`, Scope-Grenzen/Nähe, registrierte Custom-Property-Typen mit Initialwert/Vererbung und Invalidierung | CSS/CascadeLayers, CSS/ScopeRules, CSS/RegisteredProperties, CSS/Variables |
| Erzeugte Inhalte | Dynamische `::before`, `::after`, `::marker`, Texte/Attribute/Quotes/Counter, geschachtelte Counterbereiche und eigene Counter-Formate; normale Boxen für blockförmige Pseudoelemente | Rendering/GeneratedContent, CSS/Counters, CSS/CounterStyles, Layout/ListMarker |
| Animationen | Numerische Layoutgrößen, Insets/Margins/Padding, Flexwerte, Gaps und Spacing; CSS-Transition/Keyframes und Web Animations teilen den Effektstapel; replace/add/accumulate, einzelne Keyframe-Composites, aktuelles `getComputedStyle`/Geometrie und `commitStyles` | Rendering/AnimationValues, Rendering/HTMLAnimations, JavaScript/WebAnimations |
| Eintrittsübergänge | `@starting-style` bei anfänglichem Rendern, Insertion und Wiedererscheinen aus `display:none`; Kaskade, tatsächlicher Vorzustand und laufende Layout-/Transformkombinationen | CSS/Stylesheet, Rendering/RenderTree, Rendering/HTMLAnimations |

Styleänderungen verwenden die vorhandenen lokalen Layoutwege. Paint-Effekte lösen keine Layoutarbeit aus. Layoutanimationen veröffentlichen zusammenhängende Änderungen gesammelt; unveränderte Bereiche behalten ihre Boxen und Caches. Abbruch und Abbau entfernen die Effekte und ihre Frameabonnements.

## Prüfungen

Native Browserreferenzen und die Luau-Integration prüfen insbesondere API-Fehler, Receiver/Deskriptoren, Slots und Eventgrenzen, CSSOM-Mutation, Layout-/Paintwerte, erhaltene Eingaben/Auswahl, Effektstapel, aktuelle Geometrie und Ressourcenfreigabe. Die ausgelieferte Vergleichsseite wird zusätzlich mit ihren echten Buttons, Komponenten, Formularen und Animationen durch den gemeinsamen Renderer ausgeführt. FPS-Benchmarks sind ausdrücklich nicht Teil dieser Prüfung.

Die Referenzdateien liegen unter `tests/fixtures`: `javascript-components-browser.json`, `javascript-pointer-touch-native-results.json`, `cssom-rules-expected.json`, `animation-layout-native.json`, `animation-context-native.json`, `css-starting-style-browser.json` und `pseudo-content-native.json`. Die ausführbaren Gruppen sind im zentralen `scripts/run-html-tests.cjs` registriert.

Der abschließende Regressionstest einschließlich der Studio-Rückmeldungen umfasst 60 bestandene Gruppen: neue APIs und gemountete Updates, vorhandene Tabellen-/Listen-/Selektor-/Rahmenregressionen, Hover/Resize, die früheren Vergleichsseiten sowie Observer und Ressourcenfreigabe. Die neue Vergleichsseite wird mit ihren sechs Karten ausgeführt. `HTMLPageAnimationScheduling` prüft zusätzlich die tatsächliche Seitenveröffentlichung mit voranschreitender Uhr und endlosen Größen-Keyframes; die neue Rahmenprüfung kontrolliert echte UIStroke-Flächen nach der Stylesheet-Adoption. Zusätzlich stimmen 53 CSSOM-Referenzassertions und 19 erfasste CSS-Kombinationszustände mit dem nativen Browser überein. Die getrennt dokumentierten Standard-/Browserabweichungen bleiben ausdrücklich ausgewiesen.

## Konkrete Grenzen

Roblox liefert keine öffentlichen nativen IME-Composition-/Preedit-Signale. `CompositionEvent` und synthetischer Dispatch sind vorhanden; veröffentlichte Unicode-Textänderungen erzeugen `beforeinput`/`input`. Zwischenstände, Composition-Ranges und `isComposing` werden nicht erfunden. Die Eingabekarte kennzeichnet diesen Unterschied.

Custom Elements verwenden einen dokumentweiten Registry. Scoped Registries, `ElementInternals`/formularassoziierte Komponenten, vollständige dokumentübergreifende Adoption und Shadow-Selection/Editing sind weiter offen. Die Rendererunterstützung für einzelne CSS-Effekte, Schriftmetriken und fragmentierte Inline-Boxen bestimmt weiterhin die visuellen Grenzen.

Die zusätzlichen CSSOM-Regeltypen bedeuten keine neue Fontdatei-Ladepipeline, Druck-/Seitenlayoutmaschine oder Font-Palette-Rasterisierung. Deren Regeln besitzen das dokumentierte CSSOM-Profil; nicht jede Descriptorgrammatik oder neue CSS-Regelfamilie ist vollständig implementiert. `@property` deckt die dokumentierten skalaren und Listen-/Union-Typen ab, nicht die gesamte CSS-Wertgrammatik.

Animationen von `auto`/intrinsischen Größen, sämtlichen Layout-/Paintproperties oder Pseudoelement-/Inlinefragment-Zielen sind nicht vollständig umgesetzt. `iterationComposite` ist eine explizit geprüfte Level-2-Erweiterung: Der erfasste Chromium-Browser ignoriert diese Option, daher besitzen diese Fälle getrennte Browser-/Engine-Erwartungen. Weitere Browserabweichungen werden in den jeweiligen Profildokumenten ausgewiesen.

## Standards und Detailprofile

Die Algorithmen folgen [DOM](https://dom.spec.whatwg.org/), [HTML](https://html.spec.whatwg.org/multipage/), [CSS-Kaskade](https://www.w3.org/TR/css-cascade-6/), [CSS-Listen](https://www.w3.org/TR/css-lists-3/), [CSS-Transitions](https://www.w3.org/TR/css-transitions-2/) und [Web Animations](https://www.w3.org/TR/web-animations-1/). Native Referenzen belegen die erfassten Fälle; sie sind kein Nachweis vollständiger Browserkonformität.

Details: [Tabellen](JAVASCRIPT-TABLES.md), [Komponenten](JAVASCRIPT-COMPONENTS.md), [Pointer/Touch/Text](JAVASCRIPT-POINTER-TOUCH-INPUT.md), [CSSOM](JAVASCRIPT-CSSOM.md) und [Layoutanimationen](JAVASCRIPT-ANIMATION-LAYOUT.md).
