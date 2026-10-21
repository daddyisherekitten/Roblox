--!strict
-- Shared scalar-value and percent codecs for URL records and JavaScript URI APIs.
local Strings=require(script.Parent.Strings)
local Codec={}
function Codec.create(c: any)
 local function usv(value)
  local units=Strings.units(c.text(value));local i=1;while i<=#units do local unit,following=units[i],units[i+1]
   if unit>=0xd800 and unit<=0xdbff and following and following>=0xdc00 and following<=0xdfff then i+=2
   elseif unit>=0xd800 and unit<=0xdfff then units[i]=0xfffd;i+=1 else i+=1 end
  end;return Strings.fromUnits(units)
 end
 local function utf8decode(bytes,strict)
  local parts={};local i=1
  while i<=#bytes do local first=bytes:byte(i)
   if first<128 then table.insert(parts,string.char(first));i+=1;continue end
   local count=if first>=194 and first<=223 then 2 elseif first>=224 and first<=239 then 3 elseif first>=240 and first<=244 then 4 else 0
   local code=if count>0 then first%(2^(8-count-1))else 0;local good=count>0 and i+count-1<=#bytes;local consumed=1
   for j=1,count-1 do local byte=bytes:byte(i+j)
    if not byte or byte<128 or byte>191 then good=false;break end
    if j==1 and((first==224 and byte<160)or(first==237 and byte>159)or(first==240 and byte<144)or(first==244 and byte>143))then good=false;break end
    code=code*64+byte-128;consumed+=1
   end
   if good then table.insert(parts,utf8.char(code));i+=count
   else if strict then c.fail('URIError','URI malformed')end;table.insert(parts,utf8.char(0xfffd));i+=consumed end
  end;return table.concat(parts)
 end
 local unreserved="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()"
 local reserved=';/?:@&=+$,#'
 local function encode(value,allowed,form,strict)
  value=if strict then c.text(value)else usv(value)
  if strict then for code in Strings.codes(value)do if code>=0xd800 and code<=0xdfff then c.fail('URIError','URI malformed')end end end
  local out={};for i=1,#value do local byte=value:byte(i);local char=string.char(byte)
   if allowed:find(char,1,true)then table.insert(out,char)elseif form and byte==32 then table.insert(out,'+')else table.insert(out,string.format('%%%02X',byte))end
  end;return c.stringResult(table.concat(out))
 end
 local function decode(value,form,strict,preserve)
  value=c.text(value);local parts={};local bytes={};local function flush()if #bytes>0 then table.insert(parts,utf8decode(table.concat(bytes),strict));table.clear(bytes)end end
  local at=1;while at<=#value do local char=value:sub(at,at)
   if char=='%'then local hex=value:sub(at+1,at+2)
    if #hex~=2 or not hex:match('^%x%x$')then if strict then c.fail('URIError','URI malformed')end;table.insert(bytes,char);at+=1
    else local byte=tonumber(hex,16);if preserve and reserved:find(string.char(byte),1,true)then flush();table.insert(parts,value:sub(at,at+2))else table.insert(bytes,string.char(byte))end;at+=3 end
   else
    if strict then flush();table.insert(parts,char)else table.insert(bytes,if form and char=='+'then ' 'else char)end
    at+=1
   end
  end;flush();return c.stringResult(table.concat(parts))
 end
 return {USV=usv,Encode=encode,Decode=decode,Unreserved=unreserved,Reserved=reserved}
end
return Codec
