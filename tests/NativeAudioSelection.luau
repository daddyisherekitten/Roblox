--!strict
-- Actual HTMLPage startup, Controller and HTMLScripts; deterministic native
-- metadata/resource completion is distinct from Chrome and Studio pixels.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference,NativeMediaResources,Work)
 local checks,states,nativeStates=0,0,0
 local function check(value,label)checks+=1;assert(value,label)end
 local function near(actual,expected,label)check(math.abs(actual-expected)<.03,label..': '..actual..' != '..expected)end
 local function signal()
  local entries={};local s={}
  function s:Connect(fn)local c={Connected=true,Callback=fn};function c:Disconnect()self.Connected=false end;table.insert(entries,c);return c end
  function s:Fire(...)for _,c in table.clone(entries)do if c.Connected then c.Callback(...)end end end
  function s:Count()local n=0;for _,c in entries do if c.Connected then n+=1 end end;return n end
  function s:Snapshot()local n={};for _,c in entries do if c.Connected then table.insert(n,c.Callback)end end;return n end
  return s
 end
 local faces={};local overrides={['Layout/FontProfiles']={face=function(f,w,v)local k=tostring(f)..':'..tostring(w)..':'..tostring(v);faces[k]=faces[k]or{Family=f,Weight=w,Style=v};return faces[k]end},['Layout/TextMeasure']={measure=function(t,_,size)return Vector2.new(#t*size/2,size)end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local block=loadBlockLayout(overrides)
 local function fixture(options)
  options=options or{};local jobs,waiting,created,natives,svgs={}, {},{}, {},{};local focused,time,tree,page=nil,0,nil,nil;local hitObjects={};local observedPage,observedNode;local frameGate={Owners={},Deadline=nil};local cooperativeWaits,selectionWaits=0,0;local destroyedDuringSelection=false
  local counts={PosterLoads=0,PosterCancelled=0,SVGAdded=0,SVGRemoved=0,SVGJobs=0,NativeLoads=0,NativePlay=0,NativeSoundBind=0,Passes=0,PartialPasses=0}
  local function enqueue(fn,delay)local h={Callback=fn,Due=time+(delay or 0)};table.insert(jobs,h);return h end
  local tasks={spawn=enqueue,defer=enqueue,delay=function(delay,fn)return enqueue(fn,delay)end,cancel=function(h)h.Cancelled=true end,wait=function()
    time+=.016
    if options.Work4 then
     cooperativeWaits+=1;frameGate.Deadline=nil
     local state=observedNode and observedNode.NativeAudioResourceState
     if state and state.Mode=='children'and(state.Phase=='checking'or state.Phase=='source-error')then selectionWaits+=1 end
     if options.DestroyDuringSelection and state and state.Mode=='children'and(state.Phase=='checking'or state.Phase=='source-error')and not destroyedDuringSelection then
      destroyedDuringSelection=true;if options.OwnerOnly then observedPage.NativeMediaResources:Destroy()else observedPage:Destroy()end
     end
     local current=coroutine.running();enqueue(function()local ok,message=coroutine.resume(current);check(ok,tostring(message))end)
     coroutine.yield('native-selection-cooperative-wait')
    end
   end}
  local factory={}
  function factory.create(class,parent,props)
   local object=table.clone(props or{});object.ClassName,object.Parent=class,parent;if object.Visible==nil then object.Visible=true end
   object.AbsolutePosition,object.AbsoluteSize=Vector2.new(0,0),Vector2.new(800,600);object.AnchorPoint=Vector2.new(0,0);object.Position=object.Position or UDim2.fromOffset(0,0)
   object.BackgroundColor3=object.BackgroundColor3 or Color3.new(1,1,1);object.BackgroundTransparency=object.BackgroundTransparency or 1
   if class=='ScrollingFrame'then object.CanvasPosition=Vector2.new(0,0);object.ScrollBarThickness=0 end
   object.Destroying,object.Focused,object.FocusLost,object.InputBegan=signal(),signal(),signal(),signal();local propsigs,attrs={},{ }
   function object:GetPropertyChangedSignal(k)propsigs[k]=propsigs[k]or signal();return propsigs[k]end
   function object:GetAttributeChangedSignal(k)return self:GetPropertyChangedSignal('attribute:'..k)end
   function object:SetAttribute(k,v)local changed=attrs[k]~=v;attrs[k]=v;if changed then self:GetAttributeChangedSignal(k):Fire()end end
   function object:GetAttribute(k)return attrs[k]end
   function object:IsA(k)return k==class or k=='GuiObject'or k=='LayerCollector'and class=='ScreenGui'end
   function object:IsFocused()return focused==self end
   function object:CaptureFocus()if focused==self then return end;local old=focused;focused=self;if old then old.FocusLost:Fire(false)end;self.Focused:Fire()end
   function object:ReleaseFocus()if focused~=self then return end;focused=nil;self.FocusLost:Fire(false)end
   function object:Connections()local n=self.Focused:Count()+self.FocusLost:Count()+self.InputBegan:Count();for _,s in propsigs do n+=s:Count()end;return n end
   function object:Destroy()check(not self.Destroyed,'GUI destroyed once');self.Destroyed=true;self.Destroying:Fire();self:ReleaseFocus();for _,child in created do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
   if class=='VideoFrame'then
    object.Playing=false;object.TimePosition=0;object.TimeLength=12;object.Resolution=Vector2.new(0,0);object.Loaded,object.Played,object.Paused,object.Ended=signal(),signal(),signal(),signal()
    function object:Play()counts.NativePlay+=1;self.Playing=true;self.Played:Fire()end
    function object:Pause()self.Playing=false;self.Paused:Fire()end
   end
   table.insert(created,object);return object
  end;factory.modifier=factory.create
  local run={Heartbeat=signal(),RenderStepped=signal()};local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),MouseEnabled=true,MouseIcon='',MouseIconEnabled=true}
  function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode(k)return k.Name end
  local instance={new=function(class)
   if class=='Sound'and options.FactoryError then error('Controlled native Sound factory error')end
   if class=='VideoPlayer'and options.Modern==false then error('Intentional VideoFrame fallback')end
   local o={ClassName=class,TimePosition=0,TimeLength=12,Resolution=Vector2.new(0,0),IsLoaded=false,IsPlaying=false,Playing=false,DestroyCalls=0,Loaded=signal(),Played=signal(),Paused=signal(),Ended=signal(),DidEnd=signal(),DidLoop=signal(),PlayFailed=signal()};local sigs={}
   function o:GetPropertyChangedSignal(k)sigs[k]=sigs[k]or signal();return sigs[k]end
   function o:LoadAsync()counts.NativeLoads+=1;counts.Requests=counts.Requests or{};table.insert(counts.Requests,self.VideoContent);if self.VideoContent=='rbxassetid://200'and options.Failure then if options.Failure=='throw'then error('Controlled first video failure')else return end end;if options.DelayVideo then table.insert(waiting,coroutine.running());coroutine.yield()end;self.IsLoaded=true;self.Resolution=Vector2.new(80,40);self:GetPropertyChangedSignal('IsLoaded'):Fire()end
   function o:Play()counts.NativePlay+=1;self.IsPlaying=true;self.Playing=true;self:GetPropertyChangedSignal('IsPlaying'):Fire();self.Played:Fire()end
   function o:Pause()self.IsPlaying=false;self.Playing=false;self:GetPropertyChangedSignal('IsPlaying'):Fire();self.Paused:Fire()end
   function o:Stop()self:Pause();self.TimePosition=0 end
   function o:Unload()self.IsLoaded=false end
   function o:Destroy()self.DestroyCalls+=1;self.Parent=nil end
   if class=='Sound'then
    local soundId='';setmetatable(o,{__index=function(_,k)if k=='SoundId'then return soundId end end,__newindex=function(self,k,v)if k=='SoundId'then soundId=v;counts.NativeSoundBind+=1 else rawset(self,k,v)end end})
   end
   if class=='Frame'then o.AbsoluteSize=Vector2.new(960,540)end
   table.insert(natives,o);return o
  end}
  local provider={PreloadAsync=function(_,list)
   local object=list[1]
   if object and object.ClassName=='ImageLabel'and object.Image then
    counts.PosterLoads+=1;if options.DelayPoster then table.insert(waiting,coroutine.running());coroutine.yield()end
   elseif object and(object.ClassName=='VideoFrame'or object.ClassName=='Sound')then
    counts.NativeLoads+=1;counts.Requests=counts.Requests or{};local selected=object.SoundId or object.Video;table.insert(counts.Requests,selected);if (selected=='rbxassetid://300'or selected=='rbxassetid://200')and options.Failure then if options.Failure=='throw'then error('Controlled first native preload failure')else object.IsLoaded=false;return end end;if object.ClassName=='VideoFrame'and options.DelayVideo or object.ClassName=='Sound'and options.DelayAudio then table.insert(waiting,coroutine.running());coroutine.yield()end;object.IsLoaded=true
    if object.ClassName=='VideoFrame'then object.Resolution=Vector2.new(80,40);object.Loaded:Fire()else object.Loaded:Fire()end
   end
  end}
  local resources={Task=tasks,ContentProvider=provider,AssetFetchSuccess='Success',CreateImageLabel=function()return factory.create('ImageLabel',nil,{})end,AssetService={CreateEditableImageAsync=function(_,content)
   local raw=tostring(content);local w,h=if raw:find('102',1,true)then 120 else 200,if raw:find('102',1,true)then 240 else 100
   if raw:find('109',1,true)then error('Intentional poster decode failure')end
   return {Size=Vector2.new(w,h),Destroy=function()end}
  end}}
  local services={Task=tasks,RunService=run,ContentProvider=provider,Instance=instance,Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return hitObjects end},Content={none='content:none',fromUri=function(s)return s end},Factory=factory,Clock=function()return time end,PickerLayout=block}
  local workFacade=table.clone(Work)
  workFacade.new=function(milliseconds,svc)local supplied=table.clone(svc or{});if options.Work4 then supplied.FrameGate=frameGate end;return Work.new(milliseconds,supplied)end
  local renderer=loadRenderTree(factory)
  local svgRuntime={}
  function svgRuntime:AddItems(items)for _,item in items do if not svgs[item]then svgs[item]=true;counts.SVGAdded+=1;local last
   item.UpdateSVG=function()local key=tostring(item.ContentWidth)..':'..tostring(item.ContentHeight);if svgs[item]and key~=last then last=key;counts.SVGJobs+=1 end end
  end end end
  function svgRuntime:RemoveItems(items)for _,item in items do if svgs[item]then svgs[item]=nil;counts.SVGRemoved+=1;item.UpdateSVG=nil end end end
  local noImages={start=function()return nil,{Add=function()end,Remove=function()end,Destroy=function()end}end}
  local module=loadHTMLPage({['WorkContext']=workFacade,['Rendering/NativeMediaResources']={new=function(owner,current,configuration)
    observedPage=owner;observedNode=current.MediaItems[1]and current.MediaItems[1].Node
    if options.OwnerResolver then configuration.Resolve=options.OwnerResolver end
    if options.TypePolicy then configuration.AudioServices=table.clone(configuration.AudioServices or{});configuration.AudioServices.CanRenderSourceType=options.TypePolicy end
    if options.ResolverError then configuration.Resolve=function()error('Controlled initial native resolver error')end;configuration.Task=table.clone(tasks);configuration.Task.defer=function(fn)fn()end end
    if options.TraversalError then
     local original=Work.checkpoint;Work.checkpoint=function()error('Controlled initial native traversal error')end
     local ok,result=pcall(NativeMediaResources.new,owner,current,configuration);Work.checkpoint=original
     if not ok then error(result,0)end;return result
    end
    return NativeMediaResources.new(owner,current,configuration)
   end},['Rendering/GuiFactory']=factory,['Layout/WordLayout']=overrides['Layout/WordLayout'],['Layout/TextMeasure']=overrides['Layout/TextMeasure'],['Rendering/ImageDimensions']=noImages,['Rendering/ImageLoad']=noImages,
   ['Rendering/HTMLScripts']={hasScripts=HTMLScripts.hasScripts,ShouldStart=HTMLScripts.ShouldStart,start=function(...)
    if options.DelayVM then
     for _,o in natives do if o.ClassName=='Sound'then check(o.SoundId=='','Managed Sound is empty before delayed real realm initialization')end end
     check(counts.NativeSoundBind==0 and counts.NativeLoads==0 and counts.NativePlay==0,'No legacy audio IO before real realm startup')
     while #jobs>0 do local job=table.remove(jobs,1);if not job.Cancelled then time=math.max(time,job.Due);job.Callback()end end
     check(counts.NativeSoundBind==0 and counts.NativeLoads==0 and counts.NativePlay==0,'Delayed startup tasks do not bind/preload/play legacy audio')
    end
    return HTMLScripts.start(...)
   end},
   ['Rendering/RenderTree']={build=function(document,viewport,diagnostic,...)
    local args=table.pack(...);args[1]=overrides['Layout/FontProfiles'].face;tree=renderer.build(document,viewport,diagnostic,table.unpack(args,1,args.n));return tree
   end},['Layout/BlockLayout']={arrange=function(...)counts.Passes+=1;if tree.DirtyContext and tree.DirtyContext.Reuse then counts.PartialPasses+=1 end;return block.arrange(...)end},
   ['Input/Controller']={start=function(owner,current,layout,diagnostic)return Controller.start(owner,current,layout,diagnostic,services)end},
   ['Rendering/SVGImages']={start=function(owner,current)
    svgRuntime:AddItems(current.SVGItems);owner:AddCleanup(function()local all={};for i in svgs do table.insert(all,i)end;svgRuntime:RemoveItems(all)end);return svgRuntime
   end},
  },tasks,function()if options.Work4 then time+=.00005 end;return time end)
  local scripts=if options.Scripting==false then ''else '<script>var m=document.getElementById("v"),v=m,wide="wide.png",tall="tall.png",clip="one.webm",e=document.getElementById("editor");window.loadSeen=0;window.addEventListener("load",function(){loadSeen++})</script>'
  local html=options.HTML or('<!doctype html><style>body{margin:0}video{display:block}</style><video id="v" muted preload="none" '..(if options.Poster then 'poster="'..options.Poster..'" 'else '')..'></video><input id="editor" tabindex="-1" value="A&#x1f600;BC"><p id="neighbor">retained neighbor</p>'..scripts)
  local mountOptions={JavaScript=options.Scripting~=false,RenderWorkBudgetMS=if options.Work4 then 4 else 0,DocumentURL=if options.Catalog then nil else options.DocumentURL or 'https://video.test/root/index.html',Images={['wide.png']='101',['tall.png']='102',['bad.png']='109'},SVGs={['wide.svg']='<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100"/></svg>'},Videos={['first.webm']='200',['second.webm']='201'},Audio={['first.mp3']='300',['second.mp3']='301'},JavaScriptServices={Task=tasks,Clock=function()return time end,RunService=run,ResourceServices=resources,AudioServices={Task=tasks,Instance=instance,RunService=run,ContentProvider=provider}}}
  if options.StylesheetOnly then mountOptions.JavaScriptServices.LoadStylesheet=function()return ''end end
  local target=factory.create('Frame',factory.create('ScreenGui',nil,{}),{})
  local mountOK,mountResult
  if options.Work4 then
   local mountThread=coroutine.create(function()mountOK,mountResult=pcall(module.mount,target,html,mountOptions)end)
   local started,message=coroutine.resume(mountThread);check(started,tostring(message))
   for _=1,4096 do
    if coroutine.status(mountThread)=='dead'then break end
    check(#jobs>0,'Work4 mount has a real cooperative continuation');local job=table.remove(jobs,1)
    if not job.Cancelled then time=math.max(time,job.Due);local current=coroutine.create(job.Callback);local ok,result=coroutine.resume(current);check(ok,tostring(result))end
   end
   check(coroutine.status(mountThread)=='dead','Actual cooperative HTMLPage mount returns')
  else mountOK,mountResult=pcall(module.mount,target,html,mountOptions)end
  if options.ExpectMountError then
   print('NATIVE_OWNER_CONSTRUCTOR_PROBE',options.ExpectMountError,mountOK,tostring(mountResult))
   check(not mountOK and tostring(mountResult):find(options.ExpectMountError,1,true)~=nil,'Actual mount propagates original constructor failure')
   check(observedPage~=nil and not observedPage.Alive and observedPage.Root.Destroyed,'Outer mount catch destroys actual native owner page/root')
   check(observedPage.NativeMediaResources~=nil and not observedPage.NativeMediaResources.Alive,'Constructor cleanup releases installed native owner')
   for _,native in natives do if native.ClassName=='Sound'then check(native.DestroyCalls==1,'Constructor failure destroys each allocated Sound exactly once')end end
   check(counts.NativeLoads==0,'Constructor failure performs no native provider IO')
   return {Page=observedPage,Instances=natives,Created=created,Counts=counts}
  end
  check(mountOK,tostring(mountResult));page=mountResult
  local realm=page.JavaScriptRuntime;local node=Node.findById(page.Document,'v');local item=node and tree.MediaByNode[node]
  local gui,box,frame,display=if item then item.Gui else nil,if item then item.BoxGui else nil,if item then item.VideoGui else nil,if item then item.VideoDisplay else nil
  local function drain()for _=1,160 do if #jobs==0 then return end;local job=table.remove(jobs,1);if not job.Cancelled then time=math.max(time,job.Due);local thread=coroutine.create(job.Callback);local ok,message=coroutine.resume(thread);check(ok,tostring(message))end end;error('Presentation queue did not converge')end
  local function resume(noDrain)local thread=table.remove(waiting,1);check(thread~=nil,'Actual suspended resource job');local ok,message=coroutine.resume(thread);check(ok,tostring(message));if not noDrain then drain()end end
  local function script(code,noDrain)check(realm~=nil,'Actual page realm');local ok,message=realm:Run(code);check(ok,tostring(message));page:FlushScriptLayout();if not noDrain then drain()end;check(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
  local function direct(code)local ok,message=realm:Run(code);check(ok,tostring(message));check(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
  local editorRecord
  local function focus()
   script('e.focus();e.setSelectionRange(1,3,"backward")');local c=page.FormModel:Resolve(Node.findById(page.Document,'editor'));editorRecord={Control=c,Editor=c.Item.Editor,Bindings=c.Item.Editor:Connections(),Neighbor=tree.NodeBoxes[Node.findById(page.Document,'neighbor')].Gui}
  end
  local function retained()
   check(tree.MediaByNode[node]==item and item.Gui==gui and item.BoxGui==box and item.VideoGui==frame and item.VideoDisplay==display,'Retained VIDEO native/render surfaces')
   if editorRecord then local c,e=editorRecord.Control,editorRecord.Editor;check(c.Item.Editor==e and e:Connections()==editorRecord.Bindings and focused==e and c.Value=='A😀BC'and c.SelectionStart==1 and c.SelectionEnd==3 and c.SelectionDirection=='backward'and e.CursorPosition==2 and e.SelectionStart==6,'VIDEO mutation preserves actual editor focus/bindings/UTF16 and byte selection');check(tree.NodeBoxes[Node.findById(page.Document,'neighbor')].Gui==editorRecord.Neighbor,'VIDEO retains neighbor GUI')end
  end
  local function geometry(value,label,nativeCase)if math.abs(item.ContentWidth-value.width)>.03 then print('Presentation diagnostic',label,item.PosterSource,item.Poster,item.PosterWidth,item.PosterHeight,item.IntrinsicWidth,page.PosterPendingCount,counts.PosterLoads,tree.DirtyContext and tree.DirtyContext.Ready);for _,d in page.Document.Diagnostics do print(d.Code,d.Message)end end;near(item.ContentWidth,value.width,label..' width');near(item.ContentHeight,value.height,label..' height');states+=1;if nativeCase then nativeStates+=1 end;retained()end
  local function dimensions(w,h,label)check(item.VideoWidth==w and item.VideoHeight==h,label);if realm then script('window.dimensions=JSON.stringify([m.videoWidth,m.videoHeight])');check(realm.Window.Get('dimensions')=='['..w..','..h..']','Actual readonly mounted dimensions')end end
  local function destroy()page:Destroy();drain();check(not page.Alive and page.PosterPendingCount==0,'Actual HTMLPage disposed poster barrier');check(run.Heartbeat:Count()==0 and run.RenderStepped:Count()==0,'Actual page media frame connections disposed');check(input.InputBegan:Count()==0 and input.InputChanged:Count()==0 and input.InputEnded:Count()==0,'Actual Controller disposal');if realm then check(not realm.Alive and not realm.EventLoop.Alive,'Actual realm disposal')end end
  return {Page=page,Tree=tree,Item=item,Node=node,Realm=realm,Run=script,Direct=direct,Drain=drain,Resume=resume,Retained=retained,Geometry=geometry,Dimensions=dimensions,Destroy=destroy,Counts=counts,Waiting=waiting,Jobs=jobs,SVG=svgs,Native=function()return if item and item.MediaKind=="audio"then item.Sound elseif item then item.VideoPlayer or item.VideoGui else nil end,Options=options,Focused=function()return focused end,Focus=focus,Instances=natives,Created=created,Input=input,HitObjects=function(value)hitObjects=value end,Step=function()local job=table.remove(jobs,1);check(job~=nil,"Actual queued native owner task");return coroutine.resume(coroutine.create(job.Callback))end,WorkStats=function()return cooperativeWaits,frameGate,destroyedDuringSelection,selectionWaits end}
 end

 -- Additive BUILD tests. The original 21-case red source/log remain immutable.
 local scenarios={
  {Name='first mapped native throw',Failure='throw',Expected='both',ExpectedError='s1'},
  {Name='first mapped remains unloaded',Failure='unloaded',Expected='both',ExpectedError='s1'},
  {Name='first unmapped is still candidate',Missing=true,Expected='second',ExpectedError='s1'},
  {Name='first false media qualification',Media='(min-width:99999px)',Expected='second',ExpectedError='s1'},
  {Name='invalid MIME remains unknown',Type='not a mime',Expected='first',ExpectedError=''},
  {Name='present empty direct src never tries children',Direct=' src=""',Expected='none',ExpectedError=''},
  {Name='None defers first unavailable candidate',Missing=true,None=true,Expected='none',ExpectedError=''}
 }
 local completed=0
 for _,scenario in scenarios do
  local first=if scenario.Missing then 'missing.media'else 'first.mp3'
  local html='<audio id=v controls preload='..(if scenario.None then 'none'else 'auto')..(scenario.Direct or '')..'><source id=s1 src='..first..(if scenario.Media then ' media="'..scenario.Media..'"'else '')..(if scenario.Type then ' type="'..scenario.Type..'"'else '')..'><source id=s2 src=second.mp3></audio>'
  local h=fixture({HTML=html,Scripting=false,Failure=scenario.Failure});local errors={}
  for _,s in h.Node.Children do h.Page.Events:On(s,'error',function()table.insert(errors,s.Attributes.id)end)end
  h.Drain()
  check(h.Realm==nil and h.Page.ManagedAudioStartup==false and h.Page.NativeMediaResources~=nil,'Actual no-Realm AUDIO owner')
  local expected=if scenario.Expected=='both'then 'rbxassetid://300,rbxassetid://301'elseif scenario.Expected=='second'then 'rbxassetid://301'elseif scenario.Expected=='first'then 'rbxassetid://300'else ''
  check(table.concat(h.Counts.Requests or{},',')==expected,scenario.Name..' exact actual native attempts')
  check(table.concat(errors,',')==scenario.ExpectedError,scenario.Name..' exact SOURCE errors')
  local raw=if scenario.None then first elseif scenario.Expected=='first'then 'first.mp3'elseif scenario.Expected=='none'then ''else 'second.mp3'
  check(h.Item.SelectedSource==raw,scenario.Name..' selected actual item')
  check(h.Node.AudioResourceState==nil,'No JS AudioElements state allocated')
  local sounds=0;for _,native in h.Instances do if native.ClassName=='Sound'then sounds+=1 end end;check(sounds==1,'One retained Sound through candidate attempts')
  if scenario.Expected~='none'then check(h.Native().IsLoaded and h.Item.MetadataEmitted,'Actual successful metadata only')end
  if scenario.None then
   check(h.Native().SoundId==''and h.Counts.NativeLoads==0 and #errors==0,'None stops before mapping availability and IO')
   h.Page:PlayMedia('v');h.Drain()
   check(table.concat(errors,',')=='s1'and table.concat(h.Counts.Requests or{},',')=='rbxassetid://301','Actual page control resumes retained first candidate then retries')
   check(h.Item.Playing and h.Native().Playing,'Native Play intent survives candidate error')
  end
  h.Destroy();check(h.Page.NativeMediaResources.Alive==false,'Native owner participates in actual page teardown');completed+=1
 end

 for _,style in {'','display:none'}do
  local h=fixture({HTML='<audio id=v autoplay preload=auto style="'..style..'"><source src=first.mp3></audio>',Scripting=false})
  h.Drain();check(h.Item==nil,'Control-free AUDIO has no MediaItem')
  check(h.Realm==nil and h.Node.AudioResourceState==nil,'Hidden/control-free owner remains VM-free')
  local state=h.Page.NativeMediaResources:State(h.Node)
  check(state.Playing and state.ReadyState==4 and state.SelectedSource=='first.mp3','Hidden/control-free AUDIO actually selects and plays')
  check(h.Counts.NativeLoads==1,'Hidden/control-free AUDIO exactly one native IO')
  h.Destroy();completed+=1
 end

 for _,gesture in {'key','pointer'}do
  local h=fixture({HTML='<button id=before>Before</button><audio id=v controls preload=none><source id=s1 src=missing.media><source src=second.mp3></audio>',Scripting=false})
  local errors,starts=0,0;h.Page.Events:On(h.Node.Children[1],'error',function()errors+=1 end)
  h.Drain();local owner=h.Page.NativeMediaResources;local r=h.Node.NativeAudioResourceState;local epoch=r.SelectionEpoch
  local sound,gui,controls=h.Native(),h.Item.Gui,h.Item.ControlsGui
  check(h.Item.Source==nil and sound.SoundId==''and r.Raw=='missing.media'and r.Gap==1 and r.Phase=='deferred','Deferred unavailable candidate has retained actual controls without IO')
  check(h.Counts.NativeLoads==0 and errors==0,'No native availability failure before real input')
  h.Page.Events:On(h.Node,'loadstart',function()starts+=1 end)
  owner:Set(h.Node,'currentTime',5);owner:Set(h.Node,'playbackRate',1.5)
  if gesture=='key'then
   check(h.Page:FocusDOMElement(h.Node,true),'Actual programmatic focus accepts nil-asset native AUDIO session')
   check(h.Page:FocusDOMElement(Node.findById(h.Page.Document,'before'),true),'Actual preceding button takes focus')
   local tab={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Tab}
   h.Input.InputBegan:Fire(tab);h.Input.InputEnded:Fire(tab)
   check(h.Page.FormModel:GetActiveElement()==h.Node and h.Item.FocusVisible and h.Counts.NativeLoads==0,'Actual Tab includes deferred native AUDIO without IO')
   local keys=0;h.Page.Events:On(h.Node,'keydown',function()keys+=1 end)
   local space={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Space}
   h.Input.InputBegan:Fire(space);h.Input.InputEnded:Fire(space);check(keys==1,'Actual focused Space reaches native AUDIO Controller route')
  else
   local p=controls.AbsolutePosition;local point=Vector2.new(p.X+10,p.Y+10)
   check(MediaBox.action(h.Item,point)=='toggle','Pointer selects actual Play control geometry')
   local clicks=0;h.Page.Events:On(h.Node,'click',function()clicks+=1 end);h.HitObjects({h.Item.PlayGui})
   local click={UserInputType=Enum.UserInputType.MouseButton1,KeyCode=Enum.KeyCode.Unknown,Position=point}
   h.Input.InputBegan:Fire(click);check(h.Item.PressedAction=='toggle','Actual Controller accepts deferred native pointer press')
   h.Input.InputEnded:Fire(click);h.HitObjects({});check(clicks==1 and h.Item.PressedAction==nil,'Actual pointer release dispatches one click and clears press')
  end
  h.Drain();check(errors==1 and starts==0 and h.Counts.NativeLoads==1,'Native input resumes one selection without new loadstart and retries missing SOURCE once')
  check(r.SelectionEpoch==epoch and r.Gap==2 and r.Raw=='second.mp3'and sound.Playing,'Native input preserves epoch/Play intent through ordered fallback')
  check(sound.TimePosition==5 and sound.PlaybackSpeed==1.5,'Candidate retry preserves default cursor and chosen rate')
  check(h.Native()==sound and h.Item.Gui==gui and h.Item.ControlsGui==controls,'Actual native input/fallback retains Sound and GUI identity')
  if gesture=='key'then check(h.Page.FormModel:GetActiveElement()==h.Node,'Native fallback retains keyboard focus')end
  h.Destroy();completed+=1
 end

 for _,enabled in {false,true}do
  local keyword=if enabled then 'enabled'else 'none'
  local h=fixture({HTML='<audio id=v controls preload=auto><source id=s1 src=first.mp3 media="(scripting: '..keyword..')"><source src=second.mp3></audio>',Scripting=enabled})
  h.Drain();check(h.Realm==nil and h.Page.ManagedAudioStartup==false,'Script-free mount does not create a hidden realm')
  check(h.Item.SelectedSource=='first.mp3'and h.Counts.NativeLoads==1,'Native SOURCE media reads enabled versus explicitly disabled environment')
  check(h.Page:GeometryViewport().Environment.Scripting==keyword,'Existing host scripting environment is used unchanged')
  h.Destroy();completed+=1
 end

 do
  local h=fixture({HTML='<audio id=v controls preload=auto src="./first.mp3"></audio>',Scripting=false,Catalog=true})
  h.Drain();check(h.Page.DocumentURL=='/'and h.Realm==nil,'Actual default local-catalog no-Realm mount')
  check(h.Item.SelectedSource=='./first.mp3'and h.Page.NativeMediaResources:State(h.Node).CurrentSrc=='/first.mp3','Current selected URL preserves catalog profile and raw source')
  check(h.Counts.NativeLoads==1 and h.Native().SoundId=='rbxassetid://300','Raw local catalog mapping reaches exactly one actual native load')
  h.Destroy();completed+=1
 end

 do
  local h=fixture({HTML='<audio id=v controls preload=auto><source id=s1 src=first.mp3><source id=s2 src=second.mp3></audio>',Scripting=false,Failure='throw'})
  local owner=h.Page.NativeMediaResources;local atError
  h.Page.Events:On(h.Node.Children[1],'error',function()
   local state=owner:State(h.Node);atError={Raw=state.SelectedSource,Current=state.CurrentSrc,Sound=h.Native().SoundId}
   h.Node.Attributes.src='second.mp3';owner:AttributeChanged(h.Node,'src','second.mp3',nil)
  end,{Once=true})
  h.Drain();check(atError~=nil and atError.Raw=='second.mp3'and atError.Current=='https://video.test/root/second.mp3'and atError.Sound=='rbxassetid://301','Stable next-candidate decision precedes SOURCE error task')
  check(h.Item.SelectedSource=='second.mp3'and h.Node.NativeAudioResourceState.Mode=='attribute','Error-listener direct reset replaces old selection epoch')
  check(h.Native().IsLoaded and h.Item.MetadataEmitted,'Reentrant direct selection reaches actual metadata')
  h.Destroy();completed+=1
 end

 -- Explicit notification seam, not interception of bare Node operations.
 do
  local h=fixture({HTML='<audio id=v controls preload=auto><source id=s1 src=missing.media><i id=gap></i></audio>',Scripting=false})
  h.Drain();local owner=h.Page.NativeMediaResources;local r=h.Node.NativeAudioResourceState
  check(r.Waiting and r.Gap==2,'Exhausted gap includes non-SOURCE children')
  local first=h.Node.Children[1];owner:BeforeRemove(first,true);Node.removeChild(h.Node,first)
  check(r.Gap==1,'BeforeRemove notifies exactly once before native removal')
  owner:BeforeInsert(h.Node,0,1);Node.insertBefore(h.Node,first,h.Node.Children[1]);owner:Mutation({Type='childList',Target=h.Node,AddedNodes={first},RemovedNodes={}})
  h.Drain();check(r.Waiting and r.Gap==2,'Move before exhausted gap does not retry old SOURCE')
  local extra=Node.element('source',{id='s2',src='second.mp3'});extra.OwnerDocument=h.Page.Document
  owner:BeforeInsert(h.Node,#h.Node.Children,1);Node.append(h.Node,extra);owner:Mutation({Type='childList',Target=h.Node,AddedNodes={extra},RemovedNodes={}})
  h.Drain();check(h.Item.SelectedSource=='second.mp3'and h.Counts.NativeLoads==1,'Append at live gap resumes one successful native attempt')
  h.Destroy();completed+=1
 end

 do
  local h=fixture({HTML='<audio id=v controls preload=auto><source id=s1 src=first.mp3><source src=second.mp3></audio>',Scripting=false,Failure='throw'})
  local errors,metadata=0,0;local sound=h.Native()
  h.Page.Events:On(h.Node.Children[1],'error',function()errors+=1;h.Page:Destroy()end,{Once=true})
  h.Page.Events:On(h.Node,'loadedmetadata',function()metadata+=1 end)
  h.Drain();check(errors==1 and metadata==0 and h.Page.Alive==false,'SOURCE error task can destroy actual page without late publication')
  check(sound.DestroyCalls==1 and h.Page.NativeMediaResources.Alive==false,'Reentrant actual page teardown destroys one retained native Sound')
  check(table.concat(h.Counts.Requests or{},',')=='rbxassetid://300','Already selected next candidate cannot begin IO after page destruction')
  h.Destroy();completed+=1
 end

 do
  local h=fixture({HTML='<audio id=v controls preload=auto src=first.mp3></audio>',Scripting=false,DelayAudio=true})
  local owner=h.Page.NativeMediaResources;local metadata=0;local sound=h.Native()
  h.Page.Events:On(h.Node,'loadedmetadata',function()metadata+=1 end)
  h.Drain();check(#h.Waiting==1 and metadata==0,'Actual first native preload held before metadata')
  h.Node.Attributes.src='second.mp3';owner:AttributeChanged(h.Node,'src','second.mp3',nil);h.Drain()
  check(#h.Waiting==2 and h.Native()==sound,'New selection retains exactly one Sound across held old IO')
  h.Resume();check(metadata==0 and owner:State(h.Node).ReadyState==0,'Late old IO cannot publish current metadata')
  h.Resume();check(metadata==1 and h.Item.SelectedSource=='second.mp3'and h.Native()==sound,'Current native completion publishes metadata once')
  check(table.concat(h.Counts.Requests or{},',')=='rbxassetid://300,rbxassetid://301','Native held attempts retain exact request order')
  h.Destroy();check(sound.DestroyCalls==1,'Held IO path still destroys retained Sound exactly once');completed+=1
 end

 do
  local document=Node.document();local node=Node.element('source',{});node.OwnerDocument=document
  local page={Document=document,DocumentURL='https://resolver.test/root/index.html'}
  check(NativeMediaResources.resolve(page,node,'clip.mp3')=='https://resolver.test/root/clip.mp3','Native resolver uses current document base')
  check(NativeMediaResources.resolve(page,node,'http://[')==nil,'Invalid absolute selected URL does not use reflection fallback')
  check(NativeMediaResources.resolve(page,node,'\237\160\128.mp3')=='https://resolver.test/root/%EF%BF%BD.mp3','Native selected URL scalarizes lone UTF16 unit')
  check(NativeMediaResources.resolve(page,node,'\237\160\189\237\184\128.mp3')=='https://resolver.test/root/%F0%9F%98%80.mp3','Native scalarizer preserves valid surrogate pair')
  local detached=Node.document();detached.URL='https://adopt.test/else/index.html';node.OwnerDocument=detached
  local base=Node.element('base',{href='../assets/'});Node.append(detached,base)
  check(NativeMediaResources.resolve(page,node,'clip.mp3')=='https://adopt.test/assets/clip.mp3','Detached current owner base uses existing document rules')
  node.OwnerDocument=document;page.DocumentURL='about:blank';document.BaseURLState=nil
  check(NativeMediaResources.resolve(page,node,'clip.mp3')==nil,'Opaque base cannot resolve a relative candidate')
  check(NativeMediaResources.resolve(page,node,'https://absolute.test/clip.mp3')=='https://absolute.test/clip.mp3','Opaque base still allows absolute candidate')
  page.DocumentURL=nil;document.BaseURLState=nil
  check(NativeMediaResources.resolve(page,node,'clip.mp3')==nil,'Missing URL uses about:blank rather than an invented origin')
  page.DocumentURL='/';document.BaseURLState=nil
  check(NativeMediaResources.resolve(page,node,'./tone.ogg')=='/tone.ogg','Default local catalog root resolves dot path')
  check(NativeMediaResources.resolve(page,node,'../tone.ogg')=='/tone.ogg','Default local catalog root clamps parent path')
  page.DocumentURL='/site/index.html';document.BaseURLState=nil
  check(NativeMediaResources.resolve(page,node,'./tone.ogg')=='/site/tone.ogg','Local catalog document resolves dot path')
  check(NativeMediaResources.resolve(page,node,'../tone.ogg')=='/tone.ogg','Local catalog document resolves parent path')
  check(NativeMediaResources.resolve(page,node,'\t ./tone.ogg\n')=='/site/tone.ogg','Local catalog URL preprocessing removes tabs/newlines')
  check(NativeMediaResources.resolve(page,node,' \thttp://[\n')==nil,'Preprocessed invalid absolute URL never enters catalog fallback')
  local catalogBase=Node.element('base',{href='../audio/'});Node.append(document,catalogBase);document.BaseURLState=nil
  check(NativeMediaResources.resolve(page,node,'./tone.ogg')=='/audio/tone.ogg','Relative catalog BASE preserves existing frozen base contract')
  check(NativeMediaResources.resolve(page,node,'../tone.ogg')=='/tone.ogg','Catalog relative BASE retains parent-path normalization')
 end
 for _,controls in {false,true}do
  local h=fixture({HTML='<audio id=v '..(if controls then 'controls'else '')..' preload=none></audio>',Scripting=false})
  h.Drain();local owner=h.Page.NativeMediaResources;local r=h.Node.NativeAudioResourceState
  check(r.Network==0 and not r.Loading and r.Paused and r.Current==''and h.Counts.NativeLoads==0,'Initial source-less native AUDIO stays NETWORK_EMPTY without IO')
  local initialSounds=0;for _,native in h.Instances do if native.ClassName=='Sound'then initialSounds+=1 end end
  check(initialSounds==(if controls then 1 else 0),'Only initial native controls need a retained source-less Sound')
  owner:Set(h.Node,'currentTime',5);owner:Set(h.Node,'playbackRate',1.5);owner:Play(h.Node);h.Drain()
  check(r.Network==0 and not r.Paused and r.PendingPlay and r.DefaultStart==5 and r.Rate==1.5,'Source-less native Play retains waiting intent/cursor/rate')
  local source=Node.element('source',{src='second.mp3'});source.OwnerDocument=h.Page.Document
  owner:BeforeInsert(h.Node,0,1);Node.append(h.Node,source);owner:Mutation({Type='childList',Target=h.Node,AddedNodes={source},RemovedNodes={}});h.Drain()
  check(r.Playing and not r.PendingPlay and r.Position==5 and r.Rate==1.5 and h.Counts.NativeLoads==1,'Initial SOURCE insertion fulfills retained native Play without load reset')
  local sounds=0;for _,native in h.Instances do if native.ClassName=='Sound'then sounds+=1;check(native.TimePosition==5 and native.PlaybackSpeed==1.5,'Source-less native cursor/rate reaches retained Sound')end end
  check(sounds==1,'Initial insertion allocates or reuses exactly one Sound')
  h.Destroy();completed+=1
 end
 do
  local h=fixture({HTML='<audio id=v controls preload=none src=second.mp3></audio>',Scripting=false})
  h.Drain();check(h.Counts.NativeLoads==0 and h.Counts.NativeSoundBind==1 and h.Native().SoundId=='rbxassetid://301','Mapped native None preserves one binding hint and performs no IO')
  check(h.Node.NativeAudioResourceState.Phase=='deferred'and h.Item.SelectedSource=='second.mp3','Mapped native None retains its actual selected resource')
  h.Destroy();completed+=1
 end
 for _,failure in {{FactoryError=true,ExpectMountError='Controlled native Sound factory error'},{TraversalError=true,ExpectMountError='Controlled initial native traversal error'},{ResolverError=true,ExpectMountError='Controlled initial native resolver error'}}do
  failure.HTML='<audio id=v controls preload=auto src=first.mp3></audio>';failure.Scripting=false
  fixture(failure);completed+=1
 end
 for _,ownerOnly in {false,true}do
  local children={};for _=1,300 do table.insert(children,'<i></i>')end
  local h=fixture({HTML='<audio id=v controls preload=auto><source src=missing.media>'..table.concat(children)..'<source src=second.mp3></audio>',Scripting=false,Work4=true,DestroyDuringSelection=true,OwnerOnly=ownerOnly})
  h.Drain();local waits,gate,destroyed,selectionWaits=h.WorkStats();local work=h.Page.LoadingWork
  check(destroyed and waits>0 and selectionWaits==1 and work~=nil and work.Yields>0,'Native selection uses real active WorkContext and cooperatively yields before disposal')
  check(h.Page.Alive==ownerOnly and not h.Page.NativeMediaResources.Alive and work.Running==0 and not work.Active and next(gate.Owners)==nil,'Page or owner-only Dispose ends held native selection and releases its running work/frame owner')
  check(h.Counts.NativeLoads==0 and h.Counts.NativePlay==0,'No host load/play begins after cancelled native gap traversal')
  for _,native in h.Instances do if native.ClassName=='Sound'then check(native.DestroyCalls==1,'Cooperative selection disposal destroys its retained native Sound once')end end
  print('NATIVE_AUDIO_SELECTION_WORK4','ownerOnly='..tostring(ownerOnly),'waits='..waits,'selectionWaits='..selectionWaits,'yields='..work.Yields,'runs='..work.Runs,'running='..work.Running,'nativeLoads='..h.Counts.NativeLoads)
  h.Destroy();completed+=1
 end
 do
  local h=fixture({HTML='<audio id=v controls preload=none src=second.mp3></audio>',Scripting=false,DelayAudio=true})
  h.Drain();local sound=h.Native();h.Page:PlayMedia('v');h.Drain()
  check(#h.Waiting==1 and h.Item.Loading and h.Node.AudioHostSession.Loading,'Actual native deferred Play enters held IO')
  h.Page.Media:Remove({h.Item});h.Page.Media:Add({h.Item});h.Drain()
  check(h.Native()==sound and h.Item.AudioSession==h.Node.AudioHostSession and h.Item.Loading and h.Item.SelectedSource=='second.mp3'and h.Item.Source=='rbxassetid://301','Warm Add preserves attached live native loading/source/error fields')
  check(h.Counts.NativeLoads==1 and #h.Waiting==1,'Warm Add does not create another native media request')
  h.Resume();check(not h.Item.Loading and h.Item.Playing and h.Item.MetadataEmitted,'Held warm native completion publishes loading/playing/metadata state once')
  h.Destroy();check(sound.DestroyCalls==1,'Warm Add still owns one retained native Sound');completed+=1
 end
 for _,policy in {'false','true','unknown'}do
  local calls=0
  local h=fixture({HTML='<audio id=v controls preload=auto><source id=s1 src=first.mp3 type="audio/wav"><source src=second.mp3></audio>',Scripting=false,TypePolicy=function(raw,parsed)
   calls+=1;check(raw=='audio/wav'and parsed.Essence=='audio/wav','Native owner forwards pure source type policy arguments')
   return if policy=='false'then false elseif policy=='true'then true else nil
  end})
  local errors=0;h.Page.Events:On(h.Node.Children[1],'error',function()errors+=1 end);h.Drain()
  local expected=if policy=='false'then 'rbxassetid://301'else 'rbxassetid://300'
  check(calls==1 and table.concat(h.Counts.Requests or{},',')==expected and errors==(if policy=='false'then 1 else 0),'Tri-state native type capability rejects only known false before IO')
  check(h.Item.MetadataEmitted and h.Native().IsLoaded,'Native policy still requires actual successful metadata')
  h.Destroy();completed+=1
 end
 do
  local h=fixture({HTML='<audio id=v controls preload=auto></audio>',Scripting=false});h.Drain();local owner=h.Page.NativeMediaResources
  local foreign=Node.element('source',{src='first.mp3'});foreign.NamespaceURI='urn:foreign';foreign.OwnerDocument=h.Page.Document
  local nested=Node.element('i',{});nested.OwnerDocument=h.Page.Document;local inside=Node.element('source',{src='first.mp3'});inside.OwnerDocument=h.Page.Document;Node.append(nested,inside)
  local direct=Node.element('source',{src='second.mp3'});direct.OwnerDocument=h.Page.Document
  owner:BeforeInsert(h.Node,0,3);for _,child in {foreign,nested,direct}do Node.append(h.Node,child)end
  owner:Mutation({Type='childList',Target=h.Node,AddedNodes={foreign,nested,direct},RemovedNodes={}});h.Drain()
  check(h.Item.SelectedSource=='second.mp3'and h.Node.NativeAudioResourceState.Gap==3 and table.concat(h.Counts.Requests or{},',')=='rbxassetid://301','Native owner uses HTML expanded names and direct light children while gap counts every child')
  h.Destroy();completed+=1
 end
 for _,kind in {'ready','deferred missing','deferred mapped'}do
  local raw=if kind=='deferred missing'then 'missing.media'else 'first.mp3'
  local h=fixture({HTML='<audio id=v preload='..(if kind=='ready'then 'auto'else 'none')..'><source id=s1 src='..raw..'><source src=second.mp3></audio>',Scripting=false})
  h.Drain();local owner=h.Page.NativeMediaResources;local r=h.Node.NativeAudioResourceState;local epoch=r.SelectionEpoch
  check(h.Item==nil,'Late controls begin with actual control-free AUDIO')
  local oldSound=h.Node.AudioHostSession and h.Node.AudioHostSession.Sound
  h.Node.Attributes.controls='';owner:AttributeChanged(h.Node,'controls','',nil)
  h.Tree:ApplyDOMChanges({[h.Node]={Attributes={controls=true}},[h.Node.Parent]={Children=true,RenderChildren=true}})
  h.Page:RefreshDOMResources();h.Page:RequestAnimationLayout();h.Drain()
  local item=assert(h.Tree.MediaByNode[h.Node]);local sound=item.Sound
  check(item~=h.Item and item.ControlsGui~=nil and item.AudioSession==h.Node.AudioHostSession,'Actual RenderTree creates genuinely new native controls item and attaches retained session')
  check(item.SelectedSource==raw and r.SelectionEpoch==epoch and item.LoadStarted and item.MetadataEmitted==(kind=='ready'),'New native controls recover selected resource and reached metadata flags')
  if kind=='ready'then
   check(sound==oldSound and item.Duration==12 and h.Counts.NativeLoads==1,'Ready control-free resource creates controls without another Sound or IO')
  else
   check(h.Counts.NativeLoads==0 and r.Phase=='deferred'and sound.SoundId==(if kind=='deferred mapped'then 'rbxassetid://300'else ''),'Late deferred binding selects retained first candidate and optional mapping hint without IO')
   local errors=0;h.Page.Events:On(h.Node.Children[1],'error',function()errors+=1 end)
   h.Page:PlayMedia('v');h.Drain()
   check(sound.Playing and h.Counts.NativeLoads==1 and errors==(if kind=='deferred missing'then 1 else 0)and r.SelectionEpoch==epoch,'Late native controls resume the retained first candidate and preserve epoch/Play intent')
  end
  h.Destroy();check(sound.DestroyCalls==1,'New native controls still dispose one retained Sound');completed+=1
 end
 for _,kind in {'nil','false','table'}do
  local payload=if kind=='nil'then nil elseif kind=='false'then false else {Reason='Original injected native owner failure'}
  local h=fixture({HTML='<audio id=v controls preload=auto src=second.mp3></audio><input id=editor value=stable><video id=other controls preload=none src=second.webm></video>',Scripting=false,OwnerResolver=function(page,node,raw)
   if raw=='fail.mp3'then error(payload,0)end;return NativeMediaResources.resolve(page,node,raw)
  end})
  h.Drain();local owner=h.Page.NativeMediaResources;local r=h.Node.NativeAudioResourceState;local sound=h.Native()
  local editorNode=Node.findById(h.Page.Document,'editor');local control=h.Page.FormModel:Resolve(editorNode);local editor=control.Item.Editor
  local video=h.Tree.MediaByNode[Node.findById(h.Page.Document,'other')];local videoNative=video.VideoPlayer or video.VideoGui
  check(h.Page:FocusDOMElement(editorNode),'Actual form takes focus before host exception')
  local p=h.Item.ControlsGui.AbsolutePosition;local point=Vector2.new(p.X+100,p.Y+10)
  check(MediaBox.action(h.Item,point)=='seek'and h.Page.Media:Begin(h.Item,point),'Actual AUDIO seek drag is held before host exception')
  h.Node.Attributes.src='fail.mp3';owner:AttributeChanged(h.Node,'src','fail.mp3',nil)
  local ran,message=h.Step();check(ran==false and message==payload,'Native fail-stop preserves exact original '..kind..' exception payload')
  check(h.Page.Alive and not owner.Alive and owner.Pending==0 and r.Node==nil and r.Candidate==nil and r.Handle==nil,'Host exception clears core/queue/record owner refs without destroying page')
  check(h.Item.Source==nil and h.Item.AudioSession==nil and not MediaBox.canControl(h.Item)and sound.DestroyCalls==1,'Native AUDIO controls disabled and retained Sound destroyed once after host exception')
  check(h.Page.FormModel:Resolve(editorNode)==control and control.Item.Editor==editor and h.Focused()==editor and control.Value=='stable','Native host exception preserves actual form identity/value/focus')
  check(not h.Page.Media:Move(point)and h.Item.PressedAction==nil,'Scoped native AUDIO removal releases held media drag')
  h.Page:SetMediaVolume('other',.4);check(h.Page:GetMediaState('other').Volume==.4 and (video.VideoPlayer or video.VideoGui)==videoNative,'Native AUDIO fail-stop preserves registered VIDEO helper/backend identity')
  for _,operation in {function()h.Page:PauseMedia('v')end,function()h.Page:SetMediaPlaybackRate('v',1.5)end,function()h.Page:SetMediaVolume('v',.5)end,function()h.Page:GetMediaState('v')end}do
   local accepted,reason=pcall(operation);check(not accepted and tostring(reason):find('Native audio owner stopped',1,true)~=nil,'Stopped native AUDIO page helper deliberately rejects without nil native dereference')
  end
  local requests=h.Counts.NativeLoads;h.Drain();check(h.Counts.NativeLoads==requests and sound.DestroyCalls==1,'No stranded queue produces late native IO or duplicate cleanup')
  h.Page.Media:Remove({h.Item});h.Page.Media:Add({h.Item});h.Drain()
  local sounds=0;for _,native in h.Instances do if native.ClassName=='Sound'then sounds+=1 end end
  check(sounds==1 and h.Counts.NativeLoads==requests and h.Item.Sound==nil and h.Item.AudioSession==nil and h.Item.Source==nil and h.Item.LoadFailed and not MediaBox.canControl(h.Item),'Stopped native owner survives structural Add without legacy Sound/IO/control resurrection')
  check(h.Page.FormModel:Resolve(editorNode)==control and h.Focused()==editor and (video.VideoPlayer or video.VideoGui)==videoNative,'Stopped native structural Add preserves Page/form/VIDEO identity')
  h.Destroy();completed+=1
 end
 print('NATIVE_AUDIO_OWNER_BUILD','mountedControls='..completed,'assertions='..checks)
end
