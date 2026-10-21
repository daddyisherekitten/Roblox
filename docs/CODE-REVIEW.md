# Codeprüfung

## Projektprüfung nach Höhenbegrenzung und Overflow — 10. September 2026

Erneut geprüft: Parser/DOM, CSS-Auflösung und Kataloge, Block-/Wortlayout, Fontprofile,
Rendering, Lebenszyklus, Labor-/Vergleichsdemos, Browserquellen, Tests, Hilfsskripte
und alle sechs Rojo-Konfigurationen. Die 126 Schriftkatalogeinträge und lokalen
Dateiverweise wurden maschinell abgeglichen; Fontbinärdaten bleiben unverändert.

Umgesetzt:

- min-height (auto/0/px), max-height (none/0/px) sowie overflow hidden/visible.
- BlockLayout trennt Boxhöhe im Fluss und sichtbaren Überlauf. Feste/maximale Höhen
  verschieben folgende Geschwister nicht durch überlaufende Kinder. Hidden begrenzt
  auch die an die Seiten-Scrollfläche weitergereichte Ausdehnung.
- Gemeinsame Größenkonvertierung statt zweier Hilfsfunktionen pro angeordneter Box;
  gemeinsamer min/max-Parser für Breite und Höhe, mit expliziter Prozentfreigabe.
- Vererbbare CSS-Felder werden einmal aus dem unveränderlichen Katalog ausgewählt.
  Selektormatching erzeugt Deklarationslisten erst bei einem Treffer; ohne Treffer
  werden eingefrorene Leerdaten wiederverwendet. Berechnete Styles bleiben unabhängig.
- Veraltete Angaben zu div-Rahmen, Unterlinien, Demo-Größe und Höhenfluss korrigiert.
  Die vollständigen Browser-/Studio-HTML-Dokumente sind identisch (5.976 UTF-8-Bytes).

Prüfergebnis: 78 Luau-Dateien kompiliert, 5 JavaScript- und 11 HTML-Dateien geprüft,
190 lokale Referenzen gültig, 126 Schriftkatalogeinträge identisch. Vollständige
Luau-Regressionstests regulär und mit -O2, fünf Schriftformelprüfungen und sechs
Rojo-Builds bestanden. Neue Tests sichern unter anderem verschachteltes Clipping,
Minimum-vor-Maximum, Nullhöhen, Box-Sizing, Folgeelemente, Resize ohne neue Messungen
und unveränderliche leere CSS-Ergebnisse ab.

Erhalten: Fontfaktoren und historische Guide-Rundung, Unter-/Durchstrichformeln,
skip-ink-Lücken, Wort-/Graphem-Labels, individuelle Textmessungen, natives Scrollen
und Seitenabbau. Keine gemessene Studio-Beschleunigung aus den Vereinfachungen ableiten.

Grenzen: min/max-height nur in px; overflow hidden/visible für beide Achsen zusammen,
keine eigenen Scrollcontainer. ClipsDescendants schneidet rechteckig an der äußeren
Framekante, ohne abgerundeten CSS-Padding-Zuschnitt. CLI-Messungen und GUI-Ersatzobjekte
sind keine native Studio-/Browser-Sichtprüfung oder vollständige Roblox-Typprüfung.
Die neuen Beispiele müssen noch visuell in Studio beurteilt werden.

## Frühere Prüfung nach Blocksatz-Erweiterung

Geprüft am 9. September 2026. Umfang: Engine, Parser/DOM, CSS, Layout, Rendering,
Seitenlebenszyklus, Schriftprofile, Schriftlabor, Vergleichsdemos, Browser-JavaScript/CSS/HTML,
Tests, Teststarter und alle sechs Rojo-Projektdateien. Die generierten Schriftkataloge wurden
vollständig miteinander und gegen ihre lokalen Dateiverweise abgeglichen.
Font-Binärdateien und alte Messdaten wurden nicht verändert.

## Neue Funktion

