--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Interactive — die Optik von Hover und Gedrückt, aufgesetzt auf den
	InputRouter.

	Der Router sagt, WAS passiert. Interactive sagt, WIE es aussieht. Ohne
	diese Trennung schreibt jedes Modul dieselben vier Zeilen (hovered
	merken, pressed merken, neu einfärben, Tween starten) — und jedes ein
	kleines bisschen anders.

		Interactive.bind(frame, {
			cleanup = cleanup,
			blocking = true,
			cursor = Theme.cursor.hand,

			paint = {
				instance = frame,
				prop = "BackgroundColor3",
				idle = Theme.color.listInactive,
				hover = Theme.color.listHover,
				press = Theme.color.listSelected,
			},

			onClick = function() print("geklickt") end,
		})

	Windows-Verhalten, das dabei herauskommt, ohne dass der Aufrufer etwas
	tun muss:

	  · Drücken, wegziehen  -> Optik zurück auf idle, Klick fällt aus
	  · Wieder reinfahren   -> Press-Optik kommt zurück
	  · Loslassen aussen    -> nichts passiert

	API
		.bind(frame, opts) -> unregister      opts.input ist Pflicht
		.paint(frame, spec, cleanup, input) -> unregister
		.tint(root, color) · .setTransparency(root, value)
		.stateOf(spec, hovered, pressed)
		.tweenFor(spec, hovered)
--]]

local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent

local Theme = require(Root.UI.Theme)
local Tween = require(Root.UI.Tween)

local Interactive = {}

--[[
	Ein PaintSpec beschreibt EINE Property in drei Zuständen:

		instance      das Objekt
		prop          Name der Property
		idle          Wert im Ruhezustand
		hover         Wert beim Überfahren
		press         Wert beim Drücken (optional, dann gilt hover)
		tweenInfo     Übergang HINEIN (optional, Standard Theme.tween.normal)
		tweenInfoOut  Übergang HINAUS (optional, Standard = tweenInfo)

	Mehrere davon über opts.paints, wenn ein Element in mehreren
	Eigenschaften reagiert — Fläche und Rahmen etwa, wie bei einer
	Windows-Schaltfläche.
--]]

--------------------------------------------------------------------------
-- Zustand -> Wert
--------------------------------------------------------------------------

--[[
	Welcher der drei Werte gilt gerade?

	press nur, wenn AUCH gehovert wird. Das ist der Kern des
	Windows-Verhaltens: zieht man mit gedrückter Maus vom Element weg, sieht
	es wieder aus wie im Ruhezustand, obwohl die Taste noch unten ist. Fährt
	man zurück, kommt die Press-Optik wieder.

	Als reine Funktion, damit die Fallunterscheidung prüfbar ist, ohne
	Tweens laufen zu lassen.
--]]
function Interactive.stateOf(spec, hovered, pressed)
	if pressed and hovered and spec.press ~= nil then
		return spec.press
	end

	if hovered then
		return spec.hover
	end

	return spec.idle
end

--[[
	Welche Dauer gilt für diesen Übergang?

	RICHTUNGSABHÄNGIG, und das ist Absicht. Windows blendet die Fläche eines
	Caption-Buttons beim Überfahren in etwa einer Zehntelsekunde ein, nimmt sie
	beim Wegfahren aber SOFORT weg. Der Unterschied ist deutlich zu spüren:
	ein Ausblenden lässt den Zeiger einen blassen Schatten hinter sich
	herziehen, und die Leiste wirkt träge.

	Fehlt tweenInfoOut, gilt tweenInfo in beide Richtungen — dann verhalten
	sich Specs wie vorher.

	Als reine Funktion, damit die Wahl prüfbar ist, ohne Tweens laufen zu
	lassen.
--]]
function Interactive.tweenFor(spec, hovered)
	local inInfo = spec.tweenInfo or Theme.tween.normal

	if hovered then
		return inInfo
	end

	return spec.tweenInfoOut or inInfo
end

