--!strict
-- Geometry Interfaces over realm-owned values, independent of native layout.
-- is2D is a sticky dimension flag, not a tolerance test of the matrix entries.
local Matrix=require(script.Parent.Parent.CSS.Matrix4)
local TransformParser=require(script.Parent.GeometryTransformParser)
local GeometryMath={}
local ELEMENTS={"m11","m12","m13","m14","m21","m22","m23","m24","m31","m32","m33","m34","m41","m42","m43","m44"}
local ALIASES={a=1,b=2,c=5,d=6,e=13,f=14}
local TWO_D={1,2,5,6,13,14}
local THREE_D={3,4,7,8,9,10,11,12,15,16}
function GeometryMath.install(vm: any,globals: any,options: any?): any
 options=options or {};local VM=vm.Model;local U,N=VM.Undefined,VM.Null
 local api={Alive=true};local points,matrices,quads,mutability={},{},{},{}
 for _,map in {points,matrices,quads,mutability}do setmetatable(map,{__mode='kv'})end
 local pointRO,pointProto,matrixRO,matrixProto,quadProto=vm.Object({}),nil,vm.Object({}),nil,vm.Object({})
 pointProto=vm.Object({},pointRO);matrixProto=vm.Object({},matrixRO)
 local function check()assert(api.Alive and vm.Alive,'Geometry objects disposed')end
 local function fail(name,message)
  VM.throw(if options.Events and (name=='SyntaxError'or name=='InvalidStateError')then options.Events:DOMException(message,name)else VM.error(name,message))
 end
 local function arg(args,i,default)local value=args[i];return if value==nil or value==U then default else value end
 local function number(value)return VM.number(vm.ToPrimitive(value,'number'))end
 local function numeric(args,i,default)return number(arg(args,i,default))end
 local function dictionary(value)
  if value==nil or value==U or value==N then return nil end
  if not vm.ObjectModel.IsObject(value)then fail('TypeError','Expected a geometry dictionary')end;return value
 end
 local function def(value,key,descriptor)vm.DefineProperty(value,key,vm.Object(descriptor,VM.Null))end
 local function native(name,arity,action)
  local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return action(args,receiver)end}
  def(value,'length',{value=arity,configurable=true});def(value,'name',{value=name,configurable=true});return value
 end
 local function method(proto,name,arity,action)def(proto,name,{value=native(name,arity,action),writable=true,enumerable=true,configurable=true})end
 local function accessor(proto,key,read,write)
  def(proto,key,{get=native('get '..key,0,function(_,receiver)return read(receiver)end),
   set=if write then native('set '..key,1,function(args,receiver)write(receiver,arg(args,1,U))end)else U,enumerable=true,configurable=true})
 end
 local function brand(map,value,name)check();local state=map[value];if not state then fail('TypeError',name..' requires a compatible receiver')end;return state end
 local function mutable(map,value,name)local state=brand(map,value,name);if not mutability[value]then fail('TypeError',name..' requires a mutable receiver')end;return state end
 local function construct(name,proto,action)
  local value=native(name,0,function()fail('TypeError',name..' requires new')end)
  value.Construct=function(args,newTarget)
   check();local prototype=vm.Get(newTarget or value,'prototype');if not vm.ObjectModel.IsObject(prototype)then prototype=proto end
   local result=action(args);result.Prototype=prototype;return result
  end
  def(value,'prototype',{value=proto});def(proto,'constructor',{value=value,writable=true,configurable=true})
  def(proto,vm.SymbolToStringTag,{value=name,configurable=true});globals[name]=value;vm.Global.Bindings[name]={Value=value};return value
 end
 local function point(values,mutable)
  local value=vm.Object({},if mutable then pointProto else pointRO);value.MathGeometryState=values;points[value]=values;mutability[value]=mutable;return value
 end
 local function pointDictionary(value)
  local d=dictionary(value);local result={}
  -- Web IDL dictionaries get members in lexicographic order, not IDL order.
  for _,key in {'w','x','y','z'}do local v=if d then vm.Get(d,key)else U;result[key]=if v==U then (if key=='w'then 1 else 0)else number(v)end;return result
 end
 local function matrix(values,is2D,mutable,compact)
  local state={Values=values,Is2D=is2D,Compact=compact==true};local value=vm.Object({},if mutable then matrixProto else matrixRO)
  value.MathGeometryState=state;matrices[value]=state;mutability[value]=mutable;return value
 end
 local function same(a,b)return a==b or a~=a and b~=b end
 local function matrixDictionary(value)
  local d=dictionary(value);local data={};local is2D=nil
  local keys={'a','b','c','d','e','f','m11','m12','m21','m22','m41','m42','is2D','m13','m14','m23','m24','m31','m32','m33','m34','m43','m44'}
  for _,key in keys do local item=if d then vm.Get(d,key)else U
   if item~=U then if key=='is2D'then is2D=VM.truth(item)else data[key]=number(item)end end
  end
  local result=Matrix.identity()
  for alias,index in ALIASES do
   local long=data[ELEMENTS[index]];local short=data[alias]
   if long~=nil and short~=nil and not same(long,short)then fail('TypeError','Conflicting matrix aliases')end
   result[index]=if long~=nil then long elseif short~=nil then short else result[index]
  end
  local dimensional=false
  for _,index in THREE_D do local item=data[ELEMENTS[index]];if item~=nil then result[index]=item end
   local default=if index==11 or index==16 then 1 else 0;if result[index]~=default then dimensional=true end
  end
  if is2D==true and dimensional then fail('TypeError','is2D conflicts with 3D matrix values')end
  return result,if is2D==nil then not dimensional else is2D
 end
 local function sequence(value,iteratorMethod)
  if not vm.ObjectModel.IsObject(value)then fail('TypeError','Matrix input must be a sequence')end
  local iterator=vm:Call(iteratorMethod,{},value)
  if not vm.ObjectModel.IsObject(iterator)then fail('TypeError','Iterator is not an object')end
  local nextMethod=vm.Get(iterator,'next');local result={}
  while true do vm.Step();local entry=vm:Call(nextMethod,{},iterator)
   if not vm.ObjectModel.IsObject(entry)then fail('TypeError','Iterator result is not an object')end
   if VM.truth(vm.Get(entry,'done'))then break end
   local item=vm.Get(entry,'value')
   -- Web IDL sequence conversion does not close the source on conversion error.
   local n=number(item)
   if #result>=16384 then fail('RangeError','Matrix input sequence budget exceeded')end;table.insert(result,n)
  end
  if #result~=6 and #result~=16 then fail('TypeError','A matrix sequence must have 6 or 16 values')end
  if #result==16 then return result,false end
  local values=Matrix.identity();for i,index in TWO_D do values[index]=result[i]end;return values,true
 end
 local function parse(source)
  if #source>65536 then fail('RangeError','Matrix string budget exceeded')end
  local values,is2D,compact=TransformParser.parse(source);if not values then fail('SyntaxError','Invalid absolute CSS transform')end
  return values,is2D,compact
 end
 local function input(value)
  if value==nil or value==U then return Matrix.identity(),true,true end
  if type(value)=='string'then return parse(value)end
  if vm.ObjectModel.IsObject(value)then
   local method=vm.Get(value,vm.SymbolIterator)
   if method~=U and method~=N then if not VM.callable(method)then fail('TypeError','Matrix input iterator is not callable')end;return sequence(value,method)end
  end
  local raw=vm.ToPrimitive(value,'string');if type(raw)=='table'and raw.Kind=='symbol'then fail('TypeError','Cannot convert Symbol to matrix string')end
  return parse(VM.string(raw))
 end
 local makePoint=function(args)return {x=numeric(args,1,0),y=numeric(args,2,0),z=numeric(args,3,0),w=numeric(args,4,1)}end
 for _,spec in {{'DOMPointReadOnly',pointRO,false},{'DOMPoint',pointProto,true}}do
  local constructor=construct(spec[1],spec[2],function(args)return point(makePoint(args),spec[3])end)
  method(constructor,'fromPoint',0,function(args)return point(pointDictionary(arg(args,1,U)),spec[3])end)
 end
 vm.SetPrototype(globals.DOMPoint,globals.DOMPointReadOnly)
 for _,key in {'x','y','z','w'}do
  accessor(pointRO,key,function(value)return brand(points,value,'DOMPointReadOnly')[key]end)
  accessor(pointProto,key,function(value)return mutable(points,value,'DOMPoint')[key]end,function(value,item)mutable(points,value,'DOMPoint')[key]=number(item)end)
 end
 method(pointRO,'toJSON',0,function(_,value)local p=brand(points,value,'DOMPointReadOnly.toJSON');return vm.Object({x=p.x,y=p.y,z=p.z,w=p.w},nil,{'x','y','z','w'})end)
 local function transform(values,p,is2D)
  if is2D and p.z==0 and p.w==1 then return point({x=values[1]*p.x+values[5]*p.y+values[13],y=values[2]*p.x+values[6]*p.y+values[14],z=0,w=1},true)end
  local out={};for row,key in {'x','y','z','w'}do out[key]=values[row]*p.x+values[4+row]*p.y+values[8+row]*p.z+values[12+row]*p.w end;return point(out,true)
 end
 method(pointRO,'matrixTransform',0,function(args,value)local p=brand(points,value,'DOMPointReadOnly.matrixTransform');local m,is2D=matrixDictionary(arg(args,1,U));return transform(m,p,is2D)end)
 for _,spec in {{'DOMMatrixReadOnly',matrixRO,false},{'DOMMatrix',matrixProto,true}}do
  local constructor=construct(spec[1],spec[2],function(args)local values,is2D,compact=input(arg(args,1,U));return matrix(values,is2D,spec[3],compact)end)
  method(constructor,'fromMatrix',0,function(args)local values,is2D=matrixDictionary(arg(args,1,U));return matrix(values,is2D,spec[3])end)
  for _,kind in {'Float32Array','Float64Array'}do method(constructor,'from'..kind,1,function(args)
   if #args<1 then fail('TypeError','Matrix typed-array factory requires an argument')end
   local value=args[1];local info=options.Binary and options.Binary:Describe(value)
   if not info or info.Kind~=kind or info.Detached then fail('TypeError','Expected a live '..kind)end
   if info.Length~=6 and info.Length~=16 then fail('TypeError','A matrix array must have 6 or 16 values')end
   local bytes=buffer.fromstring(options.Binary:ReadBytes(value));local size=if kind=='Float32Array'then 4 else 8
   local values=Matrix.identity();for i=1,info.Length do
    local n=if size==4 then buffer.readf32(bytes,(i-1)*size)else buffer.readf64(bytes,(i-1)*size)
    values[if info.Length==6 then TWO_D[i]else i]=n
   end
   return matrix(values,info.Length==6,spec[3])
  end)end
 end
 vm.SetPrototype(globals.DOMMatrix,globals.DOMMatrixReadOnly)
 globals.WebKitCSSMatrix=globals.DOMMatrix;vm.Global.Bindings.WebKitCSSMatrix={Value=globals.DOMMatrix}
 local function setElement(value,index,item)
  local s=mutable(matrices,value,'DOMMatrix');local n=number(item);s.Values[index]=n;s.Compact=false
  if table.find(THREE_D,index)and n~=(if index==11 or index==16 then 1 else 0)then s.Is2D=false end
 end
 local function matrixAccessor(key,index)
  accessor(matrixRO,key,function(value)return brand(matrices,value,'DOMMatrixReadOnly').Values[index]end)
  accessor(matrixProto,key,function(value)return mutable(matrices,value,'DOMMatrix').Values[index]end,function(value,item)setElement(value,index,item)end)
 end
 for i,key in ELEMENTS do matrixAccessor(key,i)end;for key,i in ALIASES do matrixAccessor(key,i)end
 accessor(matrixRO,'is2D',function(value)return brand(matrices,value,'DOMMatrixReadOnly').Is2D end)
 accessor(matrixRO,'isIdentity',function(value)local s=brand(matrices,value,'DOMMatrixReadOnly');for i,n in s.Values do if n~=(if i==1 or i==6 or i==11 or i==16 then 1 else 0)then return false end end;return true end)
 local function affine(values)
  for _,i in THREE_D do if values[i]~=(if i==11 or i==16 then 1 else 0)then return false end end;return true
 end
 local function product(a,b)
  local out=Matrix.identity()
  if affine(a)and affine(b)then
   out[1],out[2]=a[1]*b[1]+a[5]*b[2],a[2]*b[1]+a[6]*b[2]
   out[5],out[6]=a[1]*b[5]+a[5]*b[6],a[2]*b[5]+a[6]*b[6]
   out[13],out[14]=a[1]*b[13]+a[5]*b[14]+a[13],a[2]*b[13]+a[6]*b[14]+a[14]
  else
   for col=0,3 do for row=1,4 do
    out[col*4+row]=a[row]*b[col*4+1]+a[4+row]*b[col*4+2]+a[8+row]*b[col*4+3]+a[12+row]*b[col*4+4]
   end end
  end;return out
 end
 -- Browser matrix backends keep default axis-aligned transforms compact until
 -- a full-matrix operation occurs. This is observable for NaN and signed zero;
 -- do not infer this history from the visible entries or the sticky is2D flag.
 local function multiply(s,other,is2D,pre)
  if s.Compact then
   local a=s.Values;local out=table.clone(other)
   if pre then
    for row=1,4 do out[12+row]=other[row]*a[13]+other[4+row]*a[14]+other[12+row]end
    for row=1,4 do out[row]*=a[1];out[4+row]*=a[6]end
   else
    if a[1]~=1 then for col=0,3 do out[col*4+1]*=a[1]end end
    if a[6]~=1 then for col=0,3 do out[col*4+2]*=a[6]end end
    if out[4]==0 and out[8]==0 and out[12]==0 and out[16]==1 then out[13]+=a[13];out[14]+=a[14]
    else
     if a[13]~=0 then for col=0,3 do out[col*4+1]+=out[col*4+4]*a[13]end end
     if a[14]~=0 then for col=0,3 do out[col*4+2]+=out[col*4+4]*a[14]end end
    end
   end;s.Values=out
  else s.Values=if pre then product(other,s.Values)else product(s.Values,other)end
  s.Compact=false;s.Is2D=s.Is2D and is2D
 end
 local function inverse(values)
  local rows={};for r=1,4 do rows[r]={};for c=1,4 do local n=values[(c-1)*4+r];if n~=n or math.abs(n)==math.huge then return nil end;rows[r][c]=n;rows[r][c+4]=if r==c then 1 else 0 end end
  for c=1,4 do local pivot=c;for r=c+1,4 do if math.abs(rows[r][c])>math.abs(rows[pivot][c])then pivot=r end end
   if rows[pivot][c]==0 then return nil end;rows[c],rows[pivot]=rows[pivot],rows[c];local n=rows[c][c]
   for i=1,8 do rows[c][i]/=n end
   for r=1,4 do if r~=c then local factor=rows[r][c];for i=1,8 do rows[r][i]-=factor*rows[c][i]end end end
  end
  local result={};for c=1,4 do for r=1,4 do local n=rows[r][c+4];if n~=n or math.abs(n)==math.huge then return nil end;result[(c-1)*4+r]=n end end;return result
 end
 local function sincos(angle)
  local reduced=angle%360
  if reduced==0 then return 0,1 elseif reduced==90 then return 1,0 elseif reduced==180 then return 0,-1 elseif reduced==270 then return -1,0 end
  local radians=math.rad(reduced);return math.sin(radians),math.cos(radians)
 end
 local function rotatePlane(s,first,second,angle,reverse)
  local sine,cosine=sincos(angle);if sine==0 and cosine==1 then return end
  s.Compact=false;local values=s.Values;local a,b=(first-1)*4,(second-1)*4
  for row=1,4 do local x,y=values[a+row],values[b+row]
   if reverse then values[a+row],values[b+row]=x*cosine-y*sine,y*cosine+x*sine
   else values[a+row],values[b+row]=x*cosine+y*sine,y*cosine-x*sine end
  end
 end
 local function rotateAxis(s,x,y,z,angle)
  local sine,cosine=sincos(angle);if sine==0 and cosine==1 then return end
  local scale=math.max(math.abs(x),math.abs(y),math.abs(z));if scale==0 then return end
  -- Scaling first avoids throwing away valid very small/large finite axes.
  x,y,z=x/scale,y/scale,z/scale;local norm=math.sqrt(x*x+y*y+z*z);x,y,z=x/norm,y/norm,z/norm
  if z==1 then rotatePlane(s,1,2,angle,false)
  elseif y==1 then rotatePlane(s,1,3,angle,true)
  elseif x==1 then rotatePlane(s,2,3,angle,false)
  else
   local t=1-cosine;local m={t*x*x+cosine,t*x*y+sine*z,t*x*z-sine*y,0,t*x*y-sine*z,t*y*y+cosine,t*y*z+sine*x,0,t*x*z+sine*y,t*y*z-sine*x,t*z*z+cosine,0,0,0,0,1}
   s.Compact=false;s.Values=product(s.Values,m)
  end
 end
 local function translate(s,x,y,z)
  if x==0 and y==0 and z==0 then return end
  if z~=0 then s.Is2D=false;s.Compact=false end
  local m=s.Values
  if s.Compact then m[13]+=m[1]*x;m[14]+=m[6]*y
  elseif z==0 then for row=1,4 do m[12+row]=m[row]*x+m[4+row]*y+m[12+row]end
  else for row=1,4 do m[12+row]=m[row]*x+m[4+row]*y+m[8+row]*z+m[12+row]end end
 end
 local function scaled(s,x,y,z,ox,oy,oz)
  if z~=1 or oz~=0 then s.Is2D=false end
  if x==1 and y==1 and z==1 then return end
  local origin=ox~=0 or oy~=0 or oz~=0;if origin then translate(s,ox,oy,oz)end
  if z~=1 then s.Compact=false end
  local m=s.Values
  if s.Compact then m[1]*=x;m[6]*=y
  else for row=1,4 do m[row]*=x;m[4+row]*=y;if z~=1 then m[8+row]*=z end end end
  if origin then translate(s,-ox,-oy,-oz)end
 end
 -- Web IDL argument conversion runs before an algorithm copies or changes its
 -- receiver: valueOf/getters are allowed to change the matrix being operated on.
 local prepare,actions={},{}
 prepare.translate=function(args)return {numeric(args,1,0),numeric(args,2,0),numeric(args,3,0)}end
 prepare.scale=function(args)local x=numeric(args,1,1);return {x,numeric(args,2,x),numeric(args,3,1),numeric(args,4,0),numeric(args,5,0),numeric(args,6,0)}end
 prepare.scaleNonUniform=function(args)return {numeric(args,1,1),numeric(args,2,1)}end
 prepare.scale3d=function(args)return {numeric(args,1,1),numeric(args,2,0),numeric(args,3,0),numeric(args,4,0)}end
 prepare.rotate=function(args)
  local x=numeric(args,1,0);local y,z=arg(args,2,U),arg(args,3,U)
  if y==U and z==U then return {0,0,x}end
  return {x,if y==U then 0 else number(y),if z==U then 0 else number(z)}
 end
 prepare.rotateFromVector=function(args)return {numeric(args,1,0),numeric(args,2,0)}end
 prepare.rotateAxisAngle=function(args)return {numeric(args,1,0),numeric(args,2,0),numeric(args,3,0),numeric(args,4,0)}end
 prepare.skewX=function(args)return {numeric(args,1,0)}end;prepare.skewY=prepare.skewX
 prepare.multiply=function(args)local m,is2D=matrixDictionary(arg(args,1,U));return {m,is2D}end;prepare.preMultiply=prepare.multiply
 local function convert(name,args)return if prepare[name]then prepare[name](args)else {}end
 actions.translate=function(s,args)translate(s,args[1],args[2],args[3])end
 actions.scale=function(s,args)scaled(s,table.unpack(args))end
 actions.scaleNonUniform=function(s,args)scaled(s,args[1],args[2],1,0,0,0)end
 actions.scale3d=function(s,args)local n=args[1];scaled(s,n,n,n,args[2],args[3],args[4])end
 actions.rotate=function(s,args)
  local x,y,z=args[1],args[2],args[3]
  if z~=0 then rotatePlane(s,1,2,z,false)end
  if y~=0 then rotatePlane(s,1,3,y,true);s.Is2D=false end
  if x~=0 then rotatePlane(s,2,3,x,false);s.Is2D=false end
 end
 actions.rotateFromVector=function(s,args)rotatePlane(s,1,2,math.deg(math.atan2(args[2],args[1])),false)end
 actions.rotateAxisAngle=function(s,args)local x,y,z,a=table.unpack(args);rotateAxis(s,x,y,z,a);if x~=0 or y~=0 then s.Is2D=false end end
 local function skew(s,x,y)
  if x==0 and y==0 then return end;s.Compact=false;local m=s.Values
  local tx,ty=math.tan(math.rad(x)),math.tan(math.rad(y))
  for row=1,4 do local a,b=m[row],m[4+row];m[row],m[4+row]=a+b*ty,b+a*tx end
 end
 actions.skewX=function(s,args)skew(s,args[1],0)end
 actions.skewY=function(s,args)skew(s,0,args[1])end
 actions.multiply=function(s,args)multiply(s,args[1],args[2],false)end
 actions.preMultiply=function(s,args)multiply(s,args[1],args[2],true)end
 actions.flipX=function(s)s.Compact=false;for i=1,4 do s.Values[i]=-s.Values[i]end end
 actions.flipY=function(s)s.Compact=false;for i=5,8 do s.Values[i]=-s.Values[i]end end
 actions.inverse=function(s)local result=inverse(s.Values);if result then s.Values=result else s.Values=table.create(16,0/0);s.Is2D=false;s.Compact=false end end
 for _,name in {'translate','scale','scaleNonUniform','scale3d','rotate','rotateFromVector','rotateAxisAngle','skewX','skewY','multiply','flipX','flipY','inverse'}do method(matrixRO,name,0,function(args,value)
  local s=brand(matrices,value,'DOMMatrixReadOnly.'..name);local converted=convert(name,args)
  local result=matrix(table.clone(s.Values),s.Is2D,true,s.Compact);actions[name](matrices[result],converted);return result
 end)end
 for _,entry in {{'translateSelf','translate'},{'scaleSelf','scale'},{'scale3dSelf','scale3d'},{'rotateSelf','rotate'},{'rotateFromVectorSelf','rotateFromVector'},{'rotateAxisAngleSelf','rotateAxisAngle'},{'skewXSelf','skewX'},{'skewYSelf','skewY'},{'multiplySelf','multiply'},{'preMultiplySelf','preMultiply'},{'invertSelf','inverse'}}do method(matrixProto,entry[1],0,function(args,value)
  local s=mutable(matrices,value,'DOMMatrix.'..entry[1]);local converted=convert(entry[2],args);actions[entry[2]](s,converted);return value
 end)end
 method(matrixProto,'setMatrixValue',1,function(args,value)
  local s=mutable(matrices,value,'DOMMatrix.setMatrixValue');if #args<1 then fail('TypeError','setMatrixValue requires a transform string')end
  local raw=vm.ToPrimitive(args[1],'string');if type(raw)=='table'and raw.Kind=='symbol'then fail('TypeError','Cannot convert Symbol to string')end
  local values,is2D,compact=parse(VM.string(raw));s.Values,s.Is2D,s.Compact=values,is2D,compact==true;return value
 end)
 method(matrixRO,'transformPoint',0,function(args,value)local s=brand(matrices,value,'DOMMatrixReadOnly.transformPoint');local p=pointDictionary(arg(args,1,U));return transform(s.Values,p,s.Is2D)end)
 for _,name in {'toFloat32Array','toFloat64Array'}do method(matrixRO,name,0,function(_,value)
  local s=brand(matrices,value,'DOMMatrixReadOnly.'..name);if not options.Binary then fail('TypeError','Binary geometry adapter is unavailable')end
  local kind=if name=='toFloat32Array'then 'Float32Array'else 'Float64Array';local size=if kind=='Float32Array'then 4 else 8
  local bytes=buffer.create(16*size);for i,n in s.Values do if size==4 then buffer.writef32(bytes,(i-1)*size,n)else buffer.writef64(bytes,(i-1)*size,n)end end
  return options.Binary:CreateView(kind,options.Binary:Buffer(buffer.tostring(bytes)),0,16)
 end)end
 method(matrixRO,'toString',0,function(_,value)
  local s=brand(matrices,value,'DOMMatrixReadOnly.toString');local out={}
  for _,n in s.Values do if n~=n or math.abs(n)==math.huge then fail('InvalidStateError','Cannot serialize a non-finite matrix')end end
  for _,i in (if s.Is2D then TWO_D else {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16})do table.insert(out,VM.string(s.Values[i]))end
  return (if s.Is2D then 'matrix('else 'matrix3d(')..table.concat(out,', ')..')'
 end)
 method(matrixRO,'toJSON',0,function(_,value)
  local s=brand(matrices,value,'DOMMatrixReadOnly.toJSON');local out={is2D=s.Is2D,isIdentity=true}
  for i,name in ELEMENTS do out[name]=s.Values[i];if s.Values[i]~=(if i==1 or i==6 or i==11 or i==16 then 1 else 0)then out.isIdentity=false end end
  local order={'a','b','c','d','e','f'};for _,name in ELEMENTS do table.insert(order,name)end;table.insert(order,'is2D');table.insert(order,'isIdentity')
  for name,i in ALIASES do out[name]=s.Values[i]end;return vm.Object(out,nil,order)
 end)
 local function quad(p)
  local value=vm.Object({},quadProto);local state={};for i=1,4 do state[i]=point(p[i],true)end;value.MathGeometryState=state;quads[value]=state;return value
 end
 local quadConstructor=construct('DOMQuad',quadProto,function(args)local p={};for i=1,4 do p[i]=pointDictionary(arg(args,i,U))end;return quad(p)end)
 for i=1,4 do accessor(quadProto,'p'..i,function(value)return brand(quads,value,'DOMQuad')[i]end)end
 method(quadConstructor,'fromRect',0,function(args)
  local d=dictionary(arg(args,1,U));local data={};for _,key in {'height','width','x','y'}do local n=if d then vm.Get(d,key)else U;data[key]=if n==U then 0 else number(n)end
  local x,y,w,h=data.x,data.y,data.width,data.height;return quad({{x=x,y=y,z=0,w=1},{x=x+w,y=y,z=0,w=1},{x=x+w,y=y+h,z=0,w=1},{x=x,y=y+h,z=0,w=1}})
 end)
 method(quadConstructor,'fromQuad',0,function(args)local d=dictionary(arg(args,1,U));local p={};for i=1,4 do p[i]=pointDictionary(if d then vm.Get(d,'p'..i)else U)end;return quad(p)end)
 method(quadProto,'getBounds',0,function(_,value)
  local s=brand(quads,value,'DOMQuad.getBounds');local x,y,r,b=math.huge,math.huge,-math.huge,-math.huge
  for _,v in s do local p=points[v];x=if x~=x or p.x~=p.x then 0/0 else math.min(x,p.x);y=if y~=y or p.y~=p.y then 0/0 else math.min(y,p.y);r=if r~=r or p.x~=p.x then 0/0 else math.max(r,p.x);b=if b~=b or p.y~=p.y then 0/0 else math.max(b,p.y)end
  return options.Rect(x,y,r-x,b-y,false)
 end)
 method(quadProto,'toJSON',0,function(_,value)local s=brand(quads,value,'DOMQuad.toJSON');return vm.Object({p1=s[1],p2=s[2],p3=s[3],p4=s[4]},nil,{'p1','p2','p3','p4'})end)
 function api:Describe(value)
  check();local p=points[value];if p then return {Kind=if mutability[value]then 'DOMPoint'else 'DOMPointReadOnly',Data=table.clone(p),ByteLength=32}end
  local m=matrices[value];if m then
   -- A 2D serialization contains six entries; the remaining ten are rebuilt
   -- from the identity matrix, including normalization of otherwise hidden -0.
   local values=if m.Is2D then Matrix.identity()else table.clone(m.Values)
   if m.Is2D then for _,i in TWO_D do values[i]=m.Values[i]end end
   return {Kind=if mutability[value]then 'DOMMatrix'else 'DOMMatrixReadOnly',Data={Values=values,Is2D=m.Is2D},ByteLength=if m.Is2D then 49 else 129}
  end
  local q=quads[value];if q then return {Kind='DOMQuad',Data=table.clone(q),ByteLength=0}end
  return nil
 end
 function api:Restore(record)
  check();local kind,data=record.Kind,record.Data
  if kind=='DOMPoint'or kind=='DOMPointReadOnly'then return point(table.clone(data),kind=='DOMPoint')end
  if kind=='DOMMatrix'or kind=='DOMMatrixReadOnly'then return matrix(table.clone(data.Values),data.Is2D,kind=='DOMMatrix',false)end
  if kind=='DOMQuad'then
   local state=table.clone(data);for _,p in state do if not points[p]or not mutability[p]then fail('TypeError','DOMQuad clone requires mutable points')end end
   local value=vm.Object({},quadProto);value.MathGeometryState=state;quads[value]=state;return value
  end
  return nil
 end
 function api:Destroy()if not self.Alive then return end;self.Alive=false;for _,map in {points,matrices,quads,mutability}do table.clear(map)end;table.clear(options)end
 return api
end
return GeometryMath
