--!strict
-- Liang pattern matching; immutable language data, never shared text measurements.
local LanguageRange=require(script.Parent.Parent.CSS.LanguageRange)
local Characters=require(script.Parent.HyphenationPatterns.Characters)
local Work=require(script.Parent.Parent.WorkContext)
local Hyphenation={}
local loaders={
	enUS=function()return require(script.Parent.HyphenationPatterns.enUS)end,
	enGB=function()return require(script.Parent.HyphenationPatterns.enGB)end,
	de1996=function()return require(script.Parent.HyphenationPatterns.de1996)end,
	de1901=function()return require(script.Parent.HyphenationPatterns.de1901)end,
	deCH1901=function()return require(script.Parent.HyphenationPatterns.deCH1901)end,
	fr=function()return require(script.Parent.HyphenationPatterns.fr)end,
	es=function()return require(script.Parent.HyphenationPatterns.es)end,
	it=function()return require(script.Parent.HyphenationPatterns.it)end,
	nl=function()return require(script.Parent.HyphenationPatterns.nl)end,
	pt=function()return require(script.Parent.HyphenationPatterns.pt)end,
	da=function()return require(script.Parent.HyphenationPatterns.da)end,
	uk=function()return require(script.Parent.HyphenationPatterns.uk)end,
	pl=function()return require(script.Parent.HyphenationPatterns.pl)end,
	sl=function()return require(script.Parent.HyphenationPatterns.sl)end,
	et=function()return require(script.Parent.HyphenationPatterns.et)end,
	lt=function()return require(script.Parent.HyphenationPatterns.lt)end,
	af=function()return require(script.Parent.HyphenationPatterns.af)end,
}
local primary={en="enUS",de="de1996",fr="fr",es="es",it="it",nl="nl",pt="pt",da="da",uk="uk",pl="pl",sl="sl",et="et",lt="lt",af="af"}
local resources={}
-- A bounded immutable linguistic cache is independent of pages. Width/font
-- measurements and chosen breaks are retained solely by each source word.
local buckets,bucketOrder={},{}
local MAX_BUCKETS=64
function Hyphenation.language(style: any): string
	return if style.Node then LanguageRange.language(style.Node)else style.Language or ""
end
local function resource(language: string): any?
	local range=LanguageRange.compile(language)
	if range.Invalid or range.Unknown then return nil end
	local parts=range.Parts
	local key=primary[parts[1]]
	-- Explicit spelling variants precede geographic defaults. Non-Latin
	-- transliterations do not accidentally receive Latin pattern resources.
	local significant={}
	for _,part in parts do
		if #part==1 then break end
		table.insert(significant,part)
		if #part==4 and part:match("^[a-z]+$")and part~=(if parts[1]=="uk"then "cyrl"else "latn")then return nil end
	end
	if parts[1]=="en"then
		for _,part in significant do if part=="gb"or part=="au"or part=="nz"or part=="ie"then key="enGB"end end
	elseif parts[1]=="de"then
		for _,part in significant do if part=="1901"then key="de1901"end end
		if key=="de1901"then for _,part in significant do if part=="ch"then key="deCH1901"end end end
	end
	if not key then return nil end
	if not resources[key]then resources[key]=loaders[key]()end
	return resources[key]
end
local function bucket(data: any,key: string): any?
	local source=data.Buckets[key];if not source then return nil end
	local all=buckets[data];local existing=all and all[key]
	if existing then return existing end
	local result={}
	for name,weights in source:gmatch("([^\n:]+):([0-9]+)")do Work.checkpoint();result[name]=weights end
	if #bucketOrder>=MAX_BUCKETS then
		local removed=table.remove(bucketOrder,1);local group=buckets[removed.Data]
		group[removed.Key]=nil;if not next(group)then buckets[removed.Data]=nil end
	end
	all=buckets[data]or {};buckets[data]=all;all[key]=table.freeze(result)
	table.insert(bucketOrder,{Data=data,Key=key})
	return all[key]
