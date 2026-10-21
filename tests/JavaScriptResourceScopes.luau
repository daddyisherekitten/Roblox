--!strict
return function(VM: any,Stacks: any,Promises: any,AsyncFunctions: any,fixtures: any)
 for _,fixture in fixtures do
  local values,jobs={},{};local globals={record=function(args)table.insert(values,VM.string(args[1]))end};local vm,promises
  local async=AsyncFunctions.new({Create=function()return promises:CreateCapability()end,Wait=function(v,yes,no)promises:Await(v,yes,no)end,Resume=function(r,rejected,v)return vm:ResumeAsync(r,rejected,v)end})
  vm=VM.new(globals,{MaxSteps=300000,Async=async})
  promises=Promises.new({Object=vm.Object,Array=vm.Array,Construct=function(fn,args)return vm:Construct(fn,args)end,Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(v,key,receiver)return vm.Get(v,key,receiver)end,Iterator=function(v)return vm.Iterator(v)end,Step=vm.Step,Enqueue=function(job)table.insert(jobs,job)end})
  promises:Attach(vm);globals.Promise=promises.Constructor;vm.Global.Bindings.Promise={Value=promises.Constructor}
  local stacks=Stacks.install(vm,globals,{CreatePromise=function()return promises:CreateCapability()end,Await=function(v,yes,no)promises:Await(v,function(args)yes(args[1])end,function(args)no(args[1])end)end})
  vm.Generators:AttachPromises(promises)
  local ok,message=pcall(function()vm:Run(fixture.source);local count=0;while #jobs>0 do count+=1;assert(count<=4096,'Microtask bound');table.remove(jobs,1)()end end)
  local expected=fixture.browserExpected or fixture.expected
  assert(ok,fixture.name..': '..tostring(message));assert(#values==#expected,fixture.name..': record count '..#values..' vs '..#expected..' ('..table.concat(values,' | ')..')')
  for i,want in expected do assert(values[i]==want,fixture.name..' record '..i..': '..tostring(values[i])..' versus '..want)end
  stacks:Destroy();async:Destroy();promises:Destroy();vm:Destroy()
 end
 -- Realm-owned scope records reject forged records and disposal keeps the
 -- original thrown undefined distinct from normal completion.
 local vm=VM.new({},{MaxSteps=100000});local api=Stacks.install(vm,{})
 local record=api:NewScope();assert(not api:ScopeIsAsync(record))
 assert(api:RegisterScope(record,VM.Null,false)==VM.Null)
 local ok,err=pcall(function()api:DisposeScope(record,true,VM.Undefined)end)
 assert(not ok and VM.exceptionValue(err)==VM.Undefined)
 ok,err=pcall(function()api:RegisterScope(record,VM.Null,false)end)
 assert(not ok and vm.Get(VM.exceptionValue(err),'name')=='ReferenceError')
 ok,err=pcall(function()api:DisposeScope({})end)
 assert(not ok and vm.Get(VM.exceptionValue(err),'name')=='TypeError')
 local abandoned=api:NewScope();local count=0;local value=vm.Object({})
 vm.DefineProperty(value,vm.Get(vm.Global.Bindings.Symbol.Value,'dispose'),vm.Object({value=function()count+=1 end}))
 api:RegisterScope(abandoned,value,false);api:Destroy();vm:Destroy();assert(count==0,'Destroy does not invent lexical disposal')
end
