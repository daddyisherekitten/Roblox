--!strict
-- Storage-bucket coordination is explicit: a host shares a Store+PartitionKey.
-- Plain stores coordinate VMs in one Luau environment, never separate Actors.
local WebLocks={}
local stores=setmetatable({},{__mode='k'})
function WebLocks.createStore(): any
 local store={Partitions={},Managers=0,NextClient=0,DefaultPartition={},NameBytes=0,MaxNameBytes=4194304}
 stores[store]=true;return store
end
local function trustworthy(address)
 if type(address)~='string'then return false end
 local scheme,host=address:match('^(%w+)://([^/:]+)')
 if scheme=='https'or scheme=='wss'then return true end
 if scheme~='http'then return false end
 if host=='localhost'or host and host:match('%.localhost$')then return true end
 local ipv6Tail=address:match('^http://%[::1%](.*)$')
 if ipv6Tail and(ipv6Tail==''or ipv6Tail:match('^[/?#]')or ipv6Tail:match('^:%d+$')or ipv6Tail:match('^:%d+/'))then return true end
 local a,b,c,d;if host then a,b,c,d=host:match('^(%d+)%.(%d+)%.(%d+)%.(%d+)$')end
 return a=='127'and tonumber(b)<=255 and tonumber(c)<=255 and tonumber(d)<=255
