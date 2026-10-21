--!strict
-- Real PageSession/HTMLPage logic with deterministic GUI/event substitutes.
-- This checks scheduling and disposal, not Roblox rendering.
return function(PageSession: any, loadHTMLPage: any)
	local function signal(deferCallback: any?)
		local callbacks = {}
		return {
			Connect = function(_, callback)
				local connection = { Connected = true }
				function connection:Disconnect() self.Connected = false end
				table.insert(callbacks, { Connection = connection, Callback = callback })
				return connection
			end,
			Fire = function()
				for _, entry in callbacks do if entry.Connection.Connected then
					if deferCallback then
						deferCallback(function() if entry.Connection.Connected then entry.Callback() end end)
					else entry.Callback() end
				end end
			end,
		}
	end
	local function root(deferAttributes: any?)
		local self = { Destroying = signal(), Resized = signal(), AbsoluteSize = { X = 400, Y = 300 }, ScrollBarThickness = 10, Attributes = {}, DestroyCalls = 0 }
		local properties = {AbsoluteSize = self.Resized}
		local attributes = {}
		function self:GetPropertyChangedSignal(name)
			if not properties[name] then properties[name] = signal() end
			return properties[name]
		end
		function self:GetAttribute(key) return self.Attributes[key] end
		function self:GetAttributeChangedSignal(key)
			if not attributes[key] then attributes[key] = signal(deferAttributes) end
			return attributes[key]
		end
		function self:SetAttribute(key, value)
			local changed = self.Attributes[key] ~= value
			self.Attributes[key] = value
			if changed and attributes[key] then attributes[key]:Fire() end
		end
		function self:Destroy()
			self.DestroyCalls += 1
			assert(self.DestroyCalls == 1, "Recursive or duplicate destruction")
			self.Destroying:Fire()
		end
		return self
	end
	local function factory(viewport)
		return {create = function(class, parent, properties)
			local object = if class == "ScrollingFrame" then viewport else root()
			-- These scheduling fixtures use synthetic boxes without native surfaces.
			if class ~= "ScrollingFrame" then object.Parent = parent end
			for key, value in properties do object[key] = value end
			return object
		end}
	end
	local external = root()
	local session = PageSession.new(external)
	local cleaned = 0
	session:AddCleanup(function() cleaned += 1 end)
	external:Destroy()
	session:Destroy()
	session:AddCleanup(function() cleaned += 1 end)
	assert(not session.Alive and cleaned == 2 and external.DestroyCalls == 1)
	local queue, viewport, widths = {}, root(), {}
	local now = 0
	local function clock() return now end
	local function delay(seconds, callback)
		local token = {Cancelled = false}
		local due = now + seconds
		table.insert(queue, function()
			if not token.Cancelled then now = math.max(now, due); callback() end
		end)
		return token
	end
	local runtime = {defer = function(callback) table.insert(queue, callback) end,
		delay = delay, cancel = function(token) token.Cancelled = true end}
	local duringLayout = nil
	local scrollChanged = signal()
	local repaints = 0
	local duringRepaint
	local scrollRun = {Kind = "Words"}
	local outputA, outputB = {}, {}
	local outputRunA, outputRunB = {Kind="Words",Items={outputA}}, {Kind="Words",Items={outputB}}
	local textBox={Style={},Children={}}
	local textFits,textChecks,duringTextCheck=false,0,nil
	local outputChanged
	local scriptChanged
	local sameSize = {}
	local duringSizeCheck
	local sizeChecks = 0
	local layoutKinds, dirtySnapshots = {}, {}
	local layoutExtraWidth = 0
	local scrollGui = {CanvasPosition = Vector2.new(0, 0), GetPropertyChangedSignal = function() return scrollChanged end}
	local preloadStarted = false
	local imagesStarted = false
	local imagesStopped = 0
	local imageChanged
	local dimensionsChanged
	local dimensionsStopped = 0
	local patternsDisposed = 0
	local patterns = {Destroy = function() patternsDisposed += 1 end}
	local insetsDisposed = 0
	local insets = {Destroy = function() insetsDisposed += 1 end}
	local radioDisposed = 0
	local radioDot = {Destroy = function() radioDisposed += 1 end}
	local function drain()
		while #queue > 0 do table.remove(queue, 1)() end
	end
	local pageModule = loadHTMLPage({
		["Input/Controller"] = {start = function() end}, -- Input/cursor lifecycle is exercised separately.
		["Rendering/GuiFactory"] = factory(viewport),
		["Rendering/DecorationPatterns"] = {new = function() return patterns end},
		["Rendering/InsetShadows"] = {new = function() return insets end},
		["Rendering/RadioDot"] = {new = function() return radioDot end},
		["Rendering/RenderTree"] = { build = function(_, _, _, resolveFont, pagePatterns, pageInsets, resolveImage, css, defaultFont, _, pageRadioDot, _, stylesheets, _, mediaResolver)
			assert(pageRadioDot == radioDot, "The page forwards its shared radio image cache")
			assert(defaultFont == "Inter", "The page passes its configured default font")
			assert(css == "p {color: blue}", "The mount API forwards separate CSS unchanged")
			assert(stylesheets and stylesheets['styles.css'] == 'p {color: green}', "The mount API forwards linked stylesheets unchanged")
			assert(type(resolveFont) == "function")
			assert(pagePatterns == patterns, "The page supplies its own pattern cache")
			assert(pageInsets == insets)
			assert(resolveImage("landschaft.png") == "rbxassetid://6319951718")
			assert(mediaResolver:Asset("audio","tone.mp3") == "rbxassetid://12")
			assert(mediaResolver:Asset("video","clip.mp4") == "rbxassetid://21")
			assert(mediaResolver:Track("captions.vtt") == "WEBVTT\n")
			return { FontPreloadTargets = { "used-font-label" }, ImageItems = {"used-image"}, Children = {{ScrollGui = scrollGui, Style = {TextOverflow = "ellipsis"}, Children = {scrollRun}},outputRunA,outputRunB,textBox},
				CanKeepTextLayout=function(_,item,_,alive)
					if item~=textBox then return false end
					textChecks+=1
					if duringTextCheck then local callback=duringTextCheck;duringTextCheck=nil;callback() end
					return textFits and alive()
				end }
		end },
		["Input/Controller"] = {start = function(_,_,request) outputChanged=request end},
		["Rendering/HTMLScripts"] = {ShouldStart=function()return true end,hasScripts=function()return false end,start = function(page,_,schedule)
			local pending,targets,layout=false,{},false
			local scripting={HasOwnBlockingStylesheets=function()return false end,
				SubscribeStylesheetChanges=function()return function()end end,
				HasPending=function()return pending end,Flush=function()
				pending=false
				local needed,items=layout,targets
				layout,targets=false,{}
				return needed,items
			end}
			page.JavaScriptRuntime=scripting
			scriptChanged=function(item)
				pending=true
				if item then layout=true;targets[item]=true end
				schedule()
			end
		end},
		["Controls/View"] = {canKeepLayout = function(item)
			sizeChecks+=1
			if duringSizeCheck then local callback=duringSizeCheck; duringSizeCheck=nil; callback() end
			return sameSize[item] == true
		end},
		["Rendering/ImageLoad"] = { start = function(items, alive, _, changed)
			assert(items[1] == "used-image" and alive())
			imagesStarted = true
			imageChanged = changed
			return function() imagesStopped += 1 end
		end },
		["Rendering/ImageDimensions"] = { start = function(items, alive, _, changed)
			assert(items[1] == "used-image" and alive())
			dimensionsChanged = changed
			return function() dimensionsStopped += 1 end
		end },
		["Rendering/FontPreload"] = { start = function(targets, alive)
			assert(targets[1] == "used-font-label" and alive())
			preloadStarted = true
		end },
		["Layout/WordLayout"] = {repaint = function(run, alive)
			assert(run == scrollRun and alive())
			repaints += 1
			if duringRepaint then local callback = duringRepaint; duringRepaint = nil; callback() end
		end},
		["Layout/BlockLayout"] = { arrange = function(tree, width)
			assert(preloadStarted, "Font preload must start before first layout")
			assert(imagesStarted, "Images load alongside the initial layout")
			table.insert(widths, width)
			table.insert(layoutKinds,tree.DirtyContext.Stats.Mode)
			table.insert(dirtySnapshots,table.clone(tree.DirtyContext.Dirty))
			if duringLayout then local callback = duringLayout; duringLayout = nil; callback() end
			return 120, width + layoutExtraWidth
		end },
	}, runtime, clock)
	local imageMap = {["landschaft.png"] = 6319951718}
	for _, invalidCSS in {false, 123, {}} do
		local ok, message = pcall(pageModule.mount, {}, "<p>test</p>", {CSS = invalidCSS})
		assert(not ok and tostring(message):find('options.CSS', 1, true))
		assert(viewport.Attributes.Status == nil and #queue == 0, 'Invalid CSS options must fail before allocating a page')
	end
	for _, invalidStylesheets in {false, 123, {['styles.css']=false}, {[1]='p{}'}, {['']='p{}'}} do
		local ok, message = pcall(pageModule.mount, {}, '<p>test</p>', {Stylesheets = invalidStylesheets})
		assert(not ok and tostring(message):find('options.Stylesheets', 1, true))
		assert(viewport.Attributes.Status == nil and #queue == 0, 'Invalid stylesheet maps must fail before allocating a page')
	end
	for _, invalidNavigate in {false, 123, {}} do
		local ok, message = pcall(pageModule.mount, {}, '<p>test</p>', {Navigate = invalidNavigate})
		assert(not ok and tostring(message):find('options.Navigate', 1, true))
		assert(viewport.Attributes.Status == nil and #queue == 0, 'Invalid navigation callbacks must fail before allocating a page')
	end
	for option,values in {
		Audio={false,123,{[1]='12'},{['']='12'},{['tone.mp3']=0}},
		Videos={false,123,{[1]='21'},{['']='21'},{['clip.mp4']='bad'}},
		Tracks={false,123,{[1]='WEBVTT'},{['']='WEBVTT'},{['captions.vtt']=12}},
	} do for _,value in values do
		local ok,message=pcall(pageModule.mount,{},'<p>test</p>',{[option]=value})
		local label=if option=='Audio' then 'Audio' elseif option=='Videos' then 'Video' else 'Track'
		assert(not ok and tostring(message):lower():find(label:lower(),1,true),option..': '..tostring(message))
		assert(viewport.Attributes.Status==nil and #queue==0,'Invalid media options must fail before allocating a page')
	end end
	for option,values in {
		SVGCacheBytes={-1,1.5,256*1024*1024+1,'24mb'},
		SVGCacheEntries={-1,1.5,257,'48'},
		SVGPrewarmStates={-1,1.5,65,'16'},
		RenderWorkBudgetMS={-1,17,0/0,'4'},
	} do for _,value in values do
		local ok,message=pcall(pageModule.mount,{},'<p>test</p>',{[option]=value})
		assert(not ok and tostring(message):find('options.'..option,1,true))
		assert(viewport.Attributes.Status==nil and #queue==0,'Invalid SVG cache options must fail before allocating a page')
	end end
	for _, invalidFont in {false, 123, {}, 'Unknown', 'Inter,'} do
		local ok, message = pcall(pageModule.mount, {}, '<p>test</p>', {DefaultFont = invalidFont})
		assert(not ok and tostring(message):find('options.DefaultFont', 1, true))
		assert(viewport.Attributes.Status == nil and #queue == 0)
	end
	local audioMap={['tone.mp3']='12'}
	local videoMap={['clip.mp4']='21'}
	local trackMap={['captions.vtt']='WEBVTT\n'}
	local page = pageModule.mount(root(), "<p>test</p>", {Images = imageMap,Audio=audioMap,Videos=videoMap,Tracks=trackMap,CSS = "p {color: blue}", Stylesheets = {['styles.css']='p {color: green}'}, DefaultFont = 'Missing, Inter'})
	assert(page.ResolveImage("landschaft.png") == "rbxassetid://6319951718")
	assert(page.ResolveAudio('tone.mp3')=='rbxassetid://12' and page.ResolveVideo('clip.mp4')=='rbxassetid://21' and page.ResolveTrack('captions.vtt')=='WEBVTT\n')
	imageMap["landschaft.png"] = 123
	audioMap['tone.mp3']='99';videoMap['clip.mp4']='99';trackMap['captions.vtt']='changed'
	assert(page.ResolveImage("landschaft.png") == "rbxassetid://6319951718", "A page owns an independent image mapping snapshot")
	assert(page.ResolveAudio('tone.mp3')=='rbxassetid://12' and page.ResolveVideo('clip.mp4')=='rbxassetid://21' and page.ResolveTrack('captions.vtt')=='WEBVTT\n','A page owns independent media mapping snapshots')
	assert(#queue == 1)
	drain()
	assert(#widths == 1 and widths[1] == 390 and viewport.Attributes.Status == "ready")
	assert(viewport.ScrollingDirection == Enum.ScrollingDirection.Y and viewport.CanvasSize[1] == 0, "A fitting page must not expose a horizontal root scrollbar")
	viewport.AbsoluteSize.Y = 500
	viewport.Resized:Fire()
	assert(#queue == 0, "Height-only changes must not schedule layout")
	layoutExtraWidth = 40
	viewport.AbsoluteSize.X = 500; viewport.Resized:Fire()
	viewport.AbsoluteSize.X = 600; viewport.Resized:Fire()
	assert(#queue == 1, "Multiple requests must share one worker")
	drain()
	assert(#widths == 2 and widths[2] == 590)
	assert(viewport.ScrollingDirection == Enum.ScrollingDirection.XY and viewport.CanvasSize[1] == 630, "Real horizontal overflow enables the root X scrollbar")
	layoutExtraWidth = 0
	duringLayout = function() viewport.AbsoluteSize.X = 700; viewport.Resized:Fire() end
	viewport.AbsoluteSize.X = 650; viewport.Resized:Fire()
	drain()
	assert(widths[3] == 640 and widths[4] == 690, "Changes during layout must not be lost")
	assert(viewport.ScrollingDirection == Enum.ScrollingDirection.Y and viewport.CanvasSize[1] == 0, "Removing horizontal overflow disables the root X scrollbar again")
	duringLayout = function()
		viewport.AbsoluteSize.X = 740; viewport.Resized:Fire()
		error("simulated measurement failure")
	end
	viewport.AbsoluteSize.X = 720; viewport.Resized:Fire()
	drain()
	assert(widths[5] == 710 and widths[6] == 730 and viewport.Attributes.Status == "ready", "A failed old width cannot discard a pending resize")
	assert(viewport.Attributes.Error == nil, "Successful recovery clears the old error")
	duringLayout = function() error("temporary failure") end
	viewport.AbsoluteSize.X = 750; viewport.Resized:Fire(); drain()
	assert(viewport.Attributes.Status == "error" and viewport.Attributes.Error ~= nil)
	viewport.AbsoluteSize.X = 760; viewport.Resized:Fire(); drain()
	assert(viewport.Attributes.Status == "ready" and viewport.Attributes.Error == nil)
	local beforeImages = #widths
	imageChanged(); dimensionsChanged()
	assert(#queue == 1, "Image state changes share a single queued layout")
	drain()
	assert(#widths == beforeImages + 1 and widths[#widths] == 750, "Image fallback reflows even when the viewport width is unchanged")
	duringLayout = function() imageChanged() end
	imageChanged(); drain()
	assert(#widths == beforeImages + 3, "Image changes during a yielding layout must not be lost")
	local beforeDirty=#widths
	outputChanged(true,outputA); outputChanged(true,outputB)
	assert(#queue == 1,"Dirty output requests share the existing worker")
	drain()
	assert(#widths == beforeDirty+1 and layoutKinds[#layoutKinds] == "partial")
	assert(dirtySnapshots[#dirtySnapshots][outputRunA] and dirtySnapshots[#dirtySnapshots][outputRunB],"Coalescing preserves both dirty regions")
	duringLayout=function() outputChanged(true,outputB) end
	outputChanged(true,outputA); drain()
	assert(#widths == beforeDirty+3 and layoutKinds[#layoutKinds] == "full","Dirty changes during a yielding layout recover in full from the latest state")
	viewport.AbsoluteSize.X=765; viewport.Resized:Fire(); outputChanged(true,outputA); drain()
	assert(layoutKinds[#layoutKinds] == "full","Pending resize takes precedence over partial requests")
	duringLayout=function() error("dirty measurement failed") end
	outputChanged(true,outputA); drain(); assert(viewport.Attributes.Status == "error")
	outputChanged(true,outputB); drain()
	assert(layoutKinds[#layoutKinds] == "full" and viewport.Attributes.Status == "ready","Failed partial layout recovers through full layout")
	local sizeBefore,checksBefore=#widths,sizeChecks
	local lastStats,lastCanvas=page.LastLayoutStats,viewport.CanvasSize
	sameSize[outputA],sameSize[outputB]=true,true
	outputChanged(true,outputA); outputChanged(true,outputB); drain()
	assert(#widths == sizeBefore and sizeChecks == checksBefore+2,"Equal-size output changes must not call block layout")
	assert(page.LastLayoutStats == lastStats and viewport.CanvasSize == lastCanvas and viewport.Attributes.Status == "ready","Paint-only updates do not publish another layout or touch scroll extents")
	sameSize[outputB]=false
	outputChanged(true,outputA); outputChanged(true,outputB); drain()
	assert(#widths == sizeBefore+1 and not dirtySnapshots[#dirtySnapshots][outputRunA] and dirtySnapshots[#dirtySnapshots][outputRunB],"Only resized items enter dirty layout")
	duringSizeCheck=function() outputChanged(true,outputB) end
	outputChanged(true,outputA); drain()
	assert(#widths == sizeBefore+2 and layoutKinds[#layoutKinds] == "full","A queued size-changing update survives a same-size measurement")
	duringSizeCheck=function() viewport.AbsoluteSize.X=770; viewport.Resized:Fire() end
	outputChanged(true,outputA); drain()
	assert(#widths == sizeBefore+3 and layoutKinds[#layoutKinds] == "full","Resize during size measurement supersedes the paint-only path")
	duringSizeCheck=function() error("size probe failed") end
	outputChanged(true,outputA); drain()
	assert(#widths == sizeBefore+4,"Failed preflight uses the normal layout path")
	sameSize[outputA],sameSize[outputB]=nil,nil
	local scriptBefore=#widths
	scriptChanged(outputA);scriptChanged(outputB)
	assert(#queue==1,"Script batches share one layout worker")
	drain()
	assert(#widths==scriptBefore+1 and layoutKinds[#layoutKinds]=="partial","HTML script flush forwards dirty targets")
	assert(dirtySnapshots[#dirtySnapshots][outputRunA] and dirtySnapshots[#dirtySnapshots][outputRunB],"Both script regions survive batching")
	local scriptStats=page.LastLayoutStats
	scriptChanged(nil);drain()
	assert(#widths==scriptBefore+1 and page.LastLayoutStats==scriptStats,"Script paint does not publish layout")
	duringLayout=function()scriptChanged(outputB)end
	scriptChanged(outputA);drain()
	assert(#widths==scriptBefore+3 and layoutKinds[#layoutKinds]=="full","Script changes during a suspended pass recover safely")
	local textBefore=#widths
	textFits=true;scriptChanged(textBox);drain()
	assert(textChecks==1 and #widths==textBefore,"A same-size text replacement never calls block layout")
	textFits=false;scriptChanged(textBox);drain()
	assert(#widths==textBefore+1 and layoutKinds[#layoutKinds]=="partial" and dirtySnapshots[#dirtySnapshots][textBox],"Larger text retains its partial layout target")
	textFits=true;duringTextCheck=function()viewport.AbsoluteSize.X=780;viewport.Resized:Fire()end
	scriptChanged(textBox);drain()
	assert(#widths==textBefore+2 and layoutKinds[#layoutKinds]=="full","Resize during local text measurement still recovers through full layout")
	local beforeScroll = #widths
	scrollGui.CanvasPosition = Vector2.new(10, 0); scrollChanged:Fire()
	scrollGui.CanvasPosition = Vector2.new(20, 0); scrollChanged:Fire()
	assert(#queue == 1, "Horizontal scroll changes coalesce")
	drain(); assert(#widths == beforeScroll and repaints == 1 and viewport.Attributes.Status == "ready", "Scroll repaint never calls block layout or changes page status")
	duringRepaint = function() scrollGui.CanvasPosition = Vector2.new(22, 0); scrollChanged:Fire() end
	scrollGui.CanvasPosition = Vector2.new(21, 0); scrollChanged:Fire(); drain()
	assert(repaints == 3 and #widths == beforeScroll, "Scroll during repaint is not lost")
	scrollGui.CanvasPosition = Vector2.new(20, 0); scrollChanged:Fire(); drain()
	scrollGui.CanvasPosition = Vector2.new(20, 5); scrollChanged:Fire()
	assert(#queue == 0, "Vertical scrolling does not reproject right-edge ellipsis")
	local paintOnlyLayouts,paintOnlyRepaints=#widths,repaints
	sameSize[outputA]=true
	outputChanged(true,outputA)
	scrollGui.CanvasPosition=Vector2.new(25,5); scrollChanged:Fire(); drain()
	assert(#widths == paintOnlyLayouts and repaints == paintOnlyRepaints+1,"Skipping same-size layout must preserve queued scroll paint")
	sameSize[outputA]=nil
	local oldWidthCount = #widths
	viewport.ScrollBarThickness = 16
	viewport:GetPropertyChangedSignal("ScrollBarThickness"):Fire(); drain()
	assert(#widths == oldWidthCount + 1 and widths[#widths] == viewport.AbsoluteSize.X - 16, "Changing scrollbar width recomputes the usable content width")
	viewport.ScrollBarThickness = 10
	viewport:GetPropertyChangedSignal("ScrollBarThickness"):Fire(); drain()
	local beforeDestroy = #widths
	viewport.AbsoluteSize.X = 800; viewport.Resized:Fire()
	page:Destroy()
	scrollGui.CanvasPosition = Vector2.new(30, 5); scrollChanged:Fire()
	imageChanged()
	drain()
	assert(#widths == beforeDestroy and not page.Alive, "Queued work must stop after destruction")
	page:Destroy()
	assert(patternsDisposed == 1, "Page disposal releases its pattern images exactly once")
	assert(insetsDisposed == 1, "Page disposal releases its inset images exactly once")
	assert(radioDisposed == 1, "Page disposal releases its radio image exactly once")
	assert(imagesStopped == 1, "Page disposal disconnects image loading listeners exactly once")
	assert(dimensionsStopped == 1, "Page disposal cancels image metadata work")
	local diagnosticRoot = root()
	local diagnosticPage = loadHTMLPage({
		["Input/Controller"] = {start = function() end},
		["Rendering/GuiFactory"] = factory(diagnosticRoot),
		["Rendering/RenderTree"] = { build = function(_, _, diagnostic, _, _, _, _, _, defaultFont)
			assert(defaultFont == 'PT Serif', 'DefaultFont does not leak from another page')
			for _ = 1, 101 do diagnostic("unsupported") end
			return {}
		end },
		["Layout/BlockLayout"] = { arrange = function() return 10, 10 end },
	}, runtime, clock).mount(root(), "")
	assert(#diagnosticPage.Document.Diagnostics == 100 and diagnosticPage.Document.DiagnosticsTruncated)
	assert(diagnosticPage.ResolveImage("landschaft.png") == nil, "Mappings do not leak to another page")
	diagnosticRoot.AbsoluteSize.X = 0; diagnosticRoot.Resized:Fire(); drain()
	assert(diagnosticRoot.Attributes.Status == "waiting-size")
	diagnosticRoot.AbsoluteSize.X = 100; diagnosticRoot.Resized:Fire(); drain()
	assert(diagnosticRoot.Attributes.Status == "ready")
	diagnosticPage:Destroy()
	local positionedRoot, heights = root(), {}
	local positionedPage = loadHTMLPage({
		["Input/Controller"] = {start = function() end},
		["Rendering/GuiFactory"] = factory(positionedRoot),
		["Rendering/RenderTree"] = {build = function() return {Positioning = true} end},
		["Layout/BlockLayout"] = {arrange = function(tree)
			table.insert(heights, tree.ViewportHeight)
			return 20, 100
		end},
	}, runtime, clock).mount(root(), "")
	drain(); assert(heights[1] == 300)
	positionedRoot.AbsoluteSize.Y = 400; positionedRoot.Resized:Fire()
	positionedRoot.AbsoluteSize.Y = 500; positionedRoot.Resized:Fire()
	assert(#queue == 1); drain(); assert(#heights == 2 and heights[2] == 500)
	positionedRoot.Resized:Fire(); assert(#queue == 0)
	positionedRoot.AbsoluteSize.Y = 600; positionedRoot.Resized:Fire()
	positionedPage:Destroy(); drain(); assert(#heights == 2)
	local fragmentRoot=root()
	fragmentRoot.CanvasPosition=Vector2.new(0,0)
	fragmentRoot.CanvasSize=UDim2.fromOffset(0,1000)
	fragmentRoot.AbsolutePosition=Vector2.new(0,0)
	local fragmentScroll={CanvasPosition=Vector2.new(0,0),CanvasSize=UDim2.fromOffset(800,0)}
	local fragmentGoal,fragmentPlayed
	local fragmentPage=loadHTMLPage({
		["Input/Controller"]={start=function() end},
		["Rendering/GuiFactory"]=factory(fragmentRoot),
		["Rendering/RenderTree"]={build=function(document)
			local function find(node,id)
				if node.Attributes and node.Attributes.id==id then return node end
				for _,child in node.Children or {} do
					local found=find(child,id)
					if found then return found end
				end
				return nil
			end
			local track=find(document,"track")
			local slide=find(document,"lab-slide-4")
			local function htmlNode(node)
				if node.Name=="html" then return node end
				for _,child in node.Children or {} do local found=htmlNode(child);if found then return found end end
				return nil
			end
			local slideBox={Gui={AbsolutePosition=Vector2.new(420,60)}}
			local trackBox={ScrollGui=fragmentScroll,ScrollMarkerChildren={slideBox},
				ScrollMarkerTargets={Vector2.new(400,0)},ScrollMarkerViewWidth=200,ScrollMarkerViewHeight=100,
				Style={ScrollBehavior="smooth"},TweenService={Create=function(_,_,_,goal)
					fragmentGoal=goal.CanvasPosition
					return {Play=function() fragmentPlayed=true end,Cancel=function() end}
				end}}
			return {NodeBoxes={[track]=trackBox,[slide]=slideBox},
				NodeStyles={[htmlNode(document)]={ScrollPadding={20,0,0,0},ScrollBehavior="auto"},
					[slide]={ScrollMargin={0,0,0,0}}},Children={}}
		end},
		["Layout/BlockLayout"]={arrange=function() return 1000,100 end},
	},runtime,clock).mount(root(),'<div id="track"><article id="lab-slide-4">Ende</article></div>')
	drain()
	assert(fragmentRoot.Attributes.Status=="ready")
	fragmentPage:ScrollToFragment("lab-slide-4")
	assert(fragmentPlayed and fragmentGoal.X==400 and fragmentGoal.Y==0
		and fragmentRoot.CanvasPosition.X==0 and fragmentRoot.CanvasPosition.Y==40
		and fragmentRoot.Attributes.Fragment=="lab-slide-4",
		"A snap fragment must scroll its local track and align the page target after root scroll-padding")
	fragmentPage:Destroy()
	-- Explicit virtual time: the actual gesture owns the wait, with no idle delay.
	local time, jobs, layouts, paints = 0, {}, {}, 0
	local mediaEnvironments = {}
	local failMediaNext = false
	local timers, cancelledTimers = 0, 0
	local limitedRoot, limitedTarget, horizontal = root(), root(), signal()
	local scrolling = {CanvasPosition = Vector2.new(0, 0), GetPropertyChangedSignal = function() return horizontal end}
	local forceLayout
	local function enqueue(seconds, callback)
		local job = {Due = time + seconds, Callback = callback}
		table.insert(jobs, job)
		return job
	end
	local function advance(target)
		assert(target >= time, "Virtual time only moves forward")
		time = target
		local executions = 0
		while true do
			local ready
			for index, job in jobs do if job.Due <= time then ready = index; break end end
			if not ready then break end
			local job = table.remove(jobs, ready)
			if not job.Cancelled then job.Callback() end
			executions += 1; assert(executions < 100, "Timer scheduling must make progress")
		end
	end
	local dragLayout
	local dragItem={Control={Type="textarea"}}
	local releaseDriven = loadHTMLPage({
		["Input/Controller"] = {start = function(_,_,request) dragLayout=request end},
		["Rendering/GuiFactory"] = factory(limitedRoot),
		["Rendering/RenderTree"] = {build = function() return {Positioning = true, Children = {
			{ScrollGui = scrolling, Style = {TextOverflow = "ellipsis"}, Children = {{Kind = "Words"}}},
		}, SetMediaEnvironment = function(_,width,height)
			if failMediaNext then failMediaNext = false; error("temporary CSS failure") end
			table.insert(mediaEnvironments,{Width=width,Height=height})
			return false
		end} end},
		["Rendering/ImageDimensions"] = {start = function(_, _, _, changed) forceLayout = changed end},
		["Layout/WordLayout"] = {repaint = function() paints += 1 end},
		["Layout/BlockLayout"] = {arrange = function(tree, width)
			table.insert(layouts, {Time = time, Width = width, Height = tree.ViewportHeight})
			return 20, width
		end},
	}, {
		defer = function(callback) return enqueue(0, callback) end,
		delay = function(seconds, callback) timers += 1; return enqueue(seconds, callback) end,
		cancel = function(job) job.Cancelled = true; cancelledTimers += 1 end,
	}, function() return time end).mount(limitedTarget, "")
	advance(0); assert(#layouts == 1 and #mediaEnvironments == 1, "First load is immediate")
	limitedTarget:SetAttribute("HTMLViewportResizing", true)
	for step = 1, 30 do
		time = step * 0.02
		limitedRoot.AbsoluteSize.X = 400 + step * 10
		limitedRoot.AbsoluteSize.Y = 300 + step
		limitedRoot.Resized:Fire()
		if step == 10 then forceLayout() end
		if step == 12 then dragLayout(true,dragItem) end
		if step == 5 or step == 25 then scrolling.CanvasPosition = Vector2.new(step,0); horizontal:Fire() end
		advance(time)
		assert(#layouts == 1 and #mediaEnvironments == 1, "Neither layout nor CSS recalculation runs during a continuous drag, including forced requests")
	end
	assert(timers == 0 and paints == 2, "A held grip never polls or installs a delay; scroll repaint continues")
	advance(1.7); limitedRoot.Resized:Fire(); forceLayout(); advance(time)
	assert(#layouts == 1 and #mediaEnvironments == 1 and timers == 0, "Even a long stationary hold and forced updates wait for the real release")
	limitedTarget:SetAttribute("HTMLViewportResizing", false); advance(time)
	assert(#layouts == 2 and layouts[2].Time == 1.7 and layouts[2].Width == 690 and layouts[2].Height == 330, "Release immediately lays out exactly the final width/height pair")
	assert(#mediaEnvironments == 2 and mediaEnvironments[2].Width == 700 and mediaEnvironments[2].Height == 330, "CSS viewport units and media queries use the full viewport; flow width excludes the scrollbar")
	limitedTarget:SetAttribute("HTMLViewportResizing", true); advance(1.8)
	limitedTarget:SetAttribute("HTMLViewportResizing", false); advance(time)
	assert(#layouts == 2, "Grabbing a grip without moving it does not rebuild a completed layout")
	forceLayout(); advance(time)
	assert(#layouts == 3, "Image completion outside a viewport drag is immediate")
	limitedTarget:SetAttribute("HTMLViewportResizing", true)
	advance(1.82); limitedRoot.AbsoluteSize.Y = 500; limitedRoot.Resized:Fire(); advance(time)
	advance(1.9); limitedRoot.AbsoluteSize.Y = 600; limitedRoot.Resized:Fire(); advance(time)
	assert(#layouts == 3, "Height-only dragging of positioned pages waits for release too")
	limitedTarget:SetAttribute("HTMLViewportResizing", false); advance(time)
	assert(#layouts == 4 and layouts[4].Height == 600 and layouts[4].Time == 1.9)
	-- No artificial pause for a fullscreen/programmatic size change, even inside 1/60s.
	advance(1.901); limitedRoot.AbsoluteSize = Vector2.new(1920,1080); limitedRoot.Resized:Fire(); advance(time)
	assert(#layouts == 5 and layouts[5].Time == 1.901 and layouts[5].Width == 1910 and layouts[5].Height == 1080, "A size jump without an active gesture schedules layout immediately")
	advance(1.902); limitedRoot.AbsoluteSize.Y = 600; limitedRoot.Resized:Fire(); advance(time)
	assert(#layouts == 6 and layouts[6].Height == 600, "Abrupt height-only viewport changes are also immediate")
	advance(1.91); dragLayout(false,dragItem); advance(time)
	advance(1.915); dragLayout(false,dragItem); advance(time)
	assert(#layouts == 6, "Textarea requests still share their existing frame throttle")
	advance(1.92); assert(#layouts == 7, "Local textarea resizing keeps only its normal frame throttle")
	advance(2.0); failMediaNext = true; forceLayout(); advance(time)
	assert(limitedRoot.Attributes.Status == "error" and #layouts == 7, "Deferred CSS failures cannot publish stale layout")
	forceLayout(); advance(time)
	assert(limitedRoot.Attributes.Status == "ready" and #layouts == 8, "A later update can recover after deferred CSS failure")
	advance(2.01); dragLayout(false,dragItem); advance(time)
	local beforeCancel = cancelledTimers
	releaseDriven:Destroy(); advance(3)
	limitedTarget:SetAttribute("HTMLViewportResizing", true)
	limitedTarget:SetAttribute("HTMLViewportResizing", false); advance(time)
	assert(#layouts == 8 and cancelledTimers == beforeCancel + 1, "Disposal cancels the local-control timer and disconnects gesture callbacks")
	-- A new page can mount while the same host's grip is already held.
	local heldTarget = root(function(callback) enqueue(0,callback) end)
	heldTarget:SetAttribute("HTMLViewportResizing", true)
	local heldRoot, firstLayouts = root(), 0
	local heldPage = loadHTMLPage({
		["Input/Controller"] = {start = function() end},
		["Rendering/GuiFactory"] = factory(heldRoot),
		["Rendering/RenderTree"] = {build = function() return {Children={}} end},
		["Layout/BlockLayout"] = {arrange = function(_,width) firstLayouts+=1;return 10,width end},
	}, {
		defer = function(callback) return enqueue(0,callback) end,
		delay = function() error("A held host must not create a polling timer") end,
	}, function() return time end).mount(heldTarget, "")
	advance(10)
	assert(firstLayouts == 0 and heldRoot.Attributes.Status == "loading", "A newly mounted page respects an already active grip")
	-- Queue a worker before the deferred release callback, matching Roblox's
	-- deferred signals. It must return to the scheduler, never spin on cancellation.
	heldRoot.AbsoluteSize.X = 450; heldRoot.Resized:Fire()
	heldTarget:SetAttribute("HTMLViewportResizing", false); advance(time)
	assert(firstLayouts == 1 and heldRoot.Attributes.Status == "ready", "The first layout starts at release without another size event")
	heldPage:Destroy()
	-- Real budget waits inside the page worker: simulate mouse/input callbacks
	-- while a pass is suspended, then verify only the newest result is published.
	local cooperativeRoot, cooperativeTree = root(), {Positioning=true,Children={}}
	local cooperativeTarget = root()
	local cooperativeTime, cooperativeQueue = 0, {}
	local cooperativePasses, cooperativeWaits, readyPublications = 0,0,0
	local cooperativeForce, cooperativePage
	local disposeOnWait, holdOnWait = false, false
	local baseAttribute = cooperativeRoot.SetAttribute
	function cooperativeRoot:SetAttribute(key,value)
		if key=="Status" and value=="ready" then
			readyPublications+=1
			assert(not cooperativeTree.LayoutInProgress and self.CanvasSize[2]==500,"Only completed final geometry is published")
		end
		baseAttribute(self,key,value)
	end
	local function cooperativeEnqueue(seconds,callback)
		local token={Due=cooperativeTime+seconds,Callback=callback}
		table.insert(cooperativeQueue,token);return token
	end
	cooperativePage=loadHTMLPage({
		["Input/Controller"]={start=function() end},
		["Rendering/GuiFactory"]=factory(cooperativeRoot),
		["Rendering/RenderTree"]={build=function() return cooperativeTree end},
		["Rendering/ImageDimensions"]={start=function(_,_,_,changed) cooperativeForce=changed end},
		["Layout/BlockLayout"]={arrange=function(tree,width,_,_,check)
			cooperativePasses+=1
			for _=1,30 do cooperativeTime+=.002;check() end
			return tree.ViewportHeight,width
		end},
	}, {
		defer=function(callback) return cooperativeEnqueue(0,callback) end,
		delay=cooperativeEnqueue,
		cancel=function(token) token.Cancelled=true end,
		wait=function()
			cooperativeWaits+=1;cooperativeTime+=.016
			assert(cooperativeTree.LayoutInProgress,"The mouse callback runs between protected layout chunks")
			if disposeOnWait then disposeOnWait=false;cooperativePage:Destroy()
			elseif holdOnWait then holdOnWait=false;cooperativeTarget:SetAttribute("HTMLViewportResizing", true)
			elseif cooperativeWaits==1 then
				assert(cooperativeRoot.CanvasSize[1]==0 and cooperativeRoot.CanvasSize[2]==0 and readyPublications==0)
				cooperativeTarget:SetAttribute("HTMLViewportResizing", true)
				cooperativeRoot.AbsoluteSize.X,cooperativeRoot.AbsoluteSize.Y=700,500
				cooperativeRoot.Resized:Fire();cooperativeForce()
			end
		end,
	},function() return cooperativeTime end).mount(cooperativeTarget,"")
	local function cooperativeDrain()
		while #cooperativeQueue>0 do
			local job=table.remove(cooperativeQueue,1)
			if not job.Cancelled then cooperativeTime=math.max(cooperativeTime,job.Due);job.Callback() end
		end
	end
	cooperativeDrain()
	assert(cooperativePasses==1 and cooperativeWaits==1 and readyPublications==0 and cooperativeRoot.Visible==false
		and cooperativeTree.LayoutNeedsRecovery and not cooperativeTree.DirtyContext.Ready,
		"An actual resize gesture cancels the suspended layout without publishing intermediate geometry")
	cooperativeTime+=2;cooperativeDrain()
	assert(cooperativePasses==1,"A cancelled layout never restarts while the grip is held")
	cooperativeTarget:SetAttribute("HTMLViewportResizing", false);cooperativeDrain()
	assert(cooperativePasses==2 and cooperativeWaits>1 and readyPublications==1 and cooperativeRoot.Visible==true
		and not cooperativeTree.LayoutNeedsRecovery
		and cooperativeRoot.CanvasSize[1]==0 and cooperativeTree.DirtyContext.Ready
		and cooperativePage.LastLayoutWork.Yields>0,"Resize/image events during a pause produce one final full layout")
	local completedCanvas=cooperativeRoot.CanvasSize
	holdOnWait=true;cooperativeForce();cooperativeDrain()
	assert(cooperativePasses==3 and readyPublications==1 and cooperativeTree.LayoutNeedsRecovery
		and cooperativeRoot.CanvasSize==completedCanvas, "Grabbing during a suspended pass cancels it before any size movement")
	cooperativeTarget:SetAttribute("HTMLViewportResizing", false);cooperativeDrain()
	assert(cooperativePasses==4 and readyPublications==2 and not cooperativeTree.LayoutNeedsRecovery
		and cooperativeTree.DirtyContext.Ready, "Release recovers a pass cancelled only by gesture begin")
	completedCanvas=cooperativeRoot.CanvasSize
	disposeOnWait=true;cooperativeForce();cooperativeDrain()
	assert(not cooperativePage.Alive and not cooperativeTree.LayoutInProgress and not cooperativeTree.DirtyContext.Ready
		and readyPublications==2 and cooperativeRoot.CanvasSize==completedCanvas,"Disposal during a work slice stops all later publication")
	print("Lifecycle: disposal, serialized scroll paint, exact resize release, immediate size jumps, final CSS/size, cooperative cancellation and local control throttle passed")
end
