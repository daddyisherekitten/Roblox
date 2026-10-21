# CSS-Übergänge und Animationen

Stand: 10. Oktober 2026. CSS-Animationen und Übergänge verwenden vorhandene Renderboxen, native Eingabefelder und denselben CSS-Wertresolver wie das normale Layout. Größenänderungen fordern lokales Layout an; reine Paint-Effekte ändern ihre Oberfläche ohne eigenes Layout pro Frame.

## Unterstütztes Profil

- `transition` und seine Longhands einschließlich Timing, Delay und Property-Listen; `animation` und seine Longhands, Wiederholung, Richtung, Fill, Play-State, Composition und Scroll-Timeline-Zuordnung.
- `@keyframes` mit `from`, `to`, Prozentstopps und Timing pro Segment. Änderungen an laufenden Definitionen behalten die ursprüngliche Uhr; eine später eingeführte fehlende Definition startet dann neu. Shadow-Targets beziehen Keyframes aus ihrem Tree-Scope.
- `linear`, die benannten Ease-Kurven, `cubic-bezier()`, `steps()` und die gemeinsame Easing-Auswertung.
- Transform und individuelle Translate/Rotate/Scale-Werte, Transform-Origin, Offset-Distance, Opacity, die vorhandenen einfarbigen Vordergrund-/Hintergrund-/Rahmen-/Kontur-/Dekorationsfarben, Konturbreite/-abstand, vier physische Eckenradien sowie Box-/scharfe Textschattenlisten und vererbte Farben der Betonungszeichen. Der genaue nachgewiesene Umfang und die offenen Kombinationen stehen im [C08-Fachprofil](JAVASCRIPT-ANIMATION-LAYOUT.md).
- Breite/Höhe, physische/logische Min-/Max-Maße, Positionierungsabstände, Margin/Padding, Flex-Basis/Grow/Shrink, Zeilen-/Spaltenabstände und Buchstaben-/Wortabstände über `Rendering/AnimationValues.luau`.
- Geordnete `animation-composition:replace/add/accumulate`. Transform-Addition verkettet Operationen; passende Scale-Funktionen akkumulieren relativ zur Identität. Individuelle Translate/Rotate/Scale-Eigenschaften werden einmal vor der Transform-Effektkette angewendet.

Autorwerte bleiben von abgetasteten Layoutwerten getrennt. Größe, Padding und Margin können gemeinsam animieren, ohne den letzten Frame als neue Ausgangsgröße zu übernehmen. Nach einem Layout wird der aktuelle Transition-Paint erneut veröffentlicht, damit eine gleichzeitige Größenänderung nicht die Transform- oder Opacity-Abtastung mit dem Autor-Endwert überschreibt. Prozent-Translationen verwenden dabei die aktuell animierte Referenzbox.

Alle Folge-Layouts einer Frame-Veröffentlichung verwenden denselben Animationszeitpunkt. Erst der nächste Renderframe bewegt laufende Effekte weiter; sonst würde eine während des Layouts voranschreitende Uhr ununterbrochen neue Größen und Layoutanforderungen erzeugen. Neue Effekte starten mit einem aktuellen Zeitpunkt, und direkte `commitStyles()`-Abfragen können die aktuelle Zeit unabhängig davon abtasten.

Die Runtime hält im Leerlauf keine Frame-Verbindung. Pro Seite laufen höchstens 128 aktive Keyframe-Einträge; das vorhandene Frame-Zeitbudget verteilt ihre Arbeit. Dieses Budget ist kein FPS-Versprechen. Entfernte Boxen und beendete Effekte geben ihre Arbeitseinträge wieder frei.

Die Frame-Veröffentlichung besucht nur Effektziele und aktive Übergänge. Nach dem Entfernen des letzten Effekts setzt eine einmalige Veröffentlichung dessen Autorwerte zurück. Eine reine Größenanimation löst keine Transform-Matrizen für unbeteiligte Paint-Eigenschaften oder andere Seitenboxen auf.

## Eintritt mit `@starting-style`

Normale und verschachtelte Starting-Style-Regeln beteiligen sich nur an der synthetischen Vorher-Auswertung eines zuvor nicht gerenderten Elements. Normales Cascade-Verhalten, Layer, Scope, Media, Importance und Shadow-Styles bleiben wirksam. Ein späterer normaler Selektor kann eine gleich spezifische Starting-Regel überstimmen.

Neue Elemente und der Wechsel von `display:none` zu gerendert erhalten so eine Startpose für die bestehenden Transition-Algorithmen. Ein bereits gerendertes Element nutzt seine tatsächliche Vorher-Pose; `visibility:hidden` allein entfernt diesen Zustand nicht. Starting-Style verändert weder dauerhafte Autorwerte noch die native Identität eines Eingabefelds. Die Vergleichsseite 08 zeigt den Eintritt neu ergänzter Listeneinträge durch Opacity und Translate-Y.

## Prüfung und Grenzen

`CSSLayoutAnimations` prüft die tatsächliche Layout-/Paint-Integration, behaltene Controls und Auswahl, zusammengesetzte Maße/Abstände, Keyframe-Änderungen, Importance, Composition, lokale Flow-Änderungen sowie initialen/erneuten Eintritt. Eine während der Ausführung voranschreitende Testuhr prüft außerdem, dass unendliche Größenanimationen und Live-Keyframe-Änderungen ihre Folge-Layouts innerhalb desselben Frames beenden. `Animations` prüft die bestehenden Paint-, Easing-, Motion-Path-, Scroll- und Cleanup-Wege. Die ausführbare native Referenz `tests/fixtures/css-starting-style-reference.html` hält deterministisch pausierte Eintrittsübergänge fest; die erfasste Browserausgabe steht in `css-starting-style-browser.json`.

Nicht jede CSS-Eigenschaft ist animierbar in diesem Renderer. Kontinuierliche Übergänge zwischen `auto`/intrinsischen Größen und Längen, diskrete Display-/Content-Visibility-Exit-Transitions sowie die vollständige CSS-Animation/CSSTransition-DOM-Oberfläche und deren Event-Lifecycle sind nicht vollständig implementiert. Weitere Bild-/Filter-/Maskenwerte und Paint-Familien gehören nicht automatisch zu diesem Sampling-Profil. Die geprüften intrinsischen Höhen, CSSAnimation-/CSSTransition-Controller und Ereignis-/Cleanup-Fälle sind im [C08-Fachprofil](JAVASCRIPT-ANIMATION-LAYOUT.md) abgegrenzt. Native Roblox-Fonts, Rasterisierung und native Schatten setzen weiterhin die dokumentierten visuellen Grenzen.

Die Algorithmen folgen [CSS Transitions 2](https://drafts.csswg.org/css-transitions-2/#defining-before-change-style), [CSS Animations 1](https://drafts.csswg.org/css-animations-1/) und [CSS Transforms 1](https://drafts.csswg.org/css-transforms-1/#interpolation-of-transforms). Die Referenzfälle belegen die geprüften Kombinationen; sie sind keine vollständige Browser-Konformitätszusage.
