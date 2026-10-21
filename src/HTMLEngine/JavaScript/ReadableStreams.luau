--!strict
-- Default readable streams: demand-driven jobs, bounded queues, no frame loop.
local ReadableStreams={}
function ReadableStreams.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true}
 local streams,readers,controllers=setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"})
 local streamProto,readerProto,controllerProto=vm.Object({}),vm.Object({}),vm.Object({})
 local pull,errorStream,closeStream,read,cancel
 local function check()assert(api.Alive and vm.Alive,"JavaScript readable streams disposed")end
 local function fail(message)VM.throw(VM.error("TypeError",message))end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function field(value,key)return if value==U or value==N or value==nil then U else vm.Get(value,key)end
 local function capability()local p,resolve,reject=options.CreatePromise();return {Promise=p,Resolve=function(value)if api.Alive then resolve({value})end end,Reject=function(value)if api.Alive then reject({value})end end}end
 local function resolved(value)local c=capability();c.Resolve(value);return c.Promise end
 local function rejected(value)local c=capability();c.Reject(value);return c.Promise end
 local function typeError(message)return VM.error("TypeError",message)end
 local function native(name,n,fn)local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end};vm.DefineProperty(value,"length",vm.Object({value=n,configurable=true},VM.Null));vm.DefineProperty(value,"name",vm.Object({value=name,configurable=true},VM.Null));return value end
 local function def(target,key,desc)vm.DefineProperty(target,key,vm.Object(desc,VM.Null))end
 local function method(proto,name,n,fn)
  local callback=fn
  if proto~=controllerProto and(name=="read"or name=="cancel")then callback=function(args,value)local ok,result=pcall(fn,args,value);return if ok then result else rejected(VM.exceptionValue(result))end end
  def(proto,name,{value=native(name,n,callback),writable=true,configurable=true,enumerable=true})
 end
 local function accessor(proto,name,fn)def(proto,name,{get=native("get "..name,0,function(_,value)return fn(value)end),enumerable=true,configurable=true})end
 local function brand(map,value,name)local state=map[value];if not state then fail(name.." requires a compatible receiver")end;return state end
 local function result(value,done)return vm.Object({value=value,done=done},nil,{"value","done"})end
 local function quiet(p)options.Await(p,function()end,function()end)end
 local function desired(state)return if state.Status=="errored"then N elseif state.Status=="closed"then 0 else state.HighWaterMark-state.QueueSize end
 local function cleanSource(state)state.Source,state.Pull,state.Cancel,state.Size=U,U,U,U end
 closeStream=function(state)
  if state.Status~="readable"then return end;state.Status="closed";cleanSource(state)
  local reader=state.Reader and readers[state.Reader];if reader then for _,request in reader.Requests do request.Resolve(result(U,true))end;reader.Requests={};reader.Closed.Resolve(U)end
 end
 errorStream=function(state,reason)
  if state.Status~="readable"then return end;state.Status,state.Error="errored",reason;state.Queue={};state.QueueSize=0;cleanSource(state)
  local reader=state.Reader and readers[state.Reader];if reader then for _,request in reader.Requests do request.Reject(reason)end;reader.Requests={};reader.Closed.Reject(reason)end
 end
 local function callAlgorithm(state,fn,args)
  if fn==U then return true,U end
  return pcall(function()return vm:Call(fn,args,state.Source)end)
 end
 pull=function(state)
  if not api.Alive or not state.Started or state.Status~="readable"or state.Closing or state.Pull==U then return end
  local reader=state.Reader and readers[state.Reader]
  if not(reader and #reader.Requests>0)and desired(state)<=0 then return end
  if state.Pulling then state.PullAgain=true;return end;state.Pulling=true
  local ok,value=callAlgorithm(state,state.Pull,{state.Controller})
  if not ok then state.Pulling=false;errorStream(state,VM.exceptionValue(value));return end
  options.Await(value,function()
   if not api.Alive then return end;state.Pulling=false;if state.PullAgain then state.PullAgain=false;pull(state)end
  end,function(reason)if api.Alive then state.Pulling=false;errorStream(state,reason)end end)
 end
 local function enqueue(state,value)
  if state.Status~="readable"or state.Closing then fail("Cannot enqueue into a closed or errored stream")end
  local reader=state.Reader and readers[state.Reader]
  if reader and #reader.Requests>0 then table.remove(reader.Requests,1).Resolve(result(value,false))
  else
   local ok,size=pcall(function()return if state.Size==U then U else vm:Call(state.Size,{value},U)end);if not ok then local reason=VM.exceptionValue(size);errorStream(state,reason);VM.throw(reason)end
   size=if state.Size==U then 1 else VM.number(size)
   if size~=size or size<0 or size==math.huge then local reason=VM.error("RangeError","Invalid stream chunk size");errorStream(state,reason);VM.throw(reason)end
   if #state.Queue>=1024 or state.QueueSize+size>1048576 then local reason=VM.error("RangeError","ReadableStream queue budget exceeded");errorStream(state,reason);VM.throw(reason)end
   table.insert(state.Queue,{Value=value,Size=size});state.QueueSize+=size
  end;pull(state)
 end
 local function controllerState(value)return brand(controllers,value,"ReadableStreamDefaultController")end
 accessor(controllerProto,"desiredSize",function(value)return desired(controllerState(value))end)
 method(controllerProto,"enqueue",1,function(args,value)enqueue(controllerState(value),arg(args,1));return U end)
 method(controllerProto,"close",0,function(_,value)local state=controllerState(value);if state.Status~="readable"or state.Closing then fail("Cannot close this stream")end;state.Closing=true;if #state.Queue==0 then closeStream(state)end;return U end)
 method(controllerProto,"error",1,function(args,value)errorStream(controllerState(value),arg(args,1));return U end)
 function api:New(source,strategy)
  check();source=source or U;strategy=strategy or U
  if field(source,"type")~=U then fail("Byte-mode/BYOB streams are not implemented; use a default readable stream")end
  local high=field(strategy,"highWaterMark");high=if high==U then 1 else VM.number(high)
  if high~=high or high<0 then VM.throw(VM.error("RangeError","Invalid highWaterMark"))end
  local state={Status="readable",Error=U,Queue={},QueueSize=0,HighWaterMark=high,Source=source,Pull=field(source,"pull"),Cancel=field(source,"cancel"),Size=field(strategy,"size"),Started=false,Pulling=false,PullAgain=false,Closing=false,Disturbed=false}
  for _,key in {"Pull","Cancel","Size"}do if state[key]~=U and not VM.callable(state[key])then fail("Stream "..key.." must be callable")end end
  local stream=vm.Object({},streamProto);stream.StreamState=state;streams[stream]=state
  local controller=vm.Object({},controllerProto);controller.StreamState=state;controllers[controller]=state;state.Controller=controller
  local start=field(source,"start");if start~=U and not VM.callable(start)then fail("Stream start must be callable")end
  local ok,value=callAlgorithm(state,start,{controller});if not ok then error(value,0)end
  options.Await(value,function()if api.Alive then state.Started=true;pull(state)end end,function(reason)if api.Alive then errorStream(state,reason)end end)
  return stream
 end
 function api:IsStream(value)return streams[value]~=nil end
 function api:IsDisturbed(value)return brand(streams,value,"ReadableStream").Disturbed end
 function api:IsLocked(value)return brand(streams,value,"ReadableStream").Reader~=nil end
 function api:FromChunks(chunks)
  local source=vm.Object({start=function(args)local controller=args[1];for _,chunk in chunks do vm:Call(vm.Get(controller,"enqueue"),{chunk},controller)end;vm:Call(vm.Get(controller,"close"),{},controller)end})
  return self:New(source)
 end
 local function acquire(stream)
  local state=brand(streams,stream,"ReadableStream.getReader");if state.Reader then fail("ReadableStream is already locked")end
  local closed=capability();quiet(closed.Promise);local record={Stream=stream,Closed=closed,Requests={}}
  local reader=vm.Object({},readerProto);reader.ReaderState=record;readers[reader]=record;state.Reader=reader
  if state.Status=="closed"then closed.Resolve(U)elseif state.Status=="errored"then closed.Reject(state.Error)end
  return reader
 end
 read=function(reader)
  local record=brand(readers,reader,"ReadableStreamDefaultReader.read");if not record.Stream then return rejected(typeError("Reader lock was released"))end
  local state=streams[record.Stream];state.Disturbed=true
  if state.Status=="closed"then return resolved(result(U,true))elseif state.Status=="errored"then return rejected(state.Error)end
  local request=capability()
  if #state.Queue>0 then local chunk=table.remove(state.Queue,1);state.QueueSize=math.max(0,state.QueueSize-chunk.Size);request.Resolve(result(chunk.Value,false));if state.Closing and #state.Queue==0 then closeStream(state)else pull(state)end
  else if #record.Requests>=1024 then request.Reject(VM.error("RangeError","Stream read request budget exceeded"))else table.insert(record.Requests,request);pull(state)end end
  return request.Promise
 end
 cancel=function(state,reason)
  state.Disturbed=true;if state.Status=="closed"then return resolved(U)elseif state.Status=="errored"then return rejected(state.Error)end
  local source,algorithm=state.Source,state.Cancel;state.Queue={};state.QueueSize=0;closeStream(state)
  local request=capability();local ok,value=pcall(function()return if algorithm==U then U else vm:Call(algorithm,{reason},source)end)
  if not ok then request.Reject(VM.exceptionValue(value))else options.Await(value,function()request.Resolve(U)end,request.Reject)end;return request.Promise
 end
 accessor(streamProto,"locked",function(value)return api:IsLocked(value)end)
 method(streamProto,"getReader",0,function(args,value)local mode=field(arg(args,1),"mode");if mode~=U then fail("Only default readers are supported; BYOB is not implemented")end;return acquire(value)end)
 method(streamProto,"cancel",1,function(args,value)local state=brand(streams,value,"ReadableStream.cancel");if state.Reader then return rejected(typeError("Cannot cancel a locked stream"))end;return cancel(state,arg(args,1))end)
 accessor(readerProto,"closed",function(value)return brand(readers,value,"ReadableStreamDefaultReader.closed").Closed.Promise end)
 method(readerProto,"read",0,function(_,value)return read(value)end)
 method(readerProto,"cancel",1,function(args,value)local record=brand(readers,value,"ReadableStreamDefaultReader.cancel");if not record.Stream then return rejected(typeError("Reader lock was released"))end;return cancel(streams[record.Stream],arg(args,1))end)
 method(readerProto,"releaseLock",0,function(_,value)
  local record=brand(readers,value,"ReadableStreamDefaultReader.releaseLock");if not record.Stream then return U end
  local state=streams[record.Stream];local reason=typeError("Reader lock was released")
  if state.Status~="readable"then record.Closed=capability();quiet(record.Closed.Promise)end;record.Closed.Reject(reason)
  for _,request in record.Requests do request.Reject(reason)end;record.Requests={};record.Stream=nil;state.Reader=nil;return U
 end)
 function api:Consume(stream,onChunk,onDone,onError)
  local reader=acquire(stream);local readNext
  local function finish(callback,value)if not api.Alive then return end;vm:Call(vm.Get(reader,"releaseLock"),{},reader);callback(value)end
  readNext=function()
   if not api.Alive then return end
   options.Await(read(reader),function(item)
    if not api.Alive then return end
    if VM.truth(vm.Get(item,"done"))then finish(onDone,U);return end
    local ok,message=pcall(onChunk,vm.Get(item,"value"));if not ok then local reason=VM.exceptionValue(message);local canceled=cancel(streams[stream],reason);quiet(canceled);finish(onError,reason);return end;readNext()
   end,function(reason)finish(onError,reason)end)
  end;readNext()
 end
 function api:Transfer(stream)
  local reader=acquire(stream);streams[stream].Disturbed=true
  return api:New(vm.Object({pull=function(args)
   local controller=args[1];local completion=capability()
   options.Await(read(reader),function(item)
    if not api.Alive then return end
    if VM.truth(vm.Get(item,"done"))then vm:Call(vm.Get(controller,"close"),{},controller)
    else vm:Call(vm.Get(controller,"enqueue"),{vm.Get(item,"value")},controller)end
    completion.Resolve(U)
   end,function(reason)if api.Alive then errorStream(controllers[controller],reason);completion.Resolve(U)end end)
   return completion.Promise
  end,cancel=function(args)return cancel(streams[stream],arg(args,1))end}))
 end
 function api:Tee(stream,clone)
  local reader=acquire(stream);local branches,controls={},{};local canceled,reasons={false,false},{U,U};local reading=false;local cancelResult=capability()
  local function request()
   if reading then return U end;reading=true
   options.Await(read(reader),function(item)
    if not api.Alive then return end;reading=false
    if VM.truth(vm.Get(item,"done"))then for i=1,2 do if not canceled[i]then vm:Call(vm.Get(controls[i],"close"),{},controls[i])end end;cancelResult.Resolve(U);return end
    local chunk=vm.Get(item,"value")
    for i=1,2 do if not canceled[i]then local copied=if i==2 and clone then clone(chunk)else chunk;vm:Call(vm.Get(controls[i],"enqueue"),{copied},controls[i])end end
   end,function(reason)if api.Alive then for i=1,2 do if not canceled[i]then errorStream(streams[branches[i]],reason)end end;cancelResult.Resolve(U)end end)
   return U
  end
  for i=1,2 do branches[i]=api:New(vm.Object({start=function(args)controls[i]=args[1]end,pull=request,cancel=function(args)
   canceled[i],reasons[i]=true,arg(args,1)
   if canceled[1]and canceled[2]then options.Await(cancel(streams[stream],vm.Array(reasons)),cancelResult.Resolve,cancelResult.Reject)end
   return cancelResult.Promise
  end}))end
  return branches[1],branches[2]
 end
 method(streamProto,"tee",0,function(_,value)local first,second=api:Tee(value);return vm.Array({first,second})end)
 local function constructor(name,proto,create)local value=native(name,0,function()fail(name.." requires new")end);value.Construct=create;def(value,"prototype",{value=proto});def(proto,"constructor",{value=value,writable=true,configurable=true});def(proto,vm.SymbolToStringTag,{value=name,configurable=true});globals[name]=value;vm.Global.Bindings[name]={Value=value};return value end
 constructor("ReadableStream",streamProto,function(args)return api:New(arg(args,1),arg(args,2))end)
 constructor("ReadableStreamDefaultReader",readerProto,function(args)return acquire(arg(args,1))end)
 constructor("ReadableStreamDefaultController",controllerProto,function()fail("Illegal ReadableStreamDefaultController constructor")end)
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  for _,state in streams do state.Queue={};state.QueueSize=0;cleanSource(state);state.Controller=nil;state.Reader=nil end
  for _,record in readers do record.Requests={};record.Stream=nil;record.Closed=nil end
  table.clear(streams);table.clear(readers);table.clear(controllers)
 end
 return api
end
return ReadableStreams
