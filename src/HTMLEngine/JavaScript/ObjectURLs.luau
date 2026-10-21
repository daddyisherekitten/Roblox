--!strict
-- Explicit host resource registry. No URL grants access to disk or sockets.
local ObjectURLs={}
function ObjectURLs.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U=VM.Undefined;local api={Alive=true};local owned={}
 local store=options.Store or {Entries={},Bytes=0,Count=0};local origin=options.Origin or "null"
 local partition=options.PartitionKey or(if origin=="null"then {}else origin)
 assert(type(store.Entries)=="table"and type(store.Bytes)=="number"and type(store.Count)=="number","Invalid object URL store")
 local function check()assert(api.Alive and vm.Alive,"Object URL registry disposed")end
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function text(value)value=vm.ToPrimitive(value,"string");if type(value)=="table"and value.Kind=="symbol"then fail("TypeError","Cannot convert Symbol to an object URL")end;return VM.string(value)end
 local function key(url)return(url:match("^[^#]*")or url)end
 local function native(name,n,callback)
  local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args)check();return callback(args)end}
  vm.DefineProperty(value,"length",vm.Object({value=n,configurable=true},VM.Null));vm.DefineProperty(value,"name",vm.Object({value=name,configurable=true},VM.Null));return value
 end
 local function remove(url)
  local entry=store.Entries[url];if not entry then return end
  store.Entries[url]=nil;store.Bytes-=#entry.Bytes;store.Count-=1
  if entry.Owner then entry.Owner[url]=nil end
 end
 local function uuid()
  local bytes={};for i=1,16 do bytes[i]=math.random(0,255)end;bytes[7]=bit32.bor(bit32.band(bytes[7],15),64);bytes[9]=bit32.bor(bit32.band(bytes[9],63),128)
  local parts={};for i,value in bytes do if i==5 or i==7 or i==9 or i==11 then table.insert(parts,"-")end;table.insert(parts,string.format("%02x",value))end;return table.concat(parts)
 end
 local urlCtor=vm.Global.Bindings.URL.Value
 vm.DefineProperty(urlCtor,"createObjectURL",vm.Object({value=native("createObjectURL",1,function(args)
  if #args<1 then fail("TypeError","URL.createObjectURL requires a Blob")end
  local blob=options.Network:DescribeBlob(args[1]);if not blob then fail("TypeError","URL.createObjectURL requires a Blob")end
  if store.Count>=256 or store.Bytes+#blob.Bytes>(options.MaxBytes or 8388608)then fail("RangeError","Object URL resource budget exceeded")end
  local url
  for _=1,8 do local candidate="blob:"..origin.."/"..uuid();if not store.Entries[candidate]then url=candidate;break end end
  if not url then fail("RangeError","Object URL identifier collision limit exceeded")end
  store.Entries[url]={Bytes=blob.Bytes,Type=blob.Type,Origin=origin,Partition=partition,Owner=owned};store.Count+=1;store.Bytes+=#blob.Bytes;owned[url]=true;return url
 end),writable=true,enumerable=true,configurable=true},VM.Null))
 vm.DefineProperty(urlCtor,"revokeObjectURL",vm.Object({value=native("revokeObjectURL",1,function(args)
  if #args<1 then fail("TypeError","URL.revokeObjectURL requires a URL")end
  local url=text(args[1]);local entry=store.Entries[url]
  -- Revocation parses a URL but a fragment is not an entry identifier.
  if entry and entry.Origin==origin and entry.Partition==partition then remove(url)end;return U
 end),writable=true,enumerable=true,configurable=true},VM.Null))
 function api:Resolve(url)
  check();local entry=store.Entries[key(url)]
  if not entry or entry.Origin~=origin or entry.Partition~=partition then return nil end
  return {Bytes=entry.Bytes,Type=entry.Type,Origin=entry.Origin,URL=key(url)}
 end
 function api:Destroy()if not self.Alive then return end;self.Alive=false;for url in owned do remove(url)end;table.clear(owned)end
 return api
end
return ObjectURLs
