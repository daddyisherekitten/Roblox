--!strict
-- One document owns its navigation history; native resources stay opaque.
local Session = require(script.Parent.Session)
local Model = {}
Model.__index = Model
Model.StartURL = 'wayline://home'
function Model.new(home, clock, sharedData)
	local self = setmetatable({Alive = true, HomeURL = home or Model.StartURL, Tabs = {}, Active = nil, NextID = 0, Bookmarks = {}, BookmarkVersion = 0, Recent = {}, RecentVersion = 0, Clock = clock or os.clock, SharedData = sharedData}, Model)
	if sharedData then
		self.SharedConnection = sharedData.Changed:Connect(function(kind)
			if kind == 'Bookmarks' or kind == 'History' or kind == 'Replace' then self:_SyncShared() end
		end)
		self:_SyncShared()
	end
	return self
end
function Model:_SyncShared()
	table.clear(self.Bookmarks); table.clear(self.Recent)
	for _, item in self.SharedData.Bookmarks do
		if item.Kind == 'bookmark' then self.Bookmarks[item.Address] = {ID = item.ID, URL = item.Address, Address = item.Address, Title = item.Title, Parent = item.Parent, Order = item.Order, Icon = 'bookmark'} end
	end
	local seen = {}
	for _, item in self.SharedData.History do
		if not seen[item.Address] then seen[item.Address] = true; table.insert(self.Recent, {URL = item.Address, Address = item.Address, Title = item.Title, Time = item.Time}) end
		if #self.Recent >= 32 then break end
	end
	self.BookmarkVersion += 1; self.RecentVersion += 1
end
function Model:IsStartPage(url) return url == Model.StartURL or url == 'about:newtab' end
function Model:_Remember(tab, request, metadata)
	if request.Kind == 'reload' or request.Kind == 'restore' or request.Source == 'restore' or metadata.Error or tab.URL == 'about:blank' then return end
	if self.SharedData then self.SharedData:RecordVisit(tab.Title, tab.URL); return end
	for index, entry in self.Recent do if entry.URL == tab.URL then table.remove(self.Recent, index); break end end
	table.insert(self.Recent, 1, {URL = tab.URL, Title = tab.Title, Icon = tab.Icon})
	while #self.Recent > 32 do table.remove(self.Recent) end
	self.RecentVersion += 1
end
function Model:GetBookmarks()
	local list = {}
	for _, entry in self.Bookmarks do table.insert(list, entry) end
	table.sort(list, function(a, b) if (a.Order or 0) ~= (b.Order or 0) then return (a.Order or 0) < (b.Order or 0) end; return tostring(a.ID) < tostring(b.ID) end)
	return list
end
function Model:Contains(tab) return self.Alive and tab ~= nil and tab.Alive and table.find(self.Tabs, tab) ~= nil end
function Model:Open()
	if not self.Alive then return nil end
	if self.Tabs[1] then return self.Tabs[1] end
	self.NextID += 1
	local tab = {ID = self.NextID, Alive = true, URL = 'about:blank', Title = 'Untitled page', History = {}, HistoryIndex = 0, Generation = 0, Loading = false, OpenedAt = self.Clock()}
	table.insert(self.Tabs, tab); return tab
end
function Model:Select(tab)
	if not self:Contains(tab) then return false end
	self.Active = tab; return true
