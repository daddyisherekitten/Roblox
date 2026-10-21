--!strict
-- CSS transform parsing, ordered 4x4 composition and function-list interpolation.
local Syntax = require(script.Parent.Syntax)
local LengthExpression = require(script.Parent.LengthExpression)
local Matrix4 = require(script.Parent.Matrix4)
local BorderGeometry = require(script.Parent.Parent.Layout.BorderGeometry)

local Transform2D = {}

-- Transform reference boxes for elements that have a CSS layout box. SVG
-- shape fill/stroke bounds belong to the separate SVG transform pipeline.
function Transform2D.layoutReference(style: any,width: number,height: number): any
	if style.TransformBox~='content-box'and style.TransformBox~='fill-box'then return {X=0,Y=0,W=width,H=height}end
	local t,r,b,l=BorderGeometry.sizes(style);local p=style.Padding or{0,0,0,0}
	return {X=l+p[4],Y=t+p[1],W=math.max(0,width-l-r-p[4]-p[2]),H=math.max(0,height-t-b-p[1]-p[3])}
end

local function arguments(source: string): {string}
	local result, cursor = {}, 1
	while cursor <= #source do
		local value, nextCursor = Syntax.scan(source, cursor, ", \t\r\n")
		cursor = nextCursor
		value = value:match("^%s*(.-)%s*$") :: string
		if value ~= "" then table.insert(result, value) end
	end
	return result
end

local function number(source: string): number?
	if not source:match("^[%+%-]?%d*%.?%d+[eE]?[%+%-]?%d*$") then return nil end
	local value = tonumber(source)
	return if value and value==value and math.abs(value) <= 1e12 then value else nil
end

local function scaleNumber(source: string): number?
 if source:sub(-1)=="%" then local n=number(source:sub(1,-2));return if n then n/100 else nil end
 return number(source)
end

local function angle(source: string): number?
	local raw, unit = source:match("^([%+%-]?%d*%.?%d+[eE]?[%+%-]?%d*)([%a]+)$")
	if not raw then
		return if source == "0" or source == "+0" or source == "-0" then 0 else nil
	end
	unit=unit:lower()
	if unit~="deg" and unit~="grad" and unit~="rad" and unit~="turn" then return nil end
	local value = tonumber(raw)
	if not value or math.abs(value) > 100000 then return nil end
	if unit == "grad" then value *= .9 elseif unit == "rad" then value = math.deg(value) elseif unit == "turn" then value *= 360 end
	return value
end

