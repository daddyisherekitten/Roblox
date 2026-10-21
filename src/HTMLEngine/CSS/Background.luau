--!strict
-- CSS background layer parsing shared by longhands and the shorthand.
local Syntax = require(script.Parent.Syntax)
local Color = require(script.Parent.Color)
local ImageSet = require(script.Parent.ImageSet)

local Background = {}
local BOX = { ["border-box"] = true, ["padding-box"] = true, ["content-box"] = true }
local REPEAT = { ["repeat"] = true, ["no-repeat"] = true, space = true, round = true }
local SIZE_KEYWORD = { cover = true, contain = true }
local RADIAL_SIZE = { ["closest-side"] = true, ["farthest-side"] = true, ["closest-corner"] = true, ["farthest-corner"] = true }

local function trim(value: string): string return value:match("^%s*(.-)%s*$") :: string end

local function split(value: string, stops: string): {string}
	local result, cursor = {}, 1
	while cursor <= #value do
		local part, nextCursor, separator = Syntax.scan(value, cursor, stops)
		cursor = nextCursor
		part = trim(part)
		if part == "" then return {} end
		table.insert(result, part)
		if separator ~= "" and cursor > #value then return {} end
	end
	return result
end

local function tokens(value: string): {string}
	local result, cursor = {}, 1
	while cursor <= #value do
		local part, nextCursor = Syntax.scan(value, cursor, " \t\r\n")
		cursor = nextCursor
		part = trim(part)
		if part ~= "" then table.insert(result, part) end
	end
	return result
end

local function unquote(value: string): string?
	value = trim(value)
	local quote = value:sub(1, 1)
	if quote == "\"" or quote == "'" then
		if value:sub(-1) ~= quote or #value < 2 then return nil end
		value = value:sub(2, -2)
	end
	-- An empty URL is a valid image value pointing to an invalid resource.
	-- Keep the layer for root/body propagation even though it paints nothing.
	if value:find("[\r\n]") then return nil end
	return (value:gsub("\\([\\\"'])", "%1"))
end

local function parseAngle(value: string): number?
	local lower = value:lower()
	local number, unit = lower:match("^([%+%-]?%d*%.?%d+)(%a+)$")
	if not number then return nil end
	if unit~="deg" and unit~="grad" and unit~="rad" and unit~="turn" then return nil end
	local n = tonumber(number)
	if not n or math.abs(n) > 100000 then return nil end
	if unit == "grad" then n *= .9 elseif unit == "rad" then n *= 180 / math.pi elseif unit == "turn" then n *= 360 end
	return n
end

local function direction(value: string): number?
	local angle = parseAngle(value)
	if angle then return angle end
	local lower = value:lower()
	if lower:sub(1, 3) ~= "to " then return nil end
	local x, y = 0, 0
	for _, token in tokens(lower:sub(4)) do
		if token == "left" and x == 0 then x = -1 elseif token == "right" and x == 0 then x = 1
		elseif token == "top" and y == 0 then y = -1 elseif token == "bottom" and y == 0 then y = 1 else return nil end
	end
	if x == 0 and y == 0 then return nil end
	return math.deg(math.atan2(x, -y))
end

local function colorStop(value: string, parseLength: (string, boolean?) -> any): any
	local parts = tokens(value)
	if #parts < 1 or #parts > 3 then return nil end
	local shade, alpha = Color.parse(parts[1]:lower())
	if not shade then return nil end
	local positions = {}
	for index = 2, #parts do
		local length = parseLength(parts[index], true)
		if not length then return nil end
		if length.Value==0 and not length.Expression and parts[index]:sub(-1)=='%'then length.Percent=true end
		table.insert(positions, length)
	end
	return {Color = shade, Alpha = alpha or 1, Positions = positions}
end

local function conicStop(value: string, parseLength: (string, boolean?) -> any): any
	local parts = tokens(value)
	if #parts < 1 or #parts > 3 then return nil end
	local shade, alpha = Color.parse(parts[1]:lower())
	if not shade then return nil end
	local positions = {}
	for index = 2, #parts do
		local raw = parts[index]
		local degrees = parseAngle(raw)
		local position = if degrees then {Value = degrees / 3.6, Percent = true} else parseLength(raw, true)
		if position and position.Value==0 and not position.Expression and raw:sub(-1)=='%'then position.Percent=true end
		if not position or (not degrees and not position.Percent and position.Value ~= 0) then return nil end
		-- Painting uses turns as percentages; CSSOM must retain the distinction
		-- between an authored percentage and an angle computed to degrees.
		if degrees then position.ConicAngle = true end
		table.insert(positions, position)
	end
	return {Color = shade, Alpha = alpha or 1, Positions = positions}
