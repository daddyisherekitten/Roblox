# CSS-Hintergrundbilder

Die Engine unterstützt Hintergrundebenen auf Blockboxen mit demselben CSS, das
auch ein Browser liest:

- `background-image` mit `url(...)`, `linear-gradient()`,
  `repeating-linear-gradient()`, `radial-gradient()` und
  `repeating-radial-gradient()` sowie konische Verlaufsquellen im bestehenden
  begrenzten Rasterprofil;
- mehrere Ebenen, wobei die erste CSS-Ebene oben liegt;
- `background-size` mit `auto`, ein oder zwei Längen/Prozenten, `cover` und
  `contain`;
- `background-position` mit Schlüsselwörtern, Längen, Prozenten und
  Kantenoffsets wie `right 12px bottom 10px`;
- `background-repeat` mit getrennten Achsen, `repeat-x`, `repeat-y`, `space`
  und `round`;
- `background-origin` und `background-clip` für Border-, Padding- und
  Contentbox;
- die Kurzform `background`, die Farbe und alle Ebenen-Longhands zurücksetzt.

`url(...)` lädt keine beliebigen Internetdateien. Wie bei `img` ordnet
`options.Images` den exakten Quellpfad einer freigegebenen Roblox-Asset-ID zu.
Die Groß-/Kleinschreibung des URL-Inhalts bleibt dabei erhalten. In einer
normalen Browserdatei zeigt derselbe Pfad direkt auf die Bilddatei.
Lokale SVG-Quellen aus `options.SVGs` verwenden denselben budgetierten
SVG-Rasterpfad und dessen Ladezustand. `image-set()` wählt in diesem
Hintergrundpfad nach Dichte und unterstütztem MIME-Typ; das ist kein Nachweis
der vollständigen Bildgrammatik oder aller anderen Bildverbraucher.

## Darstellung und Cache

`Rendering/BackgroundImages` hängt passive, nicht anklickbare Bildschichten an
die vorhandene Box. URL-Ebenen verwenden native `ImageLabel`s. Verläufe werden
von `Rendering/BackgroundPixels` in ein `EditableImage` gerastert. Ein Verlauf
wird nur für eine neue Kombination aus Verlauf, Rastergröße und `currentcolor`
berechnet. Reflow und wiederholte Zustandswechsel verwenden danach denselben
Cacheeintrag.

Eine Verlaufstextur hat höchstens 256 Pixel pro Kante und 65536 Pixel. Pro
Seite gelten höchstens acht Ebenen je Box, 64 Verlaufstexturen und insgesamt
4194304 Cachepixel. Die Seite meldet eine Diagnose und lässt nur die betroffene
Ebene weg, falls die API oder das Budget fehlt. Beim Zerstören der PageSession
werden alle `EditableImage`s freigegeben.

Die Verläufe interpolieren Alpha vormultipliziert, verteilen ausgelassene
Stopppositionen, begrenzen rückwärts laufende Stopps und unterstützen doppelte
Positionen. Lineare Winkel und Richtungen folgen der CSS-Ausrichtung. Radiale
Kreise/Ellipsen unterstützen Seiten-/Eckgrößen, explizite Radien und eine
eigene Mittelpunktposition.

## Bewusste Grenzen

- `cross-fade()`, heruntergeladene Remote-Bilder und vollständige
  Bild-/Farbraumgrammatik bleiben offen. Konische Verläufe und die begrenzte
  `image-set()`-Quellwahl sind bereits vorhanden; ihre weiteren Kombinationen
  stehen im [CSS-Profil](CSS-ATELIER-20261007.md).
- Hintergrundbilder auf zerlegten Inline-Textfragmenten werden nicht gemalt;
  einfarbige Inline-Hintergründe bleiben wie bisher verfügbar.
- `space` verwendet die normale Wiederholungsphase als Näherung. `round`
  wählt eine ganzzahlige Kachelzahl und passt die Kachelgröße an.
- URL-`auto` füllt ohne separate intrinsische Hintergrundmetadaten die
  Positionierungsfläche. `cover` und `contain` verwenden Robloxs native
  Bildanpassung.
- Ungleiche innere Rundungen werden auf einen gemeinsamen Kreisradius
  angenähert.

Die neue Browser-/Roblox-Untertestseite
`examples/websites/css-background-position` prüft getrennte Positionsachsen.
`tests/Backgrounds.luau` deckt zusätzlich Parser, Kaskade, URL-Schreibweise,
Rasterfarben/-alpha, Größen-Cache und Freigabe ab.