end
function Model:Close(tab)
	if not self:Contains(tab) then return false end
	local index = assert(table.find(self.Tabs, tab))
	tab.Alive = false; tab.Generation += 1; tab.Pending = nil; tab.Loading = false; tab.DeferredVisit = nil
	table.remove(self.Tabs, index)
	if self.Active == tab then self.Active = self.Tabs[math.min(index, #self.Tabs)] end
	table.clear(tab.History); return true
end
function Model:Request(tab, url, intent)
	if not self:Contains(tab) or type(url) ~= 'string' then return nil end
	url = url:match('^%s*(.-)%s*$') or ''
	if url == '' then url = Model.StartURL end
	intent = intent or {}; tab.Generation += 1
	local request = {ID = tab.Generation, URL = url, Kind = intent.Kind or 'assign', Source = intent.Source or 'host', TargetIndex = intent.TargetIndex, Entry = intent.Entry, Data = intent.Data}
	if (request.Kind == 'reload' or request.Kind == 'restore') and not request.Entry then request.Entry = tab.History[tab.HistoryIndex] end
	tab.Pending, tab.Loading, tab.Error, tab.ErrorDetails, tab.DeferredVisit = request, true, nil, nil, nil
	return request
end
function Model:IsCurrent(tab, request) return self:Contains(tab) and request ~= nil and tab.Pending == request and tab.Generation == request.ID end
function Model:Commit(tab, request, metadata)
	if not self:IsCurrent(tab, request) then return false end
	metadata = metadata or {}
	local url = metadata.URL or request.URL
	local entry = {URL = url, Title = metadata.Title or url, Icon = metadata.Icon, State = Session.Clone(metadata.State)}
	if request.Kind == 'traverse' then
		local index = request.TargetIndex
		if not index or not tab.History[index] then return false end
		if metadata.State == nil then entry.State = tab.History[index].State end
		tab.HistoryIndex = index; tab.History[index] = entry
	elseif (request.Kind == 'replace' or request.Kind == 'reload' or request.Kind == 'restore') and tab.HistoryIndex > 0 then
		if request.Kind == 'restore' and metadata.State == nil then entry.State = tab.History[tab.HistoryIndex].State end
		tab.History[tab.HistoryIndex] = entry
	else
		for index = #tab.History, tab.HistoryIndex + 1, -1 do tab.History[index] = nil end
		table.insert(tab.History, entry); tab.HistoryIndex = #tab.History
	end
	tab.URL, tab.Title, tab.Icon = url, entry.Title, metadata.Icon
	tab.Pending, tab.Loading, tab.Error, tab.ErrorDetails = nil, false, nil, nil
	tab.Restored = nil
	if metadata.Remember == false then
		tab.DeferredVisit = {Generation = request.ID, Entry = entry, Request = {Kind = request.Kind, Source = request.Source}, Error = metadata.Error}
	else self:_Remember(tab, request, metadata) end
	return true
end
function Model:Remember(tab, metadata)
	if not self:Contains(tab) then return false end
	local pending = tab.DeferredVisit
	if not pending or pending.Generation ~= tab.Generation or pending.Entry ~= tab.History[tab.HistoryIndex] then return false end
	tab.DeferredVisit = nil
	metadata = metadata or {}
	if pending.Error or metadata.Error then return false end
	self:_Remember(tab, pending.Request, metadata)
	return true
end
function Model:Fail(tab, request, message)
	if not self:IsCurrent(tab, request) then return false end
	tab.Pending, tab.Loading, tab.Error = nil, false, tostring(message)
	tab.ErrorDetails = if type(message) == 'table' then message else nil
	return true
end
function Model:Cancel(tab)
	if not self:Contains(tab) or not tab.Pending then return false end
	tab.Generation += 1; tab.Pending = nil; tab.Loading = false; tab.Error = nil; return true
end
function Model:CanBack(tab) return self:Contains(tab) and tab.HistoryIndex > 1 end
function Model:CanForward(tab) return self:Contains(tab) and tab.HistoryIndex < #tab.History end
function Model:Traversal(tab, delta)
	if not self:Contains(tab) then return nil end
	local index = tab.HistoryIndex + delta
	local entry = tab.History[index]
	if not entry then return nil end
	return self:Request(tab, entry.URL, {Kind = 'traverse', TargetIndex = index, Entry = entry, Source = 'toolbar'})
end
function Model:SetTitle(tab, title, icon)
	if not self:Contains(tab) then return false end
	tab.Title = if type(title) == 'string' and title ~= '' then title else tab.URL
	if icon ~= nil then tab.Icon = icon end
	local entry = tab.History[tab.HistoryIndex]
	if entry then entry.Title = tab.Title; entry.Icon = tab.Icon end
	for _, recent in self.Recent do if recent.URL == tab.URL then recent.Title = tab.Title; recent.Icon = tab.Icon; self.RecentVersion += 1; break end end
	return true
end
function Model:SetLocation(tab, url, kind)
	if not self:Contains(tab) or tab.Pending then return false end
	if kind == 'traverse' then
		for index = tab.HistoryIndex - 1, 1, -1 do if tab.History[index].URL == url then tab.HistoryIndex = index; tab.URL = url; return true end end
		for index = tab.HistoryIndex + 1, #tab.History do if tab.History[index].URL == url then tab.HistoryIndex = index; tab.URL = url; return true end end
	end
	local request = self:Request(tab, url, {Kind = if kind == 'replaceState' or kind == 'replace' or kind == 'commit' then 'replace' else 'assign'})
	return self:Commit(tab, request, {URL = url, Title = tab.Title, Icon = tab.Icon})
end
function Model:ToggleBookmark(tab)
	if not self:Contains(tab) or tab.URL == 'about:blank' then return false end
	if self.SharedData then
		local existing = self.SharedData:FindBookmark(tab.URL)
		if existing then return self.SharedData:DeleteItem(existing.ID) end
		return self.SharedData:AddBookmark(tab.Title, tab.URL)
	end
	if self.Bookmarks[tab.URL] then self.Bookmarks[tab.URL] = nil else
		self.BookmarkVersion += 1; self.Bookmarks[tab.URL] = {URL = tab.URL, Title = tab.Title, Icon = tab.Icon, ID = self.BookmarkVersion}
	end
	self.BookmarkVersion += 1; return true
end
function Model:ExportSession() return Session.Export(self) end
function Model:ExportServerSession() return Session.ExportServer(self) end
function Model:ImportSession(snapshot, serverOnly) return Session.Import(self, snapshot, serverOnly) end
function Model:Destroy()
	if not self.Alive then return end
	if self.SharedConnection then self.SharedConnection:Disconnect(); self.SharedConnection = nil end
	for _, tab in table.clone(self.Tabs) do self:Close(tab, false) end
	self.Alive = false; self.Active = nil
	table.clear(self.Bookmarks); table.clear(self.Recent)
end
return Model
