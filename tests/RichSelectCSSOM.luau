--!strict
return function(Parser,Node,Runtime,Events,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local function signal()
  local entries={};local api={};function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
  function api:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end;return api
 end
 local allocated={};local factory={create=function(class,parent,props)
  local gui=table.clone(props or{});gui.Parent,gui.ClassName=parent,class;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(800,600);gui.Visible=true
  if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0)end
  local signals={};function gui:GetPropertyChangedSignal(key)signals[key]=signals[key]or signal();return signals[key]end
  function gui:IsA(kind)return kind==class or kind=='GuiObject'end
  function gui:Destroy()assert(not self.Destroyed,'CSSOM picker double cleanup');self.Destroyed=true;for _,child in allocated do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
  table.insert(allocated,gui);return gui
 end};factory.modifier=factory.create
 local renderer=loadRenderTree(factory);local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=(utf8.len(text)or 0)*size*.5,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local Popup=require('Input/SelectPopup');local Picker=require('Rendering/PickerFragments');local checked=0
 local names={};for _,name in reference.fields do table.insert(names,string.format('%q',name))end
 local read='globalThis.pickerSnapshot=['..table.concat(names,',')..'].map(k=>livePicker.getPropertyValue(k)).join("|")'
 for _,case in reference.cases do
  local document=Parser.parseDocument(case.html);local parent=factory.create('Frame',nil,{});local root=factory.create('ScrollingFrame',parent,{})
  local tree=renderer.build(document,root,error);tree.ViewportHeight=600
  local select=Node.findById(document,'s');local control=tree.Controls[1];local page={Alive=true,Root=root};local popup=Popup.new(page,function()end,factory,nil,Picker.new(page,tree,error,{PickerLayout=layout}))
  function page:SetControlPickerOpen(_,open)tree:SetCSSState('open',if open then select else nil)end
  local function arrange()layout.arrange(tree,800,0,0,function()return true end);control.Item.BoxGui.AbsolutePosition=Vector2.new(300,230);control.Item.BoxGui.AbsoluteSize=Vector2.new(120,40);if popup.Control then popup:Refresh()end end
  arrange();local events=Events.new(error);local runtime
  runtime=Runtime.new(document,{Events=events,Diagnostic=error,ApplyChanges=function(changes)return tree:ApplyDOMChanges(changes)end,
   GeometryAdapter={GetTree=function()return tree end,GetViewport=function()return{Width=800,Height=600}end,HasPending=function()return runtime:HasPending()end,
    Flush=function()local changed=runtime:Flush();if changed then arrange()elseif popup.Control then popup:Refresh()end end}})
  assert(runtime:Run('globalThis.livePicker=getComputedStyle(document.getElementById("s"),"::picker(select)")'))
  local retained
  for _,state in case.states do
   if state.action=='open'then popup:Open(control);retained=assert(tree:PickerBox(select),'Open picker is registered').Gui
   elseif state.action=='mutate'then
    assert(runtime:Run('let changed=document.createElement("style");changed.textContent='..string.format('%q',state.css)..';document.head.append(changed)'))
   elseif state.action=='close'then popup:Close();assert(retained.Destroyed and tree:PickerBox(select)==nil,'Closed picker drops the used box before a live CSSOM reread')end
   assert(runtime:Run(read));local actual=string.split(runtime.Window.Get('pickerSnapshot'),'|')
   for index,name in reference.fields do assert(actual[index]==state.expected[name],case.name..' '..state.action..' '..name..': '..tostring(actual[index])..' != '..state.expected[name])end
   if state.action=='mutate'then assert(tree:PickerBox(select).Gui==retained and popup.Control==control,'CSSOM mutation retains the actual open picker')end
   checked+=1
  end
  assert(#runtime.Diagnostics==0,'Picker CSSOM must not report diagnostics');runtime:Destroy();events:Destroy();page.Alive=false;parent:Destroy()
 end
 assert(checked==80,'Picker CSSOM native coverage changed')
 print('Rich select CSSOM: '..checked..' native closed/open/percentage/mutation/reclose states, live declarations, actual used boxes and cleanup passed')
end
