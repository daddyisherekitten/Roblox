# JavaScript API- und Statusregister

Stand: 18. Oktober 2026. Das versionierte
[Register v1](javascript-api-register.v1.json) wird aus einem tatsächlich
initialisierten, leeren HTML-Runtime-Realm erzeugt. Es enthält globale
Deskriptoren, Konstruktor-Slots, statische Mitglieder, intrinsische und
Interfaceprototypen, Accessorverfügbarkeit, Methodenmetadaten,
Prototypbeziehungen und Aliasnamen. Jede offene Familie R00–R20 bleibt mit
Ziel, Abhängigkeiten und Abschlusskriterium enthalten.

Ein vorhandener Deskriptor bedeutet „erreichbar im untersuchten Profil“.
Er bedeutet nicht, dass sämtliche Methoden, Fehlerfälle, Darstellungs- oder
Browserregeln der betreffenden Familie fertig sind. Die Familien bleiben
deshalb explizit offen, bis die Roadmapkriterien nachgewiesen sind.

Das gespeicherte Register enthält derzeit 5.320 Deskriptoren,
689 erreichbare Objekte/Prototypen und 140 zugeordnete Module. Der Export hat
keinen Propertygetter ausgeführt; der anschließende `--check` stimmt mit dem
gespeicherten Register überein.

## Erzeugen und überprüfen

```powershell
node scripts/export-javascript-api.cjs
node scripts/export-javascript-api.cjs --check
```

Der Exporter startet `JavaScriptAPIInventory` im bestehenden Luau-Runner.
Die Quelle ist `tests/JavaScriptAPIInventory.luau`; die eigentliche Runtime
und ihre Module werden unverändert eingebunden. Der Export startet keine
Seitenskripte und evaluiert keine Propertygetter. Ein Sentinel-Accessor
verifiziert dies; der Runtime wird anschließend abgebaut.

`--check` erzeugt denselben Bestand im Speicher und vergleicht ihn mit dem
gespeicherten Register. Nur der Generierungszeitpunkt ist vom Vergleich
ausgenommen. Modulhashes und Declarationzeilen ändern sich, wenn Code
geändert wurde; dann muss das Register erneut erzeugt werden.

## Felder

| Feld | Bedeutung |
| --- | --- |
| `schema`, `revision` | Maschinenlesbare Registerversion, getrennt von der Engineversion |
| `families` | Alle R00–R20-Ziele einschließlich noch nicht exportierter Familien |
| `modules` | Zuständige Quelldateien, Hashes, Standardreferenzen und direkte Regression-Abhängigkeiten |
| `owners` | Entdeckte Objekte/Prototypen mit stabilen Exportpfaden und Aliasnamen |
| `descriptors` | Daten-/Accessor-Properties mit Flags, Value-Typ, Methodennamen/-längen und erreichbaren Konstruktor-Slots |
| `declaration` | Datei/Zeile der installierten nativen Funktion oder Registrierungshülle |
| `stage`, `spec`, `tests` | Zuordnung und überprüfbare Hinweise; ein Fixturebezug ist keine Einzelmethoden-Konformitätsgarantie |
| `eventHandlers`, `eventInterfaces` | Entdeckte Handlerdeskriptoren und Eventkonstruktoren; kein erfundener vollständiger Katalog nativer Eventlieferung |
| `profiles` | Geprüfte Erweiterungsprofile R01–R04 sowie Teile von R05/R06, R07/R08, R10/R12 und R13/R14/R16, jeweils mit ausdrücklich verbleibenden Grenzen |
| `evidence`, `limitations` | Getter-/Script-Sentinel, Untersuchungsprofil und ausdrücklich verbleibende Lücken |

Eine kleine Abfrage findet zum Beispiel alle Selection-Mitglieder:

```javascript
const register = require('./docs/javascript-api-register.v1.json');
console.table(register.descriptors
  .filter(entry => entry.path.includes('Selection.prototype.'))
  .map(({path, descriptor, declaration, stage}) =>
    ({path, descriptor, declaration: declaration?.module, stage})));
```

## Grenzen des Exports

