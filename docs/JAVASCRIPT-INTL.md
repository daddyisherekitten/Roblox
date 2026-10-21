# Intl-Profil

Stand: 5. Oktober 2026. `JavaScript/Intl` enthält die gemeinsame Localeauswahl,
`Intl.Locale`, `getCanonicalLocales` sowie die NumberFormat- und DateTimeFormat-
Profile. `IntlLists` und `IntlListData` ergänzen ListFormat. Der genaue Umfang,
die Datenversionen, Zeitzonengrenzen und nativen Nachweise sind in
[Text, URL, Datum und Intl](JAVASCRIPT-TEXT-DATA-20261005.md) festgehalten. Grundlage:
[ECMA-402](https://tc39.es/ecma402/#listformat-objects).

`new Intl.ListFormat(locales, options)` bietet `format`, `formatToParts`,
`resolvedOptions` und `supportedLocalesOf`. Die verfügbaren Sprachdaten sind
US-Englisch, britisches Englisch und Deutsch; conjunction, disjunction und unit sowie long, short und
narrow besitzen eigene Muster. Localeauswahl und Kanonisierung verwenden denselben
Unterbau wie NumberFormat. Nicht unterstützte gültige Locales folgen dem
dokumentierten Fallback dieses begrenzten Profils.

Die Eingabe muss ein Iterable aus Strings sein; andere Elemente werden nicht
stillschweigend zu Strings konvertiert. Fehler und Budgets schließen den Iterator.
Leere Elemente bleiben in der formatierten Liste erhalten, erzeugen aber keine
leeren element-Parts; angrenzende literal-Parts werden zusammengeführt. Neue
Parts-/Optionsergebnisse sind unabhängig veränderbar. Konstruktorpflicht,
Brandchecks, Prototypen, Subclass-Prototypen, Deskriptoren und Optionslesereihenfolge
werden geprüft. Locale-, NumberFormat- und ListFormat-Objekte können nicht über
structuredClone übertragen werden.

Die bisherigen Nachweise enthalten 58 gemeinsame Bibliotheksfälle in Luau und nativer ECMAScript-Laufzeit,
zusätzlich derselbe Datensatz im in-app Chromium. Davon betreffen 21 zusätzliche
Fälle ListFormat: alle 18 Kombinationen von zwei Sprachen, drei Typen und drei
Stilen sowie Konvertierungen, Fehler, IteratorClose und Objektsemantik.
Vergleichsseite 07 zeigt die Ausgabe und Parts mit Sprach-/Typwechsel.

NumberFormat bietet Dezimal-, Prozent-, Währungs- und Einheitenformatierung,
bedeutende Ziffern, neun Rundungsarten, Rundungsschritte/-priorität und
wissenschaftliche, technische und kompakte Schreibweisen. Währungs-/Einheiten-
Namen und Standard-Nachkommastellen stammen aus versionierten CLDR-Referenzdaten.
DateTimeFormat bietet das gregorianische Profil mit lateinischen Ziffern für
`de-DE`, `en-US` und `en-GB`, Komponenten-/Stilformatierung, vier Stundenzyklen,
Format-Teile sowie UTC, feste Offsets und neun benannte IANA-Zonen für 1900–2100.
Die entsprechenden Date-/Number-Locale-Methoden verwenden denselben Unterbau.
Zusätzlich bestehen 30 native Text-/Daten-Vergleichsgruppen mit 4.729 Erwartungen,
einschließlich britischer ListFormat-Interpunktion.

Die vollständige Intl-Familie bleibt offen. Es gibt keine vollständigen CLDR-
Sprachdaten. Collator, PluralRules, RelativeTimeFormat, DisplayNames, Segmenter
und DurationFormat bleiben offen; auch NumberFormat und DateTimeFormat sind
begrenzte Profile mit den genannten offenen Range-/Kalender-/Datenfällen.
Listen sind auf 16.384 Elemente und 65.536 Bytes
Text begrenzt.
