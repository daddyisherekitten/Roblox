--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	WindowManager — hält die Fensterliste, den Fokus und die Z-Reihenfolge.

		local wm = WindowManager.new()

		local fenster = wm:open({
			title = "Editor",
			size = Vector2.new(520, 340),
		})

	Kennt kein GUI: er baut nichts und zeichnet nichts. Der Rahmen entsteht in
	Windows/Window, die Ebene kommt von UI/Layers. Dadurch lässt sich die
	Fensterlogik von der Darstellung getrennt anschauen — und die Taskleiste
	wird später eine Ansicht darauf, keine zweite Buchhaltung.

	ZWEI REIHENFOLGEN. list() gibt die Z-Reihenfolge und ändert sich bei jedem
	Klick; listOpened() gibt die Öffnungsreihenfolge und bleibt stehen. Die
	Taskleiste braucht die zweite, sonst springen ihre Knöpfe.

	API
		.new(config)   config.layers und config.input sind Pflicht
		:open(config) -> Window · :close(window) · :closeAll()
		:focus(window) · :focusNextVisible(exclude?) · :getFocused()
		:clearFocus() -> vorheriges Fenster oder nil
		:list() · :count() · :findByAppId(id) · :findAllByAppId(id)
		:listOpened() · :listTaskbar() · :listOwned(window) · :listMinimized()
		:getWorkArea() -> origin, size
		:pushModal(entry) · :popModal(frame) · :modalDepth()
		:destroy()

		.windowOpened / .windowClosed / .focusChanged   (Event)

	Reine Rechnung, ohne Roblox-Objekte und damit testbar:
		.cascadePosition(index, windowSize, area) -> Vector2
--]]

local Root = script.Parent.Parent

local Class = require(Root.Framework.Class)
local Cleanup = require(Root.Framework.Cleanup)
local Event = require(Root.Framework.Event)

local Theme = require(Root.UI.Theme)
local Window = require(Root.Windows.Window)
local Geometry = require(Root.Geometry)

local WindowManager = Class.new("WindowManager")

--[[
	Fensterplatzierung, an echtem Windows bei 1920x1080 und 100 % gemessen.

	Das erste Fenster sitzt mittig im Arbeitsbereich, um +8/+7 versetzt. Jedes
	weitere kommt exakt 22 px diagonal nach rechts unten dazu. Läuft eines
	unten oder rechts aus dem Bild, beginnt die Reihe wieder bei 0.
--]]
local CASCADE_STEP = 22
local CASCADE_OFFSET = Vector2.new(8, 7)

--[[
	cascadePosition(index, windowSize, area) -> Vector2

	index ist die laufende Nummer in der Kaskade, beginnend bei 0.

	Rein gerechnet und deshalb prüfbar: die Rücksetzbedingung ist der
	interessante Teil, und sie ist leicht falsch. Passt das Fenster mit dem
	Versatz nicht mehr ganz auf die Fläche, fängt die Reihe wieder vorn an —
	sonst wandern Fenster bei jedem Öffnen weiter aus dem Bild.
--]]
function WindowManager.cascadePosition(index, windowSize, area)
	local baseX = math.round((area.X - windowSize.X) / 2) + CASCADE_OFFSET.X
	local baseY = math.round((area.Y - windowSize.Y) / 2) + CASCADE_OFFSET.Y

	local step = index * CASCADE_STEP

	if baseX + step + windowSize.X > area.X or baseY + step + windowSize.Y > area.Y then
		step = 0
	end

	--[[
		max() gegen negative Positionen: ein Fenster, das schon ohne Versatz
		grösser ist als der Arbeitsbereich, würde sonst links oberhalb des
		Bildschirms beginnen.
	--]]
	return Vector2.new(
		math.max(baseX + step, 0),
		math.max(baseY + step, 0)
	)
end

--------------------------------------------------------------------------

