--!strict
local WorkContext=require(script.Parent.Parent.WorkContext)
local Embedded=require(script.Parent.Parent.SVG.Embedded)
local Queue=require(script.Parent.Parent.SVG.RenderQueue)
local Raster=require(script.Parent.Parent.SVG.Raster)
local Hit=require(script.Parent.Parent.SVG.HitTest)
local Style=require(script.Parent.Parent.SVG.Style)
local ImageColors=require(script.Parent.ImageFilterPixels)
local ImageEffects=require(script.Parent.ImageEffectPixels)
local ImageBox=require(script.Parent.ImageBox)
local SVGImages={}
function SVGImages.start(page: any,tree: any,diagnostic: any,services: any?): any?
 local api=if services and services.Asset then services.Asset else game:GetService('AssetService')
 local taskAPI=if services and services.Task then services.Task else task
 local prewarmLimit=if services and services.PrewarmStates~=nil then services.PrewarmStates else 16
 local queue
 local function publish(stats)
  if page.Alive then
   page.Root:SetAttribute('SVGRasters',stats.Rasters);page.Root:SetAttribute('SVGUploads',stats.Uploads)
   page.Root:SetAttribute('SVGPrewarmTotal',stats.WarmQueued);page.Root:SetAttribute('SVGPrewarmDone',stats.WarmCompleted)
   page.Root:SetAttribute('SVGPrewarmPending',queue:WarmPending());page.Root:SetAttribute('SVGPrewarmCancelled',stats.WarmCancelled)
   page.Root:SetAttribute('SVGReady',queue:Pending()==0)
  end
 end
 -- Keep the source SVG work/cache unmodified; HTML filters apply once to the
 -- complete raster before its pixels enter the queue's output cache/upload.
 local imageRaster=table.clone(Raster)
 imageRaster.render=function(scene,states,width,checkpoint,work)
  local effect=scene.HTMLImageEffect
  if effect then
   local source=effect.Source
   local scale=math.min(1,1024/source.Width,1024/source.Height)
   local sw=math.max(1,math.floor(source.Width*scale))
   local bytes=Raster.render(source,states,sw,checkpoint,work)
   if not bytes then return nil end
   return ImageEffects.render(bytes,Vector2.new(sw,math.round(source.Height*sw/source.Width)),effect,checkpoint)
  end
  local bytes=Raster.render(scene,states,width,checkpoint,work)
  if bytes and scene.HTMLImageFilter then return ImageColors.render(bytes,scene.HTMLImageFilter,checkpoint) end
  return bytes
 end
 queue=Queue.new(api,imageRaster,taskAPI,{LoadingWork=page.LoadingWork,CacheBytes=services and services.CacheBytes,CacheEntries=services and services.CacheEntries,YieldSeconds=if services and services.WorkBudgetMS~=nil then services.WorkBudgetMS/1000 else nil,Report=diagnostic,VisibleChanged=function(ready)
  if page.Alive then page.Root:SetAttribute('SVGVisibleReady',ready) end
 end,Changed=function(stats)
  publish(stats)
 end})
 page.SVGStats=queue.Stats
 page.Root:SetAttribute("SVGReady",true)
 page.Root:SetAttribute("SVGVisibleReady",true)
 page.Root:SetAttribute('SVGPrewarmTotal',0);page.Root:SetAttribute('SVGPrewarmDone',0);page.Root:SetAttribute('SVGPrewarmPending',0);page.Root:SetAttribute('SVGPrewarmCancelled',0)
 local entries={};local disposed=false;local ownerSequence=0
 tree.MousePosition=function(p)
  local inset=if services and services.Inset then services.Inset else game:GetService('GuiService'):GetGuiInset()
  return Vector2.new(p.X-inset.X,p.Y-inset.Y)
 end
 local function signature(n)
  WorkContext.checkpoint()
  local keys={};for k in n.Attributes or {} do table.insert(keys,k) end;table.sort(keys)
  local s=(n.Name or n.Kind)..':'..(n.Text or '')
  for _,k in keys do local v=n.Attributes[k];s..='|'..k..'='..#v..':'..v end
  for _,c in n.Children do s..='['..signature(c)..']' end;return s
 end
 local function addItem(item)
  if disposed or entries[item] then return end
  ownerSequence+=1
  local doc=Embedded.document(item.SVG,item.SVGExternal,item.SVGDeclarations)
  if not doc.Root.Attributes.color and item.Style.Color then local c=item.Style.Color;doc.Root.Attributes.color=string.format('rgb(%d,%d,%d)',math.round(c.R*255),math.round(c.G*255),math.round(c.B*255)) end
  doc.Root.Attributes['font-size']=doc.Root.Attributes['font-size'] or tostring(item.Style.FontSize or 16)
  local state={Item=item,Document=doc,Base=signature(doc),States={},Keys={},Rules=Style.collect(doc,function(code,value) diagnostic('SVG '..code..': '..tostring(value)) end)}
  state.Base=tostring(ownerSequence)..':'..state.Base
  state.VisualKey=Style.stateKey(doc,state.Rules,'hover',{})
  state.Keys[false]=state.VisualKey
  entries[item]=state
  local function externalKey(captured)
   if not item.SVGDeclarations then return ''end
   local revision=tree.AnimationStyleRevision or 0;local hover=captured and captured.hover
   if state.CSSRevision==revision and state.CSSHover==hover then return state.CSSKey end
   local parts={}
   local function visit(node)
    if node.ExternalDeclarations then local match=node.ExternalDeclarations(captured);for _,list in {match.Normal,match.Important}do for _,entry in list do table.insert(parts,entry.Name..':'..#entry.Value..':'..entry.Value..':'..tostring(entry.Important))end end end
    for _,child in node.Children do visit(child)end
   end;visit(doc.Root)
   state.CSSRevision,state.CSSHover,state.CSSKey=revision,hover,table.concat(parts,';');return state.CSSKey
  end
  state.ExternalKey=externalKey
  local function build(captured,w,h,filter,effect)
   local scene,errors=Embedded.build(doc,w,h,captured)
   if effect then
    scene.HTMLImageEffect={Style=effect.Style,Plan=effect.Plan,Source=table.clone(scene)}
    scene.Width,scene.Height=effect.Plan.Width,effect.Plan.Height
   elseif filter and #filter.Steps>0 then scene.HTMLImageFilter=filter end
   if not state.Reported then for _,d in errors do diagnostic('SVG '..d.Code..': '..tostring(d.Value)) end;state.Reported=true end
   return scene
  end
  local function scheduleWarm(scene,w,h)
   local filter,effect=scene.HTMLImageFilter,scene.HTMLImageEffect
   local filterKey=if effect then effect.Plan.Key elseif filter then filter.Key else 'none'
   local sizeKey=tostring(w)..'x'..tostring(h)..':'..filterKey
   local warmKey=sizeKey..':'..tostring(if item.SVGDeclarations then tree.AnimationStyleRevision or 0 else 0)
   if prewarmLimit<=0 or state.WarmSize==warmKey then return end
   state.WarmSize=warmKey
   local variants={};local visualKeys={}
   local function add(node,states)
    local visual=Style.stateKey(state.Document,state.Rules,'hover',states)
    if node then state.Keys[node]=visual end
    local cssKey=externalKey(states);local combined=visual..':'..cssKey
    if combined~=state.VisualKey..':'..(state.PaintedCSSKey or '')and not visualKeys[combined]then visualKeys[combined]=true;table.insert(variants,{Visual=visual,CSSKey=cssKey,States=states})end
   end
   add(nil,{})
   local seen={}
   local function visit(items)
    for _,entry in items or {} do
     local node=entry.SourceNode
     if node and not seen[node] and not entry.Hidden and (entry.PointerEvents or 'visiblePainted'):lower()~='none' then
      seen[node]=true;add(node,{hover=node})
     end
     if entry.Children then visit(entry.Children) end
     if entry.Markers then visit(entry.Markers) end
    end
   end
   visit(scene.RenderTree or scene.Shapes)
   local scale=math.min(1,1024/w,1024/h);local rw=if effect then effect.Plan.Width else math.max(1,math.floor(w*scale));local rh=if effect then effect.Plan.Height else math.max(1,math.round(h*rw/w))
   -- The displayed frame is admitted immediately after this callback.
   local capacity=math.max(0,queue:WarmCapacity(item,rw*rh*4)-1)
   local limit=math.min(prewarmLimit,capacity,#variants)
   for i=1,limit do
    local variant=variants[i];local captured=table.clone(variant.States)
    local key=state.Base..':'..sizeKey..':'..variant.Visual..':'..variant.CSSKey
    queue:Warm(item,key,function() return build(captured,w,h,filter,effect) end,rw*rh*4)
   end
   if limit>0 then page.Root:SetAttribute('SVGReady',false);publish(queue.Stats) end
  end
  item.UpdateSVG=function()
   if disposed or not page.Alive or entries[item]~=state then return end
   local w,h=math.round(item.SVGRasterWidth or item.ContentWidth or 0),math.round(item.SVGRasterHeight or item.ContentHeight or 0)
   if w<=0 or h<=0 then
    queue:Remove(item);state.Snapshot=nil;state.Size=nil;state.WarmSize=nil;state.LastSize=nil
    item.SVGEffectReady=nil;if item.SVGEffectGui then item.SVGEffectGui.Visible=false end
    return
   end
   local sizeKey=tostring(w)..'x'..tostring(h)
   if state.LastSize and state.LastSize~=sizeKey then queue:Reset(item);state.WarmSize=nil end
   state.LastSize=sizeKey
   local filter=item.Style.Filter
   local effect=if ImageEffects.needed(item.Style)then ImageEffects.capture(item,Vector2.new(w,h))else nil
   local filterKey=if effect then effect.Plan.Key elseif filter then filter.Key else 'none'
   if state.LastFilter~=filterKey then queue:CancelWarm(item);state.WarmSize=nil;state.LastFilter=filterKey end
   local captured=table.clone(state.States)
   local cssKey=externalKey(captured);state.PaintedCSSKey=cssKey
   local key=state.Base..':'..w..'x'..h..':'..filterKey..':'..state.VisualKey..':'..cssKey
   local requested=queue:Request(item,key,function()
    return build(captured,w,h,filter,effect)
   end,function(image,scene)
    if disposed or not page.Alive or entries[item]~=state then return end
    local painted=scene.HTMLImageEffect
    if painted then
     if not item.SVGEffectGui then
      item.SVGEffectGui=item.ImageFactory.create('ImageLabel',item.BoxGui,{Name='SVGImageEffects',BackgroundTransparency=1,Visible=false,ScaleType=Enum.ScaleType.Stretch})
     end
     item.SVGEffectGui.ImageContent=Content.fromObject(image)
     item.SVGEffectReady,item.SVGEffectPlan=true,painted.Plan
    else
     item.ImageGui.ImageContent=Content.fromObject(image);item.SVGEffectReady,item.SVGEffectPlan=nil,nil
    end
    if item.ImageFactory then ImageBox.arrangeSVGEffect(item);ImageBox.updateFallback(item)end
    local source=if painted then painted.Source else scene
    state.Scene=source;state.Size={w,h}
    if not source.EmbeddedSnapshot then source.EmbeddedSnapshot=Hit.prepare(source,1);queue.Stats.HitBuilds+=1 end
    scene.EmbeddedSnapshot=source.EmbeddedSnapshot
    state.Snapshot=scene.EmbeddedSnapshot;scheduleWarm(scene,w,h)
   end,true)
   if requested then page.Root:SetAttribute('SVGReady',false) end
  end
 end
 function queue:AddItems(items)
  for _,item in items do addItem(item) end
 end
 function queue:RemoveItems(items)
  for _,item in items do
   local state=entries[item]
   if state then
    entries[item]=nil;item.UpdateSVG=nil;self:Remove(item)
    item.SVGEffectReady,item.SVGEffectPlan=nil,nil
    if item.SVGEffectGui then item.SVGEffectGui:Destroy();item.SVGEffectGui=nil end
   end
  end
 end
 queue:AddItems(tree.SVGItems or {})
 local styleChanged=function(affected)
  local ancestors={}
  local function parent(node)return if node.Kind=='ShadowRoot'then node.Host else node.Parent end
  if affected then for node in affected do
   while node and not ancestors[node]do ancestors[node]=true;node=parent(node)end
  end end
  local function relevant(item)
   if not affected then return true end
   local node=item.Node or item.SVG
   if ancestors[node]then return true end
   while node do if affected[node]then return true end;node=parent(node)end
   return false
  end
  for item,state in entries do
   if item.SVGDeclarations and relevant(item)and state.ExternalKey(state.States)~=state.PaintedCSSKey then item.UpdateSVG()end
  end
 end
 tree.SVGStyleChanged=styleChanged
 tree.SVGCursor=function(node,position)
  local selected
  if node then for item,state in entries do if item.Node==node or item.SVG==node then selected=state;break end end end
  local cursor
  for _,state in entries do
   local hover
   if state==selected and state.Snapshot and state.Size then
    local gui=state.Item.ImageGui;local p,size=gui.AbsolutePosition,gui.AbsoluteSize
    if size.X>0 and size.Y>0 then
     local x,y=(position.X-p.X)*state.Size[1]/size.X,(position.Y-p.Y)*state.Size[2]/size.Y
     if x>=0 and y>=0 and x<state.Size[1] and y<state.Size[2] then local shape=Hit.query(state.Snapshot,x,y);hover=shape and shape.SourceNode end
    end
    local entry=hover and state.Scene.Nodes[hover];cursor=entry and entry.Node.Attributes.cursor
    if cursor=='auto' or cursor==nil then local n=hover;while n do if n.Name=='a' and n.Attributes.href then cursor='pointer';break end;n=n.Parent end end
   end
   if hover~=state.States.hover then
    local after=table.clone(state.States);after.hover=hover
    local identity=hover or false
    local key=state.Keys[identity]
    if key==nil then key=Style.stateKey(state.Document,state.Rules,'hover',after);state.Keys[identity]=key end
    local visual=key~=state.VisualKey or(state.Item.SVGDeclarations and state.ExternalKey(after)~=state.PaintedCSSKey);state.VisualKey=key
    state.States.hover=hover
    if visual then state.Item.UpdateSVG() end
   end
  end
  return if cursor and cursor~='auto' then cursor else nil
 end
 local function cleanup()
  if disposed then return end;disposed=true;tree.SVGCursor=nil;tree.MousePosition=nil
  if tree.SVGStyleChanged==styleChanged then tree.SVGStyleChanged=nil end
  for item in entries do
   item.UpdateSVG=nil;item.SVGEffectReady,item.SVGEffectPlan=nil,nil
   -- Page teardown owns GUI destruction; a removed item is released above.
   if item.SVGEffectGui then item.SVGEffectGui.Visible=false end
  end
  queue:Destroy();table.clear(entries)
 end
 page:AddCleanup(cleanup)
 return queue
end
return SVGImages
