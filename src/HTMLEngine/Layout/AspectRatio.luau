--!strict
local AspectRatio = {}

-- Natural ratios always use the content box; author ratios honor box-sizing.
function AspectRatio.resolve(style: any, natural: number?): (number?, boolean)
	local specified = style.AspectRatio
	if specified and specified.Value and (not specified.Auto or not natural) then
		return specified.Value, style.BoxSizing == "border-box"
	end
	return natural, false
end

function AspectRatio.height(width: number, ratio: number, widthEdges: number, heightEdges: number): number
	return math.max(0, (width + widthEdges) / ratio - heightEdges)
end

function AspectRatio.width(height: number, ratio: number, widthEdges: number, heightEdges: number): number
	return math.max(0, (height + heightEdges) * ratio - widthEdges)
end

return AspectRatio