--[[
	Setzt oder tweent auf den Zielwert.

	Den laufenden Tween abzubrechen macht UI/Tween; dort steht auch, warum
	es nötig ist und was ohne es passiert.

	DER SCHLÜSSEL IST DIE SPEC, nicht die Instanz. Eine Schaltfläche tweent
	Fläche und Rahmen unabhängig voneinander, und beide hängen an derselben
	Instanz — mit der Instanz als Schlüssel bräche der zweite Tween den
	ersten ab.
--]]
local function applySpec(spec, hovered, pressed, tweens)
	tweens:to(
		spec.instance,
		Interactive.tweenFor(spec, hovered),
		{ [spec.prop] = Interactive.stateOf(spec, hovered, pressed) },
		spec
	)
end

--------------------------------------------------------------------------
-- bind
--------------------------------------------------------------------------

--[[
	bind(frame, opts) -> unregister

	opts nimmt alle Handler des InputRouters plus:
		cleanup   Pflicht
		paint     ein PaintSpec
		paints    Liste von PaintSpecs
		blocking, cursor, enabled  gehen an den Router durch
--]]
function Interactive.bind(frame, opts)
	assert(frame, "Interactive.bind: frame fehlt")
	assert(type(opts) == "table", "Interactive.bind: opts muss eine Tabelle sein")
	assert(opts.cleanup, "Interactive.bind: opts.cleanup ist Pflicht")

	--[[
		Eigene Liste bauen, nicht in opts.paints hineinschreiben.

		In die Tabelle des Aufrufers zu schreiben (table.insert(opts.paints,
		opts.paint)) wäre der Fehler: wer seine Spec-Liste für zwei Elemente
		wiederverwendet, hat danach die Spec des ersten in der Liste des
		zweiten stehen, und die Farben wandern über Elemente hinweg.
	--]]
	local specs = {}

	if opts.paints then
		for _, spec in opts.paints do
			table.insert(specs, spec)
		end
	end

	if opts.paint then
		table.insert(specs, opts.paint)
	end

	local hovered = false
	local pressed = false

	local tweens = Tween.slots()

	local function repaint()
		for _, spec in specs do
			applySpec(spec, hovered, pressed, tweens)
		end
	end

	--[[
		Beim Aufräumen alles anhalten. Ein Tween auf eine zerstörte Instanz
		wirft zwar nicht, hält sie aber bis zum Ende am Leben.
	--]]
	opts.cleanup:add(function()
		tweens:cancelAll()
	end)

	--[[
		Drag-Handler nur weitergeben, wenn der Aufrufer sie wirklich hat.

		Sonst hielte der Router jedes Element für ziehbar und würde beim
		Wegziehen onUp verschlucken — dann ginge das Windows-Verhalten
		"drücken, wegziehen, loslassen = kein Klick" verloren, weil onUp
		nie käme und die Optik hängen bliebe.
	--]]
	local wantsDrag = opts.onDragStart ~= nil
		or opts.onDrag ~= nil
		or opts.onDragEnd ~= nil

	local handlers = {
		blocking = opts.blocking,
		cursor = opts.cursor,
		enabled = opts.enabled,

		onEnter = function()
			hovered = true
			repaint()
			if opts.onEnter then
				opts.onEnter()
			end
		end,

		onLeave = function()
			hovered = false
			repaint()
			if opts.onLeave then
				opts.onLeave()
			end
		end,

		onDown = function(button, pos)
			if button == 1 then
				pressed = true
				repaint()
			end
			if opts.onDown then
				opts.onDown(button, pos)
			end
		end,

		onUp = function(button, pos, wasInside)
			if button == 1 then
				pressed = false
				repaint()
			end
			if opts.onUp then
				opts.onUp(button, pos, wasInside)
			end
		end,

		onClick = opts.onClick,
		onDoubleClick = opts.onDoubleClick,
		onRightClick = opts.onRightClick,
		onScroll = opts.onScroll,
		onKey = opts.onKey,
	}

	if wantsDrag then
		handlers.onDragStart = opts.onDragStart
		handlers.onDrag = opts.onDrag

		-- Nach einem Drag kommt kein onUp, der Router meldet stattdessen
		-- onDragEnd. Ohne dieses Zurücksetzen bliebe die Press-Optik stehen.
		handlers.onDragEnd = function(pos, delta, cancelled)
			pressed = false
			repaint()
			if opts.onDragEnd then
				opts.onDragEnd(pos, delta, cancelled)
			end
		end
	end

	--[[
		DER ROUTER IST PFLICHT. Interactive ist ein Baustein ohne eigenen
		Besitzer — es weiss nicht, zu welchem System der Frame gehört, also
		muss es ihm gesagt werden.

		HIER STAND EIN RÜCKFALL auf die Standard-Instanz, und der war ein
		Fehler: er verdeckte genau die Stellen, an denen der Router nicht
		durchgereicht wurde. Solange die Standard-Instanz zufällig lief, ging
		alles gut; im Lebenszyklus — der seine eigene hat — knallte es. Und
		zwar nicht dort, wo die Verkabelung fehlte, sondern drei Ebenen
		tiefer.

		Ein Vorgabewert, der die Hälfte der Aufrufer stillschweigend an ein
		fremdes System hängt, ist schlimmer als ein assert.
	--]]
	local router = assert(opts.input, "Interactive.bind: opts.input fehlt")

	local unregister = router:register(frame, handlers, opts.cleanup)

	-- Startzustand malen, sonst steht das Element bis zur ersten
	-- Mausbewegung in den Farben, die beim Erzeugen zufällig gesetzt waren.
	repaint()

	return unregister
