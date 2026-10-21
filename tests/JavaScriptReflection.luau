--!strict
return function(VM: any,Reflection: any,fixtures: any)
 for _,fixture in fixtures do
  local values={};local globals={record=function(args)table.insert(values,VM.string(args[1]))end}
  local vm=VM.new(globals,{MaxSteps=100000});local reflection=Reflection.install(vm,globals)
  local ok,message=pcall(function()vm:Run(fixture.source)end)
  assert(ok,fixture.name..': '..tostring(message))
  assert(#values==#fixture.expected,fixture.name..': record count '..#values..' versus '..#fixture.expected)
  for i,want in fixture.expected do assert(values[i]==want,fixture.name..' record '..i..': '..tostring(values[i])..' versus '..want)end
  reflection:Destroy();vm:Destroy()
 end
end
