# Dokumentation der HTML Engine

Hier beginnt die fachliche Orientierung. Bedienung steht in der
[Projekt-README](../README.md), gemeinsame Arbeitsregeln im [Plan](../PLAN.md),
Modulverantwortung in der [Architektur](ARCHITECTURE.md).
Funktionsumfang und offene Grenzen werden bei ihrem jeweiligen Fachbereich gepflegt.

Aktueller Formularvergleich: [Datum-/Zeit-Picker, Dateibutton und Bild-Submitter](HTML-INPUT-TYPES-20261006.md).
Aktueller HTML-Abgleich: [Dokumentparser und Attributnachweise](HTML-PARSER-ATTRIBUTES-20261006.md),
[Attributregister mit offenen Achsen](html-attributes.v1.json).
Aktueller CSS-Abgleich: [vollständige datierte Liste mit Teilprofilen und Hostgrenzen](CSS-GAPS-20261006.md),
[CSS-Register](css-features.v1.json). Aktuelles Code-/Pfadreview:
[Gesamtprüfung vom 6. Oktober](audit-2026-10-06/README.md).

## Welche Datei wofür gilt

| Frage | Maßgebliche Übersicht | Geltung |
| --- | --- | --- |
| How is the independent browser installed and extended? | [WAYLINE](WAYLINE.md) | Native browser, host contract, Explorer mapping and server persistence |
| Welche HTML-Tags und Attribute verhalten sich korrekt? | [HTML-COMPLETION](HTML-COMPLETION.md) | Quellen und ausstehender vollständiger Attribut-/Verhaltensabgleich |
| Welche CSS-Eigenschaften und Kombinationen funktionieren? | [CSS-COMPLETION](CSS-COMPLETION.md) | Datiertes Referenzregister, Teilprofile und weiterhin offene Wirkungsnachweise |
| Welche JavaScriptfunktionen haben wir? | [JAVASCRIPT-IMPLEMENTATION](JAVASCRIPT-IMPLEMENTATION.md) | Implementierte Teilprofile, Module und konkrete Grenzen |
| Was bauen wir für JavaScript noch aus? | [JAVASCRIPT-ROADMAP](JAVASCRIPT-ROADMAP.md) | Ein detaillierter Plan P/R mit Abschlusskriterien |
| Welche APIs sind tatsächlich erreichbar? | [API-Register](JAVASCRIPT-API-REGISTER.md) | Generierter Descriptorbestand, keine Verhaltensgarantie |
| Welche SVG-Familien haben wir? | [SVG-SUPPORT](SVG-SUPPORT.md) | Datierter Bestand und Grenzen pro Etappe |
| Was ist für SVG geplant? | [SVG-PLAN](SVG-PLAN.md) | Detaillierter Fachplan S; gemeinsame Regeln bleiben in PLAN |
| Was wurde zuletzt geändert und geprüft? | [Übergabe](AI-HANDOFF.md), [Prüfprotokolle](PROJECT-REVIEW.md) | Aktueller Einstieg beziehungsweise datierte Belege |
| Wo liegt jedes Dokument und wer ist zuständig? | [Dokumentregister](documentation-index.json) | Vollständiger Dateibestand mit Rolle, Bereich und zuständiger Übersicht |

## Status richtig lesen

Aktueller CSS-Vergleich: [CSS Atelier vom 7. Oktober](CSS-ATELIER-20261007.md)
mit denselben Browser-/Roblox-Quellen, konkretem Ausbauumfang und Rest-/Hostgrenzen.

