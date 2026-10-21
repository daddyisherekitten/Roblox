--!strict
-- Retained, budgeted paint groups for mix-blend-mode. Layout/DOM owners and
-- event geometry remain native; only an affected composition group is rastered.
local Queue=require(script.Parent.Parent.SVG.RenderQueue)
local Pixels=require(script.Parent.PerspectivePixels)
local Plans=require(script.Parent.VisualEffectPixels)
local PaintLayer=require(script.Parent.PaintLayer)
local WorkContext=require(script.Parent.Parent.WorkContext)
local Groups={}
function Groups.new(diagnostic: any,createImage: any?,taskAPI: any?,host: any?): any
 local entries={};local queue;local alive=true;local sequence=0
 local owners=setmetatable({},{__mode='k'});local contexts=setmetatable({},{__mode='k'})
 local function context(style)return table.concat({style.MixBlendMode or 'normal',style.Isolation or 'auto',tostring(style.Opacity),tostring(style.Position),tostring(style.ZIndex)},':')end
 local runtime=taskAPI or task or {defer=function(fn)fn()end,wait=function()end}
 if host and host.SetAttribute then host:SetAttribute('CompositeVisibleReady',true)end
 local function restore(entry)
  for _,saved in entry.Hidden or {}do
   if saved.Object[saved.Key]==saved.Hidden then saved.Object[saved.Key]=saved.Value end
  end
  entry.Hidden=nil
 end
 local function hide(entry)
  restore(entry)
  local root=entry.Root;local saved={};entry.Hidden=saved
  local function cover(object,key,value)
   if object then table.insert(saved,{Object=object,Key=key,Value=object[key],Hidden=value});object[key]=value end
  end
  cover(root.Gui,'BackgroundTransparency',1)
  local function paints(gui,depth)
   if not gui or gui==entry.Gui or depth>64 then return end
   if gui.IsA then
    if gui:IsA('GuiObject')then cover(gui,'BackgroundTransparency',1)end
    if gui:IsA('ImageLabel')or gui:IsA('ImageButton')then cover(gui,'ImageTransparency',1)end
    if gui:IsA('TextLabel')or gui:IsA('TextButton')or gui:IsA('TextBox')then cover(gui,'TextTransparency',1);cover(gui,'TextStrokeTransparency',1)end
    if gui:IsA('UIStroke')then cover(gui,'Transparency',1)end
    if gui:IsA('UIShadow')then cover(gui,'Enabled',false)end
   end
   if gui.GetChildren then for _,child in gui:GetChildren()do paints(child,depth+1)end end
  end
  -- Transparent native surfaces still participate in hit testing, focus and
  -- selection. Hiding their GuiObject would remove those input targets.
  if root.Gui.GetChildren then for _,child in root.Gui:GetChildren()do paints(child,0)end
  else for _,child in root.Children or {}do
   if child.Kind=='Words'then for _,word in child.Items or {}do paints(word.TextGui or word.Gui,0)end
   else paints(child.Gui,0)end
  end end
 end
 local function getQueue()
  if queue then return queue end
  local asset={CreateEditableImage=function(_,options)
   return if createImage then createImage(options.Size)else game:GetService('AssetService'):CreateEditableImage(options)
  end}
  local raster={render=function(scene,_,_,check)
   if not check()then return nil end
   local work=WorkContext.new(4,{Task=runtime,Alive=function()return alive end})
   local ok,result=pcall(function()return work:Run(function()
    local planes=Pixels.scene(scene.Node)
    return Pixels.renderScene(planes,scene.Bounds,{Width=scene.Width,Height=scene.Height})
   end)end)
   work:Finish();if not ok then error(result,0)end
   return if check()then result else nil
  end}
  queue=Queue.new(asset,raster,runtime,{MaxBytes=2*1048576,CacheBytes=2*1048576,CacheEntries=24,YieldSeconds=.004,Report=function(message)diagnostic('mix-blend-mode: '..message)end,
   VisibleChanged=function(ready)if alive and host and host.SetAttribute then host:SetAttribute('CompositeVisibleReady',ready)end end})
  return queue
 end
 local function clear(root)
  local entry=entries[root];if not entry then return end
  restore(entry);if queue then queue:Remove(root)end
  if entry.Gui then entry.Gui:Destroy()end
  root.CompositeSurface=nil;entries[root]=nil
 end
 local renderer={}
 function renderer:Prepare(onlyStyles: any?)
  local affected={}
  if onlyStyles then for style in onlyStyles do local root=owners[style];if root then affected[root]=true end end end
  -- Restore before the native painter writes new author values. A newly
  -- transparent author color is indistinguishable from our hidden sentinel
  -- afterwards and must never be replaced by an old opaque saved value.
  for root,entry in entries do if not onlyStyles or affected[root]then restore(entry)end end
 end
 local warned=setmetatable({},{__mode='k'})
 local function supported(root)
  local count=0
  local function visit(box,depth)
   count+=1;if count>64 or depth>64 then return false end
   local item=box.ImageItem
   if item and not item.CanvasSurface then return false end
   if box.Scene3DSurface or #(box.Style.Transform or {})>0 or box.Style.OffsetPath then return false end
   for _,run in box.Children or {}do
    if run.Kind=='Words'then for _,word in run.Items or {}do
     if word.Kind=='Image' and not word.CanvasSurface then return false end
    end end
    if not visit(run,depth+1)then return false end
   end
   return true
  end
  return visit(root,0)
 end
 function renderer:Update(tree: any,onlyStyles: any?)
  if not alive then return end
  local targets={};local groups={};local touched={};local stack={}
  local partial=onlyStyles~=nil
  if onlyStyles then for style in onlyStyles do
   if contexts[style]~=context(style)then partial=false;break end
   local owner=owners[style];if owner then groups[owner]=true;touched[owner]=true end
  end end
  local function visit(box,depth)
   if depth>64 then return end
   local style=box.Style
   if not style then return end
   contexts[style]=context(style)
   table.insert(stack,box)
   if onlyStyles and onlyStyles[style]then for _,ancestor in stack do touched[ancestor]=true end end
   if not style.Hidden and style.MixBlendMode and style.MixBlendMode~='normal'then
    local root=tree
    for index=#stack-1,1,-1 do
     local candidate=stack[index];local s=candidate.Style
     if s.Isolation=='isolate' or (s.Opacity or 1)<1 or s.ZIndex~=nil and s.Position~='static' then root=candidate;break end
    end
    targets[root]=true
   end
   for _,child in box.Children or {}do visit(child,depth+1)end
   table.remove(stack)
  end
  if not partial then visit(tree,0)end
  -- An outer group already composites nested isolated groups. Avoid drawing
  -- two replacement surfaces over the same native content.
  local function select(box,covered,depth)
   if depth>64 then return end
   local chosen=not covered and targets[box]
   if chosen then groups[box]=true end
   local owner=covered or (if chosen then box else nil)
   if owner and box.Style then owners[box.Style]=owner end
   for _,child in box.Children or {}do select(child,owner,depth+1)end
  end
  if not partial then
   table.clear(owners);select(tree,nil,0)
   for root in entries do if not groups[root]then clear(root)end end
  end
  for root in groups do
   if onlyStyles and not touched[root]then continue end
   if not root.OuterWidth or root.OuterWidth<=0 or not root.OuterHeight or root.OuterHeight<=0 then clear(root);continue end
   if not supported(root)then
    clear(root)
    if not warned[root]then warned[root]=true;diagnostic('mix-blend-mode: native image/control pixels or a group over 64 boxes cannot be composed; retaining native content')end
    continue
   end
   local node=Pixels.flat(root,true);local key=Pixels.sceneKey(node)
   local entry=entries[root]
   if not entry then sequence+=1;entry={Root=root,Identity=sequence};entries[root]=entry end
   if entry.Ready then hide(entry)end
   if key==entry.RequestKey then continue end
   entry.RequestKey=key
   local captured=Pixels.snapshot(node);local bounds={Left=0,Top=0,Width=root.OuterWidth,Height=root.OuterHeight}
   local plan=Plans.plan(bounds.Width,bounds.Height)
   getQueue():Request(root,tostring(entry.Identity)..':'..key,function()
    return {Width=plan.Width,Height=plan.Height,Node=captured,Bounds=bounds}
   end,function(image,scene)
    if not alive or entries[root]~=entry then return end
    if not entry.Gui then entry.Gui=PaintLayer.create(root.Factory,'ImageLabel',root.Gui,{Name='CSSBlendSurface',BackgroundTransparency=1,ScaleType=Enum.ScaleType.Stretch,ZIndex=100004})end
    entry.Gui.ImageContent=Content.fromObject(image);entry.Gui.Position=UDim2.fromOffset(0,0)
    entry.Gui.Size=UDim2.fromOffset(scene.Bounds.Width,scene.Bounds.Height)
    entry.Gui.ImageTransparency=if root.Style.Visibility=='hidden'then 1 else 0
    entry.Ready=true;root.CompositeSurface=entry.Gui;hide(entry)
   end,true)
  end
 end
 function renderer:Remove(root)clear(root)end
 function renderer:Destroy()
  if not alive then return end;alive=false
  for root in entries do clear(root)end
  if queue then queue:Destroy()end
  table.clear(owners);table.clear(contexts)
 end
 function renderer:Stats()return queue and queue.Stats end
 return renderer
end
return Groups
