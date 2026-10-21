--!strict
-- Supported CSS in style blocks and attributes, exposed as Engine.CSSProperties.
-- Support is measured against the documented Roblox CSS profile, not full browser parity.
-- Every catalog entry is usable in that profile; Limitations define its intentional boundary.
-- InlineStyle uses Kind, Field and Inherited; value parsing remains in InlineStyle.
-- Lengths/numbers are bounded to 100000. New rendering behavior needs implementation too.
local properties: { [string]: any } = {
	['field-sizing']={Kind='enum',Field='FieldSizing',Inherited=false,Allowed={fixed=true,content=true},Values='fixed | content',Limitations='Select: feste bevorzugte Breite über alle Beschriftungen oder Inhaltsbreite des angezeigten Wertes; Listenhöhe nach Zeilenzahl. Text-/Dateieingaben und Textarea-Inhaltsgrößen sind noch nicht umgesetzt.'},
	['text-box-trim']={Kind='enum',Field='TextBoxTrim',Inherited=false,Allowed={none=true,['trim-start']=true,['trim-end']=true,['trim-both']=true},Values='none | trim-start | trim-end | trim-both',Limitations='Horizontale Textläufe: entfernt metrischen Überhang am ersten/letzten Zeilenrand. Fontmetrik aus unabhängigen kalibrierten Profilen, sonst geschätzt.'},
	['text-box-edge']={Kind='text-box-edge',Field='TextBoxEdge',Inherited=true,Values='auto | text | cap | ex; optional text | alphabetic am Ende',Limitations='Horizontale cap/ex/text- und alphabetic/text-Kanten. Keine vollständigen ideographischen Fontmetriken.'},
	['initial-letter']={Kind='initial-letter',Field='InitialLetter',Inherited=false,Values='normal | <number >= 1> [<integer >= 1> | drop | raise]?',Limitations='Horizontale Initialen; kalibrierte/geschätzte Glyphenmetrik statt nativer OpenType-Kapitelmetrik.'},
	['box-decoration-break']={Kind='enum',Field='BoxDecorationBreak',Inherited=false,Inline=true,Allowed={slice=true,clone=true},Values='slice | clone',Limitations='Horizontale, vertikale und sideways Inline-Zeilenfragmente: Hintergrundfarbe, Padding und physische gerade Rahmen, mit retained Paint und Quell-Auswahl. 240 native Achs-/Größenvergleiche; genaue native Font-Baselinekalibrierung getrennt offen. Keine Bildhintergründe, runden Fragmentkanten, Seiten-/Spaltenfragmentierung, fragmentierten Boxschatten, Inline-Deckkraftgruppen oder verschachtelten Dekorationsstapel.'},
	['border-shape']={Kind='border-shape',Field='BorderShape',Inherited=false,Values='none | circle(Länge/Prozent/closest-side at center)',Limitations='Zentrierte Kreiskontur mit einheitlichem solid-Rahmen und Hintergrundfarbe. Kein ellipse/polygon/path, Doppelkontur, Bildhintergrund, Formschatten oder geformtes Overflow-Clipping. EditableImage erforderlich; begrenzte Rasterauflösung.'},
	["all"]={Kind="css-wide-only",Field="All",Inherited=false,Inline=true,
		Values="initial | inherit | unset | revert | revert-layer",Limitations="Setzt registrierte Longhand-Gruppen zurück; direction, unicode-bidi und Custom Properties bleiben erhalten. Revert verwendet das vorhandene UA-Profil; eigene User-Stylesheet-Ursprünge fehlen."},
	["hyphens"]={Kind="enum",Field="Hyphens",Inherited=true,Allowed={none=true,manual=true,auto=true},Values="none | manual | auto",Limitations="manual berücksichtigt weiche Trennzeichen; auto verwendet die vorhandenen sprachabhängigen Musterressourcen. Ohne passende Sprachressource keine automatische Trennung. Sprachumfang und Zeilenprofil stehen in OVERFLOW-WRAP."},
	["hyphenate-character"]={Kind="hyphen-character",Field="HyphenateCharacter",Inherited=true,CaseSensitive=true,Values="auto | eine Zeichenkette",Limitations="auto verwendet einen Bindestrich; eine vollständige CSS-Zeichenkette einschließlich leerer Zeichenkette wird verwendet. Schriftabhängige Wahl des automatischen Trennzeichens bleibt ein eigenes Profil."},
	["hyphenate-limit-chars"]={Kind="hyphen-limit",Field="HyphenateLimitChars",Inherited=true,Values="[ auto | nichtnegative Ganzzahl ]{1,3}",Limitations="Begrenzt Mustertrennung mit Mindestwort-, Vorher-/Nachher-Längen; auto verwendet im vorhandenen Profil 5 2 2. Sprachabhängige Typografiestandards und weitere calc-Grammatik bleiben getrennt nachzuweisen."},
	["text-emphasis"]={Kind="text-emphasis",Field="TextEmphasisShorthand",Inherited=true,CaseSensitive=true,Values="Style und optional Farbe",Limitations="Erhaltene Markierungen pro berechtigtem Graphem gemäß Unicode 17; individuelle Wort-/Markenmessung und vertikale/sideways Projektion. Exakte Font-/Ruby-Kollisionsmetriken bleiben gesondert offen."},
	["text-emphasis-style"]={Kind="emphasis-style",Field="TextEmphasisStyle",Inherited=true,CaseSensitive=true,Values="none | filled/open dot/circle/double-circle/triangle/sesame | Zeichenkette",Limitations="Erhaltene Zeichen mit 50% der nativen Textgröße pro berechtigtem Graphem; Unicode-17-Kategorien, NFKD-Interpunktionsausnahmen und Separator+Combining-Mark. Leere Zeichenketten sind gültig, andere malen ihr erstes Graphem. Fehlende Fontglyphen/-ruby-Features brauchen einen weiteren Adapter."},
	["text-emphasis-color"]={Kind="color",Field="TextEmphasisColor",Inherited=true,Values="currentcolor | Farbe",Limitations="Farbe und Alpha der behaltenen Betonungszeichen; CSS-/WAAPI-Interpolation, Add/Accumulate, statisches symbolisches vs. animiertes aufgelöstes currentColor, Vererbung/Autorbasiswechsel/Importance/Commit/Cancel sind im C08-Profil geprüft. Uniforme Farben bleiben ohne Layout; neue explizite Quellaufteilung braucht erstes Layout. WAAPI-text-emphasis-Kurzform, diskrete Markenstile/-positionen, weitere Farbräume und reine Inline-/Pseudoziele bleiben offen."},
	["text-emphasis-position"]={Kind="emphasis-position",Field="TextEmphasisPosition",Inherited=true,Values="over | under, optional right | left",Limitations="over/under ist verpflichtend. Horizontale und sideways Typografie nutzt over/under, vertikale Typografie left/right. Aufrechte Marken, dynamische Positionen und Quell-/Poolerhaltung; genaue Fontbaselines und Ruby-/Dekorationskollisionen bleiben offen. Sideways-Markenorientierung ist in Level3 undefiniert; Engine behält sie aufrecht."},
	["quotes"]={Kind="quotes",Field="Quotes",Inherited=true,CaseSensitive=true,Values="auto | none | Paare aus Zeichenketten",Limitations="q sowie open-quote/close-quote in generiertem Inhalt; maximal acht verschachtelte Paare."},
	["writing-mode"]={Kind="enum",Field="WritingMode",Inherited=true,Allowed={["horizontal-tb"]=true,["vertical-rl"]=true,["vertical-lr"]=true,["sideways-rl"]=true,["sideways-lr"]=true},Values="horizontal-tb | vertical-rl | vertical-lr | sideways-rl | sideways-lr",Limitations="Vertikale Inline-Texte nutzen die Höhe als Umbruchachse. sideways-rl dreht horizontale Wortläufe um 90°; sideways-lr um −90° mit umgekehrter physischer Inlineachse. text-orientation beeinflusst diese zwei Modi nicht. Gerade Inlineflächen/-rahmen, Textlinien und Auswahllücken projizieren in die physischen Achsen. Vollständige vertikale Block-, Tabellen- und Ruby-Neuanordnung bleibt offen."},
	["text-orientation"]={Kind="enum",Field="TextOrientation",Inherited=true,Inline=true,Allowed={mixed=true,upright=true,sideways=true},Values="mixed | upright | sideways",Limitations="mixed nutzt Unicode17 UAX50 je Graphem: U/Tu/Tr aufrecht, R um90° gedreht; enclosing marks orientieren das ganze Graphem. upright trennt vertikale Em- und horizontale Fontzellen, mit LTR-Bidi-Verarbeitung bei unverändertem computed direction; die Zeilenausrichtung folgt computed direction. Native vertikale Fontmetriken/-alternates, Emoji-Joining und komplexe Block-/Ruby-/Tabellenachsen bleiben offen."},
	["ruby-align"]={Kind="enum",Field="RubyAlign",Inherited=true,Allowed={start=true,center=true,["space-between"]=true,["space-around"]=true},Values="start | center | space-between | space-around",Limitations="Richtet Basis und rt innerhalb der gemeinsamen Ruby-Spalte aus; die beiden space-Werte verwenden die zentrierte Roblox-Näherung."},
	["ruby-position"]={Kind="enum",Field="RubyPosition",Inherited=true,Allowed={over=true,under=true},Values="over | under",Limitations="Platziert die einzelne rt-Zeile ober- oder unterhalb des Basistexts."},
	["overscroll-behavior"]={Kind="axis-enum",Field="OverscrollBehavior",Inherited=false,Allowed={auto=true,contain=true,none=true},Values="auto | contain | none; ein oder zwei Achsen",Limitations="Steuert ElasticBehavior der nativen Overflow-ScrollingFrame; contain/none deaktivieren elastisches Überschwingen."},
	["overscroll-behavior-x"]={Kind="enum",Field="OverscrollX",Inherited=false,Allowed={auto=true,contain=true,none=true},Values="auto | contain | none",Limitations="Horizontale native Scrollfläche."},
	["overscroll-behavior-y"]={Kind="enum",Field="OverscrollY",Inherited=false,Allowed={auto=true,contain=true,none=true},Values="auto | contain | none",Limitations="Vertikale native Scrollfläche."},
	["overscroll-behavior-inline"]={Kind="enum",Field="OverscrollInline",Inherited=false,Allowed={auto=true,contain=true,none=true},Values="auto | contain | none",Limitations="Wird anhand direction auf die horizontale Achse abgebildet."},
	["overscroll-behavior-block"]={Kind="enum",Field="OverscrollBlock",Inherited=false,Allowed={auto=true,contain=true,none=true},Values="auto | contain | none",Limitations="Im horizontalen Roblox-Profil die vertikale Achse."},
	["scroll-snap-type"]={Kind="snap-type",Field="ScrollSnapType",Inherited=false,Values="none | x/y/block/inline/both [mandatory/proximity]",Limitations="Overflow-Container rasten nach Pointer-/Touch-Ende oder kurzer Mausradpause an direkten Nachfahren ein; der Übergang nutzt einen kurzen Sine-Tween."},
	["scroll-snap-align"]={Kind="snap-align",Field="ScrollSnapAlign",Inherited=false,Values="none | start | center | end; ein oder zwei Achsen",Limitations="Direkte Nachfahren eines Snap-Containers; horizontale und vertikale Ausrichtung."},
	["scroll-snap-stop"]={Kind="enum",Field="ScrollSnapStop",Inherited=false,Allowed={normal=true,always=true},Values="normal | always",Limitations="always markiert einen verpflichtenden Kandidaten; native Eingabe springt dennoch zum geometrisch nächsten Ziel."},
	["scroll-behavior"]={Kind="enum",Field="ScrollBehavior",Inherited=false,Allowed={auto=true,smooth=true},Values="auto | smooth",Limitations="smooth verwendet einen kurzen Sine-Tween für Fragmentnavigation und Engine-Scrollziele; direkte native Roblox-CanvasPosition-Änderungen bleiben sofort."},
	["scrollbar-gutter"]={Kind="scrollbar-gutter",Field="ScrollbarGutter",Inherited=false,Values="auto | stable [both-edges]",Limitations="stable reserviert die native Scrollleistenbreite bereits ohne Überlauf. both-edges reserviert symmetrischen Zusatzraum innerhalb der Inhaltsbreite."},
	["scroll-padding"]={Kind="scroll-spacing",Field="ScrollPadding",Inherited=false,Values="0 | nichtnegative px/%; 1–4 Werte",Limitations="Snapport-Abstand innerhalb der Overflow-Fläche."},
	["scroll-padding-top"]={Kind="length",Field="ScrollPadding",Side=1,Inherited=false,AllowPercent=true,Values="0 | nichtnegative px/%",Limitations="Vertikaler Startabstand des Snapports."},
	["scroll-padding-right"]={Kind="length",Field="ScrollPadding",Side=2,Inherited=false,AllowPercent=true,Values="0 | nichtnegative px/%",Limitations="Horizontaler Endabstand des Snapports."},
	["scroll-padding-bottom"]={Kind="length",Field="ScrollPadding",Side=3,Inherited=false,AllowPercent=true,Values="0 | nichtnegative px/%",Limitations="Vertikaler Endabstand des Snapports."},
	["scroll-padding-left"]={Kind="length",Field="ScrollPadding",Side=4,Inherited=false,AllowPercent=true,Values="0 | nichtnegative px/%",Limitations="Horizontaler Startabstand des Snapports."},
	["scroll-padding-block"]={Kind="scroll-axis-spacing",Field="ScrollPadding",LogicalSides={"block-start","block-end"},LogicalValues=true,Inherited=false,Values="ein oder zwei nichtnegative Längen/%",Limitations="Logische vertikale Snapport-Abstände."},
	["scroll-padding-block-start"]={Kind="scroll-length",Field="ScrollPadding",LogicalSides={"block-start"},Inherited=false,AllowPercent=true,Values="nichtnegative px/%",Limitations="Logischer Block-Startabstand."},
	["scroll-padding-block-end"]={Kind="scroll-length",Field="ScrollPadding",LogicalSides={"block-end"},Inherited=false,AllowPercent=true,Values="nichtnegative px/%",Limitations="Logischer Block-Endabstand."},
	["scroll-padding-inline"]={Kind="scroll-axis-spacing",Field="ScrollPadding",LogicalSides={"inline-start","inline-end"},LogicalValues=true,Inherited=false,Values="ein oder zwei nichtnegative Längen/%",Limitations="Logische horizontale Snapport-Abstände."},
	["scroll-padding-inline-start"]={Kind="scroll-length",Field="ScrollPadding",LogicalSides={"inline-start"},Inherited=false,AllowPercent=true,Values="nichtnegative px/%",Limitations="Logischer Inline-Startabstand."},
	["scroll-padding-inline-end"]={Kind="scroll-length",Field="ScrollPadding",LogicalSides={"inline-end"},Inherited=false,AllowPercent=true,Values="nichtnegative px/%",Limitations="Logischer Inline-Endabstand."},
	["scroll-margin"]={Kind="scroll-spacing",Field="ScrollMargin",Inherited=false,AllowNegative=true,Values="0 | signierte px/%; 1–4 Werte",Limitations="Außenabstand eines Snap-Kandidaten."},
	["scroll-margin-top"]={Kind="scroll-length",Field="ScrollMargin",Side=1,Inherited=false,AllowPercent=true,AllowNegative=true,Values="signierte px/%",Limitations="Snap-Außenabstand oben."},
	["scroll-margin-right"]={Kind="scroll-length",Field="ScrollMargin",Side=2,Inherited=false,AllowPercent=true,AllowNegative=true,Values="signierte px/%",Limitations="Snap-Außenabstand rechts."},
	["scroll-margin-bottom"]={Kind="scroll-length",Field="ScrollMargin",Side=3,Inherited=false,AllowPercent=true,AllowNegative=true,Values="signierte px/%",Limitations="Snap-Außenabstand unten."},
	["scroll-margin-left"]={Kind="scroll-length",Field="ScrollMargin",Side=4,Inherited=false,AllowPercent=true,AllowNegative=true,Values="signierte px/%",Limitations="Snap-Außenabstand links."},
	["scroll-margin-block"]={Kind="scroll-axis-spacing",Field="ScrollMargin",LogicalSides={"block-start","block-end"},LogicalValues=true,Inherited=false,AllowNegative=true,Values="ein oder zwei signierte Längen/%",Limitations="Logische vertikale Snap-Außenabstände."},
	["scroll-margin-block-start"]={Kind="scroll-length",Field="ScrollMargin",LogicalSides={"block-start"},Inherited=false,AllowPercent=true,AllowNegative=true,Values="signierte px/%",Limitations="Logischer Block-Startaußenabstand."},
	["scroll-margin-block-end"]={Kind="scroll-length",Field="ScrollMargin",LogicalSides={"block-end"},Inherited=false,AllowPercent=true,AllowNegative=true,Values="signierte px/%",Limitations="Logischer Block-Endaußenabstand."},
	["scroll-margin-inline"]={Kind="scroll-axis-spacing",Field="ScrollMargin",LogicalSides={"inline-start","inline-end"},LogicalValues=true,Inherited=false,AllowNegative=true,Values="ein oder zwei signierte Längen/%",Limitations="Logische horizontale Snap-Außenabstände."},
	["scroll-margin-inline-start"]={Kind="scroll-length",Field="ScrollMargin",LogicalSides={"inline-start"},Inherited=false,AllowPercent=true,AllowNegative=true,Values="signierte px/%",Limitations="Logischer Inline-Startaußenabstand."},
	["scroll-margin-inline-end"]={Kind="scroll-length",Field="ScrollMargin",LogicalSides={"inline-end"},Inherited=false,AllowPercent=true,AllowNegative=true,Values="signierte px/%",Limitations="Logischer Inline-Endaußenabstand."},
	["appearance"]={Kind="enum",Field="Appearance",Inherited=false,Inline=true,Replaced=true,Allowed={auto=true,none=true,button=true,textfield=true,menulist=true,["base-select"]=true},Values="auto | none | button | textfield | menulist | base-select",Limitations="none entfernt Roblox-Standardfüllung, Standardrahmen sowie Pfeil/Spinner des Steuerelements; base-select verwendet das anpassbare Select-Popup."},
	["caret-color"]={Kind="caret-color",Field="CaretColor",Inherited=true,Inline=true,Values="auto | currentcolor | Farbe",Limitations="Eigener Caret-Layer für einzeilige Textfelder und textarea; Position folgt CursorPosition mit gemessener Präfixbreite."},
	["caret-shape"]={Kind="enum",Field="CaretShape",Inherited=true,Inline=true,Allowed={auto=true,bar=true,block=true,underscore=true},Values="auto | bar | block | underscore",Limitations="Form des eigenen Caret-Layers; auto entspricht bar."},
	["caret-animation"]={Kind="enum",Field="CaretAnimation",Inherited=true,Inline=true,Allowed={auto=true,manual=true},Values="auto | manual",Limitations="auto blinkt mit dem nativen Fokuszustand angenähert; manual hält den eigenen Caret sichtbar."},
	["caret"]={Kind="caret",Field="CaretShorthand",Inherited=true,Inline=true,Values="caret-color und/oder caret-shape",Limitations="Setzt Farbe und Form des eigenen Caret-Layers gemeinsam."},
	["float"]={Kind="enum",Field="Float",Inherited=false,Allowed={none=true,left=true,right=true,["inline-start"]=true,["inline-end"]=true},Values="none | left | right | inline-start | inline-end",Limitations="Float-Bänder gelten für nachfolgende Textzeilen und normale verschachtelte Blöcke. Eigenständige Formatierungskontexte verwenden den rechteckigen Restbereich."},
	["clear"]={Kind="enum",Field="Clear",Inherited=false,Allowed={none=true,left=true,right=true,both=true,["inline-start"]=true,["inline-end"]=true},Values="none | left | right | both | inline-start | inline-end",Limitations="Verschiebt direkte Blockkinder unter passende aktive Floats."},
	["shape-outside"]={Kind="shape-outside",Field="ShapeOutside",Inherited=false,Values="none | circle(radius at center) | ellipse(rx ry at center) | url(local-image)",Limitations="Circle/ellipse und Alphaformen aus zugeordneten SVGs oder lesbaren Roblox-Bildassets. Bilder werden asynchron geladen und im Contentbereich ausgewertet; fehlende Quellen behalten die rechteckige Floatfläche. Keine Polygonformen."},
	["shape-image-threshold"]={Kind="shape-threshold",Field="ShapeImageThreshold",Inherited=false,Inline=true,Replaced=true,Values="Zahl oder Prozent, auf 0 bis 1 begrenzt",Limitations="Nur Bildformen; ausschließlich Pixel mit Alpha oberhalb des Schwellenwerts beeinflussen den Textumfluss."},
	["object-view-box"]={Kind="object-view-box",Field="ObjectViewBox",Inherited=false,Inline=true,Replaced=true,Values="none | inset(1–4 Längen/Prozent) | xywh(x y width height) | rect(top right bottom left)",Limitations="Rechteckiger Bildausschnitt vor object-fit/object-position. Keine runden Ausschnitte; bekannte natürliche Bildmaße erforderlich."},
	["image-orientation"]={Kind="enum",Field="ImageOrientation",Inherited=true,Inline=true,Replaced=true,Allowed={["from-image"]=true},Values="from-image",Limitations="Verwendet die von Roblox importierte Bildausrichtung. Rohes EXIF ist nicht verfügbar; none und manuelle Drehung/Spiegelung werden nicht unterstützt."},
	["image-resolution"]={Kind="enum",Field="ImageResolution",Inherited=true,Inline=true,Replaced=true,Allowed={["1dppx"]=true},Values="1dppx",Limitations="Native Bildpixel entsprechen CSS-Pixeln bei automatischer Größe. Andere Auflösungen und Metadaten-Dichte sind nicht implementiert."},
	["mask-type"]={Kind="enum",Field="MaskType",Inherited=false,Inline=true,Replaced=true,Allowed={alpha=true,luminance=true},Values="alpha | luminance",Limitations="Bestimmt SVG-mask-Ressourcen über den vorhandenen SVG-Rasterizer; auf normalen HTML-Boxen ohne Wirkung. Verlaufs-Masken verwenden mask-mode."},
	["shape-margin"]={Kind="length",Field="ShapeMargin",Inherited=false,AllowPercent=true,Values="nichtnegative Länge oder Prozent",Limitations="Abstand um circle/ellipse; Prozentwerte beziehen sich auf die Breite des umgebenden Blocks."},
	["column-count"]={Kind="column-count",Field="ColumnCount",Inherited=false,Values="auto | Ganzzahl 1–32",Limitations="Text wird an Zeilengrenzen aufgeteilt. Eigenständige Layouts und ersetzte Elemente bleiben ungeteilt; fragmentierte Blockrahmen und Hintergründe fehlen."},
	["column-width"]={Kind="column-width",Field="ColumnWidth",Inherited=false,Values="auto | positive Länge",Limitations="Bestimmt zusammen mit column-count die Anzahl bis maximal 32."},
	["column-height"]={Kind="column-height",Field="ColumnHeight",Inherited=false,Values="auto | nichtnegative Länge",Limitations="Feste Höhe einer Spaltenreihe; mit column-wrap:auto entstehen weitere Reihen."},
	["column-wrap"]={Kind="enum",Field="ColumnWrap",Inherited=false,Allowed={auto=true,nowrap=true,wrap=true},Values="auto | nowrap | wrap",Limitations="Overflow-Spalten laufen rechts weiter oder bilden neue Reihen mit row-gap."},
	["columns"]={Kind="columns",Field="ColumnsShorthand",Inherited=false,Values="column-width und/oder column-count [/ column-height]",Limitations="Setzt width/count/height gemeinsam zurück; verfügbare Breite bestimmt die verwendete Spaltenzahl."},
	["column-fill"]={Kind="enum",Field="ColumnFill",Inherited=false,Allowed={auto=true,balance=true,["balance-all"]=true},Values="auto | balance | balance-all",Limitations="Gleicht Zeilenhöhen aus; auto füllt bei fester Höhe fortlaufend. balance-all entspricht ohne Seitenfragmentierung balance."},
	["column-span"]={Kind="enum",Field="ColumnSpan",Inherited=false,Allowed={none=true,all=true},Values="none | all",Limitations="all überspannt alle Spalten als eigene Zeile im Blockspaltenprofil."},
	["orphans"]={Kind="positive-integer",Field="Orphans",Inherited=true,Values="Ganzzahl 1–1000",Limitations="Mindestzahl von Absatzzeilen vor einem Spaltenumbruch; bei unteilbaren Inhalten kann die Spaltenhöhe wachsen."},
	["widows"]={Kind="positive-integer",Field="Widows",Inherited=true,Values="Ganzzahl 1–1000",Limitations="Mindestzahl von Absatzzeilen nach einem Spaltenumbruch."},
	["break-inside"]={Kind="enum",Field="BreakInside",Inherited=false,Allowed={auto=true,avoid=true,["avoid-column"]=true},Values="auto | avoid | avoid-column",Limitations="avoid hält direkte Blockkinder eines Mehrspaltencontainers zusammen; keine Seitenfragmentierung."},
	["break-before"]={Kind="enum",Field="BreakBefore",Inherited=false,Allowed={auto=true,avoid=true,["avoid-column"]=true,column=true},Values="auto | avoid | avoid-column | column",Limitations="Spaltenumbrüche vor Blockelementen im Mehrspaltenfluss; keine Seitenfragmentierung."},
	["break-after"]={Kind="enum",Field="BreakAfter",Inherited=false,Allowed={auto=true,avoid=true,["avoid-column"]=true,column=true},Values="auto | avoid | avoid-column | column",Limitations="Spaltenumbrüche nach Blockelementen im Mehrspaltenfluss; keine Seitenfragmentierung."},
	["column-rule"]={Kind="border",Field="ColumnRule",Inherited=false,Values="Breite Style Farbe",Limitations="Linie mittig im Spaltenabstand; gleiche Style-/Farbnäherungen wie Rahmen."},
	["column-rule-width"]={Kind="border-width",Field="ColumnRuleWidth",Inherited=false,Values="thin | medium | thick | px",Limitations="Breite der Spaltenlinie."},
	["column-rule-style"]={Kind="enum",Field="ColumnRuleStyle",Inherited=false,Allowed={none=true,hidden=true,solid=true,dotted=true,dashed=true,double=true},Values="none | hidden | solid | dotted | dashed | double",Limitations="Nicht-solide Styles verwenden die vorhandene Rahmenannäherung."},
	["column-rule-color"]={Kind="color",Field="ColumnRuleColor",Inherited=false,Values="currentcolor | Farbe",Limitations="Farbe der Spaltenlinie."},
	["line-clamp"]={Kind="line-clamp",Field="MaxLines",Inherited=false,Values="none | positive Ganzzahl",Limitations="Begrenzt Wortläufe auf 1–100 sichtbare Zeilen und setzt ein Auslassungszeichen. Gemischte Blocknachfahren werden nicht als gemeinsamer Absatz geklemmt."},
	["max-lines"]={Kind="line-clamp",Field="MaxLines",Inherited=false,Values="none | positive Ganzzahl",Limitations="Gleiche Roblox-Funktion wie line-clamp."},
	["contain"]={Kind="contain",Field="Contain",Inherited=false,Replaced=true,Values="none | strict | content | size | inline-size | layout | paint | style",Limitations="paint clippt Nachfahren an der rechteckigen Borderbox; size/inline-size verwenden bei verstecktem Inhalt contain-intrinsic-* als Ersatzgröße. Layout/style dienen als Isolationsmetadaten."},
	["container-type"]={Kind="container-type",Field="ContainerType",Inherited=false,Values="normal | [size | inline-size] || scroll-state",Limitations="Größenabfragen verwenden die Inhaltsbox des nächsten für alle abgefragten Achsen geeigneten Vorfahren. Style-Abfragen eigener Variablen benötigen keinen Größentyp; Scrollzustände verwenden Layout-/Scroll-Snapshots."},
	["container-name"]={Kind="ident-list",Field="ContainerNames",Inherited=false,CaseSensitive=true,Values="none | bis zu acht Bezeichner",Limitations="Benannte Größen-/Style-/Scrollcontainer für @container; Namen bleiben case-sensitive und unterstützen CSS-Escapes."},
	["container"]={Kind="container",Field="ContainerShorthand",Inherited=false,CaseSensitive=true,Values="container-name [ / container-type ]",Limitations="Setzt Name und Typ gemeinsam."},
	["content-visibility"]={Kind="enum",Field="ContentVisibility",Inherited=false,Allowed={visible=true,auto=true,hidden=true},Values="visible | auto | hidden",Limitations="hidden behält die eigene Box und lässt Nachfahren ungerendert; auto bleibt sichtbar, da Roblox keine zuverlässige Offscreen-Inhaltsmessung anbietet."},
	["contain-intrinsic-width"]={Kind="length",Field="ContainIntrinsicWidth",Inherited=false,Replaced=true,Values="nichtnegative Länge",Limitations="Ersatzbreite für versteckten size-Containment-Inhalt und auto-sized IMG."},
	["contain-intrinsic-height"]={Kind="length",Field="ContainIntrinsicHeight",Inherited=false,Replaced=true,Values="nichtnegative Länge",Limitations="Ersatzhöhe für versteckten size-Containment-Inhalt und auto-sized IMG."},
	["contain-intrinsic-inline-size"]={Kind="length",Field="ContainIntrinsicWidth",Inherited=false,Replaced=true,Values="nichtnegative Länge",Limitations="Horizontale Ersatzgröße im Roblox-Schreibprofil."},
	["contain-intrinsic-block-size"]={Kind="length",Field="ContainIntrinsicHeight",Inherited=false,Replaced=true,Values="nichtnegative Länge",Limitations="Vertikale Ersatzgröße im Roblox-Schreibprofil."},
	["contain-intrinsic-size"]={Kind="length-pair",Field="ContainIntrinsicShorthand",Inherited=false,Replaced=true,Values="eine oder zwei nichtnegative Längen",Limitations="Setzt contain-intrinsic-width und -height gemeinsam."},
	["clip-path"]={Kind="clip-path",Field="ClipPath",Inherited=false,Inline=true,Replaced=true,Values="none | inset(0 [round radius]) | circle(radius at center) | ellipse(rx ry at center) | polygon(x y, ...)",Limitations="Grundformen und Polygone mit bis zu 32 Punkten werden als Alphamaske gerastert; inset unterstützt nur Null-Inset und optional eine Rundung."},
	["mask-image"]={Kind="mask",Field="MaskImage",Inherited=false,Inline=true,Replaced=true,Values="none | bis 8 lineare, radiale oder konische Verlaufsmasken",Limitations="Einfacher linearer Verlauf als UIGradient mit zweidimensionalem Box-Ausschnitt; komplexe Masken als begrenztes Alpharaster für Text, Farben und Verlaufsflächen. Keine URL-Masken; externe Bilder, Medien und native Formulare im maskierten Raster werden nicht abgebildet."},
	["mask"]={Kind="mask",Field="MaskImage",Inherited=false,Inline=true,Replaced=true,Values="none | unterstützte mask-image",Limitations="Begrenzter Alias für mask-image."},
	["mask-mode"]={Kind="enum",Field="MaskMode",Inherited=false,Allowed={alpha=true},Values="alpha",Limitations="Roblox-Masken verwenden ausschließlich Alpha."},
	["mask-position"]={Kind="background-position",Field="MaskPositions",Inherited=false,Values="Position wie background-position",Limitations="Position der ersten zweistufigen Verlaufsmaske; Prozentwerte werden auf die Maskenfläche bezogen."},
	["mask-size"]={Kind="background-size",Field="MaskSizes",Inherited=false,Values="auto | cover | contain | Länge/%",Limitations="Größe der ersten Verlaufsmaske. Das sichtbare UIGradient-Profil unterstützt vor allem Prozentwerte entlang seiner Achse."},
	["mask-repeat"]={Kind="background-repeat",Field="MaskRepeats",Inherited=false,Values="repeat | no-repeat | repeat-x | repeat-y",Limitations="Wiederholung der ersten linearen Alpha-Maske entlang ihrer Verlaufsachse; space/round verwenden normale Wiederholung."},
	["mask-origin"]={Kind="background-box",Field="MaskOrigins",Inherited=false,Values="border-box | padding-box | content-box",Limitations="Zweidimensionale Bezugsbox der Verlaufsmaske; Listen werden für mehrere Rastermasken zyklisch verwendet."},
	["mask-clip"]={Kind="background-box",Field="MaskClips",Inherited=false,Values="border-box | padding-box | content-box",Limitations="Beschränkt die sichtbare Maske in beiden Achsen auf die gewählte Box, ohne ihre Layoutgröße zu verändern."},
	["mask-composite"]={Kind="enum",Field="MaskComposite",Inherited=false,Allowed={add=true,subtract=true,intersect=true,exclude=true},Values="add | subtract | intersect | exclude",Limitations="Komponiert mehrere Verlaufsmasken anhand ihrer Alpha-Werte von unten nach oben; ein Operator gilt für alle Ebenen. Einzelmasken bleiben unverändert."},
	["mask-border-source"]={Kind="mask",Field="MaskBorderSource",Inherited=false,Inline=true,Replaced=true,Values="none | linear-gradient(Richtung, Farbe, Farbe)",Limitations="Lineare Alpha-Verlaufsquelle; die Vollflächenvariante 0 fill / 0 / stretch wird unterstützt."},
	["mask-border-slice"]={Kind="mask-border-fill",Field="MaskBorderSlice",Inherited=false,Values="0 fill",Limitations="Nur die vollständig gefüllte Fläche mit null breiten Randsegmenten; sie entspricht der bestehenden linearen Vollflächenmaske."},
	["mask-border-width"]={Kind="mask-border-zero",Field="MaskBorderWidth",Inherited=false,Values="0",Limitations="Nur null breite Randsegmente im unterstützten 0-fill-Profil."},
	["mask-border-repeat"]={Kind="enum",Field="MaskBorderRepeat",Inherited=false,Allowed={stretch=true},Values="stretch",Limitations="Nur die gestreckte Vollflächenmaske."},
	["mask-border"]={Kind="mask",Field="MaskBorderSource",Inherited=false,Inline=true,Replaced=true,Values="none | linear-gradient(Richtung, Farbe, Farbe)",Limitations="Alias für die unterstützte mask-border-source-Verlaufsmaske; -webkit-mask-box-image wird für Browser-kompatible Testseiten gleich ausgewertet."},
	["border-image-source"]={Kind="border-image-source",Field="BorderImageSource",Inherited=false,Replaced=true,Values="none | url(...) | linear-gradient([Winkel oder Richtung,] 2–8 Farben)",Limitations="URL-Zuordnung aus options.Images als Slice-Image oder ein Verlaufsrahmen ohne explizite Stoppositionen."},
	["border-image"]={Kind="border-image",Field="BorderImageShorthand",Inherited=false,Replaced=true,Values="url(...) slice [ / width ] [stretch | round]",Limitations="Setzt die unterstützten Source-, Slice-, Width- und Repeat-Anteile gemeinsam."},
	["border-image-slice"]={Kind="number-sides",Field="BorderImageSlice",Inherited=false,Values="eine bis vier nichtnegative Zahlen/%",Limitations="Roblox SliceCenter verwendet die vier Werte als Quellpixel."},
	["border-image-width"]={Kind="number-sides",Field="BorderImageWidth",Inherited=false,Values="eine bis vier nichtnegative Zahlen",Limitations="Zahlen skalieren die jeweilige berechnete Rahmenbreite; Längen, Prozentwerte und auto fehlen."},
	["border-image-repeat"]={Kind="enum",Field="BorderImageRepeat",Inherited=false,Allowed={stretch=true,round=true},Values="stretch | round",Limitations="stretch und Roblox-Slice-Kachelung; getrennte Achsen fehlen."},
	["border-image-outset"]={Kind="number-sides",Field="BorderImageOutset",Inherited=false,Values="eine bis vier nichtnegative Zahlen",Limitations="Zahlen erweitern den gerenderten Border-Image-Layer um ein Vielfaches der jeweiligen Rahmenbreite; beeinflusst das Layout nicht."},
	["corner-shape"]={Kind="enum",Field="CornerShape",Inherited=false,Allowed={round=true,bevel=true,notch=true,squircle=true},Values="round | bevel | notch | squircle",Limitations="Wendet eine einheitliche Form auf alle gerundeten Ecken an; die Roblox-Rasterfläche glättet die Kontur mit 4×4-Supersampling."},
	["mix-blend-mode"]={Kind="enum",Field="MixBlendMode",Inherited=false,Allowed={normal=true,multiply=true,screen=true,difference=true},Values="normal | multiply | screen | difference",Limitations="Pixelweise Mischung mit gezeichneten Hintergründen/Geschwistern im begrenzten CPU-Kompositionsprofil; Farben bleiben berechnet unverändert. Solide/Verlaufsflächen, Text-/Canvasprofil, Alpha und gerundete Ecken; native Bild-/Formularpixel und vollständige Stacking-/Transformfälle fehlen. Maximal 64 Boxen, 512 Pixel pro Achse."},
	["background-blend-mode"]={Kind="enum-list",Field="BackgroundBlendMode",Inherited=false,Allowed={normal=true,multiply=true,screen=true},Values="normal | multiply | screen (kommagetrennte Ebenen)",Limitations="Mehrere vollständige Verlaufsflächen werden pixelweise komponiert; URL-Bilder und abweichende Größen/Positionen bleiben im Einzelbildprofil."},
	["isolation"]={Kind="enum",Field="Isolation",Inherited=false,Allowed={auto=true,isolate=true},Values="auto | isolate",Limitations="Isolierte CPU-Mischgruppen beginnen mit transparentem Backdrop; verschachtelte isolierte Gruppen und Deckkraft werden gemeinsam komponiert. Vollständige native CSS-Stacking-Contexts fehlen."},
	["backdrop-filter"]={Kind="backdrop-filter",Field="BackdropFilter",Inherited=false,Values="none | blur(px) [brightness()]",Limitations="Lokales Backdrop-Sampling fehlt Roblox; dargestellt als begrenzte transluzente Frostglasfläche mit Helligkeitsfaktor."},
	["offset-path"]={Kind="offset-path",Field="OffsetPath",Inherited=false,Replaced=true,CaseSensitive=true,Values="none | path(\"SVG-Pfad\") | ray(Winkel)",Limitations="SVG-Linien, Bézierkurven und Bögen mit absoluten/relativen Befehlen; adaptive Kurvennäherung mit begrenztem Punktbudget. Keine URL-Pfade oder Koordinatenboxen."},
	["offset-distance"]={Kind="length",Field="OffsetDistance",Inherited=false,AllowPercent=true,AllowNegative=true,Replaced=true,Values="signierte Länge/%",Limitations="Prozentwert entlang der unterstützten Pfadlänge; animierbar in @keyframes."},
	["offset-rotate"]={Kind="offset-rotate",Field="OffsetRotate",Inherited=false,Replaced=true,Values="auto | reverse | Winkel | auto Winkel",Limitations="Tangentenrotation auf Linien und adaptiv unterteilten Kurven."},
	["offset"]={Kind="offset",Field="OffsetShorthand",Inherited=false,Replaced=true,CaseSensitive=true,Values="offset-path [offset-distance] [offset-rotate] [ / offset-anchor ]",Limitations="Kurzform des SVG-Bewegungspfads; keine URL-Pfade oder Koordinatenboxen."},
	["offset-anchor"]={Kind="offset-anchor",Field="OffsetAnchor",Inherited=false,Replaced=true,Values="auto | Position",Limitations="Verankert einen Punkt der Box am Pfad; auto verwendet transform-origin."},
	["offset-position"]={Kind="offset-position",Field="OffsetPosition",Inherited=false,Replaced=true,Values="normal | Position",Limitations="Startpunkt für ray()-Pfade innerhalb der eigenen Referenzbox; path()-Koordinaten bleiben unverändert."},
	["perspective"]={Kind="length-none",Field="Perspective",Inherited=false,Values="none | positive Länge",Limitations="Homogene 3D-Projektion mit gemeinsamem Fluchtpunkt für Nachfahren; EditableImage erforderlich. Rasterprofil siehe docs/CSS-TRANSFORMS.md."},
	["perspective-origin"]={Kind="transform-origin",Field="PerspectiveOrigin",Inherited=false,Values="Position",NoZ=true},
	["transform-style"]={Kind="enum",Field="TransformStyle",Inherited=false,Allowed={flat=true,["preserve-3d"]=true},Values="flat | preserve-3d",Limitations="Gemeinsame 3D-Szene mit Tiefensortierung pro Pixel; flat und gruppierende Eigenschaften fassen Nachfahren zu einer Fläche zusammen. Maximal 64 Flächen pro Gruppe."},
	["backface-visibility"]={Kind="enum",Field="BackfaceVisibility",Inherited=false,Allowed={visible=true,hidden=true},Values="visible | hidden",Limitations="Rückseitenprüfung anhand der akkumulierten 4x4-Matrix, einschließlich verschachtelter Elterntransformationen."},
	["animation-timeline"]={Kind="timeline-list",Field="AnimationTimeline",Inherited=false,Values="auto | none | scroll() | benannter Zeitstrahl; Liste",Limitations="scroll() bindet Keyframes an den nächsten Roblox-ScrollingFrame; benannte Zeitstrahlen verwenden scroll-timeline-name."},
	["animation-trigger"]={Kind="timeline-list",Field="AnimationTimeline",Inherited=false,Values="auto | none | scroll() | benannter Zeitstrahl",Limitations="Roblox-Profil der Scroll-Trigger: verwendet dieselbe laufzeitgebundene Timeline wie animation-timeline."},
	["scroll-marker-group"]={Kind="enum",Field="ScrollMarkerGroup",Inherited=false,Allowed={none=true,before=true,after=true},Values="none | before | after",Limitations="Erzeugt anklickbare Roblox-Markierungen für direkte scroll-snap-align-Kinder vor oder nach dem Scrollbereich."},
	["animation-composition"]={Kind="motion-composition",Field="AnimationComposition",Inherited=false,Values="replace | add | accumulate; Liste",Limitations="add und accumulate addieren Translation/Rotation und multiplizieren Skalierung mit dem zugrunde liegenden Transform; Farbkomposition bleibt replace."},
	['interpolate-size']={Kind='enum',Field='InterpolateSize',Inherited=true,Allowed={['numeric-only']=true,['allow-keywords']=true},Values='numeric-only | allow-keywords',Limitations='Größenübergänge verbinden eine numerische Größe mit der gemessenen intrinsischen Endgröße; keine Interpolation zwischen zwei intrinsischen Schlüsselwörtern.'},
	['animation-range']={Kind='timeline-range',Field='AnimationRange',Inherited=false,Values='Start- und Endbereich einer Scroll-/View-Animation; Liste'},
	['animation-range-start']={Kind='timeline-range-start',Field='AnimationRangeStart',Inherited=false,Values='normal | Bereichsname [Länge/Prozent]; Liste'},
	['animation-range-end']={Kind='timeline-range-end',Field='AnimationRangeEnd',Inherited=false,Values='normal | Bereichsname [Länge/Prozent]; Liste'},
	['position-try-fallbacks']={Kind='position-try-fallbacks',Field='PositionTryFallbacks',Inherited=false,CaseSensitive=true,Values='none | [ <dashed-ident> || <try-tactic> ]#',Limitations='Bis zu acht benannte/gespiegelte Alternativen; geometrische Position-Area-Einträge und vollständige Fallback-Origin-/Scrollregeln benötigen weiteren Abgleich.'},
	["transition-behavior"]={Kind="transition-behavior",Field="TransitionBehavior",Inherited=false,Values="normal | allow-discrete; Liste",Limitations="Wird listenweise einschließlich transition-Shorthand gekoppelt. Box-Schattenlisten mit Inset-Wechsel schalten bei allow-discrete als ganze Liste bei 50%; display-/content-visibility-Exit-Transitions bleiben ausgeschlossen."},
	["scroll-timeline"]={Kind="scroll-timeline-shorthand",Field="ScrollTimelineShorthand",Inherited=false,CaseSensitive=true,Values="[ none | --Name ] [ block | inline | x | y ]?; kommaseparierte Liste",Limitations="Setzt Namen und Achsen atomar; an bestehende Animationstimeline und native Scrollfläche gebunden."},
	["scroll-timeline-name"]={Kind="scroll-timeline-names",Field="ScrollTimelineNames",Inherited=false,CaseSensitive=true,Values="none | Bezeichner",Limitations="Benannte Scrollzeitstrahlen am nächsten Scrollcontainer; maximal acht Namen."},
	["scroll-timeline-axis"]={Kind="scroll-timeline-axes",Field="ScrollTimelineAxes",Inherited=false,Allowed={["block"]=true,["inline"]=true,x=true,y=true},Values="block | inline | x | y",Limitations="block/y nutzt CanvasPosition.Y, inline/x CanvasPosition.X."},
	["accent-color"]={Kind="accent-color",Field="AccentColor",Inherited=true,Inline=true,Replaced=true,Values="auto | Farbe",Limitations="Checkbox, Radio, Range und progress verwenden die Akzentfarbe. meter behält seine semantischen Qualitätsfarben; Alpha wird für native Flächen auf die deckende RGB-Farbe reduziert."},
	["image-rendering"]={Kind="enum",Field="ImageRendering",Inherited=true,Inline=true,Replaced=true,Allowed={auto=true,smooth=true,["high-quality"]=true,["crisp-edges"]=true,pixelated=true},Values="auto | smooth | high-quality | crisp-edges | pixelated",Limitations="img und CSS-Hintergrundbilder: pixelated/crisp-edges verwenden ResampleMode.Pixelated, die übrigen Werte Robloxs Standardfilter. EditableImage-Raster werden weiterhin bei ihrer Erzeugung abgetastet."},
	["scroll-initial-target"]={Kind="enum",Field="ScrollInitialTarget",Inherited=false,Allowed={none=true,nearest=true},Values="none | nearest",Limitations="Erstes passendes Ziel des nächsten Scrollcontainers wird bei dessen erstem Layout positioniert."},
	["overflow-anchor"]={Kind="enum",Field="OverflowAnchor",Inherited=false,Allowed={auto=true,none=true},Values="auto | none",Limitations="Stabilisiert den sichtbaren Anker beim Neulayout nativer Scrollflächen; none schließt das Element und seine Nachfahren aus."},
	["scrollbar-color"]={Kind="scrollbar-color",Field="ScrollbarColor",Inherited=true,Values="auto | Daumenfarbe Spurfarbe",Limitations="Native Overflow-ScrollingFrames. Roblox bietet nur eine native Daumenfarbe; die Spurfarbe wird für dauerhaft sichtbare overflow:scroll-Spuren verwendet."},
	["scrollbar-width"]={Kind="enum",Field="ScrollbarWidth",Inherited=false,Allowed={auto=true,thin=true,none=true},Values="auto | thin | none",Limitations="Overflow-ScrollingFrames: 10px, 6px oder ausgeblendet. none erhält Scrollen per Rad/Touch; die Root-Seitenleiste bleibt durch die Host-Anwendung bestimmt."},
	["text-wrap-mode"]={Kind="enum",Field="TextWrapMode",Inherited=true,Allowed={wrap=true,nowrap=true},Values="wrap | nowrap",Limitations="Unabhängige Wrap-Achse für alle sechs white-space-collapse-Werte. nowrap unterdrückt weiche Umbrüche einschließlich Notumbrüchen/Silbentrennung, nicht br oder erhaltene LF."},
	["white-space-collapse"]={Kind="enum",Field="WhiteSpaceCollapse",Inherited=true,Allowed={collapse=true,discard=true,preserve=true,["preserve-breaks"]=true,["preserve-spaces"]=true,["break-spaces"]=true},Values="collapse | discard | preserve | preserve-breaks | preserve-spaces | break-spaces",Limitations="Getrennte Kollaps-/Wrap-Achsen: preserve-spaces ersetzt Tabs/Zeilenumbrüche durch erhaltene Leerzeichen; preserve-breaks kollabiert nur Spaces/Tabs, auch bei nowrap. Vollständige Unicode-/Bidi-/Trimregeln bleiben separat."},
	["text-wrap"]={Kind="text-wrap",Field="TextWrapShorthand",Inherited=true,Values="wrap | nowrap; optional auto | stable",Limitations="Setzt text-wrap-mode und text-wrap-style gemeinsam. auto/stable sind bei statischem Inhalt identisch; balance/pretty benötigen browserartige Absatzoptimierung und werden abgelehnt."},
	["text-wrap-style"]={Kind="enum",Field="TextWrapStyle",Inherited=true,Allowed={auto=true,stable=true},Values="auto | stable",Limitations="Statischer Inhalt ist bei auto und stable identisch. balance und pretty sind noch nicht Teil des Roblox-Profils."},
	["text-justify"]={Kind="enum",Field="TextJustify",Inherited=true,Allowed={auto=true,["inter-word"]=true,none=true},Values="auto | inter-word | none",Limitations="auto/inter-word verteilen vorhandene Wortabstände bei text-align:justify; none deaktiviert den Blocksatz. Kein inter-character oder sprachabhängiges Dehnen."},
	["text-underline-position"]={Kind="underline-position",Field="UnderlinePosition",Inherited=true,Values="auto | [from-font | under] || [left | right]",Limitations="Vertikale Typografie: left/right bestimmen die physische Unterstrichseite; Überstriche tauschen die Gegenseite. In horizontaler/sideways Typografie bleibt die Seitenangabe ohne Wirkung. under und benutzerdefinierter Offset kombinieren sich am Fontboxrand. from-font verwendet die dokumentierte Fontnäherung, da native Font-Unterstrichmetriken noch nicht angebunden sind."},
	["list-style-image"]={Kind="list-style-image",Field="ListStyleImage",Inherited=true,CaseSensitive=true,Values="none | url(...) ",Limitations="li-Marker aus options.Images, quadratisch in 1em Größe. Bei fehlender Zuordnung fällt der Marker auf list-style-type zurück; keine Gradienten oder marker-spezifische Objektanpassung."},
	["transition"]={Kind="transition",Field="TransitionShorthand",Inherited=false,Inline=true,Values="property duration [timing-function] [delay] [normal | allow-discrete], bis zu 16 Einträge",Limitations="Animiert die registrierten Transform-/Farb-/Box-Schatten-/Radius-/Schrift-/numerischen Layoutfamilien; siehe JAVASCRIPT-ANIMATION-LAYOUT.md. Letzter passender Listeneintrag, negative Delay und verkürzte Umkehr; zusätzliche Werttypen, direkte Inline-/Pseudoziele und vollständige intrinsische Größen bleiben offen."},
	["transition-property"]={Kind="transition-property",Field="TransitionProperty",Inherited=false,Inline=true,Values="none | all | CSS-Eigenschaftsbezeichner; Liste",Limitations="all umfasst nur die animierbaren Eigenschaften des Roblox-Profils. Unterstützte Shorthands background, margin, padding, inset, gap und flex wählen ihre animierbaren Longhands."},
	["transition-duration"]={Kind="motion-time",Field="TransitionDuration",Inherited=false,Inline=true,Values="Nichtnegative s/ms; Liste",Limitations="Maximal 16 Einträge; numerischer s/ms-Anteil bis 3600000."},
	["transition-timing-function"]={Kind="motion-timing",Field="TransitionTiming",Inherited=false,Inline=true,Values="linear | linear(...) | ease | ease-in | ease-out | ease-in-out | step-start | step-end | cubic-bezier(...) | steps(...); Liste",Limitations="Gemeinsamer CSS-/Script-Sampler mit numerischem Bezier-Solver und allen jump-Positionen. Maximal 2048 Zeichen und 128 linear-Kontrollpunkte je Funktion; steps bis 100000, Bezier-Kontrollwerte bis ±100."},
	["transition-delay"]={Kind="motion-delay",Field="TransitionDelay",Inherited=false,Inline=true,Values="s/ms einschließlich negativer Verzögerung; Liste",Limitations="Maximal 16 Einträge."},
	["animation"]={Kind="animation",Field="AnimationShorthand",Inherited=false,Inline=true,CaseSensitive=true,Values="name duration [timing] [delay] [iterations] [direction] [fill-mode] [play-state]",Limitations="Bis zu 16 CSS-Animationen; transform, offset-distance, opacity, background-color und die numerischen Layoutwerte aus AnimationValues. CSS-Komposition/Scroll-Timelines über Longhands; keine vollständigen CSS-Animationsereignisse, Pseudoelement-/Inlineziele oder auto-Größen."},
	["animation-name"]={Kind="animation-name",Field="AnimationName",Inherited=false,Inline=true,CaseSensitive=true,Values="none | Keyframe-Name; Liste",Limitations="Case-sensitive Bezeichner aus @keyframes derselben Seite oder ihres Shadow-Stylesheets; keine gequoteten Namen."},
	["animation-duration"]={Kind="motion-time",Field="AnimationDuration",Inherited=false,Inline=true,Values="Nichtnegative s/ms; Liste",Limitations="Numerischer s/ms-Anteil bis 3600000."},
	["animation-timing-function"]={Kind="motion-timing",Field="AnimationTiming",Inherited=false,Inline=true,Values="linear | linear(...) | ease | ease-in | ease-out | ease-in-out | step-start | step-end | cubic-bezier(...) | steps(...); Liste",Limitations="Die Funktion gilt je Keyframe-Intervall; ein Keyframe kann sie überschreiben. Dieselben Grenzen wie transition-timing-function."},
	["animation-delay"]={Kind="motion-delay",Field="AnimationDelay",Inherited=false,Inline=true,Values="s/ms einschließlich negativer Verzögerung; Liste",Limitations="Maximal 16 Einträge."},
	["animation-iteration-count"]={Kind="motion-iteration",Field="AnimationIteration",Inherited=false,Inline=true,Values="Nichtnegative Zahl | infinite; Liste",Limitations="Bruchteile sind unterstützt; maximal 100000 endliche Wiederholungen."},
	["animation-direction"]={Kind="motion-direction",Field="AnimationDirection",Inherited=false,Inline=true,Values="normal | reverse | alternate | alternate-reverse; Liste",Limitations="Entspricht der Zyklusrichtung im begrenzten Profil."},
	["animation-fill-mode"]={Kind="motion-fill",Field="AnimationFill",Inherited=false,Inline=true,Values="none | forwards | backwards | both; Liste",Limitations="Füllt die unterstützten Paint-/Layoutwerte. Pausierte oder abgeschlossene Füllung benötigt keine permanente Frameverbindung."},
	["animation-play-state"]={Kind="motion-play",Field="AnimationPlay",Inherited=false,Inline=true,Values="running | paused; Liste",Limitations="CSS-Zustandswechsel behalten Fortschritt und die vorhandenen nativen Oberflächen; Script-Animationsobjekte verwenden Web Animations."},
	["transform"]={Kind="transform",Field="Transform",Inherited=false,Replaced=true,Values="none | translate*/rotate*/scale*/perspective(); bis zu 16 Funktionen",Limitations="4x4-Matrizen für translate(X/Y/Z/3d), rotate(X/Y/Z/3d), scale(X/Y/Z/3d), matrix/matrix3d, skew(X/Y) und perspective. Nicht-native Flächen als begrenztes EditableImage; Text, solide Rahmen und Gradienten. Kein vollständiges Browser-Compositing für interaktive oder externe Medienflächen."},
	["transform-box"]={Kind="enum",Field="TransformBox",Inherited=false,Replaced=true,Allowed={["border-box"]=true,["content-box"]=true,["fill-box"]=true,["stroke-box"]=true,["view-box"]=true},Values="border-box | content-box | fill-box | stroke-box | view-box",Limitations="Bei CSS-Layoutboxen entspricht fill-box der content-box und stroke-box/view-box der border-box; computed Keywords bleiben unverändert. SVG-Formen besitzen ihre eigene Transformpipeline."},
	["transform-origin"]={Kind="transform-origin",Field="TransformOrigin",Inherited=false,Replaced=true,Values="Ein/zwei X-/Y-Werte: left | center | right | top | bottom | Länge/%; optional dritter Z-Längenwert",Limitations="Negative/äußere Ursprünge und Z-Längen im vorhandenen 2D-/Projektions-Paint-/Trefferpfad; Border-/Content-Transformbox. CSS-/WAAPI-Interpolation, Add/Accumulate, Live-Basis, Commit/Cancel boxgebunden geprüft; Ursprung allein erzeugt keinen Transform-Containing-Block. Prozentanteile in Z sind auch in calc/min/max ungültig. Reine Inline-/Pseudoziele und sämtliche 3D-/Schreibmodus-/Stackingkombinationen bleiben ungeprüft."},
	["translate"]={Kind="individual-transform",TransformKind="translate",Field="Translate",Inherited=false,Replaced=true,Values="none | signierte X-/Y-Längen/% und optionale Z-Länge",Limitations="Eigener computed-value-Kanal vor rotate, scale und transform; CSS-/WAAPI-Interpolation erhält Prozentanteile. 3D-Paint nutzt das dokumentierte CPU-Profil."},
	["rotate"]={Kind="individual-transform",TransformKind="rotate",Field="Rotate",Inherited=false,Replaced=true,Values="none | Winkel in deg/grad/rad/turn mit optionaler x/y/z- oder Vektorachse",Limitations="Eigener Kanal vor scale und transform; gleiche Achsen interpolieren Winkel, unterschiedliche Achsen per SLERP. 3D-Paint nutzt das dokumentierte CPU-Profil."},
	["scale"]={Kind="individual-transform",TransformKind="scale",Field="Scale",Inherited=false,Replaced=true,Values="none | eine bis drei signierte Zahlen oder Prozentwerte",Limitations="Getrennte X/Y/Z-Werte vor transform; individuelle Addition/Akkumulation multipliziert Skalierung. Ungleichmäßige, gespiegelte und 3D-Flächen nutzen das CPU-Profil."},
	["filter"]={Kind="filter",Field="Filter",Inherited=false,Replaced=true,Values="none | brightness()/contrast()/grayscale()/invert()/sepia()/saturate()/hue-rotate()/opacity()/blur(0–100px)/drop-shadow()",Limitations="img: nur Bildpixel, ohne Rahmen/Hintergrund/Alt-Text. Container: vollständiger nativer Unterbaum für brightness(0–100%) und opacity(); kein blur, contrast oder Farbmix. Bis 16 Funktionen in Reihenfolge, Zahlen/% bis 100000, Winkel deg/grad/rad/turn. EditableImage-Zugriff erforderlich; Cache max16 Ergebnisse/8388608 Pixel pro Seite, Original bei Fehler. Blur: Gauß-Näherung in Anzeigegröße mit transparentem Überstand, max512px Texturkante, separater Resize-Cache. Drop-shadow: signed px offsets bis 1000px, sigma 0–100px, Farbe/currentcolor; kein spread/inset. Kein url/backdrop-filter oder Animation."},
	["direction"] = {Kind="enum",Field="Direction",Inherited=true,Allowed={ltr=true,rtl=true},Values="ltr | rtl",Limitations="Logische Text-/Tabellen-/Flex-/Grid-Achsen; UAX9-Zeilenumordnung und HTML-dir-Auto werden getrennt nachgewiesen. Native Glyphcluster und vertikaler Satz bleiben Host-/Profilgrenzen."},
	["unicode-bidi"]={Kind="enum",Field="UnicodeBidi",Inline=true,Allowed={normal=true,embed=true,isolate=true,["bidi-override"]=true,["isolate-override"]=true,plaintext=true},Values="normal | embed | isolate | bidi-override | isolate-override | plaintext",Limitations="Nicht vererbt. Inline-Scope-Übersetzung gemäß CSS Writing Modes; Overrides auf dem Root-Inline des Blocks, plaintext mit UAX9-Absatzbasis. Shaping/Glyphcluster bleiben native Hostaufgabe."},
	["caption-side"] = {Kind="enum",Field="CaptionSide",Inherited=true,Allowed={top=true,bottom=true},Values="top | bottom",Limitations="Beschriftung außerhalb des Tabellenrahmens; horizontales Layout."},
	["empty-cells"] = {Kind="enum",Field="EmptyCells",Inherited=true,Allowed={show=true,hide=true},Values="show | hide",Limitations="Eigene Rahmen und Hintergründe leerer Zellen bei border-collapse:separate ausblenden; darunterliegende Zeilen-/Spaltenfarben bleiben sichtbar."},
	["cursor"] = {Kind="cursor",Field="Cursor",Inherited=true,Inline=true,Replaced=true,Values="auto | default | pointer | text | help | crosshair | move | grab | grabbing | copy | alias | cell | vertical-text | all-scroll | no-drop | not-allowed | zoom-in | zoom-out | none | Richtungs-/Spalten-/Zeilen-resize | url(...), Fallback",Limitations="Assetliste in CursorIcons. URL: rbxassetid:// oder Name aus CursorIcons; andere Quellen verwenden den Fallback. Keine Hotspot-Koordinaten, wait/progress. Native TextBoxen können den Roblox-Textcursor erzwingen."},
	["table-layout"] = {Kind="enum",Field="TableLayout",Inherited=false,Allowed={auto=true,fixed=true},Values="auto | fixed",Limitations="fixed benötigt eine Tabellenbreite; col/colgroup vor erster Zeile, übrige Spalten teilen Restplatz. Inhalt späterer Zeilen beeinflusst die Breiten nicht. Bei width:auto automatisches Layout."},
	["border-spacing"] = {Kind="border-spacing",Field="BorderSpacing",Inherited=true,Values="Eine oder zwei nichtnegative Längen: horizontal vertikal",Limitations="Separate Tabellenrahmen; px, em, rem und 0. Keine Prozentwerte."},
	["border-collapse"] = {Kind="enum",Field="BorderCollapse",Inherited=true,Allowed={separate=true,collapse=true},Values="separate | collapse",Limitations="collapse: gemeinsame Zell-/Zeilen-/Gruppen-/Tabellenkanten, einschließlich colspan/rowspan und hidden. Ohne border-spacing, Tabellen-padding und Rundungen. Spalten-/Gruppenkanten ebenfalls berücksichtigt; Muster-/Eckübergänge angenähert."},
	["resize"] = {Kind="enum",Field="Resize",Inherited=false,Allowed={none=true,both=true,horizontal=true,vertical=true},Values="none | both | horizontal | vertical",Limitations="Manueller Ziehgriff für textarea; andere Elemente unverändert."},
	["word-break"] = {Kind = "enum", Field = "WordBreak", Inherited = true, Allowed = {normal = true, ["break-all"] = true, ["break-word"] = true}, Values = "normal | break-all | break-word", Limitations = "Graphemgrenzen; break-word wirkt wie normal mit overflow-wrap:anywhere, auch bei min-content und unabhängig vom tatsächlichen overflow-wrap. Kein keep-all oder vollständiger sprachabhängiger Unicode-Umbruch."},
	["list-style-position"] = {Kind = "enum", Field = "ListStylePosition", Inherited = true, Allowed = {outside = true, inside = true}, Values = "outside | inside", Limitations = "LTR; innen als erster Zeilenbestandteil. ::marker unterstützt Text und gemeinsame Font-/Farbeigenschaften; vollständige RTL-Markeranordnung bleibt offen."},
	["list-style"] = {Kind = "composite", Field = "ListStyle", Inherited = true, CaseSensitive=true, Values = "Typ und/oder inside | outside", Limitations = "Setzt ausgelassene Komponenten auf disc/outside zurück; Markerbilder über die separate list-style-image-Eigenschaft."},
	["font"] = {Kind = "composite", Field = "FontShorthand", Inherited = true, Values = "[normal | italic] [normal | bold | 1–1000] Größe[/line-height] Familie", Limitations = "Unterstützte Longhand-Werte; keine Systemfonts, variant oder stretch."},
	["opacity"] = {Kind = "opacity", Field = "Opacity", Inherited = false, Inline = true, Replaced = true, Values = "Zahl oder Prozent; begrenzt auf 0–1", Limitations = "Gruppenkomposition via CanvasGroup; Roblox-Texturspeicher-/Auflösungsgrenzen, siehe docs/MEDIUM-ADDITIONS.md."},
	["row-gap"] = {Kind = "gap-side", Field = "Gap", Side = 1, Inherited = false, Values = "normal | nichtnegative Länge/Prozent/Math-Ausdruck", Limitations = "Flex/Grid-Zeilenabstand und Abstand zwischen Mehrspaltenreihen; Prozentbasis und zyklische Intrinsic-Größen getrennt aufgelöst. Vertikale Flex/Grid-Hauptachsen bleiben außerhalb des vollständigen Layoutprofils."},
	["column-gap"] = {Kind = "gap-side", Field = "Gap", Side = 2, Inherited = false, Values = "normal | nichtnegative Länge/Prozent/Math-Ausdruck", Limitations = "Spaltenabstand; normal bei Mehrspalten 1em, bei Flex/Grid 0. Prozent-/Math-Werte bleiben bis zur verwendeten Größenbasis erhalten; zyklische Intrinsic-Größen separat geprüft."},
	["inset"] = {Kind = "inset-shorthand", Field = "Inset", Inherited = false, Values = "1 bis 4 Werte: auto | 0 | signierte px/%", Limitations = "Setzt top/right/bottom/left; dieselben Positionierungsgrenzen wie die Einzelwerte."},
	["position"] = {Kind = "enum", Field = "Position", Inherited = false, Allowed = {static = true, relative = true, absolute = true, fixed = true, sticky = true}, ResetOnly = {"position-anchor"}, Values = "static | relative | absolute | fixed | sticky", Limitations = "fixed bezieht sich auf den Seiten-Viewport; sticky haftet vertikal im nächsten Scrollbereich. Setzt position-anchor als Reset-Unterproperty zurück; logische/fragmentierte Positionierung bleibt begrenzt."},
	["anchor-name"]={Kind="anchor-names",Field="AnchorNames",Inherited=false,CaseSensitive=true,Values="none | <dashed-ident>#",Limitations="Ankernamen als Kommaliste; Auswahl nach zulässiger Layoutreihenfolge, nächstem Vorfahren und sonst letzter Baumposition."},
	["anchor-scope"]={Kind="anchor-scope",Field="AnchorScope",Inherited=false,CaseSensitive=true,Values="none | all | <dashed-ident>#",Limitations="Begrenzt Namen und Referenzen auf den nächsten passenden Teilbaum; Shadow-Provenienz von ::part-Regeln bleibt offen."},
	["position-anchor"]={Kind="anchor-ref",Field="PositionAnchor",Inherited=false,CaseSensitive=true,Values="normal | none | auto | match-parent | ein --Ankername",Limitations="Normal deaktiviert den Default-Anker bei position-area:none; auto verwendet einen vorhandenen impliziten Ursprung. Match-parent behält den tatsächlichen zulässigen Elteranker. Physische/logische/self-Area-Geometrie läuft durch den gemeinsamen Solver; transformierte/fragmentierte Anker und vollständige Scrollkombinationen bleiben offen."},
	["position-try-order"]={Kind="position-try-order",Field="PositionTryOrder",Inherited=false,Values="normal | most-width | most-height | most-block-size | most-inline-size",Limitations="Stabile Auswahl nach inset-modifiziertem verfügbarem Bereich; behält passende Alternativen auch bei Bewegung und Resize. Physische/logische Area-Rezepte und Flip-Taktiken gemeinsam geprüft; vollständige Scroll-/Fragmentkombinationen bleiben offen."},
	["position-try"]={Kind="position-try",Field="PositionTryShorthand",Inherited=false,CaseSensitive=true,Values="[normal | most-width | most-height | most-block-size | most-inline-size]? <position-try-fallbacks>",Limitations="Gemeinsame Order-/Fallback-Komponenten mit CSS-weiten Resets, Variablen und CSSOM; dieselben Grenzen wie die Longhands."},
	["position-area"]={Kind="position-area",Field="PositionArea",Inherited=false,Values="none | physische, achsenbezogene, block/inline- oder self-Schlüsselwörter; center/span-all und zulässige span-*/Zweierkombinationen",Limitations="Gemeinsame Syntax und Bereichsgeometrie für alle fünf Schreibmodi, Prozentgrößen/Insets, bestehende Alignmentwerte, Overflow und Try-Fallbacks. Vollständige sichere/unsichere Alignmentgrammatik, transformierte/fragmentierte Anker und Scrollkombinationen bleiben offen."},
	["pointer-events"] = {Kind="enum",Field="PointerEvents",Inherited=true,Allowed={auto=true,none=true},Values="auto | none",Limitations="none entfernt die Box samt Nachfahren aus HTML-HitTests; SVG verwendet zusätzlich sein eigenes erweitertes pointer-events-Profil."},
	["user-select"] = {Kind="enum",Field="UserSelect",Inherited=true,Allowed={auto=true,none=true,text=true,all=true},Values="auto | none | text | all",Limitations="Steuert TextBox-Auswahl und Engine-Ziehgesten; TextLabel-Text besitzt in Roblox keine native Browserauswahl."},
	["touch-action"] = {Kind="enum",Field="TouchAction",Inherited=false,Allowed={auto=true,none=true,["pan-x"]=true,["pan-y"]=true,manipulation=true},Values="auto | none | pan-x | pan-y | manipulation",Limitations="Begrenzt Engine-Touchgesten und Scrollachsen; kein pinch-zoom oder kombinierte Schlüsselwortliste."},
	["content"] = {Kind="content",Field="GeneratedContent",Inherited=false,Inline=true,CaseSensitive=true,Values="normal | none | Zeichenketten | attr(name) | counter(name[, Stil]) | counters(name, Trennzeichen[, Stil]) | Quote-Werte",Limitations="Wirkt auf vorhandene erzeugte Inhalte einschließlich ::before, ::after, ::marker und die eigenen Rich-Select-Teile ::picker-icon/::checkmark. Zähler verwenden das vorhandene Counter-Style-Profil. Keine Bilder, CSS-Stringescapes oder alternativen Inhalte."},
	["counter-reset"] = {Kind="counter-reset",Field="CounterReset",Inherited=false,Inline=true,CaseSensitive=true,Values="none | Name [ganze Zahl] | reversed(Name) [ganze Zahl], wiederholbar",Limitations="Element- und Geschwisterbereiche mit maximal 16 Einträgen; ganzzahlige Werte werden begrenzt."},
	["counter-increment"] = {Kind="counter-increment",Field="CounterIncrement",Inherited=false,Inline=true,CaseSensitive=true,Values="none | Name [ganze Zahl], wiederholbar",Limitations="Ändert den innersten aktiven Zähler; implizite Zähler ohne reset gelten nur im erzeugenden Elementbereich."},
	["counter-set"] = {Kind="counter-set",Field="CounterSet",Inherited=false,Inline=true,CaseSensitive=true,Values="none | Name [ganze Zahl], wiederholbar",Limitations="Setzt den innersten aktiven Zähler; implizite Zähler ohne reset gelten nur im erzeugenden Elementbereich."},
	["z-index"] = {Kind = "z-index", Field = "ZIndex", Inherited = false, Values = "auto | ganze Zahl von -100000 bis 100000", Limitations = "Positionierte Boxen und Flexitems; Stapelung von Geschwister-Teilbäumen. Keine vollständige CSS-Stacking-Context-Auflösung über statische Vorfahren."},
	["flex-flow"] = {Kind = "flex-flow", Field = "FlexFlow", Inherited = false, Values = "Richtung und/oder Wrap-Modus, etwa row wrap", Limitations = "Setzt ausgelassene Richtung auf row und Wrap-Modus auf nowrap zurück."},
	["order"] = {Kind = "order", Field = "Order", Inherited = false, Values = "Ganze Zahl von -100000 bis 100000 (Standard 0)", Limitations = "Nur direkte Flexitems; gleiche Werte behalten die DOM-Reihenfolge. Keine DOM-/Fokus-Umsortierung."},
	["align-self"] = {Kind = "enum", Field = "AlignSelf", Inherited = false,
		Allowed = {auto = true, stretch = true, ["self-start"] = true, ["self-end"] = true, ["flex-start"] = true, ["flex-end"] = true, center = true, baseline = true},
		Values = "auto | normal | stretch | start | end | self-start | self-end | flex-start | flex-end | center | baseline", Limitations = "Horizontale Flex-/Gridcontainer: physische Selfkanten fester Items einschließlich orthogonaler Schreibmodi; auto folgt align-items. Flex-/Grid-Automargins haben getrennte Overflowregeln. Vollständige vertikale Containerachsen, Baselinekombinationen und safe/unsafe fehlen."},
	["flex-wrap"] = {Kind = "flex-wrap", Field = "FlexWrap", Inherited = false,
		Values = "nowrap | [wrap | wrap-reverse] || balance",
		Limitations = "Zeilen bei row, Spalten bei column; balance verteilt Items auf die Mindestzahl von Zeilen."},
	["flex-line-count"]={Kind="positive-integer",Field="FlexLineCount",Inherited=false,Values="Ganzzahl 1–1000",Limitations="Mindestzahl bei flex-wrap:balance; begrenzt durch die Itemzahl. Ohne balance bleibt die normale Umbruchwahl erhalten."},
	["align-content"] = {Kind = "enum", Field = "AlignContent", Inherited = false,
		Allowed = {stretch = true, ["flex-start"] = true, ["flex-end"] = true, center = true, ["space-between"] = true, ["space-around"] = true, ["space-evenly"] = true},
		Values = "stretch | flex-start | flex-end | center | space-between | space-around | space-evenly",
		Limitations = "Verteilt Flexzeilen auf der Querachse bei wrap/wrap-reverse, auch bei nur einer Zeile. Keine Wirkung bei nowrap; kein baseline/safe/unsafe."},
	["flex-grow"] = {Kind = "flex-factor", Field = "FlexGrow", Inherited = false, Values = "Nichtnegative Zahl bis 100000 (Standard 0)", Limitations = "Nur direkte Flexitems."},
	["flex-shrink"] = {Kind = "flex-factor", Field = "FlexShrink", Inherited = false, Values = "Nichtnegative Zahl bis 100000 (Standard 1)", Limitations = "Mit der Inhalts-Ausgangsgröße gewichtetes Schrumpfen; nur direkte Flexitems."},
	["flex-basis"] = {Kind = "flex-basis", Field = "FlexBasis", Inherited = false, Values = "auto | content | unterstützte Längen, Prozente und Berechnungen", Limitations = "Prozente brauchen eine bestimmte Hauptachsengröße; sonst Inhalt. Intrinsische Größenkeywords außer content fehlen."},
	["flex"] = {Kind = "flex", Field = "Flex", Inherited = false, Values = "none | auto | initial | grow [shrink] [basis]", Limitations = "Setzt alle drei Komponenten zurück; ausgelassene Basis 0% wie im Browser. Direkte img sind eigenständige Flexitems."},
	["flex-direction"] = {Kind = "enum", Field = "FlexDirection", Inherited = false, Allowed = {row = true, column = true, ["row-reverse"] = true, ["column-reverse"] = true}, Values = "row | column | row-reverse | column-reverse", Limitations = "Horizontale Schreibrichtung LTR; kein writing-mode oder RTL."},
	["justify-content"] = {Kind = "enum", Field = "JustifyContent", Inherited = false,
		Allowed = {["flex-start"] = true, ["flex-end"] = true, left = true, right = true, center = true, ["space-between"] = true, ["space-around"] = true, ["space-evenly"] = true},
		Values = "normal | stretch | start | end | flex-start | flex-end | left | right | center | space-between | space-around | space-evenly", Limitations = "Horizontale Flex-/Gridcontainer: left/right sind physisch, auf der Column-Flex-Hauptachse wie start. Hauptachsen-/Trackpositionen einschließlich RTL und negativem Restplatz; automatische Flex-Hauptachsen-Margins nehmen positiven Restplatz vorher auf. Vollständige vertikale Containerachsen, Baseline- und safe/unsafe-Grammatik fehlen."},
	["align-items"] = {Kind = "enum", Field = "AlignItems", Inherited = false,
		Allowed = {stretch = true, ["self-start"] = true, ["self-end"] = true, ["flex-start"] = true, ["flex-end"] = true, center = true, baseline = true},
		Values = "normal | stretch | start | end | self-start | self-end | flex-start | flex-end | center | baseline", Limitations = "Horizontale Flex-/Gridcontainer: physische Selfkanten fester Items einschließlich orthogonaler Schreibmodi. align-self überschreibt einzelne Items; Automargins haben Vorrang. baseline bleibt das vorhandene erste-Grundlinien-Profil; vollständige vertikale Containerachsen, Baselinekombinationen und safe/unsafe fehlen."},
	["gap"] = {Kind = "gap", Field = "Gap", Inherited = false, Values = "1 oder 2 Werte: normal | 0 | nichtnegative feste Längen/Berechnungen", Limitations = "Flex- und Gridcontainer; normal wie 0. row-gap/column-gap überschreiben einzelne Achsen; Prozentwerte fehlen."},
	["text-overflow"] = {Kind = "enum", Field = "TextOverflow", Inherited = false, Allowed = {clip = true, ellipsis = true}, Values = "clip | ellipsis", Limitations = "LTR-Zeilen in Blockcontainern mit overflow-x:hidden/auto/scroll; typischerweise white-space:nowrap. Reine Zeichenprojektion ohne Layoutänderung. Scrollposition aktualisiert die sichtbaren Zeichen; kein RTL, zwei Werte, eigene Zeichenfolge oder line-clamp."},
	["overflow-wrap"] = {
		Kind = "overflow-wrap", Field = "OverflowWrap", Inherited = true,
		Values = "normal | break-word | anywhere",
		Limitations = "Notumbruch langer Wörter an Graphemgrenzen. nowrap/pre bleiben ungebrochen; keine automatische Silbentrennung oder vollständiger Unicode-Zeilenumbruchalgorithmus.",
	},
	["visibility"] = {
		Kind = "visibility", Field = "Visibility", Inherited = true,
		Values = "visible | hidden | collapse",
		Limitations = "collapse entfernt Tabellenzeilen/-spalten und deren Gruppen aus der sichtbaren Geometrie, erhält ihre Größenmessung und schneidet verbundene Zellen zu. Außerhalb von Tracks wie hidden. Keine dynamische CSS-Neuberechnung.",
	},
	["aspect-ratio"] = {
		Kind = "aspect-ratio", Field = "AspectRatio", Inherited = false, Replaced = true,
		Values = "auto | Zahl | Breite / Höhe; optional auto mit Verhältnis",
		Limitations = "Blockcontainer und img; nur automatische Achsen. Autorenverhältnis gemäß box-sizing, natürliche Bildratio immer content-box. Dezimalzahlen bis 100000, Quotient 0.00001–100000; Nullratio wie auto. Kein calc, Flex/Grid oder intrinsische Min-Content-Breitenberechnung.",
	},
	["text-shadow"] = {
		Kind = "text-shadow", Field = "TextShadows", Inherited = true,
		Values = "none | x y [0px] [Farbe], bis zu 16 Schatten",
		Limitations = "Scharfe Text-/Emphasiskopien mit physischem px-Offset, currentcolor und Alpha; erster Schatten vorn. Vertikale und sideways Glyphen behalten physisches rechts/unten. Dynamische Listen/Quellscopes und Labels werden erhalten; keine Zusatztextmessung. CSS-/WAAPI-Listeninterpolation, Add/Accumulate, statisches symbolisches vs. animiertes aufgelöstes currentColor, Autorbasiswechsel und Commit/Cancel sind im C08-Profil geprüft; uniformes Paint bleibt ohne Layout, neue Quellaufteilung braucht erstes Layout. Kein Blur, Spread oder inset. Schatten von Textlinien, Listenmarkern und Bild-alt sowie zeilenweite gemeinsame Schattenstapelung fehlen. Keine Layout-/Scrollgrößenänderung.",
	},
	["object-fit"] = {
		Kind = "object-fit", Field = "ObjectFit", Inherited = false, Inline = true,
		Values = "fill | contain | cover | none | scale-down",
		Limitations = "img: Inhaltsanpassung ohne Änderung der Elementgröße. none/scale-down benötigen Assetmaße; bei fehlendem Zugriff Attributmaße oder 300x150. Abgerundeter eigener Zuschnitt über CanvasGroup (ZIndexBehavior.Sibling).",
	},
	["object-position"] = {
		Kind = "object-position", Field = "ObjectPosition", Inherited = false, Inline = true,
		Values = "left | center | right | top | bottom | px | %; 1, 2 oder 4 Komponenten",
		Limitations = "img: Standard 50% 50%, negative Werte, Berechnungen und Kantenabstände erlaubt. Logische Schlüsselwörter fehlen. Außerhalb der Inhaltsfläche wird abgeschnitten.",
	},
	["vertical-align"] = {
		Kind = "vertical-align", Field = "VerticalAlign", Inherited = false, Inline = true,
		Values = "baseline | super | sub; img auch middle | text-top | text-bottom | top | bottom | signierte px/%",
		Limitations = "img: Marginbox an Elternschrift bzw. gesamter Zeile ausgerichtet; % relativ zur eigenen line-height. Fontmetriken angenähert. Inline-Text weiterhin baseline/super/sub, keine Tabellen oder vollständigen ausgerichteten Inline-Teilbäume.",
	},
	["text-align-last"] = {
		Kind = "text-align-last", Field = "TextAlignLast", Inherited = true,
		Values = "auto | left | center | right | justify | start | end", Limitations = "Letzte Zeile und Zeilen vor festen Umbrüchen; start/end folgen direction. Kein match-parent oder vollständiger Bidi-Textsatz.",
	},
	["list-style-type"] = {
		Kind = "list-style-type", Field = "ListStyleType", Inherited = true,CaseSensitive=true,
		Values = "Vordefinierter oder eigener Counterstil | symbols(...) | Zeichenfolge | none",
		Limitations = "Textmarker auf list-item-Elementen. Eigene @counter-style-Namen bleiben case-sensitive. Keine Bildsymbole in symbols()/@counter-style oder vollständige RTL-Markeranordnung.",
	},
	["white-space"] = {
		Kind = "white-space", Field = "WhiteSpace", Inherited = true,
		Values = "normal | pre | pre-wrap | pre-line | [collapse | discard | preserve | preserve-breaks | preserve-spaces | break-spaces] || [wrap | nowrap]",
		Limitations = "HTML-Leerzeichen, Tabs und Zeilenumbrüche mit getrennten Kollaps-/Wrap-Achsen; Legacy-Werte und achsenweise Kurzformen. white-space-trim und vollständige Unicode-/Bidi-Regeln sind getrennte Restanforderungen.",
	},
	["tab-size"] = {
		Kind = "tab-size", Field = "TabSize", Inherited = true,
		Values = "nichtnegative Zahl | nichtnegative px; Standard 8",
		Limitations = "Erhaltene Tabs; Zahlen beziehen sich auf die Leerzeichenbreite des Blockcontainers inklusive word-spacing/letter-spacing. Keine weiteren Längeneinheiten oder Prozentwerte; Blocksatz bleibt angenähert.",
	},
	["min-height"] = {
		Kind = "min-size", Field = "MinHeight", Inherited = false, AllowPercent=true,
		Values = "auto | min-content | max-content | fit-content | nichtnegative Länge/% oder unterstützte CSS-Mathematik",
		Limitations = "Intrinsische Limits im horizontalen Blockfluss, vertikalen direkten Text und geladenen ersetzten Bildern; Aspect-Ratio-Übertrag und logische Achsen verwenden dieselben Messpfade. Minimum gewinnt gegen kleineres Maximum. Längenhöhen und ihre Längenlimits bestimmen weiterhin die Prozentkindbasis. auto entspricht hier 0; Prozentwerte und Quirks verwenden den dokumentierten Höhenpfad. Vollständige orthogonale/Flex-/Grid-/Prozent-/Fragmentkombinationen bleiben offen.",
	},
	["max-height"] = {
		Kind = "max-size", Field = "MaxHeight", Inherited = false, AllowPercent=true,
		Values = "none | min-content | max-content | fit-content | nichtnegative Länge/% oder unterstützte CSS-Mathematik",
		Limitations = "Intrinsische Limits im horizontalen Blockfluss, vertikalen direkten Text und geladenen ersetzten Bildern; eine vorhandene bestimmte Prozentkindbasis wird durch den intrinsischen Grenzwert nicht erneut aufgelöst. none hebt die Grenze auf; Minimum gewinnt bei Konflikten. Native Widgetmaße und behaltene Editorpfade sind geprüft, Fontmetriken bleiben angenähert. Vollständige orthogonale/Flex-/Grid-/Prozent-/Fragmentkombinationen bleiben offen.",
	},
	["overflow-clip-margin"]={Kind="clip-margin-shorthand",Field="OverflowClipMarginShorthand",Inherited=false,Values="<visual-box> || <length>",Limitations="Verschiebt die Kante von overflow:clip; wirkt nicht auf hidden oder auto."},
	["overflow-clip-margin-top"]={Kind="clip-margin",Field="OverflowClipMargins",Side=1,Inherited=false,Values="<visual-box> || <length>",Limitations="Top-Kante bei overflow:clip."},
	["overflow-clip-margin-right"]={Kind="clip-margin",Field="OverflowClipMargins",Side=2,Inherited=false,Values="<visual-box> || <length>",Limitations="Right-Kante bei overflow:clip."},
	["overflow-clip-margin-bottom"]={Kind="clip-margin",Field="OverflowClipMargins",Side=3,Inherited=false,Values="<visual-box> || <length>",Limitations="Bottom-Kante bei overflow:clip."},
	["overflow-clip-margin-left"]={Kind="clip-margin",Field="OverflowClipMargins",Side=4,Inherited=false,Values="<visual-box> || <length>",Limitations="Left-Kante bei overflow:clip."},
	["overflow-clip-margin-block"]={Kind="clip-margin-shorthand",Field="OverflowClipMarginBlock",Inherited=false,Values="<visual-box> || <length>",Limitations="Logische Kanten bei overflow:clip."},
	["overflow-clip-margin-inline"]={Kind="clip-margin-shorthand",Field="OverflowClipMarginInline",Inherited=false,Values="<visual-box> || <length>",Limitations="Logische Kanten bei overflow:clip."},
	["overflow-clip-margin-block-start"]={Kind="clip-margin",Field="OverflowClipMargins",LogicalSides={"block-start"},Inherited=false,Values="<visual-box> || <length>",Limitations="Logische block-start-Kante bei overflow:clip."},
	["overflow-clip-margin-inline-start"]={Kind="clip-margin",Field="OverflowClipMargins",LogicalSides={"inline-start"},Inherited=false,Values="<visual-box> || <length>",Limitations="Logische inline-start-Kante bei overflow:clip."},
	["overflow-clip-margin-block-end"]={Kind="clip-margin",Field="OverflowClipMargins",LogicalSides={"block-end"},Inherited=false,Values="<visual-box> || <length>",Limitations="Logische block-end-Kante bei overflow:clip."},
	["overflow-clip-margin-inline-end"]={Kind="clip-margin",Field="OverflowClipMargins",LogicalSides={"inline-end"},Inherited=false,Values="<visual-box> || <length>",Limitations="Logische inline-end-Kante bei overflow:clip."},
	["overflow"] = {
		Kind = "overflow", Field = "Overflow", Inherited = false,
		Values = "visible | hidden | clip | auto | scroll; ein oder zwei Werte (x, y)",
		Limitations = "Blockcontainer; auto/scroll über native ScrollingFrames mit 10px Leisten. Sichtbare Gegenachse wird zu auto. Rechteckiges Clipping; keine CSS-Viewport-Übertragung von html/body, clip ohne programmatisches Scrollen; kein öffentliches programmatisches Scrollen. Details: docs/SCROLLING.md.",
	},
	["overflow-x"] = {Kind = "overflow", Field = "OverflowX", Inherited = false, Values = "visible | hidden | clip | auto | scroll", Limitations = "Horizontale Achse; gleiche Grenzen wie overflow."},
	["overflow-y"] = {Kind = "overflow", Field = "OverflowY", Inherited = false, Values = "visible | hidden | clip | auto | scroll", Limitations = "Vertikale Achse; gleiche Grenzen wie overflow."},
	["box-sizing"] = {
		Kind = "box-sizing", Field = "BoxSizing", Inherited = false, Inline = true,
		Values = "content-box | border-box",
		Limitations = "Steuert width/height und ihre min/max-Grenzen auf Blockcontainern. Margin bleibt außerhalb; Padding und Rahmen können nicht unterschritten werden. Auf Inline-Text ohne eigene Box keine Layoutwirkung.",
	},
	["min-width"] = {
		Kind = "min-size", Field = "MinWidth", Inherited = false, AllowPercent = true,
		Values = "auto | min-content | max-content | fit-content | nichtnegative Länge/% oder unterstützte CSS-Mathematik",
		Limitations = "Intrinsische Limits teilen die vorhandene Text-/Bildmessung; Eigenlimits werden nicht rekursiv in ihre eigene Probe einbezogen. Horizontale Flex-/Grid-Items und fünf Schreibmodi für direkten Text/Bilder sind geprüft. Prozent relativ zur Eltern-Inhaltsbreite; Minimum gewinnt bei Konflikten. auto entspricht hier 0 außerhalb der vorhandenen automatischen Itemminimum-Pfade. Vollständige orthogonale/atomare/Flex-/Grid-Intrinsic-Kombinationen bleiben offen.",
	},
	["max-width"] = {
		Kind = "max-size", Field = "MaxWidth", Inherited = false, AllowPercent = true, Replaced = true,
		Values = "none | min-content | max-content | fit-content | nichtnegative Länge/% oder unterstützte CSS-Mathematik",
		Limitations = "Intrinsische Limits teilen die vorhandene Text-/Bildmessung und Ratioübertragung. Horizontale Flex-/Grid-Items und fünf Schreibmodi für direkten Text/Bilder sind geprüft; unveränderte Mess-/Paintobjekte bleiben erhalten. none hebt die Grenze auf; Prozent relativ zur Eltern-Inhaltsbreite. Inhalt kann überlaufen. Vollständige orthogonale/atomare/Flex-/Grid-Intrinsic-Kombinationen bleiben offen.",
	},
	["outline"] = {Kind = "outline", Field = "Outline", Inherited = false, Values = "[px | thin | medium | thick] [auto | solid | dashed | dotted | double | none] [Farbe]", Limitations = "Blöcke/Bilder/Controls; setzt Breite/Stil/Farbe auf 3px/none/currentcolor zurück, nicht offset. Kein Layout-/Scrollplatz. auto verwendet einen gerundeten 2px-Fokusring wie Chromium/Windows. Keine Inline-Text-Konturen, invert oder 3D-Stile; Mustergrenzen wie border-style."},
	["outline-width"] = {Kind = "border-width", Field = "OutlineWidth", Inherited = false, Values = "0 | nichtnegative px | thin | medium | thick", Limitations = "Ein Wert für alle Kanten; kein Einfluss auf Boxgrößen."},
	["outline-style"] = {Kind = "outline-style", Field = "OutlineStyle", Inherited = false, Values = "auto | solid | dashed | dotted | double | none", Limitations = "Muster rechteckig; solide Kontur folgt border-radius. auto nutzt den Chromium/Windows-Fokusring und ignoriert outline-width. Kein 3D-Stil."},
	["outline-color"] = {Kind = "border-color", Field = "OutlineColor", Inherited = false, Values = "Farbe | currentcolor", Limitations = "Farbformate und Alpha wie color; kein invert. CSS/WAAPI Replace/Add/Accumulate und currentColor an gerenderten Boxen; behaltene Outline-Fläche. Vollständige Farbräume, logische Aliase und Timingkombinationen bleiben offen."},
	["outline-offset"] = {Kind = "outline-offset", Field = "OutlineOffset", Inherited = false, Values = "0 | px (auch negativ)", Limitations = "Abstand von der Borderbox; negative Werte nach innen. Keine Prozentwerte oder calc."},
	["border"] = {
		Kind = "border", Field = "Border", Inherited = false, Replaced = true,
		Values = "[px | thin | medium | thick] [solid | inset | outset | groove | ridge | none | hidden | dashed | dotted | double] [Farbe]; z.B. 2px solid #245bb3",
		Limitations = "Setzt alle Rahmenkanten auf Blöcken/Bildern; fehlende Werte: 3px, none, currentcolor. Einzelkanten über border-top/right/bottom/left. border-image besitzt ein getrenntes begrenztes Profil. Muster rechteckig, keine durchgehenden Eckmuster.",
	},
	["border-width"] = {Kind = "border-width", Field = "BorderWidth", BorderComponents = true, Inherited = false, Values = "1–4 Werte: 0 | nichtnegative px | thin | medium | thick", Limitations = "Oben/rechts/unten/links nach CSS-Kurzformregeln; thin/medium/thick = 1/3/5px. Keine Prozentwerte oder calc."},
	["border-style"] = {Kind = "border-style", Field = "BorderStyle", BorderComponents = true, Inherited = false, Values = "1–4 Werte: solid | inset | outset | groove | ridge | none | hidden | dashed | dotted | double", Limitations = "Oben/rechts/unten/links; inset/outset/groove/ridge zweifarbig angenähert. Muster mit wiederverwendeten Frames, höchstens 128 Segmente je Kante; dann größere Lücken. Double unter 3px wie solid. Diagonale Eckbilder: max64 Boxen/262144 Pixel je Seite; API-/Budgetfallback auf rechteckige Übergänge. Musterrundung fehlt."},
	["border-color"] = {Kind = "border-color", Field = "BorderColor", BorderComponents = true, Inherited = false, Values = "1–4 Werte: Farbe | currentcolor", Limitations = "Oben/rechts/unten/links nach CSS-Kurzformregeln; gleiche Farbformate und Alpha wie color. CSS/WAAPI expandiert zu vier physischen Farbkanälen mit unabhängiger Importance, currentColor und behaltenen Kanten. Vollständige logische Aliase/Farbräume bleiben offen."},
	["border-radius"] = {Kind = "border-radius", Field = "BorderRadius", Inherited = false, Values = "1–4 nichtnegative Längen/%; optional / für vertikale Radien", Limitations = "Prozentwerte beziehen sich auf die Borderbox. Einfarbige Boxen verwenden eine vollständige elliptisch gerundete EditableImage-Oberfläche. overflow:hidden maskiert Kinder gegen den nächsten deckenden Hintergrund; transparente Umgebungen und Bildhintergründe verwenden die größte gemeinsame sichere UICorner-Rundung."},
	["letter-spacing"] = {
		Kind = "letter-spacing", Field = "LetterSpacing", Inherited = true,
		Values = "normal | 0 | px (auch negativ)",
		Limitations = "Bei nichtnull Abstand: Zeichen-Labels je Graphem in einem Wort-Frame. Wörter bleiben beim Umbruch zusammen. Unabhängige Zeichenmessungen; Kerning, Ligaturen und verbundene Schriften können vom Browser abweichen. Keine % oder RTL.",
	},
	["word-spacing"] = {
		Kind = "word-spacing", Field = "WordSpacing", Inherited = true,
		Values = "normal | 0 | px (auch negativ)",
		Limitations = "Zusatz zum gemessenen normalen Leerzeichen, nach Whitespace-Kollaps; Stil des Leerzeichens zählt. Keine % oder weiteren Unicode-Worttrenner. NBSP im nativen Wort-Label bleibt unverändert (Diagnose bei nichtnull Abstand); im Zeichenmodus mit letter-spacing wird es berücksichtigt. Negative Werte können Wörter überlappen lassen.",
	},
	["text-transform"] = {
		Kind = "text-transform", Field = "TextTransform", Inherited = true,
		Values = "none | [uppercase | lowercase | capitalize] || full-width || full-size-kana | math-auto",
		Limitations = "Unicode-17-Vollabbildungen und bedingte Sprach-/Kontextregeln. Transformation vor individueller Wortmessung; DOM/Quellpositionen bleiben erhalten. capitalize nutzt ein festgelegtes UA-Wortgrenzenprofil. Native Glyphenverfügbarkeit, Formung und Kerning über Stilgrenzen bleiben hostabhängig; Nachweis und verbleibende Grenzen im Textprofil HTML-SUPPORT.md.",
	},
	["text-indent"] = {
		Kind = "text-indent", Field = "TextIndent", Inherited = true,
		Values = "<length-percentage> && hanging? && each-line? (auch negativ)",
		Limitations = "Erste formatierte Zeile, each-line zusätzlich nach festen Umbrüchen, hanging kehrt die betroffenen Zeilen um. Logischer Einzug für LTR/RTL; Prozent relativ zur Inhaltsbreite und null in intrinsischen Größen. Vollständige Bidi-/Fragmentierungskombinationen erfordern weitere Nachweise.",
	},
	["text-decoration-skip-ink"] = {
		Kind = "skip-ink", Field = "SkipInk", Inherited = true,
		Values = "auto | none",
		Limitations = "Experimentelle Unterlinien-Lücken bei p/g/j/q/y, proportional zur Schriftgröße. Zusätzliche Präfixmessungen pro betroffenem Wort; keine echten Glyphenkonturen. Durchstriche bleiben durchgehend. all fehlt.",
	},
	["text-decoration-color"] = {
		Kind = "decoration-color", Field = "DecorationColor", Inherited = false, Inline = true,
		Values = "currentcolor | unterstützte Farbe wie color",
		Limitations = "Farbe der vom Element erzeugten Linien; färbt keine Vorfahrenlinie um. Gleiche Farben und Alpha wie color. CSS/WAAPI Replace/Add/Accumulate und currentColor an gerenderten Boxen; vorhandene Linienflächen bleiben erhalten. Direkte reine Inline-/Pseudoziele und weitere Farb-/Timingkombinationen bleiben offen.",
	},
	["text-decoration-style"] = {
		Kind = "decoration-style", Field = "DecorationStyle", Inherited = false, Inline = true,
		Values = "solid | double | dotted | dashed | wavy",
		Limitations = "Prototyp: solid/double als Frames, Muster als geteilte EditableImages. Mustergeometrie angenähert; 1–32 px Dicke, maximal 16 Muster/65536 Pixel pro Seite. Bei fehlender API oder Budget: solid mit Diagnose. Auch in text-decoration kombinierbar.",
	},
	["text-underline-offset"] = {
		Kind = "underline-offset", Field = "UnderlineOffset", Inherited = true,
		Values = "auto | 0 | signierte px oder %",
		Limitations = "Auf ganze Pixel gerundet; positive Offsets nach außen, negative nach innen. Prozent relativ zur Schriftgröße am Linienursprung, vererbt relativ. auto behält die Fontnäherung. under beginnt an der geschätzten Fontboxkante, auch bei explizitem Null-/Negativoffset; vertikale left/right-Seiten behalten denselben Ursprung. Genaues Font-Skip-ink bleibt offen.",
	},
	["text-decoration-thickness"] = {
		Kind = "length", Field = "DecorationThickness", Inherited = false, Inline = true, AllowPercent = true,
		Values = "auto | px | %",
		Limitations = "Ganze Pixel, mindestens 1 px. auto als gemeinsame Näherung: floor(CSS-font-size * 0.049), unabhängig von Schrift und Gewicht. Explizite px/% werden gerundet. Browser-auto kann abweichen; from-font fehlt.",
	},
	["text-decoration"] = {
		Kind = "text-decoration", Field = "TextDecoration", Inherited = false, Inline = true, ResetDecoration = true,
		Values = "Linien (none oder underline/overline/line-through kombiniert), optional solid/double/dotted/dashed/wavy, Farbe und auto/px/%-Dicke; beliebige Reihenfolge",
		Limitations = "Ausgelassene Komponenten: none/currentcolor/auto/solid. Offset bleibt erhalten. Ungültige oder doppelte Komponenten verwerfen die ganze Deklaration. Keine from-font oder Font-Einzelkalibrierung. none entfernt keine Vorfahrenlinie.",
	},
	["text-decoration-line"] = {
		Kind = "text-decoration", Field = "TextDecoration", Inherited = false, Inline = true,
		Values = "none | underline, overline, line-through (auch kombiniert)",
		Limitations = "Ändert nur die Linienauswahl; Farbe, Dicke, Style und Offset bleiben erhalten. overline liegt an der geschätzten oberen Fontboxkante des Linienursprungs; double/wavy wachsen nach oben. Kein blink, spelling-error oder grammar-error. none entfernt keine Vorfahrenlinie. Overline ohne Glyphen-Skip-ink; native Höhenposition noch visuell abzugleichen.",
	},
	["color"] = {
		Kind = "color", Field = "Color", Inherited = true,
		Values = "#RGB/#RGBA/#RRGGBB/#RRGGBBAA, rgb()/rgba(), hsl()/hsla(), oklab(), oklch(), color-mix(), transparent, currentcolor; 148 CSS-Farbnamen",
		Limitations = "RGB und HSL mit Kommas oder Leerzeichen/Slash; modernes RGB erlaubt gemischte Zahlen/Prozente und none. OKLab/OKLCH und color-mix() besitzen das begrenzte sRGB/linear-sRGB/OKLab/OKLCH-Profil; Ausgabe als sRGB/Color3 mit Gamut-Clipping. Hue als Zahl/deg/grad/rad/turn. Alpha als Zahl/Prozent; Komponenten bis 100000. HSL-none, calc, relative Farben und vollständige Farbraumgrammatik bleiben offen. Alpha wirkt auf die Farbe, nicht als Gruppen-opacity. CSS/WAAPI Replace/Add/Accumulate mit vererbten currentColor-Verbrauchern an gerenderten Boxen; direkte reine Inline-/Pseudoziele, vollständige Alpha-Clamps und weitere Timingkombinationen bleiben offen.",
	},
	["background-color"] = {
		Kind = "color", Field = "Background", Inherited = false, Inline = true,
		Values = "#RGB/#RGBA/#RRGGBB/#RRGGBBAA, rgb()/rgba(), hsl()/hsla(), oklab(), oklch(), color-mix(), transparent, currentcolor; 148 CSS-Farbnamen",
		Limitations = "RGB und HSL mit Kommas oder Leerzeichen/Slash; modernes RGB erlaubt gemischte Zahlen/Prozente und none. OKLab/OKLCH und color-mix() besitzen das begrenzte sRGB/linear-sRGB/OKLab/OKLCH-Profil; Ausgabe als sRGB/Color3 mit Gamut-Clipping. Hue als Zahl/deg/grad/rad/turn. Alpha als Zahl/Prozent; Komponenten bis 100000. HSL-none, calc, relative Farben und vollständige Farbraumgrammatik bleiben offen. Alpha wirkt auf die Farbe, nicht als Gruppen-opacity. CSS/WAAPI Replace/Add/Accumulate und live currentColor an gerenderten Boxen; vorhandene Inline-Verbraucher bleiben erhalten. Direkte reine Inline-/Pseudoziele und vollständige Farb-/Timingkombinationen bleiben offen.",
	},
	["line-break"]={Kind="enum",Field="LineBreak",Inherited=true,Allowed={auto=true,loose=true,normal=true,strict=true,anywhere=true},Values="auto | loose | normal | strict | anywhere",Limitations="anywhere erlaubt Graphemumbrüche wie overflow-wrap:anywhere; die übrigen Werte behalten Robloxs normale Wortgrenzen."},
	["hanging-punctuation"]={Kind="enum",Field="HangingPunctuation",Inherited=true,Allowed={none=true,first=true,last=true,["allow-end"]=true,["force-end"]=true},Values="none | first | last | allow-end | force-end",Limitations="Hängt passende einzelne Satzzeichen am Anfang oder Ende einer Textzeile um eine halbe Glyphenbreite aus."},
	["text-autospace"]={Kind="enum",Field="TextAutospace",Inherited=true,Allowed={normal=true,["no-autospace"]=true},Values="normal | no-autospace",Limitations="normal fügt zwischen CJK-Ideogrammen und lateinischen Buchstaben/Ziffern einen schmalen Roblox-Zwischenraum ein."},
	["background-image"] = {
		Kind = "background-image", Field = "BackgroundImages", Inherited = false, CaseSensitive = true,
		Values = "none | url(...) | linear-gradient(...) | repeating-linear-gradient(...) | radial-gradient(...) | repeating-radial-gradient(...) | conic-gradient(...) | repeating-conic-gradient(...) | image-set(...); mehrere Ebenen mit Komma",
		Limitations = "Blockboxen und eigener Canvashintergrund mit Root-/Body-Quellwahl. url() verwendet zugeordnete Roblox-Assets oder lokale SVG-Quellen, keinen allgemeinen Webdownload. Verläufe werden als gecachte EditableImages bis 256px pro Kante gerastert; maximal 8 Ebenen/64 Bilder/4194304 Pixel pro Seite. image-set() besitzt ein begrenztes Dichte-/MIME-Auswahlprofil. cross-fade(), vollständige Bildgrammatik, Inline-Fragmentbilder, computed background-image und weitere Transform-/Attachmentkombinationen bleiben offen; genaue Nachweise in CSS-BACKGROUNDS.",
	},
	["background-size"] = {
		Kind = "background-size", Field = "BackgroundSizes", Inherited = false,
		Values = "auto | cover | contain | eine oder zwei nichtnegative Längen/Prozente; mehrere Ebenen mit Komma",
		Limitations = "Gradient-auto füllt die Positionierungsfläche. URL-auto ohne verfügbare intrinsische Metadaten füllt ebenfalls; cover/contain verwenden native Roblox-Bildanpassung. space/round-Wiederholung bleibt angenähert.",
	},
	["background-position"] = {
		Kind = "background-position", Field = "BackgroundPositions", Inherited = false,
		Values = "left/center/right, top/center/bottom und Längen/Prozente einschließlich Kantenoffsets; mehrere Ebenen mit Komma",
		Limitations = "Prozente beziehen sich auf den freien Raum. Ein- bis vierteilige Syntax; berechnete Längen und Viewport-Einheiten wie bei anderen Größen.",
	},
	["background-position-x"] = {Kind="background-position-axis",Field="BackgroundPositions",Axis="X",Inherited=false,
		Values="left | center | right | Länge/% einschließlich Kantenoffset; mehrere Ebenen mit Komma",Limitations="Horizontale Komponente von background-position; gleiche Ebenen- und Längengrenzen."},
	["background-position-y"] = {Kind="background-position-axis",Field="BackgroundPositions",Axis="Y",Inherited=false,
		Values="top | center | bottom | Länge/% einschließlich Kantenoffset; mehrere Ebenen mit Komma",Limitations="Vertikale Komponente von background-position; gleiche Ebenen- und Längengrenzen."},
	["background-repeat"] = {
		Kind = "background-repeat", Field = "BackgroundRepeats", Inherited = false,
		Values = "repeat | no-repeat | repeat-x | repeat-y | space | round; horizontal/vertikal und mehrere Ebenen",
		Limitations = "repeat/no-repeat/repeat-x/repeat-y pixelgenau zur berechneten Kachel. space wird wie repeat behandelt; round passt die Kachelzahl deterministisch an.",
	},
	["background-attachment"] = {
		Kind = "enum-list", Field = "BackgroundAttachments", Inherited = false,
		Allowed = {scroll=true,fixed=true,["local"]=true}, Values = "scroll | fixed | local; mehrere Ebenen",
		Limitations = "local hängt die Ebene an den Inhalt eines Overflow-Containers. fixed verankert sie beim Layout am Seiten-Viewport; Roblox aktualisiert sie nicht während eines laufenden nativen Scroll-Frames.",
	},
	["background-origin"] = {
		Kind = "background-box", Field = "BackgroundOrigins", Inherited = false,
		Values = "border-box | padding-box | content-box; mehrere Ebenen mit Komma",
		Limitations = "Bestimmt die Positionierungsfläche jeder Hintergrundebene.",
	},
	["background-clip"] = {
		Kind = "background-box", Field = "BackgroundClips", Inherited = false,
		Values = "border-box | padding-box | content-box; mehrere Ebenen mit Komma",
		Limitations = "Clipping einschließlich Hintergrundfarbe; gerundete innere Ecken sind eine Roblox-Näherung. Kein text-Clip.",
	},
	["box-shadow"] = {
		Kind = "box-shadow", Field = "BoxShadows", Inherited = false,
		Values = "none | [inset] x y [blur [spread]] [color], bis zu 16 Schatten",
		Limitations = "Blöcke: außen natives UIShadow, inset als zusammengesetztes EditableImage innerhalb der gerundeten Paddingbox. 0/px, signierter Offset/Spread, Blur 0–1000px. Farben wie color, currentcolor, transparent, Alpha-Hex, rgb()/rgba() und hsl()/hsla(). Keine Inline-Boxen, %, relativen Farbfunktionen. Inset: Gauß-Näherung, große Bilder reduziert; max32 Karten/4194304 Bildpixel pro Seite. Fehlende API/Budget: betroffene Innenschatten ausgelassen mit Diagnose. Box-Schattenlisten: CSS-/WAAPI-Interpolation, transparentes Padding, Add-Verkettung, Accumulate und diskrete Inset-Wechsel; aktuelle Farben, Autorbasen, Commit/Cancel und behaltene Paintflächen im Animationsprofil geprüft. Schatten ändern weder Layout noch Scrollausdehnung; native Inset-Sichtabnahme bleibt offen.",
	},
	["background"] = {
		Kind = "background", Field = "BackgroundShorthand", Inherited = false, Inline = true, CaseSensitive = true,
		Values = "Farbe und/oder Hintergrundebenen mit image position / size repeat origin clip",
		Limitations = "Setzt Farbe und alle sechs Ebenen-Longhands zurück. Einfarbige Hintergründe bleiben auch auf Inline-Text unterstützt; Bild-/Verlaufsebenen werden auf Blockboxen dargestellt. Keine globalen CSS-Bildfunktionen außerhalb des dokumentierten Profils.",
	},
	["width"] = {
		Kind = "length", Field = "Width", Inherited = false, AllowPercent = true, Replaced = true,
		Values = "auto | min-content | max-content | fit-content | nichtnegative Länge/% oder unterstützte CSS-Mathematik",
		Limitations = "Breite gemäß box-sizing, begrenzt durch min-width/max-width; intrinsische Proben teilen die vorhandene Text-/Bildmessung. Vollständige orthogonale/Flex-/Grid-Intrinsic-Kombinationen bleiben offen.",
	},
	["height"] = {
		Kind = "length", Field = "Height", Inherited = false, AllowPercent = true,
		Values = "auto | min-content | max-content | fit-content | nichtnegative Länge/% oder unterstützte CSS-Mathematik",
		Limitations = "Intrinsische bevorzugte Höhe im horizontalen Blockfluss, vertikalen direkten Text und Bildern; Keywords bleiben für Prozentkinder unbestimmt. Prozenthöhen brauchen eine bestimmte Elternhöhe; horizontale Quirks-Blöcke verwenden die historische Vorfahrensuche. Zellhöhen sind Mindesthöhen, in Quirks als Borderbox; Zell-min/max-height werden im Chromium-Profil ignoriert. Komplexe orthogonale/Flex-/Grid-/Prozent-/Gruppenkombinationen bleiben ein Teilumfang.",
	},
	["margin"] = {
		Kind = "spacing", Field = "Margin", Inherited = false, Replaced = true,
		Values = "1 bis 4 Werte: auto, 0 oder signierte px/% bis 100000",
		Limitations = "Prozente aller Seiten relativ zur Eltern-Inhaltsbreite. auto verteilt Restplatz bei Flexitems; normale Blöcke/Bilder horizontal. Kollaps: größter positiver plus kleinster negativer Abstand; Eltern-Kind-Collapsing wie bisher bei Listen/blockquote. Vollständige Kollapsketten leerer Blöcke fehlen.",
	},
	["padding"] = {
		Kind = "spacing", Field = "Padding", Inherited = false,
		Values = "1 bis 4 Werte: 0 oder nichtnegative px/% bis 100000",
		Limitations = "Prozente aller Seiten relativ zur Eltern-Inhaltsbreite, auch oben/unten; einzelne Seiten überschreiben die Kurzform gemäß Cascade.",
	},
	["font-size"] = {
		Kind = "font-size", Field = "FontSize", Inherited = true,
		Values = "0 bis 100 px | smaller | larger",
		Limitations = "CSS-/WAAPI-Abtastungen erneuern vererbte Text-/Inputmetriken und abhängige em/rem-Maße ohne GUI-Ersatz; Add/Accumulate, isolierte Autorbasen, Commit/Cancel und Transition-Reversal sind im C08-Profil geprüft. Nullschrift hat keine Glyphenmaße; positive Bruchteile werden nach Fontfaktor für Roblox-TextSize aufgerundet. smaller: Elternschrift / 1.2 (mindestens 1px); larger: Elternschrift * 1.2 (höchstens 100px). Native Fontmetriken bleiben Näherungen; Prozentgrößen, weitere Größenkeywords, deklarierte Größen über 100px, direkte Inline-/Pseudoelement-Animationsziele und weitere Formatierungs-/Effektkombinationen sind offen.",
	},
	["font-family"] = {
		Kind = "font-family", Field = "Font", Inherited = true,
		Values = "Kommagetrennte Schriftliste, Namen mit/ohne Anführungszeichen; sans-serif, serif, monospace, system-ui",
		Limitations = "Erste registrierte Familie. sans-serif/system-ui → Arial, serif → Roboto Slab, monospace → Roboto Mono; ohne Treffer options.DefaultFont (Standard PT Serif). Kein Glyphen-/Ladefehler-Fallback, CSS-Escapes oder Webfont-Download. Gewicht/Kursivstil separat; bestehende Fontprofile bleiben maßgeblich.",
	},
	["line-height"] = {
		Kind = "line-height", Field = "LineHeight", Inherited = true,
		Values = "normal, nichtnegative Dezimalzahl, px oder % (jeweils bis 100000)",
		Limitations = "Auch auf Inline-Text; gemischte Schriften können die Zeile vergrößern. CSS-/WAAPI-Animationen erhalten Zahlen als vererbte Multiplikatoren und Längen als Pixelwerte; px/em/rem/%, lineare calc und min/max/clamp verwenden den jeweils geprüften Schriftkontext. Zahlen/Längen und normal wechseln diskret. Add/Accumulate, Commit/Cancel, Autorbasiswechsel und CSS-Transition-Reversal aktualisieren behaltene Text-/Inputmetriken. normal/Glyphen-/Baseline-Metriken bleiben Näherungen; direkte Inline-/Pseudoelementziele und vollständige Formatierungs-/Mathematik-/Timingkombinationen sind offen (C08-Profil).",
	},
	["font-weight"] = {
		Kind = "font-weight", Field = "FontWeight", Inherited = true,
		Values = "normal | bold | Zahl 1–1000",
		Limitations = "Roblox-FontWeight in 100er-Stufen; Zwischenwerte werden auf den nächsten Schnitt gerundet. Fehlende Schnitte löst Roblox auf. Regular-Größen-/Linienkalibrierung bleibt für andere Gewichte eine Näherung; kein bolder/lighter.",
	},
	["text-align"] = {
		Kind = "text-align", Field = "TextAlign", Inherited = true,
		Values = "left (Standard) | center | right | justify | start | end",
		Limitations = "Gilt für Textzeilen des Blockcontainers. start/end folgen direction; justify verteilt Wortabstände. Kein vollständiger Unicode-Bidi-Algorithmus oder Silbentrennung. Überbreite Wörter können bei center/right links überlaufen.",
	},
	["font-style"] = {
		Kind = "font-style", Field = "FontStyle", Inherited = true,
		Values = "normal, italic",
		Limitations = "Mit Gewicht 400/700 kombinierbar; kein oblique oder Neigungswinkel. Fehlende Schnitte werden von Roblox aufgelöst. Kursiv-Größen-/Linienwerte sind noch nicht separat kalibriert.",
	},
	["font-size-adjust"] = {
		Kind = "font-size-adjust", Field = "FontSizeAdjust", Inherited = true,
		Values = "none | from-font | nichtnegative Zahl",
		Limitations = "Eine Zahl skaliert die verwendete Textgröße relativ zur Roblox-Referenz-x-Höhe 0,5. from-font behält die registrierte Fontprofilgröße; keine Zweiwertsyntax oder cap-height/ch-width-Metrik.",
	},
	["font-kerning"] = {Kind="font-kerning",Field="FontKerning",Inherited=true,Values="auto | normal | none",Limitations="Direkte Abbildung auf das OpenType-Feature kern; die sichtbare Wirkung hängt vom Roblox-Font ab."},
	["font-variant-caps"] = {Kind="font-variant-caps",Field="FontVariantCaps",Inherited=true,Values="normal | small-caps | all-small-caps",Limitations="Abbildung auf smcp und c2sc; Fonts ohne diese OpenType-Tabellen bleiben unverändert."},
	["font-variant-position"] = {Kind="font-variant-position",Field="FontVariantPosition",Inherited=true,Values="normal | sub | super",Limitations="Abbildung auf subs und sups; kein künstlicher Baseline-Ersatz, wenn der Font das Feature nicht enthält."},
	["font-feature-settings"] = {
		Kind = "font-feature-settings", Field = "FontFeatureSettings", Inherited = true,
		Values = "normal | kommagetrennte Tags: \"zero\", \"ss03\", \"liga\", \"calt\", \"kern\", \"smcp\", \"c2sc\", \"sups\", \"subs\", \"tnum\" mit optional 0/1",
		Limitations = "Neun Tags werden direkt auf GuiText.OpenTypeFeatures abgebildet. tnum nutzt gleich breite Ziffernzellen der Engine, weil Roblox das OpenType-Tag nicht freigibt.",
	},
	["font-variant-numeric"] = {
		Kind = "font-variant-numeric", Field = "FontVariantNumeric", Inherited = true,
		Values = "normal | slashed-zero | tabular-nums | lining-nums | Kombinationen dieser Werte",
		Limitations = "slashed-zero nutzt das Roblox-OpenType-Feature zero. tabular-nums setzt gleich breite Ziffernzellen mit der aktuellen Schrift; lining-nums verwendet die Standardziffern der Roblox-Schrift.",
	},
	["font-variant-ligatures"] = {
		Kind = "font-variant-ligatures", Field = "FontVariantLigatures", Inherited = true,
		Values = "normal | none | common-ligatures | no-common-ligatures | contextual | no-contextual",
		Limitations = "Abbildung auf liga und calt. Weitere Ligaturklassen fehlen; Wirkung hängt von der Schrift ab.",
	},
	["font-variant"] = {
		Kind = "font-variant", Field = "FontVariantShorthand", Inherited = true,
		Values = "normal | none | unterstützte Ligaturwerte und/oder slashed-zero, tabular-nums, lining-nums",
		Limitations = "Kurzform nur für die unterstützten Teile von font-variant-ligatures und font-variant-numeric.",
	},
	["display"] = {
		Kind = "display", Field = "Display", Inherited = false,
		Values = "inline | block | flow-root | inline-block | none | flex | inline-flex | grid | inline-grid | -ms-grid | -ms-inline-grid | contents | table | table-row | table-cell | table-row-group | table-header-group | table-footer-group | table-caption",
		Limitations = "inline-block/inline-flex nehmen als atomare Inline-Boxen an Zeilen teil; contents entfernt die eigene Box. Tabellenrollen benötigen eine explizite Struktur; kein inline-table.",
	},
}
properties["word-wrap"] = table.clone(properties["overflow-wrap"])
properties["word-wrap"].Limitations = "Alias für overflow-wrap; gleiche Cascade, Vererbung und Notumbruchregeln."
for _, side in {"top", "right", "bottom", "left"} do
	properties[side] = {Kind = "inset", Field = "Inset" .. side, Inherited = false, Values = "auto | 0 | signierte px oder % bis 100000", Limitations = "Positionierte Boxen; Prozent relativ zur Bezugsbox. Relative vertikale Prozente brauchen bestimmte Elternhöhe. LTR: left/top haben bei Widerspruch Vorrang."}
