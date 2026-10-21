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

 settle();check(Node.textContent(node('page-status'))=='Vier Beispiele bereit · R01–R04','Comparison boot');
 local richBox=box('rich-editor');local richGUI=richBox.Gui;
 run("projectTable.tBodies[0].rows[0].cells[1].firstElementChild.value='Erhalten';");
 click('table-move');run("if(projectTable.tBodies[0].rows[1].cells[1].firstElementChild.value!=='Erhalten')throw new Error('Retained table note')");
 click('table-copy');run("if(projectTable.tBodies[0].rows.length!==3||projectTable.tBodies[0].rows[2].cells[1].firstElementChild.value!=='Morgensonne')throw new Error('Cloned input state')");
 click('table-adopt');check(Node.textContent(node('table-result')):find('true',1,true)~=nil,'Adopted row event owner');
 click('language-run');check(Node.textContent(node('language-result')):find('480 m²',1,true)~=nil,'Object, Proxy and binary sample');
 click('xml-run');check(Node.textContent(node('language-result'))=='urn:studio · Gartenatelier · HTML-Modus: CSS1Compat','Namespaced document');
 click('form-read');check(Node.textContent(node('form-result'))=='Formwert: Ein ruhiger Ort · gültig: true · eigener Zustand: true','FACE initial value');
 click('form-clear');check(Node.textContent(node('form-result'))=='Formwert:  · gültig: false · eigener Zustand: false','FACE empty validity/state');
 local field=Node.findById(document,'project-field');local shadow=field.InternalShadowRoot;local editorNode=Node.findById(shadow,'note');local editorRecord=page.FormModel:Resolve(editorNode);local editorGUI=editorRecord.Item.Editor;
 check(editorRecord.Item.Style.BorderColor==Color3.fromRGB(165,75,43),'FACE invalid native border');
 click('form-read');check(focused==editorGUI,'FACE validation anchor native focus');
 click('form-reset');check(editorRecord.Value=='Ein ruhiger Ort'and editorRecord.Item.Editor==editorGUI,'Reset retains native shadow editor');
 click('form-disable');check(editorRecord.Disabled and Node.textContent(node('form-result')):find('kein aktiver Wert',1,true)~=nil,'Disabled field excluded from form');
 click('form-disable');check(not editorRecord.Disabled,'Shadow disabled restoration');
 click('shadow-select');check(Node.textContent(node('form-result'))=='Shadow-Auswahl: Notiz · mit Root: true · ohne Root verborgen: true','Nested Shadow selection and composed range rescoping: '..Node.textContent(node('form-result')));
 click('select-bold');check(Node.textContent(node('edit-result')):find('morgen',1,true)~=nil,'Rich DOM selection');
 check(page.ContentEditableInput.Host==node('rich-editor'),'Rich editor uses native input source');
 click('select-word');click('select-line');click('editor-reset');check(tree.NodeBoxes[node('rich-editor')].Gui==richGUI,'Editing mutations retain host GUI');
 click('control-select');check(Node.textContent(node('control-result'))=='Text: Ä 😀 · Grenzen: 0 → 5','Unicode control selection');
 click('control-replace');check(control('control-note').Value=='Licht Holz und Licht','Control replacement retains following text');
 click('drag-reset');check(Node.textContent(node('drag-result'))=='Griff am Ausgangspunkt.','Drag reset');
 -- Native capture input exercises the shipped handlers after retained GUI resize.
 local grip=box('drag-handle').Gui;hitGui=grip;
 local object={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(20,20)};
 input.InputBegan:Fire(object,false);input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(50,42)},false);
 input.InputEnded:Fire(object,false);settle();
 run("if(dragging!==null||dragX!==30||dragY!==22)throw new Error('Shipped captured drag');");
 check(Node.textContent(node('drag-result')):find('30 / 22',1,true)~=nil,'Native captured coordinates');
 for _,w in {360,960}do
  root.AbsoluteSize=Vector2.new(w,900);root.AbsoluteWindowSize=Vector2.new(w,900);
  tree:SetMediaEnvironment(w,900);Dirty.begin(tree,nil);layout.arrange(tree,w,0,0,function()return true end);Dirty.finish(tree,true);realm:AfterLayout();settle();
  check(editorRecord.Item.Editor==editorGUI and tree.NodeBoxes[node('rich-editor')].Gui==richGUI,'Resize keeps both editor kinds');
 end
 check(runService.RenderStepped:Count()==0,'Comparison leaves no idle animation/frame listener');
 for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;page.Alive=false;
 check(editorGUI:GetPropertyChangedSignal('Text'):Count()==0 and input.InputBegan:Count()==0,'Comparison cleanup');
 for _,message in failures do print('Comparison09: '..message)end;assert(#failures==0,'Comparison09 failures: '..#failures);
 print('Shipped comparison09: tables/clone/adoption, language/XML, nested FACE validation/reset/disabled, scoped registry, retained rich/native selection, Unicode, capture and resize passed');
end
