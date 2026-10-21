# S15 + S16 — CSS-Kaskade und wiederverwendbare Instanzen

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisiert geprüft und vom Nutzer visuell bestätigt („ja passt“).
Kein zusätzlicher Clientbericht; Größenwechsel/R nicht separat bestätigt.
S01–S16 sind bestätigt; für S14–S16 ohne zusätzlichen Clientbericht. Ab jetzt werden
auf Nutzerwunsch größere Etappenpakete zusammen bearbeitet.

## Vergleich

[Gemeinsame Browsertafel](../tests/fixtures/svg-regressions.zip), alternativ
[S15](../tests/fixtures/svg-regressions.zip) / [S16](../tests/fixtures/svg-regressions.zip).
StudioDemoConfig: ActiveDemo=SVGLab, SVGStage=S15_S16; Stop → Play.
1/2/3: 240/480/960 px, R: 20 Neuaufbauten. Erwartet sechs Tafeln, zwölf lebende
EditableImages. Zwei Diagnosen sind absichtlich eingebaut: missing-use-target
und cyclic-use-reference, beide in S16-external. Sonst keine Diagnosen erwartet.

1. CSS-Rangfolge: oben Rot / Blau / Grün / Orange; unten Orange / Blau / Grün / Grün.
2. Selektoren: oben vier grüne Kacheln. Elternfarbe Rot → Grün, feste blaue Kinder
   bleiben blau. Unten inherit / initial / unset / revert: Grün / Schwarz / Grün / Grün.
3. Nur Variablen, ohne Legacy-Ersatzregeln: Blau / Grün / Orange; Blau / Lila / Grün.
4. Ein Symbol, drei Größen/Farben. Unten xlink und Instanzvariablen: Lila / Orange / Lila.
5. Wiederverwendete Definition oben, veränderte Form unten. Gold bleibt fest;
   Instanzfarben bleiben Grün / Blau / Lila. Host-Selektoren dringen nicht in
   den use-Schattenbaum ein.
6. Lokaler/externer grüner Stern sind gleich. Unten werden die fehlende und
   zyklische Referenz ausgelassen; der gültige blaue Stern bleibt sichtbar.

sync-svg-styles-use.py erzeugt CSSSources, UseSources, StylesUseSources sowie drei
HTML-Seiten. Jede Browsertafel läuft in einem eigenen nativen SVG-Blob-Dokument
im iframe: Stylesheets können andere Tafeln nicht beeinflussen. Alte Blob-URLs
werden bei Neuaufbau freigegeben. Für den Dateibrowser wird die externe
Bibliotheksdefinition vor dem Vergleich lokal eingebettet, um file-URL-Sperren
zu vermeiden. Das ist eine visuelle Referenz der Definition, kein Nachweis
browserseitiger externer Dateiladung. Roblox erhält denselben Bibliotheksinhalt
über den expliziten Resolver.

## S15: CSS für den bisherigen SVG-Funktionsumfang

CSS/Selectors, Variables und AuthorRules sind Datenmodule und verwenden den
vorhandenen CSS/Syntax-Scanner. SVG/Style nutzt die bestehenden Paint-, Rendering-,
Transform- und Length-Validatoren. Das bestehende HTML-CSS-System bleibt erhalten.

Unterstützte Selektoren: Typ (SVG-Schreibweise), *, ID, Klassen, Nachfahren, Kinder,
benachbarte/allgemeine Geschwister; Attribut-Präsenz, =, ~=, |=, ^=, $=, *= und
Fallvergleich i/s; root, empty, first/last/only-child bzw. -of-type, nth-child/
nth-last-child/nth-of-type/nth-last-of-type mit An+B; is, where, not. Spezifität
von where ist null, is/not verwenden die höchste Argument-Spezifität. hover,
active, focus und focus-within können über options.States mit Quellknoten geprüft
werden. Die tatsächliche SVG-Mauseingabe wird hier noch nicht angeschlossen.

Präsentationsattribute, Stylesheets, Inlinewerte, !important, Spezifität und
Quellreihenfolge werden pro Eigenschaft geordnet. Ungültige normale Deklarationen
lassen frühere gültige Werte stehen. Ein erst nach var-Auflösung ungültiger
Gewinner wird dagegen unset; er fällt nicht auf die frühere Deklaration zurück.
inherit/initial/unset/revert und all sind für registrierte SVG-Eigenschaften
angebunden. Da Cascade Layers noch nicht unterstützt sind, ist revert-layer
außerhalb von Layers gleich revert.

Custom Properties sind namenssensitiv, erben berechnete Werte und unterstützen
verschachtelte Ersatzwerte und leere Ersatzwerte. Der Abhängigkeitsgraph umfasst
auch Referenzen in Ersatzwerten; Zyklen werden ungültig, gültige Ersatzwerte der
Verbraucher funktionieren weiter. Geerbte Aliaswerte werden nicht erneut gegen
geänderte Kindvariablen ausgewertet. Strings mit dem Text var() bleiben Strings.

