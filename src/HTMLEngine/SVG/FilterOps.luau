--!strict
local Blend=require(script.Parent.Blend)
local FilterColor=require(script.Parent.FilterColor)
local Ops={}
Ops.Operators={over=true,['in']=true,out=true,atop=true,xor=true,lighter=true,arithmetic=true}
function Ops.composite(mode: string,c: any,b: any,k: any?): any
 local a,d=c[4],b[4];local out={0,0,0,0}
 local f,g=1,1-a
 if mode=='in' then f=d;g=0 elseif mode=='out' then f=1-d;g=0
 elseif mode=='atop' then f=d;g=1-a elseif mode=='xor' then f=1-d;g=1-a
 elseif mode=='lighter' then f=1;g=1 end
 for i=1,4 do
  local s=if i==4 then a else c[i]*a;local t=if i==4 then d else b[i]*d
  out[i]=math.clamp(if mode=='arithmetic' then k[1]*s*t+k[2]*s+k[3]*t+k[4] else s*f+t*g,0,1)
 end
 for i=1,3 do out[i]=if out[4]>0 then math.min(out[i],out[4])/out[4] else 0 end
 return out
end
function Ops.point(step: any,get: any): any
 if step.Kind=='feFlood' then return step.Flood end
 if step.Kind=='feMerge' then
  local out={0,0,0,0}
  for _,index in step.Inputs do out=Ops.composite('over',get(index,step.Space),out) end
  return out
 end
 local c=get(step.Input,step.Space)
 if step.Kind=='feComposite' then return Ops.composite(step.Operator,c,get(step.Input2,step.Space),step.K) end
 if step.Kind=='feBlend' then
  local b=get(step.Input2,step.Space);local a=c[4]+b[4]*(1-c[4]);local out={0,0,0,a}
  if a>0 then
   local mixed=Blend.rgb(step.Mode,b,c)
   for i=1,3 do out[i]=math.clamp(((1-b[4])*c[4]*c[i]+(1-c[4])*b[4]*b[i]+c[4]*b[4]*mixed[i])/a,0,1) end
  end
  return out
 end
 return FilterColor.apply(step,c)
end
return Ops
