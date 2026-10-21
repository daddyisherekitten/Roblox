--!strict
return function(Parser,Runtime,Events,fixture)
	local expectedCases={
		['areas interface contract']=true,
		['areas readonly and branded receivers']=true,
		['areas is map only and other nodes keep expandos']=true,
		['areas light tree and expanded names']=true,
		['areas live names order and reserved members']=true,
		['areas detached adoption and import']=true,
		['shape raw attribute states']=true,
		['shape setter DOMString conversion']=true,
		['shape descriptor and foreign namespace']=true,
		['area tabIndex reflection independent of focusability']=true,
	}
	local seen={}
	for _,case in fixture.cases do
		assert(expectedCases[case.name]and not seen[case.name],'Image-map fixture cases must be expected and unique: '..case.name)
		seen[case.name]=true
	end
	for name in expectedCases do assert(seen[name],'Required image-map native fixture case is missing: '..name)end
	for _,case in fixture.cases do
		local document=Parser.parseDocument(case.html);local events=Events.new(error)
		local runtime=Runtime.new(document,{Events=events,ControlAdapter={},Schedule=function()end})
		local ok,message=runtime:Run('window.imageMapResult='..case.action)
		assert(ok,case.name..': '..tostring(message))
		local actual=runtime.Window.Get('imageMapResult')
		assert(actual==case.expected,case.name..'\nexpected '..case.expected..'\nactual '..tostring(actual))
		assert(#runtime.Diagnostics==0,case.name..': '..table.concat(runtime.Diagnostics,' | '))
		runtime:Destroy();events:Destroy()
	end
	local sourceEvents,destinationEvents=Events.new(error),Events.new(error)
	local source=Runtime.new(Parser.parseDocument('<!doctype html><map id=m><area id=a></map>'),{Events=sourceEvents,ControlAdapter={},Schedule=function()end})
	local destination=Runtime.new(Parser.parseDocument('<!doctype html><body></body>'),{Events=destinationEvents,ControlAdapter={},Schedule=function()end})
	assert(source:Run([=[
window.moved=document.getElementById('m');window.keptAreas=moved.areas;
window.sourceGet=Object.getOwnPropertyDescriptor(HTMLMapElement.prototype,'areas').get;
window.sourceCollection=HTMLCollection;window.sourcePrototype=HTMLCollection.prototype;
]=]))
	for _,key in {'moved','keptAreas','sourceGet','sourceCollection','sourcePrototype'}do destination.VM.Global.Bindings[key]={Value=source.Window.Get(key)}end
	assert(destination:Run([=[
window.destinationGet=Object.getOwnPropertyDescriptor(HTMLMapElement.prototype,'areas').get;
window.adoptionResult=[];
window.prototypeResult=[];window.destinationCollection=HTMLCollection;
prototypeResult.push(Object.getPrototypeOf(keptAreas)===sourcePrototype,keptAreas instanceof sourceCollection,keptAreas instanceof destinationCollection);
adoptionResult.push(keptAreas===moved.areas,sourceGet.call(moved)===keptAreas,destinationGet.call(moved)===keptAreas);
document.body.append(document.adoptNode(moved));
prototypeResult.push(Object.getPrototypeOf(keptAreas)===sourcePrototype,keptAreas instanceof sourceCollection,keptAreas instanceof destinationCollection);
adoptionResult.push(keptAreas===moved.areas,sourceGet.call(moved)===keptAreas,destinationGet.call(moved)===keptAreas,moved.ownerDocument===document);
const b=document.createElement('area');b.id='b';moved.append(b);adoptionResult.push(Array.from(keptAreas,n=>n.id));
moved.firstChild.remove();adoptionResult.push(Array.from(keptAreas,n=>n.id));
]=]),table.concat(destination.Diagnostics,' | '))
	for _,key in {'destinationGet','adoptionResult','destinationCollection','prototypeResult'}do source.VM.Global.Bindings[key]={Value=destination.Window.Get(key)}end
	assert(source:Run([=[
document.body.append(document.adoptNode(moved));
prototypeResult.push(Object.getPrototypeOf(keptAreas)===sourcePrototype,keptAreas instanceof sourceCollection,keptAreas instanceof destinationCollection);
adoptionResult.push(keptAreas===moved.areas,sourceGet.call(moved)===keptAreas,destinationGet.call(moved)===keptAreas,moved.ownerDocument===document);
window.crossRealmResult=JSON.stringify(adoptionResult);
window.crossRealmPrototypeResult=JSON.stringify(prototypeResult);
]=]),table.concat(source.Diagnostics,' | '))
	assert(source.Window.Get('crossRealmResult')==fixture.crossRealmJSON,'Cross-realm adoption preserves the original SameObject collection, borrowed getters and live destination mutations')
	assert(source.Window.Get('crossRealmPrototypeResult')==fixture.crossRealmPrototypeJSON,'Adopted areas collections preserve the original realm prototype and instanceof identity')
	assert(#source.Diagnostics==0 and #destination.Diagnostics==0,'Cross-realm areas access must not produce diagnostics')
	local held=source.Window.Get('keptAreas');local item=held.Get('item');local namedItem=held.Get('namedItem')
	source:Destroy();sourceEvents:Destroy();destination:Destroy();destinationEvents:Destroy()
	for _,action in {
		function()held.Get('length')end,function()item({0})end,function()namedItem({'b'})end,
		function()held.HasOwn('0')end,function()held.Iterator()end,
	}do assert(not pcall(action),'Disposed areas collections and cached methods cannot wrap nodes after runtime cleanup')end
	local discarded,plainControl=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
	local events=Events.new(error)
	local runtime=Runtime.new(Parser.parseDocument('<!doctype html><map id=m><area id=discarded></map>'),{Events=events,ControlAdapter={},Schedule=function()end})
	local function discardArea()
		assert(runtime:Run("window.keptMap=document.getElementById('m');window.keptMapAreas=keptMap.areas;keptMapAreas.length;window.discardedArea=document.getElementById('discarded');"))
		discarded[runtime.Window.Get('discardedArea').DOMNode]=true
		assert(runtime:Run('discardedArea.remove();window.discardedArea=null;'))
		assert(runtime:Run("window.transientMap=document.createElement('map');transientMap.append(document.createElement('area'));window.transientAreas=transientMap.areas;transientAreas.length;"))
		discarded[runtime.Window.Get('transientMap').DOMNode]=true
		assert(runtime:Run('window.transientMap=null;window.transientAreas=null;'))
		runtime:Flush();runtime:PumpTasks()
	end
	local frame=coroutine.create(function()plainControl[{}]=true;discardArea()end)
	assert(coroutine.resume(frame));assert(coroutine.status(frame)=='dead');frame=nil
	for batch=1,2048 do
		if next(discarded)==nil and next(plainControl)==nil then break end
		local garbage=table.create(2048);for index=1,2048 do garbage[index]={batch,index}end
	end
	assert(next(plainControl)==nil,'The areas lifetime budget must collect an independent plain-object control')
	assert(next(discarded)==nil,'Areas caches cannot retain unused detached maps or removed nodes from an earlier scan before the next access')
	assert(runtime:Run("if(keptMapAreas!==keptMap.areas||keptMapAreas.length!==0)throw new Error('Retained areas lost live identity during collection');"))
	runtime:Destroy();events:Destroy()
	print('Image maps DOM: '..#fixture.cases..' native cases; cross-realm SameObject adoption, live mutations and disposal passed')
end
