--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Titlebar — Symbol, Titel und die drei Caption-Buttons.

		local titlebar = Titlebar.mount(window)

	window muss liefern: frame, cleanup, title, icon (Farbe oder nil),
	close(), minimize(), toggleMaximize(), isMaximized().

	options
		showMinimize / showMaximize / showClose   je false lässt weg
		captionSize   Vector2, Standard 46 x 32. Dialoge nehmen 31 x 29.

	handle
		.frame            der Leisten-Frame, Ziehfläche für Drag
		.captionZone      Breite aller Buttons zusammen, in Pixeln
		:setTitle(text)
		:setFocused(bool)
		:updateMaximizeGlyph(bool)

	Die Buttons werden von rechts nach links gesetzt: Schliessen ganz aussen,
	dann Maximieren, dann Minimieren. Genau diese Reihenfolge hat Windows, und
	sie ergibt sich hier von selbst, weil jeder Slot um eine Buttonbreite
	weiter nach innen rutscht.
--]]

local Root = script.Parent.Parent

local Theme = require(Root.UI.Theme)
local New = require(Root.UI.New)
local Interactive = require(Root.UI.Interactive)
local Glyphs = require(Root.UI.Glyphs)

local Titlebar = {}

-- 8 px vom Rand + 16 px Symbol + 5 px Luft, an Windows abgemessen.
local TEXT_LEFT = 29
local GLYPH_SIZE = 10

--[[
	Ein Caption-Button.

	Die Fläche wird über BackgroundTransparency ein- und ausgeblendet, nicht
	über die Farbe — so kann derselbe Frame im Ruhezustand durchsichtig und
	beim Überfahren deckend sein, ohne dass zwei Farbwerte gepflegt werden.

	RICHTUNGSABHÄNGIGE DAUER. Beim Überfahren blendet die Fläche in einer
	Zehntelsekunde ein (Theme.tween.fast), beim Wegfahren verschwindet sie
	SOFORT (Theme.tween.instant). Genau so verhält sich Windows, und der
	Unterschied ist deutlich zu spüren: mit Ausblenden zieht der Zeiger einen
	blassen Schatten hinter sich her, und die Leiste wirkt träge.

	Beim Schliessen-Button fadet die GLYPHFARBE mit. Ohne das gäbe es einen
	sichtbaren Fehler: die rote Fläche käme in 0.1 s, das X würde aber sofort
	weiss — für einen Moment stünde also ein weisses X auf noch weissem Grund
	und wäre unsichtbar. Deshalb ist die Farbe ein zweiter PaintSpec mit
	derselben Dauer und nicht ein Interactive.tint() im onEnter.
--]]
--[[
	glyphAlpha(focused, hovered) -> number

	Wie durchsichtig ein Caption-Symbol ist.

	Im Ruhezustand zeigt ein unfokussiertes Fenster seine Symbole blasser —
	das ist der einzige Fokusunterschied, den Windows in der weissen
	Titelleiste macht.

	BEIM ÜBERFAHREN GILT DAS NICHT MEHR. Sobald der Zeiger auf dem Button
	steht, ist das Symbol voll deckend, egal ob das Fenster den Fokus hat.
	Das ist nicht nur Optik: die farbige Fläche kommt ohnehin in voller
	Stärke, und ein blasses Symbol darauf sähe aus, als wäre der Button
	abgeschaltet. Bei Schliessen wäre es besonders auffällig — ein halb
	durchscheinendes X auf sattem Rot.

	Rein gerechnet, damit die Vorrangfolge ohne Instanzen prüfbar ist.
--]]
function Titlebar.glyphAlpha(focused, hovered)
	if hovered then
		return 0
	end

	return if focused then 0 else 0.6
end

