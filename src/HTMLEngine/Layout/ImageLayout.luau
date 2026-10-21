--!strict
local BorderGeometry = require(script.Parent.BorderGeometry)
-- CSS/HTML dimensions win; automatic axes use loaded metadata, then attributes/defaults.
local ImageLayout = {}
local SVGSizing = require(script.Parent.Parent.SVG.Sizing)
local BoxSpacing = require(script.Parent.BoxSpacing)
local FontMetrics = require(script.Parent.FontMetrics)
local AspectRatio = require(script.Parent.AspectRatio)
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)
local ViewBox=require(script.Parent.Parent.CSS.ObjectViewBox)
local ImageFallback=require(script.Parent.Parent.Rendering.ImageFallback)

local function pixels(value: any, width: number): number?
	return if value then LengthExpression.resolve(value,width) else nil
end

function ImageLayout.size(item: any, available: number, heightBasis: number?,quirkyHeightBasis: number?): (number, number)
	local style = item.Style
	BoxSpacing.resolve(style, available)
	local padding, margin = style.Padding, style.Margin
	local bt, br, bb, bl = BorderGeometry.sizes(style)
	local horizontal = br + bl + padding[2] + padding[4]
	local vertical = bt + bb + padding[1] + padding[3]
	local function content(value: any, edges: number, verticalAxis: boolean?): number?
		if value and value.Intrinsic then return nil end
		local basis=if verticalAxis then heightBasis or quirkyHeightBasis else available
		if verticalAxis and value and value.Percent and basis == nil then return nil end
		local resolved = pixels(value,basis or 0)
		return if resolved then math.max(0, resolved - (if style.BoxSizing == "border-box" then edges else 0)) else nil
	end
	item.InlineFallback=item.TextFallback==true and not item.Block and style.Display~="inline-block"
	if item.InlineFallback then
		-- Chromium's inline alt replacement ignores width/height/ratio but
		-- still applies its min/max constraints, padding, border and margins.
		item.ContentWidth=math.max(content(style.MinWidth,horizontal)or 0,math.min(content(style.MaxWidth,horizontal)or math.huge,(item.AltWidth or 0)+ImageFallback.IconSize))
		item.ContentHeight=math.max(content(style.MinHeight,vertical,true)or 0,math.min(content(style.MaxHeight,vertical,true)or math.huge,item.AltHeight or 0))
		item.BoxWidth,item.BoxHeight=item.ContentWidth+horizontal,item.ContentHeight+vertical
		return item.BoxWidth+margin[2]+margin[4],item.BoxHeight+margin[1]+margin[3]
	end
	local width, height = content(style.Width, horizontal), content(style.Height, vertical,true)
	-- Controls share this box-sizing path but have no natural image aspect ratio.
	local naturalRatio = if item.Control and item.Control.Type~="image" then nil
		elseif not style.AutoImageSize and not item.TextFallback and item.IntrinsicWidth and item.IntrinsicHeight and item.IntrinsicWidth>0 and item.IntrinsicHeight>0 then item.IntrinsicWidth / item.IntrinsicHeight
		elseif style.AspectRatio and style.AspectRatio.Auto then nil
		elseif item.AttributeWidth and item.AttributeHeight and item.AttributeWidth > 0 and item.AttributeHeight > 0
		then item.AttributeWidth / item.AttributeHeight else nil
	local svgWidth,svgHeight
	if item.SVG and not item.SVGExternal then svgWidth,svgHeight,naturalRatio=SVGSizing.natural(item,available,horizontal,vertical) end
	local naturalWidth, naturalHeight = svgWidth or item.IntrinsicWidth or item.AttributeWidth or 300, svgHeight or item.IntrinsicHeight or item.AttributeHeight or 150
	if style.AutoImageSize then
		naturalWidth=pixels(style.ContainIntrinsicWidth,available)or 0
		naturalHeight=pixels(style.ContainIntrinsicHeight,heightBasis or quirkyHeightBasis or 0)or 0
	end
	if ImageFallback.broken(item)then
		naturalWidth=if item.TextFallback then (item.AltWidth or 0)+ImageFallback.IconSize elseif item.EmptyAlt then 0 else ImageFallback.IconSize
		naturalHeight=if item.TextFallback then item.AltHeight or 0 elseif item.EmptyAlt then 0 else ImageFallback.IconSize
		if item.TextFallback and width==nil and item.Block then width=math.max(0,available-horizontal-margin[2]-margin[4])end
	end
	if style.ObjectViewBox and not item.Control and not style.AutoImageSize then
		local _,_,croppedWidth,croppedHeight=ViewBox.rectangle(style.ObjectViewBox,naturalWidth,naturalHeight)
		naturalWidth,naturalHeight=croppedWidth,croppedHeight
		naturalRatio=if croppedHeight>0 and croppedWidth>0 then croppedWidth/croppedHeight else nil
	end
	local ratio, ratioBorderBox = AspectRatio.resolve(style, naturalRatio)
	local ratioWidthEdges, ratioHeightEdges = if ratioBorderBox then horizontal else 0, if ratioBorderBox then vertical else 0
	if width == nil and height == nil then
		width, height = naturalWidth, naturalHeight
		if style.AspectRatio and ratio then height = AspectRatio.height(width, ratio, ratioWidthEdges, ratioHeightEdges) end
	elseif width == nil then width = if ratio then AspectRatio.width(height, ratio, ratioWidthEdges, ratioHeightEdges) else naturalWidth
	elseif height == nil then height = if ratio then AspectRatio.height(width, ratio, ratioWidthEdges, ratioHeightEdges) else naturalHeight end
	local minWidth, maxWidth = content(style.MinWidth, horizontal) or 0, content(style.MaxWidth, horizontal) or math.huge
	local minHeight, maxHeight = content(style.MinHeight, vertical,true) or 0, content(style.MaxHeight, vertical,true) or math.huge
	-- Replaced intrinsic limits ignore the preferred size on their own axis.
	-- Their natural dimension follows the constrained opposite dimension and
	-- its preferred ratio; ordinary controls retain their measured widget size.
	local intrinsicWidth=if ratio then AspectRatio.width(math.max(minHeight,math.min(maxHeight,
		content(style.Height,vertical,true)or naturalHeight)),ratio,ratioWidthEdges,ratioHeightEdges)else naturalWidth
	local intrinsicHeight=if ratio then AspectRatio.height(math.max(minWidth,math.min(maxWidth,
		content(style.Width,horizontal)or naturalWidth)),ratio,ratioWidthEdges,ratioHeightEdges)else naturalHeight
	if style.MinWidth and style.MinWidth.Intrinsic then minWidth=intrinsicWidth end
	if style.MaxWidth and style.MaxWidth.Intrinsic then maxWidth=intrinsicWidth end
	if style.MinHeight and style.MinHeight.Intrinsic then minHeight=intrinsicHeight end
	if style.MaxHeight and style.MaxHeight.Intrinsic then maxHeight=intrinsicHeight end
	-- One automatic axis follows the preferred ratio when the specified axis is constrained.
	local automaticWidth=style.Width==nil or style.Width.Intrinsic~=nil
	local automaticHeight=style.Height==nil or style.Height.Intrinsic~=nil
	if automaticWidth and automaticHeight and ratio then
		local rw, rh = width + ratioWidthEdges, height + ratioHeightEdges
		local lower = if rw > 0 and rh > 0 then math.max((minWidth + ratioWidthEdges) / rw, (minHeight + ratioHeightEdges) / rh) else 0
		local upper = if rw > 0 and rh > 0 then math.min((maxWidth + ratioWidthEdges) / rw, (maxHeight + ratioHeightEdges) / rh) else 0
		if lower <= upper and rw > 0 and rh > 0 then
			local scale = math.max(lower, math.min(upper, 1))
			width, height = math.max(0, rw * scale - ratioWidthEdges), math.max(0, rh * scale - ratioHeightEdges)
		end
	elseif automaticHeight and not automaticWidth and ratio then
		width = math.max(minWidth, math.min(maxWidth, width))
		height = AspectRatio.height(width, ratio, ratioWidthEdges, ratioHeightEdges)
	elseif automaticWidth and not automaticHeight and ratio then
		height = math.max(minHeight, math.min(maxHeight, height))
		width = AspectRatio.width(height, ratio, ratioWidthEdges, ratioHeightEdges)
	end
	item.ContentWidth, item.ContentHeight = math.max(minWidth, math.min(maxWidth, width)), math.max(minHeight, math.min(maxHeight, height))
	item.BoxWidth, item.BoxHeight = item.ContentWidth + horizontal, item.ContentHeight + vertical
	return item.BoxWidth + margin[2] + margin[4], item.BoxHeight + margin[1] + margin[3]
