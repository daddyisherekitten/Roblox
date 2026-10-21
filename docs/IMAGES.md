# Bildquellen

Die Zuordnung steht auf Nutzerwunsch direkt oben im jeweiligen Seitenskript. Die Engine enthält keinen globalen Bildkatalog. Im HTMLPage-Testskript ist die vom Nutzer korrigierte Bild-ID eingetragen:

```lua
local IMAGES = {
    ["landschaft.png"] = 15773523297,
}

local page = Engine.mountHTML(target, HTML, {Images = IMAGES})
```

Das HTML verwendet weiterhin den normalen Bildnamen landschaft.png. Dieser muss als Schlüssel exakt passen; bei src="bilder/landschaft.png" entsprechend diesen vollständigen Pfad als Schlüssel verwenden. Die Engine wandelt die ID in rbxassetid://15773523297 um. Die ID wurde vom Nutzer für dieses Bild angegeben; der native Sichtvergleich steht noch aus.

HTMLPage erstellt vor der GUI-Allokation einen unabhängigen Resolver aus options.Images und stellt ihn als page.ResolveImage(src) bereit. Engine.ImageSources.newResolver(mapping) kann auch separat verwendet werden. Ohne Images ist die Zuordnung leer. Spätere Änderungen an der Eingabetabelle ändern keine bereits geladene Seite.

Ganze Zahlen innerhalb des exakt darstellbaren Zahlenbereichs, dezimale ID-Strings und rbxassetid://-Strings sind zulässig; für große IDs Strings verwenden. Groß-/Kleinschreibung, Verzeichnisse und URL-Querys bleiben relevant. Ein führendes ./ und äußerer Leerraum werden ignoriert. Doppelte normalisierte Schlüssel und ungültige Asset-IDs werden abgewiesen; unbekannte Bildpfade liefern nil.

Diese Zuordnung lädt keine Webbilder herunter und veröffentlicht keine Assets. Die Browserdatei muss separat unter dem im HTML genannten Pfad liegen; Roblox benötigt das passende Bild als verfügbares Roblox-Asset.

Lokale SVG-Dateien können ohne Upload über die Website-Konfiguration eingebunden werden. `options.json` enthält dafür etwa `{"LocalSVG":["sample.svg"]}`; `scripts/sync-website.py` übernimmt den Inhalt aus derselben Browserdatei in die generierte Website-Option `SVGs`. Die Engine rendert damit `img`/`picture`, Video-Poster sowie `object`/`embed` über ihre SVG-Pipeline. Andere Bildformate benötigen weiterhin eine `Images`-Zuordnung zu Roblox-Assets.

## Darstellung

```html
<img src="landschaft.png" alt="Landschaft" width="400" height="200"
     style="width: 100%; height: auto; max-width: 400px; object-fit: contain;">
```

`img` wird als atomarer Inline-Eintrag dargestellt. Standardmäßig liegt die Unterkante seiner Marginbox auf der Textgrundlinie; der normale Unterlängenabstand der Zeile bleibt darunter erhalten. Leerzeichen werden wie im übrigen Textfluss behandelt; in normalem Text darf vor/nach einem Bild umgebrochen werden, in nowrap/pre nicht. Bilder werden nicht in Text-Labels zerlegt. Textlinien und mark-Hintergründe überziehen das Bild nicht; die angrenzenden Leerzeichen behalten ihre Formatierung.

Unterstützt: `src`, `alt`, nichtnegative ganzzahlige `width`/`height`-Attribute bis 100000; CSS width/height einschließlich auto, min/max-width/-height, aspect-ratio, box-sizing, background-color und display:none. Prozentbreiten beziehen sich auf den Inhaltsbereich des nächsten Blocks. Höhen sind in px. Autor-CSS und !important überschreiben die Attributmaße.

