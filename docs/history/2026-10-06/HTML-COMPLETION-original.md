# HTML-Abschlussliste

Stand: 20. September 2026. Referenz ist die aktuelle Liste konformer Elemente
im [WHATWG HTML Living Standard](https://html.spec.whatwg.org/multipage/indices.html#elements-3).
Diese Datei zählt ausschließlich offenen Umfang. Bereits fertiggestellte
Teilfunktionen werden nicht erneut aufgelistet.

## Zählung

- Der aktuelle Standard führt 113 konforme HTML-Elementnamen.
- `HTML/Elements.luau` registriert alle 113 davon ausdrücklich.
- Kein konformes HTML-Element fehlt vollständig.
- Von den 113 registrierten HTML-Elementen sind 112 im dokumentierten Roblox-
  Profil als `supported` und eines als `parser-only` markiert. Kein Eintrag
  beansprucht damit vollständige Browser- oder WHATWG-Konformität.
- `partial` ist künftig nur zulässig, wenn eine geplante Funktion innerhalb des
  Roblox-Profils noch fehlt; derzeit ist kein Element so eingestuft.
- `svg` ist zusätzlich registriert, zählt aber nicht zu den 113 HTML-Elementen.
- Ein unbekannter Tag, der nur als generischer Block erscheint, gilt nicht als
  Unterstützung dieses Elements.

## Bewertungsmaßstab

Der Katalog bewertet die praktische Funktion in Roblox. Nicht verfügbare oder
bewusst ausgeschlossene Browserplattformen wie allgemeines JavaScript, DRM,
Browserprozesse oder HTTP-Navigation machen ein ansonsten fertiges Roblox-Element
nicht `partial`. Die folgenden offenen Punkte bleiben als optionale Browser-Parität
dokumentiert und ändern den Roblox-Status erst, wenn sie ausdrücklich in den
Projektumfang aufgenommen werden.

## 1. Vollständig fehlende HTML-Elemente

Keine. Alle 113 konformen Elementnamen sind ausdrücklich registriert.

## 2. Fehlendes Verhalten registrierter Elemente

### Canvas

- [ ] `canvas` — interne Pixelauflösung, responsive CSS-Anzeigegröße, CSS-Farben,
  Rechtecke, Pfade, Kurven, Kreise, Ellipsen, Transformationen, Füllung,
  Kontur, Alpha, lineare/radiale Verläufe, Clipping, Füllregeln, elf
  Porter-Duff-Kompositionsmodi, alle 15 CSS-Mischmodi, Formschatten und
  `save()`/`restore()` sowie Outline-Text mit vier Source-Sans-Pro-Schnitten,
  Ausrichtung, Baselines, `maxWidth`, Messwerten und `drawImage()` für skalierte,
  zugeschnittene und transformierte HTML-/Canvas-Bildquellen sowie wiederholbare,
  transformierbare Canvas-Muster, direkter Pixelzugriff über `ImageData` und
  PNG-Export über `toDataURL()`/`toBlob()` sowie Animation über
  `requestAnimationFrame()` sind vorhanden. WebGL/WebGL2 und WebGPU besitzen
  ausführbare CPU-Dreieckspipelines mit Shader-, Buffer-, Attribut-, Device-,
  Queue- und Renderpass-APIs; allgemeine Shader, Texturen, Depth/Stencil,
  Compute und die vollständigen GPU-Spezifikationen fehlen.

### Eingebettete Dokumente

- [ ] `iframe` — unabhängige interne PageSession, `src`, `srcdoc`,
  Fragmentnavigation, `_parent`/`_top`, CSS-/Attributgrößen, Scrollen,
  404-Fallback und ein Tiefenlimit sind vorhanden. Es fehlen benannte
  Browsing-Kontexte, Verlauf vor/zurück, `loading=lazy`, Ladeereignisse,
  `sandbox`, `allow`, Permissions Policy, `credentialless` und externe
  Browserinhalte.
- [ ] `object` — interne HTML-Websites aus `data`, die MIME-Typen `text/html`
  und `application/xhtml+xml` sowie Kind-Fallback bei fehlender/inkompatibler
  Quelle sind vorhanden. Es fehlen Bilder, Plugins, Formzuordnung, dynamische
  Änderungen, Ladeereignisse und externe Ressourcen.
- [ ] `embed` — interne HTML-Websites aus `src` mit denselben HTML-MIME-Typen
  sind vorhanden. Es fehlen Bilder, Plugins, dynamische Änderungen,
  Ladeereignisse und externe Ressourcen.

### Dokumentstruktur, Metadaten und Ressourcen

- [ ] `template` — ein eigenes inaktives `DocumentFragment`, verschachtelte
  Templates, getrennte Dokument-/ID-/Stylesheet-Suche, unabhängiges tiefes
  `DOM.cloneNode()` und deklarative offene/geschlossene Shadow Roots über
  `shadowrootmode` sind vorhanden. Es fehlen die vollständigen HTML-
  Tree-Builder-Modi und allgemeine JavaScript-DOM-Methoden.

- [ ] `slot` — benannte und namenlose Verteilung direkter Light-DOM-Kinder,
  Quellreihenfolge, erster gleichnamiger Slot und Fallback-Inhalt sind vorhanden.
  Es fehlen dynamische Neuzuweisung, `slotchange`, `assign()`, imperative Shadow-
  DOM-Methoden, `:host`, `::slotted()` und vollständiges Event-Retargeting.

- [ ] `html`, `head`, `body` — implizit erzeugen, ausgelassene Tags korrekt
  behandeln, Dokumentattribute reflektieren und `body`-Ereignisse an das Fenster
  anbinden.
- [ ] `title` — aktiven Dokumenttitel aus Textinhalt erzeugen und bei Änderungen
  aktualisieren.
- [ ] `base` — Basis-URL und Standardziel nach DOM-Änderungen neu bestimmen und
  außerdem auf Formulare sowie alle weiteren Ressourcentypen anwenden.
- [ ] `meta` — mindestens Zeichencodierung, Viewport, Referrer, Theme-Farbe und
  die erlaubten `http-equiv`-Pragmas auswerten.
- [ ] `link` — Stylesheets und die standardisierten `rel`-Beziehungen mit
  Medienabfrage, Aktivierung, Fehler-/Ladeereignissen und Ressourcenwahl
  auswerten; dazu gehören unter anderem Icon, Preload und Manifest.
- [ ] `style` — `media`, `blocking`, dynamische Änderungen und die zugehörige
  Stylesheet-Schnittstelle vollständig anbinden.
- [ ] `script` — klassische Scripts, Module, Import Maps, Lade-/Ausführungsreihenfolge,
  `async`, `defer`, Ereignisse und Script-DOM. Das setzt eine deutlich vollständigere
  ECMAScript- und Web-API-Laufzeit voraus als die bisherige SVG-Script-Teilmenge.

### Text- und Abschnittselemente

- [ ] `ruby`, `rt`, `rp` — ein horizontaler Basistext mit darüber zentrierter,
  kleinerer Anmerkung und ausgeblendeten Fallbackklammern ist vorhanden. Es
  fehlen mehrere Paare innerhalb eines gemeinsamen Ruby-Elements, komplexe
  Gruppierung, Umbruch, vertikale Schreibrichtung sowie `ruby-position`,
  `ruby-align` und `ruby-merge`.
- [ ] `noscript` — body-Fallback wird dargestellt, weil allgemeines
  HTML-JavaScript nicht ausgeführt wird; im head bleibt es unsichtbar. Es fehlen
  umschaltbarer Scripting-Zustand und die vollständigen Sonder-Parserregeln.
- [ ] `abbr`, `bdi`, `bdo`, `data`, `q`, `time` — Inline-Darstellung,
  maschinenlesbare Attributwerte, einfache Schreibrichtung und verschachtelte
  typografische Anführungszeichen sind vorhanden. Es fehlen Tooltip,
  sprachabhängige `quotes`, vollständiger Unicode-Bidi-Algorithmus,
  Wert-/Datumsvalidierung und die vollständigen DOM-Schnittstellen.
- [ ] `article`, `aside`, `footer`, `header`, `hgroup`, `main`, `nav`, `search`,
  `section` — der Block-Standardwert und semantische Rollenmetadaten sind
  vorhanden. Es fehlen kontextabhängige Landmark-Rollen, vollständige
  Accessible-Name-Berechnung, Inhaltsmodellvalidierung und die native
  Accessibility-Tree-Anbindung.
- [ ] `address`, `article`-bezogene Kontaktsemantik und Zugänglichkeitsrolle
  vollständig abbilden.
- [ ] `blockquote`, `ins`, `del` — `cite` und bei Änderungen zusätzlich
  `datetime` reflektieren; Änderungssemantik statt reiner Dekoration liefern.
- [ ] `dfn` — Definitionsterm und `title`-Beziehung vollständig auswerten.
- [ ] `cite`, `code`, `kbd`, `samp`, `var`, `small`, `mark`, `b`, `strong`,
  `em`, `i`, `s`, `u`, `sub`, `sup`, `span` — Elementsemantik im
  Zugänglichkeitsbaum, vollständige Inline-Boxen und korrekte Schriftformung über
  Stilgrenzen ergänzen.
- [ ] `pre` — vollständige Browser-Fontwahl und alle parserrelevanten
  Anfangszeilenregeln vervollständigen.
- [ ] `p` — implizites Schließen durch alle vorgeschriebenen Start-/End-Tags und
  vollständiges Absatzmodell.
- [ ] `h1`–`h6` — exakte Standardmetriken, Überschriftenstruktur und
  Accessibility-Level vervollständigen.
- [ ] `br`, `wbr` — vollständige Zeilenbruch-, Auswahl- und Kopiersemantik in
  allen Schreibrichtungen.
- [ ] `hr` — vollständige semantische Trennlinie und Standarddarstellung ohne
  Abhängigkeit von historischen Attributen.
- [ ] `figure`, `figcaption` — Caption-Zuordnung und Accessibility-Name korrekt
  ableiten.
- [ ] `dl`, `dt`, `dd` — Name-Wert-Gruppen einschließlich `div`-Wrappern,
  Parserkorrekturen und bidirektionalem Layout vollständig umsetzen.

### Links und Navigation

- [ ] `a` — echte benannte Navigationskontexte für `target`, Downloadpfad,
  `ping`, `rel`, Referrer-Regeln, externe Navigation und Tastaturaktivierung
  implementieren.
- [ ] Fragmentnavigation — Scrollziel, Fokus, URL-Zustand, Verlauf sowie
  `:target` bei Navigation und Rücknavigation aktualisieren.
- [ ] Bildlinks — die vorhandenen `map`/`area`-Trefferflächen um Tastaturfokus,
  dynamische Änderungen, sämtliche object-fit-Fälle und `img[ismap]` ergänzen.

### Bilder

- [ ] `img` — die vorhandene `srcset`-/`sizes`-Auswahl um die vollständige
  Medien-/Größensyntax, echte Gerätedichte und dynamische Neuauswahl erweitern.
- [ ] `img` — vorhandenes `usemap` vervollständigen sowie `ismap`, CORS,
  Referrer Policy, `decoding`, `loading`,
  `fetchpriority` und die vollständigen Lade-/Fehlerzustände abbilden.
- [ ] `img` — animierte Bilder, echte Netzressourcen, Intrinsic-Dichte und
  vollständige Ersatztext-/Accessibility-Semantik unterstützen.
- [ ] `img` — zusammen mit `picture`/`source` bei Viewport-, Medien- oder
  Auflösungsänderungen neu auswählen.

### Audio, Video und Textspuren

- [ ] `audio` — lokale Roblox-Assetzuordnung, Wiedergabe, Pause, Schleife,
  Stummschaltung, Zeitachse, Wiedergabegeschwindigkeit von 0.5x bis 2x,
  `preload`, responsive Controls, Zustandsabfrage und lokale Medienereignisse
  sind vorhanden. Es fehlen freie Raten außerhalb dieses Bereichs, echte
  Netz-/Pufferzustände, `crossorigin`, die Trennung von Metadaten- und
  vollständigem Preload, MediaSource/DRM und die vollständige
  `HTMLMediaElement`-Schnittstelle.
- [ ] `video` — zusätzlich sind `VideoPlayer`/`VideoDisplay`, ein
  `VideoFrame`-Fallback, Poster, eigene Controls, Vollbild, `nofullscreen` und
  bei `VideoPlayer` Wiedergabegeschwindigkeit von 0.5x bis 2x vorhanden. Es
  fehlen Picture-in-Picture, Streaming, native Browser-Steuerleisten und
  vollständige Größen-/Qualitätsereignisse.
- [ ] `source` — Audio und Video wählen beim Mount die erste typkompatible
  Quelle mit Assetzuordnung. Es fehlen dynamische Neuauswahl, Codecprüfung,
  Media Queries sowie Lade-/Fehlerereignisse je Quelle.
- [ ] `track` — einfache WebVTT-Untertitel/Captions, `default`, `kind`, `label`
  und `srclang`, mehrere auswählbare Spuren und Wechselereignisse werden
  gelesen. Es fehlen Regionen, Cue-Positionierung/-Styling,
  Kapitel-/Metadaten-APIs, mehrere gleichzeitig aktive Spuren und die
  vollständige `TextTrack`-/`VTTCue`-Schnittstelle.

### Listen

- [ ] `menu` — Standarddarstellung, `li`-Marker, Verschachtelung und CSS-
  Listenwerte sind vorhanden. Es fehlen eine Befehls-API und historische
  Toolbar-Kompatibilität.
- [ ] `ol` — das HTML-Attribut `type` vollständig abbilden und Grenzfälle von
  `start`, `reversed` und sehr großen Ganzzahlen browsergleich behandeln.
- [ ] `ul`, `ol`, `li` — RTL-Marker, Markerbilder, vollständige Markerboxen und
  `::marker` ergänzen.
- [ ] `li` — sämtliche ausgelassenen End-Tag- und fehlerhaften
  Verschachtelungsfälle im HTML-Parser korrigieren.

### Formulare allgemein

- [ ] `form` — `action`, `method` (`get`, `post`, `dialog`), `enctype`,
  `target`, `accept-charset`, `autocomplete`, `novalidate` und `rel` ausführen.
- [ ] Erfolgreiche Controls nach Standard auswählen, Daten in DOM-Reihenfolge
  serialisieren und URL-encoded, multipart sowie text/plain übergeben.
- [ ] Externe Formularzuordnung über `form=id`, submitter-spezifische Overrides
  und verschachtelte/fehlerhafte Form-Tags korrekt behandeln.
- [ ] Constraint Validation vollständig umsetzen: `willValidate`, ValidityState,
  `checkValidity()`, `reportValidity()`, `setCustomValidity()`, `invalid` und
  standardisierte Meldungen.
- [ ] Form-, Input-, Change-, BeforeInput-, Submit-, FormData-, Reset- und
  Invalid-Ereignisse mit richtiger Reihenfolge und Abbruchsemantik ergänzen.
- [ ] Autofill-/Autocomplete-Tokens, Speicherung sowie Wiederherstellung von
  Formzustand ergänzen.

### Formularelemente

- [ ] `datalist` — `input[list]`, Optionswerte, Filterung sowie Maus- und
  Tastaturauswahl sind für die vorhandenen editierbaren Text-, E-Mail-, URL-
  und Zahlenfelder umgesetzt. Es fehlen native Picker für Datum/Farbe,
  Range-Markierungen, vollständige Attributreflexion und Browserdetails der
  Filter-/Ereignislogik.
- [ ] `input` — fehlende Zustände implementieren: `search`, `tel`, `date`,
  `month`, `week`, `time`, `datetime-local`, `color`, `file` und `image`.
- [ ] `input` — für alle Zustände die jeweils geltenden Attribute, Sanitisierung,
  Schrittbasis, Lokalisierung, Auswahl-APIs und Standarddarstellung umsetzen.
- [ ] `input` — `pattern`, `size`, `list`, `dirname`, `accept`, `capture`,
  `multiple`, `form*`, `popovertarget*`, `width`, `height`, `src` und `alt`
  entsprechend dem jeweiligen Typ ergänzen.
- [ ] `button` — beliebigen zulässigen Kindinhalt, `command`/`commandfor`,
  `popovertarget*` und alle `form*`-Overrides unterstützen.
- [ ] `textarea` — `wrap`, `dirname`, `form`, `required`, `placeholder`,
  Auswahl-/Scroll-APIs und standardkonforme Zeilenumbruch-Normalisierung ergänzen.
- [ ] `select` — `multiple`, `size`, Listenboxdarstellung, leere Auswahl,
  vollständige Tastatursteuerung und anpassbares Select ergänzen.
- [ ] `option`, `optgroup` — dynamische Auswahllogik, vollständiger zulässiger
  Inhalt für anpassbares Select, Styling und `legend` in `optgroup` ergänzen.
- [ ] `label` — mehrere Labels pro Control, dynamische Zuordnung,
  standardkonforme Weiterleitung von Aktivierung und Accessibility-Name ergänzen.
- [ ] `fieldset`, `legend` — `form`, `name`, `elements`, dynamische
  Disabled-Vererbung, RTL/vertikale Darstellung und `legend` in `optgroup`
  vervollständigen.
- [ ] `output` — `for`, `form`, `name`, Defaultwert/Reset und automatische
  Zuordnung zu den Eingabequellen ergänzen.
- [ ] `progress` — indeterminierte Animation, Accessibility-Werte und exakte
  Standardzustände ergänzen.
- [ ] `meter` — Accessibility-Werte, Fallback-Inhalt und standardkonforme
  Bereichsbestimmung vervollständigen.

### Details und Zusammenfassung

- [ ] `details` — gleiche `name`-Gruppe als exklusives Akkordeon umsetzen.
- [ ] `details` — `toggle`/`beforetoggle`, dynamische `open`-Änderungen und davon
  abhängige Selektoren ohne vollständiges Remount aktualisieren.
- [ ] `summary` — vollständige Markerbox, `::marker`, Fokus-, Auswahl- und
  Accessibility-Semantik ergänzen.

### Dialoge

- [ ] `dialog` — `open`, die Seitenmethoden `ShowDialog`, `ShowModal` und
  `CloseDialog`, deklarative `commandfor`-Befehle, modaler Hintergrund,
  Fokusbegrenzung, Escape, `closedby=none|closerequest|any`, `returnValue` und
  `form method="dialog"` sind vorhanden. Es fehlen DOM-Methoden auf dem
  Elementobjekt, `cancel`-/`close`-/`beforetoggle`-/`toggle`-Ereignisse,
  Fokuswiederherstellung zum Öffner, mehrere gestapelte modale Dialoge,
  dynamische Attributänderungen und `::backdrop`-CSS.

### Tabellen

- [ ] `table`, `caption`, `colgroup`, `col`, `thead`, `tbody`, `tfoot`, `tr`,
  `td`, `th` — vollständigen HTML-Tabellenparser mit impliziten Elementen,
  Foster Parenting und Reparatur fehlerhafter Reihenfolge implementieren.
- [ ] Das vollständige automatische und feste Tabellenbreiten-/Höhenmodell,
  Min-/Max-Content, Prozentkonflikte, Baselines, anonyme Tabellenboxen und
  Blockifizierung ergänzen.
- [ ] `th` — `scope`, `headers` und `abbr`; `td` — `headers`; dazu den
  Header-Zuordnungsalgorithmus und die semantische Tabelle im
  Zugänglichkeitsbaum umsetzen.
- [ ] `caption` — sämtliche zulässigen Layoutfälle; Zeilen-/Spaltengruppen —
  vollständige Vererbung, Schreibrichtung und Druck-/Wiederholungssemantik.
- [ ] Die internen Rastergrenzen entweder standardtransparent erweitern oder als
  bewusste Sicherheitsgrenze beibehalten; sie verhindern streng genommen eine
  Behauptung unbegrenzter Browsergleichheit.

## 3. Elementübergreifende HTML-Anforderungen

Ohne diese Punkte können alle Tag-Namen vorhanden sein und die Engine ist
trotzdem nicht HTML-vollständig.

### HTML-Parser und Dokumentmodell

- [ ] Vollständigen HTML-Tokenizer mit allen Zuständen, Parsefehlern,
  Zeichenreferenzen und Encoding-Sniffing implementieren.
- [ ] Vollständigen Tree Builder mit allen Insertion Modes, implied end tags,
  Active Formatting Elements, Adoption Agency Algorithm und Foster Parenting
  implementieren.
- [ ] Fragment-Parsing mit richtigem Kontextelement ergänzen.
- [ ] Standards-, Limited-Quirks- und Quirks-Modus aus Doctypes bestimmen.
- [ ] HTML-, SVG- und MathML-Namespaces samt Integrationspunkten korrekt mischen.
- [ ] Parser, `innerHTML`, `outerHTML` und Serialisierung browsergleich machen.

### Globalattribute

- `popover` ist als statischer Top-Layer-Zustand mit `auto`, `manual` und
  `hint`, `popovertarget`/`popovertargetaction`, Escape, Außenklick,
  `:popover-open` und einer viewportbezogenen Platzierung umgesetzt.
  Vollständige HTML-Popover-Ereignisse, Fokuswiederherstellung und die
  dynamische JavaScript-DOM-API bleiben offen.
- [ ] `accesskey`, `autocapitalize`, `autocorrect`, `contenteditable`, `dir`,
  `draggable`, `enterkeyhint`, `headingoffset`, `headingreset`, `hidden`
  einschließlich `until-found`, `inert`, `inputmode`, `is`, `itemid`,
  `itemprop`, `itemref`, `itemscope`, `itemtype`, `lang`, `nonce`, `part`,
  `spellcheck`, `style`, `tabindex`, `title`, `translate`,
  `virtualkeyboardpolicy`, `writingsuggestions` und alle `data-*`-Attribute mit
  ihrer vollständigen Semantik ergänzen.
- [ ] Alle zulässigen `on...`-Eventhandlerattribute anbinden.
- [ ] ARIA-Attribute, Rollen, Accessible-Name-Berechnung, Zustände und native
  Rollen pro Element vollständig in Roblox-Zugänglichkeit übertragen.
- [ ] Microdata (`itemscope`, `itemtype`, `itemprop`, `itemid`, `itemref`) und
  `dataset` implementieren.

### DOM-Schnittstellen und dynamische Änderungen

- [ ] Für jedes Element die im Standard genannte `HTML*Element`-Schnittstelle,
  reflektierte Attribute, Methoden, Eigenschaften und Live-Collections ergänzen.
- [ ] DOM-Erzeugung, Einfügen, Entfernen, Klonen, Ersetzen, Attributänderung und
  Textänderung ohne komplettes Remount korrekt invalidieren.
- [ ] Eventziel, Capture/Bubble, `preventDefault`, zusammengesetzte Pfade,
  Fokusreihenfolge, Aktivierung und Tastaturbedienung browsergleich machen.
- [ ] Selection-, Range-, Editing-, Drag-and-drop- und Clipboard-Anbindung für
  editierbaren HTML-Inhalt ergänzen.
- [ ] URL, Location, History und benannte Navigationskontexte an Links,
  Formulare, Frames und Fragmente anbinden.

### Custom Elements und Shadow DOM

- [ ] Gültige autonome Custom-Element-Namen statt generischem Blockfallback
  erkennen.
- [ ] `CustomElementRegistry`, Upgrade, Lifecycle-Callbacks und
  form-associated custom elements implementieren.
- [ ] Die vorhandenen offenen/geschlossenen deklarativen Shadow Roots,
  Slot-Verteilung und Stylesheet-Isolation um imperative APIs, dynamische
  Neuzuweisung, Event-Retargeting, fokussierte Navigation, `:host` und
  `::slotted()` ergänzen.

### Fremdinhalte

- [ ] MathML mit dem Root-Element `math`, MathML-Parserintegration,
  Formel-Layout, Operatoren, Schriften und Accessibility ergänzen.
- [ ] Die in `SVG-SUPPORT.md` verbliebenen SVG-Grenzen schließen und eingebettetes
  SVG vollständig mit HTML-Cascade, Navigation, Fokus, Ereignissen und DOM
  verbinden.

## 4. Nicht Teil des modernen 100-%-Ziels

Obsolete beziehungsweise nicht konforme Tags wie `font`, `center`, `marquee`,
`frameset`, `frame`, `applet`, `big`, `tt`, `strike`, `xmp` oder `plaintext`
gehören nicht zur obigen 113-Elemente-Zählung. Sie wären ein eigener
Browser-Kompatibilitätsumfang für alte Webseiten, aber keine Voraussetzung für
die vollständige aktuelle, konforme HTML-Elementmenge.

## Abschlusskriterium

Der Roblox-Elementumfang gilt als vollständig registriert, wenn kein konformes
Element fehlt und kein Eintrag mehr `partial` meldet. Das ist aktuell erreicht:
112 Elemente sind im Roblox-Profil `supported`; `script` bleibt als bewusste
Sicherheits- und Plattformgrenze `parser-only`. Die übrigen Punkte dieser Datei
beschreiben optionale Browser-Parität und sind kein automatischer Blocker für
den Roblox-Status.
