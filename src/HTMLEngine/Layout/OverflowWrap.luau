--!strict
-- Lazily measure whole substrings; regular words retain their native word label.
local LetterSpacing = require(script.Parent.LetterSpacing)
local SkipInk = require(script.Parent.SkipInk)
local GroupOpacity = require(script.Parent.Parent.Rendering.GroupOpacity)
local TextSource = require(script.Parent.TextSource)
local Hyphenation=require(script.Parent.Hyphenation)
local WhiteSpace=require(script.Parent.WhiteSpace)
local BidiInline=require(script.Parent.BidiInline)
local BidiPaint=require(script.Parent.BidiPaint)
local OverflowWrap = {}

local function allowed(item: any): boolean
	local style = item.Style
	local source=item.WrapOwner or item
	return item.Kind == "Word" and style and (item.VerticalAdvance ~= nil or style.LineBreak=="anywhere" or style.OverflowWrap == "break-word" or style.OverflowWrap == "anywhere" or style.WordBreak == "break-all" or style.WordBreak == "break-word" or next(source.HyphenPoints or {})~=nil or source.HyphenAtEnd~=nil)
		and WhiteSpace.wraps(style)
end

function OverflowWrap.splitter(run: any, measure: any, alive: () -> boolean): any
	if not run.CreateWord and not run.MeasureOnly then return nil end
	Hyphenation.prepare(run)
	local active = false
	for _, item in run.Items do if allowed(item) then active = true; break end end
	if not active then return nil end
	local function split(item: any, available: number, occupied: boolean): (any, any, boolean?)
		if not allowed(item) then return nil,nil end
		local owner = item.WrapOwner or item
		local emergency=owner.VerticalAdvance~=nil or owner.Style.LineBreak=="anywhere"or owner.Style.OverflowWrap=="anywhere"or owner.Style.WordBreak=="break-all"or owner.Style.WordBreak=="break-word"
			or (not run.MeasureOnly and owner.Style.OverflowWrap=="break-word")
		local spacing, wordSpacing = owner.Style.LetterSpacing or 0, owner.Style.WordSpacing or 0
		local cache = owner.WrapCache
		if not cache or cache.Text ~= owner.Text or cache.Font ~= owner.FontFace or cache.Size ~= owner.TextSize
			or cache.Spacing ~= spacing or cache.WordSpacing ~= wordSpacing or cache.VerticalAdvance ~= owner.VerticalAdvance or cache.VerticalEm~=owner.VerticalEm
			or cache.BidiDirection~=owner.BidiDirection or cache.NativeBidiForced~=owner.NativeBidiForced then
			local ends = {}
			for _, last in utf8.graphemes(owner.Text) do table.insert(ends, last) end
			cache = {Text = owner.Text, Font = owner.FontFace, Size = owner.TextSize, Spacing = spacing,
				WordSpacing = wordSpacing, VerticalAdvance = owner.VerticalAdvance, VerticalEm=owner.VerticalEm, Ends = ends, Bounds = {}, Count = 0,BidiDirection=owner.BidiDirection,NativeBidiForced=owner.NativeBidiForced}
			owner.WrapCache = cache
		end
		local first, last = item.WrapFirst or 1, item.WrapLast or #cache.Ends
		local function part(stop: number, start: number?,hyphen: boolean?): any
			local begin = start or first
			local key = tostring(begin) .. ":" .. tostring(stop)..(if hyphen then ":h:"..(owner.Style.HyphenateCharacter or "-") else "")
			local result = cache.Bounds[key]
			if result then return result end
			local text = owner.Text:sub(if begin == 1 then 1 else cache.Ends[begin - 1] + 1, cache.Ends[stop])..(if hyphen then owner.Style.HyphenateCharacter or "-" else "")
			result = {Text = text,Hyphen=hyphen==true}
			if owner.VerticalAdvance then
				result.Width, result.Height = 0, owner.Height
				for index = begin, stop do
					if index > begin then result.Width += spacing end
					result.Width += owner.VerticalCharacters[index].Cell or owner.VerticalAdvance
					if owner.VerticalCharacters[index].Text == " " then result.Width += wordSpacing end
				end
			elseif owner.Glyphs then
				result.Glyphs = {}
				for index = begin, stop do
					local glyph = owner.Glyphs[index]
					table.insert(result.Glyphs, {Text = glyph.Text, Width = glyph.Width, Height = glyph.Height})
				end
				if hyphen then for a,b in utf8.graphemes(owner.Style.HyphenateCharacter or "-")do
					local value=(owner.Style.HyphenateCharacter or "-"):sub(a,b)
					local bounds,message=measure(value,owner.FontFace,owner.TextSize,0)
					if not alive()then error("Page disposed during hyphen measurement")end
					assert(bounds,"Hyphen measurement failed: "..tostring(message))
					table.insert(result.Glyphs,{Text=value,Width=bounds.X,Height=math.max(owner.TextSize,bounds.Y)})
				end end
				LetterSpacing.arrange(result, spacing, wordSpacing)
			else
				local bounds, message = measure(BidiPaint.text(owner,text), owner.FontFace, owner.TextSize, 0)
				if not alive() then error("Page disposed during overflow-wrap measurement") end
				assert(bounds, "Overflow word measurement failed: " .. tostring(message))
				result.Width, result.Height = bounds.X, math.max(owner.TextSize, bounds.Y)
			end
			-- Bound measurement storage across many viewport widths.
			if cache.Count >= 256 then table.clear(cache.Bounds); cache.Count = 0 end
			cache.Bounds[key], cache.Count = result, cache.Count + 1
			return result
		end
		local best,hyphen,fallback=nil,false,nil
		-- Linguistic/explicit opportunities precede arbitrary emergency breaks.
		-- Scan only candidates: tracking/font shaping need not be monotonic.
		if not owner.VerticalAdvance then for stop=first,last do
			local opportunity=owner.HyphenPoints and owner.HyphenPoints[cache.Ends[stop]]
			if stop==#cache.Ends then opportunity=owner.HyphenAtEnd end
			if opportunity then
				fallback=fallback or stop
				if part(stop,nil,true).Width<=available then best,hyphen=stop,true end
			end
		end end
		if not best and not occupied and owner.HyphenFallbackPoints then
			-- Explicit SHY takes precedence. Dictionary points are considered
			-- only when its next unbreakable portion cannot fit an empty line.
			for stop=first,(fallback or last+1)-1 do if owner.HyphenFallbackPoints[cache.Ends[stop]]and part(stop,nil,true).Width<=available then best,hyphen=stop,true end end
		end
		if not best and not emergency then
			if fallback and(not occupied or item.WrapBefore==false)then best,hyphen=fallback,true
			else return nil,if occupied then item else nil end
		end
		if not best and first==last then return nil,nil end
		if not best and part(first).Width>available and occupied then return nil,item end
		if not best and spacing < 0 then
			-- Negative tracking can make prefix advances non-monotonic.
			best=first
			for stop = first, last - 1 do if part(stop).Width <= available then best = stop end end
		elseif not best then
			local low,high=first,last-1;best=first
			while low <= high do
				local mid = math.floor((low + high) / 2)
				if part(mid).Width <= available then best, low = mid, mid + 1 else high = mid - 1 end
			end
		end
		local function fragment(begin: number, stop: number, head: boolean): any
			local bounds = part(stop, begin,head and hyphen)
			local result = {Kind = "Word", Style = owner.Style, Text = bounds.Text, Width = bounds.Width,
				Height = bounds.Height, VisualWidth = bounds.VisualWidth, WrapOwner = owner, WrapFirst = begin, WrapLast = stop}
			result.SourceSpans=TextSource.slice(owner.SourceSpans,if begin==1 then 1 else cache.Ends[begin-1]+1,cache.Ends[stop])
			local source=owner.HyphenPoints and owner.HyphenPoints[cache.Ends[stop]]or (stop==#cache.Ends and owner.HyphenAtEnd)
			if head and hyphen and type(source)=="table"then
				result.SourceSpans=result.SourceSpans or {}
				table.insert(result.SourceSpans,{Node=source.Node,Start=source.Start,Finish=source.Finish,FirstByte=#bounds.Text-#(owner.Style.HyphenateCharacter or "-")+1,LastByte=#bounds.Text})
			end
			local firstByte=if begin==1 then 1 else cache.Ends[begin-1]+1
			BidiInline.slice(owner,result,firstByte,cache.Ends[stop])
			local hidden={}
			for _,span in owner.SourceHiddenSpans or {}do
				if span.Byte>=firstByte-1 and span.Byte<=cache.Ends[stop]and not(head and hyphen and span.Byte==cache.Ends[stop])then
					table.insert(hidden,{Node=span.Node,Start=span.Start,Finish=span.Finish,Byte=span.Byte-firstByte+1,Text=span.Text})
				end
			end
			result.SourceHiddenSpans=if #hidden>0 then hidden else nil
			result.SourceGap=if head then item.SourceGap else nil
			for _, key in {"VerticalAdvance","VerticalEm","VerticalOrientation","VerticalAlternate", "FontFace", "TextSize", "Baseline", "BaselineShift", "Ascent", "Descent", "SkipInkTop", "SkipInkBottom"} do result[key] = owner[key] end
			result.Fragment,result.FragmentLeft,result.FragmentRight=item.Fragment,item.FragmentLeft,item.FragmentRight
			result.FragmentFirst=head and item.FragmentFirst
			result.FragmentLast=stop==last and item.FragmentLast
			result.GlyphMetrics = bounds.Glyphs
			result.SpaceBefore = head and item.SpaceBefore
			result.SpaceStyle = if head then item.SpaceStyle else nil
			result.SpaceWidth = if head then item.SpaceWidth else spacing
			result.Joined = if head then item.Joined else true
			return result
		end
		return fragment(first, best, true),if best<last then fragment(best + 1, last, false)else nil,hyphen
	end
	local function canHyphenate(item: any,available: number): boolean
		local group=item.HyphenGroup
		if not group then
			local source=item.WrapOwner or item
			if not next(source.HyphenPoints or {})and source.HyphenAtEnd==nil then return false end
			local head,_,hyphen=split(item,available,true);return head~=nil and hyphen==true and head.Width<=available
		end
		local begun=false
		for _,piece in group do
			if piece==item then begun=true elseif begun then available-=piece.SpaceWidth or 0 end
			if not begun then continue end
			if next(piece.HyphenPoints or {})or piece.HyphenAtEnd~=nil then
				local head,_,hyphen=split(piece,available,true)
				if head and hyphen and head.Width<=available then return true end
			end
			available-=piece.Width
			if available<=0 then return false end
		end
		return false
	end
	return split,canHyphenate
end

function OverflowWrap.commit(run: any, displayed: any, measure: any, alive: () -> boolean): boolean
	-- Hide unused pooled labels, including after a word fits as a whole again.
	for _, item in run.Items do
		if item.WrapPool then
			item.WrapUsed = 0
			for _, fragment in item.WrapPool do fragment.Gui.Visible = false end
			item.Gui.Visible = true
		end
	end
	for index, item in displayed do
		local owner = item.WrapOwner
		if not owner then continue end
		owner.WrapPool = owner.WrapPool or {}
		owner.WrapUsed = (owner.WrapUsed or 0) + 1
		local slot = owner.WrapUsed
		local target = owner.WrapPool[slot]
		if target and target.Glyphs and target.Text ~= item.Text then
			if run.Factory then
				-- Retain the registered word/frame. Replacing whole frames would
				-- retain dead textItems and GroupOpacity members on every resize.
				local glyphs=LetterSpacing.split(item.Text)
				for index,glyph in glyphs do
					local old=target.Glyphs[index]
					glyph.Gui=if old then old.Gui else run.Factory.create("TextLabel",target.Gui,{Name="Character_"..index,LineHeight=1,ZIndex=target.Glyphs[1]and target.Glyphs[1].Gui.ZIndex})
					glyph.Gui.Text=glyph.Text
					glyph.Gui.Visible=true
					glyph.Gui.TextXAlignment=if item.Style.TabularNums and glyph.Text:match("^[0-9]$")then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
				end
				for index=#glyphs+1,#target.Glyphs do target.Glyphs[index].Gui:Destroy()end
				target.Glyphs=glyphs
			else
				GroupOpacity.untrack(target)
				target.Gui:Destroy(); target=nil
			end
		end
		if not target then
			target = table.clone(item)
			run.CreateWord(target)
			owner.WrapPool[slot] = target
		end
		if target.Text ~= item.Text or target.FontFace ~= item.FontFace or target.TextSize ~= item.TextSize or target.Width ~= item.Width then target.SkipInkCuts = nil end
		for key, value in item do target[key] = value end
		BidiInline.copy(item,target)
		target.VerticalAdvance = item.VerticalAdvance
		target.VerticalEm,target.VerticalOrientation,target.VerticalAlternate=item.VerticalEm,item.VerticalOrientation,item.VerticalAlternate
		target.SpaceStyle, target.SpaceBefore = item.SpaceStyle, item.SpaceBefore
		target.SourceSpans,target.SourceGap,target.SourceHiddenSpans=item.SourceSpans,item.SourceGap,item.SourceHiddenSpans
		if target.Glyphs then
			for i, glyph in if item.VerticalAdvance then {} else target.Glyphs do
				local metrics = item.GlyphMetrics[i]
				glyph.X, glyph.Width, glyph.Height = metrics.X, metrics.Width, metrics.Height
			end
		else (target.TextGui or target.Gui).Text = item.Text end
		if not SkipInk.measure(target, target.Style, measure, alive) then return false end
		if owner.Gui.ZIndex ~= nil then target.Gui.ZIndex = owner.Gui.ZIndex end
		owner.Gui.Visible, target.Gui.Visible = false, true
		displayed[index] = target
	end
	return true
end

return OverflowWrap
