--!strict
return function(VM: any,IteratorHelpers: any,fixtures: any)
 for _,fixture in fixtures do
  local values={};local globals={record=function(args)table.insert(values,VM.string(args[1]))end}
  local vm=VM.new(globals,{MaxSteps=300000});local api=vm.IteratorHelpers or vm:Install(function()return IteratorHelpers.install(vm,globals)end)
  local ok,message=pcall(function()vm:Run(fixture.source)end)
  local expected=fixture.standardExpected or fixture.browserExpected or fixture.expected
  assert(ok,fixture.name..': '..tostring(message))
  assert(#values==#expected,fixture.name..': record count '..#values..' vs '..#expected..' ('..table.concat(values,' | ')..')')
  for i,want in expected do assert(values[i]==want,fixture.name..' record '..i..': '..tostring(values[i])..' versus '..want)end
  api:Destroy();vm:Destroy()
 end
 -- Host limits terminate lazy loops, and disposal only releases internal
 -- references: realm teardown must never invent a user iterator return call.
 local vm=VM.new({},{MaxSteps=400});local api=vm.IteratorHelpers or vm:Install(function()return IteratorHelpers.install(vm,{})end)
 local ok,e=pcall(function()vm:Run("Iterator.from({next(){return {value:1,done:false}}}).filter(()=>false).next();")end)
 assert(not ok and tostring(e):find('instruction budget exceeded',1,true))
 local closes=0;local iterator,mapped,native
 vm:ExecuteHost(function()
  local source=vm.Object({next=function()return vm.Object({value=1,done=false})end,['return']=function()closes+=1;return vm.Object({done=true})end})
  iterator=vm:Call(vm.Get(api.Constructor,'from'),{source},api.Constructor)
  mapped=vm:Call(vm.Get(iterator,'map'),{function(args)return args[1]end},iterator)
  native=vm:Call(vm.Get(vm.Array({1}),'values'),{},vm.Array({1}))
 end)
 api:Destroy();assert(closes==0)
 assert(mapped.IteratorHelperState.Source==nil and iterator.IteratorHelperState.Source==nil and native.NativeIteratorState.Advance==nil)
 vm:Destroy()
 print('Iterator helpers: '..#fixtures..' Luau cases plus lazy-loop budget and teardown checks passed.')
end
