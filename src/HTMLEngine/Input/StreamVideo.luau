--!strict
-- Native presentation lease for a MediaStream. It owns views, never tracks;
-- pausing/detaching one video must not stop a stream shared by another video.
local StreamVideo={}
function StreamVideo.new(stream,parent,changed)
 local player={Playing=false,TimePosition=0,TimeLength=math.huge,Resolution={X=0,Y=0},Active=false,FrameEnabled=false,Root=nil,View=nil,Track=nil,Error=nil}
 local alive=true;local streamCancel,trackCancel;local refreshing=false;local refreshAgain=false;local published=false
 local function release()
  local cancel=trackCancel;trackCancel=nil;if cancel then cancel()end
  local view=player.View;player.View=nil;player.Root=nil;player.Track=nil
  if view then view:Destroy()end
 end
 local function present()
  local view=player.View
  if view then view:SetPlaying(player.Playing and player.Active and player.FrameEnabled)end
 end
 local function refresh()
  if not alive then return end
  if refreshing then refreshAgain=true;return end
  refreshing=true
  repeat
   refreshAgain=false
   local track
   for _,candidate in stream.Tracks or{}do
    if candidate.Kind=='video'and candidate.Stopped~=true and candidate.ReadyState~='ended'and candidate.Source then track=candidate;break end
   end
   local previous=player.Track;local wasActive=player.Active
   if track~=previous then
    release();player.Error=nil
    if track then
     player.Track=track
     local source=track.Source
     local ok,view=pcall(function()return source:Mount(parent)end)
     if not alive then if ok and view then view:Destroy()end;break end
     -- Building a world view may yield. Do not publish a frame whose track
     -- was stopped, removed, or rebound while that work was suspended.
     if track.Stopped or track.ReadyState=='ended'or track.Source~=source or not table.find(stream.Tracks,track)then
      if ok and view then view:Destroy()end
      player.Track=nil;refreshAgain=true;continue
     end
     if ok and view and view.Root then
      player.View=view;player.Root=view.Root
      if track.Subscribe then
       local cancel=track.Subscribe(function()refresh()end)
       if alive and player.Track==track then trackCancel=cancel elseif cancel then cancel()end
      end
     else player.Error=tostring(if ok then'MediaStream video source did not provide a viewport'else view)end
    end
   end
   local settings=track and track.Settings or{}
   local source=track and track.Source
   local width=tonumber(settings.width or(track and track.Width)or(source and source.Width))or 0
   local height=tonumber(settings.height or(track and track.Height)or(source and source.Height))or 0
   player.Resolution={X=math.max(0,math.floor(width)),Y=math.max(0,math.floor(height))}
   player.Active=track~=nil and player.View~=nil and player.Error==nil
   player.FrameEnabled=player.Active and track.Enabled~=false and track.Muted~=true
   if not player.Active then player.Playing=false end
   present()
   if alive then changed(if player.Error then'error'elseif wasActive and not player.Active then'ended'elseif track~=previous then'ready'else'change',player)end
  until not alive or not refreshAgain
  refreshing=false
 end
 function player:Play()if not alive or not self.Active then return end;self.Playing=true;present()end
 function player:Pause()self.Playing=false;if alive then present()end end
 function player:Refresh()published=true;refresh()end
 function player:Destroy()
  if not alive then return end;alive=false;self.Playing=false;self.Active=false
  local cancel=streamCancel;streamCancel=nil;if cancel then cancel()end
  release()
 end
 if stream.Subscribe then
  local cancel=stream.Subscribe(function()if published then refresh()end end)
  if alive then streamCancel=cancel elseif cancel then cancel()end
 end
 -- The owner publishes its player slot before calling Refresh. This prevents
 -- synchronous mounted-source callbacks from observing a half-bound owner.
 return player
end
return StreamVideo
