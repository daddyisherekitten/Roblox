# Bildfilter

CSS `filter` unterstützt auf `img` die Funktionen `brightness`, `contrast`,
`grayscale`, `invert`, `sepia`, `saturate`, `hue-rotate`, `opacity`, `blur` und `drop-shadow` sowie `none`.
Beispiel: `filter: sepia(60%) contrast(120%);`.

Zahlen und Prozentwerte sind austauschbar (`.5` entspricht `50%`). Negative
Beträge werden abgelehnt. grayscale/invert/sepia/opacity begrenzen Werte über
100% auf 100%; brightness/contrast/saturate erlauben stärkere Werte. Leere
Argumente entsprechen 1, bei hue-rotate 0deg. Winkel erlauben deg, grad, rad,
turn und einheitenlose 0, auch negative Winkel. Der Zahlenparser akzeptiert
Dezimalschreibweise bis zum Betrag 100000, keine Exponenten/calc/var. Bis zu
16 Funktionen sind erlaubt. Eine ungültige Funktion verwirft die gesamte
Deklaration; vorherige gültige Deklarationen und !important bleiben wirksam.
Die Eigenschaft ist nicht vererbt; CSS-weite Keywords nutzen die bestehende Cascade.

Dieser Teilumfang filtert ausschließlich Bildpixel. Rahmen, Hintergründe,
Alt-Texte und ganze Container werden nicht mitgefiltert.
url, backdrop-filter, animierte Filter und dynamische Filteränderungen fehlen.
Inline-, Block- und Flexbilder verwenden denselben Ausgabepfad. object-fit,
object-position und bestehende Layoutmaße bleiben erhalten.

CSS/Filter erzeugt unveränderliche Filterketten mit kanonischen Cache-Schlüsseln.
Rendering/ImageFilterPixels rechnet in sRGB mit nicht vormultipliziertem Alpha,
wendet die Funktionen nacheinander an und begrenzt jeden Zwischenschritt auf
den Kanalbereich. Erst das Endergebnis wird auf 8 Bit gerundet. opacity
multipliziert das vorhandene Alpha; andere Funktionen verändern es nicht.

Rendering/ImageFilters liest je verwendetem Asset einmal die Pixel aus einem
EditableImage, gibt dieses frei und erzeugt je verschiedener Filterkette ein
geteiltes Ausgabe-EditableImage. Die vorhandene Metadatenabfrage für natürliche
Bildgrößen arbeitet unabhängig und kann einen zusätzlichen Assetzugriff benötigen.
Die reine Farbfilterausgabe bleibt im Seitencache; Resize/Reflow berechnet sie nicht neu.
Die Arbeit startet asynchron und prüft nach jeweils 2048 Pixeln Abbruch sowie
das kooperative Zeitbudget von etwa 4ms. Es gibt keine dauerhaft laufende Schleife.
Das API-Schreiben der gesamten Textur kann trotzdem eigene Laufzeit benötigen.

Grenzen: höchstens 1024×1024 Pixel pro Quelle, 16 Ergebnisbilder und insgesamt
8.388.608 gespeicherte Ergebnispixel pro Seite. Roblox hat zusätzlich eigene
Speicher- und Assetzugriffsgrenzen. Wenn Laden, Zuweisen oder Speicherzuweisung
fehlschlägt, bleibt das Original erhalten und eine Diagnose wird ausgegeben.
Teilweise erfolgte Zuweisungen werden zurückgesetzt. Das Schließen der Seite
bricht die Verarbeitung ab und gibt alle geteilten Bilder einmalig frei.

Erfolgreiche Filter ändern nur den Bildinhalt. Ein zusätzlicher Layoutauftrag ist
nur nötig, wenn zuvor ein größenverändernder Alt-Text-Fallback aktiv war. Ein
später fehlgeschlagener Original-Preload darf ein fertiges Filterbild nicht ersetzen.

`blur()` und `blur(0)` sind Identität; positive Radien brauchen px, maximal 100px
je Funktion. Prozentwerte, negative Werte und em/rem werden hierfür abgelehnt.
Der Wert ist die Standardabweichung in CSS-Anzeigepixeln. ImageBlurPixels rastert
zuerst object-fit/object-position in die sichtbare Inhaltsbox, berücksichtigt die
innere Rundung und ergänzt transparenten Raum (Summe 3×sigma je Seite).
Eine Gauß-Näherung mit drei separierbaren Boxfiltern und gleitenden Summen arbeitet
auf vormultiplizierten Float-RGBA-Kanälen. Sehr kleine Radien erhalten einen
gewichteten Dreipunkt-Kernel. Dadurch verfärben transparente Pixel die Ränder
nicht. Farbfilter vor/nach Blur bleiben in der angegebenen Reihenfolge wirksam.

