--!strict
-- Serializable shared data, independent of page instances and native input.
local Signal = require(script.Parent.Signal)
local Schema = require(script.Parent.Persistence.Schema)
local HttpService = game:GetService('HttpService')
local SharedData = {}
SharedData.__index = SharedData
SharedData.Backgrounds = Schema.Backgrounds
local function cleanTitle(value)
	if type(value) ~= 'string' then return nil end
	value = value:match('^%s*(.-)%s*$') or ''
	return Schema.Text(value, false)
end
function SharedData.new(initial, options)
	options = options or {}
	local safe = if initial then Schema.ValidateShared(initial) else nil
	safe = safe or Schema.DefaultShared()
	local self = setmetatable({Alive = true, Settings = safe.Settings, Home = safe.Home, Bookmarks = safe.Bookmarks, History = safe.History, Changed = Signal.new(), Counter = 0, NormalizeAddress = options.NormalizeAddress, Clock = options.Clock or os.time}, SharedData)
	return self
end
function SharedData:_ID(prefix)
	while true do
		self.Counter += 1
		local id = prefix..'_'..HttpService:GenerateGUID(false)
		local exists = self.Bookmarks[id] ~= nil
		for _, item in self.Home.QuickLinks do if item.ID == id then exists = true end end
		for _, item in self.History do if item.ID == id then exists = true end end
		if not exists then return id end
	end
end
function SharedData:_Address(value)
	if self.NormalizeAddress then
		local ok, result, message = pcall(self.NormalizeAddress, value)
		if not ok or not result then return nil, message or 'Enter a valid internal or host-registered address.' end
		if type(result) == 'table' then
			if result.Kind == 'error' then return nil, result.Error end
			result = result.URL or result.Address
		end
		value = result
	end
	local canonical = Schema.CanonicalAddress(value)
	if not canonical then return nil, 'Addresses must be valid and contain at most 512 characters.' end
	return canonical
end
function SharedData:_Change(kind, field)
	if self.Alive then self.Changed:Fire(kind, field) end
end
function SharedData:SetSetting(key, value)
	if not self.Alive then return false, 'Browser data is closed.' end
	if key == 'Theme' and not table.find({'Light', 'Dark'}, value) then return false, 'Choose Light or Dark.' end
	if key == 'Accent' and not table.find({'Blue', 'Purple', 'Green'}, value) then return false, 'Choose Blue, Purple, or Green.' end
	if key == 'BookmarksBar' and type(value) ~= 'boolean' then return false, 'Bookmarks-bar visibility must be a boolean.' end
	if key ~= 'Theme' and key ~= 'Accent' and key ~= 'BookmarksBar' then return false, 'Unknown setting.' end
	if self.Settings[key] ~= value then self.Settings[key] = value; self:_Change('Settings', key) end
	return true
end
function SharedData:SetGreeting(value)
	if not Schema.Text(value, true) then return false, 'The greeting may contain at most 120 characters.' end
	if self.Home.Greeting ~= value then self.Home.Greeting = value; self:_Change('Home', 'Greeting') end
	return true
end
function SharedData:SetBackground(value)
	if not table.find(Schema.Backgrounds, value) then return false, 'Choose one of the available Home backgrounds.' end
	if self.Home.Background ~= value then self.Home.Background = value; self:_Change('Home', 'Background') end
	return true
end
function SharedData:AddQuickLink(title, address)
	if #self.Home.QuickLinks >= 12 then return false, 'Home supports up to 12 quick links.' end
	title = cleanTitle(title)
	if not title then return false, 'Enter a title of 1 to 120 characters.' end
	local canonical, message = self:_Address(address)
	if not canonical then return false, message end
	local item = {ID = self:_ID('quick'), Title = title, Address = canonical}
	table.insert(self.Home.QuickLinks, item); self:_Change('QuickLinks'); return item
end
function SharedData:EditQuickLink(id, title, address)
	title = cleanTitle(title)
	if not title then return false, 'Enter a title of 1 to 120 characters.' end
	local canonical, message = self:_Address(address)
	if not canonical then return false, message end
	for _, item in self.Home.QuickLinks do if item.ID == id then item.Title = title; item.Address = canonical; self:_Change('QuickLinks'); return item end end
	return false, 'This quick link no longer exists.'
