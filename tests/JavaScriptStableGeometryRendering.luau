--!strict
-- Mounted DOM/control changes must match an independent final-DOM reflow.
-- Counts are deterministic layout/measurement work, never an FPS benchmark.
return function(Parser,Node,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,View,Controller)
 local measurements,created=0,0
 local factory={}
 function factory.create(class,parent,properties)
  local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent;created+=1
  function gui:Destroy()assert(not self.Destroyed,'Dispose a retained GUI once');self.Destroyed=true;self.Parent=nil end
  return gui
 end
 factory.modifier=factory.create
 local function measure(text,_,size)
  measurements+=1;local width=0
  for _,code in utf8.codes(text)do width+=if code==105 then .2 elseif code==77 then .9 else .5 end
  return {X=width*size,Y=size}
 end
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=measure}}
 local words=loadWordLayout(overrides);overrides['Layout/WordLayout']=words
 local renderer,layout=loadRenderTree(factory),loadBlockLayout(overrides)
 local function snapshot(tree)
  local result={}
  local function add(value)table.insert(result,if type(value)=='number'then string.format('%.5f',value)else tostring(value))end
  local function visit(box)
   add(box.Kind);add(box.Node and((box.Node.Attributes or{}).id or box.Node.Name))
   for _,key in {'LayoutX','LayoutY','OuterWidth','OuterHeight','ContentWidth','ContentHeight','LocalRight','LocalBottom','FirstBaseline'}do add(box[key])end
   for _,item in box.Items or{}do
    add(item.Kind);add(item.Text)
    for _,key in {'X','Y','Width','Height','Baseline','LineIndex'}do add(item[key])end
   end
   for _,child in box.Children or{}do visit(child)end
  end
  visit(tree);return table.concat(result,'|')
 end
 local totalLayouts,totalLocal=0,0
 for _,display in {'block','flex','grid'}do
  local css='body{margin:8px}.controls{display:'..display..';gap:8px;grid-template-columns:auto 1fr}.fixed{width:150px}.same{color:green}button:empty{color:red}#form:has(#fixed:empty){padding:20px}'
  local document=Parser.parseDocument('<!doctype html><html><body><h1 id="heading">Retained heading</h1><form id="form"><div class="controls"><button id="auto" type="button">TEST</button><button id="fixed" class="fixed" type="button">TEST</button><input id="native-submit" type="submit" value="TEST"><input id="native-reset" type="reset" value="TEST"><input id="native-button" type="button" value="TEST"><output id="status">TEST</output><input id="check" type="checkbox"><input id="value" value="initial"><select id="pick"><option id="first">TEST</option><option id="second">TEXT</option></select><select id="wide" class="fixed"><option id="wide-label">TEST</option></select><select id="list" size="3" multiple><optgroup label="TEST"><option id="list-label">TEXT</option></optgroup></select></div></form><p id="following">Following text stays measured.</p><script>void 0;</script></body></html>')
  local root={AbsoluteSize=Vector2.new(520,500)}
  local tree=renderer.build(document,root,error,function(font)return font end,nil,nil,nil,css)
  local events=Events.new(error);local dirtyControls={}
  local model=FormModel.new(document,tree.Controls,events,function(control,needed)
   -- Controller owns editor writes; native text changes do not measure layout.
   if control.Item.Editor then control.Item.Editor.Text=control.Value end
   View.paint(control.Item);if needed then dirtyControls[control.Item]=true end
  end)
  local page={Alive=true,Document=document,DocumentURL='https://example.test/stable',Root=root,Events=events,FormModel=model,Cleanups={}}
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  function page:SetValue(node,value)model:SetValue(model:Resolve(node),value,false)end
  local realm=HTMLScripts.start(page,tree,function()end,error)
  local function arrange(items)
   totalLayouts+=1;tree:SetMediaEnvironment(520,500);tree.ViewportHeight=500
   local stats=Dirty.begin(tree,items);layout.arrange(tree,520,0,0,function()return true end);Dirty.finish(tree,true);return stats
  end
  arrange();realm:Flush()
  local heading=tree.NodeBoxes[Node.findById(document,'heading')]
  local following=tree.NodeBoxes[Node.findById(document,'following')]
  local headingGui,followingGui=heading.Gui,following.Gui
  local function equivalent()
   local fresh=renderer.build(Node.cloneNode(document,true),root,error,function(font)return font end,nil,nil,nil,css)
   fresh:SetMediaEnvironment(520,500);fresh.ViewportHeight=500;Dirty.begin(fresh);layout.arrange(fresh,520,0,0,function()return true end);Dirty.finish(fresh,true)
   assert(snapshot(tree)==snapshot(fresh),'Stable local/fallback mutation differs from independent full layout: '..display)
   assert(heading.Gui==headingGui and following.Gui==followingGui and not headingGui.Destroyed and not followingGui.Destroyed,'Unrelated heading/following surfaces must remain retained')
  end
  local function mutate(code,expectedFallback,expectedNoMeasure)
   local beforeMeasure,beforeCreated,beforeLayouts=measurements,created,totalLayouts
   local oldFollowing=following.Children[1];local oldMeasurement=oldFollowing.Items[1].MeasuredText
   realm:Run(code);assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))
   local needed,items=realm:Flush();items=items or{}
   for item in dirtyControls do items[item]=true;needed=true end;table.clear(dirtyControls)
   local remaining={}
   if needed then for item,reason in items do
    local kept=tree:CanKeepTextLayout(item,words.arrange,function()return true end)or View.canKeepLayout(item,measure,function()return true end)
    if kept then totalLocal+=1 else remaining[item]=reason end
   end end
   local fallback=next(remaining)~=nil
   assert(fallback==expectedFallback,'Unexpected whole/ancestor layout for '..display..': '..code)
   if fallback then local stats=arrange(remaining);assert(stats.Mode=='partial'and stats.Reused>0,'Caption fallback must reuse unrelated branches')end
   if expectedNoMeasure then assert(measurements==beforeMeasure,'A rendered no-op caption must not invalidate font measurements')end
   if not fallback then assert(totalLayouts==beforeLayouts and created==beforeCreated,'Stable geometry needs no block arrangement or replacement native surfaces')end
   assert(following.Children[1]==oldFollowing and oldFollowing.Items[1].MeasuredText==oldMeasurement,'Unrelated text keeps its actual measurement cache')
   equivalent()
  end
  -- Equal native bounds, rather than string length, make an auto button local.
  mutate("document.getElementById('auto').textContent='TEXT';",false,false)
  mutate("document.getElementById('auto').textContent='  TEXT  ';",false,true)
  mutate("document.getElementById('fixed').textContent='LONGER';",false,false)
  mutate("document.getElementById('status').textContent='TEXT';",false,false)
  mutate("document.getElementById('native-submit').value='TEXT';",false,false)
  assert(model:Resolve('native-submit').Item.Label.Text=='TEXT','Input submit.value changes the actually rendered native caption')
  mutate("document.getElementById('native-submit').value='MMMMMMMM';",true,false)
  mutate("document.getElementById('native-reset').value='TEXT';document.getElementById('native-button').defaultValue='TEXT';",false,false)
  assert(model:Resolve('native-reset').Item.Label.Text=='TEXT' and model:Resolve('native-button').Item.Label.Text=='TEXT','Reset/button value modes paint their reflected property captions')
  mutate("document.getElementById('native-submit').defaultValue='TEXT';",true,false)
  mutate("document.getElementById('native-submit').removeAttribute('value');",true,false)
  assert(model:Resolve('native-submit').Item.Label.Text=='Submit','Removing value restores the native submit caption')
  mutate("document.getElementById('auto').value='payload';",false,true)
  assert(model:Resolve('auto').Item.Label.Text=='TEXT','HTMLButtonElement.value does not replace its visible DOM caption')
  -- Equal character counts can have very different font bounds: auto widths
  -- and their grid/flex contributions must still update normally.
  mutate("document.getElementById('auto').textContent='iiii';",true,false)
  mutate("document.getElementById('auto').textContent='MMMM';",true,false)
  mutate("document.getElementById('auto').textContent='';",true,false)
  assert(model:Resolve('auto').Item.Style.Color==Color3.fromRGB(255,0,0),':empty selectors still recascade when the control text path runs')
  mutate("document.getElementById('fixed').style.width='190px';document.getElementById('fixed').textContent='SIZE';",true,false)
  mutate("document.getElementById('fixed').classList.add('same');",false,true)
  assert(model:Resolve('fixed').Item.Style.Color==Color3.fromRGB(0,128,0),'Paint-only classes update the retained control')
  mutate("document.getElementById('check').checked=true;document.getElementById('value').value='changed';",false,true)
  assert(model:Resolve('check').Checked and model:Resolve('value').Item.Editor.Text=='changed','Value/toggle state remains visible without layout')
  mutate("document.getElementById('form').reset();",false,true)
  assert(not model:Resolve('check').Checked and model:Resolve('value').Item.Editor.Text=='initial','Form reset restores native state without geometry work')
  assert(model:Resolve('native-submit').Item.Label.Text=='Submit' and model:Resolve('native-reset').Item.Label.Text=='TEXT' and model:Resolve('native-button').Item.Label.Text=='TEXT','Form reset preserves the current native button default-value captions')
  mutate("document.getElementById('first').textContent='TEXT';",false,false)
  assert(model:Resolve('pick').Item.Label.Text=='TEXT','The selected option caption paints on the retained native select')
  mutate("document.getElementById('second').label='iiii';",false,false)
  mutate("document.getElementById('second').disabled=true;",false,true)
  mutate("document.getElementById('first').label='MMMM';",true,false)
  mutate("document.getElementById('wide-label').textContent='LONGER';",false,false)
  local listRow=model:Resolve('list').Item.SelectRowsByNode[Node.findById(document,'list-label')]
  mutate("document.getElementById('list-label').textContent='TEST';",false,false)
  assert(model:Resolve('list').Item.SelectRowsByNode[Node.findById(document,'list-label')]==listRow and listRow.Label.Text=='TEST','Listbox caption updates preserve the actual native option row')
  mutate("document.getElementById('list-label').selected=true;",false,true)
  mutate("document.getElementById('list-label').textContent='MMMMMMMM';",true,false)
  -- A transform write in the same batch must not hide the text mutation from
  -- :has/:empty dependencies, even when a fixed-width caption remains local.
  mutate("document.getElementById('fixed').textContent='';document.getElementById('fixed').style.transform='translateX(4px)';",true,false)
  assert(tree.NodeStyles[Node.findById(document,'form')].Padding[1]==20,'Native caption metadata preserves ancestor selector geometry')
  assert(tree.NodeStyles[Node.findById(document,'fixed')].Transform~=nil,'Mixed caption/selector batches still paint their authored transform')
  mutate("document.getElementById('fixed').textContent='   ';document.getElementById('fixed').style.transform='translateX(8px)';",true,false)
  assert(tree.NodeStyles[Node.findById(document,'form')].Padding[1]==0,'An unchanged normalized caption still changes the native DOM :empty predicate')
  for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end;model:Destroy();events:Destroy()
 end
 -- Percentage/calc spacing is resolved in-place by real layout. Color and
 -- native focus recascades must retain those pixels without dirtying geometry.
 local function signal()
  local handlers={};local api={}
  function api:Connect(fn)local entry={Connected=true,Fn=fn};function entry:Disconnect()self.Connected=false end;table.insert(handlers,entry);return entry end
  function api:Fire(...)for _,entry in table.clone(handlers)do if entry.Connected then entry.Fn(...)end end end
  return api
 end
 for _,display in {'block','flex','grid'}do
  local native,objects=nil,{}
  local nativeFactory={}
  function nativeFactory.create(class,parent,properties)
   local gui=factory.create(class,parent,properties);gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(600,500)
   gui.Visible=true;gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal()
   local propertiesChanged,attributes,attributeChanged={},{},{}
   function gui:IsA(kind)return kind==class or kind=='GuiObject' and class~='ScreenGui' or kind=='LayerCollector' and class=='ScreenGui'end
   function gui:GetPropertyChangedSignal(name)propertiesChanged[name]=propertiesChanged[name]or signal();return propertiesChanged[name]end
   function gui:GetAttributeChangedSignal(name)attributeChanged[name]=attributeChanged[name]or signal();return attributeChanged[name]end
   function gui:GetAttribute(name)return attributes[name]end
   function gui:SetAttribute(name,value)local old=attributes[name];attributes[name]=value;if old~=value then self:GetAttributeChangedSignal(name):Fire()end end
   function gui:IsFocused()return native==self end
   function gui:CaptureFocus()if native and native~=self then native:ReleaseFocus()end;native=self;self.Focused:Fire()end
   function gui:ReleaseFocus()if native==self then native=nil;self.FocusLost:Fire(false)end end
   if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0)end
   table.insert(objects,gui);return gui
  end
  nativeFactory.modifier=nativeFactory.create
  local screen=nativeFactory.create('ScreenGui',nil,{})
  local root=nativeFactory.create('ScrollingFrame',screen,{});root:SetAttribute('Status','ready')
  local css='body{margin:8px;font-size:16px}.rack{display:'..display..';gap:10px;grid-template-columns:1fr 1fr}.space{box-sizing:border-box;padding:2% calc(1% + 3px);margin:1% calc(2% + 1px);font-size:16px}.tint{color:green}#spaced:focus-within{color:red}#spacing-input{display:block;padding:2% calc(1% + 1rem);margin:1% calc(2% + 3px);width:100px}.control-tint{color:purple}#em{padding:1em calc(2% + 1em);margin:calc(1% + .5em)}#rem{padding:calc(2% + 1rem);margin:1rem}'
  local document=Parser.parseDocument('<!doctype html><html><body><h1>Retained title</h1><div class="rack"><article id="spaced" class="space"><p>Stable spacing text</p><input id="spacing-input" value="same"><p id="em">Font relative spacing</p><p id="rem">Root relative spacing</p></article><article id="other" class="space"><p>Independent cached card</p></article></div><p>Retained footer</p><script>void 0;</script></body></html>')
  local tree=loadRenderTree(nativeFactory).build(document,root,error,function(font)return font end,nil,nil,nil,css)
  local width=600;local layoutRequests,requestItems=0,{}
  local page={Alive=true,Document=document,DocumentURL='https://example.test/spacing',Root=root,Cleanups={}}
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  local input={InputBegan=signal(),InputEnded=signal(),InputChanged=signal(),WindowFocusReleased=signal()}
  function input:GetFocusedTextBox()return native end
  function input:IsKeyDown()return false end
  local function request(_,item)layoutRequests+=1;if item then requestItems[item]=true end end
  Controller.start(page,tree,request,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=nativeFactory})
  local realm=HTMLScripts.start(page,tree,function()end,error)
  local function arrange(items)
   tree:SetMediaEnvironment(width,500);tree.ViewportHeight=500
   local stats=Dirty.begin(tree,items);layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true);return stats
  end
  arrange();realm:Flush();layoutRequests=0;table.clear(requestItems)
  local spaced=tree.NodeBoxes[Node.findById(document,'spaced')]
  local field=page.FormModel:Resolve('spacing-input')
  local other=tree.NodeBoxes[Node.findById(document,'other')]
  local oldOther,oldOtherGui=other.Children[1],other.Gui
  local function equivalent()
   local cloned=Node.cloneNode(document,true)
   local fresh=renderer.build(cloned,root,error,function(font)return font end,nil,nil,nil,css)
   fresh:SetMediaEnvironment(width,500);fresh.ViewportHeight=500
   if field.Focused then
    local target=Node.findById(cloned,'spacing-input');fresh:SetCSSState('focus',target)
    if field.FocusVisible then fresh:SetCSSState('focus-visible',target)end
   end
   Dirty.begin(fresh);layout.arrange(fresh,width,0,0,function()return true end);Dirty.finish(fresh,true)
   local live,reference=string.split(snapshot(tree),'|'),string.split(snapshot(fresh),'|')
   local differences={}
   for i=1,math.max(#live,#reference)do if live[i]~=reference[i]then table.insert(differences,'token '..i..' '..tostring(live[i])..' / '..tostring(reference[i]))end end
   assert(#differences==0,'Percentage/calc/native-focus spacing diverges from final full layout: '..display..' '..table.concat(differences,', ',1,math.min(#differences,8)))
   assert(other.Gui==oldOtherGui and other.Children[1]==oldOther and not oldOtherGui.Destroyed,'Independent card remains the actual retained branch')
  end
  local function mutate(code,expectedLayout,globalFont)
   local before=measurements
   realm:Run(code);assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))
   local needed,items=realm:Flush();items=items or{}
   for item in requestItems do items[item]=true;needed=true end;table.clear(requestItems)
   assert(needed==expectedLayout,'Stable spacing requested an unnecessary layout for '..display..': '..code)
   if needed then
    local stats=arrange(items)
    assert(stats.Mode=='partial'and(globalFont or stats.Reused>0),'Real spacing changes reuse independent measured branches')
   else assert(measurements==before,'Color-only spacing recascades must not remeasure text')end
   equivalent();layoutRequests=0
  end
  local geometry=snapshot(tree)
  local margin,padding=table.clone(spaced.Style.Margin),table.clone(spaced.Style.Padding)
  mutate("document.getElementById('spaced').classList.add('tint');document.getElementById('spacing-input').classList.add('control-tint');",false)
  assert(snapshot(tree)==geometry and spaced.Style.Color==Color3.fromRGB(0,128,0),'Percentage spacing color change paints without geometry work')
  for side=1,4 do assert(spaced.Style.Margin[side]==margin[side]and spaced.Style.Padding[side]==padding[side],'Paint-only recascade retains resolved percentage/calc pixels')end
  local beforeFocus=measurements
  field.Item.Editor:CaptureFocus()
  assert(field.Focused and native==field.Item.Editor and layoutRequests==0,'Native focus on percentage/calc spaced input must not schedule a layout')
  assert(spaced.Style.Color==Color3.fromRGB(255,0,0)and measurements==beforeFocus,'Native :focus-within recascade is real paint without text measurement')
  equivalent();field.Item.Editor:ReleaseFocus();assert(layoutRequests==0,'Native blur keeps resolved spacing local');equivalent()
  mutate("document.getElementById('spaced').style.padding='3% calc(2% + 5px)';",true)
  local cachedSpaced=spaced.CachedLayout
  mutate("document.getElementById('other').style.width='170px';",true)
  if display~='flex'then assert(spaced.CachedLayout==cachedSpaced,'An unrelated width change retains the actually unchanged spaced card layout')end
  mutate("document.getElementById('spaced').classList.remove('tint');",false)
  mutate("document.getElementById('em').style.fontSize='20px';",true)
  local remStyle=tree.NodeStyles[Node.findById(document,'rem')]
  local remMargin=remStyle.Margin[1]
  -- The root's actual FontSize also changes; its own inherited geometry scope
  -- can conservatively invalidate the tree, unlike a local spacing mutation.
  mutate("document.documentElement.style.fontSize='20px';",true,true)
  assert(remStyle.Margin[1]~=remMargin and remStyle.FontSize==16,'Authored root font changes rem geometry despite an explicitly fixed body font')
  local oldPixels=spaced.Style.Padding[2]
  width=420;root.AbsoluteSize=Vector2.new(width,500);arrange()
  assert(spaced.Style.Padding[2]~=oldPixels,'Available-width changes resolve the retained CSS percentage values again')
  equivalent();mutate("document.getElementById('spaced').classList.add('tint');",false)
  for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end
 end
 print('Stable mounted geometry: block/flex/grid captions, select/listbox rows, output, checkbox/value/reset, native-focus percentage/calc spacing, genuine spacing/font/resize propagation and independent full-layout equivalence passed; '..totalLocal..' local updates')
end
