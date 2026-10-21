--!strict
return function(Parser,Runtime,Events,fixture)
 local expectedCases={
  ['direct removal pause play controls']=6,['direct removal synchronous move']=4,
  ['direct removal stable detach reinsert']=5,['direct removal source edits']=8,
  ['child selection mutations']=7,['empty source insertion and removal']=7,
  ['empty source move']=6,['direct removal preload-none selected source']=7,
  ['never-connected Audio playback']=5,['subtree stable removal']=4,
  ['shadow host stable removal']=4,['empty removal internal pause']=3,
  ['microtask reinsertion boundary']=2,['promise reinsertion boundary']=2,
  ['nested microtask reinsertion boundary']=2,['state-preserving move boundary']=2,
 }
 assert(fixture.target.commit=='ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c'and fixture.target.sha256=='49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f','Frozen HTML target changed')
 local seen,total={},0
 for _,case in fixture.cases do assert(expectedCases[case.name]==#case.steps and not seen[case.name],'Unexpected/duplicate/resized audio lifetime case: '..case.name);seen[case.name]=true;total+=#case.steps end
 for name in expectedCases do assert(seen[name],'Required audio lifetime case missing: '..name)end
 assert(total==74,'All 74 native lifecycle transitions are required')
 local expectedHints={['none hint upgrade retains selection']=true,['NONE hint upgrade retains selection']=true}
 assert(#fixture.hints.cases==2)
 local hintSteps={'remove src while selected','upgrade preload to auto','controls attach after upgrade','play retained source','explicit load selects child'}
 for _,case in fixture.hints.cases do assert(expectedHints[case.name]and #case.steps==5,'Required native HTTP hint control missing');expectedHints[case.name]=nil;for index,name in hintSteps do assert(case.steps[index].name==name,'Native HTTP hint transition changed')end end
 assert(next(expectedHints)==nil)
 local timingNames={'set different src while loaded','set identical src while loaded','explicit load of changed child source','set empty src while loaded','set invalid URL while selected'}
 assert(fixture.selection.timing.name=='currentSrc changes at stable selection'and #fixture.selection.timing.steps==5)
 for index,name in timingNames do assert(fixture.selection.timing.steps[index].name==name,'Required currentSrc timing transition changed')end
 assert(fixture.selection.empty.name=='source-less play survives source insertion'and #fixture.selection.empty.steps==2)
 assert(fixture.selection.empty.steps[1].name=='play without a source'and fixture.selection.empty.steps[2].name=='append source to pending play')
 local boundaryNames={['same-task source insertion retains pending play']=true,['queued source insertion retains pending play']=true,['nested source insertion retains pending play']=true}
 assert(#fixture.selection.boundaries==3)
 for _,case in fixture.selection.boundaries do assert(boundaryNames[case.name]and #case.steps==1 and case.steps[1].name=='play and insert source');boundaryNames[case.name]=nil end
 assert(next(boundaryNames)==nil)
 local promiseNames={['already-playing Play load settlement']=true,['queued playing completion load settlement']=true,['playing listener direct load settlement']=true,['queued pause rejection load settlement']=true}
 assert(#fixture.promises.cases==4)
 for _,case in fixture.promises.cases do assert(promiseNames[case.name]and #case.steps==1 and case.steps[1].name=='load preserves queued Play outcome');promiseNames[case.name]=nil end
 assert(next(promiseNames)==nil)
 local startNames={['empty load retains default start']=1,['deferred direct src retains default start']=1,['deferred child insertion retains default start']=1,['empty-network load preserves pending play']=2,['late metadata clamps and consumes default start']=1,['negative early seek is consumed at metadata']=1,['zero early seek clears default start']=1}
 assert(#fixture.starts.cases==7)
 for _,case in fixture.starts.cases do assert(startNames[case.name]==#case.steps,'Required default-start transition changed');startNames[case.name]=nil end
 assert(next(startNames)==nil)
 local function realm(html,complete)
  local requests,handles={},{};local events=Events.new(error);local adapter={Alive=true}
  function adapter:Open(node,notify)
   local h={Node=node,Notify=notify,Alive=true,Position=0,Playing=false,PauseCalls=0,ResetCalls=0,DestroyCalls=0,Settings={}}
   function h:Set(key,value)assert(self.Alive);self.Settings[key]=value;if key=='currentTime'then self.Position=value end end
   function h:Snapshot()return {Position=self.Position}end
   function h:Load(url,raw,generation)
    assert(self.Alive);self.Generation=generation;table.insert(requests,{URL=url,Raw=raw,Generation=generation,Handle=self})
    if complete~=false then self.Notify({Kind='loaded',Generation=generation,Duration=20})end
   end
   function h:Play(intent)assert(self.Alive);self.Playing=true;self.Notify({Kind='playing',Generation=self.Generation,Intent=intent})end
   function h:Pause()assert(self.Alive);self.PauseCalls+=1;self.Playing=false end
   function h:Reset(generation)assert(self.Alive);self.Generation=generation;self.ResetCalls+=1 end
   table.insert(handles,h);return h
  end
  function adapter:Destroy()self.Alive=false;for _,h in handles do h.Alive=false;h.DestroyCalls+=1 end end
  local runtime=Runtime.new(Parser.parseDocument(html or'<!doctype html><body><audio id=m controls muted preload=auto></audio><div id=holder></div></body>'),{URL='https://media.invalid/source/index.html',Events=events,AudioAdapter=adapter,Schedule=function()end,ApplyChanges=function()return false end})
  local function pump()for _=1,16 do runtime:PumpTasks();runtime.EventLoop:Checkpoint()end end
  local function run(source)local ok,message=runtime:Run(source);assert(ok,tostring(message));pump();assert(#runtime.Diagnostics==0,table.concat(runtime.Diagnostics,' | '))end
  local function finish()runtime:Destroy();events:Destroy();assert(not adapter.Alive);for _,h in handles do assert(h.DestroyCalls==1)end end
  runtime:Start();pump();return runtime,run,pump,finish,requests,handles
 end
 local state=[=[({selected:m.currentSrc==='https://media.invalid/source/one.ogg'?'one':m.currentSrc==='https://media.invalid/source/two.ogg'?'two':m.currentSrc===''?'empty':'other',paused:m.paused,rate:m.playbackRate,network:m.networkState,controls:m.controls,connected:m.isConnected})]=]
 local eventSetup=[=[globalThis.events=[];for(const type of ['loadstart','emptied','abort','play','pause','playing','waiting','loadedmetadata','canplay','suspend','error'])m.addEventListener(type,()=>events.push(type));]=]
 local function setup(run,mode,preload)
  run("globalThis.m=document.getElementById('m');globalThis.one='one.ogg';globalThis.two='two.ogg';"..(if mode=='detached'then"m=new Audio(one);m.muted=true;m.preload='auto';"else'')..eventSetup..(if preload then"m.preload='"..preload.."';"else'')..(if mode=='direct'then"m.append(Object.assign(document.createElement('source'),{src:two}));m.src=one;"elseif mode=='child'then"m.append(Object.assign(document.createElement('source'),{src:one}));"else''))
  if mode~='empty'and not preload then run('m.play().catch(()=>{});m.currentTime=3;m.playbackRate=1.5;')end
 end
 local function compare(runtime,run,raw,label)
  run('window.lifecycleState=JSON.stringify('..state..');window.lifecycleEvents=events.join(",");window.lifecycleTime=m.currentTime;')
  local expected=string.format('{"selected":%q,"paused":%s,"rate":%s,"network":%s,"controls":%s,"connected":%s}',raw.selected,tostring(raw.paused),tostring(raw.rate),tostring(raw.network),tostring(raw.controls),tostring(raw.connected))
  assert(runtime.Window.Get('lifecycleState')==expected,label..'\nexpected '..expected..'\nactual '..tostring(runtime.Window.Get('lifecycleState')))
  local actual=runtime.Window.Get('lifecycleEvents');local nativeCore,actualCore={},{}
  for _,event in raw.events do assert(event.trusted,'Native event must be trusted');if event.type=='pause'or event.type=='play'or event.type=='playing'then table.insert(nativeCore,event.type)end end
  for event in actual:gmatch('[^,]+')do if event=='pause'or event=='play'or event=='playing'then table.insert(actualCore,event)end end
  assert(table.concat(actualCore,',')==table.concat(nativeCore,','),label..': retained playback event mismatch')
  local nativeSelect=false;for _,event in raw.events do if event.type=='loadstart'or event.type=='emptied'or event.type=='abort'then nativeSelect=true end end
  if not nativeSelect then for event in actual:gmatch('[^,]+')do assert(event~='loadstart'and event~='emptied'and event~='abort',label..': unexpected new resource selection event')end end
  if raw.time==0 then assert(runtime.Window.Get('lifecycleTime')==0,label..': reset playback position')end
  return nativeSelect
 end
 do
  local runtime,run,_,finish,requests=realm();setup(run,'direct')
  for _,step in fixture.selection.timing.steps do
   local loads=#requests
   run('events.length=0;'..step.action..';window.immediateSelection=JSON.stringify('..state..');')
   local raw=step.immediate
   local expected=string.format('{"selected":%q,"paused":%s,"rate":%s,"network":%s,"controls":%s,"connected":%s}',raw.selected,tostring(raw.paused),tostring(raw.rate),tostring(raw.network),tostring(raw.controls),tostring(raw.connected))
   assert(runtime.Window.Get('immediateSelection')==expected,step.name..': currentSrc remains selected until successful stable URL selection')
   compare(runtime,run,step.settled,step.name)
   run('window.selectionFailure=JSON.stringify({ready:m.readyState,error:m.error?m.error.code:null});')
   assert(runtime.Window.Get('selectionFailure')==string.format('{"ready":%s,"error":%s}',tostring(step.settled.ready),if step.settled.error then tostring(step.settled.error)else'null'))
   if step.settled.error then assert(#requests==loads,'Empty/invalid URL cannot reach the audio adapter')else assert(#requests==loads+1,'Every explicit src write/load selects again')end
  end
  finish()
 end
 local function pendingSetup(run)
  run('globalThis.m=new Audio();globalThis.one="one.ogg";globalThis.two="two.ogg";'..eventSetup..'globalThis.playOutcome="pending";globalThis.s=document.createElement("source");s.src=one;m.defaultPlaybackRate=1.25;m.playbackRate=1.5;m.currentTime=5;')
 end
 local function pendingCompare(runtime,run,step,label,compareImmediateNetwork)
  run('events.length=0;'..step.action..';window.pendingImmediate=JSON.stringify({selected:m.currentSrc===""?"empty":"other",paused:m.paused,time:m.currentTime,rate:m.playbackRate,outcome:playOutcome});window.pendingNetwork=m.networkState;')
  local raw=step.immediate
  assert(runtime.Window.Get('pendingImmediate')==string.format('{"selected":%q,"paused":%s,"time":%s,"rate":%s,"outcome":%q}',raw.selected,tostring(raw.paused),tostring(raw.time),tostring(raw.rate),raw.outcome),label..': pending play retains its pre-selection cursor and rate')
  if compareImmediateNetwork then assert(runtime.Window.Get('pendingNetwork')==raw.network)end
  compare(runtime,run,step.settled,label)
  run('window.pendingOutcome=playOutcome;window.pendingTime=m.currentTime;')
  assert(runtime.Window.Get('pendingOutcome')==step.settled.outcome and runtime.Window.Get('pendingTime')==5,label..': original play outcome and cursor survive source selection')
 end
 do
  local runtime,run,_,finish,requests=realm();pendingSetup(run)
  for _,step in fixture.selection.empty.steps do pendingCompare(runtime,run,step,fixture.selection.empty.name,true)end
  assert(#requests==1 and requests[1].Raw=='one.ogg');finish()
 end
 for _,case in fixture.selection.boundaries do
  local runtime,run,_,finish,requests=realm();pendingSetup(run)
  -- Chromium's same-task insertion reports immediate NETWORK_LOADING. Only
  -- settled network and immediate promise/cursor/rate are compared here.
  pendingCompare(runtime,run,case.steps[1],case.name,case.name~='same-task source insertion retains pending play')
  assert(#requests==1 and requests[1].Raw=='one.ogg');finish()
 end
 for _,case in fixture.promises.cases do
  local runtime,run,_,finish=realm()
  run('globalThis.m=new Audio();m.muted=true;globalThis.one="one.ogg";globalThis.two="two.ogg";'..eventSetup..'globalThis.playOutcome="pending";globalThis.markers=[];'..(if case.mode=='empty'then''else'm.src=one;'))
  if case.mode~='empty'then run('m.play().catch(()=>{});');if case.mode=='paused'then run('m.pause();')end end
  local step=case.steps[1];run('events.length=0;'..step.action..';window.promiseImmediate=playOutcome;')
  assert(runtime.Window.Get('promiseImmediate')==step.immediate.outcome)
  run('window.promiseResult=JSON.stringify({outcome:playOutcome,markers:markers.join(","),selected:m.currentSrc==="https://media.invalid/source/one.ogg"?"one":m.currentSrc===""?"empty":"other",paused:m.paused,network:m.networkState});')
  local raw=step.settled
  local expected=string.format('{"outcome":%q,"markers":%q,"selected":%q,"paused":%s,"network":%s}',raw.outcome,table.concat(raw.markers,','),raw.selected,tostring(raw.paused),tostring(raw.network))
  assert(runtime.Window.Get('promiseResult')==expected,case.name..': load settles the original queued outcome before later microtasks\nexpected '..expected..'\nactual '..tostring(runtime.Window.Get('promiseResult')))
  -- These controls compare Promise settlement, not all discarded media events.
  finish()
 end
 for _,case in fixture.starts.cases do
  local runtime,run,_,finish,requests=realm();pendingSetup(run);run('m.muted=true;m.preload="none";')
  if case.mode=='pending'then run('m.play().then(()=>playOutcome="played",e=>playOutcome=e.name);')end
  local node=runtime.DOM.Unwrap(runtime.Window.Get('m'));local r=node.AudioResourceState
  assert(r.DefaultStart==5 and r.Position==0 and r.Ready==0,'Early currentTime is stored independently of the actual playback position')
  for _,step in case.steps do
   run('events.length=0;'..step.action..';window.startImmediate=JSON.stringify({time:m.currentTime,rate:m.playbackRate,network:m.networkState,ready:m.readyState,paused:m.paused,outcome:playOutcome});')
   local raw=step.immediate
   local expected=string.format('{"time":%s,"rate":%s,"network":%s,"ready":%s,"paused":%s,"outcome":%q}',tostring(raw.time),tostring(raw.rate),tostring(raw.network),tostring(raw.ready),tostring(raw.paused),raw.outcome)
   assert(runtime.Window.Get('startImmediate')==expected,case.name..': default start must survive an explicit load before metadata')
   compare(runtime,run,step.settled,case.name..' / '..step.name)
   run('window.startSettled=JSON.stringify({time:m.currentTime,ready:m.readyState,outcome:playOutcome});')
   raw=step.settled;local time=if case.mode=='pending'then 5 else raw.time
   assert(runtime.Window.Get('startSettled')==string.format('{"time":%s,"ready":%s,"outcome":%q}',tostring(time),tostring(raw.ready),raw.outcome),case.name..': bounded start-time/metadata/promise result')
  end
  if r.Ready==0 then assert(#requests==0 and r.Position==0,'None/no-source early positions cannot load or mutate the actual cursor')
  else
   assert(#requests==1 and r.DefaultStart==0 and r.Position==(if case.name=='late metadata clamps and consumes default start'then 20 elseif case.name=='negative early seek is consumed at metadata'then 0 else 5),'Metadata consumes the pending default start once and clamps it to duration')
   run('m.load();window.afterConsumed=m.currentTime;')
   assert(runtime.Window.Get('afterConsumed')==0 and r.DefaultStart==0 and r.Position==0,'A consumed default start cannot leak into a later explicit load')
  end
  finish()
 end
 do
  local runtime,run,pump,finish,requests,handles=realm('<!doctype html><body><audio id=m preload=none src="one.ogg"></audio></body>',false)
  run('var m=document.getElementById("m");m.currentTime=25;m.preload="auto";')
  local node=runtime.DOM.Unwrap(runtime.Window.Get('m'));local r=node.AudioResourceState
  assert(#requests==1 and r.Ready==0 and r.DefaultStart==25 and r.Position==0 and handles[1].Settings.currentTime==nil,'Early seek is retained while metadata is delayed, without sending a premature adapter seek')
  run('m.load();window.delayedStart=m.currentTime;')
  assert(#requests==2 and runtime.Window.Get('delayedStart')==25,'Full load retains an unconsumed early default start')
  handles[1].Notify({Kind='loaded',Generation=requests[1].Generation,Duration=20});pump()
  assert(r.Ready==0 and r.DefaultStart==25,'Old metadata cannot consume a newer generation default start')
  handles[1].Notify({Kind='loaded',Generation=requests[2].Generation,Duration=20});pump()
  assert(r.Ready==4 and r.DefaultStart==0 and r.Position==20 and handles[1].Settings.currentTime==20,'Current metadata consumes/clamps the default start exactly once')
  run('m.src="two.ogg";m.currentTime=5;m.src="http://[";window.failedStart=m.currentTime;')
  assert(runtime.Window.Get('failedStart')==5 and r.DefaultStart==5 and r.Ready==0 and #requests==2,'Obsolete/invalid same-task selections retain an unconsumed early start without reaching the adapter')
  run('m.src="two.ogg";')
  assert(#requests==3);handles[1].Notify({Kind='loaded',Generation=requests[3].Generation,Duration=20});pump()
  assert(r.DefaultStart==0 and r.Position==5 and r.Error==runtime.VM.Model.Null,'A later valid explicit selection consumes the retained early start after an error');finish()
 end
 do
  -- Hold the adapter's loaded/playing notifications before their queued Play
  -- settlement task, then load. This is the exact previously losing path.
  local runtime,run,pump,finish,requests,handles=realm('<!doctype html><body><audio id=m src="one.ogg"></audio></body>',false)
  local function newestTask()local id=0;for key in runtime.EventLoop.Tasks do id=math.max(id,key)end;return id end
  local function invokeTask(id)
   local loop=runtime.EventLoop
   assert(id and id>0);local record=loop.Tasks[id];assert(record);loop.Tasks[id]=nil;loop.TaskCount-=1;record.Handler();loop:Checkpoint()
  end
  assert(runtime:Run('var m=document.getElementById("m");window.playOutcome="pending";window.markers=[];window.playingCount=0;m.addEventListener("playing",()=>playingCount++);m.play().then(()=>{playOutcome="played";markers.push("fulfilled")},e=>{playOutcome=e.name;markers.push("rejected")});'))
  local playingTask;local nativePlay=handles[1].Play
  handles[1].Play=function(self,intent)nativePlay(self,intent);playingTask=newestTask()end
  handles[1].Notify({Kind='loaded',Generation=requests[1].Generation,Duration=20});invokeTask(newestTask());invokeTask(playingTask)
  local r=runtime.DOM.Unwrap(runtime.Window.Get('m')).AudioResourceState
  assert(r.Playing and #r.Plays==0 and #r.Settlements==1,'The controlled adapter has queued a successful original Play settlement')
  assert(runtime:Run('m.load();queueMicrotask(()=>markers.push("marker"));'))
  assert(runtime.Window.Get('playOutcome')=='played'and #r.Settlements==0,'Explicit load fulfills the queued success before changing its generation')
  run('window.settlementOrder=markers.join(",");')
  assert(runtime.Window.Get('settlementOrder')=='fulfilled,marker'and runtime.Window.Get('playingCount')==0 and r.Paused,'Old playing task is inert after its load-owned settlement')
  pump();finish()
 end
 for _,case in fixture.cases do
  local runtime,run,_,finish,requests,handles=realm();setup(run,case.mode)
  for _,step in case.steps do
   local loads=#requests;local node=runtime.DOM.Unwrap(runtime.Window.Get('m'));local generation=node.AudioResourceState.Generation;local selectedBefore=node.AudioResourceState.Network~=0
   local action=step.action:gsub('await m%.play%(%)','m.play().catch(()=>{})')
   run('events.length=0;'..action..';window.immediatePaused=m.paused;')
   if step.immediate.paused~=step.settled.paused then assert(runtime.Window.Get('immediatePaused')==step.immediate.paused,case.name..': removal pause must wait for stable state')end
   local selected=compare(runtime,run,step.settled,case.name..' / '..step.name)
   if not selected then assert(#requests==loads and(not selectedBefore or node.AudioResourceState.Generation==generation),case.name..': retained actions cannot reload/invalidate the selected resource')end
   if step.settled.time>=3 then assert(runtime.Window.Get('lifecycleTime')==3,case.name..': retained playback cursor')end
  end
  local selectedNode=runtime.DOM.Unwrap(runtime.Window.Get('m'));local sessions=0
  for _,handle in handles do if handle.Node==selectedNode then sessions+=1 end end
  assert(sessions==1,case.name..': one session is retained for the selected audio node');finish()
 end
 for _,case in fixture.hints.cases do
  local runtime,run,_,finish,requests,handles=realm('<!doctype html><body><audio id=m muted></audio></body>');setup(run,'direct',case.raw)
  assert(#requests==0 and #handles==0,'The engine None hint defers loading its selected resource')
  for _,step in case.steps do
   local node=runtime.DOM.Unwrap(runtime.Window.Get('m'));local generation=node.AudioResourceState.Generation
   run('events.length=0;'..step.action:gsub('await m%.play%(%)','m.play().catch(()=>{})'))
   compare(runtime,run,step.settled,case.name..' / '..step.name)
   if step.name~='explicit load selects child'then assert(node.AudioResourceState.Generation==generation,'Hint resume preserves selected resource generation')end
  end
  assert(#requests==2 and requests[1].Raw=='one.ogg'and requests[2].Raw=='two.ogg'and #handles==1,'Only explicit load switches from the retained resource to the DOM child');finish()
 end
 do
  local runtime,run,_,finish,requests=realm('<!doctype html><body><audio id=m preload=none src="one.ogg"></audio></body>')
  run('var m=document.getElementById("m");m.removeAttribute("src");m.play().catch(()=>{});')
  assert(#requests==1 and requests[1].Raw=='one.ogg'and runtime.DOM.Unwrap(runtime.Window.Get('m')).AudioResourceState.Playing,'Deferred Play prepares its retained source even after all DOM sources disappear');finish()
 end
 do
  local runtime,run,_,finish,requests=realm('<!doctype html><body><audio id=m preload=none src="one.ogg"><source src="two.ogg"></audio></body>')
  run('var m=document.getElementById("m");m.removeAttribute("src");m.defaultPlaybackRate=1.25;m.playbackRate=1.5;m.preload="METADATA";')
  local r=runtime.DOM.Unwrap(runtime.Window.Get('m')).AudioResourceState
  assert(#requests==1 and requests[1].Raw=='one.ogg'and r.Generation==1 and r.Rate==1.5 and r.Position==0,'Optional background hint resume retains selected source, generation and live rate');finish()
 end
 do
  -- The pre-removal checkpoint must honor the current live owner document.
  local source,runSource,_,finishSource,_,handles=realm();setup(runSource,'direct')
  local destination,runDestination,_,finishDestination=realm('<!doctype html><body></body>')
  destination.VM.Global.Bindings.m={Value=source.Window.Get('m')}
  local pauses=handles[1].PauseCalls
  runDestination('document.body.append(document.adoptNode(m));')
  source.EventLoop:Checkpoint()
  assert(handles[1].Playing and handles[1].PauseCalls==pauses,'Adoption into a connected live owner skips the old owner removal pause')
  finishDestination();finishSource()
 end
 do
  -- A queued old completion cannot restart an explicitly replaced/detached load.
  local runtime,run,pump,finish,requests,handles=realm('<!doctype html><body><audio id=m src="one.ogg"></audio></body>',false)
  local first=requests[1]
  run('var m=document.getElementById("m");m.play().catch(()=>{});m.remove();m.src="two.ogg";')
  assert(#requests==2 and not handles[1].Playing)
  first.Handle.Notify({Kind='loaded',Generation=first.Generation,Duration=20});pump()
  assert(runtime.DOM.Unwrap(runtime.Window.Get('m')).AudioResourceState.Ready==0 and not handles[1].Playing,'Old resource completion is ignored after source generation changes')
  local second=requests[2];second.Handle.Notify({Kind='loaded',Generation=second.Generation,Duration=20});pump()
  assert(runtime.DOM.Unwrap(runtime.Window.Get('m')).AudioResourceState.Paused and not handles[1].Playing,'New completion cannot override the stable-removal pause');finish()
 end
 do
  local runtime,run,_,finish,_,handles=realm();setup(run,'direct')
  local node=runtime.DOM.Unwrap(runtime.Window.Get('m'));local retained=runtime.AudioElements
  runtime.DOM.Host.BeforeRemove(node,false)
  local pauses=handles[1].PauseCalls;finish();retained:AfterCheckpoint()
  assert(handles[1].PauseCalls==pauses and handles[1].DestroyCalls==1,'Disposal drops a pending stable removal without calling its destroyed adapter')
 end
 print('Audio source lifecycle: 74 native lifecycle + 10 HTTP hint + 10 selection + 4 Promise + 8 default-start transitions; retained selection, checkpoint reinsertion, owner recheck, generation and disposal passed')
end
