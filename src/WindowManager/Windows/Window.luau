--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Window — ein Fenster: Rahmen, Zustände, Fokus-Optik.

	Erzeugt wird es nicht von Hand, sondern über den WindowManager:

		local fenster = wm:open({
			title = "Editor",
			size = Vector2.new(520, 340),
			icon = Theme.color.accent,
		})

		local inhalt = fenster:getContent()

	Titelleiste, Ziehen und Griffzonen liegen in eigenen Modulen (Titlebar,
	Drag, Resize). Dieses Modul hält nur den Rahmen, den Inhaltsbereich und
	die Zustände zusammen.

	BESITZ. Ein Fenster kann einem anderen gehören:

		local dialog = wm:open({ title = "Speichern?", owner = editor })

	Ein Fenster mit Besitzer bekommt keinen eigenen Knopf in der Taskleiste —
	der Besitzer vertritt es dort. Das ist eine Aussage über die Fenster und
	steht deshalb hier, nicht in der Leiste; die liest sie nur ab.

	API
		:focus() :close()
		:minimize() :unminimize()
		:maximize() :restore(targetPosition?) :toggleMaximize()
		:isMaximized() :isMinimized() :isVisible()
		:getPosition() :setPosition(v) :getSize() :setSize(v)
		:snapTo(position, size, zone) :getSnapZone()
		:getRestoreRect() :getCaptionZone()
		:getContent() :setTitle(s) :setZ(n) :setFocused(b)
		:getOwner() :showsInTaskbar()
		:looksActive() :refreshFocusLook()
		:setEnabled(bool, onBlocked?) :isEnabled()

		.closed        Event, feuert mit dem Fenster
		.stateChanged  Event, feuert mit "normal" | "minimized" | "maximized"
		.focusChanged  Event, feuert mit true oder false
		.keyPressed    Event, feuert mit (keyCode, down)

	AKTIV AUSSEHEN IST NICHT FOKUS HABEN. Ein Fenster mit offenem Dialog
	behält seine aktive Titelleiste — es verliert den Fokus, aber nicht die
	Aktivität. Nachmessbar mit tests/ModalVerhalten.ps1, Knopf 1.

	Deshalb liest die Optik looksActive() und nicht self.focused, und deshalb
	fragt auch die Taskleiste dasselbe: der Knopf und die Titelleiste, auf die
	er zeigt, sollen sich nicht widersprechen.

	Reine Rechnung, ohne Roblox-Objekte und damit testbar:
		.taskbarVisibility(hasOwner, override) -> boolean
		.activeLook(selfFocused, ownedActive) -> boolean
--]]

local Root = script.Parent.Parent

local Class = require(Root.Framework.Class)
local Cleanup = require(Root.Framework.Cleanup)
local Event = require(Root.Framework.Event)

local Theme = require(Root.UI.Theme)
local New = require(Root.UI.New)

local Titlebar = require(Root.Windows.Titlebar)
local Drag = require(Root.Windows.Drag)
local Resize = require(Root.Windows.Resize)
local Animate = require(Root.Windows.Animate)

local Window = Class.new("Window")

--[[
	Schatten, aus Windows abgemessen: 13 px Reichweite, Spitzendeckkraft rund
	11 %. Eingestellt ist 0.8 statt der gemessenen 0.889, weil UIShadow die
	Deckkraft über die 13 px flacher verteilt als der Windows-Compositor und
	derselbe Spitzenwert deshalb blasser wirkt.

	Das aktive Fenster wirft einen kräftigeren Schatten — daran erkennt man
	auf einen Blick, welches den Fokus hat.
--]]
local SHADOW = {
	activeBlur = 13,
	activeTransparency = 0.8,
	inactiveBlur = 8,
	inactiveTransparency = 0.87,
}

