--!strict
-- The same bounds and canonical records are used on both sides of the remote boundary.
local HttpService = game:GetService('HttpService')
local Address = require(script.Parent.Parent.Address)
local Schema = {}
Schema.Version = 2
Schema.Limits = table.freeze({Bookmarks = 300, Folders = 50, FolderDepth = 5, QuickLinks = 12, History = 500, Text = 120, Address = 512, Bytes = 512 * 1024})
Schema.Backgrounds = table.freeze({'Slate', 'Ocean', 'Meadow', 'Plum', 'Sand', 'Rose'})
local function text(value, limit, allowEmpty)
	if type(value) ~= 'string' then return nil end
	local length = utf8.len(value)
	if not length or length > limit or (not allowEmpty and length == 0) or value:find('[%z\1-\8\11\12\14-\31\127]') then return nil end
	return value
end
function Schema.Text(value, allowEmpty) return text(value, Schema.Limits.Text, allowEmpty) end
local function id(value)
	return type(value) == 'string' and value ~= 'root' and #value >= 1 and #value <= 64 and value:match('^[%w_%-]+$') ~= nil
end
function Schema.IsID(value) return id(value) end
local function integer(value, low, high)
	return type(value) == 'number' and value == value and value % 1 == 0 and value >= low and value <= high
