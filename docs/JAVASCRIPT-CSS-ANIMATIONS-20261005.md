# CSSOM, Verschachtelung und Animationen: Ausbau vom 5. Oktober 2026

Dieser Durchlauf erweitert die wichtigen Websitefälle von R05/R06. Er schließt beide Standardfamilien nicht vollständig ab. Vorhandene CSSOM-Regelfamilien, dynamische Pseudoelemente/Counter und CSS-/Web-Animations-Unterbauten bleiben erhalten; die folgende Tabelle nennt die tatsächlich neu ergänzten Fälle. Die neue Vergleichsseite `examples/websites/browser-foundations/index.html` verbindet verschachtelte Styles, CSSOM-Inhalte, Bild-/Fontzustände und Hovereffekte. Die ausgelieferte Fernweh-Quelle blieb unverändert.

## Implementierter Umfang

| Bereich | Ergänzung und tatsächliche Wirkung |
| --- | --- |
| CSS-Verschachtelung | Explizites `&`, implizite Nachfahren und führende Kombinatoren, Typ-/Klassenzusammensetzung (`div&`, `.selected&`), mehrere Ebenen und Selektorlisten. Sass-Konkatenation `&suffix` wird verworfen. Ampersands in Attributen und Strings bleiben literal. Die Elternliste liefert die richtige maximale Spezifität. |
| Regeln und Deklarationsreihenfolge | Stilregeln besitzen lebende untergeordnete Regeln. Deklarationen nach Kindregeln werden als `CSSNestedDeclarations` dargestellt und in Quellreihenfolge kaskadiert. Ignorierte ungültige Regeln trennen zusammengehörige Deklarationsläufe nicht. Braced Custom-Property-Werte bleiben Deklarationen. |
| CSSOM-Mutationen | Verschachteltes `insertRule`/`deleteRule`, `selectorText`, Deklarationen, Serialisierung und Eltern-/Blattbeziehungen. Änderungen adoptierter Blätter aktualisieren vorhandene Oberflächen; Kontrollwerte, Fokus und GUI-Identität bleiben erhalten. `style`-Zuweisungen folgen der sichtbaren PutForwards-Zieleigenschaft. |
| Bedingungen und Scope | Verschachtelte Media-, Supports-, Layer-, Container-, Scope- und StartingStyle-Kontexte verwenden denselben Parser. Explizites `&` in `@scope`-Wurzel/-Grenze wird im Elternkontext aufgelöst. Spätere Deklarationen bewahren die Pseudoelemente ihrer ursprünglichen Elternregel. |
| Selektorlisten | `:is()` und `:where()` ignorieren ungültige, nicht unterstützte und Pseudoelement-Zweige entsprechend ihrer forgiving Listen. Eine leere gültige Liste trifft nichts. `:not()` und `:has()` bleiben streng. Das verhindert auch falsche Spezifität bei gemischten Nesting-Elternlisten. |
| Dynamischer Inhalt | Montierte Regression für verschachteltes CSSOM plus Counter, `attr()`, Klassen, Mediawechsel, Inhaltentfernung und Unadoption. Farben und erzeugter Text wirken tatsächlich; unveränderte Boxen und Eingaben bleiben erhalten. Der vorhandene allgemeine Inhaltsunterbau wurde nicht durch einen Seiten-Sonderfall ersetzt. |
| Unveränderte Transitionziele | Eine unabhängige Text-/Farb-/Stylesheetänderung startet einen bereits laufenden Transform-, Opacity-, Hintergrund- oder Größenübergang nicht erneut. Jede Property behält ihren eigenen Zielwert, Startzeitpunkt und Timingzustand. Nach Layout werden die vorhandenen Posen an die neue Geometrie gebunden. |
| Unterbrechen und Umkehren | Rückkehr zum früheren Ziel verwendet den CSS-Reversing-Shortening-Factor, einschließlich Easing und gekürzter negativer Verzögerung. Positive Verzögerungen bleiben unverändert. Der letzte passende Eintrag von `transition-property` gewinnt. `transition:none` löst die Effekte und stellt die Autorenwerte wieder her. |
| Unterstützte Kurzformen | Übergänge von `background`, `margin`, `padding`, `gap`, `inset` und `flex` werden auf die vorhandenen interpolierbaren Longhands abgebildet. Das erweitert nicht pauschal sämtliche animierbaren CSS-Werte. |
| Farben und Autorenwerte | Hintergrundfarben interpolieren mit vormultipliziertem Alpha: transparentes Rot nach Blau erzeugt kein violettes Zwischenbild. Kontrollen behalten ihren unabhängig vom Effektsample gespeicherten Autorenhintergrund. Vollständig unsichtbare RGB-Werte werden für den Posevergleich vereinheitlicht; Status-/Textänderungen starten dadurch keine unsichtbaren Hintergrundübergänge. |
| Moderne Timingfunktionen | `steps()` mit optionaler Position und allen Jump-Varianten; `linear()` mit expliziten/fehlenden Prozentpositionen, Doppelpositionen, Plateaus und Sprüngen; CSS-Zahlen einschließlich Exponentenschreibweise für Timingparameter. Bézierfunktionen extrapolieren ihre Tangenten. CSS und Skripte teilen den Solver und einen begrenzten Cache unveränderlicher Parses. |
| Keyframekombinationen | Case-sensitive Animationsnamen bleiben erhalten; CSS-Schlüsselwörter werden separat normalisiert. Hintergrund-Kurzformen, transparente Stops, `currentcolor`, passende `var()`-Paintwerte und `!important`-Blockierung werden in der tatsächlich gemalten Pose berücksichtigt. Die Variablenauflösung erfolgt bei der Veröffentlichung von Stops und nicht erneut in jedem Frame. |

