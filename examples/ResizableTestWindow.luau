--!strict
-- Temporary demo controls; independent of HTML/CSS rendering.
local Input = game:GetService("UserInputService")
local CursorLease = require(game:GetService("ReplicatedStorage"):WaitForChild("HTMLEngine"):WaitForChild("Input"):WaitForChild("CursorLease"))

return function(target: Frame): () -> ()
	local host = target.Parent :: ScreenGui
	local connections: {RBXScriptConnection} = {}
	local dragging: any = nil
	local cursor=CursorLease.new(Input,100)
	local hoveredCursor: string?=nil
	local function refreshCursor()
		cursor:Set(if dragging and dragging.Input.UserInputType == Enum.UserInputType.MouseButton1 then dragging.Cursor else hoveredCursor)
	end
	local function finishDrag()
		dragging = nil
		refreshCursor()
		target:SetAttribute("HTMLViewportResizing", false)
	end
	local disposed, initialized = false, false
	local fittedWidth, fittedHeight: number? = nil, nil
	local controls = Instance.new("Frame")
	controls.Name = "ResizeControls"
	controls.Active = false
	controls.Selectable = false
	controls.BorderSizePixel = 0
	controls.BackgroundTransparency = 1
	controls.Size = UDim2.fromScale(1, 1)
	controls.ZIndex = 200
	controls.Parent = target
	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(75, 125, 200)
	border.Thickness = 1
	border.Parent = controls
	local function connect(signal: RBXScriptSignal, callback: any)
		table.insert(connections, signal:Connect(callback))
	end
	local function fit()
		local view = host.AbsoluteSize
		-- Deferred host notifications can report the size already fitted above.
		-- Only a real host-size change may cancel the current drag origin.
		if view.X == fittedWidth and view.Y == fittedHeight then return end
		fittedWidth, fittedHeight = view.X, view.Y
		if view.X <= 0 or view.Y <= 0 then finishDrag(); return end
		dragging = nil
		refreshCursor()
		local pos = if initialized then target.AbsolutePosition - host.AbsolutePosition else Vector2.new(24, 64)
		local size = if initialized then target.AbsoluteSize else Vector2.new(480, view.Y - 88)
		local width = math.clamp(size.X, math.min(240, view.X), view.X)
		local height = math.clamp(size.Y, math.min(180, view.Y), view.Y)
		target.Position = UDim2.fromOffset(math.clamp(pos.X, 0, view.X - width), math.clamp(pos.Y, 0, view.Y - height))
		target.Size = UDim2.fromOffset(width, height)
		initialized = true
		-- Host changes (including fullscreen) commit their final size immediately.
		target:SetAttribute("HTMLViewportResizing", false)
	end
	for _, corner in {{0, 0}, {1, 0}, {0, 1}, {1, 1}} do
		local grip = Instance.new("Frame")
		grip.Name = "Corner" .. corner[1] .. corner[2]
		grip.Active = false
		grip:SetAttribute("HTMLInputBlocker",true)
		grip.Selectable = false
		grip.BorderSizePixel = 0
		grip.BackgroundColor3 = border.Color
		grip.Size = UDim2.fromOffset(16, 16)
		grip.AnchorPoint = Vector2.new(corner[1], corner[2])
		grip.Position = UDim2.fromScale(corner[1], corner[2])
		grip.ZIndex = 201
		grip.Parent = controls
		local icon=if corner[1] == corner[2] then "nwse-resize" else "nesw-resize"
		connect(grip.MouseEnter,function() hoveredCursor=icon; refreshCursor() end)
		connect(grip.MouseLeave,function() hoveredCursor=nil; refreshCursor() end)
		connect(grip.InputBegan, function(input: InputObject)
			if dragging or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then return end
			dragging = {Input = input, Pointer = Vector2.new(input.Position.X, input.Position.Y),
				Position = target.AbsolutePosition - host.AbsolutePosition, Size = target.AbsoluteSize, Corner = corner,Cursor=icon}
			target:SetAttribute("HTMLViewportResizing", true)
			refreshCursor()
		end)
	end
	connect(Input.InputChanged, function(input: InputObject)
		local drag = dragging
		if not drag then return end
		local mouse = drag.Input.UserInputType == Enum.UserInputType.MouseButton1
		if (mouse and input.UserInputType ~= Enum.UserInputType.MouseMovement) or (not mouse and input ~= drag.Input) then return end
		local delta = Vector2.new(input.Position.X, input.Position.Y) - drag.Pointer
		local view, pos, size = host.AbsoluteSize, drag.Position, drag.Size
		local left, top, right, bottom = pos.X, pos.Y, pos.X + size.X, pos.Y + size.Y
		if drag.Corner[1] == 0 then left = math.clamp(left + delta.X, 0, math.max(0, right - 240))
		else right = math.clamp(right + delta.X, math.min(view.X, left + 240), view.X) end
		if drag.Corner[2] == 0 then top = math.clamp(top + delta.Y, 0, math.max(0, bottom - 180))
		else bottom = math.clamp(bottom + delta.Y, math.min(view.Y, top + 180), view.Y) end
		target.Position = UDim2.fromOffset(left, top)
		target.Size = UDim2.fromOffset(right - left, bottom - top)
	end)
	connect(Input.InputEnded, function(input: InputObject)
		if dragging and (input == dragging.Input or (input.UserInputType == Enum.UserInputType.MouseButton1
			and dragging.Input.UserInputType == Enum.UserInputType.MouseButton1)) then finishDrag() end
	end)
	connect(Input.WindowFocusReleased, function() hoveredCursor=nil; finishDrag() end)
	connect(Input.InputBegan,function(event) if event.UserInputType == Enum.UserInputType.Touch then hoveredCursor=nil; cursor:Set(nil) end end)
	connect(host:GetPropertyChangedSignal("AbsoluteSize"), fit)
	local function destroy()
		if disposed then return end
		disposed, dragging = true, nil
		cursor:Destroy()
		for _, connection in connections do connection:Disconnect() end
		controls:Destroy()
		target:SetAttribute("HTMLViewportResizing", false)
	end
	connect(target.Destroying, destroy)
	fit()
	return destroy
end
