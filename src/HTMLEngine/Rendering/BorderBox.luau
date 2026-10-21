--!strict
local PaintLayer=require(script.Parent.PaintLayer)
-- Uniform solid borders keep their native rounded stroke. Other borders use four strips.
local BorderBox = {}
local Geometry = require(script.Parent.Parent.Layout.BorderGeometry)
local SIDES = {1, 4, 3, 2}
local Paint = require(script.Parent.BorderPaint)
local Pattern = require(script.Parent.BorderPattern)
local nativeStrokes = setmetatable({}, {__mode = "k"})
local function write(gui: any, key: string, value: any)
	if gui[key] ~= value then gui[key] = value end
end
local function hasBackgroundImage(style: any): boolean
	for _, image in style.BackgroundImages or {} do
		if image.Kind ~= "none" then return true end
	end
	return false
end
function BorderBox.create(style: any, gui: any, factory: any, corners: any?): any?
	if style.Visibility == "hidden" then return nil end
	if style.Node and style.Node.Name == "fieldset" then
		-- Three transparent clipping regions leave a real gap, including on patterned borders.
		local regions = {}
		local borderStyle = table.clone(style)
		borderStyle.Node, borderStyle.BorderUniform = nil, false
		for index = 1, 3 do
			local clip = factory.create("Frame", gui, {Name = "FieldsetBorderClip_" .. index, BackgroundTransparency = 1, ClipsDescendants = true})
			local host = factory.create("Frame", clip, {Name = "FieldsetBorder", BackgroundTransparency = 1})
			regions[index] = {Clip = clip, Host = host, Edges = BorderBox.create(borderStyle, host, factory, corners)}
		end
		return {FieldsetRegions = regions}
	end
	-- UIStroke may only own borders whose corner geometry Roblox can express.
	-- Raster corner shapes (squircle/bevel/notch and elliptical radii) need four
	-- temporary strips which BorderBox.arrange hides once the raster surface is ready.
	local rasterCorners=style.BorderRadii and (style.BorderRadius==0 or style.CornerShape~="round") and not style.NativeCornerRadii
	if style.BorderUniform ~= false and not rasterCorners and (style.BorderStyle == "solid" or style.BorderStyle == "none") then
		if (style.BorderSize or 0) > 0 then
			-- A UIStroke on the box itself is painted below child GuiObjects. A border-box
			-- background therefore covered the border. Keep the cheap native path for
			-- ordinary boxes and raise only image-backed borders above their background.
			local host = gui
			local overlay = nil
			local corner = nil
			if hasBackgroundImage(style) then
				overlay = PaintLayer.create(factory,"Frame", gui, {Name = "BorderOverlay", BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 1})
				host = overlay
				if (style.BorderRadius or 0) > 0 then
					corner = factory.modifier("UICorner", overlay, {CornerRadius = UDim.new(0, style.BorderRadius)})
				end
			end
			local stroke = factory.modifier("UIStroke", host, {Thickness = style.BorderSize, Color = style.BorderColor,
				Transparency = 1 - (style.BorderColorAlpha or 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				LineJoinMode = if (style.BorderRadius or 0) > 0 or style.NativeCornerRadii then Enum.LineJoinMode.Round else Enum.LineJoinMode.Miter})
			nativeStrokes[gui] = stroke
			if overlay then return {Overlay = overlay, Stroke = stroke, Corner = corner} end
			if style.BorderImageSource then return {NativeImageBorder=true,Stroke=stroke}end
		end
		return nil
	end
	local edges: any = {Factory = factory, Pools = {}, Host = gui, CornerRenderer = corners}
	for index, side in SIDES do
		local color, alpha, kind = Paint.edge(style, side)
		edges[index] = factory.create("Frame", gui, {Name = "InsetBorder_" .. index,
			BackgroundTransparency = if Paint.patterned(kind) then 1 else 1 - alpha, BackgroundColor3 = color})
	end
	return edges
end
function BorderBox.arrange(edges: any, style: any, width: number, height: number, gap: any?)
	if edges.NativeImageBorder then write(edges.Stroke,'Transparency',1-(style.BorderColorAlpha or 1));return end
	if edges.Overlay then
		write(edges.Overlay, "Position", UDim2.fromOffset(0, 0))
		write(edges.Overlay, "Size", UDim2.fromOffset(width, height))
		if edges.Corner then write(edges.Corner, "CornerRadius", UDim.new(0, style.BorderRadius or 0)) end
		return
	end
	if edges.FieldsetRegions then
		local t = Geometry.sizes(style)
		local top = if gap then math.min(height, gap.Top) else 0
		local left = if gap then math.clamp(gap.Left, 0, width) else width
		local right = if gap then math.clamp(gap.Right, left, width) else width
		local below = math.min(height, top + t)
		local rectangles = {{0, 0, left, height}, {right, 0, width-right, height}, {left, below, right-left, height-below}}
		for index, rect in rectangles do
			local region = edges.FieldsetRegions[index]
			local visible = rect[3] > 0 and rect[4] > 0
			write(region.Clip, "Visible", visible)
			if not visible then continue end
			write(region.Clip, "Position", UDim2.fromOffset(rect[1], rect[2]))
			write(region.Clip, "Size", UDim2.fromOffset(rect[3], rect[4]))
			write(region.Host, "Position", UDim2.fromOffset(-rect[1], top-rect[2]))
			write(region.Host, "Size", UDim2.fromOffset(width, height-top))
			BorderBox.arrange(region.Edges, style, width, height-top)
		end
		return
	end
	local radii=style.ResolvedBorderRadii
	local corners = if radii then false else edges.CornerRenderer and edges.CornerRenderer:Draw(edges, style, width, height) or false
	local t, r, b, l = Geometry.sizes(style)
	local rectangles = Geometry.rectangles(style, width, height)
	if radii and style.RasterBorderOverlay then
		for index=1,4 do
			write(edges[index],"Visible",false)
			for _,segment in edges.Pools[index] or {} do write(segment,"Visible",false) end
		end
		return
	end
	if radii then
		rectangles[1]={radii[1][1],0,math.max(0,width-radii[1][1]-radii[2][1]),t}
		rectangles[2]={width-r,radii[2][2],r,math.max(0,height-radii[2][2]-radii[3][2])}
		rectangles[3]={radii[4][1],height-b,math.max(0,width-radii[4][1]-radii[3][1]),b}
		rectangles[4]={0,radii[1][2],l,math.max(0,height-radii[1][2]-radii[4][2])}
	end
	if corners then rectangles[1] = {l, 0, width-l-r, t}; rectangles[3] = {l, height-b, width-l-r, b} end
	for index, rect in rectangles do
		local gui = edges[index]
		write(gui, "ClipsDescendants", corners)
		write(gui, "Position", UDim2.fromOffset(rect[1], rect[2]))
		write(gui, "Size", UDim2.fromOffset(rect[3], rect[4]))
		local entry = if style.BorderSides then style.BorderSides[SIDES[index]] else nil
		local kind = if entry then entry.Style else style.BorderStyle
		local color,alpha=Paint.edge(style,SIDES[index])
		write(gui,"BackgroundColor3",color)
		write(gui,"BackgroundTransparency",if Paint.patterned(kind) then 1 else 1-alpha)
		local pool = edges.Pools[index]
		if not Paint.patterned(kind) then
			if pool then for _,segment in ipairs(pool) do write(segment,"Visible",false) end end
			continue
		end
		if not pool then pool = {}; edges.Pools[index] = pool end
		local horizontal = index == 1 or index == 3
		local length, thickness = if horizontal then rect[3] else rect[4], if horizontal then rect[4] else rect[3]
		local offset = if corners then (if horizontal then l else t) else 0
		if corners then length = if horizontal then width else height end
		Pattern.draw(pool,edges.Factory,gui,kind,length,thickness,horizontal,offset,function(ordinal)
			return Paint.edge(style,SIDES[index],ordinal)
		end)
	end
end
-- Color changes reuse border geometry and its existing native/raster surfaces.
function BorderBox.repaint(edges: any?, style: any, gui: any, width: number, height: number, gap: any?)
	local stroke = nativeStrokes[gui] or (edges and edges.Stroke)
	if stroke then
		write(stroke, "Color", style.BorderColor)
		write(stroke, "Transparency", 1 - (style.BorderColorAlpha or 1))
		write(stroke, "Thickness", style.BorderSize or 0)
		write(stroke, "LineJoinMode", if (style.BorderRadius or 0)>0 or style.NativeCornerRadii then Enum.LineJoinMode.Round else Enum.LineJoinMode.Miter)
	end
	if edges then BorderBox.arrange(edges, style, width, height, gap) end
end

local function representation(style: any): string
	local t,r,b,l=Geometry.sizes(style)
	if style.Visibility=='hidden'or t<=0 and r<=0 and b<=0 and l<=0 then return 'none' end
	if style.Node and style.Node.Name=='fieldset'then return 'fieldset' end
	local raster=style.BorderRadii and (style.BorderRadius==0 or style.CornerShape~='round') and not style.NativeCornerRadii
	if style.BorderUniform~=false and not raster and (style.BorderStyle=='solid'or style.BorderStyle=='none')then
		return if hasBackgroundImage(style)then 'overlay'elseif style.BorderImageSource then 'image'else 'native'
	end
	return 'edges'
end
local function currentRepresentation(edges: any?,gui: any): string
	if edges then
		if edges.FieldsetRegions then return 'fieldset' end
		if edges.Overlay then return 'overlay' end
		if edges.NativeImageBorder then return 'image' end
		return 'edges'
	end
	return if nativeStrokes[gui]then 'native'else 'none'
end
local function destroy(gui: any?)
	if not gui then return end
	if gui.Destroy then gui:Destroy()else gui.Parent=nil end
end
local function release(edges: any?,gui: any)
	local stroke=nativeStrokes[gui];nativeStrokes[gui]=nil
	if edges and edges.FieldsetRegions then
		for _,region in edges.FieldsetRegions do release(region.Edges,region.Host);destroy(region.Clip)end
	elseif edges and edges.Overlay then
		destroy(edges.Overlay) -- owns its native stroke and corner modifier.
	elseif edges then
		if edges.CornerRenderer and edges.CornerRenderer.RemoveEdges then edges.CornerRenderer:RemoveEdges(edges)end
		for index=1,4 do destroy(edges[index])end
		destroy(stroke or edges.Stroke)
	else destroy(stroke)end
end

-- CSSOM/class/state changes can introduce a border after the box was mounted,
-- or change the representation between native strokes and patterned strips.
-- Reconcile only border-owned surfaces; the box and its controls stay retained.
function BorderBox.update(edges: any?,style: any,gui: any,width: number,height: number,factory: any,corners: any?,gap: any?): any?
	local wanted=representation(style)
	if wanted~=currentRepresentation(edges,gui)then
		release(edges,gui)
		edges=if wanted~='none'then BorderBox.create(style,gui,factory,corners)else nil
	end
	if wanted=='overlay'and edges and (style.BorderRadius or 0)>0 and not edges.Corner then
		edges.Corner=factory.modifier('UICorner',edges.Overlay,{CornerRadius=UDim.new(0,style.BorderRadius)})
	end
	BorderBox.repaint(edges,style,gui,width,height,gap)
	return edges
end
-- Controls keep their own cheap uniform stroke, but share the general border
-- renderer for individual/patterned sides. Release only these owned surfaces.
function BorderBox.remove(edges: any?,gui: any)release(edges,gui)end
return BorderBox
