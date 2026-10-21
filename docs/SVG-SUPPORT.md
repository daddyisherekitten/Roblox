# SVG-Supportübersicht

## Entferntes Vergleichslabor — 14. Oktober 2026

`SVGLabDemo`, das eigenständige SVGLab-Modul, seine Browserseiten, Generatoren
und sein Rojo-Projekt sind auf Nutzerwunsch entfernt. SVG in der HTML-Engine
bleibt erhalten. Die folgenden Etappenangaben und Laborbedienungen dokumentieren
historische Prüfungen; sie sind keine aktuellen Startanweisungen.
Die bisherigen 342 Quell-/Test-/Ressourcendateien sind bytegleich im nicht
ausgelieferten [Regressionsarchiv](../tests/fixtures/svg-regressions.zip) erhalten.
[svg-fixtures.cjs](../scripts/svg-fixtures.cjs) liest sie mit SHA-256-Prüfung in
den bestehenden CLI-Tests, ohne Seiten oder Labormodule wieder anzulegen.
Die Unterstützungstabelle wird durch das Entfernen der Demo nicht verändert.

> Maßgebliche SVG-Fachübersicht mit dem unten genannten Referenzdatum. Die Dokumentationsneuordnung ist kein neuer SVG-Konformitätsaudit; spätere konkrete Reparaturen stehen in ihren datierten Nachweisen. [Index](README.md), [Prüfprotokolle](PROJECT-REVIEW.md).

Stand 14.09.2026, nach Umsetzung der S45-Vergleichsbilder. Dies ist der
Implementierungsstand dieses Projekts, keine Zusage vollständiger SVG-Konformität.
S01–S44 wurden im jeweils gezeigten Teilumfang vom Nutzer zum Fortfahren
bestätigt. S45 wartet auf den visuellen Vergleich. Eine Bestätigung einzelner
Tafeln belegt keine vollständige Prüfung sämtlicher Größen, Geräte und Sonderfälle.

**Teilumfang** bedeutet implementiert und durch gezielte Tests abgedeckt;
die genauen Einschränkungen stehen in den verlinkten Etappenprotokollen.
**Offen** bedeutet noch zu implementieren oder zu untersuchen, nicht in Roblox
unmöglich. **Plattformabhängig** kennzeichnet benötigte Assets/Fontdaten/APIs.
Die Matrix ersetzt veraltete „kommt später“-Verweise zwischen frühen Protokollen;
deren konkrete, nicht später behobene Einschränkungen bleiben gültig.

## Dokument, Geometrie und Darstellung

| Etappen | Implementierter Teilumfang | Verbleibende Grenze / Nachweis |
|---|---|---|
| S01–S02 | EditableImage-Raster, Alpha/Antialiasing, Lebenszyklus; XML/Namespaces, IDs, Diagnosen | Plattformabhängige API-/Speicherfreigabe, begrenzte Dokumentgröße. Keine vollständige Geräte-/DPI-Matrix. [S01](SVG-S01.md), [S02](SVG-S02.md). |
| S03–S05 | HTML-Intrinsic-Größe, viewBox/preserveAspectRatio, verschachtelte Viewports, Längeneinheiten | Allgemeine CSS-Längen-/HTML-Layoutgrenzen und Rasterauflösung. [S03](SVG-S03.md), [S04](SVG-S04.md), [S05](SVG-S05.md). |
| S06–S11 | rect/circle/ellipse/line/polyline/polygon; M/L/H/V/Z/C/S/Q/T/A, Füllregeln, Pfadlänge | Kurven werden mit begrenzter adaptiver Unterteilung gerastert; sehr große/komplexe Pfade können Budgets erreichen. [S06](SVG-S06.md), [S08](SVG-S08.md), [S09](SVG-S09.md), [S10](SVG-S10.md), [S11](SVG-S11.md). |
| S07/S12 | fill/stroke, Alpha, Kappen, miter/round/bevel, Dash-Muster/-Offset | miter-clip und arcs noch offen; endliche Konturapproximation. [S07](SVG-S07.md), [S12](SVG-S12.md). |
| S13–S14 | SVG/CSS-Transformationen, Transformursprung, Zeichenreihenfolge, Gruppen-Opacity, Rendering-Hinweise | Keine unbegrenzte geometrische Genauigkeit oder vollständige Browser-Rasterparität. [S13](SVG-S13.md), [S14](SVG-S14.md). |
| S15–S16 | SVG-Cascade, ausgewählte Selektoren/Zustände, Variablen, defs/g/use/symbol, lokale und Callback-Ressourcen | Shadow-Tree-/Selektor-Sonderfälle, symbol refX/refY und allgemeine DOM-/Basis-URL-Semantik bleiben offen. CSS ist in HTML noch je SVG isoliert. [S15/S16](SVG-S15-S16.md). |
| S17–S18 | Lineare/radiale Verläufe, Stopps, Spread, Einheiten, Transformation, Referenzen | Ressourcen-/Stoppbudgets; URL-Escapes und externe Basis-URL-Sonderfälle offen. [S17/S18](SVG-S17-S18.md). |
| S19–S20 | Pattern, Transformation/viewBox, Marker, Orientierung und Kontextfarben | markerUnits=strokeWidth mit non-scaling-stroke offen; begrenzte verschachtelte Ressourcen. [S19/S20](SVG-S19-S20.md). |
| S21 | Bilder mit Resolver, Ausschnitt, Transformation, Alpha | Plattformabhängige Assetrechte/Quelldaten; vollständige object-fit/object-position-Anbindung offen. Resolver bedeutet keinen allgemeinen Browser-Netzwerkzugriff. [S21/S22](SVG-S21-S22.md). |
| S22 | clipPath, Regeln, Einheiten, Verschachtelung; Textkonturen als Ressourcen seit S28 | Vollständige CSS-Basisformen/Geometriebox-Syntax offen. [S21/S22](SVG-S21-S22.md), [S27/S28](SVG-S27-S28.md). |
| S23–S24 | Alpha-/Luminanzmasken, Gruppenkomposition, Blend-Modi und Isolation im SVG | Keine allgemeine Komposition mit beliebigen HTML-/Roblox-Hintergrundpixeln; vollständige Mask-Shorthands/Listen fehlen. [S23/S24](SVG-S23-S24.md). |

