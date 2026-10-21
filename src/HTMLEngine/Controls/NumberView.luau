--!strict
local Geometry=require(script.Parent.Parent.Layout.BorderGeometry)
local View={ReservedWidth=18}
local function geometry(item: any): (number,number,number,number)
	local top,right,bottom,left=Geometry.sizes(item.Style)
	local innerHeight=math.max(0,(item.BoxHeight or 21)-top-bottom)
	local height=math.min(14,innerHeight)
	local width=math.max(0,math.min(15,(item.BoxWidth or 120)-left-right-3))
	return (item.BoxWidth or 120)-right-3-width,top+math.floor((innerHeight-height)/2),width,height
end
function View.create(item: any,factory: any)
	item.NumberArrows={}
	item.NumberGlyphs={}
	for _,direction in {1,-1} do
		local frame=factory.create("Frame",item.BoxGui,{Name=if direction == 1 then "StepUp" else "StepDown",BackgroundTransparency=0})
		local glyph=factory.create("Frame",frame,{Name="Arrow",Size=UDim2.fromOffset(7,4),BackgroundTransparency=1})
		for row=0,3 do
			factory.create("Frame",glyph,{Name="ArrowRow",Position=UDim2.fromOffset(3-row,if direction == 1 then row else 3-row),
				Size=UDim2.fromOffset(row*2+1,1),BackgroundTransparency=0,BackgroundColor3=Color3.fromRGB(139,139,139)})
		end
		item.NumberArrows[direction]=frame
		item.NumberGlyphs[direction]=glyph
	end
end
function View.paint(item: any)
	local c=item.Control
	local x,y,width,totalHeight=geometry(item)
	local height=totalHeight/2
	for direction,frame in item.NumberArrows do
		frame.Visible=(c.Hovered or c.Focused or false) and not c.Disabled and not c.ReadOnly
		frame.Position=UDim2.fromOffset(x,y+(if direction == 1 then 0 else height))
		frame.Size=UDim2.fromOffset(width,height)
		item.NumberGlyphs[direction].Position=UDim2.fromOffset(math.floor((width-7)/2),
			math.floor((height-4)/2)+(if direction == 1 then 0 else 1))
		local gray=if c.Pressed and c.NumberPressed == direction then 245 elseif c.NumberHovered == direction then 218 else 252
		frame.BackgroundColor3=Color3.fromRGB(gray,gray,gray)
	end
end
function View.direction(c: any,position: any): number?
	if c.Type ~= "number" or c.Disabled or c.ReadOnly or not position then return nil end
	local item=c.Item
	local origin,size=item.BoxGui.AbsolutePosition,item.BoxGui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return nil end
	local x=(position.X-origin.X)*item.BoxWidth/size.X
	local y=(position.Y-origin.Y)*item.BoxHeight/size.Y
	local left,top,width,height=geometry(item)
	if x < left or x >= left+width or y < top or y >= top+height then return nil end
	return if y < top+height/2 then 1 else -1
end
return View
