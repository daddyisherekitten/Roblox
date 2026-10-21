--!strict
-- Pure canonical data. This does not select, load or allocate a native backend.
local VideoState={}
function VideoState.ensure(node)
 local state=node.VideoResourceState
 if not state then
  state={Paused=true,Ended=false,Seeking=false,Ready=0,Network=0,Current="",Duration=0/0,Position=0,DefaultStart=0,
   Rate=1,DefaultRate=1,Muted=node.Attributes.muted~=nil,Volume=1,Error=nil,ErrorVersion=0,Epoch=0,Generation=0,
   Played={},LastPlayed=nil,Subscribers={},Backend=nil,Disposed=false}
  node.VideoResourceState=state
 end
 return state
end
function VideoState.subscribe(state,callback)
 local entry={Callback=callback};state.Subscribers[entry]=true
 return function()state.Subscribers[entry]=nil;entry.Callback=nil end
end
function VideoState.notify(state,kind)
 local failed=false;local firstError
 for entry in table.clone(state.Subscribers)do
  local callback=entry.Callback
  if callback and state.Subscribers[entry]then
   local ok,value=pcall(callback,kind,state)
   if not ok and not failed then failed=true;firstError=value end
  end
 end
 if failed then error(firstError,0)end
end
function VideoState.track(state,position)
 local previous=state.LastPlayed;state.LastPlayed=if not state.Paused then position else nil
 if previous and position>previous then
  local start,finish=previous,position;local nextSpans={}
  for _,span in state.Played do
   if span[2]<start then table.insert(nextSpans,span)
   elseif span[1]>finish then table.insert(nextSpans,{start,finish});start,finish=span[1],span[2]
   else start=math.min(start,span[1]);finish=math.max(finish,span[2])end
  end
  table.insert(nextSpans,{start,finish});state.Played=nextSpans
 end
end
function VideoState.ranges(state,key)
 local result={}
 if key=="played"then for _,span in state.Played do table.insert(result,{span[1],span[2]})end end
 -- Neither Loaded nor native TimeLength proves buffered/seekable ranges.
 -- A backend may provide actual snapshots through the optional capability.
 local supplied=state.RangeData and state.RangeData[key]
 if key~="played"and supplied then for _,span in supplied do table.insert(result,{span[1],span[2]})end end
 return result
end
function VideoState.get(state,key)
 if key=="currentSrc"then return state.Current elseif key=="duration"then return state.Duration
 elseif key=="paused"then return state.Paused elseif key=="ended"then return state.Ended
 elseif key=="seeking"then return state.Seeking elseif key=="readyState"then return state.Ready
 elseif key=="networkState"then return state.Network elseif key=="error"then return state.Error
 elseif key=="currentTime"then return if state.DefaultStart~=0 then state.DefaultStart else state.Position
 elseif key=="muted"then return state.Muted elseif key=="volume"then return state.Volume
 elseif key=="playbackRate"then return state.Rate elseif key=="defaultPlaybackRate"then return state.DefaultRate
 elseif key=="buffered"or key=="seekable"or key=="played"then return VideoState.ranges(state,key)end
 return nil
end
function VideoState.localSet(state,key,value)
 if key=="volume"and(value<0 or value>1)then return {Name="IndexSizeError",Message="Volume is outside 0 to 1"}end
 if key=="currentTime"then
  if state.Ready==0 then state.DefaultStart=value;return nil end
  return {Name="InvalidStateError",Message="No live video backend for this seek"}
 elseif key=="muted"then state.Muted=value
 elseif key=="volume"then state.Volume=value
 elseif key=="playbackRate"then state.Rate=value
 elseif key=="defaultPlaybackRate"then state.DefaultRate=value
 else return {Name="TypeError",Message="Unknown video setter"}end
 VideoState.notify(state,if key=="muted"or key=="volume"then"volumechange"else"ratechange")
 return nil
end
function VideoState.failure(state,code,message)
 state.ErrorVersion+=1;state.Error={Code=code,Message=message,Version=state.ErrorVersion}
 state.Ready=0;state.Network=3;state.Seeking=false
 VideoState.notify(state,"error")
end
return VideoState
