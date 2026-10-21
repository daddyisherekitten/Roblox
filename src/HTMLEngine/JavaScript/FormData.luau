--!strict
-- Ordered form entry lists and bounded multipart serialization/parsing.
local FormData={}
function FormData.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true};local records=setmetatable({},{__mode="kv"});local constructing=setmetatable({},{__mode="k"});local eventRecords=setmetatable({},{__mode="kv"});local proto=vm.Object({})
 local urlParams=vm.Global.Bindings.URLSearchParams.Value;local maxBytes=options.MaxBytes or 1048576
 local function fail(message)VM.throw(VM.error("TypeError",message))end
 local function check()assert(api.Alive and vm.Alive,"JavaScript FormData disposed")end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function usv(value)return options.ToUSV(value)end
 local function def(value,key,desc)vm.DefineProperty(value,key,vm.Object(desc,VM.Null))end
 local function native(name,n,fn)local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end};def(value,"length",{value=n,configurable=true});def(value,"name",{value=name,configurable=true});return value end
 local function method(name,n,fn)def(proto,name,{value=native(name,n,fn),writable=true,enumerable=true,configurable=true})end
 local function state(value)local record=records[value];if not record then fail("FormData requires a compatible receiver")end;return record end
 local function required(args,count,name)if #args<count then fail("FormData."..name.." requires "..count.." arguments")end end
 local function make()
  local value=vm.Object({},proto);local record={Entries={}};value.NetworkState=record;records[value]=record;return value
 end
 local function fileValue(value,filename,explicit)
  local blob=options.DescribeBlob(value)
  if explicit and not blob then fail("A filename requires a Blob value")end
  if not blob then return usv(value)end
  if blob.Name and filename==U then return value end
  local name=if filename~=U then usv(filename)elseif blob.Name then blob.Name else "blob"
  return options.CreateBlob({Bytes=blob.Bytes,Type=blob.Type,Name=name,LastModified=blob.LastModified or math.floor(if options.Now then options.Now()else os.time()*1000)})
 end
 local function append(record,name,value)
  if #record.Entries>=1024 then VM.throw(VM.error("RangeError","FormData entry budget exceeded"))end
  table.insert(record.Entries,{Name=name,Value=value})
 end
 local constructor=native("FormData",0,function()fail("FormData requires new")end)
 constructor.Construct=function(args)
  check();local value=make();local form,submitter=arg(args,1),arg(args,2)
  if form~=U then
   if form==N or type(form)~="table"or form.Kind=="symbol"or form.Kind=="bigint"then fail("FormData requires an HTMLFormElement")end
   if constructing[form]then VM.throw(if options.HostEvents then options.HostEvents:DOMException("The form entry list is already being constructed","InvalidStateError")else VM.error("InvalidStateError","The form entry list is already being constructed"))end
   if not options.FormDataEntries then VM.throw(VM.error("NotSupportedError","FormData(form) requires a successful-controls DOM adapter"))end
   constructing[form]=true
   local ok,failure=pcall(function()
    for _,entry in options.FormDataEntries(form,submitter)do vm.Step();append(records[value],usv(entry.name),fileValue(entry.value,U,false))end
    if options.FormDataConstructed then options.FormDataConstructed(form,value)end
   end)
   constructing[form]=nil;if not ok then error(failure,0)end;check()
   -- The formdata event owns the construction list; the constructor receives a
   -- clone after dispatch. Later edits to event.formData cannot mutate it.
   local result=make();for _,entry in records[value].Entries do append(records[result],entry.Name,entry.Value)end;return result
  end;return value
 end
 def(constructor,"prototype",{value=proto});def(proto,"constructor",{value=constructor,writable=true,configurable=true});def(proto,vm.SymbolToStringTag,{value="FormData",configurable=true});globals.FormData=constructor;vm.Global.Bindings.FormData={Value=constructor}
 method("append",2,function(args,value)required(args,2,"append");local record=state(value);local name=usv(args[1]);local entry=fileValue(args[2],arg(args,3),#args>=3);append(record,name,entry);return U end)
 method("set",2,function(args,value)
  required(args,2,"set");local record=state(value);local name=usv(args[1]);local entry=fileValue(args[2],arg(args,3),#args>=3);local found=false
  for i=#record.Entries,1,-1 do if record.Entries[i].Name==name then if found then table.remove(record.Entries,found)end;record.Entries[i].Value=entry;found=i end end
  if not found then append(record,name,entry)end;return U
 end)
 method("delete",1,function(args,value)required(args,1,"delete");local record=state(value);local name=usv(args[1]);for i=#record.Entries,1,-1 do if record.Entries[i].Name==name then table.remove(record.Entries,i)end end;return U end)
 method("get",1,function(args,value)required(args,1,"get");local record=state(value);local name=usv(args[1]);for _,entry in record.Entries do if entry.Name==name then return entry.Value end end;return N end)
 method("getAll",1,function(args,value)required(args,1,"getAll");local record=state(value);local name=usv(args[1]);local values={};for _,entry in record.Entries do if entry.Name==name then table.insert(values,entry.Value)end end;return vm.Array(values)end)
 method("has",1,function(args,value)required(args,1,"has");local record=state(value);local name=usv(args[1]);for _,entry in record.Entries do if entry.Name==name then return true end end;return false end)
 for _,name in {"keys","values","entries"}do method(name,0,function(_,value)
  local record=state(value);local index=0;local iterator=vm.Object({},vm.Prototypes.Iterator);iterator.Kind="iterator"
  def(iterator,"next",{value=native("next",0,function()
   local entry=record.Entries[index+1];if entry then index+=1 end;return vm.Object({done=entry==nil,value=if not entry then U elseif name=="keys"then entry.Name elseif name=="values"then entry.Value else vm.Array({entry.Name,entry.Value})})
  end),writable=true,configurable=true});return iterator
 end)end
 def(proto,vm.SymbolIterator,{value=vm.Get(proto,"entries"),writable=true,configurable=true})
 method("forEach",1,function(args,value)
  required(args,1,"forEach");local record=state(value);local callback=args[1];if not VM.callable(callback)then fail("FormData callback must be callable")end
  local i=1;while record.Entries[i]do vm.Step();local entry=record.Entries[i];vm:Call(callback,{entry.Value,entry.Name,value},arg(args,2));i+=1;if i>16384 then VM.throw(VM.error("RangeError","FormData iteration budget exceeded"))end end;return U
 end)
 function api:IsFormData(value)return records[value]~=nil end
 function api:SnapshotEntries(value)
  check();local result={};for _,entry in state(value).Entries do vm.Step();table.insert(result,{name=entry.Name,value=entry.Value})end;return result
 end
 if options.HostEvents then
  local eventProto=vm.Object({},vm.Get(globals.Event,"prototype"))
  local function newEvent(typeName,init,data)
   local value=options.HostEvents:NewEvent(typeName,init);vm.SetPrototype(value,eventProto)
   local record={FormData=data};value.FormDataEventState=record;eventRecords[value]=record;return value
  end
  local eventConstructor=native("FormDataEvent",2,function()fail("FormDataEvent requires new")end)
  eventConstructor.Construct=function(args)
   check();required(args,2,"FormDataEvent");local name=options.ToDOMString(args[1]);local init=args[2]
   if init~=U and init~=N and(type(init)~="table"and type(init)~="function"or type(init)=="table"and(init.Kind=="symbol"or init.Kind=="bigint"))then fail("FormDataEvent requires a dictionary")end
   local values={};for _,key in {"bubbles","cancelable","composed","formData"}do local field=if init==U or init==N then U else vm.Get(init,key);values[key]=if key=="formData"then field else VM.truth(field)end
   if not records[values.formData]then fail("FormDataEvent requires FormData")end
   return newEvent(name,values,values.formData)
  end
  def(eventConstructor,"prototype",{value=eventProto});vm.SetPrototype(eventConstructor,globals.Event)
  def(eventProto,"constructor",{value=eventConstructor,writable=true,configurable=true});def(eventProto,vm.SymbolToStringTag,{value="FormDataEvent",configurable=true})
  def(eventProto,"formData",{get=native("get formData",0,function(_,value)local record=eventRecords[value];if not record then fail("Expected FormDataEvent")end;return record.FormData end),enumerable=true,configurable=true})
  globals.FormDataEvent=eventConstructor;vm.Global.Bindings.FormDataEvent={Value=eventConstructor}
  function api:Event(data)check();state(data);return newEvent("formdata",{bubbles=true,cancelable=false},data)end
 end
 local function normalize(value)return(value:gsub("\r\n","\n"):gsub("\r","\n"):gsub("\n","\r\n"))end
 local function quoted(value,isFilename)return((if isFilename then value else normalize(value)):gsub("\r","%%0D"):gsub("\n","%%0A"):gsub('"',"%%22"))end
 function api:Serialize(value)
  check();local chunks={};local size=0
  for _,entry in state(value).Entries do
   vm.Step();local blob=options.DescribeBlob(entry.Value);local disposition='Content-Disposition: form-data; name="'..quoted(entry.Name)..'"'
   if blob then disposition..='; filename="'..quoted(blob.Name,true)..'"\r\nContent-Type: '..(if blob.Type==""then "application/octet-stream"else blob.Type)end
   local chunk=disposition.."\r\n\r\n"..(if blob then blob.Bytes else normalize(entry.Value)).."\r\n";size+=#chunk
   if size>maxBytes then VM.throw(VM.error("RangeError","Multipart body byte budget exceeded"))end;table.insert(chunks,chunk)
  end
  local boundary
  for _=1,8 do
   local parts={"----HTMLEngineBoundary"};for _=1,8 do table.insert(parts,string.format("%04x",math.random(0,65535)))end;local candidate=table.concat(parts);local collision=false
   for _,chunk in chunks do if string.find(chunk,candidate,1,true)then collision=true;break end end
   if not collision then boundary=candidate;break end
  end
  if not boundary then fail("Could not generate a distinct multipart boundary")end
  local out={};for _,chunk in chunks do table.insert(out,"--"..boundary.."\r\n"..chunk)end;table.insert(out,"--"..boundary.."--\r\n")
  local bytes=table.concat(out);if #bytes>maxBytes then VM.throw(VM.error("RangeError","Multipart body byte budget exceeded"))end
  return bytes,"multipart/form-data; boundary="..boundary
 end
 local function parameters(value)
  local out={};local first=value:find(";",1,true);local mime=(if first then value:sub(1,first-1)else value):lower():gsub("^%s+",""):gsub("%s+$","");local at=if first then first+1 else #value+1
  while at<=#value do
   while value:sub(at,at)==";"or value:sub(at,at):match("[ \t]")do at+=1 end
   local equals=value:find("=",at,true);if not equals then break end
   local name=value:sub(at,equals-1):lower():gsub("%s+$","");at=equals+1;local content
   if value:sub(at,at)=='"'then at+=1;local parts={};while at<=#value and value:sub(at,at)~='"'do local c=value:sub(at,at);at+=1;if c=="\\"and at<=#value then c=value:sub(at,at);at+=1 end;table.insert(parts,c)end;if value:sub(at,at)~='"'then fail("Malformed multipart parameter")end;at+=1;content=table.concat(parts)
   else local ending=value:find(";",at,true)or #value+1;content=value:sub(at,ending-1):gsub("%s+$","");at=ending end
   if out[name]==nil then out[name]=content end
  end;return mime,out
 end
 function api:Parse(bytes,contentType)
  check();if #bytes>maxBytes then VM.throw(VM.error("RangeError","FormData body byte budget exceeded"))end
  local mime,params=parameters(contentType);local result=make();local record=records[result]
  if mime=="application/x-www-form-urlencoded"then
   local values=vm:Construct(urlParams,{options.DecodeUTF8(bytes)});local nextValue=vm.Iterator(values)
   while true do local more,pair=nextValue();if not more then break end;vm.Step();append(record,usv(vm.Get(pair,"0")),usv(vm.Get(pair,"1")))end;return result
  end
  if mime~="multipart/form-data"or not params.boundary or params.boundary==""then fail("Body does not have a supported form content type")end
  local boundary=params.boundary;if #boundary>70 or boundary:find("[\r\n]")then fail("Invalid multipart boundary")end
  local delimiter="--"..boundary;local at=bytes:find(delimiter,1,true);if not at then fail("Multipart boundary not found")end
  while true do
   vm.Step();at+=#delimiter
   if bytes:sub(at,at+1)=="--"then return result end
   if bytes:sub(at,at+1)~="\r\n"then fail("Malformed multipart boundary")end;at+=2
   local headerEnd=bytes:find("\r\n\r\n",at,true);if not headerEnd or headerEnd-at>16384 then fail("Malformed multipart headers")end
   local head={};for row in (bytes:sub(at,headerEnd-1).."\r\n"):gmatch("(.-)\r\n")do local colon=row:find(":",1,true);if not colon then fail("Malformed multipart header")end;head[row:sub(1,colon-1):lower()]=row:sub(colon+1):gsub("^[ \t]+",""):gsub("[ \t]+$","")end
   local disposition,fields=parameters(head["content-disposition"]or "");if disposition~="form-data"or not fields.name then fail("Multipart part lacks a form-data name")end
   local ending=bytes:find("\r\n"..delimiter,headerEnd+4,true)
   while ending do local following=bytes:sub(ending+2+#delimiter,ending+3+#delimiter);if following=="--"or following=="\r\n"then break end;ending=bytes:find("\r\n"..delimiter,ending+2,true)end
   if not ending then fail("Unterminated multipart body")end
   local payload=bytes:sub(headerEnd+4,ending-1);local name=options.DecodeUTF8(fields.name);local value
   if fields.filename~=nil then
    local filename=options.DecodeUTF8(fields.filename)
    value=options.CreateBlob({Bytes=payload,Type=(head["content-type"]or "text/plain"):lower(),Name=filename,LastModified=math.floor(if options.Now then options.Now()else os.time()*1000)})
   else value=options.DecodeUTF8(payload)end
   append(record,name,value);at=ending+2
  end
 end
 function api:Destroy()self.Alive=false;for _,record in records do table.clear(record.Entries)end;table.clear(records);table.clear(constructing);table.clear(eventRecords)end
 return api
end
return FormData