function Window:init(manager, config)
	self.manager = manager

	--[[
		Ebenen und Router kommen vom MANAGER. Ein Fenster ohne Manager gibt
		es nicht — er erzeugt es —, also ist das der kürzeste ehrliche Weg,
		und Titlebar, Drag und Resize holen sie sich wiederum vom Fenster.
	--]]
	self.layers = manager.layers
	self.input = manager.input
	self.id = config.id or 0
	self.appId = config.appId
	self.title = config.title or "Fenster"
	self.icon = config.icon

	self.resizable = config.resizable ~= false
	self.minSize = config.minSize or Theme.size.windowMin

	--[[
		DER BESITZER, und was daraus folgt.

		Ein Fenster mit Besitzer gehört einem anderen Fenster: ein Dialog, eine
		Eigenschaftenseite, ein Werkzeugfenster. In Windows heisst das "owned
		window", und daran hängen mehrere Regeln gleichzeitig — es liegt immer
		über seinem Besitzer, es schliesst mit ihm, und es bekommt KEINEN
		eigenen Knopf in der Taskleiste. Der Besitzer vertritt es dort.

		Deshalb steht der Besitzer hier und nicht in der Taskleiste. Er ist
		eine Aussage über die Fenster, keine über ihre Darstellung; die Leiste
		liest sie nur ab. Dass Windows niemals Taskbar kennt, bleibt damit
		unberührt.
	--]]
	self.owner = config.owner

	--[[
		showInTaskbar überschreibt die Ableitung, in beide Richtungen.

		Gebraucht für die zwei Fälle, die der Besitzer nicht trifft: ein
		besitzerloses Werkzeugfenster, das trotzdem nicht in die Leiste
		gehört, und ein Dokumentfenster mit Besitzer, das trotzdem einen
		eigenen Knopf bekommen soll.

		Ohne Angabe gilt die Windows-Regel: Besitzer ja, Knopf nein.
	--]]
	self.showInTaskbar = config.showInTaskbar

	--[[
		animate = false schaltet Öffnen- und Schliessanimation ab. Gedacht für
		Tests und für Fenster, die beim Hochfahren schon dastehen sollen — dort
		wäre eine Animation nur Verzögerung.
	--]]
	self.animate = config.animate ~= false

	self.state = "normal"
	self.focused = false

	--[[
		Abgeschaltet nimmt das Fenster keine Eingaben mehr an. Ein Dialog
		schaltet damit seinen Besitzer ab — siehe setEnabled.
	--]]
	self.enabled = true

	--[[
		Ohne diese gespeicherten Maße lässt sich ein maximiertes Fenster nicht
		wiederherstellen. Häufigster Fehler bei Fenster-Nachbauten.
	--]]
	self._restoreRect = nil
	self._stateBeforeMinimize = "normal"

	--[[
		An welchen Rand das Fenster angedockt ist, oder nil. Kein eigener
		Zustand — siehe snapTo.
	--]]
	self._snapZone = nil
	self._closing = false

	self.cleanup = Cleanup.new()
	self.closed = Event.new()
	self.stateChanged = Event.new()

	--[[
		Feuert bei jedem Fokuswechsel mit true oder false.

		Der Fensterinhalt braucht das: Schaltflächen eines inaktiven Dialogs
		zeichnet Windows blasser. Ohne dieses Ereignis müsste MessageBox am
		Manager lauschen und selbst prüfen, ob es sein Fenster war.
	--]]
	self.focusChanged = Event.new()

	--[[
		Feuert mit (keyCode, down), solange das Fenster den Fokus hat.

		Der Fensterinhalt hängt sich hier ein, statt selbst beim InputRouter
		zu lauschen — sonst müsste jeder Inhalt prüfen, ob sein Fenster
		überhaupt aktiv ist.
	--]]
	self.keyPressed = Event.new()
	self.gestureChanged = Event.new()
	self._busy = {}

	self:_build(config)
end

