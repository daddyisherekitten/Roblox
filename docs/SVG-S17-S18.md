# S17 + S18 — lineare und radiale Farbverläufe

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und vom Nutzer visuell bestätigt („gut weiter“).\nKein neuer Clientbericht übermittelt.
S01–S16 sind visuell bestätigt. Größere Etappenpakete bleiben die Nutzerpräferenz.

## Vergleich und Bedienung

[Gemeinsame Browsertafel](../tests/fixtures/svg-regressions.zip), alternativ
[S17](../tests/fixtures/svg-regressions.zip) / [S18](../tests/fixtures/svg-regressions.zip).
StudioDemoConfig: ActiveDemo=SVGLab, SVGStage=S17_S18. Stop → Play.
1/2/3: 240/480/960 px. R: 20 Neuaufbauten. Erwartet sechs Tafeln, zwölf lebende
EditableImages, PixelReadback=true und keine Diagnosen.

- S17-colors: RGB-Farbstopps, Alpha, doppelte Offsets/harter Übergang und
  sRGB gegenüber linearRGB.
- S17-units: objectBoundingBox gegenüber userSpaceOnUse; gradientTransform,
  zusätzliche Formtransformation und Verlauf auf einer Kontur.
- S17-spread: pad/repeat/reflect, verkürzter Gradientvektor, href-Kette und
  Stopps mit CSS-Variablen im Kontext einer referenzierenden Definition.
- S18-focus: zentrale/versetzte Fokuspunkte, fr-Innenkreis; rote Prüfkreuze.
- S18-units: Bounding-Box-Ellipse, Benutzerkoordinaten-Kreis, gedrehter Verlauf
  und transparente Füllung mit isolierter Gruppen-Deckkraft.
- S18-spread: radiale Wiederholungen, harte Farbkante, Fokus außerhalb des
  Endkreises mit transparentem Bereich und einzelner Stopp.

scripts/sync-svg-gradients.py erzeugt drei Luau-Quellenmodule und die drei
Browserseiten aus denselben sechs SVG-Dateien. Jede Browsertafel läuft in einem
eigenen SVG-Blob-iframe: Stylesheets bleiben isoliert. Die browsernative SVG-
Ausgabe ist die Referenz. Die lokal kontrollierte Vorschau in
build/svg-s17-s18-preview.png stammt vom tatsächlichen Luau-Rasterkern;
sie ist kein Studio- oder Browser-Screenshot.

## Implementierung

SVG/Gradient.luau kompiliert Paintserver vor dem Zeichnen. SVG/Paint erhält
case-sensitive url()-Referenzen mit optionaler Ersatzfarbe/none/currentColor.
Document stellt Ressourcenauflösung mit dem bisherigen externen Resolver-Cache
und die CSS-Berechnung von Definitionen/Stopps bereit. Definitionen müssen nicht
im sichtbaren Renderbaum stehen; display:none an Vorfahren versteckt ihre
Verwendung als Paintserver nicht.

linearGradient: x1/y1/x2/y2 und ihre Standardwerte; Projektion im Gradientenraum.
radialGradient: cx/cy/r, fx/fy mit Rückfall auf cx/cy sowie fr. Die quadratische
Zweikreis-Gleichung berücksichtigt auch äußere Fokuspunkte und schrumpfende
Radien. Bereiche ohne gültigen Kegelschnitt bleiben transparent; gleiche Kreise
zeichnen nichts. Bei zusammengefallenen wiederholten Ringen am Fokus auf dem
Endkreis wird der nach Stoppabständen gewichtete Farbmittelwert verwendet.

Gemeinsam: objectBoundingBox/userSpaceOnUse, Prozent-/SVG-Längeneinheiten,
gradientTransform bzw. CSS transform, pad/repeat/reflect, href/xlink und externe
Resolver-Ziele. Gradientenattribute werden aus passenden Templates übernommen,
eigene Stopps ersetzen übernommene Stopps. Stopps erhalten CSS-Kaskade,
stop-color/stop-opacity, currentColor und var(). Referenzierte Stopps erben
im Stilkontext der verwendeten Definition; Selektoren beziehen sich auf ihre
Quellknoten, wie bei den S16-Instanzen.

