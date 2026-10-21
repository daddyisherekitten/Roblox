--!strict
local DOM=require(script.Parent.Parent.DOM.Node)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local WebVTT=require(script.Parent.Parent.HTML.WebVTT)
local MediaBox=require(script.Parent.Parent.Rendering.MediaBox)
local Selection=require(script.Parent.Parent.HTML.MediaSelection)
local URLResolver=require(script.Parent.Parent.Rendering.NativeMediaResources)
local StreamVideo=require(script.Parent.StreamVideo)
local MediaRuntime={}
local RATES={0.5,1,1.5,2}

local function connect(list: {any}, signal: any, callback: any)
	if signal and signal.Connect then table.insert(list,signal:Connect(callback)) end
end

function MediaRuntime.start(page: any,tree: any,events: any,diagnostic: any,services: any?,bootstrap: any?): any
	local items=tree.MediaItems or {}
	local byNode=tree.MediaByNode or {}
	local api={}
 local registered={}
 local videoSignal
 local Names=require(script.Parent.Parent.DOM.ElementNames)
 local Work=require(script.Parent.Parent.WorkContext)
 -- The zero-item input facade and its later native owner share one ledger.
 -- Reads never traverse the DOM. Only committed edited subtrees are visited.
 local reservations=bootstrap or {Alive=true,Nodes={},Count=0,OwnerCount=0,Revision=0,Scans={},ScanCount=0}
 local closingNotifications
 local function willLazy(node)return page.LazyMedia and page.LazyMedia:WillDefer(node)or false end
 local function cancelLazy(r)local cancel=r.CancelLazy;r.CancelLazy=nil;if cancel then cancel()end end
 local function closeAttempt(closing,operation)
  local ok,value=pcall(operation)
  if not ok and not closing.Failed then closing.Failed=true;closing.Value=value end
 end
 local function resourcesChanged()
  local runtime=page.JavaScriptRuntime
  local owner,notify
  if page.DocumentResourcesChanged then owner=page;notify=page.DocumentResourcesChanged
  elseif runtime and runtime.Alive then owner=runtime;notify=runtime.ResourcesChanged end
  if page.Alive and notify then
   if closingNotifications then
    -- Finish this owner's existing teardown before propagating its first
    -- external notification failure, including nil/false error values.
    local ok,value=pcall(notify,owner)
    if not ok and not closingNotifications.Failed then closingNotifications.Failed=true;closingNotifications.Value=value end
   else notify(owner)end
  end
 end
 local function releaseReservation(node,lease,notify)
  if reservations.Nodes[node]~=lease then return end
  reservations.Nodes[node]=nil;reservations.Count-=1
  if notify then resourcesChanged()end
 end
 local function reserve(node)
  if not reservations.Alive or not page.Alive or not Names.html(node,'video')or not ShadowTree.Connected(node,page.Document)then return end
  local item=byNode[node];if item and registered[item]then return end
  if willLazy(node)then local lease=reservations.Nodes[node];if lease then releaseReservation(node,lease,true)end;return end
  reservations.Revision+=1
  local lease=reservations.Nodes[node]
  if lease then lease.Revision=reservations.Revision;return end
  lease={Revision=reservations.Revision};reservations.Nodes[node]=lease;reservations.Count+=1
  resourcesChanged()
 end
 local function walk(root,added)
  if not root or root.Kind=='Text'or root.Kind=='Comment'then return end
  -- SOURCE/TRACK are inert leaf data. A VIDEO is itself the resource owner;
  -- its supported children are processed by the existing selection core.
  if Names.html(root,'source')or Names.html(root,'track')then return end
  if Names.html(root,'video')then
   if added then reserve(root)else local lease=reservations.Nodes[root];if lease and not ShadowTree.Connected(root,page.Document)then releaseReservation(root,lease,true)end end
   return
  end
  local scan={Active=true};reservations.Scans[scan]=true;reservations.ScanCount+=1
  local result=table.pack(pcall(function()
   resourcesChanged()
   local pending={{Node=root,Index=0}}
   while #pending>0 and reservations.Alive and page.Alive do
    local frame=pending[#pending];local node=frame.Node
    if frame.Index==0 then
     if added then reserve(node)
     else local lease=reservations.Nodes[node];if lease and not ShadowTree.Connected(node,page.Document)then releaseReservation(node,lease,true)end end
     if not reservations.Alive or not page.Alive then break end
     Work.checkpoint()
     if not reservations.Alive or not page.Alive then break end
    end
    frame.Index+=1
    local children=node.Children or{};local child=children[frame.Index]
    if not child and frame.Index==#children+1 then child=node.InternalShadowRoot end
    if child then table.insert(pending,{Node=child,Index=0})else table.remove(pending)end
   end
  end))
  if scan.Active then scan.Active=false;reservations.Scans[scan]=nil;reservations.ScanCount-=1 end
  local closed=table.pack(pcall(resourcesChanged))
  if not result[1]then error(result[2],0)end
  if not closed[1]then error(closed[2],0)end
 end
 local function bootstrapMutation(change)
  if not reservations.Alive or not page.Alive then return end
  if change.Type=='attributes'and not change.AttributeNamespace and change.AttributeName=='loading'and Names.html(change.Target,'video')then
   reserve(change.Target)
  elseif change.Type=='attributes'and not change.AttributeNamespace and change.AttributeName=='src'and change.Target.Attributes.src~=nil then
   if Names.html(change.Target,'video')then reserve(change.Target)
   elseif Names.html(change.Target,'source')then reserve(change.Target.Parent)end
  elseif change.Type=='childList'then
   for _,node in change.RemovedNodes or{}do walk(node,false);if not reservations.Alive or not page.Alive then return end end
   for _,node in change.AddedNodes or{}do
    walk(node,true)
    if not reservations.Alive or not page.Alive then return end
   end
   reserve(change.Target)
  end
 end
 function api:BeginVideoPublication()return reservations.Revision end
 function api:EndVideoPublication(token)
  if not reservations.Alive then return end
  local changed=false
  for node,lease in reservations.Nodes do
   local item=byNode[node]
   if lease.Revision<=token and(not item or not registered[item])then releaseReservation(node,lease,false);changed=true end
  end
  -- Retire every slot before entering an external notification. Its first
  -- error cannot strand the rest of this completed publication batch.
  if changed then resourcesChanged()end
 end
 local function destroyReservations()
  if not reservations.Alive then return end;reservations.Alive=false
  table.clear(reservations.Nodes);reservations.Count=0
  for scan in reservations.Scans do scan.Active=false end
  table.clear(reservations.Scans);reservations.ScanCount=0
 end
	if #items==0 then
		local disposed=false
		function api:Resolve(): any return nil end
		function api:Hover()end;function api:Begin(): boolean return false end
		function api:Move(): boolean return false end;function api:Finish(): boolean return false end
		function api:Cancel()end;function api:Activate()end;function api:Key(): boolean return false end
		function api:ExitFullscreen(): boolean return false end;function api:Remove()end
		function api:Refresh()end
  function api:VideoSetSource(node,_,source)node.MediaStreamSource=source;return nil end
  function api:VideoMutation(change)if not disposed then bootstrapMutation(change)end end
  function api:GetPendingDocumentResources()return reservations.OwnerCount+reservations.Count+reservations.ScanCount end
		function api:Destroy()
   if disposed then return end;disposed=true
   if not reservations.Alive then return end
   local owner=reservations.Owner
   if owner then owner:Destroy()else destroyReservations();resourcesChanged()end
  end
		function api:Add(additions: {any})
			if disposed or not reservations.Alive or not page.Alive or #additions==0 then return end
			local current=MediaRuntime.start(page,tree,events,diagnostic,services,reservations)
			if disposed or not reservations.Alive or not page.Alive then return end
			-- The input controller retains this facade, so populate it in place.
			for key,value in current do self[key]=value end
			page.Media=self
		end
		page.Media=api;page:AddCleanup(function()api:Destroy()end)
		return api
	end
	local runService=if services and services.RunService then services.RunService else game:GetService("RunService")
	local contentProvider=if services and services.ContentProvider then services.ContentProvider else game:GetService("ContentProvider")
	local instance=if services and services.Instance then services.Instance else Instance
	local content=if services and services.Content then services.Content else Content
	local alive,connections=true,{}
	local dragItem,dragAction,pressedItem,hoveredItem=nil,nil,nil,nil
	local fullscreenItem,fullscreenOverlay,fullscreenConnection=nil,nil,nil
 local queueDocumentBoundary
 function api:GetPendingDocumentResources()return reservations.OwnerCount+reservations.Count+reservations.ScanCount end
	local taskAPI=if services and services.Task then services.Task else task
 local videoSelection;local videoTasks={Head=1,Tail=0};local videoStable={Head=1,Tail=0};local videoWake=false;local videoRunning=false
 local videoStarted=page.VideoSelectionStarted==true or page.ScriptInitializationPending~=true;local videoRealm=page.JavaScriptRuntime
 local sourceServices=page.VideoSourceServices or services or{}

	local function native(item: any): any
		if item.MediaKind=="audio" then return item.Sound end
		return item.StreamPlayer or item.VideoPlayer or item.VideoGui
	end
	local function playing(item: any,object: any): boolean
		return if item.StreamPlayer then object.Playing==true elseif item.UsingVideoPlayer then object.IsPlaying==true else object.Playing==true
	end
	local function read(item: any)
		local registration=registered[item]
		if not alive or not page.Alive or not registration then return end
		if item.MediaKind=="video"and registration.ReadyGeneration~=registration.Generation then MediaBox.paint(item);return end
		local object=native(item)
		if not object then return end
		item.Playing=playing(item,object)
		local session=item.AudioSession
		item.Duration=if session and not session.Ready then 0 else tonumber(object.TimeLength) or item.Duration or 0
		if session then item.Ended=session.Ended==true end
		item.CurrentTime=if session and session.Ended then item.Duration else tonumber(object.TimePosition) or item.CurrentTime or 0
		if item.Captions and item.Cues then item.CaptionText=WebVTT.at(item.Cues,item.CurrentTime) else item.CaptionText=nil end
		MediaBox.paint(item)
	end
	local function data(item: any): any
		return {CurrentTime=item.CurrentTime,Duration=item.Duration,Paused=not item.Playing,Muted=item.Muted,Volume=item.Volume,PlaybackRate=item.PlaybackRate,Loading=item.Loading==true,Error=item.LoadError,Fullscreen=item.Fullscreen==true}
	end
	local function emit(item: any,kind: string)
		local registration=registered[item];if not registration or not alive or not page.Alive then return end
		read(item)
		if item.AudioSession then item.AudioSession:Control(kind,data(item))else events:Emit(item.Node,kind,data(item))end
	end
	local function destroyAll(objects: {any})
		for index=#objects,1,-1 do pcall(function() objects[index]:Destroy() end) end
	end
	local function setupVideoPlayer(item: any): any?
		if not item.VideoDisplay then return nil end
		local made={}
		local player
		local ok,message=pcall(function()
			player=instance.new("VideoPlayer");table.insert(made,player)
			player.Name=(item.Node.Attributes.id or "HTMLVideo").."Player"
			if item.Source and not item.VideoSelection then player.VideoContent=content.fromUri(item.Source) end
			player.Looping=item.Node.Attributes.loop~=nil
			player.Volume=if item.Muted then 0 else 1
			player.PlaybackSpeed=1
			player.Parent=item.Gui
			local videoWire=instance.new("Wire");table.insert(made,videoWire)
			videoWire.SourceInstance=player;videoWire.TargetInstance=item.VideoDisplay;videoWire.Parent=player
			local output=instance.new("AudioDeviceOutput");table.insert(made,output);output.Parent=item.Gui
			local audioWire=instance.new("Wire");table.insert(made,audioWire)
			audioWire.SourceInstance=player;audioWire.TargetInstance=output;audioWire.Parent=player
		end)
		if not ok then
			destroyAll(made)
			diagnostic("Video playback-speed backend unavailable; VideoFrame fallback used: "..tostring(message))
			return nil
		end
		item.VideoPlayer=player
		item.VideoObjects=made
		item.UsingVideoPlayer=true
		return player
	end
	local function current(item: any,registration: any,generation: number): boolean
		return alive and page.Alive and registered[item]==registration and registration.Generation==generation and(item.MediaKind~='video'or not page.Document or ShadowTree.Connected(item.Node,page.Document))
	end
 local function cancelDocumentBoundaries(r)
  r.DocumentRevision=(r.DocumentRevision or 0)+1
  for entry in r.DocumentBoundaries or{}do entry.Record=nil end
  if r.DocumentBoundaries then table.clear(r.DocumentBoundaries)end
 end
 local function documentBarrier(r,bootstrap,delay)
  cancelDocumentBoundaries(r)
  r.BootstrapPending=bootstrap;r.DelayLoadFlag=delay
  local item=r.Item
  local blocking=alive and page.Alive and item~=nil and registered[item]==r and(bootstrap or delay)
  if blocking~=(r.DocumentBlocking==true)then
   r.DocumentBlocking=blocking;reservations.OwnerCount+=if blocking then 1 else -1
   resourcesChanged()
  elseif r.BootstrapAdopted then
   r.BootstrapAdopted=nil;resourcesChanged()
  end
 end

	local function presentation(item)
		if page.MediaPresentationChanged then page:MediaPresentationChanged(item)
		else MediaBox.natural(item);MediaBox.paint(item)end
	end
	local function dimensions(item,registration,generation)
		if not current(item,registration,generation)or registration.ReadyGeneration~=generation then return end
		local ok,resolution=pcall(function()return native(item).Resolution end)
		local w,h=if ok and resolution then tonumber(resolution.X)else nil,if ok and resolution then tonumber(resolution.Y)else nil
		w,h=if w and w>0 and w<math.huge then math.floor(w)else 0,if h and h>0 and h<math.huge then math.floor(h)else 0
		if item.VideoWidth==w and item.VideoHeight==h then return end
		item.VideoWidth,item.VideoHeight=w,h;presentation(item)
		if current(item,registration,generation)then events:Emit(item.Node,'resize',{}, {Bubbles=false,Cancelable=false})end
	end
	local function ready(item: any,registration: any?,generation: number?)
		local owner=registration or registered[item];if not owner then return end
		local epoch=generation or owner.Generation
		if not current(item,owner,epoch)or item.AudioSession or(item.VideoSelection and(owner.AttemptFailed or owner.Phase~="fetch"))then return end
		owner.ReadyGeneration=epoch
  if item.VideoSelection then owner.MetadataReached=true;owner.Phase="ready";owner.Loading=false;owner.Network=1 end
		if item.MediaKind=='video'then item.VideoFrameAvailable=true end
		if item.MediaKind=='video'then dimensions(item,owner,epoch);if not current(item,owner,epoch)then return end end
		item.Loading=false;item.LoadFailed=false;item.LoadError=nil;read(item)
  if item.VideoSelection then videoSignal(item,"metadata");if not current(item,owner,epoch)then return end end
		if not item.MetadataEmitted then
			item.MetadataEmitted=true
			events:Emit(item.Node,"loadedmetadata",data(item))
			if current(item,owner,epoch)then events:Emit(item.Node,"canplay",data(item))end
		end
  if current(item,owner,epoch)and item.VideoSelection then queueDocumentBoundary(owner,"data","ready")end
	end
	local function failed(item: any,message: any,registration: any?,generation: number?)
		local owner=registration or registered[item];if not owner then return end
  local selectionEpoch=owner.SelectionEpoch;generation=generation or owner.Generation
		if not current(item,owner,generation or owner.Generation)or item.AudioSession then return end
		-- Native notification and LoadAsync completion can report the same
		-- attempt. Settle it once; a pending child retry is not a media error.
		if item.VideoSelection and owner.AttemptFailed then return end
		if item.VideoSelection and owner.Mode=="children"and not owner.MetadataReached then videoSelection:Fail(owner);return end
  if item.VideoSelection then owner.Phase="error";owner.Loading=false;owner.Network=3;owner.AttemptFailed=true end
  item.PendingPlay=false;item.PendingAutoplay=false
		item.Loading=false;item.LoadFailed=true;item.LoadError=tostring(message);MediaBox.paint(item)
  if item.VideoSelection then videoSignal(item,"error");if not current(item,owner,generation)then return end end
  if item.VideoSelection and owner.MetadataReached then
   documentBarrier(owner,false,false)
   if not current(item,owner,generation)or owner.SelectionEpoch~=selectionEpoch then return end
  end
		events:Emit(item.Node,"error",data(item),if item.MediaKind=="video"then {Bubbles=false,Cancelable=false}else nil);diagnostic("Media load failed: "..tostring(message))
  if item.VideoSelection and current(item,owner,generation)and owner.SelectionEpoch==selectionEpoch then documentBarrier(owner,false,false)end
	end
	local function beginLoad(item: any)
		if not alive or not page.Alive or not registered[item]or item.AudioSession then return end
		item.Loading=true;item.LoadFailed=false;item.LoadError=nil;MediaBox.paint(item)
		if not item.LoadStarted and not item.VideoSelection then item.LoadStarted=true;events:Emit(item.Node,"loadstart",data(item))end
	end
	local function bindVideoEvents(item: any,registration: any)
		-- Old callback closures carry this epoch. Roblox's payload-free signals
		-- cannot identify a genuinely late old-source delivery to a new binding.
		for _,connection in registration.Connections do connection:Disconnect()end
		table.clear(registration.Connections)
		local object=native(item);local generation=registration.Generation
		local function active(): boolean
			return current(item,registration,generation)and not item.StreamPlayer and registration.BoundGeneration==generation and item.Source~=nil
		end
		local list=registration.Connections
		-- Older/fallback hosts may lack the property notification; their
		-- available metadata is still sampled at the current readiness boundary.
		local hasResolution,resolutionSignal=pcall(function()return object:GetPropertyChangedSignal('Resolution')end)
		if hasResolution then connect(list,resolutionSignal,function()if active()then dimensions(item,registration,generation)end end)end
		if item.UsingVideoPlayer then
			connect(list,object:GetPropertyChangedSignal("IsLoaded"),function()if active()and object.IsLoaded then ready(item,registration,generation)end end)
			connect(list,object:GetPropertyChangedSignal("IsPlaying"),function()
				if not active()or registration.ReadyGeneration~=generation then return end
				local before=item.Playing;read(item);if item.Playing then item.Ended=false;item.HasPlayed=true;item.ShowPoster=false;presentation(item)end
				if item.Playing then videoSignal(item,"playing")end
				if item.Playing~=before then events:Emit(item.Node,if item.Playing then "play"else "pause",data(item))end
			end)
			connect(list,object.DidEnd,function()if active()and registration.ReadyGeneration==generation then item.Playing=false;item.Ended=true;videoSignal(item,"ended");emit(item,"ended")end end)
			connect(list,object.PlayFailed,function(reason)if active()then failed(item,"Video playback failed: "..tostring(reason),registration,generation)end end)
		else
			connect(list,object.Loaded,function()if active()then ready(item,registration,generation)end end)
			connect(list,object.Played,function()if active()and registration.ReadyGeneration==generation then item.HasPlayed=true;item.ShowPoster=false;presentation(item);item.Ended=false;videoSignal(item,"playing");emit(item,"play")end end)
			connect(list,object.Paused,function()if active()and registration.ReadyGeneration==generation then emit(item,"pause")end end)
			connect(list,object.Ended,function()if active()and registration.ReadyGeneration==generation then item.Playing=false;item.Ended=true;videoSignal(item,"ended");emit(item,"ended")end end)
		end
	end
	local requestVideoLoad
	local function playPending(item: any,registration: any,generation: number)
		if not current(item,registration,generation)or registration.ReadyGeneration~=generation or(not item.Source and not item.StreamPlayer)then return end
		if item.PendingPlay or item.PendingAutoplay then
			item.PendingPlay=false;item.PendingAutoplay=false;item.HasPlayed=true;item.ShowPoster=false;presentation(item);item.Ended=false
			local ok,message=pcall(function()native(item):Play()end)
			if not current(item,registration,generation)then return end
			if ok then read(item);if item.StreamPlayer then videoSignal(item,'playing');events:Emit(item.Node,'play',data(item))end else failed(item,message,registration,generation)end
		end
	end
	local function applyVideoSource(item: any,registration: any)
		local generation=registration.Generation
		if not current(item,registration,generation)or item.StreamPlayer or registration.LoadJob or registration.Phase=="lazy"then return end
		if registration.BoundGeneration==generation then return end
		local object=native(item)
		-- Disconnect before native Pause/Unload: their signals belong to the old source.
		for _,connection in registration.Connections do connection:Disconnect()end;table.clear(registration.Connections)
		pcall(function()object:Pause()end)
		if not current(item,registration,generation)then return end
		if item.UsingVideoPlayer then
			pcall(function()object:Unload()end)
			if not current(item,registration,generation)then return end
			local nextContent=if item.Source then content.fromUri(item.Source)else content.none
   if not current(item,registration,generation)then return end
   object.VideoContent=nextContent
		else object.Video=item.Source or ""end
  if not current(item,registration,generation)then return end
		object.TimePosition=0
  if not current(item,registration,generation)then return end
		if item.RateSupported then object.PlaybackSpeed=item.PlaybackRate or 1 end
  if not current(item,registration,generation)then return end
		registration.BoundGeneration=generation;bindVideoEvents(item,registration)
	end
	local function loadVideoNow(item: any,registration: any,generation: number)
		if not current(item,registration,generation)or item.StreamPlayer or registration.Phase=="lazy"then return end
		registration.RequestedGeneration=nil
		if registration.LoadJob then return end
		applyVideoSource(item,registration)
		if not current(item,registration,generation)or not item.Source then return end
		if registration.ReadyGeneration==generation then playPending(item,registration,generation);return end
		local object=native(item)
		if item.UsingVideoPlayer and object.IsLoaded then ready(item,registration,generation);playPending(item,registration,generation);return end
		local job={Generation=generation};registration.LoadJob=job;item.LoadInProgress=true;beginLoad(item)
		if not current(item,registration,generation)then
			if registered[item]==registration and registration.LoadJob==job then registration.LoadJob=nil;item.LoadInProgress=false;applyVideoSource(item,registration);requestVideoLoad(item)end
			return
		end
		local fetchFailed=false;local ok,message=pcall(function()
			if item.UsingVideoPlayer then return object:LoadAsync()end
			if contentProvider and contentProvider.PreloadAsync then contentProvider:PreloadAsync({object},function(_,status)local value=tostring(status);if value:match("Failure$")or value:match("TimedOut$")then fetchFailed=true end end)end
		end)
		if registered[item]~=registration or registration.LoadJob~=job then return end
		registration.LoadJob=nil;item.LoadInProgress=false
		if not current(item,registration,generation)then
			if alive and page.Alive then applyVideoSource(item,registration);requestVideoLoad(item)end
			return
		end
		if ok and not fetchFailed and(object.IsLoaded==true or not item.VideoSelection and registration.ReadyGeneration==generation)and(not item.UsingVideoPlayer or message==nil or tostring(message):match("Success$"))then ready(item,registration,generation);playPending(item,registration,generation)
		else failed(item,"Video preload failed: "..tostring(message),registration,generation)end
	end
	requestVideoLoad=function(item: any)
		local registration=registered[item];if not registration then return end
		local generation=registration.Generation
		if not current(item,registration,generation)or item.StreamPlayer or registration.Phase=="lazy"then return end
		applyVideoSource(item,registration)
		if not item.Source or registration.LoadJob or registration.RequestedGeneration==generation then return end
		if registration.ReadyGeneration==generation then playPending(item,registration,generation);return end
		if item.Preload=="none"and not item.PendingPlay and not item.PendingAutoplay then return end
		registration.RequestedGeneration=generation
		taskAPI.spawn(function()loadVideoNow(item,registration,generation)end)
	end

 -- One video selection core; native IO remains the retained serial LoadJob.
 -- This renderer-backed proposal deliberately does not add hidden backends.
 local selectionWake;local videoCheckpointWake=false
 local function queued(list)return list.Head<=list.Tail end
 local function take(list)
  if not queued(list)then return nil end
  local index=list.Head;local entry=list[index];list[index]=nil;list.Head+=1
  if not queued(list)then list.Head,list.Tail=1,0 end
  local callback=entry.Callback;entry.Callback=nil;return callback
 end
 local function realmQueue(list,callback)
  local runtime=videoRealm
  if runtime and runtime.Alive and runtime.EventLoop.Alive then
   local loop=runtime.EventLoop
   if list==videoStable then
    loop:QueueMicrotask(callback)
    -- EventLoop.NextDue deliberately excludes pure microtasks. A bounded
    -- source-owned wake runs their checkpoint even after a renderer flush.
    if not videoCheckpointWake then videoCheckpointWake=true;loop:QueueTask(function()videoCheckpointWake=false;if alive and page.Alive and videoRealm==runtime and runtime.Alive then loop:Checkpoint()end end)end
   else
    loop:QueueTask(function()if not alive or not page.Alive or videoRealm~=runtime or not runtime.Alive then return end;loop:Checkpoint();if alive and page.Alive then callback()end end)
   end
   return true
  end
  return false
 end
 selectionWake=function()
  if not videoStarted or videoWake or videoRunning or not alive or not page.Alive then return end
  videoWake=true;taskAPI.defer(function()
   videoWake=false;if not alive or not page.Alive then return end;videoRunning=true
   local ok,message=pcall(Work.runFor,page,function()
    while alive and page.Alive and queued(videoStable)do
     Work.checkpoint();if not alive or not page.Alive then break end
     local fn=take(videoStable);if fn then fn()end
    end
    if alive and page.Alive then local fn=take(videoTasks);if fn then fn()end end
   end);videoRunning=false
   if not ok then if not alive and Work.isCancelled(message)then return end;error(message,0)end
   if queued(videoTasks)or queued(videoStable)then selectionWake()end
  end)
 end
 local function selectionQueue(list,callback)
  if not alive or not page.Alive then return end
  if videoStarted and realmQueue(list,callback)then return end
  list.Tail+=1;list[list.Tail]={Callback=callback};selectionWake()
 end
 queueDocumentBoundary=function(r,kind,phase)
  if not alive or not page.Alive or not r.Item or registered[r.Item]~=r then return end
  local entry={Record=r,Epoch=r.SelectionEpoch,Generation=r.Generation,Revision=r.DocumentRevision,Kind=kind,Phase=phase}
  r.DocumentBoundaries=r.DocumentBoundaries or{};r.DocumentBoundaries[entry]=true
  selectionQueue(videoTasks,function()
   local record=entry.Record;entry.Record=nil
   if record and record.DocumentBoundaries then record.DocumentBoundaries[entry]=nil end
   local item=record and record.Item
   local function active()return item and current(item,record,entry.Generation)and record.SelectionEpoch==entry.Epoch and record.DocumentRevision==entry.Revision and record.Phase==entry.Phase end
   if not active()then return end
   if entry.Kind=="data"or entry.Kind=="suspend"then
    -- IsLoaded/Loaded is the existing mapped-host data proxy. This task does
    -- not assert an exact decoder first-frame/native streaming boundary.
    events:Emit(item.Node,if entry.Kind=="data"then"loadeddata"else"suspend",data(item),{Bubbles=false,Cancelable=false})
    if not active()then return end
   end
   if entry.Kind~="suspend"then documentBarrier(record,false,false)end
  end)
 end

 -- Public VIDEO services use this existing registration/selection owner.
 local VideoState=require(script.Parent.Parent.HTML.VideoState)
 local videoServices=require(script.Parent.VideoServices).new({
  Owner=api,
  Lookup=function(node,item)
   item=item or byNode[node];local r=item and registered[item]
   if not alive or not page.Alive or not r or item.MediaKind~="video"or not item.VideoSelection or not current(item,r,r.Generation)then return nil,nil end
   return item,r
  end,
  Current=function(lease,stamp)
   return current(lease.Item,lease.Registration,stamp.Generation)and lease.Registration.SelectionEpoch==stamp.Epoch and native(lease.Item)==stamp.Object
  end,
  Queue=function(fn)selectionQueue(videoTasks,fn)end,
  Refresh=function(item)
   if page.LazyMedia then page.LazyMedia:Resume(item.Node,"Media")end
   api:Refresh(item,{src=true},true)
  end,
  Fetch=function(r)videoSelection:Fetch(r)end,
  Read=read,Present=presentation,
  Emit=function(item,kind)events:Emit(item.Node,kind,data(item),{Bubbles=false,Cancelable=false})end,
 })
 videoSignal=function(item,kind)videoServices:Signal(item,kind)end
 for _,key in {"VideoBind","VideoSnapshot","VideoSet","VideoCommand","VideoCanPlayType"}do api[key]=videoServices[key]end

 local function selected(r,epoch,generation)
  if not videoSelection:Current(r,epoch,generation)then return end
  local item=r.Item;local resolver=page.ResolveVideo;local asset
  if resolver then asset=resolver(r.Raw);if not videoSelection:Current(r,epoch,generation)then return end;if asset==nil then asset=resolver(r.Current);if not videoSelection:Current(r,epoch,generation)then return end end end
  item.Source,item.SelectedSource=asset,r.Raw;item.SourceGeneration=generation
  r.ReadyGeneration=nil;r.BoundGeneration=nil;r.RequestedGeneration=nil;r.MetadataReached=false
  videoSignal(item,"selected")
  item.MetadataEmitted=false;item.LoadStarted=false;item.LoadFailed=false;item.LoadError=nil
  item.VideoWidth,item.VideoHeight=0,0;item.VideoFrameAvailable=false;presentation(item)
  if not willLazy(item.Node)then applyVideoSource(item,r)end
 end
 videoSelection=Selection.new({
  Alive=function(r)return alive and page.Alive and r.Item~=nil and not r.Item.StreamPlayer and registered[r.Item]==r and current(r.Item,r,r.Generation)end,
  BeforeSelect=function(r)
   if r.Phase=="selecting"or r.Phase=="resuming"then r.DelayEligible=not willLazy(r.Node)end
   documentBarrier(r,false,r.DelayEligible~=false)
  end,
  QueueTask=function(fn)selectionQueue(videoTasks,fn)end,QueueStable=function(fn)selectionQueue(videoStable,fn)end,
  Dispatch=function(node,kind)if alive and page.Alive then events:Emit(node,kind,{},{Bubbles=false,Cancelable=false})end end,
  Changed=function(r)
   local item=r.Item;item.Loading=r.Loading;item.LoadStarted=r.Network~=0;MediaBox.paint(item)
   if r.Phase=="empty"then documentBarrier(r,false,false)
   elseif r.Phase=="deferred"or r.Phase=="waiting"then queueDocumentBoundary(r,"release",r.Phase)
   elseif r.Phase=="resuming"then r.DelayEligible=not willLazy(r.Node);documentBarrier(r,r.DelayEligible,r.DelayEligible)
   elseif r.Phase=="fetch"or r.Phase=="source-error"then documentBarrier(r,false,r.DelayEligible~=false)end
  end,
  Resolve=function(node,raw)local resolve=if sourceServices.ResolveVideoSourceURL then sourceServices.ResolveVideoSourceURL else URLResolver.resolve;return resolve(page,node,raw)end,
  GetViewport=function()return if page.GeometryViewport then page:GeometryViewport()else{}end,
  CanLoad=function(raw,url,r)
   local resolver=page.ResolveVideo;if not resolver then return false end
   local epoch,generation=r.SelectionEpoch,r.Generation;local asset=resolver(raw)
   if not videoSelection:Current(r,epoch,generation)then return nil end
   if asset~=nil then return true end
   return resolver(url)~=nil
  end,
  CanRenderSourceType=function(raw,parsed)return if sourceServices.CanRenderSourceType then sourceServices.CanRenderSourceType(raw,parsed)else nil end,
  Selected=selected,
  Defer=function(r,resume)
   if not willLazy(r.Node)then return false end
   local epoch,generation=r.SelectionEpoch,r.Generation
   r.Phase="lazy";r.Loading=false;r.Network=1;r.Item.Loading=false
   cancelLazy(r)
   r.CancelLazy=page.LazyMedia:Defer(r.Node,"Media",function()
    r.CancelLazy=nil
    if videoSelection:Current(r,epoch,generation)then resume()end
   end)
   MediaBox.paint(r.Item);documentBarrier(r,false,false)
   return true
  end,
  Resume=function(r)return r.Phase=="lazy"and page.LazyMedia and page.LazyMedia:Resume(r.Node,"Media")or false end,
  ShouldDefer=function(r)return r.Item.Preload=="none"and not r.Item.PendingPlay and not r.Item.PendingAutoplay end,
  Suspend=function(r)queueDocumentBoundary(r,"suspend","deferred")end,
  DirectFailure=function(r,reason)
   local epoch,generation=r.SelectionEpoch,r.Generation;local item=r.Item;applyVideoSource(item,r)
   if videoSelection:Current(r,epoch,generation)then failed(item,if reason=="empty"then"The video src attribute is empty"else"The video source URL is invalid",r,generation)end
  end,
  Fetch=function(r,epoch,generation)if videoSelection:Current(r,epoch,generation)then requestVideoLoad(r.Item)end end,
 })

 local function clearStream(item,r)
  local player=item.StreamPlayer
  item.StreamPlayer=nil;item.StreamVideoGui=nil;item.StreamSource=nil
  if r then r.StreamSource=nil end
  if player then player:Destroy()end
 end
 function api:VideoSetSource(node,state,source)
  node.MediaStreamSource=source
  local item=byNode[node];local r=item and registered[item]
  if not alive or not page.Alive or not r or item.MediaKind~='video'or not current(item,r,r.Generation)then return nil end
  if source~=nil and item.StreamSource==source then return nil end
  if source==nil and not item.StreamPlayer then return nil end
  if not item.VideoSelection then
   item.VideoSelection=r;r.Node=node;r.Item=item;r.SelectionEpoch=0;r.Network=0
   r.PublicState=state or VideoState.ensure(node);api:VideoBind(node,r.PublicState)
  end
  local object=native(item)
  for _,connection in r.Connections do connection:Disconnect()end;table.clear(r.Connections)
  pcall(function()object:Pause()end)
  cancelLazy(r);videoSelection:Invalidate(r);r.SelectionEpoch+=1;r.Generation+=1
  clearStream(item,r)
  r.ReadyGeneration=nil;r.BoundGeneration=nil;r.RequestedGeneration=nil;r.SourceInvalidated=nil
  r.Mode=nil;r.Candidate=nil;r.Gap=nil;r.Current='';r.Raw='';r.Specified=source~=nil;r.Waiting=false;r.AttemptFailed=false;r.MetadataReached=false
  item.Source=nil;item.SelectedSource='';item.Playing=false;item.Ended=false;item.CurrentTime=0;item.Duration=0
  item.VideoWidth=0;item.VideoHeight=0;item.VideoFrameAvailable=false;item.MetadataEmitted=false
  item.LoadStarted=false;item.LoadFailed=false;item.LoadError=nil;item.Loading=false
  item.HasPlayed=false;item.ShowPoster=true;item.PendingAutoplay=node.Attributes.autoplay~=nil
  local public=r.PublicState
  if public then public.Current=''end
  item.PendingPlay=public and public.Network==0 and not public.Paused or false
  if source==nil then
   item.RateSupported=item.UsingVideoPlayer==true
   r.Phase='selecting';r.Network=2
   videoSignal(item,'reset');presentation(item)
   documentBarrier(r,not willLazy(node),false)
   videoSelection:Begin(r,r.SelectionEpoch,function(record)applyVideoSource(record.Item,record)end)
   return nil
  end
  r.Mode='stream';r.Phase='fetch';r.Network=2;r.StreamSource=source
  item.StreamSource=source;item.Duration=math.huge;item.RateSupported=false
  videoSignal(item,'reset');documentBarrier(r,false,false)
  local generation=r.Generation
  local player
  player=StreamVideo.new(source,item.StreamSurfaceGui or item.BoxGui,function(kind,activePlayer)
   if not current(item,r,generation)or item.StreamPlayer~=activePlayer then return end
   item.StreamVideoGui=activePlayer.Root
   if kind=='error'then failed(item,activePlayer.Error,r,generation);return end
   if kind=='ended'then
    item.Playing=false;item.Ended=true;item.PendingPlay=false;item.PendingAutoplay=false
    videoSignal(item,'ended');presentation(item);events:Emit(node,'ended',data(item),{Bubbles=false,Cancelable=false});return
   end
   if activePlayer.Active then
    if r.ReadyGeneration~=generation then
     r.Phase='fetch';ready(item,r,generation)
     if current(item,r,generation)then playPending(item,r,generation)end
    else dimensions(item,r,generation)end
   end
   if current(item,r,generation)then api:RefreshPresentation(item)end
  end)
  item.StreamPlayer=player;r.BoundGeneration=generation
  player:Refresh()
  if current(item,r,generation)and not player.Active and not player.Error then
   item.Loading=false;item.VideoFrameAvailable=false;r.Phase='ready';r.Network=1
   videoSignal(item,'ended');presentation(item)
  end
  return nil
 end

	local function initializeItem(item,batch)
		local registration={Connections={},Generation=1,BoundGeneration=1};registered[item]=registration
  if item.MediaKind=="video"and page.ResolveVideo then registration.Node=item.Node;registration.Item=item;registration.SelectionEpoch=1;registration.Network=0;registration.Phase="selecting";registration.Loading=false;registration.DelayEligible=not willLazy(item.Node);item.VideoSelection=registration;item.Source=nil;item.SelectedSource=""
   local lease=reservations.Nodes[item.Node]
   if lease then
    -- Transfer before notifying: no intermediate zero or double count.
    releaseReservation(item.Node,lease,false)
    reservations.OwnerCount+=1;registration.DocumentBlocking=true;registration.BootstrapAdopted=true
   end
   local beforeGeneration,beforeEpoch=registration.Generation,registration.SelectionEpoch
   documentBarrier(registration,registration.DelayEligible,false)
   if not current(item,registration,beforeGeneration)or registration.SelectionEpoch~=beforeEpoch then return end
  end
		if item.VideoSelection then
   local state=VideoState.ensure(item.Node);registration.PublicState=state;api:VideoBind(item.Node,state)
  end
		local connections=registration.Connections
		item.Playing=false;item.Ended=false;item.CurrentTime=0;item.Duration=0;item.Muted=item.Node.Attributes.muted~=nil;item.Volume=1;item.Captions=false;item.HasPlayed=false;item.ShowPoster=true;item.VideoFrameAvailable=false
		if item.MediaKind=='audio'and page.NativeMediaResources and page.NativeMediaResources.Alive==false then
   item.Source=nil;item.SelectedSource="";item.Loading=false;item.LoadFailed=true;item.LoadError="Native audio owner stopped"
   item.Sound=nil;item.AudioSession=nil;item.PressedAction=nil;item.HoverAction=nil;item.FocusVisible=false
   MediaBox.paint(item);return
  end
  local managedAudio=item.MediaKind=='audio'and(page.ManagedAudioStartup==true or page.NativeMediaResources~=nil or item.Node.AudioHostSession and item.Node.AudioHostSession.Alive==true)
		item.Preload=string.lower(item.Node.Attributes.preload or "auto")
		if item.Preload~="none" and item.Preload~="metadata" and item.Preload~="auto" and item.Preload~="" then item.Preload="auto" end
		item.Loading=item.Source~=nil and item.Preload~="none";item.LoadFailed=false
		local public=registration.PublicState
  if public then item.Muted=public.Muted;item.Volume=public.Volume end
		item.PlaybackRate=if public then public.Rate else 1;item.RateSupported=true
		if item.MutePreloadGui then
			table.insert(batch.Icons,item.MuteGui)
			table.insert(batch.Icons,item.MutePreloadGui)
		end
		item.ParsedTracks={}
		for _,track in item.Tracks or {} do
			if track.Contents then
				local cues,messages=WebVTT.parse(track.Contents)
				local parsed={Track=track,Cues=cues,Diagnostics=messages}
				table.insert(item.ParsedTracks,parsed)
				for _,message in messages do diagnostic(message..": "..track.Source) end
				if track.Default and not item.ActiveTrackIndex then item.ActiveTrackIndex=#item.ParsedTracks end
			else diagnostic("No track mapping for src: "..(track.Source or "")) end
		end
		if item.ActiveTrackIndex then
			item.Captions=true;item.Cues=item.ParsedTracks[item.ActiveTrackIndex].Cues
		end
		local object
		if item.MediaKind=="audio" then
			local session=item.Node.AudioHostSession
			if session and session.Alive then
				session:Attach(item);object=session.Sound
			else
				object=instance.new("Sound")
				item.Sound=object
				object.Name=item.Node.Attributes.id or "HTMLAudio"
				if not managedAudio then object.SoundId=item.Source or ""end
				object.Looped=item.Node.Attributes.loop~=nil
				object.Volume=if item.Muted then 0 else 1
				object.PlaybackSpeed=1
				object.Parent=item.Gui
			end
		else
			object=setupVideoPlayer(item)
			if not object then
				object=item.VideoGui;if not item.VideoSelection then object.Video=item.Source or ""end;object.Looped=item.Node.Attributes.loop~=nil
				object.Volume=if item.Muted then 0 else 1;item.RateSupported=false
			end
			bindVideoEvents(item,registration)
			if page.LoadVideoPoster then page:LoadVideoPoster(item,item.Node.Attributes.poster)end
			if item.Node.MediaStreamSource then api:VideoSetSource(item.Node,registration.PublicState,item.Node.MediaStreamSource)
   elseif item.VideoSelection then registration.BoundGeneration=nil;if item.Node.Attributes.autoplay~=nil then item.PendingAutoplay=true end;videoSelection:Begin(registration,registration.SelectionEpoch)
   elseif item.Source and(item.Preload~="none"or item.Node.Attributes.autoplay~=nil)then table.insert(batch.Players,item)end
		end
		if item.MediaKind=="audio"and not managedAudio then
			if item.Source and item.Preload~="none" and not item.AudioSession then table.insert(batch.Native,object);table.insert(batch.Media,item) end
			connect(connections,object.Loaded,function() if alive and page.Alive then ready(item) end end)
			connect(connections,object.Played,function() if alive and page.Alive then item.HasPlayed=true;item.Ended=false;emit(item,"play") end end)
			connect(connections,object.Paused,function() if alive and page.Alive then emit(item,"pause") end end)
			connect(connections,object.Ended,function() if alive and page.Alive then item.Playing=false;item.Ended=true;emit(item,"ended") end end)
		end
		if managedAudio and not item.AudioSession then item.Loading=false end
		if item.Preload=="none"and not item.AudioSession then item.Loading=false end
		if item.AudioSession and page.NativeMediaResources then page.NativeMediaResources:Attached(item.Node)end
		MediaBox.paint(item)
		if item.Node.Attributes.autoplay~=nil and item.Source and not item.AudioSession and not managedAudio then
			if item.MediaKind=="video"then item.PendingAutoplay=true else
				item.HasPlayed=true;if not item.MetadataEmitted then beginLoad(item)end
				local ok,message=pcall(function()object:Play()end)
				if not ok then diagnostic("Media autoplay failed: "..tostring(message))end
			end
		end
		batch.Registrations[item]=registration
	end
	function api:Add(additions: {any})
		if not alive or not page.Alive then return end
		local batch={Icons={},Native={},Media={},Players={},Registrations={}}
		for _,item in additions do if not alive or not page.Alive then break end;if not registered[item] then initializeItem(item,batch) end end
		if #batch.Icons>0 then taskAPI.spawn(function()
			if not alive or not page.Alive then return end
			local liveIcons={};for item,registration in batch.Registrations do if registered[item]==registration and item.MutePreloadGui then table.insert(liveIcons,item.MuteGui);table.insert(liveIcons,item.MutePreloadGui) end end
			if #liveIcons==0 then return end
			local ok,message=pcall(function()contentProvider:PreloadAsync(liveIcons)end)
			if not ok and alive and page.Alive then diagnostic("Media control icon preload failed: "..tostring(message)) end
		end)end
		if #batch.Media>0 or #batch.Players>0 then taskAPI.spawn(function()
			if not alive or not page.Alive then return end
			local objects,media={},{}
			for _,item in batch.Media do if registered[item]==batch.Registrations[item] then table.insert(objects,native(item));table.insert(media,item);beginLoad(item) end end
			if #objects>0 and contentProvider and contentProvider.PreloadAsync then
				local ok,message=pcall(function()contentProvider:PreloadAsync(objects)end)
				for _,item in media do if alive and page.Alive and registered[item]==batch.Registrations[item] then if ok then ready(item) else failed(item,message) end end end
			end
			for _,item in batch.Players do if registered[item]==batch.Registrations[item] then requestVideoLoad(item)end end
		end)end
	end
 function api:VideoScriptsReady(runtime)
  if not alive or not page.Alive then return end;videoStarted=true;videoRealm=runtime
  if runtime and runtime.Alive then
   for _,list in {videoStable,videoTasks}do while alive and queued(list)do local fn=take(list);if fn then realmQueue(list,fn)end end end
  else selectionWake()end
 end
 function api:VideoBeforeRemove(node)
  local item=node.Parent and byNode[node.Parent];local r=item and registered[item]
  if r and item.VideoSelection then videoSelection:BeforeRemove(r,node)end
 end
 function api:VideoBeforeInsert(parent,index,count)
  local item=byNode[parent];local r=item and registered[item]
  if r and item.VideoSelection then videoSelection:BeforeInsert(r,index,count)end
 end
 function api:VideoMutation(change)
  if not alive or not page.Alive then return end
  bootstrapMutation(change)
  if not alive or not page.Alive then return end
  if change.Type=="attributes"and not change.AttributeNamespace and change.AttributeName=="loading"and Names.html(change.Target,"video")and page.LazyMedia then page.LazyMedia:AttributeChanged(change.Target)end
  local item=byNode[change.Target];local r=item and registered[item]
  if not r or not item.VideoSelection then return end
  if item.StreamPlayer then return end
  if change.Type=="attributes"and not change.AttributeNamespace and change.AttributeName=="src"and change.Target.Attributes.src~=nil then
   -- Stop exposed old metadata/callbacks in this script, without layout/IO.
   if not r.SourceInvalidated then cancelLazy(r);r.SelectionEpoch+=1;r.Generation+=1;videoSelection:Invalidate(r);r.SourceInvalidated=true end
   local beforeGeneration,beforeEpoch=r.Generation,r.SelectionEpoch
   r.DelayEligible=not willLazy(r.Node);documentBarrier(r,r.DelayEligible,false)
   if not current(item,r,beforeGeneration)or r.SelectionEpoch~=beforeEpoch then return end
   r.ReadyGeneration=nil;r.BoundGeneration=nil;r.RequestedGeneration=nil
   item.VideoWidth,item.VideoHeight=0,0
   videoSignal(item,"reset");if not current(item,r,beforeGeneration)then return end
  elseif change.Type=="childList"then
   if not videoSelection:ResumeWaiting(r)and r.Network==0 and r.Phase=="empty"then
    for _,child in change.AddedNodes or{}do if child.Kind=="Element"and require(script.Parent.Parent.DOM.ElementNames).html(child,"source")then
     local beforeGeneration,beforeEpoch=r.Generation,r.SelectionEpoch
     r.Phase="selecting";r.DelayEligible=not willLazy(r.Node);documentBarrier(r,r.DelayEligible,false)
     if not current(item,r,beforeGeneration)or r.SelectionEpoch~=beforeEpoch then return end
     videoSelection:Begin(r,beforeEpoch);break
    end end
   end
  end
 end
 function api:LoadVideo(id)
  local node=DOM.findById(page.Document,id);local item=node and byNode[node]
  assert(alive and page.Alive and item and registered[item]and item.VideoSelection,"Unknown VIDEO element")
  if page.LazyMedia then page.LazyMedia:Resume(item.Node,"Media")end
  self:Refresh(item,{src=true},true)
 end

	function api:Refresh(item: any,attributes: any,sourceSet: boolean?)
		local registration=registered[item]
		if not registration or not alive or not page.Alive or item.MediaKind~="video"then return end
		if item.StreamPlayer then
   if attributes.autoplay then item.PendingAutoplay=item.Node.Attributes.autoplay~=nil;playPending(item,registration,registration.Generation)end
   if attributes.controls and not item.Controls then if dragItem==item or pressedItem==item then self:Cancel()end;item.HoverAction=nil;item.FocusVisible=false end
   api:RefreshPresentation(item);return
  end
		local object=native(item)
		if attributes.loop then
			if item.UsingVideoPlayer then object.Looping=item.Node.Attributes.loop~=nil else object.Looped=item.Node.Attributes.loop~=nil end
		end
		if attributes.preload then
			item.Preload=string.lower(item.Node.Attributes.preload or "auto")
			if item.Preload~="none"and item.Preload~="metadata"and item.Preload~="auto"and item.Preload~=""then item.Preload="auto"end
		end
		if attributes.controls and not item.Controls then
			if dragItem==item or pressedItem==item then self:Cancel()end
			item.HoverAction=nil;item.FocusVisible=false
		end
		if attributes.autoplay and item.Node.Attributes.autoplay==nil then item.PendingAutoplay=false end
		local reload=attributes.src and(sourceSet or item.Node.Attributes.src~=nil)
		if reload then
			if item.VideoSelection then
    local beforeGeneration,beforeEpoch=registration.Generation,registration.SelectionEpoch
    registration.DelayEligible=not willLazy(item.Node);documentBarrier(registration,registration.DelayEligible,false)
    if not current(item,registration,beforeGeneration)or registration.SelectionEpoch~=beforeEpoch then return end
    cancelLazy(registration)
    if not registration.SourceInvalidated then registration.SelectionEpoch+=1;registration.Generation+=1;videoSelection:Invalidate(registration)end
    registration.SourceInvalidated=nil;registration.Mode=nil;registration.Candidate=nil;registration.Gap=nil;registration.Current=nil;registration.Raw="";registration.Specified=false;registration.Waiting=false;registration.AttemptFailed=false;registration.MetadataReached=false;registration.Phase="selecting";registration.Network=2
    item.Source=nil;item.SelectedSource=""
   else registration.Generation+=1 end
   registration.ReadyGeneration=nil;registration.BoundGeneration=nil;registration.RequestedGeneration=nil
			local generation=registration.Generation
			item.SourceGeneration=registration.Generation
			local public=registration.PublicState
   item.PendingPlay=public and public.Network==0 and not public.Paused or false;item.PendingAutoplay=item.Node.Attributes.autoplay~=nil
   if public then videoSignal(item,"reset");if not current(item,registration,generation)then return end end
			item.Playing=false;item.Ended=false;item.CurrentTime=0;item.Duration=0;item.PlaybackRate=if registration.PublicState then registration.PublicState.DefaultRate else 1;item.HasPlayed=false;item.ShowPoster=true;item.VideoFrameAvailable=false;item.VideoWidth=0;item.VideoHeight=0;presentation(item)
			item.MetadataEmitted=false;item.LoadStarted=false;item.Loading=false;item.LoadFailed=false;item.LoadError=nil;item.CaptionText=nil
			if registration.LoadJob or item.VideoSelection then
				-- An in-flight native load keeps its source binding until it returns;
				-- playback and old callbacks are cancelled immediately meanwhile.
				for _,connection in registration.Connections do connection:Disconnect()end;table.clear(registration.Connections)
				pcall(function()object:Pause()end)
			end
			if not current(item,registration,generation)then return end
			if item.VideoSelection then videoSelection:Begin(registration,registration.SelectionEpoch,function(r)applyVideoSource(r.Item,r)end)
   else applyVideoSource(item,registration)
    if not current(item,registration,generation)then return end
    if not item.Source and item.Node.Attributes.src~=nil then failed(item,"No mapped video source: "..item.SelectedSource,registration,generation)end
   end
		elseif attributes.autoplay and item.Node.Attributes.autoplay~=nil and not item.Playing then item.PendingAutoplay=true end
		if not reload and item.VideoSelection and registration.Phase=="deferred"and(attributes.preload or attributes.autoplay)and(item.Preload~="none"or item.PendingAutoplay)then videoSelection:Fetch(registration)
  elseif (not item.VideoSelection or not reload)and(reload or attributes.preload or attributes.autoplay)then
			requestVideoLoad(item)
			playPending(item,registration,registration.Generation)
		end
		if alive and page.Alive and registered[item]==registration then
			if attributes.controls and fullscreenItem==item and fullscreenOverlay then
				local size=fullscreenOverlay.AbsoluteSize
				MediaBox.fullscreen(item,size.X,size.Y)
			else MediaBox.paint(item)end
		end
	end
	function api:RefreshPresentation(item)
		if not alive or not page.Alive or not registered[item]then return end
		if fullscreenItem==item and fullscreenOverlay then local size=fullscreenOverlay.AbsoluteSize;MediaBox.fullscreen(item,size.X,size.Y)
		elseif item.ContentWidth and item.ContentHeight then MediaBox.arrange(item)else MediaBox.paint(item)end
	end
	function api:VideoDimensions(node)
		local item=byNode[node];local registration=item and registered[item]
		if not alive or not page.Alive or not registration or item.MediaKind~='video'or registration.ReadyGeneration~=registration.Generation then return 0,0 end
		return item.VideoWidth or 0,item.VideoHeight or 0
	end

	local elapsed=0
	connect(connections,runService.Heartbeat,function(delta: number)
		if not alive or not page.Alive then return end
		elapsed+=delta
		if elapsed<0.1 then return end
		local tickElapsed=elapsed
		elapsed=0
		for _,item in items do
			local registration=registered[item]
			if not registration or(item.MediaKind=="video"and registration.ReadyGeneration~=registration.Generation)then continue end
			local object=native(item)
			if item.Playing or (object and playing(item,object)) then
				if item.StreamPlayer and item.StreamPlayer.Playing then item.StreamPlayer.TimePosition+=tickElapsed end
				read(item)
				if not item.AudioSession then events:Emit(item.Node,"timeupdate",data(item))end
			end
		end
	end)

	local function setRate(item: any,rate: number)
		assert(type(rate)=="number" and rate>=0.5 and rate<=2,"Playback rate must be from 0.5 to 2")
		assert(item.RateSupported,"Playback speed is unavailable for this video backend")
		local object=native(item)
		object.PlaybackSpeed=rate
		item.PlaybackRate=rate
		MediaBox.paint(item)
		emit(item,"ratechange")
	end
	local function seek(item: any,ratio: number)
		if item.AudioSession and not item.AudioSession.Ready then return end
		local registration=registered[item]
		if not registration or(item.MediaKind=="video"and registration.ReadyGeneration~=registration.Generation)then return end
		local object=native(item)
		local duration=tonumber(object.TimeLength) or 0
		if duration<=0 then return end
		local previous=tonumber(object.TimePosition)or 0
		local position=duration*math.clamp(ratio,0,1)
		if registration.PublicState then api:VideoSet(item.Node,registration.PublicState,"currentTime",position);return end
		if item.AudioSession then item.AudioSession:Set("currentTime",position)else object.TimePosition=position end
		if item.MediaKind=='video'then item.ShowPoster=false;presentation(item)end
		item.Ended=false
		read(item)
		if item.AudioSession then item.AudioSession:Control("seeking",{CurrentTime=item.CurrentTime,PreviousTime=previous})else emit(item,"seeking")end
	end
	local function setVolume(item: any,volume: number)
		volume=math.clamp(volume,0,1)
		local changed=math.abs(volume-(item.Volume or 1))>0.0001 or item.Muted
		item.Volume=volume
		item.Muted=false
		native(item).Volume=volume
		MediaBox.paint(item)
		if changed then emit(item,"volumechange")end
	end
	local function setTrack(item: any,index: number?)
		local tracks=item.ParsedTracks or {}
		if index and (index<1 or index>#tracks) then error("Unknown media text track") end
		item.ActiveTrackIndex=index
		item.Captions=index~=nil
		item.Cues=if index then tracks[index].Cues else nil
		read(item)
		events:Emit(item.Node,"texttrackchange",data(item))
	end
	local function cycleTrack(item: any)
		local count=#(item.ParsedTracks or {})
		if count==0 then return end
		if not item.Captions then setTrack(item,1)
		elseif (item.ActiveTrackIndex or 1)<count then setTrack(item,(item.ActiveTrackIndex or 1)+1)
		else setTrack(item,nil) end
	end
	local function applyDrag(item: any,action: string,value: number?)
		if value==nil then return end
		if action=="seek" then seek(item,value)
		elseif action=="volume" then setVolume(item,value) end
	end
	local function togglePlayback(item: any)
  local r=registered[item];if r and r.PublicState then api:VideoCommand(item.Node,r.PublicState,if r.PublicState.Paused then"play"else"pause");return end
		if item.AudioSession then item.AudioSession:Request("toggle");return end
  if item.VideoSelection and registered[item].Phase=="error"and not item.Source then item.PendingPlay=false;MediaBox.paint(item);return end
  if item.VideoSelection and registered[item].ReadyGeneration~=registered[item].Generation then item.PendingPlay=not item.PendingPlay;if item.PendingPlay then videoSelection:Fetch(registered[item])else MediaBox.paint(item)end;return end
		local registration=registered[item];local generation=registration.Generation
		local object=native(item)
		if playing(item,object) then
			object:Pause()
			if current(item,registration,generation)then read(item)end
		else
			if item.MediaKind=="video"and registered[item].ReadyGeneration~=registered[item].Generation then
				if item.PendingPlay then item.PendingPlay=false;MediaBox.paint(item);return end
				item.PendingPlay=true
				requestVideoLoad(item)
				return
			end
			if not item.MetadataEmitted then beginLoad(item) end
			local duration=tonumber(object.TimeLength) or 0
			local position=tonumber(object.TimePosition) or 0
			if item.Ended or (duration>0 and position>=duration-0.01) then object.TimePosition=0;item.CurrentTime=0 end
			item.Ended=false;item.HasPlayed=true;item.ShowPoster=false;presentation(item);object:Play()
			if current(item,registration,generation)then read(item)end
		end
	end
	local function toggleMute(item: any)
		item.Muted=not item.Muted
		native(item).Volume=if item.Muted then 0 else item.Volume
		MediaBox.paint(item)
		emit(item,"volumechange")
	end
	local function exitFullscreen(): boolean
		if not fullscreenItem then return false end
		local item=fullscreenItem
		if fullscreenConnection then fullscreenConnection:Disconnect();fullscreenConnection=nil end
		item.Gui.Parent=item.FullscreenParent
		item.Gui.Position=item.FullscreenPosition
		item.Gui.Size=item.FullscreenSize
		item.Fullscreen=false
		fullscreenItem=nil
		if fullscreenOverlay then fullscreenOverlay:Destroy();fullscreenOverlay=nil end
		MediaBox.arrange(item)
		events:Emit(item.Node,"fullscreenchange",data(item))
		return true
	end
	local function enterFullscreen(item: any): boolean
		if item.MediaKind~="video" or not item.AllowFullscreen then return false end
		if fullscreenItem==item then return true end
		exitFullscreen()
		local layer=item.Gui
		while layer and not layer:IsA("LayerCollector") do layer=layer.Parent end
		if not layer then diagnostic("Video fullscreen unavailable: no LayerCollector ancestor");return false end
		local overlay=instance.new("Frame")
		overlay.Name="HTMLMediaFullscreen";overlay.Active=false;overlay.Selectable=false;overlay.BorderSizePixel=0
		overlay.BackgroundColor3=Color3.fromRGB(0,0,0);overlay.BackgroundTransparency=0
		overlay.Position=UDim2.fromOffset(0,0);overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=1000;overlay.Parent=layer
		item.FullscreenParent,item.FullscreenPosition,item.FullscreenSize=item.Gui.Parent,item.Gui.Position,item.Gui.Size
		item.Gui.Parent=overlay;item.Fullscreen=true
		fullscreenItem,fullscreenOverlay=item,overlay
		local function resize()
			if fullscreenItem~=item then return end
			local size=overlay.AbsoluteSize
			MediaBox.fullscreen(item,size.X,size.Y)
		end
		fullscreenConnection=overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
		resize();events:Emit(item.Node,"fullscreenchange",data(item))
		return true
	end
	function api:Resolve(node: any): any return byNode[node] end
	function api:Hover(item: any?,position: any?)
		if not alive then return end
		if hoveredItem and hoveredItem~=item and hoveredItem.HoverAction~=nil then hoveredItem.HoverAction=nil;MediaBox.paint(hoveredItem) end
		hoveredItem=item
		if item then
			local action=MediaBox.action(item,position)
			local nextAction=if action~="none" then action else nil
			if item.HoverAction~=nextAction then item.HoverAction=nextAction;MediaBox.paint(item) end
		end
	end
	function api:Begin(item: any,position: any): boolean
		if not alive or not page.Alive or not item or not registered[item]or not MediaBox.canControl(item)then return false end
		local action,value=MediaBox.action(item,position)
		if action=="none" then return false end
		pressedItem=item;item.PressedAction=action;MediaBox.paint(item)
		if action~="seek" and action~="volume" then return false end
		dragItem,dragAction=item,action
		applyDrag(item,action,value)
		return true
	end
	function api:Move(position: any): boolean
		if not alive or not dragItem then return false end
		applyDrag(dragItem,dragAction,MediaBox.dragValue(dragItem,dragAction,position))
		return true
	end
	function api:Finish(item: any,position: any): boolean
		if not dragItem or dragItem~=item then return false end
		applyDrag(dragItem,dragAction,MediaBox.dragValue(dragItem,dragAction,position))
		if pressedItem then pressedItem.PressedAction=nil;MediaBox.paint(pressedItem) end
		dragItem,dragAction=nil,nil
		pressedItem=nil
		return true
	end
	function api:Cancel()
		if pressedItem then pressedItem.PressedAction=nil;MediaBox.paint(pressedItem) end
		dragItem,dragAction,pressedItem=nil,nil,nil
	end
	function api:Activate(item: any,position: any)
		if not alive or not page.Alive or not item or not registered[item]or not MediaBox.canControl(item)then return end
		local object=native(item)
		local action,value=MediaBox.action(item,position)
		if action=="toggle" then togglePlayback(item)
		elseif action=="seek" then seek(item,value or 0)
		elseif action=="speed" and item.RateSupported then
			local index=1
			for current,rate in RATES do if math.abs(rate-item.PlaybackRate)<0.001 then index=current;break end end
			setRate(item,RATES[index%#RATES+1])
		elseif action=="mute" then toggleMute(item)
		elseif action=="volume" then setVolume(item,value or 0)
		elseif action=="captions" then cycleTrack(item)
		elseif action=="fullscreen" then if item.Fullscreen then exitFullscreen() else enterFullscreen(item) end end
	end
	function api:Key(item: any,keyCode: any): boolean
		if item and item.Controls==false then return false end
		if not alive or not page.Alive or not item or not registered[item]or not MediaBox.canControl(item)then return false end
		local name=if type(keyCode)=="string" then keyCode else keyCode.Name
		if name=="Space" or name=="Return" then togglePlayback(item)
		elseif name=="Left" or name=="Right" then
			local object=native(item)
			local duration=tonumber(object.TimeLength) or 0
			if duration>0 then seek(item,math.clamp(((tonumber(object.TimePosition) or 0)+(if name=="Left" then -5 else 5))/duration,0,1)) end
		elseif name=="Up" or name=="Down" then setVolume(item,(item.Volume or 1)+(if name=="Up" then 0.1 else -0.1))
		elseif name=="M" then toggleMute(item)
		elseif name=="C" and #(item.ParsedTracks or {})>0 then cycleTrack(item)
		elseif name=="F" and item.AllowFullscreen then if item.Fullscreen then exitFullscreen() else enterFullscreen(item) end
		else return false end
		return true
	end
	local function itemFor(id: string): any
		local node=DOM.findById(page.Document,id);local item=node and byNode[node]
		assert(not(item and item.MediaKind=="audio"and page.NativeMediaResources and page.NativeMediaResources.Alive==false),"Native audio owner stopped")
		assert(alive and page.Alive and item and registered[item],"Unknown media element")
		return item
	end
	function api:Play(id: string)
		local item=itemFor(id)
  local r=registered[item];if r and r.PublicState then api:VideoCommand(item.Node,r.PublicState,"play");return end
		if item.AudioSession then item.AudioSession:Request("play");return end
  if item.VideoSelection and registered[item].Phase=="error"and not item.Source then item.PendingPlay=false;MediaBox.paint(item);return end
  if item.VideoSelection and registered[item].ReadyGeneration~=registered[item].Generation then item.PendingPlay=true;videoSelection:Fetch(registered[item]);return end
		if item.Source then
			local object=native(item)
			if item.MediaKind=="video"and registered[item].ReadyGeneration~=registered[item].Generation then
				item.PendingPlay=true
				requestVideoLoad(item)
				return
			end
			if not item.MetadataEmitted then beginLoad(item) end
			local duration=tonumber(object.TimeLength) or 0
			local current=tonumber(object.TimePosition) or 0
			if item.Ended or (duration>0 and current>=duration-0.01) then object.TimePosition=0;item.CurrentTime=0 end
			item.Ended=false;item.HasPlayed=true;item.ShowPoster=false;presentation(item);object:Play();read(item)
		end
	end
	function api:Pause(id: string)
		local item=itemFor(id)
  local r=registered[item];if r and r.PublicState then api:VideoCommand(item.Node,r.PublicState,"pause");return end
		if item.AudioSession then item.AudioSession:Request("pause");return end
		item.PendingPlay=false;item.PendingAutoplay=false
		native(item):Pause();read(item)
	end
	function api:SetRate(id: string,rate: number) setRate(itemFor(id),rate) end
	function api:SetVolume(id: string,volume: number) assert(type(volume)=="number" and volume>=0 and volume<=1,"Volume must be from 0 to 1");setVolume(itemFor(id),volume) end
	function api:SetTextTrack(id: string,selector: any)
		local item=itemFor(id)
		if selector==nil or selector==false or selector==0 or selector=="off" then setTrack(item,nil);return end
		if type(selector)=="number" then setTrack(item,math.floor(selector));return end
		for index,entry in item.ParsedTracks or {} do
			local track=entry.Track
			if selector==track.Label or selector==track.Language or selector==track.Source then setTrack(item,index);return end
		end
		error("Unknown media text track")
	end
	function api:EnterFullscreen(id: string): boolean return enterFullscreen(itemFor(id)) end
	function api:ExitFullscreen(): boolean return exitFullscreen() end
	function api:State(id: string): any
		local item=itemFor(id);read(item)
		local entry=if item.ActiveTrackIndex then item.ParsedTracks[item.ActiveTrackIndex] else nil
		return {CurrentTime=item.CurrentTime,Duration=item.Duration,Playing=item.Playing,Muted=item.Muted,Volume=item.Volume,Captions=item.Captions,TextTrack=entry and entry.Track or nil,PlaybackRate=item.PlaybackRate,Source=item.SelectedSource,Loading=item.Loading,Error=item.LoadError,Fullscreen=item.Fullscreen==true}
	end
	function api:Remove(removals: {any})
  local previousClosing=closingNotifications;local closing=previousClosing or{};closingNotifications=closing
  for _,item in removals do
   local registration=registered[item];if not registration then continue end
   -- Take the retiring slots before any external notification. A callback may
   -- publish a new registration on this same retained renderer item.
   registered[item]=nil
   local selection=item.VideoSelection;local public=registration.PublicState
   local session,sound,player,objects,frame=item.AudioSession,item.Sound,item.VideoPlayer,item.VideoObjects,item.VideoGui
   local oldConnections=registration.Connections;registration.Connections={}
   if selection==registration then item.VideoSelection=nil end
   item.AudioSession=nil;item.Sound=nil;item.VideoPlayer=nil;item.VideoObjects=nil
   item.Playing=false;item.Loading=false;item.LoadInProgress=false;item.PendingPlay=false;item.PendingAutoplay=false
   closeAttempt(closing,function()clearStream(item,registration)end)
   local removedPublic=public and public.Backend and public.Backend.Registration==registration
   if removedPublic then public.Backend=nil;public.Playing=false;public.Paused=true end
   if dragItem==item then dragItem,dragAction=nil,nil end
   if pressedItem==item then pressedItem=nil end
   if hoveredItem==item then item.HoverAction=nil;hoveredItem=nil end
   if selection then
    closeAttempt(closing,function()cancelLazy(registration)end)
    closeAttempt(closing,function()documentBarrier(registration,false,false)end)
    closeAttempt(closing,function()videoSelection:Invalidate(registration)end)
    registration.Item=nil;registration.Node=nil
   end
   registration.LoadJob=nil;registration.RequestedGeneration=nil
   for _,connection in oldConnections do closeAttempt(closing,function()connection:Disconnect()end)end
   table.clear(oldConnections)
   if item.MediaKind=='video'and page.RemoveVideoPoster then closeAttempt(closing,function()page:RemoveVideoPoster(item)end)end
   if fullscreenItem==item then closeAttempt(closing,exitFullscreen)end
   -- Preserve the existing best-effort native release policy, but always
   -- release the captured old objects, never a reentrant replacement's slots.
   if session then closeAttempt(closing,function()session:Detach(item)end)
   elseif sound then
    pcall(function()if sound.Stop then sound:Stop()else sound:Pause()end end)
    pcall(function()sound:Destroy()end)
   end
   if player then
    pcall(function()player:Pause()end);pcall(function()player:Unload()end)
    destroyAll(objects or{})
   end
   -- The retained fallback frame is shared across registrations. A native
   -- property/method callback may have rebound it; do not clear that binding.
   if frame and registered[item]==nil then
    pcall(function()frame:Pause()end)
    if registered[item]==nil then pcall(function()frame.Video=""end)end
   end
   if removedPublic then closeAttempt(closing,function()VideoState.notify(public,"removed")end)end
  end
  closingNotifications=previousClosing
  if not previousClosing and closing.Failed then error(closing.Value,0)end
 end
	function api:Destroy()
		if not alive then return end
  alive=false
  local previousClosing=closingNotifications;local closing=previousClosing or{};closingNotifications=closing
  closeAttempt(closing,exitFullscreen)
  local removals={};for item in registered do table.insert(removals,item)end
  closeAttempt(closing,function()self:Remove(removals)end)
  if reservations.Owner==api then reservations.Owner=nil end
  closeAttempt(closing,destroyReservations);closeAttempt(closing,resourcesChanged)
  closeAttempt(closing,function()videoSelection:Destroy()end);videoServices:Destroy()
  for _,list in {videoTasks,videoStable}do
   for index=list.Head,list.Tail do local entry=list[index];if entry then entry.Callback=nil end end
   table.clear(list);list.Head,list.Tail=1,0
  end
  if hoveredItem then hoveredItem.HoverAction=nil end
  dragItem,dragAction,pressedItem,hoveredItem=nil,nil,nil,nil
  local oldConnections=connections;connections={}
  for _,connection in oldConnections do closeAttempt(closing,function()connection:Disconnect()end)end
  table.clear(oldConnections)
  closingNotifications=previousClosing
  if not previousClosing and closing.Failed then error(closing.Value,0)end
 end
	page:AddCleanup(function() api:Destroy() end)
 reservations.Owner=api
	page.Media=api
	function page:LoadVideo(id: string)api:LoadVideo(id)end
	function page:PlayMedia(id: string) api:Play(id) end
	function page:PauseMedia(id: string) api:Pause(id) end
	function page:SetMediaPlaybackRate(id: string,rate: number) api:SetRate(id,rate) end
	function page:SetMediaVolume(id: string,volume: number) api:SetVolume(id,volume) end
	function page:SetMediaTextTrack(id: string,selector: any) api:SetTextTrack(id,selector) end
	function page:EnterMediaFullscreen(id: string): boolean return api:EnterFullscreen(id) end
	function page:ExitMediaFullscreen(): boolean return api:ExitFullscreen() end
	function page:GetMediaState(id: string): any return api:State(id) end
	-- Publish the complete owner before the first acquisition notification.
	-- The zero-item facade retains these same methods after its upgrade.
	api:Add(items)
	return api
end

return MediaRuntime
