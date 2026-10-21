--!strict
return function(Parser,Node,Style,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local fixtureElement=require('DOM/Node').element
 local allocated=0
 local function create(class,parent,props)
  allocated+=1;local gui=table.clone(props);gui.Parent,gui.ClassName=parent,class
  function gui:Destroy()self.Destroyed=true end
  return gui
 end
 local renderer=loadRenderTree({create=create,modifier=create})
 local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*5,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides)
 local checked=0
 for _,case in reference.cases do
  if case.pending then continue end
  local doc=Parser.parse(case.html);local warnings={}
  local tree=renderer.build(doc,{},function(message)table.insert(warnings,message)end)
  local node=Node.findById(doc,'gapBox');local box=tree.NodeBoxes[node]
  local surfaces={box.Gui};for _,child in box.Children do if child.Kind~='Words'then table.insert(surfaces,child.Gui)end end
  for i,step in case.steps do
   node.Attributes.style=step.style
   local _,changed=tree:ApplyDOMChanges({[node]={Attributes={style=true}}})
   Dirty.begin(tree,if i==1 then nil else changed)
   layout.arrange(tree,step.width,0,0,function()return true end);Dirty.finish(tree,true)
   local actual={box.OuterWidth,box.OuterHeight}
   for _,child in box.Children do if child.Kind~='Words'then
    table.insert(actual,child.LayoutX);table.insert(actual,child.LayoutY);table.insert(actual,child.OuterWidth);table.insert(actual,child.OuterHeight)
   end end
   local expected=case.expected[i];assert(#actual==#expected,case.name..': element count')
   for j,value in actual do assert(math.abs(value-expected[j])<.025,case.name..' state '..i..' value '..j..': '..value..' != '..expected[j])end
   assert(box.Gui==surfaces[1],case.name..': container GUI replaced')
   local surface=2;for _,child in box.Children do if child.Kind~='Words'then assert(child.Gui==surfaces[surface],case.name..': child GUI replaced');surface+=1 end end
   checked+=1
  end
 end
 assert(checked>=35,'Native percentage-gap geometry coverage unexpectedly shrank')
 local function resolve(css,parent,warn)return Style.resolve(fixtureElement('div',{style=css}),parent or {},warn or error)end
 local parsed=resolve('gap:10% calc(20% + 3px)');assert(parsed.Gap[1].Percent and parsed.Gap[2].Expression,'Gap math must remain computed lengths')
 local inherited=resolve('row-gap:inherit;column-gap:inherit',parsed);assert(inherited.Gap[1].Percent and inherited.Gap[2].Expression,'Longhand inheritance retains computed expressions')
 assert(resolve('gap:initial',parsed).Gap[1]==0 and resolve('gap:unset',parsed).Gap[2]==0,'Gaps are non-inherited and reset independently')
 print('Percentage gaps: '..checked..' native flex/grid/multicol geometry states, cyclic intrinsic sizes, computed math, invalid grammar and retained resize surfaces passed')
end
