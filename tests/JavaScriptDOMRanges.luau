--!strict
return function(Parser,Node,DOM,VM,Ranges,Contents,fixture)
	local document=Parser.parseDocument('<!doctype html><html><body></body></html>');local vm
	local changes,notifications=0,0;local reject=false;local mutations={};local notificationKinds={}
	local bridge=DOM.new(document,{Window={},ReadyState="complete",ControlAdapter={},Step=function()vm.Step()end,
		Changed=function()changes+=1 end,Mutation=function(record)table.insert(mutations,record)end,ValidateStructure=function()assert(not reject,"Renderer rejected batch")end})
	local globals={document=bridge.Document};vm=VM.new(globals);bridge.AttachVM(vm)
	local api=vm:Install(function()return Ranges.install(vm,globals,{Document=bridge.Document,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,Context=bridge.RangeContext(),Contents=Contents,Changed=function(_,kind)notifications+=1;table.insert(notificationKinds,kind)end})end)
	bridge.AttachRanges(api);vm:Run(fixture)
	local cases=vm.Global.Bindings.rangeCases.Value;local outputs={}
	for _,name in vm.OwnKeys(cases,true)do outputs[name]=vm:Call(vm.Get(cases,name),{},cases)end
	local function field(group,key)return vm.Get(outputs[group],key)end
	assert(field("construction","text")=="onetwothree"and field("construction","instance")and field("construction","common"))
	assert(field("comparisons","wrongRoot")=="WrongDocumentError"and field("comparisons","wrongRange")=="WrongDocumentError"and field("comparisons","detached")==false)
	assert(field("stringification","all")=="😀BCDEFZ"and field("stringification","contents")=="A😀BCDEFZ"and field("stringification","comment")=="")
	assert(field("splitText","orphanIdentity")and field("structuralMutations","other"))
	assert(field("staticRange","readonly")and field("conversionsAndBrand","noConversion")and field("conversionsAndBrand","identity"))
	assert(field("constructorTargets","custom")and field("constructorTargets","static")and field("constructorTargets","fallback")and field("constructorTargets","identity"))
	assert(vm.Get(field("normalize","trailing"),"0").Items[1]=="#text:word"and field("normalize","trailingIdentity"),"A trailing empty normalized text boundary moves into the retained text")
	local json=vm:Call(vm.Get(globals.JSON,"stringify"),{vm.Object(outputs)},globals.JSON);print("RANGE_RESULT "..json)
	vm:Run([[const documentRange=new Range();const documentComment=document.createComment('range-document');documentRange.insertNode(documentComment);
		if(documentComment.parentNode!==document||documentRange.startContainer!==document||documentRange.startOffset!==0||documentRange.endOffset!==1)throw new Error('Document Range insertion');
		document.removeChild(documentComment);]])
	local isolated=Node.document();vm.Global.Bindings.isolated={Value=bridge.Wrap(isolated)}
	vm:Run([[const isolatedRoot=document.createElement('html');isolated.appendChild(isolatedRoot);
		const anotherRoot=document.createElement('html');const roots=document.createDocumentFragment();roots.append(anotherRoot,document.createElement('html'));
		const badText=document.createTextNode('bad');const textParent=document.createElement('p');textParent.appendChild(badText);
		for(const candidate of [anotherRoot,roots,badText,isolatedRoot]){let name='';try{isolated.appendChild(candidate);}catch(e){name=e.name;}if(name!=='HierarchyRequestError')throw new Error('Document hierarchy validation');}
		if(roots.childNodes.length!==2||anotherRoot.parentNode!==roots||badText.parentNode!==textParent||isolated.firstChild!==isolatedRoot)throw new Error('Hierarchy failure changed a source tree');
		const replacement=document.createElement('html');isolated.replaceChild(replacement,isolatedRoot);
		if(isolated.firstChild!==replacement||isolatedRoot.parentNode!==null)throw new Error('Document replacement preflight');
		const beforeFailure=isolated.firstChild;let failed=false;try{isolated.replaceChildren(document.createElement('html'),document.createElement('html'));}catch(e){failed=e.name==='HierarchyRequestError';}
		if(!failed||isolated.firstChild!==beforeFailure||isolated.childNodes.length!==1)throw new Error('Atomic document batch');
		isolated.replaceChildren(isolatedRoot);if(isolated.firstChild!==isolatedRoot)throw new Error('Document replace-all');]])
	local typed=Node.document();local doctype={Kind="DocumentType",Name="html",Children={}};local element=Node.element("html",{})
	Node.append(typed,doctype);Node.append(typed,element)
	assert(not pcall(Node.validateInsert,typed,Node.element("html",{}),doctype,{element}),"A replacement document element must still follow an existing doctype")
	assert(not pcall(Node.validateInsert,typed,{Kind="DocumentType",Children={}},nil,{doctype}),"A replacement doctype cannot follow the existing document element")
	assert(not pcall(Node.validateInsert,Node.documentFragment(),doctype,nil),"Doctypes cannot move into ordinary fragments")
	Node.validateInsert(typed,Node.element("html",{}),element,{element})
	Node.validateInsert(typed,{Kind="DocumentType",Children={}},doctype,{doctype})
	local shadowHost=Node.element("div",{});local shadow=Node.shadowRoot("open",shadowHost)
	assert(not pcall(Node.validateInsert,shadow,shadowHost,nil),"Insertion cycles include ShadowRoot hosts")
	vm:Run([[const cycleTemplate=document.createElement('template');let cycleFailed=false;try{cycleTemplate.content.appendChild(cycleTemplate);}catch(e){cycleFailed=e.name==='HierarchyRequestError';}if(!cycleFailed||cycleTemplate.content.childNodes.length!==0)throw new Error('Template host-inclusive cycle');]])
	Node.insertBefore(shadow,Node.text("shadow"),nil)
	local shadowRange=api.New(shadow,0,shadow,1);local shadowText=shadow.Children[1]
	assert(api.Stringify(shadowRange)=="shadow"and vm.Get(bridge.Wrap(shadow),"nodeType")==11,"Existing ShadowRoots are genuine Range containers")
	vm:Install(function()bridge.RangeContext().Insert(shadow,Node.comment("inserted"),shadowText)end)
	assert(api.State(shadowRange).EndOffset==2,"Existing ShadowRoot insertion adjusts live boundaries")
	local deep=Node.element("main",{});local startBranch,endBranch=deep,deep
	for _=1,240 do
		local left,right=Node.element("div",{}),Node.element("div",{})
		Node.append(startBranch,left);Node.append(endBranch,right);startBranch,endBranch=left,right
	end
	local startText,endText=Node.text("start"),Node.text("end");Node.append(startBranch,startText);Node.append(endBranch,endText)
	local deepRange=vm:Install(function()return api.New(startText,0,endText,3)end)
	vm.Global.Bindings.deepRange={Value=deepRange};vm.Global.Bindings.deepRoot={Value=bridge.Wrap(deep)}
	vm:Run("if(deepRange.commonAncestorContainer!==deepRoot||String(deepRange)!=='startend')throw new Error('Deep range');")
	assert(vm.Steps<4000,"A valid two-branch depth240 Range reads its common ancestor and text within the default instruction budget")
	local before=changes
	vm:Run("const pure=new Range();pure.selectNodeContents(document.body);const cloned=pure.cloneRange();const text=String(cloned);cloned.compareBoundaryPoints(0,pure);cloned.intersectsNode(document.body);")
	assert(changes==before,"Range reads and boundary mutations cannot invalidate the renderer")
	vm:Run("const norm=document.createElement('p');norm.append('ab','cd','ef');document.body.append(norm);")
	table.clear(mutations);vm:Run("norm.normalize();")
	local characters=0;for _,record in mutations do if record.Type=="characterData"then characters+=1;assert(record.OldValue=="ab")end end
	assert(characters==1,"One contiguous normalized text run emits one characterData record, followed by child removals")
	table.clear(mutations);table.clear(notificationKinds);local cleanLayout=changes;vm:Run("norm.normalize();")
	assert(#mutations==1 and mutations[1].Type=="characterData"and mutations[1].OldValue=="abcdef"and #notificationKinds==0 and changes==cleanLayout,"An already normalized Text still emits replaceData's record without repainting or changing Range boundaries/content")
	vm:Run("const kinds=new Range();kinds.selectNodeContents(norm.firstChild);")
	table.clear(notificationKinds);vm:Run("norm.firstChild.replaceData(1,1,'X');")
	assert(table.find(notificationKinds,"content")~=nil,"Text content-only changes are distinguished from associated Range boundary changes")
	vm:Run("const guardedRoot=document.createElement('p');guardedRoot.textContent='guard';document.body.append(guardedRoot);const guardedText=guardedRoot.firstChild;const guard=new Range();guard.setStart(guardedText,1);guard.setEnd(guardedText,4);")
	local holder=vm.Global.Bindings.guard.Value;local entry=api.State(holder);local initial=table.clone(entry);local oldNotifications=notifications
	reject=true;local ok=pcall(function()vm:Run("guardedRoot.remove();")end);reject=false
	assert(not ok and entry.StartNode==initial.StartNode and entry.StartOffset==initial.StartOffset and entry.EndOffset==initial.EndOffset and notifications==oldNotifications,"Failed renderer validation leaves boundaries and queued Selection notifications untouched")
	local weak=setmetatable({},{__mode="k"})
	local function transient()weak[api.New()]=true;weak[api.NewStatic(initial)]=true end
	vm:Install(transient);vm:Run("0;")
	for _=1,128 do if next(weak)==nil then break end;local garbage=table.create(2048);for i=1,2048 do garbage[i]={i,i+1}end end
	assert(next(weak)==nil,"Weak registrations do not retain unused live or static ranges")
	-- Repeated independent selection work must not exhaust a lifetime counter.
	for batch=1,72 do
		vm:Run("for(let i=0;i<64;i++){new Range();new StaticRange({startContainer:document,startOffset:0,endContainer:document,endOffset:0});}")
		local garbage=table.create(2048);for i=1,2048 do garbage[i]={i,batch}end
	end
	local retained={}
	vm:Install(function()for _=1,4096 do
		local ok,value=pcall(api.New);if not ok then break end;table.insert(retained,value)
	end end)
	local full,value=pcall(function()vm:Run("new Range();")end)
	assert(not full and VM.string(VM.exceptionValue(value)):find("retained range budget",1,true),"The private cap counts retained ranges across weak live and static registries")
	local releasedRanges=setmetatable({},{__mode="k"});for _,range in retained do releasedRanges[range]=true end
	table.clear(retained)
	-- Observe completion of the collector rather than assuming a fixed number
	-- of small allocations triggers a complete cycle for every module heap.
	for _=1,512 do
		if next(releasedRanges)==nil then break end
		local garbage=table.create(2048);for i=1,2048 do garbage[i]={i}end
	end
	assert(next(releasedRanges)==nil,"Released Range objects must actually leave the weak registry")
	local released,message=pcall(function()vm:Run("new Range();")end)
	assert(released,"Collected ranges release private retained capacity: "..VM.string(VM.exceptionValue(message)))
	local getter=vm.Get(vm.GetOwnPropertyDescriptor(vm.Get(globals.AbstractRange,"prototype"),"startContainer"),"get")
	local method=vm.Get(holder,"cloneRange");bridge:Destroy()
	assert(not api.Alive and holder.RangeState==nil and not pcall(function()vm:Call(method,{},holder)end)and not pcall(function()vm:Call(getter,{},holder)end),"Destroy clears live state and cached branded methods/getters reject")
	vm:Destroy();print("DOM Range core: boundaries, live remove/insert/text/split/normalize, static dictionary, comparisons, identity/brand/readonly, GC/disposal and renderer guards passed")
	return json
end
