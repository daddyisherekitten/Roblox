--!strict
return function(Parser,Node,Runtime,Events,Selectors,Stylesheet,Dirty,Controller,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,fixture,frozen,additional)
 local function jsString(value)return '"'..value:gsub('[%z\1-\31\\"]',function(c)return if c=='"'or c=='\\'then '\\'..c else string.format('\\u%04x',string.byte(c))end)..'"'end
 local function color(value)local r,g,b=value:match('rgb%((%d+), (%d+), (%d+)%)');return Color3.fromRGB(tonumber(r),tonumber(g),tonumber(b))end
 local document=Parser.parseDocument(fixture.html);local events=Events.new(error);local runtime=Runtime.new(document,{Events=events,ControlAdapter={},Schedule=function()end})
 assert(runtime:Run('(()=>{'..fixture.setup..'})()'))
 local comparisons,normDeltas=0,0;local equivalents={};local cases=table.clone(fixture.cases)
 for _,case in frozen.cases do equivalents[case.normativeFor]=case;table.insert(cases,case)end
 for _,case in cases do
  local counterpart=equivalents[case.name];local colors=if counterpart then counterpart.expected.colors else case.expected.colors
  local compiled=Selectors.compile(case.selector,nil,case.namespaces)
  local valid=case.expected.selectorText~=nil
  assert((compiled~=nil)==valid,case.name..': namespace grammar differs from native rule acceptance')
  local messages={};local rules=Stylesheet.collect(document,function(m)table.insert(messages,m)end,case.css)
  assert(runtime:Run('(()=>{const sheet=new CSSStyleSheet();sheet.replaceSync('..jsString(case.css)..');globalThis.nsCount=sheet.cssRules.length;})()'),case.name)
  assert(runtime.Window.Get('nsCount')==case.expected.count,case.name..': actual namespace CSSOM rule count')
  for _,m in messages do assert(not valid and m:find('Unsupported CSS selector',1,true),case.name..': '..m)end
  for recordIndex,record in colors do
   if counterpart and record[2]~=case.expected.colors[recordIndex][2]then normDeltas+=1 end
   local node=assert(Node.findById(document,record[1]));local wanted=record[2]=='rgb(17, 53, 91)'
   if compiled then assert(Selectors.matches(node,compiled)==wanted,case.name..' '..record[1]..': subject/ancestor namespace match')end
   local selected=Stylesheet.rawMatch(rules,node);assert(selected.Normal[#selected.Normal].Value==record[2]:gsub(' ',''),case.name..' '..record[1]..': actual stylesheet namespace cascade winner');comparisons+=1
  end
 end
 assert(normDeltas==99 and comparisons==6840,'Preserved explicit frozen/native namespace deltas and native controls')
 for _,case in additional.dom do
  assert(runtime:Run('globalThis.nsDOMResult='..case.action),case.name)
  assert(runtime.Window.Get('nsDOMResult')==case.expected,case.name..': actual mixednamespace DOM matches/queries')
 end
 local winnerDeltas,extraComparisons=0,0
 for _,case in additional.winners do
  local compiled=assert(Selectors.compile(case.selector,nil,case.namespaces));assert(table.concat(compiled.Specificity,',')==table.concat(case.specificity,','),case.name..': namespace context changed specificity')
  local rules=Stylesheet.collect(document,error,case.css)
  local colors=if case.name==additional.winnerEquivalent.normativeFor then additional.winnerEquivalent.expected.colors else case.expected.colors
  for i,record in colors do
   if record[2]~=case.expected.colors[i][2]then winnerDeltas+=1 end
   local selected=Stylesheet.rawMatch(rules,Node.findById(document,record[1]));assert(selected.Normal[#selected.Normal].Value==record[2]:gsub(' ',''),case.name..' '..record[1]..': actual namespace specificity winner');extraComparisons+=1
  end
 end
 local equivalent=additional.winnerEquivalent;local equivalentRules=Stylesheet.collect(document,error,equivalent.css)
 assert(table.concat(Selectors.compile(equivalent.selector,nil,equivalent.namespaces).Specificity,',')==table.concat(equivalent.specificity,','),'Explicit max-ID equivalent retains specificity')
 for _,record in equivalent.expected.colors do local selected=Stylesheet.rawMatch(equivalentRules,Node.findById(document,record[1]));assert(selected.Normal[#selected.Normal].Value==record[2]:gsub(' ',''),'Actual independently captured maximum-ID equivalent');extraComparisons+=1 end
 for _,case in additional.scopeExplicit do
  local rules=Stylesheet.collect(document,error,case.css)
  assert(runtime:Run('(()=>{const sheet=new CSSStyleSheet();sheet.replaceSync('..jsString(case.css)..');const rule=sheet.cssRules[sheet.cssRules.length-1];globalThis.nsScopeResult=JSON.stringify([sheet.cssRules.length,rule.constructor.name]);})()'),case.name)
  assert(runtime.Window.Get('nsScopeResult')=='['..case.expected.count..',"'..case.expected.type..'"]',case.name..': actual namespaced CSSOM scope rule tree')
  for _,record in case.expected.colors do local selected=Stylesheet.rawMatch(rules,Node.findById(document,record[1]));assert(selected.Normal[#selected.Normal].Value==record[2]:gsub(' ',''),case.name..' '..record[1]..': author-explicit scope anchor namespace cascade');extraComparisons+=1 end
 end
 assert(winnerDeltas==18 and extraComparisons==360,'Bounded preserved specificity raw/frozen delta and author-explicit scope controls')
 assert(#runtime.Diagnostics==0,table.concat(runtime.Diagnostics,' | '));runtime:Destroy();events:Destroy()

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
  function gui:Destroy()assert(not self.Destroyed,'Namespace disposed GUI twice');self.Destroyed=true;self:ReleaseFocus();self.Parent=nil end
  table.insert(objects,gui);return gui
 end};factory.modifier=factory.create
 local measurements=0;local faces={}
 local overrides={['Layout/FontProfiles']={face=function(f,w,v)local k=tostring(f)..':'..tostring(w)..':'..tostring(v);faces[k]=faces[k]or{Family=f,Weight=w or 400,Style=v or'normal'};return faces[k]end},['Layout/TextMeasure']={measure=function(text,_,size)measurements+=1;return{X=#text*size/2,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
 local resolveFont=overrides['Layout/FontProfiles'].face
 document=Parser.parseDocument(fixture.retainedHTML);local root=factory.create('ScrollingFrame',nil,{});root:SetAttribute('Status','ready')
 local messages={};local function diagnostic(m)table.insert(messages,m)end
 local tree=renderer.build(document,root,diagnostic,resolveFont);tree.ViewportHeight=600
 local realm,flushing=nil,false;local pending,targets=false,{};local arrangements=0
 local page={Alive=true,Document=document,DocumentURL='https://namespace.test/page',BaseURL='https://namespace.test/page',Root=root,Cleanups={}}
 function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
 function page:GeometryViewport()return{Width=800,Height=600,ClientWidth=800,ClientHeight=600,ScrollWidth=800,ScrollHeight=600,ScrollX=0,ScrollY=0}end
 function page:HasPendingLayout()return pending end
 local function arrange(items)arrangements+=1;Dirty.begin(tree,items);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)end
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
 local tasks={delay=function(_,fn)local h={Callback=fn,CancelCount=0};table.insert(timers,h);return h end,cancel=function(h)h.CancelCount+=1;assert(h.CancelCount==1,'Namespace timer canceled twice')end}
 realm=assert(HTMLScripts.start(page,tree,function()end,diagnostic,{JavaScriptServices={Clock=os.clock,RunService=runService,Task=tasks}}));page.JavaScriptRuntime=realm
 local function settle()
  for _=1,16 do page:FlushScriptLayout();realm:AfterLayout();local count=realm:PumpTasks();if not realm:HasPending()and count==0 and not pending then break end end;page:FlushScriptLayout()
  assert(#messages==0,table.concat(messages,' | '));assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))
 end
 local function run(code)assert(realm:Run('(()=>{'..code..'})()'),code);settle()end
 settle()
 local target=Node.findById(document,'target');local kept=Node.findById(document,'kept');local control=page.FormModel:Resolve(kept);local editor=control.Item.Editor;local connections=editor:ConnectionCount()
 local surfaceItem;for _,item in tree.TextItems do if item.Text=='Surface'then surfaceItem=item;break end end;assert(surfaceItem,'Retained surface label');local surfaceGui=surfaceItem.TextGui or surfaceItem.Gui
 local native={};for _,id in {'target','branch','leaf','kept','outside'}do local n=Node.findById(document,id);local b=tree.NodeBoxes[n];if b then native[id]={Node=n,Box=b,Gui=b.Gui}end end
 local function geometry(current)
  local out={};local function visit(box)for _,key in {'LayoutX','LayoutY','OuterWidth','OuterHeight','ContentWidth','ContentHeight'}do if type(box[key])=='number'then table.insert(out,key..':'..tostring(box[key]))end end;for _,child in box.Children or{}do visit(child)end end;visit(current);return table.concat(out,'|')
 end
 for index,case in fixture.retained do
  local before=arrangements;run(case.code);local expected=case.expected
  assert(tree.NodeStyles[target].Color==color(expected.color),case.name..': retained computed namespace color')
  assert((surfaceItem.TextGui or surfaceItem.Gui)==surfaceGui and surfaceGui.TextColor3==color(expected.color),case.name..': retained original label repaint')
  assert(control.Item.Editor==editor and editor:ConnectionCount()==connections and not editor.Destroyed and control.Value==expected.value,case.name..': editor/value/binding retention')
  for id,old in native do assert(Node.findById(document,id)==old.Node and tree.NodeBoxes[old.Node]==old.Box and old.Box.Gui==old.Gui,case.name..': recreated '..id)end
  if index>1 then
   assert(focused==editor and control.SelectionStart==expected.selectionStart and control.SelectionEnd==expected.selectionEnd and control.SelectionDirection==expected.selectionDirection and editor.CursorPosition==2 and editor.SelectionStart==6,case.name..': UTF16/native byte selection/focus')
  end
  run('const i=document.getElementById("kept");if(document.getElementById("sheet").sheet.cssRules.length!=='..expected.count..')throw new Error("Namespace CSSOM count");if(i.value!=='..jsString(expected.value)..')throw new Error("Namespace retained value");'..(if index>1 then 'if(document.activeElement!==i||i.selectionStart!==1||i.selectionEnd!==3||i.selectionDirection!=="backward")throw new Error("Namespace editor selection");'else ''))
  if case.paintOnly or index>=3 then assert(arrangements==before,case.name..': namespace selector/color mutation must retain layout')end
  run('globalThis.nsCurrentCSS=Array.from(document.getElementById("sheet").sheet.cssRules,r=>r.cssText).join(" ")')
  local css=realm.Window.Get('nsCurrentCSS');local freshHTML=fixture.retainedHTML:gsub('<style id=sheet>.-</style>',function()return '<style id=sheet>'..css..'</style>'end)
  local freshDocument=Parser.parseDocument(freshHTML)
  for _,id in {'target','branch','leaf','kept','outside'}do local from,to=Node.findById(document,id),Node.findById(freshDocument,id);to.Attributes=table.clone(from.Attributes)end
  Node.findById(freshDocument,'kept').Attributes.value=control.Value
  local fresh=renderer.build(freshDocument,{},diagnostic,resolveFont);fresh.ViewportHeight=600;Dirty.begin(fresh);layout.arrange(fresh,800,0,0,function()return true end);Dirty.finish(fresh,true)
  assert(geometry(tree)==geometry(fresh),case.name..': retained geometry differs from independently fresh full layout')
  for _,id in {'target','branch','leaf','outside'}do assert(tree.NodeStyles[Node.findById(document,id)].Color==fresh.NodeStyles[Node.findById(freshDocument,id)].Color,case.name..': dirty/full paint parity '..id)end
  local measured,allocated=measurements,#objects;arrange();arrange();assert(measurements==measured and #objects==allocated,case.name..': warm layout remeasured/recreated surfaces')
  assert(control.Item.Editor==editor and (surfaceItem.TextGui or surfaceItem.Gui)==surfaceGui,case.name..': warm editor/label identity')
 end
 editor.Text='changed by editor';editor:GetPropertyChangedSignal('Text'):Fire();assert(control.Value=='changed by editor','Namespace mutations broke actual native editor events')
 run("setTimeout(function(){throw new Error('Disposed namespace timer ran')},100000);requestAnimationFrame(function(){throw new Error('Disposed namespace frame ran')})")
 assert(realm.EventLoop.TimerCount==1 and realm.EventLoop.FrameCount==1 and runService.RenderStepped:Count()==1,'Actual namespace timer/frame exists')
 realm:Destroy();stop();page.Alive=false;for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end
 assert(input.InputBegan:Count()==0 and input.InputChanged:Count()==0 and input.InputEnded:Count()==0 and input.WindowFocusReleased:Count()==0 and editor:ConnectionCount()==0,'Namespace leaked editor/input bindings')
 assert(not realm.Alive and not realm:HasPending()and not realm.EventLoop.Alive and realm.EventLoop.TimerCount==0 and realm.EventLoop.TaskCount==0 and realm.EventLoop.FrameCount==0 and next(realm.EventLoop.Microtasks)==nil,'Namespace jobs survived disposal')
 assert(not page.ScriptClock.Alive and runService.RenderStepped:Count()==0 and runService.Heartbeat:Count()==0 and root:GetAttributeChangedSignal('Status'):Count()==0,'Namespace clock survived disposal')
 for _,timer in timers do assert(timer.CancelCount==1,'Namespace timer not canceled')end
 print('Default namespaces: '..#fixture.cases..' raw CSSOM grammar/style cases plus '..#frozen.cases..' explicit native equivalent controls; '..normDeltas..' named frozen/native projections, '..comparisons..' actual selector/stylesheet namespace subjects and '..#fixture.retained..' retained labels/editor/paint states; 2 actual DOM sequences, 6 specificity winners+1 independent explicit equivalent (18 separate raw/frozen projections), 8 author-explicit CSSOM scope cases passed')
end
