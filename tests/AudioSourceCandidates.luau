--!strict
return function(Parser,Runtime,Events,fixture)
 local names={
  ['404 candidate then playable source']=0,['corrupt candidate then playable source']=0,['missing empty invalid then playable']=0,
  ['false media before playable']=0,['unsupported type before playable']=0,['invalid MIME declaration still sniffed']=0,
  ['direct failure never falls back to child']=0,['all candidates failed waiting']=0,
  ['error listener inserts at candidate pointer']=0,['error listener prepends before candidate pointer']=0,
  ['waiting pointer later insertion']=2,['held failure candidate removed']=1,['held failure following candidate removed']=1,
  ['held failure candidate removed global ref']=1,['held failure candidate moved outside audio global ref']=1,
  ['held failure candidate removed mutated global ref']=1,['held failure candidate removed then reinserted global ref']=1,
  ['held failure following candidate removed then inserted at gap']=1,['all missing empty invalid wait pending']=0,
  ['audio wav declared positive']=0,['unsupported wav codec before playable']=0,['source error listener switches direct src']=0,
  ['source error listener removes all candidates']=0,['source error listener removes audio']=0,
  ['none first candidate resumes on play']=1,['none first candidate resumes on hint upgrade']=1,
  ['early cursor rate survive candidate retry']=0,['author matchMedia override is bypassed']=0,['positive media candidate']=0,
  ['foreign and nested sources do not select']=0,['source error listener explicit load cancels old loop']=0,
  ['source error listener adds another pending play']=0,['waiting pointer append after exhaustion']=1,
  ['fragment insertion after removing gap neighbor']=0,['held failure candidate reordered with moveBefore']=1,
  ['replaceChildren in source error preserves gap']=0,
 }
 assert(fixture.target.commit=='ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c'and fixture.target.sha256=='49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f')
 assert(#fixture.cases==36 and #fixture.bases==5 and #fixture.preparations.original.cases==13 and #fixture.preparations.original.bases==5 and #fixture.preparations.held.cases==11)
 for _,case in fixture.cases do assert(names[case.name]==#case.steps,'Unexpected/duplicate/resized SOURCE control: '..case.name);names[case.name]=nil end
 assert(next(names)==nil,'Required SOURCE control removed')
 local deltas={};for _,delta in fixture.deltas do assert(not deltas[delta.case]);deltas[delta.case]=delta end
 assert(#fixture.deltas==15,'Required normative counterpart removed')
 local orderingNames={['missing source error observes next selected resource']=true,['404 source error observes next selected resource']=true,
  ['error listener insertion precedes already selected source']=true,['error listener removes selected next source and appends replacement']=true,
  ['error listener replaces children after next source selected']=true,['queued qualification errors survive ordinary candidate advances']=true,
  ['source error direct reset invalidates selection continuation']=true,['source error explicit load invalidates selection continuation']=true}
 assert(#fixture.ordering.cases==8 and #fixture.orderingProjections==8)
 local projections={};local rawDeltas=0
 for _,p in fixture.orderingProjections do assert(orderingNames[p.case]and not projections[p.case]);projections[p.case]=p;if p.rawDelta then rawDeltas+=1 end end
 assert(rawDeltas==6,'The HTTP-failure ordering deltas must stay explicit')
 for _,case in fixture.ordering.cases do
  assert(orderingNames[case.name]);orderingNames[case.name]=nil;local projection=projections[case.name]
  assert(projection.sourceLines[1]==39026 and projection.stableStateLines[1]==123740)
  local expected=if case.name=='queued qualification errors survive ordinary candidate advances'then 6 elseif case.name=='missing source error observes next selected resource'or case.name=='404 source error observes next selected resource'then 2 else 4
  assert(#case.ordering==expected,'Native handler inventory changed')
  assert(case.ordering[1].currentSrc:match('([^/]+)$')==(if projection.rawDelta then'404.wav'else projection.handlerSuffix),'Raw qualification/HTTP ordering evidence changed')
 end;assert(next(orderingNames)==nil)
 local function realm(automatic,disposeOnSourceError,traceAttempts)
  local events=Events.new(error);local handles,requests,traces={},{},{};local adapter={Alive=true}
  function adapter:CanRenderSourceType(value,parsed)
   if parsed.Essence=='audio/x-no-such'or value:find('unrecognized',1,true)then return false end
   return if parsed.Essence=='audio/wav'then true else nil
  end
  function adapter:Open(node,notify)
   local h={Alive=true,Node=node,Notify=notify,Settings={},Position=0,Playing=false,DestroyCalls=0}
   function h:Set(key,value)assert(self.Alive);self.Settings[key]=value;if key=='currentTime'then self.Position=value end end
   function h:Select(_,raw,generation)self.Raw,self.Generation=raw,generation end
   function h:Load(url,raw,generation)
    assert(self.Alive);self.Generation=generation;table.insert(requests,{URL=url,Raw=raw,Generation=generation,Handle=self})
    local name=raw:match('([^/]+)$')
    if automatic~=false and name~='hold.wav'then self.Notify({Kind=if name=='404.wav'or name=='corrupt.wav'then'error'else'loaded',Generation=generation,Code=4,Duration=20})end
   end
   function h:Snapshot()return {Position=self.Position}end
   function h:Pause()self.Playing=false end
   function h:Play(intent)self.Playing=true;self.Notify({Kind='playing',Generation=self.Generation,Intent=intent})end
   function h:Reset(generation)self.Generation=generation;self.Position=0 end
   table.insert(handles,h);return h
  end
  function adapter:Destroy()self.Alive=false;for _,h in handles do assert(h.Alive);h.Alive=false;h.DestroyCalls+=1 end end
  local runtime
  local settings={URL='https://sources.invalid/index.html',Events=events,AudioAdapter=adapter,ResourceViewport=function()return {Width=800,Height=600,Environment={Pointer='fine',PreferredColorScheme='light'}}end,Schedule=function()end,ApplyChanges=function()return false end}
  if disposeOnSourceError or traceAttempts then settings.AudioEmitEvent=function(node,kind)
   if node.Name=='source'and kind=='error'then
    local attempts={};for _,request in requests do table.insert(attempts,request.URL:match('([^/]+)$'))end
    table.insert(traces,{Target=node.Attributes.id,Current=runtime.DOM.Unwrap(runtime.Window.Get('m')).AudioResourceState.Current,Attempts=attempts})
   end
   events:Emit(node,kind,{}, {Bubbles=false,Cancelable=false})
   if disposeOnSourceError and node.Name=='source'and kind=='error'then runtime:Destroy()end
  end end
  runtime=Runtime.new(Parser.parseDocument('<!doctype html><body><audio id=m muted preload=auto controls></audio></body>'),settings)
  local function pump()for _=1,16 do runtime:PumpTasks();runtime.EventLoop:Checkpoint()end end
  local function run(code)local ok,message=runtime:Run(code);assert(ok,tostring(message));pump();assert(#runtime.Diagnostics==0,table.concat(runtime.Diagnostics,'\n'))end
  local function finish()runtime:Destroy();events:Destroy();for _,h in handles do assert(h.DestroyCalls==1)end end
  runtime:Start();pump()
  run([=[globalThis.m=document.getElementById('m');globalThis.base='https://sources.invalid/';globalThis.events=[];globalThis.outcome='pending';globalThis.make=(id,src,attrs={})=>{const s=document.createElement('source');s.id=id;if(src!==null)s.setAttribute('src',src);for(const [k,v]of Object.entries(attrs))s.setAttribute(k,v);s.addEventListener('error',e=>events.push({target:s.id,type:e.type,trusted:e.isTrusted,bubbles:e.bubbles,cancelable:e.cancelable}));return s};globalThis.play=()=>m.play().then(()=>outcome='played',e=>outcome=e.name);for(const type of ['loadstart','loadedmetadata','play','playing','waiting','error','abort','emptied'])m.addEventListener(type,e=>events.push({target:'media',type:e.type,trusted:e.isTrusted}));]=])
  return runtime,run,pump,finish,adapter,requests,handles,traces
 end
 local function sourceErrors(raw)local out={};for _,e in raw.events do if e.target~='media'and e.type=='error'then table.insert(out,e.target)end end;return out end
 local function state(runtime,run,raw,label,override)
  local suffix=raw.currentSrc:match('([^/]+)$')or'';local network,ready,errorCode,outcome,paused=raw.network,raw.ready,raw.error,raw.outcome,raw.paused
  if override then suffix=override.suffix or suffix;network=override.network or network;ready=override.ready or ready;outcome=override.outcome or outcome;paused=if override.paused~=nil then override.paused else paused end
  -- Dedicated direct failure's Chrome paused value remains a separate open axis.
  local checkPaused=label~='direct failure never falls back to child'
  run('window.sourceState=JSON.stringify({suffix:m.currentSrc.split("/").pop(),network:m.networkState,ready:m.readyState,error:m.error?m.error.code:null,outcome});window.sourcePaused=m.paused;window.sourceTime=m.currentTime;window.sourceRate=m.playbackRate;')
  local expected=string.format('{"suffix":%q,"network":%s,"ready":%s,"error":%s,"outcome":%q}',suffix,tostring(network),tostring(ready),if errorCode then tostring(errorCode)else'null',outcome)
  assert(runtime.Window.Get('sourceState')==expected,label..'\nexpected '..expected..'\nactual '..tostring(runtime.Window.Get('sourceState')))
  if checkPaused then assert(runtime.Window.Get('sourcePaused')==paused,label..': paused result')end
  assert(runtime.Window.Get('sourceRate')==raw.rate,label..': fallback cannot reset the live rate')
  if raw.time>=5 then assert(runtime.Window.Get('sourceTime')==5,label..': fallback retains default start/cursor')end
 end
 for _,case in fixture.cases do
  local runtime,run,pump,finish,_,requests,handles=realm();run(case.action)
  local node=runtime.DOM.Unwrap(runtime.Window.Get('m'));local r=node.AudioResourceState;local initialEpoch=r.SelectionEpoch
  if case.held then
   assert(#requests==1 and requests[1].Raw=='hold.wav');run(case.steps[1].action)
   local request=requests[1];request.Handle.Notify({Kind='error',Generation=request.Generation,Code=4});pump()
   if case.name=='held failure candidate removed then reinserted global ref'then
    assert(#requests==2 and requests[2].Raw=='hold.wav');requests[2].Handle.Notify({Kind='error',Generation=requests[2].Generation,Code=4});pump()
   end
  end
  local finalRaw=if #case.steps>0 and case.steps[#case.steps].settled then case.steps[#case.steps].settled else case.settled
  local delta=deltas[case.name];local errors=if delta and delta.targetSourceErrors then delta.targetSourceErrors else sourceErrors(finalRaw)
  local initialOverride=if delta and delta.targetState then delta.targetState else nil
  state(runtime,run,case.settled,case.name,initialOverride)
  if not case.held then for _,step in case.steps do
   run(step.action)
   local overlay=if case.name=='waiting pointer later insertion'then(if step.name=='prepend before exhausted pointer'then{suffix='404.wav',network=3,ready=0,outcome='pending'}else{suffix='two.wav',network=1,ready=4,outcome='played'})elseif delta and delta.targetContinuation then delta.targetContinuation else nil
   state(runtime,run,step.settled,case.name..' / '..step.name,overlay)
  end end
  run('window.sourceErrors=events.filter(e=>e.target!=="media").map(e=>e.target).join(",");window.sourceStarts=events.filter(e=>e.target==="media"&&e.type==="loadstart").length;window.sourceEventFlags=events.filter(e=>e.target!=="media").every(e=>e.trusted&&!e.bubbles&&!e.cancelable);')
  assert(runtime.Window.Get('sourceErrors')==table.concat(errors,','),case.name..': SOURCE error targets/order '..tostring(runtime.Window.Get('sourceErrors')))
  assert(runtime.Window.Get('sourceEventFlags'),case.name..': SOURCE errors are trusted/nonbubbling/noncancelable')
  local expectedRequests={}
  if delta and delta.targetRequests then expectedRequests=delta.targetRequests else for _,request in case.requests do table.insert(expectedRequests,request.path:match('([^/]+)$'))end end
  local actualRequests={};for _,request in requests do table.insert(actualRequests,request.URL:match('([^/]+)$'))end
  assert(table.concat(actualRequests,',')==table.concat(expectedRequests,','),case.name..': ordered attempts '..table.concat(actualRequests,','))
  local starts=0;local last=if #case.steps>0 and case.steps[#case.steps].settled then case.steps[#case.steps].settled else case.settled
  for _,e in last.events do if e.target=='media'and e.type=='loadstart'then starts+=1 end end
  if delta and delta.targetLoadstarts then starts=delta.targetLoadstarts end
  assert(runtime.Window.Get('sourceStarts')==starts,case.name..': selection loadstart count')
  if not case.name:find('switches direct',1,true)and not case.name:find('explicit load',1,true)then assert(r.SelectionEpoch==initialEpoch,'Fallback/waiting resume cannot replace its selection epoch')end
  assert(#handles<=1,'Candidates reuse one handle');finish()
 end
 for _,case in fixture.ordering.cases do
  local runtime,run,pump,finish,_,requests,_,traces=realm(nil,false,true);local projection=projections[case.name]
  run([=[globalThis.order=[];globalThis.observe=label=>{const snapshot=()=>({label,suffix:m.currentSrc.split('/').pop(),network:m.networkState,ready:m.readyState,paused:m.paused,outcome});order.push(snapshot());queueMicrotask(()=>order.push({...snapshot(),label:label+':microtask'}));};]=])
  run(case.action)
  local function attempts()local out={};for _,request in requests do table.insert(out,request.URL:match('([^/]+)$'))end;return table.concat(out,',')end
  assert(attempts()==table.concat(projection.beforeReleaseRequests,','),case.name..': IO started before held response release '..attempts())
  assert(#traces>0 and traces[1].Current:match('([^/]+)$')==projection.handlerSuffix,case.name..': next currentSrc selected before SOURCE error dispatch')
  local before=if case.name=='missing source error observes next selected resource'or case.name=='queued qualification errors survive ordinary candidate advances'then'hold.wav'else'404.wav,hold.wav'
  assert(table.concat(traces[1].Attempts,',')==before,case.name..': next IO starts before the actual SOURCE event handler')
  run('window.handlerSuffixes=order.map(x=>x.suffix).join(",");window.handlerNetworks=order.map(x=>x.network).join(",");')
  local count=if case.name=='queued qualification errors survive ordinary candidate advances'then 6 elseif case.name=='missing source error observes next selected resource'or case.name=='404 source error observes next selected resource'then 2 else 4
  if case.name=='source error direct reset invalidates selection continuation'or case.name=='source error explicit load invalidates selection continuation'then
   assert(runtime.Window.Get('handlerSuffixes')=='hold.wav,hold.wav,hold.wav,two.wav',case.name..': listener microtasks bracket the explicit replacement selection '..tostring(runtime.Window.Get('handlerSuffixes')))
   assert(runtime.Window.Get('handlerNetworks')=='2,3,3,2',case.name..': replacement fetch begins between the listener microtasks '..tostring(runtime.Window.Get('handlerNetworks')))
  else
   assert(runtime.Window.Get('handlerSuffixes')==string.rep('hold.wav,',count-1)..'hold.wav',case.name..': handler plus listener microtask observe the selected resource')
   assert(runtime.Window.Get('handlerNetworks')==string.rep('2,',count-1)..'2',case.name..': next attempt is loading at event time')
  end
  local held
  for _,request in requests do if request.Raw=='hold.wav'then held=request;break end end
  assert(held,'The normative continuation selected the retained next candidate')
  held.Handle.Notify({Kind='error',Generation=held.Generation,Code=4});pump()
  local raw=case.afterRelease or case.settled;state(runtime,run,raw,case.name,projection.final)
  assert(attempts()==table.concat(projection.requests,','),case.name..': attempt order after held failure '..attempts())
  run('window.orderedSourceErrors=events.filter(e=>e.target!=="media").map(e=>e.target).join(",");')
  assert(runtime.Window.Get('orderedSourceErrors')==table.concat(projection.sourceErrors,','),case.name..': queued error retains candidate across generation changes/removal')
  finish()
 end
 do
  local runtime,run,_,finish,adapter,requests=realm()
  function adapter:CanLoad(raw)return if raw=='unmapped.wav'then false else nil end
  run('m.preload="none";m.append(make("missing","unmapped.wav"),make("good","one.wav"));')
  assert(#requests==0,'None hint precedes definitive host availability checks')
  local node=runtime.DOM.Unwrap(runtime.Window.Get('m'));local epoch=node.AudioResourceState.SelectionEpoch
  run('play();')
  assert(#requests==1 and requests[1].Raw=='one.wav'and node.AudioResourceState.SelectionEpoch==epoch,'Unavailable candidate fails in order without list preselection')
  run('window.unavailable=events.filter(e=>e.target==="missing").length;')
  assert(runtime.Window.Get('unavailable')==1);finish()
 end
 do
  local runtime,run,pump,finish,_,requests,handles=realm(false)
  run('m.currentTime=5;m.playbackRate=1.5;m.append(make("a","one.wav"),make("b","two.wav"));play();')
  local first=requests[1];first.Handle.Notify({Kind='error',Generation=first.Generation,Code=4});first.Handle.Notify({Kind='loaded',Generation=first.Generation,Duration=20});pump();assert(#requests==2)
  first.Handle.Notify({Kind='loaded',Generation=first.Generation,Duration=20});first.Handle.Notify({Kind='error',Generation=first.Generation,Code=4});pump()
  local r=runtime.DOM.Unwrap(runtime.Window.Get('m')).AudioResourceState
  assert(r.Ready==0 and r.DefaultStart==5 and #requests==2,'Stale metadata/error cannot consume default start or advance candidate pointer')
  requests[2].Handle.Notify({Kind='loaded',Generation=requests[2].Generation,Duration=20});pump()
  assert(r.Ready==4 and r.Position==5 and r.Rate==1.5 and handles[1].Playing)
  requests[2].Handle.Notify({Kind='error',Generation=requests[2].Generation,Code=3});pump()
  assert(#requests==2 and r.Error~=runtime.VM.Model.Null,'Failure after usable metadata cannot fall back to another SOURCE');finish()
 end
 do
  local runtime,run,pump,finish,_,requests=realm(false)
  run('m.append(make("a","one.wav"),make("b","two.wav"));play();')
  local retained=runtime.AudioElements;local first=requests[1]
  first.Handle.Notify({Kind='error',Generation=first.Generation,Code=4})
  finish();retained:AfterCheckpoint()
  assert(#requests==1,'Disposal prevents queued SOURCE error/continuation IO');assert(not runtime.Alive)
 end
 do
  local runtime,run,_,finish,_,requests=realm(nil,true)
  run('m.append(make("a","404.wav"),make("b","one.wav"));play();')
  assert(not runtime.Alive and #requests==2,'Stable-state continuation starts the next attempt before the error task; disposal prevents later work');finish()
 end
 do
  local runtime,run,_,finish,_,requests=realm()
  run('const s=document.createElementNS("http://www.w3.org/1999/xhtml","h:source");s.src="one.wav";m.append(s);play();')
  assert(#requests==1 and requests[1].Raw=='one.wav','Prefixed HTML expanded names participate as SOURCE candidates');finish()
 end
 print('Audio SOURCE candidates: 36 raw controls plus 8 task/microtask controls, 15 main and 6 ordering deltas, ordered attempts, gap updates, pure media/type policy, None resume, pending Plays/cursor, epoch races and disposal passed')
end