end
for name, field in {margin = "Margin", padding = "Padding"} do
	for side, suffix in {"top", "right", "bottom", "left"} do
		properties[name .. "-" .. suffix] = {
			Kind = "spacing-side", Field = field, Side = side, Inherited = false, Replaced = true,
			Values = if field == "Margin" then "auto | 0 | signierte px/% bis 100000" else "0 | nichtnegative px/% bis 100000",
			Limitations = "Eine physische Seite eines Blocks oder Bildes; Prozente relativ zur Eltern-Inhaltsbreite; keine Inline-Text-Abstände. " .. (if field == "Margin" then "auto wie bei margin." else "Kein auto."),
		}
	end
end
local logicalSides = {
	["inline"]={"inline-start","inline-end"}, ["block"]={"block-start","block-end"},
	["inline-start"]={"inline-start"}, ["inline-end"]={"inline-end"},
	["block-start"]={"block-start"}, ["block-end"]={"block-end"},
}
for name, field in {margin="Margin",padding="Padding"} do
	for suffix,sides in logicalSides do
		properties[name.."-"..suffix]={Kind="logical-spacing",Field=field,LogicalSides=sides,Inherited=false,Replaced=true,
			Values=if field=="Margin" then "1–2 Werte: auto | signierte Länge/%" else "1–2 Werte: nichtnegative Länge/%",
			Limitations="Physische Kante folgt berechnetem writing-mode/direction in allen fünf Modi. CSS-weite Vererbung liest die entsprechende logische Elternkante. Vollständige vertikale Block- und Prozentbasisfälle bleiben offen."}
	end