end

local function parsePosition(value: string, parseLength: (string, boolean?) -> any): any
	local parts = tokens(value)
	if #parts < 1 or #parts > 4 then return nil end
	if #parts<=2 then
		-- In the two-value grammar a length is a coordinate, not an offset
		-- from the preceding edge. E.g. right 10px means x=100%, y=10px.
		local keywordAxes={left="X",right="X",top="Y",bottom="Y"}
		local function coordinate(part: string): any
			if part=="center" then return {Anchor=.5} end
			if keywordAxes[part] then return {Anchor=if part=="right" or part=="bottom" then 1 else 0} end
			local length=parseLength(part,true)
			return if length then {Anchor=0,Offset=length} else nil
		end
		local a,b=parts[1]:lower(),if parts[2] then parts[2]:lower() else "center"
		if #parts==1 then
			if keywordAxes[a]=="Y" then a,b=b,a end
		elseif (keywordAxes[a] or a=="center") and (keywordAxes[b] or b=="center") then
			if keywordAxes[a]=="Y" or keywordAxes[b]=="X" then a,b=b,a end
		end
		if keywordAxes[a]=="Y" or keywordAxes[b]=="X" then return nil end
		local x,y=coordinate(a),coordinate(b)
		return if x and y then {X=x,Y=y} else nil
	end
	local axes: any = {X = nil, Y = nil}
	local pendingAxis: string? = nil
	local function set(axis: string, anchor: number, offset: any?): boolean
		if axes[axis] then return false end
		axes[axis] = {Anchor = anchor, Offset = offset}
		return true
	end
	for _, raw in parts do
		local part = raw:lower()
		local axis, anchor
		if part == "left" then axis, anchor = "X", 0 elseif part == "right" then axis, anchor = "X", 1
		elseif part == "top" then axis, anchor = "Y", 0 elseif part == "bottom" then axis, anchor = "Y", 1
		elseif part == "center" then
			axis = if not axes.X and pendingAxis ~= "X" then "X" else "Y"; anchor = .5
		else
			local length = parseLength(raw, true)
			if not length then return nil end
			if pendingAxis then
				local current = axes[pendingAxis]
				if not current or current.Offset then return nil end
				current.Offset = length; pendingAxis = nil
			else
				axis = if not axes.X then "X" elseif not axes.Y then "Y" else nil
				if not axis or not set(axis, 0, length) then return nil end
			end
			continue
		end
		if not set(axis :: string, anchor :: number) then return nil end
		pendingAxis = axis
	end
	if pendingAxis then pendingAxis = nil end
	if not axes.X then axes.X = {Anchor = .5} end
	if not axes.Y then axes.Y = {Anchor = .5} end
	return axes
end

