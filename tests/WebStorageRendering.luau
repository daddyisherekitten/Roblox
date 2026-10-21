--!strict
return function(Parser, HTMLScripts, Events, Storage, loadRenderTree, FormModel, loadIFrameRuntime)
	local localArea, sessionArea = Storage.createArea(), Storage.createArea()
	localArea.Values.saved = "before-scripts"; localArea.Order = {"saved"}; localArea.Bytes = 38
	local host = {Prepared = {}, Observers = {}, Calls = {}}
	function host:Prepare(address)
		table.insert(self.Prepared, address); table.insert(self.Calls, "prepare")
		return function(kind) return if kind == "local" then localArea elseif kind == "session" then sessionArea else nil end
	end
	function host:Observe(address, callback)
		table.insert(self.Calls, "observe"); self.Observers[address] = callback; callback("saved", nil)
		return function() self.Observers[address] = nil end
	end
	local factory = {}
	function factory.create(_, parent, properties)
		local gui = table.clone(properties); gui.Parent = parent
		function gui:Destroy() self.Destroyed = true end
		return gui
	end
	local function mounted(options, scriptSource)
		local document = Parser.parseDocument("<html><body><script>" .. scriptSource .. "</script></body></html>")
		local diagnostics, attributes = {}, {}
		local root = {AbsoluteSize = Vector2.new(600, 600)}
		function root:SetAttribute(key, value) attributes[key] = value end
		function root:GetAttribute(key) return attributes[key] end
		local tree = loadRenderTree(factory).build(document, root, function(message) table.insert(diagnostics, message) end)
		local events = Events.new(error)
		local model = FormModel.new(document, tree.Controls, events, function() end)
		local page = {Alive = true, Document = document, DocumentURL = "https://document.test/page", BaseURL = "https://resources.test/base/", Root = root, Events = events, FormModel = model, Cleanups = {}}
		function page:AddCleanup(callback) table.insert(self.Cleanups, callback) end
		function page:Destroy()
			self.Alive = false
			for index = #self.Cleanups, 1, -1 do self.Cleanups[index]() end
			model:Destroy(); events:Destroy()
		end
		local runtime = HTMLScripts.start(page, tree, function() end, function(message) table.insert(diagnostics, message) end, options)
		assert(runtime and #diagnostics == 0 and #runtime.Diagnostics == 0, table.concat(diagnostics, " / "))
		return page, runtime, attributes
	end
	local page, runtime, attributes = mounted({StorageHost = host}, [[window.boot=localStorage.getItem('saved');sessionStorage.setItem('tab','same');]])
	assert(host.Prepared[1] == "https://document.test/page" and table.concat(host.Calls, ",") == "prepare,observe", "Mounted scripts prepare storage using the document's URL before realm creation")
	assert(runtime.Window.Get("boot") == "before-scripts" and runtime.ScriptsRun == 1 and attributes.StorageStatus == "saved", "The first parser script sees loaded storage and mount exposes its save status")
	host.Observers["https://document.test/page"]("pending", "retrying")
	assert(attributes.StorageStatus == "pending" and attributes.StorageError == "retrying")
	page:Destroy()
	assert(host.Observers["https://document.test/page"] == nil and #localArea.Subscribers == 0 and #sessionArea.Subscribers == 0 and localArea.Values.saved == "before-scripts", "Page cleanup releases its status observer and realm subscriptions while retaining host storage")
	local prepared = #host.Prepared
	local opaque, opaqueRuntime = mounted({StorageHost = host, StorageOriginOpaque = true}, [[try{localStorage.length}catch(e){window.localError=e.name}try{sessionStorage.length}catch(e){window.sessionError=e.name}]])
	assert(#host.Prepared == prepared and opaqueRuntime.Window.Get("localError") == "SecurityError" and opaqueRuntime.Window.Get("sessionError") == "SecurityError", "Opaque mounts deny both areas before a shared host can supply them")
	opaque:Destroy()
	local inherited, inheritedRuntime = mounted({StorageHost = host, StorageDocumentURL = "https://creator.test/start"}, [[window.boot=localStorage.getItem('saved');]])
	assert(host.Prepared[#host.Prepared] == "https://creator.test/start" and inheritedRuntime.Window.Get("boot") == "before-scripts", "An inherited document origin overrides its resource-resolution URL")
	inherited:Destroy()

	local iframe = loadIFrameRuntime({defer = function(callback) callback() end})
	local mounts, cleanups = {}, {}
	local embedding = {Alive = true, Document = {}, DocumentURL = "https://creator.test/document", BaseURL = "https://resources.test/base/"}
	function embedding:AddCleanup(callback) table.insert(cleanups, callback) end
	local function item(attributes)
		return {Node = {Attributes = attributes}, ContentGui = {}, SelectedSource = attributes.src or "about:blank"}
	end
	local function mount(_, _, options)
		local child = {Alive = true, Root = {SetAttribute = function() end}, ScrollToFragment = function() end}
		function child:Destroy() self.Alive = false end
		table.insert(mounts, {Options = options, Page = child})
		return child
	end
	local resolver = function(_, reference)
		return {Kind = "internal", Name = reference, URL = if reference == "about:blank" then "about:blank" else "https://child.test/page", Website = {HTML = "<html></html>", Options = {}}}
	end
	local srcdoc, sandboxed, sameOrigin, blank, cross = item({srcdoc = "inline"}), item({srcdoc = "opaque", sandbox = "allow-scripts"}), item({srcdoc = "same", sandbox = "allow-scripts allow-same-origin"}), item({}), item({src = "/child"})
	local api = iframe.start(embedding, {IFrameItems = {srcdoc, sandboxed, sameOrigin, blank, cross}}, error, mount, {StorageHost = host, IFrameResolver = resolver})
	assert(#mounts == 5)
	for _, index in {1, 3, 4} do
		assert(mounts[index].Options.StorageHost == host and mounts[index].Options.StorageDocumentURL == embedding.DocumentURL and not mounts[index].Options.StorageOriginOpaque, "Unsandboxed srcdoc/blank and allow-same-origin inherit the embedding document's storage origin")
	end
	assert(mounts[2].Options.StorageOriginOpaque and mounts[2].Options.JavaScript ~= false and mounts[2].Options.StorageHost == host, "allow-scripts permits scripts while retaining opaque storage isolation")
	assert(mounts[5].Options.DocumentURL == "https://child.test/page" and mounts[5].Options.StorageDocumentURL == nil and mounts[5].Options.StorageHost == host, "A regular child URL selects its own origin on the same browser host")
	local previous = mounts[5].Page
	mounts[5].Options.Navigate("/child", nil, {Kind = "reload", Target = ""})
	assert(#mounts == 6 and not previous.Alive and mounts[6].Options.StorageHost == host, "A child reload recreates its page while retaining the browser storage host")
	api:Destroy()
	local nested = item({srcdoc = "nested", sandbox = "allow-scripts allow-same-origin"})
	local nestedApi = iframe.start(embedding, {IFrameItems = {nested}}, error, mount, {StorageHost = host, StorageOriginOpaque = true, StorageDocumentURL = "https://ancestor.test/", IFrameResolver = resolver})
	assert(mounts[7].Options.StorageOriginOpaque and mounts[7].Options.StorageDocumentURL == "https://ancestor.test/", "A nested child cannot escape its embedding document's opaque storage origin")
	nestedApi:Destroy()
	print("Web Storage rendering: prepare-before-script, document/inherited origin, save-status cleanup, shared iframe host and sandbox/opaque inheritance passed")
end
