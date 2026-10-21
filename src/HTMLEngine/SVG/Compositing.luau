--!strict
--!optimize 2
local WorkContext=require(script.Parent.Parent.WorkContext)
-- Isolated opacity groups use transient CPU buffers, not extra EditableImages.
local Blend=require(script.Parent.Blend)
local Matrix=require(script.Parent.Matrix)
local Compositing={}
-- CPU-only retained layers belong to their render owner. The weak registry lets
-- abandoned owners be collected while enforcing one shared pixel budget.
local owners=setmetatable({},{__mode='k'})
local clock=0
local ignored={SourceNode=true,SourceId=true,PointerEvents=true,Nodes=true,Probes=true,Caption=true,Diagnostics=true}
local function snapshot(value: any,seen: any,budget: any): any
 if type(value)~='table' then return value end
 if seen[value] then return seen[value] end
 local result={};seen[value]=result
 WorkContext.checkpoint()
 for key,child in value do
  if not ignored[key] and not (key=='Shapes' and value.RenderTree) then
   budget.Fields+=1
   if budget.Fields>262144 or type(key)=='table' then budget.Exceeded=true;return nil end
   result[key]=snapshot(child,seen,budget)
   if budget.Exceeded then return nil end
  end
 end
 return result
end
local function equal(a: any,b: any,seen: any?): boolean
 if a==b then return true end
 if type(a)~='table' or type(b)~='table' then return false end
 seen=seen or {};if seen[a]==b then return true end;seen[a]=b
 WorkContext.checkpoint()
 for key,value in a do
  if not equal(value,b[key],seen) then return false end
 end
 for key in b do
  if not ignored[key] and not (key=='Shapes' and b.RenderTree) and a[key]==nil then return false end
 end
 return true
end
-- Resolved render tables may change between calls; snapshot comparisons detect
-- those edits. Decoded image pixel buffers follow Image's immutable-resource
-- contract: replace the buffer when editing pixels. Pixel bytes and reachable
-- descriptor fields have separate caps; field counts are not exact heap bytes.
function Compositing.createWork(): any
 local work={Retain=true,Retained={},RetainedBytes=0,RetainedFields=0,LayerHits=0,LayerBuilds=0,PartialRenders=0,RepaintPixels=0,Patterns={},PatternBytes=0,PatternDepth=0}
 owners[work]=true;return work
end
function Compositing.releaseWork(work: any)
 work.Retain=false;work.Retained={};work.RetainedBytes=0;work.RetainedFields=0;work.LastFrame=nil;work.Patterns={};work.PatternBytes=0;owners[work]=nil
end
function Compositing.cached(work: any,kind: string,value: any,width: number,height: number,scale: number): any?
 work=work.Owner or work
 if not work.Retain then return nil end
 for _,entry in work.Retained do
  if entry.Kind==kind and entry.Width==width and entry.Height==height and entry.Scale==scale and equal(entry.Value,value) then
   clock+=1;entry.Used=clock;work.LayerHits+=1;return entry
  end
 end
 return nil
end
function Compositing.remember(work: any,kind: string,value: any,bytes: buffer,width: number,scale: number,check: any?): (any?,boolean?)
 work=work.Owner or work
 if not work.Retain then return nil end
 owners[work]=true
 local budget={Fields=0};local description=snapshot(value,{},budget)
 if budget.Exceeded then return nil end
 local height=buffer.len(bytes)/(width*4);local left,top,right,bottom=width,height,-1,-1
 if kind=='frame' then left=0;top=0;right=width-1;bottom=height-1
 else
  for y=0,height-1 do
   if check and not check() then return nil,false end
   if not work.Retain then return nil,false end
   -- Only the outermost occupied pixels can change this row's bounds.
   -- Skip opaque interiors without changing alpha coverage or crop semantics.
   local row=y*width*4;local first=0
   while first<width and buffer.readu8(bytes,row+first*4+3)==0 do first+=1 end
   if first<width then
    local last=width-1
    while last>first and buffer.readu8(bytes,row+last*4+3)==0 do last-=1 end
    left=math.min(left,first);right=math.max(right,last);top=math.min(top,y);bottom=y
   end
  end
 end
 -- Checkpoints may yield to teardown. Publish and evict only after scanning,
 -- so cancelled or released work cannot repopulate a disposed owner's cache.
 if not work.Retain then return nil,false end
 local w,h=math.max(0,right-left+1),math.max(0,bottom-top+1);local size=w*h*4
 if size>8*1024*1024 then return nil end
 local cropped=buffer.create(size)
 for y=0,h-1 do
  WorkContext.checkpoint()
  if not work.Retain then return nil,false end
  buffer.copy(cropped,y*w*4,bytes,((top+y)*width+left)*4,w*4)
 end
 if not work.Retain then return nil,false end
 -- Eviction and admission form one non-yielding commit. Another loader may
 -- have changed the shared cache while this entry's pixels were being copied.
 local function evict(owner: any,index: number)
  local old=table.remove(owner.Retained,index);owner.RetainedBytes-=buffer.len(old.Bytes)
  owner.RetainedFields-=old.Fields
  if owner.LastFrame==old then owner.LastFrame=nil end
 end
 while #work.Retained>=24 or work.RetainedBytes+size>8*1024*1024 or work.RetainedFields+budget.Fields>262144 do
  local oldest=1;for i,entry in work.Retained do if entry.Used<work.Retained[oldest].Used then oldest=i end end
  evict(work,oldest)
 end
 local total,fields=0,0;for owner in owners do total+=owner.RetainedBytes;fields+=owner.RetainedFields end
 while total+size>24*1024*1024 or fields+budget.Fields>1048576 do
  local oldestOwner,oldestIndex,used=nil,nil,math.huge
  for owner in owners do for i,entry in owner.Retained do if entry.Used<used then oldestOwner=owner;oldestIndex=i;used=entry.Used end end end
  if not oldestOwner then break end
  local old=oldestOwner.Retained[oldestIndex]
  total-=buffer.len(old.Bytes);fields-=old.Fields;evict(oldestOwner,oldestIndex)
 end
 clock+=1
 local entry={Kind=kind,Value=description,Fields=budget.Fields,Bytes=cropped,Width=width,Height=height,Scale=scale,Used=clock,Region={X=left,Y=top,Width=w,Height=h}}
 table.insert(work.Retained,entry);work.RetainedBytes+=size;work.RetainedFields+=budget.Fields
 if kind~='frame' then work.LayerBuilds+=1 end
 return entry
