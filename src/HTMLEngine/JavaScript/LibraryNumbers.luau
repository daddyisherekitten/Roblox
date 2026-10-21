--!strict
-- Exact binary64-to-decimal rounding. Scaling through host floating point would
-- lose the distinction between e.g. 2.55 and the binary value just below it.
local Strings=require(script.Parent.Strings)
local Numbers={}
-- StringNumericLiteral grammar, distinct from parseFloat and source literals.
-- Nondecimal integers retain guard/sticky bits rather than rounding each digit.
function Numbers.parse(source: string,step: any?): number
 source=Strings.trim(source);if source==''then return 0 end
 if source=='Infinity'or source=='+Infinity'then return math.huge elseif source=='-Infinity'then return -math.huge end
 local marker=source:sub(1,2):lower();local width=if marker=='0x'then 4 elseif marker=='0o'then 3 elseif marker=='0b'then 1 else 0
 if width>0 then
  if #source==2 then return 0/0 end
  local significand,count,guard,sticky=0,0,0,false;local started=false;local limit=2^width
  for i=3,#source do
   if step then step()end;local byte=source:byte(i);local digit=if byte>=48 and byte<=57 then byte-48 elseif byte>=65 and byte<=70 then byte-55 elseif byte>=97 and byte<=102 then byte-87 else -1
   if digit<0 or digit>=limit then return 0/0 end
   for bit=width-1,0,-1 do local one=math.floor(digit/2^bit)%2
    if started or one~=0 then started=true;count+=1;if count<=53 then significand=significand*2+one elseif count==54 then guard=one elseif one~=0 then sticky=true end end
   end
  end
  if guard==1 and(sticky or significand%2==1)then significand+=1 end
  return significand*2^math.max(count-53,0)
 end
 local unsigned=source;if unsigned:sub(1,1)=='+'or unsigned:sub(1,1)=='-'then unsigned=unsigned:sub(2)end
 local mantissa,exponent=unsigned:match('^(.-)[eE]([+-]?%d+)$');if not mantissa then mantissa=unsigned end
 if not mantissa:match('^%d+%.?%d*$')and not mantissa:match('^%.%d+$')then return 0/0 end
 -- Validation excludes host-only inf/nan, hexadecimal floats and separators.
 return tonumber(source)or 0/0
