--!strict
-- Paused deterministic samples shared with an actual Chromium reference. Both
-- CSSOM geometry and native paint are checked over the retained renderer.
return function(Parser,Node,Runtime,VM,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLAnimations,fixtures,ProjectiveHit,ViewportLayer,BorderCorners,cssDOMFixtures,InsetShadows)
 local factory={};local images={};local objects={}
 function factory.create(class,parent,props)
  local gui=table.clone(props);gui.ClassName=class;gui.Parent=parent
  function gui:IsA(kind)return kind==self.ClassName or kind=='GuiObject'or kind=='Instance'end
  function gui:Destroy()self.Destroyed=true;self.Parent=nil end;table.insert(objects,gui);return gui
 end
 factory.modifier=factory.create
 function factory.createImage(size)
  local value={Size=size,Writes=0};function value:WritePixelsBuffer(_,_,pixels)self.Pixels=pixels;self.Writes+=1 end
  function value:Destroy()assert(not self.Destroyed,'An animation texture is disposed once');self.Destroyed=true end;table.insert(images,value);return value
 end
 local renderer=loadRenderTree(factory)
 local measurements=0
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)measurements+=1;return {X=#text*size/2,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local function near(a,b,label)assert(type(a)=='number'and math.abs(a-b)<.001,(label or'number')..': '..tostring(a)..' ~= '..tostring(b))end
 local function fixture(css,cssMotion,withViewport,prepare,clock)
  clock=clock or function()return 0 end
  local firstImage=#images+1
  local document=Parser.parseDocument('<html><head></head><body><div id="parent"><div id="box"></div></div><div id="outside">Unchanged</div></body></html>')
  if prepare then prepare(document)end
  local root={AbsoluteSize=Vector2.new(600,800),AbsolutePosition=Vector2.new(0,0),CanvasPosition=Vector2.new(0,0),Parent=if withViewport then {}else nil}
  local messages={};local cornerPainter=BorderCorners.new(function(value)table.insert(messages,value)end,factory.createImage)
  local insetPainter=InsetShadows.new(function(value)table.insert(messages,value)end,factory.createImage)
  local tree=renderer.build(document,root,function(s)table.insert(messages,s)end,nil,nil,insetPainter,nil,
   'html,body{margin:0;padding:0}#box{width:200px;height:100px;background:white}'..(css or''),nil,cornerPainter)
  local s={Tree=tree,Document=document,Layouts=0,Requests=0,Diagnostics={},Values={},Stats={}}
  local pending=false;local targets={};local flushing=false;local runtime
  local function arrange(items)
   tree.ViewportHeight=800
   local stats=Dirty.begin(tree,items);layout.arrange(tree,600,0,0,function()return true end);Dirty.finish(tree,true)
   if withViewport then ViewportLayer.attach(tree,root,factory);ViewportLayer.update(tree,root)end
   table.insert(s.Stats,stats)
  end
  arrange(nil)
  local page={Alive=true,Root={SetAttribute=function()end},Cleanups={}}
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  function page:RequestAnimationLayout(box)s.Requests+=1;pending=true;targets[box]=true end
  function page:HasPendingLayout()return pending end
  function page:FlushScriptLayout()
   if flushing or not runtime then return end;flushing=true
   for attempt=1,4 do
    local needed=runtime:Flush()
    if not needed and not pending then break end
    local items=targets;targets={};pending=false;s.Layouts+=1;arrange(if next(items)then items else nil);if s.CSS then s.CSS:AfterLayout()end;runtime:AfterLayout()
    assert(attempt<4 or not pending,'Stable animation sample did not converge after publication')
   end
   flushing=false
  end
  local cssFrame
  if cssMotion then
   s.CSS=HTMLAnimations.start(page,tree,error,{Clock=clock,RunService={Heartbeat={Connect=function(_,fn)cssFrame=fn;return {Disconnect=function()cssFrame=nil end}end}}},20)
   s.CSS:AfterLayout();assert(not cssFrame,'A paused CSS reference owns no idle subscription')
  end
  runtime=Runtime.new(document,{Events=Events.new(error),Clock=clock,
   Diagnostic=function(value)table.insert(s.Diagnostics,value)end,Console=function(_,value)table.insert(s.Values,value)end,
   CreateAnimationAdapter=function()s.Adapter=HTMLAnimations.scriptAdapter(page,tree,error);return s.Adapter end,
   GeometryAdapter={GetTree=function()return tree end,GetViewport=function()return {Width=600,Height=800,ClientWidth=600,ClientHeight=800}end,
    HasPending=function()return runtime:HasPending()or pending end,Flush=function()page:FlushScriptLayout()end},
   ApplyChanges=function(changes)
    local needed,items=tree:ApplyDOMChanges(changes);pending=pending or needed
    if not needed and s.CSS then local affected={};for node in changes do affected[node]=true end;s.CSS:AfterLayout(affected)end
    for item,reason in items or{}do targets[item]=reason end;return needed,items
   end})
  s.Runtime,s.Page,s.Messages=runtime,page,messages;s.Node=Node.findById(document,'box');s.Outside=tree.NodeBoxes[Node.findById(document,'outside')]
  function s:Run(source)runtime:Run(source);page:FlushScriptLayout();runtime:AfterLayout();runtime:PumpTasks();page:FlushScriptLayout()end
  function s:AssertIdle(label)assert(not cssFrame and runtime.EventLoop.FrameCount==0,label..': paused/finished CSS DOM effects retain neither a native CSS subscription nor a script frame request (frames='..tostring(runtime.EventLoop.FrameCount)..', diagnostics='..table.concat(s.Diagnostics,' / ')..')')end
  function s:Destroy(label)
   runtime:Destroy();for _,cleanup in page.Cleanups do cleanup()end;page.Alive=false
   tree.VisualEffects:Destroy();cornerPainter:Destroy();insetPainter:Destroy();for index=firstImage,#images do assert(images[index].Destroyed,'Disposed animation releases its projected, inset and rounded textures')end
   if withViewport then local layer=tree.ViewportLayer;ViewportLayer.destroy(tree);assert(not layer or layer.Destroyed,'Disposed page releases its retained fixed overlay')end
   for _,box in tree.NodeBoxes do assert(box.AnimationTransformContainingBlock==nil and box.HasScriptTransformEffects==nil and box.CSSAnimationTransformEffects==nil,'Disposed effects release implicit transform positioning state');assert(not box.AnimationMetricAuthor,'Disposed metric effects release author bases');assert(not box.AnimationTextShadowAuthor and not box.AnimationTextShadowInherited,'Disposed text shadows release author/inherited bases');assert(not box.AnimationColorAuthor and not box.AnimationColorInherited and not box.HasScriptColorEffects,(label or 'Animation')..': disposed color effects release author and inherited bases on '..tostring(box.Node.Attributes and box.Node.Attributes.id or box.Node.Kind))end
   assert(not tree.AnimationMetricOverrides or next(tree.AnimationMetricOverrides)==nil,'Disposed metrics retain no target override map')
   assert(not tree.AnimationColorOverrides or next(tree.AnimationColorOverrides)==nil,'Disposed colors retain no target override map')
   assert(not tree.AnimationTextShadowOverrides or next(tree.AnimationTextShadowOverrides)==nil,'Disposed text shadows retain no target override map')
   assert(not cssFrame,'Disposed CSS reference releases its frame subscription')
   assert(not s.CSS or not next(s.CSS.OwnedCSSRecords),'Disposed CSS controllers release canceled/completed owning-element records')
   assert(runtime.EventLoop.FrameCount==0 and runtime.EventLoop.TaskCount==0,'Disposed animations retain neither frames nor tasks')
  end
  return s
 end
 local cssDOMNativeCount,cssDOMNormativeCount=0,0
 for _,reference in cssDOMFixtures and cssDOMFixtures.cases or{}do
  if reference.name:sub(1,4)~='CSS 'and reference.name~='event dispatch and handler identity'and not reference.asynchronous then continue end
  local s=fixture(reference.css,true,false,function(doc)Node.append(Node.findById(doc,'box'),Node.element('div',{id='leaf'}))end)
  local box=s.Tree.NodeBoxes[s.Node];local boxGui,cache=box.Gui,s.Outside.CachedLayout
  if reference.asynchronous then
   s:Run('(async function(){'..reference.source..'})().then(values=>values.forEach(value=>console.log(value)));')
   for _=1,12 do if #s.Values>0 or #s.Diagnostics>0 then break end;s.Runtime:PumpFrame();s.Runtime:PumpTasks();s.Page:FlushScriptLayout();s.Runtime:AfterLayout()end
  else s:Run('const cssDOMResult=(function(){'..reference.source..'})();cssDOMResult.forEach(value=>console.log(value));')end
  assert(#s.Diagnostics==0,reference.name..': '..table.concat(s.Diagnostics,' / '))
  local expectedValues=reference.engineExpected or reference.expected
  assert(#s.Values==#expectedValues,reference.name..': output count '..#s.Values..' ~= '..#expectedValues)
  for index,expected in expectedValues do assert(s.Values[index]==expected,reference.name..' ['..index..']: '..s.Values[index]..' ~= '..expected)end
  assert(s.Tree.NodeBoxes[s.Node].Gui==boxGui and s.Outside.CachedLayout==cache,reference.name..': CSS DOM control retains target GUI and unrelated cache')
  -- These references contain only DOM animation control. Authored animation
  -- property changes still pass through the engine's general style cascade.
  if reference.name=='CSS animation list identity'or reference.name=='CSS animation finish reverse error'or reference.name=='CSS transition seek reversal identity'or reference.name=='event dispatch and handler identity'or reference.name=='CSS animation computed sparse keyframes'or reference.name:sub(1,14)=='CSS keyframes 'then assert(s.Layouts==0,reference.name..': paint-only CSS DOM calls must not arrange flow')end
  s:AssertIdle(reference.name)
  s:Destroy();if reference.engineExpected then cssDOMNormativeCount+=1 else cssDOMNativeCount+=1 end
 end
 local silentCSS=fixture('#box{animation:move 2s linear both paused}@keyframes move{from{opacity:0}to{opacity:1}}',true)
 silentCSS:Run("document.getElementById('box').style.animationName='none';")
 assert(#silentCSS.Diagnostics==0,'An unread generated CSS finished promise is intrinsically handled when CSS cancels it')
 silentCSS:Run("const author=document.getElementById('box').animate([{opacity:0},{opacity:1}],{duration:1000});author.ready.catch(()=>{});author.cancel();")
 assert(#silentCSS.Diagnostics==1 and silentCSS.Diagnostics[1]:find('Unhandled promise rejection: AbortError',1,true),'An uncaught author animation rejection remains observable')
 silentCSS:Destroy()
 local owning=fixture('#box{opacity:0!important;transition:opacity 2s linear}#box.active{opacity:1!important}#liveField{width:20px;height:10px}',true,false,function(doc)Node.append(Node.findById(doc,'box'),Node.element('input',{id='liveField',value='kept'}))end)
 local owningBox=owning.Tree.NodeBoxes[owning.Node];local owningControl
 for _,control in owning.Tree.Controls do if control.Node.Attributes.id=='liveField'then owningControl=control;break end end
 local owningGui,owningEditor=owningBox.Gui,assert(owningControl).Item.Gui
 owningEditor.Text='live';owningEditor.CursorPosition=3;owningEditor.SelectionStart=1
 owning:Run("const owner=document.getElementById('box');owner.className='active';owner.offsetWidth;const owned=owner.getAnimations()[0];owned.finished.catch(()=>{});owned.ready.catch(()=>{});owned.pause();owned.currentTime=500;owned.cancel();console.log(getComputedStyle(owner).opacity);")
 assert(#owning.Diagnostics==0 and owning.Values[1]=='1','Cancel restores the important author opacity while retaining CSS ownership')
 local owningRecord;local ownerCount=0;for record in owning.CSS.OwnedCSSRecords do ownerCount+=1;owningRecord=record end
 assert(ownerCount==1 and owningRecord.DOMCanceled and not owningRecord.Removed,'An API-canceled transition retains one owning-element record and no active pixels')
 assert(not owning.CSS.Transitions[owningBox],'API cancellation releases its active transition painter')
 owning:AssertIdle('Canceled owned transition')
 owning:Run("owned.pause();owned.ready.catch(()=>{});owned.currentTime=1000;console.log(getComputedStyle(owner).opacity);owned.finish();")
 assert(#owning.Diagnostics==0 and owning.Values[2]=='0.5'and owning.CSS.OwnedCSSRecords[owningRecord]and not owningRecord.DOMCanceled,'Replay reuses its original record and transition origin above important author opacity')
 owning:AssertIdle('Finished owned transition')
 assert(owningBox.Gui==owningGui and owningControl.Item.Gui==owningEditor and owningEditor.Text=='live'and owningEditor.CursorPosition==3 and owningEditor.SelectionStart==1 and owning.Layouts==0,'Cancel/replay/finish preserve the native box/editor/text selection without flow layout')
 owning:Run("owner.className='';owner.offsetWidth;const next=owner.getAnimations()[0];next.finished.catch(()=>{});next.ready.catch(()=>{});next.pause();next.currentTime=500;")
 assert(#owning.Diagnostics==0 and not owning.CSS.OwnedCSSRecords[owningRecord]and owningRecord.Removed,'A new authored transition invalidates completed old ownership instead of retaining stale records')
 ownerCount=0;for _ in owning.CSS.OwnedCSSRecords do ownerCount+=1 end;assert(ownerCount==1,'A replaced transition retains exactly its current owner record')
 owning:Run('owner.remove();')
 assert(#owning.Diagnostics==0 and not next(owning.CSS.OwnedCSSRecords),'Removing the rendered owner releases every inactive/completed transition record')
 owning:AssertIdle('Removed owning element');owning:Destroy()
 local elapsed=0
 local handoff=fixture('#box{opacity:0;transition:opacity .5s linear}#box.active{opacity:1}',true,false,nil,function()return elapsed end)
 handoff:Run("const handoffTarget=document.getElementById('box');handoffTarget.className='active';handoffTarget.offsetWidth;const handoffEffect=handoffTarget.getAnimations()[0];handoffEffect.ready.catch(()=>{});handoffEffect.finished.catch(()=>{});")
 elapsed=.25;handoff.Runtime:PumpFrame();handoff.Runtime:PumpTasks();handoff.Page:FlushScriptLayout();handoff.Runtime:AfterLayout()
 handoff:Run("console.log(String(handoffEffect.currentTime));console.log(String(handoffEffect.startTime));console.log(getComputedStyle(handoffTarget).opacity);")
 assert(table.concat(handoff.Values,'|')=='250|0|0.5','Initial CSS DOM ownership preserves authored elapsed time instead of restarting at its first pending frame')
 elapsed=.55;handoff.Runtime:PumpFrame();handoff.Runtime:PumpTasks();handoff.Page:FlushScriptLayout();handoff.Runtime:AfterLayout()
 handoff:Run("console.log(handoffEffect.playState);console.log(String(handoffEffect.currentTime));console.log(getComputedStyle(handoffTarget).opacity);")
 assert(handoff.Values[4]=='finished'and handoff.Values[5]=='500'and handoff.Values[6]=='1'and handoff.Layouts==0,'Authored paint transition finishes at its source duration with no layout')
 handoff:AssertIdle('Initial CSS timeline handoff');handoff:Destroy()
 elapsed=0
 local sought=fixture('#box{opacity:0;transition:opacity .5s linear}#box.active{opacity:1}',true,false,nil,function()return elapsed end)
 sought:Run("const soughtTarget=document.getElementById('box');soughtTarget.className='active';soughtTarget.offsetWidth;const soughtEffect=soughtTarget.getAnimations()[0];soughtEffect.ready.catch(()=>{});soughtEffect.finished.catch(()=>{});soughtEffect.currentTime=50;")
 elapsed=.25;sought.Runtime:PumpFrame();sought.Runtime:PumpTasks();sought.Page:FlushScriptLayout();sought.Runtime:AfterLayout()
 sought:Run("console.log(String(soughtEffect.currentTime));console.log(getComputedStyle(soughtTarget).opacity);soughtEffect.cancel();")
 assert(table.concat(sought.Values,'|')=='50|0.1','An author seek before CSS readiness replaces the source anchor with the held seek sample')
 sought:AssertIdle('Sought initial CSS handoff');sought:Destroy()
 for _,mode in {'add','accumulate'}do
  local s=fixture('#box{transform:translateX(40px) rotate(25deg)}')
  s:Run("const box=document.getElementById('box');const a=box.animate({transform:['translateX(0)','translateX(60px)']},{duration:1000,fill:'both',composite:'"..mode.."'});a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();a.currentTime=500;const value=getComputedStyle(box).transform;const m=value.slice(value.indexOf('(')+1,-1).split(',');console.log(String(parseFloat(m[4])));console.log(String(parseFloat(m[5])));")
  assert(#s.Diagnostics==0 and #s.Values==2,'Paused composition publishes its computed matrix')
  near(tonumber(s.Values[1]),if mode=='add'then 67.1892 else 70,'WAAPI '..mode..' horizontal direction')
  near(tonumber(s.Values[2]),if mode=='add'then 12.6785 else 0,'WAAPI '..mode..' vertical direction')
  assert(s.Layouts==0,'Compositing transforms preserves normal document layout');s:Destroy()
 end
 local ordered=fixture('#parent{display:flex;align-items:flex-start}#box{width:40px;height:20px;flex-shrink:0}')
 ordered:Run("const target=document.getElementById('box');const parent=document.getElementById('parent');const peer=document.createElement('div');peer.id='peer';peer.style.cssText='width:20px;height:20px;order:1;flex-shrink:0';parent.appendChild(peer);const field=document.createElement('input');field.id='retainedField';field.style.cssText='width:20px;height:10px';target.appendChild(field);const orderAnimation=target.animate({order:['0','4']},{duration:100,fill:'both'});orderAnimation.finished.catch(()=>{});orderAnimation.ready.catch(()=>{});orderAnimation.pause();orderAnimation.currentTime=0;")
 assert(#ordered.Diagnostics==0,'Integer order setup mounts its retained Flex siblings and input')
 local orderedBox=ordered.Tree.NodeBoxes[ordered.Node];local originalStyle=orderedBox.Style;local originalGui=orderedBox.Gui
 -- Find retained native state directly: wrapper identity alone does not prove
 -- that an order change preserved the actual textbox or rendered sibling.
 local peerBox
 for node,box in ordered.Tree.NodeBoxes do if node.Attributes and node.Attributes.id=='peer'then peerBox=box end end
 local control
 for _,entry in ordered.Tree.Controls do if entry.Node.Attributes.id=='retainedField'then control=entry end end
 assert(peerBox and control,'Dynamically appended sibling and control are rendered')
 local peerGui=peerBox.Gui;local fieldGui=control.Item.Gui
 fieldGui.Text='live selection';fieldGui.CursorPosition=4;fieldGui.SelectionStart=2
 local cached=ordered.Outside.CachedLayout
 ordered:Run('orderAnimation.currentTime=50;console.log(String(target.getBoundingClientRect().x));')
 assert(#ordered.Diagnostics==0 and ordered.Values[1]=='20'and orderedBox.Style.Order==2,'Rounded order is used by the actual Flex layout')
 assert(orderedBox.Gui==originalGui and orderedBox.Style==originalStyle and peerBox.Gui==peerGui and control.Item.Gui==fieldGui,'Reordering retains rendered box, style, sibling and control identity')
 assert(fieldGui.Text=='live selection'and fieldGui.CursorPosition==4 and fieldGui.SelectionStart==2,'Flex order preserves live native selection')
 assert(ordered.Outside.CachedLayout==cached,'Reordering does not rebuild an unrelated retained layout cache')
 ordered:Run('orderAnimation.cancel();console.log(String(target.getBoundingClientRect().x));')
 assert(ordered.Values[2]=='0'and orderedBox.Style.Order==0,'Cancellation restores author ordering and native geometry')
 ordered:Destroy()
 local shorthand=fixture('#box{width:100px;height:40px;margin:2px;padding:4px;display:flex}#shorthandField{width:20px;height:10px;padding:0;border:0}')
 shorthand:Run("const shorthandTarget=document.getElementById('box');const field=document.createElement('input');field.id='shorthandField';shorthandTarget.appendChild(field);const spacing=shorthandTarget.animate({margin:['2px 4px','6px 8px'],padding:['2px 4px','10px 12px'],gap:['2px 4px','6px 8px']},{duration:100,fill:'both'});spacing.finished.catch(()=>{});spacing.ready.catch(()=>{});spacing.pause();spacing.currentTime=50;")
 assert(#shorthand.Diagnostics==0,'Shorthand animation mounts and samples the real control')
 local shorthandBox=shorthand.Tree.NodeBoxes[shorthand.Node];local shorthandControl
 for _,entry in shorthand.Tree.Controls do if entry.Node.Attributes.id=='shorthandField'then shorthandControl=entry.Item end end
 assert(shorthandControl,'A native input is retained inside the shorthand target')
 local shorthandGui,shorthandEditor=shorthandBox.Gui,shorthandControl.Editor
 shorthandEditor.Text='selection';shorthandEditor.CursorPosition=4;shorthandEditor.SelectionStart=2
 local shorthandLayouts,shorthandRequests,shorthandObjects,shorthandMeasures,shorthandCache=shorthand.Layouts,shorthand.Requests,#objects,measurements,shorthand.Outside.CachedLayout
 near(shorthandGui.Size[1],116,'Shorthand padding publishes actual retained width');near(shorthandBox.Style.Gap[2],6,'Shorthand gap publishes its second axis')
 shorthand:Run('spacing.currentTime=50;shorthandTarget.getBoundingClientRect();shorthandTarget.getBoundingClientRect();')
 assert(shorthand.Layouts==shorthandLayouts and shorthand.Requests==shorthandRequests and #objects==shorthandObjects and measurements==shorthandMeasures,'An unchanged shorthand sample arranges, requests, allocates and measures nothing')
 assert(shorthand.Outside.CachedLayout==shorthandCache,'Shorthand samples preserve unrelated layout cache')
 shorthand:Run('spacing.cancel();shorthandTarget.getBoundingClientRect();')
 near(shorthandGui.Size[1],108,'Shorthand cancellation restores actual author padding')
 assert(shorthandBox.Gui==shorthandGui and shorthandControl.Editor==shorthandEditor and shorthandEditor.Text=='selection'and shorthandEditor.CursorPosition==4 and shorthandEditor.SelectionStart==2,'Shorthand cancellation retains box/input and live editor state')
 assert(not shorthandBox.AnimationAuthorFields and shorthand.Runtime.EventLoop.FrameCount==0,'Last shorthand cancellation clears snapshots and idle frame work')
 shorthand:Destroy()
 local replacement=fixture('#box{opacity:.1;color:black;width:100px;height:40px}#replacementField{width:20px;height:10px;padding:0;border:0}')
 replacement:Run("const replaceTarget=document.getElementById('box');const field=document.createElement('input');field.id='replacementField';replaceTarget.appendChild(field);const removed=replaceTarget.animate([{opacity:.1,color:'red',translate:'10px',width:'120px'},{opacity:.2,color:'red',translate:'20px',width:'140px'}],{duration:100,fill:'both'});const covering=replaceTarget.animate([{opacity:.4,color:'blue',translate:'30px',width:'160px'},{opacity:.6,color:'blue',translate:'40px',width:'180px'}],{duration:100,fill:'both'});for(const a of[removed,covering]){a.finished.catch(()=>{});a.ready.catch(()=>{});a.finish();}")
 assert(#replacement.Diagnostics==0,'Replacement setup samples both finished controllers')
 local replacementBox=replacement.Tree.NodeBoxes[replacement.Node];local replacementControl
 for _,entry in replacement.Tree.Controls do if entry.Node.Attributes.id=='replacementField'then replacementControl=entry.Item end end
 assert(replacementControl,'Replacement test retains its real native editor')
 local replacementGui,replacementEditor=replacementBox.Gui,replacementControl.Editor
 replacementEditor.Text='live replacement';replacementEditor.CursorPosition=5;replacementEditor.SelectionStart=2
 local replacementLayouts,replacementRequests,replacementObjects,replacementMeasures,replacementCache=replacement.Layouts,replacement.Requests,#objects,measurements,replacement.Outside.CachedLayout
 assert(replacement.Runtime.EventLoop.FrameCount==1,'A fully covered finished effect requests one existing scheduler opportunity')
 replacement.Runtime:PumpFrame();replacement.Runtime:PumpTasks();replacement.Page:FlushScriptLayout();replacement.Runtime:AfterLayout()
 replacement:Run("console.log(removed.replaceState);console.log(String(replaceTarget.getAnimations().length));console.log(getComputedStyle(replaceTarget).width);console.log(getComputedStyle(replaceTarget).translate);")
 assert(table.concat(replacement.Values,'|')=='removed|1|180px|40px','Automatic replacement releases the lower effect while preserving the final native values')
 assert(replacement.Layouts==replacementLayouts and replacement.Requests==replacementRequests and #objects==replacementObjects and measurements==replacementMeasures,'Removing an already covered effect performs no arrangement, layout request, allocation or text measurement')
 assert(replacementBox.Gui==replacementGui and replacementControl.Editor==replacementEditor and replacementEditor.Text=='live replacement'and replacementEditor.CursorPosition==5 and replacementEditor.SelectionStart==2 and replacement.Outside.CachedLayout==replacementCache,'Replacement retains the rendered editor, selection and unrelated cache')
 replacement:AssertIdle('Covered finished animation')
 replacement:Run("covering.cancel();replaceTarget.getBoundingClientRect();")
 assert(not replacementBox.AnimationAuthorFields and not replacementBox.AnimationColorAuthor and not replacementBox.HasScriptColorEffects and not replacementBox.HasScriptTransformEffects,'Removed and canceled effects retain no numeric/color/transform author snapshots')
 replacement:Run("removed.persist();replaceTarget.getBoundingClientRect();console.log(getComputedStyle(replaceTarget).width);console.log(getComputedStyle(replaceTarget).translate);removed.cancel();replaceTarget.getBoundingClientRect();")
 assert(replacement.Values[5]=='140px'and replacement.Values[6]=='20px','Persist repaints the same removed controller using its preserved finished sample')
 assert(replacementBox.Gui==replacementGui and replacementControl.Editor==replacementEditor and not replacementBox.AnimationAuthorFields and not replacementBox.AnimationColorAuthor,'Persist/cancel retain native identity and release recreated snapshots')
 -- Repeated finishing must not consume the strong active-effect budget. Each
 -- frame prunes only fully replaced effects, leaving the latest controller.
 replacement:Run("let last;function churn(){const a=replaceTarget.animate([{opacity:.2},{opacity:.4}],{duration:100,fill:'both'});a.finished.catch(()=>{});a.ready.catch(()=>{});a.finish();last=a;}churn();")
 for _=1,140 do replacement:Run('churn();');replacement.Runtime:PumpFrame();replacement.Runtime:PumpTasks();replacement.Page:FlushScriptLayout();replacement.Runtime:AfterLayout()end
 replacement:Run("console.log(String(replaceTarget.getAnimations().length));last.cancel();")
 assert(#replacement.Diagnostics==0 and replacement.Values[7]=='1','More than 128 successive finished replacements recycle the bounded strong registry')
 replacement:AssertIdle('Repeated finished replacements');replacement:Destroy()
 local projected=fixture('#box{width:200px;height:100px;transform-origin:0 0}')
 projected:Run("const projected=document.getElementById('box');const tilted=projected.animate({scale:['1 1','3 5']},{duration:100,fill:'both'});tilted.finished.catch(()=>{});tilted.ready.catch(()=>{});tilted.pause();tilted.currentTime=50;")
 local projectedBox=projected.Tree.NodeBoxes[projected.Node];local keptBox=projectedBox.Gui;local keptSurface=projectedBox.Scene3DSurface;local record=projectedBox.Scene3DHit
 assert(record and keptSurface and ProjectiveHit.has(keptSurface),'Nonuniform individual scale paints and registers the real projected surface')
 local function pick(x,y)
  local bounds=projectedBox.Scene3DHit.Bounds
  keptSurface.AbsolutePosition=Vector2.new(bounds.Left,bounds.Top);keptSurface.AbsoluteSize=Vector2.new(bounds.Width,bounds.Height)
  return ProjectiveHit.pick(keptSurface,Vector2.new(x,y),projected.Tree.HitNodes,projected.Tree.HitStyles)
 end
 local hit,gui,point=pick(300,150)
 assert(hit==projected.Node and gui==keptBox and math.abs(point.X-150)<.001 and math.abs(point.Y-50)<.001,'Projected hit testing inverts the same 2x/3x scale that is painted')
 assert(pick(410,150)==nil,'A point outside the painted individual transform cannot hit its source box')
 local image=images[#images];local writes=image.Writes
 projected:Run('tilted.currentTime=50;projected.getBoundingClientRect();')
 assert(projectedBox.Gui==keptBox and projectedBox.Scene3DSurface==keptSurface and images[#images]==image and image.Writes==writes,'Repeating a stable projected sample reuses its raster surface and pixels')
 projected:Run('tilted.cancel();')
 assert(projectedBox.Gui==keptBox and not projectedBox.Scene3DSurface and not ProjectiveHit.has(keptSurface)and keptSurface.ImageTransparency==1 and keptBox.BackgroundTransparency==0,'Cancellation restores the retained native box and detaches the projected hit surface')
 assert(projected.Layouts==0 and projected.Runtime.EventLoop.FrameCount==0,'Individual projection and cancellation are paint-only and leave no idle frame work');projected:Destroy()
 do
 local pivoted=fixture('#box{transform:rotate(90deg);transform-origin:0 0}#originField{width:20px;height:10px}',false,false,function(doc)Node.append(Node.findById(doc,'box'),Node.element('input',{id='originField',value='kept'}))end)
 local pivotBox=pivoted.Tree.NodeBoxes[pivoted.Node];local pivotGui=pivotBox.Gui;local pivotInput
 for _,entry in pivoted.Tree.Controls do if entry.Node.Attributes.id=='originField'then pivotInput=entry.Item.Gui end end
 assert(pivotInput,'Origin paint contains a real retained native input')
 pivotInput.Text='live pivot';pivotInput.CursorPosition=4;pivotInput.SelectionStart=2
 local pivotCache=pivoted.Outside.CachedLayout;local pivotObjects=#objects;local pivotMeasures=measurements
 pivoted:Run("const pivot=document.getElementById('box');const pivotEffect=pivot.animate({transformOrigin:['0 0','100% 100%']},{duration:100,fill:'both'});pivotEffect.finished.catch(()=>{});pivotEffect.ready.catch(()=>{});pivotEffect.pause();pivotEffect.currentTime=25;")
 near(pivotGui.Position[1],-25,'Quarter origin paints the retained native horizontal position');near(pivotGui.Position[2],50,'Quarter origin paints the retained native vertical position')
 near(pivotGui.AnchorPoint.X,.25,'Quarter origin native horizontal anchor');near(pivotGui.AnchorPoint.Y,.25,'Quarter origin native vertical anchor');near(pivotGui.Rotation,90,'Origin interpolation retains native rotation')
 pivoted:Run('pivotEffect.currentTime=50;pivot.getBoundingClientRect();')
 near(pivotGui.Position[1],100,'Midpoint origin paints the native horizontal position');near(pivotGui.Position[2],50,'Midpoint origin paints the native vertical position');near(pivotGui.AnchorPoint.X,.5,'Midpoint origin native horizontal anchor')
 local stablePivotObjects=#objects
 pivoted:Run('pivotEffect.currentTime=50;pivot.getBoundingClientRect();pivot.getBoundingClientRect();pivotEffect.commitStyles();pivotEffect.cancel();')
 assert(pivotBox.Gui==pivotGui and not pivotGui.Destroyed and not pivotInput.Destroyed and pivotInput.Text=='live pivot'and pivotInput.CursorPosition==4 and pivotInput.SelectionStart==2,'Origin samples/commit/cancel preserve actual native GUI/input and selection')
 assert(#objects==stablePivotObjects and #objects==pivotObjects and measurements==pivotMeasures and pivoted.Layouts==0 and pivoted.Requests==0 and pivoted.Outside.CachedLayout==pivotCache,'Origin paint, author commit and cancellation allocate, measure and arrange nothing')
 near(pivotGui.Position[1],100,'Committed origin remains painted after cancellation');assert(not pivotBox.AnimationAuthorFields,'Origin cancellation releases its isolated author snapshot');pivoted:AssertIdle('Retained origin paint');pivoted:Destroy()
 local originScene=fixture('#box{transform:perspective(500px) rotateY(60deg);transform-origin:0 0}#sceneField{width:20px;height:10px}',false,false,function(doc)Node.append(Node.findById(doc,'box'),Node.element('input',{id='sceneField',value='kept'}))end)
 local originSceneBox=originScene.Tree.NodeBoxes[originScene.Node];local sceneGui,originSurface=originSceneBox.Gui,originSceneBox.Scene3DSurface;local sceneInput
 for _,entry in originScene.Tree.Controls do if entry.Node.Attributes.id=='sceneField'then sceneInput=entry.Item.Gui end end
 assert(originSurface and sceneInput and ProjectiveHit.has(originSurface),'Perspective origin starts with a registered retained paint/hit surface')
 sceneInput.Text='live scene';sceneInput.CursorPosition=4;sceneInput.SelectionStart=2
 local originSceneCache=originScene.Outside.CachedLayout
 originScene:Run("const originScene=document.getElementById('box');const originSceneEffect=originScene.animate({transformOrigin:['0 0 0','100% 100% 60px']},{duration:100,fill:'both'});originSceneEffect.finished.catch(()=>{});originSceneEffect.ready.catch(()=>{});originSceneEffect.pause();originSceneEffect.currentTime=50;")
 local sceneRecord=originSceneBox.Scene3DHit;local m=sceneRecord.Scene.Matrix;local denominator=m[4]*100+m[8]*50+m[16]
 local screen=Vector2.new((m[1]*100+m[5]*50+m[13])/denominator,(m[2]*100+m[6]*50+m[14])/denominator)
 originSurface.AbsolutePosition=Vector2.new(sceneRecord.Bounds.Left,sceneRecord.Bounds.Top);originSurface.AbsoluteSize=Vector2.new(sceneRecord.Bounds.Width,sceneRecord.Bounds.Height)
 local originHit,originHitGui,originPoint=ProjectiveHit.pick(originSurface,screen,originScene.Tree.HitNodes,originScene.Tree.HitStyles)
 assert(originHit==originScene.Node and originHitGui==sceneGui,'Perspective origin hit testing selects the painted retained box');near(originPoint.X,100,'Perspective origin inverse hit horizontal coordinate');near(originPoint.Y,50,'Perspective origin inverse hit vertical coordinate')
 local originImage=images[#images];local originWrites=originImage.Writes;local originObjects=#objects
 originScene:Run('originSceneEffect.currentTime=50;originScene.getBoundingClientRect();')
 assert(originSceneBox.Scene3DSurface==originSurface and images[#images]==originImage and originImage.Writes==originWrites and #objects==originObjects,'An unchanged perspective origin reuses the GUI, texture and raster pixels')
 originScene:Run('originSceneEffect.cancel();')
 assert(originSceneBox.Gui==sceneGui and originSceneBox.Scene3DSurface==originSurface and ProjectiveHit.has(originSurface)and not sceneInput.Destroyed and sceneInput.Text=='live scene'and sceneInput.CursorPosition==4 and sceneInput.SelectionStart==2,'Origin cancellation restores the author perspective through the same surface/input')
 assert(originScene.Layouts==0 and originScene.Requests==0 and originScene.Outside.CachedLayout==originSceneCache and not originSceneBox.AnimationAuthorFields,'Perspective origin repaint preserves flow cache and releases the sampled author base');originScene:AssertIdle('Perspective origin');originScene:Run('originSceneEffect.pause();originSceneEffect.ready.catch(()=>{});originSceneEffect.finished.catch(()=>{});originSceneEffect.currentTime=25;');assert(originSceneBox.AnimationAuthorFields,'Replaying an origin effect retains only its current author snapshot');originScene:AssertIdle('Replayed perspective origin');originScene:Destroy();assert(not originSceneBox.AnimationAuthorFields and not ProjectiveHit.has(originSurface),'Disposal of a live origin effect releases its author snapshot and projective hit registry')
 local originFixed=fixture('#parent{margin:40px 30px}#box{margin-left:50px}#originFixed{position:fixed;left:10px;top:15px;width:20px;height:10px}',false,true,function(doc)Node.append(Node.findById(doc,'box'),Node.element('div',{id='originFixed'}))end)
 local originFixedBox
 for node,box in originFixed.Tree.NodeBoxes do if node.Attributes and node.Attributes.id=='originFixed'then originFixedBox=box end end
 local fixedOriginGui=assert(originFixedBox).Gui;local originOverlay=originFixed.Tree.ViewportLayer
 originFixed:Run("const originParent=document.getElementById('box');const originFixed=document.getElementById('originFixed');const onlyOrigin=originParent.animate({transformOrigin:['0 0','100% 100%']},{duration:100,fill:'both'});onlyOrigin.finished.catch(()=>{});onlyOrigin.ready.catch(()=>{});onlyOrigin.pause();for(const time of[0,25,50,100]){onlyOrigin.currentTime=time;console.log(String(originFixed.getBoundingClientRect().x));console.log(String(originFixed.getBoundingClientRect().y));}onlyOrigin.commitStyles();onlyOrigin.cancel();")
 assert(table.concat(originFixed.Values,'|')=='10|15|10|15|10|15|10|15','An origin animation without transform keeps native fixed descendants in viewport coordinates')
 assert(originFixedBox.Gui==fixedOriginGui and fixedOriginGui.Parent==originOverlay and not originFixedBox.FixedContainingBox and originFixed.Layouts==0 and originFixed.Requests==0,'An origin channel alone neither creates a containing block nor reparents/arranges the retained fixed GUI');originFixed:AssertIdle('Origin without transform');originFixed:Destroy()
 end
 local contained=fixture('#parent{margin:40px 30px}#box{margin-left:50px}#fixed{position:fixed;left:10px;top:15px;width:20px;height:10px}#absolute{position:absolute;left:10px;top:15px;width:20px;height:10px}',false,true)
 contained:Run("const container=document.getElementById('box');const fixed=document.createElement('div');fixed.id='fixed';container.appendChild(fixed);const absolute=document.createElement('div');absolute.id='absolute';container.appendChild(absolute);const input=document.createElement('input');input.id='liveField';input.setAttribute('value','kept');input.style.cssText='width:10px;height:5px';fixed.appendChild(input);")
 -- Runtime document ownership is deliberately obtained from actual rendered
 -- boxes, so wrapper identity cannot hide a replaced native input or overlay.
 local fixedBox,absoluteBox,control
 for node,box in contained.Tree.NodeBoxes do local id=node.Attributes and node.Attributes.id;if id=='fixed'then fixedBox=box elseif id=='absolute'then absoluteBox=box end end
 for _,entry in contained.Tree.Controls do if entry.Node.Attributes.id=='liveField'then control=entry end end
 assert(fixedBox and absoluteBox and control,'The positioned children and live native input mount: '..table.concat(contained.Diagnostics,' / ')..' '..tostring(fixedBox)..' '..tostring(absoluteBox)..' '..tostring(control))
 local fixedGui,absoluteGui,inputGui=fixedBox.Gui,absoluteBox.Gui,control.Item.Gui
 local overlay=contained.Tree.ViewportLayer;assert(overlay and fixedGui.Parent==overlay and not fixedBox.FixedContainingBox,'Initial fixed child belongs to the viewport overlay')
 inputGui.Text='live';inputGui.CursorPosition=3;inputGui.SelectionStart=1
 local outsideCache=contained.Outside.CachedLayout
 local beforeLayouts,beforeRequests=contained.Layouts,contained.Requests
 contained:Run("const containAnimation=container.animate({translate:['none','40px']},{duration:100,fill:'both'});containAnimation.finished.catch(()=>{});containAnimation.ready.catch(()=>{});containAnimation.pause();containAnimation.currentTime=0;console.log(String(fixed.getBoundingClientRect().x));console.log(String(absolute.getBoundingClientRect().x));")
 assert(#contained.Diagnostics==0 and contained.Values[1]=='90'and contained.Values[2]=='90','Same-script geometry flush sees the animation-created padding containing block')
 assert(contained.Layouts==beforeLayouts+1 and contained.Requests==beforeRequests+1,'Entering a transform effect requests exactly one local positioning layout')
 assert(fixedBox.FixedContainingBox==contained.Tree.NodeBoxes[contained.Node]and fixedGui.Parent~=overlay,'The retained fixed surface returns from its viewport overlay into the animated hierarchy')
 local enteredLayouts,enteredRequests=contained.Layouts,contained.Requests
 for _,time in {25,50,75,100}do contained:Run('containAnimation.currentTime='..time..';fixed.getBoundingClientRect();absolute.getBoundingClientRect();')end
 assert(contained.Layouts==enteredLayouts and contained.Requests==enteredRequests,'Ordinary transform samples and forwards fill retain positioning layout')
 contained:Run('containAnimation.cancel();console.log(String(fixed.getBoundingClientRect().x));console.log(String(absolute.getBoundingClientRect().x));')
 assert(contained.Values[3]=='10'and contained.Values[4]=='10'and contained.Layouts==enteredLayouts+1 and contained.Requests==enteredRequests+1,'Cancel releases implicit will-change and flushes the original containing block once')
 assert(fixedGui.Parent==overlay and not fixedBox.FixedContainingBox and contained.Tree.ViewportLayer==overlay,'Cancellation reuses the same viewport overlay and fixed surface')
 assert(fixedBox.Gui==fixedGui and absoluteBox.Gui==absoluteGui and control.Item.Gui==inputGui and inputGui.Text=='live'and inputGui.CursorPosition==3 and inputGui.SelectionStart==1,'Containing-block changes preserve retained native controls and selection')
 assert(contained.Outside.CachedLayout==outsideCache and contained.Runtime.EventLoop.FrameCount==0,'Positioning boundaries keep unrelated flow caches and leave no idle animation frame')
 contained:Destroy()
 local decorated=fixture('#box{border-style:solid;border-width:2px 4px 6px 8px;outline:3px solid blue;outline-offset:2px}')
 decorated:Run("const decorated=document.getElementById('box');const decorField=document.createElement('input');decorField.id='decorField';decorField.style.cssText='width:20px;height:10px';decorated.appendChild(decorField);const borderEffect=decorated.animate({borderTopWidth:['2px','10px'],borderRightWidth:['4px','12px'],borderBottomWidth:['6px','14px'],borderLeftWidth:['8px','16px']},{duration:100,fill:'both'});borderEffect.finished.catch(()=>{});borderEffect.ready.catch(()=>{});borderEffect.pause();borderEffect.currentTime=0;")
 local decorBox=decorated.Tree.NodeBoxes[decorated.Node];local decorGui=decorBox.Gui;local edges=decorBox.InsetEdges;local decorControl
 for _,entry in decorated.Tree.Controls do if entry.Node.Attributes.id=='decorField'then decorControl=entry end end
 assert(edges and decorControl,'Animated nonuniform borders and their native child are rendered')
 local decorInput=decorControl.Item.Gui;decorInput.Text='selection';decorInput.CursorPosition=4;decorInput.SelectionStart=1
 local decorCache=decorated.Outside.CachedLayout
 decorated:Run('borderEffect.currentTime=50;decorated.getBoundingClientRect();')
 assert(decorBox.InsetEdges==edges and decorBox.Gui==decorGui,'Different side widths repaint the retained border strips and box')
 -- The native strip spans the space between the left/right corner atlas;
 -- those atlas joins own the remaining 12px and 8px of this 220px box.
 near(decorBox.Gui.Size[1],220,'Actual animated border box width');near(edges[1].Position[1],12,'Actual animated top border left join');near(edges[1].Size[1],200,'Actual animated top border straight segment');near(edges[1].Size[2],6,'Actual animated top border thickness')
 near(edges[2].Size[1],12,'Actual animated left border thickness');near(edges[3].Size[2],10,'Actual animated bottom border thickness');near(edges[4].Size[1],8,'Actual animated right border thickness')
 local stableObjects=#objects;local stableLayouts=decorated.Layouts
 decorated:Run('borderEffect.currentTime=50;decorated.getBoundingClientRect();')
 assert(#objects==stableObjects and decorated.Layouts==stableLayouts,'A stable border sample creates no GUI or additional layout')
 decorated:Run('borderEffect.cancel();')
 assert(decorBox.InsetEdges==edges and decorBox.Gui==decorGui and decorControl.Item.Gui==decorInput and decorInput.Text=='selection'and decorInput.CursorPosition==4 and decorInput.SelectionStart==1,'Border restore retains controls and live selection')
 near(edges[1].Size[2],2,'Cancelled top border paint');near(edges[2].Size[1],8,'Cancelled left border paint')
 assert(decorated.Outside.CachedLayout==decorCache and not decorBox.AnimationAuthorFields,'Border animation preserves unrelated layout caches and releases sampled author fields');decorated:Destroy()
 local outlined=fixture('#box{outline:3px solid blue;outline-offset:2px;opacity:.5}')
 local outlineBox=outlined.Tree.NodeBoxes[outlined.Node];local outlineGui=outlineBox.Outline.Gui;local group=outlineBox.OpacityGroup
 outlined:Run("const outlined=document.getElementById('box');const outlineEffect=outlined.animate({outlineWidth:['2px','10px'],outlineOffset:['-4px','8px']},{duration:100,fill:'both'});outlineEffect.finished.catch(()=>{});outlineEffect.ready.catch(()=>{});outlineEffect.pause();outlineEffect.currentTime=50;")
 assert(outlineBox.Outline.Gui==outlineGui and outlineBox.OpacityGroup==group and outlined.Layouts==0,'Outline width and offset repaint retained compositing bounds without flow layout')
 near(outlineGui.Size[1],216,'Actual outline surface width');near(outlineGui.Size[2],116,'Actual outline surface height');near(outlineGui.Position[1],-8,'Actual outline outset')
 stableObjects=#objects;outlined:Run('outlineEffect.currentTime=50;outlined.getBoundingClientRect();')
 assert(#objects==stableObjects and outlined.Layouts==0,'Repeating outline paint does not create surfaces or layout')
 outlined:Run('outlineEffect.cancel();')
 assert(outlineBox.Outline.Gui==outlineGui and outlineBox.OpacityGroup==group and outlined.Layouts==0,'Cancelling outline effects retains the surface and opacity group')
 near(outlineGui.Size[1],210,'Cancelled outline surface width');near(outlineGui.Position[1],-5,'Cancelled outline outset');outlined:Destroy()
 local outlinedControl=fixture('#box{width:200px;height:100px}')
 outlinedControl:Run("const host=document.getElementById('box');const outlineInput=document.createElement('input');outlineInput.id='outlineInput';outlineInput.style.cssText='display:block;width:100px;height:20px;outline:3px solid blue;outline-offset:2px';host.appendChild(outlineInput);const controlOutline=outlineInput.animate({outlineWidth:['2px','10px'],outlineOffset:['-4px','8px']},{duration:100,fill:'both'});controlOutline.finished.catch(()=>{});controlOutline.ready.catch(()=>{});controlOutline.pause();controlOutline.currentTime=0;")
 local outlinedItem
 for _,entry in outlinedControl.Tree.Controls do if entry.Node.Attributes.id=='outlineInput'then outlinedItem=entry.Item end end
 assert(outlinedItem and outlinedItem.ControlOutline,'Native input has a painted outline')
 local nativeInput=outlinedItem.Gui;local nativeOutline=outlinedItem.ControlOutline.Gui;nativeInput.Text='native';nativeInput.CursorPosition=4;nativeInput.SelectionStart=2
 local outlineLayouts=outlinedControl.Layouts
 outlinedControl:Run('controlOutline.currentTime=50;outlineInput.getBoundingClientRect();')
 assert(outlinedItem.Gui==nativeInput and outlinedItem.ControlOutline.Gui==nativeOutline and not nativeOutline.Destroyed and outlinedControl.Layouts==outlineLayouts,'A native input animates its outline without replacing the control, outline or flow layout')
 near(outlinedItem.ControlOutline.Style.BorderSize,6,'Animated native outline width');near(outlinedItem.ControlOutline.Offset,2,'Animated native outline offset')
 outlinedControl:Run('controlOutline.cancel();')
 assert(outlinedItem.ControlOutline.Gui==nativeOutline and nativeInput.Text=='native'and nativeInput.CursorPosition==4 and nativeInput.SelectionStart==2,'Native outline cancellation preserves surface and live selection');outlinedControl:Destroy()
 local rounded=fixture('#box{border-radius:4px}')
 rounded:Run("const rounded=document.getElementById('box');const cornerEffect=rounded.animate({borderTopLeftRadius:['2px','10px']},{duration:100,fill:'both'});cornerEffect.finished.catch(()=>{});cornerEffect.ready.catch(()=>{});cornerEffect.pause();cornerEffect.currentTime=50;")
 local roundBox=rounded.Tree.NodeBoxes[rounded.Node];local roundGui=roundBox.Gui;local roundCorner=roundBox.Corner
 assert(roundCorner and roundBox.NativeCornerRadii,'Independent circular corner animation uses the retained native corner')
 near(roundCorner.TopLeftRadius.Offset,6,'Actual individual native top-left radius');near(roundCorner.TopRightRadius.Offset,4,'Actual unaffected native top-right radius')
 local roundImages=#images;stableObjects=#objects;rounded:Run('cornerEffect.currentTime=50;')
 assert(#images==roundImages and #objects==stableObjects and rounded.Layouts==0,'A stable circular corner sample creates no texture, GUI or layout')
 rounded:Run('cornerEffect.cancel();');near(roundCorner.TopLeftRadius.Offset,4,'Cancelled native top-left radius')
 rounded:Run("const ellipseEffect=rounded.animate({borderTopLeftRadius:['calc(10% + 2px) 20%','calc(30% + 10px) 40%']},{duration:100,fill:'both'});ellipseEffect.finished.catch(()=>{});ellipseEffect.ready.catch(()=>{});ellipseEffect.pause();ellipseEffect.currentTime=50;")
 local ellipseSurface
 for _,object in objects do if object.Parent==roundGui and object.Name=='RoundedSurface'then ellipseSurface=object end end
 assert(ellipseSurface and ellipseSurface.Visible and roundGui.BackgroundTransparency==1,'An elliptic corner animation paints its retained rounded raster')
 local ellipseImage=ellipseSurface.ImageContent;local ellipseWrites=ellipseImage.Writes
 near(roundBox.ResolvedBorderRadii[1][1],46,'Resolved responsive horizontal radius');near(roundBox.ResolvedBorderRadii[1][2],30,'Resolved responsive vertical radius')
 assert(buffer.readu8(ellipseImage.Pixels,3)==0 and buffer.readu8(ellipseImage.Pixels,(50*ellipseImage.Size.X+100)*4+3)==255,'Animated ellipse raster clears the outer corner and keeps the center opaque')
 stableObjects=#objects;rounded:Run('ellipseEffect.currentTime=50;')
 assert(ellipseSurface.ImageContent==ellipseImage and ellipseImage.Writes==ellipseWrites and #objects==stableObjects,'An unchanged elliptic sample reuses its native image, pixels and GUI')
 rounded:Run('ellipseEffect.currentTime=75;')
 assert(ellipseSurface.ImageContent==ellipseImage and not ellipseImage.Destroyed and ellipseImage.Writes==ellipseWrites+1 and #objects==stableObjects,'Changed elliptical radii reuse the same-sized EditableImage and retained surfaces')
 rounded:Run('ellipseEffect.cancel();')
 assert(roundBox.Gui==roundGui and roundBox.Corner==roundCorner and not ellipseSurface.Visible and roundGui.BackgroundTransparency==0 and not roundBox.ResolvedBorderRadii,'Cancellation hides the raster and restores the retained native circular surface')
 assert(rounded.Layouts==0 and rounded.Runtime.EventLoop.FrameCount==0,'Corner animation/cancellation remain paint-only and leave no idle frame');rounded:Destroy()
 local metric=fixture('#box{font-size:20px;line-height:1.2;height:auto}')
 metric:Run("const metrics=document.getElementById('box');const line=document.createElement('div');line.id='metricLine';line.style.cssText='width:3em;height:auto';line.textContent='MM';metrics.appendChild(line);const field=document.createElement('input');field.id='metricField';field.style.cssText='display:block;font-size:inherit;width:2em;height:1em;padding:0;border:0';metrics.appendChild(field);")
 local lineBox,metricField
 for node,box in metric.Tree.NodeBoxes do if node.Attributes and node.Attributes.id=='metricLine'then lineBox=box end end
 for _,entry in metric.Tree.Controls do if entry.Node.Attributes.id=='metricField'then metricField=entry.Item end end
 local text
 for _,run in lineBox.Children do for _,item in run.Items or{}do if item.Text=='MM'then text=item end end end
 assert(lineBox and metricField and text and text.Gui,'Inherited metric fixture retains a real text run and input')
 local lineGui,textGui,fieldGui=lineBox.Gui,text.Gui,metricField.Editor;local fieldOuter=metricField.Gui;local outsideCache=metric.Outside.CachedLayout
 local baseTextSize,baseFieldSize=textGui.TextSize,fieldGui.TextSize
 fieldGui.Text='live';fieldGui.CursorPosition=3;fieldGui.SelectionStart=1
 metric:Run("const fontEffect=metrics.animate({fontSize:['20px','40px'],lineHeight:['1','2']},{duration:100,fill:'both'});fontEffect.finished.catch(()=>{});fontEffect.ready.catch(()=>{});fontEffect.pause();fontEffect.currentTime=50;metrics.getBoundingClientRect();")
 near(lineBox.OuterWidth,90,'Inherited em width uses actual sampled font');near(lineBox.OuterHeight,45,'Actual line box uses sampled unitless line-height')
 assert(text.MeasuredSize>baseTextSize,'Retained word is remeasured at the sampled font');near(text.Width,text.MeasuredSize,'Actual measured glyph width follows sampled host font');near(textGui.TextSize,text.MeasuredSize,'Retained native text paints the same sampled size used by measurement')
 near(metricField.Style.FontSize,30,'Native input inherits sampled font');near(metricField.BoxWidth,60,'Native input resolves em width');assert(fieldGui.TextSize>baseFieldSize,'Native input paints sampled font')
 assert(lineBox.Gui==lineGui and text.Gui==textGui and metricField.Gui==fieldOuter and metricField.Editor==fieldGui and fieldGui.Text=='live'and fieldGui.CursorPosition==3 and fieldGui.SelectionStart==1,'Font metric refresh preserves boxes, words, native input and selection')
 assert(metric.Outside.CachedLayout==outsideCache,'Inherited metric refresh preserves unrelated cached layout')
 local measured,allocated,layouts=measurements,#objects,metric.Layouts
 metric:Run('fontEffect.currentTime=50;metrics.getBoundingClientRect();')
 assert(measurements==measured and #objects==allocated and metric.Layouts==layouts,'Repeated inherited font sample causes no measurement, GUI allocation or layout')
 metric:Run('fontEffect.cancel();metrics.getBoundingClientRect();')
 near(lineBox.OuterWidth,60,'Cancel restores relative width');near(lineBox.OuterHeight,24,'Cancel restores inherited line box');near(textGui.TextSize,baseTextSize,'Cancel restores retained native text font');near(fieldGui.TextSize,baseFieldSize,'Cancel restores native input font')
 assert(text.Gui==textGui and metricField.Gui==fieldOuter and metricField.Editor==fieldGui and fieldGui.CursorPosition==3 and fieldGui.SelectionStart==1,'Cancellation preserves live text/control identity and state')
 metric:Destroy()
 local removedMetric=fixture('#box{font-size:20px;line-height:1.2;height:auto}')
 removedMetric:Run("const removedFontTarget=document.getElementById('box');const removedFont=removedFontTarget.animate({fontSize:['20px','40px']},{duration:100,fill:'both'});removedFont.finished.catch(()=>{});removedFont.ready.catch(()=>{});removedFont.pause();removedFont.currentTime=50;")
 local removedFontBox=removedMetric.Tree.NodeBoxes[removedMetric.Node];local retiredGui=removedFontBox.Gui
 removedMetric:Run('removedFontTarget.remove();')
 assert(not removedMetric.Tree.NodeBoxes[removedMetric.Node]and retiredGui.Destroyed and not removedFontBox.AnimationMetricAuthor and not removedFontBox.AnimationMetricUnderlyingStyle,'Removing an active font target releases the retired box and author metric snapshot')
 assert(next(removedMetric.Tree.AnimationMetricOverrides)==nil and removedMetric.Runtime.EventLoop.FrameCount==0,'Detached paused font effects retain no metric override or frame subscription')
 removedMetric:Run("document.getElementById('parent').appendChild(removedFontTarget);console.log(getComputedStyle(removedFontTarget).fontSize);")
 local remountedFontBox=removedMetric.Tree.NodeBoxes[removedMetric.Node]
 assert(remountedFontBox and remountedFontBox.Gui~=retiredGui and removedMetric.Values[1]=='30px','Reattaching the same DOM target mounts a fresh box and republishes its held font sample')
 removedMetric:Run('removedFont.cancel();')
 assert(not remountedFontBox.AnimationMetricAuthor and next(removedMetric.Tree.AnimationMetricOverrides)==nil and remountedFontBox.Style.FontSize==20,'Cancellation releases reattached metric overlays and restores author font')
 removedMetric:Destroy()
 local colors=fixture('#box{color:rgb(40,60,80);border:2px solid currentColor;outline:2px solid currentColor;text-decoration:underline}#colorLine span{background:currentColor}#colorField{color:inherit}')
 colors:Run("const colorBox=document.getElementById('box');const colorLine=document.createElement('div');colorLine.id='colorLine';colorLine.innerHTML='<span id=\"colorInline\">Color</span>';colorBox.appendChild(colorLine);const colorField=document.createElement('input');colorField.id='colorField';colorField.style.cssText='width:40px;height:10px';colorBox.appendChild(colorField);")
 local colorBox=colors.Tree.NodeBoxes[colors.Node];local colorText,colorField,colorRun
 for node,box in colors.Tree.NodeBoxes do if node.Attributes and node.Attributes.id=='colorLine'then for _,run in box.Children do for _,item in run.Items or{}do if item.Text=='Color'then colorText,colorRun=item,run end end end end end
 for _,entry in colors.Tree.Controls do if entry.Node.Attributes.id=='colorField'then colorField=entry.Item end end
 assert(colorText and colorField and colorText.DecorationFrames and colorText.DecorationFrames[1],'The real inherited text, decoration and input consumers are mounted')
 local colorGui,textGui,fieldGui,decorationGui,outlineGui=colorBox.Gui,colorText.Gui,colorField.Editor,colorText.DecorationFrames[1],colorBox.Outline.Gui
 local backgroundSlot
 for _,slot in colorRun.FragmentPool or{}do if slot.OwnerStyle==colorText.Style.InlineFragment.Style then backgroundSlot=slot;break end end
 assert(backgroundSlot and backgroundSlot.Active,'The inline currentColor background has its retained fragment owner')
 local backgroundGui=backgroundSlot.Gui
 near(backgroundGui.BackgroundColor3.R*255,40,'Author currentColor initializes the actual inline background owner')
 near(backgroundGui.BackgroundTransparency,0,'The actual inline fragment paints its background once')
 near(textGui.BackgroundTransparency or 1,1,'The foreground word does not duplicate its fragment background')
 local outlineStroke,borderStroke
 for _,gui in objects do if gui.ClassName=='UIStroke'then if gui.Parent==outlineGui then outlineStroke=gui elseif gui.Parent==colorGui then borderStroke=gui end end end
 assert(outlineStroke and borderStroke,'Real retained outline and border strokes exist')
 fieldGui.Text='live';fieldGui.CursorPosition=3;fieldGui.SelectionStart=1
 local count,measurementsBefore,layoutsBefore,requestsBefore,cache=#objects,measurements,colors.Layouts,colors.Requests,colors.Outside.CachedLayout
 colors:Run("const colorEffect=colorBox.animate({color:['rgb(0,20,40)','rgb(100,120,140)']},{duration:100,fill:'both'});colorEffect.finished.catch(()=>{});colorEffect.ready.catch(()=>{});colorEffect.pause();colorEffect.currentTime=50;")
 local consumers={Foreground=textGui.TextColor3,InlineBackground=backgroundGui.BackgroundColor3,Field=fieldGui.TextColor3,Border=borderStroke.Color,Outline=outlineStroke.Color,Decoration=decorationGui.BackgroundColor3}
 local consumerCount=0
 for _,name in {'Foreground','InlineBackground','Field','Border','Outline','Decoration'}do local value=consumers[name];assert(value,'The retained '..name..' color consumer exists');consumerCount+=1;near(value.R*255,50,'Retained '..name..' currentColor consumer red');near(value.G*255,70,'Retained '..name..' currentColor consumer green');near(value.B*255,90,'Retained '..name..' currentColor consumer blue')end
 assert(consumerCount==6 and backgroundSlot.Gui==backgroundGui and backgroundSlot.Active,'All six currentColor consumers include the same actual background owner')
 near(backgroundGui.BackgroundTransparency,0,'Color interpolation retains one fragment background layer');near(textGui.BackgroundTransparency or 1,1,'Color interpolation never duplicates the word background')
 assert(colorBox.Gui==colorGui and colorText.Gui==textGui and colorField.Editor==fieldGui and colorText.DecorationFrames[1]==decorationGui and colorBox.Outline.Gui==outlineGui,'A foreground sample retains the actual word/input/decoration/outline surfaces')
 assert(fieldGui.Text=='live'and fieldGui.CursorPosition==3 and fieldGui.SelectionStart==1,'Color painting preserves live input selection')
 colors:Run('colorEffect.currentTime=50;getComputedStyle(colorBox).color;')
 assert(#objects==count and measurements==measurementsBefore and colors.Layouts==layoutsBefore and colors.Requests==requestsBefore and colors.Outside.CachedLayout==cache,'Repeated color samples allocate/measure/layout nothing and retain the unrelated cache')
 colors:Run('colorEffect.cancel();')
 near(textGui.TextColor3.R*255,40,'Foreground cancellation restores retained text');near(backgroundGui.BackgroundColor3.R*255,40,'Cancellation restores the retained inline background');near(outlineStroke.Color.R*255,40,'Cancellation restores currentColor outline')
 assert(backgroundSlot.Gui==backgroundGui and backgroundSlot.Active,'Cancellation retains the actual inline background surface');near(backgroundGui.BackgroundTransparency,0,'Canceled color keeps one fragment background layer');near(textGui.BackgroundTransparency or 1,1,'Canceled color never duplicates the word background')
 assert(not colorBox.AnimationColorAuthor and not colorBox.AnimationColorInherited and next(colors.Tree.AnimationColorOverrides)==nil,'Last color cancellation releases all target snapshots')
 assert(colors.Runtime.EventLoop.FrameCount==0 and colors.Layouts==layoutsBefore,'Paused color cancellation remains frame-free and paint-only');colors:Destroy()
 local combinedColor=fixture('#box{font-size:20px;line-height:1.2;width:3em;height:auto;color:rgb(40,60,80);border:2px solid currentColor;border-radius:10px;outline:2px solid currentColor;outline-offset:2px}#combinedLine{width:2em}#combinedField{font-size:inherit;color:inherit;width:2em;height:1em;padding:0;border:0}')
 combinedColor:Run("const combinedTarget=document.getElementById('box');const line=document.createElement('div');line.id='combinedLine';line.textContent='MM';combinedTarget.appendChild(line);const field=document.createElement('input');field.id='combinedField';combinedTarget.appendChild(field);const combinedShape=combinedTarget.animate({fontSize:['20px','40px'],borderWidth:['2px','10px'],borderRadius:['10px','30px'],outlineWidth:['2px','10px'],outlineOffset:['2px','6px']},{duration:100,fill:'both'});combinedShape.finished.catch(()=>{});combinedShape.ready.catch(()=>{});combinedShape.pause();combinedShape.currentTime=50;combinedTarget.getBoundingClientRect();")
 local combinedBox=combinedColor.Tree.NodeBoxes[combinedColor.Node];local combinedLine,combinedField,combinedText
 for node,box in combinedColor.Tree.NodeBoxes do if node.Attributes and node.Attributes.id=='combinedLine'then combinedLine=box end end
 for _,entry in combinedColor.Tree.Controls do if entry.Node.Attributes.id=='combinedField'then combinedField=entry.Item end end
 for _,run in combinedLine.Children do for _,item in run.Items or{}do if item.Text=='MM'then combinedText=item end end end
 assert(combinedLine and combinedField and combinedText,'Combined font/size/color fixture mounts its real inherited consumers')
 local combinedGui,combinedEditor,combinedWord,combinedOutline=combinedBox.Gui,combinedField.Editor,combinedText.Gui,combinedBox.Outline.Gui
 combinedEditor.Text='kept';combinedEditor.CursorPosition=3;combinedEditor.SelectionStart=1
 local combinedLayouts,combinedRequests,combinedMeasurements,combinedObjects=combinedColor.Layouts,combinedColor.Requests,measurements,#objects
 local combinedCache=combinedColor.Outside.CachedLayout;local combinedWordWidth=combinedText.Width
 near(combinedGui.Size[1],102,'Combined font and border use actual retained outer width');near(combinedLine.OuterWidth,60,'Combined descendants resolve the held font');near(combinedBox.Style.BorderSides[1].Width,6,'Combined border has its held sampled width')
 combinedColor:Run("const combinedTint=combinedTarget.animate({color:['rgb(0,20,40)','rgb(100,120,140)']},{duration:100,fill:'both'});combinedTint.finished.catch(()=>{});combinedTint.ready.catch(()=>{});combinedTint.pause();combinedTint.currentTime=75;combinedTarget.getBoundingClientRect();")
 near(combinedBox.Style.FontSize,30,'Color publication preserves held font');near(combinedBox.Style.BorderSides[1].Width,6,'Color publication preserves held physical border width');near(combinedBox.Style.BorderRadius,20,'Color publication preserves held radius');near(combinedBox.Style.OutlineWidth,6,'Color publication preserves held outline width');near(combinedGui.Size[1],102,'Color publication preserves actual sampled geometry');near(combinedText.Width,combinedWordWidth,'Color publication preserves measured glyph geometry');near(combinedWord.TextColor3.R*255,75,'Held font word consumes sampled foreground');near(combinedEditor.TextColor3.R*255,75,'Held font input consumes sampled foreground')
 assert(combinedColor.Layouts==combinedLayouts and combinedColor.Requests==combinedRequests and measurements==combinedMeasurements and #objects==combinedObjects,'A color effect beside held metric/border/radius effects allocates, measures and layouts nothing: '..combinedColor.Layouts..'/'..combinedLayouts..' layouts, '..combinedColor.Requests..'/'..combinedRequests..' requests, '..measurements..'/'..combinedMeasurements..' measurements, '..#objects..'/'..combinedObjects..' objects')
 combinedColor:Run('combinedTint.currentTime=50;combinedTint.cancel();combinedTarget.getBoundingClientRect();')
 near(combinedBox.Style.FontSize,30,'Color cancellation keeps held font');near(combinedBox.Style.BorderSides[1].Width,6,'Color cancellation keeps held border width');near(combinedWord.TextColor3.R*255,40,'Color cancellation restores author foreground')
 assert(combinedColor.Layouts==combinedLayouts and combinedColor.Requests==combinedRequests and measurements==combinedMeasurements and #objects==combinedObjects,'Color resampling and cancellation preserve all held geometric effects without extra work')
 combinedColor:Run('combinedShape.cancel();combinedTarget.getBoundingClientRect();')
 near(combinedGui.Size[1],64,'Last geometric cancellation restores actual author outer width');near(combinedLine.OuterWidth,40,'Last geometric cancellation restores inherited author font');near(combinedBox.Style.BorderSides[1].Width,2,'Last geometric cancellation restores author border')
 assert(combinedBox.Gui==combinedGui and combinedField.Editor==combinedEditor and combinedText.Gui==combinedWord and combinedBox.Outline.Gui==combinedOutline and combinedEditor.Text=='kept'and combinedEditor.CursorPosition==3 and combinedEditor.SelectionStart==1,'Combined cancellation retains native boxes, word, outline, input and selection')
 assert(combinedColor.Outside.CachedLayout==combinedCache and combinedColor.Runtime.EventLoop.FrameCount==0 and not combinedBox.AnimationColorAuthor and not combinedBox.AnimationMetricAuthor,'Combined effects preserve unrelated cache and release bases/frame work');combinedColor:Destroy()
 local removedColor=fixture('#box{color:rgb(40,60,80)}')
 removedColor:Run("const retiredColor=document.getElementById('box');const colorEffect=retiredColor.animate({color:['rgb(0,20,40)','rgb(100,120,140)']},{duration:100,fill:'both'});colorEffect.finished.catch(()=>{});colorEffect.ready.catch(()=>{});colorEffect.pause();colorEffect.currentTime=50;")
 local retiredColorBox=removedColor.Tree.NodeBoxes[removedColor.Node];local retiredColorGui=retiredColorBox.Gui
 removedColor:Run('retiredColor.remove();')
 assert(retiredColorGui.Destroyed and not retiredColorBox.AnimationColorAuthor and not retiredColorBox.AnimationColorInherited and next(removedColor.Tree.AnimationColorOverrides)==nil,'Removing a paused color target releases the retired author/parent snapshots and override')
 removedColor:Run('document.getElementById("parent").appendChild(retiredColor);')
 local revivedColorBox=removedColor.Tree.NodeBoxes[removedColor.Node]
 assert(revivedColorBox and revivedColorBox.Gui~=retiredColorGui,'A remounted DOM color target uses a live rendered surface')
 near(revivedColorBox.Style.Color.R*255,50,'Remount republishes the held color sample')
 removedColor:Run('colorEffect.cancel();');near(revivedColorBox.Style.Color.R*255,40,'Remounted cancellation restores its actual author color');removedColor:Destroy()
 local alphaColor=fixture('#box{border:2px solid rgba(20,40,60,.25)}')
 alphaColor:Run("const colorBox=document.getElementById('box');const a=colorBox.animate({borderColor:['rgba(60,80,100,.25)','rgba(100,120,140,.5)']},{duration:100,fill:'both',composite:'add'});a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();a.currentTime=50;console.log(getComputedStyle(colorBox).borderTopColor);")
 assert(alphaColor.Values[1]=='rgba(60, 80, 100, 0.625)','Floating-alpha premultiplied composition preserves the mathematical .625 result; native 8-bit .627 difference is retained separately');alphaColor:Destroy()
 local retainedShadows=fixture('#box{color:red;box-shadow:2px 4px red}#shadowField{width:30px;height:20px}',false,false,function(doc)Node.append(Node.findById(doc,'box'),Node.element('input',{id='shadowField',value='retained'}))end)
 retainedShadows:Run("const shadowTarget=document.getElementById('box');const shadowFrames=[{boxShadow:'inset 0 0 0 8px currentColor,2px 4px red'},{boxShadow:'inset 0 0 0 16px currentColor,6px 8px blue,10px 12px green'}];const shadowEffect=shadowTarget.animate(shadowFrames,{duration:100,fill:'both'});shadowEffect.finished.catch(()=>{});shadowEffect.ready.catch(()=>{});shadowEffect.pause();shadowEffect.currentTime=50;")
 local shadowBox=retainedShadows.Tree.NodeBoxes[retainedShadows.Node];local shadowGui=shadowBox.Gui
 local shadowField;for _,control in retainedShadows.Tree.Controls do if control.Node.Attributes.id=='shadowField'then shadowField=control.Item.Editor;break end end
 assert(shadowField and #retainedShadows.Diagnostics==0,'The animated shadow target retains its real native input')
 shadowField.Text='live';shadowField.CursorPosition=3;shadowField.SelectionStart=1
 local insetSurface=assert(shadowBox.InsetShadowSurface);local insetImage=assert(insetSurface.ImageContent)
 assert(insetSurface.Parent==shadowGui and insetSurface.ZIndex==0 and not insetSurface.Active and insetSurface.ImageTransparency==0,'Dynamic inset paint uses one child below the retained editor without replacing its native Frame')
 local middleOuter=assert(shadowBox.ShadowGuis[2]);local paddedOuter=assert(shadowBox.ShadowGuis[3])
 near(middleOuter.Offset[1],4,'Retained second shadow horizontal midpoint');near(middleOuter.Offset[2],6,'Retained second shadow vertical midpoint');near(middleOuter.Color.R,.5,'Retained second shadow red midpoint');near(middleOuter.Color.B,.5,'Retained second shadow blue midpoint');near(paddedOuter.Transparency,.5,'Padded third shadow midpoint alpha')
 local pixel=(50*insetImage.Size.X+1)*4
 assert(buffer.readu8(insetImage.Pixels,pixel)==255 and buffer.readu8(insetImage.Pixels,pixel+1)==0 and buffer.readu8(insetImage.Pixels,pixel+3)==255,'Actual inset pixels consume currentColor at the held sample')
 local shadowLayouts,shadowRequests,shadowMeasurements=retainedShadows.Layouts,retainedShadows.Requests,measurements
 local shadowObjects,shadowImages,shadowWrites,shadowCache=#objects,#images,insetImage.Writes,retainedShadows.Outside.CachedLayout
 retainedShadows:Run('shadowEffect.currentTime=50;shadowTarget.getBoundingClientRect();shadowTarget.getBoundingClientRect();')
 assert(#objects==shadowObjects and #images==shadowImages and insetImage.Writes==shadowWrites,'An unchanged held shadow sample allocates and rasterizes nothing')
 retainedShadows:Run("shadowTarget.style.color='green';console.log(getComputedStyle(shadowTarget).boxShadow);")
 assert(insetSurface.ImageContent==insetImage and buffer.readu8(insetImage.Pixels,pixel)==0 and buffer.readu8(insetImage.Pixels,pixel+1)==128,'A live foreground recolors the same retained inset texture')
 retainedShadows:Run('shadowEffect.cancel();')
 assert(insetSurface.ImageTransparency==1 and shadowBox.ShadowGuis[1].Transparency==0 and middleOuter.Transparency==1 and paddedOuter.Transparency==1,'Cancel restores the original outer shadow and hides animated-only inset/list layers')
 retainedShadows:Run("const replayShadow=shadowTarget.animate(shadowFrames,{duration:100,fill:'both'});replayShadow.finished.catch(()=>{});replayShadow.ready.catch(()=>{});replayShadow.pause();replayShadow.currentTime=50;replayShadow.commitStyles();replayShadow.cancel();")
 assert(shadowBox.InsetShadowSurface==insetSurface and insetSurface.ImageContent==insetImage and shadowBox.ShadowGuis[2]==middleOuter and shadowBox.ShadowGuis[3]==paddedOuter and insetSurface.ImageTransparency==0,'Replay and commit reuse their real inset image and every existing outer list slot')
 assert(shadowBox.Gui==shadowGui and shadowField.Text=='live'and shadowField.CursorPosition==3 and shadowField.SelectionStart==1,'Shadow sampling, foreground change, cancellation and commit preserve editor identity and selection')
 assert(retainedShadows.Layouts==shadowLayouts and retainedShadows.Requests==shadowRequests and measurements==shadowMeasurements and #objects==shadowObjects and #images==shadowImages and retainedShadows.Outside.CachedLayout==shadowCache,'Paint-only shadows reuse all geometry, measurements, allocations and unrelated caches')
 assert(not shadowBox.AnimationAuthorFields and not shadowBox.SampledBoxShadows,'Final committed shadow cancellation releases sampled sources and author snapshots')
 retainedShadows:AssertIdle('Retained shadow cancellation/commit');retainedShadows:Destroy()
 do
 local function verifyTextShadows()
 local textShadows=fixture('#box{color:red;opacity:.5}#textChild{color:green}#textField{width:30px;height:10px}#plainChild{text-shadow:none}',false,false,function(doc)
  local target=Node.findById(doc,'box');Node.append(target,Node.text('Shadow '));local child=Node.element('span',{id='textChild'});Node.append(child,Node.text('Child '));Node.append(target,child);local plain=Node.element('span',{id='plainChild'});Node.append(plain,Node.text('Plain '));Node.append(target,plain);Node.append(target,Node.element('input',{id='textField',value='kept'}))
 end)
 local textBox=textShadows.Tree.NodeBoxes[textShadows.Node];local textGui,textGroup=textBox.Gui,textBox.OpacityGroup;local words={};local textField
 for _,run in textBox.Children do for _,item in run.Items or{}do if item.Text and item.Text~=''then words[item.Text]=item end end end
 for _,control in textShadows.Tree.Controls do if control.Node.Attributes.id=='textField'then textField=control.Item.Editor end end
 local word,child,plain=assert(words.Shadow),assert(words.Child),assert(words.Plain);local wordGui,childGui,plainGui=word.Gui,child.Gui,plain.Gui
 textField.Text='live';textField.CursorPosition=3;textField.SelectionStart=1
 local initialMeasurements,initialLayouts,initialRequests,initialCache=measurements,textShadows.Layouts,textShadows.Requests,textShadows.Outside.CachedLayout
 textShadows:Run("const textTarget=document.getElementById('box');const textEffect=textTarget.animate({textShadow:['none','600px 20px currentColor,10px 12px blue']},{duration:100,fill:'both'});textEffect.finished.catch(()=>{});textEffect.ready.catch(()=>{});textEffect.pause();textEffect.currentTime=50;")
 local first=assert(word.ShadowLabels and word.ShadowLabels[1]).Gui;local second=assert(word.ShadowLabels[2]).Gui;local childShadow=assert(child.ShadowLabels and child.ShadowLabels[1]).Gui
 assert(word.Gui==wordGui and child.Gui==childGui and plain.Gui==plainGui and textBox.Gui==textGui and textBox.OpacityGroup==textGroup,'Adding inherited text-shadow layers preserves native word/box/compositing identity')
 near(first.Position[1],300,'Retained text-shadow horizontal midpoint');near(first.Position[2],10,'Retained text-shadow vertical midpoint');near(first.TextTransparency,.5,'Padded text-shadow midpoint alpha');near(first.TextColor3.R,1,'Actual text-shadow currentColor consumes target foreground');near(childShadow.TextColor3.R,1,'Animated inherited shadow uses resolved target color despite green child foreground')
 assert(not plain.ShadowLabels,'Explicit text-shadow:none blocks inherited sampled shadows')
 assert(textGroup.Gui.Size[1]>=word.X+word.Width+300 and textBox.OuterWidth==200,'Text-shadow paint expands real compositing bounds while preserving CSS box width')
 local currentObjects=#objects;local groupWidth=textGroup.Gui.Size[1]
 textShadows:Run('textEffect.currentTime=50;textTarget.getBoundingClientRect();textTarget.getBoundingClientRect();')
 assert(#objects==currentObjects and measurements==initialMeasurements and textShadows.Layouts==initialLayouts and textShadows.Requests==initialRequests and textGroup.Gui.Size[1]==groupWidth,'Held text-shadow paint allocates/measures/arranges nothing and reuses bounds')
 textShadows:Run("textTarget.style.color='blue';textTarget.getBoundingClientRect();")
 near(first.TextColor3.B,1,'A live foreground updates the same currentColor shadow label');near(childShadow.TextColor3.B,1,'Resolved sampled foreground is inherited by the same child shadow label')
 textShadows:Run('textEffect.cancel();')
 assert(not first.Visible and not second.Visible and not childShadow.Visible and not textBox.AnimationTextShadowAuthor and next(textShadows.Tree.AnimationTextShadowOverrides)==nil,'Cancel hides retained text-shadow layers and clears author/override state')
 near(textGroup.Gui.Size[1],200,'Cancellation restores actual text compositing width')
 textShadows:Run("textEffect.pause();textEffect.ready.catch(()=>{});textEffect.finished.catch(()=>{});textEffect.currentTime=50;textEffect.commitStyles();textEffect.cancel();")
 assert(word.ShadowLabels[1].Gui==first and word.ShadowLabels[2].Gui==second and child.ShadowLabels[1].Gui==childShadow and first.Visible and second.Visible,'Replay and commit reveal the same retained text-shadow slots')
 assert(textField.Text=='live'and textField.CursorPosition==3 and textField.SelectionStart==1 and textBox.Gui==textGui and word.Gui==wordGui and textShadows.Outside.CachedLayout==initialCache,'Shadow color/replay/commit preserve input selection, hit-source GUI and unrelated cache')
 assert(textShadows.Layouts==initialLayouts and textShadows.Requests==initialRequests and measurements==initialMeasurements and #objects==currentObjects,'Sharp text-shadow operations remain paint-only after initial slot creation')
 textShadows:AssertIdle('Retained text shadows');textShadows:Run('textEffect.pause();textEffect.ready.catch(()=>{});textEffect.finished.catch(()=>{});textEffect.currentTime=25;');textShadows:Destroy();assert(not textBox.AnimationTextShadowAuthor and next(textShadows.Tree.AnimationTextShadowOverrides)==nil,'Disposing an active text-shadow releases isolated inherited/sample state')
 local shadowScopes=fixture('#box{color:red}#clearScope{text-shadow:none}',false,false,function(doc)
  local target=Node.findById(doc,'box');Node.append(target,Node.text('AA'));local scope=Node.element('span',{id='clearScope'});Node.append(scope,Node.text('BB'));Node.append(target,scope);Node.append(target,Node.text('CC'));Node.append(target,Node.element('input',{id='scopeField'}))
 end)
 local scopeBox=shadowScopes.Tree.NodeBoxes[shadowScopes.Node];local scopeGui=scopeBox.Gui;local scopeInput
 for _,control in shadowScopes.Tree.Controls do if control.Node.Attributes.id=='scopeField'then scopeInput=control.Item.Editor end end
 scopeInput.Text='selected';scopeInput.CursorPosition=4;scopeInput.SelectionStart=2
 shadowScopes:Run("const scopeTarget=document.getElementById('box');const scopedShadow=scopeTarget.animate({textShadow:['1px 2px red','5px 6px blue']},{duration:100,fill:'both'});scopedShadow.finished.catch(()=>{});scopedShadow.ready.catch(()=>{});scopedShadow.pause();scopedShadow.currentTime=50;")
 local clear,painted
 for _,run in scopeBox.Children do for _,item in run.Items or{}do if item.Text=='BB'then clear=item elseif item.Text=='AA'then painted=item end end end
 assert(clear and painted and not clear.ShadowLabels and painted.ShadowLabels and painted.ShadowLabels[1].Gui.Visible,'Existing source-scope regroup keeps an explicit none span out of sampled shadows')
 local scopeLayouts,scopeMeasures,scopeObjects=shadowScopes.Layouts,measurements,#objects
 shadowScopes:Run('scopedShadow.currentTime=75;scopeTarget.getBoundingClientRect();')
 assert(shadowScopes.Layouts==scopeLayouts and measurements==scopeMeasures and #objects==scopeObjects and scopeBox.Gui==scopeGui and not clear.ShadowLabels,'After required initial source partition, shadow samples retain word scopes without additional layout')
 shadowScopes:Run('scopedShadow.cancel();');assert(scopeInput.Text=='selected'and scopeInput.CursorPosition==4 and scopeInput.SelectionStart==2 and scopeBox.Gui==scopeGui,'Source-scope shadow changes retain the actual input and selection');shadowScopes:AssertIdle('Text-shadow scopes');shadowScopes:Destroy()
 end
 verifyTextShadows()
 end
 do
 local function verifyEmphasisColors()
 local emphasis=fixture('#box{color:red;opacity:.5;text-emphasis:filled circle currentColor;text-shadow:2px 4px currentColor}#markChild{color:green}#fixedMark{color:green;text-emphasis-color:currentColor}#markField{width:30px;height:10px}',false,false,function(doc)
  local target=Node.findById(doc,'box');Node.append(target,Node.text('Marks '));local child=Node.element('span',{id='markChild'});Node.append(child,Node.text('Child '));Node.append(target,child);local fixed=Node.element('span',{id='fixedMark'});Node.append(fixed,Node.text('Fixed '));Node.append(target,fixed);Node.append(target,Node.element('input',{id='markField',value='kept'}))
 end)
 local box=emphasis.Tree.NodeBoxes[emphasis.Node];local boxGui,group=box.Gui,box.OpacityGroup;local words={};local editor
 for _,run in box.Children do for _,item in run.Items or{}do if item.Text and item.Text~=''then words[item.Text]=item end end end
 for _,control in emphasis.Tree.Controls do if control.Node.Attributes.id=='markField'then editor=control.Item.Editor end end
 local word,child,fixed=assert(words.Marks),assert(words.Child),assert(words.Fixed)
 local wordGui,childGui,fixedGui=word.Gui,child.Gui,fixed.Gui
 local mark,childMark,fixedMark=assert(word.EmphasisPool[1]),assert(child.EmphasisPool[1]),assert(fixed.EmphasisPool[1]);local markGui,markText,markShadow=mark.Gui,mark.TextGui,assert(mark.ShadowLabels[1]).Gui
 near(childMark.TextGui.TextColor3.G,128/255,'Static inherited emphasis currentColor uses child foreground')
 editor.Text='live';editor.CursorPosition=3;editor.SelectionStart=1
 local initialLayouts,initialRequests,initialMeasurements,initialObjects,initialCache=emphasis.Layouts,emphasis.Requests,measurements,#objects,emphasis.Outside.CachedLayout
 local sizeX,sizeY=group.Gui.Size[1],group.Gui.Size[2]
 emphasis:Run("const markTarget=document.getElementById('box');const markEffect=markTarget.animate({textEmphasisColor:['rgba(255,0,0,.2)','rgba(0,0,255,.8)']},{duration:100,fill:'both'});markEffect.finished.catch(()=>{});markEffect.ready.catch(()=>{});markEffect.pause();markEffect.currentTime=50;")
 near(markText.TextColor3.R,.2,'Actual retained emphasis premultiplied red');near(markText.TextColor3.B,.8,'Actual retained emphasis premultiplied blue');near(markText.TextTransparency,.5,'Actual retained emphasis midpoint alpha')
 near(childMark.TextGui.TextColor3.R,.2,'Inherited animated mark receives resolved sampled red');near(childMark.TextGui.TextColor3.B,.8,'Inherited animated mark receives resolved sampled blue')
 near(fixedMark.TextGui.TextColor3.G,128/255,'Explicit descendant currentColor retains its independent green source')
 near((word.TextGui or word.Gui).TextColor3.R,1,'Animating emphasis does not recolor the source text');near(markShadow.TextColor3.R,1,'Mark shadow currentColor keeps its existing foreground source')
 emphasis:Run('markEffect.currentTime=50;markTarget.getBoundingClientRect();markTarget.getBoundingClientRect();')
 assert(word.Gui==wordGui and child.Gui==childGui and fixed.Gui==fixedGui and mark.Gui==markGui and mark.TextGui==markText and mark.ShadowLabels[1].Gui==markShadow and box.Gui==boxGui and box.OpacityGroup==group,'Color samples preserve actual words, emphasis marks, shadows and compositing surfaces')
 near(group.Gui.Size[1],sizeX,'Emphasis color preserves compositing width');near(group.Gui.Size[2],sizeY,'Emphasis color preserves compositing height')
 assert(emphasis.Layouts==initialLayouts and emphasis.Requests==initialRequests and measurements==initialMeasurements and #objects==initialObjects,'Emphasis color samples allocate, measure and arrange nothing')
 emphasis:Run('markEffect.cancel();');near(childMark.TextGui.TextColor3.G,128/255,'Cancel restores symbolic child currentColor')
 assert(not box.AnimationColorAuthor and next(emphasis.Tree.AnimationColorOverrides)==nil,'Cancel releases sampled emphasis author and weak override state')
 emphasis:Run("markEffect.pause();markEffect.ready.catch(()=>{});markEffect.finished.catch(()=>{});markEffect.currentTime=50;markEffect.commitStyles();markEffect.cancel();")
 near(childMark.TextGui.TextColor3.B,.8,'Committed sampled emphasis remains inherited as its resolved author color')
 assert(editor.Text=='live'and editor.CursorPosition==3 and editor.SelectionStart==1 and emphasis.Outside.CachedLayout==initialCache and mark.Gui==markGui and mark.TextGui==markText,'Commit/cancel retain editor text, selection, foreign caches and mark instances')
 assert(emphasis.Layouts==initialLayouts and emphasis.Requests==initialRequests and measurements==initialMeasurements and #objects==initialObjects,'Emphasis commit/cancel remain paint-only')
 emphasis:AssertIdle('Retained emphasis color');emphasis:Run('markEffect.pause();markEffect.ready.catch(()=>{});markEffect.finished.catch(()=>{});markEffect.currentTime=25;');emphasis:Destroy()
 assert(not box.AnimationColorAuthor and not box.AnimationColorInheritedEmphasis and not box.AnimationColorInheritedEmphasisAlpha and not box.AnimationColorInheritedSources and next(emphasis.Tree.AnimationColorOverrides)==nil,'Active emphasis disposal clears inherited bases and weak samples')
 local scoped=fixture('#box{color:red;text-emphasis:filled circle red}#stableMark{text-emphasis-color:red}',false,false,function(doc)
  local target=Node.findById(doc,'box');Node.append(target,Node.text('AA'));local stable=Node.element('span',{id='stableMark'});Node.append(stable,Node.text('BB'));Node.append(target,stable);Node.append(target,Node.text('CC'));Node.append(target,Node.element('input',{id='scopeMarkField'}))
 end)
 local scopeBox=scoped.Tree.NodeBoxes[scoped.Node];local scopeGui=scopeBox.Gui;local scopeEditor
 for _,control in scoped.Tree.Controls do if control.Node.Attributes.id=='scopeMarkField'then scopeEditor=control.Item.Editor end end
 scopeEditor.Text='selected';scopeEditor.CursorPosition=4;scopeEditor.SelectionStart=2
 scoped:Run("const scopeMark=document.getElementById('box');const scopeEffect=scopeMark.animate({textEmphasisColor:['red','blue']},{duration:100,fill:'both'});scopeEffect.finished.catch(()=>{});scopeEffect.ready.catch(()=>{});scopeEffect.pause();scopeEffect.currentTime=50;")
 local stable,painted
 for _,run in scopeBox.Children do for _,item in run.Items or{}do if item.Text=='BB'then stable=item elseif item.Text=='AA'then painted=item end end end
 assert(stable and painted and stable.EmphasisPool and painted.EmphasisPool,'A divergent original emphasis source is partitioned through existing text scopes')
 near(stable.EmphasisPool[1].TextGui.TextColor3.R,1,'Explicit equal author color stays red after source split');near(painted.EmphasisPool[1].TextGui.TextColor3.B,.5,'Only inherited emphasis sources receive the sampled color')
 local layouts,requests,measures,allocations=scoped.Layouts,scoped.Requests,measurements,#objects;local stableGui,paintedGui=stable.Gui,painted.Gui
 scoped:Run('scopeEffect.currentTime=75;scopeMark.getBoundingClientRect();')
 assert(scoped.Layouts==layouts and scoped.Requests==requests and measurements==measures and #objects==allocations and stable.Gui==stableGui and painted.Gui==paintedGui and scopeBox.Gui==scopeGui,'Following emphasis samples retain partitioned source words with no further layout or allocations')
 scoped:Run('scopeEffect.cancel();');assert(scopeEditor.Text=='selected'and scopeEditor.CursorPosition==4 and scopeEditor.SelectionStart==2 and scopeBox.Gui==scopeGui,'Scope cancellation retains actual input selection and owner GUI');scoped:AssertIdle('Emphasis source scopes');scoped:Destroy()
 end
 verifyEmphasisColors()
 end
 local function verifyReferences()
 local failures={}
 for _,case in fixtures do
  if case.browserOnly then continue end
  assert(#case.expected>0,case.name..': native reference has not been captured')
  local expected=case.normativeExpected or case.engineExpected or case.expected
  local prepare
  if case.emphasis then prepare=function(doc)local box=Node.findById(doc,'box');Node.append(box,Node.text('Marks'));local child=Node.element('div',{id='child'});Node.append(child,Node.text('Child'));Node.append(box,child)end
  elseif case.transitionShorthand then prepare=function(doc)local box=Node.findById(doc,'box');Node.append(box,Node.element('div',{id='shorthandLeaf'}));Node.append(box,Node.element('input',{id='shorthandField',value='kept'}))end end
  local s=fixture((if case.emphasis then '#box{text-emphasis:filled circle}'else '')..(case.css or ''),case.cssMotion,false,prepare);local outside=s.Outside.Gui;local cache=s.Outside.CachedLayout
  local keptBox=s.Tree.NodeBoxes[s.Node];local keptGui=keptBox.Gui;local keptOutline=keptBox.Outline and keptBox.Outline.Gui;local keptEditor
  if case.transitionShorthand then
   for _,control in s.Tree.Controls do if control.Node.Attributes.id=='shorthandField'then keptEditor=control.Item.Editor or control.Item.Gui end end
   assert(keptEditor,'Shorthand transition has an actual retained native input');keptEditor.Text='live';keptEditor.CursorPosition=3;keptEditor.SelectionStart=1
  end
  s:Run('function record(value){console.log(String(value));}\n'..case.source)
  if #s.Diagnostics>0 or #s.Values~=#expected then table.insert(failures,case.name..': '..table.concat(s.Diagnostics,' / ')..' actual='..table.concat(s.Values,' | '))
  else for i,value in s.Values do if value~=expected[i]then table.insert(failures,case.name..' ['..i..']: '..value..' ~= '..expected[i])end end end
  if #s.Diagnostics==0 then local valid,validationError=pcall(function()
   local p=case.paint;local box=s.Tree.NodeBoxes[s.Node]
   if p and box then
    local surface=if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui;local scale=if box.TransformScale then box.TransformScale.Scale else 1
    if p.width then near(surface.Size[1]*scale,p.width,case.name..' native width')end
    if p.height then near(surface.Size[2]*scale,p.height,case.name..' native height')end
    if p.x then near(surface.Position[1]-(surface.AnchorPoint and surface.AnchorPoint.X or 0)*surface.Size[1]*scale,p.x,case.name..' native left')end
    if p.opacity then near(if box.OpacityGroup then 1-box.OpacityGroup.Gui.GroupTransparency else box.Style.Opacity or 1,p.opacity,case.name..' native opacity')end
   end
   if case.transitionShorthand then
    local sample=case.shorthandPaint
    assert(box.Gui==keptGui,'Shorthand sampling retains the rendered box')
    local editor;for _,control in s.Tree.Controls do if control.Node.Attributes.id=='shorthandField'then editor=control.Item.Editor or control.Item.Gui end end
    assert(editor==keptEditor and editor.Text=='live'and editor.CursorPosition==3 and editor.SelectionStart==1,'Shorthand sampling preserves the native editor and live selection')
    if sample.outlineWidth then
     near(box.Style.OutlineWidth,sample.outlineWidth,'Retained shorthand outline width');near(box.Style.OutlineOffset or 0,sample.outlineOffset,'Outline offset remains outside the shorthand')
     assert(box.Outline,'Shorthand outline has a real painter');if keptOutline then assert(box.Outline.Gui==keptOutline,'Shorthand outline retains its original paint surface')end
     near(box.Outline.Gui.Size[1],box.OuterWidth+2*(sample.outlineWidth+sample.outlineOffset),'Actual outline surface consumes the sampled width and offset')
    else
     near(box.Style.FontSize,sample.fontSize,'Shorthand font size');local line=box.Style.LineHeight;near(if line.Kind=='number'then line.Value*box.Style.FontSize else line.Value,sample.lineHeight,'Shorthand line-height')
     local leaf=s.Tree.NodeBoxes[Node.findById(s.Document,'shorthandLeaf')];assert(leaf,'Shorthand metrics retain a laid-out descendant');near(leaf.OuterWidth,sample.leafWidth,'Descendant em geometry consumes the shorthand font')
    end
   end
   if not case.layout then assert(s.Layouts==0,case.name..': paint-only sample arranged '..s.Layouts..' times');assert(cache==s.Outside.CachedLayout,'Paint-only sample rebuilt an unrelated layout cache')end
   assert(s.Outside.Gui==outside,'Animation recreated an unrelated retained GUI')
   assert(#s.Messages==0,table.concat(s.Messages,' / '))
   assert(s.Runtime.EventLoop.FrameCount==0,case.name..': paused sample retained an animation frame')
   local before=s.Layouts;s:Run("document.getElementById('box').getBoundingClientRect();document.getElementById('box').getBoundingClientRect();")
   assert(s.Layouts==before,'Unchanged repeated geometry read requested more layout')
  end);if not valid then table.insert(failures,case.name..': '..tostring(validationError))end end
  s:Destroy(case.name)
 end
 for _,failure in failures do print('Animation layout mismatch: '..failure)end
 assert(#failures==0,'Animation layout fixture failures: '..#failures)
 end
 verifyReferences()
 local extensions,browserOnly,normative=0,0,0;for _,case in fixtures do if case.engineExpected then extensions+=1 elseif case.normativeExpected then normative+=1 elseif case.browserOnly then browserOnly+=1 end end
 print('JavaScript WAAPI additive/layout: '..(#fixtures-extensions-browserOnly-normative)..' native-reference samples, '..extensions..' explicit Level 2 extensions, '..browserOnly..' browser-only references, '..normative..' normative samples with preserved raw browser differences, '..cssDOMNativeCount..' native CSS DOM cases, '..cssDOMNormativeCount..' normative CSS DOM cases with preserved raw browser differences, retained paint/hits, dirty publication, transforms, timing and lifetime passed')
end
