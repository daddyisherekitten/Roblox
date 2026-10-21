--!strict
return function(Parser,DOM,Style,Computed,FontMetrics,Emphasis,loadRenderTree,loadWordLayout,reference,ScriptSelection,loadTextSelection,GroupOpacity)
 local fixtureElement=require('DOM/Node').element
 local allocated,requests={},0
 local function create(class,parent,props)
  local gui=table.clone(props);gui.ClassName,gui.Parent,gui.Visible=class,parent,props.Visible~=false
  function gui:IsA(name)return self.ClassName==name end
  function gui:Destroy()self.Destroyed=true;for _,child in allocated do if child.Parent==self and not child.Destroyed then child:Destroy()end end end
  table.insert(allocated,gui);return gui
 end
 local function source(value)local text={};for _,code in utf8.codes(value)do if code<0x202a or code>0x202e then table.insert(text,utf8.char(code))end end;return table.concat(text)end
 local renderer=loadRenderTree({create=create});local metrics=table.clone(FontMetrics)
 local pointer=loadTextSelection({['Rendering/GuiFactory']={create=create},['Layout/TextMeasure']={measure=function(text)
  return Vector2.new(assert(reference.measurements[source(text)],'Missing original source pointer prefix'),reference.nativeHeight)
 end}})
 function metrics.resolve(style)local value=FontMetrics.resolve(style);value.TextSize=style.FontSize;return value end
 local layout=loadWordLayout({['Layout/FontMetrics']=metrics,['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)
  requests+=1;text=source(text)
  if size==8 then local mark=reference.markMeasurements[text];return Vector2.new(if mark then mark.width else 8,if mark then mark.height else 9)end
  return Vector2.new(assert(reference.measurements[text],'Missing individual native emphasis source measure: '..text),reference.nativeHeight)
 end}})
 local function near(a,b,tolerance,message)assert(math.abs(a-b)<=tolerance,message..': '..a..' vs '..b)end
 for _,group in {{'text-emphasis-style',reference.grammar.styles},{'text-emphasis-position',reference.grammar.positions}}do
  for _,entry in group[2]do
   local warnings=0;Style.resolve(fixtureElement('span',{style=group[1]..':'..entry.value}),{Font='Roboto',FontSize=16,Color=Color3.new(0,0,0)},function()warnings+=1 end,true)
   if entry.value~=''then assert((warnings==0)==entry.valid,'Native emphasis grammar: '..group[1]..':'..entry.value)end
  end
 end
 local shapeDifferences=0
 for _,entry in reference.shapeDefaults do
  local parent=Style.resolve(fixtureElement('div',{style='writing-mode:'..entry.mode..';text-emphasis-style:'..entry.fill}),{Font='Roboto',FontSize=16,Color=Color3.new(0,0,0)},error)
  local vertical=entry.mode=='vertical-rl'or entry.mode=='vertical-lr'
  assert(parent.TextEmphasisStyle.Shape==(if vertical then 'sesame'else 'circle'),'Normative automatic shape uses typographic mode')
  local child=Style.resolve(fixtureElement('span',{style='writing-mode:'..(if entry.mode=='horizontal-tb'then 'vertical-rl'else 'horizontal-tb')}),parent,error,true)
  assert(child.TextEmphasisStyle.Mark==parent.TextEmphasisStyle.Mark,'Computed shape inherits without choosing a new shape in the child')
  local normalized=(if entry.fill=='open'then 'open 'else '')..parent.TextEmphasisStyle.Shape
  if normalized~=entry.parent or normalized~=entry.child then shapeDifferences+=1 end
 end
 assert(shapeDifferences==10,'Raw native dot defaults/recomputed inherited shapes remain explicit')
 for _,entry in {{'"\\1 foo"','"\\1 foo"'},{'"\\7f A"','"\\7f A"'},{'"\\a X"','"\\a X"'},{'""','""'}}do
  local style=Style.resolve(fixtureElement('span',{style='text-emphasis-style:'..entry[1]}),{Font='Roboto',FontSize=16,Color=Color3.new(0,0,0)},error,true)
  assert(Computed.read(style,nil,{Width=80,Height=80}).Values['text-emphasis-style']==entry[2],'Computed custom marks serialize ASCII controls and empty strings with the shared CSSOM string serializer')
 end
 for _,text in {'A','天','é','#','%','＃','％','@','&','§','¶','⁋','⁓','〽',' ́'}do assert(Emphasis.eligible(text),'Normative emphasis eligibility: '..text)end
 for _,text in {' ',utf8.char(0xa0),',','!','，',utf8.char(1),utf8.char(0x200d),utf8.char(0x378),utf8.char(0x10ffff)}do assert(not Emphasis.eligible(text),'Unicode separators/punctuation/controls/unassigned excluded')end
 local function center(item,mark)
  local rotation=item.Gui.Rotation or 0;local x,y=mark.Gui.Position[1],mark.Gui.Position[2]
  if rotation==90 then return item.Gui.Position[1]-(y-item.Height/2),item.Gui.Position[2]+(x-item.Width/2)
  elseif rotation==-90 then return item.Gui.Position[1]+(y-item.Height/2),item.Gui.Position[2]-(x-item.Width/2)
  else return item.Gui.Position[1]+x,item.Gui.Position[2]+y end
 end
 local checked,sideDifferences,spaceDifference,uprightDifferences=0,0,0,0
 for _,record in reference.records do
  local css='font-family:monospace;font-size:16px;line-height:24px;white-space:pre;text-autospace:no-autospace;writing-mode:'..record.writingMode..';text-orientation:'..record.orientation..';direction:'..record.direction..';color:transparent;text-emphasis:"+" red;text-emphasis-position:'..record.position
  local document=Parser.parse('<div id="sample" style=\''..css..'\'>'..record.source..'</div>');local tree=renderer.build(document,{},error);local node=DOM.findById(document,'sample');local run=tree.NodeBoxes[node].Children[1];run.HeightBasis=80
  local height=layout.arrange(run,80,0,0,function()return true end)
  local computed=Computed.read(tree.NodeStyles[node],nil,{Width=80,Height=80}).Values
  assert(computed['text-emphasis-style']==record.computed.style and computed['text-emphasis-position']==record.computed.position,'Computed custom mark and canonical position match native')
  local vertical=record.writingMode~='horizontal-tb';local marks,expected={},0
  -- CSS Writing Modes 4 §5.1 requires upright characters to be strong LTR;
  -- its implementation note explicitly records missing native RTL overrides.
  -- This fixture keeps Chromium's original punctuation ordering untouched.
  local uprightRTL=record.source=='A, B#%'and record.orientation=='upright'and record.direction=='rtl'and(record.writingMode=='vertical-rl'or record.writingMode=='vertical-lr')
  for _,character in record.characters do if Emphasis.eligible(character.text)then expected+=1 end end
  for _,item in run.Items do for _,mark in item.EmphasisPool or {}do if not mark.Gui.Visible then continue end
   local x,y=center(item,mark);assert((item.Gui.Rotation or 0)+(mark.Gui.Rotation or 0)==0,'Vertical marks stay upright; sideways orientation is our explicit permitted policy')
   local bounds=assert(Emphasis.bounds(item),'Visible real marks contribute compositing overflow')
   assert(bounds[1]<=x-mark.Width/2+.001 and bounds[2]<=y-mark.Height/2+.001 and bounds[3]>=x+mark.Width/2-.001 and bounds[4]>=y+mark.Height/2-.001,'Actual mark boxes fit the compositing viewport in every native writing-mode/RTL projection')
   assert(mark.TextGui.Text=='+'and mark.TextGui.TextSize==8,'Actual mark labels use the first grapheme and 50 percent font size')
   local span;for _,s in item.SourceSpans or {}do if mark.First>=s.FirstByte and mark.First<=s.LastByte then span=s;break end end
   assert(span and span.Node.Parent==node,'Retained mark remains associated with original source word')
   local character;for _,entry in record.characters do if entry.index==span.Start then character=entry;break end end
   assert(character,'Emphasis source span maps to a native original grapheme')
   local r=character.rect;local inline=if vertical then y else x
   local nativeInline=if vertical then r.y+r.height/2 else r.x+r.width/2
   if uprightRTL then
    near(inline,run.Items[1].X+(character.index+.5)*reference.nativeHeight,.025,'Normative upright LTR order retains original punctuation/source indices')
    assert(math.abs(inline-nativeInline)>.025,'Raw native upright RTL ordering discrepancy remains visible');uprightDifferences+=1
   else near(inline,nativeInline,.025,'Native source grapheme inline center '..record.writingMode..'/'..record.orientation..'/'..record.direction..'/'..record.position..'/'..record.source..'/'..character.text)end
   local physicalSide=if vertical then x-(item.Gui.Position[1]+(if item.VerticalAdvance then item.Height/2 else 0))else y-item.Gui.Position[2]-item.Height/2
   local expectedSide
   if record.writingMode=='sideways-lr'then expectedSide=if record.position:find('under',1,true)then 1 else -1
   elseif record.writingMode=='sideways-rl'then expectedSide=if record.position:find('under',1,true)then -1 else 1
   else expectedSide=if record.position:find(if vertical then 'left'else 'under',1,true)then (if vertical then -1 else 1)else(if vertical then 1 else -1)end
   assert(physicalSide*expectedSide>0,'Normative emphasis physical side')
   local closest,distance=nil,math.huge
   for _,paint in record.paint do local point=if vertical then paint.y+paint.height/2 else paint.x+paint.width/2;local d=math.abs(point-(if uprightRTL then nativeInline else inline));if d<distance then distance=d;closest=paint end end
   if character.text==' ́'then assert(#record.paint==expected-1,'Chrome omits the required mark on separator+combining character');spaceDifference+=1
   else
    -- Pixel ink includes the mark font's side bearing and integer raster edges;
    -- the source Range/engine layout comparison above remains at .025 px.
    assert(closest and distance<=1.5,'Actual native mark paint is centered on the original grapheme '..record.writingMode..'/'..record.orientation..'/'..record.direction..'/'..record.source..'/'..character.text..' distance '..distance)
    local nativeSide=if vertical then closest.x+closest.width/2-r.x-r.width/2 else closest.y+closest.height/2-r.y-r.height/2
    if nativeSide*expectedSide<=0 then assert(record.writingMode=='sideways-rl'or record.writingMode=='sideways-lr','Only raw sideways native side discrepancy allowed');sideDifferences+=1 end
   end
   table.insert(marks,mark.Gui)
  end end
  assert(#marks==expected,'Exactly one actual mark per eligible grapheme, excluding separators and punctuation')
  assert(height>24 or expected==0,'Emphasis contributes to line cross extents like ruby')
  assert((if vertical then record.extent.width else record.extent.height)>(if vertical then record.base.width else record.base.height),'Native emphasis also contributes to line cross extents; exact font ascent/descent is retained separately')
  local count,calls=#allocated,requests;layout.arrange(run,80,7,11,function()return true end)
  assert(#allocated==count and requests==calls,'Moving flow reuses every mark and per-word prefix measurement')
  for _,gui in marks do assert(not gui.Destroyed and gui.Visible,'Retained actual mark survives translation')end
  local selection=ScriptSelection.new({Document=document,Alive=true},tree,nil)
  assert(selection:RenderedText(node,0,node,#node.Children)==record.copied,'Native original selection excludes all painted emphasis marks')
  selection:Destroy()
  checked+=1
 end
  assert(spaceDifference==1 and uprightDifferences==32)
 local base='font-family:monospace;font-size:16px;line-height:24px;white-space:pre;text-autospace:no-autospace'
 local document=Parser.parse('<div id="uniform" style=\''..base..'\'>ABC</div><div id="mixed" style=\''..base..';text-emphasis:"+" red\'>A<span id="middle">B</span>C</div><input id="unrelated" value="keep">')
 local tree=renderer.build(document,{},error);local uniform,mixed,middle=DOM.findById(document,'uniform'),DOM.findById(document,'mixed'),DOM.findById(document,'middle')
 local box,run=tree.NodeBoxes[uniform],tree.NodeBoxes[uniform].Children[1];run.HeightBasis=80
 layout.arrange(run,80,0,0,function()return true end)
 local item,gui,control=run.Items[1],run.Items[1].Gui,tree.Controls[1];local controlGui=control.Gui
 local function change(extra)
  uniform.Attributes.style=base..';'..extra;tree:ApplyDOMChanges({[uniform]={Attributes={style=true}}})
  assert(box.Children[1]==run and run.Items[1]==item and item.Gui==gui,'Uniform emphasis changes retain the existing word, native owner and source GUI')
  layout.arrange(run,80,0,0,function()return true end)
  assert(control.Gui==controlGui and control.Value=='keep','Emphasis changes retain unrelated controls and their live state')
 end
 change('text-emphasis:"+" red')
 local marks={};for index,mark in item.EmphasisPool do marks[index]=mark.Gui;assert(tree.TextItemsByGui[mark.Gui]==nil and tree.TextItemsByGui[mark.TextGui]==nil,'Marks do not create selectable text or hit registrations')end
 assert(#marks==3 and #tree.TextItems==2,'Native word ownership excludes additional emphasis labels')
 local allocatedBefore,calls=#allocated,requests
 uniform.Attributes.style=base..';text-emphasis:"+" blue';tree:ApplyDOMChanges({[uniform]={Attributes={style=true}}})
 assert(#allocated==allocatedBefore and requests==calls,'Emphasis color paints retained labels without font/word measurement')
 for _,mark in item.EmphasisPool do assert(mark.TextGui.TextColor3==Color3.fromRGB(0,0,255),'A color-only recascade updates the actual mark')end
 for _,mode in {'vertical-rl','vertical-lr','sideways-rl','sideways-lr','horizontal-tb'}do
  change('text-emphasis:"+" blue;text-emphasis-position:under left;writing-mode:'..mode)
  for index,mark in item.EmphasisPool do assert(mark.Gui==marks[index]and mark.Gui.Visible,'Original mark frames survive reversible writing-mode/position changes')end
 end
 change('text-emphasis:none');for _,mark in item.EmphasisPool do assert(not mark.Gui.Visible,'none hides existing mark frames')end
 change('text-emphasis:"" blue');for _,mark in item.EmphasisPool do assert(not mark.Gui.Visible,'An empty string is a valid invisible mark')end
 change('text-emphasis:"Arest" blue');for index,mark in item.EmphasisPool do assert(mark.Gui==marks[index]and mark.TextGui.Text=='A','Shorthand preserves custom string case and paints only its first grapheme')end
 change('text-emphasis:"+" blue;text-shadow:2px 3px red,-2px -3px blue')
 for _,mark in item.EmphasisPool do
  assert(#mark.ShadowLabels==2 and mark.ShadowLabels[1].Gui.Visible,'Actual emphasis glyphs receive the same retained sharp shadow layers')
  near(mark.ShadowLabels[1].Gui.Position[1],2,0,'Emphasis shadow remains physical right');near(mark.ShadowLabels[1].Gui.Position[2],3,0,'Emphasis shadow remains physical down')
 end
 local selection=ScriptSelection.new({Document=document,Alive=true},tree,nil)
 assert(selection:RenderedText(uniform,0,uniform,#uniform.Children)=='ABC'and selection:CopyText(uniform,0,uniform,#uniform.Children)=='ABC','Rendered selection and plain source copy exclude all emphasis/shadow labels')
 selection:Destroy()
 tree.TextSelection=pointer.new(tree)
 local painted=item.TextGui or item.Gui;painted.AbsoluteSize=Vector2.new(item.Width,item.Height);painted.AbsolutePosition=Vector2.new(item.Gui.Position[1],item.Gui.Position[2]);painted.AbsoluteRotation=0
 local marker=item.EmphasisPool[2];local picked=tree.TextSelection:Pick({marker.TextGui},Vector2.new(painted.AbsolutePosition.X+marker.Gui.Position[1],painted.AbsolutePosition.Y+marker.Gui.Position[2]))
 assert(picked and picked.Item==item and(picked.Offset==1 or picked.Offset==2),'Clicking an actual emphasis child resolves the original second source letter, never the mark text')
 local point=tree.TextSelection:Point(picked);assert(point.Node==uniform.Children[1]and(point.Offset==1 or point.Offset==2),'The original DOM UTF16 source boundary survives mark hit traversal')
 tree.TextSelection:Apply({{Item=item,First=1,Last=2}})
 local overlay=tree.TextSelection.Overlays[item];assert(overlay and overlay.Frame.Parent==painted and tree.TextItemsByGui[marker.Gui]==nil,'Selection paints only the original source glyph interval')
 local frame=overlay.Frame;tree.TextSelection:Destroy();assert(frame.Destroyed and tree.TextItemsByGui[frame]==nil,'Emphasis source selection disposal removes its actual highlight registration')
 run.LayoutX,run.LayoutY=0,0 -- BlockLayout publishes these after WordLayout.
 local bounds=Emphasis.bounds(item,run.LayoutX,run.LayoutY);local composited=GroupOpacity.arrange(run)
 assert(bounds and composited[1]<=bounds[1]and composited[2]<=bounds[2]and composited[3]>=bounds[3]and composited[4]>=bounds[4],'Compositing bounds include actual outside-font-box mark and mark-shadow paint')
 local calls=requests;layout.arrange(run,80,7,11,function()return true end)
 run.LayoutX,run.LayoutY=7,11
 local moved=Emphasis.bounds(item,run.LayoutX,run.LayoutY);for axis=1,4 do near(moved[axis],bounds[axis],.001,'Moving flow retains local compositing mark bounds')end
 assert(requests==calls,'Emphasis compositing projection adds no source measurements')
 local mixedBox=tree.NodeBoxes[mixed];local mixedRun=mixedBox.Children[1];mixedRun.HeightBasis=80;layout.arrange(mixedRun,80,0,0,function()return true end)
 assert(#mixedRun.Items==1 and mixedRun.Items[1].Text=='ABC','Initially identical inherited effects share their existing word')
 local retired=mixedRun.Items[1].Gui
 middle.Attributes.style='text-emphasis-color:blue';tree:ApplyDOMChanges({[middle]={Attributes={style=true}}})
 mixedRun=mixedBox.Children[1];mixedRun.HeightBasis=80;layout.arrange(mixedRun,80,0,0,function()return true end)
 assert(retired.Destroyed and #mixedRun.Items==3,'An actually changed inline effect scope repartitions only its original word flow')
 for index,piece in mixedRun.Items do assert(piece.EmphasisPool[1].TextGui.TextColor3==(if index==2 then Color3.fromRGB(0,0,255)else Color3.fromRGB(255,0,0)),'Distinct original inline scopes receive their own actual mark colors')end
 assert(box.Children[1]==run and item.Gui==gui and control.Gui==controlGui,'A changed source partition retains neighboring words, source GUIs and controls')
 -- Wrapped and elided paint fragments have their own bounded prefix/mark
 -- measurements; their source indices must not alias the hidden full word.
 local wrapped=Parser.parse('<div id="wrap" style=\''..base..';white-space:normal;overflow-wrap:anywhere;text-emphasis:"+" red\'>ABC</div><div id="ellipsis" style=\''..base..';overflow:hidden;text-overflow:ellipsis;text-emphasis:"+" red\'>ABC</div>')
 local projected=renderer.build(wrapped,{},error)
 for _,id in {'wrap','ellipsis'}do
  local owner=DOM.findById(wrapped,id);local flow=projected.NodeBoxes[owner].Children[1];flow.HeightBasis=80
  layout.arrange(flow,22,0,0,function()return true end)
  local original=flow.Items[1];local visible=0
  for _,piece in flow.DisplayItems do
   local count=0;for _,mark in piece.EmphasisPool or {}do if mark.Gui.Visible then count+=1;assert(mark.Last<=#piece.Text,'A paint fragment never reuses full-word emphasis source offsets')end end
   if piece.Text=='…'then assert(count==0,'Punctuation ellipsis has no emphasis mark')else assert(count==utf8.len(piece.Text),'Each visible source letter retains exactly one mark')end
   visible+=count
  end
  assert(visible==(if id=='wrap'then 3 else 1),'Fragmented source paints only its visible eligible marks')
  local count,calls=#allocated,requests;layout.arrange(flow,22,7,11,function()return true end)
  assert(#allocated==count and requests==calls,'Fragment/ellipsis translations retain mark frames and their own native prefix caches')
  layout.arrange(flow,80,0,0,function()return true end)
  assert(flow.Items[1]==original and original.Gui.Visible,'Returning to the complete word retains its original source owner')
  for _,piece in original.WrapPool or {}do assert(not piece.Gui.Visible,'Inactive fragment paint is hidden with its retained emphasis children')end
  local adapter=ScriptSelection.new({Document=wrapped,Alive=true},projected,nil);assert(adapter:RenderedText(owner,0,owner,#owner.Children)=='ABC','Fragment/ellipsis copy uses intact original source text');adapter:Destroy()
 end
 item.Gui:Destroy();for _,mark in item.EmphasisPool do
  assert(mark.Gui.Destroyed and mark.TextGui.Destroyed,'Disposing the source word destroys every retained mark')
  for _,shadow in mark.ShadowLabels or {}do assert(shadow.Gui.Destroyed,'Mark shadow children dispose with the same source owner')end
 end
 print('Vertical emphasis: '..checked..' raw native mark paints and source references; '..sideDifferences..' sideways side differences,32 upright RTL centers,10 shape/inheritance differences and one combining-space difference retained; normative order/sides, native grammar, Unicode eligibility and per-word measurement retention passed')
end