function Window:_build(config)
	local size = config.size or Vector2.new(720, 480)
	local position = config.position or Vector2.zero

	--[[
		Eckig, ohne UICorner: Windows 10 hat durchgehend eckige Fenster.
		Abgerundete Ecken kamen erst mit Windows 11.
	--]]
	self.frame = self.cleanup:add(New("Frame", {
		Name = "Window_" .. tostring(self.id),
		Position = UDim2.fromOffset(math.round(position.X), math.round(position.Y)),
		Size = UDim2.fromOffset(math.round(size.X), math.round(size.Y)),
		BackgroundColor3 = Theme.color.windowBg,
		Parent = config.parent,
	}, {
		New.stroke(Theme.color.windowBorderInactive, Theme.size.windowBorder),
	}))

	self._stroke = self.frame:FindFirstChildOfClass("UIStroke")

	-- Kann nil sein, wenn die Engine UIShadow nicht kennt. Dann fehlt nur
	-- der Schatten, sonst ändert sich nichts.
	self._shadow = New.shadow({
		Name = "Schatten",
		Color = Theme.color.black,
		BlurRadius = UDim.new(0, SHADOW.activeBlur),
		Transparency = SHADOW.activeTransparency,
		Parent = self.frame,
	})

	--[[
		Der Fensterrahmen wird blockend registriert. Ohne das fällt ein Klick
		auf eine leere Stelle im Fenster bis zum Desktop durch und hebt dort
		die Auswahl auf — ein Fehler, den man erst bemerkt, wenn es einen
		Desktop mit Auswahl gibt.
	--]]
	--[[
		onActivate statt onDown.

		onDown geht nur an das oberste getroffene Element. Ein Klick auf einen
		Knopf im Fenster käme hier also nie an, und das Fenster bliebe im
		Hintergrund — man müsste erst irgendwo ins Leere klicken und dann
		nochmal auf den Knopf.

		onActivate läuft dagegen die Trefferkette hoch, bis es jemanden
		findet, der sich zuständig fühlt. Damit tut ein Klick auf ein
		Hintergrundfenster beides auf einmal: nach vorn holen UND bedienen,
		genau wie in Windows.

		blocking bleibt trotzdem nötig, sonst fällt ein Klick auf eine leere
		Stelle im Fenster bis zum Desktop durch.
	--]]
	self.input:register(self.frame, {
		blocking = true,
		onActivate = function()
			self:focus()
		end,

		--[[
			Tasten gehen an das FENSTER, nicht an einzelne Bedienelemente.

			So macht es Windows: die Tastatur gehört dem aktiven Fenster, und
			das verteilt sie weiter. Ein Dialog kann damit die Pfeiltasten
			auswerten, ohne dass jede Schaltfläche einzeln einen Fokus
			verwalten muss — und ohne dass zwei Elemente sich um die Tastatur
			streiten.
		--]]
		onKey = function(keyCode, down)
			self.keyPressed:fire(keyCode, down)
		end,
	}, self.cleanup)

	self.titlebar = Titlebar.mount(self, {
		titleInset = config.titleInset,
		showMinimize = config.showMinimize,
		showMaximize = config.showMaximize,
		showClose = config.showClose,
		captionSize = config.captionSize,
	})

	--[[
		Der Inhalt beginnt unter der Titelleiste. ClipsDescendants, damit eine
		App nicht versehentlich über den Rahmen hinausmalt.
	--]]
	self.content = New("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(0, Theme.size.titlebarHeight),
		Size = UDim2.new(1, 0, 1, -Theme.size.titlebarHeight),
		BackgroundColor3 = Theme.color.windowBg,
		ClipsDescendants = true,
		ZIndex = 1,
		Parent = self.frame,
	})

	Drag.attach(self, self.titlebar.frame)

	if self.resizable then
		self.resize = Resize.mount(self, self.cleanup, { minSize = self.minSize })
	end

	self:setFocused(false)

	--[[
		Das UIScale für die Animation. Es entsteht ganz zum Schluss, damit es
		nicht in einer der Grössenrechnungen darüber auftaucht.
	--]]
	Animate.prepare(self)
end

--[[
	Vom WindowManager gerufen, sobald das Fenster steht und seine Position
	hat. NICHT in _build, weil die Kaskade die Position erst danach setzt —
	die Animation muss aber wissen, wohin sie laufen soll.
--]]
function Window:playOpenAnimation()
	Animate.open(self)
