--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local SourceDocument=require(script.Parent.Parent.DOM.MediaSourceDocument)
-- Browser audio state belongs to the DOM node, including detached Audio objects.
-- Native completions enter the realm only through its task queue.
local DocumentInfo=require(script.Parent.Parent.HTML.DocumentInfo)
local URLRecord=require(script.Parent.URLRecord)
local WorkContext=require(script.Parent.Parent.WorkContext)
local MediaSelection=require(script.Parent.Parent.HTML.MediaSelection)
local Strings=require(script.Parent.Strings)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local AudioState=require(script.Parent.Parent.HTML.AudioState)
local VideoElements=require(script.Parent.VideoElements)
local AudioElements={}
function AudioElements.install(vm: any,globals: any,options: any): any
	local VM,U,N=vm.Model,vm.Model.Undefined,vm.Model.Null
	local host,bridge=options.Host,options.Bridge
	local api={Alive=true,Pending=0};local records=setmetatable({},{__mode="kv"});local active={}
	local pendingRemoved={};local removalWake=false
	local origin={Alive=true,Token={},Slots={},States=setmetatable({},{__mode="kv"}),Capabilities={},Serial=0,Pool=AudioState.newPool()}
	local owner={Alive=true,Token={},Slots={},States=setmetatable({},{__mode="kv"}),Active=active,Removed=pendingRemoved,Pending=0,Document=options.Document,Adapter=options.Adapter}
	api.OriginLease=origin;api.OwnerLease=owner;host.AudioElements=api
	local function audio(node)return ElementNames.html(node,"audio")end
	local function media(node)return audio(node)or ElementNames.html(node,"video")end
	local function preload(node)
		local value=(node.Attributes.preload or "metadata"):lower()
		-- Missing/invalid defaults are an engine UA choice. Empty is auto;
		-- enumerated keywords ignore ASCII case, but do not trim whitespace.
		return if value=="none"or value=="metadata"or value=="auto"then value elseif value==""then"auto"else"metadata"
	end
	local function sourceBase(node)
		local owner=node.OwnerDocument or options.Document
		local base=bridge.OwnerBridge(owner).NativeRead(owner,"baseURI")
		return if type(base)=="string"then base else options.URL or"about:blank"
	end
	local function resolveSource(node,value)return DocumentInfo.resolveURL(sourceBase(node),value)end
	local function selectedURL(node,value)
  SourceDocument.seed(node,node.OwnerDocument or options.Document)
  local context=node.MediaSourceDocument;local original=context and context.Document[1]
  local base=context and context.Base or sourceBase(node)
  if original then
   local origin=bridge.OwnerBridge(original)
   if origin and origin.Alive then
    local live=origin.NativeRead(original,"baseURI")
    if type(live)=="string"then base=live;SourceDocument.observe(original,live)end
   end
  end
  base=Strings.usv(base)
		if base:match("^[%a][%w+%.%-]*:")or value:match("^[%a][%w+%.%-]*:")then
			local ok,address=pcall(URLRecord.resolve,Strings.usv(value),if base:match("^[%a][%w+%.%-]*:")then base else nil,WorkContext.checkpoint)
			return if ok then address else nil
		end
		return DocumentInfo.resolveURL(base,value)
	end
	local function fail(name,message)VM.throw(VM.error(name,message))end
	local function text(value)local primitive=vm.ToPrimitive(value,"string");if type(primitive)=="table"and primitive.Kind=="symbol"then fail("TypeError","Cannot convert Symbol to DOMString")end;return VM.string(primitive)end
	local function number(value)local n=VM.number(vm.ToPrimitive(value,"number"));if n~=n or math.abs(n)==math.huge then fail("TypeError","Media values must be finite")end;return n end
	local function native(name,length,fn)return {Kind="native-function",VMOwner=vm,Prototype=vm.Prototypes.Function,Values={name=name,length=length},Call=function(args,self)assert(api.Alive and vm.Alive,"Audio realm disposed");return fn(args,self)end}end
	local function define(target,key,desc)vm.DefineProperty(target,key,vm.Object(desc,N))end
	local function errorValue(name,message)return options.Events:DOMException(message,name)end
 origin.QueueTask=options.QueueTask;owner.QueueProgress=options.QueueTask;owner.QueueStable=options.QueueMicrotask;owner.Resolve=selectedURL;owner.GetViewport=options.GetViewport
 owner.Dispatch=function(node,kind)if options.EmitEvent then options.EmitEvent(node,kind)else options.Events:Dispatch(options.TargetFor(node),options.Events:NewEvent(kind,{},"Event"),true)end end
 owner.Changed=function(pending)api.Pending=pending;if options.LoadStateChanged then options.LoadStateChanged()end end
 origin.Factory=options.CreatePromise
 origin.Create=function()
  origin.Serial+=1;local token=origin.Serial;local factory=origin.Factory
  local promise,resolve,reject=factory()
  if not origin.Alive or origin.Factory~=factory then return nil,nil end
  origin.Capabilities[token]={Resolve=resolve,Reject=reject};return promise,token
 end
 origin.Drop=function(tokens)for _,token in tokens do origin.Capabilities[token]=nil end end
 origin.Settle=function(tokens,name,message)for _,token in tokens do local capability=origin.Capabilities[token];origin.Capabilities[token]=nil;if capability then if name then capability.Reject({errorValue(name,message)})else capability.Resolve({U})end end end end
	local mediaErrorProto=vm.Object({})
	local mediaErrorCtor=native("MediaError",0,function()fail("TypeError","Illegal MediaError constructor")end)
	define(mediaErrorCtor,"prototype",{value=mediaErrorProto});define(mediaErrorProto,"constructor",{value=mediaErrorCtor,writable=true,configurable=true})
	define(mediaErrorProto,vm.SymbolToStringTag,{value="MediaError",configurable=true})
	local errorCache=setmetatable({},{__mode="k"})
	for key,length in {code=0,message=0}do define(mediaErrorProto,key,{get=native("get "..key,length,function(_,self)local state=type(self)=="table"and self.AudioErrorData;if not state or state.Brand~=AudioState.ErrorBrand then fail("TypeError","Illegal MediaError receiver")end;return state[key]end),enumerable=true,configurable=true})end
	for key,value in {MEDIA_ERR_ABORTED=1,MEDIA_ERR_NETWORK=2,MEDIA_ERR_DECODE=3,MEDIA_ERR_SRC_NOT_SUPPORTED=4}do define(mediaErrorCtor,key,{value=value,enumerable=true});define(mediaErrorProto,key,{value=value,enumerable=true})end
	globals.MediaError=mediaErrorCtor;vm.Global.Bindings.MediaError={Value=mediaErrorCtor}
	origin.MaterializeError=function(controller,data)
  local cached=errorCache[controller];if cached and cached.Version==data.Version then return cached.Value end
  local value=vm.Object({},mediaErrorProto);value.AudioErrorData={Brand=AudioState.ErrorBrand,code=data.Code,message=data.Message};errorCache[controller]={Value=value,Version=data.Version};return value
 end
	local rangeProto=vm.Object({})
	local rangeCtor=native("TimeRanges",0,function()fail("TypeError","Illegal TimeRanges constructor")end)
	define(rangeCtor,"prototype",{value=rangeProto});define(rangeProto,"constructor",{value=rangeCtor,writable=true,configurable=true});define(rangeProto,vm.SymbolToStringTag,{value="TimeRanges",configurable=true})
	define(rangeProto,"length",{get=native("get length",0,function(_,self)local state=type(self)=="table"and self.AudioRangeData;if not state or state.Brand~=AudioState.RangeBrand then fail("TypeError","Illegal TimeRanges receiver")end;return #state.Spans end),enumerable=true,configurable=true})
	for key,part in {start=1,["end"]=2}do define(rangeProto,key,{value=native(key,1,function(args,self)
		local data=type(self)=="table"and self.AudioRangeData;if not data or data.Brand~=AudioState.RangeBrand then fail("TypeError","Illegal TimeRanges receiver")end;local state=data.Spans
		if args[1]==nil then fail("TypeError","TimeRanges index is required")end
		local index=VM.number(vm.ToPrimitive(args[1],"number"));if index~=index or math.abs(index)==math.huge then index=0 end
		index=(if index<0 then math.ceil(index)else math.floor(index))%4294967296
		local span=state[index+1];if not span then VM.throw(errorValue("IndexSizeError","TimeRanges index is outside the range"))end;return span[part]
	end),writable=true,enumerable=true,configurable=true})end
	globals.TimeRanges=rangeCtor;vm.Global.Bindings.TimeRanges={Value=rangeCtor}
	origin.MaterializeRange=function(spans)local result=vm.Object({},rangeProto);result.AudioRangeData={Brand=AudioState.RangeBrand,Spans=spans};return result end
 local video=VideoElements.install(vm,{Origin=origin,Adapter=options.VideoAdapter,Events=options.Events,Streams=options.Streams})
 local function make(node)
  local controller=node.AudioController
  if not controller then
   local original=bridge.OriginBridge(node);local facade=original and original.Alive and original.Host.AudioElements
   controller=AudioState.new(node,if facade then facade.OriginLease else origin,owner,N)
  end
  local r=controller.State;records[node]=r;return r
 end
 api.Ensure=make
 local function load(r,force,selectEmpty)return r.Controller:Load(force,selectEmpty)end
 local function play(r)
  local lease=r.OriginLease
  if not lease.Alive or not lease.Create then local promise,_,reject=options.CreatePromise();reject({errorValue("InvalidStateError","The original audio realm was disposed")});return promise end
  local promise,token=lease.Create()
  if not token then local value,_,reject=options.CreatePromise();reject({errorValue("InvalidStateError","The original audio factory was disposed")});return value end
  r.Controller:Play(token);return promise
 end
 local function pause(r,internal)r.Controller:Pause(internal);return U end
	local reflected={src="src",preload="preload",crossOrigin="crossorigin",loading="loading"};local booleans={autoplay="autoplay",loop="loop",controls="controls",defaultMuted="muted"}
	local readonly={currentSrc=true,duration=true,paused=true,ended=true,seeking=true,readyState=true,networkState=true,error=true,buffered=true,seekable=true,played=true}
	function api:Get(node,key)
		if not media(node)then return nil end
		if key=='srcObject'then return if audio(node)then N else video:Get(node,key)end
		if not audio(node)then
		 if not(reflected[key]or booleans[key]or readonly[key]or key=="muted"or key=="volume"or key=="currentTime"or key=="playbackRate"or key=="defaultPlaybackRate"or key=="play"or key=="pause"or key=="load"or key=="fastSeek"or key=="canPlayType")then return nil end
		 video.Ensure(node);if not(reflected[key]or booleans[key])then return video:Get(node,key)end
		end
		local r=if audio(node)then make(node)else nil
		if reflected[key]then
			local value=node.Attributes[reflected[key]]
			if key=="src"then return if value~=nil then Strings.usv(resolveSource(node,value))else ""end
			if key=="loading"then return if value and value:lower()=="lazy"then"lazy"else"eager"end
			if key=="crossOrigin"then return if value==nil then N elseif value:lower()=="use-credentials"then"use-credentials"else"anonymous"end
			return if key=="preload"then preload(node)else value or""
		end
		if booleans[key]then return node.Attributes[booleans[key]]~=nil end
  if key=="error"then
   local data=r.Error;if data==r.NoError then return N end
   if not r.OriginLease.Alive or not r.OriginLease.MaterializeError then VM.throw(errorValue("InvalidStateError","The original audio realm was disposed"))end
   return r.OriginLease.MaterializeError(r.Controller,data)
  end
  if key=="buffered"or key=="seekable"or key=="played"then
   if not r.OriginLease.Alive or not r.OriginLease.MaterializeRange then VM.throw(errorValue("InvalidStateError","The original audio realm was disposed"))end
   return r.OriginLease.MaterializeRange(r.Controller:GetData(key))
  end
  local data=r.Controller:GetData(key);if data~=nil then return data end
		if key=="play"then return function()return play(r)end elseif key=="load"then return function()load(r,true);return U end
		elseif key=="pause"then return function()return pause(r)end elseif key=="fastSeek"then return function(args)if args[1]==nil then fail("TypeError","fastSeek requires a time")end;api:Set(node,"currentTime",args[1]);return U end
		elseif key=="canPlayType"then return function(args)if args[1]==nil then fail("TypeError","canPlayType requires a media type")end;local value=text(args[1]);local adapter=r.OwnerLease.Adapter;return if adapter and adapter.CanPlayType then adapter:CanPlayType(value)else ""end end
		return nil
	end
	function api:Set(node,key,value,strict)
		if not media(node)then return false end
		if key=='srcObject'then
		 if value==U then value=N end
		 if not audio(node)then return video:Set(node,key,value)end
		 if value~=N then if not options.Streams or not options.Streams:Resolve(value)then fail('TypeError','srcObject requires a MediaStream or null')end;VM.throw(errorValue('NotSupportedError','Live stream playback is supported by video elements only'))end
		 return true
		end
		if not audio(node)then
		 if not(reflected[key]or booleans[key]or readonly[key]or key=="muted"or key=="volume"or key=="currentTime"or key=="playbackRate"or key=="defaultPlaybackRate")then return false end
		 video.Ensure(node)
		 if readonly[key]then if strict~=false then fail("TypeError","Read-only media property")end;return true end
		 if not(reflected[key]or booleans[key])then return video:Set(node,key,value)end
		end
		local r=if audio(node)then make(node)else nil
		if readonly[key]then if strict~=false then fail("TypeError","Read-only media property")end;return true end
		if reflected[key]then bridge.Attribute(node,reflected[key],if key=="crossOrigin"and(value==N or value==U)then nil elseif key=="src"then Strings.usv(text(value))else text(value));return true end
		if booleans[key]then bridge.Attribute(node,booleans[key],if VM.truth(value)then""else nil);return true end
  if key=="muted"or key=="volume"or key=="playbackRate"or key=="defaultPlaybackRate"or key=="currentTime"then
   local converted=if key=="muted"then VM.truth(value)else number(value)
   local problem=r.Controller:SetData(key,converted);if problem then VM.throw(errorValue(problem.Name,problem.Message))end;return true
  end
		return false
	end
	function api:Visit(root)
		local pending={root};while #pending>0 do local node=table.remove(pending);if audio(node)then load(make(node),false)end;if not ElementNames.html(node,"template")then for _,child in node.Children do table.insert(pending,child)end;if node.InternalShadowRoot then table.insert(pending,node.InternalShadowRoot)end end end
	end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  local hadError=false;local firstError
  local videoOK,videoError=pcall(video.Destroy,video);if not videoOK then hadError=true;firstError=videoError end
  for _,r in origin.States do r.Controller:ReleaseOriginRealm(origin)end
  origin.Alive=false
  table.clear(origin.Capabilities);table.clear(errorCache)
  for entry in origin.Slots do entry.State=nil;entry.Action=nil end;table.clear(origin.Slots)
  origin.QueueTask=nil;origin.Create=nil;origin.Factory=nil;origin.Drop=nil;origin.Settle=nil;origin.MaterializeError=nil;origin.MaterializeRange=nil;origin.Pool=nil;table.clear(origin.States)
  for _,r in owner.States do local ok,message=pcall(r.Controller.StopOwner,r.Controller,owner);if not ok and not hadError then hadError=true;firstError=message end end
  owner.Alive=false
  for entry in owner.Slots do entry.State=nil;entry.Action=nil end;table.clear(owner.Slots)
  local adapter=owner.Adapter;owner.Adapter=nil;owner.Document=nil;owner.Resolve=nil;owner.GetViewport=nil;owner.QueueStable=nil;owner.QueueProgress=nil;owner.Dispatch=nil;owner.Changed=nil
  table.clear(owner.States);table.clear(active);table.clear(pendingRemoved);table.clear(records);self.Pending=0
  if adapter then local ok,message=pcall(function()local destroy=adapter.Destroy;if destroy then destroy(adapter)end end);if not ok and not hadError then hadError=true;firstError=message end end
  if hadError then error(firstError,0)end
 end
 function api:Adopted(node,destination)
  if not audio(node)or not destination or not destination.Alive then return end
  local controller=node.AudioController
  if controller then controller:ChangeOwner(destination.OwnerLease)end
 end
	function api:AfterCheckpoint()
		if not self.Alive or not next(pendingRemoved)then return end
		local removed=table.clone(pendingRemoved);table.clear(pendingRemoved);removalWake=false
		for r in removed do
			if r.OwnerLease==owner and owner.States[r.Node]==r and not ShadowTree.Connected(r.Node,r.Node.OwnerDocument)then pause(r,true)end
		end
	end
	local oldGet,oldSet,oldAttr,oldInsert,oldMutation,oldBeforeRemove,oldBeforeInsert=host.ElementGet,host.ElementSet,host.AttributeChanged,host.PostInsert,host.Mutation,host.BeforeRemove,host.BeforeInsert
	host.ElementGet=function(node,key)local value=api:Get(node,key);return if value~=nil then value elseif oldGet then oldGet(node,key)else nil end
	host.ElementSet=function(node,key,value,strict)return api:Set(node,key,value,strict)or oldSet and oldSet(node,key,value,strict)==true end
	host.AttributeChanged=function(node,key,value,old,namespace,...)
		-- src removal retains the selected resource; even an identical write
		-- invokes a new selection. Explicit load still reads the current DOM.
		if audio(node)and not namespace then make(node).Controller:Attribute(key,value)end
		if oldAttr then oldAttr(node,key,value,old,namespace,...)end
	end
	host.PostInsert=function(additions)for _,node in additions do api:Visit(node)end;if oldInsert then oldInsert(additions)end end
	host.BeforeRemove=function(node,preservingMove)
		local parent=node.Parent;local controller=parent and parent.AudioController;if controller then controller:BeforeRemove(node)end
		if not preservingMove and ShadowTree.Connected(node)then
			for _,r in owner.States do if ShadowTree.InclusiveDescendant(r.Node,node)then pendingRemoved[r]=true end end
			-- Stable-state removal checks run after the whole checkpoint, so
			-- synchronous or nested microtask reinsertion keeps playback intact.
			if next(pendingRemoved)and not removalWake then removalWake=true;options.QueueMicrotask(function()end)end
		end
		if oldBeforeRemove then oldBeforeRemove(node,preservingMove)end
	end
	host.BeforeInsert=function(parent,index,count)
		local controller=parent.AudioController;if controller then controller:BeforeInsert(index,count)end
		if oldBeforeInsert then oldBeforeInsert(parent,index,count)end
	end
	host.Mutation=function(record)
		if record.Type=="childList"then
			if audio(record.Target)and record.Target.Attributes.src==nil then
				local r=make(record.Target)
				if r.Controller:ResumeWaiting()then
				elseif r.Network==0 then for _,node in record.AddedNodes or{}do
					if ElementNames.html(node,"source")then load(r,false);break end
				end end
			end
			-- Removing a loading element releases the document-load gate, but
			-- its resource survives the stable-state pause.
			for r in active do r.Controller:Changed()end
		end
		if oldMutation then oldMutation(record)end
	end
	local proto=vm.Get(globals.HTMLMediaElement,"prototype")
	local function receiver(self)local node=bridge.Unwrap(self);if not audio(node)then fail("TypeError","The audio API requires an HTMLAudioElement receiver")end;return node end
	local function mediaReceiver(self)local node=bridge.Unwrap(self);if not media(node)then fail("TypeError","The reflected media API requires an HTMLMediaElement receiver")end;return node end
	define(proto,'srcObject',{get=native('get srcObject',0,function(_,self)return api:Get(mediaReceiver(self),'srcObject')end),set=native('set srcObject',1,function(args,self)api:Set(mediaReceiver(self),'srcObject',if args[1]==nil then U else args[1],true);return U end),enumerable=true,configurable=true})
	for key in readonly do define(proto,key,{get=native("get "..key,0,function(_,self)return api:Get(mediaReceiver(self),key)end),enumerable=true,configurable=true})end
	for _,key in {"src","preload","crossOrigin","loading","autoplay","loop","controls","defaultMuted"}do define(proto,key,{get=native("get "..key,0,function(_,self)return api:Get(mediaReceiver(self),key)end),set=native("set "..key,1,function(args,self)
		local node=mediaReceiver(self)
		api:Set(node,key,if args[1]==nil then U else args[1],true);return U
	end),enumerable=true,configurable=true})end
	for _,key in {"muted","volume","currentTime","playbackRate","defaultPlaybackRate"}do define(proto,key,{get=native("get "..key,0,function(_,self)return api:Get(mediaReceiver(self),key)end),set=native("set "..key,1,function(args,self)api:Set(mediaReceiver(self),key,if args[1]==nil then U else args[1],true);return U end),enumerable=true,configurable=true})end
	for key,length in {play=0,pause=0,load=0,fastSeek=1,canPlayType=1}do define(proto,key,{value=native(key,length,function(args,self)if key=="play"then
  local ok,node=pcall(mediaReceiver,self)
  if not ok then local promise,_,reject=options.CreatePromise();reject({VM.exceptionValue(node)});return promise end
  if not audio(node)then return video:Get(node,"play")(args,self)end
  return play(make(node))
 end
 return api:Get(mediaReceiver(self),key)(args,self)end),writable=true,enumerable=true,configurable=true})end
	for key,value in {NETWORK_EMPTY=0,NETWORK_IDLE=1,NETWORK_LOADING=2,NETWORK_NO_SOURCE=3,HAVE_NOTHING=0,HAVE_METADATA=1,HAVE_CURRENT_DATA=2,HAVE_FUTURE_DATA=3,HAVE_ENOUGH_DATA=4}do define(globals.HTMLMediaElement,key,{value=value,enumerable=true});define(proto,key,{value=value,enumerable=true})end
	local factory=native("Audio",0,function(args)local value=bridge.Document.Get("createElement")({"audio"});local node=bridge.Unwrap(value);bridge.Attribute(node,"preload","auto");make(node);if args[1]~=nil and args[1]~=U then bridge.Attribute(node,"src",text(args[1]))end;return value end)
	factory.Construct=function(args)return factory.Call(args)end;define(factory,"prototype",{value=vm.Get(globals.HTMLAudioElement,"prototype")});globals.Audio=factory;vm.Global.Bindings.Audio={Value=factory}
	api:Visit(options.Document);return api
end
return AudioElements
