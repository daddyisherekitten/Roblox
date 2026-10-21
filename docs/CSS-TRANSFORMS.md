# CSS-Transformationen in 2D und 3D

Blockboxen, atomare Inlineboxen und ersetzte Blockelemente verwenden eine gemeinsame
4x4-Matrix. CSS-Funktionen werden in ihrer angegebenen Reihenfolge multipliziert;
`transform-origin` wird davor und danach angewendet. Der normale Layoutfluss bleibt
unverändert. Die Implementierung folgt dem [CSS-Transforms-Modell](https://www.w3.org/TR/css-transforms-2/).

Unterstützte Funktionen:

- `translate`, `translateX/Y/Z`, `translate3d` einschließlich X/Y-Prozenten;
- `rotate`, `rotateX/Y/Z`, `rotate3d` mit normalisierter Drehachse;
- `scale`, `scaleX/Y/Z`, `scale3d`, ungleiche und negative Faktoren;
- `matrix`, `matrix3d`, `skew`, `skewX/Y`, `perspective`;
- einzelne Eigenschaften `translate`, `rotate`, `scale` auch mit drei Komponenten;
- `transform-origin` mit dritter Z-Länge und `perspective-origin`;
- `transform-style: preserve-3d/flat` und `backface-visibility`.

Gleichmäßige 2D-Transformationen bleiben native Roblox-GUIs mit wiederverwendetem
`UIScale`. Andere Transformationen verwenden eine retained EditableImage-Fläche.
Eine `preserve-3d`-Gruppe übernimmt die Matrizen aller Eltern und Kinder; Flächen
werden pro Pixel nach Tiefe sortiert und mit ihrer Transparenz zusammengesetzt.
Perspektivisch korrigierte Texturkoordinaten vermeiden Verzerrungen an der
Triangulationsdiagonale. Flächen hinter der Kamera werden entfernt; kreuzende
Flächen werden vor der homogenen Division an der Kameraebene geschnitten.

`flat`, Opacity und gruppierende Overflow-/Containment-Eigenschaften komponieren
Nachfahren zuerst zu einer Ebene. Der Perspektivwert einer Box wirkt auf ihre
Kinder, während die Funktion `perspective()` innerhalb ihrer eigenen Liste wirkt.
Rückseiten werden an der akkumulierten Matrix geprüft, nicht an einzelnen Winkeln.

Animationen und Übergänge interpolieren passende Funktionen komponentenweise.
Dadurch bleiben auch ganze Umdrehungen erhalten. Unterschiedliche Listen verwenden
Matrixzerlegung mit Quaternion-Interpolation; singuläre Matrizen wechseln diskret.
Pausierte Animationen belegen keinen Frame-Listener. Unveränderte Szenen behalten
ihre Bildfläche, und Text-/Hintergrundtexturen werden getrennt zwischengespeichert.

## Eigene 2D-Transformation ersetzter Inlineflächen – 10. Oktober 2026

Tatsächlich inline angeordnete Bilder, Canvas-, Media- und native Controlflächen
verwenden ihre bereits gezeichnete Borderfläche als Transformziel. Der äußere
Margin-Wrapper bleibt im normalen Wortfluss. Die während des Paints veröffentlichte
Geometrie gehört weiterhin zum ursprünglichen Item, auch bei einer anfänglichen
`text-overflow:ellipsis`-Momentaufnahme. Blockboxen und echte `InlineBox`-Kinder
behalten ihren bestehenden Pfad. Audio ohne Controls besitzt kein visuelles Ziel.

Translation, Rotation und gleichmäßige Skalierung, ihre Reihenfolge, individuelle
`translate`/`rotate`/`scale`, prozentuale Translation, wechselnde Ursprünge und
`transform:none` erreichen dieselbe retained Borderfläche. Das CSS-Layoutprofil
verwendet gemäß [CSS Transforms 1](https://www.w3.org/TR/css-transforms-1/#transform-box)
für `fill-box` die Contentbox und für `stroke-box`/`view-box` die Borderbox.
Der Anfangswert ist `view-box`; CSSOM erhält das angegebene Keyword. SVG-Formen
mit eigenen Fill-/Stroke-Grenzen bleiben ein separater Rendererumfang.

Paintprojektion/`getBoundingClientRect()`, untransformierte Layout-/ResizeObserver-
Maße und die rohen CSSOM-Werte für Transformmatrix/Ursprung/Einzeleigenschaften
werden getrennt geprüft. Die Chromium-Aufnahme serialisiert bei prozentualen
Content-/Fill-Referenzen Transformmatrix und Ursprung mit Bordermaßen, während
die tatsächliche Projektion die Contentreferenz verwendet. Diese rohen Kanäle
bleiben unverändert erhalten; daraus wird keine allgemeine Standardabweichung
oder identische Berechnungsbasis beider APIs abgeleitet.

Pausierte WAAPI-Transformproben und der vorhandene Opacitypfad verwenden dieselbe
Fläche. Ein neu benötigter Compositor gehört sowohl dem Item als auch seiner
Paintgeometrie; Resize und Abbruch behalten ihn einschließlich des vorhandenen
`UIScale`. Seine Viewportfläche enthält den Fokus-Outline, während der CSS-
Bordervergleich die tatsächliche Borderfläche innerhalb dieser Gruppe projiziert.
Ein späteres `Words.RepaintStyles()` benutzt dieselbe ursprüngliche Gruppe auch
bei gespeicherten Ellipsen-Paintitems; Projektion und Opacity bleiben erhalten.
Die übrigen animierten Werte auf ersetzten Inlineflächen sind durch diesen
Nachweis nicht implementiert und werden weiterhin diagnostiziert.

`InlineReplacedTransforms` prüft 20 Zustände für sieben echte Inlineelemente:
140 native Paint-/CSSOM-Geometrien einschließlich geladenem Sourcebild,
Canvas, Audio/Video-Control, Button, fokussiertem Editor und Ellipsenbild.
Transformänderungen verursachen kein Layout und keine ResizeObserver-Meldung;
tatsächliche Größenänderungen bleiben getrennt. Editor, Cursor, Markierung,
Textbindung, Item/GUI/Borderfläche und Opacitybesitzer bleiben erhalten.
9.258 unterbrochene reine Messprüfpunkte verändern keine Livefläche, Auswahl
oder Ressourcen; Entfernen entsorgt GUIs, Compositor und Transformlookup.
Capture: `scripts/capture-inline-replaced-transforms.cjs`, Rohreferenz:
`tests/fixtures/inline-replaced-transforms-browser.json`.

Dies schließt das begrenzte native 2D-Profil. Ungleichmäßige/negative Skalierung,
Skew, echte 3D-/Rasterprojektion dieser Inlineflächen sowie vollständige
Inlinefragment-/Stacking-/Overflow-/Treffer-/Auswahl- und Animationskombinationen
bleiben weitere Anforderungen. Die Tests mit Ersatz-GUIs sind weder ein
Studio-Pixelvergleich noch ein FPS- oder allgemeiner Paintatomaritätsnachweis.

## Rasterprofil und Grenzen

Der Projektionsrenderer zeichnet Text, solide rechteckige Rahmen, Hintergrundfarben,
Gradienten und verfügbare Canvas-Pixel. Das deckt alle sechs beschrifteten Flächen des
Würfels auf `html-css-stress-effects` ab. Beliebige native Controls, VideoFrames,
externe Assettexturen, SVG-GUIs und sämtliche CSS-Effekte sind noch keine vollständigen
Browser-Compositing-Flächen.

Seit dem 8. Oktober 2026 übergibt die projizierte Bildfläche Treffer an die
ursprünglichen Nachfahren. [ProjectiveHit](../src/HTMLEngine/Rendering/ProjectiveHit.luau)
invertiert die homogene Ebenenprojektion, einschließlich positiver Kameraseite,
`flat`-/`preserve-3d`-Gruppen, Tiefe, Rückseiten, Overflow-/Rundungsclips und
nativer Vorfahrenskalierung/-rotation. Verdeckte ursprüngliche GUIs werden nicht
als neue Hitboxen erstellt; die ursprüngliche DOM-/Controlidentität bleibt
erhalten. Die native Besitzerfläche benutzt dieselbe Projektion, sodass ihr
untransformiertes Rechteck keine falschen zusätzlichen Treffer liefert.
`pointer-events:none` kann von entsprechend gestylten Nachfahren überschrieben
werden. Metadaten werden mit der Szene publiziert und beim Entfernen oder
Zurückwechseln zu nativer 2D-Darstellung freigegeben.

Das erweitert die Element-/Worttreffer des vorhandenen Rasterprofils. Exakte
dreidimensionale native TextBox-/Video-/Assetdarstellung und alle Masken-/Filter-
Kombinationen sind dadurch weiterhin nicht zugesagt. Auswahl-/Caretgeometrie
einer vollständig eigenen 3D-Texteingabe wäre ein eigener Rendererumfang.

Maximal 64 Flächen und 64 Verschachtelungsebenen pro Szene; Ausgabe höchstens
512 Pixel pro Kante. EditableImage-Verfügbarkeit und das gemeinsame Seitenbudget
begrenzen die Darstellung zusätzlich. Die native Textebene des Browsers kann sich
von den Rasterglyphen unterscheiden. `StarterGui.ClipsDescendantsSupportsRotation`
muss für native gedrehte GUIs weiterhin aktiviert sein.

`tests/ThreeDTransforms.luau` prüft die Browser-Matrix und gemessene Würfelgrenzen,
Funktionsreihenfolge, Perspektive, Rückseiten, Kameraclipping, kreuzende Flächen,
Gruppen-Opacity, Keyframes, unterbrochene Hover-Übergänge, Caches und Freigabe.
`HTML_3D_PREVIEW=1 node scripts/run-html-tests.cjs ThreeDTransforms` erzeugt außerdem
`build/three-d-preview.png` mit den tatsächlich gerasterten Würfelpixeln.
`tests/ProjectiveHit.luau` prüft zusätzlich native Trefferrouting und Identität,
perspektivische Lokalpunkte, Tiefenordnung, `flat`/`preserve-3d`, Overflow und
Rundungen, Pointer-Overrides, Kamera/Rückseite/Singularität, Vorfahrensskalierung
und -rotation sowie Freigabe. Ersatz-GUIs beweisen keine Studio-Pixelgleichheit.