end

function Window:setBusy(kind, value)
	self._busy[kind] = if value then true else nil
	local busy = next(self._busy) ~= nil
	if self.frame:GetAttribute("HTMLViewportResizing") ~= busy then
		self.frame:SetAttribute("HTMLViewportResizing", busy)
		self.gestureChanged:fire(busy)
	end
end

function Window:finishAnimation()
	Animate.finishOpen(self)
end

--------------------------------------------------------------------------
-- Geometrie, alles in UI-Einheiten
--------------------------------------------------------------------------

function Window:getPosition()
	local p = self.frame.Position
	return Vector2.new(p.X.Offset, p.Y.Offset)
end

function Window:setPosition(position)
	self.frame.Position = UDim2.fromOffset(math.round(position.X), math.round(position.Y))
end

function Window:getSize()
	local s = self.frame.Size
	return Vector2.new(s.X.Offset, s.Y.Offset)
end

--[[
	Begrenzt auf das Mindestmaß. Resize klemmt selbst schon, aber nicht jeder
	Aufrufer geht über Resize — und ein Fenster kleiner als seine Titelleiste
	ist nicht mehr bedienbar.
--]]
function Window:setSize(size)
	self.frame.Size = UDim2.fromOffset(
		math.round(math.max(size.X, self.minSize.X)),
		math.round(math.max(size.Y, self.minSize.Y))
	)
end

function Window:getRestoreRect()
	return self._restoreRect
end

function Window:getCaptionZone()
	return self.titlebar.captionZone
end

function Window:getContent()
	return self.content
end

--------------------------------------------------------------------------
-- Zustände
--------------------------------------------------------------------------

function Window:isMaximized()
	return self.state == "maximized"
end

function Window:isMinimized()
	return self.state == "minimized"
end

function Window:isVisible()
	return self.state ~= "minimized"
end

--------------------------------------------------------------------------
-- Besitz
--------------------------------------------------------------------------

--[[
	taskbarVisibility(hasOwner, override) -> boolean

	Ob ein Fenster einen eigenen Knopf in der Taskleiste bekommt. Rein
	gerechnet, damit die Regel ohne Instanzen prüfbar ist — und weil sie
	genau die Stelle ist, an der man sich vertut.

	override ist absichtlich DREIWERTIG. nil heisst "nicht gesagt", und nur
	dann greift die Ableitung aus dem Besitz. Mit einem Vorbelegen auf true
	oder false wäre "nicht gesagt" von "ausdrücklich so gewollt" nicht mehr
	zu unterscheiden, und ein Dialog bekäme wieder seinen Knopf.
--]]
function Window.taskbarVisibility(hasOwner, override)
	if override ~= nil then
		return override
	end

	return not hasOwner
end

function Window:showsInTaskbar()
	return Window.taskbarVisibility(self.owner ~= nil, self.showInTaskbar)
end

function Window:getOwner()
	return self.owner
end

--------------------------------------------------------------------------
-- Abschalten
--------------------------------------------------------------------------

--[[
	setEnabled(value, onBlocked?)

	Ein abgeschaltetes Fenster nimmt keine Eingaben mehr an. Es bleibt
	sichtbar, bleibt aktiv eingefärbt und liegt weiter da, wo es lag — man
	kann nur nichts damit tun.

	DAS IST EnableWindow AUS WIN32, und es ist der Weg, auf dem ein Dialog
	sein Elternfenster sperrt. Windows nennt das anwendungsmodal: gesperrt
	wird genau dieses Fenster, andere bleiben bedienbar.

	Ein Modal wäre das andere Extrem — es sperrt alles ausserhalb seiner
	selbst. Das braucht man für einen Dialog ohne Besitzer, sonst nicht.

	onBlocked wird gerufen, wenn jemand hineinklickt. Der Dialog hängt sich
	dort ein, um zu blinken und den Klang zu spielen.

	KLICKS WERDEN GESCHLUCKT, nicht weitergereicht. Sonst klickte man durch
	das Fenster hindurch auf den Desktop dahinter — und der gäbe brav den
	Fokus ab, obwohl ein Dialog auf eine Antwort wartet.
--]]
function Window:setEnabled(value, onBlocked)
	if self.enabled == value then
		return
	end

	self.enabled = value

	if value then
		self.input:clearDisabled(self.frame)
	else
		self.input:setDisabled(self.frame, onBlocked)
	end
