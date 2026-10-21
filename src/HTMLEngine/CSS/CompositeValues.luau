--!strict
-- Shorthands and CSS-wide values share the ordinary longhand cascade.
local Syntax = require(script.Parent.Syntax)
local WritingMode=require(script.Parent.WritingMode)
local CompositeValues = {}
local groups = {
	FontShorthand = {FontStyle = "normal", FontWeight = "normal", FontSize = "16px", LineHeight = "normal", Font = "serif"},
	ListStyle = {ListStyleType = "disc", ListStylePosition = "outside"},
}

function CompositeValues.parse(field: string, value: string, parse: any, properties: any): any
	local tokens, cursor = {}, 1
	while cursor <= #value do
		local token, following = Syntax.scan(value, cursor, " \t\r\n/")
		local delimiter = value:sub(following - 1, following - 1)
		cursor = following
		if token ~= "" then table.insert(tokens, token) end
		if delimiter == "/" then table.insert(tokens, "/") end
	end
	local result = {}
	local function accept(key: string, token: string): boolean
		local property = properties[key]
		local parsed, ok = parse(property, token)
		if ok then result[property.Field] = parsed end
		return ok
	end
	if field == "ListStyle" then
		result.ListStyleType, result.ListStylePosition = "disc", "outside"
		local seen = {}
		for _, token in tokens do
			local lower=token:lower()
			local key = if lower == "inside" or lower == "outside" then "list-style-position" else "list-style-type"
			if key=='list-style-position'then token=lower end
			if seen[key] or not accept(key, token) then return nil end
			seen[key] = true
		end
		return if #tokens > 0 then result else nil
	end
	result.FontStyle, result.FontWeight, result.LineHeight = "normal", 400, {Kind = "normal"}
	local index, seen = 1, {}
	while index <= #tokens and not accept("font-size", tokens[index]) do
		local token = tokens[index]
		if token ~= "normal" then
			local key = if token == "italic" then "font-style" else "font-weight"
			if seen[key] or not accept(key, token) then return nil end
			seen[key] = true
		end
		index += 1
	end
	if index > #tokens then return nil end
	index += 1
	if tokens[index] == "/" then
		if not tokens[index + 1] or not accept("line-height", tokens[index + 1]) then return nil end
		index += 2
	end
	if index > #tokens or not accept("font-family", table.concat(tokens, " ", index)) then return nil end
	return result
end

function CompositeValues.wide(entry: any, source: any): any
	local field = if entry.LogicalDimension then WritingMode.dimension(source,entry.LogicalDimension,entry.DimensionPrefix)else entry.Field
	local value = source[field]
	if field=="Display" and source.LegacyGrid then return if value=="inline-grid" then "-ms-inline-grid" else "-ms-grid" end
	if field=="BorderRadius" and (entry.Corner or entry.LogicalCorner) then
		local corner=entry.Corner
		if entry.LogicalCorner then
			corner=({'top-left','top-right','bottom-right','bottom-left'})[WritingMode.corner(source,entry.LogicalCorner)]
		end
		local index=if corner=="top-left" then 1 elseif corner=="top-right" then 2 elseif corner=="bottom-right" then 3 else 4
		return if source.BorderRadii then source.BorderRadii[index] else {X={Value=value or 0},Y={Value=value or 0}}
	end
	if groups[field] then
		local result = {}
		for component in groups[field] do result[component] = source[component] end
		return result
	elseif field == "Flex" then return {Grow = source.FlexGrow, Shrink = source.FlexShrink, Basis = source.FlexBasis}
	elseif field == "FlexFlow" then return {Direction = source.FlexDirection, Wrap = source.FlexWrap,Balance=source.FlexBalance}
	elseif field == "Overflow" then return {source.OverflowX, source.OverflowY}
	elseif field == "Inset" then value={source.Insettop or false, source.Insetright or false, source.Insetbottom or false, source.Insetleft or false}
	elseif field == "Outline" then return {Width = source.OutlineWidth, Style = source.OutlineStyle, Color = source.OutlineColor, Alpha = source.OutlineColorAlpha}
	elseif entry.ResetDecoration then
		return {Lines = source.TextDecoration or {}, Color = source.DecorationColor, Alpha = source.DecorationColorAlpha,
			Style = source.DecorationStyle, Thickness = source.DecorationThickness}
	elseif field == "Border" or field == "BorderWidth" or field == "BorderStyle" or field == "BorderColor" then
		local parts = {}
		for side = 1, 4 do
			local edge = if source.BorderSides then source.BorderSides[side] else
				{Width = source.BorderWidth, Style = source.BorderStyle, Color = source.BorderColor, Alpha = source.BorderColorAlpha or 1}
			parts[side] = if field == "Border" then edge elseif field == "BorderColor" then {Color = edge.Color, Alpha = edge.Alpha}
				elseif field == "BorderWidth" then edge.Width else edge.Style
		end
		value=parts
		if entry.BorderSide then return parts[entry.BorderSide]end
	elseif field == "Margin" or field == "Padding" then
		value = table.clone(source[field .. "Values"] or value)
		if field == "Margin" then
			for side, auto in source.MarginAuto or {} do if auto then value[side] = "auto" end end
		end
	elseif entry.ColorValue then return {Color = value, Alpha = source[field .. "Alpha"] or (if value then 1 else 0)} end
	-- An inherited logical longhand reads the parent's corresponding logical
	-- property, then the child's cascade maps that value to its own axes.
	if entry.LogicalSides then
		local logical={}
		for _,name in entry.LogicalSides do table.insert(logical,value[WritingMode.side(source,name)])end
		return logical
	end
	return if entry.Side then value[entry.Side] else value
end

return CompositeValues
