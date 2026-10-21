--!strict
local Range=require(script.Parent.RangeValue)
local Geometry=require(script.Parent.Parent.Layout.BorderGeometry)
local View={}
local function rounded(factory: any,parent: any,name: string): any
	local frame=factory.create("Frame",parent,{Name=name,BackgroundTransparency=0})
	factory.modifier("UICorner",frame,{CornerRadius=UDim.new(.5,0)})
	return frame
end
function View.create(item: any,factory: any)
	item.RangeTrack=rounded(factory,item.BoxGui,"RangeTrack")
	item.RangeTrackStroke=factory.modifier("UIStroke",item.RangeTrack,{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
		BorderStrokePosition=Enum.BorderStrokePosition.Inner,LineJoinMode=Enum.LineJoinMode.Round,
		Thickness=1,Color=Color3.fromRGB(178,178,178)})
	item.RangeFill=rounded(factory,item.BoxGui,"RangeFill")
	item.RangeThumb=rounded(factory,item.BoxGui,"RangeThumb")
end
function View.geometry(item: any): (number,number,number,number)
	local top,_,_,left=Geometry.sizes(item.Style)
	local width,height=item.ContentWidth or 129,item.ContentHeight or 16
	local diameter=math.max(0,math.min(16,width,height))
	return left+item.Style.Padding[4],top+item.Style.Padding[1]+height/2,math.max(0,width-diameter),diameter
end
function View.paint(item: any)
	local c=item.Control
	local x,y,travel,diameter=View.geometry(item)
	local distance=travel*Range.ratio(c)
	local overThumb=false
	if c.RangePointer and diameter > 0 then
		local origin,size=item.BoxGui.AbsolutePosition,item.BoxGui.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			local dx=(c.RangePointer.X-origin.X)*(item.BoxWidth or size.X)/size.X-x-distance-diameter/2
			local dy=(c.RangePointer.Y-origin.Y)*(item.BoxHeight or size.Y)/size.Y-y
			overThumb=dx*dx+dy*dy <= diameter*diameter/4
		end
	end
	local accent=item.Style.AccentColor or Color3.fromRGB(0,117,255)
	local pressed=if item.Style.AccentColor then Color3.new(math.min(1,accent.R+.2),math.min(1,accent.G+.2),math.min(1,accent.B+.2)) else Color3.fromRGB(57,147,255)
	local baseColor=if c.Disabled then Color3.fromRGB(198,198,198) elseif c.Pressed then pressed else accent
	local canHover=not c.Disabled and not c.Pressed
	local overTrack=c.Hovered and c.RangePointer ~= nil
	local hoverColor=if item.Style.AccentColor then Color3.new(accent.R*.8,accent.G*.8,accent.B*.8) else Color3.fromRGB(0,95,204)
	local thickness=math.min(8,diameter)
	item.RangeTrack.Position=UDim2.fromOffset(x+diameter/2,y-thickness/2)
	item.RangeTrack.Size=UDim2.fromOffset(travel,thickness)
	local trackGray=if c.Disabled or c.Pressed then 245 elseif overTrack then 229 else 239
	item.RangeTrack.BackgroundColor3=Color3.fromRGB(trackGray,trackGray,trackGray)
	item.RangeFill.Position=item.RangeTrack.Position
	item.RangeFill.Size=UDim2.fromOffset(distance,thickness)
	item.RangeFill.BackgroundColor3=if canHover and overTrack then hoverColor else baseColor
	item.RangeThumb.Position=UDim2.fromOffset(x+distance,y-diameter/2)
	item.RangeThumb.Size=UDim2.fromOffset(diameter,diameter)
	item.RangeThumb.BackgroundColor3=if canHover and overThumb then hoverColor else baseColor
end
return View
