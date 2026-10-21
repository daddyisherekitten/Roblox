--!strict
-- URL query pairs and URI codecs, including pinned UTS #46 special hosts.
local Strings=require(script.Parent.Strings)
local URLCodec=require(script.Parent.URLCodec)
local URLRecord=require(script.Parent.URLRecord)
local URLs={}
function URLs.install(c: any)
 local VM,vm,U,N=c.VM,c.vm,c.U,c.N;local get,set,step=c.get,c.set,c.step
 local codec=URLCodec.create(c)
 local usv,encode,decode=codec.USV,codec.Encode,codec.Decode
 local unreserved,reserved=codec.Unreserved,codec.Reserved
 c.global('encodeURIComponent',c.native('encodeURIComponent',1,function(args)return encode(c.arg(args,1,U),unreserved,false,true)end))
 c.global('encodeURI',c.native('encodeURI',1,function(args)return encode(c.arg(args,1,U),unreserved..reserved,false,true)end))
 c.global('decodeURIComponent',c.native('decodeURIComponent',1,function(args)return decode(c.arg(args,1,U),false,true,false)end))
 c.global('decodeURI',c.native('decodeURI',1,function(args)return decode(c.arg(args,1,U),false,true,true)end))
 local formAllowed='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789*-._'
 local function formParse(source)
  local list={};source=usv(source);if source:sub(1,1)=='?'then source=source:sub(2)end
  for segment in(source..'&'):gmatch('(.-)&')do
   if segment==''then continue end;local name,value=segment:match('^(.-)=(.*)$');if not name then name,value=segment,''end
   c.bound(#list+1);table.insert(list,{decode(name,true,false,false),decode(value,true,false,false)})
  end;return list
 end
 local function formString(list)
  local parts={};for i,pair in list do step();parts[i]=encode(pair[1],formAllowed,true,false)..'='..encode(pair[2],formAllowed,true,false)end;return c.stringResult(table.concat(parts,'&'))
 end
 local paramsProto=vm.Object({},c.prototypes.Object);c.prototypes.URLSearchParams=paramsProto
 local function paramsReceiver(value)
  if not c.isObject(value)or value.Kind~='url-search-params'then c.fail('TypeError','URLSearchParams method called on incompatible receiver')end;return value
 end
 vm.DefineProperty(paramsProto,'size',vm.Object({get=c.native('get size',0,function(_,value)return #paramsReceiver(value).List end),enumerable=true,configurable=true},VM.Null))
 local function update(value)if value.Update then value.Update(formString(value.List))end end
 local function createParams(list,prototype)
  local value=vm.Object({},prototype or paramsProto);value.Kind='url-search-params';value.List=list
  return value
 end
 local function constructParams(args,newTarget)
  local prototype=c.constructPrototype(newTarget,paramsProto)
  local init=c.arg(args,1,'');local list={}
  if init==N then return createParams(list,prototype)end
  if type(init)=='string'then list=formParse(init)
  elseif c.isObject(init)then
   if init.Kind=='array'or init.Iterator or(vm.IsIterable and vm.IsIterable(init))then
    local nextEntry,outerClose=vm.Iterator(init)
    local ok,result=pcall(function()
     while true do local more,entry=nextEntry();if not more then break end
      if not c.isObject(entry)then c.fail('TypeError','Each query pair must be an iterable object')end
      local nextItem,innerClose=vm.Iterator(entry);local pair={}
      local innerOK,innerResult=pcall(function()
       while true do local present,item=nextItem();if not present then break end;c.bound(#pair+1);table.insert(pair,usv(item))end
      end)
      if not innerOK then if innerClose then pcall(innerClose)end;error(innerResult,0)end
      if #pair~=2 then c.fail('TypeError','Each query pair must contain exactly two items')end
      c.bound(#list+1);table.insert(list,pair)
     end
    end)
    if not ok then if outerClose then pcall(outerClose)end;error(result,0)end
   else for _,key in c.keys(init,true)do if type(key)=='string'then c.bound(#list+1);table.insert(list,{usv(key),usv(get(init,key))})end end end
  else list=formParse(usv(init))end
  return createParams(list,prototype)
 end
 local paramsConstructor=c.native('URLSearchParams',0,function()c.fail('TypeError','URLSearchParams requires new')end,constructParams,{prototype=paramsProto})
 c.define(paramsProto,'constructor',paramsConstructor)
 c.method(paramsProto,'append',2,function(args,value)
  value=paramsReceiver(value);if #args<2 then c.fail('TypeError','URLSearchParams.append requires two arguments')end;c.bound(#value.List+1);table.insert(value.List,{usv(args[1]),usv(args[2])});update(value);return U
 end)
 c.method(paramsProto,'delete',1,function(args,value)
  value=paramsReceiver(value);if #args<1 then c.fail('TypeError','URLSearchParams.delete requires a name')end
  local name=usv(args[1]);local matchValue=if args[2]==nil or args[2]==U then nil else usv(args[2]);local index=1
  while index<=#value.List do local pair=value.List[index];if pair[1]==name and(matchValue==nil or pair[2]==matchValue)then table.remove(value.List,index)else index+=1 end end
  update(value);return U
 end)
 c.method(paramsProto,'get',1,function(args,value)
  value=paramsReceiver(value);if #args<1 then c.fail('TypeError','URLSearchParams.get requires a name')end
  local name=usv(args[1]);for _,pair in value.List do if pair[1]==name then return pair[2]end end;return N
 end)
 c.method(paramsProto,'getAll',1,function(args,value)
  value=paramsReceiver(value);if #args<1 then c.fail('TypeError','URLSearchParams.getAll requires a name')end
  local name=usv(args[1]);local out=c.array(0);for _,pair in value.List do if pair[1]==name then c.create(out,tostring(out.Length),pair[2])end end;return out
 end)
 c.method(paramsProto,'has',1,function(args,value)
  value=paramsReceiver(value);if #args<1 then c.fail('TypeError','URLSearchParams.has requires a name')end
  local name=usv(args[1]);local matchValue=if args[2]==nil or args[2]==U then nil else usv(args[2]);for _,pair in value.List do if pair[1]==name and(matchValue==nil or pair[2]==matchValue)then return true end end;return false
 end)
 c.method(paramsProto,'set',2,function(args,value)
  value=paramsReceiver(value);if #args<2 then c.fail('TypeError','URLSearchParams.set requires two arguments')end
  local name,text=usv(args[1]),usv(args[2]);local first;local index=1
  while index<=#value.List do local pair=value.List[index]
   if pair[1]~=name then index+=1 elseif not first then first=pair;pair[2]=text;index+=1 else table.remove(value.List,index)end
  end;if not first then c.bound(#value.List+1);table.insert(value.List,{name,text})end;update(value);return U
 end)
 c.method(paramsProto,'sort',0,function(_,value)
  value=paramsReceiver(value);local list={};for index,pair in value.List do list[index]={Pair=pair,Index=index,Units=Strings.units(pair[1])}end
  table.sort(list,function(a,b)
   for i=1,math.min(#a.Units,#b.Units)do if a.Units[i]~=b.Units[i]then return a.Units[i]<b.Units[i]end end
   return if #a.Units~=#b.Units then #a.Units<#b.Units else a.Index<b.Index
  end);table.clear(value.List);for _,item in list do table.insert(value.List,item.Pair)end;update(value);return U
 end)
 c.method(paramsProto,'forEach',1,function(args,value)
  value=paramsReceiver(value);local callback=c.requireCallback(c.arg(args,1,U));local index=1
  while index<=#value.List do step();local pair=value.List[index];vm:Call(callback,{pair[2],pair[1],value},c.arg(args,2,U));index+=1 end;return U
 end)
 c.method(paramsProto,'toString',0,function(_,value)return formString(paramsReceiver(value).List)end)
 for _,name in {'keys','values','entries'}do c.method(paramsProto,name,0,function(_,value)
  value=paramsReceiver(value);local index=1
  return c.CreateNativeIterator('URLSearchParams',function()
   local pair=value.List[index];if not pair then return false,U end;index+=1
   return true,if name=='keys'then pair[1]elseif name=='values'then pair[2]else vm.Array(table.clone(pair))
  end)
 end)end
 c.global('URLSearchParams',paramsConstructor)

 local urlProto=vm.Object({},c.prototypes.Object);c.prototypes.URL=urlProto
 local parser=URLRecord.create(c,codec)
 local parseURL,serialize=parser.Parse,parser.Serialize
 local normalizePath,hostParts=parser.NormalizePath,parser.HostParts
 local defaultPorts,queryAllowed,specialQueryAllowed,fragmentAllowed=parser.DefaultPorts,parser.QueryAllowed,parser.SpecialQueryAllowed,parser.FragmentAllowed
 local function urlReceiver(value)
  if not c.isObject(value)or value.Kind~='url'then c.fail('TypeError','URL method called on incompatible receiver')end;return value
 end
 local function constructURL(args,newTarget)
  local prototype=c.constructPrototype(newTarget,urlProto)
  if #args<1 then c.fail('TypeError','URL requires an input')end
  local input=usv(args[1]);local base=if args[2]~=nil and args[2]~=U then parseURL(usv(args[2]),nil)else nil;local record=parseURL(input,base)
  local value=vm.Object({},prototype);value.Kind='url';value.Record=record;value.SearchParams=createParams(formParse(record.Query or ''))
  value.SearchParams.Update=function(query)value.Record.Query=if query==''then nil else query end
  value.URLRead=function(key)
   local r=value.Record
   if key=='href'then return serialize(r)elseif key=='protocol'then return r.Scheme..':'elseif key=='username'then return r.Username elseif key=='password'then return r.Password
   elseif key=='hostname'then return r.Hostname elseif key=='port'then return r.Port elseif key=='host'then return r.Hostname..(if r.Port~=''then ':'..r.Port else '')
   elseif key=='pathname'then return r.Path elseif key=='search'then return if r.Query==nil or r.Query==''then ''else '?'..r.Query
   elseif key=='hash'then return if r.Fragment==nil or r.Fragment==''then ''else '#'..r.Fragment elseif key=='searchParams'then return value.SearchParams
   elseif key=='origin'then
    if defaultPorts[r.Scheme]then return r.Scheme..'://'..r.Hostname..(if r.Port~=''then ':'..r.Port else '')end
    if r.Scheme=='blob'then local ok,inner=pcall(parseURL,r.Path,nil);if ok and(inner.Scheme=='http'or inner.Scheme=='https')then return inner.Scheme..'://'..inner.Hostname..(if inner.Port~=''then ':'..inner.Port else '')end end
    return 'null'
   end
   return U
  end
  value.URLWrite=function(key,item)
   local source=usv(item);local r=value.Record
   if key=='href'then value.Record=parseURL(source,nil);value.SearchParams.List=formParse(value.Record.Query or '')
   elseif key=='search'then r.Query=if source==''then nil else encode(if source:sub(1,1)=='?'then source:sub(2)else source,if defaultPorts[r.Scheme]then specialQueryAllowed else queryAllowed,false,false);value.SearchParams.List=formParse(r.Query or '')
   elseif key=='hash'then r.Fragment=if source==''then nil else encode(if source:sub(1,1)=='#'then source:sub(2)else source,fragmentAllowed,false,false)
   elseif key=='pathname'then if not r.Opaque then if defaultPorts[r.Scheme]or r.Scheme=='file'then source=source:gsub('\\','/')end;r.Path=normalizePath(if source:sub(1,1)=='/'then source else '/'..source,r.Scheme=='file')end
   elseif key=='username'or key=='password'then if not r.Opaque and r.Scheme~='file'then r[if key=='username'then 'Username'else 'Password']=encode(source,unreserved..'%',false,false)end
   elseif key=='host'or key=='hostname'then
    if not r.Opaque then
     source=source:gsub('[\t\r\n]','')
     local stop=source:find(if defaultPorts[r.Scheme]or r.Scheme=='file'then '[/\\?#]'else '[/\?#]');if stop then source=source:sub(1,stop-1)end
     local host,port=source,nil
     if source:sub(1,1)=='['then local close=source:find(']',1,true);if close and source:sub(close+1,close+1)==':'then host,port=source:sub(1,close),source:sub(close+2)end
     else local colon=source:find(':',1,true);if colon then host,port=source:sub(1,colon-1),source:sub(colon+1)end end
     -- A hostname override stops before committing when a port delimiter is
     -- present. A host override commits the host before parsing its port.
     if not(key=='hostname'and port~=nil)and not(r.Scheme=='file'and port~=nil)and not host:find('@',1,true)then
      local ok,hostname=pcall(hostParts,host,r.Scheme)
      if ok then r.Hostname=hostname;r.Hostless=nil
       if key=='host'and port~=nil then local digits=port:match('^%d+');local number=digits and tonumber(digits);if number and number<=65535 then r.Port=if defaultPorts[r.Scheme]==tostring(number)then ''else tostring(number)end end
      end
     end
    end
   elseif key=='port'then if not r.Opaque and r.Scheme~='file'then if source==''then r.Port=''else local n=source:match('^%d+');if n and tonumber(n)<=65535 then r.Port=if defaultPorts[r.Scheme]==tostring(tonumber(n))then ''else tostring(tonumber(n))end end end
   elseif key=='protocol'then local scheme=source:match('^([%a][%w+%.%-]*):?');if scheme then scheme=scheme:lower();local special=defaultPorts[scheme]~=nil or scheme=='file';local currentSpecial=defaultPorts[r.Scheme]~=nil or r.Scheme=='file'
    if special==currentSpecial and not(scheme=='file'and(r.Username~=''or r.Password~=''or r.Port~=''))and not(r.Scheme=='file'and r.Hostname=='')then r.Scheme=scheme;if defaultPorts[scheme]==r.Port then r.Port=''end end
   end
   elseif key~='origin'and key~='searchParams'then value.Values[key]=item end
  end
  return value
 end
 local constructor=c.native('URL',1,function()c.fail('TypeError','URL requires new')end,constructURL,{prototype=urlProto})
 for _,name in {'href','origin','protocol','username','password','host','hostname','port','pathname','search','searchParams','hash'}do
  local descriptor={get=c.native('get '..name,0,function(_,value)return urlReceiver(value).URLRead(name)end),enumerable=true,configurable=true}
  if name~='origin'and name~='searchParams'then descriptor.set=c.native('set '..name,1,function(args,value)urlReceiver(value).URLWrite(name,c.arg(args,1,U));return U end)end
  vm.DefineProperty(urlProto,name,vm.Object(descriptor,VM.Null))
 end
 c.define(urlProto,'constructor',constructor)
 c.method(urlProto,'toString',0,function(_,value)return serialize(urlReceiver(value).Record)end)
 c.method(urlProto,'toJSON',0,function(_,value)return serialize(urlReceiver(value).Record)end)
 local function converted(args)
  if #args<1 then c.fail('TypeError','URL requires an input')end
  local result={usv(args[1])};if args[2]~=nil and args[2]~=U then result[2]=usv(args[2])end;return result
 end
 c.method(constructor,'canParse',1,function(args)local values=converted(args);local ok=pcall(constructURL,values);return ok end)
 c.method(constructor,'parse',1,function(args)local values=converted(args);local ok,result=pcall(constructURL,values);return if ok then result else N end)
 c.global('URL',constructor)
 c.URI={Encode=encode,Decode=decode,USV=usv}
end
return URLs
