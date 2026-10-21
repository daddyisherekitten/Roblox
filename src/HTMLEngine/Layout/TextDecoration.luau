--!strict
local Factory = require(script.Parent.Parent.Rendering.GuiFactory)
local FontMetrics = require(script.Parent.FontMetrics)
local SkipInk = require(script.Parent.SkipInk)
local WritingMode=require(script.Parent.Parent.CSS.WritingMode)
local CanvasBackground=require(script.Parent.Parent.Rendering.CanvasBackground)
local Color=require(script.Parent.Parent.CSS.Color)
local TextDecoration = {}
local NO_DECORATIONS = table.freeze({})
local function inlineBackground(style: any): (any?,number)
	-- A retained inline fragment owns its background rectangle. Recascade can
	-- restore the computed inherited color without transferring that paint to
	-- each word (or its intervening spaces) as well.
	if style.InlineFragment then
		local stop=style.InlineFragment.Style.Node
		local source=style.InlineBackgroundSources;local color,alpha=nil,0
		-- Descendants can add a background inside the fragment. Paint only
		-- those layers here; the fragment and its ancestors are already below.
		while source and source.Node~=stop do
			if color then color,alpha=Color.over(color,alpha,source.Color,source.Alpha)else color,alpha=source.Color,source.Alpha end
			if alpha>=1 then break end;source=source.Parent
		end
		return color,alpha
	end
	return CanvasBackground.inlineBackground(style)
end
local function write(frame: any, key: string, value: any)
	if frame[key] ~= value then frame[key] = value end
end

