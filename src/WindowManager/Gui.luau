--!strict
local Gui={}
function Gui.new(create)
	local self={}
	function self:Make(class,parent,props)
		local object=if create then create(class,parent,props)else Instance.new(class)
		if object:IsA('GuiObject')then object.Active=false;object.Selectable=false;object.BorderSizePixel=0;object.BackgroundTransparency=1 end
		if object:IsA('TextLabel')then object.AutoLocalize=false;object.Text='';object.Font=Enum.Font.Gotham;object.TextSize=13;object.TextColor3=Color3.fromRGB(232,234,237)end
		for key,value in props or{}do object[key]=value end
		if object:IsA('GuiObject')then object.Active=false;object.Selectable=false end
		object.Parent=parent;return object
	end
	function self:Line(parent,name,x,y,w,h,rotation)
		return self:Make('Frame',parent,{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),Rotation=rotation or 0,BackgroundColor3=Color3.fromRGB(232,234,237),BackgroundTransparency=0})
	end
	return self
end
return Gui
