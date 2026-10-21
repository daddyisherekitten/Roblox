--!strict
-- Actual HTMLPage startup, Controller and HTMLScripts; deterministic native
-- metadata/resource completion is distinct from Chrome and Studio pixels.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference,Selection,loadHTMLScriptsCaptured,onlyCase)
 local checks,states,nativeStates=0,0,0
 local function check(value,label)checks+=1;assert(value,label)end
 local function near(actual,expected,label)check(math.abs(actual-expected)<.03,label..': '..actual..' != '..expected)end
 local function signal()
  local entries={};local s={}
  function s:Connect(fn)local c={Connected=true,Callback=fn};function c:Disconnect()self.DisconnectCalls=(self.DisconnectCalls or 0)+1;self.Connected=false end;table.insert(entries,c);return c end
  function s:Fire(...)for _,c in table.clone(entries)do if c.Connected then c.Callback(...)end end end
  function s:Count()local n=0;for _,c in entries do if c.Connected then n+=1 end end;return n end
  function s:Snapshot()local n={};for _,c in entries do if c.Connected then table.insert(n,c.Callback)end end;return n end
  return s
 end
 local faces={};local overrides={['Layout/FontProfiles']={face=function(f,w,v)local k=tostring(f)..':'..tostring(w)..':'..tostring(v);faces[k]=faces[k]or{Family=f,Weight=w,Style=v};return faces[k]end},['Layout/TextMeasure']={measure=function(t,_,size)return Vector2.new(#t*size/2,size)end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local block=loadBlockLayout(overrides)
 local function fixture(options)
  options=options or{};local jobs,waiting,created,natives,svgs={}, {},{}, {},{};local focused,time,tree,page=nil,0,nil,nil
  local hits={};local counts={PosterLoads=0,PosterCancelled=0,SVGAdded=0,SVGRemoved=0,SVGJobs=0,NativeLoads=0,NativePlay=0,NativePause=0,NativeSoundBind=0,Passes=0,PartialPasses=0}
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
    function object:Pause()self.PauseCalls=(self.PauseCalls or 0)+1;counts.NativePause+=1;self.Playing=false;self.Paused:Fire()end
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
   function o:Pause()self.PauseCalls=(self.PauseCalls or 0)+1;counts.NativePause+=1;self.IsPlaying=false;self.Playing=false;self:GetPropertyChangedSignal('IsPlaying'):Fire();self.Paused:Fire()end
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
    return (if options.Capture then loadHTMLScriptsCaptured(options.Capture)else HTMLScripts).start(...)
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
  return {Page=page,Tree=tree,Item=item,Node=node,Realm=realm,Run=script,Direct=direct,Drain=drain,Resume=resume,Retained=retained,Geometry=geometry,Dimensions=dimensions,Destroy=destroy,Counts=counts,RunService=run,Waiting=waiting,Jobs=jobs,SVG=svgs,Native=function()return item.VideoPlayer or item.VideoGui end,Input=input,SetHits=function(value)hits=value end,Options=options,Focused=function()return focused end,Focus=focus,Instances=natives,Created=created}
 end






 local completed,seen=0,{}
 local expected={
  'VideoPlayer acquire retained','VideoFrame acquire retained','VideoPlayer acquire current','VideoFrame acquire current',
  'VideoPlayer acquire retained nested current','VideoFrame acquire retained nested current','VideoPlayer acquire current nested retained','VideoFrame acquire current nested retained',
  'VideoPlayer warm current nested current','VideoFrame warm current nested current','VideoPlayer warm retained nested current','VideoFrame warm retained nested current','VideoPlayer warm current nested retained','VideoFrame warm current nested retained',
  'VideoPlayer remove nested current','VideoFrame remove nested current',
  'VideoPlayer close current nil','VideoFrame close current nil','VideoPlayer close current false','VideoFrame close current false','VideoPlayer close current table','VideoFrame close current table',
  'VideoPlayer close retained nil','VideoFrame close retained nil','VideoPlayer close retained false','VideoFrame close retained false','VideoPlayer close retained table','VideoFrame close retained table',
 }
 local function mark(name)check(table.find(expected,name)~=nil and not seen[name],'Exact receiver case '..name);seen[name]=true;completed+=1;print('PRERENDER_OWNER_RECEIVER',name)end
 local function selected(name)return onlyCase==nil or onlyCase=='all'or name==onlyCase end
 local html='<div id=slot></div><input id=editor value="A&#x1f600;BC"><p id=neighbor>retained</p><script>var m=null,e=document.getElementById("editor");</script>'
 local insert='var f=document.createElement("video");f.id="fresh";f.controls=true;f.src="first.webm";document.getElementById("slot").appendChild(f)'
 local function focusState(h)
  h.Focus();local control=h.Page.FormModel:Resolve(Node.findById(h.Page.Document,'editor'));local editor=control.Item.Editor;local bindings=editor:Connections();local neighbor=h.Tree.NodeBoxes[Node.findById(h.Page.Document,'neighbor')].Gui
  return function()
   check(control.Item.Editor==editor and h.Focused()==editor and editor:Connections()==bindings and control.Value=='A😀BC'and control.SelectionStart==1 and control.SelectionEnd==3 and control.SelectionDirection=='backward'and editor.CursorPosition==2 and editor.SelectionStart==6,'Owner teardown retains editor/UTF16/input bindings')
   check(h.Tree.NodeBoxes[Node.findById(h.Page.Document,'neighbor')].Gui==neighbor,'Owner teardown retains unrelated neighbor GUI')
  end
 end
 for _,modern in {true,false}do
  local backend=if modern then'VideoPlayer'else'VideoFrame'
  for _,mode in {'retained','current','retained nested current','current nested retained'}do
   local name=backend..' acquire '..mode;if not selected(name)then continue end
   local h=fixture({HTML=html,Modern=modern,DelayVideo=true});h.Drain();local retained=focusState(h)
   local facade=h.Page.Media;local oldDestroy=facade.Destroy;local current,record,item,entered,nested=nil,nil,nil,false,0;local original=h.Realm.ResourcesChanged;local before=#h.Instances
   h.Realm.ResourcesChanged=function(runtime)
    local node=Node.findById(h.Page.Document,'fresh');local found=node and h.Tree.MediaByNode[node]
    if not entered and found and found.VideoSelection then
     entered=true;current=h.Page.Media;record=found.VideoSelection;item=found
     check(current~=facade and current:GetPendingDocumentResources()==1,'Complete current owner exists before first external transfer notification')
     if string.sub(mode,1,8)=='retained'then oldDestroy(facade)else current:Destroy()end
    elseif entered and nested==0 and string.find(mode,'nested',1,true)and record.Item~=nil then
     nested+=1
     if string.sub(mode,1,8)=='retained'then current:Destroy()else oldDestroy(facade)end
    end
    return original(runtime)
   end
   h.Direct(insert);h.Drain()
   check(entered and current~=nil and record.Item==nil and record.Node==nil and item.VideoSelection==nil,'Both receiver paths retire the exact current registration')
   check(h.RunService.Heartbeat:Count()==0,'Stopped acquisition disconnects its media worker once')
   check(current:GetPendingDocumentResources()==0 and facade:GetPendingDocumentResources()==0 and h.Page.Media==current,'Stopped upgrade cannot copy back its old facade or revive a ledger')
   check(#h.Instances==before and h.Counts.NativeLoads==0 and #h.Waiting==0,'No backend or source job is created after acquisition receiver stop')
   check(nested==(if string.find(mode,'nested',1,true)then 1 else 0),'Opposite receiver is exercised exactly at teardown notification')
   local callbacks=0;h.Realm.ResourcesChanged=function()callbacks+=1 end;oldDestroy(facade);current:Destroy();check(callbacks==0,'Repeated receiver Destroy has no second publication')
   h.Realm.ResourcesChanged=original;retained();h.Destroy();mark(name)
  end
  for _,mode in {'current nested current','retained nested current','current nested retained','remove nested current','close current nil','close current false','close current table','close retained nil','close retained false','close retained table'}do
   local name=backend..' '..(if string.sub(mode,1,5)=='close'or string.sub(mode,1,6)=='remove'then mode else'warm '..mode);if not selected(name)then continue end
   local h=fixture({HTML=html,Modern=modern,DelayVideo=true});h.Drain();local retained=focusState(h);local facade=h.Page.Media;local oldDestroy=facade.Destroy
   h.Direct(insert);h.Drain();local current=h.Page.Media;local node=Node.findById(h.Page.Document,'fresh');local item=h.Tree.MediaByNode[node];local record=item.VideoSelection;local player=item.VideoPlayer;local objects=table.clone(item.VideoObjects or{});local frame=item.VideoGui;local framePauses=frame.PauseCalls or 0;local playerPauses=player and(player.PauseCalls or 0)or 0;local connections=table.clone(record.Connections)
   check(current==facade and #h.Waiting==1 and h.Counts.NativeLoads==1 and record.DocumentBlocking,'Normal upgrade retains facade/one held current load')
   local original=h.Realm.ResourcesChanged;local callbacks,nested=0,0;local pause=h.Counts.NativePause;local kind=string.match(mode,'close .+ (%a+)$');local payload=if kind=='nil'then nil elseif kind=='false'then false else{Original='receiver teardown'}
   h.Realm.ResourcesChanged=function(runtime)
    callbacks+=1
    if kind then error(if callbacks==1 then payload else{Secondary='must not replace first receiver error'},0)end
    if nested==0 and record.Item~=nil then
     nested+=1
     if mode=='current nested retained'then oldDestroy(facade)else current:Destroy()end
    end
    return original(runtime)
   end
   local ok,value=pcall(function()
    if mode=='remove nested current'then current:Remove({item})
    elseif string.sub(mode,1,8)=='retained'or string.sub(mode,1,14)=='close retained'then oldDestroy(facade)
    else current:Destroy()end
   end)
   if kind then check(not ok and value==payload,'Destroy preserves exact first '..kind..' callback error after cleanup')else check(ok,tostring(value));check(nested==1,'Warm/Remove reentry reaches actual notification before registration cleanup')end
   check(record.Item==nil and record.Node==nil and item.VideoSelection==nil and not item.Loading and current:GetPendingDocumentResources()==0 and facade:GetPendingDocumentResources()==0,'All receiver/Remove continuations retire current ownership and pending exactly once')
   print('PRERENDER_OWNER_PAUSE',name,'player',if player then player.PauseCalls-playerPauses else 0,'frame',frame.PauseCalls-framePauses)
   check(frame.PauseCalls==framePauses+1 and(not player or player.PauseCalls==playerPauses+1),'Exact per-object native pause counts, not only a combined total')
   check(h.Counts.NativePause==pause+(if player then 2 else 1),'Each retained Player and fallback Frame paused exactly once through nested teardown')
   check(h.RunService.Heartbeat:Count()==0 and #record.Connections==0,'Stopped owner removes frame worker and all registered signal leases')
   for _,connection in connections do check(not connection.Connected and connection.DisconnectCalls==1,'Every current native callback disconnected exactly once')end
   if player then check(player.DestroyCalls==1 and item.VideoPlayer==nil,'Current VideoPlayer destroyed exactly once');for _,object in objects do check(object.DestroyCalls==1,'Each retained native output/wire destroyed once')end
   else check(frame.Video==''and not frame.Playing and frame.Loaded:Count()==0,'Current VideoFrame source and retained signal leases cleared')end
   h.Realm.ResourcesChanged=original;local notified=callbacks;h.Realm.ResourcesChanged=function()callbacks+=1 end;oldDestroy(facade);current:Destroy();check(callbacks==notified,'No repeated teardown notifications from either receiver')
   h.Realm.ResourcesChanged=original;h.Resume();check(h.Counts.NativeLoads==1 and record.Item==nil and current:GetPendingDocumentResources()==0,'Held old native completion cannot resurrect a removed registration or pending flag')
   for _,connection in connections do check(connection.DisconnectCalls==1,'Late completion cannot disconnect a native lease twice')end
   retained();h.Destroy();mark(name)
  end
 end
 if onlyCase==nil or onlyCase=='all'then check(completed==28 and #expected==28,'Exact receiver inventory');for _,name in expected do check(seen[name],'Missing receiver control '..name)end
 else check(completed==1 and seen[onlyCase],'Exact isolated red/green receiver case')end
 print('PRERENDER_OWNER_RECEIVER_SUMMARY','cases='..completed,'assertions='..checks)
end
