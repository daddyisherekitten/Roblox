--!strict
local TransformStreams={}
function TransformStreams.install(vm: any,globals: any,options: any,readable: any,writable: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true};local states,controllers=setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"})
 local proto,controllerProto=vm.Object({}),vm.Object({})
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function field(value,key)return if value==nil or value==U or value==N then U else vm.Get(value,key)end
 local function fail(message)VM.throw(VM.error("TypeError",message))end
 local function call(value,key,args)return vm:Call(vm.Get(value,key),args or {},value)end
 local function cap()local promise,yes,no=options.CreatePromise();return {Promise=promise,Resolve=function(value)if api.Alive then yes({value})end end,Reject=function(value)if api.Alive then no({value})end end}end
 local function def(value,key,descriptor)vm.DefineProperty(value,key,vm.Object(descriptor,VM.Null))end
 local function native(name,n,callback)local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)assert(api.Alive and vm.Alive,"JavaScript transforms disposed");return callback(args,receiver)end};def(value,"length",{value=n,configurable=true});def(value,"name",{value=name,configurable=true});return value end
 local function method(target,name,n,callback)def(target,name,{value=native(name,n,callback),writable=true,enumerable=true,configurable=true})end
 local function getter(target,name,callback)def(target,name,{get=native("get "..name,0,function(_,value)return callback(value)end),enumerable=true,configurable=true})end
 local function controller(value)local state=controllers[value];if not state then fail("TransformStream controller requires a compatible receiver")end;return state end
 local function clearBackpressure(state)if state.Backpressure then state.Backpressure=false;state.Pressure.Resolve(U)end end
 local function errorBoth(state,reason)
  if state.Errored then return end;state.Errored,state.Error=true,reason
  call(state.ReadableController,"error",{reason});call(state.WritableController,"error",{reason});clearBackpressure(state)
  state.Transform,state.Flush,state.Transformer=U,U,U
 end
 local function enqueue(state,value)
  if state.Errored then VM.throw(state.Error)end
  local ok,message=pcall(call,state.ReadableController,"enqueue",{value})
  if not ok then local reason=VM.exceptionValue(message);errorBoth(state,reason);VM.throw(reason)end
  local desired=vm.Get(state.ReadableController,"desiredSize")
  if desired~=N and desired<=0 and not state.Backpressure then state.Backpressure=true;state.Pressure=cap()end
 end
 method(controllerProto,"enqueue",1,function(args,value)enqueue(controller(value),arg(args,1));return U end)
 method(controllerProto,"error",1,function(args,value)errorBoth(controller(value),arg(args,1));return U end)
 method(controllerProto,"terminate",0,function(_,value)
  local state=controller(value);local reason=VM.error("TypeError","TransformStream was terminated")
  local ok=pcall(call,state.ReadableController,"close");state.Errored,state.Error=true,reason;call(state.WritableController,"error",{reason});clearBackpressure(state);state.Transform,state.Flush,state.Transformer=U,U,U;return U
 end)
 getter(controllerProto,"desiredSize",function(value)return vm.Get(controller(value).ReadableController,"desiredSize")end)
 function api:New(transformer,writeStrategy,readStrategy)
  transformer=transformer or U;writeStrategy=writeStrategy or U;readStrategy=readStrategy or U
  if field(transformer,"readableType")~=U or field(transformer,"writableType")~=U then VM.throw(VM.error("RangeError","Typed transform streams are not supported"))end
  local transform,flush,start=field(transformer,"transform"),field(transformer,"flush"),field(transformer,"start")
  for _,algorithm in {transform,flush,start}do if algorithm~=U and not VM.callable(algorithm)then fail("Transformer algorithms must be callable")end end
  local state={Transformer=transformer,Transform=transform,Flush=flush,Backpressure=true,Pressure=cap(),Errored=false,Error=U}
  local value=vm.Object({},proto);value.StreamState=state;states[value]=state
  local control=vm.Object({},controllerProto);control.StreamState=state;controllers[control]=state;state.Controller=control
  local started=cap()
  state.Writable=writable:New(vm.Object({
   start=function(args)state.WritableController=args[1];return started.Promise end,
   write=function(args)
    local chunk=args[1];local completion=cap()
    local function perform()
     if not api.Alive then return end
     if state.Errored then completion.Reject(state.Error);return end
     local ok,result=pcall(function()if state.Transform==U then enqueue(state,chunk);return U end;return vm:Call(state.Transform,{chunk,control},state.Transformer)end)
     if not ok then local reason=VM.exceptionValue(result);errorBoth(state,reason);completion.Reject(reason)
     else options.Await(result,function()completion.Resolve(U)end,function(reason)errorBoth(state,reason);completion.Reject(reason)end)end
    end
    if state.Backpressure then options.Await(state.Pressure.Promise,perform,completion.Reject)else perform()end
    return completion.Promise
   end,
   close=function()
    local completion=cap();local ok,result=pcall(function()return if state.Flush==U then U else vm:Call(state.Flush,{control},state.Transformer)end)
    state.Transform,state.Flush=U,U
    if not ok then local reason=VM.exceptionValue(result);errorBoth(state,reason);completion.Reject(reason)
    else options.Await(result,function()
     if not api.Alive then return end;if state.Errored then completion.Reject(state.Error)else call(state.ReadableController,"close");completion.Resolve(U)end
    end,function(reason)errorBoth(state,reason);completion.Reject(reason)end)end
    return completion.Promise
   end,
   abort=function(args)errorBoth(state,arg(args,1));return U end,
  }),writeStrategy)
  local high=field(readStrategy,"highWaterMark");local size=field(readStrategy,"size")
  state.Readable=readable:New(vm.Object({
   start=function(args)state.ReadableController=args[1];return started.Promise end,
   pull=function()clearBackpressure(state);return if state.Backpressure then state.Pressure.Promise else U end,
   cancel=function(args)errorBoth(state,arg(args,1));return U end,
  }),vm.Object({highWaterMark=if high==U then 0 else high,size=size}))
  local result=if start==U then U else vm:Call(start,{control},transformer)
  options.Await(result,started.Resolve,function(reason)errorBoth(state,reason);started.Reject(reason)end)
  return value
 end
 for _,name in {"readable","writable"}do getter(proto,name,function(value)local state=states[value];if not state then fail("TransformStream requires compatible receiver")end;return state[if name=="readable"then "Readable"else "Writable"]end)end
 local function constructor(name,target,n,create)local value=native(name,n,function()fail(name.." requires new")end);value.Construct=create;def(value,"prototype",{value=target});def(target,"constructor",{value=value,writable=true,configurable=true});def(target,vm.SymbolToStringTag,{value=name,configurable=true});globals[name]=value;vm.Global.Bindings[name]={Value=value}end
 constructor("TransformStream",proto,0,function(args)return api:New(arg(args,1),arg(args,2),arg(args,3))end)
 constructor("TransformStreamDefaultController",controllerProto,0,function()fail("Illegal transform controller constructor")end)
 for _,name in {"CountQueuingStrategy","ByteLengthQueuingStrategy"}do
  local strategyProto=vm.Object({});local records=setmetatable({},{__mode="kv"});local size=native("size",1,function(args)return if name=="CountQueuingStrategy"then 1 else vm.Get(arg(args,1),"byteLength")end)
  getter(strategyProto,"highWaterMark",function(value)local state=records[value];if not state then fail(name.." requires compatible receiver")end;return state.HighWaterMark end)
  getter(strategyProto,"size",function(value)if not records[value]then fail(name.." requires compatible receiver")end;return size end)
  constructor(name,strategyProto,1,function(args)local init=arg(args,1);local high=field(init,"highWaterMark");if high==U then fail(name.." requires highWaterMark")end;local value=vm.Object({},strategyProto);local state={HighWaterMark=VM.number(high)};value.StreamState=state;records[value]=state;return value end)
 end
 function api:Destroy()
  self.Alive=false;for _,state in states do state.Transform,state.Flush,state.Transformer=U,U,U;state.Pressure=nil;state.ReadableController=nil;state.WritableController=nil;state.Controller=nil;state.Readable=nil;state.Writable=nil end
  table.clear(states);table.clear(controllers)
 end
 return api
end
return TransformStreams