end

-- Kurzform: nur Optik, keine Callbacks.
function Interactive.paint(frame, spec, cleanup, input)
	return Interactive.bind(frame, { cleanup = cleanup, paint = spec, input = input })
end

--------------------------------------------------------------------------
-- Umfärben ganzer Teilbäume
--------------------------------------------------------------------------

--[[
	Ein Element mit diesem Attribut wird von tint und setTransparency
	übersprungen.

		frame:SetAttribute(Interactive.SKIP_ATTRIBUTE, true)

	Gebraucht für Flächen, die in einem Symbol nicht das Symbol sind, sondern
	Verdeckung leisten: das Wiederherstellen-Symbol besteht aus zwei
	Quadraten, und das vordere muss die Kanten des hinteren abdecken. Würde
	setTransparency seine Füllung mitverblassen, schienen die Linien beim
	unfokussierten Fenster durch — und aus zwei gestapelten Fenstern würde
	ein Gitter.

	Ein Attribut und keine Namensprüfung, damit es nicht daran hängt, wie
	jemand seinen Frame benannt hat.
--]]
Interactive.SKIP_ATTRIBUTE = "InteractiveSkip"

local function isSkipped(object)
	return object:GetAttribute(Interactive.SKIP_ATTRIBUTE) == true
end

--[[
	Färbt ein Element und alle Nachfahren um.

	Nötig, weil ein Symbol selten aus einem Objekt besteht: das X eines
	Schliessen-Buttons sind zwei gedrehte Frames, ein Kontrollkästchen ein
	Rahmen plus Häkchen. Welche Property die Farbe trägt, hängt an der
	Klasse — genau diese Fallunterscheidung steht hier einmal.
--]]
function Interactive.tint(root, color)
	local function apply(object)
		if isSkipped(object) then
			return
		end

		if object:IsA("ImageLabel") then
			object.ImageColor3 = color
		elseif object:IsA("TextLabel") or object:IsA("TextBox") then
			object.TextColor3 = color
		elseif object:IsA("UIStroke") then
			object.Color = color
		elseif object:IsA("Frame") then
			object.BackgroundColor3 = color
		end
	end

	apply(root)

	for _, descendant in root:GetDescendants() do
		apply(descendant)
	end
end

--[[
	Deckkraft eines Teilbaums setzen, mit derselben Fallunterscheidung.

	Wird beim Fokuswechsel gebraucht: Windows zeichnet die Caption-Symbole
	unfokussierter Fenster blasser.

	Frames mit BackgroundTransparency = 1 bleiben unangetastet — sie sind
	absichtlich unsichtbar (Träger und Layout-Hüllen), und sie sichtbar zu
	machen wäre das Gegenteil des Gewünschten.
--]]
function Interactive.setTransparency(root, value)
	local function apply(object)
		if isSkipped(object) then
			return
		end

		if object:IsA("ImageLabel") then
			object.ImageTransparency = value
		elseif object:IsA("TextLabel") or object:IsA("TextBox") then
			object.TextTransparency = value
		elseif object:IsA("UIStroke") then
			object.Transparency = value
		elseif object:IsA("Frame") and object.BackgroundTransparency < 1 then
			object.BackgroundTransparency = value
		end
	end

	apply(root)

	for _, descendant in root:GetDescendants() do
		apply(descendant)
	end
end

return Interactive
