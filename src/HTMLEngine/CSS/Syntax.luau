--!strict
--!optimize 2
-- Shared scanning for style blocks and attributes. Delimiters inside strings,
-- comments or balanced functions/blocks do not terminate the current segment.
local Syntax = {}
local WorkContext=require(script.Parent.Parent.WorkContext)
function Syntax.trim(source: string): string
	return source:match('^[ \t\n\r\f]*(.-)[ \t\n\r\f]*$') :: string
end
function Syntax.skip(source: string, at: number): (number, boolean)
	local spaced=false
	while at<=#source do
		if source:sub(at,at):match('[ \t\n\r\f]')then spaced=true;at+=1
		elseif source:sub(at,at+1)=='/*'then at=(source:find('*/',at+2,true)or #source)+2
		else break end
	end
	return at,spaced
end

-- Filter CSS input, not DOM data. JS retains lone UTF-16 units as WTF-8;
-- ordinary UTF-8 and the overwhelmingly common ASCII path need no copy.
function Syntax.preprocess(source: string): string
	if not source:find('[%z\r\f\237]')then return source end
	return (source:gsub('\r\n','\n'):gsub('[\r\f]','\n'):gsub('%z',utf8.char(0xFFFD)):gsub('\237[\160-\191][\128-\191]',utf8.char(0xFFFD)))
end

local function boundary(left: string, right: string, token: string): string
	-- A comment separates CSS tokens, but is not a whitespace token. Preserve
	-- a separator only where deleting it would manufacture an identifier,
	-- dimension, percentage or function. Punctuation in .a/**/.b stays adjacent.
	if left:match('[%w_%-]') and right == '(' then return ' ' end
	if left:match('[%w_%-]') and right:match('[%w_%-\\]')
		or left:match('%d') and tonumber(token)~=nil and (right == '.' or right == '%')
		or (left == '+' or left == '.') and right:match('%d')
		or (left == '#' or left == '@') and right:match('[%w_%-\\]')
		or left == '\\' and right ~= '' then return '/**/' end
	return ''
end

function Syntax.scan(source: string, start: number, stops: string, preserveComments: boolean?, preserveBoundaries: boolean?): (string, number, string)
	local parts, stack = {}, {}
	local index, chunk = start, start
	local quote: string? = nil
	local previous = ''
local previousToken = ''
	local nextCheck=start
	while index <= #source do
		if index>=nextCheck then nextCheck=index+256;WorkContext.checkpoint()end
		local char = source:sub(index, index)
		if quote then
			if char == "\\" then
				local nextChar=source:sub(index+1,index+1)
				if nextChar=='\n'or nextChar=='\r'or nextChar=='\f'then
					index+=if source:sub(index+1,index+2)=='\r\n' then 3 else 2
				else local _,after=Syntax.escape(source,index);index=after end
				continue
			end
			if char=='\n'or char=='\r'or char=='\f'then quote=nil end
			if char == quote then quote = nil end
		elseif char == "\\" then
			-- Escaped punctuation is part of its token, not a block/list delimiter.
			local _, after = Syntax.escape(source,index)
			index = after; continue
		elseif source:sub(index, index + 1) == "/*" then
			if preserveComments then index=(source:find('*/',index+2,true)or #source)+2;continue end
			local before = source:sub(chunk, index - 1)
			table.insert(parts, before)
			if before ~= '' then previous = before:sub(-1);previousToken=before:match('([^%s{}%;:%(%),]+)$')or'' end
			repeat
				local finish = source:find("*/", index + 2, true)
				index = if finish then finish + 2 else #source + 1
			until source:sub(index, index + 1) ~= '/*'
			local separator = boundary(previous, source:sub(index,index), previousToken)
			if preserveBoundaries and separator==' 'then separator='/**/'end
			if separator ~= '' then table.insert(parts,separator);previous=separator:sub(-1) end
			chunk = index
			continue
		elseif #stack == 0 and stops:find(char, 1, true) then
			table.insert(parts, source:sub(chunk, index - 1))
			return table.concat(parts), index + 1, char
		elseif char == '"' or char == "'" then quote = char
		elseif char == "(" then table.insert(stack, ")")
		elseif char == "[" then table.insert(stack, "]")
		elseif char == "{" then table.insert(stack, "}")
		elseif char == stack[#stack] then table.remove(stack)
		end
		index += 1
	end
	table.insert(parts, source:sub(chunk))
	return table.concat(parts), #source + 1, ""
end

-- CSS Syntax 3 escaped code points: up to six hex digits, one optional
-- whitespace terminator, and replacement for zero/surrogates/out-of-range.
function Syntax.escape(source: string, index: number): (string?, number)
	local nextIndex=index+1
	local char=source:sub(nextIndex,nextIndex)
	if char==''then return utf8.char(0xFFFD),nextIndex end
	if char=='\n'or char=='\r'or char=='\f'then return nil,nextIndex+1 end
	if char:match('[%da-fA-F]')then
		local start=nextIndex
		while nextIndex<start+6 and source:sub(nextIndex,nextIndex):match('[%da-fA-F]')do nextIndex+=1 end
		local scalar=tonumber(source:sub(start,nextIndex-1),16)or 0
		if scalar==0 or scalar>0x10FFFF or scalar>=0xD800 and scalar<=0xDFFF then scalar=0xFFFD end
		local space=source:sub(nextIndex,nextIndex)
		if space:match('[ \t\n\r\f]')then nextIndex+=1;if space=='\r'and source:sub(nextIndex,nextIndex)=='\n'then nextIndex+=1 end end
		return utf8.char(scalar),nextIndex
	end
	local byte=source:byte(nextIndex)or 0
	local bytes=if byte>=240 then 4 elseif byte>=224 then 3 elseif byte>=192 then 2 else 1
	return source:sub(nextIndex,nextIndex+bytes-1),nextIndex+bytes
end

function Syntax.stringToken(source: string, start: number): (string?, number)
	local quote=source:sub(start,start)
	if quote~="'"and quote~='"'then return nil,start end
	local parts,index={},start+1
	while index<=#source do
		WorkContext.checkpoint();local char=source:sub(index,index)
		if char==quote then return table.concat(parts),index+1 end
		if char=='\n'or char=='\r'or char=='\f'then return nil,index end
		if char=='\\'then
			local nextChar=source:sub(index+1,index+1)
			if nextChar==''then return nil,index end
			if nextChar=='\n'or nextChar=='\r'or nextChar=='\f'then
				index+=2;if nextChar=='\r'and source:sub(index,index)=='\n'then index+=1 end
			else local value,after=Syntax.escape(source,index);if not value then return nil,index end;table.insert(parts,value);index=after end
		else table.insert(parts,if char=='\0'then utf8.char(0xFFFD)else char);index+=1 end
	end
	return nil,index
end

function Syntax.string(source: string): string?
	local value,after=Syntax.stringToken(source,1)
	return if after>#source then value else nil
end

function Syntax.identifier(source: string, index: number?, allowDigit: boolean?): (string?, number)
	index=index or 1
	local start,parts=index,{}
	local function nameStart(at)
		local char=source:sub(at,at);local byte=source:byte(at)or 0
		return char:match('[%a_]')~=nil or byte>=128 or char=='\\'and source:sub(at+1,at+1)~=''and not source:sub(at+1,at+1):match('[\n\r\f]')
	end
	local first=source:sub(index,index)
	if not allowDigit and not nameStart(index)and not(first=='-'and(nameStart(index+1)or source:sub(index+1,index+1)=='-'))then return nil,index end
	while index<=#source do
		local char=source:sub(index,index);local byte=source:byte(index)or 0
		if char=='\\'then local value,after=Syntax.escape(source,index);if not value then break end;table.insert(parts,value);index=after
		elseif char:match('[%w_%-]')or byte>=128 then table.insert(parts,char);index+=1
		else break end
	end
	return if index>start then table.concat(parts)else nil,index
end

function Syntax.unescape(source: string): string
	local parts,index={},1
	while index<=#source do
		if source:sub(index,index)=='\\'then local value,after=Syntax.escape(source,index);table.insert(parts,value or '');index=after
		else table.insert(parts,source:sub(index,index));index+=1 end
	end
	return table.concat(parts)
end

-- Consume a number token whose type flag is integer. Ident units, decimal
-- fractions and exponent notation do not acquire that flag through tonumber.
function Syntax.integerToken(source: string,start: number): (number?,number)
	local digits,after=source:match('^([+%-]?%d+)()',start)
	if not digits then return nil,start end
	if source:sub(after):match('^%.%d')or source:sub(after):match('^[eE][+%-]?%d')then return nil,after end
	if Syntax.identifier(source,after)then return nil,after end
	return tonumber(digits),after
end
function Syntax.integerList(source: string): {number}?
	local result,index={},(Syntax.skip(source,1))
	while index<=#source do
		local number,after=Syntax.integerToken(source,index)
		if number==nil then return nil end
		table.insert(result,number);index=(Syntax.skip(source,after))
		if index>#source then return result end
		if source:sub(index,index)~=','then return nil end
		index=(Syntax.skip(source,index+1))
	end
	return nil
end

-- An+B is a token grammar, not a whitespace-stripped string. Return the
-- unread offset so selectors can consume their optional "of" list separately.
function Syntax.anb(source: string): (number?, number?, number)
	local function token(at)
		local spaced;at,spaced=Syntax.skip(source,at)
		WorkContext.checkpoint()
		local start=at
		local number,after=source:match('^([+%-]?%d*%.?%d+[eE][+%-]?%d+)()',at)
		if not number then number,after=source:match('^([+%-]?%d*%.?%d+)()',at)end
		if number then
			local unit,ending=Syntax.identifier(source,after)
			return {Kind=if unit then 'dimension'else 'number',Value=tonumber(number),Integer=number:match('^[+%-]?%d+$')~=nil,Sign=number:sub(1,1),Unit=unit},if unit then ending else after,spaced
		end
		local name,ending=Syntax.identifier(source,at)
		if name then return {Kind='ident',Value=name:lower()},ending,spaced end
		return {Kind='delim',Value=source:sub(start,start)},start+1,spaced
	end
	local first,after=token(1);local plus=false
	if first.Kind=='delim'and first.Value=='+'then
		local spaced;first,after,spaced=token(after);if spaced or first.Kind~='ident'then return nil,nil,after end;plus=true
	end
	if first.Kind=='number'then
		return if first.Integer then 0 else nil,first.Value,after
	end
	local name,a
	if first.Kind=='dimension'and first.Integer then name=first.Unit:lower();a=first.Value
	elseif first.Kind=='ident'then
		name=first.Value
		if not plus and(name=='odd'or name=='even')then return 2,if name=='odd'then 1 else 0,after end
		if name:sub(1,2)=='-n'then if plus then return nil,nil,after end;a=-1;name=name:sub(2)else a=1 end
	else return nil,nil,after end
	local embedded=name:match('^n%-(%d+)$')
	if embedded then return a,-tonumber(embedded),after end
	if name=='n-'then
		local last,ending=token(after)
		return if last.Kind=='number'and last.Integer and last.Sign~='+'and last.Sign~='-'then a else nil,-(last.Value or 0),ending
	end
	if name~='n'then return nil,nil,after end
	local last,ending=token(after)
	if last.Kind=='number'and last.Integer and(last.Sign=='+'or last.Sign=='-')then return a,last.Value,ending end
	if last.Kind=='delim'and(last.Value=='+'or last.Value=='-')then
		local sign=if last.Value=='-'then -1 else 1
		local offset;offset,ending=token(ending)
		if offset.Kind~='number'or not offset.Integer or offset.Sign=='+'or offset.Sign=='-'then return nil,nil,ending end
		return a,sign*offset.Value,ending
	end
	return a,0,after
end

-- Decode an at-keyword without rewriting the prelude's strings or values.
-- The returned offset still addresses the original header, including comments.
function Syntax.atRule(source: string): (string?, string, number)
	local index=1
	while index<=#source do
		if source:sub(index,index):match('[ \t\r\n\f]')then index+=1
		elseif source:sub(index,index+1)=='/*'then index=(source:find('*/',index+2,true)or #source)+2
		else break end
	end
	if source:sub(index,index)~='@'then return nil,'',index end
	local name,after=Syntax.identifier(source,index+1)
	if not name then return nil,'',index end
	local prelude=Syntax.scan(source,after,'')
	return name:lower(),Syntax.trim(prelude),after
end

function Syntax.serializeIdentifier(source: string): string
	local result,index={},0
	for _,code in utf8.codes(source)do
		index+=1;if index%256==0 then WorkContext.checkpoint()end
		if code==0 then table.insert(result,utf8.char(0xfffd))
		elseif code<32 or code==127 or code>=48 and code<=57 and(index==1 or index==2 and source:sub(1,1)=='-')then table.insert(result,'\\'..string.format('%x',code)..' ')
		elseif code==45 and #source==1 then table.insert(result,'\\-')
		elseif code>=128 or code==45 or code==95 or code>=48 and code<=57 or code>=65 and code<=90 or code>=97 and code<=122 then table.insert(result,utf8.char(code))
		else table.insert(result,'\\'..utf8.char(code))end
	end
	return table.concat(result)
end

function Syntax.serializeString(source: string): string
	return '"'..source:gsub('[%z\1-\31\127\\"]',function(char)
		if char=='\0'then return utf8.char(0xFFFD)end
		if char=='"'or char=='\\'then return '\\'..char end
		return '\\'..string.format('%x',string.byte(char))..' '
	end)..'"'
end

-- Find a function token by its decoded ASCII-insensitive name. Quotes,
-- comments, hashes, at-keywords and dimension units cannot create functions.
-- This scanner is shared by variable validation, substitution and Typed OM.
function Syntax.findFunction(source: string, start: number, name: string): (number?, number?)
	local index,quote=start,nil;local nextCheck=start
	while index<=#source do
		if index>=nextCheck then nextCheck=index+256;WorkContext.checkpoint()end
		local char=source:sub(index,index)
		if quote then
			if char=='\\'then index+=2;continue end;if char==quote then quote=nil end
		elseif char=='"'or char=="'"then quote=char
		elseif source:sub(index,index+1)=='/*'then index=(source:find('*/',index+2,true)or #source)+2;continue
		else
			local number,after=source:match('^([%+%-]?%d*%.?%d+[eE][%+%-]?%d+)()',index)
			if not number then number,after=source:match('^([%+%-]?%d*%.?%d+)()',index)end
			if number then
				local _,ending=Syntax.identifier(source,after);index=ending
				if source:sub(index,index)=='%'then index+=1 end;continue
			end
			if char=='#'or char=='@'then
				local _,ending=Syntax.identifier(source,index+1,true);index=ending;continue
			end
			local ident,ending=Syntax.identifier(source,index)
			if ident then
				if source:sub(ending,ending)=='('then
					if ident:lower()==name then return index,ending+1 end
					-- An unquoted url() is one URL/bad-URL token, not a nested
					-- function list. Quoted url() keeps normal string tokenization.
					if ident:lower()=='url'and not source:sub(ending+1):match('^[ \t\r\n\f]*["\']')then
						local _,finish=Syntax.scan(source,ending+1,')');index=finish;continue
					end
				end
				index=ending;continue
			end
		end
		index+=1
	end
	return nil,nil
end

function Syntax.declarations(source: string): { any }
	local declarations = {}
	local index = 1
	while index <= #source do
		local start=index
		local declaration, nextIndex,delimiter = Syntax.scan(source, index, ";")
		index = nextIndex
		if not declaration:find("%S") then continue end
		local value = declaration:match("^(.-)%s*!%s*[Ii][Mm][Pp][Oo][Rr][Tt][Aa][Nn][Tt]%s*$")
		local raw=if delimiter==''then source:sub(start)else source:sub(start,nextIndex-2)
		if value then raw=raw:match("^(.-)%s*!%s*[Ii][Mm][Pp][Oo][Rr][Tt][Aa][Nn][Tt]%s*$")or raw end
		table.insert(declarations, { Text = value or declaration, Raw=raw, Important = value ~= nil })
	end
	return declarations
end

return Syntax
