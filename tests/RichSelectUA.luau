--!strict
return function(Parser,Node,Computed,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local function signal()
  local entries={};local api={}
  function api:Connect(fn)local connection={Connected=true};function connection:Disconnect()self.Connected=false end;table.insert(entries,{connection,fn});return connection end
  function api:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
  function api:Count()local n=0;for _,entry in entries do if entry[1].Connected then n+=1 end end;return n end
  return api
 end
 local allocated={};local factory={create=function(class,parent,props)
  local gui=table.clone(props or{});gui.ClassName,gui.Parent=class,parent;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(800,600);gui.Visible=true
  if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0);gui.ScrollBarThickness=10 end
  local signals={};function gui:GetPropertyChangedSignal(key)signals[key]=signals[key]or signal();return signals[key]end
  function gui:IsA(kind)return kind==class or kind=='GuiObject'end
  function gui:Destroy()assert(not self.Destroyed,'UA picker double cleanup');self.Destroyed=true;for _,child in allocated do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
  table.insert(allocated,gui);return gui
 end};factory.modifier=factory.create
 local renderer=loadRenderTree(factory)
 local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=(utf8.len(text)or 0)*size*.5,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local Popup=require('Input/SelectPopup');local Picker=require('Rendering/PickerFragments');local checked,controls=0,0
 local function near(a,b,label)assert(math.abs(a-b)<.04,label..': '..tostring(a)..' != '..tostring(b))end
 for _,case in reference.cases do
  local document=Parser.parseDocument(case.html);local parent=factory.create('Frame',nil,{});local root=factory.create('ScrollingFrame',parent,{})
  parent.AbsolutePosition=Vector2.new(11,19);root.AbsolutePosition=Vector2.new(43,67)
  local tree=renderer.build(document,root,error);local select=Node.findById(document,'s');local control=tree.Controls[1];local page={Alive=true,Root=root}
  local popup=Popup.new(page,function()end,factory,nil,Picker.new(page,tree,error,{PickerLayout=layout}))
  function page:SetControlPickerOpen(_,open)tree:SetCSSState('open',if open then select else nil)end
  local view,surface,style,options
  for index,step in case.steps do
   if step.left~=nil then select.Attributes.style='left:'..step.left..'px;top:'..step.top..'px';tree:ApplyDOMChanges({[select]={Attributes={style=true}}})end
   if step.viewport then root.AbsoluteSize=Vector2.new(step.viewport.width,step.viewport.height)end
   tree.ViewportHeight=root.AbsoluteSize.Y;layout.arrange(tree,root.AbsoluteSize.X,0,0,function()return true end)
   local expected=case.expected[index]
   -- The native capture preserves Chromium's additional 1lh minimum. Its
   -- companion native control removes only that extra rule to exercise the
   -- normative HTML UA recipe, which has no minimum on the block axis.
   if expected.normativeControl then controls+=1;expected=expected.normativeControl end
   local rect=expected.select
   control.Item.BoxGui.AbsolutePosition=Vector2.new(root.AbsolutePosition.X+rect[1],root.AbsolutePosition.Y+rect[2]);control.Item.BoxGui.AbsoluteSize=Vector2.new(rect[3],rect[4])
   if index==1 then
    popup:Open(control);view=assert(popup.PickerView,'UA base picker mounted').Tree;surface,style=view.Gui,view.Style;options={}
    for _,option in control.Options do options[option.Node]=view.NodeBoxes[option.Node].Gui end
   else
    if step.viewport then root:GetPropertyChangedSignal('AbsoluteSize'):Fire()else control.Item.BoxGui:GetPropertyChangedSignal('AbsolutePosition'):Fire()end
    assert(popup.Control==control and popup.PickerView.Tree==view and view.Gui==surface and view.Style==style and not surface.Destroyed,'UA movement/resize preserves open picker and style identity')
   end
   local placed=assert(popup.PickerView.Placement,'UA picker uses generic position-area solver')
   near(placed.X,expected.rect[1],case.name..' state '..index..' x');near(placed.Y,expected.rect[2],case.name..' state '..index..' y')
   near(view.OuterWidth,expected.rect[3],case.name..' width');near(view.OuterHeight,expected.rect[4],case.name..' height')
   local host=view.Gui.Parent.Parent;near(host.Position[1],placed.X+32,'Retained host x');near(host.Position[2],placed.Y+48,'Retained host y')
   local actual=Computed.read(view.AnchorUsedStyle or view.Style,nil,{Width=root.AbsoluteSize.X,Height=root.AbsoluteSize.Y}).Values
   assert(actual['position-area']==expected.area and actual['position-try-order']==expected.order and actual['position-try-fallbacks']==expected.tries,case.name..': UA area/fallback cascade or selected geometry is wrong')
   for _,option in control.Options do assert(view.NodeBoxes[option.Node].Gui==options[option.Node]and option.Node.Parent==select,'UA fallback preserves author DOM and option resources')end
   checked+=1
  end
  popup:Close();assert(surface.Destroyed and root:GetPropertyChangedSignal('AbsoluteSize'):Count()==0 and control.Item.BoxGui:GetPropertyChangedSignal('AbsolutePosition'):Count()==0,'UA close releases surfaces/subscriptions')
  page.Alive=false;parent:Destroy()
 end
 assert(checked==150 and controls==150,'UA native reference coverage changed')
 print('Rich select UA: '..checked..' native anonymous picker bounds, 5 writing modes, fallback/resize/retention states and '..controls..' explicit native normative-minimum controls passed')
end