| Angabe | Bedeutung |
| --- | --- |
| Registriert oder erreichbar | Ein Name/Descriptor existiert. Verhalten und Darstellung sind damit nicht bewiesen. |
| Implementierter Teilumfang | Die im Fachprofil konkret genannten Fälle sind umgesetzt; genannte Grenzen bleiben offen. |
| Automatisch geprüft | Die angegebenen Tests zum genannten Zeitpunkt bestehen. Testquelle und Ersatzobjekte/native Umgebung benennen. |
| Vom Nutzer bestätigt | Die tatsächlich gezeigten Fälle sind bestätigt; keine pauschale Bestätigung aller Kombinationen. |
| Hostabhängig | Assetrechte, APIs, Konfiguration oder persistenter/nativer Nachweis erforderlich. |
| Offen | Noch zu implementieren oder zu untersuchen; keine Aussage prinzipieller Unmöglichkeit. |
| Historisch oder abzugleichen | Früherer Status bleibt erhalten und muss vor einer aktuellen Aussage mit Code/neuerem Fachprofil verglichen werden. |

Stand der Neuordnung: 6. Oktober 2026. HTML-/CSS-Katalogstatus und frühere
Abschlusslisten sind teilweise überholt. Die Neuordnung ist kein neuer
vollständiger Standardaudit. `scoped-not-reaudited` im Dokumentregister bedeutet:
Fachprofil erhalten und zugeordnet, bei dieser Neuordnung nicht vollständig
gegen aktuellen Code und Standard neu geprüft. Historische Fachpläne und
S-Etappenprotokolle bleiben zum Nachschlagen erhalten.
`scoped-reviewed` bedeutet eine aktuelle Prüfung des ausdrücklich genannten
Teilumfangs; daraus folgt keine vollständige Kategorie oder Browserkonformität.

## Dokumentation pflegen

Eine Information an ihrer zuständigen Stelle ändern; README, PLAN und Übergabe
verlinken Detailstatus, statt ihn nochmals zu kopieren. Engere neue Profile
präzisieren nur die untersuchte Familie. Datum, Quellen, echte Restpunkte und
Prüfnachweise zusammen pflegen. Beim Auflösen widersprüchlicher Altangaben deren
historischen Inhalt und Entscheidung erhalten.

Neue Dokumente im [Dokumentregister](documentation-index.json) mit `path`,
`title`, `domain`, `kind`, `assessment` und `owner` eintragen. `owner` verweist
auf die maßgebliche Bereichsübersicht; dies ist keine personenbezogene Zuständigkeit.
Neue lokale Links und neue maßgebliche Seiten müssen ohne historische Ausnahme
auflösbar sein. Vorhandene historische fehlende Ziele sind einzeln im Register
markiert und bedeuten keine bestandene Funktionsprüfung.

```powershell
python scripts/check-documentation.py
node scripts/check-project.cjs
```

Der Dokumentationscheck ist Teil der Projektprüfung. Er kontrolliert vollständige
Zuordnung, Pfade, lokale Markdownziele/Überschriften und die Originalprüfsummen.
Die [Archivübersicht](history/2026-10-06/README.md) erklärt Sicherung und Wiederherstellung.
Historische Checkboxen und Reihenfolgen werden nicht als aktuelle Aufträge übernommen.

## Messwerte und Regressionstestdaten

Die Schriftmessungen, Faktoren, Linienmodelle und früheren Messberichte bleiben
unter [measurements](../measurements). Dort liegen Rohdaten und Kalibrierungsbelege,
keine zweite aktive Planung. Das tatsächlich verwendete Schriftmodell steht in
[FontProfiles](../src/HTMLEngine/Layout/FontProfiles/init.luau); die Messdaten werden
bei dieser Neuordnung nicht verändert oder neu berechnet.

[tests/fixtures](../tests/fixtures) enthält Testdaten und die Quellen früherer
sichtbarer Seiten. Diese Daten bleiben getrennt von aktiven Websites und
Funktionsplänen. Das Dokumentregister erfasst README/PLAN und `docs` einzeln;
diese zusätzlichen Datensammlungen sind darin als Nachweisverzeichnisse zugeordnet.

## Fachprofile und erhaltene Detaildokumente

### HTML und Dokumente

