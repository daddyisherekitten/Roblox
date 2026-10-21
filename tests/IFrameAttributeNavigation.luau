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





 local expected={
  'src changes','same src setter','coalesced src setters','src removed','src empty','src invalid',
  'srcdoc priority','empty srcdoc','same srcdoc setter','srcdoc removal uses current src',
  'fragment retains document','same fragment setter','base alone no navigation','relative setter after base change',
  'setter captures base before later mutation','sandbox applies next navigation','superseded held document','ancestor URL prevents recursive navigation',
  'before initial defer supersedes source','same-value content attribute source','same-value content attribute srcdoc',
  'namespace source is inert','unrelated attributes do not navigate','detached source before removal flush',
  'fragment retained child next navigation','fragment retained child completion','queued parent completion sees source mutation',
  'navigation disposal cancels queued child','resolver reentry source wins','resolver reentry page destroy',
  'constructor reentry source wins','constructor reentry removal','current source document base after earlier write',
  'held child completes before queued fragment','held child completes before rejected ancestor',
  'child Realm hash parent fragment and reload',
  'two item Add owner stop first wake','two item Add page stop first wake','live child navigation beats queued parent src','live child navigation beats held parent src',
 }
 local seen,completed={},0
 local function mark(name)check(table.find(expected,name)and not seen[name],'Exact frame attribute case '..name);seen[name]=true;completed+=1;print('IFRAME_ATTRIBUTE_CONTROL',name)end
 check(#reference.cases==18,'Original native18 cases preserved')
 local rawStates=0
 for i,case in reference.cases do check(case.name==expected[i],'Exact native case '..case.name);rawStates+=#case.states end
 check(rawStates==44,'Original native44 states preserved')
 local origin='https://frame.test';local rootURL=origin..'/parent'
 local html='<base id=b href="'..origin..'/one/"><iframe id=frame src=a.html></iframe><input id=editor tabindex=-1 value="A&#x1f600;BC"><p id=neighbor>retained</p><script>var f=document.getElementById("frame"),b=document.getElementById("b"),e=document.getElementById("editor"),origin="'..origin..'";window.loadSeen=0;window.addEventListener("load",function(){loadSeen++})</script>'
 local function create(extra)
  extra=extra or{};local resolution={};local settings={HTML=extra.HTML or html,RootURL=extra.RootURL or rootURL,Modern=true,DelayVideo=extra.DelayVideo,DocumentCallback=extra.DocumentCallback,WorkBudget=extra.WorkBudget,Clock=extra.Clock,WorkWait=extra.WorkWait,FrameMounted=extra.Mounted}
  settings.FrameResolver=function(base,raw)
   table.insert(resolution,{Base=base,Raw=raw})
   if extra.Resolve then extra.Resolve(base,raw)end
   local url,record=URLRecord.resolve(raw,base)
   local content=if extra.Content then extra.Content(url)else '<div id=child>'..record.Path..'</div><div id=mark>target</div><script>document.documentElement.dataset.script="ran"</script>'
   return {Kind='internal',Name=record.Path,URL=url,Fragment=record.Fragment or'',Website={HTML=content,Options={DocumentLoadStateChanged=extra.ChildCallback,JavaScript=extra.ChildScripting,RenderWorkBudgetMS=extra.ChildWorkBudget or 0,Videos={['first.webm']='200',['second.webm']='201'}}}}
  end
  local h=fixture(settings)
  h.Resolution=resolution
  local frameNode=Node.findById(h.Page.Document,'frame')
  function h.Frame()return h.Trees[h.Page.Document].IFrameItems[1]end
  function h.Loads()local n=0;for _,r in h.FrameEvents do if r.Page==h.Page and r.Node==frameNode then n+=r.Loads end end;return n end
  function h.Keep()
   local frame=h.Frame();h.FrameIdentity={Item=frame,Gui=frame.Gui,Content=frame.ContentGui};h.Focus()
   local c=h.Page.FormModel:Resolve(Node.findById(h.Page.Document,'editor'));h.EditorIdentity={Control=c,Gui=c.Item.Editor,Bindings=c.Item.Editor:Connections(),Neighbor=h.Trees[h.Page.Document].NodeBoxes[Node.findById(h.Page.Document,'neighbor')].Gui}
  end
  function h.Retain()
   local frame=h.Frame();local i=h.FrameIdentity;check(frame==i.Item and frame.Gui==i.Gui and frame.ContentGui==i.Content,'Frame item and GUI retained across navigation')
   local c,e=h.EditorIdentity.Control,h.EditorIdentity.Gui
   check(c.Item.Editor==e and e:Connections()==h.EditorIdentity.Bindings and h.Focused()==e and c.Value=='A😀BC'and c.SelectionStart==1 and c.SelectionEnd==3 and c.SelectionDirection=='backward'and e.CursorPosition==2 and e.SelectionStart==6,'Frame mutation preserves editor focus/bindings/UTF16')
   check(h.Trees[h.Page.Document].NodeBoxes[Node.findById(h.Page.Document,'neighbor')].Gui==h.EditorIdentity.Neighbor,'Frame mutation retains parent neighbor GUI')
  end
  function h.Initial()h.Drain();h.Page:FlushScriptLayout();h.Drain();check(h.Frame().ChildPage~=nil and h.Loads()==1 and h.Realm.Window.Get('loadSeen')==1,'Actual initial frame and parent load once');h.Keep()end
  return h
 end
 local function url(h,want)check(h.Frame().CurrentURL==want,'Actual child URL '..want..' != '..tostring(h.Frame().CurrentURL));check(h.Frame().ChildPage.DocumentURL==want,'Current internal HTMLPage URL equals current frame')end
 local function change(name,code,want,stable)
  local h=create();h.Initial();local old=h.Frame().ChildPage;local n=h.Loads();h.Run(code)
  url(h,want);check((h.Frame().ChildPage==old)==stable,'Exact child identity for '..name);check(h.Loads()==n+(if stable then 0 else 1),'Exact frame event count for '..name)
  check(stable or not old.Alive,'Superseded child disposed');check(h.Realm.Window.Get('loadSeen')==1,'Later frame navigation does not repeat parent load');h.Retain();h.Destroy();mark(name)
 end
 local nativeMappedStates=0
 local browserOrigin=assert(reference.cases[1].states[1].value.url:match('^(https?://[^/]+)'))
 local function mapped(value)
  if type(value)=='string'and value:sub(1,#browserOrigin)==browserOrigin then return origin..value:sub(#browserOrigin+1)end
  return value
 end
 local function targetState(case,state)
  if case.name=='src invalid'and state.name=='action1'then local e=table.clone(state.value);e.url='about:blank';return e end
  if case.name=='ancestor URL prevents recursive navigation'and state.name=='action1'then
   local e=table.clone(case.states[1].value);e.srcAttribute=state.value.srcAttribute;e.srcGetter=state.value.srcGetter;return e
  end
  return state.value
 end
 local function compareNative(h,case,state)
  local e=targetState(case,state);local frame=h.Frame();local child=assert(frame.ChildPage)
  h.Direct('window.__srcAttribute=f.getAttribute("src");window.__srcGetter=f.src;window.__srcdocAttribute=f.getAttribute("srcdoc");window.__sandbox=f.getAttribute("sandbox");window.__base=document.baseURI;window.__s0=e.selectionStart;window.__s1=e.selectionEnd;window.__sd=e.selectionDirection')
  for _,key in{'srcAttribute','srcGetter','srcdocAttribute','sandbox','base'}do
   local actual=h.Realm.Window.Get('__'..key);if actual==h.Realm.VM.Model.Null then actual=nil end
   check(actual==mapped(e[key]),'Raw mapped '..case.name..' '..state.name..' '..key)
  end
  h.DocumentIDs=h.DocumentIDs or{};h.DocumentSerial=h.DocumentSerial or 1
  if not h.DocumentIDs[child.Document]then h.DocumentSerial+=1;h.DocumentIDs[child.Document]=h.DocumentSerial end
  check(h.DocumentIDs[child.Document]==e.documentID,'Raw document identity sequence '..case.name..' '..state.name)
  check(child.DocumentURL==mapped(e.url),'Raw mapped child URL '..case.name..' '..state.name)
  check((if child:IsDocumentComplete()then 'complete'else 'interactive')==e.ready,'Raw mapped current internal child completion '..case.name..' '..state.name)
  local childNode=Node.findById(child.Document,'child');local body=Node.findElement(child.Document,function(n)return n.Name=='body'end)
  check((if childNode then Node.textContent(childNode)else if body then Node.textContent(body)else '')==e.text,'Raw mapped child text '..case.name..' '..state.name)
  local root=Node.findElement(child.Document,function(n)return n.Name=='html'end)
  check((root and root.Attributes['data-script'])==e.script,'Raw child script/sandbox state '..case.name..' '..state.name)
  check(h.Loads()==e.loads and h.Realm.Window.Get('loadSeen')==e.parentLoads,'Raw frame and latched parent load counts '..case.name..' '..state.name)
  check((h.Focused()==h.EditorIdentity.Gui)==e.focused,'Raw retained input focus '..case.name..' '..state.name)
  check(h.Realm.Window.Get('__s0')==e.selection[1]and h.Realm.Window.Get('__s1')==e.selection[2]and h.Realm.Window.Get('__sd')==e.selection[3],'Raw input selection '..case.name..' '..state.name)
  nativeMappedStates+=1
 end
 for i,case in reference.cases do
  local h;h=create({RootURL=rootURL..'?case='..tostring(i-1),Resolve=function(_,raw)
   if raw=='held.html'then table.insert(h.Waiting,coroutine.running());coroutine.yield('actual held iframe resolver')end
  end})
  h.Initial();compareNative(h,case,case.states[1])
  for index=2,#case.states do
   local state=case.states[index]
   if state.name=='old response released'then h.Resume()
   elseif state.action=='f.contentWindow.location.hash="other"'then
    -- Public iframe.contentWindow remains open. This native action is routed
    -- to the existing real child Realm, never a fabricated window facade.
    local child=h.Frame().ChildPage;local ok,message=child.JavaScriptRuntime:Run('location.hash="other"');check(ok,tostring(message));child:FlushScriptLayout();h.Drain()
   else h.Run(state.action)end
   compareNative(h,case,state);h.Retain()
  end
  h.Destroy();mark(case.name)
 end
 check(nativeMappedStates==44,'Every original native state executes against the actual mounted page on the named axes')
 do local h=create();check(h.Realm~=nil and h.Frame().ChildPage==nil and #h.Resolution==0,'Actual Realm exists before queued initial frame mount');h.Direct('f.src="b.html"');check(h.Page.IFrameRuntime:PendingCount()==1,'New source reserves pending before queued initial task');h.Drain();h.Page:FlushScriptLayout();h.Drain();url(h,origin..'/one/b.html');check(#h.Resolution==1 and h.Loads()==1,'Superseded initial task does not resolve or double-mount');h.Destroy();mark('before initial defer supersedes source')end
 change('same-value content attribute source','f.setAttribute("src","a.html")',origin..'/one/a.html',false)
 do local h=create();h.Initial();h.Run('f.setAttribute("srcdoc","<p>same</p>")');local old=h.Frame().ChildPage;local n=h.Loads();h.Run('f.setAttribute("srcdoc",f.getAttribute("srcdoc"))');check(h.Frame().ChildPage~=old and not old.Alive and h.Loads()==n+1,'Same-value srcdoc content mutation survives absent paint diff');h.Retain();h.Destroy();mark('same-value content attribute srcdoc')end
 change('namespace source is inert','f.setAttributeNS("urn:test","x:src","b.html")',origin..'/one/a.html',true)
 change('unrelated attributes do not navigate','f.title="changed";f.setAttribute("class","changed");f.style.borderColor="red"',origin..'/one/a.html',true)
 do local h=create();h.Initial();local frame=h.Frame();local old=frame.ChildPage;local n=#h.Resolution;h.Direct('f.remove();f.src="b.html"');h.Page:FlushScriptLayout();h.Drain();check(not old.Alive and frame.ChildPage==nil and #h.Resolution==n and h.Page.IFrameRuntime:PendingCount()==0,'Removed frame cannot schedule detached source navigation');h.Destroy();mark('detached source before removal flush')end
 do local h=create();h.Initial();local old=h.Frame().ChildPage;h.Run('f.src="a.html#mark"');check(h.Frame().ChildPage==old,'Actual fragment keeps committed child');local ok,errorValue=old.JavaScriptRuntime:Run('location.href="b.html"');check(ok,tostring(errorValue));old:FlushScriptLayout();h.Drain();h.Page:FlushScriptLayout();h.Drain();url(h,origin..'/one/b.html');check(h.Frame().ChildPage~=old and not old.Alive and h.Loads()==2,'Retained document Navigate callback remains live after fragment');h.Retain();h.Destroy();mark('fragment retained child next navigation')end
 do local h=create({DelayVideo=true,Content=function()return '<video controls src=first.webm></video>'end});h.Drain();h.Page:FlushScriptLayout();h.Drain();local old=h.Frame().ChildPage;check(#h.Waiting==1 and h.Loads()==0,'Actual held child before fragment');h.Keep();h.Run('f.src="a.html#mark"');check(h.Frame().ChildPage==old and h.Loads()==0 and #h.Waiting==1,'Fragment retains actual pending native owner');h.Resume();h.Page:FlushScriptLayout();h.Drain();check(h.Loads()==1 and h.Realm.Window.Get('loadSeen')==1,'Retained child completion callback releases frame and parent once');h.Retain();h.Destroy();mark('fragment retained child completion')end
 do
  local h=create({DelayVideo=true,Content=function(address)return if address:find('b.html',1,true)then '<video controls src=first.webm></video>'else '<p>empty first</p>'end});
  local attempts=0;while h.Frame().ChildPage==nil or h.Loads()==0 do attempts+=1;check(attempts<100 and #h.Jobs>0,'Initial actual frame publication');local job=table.remove(h.Jobs,1);if not job.Cancelled then local ok,message=coroutine.resume(coroutine.create(job.Callback));check(ok,tostring(message))end end
  check(h.Realm.Window.Get('loadSeen')==0,'Parent completion remains genuinely queued');h.Direct('f.src="b.html"');check(h.Page.IFrameRuntime:PendingCount()==1,'New iframe source immediately delays queued parent completion');h.Page:FlushScriptLayout();h.Drain();check(#h.Waiting==1 and h.Realm.Window.Get('loadSeen')==0 and not h.Page:IsDocumentComplete(),'Queued document load rechecks actual source navigation');h.Resume();h.Page:FlushScriptLayout();h.Drain();check(h.Realm.Window.Get('loadSeen')==1 and h.Loads()==2,'Only current frame readiness releases parent once');h.Destroy();mark('queued parent completion sees source mutation')
 end
 do local h=create();h.Initial();local frame=h.Frame();local old=frame.ChildPage;local n=#h.Resolution;h.Direct('f.src="b.html"');h.Destroy();check(not old.Alive and frame.ChildPage==nil and #h.Resolution==n and h.Page.IFrameRuntime==nil,'Disposed page cancels queued frame source before resolver');mark('navigation disposal cancels queued child')end
 do local h,armed;h=create({Resolve=function(_,raw)if armed and raw=='b.html'then armed=false;h.Direct('f.src="c.html"')end end});h.Initial();armed=true;h.Run('f.src="b.html"');url(h,origin..'/one/c.html');check(h.Loads()==2,'Reentrant newer resolver selection wins without stale frame event');h.Retain();h.Destroy();mark('resolver reentry source wins')end
 do local h,armed;h=create({Resolve=function(_,raw)if armed and raw=='b.html'then armed=false;h.Page:Destroy()end end});h.Initial();local frame=h.Frame();armed=true;h.Direct('f.src="b.html"');h.Drain();check(not h.Page.Alive and frame.ChildPage==nil and h.Page.IFrameRuntime==nil,'Resolver disposal cannot publish a new child');h.Destroy();mark('resolver reentry page destroy')end
 do local h,armed,discarded;h=create({Mounted=function(_,child,settings)if armed and settings.DocumentURL==origin..'/one/b.html'then armed=false;discarded=child;h.Direct('f.src="c.html"')end end});h.Initial();armed=true;h.Run('f.src="b.html"');url(h,origin..'/one/c.html');check(discarded and not discarded.Alive and h.Loads()==2,'Obsolete constructor result is disposed once and never emits frame load');h.Retain();h.Destroy();mark('constructor reentry source wins')end
 do local h,armed,discarded;h=create({Mounted=function(_,child,settings)if armed and settings.DocumentURL==origin..'/one/b.html'then armed=false;discarded=child;h.Direct('f.remove()');h.Page:FlushScriptLayout()end end});h.Initial();local frame=h.Frame();armed=true;h.Run('f.src="b.html"');check(discarded and not discarded.Alive and frame.ChildPage==nil and h.Page.IFrameRuntime:PendingCount()==0 and h.Loads()==1,'Removed frame rejects and disposes returned child constructor');h.Destroy();mark('constructor reentry removal')end
 do local h=create();h.Initial();h.Run('b.href=origin+"/two/"');local previous=h.Frame().ChildPage;h.Direct('f.src="b.html"');h.Direct('b.href=origin+"/three/"');h.Page:FlushScriptLayout();h.Drain();url(h,origin..'/two/b.html');check(h.Frame().ChildPage~=previous and h.Resolution[#h.Resolution].Base==origin..'/two/','Mutation snapshots current node-document base, not later flush base');h.Retain();h.Destroy();mark('current source document base after earlier write')end
 for _,kind in{'fragment','ancestor'}do
  local h=create({DelayVideo=true,Content=function()return '<video controls src=first.webm></video>'end});h.Drain();h.Page:FlushScriptLayout();h.Drain();local old=h.Frame().ChildPage;check(#h.Waiting==1 and h.Loads()==0,'Genuine incomplete child before controlled task interleaving');h.Keep()
  h.Direct(if kind=='fragment'then 'f.src="a.html#mark"'else 'f.src=location.href');local paused=table.clone(h.Jobs);table.clear(h.Jobs)
  h.Resume(true);h.Drain();check(old:IsDocumentComplete()and h.Loads()==0,'Child reaches complete while the source processing task is queued')
  for _,job in paused do table.insert(h.Jobs,job)end;h.Drain();h.Page:FlushScriptLayout();h.Drain()
  check(h.Frame().ChildPage==old and h.Loads()==1 and h.Realm.Window.Get('loadSeen')==1,'Restored committed notifier publishes already reached completion exactly once')
  h.Retain();h.Destroy();mark(if kind=='fragment'then 'held child completes before queued fragment'else 'held child completes before rejected ancestor')
 end
 do local h=create();h.Initial();local old=h.Frame().ChildPage;local ok,message=old.JavaScriptRuntime:Run('location.hash="other"');check(ok,tostring(message));old:FlushScriptLayout();h.Drain();check(old.DocumentURL==origin..'/one/a.html#other','Real child Realm changes its own live URL');h.Run('f.src="a.html#mark"');check(h.Frame().ChildPage==old and h.Loads()==1 and old.DocumentURL==origin..'/one/a.html#mark','Parent src fragment keeps child hooks and uses live document address');ok,message=old.JavaScriptRuntime:Run('location.hash="final"');check(ok,tostring(message));old:FlushScriptLayout();h.Drain();h.Page.IFrameRuntime:Reload(h.Frame());h.Drain();h.Page:FlushScriptLayout();h.Drain();url(h,origin..'/one/a.html#final');check(h.Frame().ChildPage~=old and not old.Alive and h.Loads()==2,'Actual public frame reload uses live child URL rather than stale selection hint');h.Retain();h.Destroy();mark('child Realm hash parent fragment and reload')end
 for _,mode in{'owner','page'}do
  local document=Node.document();local additions={};local jobs,cleanups={},{};local mounts,wakes=0,0
  local page={Alive=true,Document=document,DocumentURL='https://frame.test/unit',BaseURL='https://frame.test/unit'}
  function page:AddCleanup(fn)table.insert(cleanups,fn)end
  for i=1,2 do local n=Node.element('iframe',{srcdoc='<p>unit'..i..'</p>'});n.OwnerDocument=document;Node.append(document,n);local content={SetAttribute=function()end};table.insert(additions,{Node=n,ContentGui=content,FallbackGui={}})end
  function page:DocumentResourcesChanged()
   wakes+=1
   if self.IFrameRuntime and self.IFrameRuntime:PendingCount()==1 then
    if mode=='owner'then self.IFrameRuntime:Destroy()else self.Alive=false;for _,fn in cleanups do fn()end end
   end
  end
  local runtime=loadIFrameRuntime({defer=function(fn)table.insert(jobs,fn)end})
  local api=runtime.start(page,{IFrameItems=additions},error,function()mounts+=1;error('Stopped frame cannot mount')end)
  check(api:PendingCount()==0 and page.IFrameRuntime==nil and #cleanups==1,'First source wake has already installed cleanup and stops shared owner')
  check(additions[2].Loading==nil and additions[1].ChildPage==nil and additions[2].ChildPage==nil and #jobs==0 and mounts==0,'Later addition never registers or queues after first wake stop')
  for _,fn in cleanups do fn()end;check(api:PendingCount()==0,'Retained cleanup is idempotent after reentrant initial stop')
  mark(if mode=='owner'then 'two item Add owner stop first wake'else 'two item Add page stop first wake')
 end
 for _,mode in{'queued','held'}do
  local h;h=create({Resolve=function(_,raw)if mode=='held'and raw=='b.html'then table.insert(h.Waiting,coroutine.running());coroutine.yield('actual held frame source before newer child navigation')end end})
  h.Initial();local old=h.Frame().ChildPage;local oldRealm=old.JavaScriptRuntime
  if mode=='queued'then h.Direct('f.src="b.html"')else h.Run('f.src="b.html"');check(#h.Waiting==1,'Actual parent navigation resolver held')end
  check(old.Alive and h.Frame().ChildPage==old and h.Page.IFrameRuntime:PendingCount()==1,'Old committed child remains live while parent source request is queued or held')
  local ok,message=oldRealm:Run('location.href="c.html"');check(ok,tostring(message));check(old.Alive,'Native document request does not destroy its executing Realm')
  old:FlushScriptLayout();h.Drain();h.Page:FlushScriptLayout();h.Drain();url(h,origin..'/one/c.html')
  check(h.Frame().ChildPage~=old and not old.Alive and h.Loads()==2,'Later live child document navigation supersedes parent request')
  if mode=='held'then h.Resume();check(h.Frame().ChildPage.DocumentURL==origin..'/one/c.html'and h.Loads()==2,'Obsolete held parent source cannot publish after child navigation')
  else for _,r in h.Resolution do check(r.Raw~='b.html','Superseded queued parent source performs no resolver IO')end end
  h.Retain();h.Destroy();mark(if mode=='queued'then 'live child navigation beats queued parent src'else 'live child navigation beats held parent src')
 end

 check(#expected==40,'Exact prepared mounted case inventory')
 check(completed==#expected,'All named mounted frame controls must execute')
 print('IFRAME_ATTRIBUTE_NAVIGATION',completed,checks)
end
