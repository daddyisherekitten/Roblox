--!strict
return function(Parser,Runtime,Events,fixture)
	for _,case in fixture.cases do
		local document=Parser.parseDocument(case.html);local events=Events.new(error)
		local runtime=Runtime.new(document,{Events=events,ControlAdapter={},Schedule=function()end})
		local ok,message=runtime:Run('globalThis.collectionResult='..case.action)
		assert(ok,case.name..': '..tostring(message))
		local actual=runtime.Window.Get('collectionResult')
		assert(actual==case.expected,case.name..'\nexpected '..case.expected..'\nactual '..tostring(actual))
		assert(#runtime.Diagnostics==0,case.name..': '..table.concat(runtime.Diagnostics,' | '))
		runtime:Destroy();events:Destroy()
		assert(document.DOMCollectionSnapshots==nil,'Destroy must release document-owned collection snapshots')
	end
	local document=Parser.parseDocument('<!doctype html><form id=discarded></form><a id=link href="#">Text</a>')
	local events=Events.new(error);local runtime=Runtime.new(document,{Events=events,ControlAdapter={}})
	assert(runtime:Run('window.keptForms=document.forms;window.keptLinks=document.links;keptForms.length;keptLinks.length'))
	local state=next(document.DOMCollectionSnapshots);state=document.DOMCollectionSnapshots[state]
	local entries=state.Entries.forms
	assert(runtime:Run("document.getElementById('link').style.color='red';document.getElementById('link').firstChild.data='New text';keptForms.length"))
	assert(state.Entries.forms==entries,'Paint and character changes must not rescan document list membership')
	local linkEntries=state.Entries.links
	assert(runtime:Run("document.getElementById('link').setAttributeNS('urn:foreign','href','other');keptLinks.length"))
	assert(state.Entries.links==linkEntries,'Foreign href attributes cannot invalidate null-namespace link membership')
	assert(runtime:Run("document.getElementById('link').removeAttribute('href');keptLinks.length;keptForms.length"))
	assert(state.Entries.forms==entries and #state.Entries.links==0,'Href changes invalidate only link membership')
	assert(runtime:Run("document.getElementById('discarded').remove()"))
	assert(next(state.Entries)==nil,'Removal releases cached nodes immediately before another list lookup')
	assert(runtime:Run("if(keptForms.length!==0||keptForms!==document.forms)throw new Error('Live retained list did not update')"))
	local list=runtime.Window.Get('keptForms');runtime:Destroy();events:Destroy()
	assert(not pcall(list.Get,'length'),'Disposed live lists cannot access released documents')
	local discarded=setmetatable({},{__mode='k'})
	local plainControl=setmetatable({},{__mode='k'})
	local document=Parser.parseDocument('<!doctype html><form id=kept></form><form id=discarded></form>')
	local events=Events.new(error);local runtime=Runtime.new(document,{Events=events})
	local function discardLists()
		assert(runtime:Run([[window.keptForms=document.forms;keptForms.length;
			window.detachedForTest=new DOMParser().parseFromString('<form></form><img>','text/html');
			window.detachedListForTest=detachedForTest.forms;detachedListForTest.length;]]))
		discarded[runtime.Window.Get('detachedForTest').DOMNode]=true
		assert(runtime:Run("window.removedForTest=document.getElementById('discarded')"))
		discarded[runtime.Window.Get('removedForTest').DOMNode]=true
		assert(runtime:Run('removedForTest.remove();window.removedForTest=null;window.detachedForTest=null;window.detachedListForTest=null'))
		runtime:Flush();runtime:PumpTasks()
	end
	-- A completed, discarded coroutine excludes stale main-stack registers.
	-- The independent plain object proves that this bounded allocation budget
	-- actually reached collection, rather than only testing DOM registry keys.
	local frame=coroutine.create(function()plainControl[{}]=true;discardLists()end)
	assert(coroutine.resume(frame));assert(coroutine.status(frame)=='dead');frame=nil
	for batch=1,2048 do
		if next(discarded)==nil and next(plainControl)==nil then break end
		local garbage=table.create(2048);for index=1,2048 do garbage[index]={batch,index}end
	end
	assert(next(plainControl)==nil,'Document collection GC proof must collect an independent plain-object control within the same budget')
	assert(next(discarded)==nil,'Document list registry must release removed nodes and detached documents without another lookup')
	assert(runtime:Run("if(keptForms!==document.forms||keptForms.length!==1||keptForms[0].id!=='kept')throw new Error('Retained list lost its live identity during GC')"))
	runtime:Destroy();events:Destroy()
	print('Document collections: '..#fixture.cases..' native cases; retained live views, independent membership caches and disposal passed')
end
