--!strict
return function(VM: any, StandardLibrary: any, fixtures: any)
 for _,fixture in fixtures do
  local values={};local globals={record=function(args)table.insert(values,VM.string(args[1]))end}
  local vm=VM.new(globals,{MaxSteps=100000});StandardLibrary.install(vm,globals,{VM=VM,DateNow=function()return 1704067200000 end})
  local ok,message=pcall(function()vm:Run(fixture.source)end)
  assert(ok,fixture.name..': '..tostring(message))
  assert(#values==#fixture.expected,fixture.name..': record count '..tostring(#values)..' versus '..tostring(#fixture.expected))
  for index,expected in fixture.expected do assert(values[index]==expected,fixture.name..' record '..tostring(index)..': '..tostring(values[index])..' versus '..expected)end
  vm:Destroy()
 end
 local values={};local globals={record=function(args)table.insert(values,args[1])end};local vm=VM.new(globals,{MaxSteps=100000})
 StandardLibrary.install(vm,globals,{VM=VM})
 vm:Run([[try { new Array(20000); } catch(e) { record(e.name); } try { 'x'.repeat(70000); } catch(e) { record(e.name); }]])
 assert(values[1]=='RangeError'and values[2]=='RangeError','Resource limits are catchable RangeErrors')
 vm:Run([[record([1,2].with(0,9).join(','));record([1,2].join(','));]])
 assert(values[3]=='9,2'and values[4]=='1,2','Copying operations keep source arrays unchanged')
 vm:Destroy()
 local firstValues={};local first=VM.new({record=function(args)table.insert(firstValues,args[1])end})
 first:Run([[record(Symbol.for('cross-realm-library'));record(Symbol.iterator);]])
 first:Destroy()
 local secondValues={};local second=VM.new({record=function(args)table.insert(secondValues,args[1])end})
 second:Run([[record(Symbol.for('cross-realm-library'));record(Symbol.iterator);record(Symbol.for('cross-realm-library').description);record(Symbol.iterator.toString());]])
 assert(firstValues[1]==secondValues[1]and firstValues[2]==secondValues[2],'Registered and well-known symbols retain agent-wide identities')
 assert(secondValues[3]=='cross-realm-library'and secondValues[4]=='Symbol(Symbol.iterator)','Symbol property lookup uses the living realm')
 second:Destroy()
end
