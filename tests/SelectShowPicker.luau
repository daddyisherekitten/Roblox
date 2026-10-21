--!strict
return function(Parser,Node,Runtime,Events,Controller,HTMLScripts,loadRenderTree,loadWordLayout,loadBlockLayout,loadIFrameRuntime,reference)
 local Origin=require('DOM/DocumentOrigin')
 local function signal()
  local listeners={};local api={};function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
  function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
  function api:Count()local count=0;for _,entry in listeners do if entry[1].Connected then count+=1 end end;return count end
  return api
 end
 local allocated={};local factory={create=function(class,parent,props)
  local gui=table.clone(props or{});gui.Parent,gui.ClassName=parent,class;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(800,600);gui.Visible=true
  if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0)end
  gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local signals,attributes={},{}
  function gui:GetPropertyChangedSignal(key)signals[key]=signals[key]or signal();return signals[key]end
  function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
  function gui:SetAttribute(key,value)attributes[key]=value end
  function gui:GetAttribute(key)return attributes[key]end
  function gui:IsA(kind)return kind==class or kind=='GuiObject'end
  function gui:IsFocused()return false end
  function gui:Destroy()assert(not self.Destroyed,'showPicker surface double cleanup');self.Destroyed=true;for _,child in allocated do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
  table.insert(allocated,gui);return gui
 end};factory.modifier=factory.create
 local renderer=loadRenderTree(factory);local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=(utf8.len(text)or 0)*size*.5,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local function setup(html,options)
  options=options or{};local document=Parser.parseDocument(html..'<script></script>');local parent=factory.create('Frame',nil,{});local root=factory.create('ScrollingFrame',parent,{})
  root:SetAttribute('Status','ready');local tree=renderer.build(document,root,error);tree.ViewportHeight=600
  local page={Alive=true,Document=document,DocumentURL=options.DocumentURL or'https://picker.test/page',Root=root,Cleanups={}}
  page.BaseURL=options.FallbackBaseURL or page.DocumentURL
  page.DocumentOrigin=Origin.ensure(document,page.DocumentURL,options.DocumentOrigin,options.DocumentOriginOpaque)
  page.TopLevelDocumentOrigin=options.TopLevelDocumentOrigin or page.DocumentOrigin
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  function page:GeometryViewport()return{Width=800,Height=600,ClientWidth=800,ClientHeight=600,ScrollWidth=800,ScrollHeight=600,ScrollX=0,ScrollY=0}end
  function page:HasPendingLayout()return false end
  local realm,flushing,dirty=nil,false,false
  local function arrange()
   layout.arrange(tree,800,0,0,function()return true end)
   for _,c in tree.Controls do
    if c.Item.BoxGui then
     c.Item.BoxGui.AbsolutePosition=Vector2.new(100,if c.Node.Attributes.id=='launch'then 30 else 90)
     local b=c.Item.Box
     c.Item.BoxGui.AbsoluteSize=Vector2.new(c.Item.BoxWidth or(b and b.OuterWidth)or 120,c.Item.BoxHeight or(b and b.OuterHeight)or 24)
    end
   end
  end
  function page:FlushScriptLayout()
   if flushing or not realm then return end;flushing=true
   local changed=realm:Flush();if changed or dirty then dirty=false;arrange()end
   if self.RefreshControlPickers then self:RefreshControlPickers()end;flushing=false
  end
  arrange();local hits={};local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
  function input:GetFocusedTextBox()return nil end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode(key)return key.Name end
  local stop=Controller.start(page,tree,function()dirty=true end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return hits end},Factory=factory,Clock=os.clock,PickerLayout=layout})
  local services={Clock=os.clock,RunService={RenderStepped=signal(),Heartbeat=signal()},Task={delay=function(_,fn)return{Callback=fn}end,cancel=function()end}}
  realm=assert(HTMLScripts.start(page,tree,function()end,error,{JavaScriptServices=services}));page.JavaScriptRuntime=realm
  local api={Page=page,Tree=tree,Realm=realm,Input=input,Document=document}
  function api:Run(code)assert(realm:Run(code),code);page:FlushScriptLayout();realm:AfterLayout();realm:PumpTasks();page:FlushScriptLayout();assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
  function api:Read(code)self:Run('globalThis.pickerSnapshot='..code);return realm.Window.Get('pickerSnapshot')end
  function api:Activate(enabled)page.FormModel.UserActivationUntil=if enabled then os.clock()+5 else 0 end
  function api:Key(key)local event={UserInputType=Enum.UserInputType.Keyboard,KeyCode=key};input.InputBegan:Fire(event,false);input.InputEnded:Fire(event,false);page:FlushScriptLayout()end
  function api:ClickLaunch()
   local c=assert(page.FormModel:Resolve(Node.findById(document,'launch')));hits={c.Item.BoxGui};local e={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(105,35)}
   input.InputBegan:Fire(e,false);input.InputEnded:Fire(e,false);hits={};page:FlushScriptLayout()
  end
  function api:Destroy()
   realm:Destroy();stop();page.Alive=false
   for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end
   assert(input.InputBegan:Count()==0 and input.InputChanged:Count()==0 and input.InputEnded:Count()==0,'showPicker releases input lifetime')
   for select in pairs(tree.NodeBoxes)do if select.Name=='select'then assert(tree:PickerBox(select)==nil,'Disposal releases registered picker geometry')end end
   parent:Destroy()
  end
  return api
 end
 local call=[=[(()=>{let error='',exception=false,result;try{result=target.showPicker()}catch(e){error=e.name;exception=e instanceof DOMException}return [error,exception,result===undefined,target.matches(':open'),document.activeElement.localName,pickerEvents.join(',')].join('|')})()]=]
 local initialize=[=[globalThis.target=document.getElementById('s');globalThis.pickerEvents=[];for(let type of ['click','input','change','focus'])target.addEventListener(type,()=>pickerEvents.push(type))]=]
 local function compare(api,expected,label)
  local wanted=table.concat({expected.error,tostring(expected.exception),tostring(expected.resultUndefined),tostring(expected.open),expected.activeElement,table.concat(expected.events,',')},'|')
  assert(api:Read(call)==wanted,label..': '..tostring(api.Realm.Window.Get('pickerSnapshot'))..' != '..wanted)
  assert((api.Page.FormModel.UserActivationUntil>os.clock())==expected.activeAfter,label..' consumes activation only after preconditions')
 end
 local checked=0
 for _,case in reference.cases do
  local api=setup(case.html);api:Run(initialize)
  if case.prepare~=''then api:Run(case.prepare:gsub('s%.','target.'))end
  api:Activate(case.activation);compare(api,case.expected,case.name);checked+=1
  local d=reference.descriptors
  local expected=table.concat({d.name,tostring(d.length),tostring(d.writable),tostring(d.enumerable),tostring(d.configurable),d.borrowed,tostring(d.same)},'|')
  assert(api:Read([=[(()=>{const d=Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype,'showPicker');let borrowed='';try{d.value.call(document.createElement('input'))}catch(e){borrowed=e.name}return[d.value.name,d.value.length,d.writable,d.enumerable,d.configurable,borrowed,target.showPicker===d.value].join('|')})()]=])==expected,'Native operation descriptor and brand check')
  api:Destroy()
 end
 assert(checked==36,'showPicker native precondition coverage changed')
 -- The actual frame host decides creation-time origins, including distinct
 -- opaque data documents and sandboxed srcdoc versus inherited srcdoc.
 local Frames=loadIFrameRuntime({defer=function(callback)callback()end})
 for _,case in reference.frames do
  local parentDocument=Node.document();local parent={Alive=true,Document=parentDocument,DocumentURL='data:text/html,parent',BaseURL='https://different-base.test/path',AddCleanup=function()end}
  local inherited=Origin.ensure(parentDocument,parent.DocumentURL);parent.DocumentOrigin=inherited;parent.TopLevelDocumentOrigin=inherited
  local html='<select id=s'..(if case.disabled then' disabled'else'')..'><option>A</option></select>'
  local attrs=if case.kind=='data'then{src='data:text/html,child'}else{srcdoc=html}
  if case.kind=='sandbox-srcdoc'then attrs.sandbox='allow-scripts'end
  local node=Node.element('iframe',attrs);local content=factory.create('Frame',nil,{});local item={Node=node,ContentGui=content,FallbackGui={},SelectedSource=attrs.src or'about:blank'}
  local child
  local frames=Frames.start(parent,{IFrameItems={item}},error,function(_,markup,options)
   child=setup(markup,options);child.Page.Destroy=function()child:Destroy()end;return child.Page
  end,{IFrameResolver=function(_,address)return{Kind='internal',URL=address,Name='Child',Website={HTML=html,Options={}}}end})
  assert(child,'Native frame fixture mounted')
  assert((child.Page.DocumentOrigin==inherited)==(case.kind=='srcdoc'),'Only unsandboxed srcdoc inherits its parent origin; a changed base URL does not change origin')
  child:Run(initialize);child:Activate(case.activation);compare(child,case.specExpected or case.expected,case.name)
  frames:Destroy();content:Destroy();parent.Alive=false;checked+=1
 end
 local interaction=[=[[target.matches(':open'),document.activeElement.localName,target.value,pickerEvents.join(',')].join('|')]=]
 for _,case in reference.interactions do
  local api=setup('<style>select,select::picker(select){appearance:'..case.appearance..'}</style><button id=launch onclick="s.showPicker()">Start</button><select id=s><option value=a>A</option><option value=b>B</option></select>')
  api:Run([=[globalThis.target=document.getElementById('s');globalThis.pickerEvents=[];for(let type of ['focus','blur','input','change'])document.addEventListener(type,e=>{if(e.target.localName!=='button')pickerEvents.push(type+':'+e.target.localName)},true)]=])
  local function check(expected)
   local wanted=table.concat({tostring(expected.open),expected.focus,expected.value,table.concat(expected.events,',')},'|')
   assert(api:Read(interaction)==wanted,case.name..': '..tostring(api.Realm.Window.Get('pickerSnapshot'))..' != '..wanted);checked+=1
  end
  api:ClickLaunch();check(case.states[1]);local select=Node.findById(api.Document,'s');local box=api.Tree:PickerBox(select);local old=box and box.Gui
  if case.action=='commit'then api:Key(Enum.KeyCode.Down);check(case.states[2]);api:Key(Enum.KeyCode.Return)
  elseif case.action=='escape'then api:Key(Enum.KeyCode.Escape)
  else api:Activate(true);api:Run('target.showPicker()');assert(not old or api.Tree:PickerBox(select).Gui==old,'Repeated showPicker retains the actual CSS/GUI tree')end
  check(case.states[#case.states]);api:Destroy()
 end
 -- Tuple origins normalize scheme/host/default port; opaque tokens never
 -- become equal merely because a URL origin would serialize as "null".
 assert(Origin.fromURL('HTTPS://example.test:443/one')==Origin.fromURL('https://example.test/two'),'Tuple origin normalization')
 assert(Origin.fromURL('https://example.test:444')~=Origin.fromURL('https://example.test'),'Nondefault ports distinguish origins')
 assert(Origin.fromURL('blob:https://example.test/token')==Origin.fromURL('https://example.test'),'Blob URL tuple origin')
 local document=Node.document();local token=Origin.ensure(document,'data:text/html,one');assert(token==Origin.ensure(document,'https://changed-url.test')and token~=Origin.fromURL('data:text/html,one'),'Document origin is immutable and opaque identities are distinct')
 print('Select showPicker: '..checked..' native precondition/frame/real-click/keyboard/repeat states, descriptors, normative precedence, retained picker and lifecycle passed')
end
