--!strict
-- Standalone Unicode17 UAX9 resolver through L2. Original codepoints and
-- UTF16/UTF8 positions are retained; this module does not claim GUI/shaping.
local Class=require(script.Parent.BidiClass)
local Data=require(script.Parent.BidiData)
local Explicit=require(script.Parent.BidiExplicit)
local Sequences=require(script.Parent.BidiSequences)
local Resolve=require(script.Parent.BidiResolve)
local Work=require(script.Parent.Parent.WorkContext)
local Bidi={Version='17.0.0'}
local whitespace={WS=true,LRI=true,RLI=true,FSI=true,PDI=true}
local valid={L=true,R=true,AL=true,EN=true,ES=true,ET=true,AN=true,CS=true,NSM=true,BN=true,B=true,S=true,WS=true,ON=true,LRE=true,RLE=true,LRO=true,RLO=true,PDF=true,LRI=true,RLI=true,FSI=true,PDI=true}
function Bidi.line(paragraph: any,first: number?,last: number?): any
	local original,base=paragraph.InitialTypes,paragraph.ParagraphLevel
	local start,limit=first or 1,last or #original
	assert(start%1==0 and limit%1==0 and start>=1 and limit<=#original and(start<=limit or #original==0 and start==1 and limit==0),'Invalid bidi line bounds')
	-- A line projection copies only its own interval. Repeated line layout is
	-- linear in paragraph length, rather than copying the paragraph per line.
	local levels={};for index=start,limit do Work.checkpoint();levels[index]=paragraph.ResolvedLevels[index]end
	local function trailing(index: number): boolean
		return whitespace[original[index]]==true or Explicit.Removed[original[index]]==true
	end
	for index=start,limit do
		if original[index]=='B'or original[index]=='S'then
			levels[index]=base;local at=index-1
			while at>=start and trailing(at)do Work.checkpoint();levels[at]=base;at-=1 end
		end
	end
	local at=limit
	while at>=start and trailing(at)do Work.checkpoint();levels[at]=base;at-=1 end
	local order,maximum,minimumOdd={},0,math.huge
	for index=start,limit do
		Work.checkpoint()
		if Explicit.Removed[original[index]]then levels[index]=false;continue end
		table.insert(order,index);local level=levels[index];maximum=math.max(maximum,level)
		if level%2==1 then minimumOdd=math.min(minimumOdd,level)end
	end
	if minimumOdd<math.huge then
		for level=maximum,minimumOdd,-1 do
			local position=1
			while position<=#order do
				Work.checkpoint()
				if levels[order[position]]<level then position+=1;continue end
				local ending=position;while order[ending+1]and levels[order[ending+1]]>=level do ending+=1 end
				local left,right=position,ending;while left<right do order[left],order[right]=order[right],order[left];left+=1;right-=1 end
				position=ending+1
			end
		end
	end
	local inverse,runs={},{}
	for position,index in order do
		Work.checkpoint();inverse[index]=position
		local level=levels[index];local direction=if level%2==0 then 'ltr'else 'rtl';local run=runs[#runs]
		local step=if direction=='ltr'then 1 else -1
		if not run or run.Level~=level or index~=run.Indices[#run.Indices]+step then
			run={Level=level,Direction=direction,Indices={},VisualStart=position};table.insert(runs,run)
		end
		table.insert(run.Indices,index);run.VisualEnd=position
	end
	return {First=start,Last=limit,Levels=levels,Order=order,Inverse=inverse,Runs=runs}
end
function Bidi.types(original: any,base: number?,codes: any?): any
	assert(base==nil or base==0 or base==1 or base==2,'Bidi paragraph base must be 0, 1 or auto (2)')
	if codes then
		assert(#codes==#original,'Bidi codepoint/class length mismatch')
		for _,code in codes do Work.checkpoint();assert(type(code)=='number'and code>=0 and code<=0x10ffff and code%1==0,'Invalid bidi codepoint')end
		codes=table.clone(codes)
	end
	for index,kind in original do
		assert(valid[kind],'Invalid bidi class: '..tostring(kind))
		assert(kind~='B'or index==#original,'Bidi.types accepts a single paragraph; B may only end it')
	end
	local initial=table.clone(original);local closing,opening=Explicit.matches(initial)
	local paragraphLevel=if base==nil or base==2 then Explicit.base(initial,closing)else base
	local types,levels=Explicit.levels(initial,paragraphLevel,closing)
	for _,sequence in Sequences.build(initial,types,levels,paragraphLevel,closing,opening)do
		Resolve.weak(sequence)
		if codes then Resolve.brackets(sequence,initial,codes,Data)end
		Resolve.neutral(sequence);Resolve.apply(sequence,types,levels)
	end
	local result={InitialTypes=initial,Types=types,ResolvedLevels=levels,ParagraphLevel=paragraphLevel,Codes=codes,MatchingPDI=closing,MatchingIsolate=opening}
	local line=Bidi.line(result);result.Levels,result.Order,result.Inverse,result.Runs=line.Levels,line.Order,line.Inverse,line.Runs
	return result
end
local function characters(text: string): (any,any,any)
	local codes,types,source={}, {},{};local offset=0
	for first,code in utf8.codes(text)do
		Work.checkpoint();local finish=(utf8.offset(text,2,first)or #text+1)-1
		table.insert(codes,code);table.insert(types,Class.get(code));table.insert(source,{FirstByte=first,LastByte=finish,Start=offset,Finish=offset+(if code>0xffff then 2 else 1)})
		offset+=if code>0xffff then 2 else 1
	end
	return codes,types,source
end
function Bidi.paragraph(text: string,base: number?): any
	local codes,types,source=characters(text)
	local result=Bidi.types(types,base,codes);result.Text,result.Source=text,source
	return result
end
-- P1 paragraph separation preserves one global source index space. Per-line
-- operations still take a paragraph object and its local codepoint bounds.
function Bidi.resolve(text: string,base: number?): any
	local codes,types,source=characters(text)
	local result={Text=text,Codes=codes,Source=source,Paragraphs={},Levels={},Order={},Inverse={},Runs={}}
	local first=1
	local function paragraph(last: number)
		local localCodes,localTypes,localSource={},{},{}
		for index=first,last do Work.checkpoint();table.insert(localCodes,codes[index]);table.insert(localTypes,types[index]);table.insert(localSource,source[index])end
		local value=Bidi.types(localTypes,base,localCodes);value.Source=localSource;value.IndexOffset=first-1
		value.Text=if source[first]then text:sub(source[first].FirstByte,source[last].LastByte)else ''
		table.insert(result.Paragraphs,value)
		for index,level in value.Levels do result.Levels[first+index-1]=level end
		for _,index in value.Order do local global=first+index-1;table.insert(result.Order,global);result.Inverse[global]=#result.Order end
		for _,run in value.Runs do
			local indices={};for _,index in run.Indices do table.insert(indices,first+index-1)end
			table.insert(result.Runs,{Level=run.Level,Direction=run.Direction,Indices=indices,Paragraph=value})
		end
		first=last+1
	end
	for index,kind in types do if kind=='B'then paragraph(index)end end
	if first<=#types or #types==0 then paragraph(#types)end
	return result
end
function Bidi.mirror(code: number,level: number): number
	return if level%2==1 then Data.Mirrors[code]or code else code
end
return Bidi
