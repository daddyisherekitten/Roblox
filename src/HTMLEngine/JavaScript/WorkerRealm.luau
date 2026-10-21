--!strict
-- DOM-free dedicated-worker realm. Scheduling and CPU isolation belong to the
-- host; this module never creates a coroutine on the page's JavaScript VM.
local VM=require(script.Parent.VM)
local Syntax=require(script.Parent.Syntax)
local EventLoop=require(script.Parent.EventLoop)
local Promises=require(script.Parent.Promises)
local AsyncFunctions=require(script.Parent.AsyncFunctions)
local HostEvents=require(script.Parent.HostEvents)
local NetworkData=require(script.Parent.NetworkData)
local StructuredClone=require(script.Parent.StructuredClone)
local Messaging=require(script.Parent.Messaging)
local Modules=require(script.Parent.Modules)
local Performance=require(script.Parent.Performance)
local Scheduler=require(script.Parent.Scheduler)
local WebLocks=require(script.Parent.WebLocks)
local DocumentOrigin=require(script.Parent.Parent.DOM.DocumentOrigin)
local WorkerAdapter=require(script.Parent.WorkerAdapter)
local WorkerRealm={}
function WorkerRealm.new(spec: any,options: any): any
	options=table.clone(options)
	local api={Alive=true,Closing=false,Ready=false};local globals={}
	local vm,host,promises,async,network,clone,messaging,modules,performance,workers,scheduler,webLocks
	local loop
	local scope;local reporting=false
	local incoming={};local incomingBytes,incomingCount=0,0
	local function check()assert(api.Alive,"Worker realm disposed")end
	local function hostCall(action)
		-- Actor synchronization can yield. Forward that work out of suspended
		-- JS stacks, as the page realm already does for native measurements.
		return if vm.Generators:IsActive()then vm.Generators:HostCall(action)else async:HostCall(action)
	end
	local function report(message,raw)
		if not api.Alive then return end
		local value=if raw or type(message)=="table"and message.Kind~=nil then message else VM.exceptionValue(message)
		local details={message=VM.string(value),filename=spec.url}
		if workers and host and not reporting then
			reporting=true
			local ok,accepted=pcall(function()return vm:ExecuteHost(function()
				local event=workers:NewErrorEvent("error",{message=details.message,filename=spec.url,error=value,cancelable=true})
				return host:Dispatch(scope,event,true)
			end)end)
			reporting=false;if ok and not accepted then return end
		end
		if options.Error then hostCall(function()options.Error(details)end) end
	end
	local function wake()
		if not api.Alive or not options.Wake then return end
		local due=loop and loop:NextDue()
		if api.Closing or loop and (#loop.Microtasks>0 or due and due<=loop:Now())then options.Wake()end
	end
	scope={HostState=api,Get=function(key)
		local binding=vm and vm.Global.Bindings[key]
		return if binding and not binding.Lexical then (if binding.Get then binding.Get() else binding.Value) else VM.Undefined
	end,Set=function(key,value,strict)
		check();if not vm then globals[key]=value;return end;local binding=vm.Global.Bindings[key]
		if binding and not binding.Lexical then
			if binding.Set then binding.Set(value,strict) else assert(not binding.Const,"Read-only worker global");binding.Value=value end
		else globals[key]=value;vm.Global.Bindings[key]={Value=value} end
	end}
	globals.self,globals.globalThis=scope,scope
	loop=EventLoop.new({Clock=options.Clock,Wake=wake,Report=report,
		AfterCheckpoint=function()if promises then promises:AfterCheckpoint() end end,
		Invoke=function(fn,args,kind)
			if not api.Alive or api.Closing and kind~="microtask" then return 0 end
			local ok,message=pcall(function()vm:ExecuteHost(function()
				if type(fn)=="string" then vm:Run(fn,spec.url) else vm:Call(fn,args,if kind=="timer" then scope else VM.Undefined) end
			end)end)
			if not ok then
				if vm.Steps>(options.MaxSteps or 30000)then api.Closing=true;wake()end
				report(message)
			end
			local steps=vm.Steps
			if api.Alive and not loop.Draining then loop:Checkpoint() end
			return steps
		end})
	for key,method in loop.Methods do if key~="requestAnimationFrame" and key~="cancelAnimationFrame" then globals[key]=method end end
	promises=Promises.new({Enqueue=function(fn)loop:QueueMicrotask(fn,true)end,QueueTask=function(fn)loop:QueueTask(fn)end,Report=report,
		CaptureContext=function()return loop.ContinuationState end,WithContext=function(state,callback)return loop:WithContinuation(state,callback)end,
		RejectionEvent=function(kind,promise,reason)return not host:Dispatch(scope,host:NewEvent(kind,{promise=promise,reason=reason,cancelable=kind=="unhandledrejection"},"PromiseRejectionEvent"),true)end,
		Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Construct=function(fn,args)return vm:Construct(fn,args)end,
		Get=function(object,key,receiver)return vm.Get(object,key,receiver)end,Iterator=function(value)return vm.Iterator(value)end,
		Array=function(items)return vm.Array(items)end,Object=function(values)return vm.Object(values)end})
	globals.Promise=promises.Constructor
	async=AsyncFunctions.new({Create=function()return promises:CreateCapability()end,Wait=function(value,yes,no)promises:Await(value,yes,no)end,
		Resume=function(record,rejected,value)return vm:ResumeAsync(record,rejected,value)end})
	vm=VM.new(globals,{MaxSteps=options.MaxSteps or 30000,Async=async,Checkpoint=options.Checkpoint})
	vm:Install(function()
		promises:Attach(vm);vm.Generators:AttachPromises(promises)
		vm.ResourceStacks:AttachPromises({CreatePromise=function()return promises:CreateCapability()end,
			Await=function(value,yes,no)promises:Await(value,function(args)yes(args[1])end,function(args)no(args[1])end)end})
	end)
	vm:Install(function()
		host=HostEvents.install(vm,globals,{Report=function(value)report(value,true)end,Now=function()return loop:Timestamp()end,
			AfterCallback=function()if not vm:IsRunningScript() and not loop.Draining then loop:Checkpoint() end end})
		host:WrapTarget(scope,{Handlers=true,GlobalErrorHandler=true,Standalone=true,Parent=function()return nil end})
		for _,key in {"addEventListener","removeEventListener","dispatchEvent"}do
			local method=host:TargetMethods(scope,key)
			globals[key]=function(args)return vm:Call(method,args,scope)end;vm.Global.Bindings[key]={Value=globals[key]}
		end
		for _,key in {"onmessage","onmessageerror","onerror","onunhandledrejection","onrejectionhandled"}do
			vm.Global.Bindings[key]={Get=function()return host:HandlerGet(scope,key)end,Set=function(value)host:HandlerSet(scope,key,value)end}
		end
		network=NetworkData.install(vm,globals,{HostEvents=host,BaseURL=spec.url,Fetch=options.Fetch,IsWorker=true,
			CreatePromise=function()return promises:CreateCapability()end,Enqueue=function(fn)loop:QueueMicrotask(fn)end,
			EnqueueTask=function(fn,delay)return loop:QueueTask(fn,delay)end,CancelTask=function(id)loop:CancelTask(id)end,RequestNow=function()return loop:Timestamp()end,
			Await=function(value,yes,no)promises:Await(value,function(args)yes(args[1])end,function(args)no(args[1])end)end})
		scheduler=Scheduler.install(vm,globals,{Loop=loop,Events=host,Promises=promises})
		clone=StructuredClone.install(vm,globals,{HostEvents=host,Binary=network.Binary,NetworkData=network})
		local url=vm:Construct(globals.URL,{spec.url});local origin=vm.Get(url,"origin")
		webLocks=WebLocks.install(vm,globals,{Store=options.WebLockStore,PartitionKey=options.WebLockPartitionKey,Origin=options.DocumentOrigin or DocumentOrigin.fromURL(spec.url),URL=spec.url,
			SecureContext=options.SecureContext,Events=host,CreatePromise=function()return promises:CreateCapability()end,
			Await=function(value,yes,no)promises:Await(value,function(args)yes(args[1])end,function(args)no(args[1])end)end,
			EnqueueTask=function(fn)return loop:QueueTask(fn)end,CancelTask=function(id)loop:CancelTask(id)end,IsFullyActive=function()return api.Alive and not api.Closing end})
		messaging=Messaging.install(vm,globals,{HostEvents=host,Clone=clone,Origin=origin,EnqueueTask=function(fn)loop:QueueTask(fn)end})
		workers=WorkerAdapter.install(vm,globals,{HostEvents=host,Clone=clone,Messaging=messaging,Origin=origin,BaseURL=spec.url,
			LoadScript=options.LoadScript,SpawnWorker=options.SpawnWorker,Report=report,EnqueueTask=function(fn)loop:QueueTask(fn)end})
		performance=Performance.install(vm,globals,{Loop=loop,HostEvents=host,Clone=clone,Report=report,
			Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,TimeOrigin=options.PerformanceTimeOrigin})
		modules=Modules.install(vm,globals,{BaseURL=spec.url,Promises=promises,Sources=options.Sources,
			LoadScript=options.LoadScript,QueueTask=function(fn)loop:QueueTask(fn)end})
		local location=vm.Object({})
		for _,key in {"href","origin","protocol","host","hostname","port","pathname","search","hash"}do
			vm.DefineProperty(location,key,vm.Object({get=function()return vm.Get(url,key)end,enumerable=true},VM.Null))
		end
		vm.DefineProperty(location,"toString",vm.Object({value=function()return spec.url end,configurable=true,writable=true},VM.Null))
		location.HostState=api
		for key,value in {location=location,name=spec.name or ""}do vm.Global.Bindings[key]={Value=value,Const=true}end
		globals.postMessage=function(args)
			check();if #args<1 then VM.throw(VM.error("TypeError","postMessage requires a message"))end
			local transfer=args[2] or VM.Undefined
			if transfer~=VM.Undefined and transfer~=VM.Null and not VM.callable(vm.Get(transfer,vm.SymbolIterator)) then transfer=vm.Get(transfer,"transfer")end
			if transfer~=VM.Undefined and transfer~=VM.Null then
				local list={};local nextValue,close=vm.Iterator(transfer)
				local ok,message=pcall(function()while true do local more,value=nextValue();if not more then break end
					if messaging:IsPort(value) and not options.SupportsPortTransfer then VM.throw(host:DOMException("Worker host cannot transfer MessagePort handles","DataCloneError"))end
					if #list>=1024 then VM.throw(host:DOMException("Worker transfer list budget exceeded","DataCloneError"))end
					table.insert(list,value)
				end end)
				if not ok then if close then pcall(close)end;error(message,0)end;transfer=vm.Array(list)
			end
			local wire=clone:Serialize(args[1],transfer)
			if options.Message then hostCall(function()options.Message(wire)end) else clone:Discard(wire) end;return VM.Undefined
		end
		globals.close=function()api.Closing=true;wake();return VM.Undefined end
		globals.importScripts=function(args)
			if spec.type=="module" then VM.throw(VM.error("TypeError","Module workers cannot use importScripts"))end
			local urls={};for _,value in args do
				local primitive=vm.ToPrimitive(value,"string");local text=VM.string(primitive)
				table.insert(urls,vm.Get(vm:Construct(globals.URL,{text,spec.url}),"href"))
			end
			for _,href in urls do
				local source=options.Sources and options.Sources[href]
				if type(source)=="table" then source=source.Source end
				if type(source)~="string" then VM.throw(host:DOMException("Synchronous worker resource is unavailable","NetworkError"))end
				vm:Run(source,href)
			end
			return VM.Undefined
		end
		for _,key in {"postMessage","close","importScripts"}do vm.Global.Bindings[key]={Value=globals[key]}end
	end)
	local function entry(callback)
		if not api.Alive or api.Closing then return end
		local ok,message=pcall(vm.ExecuteHost,vm,callback)
		if not ok then
			if vm.Steps>(options.MaxSteps or 30000)then api.Closing=true;wake()end
			report(message)
		end
		if api.Alive then loop:Checkpoint() end
		return ok,message
	end
	local function deliver(wire)
		loop:QueueTask(function()
			if not incoming[wire] then return end
			incoming[wire]=nil;incomingBytes-=wire.ByteLength or 0;incomingCount-=1
			local ok,data,ports=pcall(clone.Deserialize,clone,wire)
			if not ok then clone:Discard(wire) end
			host:Dispatch(scope,messaging:NewMessageEvent(if ok then "message" else "messageerror",{data=if ok then data else VM.Null,ports=if ok then ports else {}}),true)
		end)
	end
	local waiting={}
	local function ready()
		api.Ready=true;local queue=waiting;waiting={};for _,wire in queue do deliver(wire) end
	end
	function api:Start()
		if self.Started or not self.Alive then return end;self.Started=true
		if spec.type~="module"then
			local valid,message=pcall(Syntax.parse,spec.source)
			if not valid then report(VM.error("SyntaxError",tostring(message)));self.Closing=true;wake();return end
		end
		local ok=entry(function()
			if spec.type=="module" then
				-- The implicit port opens after starting module evaluation, not
				-- after its top-level await resolves. Applications must establish
				-- their own ready protocol if they install handlers after await.
				local prepared=modules:Prepare(spec.url,spec.url,nil,spec.source)
				promises:Await(prepared,function(args)
					local result=modules:Evaluate(args[1]);ready()
					promises:Await(result,function()end,function(errors)report(VM.string(errors[1]))end)
				end,function(errors)report(VM.string(errors[1]));api.Closing=true;wake()end)
			else vm:Run(spec.source,spec.url);ready() end
		end)
		if ok==false then
			if self.Closing then wake()else ready()end
		end
	end
	function api:PostMessage(wire)
		if not self.Alive or self.Closing then clone:Discard(wire);return end
		if incomingCount>=1024 or incomingBytes+(wire.ByteLength or 0)>4194304 then clone:Discard(wire);error("Worker incoming queue budget exceeded")end
		incoming[wire]=true;incomingBytes+=wire.ByteLength or 0;incomingCount+=1
		if self.Ready then deliver(wire) else table.insert(waiting,wire)end
	end
	function api:Pump()
		if self.Alive and not self.Closing then loop:Checkpoint();loop:PumpTasks() end
		if self.Closing and not self.Exited then
			self.Exited=true
			if options.Exit then options.Exit() end
		end
	end
	function api:NextDue()return if self.Alive and not self.Closing then loop:NextDue() else nil end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false
		for wire in incoming do clone:Discard(wire)end;table.clear(incoming);table.clear(waiting)
		workers:Destroy();performance:Destroy();modules:Destroy();messaging:Destroy();clone:Destroy();webLocks:Destroy();scheduler:Destroy();network:Destroy();host:Destroy();async:Destroy();promises:Destroy();loop:Destroy();vm:Destroy()
		table.clear(globals);table.clear(options)
	end
	api.VM,api.Loop,api.Clone,api.WebLocks=vm,loop,clone,webLocks
	return api
end
return WorkerRealm
