--!strict
local FilterColor=require(script.Parent.FilterColor)
local Paint=require(script.Parent.Paint)
local Lighting={}
Lighting.Kinds={feDiffuseLighting=true,feSpecularLighting=true}
local function unit(x: number,y: number,z: number): (number,number,number)
 local n=math.sqrt(x*x+y*y+z*z);if n==0 then return 0,0,0 end;return x/n,y/n,z/n
end
function Lighting.parse(step: any,child: any,computed: any,ctx: any,box: any,pu: string,report: any): boolean
 local function number(a: any,key: string,default: number): number
  if a[key]==nil then return default end
  local v=FilterColor.numbers(a[key]);if not v or #v~=1 then error(key) end;return v[1]
 end
 local ok,err=pcall(function()
  local a=child.Attributes
  step.SurfaceScale=number(a,'surfaceScale',1)
  step.Constant=number(a,if step.Kind=='feDiffuseLighting' then 'diffuseConstant' else 'specularConstant',1)
  step.Exponent=number(a,'specularExponent',1)
  if step.Constant<0 or step.Exponent<1 or step.Exponent>128 then error('lighting constant/exponent') end
  step.PX=if pu=='objectBoundingBox' then box.Width else 1;step.PY=if pu=='objectBoundingBox' then box.Height else 1
  step.OX=if pu=='objectBoundingBox' then box.X else 0;step.OY=if pu=='objectBoundingBox' then box.Y else 0
  if a.kernelUnitLength then
   local v=FilterColor.numbers(a.kernelUnitLength)
   if not v or #v<1 or #v>2 or v[1]<=0 or (v[2] or v[1])<=0 then error('kernelUnitLength') end
   step.KernelX=v[1];step.KernelY=v[2] or v[1]
  end
  local light
  for _,c in child.Children do
   if c.Kind=='Element' and c.NamespaceURI==child.NamespaceURI and ({feDistantLight=true,fePointLight=true,feSpotLight=true})[c.Name] then
    if light then error('exactly one light required') end;light=c
   end
  end
  if not light then error('missing light') end
  local la=light.Attributes;step.Light={Kind=light.Name}
  local l=step.Light
  if light.Name=='feDistantLight' then
   local az,el=math.rad(number(la,'azimuth',0)),math.rad(number(la,'elevation',0))
   l.X=math.cos(az)*math.cos(el);l.Y=math.sin(az)*math.cos(el);l.Z=math.sin(el)
  else
   l.X=number(la,'x',0);l.Y=number(la,'y',0);l.Z=number(la,'z',0)
   if light.Name=='feSpotLight' then
    l.DX,l.DY,l.DZ=unit(number(la,'pointsAtX',0)-l.X,number(la,'pointsAtY',0)-l.Y,number(la,'pointsAtZ',0)-l.Z)
    l.Exponent=number(la,'specularExponent',1)
    if l.Exponent<1 or l.Exponent>128 then error('spot exponent') end
    if la.limitingConeAngle then l.Cone=math.cos(math.rad(number(la,'limitingConeAngle',90))) end
   end
  end
  local state=Paint.resolve({color=computed.Values.color,fill=computed.Values['lighting-color']},nil,ctx)
  local c=Paint.used(state,ctx);step.LightColor=FilterColor.convert({c[1]/255,c[2]/255,c[3]/255,1},'sRGB',step.Space)
 end)
 if not ok then report('invalid-lighting-parameter',tostring(err));return false end;return true
end
-- Sobel derivative with one-sided kernels at image edges, as in SVG's 3x3 table.
function Lighting.normal(alpha: any,x: number,y: number,dx: number,dy: number,region: any,height: number): (number,number,number)
 local x0,x1=if x-dx>=region.X then -1 else 0,if x+dx<region.X+region.Width then 1 else 0
 local y0,y1=if y-dy>=region.Y then -1 else 0,if y+dy<region.Y+region.Height then 1 else 0
 local gx,gy,wx,wy=0,0,0,0
 if x0~=x1 then
  for j=y0,y1 do local w=if j==0 then 2 else 1;gx+=(alpha(x+x1*dx,y+j*dy)-alpha(x+x0*dx,y+j*dy))*w;wx+=w end
 end
 if y0~=y1 then
  for i=x0,x1 do local w=if i==0 then 2 else 1;gy+=(alpha(x+i*dx,y+y1*dy)-alpha(x+i*dx,y+y0*dy))*w;wy+=w end
 end
 gx=if wx>0 then gx*2/((x1-x0)*wx*dx) else 0
 gy=if wy>0 then gy*2/((y1-y0)*wy*dy) else 0
 return unit(-height*gx,-height*gy,1)
end
function Lighting.shade(step: any,x: number,y: number,z: number,nx: number,ny: number,nz: number): any
 local light=step.Light;local lx,ly,lz=light.X,light.Y,light.Z;local intensity=1
 if light.Kind~='feDistantLight' then
  lx,ly,lz=unit(lx-x,ly-y,lz-z)
  if light.Kind=='feSpotLight' then
   local cosine=-(lx*light.DX+ly*light.DY+lz*light.DZ)
   local cutoff=light.Cone or 0
   if cosine<=0 or cosine<cutoff then intensity=0
   else
    -- Match Skia's narrow cone-edge fade in cosine space. A hard cutoff
    -- aliases the spot boundary; blurring the image would soften the relief too.
    intensity=cosine^light.Exponent*math.clamp((cosine-cutoff)/.016,0,1)
   end
  end
 end
 if step.Kind=='feSpecularLighting' then lx,ly,lz=unit(lx,ly,lz+1) end
 local v=math.max(0,nx*lx+ny*ly+nz*lz)
 if step.Kind=='feSpecularLighting' then v=v^step.Exponent end
 v*=step.Constant*intensity
 local c=step.LightColor;local r,g,b=math.clamp(c[1]*v,0,1),math.clamp(c[2]*v,0,1),math.clamp(c[3]*v,0,1)
 if step.Kind=='feDiffuseLighting' then return {r,g,b,1} end
 local a=math.max(r,g,b);return if a==0 then {0,0,0,0} else {r/a,g/a,b/a,a}
end
return Lighting