## Dokument-Canvas und tatsächliche Paintbesitzer – 11. Oktober 2026

[CanvasBackground](../src/HTMLEngine/Rendering/CanvasBackground.luau) liest
das tatsächliche Dokumentelement und den ersten direkten HTML-Body. Ein
transparentes HTML-Root ohne Bildebene übernimmt dessen Hintergrund nur,
wenn weder Root noch Body aktive Containment-Grenzen besitzen. Auch implizite
Containment-Zustände aus `container-type:size`/`inline-size` verhindern diese
Übernahme; `normal` und reines `scroll-state` tun das nicht. Präfixe ändern
gültige HTML-Namespacebesitzer nicht. Fremde, namespacefreie oder verschachtelte
Body-Namensvettern werden nicht als Canvasquelle benutzt. `display:none`
entfernt die sichtbare Quelle; `visibility:hidden` versteckt den übertragenen
Canvas-Hintergrund nicht. Eine vorhandene fehlgeschlagene Bildebene wird durch
einen Ressourcenfehler nicht zu `none` und aktiviert keine Body-Ersatzquelle.
Auch `url("")` und `url()` bleiben vorhandene URL-Bildebenen. Der Parser
bewahrt ihre leere Quelle; der Painter führt dafür weder Bildauflösung noch
SVG-Draw, Upload, Slotallokation oder Warnung aus. Die spätere Bildebene behält
ihren ursprünglichen Longhandindex. Wird eine wartende SVG-Ebene durch diese
leere URL ersetzt, entfernt der bestehende Ressourcenbesitzer den alten Request.
Das ist keine allgemeine neue URL- oder Bildgrammatik.

Die behaltene passive Paintfläche deckt mindestens Viewport und Dokument ab;
Größe, Position und Wiederholungsperiode der Bilder beziehen sich weiterhin
auf die Root-Positionierungsbox samt Rändern und Padding. DOM-/CSSOM-Stile
der ursprünglichen Besitzer bleiben erhalten. Die verwendete Paintprojektion
unterdrückt nur deren doppelten Hintergrund, auch bei Rundungen und vorhandenen
Effektrastern. Ein gewöhnliches langes Dokument erhält keine zusätzliche
CanvasGroup. Falls Root-Opacity eine Gruppe benötigt, liegen Canvas und
ursprüngliche Root-GUI gemeinsam darin; die erste direkte WAAPI-Änderung
erhält Editor, Verbindungen, Fokus und Auswahl. Body-Opacity dämpft einen
übertragenen Hintergrund nicht. Die helle oder dunkle UA-Fläche bleibt
außerhalb der Root-Komposition. Unveränderte Layoutveröffentlichungen zeichnen
die Fläche nicht erneut. Dieselbe BackgroundImages-/SVG-Warteschlange und
deren begrenzte Caches besitzen die Ressourcen; PageSession-Abbau entfernt
die Canvasfläche und invalidiert wartende Veröffentlichungen.

