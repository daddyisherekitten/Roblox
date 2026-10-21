--!strict
-- Discover the actual installed surface without evaluating an author getter.
-- Availability is separate from semantic, rendering or native-host coverage.
return function(Parser: any,Runtime: any,VM: any,Events: any)
 local events=Events.new(error)
 local runtime=Runtime.new(Parser.parseDocument('<!doctype html><html><head></head><body></body></html>'),{
  URL='https://inventory.test/',Events=events,Schedule=function()end,MaxSteps=300000})
 local vm,model=runtime.VM,runtime.VM.ObjectModel
 local U,N=VM.Undefined,VM.Null
 local records,owners,queue,seen,paths={},{},{},{},{}
 local reads=0
 local sentinel=vm.Object({})
 vm:Install(function()
  assert(model.DefineOwn(sentinel,'neverEvaluate',{Accessor=true,Get=function()reads+=1;error('Inventory invoked an accessor')end,Enumerable=true,Configurable=true}))
 end)
 local function label(key)
  return if type(key)=='table'and key.Kind=='symbol'then '['..tostring(key.Description or 'Symbol()')..']'else tostring(key)
 end
 local function kind(value)
  return if value==U then'undefined'elseif value==N then'null'elseif type(value)=='table'then value.Kind or'host-object'else type(value)
 end
 local function source(fn)
  if type(fn)=='table'then fn=fn.Call end
  if type(fn)~='function'then return nil end
  local file,line=debug.info(fn,'sl')
  return {file=file,line=line}
 end
 -- Ordinary internal records and explicit descriptor hooks never synthesize
 -- values through a wrapper's legacy Get/HasOwn fallback.
 local function own(value,key)
  if model.Ordinary(value)then return model.Own(value,key)end
  if type(value)=='table'and value.GetOwnPropertyDescriptor then return value.GetOwnPropertyDescriptor(key)end
  return nil
 end
 local function enqueue(value,path)
  if not model.IsObject(value)then return end
  local id=seen[value]
  if id then table.insert(paths[id],path);return id end
  id=#owners+1;assert(id<=4096,'API inventory object budget exceeded')
  seen[value]=id;paths[id]={path};owners[id]={id=id,path=path,kind=kind(value)}
  table.insert(queue,{value=value,id=id,path=path});return id
 end
 local function functionInfo(value)
  if not VM.callable(value)then return nil end
  local name,length=own(value,'name'),own(value,'length')
  return {name=if name and not name.Accessor then name.Value else nil,
   length=if length and not length.Accessor then length.Value else nil,
   call=source(value),construct=if type(value)=='table'then source(value.Construct)else nil,
   constructible=type(value)=='table'and type(value.Construct)=='function'}
 end
 local function property(value,id,path,key,descriptor)
  if not descriptor then return end
  local keyLabel=label(key)
  local row={owner=id,path=path..'.'..keyLabel,key=keyLabel,symbol=type(key)=='table',
   enumerable=descriptor.Enumerable==true,configurable=descriptor.Configurable==true,
   descriptor=if descriptor.Accessor then'accessor'else'data'}
  if descriptor.Accessor then
   row.getter=descriptor.Get~=nil and descriptor.Get~=U
   row.setter=descriptor.Set~=nil and descriptor.Set~=U
   row.get=functionInfo(descriptor.Get);row.set=functionInfo(descriptor.Set)
  else
   row.writable=descriptor.Writable==true;row.valueKind=kind(descriptor.Value)
   row.functionInfo=functionInfo(descriptor.Value)
   if model.IsObject(descriptor.Value)then
    if not VM.callable(descriptor.Value)or path=='globalThis'or key=='prototype'then row.valueOwner=enqueue(descriptor.Value,row.path)end
   elseif type(descriptor.Value)=='string'or type(descriptor.Value)=='boolean'or type(descriptor.Value)=='number'and descriptor.Value==descriptor.Value and math.abs(descriptor.Value)<math.huge then
    row.value=descriptor.Value
   end
  end
  table.insert(records,row);assert(#records<=12000,'API inventory descriptor budget exceeded')
 end
 vm:Install(function()
  local globalId=enqueue(runtime.Window,'globalThis')
  -- The sentinel is exported and then removed from the final public register.
  enqueue(sentinel,'<getter-sentinel>')
  -- Reach installed navigator objects through private references, never getters.
  local navigatorRoots=runtime.MediaDevices.InventoryRoots or{}
  local navigatorPaths={};for path in navigatorRoots do table.insert(navigatorPaths,path)end;table.sort(navigatorPaths)
  for _,path in navigatorPaths do enqueue(navigatorRoots[path],'globalThis.'..path)end
  for path,value in runtime.WebLocks.InventoryRoots or{}do enqueue(value,'globalThis.'..path)end
  for path,value in runtime.Scheduler.InventoryRoots or{}do enqueue(value,'globalThis.'..path)end
  local prototypeNames={};for name in vm.Prototypes do table.insert(prototypeNames,name)end;table.sort(prototypeNames)
  for _,name in prototypeNames do enqueue(vm.Prototypes[name],'<intrinsic>.'..name..'.prototype')end
  local index=1
  while index<=#queue do
   local item=queue[index];index+=1
   local value,id,path=item.value,item.id,item.path
   local prototype=model.GetPrototype(value)
   if prototype~=N and prototype~=U then owners[id].prototype=enqueue(prototype,path..'.[[Prototype]]')end
   owners[id].functionInfo=functionInfo(value)
   if value==runtime.Window then
    local keys=vm.GlobalEnvironment:Keys(false)
    for _,key in keys do property(value,id,path,key,vm.GlobalEnvironment:Own(key))end
   elseif model.Ordinary(value)or type(value)=='table'and value.GetOwnPropertyDescriptor then
    for _,key in model.OwnKeys(value,false)do property(value,id,path,key,own(value,key))end
   else owners[id].inspection='opaque legacy wrapper: no getter-free own descriptor protocol' end
  end
  assert(reads==0,'Inventory evaluated a property getter')
  assert(not runtime.Started and runtime.ScriptsRun==0,'Inventory started page scripts')
  for id,owner in owners do table.sort(paths[id]);owner.aliases=paths[id]end
  local function convert(value)
   if type(value)~='table'then return value end
   if #value>0 then local items={};for _,entry in value do table.insert(items,convert(entry))end;return vm.Array(items)end
   local out={};for key,entry in value do out[key]=convert(entry)end;return vm.Object(out,N)
  end
  local json=vm.GlobalEnvironment:Own('JSON').Value
  local stringify=own(json,'stringify').Value
  local function emit(tag,value)
   print(tag..' '..vm:Call(stringify,{convert(value)},json))
  end
  emit('API_INVENTORY_HEADER',{schema='roblox-javascript-api-surface/v1',profile='empty document Runtime; no author scripts; no accessor evaluation',owners=#owners,records=#records})
  for _,owner in owners do emit('API_INVENTORY_OWNER',owner)end
  for _,record in records do emit('API_INVENTORY_RECORD',record)end
  emit('API_INVENTORY_END',{owners=#owners,records=#records,getterReads=reads,scriptsRun=runtime.ScriptsRun})
 end)
 runtime:Destroy();events:Destroy()
 assert(not runtime.Alive and not vm.Alive,'Inventory leaked its live Runtime')
end
