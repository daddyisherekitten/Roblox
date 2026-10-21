--!strict
-- Web byte/text/body APIs. HTTP requires an injected asynchronous host adapter.
local Strings=require(script.Parent.Strings)
local Decoder=require(script.Parent.Parent.Encoding.Decoder)
local BinaryData=require(script.Parent.BinaryData)
local ReadableStreams=require(script.Parent.ReadableStreams)
local WritableStreams=require(script.Parent.WritableStreams)
local TransformStreams=require(script.Parent.TransformStreams)
local StreamPiping=require(script.Parent.StreamPiping)
local FormData=require(script.Parent.FormData)
local FileData=require(script.Parent.FileData)
local ObjectURLs=require(script.Parent.ObjectURLs)
local EncodingStreams=require(script.Parent.EncodingStreams)
local XMLHttpRequest=require(script.Parent.XMLHttpRequest)
local NetworkData={}
function NetworkData.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true};local limit=options.MaxBytes or 1048576
 local binary=options.Binary or BinaryData.install(vm,globals,{MaxBytes=limit});api.Binary=binary
 local streams=ReadableStreams.install(vm,globals,options);api.Streams=streams
 local writable=WritableStreams.install(vm,globals,options);api.Writable=writable
 local transforms=TransformStreams.install(vm,globals,options,streams,writable);api.Transforms=transforms
 local piping=StreamPiping.install(vm,globals,options,streams,writable)
 local encoders,decoders,blobs,headers,bodies=setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"})
 local jsonIntrinsic=vm.Global.Bindings.JSON.Value;local parseJSON=vm.Get(jsonIntrinsic,"parse");local stringifyJSON=vm.Get(jsonIntrinsic,"stringify");local urlIntrinsic=vm.Global.Bindings.URL.Value
 local serializeParams=vm.Get(vm.Get(vm.Global.Bindings.URLSearchParams.Value,'prototype'),'toString')
 local abortAny=vm.Get(globals.AbortSignal,"any");local abortController=globals.AbortController
 local pending={};local proto={};for _,name in {"TextEncoder","TextDecoder","Blob","File","Headers","Request","Response"}do proto[name]=vm.Object({})end;proto.File.Prototype=proto.Blob
 local function check()assert(api.Alive and vm.Alive,"JavaScript network data disposed")end
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function field(value,key)return if value==nil or value==U or value==N then U else vm.Get(value,key)end
 local function required(args,n,name)if #args<n then fail("TypeError",name.." requires "..n.." arguments")end end
 local function brand(map,value,name)check();local state=map[value];if not state then fail("TypeError",name.." requires a compatible receiver")end;return state end
 local function int(value,default)local n=if value==U then default or 0 else VM.number(value);return if n~=n then 0 elseif n<0 then math.ceil(n)else math.floor(n)end
 local function bound(bytes)if #bytes>limit then fail("RangeError","Web body byte budget exceeded")end;return bytes end
 local function text(value)if vm.ToPrimitive then value=vm.ToPrimitive(value,"string")end;if type(value)=="table"and value.Kind=="symbol"then fail("TypeError","Cannot convert a Symbol to a Web IDL string")end;return VM.string(value)end
 local function usv(value)local out={};for code in Strings.codes(text(value))do vm.Step();table.insert(out,utf8.char(if code>=0xd800 and code<=0xdfff then 0xfffd else code))end;return bound(table.concat(out))end
 local function def(target,key,desc)return vm.DefineProperty(target,key,vm.Object(desc,VM.Null))end
 local function native(name,n,fn)local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end};def(value,"length",{value=n,configurable=true});def(value,"name",{value=name,configurable=true});return value end
 local function method(target,name,n,fn)def(target,name,{value=native(name,n,fn),writable=true,enumerable=true,configurable=true})end
 local function accessor(target,name,fn)def(target,name,{get=native("get "..name,0,function(_,value)return fn(value)end),enumerable=true,configurable=true})end
 local function constructor(name,n,create)local value=native(name,n,function()fail("TypeError",name.." requires new")end);value.Construct=function(args)check();return create(args)end;def(value,"prototype",{value=proto[name]});def(proto[name],"constructor",{value=value,writable=true,configurable=true});def(proto[name],vm.SymbolToStringTag,{value=name,configurable=true});globals[name]=value;vm.Global.Bindings[name]={Value=value};return value end
 local function object(name,map,state)local value=vm.Object({},proto[name]);value.NetworkState=state;map[value]=state;return value end
 local function promise(work)local p,resolve,reject=options.CreatePromise();local ok,value=pcall(work);if ok then resolve({value})else reject({VM.exceptionValue(value)})end;return p end
 local function iterator(items)local index=0;local result=vm.Object({},vm.Prototypes.Iterator);method(result,"next",0,function()local list=items();local entry=list[index+1];if entry~=nil then index+=1 end;return vm.Object({done=entry==nil,value=if entry==nil then U else entry})end);return result end
 local function consumeSequence(input,fn)local nextValue,close=vm.Iterator(input);local ok,message=pcall(function()local count=0;while true do local more,value=nextValue();if not more then break end;vm.Step();count+=1;if count>16384 then fail("RangeError","Web sequence budget exceeded")end;fn(value,count)end end);if not ok then if close then pcall(close)end;error(message,0)end end

 constructor("TextEncoder",0,function()return object("TextEncoder",encoders,{})end)
 accessor(proto.TextEncoder,"encoding",function(value)brand(encoders,value,"TextEncoder.encoding");return "utf-8"end)
 method(proto.TextEncoder,"encode",0,function(args,value)brand(encoders,value,"TextEncoder.encode");return binary:FromBytes(usv(if arg(args,1)==U then ""else args[1]))end)
 method(proto.TextEncoder,"encodeInto",2,function(args,value)
  brand(encoders,value,"TextEncoder.encodeInto");required(args,2,"TextEncoder.encodeInto");if not binary:IsUint8(args[2])then fail("TypeError","encodeInto destination must be a Uint8Array")end
  local length=#binary:ReadBytes(args[2]);local out,read,written={},0,0
  for code in Strings.codes(text(args[1]))do vm.Step();local scalar=if code>=0xd800 and code<=0xdfff then 0xfffd else code;local bytes=utf8.char(scalar);if written+#bytes>length then break end;table.insert(out,bytes);written+=#bytes;read+=if code>0xffff then 2 else 1 end
  binary:WriteBytes(args[2],0,table.concat(out));return vm.Object({read=read,written=written},nil,{"read","written"})
 end)
 local function decode(state,bytes,stream)
  local ok,result=pcall(Decoder.decode,state,bytes,stream,vm.Step)
  if ok then return result end
  if state.Fatal and type(result)=='string'and result:find('The encoded data was not valid',1,true)then fail('TypeError',result)end
  error(result,0)
 end
 local function decodeUTF8(bytes)return decode({Pending="",SeenBOM=false,Fatal=false,IgnoreBOM=false,Encoding="utf-8"},bytes,false)end
 constructor("TextDecoder",0,function(args)
  local raw=if arg(args,1)==U then 'utf-8'else text(args[1]);local label=Decoder.label(raw)
  if not label or label=='replacement'or not Decoder.supported(label)then fail('RangeError','Unsupported decoder encoding: '..raw)end
  return object("TextDecoder",decoders,{Encoding=label,Fatal=VM.truth(field(arg(args,2),"fatal")),IgnoreBOM=VM.truth(field(arg(args,2),"ignoreBOM")),Pending="",SeenBOM=false,Streaming=false})
 end)
 for name,key in {encoding="Encoding",fatal="Fatal",ignoreBOM="IgnoreBOM"}do accessor(proto.TextDecoder,name,function(value)return brand(decoders,value,"TextDecoder."..name)[key]end)end
 method(proto.TextDecoder,"decode",0,function(args,value)local state=brand(decoders,value,"TextDecoder.decode");local bytes=if arg(args,1)==U then ""else binary:ReadBytes(args[1]);if not state.Streaming then state.Pending="";state.SeenBOM=false;state.ReplacementSeen=false;state.ISO=nil end;state.Streaming=VM.truth(field(arg(args,2),"stream"));return decode(state,bytes,state.Streaming)end)

 local function mime(value)if value==U then return ""end;local result=text(value);if result:find("[^ -~]")then return ""end;return result:lower()end
 local function makeBlob(bytes,kind)return object("Blob",blobs,{Bytes=bound(bytes),Type=kind or ""})end
 local function blobParts(parts,ending)
  local out,size={},0;if parts~=U then consumeSequence(parts,function(value)local bytes
   if blobs[value]then bytes=blobs[value].Bytes elseif binary:IsBufferSource(value)then bytes=binary:ReadBytes(value)else bytes=usv(value);if ending=="native"then bytes=bytes:gsub("\r\n","\n"):gsub("\r","\n");if options.NativeLineEnding=="\r\n"then bytes=bytes:gsub("\n","\r\n")end end end
   size+=#bytes;if size>limit then fail("RangeError","Blob byte budget exceeded")end;table.insert(out,bytes)
  end)end;return table.concat(out)
 end
 local function blobInit(args,partsIndex,initIndex)
  local init=arg(args,initIndex);local endings=field(init,"endings");endings=if endings==U then "transparent"else text(endings);if endings~="transparent"and endings~="native"then fail("TypeError","Invalid Blob endings")end
  return blobParts(arg(args,partsIndex),endings),mime(field(init,"type"))
 end
 constructor("Blob",0,function(args)local bytes,kind=blobInit(args,1,2);return makeBlob(bytes,kind)end)
 for name,key in {size="Bytes",type="Type"}do accessor(proto.Blob,name,function(value)local state=brand(blobs,value,"Blob."..name);return if name=="size"then #state.Bytes else state.Type end)end
 method(proto.Blob,"slice",0,function(args,value)local state=brand(blobs,value,"Blob.slice");local length=#state.Bytes;local function relative(value,default)local i=int(value,default);return if i<0 then math.max(length+i,0)else math.min(i,length)end;local first,last=relative(arg(args,1),0),relative(arg(args,2),length);return makeBlob(state.Bytes:sub(first+1,math.max(first,last)),mime(arg(args,3)))end)
 method(proto.Blob,"text",0,function(_,value)local state=brand(blobs,value,"Blob.text");return promise(function()return decodeUTF8(state.Bytes)end)end)
 method(proto.Blob,"arrayBuffer",0,function(_,value)local state=brand(blobs,value,"Blob.arrayBuffer");return promise(function()return binary:Buffer(state.Bytes)end)end)
 method(proto.Blob,"bytes",0,function(_,value)local state=brand(blobs,value,"Blob.bytes");return promise(function()return binary:FromBytes(state.Bytes)end)end)
 method(proto.Blob,"stream",0,function(_,value)local state=brand(blobs,value,"Blob.stream");return streams:FromChunks(if #state.Bytes==0 then {}else{binary:FromBytes(state.Bytes)})end)
 constructor("File",2,function(args)
  required(args,2,"File");local bytes,kind=blobInit(args,1,3);local modified=field(arg(args,3),"lastModified");local state={Bytes=bytes,Type=kind,Name=usv(args[2]),LastModified=if modified==U then(if options.Now then options.Now()else os.time()*1000)else int(modified)};return object("File",blobs,state)
 end)
 vm.SetPrototype(globals.File,globals.Blob)
 for name,key in {name="Name",lastModified="LastModified"}do accessor(proto.File,name,function(value)local state=brand(blobs,value,"File."..name);if not state.Name then fail("TypeError","Expected File")end;return state[key]end)end
 accessor(proto.File,"webkitRelativePath",function(value)local state=brand(blobs,value,"File.webkitRelativePath");if not state.Name then fail("TypeError","Expected File")end;return ""end)
 local forms=FormData.install(vm,globals,{ToUSV=usv,ToDOMString=text,HostEvents=options.HostEvents,DecodeUTF8=decodeUTF8,DescribeBlob=function(value)return api:DescribeBlob(value)end,CreateBlob=function(value)return api:CreateBlob(value)end,MaxBytes=limit,Now=options.Now,FormDataEntries=options.FormDataEntries,FormDataConstructed=options.FormDataConstructed});api.FormData=forms

 local function byteString(value)local result=text(value);for code in Strings.codes(result)do if code>255 then fail("TypeError","Header contains a non-ByteString character")end end;return result end
 local function headerName(value)local name=byteString(value);if name==""or name:find("[^!#$%%&'*+.^_`|~%w-]")then fail("TypeError","Invalid HTTP header name")end;return name:lower()end
 local function headerValue(value)local content=byteString(value):gsub("^[ \t\r\n]+",""):gsub("[ \t\r\n]+$","");if content:find("[\r\n%z]")then fail("TypeError","Invalid HTTP header value")end;return content end
 local forbidden={['accept-charset']=true,['accept-encoding']=true,['access-control-request-headers']=true,['access-control-request-method']=true,connection=true,['content-length']=true,cookie=true,cookie2=true,date=true,dnt=true,expect=true,host=true,['keep-alive']=true,origin=true,referer=true,['set-cookie']=true,te=true,trailer=true,['transfer-encoding']=true,upgrade=true,via=true}
 local function headerAllowed(state,name,value)
  if state.Guard=="immutable"then fail("TypeError","Headers are immutable")end
  if state.Guard=="request"or state.Guard=="request-no-cors"then
   if forbidden[name]or name:sub(1,6)=="proxy-"or name:sub(1,4)=="sec-"then return false end
   if state.Guard=="request-no-cors"then
    if Strings.length(value)>128 then return false end
    if name=="accept-language"or name=="content-language"then return not value:find("[^%w *,.;=%-]")end
    if name=="range"then return value:match("^bytes=%d+%-%d*$")~=nil end
    if name~="accept"and name~="content-type"then return false end
    if value:find('[%z\1-\8\10-\31\127"():<>?@%[\\%]{}]')then return false end
    if name=="content-type"then local essence=(value:lower():match("^%s*([^;]+)")or ""):gsub("%s+$","");return essence=="application/x-www-form-urlencoded"or essence=="multipart/form-data"or essence=="text/plain"end
   end
  end
  return true
 end
 local function append(state,name,value)
  name,value=headerName(name),headerValue(value);local combined=value;if state.Guard=="request-no-cors"then local old={};for _,pair in state.List do if pair[1]==name then table.insert(old,pair[2])end end;if #old>0 then combined=table.concat(old,", ")..", "..value end end;if not headerAllowed(state,name,combined)then return end
  if #state.List>=1024 then fail("RangeError","Headers entry budget exceeded")end;table.insert(state.List,{name,value})
 end
 local function sortedHeaders(state)
  local names,seen={},{};for _,pair in state.List do if not seen[pair[1]]then seen[pair[1]]=true;table.insert(names,pair[1])end end;table.sort(names)
  local out={};for _,name in names do local values={};for _,pair in state.List do if pair[1]==name then if name=="set-cookie"then table.insert(out,{name,pair[2]})else table.insert(values,pair[2])end end end;if name~="set-cookie"then table.insert(out,{name,table.concat(values,", ")})end end;return out
 end
 local function makeHeaders(init,guard)
  local state={List={},Guard=guard or "none"};local value=object("Headers",headers,state)
  if init~=nil and init~=U then
   if headers[init]then for _,pair in headers[init].List do append(state,pair[1],pair[2])end
   elseif VM.callable(field(init,vm.SymbolIterator))then consumeSequence(init,function(pair)local values={};consumeSequence(pair,function(item)table.insert(values,item)end);if #values~=2 then fail("TypeError","Header entry must contain exactly two values")end;append(state,values[1],values[2])end)
   elseif type(init)=="table"and init~=N then for _,key in vm.OwnKeys(init,true)do if type(key)=="string"then append(state,key,vm.Get(init,key))end end
   else fail("TypeError","Invalid Headers initializer")end
  end;return value
 end
 constructor("Headers",0,function(args)return makeHeaders(arg(args,1))end)
 method(proto.Headers,"append",2,function(args,value)required(args,2,"Headers.append");append(brand(headers,value,"Headers.append"),args[1],args[2]);return U end)
 method(proto.Headers,"delete",1,function(args,value)required(args,1,"Headers.delete");local state=brand(headers,value,"Headers.delete");local name=headerName(args[1]);if not headerAllowed(state,name,"")then return U end;for i=#state.List,1,-1 do if state.List[i][1]==name then table.remove(state.List,i)end end;return U end)
 method(proto.Headers,"set",2,function(args,value)required(args,2,"Headers.set");local state=brand(headers,value,"Headers.set");local name,content=headerName(args[1]),headerValue(args[2]);if not headerAllowed(state,name,content)then return U end;local first
  for i=#state.List,1,-1 do if state.List[i][1]==name then first=i;table.remove(state.List,i)end end;table.insert(state.List,first or #state.List+1,{name,content});return U
 end)
 method(proto.Headers,"get",1,function(args,value)required(args,1,"Headers.get");local state=brand(headers,value,"Headers.get");local name=headerName(args[1]);local values={};for _,pair in state.List do if pair[1]==name then table.insert(values,pair[2])end end;return if #values==0 then N else table.concat(values,", ")end)
 method(proto.Headers,"has",1,function(args,value)required(args,1,"Headers.has");local state=brand(headers,value,"Headers.has");local name=headerName(args[1]);for _,pair in state.List do if pair[1]==name then return true end end;return false end)
 method(proto.Headers,"getSetCookie",0,function(_,value)local state=brand(headers,value,"Headers.getSetCookie");local out={};for _,pair in state.List do if pair[1]=="set-cookie"then table.insert(out,pair[2])end end;return vm.Array(out)end)
 for _,name in {"keys","values","entries"}do method(proto.Headers,name,0,function(_,value)local state=brand(headers,value,"Headers."..name);return iterator(function()local out={};for _,pair in sortedHeaders(state)do table.insert(out,if name=="keys"then pair[1]elseif name=="values"then pair[2]else vm.Array(pair))end;return out end)end)end
 def(proto.Headers,vm.SymbolIterator,{value=vm.Get(proto.Headers,"entries"),writable=true,configurable=true})
 method(proto.Headers,"forEach",1,function(args,value)local state=brand(headers,value,"Headers.forEach");local callback=arg(args,1);if not VM.callable(callback)then fail("TypeError","Headers callback must be callable")end;local i=1;while true do vm.Step();local list=sortedHeaders(state);local pair=list[i];if not pair then break end;vm:Call(callback,{pair[2],pair[1],value},arg(args,2));i+=1 end;return U end)

 local function absoluteURL(input)
  local url=vm:Construct(urlIntrinsic,{usv(input),options.BaseURL or U});if vm.Get(url,"username")~=""or vm.Get(url,"password")~=""then fail("TypeError","Request URL cannot contain credentials")end;return vm.Get(url,"href")
 end
 local function extract(value)
  if value==U or value==N then return nil,nil,nil end
  if blobs[value]then local state=blobs[value];return state.Bytes,if state.Type~=""then state.Type else nil,nil end
  if forms:IsFormData(value)then local bytes,contentType=forms:Serialize(value);return bytes,contentType,nil end
  if binary:IsBufferSource(value)then return bound(binary:ReadBytes(value)),nil,nil end
  if streams:IsStream(value)then if streams:IsLocked(value)or streams:IsDisturbed(value)then fail("TypeError","Body stream is already used or locked")end;return nil,nil,value end
  if type(value)=="table"and value.Kind=="url-search-params"then return bound(vm:Call(serializeParams,{},value)),"application/x-www-form-urlencoded;charset=UTF-8",nil end
  return usv(value),"text/plain;charset=UTF-8",nil
 end
 local function bodyStream(state)
  if not state.HasBody then return N end
  if not state.Stream then state.Stream=streams:FromChunks(if #state.Bytes==0 then {}else{binary:FromBytes(state.Bytes)})end
  return state.Stream
 end
 local function used(state)return state.Stream~=nil and streams:IsDisturbed(state.Stream)end
 local function consumeBody(state,transform)
  local p,resolve,reject=options.CreatePromise()
  if state.Stream and(streams:IsLocked(state.Stream)or used(state))then reject({VM.error("TypeError","Body is already used or locked")});return p end
  local function complete(bytes)local ok,value=pcall(transform,bytes);if api.Alive then(if ok then resolve else reject)({if ok then value else VM.exceptionValue(value)})end end
  if not state.HasBody then complete("");return p end
  local chunks,total={},0
  streams:Consume(bodyStream(state),function(chunk)if not binary:IsUint8(chunk)then fail("TypeError","Body stream chunk must be a Uint8Array")end;local bytes=binary:ReadBytes(chunk);total+=#bytes;if total>limit then fail("RangeError","Body byte budget exceeded")end;table.insert(chunks,bytes)end,function()complete(table.concat(chunks))end,function(reason)if api.Alive then reject({reason})end end)
  return p
 end
 local function newBody(kind,fields,body,head)
  local bytes,contentType,stream=extract(body);fields.Bytes,fields.Stream,fields.HasBody=bytes,stream,bytes~=nil or stream~=nil;fields.Headers=head
  if contentType and vm:Call(vm.Get(head,"has"),{"content-type"},head)==false then append(headers[head],"content-type",contentType)end
  return object(kind,bodies,fields)
 end
 local function cloneBody(value,kind)
  local state=brand(bodies,value,kind..".clone");if state.Kind~=kind then fail("TypeError","Incompatible body receiver")end
  if used(state)or(state.Stream and streams:IsLocked(state.Stream))then fail("TypeError","Cannot clone a used or locked body")end
  local copy=table.clone(state);if kind=="Request"then copy.Signal=vm:Call(abortAny,{vm.Array({state.Signal})},globals.AbortSignal)end;copy.Headers=makeHeaders(state.Headers);headers[copy.Headers].Guard=headers[state.Headers].Guard
  if state.HasBody then local first,second=streams:Tee(bodyStream(state),function(chunk)return if binary:IsUint8(chunk)then binary:FromBytes(binary:ReadBytes(chunk))else chunk end);state.Stream,copy.Stream=first,second end
  return object(kind,bodies,copy)
 end
 local function response(args)
  local init=arg(args,2);local status=field(init,"status");status=if status==U then 200 else int(status)%65536
  if status<200 or status>599 then fail("RangeError","Response status must be between 200 and 599")end
  local statusText=field(init,"statusText");statusText=if statusText==U then ""else byteString(statusText);if statusText:find("[^\t -~\128-\255]")then fail("TypeError","Invalid response statusText")end
  local body=arg(args,1);if body~=U and body~=N and(status==204 or status==205 or status==304)then fail("TypeError","This response status cannot have a body")end
  return newBody("Response",{Kind="Response",Status=status,StatusText=statusText,URL="",Type="default",Redirected=false},body,makeHeaders(field(init,"headers")))
 end
 constructor("Response",0,response)
 local function request(args)
  required(args,1,"Request");local input=args[1];local init=arg(args,2);local old=bodies[input];if old and old.Kind~="Request"then old=nil end
  local url=if old then old.URL else absoluteURL(input);local methodValue=field(init,"method");local methodName=if methodValue~=U then byteString(methodValue)elseif old then old.Method else "GET"
  if methodName==""or methodName:find("[^!#$%%&'*+.^_`|~%w-]")then fail("TypeError","Invalid HTTP method")end;local upper=methodName:upper();if upper=="CONNECT"or upper=="TRACE"or upper=="TRACK"then fail("TypeError","Forbidden HTTP method")end
  if ({DELETE=true,GET=true,HEAD=true,OPTIONS=true,POST=true,PUT=true})[upper]then methodName=upper end
  local fields={Kind="Request",URL=url,Method=methodName};for name,config in {Mode={"cors",{cors=true,["same-origin"]=true,["no-cors"]=true}},Credentials={"same-origin",{omit=true,["same-origin"]=true,include=true}},Redirect={"follow",{follow=true,error=true,manual=true}},Cache={"default",{default=true,["no-store"]=true,reload=true,["no-cache"]=true,["force-cache"]=true,["only-if-cached"]=true}}}do local key=name:lower();local value=field(init,key);value=if value~=U then text(value)elseif old then old[name]else config[1];if not config[2][value]then fail("TypeError","Invalid Request "..key)end;fields[name]=value end
  if fields.Cache=="only-if-cached"and fields.Mode~="same-origin"then fail("TypeError","only-if-cached requires same-origin mode")end
  if fields.Mode=="no-cors"and methodName~="GET"and methodName~="HEAD"and methodName~="POST"then fail("TypeError","no-cors request method must be GET, HEAD or POST")end
  fields.ReferrerPolicy=if field(init,"referrerPolicy")==U then(if old then old.ReferrerPolicy else "")else text(field(init,"referrerPolicy"))
  fields.Referrer=if field(init,"referrer")==U then(if old then old.Referrer else "about:client")else usv(field(init,"referrer"));fields.Integrity=if field(init,"integrity")==U then(if old then old.Integrity else "")else text(field(init,"integrity"));fields.Keepalive=if field(init,"keepalive")==U then(old and old.Keepalive or false)else VM.truth(field(init,"keepalive"));fields.Destination="";fields.Duplex="half"
  local sourceSignal=field(init,"signal");if sourceSignal==U and old then sourceSignal=old.Signal end
  if sourceSignal~=U and sourceSignal~=N then options.HostEvents:IsAborted(sourceSignal);fields.Signal=vm:Call(abortAny,{vm.Array({sourceSignal})},globals.AbortSignal)else local controller=vm:Construct(abortController,{});fields.Signal=vm.Get(controller,"signal")end
  local headerInit=field(init,"headers");if headerInit==U and old then headerInit=old.Headers end
  local body=field(init,"body");local inherit=body==U or body==N;if inherit and old and old.HasBody then if used(old)or(old.Stream and streams:IsLocked(old.Stream))then fail("TypeError","Input Request body is already used or locked")end;body=streams:Transfer(bodyStream(old))end
  if body~=U and body~=N and(methodName=="GET"or methodName=="HEAD")then fail("TypeError","GET/HEAD requests cannot have a body")end
  if streams:IsStream(body)and not(inherit and old)and field(init,"duplex")~="half"then fail("TypeError","A stream request body requires duplex: half")end
  local result=newBody("Request",fields,body,makeHeaders(headerInit,if fields.Mode=="no-cors"then "request-no-cors"else "request"))

  return result
 end
 constructor("Request",1,request)
 for _,kind in {"Request","Response"}do
  local target=proto[kind]
  accessor(target,"headers",function(value)return brand(bodies,value,kind..".headers").Headers end)
  accessor(target,"body",function(value)return bodyStream(brand(bodies,value,kind..".body"))end)
  accessor(target,"bodyUsed",function(value)return used(brand(bodies,value,kind..".bodyUsed"))end)
  method(target,"clone",0,function(_,value)return cloneBody(value,kind)end)
  method(target,"text",0,function(_,value)return consumeBody(brand(bodies,value,kind..".text"),decodeUTF8)end)
  method(target,"arrayBuffer",0,function(_,value)return consumeBody(brand(bodies,value,kind..".arrayBuffer"),function(bytes)return binary:Buffer(bytes)end)end)
  method(target,"bytes",0,function(_,value)return consumeBody(brand(bodies,value,kind..".bytes"),function(bytes)return binary:FromBytes(bytes)end)end)
  method(target,"json",0,function(_,value)return consumeBody(brand(bodies,value,kind..".json"),function(bytes)return vm:Call(parseJSON,{decodeUTF8(bytes)},jsonIntrinsic)end)end)
  method(target,"formData",0,function(_,value)local state=brand(bodies,value,kind..".formData");return consumeBody(state,function(bytes)local contentType=vm:Call(vm.Get(state.Headers,"get"),{"content-type"},state.Headers);return forms:Parse(bytes,if contentType==N then ""else contentType)end)end)
  method(target,"blob",0,function(_,value)local state=brand(bodies,value,kind..".blob");return consumeBody(state,function(bytes)local contentType=vm:Call(vm.Get(state.Headers,"get"),{"content-type"},state.Headers);return makeBlob(bytes,if contentType==N then ""else mime(contentType))end)end)
 end
 for name,key in {url="URL",status="Status",statusText="StatusText",type="Type",redirected="Redirected"}do accessor(proto.Response,name,function(value)return brand(bodies,value,"Response."..name)[key]end)end
 accessor(proto.Response,"ok",function(value)local status=brand(bodies,value,"Response.ok").Status;return status>=200 and status<=299 end)
 for name,key in {url="URL",method="Method",mode="Mode",credentials="Credentials",cache="Cache",redirect="Redirect",referrer="Referrer",referrerPolicy="ReferrerPolicy",integrity="Integrity",keepalive="Keepalive",destination="Destination",duplex="Duplex",signal="Signal"}do accessor(proto.Request,name,function(value)return brand(bodies,value,"Request."..name)[key]end)end
 method(globals.Response,"error",0,function()local value=response({N});local state=bodies[value];state.Status,state.Type=0,"error";headers[state.Headers].Guard="immutable";return value end)
 method(globals.Response,"redirect",1,function(args)required(args,1,"Response.redirect");local url=absoluteURL(args[1]);local status=if arg(args,2)==U then 302 else int(args[2])%65536;if not({[301]=true,[302]=true,[303]=true,[307]=true,[308]=true})[status]then fail("RangeError","Invalid redirect status")end;local value=response({N,vm.Object({status=status,headers=vm.Object({location=url})})});headers[bodies[value].Headers].Guard="immutable";return value end)
 method(globals.Response,"json",1,function(args)required(args,1,"Response.json");local bytes=vm:Call(stringifyJSON,{args[1]},jsonIntrinsic);if bytes==U then fail("TypeError","JSON data is not serializable")end;local value=response({N,arg(args,2)});local state=bodies[value];if state.Status==204 or state.Status==205 or state.Status==304 then fail("TypeError","This status cannot have a JSON body")end;state.Bytes,state.HasBody=bytes,true;if vm:Call(vm.Get(state.Headers,"has"),{"content-type"},state.Headers)==false then append(headers[state.Headers],"content-type","application/json")end;return value end)
 local fetch=native("fetch",1,function(args)
  local p,resolve,reject=options.CreatePromise();local ok,requestValue=pcall(request,args);if not ok then reject({VM.exceptionValue(requestValue)});return p end
  local state=bodies[requestValue];local signal=state.Signal
  if options.HostEvents:IsAborted(signal)then reject({vm.Get(signal,"reason")});return p end
  local blobURL=state.URL:sub(1,5)=="blob:"
  if not options.Fetch and not blobURL then reject({VM.error("TypeError","No host HTTP adapter is installed")});return p end
  local operation={Done=false};pending[operation]=true
  local function finish(success,value)
   if not api.Alive or operation.Done then return end;operation.Done=true;pending[operation]=nil
   if operation.Unsubscribe then operation.Unsubscribe();operation.Unsubscribe=nil end;operation.Cancel=nil
   if success then resolve({value})else reject({value})end
  end
  operation.Unsubscribe=options.HostEvents:SubscribeAbort(signal,function()
   if operation.Done or not api.Alive then return end;local cancelHost=operation.Cancel;finish(false,vm.Get(signal,"reason"));if cancelHost then pcall(cancelHost)end
  end)
  local function start(bytes)
   if operation.Done or not api.Alive then return end
   local snapshot={url=state.URL,method=state.Method,headerPairs=(function()local pairs={};for _,pair in headers[state.Headers].List do table.insert(pairs,table.clone(pair))end;return pairs end)(),bodyBytes=bytes,mode=state.Mode,credentials=state.Credentials,redirect=state.Redirect,cache=state.Cache,referrer=state.Referrer,referrerPolicy=state.ReferrerPolicy,integrity=state.Integrity,keepalive=state.Keepalive}
   local function completed(success,data)
    if operation.Done or not api.Alive then return end
    options.EnqueueTask(function()
     if operation.Done or not api.Alive then return end
     if not success then finish(false,if type(data)=="table"and data.Kind then data else VM.error("TypeError",tostring(data or "Network request failed")));return end
     local successResponse,value=pcall(function()
      local responseType=data.type or "basic"
      if responseType~="basic"and responseType~="cors"and responseType~="opaque"and responseType~="opaqueredirect"then fail("TypeError","Unsupported host response type")end
      local opaque=responseType=="opaque"or responseType=="opaqueredirect"
      local exposed={['cache-control']=true,['content-language']=true,['content-length']=true,['content-type']=true,expires=true,['last-modified']=true,pragma=true}
      if responseType=="cors"then for _,pair in data.headerPairs or {}do if pair[1]:lower()=="access-control-expose-headers"then for name in pair[2]:gmatch("[^,]+")do exposed[name:lower():match("^%s*(.-)%s*$")]=true end end end end
      local headerInit=vm.Array({})
      if not opaque then for _,pair in data.headerPairs or {}do local name=pair[1]:lower();if name~="set-cookie"and name~="set-cookie2"and(responseType~="cors"or exposed[name]or(exposed["*"]and state.Credentials~="include"))then table.insert(headerInit.Items,vm.Array(pair))end end end
      headerInit.Length=#headerInit.Items
      local noBody=opaque or data.bodyBytes==nil or state.Method=="HEAD"or data.status==204 or data.status==205 or data.status==304
      local responseValue=response({if noBody then N else binary:FromBytes(bound(data.bodyBytes)),vm.Object({status=if opaque then 200 else data.status or 200,statusText=if opaque then ""else data.statusText or "",headers=headerInit})})
      local result=bodies[responseValue];result.URL=if opaque then ""else data.url or state.URL;result.Type=responseType;result.Redirected=not opaque and data.redirected==true
      if opaque then result.Status=0 end;headers[result.Headers].Guard="immutable";return responseValue
     end)
     finish(successResponse,if successResponse then value else VM.exceptionValue(value))
    end)
   end
   if blobURL then
    local resource=api.ObjectURLs:Resolve(state.URL)
    if not resource or state.Method~="GET"then completed(false,VM.error("TypeError","Blob URL is revoked, unavailable or the method is not GET"))
    else
     local bytes=resource.Bytes;local size=#bytes;local status,statusText=200,"OK";local contentRange
     local range=vm:Call(vm.Get(state.Headers,"get"),{"range"},state.Headers)
     if range~=N then
      local first,last=range:match("^bytes[\t ]*=[\t ]*(%d*)[\t ]*%-[\t ]*(%d*)$")
      local startAt,endAt=tonumber(first),tonumber(last)
      if not first or first==""and last==""or startAt and endAt and startAt>endAt then completed(false,VM.error("TypeError","Invalid Blob byte range"));return end
      if not startAt then
       startAt=math.max(0,size-endAt);endAt=size-1
      else
       if startAt>=size then completed(false,VM.error("TypeError","Blob byte range is out of bounds"));return end
       endAt=math.min(endAt or size-1,size-1)
      end
      bytes=bytes:sub(startAt+1,endAt+1);status,statusText=206,"Partial Content";contentRange="bytes "..startAt.."-"..endAt.."/"..size
     end
     local pairs={{"content-type",resource.Type},{"content-length",tostring(#bytes)}};if contentRange then table.insert(pairs,{"content-range",contentRange})end
     completed(true,{status=status,statusText=statusText,url=resource.URL,bodyBytes=bytes,headerPairs=pairs})
    end
    return
   end
   local success,cancelHost=pcall(options.Fetch,snapshot,completed,signal)
   if not success then finish(false,VM.exceptionValue(cancelHost))elseif not operation.Done then operation.Cancel=if type(cancelHost)=="function"then cancelHost else nil elseif type(cancelHost)=="function"then pcall(cancelHost)end
  end
  if state.HasBody then options.Await(consumeBody(state,function(bytes)return bytes end),start,function(reason)finish(false,reason)end)else start(nil)end
  return p
 end)
 globals.fetch=fetch;vm.Global.Bindings.fetch={Value=fetch}
 function api:DescribeBlob(value)local state=blobs[value];return if state then table.clone(state)else nil end
 function api:CreateBlob(state)check();bound(state.Bytes);return object(if state.Name then "File"else "Blob",blobs,table.clone(state))end
 local files=FileData.install(vm,globals,{Events=options.HostEvents,Network=api,Binary=binary,EnqueueTask=options.EnqueueTask,MaxBytes=limit});api.Files=files
 local objectOrigin=options.Origin
 if not objectOrigin then local ok,value=pcall(function()return vm.Get(vm:Construct(urlIntrinsic,{options.BaseURL or "about:blank"}),"origin")end);objectOrigin=if ok then value else "null"end
 local objectURLs=ObjectURLs.install(vm,globals,{Network=api,Origin=objectOrigin,Store=options.ObjectURLStore,PartitionKey=options.ObjectURLPartitionKey,MaxBytes=options.MaxObjectURLBytes});api.ObjectURLs=objectURLs
 local encodingStreams=EncodingStreams.install(vm,globals,{Transforms=transforms,Binary=binary})
 local xhr=XMLHttpRequest.install(vm,globals,{Events=options.HostEvents,Network=api,Fetch=fetch,Await=options.Await,
  EnqueueTask=options.EnqueueTask,CancelTask=options.CancelTask,Now=options.RequestNow,IsWorker=options.IsWorker,ExtractBody=extract,ConvertBody=function(value)
   if blobs[value]or forms:IsFormData(value)or binary:IsBufferSource(value)or(type(value)=='table'and(value.Kind=='url-search-params'or value.DOMNode and value.DOMNode.Kind=='Document'))then return value end
   return usv(value)
  end});api.XMLHttpRequest=xhr
 function api:ObjectURL(url)return objectURLs:Resolve(url)end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  for operation in pending do operation.Done=true;if operation.Unsubscribe then operation.Unsubscribe()end;if operation.Cancel then pcall(operation.Cancel)end;operation.Cancel,operation.Unsubscribe=nil,nil end;table.clear(pending)
  xhr:Destroy();files:Destroy();objectURLs:Destroy();encodingStreams:Destroy();forms:Destroy();piping:Destroy();transforms:Destroy();writable:Destroy();streams:Destroy();if not options.Binary then binary:Destroy()end
  table.clear(encoders);table.clear(decoders);table.clear(blobs);table.clear(headers);table.clear(bodies)
 end
 return api
end
return NetworkData
