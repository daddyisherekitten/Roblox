--!strict
local WorkContext=require(script.Parent.Parent.WorkContext)
-- Prototype geometry scales with CSS stroke thickness, independently of font.
local Pixels = {}
function Pixels.size(style: string, thickness: number): (number?, number?)
	if thickness < 1 or thickness > 32 or thickness % 1 ~= 0 then return nil, nil end
	if style == "dotted" then return thickness * 2, thickness end
	if style == "dashed" then return thickness * 6, thickness end
	if style == "wavy" then return thickness * 8, thickness * 3 end
	return nil, nil
end

function Pixels.render(style: string, thickness: number): buffer
	local width, height = Pixels.size(style, thickness)
	assert(width and height, "Unsupported decoration pattern")
	local data = buffer.create(width * height * 4)
	local radius = thickness / 2
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			if x%64==0 then WorkContext.checkpoint()end
			local coverage = 0
			-- Four-by-four coverage keeps small dots and waves legible at 1 px.
			for sy = 0, 3 do
				for sx = 0, 3 do
					local px, py = x + (sx + 0.5) / 4, y + (sy + 0.5) / 4
					local inside
					if style == "dotted" then
						inside = (px - radius)^2 + (py - radius)^2 <= radius^2
					elseif style == "dashed" then inside = px < thickness * 3
					else
						local angle = px * 2 * math.pi / width
						local center = height / 2 + thickness * math.sin(angle)
						local slope = thickness * 2 * math.pi / width * math.cos(angle)
						inside = math.abs(py - center) / math.sqrt(1 + slope * slope) <= radius
					end
					if inside then coverage += 1 end
				end
			end
			local offset = (y * width + x) * 4
			buffer.writeu32(data, offset, 0x00ffffff)
			buffer.writeu8(data, offset + 3, math.round(255 * coverage / 16))
		end
	end
	return data
end

return Pixels
