# SVG-Gesamtplan mit visuellen Vergleichstests

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

> Detaillierter SVG-Fachplan S01–S45. Den dokumentierten Bestand und offene Grenzen führt [SVG-SUPPORT](SVG-SUPPORT.md); gemeinsame Arbeitsregeln stehen ausschließlich in [PLAN](../PLAN.md). Datierte Etappen-/Demoangaben sind kein neuer Auftrag.

Stand: 14.09.2026. Status: **S01–S44 im dokumentierten Teilumfang zum Fortfahren freigegeben; S45-Vergleichsbilder implementiert, visueller Vergleich offen. Frühere Restfunktionen bleiben offen.**
S02-Bedienung und Teilumfang: [SVG-Dokumentstruktur](SVG-S02.md).
Bedienung, technische Ergebnisse und Abnahmeprotokoll: [S01-Labor](SVG-S01.md).
S03-Bedienung und Teilumfang: [SVG im HTML-Layout](SVG-S03.md).
S04-Bedienung und Teilumfang: [SVG-Viewports](SVG-S04.md).
S05-Bedienung und Teilumfang: [Längeneinheiten](SVG-S05.md).
S06-Bedienung und Teilumfang: [Grundformen](SVG-S06.md).
S07-Bedienung und Teilumfang: [Füllung und Kontur](SVG-S07.md).
S08-Bedienung und Teilumfang: [Gerade Pfade](SVG-S08.md).
S09-Bedienung und Teilumfang: [Bézierkurven](SVG-S09.md).
S10-Bedienung und Teilumfang: [Elliptische Bögen](SVG-S10.md).
S11-Bedienung und Teilumfang: [Füllregeln und Pfadlänge](SVG-S11.md).
S12-Bedienung und Teilumfang: [Konturen und Strichmuster](SVG-S12.md).
S13-Bedienung und Teilumfang: [Transformationen](SVG-S13.md).
S14-Bedienung und Teilumfang: [Zeichenreihenfolge und Deckkraft](SVG-S14.md).
S15/S16-Bedienung und Teilumfang: [CSS und Instanzen](SVG-S15-S16.md).
S17/S18-Bedienung und Teilumfang: [Farbverläufe](SVG-S17-S18.md).
S19/S20-Bedienung und Teilumfang: [Muster und Marker](SVG-S19-S20.md).
[S21/S22 Bilder und Ausschnitte](SVG-S21-S22.md) sind visuell bestätigt.
[S23/S24 Masken und Mischmodi](SVG-S23-S24.md) sind visuell bestätigt.
[S25/S26 Text und Typografie](SVG-S25-S26.md): acht Vergleichstafeln, allgemeine Fontkonturen und lateinisches Layout implementiert. Vollständiges Bidi, komplexes GSUB/GPOS-Shaping, mehrzeiliges/vertikales CJK-Layout und weitere im Protokoll benannte Funktionen bleiben offen; S26 ist nicht vollständig erledigt. S27/S28 siehe aktuellen Stand unten; S29–S42 sind im dokumentierten Teilumfang implementiert; S43/S44 sind im dokumentierten Teilumfang implementiert; S45-Kombinationsbilder und Supportkatalog sind implementiert, ihre visuelle Abnahme bleibt offen. S20-Rest: Marker mit non-scaling-stroke. Weiterhin auf Nutzerwunsch größere Etappenpakete. Die SVG2-Erweiterungen miter-clip/arcs bleiben
als gesonderter S12-Restumfang offen; Standard-Kappen und miter/round/bevel sind implementiert.
Dieser Plan ersetzt die Ausrichtung auf ein einzelnes Blumenbeispiel. Ziel ist
ein allgemeiner SVG-Renderer für alles, was wir in Roblox sinnvoll implementieren
können. Die Blume ist später ein Integrationstest unter mehreren.

