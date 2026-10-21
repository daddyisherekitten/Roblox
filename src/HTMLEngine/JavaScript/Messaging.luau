--!strict
-- Realm-owned message endpoints. Delivery is task-queued; no polling/frames.
local Messaging={}
local broadcasts={}
function Messaging.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local host,clone=options.HostEvents,options.Clone
 local api={Alive=true,VM=vm,Clone=clone,Origin=options.Origin or "null"}
 local ports,channels,messages,broadcastStates=setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"})
 local ownedEndpoints,ownedBroadcasts={},{};local endpointCount,broadcastCount=0,0
 local urlConstructor=vm.Global.Bindings.URL and vm.Global.Bindings.URL.Value
 local queueLimit=options.MaxQueueBytes or 4194304
 local windowWires={};local windowBytes,windowCount=0,0
 local portProto,channelProto,messageProto,broadcastProto=vm.Object({},vm.Get(globals.EventTarget,"prototype")),vm.Object({}),vm.Object({},vm.Get(globals.Event,"prototype")),vm.Object({},vm.Get(globals.EventTarget,"prototype"))
 local schedule,makePort,closePort
 local function check()assert(api.Alive and vm.Alive,"JavaScript messaging disposed")end
 local function fail(name,message)VM.throw(host:DOMException(message,name))end
 local function typeError(message)VM.throw(VM.error("TypeError",message))end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function text(value)if vm.ToPrimitive then value=vm.ToPrimitive(value,"string")end;if type(value)=="table"and value.Kind=="symbol"then typeError("Cannot convert a Symbol to a message string")end;return VM.string(value)end
 local function field(value,key)return if value==U or value==N or value==nil then U else vm.Get(value,key)end
 local function def(target,key,desc)vm.DefineProperty(target,key,vm.Object(desc,VM.Null))end
 local function native(name,n,fn)local value={Kind="native-function",Values={name=name,length=n},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end};return value end
 local function method(proto,name,n,fn)def(proto,name,{value=native(name,n,fn),writable=true,enumerable=true,configurable=true})end
 local function accessor(proto,name,read,write)def(proto,name,{get=native("get "..name,0,function(_,receiver)return read(receiver)end),set=if write then native("set "..name,1,function(args,receiver)write(receiver,arg(args,1));return U end)else U,enumerable=true,configurable=true})end
 local function brand(map,value,name)local state=map[value];if not state then typeError(name.." requires a compatible receiver")end;return state end
 local function constructor(name,n,proto,create)local value=native(name,n,function()typeError(name.." requires new")end);value.Construct=function(args)check();return create(args)end;def(value,"prototype",{value=proto});def(proto,"constructor",{value=value,writable=true,configurable=true});def(proto,vm.SymbolToStringTag,{value=name,configurable=true});globals[name]=value;vm.Global.Bindings[name]={Value=value};return value end
 local function frozenPorts(list)
  local value=vm.Array(table.clone(list));for i=0,#list-1 do def(value,tostring(i),{writable=false,configurable=false})end;def(value,"length",{writable=false});vm.PreventExtensions(value);return value
 end
 function api:NewMessageEvent(typeName,init)
  local value=host:NewEvent(typeName,{bubbles=init.bubbles,cancelable=init.cancelable,composed=init.composed});value.Prototype=messageProto
  local state={Data=if init.data==nil then N else init.data,Origin=init.origin or "",LastEventId=init.lastEventId or "",Source=init.source or N,Ports=frozenPorts(init.ports or {})};value.MessageState=state;messages[value]=state;return value
 end
 for name,key in {data="Data",origin="Origin",lastEventId="LastEventId",source="Source",ports="Ports"}do accessor(messageProto,name,function(receiver)return brand(messages,receiver,"MessageEvent."..name)[key]end)end
 local function portList(value)
  local list={};if value==U then return list end
  local nextValue,close=vm.Iterator(value);local ok,message=pcall(function()while true do local more,item=nextValue();if not more then break end;if not ports[item]then typeError("MessageEvent ports must contain MessagePorts")end;if #list>=1024 then fail("DataCloneError","Message port list budget exceeded")end;table.insert(list,item)end end)
  if not ok then if close then pcall(close)end;error(message,0)end;return list
 end
 constructor("MessageEvent",1,messageProto,function(args)
  if #args<1 then typeError("MessageEvent requires a type")end;local typeName=text(args[1]);local init=arg(args,2)
  local converted={}
  for _,key in {"bubbles","cancelable","composed","data","lastEventId","origin","ports","source"}do
   local value=field(init,key)
   if key=="bubbles"or key=="cancelable"or key=="composed"then converted[key]=VM.truth(value)
   elseif key=="lastEventId"or key=="origin"then converted[key]=if value==U then ""else text(value)
   elseif key=="ports"then converted[key]=portList(value)
   else converted[key]=if value==U then N else value end
  end
  local source=converted.source
  if source~=U and source~=N and source~=globals.window and not ports[source]then typeError("MessageEvent source must be Window, MessagePort or null")end
  return api:NewMessageEvent(typeName,converted)
 end)
 vm.SetPrototype(globals.MessageEvent,globals.Event)
 local function handlers(proto,onMessage)
  for _,key in {"onmessage","onmessageerror"}do accessor(proto,key,function(value)return host:HandlerGet(value,key)end,function(value,callback)host:HandlerSet(value,key,callback);if key=="onmessage"and VM.callable(callback)and onMessage then onMessage(value)end end)end
 end
 local function endpoint(value)local state=brand(ports,value,"MessagePort");return state.Endpoint end
 local function start(value)local ep=endpoint(value);if ep and not ep.Closed then ep.Started=true;schedule(ep)end end
 makePort=function(ep)
  local value=vm.Object({},portProto);local state={Endpoint=ep};value.MessageState=state;ports[value]=state
  host:WrapTarget(value,{Standalone=true,Parent=function()return nil end})
  ep.Owner,ep.Port=api,value;if not ep.Closed then ownedEndpoints[ep]=true;endpointCount+=1 end
  return value
 end
 closePort=function(ep)
  if ep.Closed then return end;ep.Closed=true;local queue=ep.Queue;ep.Queue={};ep.QueueBytes=0;ep.Started=false
  for _,wire in queue do clone:Discard(wire)end
  if ep.Peer then ep.Peer.Peer=nil;ep.Peer=nil end
  if ep.Owner then ep.Owner:ReleaseEndpoint(ep)end
 end
 function api:ReleaseEndpoint(ep)if ownedEndpoints[ep]then ownedEndpoints[ep]=nil;endpointCount-=1 end end
 function api:DeliverPort(ep,wire)
  if not api.Alive or ep.Closed or ep.Owner~=api then return end
  local ok,data,eventPorts=pcall(function()return clone:Deserialize(wire)end)
  host:Dispatch(ep.Port,api:NewMessageEvent(if ok then "message"else "messageerror",{data=if ok then data else N,ports=if ok then eventPorts else {}}),true)
 end
 schedule=function(ep)
  local owner=ep.Owner
  if not owner or not owner.Alive or ep.Closed or not ep.Started or ep.Scheduled or #ep.Queue==0 then return end
  ep.Scheduled=true;local generation=ep.Generation or 0;owner:Enqueue(function()
   if (ep.Generation or 0)~=generation then return end
   ep.Scheduled=false
   if ep.Owner~=owner then schedule(ep);return end
   if not owner.Alive or ep.Closed or not ep.Started then return end
   local item=table.remove(ep.Queue,1);if item then ep.QueueBytes=(ep.QueueBytes or 0)-(item.ByteLength or 0);owner:DeliverPort(ep,item)end;schedule(ep)
  end)
 end
 function api:Enqueue(callback)options.EnqueueTask(function()if self.Alive then callback()end end)end
 constructor("MessagePort",0,portProto,function()typeError("Illegal MessagePort constructor")end)
 handlers(portProto,start)
 method(portProto,"start",0,function(_,value)start(value);return U end)
 method(portProto,"close",0,function(_,value)local ep=endpoint(value);if ep then closePort(ep)end;return U end)
 local function transferOption(value)
  if value==U or value==N then return U end
  if VM.callable(vm.Get(value,vm.SymbolIterator))then return value end
  return vm.Get(value,"transfer")
 end
 method(portProto,"postMessage",1,function(args,value)
  if #args<1 then typeError("MessagePort.postMessage requires a message")end;local ep=endpoint(value)
  local transfer=transferOption(arg(args,2))
  if transfer~=U then local nextValue,close=vm.Iterator(transfer);local list={};local ok,message=pcall(function()while true do local more,item=nextValue();if not more then break end;if item==value then fail("DataCloneError","A port cannot transfer itself in its own message")end;if #list>=1024 then fail("DataCloneError","Transfer list budget exceeded")end;table.insert(list,item)end end);if not ok then if close then pcall(close)end;error(message,0)end;transfer=vm.Array(list)end
  if ep and ep.Peer and #ep.Peer.Queue>=1024 then fail("QuotaExceededError","MessagePort queue budget exceeded")end
  local wire=clone:Serialize(args[1],transfer,if ep and ep.Peer then queueLimit-(ep.Peer.QueueBytes or 0)else nil)
  if not ep or ep.Closed or not ep.Peer then clone:Discard(wire);return U end
  ep.Peer.QueueBytes=(ep.Peer.QueueBytes or 0)+wire.ByteLength;table.insert(ep.Peer.Queue,wire);schedule(ep.Peer);return U
 end)
 constructor("MessageChannel",0,channelProto,function()
  if endpointCount>1022 then fail("QuotaExceededError","Message channel endpoint budget exceeded")end
  local a,b={Queue={},Started=false,Closed=false},{Queue={},Started=false,Closed=false};a.Peer,b.Peer=b,a
  local value=vm.Object({},channelProto);local state={Port1=makePort(a),Port2=makePort(b)};value.MessageState=state;channels[value]=state;return value
 end)
 accessor(channelProto,"port1",function(value)return brand(channels,value,"MessageChannel.port1").Port1 end)
 accessor(channelProto,"port2",function(value)return brand(channels,value,"MessageChannel.port2").Port2 end)
 function api:IsPort(value)return ports[value]~=nil end
 function api:PrepareTransfer(value)
  local state=brand(ports,value,"MessagePort transfer");local ep=state.Endpoint
  if not ep then fail("DataCloneError","MessagePort was already transferred")end
  local token={Endpoint=ep,Received=false,Ready=false}
  return {Token=token,Validate=function()if state.Endpoint~=ep then fail("DataCloneError","MessagePort changed during serialization")end end,
   Commit=function()state.Endpoint=nil;if ep.Owner then ep.Owner:ReleaseEndpoint(ep)end;ep.Owner,ep.Port,ep.Started=nil,nil,false;ep.Generation=(ep.Generation or 0)+1;ep.Scheduled=false;token.Ready=true end}
 end
 function api:ReceiveTransfer(token)
  check();if not token.Ready or token.Received then fail("DataCloneError","MessagePort transfer cannot be received twice")end
  if endpointCount>=1024 then fail("QuotaExceededError","Message endpoint budget exceeded")end;token.Received=true
  return makePort(token.Endpoint)
 end
 function api:DiscardTransfer(token)
  if token.Ready and not token.Received then token.Received=true;closePort(token.Endpoint)end
 end
 vm.SetPrototype(globals.MessagePort,globals.EventTarget)
 clone.TransferHost=api

 local function unregisterBroadcast(state)
  if state.Closed then return end;state.Closed=true;ownedBroadcasts[state]=nil;broadcastCount-=1
  local list=broadcasts[state.Key];if list then local index=table.find(list,state);if index then table.remove(list,index)end;if #list==0 then broadcasts[state.Key]=nil end end
 end
 constructor("BroadcastChannel",1,broadcastProto,function(args)
  if #args<1 then typeError("BroadcastChannel requires a name")end
  if broadcastCount>=256 then fail("QuotaExceededError","BroadcastChannel budget exceeded")end
  local name=text(args[1]);local key=api.Origin.."\0"..name;local state={Name=name,Key=key,Owner=api,Closed=false,QueueBytes=0,QueueCount=0,QueueLimit=queueLimit};local value=vm.Object({},broadcastProto);value.MessageState=state;state.Target=value;broadcastStates[value]=state
  host:WrapTarget(value,{Standalone=true,Parent=function()return nil end});broadcasts[key]=broadcasts[key]or {};table.insert(broadcasts[key],state);ownedBroadcasts[state]=true;broadcastCount+=1;return value
 end)
 vm.SetPrototype(globals.BroadcastChannel,globals.EventTarget)
 handlers(broadcastProto)
 accessor(broadcastProto,"name",function(value)return brand(broadcastStates,value,"BroadcastChannel.name").Name end)
 method(broadcastProto,"close",0,function(_,value)unregisterBroadcast(brand(broadcastStates,value,"BroadcastChannel.close"));return U end)
 function api:DeliverBroadcast(state,wire,origin)
  if not self.Alive or state.Closed then return end
  local ok,data=pcall(function()return clone:Deserialize(wire)end)
  host:Dispatch(state.Target,api:NewMessageEvent(if ok then "message"else "messageerror",{data=if ok then data else N,origin=origin}),true)
 end
 method(broadcastProto,"postMessage",1,function(args,value)
  if #args<1 then typeError("BroadcastChannel.postMessage requires a message")end;local state=brand(broadcastStates,value,"BroadcastChannel.postMessage");if state.Closed then fail("InvalidStateError","BroadcastChannel is closed")end
  local wire=clone:Serialize(args[1]);local destinations=table.clone(broadcasts[state.Key]or {})
  for _,destination in destinations do if destination~=state and not destination.Closed and destination.Owner.Alive and(destination.QueueCount>=1024 or destination.QueueBytes+wire.ByteLength>destination.QueueLimit)then fail("QuotaExceededError","BroadcastChannel queue budget exceeded")end end
  for _,destination in destinations do if destination~=state and not destination.Closed and destination.Owner.Alive then
   destination.QueueBytes+=wire.ByteLength;destination.QueueCount+=1
   destination.Owner:Enqueue(function()destination.QueueBytes-=wire.ByteLength;destination.QueueCount-=1;destination.Owner:DeliverBroadcast(destination,wire,api.Origin)end)
  end end;return U
 end)
 if globals.window then
  local window=globals.window
  function api:ReceiveWindow(wire,origin,source,targetOrigin,getOrigin)
   if not self.Alive then clone:Discard(wire);return false end
   if windowCount>=1024 or windowBytes+wire.ByteLength>queueLimit then clone:Discard(wire);fail('QuotaExceededError','Window message queue budget exceeded')end
   windowWires[wire]=true;windowBytes+=wire.ByteLength;windowCount+=1
   api:Enqueue(function()
    windowWires[wire]=nil;windowBytes-=wire.ByteLength;windowCount-=1
    if targetOrigin~='*'and targetOrigin~=getOrigin()then clone:Discard(wire);return end
    local ok,data,eventPorts=pcall(function()return clone:Deserialize(wire)end);if not ok then clone:Discard(wire)end
    host:Dispatch(window,api:NewMessageEvent(if ok then 'message'else 'messageerror',{data=if ok then data else N,origin=origin,source=source(),ports=if ok then eventPorts else {}}),true)
   end);return true
  end
  local post=native("postMessage",1,function(args)
   if #args<1 then typeError("postMessage requires a message")end
   local targetOrigin,transfer=arg(args,2),arg(args,3)
   if type(targetOrigin)=="table"and targetOrigin~=N and targetOrigin~=U then transfer=field(targetOrigin,"transfer");targetOrigin=field(targetOrigin,"targetOrigin")end
   targetOrigin=if targetOrigin==U then "/"else text(targetOrigin)
   if targetOrigin~="*"and targetOrigin~="/"then local ok,url=pcall(function()return vm:Construct(urlConstructor,{targetOrigin})end);if not ok then fail("SyntaxError","Invalid postMessage target origin")end;targetOrigin=vm.Get(url,"origin")end
   if windowCount>=1024 then fail("QuotaExceededError","Window message queue budget exceeded")end
   local wire=clone:Serialize(args[1],transfer,queueLimit-windowBytes)
   if targetOrigin~="*"and targetOrigin~="/"and targetOrigin~=api.Origin then clone:Discard(wire);return U end
   windowWires[wire]=true;windowBytes+=wire.ByteLength;windowCount+=1
   api:Enqueue(function()
    windowWires[wire]=nil;windowBytes-=wire.ByteLength;windowCount-=1
    local ok,data,eventPorts=pcall(function()return clone:Deserialize(wire)end)
    if not ok then clone:Discard(wire)end
    host:Dispatch(window,api:NewMessageEvent(if ok then "message"else "messageerror",{data=if ok then data else N,origin=api.Origin,source=window,ports=if ok then eventPorts else {}}),true)
   end);return U
  end)
  globals.postMessage=post;vm.Global.Bindings.postMessage={Value=post};vm.Set(window,"postMessage",post)
 end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  for ep in ownedEndpoints do closePort(ep)end;table.clear(ownedEndpoints)
  for state in ownedBroadcasts do unregisterBroadcast(state)end;table.clear(ownedBroadcasts)
  for wire in windowWires do clone:Discard(wire)end;table.clear(windowWires)
  table.clear(ports);table.clear(channels);table.clear(messages);table.clear(broadcastStates);if clone.TransferHost==self then clone.TransferHost=nil end
 end
 return api
end
return Messaging
