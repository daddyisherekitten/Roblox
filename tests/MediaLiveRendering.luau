--!strict
-- Native content-attribute evidence is separate from this deterministic mapped
-- asset backend. Fake GUI/native events prove routing, identity and scheduling,
-- not Roblox Studio video pixels or source identity in payload-free signals.
return function(Parser,Node,Events,FormModel,loadMediaRuntime,MediaBox,loadRenderTree,HTMLScripts,loadWordLayout,loadBlockLayout,Dirty,Controller,reference)
 local checks,states,races,reviewControls=0,0,0,0
 local function check(value,label)checks+=1;assert(value,label)end
 local names={'playing initial','controls remove','controls restore','loop add','loop remove','preload NONE','preload whitespace','autoplay add','autoplay remove while playing','runtime muted preference','defaultMuted add','defaultMuted remove','same raw src write','restore playback','remove src while playing','different raw src write','empty src','missing src'}
 local inventory={};check(#reference.cases==36,'Native live inventory 36')
 for i,c in reference.cases do local wanted=names[(i-1)%18+1];check(c.name==wanted and c.tag==(if i<=18 then 'audio'else 'video'),'Native named live state '..i);check(not inventory[c.tag..':'..c.name],'Duplicate native state');inventory[c.tag..':'..c.name]=c end
 local batchNames={'same set then remove','new set then remove','set remove set'}
 check(#reference.batches==3,'Native batch inventory');for i,c in reference.batches do check(c.name==batchNames[i],'Named native batch '..i);check(c.immediate.paused and c.immediate.time==0 and c.immediate.ready==0 and c.value.rate==1,'Native batched src activation')end
 for _,tag in {'audio','video'}do
  for _,name in {'controls remove','controls restore','loop add','loop remove','preload NONE','preload whitespace','autoplay add','autoplay remove while playing','defaultMuted add','defaultMuted remove','remove src while playing'}do
   local c=inventory[tag..':'..name];check(not c.value.paused and c.value.time>=1 and c.value.volume==.4 and c.value.rate==1.5,'Native non-source playback invariant '..tag..' '..name)
   check(#c.value.events==0,'Native non-source activation events '..tag..' '..name)
  end
  check(inventory[tag..':preload NONE'].value.preload=='none','ASCII casefold native hint')
  check(not inventory[tag..':defaultMuted add'].value.muted and inventory[tag..':defaultMuted add'].value.defaultMuted,'Native default mute preserves runtime preference')
  for _,name in {'same raw src write','different raw src write','empty src'}do local c=inventory[tag..':'..name];check(c.immediate.paused and c.immediate.time==0 and c.immediate.ready==0 and c.value.rate==1,'Native src set resets state '..tag..' '..name)end
 end
 local function signal()
  local entries={};local s={}
  function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
  function s:Fire(...)for _,e in table.clone(entries)do if e[1].Connected then e[2](...)end end end
  function s:Count()local n=0;for _,e in entries do if e[1].Connected then n+=1 end end;return n end
  function s:Snapshot()local result={};for _,e in entries do if e[1].Connected then table.insert(result,e[2])end end;return result end
  return s
 end
 local faces={};local overrides={['Layout/FontProfiles']={face=function(f,w,v)local key=tostring(f)..':'..tostring(w)..':'..tostring(v);faces[key]=faces[key]or{Family=f,Weight=w,Style=v};return faces[key]end},['Layout/TextMeasure']={measure=function(t,_,size)return{X=#t*size/2,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local function mount(modern,controls,preload,autoplay)
  local focused,objects,queue,waiting=nil,{},{},{};local factory={};local nativeEvents={}
  function factory.create(class,parent,props)
   local gui=table.clone(props or{});gui.ClassName,gui.Parent=class,parent;if gui.Visible==nil then gui.Visible=true end
   gui.AbsolutePosition,gui.AbsoluteSize=Vector2.new(0,0),Vector2.new(800,600);if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0)end
   gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local signals,attrs={},{}
   function gui:GetPropertyChangedSignal(k)signals[k]=signals[k]or signal();return signals[k]end
   function gui:GetAttributeChangedSignal(k)return self:GetPropertyChangedSignal('attribute:'..k)end
   function gui:SetAttribute(k,v)attrs[k]=v end;function gui:GetAttribute(k)return attrs[k]end
   function gui:IsA(k)return k==class or k=='GuiObject'or(k=='LayerCollector'and class=='ScreenGui')end
   function gui:IsFocused()return focused==self end
   function gui:CaptureFocus()if focused==self then return end;local old=focused;focused=self;if old then old.FocusLost:Fire(false)end;self.Focused:Fire()end
   function gui:ReleaseFocus()if focused~=self then return end;focused=nil;self.FocusLost:Fire(false)end
   function gui:ConnectionCount()local n=self.Focused:Count()+self.FocusLost:Count()+self.InputBegan:Count();for _,s in signals do n+=s:Count()end;return n end
   function gui:Destroy()check(not self.Destroyed,'Retained GUI disposed twice');self.Destroyed=true;self:ReleaseFocus();self.Parent=nil end
   if class=='VideoFrame'then
    gui.Playing=false;gui.TimePosition=0;gui.TimeLength=12;gui.Loaded=signal();gui.Played=signal();gui.Paused=signal();gui.Ended=signal();gui.PlayCalls=0;gui.PauseCalls=0
    function gui:Play()self.PlayCalls+=1;self.Playing=true;self.Played:Fire()end
    function gui:Pause()self.PauseCalls+=1;self.Playing=false;self.Paused:Fire()end
   end
   table.insert(objects,gui);return gui
  end;factory.modifier=factory.create
  local doc=Parser.parseDocument('<!doctype html><button id="before">Before</button><video id="v" src="one.webm" muted preload="'..(preload or'none')..'" '..(if controls then 'controls 'else '')..(if autoplay then 'autoplay 'else '')..'style="display:block;width:320px;height:180px"></video><button id="after">After</button><input id="editor" tabindex="-1" value="A&#x1f600;BC"><p id="neighbor">retained neighbor</p><script>var mediaMounted=true;</script>')
  local layer=factory.create('ScreenGui',nil,{});local root=factory.create('ScrollingFrame',layer,{});root:SetAttribute('Status','ready')
  local resolver=require('Rendering/MediaSources').new(nil,{['one.webm']='1',['alias.webm']='1',['two.webm']='2'},nil)
  local tree=loadRenderTree(factory).build(doc,root,function(m)error(m)end,overrides['Layout/FontProfiles'].face,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,resolver);tree.ViewportHeight=600
  local item=assert(tree.MediaItems[1]);local node=item.Node;local oldGui,oldBox,oldFrame,oldDisplay=item.Gui,item.BoxGui,item.VideoGui,item.VideoDisplay
  local player={IsPlaying=false,IsLoaded=false,TimePosition=0,TimeLength=12,DidEnd=signal(),PlayFailed=signal(),LoadCalls=0,PlayCalls=0,PauseCalls=0,UnloadCalls=0,DestroyCalls=0}
  local playing,loaded=signal(),signal();function player:GetPropertyChangedSignal(k)return if k=='IsPlaying'then playing else loaded end
  function player:LoadAsync()self.LoadCalls+=1;if self.Delay then table.insert(waiting,coroutine.running());coroutine.yield()end;self.IsLoaded=true;loaded:Fire()end
  function player:Play()self.PlayCalls+=1;self.IsPlaying=true;playing:Fire()end
  function player:Pause()self.PauseCalls+=1;self.IsPlaying=false;playing:Fire()end
  function player:Unload()self.UnloadCalls+=1;self.IsLoaded=false end
  function player:Destroy()self.DestroyCalls+=1 end
  local made,preloads,icons={},0,0;local taskAPI={}
  function taskAPI.spawn(fn)local handle={Callback=fn};table.insert(queue,handle);return handle end
  taskAPI.defer=taskAPI.spawn;function taskAPI.cancel(h)h.Cancelled=true end
  local runService={Heartbeat=signal(),RenderStepped=signal()}
  local services={Task=taskAPI,RunService=runService,ContentProvider={PreloadAsync=function(_,list)
   if table.find(list,item.VideoGui)then preloads+=1;if item.VideoGui.Delay then table.insert(waiting,coroutine.running());coroutine.yield()end;item.VideoGui.Loaded:Fire()else icons+=1 end
  end},Content={none='content:none',fromUri=function(uri)return 'content:'..uri end},Instance={new=function(class)
   if class=='VideoPlayer'then if not modern then error('intentional VideoFrame fallback')end;return player end
   local o={ClassName=class,DestroyCalls=0};function o:Destroy()self.DestroyCalls+=1 end
   if class=='Frame'then
    o.AbsoluteSize=Vector2.new(960,540);local sizeChanged=signal()
    function o:GetPropertyChangedSignal(k)check(k=='AbsoluteSize','Fullscreen uses existing overlay size signal');return sizeChanged end
    function o:SizeConnectionCount()return sizeChanged:Count()end
   end
   table.insert(made,o);return o
  end},Input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),MouseEnabled=true,MouseIcon='',MouseIconEnabled=true},PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=os.clock,PickerLayout=layout}
  function services.Input:GetFocusedTextBox()return focused end;function services.Input:IsKeyDown()return false end;function services.Input:GetStringForKeyCode(k)return k.Name end
  local page={Alive=true,Root=root,Document=doc,DocumentURL='https://media.test/live',BaseURL='https://media.test/live',Cleanups={}}
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  local realm,pending,targets,flushing=nil,false,{},false;local arrangements=0
  local function arrange(items)arrangements+=1;Dirty.begin(tree,items);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)end
  function page:FlushScriptLayout()if flushing or not realm then return end;flushing=true;local needed,items=realm:Flush();if pending then needed=true;items=items or{};for i in targets do items[i]=true end;pending=false;table.clear(targets)end;if needed then arrange(items)end;flushing=false end
  function page:HasPendingLayout()return pending end
  arrange()
  local messages={};local stop=Controller.start(page,tree,function(_,target)pending=true;if target then targets[target]=true end end,function(m)table.insert(messages,m)end,services)
  local api=page.Media;local object=if modern then player else item.VideoGui
  tree.StructuralResourcesRemoving=function(removals)api:Remove(removals.Media or{})end
  function page:RefreshDOMResources()local changes=tree:TakeStructuralResourceChanges();api:Remove(changes.Media.Removed);api:Add(changes.Media.Added)end
  local scriptTask={delay=function(_,fn)return{Callback=fn}end,cancel=function(h)h.Cancelled=true end}
  realm=assert(HTMLScripts.start(page,tree,function()end,function(m)table.insert(messages,m)end,{JavaScriptServices={Clock=os.clock,RunService=runService,Task=scriptTask}}))
  local observer=page.Events:BeforeEmit(function(e)if e.Target==node then table.insert(nativeEvents,e.Type)end end)
  local function drain()
   for _=1,128 do if #queue==0 then return end;local h=table.remove(queue,1);if not h.Cancelled then local thread=coroutine.create(h.Callback);local ok,msg=coroutine.resume(thread);check(ok,tostring(msg))end end;error('Media task queue failed to converge')
  end
  local function settle()page:FlushScriptLayout();realm:AfterLayout();drain();page:FlushScriptLayout();check(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
  local function run(code,skipDrain)check(realm:Run(code),code);page:FlushScriptLayout();realm:AfterLayout();if not skipDrain then drain()end;check(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
  run('var m=document.getElementById("v"),one="one.webm",two="two.webm",e=document.getElementById("editor");e.focus();e.setSelectionRange(1,3,"backward")')
  local control=page.FormModel:Resolve(Node.findById(doc,'editor'));local editor=control.Item.Editor;local bindings=editor:ConnectionCount();local neighbor=tree.NodeBoxes[Node.findById(doc,'neighbor')].Gui
  local function retained(focus)
   check(tree.MediaByNode[node]==item and item.Gui==oldGui and item.BoxGui==oldBox and item.VideoGui==oldFrame and item.VideoDisplay==oldDisplay,'Live media recreated renderer objects')
   check((if modern then item.VideoPlayer else item.VideoGui)==object and not item.Gui.Destroyed,'Live media replaced native backend')
   check(tree.NodeBoxes[Node.findById(doc,'neighbor')].Gui==neighbor and not neighbor.Destroyed,'Media recreated neighbor')
   check(control.Item.Editor==editor and editor:ConnectionCount()==bindings and control.Value=='A😀BC'and control.SelectionStart==1 and control.SelectionEnd==3 and control.SelectionDirection=='backward','Media lost editor/value/UTF16 selection')
   if focus then check(focused==editor and editor.CursorPosition==2 and editor.SelectionStart==6,'Media lost editor focus/byte selection')end
   check(item.ContentWidth==320 and item.ContentHeight==180,'Media attribute update changed CSS content dimensions')
  end
  local function count()return if modern then player.LoadCalls else preloads end
  local function callbacks()return if modern then{loaded:Snapshot(),playing:Snapshot(),player.DidEnd:Snapshot(),player.PlayFailed:Snapshot()}else{item.VideoGui.Loaded:Snapshot(),item.VideoGui.Played:Snapshot(),item.VideoGui.Paused:Snapshot(),item.VideoGui.Ended:Snapshot()}end
  local function connectionCount()return if modern then loaded:Count()+playing:Count()+player.DidEnd:Count()+player.PlayFailed:Count()else item.VideoGui.Loaded:Count()+item.VideoGui.Played:Count()+item.VideoGui.Paused:Count()+item.VideoGui.Ended:Count()end
  local function resume()local thread=table.remove(waiting,1);check(thread~=nil,'Missing actual suspended backend job');local ok,msg=coroutine.resume(thread);check(ok,tostring(msg))end
  local function dispose()
   observer:Disconnect();realm:Destroy();stop();page.Alive=false;for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end;api:Destroy();drain()
   check(connectionCount()==0 and runService.Heartbeat:Count()==0 and runService.RenderStepped:Count()==0,'Disposed media retained native/frame connections')
   check(services.Input.InputBegan:Count()==0 and services.Input.InputChanged:Count()==0 and services.Input.InputEnded:Count()==0 and editor:ConnectionCount()==0,'Disposed media retained input/editor connections')
   if modern then check(player.DestroyCalls==1,'Native VideoPlayer destroyed exactly once');for _,o in made do check(o.DestroyCalls==1,'Native wire/output destroyed exactly once')end end
   check(not realm.Alive and not realm.EventLoop.Alive and not realm:HasPending(),'Disposed media runtime retained jobs')
  end
  return{Run=run,Drain=drain,Settle=settle,Retained=retained,Dispose=dispose,Resume=resume,Page=page,Tree=tree,Item=item,Node=node,Object=object,Player=player,Frame=item.VideoGui,Waiting=waiting,Events=nativeEvents,Callbacks=callbacks,Connections=connectionCount,Count=count,Input=services.Input,Focused=function()return focused end,Allocated=function()return #objects end,Arrangements=function()return arrangements end}
 end
 for _,modern in {true,false}do for _,initialControls in {true,false}do
  local h=mount(modern,initialControls);local api,item,obj=h.Page.Media,h.Item,h.Object
  api:Play('v');h.Drain();check(item.Playing and obj.PlayCalls==1,'Actual Play uses injected task queue')
  api:SetVolume('v',.4);if modern then api:SetRate('v',1.5)end;obj.TimePosition=1
  local loadCount,connections=h.Count(),h.Connections();local originalCallbacks=h.Callbacks();local controls=item.ControlsGui
  for _,name in names do
   local c=inventory['video:'..name];table.clear(h.Events)
   local expectedRate=if modern then 1.5 else 1
   if name=='playing initial'then
   elseif name=='runtime muted preference'then api:SetVolume('v',.4)
   elseif name=='restore playback'then api:Play('v');h.Drain();obj.TimePosition=1;if modern then api:SetRate('v',1.5)end
   else h.Run(c.action)end
   h.Retained(true);states+=1
   if name=='controls restore'then controls=item.ControlsGui;check(controls~=nil and item.Controls and controls.Visible,'Controls created/revealed on retained VIDEO')end
   if name=='controls remove'then
    check(not item.Controls and(not item.ControlsGui or not item.ControlsGui.Visible),'Controls removal hides retained subtree')
    check(MediaBox.action(item,Vector2.new(1,1))=='none'and not api:Key(item,'Space'),'Absent controls block actions and keyboard')
   end
   if name=='loop add'or name=='loop remove'then check((if modern then obj.Looping else obj.Looped)==c.value.loop,'Live looping backend flag')end
   if name=='preload NONE'then check(item.Preload=='none','Live ASCII casefold preload')end
   if name=='preload whitespace'then check(item.Preload~='none','Live preload must not trim whitespace')end
   if name=='defaultMuted add'or name=='defaultMuted remove'then check(not item.Muted and item.Volume==.4 and obj.Volume==.4,'defaultMuted does not reset runtime mute/volume')end
   if name=='same raw src write'or name=='different raw src write'or name=='empty src'then
    check(not item.Playing and item.CurrentTime==0 and item.PlaybackRate==1,'Live explicit src set resets source state')
    check(item.SourceGeneration~=nil,'Explicit setter increments source generation')
   elseif name=='remove src while playing'then
    check(item.Playing and item.SelectedSource=='one.webm'and item.Source=='rbxassetid://1'and obj.TimePosition==1 and item.PlaybackRate==expectedRate,'Removal preserves selected resource/playback')
   elseif name=='missing src'then check(item.LoadFailed and item.Source==nil,'Removal after failed empty source does not restart load')
   elseif name~='restore playback'then
    check(item.Playing and obj.TimePosition==1 and item.Volume==.4 and item.PlaybackRate==expectedRate,'Warm non-source state '..name)
    check(h.Count()==loadCount and h.Connections()==connections,'Warm flag changed load/registration/connections '..name)
    local active=h.Callbacks();for i,list in active do for j,fn in list do check(originalCallbacks[i][j]==fn,'Warm flag rebound native callbacks '..name)end end
   end
   if item.ControlsGui and controls then check(item.ControlsGui==controls,'Controls allocated more than once')end
  end
  local controlsAllocated=h.Allocated();local retainedControls=item.ControlsGui
  for _,code in {'m.controls=false','m.controls=true','m.controls=false','m.controls=true'}do h.Run(code);h.Retained(true);check(item.ControlsGui==retainedControls and h.Allocated()==controlsAllocated,'Repeated controls toggle allocates no additional GUI')end
  h.Run('m.setAttribute("src","one.webm");m.setAttribute("preload","none");m.removeAttribute("autoplay")');api:Play('v');h.Drain();obj.TimePosition=2
  local g=item.SourceGeneration;h.Run('m.setAttribute("src","alias.webm")');check(item.Source=='rbxassetid://1'and item.SourceGeneration==g+1 and not item.Playing,'Different raw src mapping to same asset reloads')
  h.Run('m.setAttribute("src","one.webm")');g=item.SourceGeneration;h.Run('m.setAttribute("src","one.webm")');check(item.SourceGeneration==g+1,'Same raw setter survives ordinary DOM no-change coalescing')
  for _,c in reference.batches do
   h.Run('m.src=one;m.preload="auto"');api:Play('v');h.Drain();obj.TimePosition=1;if modern then api:SetRate('v',1.5)end
   h.Run(c.action);check(not item.Playing and item.CurrentTime==0 and item.PlaybackRate==1,'Mounted batched activation '..c.name)
   check((item.Source~=nil)==(c.immediate.src~=nil)and not item.LoadFailed,'Batch final selection '..c.name)
  end
  -- Actual controller tab candidates observe the current Controls field.
  h.Run('m.controls=true;document.getElementById("before").focus()');local event={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Tab};h.Input.InputBegan:Fire(event);h.Input.InputEnded:Fire(event);h.Settle();check(h.Page.FormModel:GetActiveElement()==h.Node,'Revealed VIDEO controls Tab candidate')
  h.Run('m.controls=false;document.getElementById("before").focus()');h.Input.InputBegan:Fire(event);h.Input.InputEnded:Fire(event);h.Settle();check(h.Page.FormModel:GetActiveElement()==Node.findById(h.Page.Document,'after'),'Hidden VIDEO controls skipped by actual Tab')
  h.Run('e.focus();e.setSelectionRange(1,3,"backward");document.body.append(document.createElement("span"))');h.Retained(true)
  h.Dispose()
 end end
 -- Queued and genuinely suspended native host operations. Source identity is
 -- carried by our jobs/old callback closures; Roblox's newly delivered native
 -- signals contain no originating-source payload and remain a host limitation.
 for _,modern in {true,false}do
  for _,kind in {'queued source swap','inflight source swap','autoplay cancellation','pending explicit Pause','dispose inflight','remove inflight','queued old native callbacks','reentrant loadstart','reentrant metadata','reentrant play','dispose metadata','warm Pause source change','warm Pause disposal','warm Play disposal','api Pause disposal','inflight seek source change'}do
   local h=mount(modern,true);local api,item,obj=h.Page.Media,h.Item,h.Object
   if kind=='warm Pause source change'or kind=='warm Pause disposal'or kind=='warm Play disposal'or kind=='api Pause disposal'then
    api:Play('v');h.Drain();if kind=='warm Play disposal'then api:Pause('v')end
    local changed,disposed,latePaint=false,false,0;local originalPaint=MediaBox.paint
    MediaBox.paint=function(target)if target==item and disposed then latePaint+=1 end;return originalPaint(target)end
    local eventName=if kind=='warm Play disposal'then 'play'else 'pause'
    local observer=h.Page.Events:BeforeEmit(function(e)
     if e.Target==h.Node and e.Type==eventName and not changed then changed=true
      if kind=='warm Pause source change'then h.Run('m.src=two;m.autoplay=true;m.preload="auto"')else api:Destroy();disposed=true end
     end
    end)
    if kind=='warm Play disposal'then api:Play('v')elseif kind=='api Pause disposal'then api:Pause('v')else check(api:Key(item,'Space'),'Actual warm Pause toggle')end
    observer:Disconnect();MediaBox.paint=originalPaint
    check(changed,'Warm native event must invoke reentrant change '..kind)
    if disposed then check(latePaint==0,'Old native Pause/Play completion painted after disposal '..kind)else check(item.Playing and item.SelectedSource=='two.webm','Old warm Pause completion overwrote new automatic playback')end
   elseif kind=='inflight seek source change'then
    obj.Delay=true;api:Play('v');h.Drain();check(#h.Waiting==1,'Suspended seek source load');obj.TimePosition=4;h.Run('m.src=two')
    check(api:Key(item,'Right')and obj.TimePosition==4,'Source-changing keyboard seek wrote old backend metadata')
    item.ControlsGui.AbsolutePosition=Vector2.new(0,0);item.ControlsGui.AbsoluteSize=Vector2.new(320,44)
    api:Begin(item,Vector2.new(60,10));api:Move(Vector2.new(70,10));api:Finish(item,Vector2.new(70,10));check(obj.TimePosition==4,'Source-changing control seek wrote old backend metadata')
    obj.Delay=false;h.Resume();h.Drain();check(not item.Playing and item.CurrentTime==0 and item.Duration==0,'Source-changing seek recovery reset')
   elseif kind=='reentrant loadstart'or kind=='reentrant metadata'or kind=='dispose metadata'then
    local changed=false;local eventName=if kind=='reentrant loadstart'then 'loadstart'else 'loadedmetadata'
    local observer=h.Page.Events:BeforeEmit(function(e)
     if e.Target==h.Node and e.Type==eventName and not changed then changed=true;if kind=='dispose metadata'then api:Destroy()else h.Run('m.src=two',true)end end
    end)
    api:Play('v');h.Drain();observer:Disconnect()
    check(changed and not item.Playing and obj.PlayCalls==0 and not item.LoadInProgress,'Reentrant source/disposal cancels native operation '..kind)
    check(h.Count()==(if kind=='reentrant loadstart'then 0 else 1),'Native call before/after reentrant event guard '..kind)
    if kind~='dispose metadata'then check(item.Duration==0 and item.CurrentTime==0 and not item.LoadFailed,'Reentrant event preserves current source reset')end
   elseif kind=='reentrant play'then
    api:Play('v');h.Drain();api:Pause('v')
    local changed=false;local observer=h.Page.Events:BeforeEmit(function(e)if e.Target==h.Node and e.Type=='play'and not changed then changed=true;h.Run('m.src=two',true)end end)
    check(api:Key(item,'Space'),'Actual warm toggle method');observer:Disconnect();h.Drain()
    check(changed and not item.Playing and not item.HasPlayed and item.CurrentTime==0,'Warm toggle must not overwrite reentrant source reset')
   elseif kind=='queued source swap'then
    api:Play('v');h.Run('m.src=two',true);h.Drain();check(h.Count()==0 and not item.Playing,'Old queued Play cannot load current source implicitly');api:Play('v');h.Drain();check(item.Playing and h.Count()==1,'Current explicit Play recovery')
   elseif kind=='queued old native callbacks'then
    api:Play('v');h.Drain();local old=h.Callbacks();h.Run('m.src=two');table.clear(h.Events);for _,list in old do for _,fn in list do fn('captured old failure')end end
    check(#h.Events==0 and not item.Playing and not item.Ended and not item.LoadFailed and item.Duration==0,'Captured old source signal callbacks are inert')
   else
    obj.Delay=true
    if kind=='autoplay cancellation'then h.Run('m.autoplay=true')else api:Play('v');h.Drain()end
    check(#h.Waiting==1 and item.LoadInProgress,'Actual backend must be suspended')
    if kind=='inflight source swap'then
     local old=h.Callbacks();h.Run('m.src=two;m.preload="auto"');check(item.Duration==0 and item.CurrentTime==0 and not item.Playing,'Source reset blocks stale native metadata reads');api:State('v');check(item.Duration==0,'State does not republish old TimeLength')
     table.clear(h.Events);for _,list in old do for _,fn in list do fn('old failure')end end;check(#h.Events==0,'Old native callback inert during source change')
     obj.Delay=false;h.Resume();h.Drain();check(h.Count()==2 and item.Duration==12 and not item.Playing and not item.LoadInProgress,'Stale load releases old job then current source loads once')
    elseif kind=='autoplay cancellation'then
     h.Run('m.autoplay=false');obj.Delay=false;h.Resume();h.Drain();check(obj.PlayCalls==0 and not item.PendingAutoplay and not item.Playing,'Removed autoplay cancels only pending automatic play')
     api:Play('v');h.Drain();local pauses=obj.PauseCalls;h.Run('m.autoplay=true;m.autoplay=false');check(item.Playing and obj.PauseCalls==pauses,'Autoplay removal does not pause established playback')
    elseif kind=='pending explicit Pause'then
     api:Pause('v');obj.Delay=false;h.Resume();h.Drain();check(obj.PlayCalls==0 and not item.Playing,'Pause cancels actual pending explicit Play')
    elseif kind=='dispose inflight'then
     local old=h.Callbacks();h.Dispose();table.clear(h.Events);obj.Delay=false;h.Resume();for _,list in old do for _,fn in list do fn('disposed failure')end end;h.Drain();check(obj.PlayCalls==0 and #h.Events==0 and not item.LoadFailed and not item.Loading,'Disposed continuation and native callbacks remain inert');races+=1;continue
    elseif kind=='remove inflight'then
     h.Run('m.remove()');table.clear(h.Events);obj.Delay=false;h.Resume();h.Drain();check(obj.PlayCalls==0 and #h.Events==0 and h.Tree.MediaByNode[h.Node]==nil,'Removed media cancels actual native load completion')
    end
   end
   races+=1;h.Dispose()
  end
 end
 -- Real fullscreen entry/exit through the runtime with a fixed host overlay.
 -- No AbsoluteSize event is fired during live controls writes: those writes
 -- must arrange at the retained overlay size themselves, including first use.
 for _,modern in {true,false}do for _,initialControls in {true,false}do
  local h=mount(modern,initialControls);local api,item,obj=h.Page.Media,h.Item,h.Object
  api:Play('v');h.Drain();local parent,position,size=item.Gui.Parent,item.Gui.Position,item.Gui.Size
  local connections,loadCount,callbacks=h.Connections(),h.Count(),h.Callbacks()
  check(api:EnterFullscreen('v')and item.Fullscreen,'Actual fullscreen entry');local overlay=item.Gui.Parent
  check(overlay.AbsoluteSize.X==960 and overlay.AbsoluteSize.Y==540 and overlay:SizeConnectionCount()==1,'Fullscreen host size/resize registration')
  local originalArrange,normalArranges=MediaBox.arrange,0
  MediaBox.arrange=function(target)if target==item then normalArranges+=1 end;return originalArrange(target)end
  local controls=item.ControlsGui
  for _,enabled in {false,true,false,true}do
   h.Run('m.controls='..tostring(enabled));h.Retained(true)
   if controls then check(item.ControlsGui==controls,'Fullscreen controls retain GUI')elseif enabled then controls=item.ControlsGui;check(controls~=nil,'First controls creation during fullscreen')end
   for _,gui in {item.Gui,item.BoxGui,item.VideoGui,item.VideoDisplay}do check(gui.Size[1]==960 and gui.Size[2]==540,'Live controls preserve fullscreen surface size')end
   check(item.ControlsWidth==960 and item.ControlsHeight==(if enabled then 44 else 0),'Live fullscreen controls geometry')
   if item.ControlsGui then check(item.ControlsGui.Size[1]==960 and item.ControlsGui.Size[2]==(if enabled then 44 else 0)and item.ControlsGui.Position[2]==(if enabled then 496 else 540),'Fullscreen controls use overlay dimensions without resize event')end
   check(item.Fullscreen and item.Gui.Parent==overlay and overlay:SizeConnectionCount()==1 and obj.PlayCalls==1 and item.Playing,'Fullscreen controls preserve playback/overlay connection')
   check(h.Count()==loadCount and h.Connections()==connections,'Fullscreen controls preserve native registration/load count')
   local active=h.Callbacks();for i,list in active do for j,fn in list do check(callbacks[i][j]==fn,'Fullscreen controls preserve native callbacks')end end
  end
  MediaBox.arrange=originalArrange;check(normalArranges==0,'Fullscreen controls must not transiently arrange at CSS dimensions')
  check(api:ExitFullscreen()and not item.Fullscreen and item.Gui.Parent==parent and item.Gui.Position==position and item.Gui.Size==size,'Fullscreen exit restores original outer geometry')
  for _,gui in {item.BoxGui,item.VideoGui,item.VideoDisplay}do check(gui.Size[1]==320 and gui.Size[2]==180,'Fullscreen exit restores normal CSS surface dimensions')end
  check(item.ControlsWidth==320 and item.ControlsHeight==44 and item.ControlsGui.Size[1]==320 and item.ControlsGui.Position[2]==136,'Fullscreen exit restores normal controls geometry')
  check(overlay.DestroyCalls==1 and overlay:SizeConnectionCount()==0,'Fullscreen overlay disposed once and resize disconnected');h.Retained(true)
  reviewControls+=1;h.Dispose()
 end end
 for _,modern in {true,false}do for _,kind in {'removed item Key','page dead Key','destroyed runtime Key'}do
  local h=mount(modern,true);local api,item,obj=h.Page.Media,h.Item,h.Object
  if kind=='removed item Key'then h.Run('m.remove()')elseif kind=='page dead Key'then h.Page.Alive=false else api:Destroy()end
  local loadCount,playCount,events,latePaint=h.Count(),obj.PlayCalls,#h.Events,0;local originalPaint=MediaBox.paint
  MediaBox.paint=function(target)if target==item then latePaint+=1 end;return originalPaint(target)end
  local ok,result=pcall(function()return api:Key(item,'Space')end);MediaBox.paint=originalPaint
  check(ok and result==false,'Inactive retained item Key returns false '..kind)
  check(h.Count()==loadCount and obj.PlayCalls==playCount and #h.Events==events and latePaint==0,'Inactive Key performs no load/play/events/paint '..kind)
  if kind=='page dead Key'then h.Page.Alive=true end
  reviewControls+=1;h.Dispose()
 end end
 print('Media live rendering: '..states..' mounted native sequence states, '..races..' queued/inflight controls, '..reviewControls..' fullscreen/inactive-Key controls, '..checks..' assertions; retained objects/playback/default mute, source epochs, controls Tab and cleanup passed')
end
