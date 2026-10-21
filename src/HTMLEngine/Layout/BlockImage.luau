--!strict
-- A replaced element participates directly in block/flex sizing, without a text strut.
local ImageLayout = require(script.Parent.ImageLayout)
local ImageBox = require(script.Parent.Parent.Rendering.ImageBox)
local MediaBox = require(script.Parent.Parent.Rendering.MediaBox)
local IFrameBox = require(script.Parent.Parent.Rendering.IFrameBox)
local FontMetrics = require(script.Parent.FontMetrics)
local TextMeasure = require(script.Parent.TextMeasure)
local BoxSpacing = require(script.Parent.BoxSpacing)
local ControlView = require(script.Parent.Parent.Controls.View)
local BlockImage = {}
local ReplacedElement = require(script.Parent.Parent.Rendering.ReplacedElement)
local GroupOpacity = require(script.Parent.Parent.Rendering.GroupOpacity)
local QuirksLayout=require(script.Parent.QuirksLayout)

local function write(gui: any, key: string, value: any)
	if gui[key] ~= value then gui[key] = value end
end

function BlockImage.measure(box: any, available: number, alive: any, sizing: any?): (number, number)
	local item, s = box.ImageItem, box.Style
	BoxSpacing.resolve(s, available)
	box.ImageSizing = sizing
	ReplacedElement.refreshStyle(box, sizing)
	if item.FontResolver then item.FontFace=item.FontResolver(s.Font,s.FontWeight,s.FontStyle)end
	local metrics = if item.Control then ControlView.metrics(item) else FontMetrics.resolve(s)
	item.TextSize = metrics.TextSize
	if item.TextFallback and (item.AltWidth==nil or item.AltSize~=metrics.TextSize or item.AltMeasuredText~=item.Alt or item.AltMeasuredFace~=item.FontFace)then
		local bounds, message = TextMeasure.measure(item.Alt, item.FontFace, metrics.TextSize, 0)
		if not alive() then return 0, 0 end
		assert(bounds, "Block image alt measurement failed: " .. tostring(message))
		item.AltWidth,item.AltInkHeight,item.AltSize=bounds.X,bounds.Y,metrics.TextSize
		item.AltMeasuredText,item.AltMeasuredFace=item.Alt,item.FontFace
	end
	if item.TextFallback then local extents=FontMetrics.extents(s,metrics,item.AltInkHeight);item.AltHeight=extents.Ascent+extents.Descent end
	if item.Control and not ControlView.measure(item, TextMeasure.measure, alive) then return 0, 0 end
	-- Positioned/flex/grid layout supplies the current containing height. A
	-- previous normal-flow basis may be indefinite even after the parent has
	-- acquired its used height, e.g. an aspect-ratio card with an absolute button.
	local heightBasis=if sizing and sizing.HeightBasis~=nil then sizing.HeightBasis else box.HeightBasis
	ImageLayout.size(item, available,heightBasis,QuirksLayout.heightBasis(box,heightBasis))
	item.Width, item.Height = item.BoxWidth, item.BoxHeight
	return item.BoxWidth, item.BoxHeight
end

function BlockImage.arrange(box: any, available: number, x: number, y: number, alive: any, sizing: any?): (number, number, number)
	local width, height = BlockImage.measure(box, available, alive, sizing)
	if not alive() then return 0, 0, 0 end
	local item, s = box.ImageItem, box.Style
	if item.Control then write(box.Gui, "Visible", s.Visibility ~= "hidden") end
	local m = s.Margin
	local offset = 0
	if not (sizing and sizing.FlexItem) and s.MarginAuto[4] then
		offset = math.max(0, available - width - m[2] - m[4]) / (if s.MarginAuto[2] then 2 else 1)
	end
	box.LayoutX, box.LayoutY = x + m[4] + offset, y + m[1]
	box.PaintX, box.PaintY = box.LayoutX, box.LayoutY
	if not box.LayoutProbe then write(box.Gui, "Position", UDim2.fromOffset(box.LayoutX, box.LayoutY)) end
	write(box.Gui, "Size", UDim2.fromOffset(width, height))
	if item.Gui~=box.Gui then write(item.Gui, "Position", UDim2.fromOffset(0, 0))end
	write(item.Gui, "Size", UDim2.fromOffset(width, height))
	if not box.GeometryOnly then
		if item.Control then ControlView.arrange(item) elseif item.MediaKind then MediaBox.arrange(item) elseif item.IFrame then IFrameBox.arrange(item) else ImageBox.arrange(item) end
	end
	-- Block layout already positions the outer box after its margins. Keep the
	-- native checkbox/radio face centered in its possibly wider CSS layout box.
	local nativeToggle=item.Control and (item.Control.Type=="checkbox" or item.Control.Type=="radio") and s.Appearance~="none"
	local faceSize=math.max(0,math.min(item.BoxWidth,item.BoxHeight))
	write(item.BoxGui,"Position",if nativeToggle then UDim2.fromOffset((item.BoxWidth-faceSize)/2,(item.BoxHeight-faceSize)/2)
		else UDim2.fromOffset(0,0))
	if not box.GeometryOnly and item.OpacityGroup then GroupOpacity.image(item) end
	if item.AltGui then write(item.AltGui, "TextSize", item.TextSize) end
	box.OuterWidth, box.OuterHeight = width, height
	box.ContentWidth, box.ContentHeight = item.ContentWidth, item.ContentHeight
	box.LocalRight, box.LocalBottom, box.OwnBottom = width, height, height
	box.UnclippedRight, box.UnclippedBottom = width, height
	box.FirstBaseline = height
	box.DefiniteHeight = s.Height ~= nil and s.Height.Intrinsic == nil
	return height + m[1] + m[3], width + m[2] + m[4] + offset, m[1] + math.max(height, height + m[3])
end

return BlockImage
