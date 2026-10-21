--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Resize — acht Griffzonen an Kanten und Ecken.

		Resize.mount(window, cleanup)

	window muss liefern: getPosition, setPosition, getSize, setSize,
	isMaximized, focus. Mehr braucht dieses Modul nicht zu wissen — dadurch
	arbeitet es mit dem Prototyp-Fenster aus der Demo genauso wie später mit
	der Window-Klasse.

	API
		.mount(window, cleanup, options?) -> handle
		.zones() -> Liste der acht Zonen

	handle
		:setEnabled(bool)  Griffe abschalten — bei einem maximierten Fenster
		                   und bei Dialogen. Nimmt Hover, Zeiger und Ziehen
		                   zugleich weg.
		:isEnabled()
		.grips             die acht Frames

	Reine Rechnung, ohne Roblox-Objekte und damit testbar:
		.apply(position, size, dx, dy, delta, minSize) -> position, size
--]]

local Root = script.Parent.Parent

local Theme = require(Root.UI.Theme)
local New = require(Root.UI.New)
local Interactive = require(Root.UI.Interactive)

local Resize = {}

local G = Theme.size.resizeGrip

--[[
	Die acht Zonen.

	dx und dy sagen, welche Kante angefasst wurde:

		-1  linke bzw. obere Kante   -> Position UND Grösse ändern sich
		 1  rechte bzw. untere Kante -> nur die Grösse ändert sich
		 0  diese Achse bleibt unberührt

	Die Namen folgen der Windows-Konvention (Himmelsrichtungen), die Zeiger
	dazu kommen aus Theme.cursor.

	SIE LIEGEN AUSSERHALB DES FENSTERS.

	Das ist der Punkt, an dem der erste Entwurf falsch war: dort sassen die
	Zonen innen, und der 6 px hohe Streifen an der Oberkante lag damit über
	den Caption-Buttons. Bei einem 32 px hohen Schliessen-Button wäre knapp
	ein Fünftel seiner Fläche eine Griffzone gewesen — man zielt auf das X,
	trifft die Kante und ändert die Fenstergrösse.

	Windows macht es genauso: der Rahmen zum Ziehen liegt als unsichtbarer
	Ring UM das Fenster, nicht darin. Deshalb sind die Offsets negativ
	beziehungsweise gehen über 1 hinaus:

		            NW │      N       │ NE
		          ─────┼──────────────┼─────
		             W │   Fenster    │ E
		          ─────┼──────────────┼─────
		            SW │      S       │ SE

	Die Kanten laufen über die volle Breite bzw. Höhe des Fensters, die Ecken
	sitzen in den vier Zwickeln daneben. Dadurch überlappt nichts, und jede
	Stelle des Rings gehört genau einer Zone.

	Nebeneffekt, der so gewollt ist: der Ring verschluckt Klicks im 6-px-Saum
	um das Fenster. Genau das tut der unsichtbare Rahmen in Windows auch.
--]]
local ZONES = {
	-- Kanten: über die volle Länge, direkt aussen anliegend
	{
		name = "N", dx = 0, dy = -1, cursor = Theme.cursor.sizeNS,
		position = UDim2.new(0, 0, 0, -G),
		size = UDim2.new(1, 0, 0, G),
	},
	{
		name = "S", dx = 0, dy = 1, cursor = Theme.cursor.sizeNS,
		position = UDim2.new(0, 0, 1, 0),
		size = UDim2.new(1, 0, 0, G),
	},
	{
		name = "W", dx = -1, dy = 0, cursor = Theme.cursor.sizeEW,
		position = UDim2.new(0, -G, 0, 0),
		size = UDim2.new(0, G, 1, 0),
	},
	{
		name = "E", dx = 1, dy = 0, cursor = Theme.cursor.sizeEW,
		position = UDim2.new(1, 0, 0, 0),
		size = UDim2.new(0, G, 1, 0),
	},

	--[[
		Die Ecken sitzen in den Zwickeln, also diagonal ausserhalb. NW und SE
		liegen auf derselben Diagonalen und teilen den Zeiger, ebenso NE und
		SW auf der anderen.
	--]]
	{
		name = "NW", dx = -1, dy = -1, cursor = Theme.cursor.sizeNWSE,
		position = UDim2.new(0, -G, 0, -G),
		size = UDim2.fromOffset(G, G),
	},
	{
		name = "NE", dx = 1, dy = -1, cursor = Theme.cursor.sizeNESW,
		position = UDim2.new(1, 0, 0, -G),
		size = UDim2.fromOffset(G, G),
	},
	{
		name = "SW", dx = -1, dy = 1, cursor = Theme.cursor.sizeNESW,
		position = UDim2.new(0, -G, 1, 0),
		size = UDim2.fromOffset(G, G),
	},
	{
		name = "SE", dx = 1, dy = 1, cursor = Theme.cursor.sizeNWSE,
		position = UDim2.new(1, 0, 1, 0),
		size = UDim2.fromOffset(G, G),
	},
}