`object-fit` ist nicht vererbt: fill füllt die Inhaltsfläche (Standard), contain passt proportional vollständig hinein, cover füllt sie proportional mit Zuschnitt. none zeichnet in natürlicher Assetgröße; scale-down wählt die kleinere Darstellung aus none und contain und vergrößert kleine Bilder nie. Die Elementgröße und der Platz im Textfluss bleiben unverändert. `srcset`/`sizes` sowie `picture`/`source` verwenden den gemeinsamen responsiven Auswahlkern; dessen Grammatik, Media-/Längenauswertung, Dichtekorrektur und verbleibende Grenzen sind im [Nachtrag vom 16. Oktober](#responsive-bildauswahl--16-oktober-2026) beschrieben. Bildanforderungen mit und ohne JavaScript prüfen Quellen bei Viewportänderungen erneut. `map`/`area` unterstützen rect, circle, poly und default über dasselbe Linksystem. Kein GIF-Animationsmodell. Blockdarstellung verwendet den gemeinsamen Replaced-Element-/BlockImage-Weg, Inlineblockdarstellung dieselbe Bildbox mit Inline-Fluss.

`object-position` ist ebenfalls nicht vererbt und beginnt bei `50% 50%`. Unterstützt werden ein, zwei oder vier Komponenten: left/center/right/top/bottom, signierte px/% und Kantenabstände, etwa `right top`, `75% 25%` oder `right 10px bottom 5px`. Ein einzelner Zahlenwert legt X fest, Y bleibt mittig; ein einzelnes top/bottom legt Y fest. Zwei Werte bedeuten X/Y (reine Schlüsselwortpaare dürfen vertauscht werden); bei `right 10px` sind das X=rechts und Y=10px, kein rechter Kantenabstand. Prozentwerte berechnen sich aus der Differenz von Inhaltsfläche und gezeichneter Bildgröße. Daher verschiebt `100%` bei cover einen übergroßen Inhalt zur gegenüberliegenden Kante. Die dreiteilige background-position-Syntax gilt hier nicht. Kein em/rem, calc oder logische Schlüsselwörter; ungültige Werte werden diagnostiziert und überschreiben keine vorherige gültige Deklaration.

`Layout/ImageFit` berechnet den gezeichneten Ausschnitt. Der zentrierte Standardweg für fill/contain/cover bleibt ein natives ImageLabel (Stretch/Fit/Crop). Wirksame eigene Positionen sowie none/scale-down erhalten eine Inhalts-Clipbox und ein positioniertes ImageLabel mit Stretch. Überschuss wird immer an der Inhaltsfläche abgeschnitten, unabhängig vom overflow des Elternblocks. Bei fill bleiben reine Prozentpositionen ohne Pixelversatz auf dem nativen Weg, da keine freie Fläche zur Verschiebung verbleibt. Für rechteckige Bilder genügt ein Frame; abgerundete eigene Zuschnitte verwenden CanvasGroup + UICorner, weil UICorner auf einem Frame dessen Kinder nicht maskiert. Die Rundung gehört zur festen Clipbox, nicht zum verschobenen Bild. CanvasGroup benötigt ZIndexBehavior.Sibling am ScreenGui (im Demo gesetzt) und ein zusätzliches Rendertextur-Budget; deshalb wird es nur für diese Kombination angelegt. Reflow aktualisiert Positionen/Größen und erzeugt keine neuen Instanzen. Referenzen: [CSS Images 3](https://www.w3.org/TR/css-images-3/), [CSS-Positionssyntax](https://www.w3.org/TR/css-values-4/#position), [Roblox Frames – Clipping](https://create.roblox.com/docs/ui/frames), [CanvasGroup](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup).

## Ausrichtung und Boxmodell

`vertical-align` auf img: baseline (Standard), super/sub, middle, text-top/text-bottom, top/bottom und signierte px/% einschließlich 0. Positive Längen heben das Bild, negative senken es; Prozentwerte beziehen sich auf die eigene line-height. middle richtet die Mitte der Marginbox an der Eltern-Grundlinie plus halber x-Höhe aus. text-top/text-bottom verwenden die logische Schriftbox des direkten Elternstils, unabhängig von einem eigenen font-size am Bild. Die bestehenden Fontkalibrierungen liefern Näherungen dafür. top/bottom richten an der gesamten Zeile aus; hohe Bilder erweitern diese und die Ausrichtung wird nach dem Umbruch bestimmt. top/bottom-Bilder werden zunächst aus der Grundlinienrechnung genommen; anschließend wächst die Zeile nur so weit wie nötig. Bei mehreren möglichen Grundlinien bleibt die aus den anderen Einträgen abgeleitete Lage möglichst erhalten. Das ist noch keine allgemeine Ausrichtung verschachtelter Inline-Teilbäume; neue Schlüsselwörter/Längen sind zunächst ausschließlich für img freigeschaltet. Inline-Text behält baseline/super/sub.

margin/padding einschließlich einzelner Seiten werden als nichtnegative px unterstützt. Alle Margins zählen bei Inline-Bildern mit, ohne Margin-Collapsing; keine auto-/negativen/prozentualen Abstände. border, border-width/style/color sowie ein gleichmäßiger border-radius funktionieren direkt am Bild. Content-box addiert Padding/Rahmen zu width/height; border-box zieht sie einschließlich min/max-Grenzen von der Inhaltsfläche ab. Die Kanten können nicht unterschritten werden. object-fit erhält ausschließlich die Inhaltsfläche. Rendering/ImageBox trennt die transparente Marginbox, die Rahmen-/Paddingbox und das eigentliche Bild/alt. Keine neuen Größenmessungen oder neuen Instanzen beim Reflow.

Für Rundung bekommen sowohl die Rahmenbox als auch das eigentliche ImageLabel (bei eigenem Zuschnitt die CanvasGroup) eine UICorner; der Bildradius reduziert sich um Rand/Padding. Das ist für gleichmäßiges Padding eine kreisförmige Näherung der inneren Kurve, bei ungleichmäßigem Padding werden elliptische Radien durch den kleineren gemeinsamen Kreisradius angenähert. UICorner rundet keine Kindinhalte automatisch. UIStroke verwendet Round nur mit UICorner, sonst Miter. Der bereits unterstützte inset-Rahmen bleibt eine einfache rechteckige Vierkanten-Näherung.

Das kompakte Demo kombiniert fill/contain/cover mit baseline/middle/text-top in drei Bildern. cover zeigt zusätzlich object-position:right top und aspect-ratio:16/9 bei automatischer Höhe. Fünf weitere Bilder zeigen text-bottom/top/bottom und px/%-Versatz; die ersten beiden davon kombinieren none und scale-down; super/sub werden bereits am Text demonstriert. Rahmen/Abstände/Rundung sind in einer gemeinsamen Feature-Karte sichtbar. `tests/ImageAlignment.luau` prüft unabhängig davon weiterhin das vollständige Bildboxmodell einschließlich Rahmen, Padding, Margins und aller Ausrichtungsvarianten. Grundlage: [CSS 2.2 – Line-height und vertical-align](https://www.w3.org/TR/CSS22/visudet.html#line-height), [UICorner](https://create.roblox.com/docs/reference/engine/classes/UICorner).

## Automatische Bildmaße

Vorgegebene HTML-/CSS-Größen haben Vorrang. Ist mindestens eine Achse automatisch oder benötigt die Inhaltsdarstellung natürliche Maße (none, scale-down, verschobenes contain/cover), liest `Rendering/ImageDimensions` das Roblox-Asset über `AssetService:CreateEditableImageAsync(Content.fromUri(source))` und `EditableImage.Size` aus. Das temporäre EditableImage wird unmittelbar danach zerstört; gespeichert bleiben nur Breite/Höhe an den betroffenen Einträgen. Pro Asset und Seite erfolgt genau eine Abfrage, auch bei mehreren Bildern mit derselben Quelle. Vollständig vorgegebene Maße mit zentriertem fill/contain/cover benötigen keine Abfrage. fill benötigt auch für eine eigene Position keine Inhaltsmaße. Ein festes Autorenverhältnis mit einer angegebenen Achse benötigt für native zentrierte Fits ebenfalls keine Abfrage. Ein Resize verwendet die gespeicherten Maße.

Eine automatische Achse folgt dem ermittelten Seitenverhältnis; zwei automatische Achsen beginnen mit der natürlichen Assetgröße. CSS-min/max-Grenzen und box-sizing werden anschließend wie bisher berücksichtigt. Vor dem Ergebnis sowie bei verweigertem Zugriff, fehlender API oder Speicherbudget verwendet die Engine vorhandene Attributmaße, ansonsten 300px Breite beziehungsweise 150px Höhe. Ein bekannter Attributquotient bleibt als Ersatz-Seitenverhältnis erhalten. Eigene Bildanpassung verwendet bis zur erfolgreichen Größenabfrage dieselben Ersatzmaße; bei verweigertem Zugriff kann sie daher von der natürlichen Größe bzw. dem Seitenverhältnis des tatsächlichen Assets abweichen. Zentriertes natives contain/cover behält dagegen seine native Seitenverhältnis-Ermittlung. Ein Fehler der Größenabfrage erzeugt lediglich eine Diagnose und weder LoadFailed noch ein Fehlersymbol; das normale ImageLabel lädt unabhängig weiter.

Erfolgreiche Ergebnisse stoßen über den vorhandenen Layout-Worker ein Reflow auch bei gleichbleibender Seitenbreite an. Ein bereits aktiver Textfallback braucht dafür kein zusätzliches Layout. Beim Seitenabbau werden wartende Referenzen sofort freigegeben; ein noch laufender API-Aufruf wird nicht abgebrochen, sein zurückgegebenes EditableImage wird aber zerstört und sein Ergebnis ignoriert. Keine dauerhaften Bildpuffer, keine Wiederholungen nach Fehlern und kein Polling.

Die Maße gehören zum von Roblox gelieferten Asset. Unterschiede zur lokalen Browserdatei oder eine durch Roblox veränderte Auflösung werden nicht rückgängig gemacht. Der native Zugriff hängt von den EditableImage-Voraussetzungen und Assetrechten ab. Referenzen: [AssetService](https://create.roblox.com/docs/reference/engine/classes/AssetService), [EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage).

Das erste bestehende Demo-Bild enthält keine width/height-Attribute und zeigt diesen Weg mit max-width:90px; es wurde kein zusätzliches Bildbeispiel angelegt. `tests/ImageDimensions.luau` prüft Gruppierung, CSS-Vorrang, automatische Achsen, Rahmen/Padding, Fehlerersatz, fehlende Ressourcen, Wiederverwendung und Seitenabbau. PageLifecycle prüft den Anschluss an das gemeinsame Reflow.

`Rendering/ImageLoad` lädt je verwendeter Asset-ID ein echtes ImageLabel im Hintergrund über ContentProvider vor. Während des Ladens bleibt die Bildgröße reserviert; Fehlersymbol und Alt-Fallback bleiben bis zu einem bestätigten Fehler unsichtbar. IsLoaded wird ereignisbasiert geprüft; ein erfolgreicher Fetch ohne IsLoaded gilt weiterhin als ausstehend. Preload-Callback-Fehler melden URI und Status einmal pro Asset auch im Studio-Output. Ein allgemeiner Preload-Aufruffehler allein beweist keinen individuellen Bildfehler und aktiviert keinen Fehlerfallback. ImageBox.updateFallback setzt die Sichtbarkeit von Frame, Alt und Symbol gemeinsam; das Layout ändert sie nicht. Dadurch kann ein Resize das Symbol nicht wieder einschalten.

Fehlt die Zuordnung oder meldet der Ladehost einen endgültigen Fehler, bestimmt `Rendering/ImageFallback` den gemeinsamen Fehlerzustand. Externe SVG-Bilder verwenden diesen Weg ebenfalls; internes SVG, Canvas, Medien, Iframes und Formkontrollen sind davon ausgeschlossen. Der Fehlertext ersetzt den Bildinhalt, ohne automatisch alle Bildmaße zu verwerfen:

- Block- und Inlineblockbilder behalten vorgegebene HTML-/CSS-Maße, min/max-Grenzen, Seitenverhältnis, Box-Sizing, Rahmen und Padding. Ein Blockbild mit Alttext und automatischer Breite füllt den verfügbaren Inhaltsbereich. Die Atelier-Landschaft behält damit ihre responsive Fläche im Verhältnis 2:1.
- Ein defektes Inlinebild mit nichtleerem Alttext verwendet im geprüften Chromium die gemessene Textbreite plus 16 Pixel für das Symbol; width, height und aspect-ratio bestimmen diese Ersatzdarstellung nicht. min/max-Grenzen, Padding, Rahmen und Margins wirken weiterhin. Die Inline-Grundlinie folgt der Schrift statt der Bildunterkante.
- Ohne alt-Attribut bleibt das Symbol sichtbar. Explizites `alt=""` unterdrückt Symbol und Text; angegebene Bildmaße bleiben wirksam.

Das vorhandene Nutzer-Asset `rbxassetid://112299903593689` wird als 16 × 16 Pixel großes Fehlersymbol am Anfang der Inhaltsfläche verwendet. Nichtleerer Alttext beginnt direkt daneben, auch innerhalb einer großen Bildbox. Die Ersatzdarstellung wird innerhalb der inneren Rahmenkante geclippt. Fehler blenden die ursprüngliche Bildfläche und veraltete Filter-/Blurflächen aus. Eine erfolgreiche neue Anforderung stellt dieselben erhaltenen Bild-/Boxobjekte wieder her; ein Resize baut sie nicht neu auf. Alt-Messungen berücksichtigen Text, Familie, Gewicht, Stil und Größe und bleiben bei unveränderten Messbedingungen erhalten.

Diese Textvariante bleibt ein atomarer Eintrag: kein Umbruch innerhalb mehrwortiger Alt-Texte und keine eigenen Letter-/Word-Spacing-, Text-Transform-, Schatten- oder Dekorations-Effekte. Das Symbol ist ein Roblox-Asset; vollständige optische Identität mit jedem Browser-/Betriebssystemsymbol ist nicht zugesichert. Die Regeln sind gegen 18 echte Chromium-Größenfälle geprüft, nicht gegen sämtliche Browser-/Quirks-Mode-Fälle. Grundlage: [HTML – Images rendering](https://html.spec.whatwg.org/multipage/rendering.html#images).

## Typangaben in Picture-Quellen – 12. Oktober 2026

`picture > source[type]` verwendet im vorhandenen Profil für zugeordnete statische
Bilder und vorbereitete SVGs eine begrenzte Liste bekannter Typangaben:
`image/png`, `image/jpeg`, `image/jpg`, `image/svg+xml`, `image/gif`, `image/webp`,
`image/avif`, `image/bmp`, `image/x-icon` und `image/vnd.microsoft.icon`.
Unbekannte Angaben wie `image/x-fiction` werden übersprungen; anschließend wird
die nächste passende Quelle beziehungsweise das `img`-Ersatzbild gewählt.
Groß-/Kleinschreibung, äußerer Leerraum und vorhandene Parameter werden wie bisher
behandelt. Fehlende/leere Angaben und Form-Feed entsprechen dem beobachteten
Chromium-Profil; die vollständige MIME-Grammatik ist dadurch nicht abgeschlossen.

Die unveränderte native Referenz liegt in
[`picture-source-type-hints-browser.json`](../tests/fixtures/picture-source-type-hints-browser.json).
Sie enthält 27 Fälle. Für jede URL wurde dieselbe gültige PNG-Datei ausgeliefert:
dies belegt die Wahl anhand der Typangabe, keinen zusätzlichen GIF-/AVIF-Decoder
oder eine Fähigkeit des Roblox-Hosts. Andere Rasterformate benötigen weiterhin
die oben beschriebene Assetzuordnung; GIF-Animationen sind damit nicht umgesetzt.

[`PictureTypeResources`](../tests/PictureTypeResources.luau) prüft 27 fest erhaltene
Fälle mit 378 Assertions über tatsächliche DOM-/JavaScript-Ressourcen und den
behaltenen Renderbaum. Quellenwechsel unterdrücken alte Ladeantworten und behalten
Bildfläche und CSS-Box. Fünf bestehende Bildsuiten bleiben unverändert; der gemeinsame
Produktionslauf mit sechs Suiten besteht nach unabhängigem Review. Dynamische
Decoderfähigkeiten, vollständige responsive Grammatik und sämtliche
Browser-/Studio-Kombinationen bleiben offen.

## Eager-Bildanforderungen ohne Engine-VM — 12. Oktober 2026

Verbundene HTML-IMG-Anforderungen besitzen jetzt ohne Engine-Runtime einen eigenen DOM-Zustand, unabhängig von einer sichtbaren Bildbox. Auch display:none und IMG im Audio-/Video-Fallback halten deshalb den bestehenden Dokumentabschluss offen. HTMLPage verbindet NativeImageResources mit ResourceLoadHost; ImageLoad bleibt für die visuelle Bereitschaft zuständig und startet für diese Nodes keine zweite Anfrage. Aktive JavaScript-Seiten behalten ImageResources.

Aktuelle load/error-Aufgaben geben ihren Beitrag erst nach Rückmeldung und Ereignis frei. Ein weiteres Bild vor der ersten Fertigmeldung hält das Dokument offen; spätere Ressourcen öffnen einen abgeschlossenen Zustand nicht wieder. Quellgenerationen sperren alte Antworten. Responsive Auswahl benutzt den bestehenden begrenzten srcset/picture-Pfad und lädt denselben Kandidaten beim Resize nicht erneut.

Der [begrenzte Produktionsnachweis](HTML-PARSER-ATTRIBUTES-20261006.md#eager-bildanforderungen-ohne-engine-vm--12-oktober-2026) umfasst22/986 Mounted- und24/218 Ownerkontrollen. Nach unabhängigem Review d162f16f wurden Source3/Test2 exakt übernommen; Root12 einschließlich der alten NoRealm- und acht Nachbarsuiten hat tatsächlichen Exit0. Browser HTTP7/15/117 bleibt ein getrenntes Ressourcenprofil. JavaScript-/Lazy-Resumption, automatische Node-Removal-/Adoptionssemantik, native Bildpixel/Decoder und allgemeines Page-/Realm-GC bleiben offen.

## JavaScript-Fehlerzustände

`JavaScript/ImageResources` trennt fehlendes src von explizitem `src=""`: Beide sind vollständig und haben keine natürlichen Bildmaße; nur die explizit leere Quelle plant ein error-Ereignis. `decode()` verwirft diese Zustände mit EncodingError. Fehlerhafte URLs, nicht zugeordnete Ressourcen und vom Host gemeldete Lade-/Decodierfehler führen ebenfalls zu error, complete=true und natürlichen Maßen 0 × 0. currentSrc behält die fehlgeschlagene aufgelöste URL beziehungsweise den ungültigen Autorenwert. Ein gültiges SVG mit einer Nullachse kann dagegen erfolgreich laden; null Pixel sind allein kein Decodefehler.

Eine erneute Zuweisung derselben src startet eine neue Anforderung. Quellenwechsel oder Entfernen der Quelle unterdrücken überholte Fehler-/Ladeereignisse und alte Hostantworten. Bildbox und Hit-Target bleiben erhalten. Verbundene `img.width`-/`img.height`-Abfragen berücksichtigen vorherige DOM-/CSS-Änderungen und liefern die Inhaltsmaße ohne Rahmen/Padding; abgetrennte Bilder erzwingen kein Seitenlayout. Einzelheiten und Hostgrenzen: [JavaScript-Laden](JAVASCRIPT-LOADING-20261005.md).

`tests/ImageErrorSizing.luau` vergleicht die echte Layoutpipeline gegen `tests/fixtures/image-error-sizing-browser.json`. Die Referenzseite entsteht mit `node scripts/test-image-error-sizing.cjs --serve`; die 18 Größenfälle trennen native Schriftmessung von Fontkalibrierung. `examples/websites/browser-foundations/image-error-reference.html` prüft zusätzlich neun native Lifecycle-Fälle: fehlende/leere Quelle, HTTP-404, ungültige URL, beschädigte Data-URI, Null-SVG, wiederholter Erfolg/Fehler und Entfernen vor Fehlerauslieferung. Diese Browserreferenz wird nicht als Roblox-Demoseite ausgeliefert. Hosttests ergänzen simulierte Zugriffs-, Timeout- und Decoderfehler; ein allgemeiner HTTP-/Data-/Blob-Bilddecoder in Roblox ist damit nicht implementiert.

Das gemeinsame Demo enthält alle fünf object-fit-Werte und object-position:right top sowie ein bewusst defektes data:image/png,broken für den Fehlerzustand. Dieser eine fehlende Mapping-Eintrag wird im Demo-Test ausdrücklich erwartet; andere Diagnosen bleiben Fehler. Die Nutzerdatei wurde aus Pictures/landschaft.PNG unverändert nach `examples/landschaft.png` kopiert. Der Projektaudit prüft sie als normale lokale Referenz; die frühere Ausnahme für die fehlende Datei ist entfernt. Die frühere Beispiel-ID 6319951718 wurde im Studio-Log mit AssetDelivery403IncorrectAssetType abgewiesen. Der Nutzer hat sie durch 15773523297 ersetzt. Visueller Browser-/Studio-Abgleich steht aus.

Tests: `tests/Images.luau` prüft Größen, Seitenverhältnis, CSS-Grenzen, Leerzeichen, Umbruch, Baseline, Dekorationen, Wiederverwendung, alt sowie Ladefehler und Seitenlöschung; PageLifecycle prüft die Verbindung von Resolver, Renderer und Loader. Referenzen: [ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel), [ContentProvider](https://create.roblox.com/docs/reference/engine/classes/ContentProvider), [CSS Images](https://www.w3.org/TR/css-images-3/), [HTML-Dimensionsattribute](https://html.spec.whatwg.org/multipage/embedded-content-other.html).

`tests/ImageFit.luau` prüft alle fünf Modi, Positionssyntax, negative/prozentuale Werte, Kantenabstände, das Verkleinerungslimit, die feste Clipkante einschließlich Rundung, Nullgrößen, Ersatzmaße und unveränderten Textfluss. ImageDimensions prüft zusätzlich die gemeinsame Maßabfrage für explizit dimensionierte eigene Zuschnitte. Native Sichtprüfung in Studio bleibt erforderlich.

Seitenverhältnis der Bildbox: [ASPECT-RATIO.md](ASPECT-RATIO.md). Autorverhältnis und natürliche Inhaltsgröße werden getrennt behandelt.

## Responsive Bildauswahl — 16. Oktober 2026

`HTML/ResponsiveSources` zerlegt Kandidaten mit ASCII-Leerraum, URL-Kommas und
einzelner Fehlerkorrektur. Dichtewerte erlauben die HTML-Fließkommaschreibweise
einschließlich Exponenten und null; Breiten sowie die vorbereitende `h`-Syntax
verlangen positive Ganzzahlen. Ungültige Kombinationen verwerfen den einzelnen
Kandidaten. Nach der Normalisierung bleibt der erste Kandidat einer Dichte
erhalten. Das `img.src` ergänzt gegebenenfalls den 1x-Kandidaten. Die konkrete
Wahl ist laut Standard implementationsabhängig; dieses Profil wählt die kleinste
Dichte ab der gewünschten Gerätedichte, sonst die größte verfügbare.

`sizes` verwendet CSS-Komponenten statt einer Trennung an jedem Komma. Die
geprüften Bedingungen umfassen Bereiche, `not`, `and`, `or`, Höhe und Auflösung;
die Längenauswertung verwendet den bestehenden CSS-Parser einschließlich
`calc`, `min`, `max` und `clamp`. Prozentwerte sind hier auch innerhalb einer
Berechnung ungültig. Negative berechnete Längen werden auf null begrenzt,
negative einfache Längen übersprungen; ohne passenden Eintrag gilt 100vw.
Alle übrigen CSS-Mathematik-/Einheitenkombinationen sind damit noch nicht belegt.

Vor dem jeweiligen IMG werden passende SOURCE-Elemente in Dokumentreihenfolge
geprüft. Seine ausgewählte SOURCE liefert auch vorhandene Breiten-/Höhenhinweise;
fehlt dort eine Achse, wird sie nicht aus dem IMG übernommen. Der vorhandene
begrenzte MIME-Hinweisvertrag bleibt vom tatsächlichen Decodieren getrennt.

Anforderungen mit und ohne Runtime sowie der behaltene Renderer verwenden
dieselbe Kandidatendichte und vollständige Viewportumgebung. Natürliche Maße
sind die decodierten Pixelmaße geteilt durch die Kandidatendichte. Der gemeinsame
Metadatencache behält Rohpixel und korrigiert jeden Bildverbraucher einzeln.
Ein Wechsel nur der Dichte oder der ausgewählten SOURCE-Maßhinweise erhält
Anforderung, native Bildfläche und CSS-Box; er aktualisiert die Geometrie ohne
neues Laden oder zusätzliches `load`. Eine noch wartende Antwort verwendet die
aktuellste Dichte. Für gültige 0x/-0x-Kandidaten gilt das ausdrücklich begrenzte
Chromium-Profil von höchstens 33.554.431 natürlichen Pixeln je Achse; null
Quellgröße normalisiert Breitenkandidaten auf unendliche Dichte und natürliche
Maße null. Dies ist eine endliche Layoutgrenze, keine zusätzliche Bildauflösung.

Die [native Rohreferenz](../tests/fixtures/responsive-source-browser.json) enthält
55 IMG-Grammatik-/Größenfälle und zehn Picture-Fälle aus isoliertem Chromium 155
über HTTP. Jede Quelle liefert dieselbe 200×100-PNG unter einer frischen Basis.
[Capture-Skript](../scripts/capture-responsive-source-reference.cjs) und
[ResponsiveImages](../tests/ResponsiveImages.luau) erhalten die eingefrorene
HTML-Revision und alle Rohdaten. 64 Fälle werden direkt verglichen. Der übrige
Fall `sizes-eager-auto` bleibt eine getrennte Abweichung: Die eingefrorene
Algorithmusfolge überspringt das hier unzulässige `auto` und verwendet 200px;
Chromium 155 fällt auf 100vw zurück. Die Rohwerte werden nicht angepasst.

[PictureTypeResources](../tests/PictureTypeResources.luau),
[ImageResourceRendering](../tests/ImageResourceRendering.luau),
[ImageDimensions](../tests/ImageDimensions.luau) und
[NativeImageDocumentLoadRendering](../tests/NativeImageDocumentLoadRendering.luau)
ergänzen tatsächliche VM-, behaltene Renderer- und montierte no-Realm-Wege.
Sie prüfen Basisauflösung, Media-/DPR-Änderungen, gleiche/pending Quelle,
überholte Antworten, SOURCE-Maßänderungen und erhaltene Objektidentitäten.
Die bestehenden 24 Owner-Reentry-/Fehlerkontrollen bleiben unverändert.

Die beiden Registeranforderungen für die übrigen SOURCE-`sizes`-/`srcset`-
Algorithmen sind jetzt einzeln mit diesen Achsen zugeordnet und bleiben
**offen**. Insbesondere `auto` mit Lazy Loading und konkreter Objektgröße,
alle erlaubten Mathematik-/Einheitenfälle, extreme Zahlengrenzen sowie sämtliche
Adoptions-/Entfernungs-/Basis-/Reihenfolgekombinationen sind nicht abgeschlossen.
Allgemeine Decoderfähigkeiten und Studio-Pixel sind gesonderte Hostnachweise.

## Automatische Bildgrößen mit Lazy Loading — 18. Oktober 2026

Der begrenzte `auto`-Teil ist nun mit dem tatsächlichen Layout verbunden.
Ein IMG erlaubt Auto-Größen, wenn sein `loading` ohne Unterscheidung der
ASCII-Groß-/Kleinschreibung `lazy` lautet und sein eigenes `sizes` genau `auto`
lautet oder mit `auto,` beginnt; zusätzliche Leerzeichen an diesem Schlüsselwort-Gate sind nicht
zulässig. Eine passende Picture-SOURCE ohne eigenes `sizes` verwendet dann
`auto`. Explizite SOURCE-Einträge behalten ihre Reihenfolge und Bedingungen.

Die Quellenwahl liest die bereits veröffentlichte Inhaltsbreite der Bildbox.
Sie erzwingt kein Layout während der Auswahl. Ein vorübergehend ungerendertes
Bild verwendet seine letzte gültige Auto-Breite; eine neue Kopie beginnt ohne
diesen Wert. Derselbe DOM-Anfragebesitzer liefert Quelle und Kandidatendichte
an Renderer und Metadatenverbraucher. Die zusätzlichen Layoutbenachrichtigungen
prüfen bekannte Auto-Bilder, ohne einen dauernden Framescan einzuführen.

Die [HTML-UA-Regel](https://html.spec.whatwg.org/multipage/rendering.html#images-3)
setzt für das eigene `sizes="auto"` beziehungsweise `auto,`-Präfix
`contain:size!important` und gewöhnliche Ersatzmaße von 300×150. Die
Containment-Menge ist genau `size`, auch gegenüber anderem Autoren-Containment.
Die Ersatzmaße stehen vor der Autorenkaskade: eigene Längen und null wirken,
`initial`/`unset` können sie auf die ursprüngliche Ersatzgröße null zurücksetzen,
`revert` stellt den UA-Wert wieder her. Explizite CSS-/Attributmaße bleiben
maßgeblich. Geladene, dichtekorrigierte Bildmaße verändern diese Auto-Box nicht
wiederholt. `object-view-box` beschneidet die Bilddarstellung, ohne die
geschützte Ersatzgröße nochmals zuzuschneiden.

Der vorhandene seitenweite Lazy-Besitzer verwaltet jetzt auch Bildfortsetzungen.
Bei aktiviertem Scripting warten entfernte Lazy-Bilder auf die vorhandenen
Geometrie-/Scrollbenachrichtigungen; `loading=eager` setzt sie fort. Bei
ausgeschaltetem Scripting gilt dieser Lazy-Aufschub nicht. Geplanter oder
bereits gestarteter Realm und VM-freie Seiten verwenden jeweils einen
DOM-Anfragebesitzer; zusätzliche explizite Preload-/Metadatenarbeit umgeht
dessen Lazy-Gate nicht. Ersetzte oder abgebaute Anfragen können durch späte
Antworten oder reentrante Auswahlrückrufe nicht wieder veröffentlicht werden.

[AutoImageSources](../tests/AutoImageSources.luau) prüft 59 Kernkontrollen,
[AutoImageRendering](../tests/AutoImageRendering.luau) 25 tatsächlich montierte
Kontrollen mit 1.136 Assertions. Der
[korrigierte Nachweis für elf Quellmodule](../build/engine-expansion-20261018/auto-image-corrected-receipt.json)
enthält den Rotbeleg, den Zwei-Suiten-Lauf, 13 Nachbarsuiten und zwei weitere
Kaskadensuiten. Ein unabhängiger
[Review mit elf strikten Chromium-/Renderer-Gegenproben](../build/engine-expansion-20261018/autoimage-independent-review.md)
prüft besonders UA-Priorität, CSS-weite Werte und den erhaltenen View-Box-Zuschnitt.
Die zusätzlichen 16 nativen Auswahlbeobachtungen sind davon getrennte Rohdaten;
ihre Abweichungen bei führendem Leerraum, eager-`auto` und SOURCE-`auto` ohne
IMG-Gate werden nicht durch Engineerwartungen ersetzt.

Die beiden bestehenden SOURCE-Gesamtanforderungen bleiben **offen**. Dieser
Nachtrag ersetzt ihre ursprünglichen Kriterien nicht. Sämtliche zulässigen
Mathematik-/Einheiten-/Zahlenfälle, Adoptions-/Entfernungs-/Parser-/Shadow- und
Quellenreihenfolge-Kombinationen sind nicht vollständig abgedeckt. Die Tests
zählen explizite Hostanforderungen; automatische Plattformzugriffe, tatsächliche
Roblox-Decoderzeiten, Studio-Pixel und vollständige Seiten-/Realm-Freigabe sind
damit nicht allgemein nachgewiesen.

## Lebende Bildkarten

`img[usemap]` verbindet ein Bild mit dem ersten passenden HTML-Map-Namen oder
der ID im selben Light-Tree-Root. Die Flächen werden bei Eingabe aktuell
ausgewertet; `useMap`, Namen/IDs, AREA-Koordinaten/-Form/-Link und Einfügen/
Entfernen verändern Treffer und Fokus ohne einen neuen Bildaufbau. Die
geprüften Koordinaten beginnen an der CSS-Rahmenbox, einschließlich Padding,
auch bei einem defekten Bild. Gewöhnlicher Map-Inhalt bleibt normaler Inline-/
Blockinhalt; AREA selbst erzeugt keine Box.

Maus, begrenzte Tab-/Enter-Navigation und `area.click()` verwenden das gemeinsame
Linksystem. Fehlendes `href` lässt eine passende tote Fläche nicht automatisch
zu einer späteren AREA durch. Virtuelle Shape-Cursor erhalten eigene Selektoren
und IMG-Vererbung; gewöhnliche DOM-Styles werden dafür nicht überschrieben.
Ein letzter Cursorwert wird begrenzt gecacht, Mutationen invalidieren ihn und
der Seitenabbau gibt ihn sowie den Zuordnungsindex frei. Unveränderte Bewegung
und gewöhnliche Countertexte außerhalb Maps wiederholen keine Zuordnungsscans.

Der [Bildkarten-Nachweis](HTML-PARSER-ATTRIBUTES-20261006.md#lebende-bildkarten-und-flächen--11-oktober-2026)
trennt die 82 nativen Primärzustände von acht normativen Default-Reihenfolge-
Differenzen und nennt die zusätzliche DOM-, Eingabe- und Lebenszyklusprüfung.
Transformierte oder fragmentierte Geometrie, vollständige Mehrbild-/Fokusreihenfolge,
stationäre Hoverzeitpunkte, OS-Cursor und Studio-Pixel/FPS sind damit nicht
pauschal abgeschlossen.
