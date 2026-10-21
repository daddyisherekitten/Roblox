--!strict
-- Reusable persistence core. Remote authentication, scheduling and DataStore
-- construction belong to the host; injected stores make failures testable.
local Protocol = require(script.Parent.Protocol)
local Server = {}
Server.__index = Server

local function call(callback: any, ...: any)
	if callback then
		local success, message = pcall(callback, ...)
		if not success then warn("HTML storage callback: " .. tostring(message)) end
	end
end

local function validUser(userId: any): boolean
	return type(userId) == "number" and userId ~= 0 and math.abs(userId) <= 9007199254740991 and userId % 1 == 0
end

local function sameChanges(first: any, second: any): boolean
	if #first ~= #second then return false end
	for index, item in first do
		local other = second[index]
		if item.Kind ~= other.Kind or item.Key ~= other.Key or item.NewValue ~= other.NewValue then return false end
	end
	return true
end

function Server.new(options: any): any
	assert(options and options.Store and type(options.AllowedOrigins) == "table", "Storage server requires a store and approved origins")
	local approved, count = {}, 0
	for address, enabled in options.AllowedOrigins do
		if enabled then
			local origin = Protocol.origin(address)
			assert(origin and origin == address, "Approved storage origins must be canonical HTTP(S) origins")
			approved[origin] = true; count += 1
		end
	end
	assert(count <= 32, "Storage host supports at most 32 approved origins")
	return setmetatable({Store = options.Store, AllowedOrigins = approved, Players = {}, Clock = options.Clock or os.clock,
		OnDirty = options.OnDirty, OnSaved = options.OnSaved, OnError = options.OnError}, Server)
end

function Server:_state(userId: number, origin: string): any?
	local player = self.Players[userId]
	return if player then player.States[origin] else nil
end

function Server:_error(state: any, message: string)
	state.LastError = message
	call(self.OnError, state.UserId, state.Origin, message)
end

function Server:_request(player: any): boolean
	local now = self.Clock()
	player.Tokens = math.min(16, player.Tokens + math.max(0, now - player.LastTokenTime) * 4)
	player.LastTokenTime = now
	if player.Tokens < 1 then return false end
	player.Tokens -= 1
	return true
end

function Server:Load(userId: number, origin: any): any
	if not validUser(userId) or type(origin) ~= "string" or not self.AllowedOrigins[origin] then return {Ok = false, Denied = true, Error = "Storage origin is not approved"} end
	local player = self.Players[userId]
	if not player then player = {States = {}, Tokens = 16, LastTokenTime = self.Clock()}; self.Players[userId] = player end
	if not self:_request(player) then return {Ok = false, Error = "Storage request rate exceeded"} end
	local state = player.States[origin]
	if state and state.Area then return {Ok = true, Record = Protocol.encodeRecord(state.Area, origin, state.Receipts)} end
	if state and state.Loading then return {Ok = false, Error = "Storage load in progress"} end
	local now = self.Clock()
	if state and state.NextLoad and now < state.NextLoad then return {Ok = false, Error = state.LastError or "Storage load retry pending"} end
	if not state then
		state = {UserId = userId, Origin = origin, Pending = {}, PendingBytes = 0, Receipts = {}, Clients = {}, ClientCount = 0}
		player.States[origin] = state
	end
	state.Loading = true
	local success, record = pcall(function() return self.Store:GetAsync(Protocol.key(userId, origin)) end)
	state.Loading = false
	if self.Players[userId] ~= player or player.States[origin] ~= state then return {Ok = false, Error = "Storage load cancelled"} end
	if not success then
		state.NextLoad = self.Clock() + 2
		self:_error(state, "Storage load failed: " .. tostring(record))
		return {Ok = false, Error = state.LastError}
	end
	if record == nil then record = Protocol.createRecord(origin) end
	local area, message = Protocol.decodeRecord(record, origin)
	if not area then
		state.NextLoad = self.Clock() + 5
		self:_error(state, "Storage record rejected: " .. tostring(message))
		return {Ok = false, Error = state.LastError}
	end
	state.Area, state.Receipts, state.LastError = area, table.clone(record.Receipts), nil
	return {Ok = true, Record = Protocol.encodeRecord(area, origin, state.Receipts)}
end

