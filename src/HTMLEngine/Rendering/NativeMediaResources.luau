--!strict
-- Native AUDIO resource owner. No Runtime, VM, Promise or author-query calls.
local Selection=require(script.Parent.Parent.HTML.MediaSelection)
local AudioHost=require(script.Parent.AudioHost)
local Names=require(script.Parent.Parent.DOM.ElementNames)
local SourceDocument=require(script.Parent.Parent.DOM.MediaSourceDocument)
local Node=require(script.Parent.Parent.DOM.Node)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local DocumentInfo=require(script.Parent.Parent.HTML.DocumentInfo)
local URLRecord=require(script.Parent.Parent.JavaScript.URLRecord)
local Strings=require(script.Parent.Parent.JavaScript.Strings)
local Work=require(script.Parent.Parent.WorkContext)
local NativeMediaResources={}

local function preload(node)
	local value=(node.Attributes.preload or "metadata"):lower()
	return if value=="none"or value=="metadata"or value=="auto"then value elseif value==""then "auto"else "metadata"
end

-- Selected resource uses the last successful semantic src write document.
-- Unlike the general reflection fallback, invalid input is not a selected URL.
function NativeMediaResources.resolve(page,node,raw)
	SourceDocument.seed(node,node.OwnerDocument or page.Document)
	local context=node.MediaSourceDocument;local original=context and context.Document[1]
	local owner=original or node.OwnerDocument or page.Document
	local address=if owner==page.Document then page.DocumentURL else owner.URL or context and context.URL
	local base=if original or not context then DocumentInfo.baseURL(owner,address,owner~=page.Document)else context.Base
	base=Strings.usv(base or "about:blank")
	local input=Strings.usv(raw):gsub("[\t\n\r]", ""):gsub("^[%z\1-\32]+", ""):gsub("[%z\1-\32]+$", "")
	local baseScheme=base:match("^[%a][%w+%.%-]*:")
	if not baseScheme and not input:match("^[%a][%w+%.%-]*:")then
		-- DocumentInfo explicitly preserves the engine's scheme-less website
		-- catalog profile. It is not the URL parser for absolute inputs.
		Work.checkpoint();return DocumentInfo.resolveURL(base,input)
	end
	local ok,result=pcall(URLRecord.resolve,input,if baseScheme then base else nil,Work.checkpoint)
	return if ok then result else nil
end