`text-align: justify` dehnt normale Wortabstände gleichmäßig, nachdem der automatische
Umbruch feststeht. Letzte Zeilen, Zeilen vor `br` und Zeilen ohne dehnbare Zwischenräume
bleiben linksbündig. Einzelwort-Labels, individuelle Messungen, Grundlinien, Zeilenhöhen,
Vererbung und bestehende Ausrichtungen bleiben erhalten. Die kompakte Demo hat ein zusätzliches Beispiel.

## Behobene Fehler und Vereinfachungen

| Bereich | Befund und Änderung | Absicherung |
| --- | --- | --- |
| RenderTree | `display:none` auf einem Block beendete vorher den umliegenden Wortlauf. Der Stil wird jetzt vor dem Aufteilen geprüft und ohne doppelte Auflösung weitergereicht. | `tests/Elements.luau`: versteckter Block mitten in einem Wort und zwischen Wörtern |
| Layoutplanung | Eine während einer fehlgeschlagenen Messung eintreffende Breitenänderung konnte liegenbleiben. Der laufende Worker verarbeitet jetzt auch diesen neueren Auftrag. | `tests/PageLifecycle.luau`: Resize während Fehler, anschließende Erholung |
| Fehlerstatus | Nach erfolgreichem Layout blieb ein älteres Error-Attribut erhalten. Es wird jetzt gelöscht. | `tests/PageLifecycle.luau` |
| Diagnosen | Überzählige Render-Diagnosen wurden still abgeschnitten. Jetzt wird wie beim Parser `DiagnosticsTruncated` gesetzt. | `tests/PageLifecycle.luau`: 101 Diagnosen |
| GUI-Erzeugung | Ungültige Eigenschaften oder ein ungültiger Parent konnten eine ungebundene Instanz zurücklassen. Fehler räumen diese jetzt auf. Selectable und natives Scrollen können nicht mehr entgegen den Projektregeln überschrieben werden. | `tests/GuiFactory.luau` |
| Textmessung | Fehler beim Setzen der Messparameter passierten außerhalb der Fehlerbehandlung. Auch diese Fälle geben jetzt das Anfrageobjekt frei. | `tests/TextMeasure.luau`: Erfolg, Property-Fehler, Service-Fehler |
| CSS-Zahlen | Längen und line-height prüften Dezimalzahlen unterschiedlich. Eine gemeinsame kleine Funktion lehnt unter anderem `1.px` ab und akzeptiert gültige nichtnegative Dezimalzahlen mit optionalem Plus. | `tests/InlineStyle.luau`, `tests/LineHeight.luau` |
| Tokenizer | Ein fehlerhaftes Raw-Text-Endtag wie `</script/>` konnte folgenden Inhalt verschlucken. Es beendet jetzt den Raw-Text und behält die Diagnose. Leerraum am Eingabeende wird nicht mehr zusätzlich als ungültiges Attribut gemeldet. | `tests/HTML.luau` |
| Teststarter | Die Roblox-Ersatzwerte wurden erst als Zeichenkette erzeugt und danach mehrfach umgeschrieben. Ein direkt lesbarer Luau-Block ersetzt diese Umwege. Die vorhandenen GuideEstimates laufen zusätzlich in der CLI. | Vollständige Testsuite |

`scripts/check-project.cjs` macht die übergreifende Prüfung wiederholbar: Luau-Syntaxcompiler,
JavaScript-Syntax einschließlich eingebetteter Scripts, lokale HTML-/CSS-Verweise,
Rojo-Pfade und beide Kataloge mit 126 Schriften. Es startet weder Roblox noch einen Browser.

## Verifikation

Alle nachstehenden Prüfungen waren erfolgreich: 58 Luau-Dateien kompiliert, 5 JavaScript-
und 11 HTML-Dateien geprüft, 193 lokale Referenzen aufgelöst, 126 Schriftkatalogeinträge
abgeglichen. Alle Regressionstests, fünf Schriftformelprüfungen und sechs Rojo-Builds bestanden.

