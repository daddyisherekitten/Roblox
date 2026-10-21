# S03 — SVG als HTML-Layoutbox

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und am 13.09.2026 vom Nutzer visuell bestätigt ("Sieht gut aus").
Clientbericht bei 480 px: neun Boxen, keine Diagnosen, Cycles=1. Gemeldete
GUI-Maße: 120×48, 180×60, 227×56, 180×60, 160×40, 227×50, 300×150,
200×50 und 0×0. Die relative Höhe wird intern mit 56,75 berechnet; der Client
meldet für AbsoluteSize 56. Der visuelle Vergleich wurde trotzdem bestätigt.
Separate 1/2/3- und R-Ergebnisse wurden nicht übermittelt.
S01/S02 sind vom Nutzer bestätigt.

## Vergleich starten

Browser: [S03](../tests/fixtures/svg-regressions.zip). StudioDemoConfig: ActiveDemo=SVGLab,
SVGStage=S03, dann Stop → Play. 1/2/3 wählen 240/480/960 px HTML-Breite.
R führt 20 vollständige PageSession-Lebenszyklen aus. Größenwechsel verwenden
vorhandene GUIs; die Seite wird dafür nicht neu gemountet.

Der Browser lädt S03-embedding.html in einen automatisch hohen iframe. Studio
verwendet exakt dessen Quelltext über EmbeddingSource.luau und die echte HTMLPage.
Der Studiotarget erhält 10 zusätzliche Pixel für den vorhandenen Scrollbalken,
damit die verfügbare HTML-Breite dem iframe entspricht. Keine globale Änderung
der Scrollbardicke. Die 100-Pixel-Messlinie gehört zur Laborhülle.

Acht Tafeln, neun SVG-Boxen:

1. Inline: rote Box 120×48 zwischen Vor/Nach, Folgezeile und zwei Höhenmarken.
2. Block: blaue Box 180×60 zwischen Vorher/Nachher ohne zusätzliche Inline-Unterlänge.
3. 50 % Breite mit viewBox-Verhältnis 4:1. Bei 480 px Laborbreite: 227×56,75.
4. Nur intrinsisches viewBox-Verhältnis 3:1 im 180-px-Container: 180×60.
5. CSS überschreibt width/height-Attribute: 160×40 statt 300×100.
6. 50 % Höhe in explizit 100 px hohem Elternblock: 50 px.
7. Ohne Maße/Verhältnis: 300×150; Überstand bei schmalem Fenster ist beabsichtigt.
8. max-width:200px mit Verhältnis 4:1 und unsichtbare Nullgröße; Abschluss nur einmal.

Die farbigen Flächen sind die CSS-Hintergründe der SVG-Viewportboxen. SVG-Kinder
bleiben im DOM und erzeugen keine HTML-Text-/Blockfragmente. Diese Etappe zeichnet
noch keine allgemeinen SVG-Formen; viewBox liefert hier ausschließlich das
intrinsische Seitenverhältnis, die Koordinatentransformation folgt in S04.

## Implementierung und Grenzen

HTML/Parser erkennt einen SVG-Fremdinhaltsbereich, erhält die Unterstruktur und
respektiert dort selbstschließende Tags. Er weist SVG-Namensräume zu und korrigiert
viewBox/preserveAspectRatio aus der HTML-Tokenisierung. Der eigenständige strikte
S02-XML-Parser bleibt separat. Die vollständige HTML-Foreign-Content-Fehlerkorrektur,
HTML-Integrationspunkte in foreignObject/title/desc und sämtliche SVG-Namens-
korrekturen sind noch nicht implementiert. Sie zählen nicht als S03-Support.

CSS/InlineStyle behandelt width/height als Präsentationshinweise vor Autoren-CSS.
Vorhandene CSS-Längen, Prozentmaße, min/max, aspect-ratio, box-sizing und vertikale
Inline-Ausrichtung werden wiederverwendet. SVG/Sizing bestimmt natürliche Maße
und gültige viewBox-Verhältnisse. ImageLayout/BlockImage/WordLayout übernehmen
Boxränder, Baseline, Zeilenumbruch und Reflow. RenderTree erstellt eine einzelne
ersetzte Box pro SVG, ohne ImageLoad, Alt-Ersatz oder externe Assetabfrage.

S03 betrifft Inline-/Blockfluss im bestehenden HTML-Teilumfang. Allgemeine SVG-
CSS-Vererbung, Geometrie/Paint und Transformationen sind spätere Etappen; ebenso
extern eingebundene SVG-Dateien über img/object und SVG-foreignObject. Bestehende
HTML-Grenzen für Positionierung und komplexe CSS-Längen bleiben bestehen.

## Prüfung

SVGEmbedding.luau prüft Parsergrenze, Attribute/CSS, Maße, Nullgrößen, Seiten-
verhältnis, Min/Max, Prozenthöhen, Inline-Grundlinie/Umbruch und Folgeposition.
Zusätzlich läuft die unveränderte echte Vergleichsdatei durch den Renderer und
mehrere Layoutgrößen: neun Boxen, richtige Maße, keine neu angelegten GUIs.
SVGEmbeddingController.luau prüft den echten Laborcontroller mit gemockter
PageSession: 20 Wechsel, alte Seite zuerst freigeben, doppelte Statusereignisse,
Resize ohne Mount sowie Abbau bei wartendem Neuaufbau. Kein Studio-Renderingtest.

SVG_S03_REPORT enthält Boxgrößen, HTML-Breite, Quelldigest, Durchlauf und Diagnosen.
StudioVisualComparison bleibt automatisch pending, bis der Nutzervergleich
separat dokumentiert wird. Diese Etappe benötigt keine EditableImages.

- [x] Acht Tafeln und Folgezeilen stimmen mit dem Browser überein.
- [ ] 1/2/3: richtige Breiten und Umbrüche, keine doppelten Inhalte.
- [ ] R: am Ende weiterhin neun SVG-Boxen, ein sichtbarer Abschluss.

Referenzen: [SVG intrinsische Maße](https://www.w3.org/TR/SVG2/coords.html#IntrinsicSizing),
[CSS ersetzte Elemente](https://www.w3.org/TR/CSS2/visudet.html#inline-replaced-width).
