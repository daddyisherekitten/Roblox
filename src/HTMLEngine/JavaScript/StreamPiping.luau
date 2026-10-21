--!strict
local StreamPiping={}
function StreamPiping.install(vm: any,globals: any,options: any,readable: any,writable: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true};local active={}
 local function errorValue(message)return VM.error("TypeError",message)end
 local function fail(message)VM.throw(errorValue(message))end
 local function field(value,key)return if value==U or value==N or value==nil then U else vm.Get(value,key)end
 local function call(value,key,args)return vm:Call(vm.Get(value,key),args or {},value)end
 local function pipe(source,destination,settings,throwEarly)
  local p,resolve,rejectPromise=options.CreatePromise();local state={Done=false,Stopping=false,Writing=false,SourceDone=false}
  local reader,writer,signal;local preventClose,preventAbort,preventCancel=false,false,false
  local finish,shutdown,requestStop,nextChunk
  finish=function(failed,reason)
   if not api.Alive or state.Done then return end;state.Done=true;active[state]=nil
   if state.Unsubscribe then state.Unsubscribe();state.Unsubscribe=nil end
   if reader then pcall(call,reader,"releaseLock")end;if writer then pcall(call,writer,"releaseLock")end
   if failed then rejectPromise({reason})else resolve({U})end
  end
  shutdown=function()
   if state.Done or not api.Alive or state.Writing then return end
   local plan=state.Plan;local remaining=0;local failed,reason=plan.Failed,plan.Reason
   local actions={}
   if plan.Close and not preventClose then table.insert(actions,function()return call(writer,"close")end)end
   if plan.Abort and not preventAbort then table.insert(actions,function()return call(writer,"abort",{plan.Reason})end)end
   if plan.Cancel and not preventCancel then table.insert(actions,function()return call(reader,"cancel",{plan.Reason})end)end
   remaining=#actions;if remaining==0 then finish(failed,reason);return end
   local function completed()remaining-=1;if remaining==0 then finish(failed,reason)end end
   for _,action in actions do local ok,result=pcall(action)
    if not ok then failed,reason=true,VM.exceptionValue(result);completed()
    else options.Await(result,completed,function(value)failed,reason=true,value;completed()end)end
   end
  end
  requestStop=function(plan)
   if state.Stopping or state.Done or not api.Alive then return end;state.Stopping,state.Plan=true,plan;shutdown()
  end
  nextChunk=function()
   if state.Stopping or state.Done or not api.Alive then return end
   if state.SourceClosed then state.SourceDone=true;requestStop({Close=true,Failed=false,Reason=U});return end
   options.Await(vm.Get(writer,"ready"),function()
    if state.Stopping or state.Done or not api.Alive then return end
    state.Reading=true
    options.Await(call(reader,"read"),function(item)
     if state.Stopping or state.Done or not api.Alive then return end
     state.Reading=false
     if VM.truth(vm.Get(item,"done"))then state.SourceDone=true;requestStop({Close=true,Failed=false,Reason=U});return end
     state.Writing=true
     options.Await(call(writer,"write",{vm.Get(item,"value")}),function()
      if not api.Alive then return end;state.Writing=false;if state.Stopping then shutdown()else nextChunk()end
     end,function(reason)
      if not api.Alive then return end;state.Writing=false;if state.Stopping then shutdown()else requestStop({Cancel=true,Failed=true,Reason=reason})end
     end)
    end,function(reason)state.Reading=false;requestStop({Abort=true,Failed=true,Reason=reason})end)
   end,function(reason)requestStop({Cancel=true,Failed=true,Reason=reason})end)
  end
  local ok,message=pcall(function()
   if not readable:IsStream(source)then fail("pipeTo requires a readable source")end;if not writable:IsStream(destination)then fail("pipeTo requires a writable destination")end
   preventAbort=VM.truth(field(settings,"preventAbort"));preventCancel=VM.truth(field(settings,"preventCancel"));preventClose=VM.truth(field(settings,"preventClose"));signal=field(settings,"signal")
   if readable:IsLocked(source)or writable:IsLocked(destination)then fail("Cannot pipe locked streams")end
   if signal~=U then options.HostEvents:IsAborted(signal)end
   reader,writer=call(source,"getReader"),call(destination,"getWriter")
   active[state]=true
   options.Await(vm.Get(reader,"closed"),function()state.SourceClosed=true;if not state.Reading and not state.Writing then state.SourceDone=true;requestStop({Close=true,Failed=false,Reason=U})end end,function(reason)requestStop({Abort=true,Failed=true,Reason=reason})end)
   options.Await(vm.Get(writer,"closed"),function()if not state.SourceDone then requestStop({Cancel=true,Failed=true,Reason=errorValue("Writable destination closed before the source")})end end,function(reason)requestStop({Cancel=true,Failed=true,Reason=reason})end)
   if signal~=U then
    local function aborted(reason)requestStop({Abort=true,Cancel=true,Failed=true,Reason=reason})end
    if options.HostEvents:IsAborted(signal)then aborted(vm.Get(signal,"reason"))else state.Unsubscribe=options.HostEvents:SubscribeAbort(signal,function()aborted(vm.Get(signal,"reason"))end)end
   end
   nextChunk()
  end)
  if not ok then
   if throwEarly then if reader then pcall(call,reader,"releaseLock")end;if writer then pcall(call,writer,"releaseLock")end;error(message,0)end
   finish(true,VM.exceptionValue(message))
  end
  return p
 end
 local function method(proto,name,n,callback)
  local fn={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)assert(api.Alive and vm.Alive,"JavaScript stream piping disposed");return callback(args,receiver)end}
  vm.DefineProperty(fn,"length",vm.Object({value=n,configurable=true},VM.Null));vm.DefineProperty(fn,"name",vm.Object({value=name,configurable=true},VM.Null))
  vm.DefineProperty(proto,name,vm.Object({value=fn,writable=true,enumerable=true,configurable=true},VM.Null));return fn
 end
 local proto=vm.Get(globals.ReadableStream,"prototype")
 method(proto,"pipeTo",1,function(args,source)return pipe(source,if args[1]==nil then U else args[1],args[2],false)end)
 method(proto,"pipeThrough",1,function(args,source)
  local pair=if args[1]==nil then U else args[1];local target=field(pair,"readable");local destination=field(pair,"writable")
  if not readable:IsStream(target)then fail("pipeThrough requires a readable/writable pair")end
  local p=pipe(source,destination,args[2],true);options.Await(p,function()end,function()end);return target
 end)
 -- Async iterator requests are serialized, including return() while a read is
 -- outstanding. The iterator owns its reader until done/cancel/release.
 local function iterator(source,settings)
  local reader=call(source,"getReader");local prevent=VM.truth(field(settings,"preventCancel"));local done=false;local tail
  local iterator=vm.Object({},vm.Prototypes.AsyncIterator or vm.Prototypes.Object);iterator.Kind="iterator"
  local function result(value,finished)return vm.Object({value=value,done=finished})end
  local function serialized(returning,value)
   local p,resolve,rejectPromise=options.CreatePromise();local previous=tail;tail=p
   local function work()
    if not api.Alive then return end
    if done then resolve({result(if returning then value else U,true)});return end
    local function failed(reason)done=true;pcall(call,reader,"releaseLock");rejectPromise({reason})end
    if returning then
     done=true
     if prevent then call(reader,"releaseLock");resolve({result(value,true)})
     else options.Await(call(reader,"cancel",{value}),function()call(reader,"releaseLock");resolve({result(value,true)})end,failed)end
    else options.Await(call(reader,"read"),function(item)if VM.truth(vm.Get(item,"done"))then done=true;call(reader,"releaseLock")end;resolve({item})end,failed)end
   end
   if previous then options.Await(previous,work,work)else work()end;return p
  end
  method(iterator,"next",0,function()return serialized(false,U)end)
  method(iterator,"return",1,function(args)return serialized(true,if args[1]==nil then U else args[1])end)
  local identity={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(_,value)return value end}
  vm.DefineProperty(iterator,vm.SymbolAsyncIterator,vm.Object({value=identity,writable=true,configurable=true},VM.Null));return iterator
 end
 local values=method(proto,"values",0,function(args,source)return iterator(source,args[1])end)
 vm.DefineProperty(proto,vm.SymbolAsyncIterator,vm.Object({value=values,writable=true,configurable=true},VM.Null))
 function api:Destroy()self.Alive=false;for state in active do if state.Unsubscribe then state.Unsubscribe()end;state.Done=true end;table.clear(active)end
 return api
end
return StreamPiping
