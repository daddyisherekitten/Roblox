# Farben und Transparenz

CSS/Color verarbeitet gemeinsam alle 148 CSS-Farbnamen einschließlich Aliasnamen,
#RGB/#RGBA/#RRGGBB/#RRGGBBAA, transparent, currentcolor und rgb()/rgba().
RGB und HSL besitzen Komma- und Leerzeichen-/Slash-Formen; modernes RGB erlaubt
gemischte Zahlen-/Prozentkanäle und `none`. Alpha kann eine Zahl oder ein Prozentwert
sein. Kanäle werden auf den gültigen Bereich begrenzt. Parsergrenze: Zahlenbetrag
100000, keine Exponentenschreibweise. Das neuere begrenzte OKLab-/OKLCH- und
`color-mix()`-Profil unterstützt sRGB, lineares sRGB, OKLab und OKLCH samt den
dokumentierten Alpha-/Hue-Pfaden. Die Ausgabe bleibt sRGB/Color3 mit einfachem
Gamut-Clipping. [Umfang und verbleibende Kombinationen](CSS-ATELIER-20261007.md)
sind getrennt dokumentiert; HSL-`none`, `calc()`, relative Farben und vollständige
Farbraumgrammatik bleiben offen. Diese Angaben gleichen am 11. Oktober 2026
die älteren pauschalen Nichtunterstützungsangaben mit dem vorhandenen Code ab;
sie melden keine neue Parserimplementierung.

InlineStyle bewahrt Color3-Felder und speichert Alpha separat: ColorAlpha, BackgroundAlpha, BorderColorAlpha, DecorationColorAlpha. Farbdeklarationen überschreiben beide Werte gemeinsam; eine nachfolgende deckende Farbe entfernt vorherige Transparenz. color vererbt Farbe und Alpha. currentcolor wird nach der Cascade aufgelöst und übernimmt beide Komponenten, bei color selbst aus dem Elternstil. Tag-Defaults mit eigener Textfarbe (mark/hr) bleiben deckend.

RGB-Funktionen im border-Shorthand werden als vollständige Tokens gelesen. Rahmen behalten auch bei Alpha 0 ihre Layoutbreite. Text und Zeichenlabels nutzen TextTransparency, Hintergründe BackgroundTransparency, UIStroke Transparency und Linienmuster ImageTransparency. Bildinhalt wird durch Hintergrundfarbe nicht abgedunkelt. Alt-Text und Listenmarker erhalten dieselbe Textfarbtransparenz. Dies ist keine allgemeine opacity auf Elementgruppen.

Der Root-Hintergrund wird auf den Seiten-Canvas übertragen. Die besondere
HTML-Body-Übernahme verlangt einen transparenten Root ohne Bildebene und ohne
aktive Containment-Grenze auf Root oder Body. Die vorhandenen Quellstile bleiben
erhalten; die verwendete Paintfläche zeichnet den Hintergrund einmal über der
UA-Fläche. [Tatsächliche Paintbesitzer, Alpha und Rootkomposition](CSS-BACKGROUNDS.md#dokument-canvas-und-tatsächliche-paintbesitzer--11-oktober-2026)
beschreibt auch PageSession-Abbau und die noch offenen Transform-/Scrollfälle.

Inline-Wortfragmente mit gleichem RGB, aber unterschiedlichem Alpha, bleiben getrennt. Hintergründe über Wortabständen behalten das zugehörige Alpha. Verschachtelte transparente Inline-Hintergründe werden bei der Stilauflösung in ihrer Reihenfolge zusammengesetzt; keine zusätzlichen GUI-Container. Die vorhandene Annäherung der Inline-Hintergrundgeometrie anhand einzelner Wortboxen bleibt erhalten.

Text-, Außen- und Innenschatten verwenden bei currentcolor auch das Text-Alpha; explizite Schattenfarben behalten ihr eigenes Alpha. Der Inset-Cache berücksichtigt Änderungen an ColorAlpha. Die bestehende einfache inset-Rahmennäherung verwendet für beide hellen/dunklen Kanten dasselbe Rahmen-Alpha.

Demo: bisherige Karte mit 20% blauem Hintergrund und 65% Rahmenfarbe; word-spacing-Zeile mit 60% Textfarbe. Body-Farbe als gleichwertiges rgb(), keine zusätzlichen sichtbaren Beispiele. Tests/Colors prüft Parser, Grenzwerte, Vererbung/Resets, Alpha-Stilgrenzen, verschachtelte Hintergründe, Wortabstände, Zeichenlabels, Bild-alt, Listenmarker, Linienmuster, currentcolor-Schatten und Cache-Neuzeichnung. Bestehende Tests prüfen weiterhin Geometrie, Lebensdauer und Ressourcen.

Referenz: [CSS Color 4](https://www.w3.org/TR/css-color-4/). Native Darstellung in Roblox bleibt visuell zu prüfen.
