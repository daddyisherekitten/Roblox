--!strict
-- Canonical audio data/selection controller; no VM, page factory or author code.
local Names=require(script.Parent.Parent.DOM.ElementNames)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local MediaSelection=require(script.Parent.MediaSelection)
local AudioState={ErrorBrand={},RangeBrand={}}
local load,play,pause,hostEvent,fetch,failCandidate
local function alive(r)return r.Alive and not r.Stopped and r.OwnerLease and r.OwnerLease.Alive end
local function capture(r)return {Owner=r.OwnerLease,OwnerEpoch=r.OwnerEpoch,Epoch=r.SelectionEpoch,Generation=r.Generation}end
local function unchanged(r,stamp,handle)return alive(r)and r.OwnerLease==stamp.Owner and r.OwnerEpoch==stamp.OwnerEpoch and r.SelectionEpoch==stamp.Epoch and r.Generation==stamp.Generation and(handle==nil or r.Handle==handle)end
local function preload(node)local value=(node.Attributes.preload or "metadata"):lower();return if value=="none"or value=="metadata"or value=="auto"then value elseif value==""then "auto"else "metadata"end
local function errorData(r,code,message)r.ErrorVersion=(r.ErrorVersion or 0)+1;return {Code=code,Message=message,Version=r.ErrorVersion}end
local function settleTokens(r,tokens,name,message)local origin=r.OriginLease;if origin and origin.Alive and origin.Settle then origin.Settle(tokens,name,message)end end
local function cancelSlots(lease,r)
 for entry in lease.Slots do if entry.State==r then entry.State=nil;entry.Action=nil;lease.Slots[entry]=nil end end
end
local function enqueue(r,kind,action)
 local lease=if kind=="Media"then r.OriginLease else r.OwnerLease
 if not lease or not lease.Alive or not alive(r)then return false end
 local entry={State=r,Action=action,OwnerEpoch=r.OwnerEpoch,Kind=kind};lease.Slots[entry]=true
 local function deliver()
  lease.Slots[entry]=nil;local state,operation=entry.State,entry.Action;entry.State=nil;entry.Action=nil
  if state and operation and lease.Alive and alive(state)and(if kind=="Media"then state.OriginLease==lease else state.OwnerLease==lease and state.OwnerEpoch==entry.OwnerEpoch)then operation(state)end
 end
 local scheduler=if kind=="Media"then lease.QueueTask elseif kind=="Stable"then lease.QueueStable else lease.QueueProgress
 local ok,result=pcall(scheduler,deliver)
 if not ok or result==false then lease.Slots[entry]=nil;entry.State=nil;entry.Action=nil;if not ok then error(result,0)end end
 return result
end
local function queue(fn,r)return enqueue(r,"Media",function()fn()end)end
local function takeStable(lease,r)
 local actions={};for entry in lease.Slots do if entry.State==r and entry.Kind=="Stable"then table.insert(actions,entry.Action);entry.State=nil;entry.Action=nil;lease.Slots[entry]=nil end end
 return actions
end
local function dispatchAt(node,kind,r)local owner=r.OwnerLease;if alive(r)and owner.Dispatch then owner.Dispatch(node,kind)end end
local function dispatch(r,kind)dispatchAt(r.Node,kind,r)end
local function emit(r,kind,generation)enqueue(r,"Media",function(state)if not generation or state.Generation==generation then dispatch(state,kind)end end)end
local function retain(r)
 local owner=r.OwnerLease;if not owner or not owner.Alive then return end
 if r.Loading or r.Playing or #r.Plays>0 then owner.Active[r]=true else owner.Active[r]=nil end
 local blocking=alive(r)and r.Loading and r.Node and ShadowTree.Connected(r.Node,owner.Document)
 if blocking~=(r.Blocking==true)then r.Blocking=blocking;owner.Pending+=if blocking then 1 else -1;if owner.Changed then owner.Changed(owner.Pending)end end
