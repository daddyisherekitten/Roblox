--!strict
return function(Parser,Node,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,fixture)
 local allocations=0
 local factory={create=function(class,parent,props)
  allocations+=1
  local gui=table.clone(props);gui.ClassName=class;gui.Parent=parent
  function gui:Destroy()self.Parent=nil;self.Destroyed=true end
  return gui
 end}
 local renderer=loadRenderTree(factory)
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.5,size)end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local checks=0
 for _,case in fixture.cases do
  local document=Parser.parseDocument(case.html);local nodes={};local pending={document}
  while #pending>0 do local node=table.remove(pending);if node.Kind=='Element'then nodes[node.Attributes.id or node.Name]=node end;for _,child in node.Children do table.insert(pending,child)end end
  local root={AbsoluteSize=Vector2.new(case.viewport[1],case.viewport[2])}
  local tree=renderer.build(document,root,error,nil,nil,nil,function()return 'rbxassetid://1'end,case.css)
  local retained={}
  for node,box in tree.NodeBoxes do retained[node]=box.Gui end
  local retainedImages={}
  for _,item in tree.ImageItems do retainedImages[item]={Gui=item.Gui,BoxGui=item.BoxGui}end
  local function compare(snapshot,partial,changes)
   tree.ViewportHeight=snapshot.viewport[2]
   local count=allocations
   tree:SetMediaEnvironment(snapshot.viewport[1],snapshot.viewport[2])
   local stats=Dirty.begin(tree,changes or(if partial then {[tree]='children'}else nil))
   layout.arrange(tree,snapshot.layoutWidth,0,0,function()return true end);Dirty.finish(tree,true)
   if partial then assert(allocations==count,case.name..' resizing allocates no replacements')end
   for node,gui in retained do assert(tree.NodeBoxes[node].Gui==gui,'Layout/resizing preserves every box GUI')end
   for item,owned in retainedImages do assert(item.Gui==owned.Gui and item.BoxGui==owned.BoxGui,'Layout/resizing preserves inline/block image GUIs')end
   for _,item in tree.TextItems do
    if item.Kind=='Word'and item.Style.FontSize==0 then
     if item.Glyphs then for _,glyph in item.Glyphs do assert(glyph.Gui.TextTransparency==1,'Zero CSS font paints no native glyph')end
     else assert((item.TextGui or item.Gui).TextTransparency==1,'Zero CSS font paints no native word')end
     for _,copy in item.ShadowLabels or{}do assert(not copy.Gui.Visible,'Zero CSS font paints no native text shadow')end
    end
   end
   for _,probe in snapshot.boxes do
   local box=tree.NodeBoxes[nodes[probe.id]]
   if not box then
    local function find(run)
     for _,item in run.Items or{}do if item.Node==nodes[probe.id]then
      box={OuterHeight=item.BoxHeight,OuterWidth=item.BoxWidth,LayoutX=item.X,LayoutY=item.Y,LayoutParent=run,
       QuirksMode=run.QuirksMode,QuirksHeightBasis=run.QuirksHeightBasis,Style=item.Style,Node=item.Node};return
     end end
     for _,child in run.Children do find(child)end
    end
    find(tree)
   end
   assert(box,case.name..' '..probe.id..' missing box')
   assert(math.abs(box.OuterHeight-probe.height)<.01,case.name..' '..probe.id..' height '..box.OuterHeight..' ~= '..probe.height..' mode '..tostring(box.QuirksMode)..' basis '..tostring(box.QuirksHeightBasis)..' writing '..tostring(box.Style.WritingMode)..' parent '..tostring(box.Node.Parent and box.Node.Parent.Kind))
   local bx,by=0,0;local current=box
   while current do bx+=current.LayoutX or 0;by+=current.LayoutY or 0;current=current.LayoutParent end
   assert(math.abs(bx-probe.x)<.01 and math.abs(by-probe.y)<.01,case.name..' '..probe.id..' position '..bx..','..by..' ~= '..probe.x..','..probe.y)
   assert(math.abs(box.OuterWidth-probe.width)<.01,case.name..' '..probe.id..' width '..box.OuterWidth..' ~= '..probe.width)
   checks+=1
   end
   return stats
  end
  compare(case,false)
  if case.computed then
   local s=tree.NodeStyles[nodes.target];local expected=case.computed
   assert(s and math.abs((s.UnadjustedFontSize or s.FontSize)-expected.fontSize)<.01,case.name..' computed font size')
   assert(s.FontWeight==expected.fontWeight and s.FontStyle==expected.fontStyle,case.name..' computed font weight/style')
   assert(s.WhiteSpace==expected.whiteSpace and s.BoxSizing==expected.boxSizing,case.name..' computed white-space/box-sizing')
   local r,g,b=expected.color:match('^rgb%((%d+), (%d+), (%d+)%)$')
   assert(r and s.Color==Color3.fromRGB(tonumber(r),tonumber(g),tonumber(b)),case.name..' computed text color')
  end
  if case.afterBodyColor then
   local s=tree.NodeStyles[nodes.target]
   local own=case.name:find('own color and decoration',1,true)~=nil
   assert(#s.Decorations==(if case.mode=='quirks'then(if own then 1 else 0)else(if own then 2 else 1)),case.name..' decoration propagation across the table')
   nodes.body.Attributes.style='color:purple'
   local count=allocations
   local changed,relayout=tree:RefreshDOMStyles({[nodes.body]=true})
   assert(changed and not relayout and allocations==count,case.name..' body color remains paint without layout or replacement GUIs')
   local r,g,b=case.afterBodyColor:match('^rgb%((%d+), (%d+), (%d+)%)$')
   assert(r and s.Color==Color3.fromRGB(tonumber(r),tonumber(g),tonumber(b)),case.name..' dynamic body/table color')
  end
  for i,snapshot in case.resizes do
   local stats=compare(snapshot,true)
   if i==#case.resizes then
    local eligible=false
    for _,box in tree.NodeBoxes do if box.CanReuseLayout and not tree.HasFloats then eligible=true;break end end
    if eligible then assert(stats.Reused>0,case.name..' unchanged follow-up '..stats.Mode..' recomputed '..stats.Recomputed)end
   end
  end
  for _,snapshot in case.dimensionMutations or{}do
   nodes.target.Attributes.width=snapshot.value
   local changed,relayout,targets=tree:RefreshDOMStyles({[nodes.target]=true})
   if relayout then assert(changed and next(targets),'HTML size hint returns explicit local layout targets')end
   compare(snapshot,true,if relayout then targets else {})
  end
  for _,snapshot in case.groupMutations or{}do
   nodes.target.Attributes.style='height:'..snapshot.value
   local changed,relayout,targets=tree:RefreshDOMStyles({[nodes.target]=true})
   assert(changed and relayout and next(targets),'Row-group height returns explicit local layout targets')
   compare(snapshot,true,targets)
  end
  for _,snapshot in case.groupColorMutations or{}do
   local tableBox=tree.NodeBoxes[nodes.ancestor];local group=tree.NodeBoxes[nodes.target]
   local retainedLayers={}
   for _,entry in tableBox.TableGrid.Entries do retainedLayers[entry.Cell]=table.clone(entry.Cell.ColumnBackgrounds or{})end
   nodes.target.Attributes.style='background:'..snapshot.value
   local before=allocations
   local changed,relayout=tree:RefreshDOMStyles({[nodes.target]=true})
   assert(changed and not relayout and allocations==before,'Group color/alpha paints without layout or GUI replacement')
   assert(group.Gui.BackgroundTransparency==1,'Row-group color never paints a second layer over spacing or empty space')
   for cell,layers in retainedLayers do
    assert(#layers==#cell.ColumnBackgrounds,'Background source layer count remains stable')
    for i,gui in layers do
     assert(gui==cell.ColumnBackgrounds[i]and not gui.Destroyed,'Source background GUI remains retained')
     if gui.Name=='RowGroupBackground'then
      assert(gui.BackgroundColor3==Color3.fromRGB(snapshot.color[1],snapshot.color[2],snapshot.color[3])and math.abs(gui.BackgroundTransparency-(1-snapshot.color[4]))<.0001,'Retained row-group color/alpha matches native source')
     end
    end
   end
   compare(snapshot,true,{})
  end
 end
 print('Quirks layout: '..#fixture.cases..' native scenes, repeated resize / '..checks..' mounted x/y/width/height boxes; retained GUIs and unchanged-pass reuse passed')
end
