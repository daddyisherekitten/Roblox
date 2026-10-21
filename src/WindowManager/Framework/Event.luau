--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Event — Signal in reinem Lua, ohne BindableEvent-Instance.

	Warum nicht BindableEvent? Weil das eine echte Roblox-Instanz ist: sie
	kostet Speicher, taucht im Explorer auf, und ihre Argumente werden bei
	jedem :Fire() kopiert — Tabellen kommen als Kopie an, Metatables gehen
	verloren. Für Fenster- und Prozessereignisse, die Objekte weitergeben,
	ist das unbrauchbar. Hier bleiben Referenzen Referenzen.

	Nebenbei: BindableEvent feuert in neuen Places deferred, der Handler
	läuft also erst am Ende des Frames. Hier läuft er sofort.

		local closed = Event.new()

		local conn = closed:connect(function(window)
			print("zu:", window.title)
		end)

		closed:fire(someWindow)
		conn:disconnect()

	API: .new() · :connect(fn) -> Connection · :once(fn) -> Connection
	     :fire(...) · :wait(timeout?) · :listenerCount() · :isDestroyed()
	     :destroy()

	Connection: :disconnect() · :isConnected()
--]]

local Event = {}
Event.__index = Event

function Event.new()
	return setmetatable({
		--[[
			Ein Listener ist { callback = fn, connected = bool }.

			connected ist ein Feld, kein Entfernen aus der Liste. So kann
			:disconnect() mitten in einem laufenden :fire() aufgerufen
			werden, ohne die Iteration zu beschädigen — der Listener wird
			nur noch übersprungen und später weggeräumt.
		--]]
		_listeners = {},
		_firing = 0,
		_destroyed = false,
	}, Event)
end

local function makeConnection(listener)
	local connection = {}

	function connection:disconnect()
		listener.connected = false
	end

	function connection:isConnected()
		return listener.connected
	end

	return connection
end

function Event:connect(callback)
	assert(type(callback) == "function", "Event:connect braucht eine Funktion")

	local listener = { callback = callback, connected = true }

	if self._destroyed then
		-- Nach :destroy() feuert nichts mehr. Eine tote Connection
		-- zurückzugeben ist ehrlicher, als sie stumm einzuhängen.
		warn("Event: :connect() nach :destroy() — Listener ist inaktiv")
		listener.connected = false
		return makeConnection(listener)
	end

	table.insert(self._listeners, listener)
	return makeConnection(listener)
end

--[[
	Feuert genau einmal. Getrennt wird VOR dem Callback — sonst könnte der
	Callback selbst ein :fire() auslösen und sich rekursiv erneut aufrufen.
--]]
function Event:once(callback)
	local connection

	connection = self:connect(function(...)
		connection:disconnect()
		callback(...)
	end)

	return connection
end

--[[
	Ruft alle Listener auf, in Verbindungsreihenfolge.

	Zwei Vorkehrungen:

	  1. table.clone: der Callback darf :connect() und :disconnect() rufen,
	     ohne die laufende Iteration zu verändern. Neu Verbundene bekommen
	     dieses fire NICHT mehr — das ist Absicht, sonst könnte ein Listener,
	     der sich selbst verbindet, eine Endlosschleife bauen.

	  2. pcall: ein Fehler in einem Listener darf die übrigen nicht
	     verschlucken. Bei einem Fenster hängen an closed schnell fünf
	     Zuhörer; einer davon soll die anderen nicht mitnehmen.

	_firing zählt verschachtelte Aufrufe, damit :_compact() erst nach dem
	äussersten läuft. Würde ein innerer fire die Liste umbauen, zeigte die
	äussere Schleife auf ihre Kopie — kein Fehler, aber :listenerCount()
	wäre zwischenzeitlich falsch.
--]]
function Event:fire(...)
	if self._destroyed then
		return
	end

	self._firing += 1

	local snapshot = table.clone(self._listeners)

	for _, listener in snapshot do
		if listener.connected then
			local ok, err = pcall(listener.callback, ...)
			if not ok then
				warn("Event: Fehler im Callback:", err)
			end
		end
	end

	self._firing -= 1

	if self._firing == 0 then
		self:_compact()
	end
end

-- Wirft getrennte Listener aus der Liste. Ohne das wächst sie bei einem
-- Event, an dem sich dauernd etwas an- und abmeldet, unbegrenzt.
function Event:_compact()
	local alive = {}

	for _, listener in self._listeners do
		if listener.connected then
			table.insert(alive, listener)
		end
	end

	self._listeners = alive
end

--[[
	Hält den aufrufenden Thread an, bis das Event feuert. Gibt die
	Argumente des fire zurück.

	Mit timeout: läuft die Zeit ab, kommt nichts zurück (nil). Der Aufrufer
	unterscheidet die Fälle also am ersten Rückgabewert:

		local window = wm.windowOpened:wait(5)
		if not window then
			warn("kein Fenster in 5 Sekunden")
		end

	resumed schützt gegen doppeltes Fortsetzen: feuert das Event genau in
	dem Moment, in dem der Timer zuschlägt, würde der Thread sonst zweimal
	fortgesetzt — das ist ein harter Fehler ("cannot resume dead coroutine").
--]]
function Event:wait(timeout)
	local thread = coroutine.running()
	assert(thread, "Event:wait() nur aus einer Coroutine aufrufbar")

	local resumed = false

	local connection = self:once(function(...)
		if resumed then
			return
		end
		resumed = true
		task.spawn(thread, ...)
	end)

	if timeout then
		task.delay(timeout, function()
			if resumed then
				return
			end
			resumed = true
			connection:disconnect()
			task.spawn(thread, nil)
		end)
	end

	return coroutine.yield()
end

function Event:listenerCount()
	local count = 0

	for _, listener in self._listeners do
		if listener.connected then
			count += 1
		end
	end

	return count
end

function Event:isDestroyed()
	return self._destroyed
end

--[[
	Trennt alle Listener und macht das Event unbrauchbar. Wird von den
	Besitzern aufgerufen (Fenster, Prozessmanager), wenn sie selbst
	weggeräumt werden — ein Event, das noch Referenzen auf Callbacks hält,
	hält damit auch alles fest, was diese Callbacks in ihrem Upvalue haben.
--]]
function Event:destroy()
	for _, listener in self._listeners do
		listener.connected = false
	end

	self._listeners = {}
	self._destroyed = true
end

return Event
