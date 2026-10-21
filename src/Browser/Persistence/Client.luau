--!strict
-- Optional client transport. Page rendering never waits for a DataStore operation.
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local HttpService = game:GetService('HttpService')
local Signal = require(script.Parent.Parent.Signal)
local Schema = require(script.Parent.Schema)
local Client = {}
Client.__index = Client
local function equalRecord(left, right)
	if not left or not right then return left == right end
	for key, value in left do if right[key] ~= value then return false end end
	for key, value in right do if left[key] ~= value then return false end end
	return true
end
local function reconcileLinks(saved, current, original)
	local baseline, live, merged = {}, {}, {}
	for _, item in original do baseline[item.ID] = item end
	for _, item in current do live[item.ID] = item end
	for _, item in saved do if not baseline[item.ID] or live[item.ID] then table.insert(merged, item) end end
	for _, item in current do
		if not equalRecord(item, baseline[item.ID]) then
			local index
			for position, entry in merged do if entry.ID == item.ID then index = position; break end end
			if index then merged[index] = item else table.insert(merged, item) end
		end
	end
	local changedOrder = false
	for index, item in current do if original[index] and original[index].ID ~= item.ID then changedOrder = true; break end end
	if changedOrder then
		local ranks = {}
		for index, item in current do ranks[item.ID] = index end
		local storedOrder = {}
		for index, item in merged do storedOrder[item.ID] = index end
		table.sort(merged, function(a, b)
			local left, right = ranks[a.ID], ranks[b.ID]
			if left and right then return left < right end
			if left then return true end
			if right then return false end
			return storedOrder[a.ID] < storedOrder[b.ID]
		end)
	end
	return merged
end
local function reconcileBookmarks(saved, current, original)
	local merged = Schema.Clone(saved)
	local function remove(id)
		for childID, item in table.clone(merged) do if item.Parent == id then remove(childID) end end
		merged[id] = nil
	end
	for id in original do if not current[id] then remove(id) end end
	for id, item in current do
		if not equalRecord(item, original[id]) then
			if item.Kind == 'bookmark' then
				for previousID, previous in merged do if previousID ~= id and previous.Kind == 'bookmark' and previous.Address == item.Address then merged[previousID] = nil end end
			end
			merged[id] = Schema.Clone(item)
		end
	end
	return merged
end
local function reconcileHistory(saved, current, original, cleared)
	if cleared then return current end
	local baseline, live, seen, merged = {}, {}, {}, {}
	for _, item in original do baseline[item.ID] = true end
	for _, item in current do live[item.ID] = true end
	for _, item in current do if not baseline[item.ID] then seen[item.ID] = true; table.insert(merged, item) end end
	for _, item in saved do
		if not seen[item.ID] and (not baseline[item.ID] or live[item.ID]) then seen[item.ID] = true; table.insert(merged, item) end
		if #merged >= 500 then break end
	end
	while #merged > 500 do table.remove(merged) end
	return merged
end
local function status(state, message, available)
	return {State = state, Message = message, Available = available == true}
end
function Client.new(options)
	options = options or {}
	local self = setmetatable({Alive = true, Loaded = false, ClientID = HttpService:GenerateGUID(false), Status = status('loading', 'Loading your saved browser data.', false), Changed = Signal.new(), Attachments = {}, SharedBindings = setmetatable({}, {__mode = 'k'}), SeenShared = setmetatable({}, {__mode = 'k'}), DataGeneration = 0, Threads = {}, Connections = {}, Dirty = {Settings = {}, Home = {}}, Session = Schema.DefaultSession(), Options = options, Sequence = 0, Replacing = false}, Client)
	self:_Start()
	return self
end
function Client:_Spawn(callback)
	local thread
	thread = task.defer(function()
		local ok, message = pcall(function() if self.Alive then callback() end end)
		self.Threads[thread] = nil
		if not ok and self.Alive then warn('Wayline persistence: '..tostring(message)) end
	end)
	self.Threads[thread] = true
	return thread
end
function Client:_Status(value)
	if not self.Alive or type(value) ~= 'table' then return end
	if value.State == 'saved' and (self.PendingShared or self.SessionDirty) then value = status('saving', 'Saving browser changes.', value.Available) end
	self.Status = status(value.State or 'unavailable', value.Message or 'Changes are available for this session.', value.Available)
	self.Changed:Fire(self.Status)
