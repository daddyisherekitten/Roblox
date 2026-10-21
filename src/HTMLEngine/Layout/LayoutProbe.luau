--!strict
-- Size probes use local coordinates, but must not move a retained surface to
-- that temporary origin while a cooperative layout is suspended.
local LayoutProbe = {}
function LayoutProbe.natural(box,available,measure,alive,minimum,style)
	local previous=box.Style;box.Style=style or previous
	local ok,width=pcall(measure,box,available,alive,minimum)
	box.Style=previous
	if not ok then error(width,0)end
	return width
end

function LayoutProbe.arrange(box: any, available: number, layout: any, alive: any, sizing: any?): (number, number, number)
	if box.Kind == "Words" then
		-- Anonymous runs paint directly into their parent's surface. Their
		-- measured extents do not depend on the retained line's paint origin.
		return layout(box, available, box.LayoutX or 0, box.LayoutY or 0, alive, true, sizing)
	end
	local previous = box.LayoutProbe
	local previousStyle=box.Style
	if sizing and sizing.Style then box.Style=sizing.Style;box.LayoutMargin=sizing.Style.Margin end
	box.LayoutProbe = true
	local ok, height, width, bottom = pcall(layout, box, available, 0, 0, alive, true, sizing)
	box.LayoutProbe = previous
	box.Style=previousStyle
	if not ok then error(height, 0) end
	return height, width, bottom
end

return LayoutProbe
