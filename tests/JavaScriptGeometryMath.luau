--!strict
return function(VM,Geometry,HostEvents,Binary,fixtures,StructuredClone)
 for _,fixture in fixtures do
  local values={};local globals={record=function(args)table.insert(values,VM.string(args[1]))end}
  local vm=VM.new(globals,{MaxSteps=100000})
  local events=vm:Install(function()return HostEvents.install(vm,globals,{})end)
  local binary=vm:Install(function()return Binary.install(vm,globals,{})end)
  local geometry=vm:Install(function()return Geometry.install(vm,globals,{Events=events,Binary=binary})end)
  local clone=vm:Install(function()return StructuredClone.install(vm,globals,{HostEvents=events,Binary=binary})end);clone.Geometry=geometry
  local ok,message=pcall(vm.Run,vm,fixture.source)
  assert(ok,fixture.name..': '..tostring(message))
  assert(#values==#fixture.expected,fixture.name..': result count '..#values..' / '..#fixture.expected..' : '..table.concat(values,' | '))
  for i,expected in fixture.expected do assert(values[i]==expected,fixture.name..' ['..i..']: '..tostring(values[i])..' / '..expected)end
  clone:Destroy();geometry:Destroy();binary:Destroy();events:Destroy();vm:Destroy()
 end
 local function realm(limit)
  local globals={};local vm=VM.new(globals,{MaxSteps=100000})
  local events=vm:Install(function()return HostEvents.install(vm,globals,{})end)
  local binary=vm:Install(function()return Binary.install(vm,globals,{})end)
  local geometry=vm:Install(function()return Geometry.install(vm,globals,{Events=events,Binary=binary})end)
  local clone=vm:Install(function()return StructuredClone.install(vm,globals,{HostEvents=events,Binary=binary,MaxBytes=limit})end);clone.Geometry=geometry
  return {VM=vm,Globals=globals,Events=events,Binary=binary,Geometry=geometry,Clone=clone,Destroy=function()clone:Destroy();geometry:Destroy();binary:Destroy();events:Destroy();vm:Destroy()end}
 end
 local source,target=realm(nil),realm(nil)
 source.VM:Run('globalThis.graph={q:new DOMQuad({x:9}),p:null,m:new DOMMatrix([2,0,0,3,4,5])};graph.p=graph.q.p1;graph.again=graph.q;')
 local wire=source.Clone:Serialize(source.VM.Get(source.Globals.globalThis,'graph'))
 local received=target.Clone:Deserialize(wire);target.VM.Global.Bindings.received={Value=received}
 target.VM:Run('if(!(received.q instanceof DOMQuad)||!(received.p instanceof DOMPoint)||!(received.m instanceof DOMMatrix)||received.q.p1!==received.p||received.q!==received.again)throw new Error("Cross-realm geometry identity");received.p.x=11;')
 source.VM:Run('if(graph.p.x!==9)throw new Error("Cross-realm clone aliases source");')
 local unsupported=StructuredClone.install(target.VM,{}, {HostEvents=target.Events,Binary=target.Binary})
 local supported,message=pcall(unsupported.Deserialize,unsupported,wire)
 assert(not supported and target.VM.Get(VM.exceptionValue(message),'name')=='DataCloneError','Unconfigured receiver must reject geometry records')
 unsupported:Destroy();source.Destroy();target.Destroy()
 local small=realm(160)
 small.VM:Run('structuredClone(new DOMPoint());structuredClone(new DOMMatrix());for(const value of [new DOMQuad(),new DOMMatrix(new Array(16).fill(0)),new Map([[1,2],[3,4],[5,6]]),new Set([1,2,3,4,5]),[true,null,undefined,1,2,3]]){let rejected=false;try{structuredClone(value)}catch(e){rejected=e.name==="DataCloneError"}if(!rejected)throw new Error("Clone payload storage was not charged")}const b=new ArrayBuffer(4);try{structuredClone({q:new DOMQuad(),b},{transfer:[b]})}catch(e){if(e.name!=="DataCloneError")throw e}if(b.byteLength!==4)throw new Error("Failed geometry clone detached transfer");')
 small.Destroy()
 print('Geometry clone: target-realm brands, graph identity, payload budgets and atomic transfer failure pass')
end
