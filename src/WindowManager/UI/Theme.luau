--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Theme — was das GANZE Projekt braucht: Farben, Maße, Schriften, Timings.

	Die Regel, die dieses Modul erst wertvoll macht:
	KEIN Color3.fromRGB und KEIN TweenInfo.new ausserhalb eines Themes.

	Ohne sie landen Farbwerte in zwanzig Modulen, und beim ersten Versuch,
	einen Dunkelmodus oder eine andere Akzentfarbe nachzurüsten, muss man
	sie alle einzeln finden.

	WAS HIER NICHT MEHR STEHT, und warum:

		Taskbar/TaskbarTheme    Höhe der Leiste, Symbolgrösse, ihre dunklen Farben
		Desktop/DesktopTheme    Rasterzelle, Symbolgrösse, Hintergrundfarbe

	Ein Wert gehört hierher, wenn ihn MEHRERE Bereiche brauchen — die
	Akzentfarbe, die Listenfarben, die Tweens, der Zeilenausgleich der
	Schrift. Ein Wert, den genau ein Bereich braucht, gehört zu diesem
	Bereich. Sonst wächst diese Datei zur Ablage für alles, und man liest
	beim Suchen nach einer Fensterfarbe an vierzig Taskleistenwerten vorbei.

	Die Feature-Themes holen sich von hier, was sie brauchen (blend, accent,
	die Listenfarben) — der Pfeil zeigt also von aussen nach innen und nie
	umgekehrt.

	Alle Pixelwerte sind "Windows-Pixel" bei 100 % Anzeigeskalierung.
	Skalieren macht später ein einziges globales UIScale, nicht die
	einzelnen Module — deshalb stehen hier echte Zahlen und keine Faktoren.

	API
		Theme.color · Theme.size · Theme.font · Theme.tween · Theme.delay
		Theme.cursor · Theme.z
		Theme.changed (Event)  -- feuert bei Akzentwechsel
		Theme.setAccent(color)
		Theme.blend(bg, fg, alpha) · Theme.luminance(color)
		Theme.contrastOn(bg) · Theme.resolveColor(value, bg, dim?)
		Theme.scaleFor(viewportY)
--]]

local Root = script.Parent.Parent

local Event = require(Root.Framework.Event)

local Theme = {}

--[[
	Feuert, wenn sich die Akzentfarbe ändert. Module, die Akzentfarben
	benutzen, hängen sich hier ein statt die Farbe zu kopieren — eine Kopie
	würde beim Wechsel nicht mitziehen.

		Theme.changed:connect(function(accent) stroke.Color = accent end)
--]]
Theme.changed = Event.new()

--------------------------------------------------------------------------
-- Farben
--------------------------------------------------------------------------

-- Nur hier, damit die Werte unten kurz bleiben und lesbar sind.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

--[[
	Die Hex-Werte in den Kommentaren sind aus Windows 10 abgemessen, nicht
	geschätzt. Wo sie stehen, bitte nicht "runden" — gerade die vier
	Listenfarben und die beiden Rahmengrautöne erkennt das Auge sofort als
	falsch, wenn sie daneben liegen.
--]]
Theme.color = {
	-- Akzent. Hover/Pressed werden von setAccent mitberechnet, siehe unten.
	accent          = rgb(0, 120, 215),   -- #0078D7  Windows-Standardblau
	accentHover     = rgb(22, 131, 216),
	accentPressed   = rgb(0, 108, 190),

	-- Grundflächen
	windowBg        = rgb(255, 255, 255),
	chrome          = rgb(240, 240, 240),   -- #F0F0F0  Dialog-Fussleisten
	border          = rgb(223, 223, 223),
	divider         = rgb(229, 229, 229),

	-- Text
	text            = rgb(0, 0, 0),
	textInactive    = rgb(153, 153, 153),
	textDisabled    = rgb(160, 160, 160),
	textOnAccent    = rgb(255, 255, 255),

	-- Caption-Buttons (Minimieren / Maximieren / Schliessen)
	captionHover    = rgb(229, 229, 229),
	captionPressed  = rgb(204, 204, 204),
	closeHover      = rgb(232, 17, 35),    -- #E81123
	closePressed    = rgb(241, 112, 122),  -- #F1707A

	--[[
		Die vier Listenfarben. Sie sind der eigentliche "Windows-Look":
		Explorer, Startmenü, Kontextmenüs und jede Auswahlliste benutzen
		genau diese Werte. Hover ist heller als Selected, und der Rahmen
		liegt zwischen beiden.
	--]]
	listHover       = rgb(229, 243, 255),  -- #E5F3FF
	listSelected    = rgb(204, 232, 255),  -- #CCE8FF
	listBorder      = rgb(153, 209, 255),  -- #99D1FF
	listInactive    = rgb(240, 240, 240),

	--[[
		Fensterrahmen. Der Unterschied zwischen fokussiert und unfokussiert
		läuft über die FARBE, nicht über Transparenz — beides gleichzeitig
		würde sich gegenseitig verwaschen.
	--]]
	windowBorder         = rgb(112, 112, 112),  -- #707070  fokussiert
	windowBorderInactive = rgb(170, 170, 170),  -- #AAAAAA  unfokussiert

	-- Scrollbar
	scrollThumb     = rgb(205, 205, 205),
	scrollHover     = rgb(166, 166, 166),
	scrollPressed   = rgb(96, 96, 96),
	scrollTrack     = rgb(240, 240, 240),

	-- Neutral. Da, damit auch Schwarz und Weiss nicht per fromRGB
	-- irgendwo im Projekt auftauchen müssen.
	white           = rgb(255, 255, 255),
	black           = rgb(0, 0, 0),
}