Accessor-Rückgabewerte werden nicht evaluiert. APIs, die erst nach einer
Konstruktion oder Hostaktion erscheinen, benötigen eigene Familienfixtures.
Bereits installierte `scheduler`- und Navigatorobjekte werden über ausdrücklich
private Inventarreferenzen erreicht. Das umgeht keine Autorengetter und ruft
keine API-Methode auf; eine erfolgreiche Aufgabenplanung, Sperre oder Anfrage
wird daraus nicht abgeleitet.
Legacywrapper ohne getterfreies Own-Descriptor-Protokoll bleiben als
`inspection`-Lücke sichtbar. Eine generische Registrierungshülle kann einer
anderen Datei angehören als der darunter aufgerufene Algorithmus; die
Declaration ist deshalb ein Wiederfindehinweis und kein Beweis für dessen
vollständige Semantik.

Die Modulreferenzen enthalten direkt registrierte Regressionen; die neuen
Dialog-/Lifecyclemodule nennen außerdem ausdrücklich zugeordnete Familien-
und Browserintegrationstests mit entsprechendem `testMeaning`. Fehlende
Einzelmethoden-Belege werden ausdrücklich nicht aus der Zahl verfügbarer
Properties abgeleitet. Laufzeitgenerierte Eventnamen und die Lieferung
nativer Roblox-Signale werden getrennt anhand des
[Hostprofils](JAVASCRIPT-HOST-CAPABILITIES.md) und der Input-Fixtures bewertet.
Studio-/Livehostprüfungen werden durch diesen CLI-Export nicht ausgeführt.

Den implementierten Coreumfang und seine verbleibenden Fälle dokumentiert
[R01](JAVASCRIPT-R01-CORE.md). Der vollständige Ausbauauftrag bleibt in der
[Roadmap](JAVASCRIPT-ROADMAP.md), die bekannten Runtime-/Hostprofile im
[Implementierungsstand](JAVASCRIPT-IMPLEMENTATION.md).

Der [Durchlauf vom 5. Oktober](JAVASCRIPT-FOUNDATIONS-20261005.md) ergänzt
unter anderem CSSNestedDeclarations, Image/HTMLImageElement-Lademitglieder,
FontFace, document.fonts/FontFaceSet, FontFaceSetLoadEvent und
HTMLScriptElement.supports. Auch String.normalize, Date-/URL-/Intl-Erweiterungen
werden aus der tatsächlichen gemeinsamen VM exportiert. Instanzzustände wie
document.fonts werden zusätzlich durch ihre eigenen Regressionen geprüft;
ein reiner Descriptor-Export ersetzt diese Prüfung nicht.

Der [Dialog-/Lifecycleumfang vom 15. Oktober](JAVASCRIPT-IMPLEMENTATION.md#dialoge-und-dokumentlebenszyklus--15-oktober-2026)
ergänzt die tatsächlich installierten Globals `alert`, `confirm`, `prompt`,
`PageTransitionEvent` und `BeforeUnloadEvent` sowie die schreibgeschützten
Document-Getter `hidden` und `visibilityState`. Diese neuen Mitglieder sind
R14 zugeordnet. Das leere Exportprofil öffnet keine Dialoge und erteilt keine
Nutzeraktivierung; synchrone Antworten, Abbruch, native Modalbedienung,
Navigation und Sichtwechsel werden durch die verlinkten Tests geprüft.
Der Registerexport selbst gilt weiterhin weder als Studioabnahme noch als
Abschluss der übrigen R14-Anforderungen.

Das [kooperative Idleprofil](JAVASCRIPT-IMPLEMENTATION.md#kooperative-idle-callbacks--15-oktober-2026)
ergänzt `requestIdleCallback`, `cancelIdleCallback` und `IdleDeadline` mit
konkreter W3C-Entwurfsquelle und R14-Zuordnung. Sein Timeout-/Cancellation-
Verhalten und sein vorhandener Tasktreiber sind funktional geprüft; der
begrenzte Hostbudgethinweis ist kein Beweis für freien nativen Frame-/Compositor-
Zeitraum. Diese Grenze bleibt im Profil erhalten.
