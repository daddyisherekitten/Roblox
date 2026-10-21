# CSS Abdeckung und verbleibender Abgleich

Referenzbestand: 6. Oktober 2026; Nachweisergänzung: 11. Oktober 2026.
Die [frühere CSS-Abschlussliste](history/2026-10-06/CSS-COMPLETION-original.md)
ist vollständig erhalten. Ihre Eigenschaftszahlen, alten Demoangaben und
Roblox-Profilabschlüsse sind datierte Angaben; sie belegen keine vollständige
heutige CSS-Semantik oder Pixelgleichheit.

## Zuständige Quellen

| Gesucht | Quelle |
| --- | --- |
| Vollständiger datierter Referenzbestand und offene CSS-Fälle | [CSS-Abgleich vom 6. Oktober](CSS-GAPS-20261006.md), [einziges aktives CSS-Register](css-features.v1.json) |
| Registrierte Eigenschaften und Werte | [Properties.luau](../src/HTMLEngine/CSS/Properties.luau) |
| Kaskade, CSSOM und neuere Regel-/Animationsprofile | [CSS-/Animationsprofil](JAVASCRIPT-CSS-ANIMATIONS-20261005.md), [CSSOM](JAVASCRIPT-CSSOM.md) |
| Layout und Wiederverwendung | [FLEXBOX](FLEXBOX.md), [TABLES](TABLES.md), [POSITIONING](POSITIONING.md), [DIRTY-LAYOUT](DIRTY-LAYOUT.md) |
| Pseudoelemente und Counter | [Pseudoinhalte](JAVASCRIPT-PSEUDO-COMPUTED-CONTENT.md) |
| Flächen, Rahmen und Effekte | [CSS-VISUAL-LIMITS](CSS-VISUAL-LIMITS.md), [CSS-BACKGROUNDS](CSS-BACKGROUNDS.md) |
| Transformation und Bewegung | [CSS-TRANSFORMS](CSS-TRANSFORMS.md), [CSS-MOTION](CSS-MOTION.md), [Layoutanimation](JAVASCRIPT-ANIMATION-LAYOUT.md) |
| Ausbauziele für CSS/Web-APIs | [R05/R06 in der JavaScript-Roadmap](JAVASCRIPT-ROADMAP.md), [historischer CSS-Ausbauplan](CSS-EXPANSION-ROADMAP.md) |

## Was noch abzugleichen ist

