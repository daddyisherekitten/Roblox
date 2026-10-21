--!strict
return function(Parser,Node,DOM,VM,Traversal,fixture)
	local document=Parser.parseDocument('<html><body><div id="live"><input id="retained"></div></body></html>')
	local vm;local changed,removed={},{};local rejectMutation=false
	local bridge=DOM.new(document,{Window={},ReadyState="complete",Changed=function(node,kind)table.insert(changed,{Node=node,Kind=kind})end,
		ValidateStructure=function()assert(not rejectMutation,"Renderer rejected this structural batch")end,
		BeforeRemove=function(node)table.insert(removed,node)end,Mutation=function()end,
		Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(value,key)return vm.Get(value,key)end})
	local globals={document=bridge.Document};vm=VM.new(globals);bridge.AttachVM(vm)
	local api=vm:Install(function()return Traversal.install(vm,globals,{Document=bridge.Document,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap})end)
	bridge.AttachTraversal(api);vm:Run(fixture)
	local cases=vm.Global.Bindings.traversalCases.Value;local outputs={};local stringify=vm.Get(globals.JSON,"stringify")
	for _,name in vm.OwnKeys(cases,true)do outputs[name]=vm:Call(vm.Get(cases,name),{},cases)end
	local result=vm.Object(outputs);local serialized=vm:Call(stringify,{result},globals.JSON)
	print("TRAVERSAL_RESULT "..serialized)
	local function field(group,key)return vm.Get(outputs[group],key)end
	local function joined(group,key)return table.concat(field(group,key).Items,",")end
	assert(joined("basic","forward")=="root,a,a1,a2,s1,r1,z" and joined("basic","walked")=="a,a1,a2,s1,z","Iterator reject includes descendants; TreeWalker reject prunes its subtree")
	assert(joined("basic","reverse")=="z,r1,s1,a2,a1,a,root" and joined("basic","walkedBack")=="s1,a2,a1,a,root")
	assert(field("filterConversion","deferred")==0 and field("filterConversion","receiver")and field("filterConversion","callableThis")and field("filterConversion","converted")==4294967295)
	assert(field("filterConversion","bigMask")=="TypeError"and field("filterConversion","badObject")=="TypeError"and field("masksAndUnknownResult","calls")==6)
	assert(field("errorsAndReentrancy","identity")and field("errorsAndReentrancy","recursiveError")=="InvalidStateError"and field("errorsAndReentrancy","walkerError")=="InvalidStateError")
	assert(field("filterMutation","detached")and field("filterMutation","next")=="skip"and field("filterMutation","walkerNext")=="a1","Pre-remove adjusts the active iterator candidate; TreeWalker current remains the detached node")
	-- DOM pre-remove fallback with no following in-root node. This matches the
	-- standard/Firefox; Chromium's documented divergence is recorded by the runner.
	assert(field("removals","lastPosition").Items[1]=="#comment:note" and field("removals","lastPosition").Items[2]==false and field("removals","lastPosition").Items[3]==VM.Null)
	assert(field("identityAndDescriptors","instance")and field("identityAndDescriptors","identity")and field("identityAndDescriptors","strict")=="TypeError")
	vm:Run([=[
const live=document.getElementById('live'),retained=document.getElementById('retained');
const walker=document.createTreeWalker(live,NodeFilter.SHOW_ELEMENT),iterator=document.createNodeIterator(live,NodeFilter.SHOW_ELEMENT);
const original=walker.nextNode();iterator.nextNode();iterator.nextNode();live.append(retained);
const retainedIdentity=walker.currentNode===retained&&original===retained&&retained===document.getElementById('retained');
const afterMove=iterator.referenceNode===live;
live.append(document.createElement('span'));
]=])
	assert(vm.Global.Bindings.retainedIdentity.Value and vm.Global.Bindings.afterMove.Value,"Same-parent move adjusts iterator position while retaining the existing native DOM wrapper")
	assert(#removed>0 and #changed>0,"Traversal pre-removal composes existing native notification paths")
	vm:Run([=[
const guarded=document.createNodeIterator(live,1);guarded.nextNode();guarded.nextNode();
let caughtIterator,caughtName;let caughtAttempts=0;
caughtIterator=document.createNodeIterator(live,1,()=>{if(caughtAttempts++===0){try{caughtIterator.nextNode();}catch(error){caughtName=error.name;}}return 1;});
const caughtFirst=caughtIterator.nextNode(),caughtSecond=caughtIterator.nextNode();
let spin=true;const budgetIterator=document.createNodeIterator(live,1,()=>{if(spin){while(true){}}return 1;});
]=])
	assert(vm.Global.Bindings.caughtName.Value=="InvalidStateError" and vm.Global.Bindings.caughtFirst.Value==vm.Global.Bindings.live.Value and vm.Global.Bindings.caughtSecond.Value==vm.Global.Bindings.retained.Value,
		"A caught recursive filter failure cannot corrupt the outer candidate pointer")
	local guard=vm.Global.Bindings.guarded.Value;local position=vm.Get(guard,"referenceNode");local before=vm.Get(guard,"pointerBeforeReferenceNode");local removals=#removed
	rejectMutation=true;local blocked=pcall(function()vm:Run("live.append(retained);")end);rejectMutation=false
	assert(not blocked and #removed==removals and vm.Get(guard,"referenceNode")==position and vm.Get(guard,"pointerBeforeReferenceNode")==before,"Rejected structural batches leave data and traversal positions untouched")
	local bounded=pcall(function()vm:Run("budgetIterator.nextNode();")end)
	assert(not bounded,"Author filter loops share the normal script instruction budget")
	vm:Run("spin=false;const budgetRecovered=budgetIterator.nextNode()===live;")
	assert(vm.Global.Bindings.budgetRecovered.Value,"Filter active state and iterator candidate recover after budget exhaustion")
	local orphaned=setmetatable({},{__mode="k"})
	vm:Run("function transientIterator(){let traverser;const filter=()=>traverser?1:3;traverser=document.createNodeIterator(document,1,filter);return traverser;}")
	local function transient()
		orphaned[{}]="plain"
		orphaned[vm.Object({})]="vm-object"
		orphaned[vm:Call(bridge.Document.Get("createNodeIterator"),{bridge.Document,1},bridge.Document)]="iterator"
		local plainCycle
		plainCycle=vm.Object({callback=function()return plainCycle end})
		orphaned[plainCycle]="vm-cycle"
		orphaned[vm:Call(vm.Global.Bindings.transientIterator.Value,{},VM.Undefined)]="script-callback-cycle"
		local traverser
		local filter=vm.Object({acceptNode=function()return if traverser then 1 else 3 end})
		traverser=vm:Call(bridge.Document.Get("createNodeIterator"),{bridge.Document,1,filter},bridge.Document)
		orphaned[traverser]="callback-cycle"
	end
	transient()
	-- Retired Luau native-call registers can retain the last arguments until a
	-- later entry. Advance that boundary before testing document-owned roots.
	vm:Run("0;")
	local function collected()return next(orphaned)==nil end
	for _=1,128 do if collected()then break end;local garbage=table.create(2048);for index=1,2048 do garbage[index]={index,index+1}end end
	if not collected()then for _,name in orphaned do print("Uncollected probe",name)end end
	assert(collected(),"Document iterator registration cannot retain unused filter/traverser callback cycles")
	local holder=vm.Global.Bindings.walker.Value;local method=vm.Get(holder,"nextNode")
	bridge:Destroy();assert(not api.Alive and holder.TraversalState==nil and guard.TraversalState==nil and vm.Global.Bindings.budgetIterator.Value.TraversalState==nil)
	local ok=pcall(function()vm:Call(method,{},holder)end);assert(not ok,"Disposed traversers cannot return live document wrappers")
	vm:Destroy()
	local pollutedGlobals={};local polluted=VM.new(pollutedGlobals)
	polluted:Run("Object.prototype.get=function(){return 42;};Object.prototype.value=17;")
	local pollutedAPI=polluted:Install(function()return Traversal.install(polluted,pollutedGlobals,{Document=VM.Null,Wrap=function(node)return node end,Unwrap=function(value)return value end})end)
	polluted:Run([=[
const descriptor=Object.getOwnPropertyDescriptor(NodeFilter,'SHOW_ELEMENT');
const nativeDescriptors=descriptor.value===1&&descriptor.writable===false&&descriptor.enumerable===true&&descriptor.configurable===false;
let inheritedDescriptors=false;try{Object.defineProperty({},'mixed',{value:1});}catch(error){inheritedDescriptors=error.name==='TypeError';}
delete Object.prototype.get;delete Object.prototype.value;
]=])
	assert(polluted.Global.Bindings.nativeDescriptors.Value and polluted.Global.Bindings.inheritedDescriptors.Value,"Internal traversal descriptors have null prototypes; public inherited descriptor semantics remain intact")
	pollutedAPI:Destroy();polluted:Destroy()
	print("JavaScript DOM traversal: live navigation/filtering, callback receiver/coercion/errors/reentrancy, pre-removal/candidate adjustments, replacement/normalize, stable identities, descriptors and disposal passed")
	return serialized
end