end
function WebLocks.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true}
 local events=options.Events;local store=options.Store or WebLocks.createStore();assert(stores[store],'Invalid Web Locks store')
 local partition=options.PartitionKey or store.DefaultPartition;local origin=options.Origin
 local secure=if options.SecureContext~=nil then options.SecureContext==true else trustworthy(if type(origin)=='string'then origin else options.URL)
 local owned,tasks,lockStates={},{},setmetatable({},{__mode='kv'});local count=0;local manager
 store.NextClient+=1;local clientId='engine-lock-client-'..store.NextClient
 local function check()assert(api.Alive and vm.Alive,'Web Locks disposed')end
 local function errorValue(name,message)return if name=='TypeError'or name=='RangeError'then VM.error(name,message)else events:DOMException(message,name)end
 local function fail(name,message)VM.throw(errorValue(name,message))end
 local function arg(args,index)return if args[index]==nil then U else args[index]end
 local function text(value)value=vm.ToPrimitive(value,'string');if type(value)=='table'and value.Kind=='symbol'then fail('TypeError','Cannot convert Symbol to lock name')end;local result=VM.string(value);if #result>65536 then fail('QuotaExceededError','Lock name budget exceeded')end;return result end
 local function field(value,key)return if value==U or value==N or value==nil then U else vm.Get(value,key)end
 local function define(target,key,d)vm.DefineProperty(target,key,vm.Object(d,VM.Null))end
 local function native(name,length,fn)local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end};define(value,'name',{value=name,configurable=true});define(value,'length',{value=length,configurable=true});return value end
 local function method(proto,name,length,fn)define(proto,name,{value=native(name,length,fn),writable=true,enumerable=true,configurable=true})end
 local function promiseMethod(proto,name,length,fn)
  method(proto,name,length,function(args,receiver)local p,resolve,reject=options.CreatePromise();local ok,why=pcall(fn,args,receiver,resolve,reject);if not ok then reject({VM.exceptionValue(why)})end;return p end)
 end
 local function enqueue(fn)
  local id;id=options.EnqueueTask(function()if id then tasks[id]=nil end;if api.Alive and vm.Alive then fn()end end)
  if id then tasks[id]=true end;return id
 end
 local function cancelTask(id)if id then tasks[id]=nil;if options.CancelTask then options.CancelTask(id)end end end
 local function getManager()
  if options.IsFullyActive and not options.IsFullyActive()then fail('InvalidStateError','Document is not fully active')end
  if type(origin)~='string'or origin=='null'or options.Allowed==false then fail('SecurityError','Web Locks requires an allowed non-opaque storage origin')end
  if manager then return manager end
  local origins=store.Partitions[partition];if not origins then origins={};store.Partitions[partition]=origins end
  manager=origins[origin]
  if not manager then
   if store.Managers>=256 then fail('QuotaExceededError','Lock bucket budget exceeded')end
   manager={Queues={},Held={},Count=0,Owners=0,Names=0,Processing=false,Store=store};origins[origin]=manager;store.Managers+=1
  end
  manager.Owners+=1;return manager
 end
 local process,retire
 local function compatible(bucket,name,mode)
  for _,record in bucket.Held do if record.Name==name and(mode=='exclusive'or record.Mode=='exclusive')then return false end end;return true
 end
 retire=function(record,settle,success,value,advance,preserveCallback)
  if record.Phase=='done'then return end
  local bucket,owner=record.Manager,record.Owner;local old=record.Phase;record.Phase='done'
  if record.Unsubscribe then record.Unsubscribe();record.Unsubscribe=nil end
  if record.Task and not preserveCallback then owner:Cancel(record.Task);record.Task=nil end
  if old=='queued'then local queue=bucket.Queues[record.Name];local index=queue and table.find(queue,record);if index then table.remove(queue,index)end
  elseif old=='held'then local index=table.find(bucket.Held,record);if index then table.remove(bucket.Held,index)end end
  bucket.Count-=1;owner:Drop(record)
  local resolve,reject=record.Resolve,record.Reject;record.Resolve,record.Reject=nil,nil
  if preserveCallback then record.InvokeAfterSteal=true else record.Callback=nil end
  if advance then process(bucket,record.Name)end
  if settle and owner.Alive then(if success then resolve else reject)({value})end
 end
 function api:Cancel(id)cancelTask(id)end
 function api:Drop(record)if owned[record]then owned[record]=nil;count-=1 end end
 function api:AbortError()return errorValue('AbortError','The lock was stolen by another request')end
 function api:RejectStolen(reject)
  local reason=self:AbortError();local ok=pcall(enqueue,function()reject({reason})end)
  if not ok and self.Alive then reject({reason})end
 end
 function api:Grant(record,available)
  local ok,id=pcall(enqueue,function()
   record.Task=nil;if record.Phase=='done'and not record.InvokeAfterSteal then return end
   record.InvokeAfterSteal=nil
   if record.Signal and events:IsAborted(record.Signal)then retire(record,true,false,events:AbortReason(record.Signal),true);return end
   if record.Unsubscribe then record.Unsubscribe();record.Unsubscribe=nil end
   local lock=N
   if available then lock=vm.Object({},api.LockPrototype);local data={Name=record.Name,Mode=record.Mode};lock.LockState=data;lockStates[lock]=data end
   local waiting,resolve,reject=options.CreatePromise()
   options.Await(waiting,function(value)
    if record.Phase~='done'then local scheduled=pcall(enqueue,function()retire(record,true,true,value,true)end);if not scheduled then retire(record,true,false,errorValue('QuotaExceededError','Lock release task budget exceeded'),true)end end
   end,function(reason)
    if record.Phase~='done'then local scheduled=pcall(enqueue,function()retire(record,true,false,reason,true)end);if not scheduled then retire(record,true,false,reason,true)end end
   end)
   local callback=record.Callback;record.Callback=nil
   local success,result=pcall(vm.Call,vm,callback,{lock},U)
   if success then resolve({result})else reject({VM.exceptionValue(result)})end
  end)
  if ok then record.Task=id else retire(record,true,false,errorValue('QuotaExceededError','Lock callback task budget exceeded'),true)end
 end
 process=function(bucket,name)
  if bucket.Processing then return end;bucket.Processing=true
  local queue=bucket.Queues[name]
  while queue and #queue>0 do
   local record=queue[1]
   if not record.Owner.Alive then retire(record,false,false,N,false)
   elseif not compatible(bucket,name,record.Mode)then break
   else table.remove(queue,1);record.Phase='held';table.insert(bucket.Held,record);record.Owner:Grant(record,true)end
  end
  bucket.Processing=false
  if queue and #queue==0 then
   local held=false;for _,record in bucket.Held do if record.Name==name then held=true;break end end
   if not held then bucket.Queues[name]=nil;bucket.Names-=1;bucket.Store.NameBytes-=#name end
  end
 end
 local lockProto,managerProto=vm.Object({}),vm.Object({});api.LockPrototype=lockProto
 for name,key in {name='Name',mode='Mode'}do define(lockProto,name,{get=native('get '..name,0,function(_,receiver)local s=lockStates[receiver];if not s then fail('TypeError','Illegal Lock receiver')end;return s[key]end),enumerable=true,configurable=true})end
 local lockManager=vm.Object({},managerProto);api.Manager=lockManager
 promiseMethod(managerProto,'request',2,function(args,receiver,resolve,reject)
  if receiver~=lockManager then fail('TypeError','Illegal LockManager receiver')end
  if #args<2 then fail('TypeError','Lock request requires name and callback')end
  local name=text(args[1]);local opts,callback=if #args>=3 then args[2]else U,if #args>=3 then args[3]else args[2]
  if opts~=U and opts~=N and not vm.ObjectModel.IsObject(opts)then fail('TypeError','LockOptions must be a dictionary')end
  local ifAvailable=VM.truth(field(opts,'ifAvailable'));local rawMode=field(opts,'mode');local mode=if rawMode==U then 'exclusive'else text(rawMode)
  if mode~='exclusive'and mode~='shared'then fail('TypeError','Invalid lock mode')end
  local signal=field(opts,'signal');if signal~=U then events:IsAborted(signal)else signal=nil end
  local steal=VM.truth(field(opts,'steal'))
  if not VM.callable(callback)then fail('TypeError','Lock callback must be callable')end
  local bucket=getManager()
  if name:sub(1,1)=='-'or steal and(ifAvailable or mode~='exclusive')or signal and(steal or ifAvailable)then fail('NotSupportedError','Invalid lock name or option combination')end
  if signal and events:IsAborted(signal)then reject({events:AbortReason(signal)});return end
  if count>=128 or bucket.Count>=1024 then fail('QuotaExceededError','Lock request budget exceeded')end
  local queue=bucket.Queues[name]
  if not queue then
   if bucket.Names>=1024 or store.NameBytes+#name>store.MaxNameBytes then fail('QuotaExceededError','Lock resource/name byte budget exceeded')end
   queue={};bucket.Queues[name]=queue;bucket.Names+=1;store.NameBytes+=#name
  end
  local record={Owner=api,Manager=bucket,Name=name,Mode=mode,ClientId=clientId,Resolve=resolve,Reject=reject,Callback=callback,Signal=signal,Phase='queued'}
  owned[record]=true;count+=1;bucket.Count+=1
  if signal then
   local ok,unsubscribe=pcall(events.SubscribeAbort,events,signal,function()if record.Phase~='done'then retire(record,true,false,events:AbortReason(signal),true)end end)
   if not ok then retire(record,false,false,N,true);error(unsubscribe,0)end;record.Unsubscribe=unsubscribe
  end
  local stolen={}
  if steal then
   for _,held in table.clone(bucket.Held)do if held.Name==name then
    table.insert(stolen,{Owner=held.Owner,Reject=held.Reject})
    retire(held,false,false,N,false,held.Task~=nil)
   end end
   table.insert(queue,1,record)
  elseif ifAvailable and(#queue>0 or not compatible(bucket,name,mode))then record.Phase='fallback';api:Grant(record,false);return
  else table.insert(queue,record)end
  process(bucket,name)
  -- Already posted grant callbacks still run after a steal, without ownership.
  -- Publish stolen request rejection after the replacement callback task.
  for _,entry in stolen do if entry.Owner.Alive then entry.Owner:RejectStolen(entry.Reject)end end
 end)
 promiseMethod(managerProto,'query',0,function(_,receiver,resolve)
  if receiver~=lockManager then fail('TypeError','Illegal LockManager receiver')end
  -- Broker operations are serialized native bookkeeping at API entry. Capture
  -- this operation's snapshot before later request calls, then deliver by task.
  local bucket=getManager();local held,pending={},{}
  local function info(record)return vm.Object({name=record.Name,mode=record.Mode,clientId=record.ClientId},nil,{'name','mode','clientId'})end
  for _,record in bucket.Held do table.insert(held,info(record))end
  for _,queue in bucket.Queues do for _,record in queue do table.insert(pending,info(record))end end
  local snapshot=vm.Object({held=vm.Array(held),pending=vm.Array(pending)},nil,{'held','pending'})
  enqueue(function()resolve({snapshot})end)
 end)
 local function constructor(name,proto)
  local value=native(name,0,function()fail('TypeError','Illegal '..name..' constructor')end);value.Construct=function()fail('TypeError','Illegal '..name..' constructor')end
  define(value,'prototype',{value=proto});define(proto,'constructor',{value=value,writable=true,configurable=true});define(proto,vm.SymbolToStringTag,{value=name,configurable=true});globals[name]=value;vm.Global.Bindings[name]={Value=value}
 end
 if secure then
  constructor('Lock',lockProto);constructor('LockManager',managerProto)
  local navigator=globals.navigator
  if not vm.ObjectModel.IsObject(navigator)then navigator=vm.Object({});globals.navigator=navigator;vm.GlobalEnvironment:Define('navigator',vm.Object({value=navigator,writable=false,enumerable=true,configurable=true},N),true)end
  define(navigator,'locks',{get=native('get locks',0,function(_,receiver)if receiver~=navigator then fail('TypeError','Illegal Navigator receiver')end;return lockManager end),enumerable=true,configurable=true})
  api.InventoryRoots={['navigator.locks']=lockManager}
 end
 api.Available=secure
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  for id in tasks do if options.CancelTask then options.CancelTask(id)end end;table.clear(tasks)
  local affected={};for record in owned do affected[record.Name]=true;retire(record,false,false,N,false)end
  if manager then
   for name in affected do process(manager,name)end
   manager.Owners-=1
   if manager.Owners==0 and manager.Count==0 then
    local origins=store.Partitions[partition];origins[origin]=nil;store.Managers-=1
    if next(origins)==nil then store.Partitions[partition]=nil end
   end
  end
  table.clear(owned);table.clear(lockStates)
 end
 return api
end
return WebLocks
