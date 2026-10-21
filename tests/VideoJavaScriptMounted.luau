--!strict
-- BUILD-only VIDEO JavaScript controls, exact existing actual HTMLPage fixture.
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
  local html=options.HTML or('<!doctype html><style>body{margin:0}video{display:block}</style><video id="v" muted preload="none" '..(if options.Controls then'controls 'else'')..''..(if options.Poster then 'poster="'..options.Poster..'" 'else '')..'></video><input id="editor" tabindex="-1" value="A&#x1f600;BC"><p id="neighbor">retained neighbor</p>'..scripts)
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



 local expected={
  'VideoPlayer inherited21 mounted receiver','VideoFrame inherited21 mounted receiver',
  'VideoPlayer None pending Play and early default start','VideoFrame None pending Play and early default start',
  'VideoPlayer IDL volume preserves mute','VideoFrame IDL volume preserves mute',
  'VideoPlayer absolute currentTime and fastSeek','VideoFrame absolute currentTime and fastSeek',
  'VideoPlayer force load uses defaultRate','VideoFrame force load uses defaultRate',
  'VideoPlayer currentURL error and range snapshots','VideoFrame currentURL error and range snapshots',
  'VideoPlayer actual UI pause settles script Play','VideoFrame actual UI pause settles script Play',
  'VideoPlayer state persists across actual Remove Add','VideoFrame state persists across actual Remove Add',
  'VideoPlayer default start and endpoint state','VideoFrame default start and endpoint state'
 }
 local seen={};for _,name in expected do check(seen[name]==nil,'Unique literal '..name);seen[name]=false end
 local function mark(name)check(seen[name]==false,'Exact unseen named control '..name);seen[name]=true end
 local function nativeCount(h,class)local n=0;for _,o in h.Instances do if o.ClassName==class then n+=1 end end;return n end
 for _,modern in {true,false}do
  local name=if modern then'VideoPlayer'else'VideoFrame'
  do
   local h=fixture({Modern=modern});h.Drain()
   h.Run([=[window.bindings=JSON.stringify([m.currentSrc,Number.isNaN(m.duration),m.paused,m.ended,m.seeking,m.readyState,m.networkState,m.error===null,m.buffered instanceof TimeRanges,m.seekable instanceof TimeRanges,m.played instanceof TimeRanges,m.muted,m.volume,m.currentTime,m.playbackRate,m.defaultPlaybackRate,typeof m.play,typeof m.pause,typeof m.load,typeof m.fastSeek,typeof m.canPlayType]);]=])
   check(h.Realm.Window.Get('bindings')=='["",true,true,false,false,0,0,true,true,true,true,true,1,0,1,1,"function","function","function","function","function"]','All21 valid VIDEO bindings and canonical defaults')
   check(h.Node.AudioResourceState==nil and h.Node.AudioController==nil and nativeCount(h,'Sound')==0 and h.Counts.NativeLoads==0,'No parallel audio/native backend')
   h.Retained();h.Destroy();mark(name..' inherited21 mounted receiver')
  end
  do
   local h=fixture({Modern=modern,DelayVideo=true});h.Drain()
   h.Direct([=[window.outcome='pending';m.currentTime=5;window.promise=m.play();promise.then(()=>outcome='fulfilled',e=>outcome=e.name);window.waitingPaused=m.paused;var s=document.createElement('source');s.src='first.webm';m.appendChild(s);]=])
   h.Page:FlushScriptLayout();h.Drain()
   check(h.Realm.Window.Get('waitingPaused')==false and h.Realm.Window.Get('outcome')=='pending','Paused false while waiting; real play Promise still pending')
   check(h.Counts.NativeLoads==1 and #h.Waiting==1,'One existing serial native job')
   h.Resume();h.Run('window.start=m.currentTime;window.donePaused=m.paused;')
   check(h.Realm.Window.Get('outcome')=='fulfilled'and h.Realm.Window.Get('donePaused')==false,'Actual native playing fulfills once')
   near(h.Realm.Window.Get('start'),5,'Metadata consumes early default start')
   check(h.Item.VideoSelection~=nil and nativeCount(h,'Sound')==0,'Existing selector, no second owner')
   h.Destroy();mark(name..' None pending Play and early default start')
  end
  do
   local h=fixture({Modern=modern});h.Drain();h.Run('m.muted=false;')
   h.Direct('window.volumeEvents=0;window.rateEvents=0;m.addEventListener("volumechange",()=>volumeEvents++);m.addEventListener("ratechange",()=>rateEvents++);m.muted=true;m.volume=.25;window.preferences=JSON.stringify([m.muted,m.volume]);window.eventsInSetter=volumeEvents;')
   check(h.Realm.Window.Get('eventsInSetter')==0,'Volume events are media tasks, never setter-stack dispatch');h.Drain()
   check(h.Realm.Window.Get('volumeEvents')==2,'Two changed scalar preferences dispatch after tasks')
   h.Direct('m.volume=.25;m.muted=true;m.defaultPlaybackRate=1.5;window.rateInSetter=rateEvents;');check(h.Realm.Window.Get('rateInSetter')==0,'Default rate event is queued');h.Drain()
   check(h.Realm.Window.Get('volumeEvents')==2 and h.Realm.Window.Get('rateEvents')==1,'Unchanged preferences do not duplicate events')
   local nativeLoads,passes=h.Counts.NativeLoads,h.Counts.Passes
   h.Direct('for(let i=0;i<20;i++){void m.currentSrc;void m.currentTime;void m.duration;void m.paused;void m.error;void m.buffered;}')
   check(h.Counts.NativeLoads==nativeLoads and h.Counts.Passes==passes,'Getters do not select/load/rebuild layout')
   check(h.Realm.Window.Get('preferences')=='[true,0.25]'and h.Native().Volume==0,'IDL volume never calls legacy unmuting helper')
   h.Run('m.muted=false;');near(h.Native().Volume,.25,'Unmute restores retained volume')
   h.Run('window.bad="";try{m.volume=2}catch(e){bad=e.name}');check(h.Realm.Window.Get('bad')=='IndexSizeError','No UI volume clamp for invalid IDL value')
   check(h.Counts.NativeLoads==0,'Scalar setters do not initiate resource IO')
   h.Destroy();mark(name..' IDL volume preserves mute')
  end
  do
   local h=fixture({Modern=modern});h.Drain();h.Run('m.src="first.webm";m.play();')
   h.Direct('m.currentTime=3;window.seekingNow=m.seeking;');near(h.Native().TimePosition,3,'Absolute seconds instead of slider ratio')
   check(h.Realm.Window.Get('seekingNow')==true,'Canonical seeking set before queued completion');h.Drain()
   h.Run('window.seekingAfter=m.seeking;m.fastSeek(7);');check(h.Realm.Window.Get('seekingAfter')==false,'Current task owns seek completion')
   near(h.Native().TimePosition,7,'fastSeek exact-host approximation')
   h.Destroy();mark(name..' absolute currentTime and fastSeek')
  end
  do
   local h=fixture({Modern=modern});h.Drain();h.Run('m.defaultPlaybackRate=1.5;m.src="first.webm";m.play();')
   h.Run('m.load();window.rates=JSON.stringify([m.defaultPlaybackRate,m.playbackRate]);')
   check(h.Realm.Window.Get('rates')=='[1.5,1.5]','Load resets rate to default rather than UI1')
   if modern then near(h.Native().PlaybackSpeed,1.5,'Native modern rate')
    h.Run('m.playbackRate=4;window.speed=m.playbackRate;');check(h.Realm.Window.Get('speed')==4 and h.Native().PlaybackSpeed==4,'UI .5..2 interval not applied to IDL')
   else h.Run('window.rateError="";try{m.playbackRate=4}catch(e){rateError=e.name}');check(h.Realm.Window.Get('rateError')=='NotSupportedError','Fallback speed capability explicitly unavailable')end
   h.Destroy();mark(name..' force load uses defaultRate')
  end
  do
   local h=fixture({Modern=modern});h.Drain();h.Run('m.src="first.webm";m.play();');h.Run('window.url=m.currentSrc;window.rangesFresh=m.buffered!==m.buffered;')
   check(h.Realm.Window.Get('url')=='https://video.test/root/first.webm'and h.Item.SelectedSource=='first.webm','currentSrc selected URL differs from SourceRaw')
   check(h.Realm.Window.Get('rangesFresh')==true,'Fresh range snapshots; empty capability is separately bounded')
   local calls=h.Counts.NativeLoads;h.Run('m.src="";');h.Run('window.firstError=m.error;window.sameError=m.error===firstError;window.code=m.error.code;')
   check(h.Realm.Window.Get('sameError')==true and h.Realm.Window.Get('code')==4 and h.Counts.NativeLoads==calls,'Terminal error identity; invalid direct source no child retry/IO')
   h.Destroy();mark(name..' currentURL error and range snapshots')
  end
  do
   local h=fixture({Modern=modern,DelayVideo=true,Controls=true});h.Drain();h.Run('m.src="first.webm";window.outcome="pending";m.play().then(()=>outcome="fulfilled",e=>outcome=e.name);')
   check(#h.Waiting==1 and h.Realm.Window.Get('outcome')=='pending','Script Play remains pending on held native load')
   check(h.Page.Media:Key(h.Item,'Space'),'Actual UI toggle pauses the same canonical request');h.Drain()
   check(h.Realm.Window.Get('outcome')=='AbortError','UI pause settles script token once')
   h.Resume();h.Run('window.afterPause=m.paused;');check(h.Realm.Window.Get('afterPause')==true and h.Counts.NativePlay==0,'Late metadata does not restart paused play')
   h.Destroy();mark(name..' actual UI pause settles script Play')
  end
  do
   local h=fixture({Modern=modern});h.Drain();h.Run('m.volume=.25;m.muted=true;m.defaultPlaybackRate=1.5;')
   local state=h.Node.VideoResourceState;h.Page.Media:Remove({h.Item})
   check(state.Backend==nil,'Registration lease released before native teardown')
   h.Run('window.kept=JSON.stringify([m.volume,m.muted,m.defaultPlaybackRate]);')
   check(h.Realm.Window.Get('kept')=='[0.25,true,1.5]'and h.Node.VideoResourceState==state,'Node state survives lease removal')
   local originalChanged=h.Page.DocumentResourcesChanged;local armed=true
   h.Page.DocumentResourcesChanged=function(self)
    if armed then armed=false;local ok,message=h.Realm:Run('m.volume=.4;m.volume=.25;window.acquired=m.volume;');check(ok,'Valid canonical setter during acquisition: '..tostring(message))end
    if originalChanged then originalChanged(self)end
   end
   h.Page.Media:Add({h.Item});h.Page.DocumentResourcesChanged=originalChanged
   check(not armed and h.Realm.Window.Get('acquired')==.25,'Acquisition callback sees node state before native allocation')
   h.Drain();h.Run('window.keptAgain=JSON.stringify([m.volume,m.muted,m.defaultPlaybackRate]);')
   check(h.Realm.Window.Get('keptAgain')=='[0.25,true,1.5]'and h.Node.VideoResourceState==state,'Same node state restored on a new live lease')
   h.Destroy();mark(name..' state persists across actual Remove Add')
  end
  do
   for _,start in {-5,0,25}do
    local h=fixture({Modern=modern,DelayVideo=true});h.Drain()
    h.Direct('m.currentTime='..start..';window.early=m.currentTime;m.preload="auto";m.src="first.webm";')
    check(h.Realm.Window.Get('early')==start,'HAVE_NOTHING stores finite signed default start without UI clamp')
    h.Page:FlushScriptLayout();h.Drain();check(#h.Waiting==1,'Exactly one held metadata job')
    h.Resume();h.Run('window.position=m.currentTime;window.atEnd=m.ended;')
    local expected=math.clamp(start,0,12)
    near(h.Realm.Window.Get('position'),expected,'Metadata clears default start for negative/zero/positive')
    check(h.Node.VideoResourceState.DefaultStart==0,'Default start field is cleared even when no positive seek occurs')
    check(h.Realm.Window.Get('atEnd')==(start>12),'Endpoint after metadata is canonical; positive start consumes/clamps to resource end')
    if start==0 then
     h.Direct('m.currentTime=-5;window.negative=m.currentTime;');near(h.Realm.Window.Get('negative'),0,'Loaded negative seek uses earliest position, not UI ratio');h.Drain()
     h.Direct('m.currentTime=25;window.beforeEndpoint=m.ended;');check(h.Realm.Window.Get('beforeEndpoint')==false,'Ended is not fabricated on setter stack')
     near(h.Native().TimePosition,12,'Loaded endpoint seek uses duration, not UI seek interval');h.Drain()
     h.Run('window.afterEndpoint=m.ended;m.currentTime=0;');check(h.Realm.Window.Get('afterEndpoint')==true,'Endpoint seek publishes ended after completion')
     h.Run('window.afterReset=m.ended;');check(h.Realm.Window.Get('afterReset')==false,'Seek away from end clears ended')
    end
    check(h.Counts.NativeLoads==1,'Position getters and seeks never select a second resource')
    h.Destroy()
   end
   mark(name..' default start and endpoint state')
  end
 end
 for _,label in expected do check(seen[label]==true,'No missing control '..label)end
 print('VideoJavaScriptMounted',#expected,'controls',checks,'assertions')
end