end
function Schema.CanonicalAddress(value)
	value = text(value, Schema.Limits.Address, false)
	if not value then return nil end
	value = value:match('^%s*(.-)%s*$') or ''
	if value == 'about:newtab' then return Address.Home end
	if value == 'about:blank' then return value end
	local route, tail = value:match('^[Ww][Aa][Yy][Ll][Ii][Nn][Ee]://([^%?#]+)(.*)$')
	if route then
		route = route:lower():gsub('/+$', '')
		if not route:match('^[%w_%-]+$') then return nil end
		local params, keys = {}, {}
		for part in (tail:match('^%?([^#]*)') or ''):gmatch('[^&]+') do
			local key, item = part:match('^([^=]*)=(.*)$')
			params[Address.Decode(key or part)] = Address.Decode(item or '')
		end
		for key in params do table.insert(keys, key) end
		table.sort(keys)
		local parts = {}
		for _, key in keys do table.insert(parts, Address.Encode(key)..'='..Address.Encode(params[key])) end
		local canonical = 'wayline://'..route..(if #parts > 0 then '?'..table.concat(parts, '&') else '')
		if not text(canonical, Schema.Limits.Address, false) then return nil end
		return canonical
	end
	local normalized = Address.NormalizeExternal(value)
	return if normalized and text(normalized, Schema.Limits.Address, false) then normalized else nil
end
local function plain(value, depth, seen, budget)
	local kind = type(value)
	if kind == 'string' then
		budget.Bytes += #value
		if utf8.len(value) and #value <= Schema.Limits.Bytes and budget.Bytes <= budget.MaximumBytes then return value end
		return nil, 'Save data contains too much or invalid text.'
	end
	if kind == 'boolean' or kind == 'nil' then return value end
	if kind == 'number' then if value == value and math.abs(value) < math.huge then return value end; return nil, 'Invalid number in save data.' end
	if kind ~= 'table' or getmetatable(value) ~= nil then return nil, 'Save data must contain only plain serializable values.' end
	if depth > 12 or seen[value] then return nil, 'Save data is too deeply nested or contains a cycle.' end
	seen[value] = true
	local result = {}
	for key, item in value do
		budget.Count += 1
		if budget.Count > 30000 then seen[value] = nil; return nil, 'Save data contains too many values.' end
		if type(key) ~= 'string' and not integer(key, 1, 30000) then seen[value] = nil; return nil, 'Invalid save-data key.' end
		if type(key) == 'string' then
			budget.Bytes += #key
			if #key > 512 or not utf8.len(key) or budget.Bytes > budget.MaximumBytes then seen[value] = nil; return nil, 'Invalid or oversized save-data key.' end
		end
		local copy, errorMessage = plain(item, depth + 1, seen, budget)
		if errorMessage then seen[value] = nil; return nil, errorMessage end
		result[key] = copy
	end
	seen[value] = nil
	return result
end
function Schema.Clone(value, maximumBytes) return plain(value, 0, {}, {Count = 0, Bytes = 0, MaximumBytes = maximumBytes or math.huge}) end
local function array(value, limit)
	if type(value) ~= 'table' or #value > limit then return false end
	local count = 0
	for key in value do if not integer(key, 1, #value) then return false end; count += 1 end
	return count == #value
end
function Schema.DefaultShared()
	return {
		Settings = {Theme = 'Dark', Accent = 'Blue', BookmarksBar = true},
		Home = {Greeting = '', Background = 'Slate', QuickLinks = {
			{ID = 'quick_search', Title = 'Search pages', Address = 'wayline://search'},
			{ID = 'quick_bookmarks', Title = 'Bookmarks', Address = 'wayline://bookmarks'},
			{ID = 'quick_history', Title = 'History', Address = 'wayline://history'},
			{ID = 'quick_guide', Title = 'Wayline guide', Address = 'wayline://guide'},
		}},
		Bookmarks = {}, History = {},
	}
end
function Schema.DefaultSession() return {Page = {Address = Address.Home}} end
function Schema.DefaultData() return {Version = Schema.Version, Shared = Schema.DefaultShared(), Session = Schema.DefaultSession()} end
function Schema.ValidateShared(raw)
	if type(raw) ~= 'table' or type(raw.Settings) ~= 'table' or type(raw.Home) ~= 'table' or type(raw.Bookmarks) ~= 'table' then return nil, 'Shared browser data is incomplete.' end
	local settings = raw.Settings
	if not table.find({'Light', 'Dark'}, settings.Theme) or not table.find({'Blue', 'Purple', 'Green'}, settings.Accent) or type(settings.BookmarksBar) ~= 'boolean' then return nil, 'Invalid browser settings.' end
	local home = raw.Home
	if not Schema.Text(home.Greeting, true) or not table.find(Schema.Backgrounds, home.Background) or not array(home.QuickLinks, 12) then return nil, 'Invalid Home customization.' end
	local result = {Settings = {Theme = settings.Theme, Accent = settings.Accent, BookmarksBar = settings.BookmarksBar}, Home = {Greeting = home.Greeting, Background = home.Background, QuickLinks = {}}, Bookmarks = {}, History = {}}
	local quickIDs = {}
	for _, link in home.QuickLinks do
		if type(link) ~= 'table' or not id(link.ID) or quickIDs[link.ID] or not Schema.Text(link.Title, false) then return nil, 'Invalid quick-link record.' end
		local address = Schema.CanonicalAddress(link.Address)
		if not address then return nil, 'A quick-link address is invalid.' end
		quickIDs[link.ID] = true
		table.insert(result.Home.QuickLinks, {ID = link.ID, Title = link.Title, Address = address})
	end
	local bookmarks, folders, addresses = 0, 0, {}
	for key, item in raw.Bookmarks do
		if not id(key) or type(item) ~= 'table' or item.ID ~= key or not Schema.Text(item.Title, false) or (item.Parent ~= 'root' and not id(item.Parent)) or not integer(item.Order, 1, 350) then return nil, 'Invalid bookmark or folder record.' end
		local record = {ID = key, Kind = item.Kind, Title = item.Title, Parent = item.Parent, Order = item.Order}
		if item.Kind == 'bookmark' then
			bookmarks += 1
			local address = Schema.CanonicalAddress(item.Address)
			if not address or addresses[address] then return nil, 'Bookmark addresses must be valid and unique.' end
			addresses[address] = true; record.Address = address
		elseif item.Kind == 'folder' then folders += 1
		else return nil, 'Unknown bookmark item kind.' end
		result.Bookmarks[key] = record
	end
	if bookmarks > 300 or folders > 50 then return nil, 'The bookmark collection exceeds its limits.' end
	for _, item in result.Bookmarks do
		local current, chain, depth = item, {}, 0
		if item.Kind == 'folder' then depth = 1 end
		while current.Parent ~= 'root' do
			local parent = result.Bookmarks[current.Parent]
			if not parent or parent.Kind ~= 'folder' or chain[parent.ID] or parent.ID == item.ID then return nil, 'The folder structure has an invalid reference or cycle.' end
			chain[parent.ID] = true; depth += 1
			if depth > 5 then return nil, 'Folders may be nested at most five levels deep.' end
			current = parent
		end
	end
	if not array(raw.History, 500) then return nil, 'History exceeds its limit.' end
	local historyIDs = {}
	for _, entry in raw.History do
		if type(entry) ~= 'table' or not id(entry.ID) or historyIDs[entry.ID] or not Schema.Text(entry.Title, false) or not integer(entry.Time, 0, 9999999999) then return nil, 'Invalid browsing-history record.' end
		local address = Schema.CanonicalAddress(entry.Address)
		if not address then return nil, 'A browsing-history address is invalid.' end
		historyIDs[entry.ID] = true
		table.insert(result.History, {ID = entry.ID, Title = entry.Title, Address = address, Time = entry.Time})
	end
	return result
end
function Schema.ValidateSession(raw)
	if type(raw) ~= 'table' or getmetatable(raw) ~= nil or type(raw.Page) ~= 'table' or getmetatable(raw.Page) ~= nil
		or raw.Tabs ~= nil or raw.Selected ~= nil or raw.Closed ~= nil then return nil, 'A saved browser session must contain one page.' end
	local address = Schema.CanonicalAddress(raw.Page.Address or raw.Page.URL)
	if not address then return nil, 'The saved page address is invalid.' end
	return {Page = {Address = address}}
end
function Schema.Validate(raw)
	local safe, cloneError = Schema.Clone(raw, Schema.Limits.Bytes)
	if not safe then return nil, cloneError end
	if safe.Version ~= Schema.Version then return nil, 'This browser data version is not supported.' end
	local shared, sharedError = Schema.ValidateShared(safe.Shared)
	if not shared then return nil, sharedError end
	local session, sessionError = Schema.ValidateSession(safe.Session)
	if not session then return nil, sessionError end
	local result = {Version = Schema.Version, Shared = shared, Session = session}
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, result)
	if not ok or #encoded > Schema.Limits.Bytes then return nil, 'Browser save data exceeds 512 KiB.' end
	return result
end
function Schema.Migrate(raw)
	if raw == nil then return Schema.DefaultData() end
	if type(raw) ~= 'table' then return nil, 'Stored browser data is malformed.' end
	local safe, cloneError = Schema.Clone(raw, Schema.Limits.Bytes)
	if not safe then return nil, cloneError end
	raw = safe
	if raw.Version == 0 then
		local defaults = Schema.DefaultShared()
		local source = raw.Shared or raw
		if type(source) ~= 'table' then return nil, 'Stored browser data is malformed.' end
		if type(source.Settings) == 'table' then for key, value in source.Settings do defaults.Settings[key] = value end end
		if type(source.Home) == 'table' then for key, value in source.Home do defaults.Home[key] = value end end
		if source.Bookmarks ~= nil then defaults.Bookmarks = source.Bookmarks end
		if source.History ~= nil then defaults.History = source.History end
		raw = {Version = 1, Shared = defaults, Session = raw.Session or {Tabs = {{ID = 1, Address = Address.Home}}, Selected = 1}}
	end
	if raw.Version == 1 then
		-- Read the old collection only during migration. Its selected document is
		-- the sole page in the new browser; no closed or background page survives.
		local session = raw.Session
		if type(session) ~= 'table' or not array(session.Tabs, 20) or #session.Tabs < 1 then return nil, 'The legacy browser session is invalid.' end
		local selected, ids = nil, {}
		for _, page in session.Tabs do
			if type(page) ~= 'table' or not (id(page.ID) or integer(page.ID, 1, 2147483647)) or ids[tostring(page.ID)] then return nil, 'The legacy browser session has invalid identifiers.' end
			ids[tostring(page.ID)] = true
			local address = Schema.CanonicalAddress(page.Address or page.URL)
			if not address then return nil, 'A legacy page address is invalid.' end
			if page.ID == session.Selected then selected = {Address = address} end
		end
		if not selected then return nil, 'The selected legacy page does not exist.' end
		raw = {Version = Schema.Version, Shared = raw.Shared, Session = {Page = selected}}
	end
	return Schema.Validate(raw)
end
return Schema
