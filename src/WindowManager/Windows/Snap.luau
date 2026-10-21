--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Snap — Aero Snap: Fenster an den Bildschirmrand ziehen und andocken.

		local zone = Snap.zoneAt(mouse, origin, area)

		Snap.showPreview(zone, origin, area, zIndex)
		Snap.hidePreview()
		Snap.apply(window, zone)

	DIE ZONEN, wie Windows sie kennt:

		links / rechts    halber Bildschirm
		oben              maximieren
		die vier Ecken    ein Viertel

	DIE VORSCHAU IST NUR EIN RAHMEN: die Mitte bleibt leer, aussen ein
	fester dunkler Saum (#394044), innen ein aufgehellter 1-px-Ring.

	Gemessen auf einem Hintergrund #4A5459 ergaben sich #535D61 für die
	Fläche und #6D7579 für den Rand. Rechnet man zurück, sind das Weiss mit
	5 % und mit 19.3 % Deckkraft — bei allen drei Kanälen, was den Zufall
	ausschliesst.

	Das ist keine Kosmetik, sondern der Unterschied zwischen richtig und
	fast richtig: feste Grautöne stimmen genau auf DIESEM Hintergrund. Auf
	einem hellen Desktop wäre die Vorschau plötzlich dunkler als der Grund,
	statt heller. Deshalb steht hier Weiss mit Transparenz und keine
	abgemessene Farbe.

	API
		.zoneAt(mouse, origin, area, threshold?) -> string?
		.rectFor(zone, origin, area) -> position, size
		.previewRectFor(zone, origin, area) -> position, size
		.growFromFor(zone, position, size) -> position, size
		.showPreview(layers, zone, origin, area, zIndex?) · .hidePreview()
		.apply(window, zone) -> boolean
		.zones() -> { string }
--]]

local Root = script.Parent.Parent

local Theme = require(Root.UI.Theme)
local Tween = require(Root.UI.Tween)
local New = require(Root.UI.New)

local Snap = {}

--------------------------------------------------------------------------
-- Rechnung
--------------------------------------------------------------------------

--[[
	Wie nah der Cursor an den Rand muss. Theme.size.snapZone, also 20 px.

	Bewusst am CURSOR gemessen und nicht am Fensterrand: man zieht ein
	Fenster an die Kante, indem man den Zeiger dorthin führt — wo die
	Fensterecke dabei landet, hängt vom Griffpunkt ab und wäre unberechenbar.
--]]
local function thresholdOf(value)
	return value or Theme.size.snapZone
end

--[[
	Wie hoch die Eckzonen sind.

	Windows nimmt hier keinen schmalen Streifen, sonst träfe man die Viertel
	nie. Ein Sechstel der Höhe ist gross genug zum Treffen und klein genug,
	dass die Hälfte in der Mitte noch dominiert.
--]]
local CORNER_RATIO = 1 / 6

--[[
	zoneAt(mouse, origin, area, threshold?) -> string?

	Die Zone unter dem Cursor, oder nil.

	Die Reihenfolge der Prüfungen ist der ganze Inhalt: ERST waagerecht,
	dann senkrecht, und die Ecke gewinnt über die Hälfte. Prüfte man oben
	zuerst, würde die obere linke Ecke zu "maximieren" statt zum Viertel —
	ein Fehler, den man erst bemerkt, wenn man Viertel wirklich benutzt.
--]]
function Snap.zoneAt(mouse, origin, area, threshold)
	local edge = thresholdOf(threshold)

	local left = origin.X + edge
	local right = origin.X + area.X - edge
	local top = origin.Y + edge

	local cornerHeight = area.Y * CORNER_RATIO
	local nearTop = mouse.Y <= origin.Y + cornerHeight
	local nearBottom = mouse.Y >= origin.Y + area.Y - cornerHeight

	if mouse.X <= left then
		if nearTop then
			return "topLeft"
		end
		if nearBottom then
			return "bottomLeft"
		end
		return "left"
	end

	if mouse.X >= right then
		if nearTop then
			return "topRight"
		end
		if nearBottom then
			return "bottomRight"
		end
		return "right"
	end

	--[[
		Oben in der Mitte heisst maximieren. Nur hier zählt die schmale
		Schwelle und nicht die Eckhöhe — sonst schnappte jedes Fenster,
		dessen Titelleiste man im oberen Sechstel führt.
	--]]
	if mouse.Y <= top then
		return "maximize"
	end

	return nil
