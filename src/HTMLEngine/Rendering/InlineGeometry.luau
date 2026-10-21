--!strict
-- CSSOM boxes of retained inline flow. Queries never create GUI objects or
-- reflow words; source spans keep neutral inline boundaries after word merging.
local Work=require(script.Parent.Parent.WorkContext)
local Fonts=require(script.Parent.Parent.Layout.FontMetrics)
local Measure=require(script.Parent.Parent.Layout.TextMeasure)
local Inline={}
local LIMIT=131072
local function within(source: any,node: any): boolean
	local depth=0
	while source do
		if source==node then return true end
		depth+=1;assert(depth<=256,'Inline geometry ancestor budget exceeded')
		source=source.Parent
	end
	return false
end
local function prefix(item: any,last: number): number
	if last<=0 then return 0 end
	if last>=#item.Text then return item.Width end
	local key=item.InlineGeometryWidths
	if not key or key.Text~=item.Text or key.Font~=item.FontFace or key.Size~=item.TextSize or key.Width~=item.Width then
		key={Text=item.Text,Font=item.FontFace,Size=item.TextSize,Width=item.Width,Widths={},Count=0};item.InlineGeometryWidths=key
	end
	if key.Widths[last]~=nil then return key.Widths[last]end
	local width
	if item.Glyphs then
		local byte=0;width=0
		for _,glyph in item.Glyphs do
			if byte>=last then width=glyph.X;break end
			byte+=#glyph.Text;width=glyph.X+glyph.Width
		end
	else
		local bounds,message=Measure.measure(item.Text:sub(1,last),item.FontFace,item.TextSize,0)
		assert(bounds,'Inline geometry prefix measurement failed: '..tostring(message));width=bounds.X
	end
	if key.Count>=256 then table.clear(key.Widths);key.Count=0 end
	key.Widths[last]=width;key.Count+=1;return width
end
function Inline.collect(owner: any,node: any,style: any): any
	local result={};local count=0;local metrics=Fonts.resolve(style)
	for _,run in owner.Children or{}do
		if run.Kind~='Words'then continue end
		Work.checkpoint()
		local decorated=false
		for _,slot in run.FragmentPool or{}do
			if slot.Active and slot.OwnerStyle.Node==node then
				assert(#result<4096,'Inline geometry rectangle budget exceeded')
				table.insert(result,{Host=owner.Node,X=slot.LocalX,Y=slot.LocalY,Width=slot.Width,Height=slot.Height})
				decorated=true
			end
		end
		if decorated then continue end
		local groups={};local order={}
		local function add(item,left,right)
			local line=item.LineIndex;if not line then return end
			local x=(run.LayoutX or 0)+item.X
			local group=groups[line]
			if not group then
				group={Host=owner.Node,X=x+left,Y=(run.LayoutY or 0)+item.LineBaseline+(style.InlineShift or 0)-metrics.Baseline,
					Width=right-left,Height=metrics.TextSize};groups[line]=group;table.insert(order,line)
			else local edge=math.max(group.X+group.Width,x+right);group.X=math.min(group.X,x+left);group.Width=edge-group.X end
		end
		-- Ellipsis changes glyph paint only; CSSOM retains the finished flow.
		local items=run.FlowPaintState and run.FlowPaintState.Items or run.Items
		local previous
		for _,item in items do
			count+=1;assert(count<=LIMIT,'Inline geometry source budget exceeded');Work.checkpoint()
			if item.Kind=='Break'then previous=nil;continue end
			if item.Node and within(item.Node,node)then add(item,0,item.Width)
			elseif item.EmptyInline and item.Style.Node==node then add(item,0,0)
			else
				for _,span in item.SourceSpans or{}do
					count+=1;assert(count<=LIMIT,'Inline geometry source budget exceeded')
					if within(span.Node,node)then add(item,prefix(item,span.FirstByte-1),prefix(item,span.LastByte))end
				end
			end
			if item.SpaceBefore and previous and previous.LineIndex==item.LineIndex then
				local right=-(item.FragmentPaintLeft or 0)
				local gap=item.X-previous.X-previous.Width-(previous.FragmentPaintRight or 0)+(right)
    -- A collapsed sequence occupies the box of its first source character;
    -- later whitespace inside an otherwise empty span has no advance.
    local span=item.SourceGap and item.SourceGap[1]
    if span and within(span.Node,node)then add(item,right-gap,right)end
			end
			previous=item
		end
		for _,line in order do assert(#result<4096,'Inline geometry rectangle budget exceeded');table.insert(result,groups[line])end
	end
	return result
end
return Inline