end

function Window:isEnabled()
	return self.enabled
end

--[[
	activeLook(selfFocused, ownedActive) -> boolean

	Ob ein Fenster AKTIV AUSSIEHT. Das ist nicht dasselbe wie "hat den Fokus".

	In Windows behält ein Fenster seine aktive Titelleiste, solange einer
	seiner Dialoge vorn ist — es verliert den Fokus, aber nicht die
	Aktivität. Nachmessbar mit tests/ModalVerhalten.ps1, Knopf 1: das
	Elternfenster ist gesperrt und bleibt trotzdem blau.

	Der Grund liegt auf der Hand, sobald man es einmal andersherum sieht: der
	Dialog GEHÖRT dem Fenster. Würde das Fenster blass, sähe es aus, als sei
	man woanders hingewechselt — dabei ist man mitten in einer Rückfrage
	desselben Programms.

	Als reine Funktion, weil genau das die Aussage ist, die stimmen muss.
--]]
function Window.activeLook(selfFocused, ownedActive)
	return selfFocused or ownedActive
end

--[[
	Sieht dieses Fenster gerade aktiv aus?

	REKURSIV ÜBER DIE DIALOGE, denn die Kette kann mehrere Stufen haben: ein
	Dialog auf einem Dialog auf einem Fenster. Hat der oberste den Fokus,
	sehen alle darunter aktiv aus — sie gehören ja alle zusammen.

	SCHUTZ GEGEN RINGE über die Tiefe. Zeigen zwei Fenster gegenseitig
	aufeinander, liefe die Rekursion ewig. Ein Ring ist ein Fehler beim
	Aufbau, aber er soll das Bild nicht einfrieren.
--]]
function Window:looksActive(depth)
	if self.focused then
		return true
	end

	local level = depth or 0

	if level >= 32 or not self.manager then
		return false
	end

	for _, owned in self.manager:listOwned(self) do
		if owned:looksActive(level + 1) then
			return true
		end
	end

	return false
end

--[[
	Die Fokus-Optik neu auftragen, ohne dass sich der Fokus geändert hat.

	Gebraucht vom Manager: wenn ein Dialog den Fokus bekommt, ändert sich am
	Besitzer nichts — ausser wie er aussehen soll. Ohne diesen Aufruf würde er
	es nie erfahren.
--]]
function Window:refreshFocusLook()
	if self._flashing then
		return
	end

	self:_applyFocusLook(self:looksActive())
	self:_applyShadow()
end

function Window:_setState(state)
	if self.state == state then
		return
	end

	self.state = state
	self:_applyShadow()
	self.stateChanged:fire(state)
end

function Window:maximize()
	if not self.resizable or self._closing then return end
	if self.state == "maximized" then
		return
	end

	if self.state == "normal" then
		self._restoreRect = { position = self:getPosition(), size = self:getSize() }
	end

	self._snapZone = nil

	local origin, area = self.manager:getWorkArea()

	self.frame.Visible = true
	self.frame.Position = UDim2.fromOffset(math.round(origin.X), math.round(origin.Y))
	self.frame.Size = UDim2.fromOffset(math.round(area.X), math.round(area.Y))

	-- Ein maximiertes Fenster hat keinen Rahmen: es schliesst bündig mit dem
	-- Bildschirmrand ab, und ein Schatten hätte nichts, worauf er fiele.
	if self._stroke then
		self._stroke.Enabled = false
	end

	self:_setState("maximized")
	self.titlebar:updateMaximizeGlyph(true)

	--[[
		Griffe abschalten. Ein Vollbild lässt sich in Windows nicht in der
		Grösse ändern, und der Zeiger zeigt an den Rändern auch keine
		Größenpfeile mehr — setEnabled erledigt beides in einem Zug, weil es
		den Router-Eintrag nicht mehr solide macht.
	--]]
	if self.resize then
		self.resize:setEnabled(false)
	end
