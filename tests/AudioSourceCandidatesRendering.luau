--!strict
-- Actual mounted HTMLScripts/AudioHost path with deterministic Sound services.
-- HTTP/decoder/native pixels remain the separate raw browser evidence.
return function(Parser,Node,Events,FormModel,loadMediaRuntime,MediaBox,loadRenderTree,HTMLScripts,loadWordLayout,loadBlockLayout,Dirty,Controller,reference)
 assert(#reference.cases==36 and reference.target.commit=='ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c')
 local function signal()
  local entries={};local s={}
  function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
  function s:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
  function s:Count()local n=0;for _,entry in entries do if entry[1].Connected then n+=1 end end;return n end
  return s
 end
 local faces={};local overrides={['Layout/FontProfiles']={face=function(f,w,v)local key=tostring(f)..':'..tostring(w)..':'..tostring(v);faces[key]=faces[key]or{Family=f,Weight=w,Style=v};return faces[key]end},['Layout/TextMeasure']={measure=function(t,_,size)return{X=#t*size/2,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local checks=0;local function check(value,message)checks+=1;assert(value,message)end
 for _,mode in {'mapped failure','unavailable','resolved alias','type policy','error insertion','none unavailable Play','none unavailable Key','none unavailable pointer'}do
  local deferred=mode:find('none unavailable',1,true)~=nil
  local focused,objects,queue,sounds,preloads=nil,{},{},{},{};local factory={}
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
   function gui:Destroy()check(not self.Destroyed,'GUI disposed twice');self.Destroyed=true;self:ReleaseFocus();self.Parent=nil end
   table.insert(objects,gui);return gui
  end;factory.modifier=factory.create
  local first=if mode=='unavailable'or deferred then'missing.wav'elseif mode=='resolved alias'then'alias.wav'else'bad.wav'
  local doc=Parser.parseDocument('<!doctype html><body><button id=before>Before</button><audio id=m controls muted preload='..(if deferred then'none'else'auto')..' style="display:block;width:320px;height:54px"><source id=s1 src="'..first..'" '..(if mode=='type policy'then'type="audio/x-no-such"'else'')..'><source id=s2 src="one.wav"></audio><input id=editor tabindex=-1 value="A&#x1f600;BC"><p id=neighbor>retained neighbor</p><script>window.mountedSources=true;</script></body>')
  local root=factory.create('ScrollingFrame',factory.create('ScreenGui',nil,{}),{});root:SetAttribute('Status','ready')
  local resolver=require('Rendering/MediaSources').new({['bad.wav']='401',['one.wav']='402',['two.wav']='403'},nil,nil)
  local messages={};local tree=loadRenderTree(factory).build(doc,root,function(m)table.insert(messages,m)end,overrides['Layout/FontProfiles'].face,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,resolver);tree.ViewportHeight=600
  local item=assert(tree.MediaItems[1]);local node=item.Node;local gui,box,controls=item.Gui,item.BoxGui,item.ControlsGui
  local taskAPI={};function taskAPI.spawn(fn)local h={Callback=fn};table.insert(queue,h);return h end;taskAPI.defer=taskAPI.spawn;function taskAPI.cancel(h)h.Cancelled=true end
  local runService={Heartbeat=signal(),RenderStepped=signal()}
  local hitObjects={}
  local services={Factory=factory,Task=taskAPI,RunService=runService,Clock=os.clock,PickerLayout=layout,Input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),MouseEnabled=true,MouseIcon='',MouseIconEnabled=true},PlayerGui={GetGuiObjectsAtPosition=function()return hitObjects end}}
  function services.Input:GetFocusedTextBox()return focused end;function services.Input:IsKeyDown()return false end;function services.Input:GetStringForKeyCode(k)return k.Name end
  services.Instance={new=function(class)
   check(class=='Sound','Only a native Sound is allocated');local sound={SoundId='',Playing=false,IsLoaded=false,TimePosition=0,TimeLength=20,DestroyCalls=0,StopCalls=0,Ended=signal(),DidLoop=signal(),Loaded=signal(),Played=signal(),Paused=signal()}
   function sound:Stop()self.Playing=false;self.TimePosition=0;self.StopCalls+=1 end
   function sound:Play()self.Playing=true;self.Played:Fire()end
   function sound:Pause()self.Playing=false;self.Paused:Fire()end
   function sound:Destroy()self.DestroyCalls+=1 end
   table.insert(sounds,sound);return sound
  end}
  services.ContentProvider={PreloadAsync=function(_,list,callback)
   for _,sound in list do if sound.ClassName~=nil then continue end
    table.insert(preloads,sound.SoundId);sound.IsLoaded=sound.SoundId~='rbxassetid://401'
    if callback and not sound.IsLoaded then callback(sound.SoundId,'Enum.AssetFetchStatus.Failure')end
   end
  end}
  services.CanRenderSourceType=function(_,parsed)return if parsed.Essence=='audio/x-no-such'then false else nil end
  local page={Alive=true,Root=root,Document=doc,DocumentURL='https://sources.invalid/index.html',BaseURL='https://sources.invalid/index.html',Cleanups={}}
  function page:ResolveAudio(raw)return if raw=='https://sources.invalid/alias.wav'then'rbxassetid://402'else resolver:Asset('audio',raw)end
  -- AudioHost invokes this as a function, matching the real page contract.
  local resolve=page.ResolveAudio;page.ResolveAudio=function(raw)return resolve(page,raw)end
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  page.ManagedAudioStartup=HTMLScripts.ShouldStart(page,{})
  check(page.ManagedAudioStartup,'The exact real realm predicate owns startup audio')
  local realm,pending,targets,flushing=nil,false,{},false;local arrangements=0
  local function arrange(items)arrangements+=1;Dirty.begin(tree,items);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)end
  function page:FlushScriptLayout()if flushing or not realm then return end;flushing=true;local needed,items=realm:Flush();if pending then needed=true;items=items or{};for i in targets do items[i]=true end;pending=false;table.clear(targets)end;if needed then arrange(items)end;flushing=false end
  function page:HasPendingLayout()return pending end
  arrange();local stop=Controller.start(page,tree,function(_,target)pending=true;if target then targets[target]=true end end,function(m)table.insert(messages,m)end,services)
  local media=page.Media
  check(#sounds==1 and #preloads==0 and sounds[1].SoundId=='','Managed mount does not preload the renderer-preselected child')
  tree.StructuralResourcesRemoving=function(removals)media:Remove(removals.Media or{})end
  function page:RefreshDOMResources()local changes=tree:TakeStructuralResourceChanges();media:Remove(changes.Media.Removed);media:Add(changes.Media.Added)end
  realm=assert(HTMLScripts.start(page,tree,function()end,function(m)table.insert(messages,m)end,{JavaScriptServices={AudioServices=services,Clock=os.clock,RunService=runService,Task={delay=function(_,fn)return{Callback=fn}end,cancel=function(h)h.Cancelled=true end}}}))
  local function pump()
   for _=1,64 do
    if #queue>0 then local h=table.remove(queue,1);if not h.Cancelled then h.Callback()end end
    realm:PumpTasks();realm.EventLoop:Checkpoint();page:FlushScriptLayout()
   end
   check(#queue==0 and #realm.Diagnostics==0,mode..': '..table.concat(realm.Diagnostics,' | '))
  end
  local function run(code)local ok,message=realm:Run(code);check(ok,tostring(message));page:FlushScriptLayout();check(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
  run('var m=document.getElementById("m"),e=document.getElementById("editor");e.focus();e.setSelectionRange(1,3,"backward");window.sourceErrors=[];window.mutations=0;new MutationObserver(rs=>mutations+=rs.length).observe(document.body,{subtree:true,childList:true,attributes:true});document.getElementById("s1").addEventListener("error",()=>sourceErrors.push("s1"));window.outcome="pending";m.currentTime=5;m.playbackRate=1.5;'..(if deferred then''else'm.play().then(()=>outcome="played",x=>outcome=x.name);'))
  if mode=='error insertion'then run('document.getElementById("s1").addEventListener("error",()=>m.insertBefore(Object.assign(document.createElement("source"),{src:"two.wav"}),document.getElementById("s2")),{once:true});')end
  local control=page.FormModel:Resolve(Node.findById(doc,'editor'));local editor=control.Item.Editor;local connections=editor:ConnectionCount();local neighbor=tree.NodeBoxes[Node.findById(doc,'neighbor')].Gui;local sound=sounds[1];local baselineLayouts=arrangements
  local deferredEpoch
  if deferred then
   pump();local state=node.AudioResourceState;deferredEpoch=state.SelectionEpoch
   check(item.Source==nil and state.Current=='https://sources.invalid/missing.wav'and state.Raw=='missing.wav'and state.Mode=='children'and state.Gap==1 and state.Phase=='deferred'and state.Network==1 and state.Paused,'None retains the first unavailable candidate before the control request')
   check(#preloads==0 and #sounds==1 and not sound.Playing,'None checks no availability/IO and does not skip to the mapped second candidate')
   run('window.beforeControlErrors=sourceErrors.length;window.beforeControlStarts=0;m.addEventListener("loadstart",()=>beforeControlStarts++);')
   check(realm.Window.Get('beforeControlErrors')==0,'No SOURCE error before the real control requests playback')
   if mode=='none unavailable Play'then page:PlayMedia('m')
   elseif mode=='none unavailable Key'then
    check(page:FocusDOMElement(node,true),'Programmatic focus accepts controls with a live deferred AUDIO session and nil asset')
    run('document.getElementById("before").focus();')
    local tabEvent={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Tab}
    services.Input.InputBegan:Fire(tabEvent);services.Input.InputEnded:Fire(tabEvent)
    check(page.FormModel:GetActiveElement()==node and item.FocusVisible and #preloads==0,'Actual Tab includes the deferred AUDIO control without starting IO')
    local keyEvents=0;page.Events:On(node,'keydown',function()keyEvents+=1 end)
    local spaceEvent={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Space}
    services.Input.InputBegan:Fire(spaceEvent);services.Input.InputEnded:Fire(spaceEvent)
    check(keyEvents==1,'Space reaches the actual focused AUDIO through Controller native input')
   else
    local p=controls.AbsolutePosition;local point=Vector2.new(p.X+10,p.Y+10)
    check(MediaBox.action(item,point)=='toggle','Pointer uses the actual control toggle geometry')
    local clicks=0;page.Events:On(node,'click',function()clicks+=1 end);hitObjects={item.PlayGui}
    local clickEvent={UserInputType=Enum.UserInputType.MouseButton1,KeyCode=Enum.KeyCode.Unknown,Position=point}
    services.Input.InputBegan:Fire(clickEvent);check(item.PressedAction=='toggle','Actual Controller pointer press accepts the deferred selected AUDIO session')
    services.Input.InputEnded:Fire(clickEvent);hitObjects={}
    check(clicks==1 and item.PressedAction==nil,'Actual pointer release dispatches one control click and clears pressed state')
   end
  end
  pump()
  if deferred then
   check(sound.Playing and #preloads==1 and preloads[1]=='rbxassetid://402','The actual control alone resumes the selected first candidate and loads its mapped fallback')
   check(node.AudioResourceState.SelectionEpoch==deferredEpoch and node.AudioResourceState.Gap==2,'Control continuation preserves the selection epoch and advances its SOURCE pointer once')
   if mode~='none unavailable Play'then check(page.FormModel:GetActiveElement()==node,'Fallback retains the deliberate AUDIO control focus');run('e.focus();')end
   run('window.controlErrors=sourceErrors.join(",");window.controlStarts=beforeControlStarts;m.play().then(()=>outcome="played",x=>outcome=x.name);');pump()
   check(realm.Window.Get('controlErrors')=='s1'and realm.Window.Get('controlStarts')==0 and #preloads==1,'Unavailable first SOURCE fails once; control resume and later play promise do not start another selection/load')
  end
  check(#sounds==1 and item.Sound==sound and node.AudioHostSession.Sound==sound,'Fallback retains one actual AudioHost Sound')
  if mode=='error insertion'then
   check(preloads[1]=='rbxassetid://401'and preloads[2]=='rbxassetid://402'and #preloads==2,'Stable-state continuation selects s2 before the error listener inserts a node before the advanced gap')
  elseif mode=='mapped failure'then check(#preloads==2 and preloads[1]=='rbxassetid://401'and preloads[2]=='rbxassetid://402','Native before-metadata failure attempts mapped assets in order')
  else check(#preloads==1 and preloads[1]=='rbxassetid://402','Unavailable/type-rejected/absolute-alias candidates route to the single successful native load')end
  check(sound.Playing and sound.TimePosition==5,'Mounted fallback retains pending Play and the early position')
  local current=assert(tree.MediaByNode[node]);check(current==item and current.Gui==gui and current.BoxGui==box and current.ControlsGui==controls,'Fallback retains media and control GUI identity')
  check(control.Item.Editor==editor and editor:ConnectionCount()==connections and control.Value=='A😀BC'and control.SelectionStart==1 and control.SelectionEnd==3 and control.SelectionDirection=='backward','Fallback preserves editor, bindings, value and UTF16 selection')
  check(focused==editor and editor.CursorPosition==2 and editor.SelectionStart==6,'Fallback preserves native input focus and byte selection')
  check(tree.NodeBoxes[Node.findById(doc,'neighbor')].Gui==neighbor and not neighbor.Destroyed,'Fallback preserves its neighbor')
  run('window.result=outcome;window.errorList=sourceErrors.join(",");window.eventOnlyMutationCount=mutations;window.childSources=Array.from(m.children).map(s=>s.getAttribute("src")).join(",");')
  check(realm.Window.Get('result')=='played','Mounted original Play promise completes')
  check(realm.Window.Get('errorList')==(if mode=='resolved alias'then''else's1'),'Actual page events dispatch SOURCE errors, including no-IO qualification')
  if mode=='error insertion'then
   check(realm.Window.Get('eventOnlyMutationCount')==1 and realm.Window.Get('childSources')=='bad.wav,two.wav,one.wav','The actual error listener mutation is reconciled while its insertion remains before the advanced pointer')
  else check(realm.Window.Get('eventOnlyMutationCount')==0 and arrangements==baselineLayouts,'Candidate progress does not mutate DOM or rescan/arrange unrelated layout')end
  local count=#preloads;local epoch=node.AudioResourceState.SelectionEpoch
  run('m.pause();m.play().catch(()=>{});');pump()
  check(#preloads==count and node.AudioResourceState.SelectionEpoch==epoch and sound.Playing,'Later controls reuse the selected native resource')
  realm:Destroy();stop();page.Alive=false;for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end;media:Destroy();pump()
  check(sound.DestroyCalls==1 and sound.Ended:Count()==0 and sound.DidLoop:Count()==0 and runService.Heartbeat:Count()==0,'Disposed candidate host drops Sound and heartbeat connections once')
  check(editor:ConnectionCount()==0 and services.Input.InputBegan:Count()==0 and services.Input.InputChanged:Count()==0 and services.Input.InputEnded:Count()==0,'Disposed mounted candidates drop input/editor handlers')
 end
 print('Mounted Audio SOURCE candidates: 8 real HTMLScripts/AudioHost/Controller paths, '..checks..' assertions, including unavailable None Play/Key/pointer resume, retained Sound/GUI/editor/focus/UTF16 selection and cleanup passed')
end