--[[
	Die Besitzer eines Fensters neu zeichnen lassen, die Kette hinauf.

	NÖTIG, WEIL SICH BEI IHNEN NICHTS ÄNDERT ausser dem Aussehen. Bekommt ein
	Dialog den Fokus, ruft niemand setFocused auf seinem Besitzer — dessen
	Fokus hat sich ja nicht geändert. Nur wie er aussehen SOLL, hat sich
	geändert: er bleibt aktiv, obwohl er nicht mehr fokussiert ist.

	Die ganze Kette, weil sie mehrere Stufen haben kann: ein Dialog auf einem
	Dialog auf einem Fenster. Bekommt der oberste den Fokus, sehen alle
	darunter aktiv aus.

	Die Grenze schützt gegen Ringe — zwei Fenster, die sich gegenseitig als
	Besitzer führen, sind ein Fehler beim Aufbau, sollen aber nicht das Bild
	einfrieren.
--]]
local function refreshOwnerChain(window)
	local current = window and window.owner
	local guard = 0

	while current and guard < 32 do
		current:refreshFocusLook()
		current = current.owner
		guard += 1
	end
end

function WindowManager:init(config)
	local cfg = config or {}

	--[[
		EBENEN UND ROUTER KOMMEN VON AUSSEN. Der Manager legt sie nicht an —
		sie gehören dem OS und überleben ihn. Ohne sie ist er nicht
		betriebsfähig, deshalb ein assert und kein stiller Rückfall auf eine
		Standard-Instanz: der wäre genau der Fehler, den die Umstellung
		beseitigen soll.
	--]]
	self.layers = assert(cfg.layers, "WindowManager: layers fehlt")
	self.input = assert(cfg.input, "WindowManager: input fehlt")

	self.layerName = cfg.layer or "windows"
	self.taskbarHeight = cfg.taskbarHeight or 0
	self.defaultAnimate = cfg.animate ~= false

	--[[
		ZWEI LISTEN ÜBER DIESELBEN FENSTER, und sie dürfen nicht eine sein.

		_windows ist die Z-REIHENFOLGE. focus() hängt das Fenster ans Ende,
		_reorder() macht daraus den ZIndex. Diese Liste ändert sich bei jedem
		Klick.

		_opened ist die ÖFFNUNGSREIHENFOLGE und ändert sich nie, ausser wenn
		ein Fenster dazukommt oder verschwindet. Daraus baut die Taskleiste
		ihre Knöpfe.

		MIT NUR EINER LISTE fällt der Fehler erst spät auf, weil die Leiste nur
		bei windowOpened und windowClosed neu baut: öffne A, B, C, klicke A
		an, öffne D — und die Knöpfe stehen als B C A D da. Sie springen,
		sobald ein Fenster dazukommt. Eine Taskleiste behält ihre Reihenfolge,
		egal was der Fokus tut.
	--]]
	self._windows = {}
	self._opened = {}

	self._focused = nil
	self._nextId = 1
	self._cascade = 0
	self._cleanup = Cleanup.new()

	self.windowOpened = Event.new()
	self.windowClosed = Event.new()
	self.focusChanged = Event.new()

	--[[
		DER STAPEL DER MODALEN DIALOGE, und er gehört hierhin.

		Er lag vorher als `local modalStack = {}` auf Modulebene in
		Dialogs/MessageBox — also globaler Zustand in einem Dialogmodul. Zwei
		Folgen davon:

		  · Zwei WindowManager teilten sich einen Stapel. Ein Dialog im einen
		    sperrte Fenster im anderen.
		  · Der Stapel überlebte InputRouter.shutdown(). Ein Selbsttest, der
		    einen Dialog offen liess, vererbte ihn dem nächsten Abschnitt.

		Der Manager führt ohnehin die Fenster; welche davon gerade gesperrt
		sind, ist eine Aussage über dieselbe Menge.
	--]]
	self._modals = {}
end

--[[
	Nutzbarer Bereich in UI-Einheiten: Ebene minus Taskleiste.

	Maximierte Fenster füllen genau diesen Bereich, nicht den ganzen
	Bildschirm — sonst verschwindet die Taskleiste darunter. Solange
	taskbarHeight 0 ist (es gibt noch keine Leiste), ist es der ganze Schirm.
--]]
function WindowManager:getWorkArea()
	local size = self.layers:sizeOf(self.layerName)
	return Vector2.zero, Vector2.new(size.X, size.Y - self.taskbarHeight)
end

