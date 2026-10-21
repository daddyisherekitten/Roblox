--!strict
-- Every still-current subscriber runs despite first injected hook failure.
return function(Node,VideoElements,VideoState)
 local ids={"Notify every subscriber before nil rethrow","Notify every subscriber before false rethrow","Notify every subscriber before table rethrow"}
 local cases,checks=0,0;local function check(value,message)checks+=1;assert(value,message)end
 for index,kind in {"nil","false","table"}do
  local payload=if kind=="false"then false elseif kind=="table"then{Original=ids[index]}else nil
  local state=VideoState.ensure(Node.element("video",{}));local calls={0,0,0};local cancels={}
  for at=1,3 do table.insert(cancels,VideoState.subscribe(state,function(event,current)
   check(event=="removed"and current==state,"Original notification arguments")
   calls[at]+=1;if at<3 then error(payload,0)end
  end))end
  local result=table.pack(pcall(VideoState.notify,state,"removed"))
  check(result[1]==false and result[2]==payload,"Exact first original nil/false/table payload")
  check(calls[1]==1 and calls[2]==1 and calls[3]==1,"Both failing and successful subscribers run once before rethrow")
  for _,cancel in cancels do cancel()end
  check(next(state.Subscribers)==nil,"Caller cancellation releases all subscriber slots")
  cases+=1;print("VIDEO_NOTIFY_ALL_CONTROL",ids[index])
 end
 check(cases==3,"Exact three literal notification controls")
 print("VIDEO_NOTIFY_ALL_SUMMARY","cases="..cases,"assertions="..checks)
end
