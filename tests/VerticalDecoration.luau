--!strict
return function(Parser,DOM,Style,Computed,FontMetrics,loadRenderTree,loadWordLayout,reference,loadTextDecoration)
 local fixtureElement=require('DOM/Node').element
 local allocated,requests={},0
 local function create(class,parent,props)
  local gui=table.clone(props);gui.ClassName,gui.Parent,gui.Visible=class,parent,true
  function gui:IsA(name)return self.ClassName==name end
  function gui:Destroy()self.Destroyed=true;for _,child in allocated do if child.Parent==self and not child.Destroyed then child:Destroy()end end end
  table.insert(allocated,gui);return gui
 end
 local renderer=loadRenderTree({create=create});local metrics=table.clone(FontMetrics)
 function metrics.resolve(style)local value=FontMetrics.resolve(style);value.TextSize=style.FontSize;return value end
 local layout=loadWordLayout({['Layout/TextDecoration']=loadTextDecoration({create=create}),['Layout/FontMetrics']=metrics,['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text)
  requests+=1;return Vector2.new(assert(reference.measurements[text],'Missing native decoration measure: '..text),reference.nativeHeight)
 end}})
 local function near(a,b,tolerance,message)assert(math.abs(a-b)<=tolerance,message..': '..a..' vs '..b)end
 local function css(record)
  return 'font-family:monospace;font-size:16px;line-height:24px;white-space:pre;text-autospace:no-autospace;writing-mode:'..record.writingMode..';text-orientation:'..record.orientation..';direction:'..record.direction
 end
 local function geometry(item,frame)
  local w,h=item.Gui.Size[1],item.Gui.Size[2];local rotation=item.Gui.Rotation or 0
  local x,y=frame.Position[1],frame.Position[2];local width,height=frame.Size[1],frame.Size[2]
  -- Decoration coordinates belong to retained word labels, including their
  -- native clockwise/counterclockwise rotation. Compare their physical axes.
  if rotation==90 then return h-y-height,x,height,width,h/2,w/2
  elseif rotation==-90 then return y,w-x-width,height,width,h/2,w/2
  else return x,y,width,height,w/2,h/2 end
 end
 local checked=0
 for _,entry in reference.grammar do
  local warnings=0;local style=Style.resolve(fixtureElement('span',{style='text-underline-position:under;text-underline-position:'..entry.value}),{Font='Roboto',FontSize=16,Color=Color3.new(0,0,0)},function()warnings+=1 end,true)
  assert((warnings==0)==entry.supported,'Native underline-position grammar '..entry.value)
  if not entry.supported then assert(style.UnderlinePosition=='under','Invalid combinations preserve the earlier declaration')end
 end
 for _,record in reference.records do
  local document=Parser.parse('<div id="sample" style="'..css(record)..'"><span id="decorated" style="'..record.spanCSS..'">'..record.source..'</span></div>')
  local tree=renderer.build(document,{},error);local node=DOM.findById(document,'sample');local run=tree.NodeBoxes[node].Children[1];run.HeightBasis=80
  layout.arrange(run,80,0,0,function()return true end)
  local item=run.Items[1];assert(#run.Items==1,'One logical word per native paint reference')
  local key=record.writingMode..'/'..record.orientation..'/'..record.direction..'/'..record.position..'/'..record.kind..'/'..record.source
  assert(#item.DecorationFrames==1 and item.DecorationFrames[1].Visible,'One actual retained decoration band '..key)
  local x,y,w,h,cx,cy=geometry(item,item.DecorationFrames[1]);local vertical=record.writingMode~='horizontal-tb';local paint=assert(record.paint,'Native line must actually paint')
  near(if vertical then h else w,if vertical then paint.height else paint.width,.61,'Native painted inline extent '..key)
  near(if vertical then w else h,2,0,'Two physical device pixels across the projected line '..key)
  local computed=Computed.read(tree.NodeStyles[DOM.findById(document,'decorated')],nil,{Width=80,Height=80})
  assert(computed.Values['text-underline-position']==record.computed,'Actual computed canonical position '..key)
  -- Positions and font metrics are UA-defined. Establish the physical side
  -- from painted pixels, without converting Chromium offsets into font fits.
  if record.kind~='line-through'then
   local own=if vertical then x+w/2-cx else y+h/2-cy
   local native=if vertical then paint.x+paint.width/2-record.textRect.x-record.textRect.width/2 else paint.y+paint.height/2-record.textRect.y-record.textRect.height/2
   assert(own*native>0,'Native physical underline/overline side '..key)
  elseif vertical and (record.writingMode=='vertical-rl'or record.writingMode=='vertical-lr')and record.orientation~='sideways'then
   near(x+w/2,cx,.001,'Vertical typographic strike uses the central baseline '..key)
  end
  local count,calls=#allocated,requests;local frame=item.DecorationFrames[1]
  layout.arrange(run,80,0,0,function()return true end)
  assert(#allocated==count and requests==calls and item.DecorationFrames[1]==frame,'Identical decoration paint retains frames and native per-word measurements')
  checked+=1
 end
 local document=Parser.parse('<div id="stable" style="font-family:monospace;font-size:16px;line-height:24px;white-space:pre;text-autospace:no-autospace;text-decoration:underline overline line-through;text-decoration-thickness:2px;text-decoration-skip-ink:none">天地</div><input id="unrelated" value="keep">')
 local tree=renderer.build(document,{},error);local node=DOM.findById(document,'stable');local box=tree.NodeBoxes[node];local run=box.Children[1];run.HeightBasis=80
 layout.arrange(run,80,0,0,function()return true end)
 local item,control=run.Items[1],tree.Controls[1];local gui,controlGui=item.Gui,control.Gui;local frames=table.clone(item.DecorationFrames)
 local base=node.Attributes.style
 for _,mode in {'vertical-rl','vertical-lr','sideways-rl','sideways-lr','horizontal-tb','vertical-rl'}do
  node.Attributes.style=base..';writing-mode:'..mode..';text-underline-position:under right'
  tree:ApplyDOMChanges({[node]={Attributes={style=true}}})
  assert(box.Children[1]==run and run.Items[1]==item and item.Gui==gui,'Uniform logical pieces retain word ownership through decoration axis changes')
  layout.arrange(run,80,0,0,function()return true end)
  for index,frame in frames do assert(item.DecorationFrames[index]==frame and frame.Visible,'Decoration bands survive mode changes')end
  assert(control.Gui==controlGui and control.Value=='keep','Unrelated controls survive decoration axis changes')
 end
 local count,calls=#allocated,requests
 node.Attributes.style..=';text-decoration-color:blue';tree:ApplyDOMChanges({[node]={Attributes={style=true}}})
 assert(#allocated==count and requests==calls and item.DecorationFrames[1]==frames[1],'Color changes retain projected bands without measuring text')
 node.Attributes.style..=';text-decoration:none';tree:ApplyDOMChanges({[node]={Attributes={style=true}}});layout.arrange(run,80,0,0,function()return true end)
 for _,frame in frames do assert(frame.Visible==false,'Removing decorations hides retained frames')end
 node.Attributes.style..=';text-decoration:underline overline line-through';tree:ApplyDOMChanges({[node]={Attributes={style=true}}});layout.arrange(run,80,0,0,function()return true end)
 for index,frame in frames do assert(item.DecorationFrames[index]==frame and frame.Visible,'Returning decorations reuses retained frames')end
 item.Gui:Destroy();for _,frame in frames do assert(frame.Destroyed,'Decoration children dispose with their word owner')end
 local patternedDocument=Parser.parse('<div id="patterned" style="font-family:monospace;font-size:16px;line-height:24px;writing-mode:vertical-rl;text-orientation:mixed;text-autospace:no-autospace;white-space:normal;text-decoration:underline wavy;text-decoration-thickness:2px;text-decoration-skip-ink:none">天地 ABC</div>')
 local pattern={Width=8,Height=6,Content='retained-pattern'};local cache={Get=function()return pattern end}
 local patternedTree=renderer.build(patternedDocument,{},error,nil,cache);local patternedNode=DOM.findById(patternedDocument,'patterned');local patternedRun=patternedTree.NodeBoxes[patternedNode].Children[1];patternedRun.HeightBasis=80
 layout.arrange(patternedRun,80,0,0,function()return true end)
 local first,second=patternedRun.Items[1],patternedRun.Items[2]
 assert(first.VerticalAdvance and not second.VerticalAdvance,'Native mixed typographic sample has an upright and a rotated piece')
 local image=first.DecorationImages[1];local frame=first.DecorationFrames[1]
 assert(image.Rotation==90 and image.AnchorPoint.X==.5 and frame.Size[1]==pattern.Height,'Upright raster patterns rotate inside the physical vertical band')
 assert(second.DecorationImages[1].Rotation==0 and second.DecorationImages[1].ImageContent==image.ImageContent,'Sideways pattern inherits word rotation and reuses the same cached pixels')
 local count,calls=#allocated,requests;layout.arrange(patternedRun,80,5,7,function()return true end)
 assert(first.DecorationImages[1]==image and first.DecorationFrames[1]==frame and #allocated==count and requests==calls,'Pattern translation retains labels, bands and per-word measurements')
 local origin=first.Style.Decorations[1];assert(second.Style.Decorations[1]==origin,'Mixed pieces share the decorating box origin')
 -- Explicit under offsets start at the text edge; percentages retain their
 -- origin size. These are CSS semantics, not a fabricated Chromium font fit.
 local baseStyle={Font='Roboto',FontSize=16,Color=Color3.new(0,0,0)}
 local zero=Style.resolve(fixtureElement('u',{style='text-underline-position:under;text-underline-offset:0px'}),baseStyle,error,true)
 local negative=Style.resolve(fixtureElement('u',{style='text-underline-position:under;text-underline-offset:-3px'}),baseStyle,error,true)
 assert(zero.Decorations[1].UnderlineOffset-negative.Decorations[1].UnderlineOffset==3,'Negative offsets move inward from the same content edge')
 local child=Style.resolve(fixtureElement('span',{style='font-size:32px;text-underline-position:left;text-underline-offset:10px'}),zero,error,true)
 assert(child.Decorations[1]==zero.Decorations[1],'A descendant position/size cannot alter an ancestor decoration origin')
 print('Vertical decorations: '..checked..' actual native paint axis/extent/side comparisons, native grammar/computed values and retained mode/color/disposal; exact UA font offsets remain explicit')
end
