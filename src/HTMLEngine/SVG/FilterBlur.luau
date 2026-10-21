--!strict
--!optimize 2
--!native
-- Separable Gaussian along transformed SVG axes, on premultiplied float pixels.
local Blur={}
function Blur.read(image: any,x: number,y: number): (number,number,number,number)
 if x<0 or y<0 or x>=image.Width or y>=image.Height then return 0,0,0,0 end
 local at=(y*image.Width+x)*16;local b=image.Bytes
 return buffer.readf32(b,at),buffer.readf32(b,at+4),buffer.readf32(b,at+8),buffer.readf32(b,at+12)
end
function Blur.sample(image: any,x: number,y: number): (number,number,number,number)
 local xx,yy=math.floor(x),math.floor(y);local fx,fy=x-xx,y-yy
 if fx==0 and fy==0 then return Blur.read(image,xx,yy) end
 local r,g,b,a=0,0,0,0
 for dy=0,1 do for dx=0,1 do
  local weight=(if dx==0 then 1-fx else fx)*(if dy==0 then 1-fy else fy)
  if weight==0 then continue end
  local rr,gg,bb,aa=Blur.read(image,xx+dx,yy+dy)
  r+=rr*weight;g+=gg*weight;b+=bb*weight;a+=aa*weight
 end end
 return r,g,b,a
end
function Blur.kernel(sigma: number): any
 if sigma<=.01 then return {1},0 end
 local radius=math.ceil(3*sigma);assert(radius<=256,'SVG Gaussian kernel budget exceeded')
 local weights={};local total=0
 for i=-radius,radius do local v=math.exp(-.5*(i/sigma)^2);weights[i+radius+1]=v;total+=v end
 for i,v in weights do weights[i]=v/total end
 return weights,radius
end
function Blur.apply(input: any,sigmaX: number,sigmaY: number,t: any,scale: number,allocate: any,release: any,check: any?): any
 local current=input
 for _,axis in {{t.SX,t.KY or 0,sigmaX},{t.KX or 0,t.SY,sigmaY}} do
  local length=math.sqrt(axis[1]^2+axis[2]^2);local sigma=axis[3]*length*scale
  if sigma<=.01 then continue end
  local ux,uy=axis[1]/length,axis[2]/length
  -- Snap numerical rotation noise so orthogonal axes take the direct pixel path.
  if math.abs(ux)<1e-9 then ux=0 end;if math.abs(uy)<1e-9 then uy=0 end
  local weights,radius=Blur.kernel(sigma);local output=allocate(input.Space)
  output.AlphaOnly=input.AlphaOnly
  local orthogonal=(ux==0 and math.abs(uy)==1) or (uy==0 and math.abs(ux)==1)
  for y=0,input.Height-1 do
   if check and not check() then return nil end
   for x=0,input.Width-1 do
    local r,g,b,a=0,0,0,0
    if orthogonal then
     -- The usual horizontal/vertical blur needs no bilinear sampling, bounds
     -- checks or function calls per tap. Keep the same summation order/weights.
     local first,last=-radius,radius
     if ux==1 then first=math.max(first,-x);last=math.min(last,input.Width-1-x)
     elseif ux==-1 then first=math.max(first,x-input.Width+1);last=math.min(last,x)
     elseif uy==1 then first=math.max(first,-y);last=math.min(last,input.Height-1-y)
     else first=math.max(first,y-input.Height+1);last=math.min(last,y) end
     local pixels=current.Bytes;local stride=(uy*input.Width+ux)*16;local at=(y*input.Width+x)*16+first*stride
     for i=first,last do
      local w=weights[i+radius+1]
      if not input.AlphaOnly then r+=buffer.readf32(pixels,at)*w;g+=buffer.readf32(pixels,at+4)*w;b+=buffer.readf32(pixels,at+8)*w end
      a+=buffer.readf32(pixels,at+12)*w;at+=stride
     end
    else
     for i=-radius,radius do
      local rr,gg,bb,aa=Blur.sample(current,x+i*ux,y+i*uy);local w=weights[i+radius+1]
      r+=rr*w;g+=gg*w;b+=bb*w;a+=aa*w
     end
    end
    local at=(y*input.Width+x)*16
    buffer.writef32(output.Bytes,at,r);buffer.writef32(output.Bytes,at+4,g);buffer.writef32(output.Bytes,at+8,b);buffer.writef32(output.Bytes,at+12,a)
   end
  end
  if current~=input then release(current) end
  current=output
 end
 return current
end
return Blur
