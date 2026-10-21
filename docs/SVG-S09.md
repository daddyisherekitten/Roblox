# S09 — Bézierkurven

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und vom Nutzer visuell bestätigt.
S01–S09 sind vom Nutzer bestätigt.

Abnahme am 13.09.2026: „passt weiter“. Clientbericht: Width=480, UIScale=1,
Viewport=1319×619, Created=6, Live=6, Destroyed=0, Peak=6, Cycles=1,
Kind=ready, PixelReadback=true, Diagnostics=[].
SourceSHA256: 0af51ce439c2885421e3daf1efd36433a55a0c22060c3e8117f32e2f54be18a3.
Das automatische StudioVisualComparison=pending wird durch diese manuelle
Bestätigung ergänzt. Größenwechsel und R nicht separat bestätigt.

## Vergleich

[Browsertafel](../tests/fixtures/svg-regressions.zip). StudioDemoConfig: ActiveDemo=SVGLab,
SVGStage=S09; Stop → Play. 1/2/3: 240/480/960 px, R: 20 Neuaufbauten.
Erwartet werden drei Tafeln, sechs lebende EditableImages und keine Diagnosen.

1. C, C/S, Q und Q/T mit grauen Kontrollpolygonen und dunklen Kontrollpunkten.
   Bei S/T sind auch die gespiegelten Punkte eingezeichnet. Die Kurven müssen
   durch ihre Endpunkte laufen; Kontrollpunkte müssen nicht auf der Kurve liegen.
2. Links explizite absolute Kontrollpunkte, rechts relative Kurzschreibweise
   mit gespiegelten Punkten. Die beiden Kurven jeder Zeile müssen gleich aussehen.
3. Geschlossene Schleife mit gleichem Anfang/Ende, kollinearer Richtungswechsel,
   S/T nach einem Linienbefehl. Eine zusätzliche Kurve ohne Ausdehnung bleibt
   mit den aktuellen butt-Kappen unsichtbar.

Die SVG-Dateien laufen unverändert in Browser und Labor; Synchronisierung über
scripts/sync-svg-curves.py nach SVGLab/CurveSources und s09.html.

## Umsetzung und Grenzen

Path verarbeitet C/c, S/s, Q/q und T/t einschließlich wiederholter Parametersätze.
Relative Kontrollpunkte beziehen sich auf den Anfang des jeweiligen Segments.
S spiegelt nur nach C/S, T nur nach Q/T. Sonst liegt der implizite Kontrollpunkt
am aktuellen Punkt. Linien, moveto und closepath setzen die Spiegelung zurück.
Unvollständige Parametersätze werden nicht teilweise übernommen; vollständige
vorherige Segmente bleiben erhalten. Explizite, relative und gespiegelte Punkte
werden auf das bestehende Koordinatenbudget geprüft.

Kontrollpunkte bleiben im Parse-Ergebnis erhalten. Curves.flatten erzeugt erst
beim Rendern die Polylinien: quadratische Kurven werden geometrisch gleichwertig
kubisch dargestellt, anschließend per de Casteljau geteilt. Die Distanz der
Kontrollpunkte zur endlichen Sehne begrenzt die Abweichung; der Bezug auf die
endliche Strecke verhindert, dass kollineare Umkehrungen oder geschlossene
Schleifen als einfache Verbindung verloren gehen.

Toleranz der Kurvenmittellinie: 0,125 Ausgabepixel. Die vorhandene positive
Viewportskalierung und gewählte Rastergröße fließen ein. Größere Ausgaben
erhalten daher mehr Unterteilungen. Allgemeine Transformationen folgen in S13.
Die Konturzeichnung benutzt weiterhin die S06-Strichapproximation; vollständige
Kappen/Verbindungen folgen in S12. Die Toleranz ist keine Zusage bitidentischer
Browser-Kantenglättung oder eines identischen breiten Kurven-Stroke.

Grenzen: maximal 20 Unterteilungsebenen und 16384 ausgegebene Punkte pro Pfad.
Bei Überschreitung wird die Arbeit mit ausdrücklichem Budgetfehler beendet,
statt still eine zu grobe Kurve auszugeben. Abbruchprüfungen erfolgen pro Teilpfad
und nach jeweils 64 Unterteilungsschritten. Parsedaten bleiben unverändert.
Die vorhandenen Parser-/Rasterbudgets gelten zusätzlich.

Elliptische Bögen folgen in S10; CSS-d und allgemeine HTML-Paint-Anbindung bleiben
offen. Dieses Stadium zeichnet die Kurven im eigenständigen SVG-Vergleichslabor.

## Prüfung

SVGCurves prüft alle neuen Befehle, relative/repetierte Parameter, Spiegelungen,
Resets nach Linien/M/Z und Wechsel zwischen kubischen/quadratischen Kurven,
unvollständige Befehle und Kontrollpunktgrenzen. Analytische Bézierwerte werden
an 1001 Stellen mit den erzeugten Polylinien verglichen, bei vier Skalierungen,
auch für Schleifen und kollineare Umkehrungen. Weitere Prüfungen: quadratischer
Scheitel, Nullkurven, Abbruch und expliziter Unterteilungsbudgetfehler.

Die expliziten und kurzen Kurven werden bei 240/480/960 px pixelweise verglichen
(höchstens 1/255 Kanalabweichung); alle drei Tafeln laufen durch den tatsächlichen
Rasterkern. Controller-/Ressourcenprüfungen mit Mocks laufen auch für S09.
Die lokale Vorschau aus tatsächlichen Luau-Pixeln wurde visuell kontrolliert;
sie ist kein Browser- oder Studio-Screenshot.

SVG-/HTML-Suiten normal/-O2, Quellensynchronität, Projektaudit und drei Rojo-Builds
bestanden. Laufender Rojo-Server liefert S09-Konfiguration und Module.

- [x] Kontrollpunkte, Endpunkte und glatte Anschlüsse vergleichen.
- [x] Explizite/kurze Kurven sowie Schleifen und Umkehrungen vergleichen.
- [x] Clientbericht: sechs Bilder, PixelReadback=true, keine Diagnosen.
- [ ] Größenwechsel und R im Client prüfen.

Referenz: [SVG 2 — Bézier path commands](https://www.w3.org/TR/SVG2/paths.html#PathDataCubicBezierCommands).
