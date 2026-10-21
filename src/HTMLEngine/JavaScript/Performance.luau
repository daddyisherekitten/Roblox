--!strict
-- User Timing and Performance Timeline. Delivery uses one ordinary event-loop
-- task per batch; an idle page has no connection, timer or polling work.
local Performance={}
local LEGACY={navigationStart=true,unloadEventStart=true,unloadEventEnd=true,redirectStart=true,redirectEnd=true,
	fetchStart=true,domainLookupStart=true,domainLookupEnd=true,connectStart=true,connectEnd=true,secureConnectionStart=true,
	requestStart=true,responseStart=true,responseEnd=true,domLoading=true,domInteractive=true,domContentLoadedEventStart=true,
	domContentLoadedEventEnd=true,domComplete=true,loadEventStart=true,loadEventEnd=true}
function Performance.install(vm: any,globals: any,options: any): any
	options=table.clone(options);local VM=vm.Model;local U,N=VM.Undefined,VM.Null
	local api={Alive=true};local loop=options.Loop
	local entries=setmetatable({},{__mode='kv'});local observers=setmetatable({},{__mode='kv'});local lists=setmetatable({},{__mode='kv'})
	local timeline,registered={},{};local queued=false;local serial=0
	local retainedCount,retainedBytes=0,0
	local maxEntries=options.MaxEntries or 2048;local maxBytes=options.MaxBytes or 8388608
	local entryPrototype=vm.Object({});local markPrototype=vm.Object({},entryPrototype);local measurePrototype=vm.Object({},entryPrototype)
	local observerPrototype,listPrototype=vm.Object({}),vm.Object({})
	local eventTargetPrototype=vm.Get(globals.EventTarget,'prototype');local performancePrototype=vm.Object({},eventTargetPrototype)
	local performance=vm.Object({},performancePrototype);performance.HostState={}
	local origin=options.TimeOrigin or os.time()*1000-loop:Timestamp()
	local function check()assert(api.Alive and vm.Alive,'Performance API disposed')end
	local function fail(message)VM.throw(VM.error('TypeError',message))end
	local function exception(name,message)VM.throw(options.HostEvents:DOMException(message,name))end
	local function arg(args,index)return if args[index]==nil then U else args[index]end
	local function object(value)return type(value)=='function'or(type(value)=='table'and value~=U and value~=N and value.Kind~='symbol'and value.Kind~='bigint')end
	local function text(value)
		local primitive=vm.ToPrimitive(value,'string');if type(primitive)=='table'and primitive.Kind=='symbol'then fail('Cannot convert Symbol to DOMString')end
		local result=VM.string(primitive);if #result>65536 then exception('QuotaExceededError','Performance name budget exceeded')end;return result
	end
	local function number(value)
		local primitive=vm.ToPrimitive(value,'number');if type(primitive)=='table'and(primitive.Kind=='symbol'or primitive.Kind=='bigint')then fail('Cannot convert value to a timestamp')end
		local result=VM.number(primitive);if result~=result or math.abs(result)==math.huge then fail('Timestamp must be finite')end;return result
	end
	local function dictionary(value)
		if value==U or value==N then return nil end;if not object(value)then fail('Options must be a dictionary')end;return value
	end
	local function field(value,key)return if value then vm.Get(value,key)else U end
	local function required(args,count,name)if #args<count then fail(name..' requires '..count..' arguments')end end
	local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,N))end
	local function native(name,length,action)
		local fn={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return action(args,receiver)end}
		define(fn,'name',{value=name,configurable=true});define(fn,'length',{value=length,configurable=true});return fn
	end
	local function method(proto,name,length,action)define(proto,name,{value=native(name,length,action),writable=true,enumerable=true,configurable=true})end
	local function accessor(proto,name,read)define(proto,name,{get=native('get '..name,0,function(_,receiver)return read(receiver)end),enumerable=true,configurable=true})end
	local function brand(registry,receiver,name)local state=registry[receiver];if not state then fail('Illegal '..name..' receiver')end;return state end
	local function performanceBrand(receiver)if receiver~=performance then fail('Illegal Performance receiver')end end
	local function constructor(name,length,proto,construct)
		local fn=native(name,length,function()fail(name..' requires new')end);fn.Construct=function(args)check();if not construct then fail('Illegal '..name..' constructor')end;return construct(args)end
		define(fn,'prototype',{value=proto});define(proto,'constructor',{value=fn,writable=true,configurable=true})
		globals[name]=fn;vm.Global.Bindings[name]={Value=fn};return fn
	end
	local function acquire(value)
		local state=entries[value]
		if state.References==0 then
			if retainedCount>=maxEntries or retainedBytes+state.Bytes>maxBytes then exception('QuotaExceededError','Performance buffer budget exceeded; clear entries or drain observers')end
			retainedCount+=1;retainedBytes+=state.Bytes
		end;state.References+=1
	end
	local function release(value)
		local state=entries[value];state.References-=1
		if state.References==0 then retainedCount-=1;retainedBytes-=state.Bytes end
	end
	local function clearBuffer(buffer)for _,value in buffer do release(value)end;table.clear(buffer)end
	local function clonedDetail(value)
		if value==U or value==N then return if value==U then U else N,0 end
		local wire=options.Clone:Serialize(value,nil,65536);return options.Clone:Deserialize(wire),wire.ByteLength
	end
	local function entry(name,kind,start,duration,detail)
		local cloned,bytes=clonedDetail(detail);serial+=1
		local value=vm.Object({},if kind=='mark'then markPrototype else measurePrototype)
		local state={Name=name,Type=kind,Start=start,Duration=duration,Detail=cloned,NavigationID=0,Sequence=serial,References=0,Bytes=bytes+#name+96}
		value.HostState=state;entries[value]=state;return value
	end
	local function entryState(receiver)return brand(entries,receiver,'PerformanceEntry')end
	for name,key in {name='Name',entryType='Type',startTime='Start',duration='Duration',navigationId='NavigationID'}do accessor(entryPrototype,name,function(receiver)return entryState(receiver)[key]end)end
	for kind,proto in {mark=markPrototype,measure=measurePrototype}do accessor(proto,'detail',function(receiver)local state=entryState(receiver);if state.Type~=kind then fail('Illegal Performance'..kind..' receiver')end;return state.Detail end)end
	method(entryPrototype,'toJSON',0,function(_,receiver)
		local state=entryState(receiver);local value=vm.Object({})
		-- Inherited PerformanceEntry.toJSON serializes its interface fields;
		-- PerformanceMark/Measure detail is a separate, cloneable getter.
		for _,pair in {{'name',state.Name},{'entryType',state.Type},{'startTime',state.Start},{'duration',state.Duration},{'navigationId',state.NavigationID}}do
			define(value,pair[1],{value=pair[2],writable=true,enumerable=true,configurable=true})
		end;return value
	end)
	local function filter(buffer,name,kind)
		local result={};for _,value in buffer do vm.Step();local state=entries[value];if(not name or state.Name==name)and(not kind or state.Type==kind)then table.insert(result,value)end end
		table.sort(result,function(a,b)local x,y=entries[a],entries[b];return if x.Start==y.Start then x.Sequence<y.Sequence else x.Start<y.Start end)
		return vm.Array(result)
	end
	local function installQueries(proto,getBuffer)
		method(proto,'getEntries',0,function(_,receiver)return filter(getBuffer(receiver),nil,nil)end)
		method(proto,'getEntriesByType',1,function(args,receiver)required(args,1,'getEntriesByType');local kind=text(args[1]);return filter(getBuffer(receiver),nil,kind)end)
		method(proto,'getEntriesByName',1,function(args,receiver)required(args,1,'getEntriesByName');local name=text(args[1]);local kind=if arg(args,2)==U then nil else text(args[2]);return filter(getBuffer(receiver),name,kind)end)
	end
	installQueries(performancePrototype,function(receiver)performanceBrand(receiver);return timeline end)
	installQueries(listPrototype,function(receiver)return brand(lists,receiver,'PerformanceObserverEntryList')end)
	local function list(buffer)local value=vm.Object({},listPrototype);value.HostState=buffer;lists[value]=buffer;return value end
	local deliver
	local function preflightSchedule()
		if not queued and loop.TaskCount>=1024 then exception('QuotaExceededError','Performance delivery task budget exceeded')end
	end
	local function schedule()
		if queued then return end
		preflightSchedule()
		loop:QueueTask(function()if api.Alive then deliver()end end);queued=true
	end
	deliver=function()
		queued=false;local snapshot=table.clone(registered)
		for _,value in snapshot do
			if not api.Alive then break end
			local state=observers[value];local buffer=state.Buffer;state.Buffer={}
			if #buffer==0 then continue end
			local callbackOptions=vm.Object({});if state.RequiresDropped then callbackOptions.Values.droppedEntriesCount=0;state.RequiresDropped=false end
			-- A delivered list owns ordinary references rather than internal buffer
			-- quota; release before author code so callbacks may clear/re-mark.
			for _,item in buffer do release(item)end
			local ok,message=pcall(function()options.Call(state.Callback,{list(buffer),value,callbackOptions},value)end)
			if not ok and options.Report and api.Alive then options.Report(VM.exceptionValue(message))end
		end
	end
	local function append(value)
		-- Validate once before touching any observer queue. Shared references to
		-- an entry consume the global record/detail quota only once.
		local kind=entries[value].Type
		local pending=false
		for _,observer in registered do local state=observers[observer];if state.Types[kind]then
			if #state.Buffer>=4096 then exception('QuotaExceededError','Performance observer queue budget exceeded')end;pending=true
		end end
		if pending then preflightSchedule()end
		acquire(value);table.insert(timeline,value)
		for _,observer in registered do local state=observers[observer];if state.Types[kind]then acquire(value);table.insert(state.Buffer,value)end end
		if pending then schedule()end;return value
	end
	local function mark(args)
		required(args,1,'PerformanceMark');local name=text(args[1]);local opts=dictionary(arg(args,2))
		local detail=field(opts,'detail');local start=field(opts,'startTime');if start~=U then start=number(start)end
		if LEGACY[name]then exception('SyntaxError','Reserved navigation timing mark name')end
		if start==U then start=loop:Timestamp()elseif start<0 then fail('Mark startTime cannot be negative')end
		return entry(name,'mark',start,0,if detail==U then N else detail)
	end
	local function timestamp(value)
		if type(value)=='string'then
			if LEGACY[value]then if value=='navigationStart'then return 0 end;exception('InvalidAccessError','Navigation timing data is not available')end
			local latest=nil
			for _,item in timeline do local state=entries[item];if state.Type=='mark'and state.Name==value and(latest==nil or state.Start>=latest)then latest=state.Start end end
			if latest~=nil then return latest end
			exception('SyntaxError','The mark '..value..' does not exist')
		end
		local result=number(value);if result<0 then fail('Timestamp cannot be negative')end;return result
	end
	local function markUnion(value)return if type(value)=='number'then number(value)else text(value)end
	method(performancePrototype,'mark',1,function(args,receiver)performanceBrand(receiver);return append(mark(args))end)
	method(performancePrototype,'measure',1,function(args,receiver)
		performanceBrand(receiver);required(args,1,'measure');local name=text(args[1]);local second=arg(args,2);local third=arg(args,3)
		local detail,duration,finish,start=U,U,U,U;local startMark=nil
		if second==U or second==N or object(second)then
			local opts=dictionary(second);detail=field(opts,'detail');duration=field(opts,'duration');if duration~=U then duration=number(duration)end
			finish=field(opts,'end');if finish~=U then finish=markUnion(finish)end
			start=field(opts,'start');if start~=U then start=markUnion(start)end
		else startMark=text(second)end
		if third~=U then third=text(third)end
		if detail~=U or duration~=U or finish~=U or start~=U then
			if third~=U then fail('End mark cannot be combined with measure options')end
			if start==U and finish==U then fail('Measure options require start or end')end
			if start~=U and duration~=U and finish~=U then fail('Measure options cannot specify start, end and duration together')end
		end
		local endTime=if third~=U then timestamp(third)elseif finish~=U then timestamp(finish)
			elseif start~=U and duration~=U then timestamp(start)+duration else loop:Timestamp()
		local startTime=if start~=U then timestamp(start)elseif finish~=U and duration~=U then timestamp(finish)-duration
			elseif startMark then timestamp(startMark)else 0
		return append(entry(name,'measure',startTime,endTime-startTime,if detail==U then N else detail))
	end)
	for name,kind in {clearMarks='mark',clearMeasures='measure'}do method(performancePrototype,name,0,function(args,receiver)
		performanceBrand(receiver);local target=if arg(args,1)==U then nil else text(args[1])
		for i=#timeline,1,-1 do local value=timeline[i];local state=entries[value];if state.Type==kind and(not target or state.Name==target)then release(value);table.remove(timeline,i)end end;return U
	end)end
	method(performancePrototype,'now',0,function(_,receiver)performanceBrand(receiver);return loop:Timestamp()end)
	accessor(performancePrototype,'timeOrigin',function(receiver)performanceBrand(receiver);return origin end)
	method(performancePrototype,'toJSON',0,function(_,receiver)performanceBrand(receiver);return vm.Object({timeOrigin=origin})end)
	local function observerState(receiver)return brand(observers,receiver,'PerformanceObserver')end
	method(observerPrototype,'observe',0,function(args,receiver)
		local state=observerState(receiver);local opts=dictionary(arg(args,1))
		-- Dictionary member conversion follows WebIDL's alphabetical order.
		local buffered=field(opts,'buffered');if buffered~=U then buffered=VM.truth(buffered)end
		local threshold=field(opts,'durationThreshold');if threshold~=U then threshold=number(threshold)end
		local entryTypes=field(opts,'entryTypes');local kinds={}
		if entryTypes~=U then
			if not object(entryTypes)then fail('entryTypes must be an iterable object')end
			local nextValue,close=vm.Iterator(entryTypes);local count=0
			local ok,message=pcall(function()while true do local more,item=nextValue();if not more then break end;count+=1;vm.Step();if count>1024 then exception('QuotaExceededError','Performance entryTypes budget exceeded')end;local kind=text(item);if kind=='mark'or kind=='measure'then kinds[kind]=true end end end)
			if not ok then if close then pcall(close)end;error(message,0)end
		end
		local kind=field(opts,'type');if kind~=U then kind=text(kind)end
		if entryTypes==U and kind==U then fail('observe requires type or entryTypes')end
		-- Chromium converts but ignores buffered/durationThreshold for the
		-- multiple-types mode; mixing type and entryTypes remains an error.
		if entryTypes~=U and kind~=U then fail('entryTypes cannot be combined with type')end
		local mode=if entryTypes~=U then 'multiple'else 'single'
		if state.Mode and state.Mode~=mode then exception('InvalidModificationError','Cannot switch performance observer type')end
		if(mode=='multiple'and not next(kinds))or(mode=='single'and kind~='mark'and kind~='measure')then state.Mode=mode;state.RequiresDropped=true;return U end
		if not state.Registered and #registered>=256 then exception('QuotaExceededError','Performance observer budget exceeded')end
		local matches={}
		if mode=='single'and buffered==true then
			-- Repeated buffered observe calls append again, just as the standard
			-- specifies. Bound the queue even when it contains duplicate entries.
			for _,value in timeline do if entries[value].Type==kind then table.insert(matches,value)end end
			if #state.Buffer+#matches>4096 then exception('QuotaExceededError','Performance observer queue budget exceeded')end
			preflightSchedule()
		end
		state.Mode=mode;state.RequiresDropped=true
		if mode=='multiple'then state.Types=kinds else state.Types[kind]=true end
		if not state.Registered then state.Registered=true;table.insert(registered,receiver)end
		if mode=='single'and buffered==true then
			for _,value in matches do acquire(value);table.insert(state.Buffer,value)end
			-- Native buffered registration orders the whole pending snapshot; live
			-- entries still append, and takeRecords itself does not reorder them.
			table.sort(state.Buffer,function(a,b)local x,y=entries[a],entries[b];return if x.Start==y.Start then x.Sequence<y.Sequence else x.Start<y.Start end)
			schedule()
		end;return U
	end)
	method(observerPrototype,'disconnect',0,function(_,receiver)
		local state=observerState(receiver);for i=#registered,1,-1 do if registered[i]==receiver then table.remove(registered,i);break end end
		state.Registered=false;table.clear(state.Types);clearBuffer(state.Buffer);return U
	end)
	method(observerPrototype,'takeRecords',0,function(_,receiver)
		local state=observerState(receiver);local buffer=state.Buffer;state.Buffer={};for _,value in buffer do release(value)end;return vm.Array(buffer)
	end)
	constructor('Performance',0,performancePrototype,nil)
	constructor('PerformanceEntry',0,entryPrototype,nil)
	constructor('PerformanceMark',1,markPrototype,mark)
	constructor('PerformanceMeasure',0,measurePrototype,nil)
	local observerConstructor=constructor('PerformanceObserver',1,observerPrototype,function(args)
		required(args,1,'PerformanceObserver');if not VM.callable(args[1])then fail('PerformanceObserver callback must be callable')end
		local value=vm.Object({},observerPrototype);local state={Callback=args[1],Buffer={},Types={},Registered=false,RequiresDropped=false}
		value.HostState=state;observers[value]=state;return value
	end)
	constructor('PerformanceObserverEntryList',0,listPrototype,nil)
	local supported=vm.Array({'mark','measure'})
	vm:Call(vm.Get(vm.Global.Bindings.Object.Value,'freeze'),{supported},U)
	accessor(observerConstructor,'supportedEntryTypes',function()return supported end)
	for name,proto in {Performance=performancePrototype,PerformanceEntry=entryPrototype,PerformanceMark=markPrototype,
		PerformanceMeasure=measurePrototype,PerformanceObserver=observerPrototype,PerformanceObserverEntryList=listPrototype}do
		if vm.SymbolToStringTag then define(proto,vm.SymbolToStringTag,{value=name,configurable=true})end
	end
	vm.SetPrototype(globals.Performance,globals.EventTarget);vm.SetPrototype(globals.PerformanceMark,globals.PerformanceEntry);vm.SetPrototype(globals.PerformanceMeasure,globals.PerformanceEntry)
	options.HostEvents:WrapTarget(performance,{Standalone=true,Parent=function()return nil end})
	globals.performance=performance;vm.Global.Bindings.performance={Value=performance}
	api.Value=performance
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false;queued=false
		for _,value in registered do local state=observers[value];table.clear(state.Buffer);table.clear(state.Types);state.Registered=false end
		table.clear(registered);table.clear(timeline);table.clear(entries);table.clear(observers);table.clear(lists);table.clear(options)
		retainedCount,retainedBytes=0,0
	end
	return api
end
return Performance