end
for suffix,sides in logicalSides do
	properties["inset-"..suffix]={Kind="logical-inset",Field="Inset",LogicalSides=sides,Inherited=false,
		Values="1–2 Werte: auto | signierte Länge/%",Limitations="Physische Inset-Kante folgt berechnetem writing-mode/direction in allen fünf Modi; entsprechende logische Elternkante bei inherit. Vollständige orthogonale Positionierungs- und Prozentbasisfälle bleiben offen."}
end
for suffix,sides in logicalSides do
	properties["border-"..suffix]={Kind="border",Field="Border",LogicalSides=sides,Inherited=false,Replaced=true,
		Values="[Breite] [Stil] [Farbe]",Limitations="Physische Rahmenkante folgt berechnetem writing-mode/direction in allen fünf Modi; entsprechende logische Elternkante bei inherit. Vollständige vertikale Inlinefragmentachsen bleiben offen."}
end
for suffix,sides in logicalSides do
	for component,kind in {width="border-width",style="border-style",color="border-color"} do
		local source=properties["border-"..component]
		properties["border-"..suffix.."-"..component]={Kind="logical-"..kind,Field=source.Field,LogicalSides=sides,LogicalValues=true,
			Inherited=false,Replaced=true,Values=if #sides==2 then "Ein oder zwei "..component.."-Werte" else source.Values:gsub("^1–4 Werte: ",""),
			Limitations="Physische Rahmenkante folgt berechnetem writing-mode/direction in allen fünf Modi; entsprechende logische Elternkante bei inherit. "..source.Limitations}
	end
