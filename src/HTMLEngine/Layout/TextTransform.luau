--!strict
-- Full Unicode display mappings. Data is lazy; measurements stay per element.
local LanguageRange=require(script.Parent.Parent.CSS.LanguageRange)
local Work=require(script.Parent.Parent.WorkContext)
local Transform={}
local data: any
local function tables(): any
	if not data then data=require(script.Parent.TextCaseData)end
	return data
end
local function contains(ranges: any,code: number): boolean
	local low,high=1,#ranges/2
	while low<=high do
		local middle=math.floor((low+high)/2);local first,last=ranges[middle*2-1],ranges[middle*2]
		if code<first then high=middle-1 elseif code>last then low=middle+1 else return true end
	end
	return false
end
function Transform.parse(value: string): string?
	if value=='none'or value=='math-auto'then return value end
	local seen,case,count={},nil,0
	for part in value:gmatch('%S+')do
		if seen[part]then return nil end;seen[part]=true;count+=1
		if part=='uppercase'or part=='lowercase'or part=='capitalize'then if case then return nil end;case=part
		elseif part~='full-width'and part~='full-size-kana'then return nil end
	end
	if count==0 then return nil end
	local result={};if case then table.insert(result,case)end
	if seen['full-width']then table.insert(result,'full-width')end
	if seen['full-size-kana']then table.insert(result,'full-size-kana')end
	return table.concat(result,' ')
end
-- Context is shared only by adjacent styled source fragments, never measured.
-- Linear passes keep long combining sequences and fragmented words bounded.
function Transform.context(text: string): any
	local d=tables();local codes,starts,first,previous,nextCased,soft,afterI,above,dot={},{},{},{},{},{},{},{},{}
	local initial,cased,softDotted,iBase=true,false,false,false
	for byte,code in utf8.codes(text)do
		Work.checkpoint();local index=#codes+1;codes[index]=code;starts[index]=byte
		previous[index]=cased;soft[index]=softDotted;afterI[index]=iBase
		if contains(d.Boundaries,code)then initial=true
		elseif contains(d.Letters,code)then first[index]=initial;initial=false end
		-- Nl values (Roman numerals) are letters, unlike superscript No digits.
		if not contains(d.CaseIgnorable,code)then cased=contains(d.Cased,code)end
		local ccc=d.Combining[code]or 0
		if ccc==0 or ccc==230 then softDotted=contains(d.SoftDotted,code);iBase=code==0x49 end
	end
	local following,hasAbove,hasDot=false,false,false
	for index=#codes,1,-1 do
		Work.checkpoint();local code=codes[index];nextCased[index]=following;above[index]=hasAbove;dot[index]=hasDot
		if not contains(d.CaseIgnorable,code)then following=contains(d.Cased,code)end
		local ccc=d.Combining[code]or 0
		if ccc==0 then hasAbove=false;hasDot=false
		elseif ccc==230 then hasAbove=true;hasDot=code==0x307 end
	end
	local title,index={},1
	for _,last in utf8.graphemes(text)do
		Work.checkpoint();local ending=index;local active=false
		while starts[ending]and starts[ending]<=last do active=active or first[ending]==true;ending+=1 end
		if active then for at=index,ending-1 do title[at]=true end end
		index=ending
	end
	return {Codes=codes,First=first,Title=title,Previous=previous,Following=nextCased,Soft=soft,I=afterI,Above=above,Dot=dot}
end
local function language(value: string?): string
	local tag=value or '';local parsed=LanguageRange.compile(tag)
	if parsed.Invalid or parsed.Unknown or tag:find('*',1,true)then return ''end
	local parts=parsed.Parts
	-- Explicit writing-system subtags constrain language tailoring.
	if parts[1]=='tr'or parts[1]=='az'or parts[1]=='lt'or parts[1]=='nl'or parts[1]=='el'or parts[1]=='ga'then
		local expected=if parts[1]=='el'then 'grek'else 'latn'
		for index=2,#parts do local part=parts[index];if #part==1 then break end;if #part==4 and part~=expected then return ''end end
	end
	return parts[1]or ''
