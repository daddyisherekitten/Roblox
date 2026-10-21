--!strict
--!optimize 2
-- Pure line wrapping; measurements and Roblox property writes stay separate.
local WordFlow = {}
local WhiteSpace=require(script.Parent.WhiteSpace)

local function spaceAdvance(item: any, x: number): number
	local cursor = x + item.StartTracking
	for spaces, tab in item.Text:gmatch("( *)(\t?)") do
		cursor += #spaces * item.SpaceUnit
		if tab ~= "" and item.TabWidth > 0 then
			local remaining = item.TabWidth - cursor % item.TabWidth
			if remaining < item.TabMinimum then remaining += item.TabWidth end
			cursor += remaining
		end
	end
	return cursor + item.EndTracking - x
end

-- Measure the next indivisible group, including a nowrap/pre inline span.
local function groupEnd(items: {any}, start: number, x: number): number
	local edge = x
	for index = start, #items do
		local item = items[index]
		if item.Kind == "Float" then continue end
		if item.Kind == "Break" or (index > start and item.WrapBefore ~= false) then break end
		if index > start and (item.SpaceBefore or item.Joined) then x += item.SpaceWidth end
		x += if item.Kind == "Space" then spaceAdvance(item, x) else item.Width
		if item.Kind~='Space'or not WhiteSpace.hanging(item.Style)then edge=x end
	end
	return edge
end

