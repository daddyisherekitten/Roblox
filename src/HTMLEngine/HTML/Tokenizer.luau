--!strict
--!optimize 2
local Entities = require(script.Parent.Entities)
local Doctype=require(script.Parent.Doctype)
local ScriptData=require(script.Parent.ScriptData)
local Tokenizer = {}
local WorkContext=require(script.Parent.Parent.WorkContext)
Tokenizer.__index = Tokenizer

local function space(c: string): boolean
	return c == " " or c == "\t" or c == "\n" or c == "\r" or c == "\f"
end
local function replacement(value: string): string return (value:gsub("%z",utf8.char(0xFFFD))) end

function Tokenizer.new(source: string, diagnostic: (string, string, number) -> ())
	return setmetatable({ Source = source, Position = 1, Length = #source, Raw = nil :: string?, Warn = diagnostic }, Tokenizer)
end

local function hasDelimiter(source: string,delimiter: string,start: number,boundary: number): boolean
	if boundary==#source then return source:find(delimiter,start,true)~=nil end
	-- document.write boundaries may end before the stored source does. Scan
	-- bounded chunks with overlap rather than copying the entire remaining tail
	-- or accepting a terminator belonging to a later parser input segment.
	for cursor=start,boundary,256 do
		WorkContext.checkpoint()
		local finish=math.min(boundary,cursor+255+#delimiter-1)
		if source:sub(cursor,finish):find(delimiter,1,true)then return true end
	end
	return false
end

-- A script-created input stream and document.write insertion point do not emit
-- EOF. Defer only the unfinished token; complete tokens keep their native state.
function Tokenizer.nextIncremental(self: any,final: boolean,stop: number?): any
	if final and not stop then return self:next()end
	local source,length,position,raw,warn=self.Source,self.Length,self.Position,self.Raw,self.Warn
	local boundary=if stop then math.min(length,stop-1)else length
	if position>boundary then return nil end
	if not raw and source:sub(position,position)=="<"then
		local prefix=source:sub(position,math.min(boundary,position+8))
		if prefix=="<"or prefix=="</"then return nil end
		local declaration=prefix:sub(1,2)=="<!"or prefix:sub(1,2)=="<?"
		local bogusEnd=prefix:sub(1,2)=="</"and not prefix:sub(3,3):match("[A-Za-z>]")
		if(declaration or bogusEnd)and not hasDelimiter(source,">",position,boundary)then return nil end
		if self.AllowCDATA and prefix=="<![CDATA["and not hasDelimiter(source,"]]>",position+9,boundary)then return nil end
	end
	if boundary<length then self.Source=source:sub(1,boundary);self.Length=boundary end
	local warnings={};local incomplete=false
	self.Warn=function(code,message,offset)
		table.insert(warnings,{code,message,offset})
		if code:find("eof",1,true)or code=="unclosed-comment"or code=="unclosed-attribute"then incomplete=true end
	end
	local ok,token=pcall(self.next,self)
	local atEnd=self.Position>boundary
	if not ok then self.Source,self.Length,self.Warn=source,length,warn;error(token,0)end
	if not token or incomplete or(raw and raw~="plaintext"and atEnd and token.Kind=="Text")then
		self.Position,self.Raw=position,raw;token=nil
	elseif token.Kind=="Text"and atEnd and not raw then
		local value=source:sub(position,boundary)
		local amp=value:find("&[#A-Za-z0-9]*$")
		local opening=if value:sub(-1)=="<"then #value else nil
		local withheld=amp or opening
		if withheld then
			self.Position=position+withheld-1
			if withheld==1 then token=nil else token.Text=Entities.decode(value:sub(1,withheld-1))end
		end
	elseif raw=="plaintext"then self.Raw=raw end
	self.Source,self.Length,self.Warn=source,length,warn
	if token then for _,warning in warnings do warn(table.unpack(warning))end end
	return token
end

function Tokenizer._skipSpace(self: any)
	while space(self.Source:sub(self.Position, self.Position)) do
		if self.Position%256==0 then WorkContext.checkpoint()end
		self.Position += 1
	end
end

function Tokenizer._rawText(self: any): any
	local start, cursor, name = self.Position, self.Position, self.Raw
	if name=="plaintext" then self.Position=self.Length+1; self.Raw=nil; return {Kind="Text",Text=replacement(self.Source:sub(start)),Position=start} end
	if name=="script" then
		local ending=ScriptData.ending(self.Source,start)
		self.Raw=nil
		if ending then
			if ending==start then return self:next() end
			self.Position=ending; return {Kind="Text",Text=replacement(self.Source:sub(start,ending-1)),Position=start}
		end
		self.Position=self.Length+1; return {Kind="Text",Text=replacement(self.Source:sub(start)),Position=start}
	end
	while cursor <= self.Length do
		WorkContext.checkpoint()
		local found = self.Source:find("</", cursor, true)
		if not found then break end
		local after = found + 2 + #name
		local boundary = self.Source:sub(after, after)
		if self.Source:sub(found + 2, after - 1):lower() == name and (boundary == ">" or boundary == "/" or space(boundary)) then
			self.Raw = nil
			if found == start then return self:next() end
			self.Position = found
			local value = replacement(self.Source:sub(start, found - 1))
			return { Kind = "Text", Text = if name == "textarea" or name == "title" then Entities.decode(value) else value, Position = start }
		end
		cursor = found + 2
	end
	self.Position = self.Length + 1
	self.Raw = nil
	local value = replacement(self.Source:sub(start))
	return { Kind = "Text", Text = if name == "textarea" or name == "title" then Entities.decode(value) else value, Position = start }
end

local function bogus(self: any,start: number,content: number): any
	local stop=self.Source:find(">",content,true)
	self.Position=if stop then stop+1 else self.Length+1
	return {Kind="Comment",Text=replacement(self.Source:sub(content,if stop then stop-1 else self.Length)),Position=start}
end

function Tokenizer._comment(self: any,start: number): any
	local source,position,state,parts=self.Source,start+4,"start",{}
	while position<=self.Length do
		if position%256==0 then WorkContext.checkpoint() end
		local ch=replacement(source:sub(position,position)); local again=false
		if state=="start" then
			if ch=="-" then state="start-dash" elseif ch==">" then self.Position=position+1; return {Kind="Comment",Text="",Position=start} else state="data"; again=true end
		elseif state=="start-dash" then
			if ch=="-" then state="end" elseif ch==">" then self.Position=position+1; return {Kind="Comment",Text="",Position=start} else table.insert(parts,"-"); state="data"; again=true end
		elseif state=="data" then
			if ch=="-" then state="end-dash" else table.insert(parts,ch) end
		elseif state=="end-dash" then
			if ch=="-" then state="end" else table.insert(parts,"-"); state="data"; again=true end
		elseif state=="end" then
			if ch==">" then self.Position=position+1; return {Kind="Comment",Text=table.concat(parts),Position=start}
			elseif ch=="!" then state="end-bang" elseif ch=="-" then table.insert(parts,"-") else table.insert(parts,"--"); state="data"; again=true end
		elseif state=="end-bang" then
			if ch==">" then self.Position=position+1; self.Warn("incorrect-comment-close","Comment closed by --!>",start); return {Kind="Comment",Text=table.concat(parts),Position=start}
			elseif ch=="-" then table.insert(parts,"--!"); state="end-dash" else table.insert(parts,"--!"); state="data"; again=true end
		end
		if not again then position+=1 end
	end
	self.Position=self.Length+1; self.Warn("unclosed-comment","Comment is missing -->",start)
	return {Kind="Comment",Text=table.concat(parts),Position=start}
end

function Tokenizer._instruction(self: any,start: number): any
	local source,cursor=self.Source,start+2
	local first=source:sub(cursor,cursor)
	if cursor>self.Length then self.Position=self.Length+1; return nil end
	if not first:match("[A-Za-z_]") then return bogus(self,start,start+1) end
	while cursor<=self.Length and source:sub(cursor,cursor):match("[A-Za-z0-9_%-]") do
		if cursor%256==0 then WorkContext.checkpoint() end; cursor+=1
	end
	if cursor>self.Length then self.Position=self.Length+1; return nil end
	local target=source:sub(start+2,cursor-1); local boundary=source:sub(cursor,cursor)
	if target:lower()=="xml" or target:lower()=="xml-stylesheet" or not (space(boundary) or boundary=="?" or boundary==">") then return bogus(self,start,start+1) end
	while space(source:sub(cursor,cursor)) do cursor+=1 end
	local stop=source:find(">",cursor,true)
	if not stop then self.Position=self.Length+1; self.Warn("eof-in-processing-instruction","Incomplete processing instruction ignored",start); return nil end
	local data=replacement(source:sub(cursor,stop-1)); if data:sub(-1)=="?" then data=data:sub(1,-2) end
	self.Position=stop+1
	return {Kind="ProcessingInstruction",Target=target,Text=data,Position=start}
end

function Tokenizer.next(self: any): any
	if self.Position > self.Length then return nil end
	if self.Raw then return self:_rawText() end
	local source, start = self.Source, self.Position
	if source:sub(start, start) ~= "<" then
		local stop = source:find("<", start, true) or self.Length + 1
		self.Position = stop
		return { Kind = "Text", Text = Entities.decode(source:sub(start, stop - 1)), Position = start }
	end
	if source:sub(start, start + 3) == "<!--" then
		return self:_comment(start)
	end
	if source:sub(start, start + 1) == "<!" then
		if source:sub(start+2,start+8)=="[CDATA[" and self.AllowCDATA then
			local stop=source:find("]]>",start+9,true); self.Position=if stop then stop+3 else self.Length+1
			return {Kind="Text",Text=source:sub(start+9,if stop then stop-1 else self.Length),Position=start}
		end
		if source:sub(start+2,start+8):lower()~="doctype" then return bogus(self,start,start+2) end
		local declaration,nextPosition=Doctype.scan(source,start+9,self.Warn)
		self.Position=nextPosition
		return { Kind = "Declaration", Position = start, Doctype=declaration }
	end
	local closing = source:sub(start + 1, start + 1) == "/"
	local nameStart = start + (if closing then 2 else 1)
	if not source:sub(nameStart, nameStart):match("[A-Za-z]") then
		if source:sub(start+1,start+1)=="?" then return self:_instruction(start) end
		if closing then
			if source:sub(nameStart,nameStart)==">" then self.Position=nameStart+1; return self:next() end
			if nameStart<=self.Length then return bogus(self,start,nameStart) end
		end
		self.Position += 1
		return { Kind = "Text", Text = "<", Position = start }
	end
	local b=nameStart
	while b<=self.Length and not space(source:sub(b,b)) and source:sub(b,b)~="/" and source:sub(b,b)~=">" do if b%256==0 then WorkContext.checkpoint() end; b+=1 end
	b-=1
	local name = replacement(source:sub(nameStart, b)):lower()
	self.Position = b + 1
	if closing then self:_skipSpace(); if source:sub(self.Position,self.Position)~=">" then self.Warn("invalid-end-tag","Unexpected content in end tag",start) end end
	local attributes, attributeOrder, selfClosing, ended = {}, {}, false, false
	while self.Position <= self.Length do
		WorkContext.checkpoint()
		self:_skipSpace()
		if self.Position > self.Length then break end
		local c = source:sub(self.Position, self.Position)
		if c == ">" then self.Position += 1; ended = true; break end
		if c == "/" and source:sub(self.Position + 1, self.Position + 1) == ">" then
			self.Position += 2; selfClosing = true; ended = true; break
		end
		local attributeStart = self.Position
		if c=="=" then self.Position+=1 end
		while self.Position <= self.Length do
			if self.Position%256==0 then WorkContext.checkpoint()end
			c = source:sub(self.Position, self.Position)
			if space(c) or c == "=" or c == "/" or c == ">" then break end
			self.Position += 1
		end
		if self.Position == attributeStart then
			self.Warn("invalid-attribute", "Invalid attribute character", self.Position)
			self.Position += 1
			continue
		end
		local attributeName = replacement(source:sub(attributeStart, self.Position - 1)):lower()
		self:_skipSpace()
		local value = ""
		if source:sub(self.Position, self.Position) == "=" then
			self.Position += 1
			self:_skipSpace()
			local quote = source:sub(self.Position, self.Position)
			if quote == '"' or quote == "'" then
				self.Position += 1
				local stop = source:find(quote, self.Position, true)
				value = source:sub(self.Position, if stop then stop - 1 else self.Length)
				self.Position = if stop then stop + 1 else self.Length + 1
				if not stop then self.Warn("unclosed-attribute", "Attribute quote is missing", attributeStart) end
			else
				local valueStart = self.Position
				while self.Position <= self.Length do
					if self.Position%256==0 then WorkContext.checkpoint()end
					c = source:sub(self.Position, self.Position)
					if space(c) or c == ">" then break end
					self.Position += 1
				end
				value = source:sub(valueStart, self.Position - 1)
			end
		end
		if attributes[attributeName] == nil then attributes[attributeName] = Entities.decode(replacement(value),true);table.insert(attributeOrder,attributeName)
		else self.Warn("duplicate-attribute", "First duplicate attribute is kept: " .. attributeName, attributeStart) end
	end
	if not ended then self.Warn("eof-in-tag", "Incomplete tag ignored at end of input", start); return nil end
	if closing then return {Kind="EndTag",Name=name,Position=start} end
	if not self.TreeControlled and (name == "script" or name == "style" or name == "textarea" or name == "title" or name=="xmp" or name=="iframe" or name=="noembed" or name=="noframes" or name=="plaintext") then self.Raw = name end
	return { Kind = "StartTag", Name = name, Attributes = attributes, AttributeOrder = attributeOrder, SelfClosing = selfClosing, Position = start }
end

return Tokenizer
