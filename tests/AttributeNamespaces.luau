--!strict
return function(Parser,Runtime,Events,fixture)
	for _,case in fixture.cases do
		local document=Parser.parseDocument(case.html);local events=Events.new(error)
		local runtime=Runtime.new(document,{Events=events,ControlAdapter={},Schedule=function()end})
		local ok,message=runtime:Run('globalThis.namespaceResult='..case.action)
		assert(ok,case.name..': '..tostring(message))
		local actual=runtime.Window.Get('namespaceResult')
		local expected=case.specExpected or case.expected
		assert(actual==expected,case.name..'\nexpected '..expected..'\nactual '..tostring(actual))
		assert(#runtime.Diagnostics==0,case.name..': '..table.concat(runtime.Diagnostics,' | '))
		runtime:Destroy();events:Destroy()
	end
	local document=Parser.parseDocument('<!doctype html><div id=e title=original></div>')
	local events=Events.new(error)
	local runtime=Runtime.new(document,{Events=events,ValidateDataAttribute=function(_,_,value)
		if value=='rejected'then error('Rejected by host before attribute publication')end
	end})
	assert(runtime:Run([=[
const element=document.getElementById('e'),original=element.getAttributeNode('title');
const incoming=document.createAttribute('title');incoming.value='rejected';
let rejected=false;try{element.setAttributeNode(incoming);}catch(error){rejected=true;}
if(!rejected||original.ownerElement!==element||incoming.ownerElement!==null||original.value!=='original'||element.getAttributeNode('title')!==original)throw new Error('rejected replacement changed Attr ownership');
window.keptMap=element.attributes;
]=]))
	local discarded=setmetatable({},{__mode='k'})
	local function discardMaps()
		assert(runtime:Run([=[
window.transientElement=document.createElement('div');transientElement.setAttributeNS('urn:temporary','p:title','one');
window.transientMap=transientElement.attributes;transientMap.item(0);
window.detachedForTest=new DOMParser().parseFromString('<div title=one></div>','text/html');
window.detachedMap=detachedForTest.body.firstChild.attributes;detachedMap.length;
]=]))
		discarded[runtime.Window.Get('transientElement').DOMNode]=true
		discarded[runtime.Window.Get('detachedForTest').DOMNode]=true
		assert(runtime:Run('window.transientElement=null;window.transientMap=null;window.detachedForTest=null;window.detachedMap=null'))
		runtime:Flush();runtime:PumpTasks()
	end
	discardMaps()
	for batch=1,2048 do
		if next(discarded)==nil then break end
		local garbage=table.create(2048);for index=1,2048 do garbage[index]={batch,index}end
	end
	assert(next(discarded)==nil,'NamedNodeMap cache cannot root unused elements or detached documents')
	assert(runtime:Run("if(keptMap!==document.getElementById('e').attributes||keptMap.title!==original)throw new Error('Retained attribute map lost identity during GC')"))
	assert(runtime:Run("element.setAttributeNS('urn:repeat','title','foreign');window.heldList=document.getElementsByClassName('member');heldList.length;"))
	local querySteps=0;local oldStep=runtime.VM.Step
	runtime.VM.Step=function()querySteps+=1;oldStep()end
	assert(runtime:Run("element.setAttributeNS('urn:repeat','title','foreign');"))
	local heldList=runtime.Window.Get('heldList');querySteps=0
	assert(heldList.Get('length')==0 and querySteps==0,'An unchanged namespaced value must not invalidate a live query snapshot')
	assert(runtime:Run("element.setAttributeNS('urn:repeat','title','changed');"));querySteps=0
	assert(heldList.Get('length')==0 and querySteps>0,'A changed namespaced value invalidates and charges the same live query path')
	runtime.VM.Step=oldStep
	runtime:Destroy();events:Destroy()
	print('Attribute namespaces: '..#fixture.cases..' native identity/reflection/selector/reaction cases passed')
end
