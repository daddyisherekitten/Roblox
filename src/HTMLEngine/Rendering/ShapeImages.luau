--!strict
-- Page-local source pixels, loaded only for actual floating URL shapes. No GPU
-- textures are allocated; unreadable/missing sources fall back to a normal float.
local ShapeImage=require(script.Parent.Parent.Layout.ShapeImage)
local WorkBudget=require(script.Parent.WorkBudget)
local SVGSizing=require(script.Parent.Parent.SVG.Sizing)
local ShapeImages={}
local MAX_BYTES=8*1024*1024
local MAX_SOURCES=32

function ShapeImages.start(page: any,tree: any,diagnostic: (string)->(),changed: ()->(),services: any?): any
 local taskAPI=if services and services.Task then services.Task else task
 local cache,attached,rejected={}, {},{}
 local bytes,sources=0,0
 local disposed=false
 local budget=WorkBudget.new(if services and services.WorkBudgetMS~=nil then services.WorkBudgetMS else 4,taskAPI)
 local function check()
  if disposed or not page.Alive then error('Shape image request cancelled') end
  if budget then budget:Checkpoint() end
 end
 local function load(source)
  local svg=page.ResolveSVG and page.ResolveSVG(source)
  if svg then
   local embedded=if services and services.Embedded then services.Embedded else require(script.Parent.Parent.SVG.Embedded)
   local raster=if services and services.Raster then services.Raster else require(script.Parent.Parent.SVG.Raster)
   local w,h=SVGSizing.source(svg)
   assert(w>0 and h>0 and w<math.huge and h<math.huge,'Invalid SVG shape dimensions')
   local scale=math.min(1,1024/w,1024/h);w,h=math.max(1,math.round(w*scale)),math.max(1,math.round(h*scale))
   check()
   local scene,errors=embedded.build(embedded.document(svg,true),w,h)
   for _,entry in errors or {} do diagnostic('SVG shape '..entry.Code..': '..tostring(entry.Value)) end
   local rgba,rasterHeight=raster.render(scene,nil,w,function()check();return true end)
   assert(rgba,'SVG shape rasterization failed')
   return ShapeImage.alpha(rgba,w,rasterHeight,check),w,rasterHeight
  end
  local uri=page.ResolveImage and page.ResolveImage(source)
  assert(uri,'No image mapping for shape-outside: '..source)
  local asset=if services and services.Asset then services.Asset else game:GetService('AssetService')
  local editable
  local ok,result,w,h=pcall(function()
   editable=asset:CreateEditableImageAsync(Content.fromUri(uri));assert(editable,'EditableImage allocation unavailable')
   local size=editable.Size
   assert(size.X>0 and size.Y>0 and size.X<=1024 and size.Y<=1024,'Shape image exceeds 1024x1024')
   return editable:ReadPixelsBuffer(Vector2.new(0,0),size),size.X,size.Y
  end)
  if editable then editable:Destroy() end
  if not ok then error(result) end
  check()
  return ShapeImage.alpha(result,w,h,check),w,h
 end
 local function provider(source: string,threshold: number): any?
  if disposed or not page.Alive then return nil end
  local entry=cache[source]
  if not entry then
   if sources>=MAX_SOURCES then
    if not rejected[source] then rejected[source]=true;diagnostic('Shape image source budget exceeded; rectangular float retained') end
    return nil
   end
   sources+=1;entry={Variants={},Order={}};cache[source]=entry
  end
  if entry.Failed then return nil end
  local key=tostring(threshold)
  local variant=entry.Variants[key]
  if variant then return variant.Data end
  local pending=0;for _,v in entry.Variants do if not v.Data then pending+=1 end end
  if pending>=4 then return nil end
  variant={};entry.Variants[key]=variant
  taskAPI.defer(function()
   if disposed or not page.Alive then return end
   local ok,data=pcall(function()
    -- Requests are serialized by the source owner while a yielding load runs.
    while entry.Loading do taskAPI.wait();check() end
    if entry.Failed then return nil end
    if not entry.Alpha then
     entry.Loading=true
     local loaded,alpha,w,h=pcall(load,source)
     entry.Loading=false
     if not loaded then error(alpha) end
     check();assert(bytes+buffer.len(alpha)<=MAX_BYTES,'Shape image pixel budget exceeded')
     bytes+=buffer.len(alpha);entry.Alpha,entry.Width,entry.Height=alpha,w,h
    end
    return ShapeImage.rows(entry.Alpha,entry.Width,entry.Height,threshold,check)
   end)
   if disposed or not page.Alive then return end
   if ok and data then
    variant.Data=data;table.insert(entry.Order,key)
    -- Bound threshold variants (e.g. animated threshold) without duplicating pixels.
    while #entry.Order>4 do entry.Variants[table.remove(entry.Order,1)]=nil end
    changed()
   elseif not ok then
    entry.Failed=true;diagnostic('Shape image unavailable: '..source..'; rectangular float retained ('..tostring(data)..')')
   end
  end)
  return nil
 end
 local function measured(source: string,threshold: number): any?
  if disposed or not page.Alive then return nil end
  local entry=cache[source];local variant=entry and not entry.Failed and entry.Variants[tostring(threshold)]
  return if variant then variant.Data else nil
 end
 local function attach(box)
  if attached[box] then return end
  attached[box]=true;box.ShapeImageProvider,box.ShapeImageMeasurement=provider,measured
  for _,child in box.AllChildren or box.Children or {} do if child.Kind~='Words' then attach(child) end end
 end
 attach(tree)
 for _,box in tree.NodeBoxes or {} do attach(box) end
 local function cleanup()
  if disposed then return end;disposed=true
  for box in attached do box.ShapeImageProvider,box.ShapeImageMeasurement=nil,nil end
  table.clear(attached);table.clear(cache);table.clear(rejected)
 end
 page:AddCleanup(cleanup)
 return {Get=provider,Destroy=cleanup}
end
return ShapeImages
