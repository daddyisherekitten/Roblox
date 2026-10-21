--!strict
-- Actual HTMLPage startup, Controller and HTMLScripts; deterministic native
-- metadata/resource completion is distinct from Chrome and Studio pixels.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference,Selection,loadIFrameRuntime,NativeMediaResources,URLRecord)
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
   return actualFrames.start(owner,current,diagnostic,function(container,html,childOptions)
    local child=mount(container,html,childOptions)
    if options.FrameMounted then options.FrameMounted(owner,child,childOptions)end
    return child
   end,settings)
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
  local mountOptions={JavaScript=options.Scripting~=false,RenderWorkBudgetMS=options.WorkBudget or 0,DocumentLoadStateChanged=options.DocumentCallback,DocumentURL=options.RootURL or 'https://video.test/root/index.html',Images={['wide.png']='101',['tall.png']='102',['bad.png']='109'},SVGs={['wide.svg']='<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100"/></svg>'},Videos={['first.webm']='200',['second.webm']='201'},Audio={['first.mp3']='300',['second.mp3']='301'},JavaScriptServices={VideoServices=options.VideoServices,Task=tasks,Clock=function()return time end,RunService=run,ResourceServices=resources,AudioServices={Task=tasks,Instance=instance,RunService=run,ContentProvider=provider}}}
  for key,value in options.ScriptServices or{}do mountOptions.JavaScriptServices[key]=value end
  if options.StylesheetOnly then mountOptions.JavaScriptServices.LoadStylesheet=function()return ''end end
  if options.FrameResolver then mountOptions.IFrameResolver=options.FrameResolver
  elseif options.IFrameWebsites then
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






 local literal={'Remove child-root nil','Remove child-root false','Remove child-root table','Destroy child-root nil','Destroy child-root false','Destroy child-root table'}
 local seen={};local completed=0
 for _,operation in {'Remove','Destroy'}do for _,kind in {'nil','false','table'}do
  local payload=if kind=='nil'then nil elseif kind=='false'then false else{Original='mounted root'}
  local h=fixture({HTML='<iframe id=a src=a.html></iframe><iframe id=b src=b.html></iframe><p id=neighbor>parent</p><script>window.parentMarker=1</script>',IFrameWebsites={['a.html']={HTML='<input id=child value=one><script>window.childMarker=1;setTimeout(function(){window.future=1},500)</script>',JavaScript=true},['b.html']={HTML='<input id=child value=two><script>window.childMarker=2;setTimeout(function(){window.future=2},500)</script>',JavaScript=true}}})
  h.Drain();local items=h.Trees[h.Page.Document].IFrameItems;check(#items==2,'Actual HTMLPage builds two child iframe items')
  local api=assert(h.Page.IFrameRuntime);local children={items[1].ChildPage,items[2].ChildPage};local roots,realms,calls={},{},{}
  for i,child in children do
   check(child~=nil and child.Alive and child.JavaScriptRuntime~=nil,'Real child PageSession and VM alive before owner teardown');roots[i]=child.Root;realms[i]=child.JavaScriptRuntime;calls[i]=0
   check(realms[i].Window.Get('childMarker')==i,'Real child author initialization finished')
   local original=child.Root.Destroy
   child.Root.Destroy=function(self)
    calls[i]+=1;original(self)
    error(if h.RootFailed then {Secondary='later root'}else payload,0)
   end
  end
  -- The first native root failure is exact nil/false/table; later roots have a
  -- different payload. PageSession.Destroy itself remains the real method.
  local first=true
  for i,child in children do
   local injected=child.Root.Destroy
   child.Root.Destroy=function(self)local isFirst=first;first=false;h.RootFailed=not isFirst;return injected(self)end
  end
  local result=table.pack(pcall(function()if operation=='Remove'then api:Remove(items)else api:Destroy()end end))
  check(result[1]==false and result[2]==payload,'Real child Root.Destroy first payload survives full sibling cleanup')
  for i,child in children do
   check(not child.Alive and not realms[i].Alive and not realms[i].EventLoop.Alive,'Every actual child PageSession/VM stopped before first error escapes')
   check(roots[i].Destroyed and calls[i]==1,'Every captured actual child GUI root destroyed once')
   check(items[i].ChildPage==nil and items[i].Loading==false,'Actual renderer item slots retired before callback failure')
  end
  check(api:PendingCount()==0,'Actual parent no longer counts stopped child documents')
  check(operation~='Destroy'or h.Page.IFrameRuntime==nil,'Actual old owner cleared before teardown callbacks')
  local nativeLoads=h.Counts.NativeLoads;api:Destroy();h.Page:Destroy();h.Drain()
  for i,child in children do check(calls[i]==1 and not child.Alive,'Later actual parent destruction does not close child twice')end
  check(not h.Page.Alive and not h.Realm.Alive and h.Input.InputBegan:Count()==0 and h.Input.InputChanged:Count()==0 and h.Input.InputEnded:Count()==0,'Real parent and Controller finish their separate cleanup')
  check(h.Counts.NativeLoads==nativeLoads,'Obsolete queued work does not initiate native IO after real owner cleanup')
  local name=operation..' child-root '..kind;check(table.find(literal,name)and not seen[name],'Exact mounted lifecycle name');seen[name]=true;completed+=1;print('IFRAME_LIFECYCLE_MOUNTED_CONTROL',name)
 end end
 do
  local captured,creations,dialogs=nil,0,{}
  local leaveOrder,prompts,permit={},{},false
  local h=fixture({HTML='<iframe id=a sandbox="allow-scripts" src=a.html></iframe><iframe id=b sandbox="allow-scripts allow-modals" src=b.html></iframe><script>window.parentMarker=1</script>',
   ScriptServices={RuntimeCreated=function(realm)captured=realm;creations+=1 end,Console=function(_,message)table.insert(leaveOrder,message)end,ConfirmLeave=function(request)table.insert(prompts,request);return permit end,SimpleDialogHost={Show=function(request,complete)table.insert(dialogs,request);complete(true)end}},
   IFrameWebsites={['a.html']={HTML='<script>window.answer=confirm("blocked");window.visibility=[];document.onvisibilitychange=()=>visibility.push(document.visibilityState)</script>',JavaScript=true},['b.html']={HTML='<script>window.answer=confirm("allowed");window.visibility=[];document.onvisibilitychange=()=>visibility.push(document.visibilityState)</script>',JavaScript=true}}})
  h.Drain();local items=h.Trees[h.Page.Document].IFrameItems
  local a,b=items[1].ChildPage.JavaScriptRuntime,items[2].ChildPage.JavaScriptRuntime
  check(creations==1 and captured==h.Realm,'Actual mounted frames cannot overwrite their browser root realm callback')
  check(a.Window.Get('answer')==false and b.Window.Get('answer')==true and #dialogs==1 and dialogs[1].Message=='allowed','Actual iframe sandbox modals policy reaches alert/confirm/prompt Runtime')
  h.Page:SetVisible(false,true);h.Drain()
  -- This fixture's paint helpers do not establish native presentation readiness;
  -- advance actual realm tasks explicitly when checking lifecycle propagation.
  local function value(realm,expression)realm:PumpTasks();realm.EventLoop:Checkpoint();local ok,message=realm:Run('window.hostVisibilityResult='..expression);check(ok,tostring(message));return realm.Window.Get('hostVisibilityResult')end
  check(value(h.Realm,'document.visibilityState')=='visible'and value(a,'document.visibilityState')=='visible'and value(b,'visibility.length')==0,'Presentation staging must not hide parent or nested documents')
  h.Page:SetVisible(false);h.Drain()
  local rootHidden,childHidden,childTrace=value(h.Realm,'document.hidden'),value(a,'document.hidden'),value(b,'visibility.join("|")')
  check(rootHidden==true and childHidden==true and childTrace=='hidden','Actual parent hiding reaches every mounted document: '..tostring(rootHidden)..' '..tostring(childHidden)..' '..tostring(childTrace))
  h.Page:SetVisible(true);h.Drain()
  check(value(a,'visibility.join("|")')=='hidden|visible'and value(b,'visibility.join("|")')=='hidden|visible','Actual parent showing resumes child visibility independently of presentation')
  for index,realm in {h.Realm,a,b}do
   realm.Lifecycle:NotifyUserActivation()
   local ok,message=realm:Run('window.onbeforeunload=event=>{console.log("before:'..index..'");event.preventDefault()};window.onunload=()=>console.log("unload:'..index..'");')
   check(ok,tostring(message))
  end
  check(not h.Page:RequestLeave({Reason='close'})and #prompts==1 and table.concat(leaveOrder,'|')=='before:1','A root cancellation keeps all mounted realms and stops descendant prompts')
  permit=true;table.clear(leaveOrder)
  check(h.Page:RequestLeave({Reason='close'})and #prompts==2,'A leave group shows at most one prompt across the root and descendants')
  check(#leaveOrder==3 and leaveOrder[1]=='before:1','Root beforeunload precedes each descendant notification')
  table.clear(leaveOrder);h.Page:CommitLeave();h.Page:CommitLeave()
  check(#leaveOrder==3 and leaveOrder[3]=='unload:1'and leaveOrder[1]~='unload:1'and leaveOrder[2]~='unload:1','Every descendant unloads before its parent and no realm unloads twice')
  h.Destroy()
 end
 do
  local permit=false;local prompts,unloads=0,{}
  local h=fixture({HTML='<iframe id=child sandbox="allow-scripts allow-modals" src=a.html></iframe><p>Parent</p><script>window.marker=1</script>',
   ScriptServices={ConfirmLeave=function()prompts+=1;return permit end,Console=function(_,message)table.insert(unloads,message)end},
   IFrameWebsites={['a.html']={HTML='<p>Child</p><script>window.marker=1</script>',JavaScript=true}}})
  h.Drain();local item=h.Trees[h.Page.Document].IFrameItems[1];local previous=item.ChildPage;local realm=previous.JavaScriptRuntime
  realm.Lifecycle:NotifyUserActivation();check(realm:Run('window.onbeforeunload=event=>event.preventDefault();window.onunload=()=>console.log("replaced")'),'Child unload handlers installed')
  h.Page.IFrameRuntime:Reload(item);h.Drain()
  check(item.ChildPage==previous and previous.Alive and not item.Loading and prompts==1 and #unloads==0,'Canceled iframe reload retains its realm and clears the load contribution')
  permit=true;h.Page.IFrameRuntime:Reload(item);h.Drain()
  check(item.ChildPage~=previous and not previous.Alive and not realm.Alive and prompts==2 and table.concat(unloads,'|')=='replaced','Accepted iframe replacement unloads and disposes exactly the old realm')
  local removed=item.ChildPage;check(removed.JavaScriptRuntime:Run('window.onbeforeunload=event=>event.preventDefault();window.onunload=()=>console.log("must-not-unload-removal")'),'Removal handlers installed')
  removed.JavaScriptRuntime.Lifecycle:NotifyUserActivation();h.Page.IFrameRuntime:Remove({item});h.Drain()
  check(not removed.Alive and prompts==2 and #unloads==1,'Removing an iframe destroys its document without beforeunload or unload events')
  h.Destroy()
 end
 do
  local h=fixture({HTML='<p>Initial visibility</p><script>window.firstHidden=document.hidden;window.initialVisibilityEvents=0;document.onvisibilitychange=()=>initialVisibilityEvents++;</script>',
   ScriptServices={RuntimeCreated=function(_,page)page:SetDocumentVisible(false)end}})
  h.Drain();h.Realm:PumpTasks();h.Realm.EventLoop:Checkpoint()
  check(h.Realm.Window.Get('firstHidden')==true and h.Realm.Window.Get('initialVisibilityEvents')==0,'A pre-Start host visibility change initializes the first author script without a fake visibility event')
  h.Destroy()
 end
 check(completed==6 and #literal==6,'Exact six real HTMLPage lifecycle controls')
 print('IFRAME_LIFECYCLE_MOUNTED_SUMMARY','cases='..completed,'assertions='..checks)
end
