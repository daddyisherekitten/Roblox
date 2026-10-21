# Katalogabgleich, 21. September 2026

Verglichen wurden der ausgeführte Engine-Katalog aus `scripts/export-engine-catalog.cjs` und drei lokal gespeicherte Referenzdateien. Der vollständige, maschinenlesbare Snapshot steht in `build/audit/inventory.json`: Namen, Quelllinks, Metadaten, Differenzlisten und SHA-256-Prüfsummen der Referenzdateien. Es wurde noch keine neue Testseite erstellt.

## HTML: Namen vollständig katalogisiert, Verhalten weiterhin begrenzt

Quelle: erste Tabelle „List of elements“ im [WHATWG-Elementindex](https://html.spec.whatwg.org/multipage/indices.html#elements-3), Snapshot mit Stand 21. September 2026. Ausgewertet wird ausschließlich die Elementspalte; `h1` bis `h6` werden einzeln gezählt. Die Tabelle enthält außerdem die Namensraumwurzeln `svg` und `math` sowie die offene Familie autonomer Custom Elements.

| Menge | Anzahl |
| --- | ---: |
| Benannte HTML-Elemente im WHATWG-Index | 113 |
| Davon im Engine-Katalog vorhanden | 113 |
| Fehlende HTML-Elementnamen | 0 |
| Engine-Einträge insgesamt | 114 |
| Zusätzlicher Engine-Eintrag außerhalb des HTML-Namensraums | 1: `svg` |
| Fremdnamensraumwurzeln als separate Erweiterungen | 2: `svg`, `math` |

Aktuelle HTML-Namen:

`a`, `abbr`, `address`, `area`, `article`, `aside`, `audio`, `b`, `base`, `bdi`, `bdo`, `blockquote`, `body`, `br`, `button`, `canvas`, `caption`, `cite`, `code`, `col`, `colgroup`, `data`, `datalist`, `dd`, `del`, `details`, `dfn`, `dialog`, `div`, `dl`, `dt`, `em`, `embed`, `fieldset`, `figcaption`, `figure`, `footer`, `form`, `h1`, `h2`, `h3`, `h4`, `h5`, `h6`, `head`, `header`, `hgroup`, `hr`, `html`, `i`, `iframe`, `img`, `input`, `ins`, `kbd`, `label`, `legend`, `li`, `link`, `main`, `map`, `mark`, `menu`, `meta`, `meter`, `nav`, `noscript`, `object`, `ol`, `optgroup`, `option`, `output`, `p`, `picture`, `pre`, `progress`, `q`, `rp`, `rt`, `ruby`, `s`, `samp`, `script`, `search`, `section`, `select`, `selectedcontent`, `slot`, `small`, `source`, `span`, `strong`, `style`, `sub`, `summary`, `sup`, `table`, `tbody`, `td`, `template`, `textarea`, `tfoot`, `th`, `thead`, `time`, `title`, `tr`, `track`, `u`, `ul`, `var`, `video`, `wbr`.

`script` ist ausdrücklich `parser-only`; die übrigen 112 HTML-Namen und `svg` tragen `supported` **im dokumentierten Roblox-Profil**. Das bedeutet keine vollständige HTML-/DOM-/Accessibility-Konformität. Beispielsweise umfasst `selectedcontent` nur den beschriebenen Textspiegel; ein vorhandenes `template`/`slot` ersetzt keine vollständige Custom-Elements-Laufzeit. `math` besitzt keinen eigenen Engine-Katalogeintrag. Beliebig viele gültige Custom-Elementnamen sind keine endlich abzählbare Tagliste.

## CSS: 370 Engine-Namen gegenüber 1.013 Namen im Referenzverbund

Quellen: [W3C-Property-Index](https://www.w3.org/Style/CSS/all-properties.en.html), eindeutige Namen aus `#propdef-…`-Verweisen; [MDN Data, css/properties.json](https://github.com/mdn/data/blob/main/css/properties.json), direkte Property-Schlüssel. Der Custom-Property-Platzhalter `--*` wird ausgeschlossen und als offene Familie behandelt. Shorthands und Longhands bleiben getrennte Namen.

| Vergleich | Namen gesamt | Im Engine-Katalog | Ohne eigenen Engine-Eintrag |
| --- | ---: | ---: | ---: |
| W3C-Index | 855 | 367 | 488 |
| MDN Data | 671 | 370 | 301 |
| Union W3C + MDN + Engine | 1.013 | 370 | 643 |

Alle 370 Engine-Namen kommen in MDN Data vor. Drei fehlen im verwendeten W3C-Index: `animation-trigger`, `backdrop-filter`, `touch-action`. W3C und MDN teilen 513 Namen; 342 stehen nur im W3C-Index und 158 nur in MDN. Das zeigt, warum eine einzelne Liste keine vollständige Referenz ist.

Die 301 MDN-Namen ohne eigenen Engine-Katalogeintrag verteilen sich nach dem MDN-Statusfeld auf **134 standard, 33 experimental, 119 nonstandard und 15 obsolete**. Diese Kategorien sind keine Zusicherung der Browserverfügbarkeit. Alle 370 vorhandenen Engine-Propertyeinträge tragen `supported`, jedoch mit konkreten Values-/Limitations-Feldern, die der Snapshot unverändert mitliefert.

Wichtige Differenzgruppen sind zusätzliche Fontoptionen (`font-optical-sizing`, `font-variation-settings`, `font-synthesis-*`), Maskenrahmen-Longhands (`mask-border-slice`, `mask-border-width`, `mask-border-outset`, `mask-border-repeat`), Fragmentierung/Druck (`break-*`, `orphans`, `widows`, `page`), Text-/Schreibmodi (`text-combine-upright`, `unicode-bidi`, `text-box-*`), View-Transitions und neuere Trigger-/Corner-Longhands. Vollständige Listen stehen im JSON unter `css.missingEngineEntries` und `css.missingMDNStandardEntries`.

**Ein fehlender Katalogschlüssel ist nicht automatisch ein fehlendes Laufzeitfeature.** `InlineStyle.luau` normalisiert etwa `-webkit-line-clamp` zu `line-clamp` und `-webkit-mask-box-image` zu `mask-border`; `-webkit-box-orient` wird als Kompatibilitätshinweis konsumiert. SVG besitzt einen separaten Style-Pfad für unter anderem `fill`, `stroke`, `stroke-width` und Geometrieeigenschaften. Umgekehrt beweist ein vorhandener Schlüssel keine Unterstützung sämtlicher Werte/Kombinationen.

## Verbindlicher Scope für den Stresstest

- Alle 113 aktuellen HTML-Namen erhalten eine semantisch passende Verwendung; Dokument-/Metadaten-/Tabellen-Unterelemente sind keine beliebig platzierbaren Demo-Karten. SVG, MathML und Custom Components werden separat ausgewiesen.
- Die 1.013 CSS-Namen bilden das vollständige **Inventar dieses Snapshots**. Sie umfassen historische, experimentelle, präfixierte und kontextspezifische Eigenschaften. Ein Inventareintrag allein zählt nicht als ausgeführter visueller Test.
- Der visuelle Belastungsteil kombiniert nachprüfbare Funktionen des Engine-Profils. Fehlende Werte, Browser-spezifische Funktionen und zusätzliche APIs benötigen ehrliche Status-/Fallbackhinweise.
- CSS-Werte, Selektoren, At-Rules, Deskriptoren, Pseudoelemente und ihre unendlich vielen Kombinationen sind durch einen Property-Namensindex nicht vollständig abgedeckt. Weder dieser Audit noch eine einzelne Webseite kann lückenlose Webstandard-Konformität beweisen.