function Resize.zones()
	return ZONES
end

--------------------------------------------------------------------------
-- Die Rechnung
--------------------------------------------------------------------------

--[[
	apply(position, size, dx, dy, delta, minSize) -> position, size

	position und size sind die Werte vom BEGINN des Ziehens, delta die
	gesamte Mausbewegung seitdem. Absolut gerechnet, nicht schrittweise —
	sonst summieren sich Rundungsfehler über hundert Frames auf.

	An einer rechten oder unteren Kante ändert sich nur die Grösse. An einer
	linken oder oberen ändern sich Position UND Grösse gleichzeitig, und
	zwar gegenläufig: die Kante wandert nach links, das Fenster wird breiter.

	DER FALLSTRICK. Erreicht die Grösse ihr Minimum, muss die Position
	stehen bleiben. Rechnet man x = pos.X - delta.X und begrenzt nur die
	Breite, wandert die linke Kante weiter, während die rechte festhängt —
	das Fenster kriecht, und beim Zurückziehen springt es.

	Deshalb wird die Position AUS DER BEGRENZTEN GRÖSSE abgeleitet:

		w = max(size.X - delta.X, minSize.X)
		x = pos.X + (size.X - w)

	Sobald w = minSize.X ist, ist auch x konstant. Der Ausdruck kann gar
	nicht mehr auseinanderlaufen, weil beide Werte aus derselben Zahl
	kommen.
--]]
function Resize.apply(position, size, dx, dy, delta, minSize)
	local x, y = position.X, position.Y
	local w, h = size.X, size.Y

	if dx == 1 then
		w = math.max(size.X + delta.X, minSize.X)

	elseif dx == -1 then
		w = math.max(size.X - delta.X, minSize.X)
		x = position.X + (size.X - w)
	end

	if dy == 1 then
		h = math.max(size.Y + delta.Y, minSize.Y)

	elseif dy == -1 then
		h = math.max(size.Y - delta.Y, minSize.Y)
		y = position.Y + (size.Y - h)
	end

	return Vector2.new(x, y), Vector2.new(w, h)
end

--------------------------------------------------------------------------
-- Griffzonen anlegen
--------------------------------------------------------------------------