Aktuell: [S45 Gesamtabgleich](SVG-S45.md) und [Supportkatalog mit Restarbeiten](SVG-SUPPORT.md).
S43/S44-Rest: gemeinsame HTML/SVG-Cascade, DOM-/Animationsintegration, Geometriecache, Kachelung und echte Gerätebudgets; Details im Etappenprotokoll.
S41/S42-Rest: vollständiges ECMAScript/DOM, erweiterte Fragmente, xml:base und Legacy-Funktionen; expliziter Audit im Etappenprotokoll.
S39/S40-Rest: vollständige SMIL-Intervalle, CSS-Mehrfachanimation/Shorthands, Cascade, Motion-accumulate und allgemeine Viewportkontexte; Details im Etappenprotokoll.
S37/S38-Rest: vollständige Pointer-/DOM-API, use-Retargeting, verschachtelte CTM-Semantik und HTML-Integration.
S36-Rest: Text-Trefferzellen und Unterdokument-/use-Retargeting.
S33-Rest: feImage mit lokalen/externalen SVG-Verweisen. S34-Rasterparität noch visuell abgleichen.
S29/S30 nach korrigierter direkter Filterreferenz zum Fortfahren freigegeben.
Textschatten sind integriert. EdgeMode duplicate/wrap, außerhalb der Textur
liegende Quellpixel, automatische Umbrüche, komplexe Textfälle und foreignObject
bleiben offen. Lighting-Primitive in S35 implementiert; Zustände/Eventpfade sind in S37 im protokollierten Teilumfang implementiert.

## Was „fertig“ bedeutet

Jede unten aufgeführte Funktion erhält am Ende einen überprüften Status:

- **Unterstützt:** spezifiziertes Verhalten implementiert, automatisierte Prüfung
  und visueller Browser-/Studio-Vergleich bestanden.
- **Mit Grenze unterstützt:** implementiert, konkrete Grenze und sichtbarer
  Unterschied dokumentiert und durch einen eigenen Test belegt.
- **Plattformabhängig:** funktioniert nur mit angegebenen Assets, Fontdaten oder
  Diensten; diese Voraussetzung und der Fehlerfall sind getestet.
- **Nicht verfügbar:** ein konkreter Roblox-API-/Plattformgrund wurde untersucht,
  Alternativen wurden geprüft und das Ergebnis ist belegt. Aufwand allein ist
  kein Grund, eine Funktion als unmöglich zu markieren.

„Geplant“, „untersucht“ und „nur im Mock bestanden“ zählen nicht als abgeschlossen.
Keine pauschale Zusage vollständiger Browserkompatibilität: APIs, Fontdaten,
Rechenzeit und Speicher müssen im echten Roblox-Client geprüft werden.
Alte SVG-1.1-Funktionen und experimentelle SVG-Entwürfe werden gesondert bewertet;
sie werden nicht stillschweigend dem stabilen Funktionsumfang zugerechnet.

## Ein gemeinsamer visueller Testaufbau

**S01 baut das Testlabor; die folgenden Tests entstehen jeweils mit der Funktion.**
Die unten genannten Tests sind Spezifikationen, noch keine vorhandenen Testdateien.

- Eigenes SVG-Testlabor neben der bisherigen HTML-Demo. Eine Etappe auf einmal
  anzeigen; abgeschlossene Vergleichsbilder bleiben als Regressionen gespeichert.
- Testdaten künftig unter `examples/svg-tests/`, ein Fall pro Datei/ID. Derselbe
  SVG-/CSS-Inhalt läuft unverändert im Browser und durch unsere Roblox-Engine.
  Roblox-spezifische Assetzuordnung gehört ausschließlich in die Testumgebung.
- Standardtafel: 480 × 320 CSS-Pixel, weißer Hintergrund, 100-Pixel-Messlinie und
  beschriftete Prüfpunkte außerhalb des getesteten SVG. Referenzraster optional.
  Transparenztafeln bekommen ein Schachbrett hinter dem SVG.
- Browserzoom 100 %, Roblox-UIScale 1; Betriebssystemskalierung, Screenshotmaßstab,
  Fontfamilie und Viewport dokumentieren. CSS-Pixel nicht blind mit Screenshot-
  Pixeln gleichsetzen; zuerst die Messlinie abgleichen.
- Jede Tafel zeigt nur wenige große Beispiele: Grundfall, Grenzfall und eine
  Kombination. Keine unleserliche Sammlung winziger Icons.
- Geometrie zusätzlich bei 240 × 160 und 960 × 640 prüfen. Nichtuniforme Größen
  bekommen eigene Fälle. Die Größe bezeichnet die Testfläche, nicht eine Zusage
  über die spätere interne Texturauflösung.
- Vergleiche: nebeneinander, bei Bedarf 50-%-Überlagerung und Differenzbild aus
  gleich skalierten Aufnahmen. Beide Einzelbilder bleiben sichtbar; eine
  automatische Differenz darf Font- und Antialiasingabweichungen nicht verbergen.
