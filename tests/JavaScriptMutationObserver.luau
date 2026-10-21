--!strict
return function(Parser,Node,DOM,VM,Events,MutationObservers)
	local document=Parser.parseDocument('<html><body><section id="root"><i id="a">A</i><b id="b">B</b></section></body></html>')
	local events=Events.new(error);local microtasks,diagnostics,changes={},{},{};local vm,observers
	local host={Events=events,Window={},ReadyState="complete",Mutation=function(record)if observers then observers:Notify(record)end end,
		Changed=function(node,kind)table.insert(changes,{node,kind})end,Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,
		Get=function(value,key)return vm.Get(value,key)end,GetControl=function()return VM.Undefined end,SetControl=function()end,Click=function()end}
	local bridge=DOM.new(document,host);local globals={document=bridge.Document}
	vm=VM.new(globals,{MaxSteps=100000})
	observers=vm:Install(function()return MutationObservers.install(vm,globals,{Wrap=bridge.Wrap,
		Unwrap=function(value)return if type(value)=="table" and value.DOMNode and bridge.Wrap(value.DOMNode)==value then value.DOMNode else nil end,
		Enqueue=function(callback)table.insert(microtasks,callback)end,Report=function(failure)table.insert(diagnostics,VM.string(failure))end})end)
	local function drain()
		local count=0;while #microtasks>0 do count+=1;assert(count<64,"Unexpected observer loop");table.remove(microtasks,1)()end
	end
	local function wrap(node)return bridge.Wrap(node)end
	local function call(node,key,...)return wrap(node).Get(key)({...})end
	local function create(name)return bridge.Document.Get("createElement")({name}).DOMNode end
	local function newObserver(callback)return vm:Construct(globals.MutationObserver,{callback})end
	local function observe(observer,node,opts)return vm:Call(vm.Get(observer,"observe"),{wrap(node),vm.Object(opts)},observer)end
	local function take(observer)return vm:Call(vm.Get(observer,"takeRecords"),{},observer).Items end
	local function disconnect(observer)return vm:Call(vm.Get(observer,"disconnect"),{},observer)end
	local function get(record,key)return vm.Get(record,key)end
	local function length(list)return vm.Get(list,"length")end
	local function expectError(callback,name)local ok,failure=pcall(callback);assert(not ok,"Expected "..name);assert(VM.exceptionValue(failure).Get("name")==name)end
	local root=Node.findById(document,"root");local a=Node.findById(document,"a");local b=Node.findById(document,"b")
	local ancestryReads=0
	local unobserved=setmetatable({},{__index=function(_,key)if key=='Parent'then ancestryReads+=1 end;return nil end})
	for _=1,100 do observers:Notify({Type='attributes',Target=unobserved,AttributeName='title'})end
	call(a,'setAttribute','data-before-observe','before')
	assert(ancestryReads==0 and #microtasks==0,'Unobserved mutations perform no ancestry reads or observer microtask scheduling')
	local delivered={};local observer=newObserver(function(args,receiver)
		assert(args[2]==observer or args[2]==receiver);table.insert(delivered,args[1].Items)
	end)
	observe(observer,root,{attributes=true,attributeOldValue=true,characterData=true,characterDataOldValue=true,childList=true,subtree=true})
	assert(#take(observer)==0,'Registering after an unobserved mutation never delivers its earlier record')
	call(a,"setAttribute","data-x","one");call(a,"setAttribute","data-x","two");call(a,"setAttribute","data-x","two")
	assert(#delivered==0 and #microtasks==1,"Mutations queue one delivery microtask")
	local records=take(observer);assert(#records==3 and get(records[1],"oldValue")==VM.Null and get(records[2],"oldValue")=="one" and get(records[3],"oldValue")=="two")
	assert(get(records[1],"type")=="attributes" and get(records[1],"target")==wrap(a) and get(records[1],"attributeName")=="data-x")
	drain();assert(#delivered==0,"takeRecords drains callback input")
	local text=a.Children[1];wrap(text).Set("data","A");wrap(text).Set("data","AB")
	records=take(observer);assert(#records==2 and get(records[1],"oldValue")=="A" and get(records[2],"oldValue")=="A")
	wrap(a).Set("textContent","AB");records=take(observer)
	assert(#records==1 and get(records[1],"type")=="childList" and length(get(records[1],"addedNodes"))==1 and length(get(records[1],"removedNodes"))==1)
	assert(vm.Get(get(records[1],"removedNodes"),"0")==wrap(text),"Record node lists preserve removed identities")
	call(root,"appendChild",wrap(b));records=take(observer);assert(#records==2 and length(get(records[1],"removedNodes"))==1 and length(get(records[2],"addedNodes"))==1,"Re-appending the last child still records a removal and insertion")
	local fragment=bridge.Document.Get("createDocumentFragment")({}).DOMNode;local x=create("u");local y=create("em");Node.append(fragment,x);Node.append(fragment,y)
	observe(observer,fragment,{childList=true});call(root,"append",wrap(fragment));records=take(observer)
	assert(#records==2 and get(records[1],"target")==wrap(fragment) and length(get(records[1],"removedNodes"))==2 and length(get(records[2],"addedNodes"))==2)
	call(root,"replaceChildren",wrap(b),wrap(a));records=take(observer)
	assert(#records==3 and vm.Get(get(records[1],"removedNodes"),"0")==wrap(b) and vm.Get(get(records[2],"removedNodes"),"0")==wrap(a) and length(get(records[3],"removedNodes"))==2)
	call(a,"remove");call(a,"setAttribute","data-detached","tracked");wrap(a.Children[1]).Set("data","detached")
	drain();local batch=delivered[#delivered];assert(#batch==3 and get(batch[2],"attributeName")=="data-detached" and get(batch[3],"type")=="characterData","Removed subtrees remain observed until delivery")
	call(a,"setAttribute","data-detached","after delivery");assert(#take(observer)==0,"Transient observations are removed before callbacks")
	local filteredSubtree=newObserver(function()error("Filtered removal must not deliver a callback")end)
	observe(filteredSubtree,root,{attributes=true,subtree=true});call(root,"appendChild",wrap(a));call(a,"remove");drain()
	call(a,"setAttribute","data-detached","after filtered removal");assert(#take(filteredSubtree)==0,"A removal with no requested childList record still expires transient observations")
	disconnect(filteredSubtree)
	call(root,"appendChild",wrap(a));take(observer);observe(observer,a,{attributes=true,attributeOldValue=true});observe(observer,root,{attributes=true,subtree=true})
	call(a,"setAttribute","data-x","three");records=take(observer);assert(#records==1 and get(records[1],"oldValue")=="two","Overlapping registrations produce one record with requested old value")
	observe(observer,a,{attributeFilter=vm.Array({"class"}),attributeOldValue=true})
	observe(observer,root,{childList=true})
	drain();call(a,'setAttribute','data-uninterested','filtered')
	assert(#microtasks==0,'An unrelated attribute does not wake the observer microtask driver')
	call(a,"setAttribute","data-x","filtered");call(a,"setAttribute","class","one");records=take(observer);assert(#records==1 and get(records[1],"attributeName")=="class")
	expectError(function()observe(observer,a,{attributes=false,attributeFilter=vm.Array({})})end,"TypeError")
	expectError(function()observe(observer,a,{attributes=false,attributeOldValue=true,childList=true})end,"TypeError")
	expectError(function()observe(observer,a,{characterData=false,characterDataOldValue=true,childList=true})end,"TypeError")
	expectError(function()observe(observer,a,{})end,"TypeError")
	observe(observer,a,{attributeOldValue=false});call(a,"setAttribute","title","inferred");records=take(observer);assert(#records==1 and get(records[1],"oldValue")==VM.Null)
	call(a,"setAttribute","title","discarded");disconnect(observer);drain();assert(#take(observer)==0)
	local order={};local first=newObserver(function()table.insert(order,"first")end);local second=newObserver(function()table.insert(order,"second")end)
	observe(second,a,{attributes=true});observe(first,a,{attributes=true});call(a,"setAttribute","title","ordered");drain();assert(table.concat(order,",")=="second,first","Delivery follows pending observer insertion order")
	disconnect(first);disconnect(second)
	call(a,'setAttribute','title','after disconnect')
	assert(#microtasks==0,'Disconnecting the last registrations restores the idle mutation path')
	local recursiveCount=0;local recursive=newObserver(function(args)
		recursiveCount+=1;if recursiveCount==1 then call(a,"setAttribute","title","during callback")end
	end)
	observe(recursive,a,{attributes=true});call(a,"setAttribute","title","begin");drain();assert(recursiveCount==2,"Callback mutations deliver in a later microtask");disconnect(recursive)
	local throwing=newObserver(function()error("observer callback failure")end);observe(throwing,a,{attributes=true});call(a,"setAttribute","title","throws");drain();assert(#diagnostics==1);disconnect(throwing)
	local normal=create("div");Node.append(normal,Node.text("a"));Node.append(normal,Node.text(""));Node.append(normal,Node.text("b"));Node.append(normal,Node.text("c"))
	observe(observer,normal,{childList=true,characterData=true,characterDataOldValue=true,subtree=true});call(normal,"normalize");records=take(observer)
	assert(#records==4 and get(records[1],"type")=="characterData" and get(records[1],"oldValue")=="a","Normalize concatenates a complete text run once before removing the merged nodes")
	for index=2,4 do assert(get(records[index],"type")=="childList" and get(get(records[index],"removedNodes"),"0").DOMNode.Text==({"","b","c"})[index-1],"Normalize removes contiguous nodes in browser order")end
	local _,failure=pcall(function()vm:Run([[let observed=0;const mo=new MutationObserver(function(records,observer){if(this!==observer||!(observer instanceof MutationObserver)||records[0].target!==document.getElementById('a'))throw new Error('observer identity');observed+=records.length;});mo.observe(document.getElementById('a'),{attributes:true});document.getElementById('a').setAttribute('title','JS');]])end)
	assert(failure==nil,VM.string(VM.exceptionValue(failure)));drain();assert(vm.Global.Bindings.observed.Value==1 and #diagnostics==1)
	local retained=records[1];expectError(function()vm.Set(retained,"oldValue","changed",true)end,"TypeError");vm.Set(retained,"oldValue","changed",false);assert(get(retained,"oldValue")=="a")
	observers:Destroy();drain();bridge:Destroy();events:Destroy();vm:Destroy()
	print("JavaScript MutationObserver: ordered microtask delivery, records/old values, source moves, fragments, transient subtrees, filters/reobserve, cancellation and lifetime passed")
end
