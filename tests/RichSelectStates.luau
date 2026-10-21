--!strict
return function(Parser,Node,Selectors,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local allocated=0
 local function create(class,parent,props)
  allocated+=1;local gui=table.clone(props);gui.Parent,gui.ClassName=parent,class
  function gui:Destroy()self.Destroyed=true end
  return gui
 end
 local renderer=loadRenderTree({create=create,modifier=create})
 local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.5,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides)
 local disabled,enabled=Selectors.compile(':disabled'),Selectors.compile(':enabled')
 local checked=0
 for _,case in reference.cases do
  local document=Parser.parseDocument(case.html);local tree=renderer.build(document,{},error)
  layout.arrange(tree,800,0,0,function()return true end)
  local surfaces={};for _,id in case.targets do local n=Node.findById(document,id);surfaces[id]=tree.NodeBoxes[n]and tree.NodeBoxes[n].Gui end
  for i,step in case.steps do
   local changes={}
   for id,css in step.styles or{}do local node=Node.findById(document,id);node.Attributes.style=css;changes[node]={Attributes={style=true}}end
   for id,attrs in step.attributes or{}do
    local node=Node.findById(document,id);local change=changes[node]or {Attributes={}};changes[node]=change
    for name,value in attrs do node.Attributes[name]=if value==false then nil else value;change.Attributes[name]=true end
   end
   local needsLayout=false
   if next(changes)then needsLayout=tree:ApplyDOMChanges(changes)end
   for _,name in {'hover','active'}do if step[name]~=nil then
    local _,needed=tree:SetCSSState(name,if step[name]==false then nil else Node.findById(document,step[name]));needsLayout=needsLayout or needed==true
   end end
   if needsLayout then layout.arrange(tree,800,0,0,function()return true end)end
   for id,expected in case.expected[i]do
    local node=Node.findById(document,id);local style=tree.NodeStyles[node]
    local function paint(actual,alpha,wanted,label)
     if not actual then alpha=0;actual=Color3.new(0,0,0)end
     local values={actual.R*255,actual.G*255,actual.B*255,(alpha or 1)*255}
     for j,value in values do if j==4 or wanted[4]>0 then assert(math.abs(value-wanted[j])<=1.01,case.name..' state '..i..' '..id..' '..label..' channel '..j..': '..value..' != '..wanted[j])end end
    end
    paint(style.Color,style.ColorAlpha,expected.color,'text');paint(style.Background,style.BackgroundAlpha,expected.background,'background')
    assert(Selectors.matches(node,disabled,tree.CSSStates)==expected.disabled and Selectors.matches(node,enabled,tree.CSSStates)==expected.enabled,case.name..': disabled/enabled state '..i..' '..id)
    if expected.metrics then
     local m=expected.metrics;local actual={style.BorderRadius,style.Padding[1],style.Padding[4],style.Gap[1]}
     for j,value in actual do assert(math.abs(value-m[j])<.001,case.name..' UA metric '..j..': '..tostring(value)..' != '..m[j])end
     assert(style.BoxSizing==m[5],'Dropdown UA box sizing')
    end
    if surfaces[id]then assert(tree.NodeBoxes[node].Gui==surfaces[id],case.name..': paint replaced '..id..' GUI')end
   end
   checked+=1
  end
 end
 assert(checked==31,'Native select UA state coverage unexpectedly changed')
 print('Rich select UA: '..checked..' native pointer/disabled/cascade/font states, first-legend eligibility, inherited paint and retained surfaces passed')
end