- Interaktive Tests haben eine genaue Folge von Zielpunkten/Klicks. Animationen
  zusätzlich bei fest angehaltenen Zeitpunkten prüfen, nicht nach Augenmaß starten.
- Falls der Referenzbrowser eine Funktion nicht unterstützt: zweiten Browser
  bzw. geeigneten Konformitätstest und mathematische Sollwerte verwenden. Ein
  leerer Browserbereich gilt nicht als erwartetes Ergebnis.

### Prüfkriterien je Etappe

1. Geometrie und Zustand stimmen; keine fehlenden Formen, falschen Überlagerungen
   oder falschen Trefferflächen. Harte Achsenkanten passen beim 1:1-Vergleich auf
   denselben Pixel. Rechenwerte separat mit numerischer Toleranz prüfen.
2. Vollflächige Farben/Alpha numerisch prüfen. Kurven-Antialiasing, Fontmetriken
   und Filter-Näherungen getrennt bewerten; keine großzügige Gesamttoleranz, die
   einen Positionsfehler verdeckt. Konkrete Toleranzen mit dem jeweiligen Test
   festlegen und protokollieren, bevor dessen Implementierung abgenommen wird.
3. Automatisierte Tests decken Syntax, Grenzwerte und relevante Kombinationen ab.
   Sie ersetzen nicht den visuellen Studio-Test.
4. Codeprüfung, Testlauf und betroffene Rojo-Builds bestehen. Bereits bestätigte
   Kalibrierungen werden nicht für einen neuen SVG-Test global verstellt.
5. Testprotokoll enthält Version, Browser, Gerät, Soll/Ist, Bilder, Ergebnis und
   verbleibende Grenzen. Erst dann wird die nächste abhängige Etappe freigegeben.

## A — Fundament und frühe Machbarkeit

| ID | Umsetzung | Visueller Test und erkennbare Abnahme |
|---|---|---|
| S01 | Testlabor und Plattformproben: passive Ausgabe, Pixelbuffer, Alpha, Größenwechsel, Lebenszyklus; separat Font-/Text-Rasterzugang untersuchen. | Vier Farbfelder, transparente Diagonale, Messlinie. 20-mal neu öffnen/schließen. Zusätzlich denselben Text normal, gedreht und hinter einer Kreis-Maske als Machbarkeitsziel zeigen. Festhalten, ob Text nur als Label oder auch als Pixel/Outline verfügbar ist. Kein Masken-Test als bestanden melden, solange Text nur darübergelegt wird. |
| S02 | SVG-Parsing und Dokumentstruktur: svg/g/defs, Namensräume, IDs, Attribute, title/desc/metadata, Fehlerdiagnosen. | Drei verschachtelte Gruppen mit farbigen Rechtecken; eine ausschließlich in defs gespeicherte Form bleibt unsichtbar. Metadaten erscheinen nicht als Seitentext. Falsches Markup zeigt eine Diagnose neben einem weiterhin sichtbaren gültigen Nachbar-SVG. |
| S03 | SVG als HTML-Layoutbox: feste/relative Größen, intrinsische Maße, Seitenverhältnis, Inline-/Blockeinbettung und Resize. | SVG zwischen zwei Textzeilen und in einem schmalen Container; Marken vor/nach der Box. Beim Resize stimmen Boxmaße und Position der Folgezeile, ohne doppelte Inhalte. |
| S04 | viewBox, negativer Ursprung, preserveAspectRatio mit allen Ausrichtungen, meet/slice/none; verschachtelte Viewports. | Kreis mit vier verschiedenfarbigen Eckmarken in quadratischen, breiten und hohen Rahmen. meet zeigt Freiräume, slice beschneidet die richtigen Marken, none ergibt eine Ellipse. Negativer Ursprung verschiebt keinen Mittelpunkt. |
| S05 | Koordinaten, Prozentbezüge und Längeneinheiten, Null-/negative/ungültige Maße. | Drei Lineale und identische Formen mit verschiedenen Einheiten; Prozentkreis in nichtquadratischem Viewport. Sollpositionen beschriften. Unsichtbare Nullgrößen dürfen Nachbarn nicht beschädigen. |

## B — Geometrie und Zeichnen

