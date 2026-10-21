--!strict
-- Real snapshot/schema/client/store modules; legacy collections can restore only their selected document.
return function(loadBrowser, fixture, loadStore)
	local f = fixture()
	local function encode(value)
		if type(value) == 'string' then return '"'..value:gsub('[%z\1-\31\\"]', function(c) return string.format('\\u%04x', string.byte(c)) end)..'"' end
		if type(value) ~= 'table' then return tostring(value) end
		local parts = {}
		if #value > 0 then for _, item in value do table.insert(parts, encode(item)) end; return '['..table.concat(parts, ',')..']' end
		for key, item in value do table.insert(parts, encode(key)..':'..encode(item)) end
		return '{'..table.concat(parts, ',')..'}'
	end
	f.Game:GetService('HttpService').JSONEncode = function(_, value) return encode(value) end
	local Schema = loadBrowser(f, 'Persistence/Schema')
	local Session = loadBrowser(f, 'Session')
	local Model = loadBrowser(f, 'Model')
	local checks = 0
	local function check(value, message) checks += 1; assert(value, message) end
	local shared = Schema.DefaultShared()
	shared.Settings.Theme = 'Light'
	shared.Home.Greeting = 'Saved greeting'
	shared.Bookmarks.saved = {ID='saved', Kind='bookmark', Title='Keep me', Address='https://archive.test/keep', Parent='root', Order=1}
	shared.History = {{ID='visit_saved', Title='Saved visit', Address='https://archive.test/keep', Time=19}}
	local legacy = {Version=1, Shared=shared, Session={Tabs={{ID=11, Address='https://archive.test/background'}, {ID=22, Address='https://archive.test/selected'}}, Selected=22, Closed={{Address='https://archive.test/closed'}}}}
	local migrated = assert(Schema.Migrate(legacy))
	check(Schema.Version == 2 and migrated.Version == 2, 'Persistent data migrates to the single-page version')
	check(migrated.Session.Page.Address == 'https://archive.test/selected' and migrated.Session.Tabs == nil and migrated.Session.Selected == nil and migrated.Session.Closed == nil, 'Only the selected legacy document survives')
	check(migrated.Shared.Settings.Theme == 'Light' and migrated.Shared.Home.Greeting == 'Saved greeting' and migrated.Shared.Bookmarks.saved.Title == 'Keep me' and migrated.Shared.History[1].Time == 19, 'Bookmarks, visits, settings and Home customization survive migration')
	check(legacy.Version == 1 and #legacy.Session.Tabs == 2 and legacy.Session.Closed[1].Address == 'https://archive.test/closed', 'Migration never mutates the stored input')
	check(Schema.Validate(migrated) ~= nil and Schema.Validate(legacy) == nil, 'The live protocol accepts only canonical V2 records')
	check(Schema.ValidateSession({Page={Address='https://archive.test/selected'}, Tabs=legacy.Session.Tabs}) == nil, 'The live session cannot carry a background-page collection')
	check(Schema.ValidateSession({Page={Address='javascript:alert(1)'}}) == nil, 'Invalid active-page URLs remain rejected')
	local zero = assert(Schema.Migrate({Version=0, Settings={Theme='Light'}, Session=legacy.Session}))
	check(zero.Version == 2 and zero.Session.Page.Address == 'https://archive.test/selected' and zero.Shared.Settings.Theme == 'Light', 'Version-zero settings and the selected page migrate together')
	local defaults = assert(Schema.Migrate({Version=0}))
	check(defaults.Version == 2 and defaults.Session.Page.Address == 'wayline://home', 'An old empty save migrates to one Home document')
	local invalid = Schema.Clone(legacy); invalid.Session.Selected = 999
	check(Schema.Migrate(invalid) == nil and invalid.Session.Selected == 999, 'A corrupt selection is rejected without rewriting the record')
	invalid = Schema.Clone(legacy); invalid.Version = 99
	check(Schema.Migrate(invalid) == nil, 'Unknown future save versions cannot be downgraded')
	invalid = Schema.Clone(legacy); invalid.Session.Tabs[2].ID = 11
	check(Schema.Migrate(invalid) == nil, 'Ambiguous old identifiers cannot select the wrong page')
	local snapshot = {Version=1, Selected=22, Tabs={
		{ID=11, URL='https://archive.test/background', History={}, HistoryIndex=0},
		{ID=22, URL='https://archive.test/b', Title='B', HistoryIndex=2, History={
			{URL='https://archive.test/a', Title='A', State={Scroll={X=0,Y=25}, Form={Value='first'}}},
			{URL='https://archive.test/b', Title='B', Icon='rbxassetid://123', State={Scroll={X=14,Y=285}, Form={Value='selected'}}},
			{URL='https://archive.test/c', Title='C', State={Scroll={X=0,Y=80}}},
		}},
	}, Closed={{ID=99, URL='https://archive.test/closed'}}}
	local safe = assert(Session.Validate(snapshot, false))
	check(safe.Version == 2 and safe.Tabs == nil and safe.Closed == nil and safe.Page.URL == 'https://archive.test/b', 'In-memory legacy session collapses to its selected page')
	check(#safe.Page.History == 3 and safe.Page.HistoryIndex == 2 and safe.Page.Icon == 'rbxassetid://123' and safe.Page.History[2].State.Scroll.Y == 285, 'Selected page keeps back/forward position, icon, scroll and document state')
	safe.Page.History[2].State.Form.Value = 'changed'
	check(snapshot.Tabs[2].History[2].State.Form.Value == 'selected', 'Imported document state is detached from the source snapshot')
	local model = Model.new()
	local initial=model:Open()
	model:Request(initial,'https://archive.test/pending')
	local pendingSnapshot=Session.Export(model)
	check(pendingSnapshot.Page.URL=='https://archive.test/pending' and pendingSnapshot.Page.Title=='https://archive.test/pending','A document saved during first load retains its requested address without a placeholder title')
	check(Session.Import(model, snapshot, false), 'A full legacy session imports successfully')
	check(#model.Tabs == 1 and model.Active.URL == 'https://archive.test/b' and #model.Active.History == 3 and model.Active.HistoryIndex == 2, 'Import creates exactly one navigation context')
	check(model.Active.History[2].State.Scroll.X == 14 and model.Active.History[2].State.Scroll.Y == 285, 'Restored selected-document scroll survives the model boundary')
	check(model:CanBack(model.Active) and model:CanForward(model.Active), 'Both saved navigation directions remain usable')
	local exported = model:ExportSession()
	check(exported.Version == 2 and exported.Page.URL == 'https://archive.test/b' and exported.Tabs == nil and exported.Closed == nil, 'Local exports contain no tab identifiers or closed collections')
	local server = model:ExportServerSession()
	check(server.Page.Address == 'https://archive.test/b' and server.Tabs == nil and Schema.ValidateSession(server) ~= nil, 'Server snapshots use the canonical single-document contract')
	local oldPage = model.Active
	local malformed = Session.Clone(exported); malformed.Page.HistoryIndex = 7
	check(not Session.Import(model, malformed, false) and model.Active == oldPage and oldPage.Alive, 'Invalid imports leave the currently displayed page intact')
	malformed = Session.Clone(exported); malformed.Tabs = {}
	check(Session.Validate(malformed, false) == nil, 'New local snapshots cannot hide tab collections')
	check(Session.Import(model, legacy.Session, true) and #model.Tabs == 1 and model.Active.URL == 'https://archive.test/selected' and #model.Active.History == 1, 'A legacy server restore can only restore its selected address')
	model:Destroy()
	local Client = loadBrowser(f, 'Persistence/Client')
	local start = Client._Start; Client._Start = function() end
	local client = Client.new(); Client._Start = start
	client:_Accept({Data=legacy, Restored=true, Status={State='ready', Available=true}})
	check(client.Loaded and client.Session.Page.Address == 'https://archive.test/selected' and client.Session.Tabs == nil, 'The client accepts a saved V1 response only after migration')
	check(client.SharedSnapshot.Bookmarks.saved.Title == 'Keep me', 'Client migration retains the shared collections')
	client:Destroy()
	if loadStore then
		local records = {player_7={RecordVersion=1, Revision=4, UpdatedAt=1234, Data=legacy}}
		local dataStore = {}
		function dataStore:UpdateAsync(key, update)
			local result = update(records[key]); if result ~= nil then records[key] = result end; return result
		end
		local env = {Game={JobId='migration-test'}, Task=f.Task}
		function env.Game:GetService(name)
			if name == 'HttpService' then return f.Game:GetService(name) end
			if name == 'DataStoreService' then return {GetDataStore=function(_, name) check(name == 'WaylineBrowser_v1', 'Existing store namespace must remain accessible'); return dataStore end} end
			error('Unexpected service '..name)
		end
		local Store = loadStore(env)
		local store = Store.new(Schema, {DataStore=dataStore})
		local loaded = store:Load(7)
		check(loaded.Writable and loaded.Restored and loaded.Revision == 4 and loaded.Data.Version == 2 and loaded.Data.Session.Page.Address == 'https://archive.test/selected', 'Actual Store.Load atomically migrates old selected pages while retaining the revision')
		check(records.player_7.Data.Shared.Bookmarks.saved.Title == 'Keep me' and legacy.Version == 1, 'Migrating a stored envelope preserves user collections and the old source object')
		local corrupt = Schema.Clone(legacy); corrupt.Session.Selected = 777
		records.player_8 = {RecordVersion=1, Revision=6, UpdatedAt=4321, Data=corrupt}
		local original = records.player_8
		loaded = store:Load(8)
		check(not loaded.Writable and loaded.Error == 'malformed' and records.player_8 == original and records.player_8.Data.Version == 1, 'Malformed stored sessions are preserved instead of overwritten with defaults')
		local conflicting = {RecordVersion=1, Revision=9, UpdatedAt=4321, Data=legacy, Lease={Token='other-session', Expires=os.time()+120}}
		records.player_9 = conflicting
		loaded = store:Load(9)
		check(not loaded.Writable and loaded.Error == 'conflict' and loaded.Data.Version == 2 and loaded.Data.Session.Page.Address == 'https://archive.test/selected' and records.player_9 == conflicting, 'A conflicting lease may read a migrated view but cannot overwrite the existing owner')
	end
	print('BrowserSessionMigration: '..checks..' checks passed for selected-page migration, navigation state and preserved saved data')
end
