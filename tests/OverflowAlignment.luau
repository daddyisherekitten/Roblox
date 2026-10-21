--!strict
-- Fixed physical boxes isolate position alignment from text shaping/sizing.
-- Native captures and frozen normative equivalents are passed separately.
-- Original PositionAlignment controls remain untouched; Grid auto-overflow states
-- explicitly use independently captured zero-margin counterparts (Grid2 11.2).
return function(Parser,Node,Style,Dirty,Controller,HTMLScripts,Alignment,loadRenderTree,loadWordLayout,loadBlockLayout,nativeReference,frozenReference)
 local reference=table.clone(nativeReference.main);reference.cases={};reference.additionalGrammar=nativeReference.additional.grammar
 local counterparts={}
 for _,record in frozenReference.counterparts do counterparts[record.caseName]=counterparts[record.caseName]or{};counterparts[record.caseName][record.state]=record end
 local function copyCase(source)
  local copy=table.clone(source);copy.states={}
  for i,state in source.states do local nextState=table.clone(state);local counterpart=counterparts[source.name]and counterparts[source.name][i]
   if counterpart then nextState.frozenControl=counterpart.control;nextState.targetExpected=counterpart.targetExpected end
   copy.states[i]=nextState
  end
  return copy
 end
 for _,group in {nativeReference.main.cases,nativeReference.additional.cases,nativeReference.positioned.cases,frozenReference.normalFlexGrid,frozenReference.normalArea,frozenReference.normalAuto}do
  for _,source in group do table.insert(reference.cases,copyCase(source))end
 end
 for _,key in {'dynamic','dynamicContent','dynamicSelf'}do reference[key]=copyCase(nativeReference.main[key])end
 assert(nativeReference.main.standard.sha256==frozenReference.standard.sha256 and #frozenReference.counterparts==174,'Separate frozen-source and native-equivalent provenance')

 local function signal()
  local entries={};local api={}
  function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
  function api:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
  function api:Count()local n=0;for _,entry in entries do if entry[1].Connected then n+=1 end end;return n end
  return api
 end
 local objects,focused={},nil
 local factory={create=function(class,parent,properties)
  local gui=table.clone(properties or{});gui.ClassName,gui.Parent=class,parent;if gui.Visible==nil then gui.Visible=true end
  gui.AbsolutePosition,gui.AbsoluteSize=Vector2.new(0,0),Vector2.new(800,600)
  if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0)end
  gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local signals,attributes={},{}
  function gui:GetPropertyChangedSignal(key)signals[key]=signals[key]or signal();return signals[key]end
  function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
  function gui:SetAttribute(key,v)attributes[key]=v end;function gui:GetAttribute(key)return attributes[key]end
  function gui:IsA(kind)return kind==class or kind=='GuiObject'end
  function gui:IsFocused()return focused==self end
  function gui:CaptureFocus()if focused==self then return end;local old=focused;focused=self;if old then old.FocusLost:Fire(false)end;self.Focused:Fire()end
  function gui:ReleaseFocus()if focused~=self then return end;focused=nil;self.FocusLost:Fire(false)end
  function gui:ConnectionCount()local n=self.Focused:Count()+self.FocusLost:Count()+self.InputBegan:Count();for _,s in signals do n+=s:Count()end;return n end
  function gui:Destroy()assert(not self.Destroyed,'Alignment disposed a retained GUI twice');self.Destroyed=true;self:ReleaseFocus();self.Parent=nil end
  table.insert(objects,gui);return gui
 end};factory.modifier=factory.create
 local measurements=0;local faces={}
 local overrides={['Layout/FontProfiles']={face=function(f,w,v)
  local key=tostring(f)..':'..tostring(w)..':'..tostring(v);faces[key]=faces[key]or{Family=f,Weight=w or 400,Style=v or'normal'};return faces[key]
 end},['Layout/TextMeasure']={measure=function(text,_,size)measurements+=1;return{X=#text*size/2,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
 local resolveFont=overrides['Layout/FontProfiles'].face
 local checks,states,normDeltas,projections=0,0,0,0
 local function near(a,b,label)assert(type(a)=='number'and math.abs(a-b)<.08,label..': '..tostring(a)..' != '..tostring(b))end
 local function physical(box)
  local x,y=0,0;while box do
   local positioned=box.Style and box.Style.Position and box.Style.Position~='static'
   x+=if positioned then box.PaintX or box.LayoutX or 0 else box.LayoutX or 0
   y+=if positioned then box.PaintY or box.LayoutY or 0 else box.LayoutY or 0
   if positioned and box.Gui and box.Gui.Position then
    assert(math.abs(box.Gui.Position[1]-(box.PaintX or box.LayoutX or 0))<.08 and math.abs(box.Gui.Position[2]-(box.PaintY or box.LayoutY or 0))<.08,'Positioned actual GUI disagrees with paint coordinates')
   end
   box=box.LayoutParent
  end;return x,y
 end
 local function geometry(tree)
  local out={};local function visit(box)
   for _,key in {'LayoutX','LayoutY','PaintX','PaintY','OuterWidth','OuterHeight','ContentWidth','ContentHeight','OwnBottom'}do if type(box[key])=='number'then table.insert(out,key..':'..tostring(box[key]))end end
   if box.GridLayout and(box.Style.Display=='grid'or box.Style.Display=='inline-grid')then for _,axis in {box.GridLayout.Columns,box.GridLayout.Rows}do for i,t in axis.Tracks do table.insert(out,'track:'..i..':'..t.Size..':'..axis.Starts[i]..':'..axis.Ends[i])end end end
   for _,child in box.Children or{}do visit(child)end
  end;visit(tree);return table.concat(out,'|')
 end
 local function mount(html)
  local document=Parser.parseDocument(html);local root=factory.create('ScrollingFrame',nil,{});root:SetAttribute('Status','ready')
  local messages={};local function diagnostic(m)table.insert(messages,m)end
  local tree=renderer.build(document,root,diagnostic,resolveFont);tree.ViewportHeight=600
  local realm,flushing=nil,false;local pending,targets=false,{}
  local page={Alive=true,Document=document,DocumentURL='https://alignment.test/page',BaseURL='https://alignment.test/page',Root=root,Cleanups={}}
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  function page:GeometryViewport()return{Width=800,Height=600,ClientWidth=800,ClientHeight=600,ScrollWidth=800,ScrollHeight=600,ScrollX=0,ScrollY=0}end
  function page:HasPendingLayout()return pending end
  local function arrange(items)Dirty.begin(tree,items);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)end
  function page:FlushScriptLayout()
   if flushing or not realm then return end;flushing=true;local needed,items=realm:Flush()
   if pending then needed=true;items=items or{};for item in targets do items[item]=true end;pending=false;table.clear(targets)end
   if needed then arrange(items)end;flushing=false
  end
  arrange()
  local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
  function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode(key)return key.Name end
  local stop=Controller.start(page,tree,function(_,item)pending=true;if item then targets[item]=true end end,diagnostic,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=os.clock,PickerLayout=layout})
  local runService={RenderStepped=signal(),Heartbeat=signal()};local timers={}
  local tasks={delay=function(_,fn)local handle={Callback=fn,CancelCount=0};table.insert(timers,handle);return handle end,
   cancel=function(handle)handle.CancelCount+=1;assert(handle.CancelCount==1,'Mounted script timer cancelled twice')end}
  realm=assert(HTMLScripts.start(page,tree,function()end,diagnostic,{JavaScriptServices={Clock=os.clock,RunService=runService,Task=tasks}}));page.JavaScriptRuntime=realm
  local control=page.FormModel:Resolve(Node.findById(document,'editor'));local editor=control.Item.Editor;local connections=editor:ConnectionCount()
  local native={};for _,id in {'owner','a','b','editor','guard'}do local n=Node.findById(document,id);local b=tree.NodeBoxes[n];if b then native[id]={Node=n,Gui=b.Gui}end end
  local function settle()
   for _=1,16 do page:FlushScriptLayout();realm:AfterLayout();local tasks=realm:PumpTasks();if not realm:HasPending()and tasks==0 and not pending then break end end;page:FlushScriptLayout()
   assert(#messages==0,table.concat(messages,' | '));assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))
  end
  local function run(code)assert(realm:Run(code),code);settle()end
  run(reference.setup)
  local function retained(expected)
   assert(control.Item.Editor==editor and editor:ConnectionCount()==connections and not editor.Destroyed,'Alignment replaced/rebound native editor')
   assert(control.Value==expected.editor[2]and focused==editor and control.SelectionStart==1 and control.SelectionEnd==3 and control.SelectionDirection=='backward'and editor.CursorPosition==2 and editor.SelectionStart==6,'Alignment changed UTF16/native byte selection, editor focus or value')
   for id,old in native do assert(Node.findById(document,id)==old.Node and tree.NodeBoxes[old.Node].Gui==old.Gui,'Alignment recreated '..id)end
  end
  local function compare(expected,label,normative)
   retained(expected)
   for index,record in expected.boxes do
    local node=Node.findById(document,record.id);local b=tree.NodeBoxes[node]
    if record.rect[3]==0 and record.rect[4]==0 then
     assert(not b or b.Style.Hidden and (b.Gui.Visible==false or b.OpacityGroup and b.OpacityGroup.Visible==false),'Hidden retained boundary must not paint')
    else
     near(b.OuterWidth,record.rect[3],label..' '..record.id..' width');near(b.OuterHeight,record.rect[4],label..' '..record.id..' height')
     local x,y=physical(b);local r=if normative and record.id=='a'then normative.boxes[index].rect else record.rect
     near(x,r[1],label..' '..record.id..' x');near(y,r[2],label..' '..record.id..' y');checks+=1
     for i,field in {'AlignItems','AlignSelf','JustifyItems','JustifySelf','JustifyContent','Direction','WritingMode','AlignContent'}do
      local wanted=record.values[i];if wanted~='normal'and wanted~='auto'then assert(b.Style[field]==wanted,label..' used alignment '..record.id..' '..field..': '..tostring(b.Style[field])..' != '..wanted)end
     end
    end
   end
   local owner=tree.NodeBoxes[Node.findById(document,'owner')]
   if owner.GridLayout and(owner.Style.Display=='grid'or owner.Style.Display=='inline-grid')then
    for i,axis in {owner.GridLayout.Columns,owner.GridLayout.Rows}do
     local j=0;for size in expected.tracks[i]:gmatch('([%d%.]+)px')do j+=1;near(axis.Tracks[j].Size,tonumber(size),label..' preserved track '..i..'/'..j)end
     assert(j==#axis.Tracks,label..' native track count')
    end
   end
   run("if(alignmentEditor!==document.getElementById('editor')||document.activeElement!==alignmentEditor||alignmentEditor.value!=="..string.format('%q',expected.editor[2]).."||alignmentEditor.selectionStart!==1||alignmentEditor.selectionEnd!==3||alignmentEditor.selectionDirection!=='backward')throw new Error('Retained alignment editor')")
   local freshDocument=Parser.parseDocument(html)
   for _,id in {'owner','a','b','editor','guard'}do local from,to=Node.findById(document,id),Node.findById(freshDocument,id);to.Attributes=table.clone(from.Attributes)end
   local fresh=renderer.build(freshDocument,{},diagnostic,resolveFont);fresh.ViewportHeight=600;Dirty.begin(fresh);layout.arrange(fresh,800,0,0,function()return true end);Dirty.finish(fresh,true)
   assert(geometry(tree)==geometry(fresh),label..': retained layout differs from independent full layout')
   local measured,allocated=measurements,#objects;arrange();arrange();retained(expected)
   assert(measurements==measured and #objects==allocated,label..': warm arrangement remeasured or recreated surfaces')
   states+=1
  end
  local function dispose()
   editor.Text='changed by editor';editor:GetPropertyChangedSignal('Text'):Fire();assert(control.Value=='changed by editor','Alignment broke actual native input events')
   run("setTimeout(function(){throw new Error('Disposed alignment timer ran')},100000);requestAnimationFrame(function(){throw new Error('Disposed alignment frame ran')})")
   assert(realm.EventLoop.TimerCount==1 and realm.EventLoop.FrameCount==1 and runService.RenderStepped:Count()==1,'Actual mounted timer/frame must exist before disposal')
   realm:Destroy();stop();page.Alive=false;for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end
   assert(input.InputBegan:Count()==0 and input.InputChanged:Count()==0 and input.InputEnded:Count()==0 and input.WindowFocusReleased:Count()==0 and editor:ConnectionCount()==0,'Alignment leaked native editor/input bindings')
   assert(not realm.Alive and not realm:HasPending()and not realm.EventLoop.Alive and realm.EventLoop.TimerCount==0 and realm.EventLoop.TaskCount==0 and realm.EventLoop.FrameCount==0 and next(realm.EventLoop.Microtasks)==nil,'Mounted alignment runtime/event-loop jobs survived disposal')
   assert(not page.ScriptClock.Alive and runService.RenderStepped:Count()==0 and runService.Heartbeat:Count()==0 and root:GetAttributeChangedSignal('Status'):Count()==0,'Mounted alignment frame/status clock survived disposal')
   for _,timer in timers do assert(timer.CancelCount==1,'Mounted script timer was not cancelled')end
  end
  return{Run=run,Compare=compare,Dispose=dispose}
 end
 local counterparts={};for _,case in reference.cases do if case.normativeFor then counterparts[case.normativeFor]=case.states[1].expected end end
 for _,case in reference.cases do
  local host=mount(case.html)
  for i,state in case.states do
   if state.code~=''then host.Run(state.code)end
   local normative=counterparts[case.name]
   if normative then
    local raw,zero=state.expected.boxes[2].rect,normative.boxes[2].rect
    assert(raw[1]~=zero[1]or raw[2]~=zero[2],'The preserved Chromium Grid auto-overflow norm delta disappeared')
    near(raw[3],zero[3],'Normdelta unchanged width');near(raw[4],zero[4],'Normdelta unchanged height');normDeltas+=1
   end
   if state.targetExpected then projections+=1;assert(state.frozenControl and #state.frozenControl.changes>0,'Explicit frozen counterpart provenance')end
   host.Compare(state.targetExpected or state.expected,case.name..' '..i,normative)
  end;host.Dispose()
 end
 for _,case in {reference.dynamic,reference.dynamicContent,reference.dynamicSelf}do
  local host=mount(case.html);for i,state in case.states do if state.code~=''then host.Run(state.code)end;if state.targetExpected then projections+=1;assert(state.frozenControl and #state.frozenControl.changes>0,'Retained frozen counterpart provenance')end;host.Compare(state.targetExpected or state.expected,case.name..' '..i)end;host.Dispose()
 end
 for _,mode in {'horizontal-tb','vertical-rl','vertical-lr','sideways-rl','sideways-lr'}do for _,dir in {'ltr','rtl'}do
  local s={WritingMode=mode,Direction=dir};for _,horizontal in {true,false}do
   assert(Alignment.resolve('self-start',horizontal,{Direction='ltr'},s)~=Alignment.resolve('self-end',horizontal,{Direction='ltr'},s),'Opposite self edges')
  end
 end end
 for _,property in {'align-items','align-self'}do for _,value in {'self-start','self-end'}do local s=Style.resolve(Node.element('div',{style=property..':'..value}),{},error);assert(s[if property=='align-items'then'AlignItems'else'AlignSelf']==value,'Accepted alignment keyword')end end
 for _,value in {'left','right'}do assert(Style.resolve(Node.element('div',{style='justify-content:'..value}),{},error).JustifyContent==value,'Accepted physical content keyword')end
 for _,property in {'align-items','align-self'}do for _,value in {'left','right'}do
  local warnings={};local s=Style.resolve(Node.element('div',{style=property..':'..value}),{},function(m)table.insert(warnings,m)end)
  assert(#warnings>0 and s[if property=='align-items'then'AlignItems'else'AlignSelf']~=value,'Physical side keywords are invalid on align-*')
 end end
 assert(normDeltas==0 and projections==53 and states==962,'Every preserved raw/explicit normative and retained mutation state must run')

 local fields={['align-items']='AlignItems',['align-self']='AlignSelf',['justify-items']='JustifyItems',['justify-self']='JustifySelf',['align-content']='AlignContent',['justify-content']='JustifyContent'}
 local grammarRows,normalDeltas,shorthandRows,boundaries=0,0,0,0
 for _,record in reference.grammar do
  local wanted=record.accepted
  if (record.property=='align-self'or record.property=='justify-self')and(record.value=='safe normal'or record.value=='unsafe normal')then
   assert(wanted=='','Preserve raw qualified-normal native rejection');wanted=record.value;normalDeltas+=1
  end
  local entries=Style.compile(record.property..':'..record.value).Normal;local current
  for _,entry in entries do if not entry.Error and entry.Field==fields[record.property]then current=entry.Value end end
  assert((current or'')==wanted,'Exact overflow grammar '..record.property..' '..record.value..': '..tostring(current)..' != '..wanted)
  grammarRows+=1
 end
 for _,record in reference.additionalGrammar do
  -- Existing baseline families are outside the positional grammar slice. Their
  -- unchanged raw native rows remain evidence, not a false new completion.
  if record.value:find('baseline',1,true)then boundaries+=1;continue end
  local alignWanted,justifyWanted=record.align,record.justify
  if record.property=='place-self'and(record.value=='safe normal'or record.value=='unsafe normal')then alignWanted,justifyWanted=record.value,record.value;normalDeltas+=1 end
  if record.property=='place-self'and record.value=='unsafe normal safe end'then alignWanted,justifyWanted='unsafe normal','safe end';normalDeltas+=1 end
  local suffix=record.property:sub(7);local entries=Style.compile(record.property..':'..record.value).Normal;local a,b
  for _,entry in entries do if not entry.Error then if entry.Field==fields['align-'..suffix]then a=entry.Value elseif entry.Field==fields['justify-'..suffix]then b=entry.Value end end end
  assert((a or'')==alignWanted and(b or'')==justifyWanted,'Exact positional shorthand grammar '..record.property..' '..record.value..': '..tostring(a)..'/'..tostring(b))
  shorthandRows+=1
 end
 assert(grammarRows==108 and normalDeltas==7 and shorthandRows+boundaries==57,'Exact preserved grammar/explicit frozen-normal inventory')
 print('Overflow grammar: '..grammarRows..' longhand + '..shorthandRows..' positional shorthand rows, '..normalDeltas..' explicit qualified-normal deltas; '..boundaries..' retained baseline boundary rows')
 print('Overflow alignment: '..states..' fixed box states, '..checks..' box comparisons, raw native geometry; retained CSSOM/class/variable/direction/editor/UTF16 selection, fresh parity and warm surfaces passed')
end