--------------------------------------------------------------------------
-- Maße
--------------------------------------------------------------------------

Theme.size = {
	-- Fenster
	titlebarHeight    = 32,
	captionWidth      = 46,
	captionHeight     = 32,

	--[[
		Caption-Buttons eines DIALOGS sind kleiner als die eines Fensters.

		Gemessen: 31 breit, 29 hoch — gegenüber 46 x 32 beim normalen Fenster.
		Ein Dialog hat nur den Schliessen-Button, und Windows lässt ihn
		schmaler ausfallen, weil daneben kein zweiter sitzt.

		Als Vector2, damit beide Werte zusammen bleiben: sie gehören zu einem
		Maß und nicht zu zwei.
	--]]
	dialogCaption     = Vector2.new(31, 29),
	windowIcon        = 16,
	windowBorder      = 1,
	windowMin         = Vector2.new(200, 120),
	resizeGrip        = 6,
	snapZone          = 20,

	-- Text
	text              = 14,
	textLarge         = 20,

	--[[
		Schriftgrösse des Fenstertitels.

		Windows benutzt Segoe UI in 9 pt. Bei 96 DPI sind das 12 px em-Grösse,
		und Robloxʼ TextSize ist ebenfalls die em-Grösse in Pixeln — 12 wäre
		also dimensionsgleich.

		Hier steht trotzdem 14, und das ist ein Ausgleich für die Schrift:
		SourceSans hat eine deutlich kleinere x-Höhe als Segoe UI. Bei
		gleicher em-Grösse wirken die Kleinbuchstaben dadurch rund ein Sechstel
		niedriger, und der Titel sieht zu klein aus.

		SOBALD SEGOE UI ALS FONTFACE DA IST: zurück auf 12. Dann stimmt die
		Messung wieder ohne Ausgleich.
	--]]
	titleText         = 14,

	--[[
		Senkrechter Ausgleich für MITTIG gesetzte einzeilige Beschriftungen.

		Roblox zentriert Text über die Zeilenhöhe der Schrift, nicht über die
		Höhe der sichtbaren Buchstaben. SourceSans lässt unter der Grundlinie
		mehr Platz als darüber (Raum für g, j, p), und dadurch sitzt eine
		zentrierte Zeile optisch zu tief — gemessen 3 px.

		EIN Wert für alle Stellen, weil es EINE Eigenschaft der Schrift ist und
		nicht der jeweiligen Fläche: der Fenstertitel in der 32 px hohen Leiste
		und die Beschriftung im 21 px hohen Knopf brauchen denselben Ausgleich.

		Negativ heisst nach oben. Mit echtem Segoe UI ist der Wert
		voraussichtlich 0 bis -1 — dann gehört er hier korrigiert, an einer
		Stelle.
	--]]
	centerTextOffsetY = -3,

	--[[
		Eingabe-Schwellen. Sie stehen hier und nicht im InputRouter, weil
		sie Gefühlssache sind und man sie zum Justieren an einem Ort
		zusammen sehen will.

		dragThreshold: so weit darf der Cursor bei gedrückter Taste wandern,
		bevor aus dem Klick ein Ziehen wird. Zu klein, und jeder Klick mit
		zitternder Hand verschiebt etwas; zu gross, und Ziehen fühlt sich
		zäh an. 4 px ist der Windows-Wert.
	--]]
	dragThreshold     = 4,
	doubleClickTime   = 0.5,  -- Sekunden, Windows-Vorgabe
}