end
function Compositing.storeFrame(work: any,scene: any,bytes: buffer,width: number,scale: number)
 work=work.Owner or work;if not work.Retain then return end
 if work.LastFrame then
  local index=table.find(work.Retained,work.LastFrame)
  if index then local old=table.remove(work.Retained,index);work.RetainedBytes-=buffer.len(old.Bytes);work.RetainedFields-=old.Fields end
  work.LastFrame=nil
 end
 work.LastFrame=Compositing.remember(work,'frame',scene,bytes,width,scale)
end
function Compositing.dirty(work: any,scene: any,width: number,height: number,scale: number): (any?,any?)
 work=work.Owner or work
 if not work.Retain then return nil,nil end
 local frame=work.LastFrame
 if not frame or frame.Width~=width or frame.Height~=height or frame.Scale~=scale or not scene.RenderTree then return nil,nil end
 local old=frame.Value
 if old.Width~=scene.Width or old.Height~=scene.Height or not old.RenderTree or #old.RenderTree~=#scene.RenderTree then return nil,nil end
 local left,top,right,bottom=width,height,0,0
 local function include(filter)
  if not filter or not filter.Region or not filter.Transform or not filter.Inverse then return false end
  local bounds=Matrix.bounds(Matrix.rectangle(filter.Transform,filter.Region))
  left=math.min(left,math.floor(bounds.X*scale));top=math.min(top,math.floor(bounds.Y*scale))
  right=math.max(right,math.ceil((bounds.X+bounds.Width)*scale));bottom=math.max(bottom,math.ceil((bounds.Y+bounds.Height)*scale))
  return true
 end
 local visit
 visit=function(a,b)
  if equal(a,b) then return true end
  -- Only a filter provides a proven finite output bound independent of its
  -- changed descendants and kernel halo. Broader changes use the full renderer.
  if a.Filter and b.Filter then return include(a.Filter) and include(b.Filter) end
  if not a.Children or not b.Children or #a.Children~=#b.Children then return false end
  -- A changed descendant inside another filter was handled above. A mask or
  -- isolated parent can expand its dependencies, so conservatively fall back.
  if a.Mask or b.Mask or (a.Opacity or 1)<1 or (b.Opacity or 1)<1 or a.Isolation=='isolate' or b.Isolation=='isolate' or (a.BlendMode or 'normal')~='normal' or (b.BlendMode or 'normal')~='normal' then return false end
  for key,value in a do if key~='Children' and not equal(value,b[key]) then return false end end
  for key in b do if key~='Children' and not ignored[key] and a[key]==nil then return false end end
  for i,child in a.Children do if not visit(child,b.Children[i]) then return false end end
  return true
 end
 for i,node in old.RenderTree do if not visit(node,scene.RenderTree[i]) then return nil,nil end end
 left=math.clamp(left,0,width);right=math.clamp(right,0,width);top=math.clamp(top,0,height);bottom=math.clamp(bottom,0,height)
 local region={X=left,Y=top,Width=math.max(0,right-left),Height=math.max(0,bottom-top)}
 work.PartialRenders+=1;work.RepaintPixels+=region.Width*region.Height
 return frame,region
