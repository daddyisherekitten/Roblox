--!strict
local Icons = require(script.Parent.CursorIcons)
local CursorPreload = {}
local started = false

-- Shared by all mounted pages in this client; never wait for downloads in layout.
function CursorPreload.start()
	if started then return end
	started = true
	task.spawn(function()
		local targets, seen = {}, {}
		local ok, message = pcall(function()
			for _, asset in Icons do
				if not seen[asset] then
					seen[asset] = true
					local image = Instance.new("ImageLabel")
					table.insert(targets, image)
					image.Image = asset
				end
			end
			-- Unparented labels request the image content without displaying any GUI.
			game:GetService("ContentProvider"):PreloadAsync(targets)
		end)
		for _, image in targets do image:Destroy() end
		-- Roblox reports individual failed assets itself. Do not retry on each reflow.
		if not ok then warn("Cursor preload failed: " .. tostring(message)) end
	end)
end

return CursorPreload
