--!strict
local BorderPaint = {}
function BorderPaint.patterned(kind: string): boolean
	return kind == "double" or kind == "dashed" or kind == "dotted" or kind == "groove" or kind == "ridge"
end
local function relief(color: any, light: boolean): any
	local maximum = math.max(color.R, color.G, color.B)
	if maximum < .001 then
		-- Browsers still give a black 3D border two visible relief shades.
		local value = if light then 2 / 3 else 1 / 3
		return Color3.new(value, value, value)
	end
	-- Browser 3D borders move the HSV value by roughly one third while
	-- preserving hue and saturation.  Scaling every channel by the new
	-- maximum does exactly that, including saturated authored colours.
	local target = math.clamp(maximum + (if light then 1 / 3 else -1 / 3), 0, 1)
	local factor = target / maximum
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end
function BorderPaint.edge(style: any, side: number, band: number?): (any, number, string)
	local entry = if style.BorderSides then style.BorderSides[side] else nil
	local color = if entry then entry.Color else style.BorderColor
	local alpha = if entry then entry.Alpha else style.BorderColorAlpha or 1
	local kind = if entry then entry.Style else style.BorderStyle
	if kind == "inset" then
		-- The recessed top/left edges are dark; right/bottom catch the light.
		color = relief(color, side == 2 or side == 3)
	elseif kind == "outset" then
		color = relief(color, side == 1 or side == 4)
	end
	if band and (kind == "groove" or kind == "ridge") then color = relief(color, (band == 1) == (kind == "ridge")) end
	return color, alpha, kind
end
return BorderPaint
