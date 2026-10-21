# R01: Sprache und gemeinsames Objektmodell

Prüfstand: 4. Oktober 2026. R01 ergänzt den bestehenden Sprachunterbau und
behebt konkrete Environment-, Konvertierungs-, Deskriptor-, Syntax- und
Realmfehler. Die weiter unten genannten offenen Fälle bleiben Teil von R01;
dieses Profil behauptet keine vollständige ECMAScript-Konformität.

## Ergänztes Verhalten

| Bereich | Verhalten und zuständige Dateien |
| --- | --- |
| Globale Bindungen | `GlobalEnvironment` trennt globale Objekteigenschaften von `let`/`const`/Klassenbindungen. Lexikalische Bindungen dürfen konfigurierbare globale Eigenschaften verdecken, ohne sie zu verändern. `var`, Funktionen, implizite Zuweisungen, Accessoren, geerbte Eigenschaften, Löschen, readonly und direkte globale `eval`-Deklarationen besitzen getrennte Regeln. |
| Deklarationsprüfung | Vor Nebenwirkungen prüft `VM.Run` Konflikte zwischen Skripten, eingeschränkte globale Eigenschaften, nicht erweiterbare Globalobjekte und globale Funktionen. Ein Fehler installiert keine vorhergehenden Variablen des fehlerhaften Skripts. |
| `this` | Gewöhnliche Funktionen ersetzen nullish durch ihr eigenes Realmglobal und boxen primitive Receiver mit den intrinsischen Prototypen. Strikte Funktionen behalten primitive Werte und `undefined`. Geänderte globale Konstruktoren verändern das Boxing nicht. |
| Realm und Prototypen | Aufrufe fremder Funktionen nutzen deren Realm. Gewöhnliche und native Konstruktoren berücksichtigen den Realm von `newTarget`, einschließlich gebundener Funktionen und Proxies. Array-Species behandelt fremde intrinsische Array-Konstruktoren gesondert. Fremde Proxy-/TypedArray-Objekte behalten ihr exotisches Propertyprotokoll und ihre Brands. |
| Binärdaten | Borrowed TypedArray-/DataView-Methoden, fremde Backingbuffer, eigene nichtnumerische Properties und Native-Subklassen erhalten ihren Brand und Prototyp. Iteratorgetter werden einmal gelesen; iterable Werte werden erst nach dem Sammeln konvertiert. ArrayBuffer-/DataView-Konvertierungen und beobachtbare TypedArray-Prototypabfragen folgen dem ausgewiesenen Browserprofil. Lokale Realmregistries bleiben für den Abbau zuständig; gemeinsame Brandlookups sind schwach. |
| Fehlerobjekte | Error-Konstruktoren und native Function-Methoden besitzen die passenden `name`-/`length`-/`prototype`-Deskriptoren. Aufruf ohne `new` ignoriert den Receiver. Fehler aus einem fremden Realm besitzen dessen Fehlerprototyp. |
| Frühe Syntaxfehler | Strict-reservierte Namen, strikte Parameter/Funktionsnamen, Klassenexpressionen, Switch-/For-Lexikalkonflikte, ungültige Iterationsziele, Destructuring-Zuweisungen und Function-Deklarationen außerhalb passender Statementlisten werden geprüft. |
| Methoden und Iteratoren | Objektmethoden unterstützen `*name`, `*[expression]`, `async *name` und `async *[expression]`, einschließlich `super`, Generator-`finally` und Iterator-Close. Ungültige Generator-/Async-Accessoren und Rest-Setterparameter werden verworfen. |
| Nichtdezimale Zahlen | `LibraryNumbers.radix` berechnet die Ausgabe anhand der binary64-Präzision statt einer festen 64-Stellen-Grenze. Das geprüfte Referenzprofil ist Node/V8, einschließlich Subnormalzahlen und Radices 2–36. |

## Reproduzierbare Prüfungen

`node scripts/test-javascript-r01.cjs` prüft die gemeinsame Core-Fixture und
61 eingefrorene Zahlengruppen mit insgesamt 2.135 Vergleichen gegen Node/V8.
`--update-reference` ist eine bewusste Aktualisierung der Referenzdaten;
gewöhnliche Testläufe ändern sie nicht.

Die Core-Fixture prüft mehrere aufeinanderfolgende Skripte desselben Realms,
eigene und fremde Realms, Propertydeskriptoren, globale Accessoren und Fehler.
Sie liegt in `tests/fixtures/javascript-r01-core.json`. Der Runner kann sie
auch als `JavaScriptLanguage` ausführen. Die Toolchain und die Abweichung des
Node-Globalhosts stehen in `javascript-r01-reference.json`.

Weitere erneut bestandene Referenzen: Sprache 47, Standardbibliothek 62,
erweiterte Bibliothek 58, Reflection 37, Klassen 16, DynamicCode 10,
Generatoren 41 und TypedArray-Propertyfälle 30. Die Generator-Fixture besitzt
eine eigene Microtaskprüfung; sie wird nicht durch einen synchronen
Sprachrunner ersetzt. RuntimeStorage, NativeDescriptors und RealmLifetime
prüfen zusätzlich den tatsächlichen HTML-Realm, Installation und Abbau.
Diese Fallzahlen messen Abdeckung einzelner Fixtures, keinen
Konformitätsprozentsatz. Es wurden keine FPS-Messungen durchgeführt.

