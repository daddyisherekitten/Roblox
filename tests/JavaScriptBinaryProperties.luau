--!strict
return function(VM: any,BinaryData: any,fixtures: any)
 for _,fixture in fixtures do
  local values={};local globals={record=function(args)table.insert(values,VM.string(args[1]))end}
  local vm=VM.new(globals,{MaxSteps=300000});local api=vm:Install(function()return BinaryData.install(vm,globals)end)
  local ok,message=pcall(function()vm:Run(fixture.source)end)
  local expected=fixture.standardExpected or fixture.browserExpected or fixture.expected
  assert(ok,fixture.name..': '..tostring(message))
  assert(#values==#expected,fixture.name..': record count '..#values..' vs '..#expected..' ('..table.concat(values,' | ')..')')
  for i,want in expected do assert(values[i]==want,fixture.name..' record '..i..': '..tostring(values[i])..' versus '..want)end
  api:Destroy();vm:Destroy()
 end
 local vm=VM.new({},{MaxSteps=300000});local api=vm:Install(function()return BinaryData.install(vm,{})end)
 vm:Run("const wide=new Uint8Array(16385);try{Reflect.ownKeys(wide);throw 'missing bound'}catch(e){if(e.name!=='RangeError')throw e}")
 local view=vm:ExecuteHost(function()return api:FromBytes('ab')end)
 local backing=view.BinaryState.Backing;assert(vm.ObjectModel.Exotic[view]~=nil)
 api:Destroy();assert(view.BinaryState.Backing==nil and vm.ObjectModel.Exotic[view]==nil)
 assert(backing~=nil);vm:Destroy()
 -- A live realm can hold a view over another realm's buffer when its page
 -- closes. Disposal must detach the released storage, not leave a nil native
 -- buffer behind a still-valid shared brand.
 local foreignGlobals,localGlobals={},{}
 local foreignVM,localVM=VM.new(foreignGlobals),VM.new(localGlobals)
 local foreignAPI=foreignVM:Install(function()return BinaryData.install(foreignVM,foreignGlobals)end)
 local localAPI=localVM:Install(function()return BinaryData.install(localVM,localGlobals)end)
 foreignVM:Run("var source=new ArrayBuffer(2);var original=new DataView(source);original.setUint8(0,7);")
 for _,name in {'source','original'}do localVM.GlobalEnvironment:Write(name,foreignVM.GlobalEnvironment:Read(name),true)end
 localVM:Run("const retained=new Uint8Array(source);if(retained[0]!==7||DataView.prototype.getUint8.call(original,0)!==7)throw Error('Foreign data unavailable');")
 foreignAPI:Destroy();foreignVM:Destroy()
 localVM:Run("if(retained.length!==0||retained[0]!==undefined)throw Error('Released data remains live');for(const read of [()=>retained.at(0),()=>DataView.prototype.getUint8.call(original,0)]){try{read();throw Error('Accepted disposed data')}catch(error){if(!(error instanceof TypeError))throw error}}")
 localAPI:Destroy();localVM:Destroy()
 print('TypedArray properties: '..#fixtures..' Luau cases plus enumeration bound and teardown checks passed.')
end
