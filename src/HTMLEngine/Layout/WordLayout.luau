--!strict
local TextMeasure = require(script.Parent.TextMeasure)
local Profiles = require(script.Parent.FontProfiles)
local FontMetrics = require(script.Parent.FontMetrics)
local WordFlow = require(script.Parent.WordFlow)
local VerticalText = require(script.Parent.VerticalText)
local TextEmphasis=require(script.Parent.TextEmphasis)
local InlineFragments = require(script.Parent.InlineFragments)
local TextDecoration = require(script.Parent.TextDecoration)
local SkipInk = require(script.Parent.SkipInk)
local LetterSpacing = require(script.Parent.LetterSpacing)
local ImageLayout = require(script.Parent.ImageLayout)
local TextShadows = require(script.Parent.Parent.Rendering.TextShadows)
local ImageBox = require(script.Parent.Parent.Rendering.ImageBox)
local BoxTransform = require(script.Parent.Parent.Rendering.BoxTransform)
local MediaBox = require(script.Parent.Parent.Rendering.MediaBox)
local IFrameBox = require(script.Parent.Parent.Rendering.IFrameBox)
local OverflowWrap = require(script.Parent.OverflowWrap)
local TextOverflow = require(script.Parent.TextOverflow)
local WhiteSpace=require(script.Parent.WhiteSpace)
local TextIndent=require(script.Parent.Parent.CSS.TextIndent)
local BidiPaint=require(script.Parent.BidiPaint)
local WritingMode=require(script.Parent.Parent.CSS.WritingMode)
local ControlView = require(script.Parent.Parent.Controls.View)
local ElementNames = require(script.Parent.Parent.DOM.ElementNames)
local WordLayout = {}
local ListMarker = require(script.Parent.ListMarker)
local paint
local DEFAULT_TAB_SIZE = table.freeze({Kind = "number", Value = 8})
local function htmlImage(value: any): boolean
	local node=value and value.Node
	return value~=nil and value.Kind=='Image'and ElementNames.html(node,'img')
end

local function write(gui: GuiObject, key: string, value: any)
	if (gui :: any)[key] ~= value then (gui :: any)[key] = value end
end