| ID | Umsetzung | Visueller Test und erkennbare Abnahme |
|---|---|---|
| S06 | rect, circle, ellipse, line, polyline, polygon; Rechteckradien rx/ry. | Sechs große Grundformen mit markierten Mittelpunkten und Begrenzungen. Rechtecke mit getrennten Radien und ein offener Linienzug zeigen Rundung und fehlenden Abschluss eindeutig. |
| S07 | fill, stroke, none, currentColor, fill-/stroke-opacity, Darstellungsattribute und Standardwerte. | Matrix aus gefüllt, nur umrandet, halbtransparent und unsichtbar. Auf Schachbrett prüfen: transparente Farben erzeugen keinen dunklen Saum. |
| S08 | Pfadsyntax M/L/H/V/Z, absolute/relative Werte, wiederholte Parameter und mehrere Teilpfade. | Dasselbe Haus einmal mit Grundformen und zweimal mit Pfaden. Überlagerung muss deckungsgleich sein; offener und geschlossener Pfad unterscheiden sich nur an der vorgesehenen Schlusskante. |
| S09 | Kubische und quadratische Kurven C/S/Q/T; adaptive Unterteilung. | Vier Kurven mit Kontrollpunkten und Vergleichspfaden. Gespiegelte Anschlusskurven haben keinen Knick; 2×-Ansicht zeigt keine groben Polygonsegmente. |
| S10 | Elliptische Bögen A/a, Radiuskorrektur und Sonderfälle. | Vier Bögen zwischen denselben Endpunkten für large-arc/sweep-Kombinationen, dazu gedrehte Ellipse und Radius 0. Richtung und großer/kleiner Bogen sind sofort unterscheidbar. |
| S11 | fill-rule nonzero/evenodd, Löcher, Selbstüberschneidungen, Pfadrichtung und pathLength. | Donut, Stern und verschachtelte Rechtecke, jeweils mit beiden Füllregeln. Schachbrett muss in genau den vorgesehenen Löchern sichtbar bleiben. Gleiche Strichmuster mit unterschiedlich kalibrierter Pfadlänge. |
| S12 | Vollständige Konturen: linecap, linejoin, miterlimit, dasharray/dashoffset und kurze/degenerierte Segmente. | Dicke Linienenden nebeneinander, spitzer Zickzack, gestrichelter Kreis mit Startmarke. Kappen, abgeschnittene Spitzen und Strichversatz stimmen; keine Zufallspixel bei Nullsegmenten. |
| S13 | Transformationen translate/scale/rotate/skew/matrix, Reihenfolge, Verschachtelung, transform-origin/box, non-scaling-stroke. | Asymmetrisches F mit Pivotkreuz und Transformationsgitter. rotate→translate unterscheidet sich korrekt von translate→rotate. Zwei skalierte Kreise zeigen normale und konstante Konturdicke. |
| S14 | Zeichenreihenfolge, paint-order, display/visibility/overflow, echte Gruppen-Opacity, Rendering-Hinweise. | Überlappende Rot-/Blauformen einmal pro Element und einmal als transparente Gruppe; die Überlappung muss unterschiedlich aussehen. Dicke Kontur über/unter Füllung und abgeschnittenes Randobjekt daneben. |

## C — CSS, Wiederverwendung und Farbe

| ID | Umsetzung | Visueller Test und erkennbare Abnahme |
|---|---|---|
| S15 | Vollständige CSS-Anbindung an SVG: Stylesheets/Inline/Präsentationsattribute, Vererbung, Selektoren, !important, CSS-weite Werte, Custom-Properties/var inklusive Ersatzwerten/Zyklen. | Farbkacheln mit beschrifteter erwarteter Siegerfarbe. Elternfarbe ändern; nur erbende Kinder wechseln. Separater var-Test ohne Legacy-Regeln verhindert zufälliges Bestehen. |
| S16 | defs/symbol/use, href/xlink-Kompatibilität, Instanz-Stile, externe Referenzen über Resolver und Zyklusbehandlung. | Ein Pfeilsymbol in drei Größen/Farben. Definition ändern und alle Instanzen vergleichen; Instanzstil darf Nachbarinstanzen nicht ändern. Fehlende/zyklische Referenz lässt gültige Symbole sichtbar. |
| S17 | linearGradient: stops, Alpha, gradientUnits/Transform, spreadMethod und referenzierte Verläufe. | Horizontaler RGB-Verlauf mit Stopplinien; daneben gedreht, halbtransparent und pad/repeat/reflect. Farben an festen Prüfpunkten vergleichen. |
| S18 | radialGradient: Mittelpunkt, Fokus, innerer/äußerer Radius, Transformation und Einheiten. | Kugelartige Kreise mit zentralem/versetztem Fokus, elliptisch transformierter Verlauf und harter Stopkante. Das Glanzzentrum liegt auf derselben Marke. |
| S19 | pattern: Kachel-/Inhaltseinheiten, Transformation, viewBox, Wiederverwendung und verschachtelte Inhalte. | Schachbrett, diagonale Streifen und Punkte in zwei unterschiedlich großen Formen. Nahtstellen und Phasenlage stimmen, beim Resize wandert keine Kachel unerwartet. |
| S20 | marker-start/mid/end, Bezugspunkt, Größe, Orientierung und Kontextfarben. | Pfeile auf Gerade, Zickzack und Kurve mit verschiedenen Strichstärken. Spitzen sitzen an Endpunkten, Mittelmarker drehen richtig; umgekehrte Richtung gesondert. |
| S21 | image: Assetresolver, Seitenverhältnis/Zuschnitt, Transformation, Alpha und referenziertes SVG. | Eigenes transparentes Bild mit vier verschiedenfarbigen Ecken in drei Ausschnitten. Browser nutzt die identische Quelldatei, Roblox das zugehörige erlaubte Asset. Fehlende Berechtigung hat einen sichtbaren definierten Ersatz. |

