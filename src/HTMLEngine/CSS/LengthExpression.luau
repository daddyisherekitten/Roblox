--!strict
--!optimize 2
-- Parse and resolve the supported CSS <length-percentage> math profile.
local LengthExpression = {}
local Units=require(script.Parent.LengthUnits)

local LIMIT = 100000
local NODE_LIMIT = 256
local DEPTH_LIMIT = 32

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge and math.abs(value) <= LIMIT * LIMIT
end

local function viewportUnit(unit: string): boolean
	return Units.contextual(unit)
end

local function lengthLeaf(pixels: number, percent: number, viewport: boolean?): any
	return {Kind="length", Op="linear", Pixels=pixels, PercentValue=percent,
		HasPercent=percent ~= 0, UsesViewport=viewport == true}
end

local function numberLeaf(value: number): any
	return {Kind="number", Op="number", Value=value, HasPercent=false, UsesViewport=false}
end

local function combine(op: string, left: any, right: any): any?
	if op == "+" or op == "-" then
		if left.Kind ~= right.Kind then return nil end
		if left.Op == "linear" and right.Op == "linear" then
			return lengthLeaf(left.Pixels + (if op == "+" then right.Pixels else -right.Pixels),
				left.PercentValue + (if op == "+" then right.PercentValue else -right.PercentValue),
				left.UsesViewport or right.UsesViewport)
		end
		if left.Kind == "number" and left.Op == "number" and right.Op == "number" then
			return numberLeaf(left.Value + (if op == "+" then right.Value else -right.Value))
		end
		return {Kind=left.Kind, Op=if op == "+" then "add" else "subtract", Left=left, Right=right,
			HasPercent=left.HasPercent or right.HasPercent, UsesViewport=left.UsesViewport or right.UsesViewport}
	end
	if op == "*" then
		if left.Kind == "number" and right.Kind == "number" and left.Op == "number" and right.Op == "number" then
			return numberLeaf(left.Value * right.Value)
		end
		local scalar, target = if left.Kind == "number" then left else right, if left.Kind == "number" then right else left
		if scalar.Kind ~= "number" or scalar.Op ~= "number" or target.Kind ~= "length" then return nil end
		if target.Op == "linear" then
			return lengthLeaf(target.Pixels * scalar.Value, target.PercentValue * scalar.Value, target.UsesViewport)
		end
		return {Kind="length", Op="multiply", Left=target, Scalar=scalar.Value,
			HasPercent=target.HasPercent, UsesViewport=target.UsesViewport}
	end
	if right.Kind ~= "number" or right.Op ~= "number" or right.Value == 0 then return nil end
	if left.Kind == "number" and left.Op == "number" then return numberLeaf(left.Value / right.Value) end
	if left.Kind ~= "length" then return nil end
	if left.Op == "linear" then
		return lengthLeaf(left.Pixels / right.Value, left.PercentValue / right.Value, left.UsesViewport)
	end
	return {Kind="length", Op="multiply", Left=left, Scalar=1/right.Value,
		HasPercent=left.HasPercent, UsesViewport=left.UsesViewport}
end

local function evaluate(node: any, basis: number): number
	local op = node.Op
	if op == "number" then return node.Value end
	if op == "linear" then return node.Pixels + basis * node.PercentValue / 100 end
	if op == "add" then return evaluate(node.Left,basis) + evaluate(node.Right,basis) end
	if op == "subtract" then return evaluate(node.Left,basis) - evaluate(node.Right,basis) end
	if op == "multiply" then return evaluate(node.Left,basis) * node.Scalar end
	local values = node.Values
	if op == "min" then
		local result = math.huge
		for _, value in values do result = math.min(result,evaluate(value,basis)) end
		return result
	elseif op == "max" then
		local result = -math.huge
		for _, value in values do result = math.max(result,evaluate(value,basis)) end
		return result
	end
	return math.max(evaluate(values[1],basis),math.min(evaluate(values[2],basis),evaluate(values[3],basis)))
