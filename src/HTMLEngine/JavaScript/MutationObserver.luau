--!strict
-- DOM Standard observer registrations, pending set and delivery microtask.
-- Raw node mutations are supplied by DOM; GUI refresh is a separate concern.
local MutationObservers={}
function MutationObservers.install(vm: any,globals: any,options: any): any
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null
	local host={Alive=true}
	local registrations=setmetatable({},{__mode="k"})
	local observers=setmetatable({},{__mode="kv"})
	local recordStates=setmetatable({},{__mode="kv"})
	local nodeLists=setmetatable({},{__mode="kv"})
	local pending,pendingSet,queued={},{},false
	local observerCount=0
	local observerPrototype,recordPrototype=vm.Object({}),vm.Object({})
	local function check()assert(host.Alive and vm.Alive,"Mutation observers disposed")end
	local function fail(message)VM.throw(VM.error("TypeError",message))end
	local function native(name,length,action)
		local fn={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return action(args,receiver)end}
		vm.DefineProperty(fn,"name",vm.Object({value=name,configurable=true},VM.Null));vm.DefineProperty(fn,"length",vm.Object({value=length,configurable=true},VM.Null))
		return fn
	end
	local function define(target,key,value)vm.DefineProperty(target,key,vm.Object({value=value,writable=true,configurable=true},VM.Null))end
	local function state(receiver)local entry=observers[receiver];if not entry then fail("Illegal MutationObserver receiver")end;return entry end
	local listMethods={}
	listMethods.item=native("item",1,function(args,receiver)
		local values=nodeLists[receiver];if not values then fail("Illegal NodeList receiver")end
		local n=VM.number(args[1]);if n~=n or n==math.huge or n==-math.huge then n=0 end
		n=(if n<0 then math.ceil(n)else math.floor(n))%4294967296;return values[n+1] or N
	end)
	listMethods.forEach=native("forEach",1,function(args,receiver)
		local values=nodeLists[receiver];if not values then fail("Illegal NodeList receiver")end
		if not VM.callable(args[1])then fail("NodeList.forEach callback must be callable")end
		for i,value in values do vm.Step();vm:Call(args[1],{value,i-1,receiver},args[2])end;return U
	end)
	for _,kind in {"values","keys","entries"}do listMethods[kind]=native(kind,0,function(_,receiver)
		local values=nodeLists[receiver];if not values then fail("Illegal NodeList receiver")end
		local index,done=0,false
		local nextValue=function()
			check();if done or index>=#values then done=true;return vm.Object({value=U,done=true})end
			local value=if kind=="keys"then index elseif kind=="entries"then vm.Array({index,values[index+1]})else values[index+1]
			index+=1;return vm.Object({value=value,done=false})
		end
		local iterator=vm.Object({next=nextValue})
		if vm.SymbolIterator then iterator.Values[vm.SymbolIterator]=function()return iterator end end
		return iterator
	end)end
	if vm.SymbolIterator then listMethods[vm.SymbolIterator]=listMethods.values end
	local function list(nodes)
		local values={};for _,node in nodes do table.insert(values,options.Wrap(node))end
		local view={HostState=values,Get=function(key)
			check();if key=="length"then return #values elseif listMethods[key]then return listMethods[key]elseif key==vm.SymbolToStringTag then return "NodeList"end
			local index=if type(key)=="string"then tonumber(key)else nil
			return if index and index>=0 and index%1==0 and tostring(index)==key then values[index+1] or U else U
		end,Set=function(key,_,strict)if strict~=false then fail("Read-only NodeList property: "..VM.string(key))end end,
			Keys=function()local keys={};for i=1,#values do table.insert(keys,tostring(i-1))end;return keys end,
			Iterator=function()local index=0;return function()check();index+=1;return index<=#values,values[index] or U end end}
		view.Has=function(key)return view.Get(key)~=U end
		nodeLists[view]=values
		return view
	end
	local function mutation(raw,old)
		local value=vm.Object({},recordPrototype)
		local data={type=raw.Type,target=options.Wrap(raw.Target),addedNodes=list(raw.AddedNodes or {}),removedNodes=list(raw.RemovedNodes or {}),
			previousSibling=options.Wrap(raw.PreviousSibling),nextSibling=options.Wrap(raw.NextSibling),
			attributeName=raw.AttributeName or N,attributeNamespace=raw.AttributeNamespace or N,oldValue=old}
		value.HostState=data;recordStates[value]=data;return value
	end
	for _,name in {"type","target","addedNodes","removedNodes","previousSibling","nextSibling","attributeName","attributeNamespace","oldValue"}do
		vm.DefineProperty(recordPrototype,name,vm.Object({get=native("get "..name,0,function(_,receiver)
			local data=recordStates[receiver];if not data then fail("Illegal MutationRecord receiver")end;return data[name]
		end),enumerable=true,configurable=true},VM.Null))
	end
	local function removeTransient(entry,source)
		for node in entry.Nodes do
			local listForNode=registrations[node]
			if listForNode then for index=#listForNode,1,-1 do
				local registered=listForNode[index]
				if registered.Observer==entry.Value and registered.Source and(not source or registered.Source==source)then table.remove(listForNode,index)end
			end;if #listForNode==0 then registrations[node]=nil end end
		end
	end
	local function deliver()
		if not host.Alive then return end
		queued=false;local notify=pending;pending={};pendingSet={}
		for _,value in notify do
			local entry=observers[value]
			if entry then
				local records=entry.Queue;entry.Queue={};removeTransient(entry)
				if #records>0 then
					local ok,failure=pcall(function()vm:Call(entry.Callback,{vm.Array(records),value},value)end)
					if not ok and host.Alive and options.Report then options.Report(VM.exceptionValue(failure))end
				end
			end
		end
	end
	local function schedule()
		if queued then return end;queued=true;options.Enqueue(deliver)
	end
	local function makePending(value)
		if not pendingSet[value]then pendingSet[value]=true;table.insert(pending,value)end
	end
	local function dictionary(value)
		if value==nil or value==U or value==N then value=vm.Object({})end
		if type(value)~="table"and type(value)~="function"then fail("MutationObserver options must be a dictionary")end
		local converted={}
		for _,name in {"attributeFilter","attributeOldValue","attributes","characterData","characterDataOldValue","childList","subtree"}do
			local item=vm.Get(value,name)
			if item~=U then
				if name=="attributeFilter"then
					local filter={};local nextValue,close=vm.Iterator(item)
					local ok,failure=pcall(function()
						while true do vm.Step();local exists,nextItem=nextValue();if not exists then break end
							assert(#filter<16384,"MutationObserver filter budget exceeded");table.insert(filter,VM.string(nextItem))
						end
					end)
					if not ok then if close then pcall(close)end;error(failure,0)end
					converted[name]=filter
				else converted[name]=VM.truth(item)end
			end
		end
		if converted.attributes==nil and(converted.attributeOldValue~=nil or converted.attributeFilter~=nil)then converted.attributes=true end
		if converted.characterData==nil and converted.characterDataOldValue~=nil then converted.characterData=true end
		if not converted.childList and not converted.attributes and not converted.characterData then fail("At least one mutation type must be observed")end
		if not converted.attributes and(converted.attributeOldValue==true or converted.attributeFilter~=nil)then fail("Attribute options require attributes")end
		if not converted.characterData and converted.characterDataOldValue then fail("characterDataOldValue requires characterData")end
		return converted
	end
	define(observerPrototype,"observe",native("observe",2,function(args,receiver)
		if #args<2 then fail("observe requires a node and options")end
		local entry=state(receiver);local node=options.Unwrap(args[1]);if not node then fail("observe requires a node from this document")end
		local converted=dictionary(args[2])
		local bucket=registrations[node];if not bucket then bucket={};registrations[node]=bucket end
		for _,registered in bucket do if registered.Observer==receiver and not registered.Source then
			removeTransient(entry,registered);registered.Options=converted;return U
		end end
		table.insert(bucket,{Observer=receiver,Options=converted});entry.Nodes[node]=true;return U
	end))
	define(observerPrototype,"disconnect",native("disconnect",0,function(_,receiver)
		local entry=state(receiver)
		for node in entry.Nodes do
			local bucket=registrations[node];if bucket then for index=#bucket,1,-1 do if bucket[index].Observer==receiver then table.remove(bucket,index)end end;if #bucket==0 then registrations[node]=nil end end
		end
		table.clear(entry.Nodes);entry.Queue={};return U
	end))
	define(observerPrototype,"takeRecords",native("takeRecords",0,function(_,receiver)local entry=state(receiver);local records=entry.Queue;entry.Queue={};return vm.Array(records)end))
	local constructor=native("MutationObserver",1,function()fail("MutationObserver requires new")end)
	constructor.Construct=function(args)
		check();if not VM.callable(args[1])then fail("MutationObserver callback must be callable")end
		observerCount+=1;assert(observerCount<=1024,"MutationObserver allocation budget exceeded")
		local value=vm.Object({},observerPrototype)
		local entry={Value=value,Callback=args[1],Nodes=setmetatable({},{__mode="k"}),Queue={}}
		value.HostState=entry;observers[value]=entry;return value
	end
	vm.DefineProperty(constructor,"prototype",vm.Object({value=observerPrototype},VM.Null));define(observerPrototype,"constructor",constructor)
	globals.MutationObserver=constructor;vm.Global.Bindings.MutationObserver={Value=constructor}
	local recordConstructor=native("MutationRecord",0,function()fail("Illegal MutationRecord constructor")end)
	recordConstructor.Construct=function()fail("Illegal MutationRecord constructor")end
	vm.DefineProperty(recordConstructor,"prototype",vm.Object({value=recordPrototype},VM.Null));define(recordPrototype,"constructor",recordConstructor)
	globals.MutationRecord=recordConstructor;vm.Global.Bindings.MutationRecord={Value=recordConstructor}
	if vm.SymbolToStringTag then
		vm.DefineProperty(observerPrototype,vm.SymbolToStringTag,vm.Object({value="MutationObserver",configurable=true},VM.Null))
		vm.DefineProperty(recordPrototype,vm.SymbolToStringTag,vm.Object({value="MutationRecord",configurable=true},VM.Null))
	end
	local function ancestry(raw)
		if raw.Ancestors then return raw.Ancestors end
		local nodes,current={},raw.Target;while current do table.insert(nodes,current);current=current.Parent end;return nodes
	end
	function host:Notify(raw)
		check()
		-- Most documents never register an observer. Avoid walking the DOM and
		-- waking the microtask driver for mutations nobody can receive.
		if next(registrations)==nil then return end
		local nodes=ancestry(raw);local interested,order={},{ }
		-- Install transient registrations even when childList itself is filtered.
		if raw.Type=="childList"then for _,removed in raw.RemovedNodes or {}do
			for _,node in nodes do for _,registered in table.clone(registrations[node] or {})do
				if registered.Options.subtree then
					-- Removal queues the observer even when childList is filtered:
					-- the notification microtask must expire transient registrations.
					makePending(registered.Observer)
					local bucket=registrations[removed];if not bucket then bucket={};registrations[removed]=bucket end
					local source=registered.Source or registered;local duplicate=false
					for _,other in bucket do if other.Observer==registered.Observer and other.Source==source then duplicate=true;break end end
					if not duplicate then table.insert(bucket,{Observer=registered.Observer,Options=registered.Options,Source=source});state(registered.Observer).Nodes[removed]=true end
				end
			end end
		end end
		for _,node in nodes do for _,registered in registrations[node] or {}do
			local config=registered.Options
			if node~=raw.Target and not config.subtree then continue end
			if raw.Type=="attributes"then
				if not config.attributes then continue end
				if config.attributeFilter and(raw.AttributeNamespace~=nil or not table.find(config.attributeFilter,raw.AttributeName))then continue end
			elseif raw.Type=="characterData"then if not config.characterData then continue end
			elseif raw.Type=="childList"then if not config.childList then continue end
			else continue end
			local value=registered.Observer
			if interested[value]==nil then interested[value]=false;table.insert(order,value)end
			if(raw.Type=="attributes"and config.attributeOldValue)or(raw.Type=="characterData"and config.characterDataOldValue)then interested[value]=true end
		end end
		for _,value in order do
			local entry=state(value);assert(#entry.Queue<16384,"MutationObserver record budget exceeded")
			table.insert(entry.Queue,mutation(raw,if interested[value]then raw.OldValue or N else N))
			makePending(value)
		end
		-- Filtered subtree removals still make their observer pending so its
		-- transient registrations expire at the checkpoint, even without records.
		if #pending>0 then schedule()end
	end
	function host:Destroy()
		if not self.Alive then return end;self.Alive=false
		for _,entry in observers do entry.Callback=nil;table.clear(entry.Queue);table.clear(entry.Nodes)end
		table.clear(registrations);table.clear(observers);table.clear(recordStates);table.clear(nodeLists);table.clear(pending);table.clear(pendingSet)
	end
	host.Constructor=constructor;host.Prototype=observerPrototype
	return host
end
return MutationObservers
