--!strict
-- Explicitly supplied storage areas define origin/session sharing and durability.
-- Commit runs before mutation; a failed quota/host commit leaves the area intact.
local Strings=require(script.Parent.Strings)
local Storage={}
function Storage.createArea(options: any?): any
 options=options or {};return {Values={},Order={},Bytes=0,QuotaBytes=options.QuotaBytes or 1048576,MaxEntries=options.MaxEntries or 4096,
  Commit=options.Commit,Durability=options.Durability or 'memory',Subscribers={}}
end
function Storage.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local model=vm.ObjectModel;local events=assert(options.Events)
 local api={Alive=true};local records=setmetatable({},{__mode='kv'});local eventRecords=setmetatable({},{__mode='kv'});local holders={};local subscriptions={}
 local function check()assert(api.Alive and vm.Alive,'JavaScript storage disposed')end
 local function fail(name,message)VM.throw(if name=='TypeError'then VM.error(name,message)else events:DOMException(message,name))end
 local function text(value)
  value=vm.ToPrimitive(value,'string');if type(value)=='table'and value.Kind=='symbol'then fail('TypeError','Cannot convert a Symbol to storage text')end
  local result=VM.string(value);if #result>1048576 then fail('QuotaExceededError','Storage text budget exceeded')end;return result
 end
 local function usv(value)
  local units=Strings.units(text(value));local i=1;while i<=#units do local a,b=units[i],units[i+1]
   if a>=0xd800 and a<=0xdbff and b and b>=0xdc00 and b<=0xdfff then i+=2 elseif a>=0xd800 and a<=0xdfff then units[i]=0xfffd;i+=1 else i+=1 end
  end;return Strings.fromUnits(units)
 end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function required(args,n,name)if #args<n then fail('TypeError',name..' requires '..n..' arguments')end end
 local function define(target,key,d)vm.DefineProperty(target,key,vm.Object(d,VM.Null))end
 local function native(name,n,fn)
  local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end}
  define(value,'length',{value=n,configurable=true});define(value,'name',{value=name,configurable=true});return value
 end
 local function method(target,name,n,fn)define(target,name,{value=native(name,n,fn),writable=true,enumerable=true,configurable=true})end
 local function accessor(target,name,read)define(target,name,{get=native('get '..name,0,function(_,receiver)return read(receiver)end),enumerable=true,configurable=true})end
 local function brand(registry,value,name)local r=registry[value];if not r then fail('TypeError',name..' called on incompatible receiver')end;return r end
 local prototype=vm.Object({});local eventPrototype=vm.Object({},vm.Get(globals.Event,'prototype'));vm.Prototypes.Storage=prototype;vm.Prototypes.StorageEvent=eventPrototype
 if vm.SymbolToStringTag then define(prototype,vm.SymbolToStringTag,{value='Storage',configurable=true});define(eventPrototype,vm.SymbolToStringTag,{value='StorageEvent',configurable=true})end
 local function nullable(value)return if value==nil or value==U or value==N then N else text(value)end
 local function newEvent(typeName,init)
  local value=events:NewEvent(typeName,init);value.Prototype=eventPrototype;value.StorageEventState=init;eventRecords[value]=init;return value
 end
 for _,field in {'key','oldValue','newValue','url','storageArea'}do accessor(eventPrototype,field,function(receiver)return brand(eventRecords,receiver,'StorageEvent.'..field)[field]end)end
 local function eventInit(value)
  if value~=nil and value~=U and value~=N and not model.IsObject(value)then fail('TypeError','StorageEvent options must be a dictionary')end
  local out={};for _,field in {'bubbles','cancelable','composed','key','newValue','oldValue','storageArea','url'}do
   local item=if value==nil or value==U or value==N then U else vm.Get(value,field)
   if field=='bubbles'or field=='cancelable'or field=='composed'then out[field]=VM.truth(item)
   elseif field=='url'then out.url=if item==U then ''else usv(item)
   elseif field=='storageArea'then if item~=U and item~=N and not records[item]then fail('TypeError','StorageEvent storageArea must be Storage')end;out.storageArea=if item==U then N else item
   else out[field]=nullable(item)end
  end;return out
 end
 local storageCtor=native('Storage',0,function()fail('TypeError','Illegal Storage constructor')end)
 storageCtor.Construct=function()fail('TypeError','Illegal Storage constructor')end;define(storageCtor,'prototype',{value=prototype});define(prototype,'constructor',{value=storageCtor,writable=true,configurable=true})
 local eventCtor=native('StorageEvent',1,function()fail('TypeError','StorageEvent requires new')end)
 eventCtor.Construct=function(args)required(args,1,'StorageEvent');return newEvent(text(args[1]),eventInit(args[2]))end
 define(eventCtor,'prototype',{value=eventPrototype});define(eventPrototype,'constructor',{value=eventCtor,writable=true,configurable=true})
 globals.Storage,globals.StorageEvent=storageCtor,eventCtor;vm.Global.Bindings.Storage={Value=storageCtor};vm.Global.Bindings.StorageEvent={Value=eventCtor}
 method(eventPrototype,'initStorageEvent',1,function(args,receiver)
  required(args,1,'initStorageEvent');local r=brand(eventRecords,receiver,'initStorageEvent');local typeName=text(args[1]);local key,old,new=nullable(args[4]),nullable(args[5]),nullable(args[6]);local url=if args[7]==nil or args[7]==U then ''else usv(args[7]);local area=arg(args,8)
  if area~=U and area~=N and not records[area]then fail('TypeError','storageArea must be Storage')end
  local dispatching=receiver.HostState and receiver.HostState.Dispatching
  if not dispatching then vm:Call(vm.Get(vm.Prototypes.Event or vm.Get(globals.Event,'prototype'),'initEvent'),{typeName,arg(args,2),arg(args,3)},receiver);r.key,r.oldValue,r.newValue,r.url,r.storageArea=key,old,new,url,if area==U then N else area end;return U
 end)
 local function broadcast(area,source,key,old,new)
  local url=if options.GetURL then options.GetURL()else ''
  local snapshot=table.clone(area.Subscribers)
  for _,subscriber in snapshot do if subscriber.Source~=source and subscriber.Kind==source.Kind then subscriber.Notify(key,old,new,url)end end
 end
 local function commit(area,change)
  if area.Commit and area.Commit(change)==false then fail('QuotaExceededError','Storage backend rejected mutation')end
 end
 local function write(r,key,value)
  check();local area=r.Area;local old=area.Values[key];if old==value then return end
  local bytes=area.Bytes+(if old then 2*(vm.StringLength(value)-vm.StringLength(old))else 2*(vm.StringLength(key)+vm.StringLength(value)))
  if bytes>area.QuotaBytes or old==nil and #area.Order>=area.MaxEntries then fail('QuotaExceededError','Storage quota exceeded')end
  commit(area,{Kind='set',Key=key,OldValue=old,NewValue=value,Bytes=bytes})
  area.Values[key]=value;area.Bytes=bytes;if old==nil then table.insert(area.Order,key)end;broadcast(area,r,key,old or N,value)
 end
 local function remove(r,key)
  local area=r.Area;local old=area.Values[key];if old==nil then return end
  commit(area,{Kind='remove',Key=key,OldValue=old});area.Values[key]=nil;area.Bytes-=2*(vm.StringLength(key)+vm.StringLength(old));local at=table.find(area.Order,key);if at then table.remove(area.Order,at)end;broadcast(area,r,key,old,N)
 end
 accessor(prototype,'length',function(receiver)return #brand(records,receiver,'Storage.length').Area.Order end)
 method(prototype,'key',1,function(args,receiver)
  local r=brand(records,receiver,'Storage.key');required(args,1,'Storage.key');local n=VM.number(vm.ToPrimitive(args[1],'number'));n=if n~=n or math.abs(n)==math.huge then 0 elseif n<0 then math.ceil(n)else math.floor(n);return r.Area.Order[n%4294967296+1]or N
 end)
 method(prototype,'getItem',1,function(args,receiver)local r=brand(records,receiver,'Storage.getItem');required(args,1,'Storage.getItem');return r.Area.Values[text(args[1])]or N end)
 method(prototype,'setItem',2,function(args,receiver)local r=brand(records,receiver,'Storage.setItem');required(args,2,'Storage.setItem');local key,value=text(args[1]),text(args[2]);write(r,key,value);return U end)
 method(prototype,'removeItem',1,function(args,receiver)local r=brand(records,receiver,'Storage.removeItem');required(args,1,'Storage.removeItem');remove(r,text(args[1]));return U end)
 method(prototype,'clear',0,function(_,receiver)
  local r=brand(records,receiver,'Storage.clear');local area=r.Area;if #area.Order==0 then return U end;commit(area,{Kind='clear'});table.clear(area.Values);table.clear(area.Order);area.Bytes=0;broadcast(area,r,N,N,N);return U
 end)
 local function visible(r,key)
  if type(key)~='string'or r.Area.Values[key]==nil then return false end
  local cursor,seen=r.Expandos,{};while cursor~=N do vm.Step();if seen[cursor]then fail('TypeError','Cyclic Storage prototype')end;seen[cursor]=true
   if model.Own(cursor,key)then return false end;cursor=model.GetPrototype(cursor)
  end;return true
 end
 local handlers={}
 function handlers.Own(value,key)local r=records[value];if visible(r,key)then return {Value=r.Area.Values[key],Writable=true,Enumerable=true,Configurable=true}end;return model.Own(r.Expandos,key)end
 function handlers.Get(value,key,receiver)local r=records[value];return if visible(r,key)then r.Area.Values[key]else model.Get(r.Expandos,key,receiver)end
 function handlers.Has(value,key)local r=records[value];return visible(r,key)or model.Has(r.Expandos,key)end
 function handlers.GetPrototype(value)return model.GetPrototype(records[value].Expandos)end
 function handlers.SetPrototype(value,p)return model.SetPrototypeInternal(records[value].Expandos,p)end
 function handlers.IsExtensible()return true end
 function handlers.PreventExtensions()return false end
 function handlers.Set(value,key,item,receiver)
  if receiver~=value then return model.Set(records[value].Expandos,key,item,false,receiver)end
  if type(key)=='string'then
   if model.Has(records[value].Expandos,key)then return model.Set(records[value].Expandos,key,item,false,value)end
   write(records[value],key,text(item));return true
  end;return model.Set(records[value].Expandos,key,item,false)
 end
 function handlers.Define(value,key,d)
  if type(key)~='string'then return model.DefineOwn(records[value].Expandos,key,d)end
  if d.Get~=nil or d.Set~=nil then return true end
  if model.Has(records[value].Expandos,key)then return model.DefineOwn(records[value].Expandos,key,d)end
  write(records[value],key,text(if d.Value==nil then U else d.Value));return true
 end
 function handlers.Delete(value,key)
  local r=records[value];if type(key)=='string'and visible(r,key)then remove(r,key);return true end;return model.Delete(r.Expandos,key,false)
 end
 function handlers.OwnKeys(value)
  local r=records[value];local out,seen={},{};for _,key in r.Area.Order do table.insert(out,key);seen[key]=true end
  for _,key in model.OwnKeys(r.Expandos,false)do if not seen[key]then table.insert(out,key)end end;return out
 end
 function api:Get(kind)
  check();if holders[kind]then return holders[kind]end
  local area=options.GetArea and options.GetArea(kind);if not area then fail('SecurityError','Storage is unavailable for this origin/session')end
  assert(area.Values and area.Order and area.Subscribers,'Storage adapter must return a storage area')
  local r={Kind=kind,Area=area,Expandos=vm.Object({},prototype)};local value=vm.Object({});value.Values=nil;value.Kind='storage';value.StorageState=r;records[value]=r;model.Exotic[value]=handlers;holders[kind]=value
  local subscriber={Kind=kind,Source=r,Notify=function(key,old,new,url)
   if not api.Alive then return end;assert(options.QueueTask,'Storage requires queued cross-window events')
   options.QueueTask(function()if api.Alive then events:Dispatch(options.Window,newEvent('storage',{key=key,oldValue=old,newValue=new,url=url,storageArea=value}),true)end end)
  end};table.insert(area.Subscribers,subscriber);table.insert(subscriptions,{Area=area,Subscriber=subscriber});return value
 end
 for _,entry in {{'localStorage','local'},{'sessionStorage','session'}}do
  vm.Global.Bindings[entry[1]]={Get=function()return api:Get(entry[2])end,Set=function(_,strict)if strict then fail('TypeError','Storage global is read-only')end end}
 end
 function api.WindowGet(key)return if key=='localStorage'then api:Get('local')elseif key=='sessionStorage'then api:Get('session')else nil end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  for _,subscription in subscriptions do local at=table.find(subscription.Area.Subscribers,subscription.Subscriber);if at then table.remove(subscription.Area.Subscribers,at)end end
  for value in records do model.Exotic[value]=nil end;table.clear(subscriptions);table.clear(holders);table.clear(records);table.clear(eventRecords)
 end
 -- Connected documents receive storage events even when their scripts have
 -- only registered a window listener and never read a storage property.
 -- Denied areas stay denied when subsequently accessed by JavaScript.
 for _,kind in {'local','session'}do pcall(api.Get,api,kind)end
 return api
end
return Storage
