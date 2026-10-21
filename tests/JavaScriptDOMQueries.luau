--!strict
local function verifyAdoptedQueryCaches(Parser,DOM,VM)
 local function realm(html)
  local document=Parser.parseDocument(html);local vm;local steps=0
  local bridge=DOM.new(document,{Window={},ReadyState='complete',Changed=function()end,Step=function()steps+=1;vm.Step()end})
  vm=VM.new({document=bridge.Document});bridge.AttachVM(vm)
  return {VM=vm,Bridge=bridge,Document=document,Steps=function()return steps end}
 end
 local source=realm('<!doctype html><body><div id="moving"><i class="hot"></i></div></body>')
 local destination=realm('<!doctype html><body></body>')
 source.VM:Run('var moving=document.getElementById("moving");var held=moving.getElementsByTagName("i");var classes=moving.getElementsByClassName("hot");var namespaces=moving.getElementsByTagNameNS("*","*");var initial=held.length;')
 local held=source.VM.Global.Bindings.held.Value
 local classes=source.VM.Global.Bindings.classes.Value
 local namespaces=source.VM.Global.Bindings.namespaces.Value
 destination.VM.Global.Bindings.moving={Value=source.VM.Global.Bindings.moving.Value}
 destination.VM:Run('document.body.append(moving);')
 assert(held.Get('length')==1 and classes.Get('length')==1 and namespaces.Get('length')==1)
 destination.VM:Run('moving.append(document.createElement("i"));')
 assert(held.Get('length')==2 and namespaces.Get('length')==2,'Held live collections must follow mutations in the adopted root owner')
 destination.VM:Run('moving.lastChild.className="hot";')
 assert(classes.Get('length')==2,'Reflected attributes invalidate a retained class query after adoption')
 held.Get('length');namespaces.Get('length')
 local before=source.Steps();held.Get('length');classes.Get('length');namespaces.Get('length')
 assert(source.Steps()==before,'Repeated unchanged retained queries still reuse their caches')
 destination.VM:Run('moving.remove();moving.append(document.createElement("i"));moving.lastChild.className="hot";')
 assert(held.Get('length')==3 and classes.Get('length')==3 and namespaces.Get('length')==3,'Detached adopted trees keep the destination mutation scope')
 destination.VM:Run('moving.append(document.createElementNS("http://www.w3.org/2000/svg","circle"));')
 assert(held.Get('length')==3 and namespaces.Get('length')==4,'Namespace filtering stays current across detached adoption')
 source.VM:Run('document.body.append(moving);moving.firstChild.remove();')
 assert(held.Get('length')==2 and classes.Get('length')==2 and namespaces.Get('length')==3,'Returning to the original owner invalidates old snapshots and preserves order')
 source.VM:Run('moving.lastChild.remove();')
 assert(namespaces.Get('length')==2 and held.Get('0')==source.VM.Global.Bindings.moving.Value.Get('firstChild'),'Subsequent original-owner mutations remain live')
 source.Bridge:Destroy();destination.Bridge:Destroy();source.VM:Destroy();destination.VM:Destroy()
 local quirks=realm('<body><div id="moving"><i class="hot"></i></div></body>')
 local standards=realm('<!doctype html><body></body>')
 quirks.VM:Run('var moving=document.getElementById("moving");var list=moving.getElementsByClassName("HOT");var initial=list.length;')
 local list=quirks.VM.Global.Bindings.list.Value
 assert(list.Get('length')==1,'Initial quirks class lookup is case insensitive')
 standards.VM.Global.Bindings.moving={Value=quirks.VM.Global.Bindings.moving.Value}
 standards.VM:Run('document.body.append(moving);')
 assert(list.Get('length')==0,'The adopted owner document controls quirks matching')
 standards.VM:Run('moving.firstChild.className="HOT";')
 assert(list.Get('length')==1,'A mutation after owner mode change invalidates retained queries')
 quirks.Bridge:Destroy();standards.Bridge:Destroy();quirks.VM:Destroy();standards.VM:Destroy()
 local shadowSource=realm('<!doctype html><body><div id="host"></div></body>')
 local shadowDestination=realm('<!doctype html><body></body>')
 shadowSource.Bridge.AttachShadow(shadowSource.VM,{Enqueue=function()end})
 shadowSource.VM:Run('var host=document.getElementById("host");var shadow=host.attachShadow({mode:"open"});var root=document.createElement("div");shadow.append(root);root.append(document.createElement("i"));var list=root.getElementsByTagName("i");var initial=list.length;var outside=document.getElementsByTagName("i");')
 local shadowList=shadowSource.VM.Global.Bindings.list.Value
 local outside=shadowSource.VM.Global.Bindings.outside.Value
 assert(shadowList.Get('length')==1 and outside.Get('length')==0,'Legacy queries stay inside their light-tree root')
 shadowSource.VM:Run('root.append(document.createElement("i"));')
 assert(shadowList.Get('length')==2 and outside.Get('length')==0,'Same-owner shadow descendants invalidate their own query without escaping the scope')
 shadowDestination.VM.Global.Bindings.host={Value=shadowSource.VM.Global.Bindings.host.Value}
 shadowDestination.VM.Global.Bindings.root={Value=shadowSource.VM.Global.Bindings.root.Value}
 shadowDestination.VM:Run('document.body.append(host);root.append(document.createElement("i"));')
 assert(shadowList.Get('length')==3 and outside.Get('length')==0,'Shadow descendants retain live queries after their host is adopted')
 shadowSource.Bridge:Destroy();shadowDestination.Bridge:Destroy();shadowSource.VM:Destroy();shadowDestination.VM:Destroy()
 print('Live query adoption regression: tag/class/namespace caches, unchanged reuse, detached changes, owner roundtrip, document modes and shadow scopes passed')
