--!strict
-- Cooperative task-loop idle slices, not a claim about Roblox compositor idle.
-- Positive timeouts use the existing task queue; there is no per-request driver.
local IdleCallbacks={}
function IdleCallbacks.install(vm: any,globals: any,options: any): any
	options=table.clone(options)
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local loop=options.Loop
	local api={Alive=true,Count=0};local callbacks={};local nextHandle=0;local periodUntil=0
	local deadlines=setmetatable({},{__mode='k'});local prototype=vm.Object({})
	local function check()assert(api.Alive and vm.Alive,'JavaScript idle callbacks disposed')end
	local function fail(message)VM.throw(VM.error('TypeError',message))end
	local function windowReceiver(receiver)
		if receiver~=nil and receiver~=U and receiver~=N and receiver~=options.Window then fail('Illegal Window receiver')end
	end
	local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,N))end
	local function native(name,length,action)
		local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return action(args,receiver)end}
		define(value,'name',{value=name,configurable=true});define(value,'length',{value=length,configurable=true});return value
	end
	local function global(name,value)
		globals[name]=value;vm.GlobalEnvironment:Define(name,vm.Object({value=value,writable=true,enumerable=true,configurable=true},N),true)
	end
	local function state(receiver)
		local record=deadlines[receiver];if not record then fail('Illegal IdleDeadline receiver')end;return record
	end
	define(prototype,'didTimeout',{get=native('get didTimeout',0,function(_,receiver)return state(receiver).TimedOut end),enumerable=true,configurable=true})
	define(prototype,'timeRemaining',{value=native('timeRemaining',0,function(_,receiver)
		local record=state(receiver);local ending=record.End
		local urgent=loop:NextTaskDue();if urgent then ending=math.min(ending,urgent)end
		return math.max(0,(ending-loop:Now())*1000)
	end),writable=true,enumerable=true,configurable=true})
	if vm.SymbolToStringTag then define(prototype,vm.SymbolToStringTag,{value='IdleDeadline',configurable=true})end
	local constructor=native('IdleDeadline',0,function()fail('Illegal IdleDeadline constructor')end)
	constructor.Construct=function()check();fail('Illegal IdleDeadline constructor')end
	define(constructor,'prototype',{value=prototype});define(prototype,'constructor',{value=constructor,writable=true,configurable=true})
	global('IdleDeadline',constructor);vm.Prototypes.IdleDeadline=prototype
	local function unsigned(value)
		local number=VM.number(vm.ToPrimitive(value,'number'))
		if number~=number or math.abs(number)==math.huge then return 0 end
		return(if number<0 then math.ceil(number)else math.floor(number))%4294967296
	end
	local function take(record)
		if callbacks[record.Handle]~=record then return nil end
		callbacks[record.Handle]=nil;api.Count-=1
		if record.TimeoutTask then loop:CancelTask(record.TimeoutTask);record.TimeoutTask=nil end
		local callback=record.Callback;record.Callback=nil;return callback
	end
	local function invoke(record,timedOut,ending)
		local callback=take(record);if not callback then return 0 end
		local deadline=vm.Object({},prototype);deadlines[deadline]={End=ending,TimedOut=timedOut}
		options.Invoke(callback,deadline);return 1
	end
	local function budget()
		if not api.Alive then return 0 end
		if options.CanRun and not options.CanRun()then return 0 end
		local value=1
		if options.GetBudget then
			local ok,result=pcall(options.GetBudget)
			if not api.Alive then return 0 end
			if not ok then if options.Report then options.Report('Idle budget host: '..tostring(result))end;return 0 end
			value=if type(result)=='number'and result==result then result else 0
		elseif loop.FrameCount>0 then return 0 end
		value=math.clamp(value,0,50)
		local due=loop:NextTaskDue();if due then value=math.min(value,math.max(0,(due-loop:Now())*1000))end
		return value
	end
	function api:NextDue()
		if not self.Alive or self.Count==0 or budget()<=0 then return nil end
		return math.max(loop:Now(),periodUntil)
	end
	function api:Pump()
		if not self.Alive or self.Count==0 or loop:Now()<periodUntil then return 0 end
		local remaining=budget();if remaining<=0 then return 0 end
		local first
		for _,record in callbacks do if not first or record.Handle<first.Handle then first=record end end
		if not first then return 0 end
		-- End the cooperative period after one callback. A callback registered
		-- recursively waits for a later period instead of draining the whole
		-- native task turn. Budgets remain cooperative, as in browser JS.
		periodUntil=loop:Now()+remaining/1000
		return invoke(first,false,periodUntil)
	end
	function api:Wake()if self.Alive and options.Wake then options.Wake()end end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false
		for _,record in callbacks do take(record)end
		loop:SetIdleSource(nil);table.clear(callbacks);table.clear(deadlines);table.clear(options)
	end
	global('requestIdleCallback',native('requestIdleCallback',1,function(args,receiver)
		windowReceiver(receiver)
		if #args<1 or not VM.callable(args[1])then fail('requestIdleCallback requires a callback function')end
		local dictionary=args[2];local timeout=0
		if dictionary~=nil and dictionary~=U and dictionary~=N then
			if not vm.ObjectModel.IsObject(dictionary)then fail('Idle callback options must be a dictionary')end
			local value=vm.Get(dictionary,'timeout');if value~=U then timeout=unsigned(value)end
		end
		if api.Count>=1024 or nextHandle>=4294967295 then VM.throw(VM.error('RangeError','Idle callback request budget exceeded'))end
		nextHandle+=1;local record={Handle=nextHandle,Callback=args[1]}
		if timeout>0 then record.TimeoutTask=loop:QueueTask(function()
			record.TimeoutTask=nil
			if api.Alive then invoke(record,true,loop:Now())end
		end,timeout/1000)end
		callbacks[record.Handle]=record;api.Count+=1;api:Wake();return record.Handle
	end))
	global('cancelIdleCallback',native('cancelIdleCallback',1,function(args,receiver)
		windowReceiver(receiver)
		if #args<1 then fail('cancelIdleCallback requires a handle')end
		local record=callbacks[unsigned(args[1])];if record then take(record);api:Wake()end;return U
	end))
	loop:SetIdleSource(api)
	return api
end
return IdleCallbacks
