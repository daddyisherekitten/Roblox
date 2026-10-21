--!strict
-- One bounded task-loop dispatch for all posted work. No private Heartbeat,
-- native-priority claims, or author callbacks invoked from a timer setter.
local TaskSignals=require(script.Parent.TaskSignals)
local Scheduler={}
function Scheduler.install(vm: any,globals: any,options: any): any
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local loop,events=options.Loop,options.Events
	local api={Alive=true,Count=0};local tasks,running={},{};local sequence=0;local dispatchID,dispatchDue
	local signals=TaskSignals.install(vm,globals,events)
	local weights={background=0,['user-visible']=2,['user-blocking']=4}
	local function check()assert(api.Alive and vm.Alive,'JavaScript scheduler disposed')end
	local function fail(message)VM.throw(VM.error('TypeError',message))end
	local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,N))end
	local function native(name,length,action)
		local fn={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return action(args,receiver)end}
		define(fn,'name',{value=name,configurable=true});define(fn,'length',{value=length,configurable=true});return fn
	end
	local prototype=vm.Object({});local instance=vm.Object({},prototype)
	local constructor=native('Scheduler',0,function()fail('Illegal Scheduler constructor')end)
	constructor.Construct=function()check();fail('Illegal Scheduler constructor')end
	define(constructor,'prototype',{value=prototype});define(prototype,'constructor',{value=constructor,writable=true,configurable=true})
	if vm.SymbolToStringTag then define(prototype,vm.SymbolToStringTag,{value='Scheduler',configurable=true})end
	local function global(name,value)
		globals[name]=value;vm.GlobalEnvironment:Define(name,vm.Object({value=value,writable=true,enumerable=false,configurable=true},N),true)
	end
	global('Scheduler',constructor);vm.Prototypes.Scheduler=prototype
	-- The global attribute is replaceable, not a writable data property. Global
	-- binding reads use the environment's private object as their receiver.
	local function globalReceiver(receiver)
		if receiver~=nil and receiver~=U and receiver~=N and receiver~=globals.globalThis and receiver~=vm.GlobalEnvironment.Properties then fail('Illegal scheduler receiver')end
	end
	globals.scheduler=instance;api.InventoryRoots={scheduler=instance}
	vm.GlobalEnvironment:Define('scheduler',vm.Object({
		get=native('get scheduler',0,function(_,receiver)globalReceiver(receiver);return instance end),
		set=native('set scheduler',1,function(args,receiver)
			globalReceiver(receiver);local value=if args[1]==nil then U else args[1]
			vm.GlobalEnvironment:Define('scheduler',vm.Object({value=value,writable=true,enumerable=true,configurable=true},N),true)
			globals.scheduler=value
			return U
		end),enumerable=true,configurable=true},N),true)
	local schedule
	local function disconnect(record)
		local action=record.Disconnect;record.Disconnect=nil;if action then action()end
	end
	local function remove(record,keepAbort)
		if tasks[record.Sequence]~=record then return false end
		tasks[record.Sequence]=nil;api.Count-=1
		if not keepAbort then disconnect(record)end
		return true
	end
	local function rank(record)
		return weights[if record.State.PrioritySignal then record.State.PrioritySignal.Priority else record.State.Priority]+(if record.Continuation then 1 else 0)
	end
	local function run()
		dispatchID,dispatchDue=nil,nil;if not api.Alive then return end
		local now=loop:Now();local selected
		for _,record in tasks do
			if record.Due<=now and(not selected or rank(record)>rank(selected)or rank(record)==rank(selected)and(record.Due<selected.Due or record.Due==selected.Due and record.Sequence<selected.Sequence))then selected=record end
		end
		if not selected then schedule();return end
		remove(selected,true);running[selected]=true
		local previous=loop.ContinuationState;loop.ContinuationState=selected.State
		local ok,result=pcall(function()
			return if selected.Continuation then U else vm:Call(selected.Callback,{},U)
		end)
		-- Promise assimilation reads then synchronously, in the callback context.
		if api.Alive then
			if ok then selected.Resolve({result})else selected.Reject({VM.exceptionValue(result)})end
		end
		disconnect(selected);running[selected]=nil
		loop.ContinuationState=if loop.Alive then previous else nil
		selected.Callback=nil;selected.Resolve=nil;selected.Reject=nil;selected.State=nil
		if api.Alive then schedule()end
	end
	schedule=function()
		if not api.Alive then return end
		local due
		for _,record in tasks do due=if due then math.min(due,record.Due)else record.Due end
		if due==dispatchDue and dispatchID then return end
		local old=dispatchID;dispatchID,dispatchDue=nil,nil;if old then loop:CancelTask(old)end
		if due then dispatchDue=due;dispatchID=loop:QueueTask(run,math.max(0,due-loop:Now()))end
	end
	local function post(callback,state,delay,continuation,resolve,reject)
		local signal=state.AbortSignal
		if signal and events:IsAborted(signal)then reject({events:AbortReason(signal)});return end
		assert(api.Count<1024,'JavaScript scheduler task budget exceeded')
		sequence+=1;local record={Sequence=sequence,Callback=callback,State=state,Due=loop:Now()+delay/1000,Continuation=continuation,Resolve=resolve,Reject=reject}
		tasks[sequence]=record;api.Count+=1
		if signal then record.Disconnect=events:SubscribeAbort(signal,function()
			if not api.Alive then return end
			if running[record]then reject({events:AbortReason(signal)});return end
			if not remove(record)then return end
			reject({events:AbortReason(signal)});record.Callback=nil;record.Resolve=nil;record.Reject=nil;record.State=nil;schedule()
		end)end
		schedule()
	end
	local function promiseOperation(action)
		local promise,resolve,reject=options.Promises:CreateCapability()
		local ok,message=pcall(action,resolve,reject)
		if not ok and api.Alive then reject({VM.exceptionValue(message)})end
		return promise
	end
	define(prototype,'postTask',{value=native('postTask',1,function(args,receiver)
		return promiseOperation(function(resolve,reject)
			if receiver~=instance then fail('Illegal Scheduler receiver')end
			if #args<1 or not VM.callable(args[1])then fail('postTask requires a callback')end
			local dictionary=args[2]
			if dictionary==nil or dictionary==U or dictionary==N then dictionary=nil
			elseif not vm.ObjectModel.IsObject(dictionary)then fail('Scheduler options must be a dictionary')end
			-- Web IDL dictionaries read members in lexicographic order.
			local delay=if dictionary then vm.Get(dictionary,'delay')else U
			if delay==U then delay=0 else
				delay=VM.number(vm.ToPrimitive(delay,'number'))
				if delay~=delay or math.abs(delay)==math.huge then fail('Task delay must be finite')end
				delay=if delay<0 then math.ceil(delay)else math.floor(delay)
				if delay<0 or delay>=18446744073709551616 then fail('Task delay is out of range')end
			end
			local priority=if dictionary then vm.Get(dictionary,'priority')else U
			if priority~=U then priority=signals:Priority(priority)end
			local signal=if dictionary then vm.Get(dictionary,'signal')else U
			if signal~=U then events:IsAborted(signal)else signal=nil end
			local signalState=signal and signals:Get(signal)
			post(args[1],{AbortSignal=signal,Priority=if priority~=U then priority else 'user-visible',PrioritySignal=if priority==U then signalState else nil},delay,false,resolve,reject)
		end)
	end),writable=true,enumerable=true,configurable=true})
	define(prototype,'yield',{value=native('yield',0,function(_,receiver)
		return promiseOperation(function(resolve,reject)
			if receiver~=instance then fail('Illegal Scheduler receiver')end
			post(nil,loop.ContinuationState or {Priority='user-visible'},0,true,resolve,reject)
		end)
	end),writable=true,enumerable=true,configurable=true})
	function api:IdleState()return {Priority='background'}end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false
		if dispatchID then loop:CancelTask(dispatchID)end;dispatchID,dispatchDue=nil,nil
		for _,record in tasks do if record.Disconnect then record.Disconnect()end;table.clear(record)end
		for record in running do disconnect(record);table.clear(record)end;table.clear(running)
		table.clear(tasks);self.Count=0;signals:Destroy();table.clear(options)
	end
	return api
end
return Scheduler
