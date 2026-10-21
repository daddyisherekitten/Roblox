--!strict
-- Root-authorized separately named CurrentBackend counterpart. Only the final
-- cross-live-realm request-list assertion changes; all raw rows/actions and
-- getter/URL assertions are retained. Original source SHA 74a671a8f3f1dd328d958d0f5d050945f46b12c2856f0c4d0bddfbdfc6c09830
return function(Parser,Runtime,Events,fixture)
 local expectedCases={
  ['audio defaults and shared descriptors']=true,
  ['audio content attribute states']=true,
  ['audio setters and conversion']=true,
  ['audio borrowed accessors and branding']=true,
  ['audio foreign content attributes']=true,
  ['audio URL base mutations and adoption']=true,
  ['video defaults and shared descriptors']=true,
  ['video content attribute states']=true,
  ['video setters and conversion']=true,
  ['video borrowed accessors and branding']=true,
  ['video foreign content attributes']=true,
  ['video URL base mutations and adoption']=true,
  ['audio src Unicode reflection and invalid URL fallback']=true,
  ['audio borrowed setters missing false and throwing conversion']=true,
  ['video src Unicode reflection and invalid URL fallback']=true,
  ['video borrowed setters missing false and throwing conversion']=true,
  ['Audio factory keeps DOMString content attributes']=true,
 }
 local seen={}
 for _,case in fixture.cases do assert(expectedCases[case.name]and not seen[case.name],'Unexpected/duplicate media fixture case: '..case.name);seen[case.name]=true end
 for name in expectedCases do assert(seen[name],'Required media fixture case missing: '..name)end
 assert(fixture.profile.preloadDefault=='metadata','This bounded engine UA reflection profile selects metadata for missing/invalid preload')
 local rawRows={['defaults and shared descriptors']=7,['content attribute states']=41,['setters and conversion']=65,['borrowed accessors and branding']=84,['foreign content attributes']=7,['URL base mutations and adoption']=7}
 local originalRows=0
 for _,case in fixture.cases do
  local events=Events.new(error);local runtime=Runtime.new(Parser.parseDocument(case.html),{URL='https://media.invalid/root/index.html',Events=events,Schedule=function()end,ControlAdapter={}})
  local expectedRows=rawRows[case.name:gsub('^audio ',''):gsub('^video ','')]
  if expectedRows then
   assert(runtime:Run('window.nativeRowCount=JSON.parse('..string.format('%q',case.expected)..').length'))
   assert(runtime.Window.Get('nativeRowCount')==expectedRows,'Required original native rows were removed: '..case.name)
   originalRows+=expectedRows
  end
  local ok,message=runtime:Run('window.mediaReflectionResult='..(case.targetAction or case.action))
  assert(ok,case.name..': '..tostring(message))
  local expected=case.targetExpected or case.expected;local actual=runtime.Window.Get('mediaReflectionResult')
  if actual~=expected then print('Media expected',expected);print('Media actual',actual)end
  assert(actual==expected,case.name..'\nexpected '..expected..'\nactual '..tostring(actual))
  assert(#runtime.Diagnostics==0,case.name..': '..table.concat(runtime.Diagnostics,' | '))
  runtime:Destroy();events:Destroy()
 end
 assert(originalRows==422,'All twelve original native cases and their 422 raw rows are required')
 local function realmFixture(html,url)
  local requests,handles={},{};local events=Events.new(error);local adapter={Alive=true}
  function adapter:Open(node,notify)
   local h={Node=node,Notify=notify,Settings={},Position=0,Playing=false,PlayCalls=0,PauseCalls=0,ResetCalls=0}
   function h:Set(key,value)self.Settings[key]=value;if key=='currentTime'then self.Position=value end end
   function h:Snapshot()return {Position=self.Position}end
   function h:Load(address,raw,generation)self.Generation=generation;table.insert(requests,{URL=address,Raw=raw,Generation=generation,Handle=self})end
   function h:Pause()self.PauseCalls+=1;self.Playing=false end
   function h:Play(intent)self.PlayCalls+=1;self.Playing=true;self.Notify({Kind='playing',Generation=self.Generation,Intent=intent})end
   function h:Reset()self.ResetCalls+=1 end
   table.insert(handles,h);return h
  end
  function adapter:Destroy()self.Alive=false end
  local runtime=Runtime.new(Parser.parseDocument(html or'<!doctype html><body></body>'),{URL=url or'https://media.invalid/source/index.html',Events=events,AudioAdapter=adapter,Schedule=function()end,ApplyChanges=function()return false end})
  local function pump()for _=1,16 do runtime:PumpTasks();runtime.EventLoop:Checkpoint()end end
  local function run(source)local ok,message=runtime:Run(source);assert(ok,tostring(message));pump();assert(#runtime.Diagnostics==0,table.concat(runtime.Diagnostics,' | '))end
  local function finish()runtime:Destroy();events:Destroy();assert(not adapter.Alive)end
  runtime:Start();pump();return runtime,run,pump,finish,requests,handles
 end
 do
  -- successful and failed reflected conversions preserve the existing audio
  -- make-before-conversion timing. Video reflection never creates audio state.
  local runtime,run,_,finish,requests,handles=realmFixture()
  run([=[
window.a=document.createElement('audio');a.defaultMuted=true;
window.b=document.createElement('audio');try{b.preload={toString(){b.setAttribute('muted','');throw new Error('failed conversion')}}}catch(e){}
window.c=document.createElement('audio');try{c.src=Symbol('invalid')}catch(e){}
window.v=document.createElement('video');v.src='movie.webm';v.preload='NONE';v.crossOrigin=false;v.autoplay=true;v.loop=true;v.controls=true;v.defaultMuted=true;
for(const key of ['src','preload','crossOrigin','autoplay','loop','controls','defaultMuted'])Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,key).get.call(v);
window.disposedGet=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,'src').get;
window.disposedSet=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,'src').set;
for(const [key,type] of [['currentSrc','string'],['paused','boolean'],['muted','boolean']]){const value=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,key).get.call(v);if(typeof value!==type)throw new Error('Shared HTMLMediaElement member must accept genuine VIDEO')}
]=])
  for _,name in {'a','b','c'}do local state=runtime.DOM.Unwrap(runtime.Window.Get(name)).AudioResourceState;assert(state and not state.Muted,'Audio lazy state must exist before reflected conversion')end
  local video=runtime.Window.Get('v');assert(runtime.DOM.Unwrap(video).AudioResourceState==nil and #requests==0 and #handles==0,'Video reflection must not create an audio resource or adapter session')
  local getter,setter=runtime.Window.Get('disposedGet'),runtime.Window.Get('disposedSet');finish()
  assert(not pcall(getter.Call,{},video)and not pcall(setter.Call,{'later.webm'},video),'Retained shared accessors reject disposed realms')
 end
 for _,raw in {'none','NONE','NoNe'}do
  local runtime,run,_,finish,requests,handles=realmFixture('<!doctype html><audio id="a" preload="'..raw..'" src="tone.ogg"></audio>')
  assert(#requests==0 and #handles==0,'ASCII-case-insensitive none defers the existing audio load')
  run("var a=document.getElementById('a');a.preload='NoNe';a.controls=true;")
  assert(#requests==0 and #handles==1,'Changing none casing cannot schedule a media load; controls may attach the retained owner')
  run("a.preload='METADATA';")
  assert(#requests==1,'A non-none background hint uses the existing audio load profile')
  finish()
 end
 do
  local _,_,_,finish,requests=realmFixture('<!doctype html><audio preload=" none " src="tone.ogg"></audio>')
  assert(#requests==1,'Whitespace around none is an invalid token, not the None state');finish()
 end
 do
  -- This activation arm is separate from reflection: removing src retains an
  -- active resource, while setting even the same src invokes a fresh load.
  local runtime,run,pump,finish,requests,handles=realmFixture('<!doctype html><audio id="a" src="tone.ogg"><source src="child.ogg"></audio>')
  local first=requests[1];first.Handle.Notify({Kind='loaded',Generation=first.Generation,Duration=12});pump()
  run("var a=document.getElementById('a');a.play().catch(()=>{});a.currentTime=5;a.playbackRate=1.5;")
  assert(handles[1].Playing)
  local pauses=handles[1].PauseCalls
  run("a.removeAttribute('src');window.retained=[a.currentSrc,a.paused,a.currentTime,a.playbackRate].join('|');")
  assert(runtime.Window.Get('retained')=='https://media.invalid/source/tone.ogg|false|5|1.5'and #requests==1 and handles[1].PauseCalls==pauses and handles[1].Playing,'Removing src retains selected source, playback cursor and rate')
  run("a.load();")
  assert(#requests==2 and requests[2].Raw=='child.ogg'and requests[2].URL=='https://media.invalid/source/child.ogg','Explicit load after src removal selects child sources')
  local second=requests[2];second.Handle.Notify({Kind='loaded',Generation=second.Generation,Duration=12});pump()
  run("a.src='tone.ogg';")
  local third=requests[3];third.Handle.Notify({Kind='loaded',Generation=third.Generation,Duration=12});pump()
  run("a.play().catch(()=>{});a.currentTime=6;a.playbackRate=1.5;a.setAttribute('src','tone.ogg');window.reset=[a.paused,a.currentTime,a.playbackRate].join('|');")
  assert(#requests==4 and runtime.Window.Get('reset')=='true|0|1','Setting identical src resets the selected resource through the existing load algorithm')
  run("a.removeAttribute('src');a.firstChild.remove();a.load();window.emptySource=a.currentSrc;")
  assert(#requests==4 and runtime.Window.Get('emptySource')=='https://media.invalid/source/tone.ogg'and handles[1].ResetCalls>0,'No-mode load retains currentSrc while resetting the native resource')
  run("window.emptyState=[a.paused,a.currentTime,a.playbackRate,a.networkState,a.readyState].join('|');")
  assert(runtime.Window.Get('emptyState')=='true|0|1|0|0'and not handles[1].Playing,'No-mode load resets playback and returns NETWORK_EMPTY without clearing currentSrc')
  finish()
 end
 do
  local runtime,run,pump,finish,requests,handles=realmFixture('<!doctype html><base href="https://media.invalid/a/"><audio id="a" src="tone.ogg"></audio>')
  assert(requests[1].URL=='https://media.invalid/a/tone.ogg')
  run("var a=document.getElementById('a');document.querySelector('base').href='https://media.invalid/changed/';window.baseRead=[a.src,a.currentSrc].join('|');")
  assert(runtime.Window.Get('baseRead')=='https://media.invalid/changed/tone.ogg|https://media.invalid/a/tone.ogg'and #requests==1 and #handles==1,'A src getter uses current base without selecting/reloading the active resource')
  run("var other=document.implementation.createHTMLDocument('other');other.head.innerHTML='<base href=\"https://media.invalid/detached/\">';other.adoptNode(a);window.adoptedRead=a.src;a.load();")
  local archivedDetachedExpression=[==[assert(runtime.Window.Get('adoptedRead')=='https://media.invalid/detached/tone.ogg'and #requests==2 and requests[2].URL=='https://media.invalid/detached/tone.ogg','A new explicit audio load uses its current detached owner base')]==]
  assert(archivedDetachedExpression~="","Original strict expectation is preserved beside this named counterpart")
  assert(runtime.Window.Get('adoptedRead')=='https://media.invalid/detached/tone.ogg','Historical document counterpart: adopted reflected getter remains B')
  assert(#requests==2 and requests[2].URL=='https://media.invalid/changed/tone.ogg','Historical document counterpart: explicit load uses last-src-write A with its current canonical base')
  run("other.querySelector('base').href='https://media.invalid/next/';a.src='second.ogg';")
  assert(#requests==3 and requests[3].URL=='https://media.invalid/next/second.ogg','Source writes use the current adopted owner base')
  finish()
 end
 do
  local source,runSource,_,finishSource,requestsSource=realmFixture('<!doctype html><base href="https://media.invalid/source/"><body></body>')
  local destination,runDestination,_,finishDestination,requestsDestination=realmFixture('<!doctype html><base href="https://media.invalid/destination/"><body></body>')
  runSource("window.moved=document.createElement('audio');moved.preload='none';moved.src='tone.ogg';window.borrowed=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,'src').get;window.sourceRead=[[moved.src,borrowed.call(moved)]];")
  for _,key in {'moved','borrowed','sourceRead'}do destination.VM.Global.Bindings[key]={Value=source.Window.Get(key)}end
  runDestination("document.body.append(document.adoptNode(moved));sourceRead.push([moved.src,borrowed.call(moved)]);document.querySelector('base').href='https://media.invalid/changed/';sourceRead.push([moved.src,borrowed.call(moved)]);window.crossRead=JSON.stringify(sourceRead);")
  assert(destination.Window.Get('crossRead')==fixture.crossRealm,'Borrowed getters follow the current live destination owner bridge')
  assert(#requestsSource==0 and #requestsDestination==0,'Cross-realm src getters do not open/load an audio resource')
  runSource("Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,'preload').set.call(moved,'auto');HTMLMediaElement.prototype.load.call(moved);")
  local archivedCrossExpression=[==[assert(#requestsSource==1 and requestsSource[1].URL=='https://media.invalid/changed/tone.ogg','A borrowed audio activation through the original realm still reads the current destination owner base')]==]
  assert(archivedCrossExpression~="","Original strict expectation is preserved beside this named counterpart")
  runDestination("window.historicalGetter=moved.src;")
  assert(destination.Window.Get('historicalGetter')=='https://media.invalid/changed/tone.ogg','Historical document counterpart: borrowed/current getter remains live B')
  local archivedBackendExpression=[==[assert(#requestsSource==1 and requestsSource[1].URL=='https://media.invalid/source/tone.ogg','Historical document counterpart: explicit source-realm load uses last-src-write A')]==]
  assert(archivedBackendExpression~='', 'Original strict backend-list expectation retained beside named counterpart')
  assert(#requestsSource==0 and #requestsDestination==1,'Current backend counterpart: original-realm activation reaches current owner B only')
  assert(requestsDestination[1].URL=='https://media.invalid/source/tone.ogg','Historical source document URL remains A independently of current backend B')
  finishDestination();finishSource()
 end
 print('Media reflection: native/normative fixture, shared brands/conversions, audio lazy state, case-insensitive none, source activation, live/detached owner bases and disposal passed')
end
