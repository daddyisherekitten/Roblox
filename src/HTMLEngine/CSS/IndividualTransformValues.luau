--!strict
-- Individual properties retain their computed values (including percentages),
-- independent of the transform list. None is a real value, never a missing stop.
local Length=require(script.Parent.LengthExpression)
local Values={Fields={translate='Translate',rotate='Rotate',scale='Scale'}}
local zero={Value=0,Percent=false}
function Values.value(operation:any):any return {Operation=operation}end
function Values.fromStyle(style:any,property:string):any return Values.value(style[Values.Fields[property]])end
local function identity(property:string,model:any):any
 if property=='translate'then return {Kind='translate',X=zero,Y=zero,Z=zero}
 elseif property=='scale'then return {Kind='scale',Value=1,Y=1,Z=1}
 else local copy=table.clone(model or {Kind='rotate'});copy.Value=0;return copy end
end
local function axis(op:any):(number,number,number,number)
 local x,y,z=0,0,1
 if op.Kind=='tilt'then x,y,z=if op.Axis=='x'then 1 else 0,if op.Axis=='y'then 1 else 0,0
 elseif op.Kind=='rotate3d'then x,y,z=op.X,op.Y,op.Z end
 local largest=math.max(math.abs(x),math.abs(y),math.abs(z));if largest==0 then return 0,0,1,0 end
 x,y,z=x/largest,y/largest,z/largest;local size=math.sqrt(x*x+y*y+z*z)
 return x/size,y/size,z/size,op.Value
end
local function rotation(x:number,y:number,z:number,angle:number):any
 if math.abs(x)+math.abs(y)<1e-10 and z>0 then return {Kind='rotate',Value=angle}
 elseif math.abs(y)+math.abs(z)<1e-10 and x>0 then return {Kind='tilt',Axis='x',Value=angle}
 elseif math.abs(x)+math.abs(z)<1e-10 and y>0 then return {Kind='tilt',Axis='y',Value=angle}
 else return {Kind='rotate3d',X=x,Y=y,Z=z,Value=angle}end
end
local function quaternion(op:any):any
 local x,y,z,angle=axis(op);local half=math.rad(angle)/2;local s=math.sin(half)
 return {x*s,y*s,z*s,math.cos(half)}
end
local function product(a:any,b:any):any
 return {a[4]*b[1]+a[1]*b[4]+a[2]*b[3]-a[3]*b[2],a[4]*b[2]-a[1]*b[3]+a[2]*b[4]+a[3]*b[1],a[4]*b[3]+a[1]*b[2]-a[2]*b[1]+a[3]*b[4],a[4]*b[4]-a[1]*b[1]-a[2]*b[2]-a[3]*b[3]}
end
local function fromQuaternion(q:any):any
 local norm=math.sqrt(q[1]^2+q[2]^2+q[3]^2+q[4]^2)
 local x,y,z,w=q[1]/norm,q[2]/norm,q[3]/norm,math.clamp(q[4]/norm,-1,1)
 local size=math.sqrt(x*x+y*y+z*z)
 return if size==0 then {Kind='rotate',Value=0}else rotation(x/size,y/size,z/size,math.deg(2*math.atan2(size,w)))
end
function Values.mix(property:string,a:any,b:any,t:number,mixLength:any,box:any):any
 local left,right=a.Operation,b.Operation
 if not left and not right then return Values.value(nil)end
 left,right=left or identity(property,right),right or identity(property,left)
 local op
 if property=='translate'then
  op={Kind='translate'};for _,component in {'X','Y','Z'}do op[component]=mixLength(left[component]or zero,right[component]or zero,t,box)end
 elseif property=='scale'then
  op={Kind='scale',Value=left.Value+(right.Value-left.Value)*t,Y=(left.Y or left.Value)+((right.Y or right.Value)-(left.Y or left.Value))*t,Z=(left.Z or 1)+((right.Z or 1)-(left.Z or 1))*t}
 else
  local ax,ay,az,aa=axis(left);local bx,by,bz,ba=axis(right)
  if aa==0 then ax,ay,az=bx,by,bz elseif ba==0 then bx,by,bz=ax,ay,az end
  if math.abs(ax-bx)+math.abs(ay-by)+math.abs(az-bz)<1e-8 then op=rotation(ax,ay,az,aa+(ba-aa)*t)
  else
   local qa,qb=quaternion(left),quaternion(right);local dot=qa[1]*qb[1]+qa[2]*qb[2]+qa[3]*qb[3]+qa[4]*qb[4]
   if dot<0 then for i=1,4 do qb[i]=-qb[i]end;dot=-dot end
   local angle=math.acos(math.clamp(dot,-1,1));local sa,sb=1-t,t
   if math.abs(math.sin(angle))>1e-8 then sa,sb=math.sin((1-t)*angle)/math.sin(angle),math.sin(t*angle)/math.sin(angle)end
   local q={};for i=1,4 do q[i]=qa[i]*sa+qb[i]*sb end;op=fromQuaternion(q)
  end
 end
 return Values.value(op)
