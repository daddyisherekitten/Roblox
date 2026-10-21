--!strict
-- Class state stays separate from public descriptors and private brands cannot
-- be copied by reflection, Object.assign, proxies or structured cloning.
local Classes={}
function Classes.install(vm: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null
 local api={Alive=true}
 local classes=setmetatable({},{__mode='kv'})
 local nativeBrands=setmetatable({},{__mode='k'})
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function define(target,key,value,writable,enumerable,configurable)
  vm.DefineProperty(target,key,vm.Object({value=value,writable=writable,enumerable=enumerable,configurable=configurable},VM.Null))
 end
 local function context(scope,key)
  while scope do if scope[key]~=nil then return scope[key]end;scope=scope.Parent end
  fail('ReferenceError','Missing class execution context')
 end
 local function thisValue(scope)
  while scope do local slot=scope.Bindings.this;if slot then return if slot.Get then slot.Get()else slot.Value end;scope=scope.Parent end
  fail('ReferenceError','Missing this binding')
 end
 local function token(scope,key)
  while scope do if scope.PrivateNames and scope.PrivateNames[key]then return scope.PrivateNames[key]end;scope=scope.Parent end
  fail('SyntaxError','Undeclared private name #'..key)
 end
 local function privateSlot(scope,receiver,key)
  if not vm.ObjectModel.IsObject(receiver)then fail('TypeError','Private member receiver is not an object')end
  local slot=token(scope,key).Records[receiver]
  if not slot then fail('TypeError','Receiver does not have private member #'..key)end
  return slot
 end
 local function brand(receiver,t,slot)
  if t.Records[receiver]then fail('TypeError','Private brand is already initialized')end
  -- Instance-owned slots keep live private values reachable without making
  -- the class's lookup retain an unreachable #self=this cycle in Luau.
  local owned
  if type(receiver)=='table'then receiver.ClassPrivateSlots=receiver.ClassPrivateSlots or {};owned=receiver.ClassPrivateSlots
  else nativeBrands[receiver]=nativeBrands[receiver]or {};owned=nativeBrands[receiver]end
  owned[t]=slot;t.Records[receiver]=slot
 end
 function api:GetPrivate(scope,receiver,key)
  local slot=privateSlot(scope,receiver,key)
  if slot.Accessor then return if slot.Get then vm:Call(slot.Get,{},receiver)else U end
  return slot.Value
 end
 function api:SetPrivate(scope,receiver,key,value)
  local slot=privateSlot(scope,receiver,key)
  if slot.Accessor then if not slot.Set then fail('TypeError','Private accessor has no setter')end;vm:Call(slot.Set,{value},receiver)
  elseif slot.Method then fail('TypeError','Private methods are not writable')
  else slot.Value=value end
 end
 function api:HasPrivate(scope,receiver,key)
  if not vm.ObjectModel.IsObject(receiver)then fail('TypeError','Right operand of private in is not an object')end
  return token(scope,key).Records[receiver]~=nil
 end
 function api:SuperReference(scope,key)
  local receiver=thisValue(scope);local base=vm.GetPrototype(context(scope,'HomeObject'))
  return function()return vm.Get(base,key,receiver)end,
   function(value)if not vm.SetWithReceiver(base,key,value,receiver)then fail('TypeError','Cannot assign super property')end end,receiver
 end
 function api:SuperCall(scope,args)
  local execution=context(scope,'ClassExecution')
  if not execution.Derived then fail('ReferenceError','super() outside derived constructor')end
  local parent=vm.GetPrototype(execution.Constructor)
  local instance=vm:Construct(parent,args,execution.NewTarget)
  if execution.This~=options.Uninitialized then fail('ReferenceError','Super constructor may only be called once')end
  execution.This=instance;execution.Initialize(instance)
  return instance
 end
 function api:Create(ast,outer)
  local scope=options.Env(outer);scope.Strict=true;scope.PrivateNames={}
  if ast.Name then scope.Bindings[ast.Name]={Value=options.Uninitialized,Const=true,Lexical=true}end
  for name in ast.PrivateNames do scope.PrivateNames[name]={Records=setmetatable({},{__mode='kv'})}end
  local base=if ast.Heritage then options.Evaluate(ast.Heritage,scope)else nil
  if base~=nil and base~=N and not vm.IsConstructor(base)then fail('TypeError','Class extends value is not a constructor or null')end
  local parentPrototype=vm.Prototypes.Object
  if base==N then parentPrototype=N
  elseif base~=nil then parentPrototype=vm.Get(base,'prototype');if parentPrototype~=N and not vm.ObjectModel.IsObject(parentPrototype)then fail('TypeError','Superclass prototype is not an object or null')end end
  local proto=vm.Object({},parentPrototype)
  local state={Scope=scope,Base=base,Derived=ast.Heritage~=nil,Fields={},StaticFields={},PrivateMethods={},StaticPrivateMethods={}}
  local constructor={Kind='native-function',Class=true,Values={},SourceText=ast.SourceText,Prototype=if base~=nil and base~=N then base else vm.Prototypes.Function,VMOwner=vm}
  classes[constructor]=state;state.Constructor=constructor
  local function initializationScope(receiver,home)
   local result=options.Env(scope);result.Strict=true;result.Function=true;result.HomeObject=home;result.NewTarget=U;result.ClassInitializer=true
   result.Bindings.this={Value=receiver};return result
  end
  local function initialize(receiver,fields,methods,home)
   for _,entry in methods do
    brand(receiver,entry.Token,table.clone(entry.Slot))
   end
   for _,field in fields do
    local value=if field.Value then options.Evaluate(field.Value,initializationScope(receiver,home))else U
    if field.Value then vm.NamedEvaluation(field.Value,value,if field.Private then '#'..field.Key else field.Key)end
    if field.Private then
     brand(receiver,field.Token,{Value=value})
    else define(receiver,field.Key,value,true,true,true)end
   end
  end
  constructor.Call=function()fail('TypeError','Class constructor cannot be invoked without new')end
  constructor.Construct=function(args,newTarget)
   local receiver=options.Uninitialized
   local execution={Derived=state.Derived,Constructor=constructor,NewTarget=newTarget or constructor,This=receiver,
    Initialize=function(instance)initialize(instance,state.Fields,state.PrivateMethods,proto)end}
   if not state.Derived then
    local prototype=vm.Get(execution.NewTarget,'prototype');if not vm.ObjectModel.IsObject(prototype)then prototype=vm.FunctionRealm(execution.NewTarget).Prototypes.Object end
    receiver=vm.Object({},prototype);execution.This=receiver;execution.Initialize(receiver)
   end
   if not state.Body then
    if state.Derived then api:SuperCall({ClassExecution=execution,Bindings={}},args)end
    return execution.This
   end
   local result=options.ExecuteFunction(state.Body,args,receiver,execution.NewTarget,execution)
   if vm.ObjectModel.IsObject(result)then return result end
   if state.Derived and result~=U then fail('TypeError','Derived constructors may only return an object or undefined')end
   if execution.This==options.Uninitialized then fail('ReferenceError','Must call super constructor before accessing this')end
   return execution.This
  end
  define(constructor,'length',0,false,false,true);define(constructor,'name',ast.Name or '',false,false,true)
  define(constructor,'prototype',proto,false,false,false);define(proto,'constructor',constructor,true,false,true)
  local privateMethods={}
  for _,element in ast.Elements do
   vm.Step()
   local target=if element.Static then constructor else proto
   local key=if element.Kind=='static-block'then nil else vm.PropertyKey(if element.Computed then options.Evaluate(element.Key,scope)else element.Key)
   if element.Kind=='static-block'then table.insert(state.StaticFields,{Block=element.Body})
   elseif element.Kind=='field'then
    table.insert(if element.Static then state.StaticFields else state.Fields,{Key=key,Value=element.Value,Private=element.Private,Token=scope.PrivateNames[key]})
   else
    local method=options.Evaluate(element.Value,scope);method.HomeObject=target;method.Method=true;method.Strict=true
    local methodName=if type(key)=='table'and key.Kind=='symbol'then '['..(key.Description or '')..']'else VM.string(key)
    if element.Private then methodName='#'..methodName end
    if element.Accessor then methodName=element.Accessor..' '..methodName end
    define(method,'name',methodName,false,false,true)
    if element.Constructor then state.Body=method;define(constructor,'length',vm.Get(method,'length'),false,false,true)
    elseif element.Private then
     local t=scope.PrivateNames[key];local entry=privateMethods[t]
     if not entry then entry={Token=t,Slot={}};privateMethods[t]=entry;table.insert(if element.Static then state.StaticPrivateMethods else state.PrivateMethods,entry)end
     if element.Accessor then entry.Slot.Accessor=true;entry.Slot[if element.Accessor=='get'then 'Get'else 'Set']=method
     else entry.Slot.Value=method;entry.Slot.Method=true end
    elseif element.Accessor then vm.DefineProperty(target,key,vm.Object({[element.Accessor]=method,enumerable=false,configurable=true},VM.Null))
    else define(target,key,method,true,false,true)end
   end
  end
  if ast.Name then scope.Bindings[ast.Name].Value=constructor end
  initialize(constructor,{},state.StaticPrivateMethods,constructor)
  for _,field in state.StaticFields do
   if field.Block then options.Execute(field.Block,initializationScope(constructor,constructor))
   else initialize(constructor,{field},{},constructor)end
  end
  return constructor
 end
 function api:Destroy()self.Alive=false;table.clear(classes);table.clear(nativeBrands);table.clear(options)end
 return api
end
return Classes
