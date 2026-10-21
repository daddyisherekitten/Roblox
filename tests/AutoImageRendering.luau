--!strict
-- Retained HTMLPage fixture derived from NativeImageDocumentLoadRendering.
-- Actual HTMLPage startup, Controller and HTMLScripts; deterministic native
-- metadata/resource completion is distinct from Chrome and Studio pixels.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference,Selection,loadIFrameRuntime,NativeMediaResources,loadImageLoad,loadImageDimensions,NativeImageResources)
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
  options=options or{};local jobs,waiting,created,natives,svgs={}, {},{}, {},{};local focused,time,tree,page=nil,0,nil,nil;local trees,frameEvents={},{}
  local hits={};local counts={PosterLoads=0,PosterCancelled=0,SVGAdded=0,SVGRemoved=0,SVGJobs=0,NativeLoads=0,NativePlay=0,NativeSoundBind=0,Passes=0,PartialPasses=0,ImageLoads=0,DimensionLoads=0}
  local function enqueue(fn,delay)local h={Callback=fn,Due=time+(delay or 0)};table.insert(jobs,h);return h end
  local tasks={spawn=enqueue,defer=enqueue,delay=function(delay,fn)return enqueue(fn,delay)end,cancel=function(h)h.Cancelled=true end,wait=function()time+=.016;if options.WorkWait then options.WorkWait(jobs)end end}
  local factory={}
  function factory.create(class,parent,props)
   local object=table.clone(props or{});object.ClassName,object.Parent=class,parent;if object.Visible==nil then object.Visible=true end
   object.AbsolutePosition,object.AbsoluteSize=Vector2.new(0,0),Vector2.new(800,600);object.AnchorPoint=Vector2.new(0,0);object.Position=object.Position or UDim2.fromOffset(0,0)
   object.BackgroundColor3=object.BackgroundColor3 or Color3.new(1,1,1);object.BackgroundTransparency=object.BackgroundTransparency or 1
   if class=='ImageLabel'then object.IsLoaded=false end
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
    local video,position="",0
    setmetatable(object,{__index=function(_,key)if key=='Video'then return video elseif key=='TimePosition'then return position end end,__newindex=function(self,key,value)
     if key=='Video'then video=value;if options.VideoBindHook then options.VideoBindHook(value)end
     elseif key=='TimePosition'then position=value;if options.PositionHook then options.PositionHook()end
     else rawset(self,key,value)end
    end})
    object.Playing=false;object.TimePosition=0;object.TimeLength=12;object.Resolution=Vector2.new(0,0);object.Loaded,object.Played,object.Paused,object.Ended=signal(),signal(),signal(),signal()
    function object:Play()counts.NativePlay+=1;self.Playing=true;self.Played:Fire()end
    function object:Pause()self.Playing=false;self.Paused:Fire()end
   end
   table.insert(created,object);return object
  end;factory.modifier=factory.create
  local run={Heartbeat=signal(),RenderStepped=signal()};local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),MouseEnabled=true,MouseIcon='',MouseIconEnabled=true}
  function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode(k)return k.Name end
  local instance={new=function(class)
   if class=='VideoPlayer'and options.Modern==false then error('Intentional VideoFrame fallback')end
   local o={ClassName=class,TimePosition=0,TimeLength=12,Resolution=Vector2.new(0,0),IsLoaded=false,IsPlaying=false,Playing=false,DestroyCalls=0,Loaded=signal(),Played=signal(),Paused=signal(),Ended=signal(),DidEnd=signal(),DidLoop=signal(),PlayFailed=signal()};local sigs={}
   function o:GetPropertyChangedSignal(k)sigs[k]=sigs[k]or signal();return sigs[k]end
   function o:LoadAsync()counts.NativeLoads+=1;counts.Requests=counts.Requests or{};table.insert(counts.Requests,self.VideoContent);if options.StatusFail and self.VideoContent=='rbxassetid://200'then self.IsLoaded=true;return'Enum.AssetFetchStatus.Failure'end;if self.VideoContent=='rbxassetid://200'and options.Failure then if options.Failure=='throw'then error('Controlled first video failure')else return end end;if options.DelayVideo then table.insert(waiting,coroutine.running());coroutine.yield()end;if options.ResumeFailure then error('Controlled held video failure')end;self.IsLoaded=true;self.Resolution=Vector2.new(80,40);self:GetPropertyChangedSignal('IsLoaded'):Fire();if options.ThrowAfterReady then error('Controlled postmetadata failure')end end
   function o:Play()counts.NativePlay+=1;self.IsPlaying=true;self.Playing=true;self:GetPropertyChangedSignal('IsPlaying'):Fire();self.Played:Fire()end
   function o:Pause()self.IsPlaying=false;self.Playing=false;self:GetPropertyChangedSignal('IsPlaying'):Fire();self.Paused:Fire()end
   function o:Stop()self:Pause();self.TimePosition=0 end
   function o:Unload()self.IsLoaded=false end
   function o:Destroy()self.DestroyCalls+=1;self.Parent=nil end
   if class=='VideoPlayer'then
    local video,position=nil,o.TimePosition;rawset(o,'TimePosition',nil)
    setmetatable(o,{__index=function(_,key)if key=='VideoContent'then return video elseif key=='TimePosition'then return position end end,__newindex=function(self,key,value)
     if key=='VideoContent'then video=value;if options.VideoBindHook then options.VideoBindHook(value)end
     elseif key=='TimePosition'then position=value;if options.PositionHook then options.PositionHook()end
     else rawset(self,key,value)end
    end})
   end
   if class=='Sound'then
    local soundId='';setmetatable(o,{__index=function(_,k)if k=='SoundId'then return soundId end end,__newindex=function(self,k,v)if k=='SoundId'then soundId=v;counts.NativeSoundBind+=1 else rawset(self,k,v)end end})
   end
   if class=='Frame'then o.AbsoluteSize=Vector2.new(960,540)end
   if options.NativeObject then options.NativeObject(o)end;table.insert(natives,o);return o
  end}
  local provider={PreloadAsync=function(_,list,report)
   local object=list[1]
   if object and object.ClassName=='ImageLabel'and object.Image and(tostring(object.Image):find('101',1,true)or tostring(object.Image):find('102',1,true)or tostring(object.Image):find('109',1,true)or tostring(object.Image):find('110',1,true)or tostring(object.Image):find('111',1,true))then
    counts.PosterLoads+=1;counts.ImageLoads+=1;if options.DelayPoster then table.insert(waiting,coroutine.running());coroutine.yield()end;object.IsLoaded=true;object:GetPropertyChangedSignal('IsLoaded'):Fire()
   elseif object and(object.ClassName=='VideoFrame'or object.ClassName=='Sound')then
    counts.NativeLoads+=1;counts.Requests=counts.Requests or{};local selected=object.SoundId or object.Video;table.insert(counts.Requests,selected);if options.StatusFail and selected=='rbxassetid://200'then object.IsLoaded=true;if report then report(selected,'Enum.AssetFetchStatus.Failure')end;return end;if (selected=='rbxassetid://300'or selected=='rbxassetid://200')and options.Failure then if options.Failure=='throw'then error('Controlled first native preload failure')else object.IsLoaded=false;return end end;if (object.ClassName=='VideoFrame'and options.DelayVideo)or(object.ClassName=='Sound'and options.DelayAudio)then table.insert(waiting,coroutine.running());coroutine.yield()end;if options.ResumeFailure then error('Controlled held native failure')end;object.IsLoaded=true
    if object.ClassName=='VideoFrame'then object.Resolution=Vector2.new(80,40);object.Loaded:Fire()else object.Loaded:Fire()end;if options.ThrowAfterReady then error('Controlled postmetadata failure')end
   end
  end}
  local resources={Task=tasks,ContentProvider=provider,AssetFetchSuccess='Success',CreateImageLabel=function()return factory.create('ImageLabel',nil,{})end,AssetService={CreateEditableImageAsync=function(_,content)
   counts.DimensionLoads+=1
   local raw=tostring(content);local w,h=if raw:find('102',1,true)then 120 else 200,if raw:find('102',1,true)then 240 else 100
   if raw:find('109',1,true)then error('Intentional poster decode failure')end
   return {Size=Vector2.new(w,h),Destroy=function()end}
  end}}
  local services={Task=tasks,RunService=run,ContentProvider=provider,Instance=instance,Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return hits end},Content={none='content:none',fromUri=function(s)return s end},Factory=factory,Clock=function()return time end,PickerLayout=block}
  local renderer=loadRenderTree(factory)
  local svgRuntime={}
  function svgRuntime:AddItems(items)for _,item in items do if not svgs[item]then svgs[item]=true;counts.SVGAdded+=1;local last
   item.UpdateSVG=function()local key=tostring(item.ContentWidth)..':'..tostring(item.ContentHeight);if svgs[item]and key~=last then last=key;counts.SVGJobs+=1 end end
  end end end
  function svgRuntime:RemoveItems(items)for _,item in items do if svgs[item]then svgs[item]=nil;counts.SVGRemoved+=1;item.UpdateSVG=nil end end end
  local noImages={start=function()return nil,{Add=function()end,Remove=function()end,Destroy=function()end}end}
  local actualFrames=loadIFrameRuntime(tasks)
  local actualImages=loadImageLoad(nil,tasks,{AssetFetchStatus={Success='Success'}})
  local actualDimensions=loadImageDimensions(nil,tasks)
  local module=loadHTMLPage({['Rendering/NativeImageResources']={new=function(owner,settings)if options.ImageBefore then options.ImageBefore(owner)end;return NativeImageResources.new(owner,settings)end},['Rendering/NativeMediaResources']={new=function(owner,current,settings)if options.NativeBefore then options.NativeBefore(owner,current)end;return NativeMediaResources.new(owner,current,settings)end},['Rendering/IFrameRuntime']={start=function(owner,current,diagnostic,mount,settings)
   for _,entry in current.IFrameItems or{}do
    local record={Page=owner,Node=entry.Node,Loads=0};table.insert(frameEvents,record)
    local connection=owner.Events:On(entry.Node,'load',function()record.Loads+=1 end);owner:AddCleanup(function()connection:Disconnect()end)
   end
   return actualFrames.start(owner,current,diagnostic,mount,settings)
  end},['Rendering/GuiFactory']=factory,['Layout/WordLayout']=overrides['Layout/WordLayout'],['Layout/TextMeasure']=overrides['Layout/TextMeasure'],['Rendering/ImageDimensions']=actualDimensions,['Rendering/ImageLoad']={start=function(items,alive,diagnostic,changed,settings)local owned=table.clone(settings or{});owned.Task,owned.ContentProvider=tasks,provider;return actualImages.start(items,alive,diagnostic,changed,owned)end},
   ['Rendering/HTMLScripts']={hasScripts=HTMLScripts.hasScripts,ShouldStart=HTMLScripts.ShouldStart,start=function(...)
    if options.StartupCheck then options.StartupCheck((...),counts,tree)end
    if options.DelayVM then
     for _,o in natives do if o.ClassName=='Sound'then check(o.SoundId=='','Managed Sound is empty before delayed real realm initialization')end end
     check(counts.NativeSoundBind==0 and counts.NativeLoads==0 and counts.NativePlay==0,'No legacy audio IO before real realm startup')
     while #jobs>0 do local job=table.remove(jobs,1);if not job.Cancelled then time=math.max(time,job.Due);job.Callback()end end
     check(counts.NativeSoundBind==0 and counts.NativeLoads==0 and counts.NativePlay==0,'Delayed startup tasks do not bind/preload/play legacy audio')
    end
    return HTMLScripts.start(...)
   end},
   ['Rendering/RenderTree']={build=function(document,viewport,diagnostic,...)
    local args=table.pack(...);args[1]=overrides['Layout/FontProfiles'].face;tree=renderer.build(document,viewport,diagnostic,table.unpack(args,1,args.n));trees[document]=tree;return tree
   end},['Layout/BlockLayout']={arrange=function(...)counts.Passes+=1;if tree.DirtyContext and tree.DirtyContext.Reuse then counts.PartialPasses+=1 end;return block.arrange(...)end},
   ['Input/Controller']={start=function(owner,current,layout,diagnostic)return Controller.start(owner,current,layout,diagnostic,services)end},
   ['Rendering/SVGImages']={start=function(owner,current)
    svgRuntime:AddItems(current.SVGItems);owner:AddCleanup(function()local all={};for i in svgs do table.insert(all,i)end;svgRuntime:RemoveItems(all)end);return svgRuntime
   end},
  },tasks,function()return if options.Clock then options.Clock(time)else time end)
  local scripts=if options.Scripting==false or options.NoScript then ''else '<script>var m=document.getElementById("v"),v=m,wide="wide.png",tall="tall.png",clip="one.webm",e=document.getElementById("editor");window.loadSeen=0;window.addEventListener("load",function(){loadSeen++})</script>'
  local html=options.HTML or('<!doctype html><style>body{margin:0}video{display:block}</style><video id="v" muted preload="none" '..(if options.Poster then 'poster="'..options.Poster..'" 'else '')..'></video><input id="editor" tabindex="-1" value="A&#x1f600;BC"><p id="neighbor">retained neighbor</p>'..scripts)
  local mountOptions={MediaFeatures=options.MediaFeatures,JavaScript=options.Scripting~=false,RenderWorkBudgetMS=options.WorkBudget or 0,DocumentLoadStateChanged=options.DocumentCallback,DocumentURL='https://video.test/root/index.html',Images={['wide.png']='101',['tall.png']='102',['bad.png']='109',['small.png']='101',['medium.png']='110',['large.png']='111'},SVGs={['wide.svg']='<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100"/></svg>'},Videos={['first.webm']='200',['second.webm']='201'},Audio={['first.mp3']='300',['second.mp3']='301'},JavaScriptServices={VideoServices=options.VideoServices,Task=tasks,Clock=function()return time end,RunService=run,ResourceServices=resources,AudioServices={Task=tasks,Instance=instance,RunService=run,ContentProvider=provider}}}
  if options.StylesheetOnly then mountOptions.JavaScriptServices.LoadStylesheet=function()return ''end end
  if options.IFrameWebsites then
   mountOptions.IFrameResolver=function(_,reference)
    local key=reference:match('([^/]+)$');local spec=assert(options.IFrameWebsites[key],'Controlled frame reference '..reference)
    return {Kind='internal',Name=key,URL='https://frame.test/'..key,Website={HTML=spec.HTML,Options={JavaScript=spec.JavaScript,RenderWorkBudgetMS=spec.WorkBudget or 0,DocumentLoadStateChanged=spec.DocumentCallback,Images={['wide.png']='101',['bad.png']='109'},Videos={['first.webm']='200',['second.webm']='201'},Audio={['first.mp3']='300',['second.mp3']='301'}}}}
   end
  end
  page=module.mount(factory.create('Frame',factory.create('ScreenGui',nil,{}),{}),html,mountOptions)
  tree=assert(trees[page.Document]);local realm=page.JavaScriptRuntime;local node=Node.findById(page.Document,'v');local item=node and tree.MediaByNode[node]
  local gui,box,frame,display=if item then item.Gui else nil,if item then item.BoxGui else nil,if item then item.VideoGui else nil,if item then item.VideoDisplay else nil
  local function drain()for _=1,(options.DrainBudget or 160)do if #jobs==0 then return end;local job=table.remove(jobs,1);if not job.Cancelled then time=math.max(time,job.Due);local thread=coroutine.create(job.Callback);local ok,message=coroutine.resume(thread);check(ok,tostring(message))end end;error('Presentation queue did not converge')end
  local function resume(noDrain)local thread=table.remove(waiting,1);check(thread~=nil,'Actual suspended resource job');local ok,message=coroutine.resume(thread);check(ok,tostring(message));if not noDrain then drain()end end
  local function script(code,noDrain)check(realm~=nil,'Actual page realm');local ok,message=realm:Run(code);check(ok,tostring(message));page:FlushScriptLayout();if not noDrain then drain()end;check(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
  local function direct(code)local ok,message=realm:Run(code);check(ok,tostring(message));check(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
  local editorRecord
  local function focus()
   script('e.focus();e.setSelectionRange(1,3,"backward")');local c=page.FormModel:Resolve(Node.findById(page.Document,'editor'));editorRecord={Control=c,Editor=c.Item.Editor,Bindings=c.Item.Editor:Connections(),Neighbor=trees[page.Document].NodeBoxes[Node.findById(page.Document,'neighbor')].Gui}
  end
  local function retained()
   check(trees[page.Document].MediaByNode[node]==item and item.Gui==gui and item.BoxGui==box and item.VideoGui==frame and item.VideoDisplay==display,'Retained VIDEO native/render surfaces')
   if editorRecord then local c,e=editorRecord.Control,editorRecord.Editor;check(c.Item.Editor==e and e:Connections()==editorRecord.Bindings and focused==e and c.Value=='A😀BC'and c.SelectionStart==1 and c.SelectionEnd==3 and c.SelectionDirection=='backward'and e.CursorPosition==2 and e.SelectionStart==6,'VIDEO mutation preserves actual editor focus/bindings/UTF16 and byte selection');check(trees[page.Document].NodeBoxes[Node.findById(page.Document,'neighbor')].Gui==editorRecord.Neighbor,'VIDEO retains neighbor GUI')end
  end
  local function geometry(value,label,nativeCase)if math.abs(item.ContentWidth-value.width)>.03 then print('Presentation diagnostic',label,item.PosterSource,item.Poster,item.PosterWidth,item.PosterHeight,item.IntrinsicWidth,page.PosterPendingCount,counts.PosterLoads,tree.DirtyContext and tree.DirtyContext.Ready);for _,d in page.Document.Diagnostics do print(d.Code,d.Message)end end;near(item.ContentWidth,value.width,label..' width');near(item.ContentHeight,value.height,label..' height');states+=1;if nativeCase then nativeStates+=1 end;retained()end
  local function dimensions(w,h,label)check(item.VideoWidth==w and item.VideoHeight==h,label);if realm then script('window.dimensions=JSON.stringify([m.videoWidth,m.videoHeight])');check(realm.Window.Get('dimensions')=='['..w..','..h..']','Actual readonly mounted dimensions')end end
  local function destroy()page:Destroy();drain();check(not page.Alive and page.PosterPendingCount==0,'Actual HTMLPage disposed poster barrier');check(run.Heartbeat:Count()==0 and run.RenderStepped:Count()==0,'Actual page media frame connections disposed');check(input.InputBegan:Count()==0 and input.InputChanged:Count()==0 and input.InputEnded:Count()==0,'Actual Controller disposal');if realm then check(not realm.Alive and not realm.EventLoop.Alive,'Actual realm disposal')end end
  return {Trees=trees,FrameEvents=frameEvents,Page=page,Tree=tree,Item=item,Node=node,Realm=realm,Run=script,Direct=direct,Drain=drain,Resume=resume,Retained=retained,Geometry=geometry,Dimensions=dimensions,Destroy=destroy,Counts=counts,Waiting=waiting,Jobs=jobs,SVG=svgs,Native=function()return item.VideoPlayer or item.VideoGui end,Input=input,SetHits=function(value)hits=value end,Options=options,Focused=function()return focused end,Focus=focus,Instances=natives,Created=created}
 end
 local cases=0
 do
  -- A real cooperative Runtime constructor can yield after the first layout
  -- has been queued. That layout cannot finish the constructor's work owner.
  local owner,inside,waits,passes=nil,false,0,0
  local tick=0
  local h=fixture({WorkBudget=2,Clock=function(time)tick+=.0003;return time+tick end,
   HTML='<p id="neighbor">Popup document</p><script>window.initialized=true</script>',
   StartupCheck=function(page,_,tree)
    owner=page
    check(page.ScriptInitializationPending==true,'Runtime construction is inside the initialization barrier')
    page:RequestAnimationLayout(tree)
   end,
   WorkWait=function(jobs)
    if not owner or not owner.ScriptInitializationPending or inside then return end
    waits+=1;inside=true
    local steps=0
    while #jobs>0 do
     steps+=1;check(steps<64,'Intermediate construction tasks converge')
     local job=table.remove(jobs,1)
     if not job.Cancelled then job.Callback()end
     check(not owner.Presented,'Intermediate layout cannot publish an initializing document')
     check(owner.LoadingWork.Active,'Intermediate layout cannot finish the Runtime construction owner')
    end
    if owner.Root:GetAttribute('Status')=='ready'then passes+=1 end
    inside=false
   end})
  check(waits>0 and passes>0,'Actual construction yield allowed an actual intermediate layout')
  check(h.Page.Alive and h.Realm and h.Realm.Alive,'Mount retains a live realm after the construction yield')
  check(h.Realm.Window.Get('initialized')==true,'Initial author script runs before presentation')
  h.Drain()
  check(h.Page.Presented and not h.Page.ScriptInitializationPending and not h.Page.LoadingWork.Active,'Finished initialization is eventually presented and releases loading work')
  h.Page:RequestAnimationLayout(h.Tree);h.Drain()
  check(h.Page.Alive and h.Realm.Alive,'Subsequent actual layout uses the retained live realm')
  check(#h.Realm.Diagnostics==0,'Intermediate construction has no author diagnostics: '..table.concat(h.Realm.Diagnostics,' | '))
  h.Destroy();cases+=1
 end
 for _,budget in {0,2}do
  local owner,inside=nil,false;local tick=0
  local h=fixture({NoScript=true,WorkBudget=budget,Clock=function(time)tick+=.0003;return time+tick end,
   HTML='<p id="neighbor">Document without scripts</p>',
   StartupCheck=function(page,_,tree)
    owner=page;page:RequestAnimationLayout(tree);reference.checkpoint(true)
   end,
   WorkWait=function(jobs)
    if not owner or not owner.ScriptInitializationPending or inside then return end
    inside=true
    while #jobs>0 do local job=table.remove(jobs,1);if not job.Cancelled then job.Callback()end end
    check(not owner.Presented,'Intermediate no-realm layout also waits for initialization')
    inside=false
   end})
  h.Drain()
  check(h.Realm==nil and h.Page.Presented and (not h.Page.LoadingWork or not h.Page.LoadingWork.Active),'No-realm initialization eventually presents with or without cooperative work')
  h.Destroy();cases+=1
 end
 do
  local h=fixture({NoScript=true,HTML='<p id="neighbor">Closed during initialization</p>',StartupCheck=function(page)page:Destroy()end})
  h.Drain()
  check(not h.Page.Alive and not h.Page.Presented,'Initialization completion never presents a destroyed page')
  h.Destroy();cases+=1
 end
 local function image(h)return assert(Node.findById(h.Page.Document,'img'))end
 local function current(h)return assert(image(h).ImageResourceState)end
 local function kept(h)
  local node=image(h);local item=assert(h.Tree:FindImageItem(node));local gui=item.Gui;local surface=item.ImageGui
  return function()
   check(h.Tree:FindImageItem(node)==item and item.Gui==gui and item.ImageGui==surface,'Responsive selection retains ImageItem/GUI/paint surface')
  end,item
 end
 local function change(h,node,key,value)
  if h.Realm then h.Run('document.getElementById("'..node.Attributes.id..'").setAttribute("'..key..'",'..string.format('%q',value)..')')
  else node.Attributes[key]=value
   local _,items=h.Tree:ApplyDOMChanges({[node]={Attributes={[key]=true}}})
   h.Page.NativeImageResources:AttributeChanged(node,key,nil)
   h.Page:RequestAnimationLayout(h.Tree.NodeBoxes[node]or h.Tree);h.Drain()
  end
 end
 for _,mode in {'disabled','no-realm','realm'}do
  for _,density in {1,2}do
   local script=if mode=='realm'then '<script>window.autoImageTest=true</script>'else ''
   local h=fixture({Scripting=mode~='disabled',NoScript=mode=='no-realm',MediaFeatures={Resolution=density},HTML='<img id=img loading=lazy sizes=auto srcset="small.png 200w, medium.png 400w, large.png 800w" width=200 height=100><p id=neighbor>Kept</p>'..script})
   h.Drain();local state=current(h);local retain,item=kept(h)
   check((h.Realm~=nil)==(mode=='realm'),'Actual requested realm mode')
   check(state.Status=='loaded'and state.Raw==(if density==1 then 'small.png'else'medium.png'),'Initial auto candidate uses committed width and DPR: '..mode)
   check(state.SourceDensity==density and state.Width==200/density and state.Height==100/density,'Natural geometry uses selected source density')
   check(item.ContentWidth==200 and item.ContentHeight==100,'Natural geometry cannot shrink explicit auto layout')
   local requests=h.Counts.ImageLoads;local generation=state.Generation
   if h.Realm then h.Realm.ImageResources:AfterLayout()else h.Page.NativeImageResources:AfterLayout()end;h.Drain()
   check(h.Counts.ImageLoads==requests and state.Generation==generation,'Unchanged layout adds no request or generation')
   change(h,image(h),'style','width:400px;height:100px')
   check(state.Raw==(if density==1 then 'medium.png'else'large.png')and item.ContentWidth==400,'CSS mutation changes auto source after actual layout')
   retain()
   change(h,image(h),'style','display:none;width:100px;height:100px')
   check(state.Raw==(if density==1 then 'medium.png'else'large.png'),'Hidden auto image retains remembered width')
   change(h,image(h),'style','width:200px;height:100px')
   check(state.Raw==(if density==1 then 'small.png'else'medium.png')and item.ContentWidth==200,'Rendering again publishes the new concrete slot')
   retain();h.Destroy();cases+=1
  end
 end
 for _,mode in {'no-realm','realm'}do
  local script=if mode=='realm'then '<script>window.autoImageTest=true</script>'else ''
  local h=fixture({NoScript=mode=='no-realm',HTML='<img id=img loading=lazy sizes=auto srcset="small.png 200w, medium.png 400w, large.png 800w" width=200 height=100 style="position:absolute;top:5000px">'..script})
  h.Drain();local state=current(h)
  check(state.Status=='deferred'and h.Counts.ImageLoads==0 and h.Counts.DimensionLoads==0 and h.Page:IsDocumentComplete(),'Offscreen lazy auto image does not fetch or delay document load: '..mode)
  change(h,image(h),'loading','eager')
  check(state.Status=='loaded'and h.Counts.ImageLoads==1,'Switching loading to eager resumes an offscreen image')
  check(h.Page:IsDocumentComplete(),'Resuming a late lazy image does not rewind document completion')
  h.Destroy();cases+=1
 end
 for _,mode in {'no-realm','realm'}do
  local script=if mode=='realm'then '<script>window.autoImageTest=true</script>'else ''
  local h=fixture({NoScript=mode=='no-realm',HTML='<picture><source id=source srcset="small.png 200w, medium.png 400w, large.png 800w"><img id=img loading=lazy sizes=auto width=350 height=100></picture>'..script})
  h.Drain();local state=current(h);local retain=kept(h)
  change(h,Node.findById(h.Page.Document,'source'),'sizes','(min-width:500px) auto, 800px')
  check(state.Raw=='medium.png'and state.SourceDensity==400/350,'Live SOURCE conditional auto uses current IMG geometry: '..mode)
  change(h,image(h),'sizes','50px')
  check(state.Raw=='large.png'and not h.Tree:FindImageItem(image(h)).Style.AutoImageSize,'Removing IMG auto gate removes UA containment and auto eligibility: '..mode)
  change(h,image(h),'sizes','auto, 50px')
  check(state.Raw=='medium.png'and h.Tree:FindImageItem(image(h)).Style.AutoImageSize,'Restoring IMG auto gate restores current concrete selection: '..mode)
  retain();h.Destroy();cases+=1
 end
 for _,mode in {'no-realm','realm'}do
  local script=if mode=='realm'then '<script>window.autoImageTest=true</script>'else ''
  local h=fixture({NoScript=mode=='no-realm',HTML='<img id=img loading=lazy sizes=auto srcset="small.png 200w, medium.png 400w, large.png 800w" style="position:absolute;top:5000px;object-fit:none">'..script})
  h.Drain();local state=current(h);local retain,item=kept(h)
  check(state.Status=='deferred'and h.Counts.ImageLoads==0 and h.Counts.DimensionLoads==0,'Unconstrained lazy IMG has no speculative metadata fetch: '..mode)
  check(item.ContentWidth==300 and item.ContentHeight==150,'Auto size containment supplies 300x150 before resource decode')
  h.Page.Root.CanvasPosition=Vector2.new(0,4800);h.Page.Root:GetPropertyChangedSignal('CanvasPosition'):Fire();h.Drain()
  check(state.Status=='loaded'and state.Raw=='medium.png'and h.Counts.ImageLoads==1 and h.Counts.DimensionLoads==1,'Actual scroll resumes one DOM image and its shared dimension decode')
  check(item.ContentWidth==300 and item.ContentHeight==150,'Loaded metadata cannot create auto sizing feedback')
  retain();h.Destroy();cases+=1
 end
 for _,fit in {'contain','cover','none'}do
  local h=fixture({Scripting=false,HTML='<img id=img loading=lazy sizes=auto srcset="small.png 200w, medium.png 400w, large.png 800w" style="width:350px;height:100px;object-fit:'..fit..'">'})
  h.Drain();local state=current(h);local _,item=kept(h)
  check(state.Raw=='medium.png'and state.SourceDensity==400/350 and item.ContentWidth==350,'Auto slot follows content width independently of painted object-fit:'..fit)
  h.Destroy();cases+=1
 end
 for _,mode in {'no-realm','realm'}do
  local script=if mode=='realm'then '<script>window.autoImageTest=true</script>'else ''
  local h=fixture({NoScript=mode=='no-realm',HTML='<img id=img loading=lazy sizes=auto srcset="small.png 200w, medium.png 400w, large.png 800w" style="object-view-box:inset(0 25%)">'..script})
  h.Drain();local state=current(h);local retain,item=kept(h)
  check(state.Status=='loaded'and state.Raw=='medium.png'and item.ContentWidth==300 and item.ContentHeight==150,'Auto containment box ignores object-view-box natural crop: '..mode)
  check(item.ImageClip~=nil and item.ImageClip.Size[1]==300 and item.ImageGui.Size[1]==600 and item.ImageGui.Position[1]==-150,'Auto-size preserves the real cropped image paint surface: '..mode)
  retain();h.Destroy();cases+=1
 end
 do
  local h=fixture({Scripting=false,HTML='<picture><source id=source srcset="small.png 200w, medium.png 400w, large.png 800w"><img id=img loading=lazy sizes=auto style="width:50%;height:100px"></picture>'})
  h.Drain();local state=current(h);local retain,item=kept(h)
  check(state.Raw=='medium.png'and state.SourceDensity==400/item.ContentWidth,'Omitted SOURCE sizes inherits auto-size behavior')
  h.Page.Root.AbsoluteSize=Vector2.new(400,600);h.Page.Root:GetPropertyChangedSignal('AbsoluteSize'):Fire();h.Drain()
  check(state.Raw=='small.png'and state.SourceDensity==200/item.ContentWidth,'Viewport resize reevaluates after committed percentage-width layout')
  local count=h.Counts.ImageLoads;h.Page.Root:GetPropertyChangedSignal('AbsoluteSize'):Fire();h.Drain()
  check(h.Counts.ImageLoads==count,'Repeated equal viewport is a no-op')
  retain();h.Destroy();cases+=1
 end
 for _,mode in {'no-realm','realm'}do for _,action in {'replace','destroy'}do
  local script=if mode=='realm'then '<script>window.autoImageTest=true</script>'else ''
  local h=fixture({NoScript=mode=='no-realm',HTML='<img id=img loading=lazy sizes=auto srcset="small.png 200w, large.png 800w" width=200 height=100>'..script})
  h.Drain();local node=image(h);local state=current(h);local generation=state.Generation
  local owner=h.Realm and h.Realm.ImageResources or h.Page.NativeImageResources
  local rendered=h.Page.ImageIsRendered
  h.Page.ImageIsRendered=function(page,target)
   page.ImageIsRendered=rendered
   if action=='destroy'then page:Destroy()else target.Attributes.srcset='medium.png 400w';owner:AttributeChanged(target,'srcset',nil)end
   return {Width=10,Height=10}
  end
  h.Page:RequestAnimationLayout(h.Tree);h.Drain()
  if action=='destroy'then check(not h.Page.Alive and node.ImageResourceState==nil,'Rendering callback cannot resurrect a disposed '..mode..' owner')
  else check(node.ImageResourceState==state and state.Generation==generation+1 and state.Status=='loaded'and state.Raw=='medium.png'and state.SourceDensity==2,'Rendering callback replacement wins over stale auto selection: '..mode)end
  h.Destroy();cases+=1
 end end
 for _,mode in {'no-realm','realm'}do
  local h
  local script=if mode=='realm'then '<script>window.autoImageTest=true</script>'else ''
  h=fixture({NoScript=mode=='no-realm',DocumentCallback=function(state)if state=='complete'then h.Page:Destroy()end end,HTML='<img id=img loading=lazy sizes=auto srcset="small.png 200w, medium.png 400w" style="position:absolute;top:5000px">'..script})
  h.Drain();check(not h.Page.Alive and h.Counts.ImageLoads==0 and h.Counts.DimensionLoads==0,'Document completion reentry disposes deferred auto owner without IO: '..mode)
  h.Destroy();cases+=1
 end
 do
  local h=fixture({Scripting=false,DelayPoster=true,HTML='<img id=img loading=lazy sizes=auto srcset="small.png 200w, medium.png 400w, large.png 800w" width=200 height=100>'})
  h.Drain();local state=current(h);local retain=kept(h)
  check(#h.Waiting==1 and state.Status=='loading'and state.Raw=='small.png','Initial actual auto request can remain held')
  change(h,image(h),'style','width:400px;height:100px')
  check(#h.Waiting==2 and state.Raw=='medium.png','New concrete size replaces held candidate')
  h.Resume();check(state.Status=='loading'and state.Raw=='medium.png','Stale old completion cannot publish over new auto request')
  h.Resume();check(state.Status=='loaded'and state.Raw=='medium.png','Latest candidate publishes after its own completion')
  retain();h.Destroy();cases+=1
 end
 print('Auto image rendering: '..cases..' actual HTMLPage/realm/no-realm controls; '..checks..' assertions; initial/DPR, CSS, hide/show, lazy/eager, resize, pending replacement, identity and cleanup passed')
end
