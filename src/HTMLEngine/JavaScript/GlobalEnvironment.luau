--!strict
-- The global object record and declarative record are distinct. A lexical
-- binding can shadow an ordinary window property without changing that property.
local GlobalEnvironment={}
function GlobalEnvironment.install(vm: any,globals: any,initial: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local model=vm.ObjectModel
 local properties=vm.Object({},N);local linked={};local api={Properties=properties}
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function link(name)
  local descriptor=model.Own(properties,name)
  local slot={GlobalObject=true,Value=if descriptor and not descriptor.Accessor then descriptor.Value else U}
  slot.Get=function()return vm.Get(properties,name)end
  slot.Set=function(value,strict)local result=vm.Set(properties,name,value,strict);if result then slot.Value=value end;return result end
  linked[name]=slot;vm.Global.Bindings[name]=slot;return slot
 end
 local function sync(name)
  local slot=vm.Global.Bindings[name]
  if name=='this'or not slot or slot.Lexical or slot==linked[name]then return end
  local descriptor
  if slot.Get or slot.Set then
   descriptor={Accessor=true,Get=if slot.Get then function()return slot.Get()end elseif slot.Value~=nil then function()return slot.Value end else U,
    Set=if slot.Set then function(args)return slot.Set(args[1],true)end else U,
    Enumerable=initial[name]==true,Configurable=not slot.Const}
  else descriptor={Value=if slot.Value==nil then U else slot.Value,Writable=not slot.Const,
   Enumerable=initial[name]==true or slot.Declared==true,Configurable=not slot.Const and not slot.Declared}end
  if model.Own(properties,name)then model.Delete(properties,name,false)end
  if not model.DefineOwn(properties,name,descriptor)then fail('TypeError','Cannot install global property '..tostring(name))end
  link(name)
 end
 function api:Sync()
  if properties.Prototype==N and not self.PrototypeSet then properties.Prototype=vm.Prototypes.Object or N end
  local names={};for name in vm.Global.Bindings do table.insert(names,name)end
  for _,name in names do sync(name)end
 end
 function api:Read(name)sync(name);return vm.Get(properties,name)end
 function api:Write(name,value,strict)
  sync(name);local result=vm.Set(properties,name,value,strict)
  if result and not(vm.Global.Bindings[name]and vm.Global.Bindings[name].Lexical)then link(name)end
  return result
 end
 function api:Own(name)sync(name);return model.Own(properties,name)end
 function api:Keys(enumerable)self:Sync();return model.OwnKeys(properties,enumerable)end
 function api:Has(name)sync(name);return model.Has(properties,name)end
 function api:Define(name,descriptor,strict)
  sync(name);local result=model.DefineOwn(properties,name,model.ToDescriptor(descriptor))
  if not result and strict~=false then fail('TypeError','Cannot define global property '..tostring(name))end
  if result and not(vm.Global.Bindings[name]and vm.Global.Bindings[name].Lexical)then link(name)end
  return result
 end
 function api:Delete(name,strict)
  sync(name);local result=model.Delete(properties,name,strict)
  if result then
   if vm.Global.Bindings[name]==linked[name]then vm.Global.Bindings[name]=nil end
   linked[name]=nil;globals[name]=nil
  end
  return result
 end
 function api:Binding(name)
  local slot=vm.Global.Bindings[name]
  if name=='this'or slot and slot.Lexical then return slot end
  sync(name)
  if model.Has(properties,name)then return if linked[name]then linked[name]else {GlobalObject=true,
   Get=function()return vm.Get(properties,name)end,Set=function(value,strict)return vm.Set(properties,name,value,strict)end}end
  return nil
 end
 function api:DeclareVar(name,deletable)
  if vm.Global.Bindings[name]and vm.Global.Bindings[name].Lexical then fail('SyntaxError','Conflicting global declaration '..name)end
  sync(name)
  if not model.HasOwn(properties,name)then
   if not model.DefineOwn(properties,name,{Value=U,Writable=true,Enumerable=true,Configurable=deletable==true})then fail('TypeError','Cannot declare global variable '..name)end
  end
  return link(name)
 end
 function api:DeclareFunction(name,value,deletable)
  sync(name);local old=model.Own(properties,name)
  local descriptor=if not old or old.Configurable then {Value=value,Writable=true,Enumerable=true,Configurable=deletable==true}else {Value=value}
  if not model.DefineOwn(properties,name,descriptor)then fail('TypeError','Cannot declare global function '..name)end
  return link(name)
 end
 function api:Check(ast,ignoreLexical)
  self:Sync();local lexical,vars,functions={},{},{}
  local function collect(node)
   if node.Kind=='function'or node.Kind=='function-declaration'or node.Kind=='class'or node.Kind=='class-declaration'then return end
   if node.Kind=='declare'and node.Mode=='var'then for _,entry in node.Entries do for _,name in entry.Names do vars[name]=true end end end
   for _,value in node do if type(value)=='table'then
    if value.Kind then collect(value)else for _,child in value do if type(child)=='table'then
     if child.Kind then collect(child)elseif child.Items then for _,item in child.Items do collect(item)end end
    end end end
   end end
  end
  collect(ast)
  for _,item in ast.Items do
   if not ignoreLexical and item.Kind=='declare'and item.Mode~='var'then for _,entry in item.Entries do for _,name in entry.Names do lexical[name]=true end end
   elseif not ignoreLexical and item.Kind=='class-declaration'then lexical[item.Name]=true
   elseif item.Kind=='function-declaration'then functions[item.Name]=true;vars[item.Name]=true end
  end
  for name in lexical do
   local slot=vm.Global.Bindings[name];local own=model.Own(properties,name)
   if slot and slot.Lexical or vars[name]or own and not own.Configurable then fail('SyntaxError','Conflicting global lexical declaration '..name)end
  end
  for name in vars do
   if vm.Global.Bindings[name]and vm.Global.Bindings[name].Lexical then fail('SyntaxError','Conflicting global variable '..name)end
   if not model.HasOwn(properties,name)and not model.IsExtensible(properties)then fail('TypeError','Global object is not extensible')end
  end
  for name in functions do
   local own=model.Own(properties,name)
   if own and not own.Configurable and(own.Accessor or not own.Writable or not own.Enumerable)then fail('TypeError','Cannot declare global function '..name)end
  end
 end
 function api:Destroy()table.clear(linked);table.clear(properties.Values);table.clear(properties.Descriptors or {});table.clear(properties.KeyOrder or {});table.clear(properties.OrderedKeys or {})end
 vm.GlobalEnvironment=api;return api
end
return GlobalEnvironment
