--!strict
-- Bounded Number-based binary views. No shared memory or background work.
local BinaryData={}
-- Brands belong to the agent, not to the global constructor exposed in one
-- realm. Local registries still delimit disposal; these weak lookups allow
-- borrowed methods and views over a live foreign realm's backing buffer.
local sharedBuffers,sharedViews=setmetatable({},{__mode='kv'}),setmetatable({},{__mode='kv'})
local KINDS={Int8Array={1,"i8"},Uint8Array={1,"u8"},Uint8ClampedArray={1,"clamped"},Int16Array={2,"i16"},Uint16Array={2,"u16"},Int32Array={4,"i32"},Uint32Array={4,"u32"},Float32Array={4,"f32"},Float64Array={8,"f64"}}
function BinaryData.install(vm: any,globals: any,options: any?): any
 options=options or {};local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true};local limit=options.MaxBytes or 1048576
 local buffers,views=setmetatable({},{__mode="kv",__index=sharedBuffers}),setmetatable({},{__mode="kv",__index=sharedViews});local prototypes,constructors={},{}
 local function check()assert(api.Alive and vm.Alive,"JavaScript binary data disposed")end
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function int(value,default)local n=if value==U then default or 0 else VM.number(value);return if n~=n or n==0 then 0 elseif n<0 then math.ceil(n)else math.floor(n)end
 local function index(value)local n=int(value);if n<0 or n>limit then fail("RangeError","Binary offset or size is out of range")end;return n end
 local function def(target,key,desc)
  local internal={};for name,value in desc do internal[name:sub(1,1):upper()..name:sub(2)]=value end
  assert(vm.ObjectModel.DefineOwn(target,key,internal),'Cannot define internal binary property');return target
 end
 local function native(name,n,fn)local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,VMOwner=vm,Call=function(args,receiver)check();return fn(args,receiver)end};def(value,"length",{value=n,configurable=true});def(value,"name",{value=name,configurable=true});return value end
 local function method(proto,name,n,fn)def(proto,name,{value=native(name,n,fn),writable=true,configurable=true})end
 local function accessor(proto,name,fn)def(proto,name,{get=native("get "..name,0,function(_,receiver)return fn(receiver)end),configurable=true})end
 local function ctor(name,n,proto,fn)
  vm.Prototypes[name]=proto
  local value=native(name,n,function()fail("TypeError",name.." requires new")end)
  value.Construct=function(args,newTarget)
   check();local prototype=proto
   local function resolvePrototype()
    if newTarget and newTarget~=value then
     prototype=vm.Get(newTarget,'prototype')
     if not vm.ObjectModel.IsObject(prototype)then prototype=vm.FunctionRealm(newTarget).Prototypes[name]or proto end
    end
   end
   -- Chromium 154/V8 reads arraylike length or consumes a generic iterator
   -- before newTarget.prototype, while buffer/primitive inputs read it first.
   -- Keep that observed profile distinct from the current ECMA algorithm.
   local typed=name~='ArrayBuffer'and name~='DataView'
   local result=fn(args,if typed then resolvePrototype else nil)
   if not typed then resolvePrototype()end
   result.Prototype=prototype;if result.Kind=='typed-array'then views[result].Backing.Prototype=prototype end
   return result
  end
  def(value,"prototype",{value=proto});def(proto,"constructor",{value=value,writable=true,configurable=true});globals[name]=value;vm.Global.Bindings[name]={Value=value};constructors[name]=value;return value
 end
 local function brand(map,value,name,allowDetached)check();local state=map[value];if not state or(map==views and name:sub(1,10)=="TypedArray"and state.Kind=="DataView")then fail("TypeError",name.." requires a compatible receiver")end;if not allowDetached and(state.Detached or(map==views and buffers[state.Buffer].Detached))then fail("TypeError","ArrayBuffer is detached")end;return state end
 local bufferProto=vm.Object({});prototypes.ArrayBuffer=bufferProto
 local function makeBuffer(size,bytes)
  if size>limit then fail("RangeError","JavaScript binary byte budget exceeded")end
  local value=vm.Object({},bufferProto);local state={Data=buffer.create(size),Length=size};value.BinaryState=state;buffers[value]=state;sharedBuffers[value]=state
  if bytes and #bytes>0 then buffer.writestring(state.Data,0,bytes)end;return value
 end
 local function relative(value,length,default)local n=int(value,default);return if n<0 then math.max(0,length+n)else math.min(length,n)end
 local function canonical(key)
  if type(key)~="string"then return nil,false end
  if key=="-0"then return -1,true end
  local n=tonumber(key);if n and VM.string(n)==key then return n,true end
  if key=="NaN"or key=="Infinity"or key=="-Infinity"then return -1,true end
  return nil,false
 end
 local function read(state,i)
  if buffers[state.Buffer].Detached then return U end;local data=buffers[state.Buffer].Data;local at=state.Offset+i*state.Size;local format=state.Format
  if format=="clamped"then format="u8"end
  return buffer["read"..format](data,at)
 end
 local function write(state,i,value)
  local n=VM.number(value);local format=state.Format
  if format=="clamped"then
   if n~=n or n<=0 then n=0 elseif n>=255 then n=255 else local floor=math.floor(n);local fraction=n-floor;n=if fraction>0.5 or(fraction==0.5 and floor%2==1)then floor+1 else floor end;format="u8"
  elseif format~="f32"and format~="f64"then
   n=if n~=n or math.abs(n)==math.huge then 0 else(if n<0 then math.ceil(n)else math.floor(n));local modulus=2^(state.Size*8);n%=modulus
   if format:sub(1,1)=="i"and n>=modulus/2 then n-=modulus end
  end
  buffer["write"..format](buffers[state.Buffer].Data,state.Offset+i*state.Size,n)
 end
 -- Only canonical numeric strings use the integer-indexed protocol. All
 -- other keys share ordinary descriptors, including inherited accessors and
 -- their actual receiver; the backing object is never exposed to author code.
 local model=vm.ObjectModel;local typedHandlers={OrdinaryGetPrototype=true}
 local function typedState(value)check();local state=views[value];assert(state and state.Kind~="DataView","Missing typed array state");return state end
 local function valid(state,at)return not buffers[state.Buffer].Detached and at~=nil and at>=0 and at==math.floor(at)and at<state.Length end
 function typedHandlers.Own(value,key)
  local state=typedState(value);local at,numeric=canonical(key)
  if numeric then return if valid(state,at)then {Value=read(state,at),Writable=true,Enumerable=true,Configurable=true}else nil end
  return model.Own(state.Backing,key)
 end
 function typedHandlers.Get(value,key,receiver)
  local state=typedState(value);local at,numeric=canonical(key)
  if numeric then return if valid(state,at)then read(state,at)else U end
  return model.Get(state.Backing,key,receiver)
 end
 function typedHandlers.Has(value,key)
  local state=typedState(value);local at,numeric=canonical(key)
  return if numeric then valid(state,at)else model.Has(state.Backing,key)
 end
 function typedHandlers.Define(value,key,descriptor)
  local state=typedState(value);local at,numeric=canonical(key)
  if not numeric then return model.DefineOwn(state.Backing,key,descriptor)end
  if not valid(state,at)or descriptor.Accessor or descriptor.Get~=nil or descriptor.Set~=nil or descriptor.Configurable==false or descriptor.Enumerable==false or descriptor.Writable==false then return false end
  if descriptor.Value~=nil then local n=VM.number(descriptor.Value);if valid(state,at)then write(state,at,n)end end
  return true
 end
 function typedHandlers.Set(value,key,item,receiver)
  local state=typedState(value);local at,numeric=canonical(key)
  if not numeric then return model.Set(state.Backing,key,item,false,receiver)end
  if receiver==value then local n=VM.number(item);if valid(state,at)then write(state,at,n)end;return true end
  if not valid(state,at)then return true end
  -- OrdinarySetWithOwnDescriptor, with the writable integer-index descriptor:
  -- writes to another receiver neither mutate nor coerce through this view.
  if not model.IsObject(receiver)then return false end
  local old=model.Own(receiver,key)
  if old then if old.Accessor or not old.Writable then return false end;return model.DefineOwn(receiver,key,{Value=item})end
  return model.DefineOwn(receiver,key,{Value=item,Writable=true,Enumerable=true,Configurable=true})
 end
 function typedHandlers.Delete(value,key)
  local state=typedState(value);local at,numeric=canonical(key)
  return if numeric then not valid(state,at)else model.Delete(state.Backing,key,false)
 end
 function typedHandlers.OwnKeys(value)
  local state=typedState(value);local length=if buffers[state.Buffer].Detached then 0 else state.Length
  if length>16384 then fail("RangeError","TypedArray property enumeration budget exceeded")end
  local keys={};for i=0,length-1 do vm.Step();table.insert(keys,tostring(i))end
  for _,key in model.OwnKeys(state.Backing,false)do vm.Step();if #keys>=16384 then fail("RangeError","TypedArray property enumeration budget exceeded")end;table.insert(keys,key)end
  return keys
 end
 function typedHandlers.GetPrototype(value)return model.GetPrototype(typedState(value).Backing)end
 function typedHandlers.SetPrototype(value,prototype)
  local state=typedState(value);if model.GetPrototype(state.Backing)==prototype then return true end
  if not model.IsExtensible(state.Backing)then return false end
  local cursor,seen=prototype,{}
  while cursor~=N and cursor~=nil do
   vm.Step();if cursor==value or seen[cursor]then return false end;seen[cursor]=true
   -- TypedArray [[GetPrototypeOf]] is ordinary; proxy-like exotic hooks stop
   -- this walk as OrdinarySetPrototypeOf requires, without invoking a trap.
   local handler=model.ExoticFor(cursor);if handler and not handler.OrdinaryGetPrototype then break end
   cursor=model.GetPrototype(cursor)
  end
  if not model.SetPrototypeInternal(state.Backing,prototype)then return false end;value.Prototype=prototype;return true
 end
 function typedHandlers.IsExtensible(value)return model.IsExtensible(typedState(value).Backing)end
 function typedHandlers.PreventExtensions(value)return model.PreventExtensionsInternal(typedState(value).Backing)end
 local function makeView(kind,source,offset,length)
  local spec=KINDS[kind];local state={Kind=kind,Buffer=source,Offset=offset,Length=length,Size=spec[1],Format=spec[2],Backing=vm.Object({},prototypes[kind])}
  local value={Kind="typed-array",Prototype=prototypes[kind],BinaryState=state,VMOwner=vm};views[value]=state;sharedViews[value]=state;model.Exotic[value]=typedHandlers;return value
 end
 local function arraylikeLength(source)
  local count=math.max(0,int(vm.Get(source,'length')))
  if count>16384 then fail('RangeError','TypedArray input budget exceeded')end;return count
 end
 local function sequence(source,fn,knownMethod)
  local iterator=if knownMethod~=nil then knownMethod else vm.Get(source,vm.SymbolIterator)
  if iterator~=U and iterator~=N and not VM.callable(iterator)then fail('TypeError','TypedArray input iterator is not callable')end
  if VM.callable(iterator)then local nextValue,close=vm.Iterator(source,false,iterator);local ok,result=pcall(function()local i=0;while true do local more,value=nextValue();if not more then break end;if i>=16384 then fail("RangeError","TypedArray input budget exceeded")end;fn(i,value);i+=1 end;return i end);if not ok then if close then pcall(close)end;error(result,0)end;return result end
  local count=arraylikeLength(source);for i=0,count-1 do vm.Step();fn(i,vm.Get(source,tostring(i)))end;return count
 end
 local function constructView(kind,args,resolvePrototype)
  -- Internal static/callback methods create an ordinary view and have no
  -- newTarget prototype lookup. Constructors supply the observable callback.
  resolvePrototype=resolvePrototype or function()end
  local size=KINDS[kind][1];local source=arg(args,1)
  if buffers[source]then resolvePrototype();brand(buffers,source,"TypedArray buffer");local offset=index(arg(args,2));local available=buffers[source].Length-offset;if offset%size~=0 or available<0 then fail("RangeError","TypedArray offset is out of range or unaligned")end
   local length=if arg(args,3)==U then available/size else index(args[3]);if length~=math.floor(length)or length*size>available then fail("RangeError","TypedArray length is out of range or unaligned")end;return makeView(kind,source,offset,length)
  elseif views[source]and views[source].Kind~='DataView'then
   resolvePrototype();local state=brand(views,source,'TypedArray constructor');local count=state.Length
   local result=makeView(kind,makeBuffer(count*size),0,count);for i=0,count-1 do vm.Step();write(views[result],i,read(state,i))end;return result
  elseif type(source)=="table"and source~=U and source~=N and source.Kind~="symbol"and source.Kind~="bigint"then
   local iterator=vm.Get(source,vm.SymbolIterator)
   if iterator~=U and iterator~=N and not VM.callable(iterator)then fail('TypeError','TypedArray input iterator is not callable')end
   if VM.callable(iterator)then
    local items={};local count=sequence(source,function(i,item)items[i+1]=item end,iterator);resolvePrototype()
    local result=makeView(kind,makeBuffer(count*size),0,count);for i,item in items do write(views[result],i-1,item)end;return result
   end
   local count=arraylikeLength(source);resolvePrototype();local result=makeView(kind,makeBuffer(count*size),0,count)
   for i=0,count-1 do vm.Step();write(views[result],i,vm.Get(source,tostring(i)))end;return result
  else resolvePrototype();local length=index(source);return makeView(kind,makeBuffer(length*size),0,length)end
 end
 accessor(bufferProto,"byteLength",function(value)return brand(buffers,value,"ArrayBuffer.byteLength",true).Length end)
 accessor(bufferProto,"maxByteLength",function(value)return brand(buffers,value,"ArrayBuffer.maxByteLength",true).Length end)
 accessor(bufferProto,"resizable",function(value)brand(buffers,value,"ArrayBuffer.resizable",true);return false end)
 method(bufferProto,"slice",2,function(args,value)local state=brand(buffers,value,"ArrayBuffer.slice");local first=relative(arg(args,1),state.Length,0);local last=relative(arg(args,2),state.Length,state.Length);local size=math.max(0,last-first);return makeBuffer(size,buffer.readstring(state.Data,first,size))end)
 local bufferCtor=ctor("ArrayBuffer",1,bufferProto,function(args)local size=index(arg(args,1));if arg(args,2)~=U and arg(args,2)~=N and vm.Get(args[2],"maxByteLength")~=U then fail("TypeError","Resizable ArrayBuffer is not implemented")end;return makeBuffer(size)end)
 method(bufferCtor,"isView",1,function(args)return views[arg(args,1)]~=nil end)
 local typedProto=vm.Object({});prototypes.TypedArray=typedProto
 accessor(typedProto,"length",function(value)local state=brand(views,value,"TypedArray.length",true);return if buffers[state.Buffer].Detached then 0 else state.Length end)
 accessor(typedProto,"byteLength",function(value)local state=brand(views,value,"TypedArray.byteLength",true);return if buffers[state.Buffer].Detached then 0 else state.Length*state.Size end)
 accessor(typedProto,"byteOffset",function(value)local state=brand(views,value,"TypedArray.byteOffset",true);return if buffers[state.Buffer].Detached then 0 else state.Offset end)
 accessor(typedProto,"buffer",function(value)return brand(views,value,"TypedArray.buffer",true).Buffer end)
 method(typedProto,"at",1,function(args,value)local state=brand(views,value,"TypedArray.at");local i=int(arg(args,1));if i<0 then i+=state.Length end;return if i>=0 and i<state.Length then read(state,i)else U end)
 method(typedProto,"set",1,function(args,value)local state=brand(views,value,"TypedArray.set");local offset=index(arg(args,2));local items={};local count=sequence(arg(args,1),function(i,item)items[i+1]=VM.number(item)end);if offset+count>state.Length then fail("RangeError","TypedArray source does not fit")end;for i,item in items do write(state,offset+i-1,item)end;return U end)
 for _,name in {"slice","subarray"}do method(typedProto,name,2,function(args,value)local state=brand(views,value,"TypedArray."..name);local first=relative(arg(args,1),state.Length,0);local last=relative(arg(args,2),state.Length,state.Length);local count=math.max(0,last-first)
  if name=="subarray"then return makeView(state.Kind,state.Buffer,state.Offset+first*state.Size,count)end
  return makeView(state.Kind,makeBuffer(count*state.Size,buffer.readstring(buffers[state.Buffer].Data,state.Offset+first*state.Size,count*state.Size)),0,count)
 end)end
 method(typedProto,"fill",1,function(args,value)local state=brand(views,value,"TypedArray.fill");local item=VM.number(arg(args,1));local first=relative(arg(args,2),state.Length,0);local last=relative(arg(args,3),state.Length,state.Length);for i=first,last-1 do vm.Step();write(state,i,item)end;return value end)
 method(typedProto,"copyWithin",2,function(args,value)local state=brand(views,value,"TypedArray.copyWithin");local target=relative(arg(args,1),state.Length,0);local first=relative(arg(args,2),state.Length,0);local last=relative(arg(args,3),state.Length,state.Length);local count=math.max(0,math.min(last-first,state.Length-target));local data=buffers[state.Buffer].Data;buffer.copy(data,state.Offset+target*state.Size,data,state.Offset+first*state.Size,count*state.Size);return value end)
 method(typedProto,"reverse",0,function(_,value)local state=brand(views,value,"TypedArray.reverse");for i=0,math.floor(state.Length/2)-1 do vm.Step();local last=state.Length-1-i;local first=read(state,i);write(state,i,read(state,last));write(state,last,first)end;return value end)
 method(typedProto,"join",1,function(args,value)local state=brand(views,value,"TypedArray.join");local sep=if arg(args,1)==U then ","else VM.string(args[1]);local out={};for i=0,state.Length-1 do vm.Step();out[i+1]=VM.string(read(state,i))end;return table.concat(out,sep)end)
 method(typedProto,"toString",0,function(_,value)return vm:Call(vm.Get(typedProto,"join"),{},value)end)
 for _,name in {"includes","indexOf","lastIndexOf"}do method(typedProto,name,1,function(args,value)local state=brand(views,value,"TypedArray."..name);local sought=arg(args,1);local first=int(arg(args,2),if name=="lastIndexOf"then state.Length-1 else 0);if first<0 then first+=state.Length end
  local start,finish,delta=math.max(0,first),state.Length-1,1;if name=="lastIndexOf"then start,finish,delta=math.min(first,state.Length-1),0,-1 end
  for i=start,finish,delta do vm.Step();local item=read(state,i);if item==sought or(name=="includes"and item~=item and sought~=sought)then return if name=="includes"then true else i end end;return if name=="includes"then false else -1
 end)end
 for _,name in {"values","keys","entries"}do method(typedProto,name,0,function(_,value)local state=brand(views,value,"TypedArray."..name);local i=0;local iterator=vm.Object({},vm.Prototypes.Iterator);local done=false;method(iterator,"next",0,function()if done then return vm.Object({done=true,value=U})end;brand(views,value,"TypedArray iterator");if i>=state.Length then done=true;return vm.Object({done=true,value=U})end;local at=i;i+=1;return vm.Object({done=false,value=if name=="keys"then at elseif name=="entries"then vm.Array({at,read(state,at)})else read(state,at)})end);return iterator end)end
 def(typedProto,vm.SymbolIterator,{value=vm.Get(typedProto,"values"),writable=true,configurable=true})
 for _,name in {"forEach","map","filter","every","some","find","findIndex"}do method(typedProto,name,1,function(args,value)local state=brand(views,value,"TypedArray."..name);local fn=arg(args,1);if not VM.callable(fn)then fail("TypeError","Callback is not callable")end;local selected={}
  for i=0,state.Length-1 do vm.Step();local item=read(state,i);local result=vm:Call(fn,{item,i,value},arg(args,2));local yes=VM.truth(result)
   if name=="map"then selected[i+1]=result elseif name=="filter"and yes then table.insert(selected,item)elseif name=="every"and not yes then return false elseif name=="some"and yes then return true elseif name=="find"and yes then return item elseif name=="findIndex"and yes then return i end
  end
  if name=="map"or name=="filter"then return constructView(state.Kind,{vm.Array(selected)})elseif name=="every"then return true elseif name=="some"then return false elseif name=="findIndex"then return -1 end;return U
 end)end
 for kind,spec in KINDS do
  local proto=vm.Object({},typedProto);prototypes[kind]=proto;def(proto,"BYTES_PER_ELEMENT",{value=spec[1]});def(proto,vm.SymbolToStringTag,{value=kind,configurable=true})
  local value=ctor(kind,3,proto,function(args,resolvePrototype)return constructView(kind,args,resolvePrototype)end);def(value,"BYTES_PER_ELEMENT",{value=spec[1]})
  method(value,"of",0,function(args)return constructView(kind,{vm.Array(args)})end)
  method(value,"from",1,function(args)local items={};local mapper=arg(args,2);if mapper~=U and not VM.callable(mapper)then fail("TypeError","TypedArray.from mapper must be callable")end;sequence(arg(args,1),function(i,item)items[i+1]=if mapper~=U then vm:Call(mapper,{item,i},arg(args,3))else item end);return constructView(kind,{vm.Array(items)})end)
 end
 local dataProto=vm.Object({});prototypes.DataView=dataProto
 ctor("DataView",1,dataProto,function(args)local source=arg(args,1);local state=brand(buffers,source,"DataView buffer");local offset=index(arg(args,2));local length=if arg(args,3)==U then state.Length-offset else index(args[3]);if offset+length>state.Length or length<0 then fail("RangeError","DataView range is invalid")end;local value=vm.Object({},dataProto);local view={Kind="DataView",Buffer=source,Offset=offset,Length=length,Size=1};value.BinaryState=view;views[value]=view;sharedViews[value]=view;return value end)
 for _,name in {"buffer","byteOffset","byteLength"}do accessor(dataProto,name,function(value)local state=brand(views,value,"DataView."..name,name=="buffer");if state.Kind~="DataView"then fail("TypeError","Expected DataView")end;return if name=="buffer"then state.Buffer elseif name=="byteOffset"then state.Offset else state.Length end)end
 for name,spec in {Int8={1,"i8"},Uint8={1,"u8"},Int16={2,"i16"},Uint16={2,"u16"},Int32={4,"i32"},Uint32={4,"u32"},Float32={4,"f32"},Float64={8,"f64"}}do
  for _,action in {"get","set"}do method(dataProto,action..name,if action=="get"then 1 else 2,function(args,value)local state=brand(views,value,"DataView."..action..name);if state.Kind~="DataView"then fail("TypeError","Expected DataView")end;local offset=index(arg(args,1));local number=if action=="set"then VM.number(arg(args,2))else 0;local little=VM.truth(arg(args,if action=="get"then 2 else 3));if offset+spec[1]>state.Length then fail("RangeError","DataView access is out of range")end
   local data=buffers[state.Buffer].Data;local at=state.Offset+offset;local scratch=buffer.create(spec[1]);local tempBuffer=makeBuffer(spec[1]);local temp=buffers[tempBuffer];temp.Data=scratch;local typed={Buffer=tempBuffer,Offset=0,Size=spec[1],Format=spec[2]}
   if action=="get"then local bytes=buffer.readstring(data,at,spec[1]);buffer.writestring(scratch,0,if little then bytes else bytes:reverse());return read(typed,0)end
   write(typed,0,number);local bytes=buffer.tostring(scratch);buffer.writestring(data,at,if little then bytes else bytes:reverse());return U
  end)end
 end
 def(bufferProto,vm.SymbolToStringTag,{value="ArrayBuffer",configurable=true});def(dataProto,vm.SymbolToStringTag,{value="DataView",configurable=true})
 function api:ReadBytes(value)
  check();local state=buffers[value];if state then brand(buffers,value,"BufferSource");return buffer.tostring(state.Data)end;local view=views[value];if view then brand(views,value,"BufferSource");return buffer.readstring(buffers[view.Buffer].Data,view.Offset,view.Length*view.Size)end;fail("TypeError","Expected an ArrayBuffer or ArrayBuffer view")
 end
 function api:IsBufferSource(value)return buffers[value]~=nil or views[value]~=nil end
 function api:IsUint8(value)local state=views[value];return state~=nil and state.Kind=="Uint8Array"end
 function api:FromBytes(bytes)check();return makeView("Uint8Array",makeBuffer(#bytes,bytes),0,#bytes)end
 function api:Buffer(bytes)check();return makeBuffer(#bytes,bytes)end
 function api:WriteBytes(value,offset,bytes)local state=brand(views,value,"Binary write");if offset<0 or offset+#bytes>state.Length*state.Size then fail("RangeError","Binary write exceeds view bounds")end;buffer.writestring(buffers[state.Buffer].Data,state.Offset+offset,bytes)end
 function api:Describe(value)
  check();local state=buffers[value];if state then return {Kind="ArrayBuffer",ByteLength=state.Length,Detached=state.Detached==true}end
  local view=views[value];if view then return {Kind=view.Kind,Buffer=view.Buffer,ByteOffset=view.Offset,Length=view.Length,Detached=buffers[view.Buffer].Detached==true}end
  return nil
 end
 function api:Detach(value)local state=brand(buffers,value,"ArrayBuffer detach");state.Data=nil;state.Length=0;state.Detached=true end
 function api:ReplaceBytes(value,bytes)local state=brand(buffers,value,"ArrayBuffer write");if #bytes~=state.Length then fail("RangeError","Transferred buffer size changed")end;if #bytes>0 then buffer.writestring(state.Data,0,bytes)end end
 function api:CreateView(kind,source,offset,length)
  if kind=="DataView"then return vm:Construct(constructors.DataView,{source,offset,length})end
  if not KINDS[kind]then fail("TypeError","Unknown binary view type")end
  brand(buffers,source,"TypedArray buffer");return makeView(kind,source,offset,length)
 end
 accessor(bufferProto,"detached",function(value)return brand(buffers,value,"ArrayBuffer.detached",true).Detached==true end)
 for _,name in {"transfer","transferToFixedLength"}do method(bufferProto,name,0,function(args,value)
  local state=brand(buffers,value,"ArrayBuffer."..name);local length=if arg(args,1)==U then state.Length else index(args[1]);local copy=makeBuffer(length)
  local count=math.min(length,state.Length);if count>0 then buffer.copy(buffers[copy].Data,0,state.Data,0,count)end;api:Detach(value);return copy
 end)end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  -- Held foreign views may still refer to this state through the shared
  -- weak brand lookup. Mark released backing storage detached before clearing
  -- native bytes, so their live realm never attempts buffer reads on nil.
  for _,state in buffers do state.Data=nil;state.Length=0;state.Detached=true end
  for value,state in views do
   sharedViews[value]=nil
   if model.Exotic[value]==typedHandlers then model.Exotic[value]=nil end
   state.Backing=nil
  end
  table.clear(buffers);table.clear(views)
 end
 return api
end
return BinaryData
