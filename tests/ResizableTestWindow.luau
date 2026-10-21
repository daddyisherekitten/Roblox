--!strict
-- Exercise the actual demo controller with mouse/touch events and host changes.
return function(loadWindow: any)
	local function signal()
		local entries, self = {}, {}
		function self:Connect(callback)
			local connection = {Connected = true}
			function connection:Disconnect() self.Connected = false end
			table.insert(entries, {Connection = connection, Callback = callback})
			return connection
		end
		function self:Fire(...)
			for _, entry in entries do if entry.Connection.Connected then entry.Callback(...) end end
		end
		function self:Count()
			local count = 0
			for _, entry in entries do if entry.Connection.Connected then count += 1 end end
			return count
		end
		return self
	end
	local vector = {}
	local vectorMeta = {__sub = function(a,b) return vector.new(a.X-b.X,a.Y-b.Y) end}
	function vector.new(x,y) return setmetatable({X=x,Y=y},vectorMeta) end
	local function gui(class)
		local data = {ClassName = class, Children = {}, Attributes = {}, Destroying = signal(),
			InputBegan = signal(), MouseEnter = signal(), MouseLeave = signal(), DestroyCalls = 0}
		local properties, attributes = {}, {}
		local self = setmetatable({}, {__index = data, __newindex = function(object,key,value)
			data[key] = value
			if key == "Parent" and value then table.insert(value.Children, object) end
			if key == "Size" then data.AbsoluteSize = vector.new(value[1],value[2]) end
			if key == "Position" and data.Parent then
				data.AbsolutePosition = vector.new(data.Parent.AbsolutePosition.X+value[1],data.Parent.AbsolutePosition.Y+value[2])
			end
		end})
		function data:GetPropertyChangedSignal(key)
			properties[key] = properties[key] or signal(); return properties[key]
		end
		function data:GetAttributeChangedSignal(key)
			attributes[key] = attributes[key] or signal(); return attributes[key]
		end
		function data:GetAttribute(key) return data.Attributes[key] end
		function data:SetAttribute(key,value)
			local changed = data.Attributes[key] ~= value
			data.Attributes[key] = value
			if changed then self:GetAttributeChangedSignal(key):Fire() end
		end
		function data:Destroy()
			data.DestroyCalls += 1; assert(data.DestroyCalls == 1)
			data.Destroying:Fire()
			for _, child in data.Children do child:Destroy() end
		end
		return self
	end
	local input = {InputBegan = signal(), InputChanged = signal(), InputEnded = signal(), WindowFocusReleased = signal()}
	local replicated = {}
	function replicated:WaitForChild() return self end
	local game = {GetService = function(_,name) return if name == "UserInputService" then input else replicated end}
	local cursorKind, cursorDestroyed = nil, false
	local lease = {new = function(service,priority)
		assert(service == input and priority == 100)
		return {Set = function(_,kind) assert(not cursorDestroyed); cursorKind = kind end,
			Destroy = function() assert(not cursorDestroyed); cursorKind = nil; cursorDestroyed = true end}
	end}
	local host = gui("ScreenGui")
	host.AbsolutePosition, host.AbsoluteSize = vector.new(0,0), vector.new(1000,800)
	local target = gui("Frame")
	target.Parent = host
	local window = loadWindow(game, {new = gui}, vector, function(id) assert(id == replicated); return lease end)
	local stop = window(target)
	local controls = target.Children[1]
	local grips = {}
	for _, child in controls.Children do if child.ClassName == "Frame" then grips[child.Name] = child end end
	assert(target:GetAttribute("HTMLViewportResizing") == false and target.AbsoluteSize.X == 480)
	local function begin(grip,kind)
		local event = {UserInputType = kind, Position = vector.new(504,776)}
		grip.InputBegan:Fire(event)
		assert(target:GetAttribute("HTMLViewportResizing") == true)
		return event
	end
	begin(grips.Corner11,Enum.UserInputType.MouseButton1)
	assert(cursorKind == "nwse-resize")
	host:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	assert(target:GetAttribute("HTMLViewportResizing") == true and cursorKind == "nwse-resize",
		"A delayed host notification with unchanged dimensions cannot release a held grip")
	input.InputChanged:Fire({UserInputType = Enum.UserInputType.MouseMovement, Position = vector.new(600,700)})
	assert(target.AbsoluteSize.X == 576 and target.AbsoluteSize.Y == 636 and target:GetAttribute("HTMLViewportResizing") == true)
	input.InputEnded:Fire({UserInputType = Enum.UserInputType.Keyboard})
	assert(target:GetAttribute("HTMLViewportResizing") == true, "An unrelated release cannot finish a mouse gesture")
	input.InputEnded:Fire({UserInputType = Enum.UserInputType.MouseButton1})
	assert(target:GetAttribute("HTMLViewportResizing") == false and cursorKind == nil, "Global release outside the grip finishes the gesture")
	local touch = begin(grips.Corner11,Enum.UserInputType.Touch)
	input.InputChanged:Fire({UserInputType = Enum.UserInputType.Touch,Position = vector.new(1,1)})
	assert(target.AbsoluteSize.X == 576, "A different touch must not resize this window")
	touch.Position = vector.new(614,786); input.InputChanged:Fire(touch)
	assert(target.AbsoluteSize.X == 686 and target.AbsoluteSize.Y == 646)
	input.InputEnded:Fire({UserInputType = Enum.UserInputType.Touch})
	assert(target:GetAttribute("HTMLViewportResizing") == true)
	input.InputEnded:Fire(touch)
	assert(target:GetAttribute("HTMLViewportResizing") == false, "Only the tracked touch releases its gesture")
	begin(grips.Corner00,Enum.UserInputType.MouseButton1)
	input.WindowFocusReleased:Fire()
	assert(target:GetAttribute("HTMLViewportResizing") == false and cursorKind == nil, "Focus loss cannot leave layout waiting indefinitely")
	begin(grips.Corner11,Enum.UserInputType.MouseButton1)
	local committed = false
	target:GetAttributeChangedSignal("HTMLViewportResizing"):Connect(function()
		if target:GetAttribute("HTMLViewportResizing") == false then
			assert(target.AbsoluteSize.X == 320 and target.AbsoluteSize.Y == 240, "Host size is committed before ending the gesture")
			committed = true
		end
	end)
	host.AbsoluteSize = vector.new(320,240); host:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	assert(committed and target:GetAttribute("HTMLViewportResizing") == false)
	input.InputChanged:Fire({UserInputType = Enum.UserInputType.MouseMovement,Position = vector.new(900,790)})
	assert(target.AbsoluteSize.X == 320, "A fullscreen/host change cancels the old drag origin")
	begin(grips.Corner01,Enum.UserInputType.MouseButton1)
	stop(); stop()
	assert(target:GetAttribute("HTMLViewportResizing") == false and cursorDestroyed and controls.DestroyCalls == 1)
	assert(input.InputChanged:Count() == 0 and input.InputEnded:Count() == 0 and input.WindowFocusReleased:Count() == 0
		and input.InputBegan:Count() == 0 and target.Destroying:Count() == 0
		and host:GetPropertyChangedSignal("AbsoluteSize"):Count() == 0, "Disposal disconnects all gesture callbacks")
	for _, grip in grips do assert(grip.InputBegan:Count() == 0 and grip.MouseEnter:Count() == 0 and grip.MouseLeave:Count() == 0) end
	print("Resize grips: exact mouse/touch release, cursor, focus loss, host size jump and disposal passed")
end
