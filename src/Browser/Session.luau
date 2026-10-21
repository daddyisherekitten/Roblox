--!strict
-- A browser snapshot owns one document and its navigation stack, never native resources.
local Schema = require(script.Parent.Persistence.Schema)
local Session = {}
local function clone(value, depth, seen)
	local kind = type(value)
	if kind == 'string' or kind == 'boolean' then return value end
	if kind == 'number' then return if value == value and math.abs(value) < math.huge then value else nil end
	if kind ~= 'table' or depth > 24 or seen[value] or getmetatable(value) ~= nil then return nil end
	seen[value] = true
	local copy = {}
	for key, item in value do
		if type(key) == 'string' or (type(key) == 'number' and key % 1 == 0 and key >= 1) then copy[key] = clone(item, depth + 1, seen) end
	end
	seen[value] = nil
	return copy
end
function Session.Clone(value) return clone(value, 0, {}) end
function Session.Page(page)
	local history = {}
	for _, entry in page.History do table.insert(history, {URL = entry.URL, Title = entry.Title, Icon = if type(entry.Icon) == 'string' then entry.Icon else nil, State = Session.Clone(entry.State)}) end
	local pending = page.HistoryIndex == 0 and page.Pending
	local address = if pending then pending.URL else page.URL
	local title = if pending and (page.Title == nil or page.Title == 'Untitled page' or page.Title == 'New tab') then address else page.Title
	return {URL = address, Title = title, Icon = if type(page.Icon) == 'string' then page.Icon else nil, History = history, HistoryIndex = page.HistoryIndex}
end
local function current(model) return model.Active or model.Tabs[1] end
function Session.Export(model)
	local page = current(model)
	return {Version = 2, Page = if page then Session.Page(page) else {URL = model.HomeURL, Title = model.HomeURL, History = {}, HistoryIndex = 0}}
end
function Session.ExportServer(model)
	local page = current(model)
	local address = if page then (if page.HistoryIndex == 0 and page.Pending then page.Pending.URL else page.URL) else model.HomeURL
	return {Page = {Address = address}}
end
local function dense(value, limit)
	if type(value) ~= 'table' or getmetatable(value) ~= nil or (limit and #value > limit) then return false end
	local count = 0
	for key in value do if type(key) ~= 'number' or key % 1 ~= 0 or key < 1 or key > #value then return false end; count += 1 end
	return count == #value
end
local function identifier(value)
	return Schema.IsID(value) or (type(value) == 'number' and value % 1 == 0 and value >= 1 and value <= 2147483647)
end
local function snapshotPage(item)
	if type(item) ~= 'table' or getmetatable(item) ~= nil then return nil, 'The saved page is invalid.' end
	local address = Schema.CanonicalAddress(item.URL or item.Address)
	if not address then return nil, 'The saved page address is invalid.' end
	local title = if type(item.Title) == 'string' then item.Title else address
	if not utf8.len(title) then return nil, 'The saved page title is invalid.' end
	local result = {URL = address, Title = title, Icon = if type(item.Icon) == 'string' then item.Icon else nil, History = {}}
	if item.History ~= nil then
		if not dense(item.History) then return nil, 'The saved navigation stack is invalid.' end
		for _, entry in item.History do
			if type(entry) ~= 'table' or getmetatable(entry) ~= nil then return nil, 'A saved navigation entry is invalid.' end
			local url = Schema.CanonicalAddress(entry.URL)
			if not url then return nil, 'A saved navigation address is invalid.' end
			local entryTitle = if type(entry.Title) == 'string' then entry.Title else url
			if not utf8.len(entryTitle) then return nil, 'A saved navigation title is invalid.' end
			table.insert(result.History, {URL = url, Title = entryTitle, Icon = if type(entry.Icon) == 'string' then entry.Icon else nil, State = Session.Clone(entry.State)})
		end
	end
	local index = item.HistoryIndex
	if index == nil then index = #result.History end
	if type(index) ~= 'number' or index % 1 ~= 0 or index < 0 or index > #result.History or (index == 0 and #result.History > 0) then return nil, 'The saved navigation position is invalid.' end
	result.HistoryIndex = index
	if index > 0 then
		local entry = result.History[index]
		result.URL, result.Title, result.Icon = entry.URL, entry.Title, entry.Icon
	end
	return result
end
function Session.Validate(snapshot, serverOnly)
	if serverOnly then
		if type(snapshot) == 'table' and snapshot.Page == nil and snapshot.Tabs ~= nil then
			local migrated, message = Schema.Migrate({Version = 1, Shared = Schema.DefaultShared(), Session = snapshot})
			return if migrated then migrated.Session else nil, message
		end
		return Schema.ValidateSession(snapshot)
	end
	if type(snapshot) ~= 'table' or getmetatable(snapshot) ~= nil then return nil, 'The saved browser session is invalid.' end
	local page
	if snapshot.Version == 2 then
		if snapshot.Tabs ~= nil or snapshot.Selected ~= nil or snapshot.Closed ~= nil then return nil, 'A saved browser session must contain one page.' end
		page = snapshot.Page
	elseif snapshot.Version == nil or snapshot.Version == 1 then
		if not dense(snapshot.Tabs, 20) or #snapshot.Tabs < 1 then return nil, 'The legacy browser session is invalid.' end
		local ids, selected = {}, snapshot.Selected
		for _, item in snapshot.Tabs do
			if type(item) ~= 'table' or getmetatable(item) ~= nil or not identifier(item.ID) or ids[tostring(item.ID)] then return nil, 'The legacy browser session has invalid identifiers.' end
			ids[tostring(item.ID)] = true
			local safe, message = snapshotPage(item)
			if not safe then return nil, message end
			if item.ID == selected or (selected == nil and page == nil) then page = safe end
		end
		if not page then return nil, 'The selected legacy page does not exist.' end
	else return nil, 'This browser session version is not supported.' end
	local safe, message = snapshotPage(page)
	if not safe then return nil, message end
	return {Version = 2, Page = safe}
end
function Session.RestorePage(model, snapshot, serverOnly)
	if type(snapshot) ~= 'table' then return nil end
	local page = model:Open()
	if not page then return nil end
	table.clear(page.History)
	local url = snapshot.Address or snapshot.URL or model.HomeURL
	if type(url) ~= 'string' or url == '' then url = model.HomeURL end
	page.URL = url; page.Title = if type(snapshot.Title) == 'string' then snapshot.Title else url
	page.Icon = if type(snapshot.Icon) == 'string' then snapshot.Icon else nil
	if not serverOnly and type(snapshot.History) == 'table' then
		for _, entry in snapshot.History do
			table.insert(page.History, {URL = entry.URL, Title = entry.Title, Icon = entry.Icon, State = Session.Clone(entry.State)})
		end
	end
	if #page.History == 0 then table.insert(page.History, {URL = url, Title = page.Title, Icon = page.Icon}) end
	page.HistoryIndex = math.clamp(if type(snapshot.HistoryIndex) == 'number' and snapshot.HistoryIndex == snapshot.HistoryIndex then math.floor(snapshot.HistoryIndex) else #page.History, 1, #page.History)
	local entry = page.History[page.HistoryIndex]
	page.URL, page.Title, page.Icon = entry.URL, entry.Title, entry.Icon
	page.Restored = true
	return page
end
function Session.Import(model, snapshot, serverOnly)
	local safe, message = Session.Validate(snapshot, serverOnly)
	if not safe then return false, message end
	for _, page in table.clone(model.Tabs) do model:Close(page, false) end
	model.Active = Session.RestorePage(model, safe.Page, serverOnly)
	return model.Active ~= nil
end
return Session
