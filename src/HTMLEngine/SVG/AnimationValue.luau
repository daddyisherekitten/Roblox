--!strict
local Color=require(script.Parent.Parent.CSS.Color)
local Length=require(script.Parent.Length)
local Value={}
local colors={fill=true,stroke=true,color=true,['stop-color']=true,['flood-color']=true,['lighting-color']=true}
function Value.parse(key: string,text: string,context: any): any?
 if colors[key] then local c,a=Color.parse(text);if c then return {Numbers={c.R*255,c.G*255,c.B*255,a},Color=true,Pattern='color'} end;return nil end
 local axis=({x='x',cx='x',width='x',y='y',cy='y',height='y',r='diagonal',['stroke-width']='diagonal',['font-size']='font'})[key]
 if axis then local n=Length.resolve(text,context,axis,false);if n then return {Numbers={n},Pattern='#'} end end
 local values,chunks={},{};local cursor=1
 while cursor<=#text do
  local first,last=text:find('[+-]?%d*%.?%d+',cursor)
  if not first then table.insert(chunks,text:sub(cursor));break end
  local exponent=text:match('^[eE][+-]?%d+',last+1);if exponent then last+=#exponent end
  table.insert(chunks,text:sub(cursor,first-1));table.insert(chunks,'#');table.insert(values,tonumber(text:sub(first,last)));cursor=last+1
 end
 local pattern=table.concat(chunks)
 -- Lists/transforms/path data interpolate only with the same command/unit skeleton.
 if #values==0 then return nil end
 return {Numbers=values,Pattern=pattern}
end
function Value.write(v: any): string
 if v.Color then return `rgba({v.Numbers[1]},{v.Numbers[2]},{v.Numbers[3]},{math.clamp(v.Numbers[4],0,1)})` end
 local i=0;return (v.Pattern:gsub('#',function() i+=1;return string.format('%.9g',v.Numbers[i]) end))
end
function Value.mix(key: string,a: string,b: string,t: number,context: any): string
 local x,y=Value.parse(key,a,context),Value.parse(key,b,context)
 if not x or not y or x.Pattern~=y.Pattern or #x.Numbers~=#y.Numbers then return if t<.5 then a else b end
 local v=table.clone(x);v.Numbers={};for i,n in x.Numbers do v.Numbers[i]=n+(y.Numbers[i]-n)*t end;return Value.write(v)
end
function Value.add(key: string,a: string,b: string,factor: number,context: any): string?
 local x,y=Value.parse(key,a,context),Value.parse(key,b,context)
 if not x or not y or x.Pattern~=y.Pattern or #x.Numbers~=#y.Numbers then return nil end
 local v=table.clone(x);v.Numbers={};for i,n in x.Numbers do v.Numbers[i]=n+y.Numbers[i]*factor end;return Value.write(v)
end
function Value.distance(key: string,a: string,b: string,context: any): number
 local x,y=Value.parse(key,a,context),Value.parse(key,b,context)
 if not x or not y or x.Pattern~=y.Pattern or #x.Numbers~=#y.Numbers then return 0 end
 local d=0;for i,n in x.Numbers do d+=(y.Numbers[i]-n)^2 end;return math.sqrt(d)
end
return Value
