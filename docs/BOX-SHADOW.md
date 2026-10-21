# Kartenschatten

`box-shadow` auf Blockelementen verwendet außen native UIShadow-Modifier und innen (`inset`) eine eigene EditableImage-Darstellung. Die Textschatten bleiben auf Nutzerwunsch zurückgestellt. Ein vollständiges gemeinsames HTML-Beispiel steht in examples/ubuntu-roboto-page.html und synchron im HTMLPage-Skript:

```css
box-shadow: 4px 6px 12px 2px rgba(0, 0, 0, 0.25);
```

Unterstützt sind `none` oder bis zu 16 kommagetrennte Schatten, einschließlich gemischter Innen-/Außenschatten. Jeder hat zwei signierte px-Offsets, optional einen nichtnegativen Blur bis 1000px und anschließend optional einen signierten Spread. Null darf ohne Einheit geschrieben werden. Farbe und optionales inset können vor oder nach der zusammenhängenden Längengruppe stehen. Ohne Farbe gilt currentcolor, ohne Blur/Spread jeweils 0. Farben: vorhandene benannte/Hex-Farben, currentcolor, transparent, #RGBA/#RRGGBBAA sowie kommagetrennte rgb()/rgba() mit Zahlen oder RGB-Prozenten und optionalem Alpha/Alpha-Prozent. Numerische Farbkanäle werden auf ihren gültigen Bereich begrenzt. Diese Farbschreibweisen werden inzwischen gemeinsam in CSS/Color verarbeitet und gelten auch für Text, Hintergründe, Rahmen und Dekorationen. currentcolor übernimmt auch die Alpha-Komponente.

CSS/BoxShadow parst die Liste einmal bei der CSS-Kompilierung; Funktionskommas werden von Listentrennern unterschieden. Ungültige Teile verwerfen die komplette Deklaration und lassen eine frühere gültige Deklaration bestehen. Die Eigenschaft wird nicht vererbt. Die normalen Cascade-/important-Regeln gelten. Unveränderliche Schattenrecords können zwischen Regeln geteilt werden; currentcolor wird erst pro gerendertem Element aus dessen finaler Textfarbe aufgelöst.

RenderTree erzeugt pro sichtbarem Schatten einen UIShadow direkt am Block-Frame. X/Y werden zu Offset, Blur zu BlurRadius.Offset, Spread auf beide Spread-Offsetachsen übertragen, Alpha zu `1 - Transparency`. Der erste CSS-Schatten liegt vorn: ZIndex=-1, danach -2 usw. Native Schatten folgen automatisch der Frame-Größe und vorhandenen UICorner. Resize erzeugt weder zusätzliche Modifier noch Textmessungen. Beim Zerstören des Frames werden die Modifier als Kinder mit entfernt. none, voll transparente Schatten und versteckte Elemente erzeugen keine Schatteninstanzen. Falls UIShadow nicht erzeugt werden kann, läuft der Seitenaufbau ohne weitere Schattenversuche fort und gibt eine Diagnose aus.

Keine Änderungen an Textmaßen, Boxmaßen, Abständen, Umbruch oder Scrollausdehnung. Ink-Overflow von CSS-Schatten soll den Seitenfluss nicht vergrößern. Vorhandenes Overflow-Clipping bleibt bestehen. Native Blur-/Spread-Geometrie, Clipping und Schatten an transparenten/runden Boxen sind noch visuell gegen den Browser abzugleichen; die direkte px-Abbildung ist noch keine bestätigte Pixelkalibrierung.

Nicht unterstützt: Inline-Box-Schatten, em/rem/Prozente für Längen, calc(), moderne RGB-Schreibweise mit Leerzeichen/Slash sowie weitere Farbräume. Tests/BoxShadow prüft gültige/ungültige Listen, Transparenz, Defaults, Cascade/important, nicht vererbte Stile, Größen-/Instanzwiederverwendung, Reihenfolge und API-Fehlerpfad. Tests/GuiFactory prüft die Modifier-Erzeugung und Bereinigung bei einem Property-Fehler. Der Nutzer hat den bisherigen Außenschatten visuell bestätigt.

