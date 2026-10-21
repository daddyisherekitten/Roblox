--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Button — Windows-10-Schaltfläche, selbst gezeichnet.

		local ok = Button.create({
			parent = fussleiste,
			cleanup = cleanup,
			input = fenster.input,
			text = "OK",
			default = true,
			onClick = function() fenster:close() end,
		})

		ok:setFocused(false)   -- Fenster hat den Fokus verloren

	KEIN GuiButton. Das Verhalten kommt über Interactive vom InputRouter.

	KEINE BILDER MEHR. Eine Windows-10-Schaltfläche ist eine Fläche mit einem
	1-px-Rand — mehr nicht. Als Bild war sie an eine feste Grösse gebunden
	(78 x 21; jede andere Grösse interpoliert und macht den Rand unscharf) und
	an eine feste Akzentfarbe. Gezeichnet ist sie in jeder Grösse scharf und
	folgt der Systemfarbe.

	DER RAND LIEGT INNEN. Zwei ineinander liegende Flächen statt eines
	UIStroke — der zeichnet in Roblox immer nach aussen und würde die
	Schaltfläche 80 x 23 gross machen. Details am Aufbau unten.

	DER RAHMEN TRÄGT DEN ZUSTAND, nicht die Fläche. Das ist der Unterschied zu
	Windows 7 und älter, wo die Fläche ihren Verlauf wechselte:

		normal    Fläche #E1E1E1, Rand #ADADAD
		hot       Fläche 10 % Akzent auf Weiss, Rand Akzent
		pressed   Fläche 20 % Akzent auf Weiss, Rand Akzent, 30 % dunkler
		default   wie normal, aber Rand Akzent
		disabled  Fläche #CCCCCC, Rand #BFBFBF, Text #838383

	handle
		.frame · .fill
		:setText(text) · :setEnabled(bool) · :isEnabled()
		:setFocused(bool) · :setDefault(bool) · :getState()

	OFFEN: der gepunktete Tastaturfokus-Rahmen innerhalb des Knopfes. Er
	gehört zur Tastaturbedienung, und die gibt es noch nicht.
--]]

local Root = script.Parent.Parent

local Theme = require(Root.UI.Theme)
local New = require(Root.UI.New)
local Interactive = require(Root.UI.Interactive)

local Button = {}

--------------------------------------------------------------------------
-- Zustand
--------------------------------------------------------------------------

--[[
	stateOf(enabled, hovered, pressed, isDefault, windowFocused) -> string

	Die Vorrangfolge als reine Funktion, damit sie ohne Instanzen prüfbar ist.

	  · disabled schlägt alles. Ein abgeschalteter Knopf darf nicht
	    aufleuchten, auch wenn der Cursor darauf steht.
	  · pressed nur MIT hover. Zieht man mit gedrückter Maus weg, sieht der
	    Knopf wieder normal aus — dasselbe Windows-Verhalten wie überall im
	    Projekt, und aus demselben Grund: der Klick fällt aus.
	  · hot schlägt default. Der Standardknopf trägt den Akzentrahmen schon,
	    beim Überfahren kommt die getönte Fläche dazu.
	  · default nur, wenn das FENSTER den Fokus hat. Ein Dialog im
	    Hintergrund hebt seinen Standardknopf nicht hervor — dort passiert
	    gerade nichts, was Enter auslösen könnte.
--]]
function Button.stateOf(enabled, hovered, pressed, isDefault, windowFocused)
	if not enabled then
		return "disabled"
	end

	if pressed and hovered then
		return "pressed"
	end

	if hovered then
		return "hot"
	end

	if isDefault and windowFocused then
		return "default"
	end

	return "normal"
end

--[[
	colorsFor(state, style) -> face, border, text

	Die Farbtabelle als reine Funktion. Getrennt vom Zeichnen, damit sich
	prüfen lässt, dass zum Beispiel "hot" wirklich den Akzentrahmen bekommt —
	ohne dafür eine Instanz zu bauen.
--]]
function Button.colorsFor(state, style)
	local s = style or Theme.button

	if state == "disabled" then
		return s.faceDisabled, s.borderDisabled, s.textDisabled
	end

	if state == "pressed" then
		return s.facePressed, s.borderPressed, s.text
	end

	if state == "hot" then
		return s.faceHover, s.borderHover, s.text
	end

	if state == "default" then
		return s.face, s.borderDefault, s.text
	end

	return s.face, s.border, s.text
end

--------------------------------------------------------------------------
-- create
--------------------------------------------------------------------------

