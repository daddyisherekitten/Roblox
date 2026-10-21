--!strict
-- Owns a page's resources. Destroying it also invalidates async work.
local PageSession = {}
PageSession.__index = PageSession

local function cleanup(self: any)
	if not self.Alive then return end
	self.Alive = false
	self._destroying:Disconnect()
	for index = #self._cleanups, 1, -1 do
		local success, message = pcall(self._cleanups[index])
		if not success then warn("Page cleanup: " .. tostring(message)) end
	end
	table.clear(self._cleanups)
end

function PageSession.new(root: GuiObject)
	local self: any = setmetatable({
		Root = root,
		Alive = true,
		_cleanups = {} :: { () -> () },
	}, PageSession)
	-- External removal cleans resources without recursively destroying the root.
	self._destroying = root.Destroying:Connect(function() cleanup(self) end)
	return self
end

function PageSession.AddCleanup(self: any, cleanup: () -> ())
	if not self.Alive then
		cleanup()
		return
	end
	table.insert(self._cleanups, cleanup)
end

function PageSession.Destroy(self: any)
	if not self.Alive then return end
	cleanup(self)
	self.Root:Destroy()
end

return PageSession
