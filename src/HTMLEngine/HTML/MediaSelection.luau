--!strict
-- Shared resource-selection state only. Playback/reset and native IO belong to
-- the caller; resolver, capability and scheduler operations are injected.
local Names=require(script.Parent.Parent.DOM.ElementNames)
local Queries=require(script.Parent.Parent.CSS.MediaQueries)
local Work=require(script.Parent.Parent.WorkContext)
local MediaSelection={}
function MediaSelection.firstSource(node)
	for index,child in node.Children do if Names.html(child,"source")then return child,index end end
end
function MediaSelection.matchesMedia(value,view)
	if value==nil then return true end
	view=view or{};local environment=table.clone(view.Environment or{})
	environment.Width,environment.Height=view.Width or 0,view.Height or 0
	return Queries.matches(Queries.compile(value),environment)
end
function MediaSelection.parsedType(value)
	if value==nil then return nil end
	local essence=(value:match("^([^;]*)")or value):match("^[ \t\r\n]*(.-)[ \t\r\n]*$"):lower()
	local main,sub=essence:match("^([^/]+)/([^/]+)$")
	local function token(part)return part and part~=""and not part:find("[^!#$%%&'*+%.%^_`|~%w%-]")end
	return if token(main)and token(sub)then {Type=main,Subtype=sub,Essence=essence}else nil
end
local function clear(entry)
	entry.State=nil;entry.Candidate=nil;entry.Action=nil;entry.OnEmpty=nil
