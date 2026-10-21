--!strict
-- Isolated integration regressions for HTML module resolution and exotics.
return function(VM: any,Modules: any,Promises: any,AsyncFunctions: any,fixtures: any)
 for _,fixture in fixtures do
  local output,microtasks,tasks={},{},{};local globals={record=function(args)table.insert(output,VM.string(args[1]))end};local vm,promises
  local async=AsyncFunctions.new({Create=function()return promises:CreateCapability()end,Wait=function(v,yes,no)promises:Await(v,yes,no)end,Resume=function(r,rejected,v)return vm:ResumeAsync(r,rejected,v)end})
  vm=VM.new(globals,{MaxSteps=100000,Async=async});promises=Promises.new({Object=vm.Object,Array=vm.Array,Construct=function(fn,args)return vm:Construct(fn,args)end,Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=vm.Get,Iterator=vm.Iterator,Step=vm.Step,Enqueue=function(job)table.insert(microtasks,job)end})
  promises:Attach(vm);globals.Promise=promises.Constructor;vm.Global.Bindings.Promise={Value=promises.Constructor}
  if vm.Generators then vm.Generators:AttachPromises(promises)end
  local modules=Modules.install(vm,globals,{BaseURL='https://review.test/main.js',Promises=promises,ImportMap=fixture.importMap,Sources=fixture.sources,QueueTask=function(job)table.insert(tasks,job)end})
  if fixture.kind=='resolve'then table.insert(output,modules:Resolve(fixture.specifier,fixture.base))else
   local settled=false;local promise=modules:Run('./main.js')
   promises:Await(promise,function()settled=true end,function(args)settled=true;table.insert(output,'error:'..VM.string(vm.Get(args[1],'name')))end)
   local jobs=0;while #microtasks>0 or #tasks>0 do jobs+=1;assert(jobs<=4096,'Module job bound');if #microtasks>0 then table.remove(microtasks,1)()else table.remove(tasks,1)()end end
   assert(settled,fixture.name..': graph did not settle')
  end
  assert(#output==#fixture.expected,fixture.name..': '..table.concat(output,' | '));for i,want in fixture.expected do assert(output[i]==want,fixture.name..': '..output[i]..' versus '..want)end
  modules:Destroy();async:Destroy();promises:Destroy();vm:Destroy()
 end
end
