--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
-- Live HTML named access is separate from expandos and global declarations.
-- One revision-indexed walk serves all names; returned collections stay live.
local Names=require(script.Parent.DOMNames)
local Named={}
local WINDOW_NAME={embed=true,form=true,img=true,object=true}
local DOCUMENT_NAME={embed=true,form=true,iframe=true,img=true,object=true}
local MAX_CANDIDATE_SCAN=256
function Named.new(ctx)
	local states=setmetatable({},{__mode='kv'});local documents=setmetatable({},{__mode='k'});local revisions=setmetatable({},{__mode='k'});local token={};local alive=true
	local function attribute(node,key)
		local info=node.AttributeNamespaces and node.AttributeNamespaces[key]
		return if info and info.Namespace and info.Namespace~=''then nil else node.Attributes[key]
	end
	local function snapshot(document)
		-- A cooperative checkpoint may expose a mutation. Retry iteratively;
		-- every visited node consumes the caller's existing instruction budget.
		while true do
			assert(alive,'Named properties disposed')
			local revision=revisions[document]or 0;revisions[document]=revision;local state=states[document]
			if state and state.Revision==revision then return state end
			local nextState={Revision=revision,Document={},Window={},DocumentKeys={},WindowKeys={},Collections=if state then state.Collections else {Document=setmetatable({},{__mode='v'}),Window=setmetatable({},{__mode='v'})}}
			local function add(map,keys,key,node)
				if not key or key==''then return end
				local entries=map[key];if not entries then entries={};map[key]=entries;table.insert(keys,key)end
				if entries[#entries]~=node then table.insert(entries,node)end
			end
			local pending={document};while #pending>0 do
				if ctx.Step then ctx.Step()end;local node=table.remove(pending)
				if node.Kind=='Element'then
					local html=node.NamespaceURI==nil or node.NamespaceURI==Names.HTML
					local id,name=attribute(node,'id'),attribute(node,'name')
					add(nextState.Window,nextState.WindowKeys,id,node)
					if html and WINDOW_NAME[ElementNames.htmlName(node)]then add(nextState.Window,nextState.WindowKeys,name,node)end
					if html and (ElementNames.htmlName(node)=='object'or(ElementNames.htmlName(node)=='img'and name and name~=''))then add(nextState.Document,nextState.DocumentKeys,id,node)end
					if html and DOCUMENT_NAME[ElementNames.htmlName(node)]then add(nextState.Document,nextState.DocumentKeys,name,node)end
				end
				-- Shadow trees and template contents are not a document-tree scope.
				-- Named access is an element index, not a text-node query. Non-element
				-- children cannot contain candidate descendants and must not consume
				-- a full-tree query budget on every ordinary Document member read.
				for index=#node.Children,1,-1 do local child=node.Children[index];if child.Kind=='Element'then table.insert(pending,child)end end
			end
			if revision~=(revisions[document]or 0)then continue end
			-- Luau weak keys are not ephemerons: a strong registry snapshot
			-- would retain its own document through node.OwnerDocument. The
			-- document owns this data-only snapshot; the lookup roots neither.
			local snapshots=document.DOMNamedSnapshots;if not snapshots then snapshots={};document.DOMNamedSnapshots=snapshots end
			snapshots[token]=nextState;documents[document]=true;states[document]=nextState;return nextState
		end
	end
	local api={}
	local function candidate(node)
		if node.Kind~='Element'then return false end
		local id=attribute(node,'id');if id and id~=''then return true end
		local name=attribute(node,'name');local tag=ElementNames.htmlName(node)
		return name~=nil and name~=''and(WINDOW_NAME[tag]==true or DOCUMENT_NAME[tag]==true)
	end
	local function containsCandidate(nodes,limit)
		limit=limit or MAX_CANDIDATE_SCAN;if limit==0 then return #(nodes or{})>0,0 end
		-- Cursor frames avoid copying a wide child/input list into a pending queue.
		-- One visited node includes its kind/name inspection and possible descent;
		-- at most 256 nodes and cursor frames are processed before safe fallback.
		local work=0;local pending={{Nodes=nodes or{},Index=1}}
		while #pending>0 do
			local frame=pending[#pending];local node=frame.Nodes[frame.Index]
			if not node then table.remove(pending);continue end
			frame.Index+=1;work+=1
			if candidate(node)then return true,work end
			-- Only elements can contain candidates. Template contents/shadow roots
			-- are not children in this light-tree traversal.
			if node.Kind=='Element'and #node.Children>0 then table.insert(pending,{Nodes=node.Children,Index=1})end
			if work>=limit then return true,work end
		end
		return false,work
	end
	local function invalidate(document)
		revisions[document]=(revisions[document]or 0)+1
		local state=states[document]
		if state then
			state.Revision=nil;table.clear(state.Document);table.clear(state.Window);table.clear(state.DocumentKeys);table.clear(state.WindowKeys)
		end
	end
	function api:Mutation(record)
		local document=ShadowTree.Root(record.Target)
		if not document or document.Kind~='Document'or revisions[document]==nil then return end
		-- Ordinary text/style mutations cannot change supported named properties.
		-- Clear candidate-bearing mutations immediately, before an author callback
		-- can inspect the cache or keep a removed node alive through its snapshot.
		if record.Type=='childList'then
			local added,work=containsCandidate(record.AddedNodes)
			local removed=false;if not added then local count;removed,count=containsCandidate(record.RemovedNodes,MAX_CANDIDATE_SCAN-work);work+=count end
			if added or removed then invalidate(document)end
			-- Classify at most 256 committed subtree nodes atomically. Charge
			-- every visited node after invalidation so a cooperative/nested lookup
			-- cannot observe an old candidate snapshot between commit and the clear.
			if ctx.Step then for _=1,work do ctx.Step()end end
		elseif record.Type=='attributes'and(not record.AttributeNamespace or record.AttributeNamespace=='')then
			local key=record.AttributeName;local node=record.Target
			if key=='id'or(key=='name'and(WINDOW_NAME[ElementNames.htmlName(node)]or DOCUMENT_NAME[ElementNames.htmlName(node)]))then
				local old,current=record.OldValue,attribute(node,key)
				if old~=current and((old~=nil and old~='')or(current~=nil and current~=''))then invalidate(document)end
			end
		end
	end
	function api:Entries(document,kind,key)
		if document.Kind~='Document'or type(key)~='string'or key==''then return {}end
		return snapshot(document)[kind][key]or {}
	end
	function api:Get(document,kind,key)
		local entries=self:Entries(document,kind,key)
		if #entries==0 then return false end
		if #entries==1 then
			local node=entries[1]
			if kind=='Document'and ElementNames.htmlName(node)=='iframe'and ctx.FrameWindow then local window=ctx.FrameWindow(node);if window then return true,window end end
			return true,ctx.Wrap(node)
		end
		local collections=snapshot(document).Collections[kind]
		if not collections[key]then collections[key]=ctx.Collection(function()return self:Entries(document,kind,key)end,true)end
		return true,collections[key]
	end
	function api:Keys(document,kind)
		if document.Kind~='Document'then return {}end
		return table.clone(snapshot(document)[kind..'Keys'])
	end
	function api:Destroy()
		alive=false
		for document in documents do
			local snapshots=document.DOMNamedSnapshots;if snapshots then snapshots[token]=nil;if next(snapshots)==nil then document.DOMNamedSnapshots=nil end end
		end
		table.clear(states);table.clear(documents);table.clear(revisions);table.clear(ctx)
	end
	return api
end
function Named.window(vm,document,lookup,globalEnvironment,eventTargetPrototype)
	local VM=vm.Model;local N=VM.Null
	local namedObject;local windowPrototype
	local function visible(key)
		if type(key)~='string'then return false end
		if vm.ObjectModel.HasOwn(globalEnvironment.Properties,key)then return false end
		local proto=globalEnvironment.Properties.Prototype
		while proto and proto~=N do
			vm.Step();if proto~=namedObject and vm.ObjectModel.HasOwn(proto,key)then return false end
			proto=vm.GetPrototype(proto)
		end
		return lookup:Get(document,'Window',key)
	end
	namedObject={Prototype=eventTargetPrototype or vm.Prototypes.Object,GetOwnPropertyDescriptor=function(key)
		if key==vm.SymbolToStringTag then return {Value='WindowProperties',Writable=false,Enumerable=false,Configurable=true}end
		local present,value=visible(key);if present then return {Value=value,Writable=true,Enumerable=false,Configurable=true}end;return nil
	end,Keys=function()return {vm.SymbolToStringTag}end,DefineProperty=function()return false end,Delete=function()return false end,
		SetPrototype=function(proto)return proto==namedObject.Prototype end,IsExtensible=function()return true end,PreventExtensions=function()return false end}
	windowPrototype=vm.Object({},namedObject)
	local constructor={Kind='native-function',Prototype=vm.Prototypes.Function,Values={name='Window',length=0},Call=function()VM.throw(VM.error('TypeError','Illegal Window constructor'))end}
	vm.DefineProperty(constructor,'prototype',vm.Object({value=windowPrototype},N))
	vm.DefineProperty(windowPrototype,'constructor',vm.Object({value=constructor,writable=true,configurable=true},N))
	vm.DefineProperty(windowPrototype,vm.SymbolToStringTag,vm.Object({value='Window',configurable=true},N))
	globalEnvironment.Properties.Prototype=windowPrototype
	globalEnvironment.PrototypeSet=true
	return constructor,namedObject
end
return Named
