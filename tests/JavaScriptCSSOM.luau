--!strict
return function(Parser,Runtime,VM,Events,fixtures)
 local failures={}
 for _,fixture in fixtures do
  local values,diagnostics={},{}
  local runtime=Runtime.new(Parser.parseDocument('<html><head></head><body></body></html>'),{Events=Events.new(error),URL='https://example.test/cssom',Console=function(_,s)table.insert(values,s)end,Diagnostic=function(s)table.insert(diagnostics,s)end})
  runtime:Run('function record(value){console.log(String(value));}\n'..(if fixture.async then '(async()=>{ '..fixture.source..' })();'else fixture.source));runtime:PumpTasks()
  if #diagnostics>0 or #values~=#fixture.expected then table.insert(failures,fixture.name..': '..table.concat(diagnostics,' / ')..' actual='..table.concat(values,' | '))
  else for i,item in values do if item~=fixture.expected[i]then table.insert(failures,fixture.name..' ['..i..']: '..item..' ~= '..fixture.expected[i])end end end
  runtime:Destroy()
 end
 for _,failure in failures do print('CSSOM mismatch: '..failure)end
 assert(#failures==0,'CSSOM fixture failures: '..#failures)
 print('JavaScript CSSOM: '..#fixtures..' semantics fixtures passed')
 local document=Parser.parseDocument('<html><head><style id="a">.a { color:red }</style><style id="b">.b { color:blue }</style></head><body></body></html>')
 local rawA=document.Children[1].Children[1].Children[1];local rawB=document.Children[1].Children[1].Children[2]
 local sourceCalls,changedCalls=0,0;local adapter={}
 function adapter:Sources()sourceCalls+=1;return{{Node=rawA,Source=rawA.Children[1].Text,Media='screen'},{Node=rawB,Source=rawB.Children[1].Text,Media=''}}end
 function adapter:SetProvider(provider)self.Provider=provider end
 function adapter:Changed()changedCalls+=1 end
 function adapter:Destroy()self.Destroyed=true end
 local diagnostics={};local runtime=Runtime.new(document,{Events=Events.new(error),CSSOMAdapter=adapter,Diagnostic=function(s)table.insert(diagnostics,s)end})
 runtime:Run('const sheets=document.styleSheets,a=sheets[0],b=sheets[1];a.insertRule(".x {color:green}",1);const heldRule=a.cssRules[1],heldStyle=heldRule.style;')
 assert(#diagnostics==0 and changedCalls==1)
 local api=runtime.CSSOM
 local before=sourceCalls
 runtime.VM:Install(function()for _=1,10 do assert(api:RenderSource(rawA));api:RenderSource(rawB);api:RenderAdopted(document)end end)
 assert(sourceCalls==before,'Projection compiles all source overlays from one cached DOM source snapshot')
 runtime:Run('document.getElementById("a").firstChild.data=".a { color:red }";')
 assert(changedCalls==2,'A same-value source mutation invalidates CSSOM overlay paint even without a DOM geometry change')
 runtime:Run('if(document.getElementById("a").sheet===a||a.ownerNode!==null)throw new Error("sheet reassociation");const current=document.getElementById("a").sheet;')
 assert(#diagnostics==0 and sourceCalls==before+1)
 local vm=runtime.VM;local ctor=vm.Global.Bindings.CSSStyleSheet.Value;local weak=setmetatable({},{__mode='k'})
 runtime:Run('const budgetSheet=new CSSStyleSheet();budgetSheet.replaceSync(".original { color:red }");')
 local budgetSheet=vm.Global.Bindings.budgetSheet.Value
 local replaceSync=vm.Get(budgetSheet,'replaceSync');local original=vm.Get(vm.Get(budgetSheet,'cssRules'),'0')
 for _,source in {string.rep(' ',1048577),string.rep('.x{}',4097),string.rep('@media all {',33)..'.x{}'..string.rep('}',33)}do
  local success,message=pcall(function()vm:Call(replaceSync,{source},budgetSheet)end)
  assert(not success and VM.exceptionValue(message).ErrorName=='RangeError','CSSOM source, rule and nesting budgets reject explicitly')
  assert(vm.Get(vm.Get(budgetSheet,'cssRules'),'0')==original,'Failed replacement preserves the original rule identity')
 end
 vm.Global.Bindings.oversizedCSS={Value=string.rep(' ',1048577)}
 runtime:Run('budgetSheet.replace(oversizedCSS).catch(e=>{if(e.name!=="RangeError")throw e;});')
 runtime:PumpTasks()
 assert(vm.Get(vm.Get(budgetSheet,'cssRules'),'0')==original and #diagnostics==0,'Async replacement rejects source limit without replacing existing rules')
 vm.Global.Bindings.oversizedCSS=nil
 local function transientSheet()local value=vm:Construct(ctor,{});weak[value]=true;weak[vm.Get(value,'media')]=true;weak[vm.Get(value,'cssRules')]=true end
 vm:Install(transientSheet)
 vm:Run('0;')
 -- The semantic realms leave a large heap for Luau's incremental collector;
 -- enough allocation pressure completes cycles without a host GC API.
 local function collected()return next(weak)==nil end
 local function collectTransient()
  for batch=1,1024 do
   if batch%32==0 and collected()then break end
   local garbage=table.create(2048);for i=1,2048 do garbage[i]={i,i+1}end
  end
  assert(collected(),'Constructed sheets, list wrappers and media do not retain one another through weak registries')
 end
 collectTransient()
 -- Exercise more transient allocations than the retained cap while allowing
 -- Luau's collector to reclaim each independent batch.
 for batch=1,128 do
  runtime:Run('for(let i=0;i<48;i++){new CSSStyleSheet()}')
  local garbage=table.create(2048);for i=1,2048 do garbage[i]={i,batch}end
  -- Require a real completed collection periodically, instead of assuming a
  -- fixed amount of allocation completes one on every possible host heap.
  if batch%16==0 then vm:Install(transientSheet);vm:Run('0;');collectTransient()end
 end
 assert(#diagnostics==0,'Unused constructed sheets release retained capacity')
 local held=vm.Global.Bindings.heldRule.Value;local declaration=vm.Global.Bindings.heldStyle.Value;local current=vm.Global.Bindings.current.Value;local insert=vm.Get(current,'insertRule');local set=vm.Get(declaration,'setProperty');local adoptedList=api:DocumentGet(document,'adoptedStyleSheets')
 runtime:Destroy()
 assert(adapter.Destroyed and not api.Alive and held.CSSOMBrand and held.CSSOMState==nil and declaration.CSSDeclarationState==nil)
 assert(vm.ObjectModel.Exotic[adoptedList]==nil,'Disposed adopted array releases its private handler')
 assert(not pcall(function()vm:Call(insert,{'.z{}'},current)end),'Disposed branded CSSOM methods reject')
 assert(not pcall(function()vm:Call(set,{'color','red'},declaration)end),'Disposed shared declaration methods reject')
 print('CSSOM lifecycle: source batching, source-only invalidation, association replacement, transient GC capacity and disposal passed')
end