end
function Client:_MergeLoaded(shared)
	local attachment = self.Attachments[1]
	local current = if attachment then attachment.Shared:Export() else self.PendingShared
	local original = self.InitialShared or Schema.DefaultShared()
	if current and not self.Dirty.All then
		for key in self.Dirty.Settings do shared.Settings[key] = current.Settings[key] end
		for key in self.Dirty.Home do shared.Home[key] = current.Home[key] end
		if self.Dirty.QuickLinks then shared.Home.QuickLinks = reconcileLinks(shared.Home.QuickLinks, current.Home.QuickLinks, original.Home.QuickLinks) end
		if self.Dirty.Bookmarks then shared.Bookmarks = reconcileBookmarks(shared.Bookmarks, current.Bookmarks, original.Bookmarks) end
		if self.Dirty.History then shared.History = reconcileHistory(shared.History, current.History, original.History, self.Dirty.HistoryCleared) end
	elseif current and self.Dirty.All then shared = current end
	local valid, validationMessage = Schema.ValidateShared(shared)
	if not valid then
		self.MergeError = validationMessage
		self.UpdateRemote = nil; self.TransportDisabled = true
		shared = current or original
	end
	self.DataGeneration += 1
	self.Replacing = true
	for target in self.SharedBindings do if target.Alive then target:Replace(shared); self.SeenShared[target] = self.DataGeneration end end
	self.Replacing = false
	self.SharedSnapshot = Schema.Clone(shared)
	if self.PendingShared then self.PendingShared = Schema.Clone(shared) end
end
function Client:_Accept(response)
	if not self.Alive or self.Loaded then return end
	local safe = if type(response) == 'table' then Schema.Migrate(response.Data) else nil
	if not safe then safe = Schema.DefaultData() end
	if type(response) ~= 'table' or response.Restored == false or (response.Restored == nil and (not response.Status or not response.Status.Available)) then
		local current = if self.Attachments[1] then self.Attachments[1].Shared:Export() else self.PendingShared or self.InitialShared
		if current then safe.Shared = current end
	end
	self:_MergeLoaded(safe.Shared)
	if not self.SessionDirty then self.Session = safe.Session end
	self.Loaded = true
	if self.MergeError then self:_Status(status('unavailable', 'Saved and local browser changes could not be combined within the collection limits. This session remains usable and the stored copy has been preserved.', false))
	else self:_Status(if type(response) == 'table' and type(response.Status) == 'table' then response.Status else status('unavailable', 'Your changes are available for this session, but saved data could not be loaded.', false)) end
	for _, item in table.clone(self.Attachments) do
		if item.Active and item.OnSession then
			local ok, message = pcall(item.OnSession, Schema.Clone(safe.Session))
			if not ok then warn('Wayline session restore: '..tostring(message)) end
		end
	end
	if self.PendingShared or self.SessionDirty then self:_Schedule() end
end
function Client:_Start()
	self:_Spawn(function()
		local storage = self.Options.ReplicatedStorage or ReplicatedStorage
		local folder = storage:WaitForChild(self.Options.RemoteName or 'WaylinePersistence', 12)
		if not self.Alive then return end
		local load = if folder then folder:WaitForChild('Load', 3) else nil
		local update = if folder then folder:WaitForChild('Update', 3) else nil
		local changed = if folder then folder:WaitForChild('Status', 3) else nil
		if not load or not load:IsA('RemoteFunction') or not update or not update:IsA('RemoteEvent') or not changed or not changed:IsA('RemoteEvent') then
			self:_Accept({Status = status('unavailable', 'Saving is unavailable. Changes remain available for this session.', false), Data = Schema.DefaultData()})
			return
		end
		self.UpdateRemote = update
		table.insert(self.Connections, changed.OnClientEvent:Connect(function(value)
			if self.Alive and self.Loaded and not self.TransportDisabled then self:_Status(value) end
		end))
		local finished = false
		self:_Spawn(function()
			task.wait(20)
			if not finished and self.Alive then self.UpdateRemote = nil; self.TransportDisabled = true; self:_Accept({Status = status('unavailable', 'Saved data is taking too long to load. Your changes remain available for this session.', false), Data = Schema.DefaultData()}) end
		end)
		local ok, response = pcall(load.InvokeServer, load, self.ClientID)
		finished = true
		if not self.Alive then return end
		if ok then
			if type(response) ~= 'table' or not response.Data then self.UpdateRemote = nil; self.TransportDisabled = true end
			self:_Accept(response)
		else self.UpdateRemote = nil; self.TransportDisabled = true; self:_Accept({Status = status('unavailable', 'Saving is unavailable. Changes remain available for this session.', false), Data = Schema.DefaultData()}) end
	end)