--[[
	open(config) -> Window

	config: title, icon (Farbe), size, position, minSize, appId, resizable,
	showMinimize, showMaximize, showClose

	Ohne position wird kaskadiert.
--]]
function WindowManager:open(config)
	local cfg = table.clone(config or {})
	if cfg.animate == nil then cfg.animate = self.defaultAnimate end

	cfg.id = self._nextId
	self._nextId += 1

	cfg.size = cfg.size or Vector2.new(720, 480)
	cfg.parent = self.layers:get(self.layerName)

	if not cfg.position then
		local _, area = self:getWorkArea()
		cfg.position = WindowManager.cascadePosition(self._cascade, cfg.size, area)
		self._cascade += 1
	end

	local _,area=self:getWorkArea()
	cfg.position,cfg.size=Geometry.fit(cfg.position,cfg.size,cfg.minSize or Theme.size.windowMin,area)
	local window = Window.new(self, cfg)
	table.insert(self._windows, window)
	table.insert(self._opened, window)

	self:focus(window)

	--[[
		Die Öffnungsanimation läuft erst hier, nach focus() — dort wird der
		Z-Index gesetzt, und die Animation soll auf dem fertig einsortierten
		Fenster laufen, nicht auf einem, das gleich noch umgehängt wird.
	--]]
	window:playOpenAnimation()

	self.windowOpened:fire(window)

	return window
end

function WindowManager:close(window)
	local index = table.find(self._windows, window)
	if not index then
		return
	end

	--[[
		ZUERST DIE BESESSENEN FENSTER, und das ist kein Beiwerk.

		Ein Fenster mit Besitzer hat keinen eigenen Knopf in der Taskleiste.
		Bliebe es nach dem Schliessen des Besitzers stehen, wäre es über die
		Leiste nicht mehr erreichbar — und über den Besitzer auch nicht, den
		gibt es ja nicht mehr. Ein sichtbares Fenster, an das niemand mehr
		herankommt.

		Windows macht es genauso: der Besitzer nimmt seine Dialoge mit.

		window:close() ruft hier wieder herein, deshalb die Kopie: die Liste
		verändert sich währenddessen.
	--]]
	for _, owned in self:listOwned(window) do
		owned:close(window.animate == false)
	end

	index = table.find(self._windows, window)
	if not index then
		return
	end

	table.remove(self._windows, index)

	local openedIndex = table.find(self._opened, window)
	if openedIndex then
		table.remove(self._opened, openedIndex)
	end

	if self._focused == window then
		self:focusNextVisible()
	end

	--[[
		Der Besitzer muss auch dann neu gezeichnet werden, wenn der Fokus
		woanders hingeht.

		Schliesst man einen Dialog, während ein DRITTES Fenster vorn ist, holt
		focusNextVisible nicht den Besitzer nach vorn — niemand fasst ihn also
		an, und er bliebe aktiv aussehen, obwohl sein Dialog weg ist.
	--]]
	refreshOwnerChain(window)

	self:_reorder()
	self.windowClosed:fire(window)
end

function WindowManager:closeAll()
	for _, window in table.clone(self._windows) do
		window:close()
	end
end

--------------------------------------------------------------------------
-- Modale Dialoge
--------------------------------------------------------------------------

--[[
	ANWENDUNGSMODAL, NICHT SYSTEMMODAL — der Unterschied, den Windows macht.

	MB_APPLMODAL ist die Vorgabe: der Benutzer muss den Dialog beantworten,
	bevor er IN DEM FENSTER weiterarbeiten kann, das als Besitzer übergeben
	wurde. Andere Fenster bleiben bedienbar; erst MB_SYSTEMMODAL hält alles
	an.

	Deshalb wird der BESITZER abgeschaltet (setEnabled), so wie EnableWindow
	es tut. Eine Kette ergibt sich von selbst: Dialog 3 schaltet Dialog 2 ab,
	der hat Dialog 1 abgeschaltet, der das Fenster — am Ende ist die ganze
	Familie gesperrt und sonst nichts.

	OHNE BESITZER BLEIBT ES SYSTEMMODAL. Dann gibt es kein Fenster, das man
	abschalten könnte, und ein Dialog, der nichts sperrt, wäre keiner.

	entry: { frame, owner, onBlocked }
--]]
function WindowManager:_applyTopModal()
    for index=#self._modals,1,-1 do
        local entry=self._modals[index]
        if not entry.owner then self.input:setModal(entry.frame,entry.onBlocked);return end
    end
    self.input:setModal(nil)
