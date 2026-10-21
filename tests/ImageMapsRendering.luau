--!strict
-- Native coordinate origins are supplied by fake GUIs, not a Studio font or
-- screenshot oracle. CSS dimensions and actual input routing are separate.
return function(Parser,Node,Dirty,Controller,HTMLScripts,ImageMap,Links,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local expectedCases={'live association','shape null','shape ""','shape "rect"','shape "RECT"','shape "rectangle"','shape "Rectangle"','shape "unknown"','shape " rect "','shape "circle"','shape "CIRCLE"','shape "circ"','shape "Circ"','shape "poly"','shape "POLY"','shape "polygon"','shape "Polygon"','shape "default"','shape "DEFAULT"','shape " circle "','shape " default "','zero radius','negative radius','circle boundary','circle extra','polygon odd','polygon insufficient','polygon boundary','rectangle reverse','rectangle zero width','rectangle boundaries','rectangle extra','float coords','scientific coords','plus coords','empty separators','junk middle','junk suffix','junk prefix','hex coords','semicolon coords','default ignores coords','live area precedence and dead shapes','namespace map and areas','shadow root association','default finite precedence','padding border content bounds','broken image association bounds'}
 local inventory={};for _,c in reference.cases do assert(not inventory[c.name],'Duplicate image-map case');inventory[c.name]=c end
 assert(#reference.cases==#expectedCases,'Unexpected image-map inventory');for _,name in expectedCases do assert(inventory[name],'Missing '..name)end
 do
  -- A retained index with disconnected owners must permit collection before
  -- another input/frame. Use normal Luau GC pressure and weak sentinels.
  local doc=Parser.parseDocument('<img id="live" usemap="#keep"><map name="keep"><area shape="default"></map>');local items={};local index=ImageMap.new(doc,items)
  local lost=setmetatable({},{__mode='k'})
  coroutine.wrap(function()
   local plain={};lost[plain]='plain'
   local parent=Node.findElement(doc,function(n)return n.Name=='body'end)
   local map=Node.element('map',{name='gone'});local area=Node.element('area',{shape='default'});Node.append(map,area);Node.append(parent,map)
   local image=Node.element('img',{usemap='#gone'});Node.append(parent,image);local item={};index:Bind(image,item);index:Refresh();lost[map],lost[area],lost[image]='map','area','img'
   Node.removeChild(parent,image);Node.removeChild(parent,map);index:Refresh(true)
   assert(next(items)==nil and next(index.Roots)==nil and next(index.Owners)==nil and index.Snapshots[map]==nil and index.Snapshots[area]==nil,'Disconnected unit-index still has entries')
  end)()
  local function collected()return next(lost)==nil end
  for _=1,128 do if collected()then break end;local temporary=table.create(2048);for i=1,2048 do temporary[i]={i,i+1}end end
  local function remaining()local list={};for _,label in lost do table.insert(list,label)end;return table.concat(list,',')end
  assert(collected(),'Retained unit-index collection sentinel(s): '..remaining());index:Destroy()
 end
 local function expected(c,step,probe)
  for _,d in reference.normative.defaultPrecedence do if d.case==c.name and d.step==step-1 then return d.targets[probe]end end
  for _,e in c.steps[step].probes[probe].events do if e.type=='click'then return e.innerTarget end end;error('Missing genuine native click')
 end
 local function signal()
  local entries={};local api={}
  function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
  function api:Fire(...)for _,e in table.clone(entries)do if e[1].Connected then e[2](...)end end end
  function api:Count()local n=0;for _,e in entries do if e[1].Connected then n+=1 end end;return n end;return api
 end
 local focused,objects=nil,{}
 local factory={create=function(class,parent,properties)
  local gui=table.clone(properties or{});gui.ClassName,gui.Parent=class,parent;if gui.Visible==nil then gui.Visible=true end
  gui.AbsolutePosition,gui.AbsoluteSize=Vector2.new(0,0),Vector2.new(800,600);if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0)end
  gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local signals,attrs={},{}
  function gui:GetPropertyChangedSignal(k)signals[k]=signals[k]or signal();return signals[k]end
  function gui:GetAttributeChangedSignal(k)return self:GetPropertyChangedSignal('attribute:'..k)end
  function gui:SetAttribute(k,v)attrs[k]=v end;function gui:GetAttribute(k)return attrs[k]end
  function gui:IsA(k)return k==class or k=='GuiObject'end
  function gui:IsFocused()return focused==self end
  function gui:CaptureFocus()if focused==self then return end;local old=focused;focused=self;if old then old.FocusLost:Fire(false)end;self.Focused:Fire()end
  function gui:ReleaseFocus()if focused~=self then return end;focused=nil;self.FocusLost:Fire(false)end
  function gui:ConnectionCount()local n=self.Focused:Count()+self.FocusLost:Count()+self.InputBegan:Count();for _,s in signals do n+=s:Count()end;return n end
  function gui:Destroy()assert(not self.Destroyed,'Map disposed retained GUI twice');self.Destroyed=true;self:ReleaseFocus();self.Parent=nil end
  table.insert(objects,gui);return gui
 end};factory.modifier=factory.create
 local faces={};local overrides={['Layout/FontProfiles']={face=function(f,w,v)local k=tostring(f)..':'..tostring(w)..':'..tostring(v);faces[k]=faces[k]or{Family=f,Weight=w,Style=v};return faces[k]end},['Layout/TextMeasure']={measure=function(t,_,s)return{X=#t*s/2,Y=s}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
 local function near(a,b,label)assert(type(a)=='number'and math.abs(a-b)<.08,label..': '..tostring(a)..' != '..tostring(b))end
 local function id(n)return n and n.Attributes and n.Attributes.id end
 local function mount(html)
  local doc=Parser.parseDocument(html..'<input id="retainedEditor" tabindex="-1" value="A&#x1f600;BC"><script>var mapMounted=true;</script>');local root=factory.create('ScrollingFrame',nil,{});root:SetAttribute('Status','ready')
  local messages={};local function diagnostic(m)table.insert(messages,m)end
  local resolutions=0;local function resolveImage(src)resolutions+=1;return if src=='data:image/png,invalid'then nil else'rbxassetid://12345'end
  local tree=renderer.build(doc,root,diagnostic,overrides['Layout/FontProfiles'].face,nil,nil,resolveImage);tree.ViewportHeight=600
  local realm,flushing=nil,false;local pending,targets=false,{};local arrangements=0
  local page={Alive=true,Document=doc,DocumentURL='https://maps.test/page',BaseURL='https://maps.test/page',Root=root,Cleanups={},Navigation={}}
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  function page:GeometryViewport()return{Width=800,Height=600,ClientWidth=800,ClientHeight=600,ScrollWidth=800,ScrollHeight=600,ScrollX=0,ScrollY=0}end
  function page:HasPendingLayout()return pending end
  page.Navigate=function(url,node,data)table.insert(page.Navigation,{URL=url,Node=node,Data=data})end
  page:AddCleanup(function()tree.ImageMapIndex:Destroy()end)
  local function arrange(items)arrangements+=1;Dirty.begin(tree,items);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)end
  function page:FlushScriptLayout()
   if flushing or not realm then return end;flushing=true;local needed,items=realm:Flush()
   if pending then needed=true;items=items or{};for item in targets do items[item]=true end;pending=false;table.clear(targets)end
   if needed then arrange(items)end;flushing=false
  end;arrange()
  local hitImage,point=nil,nil
  local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),MouseEnabled=true,MouseIcon='',MouseIconEnabled=true}
  function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode(k)return k.Name end;function input:GetMouseLocation()return point end
  local stop=Controller.start(page,tree,function(_,item)pending=true;if item then targets[item]=true end end,diagnostic,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()
   local list={};local item=hitImage and tree.ImageMapItems[hitImage];if item then table.insert(list,item.BoxGui)end
   local stage=Node.findById(doc,'stage');local box=stage and tree.NodeBoxes[stage];if box then table.insert(list,box.Gui)end
   return list
  end},Factory=factory,Clock=os.clock,PickerLayout=layout})
  local runService={RenderStepped=signal(),Heartbeat=signal()};local timers={};local tasks={delay=function(_,fn)local h={Callback=fn,CancelCount=0};table.insert(timers,h);return h end,cancel=function(h)h.CancelCount+=1;assert(h.CancelCount==1,'Map timer cancelled twice')end}
  realm=assert(HTMLScripts.start(page,tree,function()end,diagnostic,{JavaScriptServices={Clock=os.clock,RunService=runService,Task=tasks}}));page.JavaScriptRuntime=realm
  local control=page.FormModel:Resolve(Node.findById(doc,'retainedEditor'));local editor=control.Item.Editor;local bindings=editor:ConnectionCount()
  local function settle()
   for _=1,16 do page:FlushScriptLayout();realm:AfterLayout();local jobs=realm:PumpTasks();if not realm:HasPending()and jobs==0 and not pending then break end end;page:FlushScriptLayout()
   -- The native contrast uses map cursor:wait. That existing unsupported
   -- cursor keyword is unrelated to the virtual shape's IMG inheritance.
   for _,m in messages do assert(m:match('^No image mapping for src:')or m=='Unsupported style: cursor: wait',m)end;assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))
  end
  local function run(code)assert(realm:Run(code),code..' '..table.concat(realm.Diagnostics,' | '));settle()end
  run('var image=document.getElementById("image"),stage=document.getElementById("stage"),mapA=document.getElementById("mapA"),mapB=document.getElementById("mapB"),areaA=document.getElementById("areaA"),areaB=document.getElementById("areaB"),dead=document.getElementById("dead"),subject=document.getElementById("subject"),firstDefault=document.getElementById("firstDefault"),lastDefault=document.getElementById("lastDefault");var retainedEditor=document.getElementById("retainedEditor");retainedEditor.focus();retainedEditor.setSelectionRange(1,3,"backward");var mapClicks=[];document.addEventListener("click",function(e){mapClicks.push({target:e.composedPath()[0].id,trusted:e.isTrusted});if(globalThis.cancelMapClick!==false)e.preventDefault()},true)')
  local image=Node.findById(doc,'image');local old=tree.ImageMapItems[image];local oldBox=old and old.BoxGui;local oldPaint=old and old.ImageGui
  local events={};local observer=page.Events:BeforeEmit(function(e)if e.Type=='click'or e.Type=='pointerdown'or e.Type=='pointerup'then table.insert(events,{Type=e.Type,Target=e.Target})end end)
  local refreshes=0;local oldRefresh=tree.RefreshImageResource;function tree:RefreshImageResource(...)refreshes+=1;return oldRefresh(self,...)end
  local function retained(imageToo,focusToo)
   assert(control.Item.Editor==editor and not editor.Destroyed and editor:ConnectionCount()==bindings,'Map recreated/rebound editor')
   assert(control.Value=='A😀BC'and control.SelectionStart==1 and control.SelectionEnd==3 and control.SelectionDirection=='backward','Map lost value/UTF16 selection')
   if focusToo then assert(focused==editor and editor.CursorPosition==2 and editor.SelectionStart==6,'Map lost native focus/byte selection')end
   if imageToo and old then assert(tree.ImageMapItems[image]==old and old.BoxGui==oldBox and old.ImageGui==oldPaint and not oldBox.Destroyed,'Map data recreated image')end
  end
  local function put(probe,n)
   hitImage=n or Node.findById(doc,'image')or image;local item=assert(tree.ImageMapItems[hitImage],'Missing retained image');local r=probe.rect
   item.BoxGui.AbsolutePosition=Vector2.new(r.x,r.y);item.BoxGui.AbsoluteSize=Vector2.new(r.w or r.width,r.h or r.height);point=Vector2.new(r.x+probe.point[1],r.y+probe.point[2])
  end
  local function mouse(kind)input[kind]:Fire({UserInputType=if kind=='InputChanged'then Enum.UserInputType.MouseMovement else Enum.UserInputType.MouseButton1,Position=point});settle()end
  local function click(p)put(p);table.clear(events);table.clear(page.Navigation);run('mapClicks.length=0');mouse('InputChanged');mouse('InputBegan');mouse('InputEnded');return events end
  local function key(code)local e={UserInputType=Enum.UserInputType.Keyboard,KeyCode=code};input.InputBegan:Fire(e);input.InputEnded:Fire(e);settle()end
  local function dispose()
   run('setTimeout(function(){throw new Error("Disposed map timer")},100000);requestAnimationFrame(function(){throw new Error("Disposed map frame")})');assert(realm.EventLoop.TimerCount==1 and realm.EventLoop.FrameCount==1,'Disposal needs real jobs')
   observer:Disconnect();realm:Destroy();stop();page.Alive=false;for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end;tree.ImageMapIndex:Destroy()
   assert(next(tree.ImageMapItems)==nil and next(tree.ImageMapIndex.Roots)==nil and next(tree.ImageMapIndex.Owners)==nil and next(tree.ImageMapIndex.Snapshots)==nil,'Retained tree kept map/image/area index after disposal')
   assert(input.InputBegan:Count()==0 and input.InputChanged:Count()==0 and input.InputEnded:Count()==0 and input.WindowFocusReleased:Count()==0 and editor:ConnectionCount()==0,'Map leaked input/editor bindings')
   assert(not realm.Alive and not realm.EventLoop.Alive and realm.EventLoop.TimerCount==0 and realm.EventLoop.FrameCount==0 and realm.EventLoop.TaskCount==0 and not realm:HasPending(),'Map jobs survived disposal')
   assert(not page.ScriptClock.Alive and runService.RenderStepped:Count()==0 and runService.Heartbeat:Count()==0,'Map clock survived disposal');for _,h in timers do assert(h.CancelCount==1,'Map timer not cancelled')end;assert(input.MouseIcon=='','Map cursor lease survived disposal')
  end
  return{Run=run,Settle=settle,Put=put,Mouse=mouse,Click=click,Key=key,Retained=retained,Dispose=dispose,Page=page,Tree=tree,Document=doc,Events=events,Input=input,Counts=function()return tree.ImageMapIndex.Scans,resolutions,refreshes,arrangements,#objects end}
 end
 local states,probes,normDeltas=0,0,0
 for _,c in reference.cases do
  local host=mount(c.html)
  for step,state in c.steps do
   if state.action~=''then host.Run(state.action)end;host.Retained(c.name~='shadow root association',false)
   for i,p in state.probes do
    local wanted=expected(c,step,i);local clicked;for _,e in host.Click(p)do if e.Type=='click'then clicked=e.Target end end
    assert(id(clicked)==wanted,c.name..' '..state.label..' actual pointer '..tostring(id(clicked))..' != '..tostring(wanted));assert(#host.Page.Navigation==0,'Prevented click navigated')
    host.Run('if(mapClicks.length!==1||mapClicks[0].target!=='..string.format('%q',wanted)..'||!mapClicks[0].trusted)throw new Error("Actual trusted JS image-map click")');probes+=1
   end;states+=1
  end;host.Dispose()
 end
 assert(states==82 and probes==139,'Every primary native state/probe must run')
 for _,d in reference.normative.defaultPrecedence do
  local counterpart;for _,c in reference.supplement.defaultCounterparts do if c.name==d.case and c.step==d.step then counterpart=c;break end end
  assert(counterpart,'Missing independent full-rect counterpart');local host=mount(counterpart.html)
  for i,p in counterpart.probes do
   assert(p.events[1].target==d.targets[i]and p.events[1].trusted,'Native finite counterpart contradicts frozen default');local clicked;for _,e in host.Click(p)do if e.Type=='click'then clicked=e.Target end end
   assert(id(clicked)==p.events[1].target,'Engine finite counterpart');normDeltas+=1
  end;host.Dispose()
 end
 for _,c in reference.supplement.geometry do
  local host=mount(c.html);for _,p in c.probes do
   local clicked;for _,e in host.Click(p)do if e.Type=='click'then clicked=e.Target end end;assert(id(clicked)==p.events[1].target,'Loaded/broken border origin')
   local item=host.Tree.ImageMapItems[Node.findById(host.Document,'image')];local box=host.Tree.NodeBoxes[item.Node];near(box.OuterWidth,p.rect.width,'Border CSS width');near(box.OuterHeight,p.rect.height,'Border CSS height')
  end;host.Dispose()
 end
 local function active(h)return id(h.Page.FormModel:GetActiveElement())end
 local function keyboard(h,s)
  if s.action~=''then h.Run(s.action)end;h.Run('document.getElementById("before").focus();mapClicks.length=0');table.clear(h.Events)
  -- The third native Tab leaves page focus for browser chrome/body. The
  -- existing Roblox in-page wrap is separate from shape eligibility/order.
  for i=1,2 do if s.focused[i]=='body'then break end;h.Key(Enum.KeyCode.Tab);assert(active(h)==s.focused[i],s.label..' Tab '..i..': '..tostring(active(h))..' != '..s.focused[i]);if i==1 then h.Key(Enum.KeyCode.Return)end end
  local clicks={};for _,e in h.Events do if e.Type=='click'and(e.Target.LocalName or e.Target.Name)=='area'then table.insert(clicks,id(e.Target))end end
  local native={};for _,e in s.events do if e.target:match('^area')then table.insert(native,e)end end
  assert(#clicks==#native,s.label..' area Enter count');for i,e in native do assert(clicks[i]==e.target,s.label..' area Enter target')end
 end
 local h=mount(reference.keyboardHTML);for _,s in reference.keyboard do keyboard(h,s)end;h.Dispose()
 for _,c in reference.supplement.focusOrder do
  local host=mount(c.html);host.Run('document.getElementById("before").focus()');for i,wanted in c.focused do if wanted=='body'then break end;host.Key(Enum.KeyCode.Tab);assert(active(host)==wanted,c.name..' raw area-placement order '..i)end;host.Dispose()
 end
 for _,c in reference.downMutation do
  local host=mount(reference.downMutationHTML);host.Put({point={30,30},rect={x=220,y=180,w=192,h=128}});host.Mouse('InputChanged');table.clear(host.Events);host.Mouse('InputBegan');host.Run(c.action);host.Mouse('InputEnded')
  assert(#host.Events==#c.events,c.label..' down mutation count');for i,e in c.events do assert(host.Events[i].Type==e.type and id(host.Events[i].Target)==e.target,c.label..' down mutation '..i..' '..host.Events[i].Type..' '..tostring(id(host.Events[i].Target)))end;host.Dispose()
 end
 -- Mutation-only work keeps focus, UTF16/byte selection and image paint. A
 -- source refresh spy distinguishes retained identity from needless refresh.
 do
  local host=mount(inventory['live association'].html)
  local _,resolved,resources,arranged,allocated=host.Counts()
  for _,code in {'image.useMap="#b"','mapB.name="renamed"','mapB.id="renamed"','image.useMap="https://example.test/#renamed"','areaB.coords="0,0,120,90"','areaB.shape="rect"','areaB.href="#changed"','areaB.removeAttribute("href")','areaB.href="#restored"','mapB.append(areaB)'}do
   host.Run(code);host.Retained(true,true)
   local _,r,s,a,g=host.Counts();assert(r==resolved and s==resources and a==arranged and g==allocated,'Map-only mutation refreshed resources/layout/GUI: '..code)
  end
  local scans=host.Counts();local focusScans=0;local original=host.Page.RefreshDOMFocus
  function host.Page:RefreshDOMFocus(...)focusScans+=1;return original(self,...)end
  for _=1,4 do host.Run('stage.style.color="red"');host.Retained(true,true)end
  local after,r,s,a,g=host.Counts();assert(after==scans and focusScans==0 and r==resolved and s==resources and a==arranged and g==allocated,'Irrelevant paint rescanned maps/focus or rebuilt geometry')
  host.Run('var status=document.createElement("div");status.id="status";stage.append(status)');local statusScans=host.Counts()
  for _,code in {'status.textContent="Counter 1"','status.textContent="Counter 2"','status.append(document.createTextNode(" extra"))','status.lastChild.remove()'}do
   host.Run(code);assert(host.Counts()==statusScans,'Ordinary counter/text mutation rescanned associations: '..code);host.Retained(true,true)
  end
  -- Keep references deliberately, and prove the live index releases them on
  -- mutation, not only when the whole page/index is eventually destroyed.
  local removed=Node.findById(host.Document,'areaB');host.Run('areaB.remove()')
  assert(host.Tree.ImageMapIndex.Owners[removed]==nil and host.Tree.ImageMapIndex.Snapshots[removed]==nil,'Removed area retained in live index')
  local map=Node.findById(host.Document,'mapB');host.Run('mapB.remove()')
  for _,maps in host.Tree.ImageMapIndex.Roots do for _,value in maps do assert(value~=map,'Removed map kept in root cache')end end
  local image=Node.findById(host.Document,'image');local item=host.Tree.ImageMapItems[image];host.Run('image.remove()')
  assert(host.Tree.ImageMapItems[image]==nil and item.ImageMap==nil and item.ImageNode==nil,'Removed image kept association')
  host.Dispose()
 end
 for _,c in reference.supplement.visibility do
  local host=mount(c.html);if c.action~=''then host.Run(c.action)end
  local clicked;for _,e in host.Click(c.probe)do if e.Type=='click'then clicked=e.Target end end
  assert((id(clicked)or'')==c.probe.events[1].target,c.name..' actual pointer visibility/inert target '..tostring(id(clicked)))
  keyboard(host,{label=c.name,action='',focused=c.focused,events=c.events});host.Dispose()
 end
 do
  local host=mount(reference.supplement.imgTabIndexHTML);host.Run('image.tabIndex=0')
  local names={'mapped IMG tabindex','unmapped IMG tabindex'};assert(#reference.supplement.imgTabIndex==#names,'IMG tabindex inventory')
  for i,c in reference.supplement.imgTabIndex do
   assert(c.name==names[i],'IMG tabindex case name')
   if c.action~=''then host.Run(c.action)end;host.Run('document.getElementById("before").focus()')
   for i,wanted in c.focused do host.Key(Enum.KeyCode.Tab);assert(active(host)==wanted,c.name..' preserved generic IMG focus '..i)end
  end;host.Dispose()
 end
 do
  -- Unknown manual Children and bounded-wide edits must remain conservative.
  local doc=Parser.parseDocument('<div id="stage"></div>');local stage=Node.findById(doc,'stage');local index=ImageMap.new(doc,{})
  assert(index:Prepare({[stage]={Children=true}}),'Unknown Children lost conservative association invalidation')
  local wide=Node.element('div',{});for _=1,257 do Node.append(wide,Node.element('span',{}))end
  index:Mutation({Type='childList',Target=stage,AddedNodes={wide},RemovedNodes={}})
  assert(index.Mutations[stage].Relevant and not index.Mutations[stage].PureData,'Wide subtree did not take bounded conservative fallback')
  assert(index:Prepare({[stage]={Children=true}})and next(index.Mutations)==nil,'Wide mutation dirty metadata not consumed');index:Destroy()
 end
 for _,shadow in {false,true}do
  local host=mount(inventory['live association'].html)
  if shadow then host.Run('var scopeHost=document.createElement("div");stage.append(scopeHost);var scope=scopeHost.attachShadow({mode:"open"});scope.append(image);scope.append(mapA)')
  else host.Run('var scope=stage')end
  for _,entry in {
   {'nested MAP/IMG insert','var nestedContainer=document.createElement("div");nestedContainer.innerHTML="<div><map id=nestedMap name=a><area id=nestedHit shape=rect coords=0,0,192,128 href=#nested></map><img id=nestedImage src=asset usemap=#a></div>";scope.prepend(nestedContainer)','nestedHit'},
   {'nested MAP reorder','scope.append(nestedContainer)','areaA'},
   {'nested MAP/IMG remove','nestedContainer.remove()','areaA'},
  }do
   host.Run(entry[2]);host.Retained(true,true)
   -- Use the retained initial image in either light or shadow scope.
   host.Run('if(image.useMap!=="#a")throw new Error("Scope image changed")')
   local oldImage;for image,item in host.Tree.ImageMapItems do if id(image)=='image'then oldImage=image;break end end
   local probe={point={30,30},rect={x=220,y=180,w=192,h=128}};host.Put(probe,oldImage)
   local target=ImageMap.hit(host.Tree.ImageMapItems,oldImage,Vector2.new(250,210));assert(id(target)==entry[3],entry[1]..' '..tostring(shadow)..' association')
   table.clear(host.Events);host.Run('mapClicks.length=0');host.Mouse('InputChanged');host.Mouse('InputBegan');host.Mouse('InputEnded')
   local clicked;for _,e in host.Events do if e.Type=='click'then clicked=id(e.Target)end end
   assert(clicked==entry[3],entry[1]..' actual Controller route '..tostring(shadow))
   host.Run('retainedEditor.focus();retainedEditor.setSelectionRange(1,3,"backward")')
  end
  host.Dispose()
 end
 do
  local html=inventory['live association'].html:gsub('<area id="areaA" shape="default" href="#a">','<div id="nested"><area id="areaA" shape="default" href="#a"></div>')
  local host=mount(html);local _,r,s,a,g=host.Counts();local nested=host.Tree.NodeBoxes[Node.findById(host.Document,'nested')];local gui=nested.Gui
  for _,code in {'var nested=document.getElementById("nested");nested.insertAdjacentHTML("afterbegin","<area id=nestedArea shape=rect coords=0,0,60,60 href=#nested>")','nested.append(areaA)','document.getElementById("nestedArea").remove()'}do
   host.Run(code);host.Retained(true,true);local _,nextR,nextS,nextA,nextG=host.Counts()
   assert(nextR==r and nextS==s and nextA==a and nextG==g and nested.Gui==gui and not gui.Destroyed,'Nested pure area mutation rebuilt visible map child/image/resources')
  end;host.Dispose()
 end
 for _,c in reference.supplement.navigation do
  local host=mount(reference.supplement.visibility[1].html);host.Run('cancelMapClick=false')
  if c.action~=''then host.Run(c.action)end
  if c.keyboard then host.Run('document.getElementById("before").focus()');host.Key(Enum.KeyCode.Tab);host.Key(Enum.KeyCode.Return)
  else host.Click({point={30,30},rect={x=210,y=184,w=192,h=128}})end
  if c.value.hash~=''then assert(#host.Page.Navigation==1 and host.Page.Navigation[1].URL=='https://maps.test/page#destination','Actual fragment Navigate callback')
  else assert(#host.Page.Navigation==0,'Dead/prevented area navigated')end;host.Dispose()
 end
 do
  local names={'scripted area navigate','scripted area cancelled','scripted area empty href','scripted area missing href','scripted prefixed HTML area','scripted anchor navigate','scripted prefixed HTML anchor'}
  assert(#reference.supplement.scriptedClicks==#names,'Scriptclick inventory')
  for i,c in reference.supplement.scriptedClicks do
   assert(c.name==names[i]and #c.events==1 and c.events[1].trusted==false,'Native scriptclick case/trust '..c.name)
   local host=mount(c.html);host.Run('cancelMapClick=false');if c.setup~=''then host.Run(c.setup)end
   table.clear(host.Events);host.Run('mapClicks.length=0');host.Run(c.action)
   assert(#host.Events==1 and host.Events[1].Type=='click'and id(host.Events[1].Target)==c.events[1].target,c.name..' exact event target/count')
   host.Run('if(mapClicks.length!==1||mapClicks[0].trusted!==false||mapClicks[0].target!=='..string.format('%q',c.events[1].target)..')throw new Error("Scriptclick trust/count")')
   if c.hash=='#initial'then assert(#host.Page.Navigation==0,c.name..' unexpectedly navigated')
   else assert(#host.Page.Navigation==1 and host.Page.Navigation[1].URL=='https://maps.test/page'..c.hash,c.name..' callback URL')end
   host.Retained(true,true);host.Dispose()
  end
 end
 do
  local host=mount(reference.supplement.mapChildren[1].html)
  local function painted(item)
   local gui=item.Gui;while gui do if gui.Visible==false or gui.Destroyed then return false end;if gui==host.Page.Root then return true end;gui=gui.Parent end;return false
  end
  for _,c in reference.supplement.mapChildren do
   if c.action~=''then host.Run(c.action)end
   host.Retained(false,true)
   local native;for _,b in c.value.boxes do if b.id=='block'then native=b end end
   local block=host.Tree.NodeBoxes[Node.findById(host.Document,'block')]
   local hidden=c.value.boxes[2].display=='none'
   if not hidden then assert(block and block.OuterHeight==native.rect[4],'Transparent map block child not laid out')end
   local inline=false
   for _,item in host.Tree.TextItems do if item.Text and item.Text:find('inline',1,true)and painted(item)then inline=true end end
   assert(inline~=hidden,'Transparent map ordinary inline child visibility '..c.label)
   assert(host.Tree.NodeBoxes[Node.findById(host.Document,'areaA')]==nil,'Area unexpectedly produced a layout box')
  end
  host.Run('mapA.append(document.createTextNode("ordinary added"))')
  local found=false;for _,item in host.Tree.TextItems do if item.Text and item.Text:find('ordinary',1,true)and painted(item)then found=true end end
  assert(found,'Map metadata classifier discarded real ordinary text mutation');host.Dispose()
 end
 do
  local host=mount(reference.supplement.cursorHTML)
  local values={'crosshair','help','move','auto','crosshair'}
  local icons={crosshair='rbxassetid://104078440525685',help='rbxassetid://87260447178915',move='rbxassetid://99178097326370',auto='rbxassetid://115026529201803'}
  for i,c in reference.supplement.cursor do
   if c.action~=''then host.Run(c.action)end
   host.Put(c.probe);host.Mouse('InputChanged')
   assert(host.Input.MouseIcon==icons[values[i]],c.name..' independent shape cursor '..tostring(host.Input.MouseIcon))
   local count=host.Tree.ImageMapIndex.CursorResolves;local scans=host.Counts()
   for _=1,8 do host.Mouse('InputChanged')end
   assert(host.Tree.ImageMapIndex.CursorResolves==count and host.Counts()==scans,'Unchanged mouse move repeated cursor cascade or map scan')
  end
  host.Run('areaA.removeAttribute("style");areaA.className="hover"');host.Mouse('InputChanged');assert(host.Input.MouseIcon==icons.help,'Actual hover cursor recascade')
  local area=Node.findById(host.Document,'areaA');host.Run('areaA.remove()')
  assert(not host.Tree.ImageMapIndex.Cursor or host.Tree.ImageMapIndex.Cursor.Area~=area,'Removed shape kept last cursor cache')
  host.Dispose();assert(host.Tree.ImageMapIndex.Cursor==nil,'Disposed tree kept cursor cache')
 end
 do
  local names={'inert IMG ancestor cursor','inert stage body cursor'};local icons={'rbxassetid://87260447178915','rbxassetid://115026529201803'}
  assert(#reference.supplement.inertCursor==#names,'Inert cursor inventory')
  for i,c in reference.supplement.inertCursor do
   assert(c.name==names[i],'Inert cursor case');local host=mount(c.html);host.Run(c.action)
   host.Put(c.probe);host.Mouse('InputChanged');assert(host.Input.MouseIcon==icons[i],c.name..' native-target cursor lease')
   local target;for _,e in host.Click(c.probe)do if e.Type=='click'then target=id(e.Target)or''end end
   assert(target==c.probe.events[1].target,c.name..' native target')
   assert(host.Tree.ImageMapIndex.Cursor==nil,'Inert ancestor was cached as a virtual AREA');host.Dispose()
  end
 end
 print('Image maps: '..states..' retained native states, '..probes..' actual pointer controls, '..normDeltas..' independent frozen-default counterparts; Tab/Enter, press mutations, border geometry, map children, visibility/inert, navigation, retained focus/resources, warm cursor and disposal passed')
end
