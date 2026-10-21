# Flexbox: Ausrichtung und flexible Größen

Unterstützt auf Blockcontainern:

- `display: flex`
- `flex-direction: row | column | row-reverse | column-reverse` (Standard row)
- `gap: 12px` oder `gap: 8px 12px` (Zeilen-/Spaltenabstand)
- `justify-content: flex-start | flex-end | center | space-between | space-around | space-evenly`
- `align-items: stretch | flex-start | flex-end | center | baseline` (Standard stretch)
- `flex-grow`: nichtnegative Zahl, Standard 0
- `flex-shrink`: nichtnegative Zahl, Standard 1
- `flex-basis: auto | content | 0 | px | %`, Standard auto
- `flex`: none, auto, initial oder grow [shrink] [basis]; auch Basis allein
- `flex-wrap: nowrap | [wrap | wrap-reverse] || balance` (Standard nowrap)
- `flex-line-count`: Mindestzahl von Zeilen bei balance, Standard 1, höchstens die Itemzahl
- `flex-flow`: Richtung und/oder Wrap-Modus in beliebiger Reihenfolge
- `margin: auto` und `margin-top/right/bottom/left: auto`
- `align-content: stretch | flex-start | flex-end | center | space-between | space-around | space-evenly` (Standard stretch)
- `align-self: auto | stretch | flex-start | flex-end | center | baseline` (Standard auto)
- `order`: ganze Zahl von -100000 bis 100000 (Standard 0)

Alle Eigenschaften werden nicht vererbt. Bestehende Stylesheet-/Inline-Cascade
einschließlich `!important` gilt unverändert. `display: none` entfernt weiterhin
den Teilbaum; `visibility: hidden` behält den Platz. Außerhalb von Flexcontainern
haben die neuen Ausrichtungseigenschaften keine Wirkung.

Die Größenregeln gelten auf den direkten Items. `flex: 1` entspricht wie in
gängigen Browsern `1 1 0%`, `flex: auto` entspricht `1 1 auto`, `flex: none`
entspricht `0 0 auto`. Die Kurzform setzt ausgelassene Komponenten zurück;
nachfolgende Longhands und `!important` folgen der normalen Cascade.

`flex-flow: column wrap` setzt Richtung und Umbruch gemeinsam. Ausgelassene
Komponenten werden auf row beziehungsweise nowrap zurückgesetzt.

Automatische Margins zählen beim Bemessen und Umbruch zunächst als 0. Nach
Grow/Shrink teilen sich die automatischen Hauptachsen-Seiten einer Zeile den
positiven Restplatz, bevor justify-content greift. Auf der Querachse haben sie
Vorrang vor align-items/align-self und verhindern Stretch des Items. Zwei
automatische Seiten zentrieren, eine nimmt den ganzen freien Abstand auf.
Bei Übergröße bleibt die Box auf der Querachse am physischen oberen/linken Rand.
Reverse und wrap-reverse ändern nicht die physische Bedeutung der Margin-Seiten.
Normale Blöcke unterstützen horizontales auto bei begrenzter Breite; vertikales
auto und auto an Inline-Bildern wirken dort wie 0. Padding akzeptiert kein auto.
Intern bleiben Margin/LayoutMargin numerisch; separate MarginAuto-Flags verhindern,
dass beim Resize berechnete Abstände in den nächsten Layoutdurchlauf einfließen.

Die Basis bezieht sich gemäß box-sizing auf die Hauptachse, bei row auf Breite,
bei column auf Höhe. auto verwendet width/height, sonst den Inhalt. content
verwendet den Inhalt unabhängig von width/height. Prozentbasis braucht eine
bestimmte Container-Hauptachsengröße; bei automatischer Spaltenhöhe zählt Inhalt.
Auch 0% unterscheidet sich in dieser Situation von 0px.

Freier Platz wird nach Grow-Faktoren verteilt. Beim Schrumpfen zählt Shrink mal
Inhalts-Ausgangsgröße. Die Berechnung friert Items an Min-/Max-Grenzen ein und
verteilt den Rest erneut. Faktorsummen unter 1 dürfen Platz übrig lassen. Padding,
Rahmen, Margins und gap werden berücksichtigt; Zwischenwerte bleiben ungerundet.
Die standardmäßige automatische Mindestgröße berücksichtigt untrennbaren Inhalt;
`min-width:0` bzw. `min-height:0` hebt diese Grenze explizit auf. `overflow:hidden`
hat ebenfalls keine automatische Inhaltsmindestgröße. break-word verkleinert die
intrinsische Mindestbreite nicht. Explizite Min-Werte gewinnen vor Max-Werten.

Bei wrap werden Items anhand ihrer Ausgangsgröße mit Min-/Max-Grenzen und
Außenabständen in Zeilen aufgeteilt, bevor Grow/Shrink pro Zeile berechnet wird.
Ein übergroßes Item bekommt eine eigene Zeile und kann darin schrumpfen. Bei row
begrenzt die Inhaltsbreite die Reihe; bei column braucht ein Umbruch eine begrenzte
Höhe (height/max-height). Eine unbegrenzte automatische Spaltenhöhe bleibt ohne balance einspaltig.
`gap: 8px 12px` bedeutet immer Zeilenabstand 8px und Spaltenabstand 12px, auch
bei column. Keine zusätzlichen Abstände außen an der ersten/letzten Zeile.

