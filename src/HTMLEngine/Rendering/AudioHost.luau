--!strict
-- A page-local Sound owner, shared by detached JS Audio and mounted controls.
-- Native callbacks never execute author code. The realm queues them itself.
local MediaBox=require(script.Parent.MediaBox)
local AudioHost={}
	local function current(session,generation,operation)local lifetime=session.CurrentHostLease;return lifetime~=nil and lifetime.Alive and lifetime.Page~=nil and lifetime.Page.Alive and session.Alive and session.Generation==generation and(operation==nil or session.Operation==operation)end
local function paint(session)
 if not current(session,session.Generation)then return end
 local item=session.Item;local object=session.Sound;if not item or item.Sound~=object then return end
 local hostLease,generation,operation=session.CurrentHostLease,session.Generation,session.Operation
 local function matched()return session.CurrentHostLease==hostLease and current(session,generation,operation)and session.Item==item and item.Sound==object and session.Sound==object end
 local playing=object.Playing;if not matched()then return end
 local length=object.TimeLength;if not matched()then return end
 local position=object.TimePosition;if not matched()then return end
 local duration=if session.Ready then tonumber(length)or 0 else 0
 item.Playing=playing==true;item.Duration=duration;item.Ended=session.Ended==true
 item.CurrentTime=if session.Ended then duration else tonumber(position)or 0
 item.Volume,item.Muted,item.PlaybackRate=session.Volume,session.Muted,session.Rate
 item.Loading=session.Loading;item.LoadFailed=session.Error~=nil;item.LoadError=session.Error
 if session.Raw~=nil then item.Source,item.SelectedSource=session.Asset,session.Raw end
 if matched()then MediaBox.paint(item)end
end
	local function notify(session,event)
		if not current(session,session.Generation)then return end
		event.Generation=session.Generation;session.Notify(event);paint(session)
	end
	local function clearLoad(lease)
		local session=lease.Session
		if session then session.Loads[lease]=nil end
		lease.Session=nil;lease.Object=nil;lease.Provider=nil
	end
	local function cancelLoads(session)
		for lease in session.Loads do clearLoad(lease)end
	end
	local function loadCurrent(lease)
		local session=lease.Session
		return session~=nil and current(session,lease.Generation,lease.Operation)
	end
	-- A suspended native frame owns only its Sound and this cancellable slot.
	-- Never capture a session/page local across the yielding PreloadAsync call.
	local function loadNative(lease)
		if not loadCurrent(lease)then clearLoad(lease);return end
		local object,provider=lease.Object,lease.Provider
		local failed=false;local ok,message=pcall(function()
			provider:PreloadAsync({object},function(_,status)if tostring(status):match("Failure")or tostring(status):match("TimedOut")then failed=true end end)
		end)
		if not loadCurrent(lease)then clearLoad(lease);return end
		local session=lease.Session;clearLoad(lease);session.Loading=false
		if ok and not failed and object.IsLoaded==true then session.Ready=true;notify(session,{Kind="loaded",Duration=tonumber(object.TimeLength)or 0})
		else session.Error="Roblox audio load failed: "..tostring(message or "asset unavailable");notify(session,{Kind="error",Code=4,Message=session.Error})end
	end
	local function dispose(session)
		if not session.Alive then return end;session.Alive=false;cancelLoads(session)
		for _,handle in session.Connections do handle:Disconnect()end;table.clear(session.Connections)
		local node=session.Owner[1];if node and node.AudioHostSession==session then node.AudioHostSession=nil end
		table.clear(session.Owner)
		if session.Item then session.Item.AudioSession=nil;session.Item.Sound=nil;session.Item=nil end
		session.Notify=nil;local hostLease=session.CurrentHostLease;session.CurrentHostLease=nil;if hostLease then hostLease.Sessions[session]=nil end
		pcall(function()session.Sound:Stop()end);pcall(function()session.Sound:Destroy()end)
	end