end
for suffix,corner in { ["top-left"]="top-left",["top-right"]="top-right",["bottom-right"]="bottom-right",["bottom-left"]="bottom-left" } do
	properties["border-"..suffix.."-radius"]={Kind="corner-radius",Field="BorderRadius",Corner=corner,Inherited=false,Replaced=true,
		Values="Eine oder zwei nichtnegative Längen/%",Limitations="Horizontale und vertikale Einzelradien; Prozentwerte relativ zur Borderbox."}
end
-- Sizing longhands share their computed physical field after writing-mode is
-- cascaded. The metadata also preserves namesake logical inheritance.
for _,name in {'width','height','min-width','min-height','max-width','max-height'}do properties[name].Dimension=true end
for name,source in {
	["inline-size"]="width",["block-size"]="height",
	["min-inline-size"]="min-width",["max-inline-size"]="max-width",
	["min-block-size"]="min-height",["max-block-size"]="max-height",
} do
	local entry=table.clone(properties[source])
	entry.LogicalDimension=if name:find('inline',1,true)then 'inline'else 'block'
	entry.DimensionPrefix=if name:sub(1,3)=='min'then 'Min'elseif name:sub(1,3)=='max'then 'Max'else ''
	entry.Limitations="Physische Größenachse folgt berechnetem writing-mode in allen fünf Modi; entsprechende logische Elterngröße bei inherit. "..entry.Limitations
	properties[name]=entry
