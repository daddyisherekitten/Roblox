--!strict
return function(Parser,Runtime,Events)
 for _,mode in {'stale result','nil result','destroy before late result'}do
  local handles,requests={},{};local adapter={Alive=true};local runtime;local clock=0;local entered=false
  local function handle()
   local h={Alive=true,DestroyCalls=0,Position=0}
   function h:Destroy()assert(self.Alive,'A native handle is released exactly once');self.Alive=false;self.DestroyCalls+=1 end
   function h:Set()assert(self.Alive)end
   function h:Pause()assert(self.Alive)end
   function h:Reset()assert(self.Alive)end
   function h:Select()assert(self.Alive)end
   function h:Snapshot()return {Position=0}end
   function h:Play()assert(self.Alive)end
   function h:Load(url,raw,generation)assert(self.Alive);table.insert(requests,{Handle=self,Raw=raw,Generation=generation});self.Notify({Kind='loaded',Generation=generation,Duration=5})end
   table.insert(handles,h);return h
  end
  function adapter:Open(node,notify)
   if not entered then
    entered=true
    if mode=='destroy before late result'then runtime:Destroy();local late=handle();late.Notify=notify;return late end
    local old=handle();old.Notify=notify
    runtime.DOM.Attribute(node,'controls','');runtime.DOM.Attribute(node,'src','new.wav')
    if mode=='nil result'then old:Destroy();return nil end
    return old
   end
   local current=handle();current.Notify=notify;return current
  end
  function adapter:Destroy()if not self.Alive then return end;self.Alive=false;for _,h in handles do if h.Alive then h:Destroy()end end end
  local events=Events.new(error)
  runtime=Runtime.new(Parser.parseDocument('<audio id=m></audio>'),{URL='https://open.test/index.html',Events=events,AudioAdapter=adapter,Clock=function()return clock end,Schedule=function()end,ApplyChanges=function()return false end})
  local ok,message=runtime:Run('var m=document.getElementById("m");m.src="old.wav"');assert(ok,tostring(message))
  if mode=='destroy before late result'then
   assert(not runtime.Alive and #handles==1 and handles[1].DestroyCalls==1 and #requests==0,'Late handle after Open disposal is released, never installed or loaded')
  else
   for _=1,8 do clock+=.01;runtime:PumpTasks();runtime.EventLoop:Checkpoint()end
   local node=runtime.DOM.Unwrap(runtime.Window.Get('m'));local state=node.AudioResourceState
   assert(#handles==2 and handles[1].DestroyCalls==1 and state.Handle==handles[2]and handles[2].Alive,'Reentrant Open retains newest handle and releases the stale result once')
   assert(#requests==1 and requests[1].Raw=='new.wav'and requests[1].Handle==handles[2],'Only newest selection reaches native IO after Open reentry')
   ok,message=runtime:Run('window.clean=m.error===null;window.selected=m.currentSrc');assert(ok,tostring(message))
   assert(runtime.Window.Get('clean')==true and runtime.Window.Get('selected')=='https://open.test/new.wav','Failed stale Open cannot report a failure against the new generation')
   runtime:Destroy();assert(handles[2].DestroyCalls==1 and handles[1].DestroyCalls==1,'Final adapter disposal preserves exact-once cleanup of both handles')
  end
  events:Destroy();print('MEDIA_SELECTION_OPEN',mode,'handles='..#handles,'requests='..#requests)
 end
 print('MediaSelection Open: three actual Runtime/DOM injected handle reentry controls passed')
end