function Server:Accept(userId: number, packet: any): any
	local reply = {Ok = false, Error = "Invalid storage batch"}
	if not validUser(userId) or type(packet) ~= "table" then return reply end
	for key in packet do
		if key ~= "Origin" and key ~= "ClientId" and key ~= "Sequence" and key ~= "Changes" then return reply end
	end
	local origin, clientId, sequence = packet.Origin, packet.ClientId, packet.Sequence
	if type(origin) ~= "string" or not self.AllowedOrigins[origin] or not Protocol.clientId(clientId) or not Protocol.sequence(sequence) then return reply end
	reply.Origin, reply.ClientId, reply.Sequence = origin, clientId, sequence
	local state = self:_state(userId, origin)
	if not state or not state.Area then reply.Error = "Storage must be loaded before writing"; return reply end
	if not self:_request(self.Players[userId]) then reply.Error = "Storage request rate exceeded"; return reply end
	local changes, message, wireBytes = Protocol.validateChanges(packet.Changes)
	if not changes then reply.Error = message; return reply end
	local saved = Protocol.receipt(state.Receipts, clientId)
	if sequence <= saved then reply.Ok, reply.Error, reply.Status = true, nil, "saved"; return reply end
	local client = state.Clients[clientId]
	if client and client.Pending then
		if client.Pending.Sequence == sequence and sameChanges(client.Pending.Changes, changes) then
			reply.Ok, reply.Error, reply.Status = true, nil, "accepted"
		else reply.Error = "Storage client has an outstanding batch" end
		return reply
	end
	if sequence ~= saved + 1 then reply.Error = "Storage sequence is out of order"; return reply end
	if not client and state.ClientCount >= Protocol.MaxReceipts then reply.Error = "Storage client limit exceeded"; return reply end
	if state.PendingBytes + (wireBytes :: number) > Protocol.MaxPendingBytes then reply.Error = "Storage pending queue is full"; return reply end
	local area = Protocol.cloneArea(state.Area)
	local applied, applyError = Protocol.applyChanges(area, changes)
	if not applied then reply.Error = applyError; return reply end
	if not client then client = {}; state.Clients[clientId] = client; state.ClientCount += 1 end
	local batch = {ClientId = clientId, Sequence = sequence, Changes = changes, WireBytes = wireBytes}
	client.Pending = batch
	table.insert(state.Pending, batch)
	state.PendingBytes += wireBytes :: number
	state.Area, state.LastError = area, nil
	reply.Ok, reply.Error, reply.Status = true, nil, "accepted"
	call(self.OnDirty, state)
	return reply
end

function Server:Flush(userId: number, origin: string): boolean
	local state = self:_state(userId, origin)
	if not state or not state.Area or #state.Pending == 0 then return true end
	if state.Flushing then return false end
	state.Flushing = true
	local pending = table.clone(state.Pending)
	local success, record = pcall(function()
		return self.Store:UpdateAsync(Protocol.key(userId, origin), function(current)
			if current == nil then current = Protocol.createRecord(origin) end
			local area, decodeError = Protocol.decodeRecord(current, origin)
			assert(area, decodeError)
			local receipts = table.clone(current.Receipts)
			for _, batch in pending do
				local saved = Protocol.receipt(receipts, batch.ClientId)
				if batch.Sequence > saved then
					assert(batch.Sequence == saved + 1, "Persisted storage sequence is out of order")
					local applied, applyError = Protocol.applyChanges(area, batch.Changes)
					assert(applied, applyError)
					Protocol.setReceipt(receipts, batch.ClientId, batch.Sequence)
				end
			end
			return Protocol.encodeRecord(area, origin, receipts)
		end)
	end)
	state.Flushing = false
	if not success then self:_error(state, "Storage save failed: " .. tostring(record)); return false end
	local area, message = Protocol.decodeRecord(record, origin)
	if not area then self:_error(state, "Storage save result rejected: " .. tostring(message)); return false end
	-- An UpdateAsync callback may be repeated or a previous response lost.
	-- Receipts are part of the same atomic record as the corresponding values.
	for _, batch in pending do
		if Protocol.receipt(record.Receipts, batch.ClientId) < batch.Sequence then
			self:_error(state, "Storage save result is missing its receipt"); return false
		end
	end
	state.Receipts, state.LastError = table.clone(record.Receipts), nil
	for _, batch in pending do
		local index = table.find(state.Pending, batch)
		if index then table.remove(state.Pending, index); state.PendingBytes -= batch.WireBytes end
		local client = state.Clients[batch.ClientId]
		if client and client.Pending == batch then client.Pending = nil end
	end
	-- Changes accepted while UpdateAsync yielded remain queued and visible.
	local retained = Protocol.cloneArea(area)
	local allApplied = true
	for _, batch in state.Pending do
		if not Protocol.applyChanges(retained, batch.Changes) then allApplied = false; break end
	end
	if allApplied then state.Area = retained end
	for _, batch in pending do call(self.OnSaved, userId, origin, batch.ClientId, batch.Sequence) end
	if #state.Pending > 0 then call(self.OnDirty, state) end
	return true
end

function Server:FlushPlayer(userId: number): boolean
	local player = self.Players[userId]
	if not player then return true end
	local success = true
	for origin in player.States do if not self:Flush(userId, origin) then success = false end end
	return success
end

function Server:DestroyPlayer(userId: number, shouldDestroy: any?): boolean
	local player = self.Players[userId]
	if not self:FlushPlayer(userId) then return false end
	-- Hosts may reject disposal after a yielding save if the player rejoined.
	if shouldDestroy and not shouldDestroy() then return false end
	if self.Players[userId] == player then self.Players[userId] = nil end
	return true
end

function Server:Pending(userId: number, origin: string): boolean
	local state = self:_state(userId, origin)
	return state ~= nil and #state.Pending > 0
end

return Server