end
for name,source in {["overflow-inline"]="overflow-x",["overflow-block"]="overflow-y"}do
	local entry=table.clone(properties[source]);entry.Limitations="Horizontale Schreibrichtung; direkte logische Entsprechung von "..source..". "..entry.Limitations;properties[name]=entry
end
for _,name in {"start-start","start-end","end-end","end-start"} do
	properties["border-"..name.."-radius"]={Kind="corner-radius",Field="BorderRadius",LogicalCorner=name,Inherited=false,Replaced=true,
		Values="Eine oder zwei nichtnegative Längen/%",Limitations="Physische Ecke folgt berechnetem writing-mode/direction in allen fünf Modi; entsprechende logische Elternecke bei inherit. Prozentwerte relativ zur Borderbox; vollständige vertikale Inlinefragmentachsen bleiben offen."}
end
for _, key in {"width", "height", "min-width", "max-width", "min-height", "max-height",
	"margin", "padding", "border", "border-width", "border-style", "border-color", "border-radius",
	"outline", "outline-width", "outline-style", "outline-color", "outline-offset"} do
	properties[key].Replaced = true
end
for side, name in {"top", "right", "bottom", "left"} do
	for _, suffix in {"", "-width", "-style", "-color"} do
		local source = properties["border" .. suffix]
		local entry = table.clone(source)
		entry.BorderSide, entry.Replaced = side, true
		entry.BorderComponents = false
		entry.Values = entry.Values:gsub("^1–4 Werte: ", "")
		entry.Limitations = if suffix=='-color'then "Einzelne physische Rahmenfarbe; Farbformate und Alpha wie color. CSS/WAAPI Replace/Add/Accumulate, currentColor, Commit/Cancel und unabhängige Importance behalten die vorhandene Kante. Vollständige logische Aliase und Farb-/Timingkombinationen bleiben offen."else "Einzelne Rahmenkante; solid/inset/outset/groove/ridge/none/hidden/dashed/dotted/double. Diagonale Eckbilder; bei API-/Budgetgrenzen rechteckige Übergänge. Keine individuellen Rundungen. Musterbudget/-grenzen wie border-style."
		properties["border-" .. name .. suffix] = entry
	end
