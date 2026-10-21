--!strict
return function(Parser,Node,Style,Computed,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local allocations,measurements,guis=0,0,{}
 local function create(class,parent,props)allocations+=1;local gui=table.clone(props);gui.ClassName,gui.Parent=class,parent;function gui:Destroy()self.Destroyed=true end;table.insert(guis,gui);return gui end
 local renderer=loadRenderTree({create=create,modifier=create})
 local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)
  measurements+=1;return{X=#text*(reference.glyphWidths[tostring(size)]or reference.glyphWidths['16']*size/16),Y=size}
 end}}
 -- Native Courier advances are captured at the author's CSS font size. The
 -- host's separate Roblox font calibration is not part of this sizing proof.
 overrides['Layout/FontMetrics']={extents=require('Layout/FontMetrics').extents,resolve=function(style)
  local size=math.ceil(style.FontSize);return{TextSize=size,Baseline=math.round(size*.8),Top=math.round(size*.13),XHeight=math.round(size*.3),Bottom=size,Calibrated=true}
 end}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local compared=0
 for _,case in reference.cases do
  local document=Parser.parseDocument(case.html);local warnings={}
  local tree=renderer.build(document,{AbsoluteSize=Vector2.new(800,600)},function(w)table.insert(warnings,w)end,function(f)return f end,nil,nil,function()return'rbxassetid://123'end)
  tree.ViewportHeight=600
  local target,parent=Node.findById(document,'target'),Node.findById(document,'parent');local surface,identity
  for index,step in case.steps do
   local changes={}
   if target.Attributes.style~=step.style then target.Attributes.style=step.style;changes[target]={Attributes={style=true}}end
   if step.parentHeight then parent.Attributes.style='height:'..step.parentHeight..'px';changes[parent]={Attributes={style=true}}end
   local _,items=tree:ApplyDOMChanges(changes)
   local expected=case.expected[index]
   if expected.natural then for _,item in tree.ImageItems do item.IntrinsicWidth,item.IntrinsicHeight=expected.natural[1],expected.natural[2]end end
   Dirty.begin(tree,if index==1 then nil else items);layout.arrange(tree,step.width,0,0,function()return true end);Dirty.finish(tree,true)
   local box=tree.NodeBoxes[target]
   assert(box,'A native block target must retain its real layout/CSSOM box')
   for i,value in {box.OuterWidth,box.OuterHeight}do assert(math.abs(value-expected.rect[i])<.06,case.name..' state '..index..' geometry '..i..': '..value..' != '..expected.rect[i])end
   if expected.lines then
    local lines={};for _,child in box.Children do if child.Kind=='Words'then for _,word in child.Items do if word.Kind=='Word'then table.insert(lines,word.LineIndex)end end end end
    assert(#lines==#expected.lines,case.name..' state '..index..' native word count differs')
    for i,line in lines do assert(line==expected.lines[i],case.name..' state '..index..' word '..i..' line: '..tostring(line)..' != '..expected.lines[i])end
   end
   local values=Computed.read(box.Style,box,{Width=step.width,Height=600}).Values
   for i,name in reference.names do
    local a,b=values[name],expected.values[i];local na,nb=a and a:match('^([%d%.%-]+)px$'),b:match('^([%d%.%-]+)px$')
    assert(a==b or na and nb and math.abs(tonumber(na)-tonumber(nb))<.06,case.name..' state '..index..' CSSOM '..name..': '..tostring(a)..' != '..b)
   end
   if expected.child then local child=tree.NodeBoxes[Node.findById(document,'child')];assert(math.abs(child.OuterHeight-expected.child[2])<.04,'Intrinsic preferred height must stay indefinite for percentage children')end
   if not surface then surface,identity=box.Gui,box.Style end
   assert(box.Gui==surface and box.Style==identity,'Intrinsic preferred-height transitions retain GUI/style identity')
   if expected.lines then
    local wordGeometry,surfaces={},{}
    for _,child in box.Children do if child.Kind=='Words'then for _,word in child.Items do table.insert(wordGeometry,{word,word.X,word.Y,word.LineIndex})end end end
    for _,gui in guis do table.insert(surfaces,{gui,gui.Position,gui.Size,gui.Visible})end
    local allocated,measured=allocations,measurements
    layout.naturalWidth(box,step.width,function()return true end,true)
    layout.naturalWidth(box,step.width,function()return true end,false)
    assert(allocations==allocated and measurements==measured,'Intrinsic limit probes reuse original font measurements without native allocation')
    for _,entry in wordGeometry do assert(entry[1].X==entry[2]and entry[1].Y==entry[3]and entry[1].LineIndex==entry[4],'Width probes must not overwrite painted word/column placement')end
    for _,entry in surfaces do assert(entry[1].Position==entry[2]and entry[1].Size==entry[3]and entry[1].Visible==entry[4],'Nonpainting text limit probes must not write retained native geometry')end
   end
   local allocated,measured=allocations,measurements
   Dirty.begin(tree,{});layout.arrange(tree,step.width,0,0,function()return true end);Dirty.finish(tree,true)
   assert(allocations==allocated and measurements==measured,'An unchanged intrinsic-height pass reuses surfaces and native font measurements')
   compared+=1
  end
  assert(#warnings==0,case.name..': '..table.concat(warnings,' | '))
 end
 assert(compared==994,'Intrinsic height native coverage unexpectedly changed')
 local keywords=Style.resolve(Node.element('div',{style='height:max-content;writing-mode:vertical-rl;inline-size:min-content'}),{},error)
 assert(keywords.Height.Intrinsic=='min-content'and keywords.Height.Value==nil,'Intrinsic preferred heights must not be encoded as zero definite lengths')
 -- A native text measurement can suspend and invalidate a page. An aborted
 -- keyword probe must not publish geometry or poison the later full pass.
 local alive,cancelOnce=true,true
 local canceledOverrides=table.clone(overrides)
 canceledOverrides['Layout/TextMeasure']={measure=function(text,_,size)
  if cancelOnce then cancelOnce=false;alive=false end
  return {X=#text*reference.glyphWidths['16'],Y=size}
 end}
 canceledOverrides['Layout/WordLayout']=loadWordLayout(canceledOverrides)
 local canceledLayout=loadBlockLayout(canceledOverrides)
 local source='<!doctype html><style>body{margin:0}#target{width:100px;min-width:min-content;font:16px/20px Courier New;padding:3px;border:2px solid}</style><div id=target>ALPHA BETA GAMMA</div>'
 local document=Parser.parseDocument(source);local tree=renderer.build(document,{},error)
 local retained={};for _,gui in guis do table.insert(retained,{gui,gui.Position,gui.Size})end
 Dirty.begin(tree);canceledLayout.arrange(tree,800,0,0,function()return alive end);Dirty.finish(tree,false)
 assert(not alive,'The cancellation control must actually interrupt the intrinsic text measurement')
 for _,entry in retained do assert(entry[1].Position==entry[2]and entry[1].Size==entry[3],'A canceled intrinsic-limit probe must not publish transient native geometry')end
 alive=true;Dirty.begin(tree);canceledLayout.arrange(tree,800,0,0,function()return alive end);Dirty.finish(tree,true)
 local recovered=tree.NodeBoxes[Node.findById(document,'target')]
 local freshDocument=Parser.parseDocument(source);local fresh=renderer.build(freshDocument,{},error)
 Dirty.begin(fresh);canceledLayout.arrange(fresh,800,0,0,function()return true end);Dirty.finish(fresh,true)
 local freshBox=fresh.NodeBoxes[Node.findById(freshDocument,'target')]
 assert(recovered.OuterWidth==freshBox.OuterWidth and recovered.OuterHeight==freshBox.OuterHeight,'Cancellation recovery must equal a fresh intrinsic-limit layout')
 print('Intrinsic height: '..compared..' native text/box/image/logical/aspect/percentage/constraint states, retained surfaces and unchanged native measure reuse passed')
end
