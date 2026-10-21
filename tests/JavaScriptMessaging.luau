--!strict
return function(VM,Promises,AsyncFunctions,EventLoop,HostEvents,NetworkData,StructuredClone,Messaging,WorkerAdapter,fixtures)
	local function fresh(origin,queueBytes,workerOptions)
		local result={Values={},Reports={},Events={},Time=0}
		local vm,loop,promises,host
		local globals={record=function(args)table.insert(result.Values,VM.string(args[1]));return VM.Undefined end}
		local window={Get=function(key)local binding=vm and vm.Global.Bindings[key];return if binding then binding.Value elseif globals[key]~=nil then globals[key]else VM.Undefined end,
			Set=function(key,value)if vm then vm.Global.Bindings[key]={Value=value}else globals[key]=value end end}
		globals.window,globals.self,globals.globalThis=window,window,window
		local function report(message)table.insert(result.Reports,VM.string(message))end
		local function invoke(fn,args,kind)
			local ok,message=pcall(function()vm:Call(fn,args,if kind=="timer"then window else VM.Undefined)end)
			if not ok then report(VM.exceptionValue(message))end
			if loop and not loop.Draining then loop:Checkpoint()end
			return vm.Steps
		end
		loop=EventLoop.new({Clock=function()return result.Time end,Report=report,Invoke=invoke,
			AfterCheckpoint=function()if promises then promises:AfterCheckpoint()end end})
		for key,value in loop.Methods do globals[key]=value end
		promises=Promises.new({Enqueue=function(fn)loop:QueueMicrotask(fn)end,Report=report,
			Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(value,key,receiver)return vm.Get(value,key,receiver)end,
			Construct=function(fn,args)return vm:Construct(fn,args)end,
			Iterator=function(value)return vm.Iterator(value)end,Array=function(items)return vm.Array(items)end,Object=function(values)return vm.Object(values)end})
		globals.Promise=promises.Constructor
		local async=AsyncFunctions.new({Create=function()return promises:CreateCapability()end,Wait=function(value,yes,no)promises:Await(value,yes,no)end,
			Resume=function(record,rejected,value)return vm:ResumeAsync(record,rejected,value)end})
		vm=VM.new(globals,{Async=async,MaxSteps=100000});vm.Model=VM;promises:Attach(vm)
		host=HostEvents.install(vm,globals,{Report=report,Clock=function()return result.Time*1000 end,
			SetTimeout=function(callback,ms)return loop.Methods.setTimeout({callback,ms})end,
			ClearTimeout=function(id)loop.Methods.clearTimeout({id})end})
		host:WrapTarget(window,{Handlers=true,Parent=function()return nil end})
		local network=NetworkData.install(vm,globals,{HostEvents=host,BaseURL="https://example.com/base/",NativeLineEnding="\r\n",
			CreatePromise=function()return promises:CreateCapability()end,
			Await=function(value,yes,no)promises:Await(value,function(args)yes(args[1])end,function(args)no(args[1])end)end,
			Enqueue=function(fn)loop:QueueMicrotask(fn)end,EnqueueTask=function(fn)loop:QueueTask(fn)end,
			Fetch=function(snapshot,complete,signal)result.Request=snapshot;result.Complete=complete;if result.Adapter then return result.Adapter(snapshot,complete,signal)end;return function()result.Canceled=true end end})
		result.Network=network
		vm.Global.Bindings.makeFileList={Value=function(args)local files={};local nextValue=vm.Iterator(args[1]);while true do local more,file=nextValue();if not more then break end;table.insert(files,file)end;return network.Files:CreateFileList(files)end}
		local clone=StructuredClone.install(vm,globals,{HostEvents=host,Binary=network.Binary,NetworkData=network})
		local messaging=Messaging.install(vm,globals,{HostEvents=host,Clone=clone,Origin=origin or "https://example.com",MaxQueueBytes=queueBytes,EnqueueTask=function(fn)loop:QueueTask(fn)end})
		result.Clone,result.Messaging=clone,messaging
		local workerConfig={HostEvents=host,Clone=clone,Messaging=messaging,Origin=origin or "https://example.com",BaseURL="https://example.com/base/",EnqueueTask=function(fn)loop:QueueTask(fn)end,Report=report}
		for key,value in workerOptions or {}do workerConfig[key]=value end
		local workers=WorkerAdapter.install(vm,globals,workerConfig);result.Workers=workers
		result.VM,result.Loop,result.Host,result.Promises,result.Globals=vm,loop,host,promises,globals
		function result:Run(source)vm:Run(source);loop:Checkpoint()end
		function result:Pump()for _=1,4 do loop:PumpTasks()end end
		function result:Destroy()workers:Destroy();messaging:Destroy();clone:Destroy();network:Destroy();host:Destroy();async:Destroy();promises:Destroy();loop:Destroy();vm:Destroy()end
		return result
	end
	for _,fixture in fixtures do
		local realm=fresh();local ok,message=pcall(function()realm:Run(fixture.source);realm:Pump()end)
		assert(ok,fixture.name..": "..VM.string(VM.exceptionValue(message)))
		assert(#realm.Reports==0,fixture.name..": "..table.concat(realm.Reports," | "))
		assert(#realm.Values==#fixture.expected,fixture.name..": "..table.concat(realm.Values," | "))
		for i,value in fixture.expected do assert(realm.Values[i]==value,fixture.name..": "..table.concat(realm.Values," | "))end
		realm:Destroy()
	end
	do
		local source,destination=fresh(),fresh()
		source:Run("var bytes=new Uint8Array([4,5]);var object={bytes:bytes,map:new Map(),date:new Date(123),error:new TypeError('bad')};object.self=object;object.map.set(object,object);")
		local object=source.VM.Global.Bindings.object.Value;local bytes=source.VM.Global.Bindings.bytes.Value
		local wire=source.Clone:Serialize(object,source.VM.Array({source.VM.Get(bytes,"buffer")}))
		local result=destination.Clone:Deserialize(wire);destination.VM.Global.Bindings.received={Value=result}
		destination:Run("record(received.self===received);record(received.map instanceof Map);record(received.map.get(received)===received);record(received.bytes instanceof Uint8Array);record(received.bytes.join(','));record(received.date instanceof Date);record(received.error instanceof TypeError);")
		assert(table.concat(destination.Values,"|")=="true|true|true|true|4,5|true|true","Cross-realm clone rebuilds target prototypes, cycles and binary data")
		assert(source.VM.Get(bytes,"length")==0,"Cross-realm transfer detaches source views")
		source:Destroy();destination:Destroy()
	end
	do
		local source,destination=fresh(),fresh()
		source:Run("var channel=new MessageChannel();channel.port2.onmessage=function(){record('old realm');};channel.port1.postMessage('queued before transfer');")
		local port=source.VM.Get(source.VM.Global.Bindings.channel.Value,"port2")
		local received=destination.Clone:Deserialize(source.Clone:Serialize(port,source.VM.Array({port})))
		destination.VM.Global.Bindings.received={Value=received};destination:Run("received.onmessage=function(e){record(e.data);};")
		source:Destroy();destination:Pump()
		assert(table.concat(destination.Values,"|")=="queued before transfer","Port queue moves to destination even when source realm had a scheduled delivery and is destroyed")
		destination:Destroy()
	end
	do
		local a,b,other=fresh(),fresh(),fresh("https://different.example")
		a:Run("var c=new BroadcastChannel('cross-realm');c.onmessage=function(){record('sender');};")
		b:Run("var c=new BroadcastChannel('cross-realm');c.onmessage=function(e){record(e.data.n);record(e.origin);};")
		other:Run("var c=new BroadcastChannel('cross-realm');c.onmessage=function(){record('wrong origin');};")
		a:Run("c.postMessage({n:7});");b:Pump();other:Pump()
		assert(table.concat(b.Values,"|")=="7|https://example.com" and #a.Values==0 and #other.Values==0,"BroadcastChannel is origin-scoped across realms")
		a:Run("c.postMessage({n:9});");b.Messaging:Destroy();b:Pump();assert(#b.Values==2,"Disposed broadcast destinations do not receive queued tasks")
		a:Destroy();b:Destroy();other:Destroy()
	end
	do
		local realm=fresh(nil,128)
		realm:Run("var c=new MessageChannel();c.port1.postMessage('x'.repeat(100));var b=new ArrayBuffer(4);try{c.port1.postMessage({b:b},{transfer:[b]});}catch(e){record(e.name);}record(b.byteLength);")
		assert(table.concat(realm.Values,"|")=="DataCloneError|4","Queue byte budget fails before committing ArrayBuffer transfer")
		realm:Destroy()
	end
	do
		local realm=fresh()
		realm:Run("try{new Worker('task.js');}catch(e){record(e.name);}try{new Worker('https://other.example/task.js');}catch(e){record(e.name);}try{new Worker('task.js',{type:'module'});}catch(e){record(e.name);}")
		assert(table.concat(realm.Values,"|")=="NotSupportedError|SecurityError|NotSupportedError","Worker cannot pretend main-thread execution is an isolated host scheduler")
		realm:Destroy()
	end
	do
		local complete,callbacks,spec;local sent={};local terminated,loadCanceled=0,0
		local realm=fresh(nil,nil,{LoadScript=function(url,loaded)assert(url=="https://example.com/base/task.js");complete=loaded;return function()loadCanceled+=1 end end,
			SpawnWorker=function(settings,events)spec=settings;callbacks=events;return {PostMessage=function(wire)table.insert(sent,wire)end,Terminate=function()terminated+=1 end}end})
		realm:Run("var w=new Worker('task.js',{name:'calc'});w.onmessage=function(e){record(e.data.result);record(e.isTrusted);};var b=new Uint8Array([8,9]);w.postMessage({buffer:b.buffer},[b.buffer]);record(b.length);")
		assert(complete==nil and #sent==0,"Worker construction and message serialization do not synchronously run the host loader or scheduler")
		realm:Pump();assert(complete and callbacks==nil)
		complete(true,"postMessage('ready');");assert(callbacks==nil,"Loader completion queues scheduler work")
		realm:Pump();assert(spec.name=="calc" and spec.source=="postMessage('ready');"and #sent==1)
		local child=fresh();local data=child.Clone:Deserialize(sent[1]);assert(child.Network.Binary:ReadBytes(child.VM.Get(data,"buffer"))==string.char(8,9),"Worker receives portable buffer graph records")
		callbacks.Message(child.Clone:Serialize(child.VM.Object({result=17})));assert(#realm.Values==1,"Worker callbacks must not dispatch JS synchronously")
		realm:Pump();assert(table.concat(realm.Values,"|")=="0|17|true")
		realm:Run("w.terminate();w.terminate();");assert(terminated==1 and loadCanceled==0)
		callbacks.Message(child.Clone:Serialize(child.VM.Object({result=99})));realm:Pump();assert(#realm.Values==3,"Terminated worker ignores late delivery")
		realm:Destroy();child:Destroy();assert(terminated==1)
	end
	do
		local canceled,spawned=0,0;local loaded
		local realm=fresh(nil,nil,{LoadScript=function(_,complete)loaded=complete;return function()canceled+=1 end end,SpawnWorker=function()spawned+=1 end})
		realm:Run("var w=new Worker('task.js');");realm:Pump();realm:Run("w.terminate();")
		assert(canceled==1);loaded(true,"record('bad');");realm:Pump();assert(spawned==0)
		realm:Destroy()
	end
	do
		local callbacks;local terminated=0
		local realm=fresh(nil,nil,{LoadScript=function(_,complete)complete(true,"source")end,SpawnWorker=function(_,events)callbacks=events;return {PostMessage=function()end,Terminate=function()terminated+=1 end}end})
		realm:Run("var w=new Worker('task.js');w.onerror=function(e){record(e.message);record(e.filename);e.preventDefault();};");realm:Pump()
		callbacks.Error({message="child failed",filename="task.js",lineno=2});realm:Pump();assert(table.concat(realm.Values,"|")=="child failed|task.js" and #realm.Reports==0)
		realm:Run("var c=new MessageChannel();try{w.postMessage({port:c.port1},[c.port1]);}catch(e){record(e.name);}c.port2.onmessage=function(e){record(e.data);};c.port1.postMessage('still connected');");realm:Pump()
		assert(realm.Values[3]=="DataCloneError" and realm.Values[4]=="still connected","Unsupported cross-worker host handles reject before port transfer")
		realm:Destroy();assert(terminated==1,"Realm disposal terminates each live host worker")
	end
	print("JavaScript structured clone/messaging: "..#fixtures.." shared traces plus cross-realm cloning, transfer, origin isolation, queue budgets, worker host contracts and disposal passed")
end