## D — Ausschnitte, Komposition und Text

| ID | Umsetzung | Visueller Test und erkennbare Abnahme |
|---|---|---|
| S22 | clipPath, clip-rule, Koordinateneinheiten, verschachtelte/transformierte Ausschnitte. | Farbquadrate durch Kreis, Sternloch und zwei verschachtelte Ausschnitte. Nichts darf über die Clipkante reichen; Größenwechsel erhält den richtigen Prozentbezug. |
| S23 | mask: Alpha-/Luminanzmasken, Maskenregion und Einheiten. | Farbstreifen unter Schwarz-Weiß-Verlauf sowie transparentem Weiß. Alpha- und Luminanzmodus nebeneinander machen ihre unterschiedliche Wirkung sichtbar. |
| S24 | Gruppen-Komposition, mix-blend-mode/isolation soweit spezifiziert und sinnvoll integrierbar; Clip/Mask/Opacity-Reihenfolge. | Rot/Grün/Blau-Kreise auf Grau und auf einem andersfarbigen HTML-Hintergrund. Isolierte und nichtisolierte Gruppe sowie maskierte Überlappung vergleichen. Hintergrundzugang praktisch untersuchen, nicht durch erfundene Farbe ersetzen. |
| S25 | text/tspan: x/y/dx/dy, Anker, Baselines, Schriftprofile, Stil, Leerraum und Abstände. | „H x p Äg“ auf beschrifteten Basislinien, links/mittig/rechts verankert, mit gemischten tspan-Größen. Textbreite und Baseline getrennt beurteilen; vorhandene Kalibrierungen beibehalten. |
| S26 | Textkontur, Text-Alpha, textLength/lengthAdjust, Zeichenrotation, vertikale Schrift, RTL/Bidi und anspruchsvollere Schriftformung. | Text in einem 200-Pixel-Rahmen, gedrehte Zeichen, umrandete Buchstaben, RTL-Zeile und kombinierte Zeichen. Raster-/Outline-Strategie aus S01 bestätigen; Ligaturen nicht als unabhängig drehbare Bytes behandeln. |
| S27 | textPath, startOffset, Orientierung/Abstände und transformierte Pfade; SVG-Textumbruch soweit im Zielprofil. | Identischer Satz entlang Kreis und S-Kurve, Startmarken bei 0/25/50 %, mehrzeiliger Text in begrenzter Fläche. Keine springenden Glyphen oder falsche Baselines. |
| S28 | Text als Clip/Mask/Pattern-/Filterinhalt; foreignObject mit bestehendem HTML-Layout. | Foto durch große Buchstaben, Schatten hinter Text, HTML-Karte im gedrehten SVG-Ausschnitt. Rein darübergelegte TextLabels bestehen diesen Test nicht. Falls Font-Outlines/Atlas nötig sind, mit denselben tatsächlichen Glyphen prüfen. |

## E — Vollständiger Filteraufbau

