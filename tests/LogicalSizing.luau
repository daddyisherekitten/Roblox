--!strict
return function(Parser,Node,Style,Computed,Declarations,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local allocated=0
 local function create(class,parent,props)
  allocated+=1;local gui=table.clone(props);gui.ClassName,gui.Parent=class,parent
  function gui:Destroy()assert(not self.Destroyed,'Logical sizing double disposal');self.Destroyed=true end
  return gui
 end
 local renderer=loadRenderTree({create=create,modifier=create})
 local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=#text*size/2,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local compared,differences=0,0
 for _,case in reference.cases do
  local document=Parser.parseDocument(case.html);local warnings={}
  local tree=renderer.build(document,{AbsoluteSize=Vector2.new(800,600)},function(w)table.insert(warnings,w)end)
  tree.ViewportHeight=600
  local target,parent=Node.findById(document,'target'),Node.findById(document,'parent')
  local surface,identity,allocations
  for index,step in case.steps do
   target.Attributes.style=step.style;local changes={[target]={Attributes={style=true}}}
   if step.parentWidth then parent.Attributes.style='width:'..step.parentWidth..'px';changes[parent]={Attributes={style=true}}end
   local _,items=tree:ApplyDOMChanges(changes)
   Dirty.begin(tree,if index==1 then nil else items);layout.arrange(tree,step.width,0,0,function()return true end);Dirty.finish(tree,true)
   local box=tree.NodeBoxes[target];local expected=(case.specExpected or case.expected)[index]
   for i,value in {box.OuterWidth,box.OuterHeight}do assert(math.abs(value-expected.rect[i])<.04,case.name..' state '..index..' geometry '..i..': '..value..' != '..expected.rect[i])end
   local values=Computed.read(box.Style,box,{Width=step.width,Height=600}).Values
   for i,name in reference.names do
    local actual,wanted=values[name],expected.values[i]
    local a,b=actual and actual:match('^([%d%.%-]+)px$'),wanted:match('^([%d%.%-]+)px$')
    assert(actual==wanted or a and b and math.abs(tonumber(a)-tonumber(b))<.04,case.name..' state '..index..' CSSOM '..name..': '..tostring(actual)..' != '..wanted)
   end
   if not surface then surface,identity=box.Gui,box.Style end
   assert(box.Gui==surface and box.Style==identity,'Logical/physical axis transitions must retain GUI and style identity')
   allocations=allocated;Dirty.begin(tree,{});layout.arrange(tree,step.width,0,0,function()return true end);Dirty.finish(tree,true)
   assert(allocated==allocations,'Unchanged logical dimensions must not allocate GUI')
   compared+=1
  end
  if case.specExpected then differences+=1 end
 end
 for _,name in {'inline-size','block-size','min-inline-size','min-block-size','max-inline-size','max-block-size'}do
  local source=name..': calc(25% + 10px); writing-mode: vertical-rl;'
  local entries=Declarations.parse(source);assert(Declarations.serialize(entries)==source,'Logical dimension CSSOM preserves property identity and math: '..name)
  local invalid=Declarations.parse(name..': -2px;');assert(#invalid==0,'Negative logical dimension is invalid: '..name)
 end
 local a=Style.resolve(Node.element('div',{style='writing-mode:vertical-rl;inline-size:120px;block-size:70px'}),{},error)
 local b=Style.resolve(Node.element('div',{style='writing-mode:vertical-rl;inline-size:120px;block-size:70px;color:red'}),{},error)
 assert(a.Width.Value==b.Width.Value and a.Height.Value==b.Height.Value,'Color mutation preserves paired physical dimension fields')
 for _,record in reference.axisOrder do
  local style=Style.resolve(Node.element('div',{style='position:absolute;inset:0;'..record.css}),{},error)
  local border={require('Layout/BorderGeometry').sizes(style)}
  for family,field in {margin='Margin',padding='Padding',border='BorderSides',inset='Inset',['scroll-padding']='ScrollPadding',['scroll-margin']='ScrollMargin'}do
   for index,wanted in record.values[family]do
    local value=if field=='Inset'then style[({'Insettop','Insetright','Insetbottom','Insetleft'})[index]]elseif field=='BorderSides'then border[index]else style[field][index]
    local actual=if type(value)=='number'then value elseif value then value.Value else nil
    if type(wanted)=='number'then assert(actual==wanted,'Final axis declaration order '..record.mode..'/'..record.direction..'/'..family..'/'..index..': '..tostring(actual)..' != '..wanted)end
   end
  end
  for index,wanted in record.values.radius do local actual=style.BorderRadii[index].X.Value;assert(actual==wanted,'Final logical corner declaration order')end
 end
 assert(compared==208 and differences==10,'Logical sizing native coverage unexpectedly changed')
 print('Logical sizing: '..compared..' native geometry/CSSOM states, '..differences..' explicit namesake inheritance differences, five writing modes, ordering, importance, variables, rollback, constraints and retained resize passed')
end
