--!strict
return function(Parser,Node,Controller,HTMLScripts,loadRenderTree,loadWordLayout,loadBlockLayout,reference,loadDimensions)
 local function signal()
  local listeners={};local api={};function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
  function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
  function api:Count()local n=0;for _,entry in listeners do if entry[1].Connected then n+=1 end end;return n end;return api
 end
 local allocated,nativeFocus={},nil;local factory={create=function(class,parent,props)
  local gui=table.clone(props or{});gui.Parent,gui.ClassName=parent,class;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(800,600);gui.Visible=true
  if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0)end
  gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local signals,attributes={},{ }
  function gui:GetPropertyChangedSignal(key)signals[key]=signals[key]or signal();return signals[key]end
  function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
  function gui:SetAttribute(key,value)attributes[key]=value end;function gui:GetAttribute(key)return attributes[key]end
  function gui:IsA(kind)return kind==class or kind=='GuiObject'end;function gui:IsFocused()return nativeFocus==self end
  function gui:CaptureFocus()if nativeFocus==self then return end;local old=nativeFocus;nativeFocus=self;if old then old.FocusLost:Fire(false)end;self.Focused:Fire()end
  function gui:ReleaseFocus()if nativeFocus~=self then return end;nativeFocus=nil;self.FocusLost:Fire(false)end
  function gui:Destroy()assert(not self.Destroyed,'Input widget double cleanup');self.Destroyed=true;self:ReleaseFocus();for _,child in allocated do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
  function gui:ConnectionCount()local n=self.Focused:Count()+self.FocusLost:Count()+self.InputBegan:Count();for _,s in signals do n+=s:Count()end;return n end
  table.insert(allocated,gui);return gui
 end};factory.modifier=factory.create
 local renderer=loadRenderTree(factory);local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=(utf8.len(text)or 0)*size*.5,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local function setup(initialType,resourceSources)
  local initial=if initialType then reference.initial:gsub('<input id=s','<input type='..initialType..' id=s',1)else reference.initial
  local document=Parser.parseDocument('<!doctype html>'..initial..'<script></script>');local parent=factory.create('Frame',nil,{});local root=factory.create('ScrollingFrame',parent,{})
  root:SetAttribute('Status','ready');local tree=renderer.build(document,root,error,nil,nil,nil,if resourceSources then function(source)return resourceSources[source]end else nil);tree.ViewportHeight=600
  local page={Alive=true,Document=document,DocumentURL='https://input.test/page',BaseURL='https://input.test/page',Root=root,Cleanups={}}
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  function page:GeometryViewport()return{Width=800,Height=600,ClientWidth=800,ClientHeight=600,ScrollWidth=800,ScrollHeight=600,ScrollX=0,ScrollY=0}end
  function page:HasPendingLayout()return false end
  local realm,flushing,dirty=nil,false,false
  local function arrange()layout.arrange(tree,800,0,0,function()return true end)end
  function page:FlushScriptLayout()if flushing or not realm then return end;flushing=true;local changed=realm:Flush();if changed or dirty then dirty=false;arrange()end;flushing=false end
  arrange();local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
  function input:GetFocusedTextBox()return nativeFocus end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode(key)return key.Name end
  local stop=Controller.start(page,tree,function()dirty=true end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=os.clock,PickerLayout=layout})
  local services={Clock=os.clock,RunService={RenderStepped=signal(),Heartbeat=signal()},Task={delay=function(_,fn)return{Callback=fn}end,cancel=function()end}}
  realm=assert(HTMLScripts.start(page,tree,function()end,error,{JavaScriptServices=services}));page.JavaScriptRuntime=realm
  local api={Page=page,Tree=tree,Realm=realm,Input=input,Document=document,Control=page.FormModel:Resolve(Node.findById(document,'s'))}
  if resourceSources then
   local callbacks,cancellations,changes={},0,0
   local dimensions=loadDimensions({},{})
   local stopDimensions,dimensionRuntime=dimensions.start(tree.ImageItems,function()return page.Alive end,error,function()changes+=1 end,{LoadDimensions=function(_,callback)
    table.insert(callbacks,callback);return function()cancellations+=1 end
   end})
   page:AddCleanup(stopDimensions)
   tree.StructuralResourcesRemoving=function(removals)
    for _,item in removals.Images or{}do assert(item.BoxGui and not item.BoxGui.Destroyed,'Resources cancel before anonymous image contents are destroyed')end
    dimensionRuntime:Remove(removals.Images or{})
   end
   function page:RefreshDOMResources()local changes=tree:TakeStructuralResourceChanges();dimensionRuntime:Remove(changes.Images.Removed);dimensionRuntime:Add(changes.Images.Added)end
   api.ResourceCallbacks=callbacks;function api:ResourceStats()return cancellations,changes end
  end
  function api:Run(code)assert(realm:Run(code),code);page:FlushScriptLayout();realm:AfterLayout();realm:PumpTasks();page:FlushScriptLayout();assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
  function api:Read(code)self:Run('globalThis.typeSnapshot='..code);return realm.Window.Get('typeSnapshot')end
  function api:Destroy()realm:Destroy();stop();page.Alive=false;for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;assert(input.InputBegan:Count()==0 and tree.BeforeInputViewChange==nil,'Input type disposal releases global signals and replacement hook');parent:Destroy()end
  api:Run("globalThis.s=document.getElementById('s');globalThis.peer=document.getElementById('peer')")
  return api
 end
 local editorTypes={text=true,search=true,tel=true,url=true,email=true,password=true,number=true}
 local temporalTypes={date=true,month=true,week=true,time=true,['datetime-local']=true}
 local function widget(c,kind)
  local item=c.Item;assert(item.ViewType==kind,'Actual native widget type follows live state: '..kind)
  assert((item.Editor~=nil)==(editorTypes[kind]==true),'Editor presence: '..kind)
  assert((item.TemporalIcon~=nil)==(temporalTypes[kind]==true),'Temporal presence: '..kind)
  assert((item.RangeThumb~=nil)==(kind=='range'),'Range presence: '..kind)
  assert((item.RadioRing~=nil)==(kind=='radio')and(item.Ticks~=nil)==(kind=='checkbox'),'Toggle presence: '..kind)
  assert((item.FileButton~=nil)==(kind=='file')and(item.ColorSwatch~=nil)==(kind=='color'),'File/color presence: '..kind)
  assert((item.FallbackGui~=nil)==(kind=='image'),'Image fallback presence: '..kind)
  assert(not item.Gui.Destroyed,'A connected type transition retains its primary GUI')
 end
 local checked=0
 for _,case in reference.focus do
  local api=setup();local c,outer=api.Control,api.Control.Item.Gui
  api:Run('s.type='..string.format('%q',case.from)..";globalThis.events=[];for(const type of ['focus','blur','input','change','select'])s.addEventListener(type,()=>events.push(type));s.focus();if(s.selectionStart!==null)s.setSelectionRange(1,2,'backward');events=[]")
  -- Native selection events are queued. Drain preparation before observing
  -- the type mutation, just as the browser fixture waits for its frame.
  api:Run('events=[]')
  local oldEditor=c.Item.Editor
  api:Run('s.type='..string.format('%q',case.to))
  local expected=case.specExpected or case.platformExpected
  assert(api:Read('document.activeElement.id')==expected.active,case.from..' → '..case.to..' native focus after flush')
  assert(api:Read(reference.snapshot)==expected.snapshot,case.from..' → '..case.to..' mounted state')
  local actualEvents=api:Read('events.join("|")');assert(actualEvents==table.concat(expected.events,'|'),case.from..' → '..case.to..' native event ordering: '..actualEvents..' != '..table.concat(expected.events,'|'))
  assert(api.Page.FormModel:Resolve(c.Node)==c and c.Item.Gui==outer,'Type transition retains public control and primary GUI')
  if oldEditor and oldEditor~=c.Item.Editor then assert(oldEditor.Destroyed and oldEditor:ConnectionCount()==0,'Old editor is destroyed after disconnecting native callbacks')end
  widget(c,case.to);api:Destroy();checked+=1
 end
 -- A retained control traverses all native widget families repeatedly. Fresh
 -- text editors receive real native property signals after incompatible types.
 local api=setup();local c,outer=api.Control,api.Control.Item.Gui
 for round=1,3 do for _,kind in reference.types do
  local oldEditor=c.Item.Editor;api:Run('s.type='..string.format('%q',kind));widget(c,kind)
  assert(c.Item.Gui==outer and api.Page.FormModel:Resolve(c.Node)==c,'Repeated type changes retain identity')
  for _,target in api.Tree.FontPreloadTargets do assert(not target.Destroyed,'Anonymous font targets release destroyed widget references')end
  if oldEditor and oldEditor~=c.Item.Editor then assert(oldEditor.Destroyed and oldEditor:ConnectionCount()==0,'Repeated changes release previous editor signals')end
  if kind=='text'then
   api:Run('s.focus();s.value="42"');local editor=assert(c.Item.Editor);editor.Text='73';editor:GetPropertyChangedSignal('Text'):Fire()
   assert(api:Read('s.value')=='73','New native editor remains bound to the actual JavaScript/control record')
  end
 end end
 api:Run("s.type='text';s.defaultValue='42';s.value='73';s.setSelectionRange(0,1,'backward');document.getElementById('f').reset()")
 assert(api:Read("s.value+'|'+s.selectionStart+'|'+s.selectionEnd+'|'+s.selectionDirection")=='42|0|1|backward','Standard reset preserves a selection within the restored value')
 local editor,box=c.Item.Editor,c.Item.BoxGui
 api:Run("s.setAttribute('type','TEXT')")
 assert(c.Item.Editor==editor and c.Item.BoxGui==box,'A normalized type no-op retains anonymous widgets')
 api:Run("s.removeAttribute('type')")
 assert(c.Item.Editor==editor and c.Item.BoxGui==box,'Removing text type retains anonymous widgets')
 api:Destroy()
 local hidden=setup('hidden')
 assert(hidden.Control==nil,'Initially hidden controls need no mounted widget')
 hidden:Run("s.value='91';s.checked=false;s.indeterminate=true;s.type='text'")
 local revealed=assert(hidden.Page.FormModel:Resolve(Node.findById(hidden.Document,'s')))
 local revealedState=hidden:Read("s.value+'|'+s.defaultValue+'|'+s.checked+'|'+s.indeterminate")
 assert(revealedState=='91|91|false|true','First visible widget adopts existing unrendered DOM state: '..revealedState)
 widget(revealed,'text');hidden:Destroy()
 for _,case in reference.badInput do
  local bad=setup();bad:Run("s.type='number';s.value='';s.focus()")
  local nativeEditor=assert(bad.Control.Item.Editor);nativeEditor.Text='-';nativeEditor:GetPropertyChangedSignal('Text'):Fire()
  assert(bad:Read(reference.snapshot)==case.platformExpected.before,'Real numeric editor creates native bad input')
  bad:Run('s.type='..string.format('%q',case.to))
  local actual=bad:Read(reference.snapshot)
  assert(actual==case.platformExpected.changed,'Invalid numeric edit → '..case.to..': '..actual..' != '..case.platformExpected.changed)
  bad:Destroy()
 end
 local resource=setup(nil,{['a.png']='rbxassetid://123'})
 resource:Run("s.src='a.png';s.type='image'")
 local image=resource.Control.Item;local imageOuter=image.Gui;assert(#resource.ResourceCallbacks==1 and #resource.Tree.ImageItems==1,'A newly live image widget registers its real metadata resource')
 resource:Run("s.type='hidden'");local canceled,reflows=resource:ResourceStats()
 assert(canceled==1 and #resource.Tree.ImageItems==0,'Changing image type removes and cancels its pending resource')
 local hiddenWidth,hiddenHeight=image.IntrinsicWidth,image.IntrinsicHeight
 resource.ResourceCallbacks[1](true,{Width=640,Height=320})
 local _,lateReflows=resource:ResourceStats();assert(lateReflows==reflows and image.IntrinsicWidth==hiddenWidth and image.IntrinsicHeight==hiddenHeight,'Canceled image completion cannot restore obsolete dimensions')
 resource:Run("s.type='image'");assert(#resource.ResourceCallbacks==2 and image.Gui==imageOuter,'Returning to image creates a fresh request on the retained public surface: '..#resource.ResourceCallbacks..'/'..tostring(image.Gui==imageOuter)..' items='..#resource.Tree.ImageItems..' source='..tostring(image.Source))
 resource.ResourceCallbacks[2](true,{Width=320,Height=160});resource:Run('void s.offsetWidth')
 assert(image.IntrinsicWidth==320 and image.IntrinsicHeight==160,'Current image completion updates its real mounted resource')
 resource:Run("s.type='text'");assert(image.Source==nil and image.ImageGui==nil and image.Gui==imageOuter,'Leaving image releases native image surfaces and retains public identity')
 resource:Destroy();resource.ResourceCallbacks[2](true,{Width=999,Height=999})
 assert(checked==16,'Mounted input type native focus coverage changed')
 print('Input type rendering: '..checked..' native focus references, 22 real invalid numeric edits, 66 retained widget transitions, reset, no-op, hidden adoption, async image cancellation and disposal passed')
end
