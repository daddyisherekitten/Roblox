--!strict
-- CanvasGroups compose overlapping descendants once. Their viewport includes
-- painted overflow; the content origin stays in the original layout coordinates.
local GroupOpacity = {}
local DirtyLayout = require(script.Parent.Parent.Layout.DirtyLayout)
local Filter = require(script.Parent.Parent.CSS.Filter)
local BorderShapes=require(script.Parent.BorderShapePixels)
local MaskGradient = require(script.Parent.MaskGradient)
local OutlineBox = require(script.Parent.OutlineBox)
local TextEmphasis=require(script.Parent.Parent.Layout.TextEmphasis)

local function write(gui: any, key: string, value: any)
	if gui[key] ~= value then gui[key] = value end
end

function GroupOpacity.untrack(item: any)
	local group = item.Style and item.Style.OpacityGroup
	if not group then return end
	local index = table.find(group.Members, item)
	if index then table.remove(group.Members, index) end
end

function GroupOpacity.create(parent: any, opacity: number, factory: any): any
	local gui = factory.create("CanvasGroup", parent, {Name = "Opacity", GroupTransparency = 1 - opacity, ClipsDescendants = true})
	local content = factory.create("Frame", gui, {Name = "OpacityContent"})
	-- These are compositing shells, not DOM boxes. Their native hit rectangles
	-- must not replace a child's pointer-events rule with the DOM parent's rule.
	-- Mark only the shells: interactive descendants still receive their hits.
	for _, shell in {gui, content} do
		if shell.SetAttribute then shell:SetAttribute("HTMLHitTestPassthrough", true) end
	end
	return {Gui = gui, Content = content, Members = {}, Children = {}}
end

function GroupOpacity.paint(group: any,style: any,opacity: number?)
 group.SampledOpacity=if opacity~=nil then math.clamp(opacity,0,1)else nil
 local brightness,alpha=Filter.native(if style.Node and style.Node.Name=='img' then nil else style.Filter)
 write(group.Gui,'GroupColor3',Color3.new(brightness or 1,brightness or 1,brightness or 1))
 write(group.Gui,'GroupTransparency',1-(if opacity~=nil then group.SampledOpacity else style.Opacity or 1)*(alpha or 1))
end

function GroupOpacity.opacity(group: any,style: any): number
 local _,alpha=Filter.native(if style.Node and style.Node.Name=='img' then nil else style.Filter)
 return if (alpha or 1)>0 then (1-group.Gui.GroupTransparency)/(alpha or 1) else style.Opacity or 1
end

local function union(a: any, b: any, x: number?, y: number?)
	x, y = x or 0, y or 0
	a[1], a[2], a[3], a[4] = math.min(a[1], x + b[1]), math.min(a[2], y + b[2]), math.max(a[3], x + b[3]), math.max(a[4], y + b[4])
end

local function extras(rect: any, style: any, text: boolean?)
	local original = table.clone(rect)
	if not text and style.BorderShape then
		local g=BorderShapes.geometry(style,original[3]-original[1],original[4]-original[2])
		union(rect,{original[1]+g.Left,original[2]+g.Top,original[1]+g.Left+g.Width,original[2]+g.Top+g.Height})
	end
	if not text and style.Filter and style.Filter.HasRaster then
		local pad=style.Filter.Outset
		union(rect,{original[1]-pad,original[2]-pad,original[3]+pad,original[4]+pad})
	end
	for _, shadow in (if text then style.TextShadows else style.BoxShadows) or {} do
		if shadow.Inset then continue end
		local grow = (shadow.Spread or 0) + (shadow.Blur or 0) * 2
		union(rect, {original[1] - grow + shadow.X, original[2] - grow + shadow.Y, original[3] + grow + shadow.X, original[4] + grow + shadow.Y})
	end
	if not text and style.OutlineStyle and style.OutlineStyle ~= "none" then
		local grow = OutlineBox.outset(style)
		union(rect, {original[1] - grow, original[2] - grow, original[3] + grow, original[4] + grow})
	end
	if text then
		for _, line in style.Decorations or {} do
			local grow = (line.Thickness or 1) * 3 + math.abs(line.UnderlineOffset or 0)
			union(rect, {original[1], original[2] - grow, original[3], original[4] + grow})
		end
	end
end

local function component(value: any, axis: number): number
	local part = if axis == 1 then value.X else value.Y
	return if part then part.Offset else value[axis]
end

local function fit(group: any, bounds: any, x: number?, y: number?)
	local left, top = math.floor(bounds[1]), math.floor(bounds[2])
	local width, height = math.max(1, math.ceil(bounds[3]) - left), math.max(1, math.ceil(bounds[4]) - top)
	write(group.Gui, "Position", UDim2.fromOffset((x or 0) + left, (y or 0) + top))
	write(group.Gui, "Size", UDim2.fromOffset(width, height))
	write(group.Content, "Position", UDim2.fromOffset(-left, -top))
	write(group.Content, "Size", UDim2.fromOffset(width, height))
end

