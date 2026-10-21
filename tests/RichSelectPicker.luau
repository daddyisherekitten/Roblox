--!strict
return function(Parser,Node,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local function signal()
  local listeners={};local api={}
  function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
  function api:Fire(...)for _,entry in listeners do if entry[1].Connected then entry[2](...)end end end
  return api
 end
 local allocated={};local factory={create=function(class,parent,props)
  local gui=table.clone(props);gui.ClassName,gui.Parent=class,parent;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(800,600);gui.Visible=true
  if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0)end
  local signals={};function gui:GetPropertyChangedSignal(key)signals[key]=signals[key]or signal();return signals[key]end
  function gui:Destroy()
   assert(not self.Destroyed,'Double picker cleanup');self.Destroyed=true
   for _,child in allocated do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil
  end
  table.insert(allocated,gui);return gui
 end};factory.modifier=factory.create
 local renderer=loadRenderTree(factory)
 local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.5,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local Popup=require('Input/SelectPopup');local Picker=require('Rendering/PickerFragments');local checked=0
 for _,case in reference.cases do
  local document=Parser.parseDocument(case.html);local parent=factory.create('Frame',nil,{});local root=factory.create('ScrollingFrame',parent,{})
  local tree=renderer.build(document,root,error,nil,nil,nil,function()return 'rbxassetid://1'end);layout.arrange(tree,800,0,0,function()return true end)
  local select=Node.findById(document,'s');local control=tree.Controls[1];local page={Alive=true,Root=root}
  local original=table.clone(select.Children);local originalParents={};for _,id in case.targets do local n=Node.findById(document,id);originalParents[n]=n.Parent end
  control.Item.BoxGui.AbsolutePosition=Vector2.new(8,8);control.Item.BoxGui.AbsoluteSize=Vector2.new(200,34)
  local arrangements=0;local measuredLayout={naturalWidth=layout.naturalWidth,arrange=function(...)arrangements+=1;return layout.arrange(...)end}
  local popup=Popup.new(page,function()end,factory,nil,Picker.new(page,tree,error,{PickerLayout=measuredLayout}))
  function page:SetControlPickerOpen(_,open)tree:SetCSSState('open',if open then select else nil)end
  popup.StateChanged=function(name,node)tree:SetCSSState(name,node)end
  popup:Open(control);assert(popup.PickerView,'Custom picker must mount its whole CSS tree')
  local view=popup.PickerView.Tree;local retained=view.Gui;local surfaces={}
  for _,id in case.targets do local node=Node.findById(document,id);surfaces[node]=view.NodeBoxes[node].Gui end
  for i,step in case.steps do
   local changes={}
   for id,css in step.styles or{}do local node=Node.findById(document,id);node.Attributes.style=css;changes[node]={Attributes={style=true}}end
   if step.picker then
    local sheet=Node.findById(document,'pickerChanges')
    if not sheet then
     sheet=Node.element('style',{id='pickerChanges'});Node.append(sheet,Node.text(''));Node.append(Node.findElement(document,function(n)return n.Name=='head'end),sheet);changes[sheet.Parent]={Children=true}
    end
    sheet.Children[1].Text='select::picker(select){scrollbar-width:none;appearance:base-select;'..step.picker..'}';changes[sheet]={Text=true}
   end
   if next(changes)then tree:ApplyDOMChanges(changes)end
   control.Item.BoxGui.AbsoluteSize=Vector2.new(tonumber((select.Attributes.style or''):match('width:(%d+)px'))or 200,34)
   popup:Refresh();assert(popup.PickerView.Tree==view and view.Gui==retained and not retained.Destroyed,'Picker CSS changes preserve its actual render tree/root')
   local expected=case.expected[i]
   assert(math.abs(view.OuterWidth-expected.width)<.04,case.name..' width '..i..': '..view.OuterWidth..' != '..expected.width)
   assert(math.abs(view.OuterHeight-expected.height)<.04,case.name..' height '..i..': '..view.OuterHeight..' != '..expected.height)
   local geometry={}
   local function walk(box,x,y)
    for _,child in box.Children do if child.Kind~='Words'then
     local left,top=x+(child.LayoutX or 0),y+(child.LayoutY or 0);geometry[child.Node]={left,top,child.OuterWidth,child.OuterHeight};walk(child,left,top)
    end end
   end
   walk(view,view.LayoutX or 0,view.LayoutY or 0)
   for id,wanted in expected.boxes do
    local node=Node.findById(document,id);local box=view.NodeBoxes[node]
    assert(box.Gui==surfaces[node]and node.Parent==originalParents[node],case.name..': original option/group surface or DOM parent changed')
    if wanted.hidden then assert(box.Style.Hidden,'Native hidden option remains hidden')else
     local actual=geometry[node];for j,value in wanted do assert(math.abs(actual[j]-value)<.04,case.name..' state '..i..' '..id..' geometry '..j..': '..tostring(actual[j])..' != '..value)end
    end
   end
   for j,node in original do assert(select.Children[j]==node,'Anonymous picker root must not alter author select children')end
   checked+=1
  end
  local before=arrangements;local first=control.Options[1].Node
  tree:SetCSSState('hover',first);assert(not popup.PickerView:RefreshState()and arrangements==before,'Option hover paints without another picker layout')
  assert(view.NodeStyles[first].Background and view.NodeStyles[first].BackgroundAlpha==.1,'Option hover obeys UA paint: '..case.name..'/'..tostring(view.NodeStyles[first].BackgroundAlpha))
  if case.name=='Default picker shares normal rich option and group flow'then
   local function hasWord(text)for _,item in view.TextItems do if item.Text==text then return true end end;return false end
   local group=Node.findById(document,'g');local groupGui=view.NodeBoxes[group].Gui
   local added=Node.element('option',{value='added'});Node.append(added,Node.text('Added'));Node.append(select,added)
   control.Options,_,control.SelectRows=require('Controls/SelectOptions').read(select);popup:Refresh()
   local addedGui=view.NodeBoxes[added].Gui;assert(hasWord('Added')and view.Gui==retained and view.NodeBoxes[group].Gui==groupGui,'Adding an option reuses the picker and unrelated group')
   Node.removeChild(select,added);control.Options,_,control.SelectRows=require('Controls/SelectOptions').read(select);popup:Refresh()
   assert(addedGui.Destroyed and not view.NodeBoxes[added]and view.Gui==retained,'Removing an option releases only its owned content')
   group.Attributes.label='Changed group';popup:Refresh()
   assert(hasWord('Changed')and view.NodeBoxes[group].Gui==groupGui,'Dynamic anonymous group label updates on the same group surface')
   local legend=Node.element('legend',{});local italic=Node.element('i',{});Node.append(italic,Node.text('Legend'));Node.append(legend,italic);Node.insertBefore(group,legend,group.Children[1]);popup:Refresh()
   local legendGui=view.NodeBoxes[legend].Gui;assert(hasWord('Legend')and not hasWord('Changed')and view.NodeBoxes[group].Gui==groupGui,'First rich legend replaces only the anonymous label')
   Node.removeChild(group,legend);popup:Refresh();assert(legendGui.Destroyed and hasWord('Changed')and view.NodeBoxes[group].Gui==groupGui,'Removing a legend restores its current label and releases legend resources')
   first.Attributes.label='Label';popup:Refresh();assert(hasWord('Label')and not hasWord('Alpha')and view.NodeBoxes[first].Gui==surfaces[first],'Label replaces visible option contents on the retained box')
   first.Attributes.label=nil;popup:Refresh();assert(hasWord('Alpha')and not hasWord('Label')and view.NodeBoxes[first].Gui==surfaces[first],'Removing label restores rich contents')
   local oldChecks={};for _,item in view.TextItems do if item.Style.PseudoElement=='checkmark'then oldChecks[item.Style.Node]=item.Gui end end
   local second=control.Options[2].Node;tree:SetCSSState('form-state',{[select]={SelectedOptions={[second]=true}}});popup:Refresh()
   local selected=0;for _,item in view.TextItems do if item.Style.PseudoElement=='checkmark'and item.Style.Visibility=='visible'then selected+=1 end end
   assert(selected==1 and view.Gui==retained,'Live selectedness recascades checkmarks in the whole picker')
   control.Item.Style.Appearance='auto';popup:Refresh();assert(retained.Destroyed and not popup.PickerView,'Native picker mode releases its whole custom tree')
   control.Item.Style.Appearance='base-select';popup:Refresh();assert(popup.PickerView and popup.PickerView.Tree.Gui~=retained,'Base mode remounts only the picker CSS contents on its retained host')
   retained=popup.PickerView.Tree.Gui
  end
  popup:Close();assert(retained.Destroyed and not popup.PickerView,'Closing releases the whole picker tree')
  page.Alive=false;parent:Destroy()
 end
 assert(checked==20,'Native whole-picker coverage unexpectedly changed')
 print('Rich select picker: '..checked..' native box/grid/option/scroll/percentage geometry states, original DOM and retained CSS trees passed')
end