end
local function patternPoints(data: any,letters: any): any
	local text=table.concat(letters)
	local exception=data.Exceptions[text]
	if exception then local points={};for at in exception:gmatch("%d+")do points[tonumber(at)]=true end;return points end
	local characters={"."};for _,letter in letters do table.insert(characters,letter)end;table.insert(characters,".")
	local offsets={}
	local joined=table.concat(characters);local position=1
	for index,char in characters do offsets[index]=position;position+=#char end;offsets[#characters+1]=position
	local scores={}
	for first=1,#characters do
		Work.checkpoint()
		local one=bucket(data,characters[first])
		local two=if first<#characters then bucket(data,characters[first]..characters[first+1])else nil
		for last=first,math.min(#characters,first+31)do
			local name=joined:sub(offsets[first],offsets[last+1]-1)
			local weights=(if last==first then one else two)
			weights=weights and weights[name]
			if weights then for at=1,#weights do
				local value=weights:byte(at)-48;local slot=first+at-1
				if value>(scores[slot]or 0)then scores[slot]=value end
			end end
		end
	end
	local points={}
	for index=data.Left,#letters-data.Right do if (scores[index+2]or 0)%2==1 then points[index]=true end end
	return points
end
function Hyphenation.points(text: string,language: string,limits: any?): any
	local result={};local data=resource(language);if not data or #text>4096 then return result end
	limits=limits or {5,2,2}
	local total=if type(limits[1])=="number"then limits[1]else 5
	local left=if type(limits[2])=="number"then limits[2]else 2
	local right=if type(limits[3])=="number"then limits[3]else 2
	local letters,ends,counts={},{},{}
	local count=0
	local function flush()
		if #letters>0 and #letters<=256 and count>=total then
			local points=patternPoints(data,letters)
			for index in points do if counts[index]>=left and count-counts[index]>=right then result[ends[index]]=true end end
		end
		table.clear(letters);table.clear(ends);table.clear(counts);count=0
	end
	for first,last in utf8.graphemes(text)do
		Work.checkpoint()
		local char=Characters.Mappings[text:sub(first,last)]
		if char and data.Alphabet[char]then
			table.insert(letters,char);table.insert(ends,last)
			if Characters.Counted[char]then count+=1 end
			table.insert(counts,count)
		else flush()end
	end
	flush();return result
end
-- Whole lexical words span adjacent inline style fragments. Word boundaries
-- stay independent of colors/fonts, while each break retains its own style.
function Hyphenation.prepare(run: any)
	local group={}
	local function finish()
		if #group==0 then return end
		local active=false
		for _,item in group do
			item.HyphenPoints,item.HyphenAtEnd,item.HyphenGroup=nil,nil,nil
			if item.Style.Hyphens=="auto"or item.SoftHyphens then active=true end
		end
		if not active then table.clear(group);return end
		local values,manual,offset={},{},0
		local hasPoints=false
		for _,item in group do
			table.insert(values,item.Text)
			for at,span in item.SoftHyphens or {}do manual[offset+at]=span end
			offset+=#item.Text
		end
		local text=table.concat(values);offset=0
		local manualPositions={};for at in manual do table.insert(manualPositions,at)end;table.sort(manualPositions)
		local manualKey=table.concat(manualPositions,",")
		for _,item in group do
			Work.checkpoint()
			local style=item.Style;local language=Hyphenation.language(style)
			local limits=style.HyphenateLimitChars or {5,2,2}
			local key=text.."\0"..language.."\0"..tostring(style.Hyphens)..":"..table.concat(limits,",")..":"..manualKey..":"..tostring(style.WordBreak)..":"..tostring(style.LineBreak)
			local cache=item.HyphenationCache
			if not cache or cache.Key~=key then
				local points={}
				if style.Hyphens~="none"and style.WordBreak~="break-all"and style.LineBreak~="anywhere"then
					if next(manual)then for at in manual do points[at]=true end
					elseif style.Hyphens=="auto"then points=Hyphenation.points(text,language,limits)end
				end
				local fallback=if next(manual)and style.Hyphens=="auto"and style.WordBreak~="break-all"and style.LineBreak~="anywhere"then Hyphenation.points(text,language,limits)else nil
				cache={Key=key,Points=points,Fallback=fallback};item.HyphenationCache=cache
			end
			item.HyphenPoints={};item.HyphenAtEnd=nil
			item.HyphenFallbackPoints=nil
			for at,span in cache.Points do
				if at>offset and at<=offset+#item.Text then
					local localAt=at-offset
					local source=manual[at]or span
					if localAt==#item.Text and at<#text then item.HyphenAtEnd=source
					elseif localAt<#item.Text then item.HyphenPoints[localAt]=source end
				end
			end
			if cache.Fallback then
				item.HyphenFallbackPoints={}
				for at in cache.Fallback do if at>offset and at<offset+#item.Text then item.HyphenFallbackPoints[at-offset]=true end end
			end
			hasPoints=hasPoints or next(item.HyphenPoints)~=nil or item.HyphenAtEnd~=nil
			offset+=#item.Text
		end
		local grouped=if hasPoints and #group>1 then table.clone(group)else nil
		for _,item in group do item.HyphenGroup=grouped end
		table.clear(group)
	end
	for _,item in run.Items do
		if item.Kind~="Word"or item.EmptyInline then finish();continue end
		if item.SpaceBefore or item.SoftBefore or item.AutoSpaceBefore then finish()end
		table.insert(group,item)
	end
	finish()
end
return Hyphenation
