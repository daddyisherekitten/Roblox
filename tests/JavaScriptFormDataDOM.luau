--!strict
return function(VM,Promises,AsyncFunctions,EventLoop,HostEvents,NetworkData,FormDataDOM,Parser,DOM,fixtures)
 local function fresh(html)
  local result={Values={},Reports={}};local vm,promises,eventHost,adapter,globals
  local loop=EventLoop.new({Invoke=function(fn,args)return vm:Call(fn,args)end,Report=function(message)table.insert(result.Reports,tostring(message))end,AfterCheckpoint=function()if promises then promises:AfterCheckpoint()end end})
  local document=Parser.parseDocument("<!doctype html><html><body>"..(html or "").."</body></html>")
  local window={Get=function(key)local binding=vm and vm.Global.Bindings[key];return if binding then binding.Value elseif globals and globals[key]~=nil then globals[key]else VM.Undefined end,
   Set=function(key,value)if vm then vm.Global.Bindings[key]={Value=value}else globals[key]=value end end}
  local domHost={Window=window,ControlAdapter={},ReadyState="complete",Changed=function()end,
   Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(value,key)return vm.Get(value,key)end}
  local bridge=DOM.new(document,domHost)
  globals={document=bridge.Document,window=window,record=function(args)table.insert(result.Values,VM.string(args[1]));return VM.Undefined end}
  promises=Promises.new({Enqueue=function(fn)loop:QueueMicrotask(fn)end,Report=function(message)table.insert(result.Reports,VM.string(message))end,
   Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(value,key,receiver)return vm.Get(value,key,receiver)end,
   Construct=function(fn,args)return vm:Construct(fn,args)end,Iterator=function(value)return vm.Iterator(value)end,Array=function(values)return vm.Array(values)end,Object=function(values)return vm.Object(values)end})
  globals.Promise=promises.Constructor
  local async=AsyncFunctions.new({Create=function()return promises:CreateCapability()end,Wait=function(value,yes,no)promises:Await(value,yes,no)end,Resume=function(record,rejected,value)return vm:ResumeAsync(record,rejected,value)end})
  vm=VM.new(globals,{Async=async,MaxSteps=100000});promises:Attach(vm);bridge.AttachVM(vm)
  eventHost=HostEvents.install(vm,globals,{Report=function(message)table.insert(result.Reports,VM.string(message))end})
  local targetFor
  targetFor=function(node)
   local target=if node then bridge.Wrap(node)else window
   eventHost:WrapTarget(target,{Handlers=true,Parent=function()return if node then targetFor(node.Parent)else nil end})
   return target
  end
  domHost.EventMethod=function(node,key)return eventHost:TargetMethods(targetFor(node),key)end
  domHost.EventGet=function(node,key)if key:sub(1,2)=="on"then return eventHost:HandlerGet(targetFor(node),key)end;return nil end
  domHost.EventSet=function(node,key,value)if key:sub(1,2)~="on"then return false end;eventHost:HandlerSet(targetFor(node),key,value);return true end
  local network=NetworkData.install(vm,globals,{HostEvents=eventHost,BaseURL="https://example.com/",CreatePromise=function()return promises:CreateCapability()end,
   Await=function(value,yes,no)promises:Await(value,function(args)yes(args[1])end,function(args)no(args[1])end)end,
   Enqueue=function(fn)loop:QueueMicrotask(fn)end,EnqueueTask=function(fn)loop:QueueTask(fn)end,
   FormDataEntries=function(form,submitter)return adapter:Entries(form,submitter)end,FormDataConstructed=function(form,data)adapter:Constructed(form,data)end})
  adapter=FormDataDOM.new(vm,bridge,document,{Network=network,Events=eventHost,TargetFor=targetFor})
  function result:Run(source)vm:Run(source);loop:Checkpoint();for _=1,4 do loop:PumpTasks()end end
  function result:Destroy()adapter:Destroy();network:Destroy();eventHost:Destroy();bridge:Destroy();async:Destroy();promises:Destroy();loop:Destroy();vm:Destroy()end
  result.Adapter,result.Network,result.Bridge,result.VM=adapter,network,bridge,vm
  return result
 end
 for _,fixture in fixtures do
  local realm=fresh(fixture.html);local ok,failure=pcall(function()realm:Run(fixture.source)end)
  assert(ok,fixture.name..": "..VM.string(VM.exceptionValue(failure)))
  assert(#realm.Reports==0,fixture.name..": "..table.concat(realm.Reports," | "))
  assert(#realm.Values==#fixture.expected,fixture.name..": "..table.concat(realm.Values," | "))
  for i,value in fixture.expected do assert(realm.Values[i]==value,fixture.name..": "..table.concat(realm.Values," | "))end
  realm:Destroy()
 end
 do
  local realm=fresh('<form id="f"><input id="files" type="file" name="files" multiple></form>')
  realm:Run("const first=new File(['a'],'a.txt'),second=new File(['b'],'b.txt');")
  local input=realm.Bridge.Unwrap(realm.VM:Call(realm.VM.Get(realm.Bridge.Document,"getElementById"),{"files"},realm.Bridge.Document))
  realm.Bridge.Controls:State(input).Files={realm.VM.Global.Bindings.first.Value,realm.VM.Global.Bindings.second.Value}
  realm:Run("const f=new FormData(document.getElementById('f'));record(f.getAll('files').map(function(x){return x.name;}).join(','));record(f.get('files')===first);")
  assert(table.concat(realm.Values,",")=="a.txt,b.txt,true","Native File records preserve ordering and File identity")
  local adapter=realm.Adapter;realm:Destroy();assert(not pcall(function()adapter:Entries({})end),"Disposed form adapters cannot traverse retained documents")
 end
 print("JavaScript FormData DOM: "..#fixtures.." shared traces plus native files and disposal passed")
end
