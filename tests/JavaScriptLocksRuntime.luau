--!strict
-- Direct WorkerRealm shares a real in-process host store. Separate Roblox Actor
-- transport is not simulated by this test and remains a separate broker task.
return function(Parser,Runtime,WorkerRealm,Events,WebLocks)
 local store=WebLocks.createStore();local output,errors={},{};local instances={}
 local function page(name,partition,origin)
  local events=Events.new(error)
  local realm=Runtime.new(Parser.parseDocument('<!doctype html><body></body>'),{URL='https://locks.test/'..name,Events=events,Schedule=function()end,
   WebLockStore=store,WebLockPartitionKey=partition or'profile',DocumentOrigin=origin,
   Console=function(_,value)table.insert(output,name..':'..value)end,Diagnostic=function(message)table.insert(errors,message)end})
  table.insert(instances,{Realm=realm,Events=events});return realm
 end
 local function run(realm,source)local ok,why=realm:Run(source);assert(ok,tostring(why));assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
 local a,b,c=page('a'),page('b'),page('c','separate-profile')
 run(a,"navigator.locks.request('shared-host',function(){console.log('held');return new Promise(function(){});});")
 run(b,"navigator.locks.request('shared-host',function(){console.log('handoff');});")
 run(c,"navigator.locks.request('shared-host',function(){console.log('independent');return new Promise(function(){});});")
 local worker
 worker=WorkerRealm.new({url='https://locks.test/worker.js',type='classic',source="navigator.locks.request('shared-host',function(){postMessage('held');return new Promise(function(){});});"},{WebLockStore=store,WebLockPartitionKey='profile',
  Message=function(wire)local value=worker.Clone:Deserialize(wire);table.insert(output,'worker:'..value)end,Error=function(message)table.insert(errors,message.message or tostring(message))end})
 worker:Start()
 local function pump()for _=1,12 do for _,entry in instances do if entry.Realm.Alive then entry.Realm:PumpTasks()end end;if worker.Alive then worker:Pump()end end;assert(#errors==0,table.concat(errors,' | '))end
 pump();assert(table.concat(output,'|')=='a:held|c:independent','Runtime pages share only explicit origin+partition bucket; worker is queued behind the page')
 a:Destroy();pump();assert(table.concat(output,'|')=='a:held|c:independent|b:handoff|worker:held','Page disposal grants the next page, then the actual dedicated-worker VM')
 run(b,"navigator.locks.request('shared-host',function(){console.log('worker-released');});")
 pump();assert(#output==4);worker:Destroy();pump();assert(output[5]=='b:worker-released','WorkerRealm disposal releases only worker-owned locks and grants a queued page')
 local denied=page('opaque','profile',{})
 run(denied,"navigator.locks.request('blocked',function(){console.log('wrong');}).catch(function(e){console.log(e.name);});")
 pump();assert(output[6]=='opaque:SecurityError','Actual runtime passes opaque origin identity rather than serialized null')
 local intrinsic=page('intrinsic')
 for _,phase in {'already-aborted','queued','reserved'}do
  local before=#output
  if phase=='queued'then
   run(intrinsic,"var release;navigator.locks.request('intrinsic-reason',function(){return new Promise(function(r){release=r;});});");pump()
  end
  run(intrinsic,"var aborter=new AbortController(),reason={actual:true},reasonReads=0;Object.defineProperty(aborter.signal,'reason',{get:function(){reasonReads++;return 'author-fake';}});")
  if phase=='already-aborted'then run(intrinsic,'aborter.abort(reason);')end
  run(intrinsic,"navigator.locks.request('intrinsic-reason',{signal:aborter.signal},function(){console.log('wrong');}).catch(function(value){console.log((value===reason)+':'+reasonReads);});")
  if phase~='already-aborted'then run(intrinsic,'aborter.abort(reason);')end
  pump();assert(#output==before+1 and output[#output]=='intrinsic:true:0',phase..': actual Runtime uses internal signal state without author reason access')
  if phase=='queued'then run(intrinsic,'release();');pump()end
 end
 for _,entry in instances do entry.Realm:Destroy();entry.Events:Destroy()end
 assert(store.Managers==0 and next(store.Partitions)==nil and store.NameBytes==0,'Last runtime/worker owners release and prune their own bucket resources')
 print('Web Locks actual Runtime/WorkerRealm: explicit shared host store, partition isolation, page-to-page-to-worker handoff, opaque denial and owner-only disposal passed; Actor IPC remains separate')
end
