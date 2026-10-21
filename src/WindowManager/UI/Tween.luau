--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Tween — laufende Tweens verwalten, statt sie zu vergessen.

		local Root = script.Parent.Parent
		local Tween = require(Root.UI.Tween)

		local tweens = Tween.slots()

		tweens:to(frame, Theme.tween.fast, { Position = ziel })
		tweens:to(strich, Theme.tween.fast, { Size = breite })

		tweens:cancel(frame)
		tweens:cancelAll()

	EIN GESTARTETER TWEEN SCHREIBT WEITER, auch wenn man die Property
	zwischendurch von Hand setzt. Ohne Abbruch entsteht immer derselbe
	Fehler:

		Zeiger auf den Knopf     -> Tween nach Hell beginnt, 0.1 s
		innerhalb dieser Zeit weg -> onLeave setzt sofort zurück
		der Tween läuft weiter    -> und zieht die Fläche wieder auf Hell,
		                             wo sie dann bleibt

	Sichtbar vor allem an Flächen, über die man nur hinwegfährt — dort
	verweilt man selten länger als eine Zehntelsekunde.

	DIESE BUCHHALTUNG STAND VIERMAL IM PROJEKT, mit vier eigenen Tabellen
	(running, fading, moving, growing) und viermal derselben Begründung
	daneben. Sie ist keine Eigenschaft der Taskleiste und keine des
	Fensters — sie ist die Art, wie Roblox Tweens funktionieren.

	EIN SLOT IST EINE STELLE, DIE GENAU EINEN TWEEN HÄLT. Wer den Slot
	erneut bespielt, bricht den vorigen ab. Der Schlüssel ist normalerweise
	die Instanz selbst; wo eine Instanz MEHRERE unabhängige Tweens hat —
	Fläche und Rahmen etwa —, gibt man einen eigenen Schlüssel mit.

	API
		.slots() -> handle

		handle:to(instance, tweenInfo, props, key?) -> Tween?
		handle:cancel(key) · handle:cancelAll() · handle:count()

	Reine Rechnung, ohne Roblox-Objekte und damit testbar:
		.isInstant(tweenInfo) -> boolean
--]]

local TweenService = game:GetService("TweenService")

local Tween = {}

--[[
	isInstant(tweenInfo) -> boolean

	Bei Dauer 0 wird direkt gesetzt statt getweent. Ein Tween über 0
	Sekunden funktioniert in Roblox, kostet aber einen Frame Verzögerung und
	ein Tween-Objekt — bei einem Übergang, der sofort sein soll, ist beides
	falsch.

	nil zählt als sofort. Wer keine TweenInfo mitgibt, will keine Animation;
	das ist derselbe Fall wie animate = false an den mount-Funktionen.
--]]
function Tween.isInstant(tweenInfo)
	return tweenInfo == nil or tweenInfo.Time <= 0
end

--------------------------------------------------------------------------

function Tween.slots()
	local laufend = {}

	local handle = {}

	--[[
		cancel(key)

		Abbrechen lässt die Property da, wo sie GERADE steht — nicht am Ziel
		und nicht am Anfang. Genau das will man: der nächste Tween beginnt
		beim sichtbaren Wert, und es gibt keinen Sprung.
	--]]
	function handle:cancel(key)
		local tween = laufend[key]

		if not tween then
			return false
		end

		laufend[key] = nil
		tween:Cancel()
		return true
	end

	--[[
		to(instance, tweenInfo, props, key?) -> Tween oder nil

		nil kommt zurück, wenn sofort gesetzt wurde. Wer auf Completed
		hören will, muss also auf nil prüfen — dieselbe Regel wie bei
		Fade.tween.
	--]]
	function handle:to(instance, tweenInfo, props, key)
		local slot = key or instance

		self:cancel(slot)

		if Tween.isInstant(tweenInfo) then
			for name, value in props do
				instance[name] = value
			end
			return nil
		end

		local tween = TweenService:Create(instance, tweenInfo, props)
		laufend[slot] = tween

		--[[
			Den Eintrag nach dem Ende räumen, aber nur wenn es noch DERSELBE
			Tween ist. Sonst löscht ein spät eintreffendes Completed den
			Nachfolger, und der nächste Abbruch findet nichts mehr vor.
		--]]
		tween.Completed:Connect(function()
			if laufend[slot] == tween then
				laufend[slot] = nil
			end
		end)

		tween:Play()
		return tween
	end

	--[[
		Alles anhalten. Gehört ans Ende einer Lebensdauer: ein Tween auf eine
		zerstörte Instanz wirft zwar nicht, hält sie aber bis zum Ende am
		Leben.

		Als Funktion direkt an ein Cleanup übergebbar:

			cleanup:add(function() tweens:cancelAll() end)
	--]]
	function handle:cancelAll()
		for key, tween in laufend do
			laufend[key] = nil
			tween:Cancel()
		end
	end

	function handle:count()
		local n = 0
		for _ in laufend do
			n += 1
		end
		return n
	end

	return handle
end

return Tween
