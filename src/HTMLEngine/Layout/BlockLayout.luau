--!strict
local BorderGeometry = require(script.Parent.BorderGeometry)
local BoxTransform = require(script.Parent.Parent.Rendering.BoxTransform)
local BorderBox = require(script.Parent.Parent.Rendering.BorderBox)
local CornerRadii = require(script.Parent.Parent.Rendering.CornerRadii)
local OutlineBox = require(script.Parent.Parent.Rendering.OutlineBox)
local WordLayout = require(script.Parent.WordLayout)
local ListMarker = require(script.Parent.ListMarker)
local FontMetrics = require(script.Parent.FontMetrics)
local AspectRatio = require(script.Parent.AspectRatio)
local FlexLayout = require(script.Parent.FlexLayout)
local PositionedLayout = require(script.Parent.PositionedLayout)
local ScrollLayout = require(script.Parent.ScrollLayout)
local BlockLayout = {}
local GridLayout = require(script.Parent.GridLayout)
local GroupOpacity = require(script.Parent.Parent.Rendering.GroupOpacity)
local CanvasBackground=require(script.Parent.Parent.Rendering.CanvasBackground)
local MaskGradient = require(script.Parent.Parent.Rendering.MaskGradient)
local BoxSpacing = require(script.Parent.BoxSpacing)
local BlockImage = require(script.Parent.BlockImage)
local DirtyLayout = require(script.Parent.DirtyLayout)
local FieldsetLayout = require(script.Parent.FieldsetLayout)
local LengthExpression = require(script.Parent.Parent.CSS.LengthExpression)
local TableLayout = require(script.Parent.TableLayout)
local function isFlex(style: any): boolean return style.Display=="flex" or style.Display=="inline-flex" end
local TableCaptions = require(script.Parent.TableCaptions)
local FloatLayout = require(script.Parent.FloatLayout)
local ColumnLayout = require(script.Parent.ColumnLayout)
local LayoutProbe = require(script.Parent.LayoutProbe)
local LayoutMeasurement=require(script.Parent.LayoutMeasurement)
local bindInline
local QuirksLayout = require(script.Parent.QuirksLayout)
local WritingMode=require(script.Parent.Parent.CSS.WritingMode)

local function write(gui: GuiObject, key: string, value: any)
	if (gui :: any)[key] ~= value then (gui :: any)[key] = value end
end

local function contentSize(value: any, available: number, edges: number): number
	return math.max(0, LengthExpression.resolve(value,available) - edges)
end

local function intrinsicSize(range: any,keyword: string,available: number): number
	return if keyword=='min-content'then range.Min elseif keyword=='max-content'then range.Max
		else math.max(range.Min,math.min(range.Max,available))
end
local intrinsicWidthRange
local intrinsicScrollbarWidth

-- Resolve list/entry/quote edge margins before positioning siblings. Paragraph margins
-- inside an entry must not add a second gap at the list's outside edge.
local MarginTrim=require(script.Parent.MarginTrim)
local function prepareMargins(box: any, flexItem: boolean?, alive: (() -> boolean)?)
	if alive and not alive() then return end
	if box.Kind == "Words" then
		box.HasPositioning, box.HasAnchors,box.HasFloats = false, false,false
		for _, child in box.Children or {} do
			prepareMargins(child,nil,alive)
			box.HasPositioning = box.HasPositioning or child.HasPositioning
			box.HasAnchors = box.HasAnchors or child.HasAnchors
		end
		return
	end
	for _, child in box.Children do child.TrimmedMargins=nil;prepareMargins(child, (isFlex(box.Style) or GridLayout.is(box.Style)),alive) end
	if box.Node and box.Node.Name == "fieldset" then
		box.Legend = nil
		for _, child in box.Children do
			if child.Node and child.Node.Parent == box.Node and child.Node.Name == "legend" and not child.Style.Hidden
				and child.Style.Position ~= "absolute" and child.Style.Position ~= "fixed" then box.Legend = child; break end
		end
	end
	local style = box.Style
	box.HasFloats=false
	for _,child in box.Children do
		if child.Style.Hidden or child.TopLayerHidden or child.LayoutAsTopLayer then continue end
		if child.HasFloats or (child.Kind~='Words'and child.Style.Float and child.Style.Float~='none')then box.HasFloats=true;break end
	end
	local bt, _, bb = BorderGeometry.sizes(style)
	box.HasPositioning = box.LayoutAsTopLayer==true or (style.Position ~= nil and style.Position ~= "static") or style.ZIndex ~= nil
	box.HasAnchors = style.AnchorNames ~= nil and #style.AnchorNames > 0
	local flow = nil
	for index, child in box.Children do
		if child == box.Legend or child.Style.Hidden or child.TopLayerHidden or child.LayoutAsTopLayer or (child.Kind ~= "Words" and (child.Style.Position == "absolute" or child.Style.Position=="fixed")) then
			if not flow then
				flow = {}
				for previous = 1, index - 1 do table.insert(flow, box.Children[previous]) end
			end
		elseif flow then table.insert(flow, child) end
	end
	local positionedChildren = nil
	for index, child in box.Children do
		if child.HasPositioning then box.HasPositioning = true end
		if child.HasAnchors then box.HasAnchors = true end
		if child.Kind == "Words" and #(child.Children or {}) > 0 then
			-- Atomic inline GUI coordinates are relative to this box, not to the
			-- anonymous word run. Include them in the same positioning traversal.
			if not positionedChildren then
				positionedChildren = {}
				for previous = 1, index - 1 do table.insert(positionedChildren, box.Children[previous]) end
			end
			for _, inlineBox in child.Children do table.insert(positionedChildren, inlineBox) end
		elseif positionedChildren then table.insert(positionedChildren, child) end
		if child.Kind ~= "Words" and child.Style.BorderImageSource then
			for _,outset in child.Style.BorderImageOutset or {} do
				if outset>0 then
					-- Outset can overlap siblings, so this parent needs explicit paint
					-- ranking even without any CSS-positioned descendants.
					box.HasPositioning=true
					break
				end
			end
		end
	end
	box.PositioningChildren = positionedChildren or box.Children
	box.FlowChildren = flow or box.Children
	box.LayoutMargin, box.CollapseTop, box.CollapseBottom = style.Margin, false, false
	MarginTrim.apply(box);MarginTrim.restore(box)
	-- The document element's margins never collapse with its descendants.
	if box.Node.Name=='html'and box.Node.Parent and box.Node.Parent.Kind=='Document'then return end
	if flexItem or isFlex(style) or GridLayout.is(style) or ColumnLayout.is(style) or style.Position == "absolute" or style.Position=="fixed" then return end
	local contain=style.Contain or {}
	if style.Display~="block" or style.Overflow~="visible" or style.Float~="none" or contain.Layout or contain.Paint then return end
	local first,last=nil,nil
	for _,child in box.FlowChildren do
		if child.Kind=="Words" or child.Style.Float=="none" then
			if not first then first=child end
			last=child
		end
	end
	local collapseTop=first and first.Kind ~= "Words" and bt == 0 and style.Padding[1] == 0
	local collapseBottom=last and last.Kind ~= "Words" and bb == 0 and style.Padding[3] == 0
		and (not style.Height or style.Height.Intrinsic and not WritingMode.vertical(style))
		and not style.AspectRatio and (not style.MinHeight or style.MinHeight.Intrinsic and not WritingMode.vertical(style)
			or not style.MinHeight.Intrinsic and LengthExpression.resolve(style.MinHeight,0) == 0)
	if not collapseTop and not collapseBottom then return end
	local margin = table.clone(style.Margin)
	if collapseTop then
		margin[1], box.CollapseTop = BoxSpacing.collapse(margin[1], first.LayoutMargin[1]), true
	end
	if collapseBottom then
		margin[3], box.CollapseBottom = BoxSpacing.collapse(margin[3], last.LayoutMargin[3]), true
	end
	box.LayoutMargin = margin
	MarginTrim.restore(box)
end

