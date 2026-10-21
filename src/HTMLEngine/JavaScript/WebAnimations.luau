--!strict
-- Realm-owned Web Animations timing. The renderer supplies bounded paint hooks;
-- this module has no native connection and requests frames only while needed.
local Motion=require(script.Parent.Parent.CSS.Motion)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local WebAnimations={}
local styleEvents=setmetatable({},{__mode='k'})
function WebAnimations.install(vm: any,globals: any,options: any): any
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local host=options.HostEvents
	local api={Alive=true};local frameId,framePending=nil,false;local sequence=0
	local effects,animations,timelines,playbackEvents={},{},{},{}
	for _,map in {effects,animations,timelines,playbackEvents}do setmetatable(map,{__mode="kv"})end
	local ordered=setmetatable({},{__mode="v"});local retained={}
	local cssRecords=setmetatable({},{__mode='kv'});local syncCSSRecords,cssStop;local syncingCSS=false
	-- CSS keeps its controller even while API cancellation makes it idle. The
	-- authored source graph bounds these strong entries; removal clears them.
	local ownedControllers={}
	local eventProto=if globals.Event then vm.Get(globals.Event,"prototype")else vm.Prototypes.Object
	local targetProto=if globals.EventTarget then vm.Get(globals.EventTarget,"prototype")else vm.Prototypes.Object
	local animationProto,effectProto,timelineProto,playbackProto=vm.Object({},targetProto),vm.Object({}),vm.Object({}),vm.Object({},eventProto)
	local cssAnimationProto,cssTransitionProto=vm.Object({},animationProto),vm.Object({},animationProto)
	local function check()assert(api.Alive and vm.Alive,"Web animations disposed")end
	local function fail(name,message)VM.throw(if host and name~="TypeError" and name~="RangeError"then host:DOMException(message,name)else VM.error(name,message))end
	local function arg(args,index)return if args[index]==nil then U else args[index]end
	local function nullish(value)return value==nil or value==N or value==U end
	local function isObject(value)return (type(value)=="table"and not nullish(value)and value.Kind~="symbol"and value.Kind~="bigint")or type(value)=="function"end
	local function native(name,length,fn)
		local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end}
		vm.DefineProperty(value,"name",vm.Object({value=name,configurable=true},VM.Null));vm.DefineProperty(value,"length",vm.Object({value=length,configurable=true},VM.Null));return value
	end
	local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,VM.Null))end
	local function method(proto,key,length,fn)define(proto,key,{value=native(key,length,fn),writable=true,enumerable=true,configurable=true})end
	local function accessor(proto,key,read,write)
		define(proto,key,{get=native("get "..key,0,function(_,receiver)return read(receiver)end),set=if write then native("set "..key,1,function(args,receiver)write(receiver,arg(args,1));return U end)else U,enumerable=true,configurable=true})
	end
	local function state(map,value,name)
		local s=map[value];if not s then fail('TypeError','Illegal '..name..' receiver')end
		local owner=if map==animations then s elseif map==effects and s.Owner then animations[s.Owner]else nil
		if owner and owner.CSSRecord and not syncingCSS and options.PrepareCommit then options.PrepareCommit()end
		return s
	end
	local function dict(value)
		if nullish(value)then return nil end
		if not isObject(value)then fail("TypeError","Expected a dictionary")end;return value
	end
	local function field(value,key,fallback)local result=if value then vm.Get(value,key)else U;return if result==U then fallback else result end
	local function num(value,finite)
		local result=VM.number(vm.ToPrimitive(value,"number"));if result~=result or(finite and math.abs(result)==math.huge)then fail("TypeError","Invalid animation time")end;return result
	end
	local function text(value)
		value=vm.ToPrimitive(value,"string");if type(value)=="table"and value.Kind=="symbol"then fail("TypeError","Cannot convert Symbol to string")end
		local result=VM.string(value);if #result>65536 then fail("RangeError","Animation string budget exceeded")end;return result
	end
	local function enum(value,allowed,name)local result=text(value);if not allowed[result]then fail("TypeError","Invalid "..name)end;return result end
	local function easing(value)
		local result=text(value);local list=Motion.list(result,"timing")
		if not list or #list~=1 then fail("TypeError","Unsupported or invalid easing function")end;return list[1]
	end
	local DEFAULT={delay=0,endDelay=0,fill="auto",iterationStart=0,iterations=1,duration="auto",direction="normal",easing="linear"}
	local FILL={auto=true,none=true,forwards=true,backwards=true,both=true};local DIRECTION={normal=true,reverse=true,alternate=true,["alternate-reverse"]=true}
	local COMPOSITE={replace=true,add=true,accumulate=true};local FRAME_COMPOSITE={auto=true,replace=true,add=true,accumulate=true}
	local function timing(value,base)
		local result=table.clone(base or DEFAULT)
		if type(value)=="number"then if value~=value or value<0 then fail("TypeError","Invalid duration")end;result.duration=value;return result,{duration=true}end
		local d=dict(value)
		local changed={}
		-- Dictionary conversion is observable, and follows Web IDL member order.
		for _,key in {"delay","direction","duration","easing","endDelay","fill","iterationStart","iterations"}do
			local item=field(d,key,U);if item==U then continue end
			changed[key]=true
			if key=="fill"then result[key]=enum(item,FILL,key)
			elseif key=="direction"then result[key]=enum(item,DIRECTION,key)
			elseif key=="easing"then result[key]=easing(item)
			elseif key=="duration"and item=="auto"then result[key]="auto"
			else local n=num(item,key~="duration"and key~="iterations");if(key=="duration"or key=="iterations"or key=="iterationStart")and n<0 then fail("TypeError","Negative "..key)end;result[key]=n end
		end
		return result,changed
	end
	local function duration(t)return if t.duration=="auto"then 0 else t.duration end
	local function activeDuration(t)local d=duration(t);return if d==0 or t.iterations==0 then 0 else d*t.iterations end
	local function endTime(t)return math.max(0,t.delay+activeDuration(t)+t.endDelay)end
	local function compute(t,localTime,rate,endpointInclusive)
		local d,active=duration(t),activeDuration(t);local result=table.clone(t)
		result.duration,result.activeDuration,result.endTime,result.localTime=d,active,endTime(t),localTime or N
		result.progress,result.currentIteration=N,N
		if localTime==nil then result.Phase="idle";return result end
		local before=math.max(0,math.min(t.delay,result.endTime));local after=math.max(0,math.min(t.delay+active,result.endTime))
		local phase=if localTime<before or(localTime==before and rate<0 and not endpointInclusive)then "before"elseif localTime>after or(localTime==after and rate>=0 and not endpointInclusive)then "after"else "active"
		result.Phase=phase;local activeTime
		if phase=="before"then if t.fill=="backwards"or t.fill=="both"then activeTime=math.max(0,localTime-t.delay)end
		elseif phase=="after"then if t.fill=="forwards"or t.fill=="both"then activeTime=math.max(0,math.min(localTime-t.delay,active))end
		else activeTime=math.max(0,localTime-t.delay)end
		if activeTime==nil then return result end
		local overall=if d==0 then t.iterationStart+(if phase=="before"then 0 else t.iterations)else activeTime/d+t.iterationStart
		local simple=if overall==math.huge then t.iterationStart%1 else overall%1
		if simple==0 and phase~="before"and t.iterations~=0 and activeTime==active then simple=1 end
		local iteration=if phase=="after"and t.iterations==math.huge then math.huge elseif simple==1 then math.floor(overall)-1 else math.floor(overall)
		local reverse=t.direction=="reverse"or(t.direction=="alternate"and iteration%2==1)or(t.direction=="alternate-reverse"and iteration%2==0)
		local directed=if reverse then 1-simple else simple
		result.currentIteration,result.progress=iteration,Motion.ease(t.easing,directed,phase=="before")
		return result
	end
	local function iteratorMethod(value)
		if vm.SymbolIterator then local result=vm.Get(value,vm.SymbolIterator);if not nullish(result)then return true,result end end
		return (type(value)=="table"and value.Iterator~=nil and value.Values==nil)or(not vm.SymbolIterator and vm.IsArray(value)),nil
	end
	local function sequenceValues(value,iterator,convert)
		local nextValue,close
		if iterator~=nil then
			local object=vm:Call(iterator,{},value);if not isObject(object)then fail("TypeError","Iterator is not an object")end
			local nextMethod=vm.Get(object,"next");if not VM.callable(nextMethod)then fail("TypeError","Iterator next is not callable")end
			local done=false
			nextValue=function()if done then return false,U end;local result=vm:Call(nextMethod,{},object);if not isObject(result)then fail("TypeError","Iterator result is not an object")end;if VM.truth(vm.Get(result,"done"))then done=true;return false,U end;return true,vm.Get(result,"value")end
			close=function()if done then return end;done=true;local fn=vm.Get(object,"return");if not nullish(fn)then local result=vm:Call(fn,{},object);if not isObject(result)then fail("TypeError","Iterator return is not an object")end end end
		else nextValue,close=vm.Iterator(value)end
		local values={};local ok,failure=pcall(function()
			while true do local more,item=nextValue();if not more then break end;if #values>=1024 then fail("RangeError","Animation keyframe budget exceeded")end;table.insert(values,if convert then convert(item)else item)end
		end);if not ok then if close then pcall(close)end;error(failure,0)end;return values
	end
	local function sequenceOrSingle(value,convert)
		if isObject(value)then local iterable,iterator=iteratorMethod(value);if iterable then return sequenceValues(value,iterator,convert)end end;return {if convert then convert(value)else value}
	end
	local function cssName(key)
		if key=="cssFloat"then return "float"elseif key=="cssOffset"then return "offset"end
		return (key:gsub("%u",function(c)return "-"..c:lower()end))
	end
	local function frameOffset(value)
		if nullish(value)then return nil end;return num(value,true)
	end
	local function processFrames(value)
		local frames={};if nullish(value)then return frames end
		if not isObject(value)then fail("TypeError","Keyframes must be an object")end
		local bytes=0
		local function cssText(item)local result=text(item);bytes+=#result;if bytes>1048576 then fail("RangeError","Animation keyframe string budget exceeded")end;return result end
		local iterable,iterator=iteratorMethod(value);local unusedEasings={}
		if iterable then
			frames=sequenceValues(value,iterator,function(item)
				local d=dict(item);local composite=enum(field(d,"composite","auto"),FRAME_COMPOSITE,"composite");local curve=text(field(d,"easing","linear"));local offset=frameOffset(field(d,"offset",N))
				local frame={Offset=offset,Easing=curve,Composite=composite,Values={},Names={}}
				local keys=if d then vm.OwnKeys(d,true)else {};if #keys>64 then fail("RangeError","Animation property budget exceeded")end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
				for _,key in keys do if type(key)~="string"or key=="offset"or key=="easing"or key=="composite"then continue end
					local property=cssName(key);if property=="display"or property:sub(1,2)=="--"then continue end
					frame.Values[property]=cssText(vm.Get(d,key));frame.Names[property]=key
				end;return frame
			end)
		else
			local d=dict(value);local compositeValues=sequenceOrSingle(field(d,"composite","auto"),function(item)return enum(item,FRAME_COMPOSITE,"composite")end)
			local easingValues=sequenceOrSingle(field(d,"easing","linear"),text)
			local offsets=field(d,"offset",N);local offsetValues=if nullish(offsets)then {}else sequenceOrSingle(offsets,function(item)return frameOffset(item)or N end)
			local byOffset={};local keys=vm.OwnKeys(d,true);if #keys>64 then fail("RangeError","Animation property budget exceeded")end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
			for _,key in keys do if type(key)~="string"or key=="offset"or key=="easing"or key=="composite"then continue end
				local property=cssName(key);if property=="display"or property:sub(1,2)=="--"then continue end
				local raw=vm.Get(d,key);local values=sequenceOrSingle(raw,cssText)
				for index,item in values do local offset=if #values==1 then 1 else (index-1)/(#values-1);local frame=byOffset[offset]
					if not frame then frame={Offset=nil,ComputedOffset=offset,Easing="linear",Composite="auto",Values={},Names={}};byOffset[offset]=frame;table.insert(frames,frame)end
					frame.Values[property]=item;frame.Names[property]=key
				end
			end
			table.sort(frames,function(a,b)return a.ComputedOffset<b.ComputedOffset end)
			for index,frame in frames do
				if #offsetValues>0 then frame.ComputedOffset=nil end
				if offsetValues[index]~=nil then frame.Offset=frameOffset(offsetValues[index])end
				frame.Easing=easingValues[(index-1)%math.max(1,#easingValues)+1]or "linear"
				frame.Composite=enum(compositeValues[(index-1)%math.max(1,#compositeValues)+1]or "auto",FRAME_COMPOSITE,"composite")
			end
			for index=#frames+1,#easingValues do table.insert(unusedEasings,easingValues[index])end
		end
		if #frames>1024 then fail("RangeError","Animation keyframe budget exceeded")end
		local last=0;for _,frame in frames do if frame.Offset~=nil then if frame.Offset<last or frame.Offset>1 then fail("TypeError","Keyframe offsets are not sorted or outside [0, 1]")end;last=frame.Offset end;frame.Easing=easing(frame.Easing)end
		for _,curve in unusedEasings do easing(curve)end
		if #frames==0 then return frames end
		if frames[#frames].Offset==nil and frames[#frames].ComputedOffset==nil then frames[#frames].ComputedOffset=1 end
		if #frames>1 and frames[1].Offset==nil and frames[1].ComputedOffset==nil then frames[1].ComputedOffset=0 end
		for _,frame in frames do if frame.Offset~=nil then frame.ComputedOffset=frame.Offset end end
		local anchor=1
		for index=2,#frames do if frames[index].ComputedOffset~=nil then
			local a,b=frames[anchor].ComputedOffset,frames[index].ComputedOffset
			for middle=anchor+1,index-1 do frames[middle].ComputedOffset=a+(b-a)*(middle-anchor)/(index-anchor)end;anchor=index
		end end
		return if options.NormalizeFrames then options.NormalizeFrames(frames)else frames
	end
	local function capability()local p,resolve,reject=options.CreatePromise();return {Promise=p,Resolve=resolve,Reject=reject,Status="pending"}end
	local function settle(c,status,value)if c.Status~="pending"then return end;c.Status=status;if status=="fulfilled"then c.Resolve({value})else c.Reject({value})end end
	local function now()return options.Now()end
	local function timelineTime(s)return if s.Timeline then now()-timelines[s.Timeline].Origin else nil end
	local function current(s)
		if s.Hold~=nil then return s.Hold end
		local time=timelineTime(s);return if s.Start~=nil and time~=nil then (time-s.Start)*s.Rate else nil
	end
	local function effectiveRate(s)return if s.PendingRate~=nil then s.PendingRate else s.Rate end
	local function applyPendingRate(s)if s.PendingRate~=nil then s.Rate=s.PendingRate;s.PendingRate=nil end end
	local function ended(s,time)
		local rate=effectiveRate(s)
		return time~=nil and not s.Paused and ((rate>0 and time>=endTime(if s.Effect then effects[s.Effect].Timing else DEFAULT))or(rate<0 and time<=0))
	end
	local function playState(s)
		local time=current(s);if time==nil and s.Pending==nil then return "idle"elseif s.Paused then return "paused"elseif ended(s,time)then return "finished"else return "running"end
	end
	local function computedEffect(s)
		local owner=s.Owner and animations[s.Owner];return compute(s.Timing,if owner then current(owner)else nil,if owner then owner.Rate else 1)
	end
	local function capacity(s)
		if retained[s.Value]then return end
		local count=0;for _ in retained do count+=1;if count>=128 then fail("QuotaExceededError","Active script animation budget exceeded")end end
	end
	local update,request,repaint,release,connected
	local ticking=false
	local function styleEvent(s,kind,elapsed)
		if not options.QueueTask or not s.CSSRecord then return end
		local node=s.CSSRecord.Box.Node;local details={Name=s.CSSName,Property=s.CSSProperty,Elapsed=elapsed,Pseudo=''}
		options.QueueTask(function()if api.Alive then api:CSSStyleEvent(node,kind,details)end end)
	end
	local function cssLifecycle(s,result)
		if not s.CSSRecord or s.CSSDetached or s.CSSCanceled then return end
		local phase=result.Phase;local old=s.CSSPhase;local effect=s.Effect and effects[s.Effect];local t=if effect then effect.Timing else s.CSSLifecycleTiming or DEFAULT
		local active=activeDuration(t);local elapsed=math.min(math.max(-t.delay,0),active)/1000
		local intervalEnd=math.min(math.max(endTime(t)-t.delay,0),active)/1000
		if s.CSSKind=='transition'and(old==nil or old=='idle')then styleEvent(s,'transitionrun',elapsed)end
		local prefix=if s.CSSKind=='animation'then'animation'else'transition'
		if phase=='active'or phase=='after'then
			if old==nil or old=='idle'or old=='before'then styleEvent(s,prefix..'start',elapsed)end
			if phase=='active'and old=='after'then styleEvent(s,prefix..'start',intervalEnd)end
		end
		if phase=='active'and old=='active'and s.CSSKind=='animation'and type(result.currentIteration)=='number'and result.currentIteration~=s.CSSIteration then
			local boundary=if type(s.CSSIteration)=='number'and s.CSSIteration>result.currentIteration then result.currentIteration+1 else result.currentIteration
			styleEvent(s,'animationiteration',(boundary-t.iterationStart)*duration(t)/1000)
		end
		if phase=='after'and old~='after'then styleEvent(s,prefix..'end',intervalEnd)end
		if phase=='before'and old=='after'then styleEvent(s,prefix..'start',intervalEnd)end
		if phase=='before'and(old=='active'or old=='after')then styleEvent(s,prefix..'end',elapsed)end
		s.CSSPhase,s.CSSIteration=phase,result.currentIteration
	end
	local function queueCSSLifecycle(s,result)
		if not options.QueueTask or s.Pending or not s.CSSRecord or s.CSSDetached then return end
		local effect=s.Effect and effects[s.Effect];if effect then s.CSSLifecycleTiming=effect.Timing end
		if not s.CSSLifecyclePending and s.CSSPhase==result.Phase and s.CSSIteration==result.currentIteration then return end
		s.CSSLifecycleResult=result
		if s.CSSLifecyclePending then return end;s.CSSLifecyclePending=true
		-- Several seeks or authored updates within one script expose their final
		-- sample. Intermediate phases cannot enqueue spurious CSS events.
		options.QueueTask(function()
			s.CSSLifecyclePending=nil;local sample=s.CSSLifecycleResult;s.CSSLifecycleResult=nil
			if api.Alive and not s.Pending and sample then cssLifecycle(s,sample)end
		end)
	end
	local function event(s,kind,time)
		if not host or not options.QueueTask then return end
		local timeline=timelineTime(s);options.QueueTask(function()
			if not api.Alive then return end
			local value=host:NewEvent(kind,nil,"Event");value.Prototype=playbackProto
			playbackEvents[value]={currentTime=time or N,timelineTime=timeline or N};value.AnimationPlaybackState=playbackEvents[value]
			host:Dispatch(s.Value,value,true)
		end)
	end
	release=function(s)
		if s.CSSPainted and options.ReleaseCSSRecord then options.ReleaseCSSRecord(s.CSSRecord,false);s.CSSPainted=nil end
		if s.PaintedNode and options.Release then options.Release(s.PaintedNode,s.Value)end;s.PaintedNode=nil
	end
	repaint=function(s,retainSample)
		-- Removal changes participation, not playback state or promises. Even a
		-- replayed removed controller stays outside paint until persist().
		if s.ReplaceState=='removed'then release(s);return end
		local effect=s.Effect and effects[s.Effect]
		-- Layout restores native geometry without advancing the animation clock.
		-- Resampling here would keep changing layout values inside the page's
		-- publication loop, even before the next animation frame can run.
		local time
		if retainSample and s.PaintSampleKnown then time=s.PaintSampleTime
		else time=current(s);s.PaintSampleTime=time;s.PaintSampleKnown=true end
		local result=compute(if effect then effect.Timing else DEFAULT,time,s.Rate)
		-- Current transform effects have implicit will-change side effects even
		-- before their active interval, when no filled value can be painted.
		result.IsCurrent=result.Phase=="active"or result.Phase=="before"and s.Rate>0 or result.Phase=="after"and s.Rate<0
		if s.CSSRecord and not s.CSSDetached and(type(result.progress)=='number'or result.IsCurrent)then
			if options.AcquireCSSRecord then options.AcquireCSSRecord(s.CSSRecord)end
			s.CSSCanceled=nil
		end
		queueCSSLifecycle(s,result)
		if not effect or not effect.Target then release(s);return end
		if s.CSSRecord and not s.CSSDetached and effect.Target==s.CSSRecord.Box.Node then
			if options.ApplyCSSRecord then options.ApplyCSSRecord(s.CSSRecord,effect.Frames,result,s.Value,effect.Composite,effect.IterationComposite)end
			s.CSSPainted=true;return
		end
		if result.progress==N and not result.IsCurrent then release(s);return end
		if s.PaintedNode and s.PaintedNode~=effect.Target then release(s)end
  if options.Apply then options.Apply(effect.Target,effect.Frames,result,s.Value,effect.Composite,effect.IterationComposite)end;s.PaintedNode=effect.Target
	end
	local function needsFrame(s)
		if s.Pending~=nil and s.Timeline~=nil then return true end
		local phase=playState(s)
		-- Layout publication may observe the clock crossing the endpoint before
		-- the queued frame runs. Keep that final update to settle finished and
		-- dispatch its lifecycle events; paint alone does not settle promises.
		return s.Start~=nil and s.Rate~=0 and s.Timeline~=nil
			and(phase=="running"or phase=="finished"and s.Finished.Status=="pending")
	end
	local function targeted(effect)
		if effect.ReplacementFrames~=effect.Frames then
			local properties
			if options.TargetedProperties then properties=options.TargetedProperties(effect.Frames)
			else properties={};for _,frame in effect.Frames do for property in frame.Values do properties[property]=true end end end
			effect.ReplacementFrames,effect.ReplacementProperties=effect.Frames,properties
		end;return effect.ReplacementProperties
	end
	local function replacements(remove)
		local values={};local active=false
		for _,s in retained do
			if s.ReplaceState=='removed'or(s.CSSRecord and not s.CSSDetached)or not s.Timeline or playState(s)~='finished'then continue end
			local effect=s.Effect and effects[s.Effect]
			if not effect or not effect.Target or compute(effect.Timing,current(s),s.Rate).progress==N then continue end
			table.insert(values,s);active=active or s.ReplaceState=='active'and connected(effect.Target)
		end
		if not active then return false end
		-- Eligible later effects jointly cover physical channels. Persisted
		-- effects cover earlier ones, and additive effects are eligible too.
		table.sort(values,function(a,b)return a.Sequence>b.Sequence end)
		local coverage,removed={},{}
		for _,s in values do
			local effect=effects[s.Effect];local target=effect.Target;local properties=targeted(effect)
			local covered=coverage[target]or{};coverage[target]=covered
			if s.ReplaceState=='active'and connected(target)then
				local complete=true;for property in properties do if not covered[property]then complete=false;break end end
				if complete then if not remove then return true end;table.insert(removed,s)end
			end
			for property in properties do covered[property]=true end
		end
		-- Decide the whole pass before releasing a surface or queuing an event.
		-- Tasks may persist/commit/cancel the original controller reentrantly.
		table.sort(removed,function(a,b)return a.Sequence<b.Sequence end)
		for _,s in removed do
			s.ReplaceState='removed';release(s);retained[s.Value]=nil;event(s,'remove',current(s))
		end;return #removed>0
	end
	request=function()
		if not api.Alive or ticking or not options.RequestFrame then return end
		local needed=false;for _,s in retained do if needsFrame(s)then needed=true;break end end
		if not needed then needed=replacements(false)end
		if not needed then if framePending and options.CancelFrame then options.CancelFrame(frameId)end;framePending=false;frameId=nil;return end
		if framePending then return end
		framePending=true;frameId=options.RequestFrame(function(timestamp)
			framePending=false;frameId=nil;if api.Alive then api:Tick(timestamp or now())end
		end)
	end
	update=function(s,notify,seek)
		if playState(s)~="idle"then capacity(s)end
		local time=current(s);local isFinished=ended(s,time)
		if isFinished and s.Pending==nil then
			if s.Start~=nil and s.Rate~=0 then s.Hold=if seek then time elseif s.Rate>0 then math.max(s.Hold or 0,endTime(if s.Effect then effects[s.Effect].Timing else DEFAULT))else 0 end
			if s.Finished.Status=="pending"then settle(s.Finished,"fulfilled",s.Value);if notify~=false then event(s,"finish",s.Hold or time)end end
		elseif not isFinished and s.Finished.Status=="fulfilled"then s.Finished=capability()end
		repaint(s)
		if playState(s)=="idle"or(s.ReplaceState=='removed'and not needsFrame(s))then retained[s.Value]=nil else retained[s.Value]=s end;request()
	end
	local function readyPending(s,kind)
		if not s.Pending then s.Ready=capability()end;s.CSSPendingStart=nil;s.Pending=kind;retained[s.Value]=s;request()
	end
	local function play(s,autoRewind)
		local time=current(s);local finish=endTime(if s.Effect then effects[s.Effect].Timing else DEFAULT)
		if not s.Paused and s.PendingRate==nil and(s.Pending=="play"or(s.Pending==nil and s.Start~=nil and s.Hold==nil and not ended(s,time)))then return end
		capacity(s)
		local rate=effectiveRate(s);local seek
		if autoRewind~=false then
			if rate<0 and(time==nil or time<=0 or time>finish)then if finish==math.huge then fail("InvalidStateError","Cannot reverse an infinite animation from its end")end;seek=finish
			elseif rate>=0 and(time==nil or time<0 or time>=finish)then seek=0 end
		end
		if seek~=nil then s.Hold=seek elseif time==nil and s.Start==nil then s.Hold=0 end
		if s.Hold~=nil then s.Start=nil end
		s.Paused=false;readyPending(s,"play");update(s)
	end
	local function pause(s)
		if s.Paused and s.Pending~="play"then return end
		capacity(s)
		local time=current(s);if time==nil then
			if s.Rate>=0 then time=0 else time=endTime(if s.Effect then effects[s.Effect].Timing else DEFAULT);if time==math.huge then fail("InvalidStateError","Cannot pause a reversed infinite animation")end end
			s.Hold=time
		end;s.Paused=true;readyPending(s,"pause");update(s)
	end
	local function setEffect(s,value)
		if nullish(value)then value=nil elseif not effects[value]then fail("TypeError","Expected a KeyframeEffect")end
		if s.Effect==value then return end;s.CSSPendingStart=nil;release(s)
		if s.CSSRecord and value~=s.CSSOriginalEffect then s.CSSIgnoreEffectStyle=true end
		if s.Effect then effects[s.Effect].Owner=nil end
		if value and effects[value].Owner then local previous=animations[effects[value].Owner];release(previous);previous.Effect=nil;update(previous)end
		s.Effect=value;if value then effects[value].Owner=s.Value end;update(s)
	end
	local function newAnimation(effect,timeline)
		if not nullish(effect)and not effects[effect]then fail("TypeError","Expected a KeyframeEffect")end
		if not nullish(timeline)and not timelines[timeline]then fail("TypeError","Expected a DocumentTimeline")end
		sequence+=1;if sequence>100000 then fail("RangeError","Animation creation budget exceeded")end
		local value=vm.Object({},animationProto);local s={Value=value,Sequence=sequence,Effect=nil,Timeline=if nullish(timeline)then nil else timeline,Rate=1,Paused=false,Id="",ReplaceState="active",Ready=capability(),Finished=capability()}
		value.AnimationState=s;animations[value]=s;ordered[sequence]=value
		if host then host:WrapTarget(value,{Parent=function()return nil end,Standalone=true,Handlers=true,HandlerNames={onfinish=true,oncancel=true,onremove=true}})end
		settle(s.Ready,"fulfilled",value);setEffect(s,effect);return value
	end
	local function newEffect(target,keyframes,opts,animate)
		local source=effects[target];if source and keyframes==U and opts==U then
			local value=vm.Object({},effectProto);local s={Target=source.Target,Frames={},Timing=table.clone(source.Timing),Composite=source.Composite,IterationComposite=source.IterationComposite}
			for _,frame in source.Frames do local f=table.clone(frame);f.Values=table.clone(frame.Values);f.Names=table.clone(frame.Names);table.insert(s.Frames,f)end
			value.KeyframeState=s;effects[value]=s;return value
		end
		local node=if nullish(target)then nil else options.Unwrap(target);if node and node.Kind~="Element"then fail("TypeError","Keyframe target must be an Element")end
		local t=timing(opts);local d=if type(opts)=="number"then nil else dict(opts)
		local composite=enum(field(d,"composite","replace"),COMPOSITE,"composite");local pseudo=field(d,"pseudoElement",N)
  local iterationComposite=enum(field(d,'iterationComposite','replace'),{replace=true,accumulate=true},'iterationComposite')
		if not nullish(pseudo)then text(pseudo);fail("NotSupportedError","Pseudo-element animation targets are not supported")end
		local animateOptions=if animate then {Id=text(field(d,"id","")),Timeline=field(d,"timeline",api.Timeline)}else nil
		if animateOptions and not nullish(animateOptions.Timeline)and not timelines[animateOptions.Timeline]then fail("TypeError","Expected a DocumentTimeline")end
		local frames=processFrames(keyframes);if options.Validate then local supported,message=options.Validate(node,frames,composite);if supported==false then fail("NotSupportedError",message or "Animation paint is unsupported")end end
		local value=vm.Object({},effectProto);local s={Target=node,Frames=frames,Timing=t,Composite=composite,IterationComposite=iterationComposite};value.KeyframeState=s;effects[value]=s;return value,animateOptions
	end
	local function constructor(name,length,proto,create)
		local value=native(name,length,function()fail("TypeError",name.." requires new")end);value.Construct=function(args)check();return create(args)end
		define(value,"prototype",{value=proto});define(proto,"constructor",{value=value,writable=true,configurable=true});globals[name]=value
		if vm.Global then vm.Global.Bindings[name]={Value=value}end;return value
	end
	local function newTimeline(value)
		local origin=num(field(dict(value),"originTime",0),true);local wrapper=vm.Object({},timelineProto);local s={Origin=origin};wrapper.TimelineState=s;timelines[wrapper]=s;return wrapper
	end
	api.Timeline=newTimeline(nil)
	constructor("DocumentTimeline",0,timelineProto,function(args)return newTimeline(arg(args,1))end)
	constructor("Animation",0,animationProto,function(args)return newAnimation(arg(args,1),if arg(args,2)==U then api.Timeline else args[2])end)
	constructor('CSSAnimation',0,cssAnimationProto,function()fail('TypeError','Illegal constructor')end)
	constructor('CSSTransition',0,cssTransitionProto,function()fail('TypeError','Illegal constructor')end)
	accessor(cssAnimationProto,'animationName',function(value)local s=state(animations,value,'CSSAnimation');if s.CSSKind~='animation'then fail('TypeError','Illegal CSSAnimation receiver')end;return s.CSSName end)
	accessor(cssTransitionProto,'transitionProperty',function(value)local s=state(animations,value,'CSSTransition');if s.CSSKind~='transition'then fail('TypeError','Illegal CSSTransition receiver')end;return s.CSSProperty end)
	constructor("KeyframeEffect",1,effectProto,function(args)if #args<1 or(#args<2 and not effects[args[1]])then fail("TypeError","KeyframeEffect requires a target and keyframes")end;return newEffect(arg(args,1),arg(args,2),arg(args,3))end)
	if host then constructor("AnimationPlaybackEvent",1,playbackProto,function(args)
		if #args<1 then fail("TypeError","AnimationPlaybackEvent requires a type")end;local d=dict(arg(args,2));local value=host:NewEvent(arg(args,1),d,"Event");value.Prototype=playbackProto
		local s={};for _,key in {"currentTime","timelineTime"}do local raw=field(d,key,N);s[key]=if nullish(raw)then N else num(raw,true)end;value.AnimationPlaybackState=s;playbackEvents[value]=s;return value
	end)end
	for _,key in {"currentTime","timelineTime"}do accessor(playbackProto,key,function(value)return state(playbackEvents,value,"AnimationPlaybackEvent")[key]end)end
	local styleEventPrototypes={}
	if host then for _,name in {'AnimationEvent','TransitionEvent'}do
		local proto=vm.Object({},eventProto);styleEventPrototypes[name]=proto
		local property=if name=='AnimationEvent'then'animationName'else'propertyName'
		constructor(name,1,proto,function(args)
			if #args<1 then fail('TypeError',name..' requires a type')end
			local typeName=text(arg(args,1));local init=dict(arg(args,2))
			local eventInit={}
			for _,key in {'bubbles','cancelable','composed'}do eventInit[key]=VM.truth(field(init,key,false))end
			-- EventInit conversion precedes derived dictionary members; both are
			-- observable getters, and elapsedTime uses finite Web IDL double.
			local data={Kind=name}
			data[property]=text(field(init,property,''));data.elapsedTime=num(field(init,'elapsedTime',0),true);data.pseudoElement=text(field(init,'pseudoElement',''))
			local value=host:NewEvent(typeName,eventInit,'Event');value.Prototype=proto
			styleEvents[value]=data;return value
		end)
		for _,key in {property,'elapsedTime','pseudoElement'}do accessor(proto,key,function(value)
			local data=styleEvents[value];if not data or data.Kind~=name then fail('TypeError','Illegal '..name..' receiver')end;return data[key]
		end)end
	end end
	function api:CSSStyleEvent(node,kind,details)
		if not api.Alive or not host then return end
		local class=if kind:sub(1,9)=='animation'then'AnimationEvent'else'TransitionEvent'
		local proto=styleEventPrototypes[class];if not proto then return end
		local value=host:NewEvent(kind,{bubbles=true,cancelable=details.Cancelable==true},'Event');value.Prototype=proto
		styleEvents[value]={Kind=class,animationName=details.Name,propertyName=details.Property,elapsedTime=details.Elapsed or 0,pseudoElement=details.Pseudo or''}
		host:Dispatch(if options.TargetFor then options.TargetFor(node)else options.Wrap(node),value,true)
	end
	accessor(timelineProto,"currentTime",function(value)return now()-state(timelines,value,"DocumentTimeline").Origin end)
	accessor(animationProto,"currentTime",function(value)return current(state(animations,value,"Animation"))or N end,function(value,raw)
		local s=state(animations,value,"Animation");if nullish(raw)then if current(s)~=nil then fail("TypeError","A resolved currentTime cannot be made unresolved")end;return end
		local time=num(raw,true);capacity(s);s.CSSPendingStart=nil;local timeline=timelineTime(s)
		if s.Start==nil or s.Rate==0 or s.Paused or timeline==nil then s.Hold=time else s.Start=timeline-time/s.Rate;s.Hold=nil end
		if s.Pending=="pause"then s.Start=nil;applyPendingRate(s);s.Pending=nil;settle(s.Ready,"fulfilled",value)end;update(s,true,true)
	end)
	accessor(animationProto,"startTime",function(value)return state(animations,value,"Animation").Start or N end,function(value,raw)
		local s=state(animations,value,"Animation");local time=if nullish(raw)then nil else num(raw,true);local previous=current(s)
		local paused=s.Paused;s.CSSPendingStart=nil
		if time~=nil then capacity(s)end
		applyPendingRate(s);s.Start=time;s.Paused=false;s.Hold=if time==nil or s.Rate==0 then previous else nil
		if s.Pending then s.Pending=nil;settle(s.Ready,"fulfilled",value)end;if s.CSSRecord and paused~=s.Paused then s.CSSPlayOverride=true end;update(s)
	end)
	accessor(animationProto,"playbackRate",function(value)return state(animations,value,"Animation").Rate end,function(value,raw)
		local s=state(animations,value,"Animation");local rate=num(raw,true);local time=current(s);s.CSSPendingStart=nil;s.PendingRate=nil;s.Rate=rate
		if time~=nil then if s.Rate==0 or s.Start==nil or s.Paused or not s.Timeline then s.Hold=time else s.Start=timelineTime(s)-time/s.Rate;s.Hold=nil end end;update(s,true,true)
	end)
	accessor(animationProto,"effect",function(value)return state(animations,value,"Animation").Effect or N end,function(value,raw)setEffect(state(animations,value,"Animation"),raw)end)
	accessor(animationProto,"timeline",function(value)return state(animations,value,"Animation").Timeline or N end,function(value,raw)
		local s=state(animations,value,"Animation");if nullish(raw)then raw=nil elseif not timelines[raw]then fail("TypeError","Expected a DocumentTimeline")end
		local time=current(s);s.CSSPendingStart=nil;s.Timeline=raw;if s.Paused or s.Start==nil then s.Hold=time end;update(s)
	end)
	accessor(animationProto,"id",function(value)return state(animations,value,"Animation").Id end,function(value,raw)state(animations,value,"Animation").Id=text(raw)end)
	accessor(animationProto,"playState",function(value)return playState(state(animations,value,"Animation"))end)
	accessor(animationProto,"pending",function(value)return state(animations,value,"Animation").Pending~=nil end)
	accessor(animationProto,"ready",function(value)return state(animations,value,"Animation").Ready.Promise end)
	accessor(animationProto,"finished",function(value)return state(animations,value,"Animation").Finished.Promise end)
	accessor(animationProto,"replaceState",function(value)return state(animations,value,"Animation").ReplaceState end)
	method(animationProto,"play",0,function(_,value)local s=state(animations,value,'Animation');play(s);if s.CSSRecord then s.CSSPlayOverride=true end;return U end)
	method(animationProto,"pause",0,function(_,value)local s=state(animations,value,'Animation');pause(s);if s.CSSRecord then s.CSSPlayOverride=true end;return U end)
	local function cancel(s)
		local value=s.Value;local active=playState(s)~="idle";local reason=if host then host:DOMException("Animation canceled","AbortError")else VM.error("AbortError","Animation canceled")
		if s.CSSRecord and options.MarkPromiseHandled then
			if s.Pending then options.MarkPromiseHandled(s.Ready.Promise)end
			if active then options.MarkPromiseHandled(s.Finished.Promise)end
		end
		if active and s.CSSRecord and not s.CSSDetached and s.CSSPhase~=nil and s.CSSPhase~='after'and s.CSSPhase~='idle'then
			local t=effects[s.Effect]and effects[s.Effect].Timing or DEFAULT
			styleEvent(s,if s.CSSKind=='animation'then'animationcancel'else'transitioncancel',math.min(math.max((current(s)or 0)-t.delay,0),activeDuration(t))/1000)
		end
		if s.Pending then applyPendingRate(s);settle(s.Ready,"rejected",reason);s.Ready=capability();settle(s.Ready,"fulfilled",value)end
		if active then settle(s.Finished,"rejected",reason);s.Finished=capability();event(s,"cancel",nil)end
		s.Hold,s.Start,s.Pending,s.Paused=nil,nil,nil,false;s.CSSPendingStart=nil;s.PaintSampleKnown=false;s.PaintSampleTime=nil;release(s)
		if s.CSSRecord and options.ReleaseCSSRecord then options.ReleaseCSSRecord(s.CSSRecord,true);s.CSSPainted=nil;s.CSSCanceled=true;s.CSSPhase='idle'end
		retained[value]=nil;request()
	end
	method(animationProto,"cancel",0,function(_,value)cancel(state(animations,value,'Animation'));return U end)
	method(animationProto,"finish",0,function(_,value)
		local s=state(animations,value,"Animation");local finish=endTime(if s.Effect then effects[s.Effect].Timing else DEFAULT)
		local rate=effectiveRate(s);if rate==0 or(rate>0 and finish==math.huge)then fail("InvalidStateError","Animation cannot finish with this playback rate or duration")end
		applyPendingRate(s);s.CSSPendingStart=nil
		s.Hold,s.Paused=if s.Rate>0 then finish else 0,false
		if s.Start==nil and s.Timeline and s.Rate~=0 then s.Start=timelineTime(s)-s.Hold/s.Rate end
		if s.Pending then s.Pending=nil;settle(s.Ready,"fulfilled",value)end;update(s);return U
	end)
	method(animationProto,"reverse",0,function(_,value)
		local s=state(animations,value,"Animation");if not s.Timeline then fail("InvalidStateError","Animation has no active timeline")end
		local previous=s.PendingRate;s.PendingRate=-effectiveRate(s)
		local paused=s.Paused;local ok,failure=pcall(play,s);if not ok then s.PendingRate=previous;error(failure,0)end;if s.CSSRecord and paused~=s.Paused then s.CSSPlayOverride=true end;return U
	end)
	method(animationProto,"updatePlaybackRate",1,function(args,value)
		local s=state(animations,value,"Animation");local rate=num(arg(args,1),true);local previous=playState(s);local time=current(s);s.CSSPendingStart=nil;s.PendingRate=rate
		if s.Pending then return U end
		if previous=="idle"or previous=="paused"or time==nil then applyPendingRate(s);update(s)
		elseif previous=="finished"then
			local timeline=timelineTime(s);local unconstrained=if timeline~=nil and s.Start~=nil then(timeline-s.Start)*s.Rate else time
			if timeline~=nil then s.Start=if rate==0 then timeline else timeline-unconstrained/rate end
			applyPendingRate(s);if rate~=0 then s.Hold=nil else s.Hold=time end;update(s)
		else play(s,false)end;return U
	end)
	method(animationProto,"persist",0,function(_,value)
		local s=state(animations,value,'Animation');if playState(s)~='idle'then capacity(s)end
		s.ReplaceState='persisted';update(s);return U
	end)
	method(animationProto,"commitStyles",0,function(_,value)
		local s=state(animations,value,"Animation");local effect=s.Effect and effects[s.Effect]
		-- A commit requires a styled target. It does not play, pause, finish or
		-- cancel an animation, including when the target has no active keyframes.
		if not effect or not effect.Target then fail("NoModificationAllowedError","Animation is not associated with a styled element")end
		local namespace=effect.Target.NamespaceURI
		if namespace~=nil and namespace~="http://www.w3.org/1999/xhtml"and namespace~="http://www.w3.org/2000/svg"and namespace~="http://www.w3.org/1998/Math/MathML"then fail("NoModificationAllowedError","Animation target cannot have a style attribute")end
		if not options.SampleCommit or not options.WriteCommittedStyle then fail("NotSupportedError","Committing styles requires a mounted animation paint adapter")end
		if options.PrepareCommit then options.PrepareCommit()end
		local properties={};for _,frame in effect.Frames do for property in frame.Values do properties[property]=true end end
		local candidates={};for _,other in retained do table.insert(candidates,other)end
		if not retained[value]then table.insert(candidates,s)end
		local stack={};for _,other in candidates do
			if other.Sequence>s.Sequence then continue end
			if other~=s and other.CSSRecord and not other.CSSDetached then continue end
			if s.CSSRecord and not s.CSSDetached and other~=s then continue end
			local e=other.Effect and effects[other.Effect]
			if not e or e.Target~=effect.Target or (other.ReplaceState=="removed"and other~=s)then continue end
			local sampled=compute(e.Timing,current(other),other.Rate,true)
   if sampled.progress~=N then table.insert(stack,{Frames=e.Frames,Timing=sampled,Animation=other.Value,Composite=e.Composite,IterationComposite=e.IterationComposite,Sequence=other.Sequence})end
		end
		table.sort(stack,function(a,b)return a.Sequence<b.Sequence end)
		local declarations,errorName,message=options.SampleCommit(effect.Target,stack,{Properties=properties,Frames=effect.Frames,BeforeRecord=if s.CSSRecord and not s.CSSDetached then s.CSSRecord else nil})
		if not declarations then fail(errorName or "NotSupportedError",message or "Animation styles cannot be committed")end
		options.WriteCommittedStyle(effect.Target,declarations);return U
	end)
	accessor(effectProto,"target",function(value)local target=state(effects,value,"KeyframeEffect").Target;return if target then options.Wrap(target)else N end,function(value,raw)
		local s=state(effects,value,"KeyframeEffect");local node=if nullish(raw)then nil else options.Unwrap(raw);if node and node.Kind~="Element"then fail("TypeError","Expected an Element")end
		if options.Validate then local supported,message=options.Validate(node,s.Frames,s.Composite);if supported==false then fail("NotSupportedError",message or "Animation paint is unsupported")end end;if s.Owner and animations[s.Owner].CSSRecord then release(animations[s.Owner])end;s.Target=node;if s.Owner then update(animations[s.Owner])end
	end)
	accessor(effectProto,"composite",function(value)return state(effects,value,"KeyframeEffect").Composite end,function(value,raw)
		local s=state(effects,value,"KeyframeEffect");local result=enum(raw,COMPOSITE,"composite");if options.Validate then local supported,message=options.Validate(s.Target,s.Frames,result);if supported==false then fail("NotSupportedError",message or "Animation paint is unsupported")end end;s.Composite=result;s.CSSCompositeOverride=true;if s.Owner then update(animations[s.Owner])end
	end)
	accessor(effectProto,"iterationComposite",function(value)return state(effects,value,"KeyframeEffect").IterationComposite end,function(value,raw)
  local s=state(effects,value,"KeyframeEffect");local result=enum(raw,{replace=true,accumulate=true},"iterationComposite");s.IterationComposite=result;if s.Owner then update(animations[s.Owner])end
	end)
	accessor(effectProto,"pseudoElement",function(value)state(effects,value,"KeyframeEffect");return N end,function(value,raw)state(effects,value,"KeyframeEffect");if not nullish(raw)then text(raw);fail("NotSupportedError","Pseudo-element animation targets are not supported")end end)
	method(effectProto,"getTiming",0,function(_,value)return vm.Object(table.clone(state(effects,value,"KeyframeEffect").Timing))end)
	method(effectProto,"getComputedTiming",0,function(_,value)local result=computedEffect(state(effects,value,"KeyframeEffect"));result.Phase=nil;return vm.Object(result)end)
	method(effectProto,"updateTiming",0,function(args,value)local s=state(effects,value,"KeyframeEffect");local result,changed=timing(arg(args,1),s.Timing);s.Timing=result;if s.Owner then local owner=animations[s.Owner];if owner.CSSRecord then s.CSSOverrides=s.CSSOverrides or{};for key in changed do s.CSSOverrides[key]=true end end;update(owner)end;return U end)
	method(effectProto,"setKeyframes",1,function(args,value)local s=state(effects,value,"KeyframeEffect");local result=processFrames(arg(args,1));if options.Validate then local supported,message=options.Validate(s.Target,result,s.Composite);if supported==false then fail("NotSupportedError",message or "Animation paint is unsupported")end end;s.Frames=result;s.CSSFramesOverride=true;if s.Owner then update(animations[s.Owner])end;return U end)
	method(effectProto,"getKeyframes",0,function(_,value)
		local result={};for _,frame in state(effects,value,"KeyframeEffect").Frames do local values={offset=frame.Offset or N,computedOffset=frame.ComputedOffset,easing=frame.Easing,composite=frame.Composite};for key,item in frame.Values do values[frame.Names[key]or key]=item end;table.insert(result,vm.Object(values))end;return vm.Array(result)
	end)
	local function contains(root,node)
		-- getAnimations({subtree:true}) follows DOM descendants. Connected
		-- shadow targets can animate, but belong to their own tree scope.
		while node do if node==root then return true end;node=node.Parent end;return false
	end
	connected=function(node,lightTree)
		local document=if options.Unwrap and options.Document then options.Unwrap(options.Document)else nil
		-- Replacement eligibility includes shadow hosts; document queries keep
		-- their own light-tree scope, like Element subtree queries above.
		local root=ShadowTree.Root(node,not lightTree)
		return root~=nil and root.Kind=="Document"and(document==nil or root==document)
	end
	syncCSSRecords=function()
		if syncingCSS or not api.Alive or not options.GetCSSRecords then return end
		syncingCSS=true
		local ok,failure=pcall(function()
			local seen={}
			for _,source in options.GetCSSRecords()do
				local record=source.Record;seen[record]=true;local s=cssRecords[record]or ownedControllers[record]
				if not s then
					local effect=vm.Object({},effectProto);local e={Target=source.Target,Frames=source.Frames,Timing=table.clone(source.Timing),Composite=source.Composite or'replace',IterationComposite='replace'}
					effect.KeyframeState=e;effects[effect]=e
					local value=newAnimation(effect,api.Timeline);s=animations[value];cssRecords[record]=s
					value.Prototype=if source.Kind=='animation'then cssAnimationProto else cssTransitionProto
					s.CSSRecord,s.CSSKind,s.CSSName,s.CSSProperty=record,source.Kind,source.Name,source.Property;s.CSSOriginalEffect=effect
					s.CSSIndex=source.Index;s.CSSPlay=source.Play;s.Hold=source.CurrentTime or 0;s.Paused=source.Play=='paused'
					if source.Canceled then s.Hold=nil;s.Paused=false;s.CSSCanceled=true;s.CSSPhase='idle'
					else if options.AcquireCSSRecord then options.AcquireCSSRecord(record)end;if not s.Paused then
						readyPending(s,'play')
						-- Ownership takes over an already running authored clock. Its
						-- first pending frame must not restart that source at zero.
						s.CSSPendingStart=timelineTime(s)-(source.CurrentTime or 0)
					end end
					update(s)
				elseif not s.CSSDetached then
					s.CSSIndex=source.Index
					local e=s.Effect and effects[s.Effect]
					if e and s.Effect==s.CSSOriginalEffect and not s.CSSIgnoreEffectStyle then
						for key,value in source.Timing do if not(e.CSSOverrides and e.CSSOverrides[key])then e.Timing[key]=value end end
						if not e.CSSFramesOverride then e.Frames=source.Frames end
						if not e.CSSCompositeOverride then e.Composite=source.Composite or'replace'end
					end
					if source.Play~=s.CSSPlay and not s.CSSPlayOverride then if source.Play=='paused'then pause(s)else play(s,false)end end
					s.CSSPlay=source.Play;repaint(s,true)
				end
				ownedControllers[record]=s
			end
			for record,s in ownedControllers do if not seen[record]then
				if not s.CSSDetached then if record.Completed then s.CSSDetached=true;release(s)else cancel(s);s.CSSDetached=true end end
				ownedControllers[record]=nil
			end end
		end)
		syncingCSS=false;if not ok then error(failure,0)end
	end
	local function compositeBefore(a,b)
		local ac=if a.CSSRecord and not a.CSSDetached then(if a.CSSKind=='transition'then 0 else 1)else 2
		local bc=if b.CSSRecord and not b.CSSDetached then(if b.CSSKind=='transition'then 0 else 1)else 2
		if ac~=bc then return ac<bc end
		if ac<2 then
			local an,bn=a.CSSRecord.Box.Node,b.CSSRecord.Box.Node
			if an==bn then if ac==0 then return a.CSSProperty<b.CSSProperty else return a.CSSIndex<b.CSSIndex end end
			local function path(node)local result={};while node and node.Parent do table.insert(result,1,table.find(node.Parent.Children,node)or 0);node=node.Parent end;return result end
			local ap,bp=path(an),path(bn);for i=1,math.min(#ap,#bp)do if ap[i]~=bp[i]then return ap[i]<bp[i]end end
			if #ap~=#bp then return #ap<#bp end
		end
		return a.Sequence<b.Sequence
	end
	local function getAnimations(node,opts,document)
		if options.PrepareCommit then options.PrepareCommit()end;if syncCSSRecords then syncCSSRecords()end
		local subtree=VM.truth(field(dict(opts),"subtree",false));local result={}
		local sorted={};for _,s in retained do table.insert(sorted,s)end;table.sort(sorted,compositeBefore)
		for _,s in sorted do local value=s.Value;local effect=s.Effect and effects[s.Effect]
			if effect and effect.Target and s.ReplaceState~='removed'and playState(s)~="idle"then local resultTiming=compute(effect.Timing,current(s),s.Rate)
				local relevant=resultTiming.progress~=N or(playState(s)=="running"and resultTiming.Phase=="before")
				if relevant and ((document and connected(effect.Target,true))or(not document and(effect.Target==node or(subtree and contains(node,effect.Target)))))then table.insert(result,value)end
			end
		end;return vm.Array(result)
	end
	local elementMethods=setmetatable({},{__mode="k"})
	function api:ElementMethod(node,key)
		if node.Kind~="Element"or(key~="animate"and key~="getAnimations")then return nil end
		local methods=elementMethods[node];if not methods then methods={};elementMethods[node]=methods end
		if not methods[key]then methods[key]=native(key,if key=="animate"then 1 else 0,function(args,receiver)
			if options.Unwrap(receiver)~=node then fail("TypeError","Illegal Element receiver")end
			if key=="getAnimations"then return getAnimations(node,arg(args,1),false)end
			if #args<1 then fail("TypeError","animate requires keyframes")end
			local effect,init=newEffect(receiver,args[1],arg(args,2),true)
			local value=newAnimation(effect,init.Timeline);animations[value].Id=init.Id;play(animations[value]);return value
		end)end;return methods[key]
	end
	local documentMethod=native("getAnimations",0,function(_,receiver)if options.Document and receiver~=options.Document then fail("TypeError","Illegal Document receiver")end;return getAnimations(nil,U,true)end)
	function api:DocumentMethod(key)return if key=="getAnimations"then documentMethod else nil end
	function api:DocumentGet(key)return if key=="timeline"then api.Timeline else nil end
	function api:Tick(timestamp)
		check();local limit=0
		ticking=true
		local ok,failure=pcall(function()
		-- Snapshot retained values so callbacks cannot alter iteration ordering.
		local values={};for _,s in retained do table.insert(values,s)end;table.sort(values,function(a,b)return a.Sequence<b.Sequence end)
		for _,s in values do limit+=1;if limit>1024 then fail("RangeError","Active animation budget exceeded")end
			if s.Pending and s.Timeline then
				local pending=s.Pending;s.Pending=nil;local time=if s.Timeline then timestamp-timelines[s.Timeline].Origin else nil
				local match=if s.Hold~=nil then s.Hold elseif time~=nil and s.Start~=nil then(time-s.Start)*s.Rate else 0
				applyPendingRate(s)
				if pending=="play"and time~=nil then s.Start=if s.CSSPendingStart~=nil and s.Rate==1 then s.CSSPendingStart elseif s.Rate==0 then time else time-match/s.Rate;s.Hold=if s.Rate==0 then match else nil
				elseif pending=="pause"then s.Hold=match;s.Start=nil end
				s.CSSPendingStart=nil
				settle(s.Ready,"fulfilled",s.Value)
			end;update(s)
		end;replacements(true)
		end)
		ticking=false;if not ok then error(failure,0)end;request()
	end
	function api:AfterLayout()if not api.Alive then return end;if syncCSSRecords then syncCSSRecords()end;for _,s in retained do repaint(s,true)end;request()end
	function api:Destroy()
		if not api.Alive then return end;api.Alive=false
		if cssStop then cssStop();cssStop=nil end
		if framePending and options.CancelFrame then options.CancelFrame(frameId)end;framePending=false;frameId=nil
		for _,s in retained do release(s)end
		for _,s in animations do s.CSSRecord=nil;s.CSSOriginalEffect=nil;s.CSSLifecycleTiming=nil;s.CSSLifecycleResult=nil end
		for _,map in {retained,effects,animations,timelines,playbackEvents,ordered,elementMethods,cssRecords,ownedControllers}do table.clear(map)end
	end
	if options.SubscribeCSSRecords then cssStop=options.SubscribeCSSRecords(syncCSSRecords)end
	if options.GetCSSRecords then syncCSSRecords()end
	for _,pair in {{animationProto,"Animation"},{cssAnimationProto,'CSSAnimation'},{cssTransitionProto,'CSSTransition'},{effectProto,"KeyframeEffect"},{timelineProto,"DocumentTimeline"},{playbackProto,"AnimationPlaybackEvent"},{styleEventPrototypes.AnimationEvent,'AnimationEvent'},{styleEventPrototypes.TransitionEvent,'TransitionEvent'}}do if pair[1]and vm.SymbolToStringTag then define(pair[1],vm.SymbolToStringTag,{value=pair[2],configurable=true})end end
	return api
end
return WebAnimations