## Innenschatten

```css
box-shadow: inset 4px 6px 12px 2px rgba(0, 0, 0, 0.3);
```

Roblox UIShadow bietet kein inset. RenderTree verwendet daher bei sichtbaren Innenschatten einen ImageLabel als Blockcontainer. Seine eigene Bildebene liegt über dem Hintergrund und unter Text, Kindern und Rand. Dadurch ist kein zusätzliches Overlay mit konkurrierendem ZIndex nötig. Außenschatten bleiben native UIShadow-Kinder. Die vorhandenen GUI-Invarianten Active=false und Selectable=false bleiben erhalten.

InsetShadowPixels erzeugt die Maske einer verschobenen und durch Spread verkleinerten Paddingbox. Positiver Spread verengt das durchsichtige Loch, negativer erweitert es. Die inneren Ecken basieren auf max(0, geklemmter Außenradius minus Randbreite); der Lochradius folgt dem Spread als Näherung. Drei separable Boxfilter nähern eine Gauß-Weichzeichnung mit sigma=CSS-Blur/2 an; sehr kleine positive Blur-Werte nutzen einen gewichteten Dreipunktfilter. Die Maske wird invertiert, in umgekehrter CSS-Reihenfolge mit den Farben/Alphas zusammengesetzt und zuletzt auf die gerundete Paddingbox beschnitten. Der Rahmen bleibt frei. Geometriekanten verwenden 2×2 Abdeckung. Ein Nullschatten hinterlässt auch an gerundeten Kanten keine dunkle Linie.

InsetShadows besitzt pro Seite maximal 32 Kartenbilder und insgesamt 1048576 Bildpixel. Das Raster wird für große Karten oder Blur-Radien reduziert, um Bildseiten unter 1024px und temporäre Blur-Puffer ungefähr bei 262144 Pixeln zu halten. Kleine/übliche Karten bleiben bei nativer Auflösung; große Raster werden über ImageLabel skaliert. Bei konstanten Maßen und gleichem Stil wird nichts neu gezeichnet. Bei gleicher Bildgröße wird die bestehende EditableImage-Allokation verwendet, sonst wird das alte Bild vor dem Ersatz freigegeben. Geänderte Position allein verursacht keine Neuberechnung. Zero-Size und PageSession-Cleanup geben Bilder frei. Keine laufenden Polling-/Animationsschleifen und keine zusätzlichen Textmessungen.

Bei API-/Allokations-/Schreibfehlern oder Budgetüberschreitung wird der betroffene Innenschatten ausgeblendet und einmal diagnostiziert; der Rest der Seite bleibt benutzbar. Ein Update mehrerer sichtbarer EditableImages kann Roblox über mehrere Frames verteilen. Native Unschärfe, Randmaskierung und Verhalten an extrem kleinen/gerundeten Boxen müssen noch gegen den Browser verglichen werden. Keine pixelgenaue Gauß- oder Kurvenkalibrierung behaupten.

Tests/InsetShadows prüfen CSS-Positionen des Keywords, positive/negative Richtungen und Spread, weiche Masken inklusive kleiner Blur-Werte, transparente gerundete Randbereiche, Alpha-/Farbstapel, Rasterlimits, Bildwiederverwendung, Resize, Freigabe und Fehlerpfade. PageLifecycle prüft die einmalige Freigabe durch die Seite. Die reine 900×70-Rastervorschau wurde als build/inset-preview.png geprüft; sie ist kein Studio-Screenshot. Das gemeinsame HTML enthält direkt nach der Außenschattenkarte eine Innenschattenkarte. Native Sichtprüfung offen.

Quellen: [Roblox UIShadow](https://create.roblox.com/docs/reference/engine/classes/UIShadow), [offizielle API-Beschreibung](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UIShadow.yaml), [CSS box-shadow](https://www.w3.org/TR/css-backgrounds-3/#box-shadow), [Roblox-Release und Blur-Anpassung an CSS](https://devforum.roblox.com/t/full-release-new-ui-capabilities-shadows-individual-corners/4636263).
