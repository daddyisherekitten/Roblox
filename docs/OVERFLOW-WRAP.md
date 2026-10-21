# Wortumbrüche und Silbentrennung

Stand: 9. Oktober 2026. Sprach-/Renderingpfad für C06; der Gesamtabschluss
bleibt im bestehenden [CSS-Abschlussdokument](CSS-COMPLETION.md).

## Verhalten

`overflow-wrap: normal | break-word | anywhere` und `word-break: normal |
break-all | break-word` werden vererbt. Ein Wort, das auf die nächste Zeile passt, bleibt bei
Notumbrüchen ganz. Ein sonst überlaufendes Wort wird an Graphemgrenzen zerlegt,
ohne Bindestrich. `anywhere` und `break-all` wirken auch bei Min-Content-Proben;
`break-word` erzeugt dort keine zusätzlichen Umbruchstellen.
`line-break:anywhere` verwendet denselben Graphempfad. `white-space:nowrap` und
`pre` verhindern diese Umbrüche. Bilder werden nicht geteilt.

## Kompatibler Wortumbruch und Liveänderungen · 18. Oktober 2026

`word-break:break-word` behält seinen berechneten Wert; seine Wirkung entspricht
`word-break:normal` zusammen mit `overflow-wrap:anywhere`, unabhängig vom
tatsächlichen `overflow-wrap`-Wert. Diese Notumbrüche beeinflussen auch
Min-Content-Maße. Klassen-, Hover- und CSSOM-Änderungen an beiden Eigenschaften
fordern nun das tatsächlich nötige Layout an. Ändert sich eine Stilgrenze in
einem zuvor zusammengeführten Inlinewort, verwendet der bestehende Klassifikator
die passende lokale Neuaufteilung; unveränderte Wort-/Box-/Control-GUIs bleiben
erhalten.