end
local function condition(name: string,context: any,index: number,lang: string): boolean
	if name=='tr'or name=='az'or name=='lt'then return name==lang end
	if name=='final_sigma'then return context.Previous[index]and not context.Following[index]end
	if name=='after_soft_dotted'then return context.Soft[index]end
	if name=='after_i'then return context.I[index]end
	if name=='more_above'then return context.Above[index]end
	if name=='not_before_dot'then return not context.Dot[index]end
	return false
end
local function casing(code: number,field: string,context: any,index: number,lang: string): string
	local d=tables()
	for _,rule in d.Conditional do
		if rule.Code~=code then continue end
		local matched=true
		for _,name in rule.Conditions do if not condition(name,context,index,lang)then matched=false;break end end
		if matched then return rule[field]end
	end
	return d[field][code]or utf8.char(code)
end
local function greek(context: any): any
	if context.Greek then return context.Greek end
	local d=tables();local result={};local previousAccent,previousPrecomposed=false,false
	local accents={[0x300]=true,[0x301]=true,[0x302]=true,[0x303]=true,[0x311]=true,[0x342]=true,[0x344]=true}
	local diacritics={[0x300]=true,[0x301]=true,[0x302]=true,[0x303]=true,[0x304]=true,[0x306]=true,[0x308]=true,[0x311]=true,[0x313]=true,[0x314]=true,[0x342]=true,[0x343]=true,[0x344]=true,[0x345]=true}
	local vowels={[0x391]=true,[0x395]=true,[0x397]=true,[0x399]=true,[0x39f]=true,[0x3a5]=true,[0x3a9]=true}
	local index=1
	while index<=#context.Codes do
		Work.checkpoint();local code=context.Codes[index];local parts=d.Greek[code]or{code};local base=parts[1]
		if not(base>=0x370 and base<=0x3ff and not(base>=0x3e2 and base<=0x3ef)and contains(d.Letters,base))then previousAccent=false;index+=1;continue end
		local mapped=d.Upper[base]or utf8.char(base);local upper=utf8.codepoint(mapped)
		local accent,diaeresis,iota=false,false,0
		for part=2,#parts do local mark=parts[part];accent=accent or accents[mark]==true;diaeresis=diaeresis or mark==0x308 or mark==0x344;if mark==0x345 then iota+=1 end end
		local precomposedAccent,precomposedDiaeresis=accent,diaeresis
		local ending=index
		while diacritics[context.Codes[ending+1]]do
			Work.checkpoint()
			ending+=1;local mark=context.Codes[ending]
			accent=accent or accents[mark]==true;diaeresis=diaeresis or mark==0x308 or mark==0x344
			if mark==0x345 then iota+=1 end
		end
		local addDiaeresis=previousAccent and(upper==0x399 or upper==0x3a5)
		local nextAccent=vowels[upper]and accent and not(diaeresis or addDiaeresis)
		local disjunctive=upper==0x397 and accent and iota==0 and not context.Previous[index]and not context.Following[ending]
		if disjunctive then mapped=if precomposedAccent then 'Ή'else 'Ή'
		elseif precomposedDiaeresis or(addDiaeresis and previousPrecomposed)then
			if upper==0x399 then mapped='Ϊ'elseif upper==0x3a5 then mapped='Ϋ'end
		elseif addDiaeresis then mapped..='̈'end
		for part=2,#parts do if parts[part]==0x345 then mapped..='Ι'end end
		result[index]=mapped
		for markIndex=index+1,ending do
			Work.checkpoint()
			local mark=context.Codes[markIndex]
			result[markIndex]=if mark==0x345 then 'Ι'elseif(mark==0x308 or mark==0x344)and not disjunctive and not precomposedDiaeresis then '̈'else ''
		end
		previousAccent,previousPrecomposed=nextAccent,precomposedAccent
		index=ending+1
	end
	context.Greek=result;return result
