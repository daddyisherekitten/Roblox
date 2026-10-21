--!strict
local TextureUpload=require(script.Parent.TextureUpload)
-- Small white alpha tiles, tinted by each ImageLabel. No updates after creation.
local Pixels = require(script.Parent.DecorationPixels)
local DecorationPatterns = {}

function DecorationPatterns.new(diagnostic: (string) -> (), createImage: any?)
	local entries, count, pixels = {}, 0, 0
	local alive, unavailable, warned = true, false, false
	local cache = {}
	local function fallback(message: string)
		if warned then return end
		warned = true
		diagnostic("text-decoration-style: " .. message .. "; using solid lines.")
	end
	function cache:Get(style: string, thickness: number): any?
		if not alive then return nil end
		local width, height = Pixels.size(style, thickness)
		if not width or not height then fallback("pattern thickness outside 1–32 px"); return nil end
		local key = style .. ":" .. thickness
		if entries[key] then return entries[key] end
		if unavailable then return nil end
		if count >= 16 or pixels + width * height > 65536 then fallback("pattern budget reached"); return nil end
		local editable = nil
		local ok, result = pcall(function()
			local size = Vector2.new(width, height)
			editable = if createImage then createImage(size) else game:GetService("AssetService"):CreateEditableImage({Size = size})
			assert(editable, "EditableImage allocation unavailable")
			if not alive then return nil end
			TextureUpload.write(editable,size,Pixels.render(style,thickness),function()return alive end)
			if not alive then return nil end
			return {Image = editable, Content = Content.fromObject(editable), Width = width, Height = height}
		end)
		if not alive then
			if editable then editable:Destroy() end
			return nil
		end
		if not ok then
			if editable then editable:Destroy() end
			unavailable = true
			fallback(tostring(result))
			return nil
		end
		entries[key] = result
		count += 1; pixels += width * height
		return result
	end
	function cache:Destroy()
		if not alive then return end
		alive = false
		for _, entry in entries do entry.Image:Destroy() end
		table.clear(entries)
	end
	return cache
end

return DecorationPatterns
