--!strict
-- Actual HTMLPage startup, Controller and HTMLScripts; deterministic native
-- metadata/resource completion is distinct from Chrome and Studio pixels.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Node,Controller,HTMLScripts,MediaBox,loadPosterSVG,WorkContext)
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
  local workWaiting={};local publicationEvents=0;local publicationConnection
  local counts={WorkWaits=0,CloneStarted=0,CloneCompleted=0,RasterRequests=0,PosterLoads=0,PosterCancelled=0,SVGAdded=0,SVGRemoved=0,SVGJobs=0,NativeLoads=0,NativePlay=0,NativeSoundBind=0,Passes=0,PartialPasses=0}
  local function enqueue(fn,delay)local h={Callback=fn,Due=time+(delay or 0)};table.insert(jobs,h);return h end
  local function clock()if options.Cooperative then time+=.00075 end;return time end
  local function continueThread(thread)local ok,message=coroutine.resume(thread);check(ok,tostring(message))end
  local tasks={spawn=enqueue,defer=enqueue,delay=function(delay,fn)return enqueue(fn,delay)end,cancel=function(h)h.Cancelled=true end,wait=function()
   time+=.016
   if options.Cooperative then
    counts.WorkWaits+=1;local thread=coroutine.running()
    if options.HoldWorkWait then table.insert(workWaiting,thread)else enqueue(function()continueThread(thread)end)end
    coroutine.yield()
   end
  end}
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
  if options.ActualSVG then
   svgRuntime=loadPosterSVG(tasks,options,counts,check).start -- returned owner start below
  end
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
    if options.ActualSVG then svgRuntime=svgRuntime(owner,current,function()end,{Task=tasks,Asset={},Inset=Vector2.new(0,0),PrewarmStates=0});return svgRuntime end
    svgRuntime:AddItems(current.SVGItems);owner:AddCleanup(function()local all={};for i in svgs do table.insert(all,i)end;svgRuntime:RemoveItems(all)end);return svgRuntime
   end},
  },tasks,clock)
  local scripts=if options.Scripting==false then ''else '<script>var m=document.getElementById("v"),v=m,wide="wide.png",tall="tall.png",clip="one.webm",e=document.getElementById("editor");window.loadSeen=0;window.addEventListener("load",function(){loadSeen++})</script>'
  local html=options.HTML or('<!doctype html><style>body{margin:0}video{display:block}</style><video id="v" muted preload="none" '..(if options.Poster then 'poster="'..options.Poster..'" 'else '')..'></video><input id="editor" tabindex="-1" value="A&#x1f600;BC"><p id="neighbor">retained neighbor</p>'..scripts)
  local mountOptions={JavaScript=options.Scripting~=false,RenderWorkBudgetMS=if options.Cooperative then 4 else 0,DocumentURL='https://video.test/root/index.html',Images={['wide.png']='101',['tall.png']='102',['bad.png']='109',['bad-two.png']='1092'},SVGs={['wide.svg']='<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100"/></svg>'},Videos={['one.webm']='201',['two.webm']='202'},Audio={['second.mp3']='301'},JavaScriptServices={Task=tasks,Clock=function()return time end,RunService=run,ResourceServices=resources,AudioServices={Task=tasks,Instance=instance,RunService=run,ContentProvider=provider}}}
  if options.StylesheetOnly then mountOptions.JavaScriptServices.LoadStylesheet=function()return ''end end
  local function pump()
   for _=1,16000 do
    if #jobs==0 then return end
    local job=table.remove(jobs,1)
    if not job.Cancelled then time=math.max(time,job.Due);continueThread(coroutine.create(job.Callback))end
   end;error('Presentation queue did not converge')
  end
  local function mounted()
   page=module.mount(factory.create('Frame',factory.create('ScreenGui',nil,{}),{}),html,mountOptions)
   publicationConnection=page.Root:GetAttributeChangedSignal('Presented'):Connect(function()if page.Root:GetAttribute('Presented')==true then publicationEvents+=1 end end)
  end
  if options.Cooperative then continueThread(coroutine.create(mounted));pump();check(page~=nil,'Default Work4 actual HTMLPage mount completes cooperatively')else mounted()end
  local realm=page.JavaScriptRuntime;local node=Node.findById(page.Document,'v');local item=node and tree.MediaByNode[node]
  local gui,box,frame,display=if item then item.Gui else nil,if item then item.BoxGui else nil,if item then item.VideoGui else nil,if item then item.VideoDisplay else nil
  local function drain()pump()end
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
  local function destroy()if publicationConnection then publicationConnection:Disconnect();publicationConnection=nil end;page:Destroy();drain();check(not page.Alive and page.PosterPendingCount==0,'Actual HTMLPage disposed poster barrier');check(run.Heartbeat:Count()==0 and run.RenderStepped:Count()==0,'Actual page media frame connections disposed');check(input.InputBegan:Count()==0 and input.InputChanged:Count()==0 and input.InputEnded:Count()==0,'Actual Controller disposal');if realm then check(not realm.Alive and not realm.EventLoop.Alive,'Actual realm disposal')end end
  return {Page=page,Tree=tree,Item=item,Node=node,Realm=realm,Run=script,Direct=direct,Drain=drain,Resume=resume,Retained=retained,Geometry=geometry,Dimensions=dimensions,Destroy=destroy,Counts=counts,Waiting=waiting,Jobs=jobs,SVG=svgs,Native=function()return item.VideoPlayer or item.VideoGui end,Options=options,Focused=function()return focused end,Focus=focus,Instances=natives,Created=created,PublicationEvents=function()return publicationEvents end,WorkWaiting=workWaiting,Continue=continueThread,
   StageSVG=function()
    local parent=Node.findById(page.Document,'svgowner');check(parent~=nil,'Independent SVG structural owner')
    local svg=Node.element('svg',{width='10',height='10'});svg.NamespaceURI='http://www.w3.org/2000/svg'
    for n=1,20 do local rect=Node.element('rect',{width='1',height='1',x=tostring(n%10),y=tostring(n%10)});rect.NamespaceURI=svg.NamespaceURI;Node.append(svg,rect)end
    Node.append(parent,svg);tree:ApplyDOMChanges({[parent]={Children=true}})
    local item;for _,s in tree.SVGItems do if s.Node==svg then item=s;break end end
    check(item~=nil and item.UpdateSVG==nil,'Actual RenderTree stages an unregistered structural SVG')
    return item
   end}
 end

 -- These controls verify this engine's initial atomic presentation policy,
 -- independently of native HTML document-load semantics.
 local count=0
 local cases={};local allowed={['cooperative nil poster publication']=true,['cooperative dead page publication']=true,['publication nested mutation']=true,['publication nil error']=true,['publication false error']=true,['publication table error']=true,['resource readiness wake gates']=true,['script worker flush yield']=true,['forced script flush yield']=true,['initial success']=true,['initial failure without layout']=true,['initial poster removal']=true,['initial replacement rejects old completion']=true,['initial media removal']=true,['initial disposal']=true,['playing initial poster completion without layout']=true,['replacement after presented remains shown']=true,['initial visibility toggle']=true,['two SS forward']=true,['two SS reverse']=true,['two SF forward']=true,['two SF reverse']=true,['two FS forward']=true,['two FS reverse']=true,['two FF forward']=true,['two FF reverse']=true}
 local function case(name,modern)local key=name..':'..tostring(modern);check(allowed[name]and not cases[key],'Exact mounted presentation case '..key);cases[key]=true end
 local function blank(h)for _,o in h.Created do if o.Name=='HTMLLoadingSurface'then return o end end;error('Actual HTMLPage loading surface missing')end
 local function hidden(h,label)check(h.PublicationEvents()==0,'Pending initial presentation emits no Presented event');check(h.Page.JavaScriptRuntime==nil,'Actual no-Realm page');local preserved=h.Page.PosterPendingCount>0 and not h.Page.Presented and h.Page.Root:GetAttribute('Presented')==false and not h.Page.Root.Visible and not blank(h).Destroyed and blank(h).Visible;if not preserved then print('Presentation diagnostic',h.Page.PosterPendingCount,h.Page.Presented,h.Page.Root:GetAttribute('Presented'),h.Page.Root.Visible,blank(h).Destroyed,blank(h).Visible)end;check(preserved,label);count+=1 end
 local function shown(h,label)check(h.PublicationEvents()==1,'Initial presentation publishes exactly once');check(h.Page.Alive and h.Page.PosterPendingCount==0 and h.Page.Presented and h.Page.Root:GetAttribute('Presented')==true and h.Page.Root.Visible and blank(h).Destroyed,label);count+=1 end
 local function setPoster(h,raw)h.Node.Attributes.poster=raw;h.Page:LoadVideoPoster(h.Item,raw);h.Drain()end
 for _,modern in {true,false}do
  do
   case('initial success',modern)
   local h=fixture({Modern=modern,Scripting=false,Poster='wide.png',DelayPoster=true});h.Drain();hidden(h,'Held initial decode keeps real page root blank');local passes=h.Counts.Passes;h.Resume();shown(h,'Success releases initial page presentation after current geometry');check(h.Counts.Passes>passes,'Success arranged actual poster dimensions');h.Geometry({width=200,height=100},'Presented decoded poster');h.Destroy()
  end
  do
   case('initial failure without layout',modern)
   local h=fixture({Modern=modern,Scripting=false,Poster='bad.png',DelayPoster=true});h.Drain();hidden(h,'Held failure remains blank');local passes=h.Counts.Passes;h.Resume();shown(h,'Failure wakes initial presentation without a geometry change');check(h.Counts.Passes==passes,'Failure does not require another layout to present');h.Destroy()
  end
  do
   case('initial poster removal',modern)
   local h=fixture({Modern=modern,Scripting=false,Poster='wide.png',DelayPoster=true});h.Drain();hidden(h,'Held removable poster stays blank');local passes=h.Counts.Passes;setPoster(h,nil);shown(h,'Absent poster cancellation wakes ready no-Realm page');check(h.Counts.Passes==passes,'Cancellation needs no new layout');h.Resume();shown(h,'Late cancelled completion does not repeat initial publication');h.Destroy()
  end
  do
   case('initial replacement rejects old completion',modern)
   local h=fixture({Modern=modern,Scripting=false,Poster='wide.png',DelayPoster=true});h.Drain();hidden(h,'Held replaceable poster stays blank');setPoster(h,'tall.png');hidden(h,'Replacement retains one current lease and blank surface');check(#h.Waiting==2 and h.Page.PosterPendingCount==1,'Native requests genuinely overlap');h.Resume();hidden(h,'Old replaced completion cannot release current presentation barrier');h.Resume();shown(h,'Current replacement alone releases presentation');h.Geometry({width=120,height=240},'Current replacement geometry');h.Destroy()
  end
  do
   case('initial media removal',modern)
   local h=fixture({Modern=modern,Scripting=false,Poster='wide.png',DelayPoster=true});h.Drain();hidden(h,'Held removable item keeps initial blank');Node.removeChild(h.Node.Parent,h.Node);h.Page.Media:Remove({h.Item});h.Drain();shown(h,'Actual native media owner removal releases its presentation lease');h.Resume();shown(h,'Removed media delayed completion remains inert');h.Destroy()
  end
  do
   case('initial disposal',modern)
   local h=fixture({Modern=modern,Scripting=false,Poster='wide.png',DelayPoster=true});h.Drain();hidden(h,'Held soon-disposed page remains blank');h.Destroy();local passes=h.Counts.Passes;h.Resume();check(not h.Page.Alive and not h.Page.Presented and h.Page.Root:GetAttribute('Presented')==false and h.Counts.Passes==passes,'Disposed page never publishes from late native completion');count+=1
  end
  do
   case('playing initial poster completion without layout',modern)
   local h=fixture({Modern=modern,Scripting=false,DelayPoster=true,HTML='<video id="v" src="one.webm" muted preload="auto" poster="wide.png"></video>'});h.Drain();h.Page:PlayMedia('v');h.Drain();hidden(h,'Initial poster request blocks presentation even with video already playing');check(h.Item.ShowPoster==false and h.Item.VideoFrameAvailable==true,'Actual media play hides current poster representation');local passes=h.Counts.Passes;h.Resume();shown(h,'Hidden decoded poster completion wakes presentation without layout');check(h.Counts.Passes==passes and not h.Item.PosterGui.Visible,'Hidden posterior natural representation remains current video; no layout needed');h.Destroy()
  end
  do
   case('replacement after presented remains shown',modern)
   local h=fixture({Modern=modern,Scripting=false,Poster='wide.png'});h.Drain();shown(h,'Immediate initial current poster publication');h.Options.DelayPoster=true;setPoster(h,'tall.png');check(h.Page.Presented and h.Page.Root.Visible and blank(h).Destroyed and h.Page.PosterPendingCount==1,'Already presented page stays visible during later replacement');count+=1;h.Resume();shown(h,'Later replacement does not reblank page');h.Destroy()
  end
  for _,pair in {{Name='SS',First='wide.png',Second='tall.png',FirstReady=true,SecondReady=true},{Name='SF',First='wide.png',Second='bad.png',FirstReady=true,SecondReady=false},{Name='FS',First='bad.png',Second='wide.png',FirstReady=false,SecondReady=true},{Name='FF',First='bad.png',Second='bad-two.png',FirstReady=false,SecondReady=false}}do
   for _,reverse in {false,true}do
    case('two '..pair.Name..' '..(if reverse then 'reverse'else 'forward'),modern)
    local h=fixture({Modern=modern,Scripting=false,DelayPoster=true,HTML='<style>video{display:block}</style><video id="v" preload="none" poster="'..pair.First..'"></video><video id="w" preload="none" poster="'..pair.Second..'"></video>'});h.Drain();local secondNode=Node.findById(h.Page.Document,'w');local second=h.Tree.MediaByNode[secondNode];check(second~=nil and #h.Waiting==2 and h.Page.PosterPendingCount==2 and h.Counts.PosterLoads==2,'Two independent native requests and two live initial leases');hidden(h,'Counter two keeps all page layers blank');if reverse then h.Waiting[1],h.Waiting[2]=h.Waiting[2],h.Waiting[1]end
    h.Resume();check(h.Page.PosterPendingCount==1,'First actual completion releases only its own lease');hidden(h,'Counter one remains blank independently of success/failure/order');h.Resume();shown(h,'Counter zero publishes once after final current completion');check((h.Item.Poster~=nil)==pair.FirstReady and(second.Poster~=nil)==pair.SecondReady,'Exact independent success/failure outcomes');check(h.Counts.PosterLoads==2,'Counter/presentation does not create extra native requests');h.Destroy()
   end
  end
  do
   case('initial visibility toggle',modern)
   local h=fixture({Modern=modern,Scripting=false,Poster='wide.png',DelayPoster=true});h.Drain();hidden(h,'Held initially visible staging surface');local requests,passes=h.Counts.PosterLoads,h.Counts.Passes;h.Page:SetVisible(false);h.Drain();check(not h.Page.Presented and not h.Page.Root.Visible and not blank(h).Visible and not blank(h).Destroyed and h.Counts.PosterLoads==requests and h.Counts.Passes==passes,'Visibility false hides staging without new native IO/layout');h.Resume();check(h.Page.Presented and h.Page.Root:GetAttribute('Presented')==true and not h.Page.Root.Visible and blank(h).Destroyed and h.Page.PosterPendingCount==0,'Ready page commits while display preference stays hidden; blank retired once');count+=1;local completedPasses=h.Counts.Passes;h.Page:SetVisible(true);h.Drain();shown(h,'Restoring visibility shows already complete atomic page');check(h.Counts.PosterLoads==requests and h.Counts.Passes==completedPasses,'Visibility true alone performs no native request or layout');h.Destroy()
  end
  -- Actual Embedded.document/signature yields before SVG AddItems installs the
  -- retained updater or requests a raster. Raster/style work is a controlled
  -- queue: this is publication ordering evidence, not native SVG pixel parity.
  for _,dead in {false,true}do
   case(if dead then 'cooperative dead page publication'else 'cooperative nil poster publication',modern)
   local h=fixture({Modern=modern,Scripting=false,Cooperative=true,ActualSVG=true,DelayPoster=true,HTML='<style>body{margin:0}video{display:block}</style><video id="v" preload="none" poster="wide.png"></video><div id="svgowner"></div>'})
   h.Page.Root:SetAttribute('CompositeVisibleReady',false);h.Drain();hidden(h,'Default Work4 mounted page remains blank during initial native IO')
   h.Resume();check(h.Item.Poster~=nil and h.Page.PosterPendingCount==0 and not h.Page.Presented,'Decoded wide poster retained behind real compositor gate')
   setPoster(h,'tall.png');hidden(h,'New native lease holds replaced initial poster')
   local staged=h.StageSVG();h.Page.Root:SetAttribute('CompositeVisibleReady',true);h.Drain()
   local clones,requests=h.Counts.CloneStarted,h.Counts.RasterRequests
   h.Options.HoldWorkWait=true
   local operation=coroutine.create(function()WorkContext.runFor(h.Page,function()h.Node.Attributes.poster=nil;h.Page:LoadVideoPoster(h.Item,nil)end)end)
   h.Continue(operation)
   check(coroutine.status(operation)=='suspended'and #h.WorkWaiting==1 and h.Page.PosterPendingCount==0,'Nil cancellation genuinely suspends with last lease already released')
   check(h.Counts.CloneStarted==clones+1 and h.Counts.CloneCompleted<h.Counts.CloneStarted and staged.UpdateSVG==nil and h.Counts.RasterRequests==requests,'Actual Embedded clone suspended before SVG registration/request')
   h.Drain();check(not h.Page.Presented and not h.Page.Root.Visible and not blank(h).Destroyed and h.PublicationEvents()==0 and h.Page.LoadingWork.Active,'Deferred presentation cannot finish loading work during yielded poster publication');count+=1
   h.Options.HoldWorkWait=false;table.remove(h.WorkWaiting,1)
   if dead then
    h.Destroy();local ok,message=coroutine.resume(operation);check(not ok and WorkContext.isCancelled(message),'Disposed cooperative operation retains exact loading cancellation');h.Resume();check(not h.Page.Presented and h.PublicationEvents()==0,'Dead page stays unpublished after late work/native completion');count+=1
   else
    h.Continue(operation);h.Drain();shown(h,'Finished nil publication arranges and releases all ready gates once');h.Geometry({width=300,height=150},'Nil poster final intrinsic geometry');check(h.Counts.WorkWaits>0 and h.Page.LoadStats.Yields>0 and not h.Page.LoadingWork.Active,'Actual default Work4 yielded before the atomic commit');h.Resume();shown(h,'Old native completion cannot republish after nil transaction');h.Destroy()
   end
  end
  do
   case('publication nested mutation',modern)
   local h=fixture({Modern=modern,Scripting=false,Poster='wide.png',DelayPoster=true});h.Drain();hidden(h,'Nested mutation begins behind a live poster')
   local refresh=h.Page.RefreshDOMResources;local entered=false
   h.Page.RefreshDOMResources=function(self)
    if not entered then entered=true;self:LoadVideoPoster(h.Item,'tall.png');h.Drain();check(not self.Presented and self.PosterPendingCount==1,'Nested replacement cannot commit its parent publication')end
    return refresh(self)
   end
   h.Node.Attributes.poster=nil;h.Page:LoadVideoPoster(h.Item,nil);h.Page.RefreshDOMResources=refresh;h.Drain();hidden(h,'Nested transaction depth balanced while replacement is still pending')
   h.Resume();hidden(h,'Nested cancelled prior native job remains inert');h.Resume();shown(h,'Nested replacement releases balanced publication depth');h.Destroy()
  end
  for _,kind in {'nil','false','table'}do
   case('publication '..kind..' error',modern)
   local h=fixture({Modern=modern,Scripting=false,Poster='wide.png',DelayPoster=true});h.Drain();hidden(h,'Throwing transaction begins behind a live poster')
   local refresh=h.Page.RefreshDOMResources;local token=if kind=='table'then {}elseif kind=='false'then false else nil
   local requests,passes=h.Counts.PosterLoads,h.Counts.Passes
   h.Page.RefreshDOMResources=function()error(token,0)end
   local ok,message=pcall(function()h.Page:LoadVideoPoster(h.Item,nil)end);check(not ok and message==token,'Balanced publication propagates original '..kind..' error value exactly')
   check(h.Counts.PosterLoads==requests and h.Counts.Passes==passes,'Error balancing itself adds no native IO or layout')
   h.Page.RefreshDOMResources=refresh;h.Page:LoadVideoPoster(h.Item,'tall.png');h.Drain();hidden(h,'Recovering operation is not blocked by leaked publication depth')
   h.Resume();hidden(h,'Throwing transaction cancelled prior callback');h.Resume();shown(h,'Successful recovery publishes after balanced '..kind..' failure');h.Destroy()
  end
  do
   case('resource readiness wake gates',modern)
   local h=fixture({Modern=modern,Scripting=false,Poster='wide.png',DelayPoster=true});h.Page.Root:SetAttribute('SVGVisibleReady',false);h.Page.Root:SetAttribute('BackgroundVisibleReady',false);h.Page.Root:SetAttribute('CompositeVisibleReady',false);h.Drain();hidden(h,'Poster and all independent resource gates initially held');h.Resume()
   for _,name in {'SVGVisibleReady','BackgroundVisibleReady'}do h.Page.Root:SetAttribute(name,true);h.Drain();check(h.Page.PosterPendingCount==0 and not h.Page.Presented and h.PublicationEvents()==0,'Actual '..name..' wake cannot bypass remaining gate');count+=1 end
   h.Page.Root:SetAttribute('CompositeVisibleReady',true);h.Drain();shown(h,'Last independent ready signal wakes publication without another layout');h.Destroy()
  end
  -- Runtime.Flush empties its mutation table before the actual ApplyChanges
  -- resources callback. Yield inside that real callback, before it publishes.
  for _,forced in {false,true}do
   case(if forced then 'forced script flush yield'else 'script worker flush yield',modern)
   local h=fixture({Modern=modern,Scripting=true,Poster='bad.png',DelayPoster=true});h.Page.Root:SetAttribute('CompositeVisibleReady',false);h.Drain();h.Resume();check(not h.Page.Presented and h.Page.PosterPendingCount==0,'Real realm page held after resource completion')
   local refresh=h.Page.RefreshDOMResources;local entered=false
   h.Page.RefreshDOMResources=function(self,...)
    entered=true;h.Page.Root:SetAttribute('CompositeVisibleReady',true);coroutine.yield();return refresh(self,...)
   end
   h.Direct('var span=document.createElement("span");span.textContent="queued";document.getElementById("neighbor").appendChild(span)')
   local thread
   if forced then thread=coroutine.create(function()h.Page:FlushScriptLayout()end);h.Continue(thread)
   else
    for _=1,32 do
     local job=table.remove(h.Jobs,1);check(job~=nil,'Actual worker is queued for realm mutation')
     if not job.Cancelled then local current=coroutine.create(job.Callback);h.Continue(current);if entered then thread=current;break end end
    end
   end
   check(entered and coroutine.status(thread)=='suspended'and not h.Realm:HasPending(),'Actual runtime mutation batch is empty while flush caller remains suspended')
   h.Drain();check(not h.Page.Presented and h.PublicationEvents()==0,'Deferred commit respects '..(if forced then 'forced geometry flush'else 'scheduled worker')..' despite empty Runtime.Pending');count+=1
   h.Page.RefreshDOMResources=refresh;h.Continue(thread);h.Drain();shown(h,'Settled '..(if forced then 'forced flush schedule'else 'worker end')..' wakes presentation after blocked defer');check(#h.Realm.Diagnostics==0,'Real structural flush completed without runtime error');h.Destroy()
  end

 end
 local caseCount=0;for _ in cases do caseCount+=1 end;check(caseCount==52,'All26 exact presentation cases cover both native backends');for name in allowed do for _,modern in {true,false}do check(cases[name..':'..tostring(modern)],'Required mounted case '..name)end end
 print('PosterPresentationPrep: '..caseCount..' mounted cases / '..count..' atomic presentation controls / '..checks..' assertions passed')
end
