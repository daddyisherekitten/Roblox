# Ergänzungen mit mittlerem Aufwand

Stand: 12.09.2026. Sichtbare Beispiele 21–27 in `examples/ubuntu-roboto-page.html`,
identisch im HTML von `examples/HTMLPage.client.luau`. Alle zehn Punkte sind integriert:

| HTML/CSS | Verhalten |
| --- | --- |
| `<wbr>` | Unsichtbare Umbruchmöglichkeit, ohne Leerzeichen oder Trennstrich. |
| `word-break: normal / break-all` | `break-all` kann den verbleibenden Zeilenplatz mit einem Wortfragment füllen. |
| `overflow-wrap: anywhere` | Notumbruch langer Wörter; berücksichtigt Grapheme auch bei der intrinsischen Mindestbreite. `break-word` behält seine bisherige Mindestbreite. |
| `list-style-position: inside / outside` | Innenmarker belegt nur Platz in der ersten Zeile. Ein direkt anschließender Block beginnt darunter. |
| `list-style` | Unterstützter Markertyp plus Position, in beliebiger Reihenfolge; ausgelassene Komponenten werden auf `disc outside` zurückgesetzt. |
| Negative `margin` | Signierte px und Prozentwerte; benachbarte positive/negative Ränder werden korrekt verrechnet. |
| Prozent-`margin`/`padding` | Alle vier Seiten beziehen sich auf die Inhaltsbreite des Elternblocks; Neuberechnung bei Resize. Negative Paddingwerte bleiben ungültig. |
| `font` | Stil, Gewicht, Größe, optional `/line-height`, Familie/Fallbackliste. Beispiel: `italic bold 20px/1.5 Roboto, sans-serif`. Fehlende Stil-/Gewichts-/Zeilenhöhenangaben werden zurückgesetzt. |
| `inherit`, `initial`, `unset` | Für alle Eigenschaften im Katalog, einschließlich Kurzformen. `initial` verwendet CSS-Ausgangswerte statt HTML-Tagformatierung. `unset` folgt der Vererbbarkeit. |
| `opacity` | Zahl oder Prozent, auf 0–1 begrenzt. Block, Inline-Textgruppe und Bild; verschachtelte Gruppen werden gemeinsam komponiert. |
| Block-/Flexbilder | `display:block` auf `img`, natürliche Größe, Auto-Margins; direkte Bilder sind eigene Flexitems mit Größen-/Fit-Regeln. |
| Ellipsis mit Scrollen | `text-overflow:ellipsis` auch bei `overflow-x:auto/scroll`; die sichtbare rechte Grenze folgt `CanvasPosition.X`. Am Inhaltsende verschwindet die Ellipsis. |

## Module und Wiederverwendung