end
-- Grid values are parsed separately from ordinary box lengths.
local layoutValues=require(script.Parent.LayoutValues)
for name,field in {['margin-trim']='MarginTrim',['min-intrinsic-sizing']='MinIntrinsicSizing',['color-scheme']='ColorScheme',['align-tracks']='AlignTracks',['justify-tracks']='JustifyTracks',['grid-auto-position']='GridAutoPosition'} do
	properties[name]={Kind=if name=='align-tracks' or name=='justify-tracks' then 'tracks-alignment' else name,Field=field,Inherited=name=='color-scheme',Inline=name=='color-scheme',
		Values=if name=='margin-trim' then 'none | block | block-start || block-end' elseif name=='min-intrinsic-sizing' then 'legacy | zero-if-scroll || zero-if-extrinsic' elseif name=='color-scheme' then 'normal | light || dark, optional only' elseif name=='grid-auto-position' then '<grid-line> / <grid-line>' else 'normal | start | end | center | stretch | space-between | space-around | space-evenly; comma-separated tracks',
		Limitations=if name=='align-tracks' or name=='justify-tracks' then 'Historisches Masonry-Profil: Ausrichtung je Bahn; normale Grid-Container werden nicht verändert.' elseif name=='grid-auto-position' then 'Historischer Vorgabestart für automatisch platzierte Grid-Items; explizite Item-Platzierung gewinnt.' elseif name=='color-scheme' then 'Helle/dunkle Standardfarben für Canvas, native Controls und Scrollleisten. Autorenfarben bleiben erhalten; Auswahl über MediaFeatures.PreferredColorScheme.' elseif name=='margin-trim' then 'Block-Start/-End-Margins von direkten Flusskindern inklusive kollabierter Nachfahren; keine Inline-/Flex-/Grid-Trimmung.' else 'Komprimiert min-content-Beiträge nicht ersetzter horizontaler Boxen bei Scroll-/extrinsischer Größe; explizite Mindestgrößen bleiben erhalten.'}
