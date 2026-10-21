--!strict
-- Shared retained styling for replaced elements, independent of measurement.
local ImageBox = require(script.Parent.ImageBox)
local MediaBox = require(script.Parent.MediaBox)
local IFrameBox = require(script.Parent.IFrameBox)
local ControlView = require(script.Parent.Parent.Controls.View)
local BorderGeometry = require(script.Parent.Parent.Layout.BorderGeometry)
local ReplacedElement = {}

function ReplacedElement.refreshStyle(box: any, sizing: any?)
	local item, s = box.ImageItem, box.Style
	local inner = box.ImageStyle
	if not inner then
		inner = {}
		box.ImageStyle = inner
	end
	-- Keep the derived style's identity for paint caches, but refresh every CSS
	-- property: focus/hover can change outlines and colors without replacing it.
	local innerMargin=inner.Margin or {0,0,0,0}
	table.clear(inner)
	for key,value in s do inner[key]=value end
	for side=1,4 do innerMargin[side]=0 end
	inner.Margin,inner.MarginValues,inner.MarginAuto=innerMargin,nil,nil
	local bt, br, bb, bl = BorderGeometry.sizes(s)
	local horizontal, vertical = s.Padding[2] + s.Padding[4] + br + bl, s.Padding[1] + s.Padding[3] + bt + bb
	if sizing then
		local width = if sizing.MainAxis == "row" then sizing.MainSize else sizing.ContentWidth
		local height = if sizing.MainAxis == "column" then sizing.MainSize else sizing.ContentHeight
		if width ~= nil then inner.Width = {Value = width + (if s.BoxSizing == "border-box" then horizontal else 0), Percent = false} end
		if height ~= nil then inner.Height = {Value = height + (if s.BoxSizing == "border-box" then vertical else 0), Percent = false} end
		if sizing.IgnoreMainLimits then
			if sizing.MainAxis == "row" then inner.MinWidth, inner.MaxWidth = nil, nil else inner.MinHeight, inner.MaxHeight = nil, nil end
		end
	end
	item.Style = inner
	return inner
end

-- Repaint retained geometry without another text measurement or intrinsic probe.
function ReplacedElement.paint(box: any)
	ReplacedElement.refreshStyle(box, box.ImageSizing)
	local item = box.ImageItem
	if not item.BoxWidth or not item.BoxHeight then return end
	if item.Control then ControlView.paint(item)
	elseif item.MediaKind then MediaBox.arrange(item)
	elseif item.IFrame then IFrameBox.arrange(item)
	else ImageBox.arrange(item) end
	if not item.Control then
		item.BoxGui.BackgroundColor3 = box.Style.Background or Color3.new(1, 1, 1)
		item.BoxGui.BackgroundTransparency = if box.Style.Background then 1 - (box.Style.BackgroundAlpha or 1) else 1
	end
end

return ReplacedElement