local function gradient(value: string, parseLength: (string, boolean?) -> any): any
	local name, content = value:match("^([%a%-]+)%((.*)%)$")
	if not name then return nil end
	content = content :: string
	name = name:lower()
	local repeating = name:sub(1, 10) == "repeating-"
	local kind = if name == "linear-gradient" or name == "repeating-linear-gradient" then "linear"
		elseif name == "radial-gradient" or name == "repeating-radial-gradient" then "radial"
		elseif name == "conic-gradient" or name == "repeating-conic-gradient" then "conic" else nil
	if not kind then return nil end
	local parts = split(content, ",")
	if #parts < 2 then return nil end
	local result: any = {Kind = kind, Repeating = repeating, Stops = {}}
	local firstStop = 1
	if kind == "linear" then
		local angle = direction(parts[1])
		if angle then
			result.Angle, firstStop = angle, 2
			if parts[1]:lower():match('^to%s')then
				local horizontal,vertical
				for _,token in tokens(parts[1]:lower():sub(4))do
					if token=='left'or token=='right'then horizontal=token else vertical=token end
				end
				result.Direction='to '..table.concat(if horizontal and vertical then {horizontal,vertical}else {horizontal or vertical},' ')
			end
		else result.Angle = 180 end
	elseif kind == "radial" then
		local firstShade = Color.parse((tokens(parts[1])[1] or ""):lower())
		if not firstShade then
			local definition: string, at: string? = parts[1], nil
			local before, after = definition:match("^(.-)%s+[Aa][Tt]%s+(.+)$")
			if before then definition, at = trim(before), trim(after :: string) end
			result.Shape, result.Size = "ellipse", "farthest-corner"
			local dimensions = {}
			for _, raw in tokens(definition) do
				local token = raw:lower()
				if (token == "circle" or token == "ellipse") and result.Shape == "ellipse" and #dimensions == 0 then result.Shape = token
				elseif RADIAL_SIZE[token] and #dimensions == 0 then result.Size = token
				else
					local length = parseLength(raw, false)
					if not length or #dimensions == 2 then return nil end
					table.insert(dimensions, length)
				end
			end
			if #dimensions > 0 then
				if result.Shape == "circle" and #dimensions ~= 1 then return nil end
				result.Size = dimensions
			end
			if at then result.Position = parsePosition(at, parseLength); if not result.Position then return nil end end
			firstStop = 2
		end
		result.Position = result.Position or {X = {Anchor = .5}, Y = {Anchor = .5}}
	else
		result.Angle = 0
		result.Position = {X = {Anchor = .5}, Y = {Anchor = .5}}
		local definition = parts[1]:lower()
		local from, at = definition:match("^from%s+(.-)%s+at%s+(.+)$")
		if not from then from = definition:match("^from%s+(.+)$") end
		if not at then at = definition:match("^at%s+(.+)$") end
		if from or at then
			if from then result.Angle = parseAngle(trim(from)); if not result.Angle then return nil end end
			if at then result.Position = parsePosition(trim(at), parseLength); if not result.Position then return nil end end
			firstStop = 2
		end
	end
	for index = firstStop, #parts do
		local stop = if kind == "conic" then conicStop(parts[index], parseLength) else colorStop(parts[index], parseLength)
		if not stop then return nil end
		-- Two positions on one color are equivalent to two adjacent stops.
		if #stop.Positions == 2 then
			table.insert(result.Stops, {Color=stop.Color,Alpha=stop.Alpha,Positions={stop.Positions[1]}})
			table.insert(result.Stops, {Color=stop.Color,Alpha=stop.Alpha,Positions={stop.Positions[2]}})
		else table.insert(result.Stops, stop) end
	end
	return if #result.Stops >= 2 then result else nil
end

local function image(value: string, parseLength: (string, boolean?) -> any): any
	local lower = value:lower()
	if lower:match('^%-?[%a%-]*image%-set%(')then return ImageSet.parse(value,function(v)return image(v,parseLength)end)end
	if lower == "none" then return {Kind = "none"} end
	local inside = value:match("^[Uu][Rr][Ll]%((.*)%)$")
	if inside then local source = unquote(inside); return if source then {Kind="url",Source=source} else nil end
	return gradient(value, parseLength)
end

function Background.images(value: string, parseLength: (string, boolean?) -> any): any
	local result = {}
	for _, part in split(value, ",") do
		local parsed = image(part, parseLength)
		if not parsed then return nil end
		table.insert(result, parsed)
	end
	return if #result > 0 then result else nil
end