local function bindCaptionButton(slot, symbol, isClose, onClick, cleanup, onHover, input)
	local hoverColor = if isClose then Theme.color.closeHover else Theme.color.captionHover
	local pressColor = if isClose then Theme.color.closePressed else Theme.color.captionPressed

	local paints = {
		{
			instance = slot,
			prop = "BackgroundTransparency",
			idle = 1,
			hover = 0,
			press = 0,
			tweenInfo = Theme.tween.fast,
			tweenInfoOut = Theme.tween.instant,
		},
	}

	if isClose then
		table.insert(paints, {
			instance = symbol,
			prop = "ImageColor3",
			idle = Theme.color.text,
			hover = Theme.color.white,
			press = Theme.color.white,
			tweenInfo = Theme.tween.fast,
			tweenInfoOut = Theme.tween.instant,
		})
	end

	Interactive.bind(slot, {
		cleanup = cleanup,
		input = input,
		blocking = true,
		onClick = onClick,
		paints = paints,

		--[[
			Die Flächenfarbe wird direkt gesetzt, nicht getweent: nur die
			DECKKRAFT läuft über den Tween. Beim Drücken soll die dunklere
			Farbe sofort da sein, wie in Windows.
		--]]
		onEnter = function()
			slot.BackgroundColor3 = hoverColor
			onHover(true)
		end,

		--[[
			onLeave meldet nur den Zustand zurück. Die Fläche selbst blendet
			Interactive über den paint-Spec aus, hier geht es allein um die
			Deckkraft der Symbole.
		--]]
		onLeave = function()
			onHover(false)
		end,

		onDown = function(button)
			if button ~= 1 then
				return
			end
			slot.BackgroundColor3 = pressColor
		end,

		onUp = function(button, _, wasInside)
			if button == 1 and wasInside then
				slot.BackgroundColor3 = hoverColor
			end
		end,
	})
end

--------------------------------------------------------------------------

