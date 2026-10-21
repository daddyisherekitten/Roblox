# Kleine Ergänzungen: Alias, 3D-Rahmen, HSL und HTML-Blöcke

`word-wrap: normal | break-word` ist ein Alias für `overflow-wrap`: gleicher
Style-Wert, Vererbung, Reihenfolge und `!important`. Die bisherigen Graphem-,
nowrap/pre- und Resize-Regeln gelten unverändert.

## Rahmen

Alle Rahmenkurz-/Langformen akzeptieren zusätzlich `outset`, `groove`, `ridge`,
auch unterschiedlich je Seite. Outset zeichnet oben/links hell und unten/rechts
dunkel. Groove und ridge teilen die Rahmenbreite in zwei aneinanderliegende
Bänder mit entgegengesetzter Helligkeit. Die Summe bleibt die CSS-Rahmenbreite.
Alpha/currentcolor, Block-/Bildlayout und Resize-Pools werden weiterbenutzt.

Farbabstufung ist angenähert: hell entspricht der Ausgangsfarbe, dunkel zwei
Dritteln ihrer RGB-Kanäle. Bei Schwarz werden Grauwerte verwendet, damit der
Effekt sichtbar bleibt. Der bisherige inset-/hr-Pfad bleibt erhalten. Ecken
erhalten jetzt diagonale Übergänge über [Eckbilder](BORDER-CORNERS.md); gerundete Muster fehlen. Outline erhält
dadurch keine zusätzlichen 3D-Stile.

## HSL

`hsl()` und `hsla()` funktionieren überall, wo Farben erlaubt sind: Text,
Hintergrund, Rahmen, Outline, Dekoration und Schatten.

```css
color: hsl(215, 65%, 35%);
background: hsla(215, 65%, 50%, 0.15);
border-color: hsl(.5turn 100% 50% / 25%);
```

Kommasyntax verlangt Prozent für Sättigung/Helligkeit; die Leerzeichensyntax
akzeptiert Prozent oder Zahlen auf der 0–100-Skala. Alpha ist eine Zahl oder
Prozent. Hue akzeptiert eine Zahl in Grad oder deg/grad/rad/turn und wird auf
eine Umdrehung normalisiert. Kanäle/Alpha werden begrenzt, numerische Eingaben
wie im bisherigen Parser auf Betrag 100000 beschränkt. Kein none, relative Farben,
calc oder Exponentialnotation. Modernes RGB wird dadurch nicht erweitert.

## HTML-Elemente

| Element | Standarddarstellung |
| --- | --- |
| `address` | Kursiver Block, keine eigenen Außenabstände |
| `dl` | Block, oben/unten 1em; innerhalb ul/ol/dl 0 |
| `dt` | Block, normalgewichtig, ohne zusätzliche Abstände |
| `dd` | Block, links 40px Einzug |
| `figure` | Block, oben/unten 1em, links/rechts 40px |
| `figcaption` | Block in DOM-Reihenfolge, ohne eigene Abstände/Zentrierung |

Standardabstände richten sich nach der endgültigen Schriftgröße; CSS-Overrides
und bestehendes Margin-Collapsing bleiben aktiv. Die Regeln gelten für LTR.
Ausgelassene dt/dd-Endtags vor einem neuen dt/dd beziehungsweise am Ende einer
direkt umgebenden dl werden verarbeitet; verschachtelte dl begrenzen den Suchlauf.
Dies ersetzt keinen vollständigen HTML-Fehlerkorrekturalgorithmus.

Demo18–20 kombiniert je eine Verwendung der neuen Features. Figure zeigt eine
Textdarstellung mit Caption ohne neues Bildasset. Browser- und Studio-HTML sind
identisch. Tests/SimpleAdditions prüft Farben und Integration, Alias-Cascade,
Rahmengeometrie/Farben/Alpha, Bilder, Resize, Elementdefaults und Parserfälle.
Native Sichtprüfung steht aus.

Grundlagen: [HTML-Standarddarstellung](https://html.spec.whatwg.org/multipage/rendering.html),
[CSS-Rahmen](https://www.w3.org/TR/css-backgrounds-3/#border-style),
[HSL-Farben](https://www.w3.org/TR/css-color-4/#the-hsl-notation).
