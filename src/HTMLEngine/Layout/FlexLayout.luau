--!strict
--!optimize 2
local BorderGeometry = require(script.Parent.BorderGeometry)
-- Collect lines before flexing; size and align each line independently.
local AspectRatio = require(script.Parent.AspectRatio)
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)
local FlexLayout = {}
local FlexBalance=require(script.Parent.FlexBalance)
local DirtyLayout=require(script.Parent.DirtyLayout)
local LayoutProbe=require(script.Parent.LayoutProbe)
local BoxSpacing=require(script.Parent.BoxSpacing)
local BoxAlignment=require(script.Parent.BoxAlignment)
local NO_AUTO = table.freeze({false, false, false, false})

local function length(value: any, available: number, subtract: number): number
	return LengthExpression.resolve(value,available) - subtract
end

local function clamp(item: any, value: number): number
	return math.max(item.Min, math.min(item.Max, value))
end

-- CSS flex resolution: freeze constrained items, then redistribute the remainder.
function FlexLayout.resolve(items: any, available: number, alive: (() -> boolean)?)
	local hypothetical = 0
	for _, item in items do hypothetical += clamp(item, item.Base) + item.Extra end
	local grow = hypothetical < available
	local initial = available
	for _, item in items do
		if alive and not alive() then return end
		item.Factor = if grow then item.Grow else item.Shrink
		item.Target = clamp(item, item.Base)
		item.Frozen = item.Factor == 0 or (grow and item.Base > item.Target) or (not grow and item.Base < item.Target)
		initial -= (if item.Frozen then item.Target else item.Base) + item.Extra
	end
	-- Each iteration freezes at least one item; avoid an unbounded float loop.
	for _ = 1, #items do
		local remaining, factors, weights, count = available, 0, 0, 0
		for _, item in items do
			if alive and not alive() then return end
			remaining -= (if item.Frozen then item.Target else item.Base) + item.Extra
			if not item.Frozen then
				count += 1; factors += item.Factor
				item.Weight = if grow then item.Factor else item.Factor * math.max(0, item.Base)
				weights += item.Weight
			end
		end
		if count == 0 then break end
		if factors < 1 and math.abs(initial * factors) < math.abs(remaining) then remaining = initial * factors end
		local violation = 0
		for _, item in items do
			if alive and not alive() then return end
			if item.Frozen then continue end
			local change = if weights > 0 then remaining * item.Weight / weights else 0
			local target = item.Base + (if grow then change else -math.abs(change))
			item.Target = clamp(item, target)
			item.Violation = item.Target - target
			violation += item.Violation
		end
		for _, item in items do
			if alive and not alive() then return end
			if not item.Frozen and (math.abs(violation) < 1e-7 or (violation > 0 and item.Violation > 0)
				or (violation < 0 and item.Violation < 0)) then item.Frozen = true end
		end
	end
end

local function edges(child: any): (number, number)
	if child.Kind == "Words" then return 0, 0 end
	local s = child.Style
	local t, r, b, l = BorderGeometry.sizes(s)
	return s.Padding[2] + s.Padding[4] + r + l, s.Padding[1] + s.Padding[3] + t + b
end

-- Logical start/end follow the writing direction, while flex-start/flex-end
-- follow the possibly reversed flex axis. Resolve them before placing items.
local function legacyAlignment(mode: string, horizontal: boolean, direction: string?, reversed: boolean): string
	if mode=="normal" then return "stretch" end
	if mode=="start" or mode=="end" or mode=="self-start" or mode=="self-end" then
		local logicalReverse=horizontal and direction=="rtl"
		local atEnd=mode=="end" or mode=="self-end"
		return if atEnd~=(reversed~=logicalReverse) then "flex-end" else "flex-start"
	end
	if horizontal and (mode=="left" or mode=="right") then
		return if (mode=="right")~=reversed then "flex-end" else "flex-start"
	end
	return mode
end
local function alignment(mode: string,horizontal: boolean,container: any,subject: any,reversed: boolean): string
	-- Vertical container axis/sizing remains on its existing path. Fixed
	-- orthogonal subjects inside horizontal containers use physical self edges.
	if not BoxAlignment.horizontalContainer(container)then
		return legacyAlignment(mode,horizontal,if mode=='self-start'or mode=='self-end'then subject.Direction else container.Direction,reversed)
	end
	if mode=='normal'or mode=='stretch'then return 'stretch'end
	local physical=BoxAlignment.resolve(mode,horizontal,container,subject,reversed)
	if physical=='start'or physical=='end'then return if (physical=='end')~=reversed then 'flex-end'else 'flex-start'end
	return physical
