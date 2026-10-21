--!strict
return function(VM,Promises,AsyncFunctions,EventLoop,HostEvents,NetworkData,fixtures)
	local function fresh(extra)
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
			ObjectURLStore=extra and extra.Store,ObjectURLPartitionKey=extra and extra.Partition,Origin=extra and extra.Origin,
			CreatePromise=function()return promises:CreateCapability()end,
			Await=function(value,yes,no)promises:Await(value,function(args)yes(args[1])end,function(args)no(args[1])end)end,
			Enqueue=function(fn)loop:QueueMicrotask(fn)end,EnqueueTask=function(fn)result.TaskCalls=(result.TaskCalls or 0)+1;if result.FailTaskAt==result.TaskCalls then error("Simulated task limit")end;loop:QueueTask(fn)end,
			Fetch=function(snapshot,complete,signal)result.Request=snapshot;result.Complete=complete;if result.Adapter then return result.Adapter(snapshot,complete,signal)end;return function()result.Canceled=true end end})
		result.Network=network
		vm.Global.Bindings.makeFileList={Value=function(args)local files={};local nextValue=vm.Iterator(args[1]);while true do local more,file=nextValue();if not more then break end;table.insert(files,file)end;return network.Files:CreateFileList(files)end}
		result.VM,result.Loop,result.Host,result.Promises,result.Globals=vm,loop,host,promises,globals
		function result:Run(source)vm:Run(source);loop:Checkpoint()end
		function result:Pump()for _=1,4 do loop:PumpTasks()end end
		function result:Destroy()network:Destroy();host:Destroy();async:Destroy();promises:Destroy();loop:Destroy();vm:Destroy()end
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
		local realm=fresh()
		realm:Run("fetch('/send',{method:'POST',body:'payload',headers:{'x-app':'yes'}}).then(function(r){record(r.status);try{r.headers.set('x-change','no');}catch(e){record(e.name);}return r.text();}).then(record);")
		assert(realm.Request.url=="https://example.com/send" and realm.Request.method=="POST" and realm.Request.bodyBytes=="payload")
		assert(#realm.Values==0,"Network completion waits for a host task")
		realm.Complete(true,{status=201,bodyBytes="answer",headerPairs={{"x-server","yes"}}})
		assert(#realm.Values==0,"A host completion never executes JavaScript inline")
		realm.Complete(true,{status=202,bodyBytes="duplicate"})
		realm:Pump();assert(table.concat(realm.Values,",")=="201,TypeError,answer","Fetch tasks settle exactly once; response headers are immutable")
		assert(#realm.Reports==0,table.concat(realm.Reports," | "));realm:Destroy()
	end
	do
		local realm=fresh();realm:Run("const c=new AbortController();fetch('/pending',{signal:c.signal}).catch(record);")
		realm:Run("c.abort('canceled');")
		assert(realm.Canceled and table.concat(realm.Values,",")=="canceled","Signal abort cancels the host operation and preserves the reason")
		realm.Complete(true,{bodyBytes="late"});realm:Pump();assert(#realm.Values==1,"An aborted request cannot complete later");realm:Destroy()
	end
	do
		local realm=fresh();realm:Run("fetch('/pending').then(function(){record('late');});")
		local complete=realm.Complete;realm:Destroy();assert(realm.Canceled,"Disposal cancels outstanding network operations")
		complete(true,{bodyBytes="late"});assert(#realm.Values==0,"No completion is delivered after disposal")
	end
	do
		local realm=fresh();realm:Run("const c=new AbortController();c.abort('early');fetch('/not-started',{signal:c.signal}).catch(record);")
		assert(realm.Request==nil and realm.Values[1]=="early","Preaborted requests never invoke the adapter");realm:Destroy()
	end
	do
		local realm=fresh();realm:Run("const c=new AbortController();")
		realm.Adapter=function()
			local controller=realm.VM.Global.Bindings.c.Value
			realm.VM:Call(realm.VM.Get(controller,"abort"),{"during-start"},controller)
			return function()realm.Canceled=true end
		end
		realm:Run("fetch('/race',{signal:c.signal}).catch(record);")
		assert(realm.Canceled and realm.Values[1]=="during-start","A cancellation returned after a synchronous abort must still run")
		realm:Destroy()
	end
	do
		local realm=fresh();realm:Run("fetch('/head',{method:'HEAD'}).then(function(r){record(r.body===null);return r.text();}).then(record);")
		realm.Complete(true,{status=204,bodyBytes=""});realm:Pump();assert(realm.Values[1]=="true" and realm.Values[2]=="","Empty HTTP no-body responses remain null bodies");realm:Destroy()
	end
	do
		local realm=fresh();realm:Run("try{new ArrayBuffer(1048577);}catch(e){record(e.name);}try{new ReadableStream({start:function(c){for(let i=0;i<1025;i++)c.enqueue(i);}});}catch(e){record(e.name);}")
		assert(table.concat(realm.Values,",")=="RangeError,RangeError","Byte and stream queue limits fail predictably")
		realm:Destroy()
	end
	do
		local realm=fresh();realm:Run("fetch('/cors').then(function(r){record(r.type);record(r.headers.get('set-cookie'));record(r.headers.get('x-hidden'));record(r.headers.get('x-shown'));});")
		realm.Complete(true,{type="cors",headerPairs={{"set-cookie","secret"},{"x-hidden","hidden"},{"x-shown","yes"},{"access-control-expose-headers","x-shown"}}});realm:Pump()
		assert(table.concat(realm.Values,",")=="cors,null,null,yes","CORS filtered responses expose only allowed headers")
		realm:Destroy()
	end
	do
		local realm=fresh();realm:Run("fetch('/opaque',{mode:'no-cors'}).then(function(r){record(r.status);record(r.url);record(r.type);record(r.body===null);record(Array.from(r.headers).length);});")
		realm.Complete(true,{type="opaque",status=200,bodyBytes="hidden",headerPairs={{"x-secret","hidden"}}});realm:Pump()
		assert(table.concat(realm.Values,"|")=="0||opaque|true|0","Opaque filtered responses hide status, URL, headers and body")
		realm:Destroy()
	end
	do
		local realm=fresh();realm:Run("const f=new File(['a'],'a.txt');const files=makeFileList([f]);const iterator=files[Symbol.iterator]();record(iterator.next().value===f);record(iterator.next().done);const reader=new FileReader();reader.onload=function(){record('late load');};reader.readAsText(f);")
		local list=realm.VM.Global.Bindings.files.Value;local file=realm.VM.Global.Bindings.f.Value
		realm.Network.Files:UpdateFileList(list,{file,file});assert(#realm.Network.Files:FileListValues(list)==2)
		realm:Run("record(files.length);record(iterator.next().done);")
		assert(table.concat(realm.Values,",")=="true,true,2,true","FileList updates preserve wrapper identity and completed Array iterator semantics")
		realm.Network:Destroy();realm:Pump();assert(#realm.Values==4,"Disposal cancels queued FileReader tasks")
		realm:Destroy()
	end
	do
		local store={Entries={},Bytes=0,Count=0};local first=fresh({Store=store,Partition="same"});local peer=fresh({Store=store,Partition="same"});local other=fresh({Store=store,Partition="other"})
		first:Run("const u=URL.createObjectURL(new Blob(['owner']));record(u);");peer:Run("const u=URL.createObjectURL(new Blob(['peer']));record(u);")
		local url,peerURL=first.Values[1],peer.Values[1]
		assert(store.Count==2 and store.Bytes==9 and peer.Network:ObjectURL(url).Bytes=="owner" and other.Network:ObjectURL(url)==nil,"Object URLs share only the configured origin partition")
		first:Destroy();assert(store.Count==1 and store.Bytes==4 and peer.Network:ObjectURL(url)==nil and peer.Network:ObjectURL(peerURL).Bytes=="peer","Realm disposal revokes its own URLs only")
		peer:Destroy();other:Destroy();assert(store.Count==0 and store.Bytes==0,"Object URL resource accounting returns to zero")
	end
	do
		local realm=fresh();realm.FailTaskAt=2
		realm:Run("const r=new FileReader();r.onloadstart=function(){record('leak');};try{r.readAsText(new Blob(['x']));}catch(e){record(e.name);}record(r.readyState);record(r.result);")
		realm:Pump();assert(table.concat(realm.Values,",")=="RangeError,0,null","Queue exhaustion rolls back reader state and invalidates partially queued tasks")
		realm:Destroy()
	end
	print("JavaScript network data: "..#fixtures.." functional traces plus task ordering, transport/file abort/disposal, object URL isolation and resource bounds passed")
end
