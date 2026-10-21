--!strict
-- Passive overlay: the controller owns dismissal; no buttons or frame loop.
local Popup = {}
function Popup.new(page: any, services: any?): any
	local self = {Control=nil}
	local host, connections = nil, {}
	function self:Close()
		self.Control=nil
		for _, connection in connections do connection:Disconnect() end
		table.clear(connections)
		if host then host:Destroy(); host=nil end
	end
	function self:Open(c: any, message: string)
		self:Close()
		if not page.Alive or c.Disabled then return end
		local root, box = page.Root, c.Item.BoxGui
		local parent = root.Parent
		if not parent then return end
		local p, size, viewport, bounds = box.AbsolutePosition, box.AbsoluteSize, root.AbsolutePosition, root.AbsoluteSize
		if bounds.X < 80 or bounds.Y < 45 or p.Y+size.Y <= viewport.Y or p.Y >= viewport.Y+bounds.Y
			or p.X+size.X <= viewport.X or p.X >= viewport.X+bounds.X then return end
		local factory = if services and services.Factory then services.Factory else require(script.Parent.Parent.Rendering.GuiFactory)
		local width = math.min(300, bounds.X-4)
		local textWidth = width-48
		local measure = if services and services.MeasureValidationText then services.MeasureValidationText else function(text, available)
			return game:GetService("TextService"):GetTextSize(text,14,Enum.Font.Arial,Vector2.new(available,10000))
		end
		local measured = measure(message,textWidth)
		if not page.Alive then return end
		local height = math.min(bounds.Y-4, math.max(44, math.ceil(measured.Y*1.35)+20)+7)
		local x = math.clamp(p.X,viewport.X+2,viewport.X+bounds.X-width-2)
		local above = p.Y+size.Y+height > viewport.Y+bounds.Y and p.Y-viewport.Y > viewport.Y+bounds.Y-p.Y-size.Y
		local y = math.clamp(if above then p.Y-height else p.Y+size.Y,viewport.Y+2,viewport.Y+bounds.Y-height-2)
		local border, white = Color3.fromRGB(128,128,128), Color3.new(1,1,1)
		local parentPoint=if parent:IsA("GuiObject")then parent.AbsolutePosition else Vector2.new(0,0)
		host = factory.create("Frame",parent,{Name="ValidationPopup",ZIndex=1000001,BackgroundTransparency=1,
			Position=UDim2.fromOffset(x-parentPoint.X,y-parentPoint.Y),Size=UDim2.fromOffset(width,height)})
		self.Control=c
		local bodyY = if above then 0 else 7
		local arrowX = math.clamp(p.X+math.min(18,size.X/2)-x,10,width-10)
		-- The body covers half the rotated square, leaving an outlined triangular tip.
		local arrow = factory.create("Frame",host,{Name="ValidationArrow",ZIndex=1000002,Rotation=45,BackgroundTransparency=0,BackgroundColor3=white,
			Position=UDim2.fromOffset(arrowX-5,if above then height-13 else 3),Size=UDim2.fromOffset(10,10)})
		factory.modifier("UIStroke",arrow,{Thickness=1,Color=border,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,BorderStrokePosition=Enum.BorderStrokePosition.Inner})
		local body = factory.create("Frame",host,{Name="ValidationBody",ZIndex=1000003,BackgroundTransparency=0,BackgroundColor3=white,
			Position=UDim2.fromOffset(0,bodyY),Size=UDim2.fromOffset(width,height-7)})
		factory.modifier("UICorner",body,{CornerRadius=UDim.new(0,3)})
		factory.modifier("UIStroke",body,{Thickness=1,Color=border,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,BorderStrokePosition=Enum.BorderStrokePosition.Inner,LineJoinMode=Enum.LineJoinMode.Round})
		pcall(factory.modifier,"UIShadow",body,{Enabled=true,ZIndex=-1,Color=Color3.new(0,0,0),Transparency=.72,BlurRadius=UDim.new(0,4),Offset=UDim2.fromOffset(1,2)})
		factory.create("Frame",body,{Name="ArrowSeam",ZIndex=1000004,BackgroundTransparency=0,BackgroundColor3=white,
			Position=UDim2.fromOffset(arrowX-6,if above then height-8 else 0),Size=UDim2.fromOffset(12,1)})
		local icon=factory.create("Frame",body,{Name="ValidationIcon",ZIndex=1000004,BackgroundTransparency=0,BackgroundColor3=Color3.fromRGB(239,108,0),
			Position=UDim2.fromOffset(8,9),Size=UDim2.fromOffset(22,22)})
		factory.modifier("UICorner",icon,{CornerRadius=UDim.new(0,2)})
		for _, rect in {{9,4,4,9},{9,16,4,3}} do
			factory.create("Frame",icon,{Name="Exclamation",ZIndex=1000005,BackgroundTransparency=0,BackgroundColor3=white,
				Position=UDim2.fromOffset(rect[1],rect[2]),Size=UDim2.fromOffset(rect[3],rect[4])})
		end
		factory.create("TextLabel",body,{Name="ValidationText",ZIndex=1000004,Font=Enum.Font.Arial,TextSize=14,LineHeight=1.35,
			Text=message,RichText=false,TextWrapped=true,TextColor3=Color3.fromRGB(32,32,32),BackgroundTransparency=1,
			Position=UDim2.fromOffset(40,9),Size=UDim2.fromOffset(textWidth,height-25)})
		for _, entry in {{box,"AbsolutePosition"},{box,"AbsoluteSize"},{root,"AbsolutePosition"},{root,"AbsoluteSize"},{root,"CanvasPosition"}} do
			table.insert(connections,entry[1]:GetPropertyChangedSignal(entry[2]):Connect(function() self:Close() end))
		end
	end
	return self
end
return Popup
