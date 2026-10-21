--!strict
-- Paint only: this layer never contributes to layout or scroll extents.
local BorderBox = require(script.Parent.BorderBox)
local OutlineBox = {}
local function write(gui: any, key: string, value: any)
	if gui[key] ~= value then gui[key] = value end
end
function OutlineBox.visible(style: any): boolean
	return style.Visibility~="hidden" and (style.OutlineStyle or "none")~="none"
		and (style.OutlineStyle=="auto" or (style.OutlineWidth or 0)>0)
end
local function geometry(style: any): (number, string, number, number)
	if style.OutlineStyle=="auto" then
		-- Chromium/Windows focus profile: a rounded 2px ring straddles the
		-- border edge. CSS UI explicitly ignores outline-width for auto.
		return 2,"solid",math.max(2,style.BorderRadius or 0),(style.OutlineOffset or 0)-1
	end
	return style.OutlineWidth,style.OutlineStyle,style.BorderRadius or 0,style.OutlineOffset or 0
end
function OutlineBox.outset(style: any): number
	if not OutlineBox.visible(style) then return 0 end
	local width,_,_,offset=geometry(style)
	return math.max(0,width+offset)
end
function OutlineBox.create(style: any, parent: any, factory: any, corners: any?): any?
	if not OutlineBox.visible(style) then return nil end
	local width,kind,radius,offset=geometry(style)
	local gui = factory.create("Frame", parent, {Name = "Outline", ZIndex = 100001})
	if gui.SetAttribute then gui:SetAttribute("HTMLPaintOnlyOverlay",true) end
	local paint = {BorderSize = width, BorderStyle = kind,
		BorderColor = style.OutlineColor, BorderColorAlpha = style.OutlineColorAlpha or 1,
		BorderRadius = radius}
	local corner = if paint.BorderRadius > 0 and paint.BorderStyle == "solid"
		then factory.modifier("UICorner", gui, {CornerRadius = UDim.new(0, paint.BorderRadius)}) else nil
	return {Gui = gui, Style = paint, Edges = BorderBox.create(paint, gui, factory, corners), Corner = corner, Offset = offset}
end
function OutlineBox.update(box: any, style: any, factory: any, corners: any?): boolean
	local visible=OutlineBox.visible(style)
	local outline=box.Outline
	if not visible then
		local changed=outline~=nil and outline.Gui.Visible~=false
		if outline then write(outline.Gui,"Visible",false) end
		return changed
	end
	local width,kind,radius,offset=geometry(style)
	local changed=outline==nil or outline.Gui.Visible==false
		or outline.Style.BorderSize~=width or outline.Offset~=offset
	if not outline then
		outline=OutlineBox.create(style,box.Gui,factory,corners)
		box.Outline=outline
	end
	if not outline then return false end
	write(outline.Gui,"Visible",true)
	local paint=outline.Style
	paint.BorderSize=width
	paint.BorderStyle=kind
	paint.BorderColor=style.OutlineColor
	paint.BorderColorAlpha=style.OutlineColorAlpha or 1
	paint.BorderRadius=radius
	outline.Offset=offset
	if kind=="solid" and radius>0 and not outline.Corner then
		outline.Corner=factory.modifier("UICorner",outline.Gui,{CornerRadius=UDim.new(0,radius)})
	elseif outline.Corner and (kind~="solid" or radius==0) then
		write(outline.Corner,"CornerRadius",UDim.new(0,0))
	end
	if box.OuterWidth and box.OuterHeight then
		local dx=math.max(-box.OuterWidth/2,offset)+width
		local dy=math.max(-box.OuterHeight/2,offset)+width
		outline.Edges=BorderBox.update(outline.Edges,paint,outline.Gui,box.OuterWidth+2*dx,box.OuterHeight+2*dy,factory,corners)
		OutlineBox.arrange(outline,box.OuterWidth,box.OuterHeight)
	end
	return changed
end
function OutlineBox.arrange(outline: any, width: number, height: number)
	local stroke = outline.Style.BorderSize
	-- Clamp each axis independently so extreme negative offsets still leave a drawable ring.
	local dx = math.max(-width / 2, outline.Offset) + stroke
	local dy = math.max(-height / 2, outline.Offset) + stroke
	local w, h = width + 2 * dx, height + 2 * dy
	write(outline.Gui, "Position", UDim2.fromOffset(-dx, -dy))
	write(outline.Gui, "Size", UDim2.fromOffset(w, h))
	if outline.Corner then
		local radius=if outline.Style.BorderStyle=="solid" then math.max(0,math.min(w/2,h/2,outline.Style.BorderRadius+math.min(dx,dy))) else 0
		write(outline.Corner, "CornerRadius", UDim.new(0, radius))
	end
	if outline.Edges then BorderBox.arrange(outline.Edges, outline.Style, w, h) end
end
return OutlineBox