end

local function distribution(mode: string, free: number, count: number, gap: number, safe: boolean?): (number, number)
	if count == 0 then return 0, gap end
	if mode == "flex-end" then return free, gap end
	if mode == "center" then return free / 2, gap end
	if mode == "space-between" and count > 1 then return 0, gap + math.max(0, free) / (count - 1) end
	if mode == "space-around" or mode == "space-evenly" then
		if free < 0 then return if safe then 0 else free / 2, gap end
		local step = free / (if mode == "space-around" then count else count + 1)
		return if mode == "space-around" then step / 2 else step, gap + step
	end
	return 0, gap
end

local function collectLines(items: any, limit: number, gap: number, wrap: boolean): any
	local lines, current = {}, nil
	for _, item in items do
		local size = clamp(item, item.Base) + item.Extra
		-- An oversized item still occupies a line. Zero-sized items can fit at its end.
		if not current or (wrap and current.Used + gap + size > limit and size + gap > 0) then
			current = {Items = {}, Used = 0, Cross = 0}
			table.insert(lines, current)
		end
		if #current.Items > 0 then current.Used += gap end
		table.insert(current.Items, item)
		current.Used += size
	end
	return lines
end

function FlexLayout.arrange(box: any, width: number, heightFor: any, natural: any, layout: any, alive: any, definiteHeight: number?,intrinsicWidth: any): (number, number, number)
	local style, items = box.Style, {}
	local row = style.FlexDirection ~= "column" and style.FlexDirection ~= "column-reverse"
	local mainReverse = style.FlexDirection == "row-reverse" or style.FlexDirection == "column-reverse"
	if row and style.Direction=="rtl" then mainReverse=not mainReverse end
	local wrap = style.FlexWrap ~= nil and style.FlexWrap ~= "nowrap"
	local reverse = style.FlexWrap == "wrap-reverse"
	if not row and style.Direction=="rtl" then reverse=not reverse end
	local mainStart, mainEnd = if row then 4 else 1, if row then 2 else 3
	if mainReverse then mainStart, mainEnd = mainEnd, mainStart end
	local crossStart, crossEnd = if row then 1 else 4, if row then 3 else 2
	local function usedGap(index,basis)
		local value=(style.Gap or {0,0})[index]
		return math.max(0,if type(value)=='table'then LengthExpression.resolve(value,basis or 0)else value)
	end
	-- An indefinite flex block axis keeps the cyclic percentage term at zero,
	-- including after its content establishes a used height.
	local gap = usedGap(if row then 2 else 1,if row then width else definiteHeight)
	local crossGap = usedGap(if row then 1 else 2,if row then definiteHeight else width)
	local crossAvailable=if not row and wrap then math.max(0,(width-crossGap*((style.FlexLineCount or 1)-1))/(style.FlexLineCount or 1)) else width
	local used, cross = 0, 0
	local paintOrder = true
	for sourceIndex, child in box.FlowChildren or box.Children do
		local anonymous = child.Kind == "Words"
		local s = child.Style
		-- Column auto cross sizes use the container's current physical width for
		-- percentage margins/padding, before measuring its content-box size.
		if not row and not anonymous and not s.Width then BoxSpacing.resolve(s,width)end
		local auto = if anonymous then NO_AUTO else s.MarginAuto or NO_AUTO
		local crossAuto = auto[crossStart] or auto[crossEnd]
		if anonymous then paintOrder = false end
		local align = if not anonymous and s.AlignSelf and s.AlignSelf ~= "auto" then s.AlignSelf else style.AlignItems
		local safety;align,safety=BoxAlignment.split(align)
		align=alignment(align,not row,style,s,reverse)
		local horizontal, vertical = edges(child)
		local m = if anonymous then {0, 0, 0, 0} else child.LayoutMargin
		local hint: any = {FlexItem = true}
		if anonymous and not row and not wrap and align == "stretch" then hint.ContentWidth = width
		elseif anonymous or (not row and not s.Width and (wrap or crossAuto or align ~= "stretch")) then
			if not row and not anonymous then
				-- CSS Flexbox 9.4 treats an automatic hypothetical cross size as
				-- fit-content. Min/max constraints are applied by the same child
				-- arrange path as an explicitly authored intrinsic width.
				hint.ContentWidth=intrinsicWidth(child,crossAvailable,alive,"fit-content",definiteHeight)
			else
				local maximum=natural(child,crossAvailable,alive)
				if not alive()then return 0,0,0 end
				local intrinsic=maximum
				if not row then
					local minimum=natural(child,crossAvailable,alive,true)
					if not alive()then return 0,0,0 end
					intrinsic=math.max(minimum,math.min(maximum,crossAvailable))
				end
				hint.ContentWidth=math.max(0,intrinsic-horizontal-m[2]-m[4])
			end
			if not alive() then return 0, 0, 0 end
		end
		if not anonymous and not row then hint.MainAxis, hint.IgnoreMainLimits = "column", true end
		local h, extentWidth, extentHeight = 0, 0, 0
		local probe
		if not row then
			probe=DirtyLayout.measure(child,"flex-height",width,hint,function()
				local ph,pw,pb=LayoutProbe.arrange(child,width,layout,alive,hint)
				return {Height=ph,ExtentWidth=pw,ExtentHeight=pb,Width=if anonymous then hint.ContentWidth else child.OuterWidth+m[2]+m[4]}
			end,alive)
			h,extentWidth,extentHeight=probe.Height,probe.ExtentWidth,probe.ExtentHeight
		end
		if not alive() then return 0, 0, 0 end
		local w = if anonymous then hint.ContentWidth elseif row then 0 else probe.Width
		local edge = if row then horizontal else vertical
		local extra = edge + (if row then m[2] + m[4] else m[1] + m[3])
		local subtract = if not anonymous and s.BoxSizing == "border-box" then edge else 0
		local available = if row then width else definiteHeight
		local preferred = if anonymous then nil elseif row then s.Width else s.Height
		local basis = if anonymous then "content" else s.FlexBasis or "auto"
		if basis == "auto" then basis = preferred or "content" end
		local function intrinsic(value)
			return if row then intrinsicWidth(child,width,alive,value.Intrinsic,definiteHeight)else math.max(0,h-extra)
		end
		local base
		if type(basis)=='table'and basis.Intrinsic then base=intrinsic(basis)
		elseif type(basis) == "table" and (not basis.Percent or available ~= nil) then
			-- The flex base ignores limits, including the content-box zero floor.
			base = length(basis, available or 0, subtract)
		elseif row then
			base = natural(child, width, alive, false, true) - extra
		else
			base = h - extra
			local ratio = if not anonymous then AspectRatio.resolve(s) else nil
			if ratio and s.Width and not s.Width.Intrinsic then
				local widthEdge = if s.BoxSizing == "border-box" then horizontal else 0
				base = AspectRatio.height(math.max(0, length(s.Width, width, widthEdge)), ratio, widthEdge, subtract)
			end
		end
		local minValue = if anonymous then nil elseif row then s.MinWidth else s.MinHeight
		local maxValue = if anonymous then nil elseif row then s.MaxWidth else s.MaxHeight
		local maximum = if maxValue then(if maxValue.Intrinsic then intrinsic(maxValue)else math.max(0,length(maxValue,available or 0,subtract)))else math.huge
		local minimum = 0
		if minValue then minimum=if minValue.Intrinsic then intrinsic(minValue)else math.max(0,length(minValue,available or 0,subtract))
		elseif anonymous or s.Overflow ~= "hidden" then
			minimum = if row then math.max(0, natural(child, width, alive, true, true) - extra) else math.max(0, h - extra)
			local ratio = if not anonymous then AspectRatio.resolve(s) else nil
			local crossSize = if row then s.Height else s.Width
			if ratio and crossSize and not crossSize.Intrinsic and not anonymous then
				local crossEdge = if s.BoxSizing == "border-box" then (if row then vertical else horizontal) else 0
				local crossLength = math.max(0, length(crossSize, if row then 0 else width, crossEdge))
				local transferred = if row then AspectRatio.width(crossLength, ratio, subtract, crossEdge)
					else AspectRatio.height(crossLength, ratio, crossEdge, subtract)
				minimum = math.max(minimum, transferred)
			end
			if preferred then minimum=math.min(minimum,if preferred.Intrinsic then intrinsic(preferred)else math.max(0,length(preferred,available or 0,subtract)))end
			minimum = math.min(minimum, maximum)
		end
		if not alive() then return 0, 0, 0 end
		local item = {Box = child, Width = w, Height = h, Hint = hint, Margin = m, VerticalEdges = vertical, HorizontalEdges = horizontal,
			Align = align, Safety=safety, Order = if anonymous then 0 else s.Order or 0, SourceIndex = sourceIndex,
			Auto = auto, CrossAuto = crossAuto,
			ExtentWidth = extentWidth, ExtentHeight = extentHeight, Base = base, Extra = extra, Min = minimum, Max = maximum,
			Grow = if anonymous then 0 else s.FlexGrow or 0, Shrink = if anonymous then 1 else s.FlexShrink or 1}
		table.insert(items, item)
		used += clamp(item, base) + extra
		cross = math.max(cross, if row then h else w)
	end
	-- Stable visual order, without changing DOM children or render-tree ownership.
	table.sort(items, function(a, b)
		return if a.Order == b.Order then a.SourceIndex < b.SourceIndex else a.Order < b.Order
	end)
	if paintOrder then
		for index, item in items do
			if item.Box.Gui.ZIndex ~= index then item.Box.Gui.ZIndex = index end
		end
	end
	used += gap * math.max(0, #items - 1)
	local height = heightFor(if row then cross else used)
	local mainSize = if row then width else height
	local lines = if wrap and style.FlexBalance then FlexBalance.collect(items,mainSize,gap,style.FlexLineCount or 1,alive) else collectLines(items, mainSize, gap, wrap)
	if not alive() then return 0,0,0 end
	box.FlexLineCount=#lines
	if not row and wrap and style.FlexBalance and definiteHeight==nil then
		local balancedMain=0
		for _,line in lines do balancedMain=math.max(balancedMain,line.Used) end
		height=heightFor(balancedMain);mainSize=height
	end
	cross = crossGap * math.max(0, #lines - 1)
	for _, line in lines do
		FlexLayout.resolve(line.Items, mainSize - gap * math.max(0, #line.Items - 1),alive)
		line.Used = gap * math.max(0, #line.Items - 1)
		for _, item in line.Items do
			local child, hint = item.Box, item.Hint
			if child.Kind == "Words" then
				if row then hint.ContentWidth = item.Target end
			else
				hint.MainAxis, hint.MainSize, hint.IgnoreMainLimits = if row then "row" else "column", item.Target, nil
			end
			item.Height, item.ExtentWidth, item.ExtentHeight = LayoutProbe.arrange(child, width, layout, alive, hint)
			if not alive() then return 0, 0, 0 end
			item.Width = if child.Kind == "Words" then hint.ContentWidth else child.OuterWidth + item.Margin[2] + item.Margin[4]
			line.Used += if row then item.Width else item.Height
			line.Cross = math.max(line.Cross, if row then item.Height else item.Width)
			if row and item.Align == "baseline" and not item.CrossAuto then
				-- Baselines include the top margin; empty boxes use their bottom border edge.
				local baseline = item.Margin[1] + (child.FirstBaseline or child.OuterHeight or item.Height)
				item.Baseline = if reverse then item.Height - baseline else baseline
				line.Before = math.max(line.Before or -math.huge, item.Baseline)
				line.After = math.max(line.After or -math.huge, item.Height - item.Baseline)
			end
		end
		if line.Before then line.Cross = math.max(line.Cross, line.Before + line.After) end
		cross += line.Cross
	end
	if row then height = heightFor(cross) end
	local crossSize = if row then height else width
	local lineOffset, lineGap = 0, crossGap
	if not wrap and #lines > 0 then lines[1].Cross = crossSize
	elseif wrap then
		local free = crossSize - cross
		local mode,safety=BoxAlignment.split(style.AlignContent or "stretch")
		local align = alignment(BoxAlignment.overflow(mode,safety,free),not row,style,style,reverse)
		if align == "stretch" and free > 0 and #lines > 0 then
			for _, line in lines do line.Cross += free / #lines end
		else lineOffset, lineGap = distribution(align, free, #lines, crossGap, true) end
	end
	local right, bottom = width, height
	local bt, _, _, bl = BorderGeometry.sizes(style)
	local left, top = bl + style.Padding[4] + (box.ScrollLeadingX or 0), box.ContentTop or bt + style.Padding[1]
	for _, child in box.Children do
		if child.Kind ~= "Words" and (child.Style.Position == "absolute" or child.Style.Position=="fixed") then child.StaticX, child.StaticY = left, top end
	end
	for lineIndex, line in lines do
		local free, autoCount = mainSize - line.Used, 0
		for _, item in line.Items do
			autoCount += (if item.Auto[mainStart] then 1 else 0) + (if item.Auto[mainEnd] then 1 else 0)
		end
		local autoShare = if autoCount > 0 then math.max(0, free) / autoCount else 0
		local mode,safety=BoxAlignment.split(style.JustifyContent)
		local justify=alignment(BoxAlignment.overflow(mode,safety,if autoShare>0 then 0 else free),row,style,style,mainReverse)
		local offset, between = distribution(justify, if autoShare > 0 then 0 else free, #line.Items, gap)
		for _, item in line.Items do
			local child, hint = item.Box, item.Hint
			local stretch = item.Align == "stretch" and not item.CrossAuto and child.Kind ~= "Words"
				and (if row then not child.Style.Height else not child.Style.Width)
			if stretch then
				if row then hint.ContentHeight = math.max(0, line.Cross - item.Margin[1] - item.Margin[3] - item.VerticalEdges)
				else hint.ContentWidth = math.max(0, line.Cross - item.Margin[2] - item.Margin[4] - item.HorizontalEdges) end
				item.Height, item.ExtentWidth, item.ExtentHeight = LayoutProbe.arrange(child, width, layout, alive, hint)
				if not alive() then return 0, 0, 0 end
				item.Width = child.OuterWidth + item.Margin[2] + item.Margin[4]
			end
			local itemCross = if row then item.Height else item.Width
			local extra = line.Cross - itemCross
			local usedAlign=BoxAlignment.overflow(item.Align,item.Safety,extra)
			local across = if usedAlign == "center" then extra / 2 elseif usedAlign == "flex-end" then extra else 0
			if item.Baseline then across = line.Before - item.Baseline end
			if item.CrossAuto then
				local count = (if item.Auto[crossStart] then 1 else 0) + (if item.Auto[crossEnd] then 1 else 0)
				local physical = if extra>0 then(if item.Auto[crossStart]then extra/count else 0)
					elseif BoxAlignment.horizontalContainer(style)and BoxAlignment.startAtEnd(not row,style)then extra else 0
				-- Flex 9.6 overflow uses the container's block/inline start;
				-- subject self alignment and wrap reversal do not choose that side.
				-- Auto margins remain physical, even when wrap-reverse flips the cross axis.
				across = if reverse then extra - physical else physical
			end
			across += lineOffset
			if reverse then across = crossSize - across - itemCross end
			offset += if item.Auto[mainStart] then autoShare else 0
			local main = if mainReverse then mainSize - offset - (if row then item.Width else item.Height) else offset
			local x, y = if row then main else across, if row then across else main
			local extentWidth, extentHeight = item.ExtentWidth, item.ExtentHeight
			if child.Kind == "Words" then
				local ignored
				ignored, extentWidth, extentHeight = layout(child, width, left + x, top + y, alive, true, hint)
			else
				-- Moving a block moves its descendants; no recursive positioning pass.
				local position = UDim2.fromOffset(left + x + item.Margin[4], top + y + item.Margin[1])
				local moved=child.LayoutX~=left+x+item.Margin[4] or child.LayoutY~=top+y+item.Margin[1]
				child.LayoutX, child.LayoutY = left + x + item.Margin[4], top + y + item.Margin[1]
				child.PaintX,child.PaintY=child.LayoutX,child.LayoutY
				if moved and not child.OpacityGroup then child.TransformBaseX,child.TransformBaseY=child.LayoutX,child.LayoutY end
				if child.Gui.Position ~= position then child.Gui.Position = position end
			end
			if not alive() then return 0, 0, 0 end
			if box.FirstBaseline == nil and child.FirstBaseline ~= nil then box.FirstBaseline = top + y + item.Margin[1] + child.FirstBaseline end
			if lineIndex == 1 and item.Baseline and not line.ExportedBaseline then
				-- A nested Flex box exposes the first line's participating baseline group.
				box.FirstBaseline = top + y + item.Margin[1] + (child.FirstBaseline or child.OuterHeight or item.Height)
				line.ExportedBaseline = true
			end
			right, bottom = math.max(right, x + extentWidth), math.max(bottom, y + extentHeight)
			offset += (if row then item.Width else item.Height) + between + (if item.Auto[mainEnd] then autoShare else 0)
		end
		lineOffset += line.Cross + lineGap
	end
	return height, right, bottom
end

return FlexLayout
