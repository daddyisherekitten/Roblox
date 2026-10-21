--!strict
return function(Parser, loadRenderTree, loadWordLayout, loadBlockLayout, ViewportLayer)
	local layers = 0
	local function create(class, parent, props)
		local gui = table.clone(props); gui.Parent = parent; gui.ClassName = class
		gui.Destroy = function(self) self.Parent = nil end
		if props.Name == "HTMLViewportPositionLayer" then layers += 1 end
		return gui
	end
	local factory = {create = create, modifier = create}
	local renderer = loadRenderTree(factory)
	local overrides = {['Layout/FontProfiles'] = {face = function(font) return font end}, ['Layout/TextMeasure'] = {measure = function(text, _, size) return Vector2.new(#text * 5, size) end}}
	overrides['Layout/WordLayout'] = loadWordLayout(overrides)
	local layout = loadBlockLayout(overrides)
	local css = '#nav:hover{color:red}#port{width:200px;height:100px;overflow:auto}#content{height:400px}#space{height:30px}#target{height:20px;width:40px;opacity:.8} @media(min-width:600px){#target{position:fixed;left:7px;top:5px}} @media(min-width:350px) and (max-width:599px){#target{position:sticky;top:5px}}'
	local root = {Parent = {}, AbsoluteSize = Vector2.new(300, 400), AbsoluteWindowSize = Vector2.new(300, 400), CanvasPosition = Vector2.new(0, 0)}
	local tree = renderer.build(Parser.parse('<style>' .. css .. '</style><div id="port"><div id="content"><div id="space"></div><div id="target"></div></div></div><a id="nav" href="#port">Navigation</a>'), root, error)
	local boxes = {}; for node, box in tree.NodeBoxes do if node.Attributes and node.Attributes.id then boxes[node.Attributes.id] = box end end
	local target, port = boxes.target, boxes.port
	local surface, home, tick = target.OpacityGroup.Gui, target.OpacityGroup.Gui.Parent, nil
	local cleanups = {}
	local refresh = ViewportLayer.start({Alive = true, AddCleanup = function(_, fn) table.insert(cleanups, fn) end}, tree, root,
		{RunService = {PreRender = {Connect = function(_, fn) tick = fn; return {Disconnect = function() tick = nil end} end}}})
	assert(refresh and tick == nil, "Initially static page must not install a sticky frame listener")
	for _, width in {300, 800, 450, 800, 300, 450, 900, 300, 450, 800} do
		root.AbsoluteSize = Vector2.new(width, 400); root.AbsoluteWindowSize = root.AbsoluteSize
		tree:SetMediaEnvironment(width, 400); tree.ViewportHeight = 400
		layout.arrange(tree, width, 0, 0, function() return true end)
		port.ScrollGui.AbsoluteWindowSize = Vector2.new(190, 100)
		port.ScrollGui.CanvasPosition = Vector2.new(0, 60)
		ViewportLayer.attach(tree, root, factory); ViewportLayer.update(tree, root)
		assert(surface == target.OpacityGroup.Gui, "Resize reuses the compositing surface")
		if width >= 600 then
			assert(surface.Parent == tree.ViewportLayer and tick == nil, "Fixed opacity group moves into viewport and suspends sticky sampling")
			assert(math.abs(surface.Position[1] - 7) < .001 and math.abs(surface.Position[2] - 5) < .001, "Fixed coordinates are viewport-relative")
			root.CanvasPosition = Vector2.new(0, 70); ViewportLayer.update(tree, root)
			assert(math.abs(surface.Position[2] - 5) < .001, "Document scrolling preserves fixed coordinates")
		elseif width >= 350 then
			assert(surface.Parent == home and tick, "New sticky box returns to its scrollport and starts sampling")
			assert(target.StickyScrollBox == port, "Sticky follows the nearest scrolling ancestor")
			port.ScrollGui.CanvasPosition = Vector2.new(0, 80); tick()
			assert(math.abs(target.ViewportOffsetY - (85 - target.StickyNormalY)) < .001, "Sticky pins 5px below the nested scrollport")
		else
			assert(surface.Parent == home and tick == nil and target.ViewportKind == nil, "Static restores flow and removes stale positioning/listeners")
			local y = surface.Position[2]; ViewportLayer.update(tree, root)
			assert(surface.Position[2] == y, "Scrolling cannot apply old fixed/sticky coordinates to a static box")
		end
	end
	assert(layers == 1, "Repeated mode changes must reuse one viewport overlay")
	local nav; for node in tree.NodeStyles do if node.Attributes and node.Attributes.id == "nav" then nav = node end end
	for _, width in {800, 450} do
		root.AbsoluteSize = Vector2.new(width, 400); root.AbsoluteWindowSize = root.AbsoluteSize
		tree:SetMediaEnvironment(width, 400); layout.arrange(tree, width, 0, 0, function() return true end)
		ViewportLayer.attach(tree, root, factory); ViewportLayer.update(tree, root)
		local beforeX, beforeY, beforeTick = surface.Position[1], surface.Position[2], tick
		local attachments, originalAttach = 0, ViewportLayer.attach
		ViewportLayer.attach = function(...) attachments += 1; return originalAttach(...) end
		for _ = 1, 5 do
			local changed, needed = tree:SetCSSState("hover", nav)
			assert(changed and not needed, "Unrelated navigation hover remains paint-only with fixed/sticky content")
			tree:SetCSSState("hover", nil)
		end
		ViewportLayer.attach = originalAttach
		assert(attachments == 0 and tick == beforeTick and surface.Position[1] == beforeX and surface.Position[2] == beforeY,
			"Unrelated hover neither reattaches viewport GUIs nor moves pinned content")
	end
	for _, cleanup in cleanups do cleanup() end
	assert(tick == nil and tree.SyncViewportListeners == nil)
	ViewportLayer.destroy(tree); assert(tree.ViewportLayer == nil)
	for _, containingStyle in {"transform:translate(0)", "translate:0", "rotate:0deg", "scale:1", "perspective:400px", "filter:brightness(1)", "contain:layout", "contain:paint"} do
		local localRoot = {Parent = {}, AbsoluteSize = Vector2.new(400, 400), AbsoluteWindowSize = Vector2.new(400, 400), CanvasPosition = Vector2.new(0, 0)}
		local document = '<div id="host" style="' .. containingStyle .. ';width:200px;height:100px;padding:10px;border:2px solid blue;margin:20px"><div id="fixed" style="position:fixed;left:7px;top:5px;width:40px;height:20px"></div><div id="absolute" style="position:absolute;right:7px;bottom:5px;width:40px;height:20px"></div></div>'
		local localTree = renderer.build(Parser.parse(document), localRoot, error)
		layout.arrange(localTree, 400, 0, 0, function() return true end)
		local ids = {}; for node, box in localTree.NodeBoxes do if node.Attributes and node.Attributes.id then ids[node.Attributes.id] = box end end
		assert(ids.fixed.FixedContainingBox == ids.host, "Fixed containing block: " .. containingStyle)
		assert(math.abs(ids.fixed.Gui.Position[1] - 9) < .001 and math.abs(ids.fixed.Gui.Position[2] - 7) < .001, "Fixed insets start at the ancestor padding edge")
		assert(math.abs(ids.absolute.Gui.Position[1] - 175) < .001 and math.abs(ids.absolute.Gui.Position[2] - 97) < .001, "Absolute child uses transformed/contained ancestor padding box")
		local homeParent = ids.fixed.Gui.Parent
		assert(ViewportLayer.attach(localTree, localRoot, factory) == nil and ids.fixed.Gui.Parent == homeParent, "Locally fixed descendants must remain inside their containing block")
	end
	local hoverTree = renderer.build(Parser.parse('<style>#host{width:200px;height:100px;padding:10px;border:2px solid blue;margin:20px}#host:hover{transform:translate(0)}#fixed{position:fixed;left:7px;top:5px;width:40px;height:20px}</style><div id="host"><div id="fixed"></div></div>'), root, error)
	layout.arrange(hoverTree, 400, 0, 0, function() return true end)
	local host, child; for node, box in hoverTree.NodeBoxes do if node.Attributes and node.Attributes.id == "host" then host = box elseif node.Attributes and node.Attributes.id == "fixed" then child = box end end
	local originalParent = child.Gui.Parent
	ViewportLayer.attach(hoverTree, root, factory)
	assert(child.Gui.Parent == hoverTree.ViewportLayer)
	for _ = 1, 3 do
		local changed, needed = hoverTree:SetCSSState("hover", host.Node)
		assert(changed and needed, "Introducing a containing block must reposition its descendants")
		layout.arrange(hoverTree, 400, 0, 0, function() return true end); ViewportLayer.attach(hoverTree, root, factory)
		assert(child.FixedContainingBox == host and child.Gui.Parent == originalParent)
		hoverTree:SetCSSState("hover", nil)
		layout.arrange(hoverTree, 400, 0, 0, function() return true end); ViewportLayer.attach(hoverTree, root, factory)
		assert(child.FixedContainingBox == nil and child.Gui.Parent == hoverTree.ViewportLayer)
	end
	ViewportLayer.destroy(hoverTree)
	print("Positioning combinations: ten live resizes, static/fixed/sticky, nested scrolling, opacity surface, idle listeners, overlay reuse and cleanup")
	print("Containing-block combinations: eight transform/perspective/filter/contain variants, absolute/fixed descendants and three live hover round trips")
end
