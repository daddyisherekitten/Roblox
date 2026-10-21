--!strict
-- Original 38 controls and independent four-case fault body are preserved literally.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference,Selection)
 local runOriginal=(function()
--!strict
-- Actual HTMLPage startup, Controller and HTMLScripts; deterministic native
-- metadata/resource completion is distinct from Chrome and Studio pixels.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference,Selection)
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
  options=options or{};local jobs,waiting,created,natives,svgs={}, {},{}, {},{};local focused,time,tree,page=nil,0,nil,nil
  local hits={};local counts={PosterLoads=0,PosterCancelled=0,SVGAdded=0,SVGRemoved=0,SVGJobs=0,NativeLoads=0,NativePlay=0,NativeSoundBind=0,Passes=0,PartialPasses=0}
  local function enqueue(fn,delay)local h={Callback=fn,Due=time+(delay or 0)};table.insert(jobs,h);return h end
  local tasks={spawn=enqueue,defer=enqueue,delay=function(delay,fn)return enqueue(fn,delay)end,cancel=function(h)h.Cancelled=true end,wait=function()time+=.016 end}
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
   function o:LoadAsync()counts.NativeLoads+=1;counts.Requests=counts.Requests or{};table.insert(counts.Requests,self.VideoContent);if options.StatusFail and self.VideoContent=='rbxassetid://200'then self.IsLoaded=true;return'Enum.AssetFetchStatus.Failure'end;if self.VideoContent=='rbxassetid://200'and options.Failure then if options.Failure=='throw'then error('Controlled first video failure')else return end end;if options.DelayVideo then table.insert(waiting,coroutine.running());coroutine.yield()end;self.IsLoaded=true;self.Resolution=Vector2.new(80,40);self:GetPropertyChangedSignal('IsLoaded'):Fire();if options.ThrowAfterReady then error('Controlled postmetadata failure')end end
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
   table.insert(natives,o);return o
  end}
  local provider={PreloadAsync=function(_,list,report)
   local object=list[1]
   if object and object.ClassName=='ImageLabel'and object.Image and(tostring(object.Image):find('101',1,true)or tostring(object.Image):find('102',1,true)or tostring(object.Image):find('109',1,true))then
    counts.PosterLoads+=1;if options.DelayPoster then table.insert(waiting,coroutine.running());coroutine.yield()end
   elseif object and(object.ClassName=='VideoFrame'or object.ClassName=='Sound')then
    counts.NativeLoads+=1;counts.Requests=counts.Requests or{};local selected=object.SoundId or object.Video;table.insert(counts.Requests,selected);if options.StatusFail and selected=='rbxassetid://200'then object.IsLoaded=true;if report then report(selected,'Enum.AssetFetchStatus.Failure')end;return end;if (selected=='rbxassetid://300'or selected=='rbxassetid://200')and options.Failure then if options.Failure=='throw'then error('Controlled first native preload failure')else object.IsLoaded=false;return end end;if object.ClassName=='VideoFrame'and options.DelayVideo then table.insert(waiting,coroutine.running());coroutine.yield()end;object.IsLoaded=true
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
  local module=loadHTMLPage({['Rendering/GuiFactory']=factory,['Layout/WordLayout']=overrides['Layout/WordLayout'],['Layout/TextMeasure']=overrides['Layout/TextMeasure'],['Rendering/ImageDimensions']=noImages,['Rendering/ImageLoad']=noImages,
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
    local args=table.pack(...);args[1]=overrides['Layout/FontProfiles'].face;tree=renderer.build(document,viewport,diagnostic,table.unpack(args,1,args.n));return tree
   end},['Layout/BlockLayout']={arrange=function(...)counts.Passes+=1;if tree.DirtyContext and tree.DirtyContext.Reuse then counts.PartialPasses+=1 end;return block.arrange(...)end},
   ['Input/Controller']={start=function(owner,current,layout,diagnostic)return Controller.start(owner,current,layout,diagnostic,services)end},
   ['Rendering/SVGImages']={start=function(owner,current)
    svgRuntime:AddItems(current.SVGItems);owner:AddCleanup(function()local all={};for i in svgs do table.insert(all,i)end;svgRuntime:RemoveItems(all)end);return svgRuntime
   end},
  },tasks,function()return time end)
  local scripts=if options.Scripting==false then ''else '<script>var m=document.getElementById("v"),v=m,wide="wide.png",tall="tall.png",clip="one.webm",e=document.getElementById("editor");window.loadSeen=0;window.addEventListener("load",function(){loadSeen++})</script>'
  local html=options.HTML or('<!doctype html><style>body{margin:0}video{display:block}</style><video id="v" muted preload="none" '..(if options.Poster then 'poster="'..options.Poster..'" 'else '')..'></video><input id="editor" tabindex="-1" value="A&#x1f600;BC"><p id="neighbor">retained neighbor</p>'..scripts)
  local mountOptions={JavaScript=options.Scripting~=false,RenderWorkBudgetMS=0,DocumentURL='https://video.test/root/index.html',Images={['wide.png']='101',['tall.png']='102',['bad.png']='109'},SVGs={['wide.svg']='<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100"/></svg>'},Videos={['first.webm']='200',['second.webm']='201'},Audio={['first.mp3']='300',['second.mp3']='301'},JavaScriptServices={VideoServices=options.VideoServices,Task=tasks,Clock=function()return time end,RunService=run,ResourceServices=resources,AudioServices={Task=tasks,Instance=instance,RunService=run,ContentProvider=provider}}}
  if options.StylesheetOnly then mountOptions.JavaScriptServices.LoadStylesheet=function()return ''end end
  page=module.mount(factory.create('Frame',factory.create('ScreenGui',nil,{}),{}),html,mountOptions)
  local realm=page.JavaScriptRuntime;local node=Node.findById(page.Document,'v');local item=node and tree.MediaByNode[node]
  local gui,box,frame,display=if item then item.Gui else nil,if item then item.BoxGui else nil,if item then item.VideoGui else nil,if item then item.VideoDisplay else nil
  local function drain()for _=1,(options.DrainBudget or 160)do if #jobs==0 then return end;local job=table.remove(jobs,1);if not job.Cancelled then time=math.max(time,job.Due);local thread=coroutine.create(job.Callback);local ok,message=coroutine.resume(thread);check(ok,tostring(message))end end;error('Presentation queue did not converge')end
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
  return {Page=page,Tree=tree,Item=item,Node=node,Realm=realm,Run=script,Direct=direct,Drain=drain,Resume=resume,Retained=retained,Geometry=geometry,Dimensions=dimensions,Destroy=destroy,Counts=counts,Waiting=waiting,Jobs=jobs,SVG=svgs,Native=function()return item.VideoPlayer or item.VideoGui end,Input=input,SetHits=function(value)hits=value end,Options=options,Focused=function()return focused end,Focus=focus,Instances=natives,Created=created}
 end




 local completed,seen=0,{}
 local expected={
  'VideoPlayer eager current-data boundary','VideoFrame eager current-data boundary',
  'VideoPlayer bootstrap and stylesheet Realm','VideoFrame bootstrap and stylesheet Realm',
  'VideoPlayer None suspension releases separately','VideoFrame None suspension releases separately',
  'VideoPlayer None resume before document complete','VideoFrame None resume before document complete',
  'VideoPlayer None resume after document complete','VideoFrame None resume after document complete',
  'VideoPlayer two VIDEO plus independent poster','VideoFrame two VIDEO plus independent poster',
  'VideoPlayer exhausted children and live-gap reblock','VideoFrame exhausted children and live-gap reblock',
  'VideoPlayer direct terminal failure and no-source','VideoFrame direct terminal failure and no-source',
  'VideoPlayer native fallback and postmetadata fatal release','VideoFrame native fallback and postmetadata fatal release',
  'VideoPlayer document notification reentrant ownership','VideoFrame document notification reentrant ownership',
  'VideoPlayer DCL mutation rechecks queued load','VideoFrame DCL mutation rechecks queued load',
  'VideoPlayer superseded serial native load','VideoFrame superseded serial native load',
  'VideoPlayer suspend listener resumes same generation','VideoFrame suspend listener resumes same generation',
  'VideoPlayer loadeddata listener replaces source','VideoFrame loadeddata listener replaces source',
  'VideoPlayer removal owner disposal and page disposal','VideoFrame removal owner disposal and page disposal',
  'VideoPlayer unrelated warm controls and retained focus','VideoFrame unrelated warm controls and retained focus',
  'BeforeSelect startup disposal','BeforeSelect startup nested epoch','BeforeSelect retry same-epoch generation',
  'BeforeSelect original error nil','BeforeSelect original error false','BeforeSelect original error table',
 }
 local function mark(name)check(table.find(expected,name)~=nil,'Unexpected control '..name);check(not seen[name],'Duplicate control '..name);seen[name]=true;completed+=1;print('VIDEO_DOCUMENT_BARRIER_CONTROL',name)end
 local function markup(attrs,children,tail,script)
  return '<button id=before>before</button><video id=v controls '..attrs..'>'..(children or'')..'</video>'..(tail or'')..'<input id=editor value="A&#x1f600;BC"><p id=neighbor>retained</p><script>var m=document.getElementById("v"),e=document.getElementById("editor");window.loads=0;window.dcl=0;window.sequence=[];document.addEventListener("DOMContentLoaded",()=>{dcl++;sequence.push("dcl")});window.addEventListener("load",()=>{loads++;sequence.push("load")});m.addEventListener("loadedmetadata",()=>sequence.push("metadata"));m.addEventListener("loadeddata",()=>sequence.push("data"));m.addEventListener("suspend",()=>sequence.push("suspend"));'..(script or'')..'</script>'
 end
 local function stage(h)h.Direct('window.stage=document.readyState');return h.Realm.Window.Get('stage')end
 local function sequence(h)h.Direct('window.seq=sequence.join(",")');return h.Realm.Window.Get('seq')end
 local function pending(h)return h.Page.Media:GetPendingDocumentResources()end
 local function complete(h,label)check(stage(h)=='complete'and h.Realm.Window.Get('loads')==1 and pending(h)==0,label)end
 local function blocked(h,label)check(stage(h)=='interactive'and h.Realm.Window.Get('dcl')==1 and h.Realm.Window.Get('loads')==0,label)end
 for _,modern in {true,false}do
  local backend=if modern then'VideoPlayer'else'VideoFrame'
  do
   for _,preload in {'preload=auto',''}do
    local h=fixture({HTML=markup('src=first.webm '..preload),Modern=modern,DelayVideo=true});h.Drain();local r=h.Item.VideoSelection
    check(#h.Waiting==1 and h.Counts.NativeLoads==1 and pending(h)==1 and r.DelayLoadFlag and not r.BootstrapPending,'Eager selected fetch has its own DelayLoadFlag, one held native request and no bootstrap reservation');blocked(h,'Eager resource blocks load independently of DCL')
    h.Resume(true);check(not h.Item.Loading and r.MetadataReached and h.Item.VideoFrameAvailable and pending(h)==1,'Native ready/UI Loading false is not the document loadeddata boundary');blocked(h,'Document stays interactive before queued loadeddata')
    check(not (','..sequence(h)..','):find(',data,',1,true),'loadeddata has not yet fired as an inline metadata callback');h.Drain();complete(h,'Queued data releases load once')
    local seq=sequence(h);check(seq:find('data,load',1,true)~=nil,'loadeddata task precedes window load task');check(not r.DelayLoadFlag and not r.DocumentBlocking and next(r.DocumentBoundaries)==nil,'Current data release clears flag and callback record');h.Destroy()
   end;mark(backend..' eager current-data boundary')
  end
  do
   local startups=0
   local function startup(page,counts,tree)
    startups+=1;local item=tree.MediaByNode[Node.findById(page.Document,'v')];local r=item.VideoSelection
    check(page.Media:GetPendingDocumentResources()==1 and r.BootstrapPending and not r.DelayLoadFlag and counts.NativeLoads==0,'VIDEO bootstrap reserves before real Realm start without a premature native load or normative flag')
   end
   local h=fixture({HTML=markup('src=first.webm preload=auto'),Modern=modern,DelayVideo=true,DelayVM=true,StartupCheck=startup});h.Drain();blocked(h,'Delayed VM startup still sees current VIDEO reservation');h.Resume();complete(h,'Delayed VM ready releases load');h.Destroy()
   h=fixture({HTML='<video id=v controls src=first.webm preload=auto></video><input id=editor><p id=neighbor>retained</p>',Modern=modern,DelayVideo=true,StylesheetOnly=true,StartupCheck=startup});h.Drain()
   check(h.Realm~=nil and pending(h)==1 and stage(h)=='interactive'and #h.Waiting==1,'Stylesheet-only real Realm receives VIDEO pending lease');h.Resume();check(stage(h)=='complete'and pending(h)==0,'Stylesheet-only Realm completes after current data');h.Destroy();check(startups==2,'Both exact ShouldStart paths reached');mark(backend..' bootstrap and stylesheet Realm')
  end
  do
   local h=fixture({HTML=markup('preload=none','<source id=s1 src=missing.media><source id=s2 src=second.webm>'),Modern=modern});local order={};local r=h.Item.VideoSelection
   h.Page.Events:On(h.Node,'suspend',function()table.insert(order,'suspend');check(pending(h)==1 and r.DelayLoadFlag and not h.Item.Loading,'None suspend task still owns normative flag although GUI is not loading')end)
   h.Drain();complete(h,'Separate None release allows window load without IO');check(table.concat(order,',')=='suspend'and r.Phase=='deferred'and r.Raw=='missing.media'and h.Counts.NativeLoads==0 and not r.DelayLoadFlag,'None retains first unavailable SOURCE while separately releasing document flag');check(sequence(h):find('suspend,load',1,true)~=nil,'Separate suspension boundary precedes load');h.Destroy();mark(backend..' None suspension releases separately')
  end
  do
   local h=fixture({HTML=markup('src=first.webm preload=none poster=wide.png'),Modern=modern,DelayPoster=true,DelayVideo=true});h.Drain();blocked(h,'Independent poster keeps None document interactive');check(pending(h)==0 and h.Page.PosterPendingCount==1 and #h.Waiting==1,'None resource released independently of pending poster')
   check(h.Page:FocusDOMElement(h.Node,true),'Actual None control focus');h.Input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Space},false);h.Drain()
   check(pending(h)==1 and h.Page.PosterPendingCount==1 and #h.Waiting==2 and h.Counts.NativeLoads==1,'Actual Controller resume reblocks before document load while poster remains independent');h.Resume();blocked(h,'Poster alone cannot release active VIDEO');check(h.Page.PosterPendingCount==0 and pending(h)==1,'Poster completion leaves VIDEO lease intact');h.Resume();complete(h,'Current resumed data clears final combined resource');h.Destroy();mark(backend..' None resume before document complete')
  end
  do
   local h=fixture({HTML=markup('src=first.webm preload=none'),Modern=modern,DelayVideo=true});h.Drain();complete(h,'Initial None loads document');h.Page:PlayMedia('v');h.Drain()
   check(stage(h)=='complete'and h.Realm.Window.Get('loads')==1 and pending(h)==1 and #h.Waiting==1,'Resuming transport after document complete never regresses readyState or repeats load');h.Resume();complete(h,'Late transport data leaves document one-shot');h.Destroy();mark(backend..' None resume after document complete')
  end
  do
   for _,reverse in {false,true}do
    local h=fixture({HTML=markup('src=first.webm preload=auto poster=wide.png',nil,'<video id=v2 controls src=second.webm preload=auto></video>'),Modern=modern,DelayPoster=true,DelayVideo=true});h.Drain()
    check(pending(h)==2 and h.Page.PosterPendingCount==1 and #h.Waiting==3,'Two VIDEO and independent poster own three separate resource leases');blocked(h,'Three resources keep document interactive')
    if reverse then h.Waiting[1],h.Waiting[3]=h.Waiting[3],h.Waiting[1]end
    for count=2,0,-1 do h.Resume();check(pending(h)+h.Page.PosterPendingCount==count,'Completion clears exactly one resource in either order');if count>0 then blocked(h,'Partial resource completion cannot load document')else complete(h,'Final independent resource completes load once')end end
    h.Destroy()
   end;mark(backend..' two VIDEO plus independent poster')
  end
  do
   local h=fixture({HTML=markup('preload=auto poster=wide.png','<source id=s1 src=missing.media><source id=s2 src=also-missing.media>'),Modern=modern,DelayPoster=true,DelayVideo=true});local errors={}
   for _,node in h.Node.Children do h.Page.Events:On(node,'error',function()table.insert(errors,node.Attributes.id)end)end
   h.Drain();local r=h.Item.VideoSelection;check(r.Phase=='waiting'and pending(h)==0 and h.Counts.NativeLoads==0 and table.concat(errors,',')=='s1,s2','Exhausted children release their flag only after ordered SOURCE error tasks');blocked(h,'Poster remains separate in waiting mode')
   h.Direct('var x=document.createElement("source");x.src="second.webm";m.appendChild(x)');check(pending(h)==1 and(r.BootstrapPending or r.DelayLoadFlag),'Actual same-script gap append immediately reserves before GUI flush');h.Page:FlushScriptLayout();h.Drain()
   check(r.Phase=='fetch'and pending(h)==1 and r.DelayLoadFlag and not r.BootstrapPending and #h.Waiting==2,'Live gap stable selection re-establishes normative flag and one held load');h.Resume();blocked(h,'Waiting poster completion cannot clear live resumed VIDEO');h.Resume();complete(h,'Resumed appended candidate current data releases load');h.Destroy();mark(backend..' exhausted children and live-gap reblock')
  end
  do
   for _,attrs in {'src="" preload=auto','src="http://[invalid]" preload=auto','preload=auto'}do
    local h=fixture({HTML=markup(attrs),Modern=modern});local errors=0;h.Page.Events:On(h.Node,'error',function()errors+=1;check(pending(h)==1,'Dedicated terminal error fires before clearing its DelayLoadFlag')end);h.Drain()
    complete(h,'Terminal/no-source stable end permits document load');check(h.Counts.NativeLoads==0 and(not h.Item.VideoSelection.DelayLoadFlag),'Terminal/no-source selection performs no native IO and clears flag');check(errors==(if attrs=='preload=auto'then 0 else 1),'Dedicated failure stays separate from no-source empty state');h.Destroy()
   end;mark(backend..' direct terminal failure and no-source')
  end
  do
   local h=fixture({HTML=markup('preload=auto','<source id=s1 src=first.webm><source id=s2 src=second.webm>'),Modern=modern,DelayVideo=true,StatusFail=true});local errors={}
   for _,node in h.Node.Children do h.Page.Events:On(node,'error',function()table.insert(errors,node.Attributes.id);check(pending(h)==1,'Ordinary native failure SOURCE task cannot transiently clear document flag')end)end
   h.Drain();check(pending(h)==1 and #h.Waiting==1 and h.Counts.NativeLoads==2 and table.concat(errors,',')=='s1','Explicit failing native status falls back while retaining one current document lease');blocked(h,'Failed first native attempt does not complete load before second source');h.Resume();complete(h,'Fallback current data releases final flag');h.Destroy()
   h=fixture({HTML=markup('preload=auto','<source id=s1 src=first.webm><source id=s2 src=second.webm>'),Modern=modern,ThrowAfterReady=true});local terminal,loadeddata=0,0
   h.Page.Events:On(h.Node,'error',function()terminal+=1;check(pending(h)==0 and h.Item.VideoSelection.MetadataReached,'Postmetadata fatal error clears DelayLoadFlag before its error event')end)
   h.Page.Events:On(h.Node,'loadeddata',function()loadeddata+=1 end);h.Drain();complete(h,'Postmetadata fatal release completes document without next SOURCE')
   check(terminal==1 and loadeddata==0 and h.Counts.NativeLoads==1 and h.Item.MetadataEmitted and h.Item.VideoSelection.Phase=='error','Postmetadata failure invalidates queued data boundary and never tries next source');h.Destroy();mark(backend..' native fallback and postmetadata fatal release')
  end
  do
   for _,kind in {'owner destroy','new epoch'}do
    local h=fixture({HTML=markup('src=first.webm preload=auto'),Modern=modern,DelayVideo=true,ThrowAfterReady=true});h.Drain();local errors,entered=0,false;local r=h.Item.VideoSelection;local epoch=r.SelectionEpoch;local original=h.Realm.ResourcesChanged
    h.Page.Events:On(h.Node,'error',function()errors+=1 end)
    h.Realm.ResourcesChanged=function(runtime)
     if not entered and pending(h)==0 then entered=true;if kind=='owner destroy'then h.Page.Media:Destroy()else h.Direct('m.src="second.webm"')end end
     return original(runtime)
    end
    h.Resume(true);check(entered and errors==0,'Counter notification '..kind..' cannot publish the old postmetadata error after ownership changed')
    if kind=='owner destroy'then check(pending(h)==0 and r.Item==nil and h.Item.VideoSelection==nil,'Reentrant owner removal clears exact lease target/count');h.Drain();complete(h,'Reentrant owner removal still wakes document completion')
    else check(pending(h)==1 and r.SelectionEpoch==epoch+1,'Reentrant new src owns sole replacement counter');h.Options.ThrowAfterReady=false;h.Page:FlushScriptLayout();h.Drain();check(h.Item.SelectedSource=='second.webm'and #h.Waiting==1 and h.Counts.NativeLoads==2,'Replacement epoch owns serialized next request');blocked(h,'Old failure cannot complete replacement document');h.Resume();complete(h,'Replacement current data completes after reentrant notification')end
    h.Destroy()
   end;mark(backend..' document notification reentrant ownership')
  end
  do
   local h=fixture({HTML=markup('src=first.webm preload=none',nil,nil,'document.addEventListener("DOMContentLoaded",()=>{m.preload="auto";m.src="second.webm";window.atDCL=document.readyState});'),Modern=modern,DelayVideo=true});h.Drain()
   check(h.Realm.Window.Get('atDCL')=='interactive'and h.Item.SelectedSource=='second.webm'and pending(h)==1 and #h.Waiting==1,'Actual DCL mutation replaces None and adds bootstrap before previously queued load can complete');blocked(h,'Existing queued window load rechecks current embedded resources');h.Resume();complete(h,'DCL-started current source loadeddata completes once');h.Destroy();mark(backend..' DCL mutation rechecks queued load')
  end
  do
   local h=fixture({HTML=markup('src=first.webm preload=auto'),Modern=modern,DelayVideo=true});h.Drain();local r=h.Item.VideoSelection;h.Focus();local old=h.Native();local stale=(if modern then old:GetPropertyChangedSignal('IsLoaded')else old.Loaded):Snapshot()
   local epoch,revision=r.SelectionEpoch,r.DocumentRevision;h.Run('m.removeAttribute("src")');check(pending(h)==1 and r.SelectionEpoch==epoch and r.DocumentRevision==revision and h.Counts.NativeLoads==1,'Removing src alone preserves current selected load, epoch and document flag')
   h.Direct('m.src="second.webm"');check(pending(h)==1 and(r.BootstrapPending or r.DelayLoadFlag)and h.Counts.NativeLoads==1,'Same-script source commit replaces current lease before native work');h.Page:FlushScriptLayout();h.Drain();h.Retained()
   check(#h.Waiting==1 and h.Counts.NativeLoads==1,'Superseded native load remains serialized');for _,fn in stale do fn()end;check(pending(h)==1 and not h.Item.MetadataEmitted,'Old signals cannot clear new selection flag');h.Resume()
   check(pending(h)==1 and #h.Waiting==1 and h.Counts.NativeLoads==2 and not h.Item.MetadataEmitted,'Old native return starts latest job without releasing current flag');blocked(h,'Superseded source cannot complete document');h.Resume();complete(h,'Latest serial source data releases once');check(h.Item.SelectedSource=='second.webm','Final current source');h.Retained();h.Destroy();mark(backend..' superseded serial native load')
  end
  do
   local h=fixture({HTML=markup('src=first.webm preload=none'),Modern=modern,DelayVideo=true});local entered=false;local r=h.Item.VideoSelection
   h.Page.Events:On(h.Node,'suspend',function()if not entered then entered=true;h.Page:PlayMedia('v')end end);h.Drain()
   check(entered and r.Phase=='fetch'and r.DelayLoadFlag and pending(h)==1 and #h.Waiting==1,'Same-generation suspend listener fetch invalidates old separately queued release');blocked(h,'Reentrant suspend fetch cannot load document early');h.Resume();complete(h,'Same-generation current data final release');h.Destroy();mark(backend..' suspend listener resumes same generation')
  end
  do
   local h=fixture({HTML=markup('src=first.webm preload=auto'),Modern=modern,DelayVideo=true});local entered=false;h.Page.Events:On(h.Node,'loadeddata',function()if not entered then entered=true;h.Run('m.src="second.webm"',true)end end);h.Drain();h.Resume()
   check(entered and pending(h)==1 and h.Item.SelectedSource=='second.webm'and #h.Waiting==1 and h.Counts.NativeLoads==2,'loadeddata handler source replacement prevents old event release from clearing new epoch');blocked(h,'Reentrant data listener leaves new resource interactive');h.Resume();complete(h,'Only second current data completes document');h.Destroy();mark(backend..' loadeddata listener replaces source')
  end
  do
   for _,kind in {'remove','owner','page'}do
    local h=fixture({HTML=markup('src=first.webm preload=auto'),Modern=modern,DelayVideo=true});local dataEvents=0;h.Page.Events:On(h.Node,'loadeddata',function()dataEvents+=1 end);h.Drain();local r=h.Item.VideoSelection;local native=h.Native();local stale=(if modern then native:GetPropertyChangedSignal('IsLoaded')else native.Loaded):Snapshot();local runtime=h.Realm
    if kind=='remove'then h.Run('m.remove()')elseif kind=='owner'then h.Page.Media:Destroy();h.Drain()else h.Destroy()end
    check(pending(h)==0 and not r.DocumentBlocking and not r.DelayLoadFlag and next(r.DocumentBoundaries or{})==nil and r.Item==nil,'Removal/disposal clears document slot target/count/flag synchronously')
    if kind~='page'then complete(h,'Removing active renderer owner permits current document completion')end
    for _,fn in stale do fn()end;h.Resume();check(pending(h)==0 and dataEvents==0 and h.Counts.NativeLoads==1,'Disposed queued signals/native completion do not resurrect data/IO/document leases');if kind=='page'then check(not runtime.Alive,'Disposed real Realm stays dead')else complete(h,'Disposed stale completion cannot repeat document load');h.Destroy()end
   end;mark(backend..' removal owner disposal and page disposal')
  end
  do
   local h=fixture({HTML=markup('src=first.webm preload=auto'),Modern=modern,DelayVideo=true});h.Drain();h.Focus();local r=h.Item.VideoSelection;local revision=r.DocumentRevision;local count=h.Counts.NativeLoads;local created=#h.Created;local svg=h.Counts.SVGJobs;local resolve=h.Page.ResolveVideo;local resolverCalls=0
   h.Page.ResolveVideo=function(raw)resolverCalls+=1;return resolve(raw)end
   for i=1,3 do h.Run('m.controls=false;m.loop=true;m.style.color="red";m.controls=true');h.Page:GetMediaState('v');h.Retained()end
   check(#h.Created==created,'Warm controls/style/read operations preserve GUI allocation count')
   for i=1,3 do h.Run('document.getElementById("neighbor").textContent="ordinary status"');h.Page:GetMediaState('v');h.Retained()end
   check(pending(h)==1 and r.DelayLoadFlag and r.DocumentRevision==revision and h.Counts.NativeLoads==count and resolverCalls==0 and h.Counts.SVGJobs==svg,'Unrelated style/status/controls/time reads do not resolve source, change document lease or raster; changed status text may allocate text GUI');blocked(h,'Warm unrelated mutations retain current resource barrier');h.Resume();complete(h,'Warm current data releases')
   check(h.Page:EnterMediaFullscreen('v'),'Actual retained fullscreen helper');h.Run('m.controls=false;m.controls=true');check(pending(h)==0 and h.Counts.NativeLoads==count and h.Page:ExitMediaFullscreen(),'Fullscreen warm controls preserve zero load lease and native request count');h.Retained();h.Destroy();mark(backend..' unrelated warm controls and retained focus')
  end
 end
 for _,kind in {'startup disposal','startup nested epoch','retry same-epoch generation'}do
  local state={Node=Node.element('video',{src='old.webm'}),SelectionEpoch=1,Generation=1};local stable,tasks,requests,resolveCalls={},{},{},{};local core,entered
  local context={Alive=function()return true end,QueueStable=function(fn)table.insert(stable,fn)end,QueueTask=function(fn)table.insert(tasks,fn)end,Changed=function()end,Dispatch=function()end,Selected=function()end,ShouldDefer=function()return false end,Suspend=function()end,DirectFailure=function()error('Unexpected hook direct failure')end,
   Resolve=function(_,raw)table.insert(resolveCalls,raw);return 'https://hook.test/'..raw end,Fetch=function(r)table.insert(requests,r.Raw)end}
  context.BeforeSelect=function(r)
   if entered then return end;entered=true
   if kind=='startup disposal'then core:Destroy()
   elseif kind=='startup nested epoch'then r.SelectionEpoch+=1;r.Generation+=1;r.Node.Attributes.src='new.webm';core:Start(r,r.SelectionEpoch)
   else r.Generation+=1 end
  end
  core=Selection.new(context)
  if kind=='retry same-epoch generation'then state.Node.Attributes.src=nil;Node.append(state.Node,Node.element('source',{src='old.webm'}));Node.append(state.Node,Node.element('source',{src='new.webm'}));context.BeforeSelect=nil;context.Fetch=function(r)table.insert(requests,r.Raw);core:Fail(r)end;core:Start(state,1);check(#requests==1,'Retry fixture first source is genuinely attempted');table.clear(requests);table.clear(resolveCalls);context.BeforeSelect=function(r)entered=true;r.Generation+=1 end;while #stable>0 do table.remove(stable,1)()end
  else core:Start(state,1)end
  check(entered,'Actual shared BeforeSelect hook reached '..kind)
  if kind=='startup nested epoch'then check(table.concat(resolveCalls,',')=='new.webm'and table.concat(requests,',')=='new.webm','Hook reentrant new epoch is sole resolver/IO attempt')else check(#requests==0 and #resolveCalls==0,'Hook disposal/generation invalidation blocks old qualification/resolver/IO')end
  core:Destroy();for _,fn in tasks do fn()end;mark('BeforeSelect '..kind)
 end
 for _,kind in {'nil','false','table'}do
  local payload=if kind=='nil'then nil elseif kind=='false'then false else {Origin='original hook error'}
  local resolves=0;local core=Selection.new({Alive=function()return true end,BeforeSelect=function()error(payload,0)end,Resolve=function()resolves+=1;return 'unexpected'end})
  local r={Node=Node.element('video',{src='old.webm'}),SelectionEpoch=1,Generation=1};local ok,value=pcall(core.Start,core,r,1)
  check(not ok and value==payload and resolves==0,'BeforeSelect preserves exact '..kind..' error and never performs old resolver/IO');core:Destroy();mark('BeforeSelect original error '..kind)
 end
 for _,name in expected do check(seen[name],'Missing named control '..name)end
 check(completed==#expected and #expected==38,'Exact 32 actual-page controls plus six shared hook guards')
 print('VIDEO_DOCUMENT_BARRIER_SUMMARY','controls='..completed,'assertions='..checks)
end

end)()
 runOriginal(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference,Selection)
 local runIndependent=(function()
--!strict
-- Actual HTMLPage startup, Controller and HTMLScripts; deterministic native
-- metadata/resource completion is distinct from Chrome and Studio pixels.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference,Selection)
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
  options=options or{};local jobs,waiting,created,natives,svgs={}, {},{}, {},{};local focused,time,tree,page=nil,0,nil,nil
  local hits={};local counts={PosterLoads=0,PosterCancelled=0,SVGAdded=0,SVGRemoved=0,SVGJobs=0,NativeLoads=0,NativePlay=0,NativeSoundBind=0,Passes=0,PartialPasses=0}
  local function enqueue(fn,delay)local h={Callback=fn,Due=time+(delay or 0)};table.insert(jobs,h);return h end
  local tasks={spawn=enqueue,defer=enqueue,delay=function(delay,fn)return enqueue(fn,delay)end,cancel=function(h)h.Cancelled=true end,wait=function()time+=.016 end}
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
   function o:LoadAsync()counts.NativeLoads+=1;counts.Requests=counts.Requests or{};table.insert(counts.Requests,self.VideoContent);if options.StatusFail and self.VideoContent=='rbxassetid://200'then self.IsLoaded=true;return'Enum.AssetFetchStatus.Failure'end;if self.VideoContent=='rbxassetid://200'and options.Failure then if options.Failure=='throw'then error('Controlled first video failure')else return end end;if options.DelayVideo then table.insert(waiting,coroutine.running());coroutine.yield()end;self.IsLoaded=true;self.Resolution=Vector2.new(80,40);self:GetPropertyChangedSignal('IsLoaded'):Fire();if options.ThrowAfterReady then error('Controlled postmetadata failure')end end
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
   table.insert(natives,o);return o
  end}
  local provider={PreloadAsync=function(_,list,report)
   local object=list[1]
   if object and object.ClassName=='ImageLabel'and object.Image and(tostring(object.Image):find('101',1,true)or tostring(object.Image):find('102',1,true)or tostring(object.Image):find('109',1,true))then
    counts.PosterLoads+=1;if options.DelayPoster then table.insert(waiting,coroutine.running());coroutine.yield()end
   elseif object and(object.ClassName=='VideoFrame'or object.ClassName=='Sound')then
    counts.NativeLoads+=1;counts.Requests=counts.Requests or{};local selected=object.SoundId or object.Video;table.insert(counts.Requests,selected);if options.StatusFail and selected=='rbxassetid://200'then object.IsLoaded=true;if report then report(selected,'Enum.AssetFetchStatus.Failure')end;return end;if (selected=='rbxassetid://300'or selected=='rbxassetid://200')and options.Failure then if options.Failure=='throw'then error('Controlled first native preload failure')else object.IsLoaded=false;return end end;if object.ClassName=='VideoFrame'and options.DelayVideo then table.insert(waiting,coroutine.running());coroutine.yield()end;object.IsLoaded=true
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
  local module=loadHTMLPage({['Rendering/GuiFactory']=factory,['Layout/WordLayout']=overrides['Layout/WordLayout'],['Layout/TextMeasure']=overrides['Layout/TextMeasure'],['Rendering/ImageDimensions']=noImages,['Rendering/ImageLoad']=noImages,
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
    local args=table.pack(...);args[1]=overrides['Layout/FontProfiles'].face;tree=renderer.build(document,viewport,diagnostic,table.unpack(args,1,args.n));return tree
   end},['Layout/BlockLayout']={arrange=function(...)counts.Passes+=1;if tree.DirtyContext and tree.DirtyContext.Reuse then counts.PartialPasses+=1 end;return block.arrange(...)end},
   ['Input/Controller']={start=function(owner,current,layout,diagnostic)return Controller.start(owner,current,layout,diagnostic,services)end},
   ['Rendering/SVGImages']={start=function(owner,current)
    svgRuntime:AddItems(current.SVGItems);owner:AddCleanup(function()local all={};for i in svgs do table.insert(all,i)end;svgRuntime:RemoveItems(all)end);return svgRuntime
   end},
  },tasks,function()return time end)
  local scripts=if options.Scripting==false then ''else '<script>var m=document.getElementById("v"),v=m,wide="wide.png",tall="tall.png",clip="one.webm",e=document.getElementById("editor");window.loadSeen=0;window.addEventListener("load",function(){loadSeen++})</script>'
  local html=options.HTML or('<!doctype html><style>body{margin:0}video{display:block}</style><video id="v" muted preload="none" '..(if options.Poster then 'poster="'..options.Poster..'" 'else '')..'></video><input id="editor" tabindex="-1" value="A&#x1f600;BC"><p id="neighbor">retained neighbor</p>'..scripts)
  local mountOptions={JavaScript=options.Scripting~=false,RenderWorkBudgetMS=0,DocumentURL='https://video.test/root/index.html',Images={['wide.png']='101',['tall.png']='102',['bad.png']='109'},SVGs={['wide.svg']='<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100"/></svg>'},Videos={['first.webm']='200',['second.webm']='201'},Audio={['first.mp3']='300',['second.mp3']='301'},JavaScriptServices={VideoServices=options.VideoServices,Task=tasks,Clock=function()return time end,RunService=run,ResourceServices=resources,AudioServices={Task=tasks,Instance=instance,RunService=run,ContentProvider=provider}}}
  if options.StylesheetOnly then mountOptions.JavaScriptServices.LoadStylesheet=function()return ''end end
  page=module.mount(factory.create('Frame',factory.create('ScreenGui',nil,{}),{}),html,mountOptions)
  local realm=page.JavaScriptRuntime;local node=Node.findById(page.Document,'v');local item=node and tree.MediaByNode[node]
  local gui,box,frame,display=if item then item.Gui else nil,if item then item.BoxGui else nil,if item then item.VideoGui else nil,if item then item.VideoDisplay else nil
  local function drain()for _=1,(options.DrainBudget or 160)do if #jobs==0 then return end;local job=table.remove(jobs,1);if not job.Cancelled then time=math.max(time,job.Due);local thread=coroutine.create(job.Callback);local ok,message=coroutine.resume(thread);check(ok,tostring(message))end end;error('Presentation queue did not converge')end
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
  return {Page=page,Tree=tree,Item=item,Node=node,Realm=realm,Run=script,Direct=direct,Drain=drain,Resume=resume,Retained=retained,Geometry=geometry,Dimensions=dimensions,Destroy=destroy,Counts=counts,Waiting=waiting,Jobs=jobs,SVG=svgs,Native=function()return item.VideoPlayer or item.VideoGui end,Input=input,SetHits=function(value)hits=value end,Options=options,Focused=function()return focused end,Focus=focus,Instances=natives,Created=created}
 end





 local faults={};local cases=0
 local function demand(value,label)if not value then table.insert(faults,label)end end
 for _,modern in {true,false}do
  local backend=if modern then 'VideoPlayer'else 'VideoFrame'
  for _,mode in {'stop','nested'}do
   local h=fixture({Modern=modern,HTML='<video id="v" controls src="first.webm" preload="auto"></video><input id="editor"><p id="neighbor">retained</p><script>var m=document.getElementById("v"),e=document.getElementById("editor");</script>'});h.Drain()
   check(h.Page.Media:GetPendingDocumentResources()==0 and h.Item.VideoSelection.MetadataReached,'Warm real page ready before acquire boundary')
   local r=h.Item.VideoSelection;local oldEpoch=r.SelectionEpoch;local armed=true;local called,stopped,postStop,innerEpoch=0,false,0,nil
   local originalPresentation=h.Page.MediaPresentationChanged
   h.Page.MediaPresentationChanged=function(self,item)if stopped then postStop+=1 end;return originalPresentation(self,item)end
   local original=h.Realm.ResourcesChanged
   h.Realm.ResourcesChanged=function(self)
    if armed then
     armed=false;called+=1
     check(h.Page.Media:GetPendingDocumentResources()==1,'Actual acquisition 0 to 1 notification')
     if mode=='stop'then h.Page.Media:Destroy();stopped=true
     else h.Page:LoadVideo('v');innerEpoch=r.SelectionEpoch;if h.Item.RateSupported then h.Page:SetMediaPlaybackRate('v',1.5)end end
    end
    return original(self)
   end
   local ok,message=pcall(function()h.Page:LoadVideo('v')end)
   print('INDEPENDENT_ACQUIRE_BOUNDARY',backend,mode,'ok',ok,'message',tostring(message),'calls',called,'oldEpoch',oldEpoch,'innerEpoch',innerEpoch,'finalEpoch',r.SelectionEpoch,'postStopPresentations',postStop,'rateSupported',h.Item.RateSupported,'rate',h.Item.PlaybackRate)
   demand(ok,backend..' '..mode..' should not throw')
   demand(called==1,backend..' '..mode..' exercised acquire callback exactly once')
   if mode=='stop'then demand(postStop==0,backend..' acquire StopOwner must not publish stale presentation')
   else demand(r.SelectionEpoch==innerEpoch,backend..' outer acquisition must not supersede inner selection');if h.Item.RateSupported then demand(h.Item.PlaybackRate==1.5,backend..' outer acquisition must not overwrite later rate command')end end
   h.Realm.ResourcesChanged=original;h.Page.MediaPresentationChanged=originalPresentation;h.Destroy();cases+=1
  end
 end
 print('INDEPENDENT_ACQUIRE_BOUNDARY_SUMMARY',cases,#faults)
 for _,fault in faults do print('INDEPENDENT_ACQUIRE_BOUNDARY_FAULT',fault)end
 assert(#faults==0,table.concat(faults,' | '))
end

end)()
 runIndependent(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference,Selection)
 local runAcquire=(function()
--!strict
-- Actual HTMLPage startup, Controller and HTMLScripts; deterministic native
-- metadata/resource completion is distinct from Chrome and Studio pixels.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference,Selection)
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
  options=options or{};local jobs,waiting,created,natives,svgs={}, {},{}, {},{};local focused,time,tree,page=nil,0,nil,nil
  local hits={};local counts={PosterLoads=0,PosterCancelled=0,SVGAdded=0,SVGRemoved=0,SVGJobs=0,NativeLoads=0,NativePlay=0,NativeSoundBind=0,Passes=0,PartialPasses=0}
  local function enqueue(fn,delay)local h={Callback=fn,Due=time+(delay or 0)};table.insert(jobs,h);return h end
  local tasks={spawn=enqueue,defer=enqueue,delay=function(delay,fn)return enqueue(fn,delay)end,cancel=function(h)h.Cancelled=true end,wait=function()time+=.016 end}
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
   function o:LoadAsync()counts.NativeLoads+=1;counts.Requests=counts.Requests or{};table.insert(counts.Requests,self.VideoContent);if options.StatusFail and self.VideoContent=='rbxassetid://200'then self.IsLoaded=true;return'Enum.AssetFetchStatus.Failure'end;if self.VideoContent=='rbxassetid://200'and options.Failure then if options.Failure=='throw'then error('Controlled first video failure')else return end end;if options.DelayVideo then table.insert(waiting,coroutine.running());coroutine.yield()end;self.IsLoaded=true;self.Resolution=Vector2.new(80,40);self:GetPropertyChangedSignal('IsLoaded'):Fire();if options.ThrowAfterReady then error('Controlled postmetadata failure')end end
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
   table.insert(natives,o);return o
  end}
  local provider={PreloadAsync=function(_,list,report)
   local object=list[1]
   if object and object.ClassName=='ImageLabel'and object.Image and(tostring(object.Image):find('101',1,true)or tostring(object.Image):find('102',1,true)or tostring(object.Image):find('109',1,true))then
    counts.PosterLoads+=1;if options.DelayPoster then table.insert(waiting,coroutine.running());coroutine.yield()end
   elseif object and(object.ClassName=='VideoFrame'or object.ClassName=='Sound')then
    counts.NativeLoads+=1;counts.Requests=counts.Requests or{};local selected=object.SoundId or object.Video;table.insert(counts.Requests,selected);if options.StatusFail and selected=='rbxassetid://200'then object.IsLoaded=true;if report then report(selected,'Enum.AssetFetchStatus.Failure')end;return end;if (selected=='rbxassetid://300'or selected=='rbxassetid://200')and options.Failure then if options.Failure=='throw'then error('Controlled first native preload failure')else object.IsLoaded=false;return end end;if object.ClassName=='VideoFrame'and options.DelayVideo then table.insert(waiting,coroutine.running());coroutine.yield()end;object.IsLoaded=true
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
  local module=loadHTMLPage({['Rendering/GuiFactory']=factory,['Layout/WordLayout']=overrides['Layout/WordLayout'],['Layout/TextMeasure']=overrides['Layout/TextMeasure'],['Rendering/ImageDimensions']=noImages,['Rendering/ImageLoad']=noImages,
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
    local args=table.pack(...);args[1]=overrides['Layout/FontProfiles'].face;tree=renderer.build(document,viewport,diagnostic,table.unpack(args,1,args.n));return tree
   end},['Layout/BlockLayout']={arrange=function(...)counts.Passes+=1;if tree.DirtyContext and tree.DirtyContext.Reuse then counts.PartialPasses+=1 end;return block.arrange(...)end},
   ['Input/Controller']={start=function(owner,current,layout,diagnostic)return Controller.start(owner,current,layout,diagnostic,services)end},
   ['Rendering/SVGImages']={start=function(owner,current)
    svgRuntime:AddItems(current.SVGItems);owner:AddCleanup(function()local all={};for i in svgs do table.insert(all,i)end;svgRuntime:RemoveItems(all)end);return svgRuntime
   end},
  },tasks,function()return time end)
  local scripts=if options.Scripting==false then ''else '<script>var m=document.getElementById("v"),v=m,wide="wide.png",tall="tall.png",clip="one.webm",e=document.getElementById("editor");window.loadSeen=0;window.addEventListener("load",function(){loadSeen++})</script>'
  local html=options.HTML or('<!doctype html><style>body{margin:0}video{display:block}</style><video id="v" muted preload="none" '..(if options.Poster then 'poster="'..options.Poster..'" 'else '')..'></video><input id="editor" tabindex="-1" value="A&#x1f600;BC"><p id="neighbor">retained neighbor</p>'..scripts)
  local mountOptions={JavaScript=options.Scripting~=false,RenderWorkBudgetMS=0,DocumentURL='https://video.test/root/index.html',Images={['wide.png']='101',['tall.png']='102',['bad.png']='109'},SVGs={['wide.svg']='<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100"/></svg>'},Videos={['first.webm']='200',['second.webm']='201'},Audio={['first.mp3']='300',['second.mp3']='301'},JavaScriptServices={VideoServices=options.VideoServices,Task=tasks,Clock=function()return time end,RunService=run,ResourceServices=resources,AudioServices={Task=tasks,Instance=instance,RunService=run,ContentProvider=provider}}}
  if options.StylesheetOnly then mountOptions.JavaScriptServices.LoadStylesheet=function()return ''end end
  page=module.mount(factory.create('Frame',factory.create('ScreenGui',nil,{}),{}),html,mountOptions)
  local realm=page.JavaScriptRuntime;local node=Node.findById(page.Document,'v');local item=node and tree.MediaByNode[node]
  local gui,box,frame,display=if item then item.Gui else nil,if item then item.BoxGui else nil,if item then item.VideoGui else nil,if item then item.VideoDisplay else nil
  local function drain()for _=1,(options.DrainBudget or 160)do if #jobs==0 then return end;local job=table.remove(jobs,1);if not job.Cancelled then time=math.max(time,job.Due);local thread=coroutine.create(job.Callback);local ok,message=coroutine.resume(thread);check(ok,tostring(message))end end;error('Presentation queue did not converge')end
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
  return {Page=page,Tree=tree,Item=item,Node=node,Realm=realm,Run=script,Direct=direct,Drain=drain,Resume=resume,Retained=retained,Geometry=geometry,Dimensions=dimensions,Destroy=destroy,Counts=counts,Waiting=waiting,Jobs=jobs,SVG=svgs,Native=function()return item.VideoPlayer or item.VideoGui end,Input=input,SetHits=function(value)hits=value end,Options=options,Focused=function()return focused end,Focus=focus,Instances=natives,Created=created}
 end





 local completed=0
 local seen={}
 local expected={
  'VideoPlayer immediate mutation stop','VideoPlayer immediate mutation new selection','VideoPlayer initializer stop','VideoPlayer initializer new selection',
  'VideoFrame immediate mutation stop','VideoFrame immediate mutation new selection','VideoFrame initializer stop','VideoFrame initializer new selection',
  'VideoPlayer empty child stop','VideoPlayer empty child new selection','VideoPlayer stopped Add batch',
  'VideoFrame empty child stop','VideoFrame empty child new selection','VideoFrame stopped Add batch',
  'original acquire error nil','original acquire error false','original acquire error table',
 }
 local function mark(name)check(table.find(expected,name)~=nil,'Unexpected acquire control '..name);check(not seen[name],'Duplicate acquire control '..name);seen[name]=true;completed+=1;print('BARRIER_V2_ACQUIRE_CONTROL',name)end
 for _,modern in {true,false}do
  local backend=if modern then'VideoPlayer'else'VideoFrame'
  for _,mode in {'stop','new selection'}do
   local h=fixture({Modern=modern,HTML='<video id=v controls src=first.webm preload=auto></video><input id=editor value="A&#x1f600;BC"><p id=neighbor>retained</p><script>var m=document.getElementById("v"),e=document.getElementById("editor");</script>'});h.Drain();h.Focus();local item=h.Item;local r=item.VideoSelection;local width,height=item.VideoWidth,item.VideoHeight;local entered=false;local original=h.Realm.ResourcesChanged
   h.Realm.ResourcesChanged=function(runtime)
    if not entered then entered=true;check(h.Page.Media:GetPendingDocumentResources()==1,'Actual setter acquisition');if mode=='stop'then h.Page.Media:Destroy()else h.Direct('m.src="first.webm"');h.Page:LoadVideo('v')end end
    return original(runtime)
   end
   h.Direct('m.src="second.webm"')
   check(entered,'Actual immediate VIDEO setter notification callback')
   if mode=='stop'then check(r.Item==nil and item.VideoSelection==nil and item.VideoWidth==width and item.VideoHeight==height,'Stopped mutation owner receives no stale exposed-metadata field write')
   else h.Page:FlushScriptLayout();h.Drain();check(item.SelectedSource=='first.webm'and item.MetadataEmitted and h.Counts.NativeLoads==2,'Reentrant setter selects sole last raw source');h.Retained()end
   h.Realm.ResourcesChanged=original;h.Destroy();mark(backend..' immediate mutation '..mode)
  end
  for _,mode in {'stop','new selection'}do
   local h=fixture({Modern=modern,HTML='<video id=v controls src=first.webm preload=auto></video><div id=slot></div><input id=editor value="A&#x1f600;BC"><p id=neighbor>retained</p><script>var m=document.getElementById("v"),e=document.getElementById("editor");</script>'});h.Drain();h.Focus();local entered=false;local original=h.Realm.ResourcesChanged;local madeBefore=#h.Instances;local r,item,innerEpoch
   h.Realm.ResourcesChanged=function(runtime)
    local fresh=Node.findById(h.Page.Document,'fresh');local freshItem=fresh and h.Tree.MediaByNode[fresh]
    if not entered and freshItem and freshItem.VideoSelection then entered=true;item=freshItem;r=item.VideoSelection;check(h.Page.Media:GetPendingDocumentResources()==1,'Dynamic Media:Add registers exact VIDEO reservation before native setup');if mode=='stop'then h.Page.Media:Destroy()else h.Page:LoadVideo('fresh');innerEpoch=r.SelectionEpoch end end
    return original(runtime)
   end
   h.Run('var f=document.createElement("video");f.id="fresh";f.controls=true;f.preload="auto";f.src="second.webm";document.getElementById("slot").appendChild(f)')
   check(entered and r~=nil,'Actual dynamic initializer acquisition callback')
   if mode=='stop'then check(r.Item==nil and item.VideoSelection==nil and #h.Instances==madeBefore and item.Muted==nil and item.Duration==nil,'Stopped initializer does not allocate native objects or reset dead item default fields')
   else check(r.SelectionEpoch==innerEpoch and item.SelectedSource=='second.webm'and item.MetadataEmitted and item.VideoPlayer==nil,'Initializer outer invocation cannot overwrite nested selection or create an obsolete backend')end
   h.Realm.ResourcesChanged=original;h.Destroy();mark(backend..' initializer '..mode)
  end
 end
 for _,modern in {true,false}do
  local backend=if modern then'VideoPlayer'else'VideoFrame'
  for _,mode in {'stop','new selection'}do
   local h=fixture({Modern=modern,HTML='<video id=v controls preload=auto></video><input id=editor value="A&#x1f600;BC"><p id=neighbor>retained</p><script>var m=document.getElementById("v"),e=document.getElementById("editor");</script>'});h.Drain();h.Focus();local item=h.Item;local r=item.VideoSelection;local entered=false;local innerEpoch;local original=h.Realm.ResourcesChanged;local loads=0
   h.Page.Events:On(h.Node,'loadstart',function()loads+=1 end)
   h.Realm.ResourcesChanged=function(runtime)
    if not entered then entered=true;check(h.Page.Media:GetPendingDocumentResources()==1,'First child SOURCE acquires real document reservation');if mode=='stop'then h.Page.Media:Destroy()else h.Page:LoadVideo('v');innerEpoch=r.SelectionEpoch;if item.RateSupported then h.Page:SetMediaPlaybackRate('v',1.5)end end end
    return original(runtime)
   end
   h.Run('var s=document.createElement("source");s.src="first.webm";m.appendChild(s)')
   check(entered,'Actual empty child insertion acquire callback')
   if mode=='stop'then check(r.Item==nil and item.VideoSelection==nil and h.Counts.NativeLoads==0 and loads==0,'Stopped empty-child owner schedules no old selection or native IO')
   else check(r.SelectionEpoch==innerEpoch and item.SelectedSource=='first.webm'and item.MetadataEmitted and h.Counts.NativeLoads==1 and loads==1,'Outer empty-child insertion cannot duplicate nested selection or loadstart');if item.RateSupported then check(item.PlaybackRate==1.5,'Empty-child continuation retains later rate')end;h.Retained()end
   h.Realm.ResourcesChanged=original;h.Destroy();mark(backend..' empty child '..mode)
  end
  local h=fixture({Modern=modern,HTML='<video id=v controls src=first.webm preload=auto></video><div id=slot></div><input id=editor><p id=neighbor>retained</p><script>var m=document.getElementById("v"),e=document.getElementById("editor");</script>'});h.Drain();local entered=false;local original=h.Realm.ResourcesChanged;local before=#h.Instances
  h.Realm.ResourcesChanged=function(runtime)
   local first=Node.findById(h.Page.Document,'fresh');local item=first and h.Tree.MediaByNode[first]
   if not entered and item and item.VideoSelection then entered=true;h.Page.Media:Destroy()end
   return original(runtime)
  end
  h.Run('var a=document.createElement("video"),b=document.createElement("video");a.id="fresh";b.id="fresh2";a.controls=b.controls=true;a.src=b.src="first.webm";document.getElementById("slot").append(a,b)')
  local second=Node.findById(h.Page.Document,'fresh2');local secondItem=h.Tree.MediaByNode[second]
  check(entered and secondItem and secondItem.VideoSelection==nil and secondItem.VideoPlayer==nil and #h.Instances==before,'Stopped Add batch cannot initialize a following VIDEO or allocate obsolete native backend')
  h.Realm.ResourcesChanged=original;h.Destroy();mark(backend..' stopped Add batch')
 end
 for _,kind in {'nil','false','table'}do
  local value=if kind=='nil'then nil elseif kind=='false'then false else {Original='acquire payload'}
  local h=fixture({Modern=true,HTML='<video id=v controls src=first.webm preload=auto></video><input id=editor><p id=neighbor>retained</p><script>var m=document.getElementById("v"),e=document.getElementById("editor");</script>'});h.Drain();h.Page:SetMediaPlaybackRate('v',1.5);local r=h.Item.VideoSelection;local epoch=r.SelectionEpoch;local original=h.Realm.ResourcesChanged
  h.Realm.ResourcesChanged=function()error(value,0)end;local ok,message=pcall(h.Page.LoadVideo,h.Page,'v');check(not ok and message==value and r.SelectionEpoch==epoch and h.Item.PlaybackRate==1.5,'Acquire preserves exact '..kind..' error and never continues source reset');h.Realm.ResourcesChanged=original;h.Destroy();mark('original acquire error '..kind)
 end
 check(completed==17 and #expected==17,'Exact additive acquire control inventory');for _,name in expected do check(seen[name],'Missing acquire control '..name)end
 print('BARRIER_V2_ACQUIRE_SUMMARY','controls='..completed,'assertions='..checks)
end

end)()
 runAcquire(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference,Selection)
end