local function naturalWords(box: any,available: number,alive: () -> boolean,minimum: boolean?,heightBasis: number?,legacy: any?,axis: string?): (number,number)
	if not box.GeometryOnly then
		local context=LayoutMeasurement.new(box,alive)
		if context.Aborted or not alive()then return 0,0 end
		bindInline(context.Root,alive)
		local height,width=naturalWords(context.Root,available,alive,minimum,heightBasis,legacy,axis)
		context:KeepMeasurements()
		return height,width
	end
	local probe = table.clone(box)
	probe.HeightBasis=if axis=="height"and WritingMode.vertical(box.Style)then(if minimum then 0 else 100000)else heightBasis
	if legacy then probe.QuirksMode,probe.QuirksHeightBasis=legacy.Mode,legacy.Height end
	probe.Style = table.clone(box.Style)
	probe.Style.TextAlign, probe.Style.TextAlignLast = "left", "left"
	probe.IntrinsicIndent=true
	-- break-word does not reduce min-content; probes must never allocate fragments.
	probe.CreateWord = nil
	probe.MeasureOnly = true
	local container=box.LayoutParent
	probe.QuirksNoImageWrap=minimum==true and probe.QuirksMode==true and container~=nil
		and container.Style.TableRole=='cell'and container.Style.Width==nil
	-- Every item, linked atomic box and inline decoration belongs to the
	-- measurement graph. Wrapping can mutate that graph without publishing
	-- synthetic coordinates or resolved padding into the retained line.
	local height,width=WordLayout.arrange(probe,if axis=="height"then available elseif minimum then 0 else 100000,0,0,alive)
	return height,width
end

-- The physical height is the inline axis for vertical/sideways direct text.
-- Use the same nonpainting word probe as min/max width. Broader orthogonal
-- block/flex/grid children retain their ordinary auto path here.
local function intrinsicTextHeight(box: any,available: number,alive: () -> boolean,transferred: number?): any
	for _,child in box.Children do
		if child.Kind~='Words'then return nil end
		for _,item in child.Items do if item.Kind=='Image'or item.Kind=='Marker'then return nil end end
	end
	if transferred~=nil then return {Min=transferred,Max=transferred}end
	return DirtyLayout.measure(box,'intrinsic-height',available,nil,function()
		local minimum,maximum=0,0
		for _,child in box.Children do
			local a=naturalWords(child,available,alive,true,nil,nil,'height')
			local b=naturalWords(child,available,alive,false,nil,nil,'height')
			if not alive()then return nil end
			minimum,maximum=math.max(minimum,a),math.max(maximum,b)
		end
		return {Min=minimum,Max=maximum}
	end,alive)
end

