--!strict
-- Actual HTMLPage startup, Controller and HTMLScripts; deterministic native
-- metadata/resource completion is distinct from Chrome and Studio pixels.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference,Selection,loadIFrameRuntime,NativeMediaResources)
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
  local hits={};local counts={PosterLoads=0,PosterCancelled=0,SVGAdded=0,SVGRemoved=0,SVGJobs=0,NativeLoads=0,NativePlay=0,NativeSoundBind=0,Passes=0,PartialPasses=0}
  local function enqueue(fn,delay)local h={Callback=fn,Due=time+(delay or 0)};table.insert(jobs,h);return h end
  local tasks={spawn=enqueue,defer=enqueue,delay=function(delay,fn)return enqueue(fn,delay)end,cancel=function(h)h.Cancelled=true end,wait=function()time+=.016;if options.WorkWait then options.WorkWait()end end}
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
   if object and object.ClassName=='ImageLabel'and object.Image and(tostring(object.Image):find('101',1,true)or tostring(object.Image):find('102',1,true)or tostring(object.Image):find('109',1,true))then
    counts.PosterLoads+=1;if options.DelayPoster then table.insert(waiting,coroutine.running());coroutine.yield()end
   elseif object and(object.ClassName=='VideoFrame'or object.ClassName=='Sound')then
    counts.NativeLoads+=1;counts.Requests=counts.Requests or{};local selected=object.SoundId or object.Video;table.insert(counts.Requests,selected);if options.StatusFail and selected=='rbxassetid://200'then object.IsLoaded=true;if report then report(selected,'Enum.AssetFetchStatus.Failure')end;return end;if (selected=='rbxassetid://300'or selected=='rbxassetid://200')and options.Failure then if options.Failure=='throw'then error('Controlled first native preload failure')else object.IsLoaded=false;return end end;if (object.ClassName=='VideoFrame'and options.DelayVideo)or(object.ClassName=='Sound'and options.DelayAudio)then table.insert(waiting,coroutine.running());coroutine.yield()end;if options.ResumeFailure then error('Controlled held native failure')end;object.IsLoaded=true
    if object.ClassName=='VideoFrame'then object.Resolution=Vector2.new(80,40);object.Loaded:Fire()else object.Loaded:Fire()end;if options.ThrowAfterReady then error('Controlled postmetadata failure')end
   end
  end}
  local resources={Task=tasks,ContentProvider=provider,AssetFetchSuccess='Success',CreateImageLabel=function()return factory.create('ImageLabel',nil,{})end,AssetService={CreateEditableImageAsync=function(_,content)
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
  local module=loadHTMLPage({['Rendering/NativeMediaResources']={new=function(owner,current,settings)if options.NativeBefore then options.NativeBefore(owner,current)end;return NativeMediaResources.new(owner,current,settings)end},['Rendering/IFrameRuntime']={start=function(owner,current,diagnostic,mount,settings)
   for _,entry in current.IFrameItems or{}do
    local record={Page=owner,Node=entry.Node,Loads=0};table.insert(frameEvents,record)
    local connection=owner.Events:On(entry.Node,'load',function()record.Loads+=1 end);owner:AddCleanup(function()connection:Disconnect()end)
   end
   return actualFrames.start(owner,current,diagnostic,mount,settings)
  end},['Rendering/GuiFactory']=factory,['Layout/WordLayout']=overrides['Layout/WordLayout'],['Layout/TextMeasure']=overrides['Layout/TextMeasure'],['Rendering/ImageDimensions']=noImages,['Rendering/ImageLoad']=noImages,
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
  local scripts=if options.Scripting==false then ''else '<script>var m=document.getElementById("v"),v=m,wide="wide.png",tall="tall.png",clip="one.webm",e=document.getElementById("editor");window.loadSeen=0;window.addEventListener("load",function(){loadSeen++})</script>'
  local html=options.HTML or('<!doctype html><style>body{margin:0}video{display:block}</style><video id="v" muted preload="none" '..(if options.Poster then 'poster="'..options.Poster..'" 'else '')..'></video><input id="editor" tabindex="-1" value="A&#x1f600;BC"><p id="neighbor">retained neighbor</p>'..scripts)
  local mountOptions={JavaScript=options.Scripting~=false,RenderWorkBudgetMS=options.WorkBudget or 0,DocumentLoadStateChanged=options.DocumentCallback,DocumentURL='https://video.test/root/index.html',Images={['wide.png']='101',['tall.png']='102',['bad.png']='109'},SVGs={['wide.svg']='<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100"/></svg>'},Videos={['first.webm']='200',['second.webm']='201'},Audio={['first.mp3']='300',['second.mp3']='301'},JavaScriptServices={VideoServices=options.VideoServices,Task=tasks,Clock=function()return time end,RunService=run,ResourceServices=resources,AudioServices={Task=tasks,Instance=instance,RunService=run,ContentProvider=provider}}}
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





 local expected={
  'VideoPlayer queued completion recheck','VideoFrame queued completion recheck',
  'VideoPlayer later load stays complete','VideoFrame later load stays complete','AUDIO later load stays complete','poster later load stays complete',
  'noRealm parent nested poster','VideoPlayer independent AUDIO plus VIDEO','VideoFrame independent AUDIO plus VIDEO',
  'AUDIO held failure completion','VideoPlayer held failure completion','VideoFrame held failure completion','poster held failure completion',
  'VideoPlayer navigation current generation','VideoFrame navigation current generation','VideoPlayer frame removal stale completion','VideoFrame frame removal stale completion',
  'AUDIO owner stop page completion','VideoPlayer owner stop page completion','VideoFrame owner stop page completion',
  'noRealm callback nil','noRealm callback false','noRealm callback table',
  'NativeAUDIO initial Work4 visit gate','NativeAUDIO Bind PageDestroy','NativeAUDIO Bind owner stop',
  'queued frame completion recheck','VideoPlayer callback navigates','VideoFrame callback navigates','VideoPlayer callback destroys child','VideoFrame callback destroys child',
  'poster completion callback disposes Page','sandbox same-origin no-scripts gate',
 }
 local completed,seen=0,{}
 local function mark(name)check(table.find(expected,name)and not seen[name],'Exact document case '..name);seen[name]=true;completed+=1;print('NO_REALM_DOCUMENT_CONTROL',name)end
 local function states(out)return function(value)check(value=='interactive'or value=='complete','Actual string document state');table.insert(out,value)end end
 local function readyStates(out,label)check(#out==2 and out[1]=='interactive'and out[2]=='complete',label..' callback order/once')end
 local function pending(page)return(page.NativeMediaResources and page.NativeMediaResources.Pending or 0)+(page.Media and page.Media:GetPendingDocumentResources()or 0)+(page.PosterPendingCount or 0)+(page.IFrameRuntime and page.IFrameRuntime:PendingCount()or 0)end
 local function step(h)local job=table.remove(h.Jobs,1);check(job~=nil,'Actual queued page job');if job.Cancelled then return end;local ok,value=coroutine.resume(coroutine.create(job.Callback));check(ok,tostring(value))end
 local function untilIdleGate(h)for _=1,30 do if pending(h.Page)==0 and not h.Page:IsDocumentComplete()then return end;step(h)end;error('No queued completion gap')end
 local function source(h,raw)
  local n=Node.findById(h.Page.Document,'v');n.Attributes.preload='auto';h.Page.Media:Refresh(h.Tree.MediaByNode[n],{preload=true});n.Attributes.src=raw;h.Page.Media:VideoMutation({Type='attributes',Target=n,AttributeName='src',NewValue=raw});h.Page:LoadVideo('v')
 end
 local function iframeLoads(h,page)local n=0;for _,r in h.FrameEvents do if r.Page==page then n+=r.Loads end end;return n end
 local parent='<video id=v controls preload=none></video><iframe id=frame src=child.html></iframe><input id=editor value="A&#x1f600;BC"><p id=neighbor>retained</p><script>var m=document.getElementById("v"),e=document.getElementById("editor");window.loadSeen=0;window.addEventListener("load",()=>loadSeen++);</script>'
 for _,modern in {true,false}do
  local backend=if modern then'VideoPlayer'else'VideoFrame'
  do
   local out={};local h=fixture({Modern=modern,Scripting=false,DelayVideo=true,DocumentCallback=states(out)})
   check(h.Realm==nil and type(h.Page.IsDocumentComplete)=='function','Genuine noRealm page contract');untilIdleGate(h)
   source(h,'first.webm');h.Drain();check(#h.Waiting==1 and pending(h.Page)==1 and not h.Page:IsDocumentComplete()and #out==1,'Queued completion rechecks newer actual VIDEO load')
   h.Resume();check(h.Page:IsDocumentComplete(),'Current data task settles page');readyStates(out,'VIDEO queued recheck');h.Destroy();mark(backend..' queued completion recheck')
  end
  do
   local out={};local h=fixture({Modern=modern,Scripting=false,DelayVideo=true,DocumentCallback=states(out)});h.Drain();check(h.Page:IsDocumentComplete(),'Initial no-source document completes')
   source(h,'first.webm');h.Drain();check(#h.Waiting==1 and pending(h.Page)==1 and h.Page:IsDocumentComplete(),'Later source does not revoke latched complete');h.Resume();readyStates(out,'VIDEO later load');h.Destroy();mark(backend..' later load stays complete')
  end
  do
   local out={};local h=fixture({Modern=modern,Scripting=false,DelayAudio=true,DelayVideo=true,DocumentCallback=states(out),HTML='<audio id=a controls src=first.mp3></audio><video id=v controls src=first.webm></video>'});h.Drain()
   check(h.Realm==nil and #h.Waiting==2 and pending(h.Page)==2 and not h.Page:IsDocumentComplete(),'Independent audio/video both contribute')
   h.Resume();check(#h.Waiting==1 and pending(h.Page)==1 and not h.Page:IsDocumentComplete()and #out==1,'One response cannot complete independent second request');h.Resume();readyStates(out,'Two resources');check(h.Page:IsDocumentComplete(),'Both requests complete current Page');h.Destroy();mark(backend..' independent AUDIO plus VIDEO')
  end
  for _,mode in {'navigation','removal'}do
   local h=fixture({Modern=modern,DelayVideo=true,HTML=parent,IFrameWebsites={['child.html']={HTML='<video id=leaf controls src=first.webm></video>'},['second.html']={HTML='<video id=leaf controls src=second.webm></video>'}}});h.Drain();h.Page:FlushScriptLayout();h.Drain();h.Focus();local frame=h.Tree.IFrameItems[1];local old=frame.ChildPage
   check(old.JavaScriptRuntime==nil and #h.Waiting==1 and h.Page.IFrameRuntime:PendingCount()==1,'Held actual child before navigation/removal')
   if mode=='navigation'then
    old.Navigate('second.html',frame.Node,{Target='_self',SameDocument=false});h.Drain();local current=frame.ChildPage;check(current~=old and not old.Alive and current.JavaScriptRuntime==nil and #h.Waiting==2,'Actual child native navigation creates one new generation and disposes old owner')
    h.Resume();h.Page:FlushScriptLayout();h.Drain();check(frame.ChildPage==current and #h.Waiting==1 and h.Page.IFrameRuntime:PendingCount()==1 and iframeLoads(h,h.Page)==0 and h.Realm.Window.Get('loadSeen')==0,'Old native result cannot complete current frame generation')
    h.Resume();h.Page:FlushScriptLayout();h.Drain();check(iframeLoads(h,h.Page)==1 and h.Realm.Window.Get('loadSeen')==1 and h.Page:IsDocumentComplete(),'Only current child navigation completes once');h.Retained();h.Destroy();mark(backend..' navigation current generation')
   else
    h.Run('document.getElementById("frame").remove()');check(not old.Alive and h.Page.IFrameRuntime:PendingCount()==0 and iframeLoads(h,h.Page)==0,'Real removal cancels child without stale iframe event');h.Resume();h.Page:FlushScriptLayout();h.Drain();check(iframeLoads(h,h.Page)==0 and h.Realm.Window.Get('loadSeen')==1,'Removed child completion is inert while remaining parent completes');h.Retained();h.Destroy();mark(backend..' frame removal stale completion')
   end
  end
 end
 do
  local out={};local h=fixture({Scripting=false,DelayAudio=true,DocumentCallback=states(out),HTML='<audio id=a controls preload=none src=first.mp3></audio>'});h.Drain();check(h.Realm==nil and h.Page:IsDocumentComplete()and #h.Waiting==0,'NoRealm None begins complete')
  h.Page:PlayMedia('a');h.Drain();check(#h.Waiting==1 and h.Page.NativeMediaResources.Pending==1 and h.Page:IsDocumentComplete(),'Actual Play starts AUDIO without reopening document');h.Resume();readyStates(out,'AUDIO later play');h.Destroy();mark('AUDIO later load stays complete')
 end
 do
  local out={};local h=fixture({Scripting=false,DelayPoster=true,DocumentCallback=states(out)});h.Drain();check(h.Page:IsDocumentComplete(),'No poster initially complete');h.Page:LoadVideoPoster(h.Item,'wide.png');h.Drain();check(#h.Waiting==1 and h.Page.PosterPendingCount==1 and h.Page:IsDocumentComplete(),'Later poster keeps completion latch');h.Resume();readyStates(out,'Later poster');h.Destroy();mark('poster later load stays complete')
 end
 do
  local rootStates,childStates,leafStates={},{},{};local h=fixture({Scripting=false,DelayPoster=true,DocumentCallback=states(rootStates),HTML='<iframe id=frame src=child.html></iframe>',IFrameWebsites={['child.html']={HTML='<iframe id=nested src=leaf.html></iframe>',DocumentCallback=states(childStates)},['leaf.html']={HTML='<video id=leaf controls preload=none poster=wide.png></video>',DocumentCallback=states(leafStates)}}});h.Drain();local child=h.Page.IFrames[1].ChildPage;local leaf=child.IFrames[1].ChildPage
  check(h.Realm==nil and child.JavaScriptRuntime==nil and leaf.JavaScriptRuntime==nil and #h.Waiting==1 and not leaf:IsDocumentComplete()and not child:IsDocumentComplete()and not h.Page:IsDocumentComplete(),'Three actual absent-VM Pages retain leaf poster contribution')
  check(iframeLoads(h,h.Page)==0 and iframeLoads(h,child)==0,'Nested frames do not emit before leaf');h.Resume();readyStates(rootStates,'Root');readyStates(childStates,'Child');readyStates(leafStates,'Leaf');check(h.Page:IsDocumentComplete()and child:IsDocumentComplete()and leaf:IsDocumentComplete()and iframeLoads(h,h.Page)==1 and iframeLoads(h,child)==1,'Each nested Page/frame completes once without a VM');h.Destroy();mark('noRealm parent nested poster')
 end
 for _,kind in {'AUDIO','VideoPlayer','VideoFrame','poster'}do
  local out={};local html=if kind=='AUDIO'then'<audio id=a controls src=first.mp3></audio>'elseif kind=='poster'then'<video id=v controls preload=none poster=bad.png></video>'else'<video id=v controls src=first.webm></video>'
  local h=fixture({Scripting=false,Modern=kind~='VideoFrame',DelayAudio=kind=='AUDIO',DelayVideo=kind~='AUDIO'and kind~='poster',DelayPoster=kind=='poster',DocumentCallback=states(out),HTML=html});h.Drain();check(#h.Waiting==1 and pending(h.Page)==1 and not h.Page:IsDocumentComplete(),'Real held request before controlled failure')
  if kind~='poster'then h.Options.ResumeFailure=true end;h.Resume();check(pending(h.Page)==0 and h.Page:IsDocumentComplete(),'Current error releases owned document contribution');readyStates(out,'Failure');h.Destroy();mark(kind..' held failure completion')
 end
 for _,kind in {'AUDIO','VideoPlayer','VideoFrame'}do
  local out={};local html=if kind=='AUDIO'then'<audio id=a controls src=first.mp3></audio>'else'<video id=v controls src=first.webm></video>'
  local h=fixture({Scripting=false,Modern=kind~='VideoFrame',DelayAudio=kind=='AUDIO',DelayVideo=kind~='AUDIO',DocumentCallback=states(out),HTML=html});h.Drain();check(#h.Waiting==1 and not h.Page:IsDocumentComplete(),'Current request holds before owner stop')
  if kind=='AUDIO'then h.Page.NativeMediaResources:Destroy()else h.Page.Media:Destroy()end;h.Drain();check(pending(h.Page)==0 and h.Page:IsDocumentComplete(),'Owner-only stop wakes current living Page without layout');h.Resume();readyStates(out,'Owner stop');h.Destroy();mark(kind..' owner stop page completion')
 end
 for _,kind in {'nil','false','table'}do
  local payload=if kind=='nil'then nil elseif kind=='false'then false else{Original='NoRealm complete callback'};local called=0
  local h=fixture({Scripting=false,DocumentCallback=function(value)if value=='complete'then called+=1;error(payload,0)end end});local caught=false
  for _=1,80 do if #h.Jobs==0 then break end;local job=table.remove(h.Jobs,1);if not job.Cancelled then local ok,value=coroutine.resume(coroutine.create(job.Callback));if not ok then check(not caught and value==payload,'Exact first noRealm callback '..kind);caught=true end end end
  check(caught and called==1 and h.Page:IsDocumentComplete(),'Callback error cannot repeat or revoke reached completion');h.Page:DocumentResourcesChanged();h.Drain();check(called==1,'No duplicate completion after callback failure');h.Destroy();mark('noRealm callback '..kind)
 end
 do
  local out={};local spec={HTML='<p>initially empty</p>'};local h=fixture({Scripting=false,Modern=true,DelayVideo=true,DocumentCallback=states(out),HTML='<iframe id=frame src=child.html></iframe>',IFrameWebsites={['child.html']=spec}});untilIdleGate(h)
  local frame=h.Page.IFrames[1];local old=frame.ChildPage;check(old:IsDocumentComplete()and iframeLoads(h,h.Page)==1,'First actual frame is complete while parent completion remains queued')
  spec.HTML='<video id=leaf controls src=first.webm></video>';h.Page.IFrameRuntime:Reload(frame);h.Drain();check(frame.ChildPage~=old and not old.Alive and #h.Waiting==1 and h.Page.IFrameRuntime:PendingCount()==1 and not h.Page:IsDocumentComplete(),'Queued noRealm parent completion rechecks newer actual frame generation')
  h.Resume();readyStates(out,'Queued new frame');check(h.Page:IsDocumentComplete()and iframeLoads(h,h.Page)==2,'One parent completion after two distinct frame generations');h.Destroy();mark('queued frame completion recheck')
 end
 for _,modern in {true,false}do
  local backend=if modern then'VideoPlayer'else'VideoFrame'
  for _,mode in {'navigates','destroys child'}do
   local h,entered,old=nil,false,nil;local values={};local spec={HTML='<video id=leaf controls src=first.webm></video>'}
   spec.DocumentCallback=function(value)
    check(value=='interactive'or value=='complete','Preserved original child string callback');table.insert(values,value)
    if value=='complete'and not entered then entered=true;old=h.Page.IFrames[1].ChildPage
     if mode=='navigates'then old.Navigate('second.html',h.Page.IFrames[1].Node,{Target='_self',SameDocument=false})else old:Destroy()end
    end
   end
   h=fixture({HTML=parent,Modern=modern,DelayVideo=true,IFrameWebsites={['child.html']=spec,['second.html']={HTML='<video id=leaf controls src=second.webm></video>'}}});h.Drain();h.Page:FlushScriptLayout();h.Drain();check(#h.Waiting==1 and h.Page.IFrameRuntime:PendingCount()==1,'Current child before callback reentry');h.Resume();h.Page:FlushScriptLayout();h.Drain()
   check(entered and not old.Alive and #values==2 and values[1]=='interactive'and values[2]=='complete'and iframeLoads(h,h.Page)==0,'Previous callback can navigate/destroy before iframe load without stale old notification')
   if mode=='navigates'then check(#h.Waiting==1 and h.Page.IFrameRuntime:PendingCount()==1 and h.Realm.Window.Get('loadSeen')==0,'Callback replacement retains only newer generation');h.Resume();h.Page:FlushScriptLayout();h.Drain();check(iframeLoads(h,h.Page)==1 and h.Realm.Window.Get('loadSeen')==1,'Only callback-created new frame completes')
   else check(#h.Waiting==0 and h.Page.IFrameRuntime:PendingCount()==0 and h.Realm.Window.Get('loadSeen')==1,'Callback-disposed child releases parent without iframe load')end
   h.Destroy();mark(backend..' callback '..mode)
  end
 end
 do
  local h,done=nil,0;local hoptions={Scripting=false,DelayPoster=true,HTML='<video id=v controls preload=none poster=wide.png></video>'}
  hoptions.DocumentCallback=function(value)check(value=='interactive'or value=='complete','Actual poster Page callback string');if value=='complete'then done+=1;h.Page:Destroy()end end
  h=fixture(hoptions);h.Drain();check(#h.Waiting==1 and not h.Page:IsDocumentComplete(),'Actual noRealm poster before completion callback disposal');h.Resume();check(done==1 and not h.Page.Alive and h.Page.PosterPendingCount==0 and not h.Page:IsDocumentComplete(),'Poster wake completes once then disposal retires current Page');h.Destroy();mark('poster completion callback disposes Page')
 end
 do
  local h=fixture({HTML=string.gsub(parent,'id=frame src=child.html','id=frame sandbox="allow-same-origin" src=child.html'),DelayAudio=true,IFrameWebsites={['child.html']={HTML='<audio id=leaf controls src=first.mp3></audio><script>throw new Error("Sandbox child must not run")</script>'}}});h.Drain();h.Page:FlushScriptLayout();h.Drain();local child=h.Page.IFrames[1].ChildPage
  check(child.JavaScriptRuntime==nil and #h.Waiting==1 and child.NativeMediaResources.Pending==1 and h.Page.IFrameRuntime:PendingCount()==1 and iframeLoads(h,h.Page)==0,'Real sandbox disallows script while same-origin native resource still contributes');h.Resume();h.Page:FlushScriptLayout();h.Drain();check(iframeLoads(h,h.Page)==1 and h.Realm.Window.Get('loadSeen')==1,'Sandbox resource completion releases once without creating VM');h.Destroy();mark('sandbox same-origin no-scripts gate')
 end
 do
  local owner,armed=nil,false;local held={};local tick=0;local out={}
  local h=fixture({HTML=parent,DelayAudio=true,IFrameWebsites={['child.html']={HTML='<audio id=leaf controls src=first.mp3></audio>',WorkBudget=4,DocumentCallback=states(out)}},NativeBefore=function(page)owner=page;armed=true end,Clock=function(time)if armed and owner.NativeMediaResources then tick+=.005;return time+tick end;return time end,WorkWait=function()if armed then armed=false;table.insert(held,coroutine.running());coroutine.yield('actual NativeAUDIO initial visit')end end})
  h.Drain();check(#held==1 and owner.JavaScriptRuntime==nil and owner.ScriptInitializationPending and not owner:IsDocumentComplete()and h.Page.IFrameRuntime:PendingCount()==1 and iframeLoads(h,h.Page)==0,'Initial actual Work4 visit remains blocked by existing Page startup, no speculative lease')
  local ok,value=coroutine.resume(table.remove(held,1));check(ok,tostring(value));h.Drain();h.Page:FlushScriptLayout();h.Drain();check(#h.Waiting==1 and owner.NativeMediaResources.Pending==1 and #out==1,'Existing audio pending reserved before selection/native wait');h.Resume();h.Page:FlushScriptLayout();h.Drain();readyStates(out,'Work4 child');check(iframeLoads(h,h.Page)==1,'Work4 child completes once after current request');h.Destroy();mark('NativeAUDIO initial Work4 visit gate')
 end
 for _,mode in {'PageDestroy','owner stop'}do
  local owner,stopped,object=nil,false,nil;local out={}
  local h=fixture({Scripting=false,HTML='<audio id=a controls src=first.mp3></audio>',DocumentCallback=states(out),NativeBefore=function(page)owner=page end,NativeObject=function(value)if value.ClassName=='Sound'and not stopped then stopped=true;object=value;if mode=='PageDestroy'then owner:Destroy()else owner.NativeMediaResources:Destroy()end end end})
  h.Drain();check(stopped and h.Counts.NativeLoads==0 and #h.Waiting==0 and object.DestroyCalls==1,'Initial Bind reentry returns no stale backend/IO and disposes one fresh Sound')
  if mode=='PageDestroy'then check(not h.Page.Alive and #out==0 and not h.Page:IsDocumentComplete(),'Destroyed Page never publishes document callbacks')else check(h.Page.Alive and h.Page:IsDocumentComplete()and h.Page.NativeMediaResources.Pending==0,'Stopped native owner does not revive but Page settles');readyStates(out,'Stopped bind')end
  h.Destroy();mark('NativeAUDIO Bind '..mode)
 end
 check(completed==33 and #expected==33,'Exact additional noRealm document inventory');for _,name in expected do check(seen[name],'Missing document case '..name)end
 print('NO_REALM_DOCUMENT_SUMMARY','cases='..completed,'assertions='..checks)
end
