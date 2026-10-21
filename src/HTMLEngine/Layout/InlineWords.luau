--!strict
-- Process CSS whitespace across text nodes without inventing spaces at tags.
-- Styled word fragments remain one unbreakable group without invented spaces.
local TextTransform = require(script.Parent.TextTransform)
local TextSource = require(script.Parent.TextSource)
local LanguageRange=require(script.Parent.Parent.CSS.LanguageRange)
local WhiteSpace=require(script.Parent.WhiteSpace)
local BidiScope=require(script.Parent.BidiScope)
local Orientation=require(script.Parent.VerticalOrientation)
local InlineWords = {}
InlineWords.__index = InlineWords

local function sameShadows(a: any, b: any): boolean
	if a == b then return true end
	if #(a or {}) ~= #(b or {}) then return false end
	for index, value in a or {} do if value ~= b[index] then return false end end
	return true
end

local function sameStyle(a: any, b: any): boolean
	return a.InlineFragment==b.InlineFragment and a.HitNode == b.HitNode and a.Font == b.Font and a.FontSize == b.FontSize and a.Color == b.Color
		and a.Cursor == b.Cursor and a.AutoCursor == b.AutoCursor
		and (a.ColorAlpha or 1) == (b.ColorAlpha or 1)
		and (a.Visibility or "visible") == (b.Visibility or "visible")
		and (a.FontWeight or 400) == (b.FontWeight or 400)
		and (a.FontStyle or "normal") == (b.FontStyle or "normal")
		and (a.TextTransform or "none") == (b.TextTransform or "none")
		and (a.LetterSpacing or 0) == (b.LetterSpacing or 0)
		and a.TabularNums == b.TabularNums
		and a.WritingMode == b.WritingMode and a.TextOrientation == b.TextOrientation
		and BidiScope.same(a.BidiContext,b.BidiContext)
		-- In glyph mode NBSP receives word-spacing inside the word itself.
		and ((a.LetterSpacing or 0) == 0 or (a.WordSpacing or 0) == (b.WordSpacing or 0))
		and (a.InlineShift or 0) == (b.InlineShift or 0)
		and a.InlineBackground == b.InlineBackground
		and (a.InlineBackgroundAlpha or 1) == (b.InlineBackgroundAlpha or 1)
		and sameShadows(a.TextShadows, b.TextShadows)
		and (a.TextEmphasisStyle and a.TextEmphasisStyle.Mark)==(b.TextEmphasisStyle and b.TextEmphasisStyle.Mark)
		and a.TextEmphasisColor==b.TextEmphasisColor and a.TextEmphasisColorAlpha==b.TextEmphasisColorAlpha
		and (a.TextEmphasisPosition and a.TextEmphasisPosition.Vertical)==(b.TextEmphasisPosition and b.TextEmphasisPosition.Vertical)
		and (a.TextEmphasisPosition and a.TextEmphasisPosition.Horizontal)==(b.TextEmphasisPosition and b.TextEmphasisPosition.Horizontal)
		and (a.WhiteSpace or "normal") == (b.WhiteSpace or "normal")
		and a.WordBreak == b.WordBreak and a.OpacityGroup == b.OpacityGroup
		and a.SemanticRole == b.SemanticRole and a.SemanticLabel == b.SemanticLabel and a.SemanticValue == b.SemanticValue
		and (a.OverflowWrap or "normal") == (b.OverflowWrap or "normal")
		and (a.LineBreak or "auto") == (b.LineBreak or "auto") and (a.TextAutospace or "normal") == (b.TextAutospace or "normal")
		and (a.HangingPunctuation or "none") == (b.HangingPunctuation or "none")
		and (a.Hyphens or "manual")== (b.Hyphens or "manual") and a.HyphenateCharacter==b.HyphenateCharacter
		and table.concat(a.HyphenateLimitChars or {5,2,2},",")==table.concat(b.HyphenateLimitChars or {5,2,2},",")
		and (if a.Node then LanguageRange.language(a.Node)else "")== (if b.Node then LanguageRange.language(b.Node)else "")
		and (a.Decorations == b.Decorations or (#(a.Decorations or {}) == 0 and #(b.Decorations or {}) == 0))
		and a.LineHeight.Kind == b.LineHeight.Kind and a.LineHeight.Value == b.LineHeight.Value
end

function InlineWords.new(diagnostic: (string) -> ()): any
	return setmetatable({ Items = {}, Parts = {}, SourceChars={}, Pending={}, Diagnostic = diagnostic, HasWord = false }, InlineWords)
end

-- Internal recascade classifiers use the exact tokenizer rule. This does not
-- change initial grouping or expose an author-facing DOM interface.
InlineWords.sameStyle = sameStyle

local function emitWord(self: any,context: any?,firstIndex: number)
	local transform = self.Style.TextTransform
	local lang=self.Style.TextTransformLanguage or(if self.Style.Node then LanguageRange.language(self.Style.Node)else '')
	local text,mapping = TextTransform.word(table.concat(self.Parts), transform,self.HasSource==true,lang,context,firstIndex)
	local sourceText={};if transform and transform~='none'then for _,code in utf8.codes(table.concat(self.Parts))do table.insert(sourceText,utf8.char(code))end end
	local spans,manual,hidden={},{},{}
	local original=text
	local pieces,removed,visible={},{},0
	for first,code in utf8.codes(original)do
		local nextFirst=utf8.offset(original,2,first)or #original+1
		if code==0xAD then
			removed[first]=visible
			manual[visible]=true
		else local part=original:sub(first,nextFirst-1);table.insert(pieces,part);visible+=#part end
	end
	text=table.concat(pieces)
	local removedBytes=0
	for index,span in self.SourceChars do
		local mapped=mapping and mapping[index]
		if mapped and mapped.Hidden then
			if span then table.insert(hidden,{Node=span.Node,Start=span.Start,Finish=span.Finish,Byte=mapped.LastByte-removedBytes,Text=sourceText[index]or '',TransformHidden=true})end
		elseif mapped and removed[mapped.FirstByte]~=nil then
			if span then
				local source={Node=span.Node,Start=span.Start,Finish=span.Finish,Byte=removed[mapped.FirstByte],Text=original:sub(mapped.FirstByte,mapped.LastByte)}
				manual[source.Byte]=source;table.insert(hidden,source)
			end
			removedBytes+=mapped.LastByte-mapped.FirstByte+1
		elseif span and mapped then table.insert(spans,{Node=span.Node,Start=span.Start,Finish=span.Finish,FirstByte=mapped.FirstByte-removedBytes,LastByte=mapped.LastByte-removedBytes,CopyText=sourceText[index],SourceStyle=span.SourceStyle})end
	end
	if (self.Style.WordSpacing or 0) ~= 0 and (self.Style.LetterSpacing or 0) == 0 and text:find(" ", 1, true) then
		self.Diagnostic("word-spacing inside a non-breaking word group is not supported; keeping its native spacing")
	end
	local parts={}
	local hanging=self.Style.HangingPunctuation or "none"
	local autospace=(self.Style.TextAutospace or "normal")~="no-autospace"
	local function class(code: number): string
		if (code>=0x3400 and code<=0x9fff) or (code>=0xf900 and code<=0xfaff) or (code>=0x3040 and code<=0x30ff) or (code>=0xac00 and code<=0xd7af) then return "cjk" end
		if (code>=48 and code<=57) or (code>=65 and code<=90) or (code>=97 and code<=122) then return "latin" end
		return "other"
	end
	local previousClass
	for start,code in utf8.codes(text) do
		local nextStart=utf8.offset(text,2,start) or (#text+1);local character=text:sub(start,nextStart-1);local currentClass=class(code)
		local punctuation=hanging~="none" and (character:match("^[%.,!%?;:%(%)%[%]{}']$")~=nil or character=='"' or character=="“" or character=="”" or character=="、" or character=="。")
		local autoBefore=autospace and previousClass~=nil and ((previousClass=="cjk" and currentClass=="latin") or (previousClass=="latin" and currentClass=="cjk"))
		if #parts==0 or autoBefore or punctuation or parts[#parts].Punctuation then table.insert(parts,{Text=character,Class=currentClass,AutoBefore=autoBefore,Punctuation=punctuation})
		else parts[#parts].Text..=character;parts[#parts].Class=currentClass end
		previousClass=currentClass
	end
	local partByte=1
	if Orientation.mixed(self.Style)then
		local oriented={}
		for _,part in parts do
			local segments=Orientation.parts(part.Text)
			for index,piece in segments do
				local copy=table.clone(part);copy.Text=part.Text:sub(piece.First,piece.Last)
				copy.AutoBefore=index==1 and part.AutoBefore
				copy.Orientation,copy.Alternate=piece.Mode,piece.Alternate
				copy.Segmented=#segments>1
				table.insert(oriented,copy)
			end
		end
		parts=oriented
	end
	if #parts==0 and #hidden>0 then table.insert(parts,{Text=""})end
	for index,part in parts do
		local shy,hiddenSpans={},{}
		for at,source in manual do if (at>partByte-1 or index==1 and at==0)and at<=partByte+#part.Text-1 then shy[at-partByte+1]=source end end
		for _,source in hidden do if (source.Byte>partByte-1 or index==1 and source.Byte==0)and source.Byte<=partByte+#part.Text-1 then table.insert(hiddenSpans,{Node=source.Node,Start=source.Start,Finish=source.Finish,Byte=source.Byte-partByte+1,Text=source.Text,TransformHidden=source.TransformHidden})end end
		table.insert(self.Items,{
			Kind="Word",Text=part.Text,SourceTransform=transform and transform~='none',Style=self.Style,SoftBefore=if index==1 then self.SoftBefore else nil,
			SoftHyphens=if next(shy)then shy else nil,SourceHiddenSpans=if #hiddenSpans>0 then hiddenSpans else nil,
			SourceSpans=if #spans>0 then TextSource.slice(spans,partByte,partByte+#part.Text-1)else nil,SourceGap=if index==1 then self.SourceGap else nil,
			SpaceBefore=index==1 and self.HasWord and self.SpaceStyle~=nil and not self.EmptyGapConsumed,SpaceStyle=if index==1 then self.SpaceStyle else nil,
			AutoSpaceBefore=part.AutoBefore,HangingFirst=part.Punctuation and index==1 and hanging=="first",
			VerticalOrientation=part.Orientation,VerticalAlternate=part.Alternate,VerticalSegmented=part.Segmented,
			HangingLast=part.Punctuation and index==#parts and (hanging=="last" or hanging=="allow-end" or hanging=="force-end"),
		})
		partByte+=#part.Text
	end
	-- Queued segment state is discarded after this lexical group is emitted.
end

function InlineWords.finishWord(self: any)
	if #self.Parts==0 then return end
	table.insert(self.Pending,{Parts=self.Parts,SourceChars=self.SourceChars,HasSource=self.HasSource,Style=self.Style,
		HasWord=self.HasWord,SpaceStyle=self.SpaceStyle,SourceGap=self.SourceGap,SoftBefore=self.SoftBefore,EmptyGapConsumed=self.EmptyGapConsumed})
	self.Parts={};self.SourceChars={};self.SourceGap=nil;self.HasSource=nil
	self.HasWord, self.SpaceStyle, self.SoftBefore = true, nil, nil
	self.EmptyGapConsumed=nil
end

function InlineWords.flushWords(self: any)
	if #self.Pending==0 then return end
	local text,active={},false
	for _,segment in self.Pending do
		if not segment.Item then table.insert(text,table.concat(segment.Parts));active=active or(segment.Style.TextTransform and segment.Style.TextTransform~='none')end
	end
	local context=if active then TextTransform.context(table.concat(text))else nil
	if context then
		context.MathEligible={};local index=0
		for _,segment in self.Pending do if not segment.Item then
			for _,source in segment.SourceChars do index+=1
				if segment.Style.TextTransform=='math-auto'then
					local original=source and source.Node and source.Node.Text
					context.MathEligible[index]=if original then #original>0 and(utf8.offset(original,2)or #original+1)>#original else #context.Codes==1
				end
			end
		end end
	end
	local firstIndex=1
	for _,segment in self.Pending do
		if segment.Item then table.insert(self.Items,segment.Item)
		else
			segment.Items=self.Items;segment.Diagnostic=self.Diagnostic;emitWord(segment,context,firstIndex)
			for _,part in segment.Parts do firstIndex+=utf8.len(part)or #part end
		end
	end
	table.clear(self.Pending)
end

function InlineWords.text(self: any, text: string, style: any,sourceNode: any?,sourceOffset: number?)
	local source=if sourceNode then TextSource.characters(text,sourceNode,sourceOffset)else nil
	for _,span in source or {}do span.SourceStyle=style end
	local collapse=WhiteSpace.collapse(style)
	local cursor = 1
	while cursor <= #text do
		local first, last = text:find("[ \t\r\n]+", cursor)
		if WhiteSpace.expandable(style)then
			-- A preserved separator followed by a combining mark belongs to
			-- that grapheme (CSS Text Decoration emphasis eligibility). Keep
			-- it in the measured word, rather than manufacturing an isolated
			-- combining glyph after a separate space item.
			while last and text:sub(last,last)==' 'do
				local _,clusterLast=utf8.graphemes(text:sub(last))()
				if not clusterLast or clusterLast==1 then break end
				if last>first then last-=1;break end
				first,last=text:find("[ \t\r\n]+",last+clusterLast)
			end
		end
		local stop = if first then first - 1 else #text
		if stop >= cursor then
			if #self.Parts == 0 then self.Style = style
			elseif not sameStyle(self.Style, style) then
				self:finishWord()
				self.Style = style
			end
			table.insert(self.Parts, text:sub(cursor, stop))
			if source then self.HasSource=true end
			for byte in utf8.codes(text:sub(cursor,stop))do table.insert(self.SourceChars,if source then source[cursor+byte-1]else false)end
		end
		if not last then break end
		if collapse=='discard'then cursor=last+1;continue end
		self:finishWord()
		self:flushWords()
		local function gapBetween(a,b)
			if source then for byte=a,b do if source[byte]then self.SourceGap=self.SourceGap or {};table.insert(self.SourceGap,source[byte])end end end
		end
		if collapse~='collapse'then
			-- HTML parsing already normalizes raw CR/LF. An encoded/dynamic CR
			-- is a CSS space; preserve-spaces also converts tabs/LF to spaces.
			local whitespace=text:sub(first,last):gsub('\r',' ')
			if collapse=='preserve-spaces'then whitespace=whitespace:gsub('[\t\n]',' ')end
			local start = 1
			while start <= #whitespace do
				local newline = whitespace:find("\n", start, true)
				local value = whitespace:sub(start, if newline then newline - 1 else #whitespace)
				if value ~= "" then
					if collapse=='preserve-breaks'then
						gapBetween(first+start-1,first+start+#value-2)
						if self.HasWord and not self.SpaceStyle then self.SpaceStyle = style end
					else
						-- break-spaces can wrap after each preserved character.
						local step = if collapse=='break-spaces'then 1 else #value
						for offset = 1, #value, step do
							local part = value:sub(offset, offset + step - 1)
							local _, count = part:gsub(" ", "")
							local spans={}
							local original=text:sub(first+start+offset-2,first+start+offset+#part-3)
							if source then for byte=1,#part do local span=source[first+start+offset+byte-3];if span then table.insert(spans,{Node=span.Node,Start=span.Start,Finish=span.Finish,FirstByte=byte,LastByte=byte})end end end
							table.insert(self.Items, {Kind = "Space", Text = part, Style = style,
								CopyText=if collapse~='preserve-spaces'and original~=part then original else nil,
								SourceSpans=spans,SourceGap=self.SourceGap,
								SpaceCount = count, SpaceBefore = self.HasWord and self.SpaceStyle ~= nil, SpaceStyle = self.SpaceStyle})
							self.SourceGap=nil
							self.HasWord, self.SpaceStyle, self.SoftBefore = true, nil, nil
						end
					end
				end
				if not newline then break end
				self:lineBreak(style)
				start = newline + 1
			end
		else gapBetween(first,last);if self.HasWord and not self.SpaceStyle then self.SpaceStyle = style end end
		cursor = last + 1
	end
end

function InlineWords.image(self: any, item: any)
	self:finishWord()
	self:flushWords()
	item.SpaceBefore = self.HasWord and self.SpaceStyle ~= nil and not self.EmptyGapConsumed
	item.SpaceStyle, item.SoftBefore = self.SpaceStyle, self.SoftBefore
	self.SourceGap=nil
	table.insert(self.Items, item)
	self.HasWord, self.SpaceStyle, self.SoftBefore = true, nil, nil
	self.EmptyGapConsumed=nil
end

-- A float is anchored in the current anonymous inline flow, but consumes no
-- inline advance and does not change the whitespace around its DOM position.
function InlineWords.float(self: any, box: any)
	self:finishWord()
	self:flushWords()
	table.insert(self.Items, {Kind = "Float", FloatBox = box, Style = box.Style})
end

-- Empty inline boxes have font/edge geometry but introduce no text or second
-- collapsed space. A pending space is consumed once at their original position.
function InlineWords.empty(self: any,style: any)
	self:finishWord()
	local space=self.HasWord and self.SpaceStyle~=nil and not self.EmptyGapConsumed
	table.insert(self.Pending,{Item={Kind='Word',Text='',EmptyInline=true,Style=style,
		SpaceBefore=space,SpaceStyle=self.SpaceStyle,SourceGap=if space then self.SourceGap else nil}})
	if space then self.EmptyGapConsumed=true end
end

function InlineWords.softBreak(self: any)
	self:finishWord()
	self.SoftBefore = true
end

function InlineWords.lineBreak(self: any, style: any?)
	self:finishWord()
	self:flushWords()
	table.insert(self.Items, { Kind = "Break", Style = style })
	self.HasWord, self.SpaceStyle, self.SoftBefore = false, nil, nil
	self.EmptyGapConsumed=nil
	self.SourceGap=nil
end

function InlineWords.take(self: any): { any }
	self:finishWord()
	self:flushWords()
	local items = self.Items
	self.Items, self.HasWord, self.SpaceStyle, self.SoftBefore = {}, false, nil, nil
	self.EmptyGapConsumed=nil
	self.SourceGap=nil
	return items
end

-- Only effect scopes that can share a native word label are compared here.
-- References on original source spans update with the ordinary recascade.
function InlineWords.sameTextEffects(a: any,b: any): boolean
	return sameShadows(a.TextShadows,b.TextShadows)
		and (a.TextEmphasisStyle and a.TextEmphasisStyle.Mark)==(b.TextEmphasisStyle and b.TextEmphasisStyle.Mark)
		and a.TextEmphasisColor==b.TextEmphasisColor and a.TextEmphasisColorAlpha==b.TextEmphasisColorAlpha
		and (a.TextEmphasisPosition and a.TextEmphasisPosition.Vertical)==(b.TextEmphasisPosition and b.TextEmphasisPosition.Vertical)
		and (a.TextEmphasisPosition and a.TextEmphasisPosition.Horizontal)==(b.TextEmphasisPosition and b.TextEmphasisPosition.Horizontal)
end

return InlineWords
