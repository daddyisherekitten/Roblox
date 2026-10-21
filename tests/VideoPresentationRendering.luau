--!strict
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
  local counts={PosterLoads=0,PosterCancelled=0,SVGAdded=0,SVGRemoved=0,SVGJobs=0,NativeLoads=0,NativePlay=0,NativeSoundBind=0,Passes=0,PartialPasses=0}
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
   function o:LoadAsync()counts.NativeLoads+=1;if options.DelayVideo then table.insert(waiting,coroutine.running());coroutine.yield()end;self.IsLoaded=true;self.Resolution=Vector2.new(80,40);self:GetPropertyChangedSignal('IsLoaded'):Fire()end
   function o:Play()counts.NativePlay+=1;self.IsPlaying=true;self.Playing=true;self:GetPropertyChangedSignal('IsPlaying'):Fire();self.Played:Fire()end
   function o:Pause()self.IsPlaying=false;self.Playing=false;self:GetPropertyChangedSignal('IsPlaying'):Fire();self.Paused:Fire()end
   function o:Stop()self:Pause();self.TimePosition=0 end
   function o:Unload()self.IsLoaded=false end
   function o:Destroy()self.DestroyCalls+=1;self.Parent=nil end
   if class=='Sound'then
    local soundId='';setmetatable(o,{__index=function(_,k)if k=='SoundId'then return soundId end end,__newindex=function(self,k,v)if k=='SoundId'then soundId=v;counts.NativeSoundBind+=1 else rawset(self,k,v)end end})
   end
   if class=='Frame'then o.AbsoluteSize=Vector2.new(960,540)end
   table.insert(natives,o);return o
  end}
  local provider={PreloadAsync=function(_,list)
   local object=list[1]
   if object and object.ClassName=='ImageLabel'and object.Image then
    counts.PosterLoads+=1;if options.DelayPoster then table.insert(waiting,coroutine.running());coroutine.yield()end
   elseif object and(object.ClassName=='VideoFrame'or object.ClassName=='Sound')then
    counts.NativeLoads+=1;if object.ClassName=='VideoFrame'and options.DelayVideo then table.insert(waiting,coroutine.running());coroutine.yield()end;object.IsLoaded=true
    if object.ClassName=='VideoFrame'then object.Resolution=Vector2.new(80,40);object.Loaded:Fire()else object.Loaded:Fire()end
   end
  end}
  local resources={Task=tasks,ContentProvider=provider,AssetFetchSuccess='Success',CreateImageLabel=function()return factory.create('ImageLabel',nil,{})end,AssetService={CreateEditableImageAsync=function(_,content)
   local raw=tostring(content);local w,h=if raw:find('102',1,true)then 120 else 200,if raw:find('102',1,true)then 240 else 100
   if raw:find('109',1,true)then error('Intentional poster decode failure')end
   return {Size=Vector2.new(w,h),Destroy=function()end}
  end}}
  local services={Task=tasks,RunService=run,ContentProvider=provider,Instance=instance,Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Content={none='content:none',fromUri=function(s)return s end},Factory=factory,Clock=function()return time end,PickerLayout=block}
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
  local mountOptions={JavaScript=options.Scripting~=false,RenderWorkBudgetMS=0,DocumentURL='https://video.test/root/index.html',Images={['wide.png']='101',['tall.png']='102',['bad.png']='109'},SVGs={['wide.svg']='<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100"/></svg>'},Videos={['one.webm']='201',['two.webm']='202'},Audio={['second.mp3']='301'},JavaScriptServices={Task=tasks,Clock=function()return time end,RunService=run,ResourceServices=resources,AudioServices={Task=tasks,Instance=instance,RunService=run,ContentProvider=provider}}}
  if options.StylesheetOnly then mountOptions.JavaScriptServices.LoadStylesheet=function()return ''end end
  page=module.mount(factory.create('Frame',factory.create('ScreenGui',nil,{}),{}),html,mountOptions)
  local realm=page.JavaScriptRuntime;local node=Node.findById(page.Document,'v');local item=node and tree.MediaByNode[node]
  local gui,box,frame,display=if item then item.Gui else nil,if item then item.BoxGui else nil,if item then item.VideoGui else nil,if item then item.VideoDisplay else nil
  local function drain()for _=1,160 do if #jobs==0 then return end;local job=table.remove(jobs,1);if not job.Cancelled then time=math.max(time,job.Due);local thread=coroutine.create(job.Callback);local ok,message=coroutine.resume(thread);check(ok,tostring(message))end end;error('Presentation queue did not converge')end
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
  return {Page=page,Tree=tree,Item=item,Node=node,Realm=realm,Run=script,Direct=direct,Drain=drain,Resume=resume,Retained=retained,Geometry=geometry,Dimensions=dimensions,Destroy=destroy,Counts=counts,Waiting=waiting,Jobs=jobs,SVG=svgs,Native=function()return item.VideoPlayer or item.VideoGui end,Options=options,Focused=function()return focused end,Focus=focus,Instances=natives,Created=created}
 end
 -- Literal inventories keep each native geometry/control case independently
 -- auditable; generic DOM/media JS beyond these presentation actions is open.
 local geometryNames={'initial','wide poster','tall poster','remove poster','empty poster','width only no intrinsic','height both no intrinsic','height only no intrinsic','remove dimensions','wide poster restored','width only poster ratio','height only poster ratio','CSS width authority','CSS both authority','change poster CSS fixed','clear CSS','missing poster with dims','clear dims again'}
 check(#reference.raw.basic.geometry==#geometryNames,'Exact native geometry inventory')
 for _,modern in {true,false}do
  local h=fixture({Modern=modern});h.Drain()
  for i,c in reference.raw.basic.geometry do check(c.name==geometryNames[i],'Named native geometry '..i);if c.action~=''then h.Run(c.action)end;h.Geometry(c.value,c.name,true);h.Dimensions(0,0,'Poster is not VIDEO metadata')end
  h.Destroy()
 end
 local cascadeNames={'width-only hint','CSS auto removes width hint','CSS initial removes width hint','CSS revert removes width hint','CSS authored width beats hint','both dims ratio fallback','CSS dimension ratio wins','CSS auto ratio removes fallback','width percent no intrinsic','both dimensions decimal fallback','zero denominator','zero numerator','both zero','zero width CSS auto'}
 local rawValues={'','0','23px','3.7','+23','23%','0x10',' 23',' 23','23oops','80.5','-2'}
 check(#reference.raw.dimensions.rawDimensions==24 and #reference.raw.dimensions.cascade==14,'Exact raw dimension/cascade inventory')
 for _,modern in {true,false}do
  local h=fixture({Modern=modern});h.Drain();h.Focus()
  for i,c in reference.raw.dimensions.rawDimensions do
   check(c.key==(if i<=12 then 'width'else 'height')and c.raw==rawValues[(i-1)%12+1],'Named raw dimension case '..i)
   h.Run('v.removeAttribute("width");v.removeAttribute("height");v.setAttribute('..string.format('%q',c.key)..','..string.format('%q',c.raw)..')');h.Geometry(c.value,c.name,true)
  end
  h.Run('v.removeAttribute("width");v.removeAttribute("height");v.removeAttribute("style")')
  for i,c in reference.raw.dimensions.cascade do check(c.name==cascadeNames[i],'Named cascade state '..i);h.Run(c.action);h.Geometry(c.value,c.name,true)end
  check(h.Counts.NativeLoads==0 and h.Counts.NativePlay==0,'Presentation attrs/CSS never load or play media');h.Destroy()
 end
 local intrinsicNames={'missing initial','poster wide no source','poster tall no source','metadata with poster','seek before first play','explicit load resets poster flag','actual play hides poster','pause keeps video frame','change poster after playback','remove poster after playback','same source reset metadata','restore poster after source reset','poster remove retains video intrinsic','width only video ratio','height only video ratio','CSS width with height attr','CSS fixed both','source removal retains dimensions','empty source resets dimensions','clear all missing default'}
 check(#reference.raw.deep.intrinsics==20,'Exact native intrinsic inventory')
 for _,modern in {true,false}do
  local h=fixture({Modern=modern});h.Drain();h.Focus();h.Run('v.controls=true')
  for i,c in reference.raw.deep.intrinsics do
   check(c.name==intrinsicNames[i],'Named intrinsic state '..i)
   if c.name=='seek before first play'then check(h.Page.Media:Key(h.Item,'Right'),'Actual seek control');h.Drain()
   elseif c.name=='explicit load resets poster flag'then h.Run('v.src=clip') -- resource-reset equivalent; full VIDEO load() API is separate.
   elseif c.name=='actual play hides poster'then h.Page:PlayMedia('v');h.Drain()
   elseif c.name=='pause keeps video frame'then h.Page:PauseMedia('v');h.Drain()
   elseif c.action~=''then h.Run(c.action)end
   h.Geometry(c.value,c.name,true);h.Dimensions(c.value.videoWidth,c.value.videoHeight,'Current native source metadata '..c.name)
  end
  h.Destroy()
 end
 local controlNames={
  ['no-JS initial poster and partial completion']=true,['document load waits for initial poster']=true,
  ['poster cancel releases load barrier']=true,['poster swap rejects old completion']=true,
  ['disposed page rejects delayed poster']=true,['removed media rejects delayed poster']=true,
  ['SVG raster empty retained transitions']=true,['same poster batch and base-only changes']=true,
  ['poster no video data despite cleared flag']=true,['metadata resolution and old source callbacks']=true,
  ['fullscreen retained presentation changes']=true,['managed audio exact startup predicate']=true,
  ['media source child selectors retain render owner']=true,
  ['pending replacement retains old represented frame']=true,['poster failure clears represented frame']=true,
  ['same script source activation metadata']=true,['detached before flush rejects poster completion']=true,
  ['no-JS prepared SVG waits for active registration']=true,['hidden SVG poster avoids playback raster work']=true,
  ['dynamic prepared SVG waits for active registration']=true,
  ['native display fill and contain retain transport']=true,
 }
 local controls={}
 local function control(name,modern)check(controlNames[name],'Named presentation control '..name);local key=name..':'..tostring(modern);check(not controls[key],'No repeated presentation control');controls[key]=true end
 for _,modern in {true,false}do
  do
   control('native display fill and contain retain transport',modern)
   local h=fixture({Modern=modern});h.Drain();h.Focus();h.Run('m.src=clip;m.preload="auto";m.style.width="320px";m.style.height="180px"');h.Page:PlayMedia('v');h.Drain();local source,generation,loads=h.Native(),h.Item.SourceGeneration,h.Counts.NativeLoads;local surface=h.Item.VideoDisplay or h.Item.VideoGui
   near(surface.Size[1],320,'Default video contain width');near(surface.Size[2],160,'Default video contain height');near(surface.Position[2],10,'Default video contain offset');if modern then check(surface.ScaleType==Enum.ScaleType.Fit,'Default VideoDisplay uses native Fit')end
   h.Run('m.style.objectFit="fill"');near(surface.Size[1],320,'Explicit video fill width');near(surface.Size[2],180,'Explicit video fill height');near(surface.Position[2],0,'Explicit video fill offset');if modern then check(surface.ScaleType==Enum.ScaleType.Stretch,'Explicit fill uses native Stretch without a second contain operation')end
   h.Run('m.style.objectFit="cover"');near(surface.Size[1],360,'Explicit video cover width');near(surface.Size[2],180,'Explicit video cover height');near(surface.Position[1],-20,'Explicit video cover crop offset');if modern then check(surface.ScaleType==Enum.ScaleType.Fit,'Cover uses native Fit on the already scaled rectangle')end
   h.Run('m.style.objectFit="initial"');near(surface.Size[1],320,'Initial fill width');near(surface.Size[2],180,'Initial fill height');if modern then check(surface.ScaleType==Enum.ScaleType.Stretch,'CSS initial resets UA contain to native Stretch')end
   h.Run('m.style.objectFit="contain"');near(surface.Size[1],320,'Restored contain width');near(surface.Size[2],160,'Restored contain height');near(surface.Position[2],10,'Restored contain offset');if modern then check(surface.ScaleType==Enum.ScaleType.Fit,'Restored contain uses native Fit')end
   if modern then h.Item.Style.ObjectFit=nil;h.Page.Media:RefreshPresentation(h.Item);check(surface.ScaleType==Enum.ScaleType.Stretch,'Absent host-profile fit uses native Stretch');h.Item.Style.ObjectFit='contain';h.Page.Media:RefreshPresentation(h.Item)end
   check(h.Native()==source and h.Item.SourceGeneration==generation and h.Counts.NativeLoads==loads and h.Native().IsLoaded,'Fit-only mutation retains source/backend/readiness without IO');h.Retained();h.Destroy()
  end
  do
   control('dynamic prepared SVG waits for active registration',modern)
   local h=fixture({Modern=modern});h.Drain();h.Focus();h.Run('var n=document.createElement("video");n.id="dynamic";n.preload="none";n.poster="wide.svg";document.body.append(n)',true);local node=Node.findById(h.Page.Document,'dynamic');local item=h.Tree.MediaByNode[node];check(item~=nil and item.PosterSVGItem~=nil,'Actual structural VIDEO has prepared packaged poster');local prepared=item.PosterSVGItem;check(not item.PosterReady and prepared.UpdateSVG==nil and not h.SVG[prepared]and h.Counts.SVGAdded==0 and h.Counts.SVGJobs==0 and h.Page.PosterPendingCount==1,'Pending dynamic VIDEO is not an active poster SVG registration');local gui,poster=item.Gui,item.PosterGui;h.Drain();check(item.PosterReady and h.SVG[item.PosterSVGItem]and h.Counts.SVGAdded==1 and h.Counts.SVGRemoved==0 and h.Page.PosterPendingCount==0 and item.Gui==gui and item.PosterGui==poster,'One decoded dynamic poster registers on retained native surfaces');h.Run('n.remove()');check(h.Counts.SVGRemoved==1 and next(h.SVG)==nil,'Dynamic removal retires the active SVG registration exactly once');h.Retained();h.Destroy()
  end
  do
   control('no-JS prepared SVG waits for active registration',modern)
   local h=fixture({Modern=modern,Scripting=false,Poster='wide.svg'});local prepared=h.Item.PosterSVGItem;check(prepared~=nil and prepared.UpdateSVG==nil and not h.SVG[prepared]and h.Counts.SVGAdded==0 and h.Counts.SVGJobs==0 and not h.Item.PosterGui.Visible and h.Item.PosterWidth==nil and h.Page.PosterPendingCount==1,'Actual no-JS page does not register/raster/publish a prepared SVG before image completion');h.Drain();check(h.Item.PosterReady and h.SVG[h.Item.PosterSVGItem]and h.Counts.SVGAdded==1 and h.Page.PosterPendingCount==0 and prepared.UpdateSVG==nil,'Current decoded SVG alone enters actual page registration');h.Geometry({width=200,height=100},'Decoded initial packaged SVG');h.Destroy();check(next(h.SVG)==nil,'Actual page removes active poster SVG registration')
  end
  do
   control('hidden SVG poster avoids playback raster work',modern)
   local h=fixture({Modern=modern});h.Drain();h.Focus();h.Run('m.poster="wide.svg";m.style.width="320px";m.style.height="180px";m.src=clip;m.preload="auto"');local jobs=h.Counts.SVGJobs;h.Page:PlayMedia('v');h.Drain();for _=1,6 do h.Native().TimePosition+=1;h.Page.Media:RefreshPresentation(h.Item);MediaBox.paint(h.Item)end;check(not h.Item.PosterGui.Visible and h.Counts.SVGJobs==jobs,'Playback/time/retained surface work never rasters the hidden poster');h.Retained();h.Destroy()
  end
  do
   control('pending replacement retains old represented frame',modern)
   local h=fixture({Modern=modern});h.Drain();h.Focus();h.Run('m.poster=wide');local source=h.Item.Poster;local native=h.Native();h.Options.DelayPoster=true;h.Run('m.poster=tall');check(h.Page.PosterPendingCount==1 and h.Item.Poster==source,'Pending replacement retains previous decoded poster');h.Geometry({width=200,height=100},'Old represented frame during replacement');h.Retained();h.Resume();h.Geometry({width=120,height=240},'New represented frame after replacement');check(h.Native()==native and h.Counts.NativeLoads==0,'Replacement keeps native backend/source');h.Destroy()
  end
  do
   control('poster failure clears represented frame',modern)
   local h=fixture({Modern=modern});h.Drain();h.Run('m.poster=wide');h.Geometry(reference.raw.posterBarrier[5].value,'Native valid replacement frame');h.Run('m.poster="bad.png"');h.Geometry(reference.raw.posterBarrier[6].value,'Native failed replacement frame');check(h.Item.Poster==nil and h.Item.PosterSVG==nil and h.Page.PosterPendingCount==0,'Current decode failure clears poster and load blocker');h.Destroy()
  end
  do
   control('same script source activation metadata',modern)
   local h=fixture({Modern=modern});h.Drain();h.Focus();h.Run('m.src=clip;m.preload="auto"');h.Dimensions(80,40,'Metadata baseline before inline reads')
   for _,action in {'m.src="two.webm"','m.src="two.webm"','m.src=""','m.src=clip;m.removeAttribute("src")'}do
    local loads,passes=h.Counts.NativeLoads,h.Counts.Passes;h.Direct(action..';window.immediate=JSON.stringify([m.videoWidth,m.videoHeight])');check(h.Realm.Window.Get('immediate')=='[0,0]','Same-script setter immediately invalidates exposed dimensions '..action);check(h.Counts.NativeLoads==loads and h.Counts.Passes==passes,'Dimension read performs no native IO/layout');h.Page:FlushScriptLayout();h.Drain();h.Run('m.src=clip');h.Dimensions(80,40,'Restored current metadata')
   end
   local loads,passes=h.Counts.NativeLoads,h.Counts.Passes;h.Direct('m.removeAttribute("src");window.immediate=JSON.stringify([m.videoWidth,m.videoHeight])');check(h.Realm.Window.Get('immediate')=='[80,40]'and h.Counts.NativeLoads==loads and h.Counts.Passes==passes,'Removal-only read retains selected resource without IO/layout');h.Page:FlushScriptLayout();h.Drain();h.Retained();h.Destroy()
  end
  do
   control('detached before flush rejects poster completion',modern)
   local h=fixture({Modern=modern,Poster='wide.png',DelayPoster=true});h.Drain();local changed=h.Page.MediaPresentationChanged;local publications=0;h.Page.MediaPresentationChanged=function(...)publications+=1;return changed(...)end;h.Direct('m.remove()');local passes=h.Counts.Passes;h.Resume(true);check(h.Item.PosterReady==false and h.Item.PosterWidth==nil and not h.Item.PosterGui.Visible and publications==0 and h.Page.PosterPendingCount==0 and h.Counts.Passes==passes,'Disconnected pre-flush native callback does not publish prepared data, paint or perform layout');h.Page:FlushScriptLayout();h.Drain();h.Destroy()
  end
  do
   control('no-JS initial poster and partial completion',modern)
   local h=fixture({Modern=modern,Scripting=false,Poster='wide.png',DelayPoster=true});check(h.Realm==nil and h.Page.PosterPendingCount==1,'No-JS poster starts through actual page hook');h.Drain();check(#h.Waiting==1 and h.Item.PosterReady==false and h.Item.PosterWidth==nil and not h.Item.PosterGui.Visible and h.Item.PosterGui.Image=='','Real native preload is suspended; prepared resource never paints or supplies dimensions');h.Geometry({width=300,height=150},'Pending initial poster missing size');local partial=h.Counts.PartialPasses;h.Resume();h.Geometry({width=200,height=100},'Real no-JS poster decode');check(h.Page.PosterPendingCount==0 and h.Counts.PartialPasses>partial,'Poster completion dirties retained media owner');h.Destroy()
  end
  do
   control('document load waits for initial poster',modern)
   local h=fixture({Modern=modern,Poster='wide.png',DelayPoster=true});h.Drain();h.Run('window.stage=document.readyState');check(h.Realm.Window.Get('stage')=='interactive'and h.Realm.Window.Get('loadSeen')==0 and h.Page.PosterPendingCount==1,'Actual document remains interactive while poster fetch is pending');h.Resume();h.Run('window.stage=document.readyState');check(h.Realm.Window.Get('stage')=='complete'and h.Realm.Window.Get('loadSeen')==1 and h.Page.PosterPendingCount==0,'Actual poster completion releases document load once');h.Destroy()
  end
  do
   control('poster cancel releases load barrier',modern)
   local h=fixture({Modern=modern,Poster='wide.png',DelayPoster=true});h.Drain();h.Run('m.removeAttribute("poster");window.stage=document.readyState');h.Run('window.stage=document.readyState');check(h.Page.PosterPendingCount==0 and h.Realm.Window.Get('stage')=='complete'and h.Realm.Window.Get('loadSeen')==1,'Cancellation releases actual document load');local passes=h.Counts.Passes;h.Resume();check(h.Item.Poster==nil and h.Item.PosterSVG==nil and h.Counts.Passes==passes and h.Realm.Window.Get('loadSeen')==1,'Cancelled native completion is inert');h.Destroy()
  end
  do
   control('poster swap rejects old completion',modern)
   local h=fixture({Modern=modern,Poster='wide.png',DelayPoster=true});h.Drain();h.Focus();h.Run('v.poster=tall');check(#h.Waiting==2 and h.Page.PosterPendingCount==1,'Two genuine native jobs, one current poster lease');local epoch=h.Item.SourceGeneration;h.Resume();check(h.Item.PosterReady==false and h.Item.PosterWidth==nil and h.Page.PosterPendingCount==1,'Old completion cannot replace current pending poster');h.Resume();h.Geometry({width=120,height=240},'Current tall poster after old completion');check(h.Item.SourceGeneration==epoch and h.Counts.NativeLoads==0,'Poster swap never selects video source');h.Destroy()
  end
  do
   control('disposed page rejects delayed poster',modern)
   local h=fixture({Modern=modern,Poster='wide.png',DelayPoster=true});h.Drain();h.Destroy();local passes=h.Counts.Passes;h.Resume();check(h.Counts.Passes==passes and h.Item.Poster==nil and h.Page.LoadVideoPoster==nil and h.Page.MediaPresentationChanged==nil,'Disposed actual page rejects native callback and releases hooks')
  end
  do
   control('removed media rejects delayed poster',modern)
   local h=fixture({Modern=modern,Poster='wide.png',DelayPoster=true});h.Drain();h.Run('m.remove()');check(h.Tree.MediaByNode[h.Node]==nil and h.Page.PosterPendingCount==0,'Actual structural removal cancels poster lease');local passes=h.Counts.Passes;h.Resume();check(h.Item.Poster==nil and h.Item.PosterSVGItem==nil and h.Counts.Passes==passes,'Removed retained media rejects delayed response');h.Destroy()
  end
  do
   control('SVG raster empty retained transitions',modern)
   local h=fixture({Modern=modern});h.Drain();h.Focus();local native=h.Native();h.Run('m.poster="wide.svg"');local svg=h.Item.PosterSVGItem;check(svg and h.SVG[svg]and h.Counts.SVGAdded==1,'Actual page registers packaged SVG poster');h.Geometry({width=200,height=100},'SVG poster dimensions');local jobs=h.Counts.SVGJobs
   for _=1,5 do h.Page.Media:RefreshPresentation(h.Item);MediaBox.paint(h.Item)end
   check(h.Counts.SVGJobs==jobs,'Same poster geometry/paint creates no SVG work');h.Run('m.poster=tall');check(not h.SVG[svg]and svg.UpdateSVG==nil and h.Counts.SVGRemoved==1,'Old SVG registration retired before raster switch');h.Geometry({width=120,height=240},'Raster after SVG');h.Run('m.removeAttribute("poster")');h.Geometry({width=300,height=150},'Empty after raster');check(h.Native()==native and h.Counts.NativeLoads==0,'Poster resource switches retain native transport');h.Destroy()
  end
  do
   control('same poster batch and base-only changes',modern)
   local h=fixture({Modern=modern});h.Drain();h.Focus();h.Run('m.poster=wide');local source=h.Item.Poster;local loads=h.Counts.PosterLoads;local url=h.Item.PosterURL
   h.Run('var b=document.createElement("base");b.href="https://other.test/current/";document.head.appendChild(b)');check(h.Item.PosterURL==url and h.Item.Poster==source and h.Counts.PosterLoads==loads,'Base-only mutation does not fetch or replace poster');h.Run('m.poster=wide;m.removeAttribute("poster");m.poster=wide',true);check(h.Page.PosterPendingCount==1,'Same-batch final set remains a current load blocker');h.Drain();check(h.Item.PosterURL=='https://other.test/current/wide.png'and h.Item.Poster==source and h.Counts.PosterLoads==loads,'New activation uses current owner base and cached mapped asset');h.Retained();h.Destroy()
  end
  do
   control('poster no video data despite cleared flag',modern)
   local h=fixture({Modern=modern});h.Drain();h.Run('m.poster=wide');h.Item.ShowPoster=false;h.Item.VideoFrameAvailable=false;h.Page:MediaPresentationChanged(h.Item);h.Drain();h.Geometry({width=200,height=100},'No-data representation still uses poster');check(h.Item.PosterGui.Visible,'No metadata keeps poster visible despite seek flag');h.Item.VideoWidth,h.Item.VideoHeight=80,40;h.Page:MediaPresentationChanged(h.Item);h.Drain();h.Geometry({width=200,height=100},'Metadata-only synthetic frame unavailability');check(h.Item.PosterGui.Visible,'Metadata-only proxy keeps poster represented');h.Destroy()
  end
  do
   control('metadata resolution and old source callbacks',modern)
   local h=fixture({Modern=modern,DelayVideo=true});h.Drain();h.Run('m.src=clip;m.preload="auto"');h.Dimensions(0,0,'In-flight metadata stays zero');local object=h.Native();local old=object:GetPropertyChangedSignal('Resolution'):Snapshot();h.Run('m.src="two.webm"');for _,callback in old do object.Resolution=Vector2.new(999,777);callback()end;h.Dimensions(0,0,'Old signal closure cannot publish metadata');h.Resume();h.Dimensions(0,0,'Old in-flight load cannot publish metadata');check(#h.Waiting==1,'Current source load remains independently pending');h.Resume();h.Dimensions(80,40,'Current metadata becomes available');local eventCount=0;local observer=h.Page.Events:BeforeEmit(function(e)if e.Target==h.Node and e.Type=='resize'then eventCount+=1 end end)
   object.Resolution=Vector2.new(160,40);object:GetPropertyChangedSignal('Resolution'):Fire();h.Drain();h.Dimensions(160,40,'Live current resource resolution');check(eventCount==1,'One current dimensions-change resize');object:GetPropertyChangedSignal('Resolution'):Fire();check(eventCount==1,'Identical dimensions produce no resize');observer:Disconnect();h.Destroy()
  end
  do
   control('fullscreen retained presentation changes',modern)
   local h=fixture({Modern=modern});h.Drain();h.Focus();h.Run('m.controls=true;m.poster=wide;m.style.width="320px";m.style.height="180px"');check(h.Page:EnterMediaFullscreen('v'),'Actual fullscreen entry');h.Run('m.poster=tall;m.width=80;m.height=60');h.Retained();near(h.Item.BoxGui.Size[1],960,'Fullscreen poster mutation retains overlay width');near(h.Item.BoxGui.Size[2],540,'Fullscreen poster mutation retains overlay height');near(h.Item.PosterGui.Size[1],270,'Tall fullscreen contain width');near(h.Item.PosterGui.Size[2],540,'Tall fullscreen contain height');h.Run('m.removeAttribute("poster");m.style.width="400px";m.style.height="200px"');check(h.Page:ExitMediaFullscreen(),'Actual fullscreen exit');h.Drain();h.Geometry({width=400,height=200},'Fullscreen exit restores current CSS geometry');h.Destroy()
  end
 end
 do
  control('managed audio exact startup predicate','startup')
  check(not HTMLScripts.ShouldStart({Document={Kind='Document',Children={}}},{JavaScript=false,JavaScriptServices={LoadStylesheet=function()end}}),'JavaScript false wins exact startup predicate')
  check(not HTMLScripts.ShouldStart({Document={Kind='Document',Children={}}},{JavaScriptServices={LoadStylesheet=false}}),'Falsy loader does not create a realm')
  local modes={
   {Name='none',Scripting=false,HTML='<audio controls src="second.mp3" preload="none"></audio>'},
   {Name='no realm',HTML='<audio controls src="second.mp3" preload="none"></audio>'},
   {Name='script delayed ordered candidates',DelayVM=true,HTML='<audio controls autoplay><source src="first-missing.mp3"><source src="second.mp3"></audio><script>var initialized=true;</script>'},
   {Name='stylesheet-only delayed',DelayVM=true,StylesheetOnly=true,HTML='<audio controls preload="none" src="second.mp3"></audio>'},
   {Name='contenteditable delayed',DelayVM=true,HTML='<audio controls preload="none" src="second.mp3"></audio><div contenteditable="true">Edit</div>'},
  }
  for _,mode in modes do local h=fixture(mode);h.Drain();local sound;for _,o in h.Instances do if o.ClassName=='Sound'then check(sound==nil,'Startup uses one retained Sound');sound=o end end;check(sound~=nil,'Startup has actual mounted Sound')
   if mode.DelayVM then check(h.Page.ManagedAudioStartup and h.Realm~=nil,'Exact true realm owns audio startup '..mode.Name);if mode.Name=='script delayed ordered candidates'then check(h.Counts.NativeLoads==1 and sound.SoundId=='rbxassetid://301'and sound.Playing,'Ordered source selection alone binds and plays mapped second source')else check(h.Counts.NativeLoads==0 and sound.SoundId=='','Managed preload none has no native source IO')end
   else check(not h.Page.ManagedAudioStartup and h.Realm==nil and sound.SoundId=='rbxassetid://301'and h.Counts.NativeSoundBind==1,'No realm preserves ordinary audio source binding '..mode.Name)end
   h.Destroy()
  end
 end
 do
  control('media source child selectors retain render owner','selectors')
  local h=fixture({HTML='<style>audio:has(source[src="two.wav"]){color:rgb(0,0,255)}audio:empty{color:rgb(255,0,0)}</style><audio id="a" controls preload="none"><source id="s" src="first-missing.mp3"></audio><script>var a=document.getElementById("a"),s=document.getElementById("s");</script>'});h.Drain();local a=Node.findById(h.Page.Document,'a');local item=h.Tree.MediaByNode[a];local gui,sound=item.Gui,item.Sound
  h.Run('a.insertBefore(Object.assign(document.createElement("source"),{src:"two.wav"}),s)');check(item.Style.Color.B==1 and item.Style.Color.R==0,'SOURCE insertion updates actual :has cascade');check(h.Tree.MediaByNode[a]==item and item.Gui==gui and item.Sound==sound,'SOURCE CSS invalidation retains renderer/session');h.Run('a.replaceChildren()');check(item.Style.Color.R==1 and item.Style.Color.B==0,'SOURCE removal updates actual :empty cascade');check(item.Gui==gui and item.Sound==sound,'Empty media children do not recreate render owner');h.Destroy()
 end
 for name in controlNames do local found=false;for key in controls do if key:sub(1,#name+1)==name..':'then found=true end end;check(found,'Required presentation control missing '..name)end
 local barrierNames={'pending initial poster delays load','fulfilled initial poster releases load','pending second document poster','removed pending poster releases load','valid replacement poster','failed replacement clears poster frame'}
 check(#reference.raw.posterBarrier==6,'Exact native network/load inventory');for i,c in reference.raw.posterBarrier do check(c.name==barrierNames[i],'Named actual HTTP poster/load case '..i)end
 check(reference.raw.posterBarrier[1].value.ready=='interactive'and reference.raw.posterBarrier[1].value.loaded==0 and reference.raw.posterBarrier[2].value.ready=='complete'and reference.raw.posterBarrier[2].value.loaded==1 and reference.raw.posterBarrier[4].value.ready=='complete'and reference.raw.posterBarrier[4].value.loaded==1,'Independent native HTTP document load completion and cancellation evidence')
 check(nativeStates==152,'All raw geometry/intrinsic/dimension states remain compared for both backends')
 local controlCount=0;for _ in controls do controlCount+=1 end
 print('VideoPresentationRendering: '..nativeStates..' captured geometry states / '..(states-nativeStates)..' lifecycle geometry checks / '..controlCount..' named controls / '..checks..' assertions passed')
end
