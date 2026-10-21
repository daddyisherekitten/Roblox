--!strict
-- Asynchronous XHR over the existing buffered fetch adapter. Completion exposes
-- one received byte batch; it does not invent network chunks or upload timing.
local Strings=require(script.Parent.Strings)
local Decoder=require(script.Parent.Parent.Encoding.Decoder)
local XMLHttpRequest={}
function XMLHttpRequest.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true}
 local events,network=options.Events,options.Network;local binary=network.Binary
 local records=setmetatable({},{__mode='kv'});local active={}
 local eventTarget=vm.Get(globals.EventTarget,'prototype')
 local baseProto=vm.Object({},eventTarget);local uploadProto=vm.Object({},baseProto);local proto=vm.Object({},baseProto)
 local fetch,requestCtor,headersCtor,abortCtor=options.Fetch,globals.Request,globals.Headers,globals.AbortController
 local progressCtor,decoderCtor=globals.ProgressEvent,globals.TextDecoder
 local parseJSON=vm.Get(vm.Global.Bindings.JSON.Value,'parse');local json=vm.Global.Bindings.JSON.Value
 local parserCtor=globals.DOMParser;local serializerCtor=globals.XMLSerializer
 local function check()assert(api.Alive and vm.Alive,'XMLHttpRequest disposed')end
 local function fail(name,message)VM.throw(if name=='TypeError'or name=='RangeError'then VM.error(name,message)else events:DOMException(message,name))end
 local function arg(args,index)return if args[index]==nil then U else args[index]end
 local function text(value)value=vm.ToPrimitive(value,'string');if type(value)=='table'and value.Kind=='symbol'then fail('TypeError','Cannot convert Symbol to string')end;return VM.string(value)end
 local function bytestring(value)local result=text(value);for code in Strings.codes(result)do vm.Step();if code>255 then fail('TypeError','Expected ByteString')end end;return result end
 local function define(target,key,d)vm.DefineProperty(target,key,vm.Object(d,VM.Null))end
 local function native(name,length,fn)local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end};define(value,'name',{value=name,configurable=true});define(value,'length',{value=length,configurable=true});return value end
 local function method(target,key,length,fn)define(target,key,{value=native(key,length,fn),writable=true,enumerable=true,configurable=true})end
 local function accessor(key,get,set)define(proto,key,{get=native('get '..key,0,function(_,value)return get(value)end),set=if set then native('set '..key,1,function(args,value)set(value,arg(args,1));return U end)else U,enumerable=true,configurable=true})end
 local function state(value)local result=records[value];if not result then fail('TypeError','Illegal XMLHttpRequest receiver')end;return result end
 local function call(value,key,args)return vm:Call(vm.Get(value,key),args or {},value)end
 local function alive(s,token)return api.Alive and vm.Alive and s.Token==token end
 local function dispatch(s,name,upload,loaded,total)
  if not api.Alive or not vm.Alive then return end
  local event=if name=='readystatechange'then events:NewEvent(name)else vm:Construct(progressCtor,{name,vm.Object({loaded=loaded or 0,total=total or 0,lengthComputable=(total or 0)>0})})
  events:Dispatch(if upload then s.Upload else s.Value,event,true)
 end
 local function cancelTimer(s)
  if s.Timer and options.CancelTask then options.CancelTask(s.Timer)end;s.Timer=nil;s.TimerGeneration+=1
 end
 local function cancelTransport(s)
  local controller=s.Controller;s.Controller=nil;if controller then pcall(call,controller,'abort')end
 end
 local function clearResponse(s)s.Status,s.StatusText,s.ResponseURL,s.Bytes,s.Response,s.ResponseHeaders=0,'','','',N,nil;s.Text=nil;s.XML=nil;s.ResponseReady=false end
 local function stop(s)
  s.Token+=1;local token=s.Token;cancelTimer(s);active[s.Value]=nil;s.Sent=false
  -- Host cancellation can reenter JS. Publish the retired state before it, and
  -- never overwrite a replacement request started by that external callback.
  cancelTransport(s);return token
 end
 local function terminalError(s,kind)
  if not s.Sent then return end
  local token=stop(s);if not alive(s,token)then return token end
  clearResponse(s);s.Ready=4;dispatch(s,'readystatechange')
  if not alive(s,token)then return token end
  if not s.UploadDone then s.UploadDone=true;dispatch(s,kind,true);if not alive(s,token)then return end;dispatch(s,'loadend',true)end
  if not alive(s,token)then return token end;dispatch(s,kind)
  if api.Alive and vm.Alive then dispatch(s,'loadend')end;return token
 end
 local function now()return if options.Now then options.Now()else os.clock()*1000 end
 local function timer(s)
  cancelTimer(s);if not s.Sent or s.Timeout==0 then return end
  local token,generation=s.Token,s.TimerGeneration
  s.Timer=options.EnqueueTask(function()
   if not alive(s,token)or s.TimerGeneration~=generation or not s.Sent then return end
   s.Timer=nil;terminalError(s,'timeout')
  end,math.max(0,s.Started+s.Timeout-now())/1000)
 end
 local function normalizedMIME(mime,fallback)
  mime=mime:match('^[ \t\r\n]*(.-)[ \t\r\n]*$');local head=(mime:match('^([^;]+)')or''):gsub('[ \t]+$','')
  return if head:match("^[!#$%%&'*+.^_`|~%w-]+/[!#$%%&'*+.^_`|~%w-]+$")then mime else fallback
 end
 local function essence(mime)return (mime:match('^%s*([^;]+)')or'application/octet-stream'):lower():gsub('%s+$','')end
 local function responseMIME(s)
  if s.Override then return s.Override end
  if s.ResponseHeaders then local value=call(s.ResponseHeaders,'get',{'content-type'});if value~=N then return normalizedMIME(value,'text/xml')end end
  return 'text/xml'
 end
 local function decode(s,jsonMode)
  local label='utf-8'
  if not jsonMode then
   local charset=responseMIME(s):match('[Cc][Hh][Aa][Rr][Ss][Ee][Tt]%s*=%s*["\']?([^;"\'%s]+)')
   local normalized=charset and Decoder.label(charset);if normalized and Decoder.supported(normalized)then label=normalized end
   if s.Bytes:sub(1,3)=='\239\187\191'then label='utf-8'elseif s.Bytes:sub(1,2)=='\255\254'then label='utf-16le'elseif s.Bytes:sub(1,2)=='\254\255'then label='utf-16be'end
  end
  local decoder=vm:Construct(decoderCtor,{label});return call(decoder,'decode',{binary:FromBytes(s.Bytes)})
 end
 local function documentResponse(s)
  if s.XML~=nil then return s.XML end;s.XML=N
  local mime=essence(responseMIME(s));local html=mime=='text/html'
  if #s.Bytes==0 or(html and s.Type~='document')or not(html or mime=='text/xml'or mime=='application/xml'or mime:sub(-4)=='+xml')or not parserCtor then return N end
  local ok,result=pcall(function()
   local parser=vm:Construct(parserCtor,{});local document=call(parser,'parseFromString',{decode(s,false),if html then 'text/html'else 'application/xml'})
   if not html and vm.Get(call(document,'getElementsByTagName',{'parsererror'}),'length')>0 then return N end
   if document.DOMNode then document.DOMNode.URL=s.ResponseURL;document.DOMNode.ContentType=mime end
   return document
  end)
  if ok then s.XML=result end;return s.XML
 end
 local function response(s)
  if s.Type==''or s.Type=='text'then
   if s.Ready~=3 and s.Ready~=4 then return ''end
   if s.Text==nil then s.Text=decode(s,false)end;return s.Text
  end
  if s.Ready~=4 or s.Status==0 then return N end
  if s.ResponseReady then return s.Response end;s.ResponseReady=true
  if s.Type=='arraybuffer'then s.Response=binary:Buffer(s.Bytes)
  elseif s.Type=='blob'then s.Response=network:CreateBlob({Bytes=s.Bytes,Type=essence(responseMIME(s))})
  elseif s.Type=='json'then local ok,result=pcall(vm.Call,vm,parseJSON,{decode(s,true)},json);if ok then s.Response=result end
  elseif s.Type=='document'then s.Response=documentResponse(s)end
  return s.Response
 end
 local function receive(s,token,result)
  if not alive(s,token)or not s.Sent then return end
  if vm.Get(result,'status')==0 then terminalError(s,'error');return end
  -- The buffered adapter has completed the entire request/response. Upload byte
  -- totals are exact, but these terminal notifications are not live wire progress.
  if not s.UploadDone then
   s.UploadDone=true;dispatch(s,'progress',true,s.UploadBytes,s.UploadBytes)
   if not alive(s,token)then return end;dispatch(s,'load',true,s.UploadBytes,s.UploadBytes)
   if not alive(s,token)then return end;dispatch(s,'loadend',true,s.UploadBytes,s.UploadBytes)
  end
  if not alive(s,token)then return end
  s.Status,s.StatusText,s.ResponseURL,s.ResponseHeaders=vm.Get(result,'status'),vm.Get(result,'statusText'),(vm.Get(result,'url'):gsub('#.*$','')),vm.Get(result,'headers')
  s.Ready=2;dispatch(s,'readystatechange');if not alive(s,token)or not s.Sent then return end
  options.Await(call(result,'arrayBuffer'),function(bufferValue)
   if not alive(s,token)or not s.Sent then return end
   s.Bytes=binary:ReadBytes(bufferValue);s.Text=nil
   local raw=call(s.ResponseHeaders,'get',{'content-length'});local total=if type(raw)=='string'and raw:match('^%d+$')then tonumber(raw)or 0 else 0
   if #s.Bytes>0 then s.Ready=3;dispatch(s,'readystatechange');if not alive(s,token)or not s.Sent then return end end
   dispatch(s,'progress',false,#s.Bytes,total);if not alive(s,token)or not s.Sent then return end
   cancelTimer(s);s.Sent=false;active[s.Value]=nil;s.Controller=nil;s.Ready=4;dispatch(s,'readystatechange')
   if not alive(s,token)then return end
   local loaded=#s.Bytes;dispatch(s,'load',false,loaded,total)
   if api.Alive and vm.Alive then dispatch(s,'loadend',false,loaded,total)end
  end,function()if alive(s,token)then terminalError(s,'error')end end)
 end
 method(proto,'open',2,function(args,value)
  local s=state(value);if #args<2 then fail('TypeError','open requires method and URL')end
  local methodName=bytestring(args[1]);local url=text(args[2]);local async=if #args<3 then true else VM.truth(args[3])
  if methodName==''or methodName:find("[^!#$%%&'*+.^_`|~%w-]")then fail('SyntaxError','Invalid HTTP method')end
  local upper=methodName:upper();if upper=='CONNECT'or upper=='TRACE'or upper=='TRACK'then fail('SecurityError','Forbidden HTTP method')end
  if not async then fail('NotSupportedError','Synchronous XMLHttpRequest requires a blocking transport and is not supported')end
  if(arg(args,4)~=U and arg(args,4)~=N)or(arg(args,5)~=U and arg(args,5)~=N)then fail('NotSupportedError','XHR URL credentials require a host authentication adapter')end
  local ok,request=pcall(function()return vm:Construct(requestCtor,{url,vm.Object({method=methodName})})end)
  if not ok then fail('SyntaxError','Invalid XMLHttpRequest URL')end
  local token=stop(s);if not alive(s,token)then return U end
  clearResponse(s);s.Method,s.URL,s.Headers,s.Override=vm.Get(request,'method'),vm.Get(request,'url'),vm:Construct(headersCtor,{}),nil
  local changed=s.Ready~=1;s.Ready=1;if changed then dispatch(s,'readystatechange')end;return U
 end)
 method(proto,'setRequestHeader',2,function(args,value)
  local s=state(value);if #args<2 then fail('TypeError','setRequestHeader requires name and value')end
  local name,content=bytestring(args[1]),bytestring(args[2])
  if s.Ready~=1 or s.Sent then fail('InvalidStateError','Request is not opened or is already sending')end
  if name==''or name:find("[^!#$%%&'*+.^_`|~%w-]")or content:find('[\r\n%z]')then fail('SyntaxError','Invalid request header')end
  call(s.Headers,'append',{name,content});return U
 end)
 method(proto,'send',0,function(args,value)
  local s=state(value);local body=arg(args,1)
  if body~=U and body~=N then body=options.ConvertBody(body)end
  if s.Ready~=1 or s.Sent then fail('InvalidStateError','Request is not opened or is already sending')end
  local bytes,contentType
  if s.Method~='GET'and s.Method~='HEAD'and body~=U and body~=N then
   if type(body)=='table'and body.DOMNode and body.DOMNode.Kind=='Document'then
    if not serializerCtor then fail('NotSupportedError','Document request serialization is unavailable')end
    if body.DOMNode.IsHTML~=false then body=require(script.Parent.DOMMarkup).serialize(body.DOMNode,true);contentType='text/html;charset=UTF-8'
    else body=call(vm:Construct(serializerCtor,{}),'serializeToString',{body});contentType='application/xml;charset=UTF-8'end
   end
   local extracted,kind=options.ExtractBody(body);bytes=extracted;contentType=contentType or kind
  end
  if contentType and call(s.Headers,'has',{'content-type'})==false then call(s.Headers,'set',{'content-type',contentType})end
  local count=0;for _ in active do count+=1 end;if count>=128 then fail('QuotaExceededError','Active XMLHttpRequest budget exceeded')end
  s.Token+=1;local token=s.Token;s.Sent,s.UploadDone,s.UploadBytes,s.Started=true,bytes==nil,if bytes then #bytes else 0,now();active[value]=true
  s.Controller=vm:Construct(abortCtor,{})
  local ok,message=pcall(timer,s);if not ok then stop(s);error(message,0)end
  dispatch(s,'loadstart');if not alive(s,token)or not s.Sent then return U end
  if not s.UploadDone then dispatch(s,'loadstart',true);if not alive(s,token)or not s.Sent then return U end end
  local init=vm.Object({method=s.Method,headers=s.Headers,credentials=if s.Credentials then 'include'else 'same-origin',signal=vm.Get(s.Controller,'signal'),body=if bytes then binary:FromBytes(bytes)else N})
  local success,promise=pcall(vm.Call,vm,fetch,{s.URL,init},U)
  if success then options.Await(promise,function(result)receive(s,token,result)end,function()if alive(s,token)then terminalError(s,'error')end end)
  else options.EnqueueTask(function()if alive(s,token)then terminalError(s,'error')end end)end
  return U
 end)
 method(proto,'abort',0,function(_,value)
  local s=state(value);local token=if s.Sent then terminalError(s,'abort')else stop(s)
  if alive(s,token)and s.Ready==4 then s.Ready=0;clearResponse(s)end;return U
 end)
 method(proto,'getResponseHeader',1,function(args,value)
  local s=state(value);if #args<1 then fail('TypeError','getResponseHeader requires a name')end;local name=bytestring(args[1])
  if s.Ready<2 or not s.ResponseHeaders then return N end
  local ok,result=pcall(call,s.ResponseHeaders,'get',{name});return if ok then result else N
 end)
 method(proto,'getAllResponseHeaders',0,function(_,value)
  local s=state(value);if s.Ready<2 or not s.ResponseHeaders then return ''end
  local result={};local iterator=call(s.ResponseHeaders,'entries');while true do local item=call(iterator,'next');if VM.truth(vm.Get(item,'done'))then break end;local pair=vm.Get(item,'value');table.insert(result,vm.Get(pair,'0')..': '..vm.Get(pair,'1')..'\r\n')end;return table.concat(result)
 end)
 method(proto,'overrideMimeType',1,function(args,value)
  local s=state(value);if #args<1 then fail('TypeError','overrideMimeType requires a MIME type')end;local mime=text(args[1])
  if s.Ready==3 or s.Ready==4 then fail('InvalidStateError','Response is already loading')end
  s.Override=normalizedMIME(mime,'application/octet-stream');return U
 end)
 accessor('readyState',function(value)return state(value).Ready end)
 accessor('status',function(value)return state(value).Status end)
 accessor('statusText',function(value)return state(value).StatusText end)
 accessor('responseURL',function(value)return state(value).ResponseURL end)
 accessor('upload',function(value)return state(value).Upload end)
 accessor('timeout',function(value)return state(value).Timeout end,function(value,raw)
  local s=state(value);local number=VM.number(vm.ToPrimitive(raw,'number'));number=if number~=number or math.abs(number)==math.huge then 0 else(if number<0 then math.ceil(number)else math.floor(number))%4294967296
  s.Timeout=number;if s.Sent then timer(s)end
 end)
 accessor('withCredentials',function(value)return state(value).Credentials end,function(value,raw)local s=state(value);if s.Ready>1 or s.Sent then fail('InvalidStateError','Request is already sending')end;s.Credentials=VM.truth(raw)end)
 accessor('responseType',function(value)return state(value).Type end,function(value,raw)
  local s=state(value);local kind=text(raw);if not({['']=true,text=true,json=true,blob=true,arraybuffer=true,document=true})[kind]or(kind=='document'and options.IsWorker)then return end
  if s.Ready==3 or s.Ready==4 then fail('InvalidStateError','Response is already loading')end;s.Type=kind;s.Response=N;s.ResponseReady=false;s.Text=nil;s.XML=nil
 end)
 accessor('response',function(value)return response(state(value))end)
 accessor('responseText',function(value)local s=state(value);if s.Type~=''and s.Type~='text'then fail('InvalidStateError','responseText requires text responseType')end;return response(s)end)
 if not options.IsWorker then accessor('responseXML',function(value)local s=state(value);if s.Type~=''and s.Type~='document'then fail('InvalidStateError','responseXML requires document responseType')end;return if s.Ready==4 and s.Status~=0 then documentResponse(s)else N end)end
 local handlers={};for _,name in {'loadstart','progress','abort','error','load','timeout','loadend'}do handlers['on'..name]=true end
 local function constructor(name,target,create)
  local ctor=native(name,0,function()fail('TypeError',name..' requires new')end);ctor.Construct=function()check();return create()end
  define(ctor,'prototype',{value=target});define(target,'constructor',{value=ctor,writable=true,configurable=true});define(target,vm.SymbolToStringTag,{value=name,configurable=true});globals[name]=ctor;vm.Global.Bindings[name]={Value=ctor};return ctor
 end
 local baseCtor=constructor('XMLHttpRequestEventTarget',baseProto,function()fail('TypeError','Illegal constructor')end)
 local uploadCtor=constructor('XMLHttpRequestUpload',uploadProto,function()fail('TypeError','Illegal constructor')end)
 local ctor=constructor('XMLHttpRequest',proto,function()
  local value=vm.Object({},proto);local upload=vm.Object({},uploadProto)
  local s={Value=value,Upload=upload,Ready=0,Sent=false,Token=0,Timeout=0,Credentials=false,Type='',Response=N,UploadDone=true,TimerGeneration=0}
  clearResponse(s);value.XMLHttpRequestState=s;records[value]=s
  events:WrapTarget(upload,{Handlers=true,HandlerNames=handlers,Parent=function()return nil end})
  local names=table.clone(handlers);names.onreadystatechange=true;events:WrapTarget(value,{Handlers=true,HandlerNames=names,Parent=function()return nil end});return value
 end)
 vm.SetPrototype(baseCtor,globals.EventTarget);vm.SetPrototype(ctor,baseCtor);vm.SetPrototype(uploadCtor,baseCtor)
 for name,value in {UNSENT=0,OPENED=1,HEADERS_RECEIVED=2,LOADING=3,DONE=4}do define(proto,name,{value=value,enumerable=true});define(ctor,name,{value=value,enumerable=true})end
 function api:AttachDocumentIntrinsics(parser,serializer)
  check();if not parserCtor then parserCtor=parser end;if not serializerCtor then serializerCtor=serializer end
 end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  for _,s in records do stop(s);clearResponse(s);events:EraseListeners(s.Value);events:EraseListeners(s.Upload)end
  table.clear(active);table.clear(records)
 end
 return api
end
return XMLHttpRequest
