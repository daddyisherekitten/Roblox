--!strict
-- Bounded ECMAScript library for an individual VM realm. All user callbacks and
-- property operations pass through the VM so accessors, holes and budgets remain
-- observable. Locale data, RegExp and full Unicode normalization are separate.
local Strings=require(script.Parent.Strings)
local Numbers=require(script.Parent.LibraryNumbers)
local JSON=require(script.Parent.LibraryJSON)
local Dates=require(script.Parent.LibraryDate)
local URLs=require(script.Parent.LibraryURL)
local StringNormalization=require(script.Parent.LibraryStringNormalization)
local Collections=require(script.Parent.Collections)
local BigInt=require(script.Parent.BigInt)
local StandardLibrary={}

function StandardLibrary.install(vm: any,globals: any?,options: any?): any
 if vm.StandardLibrary then return vm.StandardLibrary end
 options=options or {};globals=globals or {}
 local VM=options.VM or vm.Model
 assert(VM,'StandardLibrary.install requires vm.Model or options.VM')
 local U,N=VM.Undefined,VM.Null
 local get,set,step=vm.Get,vm.Set,vm.Step
 local MAX_ARRAY,MAX_STRING=16384,65536
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function arg(args,index,default)return if args[index]==nil or args[index]==U then default else args[index] end
 local function isObject(value)return type(value)=='table'and value~=U and value~=N and value.Kind~='symbol'and value.Kind~='bigint'end
 local function isArray(value)return if vm.IsArray then vm.IsArray(value)else type(value)=='table'and value.Kind=='array'end
 local function number(value)
  if vm.ToPrimitive then value=vm.ToPrimitive(value,'number')end
  if type(value)=='table'and value.Kind=='symbol'then fail('TypeError','Cannot convert a Symbol value to a number')end
  return VM.number(value)
 end
 local function integer(value)
  local n=number(value);if n~=n or n==0 then return 0 end
  return if n<0 then math.ceil(n) else math.floor(n)
 end
 local function length(value)
  local n=integer(get(value,'length'));return math.clamp(n,0,9007199254740991)
 end
 local function bound(size)
  if size>MAX_ARRAY then fail('RangeError','JavaScript array budget exceeded') end
  return size
 end
 local function text(value)
  if vm.ToPrimitive then value=vm.ToPrimitive(value,'string')end
  if type(value)=='table'and value.Kind=='symbol'then fail('TypeError','Cannot convert a Symbol value to a string')end
  local result=VM.string(value);if #result>MAX_STRING then fail('RangeError','JavaScript string budget exceeded') end;return result
 end
 local function stringResult(value)
  if #value>MAX_STRING then fail('RangeError','JavaScript string budget exceeded') end;return Strings.canonical(value)
 end
 local function relative(value,size,default)
  local n=if value==nil or value==U then default or 0 else integer(value)
  return if n<0 then math.max(size+n,0) else math.min(n,size)
 end
 local function same(a,b)return BigInt.Equal(a,b)or a==b or (type(a)=='number'and type(b)=='number'and a~=a and b~=b)end
 local function sameValue(a,b)
  if not same(a,b) then return false end
  return not(type(a)=='number'and a==0 and 1/a~=1/b)
 end
 local function hasOwn(value,key)return vm.HasOwn(value,key)end
 local function has(value,key)return vm.Has(value,key)end
 local function delete(value,key)return vm.Delete(value,key)end
 local function keys(value,enumerable)return vm.OwnKeys(value,enumerable)end
 local function enumerableStringKeys(value)
  local out={};for _,key in keys(value,false)do if type(key)=='string'then step();local d=vm.GetOwnPropertyDescriptor(value,key)
   if d~=U and VM.truth(get(d,'enumerable'))then table.insert(out,key)end
  end end;return out
 end
 local prototypes=vm.Prototypes or {};vm.Prototypes=prototypes
 local objectProto=vm.Object({},N);prototypes.Object=objectProto
 for _,name in {'Array','String','Number','Boolean','Function'}do prototypes[name]=vm.Object({},objectProto)end
 prototypes.Function.Kind='native-function';prototypes.Function.Call=function()return U end
 prototypes.Array=vm.Array({});prototypes.Array.Prototype=objectProto
 for _,entry in {{'String','string',''},{'Number','number',0},{'Boolean','boolean',false}}do
  local proto=prototypes[entry[1]];proto.Kind='boxed-'..entry[2];proto.PrimitiveValue=entry[3]
 end
 local function native(name,arity,action,construct,properties)
  local values=properties or {};values.name=name;values.length=arity
  local descriptors={};for key,value in values do descriptors[key]={Value=value,Writable=false,Enumerable=false,Configurable=key=='name'or key=='length'}end
  local fn={Kind='native-function',Values=values,Descriptors=descriptors,Call=action,Construct=construct,Prototype=prototypes.Function,VMOwner=vm}
  fn.Get=function(key)
   if values[key]~=nil then return values[key] end
   return get(fn.Prototype,key)
  end
  fn.Set=function(key,value)values[key]=value end
  return fn
 end
 local function descriptorObject(fields)return vm.Object(fields,N)end
 local function define(target,key,value)
  vm.DefineProperty(target,key,descriptorObject({value=value,writable=true,enumerable=false,configurable=true}))
 end
 vm.DefineProperty(prototypes.String,'length',descriptorObject({value=0,writable=false,enumerable=false,configurable=false}))
 local function method(target,name,arity,action)define(target,name,native(name,arity,action))end
 local function global(name,value)
  globals[name]=value;vm.Global.Bindings[name]={Value=value,Const=false}
  local window=globals.globalThis or globals.window
  if isObject(window)then set(window,name,value)end
 end
 local function array(size)
  bound(size or 0);local result=vm.Array({});result.Length=size or 0;return result
 end
 local function create(target,key,value)vm.DefineProperty(target,key,descriptorObject({value=value,writable=true,enumerable=true,configurable=true}))end
 local function constructPrototype(newTarget,fallback)
  if newTarget==nil then return fallback end
  local prototype=get(newTarget,'prototype')
  if isObject(prototype)or type(prototype)=='function'then return prototype end
  local realm=if vm.FunctionRealm then vm.FunctionRealm(newTarget)elseif type(newTarget)=='table'then newTarget.VMOwner else nil
  if realm and realm~=vm then for name,value in prototypes do if value==fallback then return realm.Prototypes[name]or fallback end end end
  return fallback
 end
 vm.DefineProperty(prototypes.Function,'name',descriptorObject({value='',writable=false,enumerable=false,configurable=true}))
 vm.DefineProperty(prototypes.Function,'length',descriptorObject({value=0,writable=false,enumerable=false,configurable=true}))
 local function requireObject(value)
  if value==nil or value==U or value==N then fail('TypeError','Cannot convert undefined or null to object')end
  if isObject(value)then return value end
  if BigInt.is(value)then local box=vm.Object({},prototypes.BigInt);box.Kind='boxed-bigint';box.PrimitiveValue=value;return box end
  if type(value)=='table'and value.Kind=='symbol'then
   local box=vm.Object({},prototypes.Symbol);box.Kind='boxed-symbol';box.PrimitiveValue=value;return box
  end
  local kind=type(value);local proto=if kind=='string'then prototypes.String elseif kind=='number'then prototypes.Number else prototypes.Boolean
  local box=vm.Object({},proto);box.Kind='boxed-'..kind;box.PrimitiveValue=value
  if kind=='string'then
   local units=Strings.units(value)
   for i,unit in units do vm.DefineProperty(box,tostring(i-1),descriptorObject({value=Strings.fromUnits({unit}),writable=false,enumerable=true,configurable=false}))end
   vm.DefineProperty(box,'length',descriptorObject({value=#units,writable=false,enumerable=false,configurable=false}))
  end
  return box
 end
 vm.ToObject=requireObject
 local function requireCallback(value)
  if not VM.callable(value)then fail('TypeError','Callback is not callable')end;return value
 end
 local function stringReceiver(value)
  if value==nil or value==U or value==N then fail('TypeError','String method requires a receiver')end
  if isObject(value)and value.Kind=='boxed-string'then return value.PrimitiveValue end
  return text(value)
 end
 local function primitiveReceiver(value,kind)
  if type(value)==kind then return value end
  if isObject(value)and value.Kind=='boxed-'..kind then return value.PrimitiveValue end
  fail('TypeError',kind..' method called on incompatible receiver')
 end
 local context={VM=VM,vm=vm,U=U,N=N,get=get,set=set,step=step,fail=fail,arg=arg,isObject=isObject,isArray=isArray,number=number,
  integer=integer,length=length,bound=bound,text=text,stringResult=stringResult,relative=relative,same=same,
  hasOwn=hasOwn,has=has,delete=delete,keys=keys,enumerableStringKeys=enumerableStringKeys,native=native,method=method,define=define,global=global,
  array=array,create=create,constructPrototype=constructPrototype,requireObject=requireObject,requireCallback=requireCallback,prototypes=prototypes,options=options}

 -- Object primitives and descriptor operations share the interpreter's model.
 local objectConstructor
 local function constructObject(args,newTarget)
  if newTarget~=nil and newTarget~=objectConstructor then return vm.Object({},constructPrototype(newTarget,objectProto))end
  return if args[1]==nil or args[1]==U or args[1]==N then vm.Object({})else requireObject(args[1])
 end
 objectConstructor=native('Object',1,function(args)return constructObject(args)end,constructObject,{prototype=objectProto})
 define(objectProto,'constructor',objectConstructor)
 vm.DefineProperty(objectProto,'__proto__',descriptorObject({
  get=native('get __proto__',0,function(_,receiver)return vm.GetPrototype(requireObject(receiver))end),
  set=native('set __proto__',1,function(args,receiver)
   requireObject(receiver);local prototype=arg(args,1,U)
   if(prototype==N or isObject(prototype))and isObject(receiver)then vm.SetPrototype(receiver,prototype)end;return U
  end),enumerable=false,configurable=true}))
 method(objectProto,'hasOwnProperty',1,function(args,receiver)return hasOwn(requireObject(receiver),arg(args,1,U))end)
 method(objectProto,'propertyIsEnumerable',1,function(args,receiver)
  local descriptor=vm.GetOwnPropertyDescriptor(requireObject(receiver),arg(args,1,U))
  return descriptor~=U and VM.truth(get(descriptor,'enumerable'))
 end)
 method(objectProto,'isPrototypeOf',1,function(args,receiver)
  local candidate=arg(args,1,U);if not isObject(candidate)then return false end
  local proto=requireObject(receiver);local seen={}
  while isObject(candidate)do step();candidate=vm.GetPrototype(candidate);if candidate==proto then return true end;if seen[candidate]then break end;seen[candidate]=true end
  return false
 end)
 method(objectProto,'valueOf',0,function(_,receiver)return requireObject(receiver)end)
 method(objectProto,'toString',0,function(_,receiver)
  if receiver==U or receiver==nil then return '[object Undefined]'elseif receiver==N then return '[object Null]'end
  local tag=if type(receiver)=='string'then 'String'elseif type(receiver)=='number'then 'Number'elseif type(receiver)=='boolean'then 'Boolean'elseif isArray(receiver)then 'Array'elseif VM.callable(receiver)then 'Function'elseif receiver.Kind=='boxed-string'then 'String'elseif receiver.Kind=='boxed-number'then 'Number'elseif receiver.Kind=='boxed-boolean'then 'Boolean'elseif receiver.Kind=='boxed-symbol'or receiver.Kind=='symbol'then 'Symbol'elseif receiver.Kind=='boxed-bigint'or receiver.Kind=='bigint'then 'BigInt'elseif receiver.Kind=='date'then 'Date'elseif receiver.Kind=='error'then 'Error'elseif receiver.RegExpState then 'RegExp'else 'Object'
  if vm.SymbolToStringTag then local custom=get(receiver,vm.SymbolToStringTag);if type(custom)=='string'then tag=custom end end
  return '[object '..tag..']'
 end)
 for _,name in {'keys','values','entries','getOwnPropertyNames','getOwnPropertySymbols'}do
  method(objectConstructor,name,1,function(args)
   local target=requireObject(arg(args,1,U));local out=array(0)
   for _,key in keys(target,false)do
   step();local symbol=type(key)=='table'and key.Kind=='symbol'
   if (name=='getOwnPropertySymbols')~=symbol then continue end
    if name=='keys'or name=='values'or name=='entries'then
     local descriptor=vm.GetOwnPropertyDescriptor(target,key)
     if descriptor==U or not VM.truth(get(descriptor,'enumerable'))then continue end
    end
    local item=if name=='values'then get(target,key)elseif name=='entries'then vm.Array({key,get(target,key)})else key
    create(out,tostring(out.Length),item)
   end
   return out
  end)
 end
 method(objectConstructor,'hasOwn',2,function(args)return hasOwn(requireObject(arg(args,1,U)),arg(args,2,U))end)
 method(objectConstructor,'is',2,function(args)return sameValue(arg(args,1,U),arg(args,2,U))end)
 method(objectConstructor,'assign',2,function(args)
  local target=requireObject(arg(args,1,U))
  for i=2,#args do local source=args[i];if source==N or source==U then continue end;source=requireObject(source)
   for _,key in keys(source,false)do step();local descriptor=vm.GetOwnPropertyDescriptor(source,key)
    if descriptor~=U and VM.truth(get(descriptor,'enumerable'))then set(target,key,get(source,key))end
   end
  end;return target
 end)
 method(objectConstructor,'fromEntries',1,function(args)
  local out=vm.Object({});local nextValue,close=vm.Iterator(arg(args,1,U));local count=0
  local ok,result=pcall(function()
   while true do step();local more,pair=nextValue();if not more then break end
    if not isObject(pair)then fail('TypeError','Iterator value is not an entry object')end
    local key,item=get(pair,'0'),get(pair,'1');if vm.PropertyKey then key=vm.PropertyKey(key)end
    vm.DefineProperty(out,key,descriptorObject({value=item,writable=true,enumerable=true,configurable=true}));count+=1;bound(count)
   end
  end);if not ok then if close then pcall(close)end;error(result,0)end;return out
 end)
 local function descriptor(value)
  if not isObject(value)then fail('TypeError','Property description must be an object')end
  local fields={};for _,key in {'enumerable','configurable','value','writable','get','set'}do
   if has(value,key)then local item=get(value,key)
    if(key=='get'or key=='set')and item~=U and not VM.callable(item)then fail('TypeError','Accessor must be callable or undefined')end
    fields[key]=if key=='enumerable'or key=='configurable'or key=='writable'then VM.truth(item)else item
   end
  end
  if(fields.get~=nil or fields.set~=nil)and(fields.value~=nil or fields.writable~=nil)then fail('TypeError','Invalid mixed property descriptor')end
  return descriptorObject(fields)
 end
 local function defineProperties(target,source)
  source=requireObject(source);local pending={}
  for _,key in keys(source,false)do local own=vm.GetOwnPropertyDescriptor(source,key)
   if own~=U and VM.truth(get(own,'enumerable'))then table.insert(pending,{key,descriptor(get(source,key))})end
  end
  for _,entry in pending do vm.DefineProperty(target,entry[1],entry[2])end;return target
 end
 method(objectConstructor,'create',2,function(args)
  local prototype=arg(args,1,U);if prototype~=N and not isObject(prototype)then fail('TypeError','Object prototype must be object or null')end
  local out=vm.Object({},prototype);if args[2]~=nil and args[2]~=U then
   defineProperties(out,args[2])
  end;return out
 end)
 method(objectConstructor,'getPrototypeOf',1,function(args)return vm.GetPrototype(requireObject(arg(args,1,U)))end)
 method(objectConstructor,'setPrototypeOf',2,function(args)
  local target=arg(args,1,U);if target==U or target==N then fail('TypeError','Cannot set prototype of null or undefined')end
  local prototype=arg(args,2,U);if prototype~=N and not isObject(prototype)then fail('TypeError','Object prototype must be object or null')end
  if isObject(target)then vm.SetPrototype(target,prototype)end;return target
 end)
 method(objectConstructor,'getOwnPropertyDescriptor',2,function(args)return vm.GetOwnPropertyDescriptor(requireObject(arg(args,1,U)),arg(args,2,U))end)
 method(objectConstructor,'getOwnPropertyDescriptors',1,function(args)
  local target=requireObject(arg(args,1,U));local out=vm.Object({})
  for _,key in keys(target,false)do local d=vm.GetOwnPropertyDescriptor(target,key);if d~=U then vm.DefineProperty(out,key,descriptorObject({value=d,writable=true,enumerable=true,configurable=true}))end end;return out
 end)
 method(objectConstructor,'defineProperty',3,function(args)
  local target=arg(args,1,U);if not isObject(target)then fail('TypeError','Object.defineProperty requires an object')end
  vm.DefineProperty(target,arg(args,2,U),descriptor(arg(args,3,U)));return target
 end)
 method(objectConstructor,'defineProperties',2,function(args)
  local target=arg(args,1,U);if not isObject(target)then fail('TypeError','Object.defineProperties requires an object')end
  return defineProperties(target,arg(args,2,U))
 end)
 for _,name in {'preventExtensions','seal','freeze'}do method(objectConstructor,name,1,function(args)
  local target=arg(args,1,U);if not isObject(target)then return target end
  vm.PreventExtensions(target)
  if name~='preventExtensions'then for _,key in keys(target,false)do
   local d=descriptorObject({configurable=false})
   if name=='freeze'then local current=vm.GetOwnPropertyDescriptor(target,key);if current==U then continue end;if hasOwn(current,'value')then set(d,'writable',false)end end
   vm.DefineProperty(target,key,d)
  end end;return target
 end)end
 method(objectConstructor,'isExtensible',1,function(args)local target=arg(args,1,U);return isObject(target)and vm.IsExtensible(target)end)
 for _,name in {'isSealed','isFrozen'}do method(objectConstructor,name,1,function(args)
  local target=arg(args,1,U);if not isObject(target)then return true end;if vm.IsExtensible(target)then return false end
  for _,key in keys(target,false)do local d=vm.GetOwnPropertyDescriptor(target,key)
   if VM.truth(get(d,'configurable'))or(name=='isFrozen'and hasOwn(d,'value')and VM.truth(get(d,'writable')))then return false end
  end;return true
 end)end
 method(objectConstructor,'groupBy',2,function(args)
  local callback=requireCallback(arg(args,2,U));local nextValue,close=vm.Iterator(arg(args,1,U));local out=vm.Object({},N);local index=0
  while true do
   local more,value=nextValue();if not more then break end;step()
   local ok,result=pcall(function()
    local key=vm:Call(callback,{value,index},U);key=if vm.PropertyKey then vm.PropertyKey(key)elseif type(key)=='table'and key.Kind=='symbol'then key else text(key)
    local group=get(out,key);if group==U then group=array(0);create(out,key,group)end;create(group,tostring(group.Length),value);index+=1;bound(index)
   end);if not ok then if close then pcall(close)end;error(result,0)end
  end;return out
 end)
 global('Object',objectConstructor)

 -- Array algorithms use HasProperty where the standard skips holes, and Get
 -- where it visits them. Length snapshots and reads remain visible to callbacks.
 local arrayProto=prototypes.Array
 local function arrayReceiver(value)return requireObject(value)end
 local function constructArray(args,newTarget)
  local prototype=constructPrototype(newTarget,arrayProto)
  if #args==1 and type(args[1])=='number'then
   local size=args[1];if size<0 or size~=math.floor(size)or size==math.huge then fail('RangeError','Invalid array length')end
   local out=array(size);out.Prototype=prototype;return out
  end;bound(#args);local out=vm.Array(table.clone(args));out.Prototype=prototype;return out
 end
 local arrayConstructor=native('Array',1,function(args)return constructArray(args)end,constructArray,{prototype=arrayProto})
 vm.Intrinsics=vm.Intrinsics or {};vm.Intrinsics.Array=arrayConstructor
 define(arrayProto,'constructor',arrayConstructor)
 local function speciesArray(receiver,size)
  bound(size)
  if not isArray(receiver)then return array(size)end
  local constructor=get(receiver,'constructor')
  if vm.IsConstructor(constructor)and vm.FunctionRealm then
   local realm=vm.FunctionRealm(constructor)
   if realm~=vm and realm.Intrinsics and constructor==realm.Intrinsics.Array then constructor=U end
  end
  if isObject(constructor)then constructor=get(constructor,vm.SymbolSpecies);if constructor==N then constructor=U end end
  if constructor==U then return array(size)end
  if not vm.IsConstructor(constructor)then fail('TypeError','Array species is not a constructor')end
  return vm:Construct(constructor,{size})
 end
 method(arrayConstructor,'isArray',1,function(args)return isArray(arg(args,1,U))end)
 method(arrayConstructor,'of',0,function(args,receiver)
  local size=bound(#args);local out=if vm.IsConstructor(receiver)then vm:Construct(receiver,{size})else array(size)
  for i,value in args do step();create(out,tostring(i-1),value)end;set(out,'length',size,true);return out
 end)
 method(arrayConstructor,'from',1,function(args,receiver)
  local source=arg(args,1,U);local callback=arg(args,2,U);if callback~=U then requireCallback(callback)end
  requireObject(source);local iteratorMethod=get(source,vm.SymbolIterator)
  if iteratorMethod~=U and iteratorMethod~=N then
   requireCallback(iteratorMethod);local out=if vm.IsConstructor(receiver)then vm:Construct(receiver,{})else array(0)
   local iterator=vm:Call(iteratorMethod,{},source);if not isObject(iterator)then fail('TypeError','Iterator is not an object')end
   local nextMethod=get(iterator,'next');local index=0
   local function closeAbrupt(reason)
    -- An already abrupt completion wins over failures of return(), including
    -- its getter. Failures produced by next/done/value are not closed here.
    pcall(function()local close=get(iterator,'return');if close~=U and close~=N then vm:Call(requireCallback(close),{},iterator)end end)
    error(reason,0)
   end
   while true do
    step();local result=vm:Call(nextMethod,{},iterator);if not isObject(result)then fail('TypeError','Iterator result is not an object')end
    if VM.truth(get(result,'done'))then set(out,'length',index,true);return out end
    local value=get(result,'value');local ok,reason=pcall(function()
     bound(index+1);if callback~=U then value=vm:Call(callback,{value,index},arg(args,3,U))end;create(out,tostring(index),value)
    end)
    if not ok then closeAbrupt(reason)end;index+=1
   end
  else source=requireObject(source);local size=bound(length(source));local out=if vm.IsConstructor(receiver)then vm:Construct(receiver,{size})else array(size)
   for index=0,size-1 do step();local value=get(source,tostring(index));if callback~=U then value=vm:Call(callback,{value,index},arg(args,3,U))end;create(out,tostring(index),value)end
   set(out,'length',size,true);return out
  end
 end)
 method(arrayProto,'at',1,function(args,receiver)
  receiver=arrayReceiver(receiver);local size=length(receiver);local index=integer(arg(args,1,U));if index<0 then index+=size end
  return if index<0 or index>=size then U else get(receiver,tostring(index))
 end)
 method(arrayProto,'push',1,function(args,receiver)
  receiver=arrayReceiver(receiver);local size=length(receiver);bound(size+#args)
  for i,value in args do step();set(receiver,tostring(size+i-1),value)end;set(receiver,'length',size+#args);return size+#args
 end)
 method(arrayProto,'pop',0,function(_,receiver)
  receiver=arrayReceiver(receiver);local size=length(receiver);if size==0 then set(receiver,'length',0);return U end
  local value=get(receiver,tostring(size-1));delete(receiver,tostring(size-1));set(receiver,'length',size-1);return value
 end)
 local joining={}
 method(arrayProto,'join',1,function(args,receiver)
  receiver=arrayReceiver(receiver);if joining[receiver]then return ''end;joining[receiver]=true
  local ok,result=pcall(function()
   local size=bound(length(receiver));local separator=if args[1]==nil or args[1]==U then ','else text(args[1]);local parts={};local bytes=0
   for index=0,size-1 do step();local value=get(receiver,tostring(index));local part=if value==U or value==N then ''else text(value)
    bytes+=#part+(if index>0 then #separator else 0);if bytes>MAX_STRING then fail('RangeError','JavaScript string budget exceeded')end;parts[index+1]=part
   end;return stringResult(table.concat(parts,separator))
  end);joining[receiver]=nil;if not ok then error(result,0)end;return result
 end)
 method(arrayProto,'toString',0,function(_,receiver)
  receiver=arrayReceiver(receiver);local join=get(receiver,'join')
  return if VM.callable(join)then vm:Call(join,{},receiver)else '[object Object]'
 end)
 for _,name in {'forEach','map','filter','every','some','find','findIndex','findLast','findLastIndex'}do method(arrayProto,name,1,function(args,receiver)
  receiver=arrayReceiver(receiver);local size=bound(length(receiver));local callback=requireCallback(arg(args,1,U))
  local out=if name=='map'or name=='filter'then speciesArray(receiver,if name=='map'then size else 0)else nil;local count=0
  local backwards=name=='findLast'or name=='findLastIndex';local visitsHoles=name=='find'or name=='findIndex'or backwards
  for offset=0,size-1 do step();local index=if backwards then size-offset-1 else offset;local key=tostring(index)
   if not visitsHoles and not has(receiver,key)then continue end
   local value=get(receiver,key);local result=vm:Call(callback,{value,index,receiver},arg(args,2,U));local yes=VM.truth(result)
   if name=='map'then create(out,key,result)elseif name=='filter'and yes then create(out,tostring(count),value);count+=1
   elseif name=='every'and not yes then return false elseif name=='some'and yes then return true
   elseif visitsHoles and yes then return if name=='find'or name=='findLast'then value else index end
  end
  if name=='forEach'then return U elseif name=='every'then return true elseif name=='some'then return false
  elseif visitsHoles then return if name=='find'or name=='findLast'then U else -1 end;return out
 end)end
 for _,name in {'includes','indexOf','lastIndexOf'}do method(arrayProto,name,1,function(args,receiver)
  receiver=arrayReceiver(receiver);local size=bound(length(receiver));if size==0 then return if name=='includes'then false else -1 end
  local backwards=name=='lastIndexOf';local start=if backwards and args[2]==nil then size-1 else integer(arg(args,2,U))
  if start<0 then start+=size end
  if backwards then start=math.min(start,size-1)else start=math.max(start,0)end
  local index=start
  while if backwards then index>=0 else index<size do step();local key=tostring(index)
    if name=='includes'or has(receiver,key)then local value=get(receiver,key);local matches=if name=='includes'then same(value,arg(args,1,U))else BigInt.Equal(value,arg(args,1,U))or value==arg(args,1,U)
   if matches then return if name=='includes'then true else index end
   end;index+=if backwards then -1 else 1
  end;return if name=='includes'then false else -1
 end)end
 for _,name in {'reduce','reduceRight'}do method(arrayProto,name,1,function(args,receiver)
  receiver=arrayReceiver(receiver);local size=bound(length(receiver));local callback=requireCallback(arg(args,1,U));local present=#args>=2;local accumulator=args[2]
  for offset=0,size-1 do step();local index=if name=='reduceRight'then size-offset-1 else offset;local key=tostring(index)
   if has(receiver,key)then local value=get(receiver,key);if not present then accumulator=value;present=true else accumulator=vm:Call(callback,{accumulator,value,index,receiver},U)end end
  end;if not present then fail('TypeError','Reduce of empty array with no initial value')end;return accumulator
 end)end
 method(arrayProto,'slice',2,function(args,receiver)
  receiver=arrayReceiver(receiver);local size=bound(length(receiver));local first,last=relative(args[1],size),relative(args[2],size,size);local count=math.max(last-first,0);local out=speciesArray(receiver,count)
  for offset=0,count-1 do step();local key=tostring(first+offset);if has(receiver,key)then create(out,tostring(offset),get(receiver,key))end end;set(out,'length',count,true);return out
 end)
 method(arrayProto,'concat',1,function(args,receiver)
  receiver=requireObject(receiver);local out=speciesArray(receiver,0);local count=0;local sources={receiver};for _,v in args do table.insert(sources,v)end
  for _,source in sources do
   local marker=if isObject(source)and vm.SymbolIsConcatSpreadable then get(source,vm.SymbolIsConcatSpreadable)else U
   local spread=if marker~=U then VM.truth(marker)else isArray(source)
   if spread then local size=bound(length(source));local first=count;bound(first+size);count+=size
    for i=0,size-1 do step();if has(source,tostring(i))then create(out,tostring(first+i),get(source,tostring(i)))end end
   else bound(count+1);create(out,tostring(count),source);count+=1 end
  end;set(out,'length',count,true);return out
 end)
 method(arrayProto,'fill',1,function(args,receiver)
  receiver=arrayReceiver(receiver);local size=bound(length(receiver));local first,last=relative(args[2],size),relative(args[3],size,size)
  for i=first,last-1 do step();set(receiver,tostring(i),arg(args,1,U))end;return receiver
 end)
 method(arrayProto,'copyWithin',2,function(args,receiver)
  receiver=arrayReceiver(receiver);local size=bound(length(receiver));local target,first,last=relative(args[1],size),relative(args[2],size),relative(args[3],size,size)
  local count=math.min(last-first,size-target);local direction=1;if first<target and target<first+count then direction=-1;first+=count-1;target+=count-1 end
  for _=1,count do step();if has(receiver,tostring(first))then set(receiver,tostring(target),get(receiver,tostring(first)))else delete(receiver,tostring(target))end;first+=direction;target+=direction end;return receiver
 end)
 for _,name in {'reverse','toReversed'}do method(arrayProto,name,0,function(_,receiver)
  receiver=arrayReceiver(receiver);local size=bound(length(receiver))
  if name=='toReversed'then local out=array(size);for i=0,size-1 do step();create(out,tostring(i),get(receiver,tostring(size-i-1)))end;return out end
  for i=0,math.floor(size/2)-1 do step();local lower,upper=tostring(i),tostring(size-i-1);local a,b=has(receiver,lower),has(receiver,upper);local av,bv=if a then get(receiver,lower)else U,if b then get(receiver,upper)else U
   if b then set(receiver,lower,bv)else delete(receiver,lower)end;if a then set(receiver,upper,av)else delete(receiver,upper)end
  end;return receiver
 end)end
 method(arrayProto,'shift',0,function(_,receiver)
  receiver=arrayReceiver(receiver);local size=bound(length(receiver));if size==0 then set(receiver,'length',0);return U end
  local first=get(receiver,'0');for i=1,size-1 do step();if has(receiver,tostring(i))then set(receiver,tostring(i-1),get(receiver,tostring(i)))else delete(receiver,tostring(i-1))end end
  delete(receiver,tostring(size-1));set(receiver,'length',size-1);return first
 end)
 method(arrayProto,'unshift',1,function(args,receiver)
  receiver=arrayReceiver(receiver);local size=bound(length(receiver));bound(size+#args)
  for i=size-1,0,-1 do step();if has(receiver,tostring(i))then set(receiver,tostring(i+#args),get(receiver,tostring(i)))else delete(receiver,tostring(i+#args))end end
  for i,value in args do set(receiver,tostring(i-1),value)end;set(receiver,'length',size+#args);return size+#args
 end)
 local function splice(args,receiver,copy)
  receiver=arrayReceiver(receiver);local size=bound(length(receiver));local first=relative(args[1],size);local removed=if #args==0 then 0 elseif #args==1 then size-first else math.clamp(integer(arg(args,2,U)),0,size-first)
  local added=math.max(#args-2,0);local nextSize=bound(size-removed+added)
  if copy then local out=array(nextSize)
   for i=0,first-1 do step();create(out,tostring(i),get(receiver,tostring(i)))end
   for i=1,added do create(out,tostring(first+i-1),args[i+2])end
   for i=first+removed,size-1 do step();create(out,tostring(i-removed+added),get(receiver,tostring(i)))end;return out
  end
  local out=speciesArray(receiver,removed);for i=0,removed-1 do if has(receiver,tostring(first+i))then create(out,tostring(i),get(receiver,tostring(first+i)))end end
  set(out,'length',removed,true)
  if added<removed then
   for i=first,size-removed-1 do step();local source=tostring(i+removed);if has(receiver,source)then set(receiver,tostring(i+added),get(receiver,source))else delete(receiver,tostring(i+added))end end
   for i=size-1,nextSize,-1 do delete(receiver,tostring(i))end
  elseif added>removed then
   for i=size-removed-1,first,-1 do step();local source=tostring(i+removed);if has(receiver,source)then set(receiver,tostring(i+added),get(receiver,source))else delete(receiver,tostring(i+added))end end
  end
  for i=1,added do set(receiver,tostring(first+i-1),args[i+2])end;set(receiver,'length',nextSize);return out
 end
 method(arrayProto,'splice',2,function(args,receiver)return splice(args,receiver,false)end)
 method(arrayProto,'toSpliced',2,function(args,receiver)return splice(args,receiver,true)end)
 method(arrayProto,'with',2,function(args,receiver)
  receiver=arrayReceiver(receiver);local size=bound(length(receiver));local index=integer(arg(args,1,U));if index<0 then index+=size end
  if index<0 or index>=size then fail('RangeError','Array index is out of range')end
  local out=array(size);for i=0,size-1 do step();create(out,tostring(i),if i==index then arg(args,2,U)else get(receiver,tostring(i)))end;return out
 end)
 for _,name in {'flat','flatMap'}do method(arrayProto,name,if name=='flat'then 0 else 1,function(args,receiver)
  receiver=arrayReceiver(receiver);local initialSize=bound(length(receiver));local depth=if name=='flatMap'then 1 else math.max(integer(arg(args,1,1)),0);local callback=if name=='flatMap'then requireCallback(arg(args,1,U))else nil;local out=speciesArray(receiver,0);local count=0
  local function flatten(source,remaining,level,snapshot)
   if level>64 then fail('RangeError','Array flatten depth exceeded')end
   local size=snapshot or bound(length(source));for i=0,size-1 do step();if not has(source,tostring(i))then continue end;local value=get(source,tostring(i))
    if callback and level==0 then value=vm:Call(callback,{value,i,receiver},arg(args,2,U))end
    if remaining>0 and isArray(value)then flatten(value,remaining-1,level+1)else bound(count+1);create(out,tostring(count),value);count+=1 end
   end
  end;flatten(receiver,depth,0,initialSize);return out
 end)end
 for _,name in {'sort','toSorted'}do method(arrayProto,name,1,function(args,receiver)
  receiver=arrayReceiver(receiver);local size=bound(length(receiver));local compare=arg(args,1,U);if compare~=U then requireCallback(compare)end;local values={}
  for i=0,size-1 do step();if name=='toSorted'or has(receiver,tostring(i))then table.insert(values,get(receiver,tostring(i)))end end
  local function less(a,b)
   if a==U then return false elseif b==U then return true end
   if compare~=U then local n=number(vm:Call(compare,{a,b},U));return n<0 end
   local x,y=Strings.units(text(a)),Strings.units(text(b));for i=1,math.min(#x,#y)do if x[i]~=y[i]then return x[i]<y[i]end end;return #x<#y
  end
  -- Stable bottom-up merge sorting avoids a host comparator's undefined result
  -- for inconsistent callbacks and charges each comparison to the VM budget.
  local width=1;while width<#values do local nextValues={}
   for first=1,#values,width*2 do local a,b=first,first+width;local lastA,lastB=math.min(first+width-1,#values),math.min(first+width*2-1,#values)
    for output=first,lastB do step();if a<=lastA and(b>lastB or not less(values[b],values[a]))then nextValues[output]=values[a];a+=1 else nextValues[output]=values[b];b+=1 end end
   end;values=nextValues;width*=2
  end
  local out=if name=='toSorted'then array(size)else receiver;for i,value in values do if name=='toSorted'then create(out,tostring(i-1),value)else set(out,tostring(i-1),value)end end
  if name=='sort'then for i=#values,size-1 do delete(out,tostring(i))end end;return out
 end)end
 for _,name in {'keys','values','entries'}do method(arrayProto,name,0,function(_,receiver)
  receiver=arrayReceiver(receiver);local index=0
  return context.CreateNativeIterator('Array',function()
   -- Snapshot the index before an observable length getter. Native array
   -- iterators permit reentry and an outer read keeps its original index.
   local key=index;if key>=length(receiver)then return false,U end;index=key+1
   local value=if name=='keys'then key elseif name=='entries'then vm.Array({key,get(receiver,tostring(key))})else get(receiver,tostring(key))
   return true,value
  end)
 end)end
 global('Array',arrayConstructor)

 -- String operations below index UTF-16 units, preserving lone surrogates.
 local stringProto=prototypes.String
 local function constructString(args,newTarget)
  local box=requireObject(if args[1]==nil then ''else text(args[1]));box.Prototype=constructPrototype(newTarget,stringProto);return box
 end
 local stringConstructor=native('String',1,function(args)
  local value=args[1];if value==nil then return ''elseif type(value)=='table'and value.Kind=='symbol'then return 'Symbol('..(value.Description or '')..')'end;return text(value)
 end,constructString,{prototype=stringProto})
 define(stringProto,'constructor',stringConstructor)
 method(stringProto,'toString',0,function(_,receiver)return primitiveReceiver(receiver,'string')end)
 method(stringProto,'valueOf',0,function(_,receiver)return primitiveReceiver(receiver,'string')end)
 method(stringConstructor,'fromCharCode',1,function(args)
  local units={};for i,value in args do local n=integer(value);units[i]=if n==math.huge or n==-math.huge then 0 else n%65536 end;return stringResult(Strings.fromUnits(units))
 end)
 method(stringConstructor,'fromCodePoint',1,function(args)
  local units={};for _,value in args do local n=number(value)
   if n~=math.floor(n)or n<0 or n>0x10ffff then fail('RangeError','Invalid code point')end
   if n>0xffff then n-=0x10000;table.insert(units,0xd800+math.floor(n/1024));table.insert(units,0xdc00+n%1024)else table.insert(units,n)end
  end;return stringResult(Strings.fromUnits(units))
 end)
 method(stringConstructor,'raw',1,function(args)
  local raw=requireObject(get(requireObject(arg(args,1,U)),'raw'));local size=bound(length(raw));local parts={}
  for i=0,size-1 do step();table.insert(parts,text(get(raw,tostring(i))));if i<size-1 then table.insert(parts,if args[i+2]~=nil then text(args[i+2])else '')end end;return stringResult(table.concat(parts))
 end)
 for _,name in {'at','charAt','charCodeAt','codePointAt'}do method(stringProto,name,1,function(args,receiver)
  local units=Strings.units(stringReceiver(receiver));local index=integer(arg(args,1,U));if name=='at'and index<0 then index+=#units end;local unit=units[index+1]
  if unit==nil then return if name=='charAt'then ''elseif name=='charCodeAt'then 0/0 else U end
  if name=='charCodeAt'then return unit elseif name=='codePointAt'then local following=units[index+2]
   return if unit>=0xd800 and unit<=0xdbff and following and following>=0xdc00 and following<=0xdfff then 0x10000+(unit-0xd800)*1024+following-0xdc00 else unit
  end;return Strings.fromUnits({unit})
 end)end
 for _,name in {'slice','substring','substr'}do method(stringProto,name,2,function(args,receiver)
  local units=Strings.units(stringReceiver(receiver));local first,last
  if name=='slice'then first,last=relative(args[1],#units),relative(args[2],#units,#units)
  elseif name=='substr'then first=relative(args[1],#units);last=math.min(first+math.max(integer(arg(args,2,#units-first)),0),#units)
  else first=math.clamp(integer(arg(args,1,U)),0,#units);last=math.clamp(integer(arg(args,2,#units)),0,#units);if first>last then first,last=last,first end end
  local out={};for i=first+1,last do table.insert(out,units[i])end;return Strings.fromUnits(out)
 end)end
 local function matches(units,target,index)
  if index<0 or index+#target>#units then return false end
  for i,unit in target do if units[index+i]~=unit then return false end end;return true
 end
 for _,name in {'includes','indexOf','lastIndexOf','startsWith','endsWith'}do method(stringProto,name,1,function(args,receiver)
  local units=Strings.units(stringReceiver(receiver));local target=Strings.units(text(arg(args,1,U)));local position=integer(arg(args,2,if name=='lastIndexOf'or name=='endsWith'then #units else 0))
  if name=='lastIndexOf'and args[2]~=nil and number(args[2])~=number(args[2])then position=#units end
  position=math.clamp(position,0,#units)
  if name=='startsWith'then return matches(units,target,position)elseif name=='endsWith'then return matches(units,target,position-#target)end
  if name=='lastIndexOf'then for i=position,0,-1 do step();if matches(units,target,i)then return i end end;return -1 end
  for i=position,#units-#target do step();if matches(units,target,i)then return if name=='includes'then true else i end end
  return if name=='includes'then false else -1
 end)end
 method(stringProto,'concat',1,function(args,receiver)local parts={stringReceiver(receiver)};for _,v in args do table.insert(parts,text(v))end;return stringResult(table.concat(parts))end)
 method(stringProto,'repeat',1,function(args,receiver)
  local value=stringReceiver(receiver);local count=integer(arg(args,1,U));if count<0 or count==math.huge then fail('RangeError','Invalid repeat count')end
  if #value*count>MAX_STRING then fail('RangeError','JavaScript string budget exceeded')end;return string.rep(value,count)
 end)
 for _,name in {'padStart','padEnd'}do method(stringProto,name,1,function(args,receiver)
  local value=stringReceiver(receiver);local size=math.max(integer(arg(args,1,U)),0);local units=Strings.units(value);if size<=#units then return value end
  local padding=Strings.units(text(arg(args,2,' ')));if #padding==0 then return value end;if size>MAX_STRING then fail('RangeError','JavaScript string budget exceeded')end
  local extra={};for i=1,size-#units do step();extra[i]=padding[(i-1)%#padding+1]end
  return stringResult(if name=='padStart'then Strings.fromUnits(extra)..value else value..Strings.fromUnits(extra))
 end)end
 local function whitespace(code)
  return code==32 or(code>=9 and code<=13)or code==0xa0 or code==0x1680 or(code>=0x2000 and code<=0x200a)or code==0x2028 or code==0x2029 or code==0x202f or code==0x205f or code==0x3000 or code==0xfeff
 end
 for _,name in {'trim','trimStart','trimEnd','trimLeft','trimRight'}do method(stringProto,name,0,function(_,receiver)
  local units=Strings.units(stringReceiver(receiver));local first,last=1,#units
  if name~='trimEnd'and name~='trimRight'then while first<=last and whitespace(units[first])do first+=1 end end
  if name~='trimStart'and name~='trimLeft'then while last>=first and whitespace(units[last])do last-=1 end end
  local out={};for i=first,last do table.insert(out,units[i])end;return Strings.fromUnits(out)
 end)end
 for _,name in {'toLowerCase','toUpperCase'}do method(stringProto,name,0,function(_,receiver)return Strings.case(stringReceiver(receiver),name=='toUpperCase')end)end
 for _,name in {'isWellFormed','toWellFormed'}do method(stringProto,name,0,function(_,receiver)
  local units=Strings.units(stringReceiver(receiver));local index=1;while index<=#units do local unit,nextUnit=units[index],units[index+1]
   if unit>=0xd800 and unit<=0xdbff and nextUnit and nextUnit>=0xdc00 and nextUnit<=0xdfff then index+=2
   elseif unit>=0xd800 and unit<=0xdfff then if name=='isWellFormed'then return false end;units[index]=0xfffd;index+=1 else index+=1 end
  end;return if name=='isWellFormed'then true else Strings.fromUnits(units)
 end)end
 method(stringProto,'split',2,function(args,receiver)
  local value=stringReceiver(receiver);local limit=if args[2]==nil or args[2]==U then 4294967295 else integer(args[2])%4294967296;local out=array(0);if limit==0 then return out end
  if args[1]==nil or args[1]==U then create(out,'0',value);return out end
  local units,target=Strings.units(value),Strings.units(text(args[1]));local first=0
  if #target==0 then for i=1,math.min(#units,limit)do bound(i);create(out,tostring(i-1),Strings.fromUnits({units[i]}))end;return out end
  for i=0,#units-#target do step();if i>=first and matches(units,target,i)then
   local selected={};for j=first+1,i do table.insert(selected,units[j])end;bound(out.Length+1);create(out,tostring(out.Length),Strings.fromUnits(selected));if out.Length>=limit then return out end;first=i+#target
  end end
  local selected={};for j=first+1,#units do table.insert(selected,units[j])end;bound(out.Length+1);create(out,tostring(out.Length),Strings.fromUnits(selected));return out
 end)
 for _,name in {'replace','replaceAll'}do method(stringProto,name,2,function(args,receiver)
  local value=stringReceiver(receiver);local units,target=Strings.units(value),Strings.units(text(arg(args,1,U)));local replacement=arg(args,2,U);local functional=VM.callable(replacement);local parts={};local cursor=0;local matched=false
  local function piece(first,last)local selected={};for j=first+1,last do table.insert(selected,units[j])end;return Strings.fromUnits(selected)end
  for i=0,#units-#target do step();if i<cursor or(name=='replace'and matched)or not matches(units,target,i)then continue end
   table.insert(parts,piece(cursor,i));local result
   if functional then result=text(vm:Call(replacement,{piece(i,i+#target),i,value},U))
   else local pattern=text(replacement);local out={};local at=1
    while at<=#pattern do local char=pattern:sub(at,at);local following=pattern:sub(at+1,at+1)
     if char=='$'and following=='$'then table.insert(out,'$');at+=2
     elseif char=='$'and following=='&'then table.insert(out,piece(i,i+#target));at+=2
     elseif char=='$'and following=='`'then table.insert(out,piece(0,i));at+=2
     elseif char=='$'and following=="'"then table.insert(out,piece(i+#target,#units));at+=2
     else table.insert(out,char);at+=1 end
    end;result=table.concat(out)
   end;table.insert(parts,result);matched=true;cursor=i+#target
  end;table.insert(parts,piece(cursor,#units));return stringResult(table.concat(parts))
 end)end
 global('String',stringConstructor)

 -- Numeric conversions distinguish strict Number predicates from the coercing
 -- browser globals. Radix parsing stops at the first invalid character.
 local function parseInt(args)
  local value=Strings.trim(text(arg(args,1,U)));local sign=1;if value:sub(1,1)=='-'then sign=-1;value=value:sub(2)elseif value:sub(1,1)=='+'then value=value:sub(2)end
  local radix=integer(arg(args,2,0));radix=if math.abs(radix)==math.huge then 0 else radix%4294967296;if radix>=2147483648 then radix-=4294967296 end
  if radix~=0 and(radix<2 or radix>36)then return 0/0 end
  if radix==0 then radix=10;if value:sub(1,2):lower()=='0x'then radix=16;value=value:sub(3)end
  elseif radix==16 and value:sub(1,2):lower()=='0x'then value=value:sub(3)end
  local result,count=0,0;for i=1,#value do step();local byte=value:byte(i);local digit=if byte>=48 and byte<=57 then byte-48 elseif byte>=65 and byte<=90 then byte-55 elseif byte>=97 and byte<=122 then byte-87 else 99
   if digit>=radix then break end;result=result*radix+digit;count+=1
  end;return if count==0 then 0/0 else sign*result
 end
 local function parseFloat(args)
  local value=Strings.trim(text(arg(args,1,U)));local prefix=value:match('^[+-]?Infinity');if prefix then return if prefix:sub(1,1)=='-'then -math.huge else math.huge end
  local significand=value:match('^[+-]?%d+%.?%d*')or value:match('^[+-]?%.%d+');if not significand then return 0/0 end
  local exponent=value:sub(#significand+1):match('^[eE][+-]?%d+');return tonumber(significand..(exponent or ''))or 0/0
 end
 local numberProto=prototypes.Number
 local function explicitNumber(value)local primitive=vm.ToPrimitive(value,'number');return if BigInt.is(primitive)then BigInt.Number(primitive)else number(primitive)end
 local function constructNumber(args,newTarget)
  local value=if args[1]==nil then 0 else explicitNumber(args[1]);local box=vm.Object({},constructPrototype(newTarget,numberProto));box.Kind='boxed-number';box.PrimitiveValue=value;return box
 end
 local numberConstructor=native('Number',1,function(args)return if args[1]==nil then 0 else explicitNumber(args[1])end,constructNumber,{prototype=numberProto,
  EPSILON=2^-52,MAX_SAFE_INTEGER=9007199254740991,MIN_SAFE_INTEGER=-9007199254740991,MAX_VALUE=1.7976931348623157e308,MIN_VALUE=4.9406564584124654e-324,NaN=0/0,POSITIVE_INFINITY=math.huge,NEGATIVE_INFINITY=-math.huge})
 define(numberProto,'constructor',numberConstructor)
 for _,name in {'isFinite','isNaN','isInteger','isSafeInteger'}do method(numberConstructor,name,1,function(args)
  local value=arg(args,1,U);if type(value)~='number'then return false end
  if name=='isNaN'then return value~=value end;if value~=value or math.abs(value)==math.huge then return false end
  return name=='isFinite'or(value==math.floor(value)and(name=='isInteger'or math.abs(value)<=9007199254740991))
 end)end
 method(numberConstructor,'parseInt',2,parseInt);method(numberConstructor,'parseFloat',1,parseFloat)
 method(numberProto,'valueOf',0,function(_,receiver)return primitiveReceiver(receiver,'number')end)
 local digits='0123456789abcdefghijklmnopqrstuvwxyz'
 method(numberProto,'toString',1,function(args,receiver)
  local value=primitiveReceiver(receiver,'number');local radix=integer(arg(args,1,10));if radix<2 or radix>36 then fail('RangeError','Radix must be between 2 and 36')end
  return Numbers.radix(value,radix,step)
 end)
 method(numberProto,'toFixed',1,function(args,receiver)
  local value=primitiveReceiver(receiver,'number');local count=integer(arg(args,1,0));if count<0 or count>100 then fail('RangeError','Digits must be between 0 and 100')end
  if value~=value or math.abs(value)>=1e21 then return text(value)end
  return Numbers.fixed(value,count,step)
 end)
 method(numberProto,'toExponential',1,function(args,receiver)
  local value=primitiveReceiver(receiver,'number');local count=if args[1]==nil or args[1]==U then nil else integer(args[1])
  if value~=value or math.abs(value)==math.huge then return text(value)end
  if count and(count<0 or count>100)then fail('RangeError','Digits must be between 0 and 100')end
  return Numbers.exponential(value,count,step)
 end)
 method(numberProto,'toPrecision',1,function(args,receiver)
  local value=primitiveReceiver(receiver,'number');if args[1]==nil or args[1]==U then return text(value)end
  local precision=integer(args[1])
  if value~=value or math.abs(value)==math.huge then return text(value)end
  if precision<1 or precision>100 then fail('RangeError','Precision must be between 1 and 100')end
  return Numbers.precision(value,precision,step)
 end)
 global('Number',numberConstructor)
 local booleanProto=prototypes.Boolean
 local function constructBoolean(args,newTarget)local box=vm.Object({},constructPrototype(newTarget,booleanProto));box.Kind='boxed-boolean';box.PrimitiveValue=VM.truth(arg(args,1,U));return box end
 local booleanConstructor=native('Boolean',1,function(args)return VM.truth(arg(args,1,U))end,constructBoolean,{prototype=booleanProto})
 define(booleanProto,'constructor',booleanConstructor)
 method(booleanProto,'valueOf',0,function(_,receiver)return primitiveReceiver(receiver,'boolean')end)
 method(booleanProto,'toString',0,function(_,receiver)return if primitiveReceiver(receiver,'boolean')then 'true'else 'false'end)
 global('Boolean',booleanConstructor)
 global('parseInt',native('parseInt',2,parseInt));global('parseFloat',native('parseFloat',1,parseFloat))
 global('isNaN',native('isNaN',1,function(args)local value=number(arg(args,1,U));return value~=value end))
 global('isFinite',native('isFinite',1,function(args)local value=number(arg(args,1,U));return value==value and math.abs(value)~=math.huge end))

 local mathObject=vm.Object({E=math.exp(1),PI=math.pi,LN2=math.log(2),LN10=math.log(10),LOG2E=1/math.log(2),LOG10E=1/math.log(10),SQRT1_2=math.sqrt(0.5),SQRT2=math.sqrt(2)})
 for key,value in mathObject.Values do vm.DefineProperty(mathObject,key,descriptorObject({value=value,writable=false,enumerable=false,configurable=false}))end
 local unary={abs=math.abs,acos=math.acos,asin=math.asin,atan=math.atan,ceil=function(x)return if x<0 and x>-1 then -1/math.huge else math.ceil(x)end,cos=math.cos,exp=math.exp,floor=math.floor,log=math.log,sin=math.sin,sqrt=math.sqrt,tan=math.tan,
  trunc=function(x)return if x<0 and x>-1 then -1/math.huge elseif x<0 then math.ceil(x)else math.floor(x)end,
  sign=function(x)return if x~=x or x==0 then x elseif x<0 then -1 else 1 end,
  cbrt=function(x)return if x==0 or math.abs(x)==math.huge then x elseif x<0 then -((-x)^(1/3))else x^(1/3)end,
  log2=function(x)return math.log(x)/math.log(2)end,log10=function(x)return math.log(x)/math.log(10)end,
  log1p=function(x)if math.abs(x)<1e-5 then return x-x*x/2+x*x*x/3-x^4/4 end;return math.log(1+x)end,
  expm1=function(x)if math.abs(x)<1e-5 then return x+x*x/2+x*x*x/6+x^4/24 end;return math.exp(x)-1 end,
  sinh=function(x)if x==0 or math.abs(x)<1e-8 then return x end;return(math.exp(x)-math.exp(-x))/2 end,cosh=function(x)return(math.exp(x)+math.exp(-x))/2 end,
  tanh=function(x)if x==0 or math.abs(x)<1e-8 then return x elseif x==math.huge then return 1 elseif x==-math.huge then return -1 end;local a=math.exp(2*math.abs(x));local v=if a==math.huge then 1 else(a-1)/(a+1);return if x<0 then -v else v end,
  asinh=function(x)if x==0 or math.abs(x)==math.huge or math.abs(x)<1e-8 then return x end;local a=math.abs(x);local v=if a>1e154 then math.log(a)+math.log(2)else math.log(a+math.sqrt(a*a+1));return if x<0 then -v else v end,
  acosh=function(x)return if x>1e154 then math.log(x)+math.log(2)else math.log(x+math.sqrt(x*x-1))end,
  atanh=function(x)if x==0 or math.abs(x)<1e-8 then return x end;return math.log((1+x)/(1-x))/2 end,
  round=function(x)if x==0 or x~=x or math.abs(x)==math.huge then return x elseif x<0 and x>=-0.5 then return -1/math.huge end;return math.floor(x+0.5)end}
 for name,action in unary do method(mathObject,name,1,function(args)return action(number(arg(args,1,U)))end)end
 for _,name in {'min','max'}do method(mathObject,name,2,function(args)
  local result=if name=='min'then math.huge else -math.huge
  local values={};for i,raw in args do values[i]=number(raw)end
  for _,value in values do if value~=value then return value end
   if(name=='min'and value<result)or(name=='max'and value>result)or(value==0 and result==0 and(if name=='min'then 1/value<1/result else 1/value>1/result))then result=value end
  end;return result
 end)end
 method(mathObject,'pow',2,function(args)local a,b=number(arg(args,1,U)),number(arg(args,2,U));if math.abs(a)==1 and math.abs(b)==math.huge then return 0/0 end;return a^b end)
 method(mathObject,'atan2',2,function(args)return math.atan2(number(arg(args,1,U)),number(arg(args,2,U)))end)
 method(mathObject,'hypot',2,function(args)
  local scale=0;local values={};local nan,infinite=false,false;for i,raw in args do local n=math.abs(number(raw));if n==math.huge then infinite=true end;if n~=n then nan=true else scale=math.max(scale,n)end;values[i]=n end
  if infinite then return math.huge elseif nan then return 0/0 elseif scale==0 then return 0 end;local sum=0;for _,n in values do sum+=(n/scale)^2 end;return scale*math.sqrt(sum)
 end)
 local function uint32(value)local n=integer(value);return if math.abs(n)==math.huge then 0 else n%4294967296 end
 method(mathObject,'clz32',1,function(args)return bit32.countlz(uint32(arg(args,1,U)))end)
 method(mathObject,'imul',2,function(args)local a,b=uint32(arg(args,1,U)),uint32(arg(args,2,U));local result=((a%65536)*(b%65536)+(((math.floor(a/65536)*(b%65536)+(a%65536)*math.floor(b/65536))%65536)*65536))%4294967296;return if result>=2147483648 then result-4294967296 else result end)
 method(mathObject,'fround',1,function(args)local data=buffer.create(4);buffer.writef32(data,0,number(arg(args,1,U)));return buffer.readf32(data,0)end)
 method(mathObject,'f16round',1,function(args)
  local value=number(arg(args,1,U));if value==0 or value~=value or math.abs(value)==math.huge then return value end
  local magnitude=math.abs(value);if magnitude>=65520 then return if value<0 then -math.huge else math.huge end
  local _,exponent=math.frexp(magnitude);local quantum=if magnitude<2^-14 then 2^-24 else 2^(exponent-11)
  local scaled=magnitude/quantum;local rounded=math.floor(scaled);local fraction=scaled-rounded
  if fraction>0.5 or(fraction==0.5 and rounded%2==1)then rounded+=1 end
  local result=rounded*quantum;return if value<0 then -result else result
 end)
 method(mathObject,'random',0,function()return if options.Random then options.Random()else math.random()end)
 global('Math',mathObject)
 JSON.install(context);Dates.install(context);URLs.install(context);Collections.install(context);Dates.finalize(context);StringNormalization.install(context)
 vm.DefineProperty(globals.JSON,vm.SymbolToStringTag,descriptorObject({value='JSON',configurable=true}))
 vm.DefineProperty(arrayConstructor,vm.SymbolSpecies,descriptorObject({get=native('get [Symbol.species]',0,function(_,receiver)return receiver end),enumerable=false,configurable=true}))

 local function lookup(proto,key,receiver)
  while proto~=N and proto~=nil do
   local descriptor=vm.GetOwnPropertyDescriptor(proto,key)
   if descriptor~=U then
    if hasOwn(descriptor,'value')then return get(descriptor,'value')end
    local getter=get(descriptor,'get');return if getter==U then U else vm:Call(getter,{},receiver)
   end;proto=vm.GetPrototype(proto)
  end;return U
 end
 vm.ArrayMethod=function(value,key)return lookup(arrayProto,key,value)end
 vm.StringMethod=function(value,key)return lookup(stringProto,key,value)end
 vm.PrimitiveMethod=function(value,key)
  local proto=if type(value)=='number'then numberProto elseif type(value)=='boolean'then booleanProto else nil
  return if proto then lookup(proto,key,value)else U
 end
 vm.StandardLibrary=context;return context
end
return StandardLibrary
