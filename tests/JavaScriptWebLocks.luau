--!strict
return function(VM,Promises,AsyncFunctions,EventLoop,HostEvents,WebLocks)
 local function fresh(extra)
  extra=extra or {};local r={Values={},Reports={}};local vm,loop,promises
  local globals={record=function(args)table.insert(r.Values,VM.string(args[1]));return VM.Undefined end}
  loop=EventLoop.new({Clock=function()return 0 end,Report=function(message)table.insert(r.Reports,tostring(message))end,
   Invoke=function(fn,args)vm:Call(fn,args);loop:Checkpoint();return vm.Steps end,AfterCheckpoint=function()if promises then promises:AfterCheckpoint()end end})
  promises=Promises.new({Enqueue=function(fn)loop:QueueMicrotask(fn)end,Report=function(message)table.insert(r.Reports,VM.string(message))end,
   Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(value,key,receiver)return vm.Get(value,key,receiver)end,
   Construct=function(fn,args)return vm:Construct(fn,args)end,Iterator=function(value)return vm.Iterator(value)end,Array=function(items)return vm.Array(items)end,Object=function(values)return vm.Object(values)end})
  globals.Promise=promises.Constructor
  local async=AsyncFunctions.new({Create=function()return promises:CreateCapability()end,Wait=function(value,yes,no)promises:Await(value,yes,no)end,Resume=function(record,rejected,value)return vm:ResumeAsync(record,rejected,value)end})
  vm=VM.new(globals,{Async=async,MaxSteps=100000});promises:Attach(vm)
  local host=HostEvents.install(vm,globals,{Report=function(message)table.insert(r.Reports,VM.string(message))end})
  local locks=WebLocks.install(vm,globals,{Store=extra.Store,PartitionKey=extra.Partition,Origin=extra.Origin or'https://example.test',URL=extra.URL,SecureContext=extra.SecureContext,Allowed=extra.Allowed,
   IsFullyActive=extra.IsFullyActive,Events=host,CreatePromise=function()return promises:CreateCapability()end,
   Await=function(value,yes,no)promises:Await(value,function(args)yes(args[1])end,function(args)no(args[1])end)end,
   EnqueueTask=function(fn)return loop:QueueTask(fn)end,CancelTask=function(id)loop:CancelTask(id)end})
  r.VM,r.Loop,r.API=vm,loop,locks
  function r:Run(source)vm:Run(source);loop:Checkpoint()end
  function r:Pump()for _=1,12 do loop:PumpTasks();loop:Checkpoint()end end
  function r:Value(name)return vm.Global.Bindings[name].Value end
  function r:Destroy()locks:Destroy();host:Destroy();async:Destroy();promises:Destroy();loop:Destroy();vm:Destroy()end
  return r
 end
 local function pump(...)for _=1,5 do for _,r in {...}do r:Pump()end end end
 do
  local r=fresh();r:Run([=[
var trace=['sync'];var manager=navigator.locks;var stable=manager===navigator.locks&&manager instanceof LockManager;
manager.request('basic',function(lock){trace.push('callback:'+lock.name+':'+lock.mode+':'+(lock instanceof Lock));return 7;}).then(function(value){trace.push('done'+value);});
var noInline=trace.join('|');
]=])
  assert(r:Value('stable')and r:Value('noInline')=='sync');r:Pump();r:Run("record(trace.join('|'));")
  assert(r.Values[1]=='sync|callback:basic:exclusive:true|done7','Callback is task-queued and request adopts its result after release');assert(#r.Reports==0);r:Destroy()
 end
 do
  local r=fresh();r:Run([=[
var trace=[],a,b;
navigator.locks.request('fair',{mode:'shared'},function(){trace.push('reader1');return new Promise(function(resolve){a=resolve;});});
navigator.locks.request('fair',{mode:'shared'},function(){trace.push('reader2');return new Promise(function(resolve){b=resolve;});});
navigator.locks.request('fair',function(){trace.push('writer');});
navigator.locks.request('fair',{mode:'shared'},function(){trace.push('late-reader');});
navigator.locks.query().then(function(s){record(s.held.length+':'+s.pending.length+':'+s.pending[0].mode+':'+s.pending[1].mode);s.held[0].name='changed';});
]=]);r:Pump();assert(r.Values[1]=='2:2:exclusive:shared')
  r:Run("a();");r:Pump();r:Run("record(trace.join('|'));navigator.locks.query().then(function(s){record(s.held[0].name);});");r:Pump()
  assert(r.Values[2]=='reader1|reader2'and r.Values[3]=='fair','Queued exclusive request prevents late reader bypass; snapshots do not mutate lock state')
  r:Run('b();');r:Pump();r:Run("record(trace.join('|'));");assert(r.Values[4]=='reader1|reader2|writer|late-reader');r:Destroy()
 end
 do
  local r=fresh();r:Run([=[
var release;var held=navigator.locks.request('busy',function(){return new Promise(function(resolve){release=resolve;});});
navigator.locks.request('busy',{ifAvailable:true},function(lock){record(lock===null);return 'miss';}).then(record);
]=]);r:Pump();assert(table.concat(r.Values,'|')=='true|miss');r:Run('release();');r:Pump();r:Destroy()
 end
 do
  local r=fresh();r:Run([=[
var release,controller=new AbortController();navigator.locks.request('abort',function(){return new Promise(function(resolve){release=resolve;});});
navigator.locks.request('abort',{signal:controller.signal},function(){record('wrong');}).catch(record);controller.abort('custom-reason');
]=]);r:Pump();assert(table.concat(r.Values,'|')=='custom-reason');r:Run('release();');r:Pump();r:Destroy()
 end
 do
  local r=fresh();r:Run("var c=new AbortController();navigator.locks.request('reserved',{signal:c.signal},function(){record('wrong');}).catch(record);c.abort('before-callback');")
  r:Pump();assert(table.concat(r.Values,'|')=='before-callback','Abort between reservation and callback skips callback and releases lock');r:Destroy()
 end
 -- Abort reasons are internal signal state. Author accessors must never be
 -- evaluated when rejecting already-aborted, queued, or reserved requests.
 for _,phase in {'already-aborted','queued','reserved'}do
  local store=WebLocks.createStore();local r=fresh({Store=store})
  if phase=='queued'then
   r:Run("var release;navigator.locks.request('intrinsic-reason',function(){return new Promise(function(r){release=r;});});");r:Pump()
  end
  r:Run("var c=new AbortController(),reason={actual:true},reads=0;Object.defineProperty(c.signal,'reason',{get:function(){reads++;return 'author-fake';}});")
  if phase=='already-aborted'then r:Run('c.abort(reason);')end
  r:Run("navigator.locks.request('intrinsic-reason',{signal:c.signal},function(){record('wrong');}).catch(function(value){record(value===reason);});")
  if phase~='already-aborted'then r:Run('c.abort(reason);')end
  r:Pump();r:Run('record(reads);')
  assert(table.concat(r.Values,'|')=='true|0',phase..': internal abort reason identity is preserved without calling an author getter')
  if phase=='queued'then r:Run('release();');r:Pump()end
  assert(#r.Reports==0,table.concat(r.Reports,' | '));r:Destroy();assert(store.Managers==0 and store.NameBytes==0)
 end
 do
  local r=fresh();r:Run("var c=new AbortController(),release;navigator.locks.request('running',{signal:c.signal},function(){record('held');return new Promise(function(r){release=r;});}).then(record);")
  r:Pump();r:Run("c.abort('ignored');release('result');");r:Pump();assert(table.concat(r.Values,'|')=='held|result','Abort subscription is removed before granted callback starts');r:Destroy()
 end
 do
  local store=WebLocks.createStore();local a,b=fresh({Store=store}),fresh({Store=store})
  a:Run("var release;navigator.locks.request('steal',function(){record('old');return new Promise(function(r){release=r;});}).catch(function(e){record(e.name);});")
  a:Pump();b:Run("var release;navigator.locks.request('steal',{steal:true},function(){record('new');return new Promise(function(r){release=r;});});")
  pump(a,b);assert(table.concat(a.Values,'|')=='old|AbortError'and b.Values[1]=='new')
  a:Run('release();');pump(a,b);b:Run("navigator.locks.query().then(function(s){record(s.held.length+':'+s.held[0].name);});");pump(a,b)
  assert(b.Values[2]=='1:steal','Settling a stolen callback later cannot release the replacement owner lock')
  b:Run('release();');pump(a,b);a:Destroy();b:Destroy();assert(store.Managers==0 and next(store.Partitions)==nil,'Final owners prune the empty storage bucket')
 end
 do
  local store=WebLocks.createStore();local a,b,c=fresh({Store=store,Partition='p'}),fresh({Store=store,Partition='p'}),fresh({Store=store,Partition='p'})
  a:Run("navigator.locks.request('handoff',function(){record('a');return new Promise(function(){});});")
  b:Run("navigator.locks.request('handoff',function(){record('b');return new Promise(function(){});});")
  c:Run("navigator.locks.request('other',function(){record('c');return new Promise(function(){});});")
  pump(a,b,c);assert(a.Values[1]=='a'and #b.Values==0 and c.Values[1]=='c')
  b:Run("navigator.locks.query().then(function(s){var first=s.held[0].clientId,other=s.pending[0].clientId;record(typeof first==='string'&&first!==other&&first.length>0);});");pump(a,b,c);assert(b.Values[1]=='true')
  a:Destroy();pump(b,c);assert(b.Values[2]=='b','Disposing one owner releases its lock and hands it to the queued other realm')
  b:Destroy();c:Run("navigator.locks.query().then(function(s){record(s.held.length+':'+s.held[0].name);});");c:Pump();assert(c.Values[2]=='1:other','Disposal never wipes another realm lock');c:Destroy();assert(store.Managers==0)
 end
 do
  local store=WebLocks.createStore();local a,b,c=fresh({Store=store,Partition='one'}),fresh({Store=store,Partition='two'}),fresh({Store=store,Partition='one',Origin='https://other.test'})
  for _,r in {a,b,c}do r:Run("navigator.locks.request('same-name',function(){record('independent');return new Promise(function(){});});")end
  pump(a,b,c);assert(a.Values[1]=='independent'and b.Values[1]=='independent'and c.Values[1]=='independent','Origin and explicit partition both separate storage buckets')
  a:Destroy();b:Destroy();c:Destroy();assert(store.Managers==0)
 end
 for _,extra in {{Origin={},SecureContext=true},{Allowed=false},{IsFullyActive=function()return false end}}do
  local r=fresh(extra);r:Run("navigator.locks.request('denied',function(){}).catch(function(e){record(e.name);});navigator.locks.query().catch(function(e){record(e.name);});");r:Pump()
  local expected=if extra.IsFullyActive then'InvalidStateError'else'SecurityError';assert(table.concat(r.Values,'|')==expected..'|'..expected);r:Destroy()
 end
 do
  local r=fresh({Origin='http://unsafe.test'});r:Run("record(typeof LockManager);record(typeof navigator);")
  assert(table.concat(r.Values,'|')=='undefined|undefined','Insecure context does not expose Web Locks interfaces');r:Destroy()
 end
 do
  local r=fresh();r:Run([=[
function rejected(p){p.catch(function(e){record(e.name);});}
rejected(navigator.locks.request('-reserved',function(){}));rejected(navigator.locks.request('x',{steal:true,mode:'shared'},function(){}));
rejected(navigator.locks.request('x',{steal:true,ifAvailable:true},function(){}));rejected(navigator.locks.request('x',{signal:new AbortController().signal,ifAvailable:true},function(){}));
rejected(navigator.locks.request('x',{mode:'invalid'},function(){}));rejected(navigator.locks.request('x',null));
rejected(navigator.locks.request.call({},'x',function(){}));rejected(navigator.locks.query.call({}));
]=]);r:Pump();assert(table.concat(r.Values,'|')=='NotSupportedError|NotSupportedError|NotSupportedError|NotSupportedError|TypeError|TypeError|TypeError|TypeError');r:Destroy()
 end
 do
  local r=fresh();r:Run("var trace=[];navigator.locks.request('immediate',function(){trace.push('first');return new Promise(function(){});}).catch(function(e){trace.push(e.name);});navigator.locks.request('immediate',{steal:true},function(){trace.push('second');});")
  r:Pump();r:Run("record(trace.join('|'));");assert(r.Values[1]=='first|second|AbortError'or r.Values[1]=='first|AbortError|second','Already queued grant callback still runs when immediately stolen; replacement/rejection relative order is not promised');r:Destroy()
 end
 do
  local r=fresh();r:Run("var release;navigator.locks.query().then(function(s){record(s.held.length);});navigator.locks.request('snapshot-race',function(){return new Promise(function(r){release=r;});});navigator.locks.query().then(function(s){record(s.held.length);});")
  r:Pump();assert(table.concat(r.Values,'|')=='0|1','Query snapshots serialize before later requests, matching native broker operation order');r:Run('release();');r:Pump();r:Destroy()
 end
 for _,origin in {'http://127.0.0.1','http://127.8.9.10:8000','http://[::1]:8000','http://localhost','http://one.localhost'}do
  local r=fresh({Origin=origin});r:Run("record(typeof navigator.locks.request);");assert(r.Values[1]=='function','Trustworthy loopback origin '..origin);r:Destroy()
 end
 for _,origin in {'http://127.evil','http://127.0.0.1.evil','http://[::1]evil.test','http://notlocalhost'}do
  local r=fresh({Origin=origin});r:Run('record(typeof LockManager);');assert(r.Values[1]=='undefined','Non-loopback origin '..origin);r:Destroy()
 end
 do
  local r=fresh({Origin='https://example.test',SecureContext=false});r:Run('record(typeof LockManager);');assert(r.Values[1]=='undefined','Explicit host insecure context overrides trustworthy URL');r:Destroy()
 end
 do
  local r=fresh();r:Run("var release;navigator.locks.request('release-race',function(){return new Promise(function(r){release=r;});});")
  r:Pump();r:Run("release();Promise.resolve().then(function(){}).then(function(){}).then(function(){}).then(function(){}).then(function(){}).then(function(){return navigator.locks.query();}).then(function(s){record(s.held.length);});")
  r:Pump();assert(r.Values[1]=='0'or r.Values[1]=='1','Snapshot can race queued release; no cross-thread timing guarantee is inferred')
  r:Run("navigator.locks.query().then(function(s){record(s.held.length);});");r:Pump();assert(r.Values[2]=='0','Settled callback eventually releases the lock');r:Destroy()
 end
 do
  local store=WebLocks.createStore();store.MaxNameBytes=3;local r=fresh({Store=store})
  r:Run("navigator.locks.request('oversize',function(){}).catch(function(e){record(e.name);});navigator.locks.query().then(function(s){record(s.held.length+':'+s.pending.length);});")
  r:Pump();assert(table.concat(r.Values,'|')=='QuotaExceededError|0:0'and store.NameBytes==0,'Rejected resource allocation leaves no held/pending lock or name-byte charge');r:Destroy();assert(store.Managers==0)
 end
 do
  local r=fresh();r:Run("navigator.locks.request('throw',function(){throw new Error('callback-failure');}).catch(function(e){record(e.message);});navigator.locks.request('throw',function(){record('next');return {then:function(resolve){resolve('adopted');}};}).then(record);")
  r:Pump();assert(table.concat(r.Values,'|')=='callback-failure|next|adopted','Throw releases lock and thenable callback result is assimilated');assert(#r.Reports==0,table.concat(r.Reports,' | '));r:Destroy()
 end
 print('Web Locks explicit storage buckets: actual VM promises/tasks, fair shared/exclusive, query snapshots, ifAvailable/abort/steal, multi-realm origin/partition and owner-only disposal passed')
end
