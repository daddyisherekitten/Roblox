--!strict
return function(loadEngine: any,WorkContext: any)
	local calls = {}
	local parser = {parse=function() return 'fragment' end,parseDocument=function() return 'document' end}
	local pages = {resolveURL=function() return {Kind='internal',Name='Main'} end,get=function() return {HTML='child'} end}
	local mounted = 0
	local fallbackMounts=0
	local standalone={mount=function(target,html,options,raw)
		fallbackMounts+=1
		local page=raw(target,html,options);page.FallbackWrapped=options.FallbackWindow~=false;return page
	end}
	local engine = loadEngine(function(id)
		calls[id] = (calls[id] or 0) + 1
		if id == 'HTML/Parser' then return parser end
		if id == 'Websites' then return pages end
		if id == 'WorkContext' then return WorkContext end
		if id == 'Rendering/StandaloneHost' then return standalone end
		if id == 'Rendering/HTMLPage' then return {mount=function(target,html,options)
			mounted += 1
			return {Target=target,HTML=html,Options=options}
		end} end
		return {}
	end)
	assert(engine.parseHTML()=='fragment' and engine.parseDocument()=='document')
	assert(calls['Rendering/HTMLPage']==nil and calls['Rendering/StandaloneHost']==nil,'Parser-only imports must not load the rendering/input or fallback host graph')
	local options={BaseURL='example',RenderWorkBudgetMS=0,FallbackWindow=false}
	local page=engine.mountHTML({},'<p>Hello</p>',options)
	assert(mounted==1 and page.HTML=='<p>Hello</p>' and page.Options~=options)
	assert(options.IFrameResolver==nil and page.Options.IFrameResolver('','about:blank').Kind=='internal')
	assert(not page.FallbackWrapped and fallbackMounts==1,'Explicit embedding keeps popup/dialog integration without wrapping the main page')
	assert(engine.mountHTML({},'<p>Standalone</p>',{RenderWorkBudgetMS=0}).FallbackWrapped==true and fallbackMounts==2,'A top-level mount defaults to the independent fallback host')
	local external={Open=function()end}
	engine.mountHTML({},'',{RenderWorkBudgetMS=0,JavaScriptServices={WindowHost=external}})
	engine.mountHTML({},'',{RenderWorkBudgetMS=0,IFrameDepth=1})
	engine.mountHTML({},'',{RenderWorkBudgetMS=0,IsSrcdoc=true})
	assert(fallbackMounts==2,'Configured external hosts and embedded documents never acquire another fallback host')
	local custom=function() return 'custom' end
	assert(engine.mountHTML({},'',{IFrameResolver=custom,RenderWorkBudgetMS=0}).Options.IFrameResolver==custom)
	local now,waits,imports,connections=0,0,{},0
	local died
	local target={Destroying={Connect=function(_,fn)
		connections+=1;died=fn;return {Disconnect=function()connections-=1 end}
	end}}
	local leases={}
	local cooperative={checkpoint=WorkContext.checkpoint,budget=WorkContext.budget,new=function(milliseconds,services)
		services.Task={wait=function()waits+=1;now+=.016;coroutine.yield('cold-import')end}
		services.Clock=function()return now end
		local value=WorkContext.new(milliseconds,services);table.insert(leases,value);return value
	end}
	local function module(path)
		local children={}
		return {Path=path,FindFirstChild=function(_,name)
			if not children[name]then children[name]=module(if path==''then name else path..'/'..name)end
			return children[name]
		end}
	end
	local cancel=false
	local cold=loadEngine(function(id)
		if id=='HTML/Parser'then return parser elseif id=='Websites'then return pages elseif id=='WorkContext'then return cooperative end
		if id=='Rendering/LoadingModules'then return {'First','Second/Child'}end
		if id=='Rendering/StandaloneHost'then return standalone end
		if id=='Rendering/HTMLPage'then return {mount=function()return {Ready=true}end}end
		if type(id)=='table'then table.insert(imports,id.Path);now+=.0001;if cancel then died()end end
		return {}
	end,module(''))
	local function drive(fn)
		local thread=coroutine.create(fn);while coroutine.status(thread)~='dead'do local ok,message=coroutine.resume(thread);assert(ok,tostring(message))end
	end
	drive(function()
		local loaded=cold.mountHTML(target,'');assert(loaded.Ready and loaded.ColdLoadStats.Modules==2)
	end)
	assert(waits==2 and table.concat(imports,',')=='First,Second/Child'and connections==0 and not leases[1].Active,
		'Cheap imports share a bounded slice between the initial and presentation pauses and release their target listener')
	drive(function()
		local loaded=cold.mountHTML(target,'');assert(loaded.Ready and loaded.ColdLoadStats.Modules==0)
	end)
	assert(#imports==2,'Later page mounts skip the already loaded module graph')
	local cancelledEngine=loadEngine(function(id)
		if id=='WorkContext'then return cooperative elseif id=='HTML/Parser'then return parser elseif id=='Websites'then return pages end
		if id=='Rendering/LoadingModules'then return {'First','Second/Child'}end
		if type(id)=='table'then died();now+=.003 end
		return {}
	end,module(''))
	drive(function()local ok,message=pcall(cancelledEngine.mountHTML,target,'');assert(not ok and WorkContext.isCancelled(message))end)
	assert(connections==0 and not leases[#leases].Active,'Disposal during cold imports cancels before mounting a document')
	-- Actual entry code with deterministic native import costs. These are
	-- scheduler/operation counts, not measurements of Studio frame rate.
	local function fixture(costs)
		local state={Time=0,Waits=0,Batch=0,Batches={},Imports={},Gate={Owners={}}}
		local scoped={checkpoint=WorkContext.checkpoint,budget=WorkContext.budget,new=function(milliseconds,services)
			services.Clock=function()return state.Time end;services.FrameGate=state.Gate
			services.Task={wait=function()
				table.insert(state.Batches,state.Batch);state.Batch=0;state.Waits+=1;state.Time+=.016;state.Gate.Deadline=nil
				coroutine.yield('cold-import')
			end}
			return WorkContext.new(milliseconds,services)
		end}
		local paths={};for index in costs do table.insert(paths,'Cold'..index)end
		local value=loadEngine(function(id)
			if id=='WorkContext'then return scoped elseif id=='HTML/Parser'then return parser elseif id=='Websites'then return pages end
			if id=='Rendering/LoadingModules'then return paths end
			if id=='Rendering/StandaloneHost'then return standalone end
			if id=='Rendering/HTMLPage'then return {mount=function()return {Ready=true}end}end
			if type(id)=='table'then
				local index=tonumber(id.Path:match('Cold(%d+)'))
				if index then
					state.Imports[index]=(state.Imports[index]or 0)+1;state.Batch+=1;state.Time+=costs[index]
					if state.Fail==index then error('native import failure',0)end
				end
			end
			return {}
		end,module(''))
		return value,state
	end
	local batched,cheap=fixture({.0001,.0001,.0001,.0001,.0001,.0001,.0001,.0001})
	drive(function()assert(batched.mountHTML({},'').ColdLoadStats.Modules==8)end)
	assert(cheap.Waits==3 and table.concat(cheap.Batches,',')=='0,4,4','Eight cheap imports need three pauses while at most four run in one slice')
	local slowEngine,slow=fixture({.003,.0001,.0001,.0001,.0001})
	drive(function()slowEngine.mountHTML({},'')end)
	assert(slow.Batches[2]==1,'A native import exceeding the deadline yields before another import, regardless of the four-import cap')
	local sharedEngine,shared=fixture({.0001,.0001,.0001,.0001,.0001,.0001,.0001,.0001})
	local a=coroutine.create(function()sharedEngine.mountHTML({},'')end)
	local b=coroutine.create(function()sharedEngine.mountHTML({},'')end)
	for _=1,10 do for _,thread in {a,b}do if coroutine.status(thread)~='dead'then local ok,message=coroutine.resume(thread);assert(ok,tostring(message))end end end
	assert(coroutine.status(a)=='dead'and coroutine.status(b)=='dead'and next(shared.Gate.Owners)==nil,'Overlapping loaders finish and release their shared frame gate')
	for index=1,8 do assert(shared.Imports[index]==1,'Overlapping mounts do not repeat successful native imports')end
	local retryEngine,retry=fixture({.0001,.0001,.0001});retry.Fail=2
	drive(function()local ok,message=pcall(retryEngine.mountHTML,{},'');assert(not ok and tostring(message):find('native import failure',1,true))end)
	retry.Fail=nil
	drive(function()assert(retryEngine.mountHTML({},'').Ready)end)
	assert(retry.Imports[1]==1 and retry.Imports[2]==2 and retry.Imports[3]==1,'Failed imports retry; successful work before the failure is reused')
	print('Cold import scheduling: 8 cheap modules / 3 waits; costly import pauses immediately; overlapping and failed loads reuse only successful work')
	print('Engine entry: parser-only imports defer HTMLPage; mount options and iframe API preserved')
end