end
local function rejectPlays(r,name,message)local waiting=r.Plays;r.Plays={};retain(r);settleTokens(r,waiting,name,message)end
local function settle(r,entry)if entry.Settled then return end;entry.Settled=true;local waiting=entry.Waiting;entry.Waiting=nil;settleTokens(r,waiting,entry.Name,entry.Message)end
local function settleQueued(r)local entries=r.Settlements;r.Settlements={};for _,entry in entries do settle(r,entry)end end
local function queueSettlement(r,waiting,name,message,before)
 if #waiting==0 and not before then return end
 local entry={Waiting=waiting,Name=name,Message=message};table.insert(r.Settlements,entry)
 local ok,result=pcall(enqueue,r,"Media",function(state)if entry.Settled then return end;if before then before()end;settle(state,entry);local at=table.find(state.Settlements,entry);if at then table.remove(state.Settlements,at)end end)
 if not ok or result==false then
  local tokens=if entry.Settled then nil else entry.Waiting;entry.Waiting=nil;entry.Settled=true;local at=table.find(r.Settlements,entry);if at then table.remove(r.Settlements,at)end
  if tokens~=nil and r.OriginLease.Drop then r.OriginLease.Drop(tokens)end;if not ok then error(result,0)end
 end
end
local prepare
 local function snapshot(r)
  if r.Ended or not r.Handle or not r.Handle.Snapshot then return alive(r)end
  local before=capture(r);local handle=r.Handle;local s=handle:Snapshot()
  if not unchanged(r,before,handle)then return false end
  if s and r.Ready>0 then r.Position=s.Position or r.Position end;return true
 end
 local function track(r)
  if r.PlayStart==nil or r.Position<=r.PlayStart then return end
  local start,finish=r.PlayStart,r.Position
  local spans={};local inserted=false
  for _,span in r.Played do
   if span[2]<start then table.insert(spans,span)
   elseif finish<span[1]then if not inserted then table.insert(spans,{start,finish});inserted=true end;table.insert(spans,span)
   else start=math.min(start,span[1]);finish=math.max(finish,span[2])end
  end
  if not inserted then table.insert(spans,{start,finish})end;r.Played=spans
 end
 hostEvent=function(r,event)
  if not alive(r) or event.Kind~="control"and(event.Generation~=r.Generation or r.AttemptFailed)then return end
  if event.Kind=="loaded"then
   if r.Phase~="fetch"then return end;local before=capture(r);r.MetadataReached=true;r.Phase="ready"
   r.Loading=false;r.Network=1;r.Ready=4;r.Duration=event.Duration or 0
   if r.DefaultStart>0 then r.Position=r.DefaultStart end;r.DefaultStart=0
   r.Position=math.clamp(r.Position,0,r.Duration)
   emit(r,"durationchange",r.Generation);emit(r,"loadedmetadata",r.Generation);emit(r,"loadeddata",r.Generation);emit(r,"canplay",r.Generation);emit(r,"canplaythrough",r.Generation)
   if not unchanged(r,before)then return end
   local handle=r.Handle;if handle then handle:Set("currentTime",r.Position)end
   if not unchanged(r,before,handle)then return end
   if not r.Paused or r.CanAutoplay and r.Node.Attributes.autoplay~=nil then
    if r.Paused then r.Paused=false;emit(r,"play",r.Generation)end
    handle:Play(r.Intent)
   end
  elseif event.Kind=="error"then
   if r.Mode=="children"and not r.MetadataReached and r.Phase=="fetch"then failCandidate(r);return end
   r.AttemptFailed=true;r.Phase="error"
   r.Loading=false;r.Playing=false;r.Network=3;r.Ready=0;r.Error=errorData(r,event.Code or 4,event.Message or "Audio source is unavailable")
   emit(r,"error",r.Generation);rejectPlays(r,"NotSupportedError","Audio source could not be played")
  elseif event.Kind=="playing"then
   if r.Ready==0 or r.Paused or event.Intent~=r.Intent then return end
   local began=not r.Playing
   r.Ended=false;r.Playing=true;if began then r.PlayStart=r.Position end
   local waiting=r.Plays;r.Plays={}
   queueSettlement(r,waiting,nil,nil,function()if began then dispatch(r,"playing")end end)
  elseif event.Kind=="ended"then
   if not r.Playing then return end
   r.Position=r.Duration;track(r);r.PlayStart=nil;r.Playing=false;r.Paused=true;r.Ended=true;emit(r,"timeupdate");emit(r,"pause");emit(r,"ended")
  elseif event.Kind=="loop"then
   if not r.Playing then return end
   r.Position=r.Duration;track(r);r.Position=0;r.PlayStart=0;emit(r,"timeupdate",r.Generation)
  elseif event.Kind=="control"then
   if event.Action=="play"or event.Action=="toggle"and r.Paused then play(r,nil)else pause(r)end
  elseif event.Kind=="timeupdate"then if not snapshot(r)then return end;track(r);emit(r,"timeupdate",event.Generation)
  elseif event.Kind=="volumechange"then
   if r.Volume~=event.Volume or r.Muted~=event.Muted then r.Volume=event.Volume;r.Muted=event.Muted;emit(r,"volumechange")end
  elseif event.Kind=="ratechange"then if r.Rate~=event.Rate then r.Rate=event.Rate;emit(r,"ratechange")end
  elseif event.Kind=="seeking"then
   r.Position=event.PreviousTime or r.Position;track(r);r.Position=event.Position or r.Position
   if r.Playing then r.PlayStart=r.Position end
   r.Ended=false;r.Seeking=true;emit(r,"seeking");local generation=r.Generation
   queue(function()if generation==r.Generation then r.Seeking=false;emit(r,"timeupdate");emit(r,"seeked")end end,r)
  end
  retain(r)
 end

 local function bind(r)
  if r.Handle then return true end
  if not alive(r)or not r.OwnerLease.Adapter then return false end
  local owner,ownerEpoch,epoch,generation=r.OwnerLease,r.OwnerEpoch,r.SelectionEpoch,r.Generation
  local weak=setmetatable({r},{__mode="v"})
  local delivered=owner.Adapter:Open(r.Node,function(event)
   local state=weak[1];if state and state.OwnerLease==owner and state.OwnerEpoch==ownerEpoch then enqueue(state,"Progress",function(current)hostEvent(current,event)end)end
  end)
  if not alive(r)or r.OwnerLease~=owner or r.OwnerEpoch~=ownerEpoch or r.SelectionEpoch~=epoch or r.Generation~=generation or r.Handle~=nil then
   if delivered and delivered~=r.Handle and delivered.Alive~=false and delivered.Destroy then delivered:Destroy()end
   return alive(r)and r.Handle~=nil
  end
  r.Handle=delivered;return r.Handle~=nil
 end
 local context={
  Alive=alive,QueueTask=function(fn,r)return enqueue(r,"Media",function()fn()end)end,QueueStable=function(fn,r)return enqueue(r,"Stable",function()fn()end)end,
  Resolve=function(node,raw,r)return r.OwnerLease.Resolve(node,raw)end,
  GetViewport=function(r)return if r.OwnerLease.GetViewport then r.OwnerLease.GetViewport()else{}end,
  Changed=retain,Dispatch=dispatchAt,
  CanLoad=function(raw,url,r)local adapter=r.OwnerLease.Adapter;return if adapter and adapter.CanLoad then adapter:CanLoad(raw,url,r)else nil end,
  CanRenderSourceType=function(raw,parsed,r)local adapter=r.OwnerLease.Adapter;return if adapter and adapter.CanRenderSourceType then adapter:CanRenderSourceType(raw,parsed,r)else nil end,
  Selected=function(r)if r.Handle and r.Handle.Select then r.Handle:Select(r.Current,r.Raw,r.Generation)end end,
  ShouldDefer=function(r)return preload(r.Node)=="none"and r.Paused and #r.Plays==0 and r.Node.Attributes.autoplay==nil end,
  Suspend=function(r)emit(r,"suspend",r.Generation)end,
  DirectFailure=function(r,reason)hostEvent(r,{Generation=r.Generation,Kind="error",Code=4,Message=if reason=="empty"then "The audio src attribute is empty"else "The audio source URL is invalid"})end,
  Fetch=function(r,epoch,generation)
   local bound=bind(r);local selection=r.Controller.Pool
   if not selection:Current(r,epoch,generation)then return end
   if not bound then hostEvent(r,{Generation=generation,Kind="error",Code=4,Message="No Roblox audio adapter is installed"});return end
   for _,setting in {{"volume",r.Volume},{"muted",r.Muted},{"playbackRate",r.Rate},{"loop",r.Node.Attributes.loop~=nil}}do
    r.Handle:Set(setting[1],setting[2]);if not selection:Current(r,epoch,generation)then return end
   end
   r.Handle:Load(r.Current,r.Raw,generation)
  end,
 }
 function AudioState.newPool()return MediaSelection.new(context)end
 failCandidate=function(r)r.Controller.Pool:Fail(r)end
 fetch=function(r)r.Controller.Pool:Fetch(r)end
 load=function(r,force,selectEmpty)
  if not alive(r)then return false end
  local initial=capture(r)
  if r.Node.Attributes.controls~=nil and ShadowTree.Connected(r.Node,r.OwnerLease.Document)and not r.Handle then
   local bound=bind(r);if not unchanged(r,initial)then return false end
   if bound then
    local handle=r.Handle
    for _,setting in {{"volume",r.Volume},{"muted",r.Muted},{"playbackRate",r.Rate},{"loop",r.Node.Attributes.loop~=nil}}do handle:Set(setting[1],setting[2]);if not unchanged(r,initial,handle)then return false end end
    if r.Phase=="deferred"and handle.Select then handle:Select(r.Current,r.Raw,r.Generation);if not unchanged(r,initial,handle)then return false end end
   end
  end
  -- A selected source survives DOM source changes until an explicit load
  -- or direct src write. Controls may still attach its existing handle.
  if not force and r.Network~=0 then return true end
  if not force and not selectEmpty and r.Node.Attributes.src==nil and not MediaSelection.firstSource(r.Node)then r.Raw,r.Specified="",false;return end
  -- Explicit load settles queued Play outcomes before replacing the load.
  -- Their queued callbacks then become inert, including an old playing event.
  if force then settleQueued(r);if not unchanged(r,initial)then return false end end
  r.SelectionEpoch+=1;r.Generation+=1;local epoch=r.SelectionEpoch;local resetting=capture(r);r.Controller.Pool:Invalidate(r)
  r.Mode=nil;r.Candidate=nil;r.Gap=nil;r.Waiting=false;r.AttemptFailed=false;r.MetadataReached=false;r.Phase="selecting"
  if force then
   local hadNetwork=r.Network~=0;local hadData=r.Ready~=0
   if r.Network==1 or r.Network==2 then emit(r,"abort")end;if hadNetwork then emit(r,"emptied")end
   if hadNetwork then
    r.Intent+=1;if r.Handle then local handle=r.Handle;handle:Pause();if not unchanged(r,resetting,handle)then return false end end
    if not r.Paused then rejectPlays(r,"AbortError","Playback was interrupted by a new load");if not unchanged(r,resetting)then return false end end
    r.Paused=true;r.Playing=false;r.PlayStart=nil;r.Played={};r.Ended=false;r.Seeking=false;r.Position=0;r.Duration=0/0;r.Ready=0
    if hadData then emit(r,"timeupdate")end
   end
   if r.Rate~=r.DefaultRate then emit(r,"ratechange")end
   r.CanAutoplay=true;r.Rate=r.DefaultRate;r.Error=r.NoError;r.Loading=false
  end
  -- Resource selection waits for a stable state. It does not perform the
  -- explicit load algorithm's pause/promise/cursor/rate reset.
  r.Network=3;r.Loading=true;retain(r);if not unchanged(r,resetting)then return false end
  r.Controller.Pool:Begin(r,epoch,function(current)if force and current.Handle then current.Handle:Reset(current.Generation)end end);return unchanged(r,resetting)
 end
 prepare=function(r)
  if r.Phase~="deferred"or r.Loading or not r.Specified or r.Raw==""or r.Error~=r.NoError then return end
  -- A hint upgrade or Play resumes the retained selection. Neither starts
  -- resource selection again nor resets its playback cursor/rate.
  r.Loading=true;r.Network=2;retain(r)
  local generation=r.Generation
  enqueue(r,"Progress",function(state)if generation==state.Generation then fetch(state)end end)
 end
 play=function(r,createPromise)
  if not alive(r)then if createPromise then settleTokens(r,{createPromise},"NotSupportedError","Audio owner is unavailable")end;return end
  local token=createPromise
  if r.Error~=r.NoError then if token then settleTokens(r,{token},"NotSupportedError","The audio source is unsupported")end;return nil end
  local loaded=load(r,false,true)
  if loaded==false or not alive(r)or r.Error~=r.NoError then if token then settleTokens(r,{token},if not alive(r)or r.Error~=r.NoError then "NotSupportedError"else "AbortError","Audio playback was superseded during load")end;return end
  if token then table.insert(r.Plays,token)end
  if r.Ended then local before=capture(r);r.Position=0;r.Ended=false;local handle=r.Handle;if handle then handle:Set("currentTime",0)end;if not unchanged(r,before,handle)then return end end
  r.CanAutoplay=false
  if r.Paused then r.Intent+=1;r.Paused=false;emit(r,"play");if r.Ready<3 then emit(r,"waiting")end end
  if r.Playing then
   local waiting=r.Plays;r.Plays={};queueSettlement(r,waiting)
  elseif r.Ready>0 and bind(r)then r.Handle:Play(r.Intent)
  elseif not r.Loading and r.Specified and r.Raw~=""then
   -- preload=none selected a source without preparing it. Play overrides
   -- that hint, without resetting the current play promise.
   prepare(r)
  end
  retain(r);return nil
 end
 pause=function(r,internal)
  if not alive(r)then return end
  if not internal and load(r,false,true)==false then return end;if not snapshot(r)then return end;track(r);r.Intent+=1;r.PlayStart=nil;r.Playing=false;r.CanAutoplay=false
  if not r.Paused then r.Paused=true;emit(r,"timeupdate");emit(r,"pause")end
  local before=capture(r);local waiting=r.Plays;r.Plays={}
  queueSettlement(r,waiting,"AbortError","Playback was interrupted by pause");if not unchanged(r,before)then return end
  local handle=r.Handle;if handle then handle:Pause();if not unchanged(r,before,handle)then return end end
  retain(r);return nil
 end
