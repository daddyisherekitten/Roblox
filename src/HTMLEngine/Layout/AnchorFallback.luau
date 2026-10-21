--!strict
local Anchor=require(script.Parent.Parent.CSS.AnchorPosition)
local Work=require(script.Parent.Parent.WorkContext)
local Fallback={}
function Fallback.choose(box,base,containing,place,fits,space)
	local recipes=base.PositionTryFallbacks or{}
	if #recipes==0 then box.AnchorTryLast=nil;return place(base)end
	local key=Anchor.tryKey(base)
	local previous=if box.AnchorTryKey==key and box.AnchorTryContaining==containing.Owner then box.AnchorTryLast else nil
	box.AnchorTryLast=previous
	local currentStyle=if previous and previous~=0 then Anchor.variant(base,recipes[previous],containing)else base
	local current=place(currentStyle or base)
	local currentFits=fits(current)
	local order=base.PositionTryOrder or 'normal'
	if (previous~=nil or order=='normal')and currentFits then
		box.AnchorTryLast=if currentStyle then previous or 0 else 0
		box.AnchorTryKey,box.AnchorTryContaining=key,containing.Owner
		return current
	end
	local options={{Style=base,Index=0}}
	for index,recipe in recipes do
		Work.checkpoint();local style=Anchor.variant(base,recipe,containing)
		if style then table.insert(options,{Style=style,Index=index})end
	end
	if order~='normal'then
		local vertical=containing.Style and containing.Style.WritingMode~='horizontal-tb'and containing.Style.WritingMode~=nil
		local horizontal=order=='most-width'or order=='most-inline-size'and not vertical or order=='most-block-size'and vertical
		for _,option in options do local w,h=space(option.Style);option.Space=if horizontal then w else h end
		table.sort(options,function(a,b)return if a.Space==b.Space then a.Index<b.Index else a.Space>b.Space end)
	end
	local selected
	for _,option in options do
		Work.checkpoint()
		if option.Index~=previous and not (option.Index==0 and currentStyle==base and not currentFits)then
			local candidate=place(option.Style)
			if fits(candidate)then box.AnchorTryLast=option.Index;selected=candidate;break end
		end
	end
	box.AnchorTryKey,box.AnchorTryContaining=key,containing.Owner
	-- Failed trial layouts must not leave the box at the last trial's size.
	return selected or place(currentStyle or base)
end
return Fallback