-- Frames and tiled ImageLabels belong to words and are reused on reflow.
-- Painting never changes word measurements or wrapping.
function TextDecoration.draw(run: any)
	if run.Decorated == false then return end
	local previous = nil
	for _, item in run.Items do
		if item.Kind == "Break" or item.Kind == "Marker" then previous = nil; continue end
		local bidiGap=item.BidiGapRect
		local gap = if bidiGap then math.max(0,bidiGap.Width)elseif previous and previous.LineIndex == item.LineIndex then math.max(0, item.X - previous.X - previous.Width) else 0
		local gapLeft=if bidiGap then bidiGap.X-item.X else -gap
		local background,backgroundAlpha
		if item.Kind~='Image'then background,backgroundAlpha=inlineBackground(item.Style or run.Style)end
		if background or item.BackgroundPainted then
			write(item.Gui, "BackgroundTransparency", if background then 1 - (backgroundAlpha or 1) else 1)
			if background then write(item.Gui, "BackgroundColor3", background) end
			item.BackgroundPainted = background ~= nil
		end
		local gapStyle = item.SpaceStyle
		if not gapStyle and item.Joined and previous then local previousBackground,previousAlpha=inlineBackground(previous.Style or run.Style);if previousBackground==background and previousAlpha==(backgroundAlpha or 1)then gapStyle=item.Style end end
		local gapBackground,gapAlpha
		if gapStyle then gapBackground,gapAlpha=inlineBackground(gapStyle)end
		if gap > 0 and gapBackground then
			if not item.GapBackground then
				item.GapBackground = Factory.create("Frame", item.Gui, {Name = "InlineBackgroundGap", BackgroundTransparency = 0})
			end
			local metrics = FontMetrics.resolve(gapStyle)
			write(item.GapBackground, "BackgroundColor3", gapBackground)
			write(item.GapBackground, "BackgroundTransparency", 1 - (gapAlpha or 1))
			local cross=if WritingMode.vertical(run.Style)then math.max(metrics.TextSize,item.MeasuredSpaceHeight or 0)else metrics.TextSize
			local top=if WritingMode.vertical(run.Style)then (item.Height-cross)/2 else item.Baseline-metrics.Baseline+(gapStyle.InlineShift or 0)-(item.BaselineShift or 0)
			write(item.GapBackground, "Position", if item.VerticalAdvance then UDim2.fromOffset(top,gapLeft)else UDim2.fromOffset(gapLeft,top))
			write(item.GapBackground, "Size", if item.VerticalAdvance then UDim2.fromOffset(cross,gap)else UDim2.fromOffset(gap,cross))
			write(item.GapBackground, "Visible", true)
		elseif item.GapBackground then write(item.GapBackground, "Visible", false) end
		local ownDecorations = if item.Kind == "Image" then NO_DECORATIONS else (item.Style or run.Style).Decorations or NO_DECORATIONS
		local gapDecorations = NO_DECORATIONS
		if gap > 0 then
			if item.SpaceStyle then gapDecorations = item.SpaceStyle.Decorations or NO_DECORATIONS
			elseif item.Joined and previous then gapDecorations = (previous.Style or run.Style).Decorations or NO_DECORATIONS end
		end
		-- Background-only/plain words in a mixed run need no segment tables.
		if #ownDecorations == 0 and #gapDecorations == 0 and not item.DecorationFrames then previous = item; continue end
		local segments, byDecoration = {}, {}
		for index, decoration in ownDecorations do
			local segment = { Decoration = decoration, Left = 0, Right = item.Width, Style=item.Style or run.Style, Index=index }
			table.insert(segments, segment); byDecoration[decoration] = segment
		end
		if gap > 0 then
			for index, decoration in gapDecorations do
				local segment = byDecoration[decoration]
				local source=item.SpaceStyle or (previous and previous.Style) or run.Style
				if segment then segment.Left=math.min(segment.Left,gapLeft);segment.Right=math.max(segment.Right,gapLeft+gap);segment.GapStyle=source;segment.GapIndex=index
				elseif item.SpaceStyle then table.insert(segments, { Decoration = decoration, Left = gapLeft, Right = gapLeft+gap, Style=source, Index=index }) end
			end
		end
		local used = 0
		local function drawLine(segment: any, kind: string, left: number, right: number, offset: number, height: number, pattern: any?)
			if right <= left then return end
			local decoration=segment.Decoration
			used += 1
			item.DecorationBindings=item.DecorationBindings or {}
			local binding=item.DecorationBindings[used] or {}
			binding.Style,binding.Index=segment.Style,segment.Index
			binding.GapStyle,binding.GapIndex=segment.GapStyle,segment.GapIndex
			binding.Pattern=pattern~=nil;item.DecorationBindings[used]=binding
			item.DecorationFrames = item.DecorationFrames or {}
			local frame = item.DecorationFrames[used]
			if not frame then
				frame = Factory.create("Frame", item.Gui, { Name = "TextDecoration", BackgroundTransparency = 0,
					ZIndex = if item.ShadowLabels then 18 else nil })
				item.DecorationFrames[used] = frame
			end
			write(frame, "BackgroundColor3", decoration.Color)
			write(frame, "BackgroundTransparency", if pattern then 1 else 1 - (decoration.Alpha or 1))
			write(frame, "ClipsDescendants", pattern ~= nil)
			local baseline = if item.Kind == "Image" then item.LineBaseline - item.Y + ((item.SpaceStyle or {}).InlineShift or 0) else item.Baseline
			local vertical=WritingMode.vertical(run.Style)
			local typography=vertical and run.Style.WritingMode~='sideways-rl'and run.Style.WritingMode~='sideways-lr'
				and(decoration.OriginOrientation or (segment.Style or run.Style).TextOrientation)~='sideways'
			local top=baseline+decoration[kind..'Offset']+offset
			if typography then
				local half=(decoration.OriginFontSize or (segment.Style or run.Style).FontSize or item.TextSize)/2
				local side=(decoration.UnderlinePosition or 'auto'):find('right',1,true)~=nil
				local cross
				if kind=='Strike'then cross=-decoration.Thickness/2+offset
				elseif kind=='Underline'then
					local distance=(decoration.RawUnderlineOffset or 0)+offset
					cross=if side then half+distance else -half-distance-height
				else cross=if side then -half+offset-height else half-offset end
				local logicalCenter=(item.LineBaseline or ((item.Y or 0)+item.Height/2))-(item.Y or 0)+(decoration.OriginShift or 0)
				cross+=(if WritingMode.blockReverse(run.Style)then -1 else 1)*(logicalCenter-item.Height/2)
				-- Upright labels already live in physical axes. Rotated labels
				-- inherit the +90 degree GUI projection of their parent word.
				top=if item.VerticalAdvance then item.Height/2+cross else item.Height/2-cross-height
			elseif vertical then
				-- Sideways typographic modes retain alphabetic font metrics even
				-- though the containing vertical line uses a central baseline.
				top=item.Height/2+(decoration.OriginBaseline or FontMetrics.resolve(segment.Style or run.Style).Baseline)
					-(decoration.OriginFontSize or (segment.Style or run.Style).FontSize)/2+decoration[kind..'Offset']+offset
			end
			write(frame, "Position", if item.VerticalAdvance then UDim2.fromOffset(top,left)else UDim2.fromOffset(left,top))
			write(frame, "Size", if item.VerticalAdvance then UDim2.fromOffset(height,right-left)else UDim2.fromOffset(right-left,height))
			write(frame, "Visible", true)
			local images = item.DecorationImages
			local label = if images then images[used] else nil
			if pattern then
				if not label then
					label = Factory.create("ImageLabel", frame, {Name = "DecorationPattern", ScaleType = Enum.ScaleType.Tile})
					item.DecorationImages = images or {}
					item.DecorationImages[used] = label
				end
				-- Continue a pattern across word boundaries and skip-ink cuts.
				local phase = (item.X + left) % pattern.Width
				write(label, "ImageContent", pattern.Content)
				write(label, "ImageColor3", decoration.Color)
				write(label, "ImageTransparency", 1 - (decoration.Alpha or 1))
				write(label, "TileSize", UDim2.fromOffset(pattern.Width, pattern.Height))
				write(label,"AnchorPoint",if item.VerticalAdvance then Vector2.new(.5,.5)else Vector2.new(0,0))
				write(label,"Rotation",if item.VerticalAdvance then 90 else 0)
				write(label, "Position", if item.VerticalAdvance then UDim2.fromOffset(height/2,(right-left-phase)/2)else UDim2.fromOffset(-phase, 0))
				write(label, "Size", UDim2.fromOffset(right - left + phase, height))
				write(label, "Visible", true)
			elseif label then write(label, "Visible", false) end
		end
		for _, segment in segments do
			local decoration = segment.Decoration
			local pattern = nil
			if run.DecorationPatterns and decoration.Style and decoration.Style ~= "solid" and decoration.Style ~= "double" then
				pattern = run.DecorationPatterns:Get(decoration.Style, decoration.Thickness)
			end
			local double = decoration.Style == "double"
			local height = if pattern then pattern.Height else decoration.Thickness
			for _, kind in { "Underline", "Strike", "Overline" } do
				if not decoration[kind] or segment.Right <= segment.Left then continue end
				for band = 1, if double then 2 else 1 do
					local offset = (band - 1) * decoration.Thickness * 2
					if kind == "Strike" then offset -= (if double then decoration.Thickness else (height - decoration.Thickness) / 2) end
					if kind == "Overline" then offset = -offset - (height - decoration.Thickness) end
					local left = segment.Left
					if kind == "Underline" and not item.VerticalAdvance and decoration.SkipInk ~= "none" and SkipInk.intersects(item, decoration, offset, height) then
						for _, cut in item.SkipInkCuts or {} do
							if cut.Left >= segment.Right then break end
							if cut.Right <= left then continue end
								drawLine(segment, kind, left, math.min(cut.Left, segment.Right), offset, height, pattern)
							left = math.max(left, cut.Right)
						end
					end
						drawLine(segment, kind, left, segment.Right, offset, height, pattern)
				end
			end
		end
		for index = used + 1, #(item.DecorationFrames or {}) do write(item.DecorationFrames[index], "Visible", false) end
		previous = item
	end
