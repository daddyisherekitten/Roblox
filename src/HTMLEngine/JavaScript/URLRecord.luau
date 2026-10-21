--!strict
-- URL records shared by document metadata and the JavaScript URL object.
local Host=require(script.Parent.LibraryURLHost)
local Codec=require(script.Parent.URLCodec)
local Record={}
function Record.create(c: any,codec: any)
 local usv,encode,decode=codec.USV,codec.Encode,codec.Decode
 local unreserved,step=codec.Unreserved,c.step
 local defaultPorts={http='80',https='443',ftp='21',ws='80',wss='443'}
 local function printableExcept(excluded)local out='';for byte=33,126 do local char=string.char(byte);if not excluded:find(char,1,true)then out..=char end end;return out end
 local pathAllowed=printableExcept('"#<>?`{}')
 local queryAllowed=printableExcept('"#<>')
 local specialQueryAllowed=queryAllowed:gsub("'",'')
 local fragmentAllowed=printableExcept('"<>`')
 local opaqueAllowed='';for byte=32,126 do opaqueAllowed..=string.char(byte)end
 local function normalizePath(path,file)
  if file then local drive=path:match('^/([A-Za-z])|');if drive and(#path==3 or path:sub(4,4)=='/')then path='/'..drive..':'..path:sub(4)end end
  local parts={};local trailing=path:sub(-1)=='/'
  for segment in(path..'/'):gmatch('(.-)/')do
   if #parts==0 and segment==''then table.insert(parts,'');continue end
   local dots=segment:lower():gsub('%%2e','.')
   if dots=='.'then trailing=true elseif dots=='..'then if #parts>(if file and parts[2]and parts[2]:match('^[A-Za-z]:$')then 2 else 1)then table.remove(parts)end;trailing=true else table.insert(parts,encode(segment,pathAllowed,false,false));trailing=false end
  end
  -- The final artificial segment is omitted, while an actual terminal slash
  -- stays in the path. Interior empty segments deliberately remain observable.
  if path:sub(-1)=='/'and parts[#parts]==''then trailing=false end
  local result=table.concat(parts,'/');if result==''then result='/'end
  if trailing and result:sub(-1)~='/'then result..='/'end;return result
 end
 local function hostParts(authority,scheme,charge)
  local username,password='','';local userinfo,host=authority:match('^(.*)@(.*)$');if userinfo then authority=host;username,password=userinfo:match('^(.-):(.*)$');if not username then username,password=userinfo,''end
   username=encode(username,unreserved..'%',false,false);password=encode(password,unreserved..'%',false,false)
  end
  local hostname,port
  if authority:sub(1,1)=='['then
   local inner=authority:match('^%[([^%]]+)%]$');port=''
   if not inner then inner,port=authority:match('^%[([^%]]+)%]:(%d*)$')end
   hostname=inner and Host.ipv6(inner);if not hostname then c.fail('TypeError','Invalid IPv6 URL host')end
  else hostname,port=authority:match('^(.-):(%d*)$');if not hostname then hostname,port=authority,''end end
  local special=defaultPorts[scheme]~=nil or scheme=='file'
  if hostname:sub(1,1)~='['then
   if special then
    hostname=decode(hostname,false,false,false)
    hostname=Host.domain(hostname,charge or step);if not hostname then c.fail('TypeError','Invalid IDNA URL host')end
    if hostname:find('[%z\1-\32\127 #%/:<>?@\\^|]')then c.fail('TypeError','Invalid URL host')end
    local ipv4=Host.ipv4(hostname);if not ipv4 then c.fail('TypeError','Invalid IPv4 URL host')end;hostname=ipv4
   else
    if hostname:find('[%z\9\10\13 #%/:<>?@\\^|]')or hostname:find('[',1,true)or hostname:find(']',1,true)then c.fail('TypeError','Invalid opaque URL host')end
    -- Opaque hosts use the C0 set, preserve percent escapes and case, and do
    -- not share encodeURI's reserved/unreserved character grammar.
    hostname=encode(hostname,opaqueAllowed,false,false)
   end
  end
  if hostname==''and defaultPorts[scheme]~=nil then c.fail('TypeError','URL host is empty')end
  if scheme=='file'and(port~=''or username~=''or password~='')then c.fail('TypeError','File URLs cannot have credentials or a port')end
  if port~=''then local n=tonumber(port);if not n or n>65535 then c.fail('TypeError','Invalid URL port')end;port=tostring(n);if defaultPorts[scheme]==port then port=''end end
  if scheme=='file'and hostname=='localhost'then hostname=''end
  return hostname,port,username,password
 end
 local parseURL
 parseURL=function(input,base,charge)
  local source=usv(input):gsub('[\t\r\n]',''):gsub('^[%z\1-\32]+',''):gsub('[%z\1-\32]+$','')
  local scheme,rest=source:match('^([%a][%w+%.%-]*):(.*)$');if scheme then scheme=scheme:lower()end
  local function slashes(value)local head,tail=value:match('^([^?#]*)(.*)$');return head:gsub('\\','/')..tail end
  if not scheme and base and(defaultPorts[base.Scheme]or base.Scheme=='file')then source=slashes(source)end
  local result
  if scheme then
   local special=defaultPorts[scheme]~=nil or scheme=='file';if special then rest=slashes(rest)end
   if defaultPorts[scheme]and not(base and base.Scheme==scheme and rest:sub(1,2)~='//')then rest='//'..rest:gsub('^/*','')end
   if rest:sub(1,2)=='//'then
    local authority,suffix=rest:sub(3):match('^([^/%?#]*)(.*)$');local hostname,port,username,password
    if scheme=='file'and authority:match('^[A-Za-z][:|]$')then hostname,port,username,password='','','','';suffix='/'..authority..suffix
    else hostname,port,username,password=hostParts(authority,scheme,charge)end
    result={Scheme=scheme,Hostname=hostname,Port=port,Username=username,Password=password,Opaque=false,Path=if special then '/'else '',Query=nil,Fragment=nil};source=suffix
   elseif special then
    if base and base.Scheme==scheme and scheme~='file'then return parseURL(rest,base,charge)end
    if scheme=='file'then result={Scheme=scheme,Hostname='',Port='',Username='',Password='',Opaque=false,Path='/',Query=nil,Fragment=nil};source=rest
    else return parseURL(scheme..'://'..rest:gsub('^/*',''),nil,charge)end
   else result={Scheme=scheme,Hostname='',Port='',Username='',Password='',Opaque=rest:sub(1,1)~='/',Hostless=rest:sub(1,1)=='/',Path='',Query=nil,Fragment=nil};source=rest end
  else
   if not base then c.fail('TypeError','Invalid URL without base')end
   if source:sub(1,2)=='//'then return parseURL(base.Scheme..':'..source,nil,charge)end
   result=table.clone(base);result.Fragment=nil
   if result.Opaque and source:sub(1,1)~='#'then c.fail('TypeError','Cannot resolve a relative URL against an opaque URL')end
  end
  local fragment=source:find('#',1,true);if fragment then result.Fragment=encode(source:sub(fragment+1),fragmentAllowed,false,false);source=source:sub(1,fragment-1)end
  local query=source:find('?',1,true);if query then result.Query=encode(source:sub(query+1),if defaultPorts[result.Scheme]then specialQueryAllowed else queryAllowed,false,false);source=source:sub(1,query-1)
  elseif scheme or source~=''then result.Query=nil end
  if result.Opaque then if scheme then result.Path=encode(source,opaqueAllowed,false,false)end
  elseif source~=''then
   if defaultPorts[result.Scheme]or result.Scheme=='file'then source=source:gsub('\\','/')end
   if source:sub(1,1)~='/'then if scheme then source='/'..source else source=(result.Path:match('^(.*)/')or'')..'/'..source end
   elseif result.Scheme=='file'and not scheme and base then local drive=base.Path:match('^/([A-Za-z]:)');if drive and not source:match('^/[A-Za-z][:|]')then source='/'..drive..source end end
   result.Path=normalizePath(source,result.Scheme=='file')
  end;return result
 end
 local function serialize(record)
  local out=record.Scheme..':'
  if not record.Opaque and not record.Hostless then out..='//';if record.Username~=''or record.Password~=''then out..=record.Username..(if record.Password~=''then ':'..record.Password else '')..'@'end
   out..=record.Hostname..(if record.Port~=''then ':'..record.Port else '')
  end;out..=record.Path;if record.Query~=nil then out..='?'..record.Query end;if record.Fragment~=nil then out..='#'..record.Fragment end;return c.stringResult(out)
 end
 return {Parse=parseURL,Serialize=serialize,NormalizePath=normalizePath,HostParts=hostParts,DefaultPorts=defaultPorts,QueryAllowed=queryAllowed,SpecialQueryAllowed=specialQueryAllowed,FragmentAllowed=fragmentAllowed}
end
local nativeParser
function Record.resolve(input: string,base: string?,charge: (() -> ())?): (string,any)
 if not nativeParser then
  local c={text=function(value)return value end,stringResult=function(value)return value end,
   fail=function(_,message)error(message,0)end,step=function()end}
  nativeParser=Record.create(c,Codec.create(c))
 end
 local record=nativeParser.Parse(input,if base then nativeParser.Parse(base,nil,charge)else nil,charge)
 return nativeParser.Serialize(record),record
end
return Record
