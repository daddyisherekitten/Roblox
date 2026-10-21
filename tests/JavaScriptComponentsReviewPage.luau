--!strict
-- Exercise the shipped comparison source, through the mounted runtime and
-- actual native-input callbacks, rather than a smaller replacement page.
return function(Parser,Node,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,Controller,HTMLAnimations,html,css)
 local function signal()
  local entries={};local api={}
  function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
  function api:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
  function api:Count()local n=0;for _,entry in entries do if entry[1].Connected then n+=1 end end;return n end
  return api
 end
 local focused;local guis,deferred={},{};local factory={}
 function factory.create(class,parent,props)
  local changes,attributes={},{};local values={ClassName=class,Parent=parent,Visible=true,AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(960,900),Text='',CursorPosition=-1,SelectionStart=-1}
  for key,value in props do values[key]=value end
  if class=='ScrollingFrame'then values.CanvasPosition=Vector2.new(0,0);values.ScrollingEnabled=true end
  local gui=setmetatable({},{__index=values,__newindex=function(_,key,value)local before=values[key];values[key]=value;if before~=value and changes[key]then changes[key]:Fire()end end})
  values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
  function values:GetPropertyChangedSignal(key)if not changes[key]then changes[key]=signal()end;return changes[key]end
  function values:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
  function values:SetAttribute(key,value)attributes[key]=value;if changes['attribute:'..key]then changes['attribute:'..key]:Fire()end end
  function values:GetAttribute(key)return attributes[key]end
  function values:IsA(kind)return kind==class or kind=='GuiObject'end
  function values:IsFocused()return focused==gui end
  function values:CaptureFocus()if focused and focused~=gui then focused:ReleaseFocus()end;focused=gui;gui.CursorPosition=1;self.Focused:Fire()end
  function values:ReleaseFocus()if focused==gui then focused=nil;gui.CursorPosition=-1;gui.SelectionStart=-1;self.FocusLost:Fire(false)end end
  function values:Destroy()assert(not values.Destroyed,'Native page GUI disposed twice');values.Destroyed=true;for _,child in guis do if child.Parent==gui and not child.Destroyed then child:Destroy()end end;gui.Parent=nil end
  table.insert(guis,gui);return gui
 end
 factory.modifier=factory.create
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
 local document=Parser.parseDocument(html);local root=factory.create('ScrollingFrame',nil,{AbsoluteWindowSize=Vector2.new(960,900)})
 local messages,diagnostics={},{};local url='https://example.test/javascript-tests/index.html'
 local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,{['styles.css']=css},url)
 local time=0;local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()};local hitGui
 function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end
 local runService={RenderStepped=signal()}
 local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return if hitGui then {hitGui}else {}end},Factory=factory,Clock=function()return time end,RunService=runService,
  Task={defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
 local page={Alive=true,Document=document,DocumentURL=url,BaseURL=url,Root=root,Cleanups={}}
 function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
 local pending=false;local targets={};local flushing=false;local realm;local cssMotion;local layouts=0
 local function request(_,item,reason)pending=true;if item then targets[item]=reason or true end end
 function page:RequestAnimationLayout(box)request(true,box)end
 function page:HasPendingLayout()return pending end
 function page:GeometryViewport()return {Width=960,Height=900,ClientWidth=960,ClientHeight=900,ScrollWidth=960,ScrollHeight=tree.OuterHeight or 900,ScrollX=root.CanvasPosition.X,ScrollY=root.CanvasPosition.Y}end
 local function arrange(items)
  layouts+=1;tree:SetMediaEnvironment(960,900);tree.ViewportHeight=900;Dirty.begin(tree,items);layout.arrange(tree,960,0,0,function()return true end);Dirty.finish(tree,true)
 end
 function page:FlushScriptLayout()
  if flushing or not realm then return end;flushing=true
  for attempt=1,5 do
   local needed,items=realm:Flush();for item,reason in items or{}do targets[item]=reason end
   if not needed and not pending then break end
   local dirty=targets;targets={};pending=false;arrange(if next(dirty)then dirty else nil)
   if cssMotion then cssMotion:AfterLayout()end;realm:AfterLayout()
   assert(attempt<5 or not pending,'Comparison layout did not converge')
  end
  flushing=false
 end
 arrange(nil);Controller.start(page,tree,request,function(message)table.insert(diagnostics,message)end,services)
 cssMotion=HTMLAnimations.start(page,tree,function(message)table.insert(diagnostics,message)end,services,20);cssMotion:AfterLayout()
 root:SetAttribute('Status','ready')
 -- settle drives the scheduled script flush. Scheduling a mutation does not
 -- itself request layout: the actual Flush result decides whether to reflow.
 realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services},function()page:FlushScriptLayout()end)
 local function healthy()assert(#diagnostics==0,table.concat(diagnostics,' | '));assert(#messages==0,table.concat(messages,' | '))end
 local function settle()
  for _=1,32 do
   local work=deferred;deferred={};for _,fn in work do fn()end
   page:FlushScriptLayout();realm:AfterLayout();local count=realm:PumpTasks()
   if #deferred==0 and count==0 and not pending and not realm:HasPending()then break end
  end
  page:FlushScriptLayout();healthy()
 end
 local function run(source)realm:Run(source);settle()end
 local function node(id)return assert(Node.findById(document,id),id)end
 local function children(value,name)local result={};for _,child in value.Children do if child.Kind=='Element'and child.Name==name then table.insert(result,child)end end;return result end
 local function box(id)return assert(tree.NodeBoxes[node(id)],'Native box '..id)end
 local function control(id)return assert(page.FormModel:Resolve(node(id)),'Native control '..id)end
 local function click(id)run("document.getElementById('"..id.."').click();")end
 local failures={}
 local function check(value,message)if not value then table.insert(failures,message)end end
 local function near(value,expected,label)check(type(value)=='number'and math.abs(value-expected)<.001,(label or'geometry')..': '..tostring(value)..' ~= '..expected)end
 local function paintOffsetX(value)
  local surface=if value.OpacityGroup then value.OpacityGroup.Gui else value.Gui
  local scale=if value.TransformScale then value.TransformScale.Scale else 1
  return surface.Position[1]-(surface.AnchorPoint and surface.AnchorPoint.X or 0)*surface.Size[1]*scale-(value.TransformBaseX or 0)
 end
 settle()
 assert(Node.textContent(node('js-status')):find('Bereit',1,true),'The shipped page script did not complete boot')
 local function finishEntering(label)
  assert(runService.RenderStepped:Count()>0,label..': starting-style did not create a finite entering transition')
  time+=.25;runService.RenderStepped:Fire(.25);settle()
  assert(next(cssMotion.Transitions)~=nil,label..': entering transition finished before its .5s duration')
  time+=.3;runService.RenderStepped:Fire(.3);settle()
  assert(runService.RenderStepped:Count()==0,label..': completed entering transitions keep an idle animation connection')
 end
 finishEntering('Initial generated list')
 local note=control('component-note');local noteGUI=note.Item.Gui;local nativeEditor=note.Item.Editor
 run("document.getElementById('component-note').value='Behalten';document.getElementById('component-note').setSelectionRange(2,5);")
 local start,finish=note.SelectionStart,note.SelectionEnd
 local tableNode=node('project-table');local body=children(tableNode,'tbody')[1]
 local headerNode=children(children(tableNode,'thead')[1],'tr')[1]
 local headerGUI=assert(tree.NodeBoxes[headerNode]).Gui
 click('table-add');run("if(table.tBodies[0].rows.length!==3||table.rows.length!==4||table.tBodies[0].rows[2].cells[0].textContent!=='Entwurf 3')throw new Error('Shipped table insertion');")
 local added=children(body,'tr')[3]
 assert(tree.NodeBoxes[added],'The added table row was not mounted')
 click('table-order');run("if(table.tBodies[0].rows[0].cells[0].textContent!=='Entwurf 3')throw new Error('Shipped table reorder');")
 click('table-span');run("if(table.tBodies[0].rows[0].cells.length!==1||table.tBodies[0].rows[0].cells[0].colSpan!==2)throw new Error('Shipped table span');")
 click('table-span');assert(tree.NodeBoxes[headerNode].Gui==headerGUI,'Changing the table recreated the header')
 click('component-tone');local hostColor=box('component').Style.Background
 check(hostColor==Color3.fromRGB(246,230,216),'The shipped component adopted :host tone did not repaint')
 click('component-slot');run("if(document.getElementById('component').querySelector('strong').slot!=='alternate')throw new Error('Shipped slot switch');")
 assert(page.FormModel:Resolve(node('component-note'))==note and note.Item.Gui==noteGUI and note.Item.Editor==nativeEditor and note.Value=='Behalten','Component updates replaced the input or edited value')
 assert(note.SelectionStart==start and note.SelectionEnd==finish,'Component updates lost the input selection')
 local list=node('generated-list');local first=children(list,'li')[1]
 check(tree.NodeBoxes[first].Marker.Gui.Text=='1. ','The initial native counter marker is wrong')
 click('generated-add');local listItems=children(list,'li');check(#listItems==3 and tree.NodeBoxes[listItems[3]].Marker.Gui.Text=='3. ','New generated marker did not follow DOM order')
 finishEntering('Inserted generated item')
 click('generated-change');check(tree.NodeBoxes[first].Style.Background==Color3.fromRGB(246,230,216),'Generated class did not repaint its native item')
 local generated='';for _,item in tree.TextItems do if item.Style and item.Style.Node==first then generated..=item.Text or''end end
 check(generated:find('Favorit',1,true)and generated:find('★',1,true),'Generated attr/after content did not rebuild its actual native text')
 click('generated-remove');listItems=children(list,'li');check(#listItems==2 and tree.NodeBoxes[listItems[2]].Marker.Gui.Text=='2. ','Counter after removal is not contiguous')
 local ruleBox=box('rule-box');local ruleGUI=ruleBox.Gui
 near(ruleBox.Style.BorderSize,2,'Constructed scope border width')
 local scopeStroke;for _,gui in guis do if gui.ClassName=='UIStroke'and gui.Parent==ruleGUI and not gui.Destroyed then scopeStroke=gui;break end end
 check(scopeStroke and scopeStroke.Thickness==2 and scopeStroke.Color==Color3.fromRGB(84,113,90),'The constructed scoped border has no native stroke after adoption')
 near(ruleBox.OuterWidth,140,'Registered property initial width')
 click('rules-layer');check(ruleBox.Style.Background==Color3.fromRGB(241,217,189),'The edited layer did not repaint the retained rule box')
 click('rules-motion');run("document.getElementById('rule-box').style.animationPlayState='paused';document.getElementById('rule-box').style.animationDelay='-1s';")
 near(ruleBox.OuterWidth,180,'Paused CSS keyframe midpoint')
 local ruleStarted=cssMotion.AnimationRecords[ruleBox][1].Start
 click('rules-keyframe');near(ruleBox.OuterWidth,210,'Edited CSS endpoint at retained midpoint');assert(cssMotion.AnimationRecords[ruleBox][1].Start==ruleStarted,'Keyframe rule edit restarted the clock')
 click('rules-motion');near(ruleBox.OuterWidth,140,'CSS keyframe removal');assert(ruleBox.Gui==ruleGUI,'CSSOM updates recreated its box')
 local motionBox=box('motion-object');local motionGUI=motionBox.Gui
 click('motion-start');run("document.getElementById('motion-object').style.animationPlayState='paused';document.getElementById('motion-object').style.animationDelay='-.6s';activeMotion.pause();activeMotion.currentTime=600;")
 near(motionBox.OuterWidth,180,'Combined CSS and script width');near(motionBox.OuterHeight,52,'CSS height midpoint')
 near(paintOffsetX(motionBox),16.5,'Additive transform plus separate individual translate')
 local currentLayouts=layouts;run("document.getElementById('motion-object').getBoundingClientRect();document.getElementById('motion-object').getBoundingClientRect();")
 assert(layouts==currentLayouts,'Current geometry reads unnecessarily recalculated the comparison page')
 click('motion-commit');near(motionBox.OuterWidth,180,'Committed combined width');near(motionBox.OuterHeight,40,'Removed lower CSS height');assert(motionBox.Gui==motionGUI,'Commit recreated the native motion box')
 click('motion-cancel');near(motionBox.OuterWidth,100,'Cancel author width');near(paintOffsetX(motionBox),4,'Cancel preserves individual translate')
 local function position(x,y)return setmetatable(Vector2.new(x,y),{__sub=function(a,b)return {X=a.X-b.X,Y=a.Y-b.Y,Magnitude=math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2)}end})end
 local function pointer(kind,x,y)return {UserInputType=kind,Position=position(x,y),Delta=Vector2.new(0,0)}end
 local dragBox=tree.NodeBoxes[node('drag-object')]
 check(dragBox~=nil,'The absolute drag control has no positioned native box')
 if dragBox then
  near(dragBox.OuterWidth,86,'Drag control width');near(dragBox.OuterHeight,48,'Drag control height')
  near(dragBox.PaintX,13,'Drag control left inset');near(dragBox.PaintY,13,'Drag control top inset')
 end
 local dragStage=box('drag-stage');local dragStageHeight=dragStage.OuterHeight
 local dragGUI=control('drag-object').Item.Gui
 hitGui=control('drag-object').Item.Label or control('drag-object').Item.Gui;input.InputBegan:Fire(pointer(Enum.UserInputType.MouseButton1,20,30),true);settle()
 check(Node.textContent(node('input-result')):find('festgehalten',1,true),'The native button press did not acquire pointer capture')
 local beforeDragLayouts=layouts
 hitGui=nil;input.InputChanged:Fire(pointer(Enum.UserInputType.MouseMovement,95,45));settle()
 if dragBox then
  near(paintOffsetX(dragBox),75,'Captured pointer native transform')
  near(dragBox.Gui.Position[2]-dragBox.Gui.AnchorPoint.Y*dragBox.Gui.Size[2]-dragBox.TransformBaseY,15,'Captured pointer native vertical transform')
 end
 check(layouts==beforeDragLayouts,'Moving the captured control unnecessarily reflows the page')
 check(dragStage.OuterHeight==dragStageHeight and control('drag-object').Item.Gui==dragGUI,'Dragging changes flow height or recreates its control')
 input.InputEnded:Fire(pointer(Enum.UserInputType.MouseButton1,95,45),true);settle()
 check(node('drag-object').Attributes.style and node('drag-object').Attributes.style:find('translate(75px, 15px)',1,true),'The shipped native capture drag failed outside the original hit target')
 check(Node.textContent(node('input-result')):find('Losgelassen',1,true),'Shipped pointer-up result was not updated')
 local composition=control('composition-input');composition.Item.Editor.Text='Hé森';settle()
 check(composition.Value=='Hé森'and Node.textContent(node('input-result'))=='Bestätigter Text: Hé森','The shipped page did not receive the real native Unicode input callback')
 assert(note.Item.Gui==noteGUI and note.Value=='Behalten'and note.SelectionStart==start and note.SelectionEnd==finish,'Unrelated page combinations damaged preserved input state')
 assert(runService.RenderStepped:Count()==0,'Paused/canceled comparison effects retain a native frame connection')
 page.Alive=false;for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end
 assert(input.InputBegan:Count()==0 and input.InputChanged:Count()==0 and input.InputEnded:Count()==0 and input.WindowFocusReleased:Count()==0 and runService.RenderStepped:Count()==0,'Page disposal leaves native event/frame subscriptions')
 for _,failure in failures do print('Shipped comparison mismatch: '..failure)end;assert(#failures==0,'Shipped comparison fixture failures: '..#failures)
 print('Shipped comparison 08: table actions, adopted shadow component state, generated counters/content, CSSOM layers/keyframes, CSS+WAAPI midpoint/commit/cancel, native capture drag and Unicode editor passed')
end