Blur-/Drop-shadow-Ketten verwenden Rendering/ImageBlur mit einem eigenen Cache aus Quelle,
Filterkette und sichtbarer Geometrie. ImageBox meldet Änderungen beim tatsächlichen
Anordnen. Gleiche Geometrie benötigt keinen Job; Größenänderungen erzeugen eine
neue Variante. Überholte Ergebnisse werden vor der Zuweisung verworfen. Ungenutzte
Varianten werden bei Platzbedarf freigegeben. BlurGui zeigt den transparenten
Überstand als passives ImageLabel; ursprüngliche Layout-/Hitboxmaße bleiben gleich,
Eltern-Clipping bleibt wirksam. Opacity-Gruppen berücksichtigen den Überstand.

Rasterfilter-Budgets: je höchstens 4.194.304 Quell-/Ergebnispixel, maximal 16 Ergebnisse,
512×512 Ausgabepixel je Variante. Große Darstellungen werden für die Verarbeitung
reduziert und anschließend skaliert; Antialiasing/Rundung und Blur bleiben Näherungen.
Zwei temporäre Float-RGBA-Buffer, bei Schatten drei (je maximal 4MiB), werden
für einen Job benötigt und innerhalb der Filterkette wiederverwendet. Quellpixel bleiben bis zum Seitenende gecacht; EditableImage-Quellen
werden unmittelbar nach dem Lesen freigegeben. Farbfilter ohne Blur/Drop-shadow behalten den
bisherigen größenunabhängigen Cache. Beide Pfade können dasselbe Asset getrennt lesen.

Demo34 zeigt Original, acht Einzelfilter, eine Filterkette, zwei Blur- und zwei Drop-shadow-Beispiele.
Das vollständige Browser-/Studio-HTML umfasst 21.383 Bytes; die Kompaktgrenze wurde dafür von
20.000 auf 22.000 Bytes angehoben. Keine eingebetteten Bild-/Fontbinärdaten.
Tests/ImageFilters prüft Farbwerte, Alpha, Reihenfolge, Zwischen-Clamping, Cascade,
Cache-Sharing, Budget, Abbruch, Aufräumen und Fehler beim Laden/Schreiben/Zuweisen.
Tests/Images prüft das Zusammenspiel mit dem Original-Preload. Die Tests verwenden
API-/GUI-Mocks; tatsächlicher Assetzugriff und Darstellung sind in Studio zu prüfen.
Tests/ImageBlur ergänzt Kernel-Symmetrie, Alphaerhalt, Subpixelradien, Reihenfolge,
Skalierung/Fitting, Größenwechsel, Cache-Verdrängung, Abbruch und Original-Fallback.

Referenzen: [Filter Effects](https://www.w3.org/TR/filter-effects-1/),
[Roblox EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage).

`drop-shadow(4px 4px 3px rgba(0,0,0,.5))` erzeugt den Schatten aus der
Transparenz des aktuellen Kettenergebnisses. Zwei Versatzwerte sind erforderlich,
der dritte Wert ist die optionale Gauß-Standardabweichung (0–100px, Standard 0).
Versatzwerte dürfen negativ sein, bis zum Betrag 1000px; einheitenlose 0 ist erlaubt.
Die optionale Farbe steht vor oder nach den Längen; ohne Farbe gilt currentcolor.
Dieser Wert wird nach der Cascade aufgelöst und geht einschließlich Alpha in den
Cache-Schlüssel ein. Spread und inset gehören nicht zu dieser Funktion.

Der getönte Alphakanal wird versetzt, weichgezeichnet und hinter das aktuelle Bild
komponiert. Halbtransparenz verwendet vormultipliziertes Source-over; Subpixelversatz
verwendet bilineare Abtastung mit transparenten Außenpixeln. Weitere Schatten sehen
auch vorherige Schatten. Farbfilter und blur bleiben in ihrer angegebenen Reihenfolge.
Der konservative Überstand summiert je Schatten max(abs(x),abs(y)) + 3×sigma.
Auch scharfe Schatten verwenden HasRaster und denselben größenabhängigen Cache.

Tests/ImageDropShadow prüft Syntax, Aussparungen, negative/subpixelige Versätze,
Farben/Alpha, weiche Kanten, Überlagerung, Filterreihenfolge, currentcolor-Cache und
Speicherfreigabe. Die Rastergrenzen und Studio-Prüfung gelten wie bei blur.
