--!strict
-- DOM Standard traversal algorithms over the live data tree. No copied node
-- list, renderer objects, timers or filter callbacks are used during removal.
local Traversal={}
local ACCEPT,REJECT,SKIP=1,2,3
local TYPES={Element=1,Attribute=2,Text=3,CDATASection=4,ProcessingInstruction=7,Comment=8,Document=9,DocumentType=10,DocumentFragment=11,ShadowRoot=11}
local CONSTANTS={FILTER_ACCEPT=1,FILTER_REJECT=2,FILTER_SKIP=3,SHOW_ALL=4294967295,SHOW_ELEMENT=1,SHOW_ATTRIBUTE=2,SHOW_TEXT=4,
	SHOW_CDATA_SECTION=8,SHOW_ENTITY_REFERENCE=16,SHOW_ENTITY=32,SHOW_PROCESSING_INSTRUCTION=64,SHOW_COMMENT=128,
	SHOW_DOCUMENT=256,SHOW_DOCUMENT_TYPE=512,SHOW_DOCUMENT_FRAGMENT=1024,SHOW_NOTATION=2048}

function Traversal.install(vm: any,globals: any,options: any): any
	local VM=assert(vm.Model,"Traversal requires vm.Model");local U,N=VM.Undefined,VM.Null
	options=table.clone(options)
	local api={Alive=true};local allocated=0
	-- Register weak wrapper keys with boolean values. The wrapper owns its state;
	-- neither a filter nor its callback cycle becomes a document-owned GC root.
	local iterators,walkers=setmetatable({},{__mode="k"}),setmetatable({},{__mode="k"})
	local iteratorProto,walkerProto=vm.Object({}),vm.Object({})
	local function check()assert(api.Alive and vm.Alive,"JavaScript traversal disposed")end
	local function fail(name,message)
		VM.throw(if options.Events and name~="TypeError" and name~="RangeError" then options.Events:DOMException(message,name) else VM.error(name,message))
	end
	local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,VM.Null))end
	local function native(name,arity,fn)
		local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end}
		define(value,"length",{value=arity,configurable=true});define(value,"name",{value=name,configurable=true});return value
	end
	local function state(map,value,name)check();if not map[value]then fail("TypeError",name.." called on incompatible receiver")end;return value.TraversalState end
	local function method(proto,name,fn)
		define(proto,name,{value=native(name,0,fn),writable=true,enumerable=true,configurable=true})
	end
	local function accessor(proto,name,read,write)
		define(proto,name,{get=native("get "..name,0,function(_,receiver)return read(receiver)end),
			set=if write then native("set "..name,1,function(args,receiver)write(receiver,args[1] or U);return U end)else U,enumerable=true,configurable=true})
	end
	local function node(value)
		local result=options.Unwrap(value);if not result or not TYPES[result.Kind]then fail("TypeError","Expected a Node")end;return result
	end
	local function integer(value,modulus)
		value=vm.ToPrimitive(value,"number")
		if type(value)=="table"and(value.Kind=="symbol"or value.Kind=="bigint")then fail("TypeError","Cannot convert value to an unsigned integer")end
		local number=VM.number(value)
		if number~=number or number==0 or math.abs(number)==math.huge then return 0 end
		return (if number<0 then math.ceil(number)else math.floor(number))%modulus
	end
	local function contains(ancestor,current)
		while current do if current==ancestor then return true end;current=current.Parent end;return false
	end
	local function sibling(current,direction)
		local parent=current.Parent;if not parent then return nil end
		local index=table.find(parent.Children,current);return if index then parent.Children[index+direction]else nil
	end
	local function child(current,direction)return current.Children[if direction==1 then 1 else #current.Children]end
	local function following(current,root,skipChildren,charge)
		if not skipChildren and current.Children[1]then return current.Children[1]end
		while current and current~=root do
			if charge then vm.Step()end
			local next=sibling(current,1);if next then return next end;current=current.Parent
		end;return nil
	end
	local function preceding(current,root)
		if current==root then return nil end
		local previous=sibling(current,-1)
		if previous then while #previous.Children>0 do vm.Step();previous=previous.Children[#previous.Children]end;return previous end
		return current.Parent
	end
	local function filter(entry,current)
		-- The guard precedes even whatToShow's exclusion, as specified by DOM.
		if entry.Active then fail("InvalidStateError","Traversal filter is already active")end
		vm.Step()
		if bit32.band(entry.Show,bit32.lshift(1,TYPES[current.Kind]-1))==0 then return SKIP end
		if entry.Filter==N then return ACCEPT end
		entry.Active=true
		local ok,result=pcall(function()
			local callback,receiver=entry.Filter,U
			if not VM.callable(callback)then
				receiver=callback;callback=vm.Get(callback,"acceptNode")
				if not VM.callable(callback)then fail("TypeError","NodeFilter.acceptNode must be callable")end
			end
			return integer(vm:Call(callback,{options.Wrap(current)},receiver),65536)
		end)
		entry.Active=false;if not ok then error(result,0)end;return result
	end
	local function iterate(entry,direction)
		local previousCandidate=entry.Candidate
		entry.Candidate={Node=entry.Reference.Node,Before=entry.Reference.Before}
		local ok,result=pcall(function()
			while true do
				vm.Step();local candidate=entry.Candidate
				if direction==1 then
					if not candidate.Before then
						local next=following(candidate.Node,entry.Root,false,true);if not next then return N end
						entry.Candidate={Node=next,Before=false}
					else entry.Candidate={Node=candidate.Node,Before=false}end
				else
					if candidate.Before then
						local previous=preceding(candidate.Node,entry.Root);if not previous then return N end
						entry.Candidate={Node=previous,Before=true}
					else entry.Candidate={Node=candidate.Node,Before=true}end
				end
				local current=entry.Candidate.Node
				if filter(entry,current)==ACCEPT then entry.Reference=entry.Candidate;return options.Wrap(current)end
			end
		end)
		-- A caught recursive invocation must not overwrite the outer call's live
		-- candidate pointer. Every pre-remove adjustment still applies to it.
		entry.Candidate=previousCandidate
		if not ok then error(result,0)end;return result
	end
	method(iteratorProto,"nextNode",function(_,receiver)return iterate(state(iterators,receiver,"NodeIterator"),1)end)
	method(iteratorProto,"previousNode",function(_,receiver)return iterate(state(iterators,receiver,"NodeIterator"),-1)end)
	method(iteratorProto,"detach",function(_,receiver)state(iterators,receiver,"NodeIterator");return U end)
	local function accept(entry,current)entry.Current=current;return options.Wrap(current)end
	local function children(entry,direction)
		local current=child(entry.Current,direction)
		while current do
			vm.Step();local result=filter(entry,current)
			if result==ACCEPT then return accept(entry,current)end
			if result==SKIP then local nested=child(current,direction);if nested then current=nested;continue end end
			while current do
				vm.Step();local next=sibling(current,direction);if next then current=next;break end
				local parent=current.Parent;if not parent or parent==entry.Root or parent==entry.Current then return N end;current=parent
			end
		end;return N
	end
	local function siblings(entry,direction)
		local current=entry.Current;if current==entry.Root then return N end
		while true do
			vm.Step();local next=sibling(current,direction)
			while next do
				current=next;local result=filter(entry,current)
				if result==ACCEPT then return accept(entry,current)end
				next=child(current,direction)
				if result==REJECT or not next then next=sibling(current,direction)end
			end
			current=current.Parent;if not current or current==entry.Root then return N end
			if filter(entry,current)==ACCEPT then return N end
		end
	end
	local function previousNode(entry)
		local current=entry.Current
		while current~=entry.Root do
			vm.Step();local previous=sibling(current,-1)
			while previous do
				current=previous;local result=filter(entry,current)
				while result~=REJECT and #current.Children>0 do current=child(current,-1);result=filter(entry,current)end
				if result==ACCEPT then return accept(entry,current)end;previous=sibling(current,-1)
			end
			if current==entry.Root or not current.Parent then return N end
			current=current.Parent;if filter(entry,current)==ACCEPT then return accept(entry,current)end
		end;return N
	end
	local function nextNode(entry)
		local current,result=entry.Current,ACCEPT
		while true do
			vm.Step()
			while result~=REJECT and #current.Children>0 do
				current=child(current,1);result=filter(entry,current)
				if result==ACCEPT then return accept(entry,current)end
			end
			local next=following(current,entry.Root,true,true);if not next then return N end
			current=next;result=filter(entry,current);if result==ACCEPT then return accept(entry,current)end
		end
	end
	method(walkerProto,"parentNode",function(_,receiver)
		local entry=state(walkers,receiver,"TreeWalker");local current=entry.Current
		while current and current~=entry.Root do vm.Step();current=current.Parent;if current and filter(entry,current)==ACCEPT then return accept(entry,current)end end;return N
	end)
	for name,direction in {firstChild=1,lastChild=-1}do method(walkerProto,name,function(_,receiver)return children(state(walkers,receiver,"TreeWalker"),direction)end)end
	for name,direction in {nextSibling=1,previousSibling=-1}do method(walkerProto,name,function(_,receiver)return siblings(state(walkers,receiver,"TreeWalker"),direction)end)end
	method(walkerProto,"nextNode",function(_,receiver)return nextNode(state(walkers,receiver,"TreeWalker"))end)
	method(walkerProto,"previousNode",function(_,receiver)return previousNode(state(walkers,receiver,"TreeWalker"))end)
	for _,pair in {{iteratorProto,iterators,"NodeIterator"},{walkerProto,walkers,"TreeWalker"}}do
		local proto,map,name=pair[1],pair[2],pair[3]
		accessor(proto,"root",function(value)return options.Wrap(state(map,value,name).Root)end)
		accessor(proto,"whatToShow",function(value)return state(map,value,name).Show end)
		accessor(proto,"filter",function(value)return state(map,value,name).Filter end)
		if vm.SymbolToStringTag then define(proto,vm.SymbolToStringTag,{value=name,configurable=true})end
		local constructor=native(name,0,function()fail("TypeError","Illegal constructor")end)
		constructor.Construct=function()fail("TypeError","Illegal constructor")end
		define(constructor,"prototype",{value=proto});define(proto,"constructor",{value=constructor,writable=true,configurable=true})
		globals[name]=constructor;vm.Global.Bindings[name]={Value=constructor}
	end
	accessor(iteratorProto,"referenceNode",function(value)return options.Wrap(state(iterators,value,"NodeIterator").Reference.Node)end)
	accessor(iteratorProto,"pointerBeforeReferenceNode",function(value)return state(iterators,value,"NodeIterator").Reference.Before end)
	accessor(walkerProto,"currentNode",function(value)return options.Wrap(state(walkers,value,"TreeWalker").Current)end,
		function(value,raw)local entry=state(walkers,value,"TreeWalker");entry.Current=node(raw)end)
	local nodeFilter=native("NodeFilter",0,function()fail("TypeError","Illegal constructor")end)
	nodeFilter.Construct=function()fail("TypeError","Illegal constructor")end
	for key,value in CONSTANTS do define(nodeFilter,key,{value=value,enumerable=true})end
	globals.NodeFilter=nodeFilter;vm.Global.Bindings.NodeFilter={Value=nodeFilter}
	local factories={}
	for name,map in {createNodeIterator=iterators,createTreeWalker=walkers}do
		factories[name]=native(name,1,function(args,receiver)
			if receiver~=options.Document then fail("TypeError","Document traversal factory called on incompatible receiver")end
			if #args<1 then fail("TypeError",name.." requires a root")end
			local root=node(args[1]);local show=if args[2]==nil or args[2]==U then CONSTANTS.SHOW_ALL else integer(args[2],4294967296)
			local callback=if args[3]==nil or args[3]==U then N else args[3]
			if callback~=N and not vm.ObjectModel.IsObject(callback)then fail("TypeError","NodeFilter must be an object or null")end
			if allocated>=4096 then fail("RangeError","DOM traversal allocation budget exceeded")end;allocated+=1
			local value=vm.Object({},if map==iterators then iteratorProto else walkerProto)
			local entry={Root=root,Show=show,Filter=callback,Active=false,Reference={Node=root,Before=true},Current=root}
			value.TraversalState=entry;map[value]=true
			return value
		end)
	end
	function api.DocumentMethod(key)return factories[key]end
	local function adjust(pointer,entry,removed)
		if not contains(removed,pointer.Node)or contains(removed,entry.Root)then return pointer end
		if pointer.Before then local next=following(removed,entry.Root,true,false);if next then return {Node=next,Before=true}end end
		local previous=sibling(removed,-1)
		if previous then while #previous.Children>0 do previous=previous.Children[#previous.Children]end else previous=removed.Parent end
		return {Node=previous,Before=false}
	end
	function api:BeforeRemove(removed)
		if not self.Alive then return end
		for value in iterators do
			local entry=value.TraversalState
			entry.Reference=adjust(entry.Reference,entry,removed)
			if entry.Candidate then entry.Candidate=adjust(entry.Candidate,entry,removed)end
		end
	end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false
		for value in iterators do table.clear(value.TraversalState);value.TraversalState=nil end
		for value in walkers do table.clear(value.TraversalState);value.TraversalState=nil end
		table.clear(iterators);table.clear(walkers);table.clear(factories);table.clear(options)
	end
	return api
end
return Traversal
