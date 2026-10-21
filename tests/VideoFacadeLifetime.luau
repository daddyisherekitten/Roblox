--!strict
-- Prepared compact facade-owned controls, not whole VM/Page GC evidence.
return function(Node,VideoElements,VideoState)
 local ids={"Inline Finish then scheduler false","Inline Finish then scheduler throw nil","Inline Finish then scheduler throw false","Inline Finish then scheduler throw table","Live facade weak Node cache","Explicit Destroy releases subscription and pending token"}
 local seen={};for _,id in ids do assert(seen[id]==nil,id);seen[id]=false end
 local function mark(id)assert(seen[id]==false,id);seen[id]=true end
 local function fixture(queue)
  local caps={};local counts={Settled=0,Dropped=0,Abort=0};local serial=0
  local origin={Alive=true,QueueTask=queue}
  origin.Create=function()serial+=1;caps[serial]={};return {},serial end
  origin.Settle=function(tokens,name)assert(type(tokens)=='table');for _,token in tokens do assert(caps[token]~=nil,'Token settles exactly once');caps[token]=nil;counts.Settled+=1;if name=='AbortError'then counts.Abort+=1 end end end
  origin.Drop=function(tokens)assert(type(tokens)=='table','Drop must never receive nil');counts.Dropped+=1;for _,token in tokens do caps[token]=nil end end
  local vm={Alive=true,Model={Undefined={},Null={},truth=function(value)return value~=false and value~=nil end}}
  local adapter={Bind=function(_,_,state)state.Backend={Test=true}end,Command=function(_,_,state,kind)if kind=='play'then state.Paused=false end end}
  local facade=VideoElements.install(vm,{Origin=origin,Adapter=adapter,Events={DOMException=function(_,message,name)return{Name=name,Message=message}end}})
  return facade,origin,caps,counts
 end
 for _,kind in {'returnfalse','nil','false','table'}do
  local payload=if kind=='false'then false elseif kind=='table'then{Original=true}else nil
  local calls=0
  local facade,_,caps,counts=fixture(function(finish)
   calls+=1;finish()
   if kind=='returnfalse'then return false end
   error(payload,0)
  end)
  local node=Node.element('video',{});local state=VideoState.ensure(node)
  local promise=facade:Get(node,'play')();assert(promise~=nil and next(caps)~=nil)
  local result=table.pack(pcall(VideoState.notify,state,'pause'))
  if kind=='returnfalse'then assert(result[1]==true,'Synchronous consumed settlement permits decline')
  else assert(result[1]==false and result[2]==payload,'Exact first original scheduler payload')end
  assert(calls==1 and counts.Settled==1 and counts.Abort==1 and counts.Dropped==0 and next(caps)==nil,'Consumed entry is never dropped twice')
  assert(#facade.Ensure(node).Plays==0,'No token retained after finish')
  facade:Destroy();assert(next(state.Subscribers)==nil)
  mark(if kind=='returnfalse'then ids[1]elseif kind=='nil'then ids[2]elseif kind=='false'then ids[3]else ids[4])
 end
 do
  local facade=fixture(function()return true end);local weak=setmetatable({},{__mode='v'})
  local function create()
   local node=Node.element('video',{});local state=VideoState.ensure(node);local record=facade.Ensure(node)
   weak.Node=node;weak.State=state;weak.Record=record;weak.Plain={Independent=true}
   assert(record.Node==nil,'No value-to-weak-key backlink')
   -- This control is cache-owned only: no backend Item/Node or VM wrapper.
   state.Backend=nil
  end
  local function pressureFrame()
   for _=1,8 do local temporary=table.create(2048);for index=1,2048 do temporary[index]={index,index+1}end end
  end
  create()
  for _=1,16 do pressureFrame();if weak.Plain==nil and weak.Node==nil and weak.State==nil and weak.Record==nil then break end end
  assert(weak.Plain==nil,'Independent plain control collects in same bounded pressure')
  assert(weak.Node==nil and weak.State==nil and weak.Record==nil,'Alive facade must not retain cache-only detached node graph')
  assert(facade.Alive==true,'Weak collection happened before facade disposal')
  facade:Destroy();mark(ids[5])
 end
 do
  local facade,_,caps,counts=fixture(function()error('Explicit Destroy does not queue settlement')end)
  local node=Node.element('video',{});local state=VideoState.ensure(node);facade:Get(node,'play')()
  local record=facade.Ensure(node);assert(#record.Plays==1 and next(state.Subscribers)~=nil)
  facade:Destroy();facade:Destroy()
  assert(record.State==nil and record.Cancel==nil and record.Node==nil and #record.Plays==0,'Record references cleared')
  assert(next(state.Subscribers)==nil and next(caps)==nil and counts.Settled==1 and counts.Abort==1,'Subscription removed and pending token rejected once')
  mark(ids[6])
 end
 for _,id in ids do assert(seen[id]==true,'Lost control '..id)end
 print('VideoFacadeLifetime',#ids,'controls')
end
