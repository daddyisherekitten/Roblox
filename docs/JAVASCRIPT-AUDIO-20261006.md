# JavaScript-Audio · 6. Oktober 2026

Gewöhnliches HTML-JavaScript kann nun den vorhandenen Roblox-Soundhost steuern.
`Audio()` und `new Audio(src)` erzeugen echte `HTMLAudioElement`-DOM-Knoten.
Dasselbe Modell gilt für vorhandene `<audio>`-Elemente, entfernte Elemente und
die sichtbare Roblox-Steuerleiste. Es benötigt keine JavaScript-Erweiterung.

## Verwendung

```html
<button id="play">Ton abspielen</button>
<button id="stop">Pause</button>
<script>
const tone = new Audio("media/tone.ogg");
tone.volume = 0.4;
document.getElementById("play").addEventListener("click", async () => {
  try {
    await tone.play();
  } catch (error) {
    console.error(error.name, error.message);
  }
});
document.getElementById("stop").addEventListener("click", () => tone.pause());
// tone.currentTime = 0; setzt einen geladenen Ton an seinen Anfang.
</script>
```

Der Browser lädt die Datei unter diesem Pfad. Roblox braucht beim Mount dieselbe
Pfadzuordnung wie statisches Audio:

```lua
local page = Engine.mountHTML(target, HTML, {
    Audio = { ["media/tone.ogg"] = "rbxassetid://DEINE_SOUND_ID" },
})
```

`DEINE_SOUND_ID` ist durch die ID eines für diese Experience freigegebenen
Sound-Assets zu ersetzen. Die Zuordnung wird beim Mount kopiert. Sie ist kein
HTTP-Decoder; Audio-Data-URLs, Blob-URLs und beliebige Webdateien werden nicht
automatisch in Roblox-Sounds umgewandelt.

## Implementierter Umfang

| Oberfläche | Verhalten |
| --- | --- |
| Konstruktion/Identität | `Audio()`, `new Audio()`, `new Audio(src)`, `HTMLAudioElement` und `HTMLMediaElement`-Prototypen; Audio setzt `preload="auto"`. |
| Methoden | `play()` mit Promise, `pause()`, `load()`, `fastSeek(time)`, `canPlayType(type)`. Wiederholtes `play()` startet einen laufenden Sound nicht neu. |
| Eigenschaften | `src`, `currentSrc`, `preload`, `crossOrigin`, `autoplay`, `loop`, `controls`, `defaultMuted`, `muted`, `volume`, `currentTime`, `duration`, `playbackRate`, `defaultPlaybackRate`, `paused`, `ended`, `seeking`, `readyState`, `networkState`, `error`. |
| Fehler/Bereiche | `MediaError` mit Code/Message und Konstanten, `TimeRanges` mit `length/start/end`; statische Kopien von `buffered`, `seekable`, `played`. |
| Ereignisse | `loadstart`, `abort`, `emptied`, `suspend`, `durationchange`, `loadedmetadata`, `loadeddata`, `canplay`, `canplaythrough`, `play`, `waiting`, `playing`, `pause`, `timeupdate`, `seeking`, `seeked`, `volumechange`, `ratechange`, `error`, `ended`; auch über `on…`-Handler. |
| Ressourcen | Eine Sound-Instanz je gebundenem Audioelement, einschließlich dynamischer Controls; Quellenwechsel und veraltete Ladeantworten werden generationengeprüft. Ein Seitenwechsel zerstört Sounds und Verbindungen. |

`play()` wird nach `playing` erfüllt. Microtasks aus einem `playing`-Handler
laufen vor der entsprechenden Promise-Reaktion. `pause()` und ein Load-Reset
einer bereits ausgewählten Ressource brechen betroffene offene Play-Promises
mit `AbortError` ab. Bereits zur Erfüllung oder Ablehnung vorgemerkte Ergebnisse
werden beim Reset zuerst abgeschlossen. `load()` bei `NETWORK_EMPTY` erhält
ein wartendes Play-Promise und dessen Wiedergabeabsicht. Ein fehlendes Asset ergibt
`NotSupportedError` und einen tatsächlichen Fehlerzustand. Ohne ausgewählte
Quelle darf ein Play-Promise zunächst offen bleiben. Ein Quellenwechsel meldet
keinen Erfolg der alten Quelle.

Direktes `src` hat Vorrang; ohne `src` wird die erste typkompatible, zugeordnete
`source` gewählt. Ein gesetztes direktes `src`, auch derselbe oder ein leerer
Wert, aktiviert den Load-Reset. Bloßes Entfernen des Attributs behält dagegen
die ausgewählte Quelle, Position, Rate und laufende Wiedergabe. Änderungen oder
Entfernung vorhandener `source`-Kinder ersetzen die Auswahl ebenfalls nicht;
dafür ist `audio.load()` erforderlich. Ein neues `source`-Kind kann die Auswahl
bei `NETWORK_EMPTY` starten. Diese Ressourcenauswahl ist vom ausdrücklichen
Load-Reset getrennt und erhält ein bereits offenes Play-Promise.