local function inlineGroup(group: any, alive: (() -> boolean)?): any
	local bounds = {0, 0, 0, 0}
	for _, item in group.Members do
		if alive and not alive() then return bounds end
		if item.Gui.Visible == false or not item.Gui.Size or not item.Gui.Position then continue end
		local x, y = component(item.Gui.Position, 1), component(item.Gui.Position, 2)
		local rect = {x, y, x + component(item.Gui.Size, 1), y + component(item.Gui.Size, 2)}
		extras(rect, item.Style, item.Kind ~= "Image")
		local emphasis=TextEmphasis.bounds(item);if emphasis then union(rect,emphasis)end
		union(bounds, rect)
	end
	for _, child in group.Children do union(bounds, inlineGroup(child,alive)) end
	fit(group, bounds)
	return bounds
end

function GroupOpacity.image(item: any)
	local x, y = component(item.BoxGui.Position, 1), component(item.BoxGui.Position, 2)
	local bounds = {x, y, x + item.BoxWidth, y + item.BoxHeight}
	extras(bounds, item.Style)
	fit(item.OpacityGroup, bounds)
end

function GroupOpacity.arrange(box: any, alive: (() -> boolean)?, paintChanged: any?): any
	if alive and not alive() then return {0,0,0,0} end
	if box.CanvasPaintGui then
		local composed=box.OpacityGroup~=nil
		write(box.CanvasPaintGui,'Parent',if composed then box.OpacityGroup.Content else box.CanvasViewport)
		write(box.CanvasPaintGui,'Position',UDim2.fromOffset(if composed then -(box.LayoutX or 0)else 0,if composed then -(box.LayoutY or 0)else 0))
	end
	-- Outline changes need new compositing bounds without a layout pass. Keep
	-- all untouched branches cached, including their nested opacity groups.
	if paintChanged and not paintChanged[box] and box.OpacityBounds then return box.OpacityBounds end
	if not (paintChanged and paintChanged[box]) and DirtyLayout.wasReused(box) and box.OpacityBounds then
		-- Position painting may have written the group's ordinary flow position.
		if box.OpacityGroup then write(box.Gui, "Position", UDim2.fromOffset(0, 0)) end
		box.DirtyContext.Stats.OpacityReused += 1
		return box.OpacityBounds
	end
	local bounds = {0, 0, box.OuterWidth or box.LocalRight or 0, box.OuterHeight or box.LocalBottom or 0}
	-- The canvas is paint overflow owned by the root compositor, not layout or
	-- hit-test geometry. Include it even when the root's own box clips contents.
	if box.CanvasPaintBounds then union(bounds,box.CanvasPaintBounds)end
	local clipped=box.Style.Overflow == "hidden" or box.TableContentClipped
	for _, child in box.Children or {} do
		if child.CollapsedByTable or child.Style.Hidden then continue end
		local rect = GroupOpacity.arrange(child,alive,paintChanged)
		local surfaceOffset=if child.Style.TableRole == "caption" then 0 else box.CaptionTop or 0
		if not clipped then union(bounds, rect, child.PaintX or child.LayoutX or 0, (child.PaintY or child.LayoutY or 0)+surfaceOffset) end
	end
	if box.Kind == "Words" then
		for _, item in box.DisplayItems or box.Items do
			if alive and not alive() then return bounds end
			if item.Kind == "Break" then continue end
			-- Some diagnostic-only layout branches (for example table cells
			-- without a supported row wrapper) retain their DOM/text but have no
			-- painted geometry. They cannot contribute to a compositing viewport.
			if item.X == nil or item.Y == nil or item.Width == nil or item.Height == nil then continue end
			local rect = if item.PaintRect then table.clone(item.PaintRect) else {item.X, item.Y, item.X + item.Width, item.Y + item.Height}
			extras(rect, item.Style, item.Kind ~= "Image")
			local emphasis=TextEmphasis.bounds(item,box.LayoutX,box.LayoutY);if emphasis then union(rect,emphasis)end
			union(bounds, rect)
		end
	end
	for _, group in box.InlineOpacityGroups or {} do
		local rect=inlineGroup(group,alive)
		if not clipped then union(bounds,rect) end
	end
	extras(bounds, box.Style)
	if box.OpacityGroup then
		box.MaskDefinition=box.Style.MaskImage or box.Style.MaskBorderSource
		if box.OpacityGroup.Mask then box.OpacityGroup.Mask.Enabled=box.MaskDefinition~=nil and box.MaskDefinition.Kind=='linear'end
		if not box.MaskDefinition and box.VisualEffects then box.VisualEffects:ClearMask(box)end
		-- Positioned layout keeps the measured flow origin separate from its
		-- final paint position. Fit the compositor where the positioned surface
		-- was placed; its inner GUI is normalized to zero immediately below.
		fit(box.OpacityGroup, bounds, box.TopLayerPaintX or box.PaintX or box.LayoutX, box.TopLayerPaintY or box.PaintY or box.LayoutY)
		write(box.Gui, "Position", UDim2.fromOffset(0, 0))
		write(box.OpacityGroup.Gui, "ZIndex", box.Gui.ZIndex)
		MaskGradient.clip(box,bounds)
		if box.MaskDefinition and box.MaskDefinition.Kind=="layers" and box.VisualEffects then box.VisualEffects:DrawMask(box) end
	end
	box.OpacityBounds = bounds
	return bounds
end

return GroupOpacity
