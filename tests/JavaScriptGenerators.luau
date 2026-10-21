--!strict
return function(VM: any,Generators: any,Promises: any,AsyncFunctions: any,fixtures: any)
 for _,fixture in fixtures do
  local values,jobs={},{};local globals={record=function(args)table.insert(values,VM.string(args[1]))end};local vm,promises
  local async=AsyncFunctions.new({Create=function()return promises:CreateCapability()end,Wait=function(v,yes,no)promises:Await(v,yes,no)end,Resume=function(r,rejected,v)return vm:ResumeAsync(r,rejected,v)end})
  vm=VM.new(globals,{MaxSteps=300000,Async=async})
  promises=Promises.new({Object=vm.Object,Array=vm.Array,Construct=function(fn,args)return vm:Construct(fn,args)end,Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(v,key,receiver)return vm.Get(v,key,receiver)end,Iterator=function(v)return vm.Iterator(v)end,Step=vm.Step,Enqueue=function(job)table.insert(jobs,job)end})
  promises:Attach(vm);globals.Promise=promises.Constructor;vm.Global.Bindings.Promise={Value=promises.Constructor}
  local generators=Generators.install(vm,globals,{Resume=function(r,mode,v)return vm:ResumeGenerator(r,mode,v)end,Promises=promises})
  local ok,message=pcall(function()vm:Run(fixture.source);local count=0;while #jobs>0 do count+=1;assert(count<=4096,'Microtask bound');table.remove(jobs,1)()end end)
  assert(ok,fixture.name..': '..tostring(message));assert(#values==#fixture.expected,fixture.name..': record count '..#values..' vs '..#fixture.expected..' ('..table.concat(values,' | ')..')')
  for i,want in fixture.expected do assert(values[i]==want,fixture.name..' record '..i..': '..tostring(values[i])..' versus '..want)end
  generators:Destroy();async:Destroy();promises:Destroy();vm:Destroy()
 end
 local vm=VM.new({},{MaxSteps=100000});local api=Generators.install(vm,{}, {Resume=function(r,mode,v)return vm:ResumeGenerator(r,mode,v)end})
 local count=0;local g=api:Create(function()count+=1;api:Yield(1);count+=1;return 2 end)
 assert(count==0);assert(vm.Get(vm:Call(vm.Get(g,'next'),{},g),'value')==1 and count==1)
 api:Destroy();vm:Destroy();assert(count==1,'Destroy closes suspended stacks without inventing user disposal')
end
