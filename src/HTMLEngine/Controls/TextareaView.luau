--!strict
local Geometry=require(script.Parent.Parent.Layout.BorderGeometry)
local Grip=require(script.Parent.Parent.Rendering.ResizeGrip)
local View={}
function View.create(item: any,factory: any,cache: any?)
	local content=if cache then cache:Get() else nil
	item.ResizeGrip=factory.create(if content then "ImageLabel" else "Frame",item.BoxGui,
		{Name="TextareaResizeGrip",Size=UDim2.fromOffset(12,12),BackgroundTransparency=1})
	if content then item.ResizeGrip.ImageContent=content
	else
		for _,point in Grip.Points do
			factory.create("Frame",item.ResizeGrip,{Name="GripPixel",Position=UDim2.fromOffset(point[1],point[2]),Size=UDim2.fromOffset(1,1),BackgroundTransparency=0,BackgroundColor3=Grip.Color})
		end
	end
end
function View.paint(item: any)
	local _,right,bottom=Geometry.sizes(item.Style)
	item.ResizeGrip.Position=UDim2.new(1,-right-12,1,-bottom-12)
	item.ResizeGrip.Visible=(item.Control.LayoutStyle or item.Style).Resize ~= "none" and item.Style.Visibility ~= "hidden"
end
function View.hit(c: any,position: any): boolean
	if not c or c.Type ~= "textarea" or (c.LayoutStyle or c.Item.Style).Resize == "none" or c.Item.Style.Visibility == "hidden" then return false end
	local item=c.Item
	local origin,size=item.BoxGui.AbsolutePosition,item.BoxGui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 or not item.BoxWidth or not item.BoxHeight then return false end
	local x=(position.X-origin.X)*item.BoxWidth/size.X
	local y=(position.Y-origin.Y)*item.BoxHeight/size.Y
	local _,right,bottom=Geometry.sizes(item.Style)
	return x >= item.BoxWidth-right-12 and x < item.BoxWidth-right and y >= item.BoxHeight-bottom-12 and y < item.BoxHeight-bottom
end
return View
