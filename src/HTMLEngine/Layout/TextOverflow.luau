--!strict
-- A paint projection of the finished lines; source items and flow extents stay intact.
local LetterSpacing = require(script.Parent.LetterSpacing)
local TextSource = require(script.Parent.TextSource)
local BidiInline=require(script.Parent.BidiInline)
local BidiPaint=require(script.Parent.BidiPaint)
local TextOverflow = {}
local FIELDS = {"FontFace", "TextSize", "Baseline", "BaselineShift", "Ascent", "Descent", "SkipInkTop", "SkipInkBottom",
	"X", "Y", "LineIndex", "LineBaseline", "SpaceBefore", "SpaceStyle", "SpaceWidth", "Joined"}

local function clipped(item: any, available: number, first: boolean, keepLeft: boolean, measure: any, alive: any): any?
	local owner = item.PaintOwner or item.WrapOwner or item
	local fromStart=keepLeft~=(item.BidiDirection=='rtl')
	local cache = owner.EllipsisCache
	local spacing, wordSpacing = item.Style.LetterSpacing or 0, item.Style.WordSpacing or 0
	if not cache or cache.Text ~= item.Text or cache.Font ~= item.FontFace or cache.Size ~= item.TextSize
		or cache.Spacing ~= spacing or cache.WordSpacing ~= wordSpacing or cache.BidiDirection~=item.BidiDirection or cache.NativeBidiForced~=item.NativeBidiForced then
		local ends = {}
		for _, last in utf8.graphemes(item.Text) do table.insert(ends, last) end
		cache = {Text = item.Text, Font = item.FontFace, Size = item.TextSize, Ends = ends, Bounds = {}, Count = 0, Spacing = spacing, WordSpacing = wordSpacing,BidiDirection=item.BidiDirection,NativeBidiForced=item.NativeBidiForced}
		owner.EllipsisCache = cache
	end
	local glyphs = item.GlyphMetrics or item.Glyphs
	local function part(count: number): any
		local key=count+(if fromStart then 0 else #cache.Ends)
		if cache.Bounds[key] then return cache.Bounds[key] end
		local start=if fromStart then 1 else #cache.Ends-count+1
		local firstByte=if start==1 then 1 else cache.Ends[start-1]+1
		local lastByte=cache.Ends[start+count-1]
		local result = {Text = item.Text:sub(firstByte,lastByte),FirstByte=firstByte,LastByte=lastByte,FirstGrapheme=start}
		if glyphs then
			result.Glyphs = {}
			for i = start, start+count-1 do
				local g = glyphs[i]
				table.insert(result.Glyphs, {Text = g.Text, Width = g.Width, Height = g.Height})
			end
			LetterSpacing.arrange(result, spacing, wordSpacing)
		else
			local bounds, message = measure(BidiPaint.text(item,result.Text), item.FontFace, item.TextSize, 0)
			if not alive() then error("Page disposed during ellipsis measurement") end
			assert(bounds, "Ellipsis prefix measurement failed: " .. tostring(message))
			result.Width, result.Height = bounds.X, math.max(item.TextSize, bounds.Y)
		end
		if cache.Count >= 256 then table.clear(cache.Bounds); cache.Count = 0 end
		cache.Bounds[key], cache.Count = result, cache.Count + 1
		return result
	end
	local best, low, high = 0, 1, #cache.Ends
	if spacing < 0 or wordSpacing < 0 then
		for count = 1, high do
			local p = part(count)
			if (p.VisualWidth or p.Width) <= available then best = count end
		end
	else
		while low <= high do
			local mid = math.floor((low + high) / 2)
			local p = part(mid)
			if (p.VisualWidth or p.Width) <= available then best, low = mid, mid + 1 else high = mid - 1 end
		end
	end
	-- CSS preserves the first character and clips it if even that cannot fit.
	if first and #cache.Ends > 0 then best = math.max(1, best) end
	if best == 0 then return nil end
	local p = part(best)
	local result = {Kind = "Word", Style = item.Style, Text = p.Text, Width = p.Width, Height = p.Height,
		VisualWidth = p.VisualWidth, GlyphMetrics = p.Glyphs, WrapOwner = owner,
		WrapFirst = (item.WrapFirst or 1)+p.FirstGrapheme-1, WrapLast = (item.WrapFirst or 1)+p.FirstGrapheme+best-2,
		EllipsisFirstByte=p.FirstByte,EllipsisLastByte=p.LastByte}
	for _, field in FIELDS do result[field] = item[field] end
	result.X=if keepLeft then item.X else item.X+item.Width-result.Width
	result.SourceSpans=TextSource.slice(item.SourceSpans,p.FirstByte,p.LastByte)
	result.SourceGap=if p.FirstByte==1 then item.SourceGap else nil
	result.SourceHiddenSpans={}
	for _,span in item.SourceHiddenSpans or{}do if span.Byte>=p.FirstByte-1 and span.Byte<=p.LastByte then
		local copy=table.clone(span);copy.Byte-=p.FirstByte-1;table.insert(result.SourceHiddenSpans,copy)
	end end
	if #result.SourceHiddenSpans==0 then result.SourceHiddenSpans=nil end
	BidiInline.slice(item,result,p.FirstByte,p.LastByte)
	result.BidiGapRect=if p.FirstByte==1 then item.BidiGapRect else nil
	return result
end

function TextOverflow.prepare(run: any, displayed: any, width: number, metrics: any, font: any, measure: any, alive: any): any
	for _, marker in run.EllipsisPool or {} do marker.Gui.Visible = false end
	-- Keep the source canvas width; project against the currently visible right edge.
	local maxLines=run.Style.MaxLines
	if (run.Style.TextOverflow ~= "ellipsis" and not maxLines) or (not maxLines and run.Style.OverflowX ~= "hidden" and run.Style.OverflowX ~= "auto" and run.Style.OverflowX ~= "scroll") or not run.CreateWord then return displayed end
	local scroll = run.ScrollBox and run.ScrollBox.ScrollGui
	local scrollX=if scroll then scroll.CanvasPosition.X else 0
	width+=scrollX
	local rtl=run.Style.Direction=='rtl'
	local lines, order = {}, {}
	local discarded=false
	for _, item in displayed do
		if item.Kind == "Break" then continue end
		if maxLines and item.LineIndex>maxLines then discarded=true;continue end
		local line = lines[item.LineIndex]
		if not line then line = {Items = {}, Overflow = false}; lines[item.LineIndex] = line; table.insert(order, item.LineIndex) end
		table.insert(line.Items, item)
		if item.Kind ~= "Space"and(if rtl then item.X<scrollX-.001 else item.X+(item.VisualWidth or item.Width)>width+.001)then line.Overflow=true end
	end
	if discarded and lines[maxLines] then lines[maxLines].Overflow=true end
	local result = {}
	for _, lineIndex in order do
		local line = lines[lineIndex]
		if not line.Overflow then
			for _, item in line.Items do table.insert(result, item) end
			continue
		end
		local cache = run.EllipsisMetrics
		if not cache or cache.Font ~= font or cache.Size ~= metrics.TextSize then
			local bounds, message = measure("…", font, metrics.TextSize, 0)
			if not alive() then error("Page disposed during ellipsis measurement") end
			assert(bounds, "Ellipsis measurement failed: " .. tostring(message))
			cache = {Font = font, Size = metrics.TextSize, Width = bounds.X, Height = math.max(metrics.TextSize, bounds.Y)}
			run.EllipsisMetrics = cache
		end
		run.EllipsisPool = run.EllipsisPool or {}
		local marker = run.EllipsisPool[lineIndex]
		if not marker then
			local style = table.clone(run.Style)
			style.InlineBackground = nil
			marker = {Kind = "Word", Text = "…", Style = style}
			run.CreateWord(marker)
			run.EllipsisPool[lineIndex] = marker
			local first = line.Items[1]
			local gui = first.Gui or (first.WrapOwner and first.WrapOwner.Gui)
			if gui and gui.ZIndex ~= nil then marker.Gui.ZIndex = gui.ZIndex end
		end
		local limit=if rtl then scrollX+cache.Width else width-cache.Width
		local ending,occupied=if rtl then width else scrollX,false
		local kept,elided={},{}
		local visual=BidiPaint.visual(line.Items)
		local cutItem
		for at=1,#visual do
			local item=visual[if rtl then #visual-at+1 else at]
			local fits=if rtl then item.X>=limit else item.X+(item.VisualWidth or item.Width)<=limit
			if not cutItem and fits then
				kept[item]=item;ending=if rtl then item.X else item.X+item.Width
				if item.Kind~='Space'then occupied=true end
			elseif not cutItem then
				cutItem=item
				if item.Kind=='Word'then
					local part=clipped(item,if rtl then item.X+item.Width-limit else limit-item.X,not occupied,not rtl,measure,alive)
					if part then kept[item]=part;ending=if rtl then part.X else part.X+part.Width end
				elseif item.Kind=='Image'and not occupied then kept[item]=item;ending=if rtl then item.X else item.X+item.Width
				elseif item.Kind=='Space'then ending=if rtl then math.min(ending,limit)else math.max(ending,limit)end
			end
		end
		local function hidden(spans: any)
			for _,span in spans or{}do local copy=table.clone(span);copy.FirstByte,copy.LastByte=1,#marker.Text;table.insert(elided,copy)end
		end
		for _,item in line.Items do
			local retained=kept[item]
			if retained then
				table.insert(result,retained)
				if retained~=item then
					hidden(TextSource.slice(item.SourceSpans,1,retained.EllipsisFirstByte-1))
					hidden(TextSource.slice(item.SourceSpans,retained.EllipsisLastByte+1,#item.Text))
				end
			else hidden(item.SourceGap);hidden(item.SourceSpans);hidden(item.SourceHiddenSpans)end
		end
		-- The marker is paint only, but its hit/selection mapping belongs to the
		-- hidden source. Source copying still uses the intact logical run owners.
		marker.PaintOwner=run;marker.SourceSpans=if #elided>0 then elided else nil
		marker.BidiDirection=if rtl then 'rtl'else 'ltr';marker.NativeBidiForced=rtl
		if cutItem and run.HitNodes then run.HitNodes[marker.Gui]=cutItem.Style.HitNode or cutItem.Style.Node;run.HitStyles[marker.Gui]=cutItem.Style end
		marker.Width, marker.Height, marker.TextSize, marker.FontFace = cache.Width, cache.Height, cache.Size, font
		marker.Baseline, marker.BaselineShift = metrics.Baseline, 0
		marker.LineIndex, marker.LineBaseline = lineIndex, line.Items[1].LineBaseline
		marker.X, marker.Y = if rtl then ending-cache.Width else math.max(0,ending), marker.LineBaseline - metrics.Baseline
		marker.SkipInkTop, marker.SkipInkBottom = metrics.XHeight, metrics.Bottom
		if marker.Glyphs then
			local g = marker.Glyphs[1]; g.X, g.Width, g.Height = 0, cache.Width, cache.Height
		end
		table.insert(result, marker)
	end
	return result
end

function TextOverflow.visibility(run: any, displayed: any)
	for _, item in run.Items do if item.Gui then item.Gui.Visible = false end end
	for _, item in displayed do if item.Gui then item.Gui.Visible = true end end
end
return TextOverflow
