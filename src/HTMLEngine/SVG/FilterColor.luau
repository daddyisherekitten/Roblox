--!strict
-- Unassociated floating-point channels. Quantize only when the graph is uploaded.
local FilterColor={}
function FilterColor.numbers(value: string?): any?
 local out={}
 if value==nil then return out end
 if value:match("^%s*,") or value:match(",%s*$") or value:match(",%s*,") then return nil end
 for token in value:gmatch('[^,%s]+') do
  local n=tonumber(token)
  if not token:match("^[+%-]?[%d%.]+[eE]?[+%-]?%d*$") or not n or n~=n or math.abs(n)==math.huge or #out>=256 then return nil end
  table.insert(out,n)
 end
 return out
end
function FilterColor.convert(c: any,from: string,to: string): any
 if from==to then return c end
 local out={0,0,0,c[4]}
 for i=1,3 do
  local v=c[i]
  out[i]=if to=='linearRGB' then (if v<=.04045 then v/12.92 else ((v+.055)/1.055)^2.4) else (if v<=.0031308 then v*12.92 else 1.055*v^(1/2.4)-.055)
 end
 return out
end
function FilterColor.matrix(a: any): any?
 local kind=a.type or 'matrix';local v=FilterColor.numbers(a.values)
 if not v then return nil end
 local identity={1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0}
 if kind=='matrix' then return if a.values==nil then identity elseif #v==20 then v else nil end
 if kind=='luminanceToAlpha' then return {0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, .2125,.7154,.0721,0,0} end
 if #v>1 or (a.values~=nil and #v~=1) then return nil end
 if kind=='saturate' then
  local s=v[1] or 1;if s<0 or s>1 then return nil end
  return {.213+.787*s,.715-.715*s,.072-.072*s,0,0, .213-.213*s,.715+.285*s,.072-.072*s,0,0, .213-.213*s,.715-.715*s,.072+.928*s,0,0, 0,0,0,1,0}
 elseif kind=='hueRotate' then
  local r=math.rad(v[1] or 0);local c,s=math.cos(r),math.sin(r)
  return {.213+.787*c-.213*s,.715-.715*c-.715*s,.072-.072*c+.928*s,0,0, .213-.213*c+.143*s,.715+.285*c+.140*s,.072-.072*c-.283*s,0,0, .213-.213*c-.787*s,.715-.715*c+.715*s,.072+.928*c+.072*s,0,0, 0,0,0,1,0}
 end
 return nil
end
function FilterColor.transfer(a: any): any?
 local kind=a.type or 'identity'
 if kind=='identity' then return {Kind=kind} end
 if kind=='table' or kind=='discrete' then
  local values=FilterColor.numbers(a.tableValues)
  return if values then {Kind=kind,Values=values} else nil
 end
 if kind~='linear' and kind~='gamma' then return nil end
 local result={Kind=kind}
 for key,default in {slope=1,intercept=0,amplitude=1,exponent=1,offset=0} do
  local list=FilterColor.numbers(a[key]);if not list or (a[key]~=nil and #list~=1) then return nil end
  result[key]=list[1] or default
 end
 return result
end
function FilterColor.channel(f: any?,v: number): number
 if not f or f.Kind=='identity' then return v end
 local result=v
 if f.Kind=='linear' then result=f.slope*v+f.intercept
 elseif f.Kind=='gamma' then result=f.amplitude*v^f.exponent+f.offset
 else
  local a=f.Values;local n=#a
  if n==0 then return v end
  if f.Kind=='discrete' then result=a[math.min(n,math.floor(v*n)+1)]
  elseif n==1 then result=a[1]
  else local pos=v*(n-1);local i=math.min(n-1,math.floor(pos)+1);result=a[i]+(a[i+1]-a[i])*(pos-(i-1)) end
 end
 if result~=result then return 0 end
 return math.clamp(result,0,1)
end
function FilterColor.apply(p: any,c: any): any
 local out={0,0,0,0}
 if p.Matrix then
  local m=p.Matrix
  for i=1,4 do local k=(i-1)*5;out[i]=math.clamp(m[k+1]*c[1]+m[k+2]*c[2]+m[k+3]*c[3]+m[k+4]*c[4]+m[k+5],0,1) end
 else for i=1,4 do out[i]=FilterColor.channel(p.Functions[i],c[i]) end end
 if out[4]==0 then out[1]=0;out[2]=0;out[3]=0 end
 return out
end
return FilterColor