end
function MediaSelection.new(context)
	local lease={Alive=true,Context=context,Pending={}};context=nil
	local api={};local process,find,failed,fetch,start
	local function current(r,epoch,generation)
		local c=lease.Context
		if not lease.Alive or c==nil then return false end
		local living=c.Alive(r)
		return living and lease.Alive and lease.Context==c and r.SelectionEpoch==epoch and(generation==nil or r.Generation==generation)
	end
	local function changed(r,epoch,generation)
		if not current(r,epoch,generation)then return false end
		lease.Context.Changed(r)
		return current(r,epoch,generation)
	end
	local function schedule(kind,r,epoch,generation,action,candidate,onEmpty)
		if not current(r,epoch,generation)then return end
		local entry={State=r,Epoch=epoch,Generation=generation,Action=action,Candidate=candidate,OnEmpty=onEmpty,Kind=kind}
		lease.Pending[entry]=true
		local function deliver()
			lease.Pending[entry]=nil
			local state,node,operation,empty=entry.State,entry.Candidate,entry.Action,entry.OnEmpty
			clear(entry)
			if state and operation and current(state,entry.Epoch,entry.Generation)then operation(state,node,entry.Epoch,entry.Generation,empty)end
		end
		local ok,message=pcall(lease.Context[kind],deliver,r)
		if not ok or message==false then lease.Pending[entry]=nil;clear(entry);if not ok then error(message,0)end end
	end
	local function sourceError(r,candidate)
		if r.Mode=="children"then lease.Context.Dispatch(candidate,"error",r)end
	end
	local function retry(r)
		if r.Mode=="children"then find(r)end
	end
	local function loadstart(r)lease.Context.Dispatch(r.Node,"loadstart",r)end
	failed=function(r)
		local epoch,generation=r.SelectionEpoch,r.Generation
		if not current(r,epoch,generation)or r.AttemptFailed then return end
		r.AttemptFailed=true;r.Phase="source-error";r.Loading=true
		if not changed(r,epoch,generation)then return end
		-- The task owns its SOURCE across ordinary attempts. Its independent
		-- stable microtask must choose the next candidate before task dispatch.
		schedule("QueueTask",r,epoch,nil,sourceError,r.Candidate)
		schedule("QueueStable",r,epoch,generation,retry)
	end
	fetch=function(r)
		local epoch,generation=r.SelectionEpoch,r.Generation
		if not current(r,epoch,generation)then return end
		local c=lease.Context
		if r.Mode=="children"and c.CanLoad then
			local available=c.CanLoad(r.Raw,r.Current,r)
			if not current(r,epoch,generation)then return end
			if available==false then failed(r);return end
		end
		r.Phase="fetch";r.Loading=true;r.Network=2
		if changed(r,epoch,generation)then lease.Context.Fetch(r,epoch,generation)end
	end
	local function prepare(r,epoch,generation)
		if not current(r,epoch,generation)then return end
		local deferred=lease.Context.ShouldDefer(r)
		if not current(r,epoch,generation)then return end
		if deferred then
			r.Phase="deferred";r.Network=1;r.Loading=false
			lease.Context.Suspend(r)
			changed(r,epoch,generation);return
		end
		fetch(r)
	end
	process=function(r,candidate,first)
		local epoch,generation=r.SelectionEpoch,r.Generation
		if not current(r,epoch,generation)then return end
		if not first then r.Generation+=1;generation=r.Generation end
		r.Candidate=candidate;r.AttemptFailed=false;r.Phase="checking";r.Waiting=false;r.Loading=true
		local sourceNode=if candidate then candidate else r.Node
		local raw=sourceNode.Attributes.src;r.Raw,r.Specified=raw or"",raw~=nil
		if raw==nil or raw==""then
			if candidate then failed(r)else lease.Context.DirectFailure(r,"empty")end;return
		end
		if candidate and candidate.Attributes.media~=nil then
			local value=candidate.Attributes.media
			local c=lease.Context;local view=if c.GetViewport then c.GetViewport(r)else{}
			if not current(r,epoch,generation)then return end
			local matches=MediaSelection.matchesMedia(value,view)
			if not current(r,epoch,generation)then return end
			if not matches then failed(r);return end
		end
		local address=lease.Context.Resolve(sourceNode,raw,r)
		if not current(r,epoch,generation)then return end
		if not address then
			if candidate then failed(r)else lease.Context.DirectFailure(r,"invalid")end;return
		end
		local declared=if candidate then candidate.Attributes.type else nil
		local parsed=MediaSelection.parsedType(declared);local c=lease.Context
		if parsed and c.CanRenderSourceType then
			local canRender=c.CanRenderSourceType(declared,parsed,r)
			if not current(r,epoch,generation)then return end
			if canRender==false then failed(r);return end
		end
		r.Current=address;lease.Context.Selected(r,epoch,generation)
		if not current(r,epoch,generation)then return end
		local defer=lease.Context.Defer
		if defer and defer(r,function()prepare(r,epoch,generation)end)then return end
		prepare(r,epoch,generation)
	end
	find=function(r)
  local epoch,generation=r.SelectionEpoch,r.Generation
  if not current(r,epoch,generation)then return end
  local c=lease.Context;if c.BeforeSelect then c.BeforeSelect(r);if not current(r,epoch,generation)then return end end
		r.Candidate=nil
		while r.Gap<#r.Node.Children do
			Work.checkpoint();if not current(r,epoch,generation)then return end
			if r.Gap>=#r.Node.Children then break end
			r.Gap+=1;local child=r.Node.Children[r.Gap]
			if Names.html(child,"source")then process(r,child,false);return end
		end
		r.Waiting=true;r.Phase="waiting";r.Network=3;r.Loading=false
		changed(r,epoch,generation)
	end
	function api:Current(r,epoch,generation)return current(r,epoch,generation)end
	start=function(r,epoch,onEmpty)
  if not current(r,epoch)then return end
  local generation=r.Generation;local c=lease.Context
  if c.BeforeSelect then c.BeforeSelect(r);if not current(r,epoch,generation)then return end end
		local candidate,index=MediaSelection.firstSource(r.Node)
		if r.Node.Attributes.src~=nil then r.Mode="attribute";candidate=nil
		elseif candidate then r.Mode="children";r.Gap=index
		else
			r.Mode="none";r.Phase="empty";r.Raw,r.Specified="",false;r.Network=0;r.Loading=false
			if onEmpty then onEmpty(r)end
			changed(r,epoch,r.Generation);return
		end
		r.Network=2;schedule("QueueTask",r,epoch,nil,loadstart)
		if current(r,epoch)then process(r,candidate,true)end
	end
	local function begin(r,_,epoch,_,onEmpty)start(r,epoch,onEmpty)end
	function api:Start(r,epoch,onEmpty)start(r,epoch,onEmpty)end
	function api:Begin(r,epoch,onEmpty)schedule("QueueStable",r,epoch,r.Generation,begin,nil,onEmpty)end
	function api:Fetch(r)
		local c=lease.Context
		if c and c.Resume and c.Resume(r)then return end
		fetch(r)
	end
	function api:Fail(r)failed(r)end
	function api:BeforeRemove(r,node)
		if not r or not current(r,r.SelectionEpoch,r.Generation)or r.Mode~="children"or r.Gap==nil then return end
		local at=table.find(r.Node.Children,node);if at and at<=r.Gap then r.Gap-=1 end
	end
	function api:BeforeInsert(r,index,count)
		if r and current(r,r.SelectionEpoch,r.Generation)and r.Mode=="children"and r.Gap~=nil and index<r.Gap then r.Gap+=count end
	end
	function api:ResumeWaiting(r)
		local epoch,generation=r.SelectionEpoch,r.Generation
		if not current(r,epoch,generation)or r.Mode~="children"or not r.Waiting or r.Gap>=#r.Node.Children then return false end
		r.Waiting=false;r.Phase="resuming";r.Network=2;r.Loading=true
		if changed(r,epoch,generation)then schedule("QueueStable",r,epoch,generation,retry)end
		return true
	end
	function api:CancelTasks(r)
		for entry in lease.Pending do if entry.State==r and entry.Kind=="QueueTask"then clear(entry);lease.Pending[entry]=nil end end
	end
	function api:Invalidate(r)
		for entry in lease.Pending do if entry.State==r then clear(entry);lease.Pending[entry]=nil end end
	end
	function api:Destroy()
		if not lease.Alive then return end;lease.Alive=false;lease.Context=nil
		for entry in lease.Pending do clear(entry)end;table.clear(lease.Pending)
	end
	return api
end
return MediaSelection