local function sizeLayer(value: string, parseLength: (string, boolean?) -> any): any
	local lower = value:lower()
	if SIZE_KEYWORD[lower] then return {Kind = lower} end
	local parts, values = tokens(value), {}
	if #parts < 1 or #parts > 2 then return nil end
	for _, part in parts do
		if part:lower() == "auto" then table.insert(values, false)
		else local length = parseLength(part, false); if not length then return nil end; table.insert(values, length) end
	end
	return {Kind="explicit", X=values[1], Y=if #values == 1 then false else values[2]}
end

function Background.sizes(value: string, parseLength: (string, boolean?) -> any): any
	local result = {}
	for _, part in split(value, ",") do local parsed=sizeLayer(part,parseLength);if not parsed then return nil end;table.insert(result,parsed) end
	return if #result > 0 then result else nil
end

function Background.positions(value: string, parseLength: (string, boolean?) -> any): any
	local result = {}
	for _, part in split(value, ",") do local parsed=parsePosition(part,parseLength);if not parsed then return nil end;table.insert(result,parsed) end
	return if #result > 0 then result else nil
end

function Background.axisPositions(value: string, axis: string, parseLength: (string, boolean?) -> any): any
	local result={}
	for _,part in split(value,",") do
		for _,raw in tokens(part) do
			local keyword=raw:lower()
			if axis=="X" and (keyword=="top" or keyword=="bottom") or axis=="Y" and (keyword=="left" or keyword=="right") then return nil end
		end
		local parsed=parsePosition(if axis=="X" then part.." center" else "center "..part,parseLength)
		if not parsed then return nil end
		table.insert(result,parsed[axis])
	end
	return if #result>0 then result else nil
end

local function repeatLayer(value: string): any
	local parts = tokens(value:lower())
	if #parts == 1 and parts[1] == "repeat-x" then return {X="repeat",Y="no-repeat"} end
	if #parts == 1 and parts[1] == "repeat-y" then return {X="no-repeat",Y="repeat"} end
	if #parts < 1 or #parts > 2 or not REPEAT[parts[1]] or (parts[2] and not REPEAT[parts[2]]) then return nil end
	return {X=parts[1],Y=parts[2] or parts[1]}
end

function Background.repeats(value: string): any
	local result={}
	for _,part in split(value,",") do local parsed=repeatLayer(part);if not parsed then return nil end;table.insert(result,parsed) end
	return if #result>0 then result else nil
end

function Background.boxes(value: string): any
	local result={}
	for _,part in split(value,",") do local lower=part:lower();if not BOX[lower] then return nil end;table.insert(result,lower) end
	return if #result>0 then result else nil
end

-- Deliberately strict but covers the useful browser shorthand: image, position/size,
-- repeat, origin/clip and a final color, with comma-separated image layers.
function Background.shorthand(value: string, parseLength: (string, boolean?) -> any): any
	local segments = split(value, ",")
	if #segments == 0 then return nil end
	local result: any = {Images={},Sizes={},Positions={},Repeats={},Origins={},Clips={},Attachments={}}
	for layerIndex, segment in segments do
		local before, after = Syntax.scan(segment, 1, "/")
		local left, sizeText = trim(before), if after <= #segment then trim(segment:sub(after)) else nil
		local foundImage, repeatValue, repeatParts, attachment, boxes, positionParts = nil, nil, 0, nil, {}, {}
		local size={Kind="explicit",X=false,Y=false}
		local rightParts=if sizeText then tokens(sizeText) else {}
		local tail={}
		if #rightParts>0 then
			local count=1
			if not SIZE_KEYWORD[rightParts[1]:lower()] and rightParts[2] then
				local second=rightParts[2]:lower();local secondColor=Color.parse(second)
				if not repeatLayer(rightParts[2]) and not BOX[second] and not secondColor then count=2 end
			end
			size=sizeLayer(table.concat(rightParts," ",1,count),parseLength)
			if not size then return nil end
			for index=count+1,#rightParts do table.insert(tail,rightParts[index]) end
		elseif sizeText then return nil end
		local allLeft=tokens(left);local leftCount=#allLeft
		for _,raw in tail do table.insert(allLeft,raw) end
		for tokenIndex, raw in allLeft do
			local lower=raw:lower()
			local parsedImage=image(raw,parseLength)
			local parsedRepeat=repeatLayer(raw)
			local shade,alpha=Color.parse(lower)
			if parsedImage and not foundImage then foundImage=parsedImage
			elseif parsedRepeat and not repeatValue then repeatValue=parsedRepeat;repeatParts=1
			elseif parsedRepeat and repeatParts==1 and REPEAT[lower] and repeatValue.X==repeatValue.Y then repeatValue.Y=lower;repeatParts=2
			elseif (lower=="scroll" or lower=="fixed" or lower=="local") and not attachment then attachment=lower
			elseif BOX[lower] and #boxes<2 then table.insert(boxes,lower)
			elseif shade and layerIndex==#segments and not result.Color then result.Color,result.Alpha=shade,alpha
			elseif tokenIndex<=leftCount then table.insert(positionParts,raw)
			else return nil end
		end
		local position = if #positionParts>0 then parsePosition(table.concat(positionParts," "),parseLength) else {X={Anchor=0},Y={Anchor=0}}
		if not position then return nil end
		table.insert(result.Images,foundImage or {Kind="none"})
		table.insert(result.Sizes,size);table.insert(result.Positions,position)
		table.insert(result.Repeats,repeatValue or {X="repeat",Y="repeat"})
		table.insert(result.Origins,boxes[1] or "padding-box");table.insert(result.Clips,boxes[2] or boxes[1] or "border-box")
		table.insert(result.Attachments,attachment or "scroll")
	end
	return result
end

Background.DefaultPosition = table.freeze({X=table.freeze({Anchor=0}),Y=table.freeze({Anchor=0})})
return Background
