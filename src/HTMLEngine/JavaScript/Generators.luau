--!strict
-- Realm-owned suspended interpreter stacks and intrinsic async request queues.
-- VM Resume owns instruction/depth accounting; no scheduler or frame polling.
local Generators={}
local YIELD,AWAIT,HOST,RETURN={},{},{},{}
function Generators.install(vm: any,globals: any,options: any?): any
 if vm.Generators then if options and options.Promises then vm.Generators:AttachPromises(options.Promises)end;return vm.Generators end
 options=options or {};local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true};vm.Generators=api
 local wrappers,threads=setmetatable({},{__mode='kv'}),setmetatable({},{__mode='kv'});local promises=options.Promises
 local function check()assert(api.Alive and vm.Alive,'JavaScript generators disposed')end
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function object(value)return vm.ObjectModel.IsObject(value)end
 local function arg(args)return if args[1]==nil then U else args[1]end
 local function define(target,key,d)vm.DefineProperty(target,key,vm.Object(d,VM.Null))end
 local function property(target,key,value)define(target,key,{value=value,writable=true,configurable=true})end
 local function native(name,n,fn)local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end};define(value,'length',{value=n,configurable=true});define(value,'name',{value=name,configurable=true});return value end
 local function result(value,done)return vm.Object({value=value,done=done},nil,{'value','done'})end
 function api:IsReturn(exception)return type(exception)=='table'and exception.Brand==RETURN end
 function api:ReturnValue(exception)return exception.Value end
 local function abruptReturn(value)error({Brand=RETURN,Value=value},0)end
 local function release(r)
  local thread=r.Thread;r.Thread=nil;r.State='completed';r.HostAction=nil
  if thread then threads[thread]=nil;local state=coroutine.status(thread);if state=='suspended'or state=='dead'then pcall(coroutine.close,thread)end end
 end
 local drain,resume
 local function finishRequest(r,ok,value,done)
  local request=table.remove(r.Requests,1);r.Busy=false
  if ok then request.Resolve({result(value,done)})else request.Reject({value})end
  drain(r)
 end
 local function wait(value,yes,no)
  promises:Await(value,function(args)if api.Alive then yes(args[1])end end,function(args)if api.Alive then no(args[1])end end)
 end
 resume=function(r,mode,value)
  check();r.State='executing'
  local ok,out
  while true do
   ok,out=options.Resume(r,mode,value)
   if not api.Alive then return end
   if not ok or out~=HOST or coroutine.status(r.Thread)=='dead'then break end
   local action=r.HostAction;r.HostAction=nil;local success,packed=pcall(function()return table.pack(if options.HostCall then options.HostCall(action)else api:HostCall(action))end)
   mode,value=if success then 'next'else 'throw',packed
  end
  local ended=not ok or coroutine.status(r.Thread)=='dead'
  if ended then
   if not ok and api:IsReturn(out)then ok,out=true,api:ReturnValue(out)end
   release(r)
   if r.Async then
    if ok then wait(if out==nil then U else out,function(v)finishRequest(r,true,v,true)end,function(e)finishRequest(r,false,e,true)end)
    else finishRequest(r,false,VM.exceptionValue(out),true)end
   elseif ok then return result(if out==nil then U else out,true)else error(out,0)end
  elseif out==YIELD then
   r.State='suspendedYield';local yielded=r.Yielded;r.Yielded=nil
   if r.Async then finishRequest(r,true,yielded,false)else return result(yielded,false)end
  elseif out~=AWAIT or not r.Async then
   release(r);local errorValue=VM.error('Error','Unexpected generator suspension');if r.Async then finishRequest(r,false,errorValue,true)else VM.throw(errorValue)end
  end
 end
 drain=function(r)
  if not api.Alive or r.Busy or #r.Requests==0 then return end;r.Busy=true
  local request=r.Requests[1];local mode,value=request.Mode,request.Value
  if r.State=='completed'or(r.State=='suspendedStart'and mode~='next')then
   release(r)
   if mode=='throw'then finishRequest(r,false,value,true)
   elseif mode=='return'then wait(value,function(v)finishRequest(r,true,v,true)end,function(e)finishRequest(r,false,e,true)end)
   else finishRequest(r,true,U,true)end
  else resume(r,mode,value)end
 end
 local function brand(receiver,async)
  local r=wrappers[receiver];if not r or r.Async~=async then fail('TypeError','Generator called on incompatible receiver')end;return r
 end
 local function request(receiver,async,mode,value)
  if async then
   if not promises then fail('TypeError','Async generator requires intrinsic promises')end
   local promise,resolve,reject=promises:CreateCapability();local ok,r=pcall(brand,receiver,true)
   if not ok then reject({VM.exceptionValue(r)});return promise end
   if #r.Requests>=4096 then reject({VM.error('RangeError','Async generator request budget exceeded')});return promise end
   table.insert(r.Requests,{Mode=mode,Value=value,Resolve=resolve,Reject=reject});drain(r);return promise
  end
  local r=brand(receiver,false);if r.State=='executing'then fail('TypeError','Generator is already running')end
  if r.State=='completed'or(r.State=='suspendedStart'and mode~='next')then release(r);if mode=='throw'then VM.throw(value)end;return result(if mode=='return'then value else U,true)end
  return resume(r,mode,value)
 end
 local asyncIteratorProto=vm.Prototypes.AsyncIterator or vm.Object({});vm.Prototypes.AsyncIterator=asyncIteratorProto
 if vm.SymbolAsyncIterator then property(asyncIteratorProto,vm.SymbolAsyncIterator,native('[Symbol.asyncIterator]',0,function(_,receiver)return receiver end))end
 for _,async in {false,true}do
  local name=if async then 'AsyncGenerator'else 'Generator';local proto=vm.Object({},if async then asyncIteratorProto else vm.Prototypes.Iterator)
  local functionProto=vm.Object({},vm.Prototypes.Function);vm.Prototypes[name]=proto;vm.Prototypes[name..'Function']=functionProto
  define(functionProto,'prototype',{value=proto,configurable=true});define(proto,'constructor',{value=functionProto,configurable=true})
  for _,mode in {'next','return','throw'}do property(proto,mode,native(mode,1,function(args,receiver)return request(receiver,async,mode,arg(args))end))end
  if vm.SymbolToStringTag then define(proto,vm.SymbolToStringTag,{value=name,configurable=true});define(functionProto,vm.SymbolToStringTag,{value=name..'Function',configurable=true})end
 end
 function api:AttachPromises(value)check();if promises then assert(promises==value,'Generator promise realm cannot change');return end;promises=value end
 function api:Create(body,prototype,isAsync)
  check();assert(type(body)=='function','Generator body must be callable');if isAsync and not promises then fail('TypeError','Async generator requires intrinsic promises')end
  if not object(prototype)then prototype=vm.Prototypes[if isAsync then 'AsyncGenerator'else 'Generator']end
  local value=vm.Object({},prototype);local r={State='suspendedStart',Async=isAsync==true,Depth=1,Started=false,Requests={},Busy=false,Thread=coroutine.create(body)}
  value.GeneratorState=r;wrappers[value]=r;threads[r.Thread]=r;return value
 end
 function api:IsActive()return threads[coroutine.running()]~=nil end
 function api:Await(value)
  check();local r=threads[coroutine.running()];if not r or not r.Async then fail('TypeError','await requires an active async generator')end
  wait(value,function(v)resume(r,'next',v)end,function(e)resume(r,'throw',e)end)
  local mode,out=coroutine.yield(AWAIT);check();if mode=='throw'then VM.throw(out)end;return out
 end
 function api:HostCall(action)
  check();local r=threads[coroutine.running()];if not r then return action()end;r.HostAction=action
  local mode,packed=coroutine.yield(HOST);check();if mode=='throw'then error(packed,0)end;return table.unpack(packed,1,packed.n)
 end
 local function suspend(value)
  local r=threads[coroutine.running()];if r.Async then value=api:Await(value)end
  r.Yielded=value;local mode,out=coroutine.yield(YIELD);check();return mode,out
 end
 local function method(iterator,key)
  local value=vm.Get(iterator,key);if value==U or value==N then return nil end;if not VM.callable(value)then fail('TypeError','Iterator method is not callable')end;return value
 end
 local function delegate(input)
  local r=threads[coroutine.running()];local async=r.Async;local factory=if async then method(input,vm.SymbolAsyncIterator)else nil;local fallback=async and not factory
  if not factory then factory=method(input,vm.SymbolIterator)end;if not factory then fail('TypeError','Delegated value is not iterable')end
  local iterator=vm:Call(factory,{},input);if not object(iterator)then fail('TypeError','Delegated iterator is not an object')end
  local nextMethod=method(iterator,'next');if not nextMethod then fail('TypeError','Delegated iterator has no next method')end
  local mode,value='next',U
  while true do
   vm.Step();if async and mode=='return'then value=api:Await(value)end
   local fn=if mode=='next'then nextMethod else method(iterator,mode)
   if not fn then
    if mode=='return'then abruptReturn(value)end
    local close=method(iterator,'return');if close then local closed=vm:Call(close,{},iterator);if async and not fallback then closed=api:Await(closed)end;if not object(closed)then fail('TypeError','Iterator return result is not an object')end end
    fail('TypeError','Delegated iterator has no throw method')
   end
   local step=vm:Call(fn,{value},iterator);if async and not fallback then step=api:Await(step)end
   if not object(step)then fail('TypeError','Iterator result is not an object')end
   local done=VM.truth(vm.Get(step,'done'));local output=vm.Get(step,'value')
   if fallback then
    local ok,unwrapped=pcall(api.Await,api,output)
    if not ok then
     if not done and mode~='return'then pcall(function()local close=method(iterator,'return');if close then vm:Call(close,{},iterator)end end)end
     error(unwrapped,0)
    end
    output=unwrapped
   end
   if done then if mode=='return'then abruptReturn(output)end;return output end
   mode,value=suspend(output)
  end
 end
 function api:Yield(value,delegated)
  check();local r=threads[coroutine.running()];if not r then fail('TypeError','yield requires an active generator')end
  if delegated then return delegate(value)end
  local mode,out=suspend(value);if mode=='throw'then VM.throw(out)elseif mode=='return'then if r.Async then out=self:Await(out)end;abruptReturn(out)end;return out
 end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  for _,r in wrappers do release(r);table.clear(r.Requests)end
  -- A pending promise may retain an active record after its wrapper was
  -- collected. Close those remaining stacks before dropping the thread map.
  for _,r in threads do release(r);table.clear(r.Requests)end
  table.clear(wrappers);table.clear(threads);promises=nil;table.clear(options)
 end
 return api
end
return Generators
