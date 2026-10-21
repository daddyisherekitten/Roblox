# Dynamische Tabellen

Die Tabellen-Schnittstellen verwenden den DOM-Baum, nicht die Layout-Caches. `table.rows` enthält zuerst die Zeilen der direkten `thead`-Kinder, danach direkte Zeilen und `tbody`-Zeilen in Baumreihenfolge, zuletzt `tfoot`-Zeilen. Verschachtelte Tabellen gehören nicht zur äußeren Sammlung.

Unterstützt sind:

- `HTMLTableElement`: `caption`, `tHead`, `tFoot`, `tBodies`, `rows`, `createCaption`, `deleteCaption`, `createTHead`, `deleteTHead`, `createTFoot`, `deleteTFoot`, `createTBody`, `insertRow`, `deleteRow`.
- Tabellenabschnitte: lebende `rows`, `insertRow`, `deleteRow`.
- Zeilen: lebende `cells`, `rowIndex`, `sectionRowIndex`, `insertCell`, `deleteCell`.
- Zellen: `cellIndex`, reflektierte `colSpan`, `rowSpan`, `headers`, `abbr`, `scope`, `noWrap`. Spalten und Spaltengruppen reflektieren `span`.
- Historische Stringattribute der Tabelleninterfaces wie `align`, `vAlign`, `width`, `bgColor`, `cellPadding` und `cellSpacing` werden reflektiert. Die Reflexion allein bedeutet nicht, dass jede historische Präsentationswirkung vollständig umgesetzt ist.

Sammlungen bleiben lebend und identisch. Indexkonvertierungen laufen vor der erneuten Abfrage der Sammlung, einschließlich Autorcode in `valueOf`. Falsche Indizes erzeugen `IndexSizeError`; nicht passende Kopf-/Fuß-Elemente erzeugen `HierarchyRequestError`. `insertRow()` auf einer Tabelle ohne Zeilen/`tbody` erzeugt zunächst einen `tbody`.

DOM-Edits laufen durch dieselbe Mutationstransaktion wie andere Elemente. Renderer und TableLayout erneuern die Spannen, gemeinsamen Tracks, Abschnitts-/Spaltenhintergründe, Caption-Anordnung und kollabierten Rahmen. Zeilen, Zellen, Eingabefelder und Ereignisbindungen werden erhalten, solange ihr DOM-Knoten erhalten bleibt. Entfernte Ressourcen werden vom normalen strukturellen Cleanup freigegeben. Eine Tabellenänderung markiert das gemeinsame Tabellenlayout; unabhängige Eingabefelder und nachfolgende Blöcke werden nicht neu erzeugt.

Die Produktionstests verwenden `HTMLScripts`, `DOMReconcile`, die echte RenderTree-Erstellung und TableLayout mit einem kontrollierten GUI-/Textmess-Adapter. Sie prüfen Einfügen, Entfernen, Verschieben, Span-Änderungen, Caption-/Abschnittsersetzung, lebende Sammlungen, Observer, Rahmenmodus und erhaltene Eingabe-Identität. Es sind keine FPS-Benchmarks.

Weiterhin gelten die allgemeinen Renderergrenzen: Roblox-Fontmetriken und Rasterung können sich vom Browser unterscheiden; der HTML-Parser ist kein vollständiger fehlerkorrigierender Browser-Tree-Builder. Extreme Tabellen unterliegen den vorhandenen Ressourcenlimits (4096 Spalten, 65534 Rasterzeilen; eine Million Slots für kollabierte Rahmen).

Normative Grundlage: [WHATWG HTML – Tables](https://html.spec.whatwg.org/multipage/tables.html).
