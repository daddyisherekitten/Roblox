--!strict
-- DOM event/abort algorithms without a render connection or native Instances.
-- DOM callers supply stable target wrappers and their parent relationship.
local HostEvents={}
local sharedEvents=setmetatable({},{__mode='kv'})
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local CODES={IndexSizeError=1,HierarchyRequestError=3,WrongDocumentError=4,InvalidCharacterError=5,
	NoModificationAllowedError=7,NotFoundError=8,NotSupportedError=9,InUseAttributeError=10,
	InvalidStateError=11,SyntaxError=12,InvalidModificationError=13,NamespaceError=14,InvalidAccessError=15,
	TypeMismatchError=17,SecurityError=18,NetworkError=19,AbortError=20,URLMismatchError=21,
	QuotaExceededError=22,TimeoutError=23,InvalidNodeTypeError=24,DataCloneError=25}
local CONSTANTS={INDEX_SIZE_ERR=1,DOMSTRING_SIZE_ERR=2,HIERARCHY_REQUEST_ERR=3,WRONG_DOCUMENT_ERR=4,INVALID_CHARACTER_ERR=5,
	NO_DATA_ALLOWED_ERR=6,NO_MODIFICATION_ALLOWED_ERR=7,NOT_FOUND_ERR=8,NOT_SUPPORTED_ERR=9,INUSE_ATTRIBUTE_ERR=10,
	INVALID_STATE_ERR=11,SYNTAX_ERR=12,INVALID_MODIFICATION_ERR=13,NAMESPACE_ERR=14,INVALID_ACCESS_ERR=15,
	VALIDATION_ERR=16,TYPE_MISMATCH_ERR=17,SECURITY_ERR=18,NETWORK_ERR=19,ABORT_ERR=20,URL_MISMATCH_ERR=21,
	QUOTA_EXCEEDED_ERR=22,TIMEOUT_ERR=23,INVALID_NODE_TYPE_ERR=24,DATA_CLONE_ERR=25}

