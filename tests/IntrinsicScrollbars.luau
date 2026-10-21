--!strict
return function(Parser,Node,Style,Dirty,Scroll,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local allocations,measures,guis=0,0,{}
 local inspectWait
 local function create(class,parent,props)
  allocations+=1;local gui=table.clone(props);gui.ClassName,gui.Parent=class,parent
  function gui:Destroy()self.Destroyed=true end
  table.insert(guis,gui);return gui
 end
 local renderer=loadRenderTree({create=create,modifier=create})
 local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)
  measures+=1;if inspectWait then inspectWait()end;return {X=(utf8.len(text)or 0)*reference.glyphWidth*size/16,Y=size}
 end}}
 overrides['Layout/FontMetrics']={extents=require('Layout/FontMetrics').extents,resolve=function(style)
  local size=math.ceil(style.FontSize);return {TextSize=size,Baseline=math.round(size*.8),Top=math.round(size*.13),XHeight=math.round(size*.3),Bottom=size,Calibrated=true}
 end}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local function build(case,width)
  local content=case.content or(if case.name=='no-bar-start'then '<div style="margin:32px">'..reference.caption..'</div>'else reference.caption)
  local html='<!doctype html><style>body{margin:0;font:16px/20px "Courier New"}#target{display:block}</style><div id=owner style="width:140px;'..case.parentStyle..'"><span id=atomic style="display:inline-block;width:'..width..';'..(case.atomicStyle or(if case.name=='percent-definite'then 'height:100px'else ''))..'"><div id=target style="'..case.style..'">'..content..'</div></span></div>'
  local document=Parser.parseDocument(html);local warnings={}
  local tree=renderer.build(document,{AbsoluteSize=Vector2.new(800,600)},function(w)table.insert(warnings,w)end,function(f)return f end)
  tree.ViewportHeight=600
  Dirty.begin(tree);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)
  assert(#warnings==0,case.name..': '..table.concat(warnings,' | '))
  return tree,document
 end
 local failures,compared={},0
 for _,case in reference.cases do for _,step in case.states do
  local tree,document=build(case,step.width);local box=tree.NodeBoxes[Node.findById(document,'target')]
  local atomic=tree.NodeBoxes[Node.findById(document,'atomic')]
  for i,value in {box.OuterWidth,box.OuterHeight}do
   if math.abs(value-step.host.rect[i])>.09 then table.insert(failures,case.name..' '..step.width..' target '..i..': '..value..' != '..step.host.rect[i])end
  end
  if atomic and math.abs(atomic.OuterWidth-step.host.atomic[1])>.09 then table.insert(failures,case.name..' '..step.width..' atomic width: '..atomic.OuterWidth..' != '..step.host.atomic[1])end
  local surface,position,size,wordGeometry=box.Gui,box.Gui.Position,box.Gui.Size,{}
  for _,child in box.Children do if child.Kind=='Words'then for _,item in child.Items do table.insert(wordGeometry,{item,item.X,item.Y,item.Width,item.Height,item.LineIndex})end end end
  local allocated,measured=allocations,measures
  layout.naturalWidth(box,140,function()return true end,true,nil,if case.name=='percent-definite'then 100 else nil)
  layout.naturalWidth(box,140,function()return true end,false,nil,if case.name=='percent-definite'then 100 else nil)
  assert(allocations==allocated and box.Gui==surface and box.Gui.Position==position and box.Gui.Size==size,'Pure gutter probes never allocate or move native surfaces')
  for _,saved in wordGeometry do local item=saved[1];assert(item.X==saved[2]and item.Y==saved[3]and item.Width==saved[4]and item.Height==saved[5]and item.LineIndex==saved[6],'Pure gutter probes preserve painted words/lines')end
  assert(measures==measured,'Warm gutter probes reuse individual native bounds')
  Scroll.destroyTree(tree);compared+=1
 end end
 for _,failure in failures do print('GUTTER MISMATCH '..failure)end
 assert(#failures==0,'Intrinsic scrollbar native comparisons failed: '..#failures)
 assert(compared==159,'The frozen native scrollbar matrix must retain every state')
 -- A second, constrained gutter graph deliberately drops captured MeasureGrid
 -- closures. It must prepare linked inline boxes against its own copied graph.
 local nestedStates=0
 for _,case in reference.nestedAtomic do for _,step in case.states do
  local t,d=build(case,step.width)
  for _,id in {'atomic','target','nested','percent'}do
   local b=t.NodeBoxes[Node.findById(d,id)];local expected=step.host[id].rect
   assert(math.abs(b.OuterWidth-expected[1])<.09 and math.abs(b.OuterHeight-expected[2])<.09,
    case.name..' '..step.width..' '..id..' native constrained-inline geometry: '..b.OuterWidth..'x'..b.OuterHeight..' != '..expected[1]..'x'..expected[2])
  end
  local b=t.NodeBoxes[Node.findById(d,'target')];local positions,words={},{}
  for _,gui in guis do table.insert(positions,{gui,gui.Position,gui.Size,gui.Visible})end
  local function save(box)
   for _,item in box.Items or{}do table.insert(words,{item,item.X,item.Y,item.Width,item.Height,item.GridBaseline,item.InlineMeasurement});if item.InlineBox then save(item.InlineBox)end end
   for _,child in box.Children or{}do save(child)end
  end;save(b)
  local function unchanged()
   for _,saved in positions do assert(saved[1].Position==saved[2]and saved[1].Size==saved[3]and saved[1].Visible==saved[4],'Nested gutter measurement cannot change a retained surface')end
   for _,saved in words do assert(saved[1].X==saved[2]and saved[1].Y==saved[3]and saved[1].Width==saved[4]and saved[1].Height==saved[5]and saved[1].GridBaseline==saved[6]and saved[1].InlineMeasurement==saved[7],'Nested gutter measurement cannot publish inline placement or probe closures')end
  end
  local allocated,measured=allocations,measures
  layout.naturalWidth(b,140,function()unchanged();return true end,true,nil,60)
  layout.naturalWidth(b,140,function()unchanged();return true end,false,nil,60)
  unchanged();assert(allocations==allocated and measures==measured,'Warm linked gutter graphs reuse retained native bounds without native allocation')
  if case.style:find('gutter:auto',1,true)and step.width=='min-content'then
   local nativeBounds={}
   for _,saved in words do local item=saved[1];item.MeasuredText=nil;nativeBounds[item]={item.NativeWidth,item.NativeHeight,item.NativeGlyphBounds}end
   local alive,waits=true,0
   inspectWait=function()waits+=1;unchanged();alive=false end
   local canceled=layout.naturalWidth(b,141,function()return alive end,true,nil,60)
   inspectWait=nil;assert(canceled==0 and not alive and waits>0,'A cold linked gutter graph must abort inside actual native measurement')
   unchanged();assert(allocations==allocated,'Aborted linked gutter graphs cannot allocate retained surfaces')
   for item,bounds in nativeBounds do assert(item.MeasuredText==nil and item.NativeWidth==bounds[1]and item.NativeHeight==bounds[2]and item.NativeGlyphBounds==bounds[3],'An aborted linked gutter graph cannot publish incomplete font bounds')end
   local recovered=layout.naturalWidth(b,141,function()unchanged();return true end,true,nil,60)
   local fresh,freshDocument=build(case,step.width);local freshBox=fresh.NodeBoxes[Node.findById(freshDocument,'target')]
   local independent=layout.naturalWidth(freshBox,141,function()return true end,true,nil,60)
   assert(math.abs(recovered-independent)<.001,'Linked gutter cancellation must recover to independent fresh geometry')
   unchanged();Scroll.destroyTree(fresh)
  end
  Scroll.destroyTree(t);nestedStates+=1
 end end
 assert(nestedStates==18,'Six native constrained inline block/flex/grid controls retain all intrinsic-width states')
 -- A cold native measurement can yield or cancel while retained paint still
 -- uses the prior font. Neither graph copying nor auto-bar reflow may touch it.
 local case=reference.cases[1];local tree,document=build(case,'min-content')
 local box=tree.NodeBoxes[Node.findById(document,'target')]
 local positions,items={},{}
 for _,gui in guis do table.insert(positions,{gui,gui.Position,gui.Size,gui.Visible,gui.TextSize})end
 for _,child in box.Children do if child.Kind=='Words'then for _,item in child.Items do table.insert(items,{item,item.X,item.Y,item.Width,item.Height,item.LineIndex})end end end
 local function unchanged()
  for _,v in positions do assert(v[1].Position==v[2]and v[1].Size==v[3]and v[1].Visible==v[4]and v[1].TextSize==v[5],'Every native wait retains original paint and font geometry')end
  for _,v in items do assert(v[1].X==v[2]and v[1].Y==v[3]and v[1].Width==v[4]and v[1].Height==v[5]and v[1].LineIndex==v[6],'Every native wait retains original word placement')end
 end
 box.Style.FontSize=17
 local nativeWaits,frames,clock=0,0,0
 inspectWait=function()nativeWaits+=1;unchanged()end
 local allocated=allocations
 local Job=require('Rendering/LayoutJob')
 local ok,result=Job.run({Alive=true},tree,1,function()return true end,function(work)return layout.naturalWidth(box,140,work,true)end,
  {wait=function()frames+=1;unchanged();clock+=.016 end},function()clock+=.00025;return clock end)
 inspectWait=nil
 assert(ok and result>0 and nativeWaits>0 and frames>0 and allocations==allocated,'Cold gutter probes use cooperative/native waits without native allocation')
 unchanged()
 box.Style.FontSize=18
 local alive=true;local measured={}
 for _,v in items do measured[v[1]]={v[1].MeasuredSize,v[1].NativeWidth,v[1].NativeGlyphBounds}end
 inspectWait=function()unchanged();alive=false end
 local canceled=layout.naturalWidth(box,140,function()return alive end,true)
 inspectWait=nil
 assert(not alive and canceled==0,'The cancellation control actually aborts a cold gutter probe')
 unchanged()
 for item,v in measured do assert(item.MeasuredSize==v[1]and item.NativeWidth==v[2]and item.NativeGlyphBounds==v[3],'An aborted gutter probe never publishes incomplete native measurements')end
 Dirty.begin(tree);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)
 local freshCase={name='recovered',style=case.style..';font-size:18px',parentStyle=''}
 local fresh,freshDocument=build(freshCase,'min-content');local freshBox=fresh.NodeBoxes[Node.findById(freshDocument,'target')]
 assert(math.abs(box.OuterWidth-freshBox.OuterWidth)<.001 and math.abs(box.OuterHeight-freshBox.OuterHeight)<.001,'Canceled gutter/font recovery matches a fresh tree')
 -- Start-side overflow is reachable only from the corresponding scroll origin.
 for _,direction in {'ltr','rtl'}do
  local aligned={name='aligned-'..direction,style='width:20px;height:30px;overflow:auto;direction:'..direction,parentStyle=''}
  local t,d=build(aligned,'max-content');local port=t.NodeBoxes[Node.findById(d,'target')]
  assert(port.ScrollX==10 and port.ScrollY==10,'Oversized direct inline words produce both physical bars in LTR and RTL')
  Scroll.destroyTree(t)
 end
 Scroll.destroyTree(tree);Scroll.destroyTree(fresh)
 -- Mounted editing uses the actual Controller/HTMLScripts selection path.
 -- Resizing changes the gutter while the native editor, source and selection
 -- stay owned by the same editing host, then every callback is disposed.
 local function signal()
  local listeners={};local s={}
  function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
  function s:Fire(...)for _,v in table.clone(listeners)do if v[1].Connected then v[2](...)end end end
  function s:Count()local n=0;for _,v in listeners do if v[1].Connected then n+=1 end end;return n end
  return s
 end
 local focused;local mounted,deferred={},{};local factory={}
 function factory.create(class,parent,props)
  local changes,attributes={},{}
  local values={Parent=parent,ClassName=class,Visible=true,AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(520,500),AbsoluteWindowSize=Vector2.new(520,500),Text='',CursorPosition=-1,SelectionStart=-1}
  for k,v in props do values[k]=v end;if class=='ScrollingFrame'then values.CanvasPosition=Vector2.new(0,0)end
  local gui=setmetatable({},{__index=values,__newindex=function(_,k,v)local before=values[k];values[k]=v;if before~=v and changes[k]then changes[k]:Fire()end end})
  values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
  function values:GetPropertyChangedSignal(k)if not changes[k]then changes[k]=signal()end;return changes[k]end
  function values:GetAttributeChangedSignal(k)return self:GetPropertyChangedSignal('attribute:'..k)end
  function values:SetAttribute(k,v)attributes[k]=v;if changes['attribute:'..k]then changes['attribute:'..k]:Fire()end end
  function values:GetAttribute(k)return attributes[k]end
  function values:IsA(k)return k==class or(k=='GuiObject'and class~='ScreenGui')end
  function values:IsFocused()return focused==gui end
  function values:CaptureFocus()if focused and focused~=gui then focused:ReleaseFocus()end;focused=gui;gui.CursorPosition=1;self.Focused:Fire()end
  function values:ReleaseFocus()if focused==gui then focused=nil;gui.CursorPosition=-1;gui.SelectionStart=-1;self.FocusLost:Fire(false)end end
  function values:Destroy()if values.Destroyed then return end;values.Destroyed=true;for _,child in mounted do if child.Parent==gui and not child.Destroyed then child:Destroy()end end;gui.Parent=nil end
  table.insert(mounted,gui);return gui
 end
 factory.modifier=factory.create
 local mountedRenderer=loadRenderTree(factory)
 local doc=Parser.parseDocument('<!doctype html><style>body{margin:0;font:16px/20px "Courier New"}</style><div id=owner style="width:140px"><div id=target contenteditable style="width:fit-content;height:30px;overflow:auto">'..reference.caption..'</div></div>')
 local layer=factory.create('ScreenGui',nil,{});local root=factory.create('ScrollingFrame',layer,{ClipsDescendants=true})
 local warnings,diagnostics={},{}
 local live=mountedRenderer.build(doc,root,function(m)table.insert(warnings,m)end,function(f)return f end)
 local function arrange(items)live.ViewportHeight=500;Dirty.begin(live,items);layout.arrange(live,520,0,0,function()return true end);Dirty.finish(live,true)end
 arrange()
 local page={Alive=true,Document=doc,DocumentURL='https://example.test/scrollbars',BaseURL='https://example.test/scrollbars',Root=root,Cleanups={}}
 function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
 root:SetAttribute('Status','ready')
 local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
 function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end
 local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return {}end},Factory=factory,Clock=function()return 0 end,MeasureValidationText=function()return Vector2.new(200,16)end,
  RunService={RenderStepped=signal()},Task={defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
 require('Input/Controller').start(page,live,function()end,error,services)
 local realm,flushing
 function page:HasPendingLayout()return realm and realm:HasPending()or false end
 function page:FlushScriptLayout()if flushing or not realm then return end;flushing=true;local needed,items=realm:Flush();if needed then arrange(items)end;flushing=false end
 function page:GeometryViewport()return {Width=520,Height=500,X=0,Y=0}end
 realm=require('Rendering/HTMLScripts').start(page,live,function()end,function(m)table.insert(diagnostics,m)end,{JavaScriptServices=services})
 local function healthy()assert(#warnings==0,table.concat(warnings,' | '));assert(#diagnostics==0,table.concat(diagnostics,' | '))end
 local function settle()for _=1,24 do local work=deferred;deferred={};for _,fn in work do fn()end;local count=realm:PumpTasks();if #deferred==0 and count==0 then break end end;healthy()end
 local function flush()local needed,items=realm:Flush();if needed then arrange(items)end;settle()end
 local function run(source)realm:Run(source);healthy()end
 flush()
 local target=Node.findById(doc,'target');local text=target.Children[1];local port=live.NodeBoxes[target];local retained=port.Gui
 run("const target=document.getElementById('target'),text=target.firstChild;target.focus();getSelection().setBaseAndExtent(text,1,text,4);")
 settle();local native=page.ContentEditableInput;local editor=native.Editor
 assert(focused==editor and native.Host==target and editor.Text==reference.caption,'The native editor is actually mounted and focused')
 for _,step in reference.dynamic do
  run("document.getElementById('owner').style.width='"..step.width.."px';target.style.cssText='"..step.style.."';")
  flush()
  assert(math.abs(port.OuterWidth-step.rect[1])<.09 and math.abs(port.OuterHeight-step.rect[2])<.09,'Native editor resize/gutter geometry: '..step.width..' / '..port.OuterWidth)
  assert(live.NodeBoxes[target]==port and port.Gui==retained and target.Children[1]==text and native.Editor==editor and native.Host==target and focused==editor,'Resize preserves focused editor, nodes and scroll surface identity')
  run("if(getSelection().toString()!=='LPH'||getSelection().anchorNode!==text||getSelection().anchorOffset!==1||getSelection().focusOffset!==4)throw new Error('Resize changes editing selection');")
 end
 for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end;page.Alive=false;Scroll.destroyTree(live)
 assert(editor.Destroyed and editor:GetPropertyChangedSignal('Text'):Count()==0 and editor:GetPropertyChangedSignal('CursorPosition'):Count()==0 and native.Caret==nil,'Gutter/editor disposal releases callbacks and caret')
 print('Intrinsic scrollbars: '..compared..' native/calibrated states plus '..nestedStates..' nested inline block/flex/grid percentage-height controls; retained warm/canceled graph/editor states passed')
end