-- Return flow height, horizontal extent and vertical extent separately.
-- The document exposes its full vertical extent as the page's canvas height.
local function naturalWidth(box: any, available: number, alive: () -> boolean, minimum: boolean?, unconstrained: boolean?, heightBasis: number?,legacy: any?): number
	if not alive() then return 0 end
	if box.Kind == "Words" then local _,width=naturalWords(box,available,alive,minimum,heightBasis,legacy);return width end
	if box.Kind == "BlockImage" then
		local probe=table.clone(box)
		probe.Style=table.clone(box.Style)
		probe.ImageStyle=nil
		probe.ImageItem=table.clone(box.ImageItem)
		probe.HeightBasis=heightBasis
		if legacy then probe.QuirksMode,probe.QuirksHeightBasis=legacy.Mode,legacy.Height end
		-- Cyclic percentages compress a replaced element's min-content width,
		-- but use auto/unbounded sizing for its max-content contribution.
		-- Treating both probes as auto made responsive images force their natural
		-- width onto fr tracks, even after switching the grid to one column.
		for _,key in {"Width","MinWidth","MaxWidth"} do
			local value=probe.Style[key]
			if value and value.Percent then
				probe.Style[key]=if minimum or key=="MinWidth" then {Value=math.max(0,LengthExpression.resolve(value,0)),Percent=false} else nil
			end
		end
		local cyclicWidth=(box.Style.Width and box.Style.Width.Percent) or (box.Style.MaxWidth and box.Style.MaxWidth.Percent)
		if minimum and cyclicWidth and probe.Style.MinHeight and not probe.Style.MinHeight.Intrinsic
			and not(probe.Style.MinWidth and probe.Style.MinWidth.Intrinsic)then
			local item=probe.ImageItem
			local w,h=item.IntrinsicWidth or item.AttributeWidth,item.IntrinsicHeight or item.AttributeHeight
			local natural=if not item.Control and w and h and h>0 and w>0 then w/h else nil
			local ratio,ratioBorderBox=AspectRatio.resolve(probe.Style,natural)
			if ratio then
				local s=probe.Style;local t,r,b,l=BorderGeometry.sizes(s)
				local ex,ey=s.Padding[2]+s.Padding[4]+r+l,s.Padding[1]+s.Padding[3]+t+b
				local minimumHeight=math.max(0,LengthExpression.resolve(s.MinHeight,0)-(if s.BoxSizing=="border-box" then ey else 0))
				local transferred=AspectRatio.width(minimumHeight,ratio,if ratioBorderBox then ex else 0,if ratioBorderBox then ey else 0)+(if s.BoxSizing=="border-box" then ex else 0)
				s.MinWidth={Value=math.max(transferred,if s.MinWidth then LengthExpression.resolve(s.MinWidth,available) else 0),Percent=false}
			end
		end
		local width = BlockImage.measure(probe, available, alive)
		return width + probe.Style.Margin[2] + probe.Style.Margin[4]
	end
	local s, m = box.Style, box.LayoutMargin
	BoxSpacing.resolve(s, available)
	local bt, br, bb, bl = BorderGeometry.sizes(s)
	local edge = s.Padding[2] + s.Padding[4] + br + bl
	local subtract = if s.BoxSizing == "border-box" then edge else 0
	-- Intrinsic probes use this measurement's explicit height chain, never the
	-- final HeightBasis left behind by a previous table/flex layout pass.
	local heightEdge=if s.BoxSizing == "border-box"or(if legacy then legacy.Mode else box.QuirksMode)and s.TableRole=='cell' then s.Padding[1]+s.Padding[3]+bt+bb else 0
	local heightProbe
	local basis=heightBasis
	if(if legacy then legacy.Mode else box.QuirksMode)then
		heightProbe={Node=box.Node,Style=s,LayoutMargin=m,GridViewport=box.GridViewport,
			QuirksMode=true,QuirksHeightBasis=if legacy then legacy.Height else box.QuirksHeightBasis}
		basis=QuirksLayout.heightBasis(heightProbe,heightBasis)
	end
	local ownHeight=if s.Height and not s.Height.Intrinsic and (not s.Height.Percent or basis ~= nil) then contentSize(s.Height,basis or 0,heightEdge) else nil
	local minHeight=if s.MinHeight and not s.MinHeight.Intrinsic and(not s.MinHeight.Percent or basis~=nil)then contentSize(s.MinHeight,basis or 0,heightEdge)else 0
	local maxHeight=if s.MaxHeight and not s.MaxHeight.Intrinsic and(not s.MaxHeight.Percent or basis~=nil)then contentSize(s.MaxHeight,basis or 0,heightEdge)else math.huge
	if ownHeight then
		ownHeight=math.max(minHeight,math.min(maxHeight,ownHeight))
	end
	local measureChild=BlockLayout.naturalWidth
	if heightProbe then
		local childBasis=QuirksLayout.context(heightProbe,ownHeight,s.Padding[1]+s.Padding[3]+bt+bb,minHeight,maxHeight)
		local childLegacy={Mode=true,Height=childBasis}
		measureChild=function(child,space,work,minimal,unbounded,ordinary)
			return BlockLayout.naturalWidth(child,space,work,minimal,unbounded,ordinary,childLegacy)
		end
	end
	local width = 0
	-- A retained table model is dormant when CSS changes its display role.
	-- Keep it for restoration, but do not use its old rows in block sizing.
	local tableBox=box.TableRows~=nil and s.TableRole=="table"
	local tableAvailable=available
	if tableBox and s.TableLayout == "fixed" and s.Width and not s.Width.Intrinsic then
		tableAvailable=contentSize(s.Width,available,subtract)
		if s.MaxWidth and not s.MaxWidth.Intrinsic then tableAvailable=math.min(tableAvailable,contentSize(s.MaxWidth,available,subtract)) end
		if s.MinWidth and not s.MinWidth.Intrinsic then tableAvailable=math.max(tableAvailable,contentSize(s.MinWidth,available,subtract)) end
	end
	local tableMeasure=if tableBox then TableLayout.measure(box,tableAvailable,measureChild,alive) else nil
	if not alive() then return 0 end
	local ratio = AspectRatio.resolve(s)
	local compress=s.MinIntrinsicSizing or {}
	local scroll=(s.OverflowX=='auto' or s.OverflowX=='scroll' or s.OverflowX=='hidden')
	if minimum and ((compress.Scroll and scroll) or (compress.Extrinsic and (s.Width~=nil or s.MaxWidth~=nil))) then width=if s.Width and not s.Width.Intrinsic and not unconstrained then contentSize(s.Width,available,subtract) else 0
	elseif s.Width and not s.Width.Intrinsic and not unconstrained then width = contentSize(s.Width, available, subtract)
	elseif ratio and ownHeight ~= nil and not minimum then
		width = AspectRatio.width(ownHeight, ratio, subtract, heightEdge)
	elseif ColumnLayout.is(s) then
		width=math.max(0,available-edge-m[2]-m[4])
	elseif GridLayout.is(s) then
		width=GridLayout.natural(box,available,measureChild,alive,minimum)
	elseif tableBox then
		width=if minimum then tableMeasure.Min else tableMeasure.Max
	else
		local row = isFlex(s) and s.FlexDirection ~= "column" and s.FlexDirection ~= "column-reverse"
		-- Wrapped rows can place each item on its own line at minimum width.
		if minimum and s.FlexWrap and s.FlexWrap ~= "nowrap" then row = false end
		local children = box.FlowChildren or box.Children
		for _, child in children do
			local w = measureChild(child, available, alive, minimum,nil,ownHeight)
			if not alive() then return 0 end
			width = if row then width + w else math.max(width, w)
		end
		if row then
			local gap=(s.Gap or {0,0})[2]
			width+=math.max(0,if type(gap)=='table'then LengthExpression.resolve(gap,0)else gap)*math.max(0,#children-1)
		end
		if box.Legend then width = math.max(width,measureChild(box.Legend,available,alive,minimum,nil,ownHeight)) end
	end
	-- Intrinsic sizes include reserved scrollbar space; an assigned width
	-- already includes that space and loses it only inside the scrollport.
	if not box.IntrinsicScrollbarProbe and (unconstrained or not(s.Width and not s.Width.Intrinsic))then
		width+=intrinsicScrollbarWidth(box,width,edge,available,alive,heightBasis,legacy)
		if not alive()then return 0 end
	end
	if not unconstrained then
		local range=if s.MinWidth and s.MinWidth.Intrinsic or s.MaxWidth and s.MaxWidth.Intrinsic then intrinsicWidthRange(box,available,alive,heightBasis,legacy)else nil
		if s.MaxWidth then width=math.min(width,if s.MaxWidth.Intrinsic then intrinsicSize(range,s.MaxWidth.Intrinsic,available-edge-m[2]-m[4])else contentSize(s.MaxWidth,available,subtract))end
		if s.MinWidth then width=math.max(width,if s.MinWidth.Intrinsic then intrinsicSize(range,s.MinWidth.Intrinsic,available-edge-m[2]-m[4])else contentSize(s.MinWidth,available,subtract))end
	end
	if tableMeasure then width=math.max(width,tableMeasure.Min) end
	return width + edge + m[2] + m[4]
end

intrinsicScrollbarWidth=function(box,width,edge,available,alive,heightBasis,legacy)
	local reserved=ScrollLayout.reserved(box,"Y")
	if not ScrollLayout.needsWidthProbe(box)then return reserved end
	-- Reuse the real constrained-flow/overflow algorithm on its owned graph.
	-- This graph has only value-record surfaces; no GUI or paint callback is
	-- forwarded, including while native text bounds suspend or abort.
	local context=LayoutMeasurement.new(box,alive)
	if context.Aborted or not alive()then return 0 end
	local probe=context.Root;probe.IntrinsicScrollbarProbe=true;probe.LayoutParent=nil
	local s=probe.Style
	s.Width={Value=width+(if s.BoxSizing=='border-box'then edge else 0),Percent=false}
	s.MinWidth,s.MaxWidth=nil,nil
	probe.HeightBasis=heightBasis
	if legacy then probe.QuirksMode,probe.QuirksHeightBasis=legacy.Mode,legacy.Height end
	-- This newly copied graph has no live-bound inline layout closures. Prepare
	-- it normally; the original spacing/height bases belong to sizing (arg 7).
	BlockLayout.arrange(probe,width+edge+s.Margin[2]+s.Margin[4],0,0,alive,nil,{SpacingWidth=available,HeightBasis=heightBasis})
	if not alive()then return 0 end
	local result=probe.ScrollY or reserved
	context:KeepMeasurements()
	return result
end

-- Own intrinsic limits must not re-enter themselves; descendants retain
-- their ordinary constraints through the existing width measurement path.
intrinsicWidthRange=function(box,available,alive,heightBasis,legacy)
	local inputs={HeightBasis=heightBasis}
	if legacy then inputs.QuirksMode,inputs.QuirksHeightBasis=legacy.Mode,legacy.Height end
	return DirtyLayout.measure(box,'intrinsic-width-limits',available,inputs,function()
		local probe=table.clone(box);probe.Style=table.clone(box.Style);probe.DirtyContext=nil
		probe.Style.Width,probe.Style.MinWidth,probe.Style.MaxWidth=nil,nil,nil
		probe.Style.Margin,probe.Style.Padding=table.clone(probe.Style.Margin),table.clone(probe.Style.Padding)
		BoxSpacing.resolve(probe.Style,available);probe.LayoutMargin=probe.Style.Margin
		local _,br,_,bl=BorderGeometry.sizes(probe.Style)
		local edges=probe.Style.Padding[2]+probe.Style.Padding[4]+br+bl+probe.Style.Margin[2]+probe.Style.Margin[4]
		local maximum=naturalWidth(probe,available,alive,false,true,heightBasis,legacy)-edges
		if not alive()then return {Min=0,Max=0}end
		local s=probe.Style
		local basis=if legacy and legacy.Mode then QuirksLayout.heightBasis({Style=s,QuirksMode=true,QuirksHeightBasis=legacy.Height},heightBasis)
			else QuirksLayout.heightBasis(probe,heightBasis)
		local transferred=AspectRatio.resolve(s)and s.Height and not s.Height.Intrinsic and(not s.Height.Percent or basis~=nil)
		local minimum=if transferred then maximum else naturalWidth(probe,available,alive,true,true,heightBasis,legacy)-edges
		return {Min=math.max(0,minimum),Max=math.max(0,minimum,maximum)}
	end,alive)
end

function BlockLayout.intrinsicWidth(box: any,available: number,alive: () -> boolean,keyword: string,heightBasis: number?): number
	if not alive()then return 0 end
	local s=box.Style
	if s.MarginValues or s.PaddingValues then
		s=table.clone(s);s.Margin,s.Padding=table.clone(s.Margin),table.clone(s.Padding);BoxSpacing.resolve(s,available)
	end
	local _,br,_,bl=BorderGeometry.sizes(s)
	local availableContent=available-s.Padding[2]-s.Padding[4]-br-bl-s.Margin[2]-s.Margin[4]
	return intrinsicSize(intrinsicWidthRange(box,available,alive,heightBasis),keyword,availableContent)
end

function BlockLayout.naturalWidth(box: any, available: number, alive: () -> boolean, minimum: boolean?, unconstrained: boolean?, heightBasis: number?,legacy: any?): number
	if not alive() then return 0 end
	local tag = "intrinsic:"..tostring(minimum == true)..":"..tostring(unconstrained == true)
	local inputs={HeightBasis=heightBasis}
	if legacy then inputs.QuirksMode,inputs.QuirksHeightBasis=legacy.Mode,legacy.Height end
	return DirtyLayout.measure(box,tag,available,inputs,function()
		if box.GeometryOnly then return naturalWidth(box,available,alive,minimum,unconstrained,heightBasis,legacy)end
		local context=LayoutMeasurement.new(box,alive)
		if context.Aborted or not alive()then return 0 end
		bindInline(context.Root,alive)
		local result=naturalWidth(context.Root,available,alive,minimum,unconstrained,heightBasis,legacy)
		context:KeepMeasurements()
		return result
	end,alive)
end

local function arrange(box: any, available: number, x: number, y: number, alive: () -> boolean, sizing: any?): (number, number, number)
	if not alive() then return 0, 0, 0 end
	ScrollLayout.prepare(box)
	local style = box.Style
	if box.Kind == "BlockImage" then return BlockImage.arrange(box, available, x, y, alive, sizing) end
	if box.Kind == "Words" then
		local contentWidth=if sizing and sizing.ContentWidth then sizing.ContentWidth else available
		local flow=sizing and sizing.FloatFlow
		local lines=if flow then FloatLayout.lines({Floats=flow.Floats,X=flow.X+x,Y=flow.Y+y},contentWidth) else nil
		box.PlaceFloat=if sizing and sizing.PlaceFloat then function(child,top,used,height)
			return sizing.PlaceFloat(child,y+top,used,height)
		end else nil
		local height, width = WordLayout.arrange(box,contentWidth, x, y, alive,lines)
		box.LayoutX, box.LayoutY, box.LocalRight, box.LocalBottom = x, y, width, height
		return height, width, height
	end
	local spacingChanged = BoxSpacing.resolve(style, if sizing and sizing.SpacingWidth then sizing.SpacingWidth else available)
	local margin, padding = box.LayoutMargin, style.Padding
	local bt, br, bb, bl = BorderGeometry.sizes(style)
	local horizontalEdges, verticalEdges = padding[2] + padding[4] + br + bl, padding[1] + padding[3] + bt + bb
	local borderBox = style.BoxSizing == "border-box"
	local widthEdges, heightEdges = if borderBox then horizontalEdges else 0, if QuirksLayout.heightBorderBox(box) then verticalEdges else 0
	local ratio = AspectRatio.resolve(style)
	local heightBasis=if sizing and sizing.HeightBasis ~= nil then sizing.HeightBasis else box.HeightBasis
	local ownHeightBasis=QuirksLayout.heightBasis(box,heightBasis)
	local intrinsicHeight=style.Height and style.Height.Intrinsic
	local tableBox=box.TableRows~=nil and style.TableRole=="table"
	local fixedHeight = if style.Height and not intrinsicHeight and (not style.Height.Percent or ownHeightBasis ~= nil) then contentSize(style.Height, ownHeightBasis or 0, heightEdges) else nil
	-- Chromium's empty-table profile drops the preferred height when no row
	-- group contributes. Keep borders/padding and the computed declaration.
	if box.QuirksMode and tableBox and #box.TableRows==0 and #box.TableGroups==0 then fixedHeight=nil end
	local minHeight = if style.MinHeight and not style.MinHeight.Intrinsic and(not style.MinHeight.Percent or ownHeightBasis~=nil)then contentSize(style.MinHeight,ownHeightBasis or 0,heightEdges) else 0
	local maxHeight = if style.MaxHeight and not style.MaxHeight.Intrinsic and(not style.MaxHeight.Percent or ownHeightBasis~=nil)then contentSize(style.MaxHeight,ownHeightBasis or 0,heightEdges) else math.huge
	-- Cell min/max heights remain undefined in CSS 2.1. Match the native
	-- browser profile: row content and height contribute, min/max do not.
	if sizing and sizing.TableCell then minHeight,maxHeight=0,math.huge end
	local mainRow = sizing and sizing.MainAxis == "row"
	local mainColumn = sizing and sizing.MainAxis == "column"
	local intrinsicMin=if sizing and sizing.TableCell or mainColumn and sizing.IgnoreMainLimits then nil else style.MinHeight and style.MinHeight.Intrinsic
	local intrinsicMax=if sizing and sizing.TableCell or mainColumn and sizing.IgnoreMainLimits then nil else style.MaxHeight and style.MaxHeight.Intrinsic
	if mainColumn and sizing.IgnoreMainLimits then minHeight, maxHeight, fixedHeight = 0, math.huge, nil end
	if fixedHeight then fixedHeight = math.max(minHeight, math.min(maxHeight, fixedHeight)) end
	local contentWidth = math.max(0, available - margin[2] - margin[4] - horizontalEdges)
	if style.Width then
		if style.Width.Intrinsic then
			local minimum=BlockLayout.naturalWidth(box,available,alive,true,true)-horizontalEdges-margin[2]-margin[4]
			local maximum=BlockLayout.naturalWidth(box,available,alive,false,true)-horizontalEdges-margin[2]-margin[4]
			contentWidth=if style.Width.Intrinsic=='min-content'then minimum elseif style.Width.Intrinsic=='max-content'then maximum else math.min(maximum,math.max(minimum,contentWidth))
		else contentWidth = contentSize(style.Width, available, widthEdges)end
	end
	-- A float's used margin-box width is chosen by its containing flow. Keep
	-- that containing width for percentages instead of resolving them again
	-- against the already measured float width.
	if sizing and sizing.FloatWidth ~= nil then contentWidth = math.max(0, sizing.FloatWidth-margin[2]-margin[4]-horizontalEdges) end
	if sizing and sizing.ContentWidth ~= nil and (not style.Width or sizing.TableCell) then contentWidth = sizing.ContentWidth end
	if sizing and sizing.ContentHeight ~= nil and (not style.Height or sizing.TableCell) then fixedHeight = sizing.ContentHeight end
	if mainRow and sizing.MainSize ~= nil then contentWidth = math.max(0, sizing.MainSize) end
	if mainColumn and sizing.MainSize ~= nil then fixedHeight = math.max(0, sizing.MainSize) end
	if ratio and not style.Width and not (sizing and (sizing.ContentWidth ~= nil or sizing.FloatWidth ~= nil or mainRow)) then
		if fixedHeight then contentWidth = AspectRatio.width(fixedHeight, ratio, widthEdges, heightEdges)
		else
			contentWidth = math.max(AspectRatio.width(minHeight, ratio, widthEdges, heightEdges),
				math.min(contentWidth, AspectRatio.width(maxHeight, ratio, widthEdges, heightEdges)))
		end
	end
	local widthRange
	local function widthLimit(value)
		if not value.Intrinsic then return contentSize(value,available,widthEdges)end
		if not widthRange then widthRange=intrinsicWidthRange(box,available,alive,fixedHeight)end
		return intrinsicSize(widthRange,value.Intrinsic,available-horizontalEdges-margin[2]-margin[4])
	end
	if style.MaxWidth and not (sizing and sizing.TableCell) and not (mainRow and sizing.IgnoreMainLimits) then contentWidth = math.min(contentWidth, widthLimit(style.MaxWidth)) end
	-- CSS minimums win if the maximum is smaller than the minimum.
	if style.MinWidth and not (sizing and sizing.TableCell) and not (mainRow and sizing.IgnoreMainLimits) then contentWidth = math.max(contentWidth, widthLimit(style.MinWidth)) end
	local tableMeasure
	if tableBox then
		tableMeasure=TableLayout.measure(box,contentWidth,BlockLayout.naturalWidth,alive)
		if not tableMeasure then return 0,0,0 end
		if not style.Width and not (sizing and (sizing.ContentWidth or sizing.MainSize)) then contentWidth=math.min(contentWidth,tableMeasure.Max) end
		contentWidth=math.max(contentWidth,tableMeasure.Min)
		if style.MinWidth then contentWidth=math.max(contentWidth,widthLimit(style.MinWidth)) end
	end
	if box.Node.Name == "fieldset" and not style.MinWidth and not (mainRow and sizing.IgnoreMainLimits) then
		contentWidth = math.max(contentWidth, BlockLayout.naturalWidth(box, available, alive, true, true) - horizontalEdges - margin[2] - margin[4])
	end
	local legendExtra = FieldsetLayout.legend(box, contentWidth, BlockLayout.naturalWidth, BlockLayout.arrange, alive)
	if not alive() then return 0, 0, 0 end
	-- The legend reserves the top border area. Explicit height still describes the whole box.
	verticalEdges += legendExtra
	if fixedHeight then fixedHeight = math.max(0, fixedHeight - legendExtra) end
	minHeight, maxHeight = math.max(0, minHeight - legendExtra), math.max(0, maxHeight - legendExtra)
	local scrollX, scrollY = box.ScrollX or 0, box.ScrollY or 0
	box.ScrollStartX,box.ScrollStartY=0,0
	local outerWidth = contentWidth + horizontalEdges
	local outerMinHeight, outerMaxHeight = minHeight + verticalEdges, maxHeight + verticalEdges
	local outerFixedHeight = fixedHeight
	contentWidth = math.max(0, contentWidth - scrollY)
	if fixedHeight then fixedHeight = math.max(0, fixedHeight - scrollX) end
	minHeight, maxHeight = math.max(0, minHeight - scrollX), math.max(0, maxHeight - scrollX)
	local heightRange
	if WritingMode.vertical(style)and(intrinsicHeight or intrinsicMin or intrinsicMax or not style.Height)and not(mainColumn or mainRow or tableBox)then
		local transferred=if ratio and style.Width and not style.Width.Intrinsic then
			math.max(0,AspectRatio.height(contentWidth+scrollY,ratio,widthEdges,heightEdges)-scrollX)else nil
		heightRange=intrinsicTextHeight(box,contentWidth,alive,transferred)
		if not alive()then return 0,0,0 end
		if heightRange then
			local stretch=if ownHeightBasis then math.max(0,ownHeightBasis-verticalEdges-margin[1]-margin[3])else math.huge
			if intrinsicMin then minHeight=intrinsicSize(heightRange,intrinsicMin,stretch)end
			if intrinsicMax then maxHeight=intrinsicSize(heightRange,intrinsicMax,stretch)end
			if intrinsicHeight or not style.Height then
				fixedHeight=intrinsicSize(heightRange,intrinsicHeight or 'fit-content',stretch)
				-- A parallel automatic inline axis stretches instead of fitting.
				if transferred==nil and not intrinsicHeight and ownHeightBasis and box.LayoutParent and WritingMode.vertical(box.LayoutParent.Style)then fixedHeight=stretch end
			end
			if fixedHeight then fixedHeight=math.max(minHeight,math.min(maxHeight,fixedHeight))end
			outerMinHeight,outerMaxHeight=minHeight+verticalEdges,maxHeight+verticalEdges
			outerFixedHeight=if fixedHeight then fixedHeight+scrollX else nil
		end
	end
	local quirkyBasis,quirkyMinimum=QuirksLayout.context(box,fixedHeight,verticalEdges,minHeight,maxHeight)
	QuirksLayout.children(box,fixedHeight,quirkyBasis)
	for _, child in box.Children do
		if child.Kind ~= "Words" and BoxSpacing.resolve(child.Style, contentWidth) then spacingChanged = true end
	end
	if spacingChanged then prepareMargins(box, sizing and sizing.FlexItem,alive) end
	margin = box.LayoutMargin
	local floatFlow=sizing and sizing.FloatFlow
	local independentFlow=FloatLayout.independent(style)or box.Node.Kind=='Document'or QuirksLayout.isRoot(box)
	if floatFlow and not independentFlow then
		floatFlow={Floats=floatFlow.Floats,X=floatFlow.X+x+margin[4],Y=floatFlow.Y+y+margin[1]}
	else floatFlow=if independentFlow and box.HasFloats then {Floats={},X=0,Y=0}else nil end
	local contentLeft = bl + padding[4] + (box.ScrollLeadingX or 0)
	local cursor, farRight = bt + legendExtra + padding[1] + (box.ScrollLeadingY or 0), contentWidth + horizontalEdges
	box.ContentTop = cursor
	local contentOffset=if sizing then sizing.ContentOffset or 0 else 0
	cursor+=contentOffset
	box.FirstBaseline = nil
	local farBottom = cursor
	local previousBottom: number? = nil
	local previousMargins
	local currentMargins
	local function beginFlow(childMargin)
		currentMargins=nil
		if not childMargin then return end
		if previousMargins then
			local group=table.clone(previousMargins)
			group.Positive=math.max(group.Positive,childMargin[1]);group.Negative=math.min(group.Negative,childMargin[1])
			cursor+=group.Positive+group.Negative-previousBottom-childMargin[1]
			currentMargins=group
		elseif previousBottom then
			cursor+=BoxSpacing.collapse(previousBottom,childMargin[1])-previousBottom-childMargin[1]
		end
	end
	local function consumeFlow(child,childMargin,childHeight)
		if childMargin and child.SelfCollapsing then
			local group=currentMargins or {Positive=math.max(0,previousBottom or 0,childMargin[1]),Negative=math.min(0,previousBottom or 0,childMargin[1])}
			local before=group.Positive+group.Negative
			group.Positive=math.max(group.Positive,childMargin[3]);group.Negative=math.min(group.Negative,childMargin[3])
			local combined=group.Positive+group.Negative
			cursor+=childHeight+combined-before-childMargin[3]
			previousBottom,previousMargins=combined,group
		else
			cursor+=childHeight;previousBottom=if childMargin then childMargin[3]else nil;previousMargins=nil
		end
	end
	local function finalHeight(value: number): number
		if (intrinsicMin or intrinsicMax)and not heightRange then
			-- Ordinary block-axis limits use this actual content pass. Its
			-- percentage descendants already used the definite length limits.
			local natural=value
			local last=box.FlowChildren[#box.FlowChildren]
			if not box.CollapseBottom and last and last.Kind~='Words'and bb==0 and padding[3]==0
				and style.Display=='block'and not FloatLayout.independent(style)and not ratio then
				-- A specified height prevents actual margin collapse, but an
				-- intrinsic limit measures the automatic block extent. Its last
				-- adjoining margin contributes outside that hypothetical extent.
				natural-=last.LayoutMargin[3]
			end
			if ratio then
				local preferred=math.max(0,AspectRatio.height(contentWidth+scrollY,ratio,widthEdges,heightEdges)-scrollX)
				natural=if style.Overflow=='hidden'then preferred else math.max(natural,preferred)
			end
			if intrinsicMin then minHeight=natural end
			if intrinsicMax then maxHeight=natural end
			outerMinHeight,outerMaxHeight=minHeight+verticalEdges,maxHeight+verticalEdges
			outerFixedHeight=nil
		end
		if sizing and sizing.TableCollapsed then return fixedHeight or value end
		if tableBox then return math.max(value,(fixedHeight or 0)-(box.CollapsedTrackHeightLoss or 0),minHeight-(box.CollapsedTrackHeightLoss or 0)) end
		if sizing and sizing.TableCell then return math.max(value,fixedHeight or 0,minHeight) end
		if fixedHeight then value = fixedHeight
		elseif ratio and not (mainColumn and sizing.IgnoreMainLimits) then
			local preferred = math.max(0, AspectRatio.height(contentWidth + scrollY, ratio, widthEdges, heightEdges) - scrollX)
			value = if style.Overflow ~= "hidden" and not style.MinHeight then math.max(value, preferred) else preferred
		end
		return math.max(minHeight, math.min(maxHeight, value))
	end
	if tableBox then
		local h,right,bottom,paintedWidth=TableLayout.arrange(box,contentWidth,tableMeasure,BlockLayout.arrange,alive,math.max(minHeight,fixedHeight or 0))
		if not alive() then return 0,0,0 end
		if paintedWidth then contentWidth=paintedWidth; outerWidth=contentWidth+horizontalEdges+scrollY; farRight=outerWidth end
		cursor+=h
		farRight,farBottom=math.max(farRight,contentLeft+right),box.ContentTop+bottom
	elseif ColumnLayout.is(style) then
		local h,right,bottom=ColumnLayout.arrange(box,contentWidth,finalHeight,BlockLayout.arrange,alive,fixedHeight,WordLayout.paintFragments)
		if not alive() then return 0,0,0 end
		cursor+=h;farRight,farBottom=math.max(farRight,contentLeft+right),cursor-h+bottom
	elseif GridLayout.is(style) then
        local h,right,bottom=GridLayout.arrange(box,contentWidth,finalHeight,BlockLayout.naturalWidth,BlockLayout.arrange,alive,fixedHeight)
        if not alive() then return 0,0,0 end
		cursor+=h;farRight,farBottom=math.max(farRight,contentLeft+right),cursor-h+bottom
	elseif isFlex(style) then
		local h, right, bottom = FlexLayout.arrange(box, contentWidth, finalHeight, BlockLayout.naturalWidth, BlockLayout.arrange, alive, fixedHeight,BlockLayout.intrinsicWidth)
		if not alive() then return 0, 0, 0 end
		cursor += h
		farRight, farBottom = math.max(farRight, contentLeft + right), cursor - h + bottom
	else
	local hasFloats = false
	for _, child in box.Children do
		if child.Kind ~= "Words" and child.Style.Float and child.Style.Float ~= "none" then
			hasFloats = true
			break
		end
	end
	if hasFloats then
		-- Floats use a separate flow path so pages without floats retain the exact
		-- block/table layout and cache behavior used by the normal path below.
		local flow=floatFlow or {Floats={},X=0,Y=0}
		local floats=flow.Floats
		local function placeFloat(child,anchorTop,inlineUsed,inlineHeight): boolean
			local childStyle=child.Style
			local side=childStyle.Float
			if side=="inline-start"then side=if style.Direction=="rtl"then "right"else "left"end
			if side=="inline-end"then side=if style.Direction=="rtl"then "left"else "right"end
			local clear=childStyle.Clear
			if clear=="inline-start"then clear=if style.Direction=="rtl"then "right"else "left"end
			if clear=="inline-end"then clear=if style.Direction=="rtl"then "left"else "right"end
			local top=anchorTop
			-- A later float cannot rise above an earlier float's margin top.
			for _,active in floats do top=math.max(top,active.Top-flow.Y)end
			if clear and clear~="none"then top=FloatLayout.clear(flow,flow.Y+top,clear)-flow.Y end
			local minimum,maximum
			if child.Kind=="BlockImage"then
				local width=BlockImage.measure(child,contentWidth,alive)
				minimum=width+child.Style.Margin[2]+child.Style.Margin[4];maximum=minimum
			else
				minimum=BlockLayout.naturalWidth(child,contentWidth,alive,true)
				maximum=BlockLayout.naturalWidth(child,contentWidth,alive,false)
			end
			if not alive()then return false end
			local left,right,preferred
			repeat
				left,right=FloatLayout.bounds(flow,flow.X+contentLeft,flow.Y+top,contentWidth,.001,true)
				preferred=math.max(minimum,math.min(maximum,math.max(0,right-left)))
				local used=if math.abs(top-anchorTop)<1e-6 then inlineUsed else 0
				if preferred+used<=right-left+1e-6 then break end
				local nextTop=if used>0 then anchorTop+inlineHeight else math.huge
				for _,active in floats do
					if flow.Y+top<active.Bottom and flow.Y+top+.001>active.Top then nextTop=math.min(nextTop,active.Bottom-flow.Y)end
				end
				-- Oversized floats may overflow an otherwise empty full-width band.
				if nextTop==math.huge or nextTop<=top+1e-6 then break end
				top=nextTop
			until not alive()
			if not alive()then return false end
			local floatX=contentLeft+(if side=="right"then right-preferred else left)
			local childHeight,childWidth,childBottom=BlockLayout.arrange(child,contentWidth,floatX,top,alive,true,{FloatWidth=preferred})
			if not alive()then return false end
			local occupied=child.OuterWidth+child.LayoutMargin[2]+child.LayoutMargin[4]
			FloatLayout.add(flow,child,side,flow.X+floatX,flow.Y+top,occupied,childHeight,contentWidth)
			farRight=math.max(farRight,floatX+childWidth);farBottom=math.max(farBottom,top+childBottom)
			return true
		end
		for _, child in box.Children do
			if child == box.Legend or child.Style.Hidden or child.TopLayerHidden or child.InlineFloat then continue end
			if child.Kind ~= "Words" and (child.Style.Position == "absolute" or child.Style.Position == "fixed") then
				child.StaticX, child.StaticY = contentLeft, cursor
				continue
			end
			local childStyle = child.Style
			local floatSide = if child.Kind ~= "Words" then childStyle.Float else "none"
			if floatSide == "inline-start" then floatSide = if style.Direction == "rtl" then "right" else "left" end
			if floatSide == "inline-end" then floatSide = if style.Direction == "rtl" then "left" else "right" end
			local clear = if child.Kind ~= "Words" then childStyle.Clear else "none"
			if clear == "inline-start" then clear = if style.Direction == "rtl" then "right" else "left" end
			if clear == "inline-end" then clear = if style.Direction == "rtl" then "left" else "right" end
			if clear and clear ~= "none" then
				cursor = FloatLayout.clear(flow,flow.Y+cursor,clear)-flow.Y
			end
			local left,right=FloatLayout.bounds(flow,flow.X+contentLeft,flow.Y+cursor,contentWidth,.001,true)
			local leftInset,rightInset=left,contentWidth-right
			if floatSide == "left" or floatSide == "right" then
				if not placeFloat(child,cursor,0,0)then return 0,0,0 end
				continue
			end
			local childMargin = if child.Kind ~= "Words" then child.LayoutMargin else nil
			beginFlow(childMargin)
			local independent=child.Kind~="Words" and FloatLayout.independent(childStyle)
			local flowWidth = if independent then math.max(0,contentWidth-leftInset-rightInset) else contentWidth
			local flowX = contentLeft+(if independent then leftInset else 0)
			local childHeight, childWidth, childBottom = BlockLayout.arrange(child, flowWidth, flowX, cursor, alive, true,if independent then nil else {FloatFlow=flow,PlaceFloat=placeFloat})
			if not alive() then return 0, 0, 0 end
			if box.FirstBaseline == nil and child.FirstBaseline ~= nil then
				box.FirstBaseline = cursor + (if childMargin then childMargin[1] else 0) + child.FirstBaseline
			end
			farBottom = math.max(farBottom, cursor + childBottom)
			farRight = math.max(farRight, flowX + childWidth)
			consumeFlow(child,childMargin,childHeight)
		end
		if independentFlow then
			for _, active in floats do
				local bottom=active.Bottom-flow.Y
				farBottom=math.max(farBottom,bottom);cursor=math.max(cursor,bottom)
			end
		end
	else
	for _, child in box.Children do
		if child == box.Legend or child.Style.Hidden or child.TopLayerHidden then continue end
		if child.Kind ~= "Words" and (child.Style.Position == "absolute" or child.Style.Position=="fixed" or child.LayoutAsTopLayer) then
			child.StaticX, child.StaticY = contentLeft, cursor
			continue
		end
		-- Adjacent block margins overlap; a text run separates them.
		-- Collapse the largest positive and most negative adjoining margins.
		local childMargin = if child.Kind ~= "Words" then child.LayoutMargin else nil
		if child == box.FlowChildren[1] and box.CollapseTop then cursor -= childMargin[1] end
		beginFlow(childMargin)
		if floatFlow and child.Kind~="Words" and child.Style.Clear and child.Style.Clear~="none" then
			local clear=child.Style.Clear
			if clear=="inline-start" then clear=if style.Direction=="rtl" then "right" else "left" end
			if clear=="inline-end" then clear=if style.Direction=="rtl" then "left" else "right" end
			cursor=FloatLayout.clear(floatFlow,floatFlow.Y+cursor,clear)-floatFlow.Y
		end
		local flowWidth=if sizing and sizing.TableFlowWidth then sizing.TableFlowWidth else contentWidth
		local flowX=contentLeft+(if style.Direction == "rtl" then contentWidth-flowWidth else 0)
		local childHeight, childWidth, childBottom = BlockLayout.arrange(child, flowWidth, flowX, cursor, alive, true,if floatFlow then {FloatFlow=floatFlow} else nil)
		if not alive() then return 0, 0, 0 end
		if child.Kind=='Words'and ScrollLayout.has(box)then
			local low,high=child.FlowOverflowStart or 0,child.FlowOverflowEnd or 0
			if WritingMode.vertical(child.Style)then
				if child.Style.WritingMode=='sideways-lr'then
					local inline=child.HeightBasis or flowWidth;low,high=inline-high,inline-low
				end
				box.ScrollStartY=math.min(box.ScrollStartY,cursor+low)
				farBottom=math.max(farBottom,cursor+high)
			else
				box.ScrollStartX=math.min(box.ScrollStartX,flowX+low)
				farRight=math.max(farRight,flowX+high)
			end
		end
		if child == box.FlowChildren[#box.FlowChildren] and box.CollapseBottom then
			childBottom = childMargin[1] + child.OwnBottom
		end
		if child.SelfCollapsing then childBottom=childMargin[1]+child.OwnBottom end
		if box.FirstBaseline == nil and child.FirstBaseline ~= nil then
			box.FirstBaseline = cursor + (if childMargin then childMargin[1] else 0) + child.FirstBaseline
		end
		farBottom = math.max(farBottom, cursor + childBottom)
		consumeFlow(child,childMargin,childHeight)
		-- A descendant which overflows the content box begins at the content
		-- edge.  The parent's trailing padding is already represented by
		-- outerWidth and must not be appended after that overflow again.
		farRight = math.max(farRight, contentLeft + childWidth)
	end
	if box.CollapseBottom then cursor -= box.FlowChildren[#box.FlowChildren].LayoutMargin[3] end
	if independentFlow and floatFlow then
		for _,active in floatFlow.Floats do
			local bottom=active.Bottom-floatFlow.Y
			farBottom=math.max(farBottom,bottom);cursor=math.max(cursor,bottom)
		end
	end
	end
	end
	local contentHeight = cursor - box.ContentTop - contentOffset
	if box.Marker and style.ListStylePosition ~= "inside" then
		if box.FirstBaseline == nil then
			local extents = FontMetrics.extents(style, FontMetrics.resolve(style))
			box.FirstBaseline = bt + padding[1] + extents.Ascent
			contentHeight = math.max(contentHeight, extents.Ascent + extents.Descent)
		end
		-- Outside markers are anchored to the border-box edge. The content
		-- inset belongs only to inside markers and must not pull these inward.
		if not ListMarker.arrange(box.Marker, style, box.FirstBaseline, 0, alive) then return 0, 0, 0 end
	end
	-- Keep the content's intrinsic block extent separate from an animated or
	-- explicitly constrained height. It is reused by intrinsic-size transitions.
	box.AutoContentHeight=math.max(0,contentHeight)
	contentHeight = finalHeight(contentHeight)
	-- A scrollbar consumes explicit height; only automatic height grows to accommodate it.
	local height = if tableBox or (sizing and sizing.TableCell) then contentHeight+scrollX+verticalEdges else math.max(outerMinHeight, math.min(outerMaxHeight,
		(if outerFixedHeight ~= nil then outerFixedHeight else contentHeight + scrollX) + verticalEdges))
	if quirkyMinimum then height=math.max(height,quirkyMinimum);contentHeight=math.max(contentHeight,height-verticalEdges-scrollX)end
	farBottom = math.max(height - scrollX, farBottom + padding[3] + bb)
	box.UnclippedRight, box.UnclippedBottom = farRight, farBottom
	if ScrollLayout.has(box)then box.ScrollRight, box.ScrollBottom = farRight, farBottom end
	if style.Overflow == "hidden" then
		farRight, farBottom = outerWidth, height
	end
	box.OwnBottom = farBottom
	box.OuterWidth, box.OuterHeight = outerWidth, height
	if not box.GeometryOnly then MaskGradient.update(box,outerWidth,height)end
	if box.Corner and style.BorderRadii then
		local resolved=CornerRadii.resolve(style,outerWidth,height)
		if style.CornerShape~="round" then write(box.Corner,"CornerRadius",UDim.new(0,0))
		elseif box.NativeCornerRadii and resolved then
			CornerRadii.apply(box.Corner,resolved)
		else
			local radius=math.huge
			for _,corner in resolved or {} do radius=math.min(radius,corner[1],corner[2]) end
			write(box.Corner,"CornerRadius",UDim.new(0,math.max(0,math.min(radius,outerWidth/2,height/2))))
		end
	end
	if not box.GeometryOnly and box.RadiusRenderer and box.RadiusRenderer.DrawRadius then
		local rounded=box.RadiusRenderer:DrawRadius(box,style,outerWidth,height)
		if rounded~=nil then
			style.ResolvedBorderRadii=if rounded then box.ResolvedBorderRadii else nil
			local used=CanvasBackground.usedStyle(box,style)
			write(box.Gui,"BackgroundTransparency",if rounded then 1 elseif used.Visibility~="hidden" and used.Background then 1-(used.BackgroundAlpha or 1) else 1)
		end
	end
	box.ContentWidth, box.ContentHeight, box.DefiniteHeight = contentWidth, contentHeight, fixedHeight ~= nil and not intrinsicHeight
	box.SelfCollapsing=height==0 and verticalEdges==0 and minHeight==0 and style.Display=='block'and not FloatLayout.independent(style)
	if box.SelfCollapsing then
		for _,child in box.FlowChildren do
			if child.Kind=='Words'then if #child.Items>0 then box.SelfCollapsing=false;break end
			elseif child.Style.Float=='none'and not child.SelfCollapsing then box.SelfCollapsing=false;break end
		end
	end
	box.LocalRight, box.LocalBottom = farRight, farBottom
	if box.Outline then OutlineBox.arrange(box.Outline, outerWidth, height) end
	if box.ClipContent then write(box.ClipContent, "Size", UDim2.fromOffset(outerWidth, height)) end
	if box.OverflowClip then
		local edges=style.OverflowClipMargins
		local function edge(side: number): number
			local item=edges[side]
			local border=({bt,br,bb,bl})[side]
			local replaced=box.Node and ({img=true,svg=true,audio=true,video=true,canvas=true,iframe=true,object=true,embed=true})[box.Node.Name]
			local visualBox=item.Box or (if replaced then "content-box" else "padding-box")
			local inset=if visualBox=="border-box" then 0 elseif visualBox=="content-box" then border+padding[side] else border
			return inset-LengthExpression.resolve(item.Offset,0)
		end
		local top,right,bottom,left=edge(1),edge(2),edge(3),edge(4)
		local x,y,w,h=left,top,math.max(0,outerWidth-left-right),math.max(0,height-top-bottom)
		-- A visible axis must not be clipped by the other axis' rectangle.
		if style.OverflowX=="visible" then x,w=-4096,outerWidth+8192 end
		if style.OverflowY=="visible" then y,h=-4096,height+8192 end
		write(box.OverflowClip,"Position",UDim2.fromOffset(x,y))
		write(box.OverflowClip,"Size",UDim2.fromOffset(w,h))
		write(box.OverflowContent,"Position",UDim2.fromOffset(-x,-y))
		write(box.OverflowContent,"Size",UDim2.fromOffset(outerWidth,height))
		if box.OverflowClipCorner then
			local radii=CornerRadii.resolve(style,outerWidth,height)
			local base=style.BorderRadius or 0
			for index,property in {"TopLeftRadius","TopRightRadius","BottomRightRadius","BottomLeftRadius"} do
				local corner=if radii then radii[index] else {base,base}
				local dx=if index==1 or index==4 then left else right
				local dy=if index==1 or index==2 then top else bottom
				write(box.OverflowClipCorner,property,UDim.new(0,math.max(0,math.min(corner[1]-dx,corner[2]-dy,w/2,h/2))))
			end
		end
	end
	if box.PaintContent then
		local insetTop,insetRight,insetBottom,insetLeft=BorderGeometry.sizes(style)
		write(box.PaintClip,"Position",UDim2.fromOffset(insetLeft,insetTop))
		write(box.PaintClip,"Size",UDim2.fromOffset(math.max(0,outerWidth-insetLeft-insetRight),math.max(0,height-insetTop-insetBottom)))
		write(box.PaintContent,"Position",UDim2.fromOffset(-insetLeft,-insetTop))
		write(box.PaintContent,"Size",UDim2.fromOffset(outerWidth,height))
	end
	if box.InsetEdges and not box.GeometryOnly then
		BorderBox.arrange(box.InsetEdges, style, outerWidth, height, box.LegendGap)
	end
	local paintHeight=height
	if box.TableSurface then
		local total,right,bottom,top=TableCaptions.arrange(box,outerWidth,height,BlockLayout.arrange,alive)
		if not alive() then return 0,0,0 end
		height=total
		farRight,farBottom=math.max(farRight,right),math.max(top+farBottom,bottom)
		box.OuterHeight,box.OwnBottom=height,farBottom
		box.LocalRight,box.LocalBottom=farRight,farBottom
		box.UnclippedRight,box.UnclippedBottom=farRight,farBottom
		if box.FirstBaseline then box.FirstBaseline+=top end
	end
	if box.Node.Kind ~= "Document" then
		local offset = 0
		if not (sizing and (sizing.FlexItem or sizing.Positioned)) and style.MarginAuto and style.MarginAuto[4] then
			local free = math.max(0, available - outerWidth - margin[2] - margin[4])
			offset = free / (if style.MarginAuto[2] then 2 else 1)
		elseif not (sizing and (sizing.FlexItem or sizing.Positioned))and style.ContainingDirection=='rtl'
			and style.Float=='none'and (style.Display=='block'or style.Display=='flow-root')then
			-- CSS 2.1 drops the start-side constraint for an overconstrained
			-- normal block. Use its containing block's direction, not its own.
			offset=available-outerWidth-margin[2]-margin[4]
		end
		box.LayoutX, box.LayoutY = x + margin[4] + offset, y + margin[1]
		box.PaintX, box.PaintY = box.LayoutX, box.LayoutY
		if not box.LayoutProbe then write(box.Gui, "Position", UDim2.fromOffset(box.LayoutX, box.LayoutY)) end
		write(box.Gui, "Size", UDim2.fromOffset(outerWidth, height))
		if box.BackgroundRenderer then box.BackgroundRenderer:Draw(box,outerWidth,paintHeight) end
		if box.VisualEffects then box.VisualEffects:Draw(box,outerWidth,paintHeight) end
		if box.InsetRenderer then box.InsetRenderer:Draw(box, outerWidth, paintHeight) end
		farRight += offset
	end
	-- Bottom margin follows the box, not its overflowing descendants.
	local extent = margin[1] + math.max(height + margin[3], farBottom)
	return if box.Node.Kind == "Document" then extent else height + margin[1] + margin[3], farRight + margin[2] + margin[4], extent
end

bindInline=function(current,alive)
		if not alive() then return end
        for _,item in current.Items or {} do if item.InlineBox then
            item.MeasureGrid=function(space,minimum,alive)
                local nested=item.InlineBox
                local min=BlockLayout.naturalWidth(nested,space,alive,true)
                local max=BlockLayout.naturalWidth(nested,space,alive,false)
                local used=if minimum then min else math.max(min,math.min(max,space))
				-- A declared width is relative to the containing inline line. Passing
				-- its measured result as the containing width would resolve percentages
				-- a second time (44% became 44% of 44%). Auto-width atomic boxes still
				-- use their shrink-to-fit measurement.
				local containing=if nested.Style.Width then space else used
				local measured=nested
				local context
				if not nested.GeometryOnly then
					context=LayoutMeasurement.new(nested,alive)
					if context.Aborted or not alive()then return 0,0,nil end
					measured=context.Root
					bindInline(measured,alive)
				end
				LayoutProbe.arrange(measured,containing,BlockLayout.arrange,alive)
				if not alive()then return 0,0,nil end
				if context then context:KeepMeasurements()end
				item.InlineMeasurement={Available=containing,Width=measured.OuterWidth,Height=measured.OuterHeight,Baseline=measured.FirstBaseline}
                return measured.OuterWidth,measured.OuterHeight,measured.FirstBaseline or measured.OuterHeight
            end
			item.ArrangeGrid=function(x,y,work)
				local measurement=item.InlineMeasurement
				if not measurement then return false end
				BlockLayout.arrange(item.InlineBox,measurement.Available,x,y,work,true)
				return work()
			end
        end end
        for _,child in current.Children or {} do bindInline(child,alive) end
    end

function BlockLayout.arrange(box: any, available: number, x: number, y: number, alive: () -> boolean, prepared: boolean?, sizing: any?): (number, number, number)
	if not alive() then return 0, 0, 0 end
	if not prepared and not sizing and box.Node and box.Node.Kind=="Document" and box.VisualEffects then box.VisualEffects:PrepareComposites()end
	if prepared then
		local cached = DirtyLayout.get(box, available, x, y, sizing, alive)
		if cached then return cached.Height, cached.Width, cached.Bottom end
		local height, width, bottom = arrange(box, available, x, y, alive, sizing)
		if alive() then DirtyLayout.put(box, available, x, y, sizing, height, width, bottom) end
		return height, width, bottom
	end
	local function resolveSpacing(current: any, width: number)
		if not alive() then return end
		current.QuirksMode=box.QuirksMode
		current.LegacyLineHeight=box.LegacyLineHeight
		if current.Kind == "Words" then return end
		BoxSpacing.resolve(current.Style, width)
		local s = current.Style
		local _, br, _, bl = BorderGeometry.sizes(s)
		local edges = s.Padding[2] + s.Padding[4] + br + bl
		local content = if s.Width and not s.Width.Intrinsic then contentSize(s.Width, width, if s.BoxSizing == "border-box" then edges else 0)
			else math.max(0, width - s.Margin[2] - s.Margin[4] - edges)
		for _, child in current.Children do resolveSpacing(child, content) end
	end
	box.GridViewport={available,box.ViewportHeight or 0}
	QuirksLayout.bind(box,box.GridViewport[2])
    bindInline(box,alive)
    resolveSpacing(box, available)
	prepareMargins(box,nil,alive)
	local scrolls = {}
	ScrollLayout.reset(box, scrolls)
	if not alive() then return 0,0,0 end
	-- Each scrollbox can add at most two gutters, including overflow caused by positioned descendants.
	for _ = 1, #scrolls * 2 + 1 do
		DirtyLayout.rootPass(box)
		local height, width, bottom = arrange(box, available, x, y, alive, sizing)
		if not alive() then return 0, 0, 0 end
		if box.HasPositioning then
			local right, positionedBottom = PositionedLayout.arrange(box, available, BlockLayout.arrange, BlockLayout.naturalWidth, alive)
			if not alive() then return 0, 0, 0 end
			height, width, bottom = math.max(bottom, positionedBottom), math.max(width, right), math.max(bottom, positionedBottom)
		end
		if not ScrollLayout.settle(scrolls) then
			if not box.GeometryOnly then ScrollLayout.commit(scrolls)end
			if not box.GeometryOnly and box.HasOpacity then GroupOpacity.arrange(box,alive) end
			if not alive() then return 0,0,0 end
			if not box.GeometryOnly then BoxTransform.applyTree(box,nil,alive)end
			if not alive() then return 0,0,0 end
			if not sizing and box.VisualEffects then box.VisualEffects:UpdateComposites(box)end
			if not sizing and not box.GeometryOnly and box.PublishContentVisibility then box:PublishContentVisibility()end
			return height, width, bottom
		end
	end
	error("Scrollbar layout did not converge")
end

return BlockLayout
