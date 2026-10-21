# HTML Abdeckung und verbleibender Abgleich

Stand: 6. Oktober 2026. Der vollständige HTML-Umfang ist noch nicht einzeln
belegt. Die [frühere Abschlussliste](history/2026-10-06/HTML-COMPLETION-original.md)
bleibt vollständig erhalten, beschreibt aber ein früheres Roblox-Profil.
Die dortige Katalogzählung und das Fehlen von `partial`-Einträgen sind kein
Nachweis aller Attribute, Fehlerfälle oder Browserdarstellungen.

## Wo der vorhandene Umfang steht

| Gesucht | Quelle |
| --- | --- |
| Registrierte Tags und Defaults | [Elements.luau](../src/HTMLEngine/HTML/Elements.luau) |
| Parsing und Dokumentstruktur | [Parser.luau](../src/HTMLEngine/HTML/Parser.luau), [HTML-SUPPORT](HTML-SUPPORT.md) |
| Attributzugriff und DOM-Reflexion | [DOMAttributes](../src/HTMLEngine/JavaScript/DOMAttributes.luau), [DOMReflection](../src/HTMLEngine/JavaScript/DOMReflection.luau) |
| Parser- und Attributnachweise | [Profil vom 6. Oktober](HTML-PARSER-ATTRIBUTES-20261006.md), [Attributregister](html-attributes.v1.json) |
| Formular- und Eingabetypen | [Controls/Defaults](../src/HTMLEngine/Controls/Defaults.luau), [FORMS](FORMS.md), [R04-Eingaben](JAVASCRIPT-INPUT-R04.md) |
| Dynamisches DOM, Tabellen, Shadow DOM und Custom Elements | [JavaScript-Bestand](JAVASCRIPT-IMPLEMENTATION.md), [Dokumentprofil](JAVASCRIPT-DOCUMENTS-R02.md), [Komponentenprofil](JAVASCRIPT-COMPONENTS.md) |
| Kopf, Bilder, Medien und eingebettete Dokumente | [DOCUMENT-METADATA](DOCUMENT-METADATA.md), [IMAGES](IMAGES.md), [MEDIA](MEDIA.md), [IFRAMES](IFRAMES.md) |

## Widersprüche und echte Lücken

Die alte Einordnung von `script` als ausschließlich `parser-only` und frühe
fehlende DOM-/Custom-Element-/Shadow-APIs widersprechen neueren Implementierungen.
Für diese Familien gelten die neueren JavaScript-Fachprofile mit ihren Grenzen.
Die historischen offenen Punkte müssen einzeln abgeglichen werden; sie werden
hier weder pauschal als offen noch pauschal als erledigt übernommen.

Die Etappe [Eingabetypen vom 6. Oktober](HTML-INPUT-TYPES-20261006.md) ergänzt
`date`, `datetime-local`, `month`, `time` und `week` mit Auswahlfenstern und
gemeinsamer Wertsemantik sowie `image` als Bild-Submitter. `file` besitzt zunächst
nur die Darstellung; seine Dateiauswahl ist ausdrücklich auf später verschoben.
Die [archivierte Browserreferenz für diese sieben Typen](../tests/fixtures/retired-window-pages-20261016.json)
bleibt seit dem 16. Oktober als Regressionseingabe einschließlich ihrer
generierten `InputTypes`-Module erhalten. Sie zeigt native Auswahl, Werte,
Validierung, Schritte, Reset und Bildbutton-Klickdaten; eine aktive Web-/Katalogseite
ist sie nicht mehr. Genaue Grenzen und
Belege stehen im datierten Profil.
Eine entsprechende DOM-Eigenschaft allein belegt keine native Picker- oder
Aktivierungssemantik. Der [neue Tree-Builder und Attributabgleich](HTML-PARSER-ATTRIBUTES-20261006.md)
prüft 1.508 Dokument- und 59 Fragmentbäume sowie erste echte Attributwirkungen.
Das Register enthält nun 277 Standardgruppen mit getrennten Nachweisachsen;
leere Achsen sind weiter ungeprüft. Vollständige Parser-/Attributkonformität
und native Pixelgleichheit sind damit nicht pauschal nachgewiesen.