end
function Values.compose(property:string,a:any,b:any,count:number?,addLength:any,box:any):any
 local left,right=a.Operation,b.Operation;count=count or 1
 if not left and not right then return Values.value(nil)end
 left,right=left or identity(property,right),right or identity(property,left)
 local op
 if property=='translate'then
  op={Kind='translate'};for _,component in {'X','Y','Z'}do op[component]=addLength(left[component]or zero,right[component]or zero,box,count)end
 elseif property=='scale'then
  -- Individual scale composes by multiplication, for both add/accumulate.
  op={Kind='scale',Value=left.Value*right.Value^count,Y=(left.Y or left.Value)*(right.Y or right.Value)^count,Z=(left.Z or 1)*(right.Z or 1)^count}
 else
  local ax,ay,az,aa=axis(left);local bx,by,bz,ba=axis(right)
  if aa==0 then ax,ay,az=bx,by,bz elseif ba==0 then bx,by,bz=ax,ay,az end
  if math.abs(ax-bx)+math.abs(ay-by)+math.abs(az-bz)<1e-8 then op=rotation(ax,ay,az,aa+ba*count)
  else local delta=table.clone(right);delta.Value*=count;op=fromQuaternion(product(quaternion(left),quaternion(delta)))end
 end
 return Values.value(op)
end
function Values.operations(style:any,properties:any,transform:any):any
 local result={}
 for _,property in {'translate','rotate','scale'}do local sample=properties and properties[property];local op=if sample then sample.Operation else style[Values.Fields[property]];if op then table.insert(result,op)end end
 for _,op in transform or style.Transform or {}do table.insert(result,op)end
 return result
end
local function number(value:number):string return if value==0 then '0'else string.format('%.6g',value)end
local function length(value:any):string
 if not value then return '0px'end
 local ast=value.Expression or (if value.Kind=='length'then value else nil)
 if ast and ast.Op=='linear'then
  local px,pct=ast.Pixels,ast.PercentValue
  if pct==0 then return number(px)..'px'elseif px==0 then return number(pct)..'%'end
  return 'calc('..number(pct)..'% '..(if px<0 then '- 'else '+ ')..number(math.abs(px))..'px)'
 elseif ast then return Length.serialize(value)or'0px'end
 return number(value.Value)..(if value.Percent then '%'else 'px')
end
function Values.serialize(property:string,value:any):string
 local op=value.Operation;if not op then return 'none'end
 if property=='translate'then
  local x,y,z=length(op.X),length(op.Y),length(op.Z)
  return x..(if y~='0px'and y~='0%'or z~='0px'then ' '..y else '')..(if z~='0px'then ' '..z else '')
 elseif property=='scale'then
  local x,y,z=op.Value,op.Y or op.Value,op.Z or 1
  return number(x)..(if y~=x or z~=1 then ' '..number(y)else '')..(if z~=1 then ' '..number(z)else '')
 else
  if op.Kind=='rotate'then return number(op.Value)..'deg'
  elseif op.Kind=='tilt'then return op.Axis..' '..number(op.Value)..'deg'end
  local x,y,z=op.X,op.Y,op.Z
  if x==0 and y==0 and z>0 then return number(op.Value)..'deg'
  elseif y==0 and z==0 and x>0 then return 'x '..number(op.Value)..'deg'
  elseif x==0 and z==0 and y>0 then return 'y '..number(op.Value)..'deg'end
  return number(x)..' '..number(y)..' '..number(z)..' '..number(op.Value)..'deg'
 end
end
return Values
