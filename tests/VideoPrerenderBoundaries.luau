--!strict
-- Actual HTMLPage startup, Controller and HTMLScripts; deterministic native
-- metadata/resource completion is distinct from Chrome and Studio pixels.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,reference,Selection,loadHTMLScriptsCaptured)
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
  return {Page=page,Tree=tree,Item=item,Node=node,Realm=realm,Run=script,Direct=direct,Drain=drain,Resume=resume,Retained=retained,Geometry=geometry,Dimensions=dimensions,Destroy=destroy,Counts=counts,Waiting=waiting,Jobs=jobs,SVG=svgs,Native=function()return item.VideoPlayer or item.VideoGui end,Input=input,SetHits=function(value)hits=value end,Options=options,Focused=function()return focused end,Focus=focus,Instances=natives,Created=created}
 end






 local completed,seen=0,{}
 local expected={
  'VideoPlayer zero acquire owner stop','VideoFrame zero acquire owner stop','VideoPlayer zero acquire page destroy','VideoFrame zero acquire page destroy','VideoPlayer zero acquire new commit','VideoFrame zero acquire new commit',
  'publication renderer nil','publication renderer false','publication renderer table','publication double error nil','publication double error false','publication double error table','publication multi close nil','publication multi close false','publication multi close table',
  'publication newer lease survives','scan original nil','scan original false','scan original table','scan Work4 owner stop','scan Work4 new commit',
 }
 local function mark(name)check(table.find(expected,name)~=nil and not seen[name],'Exact boundary control '..name);seen[name]=true;completed+=1;print('PRERENDER_BOUNDARY',name)end
 local function warm(capture)
  local h=fixture({Capture=capture,Modern=true});h.Drain();return h
 end
 for _,modern in {true,false}do
  local backend=if modern then'VideoPlayer'else'VideoFrame'
  for _,mode in {'owner stop','page destroy','new commit'}do
   local h=fixture({Modern=modern,HTML='<div id=slot></div><input id=editor><p id=neighbor>retained</p><script>var m=null,e=document.getElementById("editor");</script>'});h.Drain();local facade=h.Page.Media;local callbackMedia,entered,innerEpoch,r=false,false,nil,nil;local nativeBefore=#h.Instances;local original=h.Realm.ResourcesChanged
   h.Realm.ResourcesChanged=function(runtime)
    local node=Node.findById(h.Page.Document,'fresh');local item=node and h.Tree.MediaByNode[node]
    if not entered and item and item.VideoSelection then
     entered=true;callbackMedia=h.Page.Media;r=item.VideoSelection
     check(type(callbackMedia.Destroy)=='function'and type(h.Page.LoadVideo)=='function'and callbackMedia:GetPendingDocumentResources()==1,'Full owner/API is published before atomic one-to-one transfer notification')
     if mode=='owner stop'then callbackMedia:Destroy()
     elseif mode=='page destroy'then h.Page:Destroy()
     else h.Realm.VM:Install(function()h.Realm.VM.Set(h.Realm.DOM.Wrap(node),'src','second.webm')end);h.Page:LoadVideo('fresh');innerEpoch=r.SelectionEpoch end
    end
    return original(runtime)
   end
   h.Direct('var f=document.createElement("video");f.id="fresh";f.controls=true;f.src="first.webm";document.getElementById("slot").appendChild(f)');h.Drain()
   check(entered,'Actual first VIDEO facade upgrade reached transfer callback')
   if mode=='new commit'then check(r.SelectionEpoch>=innerEpoch and #h.Instances==nativeBefore and h.Counts.NativeLoads==1 and h.Counts.Requests[1]=='rbxassetid://201','Only new commit survives outer initializer and no obsolete modern backend is constructed')
   else check(h.Page.Media==callbackMedia and h.Page.Media~=facade and h.Page.Media:GetPendingDocumentResources()==0 and #h.Instances==nativeBefore and h.Counts.NativeLoads==0,'Stopped/disposed upgrade cannot copy or republish an old facade after acquisition');check(r.Item==nil,'Stopped source lease retires exact Item')end
   h.Realm.ResourcesChanged=original;h.Destroy();mark(backend..' zero acquire '..mode)
  end
 end
 for _,mode in {'renderer','double error','multi close'}do
  for _,kind in {'nil','false','table'}do
   local payload=if kind=='nil'then nil elseif kind=='false'then false else {Original='publication primary'}
   local capture={};local h=warm(capture)
   h.Direct('var a=document.createElement("video"),b=document.createElement("video");a.id="fresh";b.id="fresh2";a.src=b.src="first.webm";a.style.display=b.style.display="none";document.body.append(a,b)')
   check(h.Page.Media:GetPendingDocumentResources()==2,'Two exact provisional owners before publication cleanup')
   local changes=h.Realm.Pending;h.Realm.Pending={};local apply=h.Tree.ApplyDOMChanges;local resource=h.Realm.ResourcesChanged
   if mode~='multi close'then h.Tree.ApplyDOMChanges=function()error(payload,0)end end
   if mode=='double error'then h.Realm.ResourcesChanged=function()error({Closing='secondary must not mask original'},0)end
   elseif mode=='multi close'then h.Realm.ResourcesChanged=function()error(payload,0)end end
   local ok,value=pcall(capture.Apply,changes)
   check(not ok and value==payload,'Actual HTMLScripts publication preserves exact '..mode..' '..kind..' first payload')
   check(h.Page.Media:GetPendingDocumentResources()==0,'Throwing first close notification cannot strand another provisional owner')
   h.Tree.ApplyDOMChanges=apply;h.Realm.ResourcesChanged=resource;h.Destroy();mark('publication '..mode..' '..kind)
  end
 end
 do
  local capture={};local h=warm(capture)
  h.Direct('var f=document.createElement("video");f.id="fresh";f.src="first.webm";f.style.display="none";document.body.appendChild(f)')
  local changes=h.Realm.Pending;h.Realm.Pending={};local apply=h.Tree.ApplyDOMChanges;local entered=false
  h.Tree.ApplyDOMChanges=function(tree,content)
   if not entered then entered=true;h.Direct('document.getElementById("fresh").src="second.webm"')end
   return apply(tree,content)
  end
  capture.Apply(changes);check(entered and h.Page.Media:GetPendingDocumentResources()==1,'Older publication token cannot erase a newer successful src commit lease')
  h.Tree.ApplyDOMChanges=apply;h.Page:FlushScriptLayout();h.Drain();check(h.Page.Media:GetPendingDocumentResources()==0 and h.Counts.NativeLoads==0,'Newest declined publication settles its own lease once without native IO');h.Destroy();mark('publication newer lease survives')
 end
 local function capturedMutation()
  local h=warm();local media=h.Page.Media;local mutation=media.VideoMutation;local record
  media.VideoMutation=function(_,change)if change.Type=='childList'and change.Target.Attributes and change.Target.Attributes.id=='slot'then record=change end end
  h.Direct('var w=document.createElement("div");w.id="wrap";var f=document.createElement("video");f.id="fresh";f.controls=true;f.src="first.webm";w.appendChild(f);var s=document.createElement("div");s.id="slot";document.body.appendChild(s);s.appendChild(w)')
  media.VideoMutation=mutation;check(record~=nil and h.Page.Media:GetPendingDocumentResources()==0,'Actual committed VM child-list record captured before one scanner delivery')
  return h,media,mutation,record
 end
 for _,kind in {'nil','false','table'}do
  local payload=if kind=='nil'then nil elseif kind=='false'then false else {Original='scan checkpoint'}
  local h,media,mutation,record=capturedMutation();local resource=h.Realm.ResourcesChanged;local called=0
  h.Realm.ResourcesChanged=function(runtime)called+=1;if called==2 then error({Closing='scan close'},0)end;return resource(runtime)end
  local ok,value=pcall(function()reference.with(function()error(payload,0)end,mutation,media,record)end)
  check(not ok and value==payload and called==2 and media:GetPendingDocumentResources()==0,'Balanced scan preserves exact first '..kind..' checkpoint error even when close throws')
  h.Realm.ResourcesChanged=resource;h.Destroy();mark('scan original '..kind)
 end
 for _,mode in {'owner stop','new commit'}do
  local h,media,mutation,record=capturedMutation();local held={};local armed,tick=true,0
  local work=reference.new(4,{Task={wait=function()armed=false;table.insert(held,coroutine.running());coroutine.yield('actual scan Work4')end},Clock=function()if armed then tick+=.005 end;return tick end,Alive=function()return h.Page.Alive end})
  local thread=coroutine.create(function()work:Run(mutation,media,record)end);local ok,value=coroutine.resume(thread);check(ok,tostring(value))
  check(#held==1 and work.Running==1 and media:GetPendingDocumentResources()==1,'Unknown edited subtree holds one scan lease before cooperative discovery')
  if mode=='owner stop'then media:Destroy();check(media:GetPendingDocumentResources()==0,'Stopped owner cancels held scan lease before resume')
  else h.Direct('document.getElementById("fresh").src="second.webm"');check(media:GetPendingDocumentResources()==2,'Reentrant source has separate node lease while scan remains active')end
  ok,value=coroutine.resume(table.remove(held,1));check(ok,tostring(value));check(work.Running==0,'Scan cooperative frame balanced')
  if mode=='owner stop'then check(media:GetPendingDocumentResources()==0,'Old scan cannot revive stopped node reservations')
  else check(media:GetPendingDocumentResources()==1,'Scan completion removes only scan lease and retains new node source')end
  h.Page:FlushScriptLayout();h.Drain()
  if mode=='owner stop'then check(h.Counts.NativeLoads==0,'Stopped scan publication cannot allocate native IO')else check(h.Counts.NativeLoads==1 and h.Counts.Requests[1]=='rbxassetid://201'and media:GetPendingDocumentResources()==0,'Only reentrant current source reaches native IO and clears its own delay flag')end
  work:Finish();h.Destroy();mark('scan Work4 '..mode)
 end
 check(completed==21 and #expected==21,'Exact boundary case inventory');for _,name in expected do check(seen[name],'Missing boundary '..name)end
 print('PRERENDER_BOUNDARY_SUMMARY','cases='..completed,'assertions='..checks)
end