`preload="none"` wählt die Quelle, bereitet sie aber erst bei Play, Autoplay
oder einer Hint-Aufwertung vor. Dabei wird die ausgewählte Ressource fortgesetzt,
auch wenn das zugehörige DOM-Attribut inzwischen entfernt wurde. `currentSrc`
wechselt bei erfolgreicher Auswahl nach dem stabilen Zustand. Eine leere oder
fehlende Quelle überschreibt dabei nicht vorschnell den bisherigen URL-Wert.
Verbundene, ladende Audioelemente halten die Dokument-Loadbarriere; ein entferntes
Element blockiert sie nicht weiter. Bleibt ein zuvor verbundenes Audio nach allen
Microtasks außerhalb seines aktuellen Dokuments, pausiert es intern. Synchrones
oder rechtzeitiges Microtask-Wiedereinfügen verhindert diese Pause. Ein nie
eingefügtes `new Audio()` kann weiterhin spielen. Erneutes Einfügen eines bereits
pausierten Elements startet es nicht von selbst.

Lautstärke, Mute, Zeitposition, Rate und Wiedergabe erzeugen keine DOM- oder
Layoutinvalidierung. Die Steuerleiste teilt den nativen Zustand. `controls`
verändert hingegen die Darstellung: Audio ohne Controls berechnet sich selbst
bei entgegenstehendem Autoren-CSS als `display:none`. Entfernen/erneutes
Einfügen oder Umschalten von Controls ersetzt den laufenden Sound nicht; ein
dauerhaftes Entfernen aus dem Dokument unterliegt trotzdem der obigen Pauseregel.
Native Audio-Zeitereignisse werden gemeinsam auf etwa vier pro Sekunde begrenzt;
die vorhandene Steuerleisten-/Caption-Aktualisierung bleibt separat begrenzt.

Eine vor Metadaten gesetzte `currentTime` ist eine eigene Startposition und
kein Seek auf einem noch unbekannten Sound. Leeres Laden und spätere
Quellenauswahl erhalten sie. Bei Metadaten wird eine positive Startposition auf
die verfügbare Dauer begrenzt und anschließend verbraucht; Null und negative
Frühwerte werden ebenfalls gelöscht. Alte Ladeantworten dürfen den Frühwert
einer neueren Quelle nicht verbrauchen.

## Konkrete Grenzen

