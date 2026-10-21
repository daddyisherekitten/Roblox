--!strict
-- Two actual Runtime realms and the AudioHost candidate; controlled native IO.
-- This is a separately named Chromium-profile counterpart, not the refuted
-- original five-case preservation baseline or an iframe-inactivity simulation.
return function(Parser,Runtime,Events,AudioHost,mode)
 local cases,checks=0,0
 local expectedInventory={
  ["settlement-scheduler"]={Checks=28,IDs={"settlement-scheduler-stop-decline","settlement-scheduler-stop-throw-nil","settlement-scheduler-stop-throw-false","settlement-scheduler-stop-throw-table"}},
  ["main"]={Checks=72,IDs={"live-playing-one-state","paused-adoption","pending-play-owner-progress-origin-settlement","failed-error-ranges-event-binding","source-fallback-one-pool","unsupported-transfer-terminal","parent-write-new-source","parent-write-stop","parent-throw-false","parent-throw-nil","parent-throw-table","origin-dispose-first","destination-dispose-first"}},
  ["owner-callback"]={Checks=27,IDs={"owner-changed-stop","owner-changed-load-rehome","owner-changed-throw-false","owner-changed-throw-nil","owner-changed-throw-table"}},
  ["paint-reentry"]={Checks=5,IDs={"paint-read-stop-no-publication"}},
  ["lookup-fault"]={Checks=39,IDs={"transfer-lookup-false","transfer-lookup-nil","transfer-lookup-table","settlement-before-destroy-lookup-false","settlement-before-destroy-lookup-nil","settlement-before-destroy-lookup-table","adapter-destroy-lookup-false","adapter-destroy-lookup-nil","adapter-destroy-lookup-table"}},
  ["native-hooks"]={Checks=33,IDs={"bind-volume-stop-play-token","metadata-position-stop","force-pause-stop","seek-snapshot-reselect","timeupdate-snapshot-reselect","settlement-load-reselect","ended-play-position-stop","pending-pause-native-stop"}},
  ["origin-factory"]={Checks=8,IDs={"nested-factory-unique-token","factory-origin-destroy-no-refill"}},
  ["capability-reentry"]={Checks=8,IDs={"capability-same-owner-new-source","capability-owner-handoff"}},
 }
 local expected=expectedInventory[mode or 'main'];assert(expected,'Unknown control mode')
 local seen={}
 local function complete(id)
  assert(not seen[id],'Duplicate control: '..id);local allowed=false
  for _,required in expected.IDs do if required==id then allowed=true;break end end
  assert(allowed,'Unexpected control: '..id);seen[id]=true;cases+=1
 end
 local function finishInventory()
  assert(cases==#expected.IDs,'Exact named control count changed')
  for _,id in expected.IDs do assert(seen[id],'Missing required control: '..id)end
  assert(checks==expected.Checks,'Exact assertion inventory changed')
 end
 local function check(value,label)checks+=1;assert(value,label)end
 local function signal()
  local slots={};local api={}
  function api:Connect(fn)local entry={Connected=true,Callback=fn};function entry:Disconnect()self.Connected=false;self.Callback=nil end;table.insert(slots,entry);return entry end
  return api
 end
 local function fixture(settings)
  settings=settings or{};local objects,jobs,requests={},{},{}
  local instance={new=function(class)
   assert(class=='Sound');local values={ClassName='Sound',Playing=false,TimePosition=0,TimeLength=20,IsLoaded=false,SoundId='',DestroyCalls=0,Ended=signal(),DidLoop=signal()}
   local object=setmetatable({},{__index=function(_,key)if settings.SoundRead then settings.SoundRead(key)end;return values[key]end,__newindex=function(_,key,value)values[key]=value;if settings.SoundWrite then settings.SoundWrite(key,value)end;if key=='Parent'and settings.ParentChanged then settings.ParentChanged(value)end end})
   function object:Pause()self.Playing=false end
   function object:Stop()self.Playing=false;self.TimePosition=0 end
   function object:Destroy()self.DestroyCalls+=1;self.Playing=false;self.Parent=nil end
   table.insert(objects,object);return object
  end}
  local taskAPI={spawn=function(fn)local thread=coroutine.create(fn);local ok,message=coroutine.resume(thread);assert(ok,message);if coroutine.status(thread)=='suspended'then table.insert(jobs,thread)end end}
  local eventsA,eventsB=Events.new(error),Events.new(error)
  local pages={{Alive=true,Root={Name='A'}},{Alive=true,Root={Name='B'}}}
  local trees={{MediaByNode={}},{MediaByNode={}}};local hosts={}
  for index,page in pages do
   page.ResolveAudio=function(value)
    if value:find('missing',1,true)then return nil end
    return if value:find('failure',1,true)then 'rbxassetid://bad'else 'rbxassetid://'..index
   end
   hosts[index]=AudioHost.new(page,trees[index],{Instance=instance,Task=taskAPI,ContentProvider={PreloadAsync=function(_,native,report)
    local object=native[1];table.insert(requests,{Owner=index,Object=object,Asset=object.SoundId})
    if settings.Hold then coroutine.yield('native-held')end
    if object.SoundId=='rbxassetid://bad'then if report then report('', 'Failure')end;object.IsLoaded=false else object.IsLoaded=true end
   end}})
  end
  local realms={}
  for index,events in {eventsA,eventsB}do realms[index]=Runtime.new(Parser.parseDocument('<!doctype html><body></body>'),{URL='https://ownership.test/'..pages[index].Root.Name..'/index.html',Events=events,AudioAdapter=hosts[index],Schedule=function()end,ApplyChanges=function()return false end})end
  local a,b=realms[1],realms[2]
  local function pumpOne(realm)for _=1,18 do if realm.Alive then realm:PumpTasks();realm.EventLoop:Checkpoint()end end end
  local function pump()pumpOne(a);pumpOne(b);pumpOne(a);pumpOne(b)end
  local function run(realm,source,only)local ok,message=realm:Run(source);assert(ok,tostring(message));if not only then pump()end end
  a:Start();b:Start();pump()
  local function setup(source,playing)
   run(a,[=[window.m=document.createElement('audio');m.id='m';m.preload='auto';document.body.append(m);window.originEvents=[];for(const name of ['loadedmetadata','playing','volumechange','error'])m.addEventListener(name,()=>originEvents.push(name));window.getPausedA=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,'paused').get;window.playA=HTMLMediaElement.prototype.play;window.pauseA=HTMLMediaElement.prototype.pause;window.promiseA=Promise;window.errorA=TypeError;window.mediaErrorA=MediaError;window.rangeA=TimeRanges;]=])
   run(a,source or "m.src='tone.ogg';")
   if playing then run(a,"m.currentTime=5;m.playbackRate=1.5;m.volume=.25;m.muted=true;window.oldPlayOutcome='pending';m.play().then(()=>oldPlayOutcome='fulfilled',e=>oldPlayOutcome=e.name);")end
   return a.DOM.Unwrap(a.Window.Get('m'))
  end
  local function adopt(only)
   for _,key in {'m','getPausedA','playA','pauseA','promiseA','errorA','mediaErrorA','rangeA'}do b.VM.Global.Bindings[key]={Value=a.Window.Get(key)}end
   run(b,"document.body.append(document.adoptNode(m));window.destinationEvents=[];m.addEventListener('volumechange',()=>destinationEvents.push('volume'));",only)
  end
  local function resume(index)local thread=jobs[index];assert(thread and coroutine.status(thread)=='suspended');local ok,message=coroutine.resume(thread);assert(ok,message)end
  local function finish()
   if a.Alive then a:Destroy()end;if b.Alive then b:Destroy()end;eventsA:Destroy();eventsB:Destroy()
   for _,object in objects do check(object.DestroyCalls==1,'Native cleanup exact once after both Runtime teardown')end
   check(#a.Diagnostics==0 and #b.Diagnostics==0,'No hidden unhandled rejection or engine diagnostic')
  end
  return{A=a,B=b,Pages=pages,Trees=trees,Hosts=hosts,Objects=objects,Requests=requests,Jobs=jobs,Setup=setup,Adopt=adopt,Run=run,Pump=pump,PumpOne=pumpOne,Resume=resume,Finish=finish}
 end
 if mode=='settlement-scheduler'then
  local failures={}
  local function strictCheck(value,label)checks+=1;if not value then table.insert(failures,label)end end
  for _,case in {
   {ID='settlement-scheduler-stop-decline'},
   {ID='settlement-scheduler-stop-throw-nil',Throws=true},
   {ID='settlement-scheduler-stop-throw-false',Throws=true,Payload=false},
   {ID='settlement-scheduler-stop-throw-table',Throws=true,Payload={Marker='original scheduler failure'}},
  }do
   local h=fixture({Hold=true});local n=h.Setup(nil,true);h.Adopt();local r=n.AudioResourceState;local origin=r.OriginLease
   h.Run(h.B,"window.pendingOutcome='pending';window.rejectionCount=0;window.schedulerPlay=m.play();schedulerPlay.then(()=>pendingOutcome='fulfilled',e=>{rejectionCount++;pendingOutcome=e.name});")
   strictCheck(h.A.Alive and r.OwnerLease==h.B.AudioElements.OwnerLease and #r.Plays==1 and h.B.Window.Get('pendingOutcome')=='pending','Actual pending PromiseA/current ownerB setup: '..case.ID)
   local scheduler,settle,drop=origin.QueueTask,origin.Settle,origin.Drop;local settlements,drops,hooks=0,0,0
   origin.Settle=function(tokens,name,message)settlements+=#tokens;return settle(tokens,name,message)end
   origin.Drop=function(tokens)drops+=1;return drop(tokens)end
   origin.QueueTask=function(fn)
    if #r.Settlements>0 then hooks+=1;r.Controller:StopOwner(r.OwnerLease,'Injected scheduler stop')
     if case.Throws then error(case.Payload,0)end;return false
    end
    return scheduler(fn)
   end
   local ok,message=pcall(r.Controller.Pause,r.Controller)
   strictCheck(if case.Throws then not ok and message==case.Payload else ok and message==nil,'Scheduler exact original result/payload survives already-settled cleanup: '..case.ID)
   h.Pump();strictCheck(settlements==1 and h.B.Window.Get('pendingOutcome')=='AbortError'and h.B.Window.Get('rejectionCount')==1,'Actual pending Play Abort settlement exactly once: '..case.ID)
   strictCheck(hooks==1 and drops==0 and r.Stopped and r.Handle==nil and #r.Plays==0 and #r.Settlements==0 and next(origin.Capabilities)==nil and next(origin.Slots)==nil and next(r.OwnerLease.Slots)==nil and h.Objects[1].DestroyCalls==1,'No double/nil Drop and canonical/token/task/native cleanup: '..case.ID)
   origin.QueueTask=scheduler;origin.Settle=settle;origin.Drop=drop
   h.Resume(1);h.Resume(2);h.Pump();strictCheck(r.Stopped and #h.Requests==2 and h.B.Window.Get('rejectionCount')==1 and h.Objects[1].DestroyCalls==1,'Held old preparation cannot publish/restart/settle again: '..case.ID)
   print('AUDIO_SETTLEMENT_SCHEDULER_CONTROL',case.ID,'originalOutcome='..tostring(if case.Throws then not ok and message==case.Payload else ok and message==nil),'settlements='..settlements,'drops='..drops)
   h.Finish();complete(case.ID)
  end
  finishInventory();assert(#failures==0,table.concat(failures,'\n'))
  print('AUDIO_SETTLEMENT_SCHEDULER','cases='..cases,'checks='..checks);return
 end
 if mode=='native-hooks'then
  do
   local enabled=false;local h,n,r
   h=fixture({SoundWrite=function(key)if enabled and key=='Volume'then enabled=false;r.Controller:StopOwner(r.OwnerLease,'Bind setter stop')end end})
   n=h.Setup("m.preload='none';m.src='tone.ogg';",false);r=n.AudioResourceState;n.Attributes.controls='';enabled=true
   h.Run(h.A,"window.bindOutcome='pending';m.play().catch(e=>bindOutcome=e.name);")
   check(r.Stopped and r.Error.Code==4 and not r.Loading and #r.Plays==0 and next(r.OriginLease.Capabilities)==nil,'Controls setter stop rejects newly created Play token without stale state mutation')
   check(h.A.Window.Get('bindOutcome')=='NotSupportedError'and #h.Requests==0 and h.Objects[1].DestroyCalls==1,'Controls bind stop has no IO/nil dereference and one cleanup')
   h.Finish();complete("bind-volume-stop-play-token")
  end
  do
   local enabled=false;local h,n,r
   h=fixture({Hold=true,SoundWrite=function(key)if enabled and key=='TimePosition'then enabled=false;r.Controller:StopOwner(r.OwnerLease,'Metadata setter stop')end end})
   n=h.Setup(nil,true);r=n.AudioResourceState;enabled=true;h.Resume(1);h.Pump()
   check(r.Stopped and r.Error.Code==4 and r.Ready==0 and not r.Loading and not r.Playing and #r.Plays==0,'Loaded native cursor setter stop cannot later Play or publish fresh metadata')
   check(h.A.Window.Get('oldPlayOutcome')=='AbortError'and h.Objects[1].DestroyCalls==1,'Loaded-stop pending Play is settled and native cleanup exact once')
   h.Finish();complete("metadata-position-stop")
  end
  do
   local enabled=false;local h,n,r
   h=fixture({SoundWrite=function(key)if enabled and key=='Playing'then enabled=false;r.Controller:StopOwner(r.OwnerLease,'Force Pause stop')end end})
   n=h.Setup(nil,true);r=n.AudioResourceState;enabled=true;r.Controller:Load(true)
   check(r.Stopped and r.Error.Code==4 and not r.Loading and r.Ready==0 and r.OwnerLease.Active[r]==nil,'Force-load Pause stop preserves terminal error/loading/active state')
   check(h.Objects[1].DestroyCalls==1 and #h.Requests==1,'Force Pause stop does not start another selection/IO')
   h.Finish();complete("force-pause-stop")
  end
  do
   local enabled=false;local writes=0;local h,n,r
   h=fixture({SoundRead=function(key)if enabled and key=='TimeLength'then enabled=false;h.A.DOM.Attribute(n,'src','next.ogg')end end,SoundWrite=function(key,value)if key=='TimePosition'and value==7 then writes+=1 end end})
   n=h.Setup(nil,true);r=n.AudioResourceState;local epoch=r.SelectionEpoch;enabled=true;h.Run(h.A,'m.currentTime=7;',true)
   check(r.SelectionEpoch==epoch+1 and r.Ready==0 and not r.Seeking and r.DefaultStart==0 and writes==0,'Snapshot-reselection prevents old currentTime setter publication/native seek into new epoch')
   h.Pump();check(r.Current=='https://ownership.test/A/next.ogg'and r.Ready==4,'Replacement resource remains selectable after stale setter abort')
   h.Finish();complete("seek-snapshot-reselect")
  end
  do
   local enabled=false;local h,n,r
   h=fixture({SoundRead=function(key)if enabled and key=='TimeLength'then enabled=false;h.B.DOM.Attribute(n,'src','next.ogg')end end})
   n=h.Setup(nil,true);r=n.AudioResourceState;h.Adopt();h.Run(h.A,"window.times=[];m.addEventListener('timeupdate',()=>times.push(m.currentSrc));")
   enabled=true;r.Handle.Notify({Kind='timeupdate',Generation=r.Generation});h.Pump()
   check(h.A.VM.Get(h.A.Window.Get('times'),'length')==1,'Stale timeupdate snapshot cannot re-stamp/publish an extra new-generation event')
   check(r.Current=='https://ownership.test/B/next.ogg'and r.Ready==4,'Timeupdate reentry leaves replacement owner selection coherent')
   h.Finish();complete("timeupdate-snapshot-reselect")
  end
  do
   local h=fixture({Hold=true});local n=h.Setup(nil,true);h.Adopt();local r=n.AudioResourceState
   h.Run(h.B,"window.queuedResult='pending';m.play().then(()=>queuedResult='fulfilled',e=>queuedResult=e.name);",true)
   h.Resume(2);h.PumpOne(h.B);check(#r.Settlements==1,'Settlement reentry probe holds actual queued success in original A task global')
   local original=r.OriginLease.Settle;local enabled=true;local epoch=r.SelectionEpoch
   r.OriginLease.Settle=function(tokens,name,message)original(tokens,name,message);if enabled then enabled=false;h.B.DOM.Attribute(n,'src','replacement.ogg')end end
   r.Controller:Load(true);h.Pump()
   check(r.SelectionEpoch==epoch+1 and r.Current=='https://ownership.test/B/replacement.ogg'and r.Ready==4,'Settlement callback replacement load prevents outer force-load epoch/reset overwrite')
   check(h.B.Window.Get('queuedResult')=='fulfilled'and #r.Plays==0 and #r.Settlements==0,'Already queued success remains fulfilled under settlement reentry')
   h.Resume(1);h.Pump();h.Finish();complete("settlement-load-reselect")
  end
  do
   local enabled=false;local h,n,r
   h=fixture({SoundWrite=function(key,value)if enabled and key=='TimePosition'and value==0 then enabled=false;r.Controller:StopOwner(r.OwnerLease,'Ended cursor stop')end end})
   n=h.Setup(nil,true);r=n.AudioResourceState;r.Handle.Notify({Kind='ended',Generation=r.Generation});h.Pump()
   check(r.Ended and r.Paused,'Ended-Play reentry starts from actual delivered native ended event')
   enabled=true;h.Run(h.A,"window.endedOutcome='pending';m.play().catch(e=>endedOutcome=e.name);")
   check(r.Stopped and r.Error.Code==4 and r.Paused and not r.Playing and #r.Plays==0 and next(r.OriginLease.Capabilities)==nil and h.A.Window.Get('endedOutcome')=='AbortError'and #h.Requests==1,'Ended cursor setter stop leaves terminal state and settles new token without stale Play publication')
   h.Finish();complete('ended-play-position-stop')
  end
  do
   local enabled=false;local h,n,r
   h=fixture({Hold=true,SoundWrite=function(key,value)if enabled and key=='Playing'and value==false then enabled=false;r.Controller:StopOwner(r.OwnerLease,'Ordinary pause stop')end end})
   n=h.Setup(nil,true);r=n.AudioResourceState;check(#r.Plays==1 and h.A.Window.Get('oldPlayOutcome')=='pending','Ordinary pause reentry starts with actual pending original Play token')
   enabled=true;h.Run(h.A,'m.pause();')
   check(r.Stopped and r.Paused and #r.Plays==0 and #r.Settlements==0 and next(r.OriginLease.Capabilities)==nil and h.A.Window.Get('oldPlayOutcome')=='AbortError','Native Pause owner stop rejects extracted pending Play exactly once without capability drop-only loss')
   h.Resume(1);h.Pump();h.Finish();complete('pending-pause-native-stop')
  end
  finishInventory();print('AUDIO_NATIVE_HOOKS','cases='..cases,'checks='..checks);return
 end
 if mode=='origin-factory'then
  do
   local h=fixture();local n=h.Setup(nil,false);local origin=n.AudioResourceState.OriginLease;local factory=origin.Factory;local enabled=true;local innerToken,innerPromise
   origin.Factory=function()if enabled then enabled=false;innerPromise,innerToken=origin.Create()end;return factory()end
   local outerPromise,outerToken=origin.Create()
   check(innerToken~=outerToken and innerPromise~=outerPromise and origin.Capabilities[innerToken]~=nil and origin.Capabilities[outerToken]~=nil,'Reentrant actual VM factory uses unique locally captured token IDs')
   origin.Drop({innerToken,outerToken});check(next(origin.Capabilities)==nil,'Unused test capabilities explicitly released')
   h.Finish();complete("nested-factory-unique-token")
  end
  do
   local h=fixture();local n=h.Setup(nil,true);h.Adopt();local r=n.AudioResourceState;local origin=r.OriginLease;local factory=origin.Factory
   origin.Factory=function()local promise,resolve,reject=factory();h.A.AudioElements:Destroy();return promise,resolve,reject end
   local value,token=origin.Create()
   check(value==nil and token==nil and not origin.Alive and next(origin.Capabilities)==nil and origin.Factory==nil,'Factory-origin teardown cannot refill cleared registry or return new success capability')
   check(r.Handle.Alive and h.Objects[1].Playing and h.Objects[1].DestroyCalls==0,'Origin factory teardown leaves current B native playback alive')
   h.Finish();complete("factory-origin-destroy-no-refill")
  end
  finishInventory();print('AUDIO_ORIGIN_FACTORY','cases='..cases,'checks='..checks);return
 end
 if mode=='capability-reentry'then
  for _,kind in {'same-owner-new-source','owner-handoff'}do
   local h=fixture();local n=h.Setup(nil,false);local r=n.AudioResourceState;local current=r.Current;local calls=0;local enabled=true
   local original=h.Pages[1].ResolveAudio
   h.Pages[1].ResolveAudio=function(value)
    calls+=1;if enabled then enabled=false
     if kind=='same-owner-new-source'then h.A.DOM.Attribute(n,'src','next.ogg')else h.Adopt()end
     return nil
    end
    return original(value)
   end
   h.Hosts[1]:CanLoad('unavailable',current,r)
   check(calls==1,'Stale raw-nil capability lookup must not call old absolute resolver: '..kind)
   h.Pump();check(r.Current~=''and #h.Objects==1,'Capability reentry retains coherent one-backend resource state: '..kind)
   h.Finish();complete('capability-'..kind)
  end
  finishInventory();print('AUDIO_CAPABILITY_REENTRY','cases='..cases,'checks='..checks);return
 end
 if mode=='owner-callback'then
  local h=fixture({Hold=true});local node=h.Setup(nil,true);local state=node.AudioResourceState;local owner=h.A.AudioElements.OwnerLease
  check(state.Blocking==true,'Loaded-gate callback probe starts with actual pending connected AUDIO')
  local oldChanged=owner.Changed;local enabled=true
  owner.Changed=function(pending)oldChanged(pending);if enabled then enabled=false;state.Controller:StopOwner(owner,'Injected gate stop')end end
  state.Controller:ChangeOwner(h.B.AudioElements.OwnerLease)
  check(state.Stopped and state.OwnerLease==owner and h.B.AudioElements.OwnerLease.States[node]==nil,'LoadStateChanged stop must prevent outer destination-owner publication')
  check(#h.Objects==1 and h.Objects[1].DestroyCalls==1 and #h.Requests==1,'LoadStateChanged stop cleanup is exact once with no B IO')
  h.Resume(1);h.Pump();check(state.Stopped and #h.Requests==1,'Old held worker remains stale after gate-stop reentry')
  h.Finish();complete('owner-changed-stop')
  do
   local q=fixture({Hold=true});local n=q.Setup(nil,true);local r=n.AudioResourceState;local previous=q.A.AudioElements.OwnerLease
   -- Controller-boundary test models the already committed document handoff;
   -- it isolates service reentry rather than replacing the ordinary DOM cases.
   n.Parent=nil;n.OwnerDocument=q.B.DOM.Document.DOMNode
   local callback=previous.Changed;local active=true
   previous.Changed=function(pending)callback(pending);if active then active=false;r.Controller:Load(true)end end
   local epoch=r.SelectionEpoch;r.Controller:ChangeOwner(q.B.AudioElements.OwnerLease)
   check(r.OwnerLease==q.B.AudioElements.OwnerLease and r.SelectionEpoch==epoch+1,'Gate-load reentry keeps current B ownership and exactly the inner selection epoch')
   q.PumpOne(q.B);check(#q.Requests==2 and q.Requests[2].Owner==2 and #q.Jobs==2,'Only fresh callback stable selection is rehomed to B and starts one preparation')
   q.Resume(2);q.Pump();check(r.Ready==4 and r.Paused and #r.Plays==0,'Rehomed explicit load retains pause/promise-reset semantics without outer UA resume')
   q.Resume(1);q.Pump();check(r.Ready==4 and #q.Requests==2,'Old native progress remains canceled during stable slot handoff')
   q.Finish();complete('owner-changed-load-rehome')
  end
  for payloadIndex,payload in {{Value=false},{},{Value={Marker='changed original'}}}do
   local q=fixture({Hold=true});local n=q.Setup(nil,true);local r=n.AudioResourceState;local previous=q.A.AudioElements.OwnerLease
   previous.Changed=function()error(payload.Value,0)end
   local ok,message=pcall(r.Controller.ChangeOwner,r.Controller,q.B.AudioElements.OwnerLease)
   check(not ok and message==payload.Value,'Gate callback preserves original nil/false/table payload')
   check(r.Stopped and r.Handle==nil and r.OwnerLease==previous and q.B.AudioElements.OwnerLease.States[n]==nil and q.Objects[1].DestroyCalls==1,'Gate callback failure fully clears old handle/slots without B publication')
   q.Resume(1);q.Pump();check(r.Stopped and #q.Requests==1,'Gate callback failure suppresses old held native resume')
   q.Finish();complete('owner-changed-throw-'..({'false','nil','table'})[payloadIndex])
  end
  finishInventory();print('AUDIO_OWNER_CALLBACK_REENTRY','cases='..cases,'checks='..checks);return
 end
 if mode=='lookup-fault'then
  for payloadIndex,payload in {{Value=false},{},{Value={Marker='lookup original'}}}do
   local q=fixture();local n=q.Setup(nil,true);local r=n.AudioResourceState;local adapter=q.Hosts[2]
   adapter.TakeSession=nil;setmetatable(adapter,{__index=function(_,key)if key=='TakeSession'then error(payload.Value,0)end end})
   local ok,message=pcall(r.Controller.ChangeOwner,r.Controller,q.B.AudioElements.OwnerLease)
   check(not ok and message==payload.Value,'Transfer method lookup preserves exact nil/false/table payload')
   check(r.Stopped and r.Handle==nil and q.Objects[1].DestroyCalls==1 and #q.Requests==1,'Throwing transfer lookup releases local/native ownership with no B IO')
   q.Finish();complete('transfer-lookup-'..({'false','nil','table'})[payloadIndex])
  end
  for payloadIndex,payload in {{Value=false},{},{Value={Marker='first settle failure'}}}do
   local q=fixture({Hold=true});local n=q.Setup(nil,true);local r=n.AudioResourceState;local handle=r.Handle;local second={Marker='secondary destroy lookup'}
   check(#r.Plays>0,'Settlement-vs-cleanup fault starts with a real pending Play token')
   local destroy=handle.Destroy;handle.Destroy=nil;setmetatable(handle,{__index=function(_,key)if key=='Destroy'then error(second,0)end end})
   local settle=r.OriginLease.Settle;r.OriginLease.Settle=function()error(payload.Value,0)end
   local ok,message=pcall(r.Controller.StopOwner,r.Controller,r.OwnerLease)
   check(not ok and message==payload.Value,'Handle destroy lookup cannot mask first settlement nil/false/table failure')
   check(r.Stopped and r.Handle==nil and next(r.OwnerLease.Slots)==nil and next(r.OriginLease.Slots)==nil,'Malicious cleanup lookup still clears canonical callback/handle slots')
   r.OriginLease.Settle=settle;handle.Destroy=destroy;setmetatable(handle,nil)
   q.Finish();complete('settlement-before-destroy-lookup-'..({'false','nil','table'})[payloadIndex])
  end
  for payloadIndex,payload in {{Value=false},{},{Value={Marker='adapter destroy lookup'}}}do
   local q=fixture();local n=q.Setup(nil,true);local r=n.AudioResourceState;local adapter=q.Hosts[1];local destroy=adapter.Destroy
   adapter.Destroy=nil;setmetatable(adapter,{__index=function(_,key)if key=='Destroy'then error(payload.Value,0)end end})
   local ok,message=pcall(q.A.AudioElements.Destroy,q.A.AudioElements)
   check(not ok and message==payload.Value,'Adapter cleanup lookup preserves exact nil/false/table payload')
   check(r.Stopped and r.Handle==nil and q.Objects[1].DestroyCalls==1 and not r.OwnerLease.Alive and r.OwnerLease.Adapter==nil and r.OriginLease.Create==nil,'Adapter lookup failure follows complete facade/service/native release')
   adapter.Destroy=destroy;setmetatable(adapter,nil);destroy(adapter)
   q.Finish();complete('adapter-destroy-lookup-'..({'false','nil','table'})[payloadIndex])
  end
  finishInventory();print('AUDIO_LOOKUP_FAULT','cases='..cases,'checks='..checks);return
 end
 if mode=='paint-reentry'then
  local enabled=false;local h,node,state
  h=fixture({SoundRead=function(key)if enabled and key=='Playing'and h.Objects[1].Parent==h.Pages[2].Root then enabled=false;state.Controller:StopOwner(h.B.AudioElements.OwnerLease,'Injected paint stop')end end})
  node=h.Setup(nil,true);state=node.AudioResourceState
  local item={Kind='AUDIO',Playing='sentinel',Duration='sentinel',CurrentTime='sentinel'};h.Trees[2].MediaByNode[node]=item
  enabled=true;h.Adopt()
  check(state.Stopped and state.Handle==nil and item.Sound==nil and item.AudioSession==nil,'Native paint-property reentry clears transferred backend/item lease')
  check(item.Playing=='sentinel'and item.Duration=='sentinel'and item.CurrentTime=='sentinel','Native snapshot must not repaint stale item after property-triggered stop')
  check(#h.Objects==1 and h.Objects[1].DestroyCalls==1 and #h.Requests==1,'Paint reentry prevents outer transfer result/reload and disposes once')
  h.Finish();complete('paint-read-stop-no-publication');finishInventory();print('AUDIO_PAINT_REENTRY','cases=1','checks='..checks);return
 end
 do
  local h=fixture();local node=h.Setup(nil,true);local state=node.AudioResourceState;local session=state.Handle;h.Adopt()
  check(node.AudioResourceState==state and node.AudioController.State==state,'Live adoption retains one canonical state')
  check(state.Handle==session and #h.Objects==1 and #h.Requests==2,'Reload retains one Sound and uses second native preparation')
  check(h.Objects[1].Parent==h.Pages[2].Root and h.Requests[2].Owner==2,'Backend/parent/provider lease is destination B')
  h.Run(h.B,"window.current=JSON.stringify([m.paused,getPausedA.call(m),m.currentTime,m.playbackRate,m.volume,m.muted]);pauseA.call(m);window.afterPause=JSON.stringify([m.paused,getPausedA.call(m)]);")
  check(h.B.Window.Get('current')=='[false,false,0,1,0.25,true]','Chromium-profile reload resets cursor/rate and preserves preferences/play intent')
  check(h.B.Window.Get('afterPause')=='[true,true]'and not h.Objects[1].Playing,'Borrowed A action and B ordinary reads share state/backend')
  h.Run(h.B,"m.muted=false;")
  check(h.A.VM.Get(h.A.Window.Get('originEvents'),'length')>=3 and h.B.VM.Get(h.B.Window.Get('destinationEvents'),'length')==1,'Transferred target retains origin listeners and destination listener')
  h.Finish();complete("live-playing-one-state")
 end
 do
  local h=fixture();local node=h.Setup(nil,false);local state=node.AudioResourceState;h.Run(h.A,'m.currentTime=5;m.playbackRate=1.5;');h.Adopt()
  check(node.AudioResourceState==state and state.Paused and not h.Objects[1].Playing and state.Position==0 and state.Rate==1,'Paused live adoption stays paused after reload')
  h.Finish();complete("paused-adoption")
 end
 do
  local h=fixture({Hold=true});local node=h.Setup(nil,true);local state=node.AudioResourceState;h.Adopt(true)
  check(node.AudioResourceState==state and #h.Jobs==2,'Adoption end checkpoint starts stable owner-B work independently of pending old IO')
  h.PumpOne(h.B);check(#h.Jobs==2 and #h.Requests==2,'B stable selection prepares the transferred backend')
  h.Run(h.B,"window.newOutcome='pending';window.p=HTMLMediaElement.prototype.play.call(m);window.realmResult=[p instanceof promiseA,p instanceof Promise].join('|');p.then(()=>newOutcome='fulfilled',e=>newOutcome=e.name);",true)
  check(h.B.Window.Get('realmResult')=='true|false','Valid B binding returns original element-realm A Promise')
  h.Resume(2);h.PumpOne(h.B)
  check(state.Ready==4 and state.Playing and h.B.Window.Get('newOutcome')=='pending','B native progress runs while A settlement queue has not run')
  h.PumpOne(h.A)
  check(h.A.Window.Get('oldPlayOutcome')=='AbortError'and h.B.Window.Get('newOutcome')=='fulfilled'and #state.Plays==0,'UA reload rejects old pending Play and A queue resolves new A capability')
  local generation=state.Generation;h.Resume(1);h.Pump()
  check(state.Generation==generation and state.Ready==4,'Late old native resume cannot replace current B selection')
  h.Finish();complete("pending-play-owner-progress-origin-settlement")
 end
 do
  local h=fixture();local node=h.Setup("m.src='failure.ogg';",false);local state=node.AudioResourceState
  h.Run(h.A,'window.oldError=m.error;window.oldErrorCode=m.error.code;');local old=state.Error;local epoch=state.SelectionEpoch;h.Adopt()
  check(node.AudioResourceState==state and state.Error==old and state.SelectionEpoch==epoch and #h.Requests==1,'Failed handoff host profile retains error/selection without IO')
  h.B.VM.Global.Bindings.oldError={Value=h.A.Window.Get('oldError')}
  h.Run(h.B,[=[window.failedIdentity=m.error===oldError&&m.error instanceof mediaErrorA&&!(m.error instanceof MediaError);window.spans=m.buffered;window.rangeIdentity=spans instanceof rangeA&&!(spans instanceof TimeRanges)&&spans!==m.buffered;window.aReject='pending';window.bReject='pending';playA.call({}).catch(e=>aReject=[e instanceof errorA,e instanceof TypeError].join('|'));HTMLMediaElement.prototype.play.call({}).catch(e=>bReject=[e instanceof errorA,e instanceof TypeError].join('|'));]=])
  check(h.B.Window.Get('failedIdentity')==true and h.B.Window.Get('rangeIdentity')==true,'Live origin materializes same A error and fresh A ranges')
  check(h.B.Window.Get('aReject')=='true|false'and h.B.Window.Get('bReject')=='false|true','Promise-returning incompatible brand rejects in invoked binding A/B realm')
  h.A.VM.Global.Bindings.eventB={Value=h.B.Window.Get('Event')}
  h.Run(h.A,"window.loadEventRealms=[];m.addEventListener('loadstart',e=>loadEventRealms.push([e instanceof Event,e instanceof eventB,e.bubbles,e.cancelable].join('|')));")
  h.Run(h.B,'HTMLMediaElement.prototype.load.call(m);window.sameAfterLoad=m.error===oldError;');check(#h.Requests==2 and state.Error~=old and h.B.Window.Get('sameAfterLoad')==false,'Explicit owner-B load makes new data error under retained original A materialization profile')
  check(h.A.VM.Get(h.A.Window.Get('loadEventRealms'),'0')=='false|true|false|false','Listener A sees current owner EventB for B-binding load; existing frozen flags unchanged')
  h.Run(h.A,'HTMLMediaElement.prototype.load.call(m);')
  check(h.A.VM.Get(h.A.Window.Get('loadEventRealms'),'1')=='false|true|false|false'and #h.Requests==3,'Borrowed original A-load also creates EventB on original A task route')
  h.Finish();complete("failed-error-ranges-event-binding")
 end
 do
  local h=fixture();local node=h.Setup("m.innerHTML='<source src=\"missing.ogg\"><source src=\"tone.ogg\">';",true);local state=node.AudioResourceState;local pool=node.AudioController.Pool;h.Adopt()
  check(node.AudioResourceState==state and node.AudioController.Pool==pool and state.Mode=='children'and state.Candidate==node.Children[2],'SOURCE adoption restarts selection on same canonical state/pure selector pool')
  check(#h.Objects==1 and #h.Requests==2 and h.Requests[2].Owner==2 and state.Playing,'Destination SOURCE fallback retains one backend and playback intent')
  local bHost=h.B.Events;local count=h.A.VM.Get(h.A.Window.Get('originEvents'),'length')
  check(count>=4,'Origin media/SOURCE task route survives the UA reload epoch')
  h.Finish();complete("source-fallback-one-pool")
 end
 do
  local h=fixture();local node=h.Setup(nil,true);local controller=node.AudioController;h.Hosts[2].TakeSession=nil;h.Adopt()
  check(node.AudioController==controller and controller.State.Stopped and controller.State.Error.Code==4,'Missing transfer hook leaves same terminal canonical controller after successful DOM adoption')
  check(node.OwnerDocument==h.B.DOM.Document.DOMNode and #h.Objects==1 and #h.Requests==1 and h.Objects[1].DestroyCalls==1,'Missing transfer hook disposes old handle once with no destination Open or IO')
  h.Run(h.B,"window.unsupported='pending';m.play().catch(e=>unsupported=e.name);")
  check(h.B.Window.Get('unsupported')=='NotSupportedError'and #h.Objects==1 and node.AudioController==controller,'Ordinary facade access cannot resurrect unsupported-transfer state')
  h.Finish();complete("unsupported-transfer-terminal")
 end
 do
  local enabled=false;local h,node
  h=fixture({ParentChanged=function(parent)
   if enabled and parent==h.Pages[2].Root then enabled=false;h.B.DOM.Attribute(node,'src','replacement.ogg')end
  end});node=h.Setup(nil,true);local state=node.AudioResourceState;enabled=true;h.Adopt()
  check(state.OwnerLease==h.B.AudioElements.OwnerLease and state.Handle.CurrentHostLease~=nil and #h.Objects==1,'Reentrant direct-src write keeps transferred one backend')
  check(state.Current=='https://ownership.test/B/replacement.ogg'and state.Paused and not state.Playing and #h.Requests==2,'Reentrant src load wins over outer adoption reload/resume')
  h.Finish();complete("parent-write-new-source")
 end
 do
  local enabled=false;local h
  h=fixture({ParentChanged=function(parent)if enabled and parent==h.Pages[2].Root then enabled=false;h.B.AudioElements:Destroy()end end})
  local node=h.Setup(nil,true);local state=node.AudioResourceState;enabled=true;h.Adopt()
  check(h.B.Alive and state.Stopped and state.Handle==nil and #h.Objects==1 and #h.Requests==1 and h.Objects[1].DestroyCalls==1,'Reentrant current audio owner stop clears handle/membership once without disposing Runtime B')
  check(next(state.OwnerLease.Slots)==nil and next(state.OwnerLease.States)==nil,'Stopped owner releases callback/index ownership before outer transfer resumes')
  h.Finish();complete("parent-write-stop")
 end
 for payloadIndex,payload in {{Value=false},{},{Value={Marker='original transfer failure'}}}do
  local enabled=false;local h
  h=fixture({ParentChanged=function(parent)if enabled and parent==h.Pages[2].Root then enabled=false;error(payload.Value,0)end end})
  local node=h.Setup(nil,true);local controller=node.AudioController;enabled=true
  -- Direct handoff isolates the injected native-property exception payload from
  -- Runtime.Run's diagnostic reporting. Ordinary DOM adoption is covered above.
  local ok,message=pcall(controller.ChangeOwner,controller,h.B.AudioElements.OwnerLease)
  check(not ok and message==payload.Value,'Transfer preserves original nil/false/table error payload')
  check(controller.State.Stopped and controller.State.Handle==nil and #h.Objects==1 and h.Objects[1].DestroyCalls==1 and #h.Requests==1,'Transfer exception completes canonical/native cleanup before rethrow')
  check(h.A.Alive and h.B.Alive,'Injected audio transfer failure does not teardown either Runtime')
  h.Finish();complete('parent-throw-'..({'false','nil','table'})[payloadIndex])
 end
 for _,order in {'origin-first','destination-first'}do
  local h=fixture();local node=h.Setup(nil,true);local state=node.AudioResourceState;h.Adopt();local session=state.Handle;local sound=h.Objects[1]
  if order=='origin-first'then
   h.A:Destroy();h.Run(h.B,"window.current=document.getElementById('m');window.afterOrigin=[current.paused,current.readyState].join('|');current.pause();window.deadPlay='pending';current.play().catch(e=>deadPlay=e.name);")
   check(session.Alive and sound.DestroyCalls==0 and sound.Parent==h.Pages[2].Root,'Origin Runtime.Destroy cannot take transferred B native backend')
   check(h.B.Window.Get('afterOrigin')=='false|4'and h.B.Window.Get('deadPlay')=='InvalidStateError'and state.Paused,'Fresh B scalar/pause works; disposed A factory has explicit terminal rejection profile')
   session:Request('play');h.PumpOne(h.B);check(sound.Playing and state.Playing,'Internal native B Play works without an A author Promise')
   for _=1,5 do session:Request('pause');h.PumpOne(h.B);session:Request('play');h.PumpOne(h.B)end
   check(#state.Plays==0 and #state.Settlements==0,'Permanently declined dead-origin media tasks leave no settlement entries across repeated native cycles')
   check(next(state.OriginLease.Capabilities)==nil and next(state.OriginLease.Slots)==nil and state.OriginLease.Create==nil and state.OriginLease.MaterializeError==nil,'Origin token/task/factory registries are actually released')
  else
   h.B:Destroy();check(not session.Alive and sound.DestroyCalls==1 and not sound.Playing and state.Stopped,'Current owner Runtime.Destroy owns one cleanup and terminal state')
   local controller=node.AudioController;h.Run(h.A,"window.currentStopped=getPausedA.call(m);window.ordinaryDisposedFailure=false;try{m.paused}catch(e){ordinaryDisposedFailure=true}window.stoppedOutcome='pending';playA.call(m).catch(e=>stoppedOutcome=e.name);")
   check(node.AudioController==controller and node.AudioResourceState==state and #h.Objects==1 and h.A.Window.Get('stoppedOutcome')=='NotSupportedError','Stopped owner cannot resurrect via live original facade')
   check(h.A.Window.Get('currentStopped')==true and h.A.Window.Get('ordinaryDisposedFailure')==true,'Live borrowed A reads terminal state; generic disposed-owner wrapper routing remains strict/open')
  end
  h.Finish();complete(if order=='origin-first'then 'origin-dispose-first'else 'destination-dispose-first')
 end
 finishInventory();print('AUDIO_CROSS_REALM_CANDIDATE','cases='..cases,'checks='..checks,'profile=two live Runtime/real AudioHost controlled native IO; Chromium reset and explicit teardown policy')
end