function WordFlow.arrange(items: { any }, width: number, strut: any, textAlign: string?, textIndent: any, textAlignLast: string?, split: any?, lineBounds: any?, work: (() -> boolean)?,hyphenProbe: any?,placeFloat: any?): (number, number, number?, any)
	local hasFloat=false
	for _,item in items do if item.Kind=="Float"then hasFloat=true;break end end
	local separate=split~=nil or hasFloat
	local displayed = if separate then {} else items
	local plan=if type(textIndent)=='table'then textIndent else {Amount=textIndent or 0,First=true}
	local function indentFor(affected: boolean): number return if affected~=(plan.Hanging==true)then plan.Amount else 0 end
	local indent=indentFor(plan.First~=false)
	local rightInset=if plan.RTL then indent else 0
	local x, y, farRight = if plan.RTL then 0 else indent, 0, 0
	local ascent, descent = strut.Ascent, strut.Descent
	local line = {}
	local hasWord = false
	local lineIndex = 1
	local firstBaseline: number? = nil
	local topHeight, bottomHeight = nil, nil
	local lineLeft,lineRight=0,width-rightInset
	local activeFragment,pendingRight=nil,0
	local startedFragments={}
	local function closeFragment()
		if activeFragment and #line>0 then line[#line].FragmentPaintRight=pendingRight end
		x+=pendingRight;activeFragment,pendingRight=nil,0
	end
	local function boundsFor(item: any?,needed: number?): (number,number,number)
		if not lineBounds then return 0,width-rightInset,y end
		local a,d=ascent,descent
		if item and not item.LineAlign then a,d=math.max(a,item.Ascent or 0),math.max(d,item.Descent or 0) end
		local height=math.max(a+d,topHeight or 0,bottomHeight or 0,if item and item.LineAlign then item.AlignmentHeight or item.Height else 0)
		local left,right,top=lineBounds(y,height,if #line==0 then needed else nil)
		return left,right-rightInset,top
	end
	local function setBounds(left: number,right: number,top: number)
		local delta=left-lineLeft
		if delta~=0 then
			x+=delta;for _,word in line do word.X+=delta end
		end
		lineLeft,lineRight,y=left,right,top
	end
	if lineBounds then setBounds(boundsFor()) end
	local function finishLine(wrapped: boolean?)
		closeFragment()
		if ascent==-math.huge then ascent=0 end
		if descent==-math.huge then descent=0 end
		if topHeight or bottomHeight then
			local height = math.max(ascent + descent, topHeight or 0, bottomHeight or 0)
			if bottomHeight then ascent = math.max(ascent, bottomHeight - descent) end
			descent = height - ascent
		end
		local baseline = y + ascent
		if firstBaseline == nil then firstBaseline = baseline end
		local last = #line
		while last>0 and line[last].Kind=='Space'and WhiteSpace.hanging(line[last].Style)and(line[last].FragmentPaintRight or 0)==0 do last-=1 end
		local availableWidth=math.max(0,lineRight-lineLeft)
		local contentEdge=if last>0 then line[last].X+line[last].Width+(line[last].FragmentPaintRight or 0)else lineLeft
		local usedEdge=if last==#line then x elseif wrapped then contentEdge else math.max(contentEdge,math.min(x,lineRight))
		local usedWidth=usedEdge-lineLeft
		if last>0 and line[last].HangingLast then usedWidth-=line[last].Width/2 end
		local gaps = 0
		for index, item in line do
			item.JustifySlots = if index > 1 and item.SpaceBefore then 1 else 0
			if item.Kind=='Space'and index<=last and WhiteSpace.expandable(item.Style)then
				gaps += item.SpaceCount
			end
			gaps += item.JustifySlots
		end
		local align = textAlign
		if not wrapped then
			align = if textAlignLast and textAlignLast ~= "auto" then textAlignLast elseif textAlign == "justify" then "left" else textAlign
		end
		local lineRTL=plan.RTL
		if align=='start'or align=='end'then
			local paragraph=line[1]and line[1].BidiParagraph
			lineRTL=if paragraph then paragraph.ParagraphLevel==1 else plan.RTL
			align=if (align=='start')~=(lineRTL==true)then 'left'else 'right'
		end
		-- CSS Text overlong inline contents fall back to start alignment.
		local offset = if usedWidth>availableWidth then (if lineRTL then lineRight-lineLeft-usedWidth else 0)elseif align == "center" then (availableWidth - usedWidth) / 2 elseif align == "right" or align == "end" then availableWidth - usedWidth else 0
		local extra = if align == "justify" and gaps > 0 then math.max(0, availableWidth - usedWidth) / gaps else 0
		local spread = 0
		for index, word in line do
			spread += word.JustifySlots * extra
			word.X += offset + spread
			if index==1 and word.HangingFirst then word.X-=word.Width/2 end
			if word.Kind=='Space'and index<=last and WhiteSpace.expandable(word.Style)then
				local added = word.SpaceCount * extra
				word.Width += added
				spread += added
			end
			word.Y, word.LineBaseline = baseline - word.Baseline + (word.BaselineShift or 0), baseline
			if word.LineAlign then
				word.Y = (if word.LineAlign == "top" then y else y + ascent + descent - (word.AlignmentHeight or word.Height))+(word.LineAlignOffset or 0)
				word.Baseline = baseline - word.Y
			end
			word.LineIndex = lineIndex
			word.LineLeft,word.LineRight,word.LineTop,word.LineHeight=lineLeft,lineRight,y,ascent+descent
			-- Large negative word-spacing can move later words backwards.
			if index <= last then farRight = math.max(farRight, word.X + (word.VisualWidth or word.Width)+(word.FragmentPaintRight or 0)) end
		end
		if last<#line and not wrapped then farRight=math.max(farRight,lineLeft+usedWidth+offset+spread)end
		y += math.max(0, ascent + descent)
		indent=indentFor(not wrapped and plan.EachLine==true)
		rightInset=if plan.RTL then indent else 0
		x, ascent, descent = if plan.RTL then 0 else indent, strut.Ascent, strut.Descent
		topHeight, bottomHeight = nil, nil
		table.clear(line)
		hasWord = false
		lineIndex += 1
		lineLeft,lineRight=0,width-rightInset
		if lineBounds then setBounds(boundsFor()) end
	end
	for index, original in items do
		if work and not work() then return 0, 0, nil, displayed end
		local item = original
		if item.Kind == "Float" then
			-- Out-of-flow boxes are anchored where they occur in the current
			-- inline line. They neither finish that line nor add inline height.
			closeFragment()
			if placeFloat then
				local height=math.max(ascent+descent,topHeight or 0,bottomHeight or 0,0)
				if not placeFloat(item.FloatBox,y,math.max(0,x-lineLeft),height)then return 0,0,nil,displayed end
				setBounds(boundsFor())
			end
		elseif item.Kind == "Break" then
			if separate then table.insert(displayed, item) end
			if #line==0 and item.EmptyLineExtents then ascent=math.max(ascent,item.EmptyLineExtents.Ascent);descent=math.max(descent,item.EmptyLineExtents.Descent)end
			if item.Ascent then ascent, descent = math.max(ascent, item.Ascent), math.max(descent, item.Descent) end
			finishLine()
		else
			if activeFragment~=item.Fragment then closeFragment() end
			local function edges(): (number,number)
				if not item.Fragment then return 0,0 end
				local clone=item.Fragment.Style.BoxDecorationBreak=='clone'
				local left=if activeFragment~=item.Fragment and (clone or not startedFragments[item.Fragment]) then item.FragmentLeft or 0 else 0
				local right=if clone or item.FragmentLast then item.FragmentRight or 0 else 0
				return left,right
			end
			local extraLeft,extraRight=edges()
			local gap = if #line > 0 and (item.SpaceBefore or item.Joined) then item.SpaceWidth else 0
			local canWrap = (item.Kind ~= "Space" and hasWord) or (item.WrapBefore == true and #line > 0)
			-- Only an empty float-constrained line needs the indivisible group's
			-- width. Ordinary/occupied lines must not rescan a nowrap suffix.
			local left,right,top=boundsFor(item,if lineBounds and #line==0 then groupEnd(items,index,0) else nil)
			if canWrap and item.WrapBefore ~= false and not(split and item.Style and item.Style.WordBreak=='break-all'and WhiteSpace.wraps(item.Style))and groupEnd(items, index, x + gap)+left-lineLeft+extraLeft+extraRight > right
				and not(hyphenProbe and hyphenProbe(item,right-x-gap-extraLeft-extraRight))then
				finishLine(true)
				gap = 0
				left,right,top=boundsFor(item,if lineBounds then groupEnd(items,index,0) else nil)
				extraLeft,extraRight=edges()
			end
			setBounds(left,right,top)
			repeat
				local remainder,hyphenated
				if split and item.Kind == "Word" and (item.Width > lineRight - x - gap-extraLeft-extraRight or item.HyphenGroup and groupEnd(items,index,x+gap)+extraLeft+extraRight>lineRight)then
					local reserve=if item.Fragment and item.Fragment.Style.BoxDecorationBreak=='slice' then 0 else extraRight
					local left, right,hyphen = split(item, lineRight - x - gap-extraLeft-reserve, #line > 0)
					if not left and right then
						finishLine(true); gap = 0;setBounds(boundsFor(item,item.Width))
						extraLeft,extraRight=edges()
						continue
					end
					if left then item, remainder,hyphenated = left, right,hyphen;extraLeft,extraRight=edges() end
				end
				item.FragmentPaintLeft=extraLeft;item.FragmentPaintRight=0
				item.X = x + gap+extraLeft
				if item.Kind == "Space" then item.Width = spaceAdvance(item, item.X) else hasWord = true end
				x = item.X + item.Width
				activeFragment,pendingRight=item.Fragment,extraRight
				if item.Fragment then startedFragments[item.Fragment]=true end
				if item.LineAlign == "top" then topHeight = math.max(topHeight or 0, item.AlignmentHeight or item.Height)
				elseif item.LineAlign == "bottom" then bottomHeight = math.max(bottomHeight or 0, item.AlignmentHeight or item.Height)
				else ascent, descent = math.max(ascent, item.Ascent), math.max(descent, item.Descent) end
				table.insert(line, item)
				if separate then table.insert(displayed, item) end
				if not remainder then if hyphenated then finishLine(true)end;break end
				finishLine(true)
				item, gap = remainder, 0
				extraLeft,extraRight=edges()
				setBounds(boundsFor(item,item.Width))
			until false
		end
	end
	-- A trailing <br> ends the current line but doesn't invent another text line.
	if #line > 0 then finishLine() end
	return y, farRight, firstBaseline, displayed
end

return WordFlow
