# JavaScript: Skript-, Bild- und Fontladen

Stand: 10. Oktober 2026. Dieses Dokument beschreibt den tatsächlich implementierten
Ladeumfang. Es erklärt kein vollständiges R13/R16- oder Browser-Ladesystem für
fertig. Fernweh und seine Browserquellen bleiben unverändert.

## Skriptfolge und Seiten-Lifecycle

`JavaScript/ScriptLoader` besitzt getrennte Zustände für DOMContentLoaded, einen
geplanten load-Task und das bereits ausgelieferte window.load. Der geplante Task
prüft offene Skript- und Bildanforderungen erneut. Ein DOMContentLoaded-Handler,
der in einer Microtask weitere verbundene Ressourcen erzeugt, kann somit ein
bereits geplantes load noch verzögern. Ressourcen nach dem abgeschlossenen
Seitenladen erzeugen kein zweites window.load.

Die Vorbereitung eines Skripts bleibt seinem ursprünglichen Dokument zugeordnet.
Entfernen während des Ladens verhindert seine Ausführung nicht; Adoption in ein
anderes Dokument verhindert sie. currentScript funktioniert auch beim bereits
entfernten klassischen Skript. `HTMLScriptElement.supports()` meldet die in der
Engine unterstützten Typen classic, module und importmap mit exakt geschriebenen
Tokens; MIME-Typen sind keine Tokens für diese Methode.

Die bisherigen Ladewege bleiben erhalten: anfängliche klassische Skripte,
defer/async, dynamische Skripte mit async=false, Importmaps, Quelltextmodule,
dynamischer Import und die vorhandene Modulgraph-Auswertung. Die 22 geteilten
Browser-/Luau-Referenzfälle bleiben Regressionen. Modul-Top-Level-Await wird nicht
als zusätzlicher pauschaler DOMContentLoaded-Blocker behandelt.