local Controller={};Controller.__index=Controller
  function Controller:Load(force,selectEmpty)local r=self.State;local node=r.Node;return load(r,force,selectEmpty)end
  function Controller:Play(token)local r=self.State;local node=r.Node;return play(r,token)end
  function Controller:Pause(internal)local r=self.State;local node=r.Node;return pause(r,internal)end
  function Controller:GetData(key)local r=self.State;local node=r.Node;
   if key=="currentTime"then if r.DefaultStart~=0 then return r.DefaultStart end;snapshot(r);return r.Position end
   local field=({volume="Volume",muted="Muted",playbackRate="Rate",defaultPlaybackRate="DefaultRate",duration="Duration",currentSrc="Current",paused="Paused",ended="Ended",seeking="Seeking",readyState="Ready",networkState="Network",error="Error"})[key]
   if field then return r[field]end
   if key=="buffered"or key=="seekable"then return if r.Ready>0 and r.Duration>0 then {{0,r.Duration}}else{} end
   if key=="played"then snapshot(r);track(r);local spans={};for _,span in r.Played do table.insert(spans,table.clone(span))end;return spans end
  end
  function Controller:SetData(key,value)local r=self.State;local node=r.Node;
   if not alive(r)then return {Name="InvalidStateError",Message="Audio owner is unavailable"}end
   if key=="muted"then if r.Muted~=value then r.Muted=value;if r.Handle then r.Handle:Set(key,value)end;emit(r,"volumechange")end;return end
   if key=="volume"and(value<0 or value>1)then return {Name="IndexSizeError",Message="Volume must be between zero and one"}end
   if(key=="playbackRate"or key=="defaultPlaybackRate")and(value<.5 or value>2)then return {Name="NotSupportedError",Message="The Roblox audio backend supports playback rates from 0.5 to 2"}end
   local field=if key=="volume"then "Volume"elseif key=="playbackRate"then "Rate"elseif key=="defaultPlaybackRate"then "DefaultRate"else "Position"
   if key=="currentTime"then
    if r.Ready==0 then r.DefaultStart=value;return end
    local before=capture(r);if not snapshot(r)or not unchanged(r,before)then return end;track(r);value=math.clamp(value,0,r.Duration);r.Seeking=true;r.Ended=false;emit(r,"seeking");local generation=r.Generation
    enqueue(r,"Media",function(state)if generation==state.Generation then state.Seeking=false;emit(state,"timeupdate");emit(state,"seeked")end end)
    if r.Playing then r.PlayStart=value end
   elseif r[field]==value then return end
   r[field]=value;if key~="defaultPlaybackRate"and r.Handle then r.Handle:Set(key,value)end
   if key=="volume"then emit(r,"volumechange")elseif key~="currentTime"then emit(r,"ratechange")end
  end
  function Controller:Changed()local r=self.State;local node=r.Node;retain(r)end
  function Controller:Attribute(key,value)local r=self.State;local node=r.Node;
   if not alive(r)then return end
   if key=="src"and value~=nil then load(r,true)
   elseif key=="controls"and node.Attributes.controls~=nil then load(r,false)
   elseif key=="loop"then if r.Handle then r.Handle:Set("loop",node.Attributes.loop~=nil)end
   elseif key=="preload"and preload(node)~="none"and r.Ready==0 and not r.Loading then if r.Network==0 then load(r,false)else prepare(r)end end
  end
  function Controller:BeforeRemove(child)local r=self.State;local node=r.Node;self.Pool:BeforeRemove(r,child)end
  function Controller:BeforeInsert(index,count)local r=self.State;local node=r.Node;self.Pool:BeforeInsert(r,index,count)end
  function Controller:ResumeWaiting()local r=self.State;local node=r.Node;return self.Pool:ResumeWaiting(r)end
  function Controller:ReleaseOriginRealm(lease)local r=self.State;local node=r.Node;
   if r.OriginLease~=lease then return end
   self.Pool:CancelTasks(r);cancelSlots(lease,r);table.clear(r.Plays)
   for _,entry in r.Settlements do entry.Waiting=nil;entry.Settled=true end;table.clear(r.Settlements);retain(r)
  end
  function Controller:StopOwner(lease,message)local r=self.State;local node=r.Node;
   if r.OwnerLease~=lease or r.Stopped then return end
   r.Stopped=true;r.OwnerEpoch+=1;r.SelectionEpoch+=1;r.Generation+=1;self.Pool:Invalidate(r)
   cancelSlots(lease,r);cancelSlots(r.OriginLease,r)
   r.Loading=false;r.Playing=false;r.Paused=true;r.Ready=0;r.Network=3;r.Error=errorData(r,4,message or "Audio owner was disposed")
   local handle=r.Handle;r.Handle=nil;lease.Active[r]=nil
   local hadError=false;local firstError
   local function attempt(action)local ok,result=pcall(action);if not ok and not hadError then hadError=true;firstError=result end end
   local blocking=r.Blocking;r.Blocking=false;if blocking then lease.Pending-=1 end
   attempt(function()settleQueued(r)end);attempt(function()rejectPlays(r,"AbortError","Audio owner was disposed")end)
   if blocking and lease.Changed then attempt(function()lease.Changed(lease.Pending)end)end
   if handle then attempt(function()local destroy=handle.Destroy;if destroy then destroy(handle)end end)end
   -- Keep the terminal controller association: Ensure must not resurrect it.
   if hadError then error(firstError,0)end
  end
  function Controller:ChangeOwner(nextOwner)local r=self.State;local node=r.Node;
   local old=r.OwnerLease;if old==nextOwner or r.Stopped then return end
   local paused=r.Paused;r.OwnerEpoch+=1;local ownerEpoch=r.OwnerEpoch;local selectionEpoch,generation=r.SelectionEpoch,r.Generation
   cancelSlots(old,r)
   if r.Blocking then
    r.Blocking=false;old.Pending-=1
    local ok,message=pcall(function()if old.Changed then old.Changed(old.Pending)end end)
    if not ok then if r.OwnerLease==old and r.OwnerEpoch==ownerEpoch and not r.Stopped then pcall(self.StopOwner,self,old,"Audio ownership notification failed")end;error(message,0)end
    if r.OwnerLease~=old or r.OwnerEpoch~=ownerEpoch or r.Stopped then return end
    if not old.Alive or not nextOwner.Alive then self:StopOwner(old,"Audio ownership was disposed during transfer");return end
   end
   local stable=takeStable(old,r);cancelSlots(old,r)
   old.States[node]=nil;old.Active[r]=nil
   if old.Removed[r]then old.Removed[r]=nil;nextOwner.Removed[r]=true end
   r.OwnerLease=nextOwner;nextOwner.States[node]=r
   local handle=r.Handle
   if handle then
    local adapter=nextOwner.Adapter
    local lookupOk,transfer=pcall(function()return adapter and adapter.TakeSession end)
    if not lookupOk then if r.OwnerLease==nextOwner and r.OwnerEpoch==ownerEpoch and not r.Stopped then pcall(self.StopOwner,self,nextOwner,"Audio transfer lookup failed")end;error(transfer,0)end
    if r.OwnerLease~=nextOwner or r.OwnerEpoch~=ownerEpoch or r.Stopped then return end
    if not transfer then self:StopOwner(nextOwner,"Unsupported cross-runtime audio adapter transfer");return end
    local weak=setmetatable({r},{__mode="v"})
    local ok,delivered=pcall(transfer,adapter,handle,node,function(event)
     local state=weak[1];if state and state.OwnerLease==nextOwner and state.OwnerEpoch==ownerEpoch then enqueue(state,"Progress",function(current)hostEvent(current,event)end)end
    end)
    if not ok then if r.OwnerLease==nextOwner and r.OwnerEpoch==ownerEpoch then pcall(self.StopOwner,self,nextOwner,"Audio transfer failed")end;error(delivered,0)end
    if r.OwnerLease~=nextOwner or r.OwnerEpoch~=ownerEpoch or r.Stopped then return end
    if delivered~=handle or not nextOwner.Alive then self:StopOwner(nextOwner,"Audio transfer is unavailable");return end
   end
   if r.OwnerLease~=nextOwner or r.OwnerEpoch~=ownerEpoch or not nextOwner.Alive then return end
   for _,action in stable do enqueue(r,"Stable",action);if r.OwnerLease~=nextOwner or r.OwnerEpoch~=ownerEpoch or not alive(r)then return end end
   if r.SelectionEpoch~=selectionEpoch or r.Generation~=generation then retain(r);return end
   -- Captured failed code-4 adoption retains its Error and selection. The
   -- reset/reload profile is scoped to the observed healthy/pending cases.
   if r.Error~=r.NoError then retain(r);return end
   -- Named Chromium UA profile, not a frozen HTML adoption trigger.
   load(r,true)
   if r.OwnerLease==nextOwner and r.OwnerEpoch==ownerEpoch and alive(r)and not paused then play(r,nil)end
   retain(r)
  end
  function Controller:Destroy()local r=self.State;local node=r.Node;
   if r.OriginLease.Alive or r.OwnerLease.Alive then return false end
   self.Pool:Invalidate(r);self.Pool=nil;r.Alive=false
   if node and node.AudioController==self then node.AudioController=nil;node.AudioResourceState=nil end
   r.Node=nil;r.OwnerLease=nil;r.OriginLease=nil;return true
  end

 function AudioState.new(node,origin,owner,noError)
  local r={Alive=true,Node=node,OriginLease=origin,OwnerLease=owner,OwnerEpoch=0,NoError=noError,Generation=0,SelectionEpoch=0,Intent=0,Paused=true,Playing=false,Ended=false,Seeking=false,Volume=1,Muted=node.Attributes.muted~=nil,Rate=1,DefaultRate=1,Position=0,DefaultStart=0,Duration=0/0,Ready=0,Network=0,Current="",Error=noError,Plays={},Settlements={},Played={},Loading=false,CanAutoplay=true,AttemptFailed=false,MetadataReached=false,Waiting=false}
  local controller=setmetatable({State=r,Pool=origin.Pool},Controller);r.Controller=controller;node.AudioController=controller;node.AudioResourceState=r
  owner.States[node]=r;origin.States[node]=r
  return controller
 end
 return AudioState