end

local function parser(source: string, context: any?, expected: string?): any?
	local state = {Source=source, Index=1, Nodes=0, Depth=0, Context=context or {}}
	local function whitespace()
		local _, finish = state.Source:find("^%s*",state.Index)
		state.Index = (finish or state.Index-1)+1
	end
	local function node(value: any): any?
		state.Nodes += 1
		return if state.Nodes <= NODE_LIMIT then value else nil
	end
	local expression: (number?) -> any?
	local function primary(depth: number?): any?
		local d = depth or 0
		if d > DEPTH_LIMIT then return nil end
		whitespace()
		local sign = 1
		local c = state.Source:sub(state.Index,state.Index)
		if c == "+" or c == "-" then sign=if c=="-" then -1 else 1;state.Index+=1;whitespace() end
		c = state.Source:sub(state.Index,state.Index)
		local result
		if c == "(" then
			state.Index+=1; result=expression(d+1); whitespace()
			if not result or state.Source:sub(state.Index,state.Index) ~= ")" then return nil end
			state.Index+=1
		else
			local tail=state.Source:sub(state.Index)
			local name=tail:match("^([%a][%w%-]*)%s*%(")
			if name then
				name=name:lower()
				if name~="calc" and name~="min" and name~="max" and name~="clamp" then return nil end
				local open=tail:find("(",1,true) :: number
				state.Index+=open
				local values={}
				repeat
					local value=expression(d+1);if not value then return nil end
					table.insert(values,value);whitespace();c=state.Source:sub(state.Index,state.Index)
					if c=="," then state.Index+=1 elseif c~=")" then return nil end
				until c==")"
				state.Index+=1
				if name=="calc" then if #values~=1 then return nil end;result=values[1]
				else
					if (name=="clamp" and #values~=3) or (name~="clamp" and #values<1) then return nil end
					local kind=values[1].Kind
					for _,value in values do if value.Kind~=kind then return nil end end
					result=node({Kind=kind,Op=name,Values=values,
						HasPercent=values[1].HasPercent,UsesViewport=values[1].UsesViewport})
					if not result then return nil end
					for index=2,#values do
						result.HasPercent=result.HasPercent or values[index].HasPercent
						result.UsesViewport=result.UsesViewport or values[index].UsesViewport
					end
				end
			else
				local raw=tail:match("^(%d+%.%d+)") or tail:match("^(%d+)") or tail:match("^(%.%d+)")
				if not raw then return nil end
				state.Index+=#raw
				local number=tonumber(raw)
				if not number or number>LIMIT then return nil end
				local unit=state.Source:sub(state.Index):match("^([%a%%]+)") or ""
				state.Index+=#unit;unit=unit:lower()
				if unit=="" then result=node(numberLeaf(number))
				elseif not Units.has(unit) then return nil
				else
					local pixels,percent,viewport=0,0,viewportUnit(unit)
					if unit=="%" then percent=number
					else pixels=number*(Units.scale(unit,state.Context) :: number)end
					result=node(lengthLeaf(pixels,percent,viewport))
				end
			end
		end
		if not result then return nil end
		if sign < 0 then result=combine("*",result,numberLeaf(-1)) end
		return result
	end
	local function product(depth: number?): any?
		local result=primary(depth);if not result then return nil end
		while true do
			whitespace();local op=state.Source:sub(state.Index,state.Index)
			if op~="*" and op~="/" then break end
			state.Index+=1;local right=primary(depth);if not right then return nil end
			result=combine(op,result,right);if not result then return nil end
		end
		return result
	end
	expression=function(depth: number?): any?
		local result=product(depth);if not result then return nil end
		while true do
			whitespace();local op=state.Source:sub(state.Index,state.Index)
			if op~="+" and op~="-" then break end
			state.Index+=1;local right=product(depth);if not right then return nil end
			result=combine(op,result,right);if not result then return nil end
		end
		return result
	end
	local result=expression(0);whitespace()
	if not result or state.Index<=#source then return nil end
	if expected=='number'then return if result.Kind=='number'then result else nil end
	if result.Kind=="number" then
		if result.Op~="number" or result.Value~=0 then return nil end
		result=lengthLeaf(0,0,false)
	end
	return result
end

function LengthExpression.parse(source: string, context: any?): any?
	if #source==0 or #source>2048 then return nil end
	local ast=parser(source,context);if not ast then return nil end
	local zero=evaluate(ast,0)
	if not finite(zero) or math.abs(zero)>LIMIT then return nil end
	if ast.Op=="linear" and ast.Pixels==0 and ast.PercentValue~=0 then
		return {Value=ast.PercentValue,Percent=true,UsesViewport=ast.UsesViewport}
	end
	if not ast.HasPercent then return {Value=zero,Percent=false,UsesViewport=ast.UsesViewport} end
	return {Value=0,Percent=true,Expression=ast,UsesViewport=ast.UsesViewport}
end

function LengthExpression.number(source: string): number?
	if #source==0 or #source>2048 then return nil end
	local ast=parser(source,nil,'number');if not ast then return nil end
	local value=evaluate(ast,0);return if finite(value)then value else nil
end

function LengthExpression.resolve(value: any, basis: number): number
	if value.Kind=='length'and value.Op=='linear'then return evaluate(value,basis)end
	if value.Expression then return evaluate(value.Expression,basis) end
	return if value.Percent then basis*value.Value/100 else value.Value
end
function LengthExpression.linear(pixels:number,percent:number):any
 return {Value=if percent==0 then pixels else 0,Percent=percent~=0,Expression=if percent~=0 then {Kind='length',Op='linear',Pixels=pixels,PercentValue=percent,HasPercent=true}else nil}
end
function LengthExpression.interpolate(a:any,b:any,t:number):any?
 local function ast(value)
  if type(value)~='table'then return nil end
  if value.Expression then return value.Expression end
  if value.Kind=='length'then return value end
  if type(value.Value)~='number'then return nil end
  return lengthLeaf(if value.Percent then 0 else value.Value,if value.Percent then value.Value else 0,false)
 end
 local left,right=ast(a),ast(b);if not left or not right then return nil end
 local result=combine('+',combine('*',left,numberLeaf(1-t)),combine('*',right,numberLeaf(t)))
 return {Value=0,Percent=result.HasPercent,Expression=result,UsesViewport=result.UsesViewport}
end

-- Computed animation values can retain percentages inside min/max/clamp.
-- Serialize the expression, rather than resolving it against a zero basis,
-- so commitStyles keeps responding to its containing block afterwards.
function LengthExpression.serialize(value:any):string?
 local ast=value.Expression or (if value.Kind=='length'then value else nil)
 if not ast then return nil end
 local function number(n)return if n==0 then '0'else string.format('%.12g',n)end
 local emit
 emit=function(node)
  if node.Op=='linear'then
   if node.PercentValue==0 then return number(node.Pixels)..'px'end
   if node.Pixels==0 then return number(node.PercentValue)..'%'end
   return '('..number(node.PercentValue)..'% '..(if node.Pixels<0 then '- 'else '+ ')..number(math.abs(node.Pixels))..'px)'
  elseif node.Op=='number'then return number(node.Value)
  elseif node.Op=='add'or node.Op=='subtract'then return '('..emit(node.Left)..(if node.Op=='add'then ' + 'else ' - ')..emit(node.Right)..')'
  elseif node.Op=='multiply'then return '('..emit(node.Left)..' * '..number(node.Scalar)..')'end
  local parts={};for _,child in node.Values do table.insert(parts,emit(child))end
  return node.Op..'('..table.concat(parts,', ')..')'
 end
 return 'calc('..emit(ast)..')'
end

function LengthExpression.usesViewport(source: string): boolean
	for unit in source:lower():gmatch('[%d%.]([%a]+)%f[%W]')do if Units.contextual(unit)then return true end end
	return false
end

return LengthExpression