## Text und Filter

| Etappen | Implementierter Teilumfang | Verbleibende Grenze / Nachweis |
|---|---|---|
| S25–S26 | Echte Fontkonturen, text/tspan, Positionierung, Anker, ausgewählte Baselines/Abstände, Textkonturen und einfache vertikale Ausrichtung | Plattformabhängige bereitgestellte Fontdaten. Vollständiges Bidi, arabische/indische Formung, allgemeines GSUB/GPOS, komplexe Cluster, vertikale CJK-Metriken, freie Font-Fallbackketten und mehrzeilige Spezialfälle offen. [S25/S26](SVG-S25-S26.md). |
| S27 | textPath, startOffset und Pfadtransformationen im getesteten Profil | Vollständiger Textumbruch, komplexe Schriftformung und Textpfad-Sonderfälle offen. [S27/S28](SVG-S27-S28.md). |
| S28 | Fontkonturen in Clip, Maske, Pattern und Filter | **foreignObject mit gerastertem HTML fehlt.** Ein darübergelegtes TextLabel zählt nicht als Umsetzung. [S27/S28](SVG-S27-S28.md). |
| S29–S30 | Filtergraph mit in/in2/result, Regionen/Farbräumen; feColorMatrix und feComponentTransfer samt Funktionen | Endliche Filterpuffer; ältere href-Varianten sind keine pauschale native Browserreferenz. [S29/S30](SVG-S29-S30.md). |
| S31–S32 | Blur/DropShadow/Offset/Flood, Blend/Composite/Merge | Blur edgeMode duplicate/wrap und Quellpixel außerhalb der Szenentextur offen. [S31/S32](SVG-S31-S32.md). |
| S33–S34 | Raster-feImage, Tile/Morphology/ConvolveMatrix, DisplacementMap/Turbulence | feImage mit SVG-/Elementverweisen offen; Filterpuffer außerhalb der Szene und weitere Randfälle bleiben begrenzt. [S33/S34](SVG-S33-S34.md). |
| S35 | Diffuse/Specular Lighting mit distant/point/spot; geglättete Spotgrenze | Software-Rasterkosten, begrenzte Filterauflösung; keine neue echte Geräte-Leistungszusage. [S35/S36](SVG-S35-S36.md). |

## Verhalten, Einbettung und Laufzeit