end

function WindowManager:pushModal(entry)
	assert(entry and entry.frame, "WindowManager:pushModal: frame fehlt")

	table.insert(self._modals, entry)

	if entry.owner then
		entry.owner:setEnabled(false, entry.onBlocked)
	end

	self:_applyTopModal()
end

--[[
	Den Besitzer nur dann wieder anschalten, wenn ihn kein ANDERER Dialog
	noch sperrt. Zwei Dialoge auf demselben Fenster sind selten, aber der
	Fall, in dem einer davon die Sperre des anderen aufhebt, ist genau der,
	den man nicht debuggen will.

	Der Stapel bleibt: schliesst der obere Dialog, muss die Sperre auf den
	darunter zurückfallen und nicht ganz verschwinden.
--]]
function WindowManager:popModal(frame)
	for index = #self._modals, 1, -1 do
		local entry = self._modals[index]

		if entry.frame == frame then
			table.remove(self._modals, index)

			if entry.owner then
				local nochGesperrt = false

				for _, rest in self._modals do
					if rest.owner == entry.owner then
						nochGesperrt = true
						break
					end
				end

				if not nochGesperrt then
					entry.owner:setEnabled(true)
				end
			end

			break
		end
	end

	self:_applyTopModal()
end

-- Wie viele modale Dialoge gerade offen sind. Für Tests und zum Nachsehen.
function WindowManager:modalDepth()
	return #self._modals
end

--------------------------------------------------------------------------
-- Fokus und Z-Reihenfolge
--------------------------------------------------------------------------

