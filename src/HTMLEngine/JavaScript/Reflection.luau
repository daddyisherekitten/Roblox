--!strict
-- Reflect and Proxy internal-method invariants, using the realm's shared model.
-- Proxy state is retained by its wrapper; revocation drops target/handler roots.
local Reflection={}
function Reflection.install(vm: any,globals: any): any
 if vm.Reflection then return vm.Reflection end
 local VM=assert(vm.Model);local model=assert(vm.ObjectModel,'Reflection requires vm.ObjectModel')
 local U,N=VM.Undefined,VM.Null;local api={Alive=true};vm.Reflection=api
 local states=setmetatable({},{__mode='kv'});local count=0;local handlers={}
 local function check()assert(api.Alive and vm.Alive,'JavaScript reflection disposed')end
 local function fail(message)VM.throw(VM.error('TypeError',message))end
 local function object(value)return model.IsObject(value)end
 local function requireObject(value)if not object(value)then fail('Reflect target must be an object')end;return value end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function descriptor(d)return model.FromDescriptor(d)end
 local function define(target,key,d)vm.DefineProperty(target,key,vm.Object(d,VM.Null))end
 local function native(name,n,fn)
  local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end}
  define(value,'length',{value=n,configurable=true});define(value,'name',{value=name,configurable=true});return value
 end
 local function method(target,name,n,fn)define(target,name,{value=native(name,n,fn),writable=true,configurable=true})end
 local function global(name,value)globals[name]=value;vm.Global.Bindings[name]={Value=value}end
 local function list(value,keysOnly)
  requireObject(value);local n=VM.number(vm.Get(value,'length'));n=if n~=n or n<=0 then 0 elseif n==math.huge then 9007199254740991 else math.floor(n)
  if n>16384 then VM.throw(VM.error('RangeError','Reflection argument/key budget exceeded'))end
  local items={};for i=0,n-1 do vm.Step();local item=vm.Get(value,tostring(i));if keysOnly and type(item)~='string'and not(type(item)=='table'and item.Kind=='symbol')then fail('Proxy ownKeys must contain only strings and symbols')end;items[i+1]=item end;return items
 end
 local function state(value)
  check();local s=states[value];if not s or s.Revoked then fail('Cannot perform operation on a revoked Proxy')end;vm.Step();return s
 end
 local function trap(value,name)
  local original=state(value);local s={Target=original.Target,Handler=original.Handler};local fn=vm.Get(s.Handler,name)
  if fn==U or fn==N then return s,nil end
  if not VM.callable(fn)then fail('Proxy '..name..' trap is not callable')end;return s,fn
 end
 local function invoke(s,fn,args)return vm:Call(fn,args,s.Handler)end
 function handlers.GetPrototype(value)
  local s,fn=trap(value,'getPrototypeOf');if not fn then return model.GetPrototype(s.Target)end
  local proto=invoke(s,fn,{s.Target});if proto~=N and not object(proto)then fail('Proxy getPrototypeOf must return an object or null')end
  if not model.IsExtensible(s.Target)and proto~=model.GetPrototype(s.Target)then fail('Proxy getPrototypeOf violates non-extensible target')end;return proto
 end
 function handlers.SetPrototype(value,proto)
  local s,fn=trap(value,'setPrototypeOf');if not fn then return model.SetPrototypeInternal(s.Target,proto)end
  if not VM.truth(invoke(s,fn,{s.Target,proto}))then return false end
  if not model.IsExtensible(s.Target)and proto~=model.GetPrototype(s.Target)then fail('Proxy setPrototypeOf violates non-extensible target')end;return true
 end
 function handlers.IsExtensible(value)
  local s,fn=trap(value,'isExtensible');if not fn then return model.IsExtensible(s.Target)end
  local result=VM.truth(invoke(s,fn,{s.Target}));if result~=model.IsExtensible(s.Target)then fail('Proxy isExtensible disagrees with target')end;return result
 end
 function handlers.PreventExtensions(value)
  local s,fn=trap(value,'preventExtensions');if not fn then return model.PreventExtensionsInternal(s.Target)end
  local result=VM.truth(invoke(s,fn,{s.Target}));if result and model.IsExtensible(s.Target)then fail('Proxy preventExtensions left target extensible')end;return result
 end
 function handlers.Own(value,key)
  local s,fn=trap(value,'getOwnPropertyDescriptor');if not fn then return model.Own(s.Target,key)end
  local result=invoke(s,fn,{s.Target,key});if result~=U and not object(result)then fail('Proxy descriptor must be an object or undefined')end
  local target=model.Own(s.Target,key)
  if result==U then
   if not target then return nil end
   if not target.Configurable or not model.IsExtensible(s.Target)then fail('Proxy descriptor cannot hide target property')end;return nil
  end
  local extensible=model.IsExtensible(s.Target);local d=model.CompleteDescriptor(model.ToDescriptor(result))
  if not model.CompatibleDescriptor(extensible,d,target)then fail('Proxy descriptor is incompatible with target')end
  if not d.Configurable then
   if not target or target.Configurable then fail('Proxy cannot invent a non-configurable property')end
   if not d.Accessor and not d.Writable and target.Writable then fail('Proxy cannot report an unfrozen target property as frozen')end
  end
  return d
 end
 function handlers.Define(value,key,d)
  local s,fn=trap(value,'defineProperty');if not fn then return model.DefineOwn(s.Target,key,d)end
  if not VM.truth(invoke(s,fn,{s.Target,key,descriptor(d)}))then return false end
  local target=model.Own(s.Target,key);local extensible=model.IsExtensible(s.Target);local settingNonConfig=d.Configurable==false
  if not target then if not extensible or settingNonConfig then fail('Proxy defineProperty cannot create target property')end
  else
   if not model.CompatibleDescriptor(extensible,d,target)or settingNonConfig and target.Configurable then fail('Proxy defineProperty is incompatible with target')end
   if not target.Accessor and not target.Configurable and target.Writable and d.Writable==false then fail('Proxy defineProperty must freeze target property first')end
  end;return true
 end
 function handlers.Has(value,key)
  local s,fn=trap(value,'has');if not fn then return model.Has(s.Target,key)end
  local result=VM.truth(invoke(s,fn,{s.Target,key}))
  if not result then local d=model.Own(s.Target,key);if d and(not d.Configurable or not model.IsExtensible(s.Target))then fail('Proxy has cannot hide target property')end end;return result
 end
 function handlers.Get(value,key,receiver)
  local s,fn=trap(value,'get');if not fn then return model.Get(s.Target,key,receiver)end
  local result=invoke(s,fn,{s.Target,key,receiver});local d=model.Own(s.Target,key)
  if d and not d.Configurable then
   if not d.Accessor and not d.Writable and not model.SameValue(result,d.Value)then fail('Proxy get must preserve read-only target value')end
   if d.Accessor and(d.Get==U or d.Get==nil)and result~=U then fail('Proxy get must preserve an absent getter')end
  end;return result
 end
 function handlers.Set(value,key,item,receiver)
  local s,fn=trap(value,'set');if not fn then return model.Set(s.Target,key,item,false,receiver)end
  if not VM.truth(invoke(s,fn,{s.Target,key,item,receiver}))then return false end
  local d=model.Own(s.Target,key)
  if d and not d.Configurable then
   if not d.Accessor and not d.Writable and not model.SameValue(item,d.Value)then fail('Proxy set must preserve read-only target value')end
   if d.Accessor and(d.Set==U or d.Set==nil)then fail('Proxy set cannot supply an absent setter')end
  end;return true
 end
 function handlers.Delete(value,key)
  local s,fn=trap(value,'deleteProperty');if not fn then return model.Delete(s.Target,key,false)end
  if not VM.truth(invoke(s,fn,{s.Target,key}))then return false end
  local d=model.Own(s.Target,key);if d and(not d.Configurable or not model.IsExtensible(s.Target))then fail('Proxy deleteProperty cannot hide target property')end;return true
 end
 function handlers.OwnKeys(value)
  local s,fn=trap(value,'ownKeys');if not fn then return model.OwnKeys(s.Target,false)end
  local keys=list(invoke(s,fn,{s.Target}),true);local seen={}
  for _,key in keys do if seen[key]then fail('Proxy ownKeys returned duplicate keys')end;seen[key]=true end
  local extensible=model.IsExtensible(s.Target);local targetKeys=model.OwnKeys(s.Target,false);local targetSet={}
  for _,key in targetKeys do vm.Step();targetSet[key]=true;local d=model.Own(s.Target,key)
   if d and not d.Configurable and not seen[key]then fail('Proxy ownKeys omitted a non-configurable key')end
   if not extensible and not seen[key]then fail('Proxy ownKeys omitted a non-extensible target key')end
  end
  if not extensible then for _,key in keys do if not targetSet[key]then fail('Proxy ownKeys added a non-extensible target key')end end end
  return keys
 end
 local function proxy(target,handler)
  requireObject(target);requireObject(handler)
  if count>=16384 then local live=0;for _ in states do live+=1 end;count=live end
  if count>=16384 then VM.throw(VM.error('RangeError','JavaScript Proxy budget exceeded'))end;count+=1
  local s={Target=target,Handler=handler,Revoked=false};local value=vm.Object({});value.Values=nil;value.Kind=if VM.callable(target)then 'native-function'else 'proxy';value.ProxyState=s
  states[value]=s;model.Exotic[value]=handlers
  if VM.callable(target)then value.Call=function(args,receiver)
   local current,fn=trap(value,'apply');return if fn then invoke(current,fn,{current.Target,if receiver==nil then U else receiver,vm.Array(table.clone(args))})else vm:Call(current.Target,args,receiver)
  end end
  if vm.IsConstructor(target)then value.Construct=function(args,newTarget)
   local current,fn=trap(value,'construct');if not fn then return vm:Construct(current.Target,args,newTarget or value)end
   local result=invoke(current,fn,{current.Target,vm.Array(table.clone(args)),newTarget or value});if not object(result)then fail('Proxy construct must return an object')end;return result
  end end
  return value,s
 end
 local constructor=native('Proxy',2,function()fail('Proxy requires new')end)
 constructor.Construct=function(args)local value=proxy(arg(args,1),arg(args,2));return value end
 method(constructor,'revocable',2,function(args)
  local value,s=proxy(arg(args,1),arg(args,2));local revoke=native('',0,function()if not s.Revoked then s.Revoked=true;s.Target=nil;s.Handler=nil end;return U end)
  return vm.Object({proxy=value,revoke=revoke},nil,{'proxy','revoke'})
 end)
 global('Proxy',constructor)
 local reflect=vm.Object({});global('Reflect',reflect)
 if vm.SymbolToStringTag then define(reflect,vm.SymbolToStringTag,{value='Reflect',configurable=true})end
 method(reflect,'apply',3,function(args)local target=arg(args,1);if not VM.callable(target)then fail('Reflect.apply target must be callable')end;return vm:Call(target,list(arg(args,3),false),arg(args,2))end)
 method(reflect,'construct',2,function(args)
  local target=arg(args,1);local newTarget=if args[3]==nil then target else args[3]
  if not vm.IsConstructor(target)or not vm.IsConstructor(newTarget)then fail('Reflect.construct requires constructors')end
  return vm:Construct(target,list(arg(args,2),false),newTarget)
 end)
 method(reflect,'defineProperty',3,function(args)local target=requireObject(arg(args,1));local key=model.Key(arg(args,2));local d=model.ToDescriptor(arg(args,3));return model.DefineOwn(target,key,d)end)
 method(reflect,'deleteProperty',2,function(args)return model.Delete(requireObject(arg(args,1)),model.Key(arg(args,2)),false)end)
 method(reflect,'get',2,function(args)local target=requireObject(arg(args,1));local key=model.Key(arg(args,2));local receiver=if args[3]==nil then target else args[3];return model.Get(target,key,receiver)end)
 method(reflect,'getOwnPropertyDescriptor',2,function(args)return model.Descriptor(requireObject(arg(args,1)),model.Key(arg(args,2)))end)
 method(reflect,'getPrototypeOf',1,function(args)return model.GetPrototype(requireObject(arg(args,1)))end)
 method(reflect,'has',2,function(args)return model.Has(requireObject(arg(args,1)),model.Key(arg(args,2)))end)
 method(reflect,'isExtensible',1,function(args)return model.IsExtensible(requireObject(arg(args,1)))end)
 method(reflect,'ownKeys',1,function(args)return vm.Array(model.OwnKeys(requireObject(arg(args,1)),false))end)
 method(reflect,'preventExtensions',1,function(args)return model.PreventExtensionsInternal(requireObject(arg(args,1)))end)
 method(reflect,'set',3,function(args)local target=requireObject(arg(args,1));local key=model.Key(arg(args,2));local receiver=if args[4]==nil then target else args[4];return model.Set(target,key,arg(args,3),false,receiver)end)
 method(reflect,'setPrototypeOf',2,function(args)local target=requireObject(arg(args,1));local proto=arg(args,2);if proto~=N and not object(proto)then fail('Reflect.setPrototypeOf prototype must be object or null')end;return model.SetPrototypeInternal(target,proto)end)
 vm.IsArray=function(value)
  local seen={};while type(value)=='table'and value.ProxyState do
   if seen[value]then fail('Cyclic Proxy target')end;seen[value]=true
   if value.ProxyState.Revoked then fail('Cannot perform operation on a revoked Proxy')end
   value=value.ProxyState.Target
  end
  return type(value)=='table'and value.Kind=='array'
 end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  for value,s in states do model.Exotic[value]=nil;s.Target=nil;s.Handler=nil;s.Revoked=true end;table.clear(states)
 end
 return api
end
return Reflection
