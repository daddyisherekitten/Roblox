--!strict
-- UTF-8 XML 1.0 scanner. No HTML case folding, repair rules or entity loading.
local XML={}
XML.__index=XML
function XML.fail(code: string,message: string,position: number)
	error({Code=code,Message=message,Position=position},0)
end
local function character(n: number): boolean
	return n==9 or n==10 or n==13 or (n>=32 and n<=0xD7FF) or (n>=0xE000 and n<=0xFFFD) or (n>=0x10000 and n<=0x10FFFF)
end
local function initial(n: number): boolean
	return n==95 or (n>=65 and n<=90) or (n>=97 and n<=122) or (n>=0xC0 and n<=0xD6)
		or (n>=0xD8 and n<=0xF6) or (n>=0xF8 and n<=0x2FF) or (n>=0x370 and n<=0x37D)
		or (n>=0x37F and n<=0x1FFF) or (n>=0x200C and n<=0x200D) or (n>=0x2070 and n<=0x218F)
		or (n>=0x2C00 and n<=0x2FEF) or (n>=0x3001 and n<=0xD7FF) or (n>=0xF900 and n<=0xFDCF)
		or (n>=0xFDF0 and n<=0xFFFD) or (n>=0x10000 and n<=0xEFFFF)
end
function XML.name(raw: string,position: number): (string,string)
	local prefix,localName=raw:match("^([^:]+):([^:]+)$")
	if not prefix then prefix,localName="",raw end
	for _,part in (if prefix=="" then {localName} else {prefix,localName}) do
		if part=="" then XML.fail("invalid-name","Empty XML name",position) end
		for index,n in utf8.codes(part) do
			if not initial(n) and not (index>1 and ((n>=48 and n<=57) or n==45 or n==46 or n==0xB7 or (n>=0x300 and n<=0x36F) or (n>=0x203F and n<=0x2040))) then
				XML.fail("invalid-name","Invalid XML qualified name: "..raw,position)
			end
		end
	end
	return prefix,localName
end
local function decode(raw: string,position: number): string
	local parts={}; local cursor=1
	while cursor<=#raw do
		local at=raw:find("&",cursor,true)
		if not at then table.insert(parts,raw:sub(cursor)); break end
		table.insert(parts,raw:sub(cursor,at-1))
		local finish=raw:find(";",at+1,true)
		if not finish then XML.fail("invalid-entity","Entity needs a semicolon",position+at-1) end
		local key=raw:sub(at+1,finish-1)
		local value=({amp="&",lt="<",gt=">",apos="'",quot='"'})[key]
		if not value then
			local digits=key:match("^#x([%da-fA-F]+)$")
			local decimal=key:match("^#(%d+)$")
			local n=if digits then tonumber(digits,16) elseif decimal then tonumber(decimal) else nil
			if not n or not character(n) then XML.fail("invalid-entity","Unknown or invalid XML entity: &"..key..";",position+at-1) end
			value=utf8.char(n)
		end
		table.insert(parts,value); cursor=finish+1
	end
	return table.concat(parts)
end
function XML.new(source: string,maxAttributes: number): any
	local length,bad=utf8.len(source)
	if not length then XML.fail("invalid-utf8","SVG must be valid UTF-8",bad or 1) end
	for at,n in utf8.codes(source) do if not character(n) then XML.fail("invalid-character","Forbidden XML character",at) end end
	return setmetatable({Source=source,Position=1,MaxAttributes=maxAttributes},XML)
end
function XML.space(self: any): boolean
	local start=self.Position
	while self.Source:sub(self.Position,self.Position):match("[ \t\r\n]") do self.Position+=1 end
	return self.Position>start
end
function XML.readName(self: any): string
	local start=self.Position
	while self.Position<=#self.Source and not self.Source:sub(self.Position,self.Position):match("[ \t\r\n/=>?]") do self.Position+=1 end
	local value=self.Source:sub(start,self.Position-1)
	XML.name(value,start)
	return value
end
function XML.next(self: any): any
	local s,p=self.Source,self.Position
	if p>#s then return nil end
	if s:sub(p,p)~="<" then
		local stop=s:find("<",p,true) or #s+1
		local raw=s:sub(p,stop-1)
		if raw:find("]]>",1,true) then XML.fail("invalid-text","]] > terminator outside CDATA",p) end
		self.Position=stop; return {Kind="Text",Text=decode(raw,p),Position=p}
	end
	for _,format in {{"<!--","-->","Comment"},{"<![CDATA[",']]>',"CDATA"},{"<?","?>","PI"}} do
		if s:sub(p,p+#format[1]-1)==format[1] then
			local stop=s:find(format[2],p+#format[1],true)
			if not stop then XML.fail("unclosed-"..format[3]:lower(),"Unclosed "..format[3],p) end
			local text=s:sub(p+#format[1],stop-1)
			if format[3]=="Comment" and (text:find("--",1,true) or text:sub(-1)=="-") then XML.fail("invalid-comment","-- is not allowed inside XML comments",p) end
			self.Position=stop+#format[2]; return {Kind=format[3],Text=text,Position=p}
		end
	end
	if s:sub(p,p+1)=="<!" then XML.fail("unsupported-declaration","DTD/entity declarations are not supported",p) end
	local closing=s:sub(p+1,p+1)=="/"
	self.Position=p+(if closing then 2 else 1)
	local name=self:readName()
	if closing then
		self:space()
		if s:sub(self.Position,self.Position)~=">" then XML.fail("invalid-end-tag","Expected >",self.Position) end
		self.Position+=1; return {Kind="End",Name=name,Position=p}
	end
	local attributes,seen={},{}
	while true do
		local separated=self:space()
		if s:sub(self.Position,self.Position+1)=="/>" then self.Position+=2; return {Kind="Start",Name=name,Attributes=attributes,SelfClosing=true,Position=p} end
		if s:sub(self.Position,self.Position)==">" then self.Position+=1; return {Kind="Start",Name=name,Attributes=attributes,Position=p} end
		if not separated or self.Position>#s then XML.fail("invalid-start-tag","Expected whitespace, > or />",self.Position) end
		if #attributes>=self.MaxAttributes then XML.fail("attribute-limit","Too many attributes",self.Position) end
		local at=self.Position; local attribute=self:readName()
		if seen[attribute] then XML.fail("duplicate-attribute","Duplicate attribute: "..attribute,at) end
		seen[attribute]=true; self:space()
		if s:sub(self.Position,self.Position)~="=" then XML.fail("invalid-attribute","XML attributes require = and quotes",self.Position) end
		self.Position+=1; self:space()
		local quote=s:sub(self.Position,self.Position)
		if quote~='"' and quote~="'" then XML.fail("unquoted-attribute","XML attribute values must be quoted",self.Position) end
		local start=self.Position+1; local stop=s:find(quote,start,true)
		if not stop then XML.fail("unclosed-attribute","Missing closing quote",start) end
		local raw=s:sub(start,stop-1)
		if raw:find("<",1,true) then XML.fail("invalid-attribute","Literal < is not allowed in attributes",start) end
		table.insert(attributes,{Name=attribute,Value=decode(raw:gsub("[\t\n\r]"," "),start),Position=at})
		self.Position=stop+1
	end
end
return XML
