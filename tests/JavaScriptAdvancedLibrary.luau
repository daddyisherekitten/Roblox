--!strict
return function(VM: any,Intl: any,ResourceStacks: any,Promises: any,fixtures: any)
 for _,fixture in fixtures do
  local values,jobs={},{};local globals={record=function(args)table.insert(values,VM.string(args[1]))end}
  local vm=VM.new(globals,{MaxSteps=300000});local intl=Intl.install(vm,globals)
  local promises=Promises.new({Object=vm.Object,Array=vm.Array,Construct=function(fn,args)return vm:Construct(fn,args)end,Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(value,key,receiver)return vm.Get(value,key,receiver)end,Iterator=function(value)return vm.Iterator(value)end,Step=function()vm.Step()end,Enqueue=function(job)table.insert(jobs,job)end})
  promises:Attach(vm);globals.Promise=promises.Constructor;vm.Global.Bindings.Promise={Value=promises.Constructor}
  local stacks=ResourceStacks.install(vm,globals,{CreatePromise=function()return promises:CreateCapability()end,Await=function(value,yes,no)promises:Await(value,function(args)yes(args[1])end,function(args)no(args[1])end)end})
  local ok,message=pcall(function()vm:Run(fixture.source);local count=0;while #jobs>0 do count+=1;assert(count<=4096,'Microtask bound');local job=table.remove(jobs,1);job()end end)
  local expected=fixture.browserExpected or fixture.expected
  assert(ok,fixture.name..': '..tostring(message));assert(#values==#expected,fixture.name..': record count '..#values..' vs '..#expected..' ('..table.concat(values,' | ')..')')
  for i,want in expected do assert(values[i]==want,fixture.name..' record '..i..': '..tostring(values[i])..' versus '..want)end
  stacks:Destroy();intl:Destroy();promises:Destroy();vm:Destroy()
 end
 local vm=VM.new({},{MaxSteps=100000});local intl=Intl.install(vm,{})
 local ok,err=pcall(function()vm:Run("new Intl.NumberFormat('en-US',{style:'unit',unit:'meter-per-liter'})")end);assert(not ok and vm.Get(VM.exceptionValue(err),'name')=='RangeError','Unsupported compound-unit profile is explicit')
 intl:Destroy();vm:Destroy()
end
