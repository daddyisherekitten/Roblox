--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Cleanup — sammelt alles, was später weggeräumt werden muss, und räumt es
	auf einen Aufruf hin auf.

	Der Sinn: ein Fenster erzeugt Frames, Connections, Threads und
	Registry-Einträge. Ohne einen gemeinsamen Sammelpunkt muss jedes Modul
	seine eigene Liste führen und beim Schliessen daran denken — und genau
	dort entstehen die Lecks.

		local cleanup = Cleanup.new()

		-- :add gibt das Item zurück, Zuweisung und Registrierung in einem
		local frame = cleanup:add(New("Frame", { Parent = parent }))
		cleanup:add(someEvent:connect(handler))
		cleanup:add(function() print("zum Schluss") end)

		cleanup:clean()   -- Funktion, Connection, Frame — in dieser Reihenfolge

	Angenommen werden: Funktionen, RBXScriptConnections, Instances, Threads
	und Tabellen mit :disconnect, :destroy, :clean oder :Destroy.

	Aufgeräumt wird LIFO, also zuletzt Hinzugefügtes zuerst. Das ist kein
	Detail: Connections zeigen fast immer auf Instanzen, die vorher erzeugt
	wurden. Räumt man vorwärts auf, wird die Instanz zerstört, während die
	Connection noch hängt.

	ZYKLISCH GEHT NICHT — dafür gibt es :scope(). Eine geleerte Cleanup ist
	verbraucht; wer sie erneut füllt, verliert die Items sofort wieder.
	Das ist Absicht (siehe :add), heisst aber, dass ein Modul, das seine UI
	regelmässig neu baut, ein eigenes Werkzeug braucht.

	API: .new() · :add(item) -> item · :addAll{...} · :remove(item)
	     :clean() · :size() · :isEmpty() · :isCleaned() · :destroy()
	     :scope() -> scope   für alles, was neu gebaut wird
--]]

local Cleanup = {}
Cleanup.__index = Cleanup

function Cleanup.new()
	return setmetatable({
		_items = {},
		_cleaning = false,
		_cleaned = false,
	}, Cleanup)
end

--[[
	Gibt das Item unverändert zurück, damit sich Erzeugen und Registrieren
	in einer Zeile schreiben lassen:

		local frame = cleanup:add(New("Frame", {...}))

	Nach :clean() wird nichts mehr angenommen — ein Item, das in eine
	bereits geleerte Cleanup wandert, würde nie aufgeräumt und wäre damit
	genau das Leck, das dieses Modul verhindern soll. Deshalb wird es
	sofort weggeräumt und gewarnt.

	WÄHREND :clean() ist :add() dagegen erlaubt und normal: Aufräumcode ruft
	gelegentlich Code, der selbst noch etwas registriert. Das Item landet
	regulär in der Liste und wird von der Schleife in :clean() mit
	abgearbeitet. Deshalb fragt die Prüfung unten _cleaned und nicht
	_cleaning — _cleaned wird erst gesetzt, wenn :clean() durch ist.
--]]
function Cleanup:add(item)
	assert(item ~= nil, "Cleanup:add: nil kann nicht aufgeräumt werden")

	if self._cleaned then
		warn("Cleanup: :add() nach :clean() — Item wird sofort weggeräumt")
		Cleanup._dispose(item)
		return item
	end

	table.insert(self._items, item)
	return item
end

function Cleanup:addAll(items)
	assert(type(items) == "table", "Cleanup:addAll braucht eine Liste")

	for _, item in items do
		self:add(item)
	end
end

--[[
	Nimmt ein Item wieder aus der Liste, ohne es aufzuräumen. Für den Fall,
	dass ein Objekt den Besitzer wechselt — etwa ein Frame, der aus einem
	Fenster in ein anderes verschoben wird.

	Gibt zurück, ob das Item überhaupt drin war.
--]]
function Cleanup:remove(item)
	local index = table.find(self._items, item)
	if not index then
		return false
	end

	table.remove(self._items, index)
	return true
end

--[[
	Ein einzelnes Item wegräumen. Die Fallunterscheidung steht bewusst nur
	hier — sie ist der eigentliche Inhalt des Moduls.

	pcall um Funktionen und Methoden: ein fehlerhafter Aufräumschritt darf
	die übrigen nicht verhindern. Sonst reisst ein einziger Fehler beim
	Fensterschliessen die ganze Kette ab und alles danach leckt.
--]]
function Cleanup._dispose(item)
	local kind = typeof(item)

	if kind == "function" then
		local ok, err = pcall(item)
		if not ok then
			warn("Cleanup: Funktion fehlgeschlagen:", err)
		end
		return
	end

	if kind == "RBXScriptConnection" then
		item:Disconnect()
		return
	end

	if kind == "Instance" then
		item:Destroy()
		return
	end

	if kind == "thread" then
		-- Ein Thread, der gerade selbst aufräumt, lässt sich nicht
		-- abbrechen. pcall schluckt genau diesen Fall.
		pcall(task.cancel, item)
		return
	end

	if kind == "table" then
		-- Reihenfolge: erst die Projektkonvention (klein geschrieben),
		-- dann Destroy für fremde Bibliotheken im Roblox-Stil.
		local method = item.disconnect or item.destroy or item.clean or item.Destroy

		if type(method) ~= "function" then
			warn("Cleanup: Tabelle ohne disconnect/destroy/clean hinzugefügt")
			return
		end

		local ok, err = pcall(method, item)
		if not ok then
			warn("Cleanup: Methode fehlgeschlagen:", err)
		end
		return
	end

	warn("Cleanup: unbekannter Typ:", kind)
