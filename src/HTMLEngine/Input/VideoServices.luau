--!strict
-- Public VIDEO state/backend adapter. Selection, registrations and native creation
-- remain in MediaRuntime. One service uses that owner's private live lease hooks.
local VideoState=require(script.Parent.Parent.HTML.VideoState)
local MediaBox=require(script.Parent.Parent.Rendering.MediaBox)
local VideoServices={}
function VideoServices.new(context)
 local api={}
 local function native(item)return item.StreamPlayer or item.VideoPlayer or item.VideoGui end
 local function playing(item,object)return if item.StreamPlayer then object.Playing==true elseif item.UsingVideoPlayer then object.IsPlaying==true else object.Playing==true end
 local function videoLease(node,state)
  if context==nil then return nil end
  local item,r=context.Lookup(node);if not r then return nil end
  local lease=state.Backend
  if not lease or lease.Media~=context.Owner or lease.Registration~=r or lease.Item~=item then
   lease={Media=context.Owner,Registration=r,Item=item};state.Backend=lease;r.PublicState=state
  end
  return lease
 end
 local function videoStamp(lease)
  local r=lease.Registration;return {Epoch=r.SelectionEpoch,Generation=r.Generation,Object=native(lease.Item)}
 end
 local function videoCurrent(state,lease,stamp)
  return context~=nil and state.Backend==lease and lease.Media==context.Owner and context.Current(lease,stamp)
 end
 local function videoAtEnd(state,item)
  return if item.StreamPlayer then not item.StreamPlayer.Active else state.Ready>=1 and state.Rate>=0 and state.Duration==state.Duration and state.Position>=state.Duration and item.Node.Attributes.loop==nil
 end
 function api:Signal(item,kind)
  if context==nil then return end
  local _,r=context.Lookup(item.Node,item);local state=r and r.PublicState
  if not state or not state.Backend or state.Backend.Registration~=r then return end
  local previousNetwork=state.Network
  state.Network=r.Network or 0;state.Epoch=r.SelectionEpoch;state.Generation=r.Generation
  if kind=="selected"then state.Current=r.Current or state.Current;state.Ready=0;state.Duration=0/0;state.Error=nil
  elseif kind=="reset"then
   state.ResetRejectPlay=previousNetwork~=0
   state.Paused=if previousNetwork~=0 then true else state.Paused;state.Ready=0;state.Duration=0/0;state.Position=0
   state.Rate=state.DefaultRate;state.Error=nil;state.Seeking=false;state.Ended=false;state.Played={};state.LastPlayed=nil
  elseif kind=="metadata"then
   state.Ready=if item.StreamPlayer then 4 else 2;state.Duration=item.Duration;state.Position=item.CurrentTime;state.Error=nil
   if not item.StreamPlayer and state.DefaultStart>0 and state.Duration==state.Duration then
    local lease=state.Backend;local stamp=videoStamp(lease);local position=math.clamp(state.DefaultStart,0,math.max(0,state.Duration))
    stamp.Object.TimePosition=position;if not videoCurrent(state,lease,stamp)then return end
    state.Position=position;item.CurrentTime=position;state.DefaultStart=0
    item.ShowPoster=false;context.Present(item)
    if not videoCurrent(state,lease,stamp)then return end
   end
   state.DefaultStart=0;state.Ended=videoAtEnd(state,item);item.Ended=state.Ended
  elseif kind=="playing"then state.Playing=true;state.Paused=false;state.Ended=false;state.LastPlayed=state.Position
  elseif kind=="pause"then state.Playing=false;state.Paused=true;state.LastPlayed=nil
  elseif kind=="ended"then state.Playing=false;state.Paused=true;state.Ended=true;state.LastPlayed=nil
  elseif kind=="error"then
   state.Playing=false;state.ErrorVersion+=1
   state.Error={Version=state.ErrorVersion,Code=if r.MetadataReached then 3 else 4,Message=item.LoadError or"Video source unavailable"}
   state.Ready=0;state.Network=3;state.Seeking=false
  end
  VideoState.notify(state,kind)
 end
 function api:VideoBind(node,state)return videoLease(node,state)~=nil end
 function api:VideoSnapshot(node,state)
  local lease=videoLease(node,state);if not lease then return end
  local stamp=videoStamp(lease);local r=lease.Registration
  state.Network=r.Network or state.Network;state.Epoch=stamp.Epoch;state.Generation=stamp.Generation
  if r.ReadyGeneration~=stamp.Generation then return end
  local position=tonumber(stamp.Object.TimePosition);local duration=tonumber(stamp.Object.TimeLength);local isPlaying=playing(lease.Item,stamp.Object)
  if not videoCurrent(state,lease,stamp)then return end
  if position and position==position and math.abs(position)<math.huge then VideoState.track(state,position);state.Position=position end
  if duration and duration==duration and math.abs(duration)<math.huge then state.Duration=duration end
  state.Playing=isPlaying;state.Ready=if lease.Item.StreamPlayer then 4 else 2
  state.Muted=lease.Item.Muted;state.Volume=lease.Item.Volume;state.Rate=lease.Item.PlaybackRate
  if state.Ended and not videoAtEnd(state,lease.Item)then state.Ended=false end
 end
 local function videoEvent(node,state,lease,stamp,kind)
  context.Queue(function()
   if videoCurrent(state,lease,stamp)then context.Emit(lease.Item,kind)end
  end)
 end
 function api:VideoSet(node,state,key,value)
  if key=="volume"and(value<0 or value>1)then return {Name="IndexSizeError",Message="Volume is outside 0 to 1"}end
  local lease=videoLease(node,state);if not lease then return VideoState.localSet(state,key,value)end
  local stamp=videoStamp(lease);local item,r=lease.Item,lease.Registration
  -- A live MediaStream has no seekable timeline. Assigning currentTime does
  -- not invent a buffered interval or reposition the in-game camera.
  if item.StreamPlayer and key=='currentTime'then return nil end
  if key=="currentTime"and state.Ready==0 then state.DefaultStart=value;return nil end
  if key=="defaultPlaybackRate"then
   if state.DefaultRate==value then return nil end
   state.DefaultRate=value;VideoState.notify(state,"ratechange")
   if videoCurrent(state,lease,stamp)then videoEvent(node,state,lease,stamp,"ratechange")end
   return nil
  end
  if key=="volume"and state.Volume==value or key=="muted"and state.Muted==value or key=="playbackRate"and state.Rate==value then return nil end
  if key=="playbackRate"and not item.RateSupported then return {Name="NotSupportedError",Message="This backend cannot change video playback rate"}end
  if key=="playbackRate"and value<0 then return {Name="NotSupportedError",Message="Reverse video playback is unavailable"}end
  local position
  if key=="currentTime"then
   self:VideoSnapshot(node,state);if not videoCurrent(state,lease,stamp)or state.Ready==0 then return nil end
   position=if state.Duration==state.Duration then math.clamp(value,0,math.max(0,state.Duration))else math.max(0,value)
   stamp.Object.TimePosition=position
  elseif key=="muted"then stamp.Object.Volume=if value then 0 else state.Volume
  elseif key=="volume"then stamp.Object.Volume=if state.Muted then 0 else value
  elseif key=="playbackRate"then stamp.Object.PlaybackSpeed=value
  else return {Name="TypeError",Message="Unknown video setter"}end
  if not videoCurrent(state,lease,stamp)then return nil end
  if key=="currentTime"then
   state.DefaultStart=0;state.Position=position;state.Seeking=true;state.Ended=false;item.CurrentTime=position;item.Ended=false
   item.ShowPoster=false;context.Present(item)
   if not videoCurrent(state,lease,stamp)then return nil end
   VideoState.notify(state,"seeking")
   if not videoCurrent(state,lease,stamp)then return nil end
   videoEvent(node,state,lease,stamp,"seeking")
   context.Queue(function()
    if not videoCurrent(state,lease,stamp)then return end
    state.Seeking=false;state.Ended=videoAtEnd(state,item);item.Ended=state.Ended;VideoState.notify(state,"seeked")
    if videoCurrent(state,lease,stamp)then context.Emit(item,"seeked")end
   end)
  elseif key=="muted"then state.Muted=value;item.Muted=value
  elseif key=="volume"then state.Volume=value;item.Volume=value
  elseif key=="playbackRate"then state.Rate=value;item.PlaybackRate=value end
  if videoCurrent(state,lease,stamp)then
   MediaBox.paint(item)
   if key~="currentTime"and videoCurrent(state,lease,stamp)then videoEvent(node,state,lease,stamp,if key=="playbackRate"then"ratechange"else"volumechange")end
  end
  return nil
 end
 function api:VideoCommand(node,state,kind)
  local lease=videoLease(node,state)
  if not lease then return {Name="NotSupportedError",Message="Detached video transport is not implemented by this bounded adapter"}end
  local stamp=videoStamp(lease);local item,r=lease.Item,lease.Registration
  if kind=="load"then context.Refresh(item);return nil end
  if kind=="pause"then
   item.PendingPlay=false;item.PendingAutoplay=false;state.Paused=true;state.Playing=false
   stamp.Object:Pause();if not videoCurrent(state,lease,stamp)then return nil end
   context.Read(item);if videoCurrent(state,lease,stamp)then api:Signal(item,"pause");if item.StreamPlayer then videoEvent(node,state,lease,stamp,'pause')end end;return nil
  end
  assert(kind=="play","Video command")
  if item.StreamPlayer and not item.StreamPlayer.Active then return {Name='NotSupportedError',Message='MediaStream has no live video track'}end
  if state.Error then return {Name="NotSupportedError",Message="Video source is unavailable"}end
  state.Paused=false;state.Ended=false;item.PendingPlay=true;VideoState.notify(state,"play")
  if not videoCurrent(state,lease,stamp)then return nil end
  if r.ReadyGeneration~=stamp.Generation then
   -- Source-less and exhausted selections wait for DOM insertion; Fetch would
   -- turn NETWORK_EMPTY into an unresumable candidate-less attempt.
   if r.Network~=0 and not r.Waiting then context.Fetch(r)end
   return nil
  end
  if item.Ended or(state.Duration>0 and state.Position>=state.Duration)then
   stamp.Object.TimePosition=0;if not videoCurrent(state,lease,stamp)then return nil end;state.Position=0;item.CurrentTime=0
  end
  item.PendingPlay=false;item.Ended=false;item.HasPlayed=true;item.ShowPoster=false;context.Present(item)
  if not videoCurrent(state,lease,stamp)then return nil end
  stamp.Object:Play();if not videoCurrent(state,lease,stamp)then return nil end
  context.Read(item);if videoCurrent(state,lease,stamp)and playing(item,stamp.Object)then api:Signal(item,"playing");if item.StreamPlayer then videoEvent(node,state,lease,stamp,'play');videoEvent(node,state,lease,stamp,'playing')end end
  return nil
 end
 function api:VideoCanPlayType(_value)return ""end -- URI mapping is not a codec claim.

 function api:Destroy()context=nil end
 return api
end
return VideoServices
