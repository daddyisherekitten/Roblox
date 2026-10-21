--!strict
return function(VM: any,_JSON: any,fixtures: any)
 for _,fixture in fixtures do
  local values={};local globals={record=function(args)table.insert(values,VM.string(args[1]))end}
  local vm=VM.new(globals,{MaxSteps=300000})
  local ok,message=pcall(function()vm:Run(fixture.source)end)
  local expected=fixture.standardExpected or fixture.browserExpected or fixture.expected
  assert(ok,fixture.name..': '..tostring(message))
  assert(#values==#expected,fixture.name..': record count '..#values..' vs '..#expected..' ('..table.concat(values,' | ')..')')
  for i,want in expected do assert(values[i]==want,fixture.name..' record '..i..': '..tostring(values[i])..' versus '..want)end
  vm:Destroy()
 end
 -- A raw wrapper retains only immutable source, ordinary descriptors and an
 -- internal identity token. Destroying its creating realm leaves no VM root.
 local original=VM.new({},{MaxSteps=300000});local raw
 original:ExecuteHost(function()
  local json=original.Global.Bindings.JSON.Value
  raw=original:Call(original.Get(json,'rawJSON'),{'9007199254740993'},json)
 end)
 original:Destroy();assert(raw.Prototype==VM.Null and raw.Values.rawJSON=='9007199254740993')
 local count=0;local vm=VM.new({foreignRaw=raw,record=function(args)assert(args[1]==true);count+=1 end},{MaxSteps=300000})
 vm:Run("record(JSON.isRawJSON(foreignRaw));record(JSON.stringify(foreignRaw)==='9007199254740993');record(Object.isFrozen(foreignRaw));record(!JSON.isRawJSON(new Proxy(foreignRaw,{})))")
 assert(count==4)
 vm:Run("for(const f of [()=>JSON.parse('1'.repeat(65537)),()=>JSON.rawJSON('1'.repeat(65537)),()=>JSON.stringify('a'.repeat(65535)),()=>JSON.parse('['.repeat(66)+'0'+']'.repeat(66))]){try{f();throw 'missing bound'}catch(e){if(e.name!=='RangeError')throw e}}")
 vm:ExecuteHost(function()
  local json=vm.Global.Bindings.JSON.Value
  local host=setmetatable({},{__index=function()error('isRawJSON must not inspect host properties')end})
  assert(vm:Call(vm.Get(json,'isRawJSON'),{host},json)==false)
 end)
 vm:Destroy()
 local small=VM.new({},{MaxSteps=100});local ok,e=pcall(function()small:Run("JSON.parse(' '.repeat(1000)+'0')")end)
 assert(not ok and tostring(e):find('instruction budget exceeded',1,true));small:Destroy()
 print('Raw JSON: '..#fixtures..' Luau cases plus cross-realm teardown, bounds and budget checks passed.')
end
