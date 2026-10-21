--!strict
-- Native cross-size comparisons use captured font advances. They exercise the
-- actual mounted Controller/Runtime path; no native font raster equality claim.
return function(Parser,Node,Dirty,Controller,HTMLScripts,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 assert(reference.metricProfile.fontKerning=='none','The native calibration must explicitly match this scoped no-kerning profile')
 local function signal()
  local entries={};local api={}
  function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
  function api:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
  function api:Count()local n=0;for _,entry in entries do if entry[1].Connected then n+=1 end end;return n end
  return api
 end
 local objects,focused={},nil
 local factory={create=function(class,parent,properties)
  local gui=table.clone(properties or{});gui.ClassName,gui.Parent=class,parent;gui.Visible=true
  gui.AbsolutePosition,gui.AbsoluteSize=Vector2.new(0,0),Vector2.new(800,600)
  if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0)end
  gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local signals,attributes={},{}
  function gui:GetPropertyChangedSignal(key)signals[key]=signals[key]or signal();return signals[key]end
  function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
  function gui:SetAttribute(key,v)attributes[key]=v end;function gui:GetAttribute(key)return attributes[key]end
  function gui:IsA(kind)return kind==class or kind=='GuiObject'end
  function gui:IsFocused()return focused==self end
  function gui:CaptureFocus()if focused==self then return end;local old=focused;focused=self;if old then old.FocusLost:Fire(false)end;self.Focused:Fire()end
  function gui:ReleaseFocus()if focused~=self then return end;focused=nil;self.FocusLost:Fire(false)end
  function gui:ConnectionCount()local n=self.Focused:Count()+self.FocusLost:Count()+self.InputBegan:Count();for _,s in signals do n+=s:Count()end;return n end
  function gui:Destroy()assert(not self.Destroyed,'A cross-size change disposed a retained GUI twice');self.Destroyed=true;self:ReleaseFocus();self.Parent=nil end
  table.insert(objects,gui);return gui
 end};factory.modifier=factory.create
 local measurements,checkEditor=0,nil;local faces={}
 local overrides={['Layout/FontProfiles']={face=function(f,w,v)
  local key=tostring(f)..':'..tostring(w)..':'..tostring(v);faces[key]=faces[key]or{Family=f,Weight=w or 400,Style=v or'normal'};return faces[key]
 end},['Layout/TextMeasure']={measure=function(text,font,size)
  measurements+=1;if checkEditor then checkEditor()end
  local family=if type(font.Family)=='table'then font.Family.Name else font.Family
  family=if family=='Arial'then'Arial'else'monospace'
  local bounds=reference.bounds[family][tostring(size)];assert(bounds and bounds[text]~=nil,'Uncaptured native font advance '..family..' '..size..' '..text)
  return{X=bounds[text],Y=size}
 end}}
 overrides['Layout/FontMetrics']={extents=require('Layout/FontMetrics').extents,resolve=function(s)
  local size=math.ceil(s.FontSize);return{TextSize=size,Baseline=math.round(size*.8),Top=math.round(size*.13),XHeight=math.round(size*.3),Bottom=size,Calibrated=true}
 end}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
 local resolveFont=overrides['Layout/FontProfiles'].face
 local checks,states,fontChecks=0,0,0
 local function near(a,b,label)assert(math.abs(a-b)<.08,label..': '..tostring(a)..' != '..tostring(b))end
 local function geometry(tree)
  local out={};local visited={};local function visit(box)
   if visited[box]then return end;visited[box]=true
   local keys={'LayoutX','LayoutY','OuterWidth','OuterHeight','ContentWidth','ContentHeight','OwnBottom','FirstBaseline'}
   for _,key in keys do if type(box[key])=='number'then table.insert(out,key..':'..tostring(box[key]))end end
   for _,item in box.Items or{}do for _,key in {'X','Y','Width','Height','LineIndex'}do if type(item[key])=='number'then table.insert(out,key..':'..tostring(item[key]))end end;if item.InlineBox then visit(item.InlineBox)end end
   for _,child in box.Children or{}do visit(child)end
  end;visit(tree);return table.concat(out,'|')
 end
 local function mount(html,anonymous)
  local document=Parser.parseDocument(html);local root=factory.create('ScrollingFrame',nil,{});root:SetAttribute('Status','ready')
  local messages={};local function diagnostic(m)table.insert(messages,m)end
  local tree=renderer.build(document,root,diagnostic,resolveFont);tree.ViewportHeight=600
  if anonymous then
   assert(Node.findById(document,'caption')==nil,'The native anonymous column fixture must contain no caption element')
   local owner=tree.NodeBoxes[Node.findById(document,'owner')];assert(owner.Children[1].Kind=='Words'and owner.Children[1].Items[1].Text=='ALPHA','The anonymous flex item must be the actual directly owned word run')
  end
  local realm,flushing=nil,false;local pending,targets=false,{}
  local page={Alive=true,Document=document,DocumentURL='https://flex.test/page',BaseURL='https://flex.test/page',Root=root,Cleanups={}}
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  function page:GeometryViewport()return{Width=800,Height=600,ClientWidth=800,ClientHeight=600,ScrollWidth=800,ScrollHeight=600,ScrollX=0,ScrollY=0}end
  function page:HasPendingLayout()return pending end
  local function arrange(items)
   Dirty.begin(tree,items);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)
  end
  function page:FlushScriptLayout()
   if flushing or not realm then return end;flushing=true
   local needed,items=realm:Flush()
   if pending then needed=true;items=items or{};for item in targets do items[item]=true end;pending=false;table.clear(targets)end
   if needed then arrange(items)end;flushing=false
  end
  arrange()
  local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
  function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode(key)return key.Name end
  local stop=Controller.start(page,tree,function(_,item)pending=true;if item then targets[item]=true end end,diagnostic,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=os.clock,PickerLayout=layout})
  realm=assert(HTMLScripts.start(page,tree,function()end,diagnostic,{JavaScriptServices={Clock=os.clock,RunService={RenderStepped=signal(),Heartbeat=signal()},Task={delay=function(_,fn)return{Callback=fn}end,cancel=function()end}}}))
  page.JavaScriptRuntime=realm
  local c=page.FormModel:Resolve(Node.findById(document,'editor'));local editor=c.Item.Editor;local connections=editor:ConnectionCount()
  local native={};for _,id in {'owner','caption','editor'}do local n=Node.findById(document,id);if n then native[id]=tree.NodeBoxes[n].Gui end end
  local function healthy()assert(#messages==0,table.concat(messages,' | '));assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
  local function settle()
   for _=1,16 do page:FlushScriptLayout();realm:AfterLayout();local tasks=realm:PumpTasks();if not realm:HasPending()and tasks==0 and not pending then break end end;page:FlushScriptLayout();healthy()
  end
  local function run(code)assert(realm:Run(code),code);settle()end
  run(reference.setup)
  local function retained()
   assert(c.Item.Editor==editor and editor:ConnectionCount()==connections and not editor.Destroyed,'Cross sizing replaced/rebound the native editor')
   assert(c.Value=='edited'and focused==editor and c.SelectionStart==1 and c.SelectionEnd==4 and c.SelectionDirection=='backward'and editor.CursorPosition==2 and editor.SelectionStart==5,'Cross sizing changed edited value, focus or actual native backward selection')
   for id,gui in native do local b=tree.NodeBoxes[Node.findById(document,id)];assert(b.Gui==gui,'Cross sizing recreated '..id);assert(b.Style.FontKerning==false,'Native-bound calibration requires the actual inherited no-kerning style')end
  end
  local function compare(expected,label)
   retained();for _,record in expected.boxes do if record then
   local b=tree.NodeBoxes[Node.findById(document,record.id)];near(b.OuterWidth,record.rect[3],label..' '..record.id..' width');near(b.OuterHeight,record.rect[4],label..' '..record.id..' height')
    -- These boxes are direct flex children; their native coordinates include
    -- the same physical margins and resolved padding/border contributions.
    near(b.LayoutX or 0,record.rect[1],label..' '..record.id..' x');near(b.LayoutY or 0,record.rect[2],label..' '..record.id..' y');checks+=1
    assert(record.values[8]=='none'and b.Style.FontKerning==false,'The native and mounted word metrics must use the same explicit kerning profile')
    for _,runBox in b.Children or{}do for _,word in runBox.Items or{}do
     if word.Kind=='Word'then assert(word.Style.FontKerning==false and word.Gui.OpenTypeFeatures:find('kern 0',1,true),'Calibrated geometry must retain the actual no-kerning paint feature')end
    end end
    for i,name in {'width','height'}do run('if(Math.abs(parseFloat(getComputedStyle(document.getElementById('..string.format('%q',record.id)..')).getPropertyValue('..string.format('%q',name)..'))-'..tostring(tonumber(record.values[i]:match('^[%d%.]+')))..')>=0.08)throw new Error("Used CSSOM cross size")')end
    for i,name in {'width','min-width','max-width','inline-size','min-inline-size','max-inline-size'}do run('if(document.getElementById('..string.format('%q',record.id)..').style.getPropertyValue('..string.format('%q',name)..')!=='..string.format('%q',record.author[i])..')throw new Error("Preserved author cross size")')end
   end end
   run("if(flexEditor!==document.getElementById('editor')||document.activeElement!==flexEditor||flexEditor.value!=='edited'||flexEditor.selectionStart!==1||flexEditor.selectionEnd!==4||flexEditor.selectionDirection!=='backward')throw new Error('Retained editor CSSOM')")
   local freshDocument=Parser.parseDocument(html)
   for _,id in {'owner','caption'}do local from,to=Node.findById(document,id),Node.findById(freshDocument,id);if from then to.Attributes=table.clone(from.Attributes)end end
   local fresh=renderer.build(freshDocument,{},diagnostic,resolveFont);fresh.ViewportHeight=600
   Dirty.begin(fresh);layout.arrange(fresh,800,0,0,function()return true end);Dirty.finish(fresh,true)
   assert(geometry(tree)==geometry(fresh),label..': retained layout differs from independent full layout')
   local owner=tree.NodeBoxes[Node.findById(document,'owner')];local measured=measurements
   for _,available in {40,120,400,80}do layout.naturalWidth(owner,available,function()retained();return true end,true,true);layout.naturalWidth(owner,available,function()retained();return true end,false,true)end
   assert(measurements==measured,label..': warmed intrinsic queries repeated native bounds')
   local allocated=#objects;arrange();arrange();retained()
   assert(measurements==measured and #objects==allocated,label..': warmed retained layout remeasured or recreated native surfaces')
   states+=1
  end
  local function dispose()
   checkEditor=nil;editor.Text='changed by editor';editor:GetPropertyChangedSignal('Text'):Fire();assert(c.Value=='changed by editor','Cross sizing broke actual native input events')
   realm:Destroy();stop();page.Alive=false;for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end
   assert(input.InputBegan:Count()==0 and input.InputChanged:Count()==0 and input.InputEnded:Count()==0 and editor:ConnectionCount()==0,'Cross sizing leaked native editor/input bindings')
  end
  checkEditor=retained
  return{Run=run,Compare=compare,Dispose=dispose,Tree=tree,Document=document,Retained=retained}
 end
 for _,case in reference.cases do
  checkEditor=nil;local host=mount(case.html,case.anonymous)
  for i,state in case.states do host.Run('flexOwner.style.width='..string.format('%q',state.width..'px'));host.Compare(state.expected,case.name..' '..i)end
  host.Dispose()
 end
 -- Previously captured raw self-start controls were intentionally held open
 -- by the property/parser boundary. Keep their native data unchanged.
 local selfControl=reference.openControls[1]
 assert(selfControl.name:find('self%-start'),'The existing raw control must exercise self-start')
 local selfHost=mount(selfControl.html)
 for i,state in selfControl.states do selfHost.Run('flexOwner.style.width='..string.format('%q',state.width..'px'));selfHost.Compare(state.expected,'Raw self-start '..i)end
 selfHost.Dispose()
 checkEditor=nil;local host=mount(reference.dynamic.html);local previousFont=nil
 for i,state in reference.dynamic.states do
  local before=measurements;host.Run(state.code);host.Compare(state.expected,'Dynamic CSSOM/font '..i)
  local font=host.Tree.NodeStyles[Node.findById(host.Document,'owner')].Font
  if previousFont and font~=previousFont then assert(measurements>before,'A family change must invalidate completed native font bounds');fontChecks+=1 end;previousFont=font
  if i==20 then assert(measurements>before and host.Tree.NodeStyles[Node.findById(host.Document,'owner')].FontSize==20,'A font-size change must invalidate native bounds and preserve its final size')end
 end
 host.Dispose()
 assert(states==#reference.cases*4+#reference.dynamic.states+#selfControl.states and fontChecks==2,'Every native resize/CSSOM/font/self-start state must be exercised')
 print('Column flex auto cross: '..states..' native mounted resize/CSSOM/font/editor states, '..checks..' box comparisons, retained identity/bindings/selection, independent full parity and warm caches passed')
end
