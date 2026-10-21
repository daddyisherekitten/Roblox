--!strict
return function(Protocol, Server)
	local origin = "https://example.test"
	assert(Protocol.origin("HTTPS://name:password@EXAMPLE.TEST:443/a?q=1#here") == origin)
	assert(Protocol.origin("http://localhost:080/page") == "http://localhost")
	assert(Protocol.origin("https://[::1]:8443/page") == "https://[::1]:8443")
	for _, invalid in {"about:blank", "file:///a", "data:text/plain,x", "https://host:65536", "https://host/a\n", "https://host\\other"} do
		assert(Protocol.origin(invalid) == nil, "Reject unsupported/ambiguous storage origin: " .. invalid)
	end
	local loneHigh, loneLow = string.char(237, 160, 128), string.char(237, 176, 128)
	for _, value in {"", "A\0B", "Grüße", utf8.char(0x1f600), loneHigh, loneLow, loneHigh .. "x" .. loneLow} do
		local encoded = Protocol.encode(value)
		assert(not encoded:find("[^%x]") and Protocol.decode(encoded) == value, "Lossless ASCII storage transport")
		assert(Protocol.bytes(value) == #encoded / 2)
	end
	assert(Protocol.encode(loneHigh .. loneLow) == Protocol.encode(utf8.char(0x10000)), "Equivalent UTF-16 strings have the same encoding")
	for _, invalid in {"f", "000z", string.rep("0", Protocol.QuotaBytes * 2 + 4)} do assert(not pcall(Protocol.decode, invalid)) end
	for _, invalid in {string.char(128), string.char(192, 128), string.char(224, 128, 128), string.char(244, 144, 128, 128)} do assert(not pcall(Protocol.encode, invalid)) end
	assert(#Protocol.key(9007199254740991, origin) <= 50 and Protocol.key(11, origin) ~= Protocol.key(12, origin))
	assert(Protocol.key(11, origin) ~= Protocol.key(11, "http://example.test"))
	local function encoded(changes)
		local result = {}; for _, change in changes do table.insert(result, Protocol.encodeChange(change)) end; return result
	end
	local function set(key, value) return {Kind = "set", Key = key, NewValue = value} end
	local function packet(clientId, sequence, changes) return {Origin = origin, ClientId = clientId, Sequence = sequence, Changes = encoded(changes)} end
	local clock, saved, errors, dirty = 0, {}, {}, 0
	local records = {}
	local store = {}
	function store:GetAsync(key)
		if self.FailLoad then error("offline load") end
		return records[key]
	end
	function store:UpdateAsync(key, transform)
		if self.FailSave then error("offline save") end
		local result = transform(records[key])
		-- Model Roblox repeating a callback against the same current version.
		local repeated = transform(records[key])
		assert(#result.Entries == #repeated.Entries, "Update callback is repeatable")
		records[key] = result
		if self.DuringSave then local callback = self.DuringSave; self.DuringSave = nil; callback() end
		if self.LoseResponse then self.LoseResponse = false; error("response lost after durable commit") end
		return result
	end
	local function newServer()
		return Server.new({Store = store, AllowedOrigins = {[origin] = true}, Clock = function() return clock end,
			OnDirty = function() dirty += 1 end,
			OnSaved = function(userId, address, clientId, sequence) table.insert(saved, {userId, address, clientId, sequence}) end,
			OnError = function(_, _, message) table.insert(errors, message) end})
	end
	local server = newServer()
	local forbidden = server:Load(11, "https://unapproved.test")
	assert(not forbidden.Ok and forbidden.Denied == true and next(server.Players) == nil)
	assert(not server:Accept(11, packet("client-0001", 1, {set("x", "bad")})).Ok, "Writes require successful initial load")
	store.FailLoad = true
	assert(not server:Load(11, origin).Ok and not server:Accept(11, packet("client-0001", 1, {set("x", "bad")})).Ok)
	store.FailLoad = false; clock += 3
	assert(server:Load(11, origin).Ok)
	local first = packet("client-0001", 1, {set("draft", "one"), set("", loneHigh)})
	local ack = server:Accept(11, first)
	assert(ack.Ok and ack.Status == "accepted" and ack.ClientId == first.ClientId and #saved == 0 and dirty == 1)
	assert(server:Accept(11, first).Status == "accepted" and dirty == 1, "An unacknowledged retry does not queue twice")
	assert(not server:Accept(11, packet("client-0001", 1, {set("draft", "altered")})).Ok)
	assert(not server:Accept(11, packet("client-0001", 2, {set("draft", "two")})).Ok)
	store.FailSave = true
	assert(not server:Flush(11, origin) and server:Pending(11, origin) and #saved == 0)
	assert(Protocol.decodeRecord(server:Load(11, origin).Record, origin).Values.draft == "one", "Failed save retains accepted memory values")
	store.FailSave = false; store.LoseResponse = true
	assert(not server:Flush(11, origin) and server:Pending(11, origin) and #saved == 0)
	local durable = records[Protocol.key(11, origin)]
	assert(Protocol.decodeRecord(durable, origin).Values.draft == "one" and Protocol.receipt(durable.Receipts, first.ClientId) == 1)
	assert(server:Flush(11, origin) and not server:Pending(11, origin) and #saved == 1)
	assert(server:Accept(11, first).Status == "saved", "A lost durable acknowledgement is idempotent")
	clock += 10
	assert(server:Load(12, origin).Ok and #server:Load(12, origin).Record.Entries == 0, "Authenticated player storage is separate")
	assert(server:Load(-1, origin).Ok, "Studio test player identities are supported")
	assert(not server:Accept(11, packet("client-0002", 2, {set("x", "out of order")})).Ok)
	local malformed = packet("client-0002", 1, {set("x", "unused")}); malformed.Changes[1].Value = "00zz"
	assert(not server:Accept(11, malformed).Ok)
	local forged = packet("client-0002", 1, {set("x", "unused")}); forged.UserId = 12
	assert(not server:Accept(11, forged).Ok, "Only the authenticated host supplies player identity")
	local sparse = packet("client-0002", 1, {set("x", "unused")}); sparse.Changes.extra = {Kind = "clear"}
	assert(not server:Accept(11, sparse).Ok)
	local tooLarge = packet("client-0002", 1, {set("small", "should not leak"), set("huge", string.rep("x", Protocol.QuotaBytes / 2))})
	assert(not server:Accept(11, tooLarge).Ok and not server:Pending(11, origin), "Batch quota validation is atomic")
	assert(Protocol.decodeRecord(server:Load(11, origin).Record, origin).Values.small == nil)
	assert(server:Accept(11, packet("client-0001", 2, {set("draft", "two")})).Ok)
	-- Another server writes a different key before this server's UpdateAsync.
	local other = newServer()
	assert(other:Load(11, origin).Ok)
	assert(other:Accept(11, packet("client-0003", 1, {set("external", "kept")})).Ok and other:Flush(11, origin))
	store.DuringSave = function()
		clock += 10
		assert(not server:Flush(11, origin), "A second flush cannot overlap an in-flight UpdateAsync")
		assert(server:Accept(11, packet("client-0002", 1, {set("later", "queued while saving")})).Ok)
	end
	assert(server:Flush(11, origin) and server:Pending(11, origin))
	local loaded = Protocol.decodeRecord(server:Load(11, origin).Record, origin)
	assert(loaded.Values.draft == "two" and loaded.Values.external == "kept" and loaded.Values.later == "queued while saving")
	assert(server:Flush(11, origin) and not server:Pending(11, origin))
	assert(Protocol.decodeRecord(records[Protocol.key(11, origin)], origin).Values.external == "kept", "Delta merge preserves other server keys")
	clock += 10
	assert(server:Accept(11, packet("client-0001", 3, {{Kind = "remove", Key = "draft"}, {Kind = "clear"}, set("after", "clear")})).Ok)
	assert(server:DestroyPlayer(11) and server.Players[11] == nil)
	local reopened = newServer()
	assert(reopened:Load(11, origin).Ok)
	local restored = Protocol.decodeRecord(reopened:Load(11, origin).Record, origin)
	assert(restored.Values.after == "clear" and restored.Values.draft == nil and restored.Values.external == nil and #restored.Order == 1)
	assert(not Protocol.decodeRecord({Version = 1, Origin = "https://wrong.test", Entries = {}, Receipts = {}}, origin), "Hash collisions/origin mismatch cannot merge records")
	records[Protocol.key(13, origin)] = {Version = 1, Origin = origin, Entries = {{Key = "00zz", Value = ""}}, Receipts = {}}
	assert(not reopened:Load(13, origin).Ok and not reopened:Accept(13, packet("client-0001", 1, {set("x", "erase corrupt record")})).Ok)
	assert(records[Protocol.key(13, origin)].Entries[1].Key == "00zz", "Corrupt loads never fall back to writable empty storage")
	clock += 10
	assert(reopened:Accept(11, packet("client-0001", 4, {set("rejoined", "retained")})).Ok)
	local allowedDisposal = true
	store.DuringSave = function() allowedDisposal = false end
	assert(not reopened:DestroyPlayer(11, function() return allowedDisposal end) and reopened.Players[11] ~= nil,
		"A rejoin during a yielding save cancels disposal without losing loaded state")
	assert(not reopened:Pending(11, origin), "Cancelled disposal still completes the durable save")
	local loadServer = newServer()
	local previousGet = store.GetAsync
	function store:GetAsync(key)
		local concurrent = loadServer:Load(14, origin)
		assert(not concurrent.Ok and concurrent.Error == "Storage load in progress", "Initial loads do not overlap")
		return previousGet(self, key)
	end
	assert(loadServer:Load(14, origin).Ok)
	function store:GetAsync(key)
		assert(loadServer:DestroyPlayer(15))
		return previousGet(self, key)
	end
	assert(not loadServer:Load(15, origin).Ok and loadServer.Players[15] == nil, "A completed stale load cannot resurrect a disposed player")
	store.GetAsync = previousGet
	clock += 10
	local denied = 0
	for index = 1, 20 do if not reopened:Accept(11, packet("client-0001", 5, {set("x", "rate limited")})).Ok then denied += 1 end end
	assert(denied > 0 and #errors >= 3, "Writes and retries are rate bounded and failures reported")
	local deniedLoads = 0
	for _ = 1, 20 do if not loadServer:Load(14, origin).Ok then deniedLoads += 1 end end
	assert(deniedLoads > 0, "Cached-load replies are rate bounded too")
	print("Web Storage server: UTF-16 transport, quotas, authenticated origins, failed/corrupt loads, atomic delta merge, durable retries and disposal passed")
end
