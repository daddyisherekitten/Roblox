--!strict
-- Actual LocalScript startup, with controlled replication and module boundaries.
return function(start, fixture, defaultAttributes, standaloneAttributes)
	assert(defaultAttributes.BrowserEnabled == true and standaloneAttributes.BrowserEnabled == false)
	local function setup(options)
		options = options or {}
		local f = fixture()
		local calls = {Mounts=0, Browsers=0, Bindings=0, Opens=0, BrowserDestroyed=0, BindingDestroyed=0, StorageDestroyed=0, OptionalRequires=0, Waits={}, LoadedWaits=0, Prints={}, Warnings={}}
		local replicationReady=not(options.Delayed or options.DelayedWindow or options.NotLoaded)
		local expectedWebsite=options.Website or ''
		local routes={Main='main',WindowCheck='window-check',AnnoyingSite='annoying-site',DeepWiki='wiki1',Nachtverzeichnis='verzeichnis'}
		local home = if expectedWebsite==''then 'wayline://home'else 'http://localhost:8000/'..assert(routes[expectedWebsite])..'/index.html'
		calls.ExpectedURL=if expectedWebsite==''then 'about:blank'else home
		calls.ExpectedWebsite=expectedWebsite
		calls.ExpectedHTML=if expectedWebsite==''then '<!doctype html><html><head><title>Leere Seite</title></head><body></body></html>'else '<p>Home</p>'
		calls.CatalogGets=0;calls.CatalogURLs=0
		local storageHost = {Destroy=function()calls.StorageDestroyed+=1 end}
		local workspace=f.Create('Model');local camera=f.Create('Part',workspace,{Name='Camera'})
		local captureHost={Destroy=function()calls.CaptureDestroyed=(calls.CaptureDestroyed or 0)+1 end}
		local engine = {
			createMediaCaptureHost=function(config)
				assert(config.Camera()==camera and config.Scene()==workspace,'LocalScript resolves the configured camera and scene relative to Workspace')
				calls.CaptureHost=captureHost;return captureHost
			end,
			Websites={get=function(name)calls.CatalogGets+=1;assert(expectedWebsite~=''and name==expectedWebsite);if options.WaitWebsite then coroutine.yield('website')end;return {HTML='<p>Home</p>', CSS='p {color: blue}',Options={FallbackWindow=options.FallbackWindow}}end, url=function()calls.CatalogURLs+=1;assert(expectedWebsite~='');return home end},
			mountHTML=function(target,html,mountOptions)
				calls.Mounts+=1;calls.Target=target;calls.HTML=html;calls.MountOptions=mountOptions;return {}
			end,
		}
		local engineModule = f.Create('ModuleScript')
		local storageModule = f.Create('ModuleScript')
		engineModule.Storage = {Memory=storageModule}
		local browserModule = f.Create(if options.BadBrowser then 'Frame' else 'ModuleScript')
		local bindingModule = f.Create('ModuleScript')
		local windowModule=f.Create(if options.BadWindow then 'Frame' else 'ModuleScript');local hostModule=f.Create('ModuleScript')
		local configModule = f.Create('ModuleScript')
		local examples = f.Create('Folder',engineModule,{Name='Examples'})
		configModule.Name='Config';configModule.Parent=examples
		local integration = f.Create('Folder',browserModule,{Name='Integration'})
		bindingModule.Name='HTMLBinding';bindingModule.Parent=if options.MissingBinding then nil else integration
		hostModule.Name='WindowHost';hostModule.Parent=if options.MissingHost then nil else integration
		local localScript = f.Create('LocalScript')
		localScript:SetAttribute('BrowserEnabled',options.BrowserEnabled)
		localScript:SetAttribute('Website',options.Website)
		local browserAPI = {new=function(screen,browserOptions)
			calls.Browsers+=1;calls.Screen=screen;calls.BrowserOptions=browserOptions
			return {
				Open=function(_,url)calls.Opens+=1;calls.OpenURL=url;if options.FailOpen then error('open failed')end end,
				Destroy=function()calls.BrowserDestroyed+=1 end,
			}
		end}
		local bindingAPI = {new=function(browser,receivedEngine,bindingOptions)
			assert(browser and receivedEngine==engine)
			calls.Bindings+=1;calls.BindingOptions=bindingOptions
			if options.FailBinding then error('binding failed')end
			return {Destroy=function()calls.BindingDestroyed+=1 end}
		end}
		local replicated = {}
		function replicated:FindFirstChild(name)
			if name=='HTMLEngine' then return engineModule end
			if name=='Browser' and (replicationReady or not options.Delayed) and not options.MissingBrowser then return browserModule end
			if name=='WindowManager' and (replicationReady or not options.DelayedWindow) and not options.MissingWindow then return windowModule end
		end
		function replicated:WaitForChild(name,timeout)
			table.insert(calls.Waits,{Name=name,Timeout=timeout})
			assert(timeout==10)
			if name=='HTMLEngine' then if options.WaitEngine then coroutine.yield('engine')end;return engineModule end
			error('Optional modules must not block startup: '..name)
		end
		local player = {WaitForChild=function(_,name)assert(name=='PlayerGui');return f.PlayerGui end}
		local values = {
			[engineModule]=engine, [browserModule]=browserAPI, [bindingModule]=bindingAPI,
			[configModule]={ActiveDemo=options.ActiveDemo or 'HTMLPage'},
			[storageModule]={new=function(...)assert(select('#',...)==0,'Demo memory storage requires no server/transport');calls.MemoryStorageCreated=(calls.MemoryStorageCreated or 0)+1;return storageHost end},
			[windowModule]={new=function(screen)calls.Windows=(calls.Windows or 0)+1;return {Screen=screen,Destroy=function()calls.WindowsDestroyed=(calls.WindowsDestroyed or 0)+1 end}end},
			[hostModule]={new=function(windows,Browser,Binding,receivedEngine,settings)
				calls.Hosts=(calls.Hosts or 0)+1
				local browser=Browser.new(windows.Screen,{HomeURL=home,AutoOpen=false});local ok,binding=pcall(Binding.new,browser,receivedEngine,settings)
				if not ok then browser:Destroy();error(binding)end
				return {Open=function(_,url)browser:Open(url)end,Destroy=function()binding:Destroy();browser:Destroy()end}
			end},
		}
		local taskAPI=table.clone(f.Task)
		if options.WaitFrame then taskAPI.wait=function()coroutine.yield('frame')end end
		local env = {
			Game={IsLoaded=function()return replicationReady end,Loaded={Wait=function()
				calls.LoadedWaits+=1;coroutine.yield('replication');replicationReady=true
			end},GetService=function(_,name)
				if name=='Players' then return {LocalPlayer=player}end
				assert(name=='ReplicatedStorage');return replicated
			end},
			Instance={new=function(class)return f.Create(class)end}, Task=taskAPI, Script=localScript,Workspace=workspace,
			Require=function(module)
				assert(values[module], 'Unexpected startup require')
				if module==engineModule and options.WaitRequire then coroutine.yield('require')end
				if module==browserModule or module==bindingModule or module==windowModule or module==hostModule then calls.OptionalRequires+=1 end
				return values[module]
			end,
			Print=function(message)table.insert(calls.Prints,message)end, Warn=function(message)table.insert(calls.Warnings,message)end,
			Color3=f.Color3, UDim2=f.UDim2, Vector2=f.Vector2, Enum=f.Enum,
		}
		return f,calls,env,storageHost
	end
	local function assertBrowser(calls,host)
		assert(calls.Mounts==0 and calls.Browsers==1 and calls.Bindings==1 and calls.Opens==1,table.concat(calls.Warnings,' | ')..' mounts='..calls.Mounts..' browsers='..calls.Browsers)
		assert(calls.BrowserOptions.AutoOpen==false and calls.OpenURL==calls.BrowserOptions.HomeURL)
		assert(calls.OpenURL==(if calls.ExpectedWebsite==''then 'wayline://home'else calls.ExpectedURL))
		assert(calls.CatalogGets==(if calls.ExpectedWebsite==''then 0 else 1),'Only a configured start page loads the website catalog')
		assert(calls.BindingOptions.StorageHost==host)
		assert(calls.MemoryStorageCreated==1,'The demo uses one memory-only storage host for every browser window')
		assert(calls.BindingOptions.MediaCaptureHost==calls.CaptureHost,'Browser windows receive the configured capture host')
		assert(#calls.Waits==1 and calls.Waits[1].Name=='HTMLEngine','Installed optional modules must be looked up without a timeout')
		assert(table.find(calls.Prints,'HTMLPageDemo: Wayline and HTML connected'))
		assert(not calls.Screen:FindFirstChild('PageTarget'))
	end
	-- An absent attribute and the standard project's true attribute both start Browser.
	for _,options in {{},{BrowserEnabled=defaultAttributes.BrowserEnabled,Website=defaultAttributes.Website}}do
		local f,calls,env,host=setup(options);start(env);assertBrowser(calls,host)
		calls.Screen:Destroy();f:Drain()
		assert(calls.BrowserDestroyed==1 and calls.BindingDestroyed==1 and calls.StorageDestroyed==1 and calls.CaptureDestroyed==1)
	end
	-- Initial replication completes once before taking the optional-module snapshot.
	for _,options in {{Delayed=true},{DelayedWindow=true}}do
		local f,calls,env,host=setup(options)
		local thread=coroutine.create(function()start(env)end)
		local ok,state=coroutine.resume(thread);assert(ok and state=='replication')
		assert(calls.Mounts==0 and calls.Browsers==0 and coroutine.status(thread)=='suspended')
		assert(calls.LoadedWaits==1 and #calls.Waits==0 and not calls.CaptureHost,'Initial replication must precede module loading and resource allocation')
		local screen=f.PlayerGui:FindFirstChild('HTMLPageDemo')
		assert(not screen:FindFirstChild('PageTarget'):FindFirstChild('StartupStatus').Visible)
		ok,state=coroutine.resume(thread);assert(ok,state);assert(coroutine.status(thread)=='dead');assertBrowser(calls,host)
		calls.Screen:Destroy();f:Drain()
	end
	-- Closing the GUI during a replication wait must not create a new application afterward.
	for _,options in {{Delayed=true},{DelayedWindow=true}}do
		local f,calls,env=setup(options)
		local thread=coroutine.create(function()start(env)end)
		local ok,state=coroutine.resume(thread);assert(ok and state=='replication')
		f.PlayerGui:FindFirstChild('HTMLPageDemo'):Destroy();f:Drain()
		ok,state=coroutine.resume(thread);assert(ok,state)
		assert(coroutine.status(thread)=='dead' and calls.Mounts==0 and calls.Browsers==0 and calls.OptionalRequires==0)
		assert(#calls.Warnings==0 and calls.StorageDestroyed==0 and not calls.CaptureHost)
	end
	-- Mandatory roots, first-frame deferral and ModuleScript loads may also
	-- suspend; a closed GUI must never receive fresh hosts after they resume.
	for _,case in {{'WaitEngine','engine'},{'WaitFrame','frame'},{'WaitRequire','require'},{'WaitWebsite','website'}}do
		local f,calls,env=setup({[case[1]]=true,Website=if case[1]=='WaitWebsite'then 'Main'else nil});local thread=coroutine.create(function()start(env)end)
		local ok,state=coroutine.resume(thread);assert(ok and state==case[2])
		f.PlayerGui:FindFirstChild('HTMLPageDemo'):Destroy();f:Drain()
		ok,state=coroutine.resume(thread);assert(ok,state)
		assert(coroutine.status(thread)=='dead' and calls.Mounts==0 and calls.Browsers==0 and calls.OptionalRequires==0)
		assert(not calls.CaptureHost and calls.StorageDestroyed==0 and #calls.Warnings==0,'Closed startup must not allocate hosts after '..case[2])
	end
	-- The default LocalScript also works when either optional root module is removed.
	for _,options in {
		{MissingWindow=true}, {MissingBrowser=true}, {MissingWindow=true,MissingBrowser=true},
		{BrowserEnabled=defaultAttributes.BrowserEnabled,MissingWindow=true,Website='Main'},
		{MissingBrowser=true,Website=defaultAttributes.Website},
		{MissingWindow=true,MissingBrowser=true,Website=defaultAttributes.Website},
	}do
		local f,calls,env,host=setup(options);start(env)
		assert(calls.Mounts==1 and calls.Browsers==0 and calls.Bindings==0 and not calls.Windows and not calls.Hosts,
			'Missing optional root modules must select the internal HTML window host')
		assert(calls.OptionalRequires==0 and #calls.Warnings==0)
		assert(calls.MountOptions.StorageHost==host and calls.MountOptions.DocumentURL==calls.ExpectedURL)
		assert(calls.CatalogGets==(if calls.ExpectedWebsite==''then 0 else 1),'The fallback uses the configured page independently of optional modules')
		assert(calls.MountOptions.JavaScriptServices.MediaCaptureHost==calls.CaptureHost,'HTML fallback receives the same configured capture host')
		assert(calls.MountOptions.Navigate==nil and calls.MountOptions.FallbackWindow~=false,
			'The internal host must own navigation and create the fallback frame')
		assert(calls.HTML==calls.ExpectedHTML and not calls.Target.Destroyed and calls.Target.BackgroundTransparency==1)
		assert(not calls.Target:FindFirstChild('StartupStatus').Visible)
		assert(#calls.Waits==1 and calls.Waits[1].Name=='HTMLEngine' and calls.LoadedWaits==0,'An absent optional module must mount HTML without waiting for it')
		calls.Target.Parent:Destroy();f:Drain();assert(calls.StorageDestroyed==1)
	end
	-- Loaded also completes when an optional root really is absent, without a
	-- subsequent Browser/WindowManager timeout or an accidental late upgrade.
	for _,missing in {{MissingBrowser=true},{MissingWindow=true},{MissingBrowser=true,MissingWindow=true}}do
		missing.NotLoaded=true
		local f,calls,env=setup(missing);local thread=coroutine.create(function()start(env)end)
		local ok,state=coroutine.resume(thread);assert(ok and state=='replication')
		assert(calls.Mounts==0 and #calls.Waits==0)
		ok,state=coroutine.resume(thread);assert(ok,state)
		assert(coroutine.status(thread)=='dead' and calls.Mounts==1 and calls.OptionalRequires==0)
		assert(calls.LoadedWaits==1 and #calls.Waits==1 and calls.Waits[1].Name=='HTMLEngine' and #calls.Warnings==0)
		calls.Target.Parent:Destroy();f:Drain();assert(calls.StorageDestroyed==1)
	end
	-- A malformed or incomplete installed integration remains a visible error.
	for _,options in {{MissingBinding=true},{MissingHost=true},{BadBrowser=true},{BadWindow=true},{FailBinding=true},{FailOpen=true}}do
		local f,calls,env=setup(options);start(env)
		assert(calls.Mounts==0 and #calls.Warnings==1)
		local screen=f.PlayerGui:FindFirstChild('HTMLPageDemo')
		local status=screen:FindFirstChild('PageTarget'):FindFirstChild('StartupStatus')
		assert(status.Visible and status.Text:find('The application could not start.',1,true))
		if options.FailBinding or options.FailOpen then assert(calls.BrowserDestroyed==1)end
		if options.FailOpen then assert(calls.BindingDestroyed==1)end
		screen:Destroy();f:Drain();assert(calls.StorageDestroyed==1)
		-- Cleanup must remain idempotent even if Open failed after its Destroying connection.
		if options.FailOpen then assert(calls.BrowserDestroyed==1 and calls.BindingDestroyed==1)end
	end
	-- Explicit standalone mode is chosen by the HTML-only project, regardless of module presence.
	for _,missing in {false,true}do
		local f,calls,env,host=setup({BrowserEnabled=standaloneAttributes.BrowserEnabled,Website=standaloneAttributes.Website,MissingBrowser=missing})
		start(env);assert(calls.Mounts==1 and calls.Browsers==0 and calls.Bindings==0)
		assert(#calls.Waits==1 and calls.Waits[1].Name=='HTMLEngine' and calls.OptionalRequires==0)
		assert(standaloneAttributes.Website=='DeepWiki' and calls.MountOptions.StorageHost==host and calls.MountOptions.DocumentURL=='http://localhost:8000/wiki1/index.html')
		assert(calls.CatalogGets==1 and calls.CatalogURLs>0,'The HTML-only project opens the same selected page without optional modules')
		assert(calls.MountOptions.Navigate==nil, 'The standalone window host owns navigation; startup must not replace its window family')
		assert(calls.HTML==calls.ExpectedHTML and not calls.Target.Destroyed)
		calls.Target.Parent:Destroy();f:Drain();assert(calls.StorageDestroyed==1)
	end
	do
		local f,calls,env=setup({MissingBrowser=true,Website='Main',FallbackWindow=false});start(env)
		assert(calls.Mounts==1 and calls.MountOptions.FallbackWindow==false and calls.MountOptions.Navigate==nil,'Explicitly embedded HTML also delegates document replacement to its engine-owned host')
		calls.Target.Parent:Destroy();f:Drain();assert(calls.StorageDestroyed==1)
	end
	do local f,calls,env=setup({ActiveDemo='FontLab'});start(env);assert(calls.Mounts==0 and #calls.Waits==0 and not f.PlayerGui:FindFirstChild('HTMLPageDemo'))end
	print('HTMLPageStartup: combined startup, initial Loaded gate/cancellation, immediate optional-root fallback, integration errors and explicit HTML-only routing passed')
end
