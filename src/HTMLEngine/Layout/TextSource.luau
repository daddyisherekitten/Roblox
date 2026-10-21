--!strict
-- Original DOM UTF-16 offsets attached to transformed UTF-8 display fragments.
local Source={}
function Source.characters(text: string,node: any,startOffset: number?): any
	local result,offset={},startOffset or 0
	for byte,code in utf8.codes(text)do
		local finish=offset+(if code>=0x10000 then 2 else 1)
		result[byte]={Node=node,Start=offset,Finish=finish};offset=finish
	end
	return result
end
function Source.slice(spans: any,first: number,last: number): any
	if not spans then return nil end
	local result={}
	-- Display spans are ordered. Binary-search the first overlap so many CJK
	-- autospace fragments or narrow wrapped words do not rescan an entire word.
	local low,high=1,#spans+1
	while low<high do local middle=math.floor((low+high)/2);if spans[middle].LastByte<first then low=middle+1 else high=middle end end
	for index=low,#spans do
		local span=spans[index];if span.FirstByte>last then break end
		if span.LastByte>=first and span.FirstByte<=last then
			table.insert(result,{Node=span.Node,Start=span.Start,Finish=span.Finish,
				FirstByte=math.max(span.FirstByte,first)-first+1,LastByte=math.min(span.LastByte,last)-first+1,CopyText=span.CopyText,SourceStyle=span.SourceStyle})
		end
	end
	return result
end
return Source
