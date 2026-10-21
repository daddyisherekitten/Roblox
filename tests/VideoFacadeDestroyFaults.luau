--!strict
-- Additive external-settlement teardown controls. No archived six-control body changes.
return function(Node,VideoElements,VideoState)
 local ids={"Destroy settlement throw nil releases every record","Destroy settlement throw false releases every record","Destroy settlement throw table releases every record"}
 local seen={};for _,id in ids do assert(seen[id]==nil);seen[id]=false end
 local checks=0;local function check(value,message)checks+=1;assert(value,message)end
 for index,kind in {"nil","false","table"}do
  local payload=if kind=="false"then false elseif kind=="table"then{First=true}else nil
  local caps,queued={},{};local serial,settles,drops=0,0,0
  local origin={Alive=true}
  origin.Create=function()serial+=1;caps[serial]=true;return{},serial end
  origin.QueueTask=function(callback)table.insert(queued,callback);return true end
  origin.Settle=function(tokens)
   settles+=1;if settles==1 then error(payload,0)end
   for _,token in tokens do check(caps[token]==true,"No double settlement");caps[token]=nil end
  end
  origin.Drop=function(tokens)check(type(tokens)=="table","Never Drop(nil)");drops+=1;for _,token in tokens do caps[token]=nil end end
  local vm={Alive=true,Model={Undefined={},Null={}}}
  local adapter={Bind=function(_,_,state)state.Backend={Test=true}end,Command=function(_,_,state)state.Paused=false end}
  local facade=VideoElements.install(vm,{Origin=origin,Adapter=adapter,Events={}})
  local records,states={},{}
  for count=1,3 do
   local node=Node.element("video",{});facade:Get(node,"play")()
   records[count]=facade.Ensure(node);states[count]=VideoState.ensure(node)
  end
  VideoState.notify(states[3],"playing");check(#queued==1,"One already queued settlement is owned separately")
  local result=table.pack(pcall(facade.Destroy,facade))
  check(result[1]==false and result[2]==payload,"Exact first nil/false/table payload after all cleanup")
  for _,record in records do check(record.State==nil and record.Cancel==nil and #record.Plays==0,"Every record and token slot retired")end
  for _,state in states do check(next(state.Subscribers)==nil,"Every subscription cancelled despite first error")end
  check(next(caps)==nil and settles==2 and drops==2,"Failed settlement and queued entry released; remaining pending token settles once")
  facade:Destroy();queued[1]();check(next(caps)==nil and settles==2 and drops==2,"Late callback and repeated Destroy are inert")
  check(facade.Alive==false,"Facade remains terminal after external fault")
  seen[ids[index]]=true
 end
 for _,id in ids do check(seen[id]==true,"Lost literal destruction control "..id)end
 print("VideoFacadeDestroyFaults",#ids,"controls",checks,"assertions")
end
