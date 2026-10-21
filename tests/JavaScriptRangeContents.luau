--!strict
return function(VM: any, DOM: any, Ranges: any, Contents: any, Parser: any, Node: any, fixtures: any)
	local outputs = {}
	for _, fixture in fixtures do
		local values, mutations, vm = {}, {}, nil
		local document = Parser.parseDocument('<html><body></body></html>')
		local bridge = DOM.new(document, {Window={}, ReadyState="complete", ControlAdapter={}, Changed=function()end,
			Step=function()vm.Step()end, Mutation=function(record)table.insert(mutations,record)end,
			Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,
			Get=function(value,key)return vm.Get(value,key)end})
		local globals = {document=bridge.Document, record=function(args)table.insert(values,VM.string(args[1]))end}
		vm = VM.new(globals, {MaxSteps=300000}); bridge.AttachVM(vm)
		local api = vm:Install(function()return Ranges.install(vm,globals,{Document=bridge.Document,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,Context=bridge.RangeContext(),Contents=Contents})end)
		bridge.AttachRanges(api)
		local ok, failure = pcall(function()vm:Run(fixture.source)end)
		local expected = fixture.standardExpected or fixture.expected
		assert(ok,fixture.name..': '..tostring(failure)..' (trace: '..table.concat(values,' | ')..')')
		assert(#values==#expected,fixture.name..': record count '..#values..' vs '..#expected..' ('..table.concat(values,' | ')..')')
		for index,want in expected do assert(values[index]==want,fixture.name..' record '..index..': '..tostring(values[index])..' versus '..want)end
		table.insert(outputs,vm.Object({name=fixture.name,values=vm.Array(values)},nil,{'name','values'}))
		if fixture.name:find('extract',1,true) or fixture.name:find('insertion',1,true) or fixture.name:find('surrounding same',1,true) then assert(#mutations>0,'Content writes must pass DOM mutation hooks') end
		bridge:Destroy();vm:Destroy()
	end
	local vm = VM.new({}, {MaxSteps=300000})
	local serialized = vm:ExecuteHost(function()return vm:Call(vm.Get(vm.Global.Bindings.JSON.Value,'stringify'),{vm.Array(outputs)},vm.Global.Bindings.JSON.Value)end)
	print('RANGE_CONTENTS_RESULT '..serialized);vm:Destroy()
	-- A bounded failed copy performs no source write and can be retried through
	-- a fresh script entry. Disposal clears Range state and rejects held methods.
	local small, api;local rejectStructure=false;local mutationCount=0
	local document=Parser.parseDocument('<html><body></body></html>')
	local bridge=DOM.new(document,{Window={},ReadyState="complete",Changed=function()end,Step=function()small.Step()end,
		ValidateStructure=function()assert(not rejectStructure,'Renderer rejected Range insertion')end,Mutation=function()mutationCount+=1 end,
		Call=function(fn,args,receiver)return small:Call(fn,args,receiver)end,Get=function(value,key)return small.Get(value,key)end})
	local globals={document=bridge.Document};small=VM.new(globals,{MaxSteps=1000});bridge.AttachVM(small)
	api=small:Install(function()return Ranges.install(small,globals,{Document=bridge.Document,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,Context=bridge.RangeContext(),Contents=Contents})end);bridge.AttachRanges(api)
	small:Run("const e=document.createElement('div');e.textContent='x'.repeat(2000);const r=document.createRange();r.selectNodeContents(e.firstChild);const held=r.cloneContents;")
	local ok,failure=pcall(function()small:Run('r.extractContents()')end)
	assert(not ok and tostring(failure):find('instruction budget exceeded',1,true),'Content traversal must share the author instruction budget')
	small:Run("const recovered=e.textContent.length===2000&&r.startOffset===0&&r.endOffset===2000;r.setEnd(e.firstChild,2);const prefix=r.extractContents().textContent;")
	assert(small.Global.Bindings.recovered.Value and small.Global.Bindings.prefix.Value=='xx','A failed private clone leaves source unchanged and has no stuck active state')
	small:Run("r.setStart(e.firstChild,1);r.collapse(true);const proposed=document.createElement('i');")
	local before=mutationCount;rejectStructure=true
	assert(not pcall(function()small:Run('r.insertNode(proposed)')end),'Renderer guard must reject unsupported insertion')
	rejectStructure=false;assert(mutationCount==before,'Rejected Range preflight must not split text or emit a mutation')
	small:Run("const preflightIntact=e.childNodes.length===1&&r.startOffset===1&&r.collapsed&&proposed.parentNode===null;")
	assert(small.Global.Bindings.preflightIntact.Value,'Rejected renderer preflight preserves source and all Range boundaries')
	local range=small.Global.Bindings.r.Value;bridge:Destroy();assert(not api.Alive and range.RangeState==nil)
	assert(not pcall(function()small:Run('held.call(r)')end),'Held content methods reject a destroyed owning DOM')
	small:Destroy()
	-- ShadowRoot is the data DOM's existing DocumentFragment subtype. Exercise
	-- it privately; this does not promise a public attachShadow implementation.
	local shadowVM
	local shadowDocument=Parser.parseDocument('<html><body></body></html>')
	local host=Node.element('div',{});local shadow=Node.shadowRoot('open',host)
	host.InternalShadowRoot=shadow;Node.append(shadowDocument.Children[1].Children[1],host)
	Node.append(shadow,Node.text('A'));Node.append(shadow,Node.text('B'))
	local shadowBridge=DOM.new(shadowDocument,{Window={},ReadyState='complete',Changed=function()end,Step=function()shadowVM.Step()end,
		Call=function(fn,args,receiver)return shadowVM:Call(fn,args,receiver)end,Get=function(v,k)return shadowVM.Get(v,k)end})
	local shadowGlobals={document=shadowBridge.Document,privateShadow=shadowBridge.Wrap(shadow)}
	shadowVM=VM.new(shadowGlobals,{MaxSteps=300000});shadowBridge.AttachVM(shadowVM)
	local shadowRanges=shadowVM:Install(function()return Ranges.install(shadowVM,shadowGlobals,{Document=shadowBridge.Document,Wrap=shadowBridge.Wrap,Unwrap=shadowBridge.Unwrap,Context=shadowBridge.RangeContext(),Contents=Contents})end)
	shadowBridge.AttachRanges(shadowRanges)
	shadowVM:Run("const r=document.createRange(),target=document.createElement('div');r.selectNodeContents(privateShadow);const copied=r.cloneContents();const copiedGood=copied.nodeType===11&&copied.textContent==='AB';r.setStart(target,0);r.collapse(true);r.insertNode(privateShadow);const insertedGood=target.textContent==='AB'&&privateShadow.childNodes.length===0&&r.startOffset===0&&r.endOffset===2;let surroundError='';try{r.surroundContents(privateShadow)}catch(e){surroundError=e.name}const rejectedGood=surroundError==='InvalidNodeTypeError'&&target.textContent==='AB';r.setStart(privateShadow,0);r.collapse(true);const t=document.createTextNode('C');r.insertNode(t);const containerGood=privateShadow.textContent==='C'&&r.startContainer===privateShadow&&r.startOffset===0&&r.endOffset===1;")
	for _,name in {'copiedGood','insertedGood','rejectedGood','containerGood'}do assert(shadowVM.Global.Bindings[name].Value,'Private ShadowRoot Range contents regression: '..name)end
	shadowBridge:Destroy();shadowVM:Destroy()
	print('Range contents: '..#fixtures..' Luau/native-authored cases plus budget recovery, renderer preflight and disposal checks passed.')
end
