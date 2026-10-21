--!strict
-- Test the real Luau weak-table behavior: registries must not root a realm
-- through a value -> prototype -> weak-key cycle.
return function(Parser, Runtime, VM, Events)
	local closed = setmetatable({}, {__mode = "k"})
	local function bare()
		local vm = VM.new({})
		closed[vm] = true
		closed[vm.Prototypes.Object] = true
		vm:Destroy()
	end
	local function page()
		local runtime = Runtime.new(Parser.parseDocument("<html><head></head><body></body></html>"), {
			Events = Events.new(error), URL = "https://example.test/lifetime",
		})
		closed[runtime] = true
		closed[runtime.VM] = true
		closed[runtime.VM.Prototypes.Object] = true
		runtime:Destroy()
	end
	local function pressure(untilCollected)
		-- The official Luau CLI has no forced-GC API. Allocate independent
		-- garbage until a collection completes, with a bounded failure limit.
		for batch = 1, 2048 do
			if untilCollected and next(untilCollected) == nil then return end
			local garbage = table.create(2048)
			for i = 1, 2048 do garbage[i] = {i, batch} end
		end
	end
	bare()
	page()
	pressure(closed)
	assert(next(closed) == nil, "Disposed VMs, runtimes and prototypes must be collectible")
	local transient=setmetatable({},{__mode='k'})
	local function liveMaps()
		local document=Parser.parseDocument('<!doctype html><div id="transient"></div><div id="persistent"></div>');local pending={document};local node
		while #pending>0 do local current=table.remove(pending);if current.Attributes and current.Attributes.id=='transient'then node=current;break end;for _,child in current.Children do table.insert(pending,child)end end
		local runtime=Runtime.new(document,{Events=Events.new(error)})
		assert(runtime:Run("(()=>{const p=document.getElementById('persistent');p.marker=52;p.same=p.attributeStyleMap;p.computed=p.computedStyleMap();const el=document.getElementById('transient');el.attributeStyleMap;el.computedStyleMap();el.remove();})()"))
		assert(node and node.TypedOMStyleMaps);transient[node]=true
		for _,slot in node.TypedOMStyleMaps do transient[slot.Inline]=true;transient[slot.Computed]=true end
		runtime:Flush();runtime:PumpTasks();return runtime
	end
	local live=liveMaps();pressure(transient)
	assert(next(transient)==nil,'An active runtime must not root detached DOM trees through SameObject style maps')
	assert(live:Run("(()=>{const p=document.getElementById('persistent');if(p.marker!==52||p.same!==p.attributeStyleMap||p.computed!==p.computedStyleMap())throw new Error('Connected node identity was lost during GC');})()"))
	live:Destroy();live=nil

	local kept = setmetatable({}, {__mode = "k"})
	local function heldObject()
		local vm = VM.new({})
		kept[vm] = true
		-- Neither this prototype nor these host functions refer to the VM.
		return vm.Object({
			toString = function() return "kept conversion" end,
			valueOf = function() return 37 end,
		}, VM.Null)
	end
	local held = heldObject()
	pressure(closed)
	-- Exercise at least one full collection while only the wrapper owns its
	-- realm, then verify conversion still dispatches to the original VM.
	pressure()
	assert(next(kept) ~= nil, "A held wrapper retains its conversion realm")
	assert(VM.string(held) == "kept conversion" and VM.number(held) == 37)
	assert(not held.VMOwner.ObjectModel.HasOwn(held, "VMOwner"), "Private ownership is not a JS property")
	for _,key in held.VMOwner.ObjectModel.OwnKeys(held) do
		assert(key ~= "VMOwner", "Private ownership is not enumerable")
	end
	held = nil
	pressure(kept)
	assert(next(kept) == nil, "Releasing the final wrapper releases its realm")
	print("JavaScript realm lifetime: disposed pages collect; held objects preserve private conversion ownership")
end