end
for name in layoutValues.SizeShorthands do properties[name]={Kind='layout-shorthand',Field='SizeShorthand',Inherited=false,Values='ein oder zwei nichtnegative Längen/%; min-size: auto; max-size: none',Limitations='Kurzform für die vorhandenen min/max-width und min/max-height.'}end
for name in layoutValues.LegacyInsets do properties[name]={Kind='layout-shorthand',Field='LegacyInsetShorthand',Inherited=false,Values='ein oder zwei signierte Längen/%',Limitations='Historische Edge-/Interior-Endpunkte von Mehrspaltenlinien; Edge bezieht sich auf den Inhaltsrand, Interior auf innere Reihenabstände.'}end
for name,field in {['column-rule-edge-inset-start']='ColumnRuleEdgeInsetStart',['column-rule-edge-inset-end']='ColumnRuleEdgeInsetEnd',['column-rule-interior-inset-start']='ColumnRuleInteriorInsetStart',['column-rule-interior-inset-end']='ColumnRuleInteriorInsetEnd'} do
 properties[name]={Kind='column-rule-inset',Field=field,Inherited=false,Values='signierte Länge/%',Limitations='Historisches Edge-/Interior-Modell für Mehrspaltenlinien; positive Werte kürzen, negative verlängern.'}
