--!strict
--!optimize 2
--!native
local FilterBlur=require(script.Parent.FilterBlur)
local Morphology={}
function Morphology.apply(input: any,rx: number,ry: number,operator: string,t: any,scale: number,allocate: any,release: any,check: any?): any
 local current=input;local dilate=operator=='dilate'
 for _,axis in {{t.SX,t.KY or 0,rx},{t.KX or 0,t.SY,ry}} do
  local length=math.sqrt(axis[1]^2+axis[2]^2)
  local radius=math.floor(axis[3]*length*scale+.5)
  assert(radius<=128,'SVG morphology radius budget exceeded')
  if radius==0 then continue end
  local ux,uy=axis[1]/length,axis[2]/length
  if math.abs(ux)<1e-9 then ux=0 end;if math.abs(uy)<1e-9 then uy=0 end
  local output=allocate(input.Space)
  for y=0,input.Height-1 do
   if check and not check() then return nil end
   for x=0,input.Width-1 do
    local start=if dilate then 0 else 1;local r,g,b,a=start,start,start,start
    for i=-radius,radius do
     local rr,gg,bb,aa=FilterBlur.sample(current,x+i*ux,y+i*uy)
     if dilate then r=math.max(r,rr);g=math.max(g,gg);b=math.max(b,bb);a=math.max(a,aa)
     else r=math.min(r,rr);g=math.min(g,gg);b=math.min(b,bb);a=math.min(a,aa) end
    end
    local at=(y*input.Width+x)*16
    buffer.writef32(output.Bytes,at,r);buffer.writef32(output.Bytes,at+4,g);buffer.writef32(output.Bytes,at+8,b);buffer.writef32(output.Bytes,at+12,a)
   end
  end
  if current~=input then release(current) end;current=output
 end
 return current
end
return Morphology
