# aspect-ratio

Unterstützt auf Blockcontainern und img: `auto`, eine Zahl, `16 / 9`, `auto 16 / 9` und `16 / 9 auto`. Nicht vererbt. Ungültige Werte überschreiben keine gültigen Deklarationen; !important und Autor-CSS verwenden die bestehende Cascade. Null im Zähler/Nenner wirkt wie auto. Wie der übrige Parser verwendet die Engine begrenzte Dezimalzahlen: Komponenten bis 100000, positiver Quotient 0.00001–100000; kein calc oder Exponentenschreibweise.

Mindestens eine Achse muss auto sein. Bei fester Breite folgt die Höhe, bei fester Höhe die Breite; zwei feste Maße bleiben maßgeblich. Autorverhältnisse betreffen die durch box-sizing gewählte Box. Natürliche Bildverhältnisse betreffen immer die Inhaltsfläche. Margin zählt nicht zur Ratio; Padding/Rahmen können nicht unterschritten werden.

`auto` verwendet bei Bildern die natürlichen Maße, bei normalen Blöcken kein Verhältnis. `auto 16 / 9` verwendet bei Bildern zunächst das Autorenverhältnis und nach erfolgreicher Maßabfrage die natürliche Ratio. Das Autorenverhältnis hat vorläufig Vorrang vor bloßen width/height-Attributquotienten. Ein reines `16 / 9` bleibt auch nach dem Laden bestehen. Layout/AspectRatio kapselt Ratio-Auswahl und Umrechnung der Boxkanten. Bildinhalt und object-fit behalten unabhängig davon die echten Assetmaße; bestätigter Alt-Textfallback ignoriert das Verhältnis.

Bei zwei automatischen Bildachsen wird die natürliche/Ersatzbreite als Ausgangspunkt verwendet und die Höhe daraus abgeleitet. Bilder mit festem Verhältnis und einer angegebenen Achse benötigen für native zentrierte Fits keine zusätzliche Metadatenabfrage. none/scale-down und wirksame eigene Ausschnitte fragen die Inhaltsmaße weiterhin ab. Reflow verwendet gespeicherte Maße und vorhandene Instanzen.

Automatische Blockbreite füllt zunächst den verfügbaren Platz; eine feste Höhe kann über die Ratio stattdessen die Breite bestimmen. Min/max-Grenzen bleiben maßgeblich und können die Ratio brechen. Normale Blöcke wachsen bei automatischer Höhe für ihren Inhalt; min-height:0 oder overflow:hidden erlauben die kleinere Verhältnisfläche. Bottom-Margins von Kindern kollabieren nicht durch eine ratio-bestimmte Höhe.

Grenzen: keine Flex/Grid-, vertikale Writing-Mode- oder allgemeine Min-Content-Breitenberechnung. Besonders min-width:auto bei fester Höhe kann deshalb bei überbreiten Wörtern vom Browser abweichen. Bestehende Font-/Layoutnäherungen und Ersatzmaße bei fehlendem Assetzugriff bleiben bestehen.

Demo: Vorhandenes cover-Bild mit object-position:right top, width=90 und aspect-ratio:16/9; keine zusätzliche Bildkopie. Browser-HTML und Luau-Literal werden synchronisiert. Tests/AspectRatio prüft Syntax, Grenzen, Cascade, beide Achsen, Boxmodell, Inhalt, Reflow und Fits; ImageDimensions prüft asynchronen auto-Ratio-Wechsel und eingesparte Abfragen. Native Studio-Sichtprüfung offen.

Referenz: [CSS Sizing 4 – Aspect Ratios](https://www.w3.org/TR/css-sizing-4/#aspect-ratio).
