--!strict
-- Serialized writes and demand promises, with no polling or permanent tasks.
local WritableStreams={}
function WritableStreams.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true}
 local streams,writers,controllers=setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"})
 local streamProto,writerProto,controllerProto=vm.Object({}),vm.Object({}),vm.Object({})
 local process,finishError,startError,abort
 local function check()assert(api.Alive and vm.Alive,"JavaScript writable streams disposed")end
 local function fail(message)VM.throw(VM.error("TypeError",message))end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function field(value,key)return if value==U or value==N or value==nil then U else vm.Get(value,key)end
 local function capability()
  local p,yes,no=options.CreatePromise();local cap={Promise=p,Settled=false}
  cap.Resolve=function(value)if api.Alive and not cap.Settled then cap.Settled=true;yes({value})end end
  cap.Reject=function(value)if api.Alive and not cap.Settled then cap.Settled=true;no({value})end end;return cap
 end
 local function resolved(value)local c=capability();c.Resolve(value);return c.Promise end
 local function rejected(value)local c=capability();c.Reject(value);return c.Promise end
 local function typeError(message)return VM.error("TypeError",message)end
 local function quiet(p)options.Await(p,function()end,function()end)end
 local function def(value,key,desc)vm.DefineProperty(value,key,vm.Object(desc,VM.Null))end
 local function native(name,n,fn)local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end};def(value,"length",{value=n,configurable=true});def(value,"name",{value=name,configurable=true});return value end
 local function method(proto,key,n,fn)
  local callback=fn
  if proto~=controllerProto and(key=="write"or key=="close"or key=="abort")then callback=function(args,value)local ok,result=pcall(fn,args,value);return if ok then result else rejected(VM.exceptionValue(result))end end
  def(proto,key,{value=native(key,n,callback),writable=true,enumerable=true,configurable=true})
 end
 local function getter(proto,key,fn)def(proto,key,{get=native("get "..key,0,function(_,receiver)return fn(receiver)end),enumerable=true,configurable=true})end
 local function brand(map,value,name)local state=map[value];if not state then fail(name.." requires a compatible receiver")end;return state end
 local function desired(state)return if state.Status=="erroring"or state.Status=="errored"then N elseif state.Status=="closed"then 0 else state.HighWaterMark-state.QueueSize end
 local function clean(state)state.Sink,state.Write,state.Close,state.Abort,state.Size=U,U,U,U end
 local function updateReady(state)
  local record=state.Writer and writers[state.Writer];if not record then return end
  if state.Status=="erroring"or state.Status=="errored"then
   if record.Ready.Settled then record.Ready=capability();quiet(record.Ready.Promise)end;record.Ready.Reject(state.Error)
  elseif state.Closing or desired(state)>0 or state.Status=="closed"then record.Ready.Resolve(U)
  elseif record.Ready.Settled then record.Ready=capability();quiet(record.Ready.Promise)end
 end
 finishError=function(state)
  if state.Status~="erroring"or state.Inflight or not state.Started then return end
  state.Status="errored";local reason=state.Error
  for _,entry in state.Queue do entry.Request.Reject(reason)end;state.Queue={};state.QueueSize=0
  local record=state.Writer and writers[state.Writer];if record then record.Closed.Reject(reason)end
  local pending=state.PendingAbort;state.PendingAbort=nil
  if pending and not pending.WasErroring then
   local sink,algorithm=state.Sink,state.Abort;clean(state)
   local ok,result=pcall(function()return if algorithm==U then U else vm:Call(algorithm,{pending.Reason},sink)end)
   if ok then options.Await(result,function()pending.Request.Resolve(U)end,pending.Request.Reject)else pending.Request.Reject(VM.exceptionValue(result))end
  else clean(state);if pending then pending.Request.Reject(reason)end end
 end
 startError=function(state,reason)
  if state.Status~="writable"then return end;state.Status,state.Error="erroring",reason;updateReady(state);finishError(state)
 end
 process=function(state)
  if not api.Alive or not state.Started or state.Inflight then return end
  if state.Status=="erroring"then finishError(state);return elseif state.Status~="writable"or #state.Queue==0 then return end
  local entry=state.Queue[1];state.Inflight=entry
  local algorithm=if entry.Close then state.Close else state.Write
  local ok,result=pcall(function()return if algorithm==U then U else vm:Call(algorithm,if entry.Close then {}else{entry.Chunk,state.Controller},state.Sink)end)
  local function failure(reason)
   if not api.Alive then return end;state.Inflight=nil;table.remove(state.Queue,1);state.QueueSize=math.max(0,state.QueueSize-entry.Size);entry.Request.Reject(reason)
   if state.Status=="writable"then startError(state,reason)else finishError(state)end
  end
  if not ok then failure(VM.exceptionValue(result));return end
  options.Await(result,function()
   if not api.Alive then return end;state.Inflight=nil;table.remove(state.Queue,1);state.QueueSize=math.max(0,state.QueueSize-entry.Size);entry.Request.Resolve(U)
   if entry.Close then
    state.Status="closed";local pending=state.PendingAbort;state.PendingAbort=nil;if pending then pending.Request.Resolve(U)end;clean(state)
    local writer=state.Writer and writers[state.Writer];if writer then writer.Ready.Resolve(U);writer.Closed.Resolve(U)end
   elseif state.Status=="erroring"then finishError(state)else updateReady(state);process(state)end
  end,failure)
 end
 abort=function(state,reason)
  if state.Status=="closed"or state.Status=="errored"then return resolved(U)end
  if state.PendingAbort then return state.PendingAbort.Request.Promise end
  if state.AbortController then vm:Call(vm.Get(state.AbortController,"abort"),{reason},state.AbortController)end
  if state.Status=="closed"or state.Status=="errored"then return resolved(U)end
  local request=capability();local wasErroring=state.Status=="erroring";state.PendingAbort={Reason=reason,Request=request,WasErroring=wasErroring}
  if wasErroring then finishError(state)else startError(state,reason)end;return request.Promise
 end
 function api:New(sink,strategy)
  check();sink=sink or U;strategy=strategy or U
  if field(sink,"type")~=U then VM.throw(VM.error("RangeError","WritableStream sink type must be undefined"))end
  local high=field(strategy,"highWaterMark");high=if high==U then 1 else VM.number(high);if high~=high or high<0 then VM.throw(VM.error("RangeError","Invalid writable highWaterMark"))end
  local state={Status="writable",Error=U,Queue={},QueueSize=0,HighWaterMark=high,Sink=sink,Write=field(sink,"write"),Close=field(sink,"close"),Abort=field(sink,"abort"),Size=field(strategy,"size"),Started=false,Closing=false}
  for _,key in {"Write","Close","Abort","Size"}do if state[key]~=U and not VM.callable(state[key])then fail("Writable stream "..key.." must be callable")end end
  if globals.AbortController then state.AbortController=vm:Construct(globals.AbortController,{})end
  local stream=vm.Object({},streamProto);stream.StreamState=state;streams[stream]=state
  local controller=vm.Object({},controllerProto);controller.StreamState=state;controllers[controller]=state;state.Controller=controller
  local start=field(sink,"start");if start~=U and not VM.callable(start)then fail("Writable start must be callable")end
  local result=if start==U then U else vm:Call(start,{controller},sink)
  options.Await(result,function()if api.Alive then state.Started=true;process(state)end end,function(reason)if api.Alive then state.Started=true;startError(state,reason);finishError(state)end end)
  return stream
 end
 function api:IsStream(value)return streams[value]~=nil end
 function api:IsLocked(value)return brand(streams,value,"WritableStream").Writer~=nil end
 local function acquire(value)
  local state=brand(streams,value,"WritableStream.getWriter");if state.Writer then fail("WritableStream is locked")end
  local record={Stream=value,Ready=capability(),Closed=capability()};quiet(record.Ready.Promise);quiet(record.Closed.Promise)
  local writer=vm.Object({},writerProto);writer.WriterState=record;writers[writer]=record;state.Writer=writer;updateReady(state)
  if state.Status=="closed"then record.Closed.Resolve(U)elseif state.Status=="errored"then record.Closed.Reject(state.Error)end;return writer
 end
 local function close(state)
  if state.Status~="writable"or state.Closing then return rejected(typeError("WritableStream cannot be closed"))end
  local request=capability();state.Closing=true;table.insert(state.Queue,{Close=true,Size=0,Request=request});updateReady(state);process(state);return request.Promise
 end
 local function write(writer,chunk)
  local record=brand(writers,writer,"WritableStreamDefaultWriter.write");if not record.Stream then return rejected(typeError("Writer lock was released"))end
  local state=streams[record.Stream]
  local ok,size=pcall(function()return if state.Size==U then 1 else VM.number(vm:Call(state.Size,{chunk},U))end)
  if not ok then startError(state,VM.exceptionValue(size))
  elseif size~=size or size<0 or size==math.huge then startError(state,VM.error("RangeError","Invalid writable chunk size"))end
  if not record.Stream then return rejected(typeError("Writer lock was released"))end
  if state.Status=="erroring"or state.Status=="errored"then return rejected(state.Error)end
  if state.Status=="closed"or state.Closing then return rejected(typeError("Cannot write after close"))end
  if #state.Queue>=1024 or state.QueueSize+size>1048576 then local reason=VM.error("RangeError","Writable stream queue budget exceeded");startError(state,reason);return rejected(reason)end
  local request=capability();table.insert(state.Queue,{Chunk=chunk,Size=size,Request=request});state.QueueSize+=size;updateReady(state);process(state);return request.Promise
 end
 getter(streamProto,"locked",function(value)return api:IsLocked(value)end)
 method(streamProto,"getWriter",0,function(_,value)return acquire(value)end)
 method(streamProto,"abort",1,function(args,value)local state=brand(streams,value,"WritableStream.abort");if state.Writer then return rejected(typeError("Cannot abort a locked stream"))end;return abort(state,arg(args,1))end)
 method(streamProto,"close",0,function(_,value)local state=brand(streams,value,"WritableStream.close");if state.Writer then return rejected(typeError("Cannot close a locked stream"))end;return close(state)end)
 for _,name in {"ready","closed"}do getter(writerProto,name,function(value)return brand(writers,value,"WritableStreamDefaultWriter."..name)[if name=="ready"then "Ready"else "Closed"].Promise end)end
 getter(writerProto,"desiredSize",function(value)local record=brand(writers,value,"WritableStreamDefaultWriter.desiredSize");if not record.Stream then fail("Writer lock was released")end;return desired(streams[record.Stream])end)
 method(writerProto,"write",1,function(args,value)return write(value,arg(args,1))end)
 method(writerProto,"close",0,function(_,value)local record=brand(writers,value,"WritableStreamDefaultWriter.close");return if record.Stream then close(streams[record.Stream])else rejected(typeError("Writer lock was released"))end)
 method(writerProto,"abort",1,function(args,value)local record=brand(writers,value,"WritableStreamDefaultWriter.abort");return if record.Stream then abort(streams[record.Stream],arg(args,1))else rejected(typeError("Writer lock was released"))end)
 method(writerProto,"releaseLock",0,function(_,value)
  local record=brand(writers,value,"WritableStreamDefaultWriter.releaseLock");if not record.Stream then return U end
  local state=streams[record.Stream];state.Writer=nil;record.Stream=nil;local reason=typeError("Writer lock was released")
  for _,key in {"Ready","Closed"}do if record[key].Settled then record[key]=capability();quiet(record[key].Promise)end;record[key].Reject(reason)end;return U
 end)
 method(controllerProto,"error",1,function(args,value)startError(brand(controllers,value,"WritableStreamDefaultController.error"),arg(args,1));return U end)
 getter(controllerProto,"signal",function(value)local state=brand(controllers,value,"WritableStreamDefaultController.signal");return if state.AbortController then vm.Get(state.AbortController,"signal")else U end)
 local function constructor(name,proto,n,create)local value=native(name,n,function()fail(name.." requires new")end);value.Construct=function(args)check();return create(args)end;def(value,"prototype",{value=proto});def(proto,"constructor",{value=value,writable=true,configurable=true});def(proto,vm.SymbolToStringTag,{value=name,configurable=true});globals[name]=value;vm.Global.Bindings[name]={Value=value}end
 constructor("WritableStream",streamProto,0,function(args)return api:New(arg(args,1),arg(args,2))end)
 constructor("WritableStreamDefaultWriter",writerProto,1,function(args)return acquire(arg(args,1))end)
 constructor("WritableStreamDefaultController",controllerProto,0,function()fail("Illegal writable controller constructor")end)
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  for _,state in streams do state.Queue={};state.Inflight=nil;state.PendingAbort=nil;state.Controller=nil;state.AbortController=nil;state.Writer=nil;clean(state)end
  for _,record in writers do record.Stream=nil;record.Ready=nil;record.Closed=nil end
  table.clear(streams);table.clear(writers);table.clear(controllers)
 end
 return api
end
return WritableStreams
