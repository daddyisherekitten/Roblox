--!strict
--!optimize 2
local Syntax=require(script.Parent.Syntax)
local Strings=require(script.Parent.Strings)
local Numbers=require(script.Parent.LibraryNumbers)
local ObjectModel=require(script.Parent.ObjectModel)
local StandardLibrary=require(script.Parent.StandardLibrary)
local Reflection=require(script.Parent.Reflection)
local BigInt=require(script.Parent.BigInt)
local RegExp=require(script.Parent.RegExp)
local ResourceStacks=require(script.Parent.ResourceStacks)
local Intl=require(script.Parent.Intl)
local Classes=require(script.Parent.Classes)
local Generators=require(script.Parent.Generators)
local IteratorHelpers=require(script.Parent.IteratorHelpers)
local DynamicCode=require(script.Parent.DynamicCode)
local GlobalEnvironment=require(script.Parent.GlobalEnvironment)
local VM={Undefined={},Null={}}
local WorkContext=require(script.Parent.Parent.WorkContext)
-- Luau weak tables are not ephemerons. A strong registry value would root its
-- realm, which owns prototypes that are themselves registry keys. Each wrapper
-- keeps its realm privately; the lookup roots neither side of that cycle.
local owners=setmetatable({},{__mode='kv'})
local UNINITIALIZED={}
local EXCEPTION={}
local activeRealms=setmetatable({},{__mode='k'})
-- Script provenance follows the physical execution stack, including calls
-- between realms. Null HTML handler frames are skipped, not inherited from
-- the script which first compiled the attribute.
local scriptContexts=setmetatable({},{__mode='kv'})
local function contexts()
 local thread=coroutine.running();local frames=scriptContexts[thread]
 if not frames then frames={};scriptContexts[thread]=frames end;return frames
end
local function activeScriptContext()
 local frames=scriptContexts[coroutine.running()]
 while frames do
  for index=#frames,1,-1 do if frames[index]then return frames[index]end end
  frames=frames.Caller
 end
 return false
end
local function restoreContexts(frames,count)for index=#frames,count+1,-1 do frames[index]=nil end end
local function protected(action,...)
 local frames=contexts();local count=#frames;local ok,value=pcall(action,...)
 restoreContexts(frames,count);return ok,value
end
function VM.callable(value: any): boolean
 return type(value)=='function' or (type(value)=='table' and (value.Kind=='function' or value.Kind=='native-function'))
end
function VM.error(name: string,message: string): any
 local values={message=message}
 local owner=activeRealms[coroutine.running()]
 return {Kind='error',ErrorName=name,Values=values,VMOwner=owner,Prototype=owner and(owner.Prototypes[name]or owner.Prototypes.Error),Descriptors={message={Value=message,Writable=true,Enumerable=false,Configurable=true}},Get=function(key)
  if key=='toString' then return function()return (values.name or name)..(if values.message=='' then '' else ': '..values.message)end end
  return if values[key]~=nil then values[key]elseif key=='name'then name else VM.Undefined
 end,Set=function(key,value)values[key]=value end}
end
function VM.throw(value: any)
 error(setmetatable({Brand=EXCEPTION,Value=value},{__tostring=function(exception)return VM.string(exception.Value)end}),0)
end
function VM.exceptionValue(value: any): any
 return if type(value)=='table' and value.Brand==EXCEPTION then value.Value else VM.error('Error',tostring(value))
end
function VM.string(v: any, seen: any?): string
 if v==VM.Undefined or v==nil then return 'undefined' elseif v==VM.Null then return 'null' end
 if type(v)=='table'and v.Kind=='symbol'then VM.throw(VM.error('TypeError','Cannot convert a Symbol value to a string'))end
 if BigInt.is(v)then return BigInt.String(v)end
 if type(v)=='number' then
  return Numbers.string(v)
 end
 if type(v)=='table'and owners[v]and owners[v].ToPrimitive then return VM.string(owners[v].ToPrimitive(v,'string'),seen)end
 if type(v)=='table' and v.Kind=='array' then
  seen=seen or {};if seen[v] then return '' end;seen[v]=true
  local parts,size={},0
  for i=1,v.Length or #v.Items do
   local item=v.Items[i];local text=if item==nil or item==VM.Null or item==VM.Undefined then '' else VM.string(item,seen)
   size+=#text+1;assert(size<=65536,'JavaScript string budget exceeded');parts[i]=text
  end
  seen[v]=nil;return table.concat(parts,',')
 elseif type(v)=='table' then
  if v.Kind=='error' then local name,message=VM.string(v.Get('name')),VM.string(v.Get('message'));return name..(if message=='' then '' else ': '..message) end
  return '[object Object]'
 end
 return tostring(v)
end
local function number(v)
 if type(v)=='table'and owners[v]and owners[v].ToPrimitive then v=owners[v].ToPrimitive(v,'number')end
 if type(v)=='table'and v.Kind=='symbol'then VM.throw(VM.error('TypeError','Cannot convert a Symbol value to a number'))end
 if BigInt.is(v)then VM.throw(VM.error('TypeError','Cannot convert a BigInt value to a number'))end
 if v==VM.Null then return 0 elseif v==true then return 1 elseif v==false then return 0 elseif type(v)=='number'then return v
 elseif type(v)=='string'then return Numbers.parse(v)
 elseif type(v)=='table'and v~=VM.Undefined then return Numbers.parse(VM.string(v))end
 return 0/0