[Dauerhafte Browserreferenz](../tests/fixtures/canvas-background-browser.json)
und [Capture](../scripts/capture-canvas-background-reference.cjs) enthalten
63 native Fälle mit 136 Rohzuständen einschließlich acht Container-Typkontrollen.
Die ursprünglichen 45 Fälle bleiben unverändert erhalten; 18 zusätzliche
Kontrollen betreffen ausdrücklich per DOM konstruierte Frameset-/Bodybesitzer,
leere/fehlgeschlagene/Unsupported-MIME-Bildebenen und warme Root-/Body-
Display-/Visibility-/Contain-/ContentVisibility-/ContainerType-Rückwechsel.
[CanvasBackgroundRendering](../tests/CanvasBackgroundRendering.luau) prüft
59 Initialzustände und 73 dynamische Zustände mit 1490 Pixelproben auf
behaltenen GUI-Flächen und hochgeladenen Rasterbuffern. Die zusätzlichen
CSSOM-Rückwechsel werden auch mit frisch aufgebauten Endzuständen verglichen;
ursprüngliche Farben, Paint-/Editoridentitäten, Resize, WAAPI und
Ressourcenfreigabe bleiben geprüft. Root- und Body-Zustände verwenden dabei
den tatsächlichen retained `content-visibility`-Pfad. Eine komplette Kombination
mit Hover, Mediaqueries, Container-Recascade, Dokumentwachstum und
Seitenersetzung ist dadurch noch nicht abgenommen. Die Rohbeobachtung,
dass Chromium einen bestehenden Root-`currentColor`-Verlauf nach einer reinen
Farbänderung nicht neu zeichnet, bleibt separat gespeichert: Die Engine folgt
der neuen verwendeten Farbe, abgeglichen mit einer frischen nativen Kontrolle.
Die zusätzliche tatsächliche HTMLPage-/PageSession-Probe prüft Erstveröffentlichung
einer 2000px-Seite, behaltene Resizeflächen und Abbruch einer wartenden
Veröffentlichung. Für SVG-Hintergründe laufen BackgroundImages, BackgroundSVG
und RenderQueue tatsächlich; allein der kleine Rasterbackend ist im Lifecycle-
Test synthetisch. Entfernen vor Verarbeitung verhindert Upload/Allokation;
Wiederherstellung installiert genau ein Raster, und Dispose vor dem nächsten
Größenrequest verhindert dessen Veröffentlichung und räumt Listener/Texturen ab.
Die getrennten SVG-Suiten prüfen die tatsächliche Rasterimplementierung.
Hintergrundbilder, -größen, -positionen, -wiederholung, -ursprung, -clip und
-attachment benutzen nun die gemeinsame reine Paintklassifizierung: Ein
entsprechender CSS-Wechsel allein fordert kein Layout der unveränderten Box.
Bei gewöhnlichen Blockboxen synchronisieren dynamischer Paint und direkte
Animationsdekorationen außerdem denselben Corner-/Borderbesitz vor dem Repaint.
Acht warme Wechsel zwischen vier unabhängigen Kreisradien, elliptischem Raster
und Hintergrundbild stimmen mit frisch aufgebauten Endzuständen überein.
Box, GUI und Cornermodifier bleiben erhalten; alte Raster werden verborgen,
erneut benutzt und genau einmal freigegeben. Die neun betroffenen Border-/
Corner-/Animations-/Lifetime-Suiten bestehen. Das ist keine vollständige
Abnahme sämtlicher ersetzter Bild- oder nativer Control-Cornerkombinationen.

Noch offen sind die vollständige `getComputedStyle().backgroundImage`-
Serialisierung, Root-Transformationsflächen einschließlich inverser
Viewportausdehnung des unendlichen Canvas, weitere `fixed`-/`local`-Scroll-
und Transformkombinationen sowie vollständige Masken-/Filter-/Mischgruppen.
Vier native Transform-Initialzustände bleiben ausdrücklich ungeprüft; zwei
Rücksetzungen zur untransformierten Basis sind keine Transformabnahme.
Der konstruierte Framesetfall bleibt in seiner lokalen Darstellung ebenfalls
offen: Chromium meldet trotz deklarierter 120px Höhe eine 800×600px große
Framesetbox mit `display:block` und blauem computed Hintergrund, zeichnet
jedoch keine blaue Fläche. Die Engine besitzt bisher eine gewöhnliche 120px-
Box. Ein vorausgehendes Frameset platziert den Body nativ bei y=600 statt
bisher y=30 in der Engine. Die Ownerprobe prüft deshalb den tatsächlichen
Canvasbesitzer und Pixel außerhalb der bisherigen Engine-Framesetbox; zwei
innere Rohpixel bleiben ungeprüft. Das ist umsetzbare separate Frameset-
Layout-/Paintarbeit. Tatsächliche nicht-HTML-Dokumentroots einschließlich
ersetzter SVG-Roots hatten in diesen ursprünglichen Fällen noch keine montierte
Abnahme; der folgende Besitzernachweis ergänzt sie getrennt.
PNG-Rohdaten und getrennte eingefrorene Standarderwartungen werden nicht
einander angepasst. Die abschließende Studio-Pixel-/Leistungsabnahme bleibt
offen; die vorhandenen [Hostgrenzen](CSS-VISUAL-LIMITS.md) gelten weiter.

