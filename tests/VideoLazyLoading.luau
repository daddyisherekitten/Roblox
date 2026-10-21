--!strict
-- Mounted lazy VIDEO/poster continuations, retained owners and raw ordinary Chrome comparison.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference)
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
   if object and object.ClassName=='ImageLabel'and object.Image then
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
  local loadStates={};local mountOptions={DocumentLoadStateChanged=function(state)table.insert(loadStates,state)end,LazyMediaMargin=options.Margin,JavaScript=options.Scripting~=false,RenderWorkBudgetMS=0,DocumentURL='https://video.test/root/index.html',Images={['wide.png']='101',['tall.png']='102',['bad.png']='109'},SVGs={['wide.svg']='<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100"/></svg>'},Videos={['first.webm']='200',['second.webm']='201'},Audio={['first.mp3']='300',['second.mp3']='301'},JavaScriptServices={VideoServices=options.VideoServices,Task=tasks,Clock=function()return time end,RunService=run,ResourceServices=resources,AudioServices={Task=tasks,Instance=instance,RunService=run,ContentProvider=provider}}}
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
  return {Provider=provider,LoadStates=loadStates,SetTime=function(value)time=value end,Page=page,Tree=tree,Item=item,Node=node,Realm=realm,Run=script,Direct=direct,Drain=drain,Resume=resume,Retained=retained,Geometry=geometry,Dimensions=dimensions,Destroy=destroy,Counts=counts,Waiting=waiting,Jobs=jobs,SVG=svgs,Native=function()return item.VideoPlayer or item.VideoGui end,Input=input,SetHits=function(value)hits=value end,Options=options,Focused=function()return focused end,Focus=focus,Instances=natives,Created=created}
 end

 local completed=0
 local function mark(label)completed+=1;print('VIDEO_LAZY_CONTROL',label)end
 local function markup(attributes,realm,style)
  return '<!doctype html><style>body{margin:0}video{display:block;width:200px;height:100px;margin-top:100000px;'..(style or'')..'}</style><video id=v muted preload=auto src="second.webm" poster="wide.png" '..attributes..'></video><input id=editor value="A&#x1f600;BC"><p id=neighbor>retained</p>'..(if realm then '<script>var m=document.getElementById("v"),e=document.getElementById("editor");window.loadSeen=0;window.addEventListener("load",()=>loadSeen++)</script>'else '')
 end
 local function requestCount(h,native,poster,label)
  check(h.Counts.NativeLoads==native and h.Counts.PosterLoads==poster,label..' actual native/video poster IO count '..h.Counts.NativeLoads..'/'..h.Counts.PosterLoads)
 end
 local function rootScroll(h,y)
  h.Page.Root.CanvasPosition=Vector2.new(0,y);h.Page.Root:GetPropertyChangedSignal('CanvasPosition'):Fire();h.Drain()
 end
 for _,modern in {true,false}do
  local backend=if modern then'VideoPlayer'else'VideoFrame'
  for _,realm in {true,false}do
   local mode=backend..'/'..(if realm then'Realm'else'JS enabled without realm')
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',realm)})
   h.Drain();check((h.Realm~=nil)==realm,mode..' exact realm existence');if not realm then check(table.concat(h.LoadStates,',')=='interactive,complete',mode..' actual no-Realm load completion')end
   requestCount(h,0,0,mode..' offscreen lazy')
   check(h.Page.LazyMedia.Count==2 and h.Page.Media:GetPendingDocumentResources()==0 and h.Page.PosterPendingCount==0,mode..' deferred resources never hold load barrier')
   check(h.Item.VideoSelection.Phase=='lazy'and h.Item.VideoSelection.DelayLoadFlag==false and h.Item.Gui.Parent~=nil,mode..' retained offscreen element and deferred selection')
   if realm then check(h.Realm.Window.Get('loadSeen')==1,mode..' lazy page load is unblocked');h.Run('window.loadingState=m.loading');check(h.Realm.Window.Get('loadingState')=='lazy',mode..' actual loading IDL')end
   local owner,native,source=h.Item.VideoSelection,h.Native(),h.Item.SelectedSource
   local box=h.Tree.NodeBoxes[h.Node];local y=0;local ancestor=h.Node;while ancestor do local b=h.Tree.NodeBoxes[ancestor];if b then y+=b.PaintY or b.LayoutY or 0 end;ancestor=ancestor.Parent end;check(box~=nil and y>90000,mode..' genuinely out of viewport '..y)
   rootScroll(h,100000)
   requestCount(h,1,1,mode..' real root scroll resumes both')
   check(h.Page.LazyMedia.Count==0 and h.Item.VideoSelection==owner and h.Native()==native and h.Item.SelectedSource==source,mode..' same native/selection/source retained')
   check(h.Page.PosterPendingCount==0 and h.Page.Media:GetPendingDocumentResources()==0,mode..' completed work releases counters')
   for _=1,4 do rootScroll(h,100000);h.Page.LazyMedia:Check(true);h.Drain()end
   requestCount(h,1,1,mode..' no duplicate scheduling')
   if realm then check(h.Realm.Window.Get('loadSeen')==1,mode..' load event not repeated')end
   h.Retained();h.Destroy();check(h.Page.LazyMedia.Count==0,mode..' scheduler disposed');mark(mode..' scroll/retention/load')
  end
  for _,attribute in {'','loading=eager','loading=unknown','loading=" lazy "','loading=LAZY'}do
   local expectedLazy=attribute=='loading=LAZY'
   local h=fixture({Modern=modern,HTML=markup(attribute,true)});h.Drain();requestCount(h,if expectedLazy then 0 else 1,if expectedLazy then 0 else 1,backend..' enum '..attribute)
   h.Run('window.value=m.loading');check(h.Realm.Window.Get('value')==(if expectedLazy then'lazy'else'eager'),backend..' limited known-value loading reflection '..attribute)
   h.Destroy();mark(backend..' enum '..attribute)
  end
  do
   local h=fixture({Modern=modern,Scripting=false,HTML=markup('loading=lazy',false)});h.Drain();requestCount(h,1,1,backend..' scripting disabled eager override');check(h.Realm==nil and h.Page.LazyMedia.Count==0,'No author realm or lazy slot');h.Destroy();mark(backend..' disabled scripting eager')
  end
  for _,value in {'eager','invalid','remove'}do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',true)});h.Drain();local owner,native,source=h.Item.VideoSelection,h.Native(),h.Item.SelectedSource
   h.Run(if value=='remove'then'm.removeAttribute("loading")'else'm.loading="'..value..'"')
   requestCount(h,1,1,backend..' out-of-view loading '..value)
   check(h.Item.VideoSelection==owner and h.Native()==native and h.Item.SelectedSource==source and owner.SelectionEpoch==1 and owner.Generation==1,backend..' loading does not reset source epoch/generation/native')
   check(not owner.DelayLoadFlag and h.Page.LazyMedia.Count==0,backend..' resumed lazy selection does not retroactively delay document')
   h.Run('m.loading="lazy";m.loading="eager"');requestCount(h,1,1,backend..' loaded source not restarted');h.Retained();h.Destroy();mark(backend..' loading mutation '..value)
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',true,'visibility:hidden;')});h.Drain();requestCount(h,0,0,backend..' hidden offscreen remains lazy');h.Run('m.loading="eager"');requestCount(h,1,1,backend..' hidden out-of-view eager resumes');h.Destroy();mark(backend..' hidden eager')
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',true)});h.Drain();h.Run('m.autoplay=true;m.preload="auto"');requestCount(h,0,0,backend..' autoplay/preload cannot bypass lazy')
   h.Run('window.outcome="pending";m.play().then(()=>outcome="played",e=>outcome=e.name)')
   requestCount(h,1,0,backend..' explicit play resumes media only');check(h.Realm.Window.Get('outcome')=='played'and h.Page.LazyMedia.Count==1 and h.Item.Playing,backend..' synchronous resumption then actual play Promise')
   h.Run('m.loading="eager"');requestCount(h,1,1,backend..' poster remains independently resumable');h.Destroy();mark(backend..' play media-only')
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',true)});h.Drain();h.Run('m.load()');requestCount(h,0,0,backend..' load resumes old fetch then resets before stale IO')
   check(h.Page.LazyMedia.Count==2 and h.Item.VideoSelection.SelectionEpoch==2 and h.Item.VideoSelection.Phase=='lazy',backend..' new load algorithm may lazily suspend again')
   rootScroll(h,100000);requestCount(h,1,1,backend..' reset lazy selection resumes once');h.Destroy();mark(backend..' load reset media-only')
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',true)});h.Drain();h.Focus();h.Run('m.poster="tall.png";m.poster="wide.png";m.poster="tall.png"');requestCount(h,0,0,backend..' poster replacements deferred');check(h.Page.LazyMedia.Count==2,'One current media and poster slot')
   h.Run('m.loading="eager"');requestCount(h,1,1,backend..' newest poster only fetched');check(h.Item.PosterSource=='tall.png'and h.Item.PosterWidth==120 and h.Item.PosterHeight==240,backend..' newest actual poster published');h.Retained();h.Destroy();mark(backend..' poster replacement retained editor')
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',true),DelayPoster=true});h.Drain();h.Run('m.loading="eager"');check(h.Page.PosterPendingCount==1 and #h.Waiting==1,backend..' resumed actual poster holds request barrier')
   h.Destroy();h.Resume();requestCount(h,1,1,backend..' disposed suspended native work never restarted');check(h.Page.LazyMedia.Count==0 and h.Page.PosterPendingCount==0 and h.Item.PosterReady==false,backend..' stale poster result inert');mark(backend..' resumed suspended disposal')
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',true)});h.Drain();h.Run('m.remove()');check(h.Page.LazyMedia.Count==0,backend..' removal cancels both pending slots');requestCount(h,0,0,backend..' removal does not start IO');h.Destroy();mark(backend..' pending removal')
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',true)});h.Drain();h.Run('m.style.transform="translateY(-100000px)"');requestCount(h,1,1,backend..' transform-only exposure');h.Retained();h.Destroy();mark(backend..' transform-only notification')
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',true)});h.Drain();h.Run('var effect=m.animate([{transform:"translateY(0px)"},{transform:"translateY(-100000px)"}],{duration:1000,fill:"both"});effect.pause();effect.currentTime=1000');requestCount(h,1,1,backend..' paused WAAPI currentTime exposure');h.Retained();h.Destroy();mark(backend..' WAAPI compositor notification')
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',false,'margin-top:0;position:fixed;left:10px;top:20px;')});h.Drain();requestCount(h,1,1,backend..' viewport-fixed target');h.Destroy();mark(backend..' fixed viewport')
  end
  do
   local source='<style>body{margin:0}#clip{width:300px;height:100px;overflow:auto}video{display:block;width:200px;height:100px;margin-top:500px}</style><div id=clip><video id=v preload=auto muted loading=lazy src="second.webm" poster="wide.png"></video></div>'
   local h=fixture({Modern=modern,HTML=source});h.Drain();requestCount(h,0,0,backend..' overflow ancestor clips pending target');local clip=h.Tree.NodeBoxes[Node.findById(h.Page.Document,'clip')];check(clip and clip.ScrollGui,backend..' actual ancestor scrolling frame')
   clip.ScrollGui.CanvasPosition=Vector2.new(0,500);clip.ScrollGui:GetPropertyChangedSignal('CanvasPosition'):Fire();h.Drain();requestCount(h,1,1,backend..' real nested scroll notification resumes');h.Retained();h.Destroy();mark(backend..' ancestor clip and nested scroll')
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',false)});h.Drain();h.Page.Root.AbsoluteSize=Vector2.new(800,100200);h.Page.Root:GetPropertyChangedSignal('AbsoluteSize'):Fire();h.Drain();requestCount(h,1,1,backend..' viewport resize exposes pending target');h.Destroy();mark(backend..' viewport resize')
  end
  do
   local source='<style>body{margin:0}#clip{width:300px;height:100px;overflow:hidden;margin-top:100000px}video{display:block;width:200px;height:100px;position:fixed;left:10px;top:20px}</style><div id=clip><video id=v preload=auto muted loading=lazy src="second.webm" poster="wide.png"></video></div>'
   local h=fixture({Modern=modern,HTML=source});h.Drain();requestCount(h,1,1,backend..' viewport fixed escapes offscreen ancestor clipping');h.Destroy();mark(backend..' fixed clipping boundary')
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',true)});h.Drain();h.Run('m.src="first.webm";m.src="second.webm"');requestCount(h,0,0,backend..' lazy source reset cancels old continuation');check(h.Page.LazyMedia.Count==2,'Newest pending source and poster only');rootScroll(h,100000);requestCount(h,1,1,backend..' newest source once');check(table.concat(h.Counts.Requests,',')=='rbxassetid://201',backend..' stale first source never reaches native IO');h.Retained();h.Destroy();mark(backend..' lazy source replacement')
  end
  do
   local source=markup('loading=lazy',true):gsub('</script>',';m.loading="eager";</script>')
   local h=fixture({Modern=modern,HTML=source,DelayPoster=true});h.Drain();check(h.Realm.Window.Get('loadSeen')==0 and h.Page.PosterPendingCount==1,backend..' poster resumed in initial script delays document load');h.Resume();check(h.Realm.Window.Get('loadSeen')==1 and h.Page.PosterPendingCount==0,backend..' resumed poster releases original document load once');h.Destroy();mark(backend..' eager resumption before initial load')
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',true)});h.Drain();local old=h.Item.PosterURL;h.Run('var base=document.createElement("base");base.href="https://changed.test/new/";document.head.append(base)');check(h.Item.PosterURL==old and old=='https://video.test/root/wide.png',backend..' deferred poster captures old base URL');h.Run('m.loading="eager"');requestCount(h,1,1,backend..' captured poster fetch survives base mutation');check(h.Item.PosterURL==old,'Continuation did not resolve against later base');h.Destroy();mark(backend..' deferred poster base capture')
  end
  do
   local source='<style>body{margin:0}#clip{width:300px;height:100px;overflow:hidden;margin-top:100000px}#fixed{position:fixed;left:10px;top:20px;width:300px;height:200px;overflow:hidden}video{display:block;width:200px;height:100px}</style><div id=clip><div id=fixed><video id=v preload=auto muted loading=lazy src="second.webm" poster="wide.png"></video></div></div>'
   local h=fixture({Modern=modern,HTML=source});h.Drain();requestCount(h,1,1,backend..' fixed parent escapes ancestor clipping');h.Destroy();mark(backend..' descendant fixed clipping boundary')
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',false)});h.Drain();local loads=h.Counts.NativeLoads;h.Page.Media:Destroy();check(h.Page.LazyMedia.Count==0,'Owner-only destroy removes deferred media/poster closures');rootScroll(h,100000);requestCount(h,loads,0,'Stopped owner does not restart native IO');h.Destroy();mark(backend..' owner-only pending teardown')
  end
  do
   local source='<style>body{margin:0}#clip{width:300px;height:100px;overflow:hidden;margin-top:100000px}video{display:block;width:200px;height:100px;position:absolute;left:0;top:0}</style><div id=clip><video id=v preload=auto muted loading=lazy src="second.webm" poster="wide.png"></video></div>'
   local h=fixture({Modern=modern,HTML=source});h.Drain();requestCount(h,1,1,backend..' absolute initial-containing-block target escapes offscreen ancestor clipping');h.Destroy();mark(backend..' absolute clipping boundary')
  end
  do
   local source='<style>body{margin:0}#outer{display:flow-root;position:relative;width:300px;height:200px}#clip{width:300px;height:100px;overflow:hidden;margin-top:100000px}#absolute{position:absolute;left:0;top:0}video{display:block;width:200px;height:100px}</style><div id=outer><div id=clip><div id=absolute><video id=v preload=auto muted loading=lazy src="second.webm" poster="wide.png"></video></div></div></div>'
   local h=fixture({Modern=modern,HTML=source});h.Drain();requestCount(h,1,1,backend..' absolute parent containing chain escapes intermediate overflow');h.Destroy();mark(backend..' descendant absolute clipping boundary')
  end
  do
   local source='<style>body{margin:0}#clip{position:relative;width:300px;height:100px;overflow:hidden}video{display:block;width:200px;height:100px;position:absolute;left:0;top:500px}</style><div id=clip><video id=v preload=auto muted loading=lazy src="second.webm" poster="wide.png"></video></div>'
   local h=fixture({Modern=modern,HTML=source});h.Drain();requestCount(h,0,0,backend..' absolute target still clipped by its actual containing block');h.Destroy();mark(backend..' actual containing block clip retained')
  end
  do
   local source='<style>body{margin:0}#spacer{height:100000px}video{width:200px;height:100px}</style><div id=spacer></div><video id=v preload=auto muted loading=lazy src="second.webm" poster="wide.png"></video>'
   local h=fixture({Modern=modern,HTML=source});h.Drain();check(h.Tree.NodeBoxes[h.Node]==nil and h.Item.GeometryBox~=nil,backend..' actual inline replaced GeometryBox');requestCount(h,0,0,backend..' inline offscreen deferred');rootScroll(h,100000);requestCount(h,1,1,backend..' inline root scroll resumes actual fallback geometry');h.Retained();h.Destroy();mark(backend..' inline no-realm geometry')
  end
  for _,kind in{'nil','false','table'}do
   local token=if kind=='false'then false elseif kind=='table'then{}else nil
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',true),DelayPoster=true});h.Drain();h.Run('m.loading="eager"');local present=h.Page.MediaPresentationChanged
   h.Page.MediaPresentationChanged=function()error(token,0)end
   local thread=table.remove(h.Waiting,1);check(thread~=nil,'Actual native pending poster');local ok,value=coroutine.resume(thread)
   check(not ok and value==token and h.Page.PosterPendingCount==0,backend..' poster completion finally releases barrier before '..kind..' error')
   h.Page.MediaPresentationChanged=present;h.Drain();h.Destroy();check(h.Page.PosterPendingCount==0,'Disposed failed publication counter balanced');mark(backend..' poster publication failure '..kind)
  end
  for _,kind in{'nil','false','table'}do
   local token=if kind=='false'then false elseif kind=='table'then{}else nil
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',false)});h.Drain();local load=h.Page.ResourceLoadHost.LoadImage
   h.Page.ResourceLoadHost.LoadImage=function()error(token,0)end;h.Node.Attributes.loading='eager'
   local ok,value=pcall(h.Page.LazyMedia.AttributeChanged,h.Page.LazyMedia,h.Node)
   check(not ok and value==token and h.Page.PosterPendingCount==0 and h.Page.LazyMedia.Count==0,backend..' failed poster acquisition finally balanced '..kind)
   h.Page.ResourceLoadHost.LoadImage=load;h.Drain();h.Destroy();mark(backend..' poster acquisition failure '..kind)
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',false,'margin-top:0;')});h.Drain();requestCount(h,1,1,backend..' initially visible without realm');h.Destroy();mark(backend..' visible no realm')
  end
  do
   local h=fixture({Modern=modern,HTML=markup('loading=lazy',false),Margin=100001});h.Drain();requestCount(h,1,1,backend..' host configured margin');h.Destroy();mark(backend..' host margin')
  end
 end
 -- Preserve the independent Chrome capture, including observed target deltas.
 check(reference.target.sha256=='49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f'and#reference.cases==13,'Independent ordinary browser fixture and pinned source provenance')
 local function mediaRequests(list)local count=0;for _,request in list do if request.url:match('%.png$')or request.url:match('%.wav$')then count+=1 end end;return count end
 for _,raw in reference.cases do
  check(raw.before.complete=='complete','Native lazy fixture document load '..raw.name)
  if raw.name=='lazy offscreen'or raw.name=='lazy mixed case'then check(mediaRequests(raw.initialRequests)==0 and raw.before.loading=='lazy','Raw Chrome offscreen IO deferred')end
  if raw.name=='lazy play'or raw.name=='lazy load'then check(mediaRequests(raw.allRequests)==0 and raw.after.ready==0,'Raw Chrome play/load delta remains explicit')end
 end
 print('VideoLazyLoading: '..completed..' mounted cases; '..checks..' assertions; ordinary Chrome raw capture retained separately from frozen play/load/scripting-disabled poster deltas')
end
