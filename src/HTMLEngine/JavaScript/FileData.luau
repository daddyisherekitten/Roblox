--!strict
-- In-memory File/Blob reads use the realm task queue. Actual file selection is
-- a host capability supplied as ordered File wrappers, never a filesystem path.
local PNG=require(script.Parent.Parent.Rendering.CanvasPNG)
local FileData={}
function FileData.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true}
 local readers,lists,progress=setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"}),setmetatable({},{__mode="kv"});local active={}
 local events=options.Events;local network,binary=options.Network,options.Binary
 local decoderCtor=globals.TextDecoder;local decoderMethod=vm.Get(vm.Get(decoderCtor,"prototype"),"decode")
 local readerProto=vm.Object({},vm.Get(globals.EventTarget,"prototype"));local listProto=vm.Object({});local progressProto=vm.Object({},vm.Get(globals.Event,"prototype"))
 local function check()assert(api.Alive and vm.Alive,"File data disposed")end
 local function fail(name,message)VM.throw(if name~="TypeError"and name~="RangeError"then events:DOMException(message,name)else VM.error(name,message))end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function text(value)value=vm.ToPrimitive(value,"string");if type(value)=="table"and value.Kind=="symbol"then fail("TypeError","Cannot convert a Symbol to string")end;return VM.string(value)end
 local function field(value,key)return if value==nil or value==U or value==N then U else vm.Get(value,key)end
 local function def(value,key,d)vm.DefineProperty(value,key,vm.Object(d,VM.Null))end
 local function native(name,n,fn)local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end};def(value,"length",{value=n,configurable=true});def(value,"name",{value=name,configurable=true});return value end
 local function method(proto,key,n,fn)def(proto,key,{value=native(key,n,fn),writable=true,enumerable=true,configurable=true})end
 local function getter(proto,key,fn)def(proto,key,{get=native("get "..key,0,function(_,receiver)return fn(receiver)end),enumerable=true,configurable=true})end
 local function ctor(name,n,proto,fn)local value=native(name,n,function()fail("TypeError",name.." requires new")end);value.Construct=function(args)check();return fn(args)end;def(value,"prototype",{value=proto});def(proto,"constructor",{value=value,writable=true,configurable=true});def(proto,vm.SymbolToStringTag,{value=name,configurable=true});globals[name]=value;vm.Global.Bindings[name]={Value=value};return value end
 local function reader(value)local state=readers[value];if not state then fail("TypeError","Expected FileReader")end;return state end
 local function list(value)local state=lists[value];if not state then fail("TypeError","Expected FileList")end;return state end
 local function progressEvent(name,init)
  local value=events:NewEvent(name,init);vm.SetPrototype(value,progressProto)
  local state={LengthComputable=init.lengthComputable==true,Loaded=init.loaded or 0,Total=init.total or 0};value.ProgressState=state;progress[value]=state;return value
 end
 local progressCtor=ctor("ProgressEvent",1,progressProto,function(args)
  if #args<1 then fail("TypeError","ProgressEvent requires a type")end;local name=text(args[1]);local init=arg(args,2);local values={}
  if init~=U and init~=N and(type(init)~="table"and type(init)~="function"or type(init)=="table"and(init.Kind=="symbol"or init.Kind=="bigint"))then fail("TypeError","ProgressEvent requires a dictionary")end
  for _,key in {"bubbles","cancelable","composed","lengthComputable","loaded","total"}do
   local value=field(init,key)
   if key=="loaded"or key=="total"then value=if value==U then 0 else VM.number(value);if value~=value or math.abs(value)==math.huge then fail("TypeError","ProgressEvent count must be finite")end;values[key]=value
   else values[key]=VM.truth(value)end
  end
  return progressEvent(name,values)
 end)
 vm.SetPrototype(progressCtor,globals.Event)
 for key,name in {lengthComputable="LengthComputable",loaded="Loaded",total="Total"}do getter(progressProto,key,function(value)local state=progress[value];if not state then fail("TypeError","Expected ProgressEvent")end;return state[name]end)end
 local function dispatch(value,name,loaded,total,computable)
  if not api.Alive then return end
  events:Dispatch(value,progressEvent(name,{loaded=loaded or 0,total=total or 0,lengthComputable=computable~=false}),true)
 end
 local function queue(value,token,fn)
  options.EnqueueTask(function()if api.Alive and vm.Alive then local state=readers[value];if state and state.Token==token and state.ReadyState==1 then fn(state)end end end)
 end
 local function decode(blob,label)
  local bytes=blob.Bytes
  if bytes:sub(1,3)=="\239\187\191"then label="utf-8"elseif bytes:sub(1,2)=="\255\254"then label="utf-16le"elseif bytes:sub(1,2)=="\254\255"then label="utf-16be"end
  local function decoderFor(candidate)if candidate==nil then return false,nil end;return pcall(function()return vm:Construct(decoderCtor,{candidate})end)end
  local ok,decoder=decoderFor(label)
  if not ok then ok,decoder=decoderFor(blob.Type:match("[Cc][Hh][Aa][Rr][Ss][Ee][Tt]%s*=%s*['\"]?([^;'\"%s]+)"))end
  if not ok then decoder=vm:Construct(decoderCtor,{"utf-8"})end
  return vm:Call(decoderMethod,{binary:FromBytes(bytes)},decoder)
 end
 local function read(value,args,kind)
  local state=reader(value);if #args<1 then fail("TypeError","FileReader requires a Blob")end
  local blob=network:DescribeBlob(args[1]);if not blob then fail("TypeError","FileReader requires a Blob")end
  local label=if kind=="text"and arg(args,2)~=U then text(args[2])else nil
  if state.ReadyState==1 then fail("InvalidStateError","FileReader is already reading")end
  if #blob.Bytes>(options.MaxBytes or 1048576)then fail("RangeError","FileReader byte budget exceeded")end
  local previous={state.ReadyState,state.Result,state.Error}
  state.ReadyState,state.Result,state.Error=1,N,N;state.Token+=1;local token=state.Token;active[value]=true
  local scheduled=pcall(function()
  queue(value,token,function()dispatch(value,"loadstart",0,#blob.Bytes)end)
  queue(value,token,function(current)
   dispatch(value,"progress",#blob.Bytes,#blob.Bytes)
   if not api.Alive or current.Token~=token or current.ReadyState~=1 then return end
   local ok,result=pcall(function()
    if kind=="buffer"then return binary:Buffer(blob.Bytes)
    elseif kind=="url"then return "data:"..(if blob.Type==""then "application/octet-stream"else blob.Type)..";base64,"..PNG.base64(buffer.fromstring(blob.Bytes),vm.Step)
    elseif kind=="binary"then local parts={};for i=1,#blob.Bytes do if i%256==1 then vm.Step()end;parts[i]=utf8.char(blob.Bytes:byte(i))end;return table.concat(parts)
    else return decode(blob,label)end
   end)
   if not api.Alive or current.Token~=token or current.ReadyState~=1 then return end
   current.ReadyState=2;active[value]=nil
   if ok then current.Result=result;dispatch(value,"load",#blob.Bytes,#blob.Bytes)
   else current.Error=events:DOMException("The Blob could not be read","NotReadableError");dispatch(value,"error",0,#blob.Bytes)end
   if api.Alive and current.ReadyState~=1 then dispatch(value,"loadend",if ok then #blob.Bytes else 0,#blob.Bytes)end
  end)
  end)
  if not scheduled then
   state.Token+=1;state.ReadyState,state.Result,state.Error=previous[1],previous[2],previous[3];active[value]=nil
   fail("RangeError","FileReader task queue budget exceeded")
  end
  return U
 end
 for name,kind in {readAsArrayBuffer="buffer",readAsText="text",readAsDataURL="url",readAsBinaryString="binary"}do method(readerProto,name,1,function(args,value)return read(value,args,kind)end)end
 method(readerProto,"abort",0,function(_,value)
  local state=reader(value);state.Result=N
  if state.ReadyState~=1 then return U end
  state.ReadyState=2;state.Token+=1;active[value]=nil;dispatch(value,"abort",0,0,false)
  if api.Alive and state.ReadyState~=1 then dispatch(value,"loadend",0,0,false)end;return U
 end)
 for name,key in {readyState="ReadyState",result="Result",error="Error"}do getter(readerProto,name,function(value)return reader(value)[key]end)end
 local readerCtor=ctor("FileReader",0,readerProto,function()
  local value=vm.Object({},readerProto);local state={ReadyState=0,Result=N,Error=N,Token=0};value.FileReaderState=state;readers[value]=state
  events:WrapTarget(value,{Handlers=true,HandlerNames={onloadstart=true,onprogress=true,onload=true,onabort=true,onerror=true,onloadend=true}});return value
 end)
 vm.SetPrototype(readerCtor,globals.EventTarget)
 for name,value in {EMPTY=0,LOADING=1,DONE=2}do def(readerProto,name,{value=value,enumerable=true});def(readerCtor,name,{value=value,enumerable=true})end
 ctor("FileList",0,listProto,function()fail("TypeError","Illegal FileList constructor")end)
 getter(listProto,"length",function(value)return #list(value).Files end)
 method(listProto,"item",1,function(args,value)
  local state=list(value);if #args<1 then fail("TypeError","FileList.item requires an index")end;local n=VM.number(args[1]);n=if n~=n or math.abs(n)==math.huge then 0 else(if n<0 then math.ceil(n)else math.floor(n))%4294967296;return state.Files[n+1]or N
 end)
 def(listProto,vm.SymbolIterator,{value=vm.Get(vm.Prototypes.Array,"values"),writable=true,configurable=true})
 function api:CreateFileList(files)
  check();local state={Files={}};local backing=vm.Object({});local value={Kind="file-list",Prototype=listProto,FileListState=state};lists[value]=state
  local function index(key)if type(key)~="string"then return nil end;local n=tonumber(key);return if n and n>=0 and n<4294967295 and n==math.floor(n)and tostring(n)==key then n else nil end
  value.Get=function(key,receiver)local i=index(key);return if i then state.Files[i+1]or U elseif vm.HasOwn(backing,key)then vm.Get(backing,key,receiver or value)else U end
  value.GetOwnPropertyDescriptor=function(key)
   local i=index(key);if i then return if state.Files[i+1]then {Value=state.Files[i+1],Writable=false,Enumerable=true,Configurable=true}else nil end
   local d=vm.GetOwnPropertyDescriptor(backing,key);if d==U then return nil end
   return if vm.Has(d,"value")then {Value=vm.Get(d,"value"),Writable=VM.truth(vm.Get(d,"writable")),Enumerable=VM.truth(vm.Get(d,"enumerable")),Configurable=VM.truth(vm.Get(d,"configurable"))}else {Accessor=true,Get=vm.Get(d,"get"),Set=vm.Get(d,"set"),Enumerable=VM.truth(vm.Get(d,"enumerable")),Configurable=VM.truth(vm.Get(d,"configurable"))}
  end
  value.Set=function(key,item,strict)check();if index(key)or key=="length"and not vm.HasOwn(backing,key)then if strict then fail("TypeError","FileList index is read-only")end;return false end;return vm.Set(backing,key,item,strict)end
  value.DefineProperty=function(key,d,strict)check();if index(key)then if strict==false then return false end;fail("TypeError","FileList indices cannot be redefined")end;vm.DefineProperty(backing,key,d);return value end
  value.Delete=function(key)local i=index(key);if i then return not state.Files[i+1]end;return vm.Delete(backing,key)end
  value.PreventExtensions=function()return false end;value.IsExtensible=function()return true end
  value.HasOwn=function(key)return value.GetOwnPropertyDescriptor(key)~=nil end
  value.Keys=function(enumerable)local keys={};for i=1,#state.Files do table.insert(keys,tostring(i-1))end;for _,key in vm.OwnKeys(backing,enumerable)do table.insert(keys,key)end;return keys end
  self:UpdateFileList(value,files);return value
 end
 function api:UpdateFileList(value,files)
  check();local state=list(value);if #files>1024 then fail("RangeError","FileList entry budget exceeded")end;local copy={}
  for _,file in files do vm.Step();local snapshot=network:DescribeBlob(file);if not snapshot or snapshot.Name==nil then fail("TypeError","FileList requires File entries")end;table.insert(copy,file)end;state.Files=copy
 end
 function api:FileListValues(value)check();return table.clone(list(value).Files)end
 function api:IsFileList(value)return lists[value]~=nil end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false;for _,state in readers do state.Token+=1;state.Result,state.Error=N,N end
  for _,state in lists do state.Files={}end;table.clear(active);table.clear(readers);table.clear(lists);table.clear(progress)
 end
 return api
end
return FileData