end
local function truth(v) return if BigInt.is(v)then v.Sign~=0 else v~=VM.Undefined and v~=VM.Null and v~=false and v~=0 and v~='' and v==v end
VM.truth=truth
VM.number=number
function VM.new(globals: any,options: any?): any
 options=options or {};local maxSteps=options.MaxSteps or 20000;local checkpoint=options.Checkpoint;local self={Alive=true,Initializing=true,Steps=0,Depth=0,Global={Bindings={},Function=true},Diagnostics={},Model=VM,Prototypes={}}
 local initialGlobals={};for k,v in globals do initialGlobals[k]=true;self.Global.Bindings[k]={Value=v,Const=false} end
 local globalEnvironment
 local function env(parent) return {Bindings={},Parent=parent,Strict=parent and parent.Strict} end
 local function binding(e,key)
  while e do local found=if e==self.Global and globalEnvironment then globalEnvironment:Binding(key)else e.Bindings[key];if found then
   if found.Value==UNINITIALIZED then VM.throw(VM.error('ReferenceError','Cannot access '..key..' before initialization')) end
   return found
  end;e=e.Parent end
  VM.throw(VM.error('ReferenceError','Unknown JavaScript identifier: '..key))
 end
 local function bindingValue(entry)return if entry.Get then entry.Get()else entry.Value end
 local function step()
  if self.Initializing then WorkContext.checkpoint();return end
  assert(self.Alive,'JavaScript runtime disposed');self.Steps+=1
  assert(self.Steps<=maxSteps,'JavaScript instruction budget exceeded')
  if self.Steps%128==0 then
   -- Managed async/generator stacks cannot perform task.wait themselves.
   -- Forward cooperative loading work to the owning host entry instead.
   if options.LoadingWork and(options.LoadingWork.Active or options.LoadingWork.Running>0)then
    if self.Generators and self.Generators:IsActive()then self.Generators:HostCall(WorkContext.checkpoint)
    elseif options.Async then options.Async:HostCall(WorkContext.checkpoint)
    else WorkContext.checkpoint()end
   else WorkContext.checkpoint()end
   if checkpoint then checkpoint()end;assert(self.Alive,'JavaScript runtime disposed')
  end
 end
 self.Step=step
 local evaluate,execute,call,get,set,construct,bindPattern
 local SHORT={}
 local model=ObjectModel.install(self,VM)
 self.ObjectModel=model
 self.StringLength=Strings.length
 self.StringIndex=function(value,index)local units=Strings.units(value);return if units[index+1]then Strings.fromUnits({units[index+1]})else VM.Undefined end
 local stackBase=0
 local function completion(body,scope)
  local depth=self.Depth;local frames=contexts();local count=#frames;local ok,result=pcall(execute,body,scope)
  -- A caught function error bypassed its normal depth decrement. Restore
  -- at the exception boundary, without adding a pcall to every JS call.
  self.Depth=depth;restoreContexts(frames,count);return ok,result
 end
 local function integer(value, fallback)
  if value==nil or value==VM.Undefined then return fallback or 0 end
  local n=number(value);if n~=n then return 0 end
  return if n<0 then math.ceil(n) else math.floor(n)
 end
 local function array(items)local result={Kind='array',Items=items,Length=#items,Properties={},Prototype=self.Prototypes.Array,VMOwner=self};owners[result]=self;return result end
 local function object(values,prototype,keyOrder)
  WorkContext.checkpoint()
  local result={Kind='object',Values=values or {},Prototype=if prototype==nil then self.Prototypes.Object else prototype}
  local keys=keyOrder or {};if not keyOrder then for key in result.Values do table.insert(keys,key)end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)end
  for _,key in keys do model.Record(result,key)end
  result.VMOwner=self;owners[result]=self
  return result
 end
 -- Internal descriptors are records, so author Object.prototype accessors
 -- cannot become additional fields during ToPropertyDescriptor conversion.
 local function descriptorObject(fields)return object(fields,VM.Null)end
 local function arrayIndex(key)
  local n=tonumber(key)
  return if n and n>=0 and n==math.floor(n) and n<4294967295 and tostring(n)==tostring(key) then n else nil
 end
 local function stringMethod(value,key)
  if key=='length' then return Strings.length(value) end
  local index=arrayIndex(key)
  if index then local units=Strings.units(value);return if units[index+1] then Strings.fromUnits({units[index+1]}) else VM.Undefined end
  if key=='trim' then return function() return Strings.trim(value) end end
  if key=='toLowerCase' then return function() return Strings.case(value,false) end end
  if key=='toUpperCase' then return function() return Strings.case(value,true) end end
  if key=='includes' or key=='indexOf' or key=='startsWith' or key=='endsWith' then return function(args)
   local needle=VM.string(if args[1]==nil then VM.Undefined else args[1]);local units=Strings.units(value);local target=Strings.units(needle)
   local first=math.clamp(integer(args[2]),0,#units)
   local last=#units-#target
   if key=='startsWith' then last=first elseif key=='endsWith' then first=math.clamp(integer(args[2],#units),0,#units)-#target;last=first end
   for at=first,last do
    step();local matches=at>=0
    for i,unit in target do if units[at+i]~=unit then matches=false;break end end
    if matches then return if key=='indexOf' then at else true end
   end
   return if key=='indexOf' then -1 else false
  end end
  if key=='slice' or key=='substring' then return function(args)
   local units=Strings.units(value);local a,b=integer(args[1]),integer(args[2],#units)
   if key=='slice' then if a<0 then a=#units+a end;if b<0 then b=#units+b end end
   a,b=math.clamp(a,0,#units),math.clamp(b,0,#units)
   if key=='substring' and a>b then a,b=b,a end
   local selected={};for i=a+1,b do table.insert(selected,units[i]) end
   return Strings.fromUnits(selected)
  end end
  if key=='charAt' or key=='charCodeAt' then return function(args)
   local unit=Strings.units(value)[integer(args[1])+1]
   return if key=='charCodeAt' then unit or (0/0) elseif unit then Strings.fromUnits({unit}) else ''
  end end
  return VM.Undefined
 end
 local function arrayMethod(value,key)
  local items=value.Items
  if key=='length' then return value.Length or #items end
  local index=arrayIndex(key);if index then return if items[index+1]==nil then VM.Undefined else items[index+1] end
  if value.Properties and value.Properties[key]~=nil then return value.Properties[key] end
  if key=='push' then return function(args)
   local length=value.Length or #items;assert(length+#args<=16384,'JavaScript array budget exceeded')
   for i,v in args do items[length+i]=v end;value.Length=length+#args;return value.Length
  end end
  if key=='pop' then return function()
   local length=value.Length or #items;if length==0 then return VM.Undefined end
   local result=items[length];items[length]=nil;value.Length=length-1;return if result==nil then VM.Undefined else result
  end end
  if key=='join' then return function(args)
   local parts,size={},0;local separator=if args[1]==nil or args[1]==VM.Undefined then ',' else VM.string(args[1]);for i=1,value.Length or #items do step();local v=items[i];parts[i]=if v==nil or v==VM.Null or v==VM.Undefined then '' else VM.string(v);size+=#parts[i]+#separator;assert(size<=65536,'JavaScript string budget exceeded') end
   return table.concat(parts,separator)
  end end
  if key=='forEach' or key=='map' or key=='filter' then return function(args)
   local out={};local length=value.Length or #items
   for i=1,length do
    step();if items[i]==nil then continue end
    local result=call(args[1],{items[i],i-1,value},args[2])
    if key=='map' then out[i]=result elseif key=='filter' and truth(result) then table.insert(out,items[i]) end
   end
   if key=='forEach' then return VM.Undefined end
   local result=array(out);if key=='map' then result.Length=length end;return result
  end end
  if key=='includes' or key=='indexOf' then return function(args)
   local length=value.Length or #items;local first=integer(args[2]);if first<0 then first=math.max(0,length+first) end
   for i=first+1,length do
    local v=items[i];if v==nil and key=='indexOf' then continue end;if v==nil then v=VM.Undefined end
    if v==args[1] or (key=='includes' and v~=v and args[1]~=args[1]) then return if key=='indexOf' then i-1 else true end
   end
   return if key=='indexOf' then -1 else false
  end end
  return VM.Undefined
 end
 get=function(value,key,receiver)
  key=model.Key(key)
  if value==VM.Null or value==VM.Undefined or value==nil then VM.throw(VM.error('TypeError','Cannot read property '..VM.string(key)))end
  if type(value)=='function'then return model.Get(self.Prototypes.Function,key,value)end
  if type(value)=='string'then
   local own=model.Own(value,key);if own then return own.Value end
   return if self.StringMethod then self.StringMethod(value,key)else stringMethod(value,key)
  elseif type(value)=='number'or type(value)=='boolean'then
   return if self.PrimitiveMethod then self.PrimitiveMethod(value,key)else VM.Undefined
  end
  if type(value)~='table'then return VM.Undefined end
  if value.Kind=='function'then
   if key=='prototype'and not value.Async and not value.Arrow and not value.Method then
    if not value.PrototypeObject then value.PrototypeObject=object({constructor=value});value.Values=value.Values or {};value.Values.prototype=value.PrototypeObject end
   end
  end
  if value.Kind=='symbol'and self.SymbolMethod then return self.SymbolMethod(value,key)end
  if BigInt.is(value)then return model.Get(self.Prototypes.BigInt,key,value)end
  local result=model.Get(value,key,receiver)
  if result~=VM.Undefined then return result end
  -- Undefined is a valid property value, including an accessor result or a
  -- Proxy get trap. Only pre-library host objects need legacy conveniences.
  if self.ArrayMethod or model.Ordinary(value)or model.Exotic[value]then return result end
  if value.Kind=='array'then
   local method=if self.ArrayMethod then self.ArrayMethod(value,key)else VM.Undefined
   return if method~=VM.Undefined then method else arrayMethod(value,key)
  end
  if VM.callable(value)and key=='call'then return function(args)local rest={};for i=2,#args do rest[i-1]=args[i]end;return call(value,rest,args[1])end end
  return VM.Undefined
 end
 set=function(value,key,item,strict)return model.Set(value,key,item,strict~=false)end
 self.Get,self.Set,self.Array,self.Object=get,set,array,object
 globalEnvironment=GlobalEnvironment.install(self,globals,initialGlobals)
 if globals.globalThis==nil then
  local globalObject
  globalObject={Get=function(key)return globalEnvironment:Read(key)end,
   Set=function(key,value,strict)return globalEnvironment:Write(key,value,strict)end,
   GetOwnPropertyDescriptor=function(key)return globalEnvironment:Own(key)end,
   DefineProperty=function(key,descriptor,strict)return globalEnvironment:Define(key,descriptor,strict)end,
   Delete=function(key,strict)return globalEnvironment:Delete(key,strict)end,
   Has=function(key)return globalEnvironment:Has(key)end,
   Keys=function(enumerable)return globalEnvironment:Keys(enumerable)end,
   IsExtensible=function()return model.IsExtensible(globalEnvironment.Properties)end,
   PreventExtensions=function()return model.PreventExtensionsInternal(globalEnvironment.Properties)end,
   GetPrototype=function()return globalEnvironment.Properties.Prototype end,
   SetPrototype=function(prototype)globalEnvironment.PrototypeSet=true;return model.SetPrototypeInternal(globalEnvironment.Properties,prototype)end}
  globals.globalThis=globalObject;self.Global.Bindings.globalThis={Value=globalObject}
 end
 self.HasOwn,self.Has,self.Delete,self.OwnKeys=model.HasOwn,model.Has,model.Delete,model.OwnKeys
 self.GetPrototype,self.SetPrototype=model.GetPrototype,model.SetPrototype
 self.GetOwnPropertyDescriptor,self.DefineProperty=model.Descriptor,model.Define
 self.IsExtensible=function(value)return model.IsExtensible(value)end
 self.PreventExtensions=function(value)return model.PreventExtensions(value)end
 self.SetWithReceiver=function(value,key,item,receiver)return model.Set(value,key,item,false,receiver)end
 self.IsArray=function(value)return type(value)=='table'and value.Kind=='array'end
 self.FunctionRealm=function(value)
  local seen={}
  while type(value)=='table'do
   if seen[value]then VM.throw(VM.error('TypeError','Cyclic function realm'))end;seen[value]=true
   if value.BoundTarget then value=value.BoundTarget
   elseif value.ProxyState then
    if value.ProxyState.Revoked then VM.throw(VM.error('TypeError','Cannot get the realm of a revoked Proxy'))end
    value=value.ProxyState.Target
   else return value.VMOwner or self end
  end
  return self
 end
 self.IsConstructor=function(value)
  return type(value)=='table'and((value.Kind=='native-function'and value.Construct~=nil)or(value.Kind=='function'and not value.Async and not value.Generator and not value.Arrow and not value.Method))
 end
 -- The current realm exposes arrays and primitive strings as iterables.
 -- Array length/index reads stay live while a consumer calls user functions.
 local function awaitValue(value)
  if self.Generators and self.Generators:IsActive()then return self.Generators:Await(value)end
  if not options.Async then VM.throw(VM.error('TypeError','Async iteration requires intrinsic promises'))end
  return options.Async:Await(value)
 end
 function self.Iterator(value,isAsync,knownMethod)
  if self.SymbolIterator and value~=VM.Null and value~=VM.Undefined then
   local asyncMethod=if isAsync and self.SymbolAsyncIterator then get(value,self.SymbolAsyncIterator)else VM.Undefined
   local nativeAsync=asyncMethod~=VM.Undefined and asyncMethod~=VM.Null
   local method=if knownMethod~=nil then knownMethod elseif nativeAsync then asyncMethod else get(value,self.SymbolIterator)
   if method~=VM.Undefined and method~=VM.Null then
    local iterator=call(method,{},value)
    if not model.IsObject(iterator)then VM.throw(VM.error('TypeError','Iterator is not an object'))end
    local nextMethod=get(iterator,'next');if not VM.callable(nextMethod)then VM.throw(VM.error('TypeError','Iterator next is not callable'))end
    local done=false
    return function()
     if done then return false,VM.Undefined end
     step();local result=call(nextMethod,{},iterator);if nativeAsync then result=awaitValue(result)end
     if not model.IsObject(result)then VM.throw(VM.error('TypeError','Iterator result is not an object'))end
     local finished=truth(get(result,'done'))
     if finished and(not isAsync or nativeAsync)then done=true;return false,VM.Undefined end
     local item=get(result,'value')
     if isAsync and not nativeAsync then item=awaitValue(item)end
     if finished then done=true;return false,VM.Undefined end
     return true,item
    end,function()
     if done then return end;done=true
     local close=get(iterator,'return')
     if close~=VM.Undefined and close~=VM.Null then
      local result=call(close,{},iterator);if nativeAsync then result=awaitValue(result)end
      if not model.IsObject(result)then VM.throw(VM.error('TypeError','Iterator return is not an object'))end
      if isAsync and not nativeAsync then local _=truth(get(result,'done'));awaitValue(get(result,'value'))end
     end
    end
   end
   if not(type(value)=='table'and value.Iterator and not model.Ordinary(value))then VM.throw(VM.error('TypeError','Value is not iterable'))end
  end
  if type(value)=='table'and value.Iterator then return value.Iterator()end
  if type(value)=='table' and value.Kind=='array' then
   local index=0
   return function()
    step();if index>=get(value,'length') then return false,VM.Undefined end
    local item=get(value,tostring(index));index+=1;return true,item
   end
  elseif type(value)=='string' then
   local codes=Strings.codes(value)
   return function()
    step();local code=codes();if code==nil then return false,VM.Undefined end
    if code>0xffff then
     code-=0x10000;return true,Strings.fromUnits({0xd800+math.floor(code/1024),0xdc00+code%1024})
    end
    return true,Strings.fromUnits({code})
   end
  end
  VM.throw(VM.error('TypeError','Value is not iterable; this realm supports arrays and strings'))
 end
 self.IsIterable=function(value)
  if value==VM.Null or value==VM.Undefined then return false end
  if self.SymbolIterator then local method=get(value,self.SymbolIterator);return(method~=VM.Undefined and method~=VM.Null)or(type(value)=='table'and value.Iterator~=nil and not model.Ordinary(value))end
  return type(value)=='string'or(type(value)=='table'and(value.Kind=='array'or value.Iterator~=nil))
 end
 local function nullish(value)return value==VM.Undefined or value==VM.Null or value==nil end
 local function primitive(value,hint)
  if not model.IsObject(value)then return value end
  if self.SymbolToPrimitive then
   local exotic=get(value,self.SymbolToPrimitive)
   if not nullish(exotic)then local result=call(exotic,{hint or 'default'},value);if model.IsObject(result)then VM.throw(VM.error('TypeError','Cannot convert object to primitive'))end;return result end
  end
  for _,name in (if hint=='string'then {'toString','valueOf'}else {'valueOf','toString'})do
   local method=get(value,name)
   if VM.callable(method)then local result=call(method,{},value);if not model.IsObject(result)then return result end end
  end
  -- Older SVG/Canvas wrappers expose no Object prototype. Preserve their
  -- ordinary object conversion without skipping a user-defined coercion.
  if not model.Ordinary(value)then return VM.string(value)end
  VM.throw(VM.error('TypeError','Cannot convert object to primitive'))
 end
 self.ToPrimitive=primitive
 local function toString(value)return VM.string(primitive(value,'string'))end
 local function toNumber(value)return number(primitive(value,'number'))end
 local function uint(value)
  local n=toNumber(value);if n~=n or n==0 or math.abs(n)==math.huge then return 0 end
  return (if n<0 then math.ceil(n)else math.floor(n))%4294967296
 end
 local function signed(n)return if n>=2147483648 then n-4294967296 else n end
 local function propertyKey(value)local v=primitive(value,'string');return if type(v)=='table'and v.Kind=='symbol'then v else VM.string(v)end
 self.PropertyKey=propertyKey
 local function namedEvaluation(ast,value,name)
  while ast and ast.Kind=='group'do ast=ast.Value end
  if ast and(ast.Kind=='function'or ast.Kind=='class')and not ast.Name and type(value)=='table'and get(value,'name')==''then
   local inferred=ast.InferredName or name
   if type(inferred)=='table'and inferred.Kind=='symbol'then inferred='['..(inferred.Description or '')..']'end
   self.DefineProperty(value,'name',descriptorObject({value=inferred,writable=false,enumerable=false,configurable=true}))
  end
  return value
 end
 self.NamedEvaluation=namedEvaluation
 local function evalState(scope)
  while scope do if scope.EvalState~=nil then return scope.EvalState or nil end;scope=scope.Parent end
  return nil
 end
 local function reference(n,e)
  if n.Kind=='group'then return reference(n.Value,e)end
  if n.Kind=='identifier'then
   local b
   local scope=e;while scope do b=if scope==self.Global then globalEnvironment:Binding(n.Name)else scope.Bindings[n.Name];if b then break end;scope=scope.Parent end
   if not b then
    if e.Strict then VM.throw(VM.error('ReferenceError','Unknown JavaScript identifier: '..n.Name))end
    return function()return bindingValue(binding(e,n.Name))end,function(v)globalEnvironment:Write(n.Name,v,false)end
   end
   if b.Value==UNINITIALIZED then VM.throw(VM.error('ReferenceError','Cannot access '..n.Name..' before initialization'))end
   return function()return bindingValue(b)end,function(v)if b.Set then b.Set(v,e.Strict);return end;if b.Const then if b.NamedFunction and not e.Strict then return end;VM.throw(VM.error('TypeError','Assignment to const '..n.Name))end;b.Value=v end
  elseif n.Kind=='member'then
   if n.Object.Kind=='super'then return self.Classes:SuperReference(e,propertyKey(evaluate(n.Key,e)))end
   local value=evaluate(n.Object,e);local key=propertyKey(evaluate(n.Key,e))
   if n.Private then return function()return self.Classes:GetPrivate(e,value,key)end,function(v)self.Classes:SetPrivate(e,value,key,v)end end
   return function()return get(value,key)end,function(v)set(value,key,v,e.Strict)end
  end
  VM.throw(VM.error('ReferenceError','Invalid JavaScript assignment target'))
 end
 local function equal(a,b)
  if nullish(a)and nullish(b)then return true end
  if BigInt.is(a)or BigInt.is(b)then
   if not BigInt.is(a)then a,b=b,a end
   if BigInt.is(b)then return BigInt.Equal(a,b)end
   if type(b)=='boolean'then return equal(a,number(b))end
   if type(b)=='number'then return BigInt.CompareNumber(a,b)==0 end
   if type(b)=='string'then local ok,value=pcall(self.BigInt.Parse,self.BigInt,b);return ok and BigInt.Equal(a,value)end
   if model.IsObject(b)then return equal(a,primitive(b))end
   return false
  end
  if type(a)==type(b)then return a==b end
  if nullish(a)and nullish(b)then return true end
  if type(a)=='boolean'then return equal(number(a),b)elseif type(b)=='boolean'then return equal(a,number(b))end
  if(type(a)=='number'and type(b)=='string')or(type(a)=='string'and type(b)=='number')then return number(a)==number(b)end
  if type(a)=='table'and not nullish(a)and type(b)~='table'then return equal(primitive(a),b)end
  if type(b)=='table'and not nullish(b)and type(a)~='table'then return equal(a,primitive(b))end
  return false
 end
 local binary,instanceOf,ordinaryHasInstance
 instanceOf=function(value,constructor)
  if not model.IsObject(constructor)then VM.throw(VM.error('TypeError','Right operand of instanceof must be an object'))end
  local method=if self.SymbolHasInstance then get(constructor,self.SymbolHasInstance)else VM.Undefined
  if not nullish(method)then
   if not VM.callable(method)then VM.throw(VM.error('TypeError','Symbol.hasInstance is not callable'))end
   return truth(call(method,{value},constructor))
  end
  if not VM.callable(constructor)then VM.throw(VM.error('TypeError','Right operand of instanceof is not callable'))end
  return ordinaryHasInstance(constructor,value)
 end
 ordinaryHasInstance=function(constructor,value)
  if not VM.callable(constructor)then return false end
  if type(constructor)=='table'and constructor.BoundTarget then return instanceOf(value,constructor.BoundTarget)end
  if not model.IsObject(value)then return false end
  local proto=get(constructor,'prototype')
  if not model.IsObject(proto)then VM.throw(VM.error('TypeError','Constructor prototype is not an object'))end
  local cursor=value
  while true do step();cursor=self.GetPrototype(cursor);if cursor==VM.Null then return false elseif cursor==proto then return true end end
 end
 self.OrdinaryHasInstance=ordinaryHasInstance
 binary=function(op,a,b)
  if op=='==='or op=='!=='then local same=if BigInt.is(a)and BigInt.is(b)then BigInt.Equal(a,b)else a==b;return if op=='==='then same else not same end
  if op=='=='or op=='!='then local same=equal(a,b);return if op=='=='then same else not same end
  if op~='in'and op~='instanceof'then
   a,b=primitive(a,if op=='+'then 'default'else 'number'),primitive(b,if op=='+'then 'default'else 'number')
   if BigInt.is(a)or BigInt.is(b)then
    if op=='+'and(type(a)=='string'or type(b)=='string')then return VM.string(a)..VM.string(b)end
    if op=='<'or op=='>'or op=='<='or op=='>='then
     local order
     if BigInt.is(a)and BigInt.is(b)then order=BigInt.Compare(a,b)
     elseif BigInt.is(a)and type(b)=='string'then local ok,value=pcall(self.BigInt.Parse,self.BigInt,b);if ok then order=BigInt.Compare(a,value)end
     elseif BigInt.is(b)and type(a)=='string'then local ok,value=pcall(self.BigInt.Parse,self.BigInt,a);if ok then order=BigInt.Compare(value,b)end
     elseif BigInt.is(a)then order=BigInt.CompareNumber(a,number(b))
     else local reverse=BigInt.CompareNumber(b,number(a));order=if reverse then -reverse else nil end
     if order==nil then return false end
     return if op=='<'then order<0 elseif op=='>'then order>0 elseif op=='<='then order<=0 else order>=0
    end
    return self.BigInt:Binary(op,a,b)
   end
  end
  if op=='+'then a,b=primitive(a),primitive(b);if type(a)=='string'or type(b)=='string'then local s=Strings.canonical(VM.string(a)..VM.string(b));assert(#s<=65536,'JavaScript string budget exceeded');return s end;return number(a)+number(b)
  elseif op=='-'then return toNumber(a)-toNumber(b)elseif op=='*'then return toNumber(a)*toNumber(b)elseif op=='/'then return toNumber(a)/toNumber(b)
  elseif op=='**'then local x,y=toNumber(a),toNumber(b);if y==0 then return 1 end;if math.abs(x)==1 and math.abs(y)==math.huge then return 0/0 end;return x^y
  elseif op=='%'then
   local x,y=toNumber(a),toNumber(b)
   if x~=x or y~=y or y==0 or math.abs(x)==math.huge then return 0/0 end
   if x==0 or math.abs(y)==math.huge then return x end
   local result=x-math.modf(x/y)*y;return if result==0 and x<0 then -0 else result
  elseif op=='==='then return a==b elseif op=='!=='then return a~=b
  elseif op=='=='or op=='!='then local result=equal(a,b);return if op=='=='then result else not result
  elseif op=='&'then return signed(bit32.band(uint(a),uint(b)))elseif op=='|'then return signed(bit32.bor(uint(a),uint(b)))elseif op=='^'then return signed(bit32.bxor(uint(a),uint(b)))
  elseif op=='<<'then return signed(bit32.lshift(uint(a),uint(b)%32))elseif op=='>>'then return signed(bit32.arshift(uint(a),uint(b)%32))elseif op=='>>>'then return bit32.rshift(uint(a),uint(b)%32)
  elseif op=='in'then if not model.IsObject(b)then VM.throw(VM.error('TypeError','Right operand of in must be an object'))end;return self.Has(b,propertyKey(a))
  elseif op=='instanceof'then
   return instanceOf(a,b)
  else
   local x,y=primitive(a,'number'),primitive(b,'number')
   if type(x)=='string'and type(y)=='string'then
    -- Lexicographic comparison uses UTF-16 code units, including lone surrogates.
    local ax,bx=Strings.units(x),Strings.units(y);local order=0
    for i=1,math.min(#ax,#bx)do if ax[i]~=bx[i]then order=if ax[i]<bx[i]then -1 else 1;break end end
    if order==0 then order=if #ax<#bx then -1 elseif #ax>#bx then 1 else 0 end
    return if op=='<'then order<0 elseif op=='>'then order>0 elseif op=='<='then order<=0 else order>=0
   end
   x,y=number(x),number(y);if op=='<'then return x<y elseif op=='>'then return x>y elseif op=='<='then return x<=y elseif op=='>='then return x>=y end
  end
  error('Unsupported JavaScript operator '..op)
 end
 local function spreadValues(out,value)
  local nextValue,close=self.Iterator(value)
  local ok,message=protected(function()while true do local more,item=nextValue();if not more then break end;assert(#out<16384,'JavaScript array budget exceeded');table.insert(out,item)end end)
  if not ok then if close then protected(close)end;error(message,0)end
 end
 local function arguments(nodes,e)
  local result={};for _,item in nodes do if item.Kind=='spread'then spreadValues(result,evaluate(item.Value,e))else assert(#result<16384,'JavaScript argument budget exceeded');table.insert(result,evaluate(item,e))end end;return result
 end
 local function targetReference(n,e)
  if n.Kind=='group'then return targetReference(n.Value,e)end
  if n.Kind=='identifier'then local entry=binding(e,n.Name);return bindingValue(entry),entry.ObjectReceiver or VM.Undefined end
  if n.Kind=='member'then
   if n.Object.Kind=='super'then local read,_,receiver=self.Classes:SuperReference(e,propertyKey(evaluate(n.Key,e)));return read(),receiver end
   local receiver=evaluate(n.Object,e)
   if receiver==SHORT or(n.Optional and nullish(receiver))then return SHORT,VM.Undefined end
   local key=propertyKey(evaluate(n.Key,e))
   return if n.Private then self.Classes:GetPrivate(e,receiver,key)else get(receiver,key),receiver
  end
  return evaluate(n,e),VM.Undefined
 end
 local templateObjects={}
 local function sourceContext(scope)
  while scope do if scope.Module then return scope.Module.ScriptContext elseif scope.ScriptContext~=nil then return scope.ScriptContext end;scope=scope.Parent end
  return activeScriptContext()or(if self.CurrentSourceURL or options.SourceURL then {URL=self.CurrentSourceURL or options.SourceURL,VM=self}else false)
 end
 evaluate=function(n,e)
  step();local k=n.Kind
  if k=='literal'then return n.Value elseif k=='null'then return VM.Null elseif k=='identifier'then return bindingValue(binding(e,n.Name))
  elseif k=='bigint'then return self.BigInt:Parse(n.Value:gsub('_',''))
  elseif k=='regexp'then
   if not self.RegExp then VM.throw(VM.error('NotSupportedError','RegExp is not installed'))end
   return self.RegExp:Create(n.Pattern,n.Flags)
  elseif k=='class'then return self.Classes:Create(n,e)
  elseif k=='group'then local value=evaluate(n.Value,e);return if value==SHORT then VM.Undefined else value
  elseif k=='chain'then local value=evaluate(n.Value,e);return if value==SHORT then VM.Undefined else value
  elseif k=='sequence'then local result=VM.Undefined;for _,item in n.Items do result=evaluate(item,e)end;return result
  elseif k=='new-target'then local scope=e;while scope do if scope.NewTarget~=nil then return scope.NewTarget end;scope=scope.Parent end;return VM.Undefined
  elseif k=='import-meta'then
   local scope=e;while scope do if scope.Module then return scope.Module.Meta end;scope=scope.Parent end
   VM.throw(VM.error('SyntaxError','import.meta outside module'))
  elseif k=='dynamic-import'then
   local specifier=evaluate(n.Value,e);local importOptions=if n.Options then evaluate(n.Options,e)else VM.Undefined
   local context=sourceContext(e);if context==false then context=activeScriptContext()end
   local importer=self.ImportModule
   if not importer then VM.throw(VM.error('TypeError','Dynamic import requires a live module loader'))end
   return importer(specifier,importOptions,if context then context.URL else nil,if context then context.VM else nil)
  elseif k=='function'then
   local scope=if n.Name and not n.Declaration then env(e)else e
   local length=0;for _,param in n.Params do if param.Kind=='default-pattern'or param.Kind=='rest'then break end;length+=1 end
   local fn={Kind='function',Params=n.Params,Length=length,Name=n.Name or '',Body=n.Body,Environment=scope,Async=n.Async,Generator=n.Generator,Arrow=n.Arrow,Prototype=if n.Generator then self.Prototypes[if n.Async then 'AsyncGeneratorFunction'else 'GeneratorFunction']else self.Prototypes.Function,
    Strict=e.Strict or n.Strict,SourceText=n.SourceText}
   if fn.Async and not fn.Generator and self.Prototypes.AsyncFunction then fn.Prototype=self.Prototypes.AsyncFunction end
   fn.Method=n.Method
   fn.ScriptContext=sourceContext(e);if fn.ScriptContext==false then fn.ScriptContext=activeScriptContext()end
   fn.SourceURL=if fn.ScriptContext then fn.ScriptContext.URL else false
   fn.VMOwner=self;owners[fn]=self
   self.DefineProperty(fn,'length',descriptorObject({value=length,writable=false,enumerable=false,configurable=true}))
   self.DefineProperty(fn,'name',descriptorObject({value=fn.Name,writable=false,enumerable=false,configurable=true}))
   if fn.Generator then
    fn.PrototypeObject=object({},self.Prototypes[if fn.Async then 'AsyncGenerator'else 'Generator'])
    self.DefineProperty(fn,'prototype',descriptorObject({value=fn.PrototypeObject,writable=true,enumerable=false,configurable=false}))
   elseif not fn.Async and not fn.Arrow and not fn.Method then
    local prototype=object({});self.DefineProperty(prototype,'constructor',descriptorObject({value=fn,writable=true,enumerable=false,configurable=true}))
    fn.PrototypeObject=prototype;self.DefineProperty(fn,'prototype',descriptorObject({value=prototype,writable=true,enumerable=false,configurable=false}))
   end
   if n.Arrow then local scope=e;while scope and not scope.Bindings.this do scope=scope.Parent end;fn.LexicalThisBinding=scope and scope.Bindings.this end
   if n.Name and not n.Declaration then scope.Bindings[n.Name]={Value=fn,Const=true,NamedFunction=true}end
   return fn
  elseif k=='array'then
   local result=array({});local length=0
   for _,item in n.Items do
    if item.Kind=='hole'then length+=1
    elseif item.Kind=='spread'then local values={};spreadValues(values,evaluate(item.Value,e));for _,value in values do length+=1;result.Items[length]=value end
    else length+=1;result.Items[length]=evaluate(item,e)end
    assert(length<=16384,'JavaScript array budget exceeded')
   end
   result.Length=length;return result
  elseif k=='object'then
   local result=object({})
   for _,property in n.Properties do
    if property.Spread then
     local source=evaluate(property.Value,e)
     if not nullish(source)then for _,key in self.OwnKeys(source,false)do
      local descriptor=self.GetOwnPropertyDescriptor(source,key)
      if descriptor~=VM.Undefined and truth(get(descriptor,'enumerable'))then self.DefineProperty(result,key,descriptorObject({value=get(source,key),writable=true,enumerable=true,configurable=true}))end
     end end
    else
     local key=propertyKey(if property.Computed then evaluate(property.Key,e)else property.Key)
     local value=evaluate(property.Value,e)
     if property.Method then value.HomeObject=result end
     if type(value)=='table'and value.Kind=='function'and value.Name==''then
      value.Name=if type(key)=='table'and key.Kind=='symbol'then '['..(key.Description or '')..']'else VM.string(key)
      value.Values.name=value.Name;if property.Method then value.Method=true end
     end
     if property.Accessor then self.DefineProperty(result,key,descriptorObject({[property.Accessor]=value,enumerable=true,configurable=true}))
     elseif key=='__proto__'and not property.Computed and not property.Method and not property.Shorthand then
      if value==VM.Null or model.IsObject(value)then self.SetPrototype(result,value)end
     else self.DefineProperty(result,key,descriptorObject({value=value,writable=true,enumerable=true,configurable=true}))end
    end
   end
   return result
  elseif k=='member'then
   if n.Object.Kind=='super'then local read=self.Classes:SuperReference(e,propertyKey(evaluate(n.Key,e)));return read()end
   local value=evaluate(n.Object,e);if value==SHORT or(n.Optional and nullish(value))then return SHORT end
   if n.Private then return self.Classes:GetPrivate(e,value,propertyKey(evaluate(n.Key,e)))end
   return get(value,propertyKey(evaluate(n.Key,e)))
  elseif k=='template'then
   if n.Tag then
    local fn,receiver=targetReference(n.Tag,e);local strings=templateObjects[n]
    if not strings then
     local values={};for i=1,#n.Parts,2 do table.insert(values,n.Parts[i].Value)end;strings=array(values);local raw=array(table.clone(n.Raw))
     for i=0,raw.Length-1 do self.DefineProperty(raw,tostring(i),descriptorObject({writable=false,configurable=false}));self.DefineProperty(strings,tostring(i),descriptorObject({writable=false,configurable=false}))end
     self.DefineProperty(raw,'length',descriptorObject({writable=false}));self.DefineProperty(strings,'length',descriptorObject({writable=false}));self.PreventExtensions(raw)
     self.DefineProperty(strings,'raw',descriptorObject({value=raw,writable=false,enumerable=false,configurable=false}));self.PreventExtensions(strings);templateObjects[n]=strings
    end
    local args={strings};for i=2,#n.Parts,2 do table.insert(args,evaluate(n.Parts[i],e))end;return call(fn,args,receiver)
   end
   local parts,size={},0;for _,part in n.Parts do local text=toString(evaluate(part,e));size+=#text;assert(size<=65536,'JavaScript string budget exceeded');table.insert(parts,text)end;return Strings.canonical(table.concat(parts))
  elseif k=='await'then
   if self.Generators:IsActive()then local value=self.Generators:Await(evaluate(n.Value,e));step();return value end
   if not options.Async then VM.throw(VM.error('TypeError','await requires the HTML Promise realm'))end
   local value=options.Async:Await(evaluate(n.Value,e));step();return value
  elseif k=='yield'then return self.Generators:Yield(if n.Value then evaluate(n.Value,e)else VM.Undefined,n.Delegate)
  elseif k=='unary'then
   if n.Op=='typeof'then
    if n.Value.Kind=='identifier'then local scope=e;local found=false;while scope do if(if scope==self.Global then globalEnvironment:Binding(n.Value.Name)else scope.Bindings[n.Value.Name])then found=true;break end;scope=scope.Parent end;if not found then return 'undefined'end end
    local v=evaluate(n.Value,e);return if v==VM.Undefined then 'undefined'elseif v==VM.Null then 'object'elseif VM.callable(v)then 'function'elseif BigInt.is(v)then 'bigint'elseif type(v)=='table'and v.Kind=='symbol'then 'symbol'elseif type(v)=='table'then 'object'else type(v)
   elseif n.Op=='delete'then
    local value=n.Value;while value.Kind=='group'or value.Kind=='chain'do value=value.Value end
    if value.Kind=='member'then local receiver=evaluate(value.Object,e);if receiver==SHORT or(value.Optional and nullish(receiver))then return true end;return self.Delete(receiver,propertyKey(evaluate(value.Key,e)),e.Strict)
    elseif value.Kind=='identifier'then
     local scope=e;while scope do
      local slot=if scope==self.Global then globalEnvironment:Binding(value.Name)else scope.Bindings[value.Name]
      if slot then return if slot.Delete then slot.Delete(e.Strict)elseif scope==self.Global and slot.GlobalObject then globalEnvironment:Delete(value.Name,e.Strict)else false end
      scope=scope.Parent
     end
     return true
    end
    evaluate(value,e);return true
   end
   local v=evaluate(n.Value,e)
   if n.Op=='!'then return not truth(v)elseif n.Op=='void'then return VM.Undefined end
   v=primitive(v,'number');if BigInt.is(v)then return self.BigInt:Unary(n.Op,v)end
   return if n.Op=='-'then -number(v)elseif n.Op=='~'then signed(bit32.bnot(uint(v)))else number(v)
  elseif k=='conditional'then return evaluate(if truth(evaluate(n.Test,e))then n.Yes else n.No,e)
  elseif k=='binary'then
   if n.Left.Kind=='private-name'and n.Op=='in'then return self.Classes:HasPrivate(e,evaluate(n.Right,e),n.Left.Name)end
   local a=evaluate(n.Left,e)
   if n.Op=='&&'then return if truth(a)then evaluate(n.Right,e)else a elseif n.Op=='||'then return if truth(a)then a else evaluate(n.Right,e)elseif n.Op=='??'then return if nullish(a)then evaluate(n.Right,e)else a end
   return binary(n.Op,a,evaluate(n.Right,e))
  elseif k=='assign'then
   if n.Target.Kind=='array-pattern'or n.Target.Kind=='object-pattern'then local value=evaluate(n.Value,e);bindPattern(n.Target,value,nil,e);return value end
   local read,write=reference(n.Target,e);local old=if n.Op~='='then read()else nil
   if(n.Op=='&&='and not truth(old))or(n.Op=='||='and truth(old))or(n.Op=='??='and not nullish(old))then return old end
   local value=evaluate(n.Value,e)
   if n.Op=='='and n.Target.Kind=='identifier'then namedEvaluation(n.Value,value,n.Target.Name)end
   if n.Op~='='and n.Op~='&&='and n.Op~='||='and n.Op~='??='then value=binary(n.Op:sub(1,-2),old,value)end
   write(value);return value
  elseif k=='update'then
   local read,write=reference(n.Target,e);local old=primitive(read(),'number');if not BigInt.is(old)then old=number(old)end
   local value=if BigInt.is(old)then self.BigInt:Binary('+',old,self.BigInt:FromNumber(n.Delta))else old+n.Delta
   write(value);return if n.Prefix then value else old
  elseif k=='call'or k=='new'then
   if k=='call'and n.Target.Kind=='super'then return self.Classes:SuperCall(e,arguments(n.Args,e))end
   local target,receiver=targetReference(n.Target,e)
   if target==SHORT or(n.Optional and nullish(target))then return SHORT end
   local args=arguments(n.Args,e)
   local direct=n.Target;while direct.Kind=='group'do direct=direct.Value end
   if k=='call'and not n.Optional and direct.Kind=='identifier'and direct.Name=='eval'and target==self.DynamicCode.EvalFunction then return self.DynamicCode:Eval(if args[1]==nil then VM.Undefined else args[1],e)end
   return if k=='new'then construct(target,args)else call(target,args,receiver)
  end
  error('Unsupported JavaScript expression '..k)
 end
 local function patternNames(pattern,out)
  out=out or {}
  if pattern.Kind=='identifier'then table.insert(out,pattern.Name)
  elseif pattern.Kind=='default-pattern'or pattern.Kind=='rest'then patternNames(pattern.Pattern,out)
  elseif pattern.Kind=='array-pattern'then for _,item in pattern.Items do patternNames(item,out)end
  elseif pattern.Kind=='object-pattern'then for _,item in pattern.Properties do patternNames(item.Pattern,out)end end
  return out
 end
 bindPattern=function(pattern,value,scope,context)
  step();local kind=pattern.Kind
  if kind=='hole'then return
  elseif kind=='default-pattern'then if value==VM.Undefined then value=evaluate(pattern.Value,context or scope);if pattern.Pattern.Kind=='identifier'then namedEvaluation(pattern.Value,value,pattern.Pattern.Name)end end;bindPattern(pattern.Pattern,value,scope,context)
  elseif kind=='rest'then bindPattern(pattern.Pattern,value,scope,context)
  elseif kind=='identifier'or kind=='member'then
   if not scope then local _,write=reference(pattern,context);write(value);return end
   local slot=scope.Bindings[pattern.Name]
   if not slot then slot={Value=UNINITIALIZED};scope.Bindings[pattern.Name]=slot end;if slot.Set then slot.Set(value,scope.Strict)else slot.Value=value end
  elseif kind=='array-pattern'then
   local nextValue,close=self.Iterator(value);local exhausted=false
   local ok,message=protected(function()
    for _,item in pattern.Items do
     if item.Kind=='rest'then local values={};while not exhausted do local more,v=nextValue();if not more then exhausted=true;break end;assert(#values<16384,'JavaScript array budget exceeded');table.insert(values,v)end;bindPattern(item.Pattern,array(values),scope,context)
     else local v=VM.Undefined;if not exhausted then local more;more,v=nextValue();if not more then exhausted=true;v=VM.Undefined end end;bindPattern(item,v,scope,context)end
    end
   end)
   if not exhausted and close then if ok then close()else protected(close)end end
   if not ok then error(message,0)end
  elseif kind=='object-pattern'then
   if nullish(value)then VM.throw(VM.error('TypeError','Cannot destructure null or undefined'))end
   local excluded={}
   for _,item in pattern.Properties do
    if item.Rest then
     local result=object({});for _,key in self.OwnKeys(value,false)do if not excluded[key]then
      local descriptor=self.GetOwnPropertyDescriptor(value,key)
      if descriptor~=VM.Undefined and truth(get(descriptor,'enumerable'))then self.DefineProperty(result,key,descriptorObject({value=get(value,key),writable=true,enumerable=true,configurable=true}))end
     end end;bindPattern(item.Pattern,result,scope,context)
    else local key=propertyKey(if item.Computed then evaluate(item.Key,context or scope)else item.Key);excluded[key]=true;bindPattern(item.Pattern,get(value,key),scope,context)end
   end
  else error('Unsupported binding pattern '..kind)end
 end
 local function hoistVar(n,e,deletable)
  if n.Kind=='declare'and n.Mode=='var'then
   for _,entry in n.Entries do for _,name in entry.Names or patternNames(entry.Pattern)do
    local existing=e.Bindings[name];assert(not existing or not existing.Lexical,'Duplicate declaration: '..name)
    if e==self.Global then globalEnvironment:DeclareVar(name,deletable)elseif not existing then e.Bindings[name]={Value=VM.Undefined}end
   end end
  elseif n.Kind=='block'or n.Kind=='program'then for _,child in n.Items do hoistVar(child,e,deletable)end
  elseif n.Kind=='if'then hoistVar(n.Yes,e,deletable);if n.No then hoistVar(n.No,e,deletable)end
  elseif n.Kind=='try'then hoistVar(n.Body,e,deletable);if n.Handler then hoistVar(n.Handler,e,deletable)end;if n.Finalizer then hoistVar(n.Finalizer,e,deletable)end
  elseif n.Kind=='for'or n.Kind=='while'or n.Kind=='do'or n.Kind=='for-each'then if n.Init then hoistVar(n.Init,e,deletable)end;hoistVar(n.Body,e,deletable)
  elseif n.Kind=='switch'then for _,case in n.Cases do for _,child in case.Items do hoistVar(child,e,deletable)end end
  elseif n.Kind=='label'then hoistVar(n.Body,e,deletable)end
 end
 local function prepare(items,e)
  for _,n in items do
   if n.Kind=='class-declaration'then
    assert(not e.Bindings[n.Name]or e==self.Global and not e.Bindings[n.Name].Lexical,'Duplicate lexical declaration: '..n.Name);e.Bindings[n.Name]={Value=UNINITIALIZED,Const=false,Lexical=true}
   end
   if n.Kind=='declare'and n.Mode~='var'then for _,entry in n.Entries do for _,name in entry.Names or patternNames(entry.Pattern)do
    assert(not e.Bindings[name]or e==self.Global and not e.Bindings[name].Lexical,'Duplicate lexical declaration: '..name);e.Bindings[name]={Value=UNINITIALIZED,Const=n.Mode~='let',Lexical=true}
   end end end
  end
  for _,n in items do if n.Kind=='function-declaration'then
   assert(not e.Bindings[n.Name]or not e.Bindings[n.Name].Lexical,'Duplicate function declaration')
   if e==self.Global then globalEnvironment:DeclareFunction(n.Name,evaluate(n.Value,e),e.EvalDeletable)
   else e.Bindings[n.Name]={Value=evaluate(n.Value,e)}end
  end end
 end
 local function registerResource(scope,value,async)
  if not scope.ResourceScope then scope.ResourceScope=self.ResourceStacks:NewScope()end
  self.ResourceStacks:RegisterScope(scope.ResourceScope,value,async)
 end
 local function finishScope(scope,ok,result)
  if not ok and(not self.Alive or self.Steps>maxSteps)then error(result,0)end
  if not ok and self.Generators:IsReturn(result)then ok,result=true,{Kind='return',Value=self.Generators:ReturnValue(result)}end
  local resource=scope.ResourceScope;scope.ResourceScope=nil
  if resource then
   local async=self.ResourceStacks:ScopeIsAsync(resource)
   local disposal=self.ResourceStacks:DisposeScope(resource,not ok,if not ok then VM.exceptionValue(result)else VM.Undefined)
   if async then awaitValue(disposal)end
  end
  if not ok then error(result,0)end
  return result
 end
 local function list(items,e,prepared,outerResources)
  if not prepared then prepare(items,e)end
  local resources=false;for _,item in items do if item.Kind=='declare'and(item.Mode=='using'or item.Mode=='await-using')then resources=true;break end end
  if resources and not outerResources then
   local ok,result=protected(function()for _,n in items do local out=execute(n,e);if out then return out end end end)
   return finishScope(e,ok,result)
  end
  for _,n in items do local result=execute(n,e);if result then return result end end
 end
 local function loopAction(result,label)
  if not result then return 'next'end
  if result.Kind=='break'and(result.Label==nil or result.Label==label)then return 'break'end
  if result.Kind=='continue'and(result.Label==nil or result.Label==label)then return 'next'end
  return 'propagate'
 end
 execute=function(n,e)
  step();local k=n.Kind
  if k=='program'then hoistVar(n,e);return list(n.Items,e)
  elseif k=='block'then return list(n.Items,env(e))
  elseif k=='class-declaration'then e.Bindings[n.Name].Value=evaluate(n.Value,e)
  elseif k=='declare'then
   for _,entry in n.Entries do
    local scope=e;if n.Mode=='var'then while not scope.Function do scope=scope.Parent end end
    for _,name in entry.Names or patternNames(entry.Pattern)do if not scope.Bindings[name]then scope.Bindings[name]={Value=UNINITIALIZED,Const=n.Mode~='var'and n.Mode~='let',Lexical=n.Mode~='var'}end end
    if entry.Value or n.Mode~='var'then
     local value=if entry.Value then evaluate(entry.Value,e)else VM.Undefined
     if entry.Pattern.Kind=='identifier'and entry.Value then namedEvaluation(entry.Value,value,entry.Pattern.Name)end
     if n.Mode=='using'or n.Mode=='await-using'then registerResource(scope,value,n.Mode=='await-using')end
     if n.Mode=='var'and entry.Pattern.Kind=='identifier'then local cursor=e;while cursor~=scope do if cursor.CatchParameter==entry.Pattern.Name then bindPattern(entry.Pattern,value,cursor,e);scope=nil;break end;cursor=cursor.Parent end end
     if scope then bindPattern(entry.Pattern,value,scope,e)end
    end
   end
  elseif k=='expression'then local value=evaluate(n.Value,e);local state=evalState(e);if state then state.Last=value end
  elseif k=='if'then
   local state=evalState(e);if state then state.Last=VM.Undefined end
   if truth(evaluate(n.Test,e))then return execute(n.Yes,e)elseif n.No then return execute(n.No,e)end
  elseif k=='return'then return {Kind='return',Value=if n.Value then evaluate(n.Value,e)else VM.Undefined}
  elseif k=='throw'then VM.throw(evaluate(n.Value,e))
  elseif k=='try'then
   local state=evalState(e);if state then state.Last=VM.Undefined end
   local ok,result=completion(n.Body,e)
   if not ok and self.Generators:IsReturn(result)then ok,result=true,{Kind='return',Value=self.Generators:ReturnValue(result)}end
   if not ok and(not self.Alive or self.Steps>maxSteps)then error(result,0)end
   if not ok and n.Handler then
    local scope=env(e)
    if n.Parameter then for _,name in patternNames(n.Parameter)do scope.Bindings[name]={Value=UNINITIALIZED,Lexical=true}end
     if n.Parameter.Kind=='identifier'then scope.CatchParameter=n.Parameter.Name end
     local bindOK,bindError=protected(bindPattern,n.Parameter,VM.exceptionValue(result),scope)
     if bindOK then ok,result=completion(n.Handler,scope)else ok,result=false,bindError end
    else ok,result=completion(n.Handler,scope)end
    if not ok and(not self.Alive or self.Steps>maxSteps)then error(result,0)end
   end
   if n.Finalizer then
    local state=evalState(e);local saved=state and state.Last
    local finalOK,finalResult=completion(n.Finalizer,e)
    if state then state.Last=saved end
    if not finalOK then error(finalResult,0)end;if finalResult then return finalResult end
   end
   if not ok then error(result,0)end;return result
  elseif k=='break'or k=='continue'then return {Kind=k,Label=n.Label}
  elseif k=='label'then local result=execute(n.Body,e);return if result and result.Kind=='break'and result.Label==n.Name then nil else result
  elseif k=='switch'then
   local state=evalState(e);if state then state.Last=VM.Undefined end
   local value=evaluate(n.Test,e);local scope=env(e);local all={};for _,case in n.Cases do for _,item in case.Items do table.insert(all,item)end end;prepare(all,scope)
   local selected,default=nil,nil
   for i,case in n.Cases do if not case.Test then default=i elseif selected==nil and binary('===',value,evaluate(case.Test,scope))then selected=i;break end end
   selected=selected or default
   local function runSwitch()
    if selected then for i=selected,#n.Cases do local result=list(n.Cases[i].Items,scope,true,true);if result then return if result.Kind=='break'and not result.Label then nil else result end end end
   end
   local resources=false;for _,item in all do if item.Kind=='declare'and(item.Mode=='using'or item.Mode=='await-using')then resources=true;break end end
   if resources then local ok,result=protected(runSwitch);return finishScope(scope,ok,result)else return runSwitch()end
  elseif k=='while'or k=='for'or k=='do'then
   local state=evalState(e);if state then state.Last=VM.Undefined end
   local scope=env(e)
   local perIteration=k=='for'and n.Init and n.Init.Kind=='declare'and n.Init.Mode=='let'
   local function runLoop()
    if n.Init then execute(n.Init,scope)end
    local first=true
    while k=='do'and first or not n.Test or truth(evaluate(n.Test,scope))do
     first=false;step();local result=execute(n.Body,scope);local action=loopAction(result,n.Label)
     if action=='break'then break elseif action=='propagate'then return result end
     if perIteration then local fresh=env(scope.Parent);for key,slot in scope.Bindings do fresh.Bindings[key]=table.clone(slot)end;scope=fresh end
     if n.Update then evaluate(n.Update,scope)end
    end
   end
   local resources=n.Init and n.Init.Kind=='declare'and(n.Init.Mode=='using'or n.Init.Mode=='await-using')
   if resources then local ok,result=protected(runLoop);return finishScope(scope,ok,result)else return runLoop()end
 elseif k=='for-each'then
   local state=evalState(e);if state then state.Last=VM.Undefined end
   local head=env(e)
   if n.Init.Kind=='declare'and n.Init.Mode~='var'then for _,name in n.Init.Entries[1].Names do head.Bindings[name]={Value=UNINITIALIZED,Lexical=true,Const=n.Init.Mode~='let'}end end
   local value=evaluate(n.Value,head);local nextValue,close
   if n.Mode=='in'then
    local keys,seen={},{};local cursor=value
    while not nullish(cursor)do
     for _,key in self.OwnKeys(cursor,false)do if type(key)=='string'and not seen[key]then seen[key]=true;local desc=self.GetOwnPropertyDescriptor(cursor,key);if truth(get(desc,'enumerable'))then table.insert(keys,key)end end end
     cursor=if type(cursor)=='table'then self.GetPrototype(cursor)else VM.Null
    end
    local at=0;nextValue=function()at+=1;return at<=#keys,keys[at]or VM.Undefined end
   else nextValue,close=self.Iterator(value,n.Await)end
   local exhausted=false;local result
   local ok,message=protected(function()
    while true do
     -- A failing IteratorStepValue does not close the iterator. Once an
     -- item has been obtained, binding/body/disposal failures do close it.
     exhausted=true;local more,item=nextValue();if not more then break end;exhausted=false
     local scope=env(e)
     local resources=n.Init.Kind=='declare'and(n.Init.Mode=='using'or n.Init.Mode=='await-using')
     local function runIteration()
      if n.Init.Kind=='declare'then
       local entry=n.Init.Entries[1];local target=scope
       if n.Init.Mode=='var'then target=e;while not target.Function do target=target.Parent end end
       for _,name in entry.Names do if not target.Bindings[name]then target.Bindings[name]={Value=UNINITIALIZED,Lexical=n.Init.Mode~='var',Const=n.Init.Mode~='var'and n.Init.Mode~='let'}end end
       if resources then registerResource(scope,item,n.Init.Mode=='await-using')end
       bindPattern(entry.Pattern,item,target,scope)
      else bindPattern(n.Init.Value or n.Init,item,nil,scope)end
      return execute(n.Body,scope)
     end
     if resources then local iterationOK,out=protected(runIteration);result=finishScope(scope,iterationOK,out)else result=runIteration()end
     local action=loopAction(result,n.Label)
     if action=='break'then result=nil;break elseif action=='propagate'then break end
     -- Normal and consumed continue completions belong to this iteration.
     -- Do not return the final continue when the iterator is exhausted; the
     -- statements following the loop must still execute.
     result=nil
    end
   end)
   if not ok and self.Generators:IsReturn(message)then ok,result=true,{Kind='return',Value=self.Generators:ReturnValue(message)}end
   if not exhausted and close then if ok then close()else protected(close)end end
   if not ok then error(message,0)end;return result
  end
 end
 local function functionScope(fn,args,receiver,newTarget,classExecution)
  local scope=env(fn.Environment);scope.Function=true;scope.Strict=fn.Strict;scope.ScriptContext=fn.ScriptContext
  scope.EvalState=false
  scope.HomeObject=fn.HomeObject;scope.ClassExecution=classExecution
  local argsObject
  if not fn.Arrow then
   scope.NewTarget=newTarget or VM.Undefined
   scope.Bindings.this={Value=if fn.Strict then(if receiver==nil then VM.Undefined else receiver)elseif nullish(receiver)then globals.globalThis or VM.Undefined else self.ToObject(receiver)}
   if classExecution then scope.Bindings.this={Value=VM.Undefined,Get=function()
    if classExecution.This==UNINITIALIZED then VM.throw(VM.error('ReferenceError','Must call super constructor before accessing this'))end
    return classExecution.This
   end}end
   argsObject=object({});argsObject.Kind='arguments';argsObject.Mapped={}
   for i,value in args do self.DefineProperty(argsObject,tostring(i-1),descriptorObject({value=value,writable=true,enumerable=true,configurable=true}))end
   self.DefineProperty(argsObject,'length',descriptorObject({value=#args,writable=true,enumerable=false,configurable=true}))
   local simple=true;for _,param in fn.Params do if param.Kind~='identifier'then simple=false;break end end
   if fn.Strict or not simple then
    local function poison()VM.throw(VM.error('TypeError','arguments.callee is not accessible'))end
    self.DefineProperty(argsObject,'callee',descriptorObject({get=poison,set=poison,enumerable=false,configurable=false}))
   else self.DefineProperty(argsObject,'callee',descriptorObject({value=fn,writable=true,enumerable=false,configurable=true}))end
   if self.SymbolIterator then self.DefineProperty(argsObject,self.SymbolIterator,descriptorObject({value=get(self.Prototypes.Array,'values'),writable=true,enumerable=false,configurable=true}))end
   scope.Bindings.arguments={Value=argsObject}
  else scope.Bindings.this=fn.LexicalThisBinding or {Value=VM.Undefined}end
  for _,param in fn.Params do for _,name in patternNames(param)do scope.Bindings[name]={Value=UNINITIALIZED}end end
  for i,param in fn.Params do
   local value
   if param.Kind=='rest'then local values={};for j=i,#args do table.insert(values,args[j])end;value=array(values)
   else value=if args[i]==nil then VM.Undefined else args[i]end
   bindPattern(param,value,scope)
  end
  if not fn.Arrow and not fn.Strict then
   local simple=true;for _,param in fn.Params do if param.Kind~='identifier'then simple=false;break end end
   if simple then
    local seen={};local mapped=argsObject.Mapped
    for i=#fn.Params,1,-1 do local name=fn.Params[i].Name;if not seen[name]then seen[name]=true;if i<=#args then mapped[tostring(i-1)]=scope.Bindings[name]end end end
   end
  end
  local nonSimple=false;for _,param in fn.Params do if param.Kind~='identifier'then nonSimple=true;break end end
  if nonSimple then
   -- Defaults capture the parameter environment. Body var/parameter writes
   -- live in a separate environment and must not become visible to it.
   local bodyScope=env(scope);bodyScope.Function=true;bodyScope.EvalState=false
   for _,param in fn.Params do for _,name in patternNames(param)do bodyScope.Bindings[name]={Value=bindingValue(scope.Bindings[name])}end end
   scope=bodyScope
  end
  hoistVar(fn.Body,scope)
  return scope
 end
 local function executeFunctionBody(fn,scope)
  local frames=contexts();table.insert(frames,fn.ScriptContext or false)
  local out=execute(fn.Body,scope);table.remove(frames)
  return if out and out.Kind=='return'then out.Value else VM.Undefined
 end
 local function executeFunction(fn,args,receiver,newTarget,classExecution)
  return executeFunctionBody(fn,functionScope(fn,args,receiver,newTarget,classExecution))
 end
 construct=function(fn,args,newTarget)
  step()
  newTarget=newTarget or fn
  if type(fn)=='table'and fn.VMOwner and fn.VMOwner~=self then return fn.VMOwner:Construct(fn,args,newTarget)end
  if type(fn)=='table'and fn.Kind=='native-function'and fn.Construct then return fn.Construct(args,newTarget)end
  if type(fn)~='table'or fn.Kind~='function'or fn.Async or fn.Generator or fn.Arrow or fn.Method then VM.throw(VM.error('TypeError','Value is not a constructor'))end
  local prototype=get(newTarget,'prototype');if not model.IsObject(prototype)then prototype=self.FunctionRealm(newTarget).Prototypes.Object end
  local instance=object({},prototype);self.Depth+=1;assert(self.Depth+stackBase<=64,'JavaScript call depth exceeded')
  local result=executeFunction(fn,args,instance,newTarget);self.Depth-=1
  return if model.IsObject(result)then result else instance
 end
 call=function(fn,args,receiver)
  if type(fn)=='table'and fn.VMOwner and fn.VMOwner~=self then step();return fn.VMOwner:Call(fn,args,receiver)end
  step();self.Depth+=1;assert(self.Depth+stackBase<=64,'JavaScript call depth exceeded')
  local result
  if type(fn)=='function' then result=fn(args,receiver)
  elseif type(fn)=='table' and fn.Kind=='native-function' then result=fn.Call(args,receiver)
  else if type(fn)~='table' or fn.Kind~='function' then VM.throw(VM.error('TypeError','Value is not callable')) end
   if fn.Generator then
    local scope=functionScope(fn,args,receiver)
    result=self.Generators:Create(function()return executeFunctionBody(fn,scope)end,get(fn,'prototype'),fn.Async)
   elseif fn.Async then
    if not options.Async then VM.throw(VM.error('TypeError','async functions require the HTML Promise realm')) end
    result=options.Async:Start(function()return executeFunction(fn,args,receiver)end)
   else result=executeFunction(fn,args,receiver) end
  end
  self.Depth-=1;return if result==nil then VM.Undefined else result
 end
 -- Host work can read JS objects or synchronously dispatch another event.
 -- It shares a budget with nested callbacks; independent entries reset it.
 -- Restore depth even when the host catches a nested callback error.
 local entries,scriptEntries=0,0
 local executionThreads={}
 local function enter(scriptEntry,action,...)
  assert(self.Alive,'JavaScript runtime disposed')
  if entries==0 then self.Steps=0;self.Depth=0 end
  local thread=coroutine.running();executionThreads[thread]=(executionThreads[thread]or 0)+1
  local previousRealm=activeRealms[thread];activeRealms[thread]=self
  local depth=self.Depth;local frames=contexts();local count=#frames;entries+=1;if scriptEntry then scriptEntries+=1 end
  local ok,result=pcall(action,...)
  entries-=1;if scriptEntry then scriptEntries-=1 end;self.Depth=depth;restoreContexts(frames,count)
  executionThreads[thread]-=1;if executionThreads[thread]==0 then executionThreads[thread]=nil end
  activeRealms[thread]=previousRealm
  if not ok then error(result,0) end
  return result
 end
 function self:Call(fn,args,receiver)return enter(type(fn)~='function',call,fn,args,receiver)end
 function self:ExecuteHost(action,...)return enter(false,action,...)end
 function self:IsExecuting()return entries>0 end
 -- Internal Luau task wrappers and measurement phases own a budget without
 -- leaving an author-script frame on the stack between native callbacks.
 function self:IsRunningScript()return scriptEntries>0 end
 function self:IsExecutingOnCurrentThread()return executionThreads[coroutine.running()]~=nil end
 function self:Install(action)
  assert(self.Alive and entries==0,'Host installation requires an idle live realm')
  local previous=self.Initializing;self.Initializing=true
  local thread=coroutine.running();local previousRealm=activeRealms[thread];activeRealms[thread]=self
  local ok,result=pcall(action);self.Initializing=previous;activeRealms[thread]=previousRealm
  if not ok then error(result,0)end;return result
 end
 function self:Construct(fn,args,newTarget)return enter(true,construct,fn,args,newTarget)end
 function self:ResumeAsync(record,rejected,value)
  assert(self.Alive,'JavaScript runtime disposed')
  local depth,base=self.Depth,stackBase
  self.Depth=record.Depth
  -- Before the first await, async calls still share their caller's physical
  -- stack limit. A later microtask resumes a standalone stack with saved scopes.
  stackBase=if record.Started then 0 else base+depth-1
  record.Started=true
  local thread=record.Thread;executionThreads[thread]=(executionThreads[thread]or 0)+1
  local frames=scriptContexts[thread];if not frames then frames={};scriptContexts[thread]=frames end
  frames.Caller=scriptContexts[coroutine.running()]
  -- A suspended interpreter executes on its own coroutine. Intrinsic errors
  -- must retain that function's realm even when another realm resumes it.
  local previousRealm=activeRealms[thread];activeRealms[thread]=self
  scriptEntries+=1;local ok,result=coroutine.resume(thread,rejected,value);scriptEntries-=1;frames.Caller=nil
  if not ok or coroutine.status(thread)=='dead'then table.clear(frames);scriptContexts[thread]=nil end
  activeRealms[thread]=previousRealm
  executionThreads[thread]-=1;if executionThreads[thread]==0 then executionThreads[thread]=nil end
  record.Depth=self.Depth;self.Depth,stackBase=depth,base
  return ok,result
 end
 function self:ResumeGenerator(record,mode,value)return self:ResumeAsync(record,mode,value)end
 function self:Run(source,url)
  return enter(true,function()
   local previous=self.CurrentSourceURL;self.CurrentSourceURL=url or options.SourceURL
   local frames=contexts();table.insert(frames,if self.CurrentSourceURL then {URL=self.CurrentSourceURL,VM=self}else false)
   local ok,result=pcall(function()
    local parsed,ast=pcall(Syntax.parse,source)
    if not parsed then VM.throw(VM.error('SyntaxError',tostring(ast)))end
    globalEnvironment:Check(ast);self.Global.Strict=ast.Strict
    local out=execute(ast,self.Global)
    assert(not out,'Illegal top-level return, break or continue')
   end)
   self.CurrentSourceURL=previous;table.remove(frames);if not ok then error(result,0)end
  end)
 end
 function self:Destroy()
  if not self.Alive then return end;self.Alive=false
  if options.Async then options.Async:Destroy() end
  if self.Reflection then self.Reflection:Destroy() end
  if self.BigInt then self.BigInt:Destroy()end
  if self.RegExp then self.RegExp:Destroy()end
  if self.ResourceStacks then self.ResourceStacks:Destroy()end
  if self.Intl then self.Intl:Destroy()end
  if self.Classes then self.Classes:Destroy()end
  if self.Generators then self.Generators:Destroy()end
  if self.IteratorHelpers then self.IteratorHelpers:Destroy()end
  if self.DynamicCode then self.DynamicCode:Destroy()end
  globalEnvironment:Destroy()
  table.clear(self.Global.Bindings)
 end
 function self:CreateModule(ast,meta,url)
  return enter(true,function()
   assert(ast.Module,'Expected module AST')
   local scope=env(self.Global);scope.Function=true;scope.Strict=true
   local record={AST=ast,Scope=scope,Meta=meta,URL=url,ScriptContext={URL=url,VM=self}};scope.Module=record
   scope.Bindings.this={Value=VM.Undefined,Const=true}
   for _,entry in ast.Imports do scope.Bindings[entry.Local]={Value=UNINITIALIZED,Const=true,Lexical=true}end
   hoistVar(ast,scope);prepare(ast.Items,scope);return record
  end)
 end
 function self:SetModuleImport(record,name,read)
  local slot=assert(record.Scope.Bindings[name],'Missing module import')
  slot.Get=read;slot.Value=VM.Undefined
 end
 function self:ReadModuleBinding(record,name)return bindingValue(binding(record.Scope,name))end
 function self:EvaluateModule(record)
  return enter(true,function()
   local function body()local frames=contexts();table.insert(frames,record.ScriptContext);local out=list(record.AST.Items,record.Scope,true);table.remove(frames);assert(not out,'Illegal module completion');return VM.Undefined end
   if record.AST.HasTopLevelAwait and options.Async then return options.Async:Start(body,{ModuleScript=true})end
   return body()
  end)
 end
 self.Global.Bindings.this={Value=globals.globalThis or VM.Undefined,Const=true}
 self.Global.Bindings.NaN={Value=0/0,Const=true}
 self.Global.Bindings.Infinity={Value=math.huge,Const=true}
 self.Global.Bindings.Boolean={Value=function(args)return truth(if args[1]==nil then VM.Undefined else args[1])end,Const=true}
 self.Global.Bindings.undefined={Value=VM.Undefined,Const=true}
 self.Global.Bindings.Number={Value=function(args) return number(if args[1]==nil then 0 else args[1]) end,Const=true}
 self.Global.Bindings.String={Value=function(args) return VM.string(if args[1]==nil then '' else args[1]) end,Const=true}
 for _,name in {'Error','TypeError','RangeError','ReferenceError','SyntaxError'} do
  local function create(args)return VM.error(name,if args[1]==nil or args[1]==VM.Undefined then '' else VM.string(args[1]))end
  self.Global.Bindings[name]={Value={Kind='native-function',Call=create,Construct=create,
   Get=function(key)return if key=='name' then name elseif key=='length' then 1 else VM.Undefined end},Const=true}
 end
 local function aggregateError(args)
  local message=if args[2]==nil or args[2]==VM.Undefined then '' else VM.string(args[2])
  local result=VM.error('AggregateError',message)
  local errorOptions=args[3]
  if type(errorOptions)=='table' and errorOptions~=VM.Null and errorOptions~=VM.Undefined then
   local cause=get(errorOptions,'cause');if cause~=VM.Undefined then result.Set('cause',cause) end
  end
  local nextValue=self.Iterator(if args[1]==nil then VM.Undefined else args[1]);local errors={}
  while true do
   local more,value=nextValue();if not more then break end
   assert(#errors<16384,'JavaScript array budget exceeded');table.insert(errors,value)
  end
  result.Set('errors',array(errors));return result
 end
 self.Global.Bindings.AggregateError={Value={Kind='native-function',Call=aggregateError,Construct=aggregateError,
  Get=function(key)return if key=='name' then 'AggregateError' elseif key=='length' then 2 else VM.Undefined end},Const=true}
 StandardLibrary.install(self,globals,options)
 local errorProto=object({},self.Prototypes.Object);self.Prototypes.Error=errorProto
 self.DefineProperty(errorProto,'name',descriptorObject({value='Error',writable=true,enumerable=false,configurable=true}))
 self.DefineProperty(errorProto,'message',descriptorObject({value='',writable=true,enumerable=false,configurable=true}))
 self.DefineProperty(errorProto,'toString',descriptorObject({value=function(_,receiver)
  if type(receiver)~='table'or nullish(receiver)then VM.throw(VM.error('TypeError','Error.toString receiver is not an object'))end
  local name,message=get(receiver,'name'),get(receiver,'message');name=if name==VM.Undefined then 'Error'else VM.string(name);message=if message==VM.Undefined then ''else VM.string(message)
  return if name==''then message elseif message==''then name else name..': '..message
 end,writable=true,enumerable=false,configurable=true}))
 for _,name in {'Error','TypeError','RangeError','ReferenceError','SyntaxError','EvalError','URIError','AggregateError'}do
  local proto=if name=='Error'then errorProto else object({},errorProto);self.Prototypes[name]=proto
  if name~='Error'then self.DefineProperty(proto,'name',descriptorObject({value=name,writable=true,enumerable=false,configurable=true}));self.DefineProperty(proto,'message',descriptorObject({value='',writable=true,enumerable=false,configurable=true}))end
  local function createError(args,newTarget)
   local prototype=proto
   if newTarget then prototype=get(newTarget,'prototype');if not model.IsObject(prototype)then prototype=self.FunctionRealm(newTarget).Prototypes[name]or proto end end
   local result=object({},prototype);result.Kind='error'
   local message=if name=='AggregateError'then args[2]else args[1]
   if message~=nil and message~=VM.Undefined then self.DefineProperty(result,'message',descriptorObject({value=VM.string(message),writable=true,enumerable=false,configurable=true}))end
   local errorOptions=if name=='AggregateError'then args[3]else args[2]
   if type(errorOptions)=='table'and not nullish(errorOptions)and self.Has(errorOptions,'cause')then self.DefineProperty(result,'cause',descriptorObject({value=get(errorOptions,'cause'),writable=true,enumerable=false,configurable=true}))end
   if name=='AggregateError'then local errors={};spreadValues(errors,if args[1]==nil then VM.Undefined else args[1]);self.DefineProperty(result,'errors',descriptorObject({value=array(errors),writable=true,enumerable=false,configurable=true}))end
   return result
  end
  local constructor={Kind='native-function',Values={name=name,length=if name=='AggregateError'then 2 else 1,prototype=proto},Prototype=self.Prototypes.Function,Call=function(args)return createError(args,nil)end,Construct=createError,VMOwner=self}
  self.DefineProperty(constructor,'name',descriptorObject({value=name,writable=false,enumerable=false,configurable=true}))
  self.DefineProperty(constructor,'length',descriptorObject({value=if name=='AggregateError'then 2 else 1,writable=false,enumerable=false,configurable=true}))
  self.DefineProperty(constructor,'prototype',descriptorObject({value=proto,writable=false,enumerable=false,configurable=false}))
  self.DefineProperty(proto,'constructor',descriptorObject({value=constructor,writable=true,enumerable=false,configurable=true}));globals[name]=constructor;self.Global.Bindings[name]={Value=constructor}
 end
 local function nativeMethod(name,length,action)
  local value={Kind='native-function',Values={},Prototype=self.Prototypes.Function,Call=action,VMOwner=self}
  self.DefineProperty(value,'name',descriptorObject({value=name,configurable=true}))
  self.DefineProperty(value,'length',descriptorObject({value=length,configurable=true}))
  return value
 end
 local function defineMethod(name,length,action)
  self.DefineProperty(self.Prototypes.Function,name,descriptorObject({value=nativeMethod(name,length,action),writable=true,enumerable=false,configurable=true}))
 end
 self.SymbolHasInstance=get(self.Global.Bindings.Symbol.Value,'hasInstance')
 local hasInstanceMethod=nativeMethod('[Symbol.hasInstance]',1,function(args,receiver)return ordinaryHasInstance(receiver,if args[1]==nil then VM.Undefined else args[1])end)
 self.DefineProperty(hasInstanceMethod,'name',descriptorObject({value='[Symbol.hasInstance]',configurable=true}))
 self.DefineProperty(hasInstanceMethod,'length',descriptorObject({value=1,configurable=true}))
 self.DefineProperty(self.Prototypes.Function,self.SymbolHasInstance,descriptorObject({value=hasInstanceMethod}))
 defineMethod('call',1,function(args,receiver)
  if not VM.callable(receiver)then VM.throw(VM.error('TypeError','Function.call receiver is not callable'))end
  local values={};for i=2,#args do table.insert(values,args[i])end;return call(receiver,values,if args[1]==nil then VM.Undefined else args[1])
 end)
 defineMethod('apply',2,function(args,receiver)
  if not VM.callable(receiver)then VM.throw(VM.error('TypeError','Function.apply receiver is not callable'))end
  local values={};local source=args[2]
  if not nullish(source)then
   if type(source)~='table'then VM.throw(VM.error('TypeError','apply arguments must be an object'))end
   local length=math.max(0,integer(get(source,'length')));assert(length<=16384,'JavaScript argument budget exceeded')
   for i=0,length-1 do table.insert(values,get(source,tostring(i)))end
  end
  return call(receiver,values,if args[1]==nil then VM.Undefined else args[1])
 end)
 defineMethod('bind',1,function(args,receiver)
  if not VM.callable(receiver)then VM.throw(VM.error('TypeError','Function.bind receiver is not callable'))end
  local prefix={};for i=2,#args do table.insert(prefix,args[i])end
  local function combine(values)local result=table.clone(prefix);assert(#result+#values<=16384,'JavaScript argument budget exceeded');for _,v in values do table.insert(result,v)end;return result end
  local boundPrototype=self.GetPrototype(receiver);local boundLength=0
  if self.HasOwn(receiver,'length')then
   local length=get(receiver,'length');if type(length)=='number'then boundLength=math.max(0,integer(length)-#prefix)end
  end
  local name=get(receiver,'name');local boundName='bound '..(if type(name)=='string'then name else '')
  local bound={Kind='native-function',Values={},Prototype=boundPrototype,BoundTarget=receiver,VMOwner=self,
   Call=function(values)return call(receiver,combine(values),if args[1]==nil then VM.Undefined else args[1])end}
  self.DefineProperty(bound,'length',descriptorObject({value=boundLength,configurable=true}))
  self.DefineProperty(bound,'name',descriptorObject({value=boundName,configurable=true}))
  if self.IsConstructor(receiver)then bound.Construct=function(values,newTarget)return construct(receiver,combine(values),if newTarget==bound then receiver else newTarget)end end
  return bound
 end)
 Reflection.install(self,globals)
 self.BigInt=BigInt.install(self,globals)
 self.RegExp=RegExp.install(self,globals)
 ResourceStacks.install(self,globals)
 self.IteratorHelpers=IteratorHelpers.install(self,globals)
 self.Intl=Intl.install(self,globals,{DefaultLocale=options.DefaultLocale or 'en-US',CanonicalizeTag=options.CanonicalizeLocale,
  DefaultTimeZone=options.DefaultTimeZone or options.TimeZone,DateNow=options.DateNow})
 self.Classes=Classes.install(self,{Env=env,Uninitialized=UNINITIALIZED,Evaluate=function(ast,scope)return evaluate(ast,scope)end,
  Execute=function(ast,scope)return execute(ast,scope)end,ExecuteFunction=executeFunction})
 self.Generators=Generators.install(self,globals,{Resume=function(record,mode,value)return self:ResumeGenerator(record,mode,value)end,
  HostCall=function(action)return if options.Async then options.Async:HostCall(action)else action()end})
 self.DynamicCode=DynamicCode.install(self,globals,{Evaluate=function(ast)
  local scope=env(self.Global);scope.Strict=false;return evaluate(ast,scope)
 end,
  Eval=function(source,caller)
   local outer=caller or self.Global;local settings={Strict=caller and caller.Strict==true,PrivateNames={}}
   if caller then
    local cursor=caller;local functionContext=false
    while cursor do
     for name in cursor.PrivateNames or {}do settings.PrivateNames[name]=true end
     if not functionContext and cursor.NewTarget~=nil then
      functionContext=true;settings.NewTarget=true;settings.NoArguments=cursor.ClassInitializer==true
      settings.SuperProperty=cursor.HomeObject~=nil
      settings.SuperCall=cursor.ClassExecution and cursor.ClassExecution.Derived==true
     end
     cursor=cursor.Parent
    end
   end
   local ok,ast=pcall(Syntax.parse,source,settings);if not ok then VM.throw(VM.error('SyntaxError',tostring(ast)))end
   local scope=env(outer);scope.Strict=ast.Strict;scope.EvalState={Last=VM.Undefined}
   local varScope=scope
   if ast.Strict then scope.Function=true else while not varScope.Function do varScope=varScope.Parent end end
   if not ast.Strict then
    local names={}
    local function collect(node)
     if type(node)~='table'or node.Kind=='function'or node.Kind=='class'then return end
     if node.Kind=='declare'and node.Mode=='var'then for _,entry in node.Entries do for _,name in entry.Names do names[name]=true end end end
     if node.Kind=='function-declaration'then return end
     for _,child in node do if type(child)=='table'then if child.Kind then collect(child)else for _,item in child do if type(item)=='table'and item.Kind then collect(item)end end end end end
    end
    collect(ast);for _,item in ast.Items do if item.Kind=='function-declaration'then names[item.Name]=true end end
    for name in names do local cursor=outer;while cursor do
     local slot=cursor.Bindings[name];if slot and slot.Lexical then VM.throw(VM.error('SyntaxError','Eval var conflicts with lexical binding '..name))end
     if cursor==varScope then break end;cursor=cursor.Parent
    end end
   end
   if varScope==self.Global then globalEnvironment:Check(ast,true)end
   hoistVar(ast,varScope,true);prepare(ast.Items,scope)
   if not ast.Strict then for _,item in ast.Items do if item.Kind=='function-declaration'then
    if varScope==self.Global then globalEnvironment:DeclareFunction(item.Name,scope.Bindings[item.Name].Value,true);scope.Bindings[item.Name]=varScope.Bindings[item.Name]
    else local existing=varScope.Bindings[item.Name];if existing then if existing.Set then existing.Set(scope.Bindings[item.Name].Value,false)else existing.Value=scope.Bindings[item.Name].Value end;scope.Bindings[item.Name]=existing
    else varScope.Bindings[item.Name]=scope.Bindings[item.Name]end
    end
   end end end
   local result=list(ast.Items,scope,true);assert(not result,'Illegal eval completion')
   return scope.EvalState.Last
  end})
 -- HTML content handlers use live object environments outside their function
 -- locals. Resolve a property at each identifier lookup, so later changes to
 -- document/form/element properties do not become a copied lexical binding.
 self.SymbolUnscopables=get(globals.Symbol,'unscopables')
 function self:CompileEventHandler(body,name,objects)
  assert(self.Alive,'JavaScript runtime disposed')
  local params=if name=='onerror'and #objects==0 then 'event, source, lineno, colno, error'else 'event'
  local source='function '..name..'('..params..') {\n'..body..'\n}'
  local ok,ast=pcall(Syntax.parse,source)
  if not ok or #ast.Items~=1 or ast.Items[1].Kind~='function-declaration'then VM.throw(VM.error('SyntaxError',if ok then 'Invalid HTML event handler body'else tostring(ast)))end
  local scope=env(self.Global);scope.Strict=false
  for _,value in objects do
   local outer=scope
   scope=env(outer);scope.Strict=false
   scope.Bindings=setmetatable({},{__index=function(_,key)
    if not self.Has(value,key)then return nil end
    local unscopables=if self.SymbolUnscopables then get(value,self.SymbolUnscopables)else VM.Undefined
    if model.IsObject(unscopables)and truth(get(unscopables,key))then return nil end
    return {ObjectReceiver=value,Get=function()return get(value,key)end,Set=function(nextValue,strict)set(value,key,nextValue,strict)end,
     Delete=function(strict)return self.Delete(value,key,strict)end}
   end})
  end
  local handler=ast.Items[1].Value
  -- A declaration AST has no extra self-name lexical binding. The name is an
  -- observable function property, as for OrdinaryFunctionCreate in HTML.
  handler.SourceText=source
  -- HTML explicitly sets [[ScriptOrModule]] to null, regardless of which
  -- external script first reads/dispatches the content handler. Keep a false
  -- sentinel through nested functions so imports use the realm's API base.
  local fn=evaluate(handler,scope);fn.SourceURL=false;fn.ScriptContext=false
  return fn
 end
 globalEnvironment:Sync();self.Initializing=false
 return self
end
return VM