end

--[[
	restore(targetPosition?)

	Ohne Argument geht das Fenster dahin zurück, wo es vor dem Maximieren
	stand. MIT Argument landet es direkt an der übergebenen Stelle.

	Das Argument ist nicht Bequemlichkeit, sondern behebt ein Flackern: beim
	Ziehen einer maximierten Titelleiste soll das Fenster unter dem Cursor
	auftauchen, nicht erst an seinem alten Platz. Schreibt man zuerst die
	gespeicherte Position und korrigiert sie danach, blitzt für einen Frame
	die alte Stelle auf.

	Deshalb wird Position hier genau EINMAL geschrieben.
--]]
function Window:restore(targetPosition)
	if self.state == "normal" and not self._snapZone then
		return
	end

	local saved = self._restoreRect

	if saved then
		self.frame.Size = UDim2.fromOffset(saved.size.X, saved.size.Y)

		local target = targetPosition or saved.position
		self.frame.Position = UDim2.fromOffset(math.round(target.X), math.round(target.Y))
	end

	self.frame.Visible = true

	if self._stroke then
		self._stroke.Enabled = true
	end

	self._snapZone = nil

	self:_setState("normal")
	self.titlebar:updateMaximizeGlyph(false)

	if self.resize then
		self.resize:setEnabled(true)
	end
end

--[[
	snapTo(position, size, zone)

	Andocken an eine Bildschirmhälfte oder ein Viertel — Aero Snap.

	KEIN eigener Zustand. Ein angedocktes Fenster ist in Windows "normal":
	es lässt sich in der Grösse ändern, das Maximieren-Symbol bleibt
	unverändert, und Doppelklick maximiert es weiterhin. Der einzige
	Unterschied zu einem gewöhnlichen Fenster ist, dass es sich seine alten
	Maße gemerkt hat.

	Deshalb wird _restoreRect nur beim ERSTEN Andocken geschrieben. Zieht man
	ein angedocktes Fenster von links nach rechts, soll es weiterhin auf die
	Grösse zurückkommen, die es vor dem ganzen Vorgang hatte — nicht auf die
	halbe Bildschirmbreite von eben.
--]]
function Window:snapTo(position, size, zone)
	if self.state == "normal" and not self._snapZone then
		self._restoreRect = { position = self:getPosition(), size = self:getSize() }
	end

	if self.state == "maximized" then
		self:restore(position)
	end

	self:setPosition(position)
	self:setSize(size)

	self._snapZone = zone
	self.stateChanged:fire(self.state)
end

-- Ist das Fenster angedockt, und wenn ja wohin?
function Window:getSnapZone()
	return self._snapZone
end

function Window:toggleMaximize()
	if self.state == "maximized" then
		self:restore()
	else
		self:maximize()
	end
end

function Window:minimize()
	if self.state == "minimized" then
		return
	end

	if self.state == "normal" then
		self._restoreRect = { position = self:getPosition(), size = self:getSize() }
	end

	self._stateBeforeMinimize = self.state
	self.frame.Visible = false
	self:_setState("minimized")

	-- Der Manager sucht sich das nächste sichtbare Fenster
	self.manager:focusNextVisible(self)
end

-- Aus dem minimierten Zustand zurück in den, der vorher galt.
function Window:unminimize()
	if self.state ~= "minimized" then
		return
	end

	self.frame.Visible = true

	if self._stateBeforeMinimize == "maximized" then
		-- state zurücksetzen, damit maximize() nicht früh aussteigt
		self.state = "normal"
		self:maximize()
	else
		self:_setState("normal")
	end

	self.manager:focus(self)
end

--------------------------------------------------------------------------
-- Fokus, Z, Titel
--------------------------------------------------------------------------

function Window:focus()
	self.manager:focus(self)
end

