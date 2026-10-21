--!strict
return function(Parser,Node,Runtime,Events,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local function signal()local api={};function api:Connect()return{Disconnect=function()end}end;return api end
 local allocated={};local factory={create=function(class,parent,props)
  local gui=table.clone(props or{});gui.Parent,gui.ClassName=parent,class;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(800,600);gui.Visible=true
  if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0)end
  function gui:GetPropertyChangedSignal()return signal()end;function gui:IsA(kind)return kind==class or kind=='GuiObject'end
  function gui:Destroy()assert(not self.Destroyed);self.Destroyed=true;for _,child in allocated do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
  table.insert(allocated,gui);return gui
 end};factory.modifier=factory.create
 local renderer=loadRenderTree(factory);local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=(utf8.len(text)or 0)*size*.5,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local checked=0
 local fields={};for _,field in reference.fields do table.insert(fields,string.format('%q',field))end
 for _,case in reference.cases do
  local document=Parser.parseDocument(case.html);local root=factory.create('ScrollingFrame',nil,{})
  local tree=renderer.build(document,root,function(message)assert(message:find('No resolvable source',1,true)or message:find('embedded page',1,true),message)end);tree.ViewportHeight=600
  layout.arrange(tree,800,0,0,function()return true end);local events=Events.new(error);local runtime
  runtime=Runtime.new(document,{Events=events,Diagnostic=error,ApplyChanges=function(changes)return tree:ApplyDOMChanges(changes)end,
   GeometryAdapter={GetTree=function()return tree end,GetViewport=function()return{Width=800,Height=600}end,HasPending=function()return runtime:HasPending()end,
    Flush=function()if runtime:Flush()then layout.arrange(tree,800,0,0,function()return true end)end end}})
  assert(runtime:Run('globalThis.target=document.getElementById("s");globalThis.live=getComputedStyle(target)'))
  local host=tree.Gui;local oldNode=Node.findById(document,'s')
  for _,state in case.states do
   assert(runtime:Run(state.script..';globalThis.hiddenSnapshot=['..table.concat(fields,',')..'].map(k=>live.getPropertyValue(k)).join("|")'))
   local values=string.split(runtime.Window.Get('hiddenSnapshot'),'|')
   local expected=state.specExpected or state.expected
   for index,field in reference.fields do assert(values[index]==expected[field],case.name..' '..state.action..' '..field..': '..tostring(values[index])..' != '..expected[field])end
   assert(Node.findById(document,'s')==oldNode and tree.Gui==host,'Hidden state/style changes keep author DOM and containing page host')
   if case.name=='embed/'and state.action=='hidden'then local s=tree.NodeStyles[oldNode];assert(s.Width.Value==0 and s.Height.Value==0,'hidden embed has the UA zero dimensions')end
   checked+=1
  end
  runtime:Destroy();events:Destroy();root:Destroy()
 end
 assert(checked==108,'Hidden UA native coverage changed')
 print('Hidden UA: '..checked..' native HTML/table/until-found/namespace/override/revert/remove states, live CSSOM and retained host passed')
end