end
function SharedData:RemoveQuickLink(id)
	for index, item in self.Home.QuickLinks do if item.ID == id then table.remove(self.Home.QuickLinks, index); self:_Change('QuickLinks'); return true end end
	return false, 'This quick link no longer exists.'
end
function SharedData:MoveQuickLink(id, index)
	if type(index) ~= 'number' or index ~= index then return false, 'Choose a valid quick-link position.' end
	for old, item in self.Home.QuickLinks do if item.ID == id then
		index = math.clamp(math.floor(index), 1, #self.Home.QuickLinks)
		if old ~= index then table.remove(self.Home.QuickLinks, old); table.insert(self.Home.QuickLinks, index, item); self:_Change('QuickLinks') end
		return true
	end end
	return false, 'This quick link no longer exists.'
end
function SharedData:GetChildren(parent)
	parent = parent or 'root'
	local result = {}
	for _, item in self.Bookmarks do if item.Parent == parent then table.insert(result, item) end end
	table.sort(result, function(a, b) if a.Order ~= b.Order then return a.Order < b.Order end; return a.ID < b.ID end)
	return result
end
function SharedData:FindBookmark(address)
	address = Schema.CanonicalAddress(address) or self:_Address(address)
	if not address then return nil end
	for _, item in self.Bookmarks do if item.Kind == 'bookmark' and item.Address == address then return item end end
	return nil
end
function SharedData:_Parent(parent)
	parent = parent or 'root'
	if parent == 'root' then return parent, 0 end
	local record, depth, seen = self.Bookmarks[parent], 0, {}
	if not record or record.Kind ~= 'folder' then return nil, 'The destination folder no longer exists.' end
	while record do
		if seen[record.ID] then return nil, 'Invalid folder structure.' end
		seen[record.ID] = true; depth += 1
		if record.Parent == 'root' then break end
		record = self.Bookmarks[record.Parent]
	end
	return parent, depth
end
function SharedData:_Renumber(parent)
	for index, item in self:GetChildren(parent) do item.Order = index end
end
function SharedData:AddBookmark(title, address, parent)
	title = cleanTitle(title)
	if not title then return false, 'Enter a title of 1 to 120 characters.' end
	local canonical, message = self:_Address(address)
	if not canonical then return false, message end
	local existing = self:FindBookmark(canonical)
	if existing then return existing, true, 'existing' end
	local destination, parentError = self:_Parent(parent)
	if not destination then return false, parentError end
	local count = 0
	for _, item in self.Bookmarks do if item.Kind == 'bookmark' then count += 1 end end
	if count >= 300 then return false, 'The browser supports up to 300 bookmarks.' end
	local item = {ID = self:_ID('bookmark'), Kind = 'bookmark', Title = title, Address = canonical, Parent = destination, Order = #self:GetChildren(destination) + 1}
	self.Bookmarks[item.ID] = item; self:_Change('Bookmarks'); return item
end
function SharedData:AddFolder(title, parent)
	title = cleanTitle(title)
	if not title then return false, 'Enter a title of 1 to 120 characters.' end
	local destination, depth = self:_Parent(parent)
	if not destination then return false, depth end
	if depth >= 5 then return false, 'Folders may be nested at most five levels deep.' end
	local count = 0
	for _, item in self.Bookmarks do if item.Kind == 'folder' then count += 1 end end
	if count >= 50 then return false, 'The browser supports up to 50 folders.' end
	local item = {ID = self:_ID('folder'), Kind = 'folder', Title = title, Parent = destination, Order = #self:GetChildren(destination) + 1}
	self.Bookmarks[item.ID] = item; self:_Change('Bookmarks'); return item
end
function SharedData:EditItem(id, title, address)
	local item = self.Bookmarks[id]
	if not item then return false, 'This item no longer exists.' end
	title = cleanTitle(title)
	if not title then return false, 'Enter a title of 1 to 120 characters.' end
	if item.Kind == 'bookmark' then
		local canonical, message = self:_Address(address or item.Address)
		if not canonical then return false, message end
		local existing = self:FindBookmark(canonical)
		if existing and existing ~= item then return false, 'That address is already bookmarked. Open or move the existing bookmark instead.' end
		item.Address = canonical
	end
	item.Title = title; self:_Change('Bookmarks'); return item
end
function SharedData:DeleteItem(id)
	local item = self.Bookmarks[id]
	if not item then return false, 'This item no longer exists.' end
	local function remove(record)
		for _, child in self:GetChildren(record.ID) do remove(child) end
		self.Bookmarks[record.ID] = nil
	end
	remove(item); self:_Renumber(item.Parent); self:_Change('Bookmarks'); return true
end
function SharedData:MoveItem(id, parent, index)
	local item = self.Bookmarks[id]
	if not item then return false, 'This item no longer exists.' end
	local destination, depth = self:_Parent(parent)
	if not destination then return false, depth end
	if item.Kind == 'folder' then
		local record = self.Bookmarks[destination]
		while record do if record.ID == item.ID then return false, 'A folder cannot be moved into itself or its descendants.' end; record = self.Bookmarks[record.Parent] end
		local function height(record)
			local max = 1
			for _, child in self:GetChildren(record.ID) do if child.Kind == 'folder' then max = math.max(max, 1 + height(child)) end end
			return max
		end
		if depth + height(item) > 5 then return false, 'That move would exceed the five-level folder limit.' end
	end
	if index ~= nil and (type(index) ~= 'number' or index ~= index) then return false, 'Choose a valid position.' end
	local previous = item.Parent
	local children = self:GetChildren(destination)
	local old = table.find(children, item)
	if old then table.remove(children, old) end
	index = math.clamp(math.floor(index or (#children + 1)), 1, #children + 1)
	table.insert(children, index, item); item.Parent = destination
	for order, child in children do child.Order = order end
	if previous ~= destination then self:_Renumber(previous) end
	self:_Change('Bookmarks'); return item
end
function SharedData:SortFolder(parent, direction)
	local destination, message = self:_Parent(parent)
	if not destination then return false, message end
	if direction ~= 'asc' and direction ~= 'desc' and direction ~= 'AZ' and direction ~= 'ZA' then return false, 'Choose title A-Z or Z-A.' end
	local children = self:GetChildren(destination)
	local reverse = direction == 'desc' or direction == 'ZA'
	table.sort(children, function(a, b)
		local left, right = a.Title:lower(), b.Title:lower()
		if left == right then return a.ID < b.ID end
		return if reverse then left > right else left < right
	end)
	for order, child in children do child.Order = order end
	self:_Change('Bookmarks'); return true
end
function SharedData:RecordVisit(title, address, time)
	local canonical = self:_Address(address)
	if not canonical then return false, 'The visit address is invalid.' end
	title = cleanTitle(title) or canonical
	if not Schema.Text(title, false) then title = 'Page' end
	time = math.max(0, math.floor(time or self.Clock()))
	local item = {ID = self:_ID('visit'), Title = title, Address = canonical, Time = time}
	table.insert(self.History, 1, item)
	while #self.History > 500 do table.remove(self.History) end
	self:_Change('History', 'add'); return item
end
function SharedData:DeleteHistory(id)
	for index, item in self.History do if item.ID == id then table.remove(self.History, index); self:_Change('History', 'delete'); return true end end
	return false, 'This visit no longer exists.'
end
function SharedData:ClearHistory()
	table.clear(self.History); self:_Change('History', 'clear')
	return true
end
function SharedData:Export()
	return Schema.Clone({Settings = self.Settings, Home = self.Home, Bookmarks = self.Bookmarks, History = self.History})
end
function SharedData:Replace(snapshot)
	local safe, message = Schema.ValidateShared(snapshot)
	if not safe then return false, message end
	self.Settings, self.Home, self.Bookmarks, self.History = safe.Settings, safe.Home, safe.Bookmarks, safe.History
	self:_Change('Replace'); return true
end
function SharedData:Destroy()
	if not self.Alive then return end
	self.Alive = false; self.Changed:Destroy()
end
return SharedData
