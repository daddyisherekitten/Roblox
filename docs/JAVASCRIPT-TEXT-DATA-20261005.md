# JavaScript: Text, URL, Datum und Intl – Stand 5. Oktober 2026

Der notwendige Text-/Datenblock des priorisierten Plans ist für den unten
beschriebenen Alltagseinsatz umgesetzt. R07 und R08 bleiben größere Familien mit
weiteren Lücken. Diese Lieferung erklärt weder die ganze URL-Zustandsmaschine
noch sämtliche Date-/Intl-APIs oder weltweiten Sprach-/Zeitzonendaten für fertig.

## Unterstützter Umfang

| Bereich | Gelieferte Semantik | Grenze |
| --- | --- | --- |
| `String.prototype.normalize` | NFC, NFD, NFKC und NFKD mit vollständigen Unicode-17.0.0-Daten; kanonische Ordnung, blockierte Komposition und algorithmisches Hangul; astrale Zeichen und unveränderte einzelne UTF-16-Surrogates | Pin auf Unicode 17.0.0 und bestehende VM-String-/Schrittbudgets |
| URL-Hosts | UTS #46, nichttransitional, NFC, Punycode in beide Richtungen, Bidi-/Joiner-Regeln und Mark-Zeichen; IPv4-Kurzformen einschließlich Hex/Oktal; IPv6 einschließlich IPv4-Endstück und kanonischer Kompression | Keine vollständige URL-/WPT-Konformität behauptet; keine DNS-Abfrage oder Spoofing-/Verwechslungsprüfung |
| URL-Verhalten | Sonder-Schemes, Standardports, Basisauflösung, host-/hostname-/port-/protocol-Setter, Backslash-Regeln, Percent-Encoding-Sets, opaque und hostlose Pfade, `blob:`-Origin, wichtige `file:`-/Windows-Laufwerkfälle | Weitere seltene Parserzustände, beliebige nicht-spezielle Schemes und sämtliche Credentials-/Encoding-/Setter-Kombinationen sind nicht vollständig nachgewiesen |
| `Date` | Gregorianische UTC-Arithmetik, ISO-Parsing, Pflicht-Roundtrips eigener `toString`-/`toUTCString`-Ausgaben bei null Millisekunden, generisches `Symbol.toPrimitive`, echter `toGMTString`-Alias, drei `toLocale…`-Methoden und konfigurierbare lokale Zeitzone | Freies Legacy-/natürlichsprachliches Parsing und hostabhängige Beschreibung in Klammern bei `toString()` bleiben außerhalb des Profils |
| `Intl.DateTimeFormat` | `de-DE`, `en-US`, `en-GB`; Gregorianisch/lateinische Ziffern; normale Komponenten, Wochentag, Ära, 1–3 Bruchsekunden, vier Stundenzyklen, alle vier Datum-/Zeitstile, sechs Zeitzonennamen-Stile, `format`, `formatToParts`, `resolvedOptions`, `supportedLocalesOf` | Kein `formatRange`/`formatRangeToParts`, keine flexiblen `dayPeriod`-Optionen, keine weiteren Kalender/Ziffernsysteme oder vollständige internationale Musterwahl |
| Zeitzonen | UTC, numerische Offsets sowie neun benannte IANA-Zonen; historische Offset- und DST-Übergänge, wiederholte/fehlende lokale Uhrzeiten | Benannte Zonen nur für UTC-Zeitpunkte ab 1900-01-01 einschließlich bis 2101-01-01 ausschließlich; Namen sind moderne CLDR-Saisonprofile |
| `Intl.NumberFormat` | Drei Sprachprofile; Dezimal-, Prozent-, Währungs- und Einheitenformatierung; bedeutende Ziffern, neun Rundungsarten, zulässige Rundungsschritte, Rundungspriorität, wissenschaftliche/technische/kompakte Schreibweise; Teile und aufgelöste Optionen | Nur `latn`; keine Range-Methoden; nicht jede Kombination kompakter Schreibweise mit Währungen/Einheiten ist vollständig nachgewiesen |
| Zahlendaten | CLDR-Namen, Symbole, schmale Symbole und Standard-Nachkommastellen aller 162 aktuellen Referenzwährungen; 45 einfache Einheiten plus 180 Kombinationen pro Sekunde/Minute/Stunde/Tag; kurze/lange kompakte Affixe | Weitere gültige zusammengesetzte Einheiten, etwa `meter-per-liter`, sind explizit außerhalb des Datenprofils |
| Locale-Methoden | `Date.prototype.toLocaleString`, `toLocaleDateString`, `toLocaleTimeString`, `Number.prototype.toLocaleString` verwenden dasselbe interne Intl-Profil | Umfang wie oben; keine Abhängigkeit von einer nachträglich überschriebenen globalen Intl-Konstruktorfunktion |
| `Intl.ListFormat` | Britisch-englische Interpunktion aus tatsächlichen Referenzdaten neben den bestehenden Deutsch-/US-Englisch-Profilen | Keine neue vollständige Welt-Sprachabdeckung |