`flex-wrap:balance` verteilt Items auf mindestens `flex-line-count` Zeilen;
die normale Umbruchwahl kann weitere Zeilen verlangen. Die Berechnung minimiert
die Summe der quadrierten Restabstände vor Grow/Shrink und bevorzugt bei Gleichstand
mehr Items in früheren Zeilen. `wrap-reverse balance` kehrt die Reihenrichtung um.
Bei column mit automatischer Höhe bestimmt die längste balancierte Spalte die
Höhe. `flex-line-count` erzwingt bei gewöhnlichem wrap keine zusätzlichen Zeilen
und hat bei nowrap keine Wirkung. Die verfügbare Breite automatisch bemessener
column-Items berücksichtigt den angegebenen Wert und die Querachsenabstände.

`justify-content` verteilt Items innerhalb jeder Zeile. `align-items` richtet sie
innerhalb ihrer eigenen Zeile aus. `align-content` verteilt die Zeilen auf der
Querachse, z.B. center bei fester Höhe. stretch vergrößert Zeilen gleichmäßig bei
positivem Restplatz. align-content hat bei nowrap keine Wirkung; bei wrap dagegen
auch dann, wenn aktuell alle Items in eine Zeile passen. wrap-reverse kehrt die
Querachsenrichtung um, einschließlich flex-start/flex-end der Items, nicht die
Reihenfolge innerhalb einer Zeile. DOM und GUI-Instanzen werden nicht neu erzeugt.

`align-self` überschreibt align-items für ein einzelnes direktes Flexitem. auto
folgt dem Container; stretch ändert nur eine automatische Querachsengröße und
beachtet Min-/Max-Grenzen. Die Eigenschaften werden nicht vererbt. Lose anonyme
Textitems verwenden align-items und order 0.

`baseline` richtet in row/row-reverse die erste Textgrundlinie aller teilnehmenden
Items derselben Zeile aus. Padding, Rahmen und physische Margins werden mitgezählt;
mehrzeiliger Text bleibt an seiner ersten Zeile ausgerichtet. Fehlt eine Grundlinie,
verwendet das Item die untere Rahmenkante. Die Zeilenhöhe berücksichtigt sowohl
den größten Abstand vor als auch nach der Grundlinie. Bei wrap hat jede Reihe
ihre eigene Gruppe; wrap-reverse verankert sie an der umgekehrten Querachse.
Automatische Querachsen-Margins nehmen ein Item aus der Gruppe heraus.
Verschachtelte Flexboxen geben die Grundlinie ihrer ersten teilnehmenden Reihe
weiter. Vorhandene Fontmetriken und Textmessungen bleiben unverändert.
column/column-reverse verwenden für baseline vorerst flex-start; vertikale
Schreibrichtungen sowie first/last baseline werden nicht unterstützt.

Items werden vor dem Zeilenumbruch aufsteigend nach order sortiert. Gleiche Werte
bleiben in Quellreihenfolge; DOM und RenderTree.Children bleiben unverändert.
Bei ausschließlich Box-Items folgt auch die Stapelung ihrem sortierten Rang
(Roblox ZIndexBehavior.Sibling). Die Stapelung bei gemischten anonymen Textitems,
Textdekorationen und Boxen ist noch nicht vollständig an die CSS-Paint-Regeln
angepasst. z-index auf Flexitems wird in [Positionierung](POSITIONING.md)
beschrieben; keine Fokus-Navigationsfunktion.

row-reverse/column-reverse kehren die Hauptachse um. flex-start liegt dann rechts
bzw. unten, flex-end auf der gegenüberliegenden Seite. Die Reihenfolge im DOM
und die Paint-Reihenfolge werden durch reverse nicht geändert. Mit wrap wird jede
Zeile in dieser Richtung angeordnet; wrap-reverse kann zusätzlich die Querachse
umkehren. Physische Margins und Padding behalten ihre Seiten. Das Scrollsystem
behält vorerst seinen Ursprung links oben; negatives Overflow bei reverse hat
noch keinen browsergleichen umgekehrten Scrollursprung.

```html
<div style="display:flex; gap:12px; align-items:center; justify-content:space-between;">
  <div style="width:64px; height:40px;">A</div>
  <div style="width:64px; height:60px;">B</div>
</div>
```

Direkte Blockkinder sind Flexitems. Direkte Inline-Tags wie span werden zu eigenen
Boxen; lose Textabschnitte zu anonymen Items. Whitespace zwischen Blockkindern
erzeugt keine zusätzlichen Items. Bilder funktionieren innerhalb solcher Boxen;
direkte img-Kinder verwenden vorerst das vorhandene Inline-Modell und sind noch
keine vollständigen ersetzten Flexitems.

