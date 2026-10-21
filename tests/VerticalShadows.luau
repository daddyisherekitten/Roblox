--!strict
return function(Parser,DOM,FontMetrics,loadRenderTree,loadWordLayout,reference)
 local allocated,requests={},0
 local function create(class,parent,props)
  local gui=table.clone(props);gui.ClassName,gui.Parent,gui.Visible=class,parent,true
  function gui:IsA(name)return self.ClassName==name end
  function gui:Destroy()self.Destroyed=true;for _,child in allocated do if child.Parent==self and not child.Destroyed then child:Destroy()end end end
  table.insert(allocated,gui);return gui
 end
 local renderer=loadRenderTree({create=create});local metrics=table.clone(FontMetrics)
 function metrics.resolve(style)local value=FontMetrics.resolve(style);value.TextSize=style.FontSize;return value end
 local layout=loadWordLayout({['Layout/FontMetrics']=metrics,['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text)
  requests+=1;return Vector2.new(assert(reference.measurements[text],'Missing native shadow source measure: '..text),reference.nativeHeight)
 end}})
 local function near(a,b,message)assert(math.abs(a-b)<.001,message..': '..a..' vs '..b)end
 local checked,rotatedNative=0,0
 for _,record in reference.records do
  local sourcePaint,shadowPaint=assert(record.foregroundPaint,'Native source glyphs must paint'),assert(record.shadowPaint,'Native shadow glyphs must paint')
  local nativeX,nativeY=shadowPaint.x-sourcePaint.x,shadowPaint.y-sourcePaint.y
  local nativeRotation=if record.writingMode=='sideways-lr'then -90 else if record.writingMode=='sideways-rl'or(record.writingMode~='horizontal-tb'and(record.orientation=='sideways'or(record.orientation=='mixed'and record.source=='ABC')))then 90 else 0
  -- CSS Writing Modes4 §7.6 explicitly defines shadow offsets as physical.
  -- Chrome currently rotates them with its sideways glyph plane; preserve and
  -- assert that raw browser discrepancy rather than relabel it as parity.
  local browserX,browserY=record.offset[1],record.offset[2]
  if nativeRotation==90 then browserX,browserY=-browserY,browserX elseif nativeRotation==-90 then browserX,browserY=browserY,-browserX end
  assert(math.abs(nativeX-browserX)<=1 and math.abs(nativeY-browserY)<=1,'Captured browser offset: antialiasing bounds differ by at most one pixel')
  if nativeRotation~=0 then rotatedNative+=1 end
  -- The two different RGB coverage masks retain their raw bounds/counts;
  -- antialiased ink edges are not a font-shape equality test.
  local css='font-family:monospace;font-size:16px;line-height:24px;white-space:pre;text-autospace:no-autospace;writing-mode:'..record.writingMode..';text-orientation:'..record.orientation..';direction:'..record.direction..';text-shadow:'..record.offset[1]..'px '..record.offset[2]..'px red'
  local document=Parser.parse('<div id="sample" style="'..css..'">'..record.source..'</div>');local tree=renderer.build(document,{},error);local node=DOM.findById(document,'sample');local run=tree.NodeBoxes[node].Children[1];run.HeightBasis=80
  layout.arrange(run,80,0,0,function()return true end);local item=run.Items[1]
  local shapes=if item.VerticalAdvance then item.UprightPool else {item}
  for _,shape in shapes do
   local shadow=shape.ShadowLabels[1].Gui;assert(shadow.Visible,'Every source shape has an actual shadow copy')
   local x,y=shadow.Position[1],shadow.Position[2];local rotation=shape.Gui.Rotation or 0
   local physicalX,physicalY=if rotation==90 then -y else if rotation==-90 then y else x,if rotation==90 then x else if rotation==-90 then -x else y
   near(physicalX,record.offset[1],'Normative shadow physical X');near(physicalY,record.offset[2],'Normative shadow physical Y')
   assert(shadow.Text==(shape.TextGui or shape.Gui).Text and shadow.FontFace==(shape.TextGui or shape.Gui).FontFace,'Sharp shadow preserves composed source glyphs and font')
  end
  local count,calls=#allocated,requests;local retained=shapes[1].ShadowLabels[1].Gui
  layout.arrange(run,80,7,11,function()return true end)
  assert(shapes[1].ShadowLabels[1].Gui==retained and #allocated==count and requests==calls,'Moving the flow reuses every sharp copy without measurements')
  checked+=1
 end
 local base='font-family:monospace;font-size:16px;line-height:24px;white-space:pre;text-autospace:no-autospace'
 local document=Parser.parse('<div id="uniform" style="'..base..'">ABC</div><div id="scoped" style="'..base..'">A<span id="middle">B</span>C</div><input id="keep" value="kept">')
 local tree=renderer.build(document,{},error);local node,scoped,middle=DOM.findById(document,'uniform'),DOM.findById(document,'scoped'),DOM.findById(document,'middle')
 local box,run=tree.NodeBoxes[node],tree.NodeBoxes[node].Children[1];run.HeightBasis=80;layout.arrange(run,80,0,0,function()return true end)
 local item,gui=run.Items[1],run.Items[1].Gui;local input,inputGui=tree.Controls[1],tree.Controls[1].Gui
 assert(gui.ClassName=='TextLabel'and item.TextGui==nil,'Initial plain words retain their native source labels')
 local calls=requests;node.Attributes.style=base..';text-shadow:2px 3px red,-4px -5px blue';tree:ApplyDOMChanges({[node]={Attributes={style=true}}})
 assert(box.Children[1]==run and run.Items[1]==item and item.Gui==gui and requests==calls,'Adding sharp shadows preserves native word/source ownership and all measurements')
 assert(item.TextGui and gui.TextTransparency==1 and item.TextGui.ZIndex>item.ShadowLabels[1].Gui.ZIndex,'A retained foreground child keeps both sharp layers behind the source glyphs')
 layout.arrange(run,80,0,0,function()return true end)
 local first,second,foreground=item.ShadowLabels[1].Gui,item.ShadowLabels[2].Gui,item.TextGui
 assert(first.Visible and second.Visible and tree.TextItemsByGui[gui]==item and tree.TextItemsByGui[foreground]==nil,'Hit/source lookup remains on the original native GUI')
 local count=#allocated
 for _,value in {'7px -8px currentcolor','none','2px 3px transparent','2px 3px red,-4px -5px blue'}do
  node.Attributes.style=base..';text-shadow:'..value;tree:ApplyDOMChanges({[node]={Attributes={style=true}}});layout.arrange(run,80,0,0,function()return true end)
  assert(box.Children[1]==run and run.Items[1]==item and item.Gui==gui and item.TextGui==foreground,'Reversible shadow-list/alpha changes retain the actual source and foreground')
  assert(#allocated==count and requests==calls and item.ShadowLabels[1].Gui==first and item.ShadowLabels[2].Gui==second,'Shadow-list changes retain bounded copy slots without measuring source text')
  assert(input.Gui==inputGui and input.Value=='kept','Sharp shadow mutations retain unrelated native input state')
 end
 local scopedBox=tree.NodeBoxes[scoped];local scopedRun=scopedBox.Children[1];local retired=scopedRun.Items[1].Gui
 middle.Attributes.style='text-shadow:2px 3px red';tree:ApplyDOMChanges({[middle]={Attributes={style=true}}})
 scopedRun=scopedBox.Children[1];scopedRun.HeightBasis=80;layout.arrange(scopedRun,80,0,0,function()return true end)
 assert(retired.Destroyed and #scopedRun.Items==3 and not scopedRun.Items[1].ShadowLabels and scopedRun.Items[2].ShadowLabels[1].Gui.Visible and not scopedRun.Items[3].ShadowLabels,'A distinct shadow source scope repartitions exactly the affected original inline word')
 assert(run.Items[1]==item and item.Gui==gui and input.Gui==inputGui,'Effect regrouping retains neighboring words and native controls')
 gui:Destroy();assert(first.Destroyed and second.Destroyed and foreground.Destroyed,'Foreground/copy children dispose with the same retained source GUI')
 print('Vertical shadows: '..checked..' normative physical offsets; '..(checked-rotatedNative)..' actual native paint matches and '..rotatedNative..' raw Chrome rotated-offset differences retained; source parity and retained copies passed')
end
