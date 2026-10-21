--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	New — erzeugt GUI-Instanzen aus einer Property-Tabelle, mit sinnvollen
	Windows-Defaults pro Klasse.

		local frame = New("Frame", {
			Size = UDim2.fromOffset(300, 200),
			BackgroundColor3 = Theme.color.windowBg,
			Parent = parent,
		}, {
			New("TextLabel", { Text = "Hallo" }),
		})

	Ohne Defaults schreibt man BorderSizePixel = 0 in jedem Frame,
	BackgroundTransparency = 1 in jedem Label und ScaleType in jedem Bild.
	Zwanzig Module später hat man es an einer Stelle vergessen, und dann
	sucht man den grauen 1-px-Rand, den Roblox von Werk aus zeichnet.

	KEINE BUTTONS. TextButton und ImageButton werden abgelehnt, nicht nur
	nicht bevorzugt — siehe unten. Interaktion läuft über InputRouter auf
	normalen Frames.

	API
		New(className, props?, children?)
		New.corner(radius) · New.stroke(color, thickness?, transparency?)
		New.shadow(props?) · New.list(direction, padding?, align?)
		New.grid(cellSize, padding?) · New.padding(all)
		New.isButtonClass(className)
--]]

local Root = script.Parent.Parent

local Theme = require(Root.UI.Theme)

--------------------------------------------------------------------------
-- Schrift: Font oder FontFace
--------------------------------------------------------------------------

--[[
	Roblox hat zwei Wege, eine Schrift zu setzen, und sie schliessen sich
	aus: Enum.Font gehört zur Property "Font", ein Font-Objekt (Font.new)
	zur Property "FontFace".

	Theme entscheidet, welcher es ist. Hier steht die EINZIGE Zeile im
	Projekt, die daraus die passende Property macht — lädst du später Segoe
	UI als FontFace hoch und tauschst Theme.font aus, ändert sich hier
	nichts und in den Modulen auch nicht.
--]]
local FONT_PROPERTY = if typeof(Theme.font.ui) == "EnumItem" then "Font" else "FontFace"

--------------------------------------------------------------------------
-- Defaults pro Klasse
--------------------------------------------------------------------------

local DEFAULTS = {
	Frame = {
		BorderSizePixel = 0,
	},

	ScrollingFrame = {
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.color.scrollThumb,

		-- CanvasSize auf 0 plus AutomaticCanvasSize: die Liste wächst mit
		-- ihrem Inhalt, statt dass jedes Modul die Höhe selbst nachrechnet.
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	},

	TextLabel = {
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		TextSize = Theme.size.text,
		TextColor3 = Theme.color.text,

		-- Windows setzt Beschriftungen linksbündig. Zentriert ist die
		-- Ausnahme (Schaltflächen), nicht die Regel.
		TextXAlignment = Enum.TextXAlignment.Left,
	},

	--[[
		TextBox ist erlaubt, obwohl es interaktiv ist.

		Grund: Texteingabe lässt sich nicht sinnvoll nachbauen. Daran hängen
		Tastaturlayouts, IME, Zwischenablage, Textauswahl mit der Maus und
		die Bildschirmtastatur auf Mobilgeräten. Das ist eine andere
		Größenordnung als ein Klick auf einen Frame.

		ClearTextOnFocus = false, weil Robloxʼ Vorgabe true ist — das würde
		bei jedem Hineinklicken den Inhalt löschen. In Windows tut das kein
		Eingabefeld.
	--]]
	TextBox = {
		BorderSizePixel = 0,
		TextSize = Theme.size.text,
		TextColor3 = Theme.color.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Text = "",
	},

	ImageLabel = {
		BorderSizePixel = 0,
		BackgroundTransparency = 1,

		-- Fit statt Stretch: ein Symbol soll sein Seitenverhältnis behalten.
		-- Wer strecken will, sagt es ausdrücklich.
		ScaleType = Enum.ScaleType.Fit,
	},

	ScreenGui = {
		ResetOnSpawn = false,
		IgnoreGuiInset = true,

		--[[
			Sibling, nicht Global. Damit rendern Kinder immer über ihrem
			Elternteil und ZIndex zählt nur zwischen Geschwistern. Genau
			darauf beruht es, dass ein Fenster mit einem einzigen
			ZIndex-Wert auskommt und seine Titelleiste nicht auf ein
			fremdes Fenster rutschen kann.
		--]]
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	},
}

-- Schriftvorgabe eintragen, ohne die Property zweimal hinzuschreiben.
DEFAULTS.TextLabel[FONT_PROPERTY] = Theme.font.ui
DEFAULTS.TextBox[FONT_PROPERTY] = Theme.font.ui

--------------------------------------------------------------------------
-- Die Button-Sperre
--------------------------------------------------------------------------

