--!strict
-- Realm-independent graph records, then target-realm reconstruction. Transfer
-- validation finishes before any buffer/port is detached.
local StructuredClone={}
function StructuredClone.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true,VM=vm};local binary=options.Binary
 local intrinsics={};for _,name in {"Map","Set","Date","String","Number","Boolean","Error","TypeError","RangeError","ReferenceError","SyntaxError","EvalError","URIError","AggregateError"}do local binding=vm.Global.Bindings[name];intrinsics[name]=binding and binding.Value end
 -- Reconstruction operates on collection data, never author-replaced adders
 -- or prototype accessors. Keep the realm's original internal operations.
 intrinsics.MapSet=vm.Get(vm.Prototypes.Map,'set');intrinsics.SetAdd=vm.Get(vm.Prototypes.Set,'add')
 local function check()assert(api.Alive and vm.Alive,"JavaScript structured clone disposed")end
 local function fail(message)VM.throw(options.HostEvents:DOMException(message,"DataCloneError"))end
 local function kind(value)return type(value)=="table"and value.Kind end
 local function transferValues(transfer)
  local list={};if transfer==nil or transfer==U then return list end
  local iterator,close=vm.Iterator(transfer);local ok,message=pcall(function()while true do local more,value=iterator();if not more then break end;if #list>=1024 then fail("Transfer list budget exceeded")end;table.insert(list,value)end end)
  if not ok then if close then pcall(close)end;error(message,0)end;return list
 end
 function api:Serialize(value,transfer,byteBudget)
  check();local records,memory,transfers,plans={},{},{},{};local bytesTotal=0
  local byteLimit=math.min(options.MaxBytes or 1048576,byteBudget or math.huge)
  local function charge(count)bytesTotal+=count;if bytesTotal>byteLimit then fail("Structured clone byte budget exceeded")end end
  local function bound(bytes)charge(#bytes);return bytes end
  local function allocate(source,record)if #records>=4096 then fail("Structured clone object budget exceeded")end;charge(64);table.insert(records,record);local id=#records;memory[source]=id;return {Ref=id}end
  local transferSet={}
  for _,item in transferValues(transfer)do
   vm.Step();if transferSet[item]then fail("Transfer list contains a duplicate")end;transferSet[item]=true
   local description=binary and binary:Describe(item)
   if description and description.Kind=="ArrayBuffer"then
    if description.Detached then fail("Detached ArrayBuffer cannot be transferred")end
    local ref=allocate(item,{Kind="ArrayBuffer"});local plan={Kind="ArrayBuffer",Source=item,ID=ref.Ref};table.insert(plans,plan);table.insert(transfers,{Kind="ArrayBuffer",Ref=ref.Ref})
   elseif api.TransferHost and api.TransferHost:IsPort(item)then
    local plan=api.TransferHost:PrepareTransfer(item);plan.Kind="MessagePort";local ref=allocate(item,{Kind="MessagePort",Token=plan.Token});table.insert(plans,plan);table.insert(transfers,{Kind="MessagePort",Ref=ref.Ref})
   else fail("Transfer list contains a non-transferable object")end
  end
  local visit
  visit=function(source,depth)
   vm.Step();if depth>256 then fail("Structured clone nesting budget exceeded")end
   if source==U or source==nil then charge(8);return {Primitive="undefined"}elseif source==N then charge(8);return {Primitive="null"}end
   local t=type(source)
   if t=="string"then charge(16);return {Primitive="value",Value=bound(source)}elseif t=="number"or t=="boolean"then charge(16);return {Primitive="value",Value=source}end
   if kind(source)=="bigint"then charge(16);return {Primitive="bigint",Value=bound(vm.BigInt:ToString(source,10))}end
   if VM.callable(source)or kind(source)=="symbol"or t~="table"then fail("Value is not structured-cloneable")end
   if memory[source]then charge(8);return {Ref=memory[source]}end
   local geometry=api.Geometry and api.Geometry:Describe(source)
   if geometry then
    charge(geometry.ByteLength or 0);geometry.ByteLength=nil
    local record={Kind='Geometry',Data=geometry};local ref=allocate(source,record)
    if geometry.Kind=='DOMQuad'then
     local points={};for i,p in geometry.Data do points[i]=visit(p,depth+1)end;geometry.Data=points
    end
    return ref
   end
   local description=binary and binary:Describe(source)
   if description then
    if description.Detached then fail("Detached binary data cannot be cloned")end
    if description.Kind=="ArrayBuffer"then return allocate(source,{Kind="ArrayBuffer",Bytes=bound(binary:ReadBytes(source))})end
    local record={Kind="BinaryView",ViewKind=description.Kind,Offset=description.ByteOffset,Length=description.Length};local ref=allocate(source,record);record.Buffer=visit(description.Buffer,depth+1);return ref
   end
   if api.TransferHost and api.TransferHost:IsPort(source)then fail("MessagePort must be listed in transfer")end
   local domException=options.HostEvents:DescribeDOMException(source)
   if domException then return allocate(source,{Kind="DOMException",Name=domException.Name,Message=bound(domException.Message)})end
   local blob=options.NetworkData and options.NetworkData:DescribeBlob(source)
   if blob then blob.Bytes=bound(blob.Bytes);return allocate(source,{Kind="Blob",Data=blob})end
   local files=options.NetworkData and options.NetworkData.Files
   if files and files:IsFileList(source)then
    local record={Kind="FileList",Files={}};local ref=allocate(source,record)
    for _,file in files:FileListValues(source)do table.insert(record.Files,visit(file,depth+1))end;return ref
   end
   if rawget(source,'RangeBrand')or rawget(source,'SelectionState')then fail('DOM ranges and selections are not structured-cloneable')end
   if rawget(source,'CSSOMBrand')then fail('CSSOM objects are not structured-cloneable')end
   if rawget(source,'CanvasPathState') then fail('Path2D objects are not structured-cloneable')end
   if rawget(source,'IntlLocaleState') or rawget(source,'IntlNumberFormatState') or rawget(source,'IntlListFormatState') then fail('Intl objects are not structured-cloneable')end
   local name=kind(source)
   local regex=vm.RegExp and vm.RegExp:Describe(source)
   if regex then return allocate(source,{Kind="RegExp",Source=bound(regex.Source),Flags=regex.Flags})end
   if name=="date"then return allocate(source,{Kind="Date",Value=source.TimeValue})end
   if name=="map"or name=="set"then
    local record={Kind=if name=="map"then "Map"else "Set",Entries={}};local ref=allocate(source,record)
    local snapshot={};for _,entry in source.Entries do if entry.Active then table.insert(snapshot,{Key=entry.Key,Value=entry.Value})end end
    for _,entry in snapshot do charge(if name=="map"then 16 else 8);table.insert(record.Entries,if name=="map"then{visit(entry.Key,depth+1),visit(entry.Value,depth+1)}else visit(entry.Value,depth+1))end;return ref
   end
   if name=="boxed-string"or name=="boxed-number"or name=="boxed-boolean"then return allocate(source,{Kind="Box",Type=if name=="boxed-string"then "String"elseif name=="boxed-number"then "Number"else "Boolean",Value=if name=="boxed-string"then bound(source.PrimitiveValue)else source.PrimitiveValue})end
   if name=="error"then
    local errorName=vm.Get(source,"name");if type(errorName)~="string"or not({Error=true,TypeError=true,RangeError=true,ReferenceError=true,SyntaxError=true,EvalError=true,URIError=true,AggregateError=true})[errorName]then errorName="Error"end
    local messageDescriptor=vm.ObjectModel.Own(source,'message')
    local record={Kind="Error",Name=errorName,Message=if messageDescriptor and not messageDescriptor.Accessor then bound(VM.string(messageDescriptor.Value))else nil};local ref=allocate(source,record)
    if vm.HasOwn(source,"cause")then record.Cause=visit(vm.Get(source,"cause"),depth+1)end
    -- The VM has no native stack accessor to invoke. Preserve an explicitly
    -- supplied data string without running an author stack getter.
    local stackDescriptor=vm.ObjectModel.Own(source,'stack')
    if stackDescriptor and not stackDescriptor.Accessor and type(stackDescriptor.Value)=='string'then record.Stack=bound(stackDescriptor.Value)end
    if errorName=="AggregateError"and vm.HasOwn(source,"errors")then record.Errors=visit(vm.Get(source,"errors"),depth+1)end;return ref
   end
   if source.DOMNode or source.HostState or source.NetworkState or source.StreamState or source.ReaderState or source.MessageState or source.PromiseBrand or source.GeometryState or source.MathGeometryState or source.IteratorHelperState or source.TraversalState or source.RawJSONBrand then fail("This platform object is not serializable")end
   if name~="object"and name~="array"then fail("Unsupported structured clone object type")end
   local record={Kind=if name=="array"then "Array"else "Object",Length=if name=="array"then source.Length else nil,Properties={}};local ref=allocate(source,record)
   for _,key in vm.OwnKeys(source,true)do if type(key)=="string"and vm.HasOwn(source,key)then charge(16);table.insert(record.Properties,{bound(key),visit(vm.Get(source,key),depth+1)})end end
   return ref
  end
  local root=visit(value,0)
  -- Read transfer bytes after getters have run, then validate every transfer
  -- again before committing. A failed clone leaves unrelated buffers attached.
  for _,plan in plans do
   if plan.Kind=="ArrayBuffer"then local description=binary:Describe(plan.Source);if not description or description.Detached then fail("Transfer source was detached while serializing")end;records[plan.ID].Bytes=bound(binary:ReadBytes(plan.Source))
   else plan.Validate()end
  end
  for _,plan in plans do if plan.Kind=="ArrayBuffer"then binary:Detach(plan.Source)else plan.Commit()end end
  return {Root=root,Records=records,Transfers=transfers,ByteLength=bytesTotal}
 end
 function api:Deserialize(wire)
  check();local memory={};local restore
  restore=function(value,depth)
   vm.Step();if depth>256 then fail("Structured clone nesting budget exceeded")end
   if value.Primitive then return if value.Primitive=="undefined"then U elseif value.Primitive=="null"then N elseif value.Primitive=="bigint"then vm.BigInt:Parse(value.Value)else value.Value end
   local id=value.Ref;if memory[id]then return memory[id]end;local record=wire.Records[id];if not record then fail("Malformed clone reference")end
   local result
   if record.Kind=='Geometry'then
    if not api.Geometry then fail('Target realm does not support geometry objects')end
    local geometry=record.Data
    if geometry.Kind=='DOMQuad'then local points={};for i,p in geometry.Data do points[i]=restore(p,depth+1)end;geometry={Kind='DOMQuad',Data=points}end
    result=api.Geometry:Restore(geometry);if not result then fail('Unsupported geometry clone record')end
   elseif record.Kind=="ArrayBuffer"then if not binary then fail("Target realm does not support binary data")end;result=binary:Buffer(record.Bytes)
   elseif record.Kind=="BinaryView"then result=binary:CreateView(record.ViewKind,restore(record.Buffer,depth+1),record.Offset,record.Length)
   elseif record.Kind=="MessagePort"then if not api.TransferHost then fail("Target realm cannot receive MessagePorts")end;result=api.TransferHost:ReceiveTransfer(record.Token)
   elseif record.Kind=="DOMException"then result=options.HostEvents:DOMException(record.Message,record.Name)
   elseif record.Kind=="Blob"then if not options.NetworkData then fail("Target realm cannot receive Blob/File")end;result=options.NetworkData:CreateBlob(record.Data)
   elseif record.Kind=="FileList"then
    local files=options.NetworkData and options.NetworkData.Files;if not files then fail("Target realm cannot receive FileList")end
    result=files:CreateFileList({});memory[id]=result;local values={};for _,file in record.Files do table.insert(values,restore(file,depth+1))end;files:UpdateFileList(result,values)
   elseif record.Kind=="Date"then result=vm:Construct(intrinsics.Date,{record.Value})
   elseif record.Kind=="RegExp"then if not vm.RegExp then fail("Target realm does not support RegExp")end;result=vm.RegExp:Create(record.Source,record.Flags)
   elseif record.Kind=="Box"then result=vm:Construct(intrinsics[record.Type],{record.Value})
   elseif record.Kind=="Map"or record.Kind=="Set"then
    result=vm:Construct(intrinsics[record.Kind],{});memory[id]=result
    local method=if record.Kind=="Map"then intrinsics.MapSet else intrinsics.SetAdd
    for _,entry in record.Entries do vm:Call(method,if record.Kind=="Map"then{restore(entry[1],depth+1),restore(entry[2],depth+1)}else{restore(entry,depth+1)},result)end
   elseif record.Kind=="Error"then
    local args=if record.Name=="AggregateError"then{vm.Array({}),record.Message}else{record.Message};result=vm:Construct(intrinsics[record.Name]or intrinsics.Error,args);memory[id]=result
    for key,ref in {cause=record.Cause,errors=record.Errors}do if ref then vm.DefineProperty(result,key,vm.Object({value=restore(ref,depth+1),writable=true,configurable=true},VM.Null))end end
    if record.Stack then vm.DefineProperty(result,"stack",vm.Object({value=record.Stack,writable=true,configurable=true},VM.Null))end
   elseif record.Kind=="Array"or record.Kind=="Object"then
    result=if record.Kind=="Array"then vm.Array({})else vm.Object({});if record.Kind=="Array"then result.Length=record.Length end;memory[id]=result
    for _,pair in record.Properties do vm.DefineProperty(result,pair[1],vm.Object({value=restore(pair[2],depth+1),writable=true,enumerable=true,configurable=true},VM.Null))end
   else fail("Unsupported clone record")end
   memory[id]=result;return result
  end
  local result=restore(wire.Root,0);local ports={}
  for _,transfer in wire.Transfers or {}do if transfer.Kind=="MessagePort"then table.insert(ports,restore({Ref=transfer.Ref},0))end end
  return result,ports
 end
 function api:Clone(value,transfer,destination)return(destination or self):Deserialize(self:Serialize(value,transfer))end
 function api:Discard(wire)
  if not self.TransferHost then return end
  for _,record in wire.Records do if record.Kind=="MessagePort"then self.TransferHost:DiscardTransfer(record.Token)end end
 end
 local fn={Kind="native-function",Values={name="structuredClone",length=1},Prototype=vm.Prototypes.Function,Call=function(args)
  check();if #args<1 then VM.throw(VM.error("TypeError","structuredClone requires an argument"))end
  local transfer=if args[2]==nil or args[2]==U or args[2]==N then U else vm.Get(args[2],"transfer")
  return api:Clone(args[1],transfer)
 end}
 globals.structuredClone=fn;vm.Global.Bindings.structuredClone={Value=fn}
 function api:Destroy()self.Alive=false;self.TransferHost=nil;self.Geometry=nil;table.clear(intrinsics)end
 return api
end
return StructuredClone
