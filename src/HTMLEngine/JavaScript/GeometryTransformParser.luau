--!strict
-- CSS transform value parser for DOMMatrix. It has no layout/font/viewport
-- context; relative lengths and translation percentages are not resolvable.
-- Delimiters remain tokens so invalid comma forms cannot turn into valid CSS.
local Matrix=require(script.Parent.Parent.CSS.Matrix4)
local Parser={}
local INVALID={}
local LENGTH={px=1,cm=96/2.54,mm=96/25.4,q=96/101.6,['in']=96,pt=96/72,pc=16}
local ANGLE={deg=1,grad=.9,rad=180/math.pi,turn=360}
local function invalid()error(INVALID,0)end
local function whitespace(c)return c==' 'or c=='\t'or c=='\n'or c=='\r'or c=='\f'end
local function digit(c)return c~=''and c>='0'and c<='9'end
local function nameStart(c)return c~=''and(c:match('[%a_]')~=nil or c:byte()>=128 or c=='\\')end
local function nameChar(c)return nameStart(c)or digit(c)or c=='-'end
local function lex(source)
 local tokens={};local i,n=1,#source;local spaced=false
 local function escape()
  i+=1;local c=source:sub(i,i);if c==''or c=='\n'or c=='\r'or c=='\f'then invalid()end
  if c:match('[%da-fA-F]')then
   local first=i;while i<=n and i-first<6 and source:sub(i,i):match('[%da-fA-F]')do i+=1 end
   local cp=tonumber(source:sub(first,i-1),16);if whitespace(source:sub(i,i))then if source:sub(i,i+1)=='\r\n'then i+=2 else i+=1 end end
   return utf8.char(if cp==0 or cp>0x10ffff or cp>=0xd800 and cp<=0xdfff then 0xfffd else cp)
  end;i+=1;return c
 end
 local function name()
  local parts={};while nameChar(source:sub(i,i))do
   local c=source:sub(i,i);if c=='\\'then table.insert(parts,escape())else table.insert(parts,c);i+=1 end
  end;return table.concat(parts):lower()
 end
 while i<=n do
  local c=source:sub(i,i)
  if whitespace(c)then spaced=true;i+=1;continue end
  if source:sub(i,i+1)=='/*'then local last=source:find('*/',i+2,true);i=if last then last+2 else n+1;continue end
  if #tokens>=16384 then invalid()end
  local token={Gap=spaced};spaced=false
  local nextChar=source:sub(i+1,i+1);local after=source:sub(i+2,i+2)
  local numeric=digit(c)or c=='.'and digit(nextChar)or(c=='+'or c=='-')and(digit(nextChar)or nextChar=='.'and digit(after))
  if numeric then
   local first=i;if c=='+'or c=='-'then i+=1 end
   while digit(source:sub(i,i))do i+=1 end
   if source:sub(i,i)=='.'and digit(source:sub(i+1,i+1))then i+=1;while digit(source:sub(i,i))do i+=1 end end
   local e=source:sub(i,i);if e=='e'or e=='E'then
    local at=i+1;if source:sub(at,at)=='+'or source:sub(at,at)=='-'then at+=1 end
    if digit(source:sub(at,at))then i=at+1;while digit(source:sub(i,i))do i+=1 end end
   end
   token.Kind='number';token.Value=tonumber(source:sub(first,i-1));token.Unit=''
   if source:sub(i,i)=='%'then token.Unit='%';i+=1
   elseif nameStart(source:sub(i,i))or source:sub(i,i)=='-'and(nameStart(source:sub(i+1,i+1))or source:sub(i+1,i+1)=='-')then token.Unit=name()end
  elseif nameStart(c)or c=='-'and(nameStart(nextChar)or nextChar=='-')then
   token.Name=name();token.Kind=if source:sub(i,i)=='('then 'function'else 'ident';if token.Kind=='function'then i+=1 end
  else token.Kind=c;i+=1 end
  table.insert(tokens,token)
 end
 table.insert(tokens,{Kind='eof',Gap=spaced});return tokens
end
local function typed(value,length,angle,percent)return {Value=value,L=length or 0,A=angle or 0,P=percent or 0}end
local function same(a,b)return a.L==b.L and a.A==b.A and a.P==b.P end
local function scalar(a)return a.L==0 and a.A==0 and a.P==0 end
local function negative(value)return value<0 or value==0 and 1/value<0 end
local function bounded(v)
 -- CSS computation canonicalizes NaN to zero and clamps infinities. Numeric
 -- values otherwise retain double precision, including large finite values.
 return if v~=v then 0 elseif v==math.huge then 1.7976931348623157e308 elseif v==-math.huge then -1.7976931348623157e308 else v
