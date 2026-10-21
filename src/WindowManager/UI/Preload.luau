--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Preload — Assets holen, bevor sie gebraucht werden.

		Preload.add("rbxassetid://123", "rbxassetid://456")

	WARUM ÜBERHAUPT?

	Roblox lädt ein Bild erst, wenn es zum ersten Mal angezeigt werden soll.
	Bis es da ist, bleibt die Fläche leer. Genau das sieht man beim ersten
	Dialog: die Schaltflächen sind kurz durchsichtig, das Symbol fehlt, dann
	springen sie an.

	Dasselbe gilt für Klänge — ein frisch gesetzter SoundId spielt erst, wenn
	die Datei da ist, und der Ton kommt hörbar nach dem Fenster.

	WER RUFT DAS AUF?

	Niemand von aussen. Jedes Modul meldet beim Laden seine eigenen Assets an;
	dieses Modul sammelt sie und lädt sie in EINEM Rutsch. Deshalb gibt es
	kein run() zum Vergessen — das Laden stösst sich selbst an.

	EIN Aufruf und nicht zwanzig: PreloadAsync arbeitet die Liste parallel ab,
	zwanzig Einzelaufrufe würden sich gegenseitig ausbremsen.

	API
		.add(...)        Asset-IDs oder Instanzen anmelden
		.pending()       was noch nicht abgeschickt wurde
		.loaded(asset)   ist es schon durch?
--]]

local ContentProvider = game:GetService("ContentProvider")

local Preload = {}

local queue = {}
local queued = {}       -- Asset -> true, gegen Doppeleinträge
local done = {}
local scheduled = false

--[[
	Der Sammelaufruf.

	task.defer und nicht sofort: beim Laden meldet ein Modul nach dem anderen
	seine Assets an, und alle sollen in derselben Liste landen. Sofortiges
	Abschicken würde für jedes Modul einen eigenen Aufruf starten.

	pcall drumherum. Schlägt das Laden fehl — kein Netz, Asset gesperrt,
	Tippfehler in der ID — soll die Oberfläche trotzdem laufen. Dann sieht man
	eben wieder den kurzen Verzug, aber nichts stürzt ab.
--]]
local function flush()
	scheduled = false

	local batch = queue
	queue = {}

	if #batch == 0 then
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)

		for _, asset in batch do
			done[asset] = true
		end

		if not ok then
			warn("Preload: Assets konnten nicht geladen werden — " .. tostring(err))
		end
	end)
end

--[[
	add(...) — Asset-IDs (Strings) oder Instanzen anmelden.

	Doppelte werden verworfen. Mehrere Module melden beim Laden an, und
	dasselbe Asset kann dabei mehrfach auftauchen.
--]]
function Preload.add(...)
	for index = 1, select("#", ...) do
		local asset = select(index, ...)

		if asset ~= nil and not queued[asset] then
			queued[asset] = true
			table.insert(queue, asset)
		end
	end

	if not scheduled and #queue > 0 then
		scheduled = true
		task.defer(flush)
	end
end

-- Was noch in der Warteschlange steht, also noch nicht abgeschickt wurde.
function Preload.pending()
	return table.clone(queue)
end

--[[
	Wurde das Asset schon einmal angemeldet?

	Anders als pending() bleibt die Antwort auch nach dem Abschicken stehen —
	das ist die Frage, die zählt, wenn ein zweites Modul dasselbe Bild
	anmeldet.
--]]
function Preload.known(asset)
	return queued[asset] == true
end

function Preload.loaded(asset)
	return done[asset] == true
end

return Preload
