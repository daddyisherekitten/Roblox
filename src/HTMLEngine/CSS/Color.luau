--!strict
-- Shared bounded sRGB parser for text, backgrounds, borders and shadows.
local Syntax = require(script.Parent.Syntax)
local NamedColors = require(script.Parent.NamedColors)
local Mix=require(script.Parent.ColorMix)
local Spaces=require(script.Parent.ColorSpaces)
local Color = {}
local colors = {}
for name, hex in NamedColors do
	colors[name] = Color3.fromRGB(tonumber(hex:sub(2, 3), 16) :: number, tonumber(hex:sub(4, 5), 16) :: number, tonumber(hex:sub(6, 7), 16) :: number)
end
table.freeze(colors)

local function basicColor(value: string): Color3?
	if colors[value] then return colors[value] end
	local hex = value:match("^#([%da-f]+)$")
	if hex and #hex == 3 then hex = hex:gsub("(.)", "%1%1") end
	if not hex or #hex ~= 6 then return nil end
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16) :: number, tonumber(hex:sub(3, 4), 16) :: number, tonumber(hex:sub(5, 6), 16) :: number)
end

local function trim(value: string): string return value:match("^%s*(.-)%s*$") :: string end
local function number(value: string): number?
	if not value:match("^[%+%-]?%d*%.?%d+$") then return nil end
	local result = tonumber(value)
	return if result and math.abs(result) <= 100000 then result else nil
end

local function hsl(content: string): (any, number?)
	local parts = {}
	local legacy = content:find(",", 1, true) ~= nil
	if legacy then
		local index = 1
		while index <= #content do
			local part, nextIndex, separator = Syntax.scan(content, index, ",")
			index = nextIndex
			part = trim(part)
			if part == "" or #parts == 4 or (separator == "," and index > #content) then return nil, nil end
			table.insert(parts, part)
		end
	else
		local channels, alpha = content:match("^(.-)/(.-)$")
		for part in (channels or content):gmatch("%S+") do table.insert(parts, part) end
		if #parts ~= 3 then return nil, nil end
		if alpha then table.insert(parts, trim(alpha)) end
	end
	if #parts ~= 3 and #parts ~= 4 then return nil, nil end
	local hue = number(parts[1])
	if not hue then
		local numeric, unit = parts[1]:match("^(.-)(%a+)$")
		local factor = if unit == "deg" then 1 elseif unit == "grad" then .9 elseif unit == "rad" then 180 / math.pi elseif unit == "turn" then 360 else nil
		local n = if numeric then number(numeric) else nil
		if not factor or not n then return nil, nil end
		hue = n * factor
	end
	local values = {}
	for index = 2, #parts do
		local part = parts[index]
		local percent = part:sub(-1) == "%"
		if legacy and index < 4 and not percent then return nil, nil end
		local n = number(if percent then part:sub(1, -2) else part)
		if not n then return nil, nil end
		values[index] = math.clamp(n / (if index < 4 or percent then 100 else 1), 0, 1)
	end
	local saturation, lightness = values[2], values[3]
	local a = saturation * math.min(lightness, 1 - lightness)
	local angle = (hue % 360) / 30
	local function channel(n: number): number
		local k = (n + angle) % 12
		return lightness - a * math.max(-1, math.min(k - 3, 9 - k, 1))
	end
	return Color3.new(channel(0), channel(8), channel(4)), values[4] or 1
end

local function modernRGB(content: string): (any, number?)
	local channels, alpha = content:match("^(.-)/(.-)$")
	local parts = {}
	for part in (channels or content):gmatch("%S+") do table.insert(parts, part) end
	if #parts ~= 3 then return nil, nil end
	if alpha then table.insert(parts, trim(alpha)) end
	local values = {}
	for index, part in parts do
		if part == "none" then values[index] = 0; continue end
		local percent = part:sub(-1) == "%"
		local n = number(if percent then part:sub(1, -2) else part)
		if not n then return nil, nil end
		local divisor = if percent then 100 elseif index <= 3 then 255 else 1
		values[index] = math.clamp(n / divisor, 0, 1)
	end
	return Color3.new(values[1], values[2], values[3]), values[4] or 1
