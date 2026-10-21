--!strict
-- JavaScript indexes UTF-16 code units, including supplementary characters.
local Strings = {}
-- Decode UTF-8 plus lone surrogate code units retained as WTF-8.
function Strings.codes(value: string): any
 local index=1
 return function()
  if index>#value then return nil end
  local first=value:byte(index);index+=1
  if first<128 then return first end
  local count=if first<224 then 1 elseif first<240 then 2 else 3
  local code=first%(2^(6-count))
  for _=1,count do local byte=value:byte(index);assert(byte and byte>=128 and byte<192,"Invalid UTF-8 string");code=code*64+byte-128;index+=1 end
  return code
 end
end
function Strings.units(value: string): {number}
	local result = {}
	for code in Strings.codes(value) do
		if code > 0xffff then
			code -= 0x10000
			table.insert(result, 0xd800 + math.floor(code / 1024))
			table.insert(result, 0xdc00 + code % 1024)
		else table.insert(result, code) end
	end
	return result
end
function Strings.length(value: string): number
	local length = 0
	for code in Strings.codes(value) do length += if code > 0xffff then 2 else 1 end
	return length
end
function Strings.fromUnits(units: {number}): string
	local parts, index = {}, 1
	while index <= #units do
		local code, following = units[index], units[index + 1]
		if code >= 0xd800 and code <= 0xdbff and following and following >= 0xdc00 and following <= 0xdfff then
			code = 0x10000 + (code - 0xd800) * 1024 + following - 0xdc00
			index += 1
		end
		-- Luau strings retain lone surrogates as WTF-8 until paired again.
		if code >= 0xd800 and code <= 0xdfff then
			table.insert(parts, string.char(0xe0 + math.floor(code / 4096), 0x80 + math.floor(code / 64) % 64, 0x80 + code % 64))
		else table.insert(parts, utf8.char(code)) end
		index += 1
	end
	return table.concat(parts)
end
-- Joining two valid JS strings can pair two separately stored WTF-8 surrogate
-- units. Normalize that boundary without allocating UTF-16 arrays for ASCII or
-- ordinary UTF-8 results; lone surrogate units retain their existing encoding.
function Strings.canonical(value: string): string
 if not value:find('\237',1,true)then return value end
 local result=value:gsub('\237[\160-\175][\128-\191]\237[\176-\191][\128-\191]',function(pair)
  local high=0xd000+(pair:byte(2)-128)*64+pair:byte(3)-128
  local low=0xd000+(pair:byte(5)-128)*64+pair:byte(6)-128
  return utf8.char(0x10000+(high-0xd800)*1024+low-0xdc00)
 end)
 return result
end
-- WebIDL USVString replaces only unpaired UTF-16 surrogates. Pair first so
-- separately stored JS halves retain their supplementary scalar value.
function Strings.usv(value: string): string
 return (Strings.canonical(value):gsub('\237[\160-\191][\128-\191]',utf8.char(0xfffd)))
end
-- Initial case profile: ASCII and Latin-1, including German umlauts/sharp S.
function Strings.case(value: string, upper: boolean): string
 local units={}
 for code in Strings.codes(value) do
  if upper then
   if code==0xdf then table.insert(units,83);code=83
   elseif code==0xff then code=0x178
   elseif (code>=97 and code<=122) or (code>=0xe0 and code<=0xf6) or (code>=0xf8 and code<=0xfe) then code-=32 end
  else
   if code==0x1e9e then code=0xdf elseif code==0x178 then code=0xff
   elseif (code>=65 and code<=90) or (code>=0xc0 and code<=0xd6) or (code>=0xd8 and code<=0xde) then code+=32 end
  end
  if code>0xffff then code-=0x10000;table.insert(units,0xd800+math.floor(code/1024));code=0xdc00+code%1024 end
  table.insert(units,code)
 end
 return Strings.fromUnits(units)
end
function Strings.trim(value: string): string
 local function space(code)
  return code==32 or (code>=9 and code<=13) or code==0xa0 or code==0x1680 or (code>=0x2000 and code<=0x200a)
   or code==0x2028 or code==0x2029 or code==0x202f or code==0x205f or code==0x3000 or code==0xfeff
 end
 local units=Strings.units(value);local first,last=1,#units
 while first<=last and space(units[first]) do first+=1 end
 while last>=first and space(units[last]) do last-=1 end
 local result={};for i=first,last do table.insert(result,units[i]) end
 return Strings.fromUnits(result)
end
return Strings