end

local function verifyQueryOwnerDocumentMode(Parser,DOM,VM)
 local document=Parser.parseDocument('<!doctype html><body></body>');local vm
 local bridge=DOM.new(document,{Window={},ReadyState='complete',Changed=function()end,Step=function()vm.Step()end})
 vm=VM.new({document=bridge.Document});bridge.AttachVM(vm)
 vm:Run([=[
var root=document.createElement('div');root.append(document.createElement('i'));
var list=root.getElementsByTagName('I');var htmlInitial=list.length;
var xml=document.implementation.createDocument(null,'root');
xml.documentElement.append(root);var xmlLower=list.length;
]=])
 assert(vm.Global.Bindings.htmlInitial.Value==1,'HTML owner performs qualified-name ASCII lowercasing')
 assert(vm.Global.Bindings.xmlLower.Value==1,'A retained HTML-created tag query preserves its HTML case-normalization after adoption into XML, as native Chrome does')
 vm:Run([=[
root.append(xml.createElementNS('http://www.w3.org/1999/xhtml','I'));
var xmlUpper=list.length===1&&list.item(0)===root.firstChild;
document.body.append(root);var htmlAgain=list.length===1&&list.item(0)===root.firstChild;
root.firstChild.remove();var htmlAfterMutation=list.length===0;
]=])
 assert(vm.Global.Bindings.xmlUpper.Value,'An uppercase HTML-namespace name does not replace the original lower-name match in a held HTML-created collection')
 assert(vm.Global.Bindings.htmlAgain.Value,'Returning to HTML reuses the original query argument with HTML lowercasing and current order')
 assert(vm.Global.Bindings.htmlAfterMutation.Value,'Subsequent HTML mutations invalidate the retained tag query')
 bridge:Destroy();vm:Destroy()
 print('Live query HTML to XML to HTML adoption: native creation-document case matching retained; owner mutations and current order passed')
end

