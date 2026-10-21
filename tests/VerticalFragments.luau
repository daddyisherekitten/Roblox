--!strict
return function(Parser,DOM,FontMetrics,loadRenderTree,loadWordLayout,reference,Selection,loadTextSelection)
 local allocated={}
 local function create(class,parent,props)
  local gui=table.clone(props);gui.ClassName,gui.Parent,gui.Visible=class,parent,true
  function gui:IsA(name)return self.ClassName==name end
  function gui:Destroy()self.Destroyed=true end
  table.insert(allocated,gui);return gui
 end
 local renderer=loadRenderTree({create=create});local metrics=table.clone(FontMetrics)
 local pointer=loadTextSelection({['Rendering/GuiFactory']={create=create},['Layout/TextMeasure']={measure=function(text)return Vector2.new(assert(reference.measurements[text],'Missing native selection fragment measure'),reference.nativeHeight)end}})
 function metrics.resolve(style)local value=FontMetrics.resolve(style);value.TextSize=style.FontSize;return value end
 local calls=0;local layout=loadWordLayout({['Layout/FontMetrics']=metrics,['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text)
  calls+=1;return Vector2.new(assert(reference.measurements[text],'Missing native fragment measure: '..text),reference.nativeHeight)
 end}})
 local function near(a,b,message)assert(math.abs(a-b)<.04,message..': '..a..' vs '..b)end
 local function absolute(gui,owner)
  local source=owner or gui;local position,size=source.Position,source.Size;local anchor=source.AnchorPoint or Vector2.new(0,0)
  gui.AbsolutePosition=Vector2.new(position[1]-size[1]*anchor.X,position[2]-size[2]*anchor.Y);gui.AbsoluteSize=Vector2.new(size[1],size[2]);gui.AbsoluteRotation=source.Rotation or 0
 end
 local compared,gaps=0,0
 for _,record in reference.records do
  local document=Parser.parse('<div id="sample" style="'..record.css..'"><span id="fragment" style="'..record.spanCSS..'">'..record.source..'</span></div>')
  local tree=renderer.build(document,{},error);local node=DOM.findById(document,'sample');local run=tree.NodeBoxes[node].Children[1];run.HeightBasis=240
  layout.arrange(run,120,0,0,function()return true end)
  tree.TextSelection=pointer.new(tree)
  for _,item in run.DisplayItems or run.Items do if item.Gui and item.Kind~='Break'then absolute(item.Gui);if item.TextGui then absolute(item.TextGui,item.Gui)end end end
  local key=record.writingMode..'/'..record.orientation..'/'..record.direction..'/'..record.source..'/'..record.decoration
  assert(run.FragmentPool and #run.FragmentPool==#record.rects,'Native inline fragment count '..key)
  for index,slot in run.FragmentPool do
   local native=record.rects[index]
   near(slot.Width,native.width,'Native inline fragment width '..key);near(slot.Height,native.height,'Native inline fragment height '..key)
   local vertical=record.writingMode~='horizontal-tb'
   near(if vertical then slot.LocalY else slot.LocalX,if vertical then native.y else native.x,'Native inline fragment inline-axis position '..key)
   assert(slot.Gui.Rotation==nil or slot.Gui.Rotation==0,'CSS physical border sides are never rotated with text')
  end
  local count,requests=#allocated,calls;local gui=run.FragmentPool[1].Gui
  layout.arrange(run,120,0,0,function()return true end)
  assert(#allocated==count and calls==requests and run.FragmentPool[1].Gui==gui,'Unchanged fragments retain their frames and per-owner measurements')
  for _,character in record.chars do if character.text==' 'then
   local text=DOM.findById(document,'fragment').Children[1];local native=character.rects[1]
   local selection=Selection.new({Document=document,Alive=true,Root={AbsolutePosition=Vector2.new(0,0)}},tree,{HasPending=function()return false end})
   local rects=selection:RangeRects(text,character.start,text,character.start+1);assert(#rects==1,'Collapsed source space yields one native range '..key)
   local rect=rects[1];local vertical=record.writingMode~='horizontal-tb'
   near(if vertical then rect.Y else rect.X,if vertical then native.y else native.x,'Native collapsed range inline position '..key)
   near(rect.Width,native.width,'Native collapsed range width '..key);near(rect.Height,native.height,'Native collapsed range height '..key)
   selection:Apply(text,character.start,text,character.start+1);local owner,gap=next(tree.TextSelection.Gaps);assert(owner and gap,'Collapsed vertical source gap is painted')
   local selectedCount,selectedCalls=#allocated,calls
   selection:Apply(text,character.start,text,character.start+1)
   assert(tree.TextSelection.Gaps[owner]==gap and #allocated==selectedCount and calls==selectedCalls,'Repeated gap selection retains its frame without measuring words')
   layout.arrange(run,120,7,11,function()return true end)
   for _,item in run.DisplayItems or run.Items do if item.Gui and item.Kind~='Break'then absolute(item.Gui);if item.TextGui then absolute(item.TextGui,item.Gui)end end end
   selection:Apply(text,character.start,text,character.start+1)
   local moved=selection:RangeRects(text,character.start,text,character.start+1)[1]
   near(moved.X,rect.X+7,'Moving a retained flow projects its selected gap X '..key);near(moved.Y,rect.Y+11,'Moving a retained flow projects its selected gap Y '..key)
   assert(tree.TextSelection.Gaps[owner]==gap and #allocated==selectedCount and calls==selectedCalls,'Flow translation retains the selected gap and all measurements')
   selection:Destroy();assert(gap.Destroyed and tree.TextItemsByGui[gap]==nil,'Gap highlight disposal removes its source registration');gaps+=1
  end end
  compared+=1
 end
 print('Vertical fragments: '..compared..' native border/background inline-axis dimensions, '..gaps..' actual native collapsed-space ranges and retained frames passed; cross-baseline font calibration remains separate')
end