- Dieses Profil bindet **Audio-Wiedergabe** an JavaScript. Die sieben gemeinsamen
  Audio-/Video-Reflexionen und bereits montierte Videoattribute besitzen einen
  [separaten begrenzten Nachweis](HTML-PARSER-ATTRIBUTES-20261006.md#gemeinsame-medienattribute-und-montierte-videos--11-oktober-2026).
  Die komplette Video-JavaScript-Oberfläche, `textTracks/addTextTrack`, die
  vollständigen Fullscreen-/Picture-in-Picture-APIs und die gesamte
  `HTMLMediaElement`-Familie bleiben offen.
- Wiedergaberaten sind auf `0.5` bis `2` beschränkt. Andere endliche Raten
  ergeben `NotSupportedError`; `volume` außerhalb `0` bis `1` ergibt
  `IndexSizeError`. Nicht endliche Zahlen ergeben `TypeError`.
- `canPlayType()` gibt `""` zurück, weil Assetzuordnungen keine Browsercodec-
  Fähigkeit nachweisen. `crossOrigin` wird reflektiert, führt aber keine
  Browser-CORS-/Credentials-Anfrage aus. Browser-Autoplay-Sperren sind kein
  identischer Roblox-Hostmechanismus.
- `metadata` und `auto` bereiten dasselbe vollständige Roblox-Asset vor.
  `buffered/seekable` bilden danach die gesamte Dauer ab; sie sind keine echten
  Streaming- oder Netzstatistiken. Der unten belegte SOURCE-Fallback gilt für
  Fehler vor Metadaten; spätere Decoder-/Netzfehler und ihre vollständigen
  Ereignisfolgen bleiben eigene Anforderungen.
- Die geordnete SOURCE-Wahl ist für JavaScriptverwaltetes Audio einschließlich
  Medienbedingungen, Retry-Zeiger und aufgeschobener Vorbereitung geprüft.
  Die unten separat geprüfte Audioauswahl ohne Realm ist inzwischen ergänzt;
  Video, vollständige Codecsemantik und alle Auswahlunterfälle sind weiterhin
  nicht abgeschlossen. Auch der gesamte Medien-Task-Discard beim
  Load-Reset bleibt separat vom gezielten Play-Promise-Nachweis offen.
- Die frühere Entfernungskontrolle allein belegt keinen gemeinsamen
  Wiedergaberecord oder Backendtransport zwischen zwei Realms. Der unten
  beschriebene produktiv übernommene Audiozustand adressiert die getrennten
  lokalen Tabellen für den belegten Zwei-Realm-Teilumfang. Die vollständige
  Realm-/Iframe-/Video-Ownership bleibt weiterhin eine offene Anforderung.
- Die eingefrorene Quellenauswahl verweist auf das Knotendokument beim letzten
  `src`-Wechsel. Ihr Quellenkommentar beschreibt darüber hinaus eine damals
  festgehaltene Basisadresse; der Algorithmus formuliert den Zeitpunkt der
  Basisauflösung nicht ebenso eindeutig. Chromium 154 nutzt in den aufgenommenen
  gleichzeitigen `src`-/Basiswechseln die spätere Basis. Historischer
  Dokumentbesitzer, Basiszeitpunkt und heutiger reflektierter URL-Getter sind
  getrennte Achsen. Die Rohkontrolle unter
  `build/audio-selection-url-review/native.json` bleibt erhalten; der aktuelle
  Getter und die heutigen Ladevorgänge schließen diese Auswahlachsen nicht.
- Web Audio (`AudioContext`, Oszillatoren, Filter, Mixer), MediaSource, DRM,
  Aufnahme und Streaming sind separate Ausbaugebiete.

## Prüfung und Referenzen

`tests/JavaScriptAudio.luau` prüft die gemeinsame VM, DOM-Identität, Web-IDL-
Fehler, Aufgaben-/Microtask-Reihenfolge, Pause/Play-Rennen, Quellenwechsel,
Ladebarriere, Preload, Zeitbereiche und Abbau. `tests/AudioHost.luau` verbindet
den tatsächlichen AudioHost mit MediaRuntime sowie HTMLScripts/RenderTree und
prüft Sound-Wiederverwendung, native Controls, Seek, Ende, Fehler und dynamische
Darstellung mit kontrollierten nativen Diensten. Das ist kein hörbarer
Studio-Test oder FPS-Benchmark.

`tests/fixtures/audio-browser-reference.html` erzeugt eine stumme PCM-Datei und
prüft Standardverhalten im echten Browser. Das Ergebnis ist unter
`tests/fixtures/audio-browser-reference.json` festgehalten: Standardwerte,
unsichtbares Audio, Volume-Fehler, früher Pause-Abbruch, Ereignis-/Promise-
Reihenfolge, Seek/Fortsetzen, Ende, Mute und leeres `src` wurden verglichen.
Die vollständigen Engine-Regressionen, Projektprüfung und Rojo-Build sind in
`build/audio-full-tests.log`, `build/audio-final-focused.log`,
`build/audio-project-audit.log` und `build/audio-rojo-build.log` dokumentiert.

Standardgrundlage: [WHATWG-Medien](https://html.spec.whatwg.org/multipage/media.html)
und [WHATWG-Rendering](https://html.spec.whatwg.org/multipage/rendering.html).
Die native Wiedergabe verwendet die kursorerhaltende `Sound.Playing`-
Eigenschaft; siehe [Roblox Sound](https://create.roblox.com/docs/reference/engine/classes/Sound).

### Quellenwahl, Startposition und Entfernung — 11. Oktober 2026

[AudioSourceLifecycle](../tests/AudioSourceLifecycle.luau) trennt den
ausdrücklichen Load-Reset von der Auswahl und Vorbereitung einer Ressource.
Der [Browsercapture](../scripts/capture-audio-source-lifecycle-reference.cjs)
und die [erhaltene Rohreferenz](../tests/fixtures/audio-source-lifecycle-browser.json)
umfassen 34 Fälle, 106 Übergänge und 237 Snapshots: die ursprünglichen
16 Lebenszyklusfälle/74 Übergänge, zwei HTTP-Hintfälle/zehn Übergänge,
fünf Auswahlfälle/zehn Übergänge, vier Promisefälle/vier Übergänge und sieben
Frühpositionsfälle/acht Übergänge. Die ursprünglichen Lebenszyklus- und
HTTP-Daten sind inhaltlich exakt erhalten. Die HTML-Grundlage ist auf Commit
`ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c` vom 6. Oktober mit SHA256
`49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f` festgelegt.

Die echte VM prüft gehaltene Soundidentität, Auswahlgeneration, Controls,
Position/Rate, leere und ungültige URLs, wartende Plays, vier beobachtete
Promisefolgen und verspätete Metadaten. Entfernung wird nach dem vollständigen
Microtask-Checkpoint mit dem aktuellen Besitzer erneut geprüft; synchrone,
Promise- und verschachtelte Microtask-Wiedereinfügungen erhalten die Wiedergabe.
Die Auswahl selbst benutzt weiter den vorhandenen Auswahl-Microtask. Der
unabhängige finale Lauf besteht mit neun offiziellen Suiten einschließlich
isolierter Realm-Lifetime-Prüfung, tatsächlichem Exit 0 und unveränderten
sieben Ownerdateien sowie der gesonderten JavaScriptAudio-Korrektur
(`build/audio-source-lifecycle-independent-final.log`). Das Inventar und die
Hashes stehen in `build/audio-source-lifetime-prep/final-audit.json`.

PCM-Wiedergabe im Browser und kontrollierte Engine-Sounddienste sind getrennte
Nachweise. Ein unmittelbarer `NETWORK_LOADING`-Zwischenwert bei gleichzeitiger
SOURCE-Einfügung bleibt als Rohwert erhalten, liegt aber außerhalb des
engen Zustandsvergleichs. Der folgende Nachtrag ergänzt SOURCE-Fallbacks;
vollständige Medien-Tasks, Basiszeitpunkt, gemeinsame Realm-Wiedergabe und
Studio-/Decodergrenzen bleiben offen. Dieser Nachweis schließt nur die genannten
Audio-Attributkombinationen.

### Geordnete SOURCE-Kandidaten — 12. Oktober 2026

JavaScriptverwaltetes Audio wählt `source`-Kinder in DOM-Reihenfolge. Der
Retry-Zeiger folgt tatsächlichen Einfügungen und Entfernungen, ohne einen
Load-Reset oder ein neues `loadstart` zu erfinden. Ein offenes Play-Promise
kann bei erschöpfter Auswahl auf später eingefügte Kandidaten warten. Änderungen
an bereits ausgewählten Kindern ersetzen weiterhin nicht ihre Ressource.

Medienbedingungen verwenden den vorhandenen CSS-Mediaqueryparser mit der
aktuellen ResourceViewportgröße. Dafür entstehen keine dauerhaften MQLs,
Autoraufrufe von `matchMedia` oder Idle-Scans. Ungültige Typen können unbekannt
bleiben; ein gültiger Typ wird nur bei ausdrücklich negativer Hostfähigkeit
übersprungen. Roblox-Assetzuordnungen sind kein Codecnachweis.

Ein Fehler vor Metadaten plant einen `error`-Task am ausgewählten `source`
und davon getrennt die unmittelbare Fortsetzung im stabilen Zustand.
Auswahlepoche und Versuchsgeneration haben unterschiedliche Aufgaben:
bereits geplante SOURCE-Fehler überleben gewöhnliches Weiterwählen und
Kindentfernung, werden aber durch ausdrückliches Laden, `src`-Setzen oder
Entsorgung gesperrt. Direkte Quellen und Fehler nach Metadaten verwenden
Medienfehler ohne Kandidatenfallback.

`preload="none"` wählt ohne native Vorbereitung. Sichtbare Controls können
Play auch dann starten, wenn der erste Kandidat keine Zuordnung besitzt.
Echte `page:PlayMedia`-, Tab/Space- und Pointerpfade durch Controller und
MediaRuntime sind geprüft: ein fehlender erster Kandidat liefert seinen
SOURCE-Fehler, danach lädt genau die nächste Ressource. Sound, GUI, Fokus,
Editor und UTF16-Auswahl bleiben erhalten.

[AudioSourceCandidates](../tests/AudioSourceCandidates.luau),
[Capture](../scripts/capture-audio-source-candidates-reference.cjs) und
[Rohfixture](../tests/fixtures/audio-source-candidates-browser.json) enthalten
36 SOURCE-Fälle mit 13 zusätzlichen Schritten/98 Snapshots, fünf URL-Fälle mit 14 Snapshots
und acht zusätzliche Reihenfolgefälle mit 19 Zuständen/30 Handlersnapshots.
15 normative Vergleichsdatensätze und die acht Reihenfolgeprojektionen sind
getrennt gespeichert; letztere enthalten sechs HTTP404-Standarddifferenzen
und zwei native Übereinstimmungen bei der Quellenqualifikation. Frühere Rohdaten bleiben inhaltlich exakt
erhalten. Die HTML-Revision und SHA256 sind dieselben wie im vorigen Nachtrag.

[AudioSourceCandidatesRendering](../tests/AudioSourceCandidatesRendering.luau)
prüft acht montierte Modi mit 252 Assertions einschließlich tatsächlicher
Eingabewege. Der unabhängige gemeinsame 14-Suiten-Lauf besteht mit tatsächlichem
Exit 0 einschließlich beider isolierter Lebensdauerprüfungen
(`build/media-candidates-independent-combined14.log`). Alle 33 geschützten
Quellen-/Referenzhashes und beide Medienmanifeste bleiben unverändert.
Die ursprünglichen Audio-Lebenszyklus-/Medienreflexionsdaten bleiben erhalten.

Diese Abnahme gilt für die genannten Audio-Kandidatenpfade. Historischer
Knotendokument-/Basiszeitpunkt, Audio ohne JavaScript, Videoauswahl,
Cross-Realm-Wiedergabebesitzer, vollständige Codec-/Tasksemantik und native
Studio-/Decoderparität sind getrennt offen.

### VM-freier Auswahlkern und Audio-Reentranz — 12. Oktober 2026

[MediaSelection](../src/HTMLEngine/HTML/MediaSelection.luau) übernimmt die
gemeinsame Quellenreihenfolge, Auswahlepoche, Versuchsgeneration, None-Deferral,
Medienbedingungen und den lebenden Geschwisterzeiger. Resolver, Hostfähigkeit,
Fetch, Ereignisse und Scheduler werden injiziert. Der Kern erzeugt weder eine
VM noch native Objekte oder Idle-Scans. [AudioElements](../src/HTMLEngine/JavaScript/AudioElements.luau)
benutzt ihn für die bereits belegte verwaltete Audioauswahl; Playback,
Play-Promises, Reset und native Besitzer bleiben dort beziehungsweise beim
[AudioHost](../src/HTMLEngine/Rendering/AudioHost.luau).

Ausstehende Tasks besitzen kleine, beim Abbau geleerte Slots. Der behaltene
Kern und externe Queues halten nach Destroy nicht weiter Kontext, Medienzustand,
Knoten oder Kandidaten fest. [MediaSelection](../tests/MediaSelection.luau)
prüft 18 injizierte Reentranzkontrollen und 49 Assertions einschließlich
Reihenfolge/Epochen, None vor Verfügbarkeit, Medien-Snapshot, kooperativer
Zeigeränderung und unabhängiger Weak-Kontrollen. Der
[kompakte Runner](../scripts/run-media-selection-tests.cjs) läuft verpflichtend
im Gesamtlauf und bei Anforderung dieser Suite, getrennt vom Rendererheap.

[MediaSelectionAudioOpen](../tests/MediaSelectionAudioOpen.luau) prüft drei
tatsächliche Runtime-/DOM-Pfade: veraltetes Open-Ergebnis, nil-Ergebnis und
Destroy vor spätem Ergebnis. Ein Handle wird erst nach Prüfung von Alive,
Epoche, Generation und dem inzwischen installierten Handle übernommen.
Ein veraltetes lebendes Ergebnis mit vorhandener per-Handle-`Destroy`-Methode
wird einmal freigegeben. Ohne diese optionale Methode bleibt sein Abbau Aufgabe
des Adapters; der Vertrag fordert keine neue Pflichtmethode. Nur die neueste
Auswahl darf native IO starten. Der unabhängige 17-Suiten-Lauf einschließlich der
kompakten Ressourcen-/Kernprüfungen und frischen isolierten GC-Tails ist Exit 0
(`build/core-poster-independent-seventeen.log`). Der anschließende vierzehnte
Gesamtlauf besteht mit tatsächlichem Exit 0 und 366 registrierten Suiten
einschließlich 13 isolierter GC-Prüfpfade. Die nachträglichen Quellen-/Projekt-/
Holdprüfungen bestätigen denselben Stand (`build/html-full14-acceptance.json`).

Diese Extraktion allein ist kein nativer No-Realm-Audio-/Video-Adapter.
Die folgende Audioanbindung und die unten belegte AudioHost-Freigabe liegen
inzwischen produktiv vor; die Videoanbindung bleibt getrennt offen.
Historische Ressourcenbasis, vollständige Typ-/Codecsemantik, payloadfreie
alte Hostsignale und Studio-Pixel werden dadurch ebenfalls nicht geschlossen.

### Audioauswahl ohne JavaScript-Realm — 12. Oktober 2026

[NativeMediaResources](../src/HTMLEngine/Rendering/NativeMediaResources.luau)
benutzt denselben Auswahlkern für Seiten ohne Autorenscript und bei deaktiviertem
JavaScript. Er besitzt auch versteckte Audios und Audios ohne `controls`, benötigt
keine VM und startet die Auswahl erst nach erfolgreichem Controlleraufbau.
Die Quellen werden in ihrer Reihenfolge geprüft; ein bekanntes Asset wird nicht
an einer davorliegenden, noch ungeprüften Quelle vorbei ausgewählt.
`preload="none"` behält die ausgewählte Anfrage ohne IO. Ein späteres Play oder
Preload-Upgrade setzt genau diese Auswahl fort. Neue Steuerelemente übernehmen
den bereits vorhandenen Sound, die erreichte Metadatenstufe und den Ladezustand.

Die stabilen Fortsetzungen und Medientasks verwenden kleine löschbare Slots
in FIFO-Queues mit konstantem Aufwand pro Entnahme. Laufende Ladearbeit benutzt
den vorhandenen `WorkContext` und prüft nach einer Pause erneut den Besitzer.
Ein unerwarteter injizierter Hostfehler gibt nur die eigenen Audioregistrierungen,
Gesten und Sounds frei; Formulare, die Seite und Videos bleiben erhalten.
Der ursprüngliche nil-, false- oder Tabellenfehler bleibt erhalten. Ein späteres
Hinzufügen von Controls kann den beendeten Audiobesitzer nicht neu starten.

[NativeAudioSelection](../tests/NativeAudioSelection.luau) prüft 37 montierte
Kontrollen, 4.481 Assertions und 16 Resolverfälle, einschließlich später Controls,
lebender Geschwisterposition, None-Fallback, Tastatur/Pointer sowie Besitzer- und
Seitenabbau während echter kooperativer Auswahlpausen. Der unabhängigen Codeprüfung
folgte der Produktionslauf mit 18 betroffenen Suiten, tatsächlichem Exit 0,
kompakten Ressourcen-/Kernprüfungen und einem frischen montierten Lifetime-Tail:
`build/native-audio-production-focused-second.log`. Die ursprünglichen
Video-/SOURCE-Referenzen und Tests wurden erhalten. Dies ist noch kein neuer
Gesamtlauf oder hörbarer Roblox-/Pixel-/FPS-Abgleich.

Der Resolver verwendet den strikten gemeinsamen URLparser; ungültige absolute
Adressen erhalten keinen Rohwert-Fallback. Pfade ohne Schema behalten das
bestehende lokale Websitekatalog-Profil. Der Quellenzustand bleibt von der
unten ergänzten, weiterhin begrenzten historischen Dokumentbasis getrennt. Datenoperationen
über nackte `DOM.Node`-Knoten benötigen weiterhin die expliziten Vorher-/Mutations-
Benachrichtigungen; rohe Lua-Attributwrites werden nicht automatisch beobachtet.
Der Pending-Zähler ist keine vollständige Dokumentladebarriere. Vollständige
Medientasks, Codecsemantik, Video-Quellenadapter, payloadfreie alte native Signale
und Arbeit nach der ersten Präsentation bleiben getrennte Restfälle. Die folgende
Host-Freigabe hat einen eigenen engen Nachweis; allgemeine Seiten-/Realm-GC ist
hier nicht behauptet.

### AudioHost-Freigabe und neue Ladeversuche — 12. Oktober 2026

[AudioHost](../src/HTMLEngine/Rendering/AudioHost.luau) trennt beim Abbau seine
Seiten-, Baum-, Callback- und Sessionbezüge, auch wenn ein natives
`PreloadAsync` noch wartet. Der Worker hält während dieser Pause nur den Sound
und einen löschbaren Ladeslot. Queues und behaltene Adapter besitzen danach
keine dieser Host-eigenen Besitzerbezüge mehr. Der bereits vorhandene Sound
wird einmal freigegeben; ein späteres natives Ergebnis veröffentlicht nichts.
Die native Operation selbst wird dadurch nicht physisch abgebrochen.

Jeder `Select`, `Reset` und `Load` erhält zusätzlich zur öffentlichen Generation
eine private Versuchsidentität. Ein Resolver oder natives Stop, das synchron
einen neueren Versuch startet, kann anschließend nicht vom älteren überschrieben
werden, auch bei derselben Generation. Ein reentrant installierter neuer Sound
bleibt erhalten; ein veraltetes frisches Factory-Ergebnis wird separat entsorgt.
Öffentliche Signaturen, Cachewiederverwendung, Cursor, Lautstärke, Loop,
Attach/Detach und das bestehende Heartbeatintervall bleiben erhalten.

[AudioHostLifetime](../tests/AudioHostLifetime.luau) führt im Hauptlauf mit
tatsächlichem `MediaBox` 23 Verhaltenskontrollen/220 Assertions aus. Der
[kompakte Runner](../scripts/run-audio-host-lifetime-tests.cjs) läuft zusätzlich
verpflichtend bei Gesamtlauf und Einzelanforderung: 27 Kontrollen/282 Assertions
mit ausdrücklich kontrollierter `MediaBox.paint`-Grenze. Drei Besitzfälle müssen
ihre Weak-Owner vor Native-Resume freigeben; gleich alte unabhängige Plain- und
zyklische Kontrollen müssen beim unveränderten Budget von 128 × 2.048 ebenfalls
sammeln. Acht neue Resolver-/Stop-Reentryfälle ergänzen die bisherigen 19 Fälle.
Die roten Vorherbelege und der unabhängige Review bleiben erhalten.

Der anschließende Produktionslauf mit 19 betroffenen Suiten besteht mit
tatsächlichem Exit 0, einschließlich beider AudioHost-Inventare, kompakter
Ressourcen-/Kernprüfungen und des frischen montierten Ressourcen-Lifetime-Tails:
`build/audio-host-production-focused-first.log`. Dies ist noch kein neuer
Gesamtlauf. Die montierte gesamte JavaScript-Seite sammelte im unveränderten
Diagnosebudget auch ohne Audio nicht vollständig; dabei blieb eine gleich alte
unabhängige Plain-Kontrolle ebenfalls erhalten. Diese Achse bleibt ungeprüft
und wird weder als Host-Retainer noch als vollständiger Page-/Realm-/WorkContext-
oder GPU-GC-Nachweis ausgegeben. Externe Servicecallbacks, historische
Quellenbasis, Videoauswahl und payloadfreie alte Signale bleiben eigene Grenzen.

### Historische Dokumentwahl bei Audio — 12. Oktober 2026

Der [Dokumentnachtrag](HTML-PARSER-ATTRIBUTES-20261006.md#historisches-quellendokument--12-oktober-2026)
ergänzt denselben historischen SOURCE-/Audio-Datenkontext für die verwaltete und
Realm-freie Ressourcenwahl. Getter bleiben beim aktuellen Besitzer; Auswahl
benutzt den Dokumentbesitzer des letzten erfolgreichen `src`-Writes und seine
aktuelle kanonische Basis. Writes gleicher Werte, Fehlerkonversionen, Namespaces,
Parser, Fragment, Clone/Import und Templateowner sind getrennt geprüft.
20 tatsächliche JS-Fälle/67 Kontrollen und neun additive native Montagefälle
bestehen. Der produktive Lauf mit 24 betroffenen Suiten einschließlich der
kompakten Daten-/Host-/Ressourcen-/Kernprüfungen und isolierter Tails hat
tatsächlichen Exit 0 (`build/historical-production-focused-first.log`).
Beide bisherigen MediaReflection-Ressourcenannahmen haben ausdrücklich benannte
Frozen-Gegenstücke; rohe Referenzen und die ursprüngliche ganze Testdatei sind
erhalten. Nach zerstörtem/gesammeltem Ursprung ist nur ein Datenfallback belegt;
die gesamte historische Anforderung und gemeinsame Cross-Realm-Wiedergabe
bleiben deshalb offen. Die neue Historie erzeugt keinen Playbackservice oder
zusätzlichen Idle-Scan und ersetzt keine dieser offenen Besitzanforderungen.

### Audio-Besitz zwischen zwei lebenden Realms — 12. Oktober 2026

Der produktiv übernommene Audiozustand trennt einen kanonischen Zustand je
Knoten von den Diensten seines ursprünglichen und seines aktuellen Realms.
Der unabhängige v2-Quellenreview besteht ohne Blocker. Fünf geprüfte Quellen,
acht Modi desselben Testkörpers und genau zwei präzise Testkorrekturen sind
bytegleich übernommen. Der anschließende produktive 22-Suiten-Lauf besteht
mit tatsächlichem Exit 0; die folgenden Aussagen gelten nur für diesen Umfang.

Bei Adoption von A nach B behält derselbe Controller den Zustand und dieselbe
Sound-Instanz behalten. Aktueller Backend-, Provider-, Resolver- und
Darstellungsbesitzer ist B. Der VM-freie Auswahlpool benutzt zustandsbezogene
Owner-Dienste statt eigener VM-/Seitenclosures je Knoten oder eines globalen
Caches. Normale Quellenversuche behalten ihre Auswahlepoche und ihre eigene
Generation; ein ausdrücklich neuer Load ersetzt sie. Playback, Cursor, Rate
und Play-Promises bleiben außerhalb des reinen Quellenwahlkerns.

Vier Realmachsen sind getrennt: Medien-/SOURCE-/Settlementtasks gehören zum
ursprünglichen Platform-Global A; stabile Auswahl und native Fortschrittsmeldungen
laufen beim heutigen Besitzer B. Brand-/Konvertierungsfehler benutzen das
aufgerufene A-/B-Binding. Gültige Play-Promises und die lebenden Error-/TimeRanges-
Factories bleiben beim ursprünglichen A. Error ist im kanonischen Zustand
nur versionierte Daten; derselbe aktive Fehler wird als dasselbe ErrorA
materialisiert. Jeder Bereichsgetter erzeugt einen neuen SnapshotA ohne Rücklink
zum Controller. Der ergänzte Browsernachweis hat leere Bereiche und beweist
keine nichtleeren sich ändernden nativen Bereichsinhalte.

Die gewählte Chromium-UA-Politik lädt erfolgreiches, pausiertes oder früh
wartendes Audio bei Adoption neu auf demselben Zustand: tatsächlicher Cursor
und Rate werden zurückgesetzt, Lautstärke/Mute und frühe Startposition bleiben
erhalten, alte offene Plays werden abgebrochen und die vorherige Pauseabsicht
wird berücksichtigt. Ein vorhandener Code-4-Fehler wird dagegen mit seiner
Identität übernommen, ohne erneute Engine-Auswahl oder Backendanforderung.
Der Frozen-HTML-Text liefert für den Reload bei Adoption keinen hier belegten
Trigger. Ein eindeutiger Zustand bedeutet deshalb nicht Cursorerhalt oder
vollständige normative Adoptionsparität.

Die zusätzlichen Chromium-Aufnahmen zeigen nach Adoption aktuelle EventB-
Objekte bei B.load, gewöhnlichem A-Prototyp-load und geborgtem A.load. Frozen
DOM erzeugt Ereignisse im relevanten Realm des Targets, hier PlatformA;
EventB ist eine getrennte gewählte UA-Materialisierungsabweichung und kein
Beleg für TaskqueueB. Auch die Flags bleiben getrennt: native Rohdaten haben
bubbles=false/cancelable=true, bestehende Engine-/Frozen-Kontrollen bleiben
streng false/false. ErrorA und neue TimeRangesA ändern diese Eventachse nicht.

Explizites Runtime.Destroy ist Engine-Teardown, kein Äquivalent zum Entfernen
oder zur Inaktivität eines Browser-Iframes. Der belegte A-Abbau löst
Factories, Caches, Tokens und originäre Taskslots, nimmt aber keinen bereits
von B besessenen Sound mit. Native Controls in B können weiterhin pausieren/spielen;
ein neues Autor-Play ohne A-Factory hat den benannten InvalidStateError-
Hostzustand. Der Abbau des aktuellen B-Besitzers ist terminal. Fehlender
TakeSession-Transfer endet im selben UnsupportedMedia-/Code-4-Controller,
ohne zweites Open, B-IO oder Wiederbelebung; die DOM-Adoption bleibt erfolgt.
Reentry und geworfene nil-/false-/Tabellenwerte müssen lokale Slots vollständig
lösen und den ersten ursprünglichen Fehler erhalten.

Der [Testkörper AudioCrossRealmCandidate](../tests/AudioCrossRealmCandidate.luau)
enthält ein festes Inventar:

| Kontrollmodus | Fälle | Assertions |
| --- | ---: | ---: |
| Gemeinsamer Zustand, Adoption und beide Abbaureihenfolgen | 13 | 72 |
| Besitzer-Loadcallback mit Stop, neuer Auswahl oder Throw | 5 | 27 |
| Native Snapshot-Paint-Reentry | 1 | 5 |
| Transfer-/Destroy-Lookup und ursprünglicher Fehlerwert | 9 | 39 |
| Bind-/Metadaten-/Pause-/Seek-/Settlement-Hooks | 8 | 33 |
| Verschachtelte oder beim Aufbau zerstörte Promise-Factory | 2 | 8 |
| Capabilityresolver bei neuer Quelle oder Besitzerwechsel | 2 | 8 |
| Settlement-Scheduler: Besitzerstop, Decline oder ursprünglicher Throw | 4 | 28 |

Die ursprünglichen 40 benannten Kontrollen/192 Assertions bleiben bytegleich
erhalten; vier zusätzliche Schedulerkontrollen/28 Assertions ergeben 44/220
in acht Modi desselben Testkörpers. Der unabhängige v2-Lauf und der produktive
Lauf mit jeweils 22 Suiten enden mit tatsächlichem Exit 0.
Es sind zwei tatsächliche Runtime-/DOM-Realms und der tatsächliche AudioHost
mit kontrollierten Sound-/Providerdiensten, keine zwei montierten HTMLPages
oder native Decoder-/Clock-/Studioabnahme. Die roten Vorherbelege und alle
Originaldaten bleiben erhalten. Der separate unabhängige kompakte Lauf liest tatsächlich CandidateHost
(27/282) und CandidateCore (18/49) je einmal physisch mit den unveränderten
Tests und endet jeweils mit tatsächlichem Exit 0. Beide Module sind im v2-
Derivat bytegleich, daher bleibt dieser enge Nachweis gültig. Der unabhängige
v1-Gesamtreview bleibt wegen des unten genannten Fehlers historisch BLOCKED.
Im damaligen BUILD-Hauptlauf lasen die gewöhnlichen kompakten Tails noch
alte Produktion; der getrennte physische Candidate-Nachweis wird deshalb
nicht als derselbe Lauf gezählt. Nach der exakten Übernahme liest der neue
Produktionslauf die geprüften Host-/Corebytes: Haupt-Lifetimepfad 23/220,
verpflichtende kompakte Tails 27/282 und 18/49 jeweils Exit 0.
Das ist kein vollständiger CanonicalState-/Origin-VM-/Page-GC-Nachweis.

Zwei frühere Testannahmen sind durch präzise benannte Gegenstücke korrigiert. In
JavaScriptAudio wird ausschließlich der synchrone Brand-TypeError bei
HTMLMediaElement.prototype.play.call({}) durch die asynchrone TypeError-
Promiseablehnung ersetzt, einschließlich genau dieses Erwartungsslots.
MediaReflection trennt streng den aktuellen Backendrequest A0/B1 von der
historischen Ressourcenadresse A; heutiger Getter B und alle 17 Fälle/488
Rohzeilen bleiben erhalten. Beide vollständigen Originaldateien, ihre SHA256
und die literalen Diffs sind archiviert. Beide kanonischen Tests sind exakt
aus diesen geprüften Gegenstücken übernommen; es gibt keine OR-/Skip-Erwartung
und keinen unverändert-grün behaupteten alten Test.

Die ursprünglichen v1-Artefakte liegen in build/media-cross-realm-audio-candidate-prep:
final-build-hold.json, final-profile-addendum.json, counterpart-literal-deltas.json
und composed-final-after-two-hooks.log. Acht ursprüngliche Browserfälle mit
64 Zuständen/29 Promisezeilen/16 Requests, fünf Brandfälle und die getrennten
Return-/Event-Ergänzungen liegen unverändert in build/media-cross-realm-native-prep.
Die alte fünf-Fall-/21-Kontrollen-/16-Fehler-Baseline bleibt als widerlegte
Playback-Erhaltshypothese erhalten. Frozen HTML ba3400bb/49641ded, DOM
b76da7af/a7e26185 und WebIDL 8c653291/473fc33b bleiben getrennt gepinnt.

VIDEO-Besitz, native-noRealm/Realm-Übergänge, generische Agent-/EventLoop-/DOM-
Operationen nach zerstörtem Besitzer, Reaktivierung inaktiver Iframes,
nichtleere native Range-Snapshots, historische Basiszeichenfolge und
zerstörter Ursprung sowie ganze Page-/Realm-/GPU-Sammlung bleiben offen.
Der bestehende Registerpunkt media-source-cross-realm-ownership bleibt
offen mit diesem produktiv belegten Teilnachweis. Die 277 Attributgruppen,
zehn partiellen Zuordnungen und 50 Anforderungen mit 29 erfüllt/sechs offen/
15 ungeprüft bleiben unverändert.

#### Additiver Settlement-Scheduler-Fix — produktive v2-Abnahme

Der unabhängige Review reproduziert auf den unveränderten v1-HOLD-Bytes vier
falsche Ergebnisse: QueueTask stoppt Besitzer B, lehnt dabei das ausstehende
Play-Promise genau einmal mit AbortError ab und liefert anschließend false
oder wirft den ursprünglichen nil-/false-/Tabellenwert. Der alte Cleanup ruft
danach Drop(nil) auf und überschreibt jedes ursprüngliche Ergebnis durch einen
Iterationsfehler. Die erfolgreiche Registry-/Soundfreigabe des v1-Pfads macht
diesen Fehler nicht akzeptabel; der erste Review bleibt als BLOCKED erhalten.

Das separate v2-Derivat verändert allein den bereits abgewickelten Waiting-
Guard in AudioState.queueSettlement. Nur tatsächlich verbleibende Tokens
werden gedroppt. Vier literale Fälle prüfen ursprüngliches Ergebnis/Fehlerwert,
AbortError genau einmal, Drop0, leere Capabilities/Play-/Settlement-/Taskslots,
SoundDestroy1 und keine späte Publikation nach Resume. Eigene Rotprobe aller
vier Fälle Exit1, grüner acht-Modi-Lauf und komponierter 22-Suiten-Lauf Exit0
sind erhalten. Die ursprünglichen 40 Kontrollen/192 Assertions, alle anderen
vier Quellmodule und beide präzisen Testgegenstücke bleiben bytegleich.

Die beiden Source-HOLDs, alte Dokumententwürfe und Rohreferenzen sind
unverändert. Neues Manifest: build/media-cross-realm-audio-candidate-v2-prep/final-build-hold.json;
rote/grüne Protokolle: settlement-scheduler-red.log, settlement-scheduler-green.log
und composed-final.log in demselben Verzeichnis. Die tatsächlichen kompakten
Candidate-Prüfungen liegen unter build/media-cross-realm-audio-candidate-prep/
independent-compact-host.json beziehungsweise independent-compact-core.json.
Der unveränderte unabhängige Vier-Fall-Rotkörper ist gegen v2 frisch grün:
false-Decline bleibt erfolgreich; geworfene nil-/false-/Tabellenwerte bleiben
identisch. Der unabhängige Abschlussbericht ist
`build/media-cross-realm-audio-candidate-v2-prep/independent-final-review.json`
(SHA256 e1776118…8464b7). Die Produktionskopien und die genau eine nachgetragene
AudioState-Bundlerregistrierung sind zusätzlich statisch geprüft
(`independent-production-copy-review.json`, SHA256 7e85d5c5…625d9f).
Der erste Produktionsversuch scheiterte vor den Suiten an dieser fehlenden
Registry-ID; seine Rotprobe und der frühere Runner bleiben erhalten.
Der korrigierte produktive 22-Suiten-Lauf ist tatsächlicher Exit 0:
`build/audio-production-focused-second-full16.log`. Der versiegelte Stand
liegt in `build/media-cross-realm-audio-candidate-v2-prep/production-source-hold.json`
(SHA256 cda0aa97…a2fae8e): zehn produktive Dateien, 162 gehaltene Artefakte und
1.674 unveränderte Full15-Altdateien. Dies ist ein gezielter Produktionsnachweis,
kein neuer Gesamtlauf. UA-/Frozen-/Destroy-/Codec-/Video-/GC-Grenzen und
Registerstatus ändern sich nicht.