--[[
	mount(window, cleanup, options?)

	options.minSize   Vector2, Standard Theme.size.windowMin
	options.parent    wohin die Griffe kommen, Standard window.frame

	Die Griffe sind durchsichtig und liegen als Ring AUSSERHALB des Fensters
	(siehe ZONES). Sie überdecken deshalb nichts im Fenster — der
	Schliessen-Button behält seine volle Fläche.

	Blockend registriert, damit ein Klick auf den Ring nicht an das
	durchfällt, was dahinter liegt: sonst würde man beim Anfassen der Kante
	das Fenster darunter oder den Desktop aktivieren.
--]]
function Resize.mount(window, cleanup, options)
	assert(window, "Resize.mount: window fehlt")
	assert(cleanup, "Resize.mount: cleanup ist Pflicht")

	local config = options or {}
	local minSize = config.minSize or Theme.size.windowMin
	local parent = config.parent or window.frame

	local startPosition = Vector2.zero
	local startSize = Vector2.zero

	local grips = {}
	local entries = {}
	local enabled = true

	for _, zone in ZONES do
		local grip = New("Frame", {
			Name = "Grip_" .. zone.name,
			Position = zone.position,
			Size = zone.size,
			BackgroundTransparency = 1,

			--[[
				Hoher ZIndex, obwohl die Griffe aussen liegen: der Ring soll
				über dem Schatten des eigenen Fensters liegen, und der wächst
				13 px nach aussen.
			--]]
			ZIndex = 50,
			Parent = parent,
		})

		table.insert(grips, grip)

		Interactive.bind(grip, {
			input = window.input,
			cleanup = cleanup,
			blocking = true,
			cursor = zone.cursor,

			--[[
				onActivate und nicht onDown, seit der Desktop den Fokus
				abgibt.

				Die Griffe ragen ÜBER den Fensterrahmen hinaus — an so einer
				Stelle ist der Rahmen selbst gar nicht getroffen, und die
				Trefferkette läuft vom Griff direkt zum Desktop durch. Der
				aktiviert sich dann und nimmt allen Fenstern den Fokus.

				blocking hilft dagegen nicht: es wirkt auf die ZUSTELLUNG
				(onDown geht nur an das oberste Element), nicht auf die
				AKTIVIERUNG, die ihren eigenen Durchlauf über die ganze Kette
				hat. Und weil dieser Durchlauf VOR onDown liegt, hätte ein
				focus() in onDown zwar am Ende recht behalten — aber erst,
				nachdem das Fenster einmal kurz blass geworden ist und die
				Taskleiste zweimal neu gezeichnet hat.

				Mit onActivate meldet sich der Griff als Erster in der Kette,
				und der Desktop kommt gar nicht dran.
			--]]
			onActivate = function()
				window:focus()
			end,

			--[[
				Startwerte beim Anfassen festhalten. Würde man in onDrag von
				der AKTUELLEN Grösse ausgehen, käme die Bewegung doppelt an:
				einmal als Delta, einmal als schon geänderte Grösse.
			--]]
			onDragStart = function()
				window:finishAnimation()
				window:setBusy("resize",true)
				startPosition = window:getPosition()
				startSize = window:getSize()
			end,

			onDrag = function(_, delta)
				--[[
					Doppelte Sicherung. Normalerweise sind die Griffe bei einem
					maximierten Fenster über setEnabled(false) abgeschaltet und
					dieser Zweig wird nie erreicht. Wer setEnabled nicht ruft,
					bekommt trotzdem kein verschobenes Vollbild.
				--]]
				if window:isMaximized() then
					return
				end

				--[[
					Mausdeltas kommen in echten Bildschirmpixeln, Offsets
					werden vom UIScale multipliziert. Ohne die Division läuft
					die Kante bei einem Faktor von 0.6 langsamer als der
					Cursor.
				--]]
				local scaled = delta / window.layers:scale()

				local newPosition, newSize = Resize.apply(
					startPosition, startSize,
					zone.dx, zone.dy,
					scaled, minSize
				)

				window:setPosition(newPosition)
				window:setSize(newSize)
			end,
			onDragEnd = function()window:setBusy("resize",false)end,
		})
	end

	--[[
		Die Handler-Tabellen einsammeln. Interactive.bind baut sie intern, der
		Router gibt sie über handlersOf() heraus — darüber lässt sich enabled
		später umschalten, ohne die Griffe neu zu bauen.
	--]]
	for _, grip in grips do
		table.insert(entries, window.input:handlersOf(grip))
	end

	local handle = {}
	handle.grips = grips

	--[[
		setEnabled(false) schaltet die Griffe ab, ohne sie zu entfernen.

		Zwei Gründe, warum das mehr ist als Visible = false:

		  · handlers.enabled = false macht den Eintrag im Router NICHT SOLIDE.
		    Damit gibt es kein Hover, keinen Zeigerwechsel und kein Ziehen —
		    genau das, was ein maximiertes Fenster braucht. Ein blosses
		    Visible = false würde den Frame unsichtbar machen, aber Roblox
		    nimmt unsichtbare Frames ohnehin aus dem Hit-Test; der Zeiger wäre
		    dann schon weg, aber nur als Nebenwirkung und nicht als Aussage.
		  · Die Griffe lassen Klicks jetzt DURCH. Bei einem Vollbild liegt der
		    Ring am Bildschirmrand, und dort soll ein Klick den Desktop oder
		    die Taskleiste erreichen, nicht im Nichts landen.

		refresh() ist Pflicht: der Router bestimmt Hover nur neu, wenn sich die
		Maus bewegt hat. Ohne den Aufruf bliebe der Größenpfeil stehen, bis man
		die Maus bewegt — obwohl das Fenster längst maximiert ist.

		Gebraucht wird das auch für Dialoge: die sind in Windows nicht
		grössenveränderbar, sollen aber sonst normale Fenster sein.
	--]]
	function handle:setEnabled(value)
		enabled = value

		for _, grip in grips do
			grip.Visible = value
		end

		for _, entry in entries do
			entry.enabled = value
		end

		window.input:refresh()
	end

	function handle:isEnabled()
		return enabled
	end

	return handle
end

return Resize