function AudioHost.new(page: any,tree: any,services: any?): any
	services=services or {}
	local instance=services.Instance or Instance
	local tasks=services.Task or task
	local provider=services.ContentProvider or (game and game:GetService("ContentProvider"))
	local runService=services.RunService or (game and game:GetService("RunService"))
	local lifetime={Alive=true,Page=page,Tree=tree,TypePolicy=services.CanRenderSourceType};page=nil;tree=nil;services=nil
	local sessions={};lifetime.Sessions=sessions;lifetime.Tasks=tasks;lifetime.Provider=provider;local api={Alive=true};local connection
	local function living()return lifetime.Alive and lifetime.Page~=nil and lifetime.Page.Alive end
	local function startHeartbeat()
		if connection or not runService then return end
		local elapsed=0
		connection=runService.Heartbeat:Connect(function(delta)
			elapsed+=delta;if elapsed<.25 then return end;elapsed=0
			for session in sessions do
				if not session.Owner[1]then dispose(session)
				elseif session.Sound.Playing then notify(session,{Kind="timeupdate"})end
			end
			if next(sessions)==nil and connection then connection:Disconnect();connection=nil end
		end)
	end
	function api:Open(node,callback)
		assert(self.Alive and living(),"Audio page disposed")
		local existing=node.AudioHostSession
		if existing and existing.Alive then existing.Notify=callback;return existing end
		local item=lifetime.Tree.MediaByNode and lifetime.Tree.MediaByNode[node]
		local fresh=not(item and item.Sound)
		local object=if not fresh then item.Sound else instance.new("Sound")
		local newer=node.AudioHostSession
		if not living()or newer and newer~=existing and newer.Alive then
			if fresh and(not newer or newer.Sound~=object)then pcall(function()object:Destroy()end)end
			return if living()and newer and newer.Alive and node.AudioHostSession==newer then newer else nil
		end
		object.Name=node.Attributes.id or "HTMLAudio";object.Parent=lifetime.Page.Root
		local session={CurrentHostLease=lifetime,Alive=true,Owner=setmetatable({node},{__mode="v"}),Sound=object,Item=item,Notify=callback,Generation=0,Operation=0,Connections={},Loads={},Volume=1,Muted=node.Attributes.muted~=nil,Rate=1,Loading=false}
		node.AudioHostSession=session;sessions[session]=true;if item then item.AudioSession=session end
		local function connect(signal,fn)if signal and signal.Connect then table.insert(session.Connections,signal:Connect(fn))end end
		connect(object.Ended,function(soundId)
			if not object.Playing and(not soundId or soundId==session.Asset)then session.Ended=true;notify(session,{Kind="ended"})end
		end)
		connect(object.DidLoop,function(soundId)if not soundId or soundId==session.Asset then notify(session,{Kind="loop"})end end)
		function session:Snapshot()local duration=tonumber(object.TimeLength)or 0;return {Position=if self.Ended then duration else tonumber(object.TimePosition)or 0,Duration=duration}end
		function session:Pause()if self.Alive then object:Pause();paint(self)end end
		function session:Select(url,raw,generation)
			if not current(self,self.Generation)then return end
			self.Operation+=1;local operation=self.Operation;cancelLoads(self)
			self.Generation=generation;self.Raw=raw;self.Ready=false;self.Ended=false;self.Error=nil;self.Loading=false
			local resolver=self.CurrentHostLease.Page.ResolveAudio;local asset
			if raw~=""and resolver then asset=resolver(raw);if not current(self,generation,operation)then return end;if not asset then asset=resolver(url);if not current(self,generation,operation)then return end end end
			self.Asset=asset;paint(self)
		end
		function session:Reset(generation)
			if not current(self,self.Generation)then return end
			self.Operation+=1;local operation=self.Operation
			cancelLoads(self);self.Generation=generation;self.Asset=nil;self.Raw="";self.Loading=false;self.Error=nil;self.Ended=false;self.Ready=false
			object:Stop();if not current(self,generation,operation)then return end;object.SoundId="";object.TimePosition=0;paint(self)
		end
		function session:Load(url,raw,generation)
			if not current(self,self.Generation)then return end
			-- Caller generations may be reused. Resolver/native reentry still
			-- creates a newer selection which must supersede this operation.
			self.Operation+=1;local operation=self.Operation
			cancelLoads(self)
			self.Generation=generation;self.Raw=raw;self.Error=nil;self.Loading=true;self.Ended=false;self.Ready=false
			local resolver=self.CurrentHostLease.Page.ResolveAudio;local asset
			if resolver then asset=resolver(raw);if not current(self,generation,operation)then return end;if not asset then asset=resolver(url);if not current(self,generation,operation)then return end end end
			local cached=asset~=nil and object.SoundId==asset and object.IsLoaded==true
			self.Asset=asset;object:Stop();if not current(self,generation,operation)then return end;object.TimePosition=0;object.SoundId=asset or "";paint(self)
			if not current(self,generation,operation)then return end
			if not asset then self.Loading=false;self.Error="Audio source has no Roblox asset mapping";notify(self,{Kind="error",Code=4,Message=self.Error});return end
			if cached then self.Loading=false;self.Ready=true;notify(self,{Kind="loaded",Duration=tonumber(object.TimeLength)or 0});return end
			local lease={Session=self,Object=object,Provider=self.CurrentHostLease.Provider,Generation=generation,Operation=operation};self.Loads[lease]=true
			local scheduler=self.CurrentHostLease.Tasks;if scheduler and scheduler.spawn then scheduler.spawn(function()loadNative(lease)end)else loadNative(lease)end
		end
		function session:Play(intent)
			if not self.Alive or not self.Asset or self.Loading then return end
			self.Ended=false
			local ok,message=pcall(function()
				-- Sound:Play resets its cursor. Playing preserves an explicitly
				-- selected position and resumes a paused browser media element.
				if not object.Playing then object.Playing=true end
				if object.Playing then if self.Item then self.Item.HasPlayed=true;self.Item.Ended=false end;notify(self,{Kind="playing",Intent=intent})end
			end)
			if not ok then self.Error=tostring(message);notify(self,{Kind="error",Code=3,Message=self.Error})end;paint(self)
		end
		function session:Set(key,value)
			if not self.Alive then return end
			if key=="volume"then self.Volume=value;object.Volume=if self.Muted then 0 else value
			elseif key=="muted"then self.Muted=value;object.Volume=if value then 0 else self.Volume
			elseif key=="playbackRate"then self.Rate=value;object.PlaybackSpeed=value
			elseif key=="loop"then object.Looped=value
			elseif key=="currentTime"then self.Ended=false;object.TimePosition=value end;paint(self)
		end
		function session:Control(kind,data)
			if kind=="volumechange"then self.Volume=data.Volume;self.Muted=data.Muted;notify(self,{Kind=kind,Volume=self.Volume,Muted=self.Muted})
			elseif kind=="ratechange"then self.Rate=data.PlaybackRate;notify(self,{Kind=kind,Rate=self.Rate})
			elseif kind=="seeking"then self.Ended=false;notify(self,{Kind=kind,Position=data.CurrentTime,PreviousTime=data.PreviousTime})end
		end
		function session:Request(action)notify(self,{Kind="control",Action=action})end
		function session:Attach(nextItem)if not current(self,self.Generation)then return end;self.Item=nextItem;nextItem.AudioSession=self;nextItem.Sound=object;paint(self)end
		function session:Detach(item)if self.Item==item then self.Item=nil end;item.AudioSession=nil;item.Sound=nil end
		function session:Destroy()dispose(self)end
		startHeartbeat();return session
	end
	function api:TakeSession(session,node,callback)
  if not living()or not session or not session.Alive or node.AudioHostSession~=session or session.Owner[1]~=node then return nil end
  local previous=session.CurrentHostLease
  if previous==lifetime then session.Notify=callback;return session end
  if not previous or not previous.Alive or previous.Sessions[session]~=true then return nil end
  session.Operation+=1;local operation=session.Operation;cancelLoads(session)
  previous.Sessions[session]=nil
  local oldItem=session.Item;session.Item=nil
  session.CurrentHostLease=lifetime;sessions[session]=true;session.Notify=callback
  if oldItem then oldItem.AudioSession=nil;oldItem.Sound=nil end
  if not current(session,session.Generation,operation)or session.CurrentHostLease~=lifetime or node.AudioHostSession~=session then return nil end
  local item=lifetime.Tree.MediaByNode and lifetime.Tree.MediaByNode[node]
  if item then
   session.Item=item;item.AudioSession=session
   if not current(session,session.Generation,operation)or session.CurrentHostLease~=lifetime or session.Item~=item or node.AudioHostSession~=session then return nil end
   item.Sound=session.Sound
   if not current(session,session.Generation,operation)or session.CurrentHostLease~=lifetime or session.Item~=item or node.AudioHostSession~=session then return nil end
  end
  session.Sound.Parent=lifetime.Page.Root
  if not current(session,session.Generation,operation)or session.CurrentHostLease~=lifetime or node.AudioHostSession~=session then return nil end
  paint(session)
  if not current(session,session.Generation,operation)or session.CurrentHostLease~=lifetime or node.AudioHostSession~=session then return nil end
  startHeartbeat();return session
 end
	function api:CanPlayType(_type)return ""end -- Mappings prove a resource, not a browser codec capability.
	function api:CanLoad(source,url,state)
		if not living()then return nil end
		local resolver=lifetime.Page.ResolveAudio;if not resolver then return nil end
  local owner=state and state.OwnerLease;local epoch=state and state.SelectionEpoch;local generation=state and state.Generation;local ownerEpoch=state and state.OwnerEpoch
  local function permitted()
   if not living()then return false end
   return state==nil or state.OwnerLease==owner and owner.Adapter==self and state.OwnerEpoch==ownerEpoch and state.Controller.Pool:Current(state,epoch,generation)
  end
  local asset=resolver(source);if not permitted()then return nil end
		if asset~=nil then return true end
		if url==nil then return false end
		asset=resolver(url);if not permitted()then return nil end;return asset~=nil
	end
	function api:CanRenderSourceType(value,parsed)
		-- Asset mappings do not establish browser container/codec support.
		-- An explicit pure host policy may reject a known unsupported type;
		-- absent policy means unknown and allows an ordinary resource attempt.
		return if lifetime.TypePolicy then lifetime.TypePolicy(value,parsed)else nil
	end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false;lifetime.Alive=false;lifetime.Page=nil;lifetime.Tree=nil;lifetime.TypePolicy=nil;lifetime.Tasks=nil;lifetime.Provider=nil
		if connection then connection:Disconnect();connection=nil end
		for session in sessions do dispose(session)end;table.clear(sessions)
	end
	return api
end
return AudioHost
