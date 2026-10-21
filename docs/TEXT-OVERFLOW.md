# Text-overflow

Unterstützt: `text-overflow: clip | ellipsis` auf Blockcontainern, nicht vererbt,
Standard `clip`. Typische Kombination:

```css
white-space: nowrap;
overflow: hidden;
text-overflow: ellipsis;
```

Die erste Version zeichnet Auslassungspunkte bei rechtem Überlauf einer LTR-Zeile
und `overflow-x: hidden`. `nowrap` ist nicht zwingend: auch eine überbreite,
untrennbare Textfolge in einer sonst umbrechenden Zeile kann gekürzt werden.
Explizite Umbrüche werden unabhängig behandelt. Nur linker Überlauf bei
rechtsbündigem Text erzeugt keine End-Auslassungspunkte.

`Layout/TextOverflow` erzeugt nach WordFlow eine Darstellungsliste. Die Originaltexte,
Wortmaße, Zeilenhöhen und Überlaufmaße bleiben erhalten; es gibt keine neuen
Layoutumbrüche. Teilwörter verwenden die vorhandenen OverflowWrap-Pools und
Graphemgrenzen. Die Ellipse (`…`) bekommt Schrift und Grundlinie des Blockcontainers.
Inline-Schrift, Hintergrund, Dekoration und Schatten verbleiben am erhaltenen
Text. Bilder werden atomar behandelt. Das erste Zeichen beziehungsweise erste
Bild wird bei sehr wenig Platz erhalten und vom Container abgeschnitten.

Messungen der Ellipse werden pro Run gespeichert. Gemessene Präfixe werden pro
betroffenem Wort auf 256 Einträge begrenzt. Unveränderte Größen und Wechsel
zwischen derselben schmalen und einer ausreichend breiten Ansicht verwenden
die vorhandenen Textobjekte/Messungen wieder. Bei einer anderen Präfixlänge im
Zeichenmodus kann der vorhandene OverflowWrap-Pfad die Glyphen-Gruppe ersetzen.
Versteckte Originalwörter und nicht benötigte Ellipsen werden beim Resize wieder
sichtbar beziehungsweise ausgeblendet. Zusätzliche Objekte gehören zur Seite und
werden mit ihr entfernt; keine eigenen Ereignisverbindungen.

Roblox `TextTruncate` arbeitet innerhalb eines einzelnen TextLabels. Unsere Zeilen
bestehen aus mehreren Wort-/Zeichenobjekten und können verschiedene Stile enthalten.
Daher koordiniert die Engine die Kürzung selbst. Der ursprüngliche DOM-Text wird
nicht verändert.

Grenzen: keine Kürzung, die der Scrollposition bei `overflow-x:auto/scroll` folgt,
kein RTL, keine Zwei-Wert-Syntax oder eigene Ellipsenzeichenfolge, kein `line-clamp`.
Komplex überlappende Textfolgen durch negative Abstände bleiben eine Näherung:
nach dem ersten gekürzten Element wird der Rest der Zeile verborgen.
Native Browser-/Studio-Sichtprüfung steht aus.

Beispiel 17 in beiden Demoquellen. `tests/TextOverflow.luau` prüft Cascade,
Wiederherstellung beim Resize, Messungs-/Objektwiederverwendung, Grapheme,
gemischte Stile und Zeichnung, Bilder, leere/mehrere Zeilen, Layoutinvarianz und
Abbruch während einer Messung.

Grundlagen: [CSS Overflow: Text-overflow](https://www.w3.org/TR/css-overflow-3/#text-overflow)
und [Roblox TextTruncate](https://create.roblox.com/docs/reference/engine/classes/TextLabel#TextTruncate).
