# Sichtbarkeit

`visibility: hidden | visible` wird in Stylesheets und style-Attributen unterstützt,
vererbt und standardmäßig auf `visible` gesetzt. Der Eintrag steht in
`src/HTMLEngine/CSS/Properties.luau` und ist über `Engine.CSSProperties` abrufbar.

```html
<p>Anfang <span style="visibility: hidden;">Platzhalter
  <span style="visibility: visible;">sichtbares Kind</span>
</span> Ende</p>
```

Unsichtbare Elemente behalten Textmaße, Bildmaße, Rahmenbreite, Padding, Margin,
Zeilenumbrüche und Listenpositionen. Ein Kind darf ausdrücklich sichtbar sein.
`display: none` entfernt dagegen weiterhin den gesamten Teilbaum aus dem Layout.
`collapse` ist in diesem Teilumfang nicht unterstützt und wird diagnostiziert.

Seit den Kombinationsprüfungen vom 1. Oktober 2026 bleiben eigenständige, anfangs
mit `display:none` versteckte Blockboxen intern erhalten. Medienregeln und
CSS-Zustände können sie später zeigen und erneut verstecken, auch in Flex/Grid.
Versteckte Kinder nehmen keinen Platz oder Gap ein; ihre Margins beeinflussen
keine benachbarten Margin-Collapses. Fixed-Kinder dürfen einen versteckten
Vorfahren nicht durch die Viewport-Ebene verlassen. Fokusprüfungen beachten
versteckte Vorfahren, Listen überspringen durch `display:none` entfernte
Listeneinträge, und Fieldsets
wählen ihre erste sichtbare Legend-Box erneut aus.

Die Änderung erhält GUI- und Rahmen-/Schattenobjekte für spätere Zustände;
sie sind während `display:none` unsichtbar. Versteckte Counter-Teilbäume
verändern beim Aufbau keine sichtbaren Geschwister-Counter. Generierte
Countertexte werden beim späteren Einblenden noch nicht allgemein neu erzeugt.
Anfangs versteckte Inline-/ersetzte Elemente sowie Blöcke mitten in gemischtem
Inline-Text bleiben eine Grenze der strukturellen Rekonstruktion. Letztere
werden weiterhin ausgelassen, damit sie keine Wörter oder Zeilen unterbrechen.
`CombinationPainting` prüft zwölf Verstecken-/Zeigen-Rundläufe und fünfzehn
Medienzustände mit anfangs versteckten Blockboxen und Fixed-Nachfahren.
Projizierte 3D-Flächen und flache Masken-Kompositionen lassen die versteckten
Teilbäume ebenfalls aus; vier zusätzliche Rasterzustände prüfen Entfernen
und Wiederherstellen der sichtbaren Pixel.

Blockcontainer bleiben als transparente Frames erhalten, damit Roblox sichtbare
Nachfahren darstellen kann. Eigene Hintergründe, Rahmen, Schatten und Listenmarker
werden ausgeblendet. Text nutzt TextTransparency, Bilder einen unsichtbaren inneren
Boxcontainer. Dadurch können Hintergrund und Unterstreichung eines sichtbaren
Vorfahren weiterhin unter unsichtbarem Text liegen; unsichtbare Buchstaben erzeugen
darin keine Skip-ink-Lücken. Versteckte Ursprünge erzeugen selbst keine Dekoration.
Geerbte Textschatten können bei einem ausdrücklich sichtbaren Kind erscheinen.

Bildladen und Größenabfragen bleiben aktiv. Fallbacks und nachträglich geladene
Bilder bleiben innerhalb ihrer unsichtbaren Bildbox; Größenänderungen lösen den
bestehenden Reflow aus. Es gibt weiterhin keine allgemeine DOM-/Style-Mutations-API.

`tests/Visibility.luau` prüft Vererbung/Cascade, Stilgrenzen, Geometrie und Umbrüche,
sichtbare Nachfahren, Listen, Buchstabenlabels, Dekorationsursprünge, Bilder und
Messwiederverwendung. Der Kurztest enthält eine zusätzliche Visibility-Zeile;
HTML und Luau-Einbettung werden zusammen synchronisiert. Native Sichtprüfung in
Studio bleibt erforderlich.

Grundlage: [CSS Display – visibility](https://www.w3.org/TR/css-display-3/#visibility)
und [CSS 2.1 – text decoration](https://www.w3.org/TR/CSS21/text.html#decoration).
