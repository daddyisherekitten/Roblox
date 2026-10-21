--!strict
-- Shared, antialiased disclosure masks. One pair is allocated lazily per page.
local Icons = {}
local SIZE = 12
local ROWS = {
	{0, 146, 18}, {1, 238, 110}, {3, 202, 74}, {5, 166, 38},
	{7, 131, 2}, {8, 223, 95}, {8, 250, 123}, {7, 158, 30},
	{5, 194, 66}, {3, 230, 102}, {2, 138, 9}, {0, 174, 45},
}

local function mask(open: boolean): buffer
	local pixels = buffer.create(SIZE * SIZE * 4)
	for row, parts in ROWS do
		for x = 0, SIZE - 1 do
			local alpha = if x < parts[1] then 255 elseif x == parts[1] then parts[2]
				elseif x == parts[1] + 1 then parts[3] else 0
			local px, py = if open then SIZE - row else x, if open then x else row - 1
			local offset = (py * SIZE + px) * 4
			buffer.writeu8(pixels, offset, 255)
		buffer.writeu8(pixels, offset + 1, 255)
		buffer.writeu8(pixels, offset + 2, 255)
		buffer.writeu8(pixels, offset + 3, alpha)
		end
	end
	return pixels
end

function Icons.new(diagnostic: any, createImage: any?): any
	local images, contents = {}, nil
	local alive, attempted = true, false
	local cache = {}
	function cache:Get(open: boolean): any?
		if not alive then return nil end
		if not attempted then
			attempted = true
			local ok, result = pcall(function()
				local pair = {}
				for _, direction in {false, true} do
					local size = Vector2.new(SIZE, SIZE)
					local image = if createImage then createImage(size) else game:GetService("AssetService"):CreateEditableImage({Size = size})
					assert(image, "EditableImage allocation unavailable")
					if not alive then image:Destroy(); return nil end
					table.insert(images, image)
					image:WritePixelsBuffer(Vector2.new(0, 0), size, mask(direction))
					if not alive then return nil end
					local content = Content.fromObject(image)
					if not alive then return nil end
					pair[if direction then "Open" else "Closed"] = content
				end
				return pair
			end)
			if not alive then return nil end
			if ok then contents = result else
				for _, image in images do image:Destroy() end
				table.clear(images)
				diagnostic("Disclosure marker: " .. tostring(result) .. "; using frame fallback.")
			end
		end
		return contents and contents[if open then "Open" else "Closed"] or nil
	end
	function cache:Destroy()
		if not alive then return end
		alive = false
		for _, image in images do image:Destroy() end
		table.clear(images)
		contents = nil
	end
	return cache
end

return Icons