`de` und andere deutsche Regionsanfragen verwenden das deutsche Datenprofil;
`en` und andere englische Regionsanfragen verwenden US-Englisch, `en-GB` verwendet
das britische Profil. Unbekannte Sprachen handeln das konfigurierte Standardprofil
aus. Gültige, nicht verfügbare Kalender-/Ziffernsystem-Anfragen handeln
`gregory`/`latn` aus. Ungültige Optionswerte behalten ihre `TypeError`-/
`RangeError`-Semantik. Eine unbekannte Zeitzone oder ein ausdrücklich nicht
verfügbares Einheiten-/Tageszeitprofil ergibt einen `RangeError`.

Andere Intl-Familien wie Collator, PluralRules, DisplayNames und vollständige
Locale-Daten sind durch diese Lieferung nicht ergänzt oder freigegeben.

## Byte-Decoder und HTML-Zeichencodierung — 9. Oktober 2026

`Encoding/Decoder` wird von `TextDecoder`, Decoder-Streams, UTF-8-Body-/Blob-
Lesepfaden und dem neuen HTML-Bytepfad geteilt. Alle 228 WHATWG-Labels werden
auf die festgehaltenen Standardcodierungen abgebildet: UTF-8, UTF-16LE/BE,
die Single-Byte-Familien, GBK/GB18030, Big5, EUC-JP, Shift_JIS, EUC-KR,
ISO-2022-JP und x-user-defined. `replacement` bleibt ein interner HTML-Decoder;
der öffentliche TextDecoder-Konstruktor lehnt dessen Labels mit RangeError ab.
Streamingzustände, Fatal-Fehler, BOM-Verhalten und unvollständige Bytefolgen
werden pro Decoder gehalten und bei einer neuen unabhängigen Folge zurückgesetzt.

`HTMLEngine.parseDocumentBytes(bytes, options)` verarbeitet eine vollständige
Rohbytezeichenfolge. `mountHTML` verwendet diesen Byteeingang bei `ByteSource=true`;
`DocumentEncoding` übergibt seine Optionen: `TransportEncoding`,
`OverrideEncoding`, `ParentEncoding` mit `ParentSameOrigin`, `DefaultEncoding`
und die Parser-/Bytebudgets. Ohne äußere Angabe gilt Windows-1252 als explizites
Hostdefault. BOM, Transport und die 1.024-Byte-Metavorschau werden vor dem
Tree-Builder geprüft. Eine erst später tatsächlich geparste Meta-Angabe kann
bei unsicherer Codierung einen einzigen Neustart aus den ursprünglichen Bytes
anfordern, bevor GUI-/Skriptausführung beginnt. `document.characterSet`,
`charset`, `inputEncoding` und DocumentInfo melden die tatsächlich verwendete
Codierung. Spätere Meta-Mutationen recodieren kein bestehendes Dokument.