Offsets werden auf 0–1 geklemmt und monoton angehoben. Gleiche Offsets ergeben
eine harte Kante; an der Kante gewinnt der letzte Stopp. Kein Stopp malt nichts,
ein Stopp ergibt eine konstante Farbe. Ein linearer Nullvektor nimmt den letzten
Stopp. color-interpolation unterstützt sRGB, linearRGB sowie auto als sRGB.
Farbe und Alpha werden getrennt interpoliert, danach mit Paint-Opacity,
Formabdeckung und bestehender Gruppenkomposition kombiniert.

Die inverse Abbildung enthält Formtransform, Bounding-Box-Abbildung und
Gradienttransform. Dadurch bleibt derselbe Sampler auch für transformierte
Füllungen, Konturen und non-scaling-stroke nutzbar. Raster benötigt keine
Gradienten-Referenzsuche pro Pixel. Harte Stopps, wiederholte Verläufe und äußere
radiale Fokusse erhalten vier Subpixelproben; Formkanten verwenden weiterhin
die vorhandene Flächenabdeckung.

## Tests und Grenzen

tests/SVGGradients.luau prüft analytische Farben, Farbraum, Alpha, Offsets,
Nullvektor, singuläre Transformation, kleine Radien, CSS-Transformpriorität,
currentColor, Template-Variablen, href/xlink, externe Auflösung, fehlende und
zyklische Referenzen, Fokus/Innenradius, Farbmittelwert und Kantenglättung.
Alle sechs echten Tafeln werden bei 240/480/960 px gerastert. Kontrollpunkte
prüfen Farben und Transparenz; Abbruch und 20 Controller-Lebenszyklen sind
abgedeckt. Bestehende SVG-/HTML-Suiten werden normal und mit -O2 geprüft.

Grenzen: maximal 64 Template-Schritte, 1024 Stopps pro verwendeter Definition;
pro vorbereitetem Dokument zusätzlich 4096 Bindungen, 8192 Referenzschritte,\n16384 berechnete Stopps und 100 Gradientendiagnosen. Die Parser-, Resolver-\nund Rasterbudgets bleiben bestehen. Fehler erhalten eine
Diagnose und isolieren die betroffene Farbe; ungültige Referenzen verwenden
die angegebene Ersatzfarbe. Kein automatischer Netzwerkzugriff. Externe Inhalte
müssen über Document.prepare(..., {Resolve=...}) bereitgestellt werden.

Der Renderer nutzt 8-Bit-Ausgabe und endliche Subpixelabtastung. Sehr enge
Wiederholungen und harte Grenzen können von Browserfiltern abweichen; dies ist
keine analytische Integration über den gesamten Pixel. Objekt-Hüllen kurviger
Pfade verwenden die bestehende feine Kurvenabtastung aus S13. color-interpolation
gilt hier für Verlaufstopps; eine lineare Farbraum-Komposition ganzer Gruppen
ist damit nicht implementiert. CSS-Farbprofile/wide-gamut, XML-Base, vollständige
CSS-URL-Escapes und die Basis-URL geerbter Paintwerte über externe use-Grenzen
sind nicht vollständig abgedeckt. Die bisherigen CSS-Teilumfangsgrenzen aus
S15/S16 bleiben bestehen. Kein Live-DOM-Beobachter; Änderungen brauchen erneutes
Prepare. Allgemeine SVG-HTML-Paint-Anbindung folgt weiterhin separat.

- [x] Sechs Tafeln: visueller Vergleich vom Nutzer bestätigt.
- [ ] Clientbericht: zwölf Bilder, PixelReadback=true, keine Diagnosen.
- [ ] Größenwechsel und R im Client bestätigen.

Grundlagen: [SVG2 Paintserver](https://www.w3.org/TR/SVG2/pservers.html) und
[SVG-Farbraumregeln](https://www.w3.org/TR/SVG11/painting.html#ColorInterpolationProperty).