Die Verschachtelungsregeln folgen dem [CSS-Nesting-Arbeitsentwurf](https://drafts.csswg.org/css-nesting-1/), die forgiving Listen [Selectors Level 4](https://www.w3.org/TR/selectors-4/). Umkehr und passende Propertyreihenfolge beruhen auf [CSS Transitions Level 1](https://drafts.csswg.org/css-transitions-1/#transition-reversing-shortening-factor). Timing basiert auf [CSS Easing Level 1](https://www.w3.org/TR/css-easing-1/) und dem [Level-2-Arbeitsentwurf](https://drafts.csswg.org/css-easing-2/); der bestehende Effektstapel bleibt an [Web Animations](https://drafts.csswg.org/web-animations-1/) angebunden. Arbeitsentwürfe sind keine eingefrorenen Standards.

Ein konkreter Umkehrfall: `width:100px` nach `300px`, linear in zwei Sekunden, steht nach einer halben Sekunde bei `150px`. Bei Rückkehr zu `100px` dauert der Rückweg nun eine halbe Sekunde und steht in dessen Mitte bei `125px`. Eine zwischenzeitliche unabhängige Farbänderung verändert weder die Breite noch die Uhr dieses Übergangs. Diese Werte stammen aus einer pausierten nativen `CSSTransition`, nicht aus einem handgewählten neuen Verhalten.

## Dateien und Nachweise

| Datei | Zuständigkeit |
| --- | --- |
| `CSS/Nesting.luau`, `Stylesheet.luau`, `ScopeRules.luau`, `Selectors.luau` | Gemeinsame Grammatik, Quellreihenfolge, Selektorauflösung und Kaskade |
| `JavaScript/CSSOM.luau`, `CSSOMRules.luau` | Live-Regelbaum, `CSSNestedDeclarations`, Änderungen und Lebensdauer |
| `CSS/Motion.luau`, `Properties.luau` | Timingparser, Solver, Namenssemantik und Metadaten des unterstützten Profils |
| `Rendering/HTMLAnimations.luau` | Propertyuhren, Umkehr, Autorenposen, transparente Farben und Keyframestops |
| `Controls/View.luau`, `Rendering/RenderTree.luau` | Integration: Autorenhintergrund/Radius und Opacitygruppen für variable Keyframes |
| `tests/fixtures/javascript-cssom.json` | 20 native Semantikfixtures, davon fünf neu für Nesting, Deklarationsläufe, Literalwerte, Compoundselektoren und PutForwards |
| `tests/fixtures/css-nesting-pseudo-native.json` | Sechs native Pseudo-/Spezifitäts-/forgiving-Referenzen |
| `tests/fixtures/css-easing-native.json` | 19 native Validierungs-/Fortschrittsreferenzen moderner Timingfunktionen |
| `tests/fixtures/css-transition-reversal-native.json` | Native Umkehr-, Easing-, Negativdelay-, Reihenfolge- und Farbreferenzen |
| `tests/JavaScriptCSSOMRendering.luau` | Gemalte verschachtelte CSSOM-Änderungen, Counter/Attribute, responsive Größen und erhaltene Eingaben |
| `tests/Animations.luau`, `CSSLayoutAnimations.luau`, `Motion.luau`, `ThreeDTransforms.luau` | Tatsächliche Paint-/Layoutwerte, erhaltene Uhren, Abbruch/Umkehr und Ruhe-/Cleanupzustände |

Die neuen Referenzen wurden am 5. Oktober 2026 mit installiertem Chromium **154.0.8037.95** erfasst. CSSOM-Referenzen lesen native Regelobjekte; Timingreferenzen lesen pausierte `KeyframeEffect.getComputedTiming().progress` bzw. `CSSTransition.currentTime` und berechnete Paint-/Layoutwerte. Die Referenzdateien sind eingefrorene Ergebnisse und keine Behauptung vollständiger Chromiumgleichheit.

Diese Befehle bestanden nach der abschließenden Codeprüfung:

```text
node scripts/test-javascript-cssom.cjs
node scripts/run-html-tests.cjs Animations CSSLayoutAnimations ThreeDTransforms Motion Stylesheet Selectors CSSRuleFamilies JavaScriptCSSOMRules JavaScriptCSSOMRendering JavaScriptShadowCSSOM GeneratedContentRendering JavaScriptPseudoContent JavaScriptComponentsRendering BrowserFoundationsWebsite FernwehWebsite
```

Der separate CSSOM-Lauf prüft 20 Semantikfixtures und Quellinvalidierung, Zuordnungswechsel, tatsächlich abgeschlossene Luau-GC sowie Disposal. Der zweite Lauf enthält 15 bestandene Gruppen, darunter 53 weitere native Regelfamilien-Assertions, 13 Pseudoinhaltsreferenzen und die montierten beiden Websites. Die Hostregressionen nutzen den echten Parser, die VM und Layout-/Paintpfade mit ersetzten Roblox-GUIs/Textmaßen. Sie sind keine Studio-Screenshots, kein neuer visueller Nutzerabgleich und keine FPS-Messung. Die eingefrorenen älteren Vergleiche bleiben Regressionen.

Der größere Testheap machte eine alte feste Anzahl an GC-Druckallokationen unzuverlässig. Der reine Lifecycle-Test wartet jetzt anhand schwacher Sentinels auf die tatsächliche Freigabe, weiterhin mit begrenztem Druck und mehr Gesamtallokationen als der Retained-Capacity. Produktionsbudgets und Produktions-GC wurden dafür nicht verändert.

## Grenzen und noch offene Teile von R05/R06

- Vollständige CSS-Token-/Escape-/Namespace-/Werteserialisierung und alle Regelhierarchiefehler sind nicht abgedeckt. Nackte Deklarationen über `CSSStyleRule.insertRule("color:red")` sind nicht unterstützt. Shadow-Spezialselektoren wie `:host`, `::slotted` und `::part` innerhalb des durch Nesting erzeugten funktionalen Elternselektors benötigen weitere Integration. Die vorhandenen normalen Shadow-CSSOM-Tests bestehen; das beweist diese speziellen Kombinationen nicht.
- Alle Counter-/Pseudo-/Inlinefragment-/Shadowkombinationen bleiben ein offener Vollständigkeitsbereich. Der Durchlauf ergänzt konkrete dynamische Wirkungsnachweise. Print-/Page-/Font-Palette-Regelobjekte garantieren weiterhin keine Druck- oder Font-Palette-Rasterisierung. `@import` braucht den gemeinsamen echten Ressourcen-/Origin-/CORS-Loader.
- Text- und Rahmenfarben sowie weitere CSS-Paintfamilien werden noch nicht vollständig getweent. Eine syntaktisch gültige Transitionproperty allein garantiert keine Interpolation. `auto`/intrinsische Größen, diskrete Übergänge einschließlich tatsächlicher `allow-discrete`-Wirkung, Inlinefragmente und Pseudoelement-Ziele bleiben offen.
- Der bestehende CSS-/WAAPI-Effektstapel unterstützt seinen dokumentierten Größen-/Transform-/Opacity-/Hintergrund-/Radius-/Shadow-/Motion-Path-Teilumfang und vorhandene Add-/Accumulate-/Commit-/Cancel-Fälle. Vollständige Werttypen, alle registrierten Custom-Property-Interpolationen, sämtliche Effektkombinationen, CSS-Transition-/Animationereignisse und `CSSAnimation`-/`CSSTransition`-Reflection sind nicht abgeschlossen. Scroll-Timeline-Teilpfade bedeuten keine vollständigen View-Timelines oder View Transitions.
- Radiusanimationen verwenden das vorhandene skalare Profil, Shadowanimationen den ersten Shadow. Die Farbmischung nutzt RGB mit Alpha und deckt keine vollständigen CSS-Farbräume ab. Vollständig transparente verborgene Farbkomponenten sind im vorhandenen Farbparser nicht durchgehend erhalten.
- Das Timingprofil folgt bei zwei sich entwickelnden `linear()`-Randfällen dem erfassten installierten Browser: Eine einzelne Kontrollposition wird zurückgewiesen; bei doppeltem erstem Input wird außerhalb dieses Inputs der letzte Wert verwendet. Der Level-2-Editorentwurf unterscheidet sich in diesen konkreten Fällen. Exakte moderne CSSOM-Timingserialisierung, sämtliche mathematischen Timingausdrücke und gequotete/escaped Animationsnamen bleiben offen.

Die vorhandenen Hostbudgets bleiben sichtbar: 1 MiB CSS-Quelle, 4096 Regeln pro Parse/Liste, 32 Parser-Verschachtelungsebenen und 16384 gehaltene CSSOM-Kernobjekte. Nestingselektoren sind nach Expansion auf 4096 Zeichen begrenzt; der bestehende Selektorcompiler hat ein zusätzliches Tiefenbudget. Timingnamen dürfen 2048 Zeichen, `linear()` 128 Punkte, `steps()` 100000 Schritte und der Parsecache 128 Einträge besitzen. Zahlen-/Bézier-/Zeit-/Listenlimits bleiben im Motionprofil dokumentiert. Diese Grenzen sind Hostschutz und keine Browserstandards.

R05/R06 werden deshalb als **praktisch erweitert, weiterhin teilweise** geführt. Der Code ist über die genannten Module, eingefrorenen Referenzen und Wirkungsregressionen wieder auffindbar; ein vollständiger Familienabschluss wird erst mit den verbleibenden Fällen behauptet.
