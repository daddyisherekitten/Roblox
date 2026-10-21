--!strict
local ObjectPosition = {}
local Syntax=require(script.Parent.Syntax)
local CENTER = table.freeze({Value = 50, Percent = true})
ObjectPosition.Default = table.freeze({X = CENTER, Y = CENTER})
local axes = {left = "X", right = "X", top = "Y", bottom = "Y"}

function ObjectPosition.parse(value: string, length: (string) -> any): any
	local tokens = {}
	local cursor=1
	while cursor<=#value do
		local token,nextCursor=Syntax.scan(value,cursor," \t\r\n");cursor=nextCursor
		if token~="" then table.insert(tokens,token) end
	end
	local function number(token: string): any
		return length(token)
	end
	local function coordinate(token: string): any
		if token == "center" then return CENTER end
		if axes[token] then return {Value = if token == "right" or token == "bottom" then 100 else 0, Percent = true} end
		return number(token)
	end
	local x, y
	if #tokens == 1 then
		local token = tokens[1]
		local point = coordinate(token)
		if not point then return nil end
		x, y = if axes[token] == "Y" then CENTER else point, if axes[token] == "Y" then point else CENTER
	elseif #tokens == 2 then
		local a, b = tokens[1], tokens[2]
		-- Keyword pairs can be reversed; numeric pairs always mean x then y.
		if (axes[a] or a == "center") and (axes[b] or b == "center") then
			if axes[a] == "Y" or axes[b] == "X" then a, b = b, a end
		end
		if axes[a] == "Y" or axes[b] == "X" then return nil end
		x, y = coordinate(a), coordinate(b)
	elseif #tokens == 4 then
		-- Unlike background-position, <position> permits no three-value form.
		local result = {}
		for index = 1, 3, 2 do
			local token = tokens[index]
			local axis = axes[token]
			local offset = number(tokens[index + 1])
			if not axis or result[axis] or not offset then return nil end
			local point = table.clone(coordinate(token))
			local sign = if token == "right" or token == "bottom" then -1 else 1
			point.EdgeOffset,point.EdgeSign=offset,sign
			result[axis] = point
		end
		x, y = result.X, result.Y
	else return nil end
	if not x or not y then return nil end
	if not table.isfrozen(x) then table.freeze(x) end
	if not table.isfrozen(y) then table.freeze(y) end
	return table.freeze({X = x, Y = y})
end

function ObjectPosition.centered(position: any): boolean
	if not position then return true end
	local x, y = position.X, position.Y
	return x.Percent and x.Value == 50 and (x.Offset or 0) == 0
		and x.EdgeOffset==nil and y.Percent and y.Value == 50 and (y.Offset or 0) == 0 and y.EdgeOffset==nil
end

return ObjectPosition
