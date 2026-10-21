--!strict
-- Streaming encoders use the same codecs and demand-driven transform queues.
local Strings=require(script.Parent.Strings)
local EncodingStreams={}
function EncodingStreams.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U=VM.Undefined;local api={Alive=true};local records=setmetatable({},{__mode="kv"})
 local encoderCtor,decoderCtor=globals.TextEncoder,globals.TextDecoder
 local encode,decode=vm.Get(vm.Get(encoderCtor,"prototype"),"encode"),vm.Get(vm.Get(decoderCtor,"prototype"),"decode")
 local function check()assert(api.Alive and vm.Alive,"Encoding streams disposed")end
 local function fail(message)VM.throw(VM.error("TypeError",message))end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function call(value,key,args)return vm:Call(vm.Get(value,key),args or {},value)end
 local function def(value,key,d)vm.DefineProperty(value,key,vm.Object(d,VM.Null))end
 local function native(name,n,fn)local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end};def(value,"length",{value=n,configurable=true});def(value,"name",{value=name,configurable=true});return value end
 for _,name in {"TextEncoderStream","TextDecoderStream"}do
  local proto=vm.Object({});local constructor=native(name,0,function()fail(name.." requires new")end)
  constructor.Construct=function(args)
   check();local encoding=name=="TextEncoderStream";local codec=vm:Construct(if encoding then encoderCtor else decoderCtor,if encoding then {}else{arg(args,1),arg(args,2)})
   local state={Kind=name,Codec=codec,Pending=nil};local value=vm.Object({},proto);value.NetworkState=state;records[value]=state
   local transformer=vm.Object({transform=function(items)
    check();local chunk,controller=items[1],items[2];local output
    if encoding then
     chunk=vm.ToPrimitive(chunk,"string");if type(chunk)=="table"and chunk.Kind=="symbol"then fail("Cannot encode Symbol")end
     local units=Strings.units(VM.string(chunk));if state.Pending then table.insert(units,1,state.Pending);state.Pending=nil end
     local last=units[#units];if last and last>=0xd800 and last<=0xdbff then state.Pending=table.remove(units)end
     output=vm:Call(encode,{Strings.fromUnits(units)},codec)
    else if not options.Binary:IsBufferSource(chunk)then fail("TextDecoderStream chunks must be BufferSource values")end;output=vm:Call(decode,{chunk,vm.Object({stream=true})},codec)end
    if(if encoding then vm.Get(output,"byteLength")else Strings.length(output))>0 then call(controller,"enqueue",{output})end;return U
   end,flush=function(items)
    check();local output=if encoding then(if state.Pending then vm:Call(encode,{Strings.fromUnits({state.Pending})},codec)else nil)else vm:Call(decode,{},codec)
    state.Pending=nil
    if output and(if encoding then vm.Get(output,"byteLength")else Strings.length(output))>0 then call(items[1],"enqueue",{output})end;return U
   end})
   state.Stream=options.Transforms:New(transformer);return value
  end
  def(constructor,"prototype",{value=proto});def(proto,"constructor",{value=constructor,writable=true,configurable=true});def(proto,vm.SymbolToStringTag,{value=name,configurable=true})
  for _,key in (if name=="TextEncoderStream"then {"encoding","readable","writable"}else{"encoding","fatal","ignoreBOM","readable","writable"})do
   def(proto,key,{get=native("get "..key,0,function(_,value)local state=records[value];if not state or state.Kind~=name then fail("Invalid "..name.." receiver")end;return vm.Get(if key=="readable"or key=="writable"then state.Stream else state.Codec,key)end),enumerable=true,configurable=true})
  end
  globals[name]=constructor;vm.Global.Bindings[name]={Value=constructor}
 end
 function api:Destroy()self.Alive=false;for _,state in records do state.Codec,state.Stream,state.Pending=nil,nil,nil end;table.clear(records)end
 return api
end
return EncodingStreams