| ID | Umsetzung | Visueller Test und erkennbare Abnahme |
|---|---|---|
| S29 | filter-Graph: in/in2/result, SourceGraphic/SourceAlpha, Regionen, primitiveUnits/filterUnits, Referenzen, sRGB/linearRGB. | Ein Diagramm mit markierten Zwischenbildern und verschieden großen Filterregionen. Kleine Region schneidet absichtlich ab, große zeigt den ganzen Überstand. Farbinterpolation separat vergleichen. |
| S30 | feColorMatrix, feComponentTransfer mit feFuncR/G/B/A. | Farbkeil und Alpha-Rampe mit identity/matrix/saturate/hueRotate/luminanceToAlpha sowie table/discrete/linear/gamma. Numerische Prüffelder verhindern nur ungefähr passende Farben. |
| S31 | feGaussianBlur, feDropShadow, feOffset, feFlood. | Transparenter Ring und scharfe Ecke mit weichen/versetzten Schatten, getrennten X/Y-Radien, negativer Richtung. Löcher und halbtransparente Kanten bleiben korrekt. Bestehende CSS-Filter nur bei passenden Semantiken wiederverwenden. |
| S32 | feBlend, feComposite, feMerge/feMergeNode. | Zwei überlappende farbige Scheiben als Operator-Matrix einschließlich arithmetic. Form, Farbe und Alpha jeder Überlappung getrennt prüfen. |
| S33 | feImage, feTile, feMorphology, feConvolveMatrix. | Kleines Quellbild gekachelt, dünne Schrift/Formen erodiert und verdickt, Impulsbild geschärft. Kachelränder, Konturwachstum, Kernelanker und Randbehandlung sind markiert. |
| S34 | feDisplacementMap und feTurbulence. | Nummeriertes Gitter durch bekannte Rot-/Grün-Rampen verzerren; daneben Rauschen mit festem seed, Oktaven und stitchTiles. Nahtfreiheit und reproduzierbare Ausgabe vergleichen. |
| S35 | feDiffuseLighting/feSpecularLighting, distant/point/spot lights. | Dieselbe Höhenkarte mit drei markierten Lichtpositionen. Glanzpunkt, Schattenseite und Spotbegrenzung müssen sichtbar richtig liegen. |

## F — Verhalten und Bewegung

| ID | Umsetzung | Visueller Test und erkennbare Abnahme |
|---|---|---|
| S36 | Formgenauer Hit-Test: Füllung/Kontur, transformierte Formen, Löcher, Überlagerung, Clipping, pointer-events-Werte. | Großes Donutloch, unsichtbar gefüllte Form und dicke Linie; nummerierte Mauspositionen. Eine Statuszeile nennt das getroffene Element. Maskentransparenz nach SVG-Regeln behandeln, nicht automatisch als Alpha-Pixel-Hit-Test. |
| S37 | Hover/Active/Fokus, cursor, Links, Eventpfad/Capture, Tastatur/Touch und zugängliche Metadaten. | Drei überlappende Formen und ein Link: feste Folge hinein→drücken→herausziehen→loslassen sowie Tab/Touch. Zustandsfarben und Ereignisliste stimmen; eigene Trefferprüfung, keine nativen Buttons. |
| S38 | Reaktive Änderungen, Abhängigkeiten und SVG-DOM-Geometrieabfragen. | Ein Regler verändert Punkte, ein Klick Farbe, ein dritter Schritt den gemeinsamen Verlauf. getBBox/CTM/ScreenCTM und Punkt-bei-Pfadlänge werden als Kreuze/Boxen eingezeichnet. Farbwechsel erhöht keinen Seitenlayoutzähler. |
| S39 | animate/set/animateTransform: Zeitmodell, Wiederholung, additive/akkumulierte Werte und Interpolation. | Vier gleiche Motive bei t=0/0,25/0,5/1 s anhalten. Sollmarken für Position/Farbe/Skalierung; anschließend Loop, Pause/Fortsetzen und Reset prüfen. |
| S40 | animateMotion/mpath, Tangentenrotation, keyPoints/keyTimes/keySplines, Ereignisstarts; CSS-Animationen/Transitions anbinden. | Pfeil fährt dieselbe S-Kurve ab; fünf feste Zeitschnappschüsse. Hover-Transition separat. Pfadänderung während Bewegung darf keine veraltete Geometrie behalten. |
| S41 | SVG-Skripting über den geplanten eigenen JS-/DOM-Ausbau; keine automatische native Browser-JS-Annahme. | Dasselbe kleine Standardskript fügt einen Kreis hinzu, ändert dessen Attribut und reagiert auf Klick. Browser/Roblox zeigen identische Schritte. Interpreter und benötigte DOM-API als eigene Abhängigkeit umsetzen/testen; Luau-Callback allein zählt nicht als script-Unterstützung. |
| S42 | switch/systemLanguage, view/Fragmente, Ressourcenauflösung, Titel/Beschreibung/Fokus und Dokumentintegration; Legacy-/Erweiterungsaudit. | Sprachvarianten A/B, zwei definierte Ansichten und eine Tafel mit nichtverfügbaren Ressourcen. Fokus-/Metadaten in einer Prüfzeile sichtbar machen. Alte Features wie SVG-Fonts und Entwurfselemente einzeln inventarisieren, Machbarkeit/Status belegen. |

