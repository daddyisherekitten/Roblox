--!strict
--!optimize 2
local WorkContext=require(script.Parent.Parent.WorkContext)
-- Immutable geometry snapshot. Pointer queries never rasterize or read GPU pixels.
local Matrix=require(script.Parent.Matrix)
local Geometry=require(script.Parent.Geometry)
local Curves=require(script.Parent.Curves)
local Dashes=require(script.Parent.Dashes)
local Hit={}
local function include(bounds: any,points: any): any
 for _,p in points do
  if not bounds then bounds={p[1],p[2],p[1],p[2]}
  else bounds[1]=math.min(bounds[1],p[1]);bounds[2]=math.min(bounds[2],p[2]);bounds[3]=math.max(bounds[3],p[1]);bounds[4]=math.max(bounds[4],p[2]) end
 end
 return bounds
end
local function outside(bounds: any,x: number,y: number): boolean
 return bounds~=nil and (x<bounds[1]-1e-8 or y<bounds[2]-1e-8 or x>bounds[3]+1e-8 or y>bounds[4]+1e-8)
end
function Hit.contains(contours: any,x: number,y: number,rule: string?): boolean
 local winding=0
 for _,points in contours do
  if #points<3 then continue end
  for i,a in points do
   local b=points[i%#points+1];local dx,dy=b[1]-a[1],b[2]-a[2]
   local cross=(x-a[1])*dy-(y-a[2])*dx
   if math.abs(cross)<1e-8 and x>=math.min(a[1],b[1])-1e-8 and x<=math.max(a[1],b[1])+1e-8 and y>=math.min(a[2],b[2])-1e-8 and y<=math.max(a[2],b[2])+1e-8 then return true end
   if y>=math.min(a[2],b[2]) and y<math.max(a[2],b[2]) and x<a[1]+(y-a[2])*dx/dy then winding+=if dy>0 then 1 else -1 end
  end
 end
 return if rule=='evenodd' then winding%2~=0 else winding~=0
end
local function inClip(clip: any,x: number,y: number): boolean
 if not clip then return true end
 if x<clip.X or y<clip.Y or x>clip.X+clip.Width or y>clip.Y+clip.Height then return false end
 for _,p in clip.Polygons or {} do if not Hit.contains({p},x,y) then return false end end
 return true
end
function Hit.prepare(scene: any,scale: number?): any
 scale=scale or 1;local cache={};local compile
 compile=function(items: any,depth: number,silhouette: boolean?): any
  assert(depth<=32,'SVG hit-test nesting budget exceeded')
  local out={}
  for _,s in items do
   WorkContext.checkpoint()
   local item={Source=s,Clip=s.Clip,Mode=(s.PointerEvents or 'visiblePainted'):lower(),Hidden=s.Hidden}
   if s.ClipPath then
    local clip=s.ClipPath
    if not cache[clip] then cache[clip]=compile(clip.RenderTree or clip.Shapes,depth+1,true) end
    item.ClipPath=cache[clip]
   end
   if s.Children then
    item.Children=compile(s.Children,depth+1,silhouette)
    for _,child in item.Children do
     local b=child.Bounds
     if b then item.Bounds=include(item.Bounds,{{b[1],b[2]},{b[3],b[4]}}) end
    end
   else
    local g,t=s.Geometry,s.Transform
    if not g or not t or Matrix.determinant(t)==0 then continue end
    local detail=scale*Matrix.scale(t)
    local parts=if g.Subpaths then Curves.flatten(g.Subpaths,detail) else {{Points=Geometry.contour(g,detail),Closed=g.Closed}}
    item.Fill={};item.Stroke={};item.PaintedFill=s.Fill~=nil;item.PaintedStroke=s.Stroke~=nil;item.Image=s.ImageBox~=nil
    local all={}
    for _,part in parts do
     if g.Kind~='line' then table.insert(item.Fill,Matrix.polygon(t,part.Points)) end
     for _,p in part.Points do table.insert(all,p) end
    end
    if #all>0 then item.Box=Matrix.rectangle(t,Matrix.bounds(all)) end
    local st,sw,ss=t,s.StrokeWidth or 1,detail
    local da,offset=s.DashArray,s.DashOffset
    if s.NonScalingStroke then
     st=Matrix.identity();sw/=scale;ss=scale
     local mapped={};for _,part in parts do table.insert(mapped,{Points=Matrix.polygon(t,part.Points),Closed=part.Closed}) end;parts=mapped
     local function adjust(e) return {Value=e.Value/(if not e.Percent and g.PathLength~=nil then 1 else scale),Percent=e.Percent} end
     if da then local values={};for _,v in da do table.insert(values,adjust(v)) end;da=values end
     if offset then offset=adjust(offset) end
    end
    local mode=item.Mode
    local painted=mode=='auto' or mode=='visiblepainted' or mode=='painted'
    local needsStroke=not silhouette and mode~='none' and mode~='fill' and mode~='visiblefill' and mode~='bounding-box' and (not painted or item.PaintedStroke)
    if sw>0 and needsStroke then
     parts=Dashes.split(parts,da,g.PathLength,nil,offset,s.LineCap)
     for _,part in parts do for _,p in Geometry.stroke(part.Points,part.Closed,sw,{LineCap=s.LineCap,LineJoin=s.LineJoin,MiterLimit=s.MiterLimit,Scale=ss,Direction=part.Direction}) do table.insert(item.Stroke,Matrix.polygon(st,p)) end end
    end
    if item.Box then item.Bounds=include(item.Bounds,item.Box) end
    for _,p in item.Fill do item.Bounds=include(item.Bounds,p) end
    for _,p in item.Stroke do item.Bounds=include(item.Bounds,p) end
   end
   table.insert(out,item)
  end
  return out
 end
 return {Items=compile(scene.RenderTree or scene.Shapes,0),Width=scene.Width,Height=scene.Height}
end
local function find(items: any,x: number,y: number,silhouette: boolean?): any
 for i=#items,1,-1 do
  local item=items[i];local s=item.Source
  -- Reject distant shapes/groups before traversing clips and detailed paths.
  -- The bounds include generated stroke joins/caps and non-scaling strokes.
  if outside(item.Bounds,x,y) then continue end
  if not inClip(item.Clip,x,y) then continue end
  if item.ClipPath and not find(item.ClipPath,x,y,true) then continue end
  if item.Children then local found=find(item.Children,x,y,silhouette);if found then return found end;continue end
  local mode=if silhouette then 'visiblefill' else item.Mode
  if mode=='none' or ((mode:sub(1,7)=='visible' or mode=='auto') and item.Hidden) then continue end
  if mode=='bounding-box' then if item.Box and Hit.contains({item.Box},x,y) then return s end;continue end
  local painted=mode=='auto' or mode=='visiblepainted' or mode=='painted'
  if item.Image then
   if Hit.contains(item.Fill,x,y) then
    -- Image opacity is irrelevant; only the original raster's alpha is used.
    if not painted or not (s.Fill and s.Fill.Pixels) or s.Fill.Sample(s.Fill,x,y)[4]>0 then return s end
   end
   continue
  end
  local fill=mode~='stroke' and mode~='visiblestroke' and (not painted or item.PaintedFill)
  local stroke=not silhouette and mode~='fill' and mode~='visiblefill' and (not painted or item.PaintedStroke)
  if fill and Hit.contains(item.Fill,x,y,s.FillRule) then return s end
  if stroke then for _,p in item.Stroke do if Hit.contains({p},x,y) then return s end end end
 end
 return nil
end
function Hit.query(snapshot: any,x: number,y: number): any
 if not snapshot or x~=x or y~=y or x<0 or y<0 or x>snapshot.Width or y>snapshot.Height then return nil end
 return find(snapshot.Items,x,y)
end
return Hit