Grundlagen: [Root-Hintergrund](https://www.w3.org/TR/2024/CRD-css-backgrounds-3-20240311/#root-background),
[Body-Hintergrund](https://www.w3.org/TR/2024/CRD-css-backgrounds-3-20240311/#body-background),
[leere URLs](https://www.w3.org/TR/2024/CRD-css-values-3-20240322/#empty-urls),
[Canvas-Transformation](https://www.w3.org/TR/2019/CR-css-transforms-1-20190214/#transform-rendering).

## Tatsächlicher Dokumentroot und erster HTML-Body – 16. Oktober 2026

Die ursprünglichen beiden Kriterien von `background-color / canvas-owner`
sind jetzt geprüft. Die reine Auswahl in `CanvasBackground.plan` verwendete
bereits das tatsächliche Dokumentelement und expandierte Namen korrekt.
Die ergänzte [Besitzerprüfung](../tests/CanvasBackground.luau) prüft außerdem
eingefrorene berechnete Stile: Auswahl und verwendete Hintergrundprojektion
ändern weder diese Tabellen noch Autorattribute. Ein erster transparenter,
verborgener oder enthaltener HTML-Body wird nicht durch einen späteren Body
ersetzt. Fremde, namespacefreie, verschachtelte und reine Namensvettern sowie
Framesets übernehmen die Body-Sonderrolle nicht. Vorhandene leere oder
fehlgeschlagene Bildebenen am Root sperren die Übertragung weiterhin.

Der neue Schlüssel `ownerSelection` in der bestehenden
[Browserreferenz](../tests/fixtures/canvas-background-browser.json) enthält
13 zusätzliche native Fälle mit 20 unveränderten Rohzuständen. Die bisherigen
63 Fälle, berechneten Bildwerte und getrennten normativen Erwartungen bleiben
erhalten. Der [Capture](../scripts/capture-canvas-background-reference.cjs)
ergänzt mit `--append-owner-selection` ausschließlich noch nicht erfasste
Rezepte. Nicht-HTML-Roots, ein ersetzter SVG-Root, Groß-/Kleinschreibung des
lokalen Namens, gültige Präfixe und erste/danach folgende Body-Kandidaten
werden konstruiert; native Pixel außerhalb der lokalen Root-/SVG-/Framesetbox
prüfen den Canvasbesitzer unabhängig von deren vollständiger Inhaltsdarstellung.

Die montierte [Rendererprüfung](../tests/CanvasBackgroundRendering.luau) führt
dieselben Body-Entfernungen, Einfügungen und Containment-Wechsel in der echten
JavaScript-VM aus. Sie ersetzt auch das verbundene Dokumentelement nacheinander
durch einen fremden Root, SVG und präfigiertes HTML. Dabei wurde ein Fehler
gefunden: Eine gleichzeitige Stylesheet-Invalidierung ließ den Renderer den
strukturellen Dokumentwechsel verwerfen. `RenderTree` verarbeitet nun beide
Änderungen unabhängig. Die vorhandene Renderer-Vorprüfung erlaubt unterstützte
Root- und direkte Body-Änderungen; ein zweites Dokumentelement bleibt durch die
DOM-Hierarchieregeln atomar abgewiesen. Die Canvasfläche bleibt erhalten und
eine wiederholte Besitzerveröffentlichung verändert keine Quellstile.

Dieser Nachweis schließt nur `canvas-owner`. Die besondere lokale
Framesetdarstellung, sämtliche SVG-Inhalte, die gesamte Hintergrundgrammatik
und die abschließende Studio-Pixelabnahme werden dadurch nicht abgeschlossen.

## Berechnete Hintergrundbilder und currentColor – 15. Oktober 2026

`getComputedStyle().backgroundImage` serialisiert jetzt die vorhandenen
geparsten Bildebenen. Lineare, radiale, konische und wiederholte Verläufe
behalten Positionen, berechnete Längen, Winkeleinheiten und die Art einer
linearen Schlüsselwortrichtung. `image-set()` behält Kandidaten, Dichten und
Typangaben; leere und bereits absolute URLs sowie mehrere Ebenen bleiben
erkennbar. Farbwerte und `currentColor` werden für das abgefragte DOM-Element
berechnet. Der übertragene Canvas-Hintergrund benutzt weiter unabhängig davon
die verwendete Root-Farbe. Weder Autorattribute noch die geparsten
Bildtabellen werden durch wiederholtes Lesen verändert.

Die bestehende [Canvasprüfung](../tests/CanvasBackgroundRendering.luau)
vergleicht jetzt auch die nativen `backgroundImage`-Strings aller dort
geprüften dynamischen Root-/Bodyzustände. Die bisherigen 59 Anfangsfälle,
73 Mutationszustände und 1490 Pixelproben bleiben erhalten. In derselben
[Referenzdatei](../tests/fixtures/canvas-background-browser.json) sind unter
`computedImages` 32 zusätzliche unveränderte Chrome-155-Beobachtungen mit
Browserfassung, Eingabewert und Berechnungskontext festgehalten. Die Elemente
bleiben verbunden, auch wenn sie `display:none` verwenden. Die sieben Suiten
CanvasBackgroundRendering, Backgrounds, CanvasBackground, JavaScriptCSSOM,
JavaScriptTypedOM, VisualCompleteness und RenderingLifetimes bestehen
einschließlich der erforderlichen isolierten Prüfpfade.

Damit erfüllt ausschließlich die vorhandene Registeranforderung
`background-image / canvas-currentcolor` ihre beiden festgelegten Kriterien.
Die gesamte `background-image`-Definition bleibt teilweise zugeordnet.
Insbesondere fehlen weiter die vollständige Bild-/Farbgrammatik, die
Deklarationsbasis relativer Stylesheet-URLs und sämtliche oben benannten
Transform-/Ressourcen-/Effektkombinationen. Für einen nicht vorhandenen
relativen URL-Basisnachweis wird kein erfundener absoluter CSSOM-Wert geliefert.
Die frühere Leerstringgrenze ist für die hier belegten Bilder aufgehoben;
ein vollständiger CSS-Bildserialisierer oder ein Studio-Pixelnachweis ist das
nicht. Die originalen Canvas-Rohbeobachtungen und getrennten normativen
`currentColor`-Rastererwartungen wurden nicht verändert.

Semantik: [berechnete Bildwerte und Serialisierung](https://www.w3.org/TR/2023/CRD-css-images-3-20231218/#serialization),
[Hintergrundbilder](https://www.w3.org/TR/2024/CRD-css-backgrounds-3-20240311/#the-background-image)
und [currentColor](https://www.w3.org/TR/2026/CRD-css-color-4-20261009/#currentcolor-color).

## Abgebrochene native Hintergrundarbeit – 15. Oktober 2026

Ein weiterer tatsächlicher Besitzerfehler ist im vorhandenen
[Backgrounds-Test](../tests/Backgrounds.luau) zuerst reproduziert und dann
behoben: Eine native Bildallokation oder ein Upload konnte den Renderer
abbauen oder dieselbe Box neu zeichnen. Der alte Aufruf setzte anschließend
die Arbeit fort, fügte sein Bild wieder in den bereits geleerten Cache ein
und überschrieb gegebenenfalls den neueren Inhalt. Ein zweiter `Destroy()`
räumte das nachträglich eingefügte Bild nicht mehr auf.

[BackgroundImages](../src/HTMLEngine/Rendering/BackgroundImages.luau) prüft
jetzt den aktuellen Box-/Zeichnungsbesitzer vor und nach diesen nativen
Grenzen. Der vorhandene bandweise Upload erhält denselben Abbruchprüfer.
Veraltete Allokationen werden vor der Rückkehr freigegeben, gelangen weder
in den Cache noch auf eine pensionierte GUI und verändern keine neuere
Zeichnung. Dasselbe gilt nach einem reentranten Bild-/SVG-Resolver. Die
vorhandenen begrenzten Caches und Warteschlangen bleiben die Besitzer.

Neun Kontrollen verbinden Allokation, Upload beziehungsweise URL-Auflösung
mit Rendererabbau, Boxentfernung und unmittelbarer neuer Zeichnung.
Sie prüfen Freigabe, verworfene Uploads, den erhaltenen neueren blauen Inhalt,
erneutes Zeichnen nach Boxentfernung und wirkungsloses Zeichnen nach Abbau.
Backgrounds, CanvasBackgroundRendering, LoadingTextures und RenderingLifetimes
bestehen gemeinsam. Die Registeranforderung `canvas-image-resources` erhält
dafür zunächst einen Teilnachweis und blieb zu diesem Zwischenstand **offen**.
Der folgende Ressourcenabgleich ergänzt die damals fehlenden Lade-, SVG- und
Seitenersetzungsfälle. Beliebige Fehler innerhalb nativer Destruktoren sind
kein zusätzliches Abnahmekriterium dieses Vertrags. Das ist kein Studio-Pixelnachweis.

## Hintergrundressourcen bei Fehlern und Seitenwechseln – 15. Oktober 2026

Die vorhandene Registeranforderung `background-image / canvas-image-resources`
erfüllt jetzt ihre beiden ursprünglichen Kriterien: Der bestehende begrenzte
Gradientcache und die vorhandene serielle SVG-Warteschlange bleiben die
Besitzer; es gibt keinen zusätzlichen Rastercache. Wechsel von Besitzer,
Quelle und Größe, fehlgeschlagene Quellen, ausstehende Arbeit und verspätete
Ergebnisse werden gegen die aktuelle Seite geprüft und geben Bilder einmal frei.

Dafür wurden drei konkrete Fehler zuerst als fehlschlagende Kontrollen gezeigt:
Ein zurückkehrender SVG-Resolver konnte entfernte Arbeit erneut einplanen;
ein ungültig verpacktes SVG ließ seinen Ladefehler aus der Hintergrundzeichnung
entweichen; und eine native SVG-Allokation konnte nach Entfernung ihres
Warteschlangenbesitzers zurückkehren und ohne Cleanup-Handle weiterleben.
[BackgroundSVG](../src/HTMLEngine/Rendering/BackgroundSVG.luau) bindet Resolver
und Installationsrückruf an den aktuellen Bild-/Quellenbesitzer und behandelt
ein fehlerhaftes SVG als ausgelassenes Hintergrundbild mit Diagnose.
[RenderQueue](../src/HTMLEngine/SVG/RenderQueue.luau) prüft eine zurückkehrende
native Allokation vor der Zuordnung an den Slot und verwirft sie bei inzwischen
geänderter Anfrage oder Generation. Die ursprünglichen Fehlerweitergaben
bleiben erhalten. [CanvasBackground](../src/HTMLEngine/Rendering/CanvasBackground.luau)
prüft nach einer Renderer-Rückkehr zusätzlich Lebensdauer und Veröffentlichung:
Ein reentrant neuer Besitzer oder Seitenabbau erhält keine nachträgliche
Veröffentlichung des alten Plans.

Der vorhandene [CanvasBackgroundRendering-Test](../tests/CanvasBackgroundRendering.luau)
nutzt weiterhin echte HTMLPage-, PageSession-, CanvasBackground-,
BackgroundImages-, BackgroundSVG- und RenderQueue-Pfade. Neue Kontrollen verbinden:

- Vier Resolver-Rückwege mit Entfernung, neuer Quelle, HTML-/Body-Besitzerwechsel
  und Seitenabbau.
- Fünf ausstehende Quellen-/Größen-/Besitzerwechsel einschließlich fehlender
  Zuordnung und fehlerhaftem SVG sowie sechs absichtlich verspätete Rasterergebnisse
  einschließlich vollständiger Seitenersetzung auf demselben Host.
- Drei während einer nativen Allokation pensionierte Anfragen und zwei native
  Allokations-/Uploadfehler mit erfolgreichem Wiederholen derselben Quelle und Größe.
- Unveränderte ausstehende Zeichnungen und Rückkehr zu einer früheren Quelle:
  eine Szene, ein Raster und ein natives Bild werden wiederverwendet.

Die Prüfungen verlangen aktuelle Seiten-/Canvasidentitäten, freigegebene
Präsentationsbereitschaft, keine Veröffentlichung alter Pixel und genau eine
Freigabe je nativer Allokation. Die bestehenden 64-Einträge-Gradientgrenzen,
gebundenen Benutzer, Uploadband-Abbrüche und begrenzten SVG-Cache-/Metadatenprüfungen
bleiben erhalten. Sechs passende HTML-Suiten einschließlich isoliertem
Rendering-Lifetime-Pfad sowie die vollständige SVG-Suite bestehen. Nur GUI,
Schriftmessung, native Bildallokation und der kleine rote/blaue Rasterbackend
sind kontrollierte Testadapter. Die unabhängigen Browserrohbeobachtungen wurden
nicht geändert; diese Lebensdauerprüfung behauptet keine Pixelgleichheit in Studio
und keinen Abschluss der anderen `background-image`-Anforderungen.

## Lebende Canvasfläche und Compositorwechsel – 16. Oktober 2026

Die ursprünglichen beiden Kriterien von `canvas-live-lifecycle` sind jetzt
belegt. 24 zusätzliche unabhängige Chrome-155-Zustände verbinden Hover,
Mediaquery-Besitzerwechsel, Container-Stilqueries, Dokumentwachstum,
`color-scheme` und transparente Hintergründe. Dieselben Operationen laufen
durch tatsächliche Runtime-/HTMLScripts-/Controller-/RenderTree-/Layoutpfade.
Root, Body, Canvas, Paintbox und nativer Editor bleiben erhalten; Wert, Fokus,
rückwärts gerichtete UTF-16-Auswahl und Listener bleiben unverändert.
Paintänderungen lösen weder Layout noch Textmessungen aus. Frisch aufgebaute
Endzustände werden getrennt mit den nativen Pixeln verglichen. Ein eingefügter
900px-Nachfahre vergrößert dieselbe Canvasfläche; Entfernen stellt sie wieder her.

Drei weitere native Kontrollen ersetzen eine Wurzel mit Opacity, Filter oder
Maske. Dabei wurde ein echter Besitzerfehler reproduziert: Die dokumenteigene
Canvasfläche lag im alten Compositor und wurde mit dessen GUI zerstört.
[DOMReconcile](../src/HTMLEngine/Rendering/DOMReconcile.luau) lässt
[CanvasBackground](../src/HTMLEngine/Rendering/CanvasBackground.luau) die Fläche
jetzt vor Ressourcen-/GUI-Abbau herausnehmen. Eine geänderte
Veröffentlichungsgeneration entwertet den alten Auftrag. Ersetzen, vollständiges
Entfernen und Wiedereinfügen der Wurzel behalten dieselbe Canvasfläche; ein
leeres Dokument zeigt ausschließlich die gespeicherte UA-Fläche.
Der Vorherfehler bleibt in `build/canvas-grouped-root-before-fix.luau` erhalten.
Die bereits belegten verspäteten SVG-/Bildveröffentlichungen, Seitenersetzung
und Dispose-Kontrollen bleiben Teil desselben Nachweises.

Die zusätzlichen Rohdaten stehen unter `liveCanvas` in der bestehenden
[Browserreferenz](../tests/fixtures/canvas-background-browser.json).
[Der additive Capture](../scripts/capture-canvas-live-reference.cjs) verändert
keine ursprünglichen Fälle. Neun ergänzende native CSSOM-Beobachtungen belegen
`color-scheme`, Vererbung und die Reihenfolge der bekannten Light-/Dark-Werte;
`only` wird am Ende serialisiert. Benutzerdefinierte Scheme-Namen sind damit
nicht vollständig implementiert. Ein nichtweißer, teilweise transparenter
ursprünglicher Hosthintergrund wird nach Dark-/Autorenpaint-Rücknahme exakt
wiederhergestellt.

Die Innerhalb-Proben der Effektbox deckten außerdem einen falschen
Prozentbezug von `circle()` auf: Die Rasterabdeckung verwendete die kürzere
Seite. Sie verwendet jetzt die normalisierte Diagonale, wie
[CSS Shapes 1 vom 12. Juni 2025](https://www.w3.org/TR/2025/CRD-css-shapes-1-20250612/#funcdef-circle)
festlegt. Beide Rasterabdeckungswege besitzen gemeinsame horizontale und
vertikale Rechteckregressionen. Das vervollständigt weder die gesamte
Shape-Grammatik noch beliebige Clip-/Filter-/Backdropkombinationen.

Sieben betroffene Suiten einschließlich isolierter CSSOM-/Renderer-Lifetime-
Prüfungen bestehen. Native Studio-Pixel, transformierte unendliche Canvasflächen,
die besondere lokale Framesetdarstellung und die übrigen offenen Anforderungen
bleiben getrennt. Dieser Nachweis ist kein vollständiger CSS-Abschluss.

## Inline-Body und tatsächliche Wurzel – 16. Oktober 2026

Ein als `inline` deklarierter tatsächlicher Dokumentroot wird jetzt vor dem
Boxaufbau blockifiziert; `contents` wird ebenfalls zu `block`, `inline-table`
zu `table`. Damit kann die Canvasfläche auch bei einer solchen Deklaration
an der tatsächlichen Rootbox ausgerichtet werden.
[CSS Display 3, Abschnitt 2.8](https://www.w3.org/TR/css-display-3/#transformations)
ist die Grundlage. Das ist kein Nachweis für sämtliche Displaytypen.
Der ältere öffentliche `Parser.parse`-Aufruf liefert weiterhin einen flachen
Fragmentcontainer. Dessen erstes Element wird dadurch nicht zur CSS-Dokumentwurzel.
Auch die Canvasplanung schließt diesen Container aus: Inline- und Inline-Block-
Hintergründe bleiben lokal, erhalten keine Canvas-Unterdrückung und überschreiben
weder die übrige Hostfläche noch deren UA-Farbe. Ein als tatsächlicher Dokumentroot
eingefügtes gleiches Element besitzt weiterhin die dokumentweite Canvaszeichnung.
Eine interne Markierung bleibt beim Klonen dieses Containers erhalten und wird
bei vollständigem Neuparsen mit `document.open` entfernt. Tatsächliche gebaute
Dokumente mit HTML-, fremden oder frei konstruierten Rootnamen werden weiterhin
blockifiziert. Die ursprüngliche Forms-Fokusumrandung bleibt unverändert geprüft.

Ein propagierender Inline-Body darf seinen bereits auf die Canvasfläche
übertragenen Hintergrund nicht noch einmal auf Wortfragmenten malen. Die
verwendete Inlinefarbe behält deshalb die Herkunft ihrer Beiträge. Beim
Zeichnen wird ausschließlich der aktive Canvasbesitzer ausgelassen; eigene
Hintergründe von Nachfahren bleiben erhalten. Der ursprüngliche deklarierte
und berechnete Hintergrund wird dabei nicht verändert. Schwache Benutzerlisten
werden nur für den tatsächlichen Root und direkte HTML-Bodys geführt; eine
deckende Nachfahrenschicht beendet die weitere Zusammensetzung. Bei einem
Besitzerwechsel werden die betroffenen vorhandenen Wort-GUIs neu bemalt.

Die unabhängige Chrome-155-Aufnahme zeigt bei einem Inline-Body selbst eine
doppelte halbtransparente Hintergrundzeichnung. Diese ursprünglichen Pixel
bleiben in der [separaten Referenz](../tests/fixtures/canvas-inline-background-browser.json)
unverändert erhalten. Die Engine folgt hier ausdrücklich der ursprünglichen
[Backgrounds-3-Regel für den verwendeten Bodyhintergrund](https://www.w3.org/TR/2024/CRD-css-backgrounds-3-20240311/#special-backgrounds).
Zusätzlich aufgenommene native Gegenstücke legen denselben Hintergrund auf
den Root und setzen den Body transparent. Nur diese ausdrücklich bezeichneten
Gegenstücke liefern die erwarteten Pixel für die einmalige Canvaszeichnung;
sie ersetzen oder normalisieren keine Rohbeobachtung.

[CanvasInlineBackground](../tests/CanvasInlineBackground.luau) prüft 16
Anfangs- und Änderungszustände durch echte Parser-, Runtime-, RenderTree-,
Text- und Layoutpfade: Inline-Body, Inline-Root, halbtransparente und deckende
Nachfahren, Root-/Body-Besitzerwechsel, unveränderte berechnete Hintergrundwerte
sowie Identität von Canvasfläche und Wort-GUIs. Vier zusätzliche Zustände
prüfen nachträglich hinzugefügte, entfernte und wiederhergestellte
Nachfahrenhintergründe auf bereits vorhandenen Wortfragmenten. Ein zuvor
leerer Dekorationscache wird dabei erneuert; auf Fragmentrahmen gemalte
Eigentümerhintergründe werden auf den Wörtern nicht ein zweites Mal aufgetragen. Der
[additive Capture](../scripts/capture-canvas-inline-background-reference.cjs)
verweigert das Überschreiben bereits eingefrorener Fälle. Native Schriftpixel
werden durch transparenten Text ausgeklammert. Diese begrenzte Korrektur
schließt weder alle Alpha-/Effektkombinationen noch den gesamten CSS-Plan ab.
Zwölf zusätzliche montierte Anfangs-/Änderungskontrollen vergleichen lokale
Fragmenthintergründe mit einem tatsächlichen konstruierten Root. Transparente
Farben werden innerhalb und außerhalb der lokalen Box geprüft; Entfernen und
Wiederherstellen behalten dieselben Wort- und Box-GUIs.
Acht weitere montierte Zustände prüfen ein anfangs wurzelloses tatsächliches
Dokument sowie den Wechsel eines Legacycontainers durch `document.open`:
Die noch leere Fläche verändert die Hostfarbe nicht. Einfügen, Entfernen und
Wiedereinfügen des ersten Roots behalten die dokumenteigene Canvasfläche und
stimmen mit jeweils frisch aufgebauten vollständigen Renderbäumen überein.
Entfernte Root-/Wort-GUIs werden freigegeben; spätere reine Farbänderungen
behalten die neu aufgebauten GUIs. Ein `DocumentFragment` erhält keine Canvasfläche.
