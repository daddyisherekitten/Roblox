--!strict
local BorderGeometry = {}
function BorderGeometry.sizes(style: any): (number, number, number, number)
	if style.BorderSizes then return table.unpack(style.BorderSizes) end
	local size = style.BorderSize or 0
	return size, size, size, size
end
function BorderGeometry.rectangles(style: any, width: number, height: number): {any}
	local t, r, b, l = BorderGeometry.sizes(style)
	return {{0, 0, width, t}, {0, t, l, math.max(0, height - t - b)},
		{0, math.max(0, height - b), width, b}, {math.max(0, width - r), t, r, math.max(0, height - t - b)}}
end
-- Segments are local to a straight edge; its full CSS thickness remains unchanged.
function BorderGeometry.pattern(kind: string, length: number, thickness: number): {any}
	if length <= 0 or thickness <= 0 or kind == "none" then return {} end
	if kind == "groove" or kind == "ridge" then
		local half = if thickness < 2 then thickness / 2 else math.floor(thickness / 2 + .5)
		return {{0, 0, length, half}, {0, half, length, thickness - half}}
	end
	if kind == "double" and thickness >= 3 then
		local stroke = math.max(1, math.floor(thickness / 3 + .5))
		return {{0, 0, length, stroke}, {0, thickness - stroke, length, stroke}}
	end
	if kind ~= "dashed" and kind ~= "dotted" then return {{0, 0, length, thickness}} end
	local mark = math.min(length, thickness * (if kind == "dashed" then 3 else 1))
	local gap = thickness * (if kind == "dashed" then 3 else 1)
	local count = math.clamp(math.floor((length + gap) / (mark + gap)), 1, 128)
	local step = if count > 1 then (length - mark) / (count - 1) else 0
	local start = if count == 1 then (length - mark) / 2 else 0
	local parts = {}
	local cross = if kind == "dotted" then mark else thickness
	for index = 1, count do table.insert(parts, {start + (index - 1) * step, (thickness - cross) / 2, mark, cross}) end
	return parts
end
return BorderGeometry