end

function Color.parse(value: string, depth: number?): (any, number?)
	depth=depth or 0;if depth>16 or #value>8192 then return nil,nil end
	value=trim(value):lower()
	local mixed=value:match('^color%-mix%((.*)%)$')
	if mixed then return Mix.parse(mixed,function(term)return Color.parse(term,depth+1)end)end
	local space,modern=value:match('^(oklab)%((.*)%)$')
	if not space then space,modern=value:match('^(oklch)%((.*)%)$')end
	if space then
		local channels,alpha=modern:match('^(.-)/(.-)$');local values={}
		for token in(channels or modern):gmatch('%S+')do
			local percent=token:sub(-1)=='%';local numeric=number(if percent then token:sub(1,-2)else token)
			if #values==2 and space=='oklch'and not numeric then local n,unit=token:match('^(.-)(%a+)$');local factor=({deg=1,turn=360,grad=.9,rad=180/math.pi})[unit];numeric=if factor and number(n)then number(n)*factor else nil end
			if not numeric then return nil,nil end
			if percent then numeric*=if #values==0 then .01 else .004 end
			table.insert(values,numeric)
		end
		if #values~=3 then return nil,nil end
		values[1]=math.clamp(values[1],0,1);if space=='oklch'then values[2]=math.max(0,values[2])end
		local opacity=1;if alpha then alpha=trim(alpha);local percent=alpha:sub(-1)=='%';opacity=number(if percent then alpha:sub(1,-2)else alpha);if not opacity then return nil,nil end;opacity=math.clamp(opacity/(if percent then 100 else 1),0,1)end
		return Spaces.color(values,space),opacity
	end
	if value == "currentcolor" then return value, 1 end
	if value == "transparent" then return Color3.new(0, 0, 0), 0 end
	local basic = basicColor(value)
	if basic then return basic, 1 end
	local hex = value:match("^#([%da-f]+)$")
	if hex and (#hex == 4 or #hex == 8) then
		if #hex == 4 then hex = hex:gsub("(.)", "%1%1") end
		return basicColor("#" .. hex:sub(1, 6)), (tonumber(hex:sub(7, 8), 16) :: number) / 255
	end
	local hslContent = value:match("^hsla?%((.*)%)$")
	if hslContent then return hsl(hslContent) end
	local name, content = value:match("^(rgba?)%((.*)%)$")
	if not name then return nil, nil end
	if not content:find(",", 1, true) then return modernRGB(content) end
	local components, index, percent = {}, 1, nil
	while index <= #content do
		local part, nextIndex, separator = Syntax.scan(content, index, ",")
		index = nextIndex; part = trim(part)
		local isPercent = part:sub(-1) == "%"
		local n = number(if isPercent then part:sub(1, -2) else part)
		if not n or #components >= 4 then return nil, nil end
		if #components < 3 then
			-- Legacy comma rgb() requires three numbers or three percentages.
			if percent ~= nil and percent ~= isPercent then return nil, nil end
			percent = isPercent
		end
		local divisor = if isPercent then 100 elseif #components < 3 then 255 else 1
		table.insert(components, math.clamp(n / divisor, 0, 1))
		if separator == "," and index > #content then return nil, nil end
	end
	if #components ~= 3 and #components ~= 4 then return nil, nil end
	return Color3.new(components[1], components[2], components[3]), components[4] or 1
end


function Color.opacity(shade: any, style: any): number
	return if shade.Color == "currentcolor" then style.ColorAlpha or 1 else shade.Alpha or 1
end

-- Inline backgrounds are painted per fragment. Fold nested layers once in CSS resolution.
function Color.over(front: Color3, alpha: number, back: Color3, backAlpha: number): (Color3, number)
	local behind = backAlpha * (1 - alpha)
	local combined = alpha + behind
	if combined == 0 then return front, 0 end
	return Color3.new((front.R * alpha + back.R * behind) / combined,
		(front.G * alpha + back.G * behind) / combined, (front.B * alpha + back.B * behind) / combined), combined
end

return Color
