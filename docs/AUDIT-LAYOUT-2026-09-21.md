# Layout- und CSS-Audit, 21. September 2026

Teilprüfung des Projekt-Audits: `src/HTMLEngine/Layout`, `src/HTMLEngine/CSS` und zugehörige Regressionen. Der Audit verspricht keine vollständige Browserkompatibilität. Browser/Roblox-Sichtvergleiche und Messungen auf echten Geräten bleiben erforderlich.

## Behoben

| Fundstelle | Befund und Änderung | Evidenz |
| --- | --- | --- |
| `CSS/Selectors.luau`: `matches`, `previous`, strukturelle Pseudoklassen | `A ~ B` suchte wiederholt den vorherigen Nachbarn und baute jedes Mal eine komplette Elementliste auf. Ein erfolgloser Match am Ende von n Geschwistern verursachte quadratische Arbeit. Jetzt ein direkter Rückwärtsscan; `+` und strukturelle Pseudoklassen bauen keine gefilterten Familienarrays. Keine langlebigen DOM-Caches. Detached-Elemente zählen sich selbst als Geschwistermenge, funktionale Pseudoklassennamen sind case-insensitive. | `tests/Selectors.luau`: Text/Kommentar-Geschwister, Reparenting/Reordering, Detached-Knoten, nth/of-type und 2.048 Geschwister. Gemessene semantische Kind-Zugriffe im erfolglosen General-Sibling-Fall bleiben unter 3n. Eigenständiger Luau-Lauf bestanden. |
| `CSS/Stylesheet.luau`: Keyframe-Parser; `CSS/Motion.luau`: `progress` | `1%` wurde als normierter Endpunkt 1 statt .01 gespeichert. Prozentwerte und `from`/`to` werden jetzt getrennt ausgewertet. Fraktionale Iterationszahlen landen nun beim tatsächlichen Fortschritt ihrer letzten Iteration, inklusive alternate/reverse-Richtung. | `tests/Motion.luau`: `from`, `1%`, `100%` müssen die Offsets 0, .01, 1 liefern; Endpunkte für 0, 1.25, 2 und 2.5 Iterationen mit verschiedenen Richtungen. |
| `Layout/PositionedLayout.luau`: Paint-Ranking, `Layout/BlockLayout.luau`: Vorbereitung | Die jüngste Foreground-Sortierung hob auch verschachtelte Flex/Grid-Items über spätere normale Items und konnte damit `order` überstimmen. Der Sonderrang gilt jetzt nur im normalen Blockkontext. `inline-flex` ist beim Item-Z-Index berücksichtigt. Atomare Inline-Container in anonymen Word-Runs propagieren Positionierungs-/Ankerflags und nehmen mit ihren richtigen Elternkoordinaten am Positionierungspass teil. Die bestehende Outset-Regression bleibt erhalten. Die Vorbereitung klont Margins nur bei tatsächlichem Eltern-/Kind-Kollaps und propagiert Anchor-Präsenz; der Anchor-Sammler überspringt Zweige ohne Anker. Doppelter `LengthExpression`-Import entfernt. | `tests/Positioning.luau`: Flex, Inline-Flex, Grid und Inline-Grid mit verschachteltem Flex-Item, `order` und statischem `z-index`. Zusätzlich absolute Badges in Inline-Flex/-Grid/-Block und Anker aus Word-Runs. Bestehende Tests für Outset, Anchors und Margin-Collapse bestehen weiterhin. |

## Offen / bewusst begrenzt