- [Dokumentkopf und Metadaten](DOCUMENT-METADATA.md)
- [HTML-Grundparser: aktueller Umfang](HTML-SUPPORT.md) (historischer Sammelumfang, abzugleichen)
- [Links und Website-Adressen](LINKS.md)
- [Trennlinie, Hervorhebung, Hoch-/Tiefstellung und letzte Zeile](SMALL-ELEMENTS.md)

### Eingabe und Formulare

- [Mauszeiger](CURSORS.md)
- [Aufklappbare Bereiche](DETAILS.md)
- [Dialoge](DIALOG.md)
- [Formulare und Eingabe – erster Teilumfang](FORMS.md)
- [Selected content](SELECTED-CONTENT.md)

### CSS und Layout

- [aspect-ratio](ASPECT-RATIO.md)
- [Diagonale Rahmenübergänge](BORDER-CORNERS.md)
- [Einzelne Rahmenkanten](BORDER-SIDES.md)
- [Kartenschatten](BOX-SHADOW.md)
- [Farben und Transparenz](COLORS.md)
- [CSS-Hintergrundbilder](CSS-BACKGROUNDS.md)
- [CSS-Erweiterungsplan](CSS-EXPANSION-ROADMAP.md) (historischer Ausbauplan)
- [Die sechs abschließenden CSS-Blöcke](CSS-FINAL-BLOCKS.md) (historischer Sammelumfang, abzugleichen)
- [CSS-Übergänge und Animationen](CSS-MOTION.md)
- [CSS-Transformationen in 2D und 3D](CSS-TRANSFORMS.md)
- [Flächen, Masken, Rahmen und Schatten](CSS-VISUAL-LIMITS.md)
- [Flexbox: Ausrichtung und flexible Größen](FLEXBOX.md)
- [Listenformate und Textdekoration](LIST-DECORATION-EXTENSIONS.md)
- [Ergänzungen mit mittlerem Aufwand](MEDIUM-ADDITIONS.md) (historischer Sammelumfang, abzugleichen)
- [Outline](OUTLINE.md)
- [Positionierung](POSITIONING.md)
- [Scrollbereiche innerhalb der Seite](SCROLLING.md)
- [Kleine HTML-/CSS-Ergänzungen](SIMPLE-FEATURES.md) (historischer Sammelumfang, abzugleichen)
- [Kleine Ergänzungen: Alias, 3D-Rahmen, HSL und HTML-Blöcke](SMALL-ADDITIONS.md) (historischer Sammelumfang, abzugleichen)
- [Tabellen: unterstützter Teilumfang](TABLES.md)
- [Sichtbarkeit](VISIBILITY.md)

### Schriften und Text

- [Roblox-Schriften: Recherche und Vergleichstest](FONT-RESEARCH.md)
- [overflow-wrap](OVERFLOW-WRAP.md)
- [CSS-Längen, Viewport-Einheiten und Berechnungen](RELATIVE-LENGTHS.md)
- [Roboto in der HTML-Engine](ROBOTO.md)
- [Text-overflow](TEXT-OVERFLOW.md)
- [Textschatten](TEXT-SHADOW.md)

### Bilder Grafik und Medien

- [Canvas 2D](CANVAS.md)
- [Eingebettete Dokumente](IFRAMES.md)
- [Bildfilter](IMAGE-FILTERS.md)
- [Bildquellen](IMAGES.md)
- [Audio, Video und WebVTT](MEDIA.md)

### Layoutarbeit Laden und Lebenszyklus

- [Dirty-Layout: zweite Stufe](DIRTY-LAYOUT.md)
- [Schnellerer Seitenaufbau](LOADING-PERFORMANCE.md)

### JavaScript und Browser APIs

