--!strict
return function(Parser,Node,Runtime,Events,Template,fixture)
	local doc=Parser.parseDocument('<!doctype html><title>Template documents</title><body><template id="initial"><span>one</span><template><b>two</b></template></template></body>')
	local initial=Node.findById(doc,'initial');local inert=Template.owner(doc)
	assert(initial.OwnerDocument==doc and initial.Content.OwnerDocument==inert)
	assert(initial.Content.Children[1].OwnerDocument==inert and initial.Content.Children[2].Content.OwnerDocument==inert,'Parser must own contents before JS attaches')
	local events=Events.new(error)
	local realm=Runtime.new(doc,{URL='https://example.test/templates',Events=events,ControlAdapter={},Schedule=function()end})
	realm:Run(fixture.source..'\nconst templateResults=templateDocumentChecks();')
	assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,'\n'))
	for index,expected in fixture.records do
		realm:Run('window.templateResult=JSON.stringify(templateResults['..tostring(index-1)..'].value);')
		assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,'\n'))
		local actual=realm.Window.Get('templateResult')
		assert(actual==expected.json,expected.name..'\nexpected '..expected.json..'\nactual '..tostring(actual))
	end
	realm:Destroy();events:Destroy()
	-- Two genuinely independent runtime bridges must route adoption of inert
	-- descendants through their original host, preserving author wrappers/state.
	local sourceEvents,targetEvents=Events.new(error),Events.new(error)
	local sourceCalls,targetCalls={},{}
	local source=Runtime.new(Parser.parseDocument('<!doctype html><template id="foreign"><input value="start"><span>label</span></template>'),
		{URL='https://example.test/source',Events=sourceEvents,ControlAdapter={},Schedule=function()end,
		Adopted=function(node)table.insert(sourceCalls,node)end})
	local target=Runtime.new(Parser.parseDocument('<!doctype html><body></body>'),
		{URL='https://example.test/target',Events=targetEvents,ControlAdapter={},Schedule=function()end,
		Adopted=function(node)table.insert(targetCalls,node)end})
	assert(source:Run('window.foreignTemplate=document.getElementById("foreign");window.foreignContent=foreignTemplate.content;window.foreignInput=foreignContent.firstChild;foreignInput.value="typed";foreignInput.expando=17;window.foreignClicks=0;foreignInput.addEventListener("click",()=>foreignClicks++);'))
	local foreign,foreignContent,foreignInput=source.Window.Get('foreignTemplate'),source.Window.Get('foreignContent'),source.Window.Get('foreignInput')
	target.VM.Global.Bindings.foreignTemplate={Value=foreign};target.VM.Global.Bindings.foreignContent={Value=foreignContent};target.VM.Global.Bindings.foreignInput={Value=foreignInput}
	assert(target:Run('document.adoptNode(foreignTemplate);if(foreignTemplate.content!==foreignContent||foreignInput!==foreignContent.firstChild||foreignInput.ownerDocument!==document.createElement("template").content.ownerDocument||foreignInput.value!=="typed"||foreignInput.expando!==17)throw new Error("Cross-realm template state");document.body.append(foreignInput);foreignInput.click();'))
	assert(#source.Diagnostics==0 and #target.Diagnostics==0,table.concat(source.Diagnostics,' | ')..table.concat(target.Diagnostics,' | '))
	assert(source.Window.Get('foreignClicks')==1,'Cross-realm template extraction retains original listener')
	assert(table.find(sourceCalls,foreignContent.DOMNode)and table.find(sourceCalls,foreignInput.DOMNode),'Inert descendants invoke original source host adoption steps')
	assert(#targetCalls==1 and targetCalls[1]==foreignInput.DOMNode,'Later extraction invokes the current target inert document host')
	source:Destroy();target:Destroy();sourceEvents:Destroy();targetEvents:Destroy()
	-- A source document owns the association, but no global strong cache keeps
	-- the discarded document or its inert owner alive.
	local weak=setmetatable({},{__mode='v'})
	do local discarded=Node.document();weak[1]=discarded;weak[2]=Template.owner(discarded)end
	for batch=1,2048 do if weak[1]==nil and weak[2]==nil then break end
		local garbage=table.create(2048);for index=1,2048 do garbage[index]={batch,index}end
	end
	assert(weak[1]==nil and weak[2]==nil,'Discarded template documents must be collectable')
	print('H05 templates: '..tostring(#fixture.records)..' native ownership/namespace/clone/adoption/fragment/descriptor records + initial parser ownership + cross-realm listener/input/host migration + discarded-document collection passed')
end
