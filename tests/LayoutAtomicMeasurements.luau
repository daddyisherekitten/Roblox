--!strict
-- A size query may suspend at either the explicit budget or native text bounds.
-- Its temporary width must never become observable through the retained tree.
return function(Parser,Node,Computed,Dirty,Job,Controller,HTMLScripts,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 -- A prior pure probe can complete new font bounds while the retained glyphs
 -- still display the old font. An unvisited descendant in the next probe must
 -- preserve that completed cache instead of relabelling painted widths.
 do
  local face={Family='probe-font',Weight=400,Style='normal'}
  local item={Kind='Word',Text='X',Style={Font='probe-font',TabularNums=false},Glyphs={{Text='X',Width=34,Height=34}},
   FontFace=face,TextSize=26,MeasuredText='X',MeasuredSize=26,MeasuredFont='probe-font',MeasuredWeight=400,MeasuredStyle='normal',
   NativeGlyphBounds={Text='X',Font=face,Size=26,Tabular=false,Family='probe-font',Weight=400,Variant='normal',Bounds={{Width=26,Height=26}}}}
  local context=require('Layout/LayoutMeasurement').new({Kind='Words',Style={},Items={item},Children={}},function()return true end)
  context:KeepMeasurements()
  assert(item.NativeGlyphBounds.Size==26 and item.NativeGlyphBounds.Bounds[1].Width==26,
   'An unvisited measurement must not replace completed new-font bounds with retained old-font glyph widths')
  assert(item.Glyphs[1].Width==34 and item.Glyphs[1].Height==34,'Keeping font bounds must leave retained painted glyph geometry unchanged')
  local fresh=require('Layout/LayoutMeasurement').new({Kind='Words',Style={},Items={item},Children={}},function()return true end)
  local measured=fresh.Root.Items[1];measured.TextSize,measured.MeasuredSize=20,20
  measured.Glyphs[1].Width,measured.Glyphs[1].Height=20,20
  fresh:KeepMeasurements()
  assert(item.NativeGlyphBounds.Size==20 and item.NativeGlyphBounds.Bounds[1].Width==20,
   'Newly completed glyph measurements must replace the previous font cache when its key differs')
  assert(item.Glyphs[1].Width==34 and item.Glyphs[1].Height==34,'Publishing a newly completed cache must still preserve retained paint')
 end
 local function signal()
  local listeners={};local api={}
  function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
  function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
  function api:Count()local n=0;for _,entry in listeners do if entry[1].Connected then n+=1 end end;return n end
  return api
 end
 local created,focused,inspectNative={},nil,nil
 local factory={create=function(class,parent,props)
  local gui=table.clone(props or{});gui.ClassName,gui.Parent=class,parent;gui.Visible=true
  gui.AbsolutePosition,gui.AbsoluteSize=Vector2.new(0,0),Vector2.new(800,600)
  if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0)end
  gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local signals,attributes={},{ }
  function gui:GetPropertyChangedSignal(key)signals[key]=signals[key]or signal();return signals[key]end
  function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
  function gui:SetAttribute(key,v)attributes[key]=v end;function gui:GetAttribute(key)return attributes[key]end
  function gui:IsA(kind)return kind==class or kind=='GuiObject'end
  function gui:IsFocused()return focused==self end
  function gui:CaptureFocus()if focused==self then return end;local old=focused;focused=self;if old then old.FocusLost:Fire(false)end;self.Focused:Fire()end
  function gui:ReleaseFocus()if focused~=self then return end;focused=nil;self.FocusLost:Fire(false)end
  function gui:ConnectionCount()local n=self.Focused:Count()+self.FocusLost:Count()+self.InputBegan:Count();for _,s in signals do n+=s:Count()end;return n end
  function gui:Destroy()assert(not self.Destroyed,'An atomic measurement disposed a retained GUI twice');self.Destroyed=true;self:ReleaseFocus();self.Parent=nil end
  table.insert(created,gui);return gui
 end};factory.modifier=factory.create
 local renderer=loadRenderTree(factory);local measurements=0;local faces={}
 local overrides={['Layout/FontProfiles']={face=function(f,w,v)
  local key=tostring(f)..':'..tostring(w)..':'..tostring(v)
  faces[key]=faces[key]or{Family=f,Weight=w or 400,Style=v or 'normal'};return faces[key]
 end},['Layout/TextMeasure']={measure=function(text,_,size)
  measurements+=1;if inspectNative then inspectNative()end
  return{X=#text*reference.glyphWidths['16']*size/16,Y=size}
 end}}
 overrides['Layout/FontMetrics']={extents=require('Layout/FontMetrics').extents,resolve=function(style)
  local size=math.ceil(style.FontSize);return{TextSize=size,Baseline=math.round(size*.8),Top=math.round(size*.13),XHeight=math.round(size*.3),Bottom=size,Calibrated=true}
 end}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local guiFields={'Parent','Position','Size','Visible','ZIndex','Text','BackgroundTransparency','ImageTransparency','TextTransparency','CanvasSize','CanvasPosition','ScrollingEnabled','CursorPosition','SelectionStart','ClipsDescendants'}
 local boxFields={'LayoutX','LayoutY','PaintX','PaintY','OuterWidth','OuterHeight','ContentWidth','ContentHeight','LocalRight','LocalBottom','OwnBottom','FirstBaseline','HeightBasis','DefiniteHeight','ScrollRight','ScrollBottom','ScrollLeft','ScrollTop','ContentTop','CaptionTop','TableGridHeight','CachedLayout','FlowPaintState','PaintState','DisplayItems','ColumnLayout'}
 local wordFields={'X','Y','Width','Height','LineIndex','LineTop','LineBaseline','LineLeft','LineRight','ColumnIndex','GridBaseline','Fragment','FragmentLeft','FragmentRight','FragmentPaintLeft','FragmentPaintRight','GeometryBox'}
 local function equal(a,b)
  if a==b then return true end
  -- The host bundle models Vector2/UDim2 as fresh value tables. Numeric values,
  -- rather than their table identities, are the actual native geometry.
  if type(a)=='table'and type(b)=='table'and a[1]~=nil and b[1]~=nil then return a[1]==b[1]and a[2]==b[2]end
  return false
 end
 local function retain(object,fields,list)
  if not object then return end;local values={};for _,key in fields do values[key]={object[key]}end
  table.insert(list,{Object=object,Values=values})
 end
 local function state(tree,first)
  local saved={};for i=first,#created do retain(created[i],guiFields,saved)end
  local visited={};local function visit(box)
   if visited[box]then return end;visited[box]=true;retain(box,boxFields,saved)
   for _,item in box.Items or{}do retain(item,wordFields,saved);for _,glyph in item.Glyphs or{}do retain(glyph,wordFields,saved)end;if item.InlineBox then visit(item.InlineBox)end end
   if box.ImageItem then retain(box.ImageItem,wordFields,saved)end
   for _,child in box.AllChildren or box.Children or{}do visit(child)end
  end;visit(tree)
  local hits={};for gui,node in tree.HitNodes or{}do hits[gui]=node end
  local styles={};for node,style in tree.NodeStyles do styles[node]={Style=style,Margin=table.clone(style.Margin),Padding=table.clone(style.Padding)}end
  return function(label)
   for _,entry in saved do for key,previous in entry.Values do
    assert(equal(entry.Object[key],previous[1]),label..': retained '..tostring(entry.Object.Name or entry.Object.Text or entry.Object.Kind)..'.'..key..' changed during a size query')
   end end
   for gui,node in hits do assert(tree.HitNodes[gui]==node,label..': hit ownership changed')end
   for gui,node in tree.HitNodes or{}do assert(hits[gui]==node,label..': a probe allocated hit ownership')end
   for node,entry in styles do
    assert(tree.NodeStyles[node]==entry.Style,label..': style identity changed')
    for i=1,4 do assert(entry.Style.Margin[i]==entry.Margin[i]and entry.Style.Padding[i]==entry.Padding[i],label..': a synthetic basis changed live resolved spacing')end
   end
  end
 end
 local nativeChecks,budgetChecks,states,nativeGeometry=0,0,0,0
 local function layoutKey(tree)
  local parts={};local seen={};local function visit(box)
   if seen[box]then return end;seen[box]=true
   for _,key in boxFields do if type(box[key])=='number'or type(box[key])=='boolean'then table.insert(parts,key..':'..tostring(box[key]))end end
   for _,item in box.Items or{}do for _,key in wordFields do if type(item[key])=='number'then table.insert(parts,key..':'..tostring(item[key]))end end;if item.InlineBox then visit(item.InlineBox)end end
   for _,child in box.Children or{}do visit(child)end
  end;visit(tree);return table.concat(parts,'|')
 end
 for caseIndex,case in reference.cases do
  local first=#created+1;local document=Parser.parseDocument(case.html..'<script></script>')
  local root=factory.create('ScrollingFrame',nil,{});root:SetAttribute('Status','ready')
  local tree=renderer.build(document,root,error,function(f)return f end);tree.ViewportHeight=600
  local page={Alive=true,Document=document,DocumentURL='https://atomic.test/page',BaseURL='https://atomic.test/page',Root=root,Cleanups={}}
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  function page:GeometryViewport()return{Width=800,Height=600,ClientWidth=800,ClientHeight=600,ScrollWidth=800,ScrollHeight=600,ScrollX=0,ScrollY=0}end
  function page:HasPendingLayout()return false end;function page:FlushScriptLayout()end
  local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
  function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode(key)return key.Name end
  Dirty.begin(tree);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)
  local stop=Controller.start(page,tree,function()end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=os.clock,PickerLayout=layout})
  local realm=assert(HTMLScripts.start(page,tree,function()end,error,{JavaScriptServices={Clock=os.clock,RunService={RenderStepped=signal(),Heartbeat=signal()},Task={delay=function(_,fn)return{Callback=fn}end,cancel=function()end}}}))
  page.JavaScriptRuntime=realm
  local owner=tree.NodeBoxes[Node.findById(document,'owner')];local atomic=tree.NodeBoxes[Node.findById(document,'atomic')]
  local c=page.FormModel:Resolve(Node.findById(document,'editor'));local editor=c.Item.Editor;local connected=editor:ConnectionCount()
  assert(connected>0,'The probe must contain an actual Controller-bound editor')
  local function run(code)assert(realm:Run(code),code);assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
  run("document.getElementById('editor').value='edited';document.getElementById('editor').focus();document.getElementById('editor').setSelectionRange(1,4,'backward')")
  assert(c.Value=='edited'and focused==editor and c.SelectionStart==1 and c.SelectionEnd==4,'Actual editor preparation must apply value/focus/selection')
  for index,style in case.styles do
   local target=Node.findById(document,'atomic');target.Attributes.style=style
   local _,items=tree:ApplyDOMChanges({[target]={Attributes={style=true}}})
   Dirty.begin(tree,items);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)
   local caption=tree.NodeBoxes[Node.findById(document,'caption')]
   if caption.ScrollGui then caption.ScrollGui.CanvasPosition=Vector2.new(0,5)end
   local drawCalls=0;local replacedRenderers={}
   for _,name in {'BackgroundRenderer','InsetRenderer','VisualEffects','RadiusRenderer'}do
    replacedRenderers[name]={atomic[name]}
    atomic[name]={Draw=function()drawCalls+=1 end,DrawRadius=function()drawCalls+=1;return false end}
   end
   local preserved=state(tree,first);local allocated,measured=#created,measurements
   local css=Computed.read(atomic.Style,atomic,{Width=800,Height=600}).Values
   local expected=case.expected[index]
   run("globalThis.atomicSnapshot=JSON.stringify(['owner','atomic','caption','nested','editor'].map(id=>{const e=document.getElementById(id);if(!e)return null;const r=e.getBoundingClientRect();return [r.x,r.y,r.width,r.height,e.clientWidth,e.clientHeight,e.scrollWidth,e.scrollHeight]}))")
   local function inspect()
    preserved(case.name..' state '..index)
    assert(drawCalls==0,'A size query called a retained Draw/DrawRadius renderer')
    assert(#created==allocated,'A measurement allocated native GUI/resources')
    assert(c.Item.Editor==editor and editor:ConnectionCount()==connected and c.Value=='edited'and focused==editor and c.SelectionStart==1 and c.SelectionEnd==4 and c.SelectionDirection=='backward','A measurement altered editor identity, binding, value, focus or selection')
    local values=Computed.read(atomic.Style,atomic,{Width=800,Height=600}).Values
    for key,value in css do assert(values[key]==value,'A measurement exposed transient computed CSSOM '..key)end
    run("if(atomicSnapshot!==JSON.stringify(['owner','atomic','caption','nested','editor'].map(id=>{const e=document.getElementById(id);if(!e)return null;const r=e.getBoundingClientRect();return [r.x,r.y,r.width,r.height,e.clientWidth,e.clientHeight,e.scrollWidth,e.scrollHeight]})))throw new Error('CSSOM query observed temporary geometry')")
    return true
   end
   inspectNative=function()nativeChecks+=1;inspect()end
   local now=0
   local ok,result=Job.run({Alive=true},tree,1,function()return true end,function(alive)
    for _,space in {250,80,400}do for _,minimum in {true,false}do layout.naturalWidth(owner,space,alive,minimum,true);if not alive()then return 0 end end end
    return 1
   end,{wait=function()budgetChecks+=1;inspect();now+=.016 end},function()now+=.000002;return now end)
   inspectNative=nil;assert(ok and result==1,tostring(result));inspect()
   -- Native reads retain all eight frames; the deterministic root fixture also
   -- checks actual geometry against captured monospace dimensions.
   for _,record in expected.boxes do if record and(record.id=='atomic'or record.id=='caption'or record.id=='nested'or record.id=='editor')then
    local b=tree.NodeBoxes[Node.findById(document,record.id)]
    local difference=case.profileDifferences
    local excluded=difference and(difference.all or difference.states and difference.states[tostring(index)])
    if not excluded or not table.find(excluded,record.id)then
     assert(math.abs(b.OuterWidth-record.rect[3])<.06 and math.abs(b.OuterHeight-record.rect[4])<.06,'Native atomic/control geometry differs: '..case.name..' '..record.id..' state '..index..' actual '..tostring(b.OuterWidth)..'x'..tostring(b.OuterHeight)..' native '..record.rect[3]..'x'..record.rect[4])
     nativeGeometry+=1
    end
   end end
   assert(measurements==measured,'Warm intrinsic atomic probes must reuse captured native text bounds')
   if caseIndex==#reference.cases and index==1 then
    local function cool(box)
     for _,item in box.Items or{}do item.MeasuredText=nil;item.NativeGlyphBounds=nil;item.ControlMeasureKey=nil;if item.InlineBox then cool(item.InlineBox)end end
     if box.ImageItem then box.ImageItem.ControlMeasureKey=nil end
     for _,child in box.Children or{}do cool(child)end
    end;cool(owner)
    inspectNative=function()nativeChecks+=1;inspect()end
    local before=measurements
    layout.naturalWidth(owner,250,inspect,true,true)
    inspectNative=nil;inspect()
    assert(measurements>before,'A cold tracked-text probe must perform actual asynchronous font bounds')
    for _,child in caption.Children do for _,item in child.Items or{}do if item.Glyphs then
     assert(item.NativeGlyphBounds and item.NativeGlyphBounds.Text==item.Text,'Cold glyphs retain independent completed native bounds')
    end end end
    local measuredCold=measurements
    layout.naturalWidth(owner,250,inspect,true,true)
    assert(measurements==measuredCold,'The next tracked-text probe reuses all completed glyph/font bounds')
   end
   -- Re-enter actual painting at the final width after synthetic queries. Its
   -- complete result must match an independent fresh tree, including profiles
   -- whose older flex/scroll geometry has an explicit native discrepancy.
   Dirty.begin(tree);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)
   local freshDocument=Parser.parseDocument(case.html..'<script></script>');local fresh=renderer.build(freshDocument,{},error,function(f)return f end);fresh.ViewportHeight=600
   Node.findById(freshDocument,'atomic').Attributes.style=style
   fresh:ApplyDOMChanges({[Node.findById(freshDocument,'atomic')]={Attributes={style=true}}})
   Dirty.begin(fresh);layout.arrange(fresh,800,0,0,function()return true end);Dirty.finish(fresh,true)
   assert(layoutKey(tree)==layoutKey(fresh),'Synthetic atomic measurements changed final layout relative to a fresh tree: '..case.name..' '..index)
   for name,previous in replacedRenderers do atomic[name]=previous[1]end
   states+=1
  end
  if caseIndex==1 then
   -- This cancellation happens inside real native bounds, after the probe has
   -- already entered linked InlineBox/MeasureGrid descendants. No partial plan
   -- may leak out or become a cache entry reused by the recovery pass.
   local function cold(box)
    for _,item in box.Items or{}do item.MeasuredText=nil;if item.InlineBox then cold(item.InlineBox)end end
    for _,child in box.Children or{}do cold(child)end
   end;cold(atomic)
   local retained=state(tree,first);local allocated=#created;local alive,nativeWaits=true,0
   local canceledOverrides=table.clone(overrides);local probing=true
   canceledOverrides['Layout/TextMeasure']={measure=function(text,_,size)
    if probing then nativeWaits+=1;retained('Canceled atomic native wait');if nativeWaits==3 then alive=false end end
    return{X=#text*reference.glyphWidths['16']*size/16,Y=size}
   end}
   canceledOverrides['Layout/WordLayout']=loadWordLayout(canceledOverrides);local canceledLayout=loadBlockLayout(canceledOverrides)
   local ok=pcall(canceledLayout.naturalWidth,owner,250,function()return alive end,true,true)
   assert(ok and not alive and nativeWaits>=3,'Cancellation must occur inside actual native measurement')
   nativeChecks+=nativeWaits
   retained('Canceled atomic result');assert(#created==allocated,'An aborted atomic plan allocated native resources')
   probing=false;alive=true;Dirty.begin(tree);canceledLayout.arrange(tree,800,0,0,function()return alive end);Dirty.finish(tree,true)
   local freshDocument=Parser.parseDocument(case.html..'<script></script>');local fresh=renderer.build(freshDocument,{},error,function(f)return f end);fresh.ViewportHeight=600
   Node.findById(freshDocument,'atomic').Attributes.style=case.styles[#case.styles]
   fresh:ApplyDOMChanges({[Node.findById(freshDocument,'atomic')]={Attributes={style=true}}})
   -- The value of a fixed-size text editor does not alter the native box extent.
   Dirty.begin(fresh);canceledLayout.arrange(fresh,800,0,0,function()return true end);Dirty.finish(fresh,true)
   assert(layoutKey(tree)==layoutKey(fresh),'An aborted atomic plan poisoned recovery geometry or line/inline placement')
  end
  -- Live native events still pass through the original binding after all probes.
  editor.Text='changed by editor';editor:GetPropertyChangedSignal('Text'):Fire()
  assert(c.Value=='changed by editor','Size probes broke the actual native editing binding')
  realm:Destroy();stop();page.Alive=false;for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end
  assert(input.InputBegan:Count()==0,'Atomic/control disposal leaked input connections')
 end
 assert(states==#reference.cases*6 and nativeGeometry==170 and budgetChecks>0,'Native atomic cases must exercise geometry and actual cooperative waits')
 print('Atomic measurements: '..states..' native/editor states, '..nativeGeometry..' native box dimensions, '..budgetChecks..' budget waits, '..nativeChecks..' native waits, retained model/CSSOM/hit/editor state passed')
end
