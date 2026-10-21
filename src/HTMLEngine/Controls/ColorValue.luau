--!strict
local ColorValue = {}

function ColorValue.normalize(value: any): string
	local text=tostring(value or "")
	if not text:match("^#%x%x%x%x%x%x$") then return "#000000" end
	return text:lower()
end

function ColorValue.color(value: string): Color3
	local normalized=ColorValue.normalize(value)
	return Color3.fromRGB(tonumber(normalized:sub(2,3),16),tonumber(normalized:sub(4,5),16),tonumber(normalized:sub(6,7),16))
end

return ColorValue