end

--[[
	rectFor(zone, origin, area) -> position, size

	Was die Zone belegt. Die Hälften teilen ungerade Breiten so, dass links
	das grössere Stück bekommt und rechts der Rest — zusammen ergeben sie
	wieder genau die Arbeitsfläche. Rechnete man beide als area.X / 2, bliebe
	bei einer ungeraden Breite ein Pixel Spalt in der Mitte.
--]]
function Snap.rectFor(zone, origin, area)
	local halfX = math.floor(area.X / 2)
	local restX = area.X - halfX
	local halfY = math.floor(area.Y / 2)
	local restY = area.Y - halfY

	if zone == "maximize" then
		return origin, area
	end

	if zone == "left" then
		return origin, Vector2.new(halfX, area.Y)
	end

	if zone == "right" then
		return Vector2.new(origin.X + halfX, origin.Y), Vector2.new(restX, area.Y)
	end

	if zone == "topLeft" then
		return origin, Vector2.new(halfX, halfY)
	end

	if zone == "topRight" then
		return Vector2.new(origin.X + halfX, origin.Y), Vector2.new(restX, halfY)
	end

	if zone == "bottomLeft" then
		return Vector2.new(origin.X, origin.Y + halfY), Vector2.new(halfX, restY)
	end

	if zone == "bottomRight" then
		return Vector2.new(origin.X + halfX, origin.Y + halfY), Vector2.new(restX, restY)
	end

	return nil, nil
end

function Snap.zones()
	return { "left", "right", "maximize", "topLeft", "topRight", "bottomLeft", "bottomRight" }
end

--------------------------------------------------------------------------
-- Die Vorschau
--------------------------------------------------------------------------

--[[
	Die Vorschau steht auf ALLEN VIER Seiten 8 px ab.

	NUR die Vorschau — das Fenster selbst dockt bündig an. Der Abstand ist
	keine Aussage über die künftige Grösse, sondern macht die Vorschau als
	schwebende Ankündigung erkennbar. Ohne ihn klebt sie am Rand und sieht
	aus wie ein Fenster, das schon da ist.

	Ringsum und nicht nur oben und unten: der Saum soll die Vorschau
	vollständig umschliessen. Läge sie an einer Kante an, wäre der dunkle
	Strich dort abgeschnitten, und die Form sähe an drei Seiten schwebend aus
	und an einer angeklebt.
--]]
local PREVIEW_MARGIN = 8

--[[
	previewRectFor(zone, origin, area) -> position, size

	Die Vorschau zur Zone, samt Abstand. Getrennt von rectFor, weil das
	Fenster den Abstand NICHT bekommen darf — verwechselte man beides, hätte
	jedes angedockte Fenster oben und unten 8 px Hintergrund stehen.
--]]
function Snap.previewRectFor(zone, origin, area)
	local position, size = Snap.rectFor(zone, origin, area)

	if not position then
		return nil, nil
	end

	local margin = Vector2.new(PREVIEW_MARGIN, PREVIEW_MARGIN)

	return position + margin, size - margin * 2
end