end
local function increment(value)
 local bytes=table.create(#value);for i=1,#value do bytes[i]=value:byte(i)-48 end
 local at=#bytes;while at>=1 and bytes[at]==9 do bytes[at]=0;at-=1 end
 if at==0 then table.insert(bytes,1,1)else bytes[at]+=1 end
 local parts={};for i,digit in bytes do parts[i]=string.char(digit+48)end;return table.concat(parts)
end
local function exact(value,step)
 if value==0 then return '0',1 end
 local fraction,exponent=math.frexp(math.abs(value));local mantissa=fraction*9007199254740992;exponent-=53
 local source=string.format('%.0f',mantissa);local digits={};for i=#source,1,-1 do table.insert(digits,source:byte(i)-48)end
 local factor=if exponent<0 then 5 else 2
 for _=1,math.abs(exponent)do
  if step then step()end;local carry=0;for i,digit in digits do local n=digit*factor+carry;digits[i]=n%10;carry=math.floor(n/10)end
  while carry>0 do table.insert(digits,carry%10);carry=math.floor(carry/10)end
 end
 local parts={};for i=#digits,1,-1 do table.insert(parts,string.char(digits[i]+48))end
 return table.concat(parts),#digits+math.min(exponent,0)
end
local function round(digits,count)
 if count<0 then return '0'elseif count==0 then return if digits:byte(1)>=53 then '1'else '0'
 elseif count>=#digits then return digits..string.rep('0',count-#digits)end
 local selected=digits:sub(1,count);return if digits:byte(count+1)>=53 then increment(selected)else selected
end
local function decimal(integer,count)
 if count==0 then return integer end
 if #integer<=count then integer=string.rep('0',count-#integer+1)..integer end
 return integer:sub(1,#integer-count)..'.'..integer:sub(#integer-count+1)
end
function Numbers.fixed(value: number,count: number,step: any?): string
 local digits,point=exact(value,step);local rounded=round(digits,point+count)
 return(if value<0 then '-'else '')..decimal(rounded,count)
end
local function significant(value,precision,step)
 local digits,point=exact(value,step);local rounded=round(digits,precision)
 if #rounded>precision then point+=1;rounded=rounded:sub(1,precision)end
 return rounded,point-1
end
local function exponential(digits,exponent)
 return digits:sub(1,1)..(if #digits>1 then '.'..digits:sub(2)else '')..'e'..(if exponent<0 then '-'else '+')..tostring(math.abs(exponent))
end
local function shortest(value,step)
 local exactDigits,point=exact(value,step)
 for precision=1,17 do
  local candidate=round(exactDigits,precision);local exponent=point-1
  if #candidate>precision then exponent+=1;candidate=candidate:sub(1,precision)end
  if tonumber(exponential(candidate,exponent))==math.abs(value)then return candidate,exponent end
 end
end
function Numbers.string(value: number): string
 if value~=value then return 'NaN'elseif value==math.huge then return 'Infinity'elseif value==-math.huge then return '-Infinity'elseif value==0 then return '0'end
 local digits,exponent=shortest(value,nil);local sign=if value<0 then '-'else ''
 if exponent>=21 or exponent<-6 then return sign..exponential(digits,exponent)end
 if exponent<0 then return sign..'0.'..string.rep('0',-exponent-1)..digits end
 if exponent+1>=#digits then return sign..digits..string.rep('0',exponent+1-#digits)end
 return sign..digits:sub(1,exponent+1)..'.'..digits:sub(exponent+2)
end
function Numbers.exponential(value: number,count: number?,step: any?): string
 local digits,exponent
 if count~=nil then digits,exponent=significant(value,count+1,step)
 else
  digits,exponent=shortest(value,step)
 end
 return(if value<0 then '-'else '')..exponential(digits,exponent)
end
function Numbers.precision(value: number,count: number,step: any?): string
 local digits,exponent=significant(value,count,step);local sign=if value<0 then '-'else ''
 if exponent>=count or exponent<-6 then return sign..exponential(digits,exponent)end
 if exponent<0 then return sign..'0.'..string.rep('0',-exponent-1)..digits end
 if exponent+1>=#digits then return sign..digits..string.rep('0',exponent+1-#digits)end
 return sign..digits:sub(1,exponent+1)..'.'..digits:sub(exponent+2)
end
-- ECMAScript leaves nondecimal output implementation-approximated. Follow the
-- Chromium binary64 precision interval, including subnormal values, instead
-- of an arbitrary limit on the number of digits after the point.
function Numbers.radix(value: number,radix: number,step: any?): string
 if radix==10 or value==0 or value~=value or math.abs(value)==math.huge then return Numbers.string(value)end
 local sign=if value<0 then '-'else '';value=math.abs(value)
 local integer=math.floor(value);local remainder=value-integer
 local _,exponent=math.frexp(value)
 local tolerance=math.max(2^(exponent-54),2^-1074)
 local fraction={}
 while remainder>=tolerance do
  if step then step()end
  remainder*=radix;tolerance*=radix
  local digit=math.floor(remainder);table.insert(fraction,digit);remainder-=digit
  if(remainder>0.5 or remainder==0.5 and digit%2==1)and remainder+tolerance>1 then
   local at=#fraction
   while at>0 and fraction[at]==radix-1 do fraction[at]=nil;at-=1 end
   if at==0 then integer+=1 else fraction[at]+=1 end
   break
  end
 end
 local alphabet='0123456789abcdefghijklmnopqrstuvwxyz';local reversed={}
 -- Dividing integers beyond their significand precision would invent low
 -- digits from rounding. These places are outside the input's precision.
 while integer/radix>=9007199254740992 do
  if step then step()end
  table.insert(reversed,'0');integer/=radix
 end
 repeat
  if step then step()end
  local digit=math.fmod(integer,radix)
  table.insert(reversed,alphabet:sub(math.floor(digit)+1,math.floor(digit)+1))
  integer=(integer-digit)/radix
 until integer<=0
 local parts={};for i=#reversed,1,-1 do table.insert(parts,reversed[i])end
 if #fraction>0 then table.insert(parts,'.');for _,digit in fraction do table.insert(parts,alphabet:sub(digit+1,digit+1))end end
 return sign..table.concat(parts)
end
return Numbers
