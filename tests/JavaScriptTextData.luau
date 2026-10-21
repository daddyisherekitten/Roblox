--!strict
return function(VM: any,Intl: any,fixtures: any)
 local records=0
 for _,fixture in fixtures do
  local values={};local globals={record=function(args)values[#values+1]=VM.string(args[1])end}
  local options=table.clone(fixture.options or {});options.MaxSteps=1000000
  local vm=VM.new(globals,options);local intl=Intl.install(vm,globals,options)
  local ok,err=pcall(function()vm:Run(fixture.source)end)
  assert(ok,fixture.name..': '..tostring(err))
  assert(#values==#fixture.expected,fixture.name..': record count '..#values..' vs '..#fixture.expected)
  for i,want in fixture.expected do assert(values[i]==want,fixture.name..' record '..i..': '..tostring(values[i])..' versus '..want);records+=1 end
 intl:Destroy();vm:Destroy()
 end
 local budget={};local vm=VM.new({record=function(args)budget[#budget+1]=VM.string(args[1])end},{MaxSteps=1000000})
 vm:Run("for(const value of ['\\ufdfa'.repeat(16384),'\\u0149'.repeat(30000)]){try{value.normalize('NFKD');record('missing budget error')}catch(error){record(error.name)}}")
 assert(#budget==2 and budget[1]=='RangeError'and budget[2]=='RangeError','Normalization intermediate and output budgets are catchable')
 vm:Destroy()
 print(`JavaScriptTextData passed ({#fixtures} native groups, {records} records)`)
end