--[[
	DIE VORSCHAU IST HOHL — und das ist nicht durch Transparenz zu haben.

	Der erste Aufbau war "aussen ein Rechteck in der Randfarbe, innen eine
	Fläche darüber". Setzt man die innere Fläche auf durchsichtig, kommt das
	äussere Rechteck darunter zum Vorschein: die ganze Vorschau ist plötzlich
	getönt. Transparenz LÖSCHT nicht, sie lässt durch.

	Deshalb hier ein anderer Aufbau: ein durchsichtiger Frame, 1 px kleiner
	als das Ziel, mit einem UIStroke NACH AUSSEN. Der Stroke belegt genau den
	1-px-Ring am Rand — und die Mitte bleibt leer, weil dort nie etwas
	gezeichnet wird.

	Der Innenrand ist Weiss zu 19.3 % (gemessen #6D7579 auf #4A5459). Roblox
	rechnet Transparenz andersherum, deshalb 1 - Deckkraft.
--]]
local BORDER_TRANSPARENCY = 0.807
local BORDER_WIDTH = 1

--[[
	Zusätzlich ein UIStroke NACH AUSSEN, in #394044.

	Hier ist der Stroke genau richtig, während er beim Knopf falsch wäre: die
	Vorschau hat kein Maß einzuhalten. Sie zeigt an, WO das Fenster landet,
	und ein Pixel Saum darum herum ändert daran nichts — beim Knopf dagegen
	hätte derselbe Saum die Gruppenbreite gesprengt.

	Die Farbe ist DUNKLER als der gemessene Hintergrund (#4A5459) und deshalb
	bewusst fest und nicht aus Weiss abgeleitet. Sie ist der abgrenzende
	Saum, der die aufgehellte Fläche vom Desktop trennt; leitete man sie aus
	Weiss ab, verschwände sie auf einem dunklen Desktop genau dann, wenn man
	sie am nötigsten braucht.
--]]
local OUTLINE_COLOR = Color3.fromRGB(57, 64, 68)   -- #394044
local OUTLINE_WIDTH = 1

--[[
	Auf wie viel die Vorschau schrumpft, bevor sie sich aufzieht. Die halbe
	Grösse ist deutlich genug, dass man die Bewegung als Wachsen liest, und
	nicht so klein, dass die Vorschau aus dem Nichts heranfliegt.
--]]
local GROW_SCALE = 0.5

--[[
	growFromFor(zone, position, size) -> position, size

	Woher die Vorschau kommt: ein verkleinertes Rechteck DERSELBEN Form,
	angelegt an die Kante, die man gewählt hat.

	Der Anker ist der Punkt. Wüchse das Rechteck aus seiner Mitte, sähe die
	Bewegung bei allen sieben Zonen gleich aus. So wächst es sichtbar VON DER
	KANTE her, an die man gezogen hat — links aus dem linken Rand, oben aus
	der Oberkante, in der Ecke aus der Ecke.

	Die Form bleibt erhalten (dieselbe Skalierung auf beiden Achsen), damit
	das kleine Rechteck schon aussieht wie das, was gleich dasteht.
--]]
function Snap.growFromFor(zone, position, size)
	local small = Vector2.new(math.round(size.X * GROW_SCALE), math.round(size.Y * GROW_SCALE))

	--[[
		Je Achse: 0 heisst an der Anfangskante kleben, 0.5 mittig, 1 an der
		Endkante. Als Tabelle statt als sieben if-Zweige — die Zonennamen
		sagen ihre Ausrichtung ohnehin schon.
	--]]
	local ANCHOR = {
		left        = Vector2.new(0,   0.5),
		right       = Vector2.new(1,   0.5),
		maximize    = Vector2.new(0.5, 0),
		topLeft     = Vector2.new(0,   0),
		topRight    = Vector2.new(1,   0),
		bottomLeft  = Vector2.new(0,   1),
		bottomRight = Vector2.new(1,   1),
	}

	local anchor = ANCHOR[zone]
	if not anchor then
		return position, size
	end

	return Vector2.new(
		math.round(position.X + (size.X - small.X) * anchor.X),
		math.round(position.Y + (size.Y - small.Y) * anchor.Y)
	), small
end

--[[
	KEIN SCHATTEN.

	Er war da — 28 px, deutlich weiter als die 13 px eines Fensters. Er musste
	wieder weg, als die Mitte leer wurde: UIShadow wirft den Schatten für die
	FORM des Frames, und die Form ist das volle Rechteck, ganz gleich ob der
	Hintergrund durchsichtig ist. Der weiche Verlauf lag damit auch unter der
	leeren Mitte und dunkelte sie ab — genau das, was eine hohle Vorschau
	nicht tun soll.

	Ein ringförmiger Schatten wäre nur mit vier einzeln beschatteten
	Kantenframes zu haben. Das ist es nicht wert: der dunkle Saum #394044
	leistet dieselbe Abgrenzung mit einer Instanz statt mit acht.
--]]

-- Each manager owns its own reusable preview and tween slots.
local previews=setmetatable({},{__mode="k"})
local function ensurePreview(layers)
    local state=previews[layers]
    if state then return state end
    local frame=New("Frame",{Name="SnapPreview",BackgroundTransparency=1,Visible=false,Parent=layers:get("windows")})
    local outline=New.stroke(OUTLINE_COLOR,OUTLINE_WIDTH,1);outline.Parent=frame
    local border=New("Frame",{Name="InnerBorder",Position=UDim2.fromOffset(BORDER_WIDTH,BORDER_WIDTH),Size=UDim2.new(1,-2*BORDER_WIDTH,1,-2*BORDER_WIDTH),BackgroundTransparency=1,Parent=frame})
    local stroke=New.stroke(Theme.color.white,BORDER_WIDTH,1);stroke.Parent=border
    state={Frame=frame,Outline=outline,Stroke=stroke,Tweens=Tween.slots()}
    previews[layers]=state
    return state
end
function Snap.showPreview(layers,zone,origin,area,zIndex)
    if not zone then Snap.hidePreview(layers);return end
    local position,size=Snap.previewRectFor(zone,origin,area)
    if not position then Snap.hidePreview(layers);return end
    local state=ensurePreview(layers);local frame=state.Frame
    if state.Zone==zone and frame.Visible then return end
    if state.FadeConnection then state.FadeConnection:Disconnect();state.FadeConnection=nil end
    local visible=frame.Visible;state.Zone=zone;frame.Visible=true;frame.ZIndex=math.max(1,zIndex or 1)
    local info=Theme.tween.fast
    if not visible then
        local at,small=Snap.growFromFor(zone,position,size)
        frame.Position=UDim2.fromOffset(at.X,at.Y);frame.Size=UDim2.fromOffset(small.X,small.Y);info=Theme.tween.snapGrow
    end
    state.Tweens:to(frame,info,{Position=UDim2.fromOffset(position.X,position.Y),Size=UDim2.fromOffset(size.X,size.Y)})
    state.Tweens:to(state.Stroke,Theme.tween.fast,{Transparency=BORDER_TRANSPARENCY})
    state.Tweens:to(state.Outline,Theme.tween.fast,{Transparency=0})
end
function Snap.hidePreview(layers)
    local state=previews[layers];if not state then return end
    -- Repeated pointer moves outside snap zones must not restart a hide.
    if not state.Zone and (not state.Frame.Visible or state.FadeConnection)then return end
    state.Zone=nil
    if state.FadeConnection then state.FadeConnection:Disconnect();state.FadeConnection=nil end
    state.Tweens:to(state.Outline,Theme.tween.fast,{Transparency=1})
    local tween=state.Tweens:to(state.Stroke,Theme.tween.fast,{Transparency=1})
    if tween then
        local connection
        connection=tween.Completed:Connect(function()
            if state.FadeConnection~=connection then return end
            connection:Disconnect();state.FadeConnection=nil
            if not state.Zone then state.Frame.Visible=false end
        end)
        state.FadeConnection=connection
    else state.Frame.Visible=false end
end
function Snap.destroyPreview(layers)
    local state=previews[layers];if not state then return end
    previews[layers]=nil
    if state.FadeConnection then state.FadeConnection:Disconnect()end
    state.Tweens:cancelAll();state.Frame:Destroy()
end
function Snap.previewZone(layers)local state=previews[layers];return state and state.Zone end
function Snap.apply(window,zone)
    if not zone or not window.resizable then return false end
    if zone=="maximize"then window:maximize();return true end
    local origin,area=window.manager:getWorkArea();local position,size=Snap.rectFor(zone,origin,area)
    if not position then return false end
    window:snapTo(position,size,zone);return true
end
return Snap
