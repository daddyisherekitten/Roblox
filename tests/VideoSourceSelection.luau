--!strict
-- Separately named frozen/native DOM fallback counterpart. Full original41
-- remains archived; only this exact rejection/count expression is corrected.
local originalSHA256="b00115c4e09c786fa27bed281b87eaa51bac11e5df34116fd5592a3e166db5b1"
local originalExpression=[=[h.Realm.Window.Get('rejects')=='[true,true]'and #h.Node.Children==2 and r.Gap==0]=]

-- Actual HTMLPage startup, Controller and HTMLScripts; deterministic native
-- metadata/resource completion is distinct from Chrome and Studio pixels.
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
 local seen={};local expected={
  'VideoPlayer actual VM gap and None PagePlay','VideoFrame actual VM gap and None PagePlay',
  'VideoPlayer actual Controller Tab Space','VideoFrame actual Controller Tab Space',
  'VideoPlayer actual Controller pointer Play','VideoFrame actual Controller pointer Play',
  'VideoPlayer superseded serial native jobs and editor identity','VideoFrame superseded serial native jobs and editor identity',
  'VideoPlayer actual native status callback','VideoFrame actual native status callback',
  'VideoPlayer postmetadata terminal failure','VideoFrame postmetadata terminal failure',
  'VideoPlayer complete qualification chain','VideoFrame complete qualification chain',
  'VideoPlayer waiting insertion and source attribute stability','VideoFrame waiting insertion and source attribute stability',
  'VideoPlayer direct src activation and removal','VideoFrame direct src activation and removal',
  'VideoPlayer suspended disposal and stale completion','VideoFrame suspended disposal and stale completion',
  'VideoPlayer terminal direct error stays quiescent','VideoFrame terminal direct error stays quiescent',
  'VideoPlayer historical SOURCE document and repeated writes','VideoFrame historical SOURCE document and repeated writes',
  'VideoPlayer source reset stops retained native transport','VideoFrame source reset stops retained native transport',
  'VideoPlayer native binding reentry guards','VideoFrame native binding reentry guards',
  'actual Realm stable selection before SOURCE error task',
  'HTML-expanded SOURCE vs foreign/unsupported child preflight','noRealm explicit owner live-gap hooks',
  'actual has/empty selector retention','unrelated writes and current media updates are idle-free',
  'noRealm reentrant resolver disposal nil','noRealm reentrant resolver disposal false','noRealm reentrant resolver disposal table',
  'noRealm Work4 owner-only destroy after checkpoint','noRealm over-1024 ordered SOURCE tasks',
  'noRealm CanLoad resolver nil then page destruction','noRealm CanLoad resolver nil then owner destruction',
  'Realm CanLoad resolver nil then new source epoch',
 }
 local function mark(name)check(table.find(expected,name)~=nil,'Unexpected control '..name);check(not seen[name],'Duplicate control '..name);seen[name]=true;completed+=1;print('VIDEO_LIVE_CONTROL',name)end
 local function html(attrs,first)
  return '<button id=before>before</button><video id=v controls '..attrs..'><source id=s1 src='..(first or'missing.media')..'><source id=s2 src=second.webm></video><input id=editor value="A&#x1f600;BC"><p id=neighbor>neighbor</p><script>var m=document.getElementById("v"),e=document.getElementById("editor");</script>'
 end
 local function events(h)
  local out={Source={},Media={}}
  for _,n in h.Node.Children do if n.Kind=='Element'then h.Page.Events:On(n,'error',function(ev)check(ev.Target==n and not ev.Bubbles and not ev.Cancelable,'SOURCE event identity/options');table.insert(out.Source,n.Attributes.id)end)end end
  h.Page.Events:On(h.Node,'error',function(ev)check(ev.Target==h.Node and not ev.Bubbles and not ev.Cancelable,'Media terminal event identity/options');table.insert(out.Media,'error')end)
  return out
 end
 for _,modern in {true,false}do
  local backend=if modern then'VideoPlayer'else'VideoFrame'
  do
   local h=fixture({HTML=html('preload=none'),Modern=modern,Scripting=true});local ev=events(h);h.Drain();local item=h.Item;local r=item.VideoSelection
   check(r and r.Raw=='missing.media'and r.Gap==1 and r.Phase=='deferred'and h.Counts.NativeLoads==0,'None selects first unavailable candidate without native preload')
   h.Run('var x=document.createElement("source");x.id="inserted";x.src="first.webm";m.insertBefore(x,document.getElementById("s2"));document.getElementById("s1").remove()')
   check(r.Gap==0 and r.Raw=='missing.media'and h.Counts.NativeLoads==0,'Real VM insert at gap/remove candidate preserves live pointer and deferred resource')
   local epoch=r.SelectionEpoch;h.Page:PlayMedia('v');h.Drain()
   check(table.concat(h.Counts.Requests or{},',')=='rbxassetid://200'and table.concat(ev.Source,',')=='s1'and #ev.Media==0 and item.SelectedSource=='first.webm'and item.Playing,'Page Play resumes original failed SOURCE and selects actual inserted gap candidate')
   check(r.SelectionEpoch==epoch and r.Gap==1,'Ordinary fallback keeps selection epoch and advances shared core gap');h.Retained();h.Destroy();mark(backend..' actual VM gap and None PagePlay')
  end
  do
   local h=fixture({HTML=html('preload=none'),Modern=modern,Scripting=true});local ev=events(h);h.Drain();local item=h.Item
   check(h.Page:FocusDOMElement(Node.findById(h.Page.Document,'before'),true),'Actual before-button focus')
   h.Input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Tab},false)
   check(h.Page.FormModel:GetActiveElement()==h.Node,'Native Tab reaches deferred unavailable VIDEO control')
   h.Input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Space},false);h.Drain()
   check(item.Playing and item.SelectedSource=='second.webm'and table.concat(ev.Source,',')=='s1'and h.Counts.NativeLoads==1,'Native keyboard resumes ordered VIDEO source selection')
   h.Destroy();mark(backend..' actual Controller Tab Space')
  end
  do
   local h=fixture({HTML=html('preload=none'),Modern=modern,Scripting=true});local ev=events(h);h.Drain();local item=h.Item
   h.SetHits({item.PlayGui});local p=Vector2.new(7,7);local input={UserInputType=Enum.UserInputType.MouseButton1,Position=p}
   h.Input.InputBegan:Fire(input,false);h.Input.InputEnded:Fire(input,false);h.Drain()
   check(item.Playing and item.SelectedSource=='second.webm'and #ev.Source==1 and h.Counts.NativeLoads==1,'Native pointer Play resumes ordered source selection once')
   h.Destroy();mark(backend..' actual Controller pointer Play')
  end
  do
   local h=fixture({HTML=html('preload=auto','first.webm'),Modern=modern,Scripting=true,DelayVideo=true});local ev=events(h);h.Drain();local item=h.Item;local native=h.Native()
   check(#h.Waiting==1 and h.Counts.NativeLoads==1,'Actual first native load held');h.Focus();local binds=item.VideoPlayer and native.VideoContent or native.Video
   h.Direct('m.src="second.webm";window.immediate=JSON.stringify([m.videoWidth,m.videoHeight])');check(h.Realm.Window.Get('immediate')=='[0,0]','Same-script old metadata invalidated without GUI/IO')
   h.Page:FlushScriptLayout();h.Drain();h.Retained();check(h.Counts.NativeLoads==1 and #h.Waiting==1 and (item.VideoPlayer and native.VideoContent or native.Video)==binds,'New selection does not overlap old native binding/load')
   h.Resume();check(h.Counts.NativeLoads==2 and #h.Waiting==1 and not item.MetadataEmitted,'Old completion starts exactly one latest current job without metadata publication');h.Resume()
   check(item.SelectedSource=='second.webm'and item.MetadataEmitted and item.VideoWidth==80 and #ev.Source==0 and #ev.Media==0,'Latest serial source becomes current metadata');h.Retained();h.Destroy();mark(backend..' superseded serial native jobs and editor identity')
  end
  do
   local h=fixture({HTML=html('preload=auto','first.webm'),Modern=modern,Scripting=true,StatusFail=true});local ev=events(h);h.Drain()
   check(table.concat(h.Counts.Requests or{},',')=='rbxassetid://200,rbxassetid://201'and table.concat(ev.Source,',')=='s1'and #ev.Media==0 and h.Item.SelectedSource=='second.webm','Explicit native failure status cannot be reported as loaded merely because IsLoaded is true')
   h.Destroy();mark(backend..' actual native status callback')
  end
  do
   local h=fixture({HTML=html('preload=auto','first.webm'),Modern=modern,Scripting=true,ThrowAfterReady=true});local ev=events(h);h.Drain()
   check(table.concat(h.Counts.Requests or{},',')=='rbxassetid://200'and #ev.Source==0 and #ev.Media==1 and h.Item.SelectedSource=='first.webm'and h.Item.MetadataEmitted,'Native failure after usable metadata stays terminal instead of trying next SOURCE')
   h.Destroy();mark(backend..' postmetadata terminal failure')
  end
  do
   local called={};local markup='<video id=v controls preload=auto><source id=s0><source id=s1 src=""><source id=s2 src="http://[invalid]"><source id=s3 src=first.webm type="video/x-blocked"><source id=s4 src=first.webm media="(min-width:99999px)" type="video/x-later"><source id=s5 src=second.webm type="not a mime"><source id=s6 src=first.webm></video>'
   local h=fixture({HTML=markup,Modern=modern,Scripting=true,VideoServices={CanRenderSourceType=function(raw,parsed)table.insert(called,raw..':'..parsed.Essence);return false end}});local ev=events(h);h.Drain();local r=h.Item.VideoSelection
   check(table.concat(ev.Source,',')=='s0,s1,s2,s3,s4'and #ev.Media==0,'Missing/empty/invalid URL/unsupported type/nonmatching media report their actual SOURCE and continue in order')
   check(table.concat(called,',')=='video/x-blocked:video/x-blocked'and table.concat(h.Counts.Requests or{},',')=='rbxassetid://201','Only syntactically valid eligible MIME asks host capability; unknown invalid MIME is attempted without later SOURCE IO')
   check(r.Mode=='children'and r.Gap==6 and r.Candidate==h.Node.Children[6]and h.Item.SelectedSource=='second.webm'and h.Item.MetadataEmitted,'Shared selector publishes actual sixth candidate and metadata');h.Retained();h.Destroy();mark(backend..' complete qualification chain')
  end
  do
   local h=fixture({HTML=html('preload=auto','missing.media'):gsub('second.webm','also-missing.media'),Modern=modern,Scripting=true});local ev=events(h);h.Drain();local item=h.Item;local r=item.VideoSelection;local epoch=r.SelectionEpoch
   check(r.Waiting and r.Phase=='waiting'and r.Gap==2 and r.Network==3 and h.Counts.NativeLoads==0 and table.concat(ev.Source,',')=='s1,s2','Exhausted children wait after all SOURCE errors without terminal VIDEO error')
   h.Run('var x=document.createElement("source");x.id="appended";x.src="first.webm";m.appendChild(x)')
   check(not r.Waiting and r.Gap==3 and r.SelectionEpoch==epoch and item.SelectedSource=='first.webm'and item.MetadataEmitted and h.Counts.NativeLoads==1,'Actual VM append after waiting resumes from current gap on same epoch')
   h.Focus();h.Run('x.src="second.webm"');check(item.SelectedSource=='first.webm'and h.Counts.NativeLoads==1,'SOURCE src mutation does not replace the already selected resource')
   h.Page:LoadVideo('v');h.Drain();check(item.SelectedSource=='second.webm'and h.Counts.NativeLoads==2 and r.SelectionEpoch==epoch+1,'Explicit page load rereads current child data in new epoch');h.Retained();h.Destroy();mark(backend..' waiting insertion and source attribute stability')
  end
  do
   local h=fixture({HTML=html('preload=auto src=first.webm'),Modern=modern,Scripting=true});local ev=events(h);h.Drain();local item=h.Item;local r=item.VideoSelection;local first=r.SelectionEpoch
   check(item.SelectedSource=='first.webm'and h.Counts.NativeLoads==1,'Direct source precedes children')
   h.Focus();h.Run('m.removeAttribute("src")');check(item.SelectedSource=='first.webm'and item.VideoWidth==80 and r.SelectionEpoch==first and h.Counts.NativeLoads==1,'Direct src removal retains active selection and metadata')
   h.Direct('m.src="first.webm";window.immediate=JSON.stringify([m.videoWidth,m.videoHeight])');check(h.Realm.Window.Get('immediate')=='[0,0]'and h.Counts.NativeLoads==1,'Same raw src assignment invalidates metadata before flush with no IO');h.Page:FlushScriptLayout();h.Drain()
   check(r.SelectionEpoch==first+1 and item.SelectedSource=='first.webm'and h.Counts.NativeLoads==2,'Repeated source setter begins exactly one new load')
   h.Run('m.src="second.webm";m.removeAttribute("src")');check(r.SelectionEpoch==first+2 and item.SelectedSource=='second.webm'and h.Counts.NativeLoads==3 and table.concat(ev.Source,',')=='s1','Same-call set/remove still activates selection once using final child list')
   h.Run('m.src=""');check(r.Mode=='attribute'and r.Phase=='error'and h.Counts.NativeLoads==3 and item.VideoWidth==0 and #ev.Media==1,'Empty direct src is terminal and never falls through to children');h.Retained();h.Destroy();mark(backend..' direct src activation and removal')
  end
  do
   local h=fixture({HTML=html('preload=auto','first.webm'),Modern=modern,Scripting=true,DelayVideo=true});local ev=events(h);h.Drain();local item=h.Item;local r=item.VideoSelection;local native=h.Native();local signals=if modern then native:GetPropertyChangedSignal('IsLoaded')else native.Loaded;local stale=signals:Snapshot()
   check(#h.Waiting==1 and h.Counts.NativeLoads==1,'Native source load held before disposal');h.Destroy()
   check(item.VideoSelection==nil and r.Item==nil and r.Node==nil and r.LoadJob==nil and #r.Connections==0,'Disposal immediately clears selection targets and job registrations')
   local metadata=item.MetadataEmitted;for _,fn in stale do fn()end;h.Resume();check(item.MetadataEmitted==metadata and #ev.Source==0 and #ev.Media==0 and h.Counts.NativeLoads==1 and not item.Playing,'Old native callback/continuation cannot republish metadata, queue fallback or play disposed VIDEO')
   if modern then check(native.DestroyCalls==1,'Retained VideoPlayer destroyed once')else check(native.Destroyed==true,'Retained VideoFrame destroyed once by page GUI')end;mark(backend..' suspended disposal and stale completion')
  end
  do
   for _,src in {'','http://[invalid]'}do
    local h=fixture({HTML=html('preload=auto src="'..src..'"'),Modern=modern,Scripting=true});local ev=events(h);h.Drain();local item=h.Item;local r=item.VideoSelection
    check(r.Mode=='attribute'and r.Phase=='error'and not item.Loading and h.Counts.NativeLoads==0 and #ev.Media==1,'Terminal direct empty/invalid URL error settled before activation')
    h.Page:PlayMedia('v');h.Drain();check(r.Phase=='error'and not item.Loading and not item.PendingPlay and h.Counts.NativeLoads==0 and #ev.Media==1,'Page Play never leaves terminal unmapped direct error stuck in fetch')
    check(h.Page:FocusDOMElement(h.Node,true),'Failed-source controls remain focusable');h.Input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Space},false);h.Drain()
    h.SetHits({item.PlayGui});local press={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(7,7)};h.Input.InputBegan:Fire(press,false);h.Input.InputEnded:Fire(press,false);h.Drain()
    check(r.Phase=='error'and not item.Loading and not item.PendingPlay and not item.Playing and h.Counts.NativeLoads==0 and #ev.Media==1,'Actual keyboard/pointer keep terminal no-source error quiescent');h.Destroy()
   end;mark(backend..' terminal direct error stays quiescent')
  end
  do
   local h=fixture({HTML='<video id=v controls preload=none></video><input id=editor value="A&#x1f600;BC"><p id=neighbor>retained</p><script>var m=document.getElementById("v"),e=document.getElementById("editor")</script>',Modern=modern,Scripting=true});h.Drain();local starts=0;h.Page.Events:On(h.Node,'loadstart',function(ev)check(not ev.Bubbles and not ev.Cancelable,'Selection loadstart options');starts+=1 end)
   h.Run([=[var aDoc=document.implementation.createHTMLDocument("A");aDoc.head.innerHTML='<base href="https://origin.test/A/">';var s=aDoc.createElement("source");s.src="first.webm";document.adoptNode(s);var s2=document.createElement("source");s2.src="second.webm";m.append(s);m.append(s2);window.getter=s.src;]=])
   local item=h.Item;local r=item.VideoSelection
   check(r.Current=='https://origin.test/A/first.webm'and h.Realm.Window.Get('getter')=='https://video.test/root/first.webm'and h.Counts.NativeLoads==0,'Actual adopted VIDEO SOURCE selection uses original write document while reflection uses destination owner')
   check(starts==1 and r.Gap==1 and r.Candidate==h.Node.Children[1],'Separate same-script append mutations start the empty VIDEO selection only once')
   h.Page:PlayMedia('v');h.Drain();check(item.SelectedSource=='first.webm'and h.Counts.NativeLoads==1,'Historical URL seam composes with retained VIDEO backend')
   h.Focus();h.Run('aDoc.querySelector("base").href="https://origin.test/A/updated/"');h.Page:LoadVideo('v');h.Drain()
   check(r.Current=='https://origin.test/A/updated/first.webm'and h.Counts.NativeLoads==1,'Explicit VIDEO load consults still-live historical document base and None makes no IO')
   h.Run('s.src="first.webm"');check(r.Current=='https://origin.test/A/updated/first.webm'and h.Counts.NativeLoads==1,'Same-value SOURCE write does not implicitly replace selected historical URL');h.Page:LoadVideo('v');h.Drain()
   check(r.Current=='https://video.test/root/first.webm'and h.Counts.NativeLoads==1 and starts==3,'Explicit reload after successful same-value write uses current document provenance');h.Retained();h.Destroy();mark(backend..' historical SOURCE document and repeated writes')
  end
  do
   for _,kind in {'empty direct','invalid direct','empty children'}do
    local h=fixture({HTML=html('preload=auto','first.webm'),Modern=modern,Scripting=true});h.Drain();local item=h.Item;local native=h.Native();h.Page:PlayMedia('v');h.Drain();h.Focus()
    check(item.Playing and(if modern then native.IsPlaying else native.Playing)and h.Counts.NativeLoads==1,'Current retained native transport playing before empty reset')
    if kind=='empty direct'then h.Run('m.src=""')elseif kind=='invalid direct'then h.Run('m.src="http://[invalid]"')else h.Run('m.replaceChildren()');check(item.Playing and(if modern then native.IsPlaying else native.Playing),'SOURCE child removal alone retains active native transport');h.Page:LoadVideo('v');h.Drain()end
    check(not item.Playing and not(if modern then native.IsPlaying else native.Playing)and h.Counts.NativeLoads==1,'Empty selection reset stops old native playback without another native load')
    check((if modern then native.VideoContent else native.Video)==(if modern then'content:none'else'')and item.Source==nil and item.VideoWidth==0,'Empty selection clears retained native content binding and metadata');h.Retained();h.Destroy()
   end;mark(backend..' source reset stops retained native transport')
  end
  do
   for _,kind in {'destroy','new epoch'}do
    local h=fixture({HTML=html('preload=none','first.webm'),Modern=modern,Scripting=true});h.Drain();local item=h.Item;local r=item.VideoSelection;local entered,stale=false,0
    h.Options.PositionHook=function()if not h.Page.Alive or r.SourceInvalidated then stale+=1 end end
    h.Options.VideoBindHook=function(value)if value=='rbxassetid://201'and not entered then entered=true;if kind=='destroy'then h.Page:Destroy()else h.Direct('m.src="first.webm";m.preload="none"')end end end
    h.Run('m.src="second.webm"');check(entered and stale==0,'Native source bind '..kind..' prevents stale TimePosition publication')
    if kind=='destroy'then check(item.VideoSelection==nil and r.Item==nil and #r.Connections==0 and h.Counts.NativeLoads==0,'Native bind teardown cannot recreate cleared callbacks or IO')
    else check(item.SelectedSource=='first.webm'and r.Phase=='deferred'and not r.SourceInvalidated and r.BoundGeneration==r.Generation and h.Counts.NativeLoads==0,'Reentrant new source remains sole current bound generation')end
    h.Options.PositionHook=nil;h.Options.VideoBindHook=nil;h.Destroy()
   end;mark(backend..' native binding reentry guards')
  end
 end
 do
  local markup=html('preload=auto')..'<script>window.order=[];queueMicrotask(()=>order.push("author micro"));document.getElementById("s1").addEventListener("error",()=>{order.push("source error");queueMicrotask(()=>order.push("listener micro"));var x=document.createElement("source");x.id="beforegap";x.src="first.webm";m.insertBefore(x,document.getElementById("s2"));});</script>'
  local h=fixture({HTML=markup,Modern=true,Scripting=true});local chosenAtError;h.Page.Events:On(h.Node.Children[1],'error',function()chosenAtError=h.Item.SelectedSource end);h.Drain();h.Run('window.sequence=JSON.stringify(order)')
  check(h.Realm.Window.Get('sequence')=='["author micro","source error","listener micro"]','Actual Realm task/microtask SOURCE order')
  check(chosenAtError=='second.webm'and h.Item.SelectedSource=='second.webm'and table.concat(h.Counts.Requests or{},',')=='rbxassetid://201'and h.Item.VideoSelection.Gap==3,'Stable retry precedes SOURCE error listener; inserted earlier source does not replace selected gap candidate')
  h.Destroy();mark('actual Realm stable selection before SOURCE error task')
 end
 do
  local h=fixture({HTML=html('preload=none'),Scripting=true});h.Drain();local r=h.Item.VideoSelection
  h.Run('window.rejected=[];for(const child of [document.createElement("div"),document.createElementNS("urn:foreign","source")]){try{m.appendChild(child);rejected.push(false)}catch(e){rejected.push(true)}}window.rejects=JSON.stringify(rejected);var pref=document.createElementNS("http://www.w3.org/1999/xhtml","h:source");pref.id="pref";pref.src="first.webm";m.insertBefore(pref,document.getElementById("s2"));document.getElementById("s1").remove()')
  check(h.Realm.Window.Get('rejects')=='[false,false]'and #h.Node.Children==4 and r.Gap==0,'Namespace and unsupported-child preflight preserve old rejection and accept expanded HTML SOURCE')
  h.Page:PlayMedia('v');h.Drain();check(h.Item.SelectedSource=='first.webm'and h.Counts.NativeLoads==1,'Shared source selector accepts qualified HTML SOURCE');h.Retained();h.Destroy();mark('HTML-expanded SOURCE vs foreign/unsupported child preflight')
 end
 do
  local h=fixture({HTML=html('preload=none'),Scripting=false});h.Drain();local r=h.Item.VideoSelection;local old=h.Node.Children[1];local added=Node.element('source',{src='first.webm',id='new'})
  h.Page.Media:VideoBeforeInsert(h.Node,1,1);Node.insertBefore(h.Node,added,h.Node.Children[2]);h.Page.Media:VideoMutation({Type='childList',Target=h.Node,AddedNodes={added},RemovedNodes={}})
  h.Page.Media:VideoBeforeRemove(old);Node.removeChild(h.Node,old);h.Page.Media:VideoMutation({Type='childList',Target=h.Node,AddedNodes={},RemovedNodes={old}})
  check(r.Gap==0 and h.Counts.NativeLoads==0 and h.Realm==nil,'NoRealm manual owner hooks keep deferred pointer with no implicit VM');h.Page:PlayMedia('v');h.Drain()
  check(h.Item.SelectedSource=='first.webm'and h.Counts.NativeLoads==1,'NoRealm manual gap resumes real retained backend');h.Retained();h.Destroy();mark('noRealm explicit owner live-gap hooks')
 end
 do
  local markup='<style>video:empty{background-color:#123456}video:has(source){background-color:#654321}</style><video id=v controls preload=none></video><script>var m=document.getElementById("v")</script>'
  local h=fixture({HTML=markup,Scripting=true});h.Drain();local item=h.Item;local gui=item.Gui;check(item.Style.Background==Color3.fromRGB(18,52,86),'Actual empty selector before inert SOURCE insertion')
  h.Run('var s=document.createElement("source");s.src="first.webm";m.appendChild(s)');check(item.Style.Background==Color3.fromRGB(101,67,33)and item.Gui==gui and h.Tree.MediaByNode[h.Node]==item,'MediaData SOURCE insertion recascades has selector without rebuilding GUI')
  h.Run('s.remove()');check(item.Style.Background==Color3.fromRGB(18,52,86)and item.Gui==gui,'MediaData removal preserves empty semantics and retained GUI');h.Destroy();mark('actual has/empty selector retention')
 end
 do
  local h=fixture({HTML=html('preload=auto','first.webm'),Scripting=true});h.Drain();local item=h.Item;h.Page:PlayMedia('v');local calls=0;local resolve=h.Page.ResolveVideo
  h.Page.ResolveVideo=function(raw)calls+=1;return resolve(raw)end;local native=h.Native();local requests=h.Counts.NativeLoads;local raster=h.Counts.SVGJobs
  h.Run('m.style.color="red"');for _=1,4 do h.Run('document.getElementById("neighbor").textContent="ordinary status"');h.Page.Media:VideoMutation({Type='childList',Target=Node.findById(h.Page.Document,'neighbor'),AddedNodes={},RemovedNodes={}});h.Page.Media:State('v');h.Page:PauseMedia('v');h.Page:PlayMedia('v');h.Drain()end
  check(calls==0 and h.Counts.NativeLoads==requests and h.Counts.SVGJobs==raster and h.Native()==native and item.Playing,'Unrelated style/status/state/play reads cause no source resolver scan/reload/raster/native replacement');h.Destroy();mark('unrelated writes and current media updates are idle-free')
 end
 for _,kind in {'nil','false','table'}do
  local token=if kind=='table'then {}elseif kind=='false'then false else nil
  local h=fixture({HTML=html('preload=auto','first.webm'),Scripting=false});local native=h.Native();h.Page.ResolveVideo=function()h.Page:Destroy();error(token,0)end
  local caught=false
  for _=1,20 do if #h.Jobs==0 then break end;local job=table.remove(h.Jobs,1);if not job.Cancelled then local thread=coroutine.create(job.Callback);local ok,value=coroutine.resume(thread);if not ok then check(value==token,'Private source wake preserves original '..kind..' payload after reentrant page teardown');caught=true;break end end end
  check(caught and not h.Page.Alive and native.DestroyCalls==1 and h.Counts.NativeLoads==0 and h.Item.VideoSelection==nil,'Resolver '..kind..' disposal prevents native IO and clears record/backend once');h.Destroy();mark('noRealm reentrant resolver disposal '..kind)
 end
 for _,kind in {'page','owner'}do
  local h=fixture({HTML=html('preload=none'),Scripting=false});h.Drain();local calls=0;local item=h.Item;local r=item.VideoSelection;local native=h.Native()
  h.Page.ResolveVideo=function()calls+=1;if kind=='page'then h.Page:Destroy()else h.Page.Media:Destroy()end;return nil end
  h.Page:PlayMedia('v');h.Drain();check(calls==1 and h.Counts.NativeLoads==0 and native.DestroyCalls==1 and item.VideoSelection==nil and r.Item==nil,'CanLoad '..kind..' destruction after raw resolver stops stale URL resolver and IO');h.Destroy()
  mark('noRealm CanLoad resolver nil then '..kind..' destruction')
 end
 do
  local h=fixture({HTML=html('preload=none'),Scripting=true});local ev=events(h);h.Drain();local item=h.Item;local r=item.VideoSelection;local old=r.SelectionEpoch;local original=h.Page.ResolveVideo;local calls={};local reentered=false
  h.Page.ResolveVideo=function(raw)table.insert(calls,raw);if not reentered then reentered=true;h.Direct('m.src="second.webm";m.preload="auto"');return nil end;return original(raw)end
  h.Page:PlayMedia('v');check(#calls==1 and calls[1]=='missing.media'and r.SelectionEpoch==old+1 and h.Counts.NativeLoads==0,'CanLoad same-script source commit invalidates attempt before stale URL resolver or IO');h.Page:FlushScriptLayout();h.Drain()
  check(table.concat(calls,',')=='missing.media,second.webm'and item.SelectedSource=='second.webm'and h.Counts.NativeLoads==1 and #ev.Source==0 and #ev.Media==0,'New direct source epoch survives resolver reentry and owns sole backend load without stale child URL mapping');h.Retained();h.Destroy();mark('Realm CanLoad resolver nil then new source epoch')
 end
 do
  local h=fixture({HTML=html('preload=none','first.webm'),Scripting=false});h.Drain();local tick,armed=0,true
  local work=reference.new(4,{Task={wait=function()armed=false;table.insert(h.Waiting,coroutine.running());coroutine.yield()end},Clock=function()if armed then tick+=.005 end;return tick end,Alive=function()return h.Page.Alive end});h.Page.LoadingWork=work
  h.Page:LoadVideo('v');h.Drain();check(work.Yields==0 and work.Running==1 and #h.Waiting==1,'Actual Work4 source worker suspended inside cooperative checkpoint')
  local item=h.Item;local r=item.VideoSelection;h.Page.Media:Destroy();check(h.Page.Alive and item.VideoSelection==nil and r.Item==nil and h.Counts.NativeLoads==0,'Owner-only destruction clears private queues while page stays alive')
  h.Resume();check(work.Running==0 and work.Yields==1 and h.Counts.NativeLoads==0,'Resumed Work4 checkpoint does not dereference a cleared queue or publish source');work:Finish();h.Destroy();mark('noRealm Work4 owner-only destroy after checkpoint')
 end
 do
  local list={};for i=1,1050 do table.insert(list,'<source id=s'..i..' src=missing.media>')end;table.insert(list,'<source id=chosen src=second.webm>')
  local h=fixture({HTML='<video id=v controls preload=auto>'..table.concat(list)..'</video>',Scripting=false,DrainBudget=2400});local ev=events(h);h.Drain();local r=h.Item.VideoSelection
  check(#ev.Source==1050 and #ev.Media==0 and ev.Source[1]=='s1'and ev.Source[1050]=='s1050','Over-1024 SOURCE error tasks retain every candidate on the same selection epoch')
  for i=1,1050 do check(ev.Source[i]=='s'..i,'O(1) queue preserves exact SOURCE error order '..i)end
  check(r.Gap==1051 and r.SelectionEpoch==1 and h.Item.SelectedSource=='second.webm'and h.Counts.NativeLoads==1,'Large legal child list chooses final valid source once without arbitrary queue cap');h.Destroy();mark('noRealm over-1024 ordered SOURCE tasks')
 end
 check(completed==#expected,'Exact control inventory');for _,name in expected do check(seen[name],'Missing control '..name)end
 print('VIDEO_LIVE_SUMMARY','controls='..completed,'assertions='..checks)
end