--[[
	Warum werden GuiButtons abgelehnt statt nur gemieden?

	Weil eine halbe Regel keine ist. Sobald ein einziger TextButton im Baum
	steht, hat man zwei Eingabesysteme: den InputRouter und Robloxʼ eigenes.
	Die sehen sich nicht — und dann zeigt sich das an lauter kleinen
	Unstimmigkeiten, die einzeln jedesmal wie ein anderer Fehler aussehen:

	  · Ein GuiButton fängt Klicks ab, die der Router nie sieht.
	  · Roblox blendet über jedem Active-Element seinen eigenen Handzeiger
	    ein und überschreibt damit Mouse.Icon.
	  · Windows-Verhalten wie "drücken, wegziehen, loslassen = kein Klick"
	    macht MouseButton1Click nicht.
	  · Ein Modal kann einen GuiButton nicht sperren, weil die Sperre im
	    Router sitzt.

	Der Fehler unten nennt deshalb gleich die Alternative. Ein Frame plus
	InputRouter.register ist keine Notlösung, sondern der Weg.
--]]
local BUTTON_CLASSES = {
	TextButton = true,
	ImageButton = true,
}

--------------------------------------------------------------------------
-- Kern
--------------------------------------------------------------------------

--[[
	create(className, props?, children?)

	Parent wird IMMER zuletzt gesetzt. Das ist keine Kosmetik: solange eine
	Instanz elternlos ist, ist sie nicht im Renderbaum, und Roblox rechnet
	kein Layout. Hängt man sie zuerst ein, löst jede weitere
	Property-Änderung ein Re-Layout aus — bei einem Fenster mit dreissig
	Kindern also dreissig statt einem.

	Kinder werden vor dem Parent eingehängt, aus demselben Grund: der ganze
	Teilbaum kommt in einem Zug in den Renderbaum.
--]]
local function create(className, props, children)
	assert(type(className) == "string", "New: className muss ein String sein")

	if BUTTON_CLASSES[className] then
		error(
			("New: %s ist in diesem Projekt nicht erlaubt. Nimm einen Frame und "):format(className)
				.. "registriere ihn mit InputRouter.register — siehe Kommentar in UI/New.",
			2
		)
	end

	local instance = Instance.new(className)

	local defaults = DEFAULTS[className]
	if defaults then
		for key, value in defaults do
			instance[key] = value
		end
	end

	local parent = nil

	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end

	if children then
		for _, child in children do
			child.Parent = instance
		end
	end

	if parent then
		instance.Parent = parent
	end
	if instance:IsA("GuiObject") then instance.Active=false;instance.Selectable=false end

	return instance
end

--[[
	Aufrufbare Tabelle: New(...) erzeugt eine Instanz, New.corner(...) ist
	eine Kurzform. Beides über denselben Namen, damit im Modulkopf nur ein
	require steht.
--]]
local New = setmetatable({}, {
	__call = function(_, className, props, children)
		return create(className, props, children)
	end,
})

-- Für Tests und für Code, der prüfen will, bevor er erzeugt.
function New.isButtonClass(className)
	return BUTTON_CLASSES[className] == true
end

--------------------------------------------------------------------------
-- Kurzformen für die UI*-Objekte
--------------------------------------------------------------------------

function New.corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

--[[
	ApplyStrokeMode.Border, nicht Contextual: der Rahmen umschliesst die
	FLÄCHE des Objekts. Contextual folgt bei einem TextLabel den Buchstaben
	statt dem Rechteck — das ist ein anderer Effekt und fast nie der
	gemeinte.

	ACHTUNG, HÄUFIGES MISSVERSTÄNDNIS: KEINE der beiden Varianten zeichnet
	nach innen. Ein UIStroke liegt immer AUSSERHALB der Fläche, ein
	1-px-Rahmen um ein 200 px breites Fenster ergibt also sichtbare 202 px.
	Roblox kennt keinen einwärts gezeichneten Rand.

	Wo die Aussenmaße genau stimmen müssen, führt deshalb kein Weg an zwei
	ineinander liegenden Flächen vorbei — siehe UI/Button.
--]]
function New.stroke(color, thickness, transparency)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

--[[
	Schlagschatten über UIShadow.

	Gibt nil zurück, wenn die Roblox-Version die Klasse noch nicht kennt.
	Aufrufer müssen das Ergebnis also prüfen — dann fehlt nur der Schatten,
	und alles Übrige läuft weiter. Ein Fenster ohne Schatten ist hässlich,
	ein Fenster, das beim Öffnen einen Fehler wirft, ist kaputt.
--]]
function New.shadow(props)
	local ok, shadow = pcall(create, "UIShadow", props)
	if not ok then
		warn("WindowManager: UIShadow is unavailable: "..tostring(shadow))
		return nil
	end
	return shadow
end

--[[
	SortOrder.LayoutOrder statt Name: sonst sortiert Roblox alphabetisch,
	und "Fenster10" käme vor "Fenster2".
--]]
function New.list(direction, padding, align)
	return create("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, padding or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
end

-- cellSize und padding als Vector2, weil es Pixelmaße sind und keine
-- Anteile. UDim2.fromOffset macht daraus, was Roblox erwartet.
function New.grid(cellSize, padding)
	local pad = padding or Vector2.new(0, 0)

	return create("UIGridLayout", {
		CellSize = UDim2.fromOffset(cellSize.X, cellSize.Y),
		CellPadding = UDim2.fromOffset(pad.X, pad.Y),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function New.padding(all)
	local value = UDim.new(0, all)

	return create("UIPadding", {
		PaddingTop = value,
		PaddingBottom = value,
		PaddingLeft = value,
		PaddingRight = value,
	})
end

return New