function Titlebar.mount(window, options)
	assert(window and window.frame, "Titlebar.mount: window.frame fehlt")
	assert(window.cleanup, "Titlebar.mount: window.cleanup fehlt")

	local config = options or {}
	local cleanup = window.cleanup
	local titleInset = math.max(0, math.round(config.titleInset or 0))

	local showMinimize = config.showMinimize ~= false
	local showMaximize = config.showMaximize ~= false
	local showClose = config.showClose ~= false

	--[[
		Caption-Größe. Ein normales Fenster hat 46 x 32, ein Dialog 31 x 29 —
		beides an Windows gemessen. Der Aufrufer gibt sie mit, weil Titlebar
		nicht wissen soll, was ein Dialog ist.
	--]]
	local captionSize = config.captionSize
		or Vector2.new(Theme.size.captionWidth, Theme.size.captionHeight)

	--[[
		ZIndex 10: über dem Inhalt (1), unter den Griffzonen (50). Damit
		liegen die Caption-Buttons über allem, was eine App in ihre Kopfzeile
		zeichnet.
	--]]
	local frame = New("Frame", {
		Name = "Titlebar",
		Size = UDim2.new(1, 0, 0, Theme.size.titlebarHeight),
		BackgroundColor3 = Theme.color.windowBg,
		ZIndex = 10,
		Parent = window.frame,
	})

	----------------------------------------------------------------------
	-- Symbol und Titel
	----------------------------------------------------------------------

	--[[
		Platzhaltersymbol: ein einfarbiges Quadrat. Sobald es echte
		App-Symbole gibt, wird hier ein ImageLabel daraus — die Maße bleiben.
	--]]
	local icon = nil

	if window.icon then
		icon = New("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, titleInset + 8, 0.5, 0),
			Size = UDim2.fromOffset(Theme.size.windowIcon, Theme.size.windowIcon),
			BackgroundColor3 = window.icon,
			Parent = frame,
		})
	end

	----------------------------------------------------------------------
	-- Caption-Buttons, von rechts nach links
	----------------------------------------------------------------------

	--[[
		Die Symbole liegen NICHT in einer flachen Liste, sondern nach Button
		gruppiert. Der Grund ist der Hover-Zustand: er gilt pro Button, nicht
		fürs ganze Fenster — überfährt man X, wird auch nur dessen Symbol
		deckend, die anderen bleiben blass.

		Der Maximieren-Button hat zwei Symbole (Maximieren und
		Wiederherstellen); beide gehören derselben Gruppe an, weil immer nur
		eines sichtbar ist.
	--]]
	local groups = {}
	local focused = true
	local slotCount = 0

	local function refreshGlyphs()
		for _, group in groups do
			local alpha = Titlebar.glyphAlpha(focused, group.hovered)

			for _, symbol in group.symbols do
				Glyphs.setTransparency(symbol, alpha)
			end
		end
	end

	local function addGroup(symbols)
		local group = { symbols = symbols, hovered = false }
		table.insert(groups, group)
		return group
	end

	local function nextSlot(name)
		local slot = New("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -slotCount * captionSize.X, 0, 0),
			Size = UDim2.fromOffset(captionSize.X, captionSize.Y),
			BackgroundColor3 = Theme.color.captionHover,
			BackgroundTransparency = 1,
			Parent = frame,
		})

		slotCount += 1
		return slot
	end

	local maximizeGlyph = nil
	local restoreGlyph = nil

	if showClose then
		local slot = nextSlot("Close")
		local symbol = Glyphs.create("close", GLYPH_SIZE, Theme.color.text, slot)
		local group = addGroup({ symbol })

		bindCaptionButton(slot, symbol, true, function()
			if window.requestClose then window:requestClose()else window:close()end
		end, cleanup, function(hovered)
			group.hovered = hovered
			refreshGlyphs()
		end, window.input)
	end

	if showMaximize then
		local slot = nextSlot("Maximize")

		--[[
			Zwei fertige Symbole, es wird nur umgeschaltet. Das ist billiger
			als das Bild bei jedem Zustandswechsel neu zu zeichnen — und
			Glyphs teilt beide Bilder ohnehin über seinen Zwischenspeicher.
		--]]
		maximizeGlyph = Glyphs.create("maximize", GLYPH_SIZE, Theme.color.text, slot)
		restoreGlyph = Glyphs.create("restore", GLYPH_SIZE, Theme.color.text, slot)
		restoreGlyph.Visible = false

		local group = addGroup({ maximizeGlyph, restoreGlyph })

		bindCaptionButton(slot, maximizeGlyph, false, function()
			window:toggleMaximize()
		end, cleanup, function(hovered)
			group.hovered = hovered
			refreshGlyphs()
		end, window.input)
	end

	if showMinimize then
		local slot = nextSlot("Minimize")
		local symbol = Glyphs.create("minimize", GLYPH_SIZE, Theme.color.text, slot)
		local group = addGroup({ symbol })

		bindCaptionButton(slot, symbol, false, function()
			window:minimize()
		end, cleanup, function(hovered)
			group.hovered = hovered
			refreshGlyphs()
		end, window.input)
	end

	--[[
		Der Titel kommt zuletzt: seine Breite hängt davon ab, wie viele
		Buttons tatsächlich erzeugt wurden. Bei einem Dialog ohne Minimieren
		und Maximieren ist mehr Platz.
	--]]
	local captionZone = slotCount * captionSize.X
	local textLeft = titleInset + (if icon then TEXT_LEFT else 10)

	--[[
		Der Titel füllt die ganze Leistenhöhe und wird von Roblox darin
		zentriert. centerTextOffsetY korrigiert die Zentrierung um den Betrag,
		den die Schrift unter der Grundlinie freilässt — ohne ihn sitzt die
		Zeile 3 px zu tief. Siehe Theme.size.centerTextOffsetY.
	--]]
	local titleLabel = New("TextLabel", {
		Name = "Titel",
		Position = UDim2.fromOffset(textLeft, Theme.size.centerTextOffsetY),
		Size = UDim2.new(1, -(textLeft + captionZone + 8), 1, 0),
		Text = window.title or "",
		TextSize = Theme.size.titleText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	----------------------------------------------------------------------

	local handle = {}
	handle.frame = frame
	handle.captionZone = captionZone

	function handle:setTitle(text)
		titleLabel.Text = text or ""
	end

	function handle:setTitleInset(value)
		local inset = math.max(0, math.round(value or 0))
		if inset == titleInset then return end
		titleInset = inset
		local left = titleInset + (if icon then TEXT_LEFT else 10)
		titleLabel.Position = UDim2.fromOffset(left, Theme.size.centerTextOffsetY)
		titleLabel.Size = UDim2.new(1, -(left + captionZone + 8), 1, 0)
		if icon then icon.Position = UDim2.new(0, titleInset + 8, 0.5, 0) end
	end

	--[[
		Windows lässt die Titelleiste weiss und trägt den Fokusunterschied
		allein über Titel und Symbole: unfokussiert werden sie blasser. Das
		war seinerzeit ein häufiger Kritikpunkt, ist aber die Vorgabe, solange
		"Titelleisten in Akzentfarbe anzeigen" ausgeschaltet ist.
	--]]
	function handle:setFocused(value)
		focused = value
		titleLabel.TextTransparency = if value then 0 else 0.45

		--[[
			refreshGlyphs statt einer Schleife über alle Symbole: ein Button,
			auf dem gerade der Zeiger steht, behält seine volle Deckkraft. Ohne
			das würde ein Fokuswechsel unter dem Zeiger den Button
			zurückblassen, obwohl man noch darauf zeigt.
		--]]
		refreshGlyphs()

		if icon then
			icon.BackgroundTransparency = Titlebar.glyphAlpha(value, false)
		end
	end

	-- Maximiert zeigt Windows zwei versetzte Rechtecke statt einem.
	function handle:updateMaximizeGlyph(isMaximized)
		if not maximizeGlyph then
			return
		end

		maximizeGlyph.Visible = not isMaximized
		restoreGlyph.Visible = isMaximized
	end

	return handle
end

return Titlebar