- [Animation.commitStyles](JAVASCRIPT-ANIMATION-COMMIT.md)
- [WAAPI: Layoutwerte und zusammengesetzte Effekte](JAVASCRIPT-ANIMATION-LAYOUT.md)
- [JavaScript API- und Statusregister](JAVASCRIPT-API-REGISTER.md)
- [JavaScript-Audio · 6. Oktober 2026](JAVASCRIPT-AUDIO-20261006.md)
- [Shadow DOM and custom elements](JAVASCRIPT-COMPONENTS.md)
- [CSSOM, Verschachtelung und Animationen: Ausbau vom 5. Oktober 2026](JAVASCRIPT-CSS-ANIMATIONS-20261005.md)
- [CSSOM: Stylesheets und Regeln](JAVASCRIPT-CSSOM.md)
- [R02: Dokumente, DOM-Interfaces und dynamische Tabellen](JAVASCRIPT-DOCUMENTS-R02.md)
- [DOM, Eingaben und CSS: Vergleich 08](JAVASCRIPT-DOM-CSS-EXTENSIONS.md)
- [R04: Native contenteditable profile](JAVASCRIPT-EDITING-R04.md)
- [Browser-Grundlagen: Ausbau und Bestand](JAVASCRIPT-FOUNDATIONS-20261005.md)
- [Roblox-Hostprofil](JAVASCRIPT-HOST-CAPABILITIES.md)
- [R04: Auswahl, Eingaben und native Geometrie](JAVASCRIPT-INPUT-R04.md)
- [Intl-Profil](JAVASCRIPT-INTL.md)
- [JavaScript: Skript-, Bild- und Fontladen](JAVASCRIPT-LOADING-20261005.md)
- [JavaScript: User Timing und PerformanceObserver](JAVASCRIPT-PERFORMANCE.md)
- [Pointer Capture, Touch und native Texteingabe](JAVASCRIPT-POINTER-TOUCH-INPUT.md)
- [Pseudo computed content](JAVASCRIPT-PSEUDO-COMPUTED-CONTENT.md)
- [R01: Sprache und gemeinsames Objektmodell](JAVASCRIPT-R01-CORE.md)
- [Range und Selection · Vergleich 03](JAVASCRIPT-RANGE-SELECTION.md)
- [Dynamische Skripte](JAVASCRIPT-SCRIPTS.md)
- [Web Storage und Roblox-Persistenz](JAVASCRIPT-STORAGE.md)
- [Dynamische Tabellen](JAVASCRIPT-TABLES.md)
- [Textauswahl in Eingabefeldern](JAVASCRIPT-TEXT-CONTROLS.md)
- [JavaScript: Text, URL, Datum und Intl – Stand 5. Oktober 2026](JAVASCRIPT-TEXT-DATA-20261005.md)
- [JavaScript: Dialoge und Popover](JAVASCRIPT-TOP-LAYER.md)
- [Dedicated Worker](JAVASCRIPT-WORKERS.md)

### Websitequellen und Demos

- [Website-Seiten](WEBSITES.md)

### SVG

- [SVG-Performance-Review — 20.09.2026](SVG-PERFORMANCE-REVIEW.md)
- [SVG: geplanter Einstieg](SVG.md)

Die einzelnen S01–S45-Protokolle sind vollständig im [SVG-Plan](SVG-PLAN.md)
und im [Dokumentregister](documentation-index.json) auffindbar. Ihre alten
Statusmeldungen bleiben datierte Etappennachweise.

### Historische Audits und Sammeltexte

- [Prüfprotokolle und Auditverweise](PROJECT-REVIEW.md)
- [Vollständige Originale und Sicherungsnachweis](history/2026-10-06/README.md)
- [September-Abdeckungsprüfung](AUDIT-COVERAGE-2026-09-21.md)
- [September-Layoutprüfung](AUDIT-LAYOUT-2026-09-21.md)
- [September-Lifecycleprüfung](AUDIT-LIFECYCLE-2026-09-21.md)
- [September-Renderingprüfung](AUDIT-RENDERING-2026-09-21.md)
- [September-Stresstest](STRESS-TEST-2026-09-21.md)
- [Frühe Codeprüfung](CODE-REVIEW.md)
