--!strict
-- Dedicated-worker boundary only. The host must load source and supply an
-- isolated, independently scheduled VM. Never evaluate worker JS on this VM.
local WorkerAdapter={}
function WorkerAdapter.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local host,clone,messaging=options.HostEvents,options.Clone,options.Messaging
 local api={Alive=true};local workers=setmetatable({},{__mode="kv"});local owned={};local workerCount=0
 local queueLimit=options.MaxQueueBytes or 4194304
 local URL=vm.Global.Bindings.URL and vm.Global.Bindings.URL.Value
 local workerProto=vm.Object({},vm.Get(globals.EventTarget,"prototype"));local errorProto=vm.Object({},vm.Get(globals.Event,"prototype"));local errors=setmetatable({},{__mode="kv"})
 local function check()assert(api.Alive and vm.Alive,"JavaScript workers disposed")end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function field(value,key)return if value==nil or value==U or value==N then U else vm.Get(value,key)end
 local function typeError(message)VM.throw(VM.error("TypeError",message))end
 local function fail(name,message)VM.throw(host:DOMException(message,name))end
 local function text(value)if vm.ToPrimitive then value=vm.ToPrimitive(value,"string")end;if type(value)=="table"and value.Kind=="symbol"then typeError("Cannot convert a Symbol to a worker string")end;return VM.string(value)end
 local function def(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,VM.Null))end
 local function native(name,n,fn)return {Kind="native-function",Values={name=name,length=n},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end}end
 local function accessor(proto,key,get,set)def(proto,key,{get=native("get "..key,0,function(_,receiver)return get(receiver)end),set=if set then native("set "..key,1,function(args,receiver)set(receiver,arg(args,1));return U end)else U,enumerable=true,configurable=true})end
 local function method(proto,key,n,callback)def(proto,key,{value=native(key,n,callback),writable=true,enumerable=true,configurable=true})end
 local function construct(name,n,proto,callback)
  local value=native(name,n,function()typeError(name.." requires new")end);value.Construct=function(args)check();return callback(args)end
  def(value,"prototype",{value=proto});def(proto,"constructor",{value=value,writable=true,configurable=true});def(proto,vm.SymbolToStringTag,{value=name,configurable=true})
  globals[name]=value;vm.Global.Bindings[name]={Value=value};return value
 end
 local function unsigned(value)local n=VM.number(value);return if n~=n or math.abs(n)==math.huge then 0 else math.floor(math.abs(n))*(if n<0 then -1 else 1)%4294967296 end
 function api:NewErrorEvent(typeName,init)
  local value=host:NewEvent(typeName,{bubbles=init.bubbles,cancelable=init.cancelable,composed=init.composed},"ErrorEvent");value.Prototype=errorProto
  local state={Message=init.message or "",Filename=init.filename or "",Lineno=init.lineno or 0,Colno=init.colno or 0,Error=if init.error==nil then U else init.error};value.MessageState=state;errors[value]=state;return value
 end
 for name,key in {message="Message",filename="Filename",lineno="Lineno",colno="Colno",error="Error"}do accessor(errorProto,name,function(value)local state=errors[value];if not state then typeError("ErrorEvent."..name.." requires an ErrorEvent")end;return state[key]end)end
 construct("ErrorEvent",1,errorProto,function(args)
  if #args<1 then typeError("ErrorEvent requires a type")end;local typeName=text(args[1]);local init=arg(args,2);local converted={}
  for _,key in {"bubbles","cancelable","colno","composed","error","filename","lineno","message"}do local value=field(init,key)
   if key=="bubbles"or key=="cancelable"or key=="composed"then converted[key]=VM.truth(value)
   elseif key=="lineno"or key=="colno"then converted[key]=if value==U then 0 else unsigned(value)
   elseif key=="error"then converted[key]=value
   else converted[key]=if value==U then ""else text(value)end
  end;return api:NewErrorEvent(typeName,converted)
 end)
 vm.SetPrototype(globals.ErrorEvent,globals.Event)
 local function report(message)if options.Report then options.Report(message)end end
 local function enqueue(callback)options.EnqueueTask(function()if api.Alive then callback()end end)end
 local function terminate(state)
  if state.Closed then return end;state.Closed=true;owned[state]=nil;workerCount-=1
  local cancel,handle=state.Cancel,state.Handle;state.Cancel,state.Handle=nil,nil
  for _,wire in state.Queue do clone:Discard(wire)end;state.Queue={};state.QueueBytes=0
  for wire in state.Incoming do clone:Discard(wire)end;table.clear(state.Incoming);state.IncomingBytes,state.IncomingCount=0,0
  if cancel then pcall(cancel)end
  if handle then pcall(handle.Terminate)end
 end
 local function workerError(state,details,fatal)
  if state.Closed then return end
  if type(details)~="table"then details={message=tostring(details)}end
  local event=api:NewErrorEvent("error",{cancelable=true,message=details.message or "Worker failed",filename=details.filename or state.Spec.url,lineno=details.lineno or 0,colno=details.colno or 0})
  if host:Dispatch(state.Target,event,true)then report(details.message or "Worker failed")end
  if fatal then terminate(state)end
 end
 local function send(state,wire)
  local ok,message=pcall(state.Handle.PostMessage,wire)
  if not ok then clone:Discard(wire);enqueue(function()workerError(state,{message=tostring(message)},true)end)end
 end
 local function prepareTransfer(value)
  if value==U or value==N then return U end
  if not VM.callable(vm.Get(value,vm.SymbolIterator))then value=vm.Get(value,"transfer");if value==U then return U end end
  local nextValue,close=vm.Iterator(value);local list={};local ok,message=pcall(function()
   while true do local more,item=nextValue();if not more then break end
    if #list>=1024 then fail("DataCloneError","Worker transfer list budget exceeded")end
    if messaging:IsPort(item)and not options.SupportsPortTransfer then fail("DataCloneError","The worker host cannot transfer MessagePort handles")end
    table.insert(list,item)
   end
  end);if not ok then if close then pcall(close)end;error(message,0)end;return vm.Array(list)
 end
 local function start(state)
  if state.Closed then return end
  local completed=false
  local function loaded(ok,source)
   if completed or state.Closed or not api.Alive then return end;completed=true
   if ok and type(source)=="table" then source=source.Source end
   enqueue(function()
    if state.Closed then return end;state.Cancel=nil
    if not ok or type(source)~="string"then workerError(state,{message=if type(source)=="string"then source else "Worker script could not be loaded"},true);return end
    if #source>(options.MaxScriptBytes or 1048576)then workerError(state,{message="Worker script byte budget exceeded"},true);return end
    local launchSpec=table.clone(state.Spec);launchSpec.source=source
    local callbacks={}
    callbacks.Message=function(wire)
     if state.Closed or state.Overflow or not api.Alive then clone:Discard(wire);return end
     local size=wire.ByteLength or 0
     if state.IncomingCount>=1024 or state.IncomingBytes+size>queueLimit then state.Overflow=true;clone:Discard(wire);enqueue(function()workerError(state,{message="Worker incoming queue budget exceeded"},true)end);return end
     state.Incoming[wire]=true;state.IncomingBytes+=size;state.IncomingCount+=1
     enqueue(function()
      if state.Closed then return end
      state.Incoming[wire]=nil;state.IncomingBytes-=size;state.IncomingCount-=1
      local succeeded,data,ports=pcall(function()return clone:Deserialize(wire)end)
      if not succeeded then clone:Discard(wire)end
      host:Dispatch(state.Target,messaging:NewMessageEvent(if succeeded then "message"else "messageerror",{data=if succeeded then data else N,ports=if succeeded then ports else {}}),true)
     end)
    end
    callbacks.Error=function(details)enqueue(function()workerError(state,details,false)end)end
    callbacks.Exit=function()enqueue(function()terminate(state)end)end
    local spawned,handle=pcall(options.SpawnWorker,launchSpec,callbacks)
    if not spawned or type(handle)~="table"or type(handle.PostMessage)~="function"or type(handle.Terminate)~="function"then
     if type(handle)=="table"and type(handle.Terminate)=="function"then pcall(handle.Terminate)end
     workerError(state,{message=if spawned then "Worker scheduler returned an invalid handle"else tostring(handle)},true);return
    end
    if state.Closed or not api.Alive then pcall(handle.Terminate);return end
    state.Handle=handle;local queue=state.Queue;state.Queue={};state.QueueBytes=0
    for _,wire in queue do if state.Closed then clone:Discard(wire)else send(state,wire)end end
   end)
  end
  local ok,cancel=pcall(options.LoadScript,state.Spec.url,loaded)
  if not ok then loaded(false,tostring(cancel))
  elseif type(cancel)=="function"then if state.Closed then pcall(cancel)elseif not completed then state.Cancel=cancel end end
 end
 construct("Worker",1,workerProto,function(args)
  if #args<1 then typeError("Worker requires a script URL")end
  local scriptURL=text(args[1]);local init=arg(args,2)
  local credentials=field(init,"credentials");credentials=if credentials==U then "same-origin"else text(credentials)
  local name=field(init,"name");name=if name==U then ""else text(name)
  local typeName=field(init,"type");typeName=if typeName==U then "classic"else text(typeName)
  if credentials~="omit"and credentials~="same-origin"and credentials~="include"then typeError("Invalid worker credentials")end
  if typeName~="classic"and typeName~="module"then typeError("Invalid worker type")end
  if typeName~="classic" and not options.SupportsModuleWorkers then fail("NotSupportedError","Module workers need an independent module-loader adapter")end
  local ok,url=pcall(function()return vm:Construct(URL,{scriptURL,options.BaseURL or "about:blank"})end)
  if not ok then fail("SyntaxError","Invalid worker script URL")end
  local protocol,origin=vm.Get(url,"protocol"),vm.Get(url,"origin")
  if protocol~="http:"and protocol~="https:"then fail("NotSupportedError","The worker loader currently accepts HTTP(S) script URLs")end
  if origin~=(options.Origin or "null")then fail("SecurityError","Worker script must have the document's origin")end
  if type(options.LoadScript)~="function"or type(options.SpawnWorker)~="function"then fail("NotSupportedError","Workers require a script loader and an isolated background scheduler")end
  if workerCount>=32 then fail("QuotaExceededError","Worker count budget exceeded")end
  local value=vm.Object({},workerProto);local state={Target=value,Closed=false,Queue={},QueueBytes=0,Incoming={},IncomingBytes=0,IncomingCount=0,Spec={url=vm.Get(url,"href"),name=name,type=typeName,credentials=credentials}}
  value.MessageState=state;workers[value]=state;owned[state]=true;workerCount+=1
  host:WrapTarget(value,{Standalone=true,Parent=function()return nil end});enqueue(function()start(state)end);return value
 end)
 vm.SetPrototype(globals.Worker,globals.EventTarget)
 local function worker(value)local state=workers[value];if not state then typeError("Worker method requires a Worker")end;return state end
 for _,key in {"onmessage","onmessageerror","onerror"}do accessor(workerProto,key,function(value)worker(value);return host:HandlerGet(value,key)end,function(value,callback)worker(value);host:HandlerSet(value,key,callback)end)end
 method(workerProto,"terminate",0,function(_,value)terminate(worker(value));return U end)
 method(workerProto,"postMessage",1,function(args,value)
  if #args<1 then typeError("Worker.postMessage requires a message")end;local state=worker(value)
  if #state.Queue>=1024 then fail("QuotaExceededError","Worker outgoing queue budget exceeded")end
  local wire=clone:Serialize(args[1],prepareTransfer(arg(args,2)),queueLimit-state.QueueBytes)
  if state.Closed then clone:Discard(wire)
  elseif state.Handle then send(state,wire)
  else table.insert(state.Queue,wire);state.QueueBytes+=wire.ByteLength end;return U
 end)
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  for state in owned do terminate(state)end;table.clear(owned);table.clear(workers);table.clear(errors)
 end
 return api
end
return WorkerAdapter