function Transform2D.parse(source: string, length: (string, boolean?)->any?): any?
	if source == "none" then return {} end
	local result, cursor = {}, 1
	while cursor <= #source do
		local token, nextCursor = Syntax.scan(source, cursor, " \t\r\n")
		cursor = nextCursor
		if token == "" then continue end
		local name, body = token:match("^([%a][%w%-]*)%((.*)%)$")
		if not name then return nil end
		name = name:lower()
		local args = arguments(body)
		if name == "translate" or name == "translatex" or name == "translatey" then
			local expected = if name == "translate" then (#args >= 1 and #args <= 2) else #args == 1
			if not expected then return nil end
			local zero = {Value=0,Percent=false}
			local x = if name == "translatey" then zero else length(args[1], true)
			local y = if name == "translatex" then zero elseif name == "translatey" then length(args[1], true) elseif args[2] then length(args[2], true) else zero
			if not x or not y then return nil end
			table.insert(result,{Kind="translate",X=x,Y=y})
		elseif name == "rotate" or name == "rotatez" then
			if #args ~= 1 then return nil end
			local value=angle(args[1]);if value==nil then return nil end
			table.insert(result,{Kind="rotate",Value=value})
		elseif name == "rotatex" or name == "rotatey" then
			if #args~=1 then return nil end;local value=angle(args[1]);if value==nil then return nil end
			table.insert(result,{Kind="tilt",Axis=if name=="rotatex" then "x" else "y",Value=value})
		elseif name == "translate3d" then
			if #args~=3 then return nil end;local x,y,z=length(args[1],true),length(args[2],true),length(args[3],true)
			if not x or not y or not z or z.Percent then return nil end;table.insert(result,{Kind="translate",X=x,Y=y,Z=z})
		elseif name == "translatez" then
			if #args~=1 then return nil end;local z=length(args[1],true);if not z or z.Percent then return nil end
			table.insert(result,{Kind="translate",X={Value=0,Percent=false},Y={Value=0,Percent=false},Z=z})
		elseif name == "scale" or name=="scalex" or name=="scaley" or name=="scalez" then
			if #args<1 or #args>(if name=="scale" then 2 else 1) then return nil end
			local value=scaleNumber(args[1]);local second=if args[2] then scaleNumber(args[2]) else value
			if value==nil or second==nil then return nil end
			if name=="scale" then table.insert(result,{Kind="scale",Value=value,Y=second})
			else table.insert(result,{Kind="scale",Value=if name=="scalex" then value else 1,Y=if name=="scaley" then value else 1,Z=if name=="scalez" then value else 1}) end
		elseif name == "scale3d" then
			if #args~=3 then return nil end;local x,y,z=scaleNumber(args[1]),scaleNumber(args[2]),scaleNumber(args[3])
			if not x or not y or not z then return nil end;table.insert(result,{Kind="scale",Value=x,Y=y,Z=z})
		elseif name=="rotate3d" then
			if #args~=4 then return nil end;local x,y,z,value=number(args[1]),number(args[2]),number(args[3]),angle(args[4])
			if not x or not y or not z or value==nil then return nil end
			table.insert(result,{Kind="rotate3d",X=x,Y=y,Z=z,Value=value})
		elseif name=="matrix" or name=="matrix3d" then
			if #args~=(if name=="matrix" then 6 else 16) then return nil end
			local values={};for _,arg in args do local value=number(arg);if value==nil then return nil end;table.insert(values,value) end
			if name=="matrix" then values={values[1],values[2],0,0,values[3],values[4],0,0,0,0,1,0,values[5],values[6],0,1} end
			table.insert(result,{Kind="matrix",Values=values})
		elseif name=="skew" or name=="skewx" or name=="skewy" then
			if #args<1 or #args>(if name=="skew" then 2 else 1) then return nil end
			local x=if name=="skewy" then 0 else angle(args[1]);local y=if name=="skewy" then angle(args[1]) elseif args[2] then angle(args[2]) else 0
			if x==nil or y==nil then return nil end;table.insert(result,{Kind="skew",X=x,Y=y})
		elseif name == "perspective" then
 if #args==1 and args[1]=="none" then table.insert(result,{Kind="perspective",Value=math.huge,FunctionName=name});continue end
			if #args~=1 then return nil end;local depth=length(args[1]);if not depth or depth.Percent or depth.Value<0 then return nil end
			table.insert(result,{Kind="perspective",Value=depth.Value})
		else return nil end
		-- Retain the authored function form for CSS keyframe endpoint export.
		-- Geometry and interpolation continue to use the shared primitive Kind.
		result[#result].FunctionName=name
		if #result > 16 then return nil end
	end
	return if #result > 0 then result else nil
end

function Transform2D.parseIndividual(kind: string, source: string, length: (string, boolean?)->any?): (any?, boolean)
	if source:lower()=="none" then return nil,true end
	local args=arguments(source)
	if kind=="translate" and #args==3 then kind="translate3d"
	elseif kind=="scale" and #args==3 then kind="scale3d"
	elseif kind=="rotate" and #args>1 then
		-- <angle> && <axis> allows the angle before or after its axis.
		if #args==2 then
			local first,last=args[1]:lower(),args[2]:lower()
			if first=='x'or first=='y'or first=='z'then kind='rotate'..first;source=args[2]
			elseif last=='x'or last=='y'or last=='z'then kind='rotate'..last;source=args[1]
			else return nil,false end
		elseif #args==4 then
			kind='rotate3d';if angle(args[1])~=nil and number(args[1])==nil then source=table.concat({args[2],args[3],args[4],args[1]},',')end
		else return nil,false end
	end
	local parsed=Transform2D.parse(kind.."("..source..")",length)
	return if parsed then parsed[1] else nil,parsed~=nil
end

function Transform2D.operations(style: any, transformOverride: any?): any
	local result={}
	if style.Translate then table.insert(result,style.Translate)end
	if style.Rotate then table.insert(result,style.Rotate)end
	if style.Scale then table.insert(result,style.Scale)end
	for _,operation in transformOverride or style.Transform or {} do table.insert(result,operation) end
	return result
end

local function originPart(source: string, length: (string, boolean?)->any?): any?
	if source == "left" or source == "top" then return {Value=0,Percent=true} end
	if source == "center" then return {Value=50,Percent=true} end
	if source == "right" or source == "bottom" then return {Value=100,Percent=true} end
	return length(source,true)
end

function Transform2D.parseOrigin(source: string, length: (string, boolean?)->any?): any?
	local values=arguments(source)
	if #values<1 or #values>3 then return nil end
	local first,second=values[1],values[2]
	local firstVertical=first=="top" or first=="bottom"
	local secondHorizontal=second=="left" or second=="right"
	if firstVertical and not second then first,second="center",first
 elseif (firstVertical and (secondHorizontal or second=="center")) or (first=="center" and secondHorizontal) then first,second=second,first end
	if (first=="top" or first=="bottom") or (second=="left" or second=="right") then return nil end
	local x=originPart(first,length);local y=originPart(second or "center",length)
	if not x or not y then return nil end
	local z=if values[3] then length(values[3],true) else nil
	if values[3] and (not z or z.Percent or z.HasPercent or z.Expression and z.Expression.HasPercent) then return nil end
	return {X=x,Y=y,Z=z}
end

function Transform2D.matrix(operations: any,width: number,height: number): any
 local matrix=Matrix4.identity()
 for _,op in operations or {} do
  local value
  if op.Kind=="translate" then value=Matrix4.translate(LengthExpression.resolve(op.X,width),LengthExpression.resolve(op.Y,height),if op.Z then LengthExpression.resolve(op.Z,0) else 0)
  elseif op.Kind=="scale" then value=Matrix4.scale(op.Value,op.Y or op.Value,op.Z or 1)
  elseif op.Kind=="rotate" then value=Matrix4.rotate(0,0,1,op.Value)
  elseif op.Kind=="tilt" then value=Matrix4.rotate(if op.Axis=="x" then 1 else 0,if op.Axis=="y" then 1 else 0,0,op.Value)
  elseif op.Kind=="rotate3d" then value=Matrix4.rotate(op.X,op.Y,op.Z,op.Value)
  elseif op.Kind=="perspective" then value=Matrix4.perspective(op.Value)
  elseif op.Kind=="matrix" then value=op.Values
  elseif op.Kind=="skew" then value=Matrix4.identity();value[5]=math.tan(math.rad(op.X));value[2]=math.tan(math.rad(op.Y))
  end
  if value then matrix=Matrix4.multiply(matrix,value) end
 end
 return matrix
end
function Transform2D.resolve(operations: any,width: number,height: number): any
 local m=Transform2D.matrix(operations,width,height)
 return {X=m[13],Y=m[14],Scale=math.sqrt(m[1]^2+m[2]^2),Rotation=math.deg(math.atan2(m[2],m[1])),BackFacing=Matrix4.backFacing(m),Matrix=m,Projected=not Matrix4.native(m),Operations=operations}
end

function Transform2D.origin(value: any,width: number,height: number): (number,number)
	return LengthExpression.resolve(value.X,width),LengthExpression.resolve(value.Y,height)
end

function Transform2D.interpolate(a: any,b: any,t: number,width: number,height: number): any
	local result={}
	local function mix(x: number,y: number): number return x+(y-x)*t end
	local function pixel(value: any,reference: number): number return if value then LengthExpression.resolve(value,reference) else 0 end
	for i=1,math.max(#a,#b) do
		local left,right=a[i],b[i];local model=left or right
		if not left or not right then
			local neutral=table.clone(model)
			if model.Kind=="translate" then neutral.X,neutral.Y,neutral.Z={Value=0,Percent=false},{Value=0,Percent=false},{Value=0,Percent=false}
			elseif model.Kind=="scale" then neutral.Value,neutral.Y,neutral.Z=1,1,1
			elseif model.Kind=="perspective" then neutral.Value=math.huge
			elseif model.Kind=="matrix" then neutral.Values=Matrix4.identity()
			elseif model.Kind=="skew" then neutral.X,neutral.Y=0,0
			else neutral.Value=0 end
			left,right=left or neutral,right or neutral
		end
		if left.Kind~=right.Kind or left.Kind=="matrix" or (left.Kind=="tilt" and left.Axis~=right.Axis) or (left.Kind=="rotate3d" and (left.X~=right.X or left.Y~=right.Y or left.Z~=right.Z)) then
			local aa,bb={},{};for k=i,#a do table.insert(aa,a[k]) end;for k=i,#b do table.insert(bb,b[k]) end
			table.insert(result,{Kind="matrix",Values=Matrix4.interpolate(Transform2D.matrix(aa,width,height),Transform2D.matrix(bb,width,height),t)});break
		end
		local op=table.clone(left)
		if op.Kind=="translate" then
			op.X={Value=mix(pixel(left.X,width),pixel(right.X,width)),Percent=false};op.Y={Value=mix(pixel(left.Y,height),pixel(right.Y,height)),Percent=false};op.Z={Value=mix(pixel(left.Z,0),pixel(right.Z,0)),Percent=false}
		elseif op.Kind=="scale" then op.Value=mix(left.Value,right.Value);op.Y=mix(left.Y or left.Value,right.Y or right.Value);op.Z=mix(left.Z or 1,right.Z or 1)
		elseif op.Kind=="perspective" then local inverse=mix(1/math.max(1,left.Value),1/math.max(1,right.Value));op.Value=if inverse==0 then math.huge else 1/inverse
		elseif op.Kind=="skew" then op.X,op.Y=mix(left.X,right.X),mix(left.Y,right.Y)
		else op.Value=mix(left.Value,right.Value) end
		table.insert(result,op)
	end
	return result
end

-- Addition concatenates lists; accumulation matches primitives, pads the
-- shorter list with identities and decomposes only an unmatched suffix.
-- CSS animations and Web Animations share this path, including iterations.
function Transform2D.compose(a: any,b: any,mode: string,width: number,height: number,count: number?): any
	count=count or 1
	local result={}
	if mode~="accumulate"then
		for _,op in a do table.insert(result,op)end
		if count==1 then for _,op in b do table.insert(result,op)end
		else
			local power=Transform2D.matrix(b,width,height);local matrix=Matrix4.identity();local n=count
			while n>0 do if n%2==1 then matrix=Matrix4.multiply(matrix,power)end;n=math.floor(n/2);if n>0 then power=Matrix4.multiply(power,power)end end
			table.insert(result,{Kind="matrix",Values=matrix})
		end
		return result
	end
	local function axis(op)
		local x,y,z=0,0,1
		if op.Kind=="tilt"then x,y,z=if op.Axis=="x"then 1 else 0,if op.Axis=="y"then 1 else 0,0
		elseif op.Kind=="rotate3d"then x,y,z=op.X,op.Y,op.Z end
		local length=math.sqrt(x*x+y*y+z*z)
		return if length>0 then {x/length,y/length,z/length}else {0,0,1}
	end
	local function rotation(op)return op.Kind=="rotate"or op.Kind=="tilt"or op.Kind=="rotate3d"end
	local function neutral(op)
		local copy=table.clone(op)
		if op.Kind=="translate"then copy.X,copy.Y,copy.Z={Value=0},{Value=0},{Value=0}
		elseif op.Kind=="scale"then copy.Value,copy.Y,copy.Z=1,1,1
		elseif op.Kind=="perspective"then copy.Value=math.huge
		elseif op.Kind=="matrix"then copy.Values=Matrix4.identity()
		elseif op.Kind=="skew"then copy.X,copy.Y=0,0
		else copy.Value=0 end
		return copy
	end
	for i=1,math.max(#a,#b)do
		local left,right=a[i],b[i];local model=left or right
		left,right=left or neutral(model),right or neutral(model)
		local leftAxis,rightAxis=if rotation(left)then axis(left)else nil,if rotation(right)then axis(right)else nil
		local sameAxis=leftAxis and rightAxis and (left.Value==0 or right.Value==0 or math.abs(leftAxis[1]-rightAxis[1])+math.abs(leftAxis[2]-rightAxis[2])+math.abs(leftAxis[3]-rightAxis[3])<1e-8)
		if left.Kind~=right.Kind and not sameAxis or left.Kind=="matrix" or rotation(left) and not sameAxis then
			local aa,bb={},{};for k=i,#a do table.insert(aa,a[k])end;for k=i,#b do table.insert(bb,b[k])end
			table.insert(result,{Kind="matrix",Values=Matrix4.accumulate(Transform2D.matrix(aa,width,height),Transform2D.matrix(bb,width,height),count)});break
		end
		local op=table.clone(left)
		if op.Kind=="translate"then
			for _,component in {"X","Y","Z"}do local basis=if component=="X"then width elseif component=="Y"then height else 0
				op[component]={Value=LengthExpression.resolve(left[component] or {Value=0},basis)+LengthExpression.resolve(right[component] or {Value=0},basis)*count,Percent=false}
			end
		elseif op.Kind=="scale"then op.Value=left.Value+(right.Value-1)*count;op.Y=(left.Y or left.Value)+((right.Y or right.Value)-1)*count;op.Z=(left.Z or 1)+((right.Z or 1)-1)*count
		elseif op.Kind=="skew"then op.X,op.Y=left.X+right.X*count,left.Y+right.Y*count
		elseif op.Kind=="perspective"then local inverse=1/math.max(1,left.Value)+count/math.max(1,right.Value);op.Value=if inverse==0 then math.huge else 1/inverse
		else
			op.Value=left.Value+right.Value*count
			if left.Kind~=right.Kind then local direction=if left.Value==0 then rightAxis else leftAxis;op.Kind="rotate3d";op.X,op.Y,op.Z=direction[1],direction[2],direction[3];op.Axis=nil end
		end
		table.insert(result,op)
	end
	return result
end

return Transform2D
