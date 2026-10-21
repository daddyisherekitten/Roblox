# S02 — SVG-Dokumentstruktur

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Status: implementiert, automatisierte Prüfung bestanden; Nutzervergleich am 13.09.2026 bestätigt ("sieht gut aus weiter").
Clientbericht: Width=480, UIScale=1, Viewport=1319×619, Created=Live=Peak=6,
Destroyed=0, Cycles=1, PixelReadback=true. Erwartete Diagnose: mismatched-end-tag
für S02-invalid bei Position 131. Separate Größen-/R-Abnahmen nicht berichtet.
S01 bleibt bestätigt und über seine bisherigen Dateien erreichbar.

## Vergleich

Browser: [S02-Tafel](../tests/fixtures/svg-regressions.zip).
Studio: `ActiveDemo = "SVGLab"`, `SVGStage = "S02"` in StudioDemoConfig,
dann Stop → Play. Tasten 1/2/3 und R funktionieren wie in S01.

1. Oben drei ineinander liegende Rechtecke: außen Rot, mittig Blau, innen Grün.
   Drei verschachtelte Gruppen enthalten die sichtbaren Elemente. Die innere
   Gruppe und ihr Rechteck verwenden ein explizites SVG-Namensraumpräfix.
2. Die magentafarbene Vollfläche aus defs bleibt unsichtbar. title, desc und
   metadata erscheinen nicht als Grafik oder zusätzlicher Seitentext.
3. Zweite Tafel: nur Schachbrett, darunter eine ausdrücklich erwartete XML-
   Fehlermeldung. Das falsch geschlossene Dokument wird vollständig verworfen.
4. Dritte Tafel: ein grünes Rechteck. Der gültige Nachbar bleibt vom Fehler
   unberührt. Sein Dokument wird separat geparst.

Browser und Roblox erhalten exakt dieselben drei SVG-Quellstrings. Der Browser
verwendet DOMParser mit `image/svg+xml`, damit sein HTML-Parser den absichtlichen
XML-Fehler nicht automatisch repariert. Formulierung und Byteposition der
Browserdiagnose müssen nicht der Luau-Diagnose entsprechen; Fehlererkennung,
leere zweite Tafel und gültiger Nachbar müssen übereinstimmen.

Bei 480px liegen die Rechteckkanten bei 24/64/104 und 456/416/376 px; die Farben
sind #e53935, #1e88e5, #43a047. Achsenkanten und Flächenfarben müssen exakt passen.
Die Tafeln verwenden denselben 16-Pixel-Schachbrett-Hintergrund wie S01.

## Tatsächlicher Engine-Code

- `src/HTMLEngine/SVG/XML.luau`: UTF-8 XML-1.0-Scanner, Unicode-Namen, qualifizierte
  Namen, quoted attributes, Kommentare, CDATA, vordefinierte/numerische Entities,
  XML-Deklaration und Diagnosepositionen in normalisierten UTF-8-Bytes.
- `src/HTMLEngine/SVG/Parser.luau`: eigener SVG-Dokumentbaum auf dem vorhandenen
  DOM.Node-Modell, namespace scopes, NamespaceURI/QualifiedName, unveränderte
  Attributnamen, ExpandedAttributes und ID-Index. Unpräfixierte Attribute bleiben
  ohne Namensraum. Präfixe sind in ihrem jeweiligen Elternbereich gültig.
- `examples/SVGLab/Structure.luau`: Beobachtungsadapter. Er traversiert diesen
  echten Laufzeitbaum und übergibt die wenigen Testrechtecke an das S01-Raster.
  Er implementiert noch keine allgemeine SVG-Geometrie, CSS-Cascade, Transformationen,
  viewBox-Anordnung oder HTML-Einbettung. Das gehört zu den folgenden Etappen.
- `scripts/sync-svg-structure.py`: kopiert nur SVG-Quellstrings und erzeugt die
  Browser-Testhülle. Anders als beim S01-Prototyp werden keine Formen vorgeparst.

API: `Parser.parse(source, options?)` liefert ein Document mit `Valid`, `Root`,
`Ids`, `Children` und `Diagnostics`. Bei einem fatalen Fehler gilt Valid=false,
Root=nil, und Baum/ID-Index sind leer. Doppelte IDs sind eine Warnung; der Index
behält das erste Element. Fremde Namespace-Inhalte bleiben im DOM erhalten,
werden im S02-Beobachtungsadapter aber nicht als SVG-Formen interpretiert.
Metadaten/Definitionen bleiben im DOM auffindbar, auch wenn sie nicht gezeichnet werden.

## Abgegrenzter Teilumfang

Eigenständige SVG-Dokumente brauchen ihren SVG-Namensraum. Die Option Inline=true
setzt lediglich den anfänglichen SVG-Namensraum; sie schaltet **keine** HTML-
Fehlerkorrektur oder HTML-SVG-Integration frei. Groß-/Kleinschreibung bleibt exakt.
DTD/Entity-Deklarationen werden ausdrücklich abgelehnt. XML 1.0 mit UTF-8 wird
unterstützt; andere Encodings/Versionen bekommen eine Diagnose. Processing
Instructions bleiben inert und werden mit Warnung gespeichert; es wird keine
Datei geladen und kein Skript ausgeführt. Vollständige SVG-Attributvalidierung
und Darstellungseigenschaften folgen den jeweiligen Funktionsetappen.

Standardbudgets: 1 MiB Quelle, 20.000 Knoten, Tiefe 128, 256 Attribute pro Element,
100 Diagnosen. Ungültige Optionswerte sind API-Fehler. Ein fataler Parsefehler
bleibt auch bei ausgeschöpftem Diagnosebudget sichtbar. Namensraumbereiche teilen
Elternbindungen über explizite Verweise mit iterativer Suche, ohne Kopieren aller
Bindings und ohne Luau-__index-Kettenlimit.

## Prüfung und offene Abnahme

`tests/SVGStructure.luau` prüft Unicode/UTF-8, XML-Großschreibung, Namespace-Scope,
Attribute mit gleichem expandiertem Namen, Entity-Decodierung, CDATA, ID-Suche,
falsche End-Tags, Limits einschließlich Tiefe 128 und isolierte Fehler. Der reale
DOM→Beobachtungsadapter→Raster-Pfad wird anhand der erwarteten Farben geprüft.
Der Lab-Controller läuft mit S01 und S02 durch Größenwechsel, 20 Lebenszyklen,
Abbruch und Cleanup-Tests; GUI/EditableImage dabei lokal gemockt.

Kommandos: `python scripts/sync-svg-structure.py --check`,
`node scripts/run-svg-tests.cjs` (auch `--optimized`), bestehende HTML-Suite,
Projektprüfung und default/svg-lab/htmlpage Rojo-Builds.
S02 hat im fertigen Zustand sechs lebende EditableImages, nach vollständigem
Abbau null. `SVG_S02_REPORT` enthält die erwartete Dokumentdiagnose separat von
Fehlern beim Aufbau der Testansicht.

- [x] Drei Rechtecke, kein Magenta, keine Metadaten als Grafik.
- [x] Leere Fehlertafel mit Diagnose und weiterhin sichtbarer grüner Nachbar.
- [ ] Drei Vergleichsgrößen sowie R-Test in Studio geprüft.

Referenzen: [SVG-Struktur](https://www.w3.org/TR/SVG2/struct.html),
[XML-Namensräume](https://www.w3.org/TR/xml-names/),
[XML 1.0](https://www.w3.org/TR/xml/).