end
-- Irish orthographic prefix rules, independently expressed from the language
-- examples in Mozilla bugs 1014639/1018805. No state-machine code is imported.
-- Ambiguous h+lowercase-vowel words require a dictionary and remain unchanged.
local lowerVowels={[0x61]=true,[0xe1]=true,[0x65]=true,[0xe9]=true,[0x69]=true,[0xed]=true,[0x6f]=true,[0xf3]=true,[0x75]=true,[0xfa]=true}
local upperVowels={[0x41]=true,[0xc1]=true,[0x45]=true,[0xc9]=true,[0x49]=true,[0xcd]=true,[0x4f]=true,[0xd3]=true,[0x55]=true,[0xda]=true}
local function irish(context: any): any
	if context.Irish then return context.Irish end
	local d=tables();local result,insertBefore={},{};local previousLetter=false
	for index,code in context.Codes do
		Work.checkpoint();local second,third=context.Codes[index+1],context.Codes[index+2]
		if not previousLetter then
			local keep=(code==0x62 and(second==0x70 or second==0x50))
				or(code==0x64 and(second==0x74 or second==0x54))
				or(code==0x67 and(second==0x63 or second==0x43))
				or(code==0x6d and(second==0x62 or second==0x42))
				or(code==0x6e and(second==0x64 or second==0x44 or second==0x67 or second==0x47))
				or((code==0x68 or code==0x6e or code==0x74)and upperVowels[second])
				or(code==0x74 and(second==0x73 or second==0x53)and(lowerVowels[third]or upperVowels[third]or third==0x6c or third==0x4c or third==0x6e or third==0x4e or third==0x72 or third==0x52))
			if keep then result[index]=utf8.char(code)
			elseif code==0x62 and second==0x68 and(third==0x66 or third==0x46)then result[index],result[index+1]='b','h'
			elseif(code==0x6e or code==0x74)and(second==0x2d or second==0x2010 or second==0x2011)and lowerVowels[third]then result[index],result[index+1]=utf8.char(code),''end
			if(code==0x6e or code==0x74)and upperVowels[second]then insertBefore[index+1]=true end
		end
		previousLetter=contains(d.GeneralLetters,code)
	end
	context.Irish={Upper=result,InsertBefore=insertBefore};return context.Irish
end
function Transform.word(text: string,mode: string?,sourceMap: boolean?,lang: string?,context: any?,firstIndex: number?): (string,any?)
	if not utf8.len(text)or(not sourceMap and(not mode or mode=='none'))then return text,nil end
	local active=mode and mode~='none'
	local d=if active then tables()else nil
	context=if active then context or Transform.context(text)else nil
	local languageTag=if active then language(lang)else ''
	local upper=active and mode:find('uppercase',1,true)~=nil
	local lower=active and mode:find('lowercase',1,true)~=nil
	local title=active and mode:find('capitalize',1,true)~=nil
	local wide=active and mode:find('full-width',1,true)~=nil
	local kana=active and mode:find('full-size-kana',1,true)~=nil
	local parts,mapping,offset,localIndex={},if sourceMap then {}else nil,0,0
	for _,code in utf8.codes(text)do
		Work.checkpoint();localIndex+=1;local index=(firstIndex or 1)+localIndex-1
		local mapped=utf8.char(code)
		if upper and languageTag=='el'then mapped=greek(context)[index]or casing(code,'Upper',context,index,languageTag)
		elseif upper or lower then
			mapped=casing(code,if upper then 'Upper'else 'Lower',context,index,languageTag)
			if languageTag=='ga'then
				local rules=irish(context)
				if upper and rules.Upper[index]~=nil then mapped=rules.Upper[index]
				elseif lower and rules.InsertBefore[index]then mapped='-'..mapped end
			end
		elseif title then
			local dutch=languageTag=='nl'and index>1 and context.First[index-1]and(context.Codes[index-1]==0x69 or context.Codes[index-1]==0x49)and(code==0x6a or code==0x4a)
			if context.Title[index]or dutch then mapped=casing(code,'Title',context,index,languageTag)end
		elseif mode=='math-auto'and(if context.MathEligible then context.MathEligible[index]else #context.Codes==1)then mapped=d.Math[code]or mapped end
		if wide or kana then
			local transformed={}
			for _,value in utf8.codes(mapped)do
				local full=if wide then d.Wide[value]or utf8.char(value)else utf8.char(value)
				if kana then local large={};for _,character in utf8.codes(full)do table.insert(large,d.Kana[character]or utf8.char(character))end;full=table.concat(large)end
				table.insert(transformed,full)
			end
			mapped=table.concat(transformed)
		end
		table.insert(parts,mapped)
		if mapping then table.insert(mapping,{FirstByte=offset+1,LastByte=offset+#mapped,Hidden=mapped==''});offset+=#mapped end
	end
	return table.concat(parts),mapping
end
return Transform
