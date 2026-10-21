# Einzelne Rahmenkanten

Aktueller Zusatz vom 8. Oktober 2026: dieselbe Kanten- und Musterdarstellung
gilt auch für einfache Formularelemente. Offene Buttonkanten erhalten keinen
vollen `UIStroke` mehr. Die native beziehungsweise per CSS gesetzte Buttonrundung und
die geprüfte Bytebude-Rahmenlinie stehen im [Formularprofil](FORMS.md#css-rahmen-und-button-ecken--8-oktober-2026).
Die folgenden älteren Angaben bleiben als ursprünglicher Teilumfang erhalten;
für spätere individuelle/rasterisierte Radien gilt [CSS-VISUAL-LIMITS](CSS-VISUAL-LIMITS.md).

Zusätzlich outset/groove/ridge: wiederverwendete Farbstreifen beziehungsweise
zwei Bänder innerhalb der CSS-Rahmenbreite. Bestehendes inset bleibt erhalten;
Farbwahl und Eckanschlüsse sind angenähert. [Details](SMALL-ADDITIONS.md).

Unterstützt auf Blöcken und Bildern: `border-top`, `border-right`,
`border-bottom`, `border-left` und jeweils `-width`, `-style`, `-color`.
Die Seitenkurzform verwendet dieselbe Grammatik wie border: nichtnegative px
oder thin/medium/thick, solid/inset/outset/groove/ridge/none/dashed/dotted/double und eine unterstützte Farbe.
Fehlende Komponenten werden auf 3px/none/currentcolor gesetzt.
Farbe allein erzeugt keinen Rahmen; transparent behält den Platz der Kante.

Alle Rahmenangaben folgen gemeinsam der Cascade inklusive !important.
border setzt alle Seiten zurück, eine Seitenkurzform nur diese Seite und ein
Longhand nur deren Komponente. Die vier Seiten werden nicht vererbt.
currentcolor wird erst nach der kompletten Cascade aufgelöst. Zusätzliche
Seitentabellen werden nur für Elemente mit eigenen Rahmenangaben angelegt.

`border-width`, `border-style` und `border-color` akzeptieren ein bis vier Werte:
ein Wert für alle Seiten; zwei für oben/unten und rechts/links; drei für oben,
rechts/links und unten; vier für oben/rechts/unten/links. Funktionen wie rgba()
werden auch mit Leerzeichen als ein Farbwert gelesen. Jeder Wert wird vor dem
Anwenden geprüft; ein ungültiger oder fünfter Wert verwirft die gesamte Angabe.
Die jeweiligen Seiten-Longhands akzeptieren weiterhin genau einen Wert.
Tests prüfen alle Anzahlen, Alpha/currentcolor, Wiederverwendung kompilierter
Styles sowie das Zusammenspiel mit Einzelkanten und !important.

Layout/BorderGeometry liefert die effektiven Breiten oben/rechts/unten/links.
Block-, Flex-, Bild-, Scroll- und Positionslayout rechnen mit deren Summen.
Margin-Collapsing prüft die jeweils betroffene obere/untere Kante.
Innere Schatten berücksichtigen alle vier Kanten in Maske und Cache-Schlüssel.
Rendering/BorderBox teilt die Darstellung zwischen normalen Boxen und Bildern.

Gleichmäßige solide Rahmen behalten UIStroke einschließlich bisheriger Rundung.
Inset und ungleiche Rahmen verwenden Frames und kleine Bildflächen für diagonale
Farbübergänge. Bei fehlender API/Budget bleibt die alte volle obere/untere Kante
erhalten. Keine Rundung ungleicher Kanten; [Details](BORDER-CORNERS.md).
Bei inset bleibt die bisherige
zweifarbige Näherung bestehen. Individuelle Eckradien sind weiterhin nicht implementiert.

Das Muster wird innerhalb jeder Kante gezeichnet: dashed mit rechteckigen
Strichen, dotted mit runden Punkten und double mit zwei Linien plus Abstand
innerhalb der unveränderten Gesamtbreite. Unter 3px ist double wie solid
angenähert. Strichlänge ungefähr 3×Dicke, Punktdurchmesser gleich Dicke; Lücken
werden auf die Kantenlänge verteilt. Sehr kurze Punktkanten verwenden einen
kleineren, zentrierten Kreis. Rahmenmuster brauchen keine EditableImage-API.

Pro Kante höchstens 128 wiederverwendete Segmente; bei längeren Kanten werden
die Lücken größer. Bei kleinerer Box werden übrige Segmente ausgeblendet,
beim Vergrößern wiederverwendet. Unveränderte Kantenmaße überspringen die
Musterberechnung. Muster laufen nicht durchgehend um die Ecken und folgen
noch keinen gerundeten Boxkanten. Diese Darstellung bleibt eine Näherung.

Beispiel 15 zeigt eine Karte mit vier Farben und 2/4/6/8px Rahmenbreite,
mit border-width/style/color-Kurzformen: oben dashed, rechts dotted, unten
double, links solid. Die bestehende Karte ersetzt zusätzliche Musterbeispiele.
Das vollständige Browser-HTML bleibt identisch mit dem HTML im Seitenskript.
Tests/BorderSides prüft die 16 Eigenschaften, Resets, !important, Vererbung,
Alpha/currentcolor, ungültige Werte, voneinander unabhängige Styles,
Box-/Flex-/Bild-/Scroll-/Positionsmaße, Schattenmasken und Resize-Wiederverwendung.
Die vorhandenen Tests für gleichmäßige Rahmen und hr bleiben bestehen.
Native Sichtprüfung der neuen Karte steht aus.

Grundlage: [CSS Backgrounds and Borders](https://www.w3.org/TR/css-backgrounds-3/#border-shorthands).