end
local function rotation(x,y,z,degrees)
 local max=math.max(math.abs(x),math.abs(y),math.abs(z));if max==0 then return Matrix.identity()end
 x,y,z=x/max,y/max,z/max;local norm=math.sqrt(x*x+y*y+z*z);x,y,z=x/norm,y/norm,z/norm
 local reduced=degrees%360;local c,s
 if reduced==0 then c,s=1,0 elseif reduced==90 then c,s=0,1 elseif reduced==180 then c,s=-1,0 elseif reduced==270 then c,s=0,-1
 else local angle=math.rad(reduced);c,s=math.cos(angle),math.sin(angle)end;local t=1-c
 return {t*x*x+c,t*x*y+s*z,t*x*z-s*y,0,t*x*y-s*z,t*y*y+c,t*y*z+s*x,0,t*x*z+s*y,t*y*z-s*x,t*z*z+c,0,0,0,0,1}
end
local function parse(source)
 if source==''then return Matrix.identity(),true,false end
 local tokens=lex(source);local at,depth=1,0
 local function peek()return tokens[at]end
 local function take(kind)local token=peek();if token.Kind~=kind then invalid()end;at+=1;return token end
 -- CSS Syntax closes functions/simple blocks at EOF; extra closing tokens
 -- and incomplete expressions remain invalid through the normal grammar.
 local function close()if peek().Kind~='eof'then take(')')end end
 local sum,product,term,mathFunction
 local function add(a,b,op)if not same(a,b)then invalid()end;return typed(if op=='+'then a.Value+b.Value else a.Value-b.Value,a.L,a.A,a.P)end
 local function numeric(token,percentHint)
  local unit=token.Unit
  if unit==''then return typed(token.Value)end
  if unit=='%'then if not percentHint then invalid()end;return typed(token.Value,0,0,1)end
  if LENGTH[unit]then return typed(token.Value*LENGTH[unit],1,0)end
  if ANGLE[unit]then return typed(token.Value*ANGLE[unit],0,1)end
  invalid()
 end
 local function comparable(values)
  for i=2,#values do if not same(values[1],values[i])then invalid()end end;return values[1]
 end
 mathFunction=function(name,hint)
  depth+=1;if depth>64 then invalid()end
  local values={};local mode
  if name=='round'and peek().Kind=='ident'and({nearest=true,up=true,down=true,['to-zero']=true})[peek().Name]then mode=peek().Name;at+=1;take(',')end
  if peek().Kind==')'then invalid()end
  repeat
   if #values>=256 then invalid()end;table.insert(values,sum(hint))
   if peek().Kind~=','then break end;at+=1
  until false
  close();depth-=1
  local count=#values;local a,b,c=values[1],values[2],values[3];local value
  if name=='calc'then if count~=1 then invalid()end;return a
  elseif name=='min'or name=='max'then comparable(values);value=a.Value
   for i=2,count do local v=values[i].Value;if value~=value or v~=v then value=0/0 else value=if name=='min'then math.min(value,v)else math.max(value,v)end end
  elseif name=='clamp'then if count~=3 then invalid()end;comparable(values);value=if a.Value~=a.Value or b.Value~=b.Value or c.Value~=c.Value then 0/0 else math.max(a.Value,math.min(b.Value,c.Value))
  elseif name=='abs'then if count~=1 then invalid()end;value=math.abs(a.Value)
  elseif name=='sign'then if count~=1 then invalid()end;return typed(if a.Value==0 or a.Value~=a.Value then a.Value elseif a.Value<0 then -1 else 1)
  elseif name=='round'then
   if count==1 and scalar(a)then b=typed(1)elseif count~=2 then invalid()end;if not same(a,b)then invalid()end
   local v,step=a.Value,math.abs(b.Value);local q=v/step
   if v~=v or step~=step or step==0 or math.abs(v)==math.huge and step==math.huge then value=0/0
   elseif math.abs(v)==math.huge then value=v
   elseif step==math.huge then
    value=if mode=='up'and v>0 then math.huge elseif mode=='down'and v<0 then -math.huge elseif negative(v)then -0 else 0
   elseif v==0 then value=v
   else
    if mode=='up'then value=math.ceil(q)*step elseif mode=='down'then value=math.floor(q)*step elseif mode=='to-zero'then value=(if q<0 then math.ceil(q)else math.floor(q))*step else value=math.floor(q+.5)*step end
    if value==0 and negative(v)then value=-0 end
   end
  elseif name=='mod'or name=='rem'then
   if count~=2 or not same(a,b)then invalid()end;local q=a.Value/b.Value
   if a.Value~=a.Value or b.Value~=b.Value or b.Value==0 or math.abs(a.Value)==math.huge then value=0/0
   elseif math.abs(b.Value)==math.huge then value=if name=='mod'and negative(a.Value)~=negative(b.Value)then 0/0 else a.Value
   else
    value=a.Value-(if name=='mod'then math.floor(q)elseif q<0 then math.ceil(q)else math.floor(q))*b.Value
    if value==0 then value=if negative(if name=='mod'then b.Value else a.Value)then -0 else 0 end
   end
  elseif name=='hypot'then
   comparable(values);local max=0;for _,item in values do max=math.max(max,math.abs(item.Value))end
   for _,item in values do if item.Value~=item.Value then return typed(0/0,a.L,a.A,a.P)end end
   if max==0 then value=0 elseif max==math.huge then value=max else local squares=0;for _,item in values do squares+=(item.Value/max)^2 end;value=max*math.sqrt(squares)end
  elseif name=='sin'or name=='cos'or name=='tan'then
   if count~=1 or not(scalar(a)or a.L==0 and a.A==1 and a.P==0)then invalid()end
   local n=if a.A==1 then math.rad(a.Value)else a.Value;return typed(if name=='sin'then math.sin(n)elseif name=='cos'then math.cos(n)else math.tan(n))
  elseif name=='asin'or name=='acos'or name=='atan'then
   if count~=1 or not scalar(a)then invalid()end
   return typed(math.deg(if name=='asin'then math.asin(a.Value)elseif name=='acos'then math.acos(a.Value)else math.atan(a.Value)),0,1)
  elseif name=='atan2'then if count~=2 or not same(a,b)then invalid()end;return typed(math.deg(math.atan2(a.Value,b.Value)),0,1)
  elseif name=='pow'then if count~=2 or not scalar(a)or not scalar(b)then invalid()end;return typed(if a.Value~=a.Value or b.Value~=b.Value or math.abs(a.Value)==1 and math.abs(b.Value)==math.huge then 0/0 else a.Value^b.Value)
  elseif name=='sqrt'or name=='exp'then if count~=1 or not scalar(a)then invalid()end;return typed(if name=='sqrt'then math.sqrt(a.Value)else math.exp(a.Value))
  elseif name=='log'then if count>2 or not scalar(a)or b and not scalar(b)then invalid()end;return typed(if b and (b.Value<=0 or b.Value==1)then 0/0 elseif b then math.log(a.Value)/math.log(b.Value)else math.log(a.Value))
  else invalid()end
  return typed(value,a.L,a.A,a.P)
 end
 term=function(hint)
  local token=peek()
  if token.Kind=='number'then at+=1;return numeric(token,hint)
  elseif token.Kind=='function'then at+=1;return mathFunction(token.Name,hint)
  elseif token.Kind=='('then depth+=1;if depth>64 then invalid()end;at+=1;local result=sum(hint);close();depth-=1;return result
  elseif token.Kind=='ident'then
   at+=1;local value=({pi=math.pi,e=math.exp(1),infinity=math.huge,['-infinity']=-math.huge,nan=0/0})[token.Name]
   if value==nil then invalid()end;return typed(value)
  end;invalid()
 end
 product=function(hint)
  local left=term(hint)
  while peek().Kind=='*'or peek().Kind=='/'do
   local op=peek().Kind;at+=1;local right=term(hint);local sign=if op=='*'then 1 else -1
   left=typed(if op=='*'then left.Value*right.Value else left.Value/right.Value,left.L+sign*right.L,left.A+sign*right.A,left.P+sign*right.P)
  end;return left
 end
 sum=function(hint)
  local left=product(hint)
  while peek().Kind=='+'or peek().Kind=='-'do
   local op=peek();if not op.Gap or not tokens[at+1].Gap then invalid()end;at+=1;left=add(left,product(hint),op.Kind)
  end;return left
 end
 local function parameter(kind)
  local token=peek();local value;local calculated=token.Kind=='function'
  if token.Kind=='number'then at+=1;value=numeric(token,kind=='scale')
  elseif calculated then at+=1;value=mathFunction(token.Name,kind=='scale')else invalid()end
  local n=bounded(value.Value)
  if kind=='number'then if not scalar(value)then invalid()end
  elseif kind=='scale'then
   if value.L~=0 or value.A~=0 or value.P~=0 and value.P~=1 then invalid()end
   if value.P==1 then n/=100 end
  elseif kind=='length'then if not(value.L==1 and value.A==0 and value.P==0)and not(not calculated and scalar(value)and n==0)then invalid()end
  elseif kind=='angle'then if not(value.L==0 and value.A==1 and value.P==0)and not(not calculated and scalar(value)and n==0)then invalid()end end
  return n,calculated
 end
 if peek().Kind=='ident'and peek().Name=='none'and tokens[2].Kind=='eof'then return Matrix.identity(),true,true end
 local result,is2D,compact=Matrix.identity(),true,true;local count=0
 while peek().Kind~='eof'do
  count+=1;if count>4096 then invalid()end
  local name=take('function').Name;local values,calculated={},{};local kinds,min,max;local three=false
  if name=='matrix'then kinds={'number'};min,max=6,6
  elseif name=='matrix3d'then kinds={'number'};min,max=16,16;three=true
  elseif name=='translate'then kinds={'length'};min,max=1,2
  elseif name=='translatex'or name=='translatey'or name=='translatez'then kinds={'length'};min,max=1,1;three=name=='translatez'
  elseif name=='translate3d'then kinds={'length'};min,max=3,3;three=true
  elseif name=='scale'then kinds={'scale'};min,max=1,2
  elseif name=='scalex'or name=='scaley'or name=='scalez'then kinds={'scale'};min,max=1,1;three=name=='scalez'
  elseif name=='scale3d'then kinds={'scale'};min,max=3,3;three=true
  elseif name=='rotate'or name=='rotatex'or name=='rotatey'or name=='rotatez'then kinds={'angle'};min,max=1,1;three=name=='rotatex'or name=='rotatey'
  elseif name=='rotate3d'then kinds={'number','number','number','angle'};min,max=4,4;three=true
  elseif name=='skew'then kinds={'angle'};min,max=1,2
  elseif name=='skewx'or name=='skewy'then kinds={'angle'};min,max=1,1
  elseif name=='perspective'then kinds={'length'};min,max=1,1;three=true
  else invalid()end
  if name=='perspective'and peek().Kind=='ident'and peek().Name=='none'then values[1]=math.huge;at+=1
  else
   repeat
    local i=#values+1;if i>max then invalid()end;values[i],calculated[i]=parameter(kinds[i]or kinds[1])
    if peek().Kind~=','then break end;at+=1
   until false
  end
  close();if #values<min then invalid()end
  local m=Matrix.identity();local x,y,z=values[1],values[2],values[3]
  if name=='matrix'then m={x,y,0,0,z,values[4],0,0,0,0,1,0,values[5],values[6],0,1}
  elseif name=='matrix3d'then m=values
  elseif name=='translate'or name=='translate3d'then m=Matrix.translate(x,y or 0,z or 0)
  elseif name=='translatex'then m=Matrix.translate(x,0,0)
  elseif name=='translatey'then m=Matrix.translate(0,x,0)
  elseif name=='translatez'then m=Matrix.translate(0,0,x)
  elseif name=='scale'then m=Matrix.scale(x,y or x,1)
  elseif name=='scale3d'then m=Matrix.scale(x,y,z)
  elseif name=='scalex'then m=Matrix.scale(x,1,1)
  elseif name=='scaley'then m=Matrix.scale(1,x,1)
  elseif name=='scalez'then m=Matrix.scale(1,1,x)
  elseif name=='rotate'or name=='rotatez'then m=rotation(0,0,1,x)
  elseif name=='rotatex'then m=rotation(1,0,0,x)
  elseif name=='rotatey'then m=rotation(0,1,0,x)
  elseif name=='rotate3d'then m=rotation(x,y,z,values[4])
  elseif name=='skew'then m[5],m[2]=math.tan(math.rad(x)),math.tan(math.rad(y or 0))
  elseif name=='skewx'then m[5]=math.tan(math.rad(x))
  elseif name=='skewy'then m[2]=math.tan(math.rad(x))
  elseif name=='perspective'then if x<0 then if not calculated[1]then invalid()end;x=0 end;m=Matrix.perspective(x)end
  -- Construction provenance, independent of is2D: CSS no-op 3D operations can
  -- retain axis storage, while an explicit matrix() promotes it immediately.
  if name=='matrix'or name=='matrix3d'or name=='perspective'then compact=false
  elseif name=='translatez'then compact=compact and x==0
  elseif name=='translate3d'then compact=compact and z==0
  elseif name=='scalez'then compact=compact and x==1
  elseif name=='scale3d'then compact=compact and z==1
  elseif name=='rotate3d'then compact=compact and (values[4]%360==0 or x==0 and y==0 and z==0)
  elseif name:sub(1,6)=='rotate'then compact=compact and x%360==0
  elseif name=='skew'then compact=compact and x==0 and (y or 0)==0
  elseif name=='skewx'or name=='skewy'then compact=compact and x==0 end
  result=Matrix.multiply(result,m);if three then is2D=false end
 end
 if count==0 then invalid()end;return result,is2D,compact
end
function Parser.parse(source: string): (any?,boolean?,boolean?)
 local ok,values,is2D,compact=pcall(parse,source)
 if ok then return values,is2D,compact end;if values~=INVALID then error(values,0)end;return nil
end
function Parser.tokens(source: string): any?
	local ok,tokens=pcall(lex,source);if ok then return tokens end;if tokens~=INVALID then error(tokens,0)end;return nil
end
return Parser