function WordLayout.arrange(run: any, width: number, x: number, y: number, alive: () -> boolean, lineBounds: any?): (number, number)
	local hasFloats=false
	for _, item in run.Items do
		if item.Kind=='Float'then hasFloats=true;continue end
		if #(item.Style and item.Style.Decorations or {}) > 0 or #(item.SpaceStyle and item.SpaceStyle.Decorations or {}) > 0 then run.Decorated = true end
	end
	if not run.MeasureOnly then run.PaintState = nil end
	local resolveFont = run.ResolveFont or Profiles.face
	-- Reuse pure font-profile calculations within this layout pass only.
	-- Native text bounds remain individual, and the next reflow starts fresh.
	local metricsByStyle = {}
	local function metricsFor(style: any): any
		if not metricsByStyle[style] then metricsByStyle[style] = FontMetrics.resolve(style) end
		return metricsByStyle[style]
	end
	local mode=run.Style.WritingMode
	local vertical = WritingMode.vertical(run.Style)
	local sideways=mode=='sideways-rl'or mode=='sideways-lr'
	local runMetrics = metricsFor(run.Style)
	local strut = FontMetrics.extents(run.Style, runMetrics)
	-- Absence of a strut must also preserve negative half-leading. A zero
	-- strut would clamp negative ascents/descents and enlarge short lines.
	if run.LegacyLineHeight then strut={Ascent=-math.huge,Descent=-math.huge}end
	if vertical then strut.Ascent, strut.Descent = (strut.Ascent + strut.Descent) / 2, (strut.Ascent + strut.Descent) / 2 end
	local flowWidth=if vertical then math.max(0,run.HeightBasis or width)else math.max(0,width)
	local fragmentItems=run.Items
	if hasFloats then
		fragmentItems={}
		for _,item in run.Items do if item.Kind~='Float'then table.insert(fragmentItems,item)end end
	end
	InlineFragments.prepare(fragmentItems,flowWidth,run.Style)
	local previousSpacing, previous = 0, nil
	for index, item in run.Items do
		if not alive() then return 0, 0 end
		if item.Kind=='Float'then hasFloats=true;continue end
		if item.Kind == "Break" then
			previousSpacing, previous = 0, nil
			item.EmptyLineExtents=nil
			if item.Style then
				local extents = FontMetrics.extents(item.Style, metricsFor(item.Style))
				local shift = item.Style.InlineShift or 0
				item.Ascent, item.Descent = extents.Ascent - shift, extents.Descent + shift
				if run.LegacyLineHeight then item.EmptyLineExtents={Ascent=item.Ascent,Descent=item.Descent};item.Ascent,item.Descent=0,0 end
			end
			continue
		end
		local style = item.Style or run.Style
		local metrics = if item.Control then ControlView.metrics(item) else metricsFor(style)
		local weight = style.FontWeight or 400
		local fontStyle = style.FontStyle or "normal"
		local size, font = metrics.TextSize, resolveFont(style.Font, weight, fontStyle)
		local spaceCharacter=if item.Kind=='Space'and item.Text:find(' ',1,true)and WhiteSpace.expandable(style)and(style.TextTransform or ''):find('full-width',1,true)then '　'else ' '
		local nativeText=if item.Kind=='Space'then spaceCharacter else BidiPaint.text(item)
		-- Only this word retains its own measurement. Width changes only rewrap.
		if item.Kind == "Marker" then
			if not ListMarker.arrange(item.Marker, style, 0, 0, alive) then return 0, 0 end
			item.Width, item.Height = item.Marker.Width, metrics.TextSize
		elseif item.Kind == "Image" then
			if item.Control and not ControlView.measure(item, TextMeasure.measure, alive) then return 0, 0 end
			if item.TextFallback and (item.MeasuredText ~= item.Alt or item.MeasuredSize ~= size or item.MeasuredFont ~= style.Font
				or item.MeasuredWeight ~= weight or item.MeasuredStyle ~= fontStyle) then
				local bounds, message = TextMeasure.measure(item.Alt, font, size, 0)
				if not alive() then return 0, 0 end
				assert(bounds, "Image alt measurement failed: " .. tostring(message))
				item.AltWidth,item.AltInkHeight=bounds.X,bounds.Y
				item.MeasuredText, item.MeasuredSize, item.MeasuredFont = item.Alt, size, style.Font
				item.MeasuredWeight, item.MeasuredStyle = weight, fontStyle
			end
			if item.TextFallback then local extents=FontMetrics.extents(style,metrics,item.AltInkHeight);item.AltHeight=extents.Ascent+extents.Descent end
			if item.InlineBox then
                item.Width,item.Height,item.GridBaseline=item.MeasureGrid(math.max(0,width),run.MeasureOnly and width==0,alive)
                if not alive()then return 0,0 end
                local m=item.Style.Margin;item.Width+=m[2]+m[4];item.Height+=m[1]+m[3]
            else item.Width, item.Height = ImageLayout.size(item, math.max(0, width),run.HeightBasis,if run.QuirksMode then run.QuirksHeightBasis else nil) end
		elseif item.EmptyInline then
			item.Width,item.Height,item.NativeWidth,item.NativeHeight=0,size,0,size
		elseif item.MeasuredText ~= item.Text or item.MeasuredSize ~= size or item.MeasuredFont ~= style.Font
			or item.MeasuredWeight ~= weight or item.MeasuredStyle ~= fontStyle or item.MeasuredBidiText~=nativeText
			or (item.Glyphs and item.MeasuredTabular ~= (style.TabularNums == true)) or(item.Kind=='Space'and item.MeasuredSpaceCharacter~=spaceCharacter)then
			if item.Glyphs then
				if not LetterSpacing.measure(item,font,size,function(text,face,textSize,wrapWidth)return TextMeasure.measure(BidiPaint.text(item,text),face,textSize,wrapWidth)end,alive)then return 0,0 end
			else
				local bounds, message = TextMeasure.measure(nativeText, font, size, 0)
				if not alive() then return 0, 0 end
				assert(bounds, "Word measurement failed: " .. tostring(message))
				local tabMinimum = 0
				if item.Kind == "Space" and item.Text:find("\t", 1, true) then
					local zero, zeroMessage = TextMeasure.measure("0", font, size, 0)
					if not alive() then return 0, 0 end
					assert(zero, "Tab measurement failed: " .. tostring(zeroMessage))
					-- CSS requires at least 0.5ch before accepting the next tab stop.
					tabMinimum = zero.X / 2
				end
				item.Width, item.Height = bounds.X, math.max(size, bounds.Y)
				if item.Kind == "Space" then
					item.NativeSpaceWidth, item.TabMinimum = bounds.X, tabMinimum
				end
			end
			if not item.Glyphs then item.NativeWidth, item.NativeHeight = item.Width, item.Height end
			item.MeasuredText, item.MeasuredSize, item.MeasuredFont = item.Text, size, style.Font
			item.MeasuredWeight = weight
			item.MeasuredStyle = fontStyle
			item.MeasuredBidiText=nativeText
			-- Store false explicitly so pure measurement publication can clear a
			-- formerly tabular cache key without dropping the field from pairs.
			item.MeasuredTabular=if item.Glyphs then style.TabularNums == true else nil
			if item.Kind=='Space'then item.MeasuredSpaceCharacter=spaceCharacter end
			item.SkipInkCuts = nil
		end
		local glyphBounds=item.NativeGlyphBounds
		if item.Glyphs and glyphBounds and glyphBounds.Text==item.Text and glyphBounds.Font==font and glyphBounds.Size==size and glyphBounds.Tabular==style.TabularNums
			and glyphBounds.Family==style.Font and glyphBounds.Weight==weight and glyphBounds.Variant==fontStyle and glyphBounds.Bidi==nativeText then
			for i,glyph in item.Glyphs do local bounds=glyphBounds.Bounds[i];glyph.Width,glyph.Height=bounds.Width,bounds.Height end
		end
		if item.NativeWidth then item.Width, item.Height = item.NativeWidth, item.NativeHeight end
		item.VerticalAdvance = nil
		local spacing = if item.Kind == "Image"or item.EmptyInline then 0 else style.LetterSpacing or 0
		if item.Kind == "Space" then
			item.SpaceUnit = item.NativeSpaceWidth + (style.WordSpacing or 0) + spacing
			item.TabWidth = 0
			if item.Text:find("\t", 1, true) then
				local tabSize = style.TabSize or DEFAULT_TAB_SIZE
				if tabSize.Kind == "px" then item.TabWidth = tabSize.Value
				elseif tabSize.Value > 0 then
					-- Numeric tab stops use the nearest block's font and spacing,
					-- even when the tab itself is inside a differently styled span.
					local base = run.Style
					local baseSize = runMetrics.TextSize
					local baseWeight, baseStyle = base.FontWeight or 400, base.FontStyle or "normal"
					local nativeWidth = item.NativeSpaceWidth
					if base.Font ~= style.Font or baseSize ~= size or baseWeight ~= weight or baseStyle ~= fontStyle or spaceCharacter~=' 'then
						if item.TabBaseFont ~= base.Font or item.TabBaseSize ~= baseSize
							or item.TabBaseWeight ~= baseWeight or item.TabBaseStyle ~= baseStyle then
							local bounds, message = TextMeasure.measure(" ", resolveFont(base.Font, baseWeight, baseStyle), baseSize, 0)
							if not alive() then return 0, 0 end
							assert(bounds, "Tab base measurement failed: " .. tostring(message))
							item.TabBaseWidth = bounds.X
							item.TabBaseFont, item.TabBaseSize = base.Font, baseSize
							item.TabBaseWeight, item.TabBaseStyle = baseWeight, baseStyle
						end
						nativeWidth = item.TabBaseWidth
					end
					item.TabWidth = math.max(0, nativeWidth + (base.WordSpacing or 0) + (base.LetterSpacing or 0)) * tabSize.Value
				end
			end
			local following = run.Items[index + 1]
			item.StartTracking = if previous and previous.Kind == "Word" then previousSpacing / 2 else 0
			item.EndTracking = if following and following.Kind == "Word" then ((following.Style or run.Style).LetterSpacing or 0) / 2 else 0
		end
		if item.Glyphs then LetterSpacing.arrange(item, spacing, style.WordSpacing or 0) end
		item.SpaceWidth = 0
		if item.AutoSpaceBefore then
			item.SpaceWidth=math.max(1,(metrics.TextSize or style.FontSize or 16)/8)
		elseif item.SpaceBefore then
			local spaceStyle = item.SpaceStyle or style
			local spaceSize = metricsFor(spaceStyle).TextSize
			local spaceWeight = spaceStyle.FontWeight or 400
			local spaceFontStyle = spaceStyle.FontStyle or "normal"
			if item.MeasuredSpaceSize ~= spaceSize or item.MeasuredSpaceFont ~= spaceStyle.Font
				or item.MeasuredSpaceWeight ~= spaceWeight or item.MeasuredSpaceStyle ~= spaceFontStyle then
				local space, message = TextMeasure.measure(" ", resolveFont(spaceStyle.Font, spaceWeight, spaceFontStyle), spaceSize, 0)
				if not alive() then return 0, 0 end
				assert(space, "Space measurement failed: " .. tostring(message))
				item.MeasuredSpaceWidth,item.MeasuredSpaceHeight = space.X,space.Y
				item.MeasuredSpaceSize, item.MeasuredSpaceFont = spaceSize, spaceStyle.Font
				item.MeasuredSpaceWeight = spaceWeight
				item.MeasuredSpaceStyle = spaceFontStyle
			end
			-- CSS spacing adds literal pixels to the measured font space; it is
			-- independent of font-size correction and never changes the cached bound.
			item.SpaceWidth = item.MeasuredSpaceWidth + (spaceStyle.WordSpacing or 0)
				+ (spaceStyle.LetterSpacing or 0) + (previousSpacing + spacing) / 2
		end
		if vertical and not sideways and (style.TextOrientation == "upright"or style.TextOrientation=='mixed'and item.VerticalOrientation=='upright') and (item.Kind == "Word" or item.Kind == "Space") then
			-- Native font bounds supply the upright em cell (including fallback fonts).
			local cell = math.max(size, item.NativeHeight or item.Height)
			VerticalText.measure(item, cell,size)
			if item.SpaceBefore then item.SpaceWidth = cell + (style.WordSpacing or 0) + spacing + (previousSpacing + spacing) / 2 end
			if item.Kind == "Space" then item.SpaceUnit = cell + (style.WordSpacing or 0) + spacing end
		end
		local boundaryStyle = if item.AutoSpaceBefore then style elseif item.SpaceBefore then item.SpaceStyle or style elseif previous and previous.Kind == "Space" then previous.Style else nil
		if item.Kind=='Space'and previous and previous.Kind=='Space'and WhiteSpace.collapse(style)=='break-spaces'then boundaryStyle=style end
		if item.SoftBefore or style.WordBreak == "break-all" or (previous and previous.Kind == "Marker") then boundaryStyle = style end
		if not boundaryStyle and (item.Kind == "Image" or (previous and previous.Kind == "Image")) then boundaryStyle = style end
		item.WrapBefore=boundaryStyle~=nil and WhiteSpace.wraps(boundaryStyle)
			and(item.Kind~='Space'or(previous~=nil and previous.Kind=='Space'and WhiteSpace.collapse(boundaryStyle)=='break-spaces'))
		if item.BidiJoined and style.WordBreak~='break-all'and style.LineBreak~='anywhere'then item.WrapBefore=false end
		if run.QuirksNoImageWrap and not item.SpaceBefore and not item.AutoSpaceBefore then
			if htmlImage(item)or htmlImage(previous)then item.WrapBefore=false end
		end
		item.Joined = item.Kind == "Word" and previous ~= nil and previous.Kind == "Word" and not item.SpaceBefore and not item.AutoSpaceBefore
		if item.Joined then item.SpaceWidth = (previousSpacing + spacing) / 2 end
		previousSpacing, previous = spacing, item
		local extents = FontMetrics.extents(style, metrics, item.Height)
		if item.EmptyInline and run.LegacyLineHeight then
			local fragment=style.InlineFragment
			local borders=fragment and fragment.Borders or style.BorderSizes or{0,0,0,0}
			local padding=fragment and fragment.Padding or style.Padding or{0,0,0,0}
			local a,b=if vertical then 1 else 2,if vertical then 3 else 4
			if (borders[a]or 0)==0 and(borders[b]or 0)==0 and(padding[a]or 0)==0 and(padding[b]or 0)==0 then extents={Ascent=0,Descent=0}end
		end
		item.LineAlign,item.AlignmentHeight,item.LineAlignOffset=nil,nil,nil
		if item.Kind~='Image'and(style.VerticalAlign=='top'or style.VerticalAlign=='bottom')then
			item.LineAlign=style.VerticalAlign;item.AlignmentHeight=extents.Ascent+extents.Descent;item.LineAlignOffset=extents.Ascent-metrics.Baseline
		end
		item.BaselineShift = style.InlineShift or 0
		item.Baseline, item.Ascent, item.Descent = metrics.Baseline, extents.Ascent - item.BaselineShift, extents.Descent + item.BaselineShift
		if vertical and item.Kind ~= "Image" and item.Kind ~= "Marker" then
			local crossHeight = extents.Ascent + extents.Descent
			item.Baseline, item.Ascent, item.Descent = item.Height / 2, crossHeight / 2, crossHeight / 2
		end
		if item.Kind == "Image" then
			if item.InlineBox then
                -- Atomic inline boxes use their own content baseline, but their
                -- margin box follows the same vertical-align rules as images.
                local baseline=(item.GridBaseline or item.InlineBox.OuterHeight)+item.Style.Margin[1]
                ImageLayout.align(item,metricsFor(item.ParentStyle or run.Style),metrics,baseline)
            else ImageLayout.align(item, metricsFor(item.ParentStyle or run.Style), metrics) end
			if item.Control then ControlView.align(item) end
		end
		item.FontFace, item.TextSize = font, size
		if not TextEmphasis.measure(item,font,size,TextMeasure.measure,alive)then return 0,0 end
		TextEmphasis.extents(item,vertical)
		item.SkipInkTop, item.SkipInkBottom = metrics.XHeight, metrics.Bottom
		if not run.MeasureOnly and item.Kind == "Word"and not item.EmptyInline and not SkipInk.measure(item, style, TextMeasure.measure, alive) then return 0, 0 end
	end
	local contentWidth = math.max(0, width)
	local indent=TextIndent.flow(run.Style.TextIndent,flowWidth,run.IndentFirstLine~=false,
		run.Style.Direction=='rtl',run.IntrinsicIndent)
	local split,hyphenProbe = OverflowWrap.splitter(run, TextMeasure.measure, alive)
	local height, farRight, firstBaseline, displayed
	local function alignment(value: string): string
		if value=="justify" and run.Style.TextJustify=="none" then return "left" end
		if run.Style.UnicodeBidi=='plaintext'and(value=='start'or value=='end')then return value end
		-- CSS Text3 8.3: line-box alignment uses computed direction, while
		-- upright's LTR used direction affects the order of its characters.
		local rtl = run.Style.Direction == "rtl"
		if value == "start" then return if rtl then "right" else "left" end
		if value == "end" then return if rtl then "left" else "right" end
		return value
	end
	if split then
		local ok
		ok, height, farRight, firstBaseline, displayed = pcall(WordFlow.arrange, run.Items, flowWidth, strut, alignment(run.Style.TextAlign), indent, alignment(run.Style.TextAlignLast), split,lineBounds,alive,hyphenProbe,run.PlaceFloat)
		if not alive() then return 0, 0 end
		if not ok then error(height) end
	else
		height, farRight, firstBaseline, displayed = WordFlow.arrange(run.Items, flowWidth, strut, alignment(run.Style.TextAlign), indent, alignment(run.Style.TextAlignLast),nil,lineBounds,alive,nil,run.PlaceFloat)
	end
	if hasFloats then
		local visible={}
		for _,item in displayed do if item.Kind~='Float'then table.insert(visible,item)end end
		displayed=visible
	end
	BidiPaint.order(displayed)
	local maxLines=run.Style.MaxLines
	local trim,edges=run.Style.TextBoxTrim,run.Style.TextBoxEdge
	if not vertical and trim and trim~='none'and #displayed>0 then
		local top,bottom=0,0;local leading=(strut.Ascent+strut.Descent-runMetrics.TextSize)/2
		if trim=='trim-start'or trim=='trim-both'then
			top=math.max(0,leading+(if edges and edges.Start=='cap'then runMetrics.Top or 0 elseif edges and edges.Start=='ex'then runMetrics.XHeight else 0))
		end
		if trim=='trim-end'or trim=='trim-both'then bottom=math.max(0,leading+(if edges and edges.End=='alphabetic'then runMetrics.TextSize-runMetrics.Baseline else 0))end
		top=math.min(top,height);bottom=math.min(bottom,height-top)
		for _,item in displayed do if item.Y then item.Y-=top end;if item.LineBaseline then item.LineBaseline-=top end end
		height-=top+bottom;firstBaseline=if firstBaseline then firstBaseline-top else nil
	end
	if maxLines then
		local clamped,bottom=false,0
		for _,item in displayed do
			if item.Kind~="Break" and item.LineIndex then
				if item.LineIndex>maxLines then clamped=true else bottom=math.max(bottom,(item.Y or 0)+(item.Height or 0)) end
			end
		end
		if clamped then height=bottom end
	end
	-- Logical inline bounds also retain permitted start-side overflow. The
	-- existing farRight alone cannot report a word hanging before RTL's origin.
	local overflowStart,overflowEnd=0,0
	for index,item in displayed do
		if index%32==0 and not alive()then return 0,0 end
		if item.Kind~='Break'and item.X~=nil and(not maxLines or not item.LineIndex or item.LineIndex<=maxLines)then
			overflowStart=math.min(overflowStart,item.X)
			overflowEnd=math.max(overflowEnd,item.X+(item.Width or 0))
		end
	end
	run.FlowOverflowStart,run.FlowOverflowEnd=overflowStart,overflowEnd
	if vertical then
		height, farRight = farRight, if run.MeasureOnly then height elseif mode == "vertical-lr"or mode=='sideways-lr' then math.max(contentWidth, height) else contentWidth
	end
	if run.MeasureOnly then run.FirstBaseline=firstBaseline;return height, farRight end
	run.FirstBaseline = firstBaseline
	local saved = table.clone(displayed)
	if run.Style.TextOverflow == "ellipsis" then
		-- Intrinsic width probes reuse source items and change their line coordinates.
		-- Keep paint geometry separate, but retain the original owner for fragment pools.
		for index, item in saved do
			local snapshot = table.clone(item)
			snapshot.PaintOwner = item.WrapOwner or item
			saved[index] = snapshot
		end
	end
	local state = {Items = saved, Width = contentWidth, FlowWidth = flowWidth, X = x, Y = y,
		Metrics = runMetrics, Font = resolveFont(run.Style.Font, run.Style.FontWeight or 400, run.Style.FontStyle or "normal"), Split = split ~= nil, ConstrainedLines = lineBounds ~= nil,HasFloats=hasFloats}
	if not paint(run, state, alive) then return 0, 0 end
	run.FlowPaintState = state
	-- Anonymous runs share their parent's GUI. Move their retained line paint
	-- when preceding content grows/shrinks, without measuring or wrapping again.
	run.TranslateLayout = if not state.ConstrainedLines then function(nextX: number,nextY: number,work: () -> boolean): boolean
		state.X,state.Y=nextX,nextY
		run.LayoutX,run.LayoutY=nextX,nextY
		return paint(run,state,work)
	end else nil
	run.RepaintStyles = function() return WordLayout.paintFragments(run, alive) end
	run.RepaintDecorationColors = function(styles) return TextDecoration.repaint(run,styles) end
	run.RepaintDecorations = function()
		-- A previously plain run can acquire its first inline background or
		-- decoration without reflow. The mount-time fast path is then stale.
		run.Decorated=true
		local projection=table.clone(run);projection.Items=BidiPaint.visual(run.DisplayItems or run.Items)
		TextDecoration.draw(projection)
	end
	if run.Style.TextOverflow == "ellipsis" or run.Style.MaxLines then run.PaintState = state end
	return height, farRight