Die ergänzte Core-Fixture umfasst 27 Fälle. Sie prüft auch die internen
TypedArray-Konstruktionswege `of`, `from`, `map` und `filter` sowie den
Ursprungsrealm intrinsischer Fehler aus fremden suspendierten Stacks.
Die TypedArray-Propertygruppe prüft zusätzlich den Abbau eines Realms,
während ein anderer Realm noch einen View auf dessen freigegebenen Buffer
hält. Dieses Abtrennen beim Engineabbau ist ein Hostprofil und kein
behauptetes Browserverhalten beim Entfernen eines Iframes.
`JavaScriptSelectionRealms`
prüft zusätzlich authentifizierte borrowed Selection-Methoden/-Getter
zwischen zwei tatsächlichen Runtime-Realms, ShadowRoot-Auswahlansichten,
öffentliche Methodenüberschreibungen, Brand-Fälschungen und Abbau. Private
gemeinsame weak Lookups ersetzen keine beliebig kopierbare JS-Brandproperty.

## Referenzprofil und offene Grenzen

- Annex B ist weiterhin unvollständig. Das aktuelle Profil erlaubt einzelne
  gewöhnliche nichtstrikte Blockfunktionen; die vollständige äußere
  Annex-B-Var-Hoistingsemantik fehlt. Legacy-Octal-Strings werden ausdrücklich
  verworfen. Legacy-Literale, HTML-Kommentare und weitere Annex-B-Sonderfälle
  bleiben offen. `with` ist derzeit nicht implementiert.
- Die neuen Early-Error-Fälle ersetzen keine vollständige Test262-Auswertung.
  Weitere Syntax-, Parameter-, Klassenelement-, ASI- und RegExp-Randfälle
  bleiben R01 beziehungsweise R07 zugeordnet.
- Der Node-Globalhost meldet eine ungültige Deklaration einer globalen
  Funktion über einer eingeschränkten bestehenden Property als `SyntaxError`.
  `GlobalDeclarationInstantiation` spezifiziert hierfür `TypeError`.
  Die Fixture erfasst beide Erwartungen ausdrücklich; andere Browserhosts
  müssen separat geprüft werden.
- Nichtdezimaler `Number.prototype.toString` ist im Standard
  implementation-approximated. Der V8-Vergleich umfasst viele Grenzfälle,
  nicht alle binary64-Werte und nicht alle Browserimplementierungen.
- Das bestätigte Chromium-154-/Node-24-V8-Profil für TypedArray-Konstruktoren
  beobachtet bei gewöhnlichen Arraylike-Eingaben deren Länge vor
  `newTarget.prototype`; iterable Eingaben werden davor gesammelt.
  Die aktuelle ECMA-Reihenfolge allokiert das TypedArray-Objekt einschließlich
  Prototypabfrage früher. Diese konkrete Browserabweichung wird bewusst als
  Referenzprofil nachgebildet und nicht als universelle Standardgarantie
  bezeichnet. Primitive und authentifizierte Buffer-/TypedArray-Eingaben
  besitzen eigene geprüfte Wege.
- Binärdaten besitzen weiterhin ein begrenztes Number-TypedArray-Profil.
  Resizable/Growable ArrayBuffer, BigInt-TypedArrays, Float16, die vollständige
  TypedArray-Methoden-/Speciesfamilie und weitere beobachtbare
  Konvertierungs-/Konstruktor-Reihenfolgen sind offen. Die Byte- und
  Enumerationsbudgets bleiben Teil des Hostprofils.
- Web-IDL-Receiver und Konvertierungen werden über die tatsächlichen
  Interfaceprototypen und ihre zugehörigen DOM-Familien geprüft. Das
  gemeinsame Objektmodell allein beweist keine vollständigen
  Cross-Realm-Brands aller Browser-APIs.
- WeakMap-/WeakSet-Ephemerons, WeakRef, FinalizationRegistry und Shared Memory
  werden durch den Luau-Unterbau nicht vollständig nachgewiesen und bleiben
  R19 zugeordnet. Cross-Realm-Scheduling bleibt R14 zugeordnet.

## Primärquellen

Die Algorithmusgrundlage sind
[GlobalDeclarationInstantiation](https://tc39.es/ecma262/multipage/ecmascript-language-scripts-and-modules.html#sec-globaldeclarationinstantiation),
[OrdinaryCallBindThis](https://tc39.es/ecma262/multipage/ecmascript-language-functions-and-classes.html#sec-ordinarycallbindthis),
[GetFunctionRealm](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-getfunctionrealm),
[Number::toString](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-tostring),
die [TypedArray-Konstruktoren](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-typedarray-constructors)
und die [Web-IDL-Konvertierungsregeln](https://webidl.spec.whatwg.org/#es-type-mapping).
Dies sind lebende Standards; die Tests halten ihre tatsächlich verwendete
native Referenz separat fest.

Der [API-/Statusregister](JAVASCRIPT-API-REGISTER.md) ergänzt das Profil um
automatisch entdeckte Exporte, Prototypen und offene Roadmapfamilien. Die
[Hostgrenzen](JAVASCRIPT-HOST-CAPABILITIES.md) trennen dokumentierte
Roblox-Fähigkeiten von tatsächlich durchgeführten Studio-/Liveprüfungen.
