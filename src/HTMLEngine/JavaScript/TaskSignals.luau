--!strict
-- Task priorities extend genuine AbortController/AbortSignal instances. No
-- polling, second abort registry, or permanent roots for unused derived signals.
local TaskSignals={}
function TaskSignals.install(vm: any,globals: any,events: any): any
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null
	local api={Alive=true};local states=setmetatable({},{__mode='kv'})
	local controllers=setmetatable({},{__mode='kv'});local eventStates=setmetatable({},{__mode='kv'})
	local abortController,abortSignal,eventConstructor=globals.AbortController,globals.AbortSignal,globals.Event
	local abortSignalPrototype=vm.Get(abortSignal,'prototype');local abortControllerPrototype=vm.Get(abortController,'prototype')
	local signalGetter=vm.Get(vm.GetOwnPropertyDescriptor(abortControllerPrototype,'signal'),'get')
	local abortAny=vm.Get(abortSignal,'any')
	local function check()assert(api.Alive and vm.Alive,'JavaScript task signals disposed')end
	local function fail(message)VM.throw(VM.error('TypeError',message))end
	local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,N))end
	local function native(name,length,action)
		local fn={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return action(args,receiver)end}
		define(fn,'name',{value=name,configurable=true});define(fn,'length',{value=length,configurable=true});return fn
	end
	local function global(name,value)
		globals[name]=value;vm.GlobalEnvironment:Define(name,vm.Object({value=value,writable=true,enumerable=false,configurable=true},N),true)
	end
	local function priority(value)
		local result=VM.string(vm.ToPrimitive(value,'string'))
		if result~='user-blocking'and result~='user-visible'and result~='background'then fail('Invalid task priority')end
		return result
	end
	local function dictionary(value)
		if value==nil or value==U or value==N then return nil end
		if not vm.ObjectModel.IsObject(value)then fail('Task options must be a dictionary')end;return value
	end
	local function field(value,key)return if value then vm.Get(value,key)else U end
	local signalPrototype=vm.Object({},abortSignalPrototype)
	local controllerPrototype=vm.Object({},abortControllerPrototype)
	local eventPrototype=vm.Object({},vm.Get(eventConstructor,'prototype'))
	local function state(receiver)local result=states[receiver];if not result then fail('Illegal TaskSignal receiver')end;return result end
	local function accessor(proto,key,read,write)
		define(proto,key,{get=native('get '..key,0,function(_,receiver)return read(receiver)end),
			set=if write then native('set '..key,1,function(args,receiver)write(receiver,if args[1]==nil then U else args[1]);return U end)else U,enumerable=true,configurable=true})
	end
	local function constructor(name,length,proto,create,parent)
		local fn=native(name,length,function()fail(name..' requires new')end);fn.Construct=function(args)check();return create(args)end
		define(fn,'prototype',{value=proto});define(proto,'constructor',{value=fn,writable=true,configurable=true})
		if parent then vm.SetPrototype(fn,parent)end;global(name,fn);vm.Prototypes[name]=proto
		if vm.SymbolToStringTag then define(proto,vm.SymbolToStringTag,{value=name,configurable=true})end;return fn
	end
	local function retain(signal,record)
		local source=record.Source and record.Source[1];local root=source and states[source]
		if root then root.Roots[signal]=if events:SignalObserved(signal,'prioritychange')then true else nil end
	end
	local function wrap(signal,value,source)
		local record={Priority=value,Changing=false,Dependents=setmetatable({},{__mode='v'}),Roots={},Next=0,Fixed=source==false}
		if source and source~=false then
			local root=states[source];local original=if root.Source then root.Source[1]else source
			local originalState=original and states[original]
			if originalState then
				if originalState.Next>=4096 then
					local live={};for _,dependent in originalState.Dependents do if states[dependent]then table.insert(live,dependent)end end
					originalState.Dependents=setmetatable(live,{__mode='v'});originalState.Next=#live
				end
				assert(originalState.Next<4096,'Dependent task signal budget exceeded')
				record.Source=setmetatable({original},{__mode='v'});originalState.Next+=1;originalState.Dependents[originalState.Next]=signal
			end
		end
		states[signal]=record;signal.TaskPriorityState=record;vm.SetPrototype(signal,signalPrototype)
		events:ObserveSignalUsage(signal,function()if api.Alive then retain(signal,record)end end)
		return signal
	end
	accessor(signalPrototype,'priority',function(receiver)return state(receiver).Priority end)
	accessor(signalPrototype,'onprioritychange',function(receiver)state(receiver);return events:HandlerGet(receiver,'onprioritychange')end,
		function(receiver,value)state(receiver);events:HandlerSet(receiver,'onprioritychange',value)end)
	accessor(eventPrototype,'previousPriority',function(receiver)local value=eventStates[receiver];if not value then fail('Illegal TaskPriorityChangeEvent receiver')end;return value.Priority end)
	constructor('TaskPriorityChangeEvent',2,eventPrototype,function(args)
		if #args<2 then fail('TaskPriorityChangeEvent requires type and init')end
		local eventType=VM.string(vm.ToPrimitive(args[1],'string'))
		local init=dictionary(args[2]);local event=vm:Construct(eventConstructor,{eventType,args[2]})
		local previous=field(init,'previousPriority');if previous==U then fail('previousPriority is required')end
		local record={Priority=priority(previous)};eventStates[event]=record;event.TaskPriorityState=record;vm.SetPrototype(event,eventPrototype);return event
	end,eventConstructor)
	local function changed(signal,value)
		local record=state(signal)
		if record.Changing then VM.throw(events:DOMException('Task priority is already changing','NotAllowedError'))end
		if record.Priority==value then return end
		record.Changing=true;local previous=record.Priority;record.Priority=value
		local ok,message=pcall(function()
			local event=events:NewEvent('prioritychange');local eventRecord={Priority=previous};eventStates[event]=eventRecord;event.TaskPriorityState=eventRecord;vm.SetPrototype(event,eventPrototype)
			events:Dispatch(signal,event,true)
			if not api.Alive then return end
			for _,dependent in record.Dependents do vm.Step();if states[dependent]then changed(dependent,value)end end
		end)
		record.Changing=false;if not ok then error(message,0)end
	end
	constructor('TaskSignal',0,signalPrototype,function()fail('Illegal TaskSignal constructor')end,abortSignal)
	define(globals.TaskSignal,'any',{value=native('any',1,function(args)
		if #args<1 then fail('TaskSignal.any requires signals')end
		-- Web IDL sequence conversion precedes the optional dictionary.
		local list={};local iterator=vm.Iterator(args[1])
		while true do local more,value=iterator();if not more then break end;vm.Step();events:IsAborted(value);assert(#list<1024,'TaskSignal source budget exceeded');table.insert(list,value)end
		local init=dictionary(args[2]);local value=field(init,'priority');if value==U then value='user-visible'end
		local source=states[value];local selected=if source then source.Priority else priority(value)
		local result=vm:Call(abortAny,{vm.Array(list)},abortSignal)
		return wrap(result,selected,if source and not source.Fixed then value else false)
	end),writable=true,enumerable=true,configurable=true})
	constructor('TaskController',0,controllerPrototype,function(args)
		local init=dictionary(args[1]);local value=field(init,'priority');if value==U then value='user-visible'end;value=priority(value)
		local controller=vm:Construct(abortController,{})
		-- Read the intrinsic accessor before replacing the instance prototype.
		local signal=vm:Call(signalGetter,{},controller);wrap(signal,value,nil);controllers[controller]=signal;controller.TaskPrioritySignal=signal
		vm.SetPrototype(controller,controllerPrototype);return controller
	end,abortController)
	define(controllerPrototype,'setPriority',{value=native('setPriority',1,function(args,receiver)
		local signal=controllers[receiver];if not signal then fail('Illegal TaskController receiver')end
		if #args<1 then fail('setPriority requires a priority')end;changed(signal,priority(args[1]));return U
	end),writable=true,enumerable=true,configurable=true})
	function api:Get(signal)return states[signal]end
	function api:Priority(value)return priority(value)end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false
		for _,record in states do table.clear(record.Dependents);table.clear(record.Roots);record.Source=nil end
		table.clear(states);table.clear(controllers);table.clear(eventStates)
	end
	return api
end
return TaskSignals