## G — Kombinationen, Leistung und Abschluss

| ID | Umsetzung | Visueller Test und erkennbare Abnahme |
|---|---|---|
| S43 | Wechselwirkung mit HTML: Scrollen, Eltern-Clips, Z-Reihenfolge, Gruppen-Opacity, Layoutänderungen und SVG in mehreren Instanzen. | Zwei SVGs zwischen normalen Formularen; überlappende HTML-Box, Scrollcontainer und verschachtelte Transparenz. SVG-Inhalte bleiben an richtiger Position, Cursor/Clipping stimmen beim Scrollen. |
| S44 | Große/komplexe SVGs: Auflösungsstrategie, ggf. Kacheln, Geometry-/Paint-Caches, Arbeitsbudgets, Abbruch und Ressourcenfreigabe. | Dasselbe Diagramm mit 10/100/1000 Formen, mehrere sichtbare SVGs und kontinuierliches Resize. Bild bleibt korrekt; Rasterzeit, Uploads, Speicher und Layoutaufrufe protokollieren. Keine Nähte bei Kacheln; 20 Lebenszyklen ohne dauerhaftes Speicherwachstum. Gerätebudgets aus Messungen festlegen. |
| S45 | Gesamtabnahme und Supportkatalog. | Vier Endbilder: Blume, beschriftetes Diagramm, Symbol-/Patternkarte und interaktive Filter-/Animationsszene. Bei drei Größen sowie im Standbild und in Aktion vergleichen. Jede Abweichung führt zu Fix oder dokumentierter Grenze, nicht zu einem stillen „passt ungefähr“. |

## Architektur und Abhängigkeiten

Die Bezeichnungen sind Verantwortungsbereiche, keine Pflicht, sofort viele leere
Module anzulegen. Bestehende HTML/CSS-/Font-/Eventmodule nach Prüfung wiederverwenden.

- **SVG-Dokument/Resolver:** Struktur, IDs, Referenzen und Instanzen; klare
  Namespacegrenze zum HTML-Parser. Begrenzte Rekursion bei Referenzzyklen.
- **Style:** SVG-Präsentationseigenschaften, Cascade, Vererbung und Abhängigkeiten
  von CSS-Variablen, Verläufen und use-Instanzen.
- **Geometrie:** Einheiten, Matrizen, Pfade/Kurven, Konturen, Bounding-Boxes und
  Hit-Tests auf gemeinsamer Geometrie, damit sichtbare Form und Klickfläche passen.
- **Paint/Raster:** Füllungen, Konturen, Textstrategie, Verläufe, Muster und
  Gruppenkomposition in Pixelbuffer; transparente Kanten korrekt behandeln.
- **Filter:** Graphauswertung und Zwischenbilder; Arbeits-/Speicherbudget teilen.
- **Roblox-Ausgabe:** passive ImageLabels/Frames/TextLabels nach Fähigkeiten,
  Eigentümerschaft der EditableImages, kooperativer Scheduler, Cleanup.
- **Interaktion/Animation:** Zustandsänderungen markieren abhängige SVG-Inhalte;
  keine Schleife pro Element. Laufende Animationen arbeiten über einen gemeinsamen
  Scheduler, statische SVGs erzeugen ohne Änderung keine neue Rasterarbeit.

S01 klärt die größten Plattformrisiken vorab. Danach A→B→C→D→E→F→G; benötigte
gemeinsame Grundlagen werden jeweils vorgezogen. Text-Machbarkeit S01 und
Textumsetzung S25–S28 sind keine zwei unterschiedlichen Qualitätsversprechen.
Wenn eine spätere Kombination einen früheren Fehler zeigt, wird der ursprüngliche
Regressionstest ergänzt und erneut geprüft.

