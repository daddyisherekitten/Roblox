# S11 — Füllregeln und Pfadlänge

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und vom Nutzer visuell bestätigt.
S01–S11 sind bestätigt. Für S11 wurde kein zusätzlicher Clientbericht übermittelt.

## Vergleich

[Browsertafel](../tests/fixtures/svg-regressions.zip). StudioDemoConfig: ActiveDemo=SVGLab,
SVGStage=S11; Stop → Play. 1/2/3: 240/480/960 px, R: 20 Neuaufbauten.
Erwartet: drei Tafeln, sechs lebende EditableImages und keine Diagnosen.

1. Links nonzero, rechts evenodd. Oben gleichgerichtete Kreis-Konturen: links
   eine volle Scheibe, rechts ein Loch. Unten entgegengesetzte Richtung: zwei Ringe.
2. Selbstüberschneidender Stern und drei gleichgerichtete Rechtecke. Links jeweils
   vollständig gefüllt; rechts offene Sternmitte bzw. Rahmen mit innerer Insel.
3. Drei identische gestrichelte Linien: ohne Kalibrierung 40/40, mit pathLength=8
   und 1/1, mit pathLength=80 und 10/10. Darunter identische Kreismuster mit
   pathLength=8 bzw. 16. Strichenden und Lücken müssen übereinstimmen.

Die identischen SVG-Laufzeitquellen werden über scripts/sync-svg-fill.py in
SVGLab/FillSources und die Browsertafel übernommen.

## Umsetzung und Grenzen

Paint erbt fill-rule mit nonzero als Standard, evenodd als Alternative sowie
inherit/initial/unset. Raster verwendet die gerichtete Windungszahl oder deren
Parität. Die Regel betrifft nur die Fülloperation: Konturstücke werden weiterhin
als nichtnull-Vereinigung gemalt, auch bei Löchern und überlappenden Strichteilen.
Die bisherigen Kanten-/Clippingverfahren bleiben erhalten.

PathMetrics liest das nicht vererbte pathLength für Pfade und Grundformen.
Negative, nichtnumerische oder mit Einheiten versehene Werte liefern eine Diagnose
und werden ignoriert. Die gemessene Länge schließt echte Z-Segmente ein; moveto
und der implizite Schluss einer offenen Füllfläche tragen keine Strecke bei.
Nicht-Prozent-Distanzen werden mit gemessener Länge / pathLength kalibriert.
Prozentwerte behalten ihren Viewportbezug. pathLength=0 erhält Nullwerte und
skaliert positive Nicht-Prozent-Distanzen zu unendlich.

Für die vorgeschriebene sichtbare Kalibrierungsprobe wurde ein Teil von S12
vorgezogen: stroke-dasharray mit geerbten Längen/Prozenten, ungeraden Listen
(verdoppelt), Nullanteilen und solid bei einer reinen Nullliste. Dashes setzt
das Muster nach jedem moveto zurück, bewahrt Kurvenzwischenpunkte und verbindet
Striche über geschlossene Nähte sowie Lücken der Länge null. Der vorhandene
butt-/miter-Stroke malt die resultierenden Teilkonturen. dashoffset und weitere
Kappen/Verbindungen bleiben S12; die aktuelle Probe verwendet Offset 0.

Strichgrenzen innerhalb von 1e-12 × max(1, Segmentlänge) am nächsten geometrischen
Punkt werden auf diesen gesetzt. Das verhindert künstliche Mikrosegmente und
abweichende Joins durch Gleitkommareste bei ansonsten identischen Kreismustern.

Kurvenlängen beruhen auf den skalierungsabhängigen Polylinien aus S09/S10 und sind
Näherungen. S11 stellt keine allgemeine getTotalLength/getPointAtLength-DOM-API,
Textpfade oder Bewegungsanimation bereit. Die Kalibrierung wird derzeit von der
Strichmuster-Ausgabe genutzt. Allgemeine HTML-Paint-/CSS-Anbindung bleibt offen.
Budgets: höchstens 64 Einträge im Ausgangsmuster, 65536 Teilungsschritte pro
gestrichelter Form; unauflösbar kleine Schritte liefern einen Präzisionsfehler.
Weitere Parser-/Kurven-/Rasterbudgets bleiben bestehen.

## Prüfung

SVGFill prüft Vererbung, ungültige Werte, gerichtete und paritätsbasierte Löcher,
deckungsgleiche Konturen und unabhängigen Stroke. Metriktests prüfen Schließen,
moveto, Null-/Prozentkalibrierung; Strichmustertests prüfen Wiederholung, Reset,
Null-Lücken, Nähte, Abbruch und Arbeitsbudget. Die drei tatsächlichen Tafeln
werden bei 240/480/960 px gerastert. Loch-/Insel-Pixel werden gezielt geprüft;
kalibrierte Linien sind pixelgleich, Kreise stimmen bis 1/255 pro Kanal überein.
Controller-/Ressourcenprüfungen laufen mit Mocks auch für S11.

Die lokale Vorschau aus tatsächlichen Luau-Pixeln wurde visuell kontrolliert;
sie ist kein Studio-/Browser-Screenshot.

SVG-/HTML-Suiten normal/-O2, Quellensynchronität, Projektaudit und drei Rojo-Builds
bestanden. Laufender Rojo-Server liefert S11-Konfiguration und Module.

- [x] Löcher, Sternmitte und innere Insel vergleichen.
- [x] Strichmuster der drei Linien und beiden Kreise vergleichen.
- [ ] Clientbericht: sechs Bilder, PixelReadback=true, keine Diagnosen.
- [ ] Größenwechsel und R im Client prüfen.

Referenzen: [SVG-Füllregeln](https://www.w3.org/TR/SVG2/painting.html#FillRuleProperty),
[pathLength](https://www.w3.org/TR/SVG2/paths.html#PathLengthAttribute).