end

--[[
	Räumt alles auf. Danach ist die Cleanup verbraucht (:isCleaned()).

	Die Liste wird vorher ausgetauscht. Grund: Aufräumfunktionen rufen
	gelegentlich Code, der selbst wieder etwas registriert. Ohne den Tausch
	würde man in die Liste schreiben, die man gerade durchläuft — und je
	nach Reihenfolge Items überspringen oder doppelt abarbeiten.

	Der _cleaning-Riegel fängt den anderen Fall: eine Aufräumfunktion, die
	:clean() erneut auslöst (etwa window:close() im closed-Handler). Ohne
	ihn liefen die Items rekursiv doppelt.

	_cleaned wird erst am Ende gesetzt, nicht am Anfang. Setzt man es vorn,
	hält :add() die Cleanup schon während des Aufräumens für verbraucht,
	räumt nachgereichte Items sofort selbst weg und warnt dabei — die
	Schleife hier unten wäre toter Code. Genau dieser Fehler ist im ersten
	Studio-Lauf durch eine unerwartete Warnung aufgefallen.
--]]
function Cleanup:clean()
	if self._cleaning then
		return
	end

	self._cleaning = true

	-- Solange etwas nachkommt, weitermachen. Fast immer genau eine Runde.
	while #self._items > 0 do
		local items = self._items
		self._items = {}

		for i = #items, 1, -1 do
			Cleanup._dispose(items[i])
		end
	end

	self._cleaning = false
	self._cleaned = true
end

function Cleanup:size()
	return #self._items
end

function Cleanup:isEmpty()
	return #self._items == 0
end

function Cleanup:isCleaned()
	return self._cleaned
end

--[[
	Damit eine Cleanup selbst in eine andere Cleanup wandern kann — eine
	Fenster-Cleanup in die des Prozesses, zum Beispiel. :destroy ist einer
	der Namen, die :dispose in Tabellen sucht.
--]]
function Cleanup:destroy()
	self:clean()
end

--------------------------------------------------------------------------
-- Scope: für alles, was neu gebaut wird
--------------------------------------------------------------------------

--[[
	scope() -> scope

	Ein Bereich, der sich BELIEBIG OFT leeren und neu füllen lässt — genau
	das, was eine Cleanup allein nicht kann.

		local knoepfe = cleanup:scope()

		function bar:refresh()
			local frisch = knoepfe:fresh()   -- leert das vorige
			for _, fenster in liste do
				frisch:add(createButton(fenster))
			end
		end

	scope
		:fresh() -> Cleanup   das vorige leeren, ein neues zurückgeben
		:current() -> Cleanup oder nil
		:clean()              leeren, ohne ein neues anzulegen

	WARUM DAS NICHT JEDES MODUL SELBST MACHT: weil es dabei zweimal
	schiefgegangen ist, in der Taskleiste und im Desktop-Raster, jeweils auf
	dieselbe Weise. Beide riefen am Ende ihres Aufbaus einmal refresh() —
	noch ohne Inhalt. Das leerte die wiederverwendete Cleanup und verbrannte
	sie, BEVOR je ein Knopf existierte. Ab da wurde jeder Knopf in dem
	Moment zerstört, in dem er registriert wurde: die Leiste blieb für immer
	leer, und im Output stand bei jedem Fenster „Cleanup: :add() nach
	:clean()".

	Hier kann das nicht passieren, weil :fresh() immer ein FRISCHES Cleanup
	zurückgibt und nie dasselbe zweimal.

	DER SCOPE SELBST HÄNGT AM ÄUSSEREN CLEANUP, nicht das jeweils aktuelle.
	Was wegzuräumen ist, steht erst beim Aufräumen fest — deshalb eine
	Funktion und keine Cleanup. LIFO sorgt für die Reihenfolge: der Scope
	wird angelegt, nachdem der Rahmen darüber steht, und läuft deshalb
	davor. Die Kinder verschwinden, bevor ihnen der Rahmen unter den Füssen
	weggezogen wird.
--]]
function Cleanup:scope()
	local scope = { _current = nil }

	function scope:clean()
		if self._current then
			self._current:clean()
			self._current = nil
		end
	end

	function scope:fresh()
		self:clean()
		self._current = Cleanup.new()
		return self._current
	end

	function scope:current()
		return self._current
	end

	self:add(function()
		scope:clean()
	end)

	return scope
end

return Cleanup