| Etappen | Implementierter Teilumfang | Verbleibende Grenze / Nachweis |
|---|---|---|
| S36–S37 | Formtreffer, pointer-events, Zustände, Cursor, Capture/Eventpfad, Tastatur und Metadaten | SVG-Text-Trefferzellen statt bloßer Glyphenkonturen, vollständiges use-Retargeting/Unterdokumente und allgemeine DOM-/Pointer-API offen. [S35/S36](SVG-S35-S36.md), [S37/S38](SVG-S37-S38.md). |
| S38 | Attribut-/DOM-Änderungen, Ressourcenverbraucher aktualisieren, ausgewählte Geometrieabfragen | Vollständige CTM-/verschachtelte Viewport-Semantik und Browser-DOM fehlen. Farbwechsel benötigt kein HTML-Layout, kann jedoch teure Rasterarbeit verursachen. [S37/S38](SVG-S37-S38.md). |
| S39–S40 | animate/set/animateTransform, ausgewählte Wiederholung/Interpolation; animateMotion/mpath, Ereignisstarts, CSS-Keyframes/Transitions | Vollständiges SMIL-Zeitmodell, Motion-accumulate/from-to-by, mehrere CSS-Animationen/Shorthands, volle Cascade und Animationen in use-Instanzen fehlen. Allgemeine eingebettete Viewportkontexte offen. [S39/S40](SVG-S39-S40.md). |
| S41 | Eigener begrenzter JavaScript-Interpreter und SVG-DOM, echte gemeinsame Skriptquellen und Listener | Kein vollständiges ECMAScript/DOM/Web-API. Explizite Aktivierung, Schritt-/Listener-/Quelltextlimits. Externe Skripte nur per Resolver. [S41/S42](SVG-S41-S42.md). |
| S42 | switch/systemLanguage, ausgewählte view-Fragmente, Metadaten, Ressourcenfehler | xml:base, vollständige Navigation/Fragmentsemantik und Legacy-Funktionen offen; siehe eigenes Inventar unten. [S41/S42](SVG-S41-S42.md). |
| S43 | SVG-Pixel im tatsächlichen HTML-Layout, Scroll/Clip/Überlagerung/Deckkraft, Hover und Cursor | Gemeinsame HTML↔SVG-Cascade, SVG-übergreifende Verweise, vollständige Schriftvererbung und automatische Skript-/Animationslaufzeit innerhalb HTML fehlen. [S43/S44](SVG-S43-S44.md). |
| S44 | Latest-request-Coalescing, CPU-Pixelcache, Textur-Reuse, Abbruch, Speicherlimits und Lebenszyklustests | Allgemeiner Geometriecache, Kacheln und echte Gerätebudgets offen. Aktuell max. 1024 px/Achse, 16 MiB Texturen und 8 MiB Pixelcache je HTML-Seite. [S43/S44](SVG-S43-S44.md). |
| S45 | Vier kombinierte Endbilder und gemeinsame Script-/Animationsprobe | Automatisierte Prüfungen vorhanden, **nativer visueller Abgleich noch offen**. Kein Abschluss aller oben genannten Restfunktionen. [S45](SVG-S45.md). |

## Legacy- und Erweiterungsinventar

Weiterhin nicht implementiert: SVG-Fonts (`font`, `glyph`, `missing-glyph`,
`hkern`, `vkern`), `altGlyph`-Familie/`glyphRef`/`tref`, `color-profile`,
SVG-`cursor`-Element, Meshgradienten und Hatch-Elemente. Die dokumentierten
Diagnosen verhindern, dass dies still als Unterstützung gilt. TTF-Konturen,
CSS-Cursor und Pattern ersetzen nicht automatisch die Semantik dieser Elemente.
Mögliche Umsetzungswege und weitere Legacy-Details: [S42-Audit](SVG-S41-S42.md).

## Reihenfolge der noch offenen Arbeit

1. S45 im nativen Browser/Studio abgleichen und konkrete Unterschiede beheben.
2. Gemeinsame HTML-/SVG-Cascade und Ressourcen-/Schriftkontext vervollständigen.
3. Skript-/Animationslaufzeit kontrolliert in HTML einbetten, mit variablen Viewports.
4. `foreignObject` und feImage-SVG-Referenzen über gemeinsame Rasterquellen umsetzen.
5. Textformung, Event-/CTM-Sonderfälle sowie SMIL-/CSS-Restumfang ausbauen.
6. Reale Geräte-/Speichermessungen und daraus abgeleitete Raster-/Kachelstrategie.

Diese Reihenfolge ist eine Arbeitsliste, kein Beleg einer Plattformunmöglichkeit.
Für jede weitere Funktion bleibt ein eigener sichtbarer Vergleich erforderlich.
