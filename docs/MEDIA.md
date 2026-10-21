# Audio, Video und WebVTT

`audio` und `video` verwenden denselben HTML-Quelltext im Browser und in Roblox.
Der Browser lädt die Pfade aus `src`, `source`, `poster` und `track` direkt. Die
Roblox-Seite ordnet diese Pfade beim Mount eigenen Assets beziehungsweise einem
WebVTT-String zu.

## Kamera- und Mikrofonberechtigungen — 16. Oktober 2026

`navigator.mediaDevices.getUserMedia()` unterstützt jetzt die **Anfrage** für
`video`/Kamera und `audio`/Mikrofon. Ein gemeinsamer Aufruf zeigt einen gemeinsamen
Dialog. Browser und eigenständiger HTML-Fensterhost bieten „Zulassen“, „Blockieren“
und Abbruch. Der Browser verankert ihn unter der Seiteninformation der Adressleiste;
der HTML-Fallback verwendet seinen eigenen Rahmen. Die Oberflächen bleiben passiv
und benutzen ihre bestehenden Eingabe-, Fokus- und Abbaupfade.

`navigator.permissions.query({name: "camera"})` und `microphone` liefern
`PermissionStatus` mit `name`, `state`, `onchange` und `change`-Ereignissen.
Die Zustände `prompt`, `granted`, `denied` gelten pro Herkunft und laufender
Fensterfamilie. Reload und gleichursprüngliche Popups erhalten die Entscheidung;
die nächste Anwendungssitzung beginnt ohne diese gespeicherten Rechte.
Schließen/Escape speichert kein `denied`. Verbergen, Navigieren und Abbau
widerrufen noch offene Anfragen; späte UI-Antworten können nichts mehr freigeben.

Nach Zulassen verwendet `getUserMedia` den optional konfigurierten
`MediaCaptureHost`. Der Demo-LocalScript verbindet jetzt den unten beschriebenen
virtuellen Kamerahost. Ohne Capturehost bleibt `NotSupportedError`, bei Ablehnung
oder fehlendem Berechtigungshost `NotAllowedError`. Der Host öffnet keine Kamera
und kein Mikrofon des Betriebssystems.
Leere Constraints liefern `TypeError`; inaktive Dokumente fragen nicht nach.
Andere Permissionnamen, vollständige Geräte-/Constraintauswahl,
`enumerateDevices`, vollständige Stream-/Track-/Recorder- und Transportfunktionen sowie
vollständige Secure-Context-/Permissions-Policy-Regeln bleiben offen.
Iframe-Anfragen sind in diesem Profil ausdrücklich gesperrt.

Die JS-Fassade liegt in [MediaDevices](../src/HTMLEngine/JavaScript/MediaDevices.luau),
der native Host in [PermissionHost](../src/HTMLEngine/Rendering/PermissionHost.luau).
`JavaScriptServices.PermissionHost` kann ausdrücklich geliefert werden:
`Query(origin, name)`, `Request(request, complete)` mit Abbruchfunktion und optional
`Subscribe(origin, callback)` mit Abmeldung sind Methoden des Hosts. Ohne expliziten
Host verbindet HTMLScripts den bestehenden Dialoghost automatisch. Ein gemeinsamer
`PermissionStore` gehört zur Anwendung; es wird kein DataStore beschrieben.