Die [Chromium-155-Referenz](../tests/fixtures/word-break-browser.json) umfasst
135 konkrete Kombinationen von Inhalt, Inlinegrenzen, Breite, `word-break` und
`overflow-wrap`. `WordBreak` vergleicht Zeilen, Min-/Max-Content und berechnete
Werte und ergänzt Grammatik, Vererbung, Grapheme, Spacing, Dekoration, Resize
und lebende Stilwechsel. Der [enge Reviewbeleg](../build/engine-expansion-20261018/word-break-report.md)
hält Rot-/Grünnachweise und Grenzen fest. Grundlage sind die im eingefrorenen
CSS-Referenzbestand zugeordneten [CSS-Text-3](https://drafts.csswg.org/css-text-3/#word-break-property)-
und [CSS-Text-4](https://drafts.csswg.org/css-text-4/#word-break-property)-Verträge.
Dies schließt weder sämtliche `word-break`-Werte noch allgemeine CJK-/Unicode-
Zeilenbruchalgorithmen oder native Studio-Glyphen-/Pixelabnahme ab.

## Silbentrennung

Seit dem 18. Oktober repartitionieren lebende Änderungen an `hyphens`,
`hyphenate-character` und `hyphenate-limit-chars` auch zuvor zusammengeführte
Inlinewörter. Änderungen an `line-break`, `text-autospace` und
`hanging-punctuation` erneuern die tatsächlich betroffenen Tokenflags und
Stilgrenzen. Die erweiterten `Hyphenation`-Fälle und `InlineTextMutation`
vergleichen Setzen/Entfernen über Stil, Klasse und Hover mit einem frisch
aufgebauten identischen Baum, einschließlich Zeilen, Positionen, Maßen und
unveränderten Controls. Der [gemeinsame Textreview](../build/engine-expansion-20261018/text-expansion-report.md)
hält die einzelnen Rot-/Grünbelege und den abgegrenzten Umfang fest. Die neuen
Invalidierungen behaupten keine zusätzlichen Sprach-, CJK- oder Glyphenalgorithmen.

`hyphens:none` unterdrückt bedingte und automatische Trennstellen. `manual`
verwendet U+00AD SOFT HYPHEN (`&shy;`). Dieses Zeichen bleibt im DOM und beim
Kopieren erhalten, erscheint im ungetrennten Wort aber nicht. Nur beim
gewählten Umbruch erscheint die Trennzeichenfolge. `auto` ergänzt tatsächliche
sprachabhängige Muster; unbekannte Sprache oder fehlende passende Ressource
erzeugen keine automatischen Trennstellen. Es gibt keinen Rückfall auf beliebige
Buchstabengrenzen mit angehängtem Bindestrich.

Ein `lang`-/`xml:lang`-Attribut, eine vererbte Sprache, eine Shadow-Host-Sprache
oder die Dokumentvorgabe bestimmt die Ressource über `CSS/LanguageRange`.
Leeres `lang` stoppt die Vererbung. Groß-/Kleinschreibung von Sprachkennzeichen
beeinflusst die Auswahl nicht. Explizite Script-Subtags müssen zum Schriftbestand
der Ressource passen; Private-Use-/Extension-Subtags ändern nicht versehentlich
die Schrift. Der Stil speichert für `auto` die aufgelöste Sprache als
`HyphenationLanguage`. Änderungen von `lang`-/namespaced `xml:lang`, einer
Shadow-Host-Sprache oder der Dokumentvorgabe invalidieren die betroffenen
Wortbesitzer samt Inline-Gruppierung. Die Trennstellen behalten die effektive
Sprache im eigenen Wort-Cache-Schlüssel. Eigene und leere Sprachgrenzen erhalten
ihre unabhängigen Wortobjekte; fremde Eingaben/Boxen bleiben erhalten.

Trennstellen berücksichtigen das vollständige lexikalische Wort über benachbarte
Inline-Stilgrenzen hinweg. Farben/Schriften teilen es nicht in neue Wörter.
Ein passender Wortteil darf eine bereits belegte Zeile füllen; ein Umbruch am
Inline-Ende behält dessen Stil und Abschlusskante. Explizite SHY-Stellen haben
Vorrang. Wenn ein nach SHY verbleibender Abschnitt schon eine leere Zeile
überläuft, darf `auto` zusätzliche Musterstellen darin verwenden. Ein unteilbarer
Abschnitt kann überlaufen; der nächste explizite Umbruch bleibt trotzdem erhalten.

`hyphenate-character` akzeptiert CSS-Strings einschließlich leerer Zeichenfolgen
und Escapes. Der ganze String wird individuell gemessen; bei leerem String
bleibt die Trennstelle wirksam. `auto` verwendet im vorhandenen Fontprofil `-`.
`hyphenate-limit-chars` akzeptiert ein bis drei nichtnegative Integer oder `auto`
je Komponente. Automatische Trennstellen beachten Mindestwortlänge, Vorder- und
Hinterteil; fehlende zweite Komponente bedeutet `auto`, fehlende dritte übernimmt
die zweite. Der UA-Ersatz für `auto` ist 5/2/2, zusätzlich gelten die sprachlichen
Ressourcenminima. Nichtspacing-Zeichen und Wortinterpunktion erhöhen die verwendete
Buchstabenzahl nicht. Explizite SHY-Stellen bleiben wie im erfassten Chromium
unabhängig von diesen automatischen Mindestwerten.

```html
<p lang="de" style="max-width:230px;hyphens:auto;hyphenate-limit-chars:auto 2 3">
  Eine außergewöhnliche Gestaltungsidee braucht eine passende Silbentrennung.
</p>
<p style="width:120px;hyphens:manual;hyphenate-character:'~'">
  hy&shy;phen&shy;ation
</p>
```

## Ressourcen, Herkunft und Speicher

17 eingefrorene Ressourcen mit 168.272 Mustern decken folgende Sprachbestände ab:
Afrikaans (`af`), Dänisch (`da`), Deutsch (`de`, moderne Rechtschreibung, zusätzlich
`de-1901` und `de-CH-1901`), Englisch (US-/britische Schreibweisen), Estnisch
(`et`), Französisch (`fr`), Italienisch (`it`), Litauisch (`lt`), Niederländisch
(`nl`), Polnisch (`pl`), Portugiesisch (`pt`), Slowenisch (`sl`), Spanisch (`es`)
und Ukrainisch (`uk`, kyrillisch). Andere Sprachen besitzen derzeit keine
automatische Ressource; manuelle SHY-Umbrüche funktionieren weiterhin.

Quellen sind die UTF-8-Muster von [tex-hyphen](https://github.com/hyphenation/tex-hyphen/tree/5684c0f51c0b81133db2efbe60a408b4155a3ff5),
eingefroren auf Commit `5684c0f51c0b81133db2efbe60a408b4155a3ff5`.
Die Quellen erlauben Weiterverteilung (MIT, bei Dual-Lizenzen gewählt; BSD für
Portugiesisch; eigene permissive Lizenz für US-Englisch). Originalquellen bleiben
unter `scripts/data/hyphenation` erhalten. Copyright-/Lizenzhinweise stehen
vollständig in den erzeugten Modulen; `manifest.json` hält Quellpfade, Revision,
Anzahl und SHA-256 fest. `python scripts/generate-hyphenation.py` erzeugt daraus
reproduzierbar die Luau-Daten; `--download` aktualisiert nur diese feste Revision.

`Layout/Hyphenation` wählt nur die benötigte Sprachressource aus. Das Laden einer
Ressource zerlegt keine Muster. Gewichtete Liang-Muster werden nach den ersten
ein bis zwei Buchstaben in bei Bedarf gelesene Buckets zerlegt. Der gemeinsame
Cache ist auf 64 unveränderliche sprachliche Buckets begrenzt; es gibt keinen
globalen Wort-/Textmaßcache. Die 279 kleinen Graphemabbildungen normalisieren
passende Großbuchstaben und kanonisch zerlegte Buchstaben für die Muster, ohne
den angezeigten Text oder seine Quellindizes umzuschreiben. Musteraufbau und
Wortprüfung benutzen `WorkContext`-Checkpoints.

Originalwortobjekte und normale Labels bleiben erhalten. Teilstringmaße werden
individuell pro Wort/Font/Größe/Spacing gespeichert, begrenzt auf 256 Einträge.
Fragmentlabels werden bei Resize wiederverwendet und überzählige ausgeblendet.
Sobald das Wort ganz passt, erscheint sein ursprüngliches Label. Bei
`letter-spacing` bleiben Wort-Frames samt Treffer-/Textregistrierung erhalten;
nur geänderte Graphemlabels werden ergänzt/entfernt. Wiederholte Größenwechsel
sammeln keine zerstörten Wortobjekte in `TextItems` an. Seitenlöschung während
einer Messung erzeugt keine weiteren Fragment-GUIs.

## Quellindizes und Nachweise

`InlineWords` entfernt SHY nur aus der Darstellung. Sichtbare Zeichen behalten
DOM-UTF-16-Spannen; versteckte Zeichen besitzen `SourceHiddenSpans`. Ein sichtbares
manuelles Trennzeichen verweist auf seinen SHY-Quellbereich. Automatische
Trennzeichen haben keinen erfundenen DOM-Index. `ScriptSelection` kopiert den
ursprünglichen SHY und erzeugt für einen unsichtbaren SHY-Auswahlbereich eine
Nullbreitengeometrie. Automatische Suffixe werden beim Kopieren nicht ergänzt.
`TextSelection` ordnet die unsichtbare Grenze dem ursprünglichen Offset zu.

`tests/Hyphenation.luau` prüft sprachliche Trennstellen, alle 14 Ressourcenfamilien,
unbekannte Sprache, Script-/Private-Use-Auswahl, kanonische Grapheme, Wortlimits,
SHY-Priorität/Overflow, komplette/leere Suffixe, Inline-Stilgrenzen, Belegung einer
vorhandenen Zeile und GUI-/Messwertwiederverwendung. 40 wechselnde Anordnungen
behalten registrierte Wort-Frames und eine konstante `TextItems`-Anzahl.
Die echte `ApplyDOMChanges`-/Recascade-Verbindung prüft bekannt → unbekannt →
bekannt, Wiederherstellung von Inline-Sprachgrenzen, eigene/leer gesetzte Sprache,
namespaced `xml:lang`, eingefügte Meta-Sprachvorgaben und Shadow-Host-Änderungen.
Eine Änderung am bereits verarbeiteten Meta-Element ändert die Dokumentvorgabe
wie im vorhandenen Dokumentprofil nicht rückwirkend. Die Kontrollen und
unabhängigen Sprachzweige behalten dabei ihre bestehenden GUI-/Wortobjekte.
`tests/ScriptSelection.luau` prüft Kopieren, Teilauswahl, UTF-16-Offsets und
unsichtbare Geometrie.

`scripts/capture-hyphenation-reference.cjs` erfasst im isolierten Chromium
90 Layoutfälle, drei Suffixe und sechs Limit-Grammatiken nach
`tests/fixtures/hyphenation-browser.json`. Der Engine-Vergleich prüft **60**
`manual`-/`none`-Layouts anhand der ursprünglichen Zeichen-/Zeilengrenzen.
Dieser Chromium-Host besitzt für die geprüften englischen/deutschen Wörter
keine wirksame automatische Trennressource. Die übrigen 30 `auto`-Aufnahmen bleiben
roh erhalten, sind aber kein Gleichheitsnachweis unserer zusätzlichen Ressourcen.
Der Host lehnt 0 ab; die eingefrorene CSS-Text-4-Grammatik erlaubt nichtnegative
Integer. Diese normative Abweichung wird nicht als Browsergleichheit ausgegeben.

Geprüft am 9. Oktober: `Hyphenation`, `OverflowWrap`, `MediumAdditions`,
`TextTransform`, `CSSExpansion`, `FeasibleVisuals` und
`node scripts/test-script-selection.cjs` bestanden. Native Roblox-Pixel-/Font-
und FPS-Abnahme steht aus.

## Weitere Anforderungen und Grenzen

Dieses Profil ersetzt keinen vollständigen Unicode-Zeilenumbruchalgorithmus.
`keep-all`, `auto-phrase` und vollständige linguistische Wortgrenzen sind nicht
hiermit zugesichert. Vollständige vertikale Silbentrennung, schwierige
Fragment-/Schreibmodus-/Schriftformungskombinationen und sprachabhängige
Schreibänderungen beim Trennen (z.B. niederländische Sonderfälle) bleiben offen.
Die TeX-Ressourcen selbst können sprachliche Ausnahmefälle enthalten; ihr Ergebnis
ist keine Zusage jeder Wörterbuchqualität oder einer bestimmten OS-Browser-
Wörterbuchversion.

Automatische Musterprüfung begrenzt ein Wort auf 4.096 UTF-8-Bytes und 256
Grapheme je zusammenhängendem Alphabetabschnitt. Längere Wörter bekommen keine
erfundenen automatischen Stellen; explizite und separat eingeschaltete
Notumbrüche bleiben verfügbar. Dies ist ein begrenztes UA-Ressourcenprofil,
keine nachgewiesene technische Unmöglichkeit weiterer Wörterbücher.
`hyphenate-limit-zone`, `hyphenate-limit-lines` und `hyphenate-limit-last` sind
mit dieser Änderung nicht umgesetzt. Vollständige Layout-/Intrinsic-/Bidi-
Kombinationen bleiben in ihren bestehenden Fachprofilen offen.

Grundlagen: [CSS Text 3 – overflow-wrap](https://www.w3.org/TR/css-text-3/#overflow-wrap-property),
[CSS Text 4, 14. August 2026 – Hyphenation](https://www.w3.org/TR/2026/WD-css-text-4-20260814/#hyphenation).
