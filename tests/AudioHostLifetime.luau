--!strict
-- Compact held-native ownership probe with controlled Sound services/paint.
-- actualPaint=true exercises the separate behavior inventory with real
-- MediaBox; GC remains in a fresh compact process with the same budget.
-- This does not prove all Page/Realm/WorkContext contexts or native GPU release.
return function(AudioHost,edgeOnly,actualPaint)
 local checks=0;local failures={};local caseNames={}
 local function check(value,label)checks+=1;assert(value,label)end
 local function case(name)check(not caseNames[name],'Unique bounded AudioHost control '..name);caseNames[name]=true end
 local function pressure(predicate)
  for _=1,128 do if predicate()then return true end;local temporary=table.create(2048);for i=1,2048 do temporary[i]={i,i+1}end end
  return predicate()
 end
 local function signal()
  local entries={};local s={}
  function s:Connect(fn)local c={Connected=true,Callback=fn};function c:Disconnect()self.Connected=false;self.Callback=nil end;table.insert(entries,c);return c end
  function s:Fire(...)for _,c in table.clone(entries)do if c.Connected then c.Callback(...)end end end
  function s:Count()local n=0;for _,c in entries do if c.Connected then n+=1 end end;return n end
  return s
 end
 local function fixture(options)
  options=options or{};local queue,threads,sounds={}, {},{};local counts={Created=0,Destroyed=0,Preloads=0,Bindings=0,StaleWrites=0,Publications=0,Paints=0,Stops=0};local heartbeat=signal()
  local function sound()
   counts.Created+=1;local id='';local o={Playing=false,IsLoaded=false,TimePosition=0,TimeLength=12,Ended=signal(),DidLoop=signal(),DestroyCalls=0}
   setmetatable(o,{__index=function(_,k)if k=='SoundId'then return id end end,__newindex=function(self,k,v)if k=='SoundId'then id=v;counts.Bindings+=1;if self.Destroyed then counts.StaleWrites+=1 end else rawset(self,k,v)end end})
   function o:Stop()counts.Stops+=1;self.Playing=false;self.TimePosition=0;if options.OnStop then options.OnStop(self)end end
   function o:Pause()self.Playing=false end
   function o:Destroy()check(not self.Destroyed,'Session-owned Sound is destroyed exactly once');self.Destroyed=true;self.DestroyCalls+=1;self.Parent=nil;counts.Destroyed+=1;if options.OnDestroy then options.OnDestroy(self)end end
   table.insert(sounds,o);return o
  end
  local services={Task={spawn=function(fn)table.insert(queue,fn)end},Instance={new=function(kind)check(kind=='Sound','Only a Sound is allocated');return sound()end},RunService={Heartbeat=heartbeat},ContentProvider={PreloadAsync=function(_,targets,report)
   counts.Preloads+=1;check(#targets==1,'Existing session Sound is the sole preload target')
   if options.OnPreload then options.OnPreload(targets[1])end
   if options.Hold then table.insert(threads,coroutine.running());coroutine.yield('native-held')end
   if options.ThrowNative then error(options.NativeError,0)end
   targets[1].IsLoaded=not options.Unloaded;if report then report(targets[1].SoundId,if options.Fail then'Failure'else'Success')end
  end}}
  local function start()
   local fn=table.remove(queue,1);check(fn~=nil,'Actual native worker is queued');local thread=coroutine.create(fn);local ok,value=coroutine.resume(thread);return ok,value,thread
  end
  local function resume()
   local thread=table.remove(threads,1);check(thread~=nil,'Actual uncancellable native coroutine remains held');local ok,value=coroutine.resume(thread);return ok,value,thread
  end
  return {Options=options,Services=services,Counts=counts,Queue=queue,Threads=threads,Sounds=sounds,Heartbeat=heartbeat,Sound=sound,Start=start,Resume=resume}
 end
 local function createOwners(h,weak,keepHost,queued)
  local frame=coroutine.create(function()
   local plain={Independent=true};local cyclic={};cyclic.Self=cyclic;weak.Plain,weak.CyclicPlain=plain,cyclic
   local node={Kind='Element',Name='audio',Attributes={id='a'},Children={}}
   local root={};local page={Alive=true,Root=root,ResolveAudio=function(raw)return if raw=='one.ogg'then'rbxassetid://101'elseif raw=='two.ogg'then'rbxassetid://102'else nil end}
   local native=h.Sound();local item={Node=node,Gui={Parent=root},Sound=native,HarnessCounts=h.Counts};local tree={MediaByNode={[node]=item}};page.Tree=tree
   local host=AudioHost.new(page,tree,h.Services)
   local callback=function()check(page.Alive and not item.Destroyed,'Only a live owner may receive media notification');h.Counts.Publications+=1 end
   local session=host:Open(node,callback);check(session.Sound==native and h.Counts.Created==1,'Host adopts the already living mounted Sound without replacement')
   weak.Page,weak.Root,weak.Tree,weak.Item,weak.Node,weak.Host,weak.Session,weak.Callback=page,root,tree,item,node,host,session,callback
   session:Load('https://audio.test/one.ogg','one.ogg',1)
   if not queued then local ok,value,thread=h.Start();check(ok and value=='native-held'and coroutine.status(thread)=='suspended','Actual PreloadAsync is suspended')end
   item.Destroyed=true;page.Alive=false;host:Destroy();host:Destroy()
   check(native.DestroyCalls==1 and native.Parent==nil and item.Sound==nil and item.AudioSession==nil and node.AudioHostSession==nil,'Dispose clears mounted refs and native GUI ancestry immediately')
   check(h.Heartbeat:Count()==0 and native.Ended:Count()==0 and native.DidLoop:Count()==0,'Dispose disconnects every native callback before resume')
   check(plain.Independent and cyclic.Self==cyclic,'Independent same-age plain/cyclic controls stay alive through owner destruction')
   if keepHost then h.KeptHost=host end
  end)
  local ok,value=coroutine.resume(frame);check(ok,tostring(value));check(coroutine.status(frame)=='dead','Owner creation frame is fully terminated')
 end
 if not edgeOnly and not actualPaint then
 for _,control in {{Name='destroy held preload',Keep=false,Queued=false},{Name='retained disposed adapter',Keep=true,Queued=false},{Name='destroy queued preload',Keep=false,Queued=true}}do
  case(control.Name);local h=fixture({Hold=not control.Queued});local weak=setmetatable({},{__mode='v'})
  createOwners(h,weak,control.Keep,control.Queued)
  local keys={'Page','Root','Tree','Item','Node','Session','Callback'};if not control.Keep then table.insert(keys,'Host')end
  local function collected()for _,key in keys do if weak[key]~=nil then return false end end;return true end
  pressure(function()return weak.Plain==nil and weak.CyclicPlain==nil and collected()end);check(weak.Plain==nil and weak.CyclicPlain==nil,'Independent same-age plain/cyclic controls collect before native resume with unchanged 128x2048 budget')
  local fields={};for _,key in keys do table.insert(fields,key..'='..tostring(weak[key]==nil))end;print('AUDIO_HOST_GC_BEFORE',control.Name,table.concat(fields,','))
  if not collected()then table.insert(failures,control.Name)end
  local ok,value,thread;if control.Queued then ok,value,thread=h.Start()else ok,value,thread=h.Resume()end
  check(ok and coroutine.status(thread)=='dead',tostring(value));check(h.Counts.Created==1 and h.Counts.Destroyed==1 and h.Counts.Publications==0,'Late native completion adds no new Sound, duplicate Destroy or publication')
  check(h.Counts.Preloads==(if control.Queued then 0 else 1)and #h.Queue==0 and #h.Threads==0,'Disposed queued load starts no IO; disposed in-flight load simply returns')
  if h.KeptHost then check(not h.KeptHost.Alive,'Retained public API stays disposed')end
 end
 check(#failures==0,'AudioHost retained owners before native resume: '..table.concat(failures,', '))
 end
 local function live(options)
  local h=fixture(options);local node={Kind='Element',Name='audio',Attributes={},Children={}};local page={Alive=true,Root={},ResolveAudio=function(raw)return if raw=='one.ogg'then'rbxassetid://101'elseif raw=='two.ogg'then'rbxassetid://102'else nil end};local item={Node=node,HarnessCounts=h.Counts,PlayGui={},TimeGui={},MissingGui={}};local host=AudioHost.new(page,{MediaByNode={[node]=item}},h.Services);local events={}
  local session=host:Open(node,function(event)h.Counts.Publications+=1;table.insert(events,table.clone(event))end)
  if actualPaint then session:Attach(item)end
  h.Page,h.Node,h.Item,h.Host,h.Session,h.Events=page,node,item,host,session,events;return h
 end
 if not edgeOnly then
 do
  case('cached selection and controls');local h=live();local s=h.Session;local sound=s.Sound
  s:Load('','one.ogg',1);local ok,value=h.Start();check(ok,tostring(value));check(s.Ready and h.Counts.Preloads==1 and h.Events[1].Kind=='loaded','Current native readiness publishes once')
  s:Load('','one.ogg',2);check(#h.Queue==0 and h.Counts.Preloads==1 and s.Sound==sound,'Cached asset reuse retains Sound and does not preload')
  s:Set('currentTime',5);s:Set('volume',.4);s:Set('muted',true);check(sound.Volume==0,'Muted preference remains active');s:Set('muted',false);s:Set('playbackRate',1.5);s:Set('loop',true);s:Play(7);s:Pause();s:Play(8)
  check(sound.TimePosition==5 and sound.Playing and sound.Volume==.4 and sound.PlaybackSpeed==1.5 and sound.Looped,'TimeSound resumes selected cursor/preferences without Sound:Play reset')
  if actualPaint then check(h.Item.TimeGui.Text=='0:05 / 0:12'and h.Item.PlayGui.Text==''and h.Item.MissingGui.Visible==false,'Actual MediaBox paints retained current time/play/loading surfaces')end
  h.Heartbeat:Fire(.25);check(h.Events[#h.Events].Kind=='timeupdate','Current heartbeat retains time notification')
  local item={HarnessCounts=h.Counts};s:Detach(h.Item);s:Attach(item);check(item.Sound==sound and item.AudioSession==s and h.Counts.Created==1,'Control detach/attach retains native object')
  s:Control('volumechange',{Volume=.2,Muted=false});s:Request('play');check(h.Events[#h.Events].Kind=='control'and h.Events[#h.Events].Action=='play','Control/request contract unchanged')
  s:Select('','two.ogg',3);check(s.Asset=='rbxassetid://102'and #h.Queue==0 and h.Counts.Preloads==1,'Selection alone resolves without native preload')
  s:Reset(4);check(sound.SoundId==''and sound.TimePosition==0 and not s.Ready,'Explicit reset retains source reset behavior');h.Host:Destroy();check(sound.DestroyCalls==1,'Cached/control session owns one final native destruction')
 end
 do
  case('superseded held generation');local h=live({Hold=true});local s=h.Session;local sound=s.Sound
  s:Load('','one.ogg',1);local ok,value=h.Start();check(ok,tostring(value));s:Load('','two.ogg',2);ok,value=h.Start();check(ok,tostring(value));check(#h.Threads==2 and h.Counts.Created==1,'Two actual native operations reuse one session Sound')
  ok,value=h.Resume();check(ok,tostring(value));check(#h.Events==0 and s.Loading,'Stale completion cannot clear newer loading state or notify');ok,value=h.Resume();check(ok,tostring(value));check(#h.Events==1 and h.Events[1].Generation==2 and s.Ready and not s.Loading,'Only current generation publishes readiness');h.Host:Destroy();check(sound.DestroyCalls==1,'Old worker does not own a second destruction')
 end
 if not actualPaint then
 do
  case('weak owner heartbeat disposal');local h=fixture({Hold=true});local weak=setmetatable({},{__mode='v'})
  local frame=coroutine.create(function()
   local node={Kind='Element',Name='audio',Attributes={},Children={}};local page={Alive=true,Root={},ResolveAudio=function()return'rbxassetid://101'end};local host=AudioHost.new(page,{MediaByNode={}},h.Services)
   local callback=function()h.Counts.Publications+=1 end;local session=host:Open(node,callback);weak.Node,weak.Session,weak.Callback,weak.Plain=node,session,callback,{}
   session:Load('','one.ogg',1);local ok,value=h.Start();check(ok and value=='native-held','Weak-owner preload is genuinely held');h.KeptHost,h.LivePage=host,page
  end)
  local ok,value=coroutine.resume(frame);check(ok and coroutine.status(frame)=='dead',tostring(value))
  pressure(function()return weak.Plain==nil and weak.Node==nil end);check(weak.Plain==nil and weak.Node==nil,'Weak Owner never becomes a strong DOM keepalive')
  h.Heartbeat:Fire(.25);pressure(function()return weak.Session==nil and weak.Callback==nil end)
  check(weak.Session==nil and weak.Callback==nil and h.KeptHost.Alive and h.LivePage.Alive,'Heartbeat disposal releases only the dead-owner session before native resume')
  check(h.Counts.Destroyed==1 and h.Sounds[1].Parent==nil and h.Heartbeat:Count()==0,'Last weak-owner session disconnects heartbeat and retires native ancestry once')
  ok,value=h.Resume();check(ok and h.Counts.Destroyed==1 and h.Counts.Publications==0,tostring(value));h.KeptHost:Destroy()
 end
 end
 for _,fallback in {false,true}do
  case(if fallback then 'resolver disposal on URL fallback'else 'resolver disposal on raw source');local h=live();local s=h.Session;local sound=s.Sound;local calls=0
  h.Page.ResolveAudio=function(raw)calls+=1;if fallback and calls==1 then return nil end;h.Page.Alive=false;h.Host:Destroy();return'rbxassetid://101'end
  s:Load('https://audio.test/one.ogg','one.ogg',1)
  check(h.Counts.Preloads==0 and #h.Queue==0 and h.Counts.StaleWrites==0 and #h.Events==0 and sound.DestroyCalls==1,'Resolver reentry does not bind/start/publish after disposal');check(calls==(if fallback then 2 else 1),'Resolver guard does not call another fallback after disposal')
 end
 do
  case('preload disposal reentry');local h=live();local sound=h.Session.Sound
  h.Options.OnPreload=function()h.Page.Alive=false;h.Host:Destroy()end
  h.Session:Load('','one.ogg',1);local ok,value=h.Start();check(ok,tostring(value));check(h.Counts.Preloads==1 and #h.Events==0 and sound.DestroyCalls==1 and h.Item.Sound==nil,'Preload reentry cannot publish or destroy the session Sound twice')
 end
 do
  case('select resolver disposal');local h=live();h.Page.ResolveAudio=function()h.Page.Alive=false;h.Host:Destroy();return'rbxassetid://101'end
  h.Session:Select('','one.ogg',1);check(h.Session.Asset==nil and #h.Queue==0 and h.Counts.StaleWrites==0 and h.Counts.Destroyed==1,'Disposed Select does not publish late resolution into its session')
 end
 do
  case('availability resolver disposal');local h=live();local calls=0;h.Page.ResolveAudio=function()calls+=1;h.Page.Alive=false;h.Host:Destroy();return nil end
  check(h.Host:CanLoad('one.ogg','https://audio.test/one.ogg')==nil and calls==1,'Availability reentry returns unknown without another resolver call after disposal');check(h.Counts.Preloads==0 and h.Counts.Destroyed==1,'Capability check starts no new native work')
 end
 for _,kind in {'nil','false','table'}do
  case('native error '..kind);local token=if kind=='table'then {}elseif kind=='false'then false else nil;local h=live({ThrowNative=true,NativeError=token})
  h.Session:Load('','one.ogg',1);local ok,value=h.Start();check(ok,tostring(value));check(#h.Events==1 and h.Events[1].Kind=='error'and h.Events[1].Code==4 and h.Events[1].Message=='Roblox audio load failed: '..tostring(token or'asset unavailable'),'Native '..kind..' failure retains original media-error formatting');h.Host:Destroy();check(h.Counts.Destroyed==1,'Native error owns no additional target')
  case('notification error '..kind);h=live();h.Session.Notify=function()error(token,0)end;h.Session:Load('','one.ogg',1);ok,value=h.Start();check(not ok and value==token,'Async notification preserves original '..kind..' error identity');h.Host:Destroy();check(h.Counts.Destroyed==1 and h.Session.Notify==nil,'Throwing notification still leaves exact-once disposal/callback cleanup')
 end
 end
 if edgeOnly~='factory'then
 do
  case('same generation new attempt');local h=live({Hold=true});local s=h.Session;local sound=s.Sound
  s:Load('','one.ogg',7);local ok,value=h.Start();check(ok,tostring(value));s:Load('','two.ogg',7);ok,value=h.Start();check(ok,tostring(value))
  check(s.Generation==7 and s.Raw=='two.ogg'and s.Asset=='rbxassetid://102'and #h.Threads==2,'Same external generation starts distinct actual native attempts')
  ok,value=h.Resume();check(ok,tostring(value));check(#h.Events==0 and s.Loading and not s.Ready,'Superseded same-generation native result cannot publish or clear the new load')
  ok,value=h.Resume();check(ok,tostring(value));check(#h.Events==1 and h.Events[1].Generation==7 and s.Ready and not s.Loading and s.Raw=='two.ogg','Only newest per-attempt slot completes while preserving caller generation')
  h.Host:Destroy();check(sound.DestroyCalls==1,'Same-generation retry owns no extra native object or destruction')
 end
 end
 do
  case('factory installs newer session');local h=fixture();local node={Kind='Element',Name='audio',Attributes={},Children={}};local page={Alive=true,Root={},ResolveAudio=function()return'rbxassetid://101'end};local host=AudioHost.new(page,{MediaByNode={}},h.Services)
  local original=h.Services.Instance.new;local entered=false;local newest;local outerEvents,innerEvents=0,0;local inner=function()innerEvents+=1 end
  h.Services.Instance.new=function(kind)
   local stale=original(kind)
   if not entered then entered=true;newest=host:Open(node,inner)end
   return stale
  end
  local result=host:Open(node,function()outerEvents+=1 end)
  check(result==newest and node.AudioHostSession==newest and newest.Alive and newest.Notify==inner,'Outer factory reentry preserves newest installed session and callback')
  check(#h.Sounds==2 and h.Sounds[1].DestroyCalls==1 and h.Sounds[1].Parent==nil and h.Sounds[2].DestroyCalls==0 and newest.Sound==h.Sounds[2]and newest.Sound.Parent==page.Root,'Only stale fresh factory result is released; live newer native object remains')
  newest:Load('','one.ogg',1);local ok,value=h.Start();check(ok,tostring(value));check(innerEvents==1 and outerEvents==0 and h.Counts.Preloads==1,'Factory reentry leaves notification/native work on newest owner')
  host:Destroy();check(h.Sounds[1].DestroyCalls==1 and h.Sounds[2].DestroyCalls==1,'Final teardown preserves exact-once ownership for both distinct native objects')
 end
 if not edgeOnly then
 for _,mode in {'Load','Select','Reset'}do
  case('same generation resolver '..mode);local h=live();local s=h.Session;local resolve=h.Page.ResolveAudio;local calls=0
  h.Page.ResolveAudio=function(raw)
   calls+=1;h.Page.ResolveAudio=resolve
   if mode=='Load'then s:Load('','two.ogg',7)elseif mode=='Select'then s:Select('','two.ogg',7)else s:Reset(7)end
   return 'rbxassetid://101'
  end
  s:Load('','one.ogg',7)
  check(calls==1 and s.Generation==7 and s.Raw==(if mode=='Reset'then''else'two.ogg')and s.Asset==(if mode=='Reset'then nil else'rbxassetid://102'),'Resolver reentry preserves newest '..mode..' source/selection in same external generation')
  check(h.Counts.Bindings==(if mode=='Select'then 0 else 1)and #h.Queue==(if mode=='Load'then 1 else 0),'Outer resolver return cannot bind or enqueue the superseded source')
  if mode=='Load'then local ok,value=h.Start();check(ok,tostring(value));check(#h.Events==1 and s.Ready and not s.Loading and h.Counts.Preloads==1,'Only nested current resolver attempt completes')else check(#h.Events==0 and not s.Loading,'Nested selection/reset does not publish old readiness')end
  h.Host:Destroy();check(h.Counts.Destroyed==1,'Resolver same-generation teardown remains exact once')
 end
 for _,mode in {'Load','Select','Reset'}do
  case('same generation Stop '..mode);local h=live();local s=h.Session;local calls=0
  h.Options.OnStop=function()
   calls+=1;h.Options.OnStop=nil
   if mode=='Load'then s:Load('','two.ogg',7)elseif mode=='Select'then s:Select('','two.ogg',7)else s:Reset(7)end
  end
  s:Load('','one.ogg',7)
  check(calls==1 and s.Generation==7 and s.Raw==(if mode=='Reset'then''else'two.ogg')and s.Asset==(if mode=='Reset'then nil else'rbxassetid://102'),'Native Stop reentry preserves newest '..mode..' source in same generation')
  check(h.Counts.Bindings==(if mode=='Select'then 0 else 1)and #h.Queue==(if mode=='Load'then 1 else 0),'Outer Stop return cannot bind or enqueue superseded source')
  if mode=='Load'then local ok,value=h.Start();check(ok,tostring(value));check(#h.Events==1 and s.Ready and h.Counts.Preloads==1,'Only nested Stop attempt completes')else check(#h.Events==0 and not s.Loading,'Nested Stop selection/reset stays idle')end
  h.Host:Destroy();check(h.Counts.Destroyed==1,'Stop reentry teardown remains exact once')
 end
 do
  case('same generation Select resolver Load');local h=live();local s=h.Session;local resolve=h.Page.ResolveAudio
  h.Page.ResolveAudio=function()h.Page.ResolveAudio=resolve;s:Load('','two.ogg',7);return'rbxassetid://101'end
  s:Select('','one.ogg',7);check(s.Raw=='two.ogg'and s.Asset=='rbxassetid://102'and s.Loading and #h.Queue==1,'Outer Select resolver cannot overwrite a nested same-generation Load')
  local ok,value=h.Start();check(ok and s.Ready and h.Counts.Preloads==1,tostring(value));h.Host:Destroy()
 end
 do
  case('same generation Reset Stop Load');local h=live();local s=h.Session
  h.Options.OnStop=function()h.Options.OnStop=nil;s:Load('','two.ogg',7)end
  s:Reset(7);check(s.Raw=='two.ogg'and s.Asset=='rbxassetid://102'and s.Sound.SoundId=='rbxassetid://102'and s.Loading and #h.Queue==1,'Outer Reset Stop cannot clear nested same-generation Load')
  local ok,value=h.Start();check(ok and s.Ready and h.Counts.Preloads==1,tostring(value));h.Host:Destroy()
 end
 end
 local expected=if edgeOnly=='factory'then {'factory installs newer session'}elseif edgeOnly then {'same generation new attempt','factory installs newer session'}else {'destroy held preload','retained disposed adapter','destroy queued preload','cached selection and controls','superseded held generation','weak owner heartbeat disposal','resolver disposal on raw source','resolver disposal on URL fallback','preload disposal reentry','select resolver disposal','availability resolver disposal','native error nil','notification error nil','native error false','notification error false','native error table','notification error table','same generation new attempt','factory installs newer session'}
 if not edgeOnly then for _,name in {'same generation resolver Load','same generation resolver Select','same generation resolver Reset','same generation Stop Load','same generation Stop Select','same generation Stop Reset','same generation Select resolver Load','same generation Reset Stop Load'}do table.insert(expected,name)end end
 if actualPaint then local gc={['destroy held preload']=true,['retained disposed adapter']=true,['destroy queued preload']=true,['weak owner heartbeat disposal']=true};for i=#expected,1,-1 do if gc[expected[i]]then table.remove(expected,i)end end end
 local n=0;for _ in caseNames do n+=1 end;check(n==#expected,'Exact AudioHost bounded control inventory');for _,name in expected do check(caseNames[name],'Required bounded host control '..name)end
 print('AudioHostLifetimePrep: '..n..' bounded controls / '..checks..' assertions passed')
end