--[[
	create(config)

	parent, cleanup   Pflicht
	text              Beschriftung
	position, size, anchorPoint, layoutOrder
	enabled           false schaltet ab
	default           true macht ihn zum Standardknopf (Akzentrahmen)
	focused           Startzustand des FENSTERS, Standard true
	onClick
	style             überschreibt einzelne Werte aus Theme.button
--]]
function Button.create(config)
	assert(config, "Button.create: config fehlt")
	assert(config.parent, "Button.create: parent fehlt")
	assert(config.cleanup, "Button.create: cleanup ist Pflicht")
	assert(config.input, "Button.create: input ist Pflicht — der Router des eigenen Systems")

	-- table.clone, damit ein einzelner Knopf nicht die Vorgabe für alle
	-- anderen verändert.
	local style = table.clone(Theme.button)

	if config.style then
		for key, value in config.style do
			style[key] = value
		end
	end

	local enabled = config.enabled ~= false
	local windowFocused = config.focused ~= false
	local isDefault = config.default == true

	--[[
		ZWEI FLÄCHEN, KEIN UIStroke.

		Ein UIStroke zeichnet immer NACH AUSSEN, in beiden ApplyStrokeMode-
		Varianten. Eine 78 x 21 grosse Schaltfläche mit 1-px-Stroke misst also
		80 x 23, und drei davon nebeneinander sprengen die Gruppenbreite, mit
		der MessageBox rechnet. Einen einwärts gezeichneten Rand gibt es in
		Roblox nicht.

		Deshalb: die äussere Fläche IST der Rand, die innere liegt 1 px
		eingerückt darin. Zusammen sind sie exakt 78 x 21, und die Farben
		lassen sich einzeln umschalten — genau das, was die Zustände brauchen.
	--]]
	local frame = New("Frame", {
		Name = "Button",
		Position = config.position,
		Size = config.size or UDim2.fromOffset(style.width, style.height),
		AnchorPoint = config.anchorPoint,
		LayoutOrder = config.layoutOrder,

		BackgroundColor3 = style.border,

		Parent = config.parent,
	})

	--[[
		Die innere Fläche. Auf allen vier Seiten um borderWidth eingerückt,
		deshalb zweimal abgezogen: einmal links, einmal rechts.

		Sie ist immer da und wechselt nur die Farbe. Sie je nach Zustand zu
		erzeugen und zu zerstören wäre bei jedem Überfahren eine Instanz mehr —
		und Überfahren passiert dauernd.
	--]]
	local inset = style.borderWidth

	local fill = New("Frame", {
		Name = "Fill",
		Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
		BackgroundColor3 = style.face,
		Parent = frame,
	})

	--[[
		KEIN Zentrierungsausgleich hier, anders als beim Fenstertitel.

		Der Titel steht auf einer weissen Fläche, in der Roblox rein nach
		Zeilenhöhe zentriert — dort sitzt die Zeile 3 px zu tief und braucht
		Theme.size.centerTextOffsetY. Beim Knopf ist die Fläche genau so hoch
		wie die Zeile, und mittig ist mittig.

		Die Beschriftung steht fest. Der flache Windows-10-Knopf verschiebt
		sie beim Drücken NICHT — das Einsinken stammt aus der Zeit der
		Verläufe, und bei einer Farbfläche mit 1-px-Rand gibt es nichts, in
		das der Text einsinken könnte. Der Zustandswechsel läuft allein über
		Fläche und Rand.
	--]]
	local label = New("TextLabel", {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		Text = config.text or "",
		TextSize = style.textSize,
		TextColor3 = style.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = fill,
	})

	----------------------------------------------------------------------
	-- Optik
	----------------------------------------------------------------------

	local hovered = false
	local pressed = false

	local function repaint()
		local state = Button.stateOf(enabled, hovered, pressed, isDefault, windowFocused)
		local face, border, text = Button.colorsFor(state, style)

		--[[
			Ohne Tween, wie in Windows: Drücken ist ein Umschalten, kein
			Übergang.
		--]]
		frame.BackgroundColor3 = border
		fill.BackgroundColor3 = face
		label.TextColor3 = text
	end

	Interactive.bind(frame, {
		input = config.input,
		cleanup = config.cleanup,
		blocking = true,

		onEnter = function()
			hovered = true
			repaint()
		end,

		onLeave = function()
			hovered = false
			repaint()
		end,

		onDown = function(button)
			if button == 1 then
				pressed = true
				repaint()
			end
		end,

		onUp = function(button)
			if button == 1 then
				pressed = false
				repaint()
			end
		end,

		onClick = function()
			if enabled and config.onClick then
				config.onClick()
			end
		end,
	})

	repaint()

	----------------------------------------------------------------------

	local handle = {}
	handle.frame = frame

	--[[
		Die innere Fläche nach aussen gereicht: wer eine Schaltfläche mit
		eigenem Inhalt füllen will (ein Symbol statt Text), hängt es dort
		hinein und nicht an den Rand.
	--]]
	handle.fill = fill

	function handle:setText(text)
		label.Text = text or ""
	end

	function handle:setEnabled(value)
		enabled = value
		repaint()
	end

	function handle:isEnabled()
		return enabled
	end

	--[[
		Wird vom Fenster gerufen, wenn es den Fokus wechselt. Ein Dialog im
		Hintergrund zeigt seinen Standardknopf ohne Akzentrahmen — das ist der
		Unterschied zwischen "gerade nicht dran" und "abgeschaltet".
	--]]
	function handle:setFocused(value)
		windowFocused = value
		repaint()
	end

	function handle:setDefault(value)
		isDefault = value
		repaint()
	end

	function handle:getState()
		return Button.stateOf(enabled, hovered, pressed, isDefault, windowFocused)
	end

	return handle
end

--[[
	Gesamtbreite einer Knopfgruppe, inklusive der Lücken dazwischen.

	Rein gerechnet, weil MessageBox sie zweimal braucht: einmal um zu prüfen,
	ob der Dialog breit genug ist, und einmal um die Gruppe rechts
	auszurichten.
--]]
function Button.groupWidth(count, gap, width)
	local buttonWidth = width or Theme.button.width
	return count * buttonWidth + math.max(count - 1, 0) * gap
end

return Button
