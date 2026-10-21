--!strict
-- WHATWG special hosts: UTS #46 nontransitional mapping, RFC 3492 Punycode,
-- URL-style IPv4 numbers and canonical IPv6. Data is pinned to Unicode 17.0.0.
local Strings=require(script.Parent.Strings)
local Unicode=require(script.Parent.UnicodeNormalization)
local NormalizationData=require(script.Parent.UnicodeNormalizationData)
local Data=require(script.Parent.LibraryURLIDNAData)
local Host={Version=Data.Version}
local function property(rows,code,fallback)
 local low,high=1,#rows
 while low<=high do local mid=math.floor((low+high)/2);local row=rows[mid];if code<row[1]then high=mid-1 elseif code>row[2]then low=mid+1 else return row[3],row[4]end end
 return fallback
end
local function codes(source)local out={};for code in Strings.codes(source)do out[#out+1]=code end;return out end
local function fromCodes(values)
 local units={};for _,code in values do if code>0xffff then code-=0x10000;units[#units+1]=0xd800+math.floor(code/1024);code=0xdc00+code%1024 end;units[#units+1]=code end;return Strings.fromUnits(units)
end
local function adapt(delta,points,first)
 delta=if first then math.floor(delta/700)else math.floor(delta/2);delta+=math.floor(delta/points);local k=0
 while delta>455 do delta=math.floor(delta/35);k+=36 end;return k+math.floor(36*delta/(delta+38))
end
local function digit(code)return if code>=48 and code<=57 then code-22 elseif code>=65 and code<=90 then code-65 elseif code>=97 and code<=122 then code-97 else 36 end
local function encodedDigit(n)return string.char(n+(if n<26 then 97 else 22))end
local function punyEncode(input,charge)
 local out={};for _,code in input do if code<128 then out[#out+1]=string.char(code)end end
 local basic=#out;local handled=basic;if basic>0 then out[#out+1]='-'end;local n,delta,bias=128,0,72
 while handled<#input do
  if charge then charge()end
  local nextCode=0x110000;for _,code in input do if charge then charge()end;if code>=n and code<nextCode then nextCode=code end end
  delta+=(nextCode-n)*(handled+1);if delta>2147483647 then return nil end;n=nextCode
  for _,code in input do
   if charge then charge()end
   if code<n then delta+=1;if delta>2147483647 then return nil end
   elseif code==n then
    local q=delta;local k=36
    while true do local t=math.clamp(k-bias,1,26);if q<t then break end;out[#out+1]=encodedDigit(t+(q-t)%(36-t));q=math.floor((q-t)/(36-t));k+=36 end
    out[#out+1]=encodedDigit(q);bias=adapt(delta,handled+1,handled==basic);delta=0;handled+=1
   end
  end;delta+=1;n+=1
 end;return table.concat(out)
end
local function punyDecode(source,charge)
 local out={};local delimiter=source:match('^.*()%-');local at=1
 if delimiter then for i=1,delimiter-1 do local code=source:byte(i);if code>=128 then return nil end;out[#out+1]=code end;at=delimiter+1 end
 local n,index,bias=128,0,72
 while at<=#source do
  if charge then charge()end
  local old,weight,k=index,1,36
  while true do
   local raw=source:byte(at);if not raw then return nil end;local d=digit(raw);at+=1;if d>=36 or d>(2147483647-index)/weight then return nil end;index+=d*weight
   local t=math.clamp(k-bias,1,26);if d<t then break end;if weight>2147483647/(36-t)then return nil end;weight*=36-t;k+=36
  end
  bias=adapt(index-old,#out+1,old==0);n+=math.floor(index/(#out+1));if n>0x10ffff or(n>=0xd800 and n<=0xdfff)then return nil end
  index%=(#out+1);table.insert(out,index+1,n);index+=1
 end;return out
end
local function validLabel(input,bidiDomain)
 if #input==0 then return true end
 if NormalizationData.Marks[input[1]]then return false end
 for at,code in input do
  local status=property(Data.Mapping,code,'disallowed');if status~='valid'and status~='deviation'and status~='disallowed_STD3_valid'then return false end
  if code==0x200d and(NormalizationData.Combining[input[at-1]]or 0)~=9 then return false end
  if code==0x200c and(NormalizationData.Combining[input[at-1]]or 0)~=9 then
   local before,after=at-1,at+1
   while before>0 and property(Data.Joining,input[before],'U')=='T'do before-=1 end
   while after<=#input and property(Data.Joining,input[after],'U')=='T'do after+=1 end
   local left=if before>0 then property(Data.Joining,input[before],'U')else 'U';local right=if after<=#input then property(Data.Joining,input[after],'U')else 'U'
   if(left~='L'and left~='D')or(right~='R'and right~='D')then return false end
  end
 end
 if bidiDomain then
  local first=property(Data.Bidi,input[1],'L');local rtl=first=='R'or first=='AL';if not rtl and first~='L'then return false end
  local en,an=false,false;local last=first
  local allowed=if rtl then {R=true,AL=true,AN=true,EN=true,ES=true,CS=true,ET=true,ON=true,BN=true,NSM=true}else {L=true,EN=true,ES=true,CS=true,ET=true,ON=true,BN=true,NSM=true}
  for _,code in input do local class=property(Data.Bidi,code,'L');if not allowed[class]then return false end;if class~='NSM'then last=class end;en=en or class=='EN';an=an or class=='AN'end
  if rtl then if en and an or(last~='R'and last~='AL'and last~='EN'and last~='AN')then return false end
  elseif last~='L'and last~='EN'then return false end
 end
 return true
end
function Host.domain(source: string,charge: (() -> ())?): string?
 local mapped={}
 for code in Strings.codes(source)do
  if charge then charge()end
  local status,mapping=property(Data.Mapping,code,'disallowed')
  if status=='mapped'or status=='disallowed_STD3_mapped'then for _,value in mapping do mapped[#mapped+1]=value end
  elseif status=='valid'or status=='deviation'or status=='disallowed_STD3_valid'then mapped[#mapped+1]=code
  elseif status~='ignored'then return nil end
 end
 local normalized=Unicode.normalize(fromCodes(mapped),'NFC',charge);local labels={};local bidi=false
 for label in(normalized..'.'):gmatch('(.-)%.')do
  local input=if label:sub(1,4)=='xn--'then punyDecode(label:sub(5),charge)else codes(label)
  if not input or(label:sub(1,4)=='xn--'and #input==0)then return nil end
  if label:sub(1,4)=='xn--'then local nonASCII=false;for _,code in input do nonASCII=nonASCII or code>=128 end;if not nonASCII then return nil end end
  if Unicode.normalize(fromCodes(input),'NFC',charge)~=fromCodes(input)then return nil end
  for _,code in input do local class=property(Data.Bidi,code,'L');if class=='R'or class=='AL'or class=='AN'then bidi=true end end
  labels[#labels+1]=input
 end
 local out={}
 for _,input in labels do
  if not validLabel(input,bidi)then return nil end
  local ascii=true;for _,code in input do if code>=128 then ascii=false;break end end
  if ascii then out[#out+1]=fromCodes(input)else local encoded=punyEncode(input,charge);if not encoded then return nil end;out[#out+1]='xn--'..encoded end
 end
 return table.concat(out,'.')
end
local function ipv4Number(source)
 if source==''then return nil end
 local radix=10
 if source:sub(1,2):lower()=='0x'then source=source:sub(3);radix=16 elseif #source>=2 and source:sub(1,1)=='0'then source=source:sub(2);radix=8 end
 if source==''then return 0 end
 if not source:match(if radix==16 then '^%x+$'elseif radix==8 then '^[0-7]+$'else '^%d+$')then return nil end
 local value=tonumber(source,radix);return if value and value<=4294967295 then value else nil
end
function Host.ipv4(source: string): (string?,boolean)
 local parts={};for part in(source..'.'):gmatch('(.-)%.')do parts[#parts+1]=part end
 if #parts>1 and parts[#parts]==''then table.remove(parts)end
 local last=parts[#parts];if not last or not(last:match('^%d+$')or ipv4Number(last)~=nil)then return source,false end
 if #parts>4 then return nil,true end
 local values={};for _,part in parts do local value=ipv4Number(part);if not value then return nil,true end;values[#values+1]=value end
 for i=1,#values-1 do if values[i]>255 then return nil,true end end
 if values[#values]>=256^(5-#values)then return nil,true end
 local address=values[#values];for i=1,#values-1 do address+=values[i]*256^(4-i)end
 local out={};for shift=3,0,-1 do out[#out+1]=tostring(math.floor(address/256^shift)%256)end;return table.concat(out,'.'),true
end
function Host.ipv6(source: string): string?
 local compressed=source:find('::',1,true);if compressed and source:find('::',compressed+2,true)then return nil end
 if compressed and source:sub(1,compressed-1):find('.',1,true)then return nil end
 local function parse(part)
  local pieces={};if part==''then return pieces end
  for token in(part..':'):gmatch('(.-):')do
   if token:find('.',1,true)then
    if part:sub(-#token)~=token then return nil end
    local bytes={};for raw in(token..'.'):gmatch('(.-)%.')do if not raw:match('^%d+$')or(#raw>1 and raw:sub(1,1)=='0')or tonumber(raw)>255 then return nil end;bytes[#bytes+1]=tonumber(raw)end
    if #bytes~=4 then return nil end;pieces[#pieces+1]=bytes[1]*256+bytes[2];pieces[#pieces+1]=bytes[3]*256+bytes[4]
   else if #token<1 or #token>4 or not token:match('^%x+$')then return nil end;pieces[#pieces+1]=tonumber(token,16)end
  end;return pieces
 end
 local left=parse(if compressed then source:sub(1,compressed-1)else source);local right=parse(if compressed then source:sub(compressed+2)else '')
 if not left or not right then return nil end
 local count=#left+#right;if(compressed and count>=8)or(not compressed and count~=8)then return nil end
 local values=left;if compressed then for _=1,8-count do values[#values+1]=0 end end;for _,value in right do values[#values+1]=value end
 local bestStart,bestLength=0,1;local at=1
 while at<=8 do if values[at]~=0 then at+=1;continue end;local first=at;while at<=8 and values[at]==0 do at+=1 end;if at-first>bestLength then bestStart,bestLength=first,at-first end end
 local out='';at=1
 while at<=8 do if at==bestStart then out..='::';at+=bestLength else if out~=''and out:sub(-1)~=':'then out..=':'end;out..=string.format('%x',values[at]);at+=1 end end
 return '['..out..']'
end
return Host
