# S39/S40: SVG-Animation und Pfadbewegung

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Stand 14.09.2026. S37/S38 einschließlich Hitbox-, Browser- und Performancekorrekturen
vom Nutzer mit „perfekt alles passt weiter“ freigegeben. S39/S40 sind im unten
beschriebenen Teilumfang implementiert. Der native Browser-/Studio-Vergleich
ist noch offen; keine gemessene Studio-Bildrate.

## Vergleich

StudioDemoConfig: `S39_S40`, Stop → Play. Browser:
[acht Animationstafeln](../tests/fixtures/svg-regressions.zip), alternativ
[S39](../tests/fixtures/svg-regressions.zip) / [S40](../tests/fixtures/svg-regressions.zip).
Beide beginnen pausiert bei 0 s. P startet/pausiert. Z/X/C/V/B setzt
0/.25/.5/.75/1 s. R setzt Zeit, Ereignisse und Zustände zurück.
1/2/3 setzt die Tafelbreite auf 240/480/960 px.

| Tafel | Sichtprüfung |
|---|---|
| Werte | Rechteck folgt Zeitmarken; Kreis wächst und wird rot; grünes Feld wird transparent. |
| Transformationen | Translation, Rotation, Skalierung und skewX um graue Ursprünge. |
| Interpolation | Linear, diskret und Spline bei .25/.75 s vergleichen. |
| Wiederholung | .4 s × 2.5; bei 1 s oben Basiswert, Mitte halber Durchlauf eingefroren, unten aufsummiert; gelbes set-Feld ab .5 s. |
| Pfadbewegung | Pfeil dreht entlang der Kurve; „Pfad wechseln“ aktualisiert mpath-Geometrie. |
| KeyPoints | Bei .5 s oben 50 %, unten 80 % Weg; unterer Pfeil zeigt rückwärts. |
| Ereignisse | P starten, dann Start: Blau läuft .5 s, Grün beginnt .1 s danach und läuft .4 s. R löscht Starts. |
| CSS | Oberer Kreis folgt Keyframes; untere Hover-Transition läuft auch bei pausierter SVG-Zeit. |

Native SVGs und CSS-Keyframes bleiben im Browser erhalten. Getrennte srcdoc-Frames
besitzen ihre eigene Ereignislogik. Die übergeordnete Uhr setzt setCurrentTime
und die currentTime nativer CSSAnimation-Instanzen. CSS-Transitions bleiben an
der Echtzeituhr. Quellen/Fonts stammen aus `scripts/sync-svg-animation.py`.

## Umsetzung und Grenzen

- `AnimationTiming`: Uhren, begin/end, repeatCount/repeatDur, freeze/remove,
  lineare/diskrete/pace-/Spline-Interpolation, Restart-Auswahl.
- `AnimationValue`: Zahlen/Längen, RGBA, kompatible Zahlenlisten und Pfaddaten.
- `Animation`: animate, animateColor, set, animateTransform, additive/by und
  numerisches accumulate; animateMotion mit path/mpath, rotate, keyPoints;
  Ereignisstarts und einfache begin/end-Syncbases. Basis-DOM bleibt unverändert.
- `AnimationCSS`: einzelne benannte Keyframe-Animation über Langformen,
  Richtung/Wiederholungen/Delay/Fill/Play-State; Property-Transitions mit einer
  Dauer und Easing sowie Unterbrechung vom aktuellen Wert.
- Session sampelt getrennte animierte Werte; Document übernimmt sie auch in
  Ressourcen. Der Lab-Host nutzt eine Uhr, aktualisiert sichtbare Tafeln maximal
  30-mal/s, bündelt Arbeit und verwendet bestehende EditableImages. Rasterarbeit
  darf über mehrere Frames laufen; dies garantiert keine 30 FPS in Studio.
  Unveränderte eingefrorene Bilder werden nicht neu gerastert. Instanz-/Event-
  Historien sind auf 256 Einträge begrenzt, Tracks auf 256.

Offen, ausdrücklich kein vollständiger S39/S40-Abschluss:

- Vollständige SMIL-Intervallauflösung: min/max, repeat(n)/accessKey/wallclock,
  Syncbase-Enden bei unterbrochenen Intervallen und alle Restart-/End-Kombinationen.
- Motion über from/to/by/values, Motion-accumulate und vollständige Pfad-Ecksemantik.
- Transform-Matrixzerlegung, gemischte Einheiten/abweichende Pfadstrukturen,
  Farbinterpolation in allen Farbräumen und alle additiven Datentypen.
- Prozent-/Fontkontexte verschachtelter Viewports: Animation verwendet derzeit
  den 480×320-Lab-Kontext; allgemeine HTML-Einbettung bleibt S43.
- CSS-Shorthands, mehrere Animationen/Dauerlisten, Keyframe-Variablen,
  Transition-Reverse-Verkürzung, vollständige Cascade-Priorität einschließlich
  !important/SMIL/CSS-Mischung, animation-/transition-Events und Web Animations API.
- Vererbung gleichzeitig animierter Werte in der zugrunde liegenden
  Animationsberechnung sowie Animationen innerhalb use-Instanzen.
- JavaScript-Ausführung ist weiterhin nicht implementiert. Die Uhr- und
  Pfadaktionen des Roblox-Labors sind Luau-Callbacks.

## Prüfung

- SVG-Suite normal und -O2: Uhren, Seek/Freeze, Wiederholungsgrenzen, Werte,
  Transform/Addition, dynamischer mpath, Click-/Syncbase-Starts, CSS-Keyframes,
  Transition-Ende, ungültige keyTimes und begrenzte Start-/End-Historien.
- Hosttest: pausierte Uhr ohne Raster, Play/Pause, feste Zeitpunkte, Reset,
  Aufräumen während Rasterarbeit; S37/S38-Regression bleibt aktiv.
- `node scripts/test-svg-animation-browser.cjs`: generierte Skripte in Node mit
  expliziten DOM-Mocks; Frame-Start, gemeinsame Uhr, native API-Aufrufe, Pfadwechsel,
  Quellenprüfung der Nachrichten. Kein automatisierter nativer Browsertest.
- Acht tatsächliche Luau-Rastertafeln bei .5 s als Montage geprüft:
  `build/svg-s39-s40-preview.png`.
- HTML-Regression, Projektprüfung, Generator-Abgleich und drei Rojo-Builds.

Nächster Schritt nach Nutzervergleich: S41/S42. Die obigen Restfunktionen bleiben
bis zur abschließenden Supportmatrix offen und dürfen nicht als fertig gelten.
