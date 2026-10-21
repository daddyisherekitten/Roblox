--!strict
--!optimize 2
local Matrix=require(script.Parent.Matrix)
local FilterColor=require(script.Parent.FilterColor)
local FilterOps=require(script.Parent.FilterOps)
local FilterBlur=require(script.Parent.FilterBlur)
local FilterMorphology=require(script.Parent.FilterMorphology)
local FilterKernel=require(script.Parent.FilterKernel)
local FilterNoise=require(script.Parent.FilterNoise)
local FilterLighting=require(script.Parent.FilterLighting)
local Pixels={}
local function inside(r: any,x: number,y: number): boolean return x>=r.X and y>=r.Y and x<r.X+r.Width and y<r.Y+r.Height end
local function store(image: any,x: number,y: number,c: any)
 local at=(y*image.Width+x)*16;local a=c[4]
 for i=1,3 do buffer.writef32(image.Bytes,at+(i-1)*4,c[i]*a) end
 buffer.writef32(image.Bytes,at+12,a)
end
local function color(image: any,x: number,y: number,space: string,alphaOnly: boolean?): any
 local r,g,b,a=FilterBlur.sample(image,x,y)
 if a<=0 then return {0,0,0,0} end
 if alphaOnly then return {0,0,0,a} end
 return FilterColor.convert({r/a,g/a,b/a,a},image.Space,space)
