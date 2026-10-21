--!strict
local Events = {}

local function disconnect(entry: any)
	if not entry.Connected then return end
	entry.Connected = false
	entry.Callback = nil
	local bucket = entry.Bucket
	entry.Bucket = nil
	local index = table.find(bucket.Entries, entry)
	if index then table.remove(bucket.Entries, index) end
	if #bucket.Entries == 0 then
		local kinds = bucket.Targets[bucket.Target]
		kinds[bucket.Kind] = nil
		if next(kinds) == nil then bucket.Targets[bucket.Target] = nil end
	end
end

function Events.new(diagnostic: any): any
	local targets, alive, pageTarget = {}, true, {}
	local bus = {}
	local observers={}
	-- Runtime observers translate one native dispatch into its JS event realm.
	function bus:BeforeEmit(callback: any): any
		assert(alive and type(callback)=='function','Event observer requires a live page')
		local record={Callback=callback};table.insert(observers,record)
		return {Disconnect=function()record.Callback=nil;local at=table.find(observers,record);if at then table.remove(observers,at)end end}
	end
	function bus:On(node: any, kind: string, callback: any, options: any?): any
		assert(alive and type(callback) == "function", "Event listener requires a live page and callback")
		local target = node or pageTarget
		local kinds = targets[target]
		if not kinds then kinds = {}; targets[target] = kinds end
		local bucket = kinds[kind]
		if not bucket then
			bucket = {Entries = {}, Targets = targets, Target = target, Kind = kind}
			kinds[kind] = bucket
		end
		local capture = options == true or (type(options) == "table" and options.Capture == true)
		local entry = {Callback = callback, Connected = true, Bucket = bucket, Capture = capture,
			Once = type(options) == "table" and options.Once == true, Passive = type(options) == "table" and options.Passive == true}
		table.insert(bucket.Entries, entry)
		-- A retained disconnected handle must not retain its callback or DOM node.
		return {Disconnect = function() disconnect(entry) end}
	end

	function bus:Emit(node: any, kind: string, data: any?, options: any?): any
		local nonBubbling = kind == "focus" or kind == "blur" or kind == "pointerenter" or kind == "pointerleave" or kind == "load"
		local notCancelable = nonBubbling or kind == "input" or kind == "change" or kind == "DOMContentLoaded"
		local event = {Type=kind, Target=node, DefaultPrevented=false, PropagationStopped=false,
			ImmediateStopped=false, Data=data or {}, Phase=0, Bubbles=not nonBubbling, Cancelable=not notCancelable}
		if options then
			if options.Bubbles ~= nil then event.Bubbles = options.Bubbles end
			if options.Cancelable ~= nil then event.Cancelable = options.Cancelable end
			if options.Composed ~= nil then event.Data=table.clone(event.Data);event.Data.composed=options.Composed end
		end
		function event:PreventDefault() if self.Cancelable and not self.Passive then self.DefaultPrevented=true end end
		function event:StopPropagation() self.PropagationStopped=true end
		function event:StopImmediatePropagation() self.ImmediateStopped=true; self.PropagationStopped=true end
		for _,observer in table.clone(observers)do
			if not alive then break end
			if observer.Callback then local ok,message=pcall(observer.Callback,event);if not ok then diagnostic('Event observer: '..tostring(message))end end
		end
		local path, current = {}, node
		while current do table.insert(path,current); current=current.Parent end
		table.insert(path,pageTarget)
		local function dispatch(target: any, capture: boolean, phase: number)
			event.CurrentTarget = if target == pageTarget then nil else target
			event.Phase = phase
			local kinds = targets[target]
			local bucket = kinds and kinds[kind]
			if not bucket then return end
			for _, entry in table.clone(bucket.Entries) do
				if not alive or event.ImmediateStopped then break end
				if not entry.Connected or entry.Capture ~= capture then continue end
				local callback = entry.Callback
				if entry.Once then disconnect(entry) end
				event.Passive = entry.Passive
				local ok, message = pcall(callback,event)
				event.Passive = false
				if not ok then diagnostic("Event listener: " .. tostring(message)) end
			end
		end
		for i=#path,2,-1 do
			if not alive or event.PropagationStopped then break end
			dispatch(path[i],true,1)
		end
		if alive and not event.PropagationStopped then
			dispatch(path[1],true,2)
			if alive and not event.ImmediateStopped then dispatch(path[1],false,2) end
		end
		if event.Bubbles then
			for i=2,#path do
				if not alive or event.PropagationStopped then break end
				dispatch(path[i],false,3)
			end
		end
		event.CurrentTarget, event.Phase = nil, 0
		return event
	end
	function bus:Destroy()
		if not alive then return end
		alive = false
		for _,observer in observers do observer.Callback=nil end;table.clear(observers)
		for _, kinds in targets do
			for _, bucket in kinds do
				for _, entry in bucket.Entries do
					entry.Connected, entry.Callback, entry.Bucket = false, nil, nil
				end
				table.clear(bucket.Entries)
			end
		end
		table.clear(targets)
	end
	return bus
end
return Events
