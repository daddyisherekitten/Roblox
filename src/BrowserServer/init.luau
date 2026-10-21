--!strict
-- Server-only persistence transport. The client browser has no dependency on this service.
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Store = require(script.Store)
local Service = {}
Service.__index = Service
local function status(state, message, available) return {State = state, Message = message, Available = available == true} end
local function validSequence(value) return type(value) == 'number' and value == value and value % 1 == 0 and value > 0 and value <= 2147483647 end
local function remote(parent, name, className)
	local existing = parent:FindFirstChild(name)
	if existing then assert(existing:IsA(className), 'Wayline persistence remote has the wrong class'); return existing end
	local object = Instance.new(className); object.Name = name; object.Parent = parent; return object
end
function Service.new(schema, options)
	options = options or {}
	local folder = ReplicatedStorage:FindFirstChild(options.RemoteName or 'WaylinePersistence')
	if not folder then folder = Instance.new('Folder'); folder.Name = options.RemoteName or 'WaylinePersistence'; folder.Parent = ReplicatedStorage end
	local self = setmetatable({Alive = true, Stopping = false, Schema = schema, Store = Store.new(schema, options), States = {}, Connections = {}, Folder = folder, LoadRemote = remote(folder, 'Load', 'RemoteFunction'), UpdateRemote = remote(folder, 'Update', 'RemoteEvent'), StatusRemote = remote(folder, 'Status', 'RemoteEvent')}, Service)
	self.LoadRemote.OnServerInvoke = function(player, clientID) return self:_Read(player, clientID) end
	table.insert(self.Connections, self.UpdateRemote.OnServerEvent:Connect(function(player, clientID, sequence, payload) self:_Update(player, clientID, sequence, payload) end))
	table.insert(self.Connections, Players.PlayerRemoving:Connect(function(player) self:_Depart(player) end))
	table.insert(self.Connections, Players.PlayerAdded:Connect(function(player) self:_State(player) end))
	for _, player in Players:GetPlayers() do self:_State(player) end
	self.Heartbeat = task.spawn(function()
		while self.Alive and not self.Stopping do
			task.wait(15)
			for _, state in self.States do
				if state.Loaded and state.Writable and not state.Departed and os.clock() - (state.LastLease or 0) >= 40 and os.clock() >= (state.RetryAt or 0) then self:_Queue(state, true) end
			end
		end
	end)
	game:BindToClose(function() self:Shutdown() end)
	return self
end
function Service:_Publish(state, value)
	state.Status = value
	if state.Player.Parent == Players then self.StatusRemote:FireClient(state.Player, value) end
end
function Service:_State(player)
	local previous = self.States[player.UserId]
	if previous then return previous end
	local state = {Player = player, UserID = player.UserId, Loaded = false, Writable = false, Dirty = false, Generation = 0, LastSequence = 0, RateTokens = 5, RateTime = os.clock(), ReadAt = -math.huge, Status = status('loading', 'Loading saved browser data.', false)}
	self.States[player.UserId] = state
	state.LoadThread = task.spawn(function()
		local loaded = self.Store:Load(player.UserId)
		state.Data, state.Restored, state.Writable, state.Token, state.Revision, state.LastLease = loaded.Data, loaded.Restored, loaded.Writable, loaded.Token, loaded.Revision, loaded.LastLease
		state.Loaded = true; state.LoadThread = nil
		if loaded.Writable then self:_Publish(state, status('ready', 'Browser data is ready to save.', true))
		elseif loaded.Error == 'conflict' then self:_Publish(state, status('conflict', 'Another game session owns your saved browser data. Changes remain available here until you rejoin.', false))
		elseif loaded.Error == 'malformed' then self:_Publish(state, status('unavailable', 'Stored browser data could not be restored. This session remains usable; the stored copy has been preserved.', false))
		else self:_Publish(state, status('unavailable', 'Saving is unavailable. Your changes remain available for this session.', false)) end
		if state.Departed then if state.Writable then self:_Queue(state, true) else self.States[state.UserID] = nil end end
	end)
	return state
end
function Service:_Read(player, clientID)
	if not self.Schema.IsID(clientID) then return {Status = status('unavailable', 'The browser storage connection could not be opened.', false)} end
	if self.Stopping then return {Status = status('unavailable', 'This server is shutting down. Changes remain available for this session.', false)} end
	local state = self:_State(player)
	local now = os.clock()
	if now - state.ReadAt < 2 then return {Status = status('unavailable', 'Please allow the saved browser data to finish loading.', false)} end
	state.ReadAt = now
	local deadline = now + 15
	while not state.Loaded and os.clock() < deadline and not state.Departed do task.wait(0.1) end
	if not state.Loaded then return {Status = status('unavailable', 'Saved browser data is taking too long to load. Changes remain available for this session.', false)} end
	if state.ClientID ~= clientID then state.ClientID = clientID; state.LastSequence = 0 end
	return {Data = self.Schema.Clone(state.Data), Restored = state.Restored, Status = state.Status, Revision = state.Revision}
