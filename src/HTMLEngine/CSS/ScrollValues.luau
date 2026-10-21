--!strict
-- Expand scroll shorthands into their canonical longhands before cascade.
local Length = require(script.Parent.LengthExpression)
local ScrollValues = {}

local clipSides = {
	["overflow-clip-margin"] = {"top", "right", "bottom", "left"},
	["overflow-clip-margin-block"] = {"block-start", "block-end"},
	["overflow-clip-margin-inline"] = {"inline-start", "inline-end"},
}

local function tokens(value: string): {string}
	local parts = {}
	for token in value:gmatch("%S+") do table.insert(parts, token) end
	return parts
end

local function validList(value: string): boolean
	return value:match("^%s*,")==nil and value:match(",%s*,")==nil and value:match(",%s*$")==nil
end

function ScrollValues.clip(value: string, context: any?): (any?, boolean)
	value=value:match("^%s*(.-)%s*$") or ""
	local box, offset = nil, nil
	for _, candidate in {"padding-box", "border-box", "content-box"} do
		if value==candidate then box,value=candidate,"";break end
		local pattern=candidate:gsub("%-","%%-")
		local start=value:match("^"..pattern.."%s+(.+)$")
		local finish=value:match("^(.+)%s+"..pattern.."$")
		if start or finish then box,value=candidate,start or finish;break end
	end
	if value~="" then
		local parsed=Length.parse(value,context)
		if not parsed or parsed.Percent then return nil,false end
		offset=parsed
	end
	if not box and not offset then return nil, false end
	return {Box = box, Offset = offset or {Value = 0, Percent = false}}, true
end

function ScrollValues.expand(name: string, value: string): any?
	if name == "scroll-timeline" then
		if not validList(value) then return nil end
		if value == "initial" or value == "inherit" or value == "unset" then
			return {{Name = "scroll-timeline-name", Value = value}, {Name = "scroll-timeline-axis", Value = value}}
		end
		local names, axes = {}, {}
		for group in value:gmatch("[^,]+") do
			local parts = tokens(group)
			if #parts < 1 or #parts > 2 or #names >= 8 then return nil end
			local name, axis = parts[1], parts[2] or "block"
			if name ~= "none" and not name:match("^%-%-[%a_][%w_%-]*$") then return nil end
			if axis ~= "block" and axis ~= "inline" and axis ~= "x" and axis ~= "y" then return nil end
			table.insert(names, name); table.insert(axes, axis)
		end
		if #names == 0 or value:match(",%s*$") then return nil end
		return {{Name = "scroll-timeline-name", Value = table.concat(names, ", ")},
			{Name = "scroll-timeline-axis", Value = table.concat(axes, ", ")}}
	end
	local sides = clipSides[name]
	if not sides then return nil end
	local wide = value == "initial" or value == "inherit" or value == "unset"
	if not wide then local _, valid = ScrollValues.clip(value, {Validate = true, FontSize = 16, RootFontSize = 16, ViewportWidth = 100, ViewportHeight = 100}); if not valid then return nil end end
	local result = {}
	for _, side in sides do table.insert(result, {Name = "overflow-clip-margin-" .. side, Value = value}) end
	return result
end

function ScrollValues.names(value: string): any?
	if not validList(value) then return nil end
	local result = {}
	for part in value:gmatch("[^,]+") do
		part = part:match("^%s*(.-)%s*$") or ""
		if part ~= "none" and not part:match("^%-%-[%a_][%w_%-]*$") then return nil end
		table.insert(result, part)
	end
	return if #result > 0 and #result <= 8 and not value:match(",%s*$") then result else nil
end

function ScrollValues.axes(value: string): any?
	if not validList(value) then return nil end
	local result = {}
	for part in value:gmatch("[^,]+") do
		part = part:match("^%s*(.-)%s*$") or ""
		if part ~= "block" and part ~= "inline" and part ~= "x" and part ~= "y" then return nil end
		table.insert(result, part)
	end
	return if #result > 0 and #result <= 8 and not value:match(",%s*$") then result else nil
end

return ScrollValues
