--!strict
-- Realm prototypes with agent-wide Symbol registry/well-known identities.
-- Strong collections retain insertion records so outstanding iterators stay
-- live across delete/clear/reinsert. Weak collections use host weak-key tables.
local Strings=require(script.Parent.Strings)
local BigInt=require(script.Parent.BigInt)
local Collections={}
local registry,wellKnown={},{}
local registeredCount=0
function Collections.install(c: any)
 local VM,vm,U,N=c.VM,c.vm,c.U,c.N;local get,set,step=c.get,c.set,c.step
 local function symbol(value)return type(value)=='table'and value.Kind=='symbol'end
 local symbolProto=vm.Object({},c.prototypes.Object);c.prototypes.Symbol=symbolProto
 local function makeSymbol(description,registered)
  return {Kind='symbol',Description=description,Registered=registered}
 end
 for _,name in {'asyncIterator','hasInstance','isConcatSpreadable','iterator','match','matchAll','replace','search','species','split','toPrimitive','toStringTag','unscopables','dispose','asyncDispose'}do
  if not wellKnown[name]then wellKnown[name]=makeSymbol('Symbol.'..name,false)end
 end
 vm.SymbolIterator=wellKnown.iterator;vm.SymbolAsyncIterator=wellKnown.asyncIterator;vm.SymbolToPrimitive=wellKnown.toPrimitive;vm.SymbolToStringTag=wellKnown.toStringTag
 vm.SymbolIsConcatSpreadable=wellKnown.isConcatSpreadable;vm.SymbolSpecies=wellKnown.species
 local function receiver(value)
  if symbol(value)then return value elseif type(value)=='table'and value.Kind=='boxed-symbol'and symbol(value.PrimitiveValue)then return value.PrimitiveValue end
  c.fail('TypeError','Symbol method called on incompatible receiver')
 end
 local constructor=c.native('Symbol',0,function(args)return makeSymbol(if args[1]==nil or args[1]==U then nil else c.text(args[1]),false)end,nil,{prototype=symbolProto})
 c.define(symbolProto,'constructor',constructor)
 c.method(symbolProto,'toString',0,function(_,value)return 'Symbol('..(receiver(value).Description or '')..')'end)
 c.method(symbolProto,'valueOf',0,function(_,value)return receiver(value)end)
 c.define(symbolProto,wellKnown.toPrimitive,c.native('[Symbol.toPrimitive]',1,function(_,value)return receiver(value)end))
 vm.DefineProperty(symbolProto,'description',vm.Object({get=c.native('get description',0,function(_,value)return receiver(value).Description or U end),enumerable=false,configurable=true},VM.Null))
 c.method(constructor,'for',1,function(args)
  local key=c.text(c.arg(args,1,U));local value=registry[key]
  if not value then c.bound(registeredCount+1);value=makeSymbol(key,true);value.RegistryKey=key;registry[key]=value;registeredCount+=1 end;return value
 end)
 c.method(constructor,'keyFor',1,function(args)local value=c.arg(args,1,U);if not symbol(value)then c.fail('TypeError','Symbol.keyFor requires a Symbol')end;return value.RegistryKey or U end)
 for name,value in wellKnown do vm.DefineProperty(constructor,name,vm.Object({value=value,writable=false,enumerable=false,configurable=false},VM.Null))end
 c.define(symbolProto,wellKnown.toStringTag,'Symbol');c.global('Symbol',constructor)

 local iteratorProto=vm.Object({},c.prototypes.Object);c.prototypes.Iterator=iteratorProto
 c.define(iteratorProto,wellKnown.iterator,c.native('[Symbol.iterator]',0,function(_,value)return value end))
 local nativeIterators=setmetatable({},{__mode='kv'})
 for _,name in {'Array','String','Map','Set','URLSearchParams'}do
  local proto=vm.Object({},iteratorProto);c.prototypes[name..'Iterator']=proto
  vm.DefineProperty(proto,wellKnown.toStringTag,vm.Object({value=name..' Iterator',configurable=true},VM.Null))
  c.method(proto,'next',0,function(_,value)
   local r=nativeIterators[value];if not r or r.Kind~=name then c.fail('TypeError',name..' iterator next called on an incompatible receiver')end
   if r.Completed then return vm.Object({value=U,done=true},nil,{'value','done'})end
   step();local more,item=r.Advance()
   if not more then r.Completed=true;r.Advance=nil;return vm.Object({value=U,done=true},nil,{'value','done'})end
   return vm.Object({value=item,done=false},nil,{'value','done'})
  end)
 end
 function c.CreateNativeIterator(kind,advance)
  local iterator=vm.Object({},c.prototypes[kind..'Iterator']);iterator.Kind='iterator'
  local r={Kind=kind,Advance=advance,Completed=false};iterator.NativeIteratorState=r;nativeIterators[iterator]=r;return iterator
 end
 function c.ClearNativeIterators()
  for _,r in nativeIterators do r.Completed=true;r.Advance=nil end;table.clear(nativeIterators)
 end
 -- Existing arrays/strings and URL query pairs join the same iterator protocol.
 c.define(c.prototypes.Array,wellKnown.iterator,get(c.prototypes.Array,'values'))
 c.define(c.prototypes.URLSearchParams,wellKnown.iterator,get(c.prototypes.URLSearchParams,'entries'))
 c.define(c.prototypes.URL,wellKnown.toStringTag,'URL');c.define(c.prototypes.URLSearchParams,wellKnown.toStringTag,'URLSearchParams')
 c.define(c.prototypes.String,wellKnown.iterator,c.native('[Symbol.iterator]',0,function(_,value)
  if value==U or value==N then c.fail('TypeError','String iterator requires receiver')end
  local codes=Strings.codes(c.text(value))
  return c.CreateNativeIterator('String',function()local code=codes();return code~=nil,if code==nil then U else Strings.fromUnits({code})end)
 end))
 vm.SymbolMethod=function(value,key)return get(symbolProto,key,value)end

 local nan={};local bigintKeys=setmetatable({},{__mode='v'})
 local function key(value)
  if BigInt.is(value)then local hash=bigintKeys[value.Canonical];if not hash then hash={};bigintKeys[value.Canonical]=hash end;return hash end
  return if type(value)=='number'and value~=value then nan elseif type(value)=='number'and value==0 then 0 else value
 end
 local function canonical(value)return if type(value)=='number'and value==0 then 0 else value end
 local function validWeak(value)return c.isObject(value)or type(value)=='function'or(symbol(value)and not value.Registered)end
 local mapProto,setProto=vm.Object({},c.prototypes.Object),vm.Object({},c.prototypes.Object)
 c.prototypes.Map,c.prototypes.Set=mapProto,setProto
 local function check(value,kind)
  if not c.isObject(value)or value.Kind~=kind then c.fail('TypeError',kind..' method called on incompatible receiver')end;return value
 end
 for _,kind in {'map','set'}do
  local proto=if kind=='map'then mapProto else setProto
  vm.DefineProperty(proto,'size',vm.Object({get=c.native('get size',0,function(_,value)return check(value,kind).Size end),enumerable=false,configurable=true},VM.Null))
 end
 local function create(kind,newTarget)
  local value=vm.Object({},c.constructPrototype(newTarget,if kind=='map'then mapProto else setProto));value.Kind=kind;value.Entries={};value.ByKey={};value.Size=0
  return value
 end
 local function add(value,entryKey,item)
  local hash=key(entryKey);local entry=value.ByKey[hash]
  if entry then entry.Value=item;return value end
  c.bound(value.Size+1);if #value.Entries>=65536 then c.fail('RangeError','Collection insertion budget exceeded')end
  entry={Key=canonical(entryKey),Value=item,Active=true};table.insert(value.Entries,entry);value.ByKey[hash]=entry;value.Size+=1;return value
 end
 local function remove(value,entryKey)
  local hash=key(entryKey);local entry=value.ByKey[hash];if not entry then return false end
  value.ByKey[hash]=nil;entry.Active=false;entry.Key=nil;entry.Value=nil;value.Size-=1;return true
 end
 local function consume(init,action)
  local nextValue,close=vm.Iterator(init)
  while true do
   step();local more,value=nextValue();if not more then break end
   local ok,result=pcall(action,value)
   if not ok then if close then pcall(close)end;error(result,0)end
  end
 end
 local function constructMap(args,newTarget)
  local value=create('map',newTarget);local init=c.arg(args,1,U);if init==U or init==N then return value end
  local adder=c.requireCallback(get(value,'set'));consume(init,function(pair)
   if not c.isObject(pair)then c.fail('TypeError','Map iterator value is not an entry object')end
   vm:Call(adder,{get(pair,'0'),get(pair,'1')},value)
  end);return value
 end
 local function constructSet(args,newTarget)
  local value=create('set',newTarget);local init=c.arg(args,1,U);if init==U or init==N then return value end
  local adder=c.requireCallback(get(value,'add'));consume(init,function(item)vm:Call(adder,{item},value)end);return value
 end
 local mapConstructor=c.native('Map',0,function()c.fail('TypeError','Map requires new')end,constructMap,{prototype=mapProto})
 local setConstructor=c.native('Set',0,function()c.fail('TypeError','Set requires new')end,constructSet,{prototype=setProto})
 c.define(mapProto,'constructor',mapConstructor);c.define(setProto,'constructor',setConstructor)
 for _,ctor in {mapConstructor,setConstructor}do vm.DefineProperty(ctor,wellKnown.species,vm.Object({get=c.native('get [Symbol.species]',0,function(_,value)return value end),enumerable=false,configurable=true},VM.Null))end
 c.define(mapProto,wellKnown.toStringTag,'Map');c.define(setProto,wellKnown.toStringTag,'Set')
 for _,kind in {'map','set'}do local proto=if kind=='map'then mapProto else setProto
  c.method(proto,'has',1,function(args,value)return check(value,kind).ByKey[key(c.arg(args,1,U))]~=nil end)
  c.method(proto,'delete',1,function(args,value)return remove(check(value,kind),c.arg(args,1,U))end)
  c.method(proto,'clear',0,function(_,value)
   value=check(value,kind);for _,entry in value.Entries do step();entry.Active=false;entry.Key=nil;entry.Value=nil end;table.clear(value.ByKey);value.Size=0;return U
  end)
  c.method(proto,'forEach',1,function(args,value)
   value=check(value,kind);local callback=c.requireCallback(c.arg(args,1,U));local index=1
   while index<=#value.Entries do step();local entry=value.Entries[index];index+=1;if not entry.Active then continue end
    vm:Call(callback,{entry.Value,entry.Key,value},c.arg(args,2,U))
   end;return U
  end)
  for _,name in {'keys','values','entries'}do c.method(proto,name,0,function(_,value)
   value=check(value,kind);local index=1
   return c.CreateNativeIterator(if kind=='map'then 'Map'else 'Set',function()
    while index<=#value.Entries do step();local entry=value.Entries[index];index+=1;if not entry.Active then continue end
     local item=if name=='keys'then entry.Key elseif name=='values'then entry.Value else vm.Array({entry.Key,entry.Value})
     return true,item
    end;return false,U
   end)
  end)end
 end
 -- Set values and keys are the same function identity in ECMAScript.
 c.define(setProto,'keys',get(setProto,'values'))
 c.define(mapProto,wellKnown.iterator,get(mapProto,'entries'));c.define(setProto,wellKnown.iterator,get(setProto,'values'))
 c.method(mapProto,'get',1,function(args,value)local entry=check(value,'map').ByKey[key(c.arg(args,1,U))];return if entry then entry.Value else U end)
 c.method(mapProto,'set',2,function(args,value)return add(check(value,'map'),c.arg(args,1,U),c.arg(args,2,U))end)
 c.method(setProto,'add',1,function(args,value)local item=c.arg(args,1,U);return add(check(value,'set'),item,canonical(item))end)
 c.method(mapConstructor,'groupBy',2,function(args)
  local callback=c.requireCallback(c.arg(args,2,U));local out=create('map');local index=0
  consume(c.arg(args,1,U),function(value)
   local groupKey=vm:Call(callback,{value,index},U);local entry=out.ByKey[key(groupKey)];local group
   if entry then group=entry.Value else group=c.array(0);add(out,groupKey,group)end
   c.bound(group.Length+1);c.create(group,tostring(group.Length),value);index+=1;c.bound(index)
  end);return out
 end)
 local function setRecord(other)
  if not c.isObject(other)then c.fail('TypeError','Set operand must be an object')end
  local size=c.number(get(other,'size'));if size~=size then c.fail('TypeError','Set operand size is NaN')end
  size=c.integer(size);if size<0 then c.fail('RangeError','Set operand size is negative')end
  local has=c.requireCallback(get(other,'has'));local keys=c.requireCallback(get(other,'keys'))
  return {Object=other,Size=size,Has=has,Keys=keys}
 end
 local function otherKeys(record)
  local iterator=vm:Call(record.Keys,{},record.Object);if not c.isObject(iterator)then c.fail('TypeError','Set keys() must return an iterator')end
  local nextMethod=c.requireCallback(get(iterator,'next'));local done=false
  return function()
   if done then return false,U end;step();local result=vm:Call(nextMethod,{},iterator);if not c.isObject(result)then c.fail('TypeError','Iterator result must be an object')end
   if VM.truth(get(result,'done'))then done=true;return false,U end;return true,get(result,'value')
  end,function()
   if done then return end;done=true;local close=get(iterator,'return');if close~=U then local result=vm:Call(c.requireCallback(close),{},iterator);if not c.isObject(result)then c.fail('TypeError','Iterator return result must be an object')end end
  end
 end
 local function copySet(value)local out=create('set');for _,entry in value.Entries do if entry.Active then add(out,entry.Key,entry.Key)end end;return out end
 for _,name in {'union','intersection','difference','symmetricDifference','isSubsetOf','isSupersetOf','isDisjointFrom'}do c.method(setProto,name,1,function(args,value)
  value=check(value,'set');local other=setRecord(c.arg(args,1,U));local out=if name=='intersection'then create('set')else copySet(value)
  local function otherHas(item)return VM.truth(vm:Call(other.Has,{item},other.Object))end
  if name=='isSubsetOf'then
   if value.Size>other.Size then return false end;for _,entry in value.Entries do step();if entry.Active and not otherHas(entry.Key)then return false end end;return true
  elseif name=='isSupersetOf'then
   if value.Size<other.Size then return false end;local nextValue,close=otherKeys(other);while true do local more,item=nextValue();if not more then return true end;if not value.ByKey[key(item)]then close();return false end end
  elseif name=='isDisjointFrom'and value.Size<=other.Size then
   for _,entry in value.Entries do step();if entry.Active and otherHas(entry.Key)then return false end end;return true
  elseif(name=='intersection'or name=='difference')and value.Size<=other.Size then
   for _,entry in value.Entries do step();if not entry.Active then continue end;local item=entry.Key;local found=otherHas(item)
    if name=='intersection'and found then add(out,item,item)elseif name=='difference'and found then remove(out,item)end
   end;return out
  end
  local nextValue,close=otherKeys(other);while true do local more,item=nextValue();if not more then break end;item=canonical(item);local own=value.ByKey[key(item)]~=nil
   if name=='union'then add(out,item,item)elseif name=='intersection'and own then add(out,item,item)elseif name=='difference'then remove(out,item)
   elseif name=='symmetricDifference'then if own then remove(out,item)else add(out,item,item)end
   elseif name=='isDisjointFrom'and own then close();return false end
  end;return if name=='isDisjointFrom'then true else out
 end)end
 c.global('Map',mapConstructor);c.global('Set',setConstructor)

 for _,kind in {'weak-map','weak-set'}do
  local name=if kind=='weak-map'then 'WeakMap'else 'WeakSet';local proto=vm.Object({},c.prototypes.Object);c.prototypes[name]=proto
  local function createWeak(args,newTarget)
   local value=vm.Object({},c.constructPrototype(newTarget,proto));value.Kind=kind;value.Data=setmetatable({},{__mode='k'});value.InsertionCount=0
   local init=c.arg(args,1,U);if init==U or init==N then return value end;local adder=c.requireCallback(get(value,if kind=='weak-map'then 'set'else 'add'))
   consume(init,function(entry)
    if kind=='weak-map'then if not c.isObject(entry)then c.fail('TypeError','WeakMap entry must be an object')end;vm:Call(adder,{get(entry,'0'),get(entry,'1')},value)
    else vm:Call(adder,{entry},value)end
   end);return value
  end
  local ctor=c.native(name,0,function()c.fail('TypeError',name..' requires new')end,createWeak,{prototype=proto});c.define(proto,'constructor',ctor);c.define(proto,wellKnown.toStringTag,name)
  c.method(proto,'has',1,function(args,value)value=check(value,kind);local item=c.arg(args,1,U);return validWeak(item)and value.Data[item]~=nil end)
  c.method(proto,'delete',1,function(args,value)value=check(value,kind);local item=c.arg(args,1,U);if not validWeak(item)or value.Data[item]==nil then return false end;value.Data[item]=nil;return true end)
  local function weakInsert(value,item,data)
   if not validWeak(item)then c.fail('TypeError','Invalid weak collection key')end
   if value.Data[item]==nil then
    if value.InsertionCount>=16384 then c.fail('RangeError','Weak collection insertion budget exceeded')end;value.InsertionCount+=1
   end;value.Data[item]=data;return value
  end
  if kind=='weak-map'then
   c.method(proto,'get',1,function(args,value)value=check(value,kind);local item=c.arg(args,1,U);return if validWeak(item)and value.Data[item]~=nil then value.Data[item]else U end)
   c.method(proto,'set',2,function(args,value)return weakInsert(check(value,kind),c.arg(args,1,U),c.arg(args,2,U))end)
  else c.method(proto,'add',1,function(args,value)return weakInsert(check(value,kind),c.arg(args,1,U),true)end)end
  c.global(name,ctor)
 end
 vm.Collections={WellKnown=wellKnown,Registry=registry}
end
return Collections
