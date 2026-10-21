# CSS-Längen, Viewport-Einheiten und Berechnungen

Die gemeinsame Längenauflösung unterstützt `px`, `%`, `em`, `rem`, `vw`, `vh`,
`vmin` und `vmax` sowie `calc()`, `min()`, `max()` und `clamp()`. Das gilt an
den vorhandenen Längenstellen: Schriftgröße und line-height, width/height und
min/max, margin/padding, gap, Flexbasis, Grid-Tracks, inset, Rahmen/Rundung/
Outline, Textabstände/-dekoration, tab-size, Bildposition/-ausrichtung und
Schatten. Die Grenzen der jeweiligen Eigenschaft gelten weiterhin.

- `em` bezieht sich auf die berechnete Schriftgröße des Elements; innerhalb von
  `font-size` auf die Elternschriftgröße.
- `rem` bezieht sich auf die Schriftgröße von `html`. Für `font-size` auf `html`
  gilt die Ausgangsgröße 16 px.
- `vw` und `vh` verwenden Breite und Höhe des sichtbaren Roblox-Fensters;
  `vmin`/`vmax` verwenden die kleinere/größere Achse. Ein Resize berechnet nur
  Seiten mit Viewport-Einheiten oder Media Queries neu.
- `calc()` unterstützt `+`, `-`, `*` und `/`. Multiplikation und Division
  verlangen eine einheitenlose Zahl; Division durch null und Länge mal Länge
  werden verworfen.
- `min()`/`max()` akzeptieren mehrere kompatible Argumente. `clamp()` verlangt
  genau Minimum, bevorzugten Wert und Maximum. Die Funktionen dürfen
  verschachtelt werden und Prozentwerte mit absoluten Längen mischen.
- Geerbte Längen bleiben berechnete Pixelwerte. Eine einheitenlose
  `line-height` bleibt ein Faktor.
- Eingabewerte und berechnete Pixelwerte sind auf die Engine-Grenzen beschränkt.
  Ungültige Ausdrücke erzeugen eine Diagnose und lassen frühere gültige Werte
  der Cascade bestehen. `ex`, allgemeines `ch` außerhalb der bestehenden
  Grid-Unterstützung, wissenschaftliche Zahlennotation und CSS-Escapes fehlen.

`CSS/LengthExpression` parst und löst alle Berechnungen zentral auf. Prozentwerte
bleiben bis zum Layout an ihre Bezugsgröße gebunden. `InlineStyle` berechnet
Schrift- und Viewport-Einheiten im Stilkontext; Layoutmodule verwenden denselben
Resolver. Dadurch liefern Box-, Flex-, Grid-, Tabellen-, Bild- und
Positionierungspfade identische Ergebnisse.

Die frühere sichtbare Sammelseite wurde entfernt. `tests/RelativeLengths.luau`
prüft verschachtelte Ausdrücke, ungültige Typkombinationen, berechnete
Layoutgrößen und die Live-Neuberechnung nach einem Viewport-Resize.

Semantik: [CSS Values and Units](https://www.w3.org/TR/css-values-4/).
