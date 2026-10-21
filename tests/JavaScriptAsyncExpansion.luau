--!strict
return function(VM,Promises,AsyncFunctions,EventLoop,HostEvents,fixtures)
	local function fresh()
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
		result.VM,result.Loop,result.Host,result.Promises,result.Globals,result.Async=vm,loop,host,promises,globals,async
		function result:Run(source)vm:Run(source);loop:Checkpoint()end
		function result:Pump()for _=1,4 do loop:PumpTasks()end end
		function result:Destroy()host:Destroy();async:Destroy();promises:Destroy();loop:Destroy();vm:Destroy()end
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
	-- Verify the host task hook independently from Runtime's DOM/window adapter.
	do
		local realm=fresh();local vm=realm.VM;local jobs,notices,reports={},{},{}
		local tracked=Promises.new({Enqueue=function(fn)realm.Loop:QueueMicrotask(fn)end,QueueTask=function(fn)table.insert(jobs,fn)end,
			Report=function(message)table.insert(reports,message)end,
			RejectionEvent=function(kind,promise,reason)table.insert(notices,{kind,promise,reason});return true end,
			Get=vm.Get,Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Array=vm.Array,Object=vm.Object,Iterator=vm.Iterator})
		local p,_,reject=tracked:CreateCapability();reject({"late"});tracked:AfterCheckpoint()
		assert(#notices==0 and #jobs==1,"Unhandled rejection notification is a host task, not a microtask")
		jobs[1]();assert(#notices==1 and notices[1][1]=="unhandledrejection" and notices[1][2]==p and notices[1][3]=="late" and #reports==0)
		vm:Call(vm.Get(p,"catch"),{function()end},p)
		assert(#jobs==2 and #notices==1,"A late handler queues rejectionhandled")
		jobs[2]();assert(#notices==2 and notices[2][1]=="rejectionhandled")
		local early,_,earlyReject=tracked:CreateCapability();earlyReject({"early"});tracked:AfterCheckpoint()
		vm:Call(vm.Get(early,"catch"),{function()end},early);jobs[3]();assert(#notices==2,"A handler before the notification task suppresses host rejection events")
		local stopped,_,stopReject=tracked:CreateCapability();stopReject({"disposed"});tracked:AfterCheckpoint();tracked:Destroy();jobs[4]()
		assert(#notices==2,"Queued rejection tasks do not survive realm disposal")
		realm:Destroy()
	end
	do
		local realm=fresh();local host,vm=realm.Host,realm.VM
		local parent=host:NewTarget();local child=vm.Object({})
		host:WrapTarget(child,{Parent=function()return parent end})
		local trace={}
		local function listen(target,name,capturing)
			vm:Call(vm.Get(target,"addEventListener"),{"x",function(args)local e=args[1];table.insert(trace,name..":"..vm.Get(e,"eventPhase"))end,capturing},target)
		end
		listen(parent,"capture",true);listen(parent,"bubble",false);listen(child,"target",false)
		host:Dispatch(child,host:NewEvent("x",{bubbles=true}))
		assert(table.concat(trace,",")=="capture:1,target:2,bubble:3","DOM-supplied stable parents participate in capture/target/bubble ordering")
		realm:Run("const pending=AbortSignal.timeout(100000);pending.addEventListener('abort',function(){record('late');});")
		assert(realm.Loop.TimerCount==1);realm:Destroy();assert(realm.Loop.TimerCount==0,"Host disposal cancels pending abort timeouts")
	end
	do
		local realm=fresh();local target=realm.VM.Object({});realm.Host:WrapTarget(target,{Handlers=true,Parent=function()return nil end})
		local count=0;realm.VM.Set(target,"onclick",function()count+=1;return false end)
		assert(not realm.Host:Dispatch(target,realm.Host:NewEvent("click",{cancelable=true})))
		assert(count==1,"Ordinary VM target handlers use descriptor setters")
		realm.VM.Set(target,"onclick",VM.Null);realm.Host:Dispatch(target,realm.Host:NewEvent("click"));assert(count==1)
		realm.VM.Set(target,"oncustom",false);assert(realm.VM.Get(target,"oncustom")==false,"Unknown on* names remain ordinary expandos")
		realm:Destroy()
	end
	-- Roblox text measurement yields in a native API while JS remains logically
	-- synchronous. Its host entry must suspend, not lose the interpreted stack.
	do
		local realm=fresh();local vm,async=realm.VM,realm.Async
		vm.Global.Bindings.measure={Value=function()
			local a,b,c=async:HostCall(function()return coroutine.yield("native-measure")end)
			assert(a==17 and b==nil and c==23,"HostCall preserves all return values, including nil holes")
			return a+c
		end}
		local entry=coroutine.create(function()realm:Run("async function inner(){return measure();} async function outer(){record('before'); const n=await inner(); record(n);} outer();record('entry-return');")end)
		local ok,marker=coroutine.resume(entry);assert(ok and marker=="native-measure" and coroutine.status(entry)=="suspended")
		assert(table.concat(realm.Values,",")=="before","Native host suspension does not settle or continue nested async JS")
		local finished,message=coroutine.resume(entry,17,nil,23);assert(finished,tostring(message))
		assert(coroutine.status(entry)=="dead" and table.concat(realm.Values,",")=="before,entry-return,40")
		assert(#realm.Reports==0,"A handled native suspension must not become Unexpected suspension")
		realm:Destroy()
	end
	do
		local realm=fresh();local vm,async=realm.VM,realm.Async
		vm.Global.Bindings.measure={Value=function()return async:HostCall(function()coroutine.yield("native-error");VM.throw("measurement failed")end)end}
		local entry=coroutine.create(function()realm:Run("async function run(){try{measure();}catch(e){record(e);}} run();")end)
		local ok,marker=coroutine.resume(entry);assert(ok and marker=="native-error")
		local done,message=coroutine.resume(entry);assert(done,tostring(message))
		assert(table.concat(realm.Values,",")=="measurement failed" and #realm.Reports==0,"Native host failures preserve the JS exception value")
		realm:Destroy()
	end
	do
		local realm=fresh();local async=realm.Async;local continued=false
		local entry=coroutine.create(function()return async:Start(function()async:HostCall(function()coroutine.yield("native-dispose")end);continued=true;return 1 end)end)
		local ok,marker=coroutine.resume(entry);assert(ok and marker=="native-dispose")
		async:Destroy();local finished,message=coroutine.resume(entry);assert(finished,tostring(message))
		assert(not continued and coroutine.status(entry)=="dead","Destroy during host suspension closes the managed continuation")
		realm:Destroy()
	end
	print("JavaScript async expansion: "..#fixtures.." shared traces, task-queued rejection hooks, DOM events, native yielding host calls and lifecycle passed")
end