--[[
	_applyShadow(aktiv?)

	Ohne Argument liest er looksActive() — und das ist der Normalfall. Der
	Schatten gehört zur Fokus-Optik und muss mit ihr gehen: ein Fenster mit
	offenem Dialog hat den Fokus nicht, sieht aber aktiv aus, und ein flacher
	Schatten widerspräche der eigenen Titelleiste.

	MIT Argument wird der Zustand vorgegeben. Das braucht genau eine Stelle,
	das Blinken — dort wird die Optik mehrfach umgeschaltet, während sich am
	echten Fokus nichts ändert.

	Diese vier Zeilen standen vorher zweimal, hier und in _applyFocusLook.
	Zwei Kopien derselben Rechnung laufen irgendwann auseinander.
--]]
function Window:_applyShadow(aktiv)
	local shadow = self._shadow
	if not shadow then
		return
	end

	-- Maximiert kein Schatten: das Fenster schliesst bündig ab.
	if self.state == "maximized" or self.fullscreen then
		shadow.Enabled = false
		return
	end

	local an = if aktiv == nil then self:looksActive() else aktiv

	shadow.Enabled = true
	shadow.BlurRadius = UDim.new(0, if an then SHADOW.activeBlur else SHADOW.inactiveBlur)
	shadow.Transparency = if an
		then SHADOW.activeTransparency
		else SHADOW.inactiveTransparency
end

--[[
	Nur die OPTIK des Fokus, ohne self.focused zu ändern.

	Getrennt wegen des Blinkens: dort wird die Optik mehrfach umgeschaltet,
	während das Fenster die ganze Zeit über denselben Fokuszustand hat. Würde
	flash() über setFocused laufen, feuerte bei jedem Blinken focusChanged —
	und der Dialog würde seine Schaltflächen viermal umfärben.
--]]
function Window:_applyFocusLook(value)
	if self._stroke then
		self._stroke.Color = if value
			then Theme.color.windowBorder
			else Theme.color.windowBorderInactive
	end

	self.titlebar:setFocused(value)

	--[[
		Der Schatten geht MIT, auch beim Blinken. Deshalb bekommt er hier den
		vorgegebenen Wert und liest nicht selbst nach.
	--]]
	self:_applyShadow(value)
end

function Window:setFocused(value)
	self.focused = value

	--[[
		Aufgetragen wird der ABGELEITETE Zustand, nicht das Argument. Verliert
		ein Fenster den Fokus an seinen eigenen Dialog, bleibt es aktiv
		aussehen — value ist dann false, looksActive() aber true.

		Gemeldet wird trotzdem value: focusChanged ist eine Aussage über den
		Fokus, nicht über die Optik. Wer das Aussehen braucht, fragt
		looksActive().
	--]]
	self:_applyFocusLook(self:looksActive())
	self:_applyShadow()
	self.focusChanged:fire(value)
end

--[[
	Blinken — die Antwort eines modalen Dialogs auf einen Klick daneben.

	Windows lässt dabei ALLES blinken, was den Fokus anzeigt: Titel, Symbol,
	die Caption-Buttons und den Schatten. Genau deshalb geht es hier über
	_applyFocusLook und nicht über einzelne Eigenschaften — das Blinken ist
	nichts anderes als ein schnelles Umschalten desselben Zustands.

	ACHT DURCHGÄNGE, abgezählt an Windows. Zwei wären eine Andeutung; acht
	sind lang genug, dass man sie auch bemerkt, wenn man beim Klicken
	woandershin gesehen hat.

	EIN ZWEITER KLICK SETZT DEN ZÄHLER ZURÜCK, statt ignoriert zu werden.
	Bei acht Durchgängen läuft das Blinken knapp zwei Sekunden — ein Riegel
	würde in dieser Zeit jeden weiteren Klick verschlucken, und wer zweimal
	daneben klickt, bekäme beim zweiten Mal gar keine Antwort mehr. Deshalb
	läuft nur EIN Thread, der seine Restzahl aus _flashRemaining liest.
--]]
--[[
	Acht Durchgänge in EINER Sekunde. Die Dauer ist die eigentliche Vorgabe,
	die Zahl der Durchgänge die zweite — deshalb steht hier beides und der
	Abstand wird daraus gerechnet, statt eine dritte Zahl zu pflegen, die
	still auseinanderlaufen kann.

	Ein Durchgang besteht aus zwei Halbschritten (aus, an), also:

		1 s / (8 * 2) = 62.5 ms je Halbschritt

	Das sind bei 60 Hz knapp vier Bilder — kurz genug, dass es als Blinken
	wahrgenommen wird und nicht als Umschalten.
--]]
local FLASH_DURATION = 1
local FLASH_COUNT = 8
local FLASH_INTERVAL = FLASH_DURATION / (FLASH_COUNT * 2)

