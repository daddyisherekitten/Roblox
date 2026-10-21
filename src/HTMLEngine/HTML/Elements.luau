--!strict
-- Central catalog of explicitly handled elements. Also exposed as Engine.Elements.
-- Support is measured against the documented Roblox profile, not full browser parity.
-- supported = usable Roblox behavior; partial = planned Roblox behavior remains; parser-only = stored, not rendered.
-- Render selects the existing renderer behavior; it does not implement new features.
-- Unlisted HTML elements keep the CSS initial inline display and generic
-- authored layout, without implying tag-specific support.
local GridValues = require(script.Parent.Parent.CSS.GridValues)
local elements: { [string]: any } = {
	base = {Render="hidden",Support="supported",Description="Basis-URL und Standardziel",Limitations="Das erste href und target werden beim Mount ausgewertet und für Links sowie lokale Stylesheets verwendet. Keine dynamische Neuberechnung nach DOM-Änderungen."},
	template = {Render="hidden",Support="supported",Description="Inaktive Vorlage oder deklarative Shadow-Root-Quelle",Limitations="HTML-Templates einschließlich Namespace-Präfixen besitzen ein unabhängiges Content-Fragment mit gemeinsamem inaktivem Eigentümerdokument; HTML-/XML-Parsing, innerHTML, Klonen, Importieren und Adoption erhalten diese Grenzen. Custom Elements bleiben darin inaktiv und werden nach aktivem Import oder Einfügen aktiviert. Deklarative Shadow Roots besitzen dagegen das Hostdokument. XML-Serialisierung verwendet den gemeinsamen Namespace-Fixup; Nachweise und bewusste API-/Standardgrenzen stehen im Dokumentprofil. Neue template[for]-Patching-Regeln bleiben offen."},
	slot = {Render="slot",Support="supported",Defaults={Display="inline"},Description="Einfügepunkt im Shadow DOM",Limitations="Benannte und namenlose Slots verteilen direkte Light-DOM-Kinder in Quellreihenfolge und zeigen ohne Zuweisung ihren Fallback-Inhalt. Einfaches :host und ::slotted(compound) gelten für den Host und direkt zugewiesene Elemente. Dynamische Neuzuweisung, slotchange, assign(), komplexe Host-/Slotted-Selektoren und imperative attachShadow-Aufrufe fehlen."},
	abbr = {Render="inline",Support="supported",ValueAttribute="title",Defaults={TextDecoration={Underline=true},DecorationStyle="dotted"},Description="Abkürzung",Limitations="Dünn gepunktet unterstrichen und title als semantischer Wert verfügbar. Noch kein nativer Hover-Tooltip; Unterstreichung gilt derzeit auch ohne title."},
	bdi = {Render="inline",Support="supported",ValueAttribute="dir",Description="Isolierter bidirektionaler Text",Limitations="dir=ltr/rtl wird als Richtung übernommen und als semantischer Wert erhalten. Keine automatische Richtung oder vollständige Unicode-Bidi-Isolation."},
	bdo = {Render="inline",Support="supported",ValueAttribute="dir",Description="Erzwungene Schreibrichtung",Limitations="dir=ltr/rtl wird als Richtung übernommen. Kein vollständiger Unicode-Bidi-Override oder Zeichenreordering."},
	data = {Render="inline",Support="supported",ValueAttribute="value",Description="Text mit maschinenlesbarem Wert",Limitations="value bleibt am DOM-Knoten und als SemanticValue des berechneten Stils verfügbar. Keine eigene DOM-Schnittstelle oder Microdata-Auswertung."},
	q = {Render="inline",Support="supported",ValueAttribute="cite",Description="Kurzes Inline-Zitat",Limitations="Automatische typografische Anführungszeichen mit wechselnder Verschachtelungstiefe; cite bleibt als semantischer Wert verfügbar. Sprache und quotes-CSS werden noch nicht ausgewertet."},
	time = {Render="inline",Support="supported",ValueAttribute="datetime",Description="Maschinenlesbare Zeitangabe",Limitations="datetime bleibt am DOM-Knoten und als SemanticValue des berechneten Stils verfügbar. Keine Datumsauswertung oder Validierung."},
	ruby = {
		Render = "inline", Support="supported",
		Defaults = {
			Display = "inline-grid",
			GridColumns = GridValues.tracks("auto"),
			GridRows = GridValues.tracks("auto auto"),
			RubyRowOverlap = 0.15,
			TextAlign = "center",
		},
		Description = "Ruby-Anmerkung",
		Limitations = "Ein horizontaler Basistext mit einer rt-Anmerkung. ruby-position over/under und ruby-align start/center werden dargestellt; space-Verteilung ist zentriert. Mehrere Paare benötigen getrennte ruby-Elemente; komplexe Gruppierung und ruby-merge fehlen.",
	},
	rt = {
		Render = "block", Support="supported", FontSizeScale = 0.5,
		Defaults = {
			LineHeight = {Kind = "number", Value = 1},
			TextAlign = "center",
			GridColumnStart = GridValues.line("1"), GridColumnEnd = GridValues.line("2"),
			GridRowStart = GridValues.line("1"), GridRowEnd = GridValues.line("2"),
		},
		Description = "Aussprache-Anmerkung in ruby",
		Limitations = "Wird mit 50 % der geerbten Schriftgröße gemäß ruby-position über oder unter dem Basistext in einer einzelnen Ruby-Spalte dargestellt; keine verschachtelte Gruppierung oder vertikale Schreibrichtung.",
	},
	rp = {
		Render = "hidden", Support="supported",
		Description = "Ruby-Fallbackklammer",
		Limitations = "Bei unterstützter Ruby-Darstellung ausgeblendet. Ein umschaltbarer Fallbackmodus ohne Ruby-Unterstützung fehlt.",
	},
	article = {Render="block",Support="supported",SemanticRole="article",Description="Eigenständiger Seitenabschnitt",Limitations="Blocklayout und semantische Rollenmetadaten. Keine vollständige Accessibility-Tree-Anbindung oder automatische Überschriftenstruktur."},
	aside = {Render="block",Support="supported",SemanticRole="complementary",Description="Ergänzender Seiteninhalt",Limitations="Blocklayout und semantische Rollenmetadaten. Kontextabhängige Landmark-Erkennung bleibt angenähert."},
	footer = {Render="block",Support="supported",SemanticRole="contentinfo",Description="Fußbereich",Limitations="Blocklayout und semantische Rollenmetadaten. Verschachtelte Footer werden noch nicht abhängig vom nächsten Abschnitt klassifiziert."},
	header = {Render="block",Support="supported",SemanticRole="banner",Description="Kopfbereich",Limitations="Blocklayout und semantische Rollenmetadaten. Verschachtelte Header werden noch nicht abhängig vom nächsten Abschnitt klassifiziert."},
	hgroup = {Render="block",Support="supported",SemanticRole="group",Description="Gruppe aus Überschrift und Untertitel",Limitations="Blocklayout und Gruppenmetadaten. Keine eigene Accessibility-Namensberechnung aus den enthaltenen Überschriften."},
	main = {Render="block",Support="supported",SemanticRole="main",Description="Hauptinhalt",Limitations="Blocklayout und semantische Rollenmetadaten. Mehrere main-Elemente werden nicht automatisch validiert."},
	nav = {Render="block",Support="supported",SemanticRole="navigation",Description="Navigationsbereich",Limitations="Blocklayout, Linkverhalten und semantische Rollenmetadaten. Keine native Roblox-Landmark-Navigation."},
	search = {Render="block",Support="supported",SemanticRole="search",Description="Suchbereich",Limitations="Blocklayout und semantische Rollenmetadaten. Suchlogik benötigt weiterhin normale Formulare und Anwendungscode."},
	section = {Render="block",Support="supported",SemanticRole="region",Description="Thematischer Seitenabschnitt",Limitations="Blocklayout und semantische Rollenmetadaten. Region-Rolle wird derzeit auch ohne zugänglichen Namen offengelegt."},
	picture = {Render="contents",Support="supported",Description="Responsive Bildquellen",Limitations="Das erste passende source vor dem img wird anhand einfacher min/max-width-Medienbedingungen sowie w-/x-Deskriptoren ausgewählt. Die Auswahl erfolgt beim Mount; komplexe sizes/media-Abfragen und dynamische Neuauswahl fehlen."},
	source = {Render="hidden",Void=true,Support="supported",Description="Alternative Medienquelle",Limitations="Für picture werden srcset, sizes, media und image/*-type ausgewertet. Audio und Video wählen die erste typkompatible Quelle mit einer Roblox-Assetzuordnung; keine dynamische Neuauswahl."},
	map = {Render="inline",Support="supported",Description="Benannte Bildkarte mit transparentem Inhalt",Limitations="Gewöhnliche Kinder verwenden Inline-/Blocklayout. Bildkarten werden im Light-Tree des Bildes über den ersten id-/name-Treffer aufgelöst; usemap, Umbenennen, Ersetzen und Reihenfolge bleiben live. Vollständige Accessibility-Anbindung und alle transformierten Trefferpfade sind nicht nachgewiesen."},
	area = {Render="hidden",Void=true,Support="supported",Description="Trefferfläche einer Bildkarte",Limitations="Live rect/circle/poly/default einschließlich historischer Aliase, Floatlisten-Fehlerkorrektur und erster überdeckender Fläche; href-lose Flächen blockieren darunterliegende Links. Pointer/Linkaktivierung sowie Tastaturberechtigung richten sich nach dem zugeordneten Bild. Das begrenzte Borderbox-Profil und Chromium-/Normabweichungen sind im Dokumentprofil abgegrenzt; visuelle Form-Fokusumrisse und beliebige Transformationen bleiben offen."},
	audio = {Render="media",Support="supported",Description="Audio-Wiedergabe",Limitations="src/source über options.Audio; JavaScript Audio()/new Audio(), play()-Promise, pause/load, Zeit/Rate/Lautstärke, Status/MediaError/TimeRanges und Ereignisse teilen denselben Sound mit controls/autoplay/loop/muted/preload und der Roblox-Steuerleiste. Raten 0.5x–2x; keine echten Pufferstatistiken, kein Streaming, vollständiger Source-Fallback, Web Audio, MediaSource/DRM oder vollständige HTMLMediaElement-API."},
	video = {Render="media",Support="supported",Description="Video-Wiedergabe",Limitations="src/source über options.Videos, Poster über options.Images, controls, autoplay, loop, muted, preload, Zeitachse, mehrere wählbare Untertitel, Vollbild und mit VideoPlayer 0.5x–2x Wiedergabegeschwindigkeit. nofullscreen wird aus controlslist ausgewertet; der VideoFrame-Fallback hat keine Geschwindigkeitswahl. Picture-in-Picture, Streaming und die vollständige HTMLMediaElement-API fehlen."},
	track = {Render="hidden",Void=true,Support="supported",Description="Medien-Textspur",Limitations="WebVTT aus options.Tracks für mehrere wählbare subtitles/captions-Spuren; default, label, srclang und kind werden erhalten. Keine Regionen, Cue-Positionierung/-Styling, gleichzeitig aktiven Spuren oder dynamisch hinzugefügten Track-Knoten."},
	svg = {Render="svg",Support="supported",Description="SVG-Layoutbox",Limitations="S03: Inline/Block, CSS-Größen und intrinsisches Seitenverhältnis. SVG-Kinder bleiben im DOM; allgemeines Zeichnen und viewBox-Transformation folgen S04–S15."},
	canvas = {Render="canvas",Support="supported",Description="Scriptgesteuerte Bitmap-Zeichenfläche",Limitations="Interne Pixelgröße über width/height, CSS-Anzeigegröße und ein begrenzter Canvas-2D-Kontext mit Rechtecken, Pfaden, Kurven, Transformationen, Verläufen, Mustern, Clipping, Compositing, allen CSS-Mischmodi, Formschatten, Outline-Text, drawImage, ImageData-Pixelzugriff, PNG-Export, requestAnimationFrame, Messwerten, Füllung, Kontur, Alpha sowie save/restore. WebGL/WebGL2 und WebGPU besitzen CPU-Dreieckspipelines; allgemeine Shader, Texturen, Depth/Stencil, Compute und die vollständigen GPU-Spezifikationen fehlen. Maximal 2048 px pro Achse und 4194304 Pixel."},
	caption = {Render="block",Support="supported",Defaults={TableRole="caption",TextAlign="center"},Description="Tabellenbeschriftung",Limitations="caption-side:top/bottom, eigene Abstände und Rahmen. Horizontales Layout; keine frei positionierten Captions."},
	col = {Render="column",Support="supported",Defaults={TableRole="column"},Description="Tabellenspalte",Limitations="CSS-Breite, span bis 1000, Hintergrundfarbe, visibility:collapse und gemeinsame Rahmen. Kein eigener Flussinhalt; Schrift/Ausrichtung wird nicht an Zellen vererbt. Keine veralteten width-/align-Attribute."},
	colgroup = {Render="column",Support="supported",Defaults={TableRole="column-group"},Description="Tabellenspaltengruppe",Limitations="col-Kinder oder span ohne col-Kinder; CSS-Breite als Vorgabe pro Spalte, Hintergrundfarbe und gemeinsame Rahmen bei collapse. Keine eigenen Flussboxen."},
	table = {Render="block",Support="supported",Defaults={TableRole="table",BorderSpacing={2,2},BoxSizing="border-box"},Description="Tabelle",Limitations="Automatische/feste Spaltenbreiten, separate/collapse, border-spacing, colspan/rowspan, col/colgroup, caption, Zeilen-/Gruppenfarben und empty-cells. Vollständiges CSS-Tabellenmodell fehlt; siehe docs/TABLES.md."},
	tr = {Render="block",Support="supported",Defaults={TableRole="row"},Description="Tabellenzeile",Limitations="Gemeinsame Spaltenbreiten und Zeilenhöhe innerhalb table."},
	td = {Render="block",Support="supported",Defaults={TableRole="cell",Padding={1,1,1,1},VerticalAlign="middle"},Description="Tabellenzelle",Limitations="Text, Bilder, Controls und Blockinhalt; separate/gemeinsame Rahmen, Padding und vertikale Ausrichtung. colspan und rowspan einschließlich rowspan=0; implizite Zusatzzeilen ohne DOM-/GUI-Knoten. Rastergrenze 65534 Zeilen und 4096 Spalten."},
	th = {Render="block",Support="supported",Defaults={TableRole="cell",Padding={1,1,1,1},VerticalAlign="middle",FontWeight=700,TextAlign="center"},Description="Tabellenüberschrift",Limitations="Wie td; standardmäßig fett und zentriert."},
	thead = {Render="block",Support="supported",Defaults={TableRole="group"},Description="Tabellenkopf",Limitations="Zeilengruppe; vor Körper und Fuß dargestellt. Kein wiederholter Druckkopf."},
	tbody = {Render="block",Support="supported",Defaults={TableRole="group"},Description="Tabellenkörper",Limitations="Zeilengruppe; direkte tr ohne explizites tbody ebenfalls erlaubt."},
	tfoot = {Render="block",Support="supported",Defaults={TableRole="group"},Description="Tabellenfuß",Limitations="Zeilengruppe nach dem Tabellenkörper."},
	details = {Render="block",Support="supported",Description="Aufklappbarer Inhalt",Limitations="open, erster summary-Titel, Maus/Touch und Enter/Leertaste; Inhalt und Formularwerte bleiben erhalten. Keine name-Akkordeongruppen oder dynamische CSS-Neuberechnung für [open]."},
	summary = {Render="block",Support="supported",Description="Titel eines Aufklappbereichs",Limitations="Erstes direktes summary eines details ist aktiv, mit Dreieckspfeil; weitere summary sind normale Blöcke. Standardmarker angenähert, kein ::marker-CSS."},
	dialog = {Render="block",Support="supported",Defaults={Position="absolute",Padding={16,16,16,16},Background=Color3.new(1,1,1),BorderWidth=3,BorderStyle="solid",BorderColor=Color3.fromRGB(0,0,0)},Description="Dialogfenster",Limitations="show/showModal/close/requestClose, commandfor, ::backdrop, Escape, closedby, Fokusbegrenzung und form method=dialog. CSS-Positionierung im normalen Fluss und in der Top Layer; vollständige Cross-Realm-/Accessibility-Semantik bleibt offen."},
	fieldset = {Render = "block", Support="supported", Defaults = {Margin = {0, 2, 0, 2}, BorderWidth = 2, BorderStyle = "groove", BorderColor = Color3.fromRGB(192, 192, 192)}, Description = "Formulargruppe mit Rahmen", Limitations = "Erste sichtbare, nicht absolut positionierte Legende unterbricht den oberen Rahmen; disabled mit Ausnahme der ersten DOM-Legende. Horizontales LTR-Layout; keine dynamischen Attribute oder fieldset.elements-API."},
	legend = {Render = "block", Support="supported", Defaults = {Padding = {0, 2, 0, 2}}, Description = "Beschriftung einer Formulargruppe", Limitations = "Im fieldset an der oberen Rahmenkante, automatisch auf Inhaltsbreite begrenzt; weitere Legenden sind normale Blöcke."},
	wbr = {Render = "soft-break", Void = true, Support="supported", Description = "Optionale Umbruchstelle", Limitations = "Ohne sichtbares Zeichen; nowrap/pre unterdrücken den Umbruch."},
	address = {Render = "block", Support="supported", Defaults = {FontStyle = "italic"}, Description = "Kontaktangaben", Limitations = "Kursiver Block ohne eigene Standardabstände; keine Kontaktaktionen."},
	dl = {Render = "block", Support="supported", Description = "Beschreibungsliste", Limitations = "Oben/unten 1em, in ul/ol/dl verschachtelt 0; keine Aufzählungsmarker."},
	dt = {Render = "block", Support="supported", Description = "Begriff einer Beschreibungsliste", Limitations = "Normaler Block ohne zusätzliche Standardabstände oder Fettschrift."},
	dd = {Render = "block", Support="supported", Defaults = {Margin = {0, 0, 0, 40}}, Description = "Beschreibung eines Begriffs", Limitations = "40px Einzug links; horizontale Schreibrichtung LTR."},
	figure = {Render = "block", Support="supported", MarginBlockEm = 1, MarginInlinePx = 40, Description = "Eigenständige Abbildung oder Darstellung", Limitations = "1em oben/unten, 40px links/rechts; normales Blocklayout für Inhalt und Beschriftung."},
	figcaption = {Render = "block", Support="supported", Description = "Beschriftung einer Abbildung", Limitations = "Normaler Block in DOM-Reihenfolge, ohne eigene Standardabstände oder Zentrierung."},
	ins = {Render = "inline", Support="supported", Defaults = {TextDecoration = {Underline = true}}, Description = "Eingefügter Text", Limitations = "Unterstrichen; keine Änderungsverfolgung. Linien wie u."},
	kbd = {Render = "inline", Support="supported", Defaults = {Font = "Roboto Mono"}, Description = "Tastatureingabe", Limitations = "Monospace wie code; keine Tastaturbedienung."},
	samp = {Render = "inline", Support="supported", Defaults = {Font = "Roboto Mono"}, Description = "Programmausgabe", Limitations = "Monospace wie code; keine Ausführung."},
	var = {Render = "inline", Support="supported", Defaults = {FontStyle = "italic"}, Description = "Variable", Limitations = "Kursiv wie i; keine Auswertung."},
	cite = {Render = "inline", Support="supported", Defaults = {FontStyle = "italic"}, Description = "Werktitel", Limitations = "Kursiv wie i; keine Navigation."},
	dfn = {Render = "inline", Support="supported", Defaults = {FontStyle = "italic"}, Description = "Definierter Begriff", Limitations = "Kursiv wie i; keine title-Tooltips."},
	small = {
		Render = "inline", Support="supported", Defaults = {FontSize = "smaller"},
		Description = "Kleiner gesetzter Text", Limitations = "Elternschrift / 1.2, mindestens 1px, ohne Grundlinienversatz. Bestehende Fragment-/Fontmetriken-Näherungen gelten.",
	},
	code = {
		Render = "inline", Support="supported", Defaults = {Font = "Roboto Mono"},
		Description = "Inline-Code in Monospace", Limitations = "Monospace wird auf Roboto Mono abgebildet; keine Syntaxhervorhebung oder Ausführung. Leerraum folgt dem geerbten white-space.",
	},
	pre = {
		Render = "block", Support="supported", Defaults = {Font = "Roboto Mono", WhiteSpace = "pre"},
		Description = "Vorformatierter Text", Limitations = "Monospace über Roboto Mono, 1em vertikale Außenabstände, erhaltener Leerraum. Erster unmittelbarer LF wird im Parser entfernt. Kein historisches wrap-Attribut oder vollständiges Browser-Fontmapping.",
	},
	blockquote = {
		Render = "block", Support="supported",
		Description = "Eingerücktes Blockzitat", Limitations = "Standardränder oben/unten 1em, links/rechts 40px. Absatzränder am offenen Rand fallen zusammen; cite wird nur im DOM gespeichert.",
	},
	hr = {
		Render = "block", Support="supported",
		Defaults = {BorderWidth = 1, BorderStyle = "inset", Color = Color3.fromRGB(128, 128, 128), OverflowX = "hidden", OverflowY = "hidden"},
		Description = "Horizontale Trennlinie", Limitations = "Standard 1px Inset-Rahmen, 0.5em vertikale Ränder, horizontal zentriert. Keine historischen size/noshade/color-Attribute.",
	},
	mark = {
		Render = "inline", Support="supported", Defaults = {Background = Color3.fromRGB(255, 255, 0), Color = Color3.new(0, 0, 0)},
		Description = "Hervorgehobener Text", Limitations = "Farbiger Texthintergrund ohne zusätzliches Padding; Fontbox-Höhe angenähert. Keine Inline-Rahmen oder verschachtelten Hintergrundebenen.",
	},
	menu = {
		Render = "block", Support="supported", Defaults = { Padding = {0, 0, 0, 40} },
		Description = "Listenartige Befehlsgruppe", Limitations = "Standarddarstellung wie ul mit li-Markern, Verschachtelung und list-style-type. Keine eigene Befehls-API oder historische toolbar-Semantik.",
	},
	noscript = {
		Render = "block", Support="supported",
		Description = "Fallback bei deaktiviertem JavaScript", Limitations = "Bei aktivierter Scripting-Flagge als Rohtext geparst und nicht dargestellt; bei deaktivierter Flagge im body als HTML-Fallback sichtbar. HTMLPage setzt die Flagge aus options.JavaScript, unabhängig von Skriptpräsenz oder Laufzeitfehlern. Vollständige spezielle in-head-Fehlerkorrekturregeln fehlen.",
	},
	sup = {
		Render = "inline", Support="supported", Defaults = {FontSize = "smaller", VerticalAlign = "super", LineHeight = {Kind = "normal"}},
		Description = "Hochgestellter Text", Limitations = "Chromium-Näherung: Elternschrift / 1.2, Grundlinie um Elternschrift / 3 + 1px höher. Teilwörter bleiben untrennbar; Kerning über Stilgrenzen fehlt.",
	},
	sub = {
		Render = "inline", Support="supported", Defaults = {FontSize = "smaller", VerticalAlign = "sub", LineHeight = {Kind = "normal"}},
		Description = "Tiefgestellter Text", Limitations = "Chromium-Näherung: Elternschrift / 1.2, Grundlinie um Elternschrift / 5 + 1px tiefer. Teilwörter bleiben untrennbar; Kerning über Stilgrenzen fehlt.",
	},
	ul = {
		Render = "block", Support="supported", Defaults = { Padding = {0, 0, 0, 40} },
		Description = "Ungeordnete Liste", Limitations = "Außenmarker disc/circle/square nach Tiefe; 1em vertikale Standardabstände, verschachtelt 0. Innenmarker über list-style-position; keine Markerbilder oder RTL.",
	},
	ol = {
		Render = "block", Support="supported", Defaults = { Padding = {0, 0, 0, 40} },
		Description = "Nummerierte Liste", Limitations = "Dezimale, alphabetische oder römische Außenmarker über list-style-type; start/reversed und li value. Innenmarker über list-style-position; kein RTL.",
	},
	li = {
		Render = "block", Support="supported",
		Description = "Listeneintrag", Limitations = "Marker an erster Textgrundlinie; außen Folgezeilen bündig zum Text, innen zum linken Inhaltsrand. Marker-Fontmetriken angenähert; keine ::marker-Regeln.",
	},
	u = {
		Render = "inline", Support="supported", Defaults = { TextDecoration = { Underline = true } },
		Description = "Unterstrichener Text", Limitations = "Linienabstand und Dicke skalieren mit der CSS-Schriftgröße; vereinfachtes skip-ink. Kein Kerning über Stilgrenzen oder Font-Einzelkalibrierung.",
	},
	s = {
		Render = "inline", Support="supported", Defaults = { TextDecoration = { Strike = true } },
		Description = "Durchgestrichener Text", Limitations = "Position und Dicke geschätzt; kein Kerning über Stilgrenzen.",
	},
	del = {
		Render = "inline", Support="supported", Defaults = { TextDecoration = { Strike = true } },
		Description = "Als gelöscht markierter, durchgestrichener Text", Limitations = "Nur Darstellung; keine Änderungsverfolgung.",
	},
	html = {
		Render = "block", Support="supported",
		Description = "Äußerer HTML-Container",
		Limitations = "parseDocument/mountHTML und DOM-Kontextfragmente verwenden den Tree-Builder mit Fehlerkorrektur. parseHTML behält seinen allgemeinen Fragmentvertrag; Streaming/Encoding und parserbegleitende Scriptfälle sind nicht vollständig. Nachweise: HTML-PARSER-ATTRIBUTES-20261006.md.",
	},
	body = {
		Render = "block", Support="supported",
		Description = "Seiteninhalt", Defaults = { Margin = { 8, 8, 8, 8 } },
		Limitations = "Im Dokumentmodus automatisch vorhanden. Einfaches Box-Modell; Margin-Collapsing zwischen Blockgeschwistern, noch nicht allgemein zwischen Eltern und Kindern. Keine vollständige Viewport-Übertragung der body-Eigenschaften.",
	},
	div = {
		Render = "block", Support="supported",
		Description = "Verschachtelbarer Blockcontainer",
		Limitations = "Block- und Flexlayout, Box-Größen, Abstände, Rahmen, overflow hidden/visible und relative/absolute Positionierung. Kein Grid; Details FLEXBOX.md und POSITIONING.md.",
	},
	p = {
		Render = "block", Support="supported",
		Description = "Textabsatz", Defaults = { Margin = { 16, 0, 16, 0 } },
		Limitations = "Eigene Wortumbrüche, line-height, gemeinsame Grundlinie und text-align left/center/right/justify; Fontmetriken bleiben Näherungen.",
	},
	h1 = {
		Render = "block", Support="supported",
		Description = "Überschrift erster Ebene",
		Defaults = { FontSize = 32, FontWeight = 700, Margin = { 20, 0, 20, 0 } },
		Limitations = "Größerer, fetter Text; durch CSS überschreibbar. Bold-Linienmetriken sind noch nicht separat kalibriert.",
	},
	h2 = {
		Render = "block", Support="supported",
		Description = "Überschrift zweiter Ebene",
		Defaults = { FontSize = 24, FontWeight = 700, Margin = { 16, 0, 16, 0 } },
		Limitations = "Größerer, fetter Text; durch CSS überschreibbar. Bold-Linienmetriken sind noch nicht separat kalibriert.",
	},
	h3 = {
		Render = "block", Support="supported", Defaults = {FontWeight = 700}, FontSizeScale = 1.17, MarginBlockEm = 1,
		Description = "Überschrift dritter Ebene", Limitations = "1.17-fache Elternschrift, vertikale Ränder 1em der eigenen Schriftgröße. Fontmetriken angenähert; keine allgemeine CSS-em-Unterstützung.",
	},
	h4 = {
		Render = "block", Support="supported", Defaults = {FontWeight = 700}, FontSizeScale = 1, MarginBlockEm = 1.33,
		Description = "Überschrift vierter Ebene", Limitations = "Elternschriftgröße, vertikale Ränder 1.33em der eigenen Schriftgröße. Fontmetriken angenähert.",
	},
	h5 = {
		Render = "block", Support="supported", Defaults = {FontWeight = 700}, FontSizeScale = 0.83, MarginBlockEm = 1.67,
		Description = "Überschrift fünfter Ebene", Limitations = "0.83-fache Elternschrift, vertikale Ränder 1.67em der eigenen Schriftgröße. Fontmetriken angenähert.",
	},
	h6 = {
		Render = "block", Support="supported", Defaults = {FontWeight = 700}, FontSizeScale = 0.67, MarginBlockEm = 2.33,
		Description = "Überschrift sechster Ebene", Limitations = "0.67-fache Elternschrift, vertikale Ränder 2.33em der eigenen Schriftgröße. Fontmetriken angenähert.",
	},
	span = {
		Render = "inline", Support="supported",
		Description = "Text innerhalb eines Absatzes",
		Limitations = "Textstile und Hintergrund auch auf zusammenhängenden Wortteilen; baseline/super/sub. Kein Kerning über Stilgrenzen, Inline-Padding oder Inline-Rahmen; leere Spans belegen keinen Platz.",
	},
	br = {
		Render = "break", Support="supported",
		Description = "Fester Zeilenumbruch",
		Limitations = "display:none unterdrückt den Umbruch gemäß CSS-Cascade. Sonst schließt br die aktuelle Zeile; Leerzeilen verwenden den Absatzstil, weitere eigene Formatierung fehlt.",
	},
	a = {
		Render = "inline", Support="supported", Defaults = {Color = Color3.fromRGB(0, 0, 238), TextDecoration = {Underline = true}},
		Description = "Hyperlink", Limitations = "href-Klicks, relative/absolute Website-Pfade, Fragmente und Navigations-Callback; target/download/rel/hreflang/type/referrerpolicy/ping werden als Metadaten übergeben. Externe URLs benötigen einen Callback. Native Downloads sind nicht implementiert.",
	},
	b = {
		Render = "inline", Support="supported", Defaults = { FontWeight = 700 },
		Description = "Fetter Text", Limitations = "Gewicht 700; kein relatives bolder/900 bei Verschachtelung. Kein Kerning über Stilgrenzen.",
	},
	strong = {
		Render = "inline", Support="supported", Defaults = { FontWeight = 700 },
		Description = "Wichtiger Text, standardmäßig fett", Limitations = "Gewicht 700; kein relatives bolder/900 bei Verschachtelung. Kein Kerning über Stilgrenzen.",
	},
	em = {
		Render = "inline", Support="supported", Defaults = { FontStyle = "italic" },
		Description = "Betonter Text, standardmäßig kursiv", Limitations = "Durch CSS überschreibbar und mit Fett kombinierbar. Kein Kerning über Stilgrenzen; Kursiv-Linienmetriken sind noch nicht separat kalibriert.",
	},
	i = {
		Render = "inline", Support="supported", Defaults = { FontStyle = "italic" },
		Description = "Kursiver Text", Limitations = "Durch CSS überschreibbar und mit Fett kombinierbar. Kein Kerning über Stilgrenzen; Kursiv-Linienmetriken sind noch nicht separat kalibriert.",
	},
	head = {
		Render = "hidden", Support="supported",
		Description = "Dokumentkopf", Limitations = "Unsichtbarer DOM-Teilbaum mit dynamischem Titel, base, meta, Stylesheets und Scripts. Normative Tree-Builder-Fälle sind geprüft; parserbegleitende Scripts und Streaming bleiben offen. Siehe docs/HTML-PARSER-ATTRIBUTES-20261006.md.",
	},
	script = {
		Render = "hidden", Support = "supported",
		Description = "Script-Rohtext", Limitations = "Klassische Scripts, Module und dynamische Einfügungen laufen im eigenen JavaScript-Runtimeprofil. Parserbegleitendes Laden/document.write und Host-/Syntaxgrenzen bleiben dokumentiert. Siehe docs/JAVASCRIPT-IMPLEMENTATION.md.",
	},
	style = {
		Render = "hidden", Support="supported",
		Description = "CSS-Regeln", Limitations = "Gemeinsamer CSS-/Selektor-/Kaskadenpfad einschließlich unterstützter At-Regeln, Pseudoklassen, Attribute, lokalen Imports und CSSOM-Änderungen. Kein pauschaler Nachweis sämtlicher CSS-Regeln. Siehe docs/CSS-ATELIER-20261007.md.",
	},
	title = {
		Render = "hidden", Support="supported",
		Description = "Dokumenttitel", Limitations = "Erstes title liefert page.Title und das Root-Attribut Title mit zusammengefasstem ASCII-Leerraum; DOM-Änderungen aktualisieren beide. Keine native Roblox-Titelleiste.",
	},
	meta = {
		Render = "hidden", Support="supported",
		Description = "Metadaten", Limitations = "Dynamische Metadaten, viewport/theme-color/referrer und Content-Language-Pragma. Explizite Bytequellen unterstützen BOM/Transport/Meta-Encoding und begrenzten Neustart; bereits decodierte Strings werden nicht umcodiert. Weitere Pragmas/Streaming offen. Siehe docs/JAVASCRIPT-TEXT-DATA-20261005.md.",
	},
	link = {
		Render = "hidden", Support="supported",
		Description = "Verknüpfte Ressource", Limitations = "Lokale rel=stylesheet-Ressourcen aus options.Stylesheets werden mit base-URL, type, media und disabled ausgewertet. Keine Netzabfrage, Preload-, Icon-, Manifest- oder Ladeereignisse.",
	},
	img = {
		Render = "image", Support="supported",
		Description = "Inline-Bild", Limitations = "src/srcset/sizes sowie picture/source über options.Images; alt, width/height, CSS-Größen mit aspect-ratio, object-fit fill/contain/cover/none/scale-down, object-position, vertical-align, Bildkarten und Boxmodell. Responsive Auswahl erfolgt beim Mount. Rundung bei ungleichem Padding angenähert. Siehe docs/IMAGES.md.",
	},
	iframe = {
		Render = "iframe", Support="supported",
		Defaults = {BorderSize = 2, BorderStyle = "inset", BorderColor = Color3.fromRGB(118, 118, 118)},
		Description = "Eingebettete Website",
		Limitations = "Interne registrierte Websites und srcdoc werden in einer unabhängigen, scrollbar begrenzten PageSession dargestellt; Standardgröße 300×150, width/height und CSS-Boxmodell. Maximale Verschachtelungstiefe vier. Externe Websites, sandbox-Berechtigungen, allow, credentialless und echte Browser-Prozesse fehlen.",
	},
	object = {
		Render = "embedded", Support="supported",
		Description = "Eingebettetes Dokument mit Ersatzinhalt",
		Limitations = "Interne HTML-Websites aus data und type=text/html werden als unabhängige PageSession dargestellt. Ohne data oder bei nicht unterstütztem MIME-Typ erscheint der Kindinhalt. Bilder, Plugins, form-Zuordnung und externe Ressourcen fehlen.",
	},
	embed = {
		Render = "embedded", Support="supported",
		Description = "Eingebettete externe Ressource",
		Limitations = "Interne HTML-Websites aus src und type=text/html werden als unabhängige PageSession dargestellt. Nicht unterstützte MIME-Typen zeigen einen lokalen Fehlerzustand. Bilder, Plugins und externe Ressourcen fehlen.",
	},
	input = {
		Render = "control", Support="supported",
		Description = "Standard-Eingabetypen", Limitations = "Text/Search/Tel/Email/URL/Password, Number/Range, Checkbox/Radio, Color, Date/Datetime-local/Month/Week/Time, Buttons/Image/Hidden und File-Darstellung. Eigene Picker, lokale Validierung und Formularsteuerung; echte OS-Dateiauswahl fehlt. Unbekannte Typen fallen auf Text zurück; Profile in FORMS.md und HTML-INPUT-TYPES-20261006.md.",
	},
	button = {
		Render = "control", Support="supported",
		Description = "Schaltfläche", Limitations = "button/submit/reset mit nativer Aktivierung, disabled, Formularbezug und formatierten Text-/Bildinhalten über den normalen Renderer. Der erste Select-Button ist inert; Grenzen eigener Controls in FORMS.md.",
	},
	textarea = {Render="control",Support="supported",Description="Mehrzeilige Texteingabe",Limitations="Native TextBox; rows/cols, readonly, disabled, maxlength. 12px-EditableImage-Ziehgriff, resize none/both/horizontal/vertical; Maus/Touch ohne Cursorwechsel."},
	select = {Render="control",Support="supported",Description="Dropdown und Auswahliste",Limitations="Einfach-/Mehrfachauswahl, size, Optgroups, Submit/Reset, Tastatur-Präfixsuche, fixe/inhaltsabhängige Maße und tiefe selectedcontent-Momentaufnahmen. Rich-Ansichten, formatierte Pickeroptionen und Pseudoelemente unter appearance:base-select; Base-Dropdowns ohne ersten Button, Rich-Darstellungswechsel und vollständige Pickergeometrie/-effekte noch offen, siehe FORMS.md."},
	datalist = {Render="hidden",Support="supported",Description="Vorschlagsliste für input[list]",Limitations="Option-Werte für editierbare Text-, E-Mail-, URL- und Zahlenfelder; Filterung, Maus sowie Pfeiltasten/Enter/Escape. Keine browserabhängigen nativen Picker für Datum, Farbe oder Range-Markierungen."},
	option = {Render="hidden",Support="supported",Description="Auswahloption",Limitations="Text, label, value, selected und disabled innerhalb select; value/label innerhalb datalist. Keine vollständige HTMLOptionElement-API."},
	optgroup = {Render="hidden",Support="supported",Description="Optionsgruppe",Limitations="label als nicht auswählbare fette Überschrift im Dropdown, Optionen eingerückt; disabled sperrt die ganze Gruppe. Kein individuelles Gruppen-CSS oder legend-Inhalt."},
	selectedcontent = {Render="inline",Support="supported",Description="Kopie des gewählten Optionsinhalts",Limitations="Tiefe Momentaufnahme bei Parser-/Auswahl-/Resetpfaden, dynamischen Spiegeln und Moduswechseln. Option-Textänderungen allein verändern die Kopie nicht. Richdarstellung unter appearance:base-select; eigene Popup-Zeilen bleiben Teil des Select-Profils."},
	output = {Render="control",Support="supported",Description="Formularausgabe",Limitations="Text über page:SetValue; keine automatische Berechnung."},
	progress = {Render="control",Support="supported",Description="Fortschrittsbalken",Limitations="value/max; ohne value laufender Balken. Passive Frames; page:SetValue ohne Layout. Horizontale Darstellung."},
	meter = {Render="control",Support="supported",Description="Messwertbalken",Limitations="value/min/max/low/high/optimum; grün/gelb/rot. Passive Frames; kein Formularfeld, horizontale Darstellung."},
	label = {Render="inline",Support="supported",Description="Feldbeschriftung",Limitations="for-Attribut oder verschachteltes Control; Klick aktiviert/fokussiert das Feld."},
	form = {Render="block",Support="supported",Description="Lokales Formular",Limitations="submit/reset und Feldwerte über Luau; kein HTTP-Versand oder JavaScript."},
}

-- Catalog data is shared and read-only; resolved element styles own their values.
for _, entry in elements do
	if entry.Defaults then
		for _, value in entry.Defaults do
			if type(value) == "table" then table.freeze(value) end
		end
		table.freeze(entry.Defaults)
	end
	table.freeze(entry)
end
return table.freeze(elements)