Bei auto-Breite werden Text-/Inhaltsbreiten ermittelt, explizite Breiten und
Prozentbreiten beziehen sich auf die Flex-Inhaltsbreite. Border-Box/Content-Box,
Padding, Rahmen, positive Margins, Min-/Max-Breiten und -Höhen bleiben wirksam.
Margins benachbarter Flexitems werden addiert, nicht zusammengeklappt. Stretch
betrifft die automatische Querachsengröße, unter Berücksichtigung der Ränder
und Größenlimits. Explizite Querachsengrößen werden nicht überschrieben.

Verschachtelte Flexcontainer verwenden denselben Block-/Text-Reflow. Das Layout
bestimmt zuerst Itemgrößen und dann deren Positionen. Das Verschieben einer
Blockbox bewegt ihre bereits angeordneten Kinder, ohne einen weiteren rekursiven
Layoutdurchlauf. Native Textmaße und GUI-Instanzen werden bei Resize wiederverwendet.
Folgende Blöcke und Scrollausdehnung berücksichtigen das fertige Flexlayout.

Keine em/rem/calc oder Größenkeywords
min-content/max-content. Intrinsische Breiten verwenden den vorhandenen
Textumbruchalgorithmus; die vollständigen zyklischen Prozent-, verschachtelten
intrinsischen Flexgrößen- und Aspect-Ratio/Cross-Min-Max-Regeln der Spezifikation
sind noch nicht abgebildet. Insbesondere direkte img-Flexitems und komplexe
intrinsisch bemessene, verschachtelte Layouts können vom Browser abweichen.
Kein Grid und keine neue DOM-Mutations-API.

Die bisherige sichtbare Feature-Sammlung wurde auf Nutzerwunsch ersetzt. Acht
kompakte Flex-Beispiele bleiben: drei Ausrichtungsfälle, eine Größenreihe und
eine umbrochene Reihe mit mittiger Zeilengruppe in einem 180px hohen Container.
Das sechste Beispiel kombiniert order/align-self/row-reverse mit einer kleinen
verschachtelten column-reverse-Box.
Das siebte Beispiel kombiniert flex-flow mit automatischem linken und oberen
Abstand: Die zweite Karte sitzt rechts unten.
Das achte Beispiel zeigt drei Schriftgrößen (18/28/40px) mit verschiedenen
Innenabständen auf einer Grundlinie.
Die Größenreihe kombiniert eine feste Karte (72px) mit zwei Karten ab 120px,
Grow 1:2 und Shrink 1:1. Browserdatei und eingebettetes HTML sind identisch;
die automatischen Tests früherer Funktionen bleiben bestehen. `tests/FlexLayout`
prüft beide Richtungen, alle angebotenen Ausrichtungen, Abstände, Stretch,
Margins, Größenlimits, Verschachtelung, anonyme/Inline-Items, Overflow und Resize.
Zusätzlich werden flexible Verteilung, gewichtetes Schrumpfen, partielle Faktoren,
Cascade/Shortcuts, automatische Mindestgrößen, Prozentbasis bei bestimmter und
automatischer Höhe, neue Textumbrüche und Reflow ohne neue native Textmessungen
geprüft. Intrinsische Textproben zeichnen nichts und erzeugen keine Umbruchlabels.
`tests/FlexWrap` prüft Grenzbreiten, Umbruch vor Shrink, Verteilung je Zeile,
beide Gap-Achsen, sieben align-content-Modi, wrap-reverse in beiden Richtungen,
einzelne Wrap-Zeile versus nowrap, verschachtelte Wrap-Items, Min-/Max-Grenzen,
prozentuale Basis, Overflow und Wiederverwendung bei wechselnder Zeilenzahl.
Die ersten acht Beispiele wurden vom Nutzer visuell bestätigt.
`tests/FlexItemControls` prüft CSS-Validierung/Cascade, stabile Sortierung und
unverändertes DOM, alle angebotenen Align-Self-Werte, beide Reverse-Achsen mit
Wrap/Wrap-Reverse, anonyme Items, physische Ränder, intrinsische Spaltenbreiten,
Block-Stapelung und Resize ohne neue Labels oder native Textmessungen.
`tests/AutoMargins` prüft Cascade, Zurücksetzen der Kurzformen, physische Seiten,
Verteilung nach Grow/Shrink, Übergröße, Wrap/Reverse, Block-Zentrierung samt
Scrollausdehnung und Resize ohne neue Labels oder native Textmessungen.
`tests/FlexBaseline` prüft Cascade, Boxkanten/Margins, Zeilenhöhe, erste Textzeile,
Wrap/Reverse, leere und verschachtelte Boxen, anonyme Textitems, Auto-Margins und
Resize ohne neue native Textmessungen oder Labels. Zusätzlich zeigt Beispiel9
Positionierung; dieses benötigt noch die native Sichtprüfung in Studio und Browser.

Grundlage: [CSS Flexible Box Layout](https://www.w3.org/TR/css-flexbox-1/).