| Fundstelle | Befund | Konsequenz / nächste belastbare Maßnahme |
| --- | --- | --- |
| `CSS/Stylesheet.luau`: `match`, `matchPseudo`; `CSS/AuthorRules.luau`: `match` | Pro Element werden alle Regeln geprüft; bei großem Katalog grundsätzlich O(Elemente × Regeln). | Ein rechter Selektorindex nach ID/Klasse/Tag kann nach Profiling helfen. Er muss `:is`, `:not`, universelle Selektoren und dynamische Zustände korrekt abdecken. Nicht ohne Regressionen als schneller Cache ergänzt. |
| `Layout/BlockLayout.luau`: `bindInline`, `resolveSpacing`, `prepareMargins` | Auch partielle Layouts durchlaufen vorbereitende Baumoperationen. Die neuen Allokations-/Anchor-Guards beseitigen nicht die vollständige Vorbereitung. | Einen Style-/Struktur-Generationsschlüssel einführen, bevor diese Vorbereitung übersprungen wird. Andernfalls drohen veraltete Prozentabstände, Anker und Kollapsflags. |
| `Layout/PositionedLayout.luau`: `paint` | Roblox-Z-Index ordnet ganze GUI-Unterbäume. Das ist weiterhin keine vollständige CSS-Paint-Phasen-/Stacking-Context-Implementierung. Die Flex/Grid-Korrektur beseitigt einen konkreten Fehler, keine allgemeine Konformitätslücke. | Überlappende negative Margins, Floats, Inline-Inhalte und explizite Stacking Contexts gezielt im Stresstest kombinieren. Vollständige Lösung benötigt getrennte Paint-Layer statt weiterer pauschaler Ränge. |
| `Layout/BlockLayout.luau`: Float-Pfad und Eltern-Margin-Collapse | Float-Shapes werden pro Blockposition statt pro Textzeile abgetastet. Margin-Collapse mit Floats/Clearance ist unvollständig; FlowChildren enthält auch Floats. | Eigene Float-/Zeilenformatierung und gezielte CSS-Referenzfälle erforderlich. Kein lokaler Quickfix, der die vorhandenen Flow-/Canvasmaße unbemerkt ändert. |
| `CSS/Motion.luau`: `ease` | Easing verwendet dokumentierte Näherungen statt CSS-Bézierkurven. | Gezielte Timing-Konformitätsetappe. Im Stresstest nicht als vollständig browsergleich deklarieren. |
| `CSS/InlineStyle.luau` | Über 1.400 nichtleere Zeilen mit Parsing, Cascade und Used-Style-Anpassungen. | Parserfamilien und Berechnungsschritte modularisieren, wenn passende Featuretests die jeweiligen Schnittstellen schützen. Reines Kürzen würde diese Verantwortung nur verstecken. |
| `Layout/GridPlacement.luau` / `CSS/GridValues.luau` | Ein explizites Trackbudget begrenzt dichte Grid-Belegung. Tausende Katalogkarten in einem einzigen Grid können deshalb am Budget scheitern. | Last auf mehrere semantische Abschnitte verteilen und Grenzfälle separat kennzeichnen; Enginebudget nicht stillschweigend entfernen. |
| `Layout/TextMeasure.luau` | Eine `GetTextBoundsParams`-Instanz je echter Messung; das Objekt wird auch bei Fehlern zerstört. Kein belegter Leak in diesem Pfad. | Messungen weiterhin elementlokal wiederverwenden. Ein globaler Wortcache würde die Projektregel in PLAN.md verletzen. |

## Normative Referenzen

- [CSS Flexbox: Item Z-Ordering](https://www.w3.org/TR/css-flexbox-1/#painting): Items verwenden die durch `order` veränderte Reihenfolge; ihr eigenes inneres Display erzeugt keinen bevorzugten Item-Paintrang.
- [Selectors Level 4: Child-indexed Pseudo-classes](https://www.w3.org/TR/selectors-4/#child-index): inklusive Geschwistermenge, ohne Textknoten.
- [CSS 2.2: Collapsing margins](https://www.w3.org/TR/CSS22/box.html#collapsing-margins): Floats, Clearance und Formatierungskontexte müssen bei weiteren Kollapsänderungen getrennt behandelt werden.

## Validierungsstand

- Eigenständige neue Selektorregression: bestanden.
- `node scripts/run-html-tests.cjs`: vollständig bestanden nach allen hier beschriebenen Änderungen; Log `build/audit-layout-html-tests.log`.
- SVG-Gesamtsuite in der abschließenden Integration vollständig bestanden; Log `build/audit-final-svg.log`.
- Kein nativer Roblox-Performancewert oder visueller Browser-/Studio-Abgleich aus dieser Teilprüfung behauptet.
