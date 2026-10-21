--!strict
-- Realm-owned Promise state and reaction jobs. Scheduling and VM evaluation
-- remain separate: jobs use the existing bounded microtask checkpoint.
local VM=require(script.Parent.VM)
local Promises={}
local function argument(args: any,index: number): any
	return if args[index]==nil then VM.Undefined else args[index]
end
local function isObject(value: any): boolean
	return type(value)=="function" or (type(value)=="table" and value~=VM.Undefined and value~=VM.Null and value.Kind~="symbol" and value.Kind~="bigint")
end
function Promises.new(options: any): any
	options=table.clone(options)
	local self={Alive=true}
	-- Wrappers/resolve functions own live states. This registry must not keep
	-- completed, unused chains alive for the lifetime of the document.
	local states=setmetatable({},{__mode="kv"})
	local unhandled={}
	local constructor,prototype,methods
	local create,resolving,resolveValue,reaction,thenPromise
	local function check()assert(self.Alive,"JavaScript promises disposed")end
	local function typeError(message)VM.throw(VM.error("TypeError",message))end
	local function enqueue(fn)options.Enqueue(fn)end
	local function context()return if options.CaptureContext then options.CaptureContext()else nil end
	local function callWithContext(state,callback)
		return if options.WithContext then options.WithContext(state,callback)else callback()
	end
	local function rejectionEvent(kind,state)
		if not self.Alive or not options.RejectionEvent then return false end
		local ok,canceled=pcall(options.RejectionEvent,kind,state.Promise,state.Value)
		if not ok and options.Report then options.Report("Promise rejection event: "..tostring(canceled))end
		return ok and canceled==true
	end
	local function task(fn)
		if options.QueueTask then options.QueueTask(fn)else fn()end
	end
	local function handled(state)
		if state.Handled then return end
		state.Handled=true
		if state.Reported and options.RejectionEvent then
			task(function()if self.Alive then rejectionEvent("rejectionhandled",state)end end)
		end
	end
	local function settle(state,status,value)
		if not self.Alive or state.Status~="pending" then return end
		state.Status,state.Value=status,value
		if status=="rejected" and not state.Handled then table.insert(unhandled,state)end
		local reactions=state.Reactions;state.Reactions={}
		for _,item in reactions do reaction(item,status,value) end
	end
	resolving=function(state)
		local resolved=false
		local function resolve(args)
			if resolved or not self.Alive then return VM.Undefined end
			resolved=true;resolveValue(state,argument(args,1));return VM.Undefined
		end
		local function reject(args)
			if resolved or not self.Alive then return VM.Undefined end
			resolved=true;settle(state,"rejected",argument(args,1));return VM.Undefined
		end
		return resolve,reject
	end
	resolveValue=function(state,value)
		if value==state.Promise then settle(state,"rejected",VM.error("TypeError","A promise cannot resolve to itself"));return end
		if not isObject(value) then settle(state,"fulfilled",value);return end
		-- Read then immediately; invoke it in a future job. Even a pending
		-- adoption consumes the original resolver's one permitted settlement.
		local ok,handler=pcall(options.Get,value,"then")
		if not ok then settle(state,"rejected",VM.exceptionValue(handler));return end
		if not VM.callable(handler) then settle(state,"fulfilled",value);return end
		local captured=context()
		enqueue(function()
			if not self.Alive then return end
			local resolve,reject=resolving(state)
			local success,result=pcall(callWithContext,captured,function()return options.Call(handler,{resolve,reject},value)end)
			if not success then reject({VM.exceptionValue(result)}) end
		end)
	end
	reaction=function(item,status,value)
		enqueue(function()
			if not self.Alive then return end
			local handler=if status=="fulfilled" then item.Fulfilled else item.Rejected
			if item.Internal then
				callWithContext(item.Context,function()return options.Call(handler,{value},VM.Undefined)end);return
			end
			if not VM.callable(handler) then
				(if status=="fulfilled" then item.Resolve else item.Reject)({value});return
			end
			-- Keep the callback's scheduling context through returned-thenable
			-- assimilation, matching the captured Chromium continuation profile.
			callWithContext(item.Context,function()
				local ok,result=pcall(options.Call,handler,{value},VM.Undefined)
				if ok then item.Resolve({result})else item.Reject({VM.exceptionValue(result)})end
			end)
		end)
	end
	create=function()
		check()
		local state={Status="pending",Value=VM.Undefined,Reactions={},Handled=false,Properties={}}
		local promise=options.Object(state.Properties);promise.PromiseBrand=true;if prototype.Prototype==nil then prototype.Prototype=promise.Prototype end;promise.Prototype=prototype
		promise.Get=function(key,receiver)check();return if state.Properties[key]~=nil then state.Properties[key]else options.Get(prototype,key,receiver or promise)end
		promise.Set=function(key,value)check();state.Properties[key]=value end
		state.Promise=promise;states[promise]=state
		local resolve,reject=resolving(state)
		return promise,resolve,reject
	end
	thenPromise=function(promise,fulfilled,rejected)
		check();local state=states[promise]
		if not state then typeError("Promise.then requires a promise receiver") end
		assert(#state.Reactions<1024,"JavaScript promise reaction budget exceeded")
		local child,resolve,reject=create()
		local item={Fulfilled=fulfilled,Rejected=rejected,Resolve=resolve,Reject=reject,Context=context()}
		handled(state)
		if state.Status=="pending" then table.insert(state.Reactions,item) else reaction(item,state.Status,state.Value) end
		return child
	end
	local function promiseResolve(value)
		if states[value] and options.Get(value,"constructor")==constructor then return value end
		local promise,resolve=create();resolve({value});return promise
	end
	local function invokeThen(receiver,fulfilled,rejected)
		return options.Call(options.Get(receiver,"then"),{fulfilled,rejected},receiver)
	end
	methods={}
	methods["then"]=function(args,receiver)return thenPromise(receiver,argument(args,1),argument(args,2))end
	methods["catch"]=function(args,receiver)return invokeThen(receiver,VM.Undefined,argument(args,1))end
	methods["finally"]=function(args,receiver)
		local handler=argument(args,1)
		if not VM.callable(handler) then return invokeThen(receiver,handler,handler) end
		local function finish(value,rejected)
			local result=options.Call(handler,{},VM.Undefined)
			return invokeThen(promiseResolve(result),function()
				if rejected then VM.throw(value) end;return value
			end,VM.Undefined)
		end
		return invokeThen(receiver,function(values)return finish(argument(values,1),false)end,
			function(values)return finish(argument(values,1),true)end)
	end
	prototype={Kind="object",Values=methods}
	local statics={}
	local function requireConstructor(receiver)check();if receiver~=constructor then typeError("Promise static method requires its constructor receiver") end end
	statics.resolve=function(args,receiver)requireConstructor(receiver);return promiseResolve(argument(args,1))end
	statics.reject=function(args,receiver)
		requireConstructor(receiver);local promise,_,reject=create();reject({argument(args,1)});return promise
	end
	local function capability(receiver)
		check()
		if receiver==constructor then return create()end
		if not options.Construct then typeError("Promise capability requires a constructor")end
		local resolve,reject=VM.Undefined,VM.Undefined
		local function executor(args)
			if resolve~=VM.Undefined or reject~=VM.Undefined then typeError("Promise capability executor called twice")end
			resolve,reject=argument(args,1),argument(args,2);return VM.Undefined
		end
		local promise=options.Construct(receiver,{executor})
		if not VM.callable(resolve) or not VM.callable(reject)then typeError("Promise constructor must supply callable resolving functions")end
		return promise,resolve,reject
	end
	statics.withResolvers=function(_,receiver)
		local promise,resolve,reject=capability(receiver)
		return options.Object({promise=promise,resolve=resolve,reject=reject})
	end
	statics["try"]=function(args,receiver)
		check();if not isObject(receiver) and not VM.callable(receiver)then typeError("Promise.try requires an object receiver")end
		-- Current ECMAScript draft/Chromium: callback first, then PromiseResolve.
		-- ES2025/Node 24 instead allocate the capability before the callback.
		local values={};for index=2,#args do values[index-1]=args[index]end
		local ok,result=pcall(options.Call,argument(args,1),values,VM.Undefined)
		if ok and states[result] and options.Get(result,"constructor")==receiver then return result end
		local promise,resolve,reject=capability(receiver)
		options.Call(if ok then resolve else reject,{if ok then result else VM.exceptionValue(result)},VM.Undefined)
		return promise
	end
	local function combine(mode,args,receiver)
		requireConstructor(receiver)
		local promise,resolve,reject=create()
		local ok,result=pcall(function()
			-- Capture resolve once, then read each input in iteration order. A
			-- replacement resolve/then may synchronously call our handlers.
			local resolveMethod=options.Get(constructor,"resolve")
			if not VM.callable(resolveMethod) then typeError("Promise.resolve must be callable") end
			local nextValue=options.Iterator(argument(args,1))
			local values={};local remaining=1;local count=0
			local function finish()
				if remaining~=0 or not self.Alive then return end
				local list=options.Array(table.clone(values))
				if mode=="any" then
					local failure=VM.error("AggregateError","All promises were rejected")
					failure.Set("errors",list);reject({failure})
				else resolve({list}) end
			end
			local function attach(value,index)
				local nextPromise=options.Call(resolveMethod,{value},constructor)
				if mode=="race" then invokeThen(nextPromise,resolve,reject);return end
				local called=false
				local function complete(args,rejected)
					if not self.Alive then return VM.Undefined end
					local value=argument(args,1)
					if mode=="all" and rejected then reject({value});return VM.Undefined end
					if mode=="any" and not rejected then resolve({value});return VM.Undefined end
					if called then return VM.Undefined end;called=true
					values[index]=if mode=="allSettled" then
						options.Object(if rejected then {status="rejected",reason=value} else {status="fulfilled",value=value})
						else value
					remaining-=1;finish();return VM.Undefined
				end
				invokeThen(nextPromise,function(args)return complete(args,false)end,
					function(args)return complete(args,true)end)
			end
			while true do
				local more,value=nextValue();if not more then break end
				assert(count<1024,"JavaScript promise input budget exceeded")
				count+=1
				if mode~="race" then values[count]=VM.Undefined;remaining+=1 end
				attach(value,count)
			end
			if mode~="race" then remaining-=1;finish() end
		end)
		if not ok then reject({VM.exceptionValue(result)}) end
		return promise
	end
	for _,mode in {"all","allSettled","race","any"} do
		statics[mode]=function(args,receiver)return combine(mode,args,receiver)end
	end
	local properties={}
	constructor={Kind="native-function",Values=properties,Call=function()typeError("Promise requires new")end,
		Construct=function(args)
			check();local executor=argument(args,1);if not VM.callable(executor) then typeError("Promise executor must be callable") end
			local promise,resolve,reject=create()
			local ok,result=pcall(options.Call,executor,{resolve,reject},VM.Undefined)
			if not ok then reject({VM.exceptionValue(result)}) end
			return promise
		end,
		Get=function(key)check();return if properties[key]~=nil then properties[key]else VM.Undefined end,
		Set=function(key,value)check();properties[key]=value end}
	properties.prototype,properties.name,properties.length=prototype,"Promise",1
	for key,value in statics do properties[key]=value end
	methods.constructor=constructor
	self.Constructor=constructor
	function self:Attach(vm)
		check();if self.Attached then return end;self.Attached=true
		prototype.Prototype=vm.Prototypes.Object;constructor.Prototype=vm.Prototypes.Function
		local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,VM.Null))end
		local function method(target,key,fn,length)
			local native={Kind="native-function",Call=fn,Values={},Prototype=vm.Prototypes.Function}
			define(native,"length",{value=length,configurable=true});define(native,"name",{value=key,configurable=true})
			define(target,key,{value=native,writable=true,enumerable=false,configurable=true})
		end
		define(constructor,"length",{value=1,writable=false,enumerable=false,configurable=true});define(constructor,"name",{value="Promise",writable=false,enumerable=false,configurable=true})
		define(constructor,"prototype",{value=prototype,writable=false,enumerable=false,configurable=false});define(prototype,"constructor",{value=constructor,writable=true,enumerable=false,configurable=true})
		for _,key in {"all","allSettled","any","race","resolve","reject","withResolvers","try"}do method(constructor,key,statics[key],if key=="withResolvers"then 0 else 1)end
		for _,key in {"then","catch","finally"}do method(prototype,key,methods[key],if key=="then"then 2 else 1)end
		if vm.SymbolToStringTag then define(prototype,vm.SymbolToStringTag,{value="Promise",configurable=true})end
	end
	-- Async functions use intrinsic PromiseResolve and internal reactions.
	-- No user-visible .then override or unused derived promise participates.
	function self:CreateCapability()
		return create()
	end
	function self:MarkHandled(promise)
		check();local state=states[promise]
		if not state then typeError('Expected an intrinsic Promise')end
		handled(state)
	end
	function self:Await(value,fulfilled,rejected)
		check();local promise=promiseResolve(value);local state=states[promise]
		assert(#state.Reactions<1024,"JavaScript promise reaction budget exceeded")
		local item={Internal=true,Fulfilled=fulfilled,Rejected=rejected,Context=context()}
		handled(state)
		if state.Status=="pending" then table.insert(state.Reactions,item) else reaction(item,state.Status,state.Value) end
	end
	function self:AfterCheckpoint()
		if not self.Alive then return end
		local pending=unhandled;unhandled={}
		if #pending==0 then return end
		local function notify()
			for _,state in pending do
				if not self.Alive then return end
				if state.Handled then continue end
				local canceled=rejectionEvent("unhandledrejection",state)
				if not state.Handled then state.Reported=true end
				if self.Alive and not canceled and options.Report then options.Report("Unhandled promise rejection: "..VM.string(state.Value))end
			end
		end
		if options.RejectionEvent then task(notify)else notify()end
	end
	function self:Destroy()
		if not self.Alive then return end;self.Alive=false
		for _,state in states do state.Value=nil;table.clear(state.Reactions);table.clear(state.Properties);state.Promise=nil end
		table.clear(states);table.clear(unhandled);table.clear(methods);table.clear(statics);table.clear(properties);table.clear(options)
	end
	return self
end
return Promises
