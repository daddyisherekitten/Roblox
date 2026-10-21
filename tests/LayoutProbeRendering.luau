--!strict
return function(Parser, DOM, Dirty, Job, Probe, loadRenderTree, loadWordLayout, loadBlockLayout, html, css)
	local created = {}
	local inspectFrame
	local function create(class, parent, properties)
		local gui = table.clone(properties)
		gui.ClassName, gui.Parent = class, parent
		function gui:Destroy() self.Parent = nil end
		table.insert(created, gui)
		return gui
	end
	local overrides = {
		["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size)
			-- GetTextBoundsAsync can yield independently of the explicit budget.
			if inspectFrame then inspectFrame() end
			return Vector2.new((utf8.len(text) or 0) * size * .45, size)
		end},
	}
	overrides["Layout/WordLayout"] = loadWordLayout(overrides)
	local renderer = loadRenderTree({create = create, modifier = create})
	local layout = loadBlockLayout(overrides)
	local function build(source, width, sheet)
		local tree = renderer.build(Parser.parse(source), {AbsoluteSize = Vector2.new(width, 900)}, error,
			nil, nil, nil, function() return "rbxassetid://1" end, nil, nil, nil, nil, nil,
			if sheet then {["styles.css"] = sheet} else nil, "http://localhost:8000/bytebude/index.html")
		tree.ViewportHeight = 900
		tree:SetMediaEnvironment(width, 900)
		Dirty.begin(tree)
		layout.arrange(tree, width, 0, 0, function() return true end)
		Dirty.finish(tree, true)
		return tree
	end
	local function snapshot(tree)
		local values = {}
		local function visit(box)
			table.insert(values, table.concat({box.Kind or "", box.LayoutX or 0, box.LayoutY or 0,
				box.OuterWidth or 0, box.OuterHeight or 0, box.FirstBaseline or 0}, ","))
			for _, item in box.Items or {} do
				table.insert(values, table.concat({item.Text or "", item.X or 0, item.Y or 0,
					item.Width or 0, item.Height or 0, item.LineBaseline or 0}, ","))
			end
			for _, child in box.Children or {} do visit(child) end
		end
		visit(tree)
		return table.concat(values, "\n")
	end
	local function position(gui)
		local x, y = 0, 0
		while gui do
			if gui.Position then x += gui.Position[1]; y += gui.Position[2] end
			gui = gui.Parent
		end
		return tostring(x) .. "," .. tostring(y)
	end
	local function key(gui, localOnly, movingRoot)
		local parts = {if localOnly then "local" else position(gui)}
		for _, field in {"Position", "Size", "Visible", "ZIndex", "Text", "BackgroundTransparency", "ImageTransparency", "TextTransparency", "Transparency"} do
			if movingRoot and field == "Position" then continue end
			local value = gui[field]
			if type(value) == "table" then value = tostring(value[1]) .. "," .. tostring(value[2]) end
			table.insert(parts, tostring(value))
		end
		return table.concat(parts, "|")
	end
	local function inside(gui, owner)
		while gui and gui ~= owner do gui = gui.Parent end
		return gui == owner
	end
	local frames, nativeWaits = 0, 0
	local function mutate(tree, id, text)
		local node = DOM.findById(tree.Node, id)
		node.Children[1].Text = text
		local box = tree.NodeBoxes[node]
		box:RefreshText(true)
		return box
	end
	for _, width in {1120, 800, 360} do
		local first = #created + 1
		local tree = build(html, width, css)
		local left, right
		for node, box in tree.NodeBoxes do
			if node.Attributes and node.Attributes.class == "left-column" then left = box end
			if node.Attributes and node.Attributes.class == "right-column" then right = box end
		end
		local main = tree.NodeBoxes[DOM.findById(tree.Node, "inhalt")]
		local saved = {}
		for index = first, #created do
			local gui = created[index]
			if inside(gui, left.Gui) or inside(gui, main.Gui) then
				-- On mobile the left sidebar follows the poll and legitimately moves
				-- down. Its descendants still retain their local paint and dimensions.
				local localOnly = width <= 580 and inside(gui, left.Gui)
				local movingRoot = localOnly and gui == left.Gui
				saved[gui] = {Key = key(gui, localOnly, movingRoot), Local = localOnly, MovingRoot = movingRoot}
			end
		end
		local rightPosition = position(right.Gui)
		local rightNative = right.Gui.Position
		local now, yields = 0, 0
		local function check()
			for gui, original in saved do
				local live = key(gui, original.Local, original.MovingRoot)
				assert(live == original.Key, "Unrelated Bytebude surface stays unchanged during every yield at " .. width .. ": " .. tostring(gui.Name) .. " BEFORE " .. original.Key .. " DURING " .. live)
			end
			assert(position(right.Gui) == rightPosition and right.Gui.Position[1] == rightNative[1]
				and right.Gui.Position[2] == rightNative[2], "A measured column never overlaps the other cards")
		end
		local function clock() now += .00015; return now end
		local taskAPI = {wait = function() yields += 1; frames += 1; check(); now += .016 end}
		inspectFrame = function() nativeWaits += 1; check() end
		local text = "Deine Wahl: Eine CD brennen. Du kannst sie jederzeit ändern."
		local changed = mutate(tree, "poll-result", text)
		local stats = Dirty.begin(tree, {[changed] = "text"})
		local ok, result = Job.run({Alive = true}, tree, 2, function() return true end, function(alive)
			return layout.arrange(tree, width, 0, 0, alive)
		end, taskAPI, clock)
		inspectFrame = nil
		Dirty.finish(tree, ok)
		assert(ok, tostring(result))
		check()
		assert(yields > 0 and stats.Mode == "partial" and stats.Reused > 0)
		local reference = build(html, width, css)
		mutate(reference, "poll-result", text)
		Dirty.begin(reference)
		layout.arrange(reference, width, 0, 0, function() return true end)
		Dirty.finish(reference, true)
		assert(snapshot(tree) == snapshot(reference), "Partial yielded poll layout matches an uninterrupted full layout")
	end
	-- Other layout owners share the same retained-surface measurement path.
	for _, container in {"display:grid;grid-template-columns:120px 160px", "display:flex",
		"display:grid;grid-template-columns:120px 160px;grid-template-rows:masonry", "position:relative;height:400px"} do
		local positioned = container:find("position:relative", 1, true) ~= nil
		local source = '<style>body{margin:0}#row{' .. container .. ';gap:12px;align-items:start;padding:17px}#first{width:120px}#second{width:160px;' .. (if positioned then 'position:absolute;left:150px;top:40px' else '') .. '}img{display:block;width:80px;height:40px}</style><div id="row"><div id="first">Unchanged</div><div id="second"><p id="change">Short</p><img src="picture.png"></div></div>'
		local tree = build(source, 420)
		local first = tree.NodeBoxes[DOM.findById(tree.Node, "first")]
		local second = tree.NodeBoxes[DOM.findById(tree.Node, "second")]
		local firstKey, secondPosition = key(first.Gui), position(second.Gui)
		local changed = mutate(tree, "change", "A much longer sentence wraps into several lines inside the second item.")
		local now, yields = 0, 0
		Dirty.begin(tree, {[changed] = "text"})
		local ok, result = Job.run({Alive = true}, tree, 1, function() return true end, function(alive)
			return layout.arrange(tree, 420, 0, 0, alive)
		end, {wait = function()
			yields += 1
			assert(key(first.Gui) == firstKey and position(second.Gui) == secondPosition, "Measurement retains item placement: " .. container)
			now += .016
		end}, function() now += .0002; return now end)
		Dirty.finish(tree, ok)
		assert(ok and yields > 0, tostring(result))
	end
	for _, child in {'<img id="second" src="picture.png" style="width:80px;height:40px">',
		'<span id="second" style="display:inline-grid;width:120px;grid-template-columns:1fr">Inline box</span>'} do
		local inline = child:find("inline-grid", 1, true) ~= nil
		local source = '<style>body{margin:0}#row{' .. (if inline then '' else 'display:grid;grid-template-columns:120px 160px;') .. 'padding:17px;gap:12px}</style><div id="row"><span id="first">Unchanged preceding text</span>' .. child .. '</div>'
		local tree = build(source, 420)
		local second = tree.NodeBoxes[DOM.findById(tree.Node, "second")]
		assert(second.Gui.Position[1] > 0)
		local now, yields = 0, 0
		Dirty.begin(tree, {[second] = "style"})
		local ok, result = Job.run({Alive = true}, tree, 1, function() return true end, function(alive)
			return layout.arrange(tree, 420, 0, 0, alive)
		end, {wait = function()
			yields += 1
			assert(second.Gui.Position[1] > 0, "Replaced/inline probe must not expose the synthetic origin")
			now += .016
		end}, function() now += .0002; return now end)
		Dirty.finish(tree, ok)
		assert(ok and yields > 0, tostring(result))
	end
	local sentinel, box = {}, {Kind = "Block"}
	local function cancelled(owner)
		assert(owner.LayoutProbe == true)
		error(sentinel, 0)
	end
	local ok, failure = pcall(Probe.arrange, box, 100, cancelled, function() return true end)
	assert(not ok and failure == sentinel and box.LayoutProbe == nil, "Cancellation clears the measurement scope")
	box.LayoutProbe = true
	ok, failure = pcall(Probe.arrange, box, 100, cancelled, function() return true end)
	assert(not ok and failure == sentinel and box.LayoutProbe == true, "Nested cancellation restores the enclosing scope")
	assert(frames > 0 and nativeWaits > 0)
	print("Layout probes: Bytebude at three widths, budget/native waits, full-layout parity, Flex/Grid/Masonry/absolute/replaced/inline surfaces and cancelled scopes passed")
end
