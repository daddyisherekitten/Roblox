--!strict
-- Actual Unicode17 conformance files; no GUI mocks or renderer claims.
return function(Bidi,typeCorpus,characterCorpus)
	local function numbers(value)
		local result={};for part in value:gmatch('%S+')do table.insert(result,if part=='x'then false else tonumber(part))end;return result
	end
	local function compare(result,expectedLevels,expectedOrder,key,expectedBase)
		if expectedBase then assert(result.ParagraphLevel==expectedBase,'Paragraph level '..key)end
		assert(#result.Levels==#expectedLevels,'Level length '..key)
		for index,level in expectedLevels do
			assert(level==false or result.Levels[index]==level,'Level '..key..' index '..index..' => '..tostring(result.Levels[index])..' ~= '..tostring(level))
		end
		assert(#result.Order==#expectedOrder,'Order length '..key)
		for position,index in expectedOrder do assert(result.Order[position]==index+1,'Order '..key..' position '..position..' => '..tostring(result.Order[position])..' ~= '..(index+1))end
	end
	local levels,order={},{};local typeCases,characterCases=0,0
	for line in (typeCorpus or ''):gmatch('[^\r\n]+')do
		if line:sub(1,1)=='#'then continue end
		if line:sub(1,8)=='@Levels:'then levels=numbers(line:sub(9))
		elseif line:sub(1,9)=='@Reorder:'then order=numbers(line:sub(10))
		elseif line:sub(1,1)~='@'then
			local input,bits=line:match('^([^;]+);%s*(%x+)');if not input then continue end
			local types={};for kind in input:gmatch('%S+')do table.insert(types,kind)end
			local mask=tonumber(bits,16)
			for _,case in {{1,2},{2,0},{4,1}}do
				if bit32.band(mask,case[1])~=0 then compare(Bidi.types(types,case[2]),levels,order,input..'/'..case[2]);typeCases+=1 end
			end
		end
	end
	for line in (characterCorpus or ''):gmatch('[^\r\n]+')do
		if line:sub(1,1)=='#'then continue end
		local codeList,base,paragraph,levelList,orderList=line:match('^([^;]+);([^;]+);([^;]+);([^;]+);(.*)$')
		if not codeList then continue end
		local chars={};for value in codeList:gmatch('%x+')do table.insert(chars,utf8.char(tonumber(value,16)))end
		compare(Bidi.paragraph(table.concat(chars),tonumber(base)),numbers(levelList),numbers(orderList),codeList..'/'..base,tonumber(paragraph));characterCases+=1
	end
	local source='A😀אב';local result=Bidi.paragraph(source,0)
	assert(result.Text==source and result.Source[2].Start==1 and result.Source[2].Finish==3 and result.Source[3].Start==3,'Logical original astral UTF16 offsets remain intact')
	assert(Bidi.mirror(0x28,1)==0x29 and Bidi.mirror(0x28,0)==0x28,'Mirroring is a separate shaped-glyph instruction')
	local mixed=Bidi.paragraph('אב 12 AB',1);local restored={}
	for position,index in mixed.Order do assert(mixed.Inverse[index]==position);restored[index]=true end
	for index in mixed.Source do assert(restored[index])end
	assert(mixed.Runs[1].Direction=='ltr'and mixed.Runs[#mixed.Runs].Direction=='rtl','Directional runs include original logical indices')
	local line=Bidi.line(Bidi.paragraph('אב  AB  ',0),1,4)
	assert(line.Levels[3]==0 and line.Levels[4]==0,'Actual soft line ending resets spaces independently of paragraph resolution')
	local document=Bidi.resolve('אב\nA😀\n\nגד',2)
	assert(#document.Paragraphs==4 and document.Paragraphs[1].ParagraphLevel==1 and document.Paragraphs[2].ParagraphLevel==0 and document.Paragraphs[4].ParagraphLevel==1,'P1 separates paragraphs and P2/P3 chooses each original paragraph direction')
	assert(document.Source[5].Start==4 and document.Source[5].Finish==6 and document.Paragraphs[4].Source[1].Start==8,'Global source offsets survive astral characters and empty paragraphs')
	local p4=document.Paragraphs[4];local projected=Bidi.line(p4,1,2)
	assert(projected.Order[1]==2 and p4.IndexOffset+projected.Order[1]==#document.Source,'Local line order explicitly maps to global source index')
	local isolated=Bidi.resolve('A\u{202e}BC\u{202c}D',0)
	assert(#isolated.Source==6 and #isolated.Order==4 and isolated.Levels[2]==false and isolated.Levels[5]==false,'Removed formatting controls retain source positions and are excluded only from visual order')
	assert(#Bidi.resolve('',2).Paragraphs==1 and #Bidi.paragraph('',1).Runs==0,'Empty paragraphs preserve an explicit base without fabricated visual runs')
	local inputClasses,inputCodes={'R','L'},{0x5d0,0x41};local independent=Bidi.types(inputClasses,1,inputCodes)
	inputClasses[1]='L';inputCodes[1]=0x42
	assert(independent.InitialTypes[1]=='R'and independent.Codes[1]==0x5d0,'Resolved source/code data cannot be changed by mutating input arrays')
	for _,callback in {function()Bidi.types({'L'},3)end,function()Bidi.types({'wrong'},0)end,function()Bidi.types({'B','L'},0)end,function()Bidi.types({'L'},0,{})end,function()Bidi.types({'L'},0,{-1})end,function()Bidi.line(independent,1.5,2)end}do assert(not pcall(callback),'Invalid paragraph/class/source/line input must fail before visual projection')end
	if typeCorpus then assert(typeCases==770241,'The full BidiTest corpus must be tested')end
	if characterCorpus then assert(characterCases==91707,'The full BidiCharacterTest corpus must be tested')end
	print('Unicode17 bidi standalone conformance: '..typeCases..' class/base cases, '..characterCases..' character paragraphs; original source and directional runs retained')
end