end

-- Retain the geometry and source of each solid/pattern/skip-ink segment.
-- Different gap and word colors can split a previously shared segment; only
-- that case needs the decoration drawer again, never the entire word run.
function TextDecoration.repaint(run: any, styles: any): boolean
	local items=run.DisplayItems or run.Items
	for _, item in items do
		for index, binding in item.DecorationBindings or {} do
			local frame=item.DecorationFrames[index]
			if frame.Visible==false or not binding.GapStyle then continue end
			local own=(binding.Style.Decorations or {})[binding.Index]
			local gap=(binding.GapStyle.Decorations or {})[binding.GapIndex]
			if not own or not gap or own.Color~=gap.Color or (own.Alpha or 1)~=(gap.Alpha or 1) then return false end
		end
	end
	for _, item in items do
		for index, binding in item.DecorationBindings or {} do
			if not styles[binding.Style] and not styles[binding.GapStyle] then continue end
			local decoration=(binding.Style.Decorations or {})[binding.Index]
			local frame=item.DecorationFrames[index]
			if not decoration or frame.Visible==false then continue end
			write(frame,"BackgroundColor3",decoration.Color)
			write(frame,"BackgroundTransparency",if binding.Pattern then 1 else 1-(decoration.Alpha or 1))
			local image=item.DecorationImages and item.DecorationImages[index]
			if binding.Pattern and image then
				write(image,"ImageColor3",decoration.Color);write(image,"ImageTransparency",1-(decoration.Alpha or 1))
			end
		end
	end
	return true
end

return TextDecoration
