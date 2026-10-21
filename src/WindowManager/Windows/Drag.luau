--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Drag — ein Fenster an einer Fläche ziehen, inklusive Drag-to-Restore.

		Drag.attach(window, window.titlebar.frame)

	Damit lässt sich jede Fläche zur Ziehfläche machen. Im Normalfall ist das
	die Titelleiste; eine App mit eigener Kopfzeile (Browser-Modus) meldet
	später die leere Stelle neben ihren Tabs an — in Windows heisst das der
	Ziehbereich der Titelleiste.

	AERO SNAP steckt hier mit drin: onDrag fragt Windows/Snap nach der Zone
	unter dem Cursor und zeigt die Vorschau, onDragEnd dockt an. Die Rechnung
	dazu liegt in Snap, nicht hier — dieses Modul weiss nur, wann es fragen
	muss.

	API
		.attach(window, frame) -> unregister
		.grabPoint(ratio, width, captionZone, titlebarHeight) -> Vector2
		.clampToArea(target, windowSize, area, titlebarHeight, edge) -> Vector2
--]]

local Root = script.Parent.Parent

local Theme = require(Root.UI.Theme)
local Interactive = require(Root.UI.Interactive)
local Snap = require(Root.Windows.Snap)

local Drag = {}

-- Abstand, den der Griffpunkt von den Fensterrändern hält
local EDGE_MARGIN = 12

-- So viel vom Fenster muss im Bild bleiben, sonst kommt man nicht mehr heran
local VISIBLE_EDGE = 48

--------------------------------------------------------------------------
-- Rechnung
--------------------------------------------------------------------------

--[[
	Griffpunkt im wiederhergestellten Fenster.

	Waagerecht anteilig zu der Stelle, an der die maximierte Leiste angefasst
	wurde; senkrecht in der Mitte der Titelleiste.

	DER RECHTE ANSCHLAG IST DER PUNKT. Fasst man die maximierte Leiste weit
	rechts an, läge der Cursor im kleinen Fenster mitten auf den
	Caption-Buttons. Man würde scheinbar am Schliessen-Button ziehen und beim
	Loslassen das Fenster zumachen.

	max() schützt schmale Fenster: dort wäre die rechte Grenze sonst kleiner
	als die linke, und math.clamp würde mit vertauschten Grenzen fehlschlagen.
--]]
function Drag.grabPoint(ratio, width, captionZone, titlebarHeight)
	local zone = captionZone or (3 * Theme.size.captionWidth)
	local barHeight = titlebarHeight or Theme.size.titlebarHeight

	local minX = EDGE_MARGIN
	local maxX = math.max(width - zone - EDGE_MARGIN, minX)

	return Vector2.new(
		math.clamp(math.clamp(ratio, 0, 1) * width, minX, maxX),
		barHeight / 2
	)
end

--[[
	Zielposition auf den Arbeitsbereich begrenzen.

	Die Titelleiste darf nicht komplett aus dem Bild wandern, sonst kommt man
	an das Fenster nicht mehr heran. Nach links und rechts bleiben edge Pixel
	sichtbar, nach oben gar nichts — in Windows kann man ein Fenster nicht
	über die Oberkante hinausschieben, nach unten schon.
--]]
function Drag.clampToArea(target, windowSize, area, titlebarHeight, edge)
	local visible = edge or VISIBLE_EDGE
	local barHeight = titlebarHeight or Theme.size.titlebarHeight

	return Vector2.new(
		math.clamp(target.X, -(windowSize.X - visible), area.X - visible),
		math.clamp(target.Y, 0, area.Y - barHeight)
	)
end

--------------------------------------------------------------------------
-- Anbinden
--------------------------------------------------------------------------