end
function Client:Attach(shared, onSessionLoaded)
	assert(self.Alive, 'Persistence service is closed')
	local item = {Shared = shared, OnSession = onSessionLoaded, Active = true}
	if not self.InitialShared then self.InitialShared = shared:Export() end
	local binding = self.SharedBindings[shared]
	if not binding then
		if self.SeenShared[shared] ~= self.DataGeneration then
			if self.SharedSnapshot then
				self.Replacing = true; shared:Replace(self.SharedSnapshot); self.Replacing = false
			elseif #self.Attachments > 0 then
				self.Replacing = true; shared:Replace(self.Attachments[1].Shared:Export()); self.Replacing = false
			end
		end
		self.SeenShared[shared] = self.DataGeneration
		binding = {References = 0}
		binding.Connection = shared.Changed:Connect(function(kind, field)
			if not self.Alive or self.Replacing then return end
			if kind == 'Settings' then self.Dirty.Settings[field] = true
			elseif kind == 'Home' then self.Dirty.Home[field] = true
			elseif kind == 'Replace' then self.Dirty.All = true
			else self.Dirty[kind] = true; if kind == 'History' and field == 'clear' then self.Dirty.HistoryCleared = true end end
			local snapshot = shared:Export()
			self.SharedSnapshot = snapshot; self.DataGeneration += 1; self.SeenShared[shared] = self.DataGeneration
			self.Replacing = true
			for target in self.SharedBindings do
				if target ~= shared and target.Alive then target:Replace(snapshot); self.SeenShared[target] = self.DataGeneration end
			end
			self.Replacing = false
			self:Update(snapshot)
		end)
		self.SharedBindings[shared] = binding
	end
	binding.References += 1
	table.insert(self.Attachments, item)
	if self.Loaded and onSessionLoaded then self:_Spawn(function() if item.Active then onSessionLoaded(Schema.Clone(self.Session)) end end) end
	return function()
		if not item.Active then return end
		item.Active = false; item.OnSession = nil
		binding.References -= 1
		if binding.References == 0 then binding.Connection:Disconnect(); self.SharedBindings[shared] = nil end
		local index = table.find(self.Attachments, item)
		if index then table.remove(self.Attachments, index) end
	end
end
function Client:_Schedule()
	if not self.Alive or not self.Loaded or self.SendThread then return end
	local thread
	thread = task.defer(function()
		task.wait(1.5)
		self.Threads[thread] = nil
		self.SendThread = nil
		if self.Alive then self:Flush() end
	end)
	self.SendThread = thread; self.Threads[thread] = true
end
function Client:Update(sharedSnapshot, serverSession)
	if not self.Alive then return false end
	if sharedSnapshot then
		local safe, message = Schema.ValidateShared(sharedSnapshot)
		if not safe then return false, message end
		self.PendingShared = safe; self.SharedSnapshot = safe
		if not self.Loaded and #self.Attachments == 0 then self.Dirty.All = true end
	end
	if serverSession then
		local safe, message = Schema.ValidateSession(serverSession)
		if not safe then return false, message end
		self.Session = safe; self.SessionDirty = true
	end
	if self.Loaded and self.Status.Available and (self.PendingShared or self.SessionDirty) then self:_Status(status('saving', 'Saving browser changes.', true)) end
	self:_Schedule(); return true
end
function Client:Flush()
	if not self.Alive or not self.Loaded then return false end
	if self.SendThread then pcall(task.cancel, self.SendThread); self.Threads[self.SendThread] = nil; self.SendThread = nil end
	local shared = self.PendingShared or self.SharedSnapshot
	if not shared or (not self.PendingShared and not self.SessionDirty) then return true end
	local data, message = Schema.Validate({Version = Schema.Version, Shared = shared, Session = self.Session})
	if not data then self:_Status(status('unavailable', message..' Your current browser remains usable.', false)); return false, message end
	if not self.UpdateRemote then return false end
	self.Sequence += 1
	local ok = pcall(self.UpdateRemote.FireServer, self.UpdateRemote, self.ClientID, self.Sequence, data)
	if not ok then self:_Status(status('unavailable', 'Saving is unavailable. Changes remain available for this session.', false)); return false end
	self.PendingShared = nil; self.SessionDirty = false
	if self.Status.Available then self:_Status(status('saving', 'Saving browser changes.', true)) end
	return true
end
function Client:Destroy()
	if not self.Alive then return end
	self:Flush(); self.Alive = false
	for _, item in self.Attachments do item.Active = false; item.OnSession = nil end
	for _, binding in self.SharedBindings do binding.Connection:Disconnect() end
	for _, connection in self.Connections do connection:Disconnect() end
	for thread in self.Threads do if coroutine.status(thread) ~= 'dead' then pcall(task.cancel, thread) end end
	table.clear(self.Threads); table.clear(self.Attachments); table.clear(self.Connections); table.clear(self.SharedBindings); table.clear(self.SeenShared)
	self.Changed:Destroy(); self.UpdateRemote = nil
end
return Client