function NativeMediaResources.new(page,tree,services)
	services=services or{}
	local lease={Alive=true,Page=page,Tree=tree,Tasks=services.Task or task,
		Records=setmetatable({},{__mode="kv"}),Active={},Stable={Head=1,Tail=0},TasksQueue={Head=1,Tail=0},Pending={},Removed={},Wake=false,Running=false,Started=false}
	lease.Adapter=services.Adapter or AudioHost.new(page,tree,services.AudioServices)
	lease.Resolve=services.Resolve or NativeMediaResources.resolve
	page=nil;tree=nil;services=nil
	local api={Alive=true,Pending=0};local selection,load,play,pause,prepare,hostEvent,make,drain
	local function has(list)return list.Head<=list.Tail end
	local function living(r)
		local owner=lease.Page
		return lease.Alive and owner~=nil and owner.Alive and r.Node~=nil and lease.Records[r.Node]==r
	end
	local function wake()
		if not lease.Alive or not lease.Started or lease.Wake or lease.Running then return end
		lease.Wake=true
		lease.Tasks.defer(function()
			lease.Wake=false
			if lease.Alive then drain()end
		end)
	end
	local function queue(kind,callback)
		if not lease.Alive then return end
		local entry={Callback=callback};lease.Pending[entry]=true
		local list=lease[kind];list.Tail+=1;list[list.Tail]=entry;wake()
	end
	local function taskQueue(callback)queue("TasksQueue",callback)end
	local function stableQueue(callback)queue("Stable",callback)end
	local function take(list)
		if not has(list)then return nil end
		local index=list.Head;local entry=list[index];list[index]=nil;list.Head+=1
		if not has(list)then list.Head=1;list.Tail=0 end
		lease.Pending[entry]=nil;local callback=entry.Callback;entry.Callback=nil
		return callback
	end
	drain=function()
		if not lease.Alive or lease.Running then return end
		lease.Running=true
		local ok,message=pcall(Work.runFor,lease.Page,function()
			while lease.Alive and has(lease.Stable)do
				Work.checkpoint();if not lease.Alive then break end
				local fn=take(lease.Stable);if fn then fn()end
			end
			if lease.Alive then local fn=take(lease.TasksQueue);if fn then fn()end end
		end)
		lease.Running=false
		if not ok then
			if not lease.Alive and Work.isCancelled(message)then return end
			-- A failing injected host hook stops this owner. Cleanup failure must
			-- not replace the original nil/false/table exception payload.
			pcall(api.Destroy,api)
			error(message,0)
		end
		if lease.Alive and(has(lease.Stable)or has(lease.TasksQueue))then wake()end
	end
	local function dispatch(node,kind)
		if not lease.Alive or not lease.Page or not lease.Page.Alive then return end
		lease.Page.Events:Emit(node,kind,{}, {Bubbles=false,Cancelable=false})
	end
	local function emit(r,kind,generation)
		taskQueue(function()if living(r)and(generation==nil or r.Generation==generation)then dispatch(r.Node,kind)end end)
	end
	local function changed(r)
		if not living(r)then return end
		if r.Loading or r.Playing or r.PendingPlay then lease.Active[r]=true else lease.Active[r]=nil end
		local blocking=r.Loading and ShadowTree.Connected(r.Node,r.Node.OwnerDocument)
  local transitioned=blocking~=(r.Blocking==true)
		if transitioned then r.Blocking=blocking;api.Pending+=if blocking then 1 else -1 end
		local item=lease.Tree.MediaByNode and lease.Tree.MediaByNode[r.Node]
		if item then
			item.LoadStarted=r.Network~=0;item.MetadataEmitted=r.MetadataReached
			item.SelectedSource=r.Raw or "";item.Loading=r.Loading;item.LoadFailed=r.Error~=nil;item.LoadError=r.Error
			if r.Handle then item.Source=r.Handle.Asset end
		end
  if transitioned and lease.Page and lease.Page.DocumentResourcesChanged then lease.Page:DocumentResourcesChanged()end
	end
	local function bind(r)
		if r.Handle and r.Handle.Alive then return true end
		if not living(r)then return false end
		r.Handle=nil
		local epoch,generation=r.SelectionEpoch,r.Generation
		local weak=setmetatable({r},{__mode="v"})
		local delivered=lease.Adapter:Open(r.Node,function(event)
			taskQueue(function()local current=weak[1];if current and living(current)then hostEvent(current,event)end end)
		end)
		if not living(r)or r.SelectionEpoch~=epoch or r.Generation~=generation or r.Handle~=nil or delivered and delivered.Owner and r.Node.AudioHostSession~=delivered then
			if delivered and delivered~=r.Handle and delivered.Alive~=false and delivered.Destroy then delivered:Destroy()end
			return living(r)and r.Handle~=nil
		end
		r.Handle=delivered
		return delivered~=nil
	end
	local function configure(r,epoch,generation)
		for _,pair in {{"volume",r.Volume},{"muted",r.Muted},{"playbackRate",r.Rate},{"loop",r.Node.Attributes.loop~=nil}}do
			r.Handle:Set(pair[1],pair[2]);if not selection:Current(r,epoch,generation)then return false end
		end
		return true
	end
	local function selected(r,epoch,generation)
		if r.Handle then r.Handle:Select(r.Current,r.Raw,generation)end
		if not selection:Current(r,epoch,generation)then return end
		-- Existing no-Realm binding hint, never a source/codec preselection.
		if preload(r.Node)=="none"and r.Paused and not r.PendingPlay and r.Node.Attributes.autoplay==nil and r.Handle and r.Handle.Asset then
			r.Handle.Sound.SoundId=r.Handle.Asset
		end
	end
	local function snapshot(r)
		if r.Handle and r.Ready>0 then local s=r.Handle:Snapshot();if s then r.Position=s.Position or r.Position end end
	end
	hostEvent=function(r,event)
		if not living(r)or event.Kind~="control"and(event.Generation~=r.Generation or r.AttemptFailed)then return end
		if event.Kind=="loaded"then
			if r.Phase~="fetch"then return end
			r.MetadataReached=true;r.Phase="ready";r.Loading=false;r.Network=1;r.Ready=4;r.Duration=event.Duration or 0
			if r.DefaultStart>0 then r.Position=r.DefaultStart end;r.DefaultStart=0
			r.Position=math.clamp(r.Position,0,r.Duration)
			for _,kind in {"durationchange","loadedmetadata","loadeddata","canplay","canplaythrough"}do emit(r,kind,r.Generation)end
			local epoch,generation=r.SelectionEpoch,r.Generation
			r.Handle:Set("currentTime",r.Position);if not selection:Current(r,epoch,generation)then return end
			if not r.Paused or r.CanAutoplay and r.Node.Attributes.autoplay~=nil then
				if r.Paused then r.Paused=false;r.Intent+=1;emit(r,"play",generation)end
				r.Handle:Play(r.Intent)
			end
		elseif event.Kind=="error"then
			if r.Mode=="children"and not r.MetadataReached and r.Phase=="fetch"then selection:Fail(r);return end
			r.AttemptFailed=true;r.Phase="error";r.Loading=false;r.Playing=false;r.Network=3;r.Ready=0
			r.Error={Code=event.Code or 4,Message=event.Message or "Native audio source is unavailable"};r.PendingPlay=false;emit(r,"error",r.Generation)
		elseif event.Kind=="playing"then
			if r.Ready==0 or r.Paused or event.Intent~=r.Intent then return end
			local began=not r.Playing;r.Playing=true;r.PendingPlay=false;r.Ended=false
			if began then emit(r,"playing",r.Generation)end
		elseif event.Kind=="control"then
			if event.Action=="play"or event.Action=="toggle"and r.Paused then play(r)else pause(r,false)end
		elseif event.Kind=="ended"then
			if not r.Playing then return end
			r.Position=r.Duration;r.Playing=false;r.Paused=true;r.Ended=true
			emit(r,"timeupdate",r.Generation);emit(r,"pause",r.Generation);emit(r,"ended",r.Generation)
		elseif event.Kind=="loop"or event.Kind=="timeupdate"then snapshot(r);emit(r,"timeupdate",r.Generation)
		elseif event.Kind=="ratechange"then r.Rate=event.Rate;emit(r,"ratechange",r.Generation)
		elseif event.Kind=="volumechange"then r.Volume,r.Muted=event.Volume,event.Muted;emit(r,"volumechange",r.Generation)
		elseif event.Kind=="seeking"then r.Position=event.Position or r.Position;r.Ended=false;emit(r,"seeking",r.Generation);emit(r,"timeupdate",r.Generation);emit(r,"seeked",r.Generation)
		end
		changed(r)
	end
	selection=Selection.new({
		Alive=living,QueueTask=taskQueue,QueueStable=stableQueue,Changed=changed,Dispatch=dispatch,
		Resolve=function(node,raw)return lease.Resolve(lease.Page,node,raw)end,
		GetViewport=function()return lease.Page:GeometryViewport()end,
		CanLoad=function(raw,url)return if lease.Adapter.CanLoad then lease.Adapter:CanLoad(raw,url)else nil end,
		CanRenderSourceType=function(raw,parsed)return if lease.Adapter.CanRenderSourceType then lease.Adapter:CanRenderSourceType(raw,parsed)else nil end,
		Selected=selected,
		ShouldDefer=function(r)return preload(r.Node)=="none"and r.Paused and not r.PendingPlay and r.Node.Attributes.autoplay==nil end,
		Suspend=function(r)emit(r,"suspend",r.Generation)end,
		DirectFailure=function(r,reason)hostEvent(r,{Generation=r.Generation,Kind="error",Code=4,Message=if reason=="empty"then "The audio src attribute is empty"else "The audio source URL is invalid"})end,
		Fetch=function(r,epoch,generation)
			local bound=bind(r);if not selection:Current(r,epoch,generation)then return end
			if not bound then hostEvent(r,{Generation=generation,Kind="error",Code=4,Message="No native AudioHost session"});return end
			if configure(r,epoch,generation)then r.Handle:Load(r.Current,r.Raw,generation)end
		end,
	})
	make=function(node)
		local r=lease.Records[node];if r then return r end
		r={Node=node,SelectionEpoch=0,Generation=0,Intent=0,Network=0,Ready=0,Current="",Raw="",Specified=false,
			Paused=true,Playing=false,PendingPlay=false,CanAutoplay=true,Ended=false,Position=0,DefaultStart=0,Duration=0/0,
			Volume=1,Muted=node.Attributes.muted~=nil,Rate=1,DefaultRate=1,Loading=false,MetadataReached=false,AttemptFailed=false}
		lease.Records[node]=r;node.NativeAudioResourceState=r;return r
	end
	load=function(r,force,selectEmpty)
		if not living(r)then return end
		if r.Node.Attributes.controls~=nil and not r.Handle then
			local epoch,generation=r.SelectionEpoch,r.Generation
			local bound=bind(r)
			if not selection:Current(r,epoch,generation)then return end
			if bound and not configure(r,epoch,generation)then return end
			if bound and r.Phase=="deferred"then selected(r,epoch,generation);if not selection:Current(r,epoch,generation)then return end end
			changed(r)
		end
		if not living(r)then return end
		if not force and r.Network~=0 then return end
		if not force and not selectEmpty and r.Node.Attributes.src==nil and not Selection.firstSource(r.Node)then return end
		local hadNetwork=r.Network~=0;local hadData=r.Ready~=0
		r.SelectionEpoch+=1;r.Generation+=1;local epoch=r.SelectionEpoch;selection:Invalidate(r)
		r.Mode=nil;r.Candidate=nil;r.Gap=nil;r.Waiting=false;r.AttemptFailed=false;r.MetadataReached=false;r.Phase="selecting"
		if force then
			if r.Network==1 or r.Network==2 then emit(r,"abort")end;if hadNetwork then emit(r,"emptied")end
			if hadNetwork then
				r.Intent+=1;if r.Handle then r.Handle:Pause()end
				if not selection:Current(r,epoch)then return end
				r.Paused=true;r.Playing=false;r.PendingPlay=false;r.Ended=false;r.Position=0;r.Duration=0/0;r.Ready=0
				if hadData then emit(r,"timeupdate")end
			end
			if r.Rate~=r.DefaultRate then emit(r,"ratechange")end
			r.Rate=r.DefaultRate;r.CanAutoplay=true;r.Error=nil;r.Loading=false
		end
		r.Network=3;r.Loading=true;changed(r)
		selection:Begin(r,epoch,function(current)if force and current.Handle then current.Handle:Reset(current.Generation)end end)
	end
	prepare=function(r)
		if not living(r)or r.Phase~="deferred"or r.Loading or not r.Specified or r.Raw==""or r.Error~=nil then return end
		r.Loading=true;r.Network=2;changed(r)
		local epoch,generation=r.SelectionEpoch,r.Generation
		taskQueue(function()if selection:Current(r,epoch,generation)then selection:Fetch(r)end end)
	end
	play=function(r)
		if not living(r)or r.Error then return false end
		load(r,false,true);if not living(r)then return false end
		r.PendingPlay=true;r.CanAutoplay=false
		if r.Paused then r.Intent+=1;r.Paused=false;emit(r,"play");if r.Ready<3 then emit(r,"waiting")end end
		if r.Ended then r.Position=0;r.Ended=false;if r.Handle then r.Handle:Set("currentTime",0)end end
		if r.Ready>0 and bind(r)then r.Handle:Play(r.Intent)elseif not r.Loading then prepare(r)end
		changed(r);return true
	end
	pause=function(r,internal)
		if not living(r)then return end
		if not internal then load(r,false,true)end;snapshot(r);r.Intent+=1;r.CanAutoplay=false;r.PendingPlay=false;r.Playing=false
		if r.Handle then r.Handle:Pause()end
		if not r.Paused then r.Paused=true;emit(r,"timeupdate");emit(r,"pause")end;changed(r)
	end
	local function visit(root)
		local pending={root}
		while lease.Alive and #pending>0 do
			Work.checkpoint();if not lease.Alive then return end;local node=table.remove(pending)
			if Names.html(node,"audio")then load(make(node),false,false)end
			if not Names.html(node,"template")then for _,child in node.Children or{}do table.insert(pending,child)end end
			if node.InternalShadowRoot then table.insert(pending,node.InternalShadowRoot)end
		end
	end
	local function record(value)
		if not lease.Alive or not lease.Page then return nil end
		local node=if type(value)=="string"then Node.findById(lease.Page.Document,value)else value
		return node and lease.Records[node]
	end
	function api:Visit(root)if lease.Alive then visit(root)end end
	function api:Attached(node)local r=lease.Records[node];if r then changed(r)end end
	function api:Start()
		if not lease.Alive or lease.Started then return end
		lease.Started=true
		if has(lease.Stable)or has(lease.TasksQueue)then wake()end
	end
	function api:Load(value)local r=record(value);if r then load(r,true,true)end end
	function api:Play(value)local r=record(value);return if r then play(r)else false end
	function api:Pause(value)local r=record(value);if r then pause(r,false)end end
	function api:State(value)
		local r=record(value);if not r then return nil end;snapshot(r)
		return {Kind="audio",Playing=r.Playing,Paused=r.Paused,Loading=r.Loading,CurrentTime=if r.DefaultStart~=0 then r.DefaultStart else r.Position,
			Duration=r.Duration,Volume=r.Volume,Muted=r.Muted,PlaybackRate=r.Rate,Ended=r.Ended,SelectedSource=r.Raw,CurrentSrc=r.Current,NetworkState=r.Network,ReadyState=r.Ready,Error=r.Error}
	end
	function api:Set(value,key,data)
		local r=record(value);if not r then return end
		if key=="currentTime"then if r.Ready==0 then r.DefaultStart=data;return end;r.Position=math.clamp(data,0,r.Duration)
		elseif key=="playbackRate"then r.Rate=data elseif key=="defaultPlaybackRate"then r.DefaultRate=data;return
		elseif key=="volume"then r.Volume=data elseif key=="muted"then r.Muted=data else return end
		if r.Handle then r.Handle:Set(key,if key=="currentTime"then r.Position else data)end
	end
	function api:BeforeRemove(node,preservingMove)
		if not lease.Alive then return end
		selection:BeforeRemove(node.Parent and lease.Records[node.Parent],node)
		if preservingMove then return end
		for _,r in lease.Records do if ShadowTree.InclusiveDescendant(r.Node,node)and ShadowTree.Connected(r.Node,r.Node.OwnerDocument)then lease.Removed[r]=true end end
		if next(lease.Removed)and not lease.RemovalWake then
			lease.RemovalWake=true
			stableQueue(function()
				lease.RemovalWake=false;local removed=lease.Removed;lease.Removed={}
				for r in removed do if living(r)and not ShadowTree.Connected(r.Node,r.Node.OwnerDocument)then pause(r,true)end end
			end)
		end
	end
	function api:BeforeInsert(parent,index,count)if lease.Alive then selection:BeforeInsert(lease.Records[parent],index,count)end end
	function api:Mutation(change)
		if not lease.Alive then return end
		if change.Type=="attributes"then DocumentInfo.baseMutation(lease.Page.Document,lease.Page.DocumentURL,change);return end
		if change.Type~="childList"then return end
		DocumentInfo.baseMutation(lease.Page.Document,lease.Page.DocumentURL,change)
		local r=lease.Records[change.Target]
		if r then
			if not selection:ResumeWaiting(r)and r.Network==0 then
				for _,child in change.AddedNodes or{}do if Names.html(child,"source")then load(r,false,true);break end end
			end
		end
		for _,child in change.AddedNodes or{}do if ShadowTree.Connected(child,child.OwnerDocument)then visit(child)end end
	end
	function api:AttributeChanged(node,key,value,namespace)
		if not lease.Alive or namespace~=nil and namespace~=""then return end
		SourceDocument.write(node,key,value,namespace,node.OwnerDocument or lease.Page.Document)
		local r=lease.Records[node];if not r then return end
		if key=="src"then if value~=nil then load(r,true,true)end
		elseif key=="preload"then if preload(node)~="none"then if r.Network==0 then load(r,false,false)else prepare(r)end end
		elseif key=="controls"then load(r,false,false)
		elseif key=="loop"and r.Handle then r.Handle:Set("loop",node.Attributes.loop~=nil)end
	end
	function api:Destroy()
		if not lease.Alive then return end;lease.Alive=false;self.Alive=false
		selection:Destroy()
		for entry in lease.Pending do entry.Callback=nil end
		table.clear(lease.Pending);table.clear(lease.Stable);table.clear(lease.TasksQueue);table.clear(lease.Removed)
		local removals={}
		for node,r in lease.Records do
			local item=lease.Tree.MediaByNode and lease.Tree.MediaByNode[node]
			if item then
				item.Source=nil;item.Loading=false;item.Playing=false;item.LoadStarted=false;item.MetadataEmitted=false;item.PressedAction=nil;item.HoverAction=nil;item.FocusVisible=false
				table.insert(removals,item)
			end
			if node.NativeAudioResourceState==r then node.NativeAudioResourceState=nil end;r.Node=nil;r.Candidate=nil;r.Handle=nil
		end
		table.clear(lease.Records);table.clear(lease.Active);self.Pending=0
		local owner=lease.Page
		local adapter,media=lease.Adapter,owner.Media;lease.Adapter=nil;lease.Resolve=nil;lease.Page=nil;lease.Tree=nil
		local failed,message=false,nil
		if media and media.Remove then local ok,result=pcall(media.Remove,media,removals);if not ok then failed=true;message=result end end
		local ok,result=pcall(adapter.Destroy,adapter);if not ok and not failed then failed=true;message=result end
  if owner.Alive and owner.DocumentResourcesChanged then local notified,value=pcall(owner.DocumentResourcesChanged,owner);if not notified and not failed then failed=true;message=value end end
		if failed then error(message,0)end
	end
	lease.Page.NativeMediaResources=api
	lease.Page:AddCleanup(function()api:Destroy()end)
	visit(lease.Page.Document)
	return api
end
return NativeMediaResources