end
properties['column-rule-outset']={Kind='layout-shorthand',Field='LegacyOutsetShorthand',Inherited=false,Values='ein oder zwei signierte Längen/%',Limitations='Historische Kurzform: positives Outset entspricht negativem column-rule-inset.'}
for name,spec in {['column-rule-break']={'ColumnRuleBreak',{none=true,normal=true,intersection=true}},['column-rule-visibility-items']={'ColumnRuleVisibilityItems',{all=true,around=true,between=true,normal=true}},['margin-break']={'MarginBreak',{auto=true,keep=true,discard=true}}} do
 properties[name]={Kind='enum',Field=spec[1],Inherited=false,Allowed=spec[2],Values=if name=='column-rule-break' then 'none | normal | intersection' elseif name=='margin-break' then 'auto | keep | discard' else 'all | around | between | normal',Limitations='Funktion innerhalb des Mehrspaltenprofils; kein Druck-/Seitenlayout und keine Grid-/Flex-Gap-Dekorationen.'}
end
local columnInsets=require(script.Parent.ColumnRuleInsets)
for name,field in columnInsets.Fields do
	properties[name]={Kind="column-rule-inset",Field=field,Inherited=false,
		Values="signierte Länge/% | overlap-join",Limitations="Mehrspaltenlinien: Prozentwerte relativ zum kreuzenden Reihenabstand, an Inhaltskanten 0; positive Werte kürzen, negative verlängern. Keine Grid-/Flex-Gap-Dekorationen oder row-rule."}
end
for name in columnInsets.Shorthands do
	properties[name]={Kind="column-rule-inset-shorthand",Field="ColumnRuleInsetShorthand",Inherited=false,
		Values="cap-start [cap-end] [ / junction-start [junction-end] ]; start/end: ein Wert; cap/junction: ein oder zwei Werte",
		Limitations="Kurzformen der vier column-rule-inset-Longhands; Funktion im Mehrspaltenprofil wie dort beschrieben."}
end
for name, field in require(script.Parent.GridValues).Fields do
 properties[name] = {Kind="grid",Field=field,Inherited=false,Inline=true,Values="CSS Grid tracks, areas or placement; see docs/GRID.md"}
end
for _, name in {"grid", "grid-template", "grid-row", "grid-column", "grid-area", "place-items", "place-self", "place-content"} do
 properties[name] = {Kind="grid-shorthand",Field=name,Inherited=false,Inline=true,Values="CSS Grid shorthand"}
end
for name,field in {['justify-items']='JustifyItems',['justify-self']='JustifySelf'} do
 properties[name]={Kind='enum',Field=field,Inherited=false,Inline=true,Allowed={normal=true,stretch=true,start=true,['end']=true,center=true,['self-start']=true,['self-end']=true,['flex-start']=true,['flex-end']=true,left=true,right=true,auto=name=='justify-self',baseline=true},Values=(if name=='justify-self'then'auto | 'else'')..'normal | stretch | start | end | center | self-start | self-end | flex-start | flex-end | left | right | baseline',Limitations='Horizontale Gridcontainer: Selfkanten fester Items einschließlich orthogonaler Schreibmodi, physisches left/right und Auto-Margin-Vorrang. Vollständige vertikale Containerachsen, Baselinekombinationen und safe/unsafe fehlen.'}
end
for _,name in {'align-items','align-self','justify-content','align-content'} do
 for _,value in {'normal','start','end'} do properties[name].Allowed[value]=true end
end
properties['justify-content'].Allowed.stretch=true
for _,name in {'align-items','align-self','justify-items','justify-self','align-content','justify-content'}do
 properties[name].Alignment=true
 properties[name].Values..=' | [safe | unsafe] followed by a positional value'
 properties[name].Limitations='Explizite safe/unsafe-Positionswerte in horizontalen Flex-/Gridcontainern einschließlich Margin-Box-Overflow, Reverse/RTL und Auto-Margin-Vorrang; qualifiziertes normal auf self-Eigenschaften behält den vorhandenen Normal-Größenpfad. Vorhandene Flex-Static-/Anchor-Area-Positionspfade unterscheiden explizite und automatische Overflowregeln. Vollständige vertikale Container-/Baseline-/Fragmentachsen, automatische Scrollsicherheit und weitere Layoutkombinationen bleiben offen.'
end
-- Legacy gap names share the canonical declaration fields and cascade.
for alias, canonical in {['grid-gap']='gap',['grid-row-gap']='row-gap',['grid-column-gap']='column-gap'} do
	local entry=table.clone(properties[canonical])
	entry.Limitations="Alias für "..canonical..". "..entry.Limitations
	properties[alias]=entry
end
for alias,canonical in layoutValues.Aliases do
 local entry=table.clone(properties[canonical]);entry.Limitations='Historischer Alias für '..canonical..'. '..(entry.Limitations or 'Gleicher Funktionsumfang wie die kanonische Eigenschaft.');properties[alias]=entry
end
-- Microsoft track declarations belong to the old display mode, not modern Grid.
for name,canonical in {['-ms-grid-columns']='grid-template-columns',['-ms-grid-rows']='grid-template-rows'} do
 local entry=table.clone(properties[canonical])
 entry.GridField=entry.Field;entry.Field='Legacy'..entry.Field
 entry.Limitations='Explizite Tracks nur für display: -ms-grid / -ms-inline-grid; ohne Wirkung auf modernes Grid. Keine vollständige IE-Grid-Emulation.'
 properties[name]=entry
end
require(script.Parent.VisualValues).register(properties)
for _, entry in properties do
	entry.Support = "supported"
	if (entry.Values:find("px", 1, true) or entry.Field == "FontShorthand") and entry.Field ~= "Filter" then
		entry.RelativeUnits = "em | rem | vw | vh | vmin | vmax | calc() | min() | max() | clamp()"
		entry.Values ..= "; relative Viewport-/Schrifteinheiten und CSS-Mathematik ebenfalls bei Längen"
	end
	entry.CSSWide = "inherit | initial | unset | revert | revert-layer"
	if entry.Allowed then table.freeze(entry.Allowed) end
	table.freeze(entry)
end
return table.freeze(properties)
