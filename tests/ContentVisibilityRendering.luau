--!strict
-- Native state transitions plus retained native GUI/resource/input invariants.
-- This does not accept offscreen auto skipping, all containment sizing or Studio FPS.
return function(Parser,Node,Dirty,Controller,HTMLScripts,HitTest,BoxTransform,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local function signal()
  local listeners={};local s={}
  function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
  function s:Fire(...)for _,v in table.clone(listeners)do if v[1].Connected then v[2](...)end end end
  function s:Count()local n=0;for _,v in listeners do if v[1].Connected then n+=1 end end;return n end
  return s
 end
 local function visible(gui)
  local visited={}
  while gui do assert(not visited[gui],'Content host formed a GUI cycle');visited[gui]=true;if gui.Visible==false then return false end;gui=gui.Parent end
  return true
 end
 local comparisons,normativeCorrections,hostCorrections=0,0,0
 local face={Family='Arial',Weight=400,Style='normal'}
 local overrides={['Layout/FontProfiles']={face=function()return face end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=#require('Layout/LetterSpacing').split(text)*size/2,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local function mount(source)
  local focused;local surfaces,deferred={},{};local factory={}
  function factory.create(class,parent,props)
   local changes,attributes={},{}
   local values={Parent=parent,ClassName=class,Visible=true,AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(800,600),AbsoluteWindowSize=Vector2.new(800,600),Text='',CursorPosition=-1,SelectionStart=-1}
   for k,v in props do values[k]=v end;if class=='ScrollingFrame'then values.CanvasPosition=Vector2.new(0,0)end
   local gui;gui=setmetatable({},{__index=values,__newindex=function(_,k,v)assert(k~='Parent'or v~=gui,'GUI self-parent');local old=values[k];values[k]=v;if old~=v and changes[k]then changes[k]:Fire()end end})
   values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
   function values:GetPropertyChangedSignal(k)changes[k]=changes[k]or signal();return changes[k]end
   function values:GetAttributeChangedSignal(k)return self:GetPropertyChangedSignal('attribute:'..k)end
   function values:SetAttribute(k,v)attributes[k]=v end;function values:GetAttribute(k)return attributes[k]end
   function values:IsA(k)return k==class or(k=='GuiObject'and class~='ScreenGui')end
   function values:IsFocused()return focused==gui end
   function values:CaptureFocus()if focused==gui then return end;if focused then focused:ReleaseFocus()end;focused=gui;gui.CursorPosition=1;self.Focused:Fire()end
   function values:ReleaseFocus()if focused==gui then focused=nil;gui.CursorPosition=-1;gui.SelectionStart=-1;self.FocusLost:Fire(false)end end
   function values:Destroy()if values.Destroyed then return end;values.Destroyed=true;if focused==gui then gui:ReleaseFocus()end;for _,child in surfaces do if child.Parent==gui and not child.Destroyed then child:Destroy()end end;gui.Parent=nil end
   table.insert(surfaces,gui);return gui
  end
  factory.modifier=factory.create
  local doc=Parser.parseDocument(source);local layer=factory.create('ScreenGui',nil,{});local root=factory.create('ScrollingFrame',layer,{ClipsDescendants=true});root:SetAttribute('Status','ready')
  local messages={};local function diagnostic(m)table.insert(messages,m)end
  local imageResolves=0;local tree=loadRenderTree(factory).build(doc,root,diagnostic,function()return face end,nil,nil,function(url)imageResolves+=1;assert(url=='asset:picture');return 'rbxassetid://12345'end)
  tree.ViewportHeight=600;local realm,flushing,pending=nil,false,false;local targets={}
  local function arrange(items)Dirty.begin(tree,items);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)end
  arrange()
  local page={Alive=true,Document=doc,DocumentURL='https://visibility.test/',BaseURL='https://visibility.test/',Root=root,Cleanups={}}
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  function page:GeometryViewport()return{Width=800,Height=600,ClientWidth=800,ClientHeight=600,ScrollWidth=800,ScrollHeight=600,ScrollX=0,ScrollY=0}end
  function page:HasPendingLayout()return pending end
  function page:FlushScriptLayout()
   if flushing or not realm then return end;flushing=true;local needed,items=realm:Flush()
   if pending then needed=true;items=items or{};for box in targets do items[box]=true end;pending=false;table.clear(targets)end
   if needed then arrange(items)end;flushing=false
  end
  local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
  function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end
  local taskAPI={defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return{Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}
  local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=os.clock,Task=taskAPI,RunService={RenderStepped=signal(),Heartbeat=signal()}}
  Controller.start(page,tree,function(_,box)pending=true;if box then targets[box]=true end end,diagnostic,services)
  realm=assert(HTMLScripts.start(page,tree,function()end,diagnostic,{JavaScriptServices=services}));page.JavaScriptRuntime=realm
  local api={Tree=tree,Document=doc,Page=page,Surfaces=surfaces,Resolves=function()return imageResolves end}
  function api:Run(code)
   local ok,err=realm:Run(code);assert(ok,tostring(err)..' | '..code)
   for _=1,24 do page:FlushScriptLayout();realm:AfterLayout();if realm.SelectionAdapter then realm.SelectionAdapter:AfterLayout()end;local tasks=deferred;deferred={};for _,fn in tasks do fn()end;if #deferred==0 and realm:PumpTasks()==0 and not pending and not realm:HasPending()then break end end
   assert(#messages==0,table.concat(messages,' | '));assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))
  end
  function api:Key(key)
   local event={UserInputType=Enum.UserInputType.Keyboard,KeyCode=key}
   input.InputBegan:Fire(event,false);input.InputEnded:Fire(event);self:Run('void 0')
  end
  function api:Box(id)return tree.NodeBoxes[Node.findById(doc,id)]end
  function api:Editor()return page.FormModel:Resolve(Node.findById(doc,'editor'))end
  function api:Snapshot(expected)
   local owner=self:Box('owner');assert(owner and owner.Gui.Visible~=false and owner.OuterWidth==expected.items.owner.rect[3]and owner.OuterHeight==expected.items.owner.rect[4],'Skipping changed the fixed owner border box')
   local hidden=owner.Style.ContentVisibility=='hidden';assert((owner.HiddenContents==true)==hidden,'Content participation disagrees with computed hidden state')
   if hidden then assert(#owner.Children==0 and owner.ContentHost and owner.ContentHost.Visible==false)end
   if owner.ContentsBuilt then
    local c=self:Editor();assert(c and c.Value==expected.editor.value and c.SelectionStart==expected.editor.start and c.SelectionEnd==expected.editor['end'],'UTF16/editor state changed')
    assert((page.FormModel:GetActiveElement()==c.Node)==(expected.active=='editor'),'Hidden/focus state disagrees with native browser: '..expected.name)
    assert(visible(c.Item.Gui)==not hidden,'Editor paints while skipped or stays hidden after reveal: '..expected.name)
    local fixed=self:Box('fixed');local hit=HitTest.pick({fixed.Gui},tree.HitNodes,root,nil,tree.HitStyles)
    assert((hit==fixed.Node)==(expected.fixedHit=='fixed'),'Escaped fixed box hit-testing disagrees with native browser: '..expected.name)
    for _,item in tree.TextItems do
     if item.Style and item.Style.Node and tree:IsContentSkipped(item.Style.Node)then assert(not visible(item.Gui),'A hidden descendant word escaped its passive content host')end
    end
    local details=tree.Disclosures[Node.findById(doc,'details')]
    if hidden then assert(not visible(details.Body.Gui))elseif details.Open then assert(visible(details.Body.Gui))else assert(not visible(details.Body.Gui))end
   else assert(self:Box('inside')==nil and self:Box('fixed')==nil and self:Editor()==nil and imageResolves==0,'Initially hidden contents were allocated eagerly')end
   for _,gui in surfaces do if not gui.Destroyed then visible(gui)end end
   comparisons+=1
  end
  function api:Copy()
   local text=Node.findById(doc,'inside').Children[1];return realm.SelectionAdapter:CopyText(text,0,text,#text.Text,false)
  end
  function api:SelectionPaints()
   local count=0;for _,overlay in tree.TextSelection.Overlays do assert(not overlay.Frame.Destroyed);if visible(overlay.Frame)then count+=1 end end;return count
  end
  function api:Dispose()
   for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end;page.Alive=false;layer:Destroy()
   assert(tree.ContentVisibilityChanged==nil,'Content-visibility input hook leaked')
   for _,gui in surfaces do if gui.ClassName=='TextBox'then assert(gui.Destroyed and gui:GetPropertyChangedSignal('Text'):Count()==0 and gui:GetPropertyChangedSignal('CursorPosition'):Count()==0,'Editor binding survived disposal')end end
  end
  return api
 end
 local live=mount(reference.source);local editor=live:Editor().Item.Editor;local inside=live:Box('inside').Gui;local image=live.Tree.ImageItems[1]
 assert(live.Resolves()==1)
 for _,state in reference.states do
  live:Run(state.operation);live:Snapshot(state)
  assert(live:Editor().Item.Editor==editor and not editor.Destroyed and live:Box('inside').Gui==inside,'Hide/reveal recreated retained surfaces')
  assert(live.Tree.ImageItems[1]==image and not image.Gui.Destroyed and live.Resolves()==1,'Hide/reveal recreated or re-resolved an image')
  if state.name=='select'or state.name=='selection-hidden'or state.name=='selection-restored'then
   assert(live:Copy()==state.selection,'Rendered copying disagrees with native hidden selection: '..state.name)
   assert((live:SelectionPaints()>0)==(state.selection~=''),'Selection overlays paint skipped text or fail to return')
  end
 end
 live:Dispose()
 local deferred=mount(reference.source:gsub('<div id=owner tabindex=0>','<div id=owner tabindex=0 style="content-visibility:hidden">'))
 for _,state in reference.deferred do
  deferred:Run(state.operation);deferred:Snapshot(state)
  if state.name=='first-reveal'or state.name=='second-reveal'then
   local text=Node.findById(deferred.Document,'inside').Children[1];assert(text.Text=='OP QR'and deferred:Copy()=='OP QR','Deferred contents used stale DOM')
   assert((deferred:Box('inserted')~=nil)==(state.items.inserted~=nil),'Hidden insert/remove left stale render boxes')
  end
 end
 deferred:Dispose()
 for _,case in reference.extra do
  local liveExtra=mount(case.source);local retained
  for _,state in case.states do
   liveExtra:Run(state.operation);if state.key then liveExtra:Key(Enum.KeyCode[state.key])end;local owner=liveExtra:Box('owner');local r=state.items.owner.rect
   -- Chromium still skips table cells, although the current Contain 2
   -- applicability rule excludes internal table boxes. Keep both raw states
   -- and their explicit normative correction; never rewrite the capture.
   local cellDelta=case.name=='table-cell'and(state.name=='initial'or state.name=='hide')
   if cellDelta then assert(r[4]==20 and state.insideHit=='owner','The preserved native table-cell discrepancy changed');normativeCorrections+=1 end
   local height=if cellDelta then 35 else r[4]
   assert(math.abs(owner.OuterWidth-r[3])<.01 and math.abs(owner.OuterHeight-height)<.01,case.name..' '..state.name..' owner dimensions: '..tostring(owner.OuterWidth)..'x'..tostring(owner.OuterHeight)..' vs '..r[3]..'x'..height)
   if owner.HiddenContents then assert(#owner.Children==0 and not owner.ContentHost.Visible)
   else
    local inside=liveExtra:Box('inside');assert(inside and visible(inside.Gui),case.name..' reveal failed')
    local hit=HitTest.pick({inside.Gui},liveExtra.Tree.HitNodes,liveExtra.Page.Root,nil,liveExtra.Tree.HitStyles)
    assert(hit==inside.Node and(cellDelta or state.insideHit=='inside'),'Effective table/details hit disagrees with its applicability rule')
    if retained then assert(inside.Gui==retained,'Deferred table/details reveal replaced a child')else retained=inside.Gui end
    if owner.TableGrid then assert(#owner.TableGrid.Entries==2 and #owner.Children>0,'Deferred table normalized to a stale/empty grid')end
   end
   if case.name=='fieldset'and not owner.HiddenContents then assert(owner.Legend==liveExtra:Box('inside'),'Deferred fieldset did not register its retained legend')end
   if case.name=='link'or case.name=='link-with-next-control'then
    local expectedActive=state.active
    if case.name=='link'and state.name=='tab-hidden'then
     assert(state.active=='body','The preserved browser-chrome Tab boundary changed');expectedActive='editor';hostCorrections+=1
    end
    local active=liveExtra.Page.FormModel:GetActiveElement();assert((if active then active.Attributes.id else 'body')==expectedActive,'Deferred link keyboard focus disagrees with its native/host profile: '..state.name)
    -- The reference's next state starts after focus left the page for Chrome
    -- UI. Explicitly mirror that host blur after checking Roblox's cycle.
    if case.name=='link'and state.name=='tab-hidden'then liveExtra:Run('document.getElementById("editor").blur()')end
    if not owner.HiddenContents then assert(table.find(liveExtra.Tree.Links,Node.findById(liveExtra.Document,'inside')),'Deferred link did not enter the retained focus index')end
   end
   comparisons+=1
  end
  liveExtra:Dispose()
 end
 print('Content visibility: '..(comparisons-normativeCorrections-hostCorrections)..' native retained/deferred states, '..normativeCorrections..' explicit normative table-cell controls and '..hostCorrections..' separate browser-chrome Tab boundary; GUI, editor UTF16, image identity, nested/details/fieldset, escaped fixed hits, hidden structure, keyboard links, selection and disposal passed')
end