--[[
	attach(window, frame)

	window muss liefern: getPosition, setPosition, getSize, isMaximized,
	restore(targetPosition?), toggleMaximize, focus, manager, cleanup.

	grab ist der Griffpunkt relativ zur linken oberen Fensterecke. Ohne ihn
	springt das Fenster beim Anfassen mit seiner Ecke unter den Cursor.

	Alle Positionen laufen über Layers.toLocal. Direkt pos/scale zu rechnen
	wäre falsch: der Layer-Root beginnt am echten Bildschirmrand,
	Mauskoordinaten dagegen unter der Roblox-Topbar.
--]]
function Drag.attach(window, frame)
	assert(window, "Drag.attach: window fehlt")
	assert(frame, "Drag.attach: frame fehlt")
	assert(window.cleanup, "Drag.attach: window.cleanup fehlt")

	local grab = Vector2.zero

	--[[
		Die Zone, über der der Cursor beim letzten Bild lag. Gemerkt, damit
		onDragEnd sie nicht neu ausrechnen muss — beim Loslassen kann sich der
		Zeiger schon wieder bewegt haben, und angedockt werden soll das, was
		die Vorschau gezeigt hat.
	--]]
	local zone = nil

	return Interactive.bind(frame, {
		input = window.input,
		cleanup = window.cleanup,
		blocking = true,
		cursor = Theme.cursor.default,

		onDown = function()
			window:focus()
		end,

		onDoubleClick = function()
			window:toggleMaximize()
		end,

		onDragStart = function(_, startPos)
			window:finishAnimation()
			window:setBusy("drag",true)
			local mouse = window.layers:toLocal(startPos)
			zone = nil

			--[[
				Ein ANGEDOCKTES Fenster verhält sich beim Anfassen wie ein
				maximiertes: es bekommt seine alte Grösse zurück und legt sich
				proportional unter den Cursor. Ohne das zöge man eine halbe
				Bildschirmbreite mit sich herum und müsste sie hinterher von
				Hand zurechtziehen.

				Es fällt hier durch in denselben Zweig wie das maximierte
				Fenster — dieselbe Rechnung, derselbe Grund.
			--]]
			if not window:isMaximized() and not window:getSnapZone() then
				grab = mouse - window:getPosition()
				return
			end

			--[[
				Drag-to-Restore: das maximierte Fenster wird wiederhergestellt
				und proportional unter den Cursor gelegt.

				Gerechnet wird VOR dem Wiederherstellen — die künftige Breite
				steht in restoreRect, dafür muss das Fenster nicht erst
				schrumpfen. Dadurch bekommt restore() die Zielposition mit und
				schreibt Position genau einmal.

				Ohne das flackert für einen Frame die alte Stelle auf: erst
				schreibt restore() die gespeicherte Position, dann korrigiert
				onDrag sie auf den Cursor.
			--]]
			local saved = window:getRestoreRect()
			local width = if saved then saved.size.X else window:getSize().X

			local ratio = (mouse.X - window:getPosition().X)
				/ math.max(window:getSize().X, 1)

			grab = Drag.grabPoint(ratio, width, window:getCaptionZone(), Theme.size.titlebarHeight)

			if window:isMaximized() then
				window:restore(mouse - grab)
			else
				--[[
					Angedockt: die gemerkten Maße zurückholen. restore() geht
					hier nicht, das ist für den maximierten Zustand — ein
					angedocktes Fenster steht auf "normal" und käme dort gar
					nicht erst durch.
				--]]
				window:setSize(saved and saved.size or window:getSize())
				window:setPosition(mouse - grab)
				window._snapZone = nil
			end
		end,

		onDrag = function(pos)
			local mouse = window.layers:toLocal(pos)
			local origin, area = window.manager:getWorkArea()

			window:setPosition(
				Drag.clampToArea(mouse - grab, window:getSize(), area)
			)

			--[[
				Die Vorschau folgt dem CURSOR, nicht dem Fenster. Wo die
				Fensterecke landet, hängt vom Griffpunkt ab — man dockt aber
				an, indem man den Zeiger an die Kante führt.

				Der ZIndex liegt eins unter dem gezogenen Fenster: die
				Vorschau soll über den anderen Fenstern liegen, aber nicht
				über dem, das man gerade in der Hand hat.
			--]]
			zone = if window.resizable then Snap.zoneAt(mouse, origin, area) else nil
			Snap.showPreview(window.layers, zone, origin, area, window.frame.ZIndex - 1)
		end,

		onDragEnd = function(_,_,cancelled)
			Snap.hidePreview(window.layers)

			if zone and not cancelled then
				Snap.apply(window, zone)
				zone = nil
			end
			zone=nil
			window:setBusy("drag",false)
		end,
	})
end

return Drag
