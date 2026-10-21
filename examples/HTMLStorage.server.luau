--!strict
-- Persistent Web Storage host for the HTML demo. All identity and origin
-- decisions are server-owned; JavaScript never invokes DataStoreService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- This bootstrap can remain in a combined place after its optional owner is
-- removed. The server's place tree is already available; do not await a root.
local engine = ReplicatedStorage:FindFirstChild("HTMLEngine")
if not engine then return end
assert(engine:IsA("ModuleScript"), "HTMLEngine must be a ModuleScript in ReplicatedStorage.")
local storage = engine:FindFirstChild("Storage")
assert(storage and storage:IsA("Folder"), "HTMLEngine.Storage is missing or invalid.")
local protocolModule,serverModule = storage:FindFirstChild("Protocol"),storage:FindFirstChild("Server")
local websitesModule = engine:FindFirstChild("Websites")
assert(protocolModule and protocolModule:IsA("ModuleScript"), "HTMLEngine.Storage.Protocol is missing or invalid.")
assert(serverModule and serverModule:IsA("ModuleScript"), "HTMLEngine.Storage.Server is missing or invalid.")
assert(websitesModule and websitesModule:IsA("ModuleScript"), "HTMLEngine.Websites is missing or invalid.")
local Protocol = require(protocolModule)
local Server = require(serverModule)
local Websites = require(websitesModule)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local allowed = {}
for _, name in Websites.names() do
	local origin = Protocol.origin(Websites.url(name))
	assert(origin, "Website has no supported storage origin: " .. name)
	allowed[origin] = true
end

local function remote(parent: Instance, name: string, className: string): any
	local object = parent:FindFirstChild(name)
	if object then assert(object:IsA(className), "Invalid HTML storage remote " .. name); return object end
	object = Instance.new(className); object.Name = name; object.Parent = parent
	return object
end

local folder = remote(ReplicatedStorage, "HTMLStorage", "Folder")
local loadRemote = remote(folder, "Load", "RemoteFunction")
local changesRemote = remote(folder, "Changes", "RemoteEvent")
local store = DataStoreService:GetDataStore("HTMLWebStorage_v1" .. (if RunService:IsStudio() then "_Studio" else ""))
local getOptions = Instance.new("DataStoreGetOptions")
getOptions.UseCache = false
local scheduled, departing = {}, {}
local closing = false
local server

local function current(state: any): boolean
	local player = server.Players[state.UserId]
	return player ~= nil and player.States[state.Origin] == state
end

local function disposeDeparted(userId: number)
	local departure = departing[userId]
	if not departure or Players:GetPlayerByUserId(userId) then return end
	local destroyed = server:DestroyPlayer(userId, function()
		return departing[userId] == departure and Players:GetPlayerByUserId(userId) == nil
	end)
	if destroyed and departing[userId] == departure then departing[userId] = nil end
end

local function schedule(state: any)
	if closing or not current(state) then return end
	local key = Protocol.key(state.UserId, state.Origin)
	if scheduled[key] and scheduled[key].State == state then return end
	local token = {State = state}
	scheduled[key] = token
	local attempt = state.SaveAttempts or 0
	local delaySeconds = if attempt == 0 then 0.75 else math.min(30, 2 ^ math.min(attempt, 5))
	task.delay(delaySeconds, function()
		if scheduled[key] ~= token then return end
		scheduled[key] = nil
		if closing or not current(state) then return end
		local success = server:Flush(state.UserId, state.Origin)
		if not current(state) then return end
		state.SaveAttempts = if success then nil else attempt + 1
		if server:Pending(state.UserId, state.Origin) then schedule(state)
		elseif success then disposeDeparted(state.UserId) end
	end)
end

server = Server.new({
	AllowedOrigins = allowed,
	Store = {
		GetAsync = function(_, key) return store:GetAsync(key, getOptions) end,
		UpdateAsync = function(_, key, transform) return store:UpdateAsync(key, transform) end,
	},
	OnDirty = schedule,
	OnSaved = function(userId, origin, clientId, sequence)
		local player = Players:GetPlayerByUserId(userId)
		if player then changesRemote:FireClient(player, {Ok = true, Origin = origin, ClientId = clientId, Sequence = sequence, Status = "saved"}) end
	end,
	OnError = function(userId, origin, message)
		warn("HTML storage [" .. tostring(userId) .. ", " .. origin .. "]: " .. message)
		local player, state = Players:GetPlayerByUserId(userId), server:_state(userId, origin)
		if player and state then
			for _, batch in state.Pending do
				changesRemote:FireClient(player, {Ok = false, Origin = origin, ClientId = batch.ClientId, Sequence = batch.Sequence, Error = message})
			end
		end
	end,
})

loadRemote.OnServerInvoke = function(player, origin)
	if closing or departing[player.UserId] or Players:GetPlayerByUserId(player.UserId) ~= player then return {Ok = false, Error = "Storage session is closed"} end
	return server:Load(player.UserId, origin)
end

changesRemote.OnServerEvent:Connect(function(player, packet)
	if closing or departing[player.UserId] or Players:GetPlayerByUserId(player.UserId) ~= player then return end
	changesRemote:FireClient(player, server:Accept(player.UserId, packet))
end)

Players.PlayerAdded:Connect(function(player) departing[player.UserId] = nil end)

Players.PlayerRemoving:Connect(function(player)
	local departure = {}
	departing[player.UserId] = departure
	-- Retain failed deltas while retries run. Never replace unavailable durable
	-- storage with an empty record or discard the queue after the first error.
	local deadline = os.clock() + 25
	local function stillDeparting()
		local active = Players:GetPlayerByUserId(player.UserId)
		return departing[player.UserId] == departure and (active == nil or active == player)
	end
	while os.clock() < deadline and stillDeparting() do
		if server:DestroyPlayer(player.UserId, stillDeparting) then
			if departing[player.UserId] == departure then departing[player.UserId] = nil end
			return
		end
		task.wait(1)
	end
	if stillDeparting() then warn("HTML storage: unsaved changes retained after player departure " .. tostring(player.UserId)) end
end)

game:BindToClose(function()
	closing = true
	local deadline, waiting = os.clock() + 27, 0
	local users = {}
	for userId in server.Players do table.insert(users, userId) end
	for _, userId in users do
		waiting += 1
		task.spawn(function()
			while os.clock() < deadline do
				if server:DestroyPlayer(userId) then break end
				task.wait(1)
			end
			waiting -= 1
		end)
	end
	while waiting > 0 and os.clock() < deadline do task.wait(0.1) end
	for userId, player in server.Players do
		for origin, state in player.States do
			if #state.Pending > 0 then warn("HTML storage shutdown: unsaved changes for " .. tostring(userId) .. ", " .. origin) end
		end
	end
end)