end
function Service:_Rate(state)
	local now = os.clock()
	state.RateTokens = math.min(5, state.RateTokens + (now - state.RateTime) / 2)
	state.RateTime = now
	if state.RateTokens < 1 then return false end
	state.RateTokens -= 1; return true
end
function Service:_Update(player, clientID, sequence, payload)
	if not self.Alive or self.Stopping then return end
	local state = self:_State(player)
	if state.Departed or not state.Loaded or clientID ~= state.ClientID or not validSequence(sequence) or sequence <= state.LastSequence or not self:_Rate(state) then return end
	local safe, message = self.Schema.Validate(payload)
	if not safe then self:_Publish(state, status('unavailable', message..' Current changes remain available locally.', false)); return end
	state.LastSequence = sequence; state.Data = safe; state.Dirty = true; state.Generation += 1
	if state.Writable then self:_Publish(state, status('saving', 'Saving browser changes.', true)); self:_Queue(state, false)
	else self:_Publish(state, state.Status) end
end
function Service:_Queue(state, immediate)
	if not state.Loaded or not state.Writable or state.Complete then return end
	if immediate then state.Immediate = true end
	state.Deadline = if state.Immediate or self.Stopping or state.Departed then os.clock() else math.min(os.clock() + 8, (state.FirstQueued or os.clock()) + 25)
	if not state.Immediate and not self.Stopping and not state.Departed then state.Deadline = math.max(state.Deadline, state.RetryAt or 0) end
	if state.Worker then return end
	state.FirstQueued = os.clock()
	state.Worker = task.defer(function()
		while state.Writable and not state.Complete do
			while os.clock() < (state.Deadline or 0) and not self.Stopping and not state.Departed do task.wait(math.min(0.25, math.max(0, state.Deadline - os.clock()))) end
			local generation, data = state.Generation, self.Schema.Clone(state.Data)
			local changed = state.Dirty
			local release = self.Stopping or state.Departed
			state.Writing = true
			local ok, reason = self.Store:Write(state.UserID, state, data, release, changed)
			state.Writing = false; state.Immediate = nil; state.FirstQueued = nil
			if not ok then
				if reason == 'conflict' then
					state.Writable = false
					self:_Publish(state, status('conflict', 'A newer game session owns your saved data. Local changes were not allowed to replace it.', false))
				else
					self:_Publish(state, status('unavailable', 'Saving is temporarily unavailable. Changes remain available for this session.', false))
					state.RetryAt = os.clock() + 30
				end
				if state.Departed or self.Stopping then state.Complete = true; state.Writable = false end
				break
			end
			state.RetryAt = nil
			if state.Generation == generation then state.Dirty = false end
			if release then state.Complete = true; state.Writable = false; break end
			if self.Stopping or state.Departed then state.Deadline = os.clock(); continue end
			if not state.Dirty then self:_Publish(state, status('saved', 'Browser changes are saved.', true)); break end
			state.FirstQueued = os.clock(); state.Deadline = os.clock() + 8
		end
		state.Worker = nil
		if state.Departed and (state.Complete or not state.Writable) then self.States[state.UserID] = nil end
	end)
end
function Service:_Depart(player)
	local state = self.States[player.UserId]
	if not state then return end
	state.Departed = true
	if state.Loaded then
		if state.Writable then self:_Queue(state, true) else self.States[player.UserId] = nil end
	end
end
function Service:Shutdown()
	if self.Stopping then return end
	self.Stopping = true
	for _, state in self.States do if state.Loaded and state.Writable then self:_Queue(state, true) end end
	local deadline = os.clock() + 25
	while os.clock() < deadline do
		local pending = false
		for _, state in self.States do if not state.Loaded or state.Worker or (state.Writable and not state.Complete) then pending = true; break end end
		if not pending then break end
		for _, state in self.States do if state.Loaded and state.Writable and not state.Worker then self:_Queue(state, true) end end
		task.wait(0.1)
	end
	self:Destroy()
end
function Service:Destroy()
	if not self.Alive then return end
	self.Alive = false
	self.LoadRemote.OnServerInvoke = nil
	for _, connection in self.Connections do connection:Disconnect() end
	table.clear(self.Connections)
	if self.Heartbeat and coroutine.status(self.Heartbeat) ~= 'dead' then pcall(task.cancel, self.Heartbeat) end
	for _, state in self.States do
		if state.Worker and coroutine.status(state.Worker) ~= 'dead' then pcall(task.cancel, state.Worker) end
		if state.LoadThread and coroutine.status(state.LoadThread) ~= 'dead' then pcall(task.cancel, state.LoadThread) end
	end
	table.clear(self.States)
end
return Service