function HostEvents.install(vm: any,globals: any,options: any?): any
	options=table.clone(options or {})
	local VM=assert(vm.Model,"HostEvents requires vm.Model")
	local U,N=VM.Undefined,VM.Null
	local host={Alive=true}
	-- Web IDL operation functions use their defining realm's global object for
	-- null/undefined this. Capture it before author code can replace an alias.
	local operationGlobal=globals.globalThis or globals.window or globals.self
	local targets,events,signals,controllers,exceptions={},{},{},{},{}
	setmetatable(targets,{__mode="kv"});setmetatable(events,{__mode="kv"})
	setmetatable(signals,{__mode="kv"});setmetatable(controllers,{__mode="kv"});setmetatable(exceptions,{__mode="kv"})
	local timers={}
	local handlerPrototypes=setmetatable({},{__mode="k"})
	local handlerNames={};for name in ("abort auxclick beforeinput beforematch beforetoggle blur cancel canplay canplaythrough change click close contextlost contextmenu contextrestored copy cuechange cut dblclick drag dragend dragenter dragleave dragover dragstart drop durationchange emptied ended error focus focusin focusout formdata gotpointercapture input invalid keydown keypress keyup load loadeddata loadedmetadata loadstart lostpointercapture mousedown mouseenter mouseleave mousemove mouseout mouseover mouseup paste pause play playing pointercancel pointerdown pointerenter pointerleave pointermove pointerout pointerover pointerrawupdate pointerup progress ratechange reset resize scroll scrollend securitypolicyviolation seeked seeking select selectionchange selectstart slotchange stalled submit suspend timeupdate toggle touchcancel touchend touchmove touchstart transitioncancel transitionend transitionrun transitionstart animationcancel animationend animationiteration animationstart volumechange waiting wheel unhandledrejection rejectionhandled message messageerror hashchange popstate readystatechange DOMContentLoaded"):gmatch("%S+")do handlerNames["on"..name]=true end
	local targetMethods,eventMethods,signalMethods,controllerMethods={},{},{},{}
	local uiTypes={}
	local targetPrototype,eventPrototype,customPrototype,rejectionPrototype,exceptionPrototype,signalPrototype,controllerPrototype
	local newEvent,dispatch,subscribe,abort,updateDependentRetention,handlerGet
	local function check()assert(host.Alive and vm.Alive,"JavaScript host events disposed")end
	local function typeError(message)VM.throw(VM.error("TypeError",message))end
	local function arg(args,index)return if args[index]==nil then U else args[index]end
	local function object(value)return type(value)=="function" or(type(value)=="table" and value~=U and value~=N and value.Kind~="symbol" and value.Kind~="bigint")end
	local function field(value,key)
		if value==nil or value==U or value==N then return U end
		if not object(value)then typeError("Expected an options dictionary")end
		return vm.Get(value,key)
	end
	local function required(args,count,name)if #args<count then typeError(name.." requires "..count.." arguments")end end
	local function report(message)if host.Alive and options.Report then options.Report(VM.exceptionValue(message))end end
	local function define(target,key,descriptor)return vm.DefineProperty(target,key,vm.Object(descriptor,VM.Null))end
	local function native(name,length,fn)
		local value={Kind="native-function",Call=function(args,receiver)check();return fn(args,receiver)end,Values={},Prototype=vm.Prototypes.Function}
		define(value,"length",{value=length,configurable=true});define(value,"name",{value=name,configurable=true})
		return value
	end
	local function wrapper(prototype,state)
		local value=vm.Object({},prototype)
		-- The wrapper owns its state; registries do not root detached objects.
		value.HostState=state
		return value
	end
	local function accessor(prototype,name,read,write,configurable)
		define(prototype,name,{get=native("get "..name,0,function(_,receiver)return read(receiver)end),
			set=if write then native("set "..name,1,function(args,receiver)write(receiver,arg(args,1));return U end)else U,
			enumerable=true,configurable=configurable~=false})
	end
	local function branded(registry,receiver,name)
		check();local state=registry[receiver]or(if registry==events then sharedEvents[receiver]else nil);if not state then typeError(name.." called on an incompatible receiver")end;return state
	end
	local function constructor(name,length,prototype,create,statics)
		local value=native(name,length,function()typeError(name.." requires new")end)
		value.Construct=function(args)check();return create(args)end
		define(value,"prototype",{value=prototype})
		for key,item in statics or {}do value.Values[key]=item end
		define(prototype,"constructor",{value=value,writable=true,configurable=true});globals[name]=value
		if vm.Global then vm.Global.Bindings[name]={Value=value}end
		return value
	end

	targetPrototype=vm.Object({})
	eventPrototype=vm.Object({NONE=0,CAPTURING_PHASE=1,AT_TARGET=2,BUBBLING_PHASE=3})
	customPrototype=vm.Object({},eventPrototype)
	rejectionPrototype=vm.Object({},eventPrototype)
	exceptionPrototype=vm.Object({},vm.Prototypes.Error)
	for key,value in CONSTANTS do define(exceptionPrototype,key,{value=value,enumerable=true})end
	signalPrototype=vm.Object({},targetPrototype)
	controllerPrototype=vm.Object({})
	function host:DOMException(message,name)
		check();name=name or "Error";message=message or ""
		local state={Name=name,Message=message}
		local value=wrapper(exceptionPrototype,state)
		value.Kind="error";exceptions[value]=state;return value
	end
	accessor(exceptionPrototype,"name",function(receiver)return branded(exceptions,receiver,"DOMException.name").Name end)
	accessor(exceptionPrototype,"message",function(receiver)return branded(exceptions,receiver,"DOMException.message").Message end)
	accessor(exceptionPrototype,"code",function(receiver)return CODES[branded(exceptions,receiver,"DOMException.code").Name] or 0 end)
	exceptionPrototype.Values.toString=native("toString",0,function(_,receiver)
		local name,message=VM.string(vm.Get(receiver,"name")),VM.string(vm.Get(receiver,"message"))
		return if name==""then message elseif message==""then name else name..": "..message
	end)
	local function prevent(state)if state.Cancelable and not state.Passive then state.Canceled=true end end
	eventMethods.preventDefault=native("preventDefault",0,function(_,receiver)prevent(branded(events,receiver,"Event.preventDefault"));return U end)
	eventMethods.stopPropagation=native("stopPropagation",0,function(_,receiver)branded(events,receiver,"Event.stopPropagation").Stopped=true;return U end)
	eventMethods.stopImmediatePropagation=native("stopImmediatePropagation",0,function(_,receiver)local state=branded(events,receiver,"Event.stopImmediatePropagation");state.Stopped,state.Immediate=true,true;return U end)
	eventMethods.composedPath=native("composedPath",0,function(_,receiver)
		local state=branded(events,receiver,"Event.composedPath")
		local raw,wrappers={},{}
		for _,target in state.Path do local node=if type(target)=="table"then target.DOMNode else nil;table.insert(raw,node or target);wrappers[node or target]=target end
		local current=if type(state.CurrentTarget)=="table"then state.CurrentTarget.DOMNode else nil
		local visible=ShadowTree.VisiblePath(raw,current);local result={}
		for _,node in visible do table.insert(result,wrappers[node])end
		return vm.Array(result)
	end)
	local function initialize(state,kind,bubbles,cancelable)
		state.Type=VM.string(kind);state.Bubbles=VM.truth(bubbles);state.Cancelable=VM.truth(cancelable)
		state.Stopped,state.Immediate,state.Canceled,state.Trusted=false,false,false,false
	end
	eventMethods.initEvent=native("initEvent",1,function(args,receiver)
		required(args,1,"Event.initEvent");local state=branded(events,receiver,"Event.initEvent")
		if not state.Dispatching then initialize(state,arg(args,1),arg(args,2),arg(args,3))end;return U
	end)
	for key,value in eventMethods do eventPrototype.Values[key]=value end
	customPrototype.Values.initCustomEvent=native("initCustomEvent",1,function(args,receiver)
		required(args,1,"CustomEvent.initCustomEvent");local state=branded(events,receiver,"CustomEvent.initCustomEvent")
		if state.Kind~="CustomEvent" then typeError("Expected CustomEvent")end
		if not state.Dispatching then initialize(state,arg(args,1),arg(args,2),arg(args,3));state.Detail=if arg(args,4)==U then N else args[4]end;return U
	end)
	newEvent=function(kind,typeName,init)
		check();init=init or {}
		local state={Kind=kind,Type=typeName,Bubbles=init.bubbles==true,Cancelable=init.cancelable==true,Composed=init.composed==true,
			Target=N,CurrentTarget=N,Phase=0,Trusted=false,Canceled=false,Stopped=false,Immediate=false,Passive=false,Dispatching=false,Path={},
			BeforeUnloadValue=if kind=='BeforeUnloadEvent'then ''else nil,
			Time=if options.Clock then options.Clock()else os.clock()*1000,
			Detail=if init.detail==nil then N else init.detail,Promise=init.promise or U,Reason=if init.reason==nil then U else init.reason}
		local proto=if uiTypes[kind]then uiTypes[kind].Prototype elseif kind=="CustomEvent"then customPrototype elseif kind=="PromiseRejectionEvent"then rejectionPrototype else eventPrototype
		state.UI={}
		if uiTypes[kind]then for key,spec in uiTypes[kind].Fields do state.UI[key]=if init[key]~=nil then init[key]else spec[2]end end
		if kind=='InputEvent'then
			state.UI.targetRanges={}
			for _,range in init.targetRanges or {}do table.insert(state.UI.targetRanges,table.clone(range.RangeState))end
		end
		local value=wrapper(proto,state)
		accessor(value,"isTrusted",function(receiver)return branded(events,receiver,"Event.isTrusted").Trusted end,nil,false)
		events[value]=state;sharedEvents[value]=state;return value
	end
	local eventFields={type="Type",target="Target",srcElement="Target",currentTarget="CurrentTarget",eventPhase="Phase",bubbles="Bubbles",cancelable="Cancelable",composed="Composed",timeStamp="Time",defaultPrevented="Canceled"}
	for key,stateKey in eventFields do accessor(eventPrototype,key,function(receiver)return branded(events,receiver,"Event."..key)[stateKey]end)end
	accessor(eventPrototype,"cancelBubble",function(receiver)return branded(events,receiver,"Event.cancelBubble").Stopped end,
		function(receiver,value)local state=branded(events,receiver,"Event.cancelBubble");if VM.truth(value)then state.Stopped=true end end)
	accessor(eventPrototype,"returnValue",function(receiver)return not branded(events,receiver,"Event.returnValue").Canceled end,
		function(receiver,value)local state=branded(events,receiver,"Event.returnValue");if not VM.truth(value)then prevent(state)end end)
	accessor(customPrototype,"detail",function(receiver)local state=branded(events,receiver,"CustomEvent.detail");if state.Kind~="CustomEvent"then typeError("Expected CustomEvent")end;return state.Detail end)
	for key,stateKey in {promise="Promise",reason="Reason"}do accessor(rejectionPrototype,key,function(receiver)local state=branded(events,receiver,"PromiseRejectionEvent."..key);if state.Kind~="PromiseRejectionEvent"then typeError("Expected PromiseRejectionEvent")end;return state[stateKey]end)end
	function host:NewEvent(typeName,init,kind)return newEvent(kind or "Event",typeName,init)end
	local function eventConstructor(kind,args)
		required(args,if kind=="PromiseRejectionEvent"then 2 else 1,kind)
		local typeName=VM.string(args[1]);local init=arg(args,2)
		local values={bubbles=VM.truth(field(init,"bubbles")),cancelable=VM.truth(field(init,"cancelable")),composed=VM.truth(field(init,"composed"))}
		if kind=="CustomEvent"then local detail=field(init,"detail");values.detail=if detail==U then N else detail end
		if kind=="PromiseRejectionEvent"then values.promise=field(init,"promise");if not object(values.promise)then typeError("PromiseRejectionEvent requires an object promise")end;values.reason=field(init,"reason")end
		return newEvent(kind,typeName,values)
	end
	constructor("Event",1,eventPrototype,function(args)return eventConstructor("Event",args)end,{NONE=0,CAPTURING_PHASE=1,AT_TARGET=2,BUBBLING_PHASE=3})
	constructor("CustomEvent",1,customPrototype,function(args)return eventConstructor("CustomEvent",args)end)
	constructor("PromiseRejectionEvent",2,rejectionPrototype,function(args)return eventConstructor("PromiseRejectionEvent",args)end)
	local function uiText(value)
		if vm.ToPrimitive then value=vm.ToPrimitive(value,"string")end
		if type(value)=="table"and value.Kind=="symbol"then typeError("Cannot convert a Symbol to an event string")end
		return VM.string(value)
	end
	local function numeric(value,bits,signed)
		local result=VM.number(value)
		if not bits then if result~=result or math.abs(result)==math.huge then typeError("Event coordinate must be finite")end;return result end
		result=if result~=result or math.abs(result)==math.huge then 0 elseif result<0 then math.ceil(result)else math.floor(result)
		local modulus=2^bits;result%=modulus;if signed and result>=modulus/2 then result-=modulus end;return result
	end
	local function uiBrand(receiver,kind)
		local state=branded(events,receiver,kind);local current=state.Kind
		while current do if current==kind then return state end;current=uiTypes[current]and uiTypes[current].Parent end
		typeError("Incompatible "..kind.." receiver")
	end
	local touches,touchLists=setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"})
	local touchPrototype,touchListPrototype=vm.Object({}),vm.Object({})
	local model=vm.ObjectModel
	local function touchIndex(key)
		if type(key)~="string"then return nil end
		local index=tonumber(key);return if index and index>=0 and index<4294967295 and index%1==0 and tostring(index)==key then index+1 else nil
	end
	local touchFields={identifier="long",target="target",clientX="double",clientY="double",screenX="double",screenY="double",pageX="double",pageY="double",radiusX="float",radiusY="float",rotationAngle="float",force="float"}
	for name in touchFields do accessor(touchPrototype,name,function(receiver)return branded(touches,receiver,"Touch")[name]end)end
	local function touch(values)local value=wrapper(touchPrototype,values);touches[value]=values;return value end
	local function touchList(values)
		local value=wrapper(touchListPrototype,values);touchLists[value]=values
		local expandos=vm.Object({},touchListPrototype);value.Values=nil
		-- Chromium's legacy indexed implementation ignores loose/Reflect
		-- writes/defines but rejects strict writes; supported indices never change.
		value.GetOwnPropertyDescriptor=function(key)
			check();local at=touchIndex(key);local item=at and values[at]
			return if item then {Value=item,Writable=false,Enumerable=true,Configurable=true}else model.Own(expandos,key)
		end
		value.Get=function(key,receiver)check();local at=touchIndex(key);return if at and values[at]then values[at]else model.Get(expandos,key,receiver or value)end
		value.HasOwn=function(key)return value.GetOwnPropertyDescriptor(key)~=nil end
		value.Has=function(key)return value.HasOwn(key)or model.Has(expandos,key)end
		value.Set=function(key,item,strict)
			check();if touchIndex(key)then if strict then typeError("TouchList index is read-only")end;return true end
			return model.Set(expandos,key,item,strict,value)
		end
		value.DefineProperty=function(key,descriptor)
			check();if touchIndex(key)then return true end
			return model.DefineOwn(expandos,key,model.ToDescriptor(descriptor))
		end
		value.Delete=function(key)check();local at=touchIndex(key);return if at and values[at]then false else model.Delete(expandos,key,false)end
		value.Keys=function()check();local keys={};for i in values do table.insert(keys,tostring(i-1))end;for _,key in model.OwnKeys(expandos,false)do table.insert(keys,key)end;return keys end
		value.GetPrototype=function()return model.GetPrototype(expandos)end
		value.SetPrototype=function(proto)
			local seen={[value]=true};local current=proto
			while current~=N do if seen[current]then return false end;seen[current]=true;current=model.GetPrototype(current)end
			return model.SetPrototypeInternal(expandos,proto)
		end
		value.IsExtensible=function()return true end;value.PreventExtensions=function()return false end
		return value
	end
	accessor(touchListPrototype,"length",function(receiver)return #branded(touchLists,receiver,"TouchList")end)
	touchListPrototype.Values.item=native("item",1,function(args,receiver)
		required(args,1,"item");local values=branded(touchLists,receiver,"TouchList")
		return values[numeric(vm.ToPrimitive(args[1],"number"),32,false)+1]or N
	end)
	if vm.SymbolIterator then touchListPrototype.Values[vm.SymbolIterator]=native("values",0,function(_,receiver)
		local values=branded(touchLists,receiver,"TouchList");local array=vm.Array(table.clone(values))
		return vm:Call(vm.Get(array,vm.SymbolIterator),{},array)
	end)end
	constructor("TouchList",0,touchListPrototype,function()typeError("Illegal TouchList constructor")end)
	constructor("Touch",1,touchPrototype,function(args)
		required(args,1,"Touch");local init=arg(args,1);local values={};local names={}
		for name in touchFields do table.insert(names,name)end;table.sort(names)
		for _,name in names do
			local item=field(init,name);local kind=touchFields[name]
			if (name=="identifier"or name=="target")and item==U then typeError("Touch requires "..name)end
			if kind=="target"then if item==N or not targets[item]and not(type(item)=="table"and item.DOMNode)then typeError("Touch target must be an EventTarget")end;values[name]=item
			else
				local value=if item==U then 0 else numeric(vm.ToPrimitive(item,"number"),if kind=="long"then 32 else nil,kind=="long")
				if kind=="float"then local bits=buffer.create(4);buffer.writef32(bits,0,value);value=buffer.readf32(bits,0);if math.abs(value)==math.huge then typeError("Touch float must be finite")end end
				values[name]=value
			end
		end
		return touch(values)
	end)
	local function touchSequence(value)
		if touchLists[value]then return touchList(table.clone(touchLists[value]))end
		if not object(value)then typeError("Touch list must be an iterable object")end
		local out={};local nextValue,close=vm.Iterator(value)
		local ok,message=pcall(function()while true do local more,item=nextValue();if not more then break end;vm.Step();if #out>=64 then VM.throw(host:DOMException("Touch list budget exceeded","QuotaExceededError"))end;if not touches[item]then typeError("Touch list entries must be Touch objects")end;table.insert(out,item)end end)
		if not ok then if close then pcall(close)end;error(message,0)end
		return touchList(out)
	end
	function host:NativeTouchInit(init,wrap)
		local converted={};local result=table.clone(init)
		for _,name in {"touches","targetTouches","changedTouches"}do
			local list={}
			for _,item in init[name]or {}do
				local value=converted[item]
				if not value then
					local values={}
					for key in touchFields do values[key]=if key=="target"then wrap(item.target)else item[key]or 0 end
					value=touch(values);converted[item]=value
				end
				table.insert(list,value)
			end
			result[name]=touchList(list)
		end
		return result
	end
	function host:SetNodeWrapper(wrap)options.WrapNode=wrap end
	function host:SetRangeFactory(factory)options.NewStaticRange=factory end
	local function retargetTouches(state,current)
		if not state.OriginalTouchLists or not options.WrapNode then return end
		local cache=state.TouchPathCache;local key=current or N;local lists=cache[key]
		if not lists then
			lists={};local changed={}
			for name,list in state.OriginalTouchLists do
				local values={}
				for _,item in touchLists[list]do
					local result=changed[item]
					if not result then
						result=item;local source=touches[item];local target=source.target
						if type(target)=="table"and target.DOMNode then
							local adjusted=ShadowTree.Retarget(target.DOMNode,current)
							if adjusted~=target.DOMNode then local copy=table.clone(source);copy.target=options.WrapNode(adjusted);result=touch(copy)end
						end
						changed[item]=result
					end
					table.insert(values,result)
				end
				lists[name]=touchList(values)
			end
			cache[key]=lists
		end
		for name,list in lists do state.UI[name]=list end
	end
	if vm.SymbolToStringTag then define(touchPrototype,vm.SymbolToStringTag,{value="Touch",configurable=true});define(touchListPrototype,vm.SymbolToStringTag,{value="TouchList",configurable=true})end
	local function installUI(name,parent,fields,constants)
		local base=if uiTypes[parent]then uiTypes[parent].Prototype else eventPrototype
		local all=if uiTypes[parent]then table.clone(uiTypes[parent].Fields)else {}
		local prototype=vm.Object({},base);for key,spec in fields do all[key]=spec;if spec[3]~=false then accessor(prototype,key,function(receiver)return uiBrand(receiver,name).UI[key]end)end end
		uiTypes[name]={Prototype=prototype,Fields=all,Parent=parent}
		local names={"bubbles","cancelable","composed"};for key in all do table.insert(names,key)end;table.sort(names)
		local value=constructor(name,1,prototype,function(args)
			required(args,1,name);local typeName=uiText(args[1]);local init=arg(args,2);local values={}
			for _,key in names do
				local item=field(init,key);local spec=all[key]
				if not spec then values[key]=VM.truth(item)
				elseif item==U then values[key]=if spec[1]=="touch-list"then touchList({})else spec[2]
				elseif spec[1]=="boolean"then values[key]=VM.truth(item)
				elseif spec[1]=="string"then values[key]=uiText(item)
				elseif spec[1]=="nullable-string"then values[key]=if item==N then N else uiText(item)
				elseif spec[1]=="target"then if item~=N and not targets[item]and not(type(item)=="table"and item.DOMNode)then typeError("Expected EventTarget or null")end;values[key]=item
				elseif spec[1]=="element"then if item~=N and not(type(item)=="table"and item.DOMNode and item.DOMNode.Kind=="Element"and(not item.DOMNode.NamespaceURI or item.DOMNode.NamespaceURI=="http://www.w3.org/1999/xhtml"))then typeError("Expected HTMLElement or null")end;values[key]=item
				elseif spec[1]=="dom-element"then if item~=N and not(type(item)=="table"and item.DOMNode and item.DOMNode.Kind=="Element")then typeError("Expected Element or null")end;values[key]=item
				elseif spec[1]=="window"then if item~=N and item~=globals.window then typeError("Expected this realm's Window or null")end;values[key]=item
				elseif spec[1]=="object"then if item~=N and not object(item)then typeError("Expected object or null")end;values[key]=item
				elseif spec[1]=="touch-list"then values[key]=touchSequence(item)
				elseif spec[1]=="static-ranges"then
					local valuesOut={};local nextValue=vm.Iterator(item)
					while true do vm.Step();local more,entry=nextValue();if not more then break end
						if type(entry)~='table'or not entry.RangeBrand or not entry.RangeStatic or not entry.RangeState then typeError('targetRanges requires StaticRange values')end
						if #valuesOut>=4096 then typeError('InputEvent target-range budget exceeded')end
						table.insert(valuesOut,entry)
					end
					values[key]=valuesOut
				elseif spec[1]=="coordinate"then values[key]=math.floor(numeric(item))
				elseif spec[1]=="double"then values[key]=numeric(item)
				elseif spec[1]=="float"then
					local bits=buffer.create(4);buffer.writef32(bits,0,numeric(item));local value=buffer.readf32(bits,0)
					if math.abs(value)==math.huge then typeError("Event float must be finite")end;values[key]=value
				elseif spec[1]=="long"then values[key]=numeric(item,32,true)
				elseif spec[1]=="short"then values[key]=numeric(item,16,true)
				elseif spec[1]=="ushort"then values[key]=numeric(item,16,false)
				else values[key]=numeric(item,32,false)end
			end
			return newEvent(name,typeName,values)
		end,constants)
		vm.SetPrototype(value,globals[parent]or globals.Event)
		if vm.SymbolToStringTag then define(prototype,vm.SymbolToStringTag,{value=name,configurable=true})end
		for key,constant in constants or {}do define(value,key,{value=constant,enumerable=true});define(prototype,key,{value=constant,enumerable=true})end
		return prototype
	end
	installUI("ToggleEvent","Event",{oldState={"string",""},newState={"string",""},source={"dom-element",N}})
	installUI("PageTransitionEvent","Event",{persisted={"boolean",false}})
	local beforeUnloadPrototype=vm.Object({},eventPrototype)
	uiTypes.BeforeUnloadEvent={Prototype=beforeUnloadPrototype,Fields={},Parent='Event'}
	accessor(beforeUnloadPrototype,'returnValue',function(receiver)return uiBrand(receiver,'BeforeUnloadEvent').BeforeUnloadValue end,
		function(receiver,value)
			local state=uiBrand(receiver,'BeforeUnloadEvent');state.BeforeUnloadValue=uiText(value)
		end)
	local beforeUnloadConstructor=constructor('BeforeUnloadEvent',0,beforeUnloadPrototype,function()typeError('Illegal BeforeUnloadEvent constructor')end)
	vm.SetPrototype(beforeUnloadConstructor,globals.Event)
	if vm.SymbolToStringTag then define(beforeUnloadPrototype,vm.SymbolToStringTag,{value='BeforeUnloadEvent',configurable=true})end
	local uiProto=installUI("UIEvent","Event",{view={"window",N},detail={"long",0}})
	accessor(uiProto,"which",function(receiver)uiBrand(receiver,"UIEvent");return 0 end)
	local modifiers={altKey={"boolean",false},ctrlKey={"boolean",false},metaKey={"boolean",false},shiftKey={"boolean",false},modifierAltGraph={"boolean",false},modifierCapsLock={"boolean",false},modifierFn={"boolean",false},modifierFnLock={"boolean",false},modifierHyper={"boolean",false},modifierNumLock={"boolean",false},modifierScrollLock={"boolean",false},modifierSuper={"boolean",false},modifierSymbol={"boolean",false},modifierSymbolLock={"boolean",false}}
	for key,spec in modifiers do if key:sub(1,8)=="modifier"then spec[3]=false end end
	local mouseFields=table.clone(modifiers)
	for key,spec in {screenX={"coordinate",0},screenY={"coordinate",0},clientX={"coordinate",0},clientY={"coordinate",0},button={"short",0},buttons={"ushort",0},relatedTarget={"target",N},movementX={"long",0},movementY={"long",0}}do mouseFields[key]=spec end
	local mouseProto=installUI("MouseEvent","UIEvent",mouseFields)
	for key,source in {x="clientX",y="clientY",pageX="clientX",pageY="clientY",offsetX="clientX",offsetY="clientY"}do accessor(mouseProto,key,function(receiver)return uiBrand(receiver,"MouseEvent").UI[source]end)end
	accessor(mouseProto,"which",function(receiver)return uiBrand(receiver,"MouseEvent").UI.button+1 end)
	local keyboardFields=table.clone(modifiers)
	for key,spec in {key={"string",""},code={"string",""},location={"ulong",0},["repeat"]={"boolean",false},isComposing={"boolean",false},charCode={"ulong",0},keyCode={"ulong",0}}do keyboardFields[key]=spec end
	local keyboardProto=installUI("KeyboardEvent","UIEvent",keyboardFields,{DOM_KEY_LOCATION_STANDARD=0,DOM_KEY_LOCATION_LEFT=1,DOM_KEY_LOCATION_RIGHT=2,DOM_KEY_LOCATION_NUMPAD=3})
	accessor(keyboardProto,"which",function(receiver)local state=uiBrand(receiver,"KeyboardEvent");return if state.UI.charCode~=0 then state.UI.charCode else state.UI.keyCode end)
	for kind,prototype in {MouseEvent=mouseProto,KeyboardEvent=keyboardProto}do prototype.Values.getModifierState=native("getModifierState",1,function(args,receiver)
		required(args,1,"getModifierState");local state=uiBrand(receiver,kind);local key=uiText(args[1]);local aliases={Alt="altKey",Control="ctrlKey",Meta="metaKey",Shift="shiftKey"};return state.UI[aliases[key]or("modifier"..key)]==true
	end)end
	installUI("WheelEvent","MouseEvent",{deltaX={"double",0},deltaY={"double",0},deltaZ={"double",0},deltaMode={"ulong",0}},{DOM_DELTA_PIXEL=0,DOM_DELTA_LINE=1,DOM_DELTA_PAGE=2})
	installUI("FocusEvent","UIEvent",{relatedTarget={"target",N}})
	local inputProto=installUI("InputEvent","UIEvent",{data={"nullable-string",N},inputType={"string",""},isComposing={"boolean",false},dataTransfer={"object",N},targetRanges={"static-ranges",{},false}})
	inputProto.Values.getTargetRanges=native("getTargetRanges",0,function(_,receiver)
		local s=uiBrand(receiver,"InputEvent");local values={}
		for _,state in s.UI.targetRanges or {}do table.insert(values,options.NewStaticRange(table.clone(state)))end
		return vm.Array(values)
	end)
	installUI("CompositionEvent","UIEvent",{data={"string",""}})
	local touchEventFields=table.clone(modifiers)
	for _,name in {"touches","targetTouches","changedTouches"}do touchEventFields[name]={"touch-list",touchList({})}end
	installUI("TouchEvent","UIEvent",touchEventFields)
	installUI("PointerEvent","MouseEvent",{pointerId={"long",0},width={"double",1},height={"double",1},pressure={"float",0},tangentialPressure={"float",0},tiltX={"long",0},tiltY={"long",0},twist={"long",0},altitudeAngle={"double",math.pi/2},azimuthAngle={"double",0},pointerType={"string",""},isPrimary={"boolean",false},persistentDeviceId={"long",0},clientX={"double",0},clientY={"double",0},screenX={"double",0},screenY={"double",0}})
	installUI("SubmitEvent","Event",{submitter={"element",N}})
	function host:EventClassForType(typeName)
		if typeName=='beforeunload'then return 'BeforeUnloadEvent'
		elseif typeName=='pageshow'or typeName=='pagehide'then return 'PageTransitionEvent'
		elseif typeName=="wheel"then return "WheelEvent"
		elseif typeName:sub(1,5)=="touch"then return "TouchEvent"
		elseif typeName:sub(1,7)=="pointer"or typeName=="gotpointercapture"or typeName=="lostpointercapture"then return "PointerEvent"
		elseif typeName=="keydown"or typeName=="keyup"or typeName=="keypress"then return "KeyboardEvent"
		elseif typeName=="input"or typeName=="beforeinput"then return "InputEvent"
		elseif typeName=="focus"or typeName=="blur"or typeName=="focusin"or typeName=="focusout"then return "FocusEvent"
		elseif typeName:sub(1,11)=="composition"then return "CompositionEvent"
		elseif typeName=="submit"then return "SubmitEvent"
		elseif typeName=="toggle" or typeName=="beforetoggle"then return "ToggleEvent"
		elseif typeName:sub(1,5)=="mouse"or typeName=="click"or typeName=="dblclick"or typeName=="auxclick"or typeName=="contextmenu"then return "MouseEvent"end
		return "Event"
	end
	constructor("DOMException",0,exceptionPrototype,function(args)
		return host:DOMException(if arg(args,1)==U then ""else VM.string(args[1]),if arg(args,2)==U then "Error"else VM.string(args[2]))
	end,CONSTANTS)

	local function remove(state,listener)
		if listener.Removed then return end;listener.Removed=true
		local index=table.find(state.Listeners,listener);if index then table.remove(state.Listeners,index)end
		if listener.Unsubscribe then listener.Unsubscribe();listener.Unsubscribe=nil end
		if updateDependentRetention then updateDependentRetention(state.Target)end
	end
	local function callbackValue(callback)
		if callback==U or callback==N then return nil end
		if not object(callback) and not VM.callable(callback)then typeError("Event listener must be an object or null")end
		return callback
	end
	local function capture(value)
		if object(value)then return VM.truth(field(value,"capture"))end
		return VM.truth(value)
	end
	local function add(target,typeName,callback,init)
		local state=branded(targets,target,"EventTarget.addEventListener")
		callback=callbackValue(callback)
		local capturing=capture(init)
		local once,passive,signal=false,nil,U
		if object(init)then
			once=VM.truth(field(init,"once"));local value=field(init,"passive");if value~=U then passive=VM.truth(value)end
			signal=field(init,"signal")
			if signal~=U and not signals[signal]then typeError("Listener signal must be an AbortSignal")end
		end
		if signal~=U and signals[signal].Aborted then return end
		if not callback then return end
		for _,listener in state.Listeners do if listener.Type==typeName and listener.Callback==callback and listener.Capture==capturing then return end end
		assert(#state.Listeners<1024,"JavaScript event listener budget exceeded")
		if passive==nil then passive=if state.DefaultPassive then state.DefaultPassive(typeName,target)==true elseif options.DefaultPassive then options.DefaultPassive(typeName,target)==true else false end
		local listener={Type=typeName,Callback=callback,Capture=capturing,Once=once,Passive=passive,Removed=false}
		table.insert(state.Listeners,listener)
		if signal~=U then
			-- A long-lived abort signal must not by itself retain detached targets.
			local refs=setmetatable({state,listener},{__mode="v"})
			listener.Unsubscribe=subscribe(signal,function()local owner,item=refs[1],refs[2];if owner and item then remove(owner,item)end end,
				function()return refs[1]~=nil and refs[2]~=nil end)
		end
		if updateDependentRetention then updateDependentRetention(target)end
	end
	local function targetReceiver(receiver)
		return if receiver==nil or receiver==U or receiver==N then operationGlobal else receiver
	end
	targetMethods.addEventListener=native("addEventListener",2,function(args,receiver)
		receiver=targetReceiver(receiver)
		required(args,2,"EventTarget.addEventListener");add(receiver,VM.string(args[1]),arg(args,2),arg(args,3));return U
	end)
	targetMethods.removeEventListener=native("removeEventListener",2,function(args,receiver)
		receiver=targetReceiver(receiver)
		required(args,2,"EventTarget.removeEventListener");local state=branded(targets,receiver,"EventTarget.removeEventListener")
		local typeName,callback=VM.string(args[1]),callbackValue(arg(args,2));local capturing=capture(arg(args,3))
		for _,listener in state.Listeners do if listener.Type==typeName and listener.Callback==callback and listener.Capture==capturing then remove(state,listener);break end end
		return U
	end)
	targetMethods.dispatchEvent=native("dispatchEvent",1,function(args,receiver)required(args,1,"EventTarget.dispatchEvent");return dispatch(targetReceiver(receiver),args[1],false)end)
	for key,value in targetMethods do targetPrototype.Values[key]=value end
	local function invoke(target,event,state,capturing,phase)
		if (state.Stopped and not state.StandaloneDispatch) or state.Immediate or not host.Alive then return end
		state.CurrentTarget,state.Phase=target,phase
		retargetTouches(state,if type(target)=="table"then target.DOMNode else nil)
		if state.OriginalTarget and type(state.OriginalTarget)=="table"and state.OriginalTarget.DOMNode then
			local current=if type(target)=="table"then target.DOMNode else nil
			local original=state.OriginalTarget.DOMNode;local retargeted=ShadowTree.Retarget(original,current)
			state.Target=state.PathTargets[retargeted]or state.OriginalTarget
			if state.Target==target then state.Phase=2 end
			local related=state.OriginalRelatedTarget
			if type(related)=="table"and related.DOMNode then
				local relatedNode=ShadowTree.Retarget(related.DOMNode,current)
				state.UI.relatedTarget=state.PathTargets[relatedNode]or related
				if relatedNode==retargeted then return end
			end
		end
		local targetState=targets[target];if not targetState then return end
		for _,listener in table.clone(targetState.Listeners)do
			vm.Step();if not host.Alive then return end
			if listener.Removed or listener.Type~=state.Type or (capturing~=nil and listener.Capture~=capturing) then continue end
			local callback=if listener.Handler then handlerGet(targetState,listener.Key)else listener.Callback
			if callback==N or callback==nil then continue end
			if listener.Once then remove(targetState,listener)end
			state.Passive=listener.Passive
			local legacyError=listener.Handler and targetState.GlobalErrorHandler and state.Type=="error"and state.Kind=="ErrorEvent"
			local ok,result=pcall(function()
				if VM.callable(callback)then
					local args=if legacyError then {vm.Get(event,"message"),vm.Get(event,"filename"),vm.Get(event,"lineno"),vm.Get(event,"colno"),vm.Get(event,"error")}else {event}
					return vm:Call(callback,args,target)
				end
				local handler=vm.Get(callback,"handleEvent")
				if not VM.callable(handler)then typeError("Event listener handleEvent is not callable")end
				return vm:Call(handler,{event},callback)
			end)
			state.Passive=false
			if not ok then report(result)elseif listener.Handler then
				-- BeforeUnload handlers coerce their result to DOMString? even for
				-- a plain synthetic Event, for which false therefore does not cancel.
				if listener.Key=='onbeforeunload'then
					if result~=N and result~=U and result~=nil then
						local converted,value=pcall(function()return VM.string(vm.ToPrimitive(result,'string'))end)
						if not converted then report(value)elseif state.Kind=='BeforeUnloadEvent'then prevent(state);if state.BeforeUnloadValue==''then state.BeforeUnloadValue=value end end
					end
				elseif result==(if legacyError then true else false)then prevent(state)end
			end
			if host.Alive and options.AfterCallback then options.AfterCallback()end
			if state.Immediate then break end
		end
	end
	dispatch=function(target,event,trusted,legacyTarget)
		local targetState=branded(targets,target,"EventTarget.dispatchEvent")
		local state=branded(events,event,"EventTarget.dispatchEvent argument")
		if state.Dispatching then VM.throw(host:DOMException("The event is already being dispatched","InvalidStateError"))end
		state.Dispatching,state.Target,state.Trusted=true,legacyTarget or target,trusted==true
		state.OriginalTarget,state.OriginalRelatedTarget=target,state.UI.relatedTarget
		if state.Kind=="TouchEvent"then
			state.OriginalTouchLists={};state.TouchPathCache={}
			for _,name in {"touches","targetTouches","changedTouches"}do state.OriginalTouchLists[name]=state.UI[name]end
		end
		state.StandaloneDispatch=targetState.Standalone
		local ok,message=pcall(function()
			local path,seen={target},{[target]=true};local current,record=target,targetState
			while record and record.Parent do
				vm.Step();local parent=record.Parent(current,event)
				if parent==nil or parent==N or parent==U then break end
				assert(not seen[parent] and #path<2048,"JavaScript event path is cyclic or exceeds its budget")
				seen[parent]=true;table.insert(path,parent);current=parent;record=targets[parent]
			end
			state.Path=path
			state.PathTargets={};for _,item in path do if type(item)=="table"and item.DOMNode then state.PathTargets[item.DOMNode]=item end end
			-- Chromium standalone targets (including AbortSignal) invoke once in registration order.
			if targetState.Standalone and #path==1 then invoke(target,event,state,nil,2);return end
			for i=#path,1,-1 do invoke(path[i],event,state,true,if i==1 then 2 else 1)end
			for i=1,#path do
				local item=path[i];local node=if type(item)=="table"then item.DOMNode else nil
				local original=if type(target)=="table"then target.DOMNode else nil
				local atTarget=original and node and ShadowTree.Retarget(original,node)==node
				if i==1 or state.Bubbles or atTarget then invoke(item,event,state,false,if i==1 or atTarget then 2 else 3)end
			end
		end)
		if type(target)=="table"and target.DOMNode then
			local adjusted=ShadowTree.Retarget(target.DOMNode,nil)
			state.Target=if not state.Composed and ShadowTree.Root(target.DOMNode).Kind=="ShadowRoot"then N else state.PathTargets and state.PathTargets[adjusted]or target
		end
		state.OriginalTarget,state.OriginalRelatedTarget,state.PathTargets=nil,nil,nil
		retargetTouches(state,nil);state.OriginalTouchLists,state.TouchPathCache=nil,nil
		state.Dispatching,state.CurrentTarget,state.Phase,state.Path=false,N,0,{}
		if not state.StandaloneDispatch then state.Stopped,state.Immediate=false,false end
		state.Passive,state.StandaloneDispatch=false,false
		if not ok then error(message,0)end
		return not state.Canceled
	end
	function host:Dispatch(target,event,trusted,legacyTarget)return dispatch(target,event,trusted,legacyTarget)end
	function host:TargetMethods(target,key)branded(targets,target,"EventTarget");return targetMethods[key]end
	handlerGet=function(state,key)
		if state.HandlerTarget then
			local target=state.HandlerTarget(key)
			if target==false then return N elseif target and target~=state.Target then return state.Owner:HandlerGet(target,key)end
		end
		local listener=state.Handlers[key]
		if not listener then return N end
		if listener.Pending then
			local pending=listener.Pending
			local ok,value,resolved,reportFailure=pcall(pending)
			-- Compilation may dispatch an error event whose script replaces the
			-- same handler. Never overwrite that newer value on return.
			if listener.Pending==pending then
				if not ok then listener.Pending=nil;listener.Callback=nil;report(value)
				elseif resolved then listener.Pending=nil;listener.Callback=if VM.callable(value)then value else nil end
			end
			if ok and reportFailure then reportFailure();return N end
		end
		return listener.Callback or N
	end
	local function handlerSet(target,state,key,value,pending)
		if state.HandlerTarget then
			local destination=state.HandlerTarget(key)
			if destination==false then return elseif destination and destination~=target then
				if pending then state.Owner:HandlerContent(destination,key,pending)else state.Owner:HandlerSet(destination,key,value)end;return
			end
		end
		local previous=state.Handlers[key]
		if not VM.callable(value)then value=nil end
		if previous then
			if value or pending then previous.Callback=value;previous.Pending=pending else remove(state,previous);state.Handlers[key]=nil end
		elseif value or pending then
			assert(#state.Listeners<1024,"JavaScript event listener budget exceeded")
			local eventType=({onwebkitanimationend='webkitAnimationEnd',onwebkitanimationiteration='webkitAnimationIteration',onwebkitanimationstart='webkitAnimationStart',onwebkittransitionend='webkitTransitionEnd'})[key]or key:sub(3)
			local listener={Type=eventType,Key=key,Callback=value,Pending=pending,Capture=false,Once=false,Passive=false,Removed=false,Handler=true}
			state.Handlers[key]=listener;table.insert(state.Listeners,listener)
		end
		if updateDependentRetention then updateDependentRetention(target)end
	end
	function host:WrapTarget(target,settings)
		check();if targets[target]then if settings and settings.Parent then targets[target].Parent=settings.Parent end;if settings and settings.HandlerTarget then targets[target].HandlerTarget=settings.HandlerTarget end;return target end
		settings=settings or {}
		local state={Target=target,Owner=host,Listeners={},Handlers={},Parent=settings.Parent or options.Parent,AllowHandlers=settings.Handlers==true,HandlerNames=settings.HandlerNames,HandlerTarget=settings.HandlerTarget,Standalone=settings.Standalone==true,DefaultPassive=settings.DefaultPassive,GlobalErrorHandler=settings.GlobalErrorHandler==true}
		targets[target]=state
		-- Ordinary VM objects use descriptor setters, not their legacy .Set hook.
		-- Share handler prototypes so a DOM tree does not allocate one closure per handler per node.
		if state.AllowHandlers and target.Values~=nil then
			local base=target.Prototype or vm.Prototypes.Object
			local proto=if not state.HandlerNames then handlerPrototypes[base]else nil
			if not proto then
				proto=vm.Object({},base)
				for key in state.HandlerNames or handlerNames do
					accessor(proto,key,function(receiver)local record=branded(targets,receiver,"Event handler");return handlerGet(record,key)end,
						function(receiver,value)handlerSet(receiver,branded(targets,receiver,"Event handler"),key,value)end)
				end
				if not state.HandlerNames then handlerPrototypes[base]=proto end
			end
			target.Prototype=proto
		end
		local oldGet,oldSet=target.Get,target.Set
		target.Get=function(key)
			check();if state.AllowHandlers and type(key)=="string" and key:sub(1,2)=="on" and (if state.HandlerNames then state.HandlerNames[key]else handlerNames[key])then return handlerGet(state,key)end
			if oldGet then local result=oldGet(key);if result~=U and result~=nil then return result end end
			if target.Values and target.Values[key]~=nil then return target.Values[key]end
			return if state.Standalone then U else targetMethods[key] or U
		end
		target.Set=function(key,value,strict)
			check();if state.AllowHandlers and type(key)=="string" and key:sub(1,2)=="on" and (if state.HandlerNames then state.HandlerNames[key]else handlerNames[key])then handlerSet(target,state,key,value)
			elseif oldSet then oldSet(key,value,strict)else target.Values=target.Values or {};target.Values[key]=value end
		end
		return target
	end
	function host:EraseListeners(target)
		local state=targets[target];if not state then return end
		for _,listener in table.clone(state.Listeners)do remove(state,listener)end
		table.clear(state.Handlers)
	end
	function host:TransferTarget(target,destination)
		local state=targets[target];if not state or destination==self then return end
		destination:ReceiveTarget(target,state)
	end
	function host:ReceiveTarget(target,state)
		check();targets[target]=state;state.Owner=self
	end
	function host:NewTarget()
		local target=wrapper(targetPrototype,{},nil,nil)
		return self:WrapTarget(target,{Parent=function()return nil end,Standalone=true})
	end
	constructor("EventTarget",0,targetPrototype,function()return host:NewTarget()end)

	local function signalState(signal)return branded(signals,signal,"AbortSignal")end
	local function newSignal()
		local state={Aborted=false,Reason=U,Algorithms={},Dependents=setmetatable({},{__mode="v"}),DependentRoots={},DependentCount=0,Sources={}}
		local value=wrapper(signalPrototype,state)
		signals[value]=state
		host:WrapTarget(value,{Parent=function()return nil end,Standalone=true})
		return value
	end
	accessor(signalPrototype,"aborted",function(receiver)return signalState(receiver).Aborted end)
	accessor(signalPrototype,"reason",function(receiver)return signalState(receiver).Reason end)
	accessor(signalPrototype,"onabort",function(receiver)local state=branded(targets,receiver,"AbortSignal.onabort");signalState(receiver);return if state.Handlers.onabort then state.Handlers.onabort.Callback else N end,
		function(receiver,value)signalState(receiver);handlerSet(receiver,targets[receiver],"onabort",value)end)
	updateDependentRetention=function(signal)
		local state=signals[signal];if not state then return end
		if state.UsageChanged then state.UsageChanged()end
		local retain=not state.Aborted and (#state.Algorithms>0 or (targets[signal] and #targets[signal].Listeners>0))
		for _,source in state.Sources do local sourceState=signals[source];if sourceState then sourceState.DependentRoots[signal]=if retain then true else nil end end
	end
	subscribe=function(signal,callback,alive)
		local state=signalState(signal)
		if state.Aborted then return function()end end
		for i=#state.Algorithms,1,-1 do local entry=state.Algorithms[i];if entry.Alive and not entry.Alive()then entry.Callback=nil;table.remove(state.Algorithms,i)end end
		assert(#state.Algorithms<1024,"JavaScript abort algorithm budget exceeded")
		local entry={Callback=callback,Alive=alive};table.insert(state.Algorithms,entry);updateDependentRetention(signal)
		return function()
			if not entry.Callback then return end;entry.Callback=nil
			local index=table.find(state.Algorithms,entry);if index then table.remove(state.Algorithms,index)end
			updateDependentRetention(signal)
		end
	end
	function host:SubscribeAbort(signal,callback)return subscribe(signal,callback)end
	function host:IsAborted(signal)return signalState(signal).Aborted end
	function host:AbortReason(signal)return signalState(signal).Reason end
	-- Signal subclasses share the native abort brand and listener lifetime.
	function host:ObserveSignalUsage(signal,callback)signalState(signal).UsageChanged=callback;updateDependentRetention(signal)end
	function host:SignalObserved(signal,eventType)
		local state=signalState(signal);if #state.Algorithms>0 then return true end
		local target=targets[signal];if target then for _,listener in target.Listeners do if not listener.Removed and listener.Type==eventType then return true end end end
		return false
	end
	local function abortSteps(signal,state)
		updateDependentRetention(signal)
		local algorithms=state.Algorithms;state.Algorithms={}
		for _,entry in algorithms do
			if not host.Alive then return end
			local callback=entry.Callback;entry.Callback=nil
			if callback then callback()end
		end
		if host.Alive then dispatch(signal,newEvent("Event","abort"),true)end
		table.clear(state.Sources);table.clear(state.Dependents);table.clear(state.DependentRoots);state.DependentCount=0
	end
	abort=function(signal,reason)
		local state=signalState(signal);if state.Aborted then return end
		if reason==nil or reason==U then reason=host:DOMException("The operation was aborted","AbortError")end
		state.Aborted,state.Reason=true,reason
		local dependents={}
		-- Every dependent's state changes before any abort listener is invoked.
		for i=1,state.DependentCount do
			local dependent=state.Dependents[i];local dependentState=dependent and signals[dependent]
			if dependentState and not dependentState.Aborted then dependentState.Aborted,dependentState.Reason=true,reason;table.insert(dependents,dependent)end
		end
		abortSteps(signal,state)
		for _,dependent in dependents do if host.Alive then abortSteps(dependent,signals[dependent])end end
	end
	signalMethods.throwIfAborted=native("throwIfAborted",0,function(_,receiver)local state=signalState(receiver);if state.Aborted then VM.throw(state.Reason)end;return U end)
	for key,value in signalMethods do signalPrototype.Values[key]=value end
	local statics={}
	statics.abort=native("abort",0,function(args)local value=newSignal();local state=signals[value];state.Aborted=true;state.Reason=if arg(args,1)==U then host:DOMException("The operation was aborted","AbortError")else args[1];return value end)
	statics.any=native("any",1,function(args)
		required(args,1,"AbortSignal.any");local iterator=vm.Iterator(args[1]);local list={}
		while true do local more,value=iterator();if not more then break end;vm.Step();signalState(value);assert(#list<1024,"JavaScript abort source budget exceeded");table.insert(list,value)end
		local result=newSignal();local resultState=signals[result]
		for _,value in list do local state=signals[value];if state.Aborted then resultState.Aborted,resultState.Reason=true,state.Reason;return result end end
		local seen={}
		for _,value in list do
			local state=signals[value];local sources=if #state.Sources>0 then state.Sources else {value}
			for _,source in sources do
				if seen[source]then continue end;seen[source]=true
				local sourceState=signals[source]
				if sourceState.DependentCount>=4096 then
					local live={};for i=1,sourceState.DependentCount do local dependent=sourceState.Dependents[i];if dependent and signals[dependent] and not signals[dependent].Aborted then table.insert(live,dependent)end end
					sourceState.Dependents=setmetatable(live,{__mode="v"});sourceState.DependentCount=#live
				end
				assert(sourceState.DependentCount<4096,"JavaScript dependent abort signal budget exceeded")
				table.insert(resultState.Sources,source);sourceState.DependentCount+=1;sourceState.Dependents[sourceState.DependentCount]=result
			end
		end
		return result
	end)
	statics.timeout=native("timeout",1,function(args)
		required(args,1,"AbortSignal.timeout");local ms=VM.number(args[1])
		if ms~=ms or math.abs(ms)==math.huge then typeError("AbortSignal.timeout requires a finite unsigned duration")end
		ms=if ms<0 then math.ceil(ms)else math.floor(ms)
		if ms<0 or ms>=18446744073709551616 then typeError("AbortSignal.timeout duration is out of range")end
		assert(options.SetTimeout and options.ClearTimeout,"AbortSignal.timeout requires host timers")
		local signal=newSignal();local remaining=ms
		local schedule
		schedule=function()
			local delay=math.min(2147483647,remaining);remaining-=delay
			local id
			id=options.SetTimeout(function()
				timers[id]=nil;if not host.Alive then return end
				if remaining>0 then schedule()else abort(signal,host:DOMException("The operation timed out","TimeoutError"))end
			end,delay)
			timers[id]=true
		end
		schedule();return signal
	end)
	constructor("AbortSignal",0,signalPrototype,function()typeError("Illegal AbortSignal constructor")end,statics)
	controllerMethods.abort=native("abort",0,function(args,receiver)local state=branded(controllers,receiver,"AbortController.abort");abort(state.Signal,arg(args,1));return U end)
	for key,value in controllerMethods do controllerPrototype.Values[key]=value end
	constructor("AbortController",0,controllerPrototype,function()
		local state={Signal=newSignal()}
		local value=wrapper(controllerPrototype,state)
		controllers[value]=state;return value
	end)
	accessor(controllerPrototype,"signal",function(receiver)return branded(controllers,receiver,"AbortController.signal").Signal end)
	for name,proto in {EventTarget=targetPrototype,Event=eventPrototype,CustomEvent=customPrototype,PromiseRejectionEvent=rejectionPrototype,DOMException=exceptionPrototype,AbortSignal=signalPrototype,AbortController=controllerPrototype}do
		local symbol=vm.Global and vm.Global.Bindings.Symbol
		if symbol then local tag=vm.Get(symbol.Value,"toStringTag");if tag~=U then define(proto,tag,{value=name,configurable=true})end end
	end
	for _,name in {"CustomEvent","PromiseRejectionEvent"}do vm.SetPrototype(globals[name],globals.Event)end
	vm.SetPrototype(globals.AbortSignal,globals.EventTarget)
	for key,value in CONSTANTS do define(globals.DOMException,key,{value=value,enumerable=true})end
	function host:DescribeDOMException(value)local state=exceptions[value];return if state then {Name=state.Name,Message=state.Message}else nil end
	function host:HandlerGet(target,key)local state=branded(targets,target,"Event handler");return handlerGet(state,key)end
	function host:HandlerSet(target,key,value)handlerSet(target,branded(targets,target,"Event handler"),key,value)end
	function host:HandlerContent(target,key,compile)handlerSet(target,branded(targets,target,"Event handler"),key,nil,compile)end
	function host:Destroy()
		if not self.Alive then return end;self.Alive=false
		operationGlobal=nil
		table.clear(touches);table.clear(touchLists)
		for id in timers do options.ClearTimeout(id)end;table.clear(timers)
		for _,state in targets do if state.Owner==host then for _,listener in table.clone(state.Listeners)do remove(state,listener)end;table.clear(state.Handlers)end end
		for _,state in signals do table.clear(state.Algorithms);table.clear(state.Dependents);table.clear(state.DependentRoots);table.clear(state.Sources)end
		table.clear(targets);table.clear(events);table.clear(signals);table.clear(controllers);table.clear(exceptions);table.clear(handlerPrototypes);table.clear(options)
	end
	return host
end
return HostEvents