end

function ImageLayout.align(item: any, parentMetrics: any, metrics: any, atomicBaseline: number?)
	local style, height = item.Style, item.Height
	local align = style.VerticalAlign
	local parentShift = (item.ParentStyle or {}).InlineShift or 0
	local shift = style.InlineShift or 0
	local baseline = atomicBaseline or (if item.InlineFallback then metrics.Baseline+style.Padding[1]+select(1,BorderGeometry.sizes(style))+style.Margin[1] else height)
	item.LineAlign = nil
	if align == "middle" then shift = parentShift + baseline - height / 2 - (parentMetrics.Baseline - parentMetrics.XHeight) / 2
	elseif align == "text-top" then shift = parentShift + baseline - parentMetrics.Baseline
	elseif align == "text-bottom" then shift = parentShift + baseline + parentMetrics.TextSize - parentMetrics.Baseline - height
	elseif align == "top" or align == "bottom" then item.LineAlign, shift = align, 0
	elseif type(align) == "table" then
		local extents = FontMetrics.extents(style, metrics)
		shift = parentShift - LengthExpression.resolve(align,extents.Ascent + extents.Descent)
	end
	item.BaselineShift = shift
	local extents = {Ascent=baseline,Descent=height-baseline}
	item.Baseline, item.Ascent, item.Descent = baseline, extents.Ascent - shift, extents.Descent + shift
end

return ImageLayout