return function(Parser,Node,DOM,VM,fixture)
	local document=Parser.parseDocument('<!doctype html><html><head></head><body></body></html>')
	local vm;local changes=0
	local bridge=DOM.new(document,{Window={},ReadyState="complete",Changed=function()changes+=1 end,Step=function()vm.Step()end,
		Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(value,key)return vm.Get(value,key)end})
	local globals={document=bridge.Document};vm=VM.new(globals);bridge.AttachVM(vm);vm:Run(fixture)
	local cases=vm.Global.Bindings.queryCases.Value;local outputs={}
	for _,name in vm.OwnKeys(cases,true)do outputs[name]=vm:Call(vm.Get(cases,name),{},cases)end
	local function field(group,key)return vm.Get(outputs[group],key)end
	local function joined(group,key)return table.concat(field(group,key).Items,",")end
	assert(joined("names","ids")=="one,two"and joined("names","empty")=="empty"and joined("names","undefined")=="undef"and field("names","elementAPI")=="undefined")
	assert(field("names","tag")=="[object NodeList]"and field("names","named")=="undefined"and field("names","item")and field("names","missing"))
	assert(joined("namespaces","svg")=="svg-root,gradient,group,circle"and joined("namespaces","html")=="html-div,")
	assert(joined("namespaces","exact")=="gradient"and joined("namespaces","null")==""and field("namespaces","documentRoot"))
	assert(field("liveNameMutation","identity")and field("liveNamespaceMutation","identity")and field("classAndNamedItems","svgName"))
	assert(field("requiredArguments","name")=="TypeError"and field("requiredArguments","local")=="TypeError"and field("requiredArguments","noConversion"))
	assert(field("conversionAndGetters","converts")==1 and field("conversionAndGetters","total")==2 and field("conversionAndGetters","shortCircuit"))
	assert(field("receiverAndMetadata","wrongDocument")=="TypeError"and field("receiverAndMetadata","wrongElement")=="TypeError"and field("receiverAndMetadata","noConversion"))
	assert(field("liveIteration","removed")and field("liveIteration","staysDone")and joined("liveIteration","final")=="one")
	assert(changes>0,"Queries run against the real DOM mutation and invalidation hooks")
	local beforeReads=changes
	vm:Run([=[
const pureNames=document.getElementsByName('x'),pureElements=document.getElementsByTagNameNS('*','*');
const observedValues=[pureNames.length,pureNames.item(0),pureElements.length,pureElements.namedItem('none'),Array.from(pureElements).length];
]=])
	assert(changes==beforeReads,"Ordinary query creation, scans, names and iteration cannot invalidate rendering")
	vm:Run([=[
Object.prototype.get=function(){return 42;};Object.prototype.value=17;
const poisonedQueryRoot=document.createElement('div');
const poisonedQuery=poisonedQueryRoot.getElementsByTagNameNS;
const poisonedLength=Object.getOwnPropertyDescriptor(poisonedQuery,'length');
const nativeDescriptorSafe=poisonedLength.value===2&&poisonedLength.writable===false&&poisonedLength.enumerable===false&&poisonedLength.configurable===true&&poisonedQuery.call(poisonedQueryRoot,'*','*').length===0;
let inheritedDescriptorRules=false;try{Object.defineProperty({},'mixed',{value:1});}catch(error){inheritedDescriptorRules=error.name==='TypeError';}
delete Object.prototype.get;delete Object.prototype.value;
]=])
	assert(vm.Global.Bindings.nativeDescriptorSafe.Value and vm.Global.Bindings.inheritedDescriptorRules.Value,"Native query descriptor records ignore author prototype pollution while public descriptors retain inherited rules")
	local stringify=vm.Get(globals.JSON,"stringify");local serialized=vm:Call(stringify,{vm.Object(outputs)},globals.JSON)
	print("QUERY_RESULT "..serialized)
	local weak=setmetatable({},{__mode="k"})
	local function transient()
		local argument=vm.Object({toString=function()return "no-match"end})
		local list=vm:Call(bridge.Document.Get("getElementsByName"),{argument},bridge.Document)
		weak[argument]="argument";weak[list]="list"
	end
	transient();vm:Run("0;")
	local function collected()return next(weak)==nil end
	for _=1,128 do if collected()then break end;local garbage=table.create(2048);for index=1,2048 do garbage[index]={index,index+1}end end
	assert(collected(),"Live queries retain neither coercion arguments nor unused collection wrappers")
	local list=vm:Call(bridge.Document.Get("getElementsByName"),{"x"},bridge.Document);local method=bridge.Document.Get("getElementsByTagNameNS")
	local item=list.Get("item");local values=list.Get("values");local forEach=list.Get("forEach")
	local all=vm:Call(method,{"*","*"},bridge.Document);local named=all.Get("namedItem")
	bridge:Destroy();assert(not pcall(function()list.Get("length")end)and not pcall(function()vm:Call(method,{"*","*"},bridge.Document)end),"Disposed query methods and existing live views reject access")
	for _,action in {function()item({0})end,function()values()end,function()forEach({function()end})end,function()named({"x"})end,function()list.HasOwn("0")end,function()list.Iterator()end}do
		assert(not pcall(action),"Cached collection methods cannot wrap nodes after bridge disposal")
	end
	vm:Destroy()
	local bulkDocument=Parser.parseDocument('<!doctype html><html><head></head><body><main id="bulk">'..string.rep('<i class="bulk" name="bulk"></i>',256)..'</main></body></html>')
	local bulk;local scans=0
	local bulkBridge=DOM.new(bulkDocument,{Window={},ReadyState="complete",ControlAdapter={},Changed=function()end,Step=function()scans+=1;bulk.Step()end})
	bulk=VM.new({document=bulkBridge.Document});bulkBridge.AttachVM(bulk)
	bulk:Run([=[
const root=document.getElementById('bulk'),classes=root.getElementsByClassName('bulk'),names=document.getElementsByName('bulk'),elements=root.getElementsByTagNameNS('*','*');
const initial=Array.from(classes);const full=initial.length===256&&initial[255]===root.lastChild;
]=])
	assert(bulk.Global.Bindings.full.Value and bulk.Steps<8000,"256-element Array.from fits the unchanged default VM budget")
	local initialSteps,initialScans=bulk.Steps,scans
	local previousScans=scans
	bulk:Run("const again=Array.from(classes);const same=again[31]===initial[31];")
	assert(bulk.Global.Bindings.same.Value and scans==previousScans,"Unchanged iteration reuses the live-query result without repeated scans")
	local namedOK,namedError=pcall(function()bulk:Run("for(let index=0;index<1000;index++)classes.namedItem('missing');")end)
	assert(not namedOK and tostring(namedError):find("instruction budget exceeded",1,true),"Cached named-item scans remain charged to the author instruction budget")
	bulk:Run("const namedRecovered=classes.length===256;")
	assert(bulk.Global.Bindings.namedRecovered.Value,"An unchanged cached query recovers in the next independent entry after a named-item budget failure")
	bulk:Run("root.firstChild.className='other';root.firstChild.setAttribute('name','other');const attributes=classes.length===255&&names.length===255&&elements.length===256;")
	assert(bulk.Global.Bindings.attributes.Value,"Reflected class and name attribute changes invalidate existing live views")
	previousScans=scans
	bulk:Run("root.firstChild.className='other';const sameAttribute=classes.length===255;")
	assert(bulk.Global.Bindings.sameAttribute.Value and scans==previousScans,"Identical attribute values do not invalidate a query cache ("..previousScans.." -> "..scans..", value "..tostring(bulk.Global.Bindings.sameAttribute.Value)..")")
	bulk:Run("root.firstChild.removeAttribute('class');root.firstChild.toggleAttribute('class',true);const toggled=classes.length===255;root.append(initial[0]);const moved=elements.item(255)===initial[0];")
	assert(bulk.Global.Bindings.toggled.Value and bulk.Global.Bindings.moved.Value,"Remove/toggle attribute and same-parent moves invalidate live ordering")
	bulk:Run([=[
const replacement=document.createElement('strong');root.firstChild.replaceWith(replacement);const replaced=elements[0]===replacement&&elements.length===256;
root.textContent='a';const textOnly=elements.length===0&&classes.length===0&&names.length===0;
root.append(initial[0]);const appended=elements[0]===initial[0];root.innerHTML='<i class="bulk" name="bulk"></i><svg><g></g></svg>';
const markup=elements.length===3&&classes.length===1&&names.length===1;
root.replaceChildren('a','b');const replacedChildren=elements.length===0;root.normalize();const normalized=elements.length===0&&root.childNodes.length===1;
root.textContent='fresh';const plainText=elements.length===0;
]=])
	for _,name in {"replaced","textOnly","appended","markup","replacedChildren","normalized","plainText"}do assert(bulk.Global.Bindings[name].Value,"Structural query cache invalidation: "..name)end
	previousScans=scans
	bulk:Run("let rejected=false;try{root.append(root);}catch(error){rejected=error.name==='HierarchyRequestError';}const intact=rejected&&elements.length===0;")
	assert(bulk.Global.Bindings.intact.Value and scans==previousScans,"Rejected mutations do not invalidate an existing query result")
	bulk:Run([=[
root.innerHTML='<i name="coerced-item"></i><i name="coerced-item"></i><i name="coerced-item"></i>';
const itemNames=document.getElementsByName('coerced-item'),itemElements=root.getElementsByTagName('i');
const warmNames=itemNames.length,warmElements=itemElements.length;
const liveItem=itemNames.item({valueOf(){root.firstChild.remove();return 0;}})===root.firstChild;
const liveElementItem=itemElements.item({valueOf(){root.firstChild.remove();return 0;}})===root.firstChild;
const cachedClass=root.getElementsByClassName('coerced-class');const warmClass=cachedClass.length;
document.getElementsByTagName({toString(){root.firstChild.className='coerced-class';return 'i';}});
const liveConversion=cachedClass.length===1;
root.innerHTML='<input name="before" class="control-query">';const input=root.firstChild;
const beforeName=document.getElementsByName('before'),afterName=document.getElementsByName('after');
const warmBefore=beforeName.length,warmAfter=afterName.length;input.name='after';
const reflectedName=beforeName.length===0&&afterName.item(0)===input;
]=])
	for _,name in {"liveItem","liveElementItem","liveConversion","reflectedName"}do assert(bulk.Global.Bindings[name].Value,"Live query conversion/mutation order: "..name)end
	previousScans=scans
	bulk:Run("input.value='current';input.checked=true;const currentState=afterName.item(0)===input;")
	assert(bulk.Global.Bindings.currentState.Value and scans==previousScans,"Current value/checked changes leave name/tag/class query membership and revision intact")
	print("DOM query 256-element default-budget iteration: "..initialSteps.." VM steps, "..initialScans.." charged scan steps; revision-cache invalidations passed")
	bulkBridge:Destroy();bulk:Destroy()
	local wide=Parser.parseDocument('<!doctype html><html><head></head><body><div id="wide"></div></body></html>');local target=Node.findById(wide,"wide")
	for _=1,256 do Node.append(target,Node.text("text"))end
	local limited;local bounded=DOM.new(wide,{Window={},ReadyState="complete",Changed=function()end,Step=function()limited.Step()end})
	limited=VM.new({document=bounded.Document},{MaxSteps=128});bounded.AttachVM(limited)
	limited:Run("const emptyFast=document.getElementsByClassName(' \t ').length===0;")
	assert(limited.Global.Bindings.emptyFast.Value,"Empty class query avoids an unnecessary full tree scan")
	local ok,message=pcall(function()limited:Run("document.getElementsByTagName('*').length;")end)
	assert(not ok and tostring(message):find("instruction budget exceeded",1,true),"Live query scans charge text nodes and share the author script budget")
	limited:Run("document.getElementById('wide').remove();const recovered=document.getElementsByTagName('*').length===3;")
	assert(limited.Global.Bindings.recovered.Value,"Independent query entry recovers after bounded traversal failure")
	limited:Run("const mask=document.createElement('form');mask.name='getElementById';document.body.append(mask);const namedMethod=document.getElementById===mask;mask.name='renamed';const methodRestored=typeof document.getElementById==='function';")
	assert(limited.Global.Bindings.namedMethod.Value and limited.Global.Bindings.methodRestored.Value,'Cheap Document lookup must preserve native method clobbering and immediate rename restoration')
	bounded:Destroy();limited:Destroy()
	verifyAdoptedQueryCaches(Parser,DOM,VM);verifyQueryOwnerDocumentMode(Parser,DOM,VM)
	print("JavaScript DOM queries: live name/namespace/tag/class results, mutation/identity/iteration, conversion order/receivers, lifetime and budgets passed")
	return serialized
end