end
function Compositing.over(destination: buffer,source: buffer,opacity: number,width: number,check: any?,mode: string?,region: any?,dirty: any?): boolean
 local sw=if region then region.Width else width
 local sh=if region then region.Height else buffer.len(source)/(width*4)
 if not region then assert(buffer.len(destination)==buffer.len(source),'SVG compositing size mismatch') end
 local x0,y0,x1,y1=0,0,sw,sh
 if dirty then
  local ox,oy=if region then region.X else 0,if region then region.Y else 0
  x0=math.max(x0,dirty.X-ox);y0=math.max(y0,dirty.Y-oy)
  x1=math.min(x1,dirty.X+dirty.Width-ox);y1=math.min(y1,dirty.Y+dirty.Height-oy)
 end
 for y=y0,y1-1 do
  if check and not check() then return false end
  for x=x0,x1-1 do
   if x%64==0 then WorkContext.checkpoint()end
  local from=(y*sw+x)*4
  local at=if region then ((region.Y+y)*width+region.X+x)*4 else from
		local alpha=buffer.readu8(source,from+3)/255*opacity
		if alpha<=0 then continue end
		local old=buffer.readu8(destination,at+3)/255;local combined=alpha+old*(1-alpha)
  local mixed
  if mode and mode~='normal' and old>0 then
   mixed=Blend.rgb(mode,{buffer.readu8(destination,at)/255,buffer.readu8(destination,at+1)/255,buffer.readu8(destination,at+2)/255},{buffer.readu8(source,from)/255,buffer.readu8(source,from+1)/255,buffer.readu8(source,from+2)/255})
  end
  for c=0,2 do
   local foreground=buffer.readu8(source,from+c)
   if mixed then foreground=foreground*(1-old)+255*math.clamp(mixed[c+1],0,1)*old end
   buffer.writeu8(destination,at+c,math.round((foreground*alpha+buffer.readu8(destination,at+c)*old*(1-alpha))/combined))
  end
		buffer.writeu8(destination,at+3,math.round(combined*255))
	end end
	return true
end
function Compositing.draw(bytes: buffer,nodes: any,drawShape: any,width: number,check: any?,work: any?,clipper: any?,filterer: any?,scale: number?,dirty: any?): boolean
 work=work or {}
 local initial=work.CompositeLive or 0
 work.CompositeLive=initial+buffer.len(bytes)
 assert(work.CompositeLive<=32*1024*1024,'SVG opacity buffer budget exceeded')
	local visit
	visit=function(target: buffer,node: any,depth: number,region: any?): boolean
		if check and not check() then return false end
		assert(depth<=256,'SVG rendering tree depth exceeded')
		local opacity=node.Opacity or 1
		if opacity<=0 or node.Hidden then return true end
		local isolated=node.Filter~=nil or opacity<1 or node.Mask~=nil or (node.BlendMode or 'normal')~='normal' or node.Isolation=='isolate'
  local detached=isolated or node.ClipPath~=nil
  local preserveBackdrop=node.ClipPath~=nil and not isolated
  -- A clipping-only group depends on its real backdrop and cannot be reused as
  -- an isolated layer. Filter/mask/opacity layers start transparent and can.
  if isolated then
   local cached=Compositing.cached(work,'layer',node,width,buffer.len(bytes)/(width*4),scale or 1)
   if cached then return Compositing.over(target,cached.Bytes,opacity,width,check,node.BlendMode,cached.Region,region) end
  end
  local destination=target
		if detached then
			work.CompositeLive+=buffer.len(bytes);assert(work.CompositeLive<=32*1024*1024,'SVG opacity buffer budget exceeded')
			destination=buffer.create(buffer.len(bytes))
   if preserveBackdrop then buffer.copy(destination,0,target) end
		end
		local sourceRegion=if isolated then nil else region
		if node.Children then
			for _,child in node.Children do if not visit(destination,child,depth+1,sourceRegion) then return false end end
		elseif not drawShape(destination,node,sourceRegion) then return false end
		if detached then
   if node.Filter and filterer and not filterer(destination,node.Filter) then return false end
   if node.ClipPath and clipper and not clipper(destination,node.ClipPath,nil,if preserveBackdrop then target else nil,sourceRegion) then return false end
   if node.Mask and clipper and not clipper(destination,node.Mask.Scene,node.Mask) then return false end
   local retained,completed
   if isolated then retained,completed=Compositing.remember(work,'layer',node,destination,width,scale or 1,check) end
   if completed==false then return false end
   if preserveBackdrop then buffer.copy(target,0,destination)
   elseif retained then
    if not Compositing.over(target,retained.Bytes,opacity,width,check,node.BlendMode,retained.Region,region) then return false end
   elseif not Compositing.over(target,destination,opacity,width,check,node.BlendMode,nil,region) then return false end
			work.CompositeLive-=buffer.len(bytes)
		end
		return true
	end
	for _,node in nodes do if not visit(bytes,node,0,dirty) then work.CompositeLive=initial;return false end end
 work.CompositeLive=initial
	return true
end
return Compositing