Die [aktuelle Testseite](../tests/fixtures/retired-nightweb-pages-20261019.json) enthält
Einzel-/Kombinationsanfrage und Statusanzeige. Nachweise:
[JS-Anfragen](../tests/MediaDevicePermissions.luau),
[native Zustände und Lebensdauer](../tests/PermissionHost.luau),
[beide Oberflächen](../tests/PermissionDialogUI.luau).
Grundlagen sind [Media Capture, Stand 9. Oktober 2025](https://www.w3.org/TR/2025/CRD-mediacapture-streams-20251009/)
und die [Permissions-Schnittstelle](https://www.w3.org/TR/permissions/#permissionstatus-interface).
Diese begrenzte Freigabeprüfung erfüllt nicht den vollständigen Medienstandard.

## Virtuelle Kamera aus dem Roblox-Workspace — 16. Oktober 2026

Die Kameraquelle wird im [HTMLPageDemo-LocalScript](../examples/HTMLPage.client.luau)
festgelegt. `CAMERA_PATH` ist eine Folge **direkter** Kindnamen relativ zum
Workspace, zum Beispiel `{"Building", "SecurityRoom", "Camera"}`. Es gibt keine
rekursive Namenssuche. Die Standardfolge `{"Camera"}` kann auch die gewöhnliche
Roblox-`Camera` im Workspace verwenden. Ein `BasePart` oder `Attachment` ist
ebenfalls eine mögliche Quelle; Blickrichtung ist dessen `CFrame` beziehungsweise
`WorldCFrame`. Die Engine verändert `Workspace.CurrentCamera` nicht.

`CAMERA_SCENE_PATH = {}` zeigt die renderbaren Workspace-Teile. Eine Folge wie
`{"Building"}` begrenzt die Szene auf dieses Modell. Eine ausdrücklich konfigurierte,
fehlende Szene wird nicht durch den gesamten Workspace ersetzt. Die Pfade werden
bei jeder Anfrage erneut aufgelöst. Quell-/Szenenverlust beendet lebende Tracks.

Für eigene Einbettungen ist der Host auch ohne Browser und WindowManager nutzbar:

```lua
local capture = Engine.createMediaCaptureHost({
    Camera = function() return workspace.Building.SecurityRoom.Camera end,
    Scene = workspace.Building,
    Width = 640, Height = 360, FrameRate = 30, MaxParts = 1500,
})
local page = Engine.mountHTML(target, HTML, {
    DocumentURL = "https://game.example/camera",
    JavaScriptServices = {MediaCaptureHost = capture},
})
-- Beim Abbau der Anwendung auch capture:Destroy() aufrufen.
```

Nach der Freigabe liefert `navigator.mediaDevices.getUserMedia({video:true})`
einen `MediaStream`. `video.srcObject = stream` und `video.play()` verbinden eine
eigene `ViewportFrame`-/`WorldModel`-Ansicht. `video.pause()` friert die Ansicht ein;
`stream.getTracks().forEach(track => track.stop())` beendet die Aufnahme.
`srcObject = null` trennt nur dieses Video. Mehrere Videos dürfen denselben Stream
anzeigen; das Trennen eines Videos stoppt die übrigen nicht. Trackklone teilen
die native Quelle, bis der letzte lebende Klon gestoppt wird. Reload, Navigation
und Realm-Abbau geben die zugehörigen Tracks und Ansichten frei. Verborgene oder
minimierte Ansichten pausieren ihre native Szenenabtastung und holen beim Anzeigen auf.

Die begrenzte JS-Fassade enthält `MediaStream` aus leerer Liste, anderer Stream-
oder Trackliste, `id`, `active`, Trackabfragen, `addTrack`, `removeTrack`, `clone`
sowie `MediaStreamTrack` mit Identität, Art, `enabled`, `muted`, `readyState`,
`clone`, `stop` und `getSettings`. Eigenes `stop()` erzeugt kein `ended`-Event;
Quellverlust erzeugt eines. `enabled=false` und stummgeschaltete Tracks zeigen
keine Kamerabilder. `getConstraints`/`getCapabilities` liefern hier leere
Wörterbücher; `applyConstraints`, Recorder, WebRTC und Geräteaufzählung fehlen.

Der native Host unterstützt feste Breite/Höhe von 16 bis 4096 und eine Bildrate
von 1 bis zur konfigurierten Obergrenze, höchstens 60. Nicht erfüllbare notwendige
Constraints liefern `OverconstrainedError`; fehlende Quelle/Szene `NotFoundError`.
`audio:true` und kombinierte Kamera-/Mikrofonanfragen liefern derzeit nach der
Berechtigungsentscheidung `NotFoundError`, da keine Tonquelle angeschlossen ist.
Es wird kein stiller Audio-Track erfunden. Iframes behalten ihre bisherige Sperre.

Die Szene wird schrittweise aufgebaut: standardmäßig höchstens 64 Traversierungs-
beziehungsweise Kopierarbeiten pro Abtastung und 1500 Teile je Aufnahme.
`MaxParts` und `BuildBudget` sind konfigurierbar. Ein Host teilt einen Heartbeat
zwischen seinen Aufnahmen; unveränderte Eigenschaften werden nicht neu gesetzt.
Sichere flache `Instance.fromExisting`-Kopien übernehmen nur Teile und erlaubte
visuelle Kinder, keine Scripts, Sounds oder ausführbare Spiellogik.

**Darstellungsgrenzen:** ViewportFrame ersetzt keinen Pixelmitschnitt des
Spielbildes. Terrain, Himmel, Partikel, Posteffekte und vollständige skinned/bone-
Mesh-Verformung werden nicht rekonstruiert; Beleuchtung und Materialien können
vom Workspace abweichen. `contain`/`cover` halten das Quellseitenverhältnis.
Bei `object-fit:fill` rendert Roblox die Szene im Zielseitenverhältnis; eine
nachträgliche Verzerrung eines aufgenommenen Pixelbilds ist nicht verfügbar.
Grundlagen: [ViewportFrame](https://create.roblox.com/docs/ui/viewport-frames),
[WorldModel](https://create.roblox.com/docs/reference/engine/classes/WorldModel)
und [sichere flache Instance-Kopie](https://create.roblox.com/docs/reference/engine/datatypes/Instance).

Umsetzung: [VirtualCameraHost](../src/HTMLEngine/Rendering/VirtualCameraHost.luau),
[MediaStreams](../src/HTMLEngine/JavaScript/MediaStreams.luau),
[StreamVideo](../src/HTMLEngine/Input/StreamVideo.luau).
Gezielte Nachweise: [nativer Kamerahost](../tests/VirtualCameraHost.luau),
[JS-Streams und Lebensdauer](../tests/MediaStreamCapture.luau),
[Videodarstellung und Transport](../tests/MediaStreamVideo.luau).
WindowCheck Abschnitt 7 besitzt Start, Stopp, Livebild und Berechtigungsstatus.
Automatisierte native Doubles bestätigen Verträge und Abbau; eine visuelle
Roblox-Studio-Abnahme wird dadurch nicht behauptet.

## Assetbasierte Wiedergabe

Für die vom Nutzer gewünschte The-Annoying-Site-Umsetzung sind die Medien in
[options.json](../tests/fixtures/retired-nightweb-pages-20261019.json) vorbereitet:
`media/theremin.ogg` → Audio `93424997719572` („Zinc“, vom Nutzer gewählt),
`media/clip.mp4` → Video `5608384572` („Particle Disco Light Experience“, Roblox).
Die öffentlichen Assetdetails bestätigen Typ 3 beziehungsweise 62. Die
Verfügbarkeit im konkreten Experience-Kontext und der Klang wurden damit nicht
in Studio geprüft. Die Basisfrequenz und ein nahtloser Loop des Audioassets sind
nicht belegt; die Namenszuordnung ist keine Behauptung einer reinen Wellenform.
Die [Seite](../tests/fixtures/retired-nightweb-pages-20261019.json) verwendet diese
Zuordnungen jetzt über die vorhandenen Audio-/Videoelemente. Eine Web-Audio-
Oszillatoranbindung wird dadurch nicht behauptet. Die normalen Browserdateien
verwenden lokal erzeugte Vorschau-Medien; ihre Herkunft und die nativen
Assetzuordnungen stehen in [source.json](../tests/fixtures/retired-nightweb-pages-20261019.json).

```lua
local page = Engine.mountHTML(target, HTML, {
    Audio = {
        ["media/tone.ogg"] = "9120386436",
        ["media/tone.mp3"] = "9120386436",
    },
    Videos = {
        ["media/clip.webm"] = "5608384572",
        ["media/clip.mp4"] = "5608384572",
    },
    Images = {
        ["media/poster.png"] = "94339162936897",
    },
    Tracks = {
        ["media/captions.vtt"] = [[WEBVTT

00:00.500 --> 00:02.500
First caption
]],
    },
})
```

IDs dürfen als positive Ganzzahl, Dezimalstring oder vollständige
`rbxassetid://`-Adresse angegeben werden. Die Engine kopiert jede Zuordnung beim
Mount. Spätere Änderungen an der übergebenen Tabelle verändern eine laufende
Seite daher nicht.

## Quellenwahl

Ein direktes `src` hat Vorrang. JavaScriptverwaltetes Audio prüft sonst
`source`-Kinder in DOM-Reihenfolge. Medienbedingungen lesen die aktuelle
Viewportgröße über den gemeinsamen Mediaqueryparser. Ein gültiger Typ wird
nur bei ausdrücklich fehlender Hostfähigkeit ausgeschlossen; eine
Assetzuordnung beweist keinen Codec. Fehler vor Metadaten liefern einen
`error` am betroffenen `source`; eine getrennte Fortsetzung wählt den nächsten
Kandidaten. Nach Metadaten und bei direktem `src` entsteht ein Medienfehler
ohne diesen Fallback. `preload="none"` verschiebt die Vorbereitung bis Play.

Tatsächliche HTMLPage-Seiten verwenden inzwischen auch ohne Realm den
gemeinsamen Auswahlkern für Audio und montierte Videos. Nicht zugeordnete
Kindquellen werden als Kandidaten mit eigenem Fehler behandelt; die Auswahl
setzt anschließend fort. Manuell injizierte ältere MediaRuntime-Aufrufe ohne
ResolveVideo behalten ihr statisches Profil. Die [Audio-Nachweise](JAVASCRIPT-AUDIO-20261006.md#geordnete-source-kandidaten--12-oktober-2026)
trennen diese Pfade ausdrücklich. Browserdateien können unterschiedliche
Formate enthalten, obwohl mehrere Pfade auf dasselbe Roblox-Asset zeigen.

Seit dem 16. Oktober 2026 wird ein fehlgeschlagener nativer Videoladeversuch
nur einmal abgeschlossen. `VideoPlayer.PlayFailed` und das Ende desselben
`LoadAsync` dürfen gemeinsam keinen zusätzlichen VIDEO-Fehler erzeugen,
während die Kindquellenauswahl bereits zur nächsten SOURCE fortsetzt.
Wartende Play-Promises bleiben bis zu deren Erfolg erhalten. Direktes `src`
liefert dagegen einmal einen Medienfehler und versucht keine Kindquellen.
[VideoSourceRetry](../tests/VideoSourceRetry.luau) prüft acht tatsächlich montierte
Fälle: Player/Frame, Realm/JavaScript deaktiviert und direkte/Kindquelle,
einschließlich später alter Rückmeldungen, erhaltenem Backend/GUI/Editor und
Abbau. Frame-Prüfungen verwenden die vorhandene Preload-Statusroute; dies
behauptet keinen zusätzlichen nativen Frame-Fehlerkanal oder Codecnachweis.
Die ursprünglichen vollständigen Auswahlkriterien bleiben im
[Attributregister](html-attributes.v1.json) offen.

## Darstellung und Steuerung

- Audio verwendet ein `Sound`. Video verwendet `VideoPlayer`, `VideoDisplay`,
  `Wire` und `AudioDeviceOutput`; auf Roblox-Versionen ohne diese Pipeline fällt
  die Engine auf `VideoFrame` zurück.
- `controls`, `autoplay`, `loop`, `muted`, `width`, `height`, `preload` und
  Video-`poster` werden ausgewertet. `preload="none"` verschiebt das Laden eines
  `VideoPlayer` beziehungsweise eines JavaScript-Audios bis zum ersten Play; `metadata` und `auto` bereiten die
  Roblox-Ressource im Hintergrund vor.
- Die eigene Roblox-Leiste bietet Play/Pause, eine klick- und ziehbare
  Zeitachse, eine größere Zeitanzeige, Mute, einen klick- und ziehbaren
  Lautstärke-Slider, eine Geschwindigkeitswahl mit `0.5x`, `1x`, `1.5x` und
  `2x` sowie bei vorhandenen Textspuren CC. Mehrfaches CC schaltet in
  Dokumentreihenfolge durch alle Sprachen und anschließend aus. Videos bieten
  zusätzlich Vollbild; `controlslist="nofullscreen"` entfernt diese Aktion.
  Die Controls blenden auf schmalen Medien zuerst Vollbild, CC,
  Geschwindigkeitswahl und zuletzt den Lautstärkeregler aus. Beim
  `VideoFrame`-Fallback wird die nicht verfügbare Geschwindigkeitswahl
  ausgeblendet.
- Buttons und Regler besitzen Hover- und gedrückte Zustände. Medien mit
  `controls` sind per Tab erreichbar und erhalten einen sichtbaren Fokusrahmen.
  Leertaste oder Enter schaltet Play/Pause, Links/Rechts springt fünf Sekunden,
  Hoch/Runter ändert die Lautstärke um `0.1`, `M` schaltet Mute, `C` wechselt
  die Textspur und `F` schaltet Video-Vollbild. Escape beendet Vollbild.
- `page:PlayMedia(id)`, `page:PauseMedia(id)`,
  `page:SetMediaPlaybackRate(id, rate)`, `page:SetMediaVolume(id, volume)`,
  `page:SetMediaTextTrack(id, indexOrLabel)`,
  `page:EnterMediaFullscreen(id)`, `page:ExitMediaFullscreen()` und
  `page:GetMediaState(id)` sind für Elemente mit `id` verfügbar. Eine Textspur
  kann über ihren 1-basierten Index, `label`, `srclang` oder `src` gewählt und
  mit `nil`, `false`, `0` oder `"off"` ausgeschaltet werden. `rate` muss
  zwischen `0.5` und `2`, `volume` zwischen `0` und `1` liegen;
  `GetMediaState` liefert zusätzlich `TextTrack`, `Loading`, `Error` und
  `Fullscreen`.
- `loadstart`, `loadedmetadata`, `canplay`, `error`, `play`, `pause`, `ended`,
  `timeupdate`, `seeking`, `volumechange`, `ratechange`, `texttrackchange` und
  `fullscreenchange` laufen durch das vorhandene lokale Ereignissystem
  `page:On(...)`.
- `Sound` und der `VideoFrame`-Fallback werden einmal über
  `ContentProvider:PreloadAsync()` vorbereitet. `VideoPlayer` verwendet
  `LoadAsync()`. Die Engine startet keine getrennte Dauerschleife je Medium;
  eine gemeinsame, auf zehn Updates pro Sekunde begrenzte Heartbeat-Verbindung
  aktualisiert Zeit und Captions.

## JavaScript-Audio

Seit dem 6. Oktober 2026 steuert normales JavaScript auch `<audio>` und
`new Audio(src)`: `play()` liefert ein Promise; `pause()`, `load()`, Zeitposition,
Lautstärke, Mute, Loop und Rate sind mit demselben Sound wie die sichtbare
Steuerleiste verbunden. Audio ohne Controls bleibt unsichtbar und kann dennoch
spielen. Die Dateipfade benötigen in Roblox weiterhin `options.Audio`.
Wiedergabe- und Lautstärkeänderungen lösen keine Seitenlayouts aus.

```js
const tone = new Audio("media/tone.ogg");
tone.volume = 0.4;
playButton.addEventListener("click", () => {
    tone.play().catch(error => console.error(error.name, error.message));
});
pauseButton.addEventListener("click", () => tone.pause());
```

Das [JavaScript-Audioprofil](JAVASCRIPT-AUDIO-20261006.md) enthält die vollständige
implementierte API, Ereignisse, Beispiele, Prüfung und offene Grenzen.
JavaScript-Audio-Zeitereignisse sind auf etwa vier pro Sekunde begrenzt.
Die Video-JavaScript-API und Web Audio sind damit noch nicht vollständig
implementiert.

## Gemeinsame Video-JavaScript-Bindungen · 12. Oktober 2026

Die bereits installierten 21 gemeinsamen HTMLMediaElement-Zustands- und Methodenbindungen akzeptieren jetzt echte HTML-VIDEO-Receiver. Reine Daten bleiben am Node vor Mount und nach Remove/Wiederanfügen erhalten; die vorhandene MediaRuntime-Registrierung besitzt weiter eine Auswahl und ein natives Backend. Video verwendet keinen AudioController oder Sound. Script-Volume erhält muted, Zeitwerte sind Sekunden und Script-Raten übernehmen keine UI-Clamps. Getter starten weder neue Auswahl/IO noch Layout.

Der [begrenzte Nachweis](HTML-PARSER-ATTRIBUTES-20261006.md#gemeinsame-video-javascript-bindungen--12-oktober-2026) umfasst 21/31 Bindings, Mounted18/1374 mit ursprünglichen16 plus zwei Positionsfällen, zwölf Cleanup-Fehlerfälle, Reentry2/153 und kompakt6+3/45+3/19. Nach unabhängigem Review fe7fa301 wurden Source7/Test7 exakt übernommen; Root22 einschließlich verpflichtender compact12 hat tatsächlichen Exit0. V1 bleibt historisch BLOCKED und nicht produktiv; vollständige Originale und der genaue MediaReflection-Gegenpart bleiben erhalten.

Detached Transport, acht fehlende IDLs, Video-Cross-Realm-Besitz, vollständige Medien-Taskordnung, Decoder-/Studioframes und allgemeines Page-/Realm-GC bleiben separat offen.

## Gemeinsame Reflexion und lebende Videos · 11. Oktober 2026

Die sieben gemeinsamen Audio-/Video-Reflexionen `src`, `preload`, `crossOrigin`,
`autoplay`, `loop`, `controls` und `defaultMuted` sind an der tatsächlichen VM
geprüft. Ein Video verwendet dafür keinen Audio-Sound oder AudioResourceState.
URL-Getter lesen die aktuelle Dokumentbasis; sie verändern eine bereits
ausgewählte Ressource nicht. `preload` ignoriert ASCII-Großschreibung, aber keinen
Leerraum. Fehlende/ungültige Werte verwenden hier das dokumentierte UA-Profil
`metadata`, keine universelle Browservorgabe.

Bereits montierte Videos erhalten Controls-/Quellen-/Loop-/Preload-/Autoplay-
Änderungen ohne Ersatz ihres GUI- oder Wiedergabebesitzers. Controls bleiben als
einmal erstellter Teilbaum erhalten; Tastaturaktionen und Vollbildgröße folgen
dem aktuellen Zustand. Eine geänderte `defaultMuted`-Reflexion setzt keine
bestehende Mutepräferenz zurück. Quellenwechsel sperren alte Jobs und alte
Callbackclosures. [MediaLiveRendering](../tests/MediaLiveRendering.luau) prüft
beide Backends, echte HTMLScripts-/Controllerpfade, erhaltene Editor-/UTF16-
Auswahl und Abbau. Die unabhängige finale Prüfung besteht mit sieben Suiten,
72 Zuständen, 32 Race- und zehn weiteren Randfallkontrollen.

Die [Mediennachweise im Attributprofil](HTML-PARSER-ATTRIBUTES-20261006.md#gemeinsame-medienattribute-und-montierte-videos--11-oktober-2026)
enthalten Rohdaten, getrennte Standarddifferenzen und genaue Grenzen. Diese
GUI-/Backend-Ersatzprüfungen belegen keine Studio-Videopixel. Roblox-Signale an
einen neuen Handler tragen keine Kennung ihrer vorherigen Quelle; wirklich
verspätete neue Signallieferungen bleiben von gesperrten alten Callbacks und
Ladefortsetzungen zu unterscheiden. Der folgende Nachtrag ergänzt Video-Poster,
Größen und die Strukturinvalidierung von Quellkindern. Vollständige geordnete
Videoquellenauswahl, dynamische Tracks und Video-JavaScript bleiben offen.

## Poster, Videogrößen und Bildflächen · 12. Oktober 2026

`poster` und `playsInline` besitzen geprüfte Reflexionen; Video-`width` und
`height` teilen den vorhandenen unsigned-long-Pfad und dimensionale
Darstellungshinweise. `videoWidth` und `videoHeight` sind vor Metadaten Null,
lesen danach die gültige native Auflösung und werden bei einem neuen
`src`-Setzen sofort zurückgesetzt, auch vor dem Rendercheckpoint. Die optionale
Auflösungsbenachrichtigung prüft aktuelle Quelle, Verbindung und Lebensdauer.

Poster haben eigene abbrechbare Ladebesitzer, auch ohne JavaScript. Mit Realm
halten ausstehende Poster die geprüfte Dokument-Ladebarriere. Der No-JS-Nachweis
prüft den initialen Lade-/Decode-/Renderpfad; der allgemeine Dokument- und
Sichtbarkeitsverschluss ohne Realm bleibt offen. Ein alter Poster bleibt während einer neuen Anfrage
erhalten; leerer, fehlender oder fehlgeschlagener Ersatz entfernt ihn. Alte
Antworten veröffentlichen nichts. Vorbereitete SVG-Daten sind noch keine
aktive Posterfläche: Erst erfolgreich geladene Poster werden im bestehenden
SVG-Pfad angemeldet. Anfangs- und dynamische Videos, während Wiedergabe
ausgeblendete SVG-Poster,
Entfernung und Abbau sind gesondert geprüft.

Normale und Vollbildflächen verwenden denselben `object-fit`-/
`object-position`-Pfad. `VideoDisplay` dehnt für `fill` das Bild; `contain`
und `cover` folgen den berechneten Bildflächen. Backend, GUI, Controls,
Editor und UTF16-Auswahl bleiben bei Änderungen erhalten.

[VideoPresentationDOM](../tests/VideoPresentationDOM.luau) prüft 130 Fälle und
sechs separat gespeicherte USV-Projektionen.
[VideoPresentationRendering](../tests/VideoPresentationRendering.luau)
prüft 152 Browsergeometrien, 28 zusätzliche kontrollierte
Lebenszyklusgeometrien und 40 benannte Controls mit 5.490 Assertions. Sechs
echte HTTP-Posterzustände belegen die Ladebarriere. Zwei Chromium-Zwischenwerte
ohne natürliche Größe bleiben als Rohdaten neben der eingefrorenen
Standarderwartung erhalten. Der unabhängige Zehn-Suiten-Lauf und der gemeinsame
14-Suiten-Medienlauf bestehen, einschließlich isolierter Lebensdauerprüfungen.

Dieser Umfang belegt keine Studio-Videopixel, Decoderphase oder vollständige
Video-JavaScript-API. Die Bindung des entsorgten Seitenbesitzers durch eine
gehaltene native Anfrage ist inzwischen für Host-eigene Bezüge und einen
tatsächlichen no-JS-Poster-Seitenabbau korrigiert und vor Resume geprüft;
[Umfang und Grenzen](HTML-PARSER-ATTRIBUTES-20261006.md#seitenabbau-während-nativer-bildarbeit--12-oktober-2026).
Details und Rohdaten stehen im
[Attributprofil](HTML-PARSER-ATTRIBUTES-20261006.md#video-poster-und-intrinsische-größen--12-oktober-2026).

## Öffentliche Video-Zeitsprünge und Posterwechsel · 13. Oktober 2026

Der gemeinsame öffentliche `currentTime`-Pfad wechselt nach einem erfolgreichen
Zeitsprung vor dem ersten Play vom Poster zur verfügbaren Videofläche. Zuvor
kehrte die Steuerleiste nach dem Aufruf des öffentlichen Setters zurück,
bevor dessen Posterflag und Darstellung aktualisiert wurden: Die unveränderte
Referenz verlangte 80 × 40, die Engine behielt das Poster mit 120 × 240.
Die Korrektur sitzt im gemeinsamen [VideoServices](../src/HTMLEngine/Input/VideoServices.luau),
damit Scriptsetter und die Links-/Rechtssteuerung denselben Pfad benutzen.

Vor Metadaten speichert `currentTime` nur die Startposition. Ein positiver
gespeicherter Start wird bei Metadaten auf die verfügbare Dauer begrenzt und
dann angewendet; Null oder ein negativer gespeicherter Start löst dort keinen
Sprung aus. Posterwechsel erfolgen nach dem erfolgreichen nativen Schreibzugriff
und der Prüfung des aktuellen Besitzers. Die Darstellung veröffentlicht die
neue natürliche Größe und fordert bei Bedarf ein lokales Layout an, bevor
synchrone `VideoState`-Subscriber über den Zeitsprung benachrichtigt werden.
Die DOM-Ereignisse `seeking` und `seeked` behalten ihre getrennten, bereits
vorhandenen Taskpfade; dies ist keine vollständige Medien-Ereignisabnahme.
Nach einer rückmeldenden Darstellung wird der Besitzer erneut geprüft.

[VideoSeekPresentation](../tests/VideoSeekPresentation.luau) prüft 78 Fälle mit
501 Assertions; [VideoSeekPresentationMounted](../tests/VideoSeekPresentationMounted.luau)
prüft 24 tatsächliche HTMLPage-/VM-/Controllerfälle mit 1.739 Assertions.
Beide Backends, direkte Setter, verzögerte Metadaten, Null-/Negativ-/Dauergrenzen,
erneute Quellwahl während nativer Schreib- und Darstellungscallbacks sowie
erste rohe nil-/false-/Tabellenfehler an diesen Grenzen sind geprüft.
Die unveränderte [Darstellungsreferenz](../tests/VideoPresentationRendering.luau)
besteht aktuell mit 152 erfassten Geometrien, 28 Lebenszyklusgeometrien,
40 benannten Controls und 5.636 Assertions. Alle 14 ursprünglichen
Video-/Mediennachbarsuiten haben tatsächlichen Exit 0; der ursprüngliche
Regressions-Rotbeleg bleibt erhalten.
Der [aktuelle gemischte Produktionslauf](../build/namespace-video-production-focused-v2-full16.log)
besteht nach der exakten Quellenübernahme mit 18 Suiten und tatsächlichem
Exit 0; ein breiter neuer Gesamtprüfstand ist davon getrennt. Die bisherigen datierten Nachweise
und ihre damaligen Zähler werden nicht nachträglich ersetzt.

Nach dem Posterwechsel erzeugen wiederholte Zeitsprünge in den geprüften
automatischen und festen CSS-Größen kein weiteres Layout, kein neues natives
Objekt und keine neue Ladearbeit. GUI, Editor und UTF16-Auswahl bleiben erhalten.
Der erste Wechsel der natürlichen Größe kann auch bei fester CSS-Größe weiterhin
den vorhandenen lokalen Layoutpfad anfordern. Seekable-Ranges, Abbruch oder
Zusammenfassung verschachtelter Sprünge derselben Quelle, vollständige
asynchrone Ereignisordnung, Decoder-/Frameverfügbarkeit, sonstige Property-/
Callbackfehler und native Studio-Pixel/FPS bleiben getrennt offen.
Diese begrenzte Korrektur schließt weder die gesamte Medien-API noch den
Gesamtprüfstand und ändert keine Register-Erfüllungsstände.

## WebVTT-Teilumfang

Unterstützt werden Textspuren an Audio und Video, eine `WEBVTT`-Kopfzeile,
optionale Cue-IDs, Zeitmarken in
`mm:ss.mmm` oder `hh:mm:ss.mmm`, mehrzeiliger Cue-Text und einfache Entfernung
von Markup. `&amp;`, `&lt;`, `&gt;` und `&nbsp;` werden decodiert. Die Standardspur
wird zunächst aktiviert; mehrere Spuren können nacheinander gewählt werden.

Noch nicht unterstützt sind Regionen, Positions-/Ausrichtungseinstellungen,
Cue-CSS, Voice-/Language-Spans, mehrere gleichzeitig aktive Spuren, dynamisch
hinzugefügte Track-Knoten, freie Raten außerhalb `0.5` bis `2`, echte
Puffer-/Netzstatistiken, Streaming, Picture-in-Picture, MediaSource und DRM.
`preload="metadata"` kann wegen der Roblox-APIs nicht getrennt von einem
vollständigen Asset-Load abgebildet werden. `controlslist` unterstützt derzeit
`nofullscreen`; Download und Remote Playback werden ohnehin nicht angeboten.
Roblox-Assets müssen für die Experience freigegeben sein; sonst bleibt die
Ressource trotz korrekter Zuordnung nicht abspielbar.

Die frühere sichtbare Medienseite wurde beim Neustart des Testkatalogs entfernt.
`tests/Media.luau` und `tests/MediaRuntime.luau` decken Auswahl, Darstellung und
Steuerung weiterhin ab. `tests/JavaScriptAudio.luau` und `tests/AudioHost.luau`
prüfen zusätzlich JavaScript und die gemeinsame native Audiosteuerung.

## Geordnete Videoquellen · 12. Oktober 2026

VideoPlayer und VideoFrame teilen die geordnete Auswahl, stabile Fortsetzung, live SOURCE-Position, Fehlerpfade, None-Resume und historischen Quellenkontext. Quellenreset stoppt den alten Transport; GUI und Backend bleiben erhalten. `page:LoadVideo(id)` lädt die aktuelle Struktur erneut, ohne eine vollständige JS-`video.load()`-API zu behaupten. 28 Anfangsfälle und 41 Livekontrollen/7.203 Assertions sowie unabhängige und produktive Regressionen belegen den [genauen Umfang](HTML-PARSER-ATTRIBUTES-20261006.md#geordnete-videoquellen-auf-erhaltenen-backends--12-oktober-2026). Detached/display:none, die Dokumentladebarriere vor Rendererregistrierung, Lazy, native Decoder und Studio bleiben separat offen.

## Audio zwischen lebenden Realms · 12. Oktober 2026

Das [Audio-Besitzprofil](JAVASCRIPT-AUDIO-20261006.md#audio-besitz-zwischen-zwei-lebenden-realms--12-oktober-2026)
beschreibt die produktiv übernommene Audioownership: ein Zustand/Sound,
aktueller Backendbesitzer B und ursprüngliche A-Tasks/Play-Promises.
Die ursprünglichen 40 Kontrollen/192 Assertions bleiben erhalten; vier
additive Schedulerfälle/28 Assertions ergeben 44/220 in acht Modi.
Unabhängiger v2-Review und produktiver 22-Suiten-Lauf bestehen mit tatsächlichem
Exit 0; separate physische CandidateHost27/282 und Core18/49 sowie die aktuellen
Produktionstails sind getrennt belegt. Der v1-Review bleibt mit seinem reproduzierten
Drop(nil)-Fehler als BLOCKED erhalten. Chromium-Adoptions-Reload und aktuelle EventB-Objekte sind
benannte UA-Profile, kein Frozen-Adoptionstrigger oder TaskqueueB-Nachweis;
Eventflags bleiben separat streng. Runtime.Destroy ist kein Iframe-Inaktivitäts-
modell. VIDEO-/noRealm-Übergänge, Decoder, ganze Realm-/Page-GC und zerstörte
VM-Operationen sind damit nicht geschlossen.

## Versteckte Medien-Fallbackinhalte · 12. Oktober 2026

Die fünf Quellmodule und fünf additiven Tests sind nach unabhängigem Kandidatenreview exakt produktiv übernommen. Der anschließende Rootlauf mit 14 betroffenen Suiten hat tatsächlichen Exit 0. Der unabhängige statische Kopierreview b1d5ef2b ist abgeschlossen, ohne Blocker und ohne weiteren Engine-Lauf. Er bestätigt Source5/Test5, die strikten Full41-/Runner-/Loader-Inversen sowie 661 unveränderte Pins. Kein Gesamt- oder Studioabschluss.

Der [Fallback-Pfad](HTML-PARSER-ATTRIBUTES-20261006.md#versteckte-medien-fallbackinhalte--12-oktober-2026)
erlaubt normale DOM-Mutationen unter unterstütztem Audio/Video, ohne gewöhnliche
Fallbackboxen zu erzeugen. Direkte HTML-SOURCE bleiben von fremden und verschachtelten
Quellen getrennt. Versteckte Runtime-/Observer-/Script-/Style-/Bildsemantik sowie
Editor-Move-in/out mit Wert/UTF16-Auswahl bleiben aktiv; normale Controls/Fokus-/
Hitindizes werden korrekt abgebaut. 30 montierte Kontrollen, die streng korrigierte
41-Fall-Gegenprobe und acht Nachbarn bestehen im anschließenden produktiven Root-14er-Lauf. Zwei instrumentierte Cascadekontrollen belegen eng lokale No-op-/Text-
Arbeit und konservative :has/:empty/dir=auto-Abhängigkeiten. Native 16+2, Top14 und
Shadow8 bleiben separat; TopLayer-/AREA-/Shadowvollständigkeit, Decoder, Pixel,
physische Cancel- und allgemeine Performance-/GC-Achsen werden nicht geschlossen.

## Dokumentladebarriere für Videos · 12. Oktober 2026

Bereits vom Renderer angemeldete, verbundene VIDEO-Elemente besitzen mit Realm
einen gezählten Dokument-Loadverschluss. Auswahlreservierung und Delay-load-
Zustand sind getrennt; queued Daten-/Suspend-/Fehlerpfade, Resume und Abbau
halten aktuelle Epochengrenzen. Vier Schutzstellen nach synchronem
ResourcesChanged und eine Add-Batch-Lebensdauerprüfung verhindern alte
Fortsetzungen nach Stop oder einer neueren Auswahl. Der Datenproxy bleibt
Loaded/IsLoaded; die synchrone loadedmetadata-/canplay-Reihenfolge und ein
tatsächlicher erster Decoderframe sind damit nicht gleichgesetzt.

Der [genaue Umfang](HTML-PARSER-ATTRIBUTES-20261006.md#dokumentladebarriere-für-videos--12-oktober-2026) enthält 38 ursprüngliche Kontrollen/4.595 Assertions,
vier unveränderte unabhängige Fehlerfälle jetzt ohne Fehler und 17 additive
Kontrollen/1.707 Assertions, insgesamt 59. Unabhängige acht Suiten und
physische Core18/49 sowie der anschließende produktive 17-Suiten-Lauf
bestehen mit tatsächlichem Exit 0. V1 bleibt als BLOCKED-Rotbeleg erhalten.
Die folgende [Prüfung vor Media:Add](HTML-PARSER-ATTRIBUTES-20261006.md#dokumentladebarriere-vor-der-video-rendererregistrierung--12-oktober-2026) ergänzt die bislang offene
Rendererregistrierungsgrenze. Lazy, detached/hidden, No-Realm-Dokument-/
Iframe-Load, vollständige JS-API und Streaming/Decoder bleiben getrennt offen.
Studio-Pixel und allgemeines Page-/Realm-GC bleiben getrennt offen.

## Video-Ladebarriere vor Rendererregistrierung · 12. Oktober 2026

Mit Realm reserviert ein neu verbundenes Video seinen Ladebeitrag vor dem
kooperativen Rendererflush. Der O(1)-Zähler verhindert den zuvor möglichen
Dokumentabschluss zwischen DOM-Verbindung und Media:Add. Die Übernahme in den
registrierten Besitzer bleibt atomar bei einem Beitrag. Neue Quellen,
None-Suspend, Fehler, abgelehnte Rendererpublikation und Besitzerabbau lösen
jeweils nur die aktuelle Reservierung.

Die gespeicherte Eingabefassade und der neue Medienbesitzer beenden denselben
Besitzer. Verschachtelter Stop räumt Registrierung, Backend und Verbindungen
einmal ab; der erste nil-/false-/table-Notifyfehler wird danach unverändert
weitergegeben. [Drei produktive Tests](HTML-PARSER-ATTRIBUTES-20261006.md#dokumentladebarriere-vor-der-video-rendererregistrierung--12-oktober-2026) prüfen 24/2.697, 21/1.136 und
28/2.673, insgesamt 73 Fälle/6.506 Assertions. Unabhängige und produktive
19-Suiten-Läufe samt verpflichtendem Core18/49 haben tatsächlichen Exit 0.
Der verworfene Pre-render-v1 und seine zusätzliche Receiver-Rotprobe bleiben
als BLOCKED erhalten; die ursprünglichen 45 Testfälle sind bytegleich.

Neun native Referenzfälle/21 Zustände bleiben unverändert. Native hält auch
ein entferntes, noch ladendes Video bis zur Antwort offen; der Engineabbau
eines nicht mehr zuständigen Rendererbesitzers ist deshalb eine ausdrücklich
engere Besitzpolicy. Detached/display:none, Lazy, No-Realm-Dokument-/Iframe-
Load, erster Decoderframe, Studio-Pixel, erzwungene Geometrie-Reentry und
allgemeines Page-/Realm-GC sind damit nicht abgeschlossen.

## Dokumentladebarriere ohne Engine-VM · 12. Oktober 2026

Die produktiv übernommene Erweiterung gibt tatsächlichen HTMLPage-Seiten auch ohne JavaScript-
Runtime einen gelatchten, verzögert erneut geprüften Dokumentabschluss.
Bereits bekannte Native-AUDIO-, rendererbasierte VIDEO-, Poster- und
IFrame-Beiträge halten ihn offen. Er fragt keine globale Requestzahl ab
und startet keine VM. Der vorhandene Realmpfad bleibt beim ScriptLoader.
Interaktive und vollständige Zustandsmeldungen verwenden weiterhin Strings;
spätere Ressourcen nehmen einen erreichten Abschluss nicht zurück.

Der [begrenzte Nachweis](HTML-PARSER-ATTRIBUTES-20261006.md#dokumentladebarriere-ohne-engine-vm--12-oktober-2026) enthält die unveränderten zehn ursprünglichen
Fälle mit jetzt null Fehlerbeobachtungen/1.319 Checks und 33 additive
Kontrollen/3.071 Assertions. Der eigene 14-Suiten-Lauf samt ursprünglichen
73 Besitzerkontrollen/6.506 Assertions und Core18/49 hat tatsächlichen
Exit 0. Unabhängiger Review9f16fe36 und anschließender produktiver
14-Suiten-Lauf bestehen ebenfalls; Source4 und zwei Testkörper sind exakt
übernommen. Produktionshold f542af4e schützt36 aktuelle/505 historische
Pins und sieben Projekte;1.671 Full15-Altdateien bleiben unverändert.

Fünf Browserfälle/elf Rohzustände/48 Kontrollen betreffen gesperrte
Kindskripte; sie beweisen keine browserseitige Abwesenheit von Window oder
Realm. Eager-Bilder, öffentliche contentDocument/contentWindow-/readyState-
Fassaden, automatische Navigation nach VM-iframe.src, Lazy, erste native
Decoderframes, ForcedGeometry und allgemeines Page-/Realm-GC bleiben
getrennt offen und werden nicht als technische Unmöglichkeiten bewertet.


## Verzögertes VIDEO-/Posterladen · 16. Oktober 2026

`loading="lazy"` verschiebt jetzt bei tatsächlichen HTMLPage-Seiten sowohl die
Videoressource als auch das Poster, auch wenn JavaScript eingeschaltet ist,
aber keine Engine-VM benötigt wird. Die Elemente behalten ihre Layout- und
GUI-Objekte. Fehlendes, ungültiges und `eager`-Loading laden regulär; `LaZy`
ist gültig, umgebende Leerzeichen werden nicht entfernt. Bei ausgeschaltetem
Scripting sind beide Ressourcen nach dem eingefrorenen Ziel eager.
`HTMLMediaElement.loading` reflektiert `lazy` oder `eager`; das gemeinsame
IDL-Member ist auch bei AUDIO vorhanden, dessen Lazy-Ladealgorithmus hiermit
nicht implementiert ist.

Die Seite besitzt genau einen [LazyMedia-Besitzer](../src/HTMLEngine/Rendering/LazyMedia.luau).
Er hält getrennte Medien-/Posterfortsetzungen und prüft ausschließlich wartende
Ziele nach Layout, Scrollen, Resize und vorhandenen Transform-/Animation-
Publikationen. Temporäre 1-ms-Arbeitsbudgets teilen lange Prüfungen kooperativ;
im Leerlauf bleiben weder Scan noch zusätzliche Frameverbindung zurück.
`LazyMediaMargin` ist ein optionaler nichtnegativer Pixelabstand beim Mount,
standardmäßig 0. Das ist eine explizite Hostpolicy; native Browser wählen ihre
Vorladeabstände selbst. Normale Overflow- und Positionierungsfälle folgen der
Containing-Block-Kette, einschließlich fixed-/absolute-Ausbrüchen und inline
ersetzten Videos. Exakte nichtrechteckige Clips, transformierte Paddingclips,
Top-Layer- und weitere vollständige Intersection-Geometrie bleiben offen.

Sichtbarkeit im Prüfbereich oder Wechsel zu eager setzt Medien und Poster
fort. `preload` und `autoplay` übergehen Lazy nicht. Nach dem eingefrorenen
HTML-Algorithmus setzt `play()` nur die Medienfortsetzung fort; `load()` tut
dies ebenfalls und beginnt dann einen neuen Ladealgorithmus, der erneut lazy
warten kann. Ein Poster hält erst ab seinem tatsächlichen Fetch eine eigene
Dokumentladebarriere. Ein bereits erreichtes Dokument-`load` wiederholt sich
nicht. Quellen-/Posterwechsel, Entfernen und Abbau löschen alte Fortsetzungen;
späte native Antworten publizieren nicht mehr. Veröffentlichungs- und
Akquisitionsfehler lösen die Posterbarriere vor Weitergabe des ersten originalen
Fehlers, einschließlich `nil`/`false`/Table-Fehlerwerten.

[VideoLazyLoading](../tests/VideoLazyLoading.luau) prüft 80 montierte Fälle mit
3.874 Assertions für beide vorhandenen nativen Ersatzbackends; weitere
18 [Besitzerprüfungen](../tests/LazyMedia.luau) betreffen Reentry, Abbruch,
Fehler, kooperatives Warten und erzwungenen Abbau. Die unabhängige
[Chrome-155-Rohreferenz](../tests/fixtures/video-lazy-browser.json) enthält
13 HTTP-Fälle mit wirklichen PNG-/PCM-WAV-Anfragen. Sie bestätigt die
Grundauswahl, Scroll-/Eager-Fortsetzung und Posterersetzung, zeigt aber auch
Abweichungen: Chrome verschiebt in dieser Aufnahme bei offscreen `play/load`
weiterhin beide Anfragen und bei abgeschaltetem Scripting weiterhin das Poster.
Auch das beobachtete leere `currentSrc` während Lazy unterscheidet sich vom
hier beibehaltenen Zielpfad mit vor dem Fetch ausgewählter Quelle. Diese
Rohzustände bleiben erhalten; sie werden nicht als Gleichheit umgeschrieben.
Grundlage ist die [eingefrorene HTML-Quelle](https://raw.githubusercontent.com/whatwg/html/ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c/source)
mit SHA256 `49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f`.
Die ursprüngliche Lazy-Anforderung und die Studio-/Decoderabnahme bleiben offen.
