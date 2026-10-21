--!strict
local Initial={}
function Initial.parse(text)
	if text=='normal'then return 'normal'end
	local parts={};for part in text:gmatch('%S+')do table.insert(parts,part)end
	local size=tonumber(parts[1]);if not size or size<1 or size>100 or #parts>2 then return nil end
	local sink=if parts[2]=='drop'then math.floor(size)elseif parts[2]=='raise'then 1 elseif parts[2]then tonumber(parts[2])else math.floor(size)
	if not sink or sink<1 or sink%1~=0 or sink>100 then return nil end
	return {Size=size,Sink=sink}
end
-- Include surrounding common quotation marks in the typographic initial.
-- Graphemes retain combining marks/surrogate-pair boundaries and source bytes.
function Initial.prefix(text)
	local leading=text:match('^[ \t\r\n\f]*')or'';local finish=#leading
	local punctuation={['"']=true,["'"]=true,['“']=true,['”']=true,['‘']=true,['’']=true,['«']=true,['»']=true,['(']=true,[')']=true,['[']=true,[']']=true}
	local letter=false
	for first,last in utf8.graphemes(text:sub(#leading+1))do
		local char=text:sub(#leading+first,#leading+last)
		if letter and not punctuation[char]then break end
		finish=#leading+last;if not punctuation[char]then letter=true end
	end
	if not letter then return nil end
	local offset=0;for _,code in utf8.codes(text:sub(1,finish))do offset+=if code>=0x10000 then 2 else 1 end
	return #leading+1,finish,offset
end
return Initial