--------------------------------------------------------------------------
-- Schriften
--------------------------------------------------------------------------

--[[
	Segoe UI gibt es in Roblox nicht. SourceSans ist die Zwischenlösung.

	UMSTIEG: Lädst du Segoe UI als FontFace hoch, wird NUR diese Tabelle
	getauscht — kein anderes Modul fasst Enum.Font an. Dann sieht das so aus:

		local SEGOE = "rbxassetid://DEINE_ID"

		Theme.font = {
			ui     = Font.new(SEGOE, Enum.FontWeight.Regular),
			medium = Font.new(SEGOE, Enum.FontWeight.SemiBold),
			bold   = Font.new(SEGOE, Enum.FontWeight.Bold),
			light  = Font.new(SEGOE, Enum.FontWeight.Light),
		}

	Wichtig dabei: Enum.Font gehört zur Property "Font", ein Font-Objekt zur
	Property "FontFace". Das heisst, beim Umstieg muss New (das Modul, das
	die Defaults setzt) von Font auf FontFace wechseln. Deshalb steht in
	New nur EINE Zeile dafür, und nicht in jedem Label eine.
--]]
Theme.font = {
	ui     = Enum.Font.SourceSans,
	medium = Enum.Font.SourceSansSemibold,
	bold   = Enum.Font.SourceSansBold,
	light  = Enum.Font.SourceSansLight,
}

--------------------------------------------------------------------------
-- Timings
--------------------------------------------------------------------------