## Roblox: Grenzen untersuchen statt Funktionen vorschnell streichen

| Bereich | Vorgehen und ehrliche Abschlussbedingung |
|---|---|
| Pixelgrafik | EditableImage bietet Pixelbuffer und Zeichenoperationen; SVG-Parsing, Pfade und CSS sind unsere Implementierung. Ein Zeichenaufruf allein ist kein vollständiger SVG-Renderer. |
| Große Texturen/viele Updates | Aktuelle API-Fähigkeiten und tatsächliche Clientgrenzen in S01/S44 messen. Aufteilung/Downsampling nur mit dokumentierter Qualitätsstufe; keine fixe Grenze aus einem älteren Filtermodul als Roblox-Gesetz übernehmen. |
| Text-Outlines und Rastertext | Normale Fontmessung/Labels sind schon vorhanden. Zugriff auf Glyphenpixel/-konturen nicht voraussetzen. Zulässigen Fontatlas-/Outline-Import oder eigenen Fontpfad untersuchen; unterstützte Fonts/Schriftformung konkret nennen. |
| Bilder/Fonts/Dateien | Erlaubte Roblox-Assets bzw. explizite Resolver verwenden. Browser-Dateipfade und beliebige Webressourcen funktionieren nicht automatisch im Roblox-Client. Fehlende Ressource reproduzierbar testen. |
| Maskierter/gefilterter HTML-Inhalt | foreignObject mit vorhandener HTML-Engine prüfen. Eine vollständige Pixelaufnahme beliebiger GUI-Inhalte nicht voraussetzen; ggf. gemeinsame Rasterdarstellung notwendig. |
| JS, DOM und Browserintegration | Ein eigener Interpreter/DOM kann erweitert werden, ist aber ein eigener großer Teil. Browserfenster, Betriebssystemnavigation, beliebige Webmedien und native Screenreader-Anbindung sind keine automatisch verfügbaren SVG-Funktionen. Zuordnung/Plattformgrenzen separat prüfen. |
| Experimentelle/alte Funktionen | Referenzstand und Browserunterstützung protokollieren. Nicht aus einem Entwurfsindex blind Vollsupport ableiten; nach S42 für jeden relevanten Punkt einen belegten Status führen. |

## Abschlusscheckliste

- [ ] S01–S45 implementiert und geprüft oder mit belegter Plattformgrenze abgeschlossen.
- [ ] Element-, Attribut-, CSS-Werte- und DOM-API-Matrix gegen den gewählten SVG-
      Referenzstand abgeglichen; auch Defaults, Einheiten und Kombinationen erfasst.
- [ ] Alle funktionsbezogenen visuellen Tests mit passenden Browser-/Studio-Bildern.
- [ ] Farb-, Geometrie-, Hit-Test-, Animations- und Fehlerfalltests bestanden.
- [ ] Kein unerwarteter Seiten-Reflow bei SVG-Farbwechseln oder Animationen.
- [ ] Speicher, Abbruch, Größenänderungen und wiederholter Seitenabbau im Client geprüft.
- [ ] Gesamte Projektprüfung und Builds bestanden; bekannte Unterschiede im Katalog.
- [ ] Keine offenen Machbarkeitsfragen als „unmöglich“ oder „fertig“ versteckt.

## Quellen und Referenzstand

Planung geprüft am 13.09.2026. SVG 2 und zugehörige Module bilden den technischen
Katalog; der Testbrowser allein definiert den Standard nicht.

- [SVG 2](https://www.w3.org/TR/SVG2/), [Elementindex](https://www.w3.org/TR/SVG2/eltindex.html), [Eigenschaften](https://www.w3.org/TR/SVG2/propidx.html)
- [Koordinaten](https://www.w3.org/TR/SVG2/coords.html), [Pfade](https://www.w3.org/TR/SVG2/paths.html), [Text](https://www.w3.org/TR/SVG2/text.html)
- [Verläufe/Muster](https://www.w3.org/TR/SVG2/pservers.html), [Clipping/Masking](https://www.w3.org/TR/css-masking-1/), [Filter](https://www.w3.org/TR/filter-effects-1/)
- [Interaktion](https://www.w3.org/TR/SVG2/interact.html), [SVG-Animation](https://www.w3.org/TR/SVG11/animate.html)
- [Roblox EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage), [AssetService](https://create.roblox.com/docs/reference/engine/classes/AssetService)
