--!strict
-- Public stacks and unobservable lexical disposal scopes share captured
-- disposer records. Async disposal uses the host's intrinsic promise adapters.
local ResourceStacks={}
function ResourceStacks.install(vm: any,globals: any,options: any?): any
 if vm.ResourceStacks then if options then vm.ResourceStacks:AttachPromises(options)end;return vm.ResourceStacks end
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true};vm.ResourceStacks=api
 local symbolConstructor=vm.Global.Bindings.Symbol.Value;local disposeSymbol,asyncDisposeSymbol=vm.Get(symbolConstructor,'dispose'),vm.Get(symbolConstructor,'asyncDispose')
 local records=setmetatable({},{__mode='kv'});local scopes=setmetatable({},{__mode='k'});local active={};local constructors={};local protocols={};local promises
 local function check()assert(api.Alive and vm.Alive,'JavaScript resource stacks disposed')end
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function text(v)v=vm.ToPrimitive(v,'string');if type(v)=='table'and v.Kind=='symbol'then fail('TypeError','Cannot convert a Symbol to error text')end;return VM.string(v)end
 local function define(target,key,d)vm.DefineProperty(target,key,vm.Object(d,VM.Null))end
 local function native(name,n,fn)local v={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end};define(v,'length',{value=n,configurable=true});define(v,'name',{value=name,configurable=true});return v end
 local function property(target,key,value)define(target,key,{value=value,writable=true,configurable=true})end
 local function global(name,value)globals[name]=value;vm.Global.Bindings[name]={Value=value}end
 local function prototypeFor(newTarget,fallback)
  if newTarget then local prototype=vm.Get(newTarget,'prototype');if vm.ObjectModel.IsObject(prototype)then return prototype end end;return fallback
 end
 local suppressedProto=vm.Object({},vm.Prototypes.Error);vm.Prototypes.SuppressedError=suppressedProto;property(suppressedProto,'name','SuppressedError');property(suppressedProto,'message','')
 local suppressedCtor
 local function suppressed(args,newTarget)
  local value=vm.Object({},prototypeFor(newTarget,suppressedProto));value.Kind='error';value.ErrorName='SuppressedError'
  if args[3]~=nil and args[3]~=U then property(value,'message',text(args[3]))end
  property(value,'error',arg(args,1));property(value,'suppressed',arg(args,2));return value
 end
 suppressedCtor=native('SuppressedError',3,function(args)return suppressed(args,suppressedCtor)end);suppressedCtor.Construct=suppressed;suppressedCtor.Prototype=vm.Global.Bindings.Error.Value
 define(suppressedCtor,'prototype',{value=suppressedProto});property(suppressedProto,'constructor',suppressedCtor);global('SuppressedError',suppressedCtor)
 local function brand(receiver,async)
  local r=records[receiver];if not r or r.Async~=async then fail('TypeError','Resource stack called on incompatible receiver')end;return r
 end
 local function pending(receiver,async)local r=brand(receiver,async);if r.Disposed then fail('ReferenceError','Resource stack is already disposed')end;return r end
 local function allocate(async,newTarget)
  local value=vm.Object({},prototypeFor(newTarget,protocols[async]));local r={Entries={},Disposed=false,Async=async};value.ResourceStackState=r;records[value]=r;return value
 end
 local function append(r,entry)
  if #r.Entries>=4096 then fail('RangeError','Resource stack record budget exceeded')end
  if entry.Async==nil then entry.Async=r.Async end;table.insert(r.Entries,entry)
 end
 local function resource(value,async)
  if value==U or value==N then return if async then {Async=true}else nil end
  if not vm.ObjectModel.IsObject(value)then fail('TypeError','Resource must be an object')end
  local method,ignore
  if async then method=vm.Get(value,asyncDisposeSymbol);if method==U or method==N then method=vm.Get(value,disposeSymbol);ignore=true end
  else method=vm.Get(value,disposeSymbol)end
  if not VM.callable(method)then fail('TypeError','Resource disposer must be callable')end
  return {Method=method,Receiver=value,IgnoreResult=ignore,Async=async}
 end
 local function combine(errorValue,previous,hasError)
  return if hasError then suppressed({errorValue,previous,'An error was suppressed during disposal'},suppressedCtor)else errorValue
 end
 local function invoke(entry)return vm:Call(entry.Method,if entry.Adopt then {entry.Value}else {},if entry.Receiver==nil then U else entry.Receiver)end
 local function syncRecord(r,failed,failure)
  if r.Disposed then if failed then VM.throw(failure)end;return U end
  r.Disposed=true;local entries=r.Entries;r.Entries={}
  for i=#entries,1,-1 do vm.Step();local ok,result=pcall(invoke,entries[i]);entries[i]=nil;if not ok then failure=combine(VM.exceptionValue(result),failure,failed);failed=true end end
  if failed then VM.throw(failure)end;return U
 end
 local function asyncRecord(r,failed,failure)
  local promise,resolve,reject=promises.CreatePromise()
  if r.Disposed then if failed then reject({failure})else resolve({U})end;return promise end
  r.Disposed=true;local entries=r.Entries;r.Entries={};active[entries]=true;local index=#entries;local needsAwait,hasAwaited=false,false
  local advance
  local function rejected(errorValue)if not api.Alive then return end;failure=combine(errorValue,failure,failed);failed=true;advance()end
  advance=function()
   if not api.Alive then return end
   while index>0 do vm.Step();local entry=entries[index]
    -- Null await-using records require an await before a subsequent sync
    -- disposer. Async records perform their own await after invocation.
    if not entry.Async and needsAwait and not hasAwaited then
     needsAwait=false;promises.Await(U,function()advance()end,rejected);return
    end
    entries[index]=nil;index-=1
    if not entry.Method then needsAwait=true;continue end
    local success,result=pcall(invoke,entry);local fallbackRejected=false
    if not success and entry.IgnoreResult then local p,_,rejectResult=promises.CreatePromise();rejectResult({VM.exceptionValue(result)});success,result=true,p;fallbackRejected=true end
    if not success then failure=combine(VM.exceptionValue(result),failure,failed);failed=true;continue end
    if not entry.Async then continue end
    if entry.IgnoreResult and not fallbackRejected then result=U end
    hasAwaited=true
    promises.Await(result,function()advance()end,rejected);return
   end
   if needsAwait and not hasAwaited then hasAwaited=true;promises.Await(U,function()advance()end,rejected);return end
   active[entries]=nil;if failed then reject({failure})else resolve({U})end
  end;advance();return promise
 end
 local function syncDispose(receiver)return syncRecord(brand(receiver,false),false,U)end
 local function asyncDispose(receiver)
  local ok,r=pcall(brand,receiver,true)
  if not ok then local promise,_,reject=promises.CreatePromise();reject({VM.exceptionValue(r)});return promise end
  return asyncRecord(r,false,U)
 end
 local function scope(record)
  if not scopes[record]then fail('TypeError','Invalid lexical resource scope')end;return record
 end
 function api:NewScope()
  check();local record={Entries={},Disposed=false,Async=false};scopes[record]=true;return record
 end
 function api:RegisterScope(record,value,isAsync)
  check();local r=scope(record);if r.Disposed then fail('ReferenceError','Lexical resource scope is already disposed')end
  if isAsync and not promises then fail('TypeError','Async resource disposal requires intrinsic promises')end
  local entry=resource(value,isAsync==true)
  if entry then append(r,entry)end;if isAsync then r.Async=true end;return value
 end
 function api:ScopeIsAsync(record)return scope(record).Async end
 function api:DisposeScope(record,failed,failure)
  check();local r=scope(record);local hasError=failed==true;local errorValue=if failure==nil then U else failure
  return if r.Async then asyncRecord(r,hasError,errorValue)else syncRecord(r,hasError,errorValue)
 end
 local function installStack(async)
  local name=if async then 'AsyncDisposableStack'else 'DisposableStack';local proto=vm.Object({});protocols[async]=proto;vm.Prototypes[name]=proto
  local constructor=native(name,0,function()fail('TypeError',name..' requires new')end);constructor.Construct=function(_,newTarget)check();return allocate(async,newTarget)end;constructors[async]=constructor
  define(constructor,'prototype',{value=proto});property(proto,'constructor',constructor);global(name,constructor)
  local use=native('use',1,function(args,receiver)
   local r=pending(receiver,async);local value=arg(args,1)
   local entry=resource(value,async);if entry then append(r,entry)end;return value
  end);property(proto,'use',use)
  property(proto,'adopt',native('adopt',2,function(args,receiver)local r=pending(receiver,async);local value,callback=arg(args,1),arg(args,2);if not VM.callable(callback)then fail('TypeError','onDispose must be callable')end;append(r,{Method=callback,Value=value,Adopt=true});return value end))
  property(proto,'defer',native('defer',1,function(args,receiver)local r=pending(receiver,async);local callback=arg(args,1);if not VM.callable(callback)then fail('TypeError','onDispose must be callable')end;append(r,{Method=callback});return U end))
  property(proto,'move',native('move',0,function(_,receiver)local r=pending(receiver,async);local moved=allocate(async,constructors[async]);records[moved].Entries=r.Entries;r.Entries={};r.Disposed=true;return moved end))
  define(proto,'disposed',{get=native('get disposed',0,function(_,receiver)return brand(receiver,async).Disposed end),configurable=true})
  local disposer=native(if async then 'disposeAsync'else 'dispose',0,function(_,receiver)return if async then asyncDispose(receiver)else syncDispose(receiver)end)
  property(proto,if async then 'disposeAsync'else 'dispose',disposer)
  property(proto,if async then asyncDisposeSymbol else disposeSymbol,disposer)
  if vm.SymbolToStringTag then define(proto,vm.SymbolToStringTag,{value=name,configurable=true})end
 end
 function api:AttachPromises(adapter)
  check();if promises then return end;assert(adapter.CreatePromise and adapter.Await,'AsyncDisposableStack requires intrinsic promise adapters');promises=adapter;installStack(true)
 end
 installStack(false);if options then api:AttachPromises(options)end
 function api:Destroy()
  self.Alive=false;for _,r in records do table.clear(r.Entries);r.Disposed=true end
  for r in scopes do table.clear(r.Entries);r.Disposed=true end
  for entries in active do table.clear(entries)end
  table.clear(active);table.clear(scopes);table.clear(records);promises=nil
 end
 return api
end
return ResourceStacks
