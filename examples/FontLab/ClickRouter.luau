--!strict
-- First-stage router for the font lab, not the future full DOM event system.
-- ScreenGui only, without rotated/scaled ancestors. No per-frame polling.
local UserInputService = game:GetService("UserInputService")
local ClickRouter = {}
ClickRouter.__index = ClickRouter

local function contains(object: GuiObject, point: Vector2): boolean
	local position, size = object.AbsolutePosition, object.AbsoluteSize
	return point.X >= position.X and point.Y >= position.Y
		and point.X < position.X + size.X and point.Y < position.Y + size.Y
end

local function hit(object: GuiObject, root: GuiObject, point: Vector2): boolean
	if not object:IsDescendantOf(root) or not contains(object, point) then return false end
	local current: Instance? = object
	while current do
		if current:IsA("GuiObject") then
			if not current.Visible then return false end
			if (current.ClipsDescendants or current == root) and not contains(current, point) then
				return false
			end
		elseif current:IsA("ScreenGui") and not current.Enabled then
			return false
		end
		current = current.Parent
	end
	return true
end

function ClickRouter.new(root: GuiObject)
	local self: any = setmetatable({ Root = root, _targets = {}, _pressed = nil }, ClickRouter)
	self._began = UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		self._pressed = nil
		if processed then return end
		self._pressed = self:_Find(Vector2.new(input.Position.X, input.Position.Y))
	end)
	self._ended = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		local pressed = self._pressed
		self._pressed = nil
		if pressed and self:_Find(Vector2.new(input.Position.X, input.Position.Y)) == pressed then
			pressed.Callback()
		end
	end)
	self._focusLost = UserInputService.WindowFocusReleased:Connect(function()
		self._pressed = nil
	end)
	-- Cancel a click if native scrolling moves the page while pressed.
	self._scroll = root:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self._pressed = nil
	end)
	return self
end

function ClickRouter.Register(self: any, object: GuiObject, callback: () -> ())
	table.insert(self._targets, { Object = object, Callback = callback })
end

function ClickRouter._Find(self: any, point: Vector2): any
	-- Lab targets never overlap. Full CSS stacking/occlusion is a later module.
	for index = #self._targets, 1, -1 do
		local target = self._targets[index]
		if hit(target.Object, self.Root, point) then return target end
	end
	return nil
end

function ClickRouter.Destroy(self: any)
	self._began:Disconnect()
	self._ended:Disconnect()
	self._focusLost:Disconnect()
	self._scroll:Disconnect()
	self._pressed = nil
	table.clear(self._targets)
end

return ClickRouter
