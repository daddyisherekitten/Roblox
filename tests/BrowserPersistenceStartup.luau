--!strict
-- Executes the actual server entry with module/service boundaries controlled.
return function(start, fixture, startHTMLStorage)
	local cases = 0
	local function setup(options)
		options = options or {}
		local f = fixture()
		local replicated = f.Create('ReplicatedStorage')
		local servers = f.Create('ServerScriptService')
		local browser = f.Create(if options.BadBrowser then 'Folder' else 'ModuleScript', if options.NoBrowser then nil else replicated, {Name='Browser'})
		local persistence = f.Create('Folder', if options.NoPersistence then nil else browser, {Name='Persistence'})
		local schemaModule = f.Create(if options.BadSchema then 'Folder' else 'ModuleScript', if options.NoSchema then nil else persistence, {Name='Schema'})
		local serverModule = f.Create(if options.BadServer then 'Folder' else 'ModuleScript', if options.NoServer then nil else servers, {Name='BrowserServer'})
		local calls = {Waits=0, Requires={}, Starts=0}
		for _, object in {replicated, servers, browser, persistence} do
			function object:WaitForChild()
				calls.Waits += 1
				error('Server startup must not wait for an optional application owner')
			end
		end
		local schema = {Identity='existing schema'}
		local server = if options.BadAPI then {} else {new=function(receivedSchema, receivedOptions)
			calls.Starts += 1
			assert(receivedSchema == schema, 'Existing schema object is passed to the backend')
			assert(receivedOptions.Name == 'WaylineBrowser_v1' and receivedOptions.RemoteName == 'WaylinePersistence', 'Existing persistence store and remote names remain unchanged')
			local keys = 0
			for _ in receivedOptions do keys += 1 end
			assert(keys == 2, 'Starter forwards only its existing backend configuration')
			if options.BackendError then error(options.BackendError, 0) end
		end}
		local game = {GetService=function(_, name)
			if name == 'ReplicatedStorage' then return replicated end
			if name == 'ServerScriptService' then return servers end
			error('Starter must not initialize an unrelated service: '..name)
		end}
		local function requireModule(module)
			table.insert(calls.Requires, module)
			if module == schemaModule then
				if options.SchemaError then error(options.SchemaError, 0) end
				return schema
			end
			assert(module == serverModule, 'Starter must not import Browser, HTML, WindowManager or unrelated modules')
			return server
		end
		local ok, message = pcall(start, game, requireModule)
		assert(calls.Waits == 0, 'Optional server entry performs zero WaitForChild calls')
		cases += 1
		return ok, message, calls, schemaModule, serverModule
	end
	for _, options in {{NoBrowser=true}, {NoBrowser=true, NoServer=true}, {NoBrowser=true, BadSchema=true, BadAPI=true}} do
		local ok, _, calls = setup(options)
		assert(ok and #calls.Requires == 0 and calls.Starts == 0, 'Absent Browser owner exits immediately without require/backend/remote/DataStore side effects')
	end
	for _, row in {
		{{BadBrowser=true}, 'ReplicatedStorage.Browser'},
		{{NoPersistence=true}, 'Browser.Persistence.Schema'},
		{{NoSchema=true}, 'Browser.Persistence.Schema'},
		{{BadSchema=true}, 'Browser.Persistence.Schema'},
		{{NoServer=true}, 'ServerScriptService.BrowserServer'},
		{{BadServer=true}, 'ServerScriptService.BrowserServer'},
	} do
		local ok, message, calls = setup(row[1])
		assert(not ok and tostring(message):find(row[2], 1, true), 'Present but incomplete package has a concrete diagnostic: '..row[2])
		assert(#calls.Requires == 0 and calls.Starts == 0, 'Invalid required package shape is diagnosed before module execution')
	end
	do
		local ok, _, calls, schema, server = setup()
		assert(ok and #calls.Requires == 2 and calls.Requires[1] == schema and calls.Requires[2] == server and calls.Starts == 1, 'Present owner starts the unchanged persistence backend exactly once')
	end
	do
		local ok, message, calls = setup({BadAPI=true})
		assert(not ok and tostring(message):find('BrowserServer.new', 1, true) and #calls.Requires == 2 and calls.Starts == 0, 'Invalid installed backend API has a concrete startup diagnostic')
	end
	for _, errorSource in {'SchemaError', 'BackendError'} do
		local reason = {Original=errorSource}
		local options = {}; options[errorSource] = reason
		local ok, message = setup(options)
		assert(not ok and message == reason, 'A real installed '..errorSource..' remains visible with its original error identity')
	end
	assert(cases == 13, 'Exact modular persistence startup case inventory')
	print('Browser persistence startup: '..cases..' actual-entry controls; absent owner has zero waits/imports/startup side effects, required installed parts have clear errors, valid backend starts once')
	assert(type(startHTMLStorage) == 'function', 'Actual HTML storage server source wrapper is required')
	local storageCases = 0
	local function storageSetup(options)
		options = options or {}
		local f = fixture()
		local replicated = f.Create('ReplicatedStorage')
		local engine = f.Create(if options.BadEngine then 'Folder' else 'ModuleScript', if options.NoEngine then nil else replicated, {Name='HTMLEngine'})
		local storage = f.Create(if options.BadStorage then 'ModuleScript' else 'Folder', if options.NoStorage then nil else engine, {Name='Storage'})
		local protocol = f.Create(if options.BadProtocol then 'Folder' else 'ModuleScript', if options.NoProtocol then nil else storage, {Name='Protocol'})
		f.Create(if options.BadServer then 'Folder' else 'ModuleScript', if options.NoServer then nil else storage, {Name='Server'})
		f.Create(if options.BadWebsites then 'Folder' else 'ModuleScript', if options.NoWebsites then nil else engine, {Name='Websites'})
		local calls = {Waits=0, Requires=0, Services=0, Instances=0, Jobs=0, Warnings=0}
		for _, object in {replicated, engine, storage} do
			function object:WaitForChild() calls.Waits += 1; error('HTML storage server must not wait for an optional owner') end
		end
		local sentinel = {FirstProtocolRequire=true}
		local game = {GetService=function(_, name)
			if name == 'ReplicatedStorage' then return replicated end
			calls.Services += 1
			error('HTML storage package must be validated before initializing '..name)
		end}
		local function requireModule(module)
			calls.Requires += 1
			assert(module == protocol, 'Valid HTML storage starts by requiring its actual Protocol module')
			error(sentinel, 0)
		end
		local instance = {new=function() calls.Instances += 1; error('Unexpected remote/native creation') end}
		local tasks = setmetatable({}, {__index=function() return function() calls.Jobs += 1; error('Unexpected queued storage job') end end})
		local ok, message = pcall(startHTMLStorage, game, requireModule, instance, tasks, function() calls.Warnings += 1 end)
		assert(calls.Waits == 0 and calls.Services == 0 and calls.Instances == 0 and calls.Jobs == 0 and calls.Warnings == 0, 'Optional HTML storage startup has no unrelated service/native/task/warning side effects')
		storageCases += 1
		return ok, message, calls, sentinel
	end
	do
		local ok, _, calls = storageSetup({NoEngine=true})
		assert(ok and calls.Requires == 0, 'Absent HTMLEngine owner silently skips HTML storage without imports')
	end
	for _, row in {
		{{BadEngine=true}, 'HTMLEngine'},
		{{NoStorage=true}, 'HTMLEngine.Storage'},
		{{BadStorage=true}, 'HTMLEngine.Storage'},
		{{NoProtocol=true}, 'Storage.Protocol'},
		{{BadProtocol=true}, 'Storage.Protocol'},
		{{NoServer=true}, 'Storage.Server'},
		{{BadServer=true}, 'Storage.Server'},
		{{NoWebsites=true}, 'HTMLEngine.Websites'},
		{{BadWebsites=true}, 'HTMLEngine.Websites'},
	} do
		local ok, message, calls = storageSetup(row[1])
		assert(not ok and tostring(message):find(row[2], 1, true) and calls.Requires == 0, 'Present invalid HTML storage package has a precise diagnostic before imports: '..row[2])
	end
	do
		local ok, message, calls, sentinel = storageSetup()
		assert(not ok and message == sentinel and calls.Requires == 1, 'Valid HTML storage reaches its real first Protocol import without starting DataStore/remotes/jobs')
	end
	assert(storageCases == 11, 'Exact HTML storage startup shape inventory')
	print('HTML storage startup: '..storageCases..' actual-entry controls; absent owner skips immediately, required shapes validate before services/imports; valid first Protocol import verified')
end
