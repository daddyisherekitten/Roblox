--!strict
return function(VM: any,Storage: any,Navigation: any,HostEvents: any,Clone: any,fixtures: any)
 for _,fixture in fixtures do
  local output={};local globals={record=function(args)table.insert(output,VM.string(args[1]))end};local vm=VM.new(globals,{MaxSteps=100000});local tasks={}
  local window=vm.Object({});globals.window=window;vm.Global.Bindings.window={Value=window}
  local events=HostEvents.install(vm,globals,{Clock=function()return 0 end});events:WrapTarget(window,{Handlers=true})
  local clone=Clone.install(vm,globals,{HostEvents=events});local navigation=Navigation.install(vm,globals,{URL='http://127.0.0.1:8767/fixture',Window=window,Events=events,Clone=clone,QueueTask=function(fn)table.insert(tasks,fn)end})
  local localArea,sessionArea=Storage.createArea(),Storage.createArea();local storage=Storage.install(vm,globals,{Events=events,Window=window,QueueTask=function(fn)table.insert(tasks,fn)end,GetURL=function()return navigation:GetURL()end,GetArea=function(kind)return if kind=='local'then localArea else sessionArea end})
  local oldGet=window.Get;window.Get=function(key)local binding=vm.Global.Bindings[key];return if binding then(if binding.Get then binding.Get()else binding.Value)else oldGet(key)end
  local peerVM,peerStorage,peerEvents
  if fixture.peer then
   peerVM=VM.new({});local peerGlobals={};local peerWindow=peerVM.Object({});peerEvents=HostEvents.install(peerVM,peerGlobals,{Clock=function()return 0 end});peerEvents:WrapTarget(peerWindow,{Handlers=true})
   peerStorage=Storage.install(peerVM,peerGlobals,{Events=peerEvents,Window=peerWindow,QueueTask=function(fn)table.insert(tasks,fn)end,GetURL=function()return 'http://127.0.0.1:8767/fixture' end,GetArea=function(kind)return if kind=='local'then localArea else sessionArea end})
   local peerTarget=peerStorage:Get('local');vm.Global.Bindings.changePeerStorage={Value=function(args)return peerVM:Call(peerVM.Get(peerTarget,'setItem'),args,peerTarget)end}
  end
  globals.pumpEvents=function()while #tasks>0 do local current=table.clone(tasks);table.clear(tasks);for _,fn in current do fn()end end end;vm.Global.Bindings.pumpEvents={Value=globals.pumpEvents}
  local ok,message=pcall(function()vm:Run(fixture.source)end);assert(ok,fixture.name..': '..tostring(message))
  assert(#output==#fixture.expected,fixture.name..': record count '..#output..' versus '..#fixture.expected)
  for i,value in fixture.expected do assert(output[i]==value,fixture.name..' record '..i..': '..tostring(output[i])..' versus '..value)end
  if peerStorage then peerStorage:Destroy();peerEvents:Destroy();peerVM:Destroy()end
  storage:Destroy();navigation:Destroy();clone:Destroy();events:Destroy();vm:Destroy()
 end
 -- Sharing, no-op events, quota atomicity and disposal are host-profile assertions.
 local area=Storage.createArea({QuotaBytes=12});local tasks={};local peers={}
 for i=1,2 do
  local vm=VM.new({});local globals={};local window=vm.Object({});local events=HostEvents.install(vm,globals,{Clock=function()return 0 end});events:WrapTarget(window,{Handlers=true})
  local sessionArea=Storage.createArea()
  local storage=Storage.install(vm,globals,{Events=events,Window=window,QueueTask=function(fn)table.insert(tasks,fn)end,GetURL=function()return 'https://example.test/'..i end,GetArea=function(kind)return if kind=='local'then area else sessionArea end})
  local target=storage:Get('local');local seen={};vm:Call(vm.Get(window,'addEventListener'),{'storage',function(args)local e=args[1];table.insert(seen,{vm.Get(e,'key'),vm.Get(e,'oldValue'),vm.Get(e,'newValue'),vm.Get(e,'url'),vm.Get(e,'storageArea'),vm.Get(e,'isTrusted')})end},window)
  table.insert(peers,{VM=vm,Storage=storage,Events=events,Target=target,Seen=seen})
 end
 local function call(peer,name,args)return peer.VM:Call(peer.VM.Get(peer.Target,name),args,peer.Target)end
 call(peers[1],'setItem',{'a','one'});assert(#tasks==1 and #peers[1].Seen==0 and #peers[2].Seen==0)
 call(peers[1],'setItem',{'a','one'});assert(#tasks==1,'No-op writes must not broadcast')
 local ok,err=pcall(call,peers[1],'setItem',{'b','long'});assert(not ok and peers[1].VM.Get(VM.exceptionValue(err),'name')=='QuotaExceededError');assert(area.Values.b==nil and area.Values.a=='one')
 for _,fn in tasks do fn()end;table.clear(tasks);local seen=peers[2].Seen[1];assert(seen[1]=='a'and seen[2]==VM.Null and seen[3]=='one'and seen[4]=='https://example.test/1'and seen[5]==peers[2].Target and seen[6])
 peers[2].Storage:Destroy();call(peers[1],'removeItem',{'a'});assert(#tasks==0 and #area.Subscribers==1)
 for _,peer in peers do peer.Storage:Destroy();peer.Events:Destroy();peer.VM:Destroy()end;assert(#area.Subscribers==0)
 local vm=VM.new({});local globals={};local events=HostEvents.install(vm,globals,{Clock=function()return 0 end});local window=vm.Object({});events:WrapTarget(window,{Handlers=true});local clone=Clone.install(vm,globals,{HostEvents=events})
 local storage=Storage.install(vm,globals,{Events=events,Window=window,GetArea=function()return nil end})
 local ok,err=pcall(function()return storage:Get('local')end);assert(not ok and vm.Get(VM.exceptionValue(err),'name')=='SecurityError')
 local requests={};local navigation=Navigation.install(vm,globals,{URL='https://example.test/start',Window=window,Events=events,Clone=clone,QueueTask=function(fn)table.insert(tasks,fn)end,Navigate=function(request)table.insert(requests,request);return true end})
 vm:Run("location.assign('/next');history.go(0)");assert(#requests==2 and requests[1].URL=='https://example.test/next'and requests[2].Kind=='reload');assert(navigation:GetURL()=='https://example.test/start','Accepted host requests must not invent completed navigation')
 navigation:CommitNavigation('https://example.test/next',false);assert(navigation:GetURL()=='https://example.test/next')
 navigation:Destroy();storage:Destroy();clone:Destroy();events:Destroy();vm:Destroy()
end
