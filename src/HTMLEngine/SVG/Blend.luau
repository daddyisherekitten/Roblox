--!strict
--!optimize 2
--!native
-- CSS Compositing Level 1. Inputs/outputs are unassociated sRGB in [0,1].
local Blend={}
Blend.Modes={normal=true,multiply=true,screen=true,overlay=true,darken=true,lighten=true,['color-dodge']=true,['color-burn']=true,['hard-light']=true,['soft-light']=true,difference=true,exclusion=true,hue=true,saturation=true,color=true,luminosity=true}
local function lum(c: any): number return .3*c[1]+.59*c[2]+.11*c[3] end
local function sat(c: any): number return math.max(c[1],c[2],c[3])-math.min(c[1],c[2],c[3]) end
local function setLum(c: any,l: number): any
 local d=l-lum(c);local out={c[1]+d,c[2]+d,c[3]+d}
 local lo,hi=math.min(out[1],out[2],out[3]),math.max(out[1],out[2],out[3])
 if lo<0 then for i=1,3 do out[i]=l+(out[i]-l)*l/(l-lo) end end
 if hi>1 then for i=1,3 do out[i]=l+(out[i]-l)*(1-l)/(hi-l) end end
 return out
end
local function setSat(c: any,s: number): any
 local order={1,2,3};table.sort(order,function(a,b) return c[a]<c[b] end)
 local lo,mid,hi=order[1],order[2],order[3];local out={0,0,0}
 if c[hi]>c[lo] then out[mid]=(c[mid]-c[lo])*s/(c[hi]-c[lo]);out[hi]=s end
 return out
end
function Blend.channel(mode: string,b: number,s: number): number
 if mode=='normal' then return s
 elseif mode=='multiply' then return b*s
 elseif mode=='screen' then return b+s-b*s
 elseif mode=='overlay' then return if b<=.5 then 2*b*s else 1-2*(1-b)*(1-s)
 elseif mode=='darken' then return math.min(b,s)
 elseif mode=='lighten' then return math.max(b,s)
 elseif mode=='color-dodge' then return if b==0 then 0 elseif s==1 then 1 else math.min(1,b/(1-s))
 elseif mode=='color-burn' then return if b==1 then 1 elseif s==0 then 0 else 1-math.min(1,(1-b)/s)
 elseif mode=='hard-light' then return if s<=.5 then 2*b*s else 1-2*(1-b)*(1-s)
 elseif mode=='soft-light' then
  if s<=.5 then return b-(1-2*s)*b*(1-b) end
  local d=if b<=.25 then ((16*b-12)*b+4)*b else math.sqrt(b)
  return b+(2*s-1)*(d-b)
 elseif mode=='difference' then return math.abs(b-s)
 elseif mode=='exclusion' then return b+s-2*b*s end
 error('Unknown separable blend mode: '..mode)
end
function Blend.rgb(mode: string,b: any,s: any): any
 if mode=='hue' then return setLum(setSat(s,sat(b)),lum(b))
 elseif mode=='saturation' then return setLum(setSat(b,sat(s)),lum(b))
 elseif mode=='color' then return setLum(s,lum(b))
 elseif mode=='luminosity' then return setLum(b,lum(s)) end
 return {Blend.channel(mode,b[1],s[1]),Blend.channel(mode,b[2],s[2]),Blend.channel(mode,b[3],s[3])}
end
return Blend
