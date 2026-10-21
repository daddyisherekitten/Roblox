--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Fade — blendet einen ganzen Teilbaum aus und wieder ein.

		local snapshot = Fade.capture(window.frame)

		Fade.set(snapshot, 1)                        -- sofort unsichtbar
		Fade.tween(snapshot, 0, Theme.tween.fast)    -- einblenden

	alpha: 0 = Ursprungszustand, 1 = unsichtbar.

	WARUM EIN SNAPSHOT UND KEIN DIREKTES SETZEN?

	Zwischenwerte werden gegen den GESPEICHERTEN Ursprungswert interpoliert.
	Ein Element, das schon halbdurchsichtig war, bleibt bei alpha = 0 auch
	halbdurchsichtig — ohne den Snapshot würde es beim Einblenden auf 0
	gezogen und wäre plötzlich deckend.

	Betroffen ist hier zum Beispiel der Schatten (Transparency 0.8) und ein
	unfokussierter Fenstertitel (TextTransparency 0.45).

	WARUM ÜBERHAUPT EIN MODUL?

	Jede GUI-Klasse hat ihre eigene Transparenz-Property: ein TextLabel
	gleich zwei, ein UIStroke eine andere, eine CanvasGroup wieder eine. Ohne
	einen gemeinsamen Ort landet diese Fallunterscheidung in jedem Modul
	erneut.

	API
		.capture(root) -> snapshot
		.set(snapshot, alpha)
		.tween(snapshot, alpha, tweenInfo) -> Tween?
		.cancel(snapshot)

	Reine Rechnung, ohne Roblox-Objekte und damit testbar:
		.targetFor(original, alpha)
		.propsFor(className)
--]]

local TweenService = game:GetService("TweenService")

local Fade = {}

--[[
	Welche Properties je Klasse die Sichtbarkeit steuern.

	Die Reihenfolge geht von der SPEZIELLSTEN zur allgemeinsten Klasse, weil
	IsA() auch auf Oberklassen anspricht: ein TextLabel ist auch ein
	GuiObject, und ohne diese Reihenfolge bliebe seine Schrift stehen,
	während nur der Hintergrund verblasst.
--]]
local RULES = {
	{ className = "CanvasGroup",   props = { "GroupTransparency" } },
	{ className = "UIStroke",      props = { "Transparency" } },
	{ className = "UIShadow",      props = { "Transparency" } },
	{ className = "TextBox",       props = { "TextTransparency", "BackgroundTransparency" } },
	{ className = "TextLabel",     props = { "TextTransparency", "BackgroundTransparency" } },
	{ className = "ImageLabel",    props = { "ImageTransparency", "BackgroundTransparency" } },
	{ className = "ViewportFrame", props = { "ImageTransparency", "BackgroundTransparency" } },
	{ className = "VideoFrame",    props = { "VideoTransparency", "BackgroundTransparency" } },
	{ className = "GuiObject",     props = { "BackgroundTransparency" } },
}

--[[
	Die Regeln nach Klassennamen, ohne Instanz. Für Tests und für Aufrufer,
	die wissen wollen, was Fade anfassen würde.
--]]
function Fade.propsFor(className)
	for _, rule in RULES do
		if rule.className == className then
			return rule.props
		end
	end
	return nil
end

local function rulesFor(instance)
	for _, rule in RULES do
		if instance:IsA(rule.className) then
			return rule.props
		end
	end
	return nil
end

--[[
	Zielwert für einen Ursprungswert bei gegebenem alpha.

	Interpoliert zwischen dem Ursprungswert und 1 (unsichtbar):

		alpha 0  ->  original
		alpha 1  ->  1
		alpha .5 ->  genau dazwischen

	Ein Schatten mit Transparency 0.8 geht damit auf 0.9 bei alpha 0.5 und
	nicht auf 0.5 — er wird schwächer, nicht stärker.
--]]
function Fade.targetFor(original, alpha)
	return original + (1 - original) * alpha
end

--------------------------------------------------------------------------

--[[
	Zustand eines Teilbaums festhalten.

	Das Ergebnis ist die Grundlage für alle weiteren Aufrufe — ohne den
	gespeicherten Ursprungswert wüsste man nach dem Ausblenden nicht mehr,
	worauf man zurückblenden soll.
--]]
function Fade.capture(root)
	assert(root, "Fade.capture: root fehlt")

	local snapshot = { entries = {}, tweens = {} }

	local function add(instance)
		local props = rulesFor(instance)
		if not props then
			return
		end

		local values = {}
		for _, prop in props do
			values[prop] = instance[prop]
		end

		table.insert(snapshot.entries, { instance = instance, props = values })
	end

	add(root)

	for _, descendant in root:GetDescendants() do
		add(descendant)
	end

	return snapshot
end

--[[
	Laufende Tweens anhalten.

	Dieselbe Falle wie in Interactive: ein gestarteter Tween schreibt weiter
	in die Property, auch wenn man sie danach direkt setzt. Ohne Cancel
	blendet ein Fenster, das während seiner Öffnungsanimation geschlossen
	wird, wieder ein.
--]]
function Fade.cancel(snapshot)
	for _, tween in snapshot.tweens do
		tween:Cancel()
	end

	snapshot.tweens = {}
end

-- Sofort setzen, ohne Animation.
function Fade.set(snapshot, alpha)
	Fade.cancel(snapshot)

	for _, entry in snapshot.entries do
		for prop, original in entry.props do
			entry.instance[prop] = Fade.targetFor(original, alpha)
		end
	end
end

--[[
	Animiert auf den Zielwert.

	Gibt den Tween des ersten Elements zurück, damit der Aufrufer sich an
	.Completed hängen kann — alle laufen mit derselben TweenInfo und enden
	deshalb gleichzeitig.
--]]
function Fade.tween(snapshot, alpha, info)
	Fade.cancel(snapshot)

	local first = nil

	for _, entry in snapshot.entries do
		local goal = {}

		for prop, original in entry.props do
			goal[prop] = Fade.targetFor(original, alpha)
		end

		local tween = TweenService:Create(entry.instance, info, goal)
		table.insert(snapshot.tweens, tween)
		tween:Play()

		if not first then
			first = tween
		end
	end

	return first
end

return Fade
