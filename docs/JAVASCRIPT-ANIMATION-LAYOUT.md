# WAAPI: Layoutwerte und zusammengesetzte Effekte

Stand: 10. Oktober 2026. Ergänzung zu P09 und Fachprofil für C08. Grundlage sind [Web Animations Level 1](https://www.w3.org/TR/web-animations-1/), [Web Animations Level 2](https://www.w3.org/TR/web-animations-2/), [CSS Transforms: Interpolation, Addition und Accumulation](https://www.w3.org/TR/css-transforms-1/#interpolation-of-transforms), [CSS Transforms 2, individuelle Eigenschaften, Entwurf vom 30. November 2025](https://drafts.csswg.org/css-transforms-2/#individual-transforms) und [CSS Values and Units 5, Entwurf vom 4. September 2026](https://drafts.csswg.org/css-values-5/#interpolate-size).

## Einordnung

Die Script-Animationen verwenden dieselben CSS-Werte und dieselben behaltenen Boxen wie das normale Layout. Das erweiterte Profil umfasst Breite/Höhe, physische und logische Min-/Max-Maße, Positionierungsabstände, Margin/Padding, Flex-Basis/Grow/Shrink, Zeilen-/Spaltenabstände, Buchstaben-/Wortabstände, Order und Spaltenmaße, physische Rahmenbreiten sowie vererbte Schriftgröße/Zeilenhöhe mit abhängigen relativen Maßen. Transform, individuelle Translate/Rotate/Scale-Werte, Transform-Origin, Offset-Distance, Opacity, Hintergrundfarbe, Außenkonturbreite/-abstand die vier physischen Eckenradien sowie Box- und scharfe Textschattenlisten bleiben Paint-Effekte.

Die Autorwerte werden getrennt von den abgetasteten Werten aufbewahrt. Ein neuer Frame darf den letzten Frame deshalb nicht als neuen Ausgangswert verwenden. Ändert JavaScript während einer additiven Animation die Autorbreite, wird der nächste abgetastete Wert mit dieser neuen Breite kombiniert. `cancel()` stellt den aktuellen Autorwert wieder her.

Layoutwerte markieren die betroffene Box und ihre Abhängigkeiten als schmutzig. Ein synchroner Geometriezugriff veröffentlicht das ausstehende Layout, danach verwenden unveränderte weitere Zugriffe die veröffentlichten Werte. Transform-/Opacity-Abtastungen verändern Paint und aktuelle CSSOM-Werte ohne eigenes Neulayout. Ein pausierter Effekt behält keine Animation-Frame-Anforderung.

## Composition und Commit

`composite:'add'` und `'accumulate'` folgen dem jeweiligen Werttyp. Längen/Zahlen werden addiert. Transform-Addition verkettet Operationen, Accumulation kombiniert passende Funktionen: Scale akkumuliert relativ zur Identität `1`, statt die Faktoren zu multiplizieren. Individuelle `translate`/`rotate`/`scale`-Eigenschaften bleiben von der animierten `transform`-Eigenschaft getrennt und werden einmal auf das Ergebnis angewendet. Keyframe-eigene Composite-Werte und implizite Endpunkte sind Teil derselben Abtastung.

`commitStyles()` schreibt den berechneten Wert in die Inline-Deklaration. Bei einem weiterhin aktiven additiven Effekt kann das **vor** `cancel()` eine weitere Addition ergeben; der Browser zeigt bei einer Autorbreite von `100px` und einem additiven Effekt von `20px` nach Commit `140px`, nach Cancel `120px`. Das ist keine Zusage, dass Commit allein einen additiven Effekt visuell einfriert.

Wichtige Deklarationen behalten ihre Cascade-Priorität. Opacity-Endpunkte und Zwischenwerte der Effektkette bleiben für die Composition ungeklammert; erst der verwendete Endwert wird auf `0..1` begrenzt.

## Ausdrückliche Browser-/Profilgrenze

`KeyframeEffect.iterationComposite` ist eine Level-2-Erweiterung. Das hier erfasste Chromium bietet die Eigenschaft nicht an: die Konstruktoroption wird ignoriert, ein Setter erzeugt nur eine eigene Eigenschaft. Die Engine implementiert die beschriebene Iterationsakkumulation. Die drei entsprechenden Fixture-Fälle enthalten deshalb getrennte `nativeExpected`- und `engineExpected`-Werte und gelten **nicht** als visuelle Chromium-Gleichheitstests.

Die native Null-Dauer-Referenz enthält 24 Fälle mit `iterations:0/1/2/Infinity`, `iterationStart:0/.3` und Zeitpunkten vor/auf/nach dem Ende. Bei Null-Dauer mit unendlichen Iterationen ist `currentIteration` nach dem Ende tatsächlich `Infinity`, die aktive Dauer aber `0`. Die Engine erhält diese Zeitangaben. Ein nichtendlicher Wiederholungszähler darf keinen unendlichen Host-Loop oder nichtendliche Transformwerte erzeugen; für die Level-2-Akkumulation verwendet das begrenzte Profil in diesem Sonderfall den aktuellen Ersatzwert.

Ein verbundener Shadow-Target darf animiert werden und Styles committen. Die Animation-Enumeration folgt jedoch dem DOM-Baum ihres Tree-Scope: `document.getAnimations()` und `host.getAnimations({subtree:true})` überschreiten die Shadow-Grenze nicht. Das ist getrennt von der Shadow-inklusive Verbundenheitsprüfung beim Rendern/Commit.

## Vergleich und Prüfung

`tests/fixtures/animation-layout-reference.html` enthält die ausführbaren Quellen für 24 deterministisch pausierte Fälle. `animation-layout-native.json` enthält die tatsächliche Browserausgabe. `javascript-animation-layout.json` übernimmt die 21 gemeinsamen Ergebnisse und kennzeichnet die drei Level-2-Abweichungen ausdrücklich. `animation-zero-duration-reference.html` und `animation-zero-duration-native.json` halten die zusätzliche Timing-Referenz fest.

`animation-context-reference.html`/`animation-context-native.json` ergänzen drei native Fälle: Opacity aus Variablen bleibt bis zur Composition ungeklammert; Prozentgrößen mit `min()`/`max()` erhalten ihre Ausdrücke über Commit/Cancel und eine spätere Änderung der Containerbreite. Die gemeinsame Ausgangsgruppe enthält 23 Browserreferenzen und drei explizite Level-2-Erweiterungen; die nachfolgenden C08-Abschnitte erfassen die weiteren Fälle.

`JavaScriptAnimationLayout` verbindet Runtime, CSSOM, echten RenderTree, DirtyLayout und Animation-Adapter. Der Test prüft CSSOM-Geometrie sowie die gemalten nativen GUI-Maße/Positionen, live geänderte Autorwerte, Cancellation, Commit, wichtige Deklarationen, Prozent-/Pixel-Mischungen, Transform-Reihenfolge, Shadow-Targets und das Entfernen von Frame-/Task-Anforderungen beim Zerstören. Er führt keine FPS-Messungen durch.

Folge-Layouts restaurieren den zuletzt veröffentlichten lokalen Script-Animationszeitpunkt. Sie lesen die Uhr nicht erneut, um ein neues Sample zu erzeugen. Der nächste Frame sowie explizite Timing-/API-Änderungen veröffentlichen neue Samples; direkte `commitStyles()`-Abfragen lesen weiterhin den aktuellen Zustand. CSS-Effekte verwenden dieselbe Trennung zwischen Frame-Abtastung und Layout-Repaint. `JavaScriptWebAnimations` prüft den Script-Fall mit einer zwischen Layoutveröffentlichungen veränderten Uhr. `HTMLPageAnimationScheduling` verbindet den tatsächlichen Page-Worker mit RenderTree, BlockLayout und CSS-Runtime: eine während der Ausführung voranschreitende Uhr und unendliche Größen-Keyframes müssen innerhalb eines Frames zur Ruhe kommen, ohne Boxen zu ersetzen oder nach Cancellation eine Frame-Verbindung zu behalten.

## C08: Intrinsische Höhe und ganzzahlige Layoutwerte – 9. Oktober 2026

CSS-Keyframes und WAAPI verbinden jetzt `height:auto` mit einer numerischen
Höhe bei `interpolate-size:allow-keywords`. `block-size` verwendet denselben
Pfad im horizontalen Schreibmodus. Das vorhandene Blocklayout behält die
natürliche Inhaltsausdehnung vor der Anwendung einer festen Höhe; die Abtastung
liest diesen Wert und verwendet nicht die vorige animierte Höhe als Endpunkt.
Damit bleiben Inhaltsänderungen während eines pausierten Effekts wirksam,
ohne eine wiederholte Layout-/Animationsrückkopplung zu erzeugen.

Vererbung der Freigabe, beide Richtungen, implizite Endpunkte, Content-/Borderbox,
Prozent-/Pixel-Mischungen, additive und akkumulative numerische Ausgangswerte,
gestapelte Effekte und Cancellation sind geprüft. `numeric-only` behält den
diskreten Wechsel. Die Freigabe wird beim Start des Effekts gespeichert;
spätere Änderungen an `interpolate-size` starten keine Interpolation nachträglich
und beenden keine bereits vorhandene. Überschießende Timingfunktionen behalten
ihre Extrapolation; nur am exakten Endpunkt wird das intrinsische Keyword
wiederhergestellt. Negative verwendete Größen begrenzt weiterhin das Layout.

`order`, `column-count` und `column-width` gehören zusätzlich zum gemeinsamen
CSS-/WAAPI-Sampler. Ganzzahlige Zwischenwerte runden zum nächsten Integer, bei
einem Gleichstand in Richtung positiver Unendlichkeit; `column-count` behält
die Untergrenze 1. `auto`-Wechsel der Spaltenmaße bleiben diskret. Der normale
Spaltenrenderer behält sein dokumentiertes Größen-/Fragmentierungsprofil.
`getComputedStyle()` veröffentlicht die Werte; `commitStyles()` schreibt Integer
ohne versehentliches `px` und Spaltenbreiten als Längen. Eine animierte Flex-
Reihenfolge verändert das wirkliche Layout, erhält aber DOM-/Fokusreihenfolge,
die bestehenden GUIs, live Textboxwerte und deren Cursor/Auswahl.

Der Review fand außerdem eine allgemeine Ausgangswertlücke: Ein neuer Autorwert
kann zufällig dem aktuellen Animationssample gleichen. Die reine Transform-
Optimierung darf dann keine unveränderte Kaskade annehmen, weil der gespeicherte
Ausgangswert noch anders ist. Boxen mit abgetasteten Layoutfeldern verwenden bei
einer Autoränderung die normale Recascade, die zuerst den Ausgangswert restauriert.
Die Browserfälle `order:2` mit additiver Zwischenposition `4`, anschließend
Autorwert `4`, sowie Breite `100→130`, anschließend Autorwert `130`, belegen
die nächste Addition und die korrekte Rückgabe nach `cancel()`.

Der Ausgangswertgetter liest gespeicherte Felder direkt. Er klont nicht mehr für
jede einzelne Eigenschaft den vollständigen Stil einer animierten Box.
Die Änderungen erzeugen keine zusätzliche permanente Frame-Verbindung und
keine Messprobe, welche die gehaltenen GUIs vorübergehend verschieben könnte.

Nachweis: [capture-animation-intrinsic.cjs](../scripts/capture-animation-intrinsic.cjs)
erfasst in einem isolierten Chromium 27 zusätzliche WAAPI-Fälle und sechs
pausierte CSS-Keyframe-Fälle. Quelle und unveränderte Browserausgabe stehen in
[animation-intrinsic-native.json](../tests/fixtures/animation-intrinsic-native.json).
Die gemeinsame [WAAPI-Fixture](../tests/fixtures/javascript-animation-layout.json)
enthält nach diesem Teilschritt 50 native Referenzfälle und drei ausdrücklich getrennte Level-2-
Erweiterungen. [JavaScriptAnimationLayout](../tests/JavaScriptAnimationLayout.luau)
prüft zusätzlich behaltene tatsächliche Flex-/Control-GUIs, Auswahl, Cache und
Cancellation; [CSSLayoutAnimations](../tests/CSSLayoutAnimations.luau) prüft
die sechs CSS-Mittelpunkte, Inhaltswechsel und lokale Veröffentlichungskonvergenz.
Die gezielte Gruppe mit diesen beiden Suiten, `JavaScriptAnimationCommit`,
`HTMLPageAnimationScheduling`, `CSSInitial` und `JavaScriptCSSOM` besteht.
Dies ist eine Ersatzobjekt-/Runtimeprüfung, keine native Studio-Pixel- oder FPS-
Abnahme.

## C08: Individuelle Transformationen – 9. Oktober 2026

`translate`, `rotate` und `scale` haben jetzt jeweils einen eigenen Paint-Kanal
für CSS-Keyframes, CSS-Transitions und WAAPI. Die Autorwerte bleiben unverändert;
die abgetasteten Operationen stehen vor der separat animierten `transform`-Liste.
`getComputedStyle().transform` enthält daher keine zusätzliche individuelle
Transformation. Gleichzeitige Größenänderungen verwenden weiterhin die behaltene
Referenzbox. Animationstakte der individuellen Eigenschaften fordern kein eigenes
normal-flow-Layout an; andere DOM-/Autoränderungen können weiterhin Layout benötigen.

`none` ist ein wirklicher Stop. Gegen einen anderen Wert entspricht er der
Identität; `none` gegen `none` bleibt `none`. Translate interpoliert und addiert
X/Y-Längen/Prozente und eine Z-Länge. Prozent-/`calc()`-Anteile bleiben auch über
`commitStyles()` erhalten. Scale unterstützt unterschiedliche und negative
X/Y/Z-Werte und Prozentnotation. Individuelles Add **und** Accumulate multiplizieren
Skalen; die Identität-basierte Accumulation einer `transform:scale()`-Liste bleibt
ein anderer Werttyp. Gleiche normalisierte Drehachsen interpolieren den Winkel,
einschließlich vollständiger Umdrehungen. Unterschiedliche Achsen verwenden
Quaternion-SLERP und Quaternion-Composition. Eine Nullachse wirkt als Identität;
kleine, aber von Null verschiedene Vektoren werden stabil normalisiert. Der
Parser akzeptiert den Winkel vor oder nach seiner optionalen Achse und
wissenschaftliche Winkelnotation.

CSS-Transitions verwenden die tatsächlich abgetasteten individuellen Vorherwerte
für Unterbrechung und verkürzte Umkehr. Ein Wechsel von `translate` startet keinen
Übergang der unabhängigen `transform`-Eigenschaft. CSS-Lower-Stack, Script-Stack
und Commit haben getrennte Ausgangswerte; Cancel legt den noch bestehenden CSS-
Effekt unmittelbar frei. Autor-Importance, Vererbung, Variablen und relative
Längen werden im aktuellen Zielkontext ausgewertet.

Der Pipeline-Review hat zwei allgemeine Fehler behoben. Ein durch Animation neu
angelegtes 3D-Raster wird beim Rückweg zu nativem 2D-Paint verborgen; seine
behaltenen Quell-GUIs und deren native Eingaben werden restauriert und der
projizierte Trefferregistereintrag entfernt. Außerdem veröffentlicht eine
erfolgreiche reine Paint-Recascade im JavaScript-Runtime sofort die gehaltenen
Script-Samples wieder. So liest ein nachfolgendes `getComputedStyle()` im selben
Script aktuelle Variablenwerte, ohne einen neuen Frame oder ein Flow-Layout
abzuwarten. Die Veröffentlichung verwendet den gehaltenen Animationszeitpunkt.

[capture-animation-individual.cjs](../scripts/capture-animation-individual.cjs)
erfasst 47 zusätzliche Referenzen in einem isolierten Chromium. 45 werden über
denselben RenderTree-/Runtime-/CSSOM-Pfad verglichen, darunter sechs reine
CSS-Keyframe-Fälle. Die gemeinsame Fixture enthält insgesamt **95 bestandene
native Referenzen, drei getrennte Level-2-Erweiterungen und zwei Browser-only-
Referenzen**. Die tatsächliche Zahl ist im Suite-Ergebnis ausgewiesen; ausgeschlossene
Referenzen zählen nicht als bestandene Enginefälle.

Die beiden offenen Vergleiche sind ausdrücklich erhalten:

- `individual individual CSS lower and script upper`: Das erfasste Chromium
  meldet bei einem pausierten CSS-Rotate-Lower-Stack von `30deg` und dem
  additiven Script-Mittelpunkt `10deg` den Wert `5deg`; Translate und Scale
  kombinieren dabei ihre unteren Werte. Die Engine komponiert Rotate zu
  `40deg`. Der gekoppelte Engine-Pfad, Commit und Cancel sind separat geprüft;
  die Browsergleichheit dieser Kombination bleibt offen. Die Ursache des
  Browserergebnisses ist bisher nicht belegt.
- `individual rotate tiny angle serialization`: Für den Mittelpunkt zwischen
  `0deg` und `2e-8deg` serialisiert Chromium `0deg`, die Engine erhält den
  Winkel `1e-8deg`. Exakte numerische Serialisierung an dieser Präzisionsgrenze
  ist noch nicht abgeglichen; dies ist keine visuelle Abweichungsabnahme.

`JavaScriptAnimationLayout` lädt auch echte projizierte Raster, prüft die
behaltene Textur-/GUI-Identität, ausbleibende neue Uploads für unveränderte
Samples und `ProjectiveHit.pick()` auf der gemalten nichtuniformen Scale-Fläche.
Cancel muss die alte Hit-Fläche entfernen, und Teardown zerstört die zugehörigen
EditableImages genau einmal. `CSSLayoutAnimations` prüft eigenständige und
gleichzeitige Kanäle, Umkehr, CSS-Composition, kombinierte Script-/CSS-Werte,
Commit und Restore ohne neue Flow-Aufrufe. Framefreie Pause, Cancel, Snapshot-
Disposal und bestehende 2D-/3D-Pfade sind Bestandteil der gezielten Prüfgruppe.
Dies ersetzt weiterhin keine native Studio-Pixel-/FPS-Abnahme.

## C08: Durch Animation erzeugte Containing-Blocks – 9. Oktober 2026

Transformationsanimationen erzeugen den Bezugspunkt für absolut und fest
positionierte Nachkommen auch dann, wenn ihre aktuelle Transformation die
Identität oder `none` ist. Das folgt aus dem impliziten `will-change` für
aktuelle oder wirkende Effekte in [Web Animations § 5.6](https://www.w3.org/TR/web-animations-1/#side-effects-of-animation)
und [CSS Animations](https://www.w3.org/TR/css-animations/). Die Wertprobe
allein reicht deshalb nicht aus. `translate`, `rotate`, `scale` und `transform`
veröffentlichen ihren Effekt-Lifecycle getrennt vom Autorstil. Startverzögerung,
Pause, Importance, Forward-Fill, unfilled Completion, Cancel und ein noch
bestehender unterer Effekt werden dabei berücksichtigt. Ein pausierter CSS-
Effekt nach seiner aktiven Phase malt ohne Forward-Fill keine Endprobe mehr.

`PositionedLayout` und die Anchor-Registry verwenden diese abgeleitete
Renderbox-Abhängigkeit. Sie verändern keine DOM-Attribute oder Autorwerte.
Nur ein Wechsel des wirksamen Bezugspunkts mit positionierten Nachkommen
fordert ein lokales Layout an. Gewöhnliche Samples, Pause und Forward-Fill
behalten die Positionierungsgeometrie. Der Cache der Positionierung prüft
zusätzlich Identität und Geometrie des festen Bezugspunkts.

[capture-animation-containing.cjs](../scripts/capture-animation-containing.cjs)
enthält **22 isolierte Chromium-Referenzen**, darunter sechs CSS-Fälle. 21
werden im gemeinsamen DOM-/Runtime-/Positionierungspfad bestanden. Geprüft
sind absolute und feste Kinder, Padding-/Prozentbezüge, ein innerer relativer
Container, `none`-Stops, Importance, Delay/Fill und die Rückkehr zum unteren
Effekt. Same-Script-Geometrie liest den angeforderten Layoutwechsel sofort.
Die gehaltenen GUI-/Input-Identitäten und die native Textauswahl bleiben
erhalten. Der feste Nachkomme kehrt aus demselben Viewport-Overlay in seinen
ursprünglichen GUI-Baum und bei Cancel in dasselbe Overlay zurück. Diese
WAAPI-Probe benötigt genau einen zusätzlichen lokalen Layoutpass bei Entry
und einen bei Cancel, unabhängig von der Zahl der Zwischenproben. Die CSS-
Probe trennt die bereits erforderliche Autorstil-Veröffentlichung von ihrem
einen zusätzlichen Positionierungspass. CSS-/Script-Teardown entfernt die
Effekt-Abhängigkeiten und lässt keine idle Frame-Verbindung zurück.

Ein weiterer Vergleich bleibt ausdrücklich offen:

- `containing reversed after phase current`: Beim pausierten ungefüllten
  Effekt nach der aktiven Phase erzeugt der synchrone Wechsel auf negative
  Playback-Rate in Chromium keinen neuen Bezugspunkt. Die Engine berücksichtigt
  den Effekt als `current`, entsprechend [Web Animations § 4.5.5](https://www.w3.org/TR/web-animations-1/#animation-effect-phases-and-states),
  und erzeugt diesen Bezugspunkt. Die Browserreferenz ist vollständig gespeichert
  und als Browser-only ausgeschlossen. Die Ursache dieser Abweichung ist noch
  nicht belegt; die Engine enthält keine besondere Chrome-Fallkorrektur.

Der gemeinsame Fixture-Stand beträgt damit **116 bestandene native Referenzen,
drei getrennte Level-2-Erweiterungen und drei Browser-only-Referenzen**. Die
Zahl im vorangehenden individuellen Slice beschreibt dessen damaligen Stand.
Diese Ergebnisse schließen weder vollständige neue Stacking-Contexts noch
sämtliche Scroll-/View-/Pseudo- oder andere Paint-Wertfamilien ein.

## C08: Rahmenbreiten, Außenkonturen und Eckenradien – 9. Oktober 2026

Die vier physischen `border-*-width`-Longhands und `border-width`-Keyframes
laufen durch denselben CSS-/WAAPI-Stack. Ein Wert ändert die tatsächlichen
Randstreifen, die Boxgröße und abhängige lokale Geometrie. Die Rundung gehört
zum verwendeten Endwert: Im erfassten Chromium-Profil werden positive Breiten
unter einem Pixel auf ein Pixel und größere Breiten auf ganze Pixel nach unten
begrenzt. Die Stops selbst behalten ihre Bruchteile; der additive Ausgangswert
verwendet die berechnete Randbreite. `none`/`hidden` reservieren keinen Platz,
während Commit den gesampelten Breitenwert erhalten kann. Eine Änderung nur
einer Seite darf die anderen Seiten und deren Importance nicht beeinflussen.

`outline-width` und der vorzeichenbehaftete `outline-offset` verwenden den
gleichen Sampler, ohne Platz im Flow zu erzeugen. Vorhandene Outline-GUIs und
die native Textbox bleiben erhalten. Geänderte Outsets aktualisieren die
Compositing-Grenzen der betroffenen Opacity-Gruppen. Dabei bleibt die aktuell
gemalte Transformation erhalten; die Dekorationsprobe darf eine parallel
laufende Transform-Transition nicht auf ihren Autorendwert zurücksetzen.

Die vier physischen `border-*-radius`-Longhands interpolieren ihre X-/Y-Längen
und Prozentanteile getrennt. `border-radius`-Keyframes expandieren zu diesen
Longhands; `transition:border-radius` wählt dieselben vier Kanäle. Replace,
Add, Accumulate, unabhängige wichtige Ecken, laufende Autoränderungen und
Commit/Cancel sind Bestandteil des begrenzten Profils. Reine negative
Pixel-/Prozentproben einer überschießenden Timingkurve werden am Endwert auf
Null begrenzt; eine reine Prozentnull bleibt bei Commit `0%`. Prozent-/`calc()`-
Anteile bleiben relativ zur Borderbox. Die verwendeten Radien und ihre
Überlappungsbegrenzung berechnet weiterhin der vorhandene Corner-Renderer;
siehe [CSS Backgrounds § 4](https://www.w3.org/TR/css-backgrounds-3/#border-radius).
Dies erweitert die Animation, nicht das dokumentierte native/Raster-Paintprofil.
Transparente Clipping-Umgebungen und Bildhintergründe behalten dessen Grenzen.

Absolute kreisförmige Ecken verwenden UICorner. Elliptische Ecken verwenden die
vorhandene antialiaste Rasteroberfläche. Bei gleicher Atlasgröße wird dieselbe
EditableImage aktualisiert, statt sie pro Radiusprobe neu anzulegen. Eine
unveränderte Probe führt weder einen Upload noch einen neuen GUI-/Layoutaufbau
aus. Neue Radiusproben, die Rückkehr zu einer nativen Form, DOM-Entfernung und
Disposal invalidieren laufende Rasterarbeit. Generation-/Lifetime-Prüfungen
vor dem Upload und seiner Veröffentlichung verhindern, dass ältere Arbeit
neue Pixel oder bereits zerstörte Ressourcen überschreibt.

[capture-animation-numeric.cjs](../scripts/capture-animation-numeric.cjs)
enthält **32 isolierte native Referenzen**: 19 für Breiten/Außenkonturen und
13 für Eckenradien. Quelle und unveränderte Browserausgabe stehen in der
gemeinsamen [Fixture](../tests/fixtures/javascript-animation-layout.json).
Der historische gemeinsame Stand nach diesem Slice beträgt **148 native Vergleichsfälle,
drei explizite Level-2-Erweiterungen und drei Browser-only-Referenzen**.
`JavaScriptAnimationLayout` prüft zusätzlich gemalte Seitenstreifen,
native einzelne Ecken, transparente/opaque Ellipsenpixel, Bild-/GUI-Wiederverwendung,
native Inputauswahl, lokale Cache-Wiederverwendung und framefreie Pause/Cancel.
`RenderingLifetimes` interleaved neuere Proben vor/während/nach der
Texture-Upload-Grenze sowie Native-Fallback, Remove und Destroy. Die betreffende
Bildressource muss genau einmal zerstört werden. Die gezielte Regressionsgruppe
umfasst außerdem `Animations`, `CSSLayoutAnimations`, `BorderCorners`,
`ControlBorders` und `HoverBorders`. Diese Ersatzobjektprüfungen ersetzen keine
native Roblox-Pixel-/FPS-Abnahme.

Nicht erfasst sind vollständige logische Corner-/Border-Aliase als
Animationskanäle, sämtliche weiteren Border-/Outline-/Shadow-Painttypen,
alle gemischten mathematischen Range-Clamps. Der nachfolgende Schrift-Slice
ergänzt vererbte `font-size`/`line-height`-Metriken über den tatsächlichen
Text-/Input-/Layoutpfad; er registriert keine bloße skalare Feldänderung.

## C08: Vererbte Schriftgröße und Zeilenhöhe – 9. Oktober 2026

Grundlage sind die bestehenden Font-/Layoutprofile sowie
[CSS Fonts: font-size](https://drafts.csswg.org/css-fonts-4/#font-size-prop)
und [CSS Inline Layout: line-height](https://drafts.csswg.org/css-inline-3/#propdef-line-height).
Die nachgewiesenen Animationsziele besitzen eine gerenderte Layoutbox.
Die Schriftprobe fließt vor der Auflösung abhängiger `em`-/`rem`-Maße in
die bestehende Kaskade ein. Betroffene vererbte Stile, Zeilenboxen,
Textmessungen und native Inputmetriken werden auf denselben GUI-Objekten
erneuert. Relative Zielbreiten/-höhen und Padding, anders große Nachkommen,
Root-`rem` sowie gleichzeitig animierte Eltern/Kinder sind erfasst.

Zeilenhöhen behalten ihren Werttyp: Zahlen werden als Multiplikatoren
vererbt, Längen als berechnete Längen. Zahl ↔ Länge und `normal` ↔ numerisch
wechseln diskret. Lineare `px`-/`em`-/`rem`-/Prozent-/`calc()`-Stops und
die erfassten `min()`-/`max()`-/`clamp()`-Stops werden im aktuellen
Schriftkontext abgetastet. Bei gleichzeitiger WAAPI-Schriftprobe `30px`
ergibt `100%` → `200%` in der Mitte `45px`; entsprechendes CSS-Transitioning
zwischen den zuvor berechneten `20px` und `80px` ergibt dagegen `50px`.
Die drei nativen Transition-Referenzen prüfen Zahlen, Pixel und Prozente
samt verkürzter Umkehr. Diese beiden Pfade werden bewusst nicht vereinheitlicht.

Replace/Add/Accumulate, aktuelle Autorbasen einschließlich Änderungen auf
den bereits sichtbaren Wert, unabhängiges `!important`, Font-Shorthand-Priorität,
eigene Variablen, vererbte CSS-weite Werte/Variable-Fallbacks,
Commit/Cancel und CSS-/WAAPI-Stapel sind nachgewiesen.
Negative extrapolierte Schriftgrößen/Zeilenhöhen werden erst am verwendeten
Endwert geklammert; eine additive CSS-Zeilenhöhe verliert deshalb keinen
negativen Zwischenwert vor ihrer Komposition.

Der Effektbasisstil ist von der durch die Probe beeinflussten Darstellung
getrennt. Beispiel: Autor `font-size:20px;width:5em`, Schriftprobe `30px`:
ohne Breiteneffekt wird `150px` dargestellt. Eine additive animierte Breite
mit mittlerem Wert `2em` komponiert im erfassten Browserfall jedoch über die
Autor-Effektbasis `100px` und ergibt `160px`. Ein gespeicherter letzter
Schrift-/Breitenframe darf diesen Basisstil nicht ersetzen. Autor-Kontexte
und Stops sind nach Stilrevision, Eltern-/Root-Schrift, geerbter Zeilenhöhe
und Variablen getrennt gecacht. Eine Probe startet die zugehörige CSS-Animation
oder Transition nicht erneut.

`capture-animation-font-metrics.cjs` erneuert ausschließlich die 35 Schriftfälle
in der gemeinsamen `javascript-animation-layout.json`. Der historische gemeinsame Stand nach dem Schrift-Slice
beträgt damit **183 native Vergleichsfälle, drei explizite Level-2-Erweiterungen
und drei Browser-only-Referenzen**.
`capture-animation-font-transitions.cjs` liefert zusätzlich drei native
Transition-/Umkehrfälle in `animation-font-transition-native.json`.
`JavaScriptAnimationLayout` prüft echte behaltene Wörter und `TextBox`-Editoren,
veränderte Mess-/Paintgrößen, Zeilen-/Nachkommengeometrie, Live-Auswahl,
unveränderte fremde Layoutcaches und keinerlei erneute Messung/GUI-Erstellung/
Layoutanforderung bei derselben Probe. CSS- und Script-Zielentfernung,
Wiedereinfügen einer pausierten DOM-Instanz, Cancel und Disposal müssen
Autor-Snapshots und Override-Maps freigeben; Pausen behalten keinen Frame-Abonnenten.

Offen bleiben insbesondere direkte reine Inline-/Pseudoelementziele,
weitere Schrift-/Formatierungs-/Zeitkombinationen, vollständige relative
Ausdrucks-/Prioritätskombinationen und `font-size-adjust` in Effektstapeln.
Die vorhandene Deklarationsgrammatik für `font-size` bleibt auf 0–100px,
die vorhandenen relativen Einheiten und `smaller`/`larger` begrenzt;
Prozent-Schriftgrößen, weitere Keywords und deklarierte Größen über 100px
werden durch diesen Slice nicht nachträglich als implementiert bezeichnet.
Native Glyphen-/Baseline-/`normal`-Metriken und die positive Rundung des
Roblox-TextSize behalten ihre dokumentierten Profilgrenzen. Die Tests mit
ersetzten Textmessungen beweisen Aktualisierung und Ressourcenerhalt,
keine pixelgenaue Gleichheit beliebiger Browser-/Roblox-Schriften.

## C08: Farbvererbung und abhängige Oberflächen – 10. Oktober 2026

Die acht Kanäle `color`, `background-color`, vier physische `border-*-color`,
`outline-color` und `text-decoration-color` verwenden einen gemeinsamen
CSS-/WAAPI-Farbtyp. `border-color`-Keyframes expandieren zu den vier physischen
Longhands. Die erfassten RGB-/Alpha-Proben interpolieren vormultipliziert;
`currentColor` bleibt als Ausdruck erhalten, bis der jeweilige gesampelte
Vordergrund bekannt ist. Dies folgt dem begrenzten vorhandenen Farbprofil,
siehe [CSS Color 4: Alpha-Interpolation](https://drafts.csswg.org/css-color-4/#interpolation-alpha)
und [currentcolor](https://drafts.csswg.org/css-color-4/#currentcolor-color).
Weitere Farbräume und Interpolationsräume werden damit nicht implementiert.

Replace/Add/Accumulate, unabhängige wichtige physische Kanten, lebende
Autorbasen einschließlich einer Änderung auf den schon sichtbaren Wert,
Variablen, vererbte CSS-weite Werte/Fallbacks, ausgelassene Endpunkte,
CSS-/WAAPI-Stapel sowie Commit/Cancel sind für die gespeicherten Fälle
nachgewiesen. Additive RGB-Zwischenwerte bleiben bis zum verwendeten Endwert
ungeklammert: Autorrot 230 plus mittlere Probe 55 ergibt 255, nicht 248 durch
eine vorherige Begrenzung der Stops. Das bedeutet keine vollständige Abdeckung
sämtlicher Alpha-Extrapolations- und Range-Clamp-Kombinationen.

Der Farb-Override besitzt eine eigene schwache Zielmap und getrennte
Autor-Snapshots. Er fließt vor der `currentColor`-Auflösung in die Kaskade ein.
Vererbte Wörter, native Inputs, physische Rahmen, Außenkonturen,
Textdekorationen und bestehende Inline-Hintergründe werden auf ihren behaltenen
Objekten gemalt. Eine explizite Nachkommenfarbe bleibt erhalten. Elternproben
aktualisieren auch einen bereits aktiven additiven Nachkommeneffekt vor einem
synchronen `getComputedStyle()`-Read. Dieser Pfad misst keinen Text neu,
regroupiert keine Runs und fordert kein Layout an.

Die Farbrecascade schreibt ausschließlich Farb-/abhängige Paintfelder.
Gehaltene Größen-, Schrift-, Rahmenbreiten-, Radius- und Outline-Geometrie
bleibt erhalten; numerische und Schriftproben werden zuerst veröffentlicht.
Ein neuer Rahmen-Farbwert darf weder den ganzen Kantenvergleich als
Layoutänderung behandeln noch die durch einen Breiteneffekt schon verwendeten
vier Width-/Style-Werte ersetzen. Die Tests prüfen tatsächliche Box-, Wort-
und Editorgrößen, gemalte aktuelle Farben und keinerlei zusätzliche
Layoutanforderung, Messung oder GUI-Erstellung beim Farbwechsel und seinem
Cancel neben diesen Effekten. Die abschließende geometrische Cancellation
stellt weiterhin echte Autorgrößen her.

[capture-animation-colors.cjs](../scripts/capture-animation-colors.cjs)
erfasst **25 isolierte Browserfälle**: 24 gemeinsam verglichene Fälle und
eine erhaltene Browser-only-Alphaabweichung. Der aktuelle gemeinsame Stand
beträgt **207 native Vergleichsfälle, drei explizite Level-2-Erweiterungen
und vier Browser-only-Referenzen**. Bei der neuen Alphaabweichung quantisiert
Chromium die Legacy-RGBA-Eingaben auf 8 Bit und serialisiert `.627`; die Engine
komponiert die erhaltenen Float-Alphas zu `.625`. Die RGB-Kanäle stimmen
überein. Beide Ergebnisse sind ausdrücklich gespeichert; der normative
Float-Test wurde nicht auf den Browserwert geändert.

[capture-animation-color-transitions.cjs](../scripts/capture-animation-color-transitions.cjs)
speichert drei zusätzliche native CSS-/WAAPI-Transitionfälle in
`animation-color-transition-native.json`. Zwei Fälle vergleichen vollständige
Mittelproben, verkürzte Umkehr und die unabhängigen Verbraucherfarben. Der
dritte prüft die obere WAAPI-Probe und ihren eigenen Commit-Sample bei
gehaltener CSS-Farbtransition. Die native abschließende Autoren-Commit- und
Transition-Retarget-Zeitfolge ist gespeichert, aber noch nicht vollständig
implementiert/geprüft; dieser Fall ist kein pauschaler Timing-Abschluss.

`JavaScriptAnimationLayout` prüft echte behaltene Text-/Input-/Rahmen-/Outline-/
Dekorationsflächen, Live-Auswahl, fremde Layoutcaches sowie gleiche wiederholte
Proben. Entfernung und Wiedereinfügen pausierter DOM-Ziele, Cancellation,
Transitionende und Disposal geben Farb-/Eltern-Snapshots und Override-Maps frei;
pausierte Effekte behalten keinen Frame-Abonnenten. Die gezielte Gruppe aus
`JavaScriptAnimationLayout`, `CSSLayoutAnimations`, `Animations`,
`RenderingLifetimes`, `FocusOutline`, `ControlBorders`, `HoverBorders` und
`BorderCorners` besteht. Diese Tests ersetzen weiterhin keine native
Roblox-Pixel-/FPS-Abnahme.

Offen bleiben direkte reine Inline-/Pseudoelementziele, vollständige logische
Alias-/Priority-Kombinationen, Farb-Räume/Gamut/relative Farben, weitere
Paint-Wertfamilien und sämtliche nicht erfassten Timing-/Kompositionskontexte.
Die geprüfte Vererbung zu Inline-Verbrauchern ist keine Freigabe direkter
Inline-Animationsziele. Globale CSS-Kaskadenursprünge bleiben außerhalb dieses
Slices und im allgemeinen Kaskadenprofil offen.

## C08: CSS-DOM-Controller und Lifecycle-Ereignisse – 10. Oktober 2026

Die vorhandenen CSS-Paintrecords werden nun als echte `CSSAnimation`-/
`CSSTransition`-Objekte derselben Runtime zugänglich. Sie behalten Identität,
`animationName`/`transitionProperty`, Ziel, Effect und Dokument-Timeline.
`getAnimations()` berücksichtigt den Zielbaum und sortiert verbundene
Transitions nach Eigenschaft sowie CSS-Keyframes nach Autorenreihenfolge.
Die Controller übernehmen ihren vorhandenen Record; es entsteht keine zweite
Animationsuhr. Pause, Seek, Finish, Umkehr und Cancel veröffentlichen dieselben
behaltenen Paint-/Layoutflächen wie die bisherigen CSS-Effekte.

Erfolgreiches `updateTiming()` unterbindet spätere CSS-Updates genau der
übergebenen Timingmember. `setKeyframes()` erhält seine eigenen Frames und
Timingfunktionen. Play/Pause übernimmt die entsprechende Autorensteuerung;
ein ersetzter Effect ignoriert weitere CSS-Timing-/Frameänderungen. Entfernung
des zugehörigen Namens beendet weiterhin den Controller. Element-Retarget,
Effect-Austausch/Null und Wiederherstellung sind für die aufgezeichneten
Opacityfälle geprüft. Grundlage ist [CSS Animations 2 §2](https://drafts.csswg.org/css-animations-2/#animations),
kein pauschaler Abschluss sämtlicher Effect-/Timeline-Kombinationen.

`AnimationEvent` und `TransitionEvent` besitzen getrennte Marken, geerbte
Eventfelder, schreibgeschützte Nutzdaten und beobachtbare Dictionary-Konversion.
Echte fremde Realm-Eventgetter funktionieren; falsche Empfänger werfen.
Die erzeugten Start-/Iteration-/End-/Cancel-Ereignisse laufen über den echten
DOM-EventTarget-Pfad und die Taskqueue. Synchron wiederholte Seeks werden zum
letzten Sample zusammengefasst. Negative Verzögerung, rückwärts überschrittene
Iterations-/Phasengrenzen, Cancel vor dem Delay und vor der ersten
Rendering-Gelegenheit sowie das ursprüngliche Ereignisziel nach Retarget
sind geprüft. [CSS Animations 2 §5.1](https://drafts.csswg.org/css-animations-2/#event-dispatch)
und [CSS Transitions 2 §5.1](https://drafts.csswg.org/css-transitions-2/#event-dispatch)
bilden die Grundlage; vollständige dokumentweite Ereignissortierung und
Rendering-Opportunity-Integration bleiben offen.

Playback-Rate-Updates behalten bis zur Ready-Auflösung die alte Rate und
deren Zeitfortschritt. Pending-Rate, mehrfache Umkehr, direkter Ratesetter,
Finish/Cancel und Fehler-Rollback sind geprüft. Interne Cancellation von
CSS-Controller-Promises ist intrinsisch behandelt; eine unbehandelte
`animate().finished`-Ablehnung des Autors bleibt sichtbar. Der gemeinsame
Effectstack erhält den gehaltenen unteren Transitionwert. Die Priorität wird
pro tatsächlich beteiligter Eigenschaft bestimmt: ein fremder Transformeffekt
lässt eine wichtige Opacity-Transition erhalten, ein eigener Opacityeffekt
kann sie in das Animation-Origin bringen, wo die wichtige Autoropacity gewinnt.
Cancel legt wieder die Transition frei. Siehe [Web Animations §5.4](https://drafts.csswg.org/web-animations-1/#combining-effects).

[capture-css-animation-dom.cjs](../scripts/capture-css-animation-dom.cjs)
speichert inzwischen **70 Browserquellen und rohe Ergebnisse** in
[css-animation-dom-native.json](../tests/fixtures/css-animation-dom-native.json).
54 Fälle stimmen direkt überein: acht Event-/Pending-rate-, 30 CSS-DOM- und
16 Replacement-Fälle. Sechzehn Fälle besitzen getrennte normative Erwartungen;
die zwei Replacement-Abweichungen sind unten dokumentiert. Chromium meldet
generierte Lifecycle-Events als cancelable; die Ereignisdefinition verlangt
`false`. Bei einem Seek vor den Start meldet es negative Cancellationzeit,
während die aktive Zeit mit `fill:both` auf null begrenzt wird. Drei erfolgreiche
Timing-/Frame-/Effect-Overrides meldet die API korrekt, malt aber später
erneut nach CSS. Schließlich kombiniert es additive Scriptopacity mit der
Autorbasis statt dem gehaltenen Transitionwert. Die letzten vier Rohdifferenzen
sind nach zwei weiteren Rendering-Frames unverändert erfasst. Keine dieser
abweichenden Rohausgaben zählt als bestandener visueller Nativevergleich.

`JavaScriptAnimationLayout` prüft reale GUI-Identität, unveränderte fremde
Layoutcaches und die gemalten/getComputedStyle-Werte. Gleichzeitige Width- und
Opacity-Transitions bleiben unabhängig; Cancellation entfernt nur ihre eigene
Eigenschaft. Reine Paint-Steuerfälle erzeugen kein Flow-Layout. Pausierte oder
fertige Controller behalten weder einen CSS-Abonnenten noch ein Script-Frame;
Disposal entfernt Tasks, Records und Oberflächen. Diese Prüfungen ersetzen
keine native Roblox-Pixel-/FPS-Abnahme.

CSS-Keyframes werden vor dem Sampling nach Offset, berechneter Kurve und
Composition gruppiert und innerhalb dieser Gruppen in Quellreihenfolge
kaskadiert. Ungültige und wichtige Deklarationen ersetzen keine gültigen
Framewerte. Jeder Eigenschaftskanal erhält eigene neutrale Endpunkte; die
Komposition erfolgt an den beiden Intervallenden vor ihrer Interpolation.
`getKeyframes()` erhält auch reine Timing-/Composition-Frames sowie die
Autoren-Funktionsform synthetischer Transformwerte. Die Verarbeitung bleibt
am bestehenden Record gecacht; die Paintframes erzeugen keine neue GUI und
fordern kein Flow-Layout an. Entfernen und Disposal geben Records und den
Frame-Abonnenten frei.

Fünf zusätzliche Referenzen prüfen doppelte Offsets, eigene Kurven und Modi,
gemischte fehlende Endpunkte und ungültige/`!important`-Werte direkt gegen
Chromium. Drei weitere Quellen behalten rohe Unterschiede ausdrücklich:
Chromium trennt ausgelassene von expliziter `replace`-Composition trotz
gleichem berechnetem Modus; reine Steps-Metadaten beeinflussen außerdem
Kanäle, die in den gemeldeten Frames eigene lineare Endpunkte haben.
Die Unterschiede bleiben nach zwei Rendering-Frames bestehen. Für die beiden
Steps-Fälle ist zusätzlich die native WAAPI-Wiedergabe der exportierten Frames
gespeichert; sie bestätigt das eigenschaftsweise Standardergebnis. Synthetische
Initialframes stehen in der Engine vor den Autorenframes gemäß
[CSS Animations 2 §3.2](https://drafts.csswg.org/css-animations-2/#keyframe-processing);
eigenschaftsfremde Frames beeinflussen gemäß
[Web Animations §5.3.4](https://drafts.csswg.org/web-animations-1/#the-effect-value-of-a-keyframe-animation-effect)
keine Intervallkurve. Diese drei Fälle zählen als normative Vergleiche und
nicht als direkte visuelle Chromium-Parität. `CSSLayoutAnimations` prüft alle
acht Quellen zusätzlich ohne DOM-Controller an den tatsächlich gemalten
Box-/Opacity-Oberflächen, mit behaltenem Editor und dessen Textauswahl.

API-`cancel()` entfernt die aktive CSS-Paintwirkung und setzt die Zeit zurück,
behält aber das CSS-owning-element. Wiederholtes Abspielen verwendet deshalb
weiter die ursprüngliche CSS-Klassenreihenfolge; eine CSS-Transition bleibt
im Transition-Origin oberhalb wichtiger Autorwerte. Auch nach `finish()` kann
ein Seek dieselbe Transition wieder anzeigen. Neun direkte Nativequellen
prüfen Cancel/Replay, die Reihenfolge gegenüber älteren Scripteffekten,
Finish/Seek, wichtige Autorwerte, tatsächlich entfernte CSS-Namen/-Properties,
erneute Start-/Run-/Cancel-/End-Ereignisse und gebrochene Rahmenpixelgrößen.
Siehe [CSS Transitions 2 §3](https://drafts.csswg.org/css-transitions-2/#starting)
und [CSS Animations 2 §2.1](https://drafts.csswg.org/css-animations-2/#owning-element).
Die vollständig globale Reihenfolge aller disassoziierten Klassen und
Wiederholungen ist damit noch nicht nachgewiesen.

Inaktive oder fertige DOM-Transition-Records sind getrennt vom aktiven
Painter erhalten. Das ermöglicht Replay ohne einen zweiten Timing-Owner,
ohne weitere Idleframes und ohne erneutes Erstellen der Oberfläche. Der
Record bleibt nur während seines echten CSS-Owners erhalten; neue
Zielwerte/-Properties, entfernte Renderknoten und Disposal lösen ihn.
Der Controllercache bleibt durch diese Autoren-Records begrenzt, sodass
Garbage Collection eine abgebrochene CSS-Animation nicht wieder starten kann.
Eine echte Rendererprüfung erhält Box, Texteditor und dessen Auswahl über
Cancel/Replay/Finish, fordert dabei kein Flow-Layout an und prüft die Freigabe
bei einer neuen Transition sowie beim Entfernen des Owners.

Zwei weitere direkte Quellen prüfen den Transform-Export: `translateX/Y/Z`,
`scaleX/Y/Z`, `rotateZ`, `skewX/Y` und ausdrücklich zweidimensionale oder
dreidimensionale Matrizen behalten ihre gültige Funktionsform; redundante
Translate-/Scale-Argumente werden wie im Browser gekürzt. CSS-Variablen werden
aus dem gültigen Gewinnerwert exportiert, auch wenn danach eine ungültige
Transformdeklaration steht. Ein live Variablenwechsel aktualisiert dieselbe
CSSAnimation. Der Export liest die bereits geparsten Operationen und muss
keine Quelltextblöcke erneut scannen oder pro Gruppe kopieren. Generisches
Transform-Commit und Matrix-/Treffergeometrie behalten ihre bisherigen Pfade.

## C08: WAAPI-Kurzformen und Quellenpriorität – 10. Oktober 2026

`margin`, `padding`, `inset`, `gap` und `flex` sind jetzt auch in Scriptkeyframes
animierbar. Der Export erhält die Kurzform wie im Browser; die Paint- und
Layoutabtastung expandiert sie in dieselben bereits vorhandenen Komponenten.
Explizite Longhands gewinnen immer gegen ihre Kurzform, unabhängig von der
Reihenfolge im JavaScript-Objekt. Diese Priorität gilt auch für die bereits
vorhandenen Rahmenbreiten, Rahmenfarben und Eckenradien. Siehe
[Web Animations §5.3.3](https://drafts.csswg.org/web-animations-1/#calculating-computed-keyframes).

`commitStyles()` schreibt die betroffenen Komponenten in die Autorinlinewerte;
Cancel, neue Keyframes und spätere Autor-/Variablenänderungen verwenden weiterhin
die getrennte Basis. Relative Werte folgen der aktuellen Schriftgröße, auch
wenn ein zweiter Kanal desselben Effekts diese Größe animiert. `gap: normal`
bleibt ein diskreter Keywordwert; die zuvor vorhandenen Specified-Flags werden
nach Cancel wiederhergestellt. Dadurch kann eine ungestylte Box während des
Effekts numerische Gaps und danach wieder `normal` ausgeben.

Direkt ungültige Werte werden aus dem Keyframe entfernt, ohne dessen Offset
zu entfernen. Der leere CSSOM-Wert bleibt im Export erhalten, hat aber keinen
eigenen Paintstop. Eine syntaktisch gültige Variable, deren Ersetzung ungültig
wird, verwendet dagegen `unset` bei der Wertberechnung, entsprechend
[CSS Variables: invalid at computed-value time](https://drafts.csswg.org/css-variables-1/#guaranteed-invalid).
Ein Wert kann keine zusätzlichen Deklarationen oder `!important` einschleusen.
Gültige Quellen werden einmal pro Frame geparst; die Kontextauflösung einer
Kurzform wird zwischen ihren Komponenten geteilt und nur bei relevanten
Stil-/Schrift-/Viewport- oder Quellenänderungen wiederholt.

`scripts/capture-animation-shorthands.cjs` hält **24 direkte native Quellen**
in `javascript-animation-layout.json` fest: Quellenexport und einfache
Canonicalisierung, Komponentenpriorität, Em/Variablen, geänderte Basen,
Add/Accumulate, wichtige einzelne Seiten, ungültige/fehlende Quellen,
Commit/Cancel, neue Keyframes und die tatsächliche Grid-/Flex-Nachbargeometrie.
Der echte RenderTree-Test erhält zusätzlich Box und Texteingabe samt Text,
Cursor und Auswahl, prüft unveränderte Folgeabfragen ohne neue Anordnung,
Messung oder GUI-Allokation und prüft Snapshot-/Framefreigabe beim letzten
Cancel und Disposal. Das ist keine Behauptung vollständiger Kurzformgrammatik:
weitere Shorthands, vollständige mathematische Quellenserialisierung, logische
Aliase und deren Schreibmoduskonflikte bleiben separat offen.

## C08: Beendete Effekte automatisch ersetzen – 10. Oktober 2026

Eine vollständig überdeckte, beendete WAAPI-Animation wechselt beim nächsten
Animationsframe zu `replaceState: "removed"`. Sie verschwindet aus
`getAnimations()` und Paint, während Timing, Effekt, Promise- und Objektidentität
erhalten bleiben. Mehrere spätere beendete Effekte können ihre physischen
Komponenten gemeinsam abdecken; Additiveffekte und persistierte Effekte zählen
ebenfalls als Abdeckung. Pausierte, ungefüllte, zeitlinienlose und weiterhin
CSS-eigene Controller ersetzen sie nicht. Siehe
[Web Animations §5.5.2](https://drafts.csswg.org/web-animations-1/#removing-replaced-animations).

`play()`, Reverse, neue Keyframes/Effekte, Retarget und Cancel heben den
Entfernungszustand nicht auf. `persist()` stellt die Paintteilnahme desselben
Controllers wieder her. `remove` meldet die bei Entfernung gespeicherten Zeiten
als vertrauenswürdiges AnimationPlaybackEvent; ein Handler kann unmittelbar
`commitStyles()`, Persist oder Cancel ausführen. Der Commit berücksichtigt auch
den eigenen bereits entfernten Effekt.

Die Prüfung verwendet die vorhandene Frameplanung und geparsten Komponenten.
Sie fordert nur bei tatsächlicher Abdeckung einen zusätzlichen Frame an,
beendet anschließend die Planung und gibt Paint-/Autoren-Snapshots sowie den
starken aktiven Registereintrag frei. Die Referenzdatei enthält **18 neue Fälle**;
zwei bewahren Chromium-Rohausgaben getrennt: dessen Entfernung nicht verbundener
Ziele und dessen Erhaltung eines alleinstehenden leeren Effekts. Der Standard
fordert Dokumentnachkommen und quantifiziert über alle betroffenen Eigenschaften.

Der behaltene RenderTree-Test prüft 140 aufeinanderfolgende Ersetzungen über
die 128er-Grenze des starken Registers, Box-/Editor-/Auswahlidentität und die
vollständige Snapshotfreigabe. Die Entfernung einer bereits überdeckten Probe
fordert keine Anordnung, Messung oder GUI-Allokation an. Der ursprüngliche
CSS-Zeitanker bleibt beim ersten Controllerframe erhalten; eine ausdrückliche
Autorseek vor diesem Frame übernimmt dagegen die gehaltene Seekzeit. Die echte
Komponentenvergleichsseite beendet dadurch ihre `.5s`-Entering-Transitions
nach `.55s` ohne verbliebene Frameverbindung.
Eine Layoutveröffentlichung, die vor dem bereits geplanten Endframe die
Endzeit beobachtet, behält genau diesen letzten Timingaufruf bis zur
Promise-/Ereigniszustellung. Drei wiederholte Veröffentlichungen bestellen
keinen zweiten Frame; nach der Zustellung bleibt der Controller ohne
Framesubskription. Die unveränderte JavaScript-Vergleichsseite erreicht nach
`.701s` ihren `.7s`-Endzustand und stellt bei Abbruch die Ausgangsposition her.

Die gemeinsamen Eventqueues aller Dokumente, weitere Timelineklassen und
vollständige fremde Realm-/CSS-Detach-/Retarget-Kombinationen bleiben offen.

## C08: Schattenlisten und behaltene Paintflächen – 10. Oktober 2026

`box-shadow` nutzt denselben Wert- und Timingpfad für WAAPI, CSS-Keyframes und
CSS-Transitions. Listen werden paarweise interpoliert; fehlende Elemente
werden mit transparenten Nullschatten passender Inset-Art ergänzt. Eine
Inset-Abweichung eines Paars schaltet die gesamte Liste diskret bei `.5` um.
Add verkettet Listen, Accumulate addiert passende Komponenten; Blur wird
nichtnegativ begrenzt. Grundlage ist [Web Animations: shadow-list
animation](https://drafts.csswg.org/web-animations-1/#animation-of-box-shadow-and-text-shadow).
CSS-Transitions erzeugen bei einer Inset-Abweichung nur mit
`transition-behavior:allow-discrete` einen Effekt. Das Schlüsselwort wird
auch im `transition`-Shorthand listenweise geparst und zurückgesetzt, gemäß
[CSS Transitions 2 §2.5–2.6](https://drafts.csswg.org/css-transitions-2/#transition-behavior-property).

Symbolisches `currentColor` wird nach der aktuellen Vordergrundprobe aufgelöst.
Live-Autor-/Variablenänderungen, wichtige Autorwerte, unabhängige additive
Ebenen, Cancel und Commit verwenden getrennte Quellen und Proben. Die
abgebildeten Schatten arbeiten ausschließlich im Paintpfad. Eine Farbe oder
unveränderte Probe misst keinen Text neu und ordnet keinen Dokumentfluss an.
Die Transform-Vorprüfung darf dabei auch separate Schrift- und Farb-Autorbasis-
Snapshots nicht als bloße Paintänderung behandeln: eine Autorenänderung, deren
Wert gerade dem Sample entspricht, muss weiterhin die echte Autorbasis ändern.

Äußere Schatten behalten ihre `UIShadow`-Slots. Eine zunächst schattenfreie
Frame-Box erhält für animierte Innenschatten ein einzelnes behaltenes Bildkind
unter ihren Text-/Editorflächen; ihr nativer Typ bleibt erhalten. Gleiche
Rasterdimensionen verwenden das bestehende EditableImage. Der Inset-Cache
vergleicht tatsächliche Geometrie und Schattenfarben, sodass gleichwertige
neue Listen, unveränderte gehaltene Proben und unabhängige Außenfarben keine
Rasterarbeit auslösen. Cancel versteckt ungenutzte Layer; Replay und Commit
verwenden sie erneut. Geänderte Außenabstände aktualisieren nur betroffene
Opacity-Bounds mit dem bisherigen Transform-Paintpfad.

[capture-animation-shadows.cjs](../scripts/capture-animation-shadows.cjs)
erfasst **25 isolierte Schattenfälle**: 23 native Vergleiche und zwei
getrennte normative Erwartungen mit erhaltenen Rohwerten. Chromium rundet bei
der Umkehr die zuvor gehaltenen RGB-/Alphakanäle auf 8 Bit; die Engine erhält
Floatwerte bis zur Ausgabe (`160`/`.375` statt `159`/`.376` bei der dokumentierten
Probe). Nach Endpoint → Seek → CSS-Transition-Commit schreibt das erfasste
Chromium den Endwert, während der eigene gehaltene Commit hier die Mittelprobe
schreibt. Beide Rohfolgen bleiben gespeichert und zählen nicht als native
Gleichheit. Der auf einen Autoren-Commit gegebenenfalls neu entstehende
Transitioncontroller wird im Vergleich ausdrücklich abgebrochen; seine aktive
Uhr gilt nicht als Idle-Leak. Weitere Commit-/Retarget-Stapel bleiben offen.
Der Schattencheckpoint umfasst **254 native Vergleichsfälle, drei Level-2-
Erweiterungen, vier Browser-only-Referenzen und zwei normative Wertproben**;
die gesonderten CSS-DOM-Lifecyclefixtures behalten ihre eigene Zählung.

`JavaScriptAnimationLayout` prüft echte behaltene äußere Slots und Insetpixel,
live Vordergrundfarbe, Editor-/Auswahlidentität, fremde Layoutcaches,
Cancellation, Replay/Commit und fehlende Idle-Frames. `RenderingLifetimes`
prüft unterbrochene Raster-/Uploadarbeit: ältere Generationen dürfen keine
neuen Pixel ersetzen; Entfernung und Teardown verhindern spätes Veröffentlichen
und zerstören unveröffentlichte oder behaltene Bilder genau einmal.
Dies ersetzt keine native Roblox-Pixel-/FPS-Abnahme. Die vorhandene
Gauß-Näherung, Größen-/Bildbudgets, Blockzielgrenzen und fehlende allgemeine
GPU-/Backdrop-Blur-Anbindung bleiben bestehen. Vollständige Shadow-List-Grammatik,
weitere mathematische/farbige Quellen und nicht erfasste Iterations-/Basis-/
Stackingkontexte bleiben offen. Scharfe Textschatten sind im nachfolgenden
Textschattenabschnitt gesondert nachgewiesen.

## C08: Transform-Ursprung im gemeinsamen Paint-/Trefferpfad – 10. Oktober 2026

`transform-origin` verwendet für CSS-Keyframes, Transitions und WAAPI denselben
Positionstyp mit zwei Längen-/Prozentkoordinaten und einer optionalen Z-Länge.
Einzelne Schlüsselwörter, vertikale/horizontale Paare, gemischte Pixel-/Prozent-
und `calc()`-Werte sowie negative Punkte außerhalb der Box bleiben erhalten.
Interpolation arbeitet komponentenweise; Add und Accumulate addieren die drei
Koordinaten. Die Z-Koordinate darf keinen Prozentanteil enthalten, auch nicht
innerhalb von `calc()`/`min()`/`max()`. Ungültige Deklarationen ersetzen keinen
vorherigen gültigen Autorwert. Grundlage ist [CSS Transforms 1:
transform-origin](https://drafts.csswg.org/css-transforms-1/#transform-origin-property).

Der Ursprung wird vor dem vorhandenen Transform-/Projektions-Painter
veröffentlicht und von derselben inversen Treffergeometrie verwendet. Er
ändert allein weder Layoutgrößen noch den Transform-Containing-Block.
Ein bestehender Transform-/individueller Rotate-Kanal, Perspektive,
Content-Transformbox und Opacity-Bounds verwenden die aktuell abgetasteten
Koordinaten. Prozentwerte reagieren auf eine echte Änderung der Referenzgröße;
eine wiederholte identische Probe fordert weder Layout noch einen neuen
Rasterupload an. Autor-/Variablenänderungen, wichtige Deklarationen und
Commit/Cancel verwenden getrennte Autoren- und Samplewerte. Eine reine
Ursprungsänderung bleibt auch nach der allgemeinen Style-Recascade im Paintpfad.

Die CSSOM-Ausgabe löst X/Y in Borderbox-Pixel auf und lässt die Z-Koordinate
bei Null weg. Das gespeicherte native Contentbox-Beispiel hält ausdrücklich
beide Bezugsregeln fest: Paintprozente verwenden die Contentbox samt deren
Offset; `commitStyles()` schreibt die ausgegebenen Pixelkoordinaten. Bei diesem
Commit kann sich deshalb die gemalte Pose ändern. Dies ist im Referenzbrowser
beobachtet und wird nicht als unveränderte visuelle Pose zugesagt.

[capture-animation-origin.cjs](../scripts/capture-animation-origin.cjs)
erfasst **29 native Fälle** mit mehreren pausierten Zeitpunkten: Prozent-/
Schlüsselwort-/Pixel-/Z-Werte, Add/Accumulate, Live-Basis/Variablen/Resize,
Importance, ungültige Z-Mathquellen, gemeinsame Transformkanäle, CSS-Keyframes,
CSS-Transitions und Reversal, Contentbox, Opacity-Gruppen sowie feste Nachkommen
bei einem Ursprungseffekt ohne Transform. Die Boundingbox-Ausgabe normalisiert
nur numerisches `-0.000` zu `0.000`; die Prüfungstoleranz bleibt `.001px`.
Der Ursprungscheckpoint umfasst **283 native Vergleichsfälle**, drei
getrennte Level-2-Erweiterungen, vier Browser-only-Referenzen und zwei normative
Wertproben. Die getrennten CSS-DOM-Lifecyclefixtures bleiben unverändert.

`JavaScriptAnimationLayout` prüft zusätzlich echte native Position/AnchorPoint/
Rotation, wiederverwendete GUI-/Editor-/Auswahlobjekte, Perspektivflächen und
inverse Trefferkoordinaten, unveränderte Rasterpixel, fremde Layoutcaches und
die unveränderte Viewport-Elternfläche fester Nachkommen. Commit/Cancel ordnen
keinen Dokumentfluss an; Disposal eines erneut pausierten aktiven Effekts gibt
Autorsnapshots, Texturen und Trefferregister frei. Die sieben Animations-/
Scheduling-/Vergleichsseitensuiten sind gemeinsam bestanden. Dies ersetzt
keine native Roblox-Pixel-/FPS-Abnahme. Reine Inline-/Pseudoziele, weitere
Schreibmodi, mathematische Grenzfälle und sämtliche 3D-/Stacking-/Motion-Path-
Kombinationen bleiben offen.

## C08: Vererbte scharfe Textschattenlisten – 10. Oktober 2026

`text-shadow` verwendet die gemeinsame Listeninterpolation und Composition
für CSS-Keyframes, CSS-Transitions und WAAPI. `none` ist eine leere Liste;
fehlende Layer werden transparent mit Nullabständen ergänzt. Add verkettet
Listen, Accumulate kombiniert passende Komponenten. Das gelieferte Paintprofil
bleibt bei scharfen Schatten mit Pixelabständen und den bereits vorhandenen
Farben/Alpha. Grundlage sind [Web Animations: shadow-list animation](https://drafts.csswg.org/web-animations-1/#animation-of-box-shadow-and-text-shadow)
und [CSS Text Decoration 3: text-shadow](https://drafts.csswg.org/css-text-decor-3/#text-shadow-property).

Eine abgetastete Schattenliste wird nach der aktuellen Vordergrundprobe
aufgelöst und als eigener vererbter Wert veröffentlicht. Die native Referenz
unterscheidet ausdrücklich zwei Fälle: Ein statisches symbolisches
`currentColor` kann die eigene Farbe eines Nachkommen verwenden; die Schatten
seines animierten Elternwerts erben dagegen die bereits aufgelöste Elternprobe.
Ein grüner Nachkomme erhält deshalb beim animierten roten Elternschatten einen
roten Schatten. Explizite Nachkommenwerte einschließlich `none` behalten ihre
Wirkung. Unabhängige additive Nachkommeneffekte werden nach einer Änderung der
Elternprobe im selben Script erneuert.

Separate schwache Overrides und Autor-Snapshots verhindern, dass die letzte
Probe zur nächsten Autorenbasis wird. Live-Variablen und Vordergrundfarben,
wichtige Autorwerte, Autorenwerte gleich der gehaltenen Probe, unabhängige
additive Layer, `commitStyles()` und `cancel()` sind im Wertnachweis enthalten.
CSSOM und Commit geben nur Textschattenkomponenten aus, ohne den Spread-Parameter
des gemeinsamen Box-Schattenwerts. CSS-Keyframewerte und Timing werden auch über
den vorhandenen CSSAnimation-Controller exportiert.

Bereits angelegte native Wörter und ihre Schattenlabels bleiben erhalten.
Eine zunächst schattenfreie Textfläche erhält bei Bedarf eigene behaltene
Vordergrund-/Schattenkinder unter ihrem bisherigen Treffer-/Quellobjekt.
Geänderte Schattenabstände erneuern betroffene Opacity-Bounds und deren
bestehende Transformpose, ohne CSS-Boxgröße, Textmessung oder Dokumentfluss zu
ändern. Eine identische Probe erneuert auch diese Bounds nicht. Cancel blendet
ungenutzte Slots aus; Replay und Commit verwenden dieselben Labels erneut.
Editor, Auswahl und fremde Layoutcaches bleiben im Retained-Test unverändert.

Eine zunächst zusammengefasste Wortfolge kann bei einem neuen expliziten
Schatten-Quellscope die vorhandene Textaufteilung und ihr erstes Layout
benötigen. Dies wird nicht als reine Paintänderung ausgegeben. Neue Slots
bleiben bis zur tatsächlichen Wort-/Glyphengröße verborgen; die folgenden
uniformen Samples erhalten diese Aufteilung ohne weitere Messung oder Layout.
Die vorhandene schattenfreie Quelle und ihre expliziten `none`-Abschnitte
bleiben im Scope-Test erhalten. Disposal eines aktiven Effekts gibt die
Autor-/Vererbungszustände und den Override-Eintrag frei; Pause/Cancel hinterlassen
keine Animation-Frame-Anforderung.

[capture-animation-text-shadows.cjs](../scripts/capture-animation-text-shadows.cjs)
hält **28 isolierte Fälle**: 25 native Wert-/Quell-/Vererbungsvergleiche, zwei
getrennte normative Commit-/Umkehrproben mit erhaltenen Chromium-Rohwerten und
einen ausdrücklich Browser-only geführten nichtnulligen Textblur. Die beiden
normativen Unterschiede entsprechen den dokumentierten Box-Schattenfolgen:
Endpoint → Seek → Transition-Commit sowie 8-Bit-Rundung der gehaltenen
Umkehrfarben. Die vollständige Wertfixture enthält nun **308 native
Vergleichsfälle, drei Level-2-Erweiterungen, fünf Browser-only-Referenzen und
vier normative Wertproben**; die CSS-DOM-Lifecyclefixture bleibt separat.

`JavaScriptAnimationLayout` prüft die echten behaltenen Text-/Opacity-/Input-/
Scopepfade zusätzlich zur Wertfixture; `TextShadows` prüft statische
Grammatik, Alpha/Reihenfolge, Glyphkopien und fehlende Zusatzmessungen.
Nichtnulliger Textblur wird weder als scharfer Ersatz gezeichnet noch als
ungültiges Standard-CSS ausgegeben: Er bleibt außerhalb des aktuellen
Renderprofils. Weitere Längen-/Math-/Farbgrammatik, große Compositelisten,
Textlinien-/Listenmarker-/Bild-alt-/native Editorschattendarstellung,
zeilenweite Schattenstapelung, direkte Inline-/Pseudoziele und sämtliche
vertikalen/Font-/Emphasis-/Stacking-/Timelinekombinationen bleiben offen.
Das ist keine Behauptung technischer Unmöglichkeit und ersetzt keine native
Roblox-Pixel-/FPS-Abnahme.

## C08: Vererbte Farben der Betonungszeichen – 10. Oktober 2026

`text-emphasis-color` verwendet den bestehenden Farbresolver, die gemeinsame
CSS-/WAAPI-Effektkette und den vorhandenen `TextEmphasis.color`-Painter.
Interpolation arbeitet mit vormultiplizierten Farbkomponenten und Alpha;
Add und Accumulate verwenden denselben Compositiontyp wie die übrigen Farben.
CSS-Keyframes, Longhand-Transitions und der Farbanteil von `transition:text-emphasis`
werden darüber abgetastet. Der WAAPI-Kurzformwert `text-emphasis` und diskrete
Animationen des Markenstils bzw. der Markenposition sind damit nicht zugesagt.
Grundlagen sind [CSS Text Decoration 3: text-emphasis-color](https://drafts.csswg.org/css-text-decor-3/#text-emphasis-color-property)
und [CSS Color 4: currentColor](https://drafts.csswg.org/css-color-4/#currentcolor-color).

Statisches `currentColor` bleibt beim Vererben symbolisch: Ein grüner Nachkomme
verwendet seine eigene grüne Vordergrundfarbe. Eine animierte Elternprobe ist
dagegen bereits aufgelöst; derselbe Nachkomme erbt deren tatsächliche Farbe und
Alpha. Ein expliziter Nachkommenwert `currentColor` bleibt seine eigene Quelle.
Auch ein Wechsel von symbolischem Rot zu abgetastetem Rot muss diese Quellen
unterscheiden, obwohl die Elternpixel identisch bleiben. Getrennte Autor- und
Samplewerte erhalten Live-Variablen, geänderte bzw. identische Autorenwerte,
explizites `inherit`, wichtige Deklarationen, Commit, Cancel und Replay.
Unabhängige additive Nachkommeneffekte erneuern ihre geerbte Basis im selben Script.

Betonungsmarken, Textlabels, Textschatten, Opacity-Gruppen, native Editoren und
Auswahlobjekte bleiben in den uniformen Farbproben erhalten. Die Farbe ändert
keine Markenmaße oder Compositing-Bounds und fordert keine Messung oder Layout
an. Eine zuvor zusammengefasste Textfolge kann einmal die bestehende
Quellaufteilung und ihr Layout benötigen, wenn eine explizite unveränderte
Markenfarbe von der animierten Elternfarbe abweicht. Weitere Proben derselben
Aufteilung erhalten ihre Frames ohne neue Messung, Layout oder Ressourcen.
Disposal gibt schwache Overrides sowie Autoren- und Vererbungssnapshots frei;
gehaltene Effekte erzeugen keine Leerlauf-Frameverbindung.

[capture-animation-emphasis-colors.cjs](../scripts/capture-animation-emphasis-colors.cjs)
hält **31 isolierte Fälle** fest: 21 direkte native Vergleiche, neun normative
Proben mit erhaltenen Browser-Rohwerten und eine getrennte Level-2-
Iterationsakkumulation. Die gesamte Wertfixture enthält damit **329 native
Vergleichsfälle, vier Level-2-Erweiterungen, fünf Browser-only-Referenzen und
13 normative Proben**. Die separate CSS-DOM-Lifecyclefixture bleibt unverändert.
Die Fälle enthalten Farblisten-/Alphaquellen, simultane Vordergrundproben,
Vererbung, wichtige Autorwerte, Live-Kurzformen, additive Stapel, CSS-Keyframe-
Export, Transition-Commit und Umkehrung. `JavaScriptAnimationLayout` prüft die
zusätzlichen echten behaltenen Mark-/Text-/Editor-/Scope-/Cleanupwege.
Die zwölf Animations-/Textnachbarsuiten und 15 Farb-/Painter-/Lifetime-Suiten
sind gemeinsam bestanden; dies ersetzt keine native Roblox-Pixel-/FPS-Abnahme.

Die Rohdifferenzen bleiben ausdrücklich sichtbar: Chromium quantisiert manche
Legacy-RGBA-Alphas vor der Rechnung. Bei den isolierten Add-/Accumulate-Proben
mit gleichen transparenten Operand-Alphas erhält es außerdem das gemeinsame
Alpha und addiert die unvermultiplizierten RGB-Kanäle; dieses Profil addiert
vormultiplizierte Komponenten und Alpha. Transition-Commit nach gehaltenem Seek
sowie bestimmte vorzeitig gerundete Umkehrkanäle bleiben separat normative
Proben. Die Level-2-Iterationsoption wird vom Referenzbrowser ignoriert.

Eine gehaltene Farbtransition und ein darüber angeordneter gewöhnlicher
WAAPI-Effekt besitzen keine pauschal gleiche Cascade-Priorität: Die höchste
Effektklasse des Eigenschaftsstapels bestimmt seinen Ursprung. Bei einem
gewöhnlichen WAAPI-Effekt kann ein wichtiger Autorwert deshalb den Stapel
überstimmen; nach dessen Cancel kehrt die gehaltene Transition zurück.
Die Referenz folgt [Web Animations: applying the composited result](https://www.w3.org/TR/web-animations-1/#applying-the-composited-result),
ohne einen zweiten Timing-Owner oder einen Chromium-Compositorfehler nachzubauen.

## CSS-Transition-Kurzformen — 10. Oktober 2026

Der gemeinsame Transition-Trigger behandelt `outline` jetzt auch für
`outline-width` und `font` für die vorhandenen `font-size`-/`line-height`-Kanäle.
Die letzte passende Listenposition bestimmt Dauer und Kurve gemäß
[CSS Transitions 1, Stand 8. Januar 2026](https://www.w3.org/TR/2026/WD-css-transitions-1-20260108/#transition-property-property).
`outline-offset` gehört ausdrücklich nicht zur
[Outline-Kurzform, UI4 vom 20. Januar 2026](https://www.w3.org/TR/2026/WD-css-ui-4-20260120/#outline);
die [Font-Kurzform vom 13. September 2026](https://www.w3.org/TR/2026/WD-css-fonts-4-20260913/#font-prop)
umfasst weitere Kanäle, deren vollständige Animation hier noch nicht belegt ist.

[capture-transition-shorthand-metrics.cjs](../scripts/capture-transition-shorthand-metrics.cjs)
speichert acht isolierte native Sequenzen in der bestehenden Wertfixture und
verifiziert sie ohne `--update` unverändert. Tatsächliche `CSSTransition`-Namen,
Dauern, gehaltene Zwischenwerte und unabhängige Longhandpriorität werden mit
montierten Outlineflächen, geerbten `em`-Breiten, Font-/Zeilenmetriken und
ursprünglichen Eingabeeditoren samt Markierung abgeglichen. Konturproben
fordern kein Layout; Schriftmetriken verwenden die vorhandene lokale
Layoutveröffentlichung. Der `outline-style`-Getter serialisiert nun den
tatsächlich aufgelösten Stil, einschließlich des diskreten Wechsels
`none` → `solid`. Die UI4-Version erhält die berechnete Konturbreite bei
`none`; eine frühere Nullbreiten-Sonderregel wird nicht nachgebildet.

Die strikte Abbauprüfung reproduzierte außerdem eine wartende Wiederherstellung
nach Freigabe des letzten DOM-kontrollierten CSS-Effekts. Diese Box war schon
aus der aktiven Transitionliste entfernt, besaß aber noch Sample-/Autorbasen.
Der vollständige CSS-Abbau vereinigt aktive und wartende Besitzer, dedupliziert
sie und verwendet die bestehenden Metrik-/Farb-/Schatten-Restorepfade vor dem
Leeren der Maps. Gewöhnliche Controllerfreigabe und laufende CSS-/WAAPI-
Komposition bleiben im bestehenden Pfad. Der enge native Slice und zwölf
betroffene Animations-/Outline-/CSSOM-/Memory-Nachbarsuiten bestehen mit
unveränderten Cleanup- und Retention-Assertions. Der Cleanup ist zusätzlich
unabhängig gegen den realen LIFO-Seitenabbau geprüft. Die gesamte Wertfixture
enthält nun 337 native Fälle; die vier Level-2-Erweiterungen, fünf Browser-only-
Referenzen und 13 normativen Proben bleiben getrennt. Die 46 nativen und
16 normativen CSS-DOM-Fälle bleiben unverändert. Ein wiederholter nativer
Capture ohne Update stimmt überein; Gesamt- und Studioabnahme bleiben separat
erforderlich.

## Verbindlicher verbleibender C08-Umfang

C08 bleibt offen. Ein bestandener Fall dieser Tabelle schließt nicht automatisch
die anderen Werttypen oder Formatierungskontexte ein.

| Teilanforderung | Gelieferter Umfang | Noch offen / ungeprüft |
| --- | --- | --- |
| Numerische Layoutwerte | Größen-/Grenzen-/Inset-/Margin-/Padding-/Flex-/Gap-/Textabstände, Integer-Order/Spaltenzahl, Spaltenbreite, physische Rahmenbreiten und boxgebundene vererbte Schrift-/Zeilenmetriken; CSS und WAAPI; geprüfte WAAPI-Kurzformen/Longhandpriorität samt `gap:normal` | Direkte reine Inline-/Pseudoziele, weitere Kurzformen, vollständige mathematische Quellenserialisierung, weitere Schrift-/Formatierungs-/Ausdruckskombinationen, logische Aliase und Layoutkombinationen. |
| Intrinsische Größen | Numerisch ↔ `height:auto`, horizontaler `block-size`; CSS-Transitions, CSS-Keyframes und WAAPI; dynamischer natürlicher Inhalt | `width:auto`, Min-/Max-/Fit-Content, Flex-Basis-Content, weitere Größenkeywords, `calc-size()`-Grammatik und langfristig erhaltene intrinsische `commitStyles()`-Ausdrücke; vertikale Achsen, Layoutzyklen und andere Formatierungskontexte. |
| Paint-Werttypen | Transform-Origin im gemeinsamen Paint-/Trefferpfad und individuelle Translate/Rotate/Scale-/Transform-Kanäle samt impliziter Transform-Containing-Blocks für absolute/feste Nachkommen, Offset-Distance, Opacity, Vordergrund/einfarbiger Hintergrund/vier physische Rahmenfarben/Outline-/Dekorationsfarben samt geprüfter Vererbung und abhängigen behaltenen Oberflächen, Outline-Breite/-Offset und vier physische Eckenradien; behaltene Box-Schattenlisten einschließlich dynamischer Insetflächen und vererbte scharfe Textschattenlisten sowie Farben der Betonungszeichen | Direkte reine Inline-/Pseudoziele, weitere Farb-/Bild-/Filter-/Masken-/Paintfamilien; WAAPI-Betonungskurzform und diskrete Markenstile/-positionen, vollständige logische Farbalias-/Importance-Kombinationen, zusätzliche Farbräume/Alpha-Clamps; Textblur/weitere Textschattenflächen/logische Radien, mathematische Range-Clamps; Motion-Path-/Transform-Reihenfolge in allen Kombinationen; vollständig durch Animation entstehende Stacking-Contexts und Bezugspunkte weiterer Wertfamilien. |
| Composition | Replace/Add/Accumulate der vorhandenen Typen, individuelle Keyframe-Modi, live Autorbasen, geordnete Effekte, gehaltene untere Transitionwerte und begrenzte Level-2-Iterationsakkumulation | Composition jeder weiteren Wertfamilie, intrinsische Ausdruckserhaltung, vollständige Basis-/Iterations-/CSS-/WAAPI-Stapel sowie Retarget-/Commit-Composite-Order; die oben erfassten fünf Browser-only-Wertabweichungen und getrennten CSS-DOM-Rohdifferenzen. |
| Timing und Lifecycle | Easing/Direction/Delay/Fill/Pause, Wiederholungen, CSS-Transition-Reversal, API-Cancel/Commit, CSSAnimation-/CSSTransition-Controller für die unterstützten zeitgebundenen Boxwerttypen, geprüfte Ereignis-/Pending-rate-Folgen, gruppierte doppelte CSS-Offsets/individuelle Kurven und Modi/neutrale Eigenschaftsendpunkte, framefreie Pause/Füllung und Disposal; beendete WAAPI-Effekte mit physischer Gesamt-/Teilabdeckung entfernen, Persist/Remove/Commit und entfernte Replay-/Retarget-Proben | Fremde Realm-Animation-/Effectmethoden, vollständige Effect-/Target-/Timeline-Steuer-, CSS-Detach- und Replay-Kombinationen; Scroll-/View-Controller, Pseudo-/reine Inlineziele und CSS-DOM-Export weiterer Wertfamilien, außer den hier geprüften Box-/scharfen Textschattenlisten und Betonungsfarben; weitere synthetische/mehrfache CSS-Offsets in anderen Wert-/Timeline-/Schreibmodus-Kontexten, dokumentweite Ereignissortierung/Rendering-Gelegenheiten und Level-2-Event.animation; Autoren-Commit/Retarget bei gehaltener Farbtransition, diskrete Display-/Content-Visibility-Exit-Transitions. |
| Abnahme | Native Browserreferenzen plus Runtime-/Layout-/GUI-Ersatzobjekttests | Die abschließende gemeinsame Vergleichsseite und native visuelle Roblox-Abnahme bleiben erforderlich. |

Der Abgleich mit dem tatsächlichen Animation-Registry nennt als nächste
konkrete Lücken bereits geparste bzw. gerenderte Werte: Spaltenlinienfarbe und
-breite, Caret-/Akzentfarben mit ihrer `auto`-Semantik, Unterstreichungsabstand
und Dekorationsthickness, Bild-/Background-/Maskenpositionen und -größen,
Perspektive samt Ursprung sowie weitere Motion-Path-Komponenten. Auch die
weiteren Font-/diskreten Outline-Kanäle und zugehörigen Kurzformkombinationen
bleiben offen; die oben ergänzten Trigger schließen nur die belegten
Schriftgröße-/Zeilenhöhe- und Konturbreite-/Farbkanäle.
Dies ist eine priorisierte Registry-Pfadliste innerhalb dieses Fachprofils;
weitere Alias-/Kurzform-/Grammatik- und Kontextanforderungen der Tabelle bleiben
separat offen. Ein Katalogeintrag ist kein Nachweis seiner Animierbarkeit.

Die übrigen Fälle sind umsetzbare oder noch zu untersuchende Anforderungen;
fehlender Code, hoher Aufwand und fehlende Testabdeckung belegen keine
technische Unmöglichkeit. Dokumentierte Hostgrenzen für native Fonts,
Rasterisierung und Medienflächen bleiben im jeweiligen Fachprofil getrennt.
