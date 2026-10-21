--!strict
return function(Parser,Runtime,VM,Events,fixture)
	local function find(document,id)
		local pending={document};while #pending>0 do local node=table.remove(pending);if node.Kind=='Element'and node.Attributes.id==id then return node end;for _,child in node.Children do table.insert(pending,child)end end
	end
	local function options(document,case,events,diagnostics,url)
		return {Events=events,ControlAdapter={},URL=url or case.url or 'https://example.test/handlers',ModuleSources=case.moduleSources,ImportMap=if url then case.sourceImportMap else case.importMap,
			Schedule=function()end,GetBaseURL=if case.moduleSources then function()local base=find(document,'base');return if base then base.Attributes.href else url or case.url end else nil,
			Diagnostic=function(message)table.insert(diagnostics,message)end}
	end
	for index,case in fixture.cases do
		local document=Parser.parseDocument(case.html)
		local diagnostics={};local events=Events.new(error)
		local runtime=Runtime.new(document,options(document,case,events,diagnostics))
		local source,sourceEvents
		if case.sourceHTML then
			sourceEvents=Events.new(error);local sourceDocument=Parser.parseDocument(case.sourceHTML);source=Runtime.new(sourceDocument,options(sourceDocument,case,sourceEvents,diagnostics,'https://example.test/source'))
			local ok,message=source:Run(case.sourcePrep);assert(ok,case.name..': '..tostring(message))
			runtime.Window.Set('foreignSource',source.Window)
			for _,key in case.sourceKeys or {'compiled','uncompiled','original'}do runtime.Window.Set(key,source.Window.Get(key))end
		end
		if case.prep then local ok,message=runtime:Run(case.prep,nil,case.prepURL);assert(ok,case.name..': '..tostring(message))end
		if case.hostActions then
			assert(runtime:Run('window.trustedEvents=[];document.addEventListener("click",e=>trustedEvents.push({trusted:e.isTrusted,baseURI:document.baseURI}),true)'))
			for _,action in case.hostActions do
				if action.script then local ok,message=runtime:Run(action.script);assert(ok,case.name..': '..tostring(message))
				else events:Emit(assert(find(document,action.click)),'click',{isTrusted=true})end
			end
			assert(runtime:Run('globalThis.hostEventsResult=JSON.stringify(trustedEvents)'))
			-- Native trusted event metadata is provenance. Compare the same
			-- DOM/base/host dispatch through the real Runtime input bridge.
			local encoded={};for _,event in case.nativeHostEvents do table.insert(encoded,'{"trusted":true,"baseURI":"'..event.baseURI..'"}')end
			assert(runtime.Window.Get('hostEventsResult')=='['..table.concat(encoded,',')..']',case.name..': host click/base provenance differs')
		end
		local ok,message=runtime:Run('globalThis.handlerResult='..case.action)
		assert(ok,case.name..': '..tostring(message))
		local actual=runtime.Window.Get('handlerResult')
		if case.await then
			local settled=false;runtime.Promises:Await(actual,function(args)actual=args[1];settled=true end,function(args)error(case.name..': rejected '..VM.string(args[1]))end)
			for _=1,200 do runtime:PumpTasks();runtime.EventLoop:Checkpoint();if source then source:PumpTasks();source.EventLoop:Checkpoint()end;if settled then break end end
			assert(settled,case.name..': imports did not settle')
		end
		local expected=case.specExpected or case.expected
		assert(actual==expected,case.name..'\nexpected '..expected..'\nactual '..VM.string(actual)..'\ndiagnostics '..table.concat(diagnostics,'\n'))
		assert(#diagnostics==0,case.name..': '..table.concat(diagnostics,'\n'))
		runtime:Destroy();events:Destroy()
		if source then source:Destroy();sourceEvents:Destroy()end
	end
	local document=Parser.parseDocument('<!doctype html><div id=duplicate></div><span id=duplicate></span>')
	local events=Events.new(error);local runtime=Runtime.new(document,{Events=events})
	local view=runtime.Window.Get('duplicate');local named=runtime.WindowNamedProperties
	runtime:Destroy();events:Destroy()
	assert(not pcall(view.Get,'length'),'Disposed named collections remain readable')
	assert(not pcall(named.GetOwnPropertyDescriptor,'duplicate'),'Disposed named window scope remains readable')
	local discarded=setmetatable({},{__mode='k'})
	local document=Parser.parseDocument('<!doctype html><div id=group></div><span id=group></span><div id=discarded></div>')
	local events=Events.new(error);local runtime=Runtime.new(document,{Events=events})
	local function discardNamedTrees()
		local node=find(document,'discarded');discarded[node]=true
		assert(runtime:Run([[window.keptNamed=window.group;window.discarded;document.getElementById('discarded').remove();
			window.detachedForTest=new DOMParser().parseFromString('<form name=peer></form><img name=peer>','text/html');
			window.detachedListForTest=detachedForTest.peer;
			if(detachedListForTest.length!==2)throw new Error('Detached document names were not indexed');]]))
		local detached=runtime.Window.Get('detachedForTest').DOMNode;discarded[detached]=true
		assert(detached.DOMNamedSnapshots,'Detached names must use a retained document-owned index')
		assert(runtime:Run('window.detachedForTest=null;window.detachedListForTest=null'))
		runtime:Flush();runtime:PumpTasks()
	end
	discardNamedTrees()
	for batch=1,2048 do
		if next(discarded)==nil then break end
		local garbage=table.create(2048);for index=1,2048 do garbage[index]={batch,index}end
	end
	local retained=next(discarded)
	assert(retained==nil,'Active named registries must release removed nodes and detached named documents without another lookup: '..tostring(retained and(retained.Kind..'/'..(retained.Name or''))))
	assert(runtime:Run('if(window.group!==window.keptNamed||keptNamed.length!==2)throw new Error("Named collection identity was lost during GC")'))
	assert(document.DOMNamedSnapshots,'Connected index stays owned by its document')
	runtime:Destroy();events:Destroy();assert(document.DOMNamedSnapshots==nil,'Destroy removes retained named snapshots')
	print('HTML handler attributes: '..#fixture.cases..' native parser/source/order/scope/inert/forwarding/legacy/reset/form sequences passed')
end