Zum Anschauen der neun Bereiche gibt es seit dem 7. Oktober 2026 das
[archivierte CSS Atelier](../tests/fixtures/css-atelier/index.html): 35 echte Browserbeispiele mit
Reglern, Buttons, Erklärungen und konkreter Syntax-/APIprüfung.
[Quellen und Abgrenzung](WEBSITES.md#css-atelier-die-neun-css-bereiche-ansehen).
Vom 7. bis 8. Oktober wurden diese Quellen auch als `CSSAtelier` in Roblox
ausgeliefert; inzwischen bleiben sie als Regressionstestdaten erhalten. [Ergänzte Pfade, konkrete Restfälle und Hostgrenzen](CSS-ATELIER-20261007.md)
sind dort zusammen dokumentiert. Kein ganzer CSS-Bereich wird damit als fertig markiert.

Alte Aussagen zu nichtdynamischen Rahmen/Schatten, nicht ausgeführtem JavaScript,
begrenzten Regeltypen oder alleinigen Paintanimationen werden mit den neueren
Fachprofilen abgeglichen. Ein neuerer Profilumfang ersetzt nur die konkret
erweiterte Familie; andere Grenzen bleiben bestehen.

Der [datierte CSS-Abgleich](CSS-GAPS-20261006.md) erfasst jetzt 5.008 Standard-
Definitions-/Kontexteinträge und 37 zusätzliche Engine-Registrierungen.
Er umfasst Eigenschaften, Selektoren, At-Regeln/Deskriptoren, Funktionen,
Einheiten, Medienmerkmale, Werte/Typen sowie CSS-bezogene APIs und deren Member.
Tatsächlicher Katalog, Compilerproben, SVG-Pfade und APIpräsenz sind getrennt;
die Quellen sind festgehalten und mit Prüfsummen versehen.

Die weitere Wirkungsprüfung muss Eigenschaft und vollständige Grammatik,
Kaskade, berechneten Wert, Layout/Paint, Zustandswechsel, Resize, Kombinationen
und Lifecycle verbinden. Registrierung und einzelne akzeptierte Beispiele
sind kein Abschluss. Die Liste trennt Websitebedarf, Print/Speech/Legacy/
Entwurfsprofile und konkrete native Hostgrenzen. Noch nicht implementiert
ist keine pauschale Unmöglichkeit.

Die Fachprofile bleiben der Ort für Detailstatus und Nachweise. Hier stehen
Prüfmethode und Zuständigkeiten, keine zweite Kopie sämtlicher Eigenschaftslisten.
Das vorhandene Register enthält seit dem 10. Oktober zusätzlich
`reviewedRequirements`: feste Teilanforderungen mit einer datierten Standardquelle,
Prüfkriterien, Status und getrennten Nachweisen. Zunächst sind Canvashintergründe
und dynamisches `letter-spacing` aufgeteilt. Diese Zuordnungen sind ausdrücklich
unvollständig; die übrigen Definitionen bleiben weiterhin zu erfassen. Der
Exporter erhält geprüfte Zuordnungen anhand ihrer stabilen Definitions-ID und
stoppt, wenn eine solche Definition verschwindet oder ihre Identität wechselt.
Parser-/Katalogverfügbarkeit und Anforderungsabschluss bleiben getrennte Felder.
Am 11. Oktober sind 25 eng abgegrenzte Anforderungen mit benannten Browser-/CLI-
Nachweisen erfüllt: vier Canvasverträge, vier dynamische Textabstandsverträge,
14 Anforderungen an horizontale Flex-/Grid-Ausrichtung und drei Anforderungen
an ausgeblendete Inhalte einschließlich Fokus/Auswahl und bereits montierter
Modals/Popovers. Die neun Zuordnungen mit 52 Teilanforderungen bleiben ausdrücklich
teilweise: fünf sind offen und 22 ungeprüft. Die übrigen Standarddefinitionen
sind noch nicht vollständig in solche Anforderungen aufgeteilt. Diese Zahlen
zählen nur den bereits zugeordneten Umfang; sie sind weder ein Abschluss der
neun Eigenschaften noch ein vollständiger verbleibender Arbeitszähler.
Nachweise und Grenzen: [Ausrichtung](CSS-ATELIER-20261007.md#position-alignment-in-horizontalen-flex--und-gridcontainern--11-oktober-2026),
[ausgeblendete Inhalte](CSS-ATELIER-20261007.md#ausgeblendete-inhalte-und-erhaltene-objekte--11-oktober-2026)
und [Canvasbesitzer](CSS-BACKGROUNDS.md#dokument-canvas-und-tatsächliche-paintbesitzer--11-oktober-2026).
Gemeinsamer Ablauf und Statusbedeutung: [PLAN](../PLAN.md), [Index](README.md).
Codepfade und sichere Optimierungen dieses Durchgangs:
[Gesamtprüfung vom 6. Oktober](audit-2026-10-06/README.md).

Der getrennte [explizite Overflow-Nachweis vom 12. Oktober](CSS-ATELIER-20261007.md#explizite-overflow-ausrichtung--12-oktober-2026) ergänzt sechs begrenzte Anforderungen an die sechs Align-3-Definitionen. Nach dieser Ergänzung sind zehn weiterhin teilweise Zuordnungen mit 60 Anforderungen vorhanden: 31 erfüllt, fünf offen und 24 ungeprüft. Die bisherigen 52/25/5/22 sind der oben datierte 11.-Oktober-Stand. Unbekannte Standardachsen, native Studioabnahme und die übrige globale Erfassung bleiben offen.

Der [begrenzte Defaultnamespace-Nachweis vom 13. Oktober](CSS-ATELIER-20261007.md#defaultnamespace-ausnahmen-funktionaler-selektoren--13-oktober-2026) ergänzt vier benannte Anforderungen an vorhandene Selektordefinitionen. Danach bleiben 14 Zuordnungen teilweise mit 72 Anforderungen: 35 erfüllt, fünf offen und 32 ungeprüft. Das sind partielle Zuordnungen; globale vollständige Mapping-, ScopeRules- und Studioabnahme bleiben offen.

Der [begrenzte Scope-/CSSOM-Nachweis vom 13. Oktober](CSS-ATELIER-20261007.md#begrenzte-scope-kontexte-und-cssom-rundläufe--13-oktober-2026) ergänzt vier erfüllte Teilanforderungen und vier ungeprüfte Restanforderungen. Nun 16 ausdrücklich partielle Zuordnungen mit 80 Anforderungen: 39 erfüllt, fünf offen, 36 ungeprüft. Die bisherigen 72 Anforderungen bleiben unverändert; vollständige Scope-/Nestinggrammatik, globale Erfassung und native Studioabnahme sind weiterhin offen.


Am 15. Oktober erfüllen die beiden unverändert abgegrenzten Hintergrundverträge
[berechnete Bildwerte/currentColor](CSS-BACKGROUNDS.md#berechnete-hintergrundbilder-und-currentcolor--15-oktober-2026)
und [Ressourcen bei Fehlern/Seitenwechseln](CSS-BACKGROUNDS.md#hintergrundressourcen-bei-fehlern-und-seitenwechseln--15-oktober-2026)
ihre ursprünglichen Kriterien. Der zugeordnete Umfang bleibt bei 16 ausdrücklich
partiellen Zuordnungen mit 80 Anforderungen: 41 erfüllt, drei offen und 36
ungeprüft. Globale Erfassung, übrige Grammatiken/Kombinationen und ausstehende
native Abnahme sind damit weiterhin nicht abgeschlossen.

Am 16. Oktober sind auch die drei ursprünglichen Canvas-Farbverträge
für tatsächlichen Besitzer, einmalige Alpha-Komposition und lebende
Veröffentlichung erfüllt. [Besitzer](CSS-BACKGROUNDS.md#tatsächlicher-dokumentroot-und-erster-html-body--16-oktober-2026),
[Lifecycle](CSS-BACKGROUNDS.md#lebende-canvasfläche-und-compositorwechsel--16-oktober-2026)
und [Inlineflächen](CSS-BACKGROUNDS.md#inline-body-und-tatsächliche-wurzel--16-oktober-2026)
benennen die behobenen Pfade, unabhängigen Rohdaten und separaten normativen
Gegenstücke. Die unveränderten 80 zugeordneten Anforderungen umfassen damit
44 erfüllte und 36 ungeprüfte Anforderungen. Dieser bereits zugeordnete
Teilbestand enthält keine offene Anforderung mehr; die ungeprüften und noch
gar nicht vollständig zugeordneten Standardachsen zählen weiterhin für den
Gesamtabschluss. Vollständige Transformationen, Clip-/Masken-/Font-/Layout-
Kombinationen sowie Studio-Sichtabnahme sind dadurch nicht pauschal erfüllt.
