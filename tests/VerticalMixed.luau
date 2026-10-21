--!strict
return function(Parser,DOM,Orientation,BidiPaint,FontMetrics,loadRenderTree,loadWordLayout,Selection,reference,loadTextSelection)
 local allocated,requests={},0
 local function create(class,parent,props)
  local gui=table.clone(props);gui.ClassName,gui.Parent,gui.Visible=class,parent,true
  function gui:IsA(name)return self.ClassName==name end
  function gui:Destroy()self.Destroyed=true end
  table.insert(allocated,gui);return gui
 end
 local renderer=loadRenderTree({create=create})
 local textSelection=loadTextSelection({['Rendering/GuiFactory']={create=create},['Layout/TextMeasure']={measure=function(text)return Vector2.new(assert(reference.measurements[text],'Native selected-prefix measurement missing: '..text),reference.nativeHeight)end}})
 local nativeMetrics=table.clone(FontMetrics)
 function nativeMetrics.resolve(style)local value=FontMetrics.resolve(style);value.TextSize=style.FontSize;return value end
 local layout=loadWordLayout({['Layout/FontMetrics']=nativeMetrics,['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)
  requests+=1;local width=reference.measurements[text];assert(width~=nil,'Native vertical measurement missing: '..text)
  return {X=width,Y=reference.nativeHeight}
 end}})
 local function near(a,b,message)assert(math.abs(a-b)<.04,message..': '..a..' vs '..b)end
 local function absolute(gui,owner)
  local source=owner or gui;local position=source.Position or UDim2.fromOffset(0,0);local size=source.Size or UDim2.fromOffset(0,0)
  local anchor=source.AnchorPoint or Vector2.new(0,0)
  gui.AbsolutePosition=Vector2.new(position[1]-size[1]*anchor.X,position[2]-size[2]*anchor.Y);gui.AbsoluteSize=Vector2.new(size[1],size[2]);gui.AbsoluteRotation=source.Rotation or 0
 end
 assert(Orientation.class(0x41)=='R'and Orientation.class(0x5929)=='U'and Orientation.class(0x3001)=='Tu'and Orientation.class(0x30fc)=='Tr')
 assert(Orientation.class(0x10fffd)=='U'and Orientation.class(0x10ffff)=='R','Private-use and unassigned defaults come from pinned Unicode data')
 assert(Orientation.cluster('Ä')=='R'and Orientation.cluster('B⃝')=='U','Combining enclosing marks make the entire grapheme upright')
 local comparisons,axisComparisons,pointerRanges=0,0,0
 for _,record in reference.records do
  local document=Parser.parse('<div id="sample" style="font-family:Roboto;font-size:16px;line-height:24px;white-space:pre;text-autospace:no-autospace;writing-mode:'..record.writingMode..';text-orientation:'..record.orientation..';direction:'..record.direction..'">'..record.source..'</div>')
  local tree=renderer.build(document,{},error);local node=DOM.findById(document,'sample');local run=tree.NodeBoxes[node].Children[1];run.HeightBasis=record.height
  tree.TextSelection=textSelection.new(tree)
  layout.arrange(run,record.width,0,0,function()return true end)
  local key=record.source..'/'..record.writingMode..'/'..record.orientation..'/'..record.direction
  assert(tree.NodeStyles[node].Direction==record.computedDirection,'upright affects used direction, not the inherited computed value')
  for _,item in run.DisplayItems or run.Items do
   if item.Kind~='Word'and item.Kind~='Space'then continue end
   local first,last=math.huge,-math.huge;local source={}
   for _,span in item.SourceSpans or {}do for _,character in record.chars do if character.start>=span.Start and character.start<span.Finish then
    table.insert(source,character);for _,rect in character.rects do if rect.height>0 and character.text~='\n' then first=math.min(first,rect.y);last=math.max(last,rect.y+rect.height)end end
   end end end
   if first~=math.huge and not record.geometryLimit then
    local inline=if record.writingMode=='sideways-lr'then record.height-item.X-item.Width else item.X
    near(inline,first,'Native vertical inline position '..key..':'..item.Text);near(item.Width,last-first,'Native vertical inline extent '..key..':'..item.Text)
   end
   if item.VerticalAdvance and item.Kind=='Word'then
    assert(item.Gui.Rotation==0 and item.UprightPool,'Upright pieces preserve whole graphemes')
    for _,glyph in item.UprightPool do if glyph.Gui.Visible then assert(glyph.TextGui.Text==BidiPaint.text(item,glyph.Text)and glyph.Gui.Rotation==nil,'Grapheme contents are never individually rotated')end end
   elseif item.Kind=='Word'then assert(item.Gui.Rotation==(if record.writingMode=='sideways-lr'then -90 else 90),'Sideways words preserve native horizontal composition')end
  end
  local count,calls=#allocated,requests;layout.arrange(run,record.width,0,0,function()return true end)
  assert(#allocated==count and requests==calls,'Unchanged vertical projection retains glyphs and per-owner measurements')
  local selection=Selection.new({Document=document,Alive=true,Root={AbsolutePosition=Vector2.new(0,0)}},tree,{HasPending=function()return false end})
  assert(selection:RenderedText(node,0,node,#node.Children)==record.copied,'Vertical visual orientation retains native logical selection copy')
  for _,item in run.DisplayItems or run.Items do if item.Kind=='Word'and item.Text=='ABC'and not item.VerticalAdvance then
   absolute(item.Gui);if item.TextGui then absolute(item.TextGui,item.Gui)end
   local rect=tree.TextSelection:Rect(item,0,1);local native
   for _,character in record.chars do if character.start==item.SourceSpans[1].Start then native=character.rects[1];break end end
   near(rect.Y,native.y,'Rotated source range start '..key);near(rect.Height,native.height,'Rotated source range advance '..key)
   local localX=reference.measurements[BidiPaint.text(item,'A')]*.2
   if item.BidiDirection=='rtl'then localX=item.Width-localX end
   local angle=math.rad(item.Gui.Rotation);local dx=localX-item.Width/2
   local point=Vector2.new(item.Gui.AbsolutePosition.X+item.Width/2+dx*math.cos(angle),item.Gui.AbsolutePosition.Y+item.Height/2+dx*math.sin(angle))
   local picked=tree.TextSelection:Pick({item.TextGui or item.Gui},point)
   assert(picked and picked.Item==item and picked.Offset==0,'Rotated pointer keeps the original logical source boundary '..key)
   selection:Apply(item.SourceSpans[1].Node,item.SourceSpans[1].Start,item.SourceSpans[1].Node,item.SourceSpans[1].Start+1)
   local overlay=tree.TextSelection.Overlays[item];assert(overlay and not overlay.Upright and overlay.Frame.Parent==(item.TextGui or item.Gui),'Sideways selection inherits the retained word rotation')
   local frame=overlay.Frame;selection:Apply(node,0,node,0);assert(frame.Destroyed and tree.TextItemsByGui[frame]==nil,'Rotated selection clears overlay and registration');pointerRanges+=1
  end end
  selection:Destroy();assert(DOM.textContent(document)==record.source);comparisons+=1;if not record.geometryLimit then axisComparisons+=1 end
 end
 local dynamicDocument=Parser.parse('<div id="mixed" style="font-family:Roboto;font-size:16px;line-height:24px;white-space:pre;text-autospace:no-autospace;writing-mode:vertical-rl;text-orientation:mixed">天地ABC天地</div><div id="uniform" style="font-family:Roboto;font-size:16px;line-height:24px;white-space:pre;text-autospace:no-autospace;writing-mode:vertical-rl;text-orientation:mixed">天地</div><input id="editor" value="kept">')
 local tree=renderer.build(dynamicDocument,{},error);local mixed,uniform,editor=DOM.findById(dynamicDocument,'mixed'),DOM.findById(dynamicDocument,'uniform'),DOM.findById(dynamicDocument,'editor')
 local mixedBox,uniformBox=tree.NodeBoxes[mixed],tree.NodeBoxes[uniform]
 local mixedRun,uniformRun=mixedBox.Children[1],uniformBox.Children[1];mixedRun.HeightBasis=240;uniformRun.HeightBasis=240
 layout.arrange(mixedRun,120,0,0,function()return true end);layout.arrange(uniformRun,120,0,0,function()return true end)
 assert(#mixedRun.Items==3 and mixedRun.Items[1].VerticalOrientation=='upright'and mixedRun.Items[2].VerticalOrientation=='sideways','One word is segmented by whole-grapheme orientation')
 local input=tree.Controls[1];assert(input.Node==editor);local controlGui,inputState=input.Gui,input.Value
 local text=uniform.Children[1];local item=uniformRun.Items[1];local retainedItem,retainedGui,retainedGlyph=item,item.Gui,item.UprightPool[1].Gui
 absolute(item.Gui)
 local selection=Selection.new({Document=dynamicDocument,Alive=true,Root={AbsolutePosition=Vector2.new(0,0)}},tree,{HasPending=function()return false end})
 local rects=selection:RangeRects(text,0,text,1);assert(#rects==1);near(rects[1].Height,16,'Upright DOM Range maps one source grapheme to its vertical cell')
 local picked=tree.TextSelection:Pick({item.UprightPool[2].TextGui},Vector2.new(item.Gui.AbsolutePosition.X+8,item.Gui.AbsolutePosition.Y+20))
 assert(picked and picked.Item==item and picked.Offset==1 and tree.TextSelection:Point(picked).Offset==1,'Upright hit traversal resolves the logical source boundary')
 selection:Apply(text,0,text,1);local overlay=tree.TextSelection.Overlays[item]
 assert(overlay and overlay.Upright and overlay.Frame.Size[2]==16 and overlay.Frame.Size[1]==reference.nativeHeight,'Selection uses vertical source-cell advances and the native font box across the line')
 local overlayGui,copyGui=overlay.Frame,overlay.Glyphs[1];selection:Destroy()
 assert(overlayGui.Destroyed and tree.TextItemsByGui[overlayGui]==nil and tree.TextItemsByGui[copyGui]==nil,'Upright selection cleanup removes every retained overlay registration')
 local base=uniform.Attributes.style
 for _,change in {'text-orientation:upright','text-orientation:sideways','writing-mode:sideways-rl;text-orientation:upright','writing-mode:sideways-lr;text-orientation:upright','writing-mode:vertical-lr;text-orientation:mixed','writing-mode:horizontal-tb;text-orientation:mixed','text-orientation:mixed'}do
  uniform.Attributes.style=base..';'..change;tree:ApplyDOMChanges({[uniform]={Attributes={style=true}}})
  assert(uniformBox.Children[1]==uniformRun and uniformRun.Items[1]==retainedItem and retainedItem.Gui==retainedGui,'Unchanged logical orientation pieces retain their owners and GUIs')
  layout.arrange(uniformRun,120,0,0,function()return true end)
  if retainedItem.VerticalAdvance then assert(retainedItem.UprightPool[1].Gui==retainedGlyph,'Upright pools survive reversible orientation changes')else assert(retainedGlyph.Visible==false,'Inactive upright glyphs are hidden when horizontal/sideways paint returns')end
  assert(input.Gui==controlGui and input.Value==inputState,'Text mode changes preserve unrelated native input state')
 end
 local oldGui=mixedRun.Items[1].Gui;mixed.Attributes.style=mixed.Attributes.style..';text-orientation:sideways';tree:ApplyDOMChanges({[mixed]={Attributes={style=true}}})
 assert(mixedBox.Children[1]~=mixedRun and oldGui.Destroyed,'A changed logical orientation partition regenerates only its own word flow')
 assert(uniformBox.Children[1]==uniformRun and input.Gui==controlGui,'Regrouping mixed text preserves neighboring words and controls')
 print('Vertical mixed: '..axisComparisons..' native inline-axis layouts, '..comparisons..' source-copy/retention cases and '..pointerRanges..' native rotated ranges/hits; native fallback/cluster limitations retained explicitly')
end