Registriert sind die bisherige Füllung/Kontur, Rendering-Eigenschaften,
Transformationen, font-size und SVG2-Geometriegrößen x/y/cx/cy/r/rx/ry/width/height.
Geerbte absolute/fontbezogene Längen werden berechnet, Prozentbezüge bleiben
viewportbezogen. Neue Rendererfunktionen müssen ihre CSS-Eigenschaften hier
registrieren. Beispielsweise Text-/Fontfamilien, Gradient-/Filtereigenschaften
und CSS-d:path() gehören noch zu späteren bzw. offenen Anbindungen.

Nicht implementiert sind beliebige CSS4-Selektoren (z. B. has, Namespaceselektoren,
Escape-/Unicode-Identifier und nth-child(... of ...)), At-Regeln einschließlich
media/layer/import und registrierte Custom Properties. Unsupported-Regeln und
-Eigenschaften werden diagnostiziert. Diese Grenzen sind keine Einstufung als
in Roblox unmöglich und kein Anspruch auf einen vollständigen Browser-CSS-Parser.

## S16: Definitionen, Instanzen und Resolver

SVG/Document.prepare(document, options) erzeugt einen unabhängigen berechneten
Renderbaum; Quell-DOM und Definitionen bleiben unverändert. defs/symbol werden
nicht direkt gezeichnet. use kopiert unterstützte Grafik-/Gruppen-/SVG-/Symbol-
Ziele, übernimmt x/y, respektiert width/height für SVG-/Symbol-Viewports und führt
Instanzstil/Variablen als Vererbungsbasis zu. Definitionseigene Deklarationen
bleiben wirksam. Regeln werden an den ursprünglichen Definitionsknoten geprüft,
damit Host-Nachfahrenselektoren nicht versehentlich in Instanzen hineinwirken.

href hat Vorrang vor dem über Namespace aufgelösten xlink:href. Lokale IDs,
Fragment-Dekodierung und externe Dokumente mit optionalem Fragment werden
unterstützt. options.Resolve(url, baseURL) liefert einen SVG-String oder
{SVG=..., URL=...}; Dokumente werden während einer Aufbereitung gecacht.
Es gibt keinen automatischen Netzwerkzugriff. Der Laborresolver verwendet die
mitgelieferte Documents-Tabelle. Fehlende, ungültige oder zyklische Referenzen
werden isoliert diagnostiziert, gültige Nachbarn bleiben erhalten.

Änderungen werden durch erneutes prepare berücksichtigt. Tests ändern eine
Elternfarbe und eine Definition und prüfen alle betroffenen Instanzen. Bereits
vorbereitete Bäume bleiben unabhängige Momentaufnahmen. Automatische Live-DOM-
Beobachtung und allgemeine HTML-Paint-Anbindung sind weiterhin offen. Ebenso
bleiben SVG2-symbol-refX/refY, Text-/Bild-use-Ziele und aufwendigere Shadow-DOM-
Selektor-Sonderfälle spätere Restfälle.

## Prüfung und Budgets

StylesAndUse prüft Kaskade, Vererbung, ungültige Gewinner, Variables/Zyklen,
Selektoren, Instanzisolation, Quellunveränderlichkeit, Definitionsänderungen,
href/xlink, Resolver-Cache, Resolverfehler und relative Pfade. Die sechs Tafeln
werden bei 240/480/960 px gerastert: Gewinnerfarben werden gezielt geprüft;
lokaler und externer Stern stimmen bis auf einen 8-Bit-Quantisierungsschritt
überein. Ressourcenmocks decken 20 Auf-/Abbauzyklen des kombinierten Labors ab.
Die lokale Luau-Pixelvorschau wurde geprüft, kein Studio-/Browser-Screenshot.

Budgets: Stylesheets zusammen 1 MiB / 4096 Regeln, Selektoren 4096 Zeichen /
128 Teile / 16 Funktionsebenen; Variablen 64 Ersatzebenen, 256 Abhängigkeitsebenen,
65536 Zeichen pro Ergebnis und begrenzte Auswertungsschritte. use-Aufbereitung
ist auf 20000 Knoten / 128 Ebenen / 32 externe Dokumente begrenzt. Parser- und
Rasterbudgets bleiben bestehen. Keine dauerhaft geteilten Instanz-Caches.

- [x] Sechs Tafeln: visueller Vergleich vom Nutzer bestätigt.
- [ ] Bericht: zwölf Bilder, PixelReadback=true, nur die zwei vorgesehenen Diagnosen.
- [ ] Größenwechsel und R im Client prüfen.

Referenzen: [SVG-Styling](https://www.w3.org/TR/SVG2/styling.html),
[CSS-Variablen und Zyklen](https://www.w3.org/TR/css-variables-1/#cycles),
[SVG use](https://www.w3.org/TR/SVG2/struct.html#UseElement).