end

paint = function(run: any, state: any, alive: () -> boolean): boolean
	local displayed = table.clone(state.Items)
	run.FlowContentWidth,run.FlowInlineExtent=state.Width,state.FlowWidth
	local contentWidth, runMetrics, x, y, split = state.Width, state.Metrics, state.X, state.Y, state.Split
	local ellipsis = run.Style.TextOverflow == "ellipsis" or run.Style.MaxLines~=nil or run.EllipsisPool ~= nil
	if ellipsis then
		local ok, result = pcall(TextOverflow.prepare, run, displayed, contentWidth, runMetrics,
			state.Font, TextMeasure.measure, alive)
		if not alive() then return false end
		if not ok then error(result) end
		displayed = result
	end
	if split or run.DisplayItems or ellipsis or state.HasFloats then
		if not OverflowWrap.commit(run, displayed, TextMeasure.measure, alive) then return false end
		run.DisplayItems = displayed
	end
	if ellipsis then TextOverflow.visibility(run, displayed) end
	for _,item in run.Items do TextEmphasis.hide(item)end
	for _, item in displayed do
		if not alive() then return false end
		if item.Kind == "Break" or item.Kind=='Float' then continue end
		local style = item.Style or run.Style
		if not TextEmphasis.measure(item,item.FontFace,item.TextSize,TextMeasure.measure,alive)then return false end
		item.PaintRect = nil
		if item.Kind == "Marker" then
			if not ListMarker.arrange(item.Marker, style, y + item.LineBaseline, x + item.X, alive) then return false end
			continue
		elseif item.VerticalAdvance and item.Kind == "Word" then
			VerticalText.paint(run, item, x, y, contentWidth)
			TextEmphasis.paint(run,item)
			continue
		elseif item.VerticalAdvance and item.Kind == "Space" then
			VerticalText.place(run, item, x, y, contentWidth)
			continue
		elseif item.Glyphs then
			VerticalText.hide(item)
			for _, glyph in item.Glyphs do
				write(glyph.Gui, "FontFace", item.FontFace)
				write(glyph.Gui, "TextSize", item.TextSize)
				write(glyph.Gui, "OpenTypeFeatures", style.OpenTypeFeatures)
				write(glyph.Gui, "TextXAlignment", if style.TabularNums and glyph.Text:match("^[0-9]$") then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left)
				write(glyph.Gui, "TextColor3", style.Color)
				write(glyph.Gui, "TextTransparency", if style.FontSize==0 or style.Visibility == "hidden" then 1 else 1 - (style.ColorAlpha or 1))
				write(glyph.Gui, "Text", BidiPaint.text(item,glyph.Text))
				if item.BidiDirection then write(glyph.Gui,"TextDirection",if item.BidiDirection=='rtl'then Enum.TextDirection.RightToLeft else Enum.TextDirection.LeftToRight)end
				write(glyph.Gui, "Position", UDim2.fromOffset(BidiPaint.glyphX(item,glyph), 0))
				write(glyph.Gui, "Size", UDim2.fromOffset(math.max(1, glyph.Width), glyph.Height))
			end
		elseif item.Kind == "Image" then
			local owner=item.PaintOwner
			if owner and owner.Kind=='Image'then item.OpacityGroup,item.GeometryBox=owner.OpacityGroup,owner.GeometryBox end
			write(item.Gui, "Visible", item.Width > 0 and item.Height > 0 and (not item.Control or style.Visibility ~= "hidden"))
			if item.InlineBox then elseif item.Control then ControlView.arrange(item) elseif item.MediaKind then MediaBox.arrange(item) elseif item.IFrame then IFrameBox.arrange(item) else ImageBox.arrange(item) end
			if item.AltGui then
				write(item.AltGui, "FontFace", item.FontFace)
				write(item.AltGui, "TextSize", item.TextSize)
				write(item.AltGui, "OpenTypeFeatures", style.OpenTypeFeatures)
				write(item.AltGui, "TextColor3", style.Color)
				write(item.AltGui, "TextTransparency", if style.Visibility == "hidden" then 1 else 1-(style.ColorAlpha or 1))
			end
		elseif item.Kind ~= "Space" then
			VerticalText.hide(item)
			local textGui = item.TextGui or item.Gui
			write(textGui,"Text",BidiPaint.text(item))
			if item.BidiDirection then write(textGui,"TextDirection",if item.BidiDirection=='rtl'then Enum.TextDirection.RightToLeft else Enum.TextDirection.LeftToRight)end
			write(textGui, "FontFace", item.FontFace)
			write(textGui, "TextSize", item.TextSize)
			write(textGui, "OpenTypeFeatures", style.OpenTypeFeatures)
			write(textGui, "TextColor3", style.Color)
			write(textGui, "TextTransparency", if style.FontSize==0 or style.Visibility == "hidden" then 1 else 1 - (style.ColorAlpha or 1))
			if item.TextGui then write(textGui, "Size", UDim2.fromOffset(math.max(1, item.Width), item.Height)) end
		end
		if item.InlineBox then
            local b,m=item.InlineBox,item.Style.Margin
            if item.ArrangeGrid then
				if not item.ArrangeGrid(x+item.X,y+item.Y,alive)then return false end
			else
				b.LayoutX,b.LayoutY=x+item.X+m[4],y+item.Y+m[1]
				write(item.Gui,'Position',UDim2.fromOffset(b.LayoutX,b.LayoutY))
			end
            continue
        end
		local writing=style.WritingMode
		local vertical=WritingMode.vertical(style)
		if vertical and item.Kind~="Image" then
			local right=WritingMode.blockReverse(style)
			local counterclockwise=writing=='sideways-lr'
			local column=item.Y or 0
			write(item.Gui,"AnchorPoint",Vector2.new(.5,.5))
			write(item.Gui,"Rotation",if counterclockwise then -90 else 90)
			local inline=if counterclockwise then state.FlowWidth-item.X-item.Width/2 else item.X+item.Width/2
			write(item.Gui,"Position",UDim2.fromOffset(x+(if right then contentWidth-item.Height/2-column else item.Height/2+column),y+inline))
		else
			write(item.Gui,"AnchorPoint",Vector2.new(0,0));write(item.Gui,"Rotation",0)
			write(item.Gui, "Position", UDim2.fromOffset(x + item.X, y + item.Y))
		end
		write(item.Gui, "Size", UDim2.fromOffset(math.max(if item.Kind == "Image"or item.EmptyInline then 0 else 1, item.Width), item.Height))
		if item.Kind=="Image" then
			-- Inline replaced elements are items in word runs, not NodeBoxes.
			-- Publish their final border-box geometry only during paint; intrinsic
			-- probes must not replace coordinates used by synchronous DOM reads.
			local owner=item.PaintOwner or item
			local geometry=owner.GeometryBox or item.GeometryBox or{};owner.GeometryBox,item.GeometryBox=geometry,geometry
			geometry.Node,geometry.Style=item.Node or item.Control and item.Control.Node,style
			geometry.LayoutX,geometry.LayoutY=x+item.X+style.Margin[4],y+item.Y+style.Margin[1]
			geometry.OuterWidth,geometry.OuterHeight=item.BoxWidth,item.BoxHeight
			geometry.ContentWidth,geometry.ContentHeight=item.ContentWidth,item.ContentHeight
			BoxTransform.inline(item,run.Factory)
			geometry.ImageItem=owner
		end
		if item.ShadowLabels then TextShadows.arrange(item) end
		TextEmphasis.paint(run,item)
	end
	-- Ellipsis projects the glyphs, not the inline background's layout box.
	-- The ancestor overflow clip bounds the original fragment behind it.
	InlineFragments.draw(run,BidiPaint.visual(if ellipsis then state.Items else displayed),x,y,ellipsis)
	if displayed ~= run.Items or run.Bidi then
		local paint = table.clone(run)
		paint.Items = BidiPaint.visual(displayed)
		TextDecoration.draw(paint)
	else TextDecoration.draw(run) end
	return true
end

-- Scrolling changes only the paint projection; no measurements of full words,
-- line wrapping, block/flex layout, canvas resizing or page status changes.
function WordLayout.repaint(run: any, alive: () -> boolean): boolean
	if not alive() or not run.PaintState then return false end
	return paint(run, run.PaintState, alive)
end

-- Fragmentation changes the line coordinates after wrapping. Paint them through
-- the same path as ordinary flow so inline atoms and decorations move together.
function WordLayout.paintFragments(run: any, alive: () -> boolean): boolean
	if run.MeasureOnly then return alive()end
	return run.FlowPaintState ~= nil and paint(run, run.FlowPaintState, alive)
end

return WordLayout
