# Die sechs abschließenden CSS-Blöcke

Stand: 21. September 2026

Die Engine schloss ihr früheres Roblox-CSS-Profil mit sechs zusammenhängenden
Blöcken ab. Sie bleiben durch die jeweiligen Modultests abgedeckt. Die frühere
Sammelroute `css-completion` wurde entfernt; neue visuelle Funktionen erhalten
jeweils eine eigene Untertestseite.

## Position und Anzeige

`position:fixed` wird gegen den sichtbaren Seiten-Viewport angeordnet, bleibt
beim Scrollen stehen und erzeugt keinen Dokumentüberlauf. `position:sticky`
behält seinen normalen Flussplatz und klemmt mit `top`/`bottom` am Viewport.
`inline-block`, `inline-flex` und `inline-grid` verwenden atomare Inline-Boxen
mit eigener intrinsischer Größe und Grundlinie. `display:contents` lässt die
eigene GUI-Box aus und rendert die Kinder mit den geerbten berechneten Werten.

## Generierter Inhalt

Die Selektoren `::before`, `::after` und `::marker` besitzen eine getrennte
Cascade und färben das Ursprungselement nicht. `content` unterstützt bis zu 16
Text- und `attr(name)`-Segmente. Zähler, Bilder, quote-Steuerung und
blockförmige Pseudoelemente liegen außerhalb dieses Profils.

## Logische Seiten

`margin-*`, `padding-*` und `inset-*` sind für inline/block sowie start/end
vorhanden. Logische Rahmenkurzformen setzen inline/block und deren start/end-
Kanten. Block-start/-end entsprechen oben/unten; inline-start/-end folgen in
horizontaler Schreibrichtung dem endgültigen `direction:ltr|rtl`. Die Cascade
zwischen physischen und logischen Deklarationen bleibt quellengeordnet.

## Radien

`border-radius` akzeptiert ein bis vier horizontale Werte und nach `/` ein bis
vier vertikale Werte. Die vier Einzel-Longhands akzeptieren je einen
horizontalen und optional einen vertikalen Wert. Pixel-, Prozent-, Schrift-,
Viewport- und Mathematikausdrücke werden gegen die endgültige Borderbox
aufgelöst. Einfarbige Boxen erhalten eine vollständige gerundete Oberfläche aus
einem begrenzten EditableImage-Atlas. Bei `overflow:hidden` enthält dasselbe Bild
eine zweite Vordergrundmaske gegen den nächsten deckenden Hintergrund. Kinder und HitTests
folgen dadurch denselben elliptischen Einzelradien. Wenn kein deckender
Hintergrund vorhanden ist, bleibt die größte gemeinsame sichere UICorner als
transparenter Fallback aktiv. Alle berechneten Ecken bleiben separat im
Stylemodell.

## Eingabe

`pointer-events:none` entfernt eine HTML-Box aus dem Engine-HitTest und lässt
dahinterliegende Ziele zu. `user-select:none` verhindert den Textcursor auf
nicht auswählbaren Labels; editierbare Roblox-TextBoxen behalten ihre native
Bearbeitung. `touch-action:none|pan-x|pan-y|manipulation` steuert die Scroll-
Aktivierung beziehungsweise -Achse eigener Overflow-Container. SVG verwendet
weiterhin sein genaueres geometrisches pointer-events-Profil.

Die Regressionen liegen in `tests/MediumAdditions.luau`,
`tests/Positioning.luau` und `tests/Stylesheet.luau`. Der Eigenschaftskatalog
enthielt nach diesen sechs Blöcken 191 Einträge. Der anschließende Online-
Abgleich erweitert den Katalog schrittweise; der aktuelle Stand steht in
[`CSS-COMPLETION.md`](CSS-COMPLETION.md).