function Window:flash(times)
	if self._closing then return end
	local count = times or FLASH_COUNT

	if self._flashing then
		self._flashRemaining = count
		return
	end

	self._flashing = true
	self._flashRemaining = count

	self._flashTask = task.spawn(function()
		while self._flashRemaining > 0 and not self._closing do
			self._flashRemaining -= 1

			self:_applyFocusLook(false)
			task.wait(FLASH_INTERVAL)
			if self._closing then return end
			self:_applyFocusLook(true)
			task.wait(FLASH_INTERVAL)
		end

		--[[
			Zum Schluss zurück auf den ECHTEN Zustand. Ein Fenster, das
			während des Blinkens den Fokus verloren hat, darf nicht aktiv
			stehenbleiben.
		--]]
		self._flashing = false
		self._flashTask = nil

		self:_applyFocusLook(self:looksActive())
		self:_applyShadow()
	end)
end

function Window:setZ(index)
	if self.frame.ZIndex ~= index then self.frame.ZIndex = index end
end

function Window:setTitle(title)
	self.title = title
	self.titlebar:setTitle(title)
end

--------------------------------------------------------------------------

--[[
	Schliessen.

	Aus der Liste des Managers fliegt das Fenster sofort — der Fokus soll
	nicht erst später weiterwandern. Der Riegel _closing verhindert, dass ein
	closed-Handler close() erneut auslöst.
--]]
function Window:close(immediate)
	if self._closing then
		return
	end
	self._closing = true
	self.frame:SetAttribute("WindowClosing",true)
	local pressed=self.input.Pressed
	if pressed then
		local current=pressed.Entry.Gui
		while current do if current==self.frame then self.input:Cancel();break end;current=current.Parent end
	end
	if immediate then self.animate = false end
	Animate.finishOpen(self)
	if self._flashTask then pcall(task.cancel, self._flashTask);self._flashTask=nil end
	self._flashing=false
	table.clear(self._busy)
	self.frame:SetAttribute("HTMLViewportResizing",false)
	self.gestureChanged:fire(false)

	--[[
		Eine Sperre, die auf diesem Fenster liegt, muss weg, bevor der Rahmen
		verschwindet. Der InputRouter räumt sie beim Abmelden zwar auch, aber
		hier ist der Zustand noch beschreibbar — und self.enabled soll nicht
		auf false stehenbleiben.
	--]]
	if not self.enabled then
		self:setEnabled(true)
	end

	self.closed:fire(self)
	self.manager:close(self)

	--[[
		Erst die Animation, dann das Aufräumen. cleanup:clean() zerstört den
		Frame — liefe es sofort, gäbe es nichts mehr zu animieren.

		Der Manager kennt das Fenster ab hier nicht mehr, der Fokus ist also
		schon weitergewandert. Was noch zu sehen ist, ist reine Optik.
	--]]
	if not self._disposed then Animate.close(self,function()self:disposeNow()end)end
end

function Window:disposeNow()
	if self._disposed then return end;self._disposed=true
	Animate.cancel(self)
	self.cleanup:clean()
	self.closed:destroy();self.stateChanged:destroy();self.focusChanged:destroy();self.keyPressed:destroy();self.gestureChanged:destroy()
end

return Window