Seit dem 10. Oktober verwendet `mountHTML` mit aktiviertem JavaScript bei einer
bereits gewissen BOM-/Transport-/Overridekodierung eine Live-Parsersession.
Der gemeinsame Decoder verarbeitet die Bytequelle stückweise, erhält seinen
Zustand über Stückgrenzen und hält am nächsten Script-Einfügepunkt an. Die Option
`DocumentEncoding.DecodeChunkBytes` begrenzt die Stückgröße auf 1–65.536 Bytes
(Standard 4.096); Rohbyte-, gesamte Ausgabebudgets und Abbruch gelten weiter.
`document.write` verändert den Parser-Einfügepunkt, nicht das Ende der noch
ausstehenden Bytequelle. Quellen und Decoderzustände werden beim Ende oder
Abbruch freigegeben. 15 native HTTP-Fälle bei drei Decoderstückgrößen und der
tatsächliche retained Script-/Rendererpfad sind im
[H03-Profil](HTML-PARSER-ATTRIBUTES-20261006.md#festgelegte-bytekodierungen-am-script-einfügepunkt--10-oktober-2026)
belegt. Unsichere Kodierungen bleiben vor Veröffentlichung im vollständigen
Reparsepfad.

Bestehende String-, Fragment- und DOMParser-Eingaben werden nicht als Bytes
umgedeutet. Der Host lädt keine unbekannten Quellen automatisch; HTTP-Transport
und IFrameResolver müssen Rohbytes ausdrücklich durchreichen. Inkrementelle
Netzwerkzufuhr während eines Mounts und Parser-Skripte während eines
Encodingneustarts gehören weiterhin zum offenen H03-Paket.

Der Generator `scripts/export-encoding-data.py` hält WHATWG-Labels und
Indexdaten mit URL/SHA256 in den erzeugten Luau-Dateien fest. Zur Laufzeit gibt
es keine Datendownloads. Multibyte-Indexmodule werden bei Bedarf geladen.
ASCII wird in begrenzten Stringstücken gesammelt; VM-Schritte und Ladepausen
bleiben pro Byte wirksam. HTML begrenzt standardmäßig Rohbytes auf 1 MiB und
decodierte UTF-8-Ausgabe auf 3 MiB; Ausgabeüberschreitungen und Ladeabbrüche
beenden den Decoder vor dem DOM-Aufbau.

Nachweise: `JavaScriptEncoding` mit 51 gespeicherten Chromium-Sequenzen,
Streaming-/Split-/Fatalfällen, Labels und 627 GB18030-Grenzproben;
`EncodingDecoders` mit allen 65.536 Zwei-Byte-Kombinationen je sieben
Multibyte-Familien; `HTMLEncoding` mit 30 echten HTTP-Bytequellen und tatsächlichem
Parserneustart, Encoding-DOM-Properties, Prioritäten und Budget-/Abbruchfällen.
Die Referenzskripte `capture-encoding-reference.cjs` und
`capture-html-encoding-reference.cjs` benutzen eigene unsichtbare Chromium-
Prozesse; Nutzer-Tabs bleiben unberührt. Rohresultate liegen unter
`tests/fixtures/encoding-browser.json` und `html-encoding-browser.json`.

Einzelne Chromium-154-Abweichungen bleiben ausdrücklich erhalten: vier
Big5-Zeiger mit Zweiskalar-Ausgabe, zwei ISO-2022-JP-Zustandsfälle sowie die
doppelte Charset-Angabe und eine späte SVG-Meta-Angabe. Nur diese konkreten
Fälle besitzen zusätzliche normative Erwartungen mit Begründung; keine ganze
Familie wird vom Browservergleich ausgenommen. Das Profil folgt dort den
aktuellen [Encoding-Regeln](https://encoding.spec.whatwg.org/) und
[HTML-Encoding-Regeln](https://html.spec.whatwg.org/multipage/parsing.html#determining-the-character-encoding).
Die Exhaustivprüfung kurzer Bytefolgen ersetzt keinen vollständigen WPT-Abgleich
sämtlicher beliebig langen Streams.

## Datenbasis und Reproduzierbarkeit

Die Laufzeit arbeitet mit gespeicherten Luau-Daten. Sie lädt keine Unicode-/
CLDR-/IANA-Daten über das Netz und ruft keinen Formatter des Hostsystems als
verdeckten Ersatz auf.

| Daten | Gepinnte Referenz |
| --- | --- |
| Unicode-Normalisierung und UTS #46 | Unicode/UCD 17.0.0, UAX #15 Revision 57 und UTS #46 Revision 35 |
| Native JavaScript-Referenz | Node 24.16.0, V8 13.6.233.17-node.49 |
| Intl-Referenz | ICU 78.3, CLDR 48.0, Unicode 17.0 |
| Zeitzonenreferenz | IANA tz 2026b aus der nativen ICU-Referenz |
| Format-/Zahl-/Listensprachen | `de-DE`, `en-US`, `en-GB` |

Unicode-Quellen und ihre SHA-256-Werte liegen in
`scripts/data/unicode-17.0.0/manifest.json`. Der Generator verarbeitet
`UnicodeData.txt`, `DerivedNormalizationProps.txt`, `NormalizationTest.txt`,
`IdnaMappingTable.txt`, `DerivedBidiClass.txt` und `DerivedJoiningType.txt`.
Die erzeugten Normalisierungstabellen enthalten 5.914 Zerlegungen, 968
Combining-Class-Einträge und 961 kanonische Kompositionen; Hangul wird
algorithmisch behandelt. Die Mapping-/Validierungsdaten decken den vollständigen
gepinnten Zeichenvorrat ab.

`scripts/data/intl-date-manifest.json` speichert die native Datenversion und
die genauen Grenzen des Zeitzonenprofils. Die Zahl- und Listendaten enthalten
ebenfalls ihre Referenzversionen. Generierte Datumsmuster und Namenslisten werden
interniert; gleiche Muster werden als gemeinsame Datensätze referenziert.

Der Datumsgenerator erfasst Komponenten-/Stilkombinationen, kontextabhängige
Monats-/Wochentags-/Äranamen sowie echte Verbindungszeichen zwischen Datum, Zeit
und Zeitzonenname. Er berücksichtigt auch den Unterschied bestimmter ICU-Ausgaben
zwischen `format()` und den zusammengesetzten `formatToParts()`-Literalen.
Die Referenzversion ist deshalb Teil des Vertrags; Ausgaben neuerer oder anderer
Browser-/ICU-Versionen können abweichen.

Die Zeitzonendaten entstehen durch tägliche Offset-Abtastung der neun Zonen
mit anschließender binärer Bestimmung jedes erkannten Übergangs auf die Sekunde.
Folgende Namen sind verfügbar:

- `Europe/Berlin`, `Europe/London`
- `America/New_York`, `America/Los_Angeles`, `America/Chicago`
- `Asia/Tokyo`, `Asia/Kolkata`
- `Australia/Sydney`, `Pacific/Auckland`

UTC-Aliase werden kanonisiert. Numerische Offsets akzeptieren `±HH`, `±HHMM`
und `±HH:MM`. UTC und feste Offsets benötigen keine historischen Tabellen und
behalten den regulären Date-Zeitbereich.

Benannte Zonen wählen bei einer doppelt vorkommenden lokalen Uhrzeit den früheren
Zeitpunkt. Eine fehlende lokale Uhrzeit wird um die Lücke vorwärts verschoben.
Historische UTC-Offsets sind datenbasiert. Kurz-/Lang-/generische Namen stammen
aus den zwei Referenzsaisons 2026; historische Sonderoffsets fallen auf einen
wahrheitsgemäßen GMT-Offset zurück. Vollständige historische Umbenennungen sind
nicht enthalten.

Die mitgelieferten Unicode-/CLDR-Daten stehen unter der mitgelieferten
`scripts/data/UNICODE-LICENSE.txt`; die Lizenz wird vom Generator ebenfalls
gehasht. Datenaktualisierungen müssen bewusst erzeugt und zusammen mit ihren
nativen Erwartungen geprüft werden.

## Realm-Konfiguration und Alltagscode

`JavaScriptServices.DefaultLocale` und `DefaultTimeZone` werden von der
gerenderten Seite über Runtime und VM bis zur Bibliothek weitergegeben.
`TimeZone` ist ein akzeptierter Alias für die Standardzeitzone. Ohne Vorgabe ist
die lokale Date-Zone UTC. Ein explizites `timeZone` im Formatter hat Vorrang.
`DateNow`, `TimezoneOffsetMinutes` und `DateLocalToUTC` bleiben Adapter für die
Hostintegration; vorhandene explizite Date-Adapter haben Vorrang vor der
benannten Date-Zone.

```javascript
const name = 'Cafe\u0301'.normalize('NFC');
const url = new URL('https://bücher.de/angebote?preis=ä');

const date = new Intl.DateTimeFormat('de-DE', {
  dateStyle: 'long', timeStyle: 'short', timeZone: 'Europe/Berlin'
}).format(Date.UTC(2026, 9, 5, 13, 4));

const money = new Intl.NumberFormat('de-DE', {
  style: 'currency', currency: 'EUR'
}).format('1234.56');

const cash = new Intl.NumberFormat('de-DE', {
  minimumFractionDigits: 2, maximumFractionDigits: 2,
  roundingIncrement: 5, roundingMode: 'halfEven'
}).format('1.025');
```

Date-Locale-Methoden geben bei einem ungültigen Date zuerst `Invalid Date`
zurück. Echte Date-Receiver werden geprüft; `Date.prototype[Symbol.toPrimitive]`
behält seine generische Receiver- und Hint-Semantik. Der Vergleich prüft die
standardisierte Ausgabe von `toString()` vor der implementationsabhängigen
Zeitzonenbeschreibung in Klammern.

Zahlenrundung arbeitet auf Dezimalziffern statt über binäre Float-Multiplikation.
Damit behalten auch mathematische Strings und BigInt-Werte ihre relevanten
Ziffern. Das Profil enthält die neun Rundungsarten `ceil`, `floor`, `expand`,
`trunc`, `halfCeil`, `halfFloor`, `halfExpand`, `halfTrunc`, `halfEven` sowie
die spezifizierten Rundungsschritte von 1 bis 5.000. Die Kompatibilitätsprüfungen
zwischen Rundungsschritt, Nachkommastellen und bedeutenden Ziffern sind enthalten.

### Gemeinsame opaque Hosts — Nachprüfung vom 10. Oktober 2026

`URLRecord` verwendet für nicht spezielle Hosts die C0-Percent-Encoding-Menge
des [WHATWG opaque-host parser](https://url.spec.whatwg.org/#concept-opaque-host-parser).
Großschreibung, vorhandene Prozentzeichen und erlaubte druckbare ASCII-Zeichen
bleiben erhalten; Unicode, DELETE und die zulässigen C0-Zeichen werden UTF-8-codiert.
Verbotene Hostzeichen führen zu Parse-Failure, einschließlich `[`/`]` außerhalb
eines gültigen IPv6-Hosts. Tabs, CR und LF werden zuvor vom vollständigen
URL-Parser entfernt. Die Zeichenmengen von `encodeURI`/`encodeURIComponent`
bleiben eigenständig. Nicht spezielle Authority-URLs ohne Pfad behalten einen
leeren Pfad, auch vor Query oder Fragment.

Der behobene Fehler war ein undefinierter `reserved`-Bezeichner im gemeinsamen
Hostparser; dadurch meldete beispielsweise `new URL('foo://UPPER.example/a')`
einen allgemeinen `Error`. Der Fix betrifft ausschließlich `URLRecord`:
Host-Encoding, Klammerprüfung und Initialisierung des nicht speziellen Pfads.
Die getrennte Nachprüfung des IPv6-Suffixes behebt außerdem einen optionalen
Doppelpunkt im Authority-Muster: `foo://[::1]123/p` und die entsprechende
HTTPS-URL scheitern nun, statt still einen Portseparator einzufügen. Hinter
dem schließenden `]` darf nur das Ende oder ein ausdrücklicher `:` mit Port
stehen. Grundlage sind [Hostparser und Hostzustand im WHATWG-Snapshot fde3f74f](https://url.spec.whatwg.org/commit-snapshots/fde3f74f063341a28d437216f75735b8b40128f5/#host-state).
Die Aufrufer verwenden denselben Parser:

- `LibraryURL`: Konstruktor, `parse`/`canParse`, `href`, `host` und `hostname`.
- `DocumentInfo`: HTML-URL-Reflektion und eingefrorene `base`-URLs über
  `URLRecord.resolve`; dazu zählen geprüfte `href`, `src` und Formular-`action`.
- `Navigation` und `NetworkData`: über den installierten URL-Konstruktor, unter
  anderem History-Prüfung, Location, `Request` und `Response.redirect`.
- `DocumentOrigin`: ebenfalls `URLRecord.resolve`; opaque Dokumentursprünge
  bleiben eigenständige Identitäten, obwohl ihre URL-Origin-Serialisierung
  jeweils `null` lautet.

`tests/URLRecords.luau` prüft 502 gespeicherte Browsersequenzen aus
`tests/fixtures/url-record-browser.json`: 501 stimmen direkt mit Chromium 154
überein; eine enthält ein ausdrücklich getrenntes Standarddelta. Die Aufnahme
deckt sämtliche 128 ASCII-Codepoints im Konstruktor sowie in beiden Hostsettern
ab, dazu Unicode, einzelne Surrogates, Prozentzeichen, IPv6, relative und leere
Pfade, Query-Paar-Identität, tatsächliche HTML-Mutationen und Netzwerk-Konstruktoren.
Die Konstruktorfälle prüfen zusätzlich den realmfreien gemeinsamen Record-Zugang. Die
Quellen stehen in `tests/fixtures/url-record-cases.js`; die Aufnahme erfolgt mit
`scripts/capture-url-record-reference.cjs` in einem isolierten Browser.
Davon prüfen 72 Sequenzen IPv6-Suffixe für spezielle und nicht spezielle URLs:
kein/leer/numerischer Port, fehlender Doppelpunkt, sonstige Zeichen und
ungültige Ports im Konstruktor sowie in beiden Hostsettern. Ungültige Hosts
lassen URL, Query-Paare und Fragment unverändert; vorhandene Port-Teilupdates
eines `host`-Setters bleiben entsprechend der nativen Referenz erhalten.

Das Standarddelta betrifft allein eine ungültige erste `base`-URL:
Chromium 154 meldet danach `document.baseURI === 'about:blank'`, auch in einem
HTTP-Dokument. Der unveränderte Enginepfad verwendet die Dokument-Fallback-URL,
wie [HTML: eingefrorene Basis-URL, Schritt 3](https://html.spec.whatwg.org/multipage/semantics.html#set-the-frozen-base-url)
verlangt. Rohwert, Standardwert und Quelle sind getrennt gespeichert; die übrigen
Werte derselben Sequenz bleiben direkte Browsererwartungen. Das ist keine
pauschale Normalisierung weiterer Unterschiede.

Die neue Suite verwendet das bestehende Runtime-Budget von 30.000 Schritten.
Fünf native Klicks führen jeweils 15 URL-/Setter-/Query-Operationen aus. Ein
separater VM-Fall überschreitet absichtlich dieselbe Grenze und prüft die
Erholung im nächsten Eintrag; eine zu große Host-Encoding-Ausgabe bleibt ein
auffangbarer `RangeError`. Gehaltene Query-Paare erhalten URL-/Realm-Identität;
freigegebene URL-/Query-/VM-/Seitenzyklen werden mit einem unabhängigen
GC-Kontrollobjekt und unveränderter begrenzter Speicherlast geprüft. Der Runner
isoliert diese Lebensdauerprüfung bei Sammelläufen. Diese Budgetbelege ersetzen
keine Messung der Framezeit oder vollständige kooperative Nachweise aller
nativen Codec-Schleifen.

Die bisherigen 30 `JavaScriptTextData`-Gruppen mit 4.729 Erwartungen bleiben
unverändert. Zusätzlich bestehen die neue Suite und zwölf betroffene
HTML-/Runtime-Nachbarsuiten sowie
die eigenständigen Bibliotheks- (62), Navigation-/Storage- (19) und
NetworkData-Prüfungen (71 Fälle). Vollständige WHATWG-Zustandsmaschine/WPT,
sämtliche Credentials-/leere-Host-/Setter-Kombinationen und vollständige
Dokumentnavigation über einen Roblox-Hostadapter bleiben weiterhin gesonderte
Anforderungen; dieser Fix behauptet dafür keinen Abschluss.

```text
node scripts/capture-url-record-reference.cjs
node scripts/run-html-tests.cjs URLRecords JavaScriptTextData BaseURLs JavaScriptRealmLifetime
```

## Kosten, Receiver und Lebensdauer

Normalisierung und Punycode belasten das VM-Schrittbudget auch in inneren
Schleifen. Lange Folgen kombinierender Zeichen werden stabil sortiert, damit
die kanonische Ordnung keine quadratische Einfügesortierung benötigt.
Normalisierung begrenzt die temporäre Zerlegung zusätzlich auf ungefähr 262.144
Codepoints; die bestehenden String-Ausgabegrenzen gelten anschließend weiter.
Normalisierungsfehler für ungültige Formen und überschrittene String-/
Zwischenbudgets sind auffangbar.

Dezimalrundung belastet ebenfalls das Schrittbudget. Locale-Listen und die
bestehenden Bibliotheks-/Stringgrenzen bleiben begrenzt. Zeitzonenoffsets verwenden
binäre Suche in unveränderlichen Übergangslisten; Standarddaten werden zwischen
Realms geteilt. Formatter-Zustand, gebundene Formatfunktionen und Fehlerbehandlung
gehören zum jeweiligen Realm und werden mit dessen Intl-/VM-Lebensdauer verworfen.
Diese Aussage ist eine Implementierungsbeschreibung, keine FPS-Messung.

## Nachweise

`tests/UnicodeNormalization.luau` prüft sämtliche 20.034 Datenzeilen des
offiziellen Unicode-17-Korpus. Jede Zeile prüft die fünf Korpusspalten für alle
vier Formen, also 400.680 Normalisierungsinvarianten, ergänzt um einzelne
Surrogate-Regressionsfälle.

`tests/JavaScriptTextData.luau` besteht mit 30 nativen Vergleichsgruppen und
4.729 aufgezeichneten Erwartungen. Die Referenzquelle ist
`tests/fixtures/javascript-text-data-native.json`; die gleichen JavaScript-
Quellen laufen im nativen Node/ICU und in der Engine-VM. Die Gruppen umfassen:

- Receiver-/Optionskonvertierung, boxed Strings mit überschriebenem `toString`,
  vier Normalformen, astrale Zeichen und einzelne Surrogates.
- Unicode-/IDNA-/IP-Hosts, ungültige Bidi-/Joiner-/Mark-/IPv6-Fälle, Defaultports,
  relative und opaque URLs, Setter sowie Windows-/file-Pfade.
- Drei Datumssprachen, 16 Datum-/Zeitstilpaare mit vier Stundenzyklen,
  Format-Teile, echte CLDR-Separatoren, Unicode-Optionen und Fehler.
- Neun Zeitzonen mit historischen, heutigen DST- und zukünftigen Zeitpunkten;
  Date-Realm-Lücken/Überlappungen und Pflicht-Parse-Roundtrips für Berlin und New York.
- Neun Zahlenrundungsarten, bedeutende Ziffern, Rundungspriorität/-schritte,
  Notationen, exakte numerische Strings, Currency-/Unit-Teile und Standard-
  Nachkommastellen sämtlicher 162 Referenzwährungen in drei Sprachen.
- Britische ListFormat-Interpunktion sowie Date-Primitive-Konvertierung,
  Stundenzyklen, ungültige Dates und ISO-Komponentenränder.

Ein zusätzlicher Engine-Test prüft die auffangbaren `RangeError`-Grenzen bei
großen NFKD-Zerlegungen und einer zu großen String-Ausgabe; diese absichtlichen
VM-Budgetgrenzen werden separat vom nativen Konformitätsdatensatz geprüft.

Zusätzlich bestanden nach der Integration `JavaScriptLanguage`,
`JavaScriptScriptLoader` mit 22 gemeinsamen Reihenfolgefällen und
`JavaScriptProfilesReviewPage` mit der bestehenden Vergleichsseite. Der finale
Gesamtlauf und die Projekt-/API-Prüfungen werden im übergeordneten Abschluss
ausgewiesen.

```text
node scripts/run-html-tests.cjs UnicodeNormalization JavaScriptTextData
node scripts/run-html-tests.cjs JavaScriptLanguage JavaScriptScriptLoader JavaScriptProfilesReviewPage

python scripts/generate-unicode-text-data.py
python scripts/generate-unicode-text-data.py --download
node scripts/generate-intl-date-data.cjs
node scripts/generate-intl-number-data.cjs
node scripts/generate-intl-list-data.cjs
node scripts/generate-text-data-fixtures.cjs
```

Der normale Unicode-Generator verwendet die gespeicherten Quellen;
`--download` aktualisiert sie von den offiziellen Quellen. Die Intl-Generatoren
verwenden die jeweils installierte native Node-/ICU-Version. Eine Ausführung mit
anderer Version ist eine Datenänderung und erfordert neue Versionsangaben und
erneute native Vergleichsläufe.

## Primärquellen

- [ECMA-262: String.prototype.normalize](https://tc39.es/ecma262/multipage/text-processing.html#sec-string.prototype.normalize)
- [Unicode 17.0.0 UAX #15, Revision 57](https://www.unicode.org/reports/tr15/tr15-57.html)
- [Offizielles Unicode-17-Normalisierungskorpus](https://www.unicode.org/Public/17.0.0/ucd/NormalizationTest.txt)
- [Unicode 17.0.0 UTS #46, Revision 35](https://www.unicode.org/reports/tr46/tr46-35.html)
- [WHATWG URL Standard: Hosts und Parser](https://url.spec.whatwg.org/#concept-host-parser)
- [ECMA-262: Date Objects](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-date-objects)
- [ECMA-402: DateTimeFormat](https://tc39.es/ecma402/#sec-intl.datetimeformat)
- [ECMA-402: NumberFormat](https://tc39.es/ecma402/#sec-intl-numberformat-constructor)
- [Unicode CLDR 48](https://cldr.unicode.org/downloads/cldr-48)
- [IANA Time Zone Database](https://www.iana.org/time-zones)
- [Unicode-Datenlizenz](https://www.unicode.org/license.txt)
