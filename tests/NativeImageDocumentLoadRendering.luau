--!strict
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
  local hits={};local counts={PosterLoads=0,PosterCancelled=0,SVGAdded=0,SVGRemoved=0,SVGJobs=0,NativeLoads=0,NativePlay=0,NativeSoundBind=0,Passes=0,PartialPasses=0,ImageLoads=0}
  local function enqueue(fn,delay)local h={Callback=fn,Due=time+(delay or 0)};table.insert(jobs,h);return h end
  local tasks={spawn=enqueue,defer=enqueue,delay=function(delay,fn)return enqueue(fn,delay)end,cancel=function(h)h.Cancelled=true end,wait=function()time+=.016;if options.WorkWait then options.WorkWait()end end}
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
   if object and object.ClassName=='ImageLabel'and object.Image and(tostring(object.Image):find('101',1,true)or tostring(object.Image):find('102',1,true)or tostring(object.Image):find('109',1,true))then
    counts.PosterLoads+=1;counts.ImageLoads+=1;if options.DelayPoster then table.insert(waiting,coroutine.running());coroutine.yield()end;object.IsLoaded=true;object:GetPropertyChangedSignal('IsLoaded'):Fire()
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
  local mountOptions={MediaFeatures=options.MediaFeatures,JavaScript=options.Scripting~=false,RenderWorkBudgetMS=options.WorkBudget or 0,DocumentLoadStateChanged=options.DocumentCallback,DocumentURL='https://video.test/root/index.html',Images={['wide.png']='101',['tall.png']='102',['bad.png']='109'},SVGs={['wide.svg']='<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100"/></svg>'},Videos={['first.webm']='200',['second.webm']='201'},Audio={['first.mp3']='300',['second.mp3']='301'},JavaScriptServices={VideoServices=options.VideoServices,Task=tasks,Clock=function()return time end,RunService=run,ResourceServices=resources,AudioServices={Task=tasks,Instance=instance,RunService=run,ContentProvider=provider}}}
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





 local expected={'JS-disabled held IMG','NoScript held IMG','display-none IMG','AUDIO fallback IMG','VIDEO fallback IMG','shared asset DOM requests','failed IMG terminal ordering','empty missing unmapped IMG','IMG source generation','IMG PageDestroy','queued new IMG','later IMG stays complete','parent child IMG barrier','nested noRealm IMG barrier','Work4 initial IMG census','Work4 edited IMG discovery',"Responsive resize same candidate","Responsive resize changed candidate","Empty src and srcset null error","Invalid srcset null error","Empty srcset missing src null error","Picture missing src null error"}
 local done,seen=0,{}
 local function mark(name)check(table.find(expected,name)~=nil and not seen[name],'Exact IMG case '..name);seen[name]=true;done+=1;print('NATIVE_IMAGE_DOCUMENT_CONTROL',name)end
 local function states(out)return function(value)check(value=='interactive'or value=='complete','IMG document callback string');table.insert(out,value)end end
 local function ready(out)check(#out==2 and out[1]=='interactive'and out[2]=='complete','IMG document completion once/in order')end
 local function owned(h)return assert(h.Page.NativeImageResources,'Actual native IMG owner')end
 local function node(h,id)return assert(Node.findById(h.Page.Document,id),'Actual IMG '..id)end
 local function listen(h,id,out)
  local n=node(h,id);for _,kind in {'load','error'}do local connection=h.Page.Events:On(n,kind,function(event)table.insert(out,event.Type);check(not h.Page:IsDocumentComplete(),'Node terminal event precedes document complete')end);h.Page:AddCleanup(function()connection:Disconnect()end)end
 end
 local function append(h,id,raw)
  local n=Node.element('img',{id=id,src=raw});n.OwnerDocument=h.Page.Document;local body=assert(Node.findElement(h.Page.Document,function(v)return v.Name=='body'end));Node.append(body,n)
  owned(h):Mutation({Type='childList',Target=body,AddedNodes={n},RemovedNodes={}});return n
 end
 for _,mode in {'JS-disabled','NoScript','display-none','AUDIO fallback','VIDEO fallback'}do
  local out,events={},{};local image='<img id=img src=wide.png width=40 height=20 alt=photo>'
  local html=if mode=='display-none'then '<div style="display:none">'..image..'</div>'elseif mode=='AUDIO fallback'then'<audio>'..image..'</audio>'elseif mode=='VIDEO fallback'then'<video>'..image..'</video>'else image
  local h=fixture({NoScript=mode=='NoScript',Scripting=if mode=='NoScript'then true else false,DelayPoster=true,DocumentCallback=states(out),HTML=html})
  check(h.Realm==nil and owned(h).Pending==1 and not h.Page:IsDocumentComplete(),'Actual no VM and early reserved DOM IMG before any queued IO');listen(h,'img',events);h.Drain()
  check(#h.Waiting==1 and h.Counts.ImageLoads==1 and owned(h).Pending==1 and not h.Page:IsDocumentComplete(),'Actual held mapped IMG retains document delay')
  if mode=='display-none'then
   local image=node(h,'img');local hidden=assert(h.Tree.NodeBoxes[image.Parent]);local item=assert(h.Tree:FindImageItem(image))
   check(hidden.Style.Hidden==true and hidden.Gui.Visible==false,'Actual retained display-none ancestor has hidden style and invisible GUI')
   local surface=item.ImageGui or item.Gui;local underHidden=false
   while surface do if surface==hidden.Gui then underHidden=true;break end;surface=surface.Parent end
   check(underHidden,'Retained IMG surfaces remain under hidden ancestor, with no escaped paint/hit/control presentation')
  elseif mode=='AUDIO fallback'or mode=='VIDEO fallback'then check(h.Tree:FindImageItem(node(h,'img'))==nil,'Unrendered media fallback IMG fetches without an ImageItem')end
  h.Resume();ready(out);check(#events==1 and events[1]=='load'and node(h,'img').ImageResourceState.Status=='loaded'and owned(h).Pending==0,'One successful terminal IMG event and release')
  local visits,requests=owned(h).Stats.Visits,owned(h).Stats.Requests
  node(h,'img').Attributes.class='irrelevant';owned(h):AttributeChanged(node(h,'img'),'class',nil);h.Page:RefreshDOMResources();h.Drain()
  check(owned(h).Stats.Visits==visits and owned(h).Stats.Requests==requests and h.Counts.ImageLoads==1,'Irrelevant paint/resource refresh adds no census/IO')
  h.Destroy();mark(mode..' '..(if mode=='JS-disabled'or mode=='NoScript'then'held IMG'else'IMG'))
 end
 do
  local out={};local h=fixture({Scripting=false,DelayPoster=true,DocumentCallback=states(out),HTML='<img id=one src=wide.png style="object-fit:contain"><img id=two src=wide.png width=40 height=20>'});h.Drain()
  check(h.Realm==nil and owned(h).Pending==2 and #h.Waiting==1 and h.Counts.ImageLoads==1,'Two DOM requests plus optional geometry share one actual ResourceLoadHost job')
  check(node(h,'one').ImageResourceState~=node(h,'two').ImageResourceState,'Each IMG has its own canonical data request')
  h.Resume();ready(out);check(owned(h).Pending==0 and node(h,'one').ImageResourceState.Width==200 and node(h,'two').ImageResourceState.Height==100,'Shared resource completes both logical IMG contributions')
  h.Destroy();mark('shared asset DOM requests')
 end
 do
  local out,events={},{};local h=fixture({Scripting=false,DelayPoster=true,DocumentCallback=states(out),HTML='<img id=img src=bad.png width=40 height=20 alt=bad>'});listen(h,'img',events);h.Drain();check(#h.Waiting==1 and owned(h).Pending==1,'Held failing IMG starts as current request');h.Resume();ready(out)
  check(#events==1 and events[1]=='error'and node(h,'img').ImageResourceState.Status=='error'and owned(h).Pending==0,'Actual mapped decode failure has one terminal task/release');h.Destroy();mark('failed IMG terminal ordering')
 end
 do
  local out,events={},{};local h=fixture({Scripting=false,DocumentCallback=states(out),HTML='<img id=missing><img id=empty src=""><img id=unmapped src=unmapped.png><template id=templ><img id=templateimg src=wide.png></template>'})
  listen(h,'empty',events);listen(h,'unmapped',events);h.Drain();ready(out)
  check(h.Counts.ImageLoads==0 and #events==2 and events[1]=='error'and events[2]=='error'and owned(h).Pending==0,'No native mapped IO for missing/empty/unmapped resources; exact two errors')
  local foreign=Node.element('img',{src='wide.png'});foreign.NamespaceURI='urn:foreign';foreign.OwnerDocument=h.Page.Document;Node.append(node(h,'missing').Parent,foreign);owned(h):Visit(foreign);h.Drain()
  local content=assert(node(h,'templ').Content);local inert=assert(Node.findById(content,'templateimg'))
  check(not owned(h):Owns(foreign)and h.Counts.ImageLoads==0 and not inert.ImageResourceState,'Expanded names/template content do not acquire native requests');h.Destroy();mark('empty missing unmapped IMG')
 end
 do
  local out,events={},{};local h=fixture({Scripting=false,DelayPoster=true,DocumentCallback=states(out),HTML='<img id=img src=wide.png width=40 height=20>'});listen(h,'img',events);h.Drain();local n=node(h,'img');local r=n.ImageResourceState;local generation=r.Generation
  n.Attributes.src='tall.png';owned(h):AttributeChanged(n,'src',nil);check(owned(h).Pending==1 and r.Generation==generation+1,'Replacement never exposes a zero delay');h.Drain();check(#h.Waiting==2 and h.Counts.ImageLoads==2,'Exactly one IO for each current asset attempt')
  h.Resume();check(not h.Page:IsDocumentComplete()and owned(h).Pending==1 and #events==0,'Old held result cannot publish/release current request');h.Resume();ready(out)
  check(#events==1 and events[1]=='load'and r.Raw=='tall.png'and r.URL=='https://video.test/root/tall.png'and r.Width==120 and r.Height==240,'Current URL/source/dimensions are retained generation');h.Destroy();mark('IMG source generation')
 end
 do
  local out,events={},{};local h=fixture({Scripting=false,DelayPoster=true,DocumentCallback=states(out),HTML='<img id=img src=wide.png>'});listen(h,'img',events);h.Drain();local n=node(h,'img');local owner=owned(h);check(#h.Waiting==1,'Actual native preload suspended')
  h.Page:Destroy();check(not owner.Alive and owner.Pending==0 and n.ImageResourceState==nil,'PageDestroy severs canonical request and all owned contributions');h.Resume();check(#out==1 and #events==0 and not h.Page:IsDocumentComplete(),'Late native resume after disposal is inert');h.Destroy();mark('IMG PageDestroy')
 end
 do
  local out={};local h=fixture({Scripting=false,DelayPoster=true,DocumentCallback=states(out),HTML='<p id=plain>empty initially</p>'});check(not h.Page:IsDocumentComplete(),'Empty page completion is queued');append(h,'more','wide.png');check(owned(h).Pending==1,'Additional DOM IMG reserves before old completion task');h.Drain()
  check(#h.Waiting==1 and #out==1 and not h.Page:IsDocumentComplete(),'Queued completion rechecks new IMG reservation');h.Resume();ready(out);h.Destroy();mark('queued new IMG')
 end
 do
  local out={};local h=fixture({Scripting=false,DelayPoster=true,DocumentCallback=states(out),HTML='<p>done first</p>'});h.Drain();ready(out);check(h.Page:IsDocumentComplete(),'Initial empty document reached complete')
  append(h,'later','wide.png');h.Drain();check(#h.Waiting==1 and owned(h).Pending==1 and h.Page:IsDocumentComplete(),'Later IMG cannot rewind the document latch');h.Resume();ready(out);h.Destroy();mark('later IMG stays complete')
 end
 do
  local parent='<video id=v controls preload=none></video><iframe id=frame src=child.html></iframe><input id=editor value="A&#x1f600;BC"><p id=neighbor>retained</p><script>var m=document.getElementById("v"),e=document.getElementById("editor");window.loadSeen=0;window.addEventListener("load",()=>loadSeen++);</script>'
  local h=fixture({HTML=parent,DelayPoster=true,IFrameWebsites={['child.html']={HTML='<img id=leaf src=wide.png>',JavaScript=false}}});h.Drain();h.Page:FlushScriptLayout();h.Drain();local child=h.Page.IFrames[1].ChildPage
  check(h.Realm~=nil and child.JavaScriptRuntime==nil and child.NativeImageResources.Pending==1 and #h.Waiting==1 and not child:IsDocumentComplete()and h.Realm.Window.Get('loadSeen')==0,'Real JS parent respects native no-VM IMG child gate');h.Focus();h.Resume();h.Page:FlushScriptLayout();h.Drain()
  check(child:IsDocumentComplete()and h.Realm.Window.Get('loadSeen')==1 and h.FrameEvents[1].Loads==1,'Real child IMG terminal releases iframe/parent load once');h.Retained();h.Destroy();mark('parent child IMG barrier')
 end
 do
  local out={};local h=fixture({Scripting=false,DelayPoster=true,DocumentCallback=states(out),HTML='<iframe id=frame src=child.html></iframe>',IFrameWebsites={['child.html']={HTML='<iframe src=leaf.html></iframe>',JavaScript=false},['leaf.html']={HTML='<img id=leaf src=wide.png>',JavaScript=false}}});h.Drain()
  local child=h.Page.IFrames[1].ChildPage;local leaf=child.IFrames[1].ChildPage;check(h.Realm==nil and child.JavaScriptRuntime==nil and leaf.JavaScriptRuntime==nil and #h.Waiting==1 and not h.Page:IsDocumentComplete()and not child:IsDocumentComplete()and not leaf:IsDocumentComplete(),'Actual nested no-VM IMG leaf retains all current document stages');h.Resume();ready(out)
  check(h.Page:IsDocumentComplete()and child:IsDocumentComplete()and leaf:IsDocumentComplete(),'Nested terminal wake completes each actual document');h.Destroy();mark('nested noRealm IMG barrier')
 end
 do
  local owner,armed=nil,false;local held={};local tick=0
  local parent='<iframe id=frame src=child.html></iframe><script>window.loadSeen=0;window.addEventListener("load",()=>loadSeen++);</script>'
  local h=fixture({HTML=parent,DelayPoster=true,IFrameWebsites={['child.html']={HTML='<img src=wide.png>',JavaScript=false,WorkBudget=4}},ImageBefore=function(page)owner=page;armed=true end,Clock=function(time)if armed and owner.NativeImageResources then tick+=.005;return time+tick end;return time end,WorkWait=function()if armed then armed=false;table.insert(held,coroutine.running());coroutine.yield('actual native IMG initial census')end end})
  h.Drain();check(#held==1 and owner.JavaScriptRuntime==nil and owner.ScriptInitializationPending and not owner:IsDocumentComplete()and h.Page.IFrameRuntime:PendingCount()==1 and h.Realm.Window.Get('loadSeen')==0,'Actual Work4 census cannot expose zero initial completion')
  local ok,value=coroutine.resume(table.remove(held,1));check(ok,tostring(value));h.Drain();h.Page:FlushScriptLayout();h.Drain();check(#h.Waiting==1 and owner.NativeImageResources.Pending==1,'Current DOM reservation survives initial/native queue gap');h.Resume();h.Page:FlushScriptLayout();h.Drain();check(owner:IsDocumentComplete()and h.Realm.Window.Get('loadSeen')==1,'Work4 current IMG eventually completes once');h.Destroy();mark('Work4 initial IMG census')
 end
 do
  local out={};local h=fixture({Scripting=false,DelayPoster=true,DocumentCallback=states(out),HTML='<p id=plain>old completion queued</p>'})
  local body=assert(Node.findElement(h.Page.Document,function(n)return n.Name=='body'end))
  local added={};for i=1,2 do local div=Node.element('div',{});div.OwnerDocument=h.Page.Document;local img=Node.element('img',{src='wide.png',id='extra'..i});img.OwnerDocument=h.Page.Document;Node.append(div,img);Node.append(body,div);table.insert(added,div)end
  local ticks=0;local waits=0;local work=reference.new(4,{Task={wait=function()waits+=1;coroutine.yield('actual edited IMG Work4 discovery')end},Clock=function()ticks+=.005;return ticks end,Alive=function()return h.Page.Alive end})
  local thread=coroutine.create(function()work:Run(function()owned(h):Mutation({Type='childList',Target=body,AddedNodes=added,RemovedNodes={}})end)end)
  for _=1,80 do
   local ok,value=coroutine.resume(thread);check(ok,tostring(value));if coroutine.status(thread)=='dead'then break end
   check(owned(h).DiscoveryDepth==1,'Whole edited DOM batch owns one discovery transaction before yield');h.Drain()
   check(not h.Page:IsDocumentComplete()and #out==1,'Old queued completion never overtakes still-unscanned IMG while native callbacks/tasks run')
  end
  check(coroutine.status(thread)=='dead'and waits>0 and work.Yields>0,'Actual WorkContext/Task.wait suspended and completed');work:Finish();h.Drain()
  check(owned(h).DiscoveryDepth==0 and owned(h).Pending==2 and #h.Waiting==1 and h.Counts.ImageLoads==1,'Two logical IMG plus one deduplicated job, no fabricated request count')
  h.Resume();ready(out);check(owned(h).Pending==0 and h.Page:IsDocumentComplete(),'Discovery ends only before current requests finish');h.Destroy();mark('Work4 edited IMG discovery')
 end
 do
  local out,events={},{};local h=fixture({Scripting=false,DocumentCallback=states(out),HTML='<base id=base href="https://image.test/one/"><img id=img src=wide.png srcset="wide.png 1x, tall.png 2x">'});listen(h,'img',events);h.Drain();ready(out)
  local n=node(h,'img');local state=n.ImageResourceState;local item=assert(h.Tree:FindImageItem(n));local gui=item.Gui
  local generation,requests,loads,visits,eventCount=state.Generation,owned(h).Stats.Requests,h.Counts.ImageLoads,owned(h).Stats.Visits,#events
  local raw,url,status=state.Raw,state.URL,state.Status
  node(h,'base').Attributes.href='https://image.test/two/'
  for _,width in {750,650,800}do h.Page.Root.AbsoluteSize=Vector2.new(width,600);owned(h):ViewportChanged();h.Drain()end
  check(n.ImageResourceState==state and state.Generation==generation and state.Raw==raw and state.URL==url and state.Status==status,'Same fixed-density selection retains canonical state/generation/URL despite resize and base-only update')
  check(owned(h).Stats.Requests==requests and h.Counts.ImageLoads==loads and #events==eventCount and owned(h).Stats.Visits==visits and owned(h).Pending==0,'Warm same-candidate resize adds no logical/host request, load event or DOM census')
  check(h.Tree:FindImageItem(n)==item and item.Gui==gui and h.Page:IsDocumentComplete(),'Same-source resize retains actual renderer item/GUI and document latch');ready(out);h.Destroy();mark('Responsive resize same candidate')
 end
 do
  local out,events={},{};local h=fixture({Scripting=false,DelayPoster=true,DocumentCallback=states(out),HTML='<picture><source media="(max-width:700px)" srcset=wide.png><img id=img src=tall.png></picture>'});listen(h,'img',events);h.Drain();check(#h.Waiting==1,'Initial picture request held');h.Resume();ready(out)
  local n=node(h,'img');local state=n.ImageResourceState;local item=assert(h.Tree:FindImageItem(n));local gui=item.Gui
  local generation,requests,loads,eventCount=state.Generation,owned(h).Stats.Requests,h.Counts.ImageLoads,#events
  check(state.Raw=='tall.png'and state.Status=='loaded','Initial fixed-density picture candidate')
  h.Page.Root.AbsoluteSize=Vector2.new(650,600);owned(h):ViewportChanged();check(owned(h).Pending==1 and state.Generation==generation+1,'Changed candidate reserves one current request before queued IO');h.Drain()
  check(n.ImageResourceState==state and owned(h).Stats.Requests==requests+1 and h.Counts.ImageLoads==loads+1 and #h.Waiting==1 and #events==eventCount,'Changed picture candidate retains state and produces exactly one new held request, no premature event')
  check(h.Tree:FindImageItem(n)==item and item.Gui==gui and h.Page:IsDocumentComplete(),'Changed candidate retains renderer GUI and latched document stage')
  h.Resume();check(state.Raw=='wide.png'and state.Status=='loaded'and #events==eventCount+1 and events[#events]=='load'and owned(h).Pending==0,'Current changed candidate publishes exactly one terminal load');ready(out)
  local finalGeneration,finalRequests,finalLoads=state.Generation,owned(h).Stats.Requests,h.Counts.ImageLoads
  owned(h):ViewportChanged();h.Drain();check(state.Generation==finalGeneration and owned(h).Stats.Requests==finalRequests and h.Counts.ImageLoads==finalLoads and #events==eventCount+1,'Repeated changed selection becomes a strict no-op');h.Destroy();mark('Responsive resize changed candidate')
 end
 for _,row in {{'Empty src and srcset null error','<img id=img src="" srcset="">'},{'Invalid srcset null error','<img id=img srcset="wide.png 0w">'},{'Empty srcset missing src null error','<img id=img srcset="">'},{'Picture missing src null error','<picture><img id=img></picture>'}}do
  local out,events,ordinary={},{},{};local h=fixture({Scripting=false,DocumentCallback=states(out),HTML=row[2]..'<img id=plain>'});listen(h,'img',events);listen(h,'plain',ordinary);h.Drain();ready(out)
  check(#events==1 and events[1]=='error'and #ordinary==0,'Frozen null-selected source queues one error for src/srcset/picture and none for ordinary missing IMG')
  check(node(h,'img').ImageResourceState.Status=='error'and node(h,'plain').ImageResourceState.Status=='empty'and owned(h).Pending==0 and owned(h).Stats.Requests==0 and h.Counts.ImageLoads==0,'Null source states release exact logical contributions without native IO')
  owned(h):ViewportChanged();h.Drain();check(#events==1 and #ordinary==0 and owned(h).Stats.Requests==0,'Viewport null-source processing retains current result without duplicate terminal tasks');h.Destroy();mark(row[1])
 end
 do
  local events={};local h=fixture({Scripting=false,MediaFeatures={Resolution=2},HTML='<picture><source id=s media="(height >= 500px) and (resolution >= 2dppx)" srcset="wide.png 400w" sizes="200px" width=90><img id=img src=tall.png width=60 height=30></picture>'});listen(h,'img',events);h.Drain()
  local n,s=node(h,'img'),node(h,'s');local state=n.ImageResourceState;local item=assert(h.Tree:FindImageItem(n));local gui,paint,box=item.Gui,item.ImageGui,h.Tree.NodeBoxes[n]
  check(state.Raw=='wide.png'and state.SourceDensity==2 and state.Width==100 and state.Height==50,'Mounted no-realm request uses height/resolution media, environment DPR and density-corrected dimensions')
  check(item.SelectedSource==state.Raw and item.SourceDensity==state.SourceDensity and item.IntrinsicWidth==100 and item.IntrinsicHeight==50 and item.AttributeWidth==90 and item.AttributeHeight==nil,'Mounted native owner and renderer share selected SOURCE and dimension owner')
  local generation,requests,loads=state.Generation,owned(h).Stats.Requests,h.Counts.ImageLoads
  s.Attributes.sizes='400px';owned(h):AttributeChanged(s,'sizes',nil);h.Drain()
  check(state.Generation==generation and owned(h).Stats.Requests==requests and h.Counts.ImageLoads==loads and #events==1 and owned(h).Pending==0,'Loaded density-only change adds no request, generation, load task or document delay')
  check(state.Width==200 and state.Height==100 and item.IntrinsicWidth==200 and item.IntrinsicHeight==100,'Mounted same-resource density update reaches retained image layout')
  check(h.Tree:FindImageItem(n)==item and item.Gui==gui and item.ImageGui==paint and h.Tree.NodeBoxes[n]==box,'Density-only reflow retains actual image GUI/native paint/CSS box')
  s.Attributes.width='120';s.Attributes.height='80';owned(h):AttributeChanged(s,'width',nil);h.Drain()
  check(item.AttributeWidth==120 and item.AttributeHeight==80 and item.ContentWidth==120 and item.ContentHeight==80,'Selected SOURCE dimension mutations update actual retained layout')
  check(state.Generation==generation and owned(h).Stats.Requests==requests and h.Counts.ImageLoads==loads and #events==1,'SOURCE dimension-only mutation never reloads or re-emits the image')
  h.Destroy()
 end
 do
  local events={};local h=fixture({Scripting=false,DelayPoster=true,HTML='<img id=img srcset="wide.png 400w" sizes=100px>'});listen(h,'img',events);h.Drain()
  local n=node(h,'img');local state=n.ImageResourceState;local generation=state.Generation;local requests=owned(h).Stats.Requests
  n.Attributes.sizes='200px';owned(h):AttributeChanged(n,'sizes',nil);h.Drain()
  check(#h.Waiting==1 and state.Generation==generation and owned(h).Stats.Requests==requests and owned(h).Pending==1 and #events==0,'Pending density-only mutation retains one held decoded subscription and document delay')
  h.Resume();local item=assert(h.Tree:FindImageItem(n))
  check(state.SourceDensity==2 and state.Width==100 and state.Height==50 and item.IntrinsicWidth==100 and item.IntrinsicHeight==50 and #events==1 and owned(h).Pending==0,'Pending native completion applies latest candidate density once')
  h.Destroy()
 end
 do
  local h=fixture({Scripting=false,HTML='<img id=img srcset="wide.png -0x">'});h.Drain();local state=node(h,'img').ImageResourceState
  check(state.Raw=='wide.png'and state.Status=='loaded'and state.Width==33554431 and state.Height==33554431 and owned(h).Pending==0,'Valid negative-zero density loads the source and uses the explicit finite intrinsic-size profile')
  h.Destroy()
 end
 check(done==22 and #expected==22,'Exact mounted IMG lifecycle inventory');for _,name in expected do check(seen[name],'Missing IMG case '..name)end
 print('NATIVE_IMAGE_RESPONSIVE_DENSITY','cases=3','scope=actual mounted native no-realm owner, selected SOURCE dimension owner, pending/current density and retained GUI')
 print('NATIVE_IMAGE_DOCUMENT_SUMMARY','cases='..done,'assertions='..checks)
end