--[[
	Windows-Animationen sind kurz. Alles über etwa 0.2 s fühlt sich träge
	an, weil man auf die Oberfläche wartet statt sie zu bedienen.

	instant ist mit Dauer 0 dabei, damit Code, der eine TweenInfo erwartet,
	nicht zwei Wege kennen muss — der Aufrufer prüft info.Time <= 0 und
	setzt den Wert direkt. Caption-Buttons brauchen genau das: in Windows
	färben sie sich ohne Übergang.
--]]
Theme.tween = {
	instant = TweenInfo.new(0,    Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
	fast    = TweenInfo.new(0.10, Enum.EasingStyle.Quad,   Enum.EasingDirection.Out),
	normal  = TweenInfo.new(0.15, Enum.EasingStyle.Quad,   Enum.EasingDirection.Out),
	window  = TweenInfo.new(0.20, Enum.EasingStyle.Quint,  Enum.EasingDirection.Out),
	screen  = TweenInfo.new(0.40, Enum.EasingStyle.Quint,  Enum.EasingDirection.Out),

	--[[
		Das Aufziehen der Aero-Snap-Vorschau.

		Länger als alles andere hier, und das mit Absicht: die Vorschau ist
		keine Rückmeldung auf einen Klick, sondern eine Ankündigung. Sie darf
		sich Zeit nehmen, weil man sie ansieht statt auf sie zu warten.

		Quint/Out startet schnell und läuft weich aus — dadurch wirkt das
		Rechteck, als würde es an seine Kante gezogen.
	--]]
	snapGrow = TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

-- Verzögerungen, bis etwas von selbst erscheint. In Sekunden.
Theme.delay = {
	tooltip   = 0.5,
	thumbnail = 0.4,   -- Fenstervorschau über der Taskleiste
	submenu   = 0.3,

	--[[
		WIE LANGE DER BOOTSCHIRM MINDESTENS STEHT.

		Eine Mindestdauer und keine feste: ist alles schneller fertig, wartet
		er trotzdem; dauert es länger, wartet er länger. Ein Schirm, der für
		zwei Bilder aufblitzt, sieht nach Fehler aus — und einer, der nach
		fester Zeit verschwindet, während noch geladen wird, zeigt einen
		halben Desktop.

		1.2 s ist genug, um gelesen zu werden, und kurz genug, um beim
		zwanzigsten Start nicht zu stören.
	--]]
	boot      = 1.2,

	--[[
		WIE LANGE DER SCHIRM SCHWARZ BLEIBT, bevor Logo und Ladekreis
		erscheinen.

		Windows zeigt beim Hochfahren erst nichts. Ohne diese Pause stünde
		das Logo schon da, bevor der Bildschirm überhaupt umgeschaltet hat —
		und der Start sähe aus, als wäre er schon halb vorbei.

		Sie kommt VOR der Mindestdauer, addiert sich also: 0.8 + 1.2 heisst
		zwei Sekunden, bevor überhaupt ausgeblendet werden darf.

		GESCHÄTZT, nicht gemessen. Wer es genau will, nimmt eine Aufnahme
		und zählt die Bilder bis zum ersten Logo.
	--]]
	bootBlank = 0.8,
}

--------------------------------------------------------------------------
-- Mauszeiger
--------------------------------------------------------------------------

--[[
	Deine hochgeladenen Cursor-Assets. Später fasst genau ein Modul
	Mouse.Icon an (der InputRouter), und der liest ausschliesslich von hier.

	Die Namen der Größenpfeile folgen der Windows-Konvention und geben die
	Achse an, entlang der der Pfeil zeigt:

		sizeNS    hoch/runter   obere und untere Kante
		sizeEW    links/rechts  linke und rechte Kante
		sizeNWSE  \             Ecken oben-links und unten-rechts
		sizeNESW  /             Ecken oben-rechts und unten-links

	OFFEN: I-Balken (text) und Wartekreis (wait) fehlen noch als Asset.
	Solange sie auf dem Pfeil stehen, ändert sich der Zeiger dort nicht —
	kein Fehler, nur noch nicht da. Sobald du sie hochlädst, hier eintragen.
--]]
local CURSOR_ARROW = "rbxassetid://100262753082865"
local CURSOR_HAND  = "rbxassetid://115026529201803"

Theme.cursor = {
	default  = CURSOR_ARROW,
	hand     = CURSOR_HAND,     -- Links, Startmenü-Kacheln, Desktopsymbole
	text     = CURSOR_ARROW,    -- OFFEN: I-Balken
	wait     = CURSOR_ARROW,    -- OFFEN: Wartekreis

	sizeNS   = "rbxassetid://84392589913047",
	sizeEW   = "rbxassetid://72662426894925",
	sizeNESW = "rbxassetid://116934724128037",
	sizeNWSE = "rbxassetid://130552258338642",
}

--------------------------------------------------------------------------
-- Ebenen
--------------------------------------------------------------------------

--[[
	DisplayOrder der ScreenGuis, eine pro Ebene. Die Abstände sind bewusst
	grob — dazwischen ist Platz, falls später eine Ebene fehlt.

	Fenster brauchen KEINE Spanne pro Fenster. Mit
	ZIndexBehavior = Sibling rendern Kinder immer über ihrem Elternteil,
	und ZIndex zählt nur zwischen Geschwistern. Ein Wert pro Fensterrahmen
	genügt. Eine Spanne je Fenster wäre überflüssig und kostete beim
	Debuggen mehr, als sie brächte.
--]]
Theme.z = {
	desktop       = 1,
	windows       = 2,
	taskbar       = 3,
	menus         = 4,
	notifications = 5,
	modals        = 10,
	login         = 50,
	boot          = 100,
	bluescreen    = 999,
}

--------------------------------------------------------------------------
-- Schaltflächen
--------------------------------------------------------------------------

--[[
	Windows-10-Schaltfläche.

	Der RAHMEN trägt den Zustand, nicht die Fläche. Beim Überfahren wird er
	blau, die Fläche nur leicht getönt — das ist der Unterschied zu älteren
	Windows-Versionen, wo die Fläche den Verlauf wechselte.

	Alle Werte aus Windows abgemessen. Die Hex-Angaben in den Kommentaren sind
	die Originalwerte; wer sie ändert, ändert den Look bewusst.
--]]
Theme.button = {
	--[[
		78 x 21 px, abgemessen an einer Windows-Schaltfläche im Dialog. Die
		Gruppenbreiten in MessageBox rechnen damit.

		Der Rand liegt INNEN (ApplyStrokeMode.Border), die Schaltfläche misst
		also mit Rand 78 x 21 und nicht 80 x 23. Läge er aussen, wäre sie zwei
		Pixel grösser als gemessen, und drei Knöpfe nebeneinander kämen um
		6 px daneben.
	--]]
	width           = 78,
	height          = 21,

	--[[
		Dieselbe Grösse wie Theme.size.text. Eine Knopfbeschriftung ist
		Fliesstext, kein Sonderfall — sie soll neben dem Text im Dialog nicht
		kleiner wirken.
	--]]
	textSize        = 14,

	--[[
		Der Rahmen ist immer 1 px und liegt AUF der Kante
		(ApplyStrokeMode.Border, setzt New.stroke). Läge er aussen, wäre die
		Schaltfläche 82 x 25 statt 80 x 23 und die Gruppe im Dialog käme nicht
		mehr auf ihr Maß.
	--]]
	borderWidth     = 1,

	--[[
		Die Ruhefarben. Aus Windows abgemessen, unabhängig von der
		Akzentfarbe — ein unberührter Knopf ist in Windows immer grau.
	--]]
	face            = rgb(225, 225, 225),   -- #E1E1E1
	border          = rgb(173, 173, 173),   -- #ADADAD

	--[[
		Abgeschaltet: flacher, hellerer Rahmen, grauer Text. Der Knopf soll
		nicht nur blasser aussehen, sondern erkennbar tot.
	--]]
	faceDisabled    = rgb(204, 204, 204),   -- #CCCCCC
	borderDisabled  = rgb(191, 191, 191),   -- #BFBFBF

	text            = rgb(0, 0, 0),
	textDisabled    = rgb(131, 131, 131),   -- #838383

	--[[
		Hover, Gedrückt und der Standardknopf werden aus der Akzentfarbe
		GERECHNET, nicht fest eingetragen. Theme.applyAccentToButton füllt sie,
		und ein Akzentwechsel zieht sie mit — genau wie in Windows, wo ein
		überfahrener Knopf die eingestellte Systemfarbe zeigt.
	--]]
	--[[
		HIER STEHT nil, UND DAS IST KEIN VERSEHEN — diese fünf werden am Ende
		der Datei von applyAccentToButton gefüllt und bei jedem setAccent neu.

		Wer nach faceHover sucht, findet also zuerst dieses nil. Die Zeile
		darüber sagt, wo der Wert wirklich herkommt; ganz weglassen wäre
		schlechter, denn dann fehlte die Aufzählung, welche Werte es
		überhaupt gibt.
	--]]
	faceHover       = nil,   -- <- applyAccentToButton
	borderHover     = nil,   -- <- applyAccentToButton
	facePressed     = nil,   -- <- applyAccentToButton
	borderPressed   = nil,   -- <- applyAccentToButton
	borderDefault   = nil,   -- <- applyAccentToButton
}

--[[
	Die akzentabhängigen Knopffarben nachziehen.

	Windows leitet sie aus der Akzentfarbe ab, und zwar als Tönung von Weiss:

		Hover     10 % Akzent über Weiss   ->  #E5F1FB
		Gedrückt  20 % Akzent über Weiss   ->  #CCE4F7

	Bei Windows-Standardblau (#0078D7) trifft die zweite Rechnung den
	gemessenen Wert exakt, die erste auf einen Zählschritt genau. Das ist
	billiger als vier feste Werte, die beim ersten Akzentwechsel falsch
	stehen.

	Der Rahmen ist beim Überfahren die Akzentfarbe selbst; gedrückt eine um
	30 % abgedunkelte Fassung (#005497, gemessen #005499).
--]]
function Theme.applyAccentToButton(accent)
	local b = Theme.button

	b.faceHover     = Theme.blend(Theme.color.white, accent, 0.1)
	b.facePressed   = Theme.blend(Theme.color.white, accent, 0.2)
	b.borderHover   = accent
	b.borderPressed = Theme.blend(accent, Theme.color.black, 0.3)

	--[[
		Der Standardknopf eines Dialogs — der, den Enter auslöst — trägt den
		Akzentrahmen dauerhaft. Das ersetzt den früheren grauen Fokusrahmen:
		in Windows 10 zeigt der Rahmen nicht "das Fenster ist aktiv", sondern
		"das hier passiert bei Enter".
	--]]
	b.borderDefault = accent
end

--------------------------------------------------------------------------
-- Helfer
--------------------------------------------------------------------------

--[[
	Mischt fg über bg. alpha 0 = nur bg, 1 = nur fg.

	Ersetzt handberechnete Hex-Werte für halbtransparente Overlays: statt
	auszurechnen, wie Schwarz mit 8 % über Weiss aussieht, schreibt man
	Theme.blend(weiss, schwarz, 0.08) und sieht, was gemeint ist.
--]]
function Theme.blend(bg, fg, alpha)
	return bg:Lerp(fg, math.clamp(alpha, 0, 1))
end

--[[
	Wahrgenommene Helligkeit, 0 (schwarz) bis 1 (weiss).

	Die drei Gewichte sind nicht willkürlich: das Auge ist für Grün weit
	empfindlicher als für Blau. Deshalb wirkt reines Blau dunkel, obwohl es
	ein kräftiger Farbwert ist — genau der Fall, der bei einem naiven
	Mittelwert (R+G+B)/3 falsch herauskäme und weisse Schrift auf blauem
	Grund zu schwarzer machen würde.
--]]
function Theme.luminance(color)
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
end

--[[
	Liefert Schwarz oder Weiss — was auf diesem Hintergrund lesbarer ist.

	Genau das macht Windows mit Titeltext und Caption-Glyphen: auf der
	blauen Akzent-Titelleiste werden sie weiss, auf der weissen
	Standardleiste schwarz. Die App hat darauf keinen Einfluss.

		Theme.contrastOn(Theme.color.accent)    -> weiss   (Helligkeit 0.40)
		Theme.contrastOn(Theme.color.windowBg)  -> schwarz (Helligkeit 1.00)
--]]
function Theme.contrastOn(background)
	if Theme.luminance(background) > 0.5 then
		return Theme.color.black
	end
	return Theme.color.white
end

--[[
	Löst einen Stilwert auf, der entweder "auto" oder eine feste Farbe ist.

	"auto" heisst: aus der Hintergrundfarbe ableiten. Das brauchen später
	Titelleiste und Caption-Glyphen, deren Farbe sich mit der Leistenfarbe
	ändert — und die ändert sich mit dem Fokus. Ein einmal eingefrorener
	Wert wäre nach dem ersten Fokuswechsel falsch.

	dim > 0 zieht das Ergebnis anteilig Richtung Hintergrund. So entsteht
	die gedämpfte Schrift unfokussierter Fenster, ohne dass man dafür eine
	zweite Farbe pflegen muss.

		Theme.resolveColor("auto", weiss)        -> schwarz
		Theme.resolveColor("auto", weiss, 0.45)  -> mittelgrau
		Theme.resolveColor(rot, weiss)           -> rot (unverändert)
--]]
function Theme.resolveColor(value, background, dim)
	local resolved = if typeof(value) == "Color3"
		then value
		else Theme.contrastOn(background)

	if dim and dim > 0 then
		return Theme.blend(resolved, background, dim)
	end

	return resolved
end

--[[
	Akzentfarbe zur Laufzeit wechseln — das ist Windows'
	"Akzentfarbe auswählen" in den Einstellungen.

	Hover und Pressed werden mitberechnet, damit sie nie zur Grundfarbe
	widersprüchlich stehen: Hover geht Richtung Weiss, Pressed Richtung
	Schwarz. Wer sie einzeln setzen könnte, würde sie irgendwann vergessen.
--]]
function Theme.setAccent(color)
	Theme.color.accent        = color
	Theme.color.accentHover   = Theme.blend(color, Theme.color.white, 0.08)
	Theme.color.accentPressed = Theme.blend(color, Theme.color.black, 0.12)

	--[[
		Die Knopffarben MÜSSEN hier mitgezogen werden. Vergisst man das, sieht
		ein überfahrener Knopf nach einem Akzentwechsel noch blau aus, während
		alles andere die neue Farbe trägt — und der Fehler fällt erst auf,
		wenn jemand die Akzentfarbe wirklich ändert.
	--]]
	Theme.applyAccentToButton(color)

	Theme.changed:fire(color)
end

--[[
	Skalierungsfaktor für das globale UIScale. Referenz ist 1080p, dort ist
	er genau 1 — deshalb sind alle Offset-Werte in diesem Projekt echte
	Windows-Pixel.

	Die Grenzen sind Notbremsen: unter 0.6 wäre Text nicht mehr lesbar,
	über 2 würde auf sehr hohen Auflösungen kaum noch ein Fenster passen.
--]]
function Theme.scaleFor(viewportY)
	return math.clamp(viewportY / 1080, 0.6, 2)
end

--[[
	Einmal beim Laden füllen, sonst stehen faceHover und die übrigen
	abgeleiteten Werte bis zum ersten Akzentwechsel auf nil.
--]]
Theme.applyAccentToButton(Theme.color.accent)

return Theme