end
function Pixels.apply(bytes: buffer,graph: any,width: number,scale: number,check: any?,work: any?,outputInside: any): boolean
 if not graph.Region or not graph.Inverse or #graph.Steps==0 then buffer.fill(bytes,0,0);return true end
 work=work or {};local initial=work.FilterLive or 0
 local function run(): boolean
  local height=buffer.len(bytes)/(width*4)
  local bounds=Matrix.bounds(Matrix.rectangle(graph.Transform,graph.Region))
  local left,top=math.max(0,math.floor(bounds.X*scale)),math.max(0,math.floor(bounds.Y*scale))
  local right,bottom=math.min(width,math.ceil((bounds.X+bounds.Width)*scale)),math.min(height,math.ceil((bounds.Y+bounds.Height)*scale))
  local w,h=right-left,bottom-top
  if w<=0 or h<=0 then buffer.fill(bytes,0,0);return true end
  local size=w*h*16;local live={}
  local function allocate(space: string): any
   local total=(work.FilterLive or 0)+size
   assert(total+(work.CompositeLive or 0)<=64*1024*1024,'SVG filter buffer budget exceeded')
   local image={Width=w,Height=h,Space=space,Bytes=buffer.create(size)}
   work.FilterLive=total;work.FilterPeak=math.max(work.FilterPeak or 0,total);live[image]=true
   return image
  end
  local function release(image: any)
   if not image or not live[image] then return end
   live[image]=nil;work.FilterLive-=size
  end
  local original=allocate('sRGB')
  for y=0,h-1 do
   if check and not check() then return false end
   for x=0,w-1 do
    local ux,uy=Matrix.point(graph.Inverse,(left+x+.5)/scale,(top+y+.5)/scale)
    if not inside(graph.Region,ux,uy) then continue end
    local at=((top+y)*width+left+x)*4;local a=buffer.readu8(bytes,at+3)/255
    store(original,x,y,{buffer.readu8(bytes,at)/255,buffer.readu8(bytes,at+1)/255,buffer.readu8(bytes,at+2)/255,a})
   end
  end
  local results={};local last={}
  for i,step in graph.Steps do
   last[step.Input]=i;if step.Input2 then last[step.Input2]=i end
   for _,index in step.Inputs or {} do last[index]=i end
  end
  for i,step in graph.Steps do
   local output=allocate(step.Space)
   local function get(index: number,x: number,y: number,space: string): any
    if index==-2 then return {0,0,0,0} end
    return color(if index<=0 then original else results[index],x,y,space,index==-1)
   end
   -- Extend the input subregion, including its transparent pixels. Wrapping
   -- individual bilinear taps keeps tile seams continuous at fractional scales.
   local inputRegion=if step.Input<=0 then graph.Region else graph.Steps[step.Input].Region
   local ib=Matrix.bounds(Matrix.rectangle(graph.Transform,inputRegion))
   local function edge(x: number,y: number,mode: string): any
    if mode=='none' then return get(step.Input,x,y,step.Space) end
    if inputRegion.Width<=0 or inputRegion.Height<=0 then return {0,0,0,0} end
    local ix,iy=math.floor(x),math.floor(y);local fx,fy=x-ix,y-iy;local sum={0,0,0,0}
    for dy=0,1 do for dx=0,1 do
     local weight=(if dx==0 then 1-fx else fx)*(if dy==0 then 1-fy else fy)
     if weight==0 then continue end
     local px,py=ix+dx,iy+dy
     if (graph.Transform.KX or 0)==0 and (graph.Transform.KY or 0)==0 then
      local lx,ty=math.ceil(ib.X*scale-.5)-left,math.ceil(ib.Y*scale-.5)-top
      local rw,bh=math.ceil((ib.X+ib.Width)*scale-.5)-left,math.ceil((ib.Y+ib.Height)*scale-.5)-top
      if rw<=lx or bh<=ty then continue end
      if mode=='wrap' then px=lx+(px-lx)%(rw-lx);py=ty+(py-ty)%(bh-ty)
      else px=math.clamp(px,lx,rw-1);py=math.clamp(py,ty,bh-1) end
     else
      local u,v=Matrix.point(graph.Inverse,(left+px+.5)/scale,(top+py+.5)/scale)
      if mode=='wrap' then u=inputRegion.X+(u-inputRegion.X)%inputRegion.Width;v=inputRegion.Y+(v-inputRegion.Y)%inputRegion.Height
      else u=math.clamp(u,inputRegion.X,inputRegion.X+inputRegion.Width-1e-6);v=math.clamp(v,inputRegion.Y,inputRegion.Y+inputRegion.Height-1e-6) end
      px,py=Matrix.point(graph.Transform,u,v);px=px*scale-left-.5;py=py*scale-top-.5
     end
     local c=get(step.Input,px,py,step.Space);local alpha=c[4]*weight
     for k=1,3 do sum[k]+=c[k]*alpha end;sum[4]+=alpha
    end end
    if sum[4]>0 then for k=1,3 do sum[k]/=sum[4] end end
    return sum
   end
   local blurred,prepared
   if step.Kind=='feGaussianBlur' or step.Kind=='feDropShadow' or step.Kind=='feMorphology' then
    prepared=allocate(step.Space)
    prepared.AlphaOnly=step.Kind=='feDropShadow'
    for y=0,h-1 do
     if check and not check() then return false end
     for x=0,w-1 do
      local c=get(step.Input,x,y,step.Space)
      if step.Kind=='feDropShadow' then c={0,0,0,c[4]} end
      store(prepared,x,y,c)
     end
    end
    blurred=if step.Kind=='feMorphology' then FilterMorphology.apply(prepared,step.RadiusX,step.RadiusY,step.Operator,graph.Transform,scale,allocate,release,check) else FilterBlur.apply(prepared,step.SigmaX,step.SigmaY,graph.Transform,scale,allocate,release,check)
    if not blurred then return false end
   end
   local dx=((graph.Transform.SX*(step.DX or 0))+(graph.Transform.KX or 0)*(step.DY or 0))*scale
   local dy=((graph.Transform.KY or 0)*(step.DX or 0)+graph.Transform.SY*(step.DY or 0))*scale
   local xx,xy,yx,yy=1,0,0,1
   if step.UnitX then xx=graph.Transform.SX*step.UnitX*scale;xy=(graph.Transform.KY or 0)*step.UnitX*scale;yx=(graph.Transform.KX or 0)*step.UnitY*scale;yy=graph.Transform.SY*step.UnitY*scale end
   local lighting=FilterLighting.Kinds[step.Kind]
   local lightingRegion,kdx,kdy,lightAlpha
   if lighting then
    lightingRegion={X=(inputRegion.X-step.OX)/step.PX,Y=(inputRegion.Y-step.OY)/step.PY,Width=inputRegion.Width/step.PX,Height=inputRegion.Height/step.PY}
    kdx=step.KernelX or 1/(scale*step.PX*math.sqrt(graph.Transform.SX^2+(graph.Transform.KY or 0)^2))
    kdy=step.KernelY or 1/(scale*step.PY*math.sqrt(graph.Transform.SY^2+(graph.Transform.KX or 0)^2))
    lightAlpha=function(u,v)
     local px,py=Matrix.point(graph.Transform,u*step.PX+step.OX,v*step.PY+step.OY)
     return get(step.Input,px*scale-left-.5,py*scale-top-.5,step.Space)[4]
    end
   end
   for y=0,h-1 do
    if check and not check() then return false end
    for x=0,w-1 do
     local ux,uy=Matrix.point(graph.Inverse,(left+x+.5)/scale,(top+y+.5)/scale)
     if not inside(step.Region,ux,uy) then continue end
     local c
     if lighting then
      local u,v=(ux-step.OX)/step.PX,(uy-step.OY)/step.PY
      local nx,ny,nz=FilterLighting.normal(lightAlpha,u,v,kdx,kdy,lightingRegion,step.SurfaceScale)
      c=FilterLighting.shade(step,u,v,lightAlpha(u,v)*step.SurfaceScale,nx,ny,nz)
     elseif step.Kind=='feGaussianBlur' or step.Kind=='feMorphology' then c=color(blurred,x,y,step.Space)
     elseif step.Kind=='feImage' then c=FilterKernel.image(step,ux,uy)
     elseif step.Kind=='feTile' then c=edge(x,y,'wrap')
     elseif step.Kind=='feConvolveMatrix' then c=FilterKernel.convolve(step,x,y,edge,xx,xy,yx,yy)
     elseif step.Kind=='feTurbulence' then c=FilterNoise.sample(step,(ux-step.OriginX)/step.PrimitiveX,(uy-step.OriginY)/step.PrimitiveY)
     elseif step.Kind=='feDisplacementMap' then
      local map=get(step.Input2,x,y,step.MapSpace)
      local sx,sy=(map[step.ChannelX]-.5)*step.ScaleX,(map[step.ChannelY]-.5)*step.ScaleY
      c=get(step.Input,x+(graph.Transform.SX*sx+(graph.Transform.KX or 0)*sy)*scale,y+((graph.Transform.KY or 0)*sx+graph.Transform.SY*sy)*scale,step.Space)
     elseif step.Kind=='feOffset' then c=get(step.Input,x-dx,y-dy,step.Space)
     elseif step.Kind=='feDropShadow' then
      local _,_,_,alpha=FilterBlur.sample(blurred,x-dx,y-dy);local f=step.Flood
      c=FilterOps.composite('over',get(step.Input,x,y,step.Space),{f[1],f[2],f[3],f[4]*alpha})
     else c=FilterOps.point(step,function(index,space) return get(index,x,y,space) end) end
     store(output,x,y,c)
    end
   end
   release(prepared);if blurred~=prepared then release(blurred) end
   results[i]=output
   for index,image in results do if index~=i and (last[index] or 0)<=i then release(image);results[index]=nil end end
  end
  local final=results[#graph.Steps];buffer.fill(bytes,0,0)
  for y=0,h-1 do
   if check and not check() then return false end
   for x=0,w-1 do
    if not outputInside(graph.OutputClip,(left+x+.5)/scale,(top+y+.5)/scale) then continue end
    local c=color(final,x,y,'sRGB');local at=((top+y)*width+left+x)*4
    for i=1,4 do buffer.writeu8(bytes,at+i-1,math.round(math.clamp(c[i],0,1)*255)) end
   end
  end
  return true
 end
 local ok,result=pcall(run);work.FilterLive=initial
 if not ok then error(result,0) end
 return result
end
return Pixels
