--!strict
return function(Parser,Node,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,Controller,Animations,BoxTransform,Measurement,fixture)
 local function signal()
  local listeners={};local api={}
  function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
  function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
  function api:Count()local n=0;for _,e in listeners do if e[1].Connected then n+=1 end end;return n end
  return api
 end
 local guis,focused,deferred={},nil,{}
 local factory={create=function(class,parent,properties)
  local gui=table.clone(properties or{});gui.ClassName,gui.Parent=class,parent;gui.Visible=true
  gui.Position=gui.Position or UDim2.fromOffset(0,0);gui.Size=gui.Size or UDim2.fromOffset(0,0);gui.AnchorPoint=Vector2.new(0,0);gui.Rotation=0
  gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(800,900);gui.CanvasPosition=Vector2.new(0,0)
  gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local attributes,signals={},{}
  function gui:GetPropertyChangedSignal(key)if not signals[key]then signals[key]=signal()end;return signals[key]end
  function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
  function gui:SetAttribute(key,value)attributes[key]=value;if signals['attribute:'..key]then signals['attribute:'..key]:Fire()end end
  function gui:GetAttribute(key)return attributes[key]end
  function gui:IsA(kind)return kind==class or kind=='GuiObject'end
  function gui:IsFocused()return focused==self end
  function gui:CaptureFocus()focused=self;self.Focused:Fire()end
  function gui:ReleaseFocus()if focused==self then focused=nil;self.FocusLost:Fire(false)end end
  function gui:GetChildren()local out={};for _,g in guis do if g.Parent==self and not g.Destroyed then table.insert(out,g)end end;return out end
  function gui:Destroy()assert(not self.Destroyed,'Duplicate GUI disposal');self.Destroyed=true;for _,g in self:GetChildren()do g:Destroy()end;self.Parent=nil end
  table.insert(guis,gui);return gui
 end}
 factory.modifier=factory.create
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
 local document=Parser.parseDocument(fixture.html);local root=factory.create('ScrollingFrame',nil,{})
 local messages,diagnostics={},{};local tree=renderer.build(document,root,function(m)if m~='audio has no media source'and m~='video has no media source'then table.insert(messages,m)end end,function(font)return font end,nil,nil,function()return 'rbxassetid://11'end)
 local page={Alive=true,Document=document,DocumentURL='https://example.test/inline-transforms',BaseURL='https://example.test/inline-transforms',Root=root,Cleanups={}}
 function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
 local layoutPasses=0
 local function arrange(targets)layoutPasses+=1;Dirty.begin(tree,targets);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true);BoxTransform.applyTree(tree)end
 arrange();root:SetAttribute('Status','ready')
 local frame,clock=signal(),0;local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
 function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end
 local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return {}end},Factory=factory,Clock=function()return clock end,RunService={RenderStepped=frame},ContentProvider={PreloadAsync=function()end},Instance={new=function(class)local value=factory.create(class,nil,{});value.Loaded,value.Ended,value.Played,value.Paused,value.Stopped=signal(),signal(),signal(),signal(),signal();function value:Play()self.Playing=true end;function value:Pause()self.Playing=false end;function value:Stop()self.Playing=false end;return value end},
  Task={spawn=function(fn)fn()end,wait=function()end,defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
 Controller.start(page,tree,function()end,error,services)
 tree.MotionRuntime=Animations.start(page,tree,error,services)
 local realm=HTMLScripts.start(page,tree,function()end,function(m)table.insert(diagnostics,m)end,{JavaScriptServices=services})
 function page:GeometryViewport()return {Width=800,Height=900,ClientWidth=800,ClientHeight=900,ScrollX=0,ScrollY=0,ScrollWidth=800,ScrollHeight=900}end
 function page:HasPendingLayout()return false end
 function page:FlushScriptLayout()local needed,targets=realm:Flush();if needed then arrange(targets)end;return needed end
 local function settle()
  for _=1,32 do page:FlushScriptLayout();realm:AfterLayout();local work=deferred;deferred={};for _,fn in work do fn()end;local tasks=realm:PumpTasks();if tasks==0 and #deferred==0 and not realm:HasPending()then break end end
  page:FlushScriptLayout();assert(#diagnostics==0,table.concat(diagnostics,' | '));assert(#messages==0,table.concat(messages,' | '))
 end
 local function run(code)assert(realm:Run(code),table.concat(realm.Diagnostics,' | '));settle()end
 local function node(id)return assert(Node.findById(document,id),id)end
 local function item(id)local c=page.FormModel:Resolve(node(id));return if c then c.Item else assert(tree:FindImageItem(node(id)),id)end
 local retained={};for _,id in fixture.ids do local i=item(id);assert(not i.InlineBox and not tree.NodeBoxes[node(id)],id..' must begin as a genuine inline item');retained[id]={Node=node(id),Item=i,Gui=i.Gui,Box=i.BoxGui}end
 local edit=assert(page.FormModel:Resolve(node('editor')));local editor=edit.Item.Editor
 editor:CaptureFocus();editor.CursorPosition,editor.SelectionStart=6,2
 local textBinding=editor:GetPropertyChangedSignal('Text'):Count();assert(textBinding>0,'Actual native editor binding was not installed')
 run(fixture.source)
 local function near(a,b,label)assert(math.abs(a-b)<.055,label..': '..tostring(a)..' != '..tostring(b))end
 local function offset(value,axis)local part=value[axis];return if part then part.Offset else value[if axis=='X'then 1 else 2]end
 local function nativePaintRect(i)
  -- CSS geometry excludes outlines. Project the real border surface through
  -- its native ancestors, including an opacity viewport with painted outsets.
  local w,h=offset(i.BoxGui.Size,'X'),offset(i.BoxGui.Size,'Y')
  local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
  for _,p in {{0,0},{w,0},{0,h},{w,h}}do
   local x,y,g=p[1],p[2],i.BoxGui
   while g~=i.Gui do
    assert(g,'Border surface no longer belongs to its retained inline wrapper')
    local gw,gh=offset(g.Size,'X'),offset(g.Size,'Y');local s=1;for _,child in g:GetChildren()do if child.ClassName=='UIScale'then s=child.Scale end end
    local angle=math.rad(g.Rotation or 0);local co,si=math.cos(angle),math.sin(angle)
    local cx=offset(g.Position,'X')+s*gw*(.5-g.AnchorPoint.X);local cy=offset(g.Position,'Y')+s*gh*(.5-g.AnchorPoint.Y)
    local dx,dy=(x-gw/2)*s,(y-gh/2)*s;x,y=cx+co*dx-si*dy,cy+si*dx+co*dy;g=g.Parent
   end
   left,top,right,bottom=math.min(left,x),math.min(top,y),math.max(right,x),math.max(bottom,y)
  end
  return left,top,right-left,bottom-top
 end
 local function snapshotGUI()
  local result={};for _,g in guis do result[g]={Position=g.Position,Size=g.Size,AnchorPoint=g.AnchorPoint,Rotation=g.Rotation,Scale=g.Scale,Parent=g.Parent,Visible=g.Visible,Destroyed=g.Destroyed,Text=g.Text,Cursor=g.CursorPosition,Selection=g.SelectionStart}end;return result
 end
 local measured,checks,opacityOwners=0,0,{}
 run('function inlineCompareNumbers(actual,expected){if(actual==="none"||expected==="none")return actual===expected;function values(s){return s.replaceAll(","," ").replaceAll("("," ").replaceAll(")"," ").split(" ").map(parseFloat).filter(Number.isFinite);}const a=values(actual),b=values(expected);return a.length===b.length&&a.every((v,i)=>Math.abs(v-b[i])<.055);}')
 for _,record in fixture.snapshots do
  local before=layoutPasses
  run('var inlineBeforeResizeCount=inlineResize.length;')
  if record.style then run('inlineSet('..string.format('%q',record.style)..');')elseif record.name=='waapi-half'then run('inlineAnimate();')elseif record.name=='opacity-half'then run('inlineOpacityAnimate();')else run('inlineCancel();')end
  if record.name~='resize'and record.name~='opacity-base'and record.name~='opacity-resize'then assert(layoutPasses==before,record.name..' transform-only mutation requested layout')end
  local geometryChecks={'var inlineActual=inlineRects();var inlineLatest={};for(const e of inlineResize)inlineLatest[e[0]]=e;'}
  if record.name~='resize'and record.name~='opacity-base'and record.name~='opacity-resize'then table.insert(geometryChecks,'if(inlineResize.length!==inlineBeforeResizeCount)throw new Error("Transform-only mutation delivered ResizeObserver entries");')end
  table.insert(geometryChecks,'if(inlineResize.length!=='..record.resizeCount..')throw new Error("Native ResizeObserver delivery count '..record.name..'");')
  for index,id in fixture.ids do
   local i,r,b=item(id),record.rects[index],record.baseline[index]
   assert(i==retained[id].Item and i.Gui==retained[id].Gui and i.BoxGui==retained[id].Box and not i.Gui.Destroyed,id..' lost retained inline surfaces')
   near(i.BoxWidth,b.width,id..' layout width');near(i.BoxHeight,b.height,id..' layout height')
   local x,y,w,h=nativePaintRect(i)
   near(w,r.width,id..' '..record.name..' native painted width');near(h,r.height,id..' '..record.name..' native painted height')
   near(x-i.Style.Margin[4],r.x-b.x,id..' '..record.name..' painted origin x');near(y-i.Style.Margin[1],r.y-b.y,id..' '..record.name..' painted origin y')
   table.insert(geometryChecks,'{const r=inlineActual['..(index-1)..'];if(Math.abs(r.width-'..r.width..')>.055||Math.abs(r.height-'..r.height..')>.055||r.cssWidth!=='..string.format('%q',r.cssWidth)..'||r.cssHeight!=='..string.format('%q',r.cssHeight)..'||r.transformBox!=='..string.format('%q',r.transformBox)..')throw new Error("Actual CSSOM/layout '..id..' '..record.name..'");}')
   for _,property in {'transform','origin','translate','rotate','scale'}do
    table.insert(geometryChecks,'if(!inlineCompareNumbers(inlineActual['..(index-1)..'].'..property..','..string.format('%q',r[property])..'))throw new Error("Native CSSOM '..property..' '..id..' '..record.name..': "+inlineActual['..(index-1)..'].'..property..');')
   end
   local resize=record.resize[index]
   table.insert(geometryChecks,'{const e=inlineLatest['..string.format('%q',id)..'];if(!e||Math.abs(e[1]-'..resize[2]..')>.055||Math.abs(e[2]-'..resize[3]..')>.055)throw new Error("Untransformed ResizeObserver '..id..' '..record.name..'");}')
   checks+=1
   if record.name=='opacity-half'or record.name=='opacity-resize'or record.name=='opacity-cancel'then
    assert(i.OpacityGroup and i.GeometryBox.OpacityGroup==i.OpacityGroup,'Inline compositor has no actual item owner')
    if record.name=='opacity-half'then opacityOwners[id]=i.OpacityGroup else assert(i.OpacityGroup==opacityOwners[id],id..' replaced its opacity compositor during resize/cancel')end
    near(1-i.OpacityGroup.Gui.GroupTransparency,tonumber(r.opacity),id..' retained compositor opacity')
    if id=='editor'then
     local group=i.OpacityGroup;local x=offset(group.Content.Position,'X')+offset(i.BoxGui.Position,'X');local y=offset(group.Content.Position,'Y')+offset(i.BoxGui.Position,'Y')
     assert(x>=1 and y>=1 and x+i.BoxWidth+1<=offset(group.Gui.Size,'X')and y+i.BoxHeight+1<=offset(group.Gui.Size,'Y'),'Focused editor compositor clipped its outline')
    end
   end
   -- Keep each native comparison below the real per-script instruction limit.
   run(table.concat(geometryChecks,'\n'));geometryChecks={}
  end
  assert(focused==editor and edit.Item.Editor==editor and editor.CursorPosition==6 and editor.SelectionStart==2 and editor:GetPropertyChangedSignal('Text'):Count()==textBinding,'Transform paint changed native focus/selection/binding')
  if record.name=='opacity-half'then
   local target=item('ellipsis');local group=target.OpacityGroup
   local owner=tree:TextOwner(node('ellipsis'));local repainted=false
   local x,y,w,h=nativePaintRect(target)
   for _,words in owner.Children or{}do if words.Kind=='Words'and words.RepaintStyles then assert(words.RepaintStyles());repainted=true end end
   assert(repainted,'Cached ellipsis requires an actual retained word repaint')
   assert(target.GeometryBox.OpacityGroup==group and target.OpacityGroup==group,'Cached ellipsis repaint lost compositor ownership')
   local nx,ny,nw,nh=nativePaintRect(target);near(nx,x,'Cached ellipsis paint x');near(ny,y,'Cached ellipsis paint y');near(nw,w,'Cached ellipsis paint width');near(nh,h,'Cached ellipsis paint height')
   near(1-group.Gui.GroupTransparency,.5,'Cached ellipsis compositor opacity')
  end
  local saved,count=snapshotGUI(),#guis
  local context=Measurement.new(tree,function()measured+=1;for g,old in saved do assert(g.Position==old.Position and g.Size==old.Size and g.AnchorPoint==old.AnchorPoint and g.Rotation==old.Rotation and g.Scale==old.Scale and g.Parent==old.Parent and g.Visible==old.Visible and g.Destroyed==old.Destroyed and g.Text==old.Text and g.CursorPosition==old.Cursor and g.SelectionStart==old.Selection,'Pure measurement changed live paint/editor state')end;return true end)
  layout.arrange(context.Root,800,0,0,function()measured+=1;for g,old in saved do assert(g.Position==old.Position and g.Size==old.Size and g.AnchorPoint==old.AnchorPoint and g.Rotation==old.Rotation and g.Scale==old.Scale,'Pure Arrange changed an inline transform')end;return true end);context:KeepMeasurements();assert(#guis==count,'Pure measurement created native surfaces')
 end
 editor.Text='changed';editor:GetPropertyChangedSignal('Text'):Fire();settle();assert(edit.Value=='changed'and edit.Item.Editor==editor,'Retained editor binding stopped accepting native edits')
 run('document.getElementById("sound").controls=false;')
 assert(not BoxTransform.node(tree,node('sound')),'Audio without controls kept a visual transform target')
 run('inlineObserver.disconnect();for(const id of inlineIDs)document.getElementById(id).remove();')
 for id,entry in retained do assert(entry.Gui.Destroyed and not BoxTransform.node(tree,entry.Node),id..' detached inline target retained its GUI/lookup');assert(opacityOwners[id].Gui.Destroyed,id..' detached inline target retained its compositor')end
 page.Alive=false;for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end
 assert(frame:Count()==0,'Disposed transform effects retained the frame connection')
 print('Inline replaced transforms: '..checks..' native GUI paint geometries, layout/CSSOM separation, retained editor and '..measured..' pure checkpoints passed')
end