- `CSS/CompositeValues`: Kurzformen und Auflösung der CSS-weiten Schlüsselwörter.
- `Layout/BoxSpacing`: unveränderte CSS-Werte getrennt von verwendeten Pixelabständen.
- `Layout/BlockImage`: Bildgröße und Bilddarstellung im Block-/Flexfluss ohne Text-Strut.
- `Rendering/GroupOpacity`: CanvasGroup-Ansichtsflächen einschließlich sichtbarem Überstand.
- Vorhandene Wortfragment-Pools werden für Umbruch und Ellipsis wiederverwendet.
  Scroll-Listener existieren nur für betroffene Ellipsis-Container. Sie aktualisieren
  nur die Textprojektion aus gespeicherten Zeilen, ohne Blocklayout, Canvas- oder
  Statusänderung. Scroll- und Reflow-Anfragen
  werden in einem gemeinsamen Worker zusammengefasst. Die Demo-Fenstergriffe
  setzen am Mount-Ziel `HTMLViewportResizing=true` beim Greifen und `false`
  beim Loslassen, Fokusverlust oder Abbruch durch eine Host-Größenänderung.
  Während der Geste warten Layout und CSS-Media-/Viewport-Anpassungen gemeinsam;
  auch eine lange Pause bei gehaltenem Griff beendet die Geste nicht. Loslassen
  berechnet sofort die neueste Breite und Höhe, ohne 200ms-Verzögerung oder Polling.
  Eine suspendierte Berechnung wird beim Beginn einer neuen Geste abgebrochen.
  Andere Resize-Controller können dasselbe Attribut verwenden; ohne aktive Geste
  starten Größenwechsel (z. B. Vollbild oder programmatische Änderungen) sofort.
  Bildabschluss und andere erzwungene Updates warten bei einer aktiven Geste
  ebenfalls, ansonsten laufen sie sofort. Lokale Control-Resizes behalten die
  1/60s-Bündelung. Erstladen bleibt sofort, sofern keine Geste aktiv ist. Debug
  meldet jeden echten Layoutabschluss. Timer und Verbindungen werden beim
  Entfernen der Seite aufgeräumt.

  CSS-Viewport-Anpassung und Block-/Textlayout verwenden nun dasselbe kooperative
  Zeitbudget wie SVG (`RenderWorkBudgetMS`, standardmäßig 4ms, 0 deaktiviert die
  zusätzlichen Pausen). Das Budget gilt über die Unteraufrufe hinweg; Prüfpunkte
  in Wortfluss, Flex-Auflösung und Spalten/Floats/Tabellen ermöglichen Maus- und
  Spielverarbeitung zwischen Rechenabschnitten. Einzelne native Aufrufe können
  länger dauern als das Zielbudget.
  Hover-/Fokus-CSS wird während eines Durchlaufs gesammelt und danach angewandt.
  Animationen und Sticky-Aktualisierung greifen währenddessen nicht auf unfertige
  Geometrie zu; Scroll-Snapping wird bis zum Abschluss vorgemerkt. Eine neuere
  Layoutanforderung beendet den alten Durchlauf am nächsten Prüfpunkt und erzwingt
  einen vollständigen Wiederaufbau der Geometrie für den neuesten Zustand.
  Nur ein gültiger Abschluss veröffentlicht Canvasgröße, Layoutstatistik und ready.
  Entfernen der Seite bricht auch einen pausierten Durchlauf ab. Bereits gespeicherte
  Repaint-Callbacks behalten anschließend ihre normalen Lebensdauerprüfungen.
  `page.LastLayoutWork` enthält die Budgetzähler des letzten gültigen Layouts.

  Prüfungen: `ResizableTestWindow`, `LayoutJob`, `CooperativeLayout`, `PageLifecycle` und
  `CombinationStates` testen Pausen, identische Endgeometrie, neue Eingaben,
  ausstehende CSS-Zustände, Abbruch/Wiederholung und Seitenabbau.

## Grenzen

Die vorhandenen LTR-, Fontmetriken- und Boxlayout-Näherungen bleiben bestehen.
Kein vollständiger Unicode-Zeilenumbruch, Silbentrennung, `keep-all`, Markerbild,
`::marker`, em/rem/calc, Systemfont-Kurzform, Font-Variant/Stretch oder `revert`.
`font` akzeptiert die bereits unterstützten Größen, Gewichte und Stile.
`display:inline` verarbeitet Textcontainer; keine vollständige Inline-Boxzerlegung
mit Rahmen/Padding. Eltern-Kind-Margin-Collapsing bleibt auf die bisherigen
Listen-/Zitatfälle begrenzt; durchgehende Kollapsketten leerer Blöcke fehlen.
Zyklische Prozentgrößen und intrinsische Flex-Bildminima sind weiterhin ein Teilmodell.

CanvasGroup komponiert überlappende Nachfahren gemeinsam, statt deren Alpha einzeln
zu multiplizieren. Gruppen verwenden eigene Texturen und benötigen
`ZIndexBehavior.Sibling`. Große Ansichtsflächen, Gerätelimits und Roblox-Qualitätsstufen
können Auflösung/Speicher beeinflussen. Gruppengrenzen berücksichtigen die berechneten
Box-/Textüberstände, Schatten und Konturen; außergewöhnliche Glyphenüberstände bleiben
eine Näherung. Inline-Gruppen mit eigenen Blocknachfahren sind noch kein vollständiges
CSS-Compositing-Modell. Native Studio-Sichtprüfung bleibt erforderlich.

## Prüfung

`tests/MediumAdditions.luau` prüft alle Katalogeigenschaften mit den drei CSS-weiten
Werten, Kurzform-Resets, Umbrüche/Mindestbreiten, signierte und prozentuale Abstände,
Markerfolgelinien, Block-/Flexbilder, Gruppenhierarchie, Resize-Reuse und scrollende
Ellipsis. Bestehende Regressionstests bleiben erhalten; nur inzwischen gültige
Werte wurden aus alten Negativtests entfernt.

Referenzen: [CSS Overflow – Ellipsis und Scrollen](https://www.w3.org/TR/css-overflow/#ellipsis-scrolling),
[Roblox CanvasGroup](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup).
