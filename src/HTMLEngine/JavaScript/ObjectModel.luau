--!strict
-- A realm's property operations. Host wrappers keep their own storage protocol;
-- ordinary objects share descriptors, ordered keys and prototype traversal.
local ObjectModel={}
local BigInt=require(script.Parent.BigInt)
function ObjectModel.install(vm: any,VM: any): any
 local U,N=VM.Undefined,VM.Null
 local model={Exotic=setmetatable({},{__mode='k'})}
 local function exotic(value)
  if type(value)~='table'then return nil end
  local owner=value.VMOwner
  return model.Exotic[value]or(if owner and owner~=vm and owner.ObjectModel then owner.ObjectModel.Exotic[value]else nil)
 end
 model.ExoticFor=exotic
 local function object(value)return type(value)=='function'or(type(value)=='table'and value~=U and value~=N and value.Kind~='symbol'and value.Kind~='bigint')end
 local function fail(message)VM.throw(VM.error('TypeError',message))end
 local function keyOf(key)
  return if vm.PropertyKey then vm.PropertyKey(key)elseif type(key)=='table'and key.Kind=='symbol'then key else VM.string(key)
 end
 local function index(key)
  if type(key)~='string'then return nil end
  local n=tonumber(key)
  return if n and n>=0 and n<4294967295 and n==math.floor(n)and tostring(n)==key then n else nil
 end
 local function ordinary(value)
  return type(value)=='table'and not exotic(value)and(value.Values~=nil or value.Kind=='array'or value.Kind=='function'or value.Kind=='native-function')
 end
 model.Ordinary=ordinary;model.Key=keyOf;model.Index=index;model.IsObject=object
 local function storage(value)
  if value.Kind=='array'then value.Properties=value.Properties or {};return value.Properties end
  value.Values=value.Values or {};return value.Values
 end
 local function record(value,key)
  value.KeyOrder=value.KeyOrder or {};value.OrderedKeys=value.OrderedKeys or {}
  if not value.OrderedKeys[key]then value.OrderedKeys[key]=true;table.insert(value.KeyOrder,key)end
 end
 local function raw(value,key)
  if value.Mapped and value.Mapped[key]then return value.Mapped[key].Value end
  if value.Kind=='array'then
   if key=='length'then return value.Length or #value.Items end
   local at=index(key);if at then return value.Items[at+1]end
  end
  return storage(value)[key]
 end
 local function rawSet(value,key,item)
  if value.Mapped and value.Mapped[key]then value.Mapped[key].Value=item end
  record(value,key)
  if value.Kind=='array'then
   if key=='length'then value.Length=item;return end
   local at=index(key);if at then value.Items[at+1]=item;value.Length=math.max(value.Length or #value.Items,at+1);return end
  end
  storage(value)[key]=item
 end
 local function own(value,key)
  key=keyOf(key)
  local handler=exotic(value);if handler then return handler.Own(value,key)end
  if not ordinary(value)then
   if type(value)=='string'then
    if key=='length'then return {Value=vm.StringLength(value),Writable=false,Enumerable=false,Configurable=false}end
    local at=index(key);if at and at<vm.StringLength(value)then return {Value=vm.StringIndex(value,at),Writable=false,Enumerable=true,Configurable=false}end
   elseif type(value)=='table'and value.GetOwnPropertyDescriptor then return value.GetOwnPropertyDescriptor(key)
   elseif type(value)=='table'and value.HasOwn and value.HasOwn(key)then return {Value=value.Get(key),Writable=true,Enumerable=true,Configurable=true}
   elseif type(value)=='table'and value.Keys then for _,item in value.Keys()do if item==key then return {Value=value.Get(key),Writable=true,Enumerable=true,Configurable=true}end end end
   return nil
  end
  if value.Kind=='function'and key=='prototype'and not value.Arrow and not value.Async and not value.Method and not value.PrototypeObject then vm.Get(value,key)end
  local descriptor=value.Descriptors and value.Descriptors[key]
  if descriptor then
   if not descriptor.Accessor then descriptor.Value=raw(value,key)end
   return descriptor
  end
  local item=raw(value,key)
  if item==nil then return nil end
  return {Value=item,Writable=true,Enumerable=key~='length'or value.Kind~='array',Configurable=key~='length'or value.Kind~='array'}
 end
 model.Own=own
 function model.GetPrototype(value)
  local handler=exotic(value);if handler then return handler.GetPrototype(value)end
  if type(value)=='function'then return vm.Prototypes.Function or N end
  if type(value)=='string'then return vm.Prototypes.String or N elseif type(value)=='number'then return vm.Prototypes.Number or N elseif type(value)=='boolean'then return vm.Prototypes.Boolean or N end
  if type(value)~='table'or value==U or value==N then fail('Object required')end
  if value.Kind=='symbol'then return vm.Prototypes.Symbol or N end
  if value.Kind=='bigint'then return vm.Prototypes.BigInt or N end
  if value.GetPrototype then return value.GetPrototype()end
  if value.Kind=='error'and value.Prototype==nil then return vm.Prototypes[value.ErrorName]or vm.Prototypes.Error or N end
  return value.Prototype or N
 end
 function model.Get(value,key,receiver)
  key=keyOf(key);if receiver==nil then receiver=value end
  local visited={}
  while value~=N and value~=U and value~=nil do
   vm.Step();if visited[value]then fail('Cyclic prototype')end;visited[value]=true
   local handler=exotic(value);if handler then return handler.Get(value,key,receiver)end
   local descriptor=own(value,key)
   if descriptor then return if descriptor.Accessor then(if descriptor.Get==U or descriptor.Get==nil then U else vm:Call(descriptor.Get,{},receiver))else descriptor.Value end
   if type(value)=='table'and value.Get then
    local result=value.Get(key,receiver);if result~=U and result~=nil then return result end
   end
   value=model.GetPrototype(value)
  end
  return U
 end
 function model.HasOwn(value,key)return own(value,keyOf(key))~=nil end
 function model.Has(value,key)
  key=keyOf(key);local visited={}
  while value~=nil and value~=N and value~=U do
   vm.Step();if visited[value]then fail('Cyclic prototype')end;visited[value]=true
   local handler=exotic(value);if handler then return handler.Has(value,key)end
   if model.HasOwn(value,key)then return true end
   if type(value)=='table'and value.Has and value.Has(key)then return true end
   value=model.GetPrototype(value)
  end
  return false
 end
 function model.OwnKeys(value,enumerable)
  local handler=exotic(value);if handler then
   local keys=handler.OwnKeys(value);if not enumerable then return keys end
   local out={};for _,key in keys do vm.Step();local d=own(value,key);if d and d.Enumerable then table.insert(out,key)end end;return out
  end
  if type(value)=='string'then local out={};for i=0,vm.StringLength(value)-1 do table.insert(out,tostring(i))end;if not enumerable then table.insert(out,'length')end;return out end
  if not ordinary(value)then return if type(value)=='table'and value.Keys then value.Keys(enumerable)else {}end
  local seen,indices,strings,symbols={},{},{},{}
  local function append(key)
   if seen[key]then return end;seen[key]=true
   local descriptor=own(value,key);if not descriptor or(enumerable and not descriptor.Enumerable)then return end
   local at=index(key)
   if at then table.insert(indices,{Key=key,Index=at})elseif type(key)=='string'then table.insert(strings,key)else table.insert(symbols,key)end
  end
  -- Factory-created keys are recorded once; keys of legacy host constructors
  -- are stable sorted on first exposure, then follow insertion order.
  for _,key in value.KeyOrder or {}do append(key)end
  local remaining={};for key in storage(value)do if not seen[key]then table.insert(remaining,key)end end
  table.sort(remaining,function(a,b)return tostring(a)<tostring(b)end)
  for _,key in remaining do record(value,key);append(key)end
  if value.Kind=='array'then for i in value.Items do append(tostring(i-1))end;append('length')end
  if value.Descriptors then for key in value.Descriptors do append(key)end end
  table.sort(indices,function(a,b)return a.Index<b.Index end)
  local out={};for _,item in indices do table.insert(out,item.Key)end;for _,key in strings do table.insert(out,key)end;for _,key in symbols do table.insert(out,key)end
  return out
 end
 function model.Delete(value,key,strict)
  key=keyOf(key)
  local handler=exotic(value);if handler then local result=handler.Delete(value,key);if not result and strict then fail('Cannot delete property')end;return result end
  if not ordinary(value)then return if type(value)=='table'and value.Delete then value.Delete(key)else not model.HasOwn(value,key)end
  local descriptor=own(value,key);if not descriptor then return true end
  if not descriptor.Configurable then if strict then fail('Cannot delete non-configurable property')end;return false end
  if value.Kind=='array'and index(key)then value.Items[index(key)+1]=nil else storage(value)[key]=nil end
  if value.Descriptors then value.Descriptors[key]=nil end
  if value.Mapped then value.Mapped[key]=nil end
  if value.OrderedKeys then value.OrderedKeys[key]=nil end
  if value.KeyOrder then local at=table.find(value.KeyOrder,key);if at then table.remove(value.KeyOrder,at)end end
  return true
 end
 local function same(a,b)return BigInt.Equal(a,b)or a==b and not(type(a)=='number'and a==0 and 1/a~=1/b)or(type(a)=='number'and type(b)=='number'and a~=a and b~=b)end
 model.SameValue=same
 local function accessor(d)return d.Accessor==true or d.Get~=nil or d.Set~=nil end
 local function data(d)return d.Value~=nil or d.Writable~=nil end
 local function complete(d)
  local out=table.clone(d);out.Enumerable=out.Enumerable==true;out.Configurable=out.Configurable==true
  if accessor(out)then out.Accessor=true;out.Get=out.Get or U;out.Set=out.Set or U;out.Value=nil;out.Writable=nil
  else out.Value=if out.Value==nil then U else out.Value;out.Writable=out.Writable==true;out.Accessor=nil end;return out
 end
 model.CompleteDescriptor=complete
 function model.ToDescriptor(value)
  if not object(value)then fail('Property descriptor must be an object')end
  local out={}
  for _,field in {'enumerable','configurable','value','writable','get','set'}do
   if model.Has(value,field)then local item=vm.Get(value,field);local name=field:sub(1,1):upper()..field:sub(2)
    if field=='get'or field=='set'then if item~=U and not VM.callable(item)then fail('Accessor must be callable or undefined')end;out.Accessor=true end
    out[name]=if field=='enumerable'or field=='configurable'or field=='writable'then VM.truth(item)else item
   end
  end
  if accessor(out)and data(out)then fail('Invalid mixed property descriptor')end;return out
 end
 function model.FromDescriptor(d)
  if not d then return U end;local values,order={},{}
  for _,field in {'Value','Writable','Get','Set','Enumerable','Configurable'}do if d[field]~=nil then local name=field:lower();values[name]=d[field];table.insert(order,name)end end
  return vm.Object(values,nil,order)
 end
 local function compatible(extensible,d,old)
  if not old then return extensible end
  if not old.Configurable then if d.Configurable==true or d.Enumerable~=nil and d.Enumerable~=old.Enumerable then return false end end
  if not accessor(d)and not data(d)then return true end
  if accessor(d)~=accessor(old)then return old.Configurable==true end
  if not old.Configurable then
   if accessor(old)then if d.Get~=nil and not same(d.Get,old.Get or U)or d.Set~=nil and not same(d.Set,old.Set or U)then return false end
   elseif not old.Writable then if d.Writable==true or d.Value~=nil and not same(d.Value,old.Value)then return false end end
  end;return true
 end
 model.CompatibleDescriptor=compatible
 function model.IsExtensible(value)
  local handler=exotic(value);if handler then return handler.IsExtensible(value)end
  if type(value)=='table'and value.IsExtensible then return value.IsExtensible()end
  return type(value)~='table'or value.Extensible~=false
 end
 function model.PreventExtensionsInternal(value)
  local handler=exotic(value);if handler then return handler.PreventExtensions(value)end
  if type(value)=='table'and value.PreventExtensions then return value.PreventExtensions()~=false end
  if type(value)=='table'then value.Extensible=false end;return true
 end
 function model.PreventExtensions(value)if not model.PreventExtensionsInternal(value)then fail('Cannot prevent extensions')end;return value end
 function model.DefineOwn(value,key,d)
  key=keyOf(key);local handler=exotic(value);if handler then return handler.Define(value,key,d)end
  if not ordinary(value)then
   if type(value)=='table'and value.DefineProperty then return value.DefineProperty(key,model.FromDescriptor(d),false)~=false end
   return false
  end
  if value.Kind=='array'and key=='length'and d.Value~=nil then
   -- ArraySetLength observes two conversions, including conversion side effects.
   local first=VM.number(d.Value);local length=if first~=first or math.abs(first)==math.huge then 0 else(if first<0 then math.ceil(first)else math.floor(first))%4294967296
   local second=VM.number(d.Value)
   if length~=second or length>16384 then VM.throw(VM.error('RangeError','Invalid or over-budget array length'))end
   d=table.clone(d);d.Value=length
  end
  local old=own(value,key);if not compatible(model.IsExtensible(value),d,old)then return false end
  local nextDescriptor=if old then table.clone(old)else complete(d)
  if old and(accessor(d)or data(d))and accessor(d)~=accessor(old)then
   nextDescriptor=if accessor(d)then {Accessor=true,Get=U,Set=U,Enumerable=old.Enumerable,Configurable=old.Configurable}else {Value=U,Writable=false,Enumerable=old.Enumerable,Configurable=old.Configurable}
  end
  for field,item in d do if field~='Accessor'then nextDescriptor[field]=item end end
  if accessor(nextDescriptor)then nextDescriptor.Accessor=true end
  if value.Kind=='array'then
   if key=='length'then
    if accessor(d)then return false end
    if d.Value~=nil then
     local length=VM.number(d.Value);if length~=math.floor(length)or length<0 or length>16384 then VM.throw(VM.error('RangeError','Invalid or over-budget array length'))end
     local oldLength=value.Length or #value.Items
     if length<oldLength and old and not old.Writable then return false end
     local writable=nextDescriptor.Writable;nextDescriptor.Value=length;nextDescriptor.Writable=true
     value.Descriptors=value.Descriptors or {};value.Descriptors.length=nextDescriptor;value.Length=length
     for i=oldLength,length+1,-1 do if not model.Delete(value,tostring(i-1),false)then value.Length=i;nextDescriptor.Value=i;nextDescriptor.Writable=writable;return false end end
     nextDescriptor.Writable=writable
    end
   elseif index(key)then
    if index(key)>=16384 then VM.throw(VM.error('RangeError','JavaScript array budget exceeded'))end
    local ld=own(value,'length');if index(key)>=(value.Length or #value.Items)and not ld.Writable then return false end
   end
  end
  if value.Mapped and value.Mapped[key]and nextDescriptor.Accessor then value.Mapped[key]=nil end
  value.Descriptors=value.Descriptors or {};value.Descriptors[key]=nextDescriptor;record(value,key);rawSet(value,key,if nextDescriptor.Accessor then U else nextDescriptor.Value)
  if value.Mapped and not nextDescriptor.Writable then value.Mapped[key]=nil end
  return true
 end
 function model.Define(value,key,descriptor)
  local d=model.ToDescriptor(descriptor);if not model.DefineOwn(value,key,d)then fail('Cannot define property '..VM.string(key))end;return value
 end
 local function setInternal(value,key,item,receiver,visited)
  vm.Step();if visited[value]then fail('Cyclic prototype')end;visited[value]=true
  local handler=exotic(value);if handler then return handler.Set(value,key,item,receiver)end
  if not ordinary(value)and type(value)=='table'and value.Set and receiver==value then local result=value.Set(key,item,false);return result~=false end
  local d=own(value,key)
  if not d then local parent=model.GetPrototype(value);if parent~=N then return setInternal(parent,key,item,receiver,visited)end;d={Value=U,Writable=true,Enumerable=true,Configurable=true}end
  if d.Accessor then if d.Set==nil or d.Set==U then return false end;vm:Call(d.Set,{item},receiver);return true end
  if not d.Writable or not object(receiver)then return false end
  local existing=own(receiver,key)
  if existing then if existing.Accessor or not existing.Writable then return false end;return model.DefineOwn(receiver,key,{Value=item})end
  return model.DefineOwn(receiver,key,{Value=item,Writable=true,Enumerable=true,Configurable=true})
 end
 function model.Set(value,key,item,strict,receiver)
  key=keyOf(key);if receiver==nil then receiver=value end
  -- Legacy DOM/typed host setters own strict-mode rejection behavior.
  if not ordinary(value)and not exotic(value)and type(value)=='table'and value.Set and receiver==value then
   local result=value.Set(key,item,strict);return result~=false
  end
  local success=setInternal(value,key,item,receiver,{})
  if not success and strict then fail('Property is not writable')end;return success
 end
 function model.SetPrototypeInternal(value,prototype)
  local handler=exotic(value);if handler then return handler.SetPrototype(value,prototype)end
  if not ordinary(value)then if type(value)=='table'and value.SetPrototype then return value.SetPrototype(prototype)~=false end;return false end
  if value.Prototype==prototype then return true end;if not model.IsExtensible(value)then return false end
  local cursor,seen=prototype,{}
  while cursor~=N and cursor~=nil do if cursor==value or seen[cursor]then return false end;seen[cursor]=true
   local handler=exotic(cursor);if handler and not handler.OrdinaryGetPrototype then break end;cursor=model.GetPrototype(cursor)
  end
  value.Prototype=prototype;return true
 end
 function model.SetPrototype(value,prototype)
  if prototype~=N and not object(prototype)then fail('Prototype must be an object or null')end
  if not model.SetPrototypeInternal(value,prototype)then fail('Cannot set prototype')end;return value
 end
 function model.Descriptor(value,key)return model.FromDescriptor(own(value,key))end
 model.Record=record
 return model
end
return ObjectModel
