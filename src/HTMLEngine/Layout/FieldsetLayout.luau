--!strict
local Geometry = require(script.Parent.BorderGeometry)
local BoxSpacing = require(script.Parent.BoxSpacing)
local FieldsetLayout = {}

-- Keep the legend in the tree for hit testing and dirty propagation, but out of flow.
function FieldsetLayout.legend(box: any, width: number, natural: any, arrange: any, alive: any): number
	local legend = box.Legend
	local bt, _, _, bl = Geometry.sizes(box.Style)
	box.LegendGap = nil
	if not legend then return 0 end
	local s, m = legend.Style, legend.LayoutMargin
	BoxSpacing.resolve(s, width)
	local _, r, _, l = Geometry.sizes(s)
	local edges = s.Padding[2] + s.Padding[4] + l + r + m[2] + m[4]
	local hint
	if not s.Width then
		local preferred = natural(legend, width, alive)
		local minimum = if preferred > width then natural(legend, width, alive, true) else 0
		if not alive() then return 0 end
		local fit = math.max(minimum, math.min(width, preferred))
		hint = {ContentWidth = math.max(0, fit - edges)}
	end
	local x = bl + box.Style.Padding[4]
	local h = arrange(legend, width, x, 0, alive, true, hint)
	if not alive() then return 0 end
	local extra = math.max(0, h - bt)
	local y = math.max(0, (bt - h) / 2)
	if y > 0 then arrange(legend, width, x, y, alive, true, hint) end
	box.LegendGap = {Left = legend.LayoutX, Right = legend.LayoutX + legend.OuterWidth, Top = extra / 2}
	return extra
end

return FieldsetLayout
