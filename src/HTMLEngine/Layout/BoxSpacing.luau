--!strict
-- Keep CSS percentage values separate from the pixels consumed by layout.
local BoxSpacing = {}
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)

function BoxSpacing.resolve(style: any, width: number): boolean
	local changed = false
	for _, field in {"Margin", "Padding"} do
		local values = style[field .. "Values"]
		if not values then continue end
		for side, value in values do
			local pixels = if type(value) == "table" then LengthExpression.resolve(value,width) else value
			if style[field][side] ~= pixels then style[field][side], changed = pixels, true end
		end
	end
	return changed
end

function BoxSpacing.collapse(a: number, b: number): number
	return math.max(0, a, b) + math.min(0, a, b)
end

return BoxSpacing
