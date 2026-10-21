--!strict
-- One white alpha mask per page; ImageColor3 supplies each radio's current blue.
local RadioDot = {}
local SIZE = 9
-- Alpha coverage sampled from the user's enlarged HTML reference, center outward.
-- Reflect one quadrant to keep the 9px mask exactly centered and symmetric.
local COVERAGE = {
	{255, 255, 255, 255, 102},
	{255, 255, 255, 255, 70},
	{255, 255, 255, 202, 0},
	{255, 255, 202, 40, 0},
	{102, 70, 0, 0, 0},
}

local function pixels(): buffer
	local result = buffer.create(SIZE * SIZE * 4)
	local center = (SIZE - 1) / 2
	for y = 0, SIZE - 1 do
		for x = 0, SIZE - 1 do
			local offset = (y * SIZE + x) * 4
			buffer.writeu8(result, offset, 255)
			buffer.writeu8(result, offset + 1, 255)
			buffer.writeu8(result, offset + 2, 255)
			buffer.writeu8(result, offset + 3, COVERAGE[math.abs(y - center) + 1][math.abs(x - center) + 1])
		end
	end
	return result
end

function RadioDot.new(diagnostic: any, createImage: any?): any
	local image, content = nil, nil
	local alive, attempted = true, false
	local cache = {}
	function cache:Get(): any?
		if not alive then return nil end
		if attempted then return content end
		attempted = true
		local ok, result = pcall(function()
			local size = Vector2.new(SIZE, SIZE)
			image = if createImage then createImage(size) else game:GetService("AssetService"):CreateEditableImage({Size = size})
			assert(image, "EditableImage allocation unavailable")
			if not alive then return nil end
			image:WritePixelsBuffer(Vector2.new(0, 0), size, pixels())
			if not alive then return nil end
			return Content.fromObject(image)
		end)
		if not alive then
			if image then image:Destroy(); image=nil end
			return nil
		end
		if not ok then
			if image then image:Destroy(); image = nil end
			diagnostic("Radio dot: " .. tostring(result) .. "; using rounded frame.")
			return nil
		end
		content = result
		return content
	end
	function cache:Destroy()
		if not alive then return end
		alive = false
		if image then image:Destroy(); image = nil end
		content = nil
	end
	return cache
end

return RadioDot
