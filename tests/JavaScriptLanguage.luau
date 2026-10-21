--!strict
return function(VM: any,_library: any,fixtures: any,BinaryData: any?)
 for _,fixture in fixtures do
  local records={}
  local globals={record=function(args)table.insert(records,VM.string(args[1]))end}
  local other
  if fixture.realmSource then
   local otherGlobals={record=globals.record};other=VM.new(otherGlobals,{MaxSteps=50000})
   if fixture.binary then BinaryData.install(other,otherGlobals)end
   other:Run(fixture.realmSource)
   local otherGlobal=other.GlobalEnvironment:Read('globalThis')
   for _,key in fixture.realmExports do globals[key]=other.Get(otherGlobal,key)end
  end
  local vm=VM.new(globals,{MaxSteps=50000})
  if fixture.binary then BinaryData.install(vm,globals)end
  for _,entry in fixture.steps or {{source=fixture.source}}do
   local ok,message=pcall(function()vm:Run(entry.source)end)
   if entry.error then assert(not ok and VM.exceptionValue(message).ErrorName==entry.error,fixture.name..': expected '..entry.error..', got '..tostring(message))
   else assert(ok,fixture.name..': '..tostring(message))end
  end
  assert(#records==#fixture.expected,fixture.name..': record count '..#records..' versus '..#fixture.expected)
  for i,value in records do assert(value==fixture.expected[i],fixture.name..' record '..i..': '..value..' versus '..fixture.expected[i])end
  vm:Destroy()
  if other then other:Destroy()end
 end
end
