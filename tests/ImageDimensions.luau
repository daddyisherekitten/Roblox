--!strict
return function(loadDimensions, Parser, loadRenderTree, loadWordLayout)
	local queue, requests, released, changes, diagnostics = {}, 0, 0, 0, {}
	local alive, duringRead, mode = true, nil, "success"
	local dimensions = loadDimensions({GetService = function(_, service)
		assert(service == "AssetService")
		return {CreateEditableImageAsync = function(_, source)
			requests += 1
			assert(source == "rbxassetid://123")
			if duringRead then duringRead() end
			if mode == "throw" then error("access denied") end
			if mode == "nil" then return nil end
			return {Size = {X = if mode == "invalid" then 0 else 640, Y = 320}, Destroy = function() released += 1 end}
		end}
	end}, {defer = function(fn) table.insert(queue, fn) end})
	local renderer = loadRenderTree({create = function(_, _, props) return table.clone(props) end})
	local measurements = 0
	local layout = loadWordLayout({["Layout/FontProfiles"] = {face = function(font) return font end}, ["Layout/TextMeasure"] = {measure = function(_, _, size)
		measurements += 1; return {X = 20, Y = size}
	end}})
	local function build(html)
		local tree = renderer.build(Parser.parse('<p>' .. html .. '</p>'), {}, error, nil, nil, nil, function() return "rbxassetid://123" end)
		return tree.Children[1].Children[1], tree.ImageItems
	end
	local function arrange(run) return layout.arrange(run, 1000, 0, 0, function() return alive end) end
	local function start(items)
		return dimensions.start(items, function() return alive end, function(message) table.insert(diagnostics, message) end,
			function() changes += 1 end)
	end
	local function drain() while #queue > 0 do table.remove(queue, 1)() end end
	local run, items = build('<img src="x"><img src="x" width="100"><img src="x" height="60"><img src="x" width="80" height="90">')
	arrange(run)
	assert(items[1].Width == 300 and items[1].Height == 150)
	assert(items[2].Width == 100 and items[2].Height == 150)
	local stop = start(items)
	assert(requests == 0, "Dimension lookup must not block mount")
	local cachedItems = table.clone(items)
	table.clear(items) -- ImageLoad releases its preload list independently.
	drain(); arrange(run)
	assert(requests == 1 and released == 1 and changes == 1 and #diagnostics == 0)
	assert(cachedItems[1].Width == 640 and cachedItems[1].Height == 320)
	assert(cachedItems[2].Width == 100 and cachedItems[2].Height == 50)
	assert(cachedItems[3].Width == 120 and cachedItems[3].Height == 60)
	assert(cachedItems[4].Width == 80 and cachedItems[4].Height == 90, "Explicit dimensions win")
	arrange(run)
	assert(requests == 1 and measurements == 0, "Resize neither reloads metadata nor measures image text")
	stop(); stop()
	local fixed, fixedItems = build('<img src="x" width="0" height="0"><img src="x" style="width: 100%; height: 30px">')
	local stopFixed=start(fixedItems)
	assert(stopFixed and #queue == 0, "Fully specified sizes need no EditableImage until a dynamic crop requests it")
	arrange(fixed)
	assert(fixedItems[1].Width == 0 and fixedItems[2].Width == 1000)
	local fixedRequests=requests
	fixedItems[2].Style.ObjectViewBox={Kind='inset',Values={{Value=10,Percent=true},{Value=10,Percent=true},{Value=10,Percent=true},{Value=10,Percent=true}}}
	arrange(fixed);assert(requests==fixedRequests and #queue==1,'Hover crop must request metadata asynchronously')
	drain();arrange(fixed);assert(requests==fixedRequests+1 and fixedItems[2].IntrinsicWidth==640)
	stopFixed();assert(not fixedItems[2].RequestDimensions)
	local constrained, constrainedItems = build('<img src="x" style="max-width: 160px"><img src="x" width="10" height="10" style="width: 120px; height: auto; box-sizing: border-box; padding: 8px; border: 2px solid red;">')
	start(constrainedItems); drain(); arrange(constrained)
	assert(constrainedItems[1].Width == 160 and constrainedItems[1].Height == 80)
	assert(constrainedItems[2].Width == 120 and constrainedItems[2].Height == 70, "Auto axis uses intrinsic ratio after border-box conversion")
	for _, failure in {"throw", "nil", "invalid"} do
		mode = failure
		local failedRun, failedItems = build('<img src="x" alt="Picture"><img src="x" alt="Again">')
		local before, notices, reflows = requests, #diagnostics, changes
		start(failedItems); drain(); arrange(failedRun); arrange(failedRun)
		assert(requests == before + 1 and #diagnostics == notices + 1 and changes == reflows)
		for _, item in failedItems do
			assert(item.Width == 300 and item.Height == 150 and not item.LoadFailed and not item.TextFallback)
			assert(not item.ErrorGui.Visible and not item.FallbackGui.Visible, "Metadata failure is not an image failure")
		end
	end
	mode = "success"
	local _, abandoned = build('<img src="x">')
	local before = requests
	stop = start(abandoned); stop(); drain()
	assert(requests == before, "Disposal before lookup avoids allocating")
	local reflows, frees = changes, released
	stop = start(abandoned)
	duringRead = function() stop() end
	drain()
	assert(changes == reflows and released == frees + 1 and abandoned[1].IntrinsicWidth == nil, "Cleanup during lookup can clear groups immediately")
	frees = released
	duringRead = function() alive = false end
	start(abandoned); drain()
	assert(changes == reflows and released == frees + 1 and abandoned[1].IntrinsicWidth == nil, "Disposal during a yielding lookup releases the image without touching layout")
	alive, duringRead = true, nil
	local fitted, fitItems = build('<img src="x" width="100" height="80" style="object-fit: none"><img src="x" width="100" height="80" style="object-fit: scale-down"><img src="x" width="100" height="80" style="object-fit: cover; object-position: right">')
	before, frees, reflows = requests, released, changes
	start(fitItems); drain(); arrange(fitted)
	assert(requests == before + 1 and released == frees + 1 and changes == reflows + 1, 'Custom fitting shares one metadata request despite explicit sizes')
	assert(fitItems[1].ImageGui.Size[1] == 640 and fitItems[1].Width == 100)
	assert(fitItems[2].ImageGui.Size[1] == 100 and fitItems[2].ImageGui.Size[2] == 50)
	assert(fitItems[3].ImageGui.Position[1] == -60 and fitItems[3].ImageGui.Size[1] == 160)
	mode = 'throw'
	local failedFit, failedFitItems = build('<img src="x" width="100" height="80" style="object-fit: none">')
	start(failedFitItems); drain(); arrange(failedFit)
	assert(failedFitItems[1].ImageGui.Size[1] == 100 and not failedFitItems[1].ErrorGui.Visible)
	mode = 'success'
	local _, determined = build('<img src="x" style="width: 120px; aspect-ratio: 1"><img src="x" style="height: 120px; aspect-ratio: 2; object-fit: contain">')
	local determinedRequests=requests
	local stopDetermined=start(determined);assert(#queue==0 and requests==determinedRequests, 'A fixed ratio with one explicit axis needs no metadata for native fitting')
	stopDetermined()
	local provisional, provisionalItems = build('<img src="x" style="width: 120px; aspect-ratio: auto 1"><img src="x" style="width: 120px; aspect-ratio: 1; object-fit: none">')
	arrange(provisional)
	assert(provisionalItems[1].Height == 120)
	before, reflows = requests, changes
	start(provisionalItems); drain(); arrange(provisional)
	assert(requests == before + 1 and changes == reflows + 1)
	assert(provisionalItems[1].Height == 60 and provisionalItems[2].Height == 120, 'auto ratio switches to natural; fixed ratio survives metadata arrival')
	assert(provisionalItems[2].ImageGui.Size[1] == 640, 'Custom fitting still requests natural dimensions for a fixed-ratio box')
	do
		local _,densityItems=build('<img srcset="x 2x"><img srcset="x .5x"><img srcset="x 0x">')
		local callbacks={};local densityChanges=0
		local stopDensity,densityRuntime=dimensions.start(densityItems,function()return true end,error,function()densityChanges+=1 end,{LoadDimensions=function(_,complete)table.insert(callbacks,complete)end})
		assert(#callbacks==1,'One decoded resource serves differing per-element densities')
		callbacks[1](true,{Width=200,Height=100})
		assert(densityItems[1].IntrinsicWidth==100 and densityItems[2].IntrinsicWidth==400 and densityItems[3].IntrinsicWidth==33554431,'Shared decoded pixels become each IMG density-corrected intrinsic dimensions')
		assert(densityItems[1].PixelWidth==200 and densityItems[2].PixelWidth==200,'Shared metadata retains raw decoded dimensions independently')
		local _,lateDensityItems=build('<img srcset="x 4x">');densityRuntime:Add(lateDensityItems)
		assert(#callbacks==1 and lateDensityItems[1].IntrinsicWidth==50 and densityChanges==1,'Late registration uses shared cached pixels with its own density')
		stopDensity()
	end
	do
		local _, sharedItems=build('<img src="x"><img src="x">')
		local callbacks,cancellations={},0
		local sharedChanges=0
		local function sharedStart(items)return dimensions.start(items,function()return true end,error,function()sharedChanges+=1 end,{LoadDimensions=function(uri,callback)
			assert(uri=="rbxassetid://123");table.insert(callbacks,callback);return function()cancellations+=1 end
		end})end
		local stopShared,sharedRuntime=sharedStart(sharedItems)
		assert(#callbacks==1,"Two retained images share the host metadata request")
		callbacks[1](true,{Width=640,Height=320});assert(sharedChanges==1 and sharedItems[2].IntrinsicWidth==640)
		stopShared();assert(cancellations==0,"Completed metadata listeners need no cancellation")
		local _, removed=build('<img src="x">')
		_,sharedRuntime=sharedStart(removed);sharedRuntime:Remove(removed);assert(cancellations==1)
		callbacks[2](true,{Width=99,Height=88});assert(removed[1].IntrinsicWidth==nil and sharedChanges==1,"A detached image cannot receive obsolete shared metadata")
		local _, known=build('<img src="x">');known[1].IntrinsicWidth,known[1].IntrinsicHeight=640,320
		stopShared=sharedStart(known);callbacks[3](true,{Width=640,Height=320});assert(sharedChanges==1,"Already published metadata does not request a redundant layout");stopShared()
		local _,changedSource=build('<img src="x">');local sourceCallbacks={}
		_,sharedRuntime=dimensions.start(changedSource,function()return true end,error,function()end,{LoadDimensions=function(uri,callback)table.insert(sourceCallbacks,{URI=uri,Finish=callback});return function()end end})
		changedSource[1].Source='rbxassetid://456';sharedRuntime:Remove(changedSource);sharedRuntime:Add(changedSource)
		local _,oldSource=build('<img src="x">');sharedRuntime:Add(oldSource)
		assert(#sourceCallbacks==3 and sourceCallbacks[3].URI=='rbxassetid://123','Source changes remove the old metadata group by its registered source, not its new item URI')
		sourceCallbacks[1].Finish(true,{Width=1,Height=1});assert(not changedSource[1].IntrinsicWidth and not oldSource[1].IntrinsicWidth,'Obsolete source completion cannot publish into the replacement registration')
		sharedRuntime:Destroy()
	end
	print("Image dimensions: per-page asset reuse, CSS precedence/ratio, custom fits, constraints, safe fallback and disposal passed")
end