Grundlage: [HTML-Skripte und Vorbereitung/Ausführung](https://html.spec.whatwg.org/multipage/scripting.html).

Der [H03-Live-Pfad](HTML-PARSER-ATTRIBUTES-20261006.md#h03-live-parser-und-dynamisches-schreiben--9-oktober-2026)
ergänzt parserbegleitende Ausführung für decodierte HTML-Stringquellen sowie
`document.write`/`writeln`/`open`/`close`. Einfügemarken, Schreibunterdrückung,
Custom-Element-Reaktionen, deklarativer Shadow DOM, Dokumentgenerationen und
retained Renderer sind dort mit 50 nativen Fällen abgegrenzt dokumentiert.
Verknüpfte CSS-Hostquellen, Parser-/Defer-/Modulbarrieren, Load-Verzögerung und
Origin-clean-Regelzugriff verwenden nun denselben Runtime-/Renderpfad, auch bei
verschachtelten CSS-Imports und nachträglichen CSSOM-Importänderungen. 33 native
HTTP-Szenen, sechs Standardabweichungen und zwei separat erhaltene Chromium-
Timeouts mit dokumentiertem Abbruchprofil stehen ebenfalls im H03-Profil.
Zehn weitere native HTTP-Szenen prüfen die Stylesheet-Barriere des unmittelbaren
Containerdokuments sowie die Kind-/Frame-/Parent-Load-Reihenfolge. Kind-Load-
Handler und ihre Microtasks laufen vor dem Container-Abschluss; Dokumentersetzung
und Entfernung verhindern veraltete Veröffentlichungen. Chromium-Srcdoc-
Abweichungen bleiben in der Referenz erhalten. Die bestehenden H03- und
[Frameprofile](IFRAMES.md) nennen den geprüften Umfang und weitere Grenzen.

Der gleiche Script-/Reconcilepfad verarbeitet inzwischen ausdrücklich übergebene
Bytequellen mit gewisser BOM-/Transport-/Overridekodierung. Der Decoder speist
die vorhandene Parsersession stückweise; frühe Scripts sehen weiterhin keine
späteren DOM-Knoten und `document.write` erhält seine getrennten Einfügemarken.
15 native HTTP-Fälle bei drei Decoderstückgrößen, Abbruch-/Ausgabebudgets und
echte behaltene Control-/CSS-/Dokumentersetzung stehen im
[Byte-Live-Nachweis](HTML-PARSER-ATTRIBUTES-20261006.md#festgelegte-bytekodierungen-am-script-einfügepunkt--10-oktober-2026).
Dieser Pfad lädt keine Netzwerkbytes selbst; unsichere Kodierungen und ein
Neustart nach Script-/GUI-Veröffentlichung bleiben getrennt offen.

## Bilder

`JavaScript/ImageResources` hält einen Requestzustand pro img-DOM-Knoten. Das
funktioniert auch für `new Image()` und vom Renderer unabhängige Bilder. Zu diesem
Umfang gehören:

- `Image(width?, height?)`, HTMLImageElement-Prototyp und geprüfte Receiver;
- `complete`, `naturalWidth`, `naturalHeight`, `currentSrc`, `width` und `height`;
- `decode()` als Promise, load/error-Ereignisse sowie Broken-/Empty-Zustände;
- Zusammenfassen mehrerer src-Schreibvorgänge bis zur Microtask-Grenze;
- Abbruch alter decode-Promises bei Quellwechsel und Ignorieren verspäteter
  Hostantworten;
- Beibehalten der aktuellen Bildmetadaten, während eine Ersatzquelle lädt;
- Bildanforderungen nach DOM-Einfügung, src/srcset/sizes-Änderung und
  Responsive-Source-Wechsel bei Viewportänderungen;
- Seiten-load-Warten auf verbundene Bilder, getrennt von abgetrennten Bildern.

Der Bildhost erfüllt decode erst nach einem tatsächlichen Ergebnis. Im geprüften
Profil laufen decode-Promise-Reaktionen vor dem getrennt geplanten load-Ereignis.
Eine erfolgreiche Roblox-Anzeige allein liefert keine verlässlichen natürlichen
Bildmaße: Die Hostbrücke ermittelt sie aus dem tatsächlichen nativen Decoder.

`Rendering/ResourceLoadHost:LoadImage(url, callback, spec)` erhält die aufgelöste
Browser-URL und zusätzlich `spec.Source` als Autorenquelle. Zugelassen sind die
expliziten Raster-/SVG-Zuordnungen der Seite. Bei Rasterbildern verwendet der Host
ContentProvider-Preload und AssetService.CreateEditableImageAsync; temporäre
ImageLabels und EditableImages werden wieder freigegeben. Bei abgelegten SVGs
stammen die Maße aus der tatsächlichen SVG-Quelle und der vorhandenen
SVG-Sizing-Logik. Ein viewBox liefert ein Verhältnis, keine CSS-Pixelmaße.

Der Seitenhost wird gemeinsam für JavaScript und das Layout verwendet.
`LoadRasterDimensions(rbxURI, callback)` und `ImageDimensions.start` mit
`services.LoadDimensions` teilen laufende Anforderungen und den begrenzten
Metadaten-Cache. Gleiche native Quellen werden dabei einmal decodiert, auch wenn
verschiedene Browser-URLs darauf zeigen. Erfolg wird gespeichert; fehlgeschlagene
Anfragen können nach geänderten Berechtigungen/Budgets erneut versucht werden.
Kündigungen entfernen einzelne Teilnehmer; bereits laufende native Arbeit ist
dadurch nicht zwingend unterbrechbar.

`RenderTree:RefreshImageResource` behält Bildobjekt, CSS-Box, GUI und Hit-Target.
Der before-Hook meldet die alte native Registrierung ab, bevor Source/SVG geändert
werden. Raster/SVG/Fehler-Wechsel aktualisieren die richtigen Ressourcenlisten.
Unveränderte Quellen behalten bereits hochgeladene SVG-Texturen. Alt- und
Dimensionsänderungen starten keine neue Quellanforderung. Ein unsichtbarer
Alttextwechsel eines geladenen Bildes fordert kein Layout an; sichtbarer Ersatztext
kann dagegen die Geometrie ändern. Schon publizierte identische Metadaten erzeugen
keinen weiteren Dimensions-Layoutcallback.

Der gemeinsame Fehlerpfad erhält die CSS-/Attributmaße von Block- und
Inlineblockbildern, einschließlich Seitenverhältnis, min/max und Box-Sizing.
Defekte Inlinebilder mit Alttext folgen der gesonderten, nativ geprüften
Text-/Symbolgröße. Das vorhandene 16-Pixel-Fehlersymbol erscheint zusammen mit
Alttext; explizites alt="" unterdrückt beide. Alte Bild-/Blurflächen werden im
Fehlerfall verborgen. Eine spätere erfolgreiche Anforderung verwendet die
erhaltenen Bildboxen und Oberflächen weiter. [Bildprofil](IMAGES.md).

Fehlendes src plant kein error-Ereignis; explizites src="" tut dies. Beide
Zustände haben complete=true, natürliche Maße null und ein verworfenes decode.
Fehlerhafte URLs behalten ihren Autorenwert als currentSrc, aufgelöste
fehlgeschlagene URLs ihren aufgelösten Wert. Ein gültiges SVG mit Nullmaßen
lädt erfolgreich, sowohl im Runtime-Zustand als auch im nativen SVG-Metadatenhost.
Eine erneute Zuweisung derselben src löst erneut load/error aus; Quellenwechsel
und Entfernen vor Auslieferung unterdrücken veraltete Ereignisse. Ungültige
Hostmetadaten (fehlende Dimensionen, NaN, negativ oder unendlich) bleiben Fehler.

width/height-Abfragen verbundener Bilder geben nach dem bestehenden
Geometry-Flush die Inhaltsmaße ohne Rahmen und Padding zurück. Abgetrennte
Bilder erzwingen keinen Layoutflush. Die Atelier-Integration prüft diese
Eigenschaften nach unmittelbar vorangehenden CSS-Änderungen am defekten Bild.

Grundlagen: [HTML-Bilder](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element),
[Roblox ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel)
und [Roblox EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage).

## Fontladen

`JavaScript/FontLoading` stellt FontFace, document.fonts, FontFaceSet und
FontFaceSetLoadEvent bereit. FontFace hat getrennte unloaded/loading/loaded/error-
Zustände, eine stabile loaded-Promise, load() sowie die implementierten
Descriptor-Getter/-Setter. Ungültige Quellen/Descriptoren und Hostladefehler
werden als Fehler geliefert; ein nicht vorhandener Decoder wird nicht als
erfolgreiches Laden dargestellt.

document.fonts unterstützt add/delete/clear/has/size, live Werte-/Eintragsiteration,
forEach, check(), load(), status, ready und loading/loadingdone/loadingerror.
Löschen oder clear während der Iteration überspringt keine nachfolgenden/neuen
Einträge. Tote Slots werden kompakt entfernt, wenn keine aktive Iteration mehr auf
deren Position angewiesen ist. Einfaches Gewicht-/Stil-Matching nimmt die nächste
verfügbare Variante; unicodeRange und Textauswahl werden berücksichtigt. check
für eine nicht registrierte Familie liefert true; dies beweist nicht, dass die
Familie existiert, sondern bedeutet, dass der Aufruf keinen registrierten
ausstehenden Fontload findet.

ready startet bei einem noch ladenden Dokument ausstehend und wartet im Ladezyklus
auf document.readyState=complete, die angehängte native FontPreload-Phase sowie
noch ausstehende DOM-/Style-/Layoutarbeit. Der ursprüngliche pending Promise wird
beim Beginn eines Fontloads nicht ersetzt. ReadyState-Wechsel und Paint-Flush
prüfen den Wartezustand direkt an der bestehenden Runtime-Grenze; bereits
erfüllte Zustände erzeugen keine zusätzlichen Tasks. Ein angefordertes Layout
bleibt auch über spätere Paint-Flushes hinweg ausstehend. Erst AfterLayout oder
die abgeschlossene lokale Prüfung unveränderter Textgeometrie gibt es frei.
Es gibt keinen Polling-Timer. BeginHostLoad/EndHostLoad/AfterLayout/
EnvironmentChanged sind die Integrationspunkte. Der Zustandswechsel auf loaded erfüllt ready; separate
Font-Ereignis-Tasks liefern anschließend die Event-Pakete. Anfangs ladende
Dokumente, native Cachezustände und Layout können die beobachtete Gesamtreihenfolge
weiter beeinflussen. FontFaceSetLoadEvent erbt von Event; fontfaces ist readonly,
SameObject und eine FrozenArray.

FontFaceSet ist im geprüften Chromium und im aktuellen Standard kein
konstruierbares Interface; `new FontFaceSet([])` wirft TypeError. Deshalb wird
kein vom Browser abweichender Konstruktor ergänzt.

Die native Brücke lädt eine unterstützte lokale Familie mit passendem CSS-Namen
sowie normal/italic und einer statischen Gewichtung. Sie verwendet den vorhandenen
FontProfiles/FontFamily-Weg und tatsächlichen ContentProvider-Preload. Sie behauptet
keine frei hochladbaren Browserfonts oder Fontaliases.

Grundlage: [CSS Font Loading](https://drafts.csswg.org/css-font-loading/).

## Nachweise und Grenzen

Mit `node scripts/run-html-tests.cjs JavaScriptResourceLoading
JavaScriptLoadingLifecycle ResourceLoadHost ImageResourceRendering Images
ImageDimensions JavaScriptScriptLoader` sind die betroffenen Suiten grün.

JavaScriptResourceLoading prüft Promise-/Ereigniszustände, Quellenrennen,
DOM-/Seitenload-Interaktion, Fontmatching, Iteration, typgeprüfte Font-Events,
Disposal sowie die Kombination aus offenem Skriptladen, nativer FontPreload-Phase,
Layoutfreigabe und Paint-Flush ohne Layout. PageLoading montiert den echten
Layoutbaum und prüft die Freigabe nach stabiler lokaler Textmessung ohne
Seitenlayout oder erneute Observer-Publikation. JavaScriptLoadingLifecycle prüft DOMContentLoaded-Microtasks, einmaliges
window.load, supports und Entfernen/Adoption wartender Skripte. ResourceLoadHost
prüft Host-Dimensionen, einmaliges Decoding für gemeinsame Metadaten/Bilder,
Teilnehmer-Kündigung, Retry, Cleanup und explizite Fehler. ImageResourceRendering
prüft Retention, Raster/SVG-Wechsel, Alttexte, Dimensionen und stabile Texturen.
ImageDimensions und Images sichern die bisherigen Fit-/Sizing-/Layoutpfade ab.

Der Bildfehler-Nachtrag verwendet zusätzlich 18 versionierte native
Chromium-Geometrien (ImageErrorSizing) und neun tatsächliche Browser-Lifecycle-
Fälle (image-error-reference.html). Images/ImageAlignment prüfen Fehlericon,
Inlinekanten und Objektretention; BrowserFoundationsWebsite prüft den
responsive großen Fehlerkasten und sofortige Inhaltsmaß-Getter. Der
ResourceLoadHost-Test sichert erfolgreiche SVG-Nullmaße auch an der realen
Adaptergrenze ab. JavaScriptResourceLoading normalisiert weitere simulierte
Hostfehler (404/500, Decoder, verweigerter Zugriff und Timeout) zum Bildfehler;
dies ist kein Nachweis eines implementierten HTTP-Transports in Roblox.

Diese Luau-Suiten verwenden deterministische Host-/GUI-Mocks. Sie beweisen die
Engine- und Adapterlogik, nicht die Zugriffsrechte auf echte Roblox-Assets oder
deren optisches Ergebnis in Studio. Die echte Chromium-Referenz bestätigt
SVG-Metadaten und decode-vor-load sowie den nicht konstruierbaren FontFaceSet.
Font-Ereignisreihenfolgen hängen zusätzlich von Dokument-/Layout- und Fontcache-
Zuständen ab; ein synchroner Hostmock ist hierfür kein allgemeiner Browserbeweis.
Die separate echte Chromium-Fontprobe zeigte face-loaded, loading, loadingdone,
done-microtask, fonts-ready. Dieser Unterschied zur kontrollierten Hostmock-
Reihenfolge ist kein Nachweis vollständiger nativer Font-Timing-Konformität.
Es wurde kein FPS-Test durchgeführt.

Folgendes bleibt ausdrücklich außerhalb dieses abgeschlossenen Ladepakets:

- Byte-/Netzwerkstreams und ihre Encoding-/Navigationsneustarts sowie übrige
  Parserkontexte. Verknüpfte/importierte CSS-Ladebarrieren, Container-Barrieren,
  nachträgliche CSSOM-Imports und der H03-String-/Schreibstream sind vorhanden;
  ausdrücklich übergebene vollständige Bytequellen werden noch vor Scriptstart geparst.
- Vollständige zyklische Top-Level-Await-Auswertung und sämtliche Importmap-,
  CSP-, SRI-, Fetch-/CORS-/Referrer-Details.
- Beliebige externe Raster-/SVG-URLs, data:/blob:-Bilddecoding und ein allgemeiner
  HTTP-Bildtransport. Roblox-Rechte und EditableImage-Budgets gelten weiterhin.
- Vollständige srcset/sizes-Grammatik, dichtekorrigierte natürliche Bildmaße und
  echte viewportgesteuerte Lazy-Load-Planung. loading=lazy blockiert window.load
  bereits nicht; der derzeitige Host lädt es dennoch sofort.
- Asynchrone Stylesheet-Netzwerkanforderungen mit einer eigenen Lifecycle-Zählung.
  Die derzeitigen abgelegten Stylesheets werden synchron zugeordnet; Änderungen
  an CSSOM/Styleknoten gehen über die vorhandene DOM-/Layoutinvalidierung.
- Automatische CSS-connected FontFace-Objekte für alle @font-face-Regeln, ihre
  bidirektionale Descriptorbindung und automatisches nachträgliches Verwenden
  beliebiger neu registrierter Fontaliases.
- WOFF/WOFF2/TTF-/BufferSource-Decoding, variabler Fontbereich, vollständige
  CSS-Font-Shorthand-/Descriptor-Grammatik und natives Anwenden sämtlicher
  FontFace-Feature-/Variation-/Metrikdescriptoren.

Für die letzte Gruppe gibt es keine stillschweigende Erfolgssimulation. Die
JavaScript-Ladeschnittstellen können durch einen künftigen echten Host erweitert
werden; die vorhandenen nativen Fontprofile werden nicht überschrieben.