- `node scripts/run-html-tests.cjs`: bestehende Regressionstests und neue Randfälle.
- `node scripts/check-project.cjs`: sämtliche First-Party-Quellen und lokale Referenzen.
- `node scripts/check-guide-model.cjs` für Arial, Ubuntu, Roboto, Inter und OpenSans.
- Rojo-Builds für default, engine, htmlpage, fontlab, fontcomparison und parser.

## Verbleibende Grenzen

Die Prüfung ist kein Nachweis vollständiger Fehlerfreiheit. Die CLI ersetzt Roblox-Werte und
Textmessungen durch kontrollierte Testobjekte; Syntaxkompilierung ist keine vollständige
Roblox-Typprüfung. Native Textdarstellung, Inter-Laden, Scrollgefühl und Klicks müssen weiterhin
in Studio beziehungsweise im Browser visuell geprüft werden. Es wurde keine neue visuelle Abnahme durchgeführt.

Bekannte Funktionsgrenzen bleiben dokumentiert: angenäherte Fontmetriken, Teilwortformatierung,
leere Inline-Boxen, links überlaufender Text bei center/right, fehlende Silbentrennung und RTL,
noch kein reaktives DOM/Dirty-System. Das Schriftlabor hat weiterhin seine bewussten Grenzen
bei Klickrouting und Messbereich. Die vorhandenen Fontfaktoren und historischen Rundungskonventionen
wurden nicht vereinheitlicht, da dies bestätigte Messergebnisse verändern könnte.

## Ergänzung vom 10. September: Standard-HTML und style-Regeln

Das vollständige Dokument im LocalScript entspricht der Browserdatei. Ein kurzer Google-Fonts-Link
ersetzt die eingebetteten Fontbinärdaten; die sichtbaren Beispiele bleiben kompakt. Der Synchronisierer
benötigt nur Python. Die Tests prüfen Dokumentgleichheit, Google-Fontfamilien und die kompakte Dateigröße.

Der Renderer verarbeitet style-Blöcke mit Selektoren, Spezifität, Reihenfolge, !important und Vererbung.
Der HTML-Baum bleibt unverändert. Tests decken das originale Inter-Beispiel, Inline-Vorrang, ungültige
Werte, Prozent-Zeilenhöhen, versteckte Blöcke und das Überspringen nicht unterstützter CSS-Regeln ab.
Die Engine lädt keine externen Stylesheets oder Fontdateien; bekannte Familien verwenden Roblox-Assets.
Eine direkte visuelle Browser-/Studio-Prüfung wurde für diese Änderung nicht durchgeführt.

## Ergänzung: Gewicht 400/700

font-weight, h1/h2/b/strong sind mit Regular/Bold ergänzt. FontFace und Textmessung verwenden dasselbe
Gewicht; die getrennten Messschlüssel für Wort und Leerraum verhindern veraltete Breiten bei Gewichtswechseln.
Tests prüfen Vererbung, CSS-Overrides, ungültige Werte, Teilwortdiagnosen, Enum-/Asset-Familien und Umbruch.
Die bisherigen Kalibrierungen bleiben erhalten; Bold-Linien und Größenfaktoren sind noch Näherungen aus Regular.
Native visuelle Abnahme bleibt offen. Konstruktorgrundlage:
[Roblox Font API](https://create.roblox.com/docs/reference/engine/datatypes/Font).

## Ergänzung: Kursiv

font-style normal/italic und i/em sind einschließlich Fett-Kursiv ergänzt. Wort- und Leerzeichenmessung
verwenden den jeweiligen Stil, mit unabhängigen Messschlüsseln. Die Tests sichern Standardwerte,
CSS-Overrides, Vererbung, Enum-Kompatibilität, kombinierte Schnitte, Umbruch und Teilwortdiagnosen ab.
Der Google-Fonts-Link fordert alle vier Schnitte an; das komplette HTML bleibt im Skript identisch.
Kursiv nutzt die bestehenden Regular-Linien als Näherung. Eine native visuelle Abnahme steht aus.
