--!strict
-- Actual JS storage uses memory shared within one run, never a server transport.
return function(Memory,Parser,Runtime,Events,projects,startRetiredStarter)
	for name,project in projects do
		local servers=project.tree.ServerScriptService
		assert(servers and servers["$ignoreUnknownInstances"]==true,name.." must preserve unrelated game server scripts")
		local guards=0
		local function inspect(node)
			for key,value in node do
				assert(key~="BrowserServer",name.." must not map the DataStore backend")
				if key=="BrowserPersistenceServer"or key=="HTMLStorageServer"then
					assert(node==servers and value["$path"]=="examples/compat/RetiredPersistence.server.luau"and value["$properties"].Disabled==true,name.." replaces only legacy bootstrap names with disabled no-op source")
					guards+=1
				end
				if type(value)=="table"then inspect(value)
				elseif key=="$path"then
					assert(value~="src/BrowserServer"and value~="examples/BrowserPersistence.server.luau"and value~="examples/HTMLStorage.server.luau",name.." must not alias a persistence server")
				end
			end
		end
		inspect(project.tree)
		assert(guards==2,name.." must retire both previously synced bootstrap scripts")
	end
	local hostile=setmetatable({},{__index=function()error("Retired starter must not access services, modules, instances or tasks")end})
	assert(pcall(startRetiredStarter,hostile,hostile,hostile,hostile),"The actual compatibility source remains inert even if enabled manually")
	local function realm(host,url)
		local output,diagnostics={},{};local events=Events.new(error)
		local runtime=Runtime.new(Parser.parseDocument("<html><body></body></html>"),{URL=url,Events=events,GetStorageArea=host:Prepare(url),
			Schedule=function()end,Console=function(_,message)table.insert(output,message)end,
			Diagnostic=function(message)table.insert(diagnostics,message)end})
		local page={Runtime=runtime,Output=output}
		function page:Run(source)
			runtime:Run(source);assert(#diagnostics==0,table.concat(diagnostics," / "))
		end
		function page:Destroy()runtime:Destroy();events:Destroy()end
		return page
	end
	local host=Memory.new()
	local areas=host:Prepare("HTTPS://storage.test:443/start")
	assert(areas("local")==host:Prepare("https://storage.test/next?x=2#view")("local"),"Origin canonicalization shares same-run storage across navigation")
	assert(areas("local")~=areas("session")and areas("local").Durability=="memory"and areas("local").Commit==nil,"Local and session stores are distinct, bounded memory areas without a save callback")
	local observed={};local removeObserver=host:Observe("https://storage.test/next",function(status,message)table.insert(observed,{status,message})end)
	assert(observed[1][1]=="memory"and observed[1][2]==nil,"Storage status never implies a durable save")
	local source=realm(host,"https://storage.test/source")
	source:Run([[localStorage.setItem('draft','current-run');sessionStorage.setItem('step','two');console.log(localStorage.getItem('draft'),sessionStorage.getItem('step'));]])
	assert(source.Output[1]=="current-run two")
	source:Destroy()
	local nextPage=realm(host,"https://storage.test/next")
	nextPage:Run([[console.log(localStorage.getItem('draft'),sessionStorage.getItem('step'));]])
	assert(nextPage.Output[1]=="current-run two","Navigation preserves both origin caches during this run")
	local popup=realm(host,"https://storage.test/popup")
	popup:Run([[var seen=[];window.addEventListener('storage',e=>seen.push(e.key+'|'+e.newValue));]])
	nextPage:Run([[localStorage.setItem('draft','changed');sessionStorage.setItem('step','three');]])
	popup.Runtime:PumpTasks()
	popup:Run([[console.log(localStorage.getItem('draft'),sessionStorage.getItem('step'),seen.join(','));]])
	assert(popup.Output[1]=="changed three draft|changed,step|three","Same-run popup peers share values and receive actual queued storage events")
	local foreign=realm(host,"https://other.test/page")
	foreign:Run([[console.log(localStorage.getItem('draft'),sessionStorage.getItem('step'));]])
	assert(foreign.Output[1]=="null null","Another origin has independent storage")
	local fresh=Memory.new();local rejoin=realm(fresh,"https://storage.test/rejoin")
	rejoin:Run([[console.log(localStorage.getItem('draft'),sessionStorage.getItem('step'));]])
	assert(rejoin.Output[1]=="null null","A new game/browser host never restores values from a previous host")
	for _,url in {"about:blank","data:text/html,test","file:///test.html"}do
		assert(host:Prepare(url)("local")==nil and host:Prepare(url)("session")==nil,"Opaque and unsupported origins retain denied storage")
	end
	assert(host:Flush(),"Memory flush returns immediately without tasks, RPCs or writes")
	removeObserver();assert(#host.Observers==0)
	nextPage:Destroy();popup:Destroy();foreign:Destroy();rejoin:Destroy();fresh:Destroy()
	host:Destroy();host:Destroy()
	for _,kind in {"local","session"}do
		assert(areas(kind)==nil,"Disposed host closures cannot regain a storage area")
	end
	assert(next(host.Origins)==nil and host.OriginCount==0 and not host:Flush())
	local isolated=Memory.new();local kept=isolated:Prepare("https://storage.test")("local")
	kept.Values.x="discarded";kept.Order[1]="x";kept.Bytes=20;kept.Subscribers[1]={}
	isolated:Destroy()
	assert(next(kept.Values)==nil and #kept.Order==0 and #kept.Subscribers==0 and kept.Bytes==0,"Destroy removes retained values, byte accounting and listeners")
	print("Session-only storage: real JS navigation/popups/events/origin separation, fresh-run empty stores, synchronous disposal, disabled inert legacy guards and all 3 projects without enabled persistence servers passed")
end