Der [H03-Nachtrag vom 9. Oktober](HTML-PARSER-ATTRIBUTES-20261006.md#h03-live-parser-und-dynamisches-schreiben--9-oktober-2026)
ergänzt Live-Parsing, Schreibstreams und die Verbindung zum bestehenden Renderer.
50 native Script-/Schreibfälle und 4.524 stückweise Baumvergleiche belegen
den genannten Umfang. Verknüpfte und importierte CSS-Ladebarrieren sowie
nachträgliche CSSOM-Imports sind mit 33 HTTP-Szenen angebunden. Sechs
Standardabweichungen und zwei Chromium-Timeouts bleiben separat erhalten;
das dokumentierte Abbruchprofil gibt entfernte Importrequests frei.
Zehn weitere HTTP-Szenen prüfen die Container-Stylesheet-Barriere und die
Kind-/Frame-/Parent-Load-Abhängigkeiten mit getrennt erhaltenen Chromium-
Abweichungen. Srcdoc-Modus, Dokument-/Basisadresse und Kodierungsstatus sind
mit 20 nativen Fällen, Basisänderungen/History/Namespaces/Adoption mit sechs nativen
Mutationsfolgen belegt; [genauer Umfang](HTML-PARSER-ATTRIBUTES-20261006.md#srcdoc-und-eingefrorene-basisadressen--10-oktober-2026).
15 weitere HTTP-Bytefälle bei drei Decoderstückgrößen belegen den Live-Parser-
Einfügepunkt für festgelegte BOM-/Transportkodierungen, Zustandsdecoder und
CR/LF-Grenzen. Der echte Script-/Rendererpfad erhält Controls und GUI-Identität.
Netzwerkzufuhr und tentative Encodingneustarts nach Veröffentlichung sowie weitere Parserkontexte bleiben
ausdrücklich in Arbeit.

Der [H05-Nachtrag vom 10. Oktober](HTML-PARSER-ATTRIBUTES-20261006.md#attributnamen-namensräume-und-objektidentität--10-oktober-2026)
belegt Attributidentitäten, Objektwechsel, Gleichheit, Reaktionen und Namespace-
Selektoren mit 34 Browsersequenzen sowie erhaltenem tatsächlichem Rendererpfad.
Globale Eingabehinweise, gemeinsame Formzuordnung und lebende Dokumentlisten
haben dort eigene, klar abgegrenzte Nachweise. Weitere Attributachsen bleiben
offen; diese Teilprofile ersetzen keinen pauschalen H05-Abschluss.

Der [Bildkarten-Nachtrag vom 11. Oktober](HTML-PARSER-ATTRIBUTES-20261006.md#lebende-bildkarten-und-flächen--11-oktober-2026)
ergänzt den DOM-Teil von `map.areas`, rohe `area.shape`-Reflexion und den von
Fokusfähigkeit getrennten `area.tabIndex`-Default. Zehn native DOM-Fälle,
Übernahme zwischen zwei lebenden Realms sowie Identitäts-/Abbau-/GC-Kontrollen
sind unabhängig geprüft. Der tatsächliche Renderer-/Controllerpfad ergänzt
48 native Primärfälle mit 82 Zuständen/139 Pointerproben sowie getrennte
Tastatur-, Scriptklick-, Cursor-, Mutations- und Abbaukontrollen. Acht normative
Default-Reihenfolgedifferenzen bleiben von Chromium-Rohdaten getrennt. Die
unabhängige Renderer-Endprüfung mit zwölf Suiten besteht. Der elfte Gesamtlauf
bestätigt den begrenzten Umfang mit 352 registrierten Suiten und anschließend
unveränderten Prüfsummen. Die Studioabnahme bleibt im Profil getrennt offen.

Der [DOM-Basisadressnachtrag](JAVASCRIPT-DOCUMENTS-R02.md#basisadresse-jedes-dom-knotens--11-oktober-2026)
ergänzt `Node.baseURI` für alle geprüften Knotentypen, entfernte Knoten,
Template-/Shadow-Besitzer und Adoption. Sieben native Folgen mit 32 Zuständen
und zusätzliche Kontrollen zwischen zwei lebenden Realms bestehen. Diese
DOM-Anforderung schließt keine weiteren Parser-/Attributachsen pauschal ab.

Der [Mediennachtrag](HTML-PARSER-ATTRIBUTES-20261006.md#gemeinsame-medienattribute-und-montierte-videos--11-oktober-2026)
belegt sieben gemeinsame Audio-/Video-Reflexionen sowie erhaltene montierte
Video-Controls, Quellenwechsel, Loop, Preload und Autoplay. Unabhängige Prüfungen
für Reflexion und den tatsächlichen Renderer-/Controllerpfad bestehen. Die
genannten Attribute haben jeweils eng zugeordnete Registerachsen; vollständiges
Medien-JavaScript und native Studio-Wiedergabe bleiben davon getrennt.

Der [Audio-Quellenlebenszyklus](JAVASCRIPT-AUDIO-20261006.md#quellenwahl-startposition-und-entfernung--11-oktober-2026)
ergänzt Auswahl/Load-Reset, ausgewählte Quellen bei Attributentfernung,
Hint-Resume, Frühpositionen und stabile Dokumententfernung. Der zwölfte
Gesamtlauf bestätigt die genannten Node-/Mediennachträge mit tatsächlichem
Exit 0, 356 registrierten Suiten und anschließend unveränderten 1.660
Quell-/Test-/Fixturedateien sowie sieben Rojo-Projekten. Dies ist der
gemeinsame CLI-Prüfstand vor dem nachfolgenden Poster-/Größen-/SOURCE-Ausbau;
die genannten offenen Konformitäts- und Hostachsen bleiben bestehen.

## Ablauf des vollständigen Abgleichs

Die [Elementreferenz](https://developer.mozilla.org/de/docs/Web/HTML/Reference/Elements),
[Attributreferenz](https://developer.mozilla.org/de/docs/Web/HTML/Reference/Attributes)
und [globalen Attribute](https://developer.mozilla.org/de/docs/Web/HTML/Reference/Global_attributes)
bilden den lesbaren Einstieg; normative Semantik steht im
[HTML-Standard](https://html.spec.whatwg.org/multipage/).

Für jeden Eintrag erfassen: Element/Attribut, Parsing/Reflexion, Verhalten,
Darstellung, Kombinationen, Testnachweis und offene Host-/Konformitätsgrenze.
Kommentare, Inhaltskategorien, Datum/Zeit, ungültige Werte und Fehlererholung
gehören ebenfalls in den Abgleich. Ein Eintrag gilt nur für die belegten Fälle.
Der Standardbestand und erste Nachweise sind im [Attributregister](html-attributes.v1.json)
erfasst. Die offenen Wirkungs-/Darstellungsachsen und die im Parserprofil
genannten Restfälle bilden den weiteren Abgleich. Gemeinsamer Ablauf: [PLAN](../PLAN.md).

Seit dem 12. Oktober enthalten acht vorhandene Mediengruppen zusätzlich
`reviewedRequirements`: einzeln benannte Anforderungen mit geprüftem
Elementteilumfang, festgehaltener Standardrevision, Abnahmekriterien, Stand und
Nachweisen. Die früheren fünf Nachweisachsen bleiben vollständig erhalten.
Die Zuordnungen sind ausdrücklich `partial`; beispielsweise deckt ein
Video-Größennachweis nicht zugleich Canvas, Bild oder Iframe ab. Die
[Poster-/Videogrößenprüfung](HTML-PARSER-ATTRIBUTES-20261006.md#video-poster-und-intrinsische-größen--12-oktober-2026)
und die [geordnete Audio-SOURCE-Auswahl](JAVASCRIPT-AUDIO-20261006.md#geordnete-source-kandidaten--12-oktober-2026)
erfüllen weitere eng benannte Kriterien. Die anschließende
[SOURCE-Reflexion](HTML-PARSER-ATTRIBUTES-20261006.md#source-reflexion-und-geliehene-url-getter--12-oktober-2026)
erfüllt die sieben einzeln zugeordneten IDL-Verträge;
[Seitenabbau während nativer Bildarbeit](HTML-PARSER-ATTRIBUTES-20261006.md#seitenabbau-während-nativer-bildarbeit--12-oktober-2026)
schließt den belegten Host-Besitzfehler einschließlich eines tatsächlich gemounteten
no-JS-Posterpfads. Der unabhängige gemeinsame Lauf mit 18 Suiten besteht.
Zehn teilweise zugeordnete Gruppen enthalten jetzt 50 Anforderungen: 28 erfüllt,
sieben offen und 15 ungeprüft. Die übrigen responsiven `srcset`-/`sizes`-Algorithmen
sind als bisherige Erfassungslücken aufgenommen; ein reflektiertes SOURCE-Mitglied
beweist ihre Auswahl-/Layoutsemantik nicht. Diese Zuordnungen sind keine
vollständige Erfassung oder Gesamtzahl der verbleibenden Arbeiten.

Der folgende gemeinsame Auswahlkern in `HTML/MediaSelection` hält die geprüften
Audio-Kandidatenregeln zentral und schützt zusätzliche Reentryfälle. Die
initiale Poster-Präsentation bleibt während nativer Anfrage, kooperativer
SVG-Vorbereitung und laufender Strukturpublikation verborgen. 52 montierte
Fälle in zwei Backend-Ersatzdiensten bestehen; der unabhängige gemeinsame
17-Suiten-Lauf einschließlich kompakter und isolierter Prüfpfade hat Exit 0.
Der folgende vierzehnte Gesamtlauf bestätigt den gemeinsamen Teilstand mit
tatsächlichem Exit 0, 366 registrierten Suiten und 13 isolierten GC-Prüfpfaden.
Die Quellen-/Projekt-/Holdprüfung besteht auch nach dem Lauf; Prüfprotokoll
und Grenzen stehen in `build/html-full14-acceptance.json`.
Die blanke Anfangsfläche ist die gewünschte Engine-Ladepolitik, kein Nachweis
des vollständigen normativen Dokumentladealgorithmus oder von Studio-Pixeln.
Die [Audioauswahl ohne Realm](JAVASCRIPT-AUDIO-20261006.md#audioauswahl-ohne-javascript-realm--12-oktober-2026)
ist danach separat eingebaut und unabhängig geprüft: 37 montierte Kontrollen,
4.481 Assertions und 16 Resolverfälle; Produktionslauf mit 18 betroffenen
Suiten einschließlich kompakter und isolierter Tails, tatsächlicher Exit 0.
Die vorhandene No-Realm-Audioanforderung erhält genau diesen Nachweis.
Es bleiben dieselben 50 begrenzt erfassten Anforderungen, davon 29 erfüllt,
sechs offen und 15 ungeprüft; diese Zahlen sind kein vollständiger HTML-Restumfang.
Video-Kandidatenwahl, historische Quellenbasis, vollständige Lade-/Task-/Codec-
Semantik und allgemeine native Besitzerfreigabe bleiben getrennt in Arbeit.

Der folgende [AudioHost-Nachtrag](JAVASCRIPT-AUDIO-20261006.md#audiohost-freigabe-und-neue-ladeversuche--12-oktober-2026)
belegt separat die Freigabe Host-eigener Besitzer vor gehaltenem Native-Resume
und Reentryschutz bei gleicher öffentlicher Generation. 23 tatsächliche
MediaBox-Kontrollen/220 Assertions und zusätzlich 27 kompakte Lifetime-Kontrollen/
282 Assertions bestehen nach unabhängigem Review auch im gemeinsamen
19-Suiten-Produktionslauf, tatsächlicher Exit 0. Die kompakte Paintgrenze und
das unveränderte Budget sind ausdrücklich ausgewiesen; der gesamte montierte
Page-/Realm-/WorkContext-/GPU-Graph ist damit nicht abgenommen. Dieser Nachtrag
schließt keine zusätzliche Attributregisteranforderung und keinen globalen
HTML-/CSS-/Studioumfang.

Die [historische Dokumentwahl](HTML-PARSER-ATTRIBUTES-20261006.md#historisches-quellendokument--12-oktober-2026)
ist danach für lebende Ursprungsdokumente in beiden Audio-Auswahlpfaden ergänzt:
20 JS-Fälle/67 Kontrollen, alle 14 archivierten URLzustände, neun additive
native Montagefälle und neun kompakte Daten-Lifetime-Kontrollen bestehen.
Unabhängiger Pfadreview und anschließend 24 produktive Suiten einschließlich
kompakter/isolierter Tails haben Exit 0. Die ursprünglichen Rohreferenzen bleiben
erhalten; zwei alte Ressourcenannahmen besitzen streng getrennte Frozen-
Gegenstücke. Der Fallback nach Sammlung/Abbau des Ursprungs ist weiterhin nur
begrenzt belegt. Die historische Registeranforderung bleibt offen mit konkreten
Teilnachweisen; es bleiben dieselben 50 Anforderungen mit 29/6/15 Statuszahlen.

Der fünfzehnte vollständige CLI-Lauf bestätigt anschließend diesen gemeinsamen
Stand: tatsächlicher Exit 0, 371 Suiten einschließlich sieben verpflichtender
kompakter und 13 isolierter Prüfpfade. Nach dem Lauf bleiben 1.689 Quell-/Test-/
Fixturedateien, sieben Projekte und 164 gehaltene Artefakte unverändert.
Projekt-/Registerabgleiche, unabhängiger enger Doku-/Registerreview und drei
Rojo-Builds bestehen; Nachweis `build/html-full15-acceptance.json`.
Dieser Regressionstest erweitert keine der genannten Konformitätsbehauptungen.

Danach sind [Picture-Typangaben](IMAGES.md#typangaben-in-picture-quellen--12-oktober-2026)
im vorhandenen statischen Bildprofil präzisiert: unbekannte Bildtypen werden
übersprungen. 27 native Referenzfälle und 378 tatsächliche Ressourcen-/Renderbaum-
Assertions sowie fünf unveränderte Bildsuiten bestehen nach unabhängigem Review
im produktiven Sechssuitenlauf. Das erweitert die Quellenauswahl, keine Formatdecoder
und keine vollständige MIME-/responsive Konformität. Die HTML-Registerstatuszahlen
bleiben unverändert.

Die [geordnete Videoauswahl](HTML-PARSER-ATTRIBUTES-20261006.md#geordnete-videoquellen-auf-erhaltenen-backends--12-oktober-2026) ist anschließend für beide erhaltenen Backends mit und ohne Realm übernommen: 28 Anfangsfälle, 41 Livekontrollen/7.203 Assertions, unabhängiger Review und produktiver 15-Suiten-Lauf bestehen. Quellenwechsel erhalten GUI/Controls; Abbau gibt sie frei und sperrt alte Ergebnisse. Dies ergänzt drei offene Medienanforderungen um Teilnachweise; Registerzahlen und globale Zuordnung bleiben unverändert.

Die [Dokumentladebarriere für bereits montierte Videos](HTML-PARSER-ATTRIBUTES-20261006.md#dokumentladebarriere-für-videos--12-oktober-2026) ist danach
begrenzt produktiv geprüft: 38 ursprüngliche Kontrollen/4.595 Assertions,
vier unveränderte unabhängige Rückruffälle jetzt ohne Fehler und 17 additive
Kontrollen/1.707 Assertions ergeben 59 Fälle. Der unabhängige frische
Acht-Suiten-Lauf, physische Core18/49 und der produktive 17-Suiten-Lauf
bestehen mit tatsächlichem Exit 0. Genau drei Quellmodule, ein neuer
Testkörper und seine Registrierung sind übernommen. V1 bleibt historisch
BLOCKED; v2 schützt vier synchron reentrante Benachrichtigungsgrenzen und
folgende Add-Batch-Elemente. Noch ungerenderte VIDEO-Insertion bleibt ein
realer Rotfall. Lazy/hidden/detached, No-Realm-Iframe-/Dokumentload,
vollständige VIDEO-JS-API, erster Decoderframe/Studio und ganze Page-/Realm-
Freigabe sind damit nicht geschlossen. Nur die bestehende offene
Videoquellenanforderung erhält einen Teilnachweis; 277 Gruppen, zehn
Teilzuordnungen, 50 Anforderungen mit 29 erfüllt/sechs offen/15 ungeprüft
bleiben unverändert. Dies ist kein vollständiger HTML-/CSS-/Medienabschluss.

Am 16. Oktober sind die bisherigen ungeprüften responsiven SOURCE-Algorithmen
mit [konkreten Auswahl-/Dichte-/Größenachsen](HTML-PARSER-ATTRIBUTES-20261006.md#responsive-bildauswahl-und-dichtekorrektur--16-oktober-2026)
abgeglichen und als **offen** geführt. Die vollständigen ursprünglichen
Abnahmekriterien bleiben erhalten; native Auswahl, Runtime und behaltene
no-Realm-Renderer besitzen getrennte Nachweise. Der bereits zugeordnete
Teilbestand bleibt bei 50 Anforderungen: 29 erfüllt, acht offen und 13
ungeprüft. Dies ist weiterhin keine vollständige Erfassung des HTML-Restumfangs.

Am 18. Oktober ergänzt der
[Auto-Größen-/Lazy-Nachtrag](HTML-PARSER-ATTRIBUTES-20261006.md#automatische-img-source-größen-und-lazy-fortsetzung--18-oktober-2026)
veröffentlichte IMG-Inhaltsgrößen, letzte Auto-Breiten, Picture-SOURCE-Defaults,
UA-Containment/Kaskade und gemeinsame Anfragebesitzer mit und ohne Realm.
Der finale [korrigierte Nachweis](../build/engine-expansion-20261018/auto-image-corrected-receipt.json)
umfasst elf Quellmodule, 59 Kernkontrollen und 25 Montagekontrollen mit
1.136 Assertions; der unabhängige Gegenlauf prüft elf strikte native Fälle.
Der Zwei-Suiten-Lauf, 13 Nachbarsuiten und zwei zusätzliche Kaskadensuiten
bestehen. Die vorherigen Zwischenzahlen sind kein finaler Abnahmestand.
Die zwei bestehenden SOURCE-Gesamtanforderungen bleiben offen; ursprüngliche
Abnahmekriterien und die noch nicht vollständig abgedeckten Grammatik-,
Einheiten-, Zahlen-, Adoptions-, Parser-/Shadow- und Studioachsen bleiben
erhalten. Dies ist kein neuer vollständiger HTML-/Projektprüflauf.

Die [lebenden Inline-Textregeln](HTML-PARSER-ATTRIBUTES-20261006.md#lebende-inline-textregeln--18-oktober-2026)
ergänzen `word-break:break-word` mit 135 nativen Vergleichsfällen und reparieren
die betroffenen dynamischen Quellgrenzen bestehender Umbruch-/Trenn-/Textregeln.
72 Live-/Frischaufbau-Vergleiche und sieben Nachbarsuiten prüfen die tatsächliche
Textgeometrie und erhaltene unabhängige Controls. Dies erweitert den
abgegrenzten CSS-Rendererpfad vorhandener Inhalte, keinen pauschalen
Parser-, Attribut-, CJK-/Unicode-/Schrift- oder Studioabschluss.