function WindowManager:focus(window)
	if not window then
		return
	end

	local index = table.find(self._windows, window)
	if not index then
		return
	end

    if self.input.canFocus and not self.input:canFocus(window)then
        local entry=self._modals[#self._modals]
        if entry then for _,candidate in self._windows do if candidate.frame==entry.frame then self:focus(candidate);return end end end
        return
    end
	if self._focused == window then
		-- The order already contains this focus operation. A focused owner can
		-- still have a newer owned window behind it in the list; retain the
		-- family reorder in that case instead of checking focus alone.
		if index == #self._windows then return end
        table.remove(self._windows,index);table.insert(self._windows,window)
		self:_reorder()
		return
	end

	-- Ans Listenende heisst ganz nach vorn
	table.remove(self._windows, index)
	table.insert(self._windows, window)

	local previous = self._focused
	self._focused = window

	if previous then
		previous:setFocused(false)
	end
	window:setFocused(true)

	--[[
		Die Besitzer beider Seiten neu zeichnen.

		BEIM NEUEN, damit ein Elternfenster aktiv wird, sobald sein Dialog
		vorn ist. BEIM ALTEN, damit es das wieder verliert, wenn der Fokus die
		Familie verlässt — sonst bliebe ein Fenster blau, dessen Dialog längst
		nicht mehr dran ist.

		Nach setFocused, weil _focused und die Fokus-Flags dann stimmen:
		looksActive() liest sie.
	--]]
	refreshOwnerChain(window)
	refreshOwnerChain(previous)

	--[[
		Die Tastatur folgt dem Fokus. Ab hier bekommt dieses Fenster die
		Tasten — das ist die Windows-Regel, und sie macht Sondermeldungen
		überflüssig: kein Bedienelement muss selbst prüfen, ob es dran ist.
	--]]
	self.input:setFocus(window.frame)

	self:_reorder()
	self.focusChanged:fire(window, previous)
end

--[[
	Fokus an das oberste noch sichtbare Fenster geben.

	Wird gebraucht, wenn das aktive Fenster minimiert oder geschlossen wird.
	exclude nimmt das Fenster heraus, das gerade verschwindet — sonst würde
	sich ein minimiertes Fenster selbst wieder den Fokus geben.
--]]
function WindowManager:focusNextVisible(exclude)
	for index = #self._windows, 1, -1 do
		local candidate = self._windows[index]

		if candidate ~= exclude and candidate:isVisible() then
			self:focus(candidate)
			return candidate
		end
	end

	--[[
		Nichts mehr da — dann richtig abgeben, nicht nur _focused leeren.

		Ein blosses self._focused = nil genügt NICHT. Es liesse das zuletzt
		aktive Fenster mit focused = true zurück: seine Fokus-Optik bliebe,
		sein Ereignis feuerte nie, und die Taskleiste erführe nichts davon.
		Sichtbar wird das, sobald man das letzte offene Fenster minimiert.
	--]]
	self:clearFocus()
	return nil
end

--[[
	Den Fokus vollständig abgeben — danach ist KEIN Fenster mehr aktiv.

	Das ist der Zustand, in dem Windows ist, wenn man auf den Desktop klickt:
	kein Titelbalken aktiv, kein Knopf in der Leiste hervorgehoben, und die
	Tastatur geht nirgendwohin.

	Er ist ein eigener Zustand und nicht "Fokus auf nichts": focus(nil) steigt
	oben aus, weil ein fehlendes Fenster dort ein Aufrufsfehler ist und keine
	Absicht. Diese Unterscheidung will man behalten.

	Die Z-Reihenfolge bleibt, wie sie ist. Ein Fenster, das den Fokus verliert,
	rutscht in Windows nicht nach hinten — es wird nur blass.

	focusChanged feuert mit (nil, previous). Wer daran hängt, muss also mit nil
	als erstem Argument rechnen; die Taskleiste ignoriert die Argumente
	ohnehin und liest den Zustand neu ab.
--]]
function WindowManager:clearFocus()
	local previous = self._focused

	if not previous then
		return nil
	end

	self._focused = nil
	previous:setFocused(false)

	--[[
		Auch die Besitzer: gibt der Desktop den Fokus ab, während ein Dialog
		vorn war, muss das Elternfenster seine Aktivität mit verlieren.
	--]]
	refreshOwnerChain(previous)

	--[[
		Auch die Tastatur. Der InputRouter löst sie bei einem Klick daneben
		zwar selbst, aber clearFocus wird auch programmatisch gerufen — und
		dann bliebe die Tastatur sonst bei einem Fenster hängen, das gar nicht
		mehr aktiv ist.
	--]]
	self.input:setFocus(nil)

	self.focusChanged:fire(nil, previous)
	return previous
end

--[[
	Z-Reihenfolge neu vergeben: Position in der Liste = ZIndex.

	Ein Wert pro Fenster genügt, weil die ScreenGuis mit
	ZIndexBehavior = Sibling laufen — Kinder rendern immer über ihrem
	Elternteil, und ZIndex zählt nur zwischen Geschwistern. Eine Spanne pro
	Fenster wird dadurch nicht gebraucht.
--]]
function WindowManager:_reorder()
    local members,roots,groups={},{},{}
    for _,window in self._windows do members[window]=true end
    for _,window in self._windows do
        local root=window;local seen={}
        while root.owner and members[root.owner]and not seen[root.owner]do seen[root]=true;root=root.owner end
        local at=table.find(roots,root);if at then table.remove(roots,at)end;table.insert(roots,root)
        groups[root]=groups[root]or{};table.insert(groups[root],window)
    end
    local placed={};local index=0
    local function place(window,depth)
        if placed[window]or depth>32 then return end
        if window.owner and members[window.owner]then place(window.owner,depth+1)end
        if placed[window]then return end
        placed[window]=true;index+=1;window:setZ(index)
    end
    for _,root in roots do for _,window in groups[root]do place(window,0)end end
end

--------------------------------------------------------------------------
-- Abfragen
--------------------------------------------------------------------------

function WindowManager:getFocused()
	return self._focused
end

--[[
	Alle Fenster in Z-Reihenfolge, hinten das oberste.

	Wer eine STABILE Reihenfolge braucht, nimmt listOpened() — diese hier
	ändert sich bei jedem Fokuswechsel.
--]]
function WindowManager:list()
	return table.clone(self._windows)
end

-- Alle Fenster in Öffnungsreihenfolge, unabhängig vom Fokus.
function WindowManager:listOpened()
	return table.clone(self._opened)
end

--[[
	taskbarOrder(windows) -> { window }

	Die Auswahl für die Taskleiste, als reine Funktion über einer Liste.

	Sie entscheidet NICHTS selbst: showsInTaskbar() gehört dem Fenster, hier
	wird nur gefiltert. Deshalb steht die Regel an einer Stelle und die
	Anwendung an einer anderen, und deshalb lässt sich diese hier mit
	einfachen Tabellen prüfen, ohne ein einziges Roblox-Objekt.
--]]
function WindowManager.taskbarOrder(windows)
	local result = {}

	for _, window in windows do
		if window:showsInTaskbar() then
			table.insert(result, window)
		end
	end

	return result
end

--[[
	ownedBy(windows, owner) -> { window }

	Die Fenster aus der Liste, die owner GEHÖREN — direkt, nicht über Ecken.
	Die Reihenfolge der Eingabe bleibt erhalten; wer das oberste braucht,
	übergibt die Z-Reihenfolge und nimmt den letzten Eintrag.
--]]
function WindowManager.ownedBy(windows, owner)
	local result = {}

	for _, candidate in windows do
		if candidate.owner == owner then
			table.insert(result, candidate)
		end
	end

	return result
end

--[[
	Was die Taskleiste zeigt: Öffnungsreihenfolge, ohne die Fenster, die
	einen Besitzer haben.

	Damit bleibt die Taskleiste eine Ansicht und keine zweite Buchhaltung, und
	die Richtung stimmt weiterhin: Windows weiss nichts von der Leiste.
--]]
function WindowManager:listTaskbar()
	return WindowManager.taskbarOrder(self._opened)
end

--[[
	Die Fenster, die window besitzt, in Öffnungsreihenfolge.

	Die Taskleiste braucht das für den Klick: hat ein Fenster einen sichtbaren
	Dialog, gehört der nach vorn und nicht der Besitzer.
--]]
function WindowManager:listOwned(window)
	return WindowManager.ownedBy(self._opened, window)
end

-- Dieselbe Frage in Z-Reihenfolge, damit "das oberste" beantwortbar ist.
function WindowManager:listOwnedByZ(window)
	return WindowManager.ownedBy(self._windows, window)
end

function WindowManager:count()
	return #self._windows
end

--[[
	findByAppId(id) -> Window oder nil

	DAS OBERSTE, nicht irgendeines. _windows ist die Z-Reihenfolge mit dem
	obersten am ENDE — deshalb rückwärts.

	Vorher lief die Schleife vorwärts und lieferte damit das unterste. Bei
	einem Programm mit nur einem Fenster fällt das nie auf; sobald es zwei
	gibt (ein Editor mit zwei Dateien), holt ein Klick in der Leiste das
	falsche nach vorn.

	„Das oberste" ist auch die Frage, die die Aufrufer wirklich stellen: der
	Rechner will sein vorhandenes Fenster nach vorn holen, und gemeint ist
	das, das man zuletzt gesehen hat.
--]]
function WindowManager:findByAppId(appId)
	for index = #self._windows, 1, -1 do
		local window = self._windows[index]

		if window.appId == appId then
			return window
		end
	end

	return nil
end

--[[
	Alle Fenster eines Programms, in Öffnungsreihenfolge.

	Gebraucht, sobald ein Programm mehrere Fenster hat und alle betreffen
	soll — „alle Editoren schliessen" etwa.
--]]
function WindowManager:findAllByAppId(appId)
	local result = {}

	for _, window in self._opened do
		if window.appId == appId then
			table.insert(result, window)
		end
	end

	return result
end

-- Alle minimierten Fenster. Die Taskleiste wird das später brauchen.
function WindowManager:listMinimized()
	local result = {}

	for _, window in self._windows do
		if window:isMinimized() then
			table.insert(result, window)
		end
	end

	return result
end

function WindowManager:destroy()
	self:closeAll()

	--[[
		Eine Sperre, die noch am Router hängt, muss weg. closeAll räumt zwar
		jeden Dialog und damit jeden popModal — aber ein Dialog, der ohne
		close() verschwindet, liesse den Router systemmodal zurück, und danach
		reagierte gar nichts mehr.
	--]]
	self._modals = {}
	self.input:setModal(nil)

	self._cleanup:clean()

	self.windowOpened:destroy()
	self.windowClosed:destroy()
	self.focusChanged:destroy()
end

return WindowManager
