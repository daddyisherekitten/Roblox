--!strict
return function(Parser,loadMediaRuntime,MediaBox,VideoState,StreamVideo)
 local checks=0
 local function check(value,message)checks+=1;assert(value,message)end
 local function signal()
  local listeners={};local api={}
  function api:Connect(callback)local entry={Connected=true,Callback=callback};function entry:Disconnect()self.Connected=false end;table.insert(listeners,entry);return entry end
  function api:Fire(...)for _,entry in table.clone(listeners)do if entry.Connected then entry.Callback(...)end end end
  return api
 end
 local function stream(width,height)
  local callbacks={};local trackCallbacks={};local mounts,destroys,stops=0,0,0;local views={}
  local source={Width=width,Height=height}
  function source:Mount(parent)
   mounts+=1;local view={Root={Parent=parent,Visible=true},Playing=false,Destroyed=false}
   function view:SetPlaying(value)self.Playing=value end
   function view:Destroy()if self.Destroyed then return end;self.Destroyed=true;destroys+=1 end
   table.insert(views,view);return view
  end
  local track={Kind='video',Id='camera',Settings={width=width,height=height},Source=source,ReadyState='live',Stopped=false,Enabled=true}
  local record={Tracks={track},Active=true}
  record.Subscribe=function(callback)callbacks[callback]=true;return function()callbacks[callback]=nil end end
  track.Subscribe=function(callback)trackCallbacks[callback]=true;return function()trackCallbacks[callback]=nil end end
  local function notify()for callback in table.clone(callbacks)do if callbacks[callback]then callback('change',record)end end end
  local h={Record=record,Track=track,Views=views}
  function h:Enabled(value)track.Enabled=value;notify()end
  function h:Stop()if track.Stopped then return end;stops+=1;track.Stopped=true;track.ReadyState='ended';record.Active=false;for callback in table.clone(trackCallbacks)do if trackCallbacks[callback]then callback('ended')end end;notify()end
  function h:Stats()local count=0;for _ in callbacks do count+=1 end;return mounts,destroys,stops,count end
  return h
 end
 local function fixture(sourceRecord)
  local jobs={};local tasks={spawn=function(callback)table.insert(jobs,callback)end,defer=function(callback)table.insert(jobs,callback)end}
  local document=Parser.parse('<video id="live" controls autoplay muted src="asset.webm"></video>');local node=document.Children[1];node.MediaStreamSource=sourceRecord
  local heartbeat=signal();local native={Playing=false,IsLoaded=true,TimeLength=15,TimePosition=0,Resolution={X=120,Y=80},Loaded=signal(),Played=signal(),Paused=signal(),Ended=signal()}
  function native:GetPropertyChangedSignal()return signal()end
  function native:Play()self.Playing=true;self.Played:Fire()end
  function native:Pause()self.Playing=false;self.Paused:Fire()end
  local item={Node=node,MediaKind='video',Source=nil,SelectedSource='',Tracks={},Controls=false,Gui={},BoxGui={},StreamSurfaceGui={},VideoGui=native,PosterGui={},MissingGui={},
   Style={Padding={0,0,0,0},Margin={0,0,0,0},BorderSize=0,Visibility='visible',ObjectFit='contain'},BoxWidth=200,BoxHeight=200,ContentWidth=200,ContentHeight=200}
  local events={};local page={Alive=true,Document=document,DocumentURL='https://video.test/index.html',ScriptInitializationPending=false,AddCleanup=function()end,ResolveVideo=function(raw)return if raw=='asset.webm'then'rbxassetid://42'else nil end}
  local api=loadMediaRuntime(tasks).start(page,{MediaItems={item},MediaByNode={[node]=item}},{Emit=function(_,_,kind)table.insert(events,kind)end},function(message)error(message)end,
   {Task=tasks,RunService={Heartbeat=heartbeat},ContentProvider={PreloadAsync=function()end},Instance={new=function()error('No native backend should be allocated')end},Content={none='none',fromUri=function(uri)return uri end}})
  local h={Page=page,API=api,Node=node,Item=item,State=VideoState.ensure(node),Native=native,Heartbeat=heartbeat,Events=events}
  function h:Drain()local count=0;while #jobs>0 do count+=1;check(count<100,'Native video tasks terminate');table.remove(jobs,1)()end end
  function h:Has(kind)for _,entry in events do if entry==kind then return true end end;return false end
  return h
 end
 do
  local camera=stream(640,360);local h=fixture(camera.Record);h:Drain()
  check(h.Item.StreamPlayer~=nil and h.Item.StreamSource==camera.Record,'Pre-render srcObject creates stream presentation')
  check(h.State.Ready==4 and h.State.Duration==math.huge and h.State.Current=='','Live metadata uses an infinite duration and empty currentSrc')
  check(h.Item.VideoWidth==640 and h.Item.VideoHeight==360 and h.Item.Playing,'Autoplay stream obtains source dimensions and starts')
  check(h:Has('loadedmetadata')and h:Has('canplay')and h:Has('loadeddata'),'Live source emits actual video readiness events')
  local width,height=h.API:VideoDimensions(h.Node);check(width==640 and height==360,'Public dimensions use configured camera size')
  check(camera.Views[1].Root.Parent==h.Item.StreamSurfaceGui and camera.Views[1].Playing,'Viewport stays in the normal video content surface')
  check(h.Item.StreamSurfaceGui.Visible and not h.Native.Visible,'Stream hides the asset transport')
  check(camera.Views[1].Root.Size[1]==200 and camera.Views[1].Root.Size[2]>112 and camera.Views[1].Root.Size[2]<113,'Object-fit contain preserves configured source aspect')
  check(camera.Views[1].Root.Position[2]>43 and camera.Views[1].Root.Position[2]<44,'Object-fit letterboxes within content box')
  h.Heartbeat:Fire(.25);check(h.State.Position==0 and h.Item.CurrentTime==.25,'Live native timeline advances between public snapshots')
  h.API:VideoSnapshot(h.Node,h.State);check(h.State.Position==.25 and h.State.Ready==4,'Public video snapshot samples live currentTime')
  check(h.API:VideoSet(h.Node,h.State,'currentTime',80)==nil and h.Item.CurrentTime==.25,'Live currentTime cannot seek the camera')
  h.API:VideoCommand(h.Node,h.State,'pause');h:Drain();check(h.State.Paused and not camera.Views[1].Playing,'Pause freezes this view')
  h.API:VideoCommand(h.Node,h.State,'play');h:Drain();check(h.State.Playing and camera.Views[1].Playing and h:Has('playing'),'Play resumes this view and settles playback signal')
  camera:Enabled(false);check(not camera.Views[1].Playing and not camera.Views[1].Root.Visible and h.Item.StreamSurfaceGui.Visible,'Disabled video track produces a black surface')
  camera:Enabled(true);check(camera.Views[1].Playing and camera.Views[1].Root.Visible,'Reenabled track resumes without a new capture')
  h.Node.Attributes.src='ignored.webm';h.API:VideoMutation({Type='attributes',Target=h.Node,AttributeName='src'});h.API:Refresh(h.Item,{src=true},true);h:Drain()
  check(h.Item.StreamSource==camera.Record and h.Item.Playing,'srcObject takes precedence over changed src')
  local nextCamera=stream(320,240);h.API:VideoSetSource(h.Node,h.State,nextCamera.Record);h:Drain()
  local _,destroyed,stopped,listeners=camera:Stats();check(destroyed==1 and stopped==0 and listeners==0,'Source replacement releases the old view/subscriber without stopping shared capture')
  check(h.Item.StreamSource==nextCamera.Record and h.Item.VideoWidth==320,'Source replacement updates metadata')
  camera:Stop();check(h.Item.StreamSource==nextCamera.Record and not h.State.Ended,'Former source cannot mutate replacement')
  nextCamera:Stop();check(h.State.Ended and h.State.Paused and not h.Item.Playing and h:Has('ended'),'Track stop ends the associated video')
  check(h.API:VideoCommand(h.Node,h.State,'play').Name=='NotSupportedError','Ended stream cannot fabricate resumed capture')
  h.API:Destroy();local _,nextDestroyed,_,remaining=nextCamera:Stats();check(nextDestroyed==1 and remaining==0,'Destroy releases stream presentation and subscription')
 end
 do
  local camera=stream(640,360);local h=fixture(nil);h:Drain()
  check(h.Item.Source=='rbxassetid://42'and h.Native.Video=='rbxassetid://42'and h.Item.StreamPlayer==nil,'Existing mapped asset path remains selected')
  h.API:VideoSetSource(h.Node,h.State,camera.Record);h:Drain();check(h.Item.StreamPlayer~=nil and not h.Native.Playing and h.State.Current=='','Assigning srcObject pauses and replaces mapped playback with an empty currentSrc')
  h.Node.Attributes.src='asset.webm';h.API:VideoSetSource(h.Node,h.State,nil);h:Drain()
  check(h.Item.StreamPlayer==nil and h.Item.Source=='rbxassetid://42'and h.Native.Video=='rbxassetid://42','Clearing srcObject resumes current src selection')
  local _,destroyed,stopped,listeners=camera:Stats();check(destroyed==1 and stopped==0 and listeners==0,'Clearing srcObject does not stop its shared tracks')
  h.API:Destroy()
 end
 do
  local camera=stream(640,360);local h=fixture(camera.Record);h:Drain();local item=h.Item
  h.API:Remove({item});local _,destroyed,stopped,listeners=camera:Stats()
  check(destroyed==1 and stopped==0 and listeners==0 and h.Node.MediaStreamSource==camera.Record,'DOM detachment releases view but retains srcObject for reinsertion')
  h.API:Add({item});h:Drain();local mounts=camera:Stats();check(mounts==2 and h.Item.StreamPlayer~=nil,'DOM reinsertion mounts a fresh view from the same live track')
  h.API:Destroy()
 end
 do
  local camera=stream(80,60);local events={};local player=StreamVideo.new(camera.Record,{},function(kind)table.insert(events,kind)end)
  player:Refresh();player:Play();player:Destroy();player:Destroy();local mounts,destroyed,stopped,listeners=camera:Stats()
  check(mounts==1 and destroyed==1 and stopped==0 and listeners==0,'Native view lease teardown is idempotent and never owns tracks')
 end
 do
  local camera=stream(80,60);local source=camera.Track.Source;local mount=source.Mount;local ready=false
  function source:Mount(parent)local view=mount(self,parent);camera:Stop();return view end
  local player=StreamVideo.new(camera.Record,{},function(kind)if kind=='ready'then ready=true end end)
  player:Refresh();local mounts,destroyed=camera:Stats()
  check(mounts==1 and destroyed==1 and not player.Active and not ready,'Track stop during world-view construction cannot publish stale readiness or a stale frame')
  player:Destroy()
 end
 print('MediaStreamVideo: '..checks..' assertions passed')
end
