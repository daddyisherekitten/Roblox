--!strict
return function(Parser,DOM,Style,Directionality,BidiInline,BidiPaint,loadRenderTree,loadWordLayout,loadBlockLayout,Selection,Native,EllipsisNative)
 local function create(class,parent,properties)
  local gui=table.clone(properties);gui.Parent=parent;gui.ClassName=class;gui.Visible=true
  function gui:IsA(name)return self.ClassName==name end
  function gui:Destroy()self.Destroyed=true end
  return gui
 end
 local renderer=loadRenderTree({create=create})
 local parentStyle=Style.resolve(DOM.element('div',{style='direction:rtl;unicode-bidi:isolate-override'}),{Font='Roboto',FontSize=16,Color=Color3.new(0,0,0)},error)
 local childStyle=Style.resolve(DOM.element('span',{}),parentStyle,error,true)
 assert(childStyle.Direction=='rtl'and childStyle.UnicodeBidi=='normal','direction is inherited; unicode-bidi is not')
 for _,mode in {'normal','embed','isolate','bidi-override','isolate-override','plaintext'}do
  local style=Style.resolve(DOM.element('span',{style='unicode-bidi:'..mode}),parentStyle,error,true)
  assert(style.UnicodeBidi==mode,'Every Unicode bidi CSS value works on inline scopes')
 end
 local resetStyle=Style.resolve(DOM.element('span',{style='direction:ltr;unicode-bidi:embed;all:initial'}),parentStyle,error,true)
 assert(resetStyle.Direction=='ltr'and resetStyle.UnicodeBidi=='embed','all intentionally excludes direction and unicode-bidi')
 assert(Style.resolve(DOM.element('span',{style='unicode-bidi:inherit'}),parentStyle,error,true).UnicodeBidi=='isolate-override','Explicit inherit changes a noninherited bidi scope')
 local comparisons=0
 for _,record in Native.records do
  local document=Parser.parse('<div id="sample" style="font-family:Roboto;font-size:16px;line-height:24px;letter-spacing:'..(record.letterSpacing or 0)..'px;text-autospace:no-autospace;text-align:start;direction:'..record.direction..';unicode-bidi:'..record.unicodeBidi..';white-space:'..record.whiteSpace..'">'..record.html..'</div>')
  local source=DOM.textContent(document);local tree=renderer.build(document,{},error);local node=DOM.findById(document,'sample');local box=tree.NodeBoxes[node]
  local measurements=Native.measurements[record.name];local requests=0
  local layout=loadWordLayout({['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)
   requests+=1;local width=measurements[text]
   assert(width~=nil,'Native bidi measurement missing: '..record.name..':'..text)
   return {X=width,Y=size}
  end}})
  local run=box.Children[1];local height=layout.arrange(run,record.width,0,0,function()return true end)
  local key=record.name..'/'..record.direction..'/'..record.unicodeBidi..'/'..record.width
  assert(height==record.height,'Native bidi height '..key..': '..height..' vs '..record.height)
  local starts,cursor={},0
  local function visit(current)
   if current.Kind=='Text'then starts[current]=cursor;for _,code in utf8.codes(current.Text)do cursor+=if code>65535 then 2 else 1 end
   else for _,child in current.Children or {}do visit(child)end end
  end
  visit(document)
  for _,item in run.DisplayItems or run.Items do
   if item.Kind~='Word'or item.Text==''then continue end
   local left,right,line=math.huge,-math.huge,nil;local nativeCharacters={}
   for _,span in item.SourceSpans or {}do
    local start,finish=starts[span.Node]+span.Start,starts[span.Node]+span.Finish
    for _,character in record.chars do if character.start>=start and character.start<finish then
     table.insert(nativeCharacters,character)
     for _,rect in character.rects do if rect.width>0 then
      left=math.min(left,rect.x);right=math.max(right,rect.x+rect.width)
      local row=math.floor(rect.y/24)+1;assert(not line or line==row,'One directional piece stays on one actual native line: '..key);line=row
     end end
    end end
   end
   if line then
    assert(item.LineIndex==line,'Native bidi line '..key..':'..item.Text..': '..item.LineIndex..' vs '..line)
    if (record.letterSpacing or 0)==0 then
     assert(math.abs(item.X-left)<.04,'Native bidi x '..key..':'..item.Text..': '..item.X..' vs '..left)
     assert(math.abs(item.Width-(right-left))<.04,'Native bidi width '..key..':'..item.Text..': '..item.Width..' vs '..(right-left))
    else
     -- Chrome's Range includes one trailing tracking advance, contrary to
     -- CSS Text3 7.2's edge suppression. Preserve that raw browser evidence;
     -- compare the actual independently painted glyphs within each run and
     -- the normative n-1 tracking extent, not an invented raw-width match.
     assert(math.abs(item.Width-(right-left-record.letterSpacing))<.04,'Normative tracked bidi piece extent '..key)
     assert(#item.Glyphs==#nativeCharacters,'Tracked reference has one source character per retained glyph')
     for index,glyph in item.Glyphs do
      local native=nativeCharacters[index].rects[1]
      assert(math.abs(BidiPaint.glyphX(item,glyph)-(native.x-left))<.04,'Native tracked glyph physical position '..key..':'..glyph.Text)
      assert(math.abs(glyph.Width-(native.width-record.letterSpacing))<.04,'Native tracked glyph ink advance '..key..':'..glyph.Text)
     end
    end
   end
   if item.Glyphs then for _,glyph in item.Glyphs do
    assert(glyph.Gui.Text==BidiPaint.text(item,glyph.Text),'Tracked labels paint their owner parity')
    assert(glyph.Gui.TextDirection==(if item.BidiDirection=='rtl'then Enum.TextDirection.RightToLeft else Enum.TextDirection.LeftToRight),'Tracked labels preserve resolved direction')
   end else assert((item.TextGui or item.Gui).Text==BidiPaint.text(item),'Retained labels paint resolved run parity without changing logical owners')end
  end
  local calls=requests;layout.arrange(run,record.width,0,0,function()return true end)
  assert(requests==calls,'Identical bidi layout reuses individual piece measurements: '..key)
  assert(DOM.textContent(document)==source,'Bidi never changes DOM source text: '..key)
  local adapter=Selection.new({Document=document,Alive=true,Root={AbsolutePosition=Vector2.new(0,0)}},tree,{HasPending=function()return false end})
  assert(adapter:RenderedText(node,0,node,#node.Children)==record.copied,'Native logical selection copy '..key)
  adapter:Destroy()
  comparisons+=1
 end
 for _,record in Native.semantic do
  local document=Parser.parse(record.html);local tree=renderer.build(document,{},error);local elements={}
  local function visit(node)if node.Kind=='Element'then table.insert(elements,node)end;for _,child in node.Children or {}do visit(child)end end
  visit(document)
  assert(#elements==#record.styles)
  for index,node in elements do local expected=record.styles[index];local style=tree.NodeStyles[node]
   local bidi=expected.normativeUnicodeBidi or expected.unicodeBidi
   assert(style.Direction==expected.direction and style.UnicodeBidi==bidi,'Native HTML direction/bidi UA '..record.html..':'..node.Name..' => '..style.Direction..'/'..style.UnicodeBidi..' vs '..expected.direction..'/'..bidi)
   if expected.normativeUnicodeBidi then assert(expected.normativeUnicodeBidi=='plaintext'and(expected.unicodeBidi=='isolate'or expected.unicodeBidi=='plaintext'),'Only the recorded HTML Text-state UA/prose discrepancy has a normative expectation')end
   assert((Directionality.of(node)=='rtl')==expected.rtl,'DOM :dir semantics are independent of author CSS direction')
  end
 end
 -- Real DOM mutation/cascade path: an auto owner depends on source text even
 -- without :dir selectors; explicit inner boundaries and other boxes survive.
 local wordLayout=loadWordLayout({['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)
  local count=0;for _,code in utf8.codes(text)do if code<0x202a or code>0x202e then count+=1 end end;return {X=count*5,Y=size}
 end}})
 local blockLayout=loadBlockLayout({['Layout/WordLayout']=wordLayout})
 local function runOf(tree,node)
  for _,child in assert(tree.NodeBoxes[node]).Children do if child.Kind=='Words'then return child end end
  error('No word run for '..tostring(node.Attributes.id))
 end
 local dynamicDocument=Parser.parse('<div id="auto" dir="auto" style="font-family:Roboto;font-size:20px;line-height:20px"><span id="copy">ABC</span><span id="fixed" dir="ltr">123</span></div><input id="editor" value="kept"><div id="after">End</div>')
 local dynamic=renderer.build(dynamicDocument,{},error)
 local auto,copy,fixed=DOM.findById(dynamicDocument,'auto'),DOM.findById(dynamicDocument,'copy'),DOM.findById(dynamicDocument,'fixed')
 local retainedControl,afterBox=dynamic.Controls[1],dynamic.NodeBoxes[DOM.findById(dynamicDocument,'after')]
 local controlGui,afterGui=retainedControl.Item.Gui,afterBox.Gui
 for _,value in {'אבג','ABC','אבג','ABC'}do
  copy.Children[1].Text=value
  assert(dynamic:ApplyDOMChanges({[copy.Children[1]]={Text=true}}),'Changing auto direction or its text requires its own layout')
  blockLayout.arrange(dynamic,150,0,0,function()return true end)
  local expected=if value=='ABC'then 'ltr'else 'rtl'
  assert(dynamic.NodeStyles[auto].Direction==expected and dynamic.NodeStyles[copy].Direction==expected,'Text mutation updates the nearest auto owner and inherited CSS direction')
  assert(dynamic.NodeStyles[fixed].Direction=='ltr','Explicit nested direction remains independent')
  assert(dynamic.Controls[1]==retainedControl and retainedControl.Item.Gui==controlGui and not controlGui.Destroyed,'Auto direction preserves unrelated native controls')
  assert(dynamic.NodeBoxes[afterBox.Node]==afterBox and afterBox.Gui==afterGui and not afterGui.Destroyed,'Auto direction preserves unrelated retained blocks')
 end
 fixed.Children[1].Text='דהו';dynamic:ApplyDOMChanges({[fixed.Children[1]]={Text=true}})
 assert(dynamic.NodeStyles[auto].Direction=='ltr','Text inside a known dir boundary cannot change the outer auto owner')
 assert(DOM.textContent(auto)=='ABCדהו','Direction resolution leaves source text intact')
 -- Source scopes are recomputed for invalid/missing bdi dir as auto. Explicit
 -- CSS direction does not change the HTML :dir semantic.
 local ruledDocument=Parser.parse('<style>#auto:dir(rtl){background:red}#auto:dir(rtl) #copy{color:blue}#after{color:black}#auto:dir(rtl)+#after{color:green}</style><div id="auto" dir="auto" style="direction:ltr"><span id="copy">ABC</span><bdi id="island" dir="invalid">123</bdi></div><div id="after">End</div>')
 local ruled=renderer.build(ruledDocument,{},error);local ruledAuto,ruledCopy,ruledIsland,ruledAfter=DOM.findById(ruledDocument,'auto'),DOM.findById(ruledDocument,'copy'),DOM.findById(ruledDocument,'island'),DOM.findById(ruledDocument,'after')
 ruledCopy.Children[1].Text='אבג';ruled:ApplyDOMChanges({[ruledCopy.Children[1]]={Text=true}})
 assert(ruled.NodeStyles[ruledAuto].Direction=='ltr'and Directionality.of(ruledAuto)=='rtl','Author direction stays independent of HTML auto semantics')
 assert(ruled.NodeStyles[ruledAuto].Background==Color3.fromRGB(255,0,0)and ruled.NodeStyles[ruledCopy].Color==Color3.fromRGB(0,0,255)and ruled.NodeStyles[ruledAfter].Color==Color3.fromRGB(0,128,0),'Semantic :dir invalidates descendant and sibling selectors')
 assert(Directionality.of(ruledIsland)=='ltr','Invalid bdi dir is the undefined auto state, with neutral default ltr')
 ruledIsland.Children[1].Text='דהו';ruled:ApplyDOMChanges({[ruledIsland.Children[1]]={Text=true}})
 assert(ruled.NodeStyles[ruledIsland].Direction=='rtl'and Directionality.of(ruledAuto)=='rtl','Nested bdi changes only its own auto scope')
 for _,direction in {'rtl','ltr','auto'}do
  ruledIsland.Attributes.dir=direction;ruled:ApplyDOMChanges({[ruledIsland]={Attributes={dir=true}}})
  assert(ruled.NodeStyles[ruledIsland].Direction==(if direction=='auto'then 'rtl'else direction),'dir attribute mutation updates the actual bidi scope')
 end
 -- Native/current control values and detached pure DOM values share the weak
 -- semantic association. A JS setter never rewrites the value attribute.
 local JS=require('JavaScript/DOM');local VM=require('JavaScript/VM');local Events=require('Input/Events');local FormModel=require('Controls/FormModel')
 local formDocument=Parser.parse('<style>#control:dir(rtl){color:blue}#control:dir(rtl)+span{color:green}form:has(input:dir(rtl)){background:red}</style><form id="form" dir="auto">ABC<input id="control" type="text" dir="auto" value="ABC"><span id="label">Label</span></form><textarea id="area" dir="auto">ABC</textarea>')
 local formTree=renderer.build(formDocument,{},error);local events=Events.new(error);local snapshots={}
 local function snapshot(c)return {Value=c.Value,Directionality=Directionality.of(c.Node)}end
 for _,c in formTree.Controls do snapshots[c.Node]=snapshot(c)end;formTree:SetCSSState('form-state',snapshots)
 local model=FormModel.new(formDocument,formTree.Controls,events,function(c)
  local nextState=table.clone(snapshots);nextState[c.Node]=snapshot(c);snapshots=nextState;formTree:SetCSSState('form-state',snapshots)
 end)
 local bridge=JS.new(formDocument,{Events=events,Window={},States=formTree.CSSStates,ReadyState='complete',Changed=function()end,GetControl=function()return VM.Undefined end,SetControl=function()error('Unbridged control')end,ControlAdapter={Events=events,ResolveControl=function(node)return model:Resolve(node)end,SetControlValue=function(node,value)model:SetValue(model:Resolve(node),value,false)end,ControlChanged=function(node)model:NotifyChanged(model:Resolve(node))end}})
 local control,label,form,area=DOM.findById(formDocument,'control'),DOM.findById(formDocument,'label'),DOM.findById(formDocument,'form'),DOM.findById(formDocument,'area')
 for _,value in {'אבג','ABC'}do
  bridge.Wrap(control).Set('value',value,true);bridge.Wrap(area).Set('value',value,true)
  local direction=if value=='ABC'then 'ltr'else 'rtl'
  assert(formTree.NodeStyles[control].Direction==direction and formTree.NodeStyles[area].Direction==direction,'Live JS control setters update auto direction through the existing FormModel callback')
  assert(control.Attributes.value=='ABC'and DOM.textContent(area)=='ABC','Live direction changes preserve default value attributes and textarea source')
  assert(Directionality.of(form)=='ltr','An input live value and excluded textarea text cannot change an ancestor auto owner')
  assert(bridge.Wrap(control).Get('matches')({':dir('..direction..')'}),'DOM matches sees live control direction')
  assert(formTree.NodeStyles[label].Color==(if direction=='rtl'then Color3.fromRGB(0,128,0)else Color3.new(0,0,0)),'Form snapshots retain the old live value for sibling :dir invalidation')
  assert((formTree.NodeStyles[form].Background~=nil)==(direction=='rtl'),'Relational :has(:dir) compares old and new values')
 end
 bridge.Wrap(control).Set('value','אבג',true);bridge:Destroy()
 assert(Directionality.of(control)=='rtl','Disposing JS alone leaves renderer-owned current control direction intact')
 model:Destroy();events:Destroy()
 local bareDocument=Parser.parse('<div dir="rtl"><input id="bare" type="text" dir="auto" value="ABC"></div>')
 local bare=JS.new(bareDocument,{Window={},ControlAdapter={},ReadyState='complete',Changed=function()end,GetControl=function()return VM.Undefined end,SetControl=function()error('Unbridged control')end})
 local bareNode=DOM.findById(bareDocument,'bare');bare.Wrap(bareNode).Set('value','אבג',true)
 assert(Directionality.of(bareNode)=='rtl'and bare.Wrap(bareNode).Get('matches')({':dir(rtl)'}),'Detached/unrendered DOM controls resolve current value without a native view')
 bare:Destroy();assert(Directionality.of(bareNode)=='ltr','Disposed control associations do not leak dirty values into a new realm')
 -- Native shadow/slot direction is independent of ordinary flat-tree CSS
 -- inheritance. Auto slots depend on assigned source text, not just ancestors.
 local shadowDocument=Parser.parse('<div id="host" dir="rtl"><span id="assigned">ABC</span></div>')
 local shadowHost,assigned=DOM.findById(shadowDocument,'host'),DOM.findById(shadowDocument,'assigned')
 local shadow=DOM.shadowRoot('open',shadowHost);shadowHost.InternalShadowRoot,shadowHost.ShadowRoot=shadow,shadow
 local scoped=DOM.element('div',{id='scoped',dir='auto'});local slot=DOM.element('slot',{id='slot',dir='auto'});local inside=DOM.element('span',{id='inside'})
 DOM.append(shadow,scoped);DOM.append(scoped,slot);DOM.append(scoped,inside);DOM.append(inside,DOM.text('123'))
 local shadowTree=renderer.build(shadowDocument,{},error);local nodes={host=shadowHost,assigned=assigned,scoped=scoped,slot=slot,inside=inside}
 for index,step in Native.shadowSteps do
  local operation=step.operation
  if operation then local target=nodes[operation.id]
   if operation.text then target.Children[1].Text=operation.text;shadowTree:ApplyDOMChanges({[target.Children[1]]={Text=true}})
   else target.Attributes.dir=operation.dir;shadowTree:ApplyDOMChanges({[target]={Attributes={dir=true}}})end
  end
  for _,expected in step.styles do local target=nodes[expected.id];local computed=shadowTree.NodeStyles[target]
   assert(computed.Direction==expected.direction and computed.UnicodeBidi==expected.unicodeBidi,'Native shadow computed direction step '..index..':'..expected.id..' => '..computed.Direction..'/'..computed.UnicodeBidi..' vs '..expected.direction..'/'..expected.unicodeBidi)
   assert((Directionality.of(target)=='rtl')==expected.rtl,'Native shadow DOM :dir semantics step '..index..':'..expected.id)
  end
 end
 local ellipsisComparisons=0
 for _,record in EllipsisNative.records do
  local document=Parser.parse('<div id="ellipsis" style="font-family:Roboto;font-size:16px;line-height:24px;white-space:pre;text-autospace:no-autospace;text-align:start;overflow:hidden;text-overflow:ellipsis;direction:'..record.direction..'">'..record.source..'</div>')
  local tree=renderer.build(document,{},error);local node=DOM.findById(document,'ellipsis');local run=runOf(tree,node);local textNode=node.Children[1]
  local metrics=EllipsisNative.measurements[record.source];local calls=0
  local layout=loadWordLayout({['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)
   calls+=1;assert(metrics[text]~=nil,'Ellipsis native substring measurement: '..text);return {X=metrics[text],Y=size}
  end}})
  layout.arrange(run,record.width,0,0,function()return true end)
  local painted={}
  for _,item in run.DisplayItems or run.Items do
   if item.PaintOwner==run then continue end
   for _,span in item.SourceSpans or{}do for index=span.Start+1,span.Finish do painted[index]=true end end
  end
  for _,character in record.chars do if character.text~=' 'then
   assert((painted[character.index]==true)==(character.solidPaintPixels>0),'Actual native ellipsis paint source '..record.source..'/'..record.direction..'/'..record.width..':'..character.index..' => '..tostring(painted[character.index])..' vs '..character.solidPaintPixels)
  end end
  local marker=run.EllipsisPool and run.EllipsisPool[1]
  if marker and marker.Gui.Visible then
   assert(marker.BidiDirection==record.direction and marker.SourceSpans and marker.PaintOwner==run,'Ellipsis retains hidden source intervals and block parity')
   assert(tree.TextItemsByGui[marker.Gui]==marker,'The retained ellipsis remains registered for selection')
  end
  local adapter=Selection.new({Document=document,Alive=true,Root={AbsolutePosition=Vector2.new(0,0)}},tree,{HasPending=function()return false end})
  assert(adapter:RenderedText(textNode,0,textNode,utf8.len(record.source))==record.copied,'Native copying retains all original source despite bidi ellipsis')
  adapter:Destroy()
  local requests=calls;layout.arrange(run,record.width,0,0,function()return true end);assert(requests==calls,'Identical ellipsis reuses individual prefix/suffix measurements')
  local itemCount=#tree.TextItems;local markerGui=marker and marker.Gui
  for _=1,5 do layout.arrange(run,200,0,0,function()return true end);layout.arrange(run,record.width,0,0,function()return true end)end
  assert(#tree.TextItems==itemCount and(not marker or marker.Gui==markerGui and not markerGui.Destroyed),'Bidi ellipsis reflow retains registered marker/word projections')
  assert(DOM.textContent(node)==record.source,'Bidi ellipsis does not edit original source')
  if marker then
   textNode.Text='Replacement';tree:ApplyDOMChanges({[textNode]={Text=true}})
   assert(markerGui.Destroyed and tree.TextItemsByGui[markerGui]==nil and tree.HitNodes[markerGui]==nil,'Regroup disposal removes obsolete ellipsis source/hit/selection registrations')
  end
  ellipsisComparisons+=1
 end
 print('Bidi native renderer: '..(comparisons-18)..' actual logical-piece layouts plus 18 tracked-glyph projections (Chrome edge-advance discrepancy retained), '..ellipsisComparisons..' actual ellipsis paints, shadow/live directionality, native parity labels, source copy and retention passed')
end
