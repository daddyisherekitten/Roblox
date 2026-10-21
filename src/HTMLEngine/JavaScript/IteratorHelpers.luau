--!strict
-- Synchronous ECMAScript iterator helpers. Records capture next once; return
-- stays observable at close time. Lazy state machines need no suspended thread.
local IteratorHelpers={}
function IteratorHelpers.install(vm: any,globals: any?): any
 if vm.IteratorHelpers then return vm.IteratorHelpers end
 globals=globals or {};local VM=vm.Model;local U,N=VM.Undefined,VM.Null
 local api={Alive=true};vm.IteratorHelpers=api
 local records=setmetatable({},{__mode='kv'})
 local proto=assert(vm.Prototypes.Iterator,'Iterator helpers require the Symbol/iterator realm')
 local helperProto,wrapperProto=vm.Object({},proto),vm.Object({},proto)
 vm.Prototypes.IteratorHelper,vm.Prototypes.WrapForValidIterator=helperProto,wrapperProto
 local symbolDispose=vm.Get(vm.Global.Bindings.Symbol.Value,'dispose')
 local function check()assert(api.Alive and vm.Alive,'JavaScript iterator helpers disposed')end
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function object(value)return vm.ObjectModel.IsObject(value)end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function define(target,key,d)vm.DefineProperty(target,key,vm.Object(d,VM.Null))end
 local function property(target,key,value)define(target,key,{value=value,writable=true,configurable=true})end
 local function native(name,length,fn)
  local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end}
  define(value,'length',{value=length,configurable=true});define(value,'name',{value=name,configurable=true});return value
 end
 local function method(target,key,length,fn)property(target,key,native(key,length,fn))end
 local function result(value,done)return vm.Object({value=value,done=done},nil,{'value','done'})end
 local function getMethod(value,key)
  local fn=vm.Get(value,key);if fn==U or fn==N then return nil end
  if not VM.callable(fn)then fail('TypeError','Iterator method is not callable')end;return fn
 end
 local function direct(value)return {Iterator=value,Next=vm.Get(value,'next'),Done=false}end
 local function flattenable(value,strings)
  if not object(value)and not(strings and type(value)=='string')then fail('TypeError','Expected an iterator or iterable object')end
  local factory=getMethod(value,vm.SymbolIterator)
  local iterator=if factory then vm:Call(factory,{},value)else value
  if not object(iterator)then fail('TypeError','Iterator is not an object')end
  return direct(iterator)
 end
 -- IteratorClose preserves an existing thrown value, including undefined,
 -- even when the return getter/call fails or returns a primitive.
 local function close(iterated,failed,failure)
  local ok,closed=pcall(function()
   local fn=getMethod(iterated.Iterator,'return');if not fn then return nil end
   local out=vm:Call(fn,{},iterated.Iterator)
   if not object(out)then fail('TypeError','Iterator return result is not an object')end
   return out
  end)
  iterated.Done=true
  if failed then error(failure,0)end
  if not ok then error(closed,0)end
 end
 local function attempt(iterated,action)
  local ok,value=pcall(action);if not ok then close(iterated,true,value)end;return value
 end
 local function pull(iterated,readValue)
  local ok,packed=pcall(function()
   vm.Step();local out=vm:Call(iterated.Next,{},iterated.Iterator)
   if not object(out)then fail('TypeError','Iterator next result is not an object')end
   if VM.truth(vm.Get(out,'done'))then iterated.Done=true;return {false,U}end
   return {true,if readValue then vm.Get(out,'value')else U}
  end)
  if not ok then iterated.Done=true;error(packed,0)end
  return packed[1],packed[2]
 end
 local function requireObject(value)
  if not object(value)then fail('TypeError','Iterator helper requires an object receiver')end;return value
 end
 local function callbackRecord(value,callback)
  requireObject(value)
  if not VM.callable(callback)then
   local ok,failure=pcall(function()fail('TypeError','Iterator callback is not callable')end)
   assert(not ok);close({Iterator=value,Done=false},true,failure)
  end
  return direct(value)
 end
 local function limitRecord(value,limit)
  requireObject(value);local provisional={Iterator=value,Done=false}
  local integer=attempt(provisional,function()
   local primitive=vm.ToPrimitive(limit,'number')
   if type(primitive)=='table'and(primitive.Kind=='symbol'or primitive.Kind=='bigint')then fail('TypeError','Iterator limit cannot convert to a Number')end
   local number=VM.number(primitive)
   if number~=number then fail('RangeError','Iterator limit is NaN')end
   if number~=math.huge and number>9007199254740991 then fail('RangeError','Iterator limit exceeds the safe integer range')end
   local n=if number<0 then math.ceil(number)else math.floor(number)
   if n<0 then fail('RangeError','Iterator limit is negative')end;return n
  end)
  return direct(value),integer
 end
 local function release(r)
  r.State='completed';r.Source=nil;r.Inner=nil;r.Callback=nil;r.Iterables=nil
 end
 local function helper(mode,source,callback,limit,iterables)
  local value=vm.Object({},helperProto)
  local r={Kind='helper',State='suspendedStart',Mode=mode,Source=source,Callback=callback,Remaining=limit,Index=0,Iterables=iterables,IterableIndex=1}
  value.IteratorHelperState=r;records[value]=r;return value
 end
 local function brand(value,kind)
  local r=records[value];if not r or r.Kind~=kind then fail('TypeError','Iterator method called on an incompatible receiver')end;return r
 end
 local function advance(r)
  if r.Mode=='concat'then
   while true do
    if not r.Source then
     local item=r.Iterables[r.IterableIndex];if not item then return false,U end
     r.IterableIndex+=1;local iterator=vm:Call(item.Method,{},item.Value)
     if not object(iterator)then fail('TypeError','Iterator is not an object')end;r.Source=direct(iterator)
    end
    local more,value=pull(r.Source,true);if more then return true,value end;r.Source=nil
   end
  elseif r.Mode=='take'then
   if r.Remaining==0 then close(r.Source,false);return false,U end
   if r.Remaining~=math.huge then r.Remaining-=1 end
   return pull(r.Source,true)
  elseif r.Mode=='drop'then
   while r.Remaining>0 do
    if r.Remaining~=math.huge then r.Remaining-=1 end
    local more=pull(r.Source,false);if not more then return false,U end
   end
   return pull(r.Source,true)
  elseif r.Mode=='flatMap'then
   while true do
    if r.Inner then
     local ok,packed=pcall(function()local more,value=pull(r.Inner,true);return {more,value}end)
     if not ok then close(r.Source,true,packed)end
     if packed[1]then return true,packed[2]end
     r.Inner=nil;r.Index+=1
    end
    local more,value=pull(r.Source,true);if not more then return false,U end
    local mapped=attempt(r.Source,function()return vm:Call(r.Callback,{value,r.Index},U)end)
    r.Inner=attempt(r.Source,function()return flattenable(mapped,false)end)
   end
  else
   while true do
    local more,value=pull(r.Source,true);if not more then return false,U end
    local mapped=attempt(r.Source,function()return vm:Call(r.Callback,{value,r.Index},U)end);r.Index+=1
    if r.Mode=='map'then return true,mapped elseif VM.truth(mapped)then return true,value end
   end
  end
 end
 method(helperProto,'next',0,function(_,receiver)
  local r=brand(receiver,'helper')
  if r.State=='executing'then fail('TypeError','Iterator helper is already running')end
  if r.State=='completed'then return result(U,true)end
  r.State='executing';local ok,packed=pcall(function()local more,value=advance(r);return {more,value}end)
  if not ok then release(r);error(packed,0)end
  if not packed[1]then release(r);return result(U,true)end
  r.State='suspendedYield';return result(packed[2],false)
 end)
 method(helperProto,'return',0,function(_,receiver)
  local r=brand(receiver,'helper')
  if r.State=='executing'then fail('TypeError','Iterator helper is already running')end
  if r.State=='completed'then return result(U,true)end
  local source,inner=r.Source,r.Inner
  -- A never-started helper is completed before close. Resuming an existing
  -- yield with return keeps the helper executing during its close callbacks.
  if r.State=='suspendedStart'then release(r)else r.State='executing'end
  local ok,e=pcall(function()
   if inner then
    local innerOk,innerFailure=pcall(function()close(inner,false)end)
    if not innerOk then if source then close(source,true,innerFailure)end;error(innerFailure,0)end
   end
   if source then close(source,false)end
  end)
  release(r);if not ok then error(e,0)end;return result(U,true)
 end)
 define(helperProto,vm.SymbolToStringTag,{value='Iterator Helper',configurable=true})
 method(wrapperProto,'next',0,function(_,receiver)local r=brand(receiver,'wrapper');return vm:Call(r.Source.Next,{},r.Source.Iterator)end)
 method(wrapperProto,'return',0,function(_,receiver)
  local r=brand(receiver,'wrapper');local fn=getMethod(r.Source.Iterator,'return')
  return if fn then vm:Call(fn,{},r.Source.Iterator)else result(U,true)
 end)
 local constructor=native('Iterator',0,function()fail('TypeError','Iterator requires a derived constructor')end)
 constructor.Construct=function(_,newTarget)
  check();if newTarget==nil or newTarget==constructor then fail('TypeError','Iterator is an abstract constructor')end
  local prototype=vm.Get(newTarget,'prototype');return vm.Object({},if object(prototype)then prototype else proto)
 end
 define(constructor,'prototype',{value=proto})
 method(constructor,'from',1,function(args)
  local iterated=flattenable(arg(args,1),true)
  -- OrdinaryHasInstance deliberately bypasses a user Symbol.hasInstance.
  if vm.OrdinaryHasInstance(constructor,iterated.Iterator)then return iterated.Iterator end
  local value=vm.Object({},wrapperProto);local r={Kind='wrapper',Source=iterated};value.IteratorHelperState=r;records[value]=r;return value
 end)
 method(constructor,'concat',0,function(args)
  local iterables={};if #args>16384 then fail('RangeError','Iterator concat input budget exceeded')end
  for _,value in args do vm.Step();requireObject(value);local fn=getMethod(value,vm.SymbolIterator)
   if not fn then fail('TypeError','Iterator.concat requires iterable objects')end;table.insert(iterables,{Value=value,Method=fn})
  end
  return helper('concat',nil,nil,nil,iterables)
 end)
 local function accessor(key,value,label)
  define(proto,key,{get=native('get '..label,0,function()return value end),set=native('set '..label,1,function(args,receiver)
   requireObject(receiver);if receiver==proto then fail('TypeError','Cannot replace an intrinsic iterator prototype property')end
   if vm.HasOwn(receiver,key)then vm.Set(receiver,key,arg(args,1),true)
   else define(receiver,key,{value=arg(args,1),writable=true,enumerable=true,configurable=true})end;return U
  end),configurable=true})
 end
 accessor('constructor',constructor,'constructor');accessor(vm.SymbolToStringTag,'Iterator','[Symbol.toStringTag]')
 property(proto,vm.SymbolIterator,native('[Symbol.iterator]',0,function(_,receiver)return receiver end))
 property(proto,symbolDispose,native('[Symbol.dispose]',0,function(_,receiver)local fn=getMethod(receiver,'return');if fn then vm:Call(fn,{},receiver)end;return U end))
 for _,mode in {'map','filter','flatMap'}do method(proto,mode,1,function(args,receiver)
  local callback=arg(args,1);return helper(mode,callbackRecord(receiver,callback),callback)
 end)end
 for _,mode in {'take','drop'}do method(proto,mode,1,function(args,receiver)local record,limit=limitRecord(receiver,arg(args,1));return helper(mode,record,nil,limit)end)end
 for _,mode in {'some','every','find','forEach','reduce','toArray'}do method(proto,mode,if mode=='toArray'then 0 else 1,function(args,receiver)
  local callback=arg(args,1)
  local iterated=if mode=='toArray'then direct(requireObject(receiver))else callbackRecord(receiver,callback)
  local index,accumulator,items=0,arg(args,2),{}
  if mode=='reduce'and #args<2 then local more,value=pull(iterated,true);if not more then fail('TypeError','Cannot reduce an empty iterator without an initial value')end;accumulator=value;index=1 end
  while true do
   local more,value=pull(iterated,true)
   if not more then return if mode=='some'then false elseif mode=='every'then true elseif mode=='reduce'then accumulator elseif mode=='toArray'then vm.Array(items)else U end
   if mode=='toArray'then
    if #items>=16384 then attempt(iterated,function()fail('RangeError','Iterator result array budget exceeded')end)end
    table.insert(items,value)
   else
    local mapped=attempt(iterated,function()return vm:Call(callback,if mode=='reduce'then {accumulator,value,index}else {value,index},U)end)
    if mode=='reduce'then accumulator=mapped
    elseif(mode=='some'and VM.truth(mapped))or(mode=='every'and not VM.truth(mapped))or(mode=='find'and VM.truth(mapped))then close(iterated,false);return if mode=='some'then true elseif mode=='every'then false else value end
   end
   index+=1
  end
 end)end
 globals.Iterator=constructor;vm.Global.Bindings.Iterator={Value=constructor}
 api.Constructor=constructor
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  for _,r in records do release(r)end;table.clear(records)
  if vm.StandardLibrary and vm.StandardLibrary.ClearNativeIterators then vm.StandardLibrary.ClearNativeIterators()end
 end
 return api
end
return IteratorHelpers
